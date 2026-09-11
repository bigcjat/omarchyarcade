import sys
import ctypes
from pathlib import Path
from PySide6.QtCore import QObject, Signal, Property, Slot, QTimer

from games.bytecity.sound_manager import SoundManager

MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

SCENARIO_FILES = {
    "dullsville": "scenario_dullsville.cty",
    "san_francisco": "scenario_san_francisco.cty",
    "hamburg": "scenario_hamburg.cty",
    "bern": "scenario_bern.cty",
    "tokyo": "scenario_tokyo.cty",
    "detroit": "scenario_detroit.cty",
    "boston": "scenario_boston.cty",
    "rio": "scenario_rio_de_janeiro.cty",
}

TOOL_SOUNDS = {
    0: "build",      # Residential (construction hammers)
    1: "build",      # Commercial (construction hammers)
    2: "build",      # Industrial (construction hammers)
    3: "build",      # Fire Dept
    4: "build",      # Police Dept
    6: "wire",       # Wire (electric zap)
    7: "bulldozer",  # Bulldozer (diesel crunch)
    8: "rail",       # Rail (rail clank)
    9: "road",       # Road (asphalt paving)
    10: "build",     # Stadium
    11: "park",      # Park
    12: "build",     # Seaport
    13: "coal",      # Coal Plant
    14: "coal",      # Nuclear Plant
    15: "build",     # Airport
}

class ByteCitySprite(ctypes.Structure):
    _fields_ = [
        ("type", ctypes.c_int),
        ("frame", ctypes.c_int),
        ("x", ctypes.c_int),
        ("y", ctypes.c_int),
        ("dir", ctypes.c_int),
    ]

class ByteCityEngine(QObject):
    statsChanged = Signal()
    mapChanged = Signal()
    advisorAlert = Signal(str)
    soundToggled = Signal(bool)
    optionsChanged = Signal()
    budgetRequired = Signal(int, int, int, int, int, int, int)
    dhhAlert = Signal(str, str, str, int)  # alert_type, title, message, urgency
    milestoneReached = Signal(int, str, str)  # threshold, title, reward_name
    gameOver = Signal(str)
    loanChanged = Signal()
    overlayChanged = Signal()
    tileQueried = Signal(dict)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._sound_manager = SoundManager(self)
        self._load_native_library()
        self._handle = self._lib.bytecity_create()
        self._map_data = None
        self._power_data = None
        self._bind_memory_buffers()
        self._speed = 1
        self._city_name = "OmarchyCity"
        self._current_message = "Welcome to OmarchyCity! Zone Residential, Commercial, and Industrial areas to begin."
        
        # Internal state cache
        self._funds = 20000
        self._tax_rate = 7
        self._population = 0
        self._year = 1900
        self._month = 0
        self._demand_r = 0.5
        self._demand_c = 0.5
        self._demand_i = 0.5
        self._approval = 75
        self._game_level = 0
        self._auto_bulldoze = True
        self._auto_budget = False

        # Loan state (SimCity Bank: $10,000 borrow, 21-year debt service @ $500/year)
        self._has_active_loan = False
        self._loan_years_remaining = 0
        self._loan_annual_payment = 500

        # Overlay Mode: 0=Normal, 1=Power, 2=Pollution, 3=Crime, 4=Land Value, 5=Traffic
        self._overlay_mode = 0
        self._overlay_buffer = (ctypes.c_uint8 * 12000)()

        # Milestones tracking
        self._milestones_achieved = set()

        # Last alert tracking for rate-limiting
        self._last_alert_ticks = 0

        # Historical census data buffers (120 data points each)
        # 10-year view (monthly samples) and 120-year view (yearly samples)
        # Categories: 'res', 'com', 'ind', 'money', 'crime', 'pollution'
        self._history_10yr = {
            'res': [0] * 120,
            'com': [0] * 120,
            'ind': [0] * 120,
            'money': [20000] * 120,
            'crime': [10] * 120,
            'pollution': [5] * 120,
        }
        self._history_120yr = {
            'res': [0] * 120,
            'com': [0] * 120,
            'ind': [0] * 120,
            'money': [20000] * 120,
            'crime': [10] * 120,
            'pollution': [5] * 120,
        }
        self._prev_month = -1
        self._prev_year = -1

        # Timer for simulation ticks
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._on_tick)
        self._update_timer_interval()
        self._timer.start()

        # Generate initial city
        self.generate_new_city(42)


    def _ensure_native_library(self, lib_dir: Path, lib_path: Path):
        """Attempts to auto-compile the native C++ simulation core if missing."""
        if lib_path.exists():
            return

        makefile = lib_dir / "Makefile"
        src_dir = lib_dir / "src"
        if not makefile.exists() or not src_dir.exists():
            return

        import subprocess
        import shutil

        print(f"[ByteCity] Native simulation core '{lib_path.name}' not found. Compiling...")
        make_cmd = shutil.which("make")
        cxx_cmd = shutil.which("c++") or shutil.which("g++") or shutil.which("clang++")

        if not cxx_cmd:
            print("[ByteCity] Notice: No C++ compiler (g++/clang++) found in PATH.")
            return

        try:
            if make_cmd:
                subprocess.run([make_cmd, "-C", str(lib_dir), "-j4"], capture_output=True, text=True, timeout=90)
            else:
                sources = list(src_dir.glob("*.cpp")) + [lib_dir / "micropolis_c_api.cpp"]
                cmd = [
                    cxx_cmd, "-std=c++17", "-O3", "-fPIC", "-shared",
                    f"-I{src_dir}", f"-I{lib_dir}",
                    *[str(s) for s in sources],
                    "-o", str(lib_path)
                ]
                subprocess.run(cmd, capture_output=True, text=True, timeout=90)

            if lib_path.exists():
                print(f"[ByteCity] Successfully compiled {lib_path.name}!")
        except Exception as e:
            print(f"[ByteCity] Auto-compilation notice: {e}")

    def _load_native_library(self):
        lib_dir = Path(__file__).resolve().parent / "native"
        if sys.platform == "darwin":
            lib_name = "libmicropolis.dylib"
        elif sys.platform == "win32":
            lib_name = "micropolis.dll"
        else:
            lib_name = "libmicropolis.so"

        lib_path = lib_dir / lib_name
        if not lib_path.exists():
            self._ensure_native_library(lib_dir, lib_path)

        if not lib_path.exists():
            help_msg = (
                f"ByteCity native simulation library '{lib_name}' not found at:\n"
                f"  {lib_path}\n\n"
                f"To compile it, open a terminal and run:\n"
                f"  make -C {lib_dir}\n\n"
                f"On Arch / Omarchy Linux, ensure base development tools are installed:\n"
                f"  sudo pacman -S --needed base-devel\n"
            )
            raise FileNotFoundError(help_msg)

        self._lib = ctypes.CDLL(str(lib_path))

        # Signatures
        self._lib.bytecity_create.restype = ctypes.c_void_p
        self._lib.bytecity_create.argtypes = []

        self._lib.bytecity_destroy.restype = None
        self._lib.bytecity_destroy.argtypes = [ctypes.c_void_p]

        self._lib.bytecity_generate_map.restype = None
        self._lib.bytecity_generate_map.argtypes = [ctypes.c_void_p, ctypes.c_int]

        self._lib.bytecity_tick.restype = None
        self._lib.bytecity_tick.argtypes = [ctypes.c_void_p]

        self._lib.bytecity_set_speed.restype = None
        self._lib.bytecity_set_speed.argtypes = [ctypes.c_void_p, ctypes.c_int]

        self._lib.bytecity_get_tile.restype = ctypes.c_uint16
        self._lib.bytecity_get_tile.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int]

        self._lib.bytecity_get_map_ptr.restype = ctypes.POINTER(ctypes.c_uint16)
        self._lib.bytecity_get_map_ptr.argtypes = [ctypes.c_void_p]

        self._lib.bytecity_get_power_map_ptr.restype = ctypes.POINTER(ctypes.c_uint8)
        self._lib.bytecity_get_power_map_ptr.argtypes = [ctypes.c_void_p]

        self._lib.bytecity_copy_map.restype = None
        self._lib.bytecity_copy_map.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint16)]

        self._lib.bytecity_do_tool.restype = ctypes.c_int
        self._lib.bytecity_do_tool.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]

        self._lib.bytecity_has_power.restype = ctypes.c_bool
        self._lib.bytecity_has_power.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int]

        self._lib.bytecity_get_funds.restype = ctypes.c_int64
        self._lib.bytecity_get_funds.argtypes = [ctypes.c_void_p]

        self._lib.bytecity_set_funds.restype = None
        self._lib.bytecity_set_funds.argtypes = [ctypes.c_void_p, ctypes.c_int64]

        self._lib.bytecity_get_tax_rate.restype = ctypes.c_int
        self._lib.bytecity_get_tax_rate.argtypes = [ctypes.c_void_p]

        self._lib.bytecity_set_tax_rate.restype = None
        self._lib.bytecity_set_tax_rate.argtypes = [ctypes.c_void_p, ctypes.c_int]

        self._lib.bytecity_get_population.restype = ctypes.c_int
        self._lib.bytecity_get_population.argtypes = [ctypes.c_void_p]

        self._lib.bytecity_get_year.restype = ctypes.c_int
        self._lib.bytecity_get_year.argtypes = [ctypes.c_void_p]

        self._lib.bytecity_get_month.restype = ctypes.c_int
        self._lib.bytecity_get_month.argtypes = [ctypes.c_void_p]

        self._lib.bytecity_get_demand.restype = None
        self._lib.bytecity_get_demand.argtypes = [
            ctypes.c_void_p,
            ctypes.POINTER(ctypes.c_float),
            ctypes.POINTER(ctypes.c_float),
            ctypes.POINTER(ctypes.c_float)
        ]

        self._lib.bytecity_get_city_yes.restype = ctypes.c_int
        self._lib.bytecity_get_city_yes.argtypes = [ctypes.c_void_p]

        self._lib.bytecity_get_city_no.restype = ctypes.c_int
        self._lib.bytecity_get_city_no.argtypes = [ctypes.c_void_p]

        self._lib.bytecity_trigger_disaster.restype = None
        self._lib.bytecity_trigger_disaster.argtypes = [ctypes.c_void_p, ctypes.c_int]

        self._lib.bytecity_has_message.restype = ctypes.c_bool
        self._lib.bytecity_has_message.argtypes = [ctypes.c_void_p]

        self._lib.bytecity_pop_message.restype = ctypes.c_char_p
        self._lib.bytecity_pop_message.argtypes = [ctypes.c_void_p]

        # File I/O & Settings
        self._lib.bytecity_load_city.restype = ctypes.c_bool
        self._lib.bytecity_load_city.argtypes = [ctypes.c_void_p, ctypes.c_char_p]

        self._lib.bytecity_save_city.restype = ctypes.c_bool
        self._lib.bytecity_save_city.argtypes = [ctypes.c_void_p, ctypes.c_char_p]

        self._lib.bytecity_set_game_level.restype = None
        self._lib.bytecity_set_game_level.argtypes = [ctypes.c_void_p, ctypes.c_int]

        self._lib.bytecity_get_game_level.restype = ctypes.c_int
        self._lib.bytecity_get_game_level.argtypes = [ctypes.c_void_p]

        self._lib.bytecity_set_auto_bulldoze.restype = None
        self._lib.bytecity_set_auto_bulldoze.argtypes = [ctypes.c_void_p, ctypes.c_bool]

        self._lib.bytecity_get_auto_bulldoze.restype = ctypes.c_bool
        self._lib.bytecity_get_auto_bulldoze.argtypes = [ctypes.c_void_p]

        self._lib.bytecity_set_auto_budget.restype = None
        self._lib.bytecity_set_auto_budget.argtypes = [ctypes.c_void_p, ctypes.c_bool]

        self._lib.bytecity_get_auto_budget.restype = ctypes.c_bool
        self._lib.bytecity_get_auto_budget.argtypes = [ctypes.c_void_p]

        self._lib.bytecity_set_city_name.restype = None
        self._lib.bytecity_set_city_name.argtypes = [ctypes.c_void_p, ctypes.c_char_p]

        self._lib.bytecity_get_city_name.restype = ctypes.c_char_p
        self._lib.bytecity_get_city_name.argtypes = [ctypes.c_void_p]

        self._lib.bytecity_get_sprites.restype = ctypes.c_int
        self._lib.bytecity_get_sprites.argtypes = [ctypes.c_void_p, ctypes.POINTER(ByteCitySprite), ctypes.c_int]

        # Budget & Financial Audit
        self._lib.bytecity_get_budget.restype = None
        self._lib.bytecity_get_budget.argtypes = [
            ctypes.c_void_p,
            ctypes.POINTER(ctypes.c_int64),
            ctypes.POINTER(ctypes.c_int64), ctypes.POINTER(ctypes.c_int64),
            ctypes.POINTER(ctypes.c_int64), ctypes.POINTER(ctypes.c_int64),
            ctypes.POINTER(ctypes.c_int64), ctypes.POINTER(ctypes.c_int64),
        ]

        self._lib.bytecity_set_budget.restype = None
        self._lib.bytecity_set_budget.argtypes = [
            ctypes.c_void_p, ctypes.c_int, ctypes.c_float, ctypes.c_float, ctypes.c_float
        ]

        self._lib.bytecity_collect_tax.restype = None
        self._lib.bytecity_collect_tax.argtypes = [ctypes.c_void_p]

        # Tile Query Inspector
        self._lib.bytecity_query_tile.restype = None
        self._lib.bytecity_query_tile.argtypes = [
            ctypes.c_void_p, ctypes.c_int, ctypes.c_int,
            ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int),
            ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int),
            ctypes.POINTER(ctypes.c_bool), ctypes.POINTER(ctypes.c_bool)
        ]

        # Data Layer Overlays
        self._lib.bytecity_get_overlay_map.restype = None
        self._lib.bytecity_get_overlay_map.argtypes = [
            ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_uint8)
        ]

    def get_sprites(self):
        if not self._handle:
            return []
        arr = (ByteCitySprite * 32)()
        count = self._lib.bytecity_get_sprites(self._handle, arr, 32)
        res = []
        for i in range(count):
            res.append({
                "type": arr[i].type,
                "frame": arr[i].frame,
                "x": arr[i].x,
                "y": arr[i].y,
                "dir": arr[i].dir,
            })
        return res

    def _update_timer_interval(self):
        if self._speed == 0:
            self._timer.stop()
        elif self._speed == 1:
            self._timer.setInterval(1000)
            if not self._timer.isActive(): self._timer.start()
        elif self._speed == 2:
            self._timer.setInterval(400)
            if not self._timer.isActive(): self._timer.start()
        elif self._speed == 3:
            self._timer.setInterval(150)
            if not self._timer.isActive(): self._timer.start()

    def _on_tick(self):
        if not self._handle or self._speed == 0:
            return
        
        # Advance simulation
        self._lib.bytecity_tick(self._handle)

        # Check messages
        while self._lib.bytecity_has_message(self._handle):
            msg_bytes = self._lib.bytecity_pop_message(self._handle)
            if msg_bytes:
                msg = msg_bytes.decode("utf-8")
                self._current_message = msg
                self.advisorAlert.emit(msg)

        # Update cached stats
        self._refresh_stats()

        cur_month = self._month
        cur_year = self._year

        # 1. Check for Annual December -> January Budget Cycle
        if (self._prev_month == 11 and cur_month == 0) or (self._prev_year != -1 and cur_year > self._prev_year):
            if not self._auto_budget:
                # Pause simulation for annual budget presentation
                self.set_speed(0)
                tf = ctypes.c_int64()
                rf = ctypes.c_int64()
                rs = ctypes.c_int64()
                pf = ctypes.c_int64()
                ps = ctypes.c_int64()
                ff = ctypes.c_int64()
                fs = ctypes.c_int64()
                self._lib.bytecity_get_budget(self._handle,
                    ctypes.byref(tf),
                    ctypes.byref(rf), ctypes.byref(rs),
                    ctypes.byref(pf), ctypes.byref(ps),
                    ctypes.byref(ff), ctypes.byref(fs))
                self.budgetRequired.emit(int(tf.value), int(rf.value), int(rs.value),
                                         int(pf.value), int(ps.value), int(ff.value), int(fs.value))
                self.dhhAlert.emit("budget", "Annual Fiscal Audit",
                                   f"Fiscal Year {cur_year} Complete! Review city revenues, department funding, and municipal loans.", 1)
            else:
                # Auto-Budget: collect tax at current rate and apply 100% funding
                self._lib.bytecity_collect_tax(self._handle)
                if self._has_active_loan:
                    self._funds -= self._loan_annual_payment
                    self._loan_years_remaining -= 1
                    if self._loan_years_remaining <= 0:
                        self._has_active_loan = False
                        self.loanChanged.emit()
                        self.dhhAlert.emit("info", "Municipal Loan Paid Off!", "Your $10,000 Municipal Bank Loan has been fully discharged!", 1)
                    self._lib.bytecity_set_funds(self._handle, self._funds)
                self._refresh_stats()

        # 2. Check for Bankruptcy Game Over Condition
        if self._funds < -5000:
            self.set_speed(0)
            self._sound_manager.play("sorry")
            msg = f"City Treasury is deeply in the red (${self._funds:,}). The state legislature has declared municipal bankruptcy and assumed emergency administration."
            self.gameOver.emit(msg)
            self.dhhAlert.emit("danger", "BANKRUPTCY DECLARED!", msg, 3)

        # 3. Check for Population Milestones & Reward Building Unlocks
        milestones = [
            (2000, "Town", "Mayor's Manor"),
            (10000, "City", "City Hall & Municipal Bank"),
            (50000, "Capital", "Metropolitan Plaza"),
            (100000, "Metropolis", "Golden Monument Statue"),
            (500000, "Megalopolis", "Fusion Energy Core & Grand Trophy"),
        ]
        for thresh, title, reward in milestones:
            if self._population >= thresh and thresh not in self._milestones_achieved:
                self._milestones_achieved.add(thresh)
                self.milestoneReached.emit(thresh, title, reward)
                self.dhhAlert.emit("milestone", f"Milestone: {title}!",
                                   f"ByteCity has surpassed {thresh:,} citizens! As Mayor, you have unlocked the {reward}!", 2)
                self._sound_manager.play("cash")

        # 4. Proactive Dr. DHH Alerts (Rate-limited to avoid spam)
        self._last_alert_ticks += 1
        if self._last_alert_ticks >= 20:
            self._last_alert_ticks = 0
            if 0 < self._funds < 500:
                self.dhhAlert.emit("warning", "Treasury Depleted!",
                                   f"Mayor! City reserves have plummeted to ${self._funds:,}. Adjust your budget or apply for a bank loan!", 2)
            elif self._population > 200 and self._approval < 35:
                self.dhhAlert.emit("warning", "Discontent Citizens!",
                                   "Citizen approval has dropped below 35%! Lower taxes or add parks and civic infrastructure.", 2)

        # Update demographic census histories
        cur_month = self._month
        cur_year = self._year
        if cur_month != self._prev_month:
            self._prev_month = cur_month
            tot_pop = self._population
            res_val = max(10, int(tot_pop * max(0.2, (self._demand_r + 1.0) / 2.0)))
            com_val = max(5, int(tot_pop * 0.5 * max(0.2, (self._demand_c + 1.0) / 2.0)))
            ind_val = max(5, int(tot_pop * 0.4 * max(0.2, (self._demand_i + 1.0) / 2.0)))
            money_val = max(0, self._funds)
            crime_val = max(0, 100 - self._approval)
            poll_val = int(ind_val * 0.35 + 2)

            new_vals = {
                'res': res_val,
                'com': com_val,
                'ind': ind_val,
                'money': money_val,
                'crime': crime_val,
                'pollution': poll_val,
            }

            for k, val in new_vals.items():
                self._history_10yr[k].pop(0)
                self._history_10yr[k].append(val)

            if cur_year != self._prev_year:
                self._prev_year = cur_year
                for k in self._history_120yr:
                    self._history_120yr[k].pop(0)
                    self._history_120yr[k].append(new_vals[k])

        self.mapChanged.emit()

    def _seed_history(self):
        tot_pop = self._population
        res_val = max(10, int(tot_pop * 0.6))
        com_val = max(5, int(tot_pop * 0.3))
        ind_val = max(5, int(tot_pop * 0.25))
        money_val = max(0, self._funds)
        crime_val = max(0, 100 - self._approval)
        poll_val = int(ind_val * 0.35 + 2)

        for i in range(120):
            frac = 0.4 + 0.6 * (i / 119.0)
            self._history_10yr['res'][i] = int(res_val * frac)
            self._history_10yr['com'][i] = int(com_val * frac)
            self._history_10yr['ind'][i] = int(ind_val * frac)
            self._history_10yr['money'][i] = int(money_val * (0.8 + 0.2 * (i / 119.0)))
            self._history_10yr['crime'][i] = int(crime_val * (0.7 + 0.3 * (i / 119.0)))
            self._history_10yr['pollution'][i] = int(poll_val * frac)

            frac120 = 0.1 + 0.9 * ((i / 119.0) ** 1.5)
            self._history_120yr['res'][i] = int(res_val * frac120)
            self._history_120yr['com'][i] = int(com_val * frac120)
            self._history_120yr['ind'][i] = int(ind_val * frac120)
            self._history_120yr['money'][i] = int(money_val * (0.5 + 0.5 * frac120))
            self._history_120yr['crime'][i] = int(crime_val * frac120)
            self._history_120yr['pollution'][i] = int(poll_val * frac120)

    @Slot(str, bool, result=list)
    def getHistory(self, category: str, is_120_year: bool = False):
        cat = category.lower()
        hist = self._history_120yr if is_120_year else self._history_10yr
        return hist.get(cat, [0] * 120)

    @Slot(bool, result=dict)
    def getAllHistory(self, is_120_year: bool = False):
        hist = self._history_120yr if is_120_year else self._history_10yr
        return {k: list(v) for k, v in hist.items()}


    def _refresh_stats(self):
        if not self._handle:
            return
        self._funds = self._lib.bytecity_get_funds(self._handle)
        self._tax_rate = self._lib.bytecity_get_tax_rate(self._handle)
        self._population = self._lib.bytecity_get_population(self._handle)
        self._year = self._lib.bytecity_get_year(self._handle)
        self._month = max(0, min(11, self._lib.bytecity_get_month(self._handle)))
        self._approval = self._lib.bytecity_get_city_yes(self._handle)

        r = ctypes.c_float()
        c = ctypes.c_float()
        i = ctypes.c_float()
        self._lib.bytecity_get_demand(self._handle, ctypes.byref(r), ctypes.byref(c), ctypes.byref(i))
        # Valves range roughly -2000 to +2000, normalize to -1.0 to 1.0
        self._demand_r = max(-1.0, min(1.0, r.value / 2000.0))
        self._demand_c = max(-1.0, min(1.0, c.value / 2000.0))
        self._demand_i = max(-1.0, min(1.0, i.value / 2000.0))

        self.statsChanged.emit()

    # --- QML Slots ---

    @Slot(str)
    def play_sound(self, sound_name):
        self._sound_manager.play(sound_name)

    @Slot(int)
    def generate_new_city(self, seed):
        if not self._handle:
            return
        self._lib.bytecity_generate_map(self._handle, seed)
        self._current_message = f"Territory charted (Seed {seed}). Connect residential, commercial, and industrial zones with roads and power."
        self._refresh_stats()
        self._seed_history()
        self.mapChanged.emit()
        self.advisorAlert.emit(self._current_message)

    @Slot(str, int, int)
    def start_new_city(self, name, level, seed):
        if not self._handle:
            return
        self._city_name = name or "OmarchyCity"
        self._lib.bytecity_set_city_name(self._handle, self._city_name.encode("utf-8"))
        self._game_level = max(0, min(2, level))
        self._lib.bytecity_set_game_level(self._handle, self._game_level)
        self._lib.bytecity_generate_map(self._handle, seed)

        # Funds based on difficulty level
        starting_funds = {0: 20000, 1: 10000, 2: 5000}.get(self._game_level, 20000)
        self._lib.bytecity_set_funds(self._handle, starting_funds)
        self._funds = starting_funds

        self._sound_manager.play("build")
        self._current_message = f"Mayor of {self._city_name} inaugurated! Treasury: ${starting_funds:,}."
        self._refresh_stats()
        self._seed_history()
        self.mapChanged.emit()
        self.advisorAlert.emit(self._current_message)

    @Slot(int)
    def add_funds(self, amount):
        if not self._handle:
            return
        new_funds = self._funds + amount
        self._lib.bytecity_set_funds(self._handle, new_funds)
        self._funds = new_funds
        self._sound_manager.play("cash")
        self.statsChanged.emit()

    @Slot(int)
    def set_funds(self, amount):
        if not self._handle:
            return
        self._lib.bytecity_set_funds(self._handle, amount)
        self._funds = amount
        self.statsChanged.emit()

    @Slot(str)
    def load_scenario(self, scenario_id):
        if not self._handle:
            return
        filename = SCENARIO_FILES.get(scenario_id.lower())
        if not filename:
            self._sound_manager.play("uhuh")
            return
        
        cities_dir = Path(__file__).resolve().parent / "cities"
        filepath = cities_dir / filename
        if not filepath.exists():
            self._sound_manager.play("uhuh")
            return

        ok = self._lib.bytecity_load_city(self._handle, str(filepath).encode("utf-8"))
        if ok:
            title = scenario_id.replace("_", " ").title()
            self._city_name = title
            self._sound_manager.play("boing")
            self._current_message = f"Scenario loaded: {title}. Good luck, Mayor!"
            self._refresh_stats()
            self._seed_history()
            self.mapChanged.emit()
            self.advisorAlert.emit(self._current_message)

        else:
            self._sound_manager.play("sorry")

    @Slot(str, result=bool)
    def save_city_file(self, filepath):
        if not self._handle or not filepath:
            return False
        return self._lib.bytecity_save_city(self._handle, filepath.encode("utf-8"))

    @Slot(str, result=bool)
    def load_city_file(self, filepath):
        if not self._handle or not filepath:
            return False
        ok = self._lib.bytecity_load_city(self._handle, filepath.encode("utf-8"))
        if ok:
            self._sound_manager.play("boing")
            self._refresh_stats()
            self.mapChanged.emit()
        return ok

    @Slot(int, int, int, result=int)
    def apply_tool(self, tool_id, x, y):
        if not self._handle:
            return 0
        res = self._lib.bytecity_do_tool(self._handle, tool_id, x, y)
        if res == 1:
            snd = TOOL_SOUNDS.get(tool_id, "build")
            self._sound_manager.play(snd)
        elif res == -2:
            self._sound_manager.play("error")
        elif res in (-1, 0):
            self._sound_manager.play("error")

        self._refresh_stats()
        self.mapChanged.emit()
        return res

    def _bind_memory_buffers(self):
        if not self._handle:
            return
        map_ptr = self._lib.bytecity_get_map_ptr(self._handle)
        power_ptr = self._lib.bytecity_get_power_map_ptr(self._handle)
        if map_ptr:
            self._map_data = (ctypes.c_uint16 * 12000).from_address(ctypes.addressof(map_ptr.contents))
        if power_ptr:
            self._power_data = (ctypes.c_uint8 * 12000).from_address(ctypes.addressof(power_ptr.contents))

    def fast_get_tile(self, x: int, y: int) -> int:
        if 0 <= x < 120 and 0 <= y < 100 and self._map_data is not None:
            return self._map_data[x * 100 + y]
        return 0

    def fast_set_tile(self, x: int, y: int, value: int):
        if 0 <= x < 120 and 0 <= y < 100 and self._map_data is not None:
            self._map_data[x * 100 + y] = value

    def fast_has_power(self, x: int, y: int) -> bool:
        if 0 <= x < 120 and 0 <= y < 100 and self._power_data is not None:
            return self._power_data[x * 100 + y] != 0
        return False

    @Slot(int, int, result=bool)
    def has_power(self, x, y):
        return self.fast_has_power(x, y)

    @Slot(int)
    def set_speed(self, speed):
        self._speed = max(0, min(3, speed))
        if self._handle:
            self._lib.bytecity_set_speed(self._handle, self._speed)
        self._update_timer_interval()
        self.statsChanged.emit()

    @Slot(int)
    def set_tax_rate(self, rate):
        if not self._handle:
            return
        self._tax_rate = max(0, min(20, rate))
        self._lib.bytecity_set_tax_rate(self._handle, self._tax_rate)
        self.statsChanged.emit()

    @Slot(int)
    def trigger_disaster(self, disaster_id):
        if not self._handle:
            return
        self._lib.bytecity_trigger_disaster(self._handle, disaster_id)
        disaster_names = {
            0: "Massive Firestorm",
            1: "Raging Flood",
            2: "Rampaging Monster",
            3: "Violent Tornado",
            4: "Major Earthquake",
            5: "Nuclear Meltdown"
        }
        d_name = disaster_names.get(disaster_id, "Emergency Disaster")
        self.dhhAlert.emit("emergency", "DISASTER STRIKE!",
                           f"{d_name} has hit the metropolitan area! Deploy emergency departments immediately!", 3)
        # Play authentic disaster sounds
        if disaster_id == 2: # Monster
            self._sound_manager.play("monster")
        elif disaster_id == 4: # Earthquake
            self._sound_manager.play("explosion_low")
        elif disaster_id == 5: # Meltdown
            self._sound_manager.play("explosion_high")
        else:
            self._sound_manager.play("siren")
        self.mapChanged.emit()

    # --- Budget & Municipal Finance Slots ---

    @Slot(result=dict)
    def get_budget_details(self):
        if not self._handle:
            return {}
        tf = ctypes.c_int64()
        rf = ctypes.c_int64()
        rs = ctypes.c_int64()
        pf = ctypes.c_int64()
        ps = ctypes.c_int64()
        ff = ctypes.c_int64()
        fs = ctypes.c_int64()
        self._lib.bytecity_get_budget(self._handle,
            ctypes.byref(tf),
            ctypes.byref(rf), ctypes.byref(rs),
            ctypes.byref(pf), ctypes.byref(ps),
            ctypes.byref(ff), ctypes.byref(fs))
        
        return {
            "tax_fund": int(tf.value),
            "road_fund": int(rf.value),
            "road_spend": int(rs.value),
            "police_fund": int(pf.value),
            "police_spend": int(ps.value),
            "fire_fund": int(ff.value),
            "fire_spend": int(fs.value),
            "tax_rate": self._tax_rate,
            "auto_budget": self._auto_budget,
            "has_loan": self._has_active_loan,
            "loan_years": self._loan_years_remaining,
            "loan_payment": self._loan_annual_payment,
            "current_funds": self._funds,
        }

    @Slot(int, float, float, float)
    def apply_budget(self, tax_rate, road_pct, police_pct, fire_pct):
        if not self._handle:
            return
        self._tax_rate = max(0, min(20, tax_rate))
        self._lib.bytecity_set_budget(self._handle, self._tax_rate, road_pct, police_pct, fire_pct)
        self._lib.bytecity_collect_tax(self._handle)

        if self._has_active_loan:
            self._funds -= self._loan_annual_payment
            self._loan_years_remaining -= 1
            if self._loan_years_remaining <= 0:
                self._has_active_loan = False
                self.loanChanged.emit()
                self.dhhAlert.emit("info", "Loan Discharged!", "Your $10,000 Municipal Bank Loan has been fully paid off!", 1)
            self._lib.bytecity_set_funds(self._handle, self._funds)

        # Resume simulation
        self.set_speed(1)
        self._refresh_stats()
        self._sound_manager.play("cash")
        self.advisorAlert.emit(f"Fiscal budget enacted! Tax rate: {self._tax_rate}%. Roads: {int(road_pct*100)}%, Police: {int(police_pct*100)}%, Fire: {int(fire_pct*100)}%.")

    @Slot(result=bool)
    def take_loan(self):
        if not self._handle or self._has_active_loan:
            self._sound_manager.play("error")
            return False
        self._has_active_loan = True
        self._loan_years_remaining = 21
        self.add_funds(10000)
        self.loanChanged.emit()
        self._sound_manager.play("cash")
        self.advisorAlert.emit("🏛️ $10,000 Municipal Bank Loan approved! Repayment: $500/yr over 21 years.")
        return True

    @Slot(result=bool)
    def repay_loan_full(self):
        if not self._handle or not self._has_active_loan:
            return False
        total_remaining = self._loan_years_remaining * self._loan_annual_payment
        if self._funds < total_remaining:
            self._sound_manager.play("error")
            return False
        self._funds -= total_remaining
        self._lib.bytecity_set_funds(self._handle, self._funds)
        self._has_active_loan = False
        self._loan_years_remaining = 0
        self.loanChanged.emit()
        self.statsChanged.emit()
        self._sound_manager.play("cash")
        self.advisorAlert.emit("🎉 Municipal Bank Loan has been paid off in full!")
        return True

    # --- Tile Query Inspector Slots ---

    @Slot(int, int, result=dict)
    def query_tile(self, x, y):
        if not self._handle or x < 0 or x >= 120 or y < 0 or y >= 100:
            return {}

        tile_id = ctypes.c_int()
        zone_type = ctypes.c_int()
        land_val = ctypes.c_int()
        crime_val = ctypes.c_int()
        poll_val = ctypes.c_int()
        powered = ctypes.c_bool()
        road_conn = ctypes.c_bool()

        self._lib.bytecity_query_tile(
            self._handle, x, y,
            ctypes.byref(tile_id), ctypes.byref(zone_type), ctypes.byref(land_val),
            ctypes.byref(crime_val), ctypes.byref(poll_val),
            ctypes.byref(powered), ctypes.byref(road_conn)
        )

        tid = tile_id.value
        zt = zone_type.value
        lv = land_val.value
        cr = crime_val.value
        pol = poll_val.value
        pwr = bool(powered.value)
        rd = bool(road_conn.value)

        # Human-readable classifications
        zone_names = {
            0: "Open Land",
            1: "Residential District",
            2: "Commercial District",
            3: "Industrial District",
            4: "Power Generation Facility",
            5: "Police Precinct",
            6: "Fire Headquarters",
            7: "City Park & Nature",
            8: "Sports Stadium",
            9: "Cargo Seaport",
            10: "Metropolitan Airport",
        }
        zone_name = zone_names.get(zt, "Unzoned Land")

        # Specific structure name
        if zt == 1:
            name = "Luxury High-Rise Condos" if lv > 160 else ("Garden Apartments" if lv > 80 else "Suburban Cottages")
        elif zt == 2:
            name = "Corporate Office Tower" if lv > 160 else ("Commercial Shopping Plaza" if lv > 80 else "Local Retail Shops")
        elif zt == 3:
            name = "Heavy Chemical Smelter" if pol > 140 else ("Manufacturing Assembly Plant" if pol > 60 else "Light Industrial Workshop")
        elif zt == 4:
            name = "Nuclear Power Station" if tid >= 811 else "Coal Power Generation Station"
        elif zt == 5:
            name = "Municipal Police Station"
        elif zt == 6:
            name = "Emergency Fire Dept Headquarters"
        elif zt == 7:
            name = "Public City Park & Fountains"
        elif zt == 8:
            name = "Major League Stadium"
        elif zt == 9:
            name = "Deepwater Cargo Seaport"
        elif zt == 10:
            name = "International Municipal Airport"
        elif tid in (0, 1):
            name = "Open Meadow / Grassland"
        elif 2 <= tid <= 20:
            name = "Navigable Coastal Waterway"
        elif 21 <= tid <= 43:
            name = "Forested Woodlands"
        elif 44 <= tid <= 51:
            name = "Demolished Rubble"
        elif 64 <= tid <= 207:
            name = "Paved Roadway Network"
        elif 208 <= tid <= 223:
            name = "High-Voltage Powerlines"
        elif 224 <= tid <= 239:
            name = "Transit Railway Lines"
        else:
            name = f"Urban Infrastructure (Tile #{tid})"

        # Qualitative ratings
        lv_str = "Prime Luxury" if lv > 180 else ("High" if lv > 120 else ("Moderate" if lv > 60 else "Low"))
        cr_str = "Dangerous / Severe" if cr > 150 else ("Elevated" if cr > 80 else ("Low" if cr > 30 else "Safe / Calm"))
        pol_str = "Hazardous Smog" if pol > 140 else ("Moderate Haze" if pol > 60 else ("Clean Air" if pol > 15 else "Pure Mountain Air"))

        info = {
            "x": x,
            "y": y,
            "tile_id": tid,
            "zone_type": zt,
            "zone_name": zone_name,
            "building_name": name,
            "land_value": lv,
            "land_value_str": lv_str,
            "crime": cr,
            "crime_str": cr_str,
            "pollution": pol,
            "pollution_str": pol_str,
            "powered": pwr,
            "road_connected": rd,
        }

        self.tileQueried.emit(info)
        return info

    # --- Data Layer Overlays Slots ---

    @Slot(int)
    def set_overlay_mode(self, mode):
        self._overlay_mode = max(0, min(5, mode))
        self.overlayChanged.emit()
        self.mapChanged.emit()

    @Slot(int, result=list)
    def get_overlay_data(self, mode):
        if not self._handle or mode <= 0:
            return []
        buf = (ctypes.c_uint8 * 12000)()
        self._lib.bytecity_get_overlay_map(self._handle, mode, buf)
        return list(buf)

    @Slot(int, int, result=int)
    def get_tile(self, x, y):
        return self.fast_get_tile(x, y)

    @Slot(bool)
    def set_sound_muted(self, muted):
        self._sound_manager.muted = muted
        self.soundToggled.emit(not muted)

    @Slot(bool)
    def set_auto_bulldoze(self, val):
        self._auto_bulldoze = val
        if self._handle:
            self._lib.bytecity_set_auto_bulldoze(self._handle, val)
        self.optionsChanged.emit()

    @Slot(bool)
    def set_auto_budget(self, val):
        self._auto_budget = val
        if self._handle:
            self._lib.bytecity_set_auto_budget(self._handle, val)
        self.optionsChanged.emit()

    # --- QML Properties ---

    @Property(int, notify=statsChanged)
    def funds(self):
        return self._funds

    @Property(int, notify=statsChanged)
    def taxRate(self):
        return self._tax_rate

    @Property(int, notify=statsChanged)
    def population(self):
        return self._population

    @Property(int, notify=statsChanged)
    def year(self):
        return self._year

    @Property(int, notify=statsChanged)
    def month(self):
        return self._month

    @Property(str, notify=statsChanged)
    def monthName(self):
        return MONTH_NAMES[self._month]

    @Property(float, notify=statsChanged)
    def demandRes(self):
        return self._demand_r

    @Property(float, notify=statsChanged)
    def demandCom(self):
        return self._demand_c

    @Property(float, notify=statsChanged)
    def demandInd(self):
        return self._demand_i

    @Property(int, notify=statsChanged)
    def approvalRating(self):
        return self._approval

    @Property(int, notify=statsChanged)
    def simSpeed(self):
        return self._speed

    @Property(str, notify=advisorAlert)
    def advisorMessage(self):
        return self._current_message

    @Property(str, notify=statsChanged)
    def cityName(self):
        return self._city_name

    @Property(bool, notify=soundToggled)
    def soundEnabled(self):
        return not self._sound_manager.muted

    @Property(bool, notify=optionsChanged)
    def autoBulldoze(self):
        return self._auto_bulldoze

    @Property(bool, notify=optionsChanged)
    def autoBudget(self):
        return self._auto_budget

    @Property(bool, notify=loanChanged)
    def hasActiveLoan(self):
        return self._has_active_loan

    @Property(int, notify=loanChanged)
    def loanYearsRemaining(self):
        return self._loan_years_remaining

    @Property(int, notify=loanChanged)
    def loanAnnualPayment(self):
        return self._loan_annual_payment

    @Property(bool, notify=loanChanged)
    def canTakeLoan(self):
        return not self._has_active_loan

    @Property(int, notify=overlayChanged)
    def overlayMode(self):
        return self._overlay_mode

    def close(self):
        if self._timer:
            self._timer.stop()
        if self._handle:
            self._lib.bytecity_destroy(self._handle)
            self._handle = None

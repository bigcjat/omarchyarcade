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

class ByteCityEngine(QObject):
    statsChanged = Signal()
    mapChanged = Signal()
    advisorAlert = Signal(str)
    soundToggled = Signal(bool)
    optionsChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._sound_manager = SoundManager(self)
        self._load_native_library()
        self._handle = self._lib.bytecity_create()
        self._map_data = None
        self._power_data = None
        self._bind_memory_buffers()
        self._speed = 1
        self._city_name = "ByteCity"
        self._current_message = "Welcome to ByteCity! Zone Residential, Commercial, and Industrial areas to begin."
        
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

        # Timer for simulation ticks
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._on_tick)
        self._update_timer_interval()
        self._timer.start()

        # Generate initial city
        self.generate_new_city(42)

    def _load_native_library(self):
        lib_dir = Path(__file__).resolve().parent / "native"
        lib_path = lib_dir / "libmicropolis.dylib"
        if not lib_path.exists():
            lib_path = lib_dir / "libmicropolis.so"
        
        if not lib_path.exists():
            raise FileNotFoundError(f"Native library not found at {lib_path}")

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
        self.mapChanged.emit()

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
        self.mapChanged.emit()
        self.advisorAlert.emit(self._current_message)

    @Slot(str, int, int)
    def start_new_city(self, name, level, seed):
        if not self._handle:
            return
        self._city_name = name or "ByteCity"
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

    def close(self):
        if self._timer:
            self._timer.stop()
        if self._handle:
            self._lib.bytecity_destroy(self._handle)
            self._handle = None

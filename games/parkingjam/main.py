#!/usr/bin/env python3
"""
Tokyo Parking Jam • Arcade Edition
Master Template Conformance Host with CoreAudio/PipeWire Sound,
Omarchy Theme Synchronization, QSettings Persistence, and Procedural Level Progression.
"""

import os
import sys
import re
import json
import random
import shutil
import subprocess
import tomllib
import ctypes
from pathlib import Path
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QFileSystemWatcher, QTimer, QObject, Slot, QSettings, Qt

# =============================================================================
# PERSISTENT SETTINGS MANAGER
# =============================================================================
class SettingsManager(QObject):
    """Provides local persistence via QSettings."""
    def __init__(self, game_id="TokyoParkingJam", parent=None):
        super().__init__(parent)
        self.settings = QSettings("Arcade", game_id)

    @Slot(result=int)
    def getBestScore(self):
        try:
            return int(self.settings.value("bestScore", 0))
        except (ValueError, TypeError):
            return 0

    @Slot(int)
    def setBestScore(self, score):
        self.settings.setValue("bestScore", int(score))

    @Slot(str, str)
    def setValue(self, key, val):
        self.settings.setValue(key, val)

    @Slot(str, str, result=str)
    def getValue(self, key, default_val=""):
        return str(self.settings.value(key, default_val))

# =============================================================================
# NATIVE LOW-LATENCY SOUND MANAGER
# =============================================================================
class SoundManager(QObject):
    """
    Ultra-low-latency sound dispatcher.
    Uses native CoreAudio AudioServices on macOS (preloaded system sound IDs).
    Falls back to PipeWire (pw-play), PulseAudio (paplay), or ALSA (aplay) on Linux.
    """
    def __init__(self, sounds_dir, parent=None):
        super().__init__(parent)
        self.sounds_dir = Path(sounds_dir)
        self.sounds = {}
        self.is_mac = sys.platform == "darwin"
        
        if self.is_mac:
            try:
                cf = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
                tb = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox")

                self.CFURLCreateWithFileSystemPath = cf.CFURLCreateWithFileSystemPath
                self.CFURLCreateWithFileSystemPath.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_long, ctypes.c_bool]
                self.CFURLCreateWithFileSystemPath.restype = ctypes.c_void_p

                self.CFStringCreateWithCString = cf.CFStringCreateWithCString
                self.CFStringCreateWithCString.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_uint32]
                self.CFStringCreateWithCString.restype = ctypes.c_void_p

                self.CFRelease = cf.CFRelease
                self.CFRelease.argtypes = [ctypes.c_void_p]

                self.AudioServicesCreateSystemSoundID = tb.AudioServicesCreateSystemSoundID
                self.AudioServicesCreateSystemSoundID.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32)]
                self.AudioServicesCreateSystemSoundID.restype = ctypes.c_int32

                self.AudioServicesPlaySystemSound = tb.AudioServicesPlaySystemSound
                self.AudioServicesPlaySystemSound.argtypes = [ctypes.c_uint32]
                self.AudioServicesPlaySystemSound.restype = None

                if self.sounds_dir.is_dir():
                    for wav in self.sounds_dir.glob("*.wav"):
                        s_name = wav.stem
                        cf_path = self.CFStringCreateWithCString(None, str(wav.resolve()).encode("utf-8"), 0x08000100)
                        cf_url = self.CFURLCreateWithFileSystemPath(None, cf_path, 0, False)
                        sound_id = ctypes.c_uint32()
                        if self.AudioServicesCreateSystemSoundID(cf_url, ctypes.byref(sound_id)) == 0:
                            self.sounds[s_name] = sound_id.value
                        self.CFRelease(cf_path)
                        self.CFRelease(cf_url)
            except Exception as e:
                print(f"[SoundManager] CoreAudio notice: {e}", file=sys.stderr)
                self.is_mac = False

        if not self.is_mac:
            self.player_cmd = shutil.which("pw-play") or shutil.which("paplay") or shutil.which("aplay")

    @Slot(str)
    def playSound(self, name):
        if self.is_mac and name in self.sounds:
            self.AudioServicesPlaySystemSound(self.sounds[name])
        elif hasattr(self, "player_cmd") and self.player_cmd:
            wav_file = self.sounds_dir / f"{name}.wav"
            if wav_file.is_file():
                try:
                    subprocess.Popen([self.player_cmd, str(wav_file)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                except Exception:
                    pass

# =============================================================================
# LEVEL & PUZZLE VAULT MANAGER
# =============================================================================
class LevelVaultManager(QObject):
    """
    Manages curated, mathematically verified, multi-step traffic jam puzzles.
    Randomizes Japanese vehicle skins on every load for endless visual novelty.
    """
    ALL_VEHICLES = [
        "taxi", "ae86", "police", "kei_truck", "skyline_gtr", "rx7",
        "impreza_wrx", "lancer_evo", "civic_ek9", "hiace", "cube", "copen",
        "delivery_truck", "fire_engine", "dekotora", "yochien_bus", "garbage_truck"
    ]

    def __init__(self, vault_path, parent=None):
        super().__init__(parent)
        self.vault_path = Path(vault_path)
        self.vault = {"easy": [], "medium": [], "hard": []}
        self.load_vault()

    def load_vault(self):
        if self.vault_path.is_file():
            try:
                with open(self.vault_path, "r", encoding="utf-8") as f:
                    self.vault = json.load(f)
            except Exception as e:
                print(f"[LevelVaultManager] Error loading vault: {e}", file=sys.stderr)

    @Slot(str, int, result=str)
    def getLevelJson(self, difficulty, level_num):
        """
        Retrieves a puzzle for the given difficulty and level number (1..N..infinity).
        Applies a random shuffle of vehicle skins.
        """
        diff = difficulty.lower()
        if diff not in self.vault or not self.vault[diff]:
            diff = "easy"
            
        pool = self.vault[diff]
        idx = (level_num - 1) % len(pool)
        base = pool[idx]

        # Shuffle vehicles
        skins = list(self.ALL_VEHICLES)
        random.shuffle(skins)

        cars_copy = []
        for i, c in enumerate(base["cars"]):
            car_copy = dict(c)
            car_copy["carId"] = skins[i % len(skins)]
            cars_copy.append(car_copy)

        puzzle_data = {
            "difficulty": diff,
            "level": level_num,
            "cols": base["cols"],
            "rows": base["rows"],
            "minMoves": base["minMoves"],
            "slideMoves": base["slideMoves"],
            "startExits": base["startExits"],
            "cars": cars_copy
        }
        return json.dumps(puzzle_data)

# =============================================================================
# THEME UTILITIES
# =============================================================================
def load_all_omarchy_themes():
    """Parses Themes.js for all predefined Omarchy color schemes."""
    themes_js = Path(__file__).resolve().parent / "Themes.js"
    if not themes_js.is_file():
        return {}
    with open(themes_js, "r", encoding="utf-8") as f:
        content = f.read()
    themes = {}
    blocks = re.findall(r"\{([^{}]+)\}", content)
    for b in blocks:
        t = {}
        for k, v in re.findall(r"(\w+):\s*\"([^\"]+)\"", b):
            t[k] = v
        if "id" in t and "name" in t:
            themes[t["id"]] = t
    return themes

ALL_THEMES = load_all_omarchy_themes()

def find_omarchy_colors_file():
    """Finds current Omarchy desktop theme colors.toml configuration."""
    home = Path.home()
    candidates = [
        home / ".config" / "omarchy" / "current" / "theme" / "colors.toml",
        home / ".config" / "omarchy" / "colors.toml",
    ]
    for c in candidates:
        if c.is_file():
            return c
    return None

def load_toml_colors(file_path):
    """Loads a TOML theme configuration file."""
    try:
        with open(file_path, "rb") as f:
            data = tomllib.load(f)
            return data.get("colors", data)
    except Exception as e:
        print(f"Warning: Failed to load {file_path}: {e}", file=sys.stderr)
        return None

# =============================================================================
# MAIN ENTRYPOINT
# =============================================================================
def main():
    os.environ["QT_ENABLE_HIGHDPI_SCALING"] = "1"
    os.environ["QML_XHR_ALLOW_FILE_READ"] = "1"

    if "--list-themes" in sys.argv:
        print(f"Parking Jam • Available Themes ({len(ALL_THEMES)} total):\n")
        print("  Light Themes:")
        for tid, t in ALL_THEMES.items():
            if any(term in tid for term in ["light", "snow", "dawn", "white", "latte", "paper"]):
                print(f"    --theme {tid:<20} -> {t['name']}")
        print("\n  Dark Themes:")
        for tid, t in ALL_THEMES.items():
            if not any(term in tid for term in ["light", "snow", "dawn", "white", "latte", "paper"]):
                print(f"    --theme {tid:<20} -> {t['name']}")
        print("\nUsage: python main.py --theme <theme_id>")
        sys.exit(0)

    app = QGuiApplication(sys.argv)
    app.setApplicationName("Parking Jam")
    app.setOrganizationName("OmarchyArcade")

    base_dir = Path(__file__).resolve().parent
    icon_file = base_dir / "assets" / "disk_icon.png"
    if icon_file.is_file():
        app.setWindowIcon(QIcon(str(icon_file)))

    engine = QQmlApplicationEngine()

    base_dir = Path(__file__).resolve().parent
    sounds_dir = base_dir / "sounds"
    vault_file = base_dir / "verified_vault.json"

    sound_mgr = SoundManager(sounds_dir)
    settings_mgr = SettingsManager("ParkingJam")
    level_mgr = LevelVaultManager(vault_file)

    engine.rootContext().setContextProperty("soundManager", sound_mgr)
    engine.rootContext().setContextProperty("settingsManager", settings_mgr)
    engine.rootContext().setContextProperty("levelVaultManager", level_mgr)

    qml_file = base_dir / "main.qml"
    engine.load(str(qml_file))

    if not engine.rootObjects():
        print("Error: Failed to load QML root object.", file=sys.stderr)
        sys.exit(1)

    root_obj = engine.rootObjects()[0]
    root_obj.requestActivate()

    # CLI Theme Argument Parsing
    theme_arg = None
    if "--theme" in sys.argv:
        idx = sys.argv.index("--theme")
        if idx + 1 < len(sys.argv):
            theme_arg = sys.argv[idx + 1]

    # 1. Explicit Theme CLI Override
    if theme_arg:
        clean_arg = theme_arg.lower().replace("_", "-")
        if clean_arg in ALL_THEMES:
            t = ALL_THEMES[clean_arg]
            root_obj.applyTheme(t, t["name"])
            print(f"Applied theme: {t['name']}")
        else:
            custom_path = Path(theme_arg).expanduser().resolve()
            if custom_path.is_file():
                data = load_toml_colors(custom_path)
                if data:
                    root_obj.applyTheme(data, custom_path.parent.name.capitalize())
                    print(f"Applied theme from file: {custom_path}")
            else:
                print(f"Warning: Theme '{theme_arg}' not found. Run with --list-themes.", file=sys.stderr)

    # 2. Omarchy Desktop System Theme Detection & Hot-Reloading
    else:
        system_colors = find_omarchy_colors_file()
        if system_colors:
            data = load_toml_colors(system_colors)
            if data:
                theme_name = system_colors.parent.name.capitalize()
                root_obj.applyTheme(data, theme_name)
                print(f"Detected Omarchy theme: {theme_name} ({system_colors})")

            watcher = QFileSystemWatcher(app)
            watcher.addPath(str(system_colors))
            if system_colors.parent.exists():
                watcher.addPath(str(system_colors.parent))

            def on_theme_updated(path):
                colors_path = find_omarchy_colors_file()
                if colors_path and colors_path.is_file():
                    updated = load_toml_colors(colors_path)
                    if updated:
                        root_obj.applyTheme(updated, colors_path.parent.name.capitalize())
                        print(f"Omarchy theme reloaded: {colors_path.parent.name}")

            watcher.fileChanged.connect(on_theme_updated)
            watcher.directoryChanged.connect(on_theme_updated)

        # 3. macOS / System Dark & Light Mode Synchronization
        else:
            def apply_system_scheme():
                scheme = app.styleHints().colorScheme()
                if scheme == Qt.ColorScheme.Light:
                    target_theme = ALL_THEMES.get("catppuccin-latte") or ALL_THEMES.get("github-light")
                    name = "System Light"
                else:
                    target_theme = ALL_THEMES.get("tokyonight") or ALL_THEMES.get("catppuccin")
                    name = "System Dark"

                if target_theme:
                    root_obj.applyTheme(target_theme, name)
                    print(f"Detected OS appearance: {name} ({target_theme.get('name')})")

            apply_system_scheme()
            app.styleHints().colorSchemeChanged.connect(lambda _: apply_system_scheme())

    if "--no-splash" in sys.argv:
        root_obj.setProperty("splashEnabled", False)

    # Screenshot / automation helpers
    if "--screenshot" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        def capture():
            out_idx = sys.argv.index("--screenshot") + 1
            out_file = sys.argv[out_idx] if out_idx < len(sys.argv) and not sys.argv[out_idx].startswith("--") else "screenshot.png"
            out_path = Path(out_file).resolve()
            root_obj.captureScreenshot(str(out_path), False)
            QTimer.singleShot(400, app.quit)
        QTimer.singleShot(450, capture)

    if "--screenshot-help" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        def capture_help():
            root_obj.setProperty("showHelp", True)
            out_path = Path(__file__).resolve().parent / "screenshot_help.png"
            root_obj.captureScreenshot(str(out_path), False)
            QTimer.singleShot(400, app.quit)
        QTimer.singleShot(450, capture_help)

    print("Parking Jam running. Press Esc or ? for help, R to restart.")
    sys.exit(app.exec())

if __name__ == "__main__":
    main()

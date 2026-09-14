#!/usr/bin/env python3
"""
Omarchy Arcade • Nuts Sort
Tactile Isometric Nut & Bolt Color Sorting Puzzle.

Features:
- Native Omarchy Desktop theme hot-reloading (~/.config/omarchy/current/theme/colors.toml)
- Native OS theme synchronization (macOS/system Dark vs Light mode via QStyleHints)
- CoreAudio low-latency sound synthesis on macOS + PipeWire/PulseAudio on Linux
- QSettings persistent level progression and move records
- Canonical arcade splashscreen and responsive layout standard
- CLI tools: --theme, --list-themes, --no-splash, --screenshot, --screenshot-help, --level <N>
"""

import os
import sys
import re
import shutil
import subprocess
import tomllib
import ctypes
from pathlib import Path
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QFileSystemWatcher, QTimer, QObject, Slot, QSettings, Qt

# =============================================================================
# THEME PRESETS
# =============================================================================
DEFAULT_PRESETS = {
    "dark": {
        "id": "catppuccin",
        "name": "Catppuccin Mocha",
        "bg": "#181825",
        "boardBg": "#11111b",
        "cardBg": "#1e1e2e",
        "surface": "#1e1e2e",
        "border": "#313244",
        "fg": "#cdd6f4",
        "subtext": "#a6adc8",
        "accent": "#F59E0B",
    },
    "light": {
        "id": "catppuccin-latte",
        "name": "Catppuccin Latte",
        "bg": "#f8fafc",
        "boardBg": "#f1f5f9",
        "cardBg": "#ffffff",
        "surface": "#ffffff",
        "border": "#cbd5e1",
        "fg": "#0f172a",
        "subtext": "#64748b",
        "accent": "#d97706",
    },
}

# =============================================================================
# PERSISTENT SETTINGS MANAGER
# =============================================================================
class SettingsManager(QObject):
    """Provides local persistence via QSettings."""
    def __init__(self, game_id="NutsSort", parent=None):
        super().__init__(parent)
        self.settings = QSettings("Arcade", game_id)

    @Slot(result=int)
    def getUnlockedLevel(self):
        try:
            return max(1, int(self.settings.value("unlockedLevel", 1)))
        except (ValueError, TypeError):
            return 1

    @Slot(int)
    def setUnlockedLevel(self, lvl):
        curr = self.getUnlockedLevel()
        if lvl > curr:
            self.settings.setValue("unlockedLevel", int(lvl))

    @Slot(result=int)
    def getLastLevel(self):
        try:
            return max(1, int(self.settings.value("lastLevel", self.getUnlockedLevel())))
        except (ValueError, TypeError):
            return 1

    @Slot(int)
    def setLastLevel(self, lvl):
        self.settings.setValue("lastLevel", max(1, int(lvl)))

    @Slot(int, result=int)
    def getBestMoves(self, level):
        try:
            return int(self.settings.value(f"bestMoves_lvl_{level}", 0))
        except (ValueError, TypeError):
            return 0

    @Slot(int, int)
    def setBestMoves(self, level, moves):
        curr = self.getBestMoves(level)
        if curr == 0 or moves < curr:
            self.settings.setValue(f"bestMoves_lvl_{level}", int(moves))

    @Slot(str, str)
    def setValue(self, key, val):
        self.settings.setValue(key, val)

    @Slot(str, str, result=str)
    def getValue(self, key, default_val=""):
        return str(self.settings.value(key, default_val))

# =============================================================================
# NATIVE SOUND MANAGER
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
            except Exception:
                self.is_mac = False

        if not self.is_mac:
            self.player_cmd = shutil.which("pw-play") or shutil.which("paplay") or shutil.which("aplay")

    @Slot(str)
    def play(self, name):
        self.playSound(name)

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
# THEME UTILITIES
# =============================================================================
def find_omarchy_colors_file():
    env_path = os.environ.get("OMARCHY_THEME_FILE")
    if env_path and Path(env_path).is_file():
        return Path(env_path)

    home = Path.home()
    candidates = [
        home / ".local" / "state" / "omarchy" / "current" / "theme" / "colors.toml",
        home / ".config" / "omarchy" / "current" / "theme" / "colors.toml",
        home / ".local" / "state" / "omarchy" / "theme" / "colors.toml",
        home / ".config" / "omarchy" / "colors.toml",
    ]
    for c in candidates:
        if c.is_file():
            return c
    return None

def load_toml_colors(file_path):
    try:
        with open(file_path, "rb") as f:
            data = tomllib.load(f)
        if isinstance(data, dict) and "colors" in data and isinstance(data["colors"], dict):
            merged = dict(data)
            merged.update(data["colors"])
            return merged
        return data
    except Exception as e:
        print(f"Warning: Failed to load {file_path}: {e}", file=sys.stderr)
        return None

# =============================================================================
# MAIN ENTRYPOINT
# =============================================================================
def main():
    os.environ["QT_ENABLE_HIGHDPI_SCALING"] = "1"
    os.environ["QML_XHR_ALLOW_FILE_READ"] = "1"

    app = QGuiApplication(sys.argv)
    app.setApplicationName("Nuts Sort")
    app.setOrganizationName("Omarchy")

    engine = QQmlApplicationEngine()

    sound_mgr = SoundManager(Path(__file__).resolve().parent / "sounds")
    engine.rootContext().setContextProperty("soundManager", sound_mgr)

    settings_mgr = SettingsManager("NutsSort")
    engine.rootContext().setContextProperty("settingsManager", settings_mgr)

    qml_file = Path(__file__).resolve().parent / "main.qml"
    engine.load(str(qml_file))

    if not engine.rootObjects():
        print("Error: Failed to load QML root object.", file=sys.stderr)
        sys.exit(1)

    root_obj = engine.rootObjects()[0]

    # CLI Theme Argument Parsing
    theme_arg = None
    if "--theme" in sys.argv:
        idx = sys.argv.index("--theme")
        if idx + 1 < len(sys.argv):
            theme_arg = sys.argv[idx + 1]

    # 1. Explicit Theme CLI Override
    if theme_arg:
        clean_arg = theme_arg.lower().replace("_", "-")
        if clean_arg in DEFAULT_PRESETS:
            t = DEFAULT_PRESETS[clean_arg]
            root_obj.applyTheme(t, t["name"])
            print(f"Applied preset theme: {t['name']}")
        else:
            custom_path = Path(theme_arg).expanduser().resolve()
            if custom_path.is_file():
                data = load_toml_colors(custom_path)
                if data:
                    root_obj.applyTheme(data, custom_path.parent.name.capitalize())
                    print(f"Applied theme from file: {custom_path}")
            else:
                # Fallback to light or dark preset if matches term
                if "light" in clean_arg:
                    t = DEFAULT_PRESETS["light"]
                    root_obj.applyTheme(t, t["name"])
                else:
                    t = DEFAULT_PRESETS["dark"]
                    root_obj.applyTheme(t, t["name"])

    # 2. Omarchy Desktop System Theme Detection & Hot-Reloading
    else:
        system_colors = find_omarchy_colors_file()
        if system_colors:
            data = load_toml_colors(system_colors)
            if data:
                theme_name = system_colors.parent.name.capitalize()
                root_obj.applyTheme(data, theme_name)
                print(f"Detected Omarchy theme: {theme_name} ({system_colors})")

            # Watch for real-time desktop theme switches
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
                    target_theme = DEFAULT_PRESETS["light"]
                else:
                    target_theme = DEFAULT_PRESETS["dark"]

                root_obj.applyTheme(target_theme, target_theme["name"])
                print(f"Detected OS appearance: {target_theme['name']}")

            apply_system_scheme()
            app.styleHints().colorSchemeChanged.connect(lambda _: apply_system_scheme())

    # Optional CLI --level jump
    if "--level" in sys.argv:
        idx = sys.argv.index("--level")
        if idx + 1 < len(sys.argv):
            try:
                lvl = int(sys.argv[idx + 1])
                root_obj.jumpToLevel(lvl)
            except ValueError:
                pass

    if "--no-splash" in sys.argv:
        root_obj.setProperty("splashEnabled", False)

    # Screenshot / automation helpers
    if "--screenshot" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        out_idx = sys.argv.index("--screenshot") + 1
        out_file = sys.argv[out_idx] if out_idx < len(sys.argv) and not sys.argv[out_idx].startswith("--") else "screenshot.png"
        out_path = Path(out_file).resolve()
        root_obj.screenshotSaved.connect(lambda p: app.quit())
        QTimer.singleShot(250, lambda: root_obj.captureScreenshot(str(out_path), False))

    print("Nuts Sort running. Press ? or Esc for help, R to restart, U to undo.")
    sys.exit(app.exec())

if __name__ == "__main__":
    main()

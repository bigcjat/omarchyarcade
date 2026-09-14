#!/usr/bin/env python3
"""
Omarchy Arcade • Fold
Cross-platform PySide6 host supporting Omarchy Linux, macOS, and standard Linux/Windows desktops.
"""

import os
import sys
import shutil
import subprocess
import tomllib
import ctypes
from pathlib import Path
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QFileSystemWatcher, QTimer, QObject, Slot, QSettings, Qt

# =============================================================================
# THEME PRESETS
# =============================================================================
DEFAULT_PRESETS = {
    "dark": {
        "id": "catppuccin",
        "name": "Catppuccin Mocha",
        "background": "#181825",
        "board_bg": "#11111b",
        "surface": "#1e1e2e",
        "card_bg": "#1e1e2e",
        "border": "#313244",
        "foreground": "#cdd6f4",
        "subtext": "#a6adc8",
        "accent": "#f28482",
    },
    "light": {
        "id": "catppuccin-latte",
        "name": "Catppuccin Latte",
        "background": "#f8fafc",
        "board_bg": "#f1f5f9",
        "surface": "#ffffff",
        "card_bg": "#ffffff",
        "border": "#cbd5e1",
        "foreground": "#0f172a",
        "subtext": "#64748b",
        "accent": "#d20f39",
    },
}

# =============================================================================
# PERSISTENT SETTINGS MANAGER
# =============================================================================
class SettingsManager(QObject):
    """Provides local persistence via QSettings."""
    def __init__(self, game_id="Fold", parent=None):
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
    def getStars(self, level):
        try:
            return int(self.settings.value(f"stars_lvl_{level}", 0))
        except (ValueError, TypeError):
            return 0

    @Slot(int, int)
    def setStars(self, level, stars):
        curr = self.getStars(level)
        if stars > curr:
            self.settings.setValue(f"stars_lvl_{level}", int(stars))

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
    app.setApplicationName("Fold")
    app.setOrganizationName("Arcade")
    # Set application icon to game floppy disk
    script_dir = Path(__file__).resolve().parent
    icon_path = script_dir / "assets" / "disk_icon.png"
    if icon_path.exists():
        app.setWindowIcon(QIcon(str(icon_path)))

    engine = QQmlApplicationEngine()
    engine.quit.connect(app.quit)

    sound_mgr = SoundManager(Path(__file__).resolve().parent / "sounds")
    engine.rootContext().setContextProperty("soundManager", sound_mgr)

    settings_mgr = SettingsManager("Fold")
    engine.rootContext().setContextProperty("settingsManager", settings_mgr)

    qml_file = Path(__file__).resolve().parent / "main.qml"
    engine.load(str(qml_file))

    if not engine.rootObjects():
        print("Error: Failed to load QML root object.", file=sys.stderr)
        sys.exit(1)

    root_obj = engine.rootObjects()[0]

    icon_path = Path(__file__).resolve().parent / "assets" / "disk_icon.png"

    if icon_path.exists() and hasattr(root_obj, "setIcon"):

        root_obj.setIcon(QIcon(str(icon_path)))

    # Theme Resolution
    theme_arg = None
    if "--theme" in sys.argv:
        idx = sys.argv.index("--theme")
        if idx + 1 < len(sys.argv):
            theme_arg = sys.argv[idx + 1]

    if theme_arg:
        clean = theme_arg.lower().replace("_", "-")
        if clean in DEFAULT_PRESETS:
            t = DEFAULT_PRESETS[clean]
            root_obj.applyTheme(t, t["name"])
        elif any(term in clean for term in ["light", "white", "day", "snow", "dawn"]):
            t = DEFAULT_PRESETS["light"]
            root_obj.applyTheme(t, t["name"])
        else:
            custom_path = Path(theme_arg).expanduser().resolve()
            if custom_path.is_file():
                data = load_toml_colors(custom_path)
                if data:
                    root_obj.applyTheme(data, custom_path.parent.name.capitalize())
            else:
                t = DEFAULT_PRESETS["dark"]
                root_obj.applyTheme(t, t["name"])
    else:
        system_colors = find_omarchy_colors_file()
        if system_colors:
            data = load_toml_colors(system_colors)
            if data:
                root_obj.applyTheme(data, system_colors.parent.name.capitalize())

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

            watcher.fileChanged.connect(on_theme_updated)
            watcher.directoryChanged.connect(on_theme_updated)
        else:
            def apply_system_scheme():
                scheme = app.styleHints().colorScheme()
                preset_key = "light" if scheme == Qt.ColorScheme.Light else "dark"
                t = DEFAULT_PRESETS[preset_key]
                root_obj.applyTheme(t, t["name"])

            apply_system_scheme()
            app.styleHints().colorSchemeChanged.connect(lambda _: apply_system_scheme())

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

    if "--unmute" in sys.argv or "--sound" in sys.argv:
        for _obj in engine.rootObjects():
            _obj.setProperty("isMuted", False)
    elif "--mute" in sys.argv:
        for _obj in engine.rootObjects():
            _obj.setProperty("isMuted", True)

    if "--width" in sys.argv:
        try:
            w = int(sys.argv[sys.argv.index("--width") + 1])
            root_obj.setWidth(w)
        except (ValueError, IndexError):
            pass

    if "--height" in sys.argv:
        try:
            h = int(sys.argv[sys.argv.index("--height") + 1])
            root_obj.setHeight(h)
        except (ValueError, IndexError):
            pass

    # Screenshot automation
    if "--screenshot" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        out_idx = sys.argv.index("--screenshot") + 1
        out_file = sys.argv[out_idx] if out_idx < len(sys.argv) and not sys.argv[out_idx].startswith("--") else "screenshot.png"
        out_path = Path(out_file).resolve()

        if hasattr(root_obj, "screenshotSaved"):
            root_obj.screenshotSaved.connect(lambda p: app.quit())
        QTimer.singleShot(250, lambda: root_obj.captureScreenshot(str(out_path), False))
        QTimer.singleShot(2000, app.quit)

    print("Fold running. Press Esc or ? for help, 1-4 for colors, U to undo, R to restart.")
    sys.exit(app.exec())

if __name__ == "__main__":
    main()

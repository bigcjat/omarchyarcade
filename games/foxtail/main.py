#!/usr/bin/env python3
"""
Omarchy Arcade • Foxtail
Cross-platform PySide6 host supporting Omarchy Linux, macOS, and standard Linux/Windows desktops.
"""

import os
import sys
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
        "background": "#1e1e2e",
        "board_bg": "#181825",
        "surface": "#313244",
        "card_bg": "#313244",
        "border": "#45475a",
        "foreground": "#cdd6f4",
        "subtext": "#a6adc8",
        "accent": "#f97316",
    },
    "light": {
        "id": "catppuccin-latte",
        "name": "Catppuccin Latte",
        "background": "#eff1f5",
        "board_bg": "#181825",
        "surface": "#ffffff",
        "card_bg": "#ffffff",
        "border": "#ccd0da",
        "foreground": "#4c4f69",
        "subtext": "#6c6f85",
        "accent": "#ea580c",
    },
}

# =============================================================================
# PERSISTENT SETTINGS MANAGER
# =============================================================================
class SettingsManager(QObject):
    """Provides local persistence via QSettings."""
    def __init__(self, game_id="Foxtail", parent=None):
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
    app.setApplicationName("Foxtail")
    app.setOrganizationName("OmarchyArcade")

    engine = QQmlApplicationEngine()
    engine.quit.connect(app.quit)

    sound_mgr = SoundManager(Path(__file__).resolve().parent / "sounds")
    engine.rootContext().setContextProperty("soundManager", sound_mgr)

    settings_mgr = SettingsManager("Foxtail")
    engine.rootContext().setContextProperty("settingsManager", settings_mgr)

    qml_file = Path(__file__).resolve().parent / "main.qml"
    engine.load(str(qml_file))

    if not engine.rootObjects():
        print("Error: Failed to load QML root object.", file=sys.stderr)
        sys.exit(1)

    root_obj = engine.rootObjects()[0]

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
        elif any(term in clean for term in ["light", "white", "day", "snow", "dawn", "latte"]):
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

    if "--no-splash" in sys.argv:
        root_obj.setProperty("splashEnabled", False)

    # Screenshot automation
    if "--screenshot" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        out_idx = sys.argv.index("--screenshot") + 1
        out_file = sys.argv[out_idx] if out_idx < len(sys.argv) and not sys.argv[out_idx].startswith("--") else "screenshot.png"
        out_path = Path(out_file).resolve()

        def capture():
            if "--level" in sys.argv:
                lvl_idx = int(sys.argv[sys.argv.index("--level") + 1])
                root_obj.loadLevel(lvl_idx)
            if "--blink" in sys.argv:
                root_obj.setProperty("isBlinking", True)
            if "--moves" in sys.argv:
                mv_str = sys.argv[sys.argv.index("--moves") + 1]
                for ch in mv_str:
                    if ch == 'U': root_obj.move(0, -1)
                    elif ch == 'D': root_obj.move(0, 1)
                    elif ch == 'L': root_obj.move(-1, 0)
                    elif ch == 'R': root_obj.move(1, 0)
            if "--hint" in sys.argv:
                root_obj.triggerHint()

            if hasattr(root_obj, "screenshotSaved"):
                root_obj.screenshotSaved.connect(lambda p: app.quit())
            QTimer.singleShot(250, lambda: root_obj.captureScreenshot(str(out_path), False))
            QTimer.singleShot(2000, app.quit)

        QTimer.singleShot(350, capture)

    if "--screenshot-help" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        def capture_help():
            root_obj.setProperty("showHelp", True)
            out_path = Path(__file__).resolve().parent / "screenshot_help.png"
            if hasattr(root_obj, "screenshotSaved"):
                root_obj.screenshotSaved.connect(lambda p: app.quit())
            QTimer.singleShot(250, lambda: root_obj.captureScreenshot(str(out_path), False))
            QTimer.singleShot(2000, app.quit)
        QTimer.singleShot(350, capture_help)

    print("Foxtail running. Press Esc or ? for help, R to restart.")
    sys.exit(app.exec())

if __name__ == "__main__":
    main()

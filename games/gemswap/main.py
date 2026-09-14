#!/usr/bin/env python3
"""
Omarchy Arcade: GemSwap (Match-3 Arcade)
- Native Omarchy Desktop theme hot-reloading (~/.config/omarchy/current/theme/colors.toml)
- Native OS theme synchronization (detects macOS/system Dark vs Light mode via QStyleHints)
- CoreAudio low-latency sound synthesis on macOS (0ms delay) + PipeWire/PulseAudio on Linux
- QSettings persistent score/save state management
- Fully responsive arcade board with canonical retro splashscreen
"""

import os
import sys
import tomllib
import ctypes
import shutil
import subprocess
from pathlib import Path
from PySide6.QtGui import QIcon, QGuiApplication
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
        "accent": "#cba6f7",
    },
    "light": {
        "id": "catppuccin-latte",
        "name": "Catppuccin Latte",
        "bg": "#eff1f5",
        "boardBg": "#11111b",
        "cardBg": "#ffffff",
        "surface": "#ffffff",
        "border": "#ccd0da",
        "fg": "#4c4f69",
        "subtext": "#6c6f85",
        "accent": "#8839ef",
    },
}

# =============================================================================
# PERSISTENT SETTINGS MANAGER
# =============================================================================
class SettingsManager(QObject):
    """Provides local persistence via QSettings."""
    def __init__(self, game_id="GemSwap", parent=None):
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

def parse_toml_theme(file_path):
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
    app.setApplicationName("GemSwap")
    app.setOrganizationName("Arcade")

    script_dir = Path(__file__).resolve().parent
    disk_candidates = [
        script_dir / "assets" / "disk_icon.png",
        script_dir.parent.parent / "assets" / "covers" / "gemswap_disk.png",
        Path.home() / ".local" / "share" / "omarchy-arcade" / "assets" / "covers" / "gemswap_disk.png",
    ]
    for cp in disk_candidates:
        if cp.exists():
            app.setWindowIcon(QIcon(str(cp)))
            break

    engine = QQmlApplicationEngine()

    sound_mgr = SoundManager(script_dir / "sounds")
    engine.rootContext().setContextProperty("soundManager", sound_mgr)

    settings_mgr = SettingsManager("GemSwap")
    engine.rootContext().setContextProperty("settingsManager", settings_mgr)

    qml_file = script_dir / "main.qml"
    engine.load(str(qml_file))

    if not engine.rootObjects():
        print("Error: Failed to load QML root object.", file=sys.stderr)
        sys.exit(1)

    root = engine.rootObjects()[0]

    # CLI Theme Argument Parsing
    theme_arg = None
    if "--theme" in sys.argv:
        idx = sys.argv.index("--theme")
        if idx + 1 < len(sys.argv):
            theme_arg = sys.argv[idx + 1]

    if theme_arg:
        clean = theme_arg.lower().replace("_", "-")
        if clean in DEFAULT_PRESETS:
            t = DEFAULT_PRESETS[clean]
            root.applyTheme(t, t["name"])
        elif any(term in clean for term in ["light", "white", "day", "snow", "dawn", "latte"]):
            t = DEFAULT_PRESETS["light"]
            root.applyTheme(t, t["name"])
        else:
            custom_path = Path(theme_arg).expanduser().resolve()
            if custom_path.is_file():
                data = parse_toml_theme(custom_path)
                if data:
                    root.applyTheme(data, custom_path.parent.name.capitalize())
            else:
                t = DEFAULT_PRESETS["dark"]
                root.applyTheme(t, t["name"])
    else:
        theme_path = find_omarchy_colors_file()
        if theme_path and theme_path.is_file():
            theme_data = parse_toml_theme(theme_path)
            t_name = theme_path.parent.name.capitalize()
            root.applyTheme(theme_data, t_name)

            watcher = QFileSystemWatcher(app)
            watcher.addPath(str(theme_path))
            if theme_path.parent.exists():
                watcher.addPath(str(theme_path.parent))

            def on_theme_updated(path):
                colors_path = find_omarchy_colors_file()
                if colors_path and colors_path.is_file():
                    updated = parse_toml_theme(colors_path)
                    if updated:
                        root.applyTheme(updated, colors_path.parent.name.capitalize())

            watcher.fileChanged.connect(on_theme_updated)
            watcher.directoryChanged.connect(on_theme_updated)
        else:
            def apply_system_scheme():
                scheme = app.styleHints().colorScheme()
                preset_key = "light" if scheme == Qt.ColorScheme.Light else "dark"
                t = DEFAULT_PRESETS[preset_key]
                root.applyTheme(t, t["name"])

            apply_system_scheme()
            app.styleHints().colorSchemeChanged.connect(lambda _: apply_system_scheme())

    if "--no-splash" in sys.argv:
        root.setProperty("splashEnabled", False)

    # Screenshot automation
    if "--screenshot" in sys.argv:
        root.setProperty("splashEnabled", False)
        out_idx = sys.argv.index("--screenshot") + 1
        out_file = sys.argv[out_idx] if out_idx < len(sys.argv) and not sys.argv[out_idx].startswith("--") else "screenshot.png"
        out_path = Path(out_file).resolve()

        if hasattr(root, "screenshotSaved"):
            root.screenshotSaved.connect(lambda p: app.quit())
        QTimer.singleShot(250, lambda: root.captureScreenshot(str(out_path), False))
        QTimer.singleShot(2000, app.quit)

    if "--screenshot-help" in sys.argv:
        root.setProperty("splashEnabled", False)
        def capture_help():
            root.setProperty("showHelp", True)
            out_path = script_dir / "screenshot_help.png"
            root.captureScreenshot(str(out_path), False)
        if hasattr(root, "screenshotSaved"):
            root.screenshotSaved.connect(lambda p: app.quit())
        QTimer.singleShot(250, capture_help)
        QTimer.singleShot(2000, app.quit)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

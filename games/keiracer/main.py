#!/usr/bin/env python3
"""
Omarchy Arcade • KeiRacer Entrypoint
High-performance pseudo-3D retro arcade racer built with PySide6 and QML.

Features:
- Omarchy desktop theme hot-reloading (~/.config/omarchy/current/theme/colors.toml)
- System appearance synchronization (Light vs Dark mode via QStyleHints)
- Native low-latency sound synthesis and procedural audio playback
- QSettings persistent high-score and distance tracking
- Canonical splashscreen and responsive arcade layout
"""

import os
import sys
import tomllib
import ctypes
import shutil
import subprocess
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"

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
        "bg": "#0f172a",
        "boardBg": "#020617",
        "cardBg": "#1e293b",
        "surface": "#1e293b",
        "border": "#334155",
        "fg": "#f8fafc",
        "subtext": "#94a3b8",
        "accent": "#00f0ff",
        "pink": "#ff007f",
    },
    "light": {
        "id": "catppuccin-latte",
        "name": "Catppuccin Latte",
        "bg": "#eff1f5",
        "boardBg": "#020617",
        "cardBg": "#ffffff",
        "surface": "#ffffff",
        "border": "#ccd0da",
        "fg": "#4c4f69",
        "subtext": "#6c6f85",
        "accent": "#0284c7",
        "pink": "#d20f39",
    },
}

# =============================================================================
# PERSISTENT SETTINGS MANAGER
# =============================================================================
class SettingsManager(QObject):
    """Provides local persistence via QSettings."""
    def __init__(self, game_id="KeiRacer", parent=None):
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
    Low-latency audio dispatcher.
    Uses AudioServices system sound IDs when available, falling back to PipeWire,
    PulseAudio, or ALSA.
    """
    def __init__(self, sounds_dir, parent=None):
        super().__init__(parent)
        self.sounds_dir = Path(sounds_dir)
        self.sounds = {}
        self.has_audio_toolbox = False

        if sys.platform == "darwin":
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
                self.has_audio_toolbox = True
            except Exception:
                self.has_audio_toolbox = False

        if not self.has_audio_toolbox:
            self.player_cmd = shutil.which("pw-play") or shutil.which("paplay") or shutil.which("aplay")

        # Procedural real-time engine acoustic synthesizer
        try:
            from audio_engine import ProceduralEngineAudio
            self.engine_audio = ProceduralEngineAudio()
            self.engine_audio.start()
        except Exception as e:
            print("Warning: Could not start procedural audio engine:", e)
            self.engine_audio = None

    @Slot(str, float, bool, float, bool, bool)
    def updateEngineAudio(self, car_id, rpm, is_accelerating, speed, is_shift_cut, is_muted):
        if self.engine_audio:
            self.engine_audio.update_state(car_id, rpm, is_accelerating, speed, is_shift_cut, is_muted)

    @Slot()
    def stop(self):
        if self.engine_audio:
            self.engine_audio.stop()

    @Slot(str)
    def play(self, name):
        self.playSound(name)

    @Slot(str)
    def playSound(self, name):
        if self.has_audio_toolbox and name in self.sounds:
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
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"

    app = QGuiApplication(sys.argv)
    app.setApplicationName("KeiRacer")
    app.setOrganizationName("Arcade")

    script_dir = Path(__file__).resolve().parent
    disk_candidates = [
        script_dir / "assets" / "disk_icon.png",
        script_dir.parent.parent / "assets" / "covers" / "keiracer_disk.png",
        Path.home() / ".local" / "share" / "omarchy-arcade" / "assets" / "covers" / "keiracer_disk.png",
    ]
    for cp in disk_candidates:
        if cp.exists():
            app.setWindowIcon(QIcon(str(cp)))
            break

    engine = QQmlApplicationEngine()

    sound_mgr = SoundManager(script_dir / "sounds")
    app.aboutToQuit.connect(sound_mgr.stop)
    engine.rootContext().setContextProperty("soundManager", sound_mgr)

    settings_mgr = SettingsManager("KeiRacer")
    engine.rootContext().setContextProperty("settingsManager", settings_mgr)

    qml_file = script_dir / "main.qml"
    engine.load(str(qml_file))

    if not engine.rootObjects():
        print("Error: Failed to load QML root object.", file=sys.stderr)
        sys.exit(1)

    root = engine.rootObjects()[0]

    icon_path = Path(__file__).resolve().parent / "assets" / "disk_icon.png"

    if icon_path.exists() and hasattr(root, "setIcon"):

        root.setIcon(QIcon(str(icon_path)))

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

    if "--width" in sys.argv:
        w_idx = sys.argv.index("--width") + 1
        if w_idx < len(sys.argv):
            root.setWidth(int(sys.argv[w_idx]))

    if "--height" in sys.argv:
        h_idx = sys.argv.index("--height") + 1
        if h_idx < len(sys.argv):
            root.setHeight(int(sys.argv[h_idx]))

    if "--no-splash" in sys.argv:
        root.setProperty("splashEnabled", False)

    if "--unmute" in sys.argv or "--sound" in sys.argv:
        for _obj in engine.rootObjects():
            _obj.setProperty("isMuted", False)
    elif "--mute" in sys.argv:
        for _obj in engine.rootObjects():
            _obj.setProperty("isMuted", True)

    if "--car" in sys.argv:
        c_idx = sys.argv.index("--car") + 1
        if c_idx < len(sys.argv) and not sys.argv[c_idx].startswith("--"):
            car_id = sys.argv[c_idx].lower()
            root.setProperty("selectedCar", car_id)
            root.setProperty("showCarSelect", False)

    # Screenshot / automation helpers
    if "--screenshot" in sys.argv:
        root.setProperty("splashEnabled", False)
        root.setProperty("showCarSelect", False)
        out_idx = sys.argv.index("--screenshot") + 1
        out_file = sys.argv[out_idx] if out_idx < len(sys.argv) and not sys.argv[out_idx].startswith("--") else "screenshot.png"
        out_path = Path(out_file).resolve()

        if hasattr(root, "screenshotSaved"):
            root.screenshotSaved.connect(lambda p: app.quit())
        QTimer.singleShot(250, lambda: root.captureScreenshot(str(out_path), False))
        QTimer.singleShot(2000, app.quit)

    if "--screenshot-help" in sys.argv:
        root.setProperty("splashEnabled", False)
        root.setProperty("showCarSelect", False)
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

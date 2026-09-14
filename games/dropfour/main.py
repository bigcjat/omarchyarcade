#!/usr/bin/env python3
"""
DropFour - Sleek Modern Retro Connect Four for macOS & Omarchy Linux.
Features:
- Native Omarchy Desktop theme hot-reloading
- Native OS theme synchronization (detects macOS/system Dark vs Light mode via QStyleHints)
- CoreAudio low-latency sound synthesis on macOS + PipeWire/PulseAudio on Linux
- Match record tracking via QSettings
- Responsive 2048 layout integration with canonical splashscreen
- CLI tools: --theme, --list-themes, --no-splash, --screenshot, --screenshot-help
"""

import os
import sys
import shutil
import subprocess
import tomllib
import ctypes
from pathlib import Path
from PySide6.QtGui import QIcon, QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QFileSystemWatcher, QTimer, QObject, Slot, QSettings, Qt

# =============================================================================
# PERSISTENT SETTINGS MANAGER
# =============================================================================
class SettingsManager(QObject):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.settings = QSettings("Arcade", "DropFour")

    @Slot(str, result=int)
    def getStat(self, key):
        try:
            val = self.settings.value(key, 0)
            return int(val) if val is not None else 0
        except (ValueError, TypeError):
            return 0

    @Slot(str, int)
    def setStat(self, key, val):
        self.settings.setValue(key, int(val))

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
    def __init__(self, sounds_dir, parent=None):
        super().__init__(parent)
        self.sounds_dir = Path(sounds_dir)
        self.sounds = {}
        self.is_mac = sys.platform == "darwin"
        self.audiotoolbox = None
        self.player_cmd = None

        if self.is_mac:
            try:
                self.audiotoolbox = ctypes.cdll.LoadLibrary(
                    "/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox"
                )
                self.audiotoolbox.AudioServicesCreateSystemSoundID.argtypes = [
                    ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32)
                ]
                self.audiotoolbox.AudioServicesPlaySystemSound.argtypes = [ctypes.c_uint32]
                self.cf = ctypes.cdll.LoadLibrary(
                    "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"
                )
                self.cf.CFURLCreateFromFileSystemRepresentation.argtypes = [
                    ctypes.c_void_p, ctypes.c_char_p, ctypes.c_long, ctypes.c_bool
                ]
                self.cf.CFURLCreateFromFileSystemRepresentation.restype = ctypes.c_void_p
                self.cf.CFRelease.argtypes = [ctypes.c_void_p]
            except Exception as e:
                print(f"[SoundManager] CoreAudio load failed: {e}")
                self.audiotoolbox = None
        else:
            self.player_cmd = shutil.which("pw-play") or shutil.which("paplay") or shutil.which("aplay")

        self.preload_sounds()

    def preload_sounds(self):
        sound_names = ["drop", "win"]
        for name in sound_names:
            wav_path = self.sounds_dir / f"{name}.wav"
            if not wav_path.exists():
                continue
            if self.is_mac and self.audiotoolbox:
                try:
                    c_path = str(wav_path.resolve()).encode("utf-8")
                    cf_url = self.cf.CFURLCreateFromFileSystemRepresentation(None, c_path, len(c_path), False)
                    if cf_url:
                        sound_id = ctypes.c_uint32(0)
                        status = self.audiotoolbox.AudioServicesCreateSystemSoundID(
                            cf_url, ctypes.byref(sound_id)
                        )
                        self.cf.CFRelease(cf_url)
                        if status == 0:
                            self.sounds[name] = sound_id.value
                except Exception as e:
                    print(f"[SoundManager] Error loading sound {name}: {e}")
            else:
                self.sounds[name] = str(wav_path)

    @Slot(str)
    def play(self, sound_name):
        if not sound_name or sound_name not in self.sounds:
            return
        if self.is_mac and self.audiotoolbox:
            sound_id = self.sounds[sound_name]
            self.audiotoolbox.AudioServicesPlaySystemSound(ctypes.c_uint32(sound_id))
        elif self.player_cmd:
            wav_path = self.sounds[sound_name]
            try:
                subprocess.Popen([self.player_cmd, wav_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception:
                pass

# =============================================================================
# THEME UTILITIES
# =============================================================================
DEFAULT_PRESETS = {
    "dark": {
        "name": "Omarchy Dark",
        "background": "#181825",
        "foreground": "#cdd6f4",
        "accent": "#89b4fa",
        "color0": "#181825",
        "color8": "#313244",
        "cardBg": "#1e1e2e",
        "boardBg": "#1e293b",
        "border": "#313244",
        "subtext": "#a6adc8",
    },
    "light": {
        "name": "Omarchy Light",
        "background": "#eff1f5",
        "foreground": "#4c4f69",
        "accent": "#1e66f5",
        "color0": "#e6e9ef",
        "color8": "#bcc0cc",
        "cardBg": "#ffffff",
        "boardBg": "#2563eb",
        "border": "#ccd0da",
        "subtext": "#5c5f77",
    },
}

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

    if "--list-themes" in sys.argv:
        print("DropFour • Preset Themes:\n  --theme light\n  --theme dark\n  --theme <path_to_colors.toml>")
        sys.exit(0)

    app = QGuiApplication(sys.argv)
    app.setApplicationName("DropFour")
    app.setOrganizationName("Arcade")

    script_dir = Path(__file__).resolve().parent
    disk_candidates = [
        script_dir / "assets" / "disk_icon.png",
        script_dir.parent.parent / "assets" / "covers" / "dropfour_disk.png",
        Path.home() / ".local" / "share" / "omarchy-arcade" / "assets" / "covers" / "dropfour_disk.png",
    ]
    for cp in disk_candidates:
        if cp.exists():
            app.setWindowIcon(QIcon(str(cp)))
            break

    engine = QQmlApplicationEngine()

    sound_mgr = SoundManager(Path(__file__).resolve().parent / "sounds")
    engine.rootContext().setContextProperty("soundManager", sound_mgr)

    settings_mgr = SettingsManager()
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

    theme_arg = None
    if "--theme" in sys.argv:
        idx = sys.argv.index("--theme")
        if idx + 1 < len(sys.argv):
            theme_arg = sys.argv[idx + 1]

    if theme_arg:
        clean_arg = theme_arg.lower().strip()
        if clean_arg in DEFAULT_PRESETS:
            t = DEFAULT_PRESETS[clean_arg]
            root_obj.applyTheme(t, t["name"])
        else:
            custom_path = Path(theme_arg).expanduser().resolve()
            if custom_path.is_file():
                data = load_toml_colors(custom_path)
                if data:
                    root_obj.applyTheme(data, custom_path.parent.name.capitalize())
    else:
        system_colors = find_omarchy_colors_file()
        if system_colors:
            data = load_toml_colors(system_colors)
            if data:
                theme_name = system_colors.parent.name.capitalize()
                root_obj.applyTheme(data, theme_name)

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
                if scheme == Qt.ColorScheme.Light:
                    target_theme = DEFAULT_PRESETS["light"]
                else:
                    target_theme = DEFAULT_PRESETS["dark"]

                root_obj.applyTheme(target_theme, target_theme["name"])

            apply_system_scheme()
            app.styleHints().colorSchemeChanged.connect(lambda _: apply_system_scheme())

    if "--no-splash" in sys.argv:
        root_obj.setProperty("splashEnabled", False)

    if "--unmute" in sys.argv or "--sound" in sys.argv:
        for _obj in engine.rootObjects():
            _obj.setProperty("isMuted", False)
    elif "--mute" in sys.argv:
        for _obj in engine.rootObjects():
            _obj.setProperty("isMuted", True)

    # Screenshot / automation helpers
    if "--screenshot" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        def capture():
            out_idx = sys.argv.index("--screenshot") + 1
            out_file = sys.argv[out_idx] if out_idx < len(sys.argv) and not sys.argv[out_idx].startswith("--") else "screenshot.png"
            out_path = Path(out_file).resolve()
            if hasattr(root_obj, "screenshotSaved"):
                root_obj.screenshotSaved.connect(lambda p: app.quit())
                root_obj.captureScreenshot(str(out_path), False)
            else:
                root_obj.captureScreenshot(str(out_path), False)
                QTimer.singleShot(400, app.quit)
        QTimer.singleShot(350, capture)

    if "--screenshot-help" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        def capture_help():
            root_obj.setProperty("showHelp", True)
            out_path = Path(__file__).resolve().parent / "screenshot_help.png"
            if hasattr(root_obj, "screenshotSaved"):
                root_obj.screenshotSaved.connect(lambda p: app.quit())
                root_obj.captureScreenshot(str(out_path), False)
            else:
                root_obj.captureScreenshot(str(out_path), False)
                QTimer.singleShot(400, app.quit)
        QTimer.singleShot(350, capture_help)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

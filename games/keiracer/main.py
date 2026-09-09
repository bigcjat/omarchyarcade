#!/usr/bin/env python3
"""
Omarchy Arcade • KeiRacer Entrypoint
High-performance pseudo-3D retro arcade racer built with PySide6 and QML.

Features:
- Omarchy desktop theme hot-reloading (~/.config/omarchy/current/theme/colors.toml)
- System appearance synchronization (Light vs Dark mode)
- Native low-latency sound synthesis and playback
- QSettings persistent high-score and distance tracking
- Canonical splashscreen and responsive arcade layout
- CLI tools: --theme, --list-themes, --no-splash, --screenshot, --screenshot-help
"""

import os
import sys
import re
import shutil
import subprocess
import tomllib
import ctypes
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"

from PySide6.QtGui import QIcon, QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QFileSystemWatcher, QTimer, QObject, Slot, QSettings, Qt

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

        # Procedural real-time engine acoustic synthesizer (AngeTheGreat cylinder math)
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
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"

    if "--list-themes" in sys.argv:
        print(f"KeiRacer • Available Themes ({len(ALL_THEMES)} total):\n")
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
    app.setApplicationName("KeiRacer")
    app.setOrganizationName("Arcade")
    # Set application icon to game floppy disk
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

    sound_mgr = SoundManager(Path(__file__).resolve().parent / "sounds")
    app.aboutToQuit.connect(sound_mgr.stop)
    engine.rootContext().setContextProperty("soundManager", sound_mgr)

    settings_mgr = SettingsManager("KeiRacer")
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

        # 3. System Dark & Light Mode Synchronization
        else:
            def apply_system_scheme():
                scheme = app.styleHints().colorScheme()
                if scheme == Qt.ColorScheme.Light:
                    target_theme = ALL_THEMES.get("catppuccin-latte") or ALL_THEMES.get("github-light")
                    name = "System Light"
                else:
                    target_theme = ALL_THEMES.get("catppuccin") or ALL_THEMES.get("tokyonight")
                    name = "System Dark"

                if target_theme:
                    root_obj.applyTheme(target_theme, name)
                    print(f"Detected appearance: {name} ({target_theme.get('name')})")

            apply_system_scheme()
            app.styleHints().colorSchemeChanged.connect(lambda _: apply_system_scheme())

    if "--width" in sys.argv:
        w_idx = sys.argv.index("--width") + 1
        if w_idx < len(sys.argv):
            root_obj.setWidth(int(sys.argv[w_idx]))

    if "--height" in sys.argv:
        h_idx = sys.argv.index("--height") + 1
        if h_idx < len(sys.argv):
            root_obj.setHeight(int(sys.argv[h_idx]))

    if "--no-splash" in sys.argv:
        root_obj.setProperty("splashEnabled", False)

    if "--car" in sys.argv:
        c_idx = sys.argv.index("--car") + 1
        if c_idx < len(sys.argv) and not sys.argv[c_idx].startswith("--"):
            car_id = sys.argv[c_idx].lower()
            root_obj.setProperty("selectedCar", car_id)
            root_obj.setProperty("showCarSelect", False)

    # Screenshot / automation helpers
    if "--screenshot" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        root_obj.setProperty("showCarSelect", False)
        def capture():
            out_idx = sys.argv.index("--screenshot") + 1
            out_file = sys.argv[out_idx] if out_idx < len(sys.argv) and not sys.argv[out_idx].startswith("--") else "screenshot.png"
            out_path = Path(out_file).resolve()
            root_obj.captureScreenshot(str(out_path), False)
            QTimer.singleShot(400, app.quit)
        QTimer.singleShot(350, capture)

    if "--screenshot-gameplay" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        root_obj.setProperty("showCarSelect", False)
        root_obj.setProperty("gamePaused", False)
        def press_gas():
            keys = root_obj.property("keysPressed")
            if isinstance(keys, dict):
                keys["up"] = True
                root_obj.setProperty("keysPressed", keys)
            elif hasattr(keys, "setProperty"):
                keys.setProperty("up", True)
        def capture_gameplay():
            out_path = Path(__file__).resolve().parent / "screenshot.png"
            root_obj.captureScreenshot(str(out_path), False)
            QTimer.singleShot(400, app.quit)
        QTimer.singleShot(150, press_gas)
        QTimer.singleShot(1400, capture_gameplay)

    if "--screenshot-sidebyside" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        root_obj.setProperty("showCarSelect", False)
        root_obj.setProperty("gamePaused", False)
        def capture_sidebyside():
            root_obj.debugSideBySide()
            out_path = Path(__file__).resolve().parent / "screenshot_sidebyside.png"
            root_obj.captureScreenshot(str(out_path), False)
            QTimer.singleShot(400, app.quit)
        QTimer.singleShot(650, capture_sidebyside)

    if "--screenshot-help" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        root_obj.setProperty("showCarSelect", False)
        def capture_help():
            root_obj.setProperty("showHelp", True)
            out_path = Path(__file__).resolve().parent / "screenshot_help.png"
            root_obj.captureScreenshot(str(out_path), False)
            QTimer.singleShot(400, app.quit)
        QTimer.singleShot(350, capture_help)

    if "--screenshot-brakes" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        root_obj.setProperty("showCarSelect", False)
        def trigger_brakes():
            keys = root_obj.property("keysPressed")
            if isinstance(keys, dict):
                keys["down"] = True
                root_obj.setProperty("keysPressed", keys)
            elif hasattr(keys, "setProperty"):
                keys.setProperty("down", True)
            def capture_brakes():
                out_path = Path(__file__).resolve().parent / "screenshot_brakes.png"
                root_obj.captureScreenshot(str(out_path), False)
                QTimer.singleShot(400, app.quit)
            QTimer.singleShot(100, capture_brakes)
        QTimer.singleShot(400, trigger_brakes)

    if "--screenshot-splash" in sys.argv:
        def capture_splash():
            out_path = Path(__file__).resolve().parent / "screenshot_splash.png"
            root_obj.captureScreenshot(str(out_path), False)
            QTimer.singleShot(400, app.quit)
        QTimer.singleShot(600, capture_splash)

    print("KeiRacer running. Press Esc or ? for help, R to restart, C for garage.")
    sys.exit(app.exec())

if __name__ == "__main__":
    main()

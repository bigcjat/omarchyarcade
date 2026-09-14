#!/usr/bin/env python3
"""
TetraBlocks Launcher for macOS and Omarchy Linux.
Features native dynamic theme synchronization with all 22 Omarchy themes:
- Live hot-reloading from ~/.config/omarchy/current/theme/colors.toml
- Pre-loaded CoreAudio low-latency memory sound architecture
- Persistent high scores via QSettings
"""

import os
import sys
import re
import shutil
import subprocess
import tomllib
import ctypes
from pathlib import Path
from PySide6.QtGui import QIcon, QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import Qt, QFileSystemWatcher, QTimer, QObject, Slot, QSettings

class SettingsManager(QObject):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.settings = QSettings("Arcade", "TetraBlocks")

    @Slot(result=int)
    def getBestScore(self):
        try:
            return int(self.settings.value("bestScore", 0))
        except (ValueError, TypeError):
            return 0

    @Slot(int)
    def setBestScore(self, score):
        self.settings.setValue("bestScore", int(score))

class SoundManager(QObject):
    def __init__(self, sounds_dir, parent=None):
        super().__init__(parent)
        self.sounds_dir = Path(sounds_dir)
        self.sounds = {}
        self.is_mac = sys.platform == "darwin"
        
        # On macOS, preload sounds into native CoreAudio memory IDs for 0ms latency
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

    @Slot()
    def playMove(self):
        self.playSound("move")

    @Slot()
    def playRotate(self):
        self.playSound("rotate")

    @Slot()
    def playHardDrop(self):
        self.playSound("hard_drop")

    @Slot()
    def playLock(self):
        self.playSound("lock")

    @Slot()
    def playLineClear(self):
        self.playSound("line_clear")

    @Slot()
    def playQuadClear(self):
        self.playSound("quad_clear")

    @Slot()
    def playGameOver(self):
        self.playSound("game_over")

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

def main():
    os.environ["QT_ENABLE_HIGHDPI_SCALING"] = "1"
    os.environ["QML_XHR_ALLOW_FILE_READ"] = "1"

    if "--list-themes" in sys.argv:
        print(f"TetraBlocks • Available Omarchy Themes ({len(ALL_THEMES)} total):\n")
        for tid, t in ALL_THEMES.items():
            print(f"    --theme {tid:<20} -> {t['name']}")
        sys.exit(0)

    app = QGuiApplication(sys.argv)
    app.setApplicationName("TetraBlocks")
    app.setOrganizationName("Arcade")
    # Set application icon to game floppy disk
    script_dir = Path(__file__).resolve().parent
    disk_candidates = [
        script_dir / "assets" / "disk_icon.png",
        script_dir.parent.parent / "assets" / "covers" / "tetrablocks_disk.png",
        Path.home() / ".local" / "share" / "omarchy-arcade" / "assets" / "covers" / "tetrablocks_disk.png",
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

    DEFAULT_PRESETS = {
        "dark": dict(ALL_THEMES.get("catppuccin_mocha", {
            "name": "Catppuccin Mocha", "background": "#1e1e2e", "foreground": "#cdd6f4",
            "accent": "#89b4fa", "card": "#181825", "surface": "#313244", "border": "#45475a",
            "subtext": "#a6adc8", "color0": "#45475a", "color1": "#f38ba8", "color2": "#a6e3a1",
            "color3": "#f9e2af", "color4": "#89b4fa", "color5": "#f5c2e7", "color6": "#94e2d5",
            "color7": "#bac2de", "color8": "#585b70"
        }), boardBg="#11111b", cellEmpty="#181825"),
        "light": dict(ALL_THEMES.get("catppuccin_latte", {
            "name": "Catppuccin Latte", "background": "#eff1f5", "foreground": "#4c4f69",
            "accent": "#1e66f5", "card": "#ffffff", "surface": "#e6e9ef", "border": "#bcc0cc",
            "subtext": "#6c6f85", "color0": "#bcc0cc", "color1": "#d20f39", "color2": "#40a02b",
            "color3": "#df8e1d", "color4": "#1e66f5", "color5": "#8839ef", "color6": "#179299",
            "color7": "#5c5f77", "color8": "#acb0be"
        }), boardBg="#d8dce5", cellEmpty="#e6eaf1")
    }

    # Theme selection CLI logic
    if "--theme" in sys.argv:
        idx = sys.argv.index("--theme")
        if idx + 1 < len(sys.argv):
            theme_key = sys.argv[idx + 1].lower()
            if theme_key in DEFAULT_PRESETS:
                root_obj.applyTheme(DEFAULT_PRESETS[theme_key], DEFAULT_PRESETS[theme_key]["name"])
            else:
                print(f"Warning: Theme '{theme_key}' not found.", file=sys.stderr)

    # Omarchy system live synchronization
    if "--theme" not in sys.argv:
        system_colors = find_omarchy_colors_file()
        if system_colors:
            colors = load_toml_colors(system_colors)
            if colors:
                root_obj.applyTheme(colors, system_colors.parent.name.capitalize())

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
            is_dark = (app.styleHints().colorScheme() == Qt.ColorScheme.Dark) if hasattr(Qt, "ColorScheme") else True
            initial_preset = DEFAULT_PRESETS["dark"] if is_dark else DEFAULT_PRESETS["light"]
            root_obj.applyTheme(initial_preset, initial_preset["name"])

        def on_scheme_changed():
            scheme = app.styleHints().colorScheme()
            is_dark_mode = (scheme == Qt.ColorScheme.Dark) if hasattr(Qt, "ColorScheme") else True
            target_preset = DEFAULT_PRESETS["dark"] if is_dark_mode else DEFAULT_PRESETS["light"]
            root_obj.applyTheme(target_preset, target_preset["name"])

        if hasattr(app.styleHints(), "colorSchemeChanged"):
            app.styleHints().colorSchemeChanged.connect(on_scheme_changed)

    if "--no-splash" in sys.argv:
        root_obj.setProperty("splashEnabled", False)

    if hasattr(root_obj, "screenshotSaved"):
        root_obj.screenshotSaved.connect(lambda p: app.quit())

    if "--screenshot" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        idx = sys.argv.index("--screenshot")
        screenshot_target = Path(__file__).resolve().parent / "screenshot.png"
        if idx + 1 < len(sys.argv) and not sys.argv[idx + 1].startswith("--"):
            screenshot_target = Path(sys.argv[idx + 1]).resolve()

        def capture():
            def do_save():
                root_obj.captureScreenshot(str(screenshot_target), True)
            QTimer.singleShot(250, do_save)
        QTimer.singleShot(150, capture)

    if "--screenshot-help" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        def capture_help():
            root_obj.setProperty("showHelp", True)
            def do_save():
                out_path = Path(__file__).resolve().parent / "screenshot_help.png"
                root_obj.captureScreenshot(str(out_path), True)
            QTimer.singleShot(250, do_save)
        QTimer.singleShot(150, capture_help)

    if "--screenshot-large" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        root_obj.setWidth(780)
        root_obj.setHeight(920)
        def capture_large():
            def do_save():
                out_path = Path(__file__).resolve().parent / "screenshot_large.png"
                root_obj.captureScreenshot(str(out_path), True)
            QTimer.singleShot(250, do_save)
        QTimer.singleShot(150, capture_large)

    print("TetraBlocks running. Press Space for hard drop, ? or Esc for help.")
    sys.exit(app.exec())

if __name__ == "__main__":
    main()

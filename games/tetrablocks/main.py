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
from PySide6.QtCore import QFileSystemWatcher, QTimer, QObject, Slot, QSettings

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

def load_all_omarchy_themes():
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

    # Theme selection CLI logic
    if "--theme" in sys.argv:
        idx = sys.argv.index("--theme")
        if idx + 1 < len(sys.argv):
            theme_key = sys.argv[idx + 1].lower()
            if theme_key in ALL_THEMES:
                root_obj.applyTheme(ALL_THEMES[theme_key], ALL_THEMES[theme_key]["name"])
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

    if "--no-splash" in sys.argv:
        root_obj.setProperty("splashEnabled", False)

    if "--screenshot" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        def capture():
            def do_save():
                out_path = Path(__file__).resolve().parent / "screenshot.png"
                root_obj.captureScreenshot(str(out_path), True)
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

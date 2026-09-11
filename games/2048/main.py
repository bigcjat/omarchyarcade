#!/usr/bin/env python3
"""
2048 Launcher for macOS and Omarchy Linux.
Features native dynamic theme synchronization with all 22 Omarchy themes:
- In-game instant cycling with the 'T' key or 'Theme' button
- Command line previews: python main.py --theme <theme_name>
- Live hot-reloading from ~/.config/omarchy/current/theme/colors.toml
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
        self.settings = QSettings("Arcade", "2048")

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

    @Slot(int)
    def playMerge(self, val):
        target = 2048 if val >= 2048 else val
        self.playSound(f"merge_{target}")

    @Slot()
    def playSlide(self):
        self.playSound("slide")

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
        print(f"2048 • Available Omarchy Desktop Themes ({len(ALL_THEMES)} total):\n")
        print("  Light Themes:")
        for tid, t in ALL_THEMES.items():
            if "light" in tid or "snow" in tid or "dawn" in tid or "white" in tid or "latte" in tid:
                print(f"    --theme {tid:<20} -> {t['name']}")
        print("\n  Dark Themes:")
        for tid, t in ALL_THEMES.items():
            if not ("light" in tid or "snow" in tid or "dawn" in tid or "white" in tid or "latte" in tid):
                print(f"    --theme {tid:<20} -> {t['name']}")
        print("\nSpecify a theme using: python main.py --theme <name>")
        sys.exit(0)

    app = QGuiApplication(sys.argv)
    app.setApplicationName("2048")
    app.setOrganizationName("Arcade")
    # Set application icon to game floppy disk
    script_dir = Path(__file__).resolve().parent
    disk_candidates = [
        script_dir / "assets" / "disk_icon.png",
        script_dir.parent.parent / "assets" / "covers" / "2048_disk.png",
        Path.home() / ".local" / "share" / "omarchy-arcade" / "assets" / "covers" / "2048_disk.png",
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

    # Theme selection logic
    theme_arg = None
    if "--theme" in sys.argv:
        idx = sys.argv.index("--theme")
        if idx + 1 < len(sys.argv):
            theme_arg = sys.argv[idx + 1]

    # 1. Explicit theme argument
    if theme_arg:
        clean_arg = theme_arg.lower().replace("_", "-")
        if clean_arg in ALL_THEMES:
            t = ALL_THEMES[clean_arg]
            root_obj.applyTheme(t, t["name"])
            print(f"Applied Omarchy theme: {t['name']}")
        else:
            custom_path = Path(theme_arg).expanduser().resolve()
            if custom_path.is_file():
                data = load_toml_colors(custom_path)
                if data:
                    root_obj.applyTheme(data, custom_path.parent.name.capitalize())
                    print(f"Applied custom theme from {custom_path}")
            else:
                print(f"Warning: Theme '{theme_arg}' not found. Run with --list-themes to see all options.", file=sys.stderr)

    # 2. Omarchy system theme detection and hot-reloading
    else:
        system_colors = find_omarchy_colors_file()
        if system_colors:
            data = load_toml_colors(system_colors)
            if data:
                theme_name = system_colors.parent.name.capitalize()
                root_obj.applyTheme(data, theme_name)
                print(f"Detected Omarchy theme: {theme_name} ({system_colors})")

            # Watch for live theme switches in Omarchy
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
                        print(f"Omarchy theme live-reloaded: {colors_path.parent.name}")

            watcher.fileChanged.connect(on_theme_updated)
            watcher.directoryChanged.connect(on_theme_updated)

    if "--no-splash" in sys.argv:
        root_obj.setProperty("splashEnabled", False)

    # Test / automation CLI helpers
    if "--test-all-themes" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        out_dir = Path(__file__).resolve().parent / "theme_previews"
        out_dir.mkdir(exist_ok=True)
        theme_keys = list(ALL_THEMES.keys())
        current_idx = [0]
        
        def save_next():
            if current_idx[0] >= len(theme_keys):
                print(f"All {len(theme_keys)} themes tested successfully! Previews saved to {out_dir}")
                app.quit()
                return
            tk = theme_keys[current_idx[0]]
            t = ALL_THEMES[tk]
            root_obj.applyTheme(t, t["name"])
            root_obj.doMove(0)
            root_obj.doMove(3)
            save_path = out_dir / f"{tk}.png"
            QTimer.singleShot(80, lambda: root_obj.captureScreenshot(str(save_path), False))

        def on_saved(saved_path):
            current_idx[0] += 1
            QTimer.singleShot(50, save_next)

        root_obj.screenshotSaved.connect(on_saved)
        QTimer.singleShot(150, save_next)

    if "--screenshot-splash" in sys.argv:
        def capture_splash():
            out_path = Path(__file__).resolve().parent / "screenshot_splash.png"
            root_obj.captureScreenshot(str(out_path), True)
        QTimer.singleShot(550, capture_splash)

    if "--screenshot" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        def capture():
            root_obj.doMove(0)
            root_obj.doMove(3)
            def do_save():
                out_path = Path(__file__).resolve().parent / "screenshot.png"
                root_obj.captureScreenshot(str(out_path), True)
            QTimer.singleShot(250, do_save)
        QTimer.singleShot(100, capture)

    if "--screenshot-help" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        def capture_help():
            root_obj.setProperty("showHelp", True)
            def do_save():
                out_path = Path(__file__).resolve().parent / "screenshot_help.png"
                root_obj.captureScreenshot(str(out_path), True)
            QTimer.singleShot(250, do_save)
        QTimer.singleShot(100, capture_help)

    print("2048 QML game running. Press Esc or ? for help, R to restart.")
    sys.exit(app.exec())

if __name__ == "__main__":
    main()

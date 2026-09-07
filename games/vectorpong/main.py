#!/usr/bin/env python3
"""
VectorPong - Minimalist Vector Pong for macOS and Omarchy Linux.
Features native dynamic theme synchronization with all 22 Omarchy themes:
- Live hot-reloading from ~/.config/omarchy/current/theme/colors.toml
- Pre-loaded CoreAudio low-latency memory sound architecture
- 1-Player vs AI (Novice, Pro, Master) and 2-Player local couch play
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
        self.settings = QSettings("Arcade", "VectorPong")

    @Slot(result=int)
    def getP1Wins(self):
        try:
            return int(self.settings.value("p1Wins", 0))
        except (ValueError, TypeError):
            return 0

    @Slot(int)
    def setP1Wins(self, wins):
        self.settings.setValue("p1Wins", int(wins))

class SoundManager(QObject):
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
    def playHitPaddle(self):
        self.playSound("hit_paddle")

    @Slot()
    def playHitWall(self):
        self.playSound("hit_wall")

    @Slot()
    def playScore(self):
        self.playSound("score")

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
        if "id" in t:
            themes[t["id"]] = t
    return themes

def load_system_theme():
    theme_path = Path.home() / ".config" / "omarchy" / "current" / "theme" / "colors.toml"
    if not theme_path.is_file():
        return None
    try:
        with open(theme_path, "rb") as f:
            data = tomllib.load(f)
        colors = data.get("colors", {})
        accent = colors.get("accent", colors.get("color4", "#89b4fa"))
        bg = colors.get("background", "#181825")
        fg = colors.get("foreground", "#cdd6f4")
        return {
            "name": "System Theme",
            "background": bg,
            "foreground": fg,
            "accent": accent,
            "color0": colors.get("color0", "#181825"),
            "color1": colors.get("color1", "#f38ba8"),
            "color2": colors.get("color2", "#a6e3a1"),
            "color3": colors.get("color3", "#f9e2af"),
            "color4": colors.get("color4", "#89b4fa"),
            "color5": colors.get("color5", "#cba6f7"),
            "color6": colors.get("color6", "#89dceb"),
            "color7": colors.get("color7", "#a6adc8"),
        }
    except Exception:
        return None

def main():
    app = QGuiApplication(sys.argv)
    # Set application icon to game floppy disk
    script_dir = Path(__file__).resolve().parent
    disk_candidates = [
        script_dir / "assets" / "disk_icon.png",
        script_dir.parent.parent / "assets" / "covers" / "vectorpong_disk.png",
        Path.home() / ".local" / "share" / "omarchy-arcade" / "assets" / "covers" / "vectorpong_disk.png",
    ]
    for cp in disk_candidates:
        if cp.exists():
            app.setWindowIcon(QIcon(str(cp)))
            break

    engine = QQmlApplicationEngine()

    settings_mgr = SettingsManager()
    engine.rootContext().setContextProperty("settingsManager", settings_mgr)

    sounds_dir = Path(__file__).resolve().parent / "sounds"
    sound_mgr = SoundManager(sounds_dir)
    engine.rootContext().setContextProperty("soundManager", sound_mgr)

    qml_path = Path(__file__).resolve().parent / "main.qml"
    engine.load(str(qml_path))

    if not engine.rootObjects():
        sys.exit(-1)

    root = engine.rootObjects()[0]
    all_themes = load_all_omarchy_themes()

    requested_theme = None
    requested_screenshot = None
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--theme" and i + 1 < len(args):
            requested_theme = args[i + 1]
            i += 2
        elif args[i] == "--screenshot" and i + 1 < len(args):
            requested_screenshot = args[i + 1]
            i += 2
        else:
            i += 1

    if requested_theme and requested_theme in all_themes:
        root.applyTheme(all_themes[requested_theme], requested_theme)
    else:
        sys_theme = load_system_theme()
        if sys_theme:
            root.applyTheme(sys_theme, "System")
        elif "catppuccin" in all_themes:
            root.applyTheme(all_themes["catppuccin"], "Catppuccin")

    theme_file = Path.home() / ".config" / "omarchy" / "current" / "theme" / "colors.toml"
    watcher = QFileSystemWatcher()
    if theme_file.parent.exists():
        watcher.addPath(str(theme_file.parent))
    if theme_file.exists():
        watcher.addPath(str(theme_file))

    def on_theme_file_changed(path):
        QTimer.singleShot(150, update_theme)

    def update_theme():
        if requested_theme: return
        t = load_system_theme()
        if t: root.applyTheme(t, "System")

    watcher.fileChanged.connect(on_theme_file_changed)
    watcher.directoryChanged.connect(on_theme_file_changed)

    if requested_screenshot:
        def do_shot():
            root.splashEnabled = False
            root.captureScreenshot(requested_screenshot, True)
        QTimer.singleShot(1250, do_shot)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

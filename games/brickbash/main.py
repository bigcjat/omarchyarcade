#!/usr/bin/env python3
"""
BrickBash - Sleek Modern Retro Brick Breaker / Arkanoid for macOS & Omarchy Linux.
Features:
- Dynamic theme synchronization with all 22 Omarchy themes
- Low latency native CoreAudio sounds on macOS / pw-play on Linux
- High score tracking via QSettings
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
        self.settings = QSettings("Arcade", "BrickBash")

    @Slot(result=int)
    def getHighScore(self):
        try:
            return int(self.settings.value("highScore", 0))
        except (ValueError, TypeError):
            return 0

    @Slot(int)
    def setHighScore(self, val):
        self.settings.setValue("highScore", int(val))

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
            self.player_cmd = shutil.which("pw-play") or shutil.which("aplay") or shutil.which("paplay")

        self.preload_sounds()

    def preload_sounds(self):
        sound_names = ["brick", "laser", "lose_life", "paddle", "powerup"]
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
        script_dir.parent.parent / "assets" / "covers" / "brickbash_disk.png",
        Path.home() / ".local" / "share" / "omarchy-arcade" / "assets" / "covers" / "brickbash_disk.png",
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

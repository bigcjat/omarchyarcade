#!/usr/bin/env python3
"""
Omarchy Arcade • Pipe Punk
Steampunk Industrial Plumbing Puzzle Game.

Features:
- Modular brushed copper & cast-iron pipe fittings
- Cutaway glass viewports with bubbling emerald water
- Quivering analog brass PSI pressure gauge
- Mechanical next-piece hopper dispenser
- Fast-forward rush mode with turbine sound
- Native low-latency CoreAudio on macOS + PipeWire/PulseAudio on Linux
- Live Omarchy Desktop theme hot-reloading (colors.toml)
- Persistent stats & records via QSettings
"""

import os
import sys
import argparse
import tomllib
import ctypes
import re
import shutil
import subprocess
from pathlib import Path

from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QObject, Signal, Slot, QSettings, QTimer, QUrl, QFileSystemWatcher, Qt

# =============================================================================
# PERSISTENT SETTINGS MANAGER
# =============================================================================
class SettingsManager(QObject):
    """Provides local persistence via QSettings for Pipe Punk statistics."""
    def __init__(self, game_id="PipePunk", parent=None):
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
        curr = self.getBestScore()
        if int(score) > curr:
            self.settings.setValue("bestScore", int(score))

    @Slot(result=int)
    def getHighestLevel(self):
        try:
            return int(self.settings.value("highestLevel", 1))
        except (ValueError, TypeError):
            return 1

    @Slot(int)
    def setHighestLevel(self, lvl):
        curr = self.getHighestLevel()
        if int(lvl) > curr:
            self.settings.setValue("highestLevel", int(lvl))


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
        if not name:
            return
        if self.is_mac and name in self.sounds:
            self.AudioServicesPlaySystemSound(self.sounds[name])
        elif not self.is_mac and getattr(self, "player_cmd", None):
            wav = self.sounds_dir / f"{name}.wav"
            if wav.exists():
                try:
                    subprocess.Popen([self.player_cmd, str(wav)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                except Exception:
                    pass


# =============================================================================
# THEME RESOLUTION
# =============================================================================
ALL_THEMES = {
    "catppuccin": {
        "id": "catppuccin", "name": "Catppuccin Mocha",
        "background": "#1e1e2e", "foreground": "#cdd6f4", "accent": "#f5c2e7",
        "color0": "#181825", "color1": "#f38ba8", "color2": "#a6e3a1",
        "color3": "#f9e2af", "color4": "#89b4fa", "color5": "#cba6f7",
        "color6": "#94e2d5", "color7": "#bac2de"
    },
    "tokyonight": {
        "id": "tokyonight", "name": "Tokyo Night",
        "background": "#1a1b26", "foreground": "#c0caf5", "accent": "#7aa2f7",
        "color0": "#16161e", "color1": "#f7768e", "color2": "#9ece6a",
        "color3": "#e0af68", "color4": "#7aa2f7", "color5": "#bb9af7",
        "color6": "#7dcfff", "color7": "#a9b1d6"
    },
    "gruvbox": {
        "id": "gruvbox", "name": "Gruvbox Dark",
        "background": "#282828", "foreground": "#ebdbb2", "accent": "#fe8019",
        "color0": "#1d2021", "color1": "#cc241d", "color2": "#98971a",
        "color3": "#d79921", "color4": "#458588", "color5": "#b16286",
        "color6": "#689d6a", "color7": "#a89984"
    }
}

def find_omarchy_colors_file():
    candidates = [
        Path.home() / ".config/omarchy/current/theme/colors.toml",
        Path.home() / ".config/omarchy/theme/colors.toml",
        Path.home() / ".cache/omarchy/theme/colors.toml",
    ]
    for c in candidates:
        if c.is_file():
            return c
    return None

def load_toml_colors(colors_file):
    try:
        with open(colors_file, "rb") as f:
            data = tomllib.load(f)
        theme = {}
        special = data.get("special", {})
        colors = data.get("colors", {})
        if "background" in special: theme["background"] = special["background"]
        if "foreground" in special: theme["foreground"] = special["foreground"]
        if "accent" in special: theme["accent"] = special["accent"]
        for k in ["color0", "color1", "color2", "color3", "color4", "color5", "color6", "color7"]:
            if k in colors: theme[k] = colors[k]
        return theme
    except Exception:
        return None


# =============================================================================
# MAIN RUNNER
# =============================================================================
def main():
    parser = argparse.ArgumentParser(description="Pipe Punk • Omarchy Arcade")
    parser.add_argument("--theme", type=str, help="Force a specific theme")
    parser.add_argument("--screenshot", type=str, help="Capture screenshot to path and exit")
    parser.add_argument("--screenshot-help", type=str, help="Capture help modal screenshot and exit")
    parser.add_argument("--no-splash", action="store_true", help="Skip the startup splash")
    parser.add_argument("--width", type=int, default=0, help="Initial window width")
    parser.add_argument("--height", type=int, default=0, help="Initial window height")
    args = parser.parse_args()

    app = QGuiApplication(sys.argv)
    app.setApplicationName("Pipe Punk")
    app.setOrganizationName("Omarchy")

    engine = QQmlApplicationEngine()
    game_dir = Path(__file__).resolve().parent
    disk_icon = game_dir / "assets" / "disk_icon.png"
    if disk_icon.exists():
        app.setWindowIcon(QIcon(str(disk_icon)))

    settings_manager = SettingsManager("PipePunk")
    sound_manager = SoundManager(game_dir / "sounds")

    engine.rootContext().setContextProperty("settingsManager", settings_manager)
    engine.rootContext().setContextProperty("soundManager", sound_manager)
    engine.rootContext().setContextProperty("noSplash", args.no_splash)
    engine.rootContext().setContextProperty("gameDirectory", str(game_dir))

    # Resolve initial theme
    active_theme = None
    colors_file = None

    if args.theme:
        tid = args.theme.lower()
        if tid in ALL_THEMES:
            active_theme = ALL_THEMES[tid]
    
    if not active_theme:
        colors_file = find_omarchy_colors_file()
        if colors_file:
            toml_colors = load_toml_colors(colors_file)
            if toml_colors:
                active_theme = {
                    "id": "system",
                    "name": "System Theme",
                    "background": toml_colors.get("background", "#12141a"),
                    "foreground": toml_colors.get("foreground", "#e2e8f0"),
                    "accent": toml_colors.get("accent", "#f59e0b"),
                    "color0": toml_colors.get("color0", "#1a1d26"),
                    "color1": toml_colors.get("color1", "#ef4444"),
                    "color2": toml_colors.get("color2", "#10b981"),
                    "color3": toml_colors.get("color3", "#f59e0b"),
                    "color4": toml_colors.get("color4", "#3b82f6"),
                    "color5": toml_colors.get("color5", "#8b5cf6"),
                    "color6": toml_colors.get("color6", "#06b6d4"),
                    "color7": toml_colors.get("color7", "#f1f5f9"),
                }

    if not active_theme:
        active_theme = ALL_THEMES["gruvbox"]

    qml_file = game_dir / "main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        print("Error: Could not load QML main window", file=sys.stderr)
        sys.exit(-1)

    root_window = engine.rootObjects()[0]

    if args.width:
        root_window.setWidth(args.width)
    if args.height:
        root_window.setHeight(args.height)

    def apply_theme(theme_dict):
        try:
            if hasattr(root_window, "themeBg"):
                root_window.setProperty("themeBg", theme_dict.get("background", "#12141a"))
                root_window.setProperty("themeFg", theme_dict.get("foreground", "#e2e8f0"))
                root_window.setProperty("themeAccent", theme_dict.get("accent", "#f59e0b"))
                root_window.setProperty("themeColor0", theme_dict.get("color0", "#1a1d26"))
                root_window.setProperty("themeColor1", theme_dict.get("color1", "#ef4444"))
                root_window.setProperty("themeColor2", theme_dict.get("color2", "#10b981"))
                root_window.setProperty("themeColor3", theme_dict.get("color3", "#f59e0b"))
                root_window.setProperty("themeColor4", theme_dict.get("color4", "#3b82f6"))
                root_window.setProperty("themeColor5", theme_dict.get("color5", "#8b5cf6"))
                root_window.setProperty("themeColor6", theme_dict.get("color6", "#06b6d4"))
        except Exception as e:
            print("Error applying theme:", e)

    apply_theme(active_theme)

    # Hot reload theme watcher
    if colors_file and not args.theme:
        watcher = QFileSystemWatcher([str(colors_file)])
        def on_file_changed(path):
            new_colors = load_toml_colors(path)
            if new_colors:
                t = {
                    "id": "system",
                    "name": "System Theme",
                    "background": new_colors.get("background", "#12141a"),
                    "foreground": new_colors.get("foreground", "#e2e8f0"),
                    "accent": new_colors.get("accent", "#f59e0b"),
                    "color0": new_colors.get("color0", "#1a1d26"),
                    "color1": new_colors.get("color1", "#ef4444"),
                    "color2": new_colors.get("color2", "#10b981"),
                    "color3": new_colors.get("color3", "#f59e0b"),
                    "color4": new_colors.get("color4", "#3b82f6"),
                    "color5": new_colors.get("color5", "#8b5cf6"),
                    "color6": new_colors.get("color6", "#06b6d4"),
                }
                apply_theme(t)
        watcher.fileChanged.connect(on_file_changed)

    if args.no_splash:
        root_window.setProperty("splashEnabled", False)

    # Screenshot handling
    if args.screenshot or args.screenshot_help:
        root_window.setProperty("splashEnabled", False)
        def capture_screenshot():
            include_help = bool(args.screenshot_help)
            if include_help:
                root_window.setProperty("showHelp", True)
            else:
                root_window.setupDemoBoard()
            app.processEvents()

            target_path = Path(args.screenshot_help if args.screenshot_help else args.screenshot).resolve()
            target_path.parent.mkdir(parents=True, exist_ok=True)
            root_window.captureScreenshot(str(target_path), False)
            QTimer.singleShot(400, app.quit)

        QTimer.singleShot(500, capture_screenshot)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

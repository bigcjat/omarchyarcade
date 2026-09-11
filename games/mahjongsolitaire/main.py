#!/usr/bin/env python3
"""
Omarchy Arcade • Mahjong Solitaire
Cyber Obsidian & Luminescent Neon 3D Mahjong Solitaire.

Features:
- 42 high-DPI obsidian glass tiles with glowing neon intaglio glyphs
- 2.5D multi-layered isometric board with contact shadows & ambient occlusion
- Guaranteed 100% solvable generator (Turtle, The Dragon, The Fortress)
- Emissive neon underglow for free/selectable tiles
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

from PySide6.QtGui import QGuiApplication, QIcon, QSurfaceFormat
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QObject, Signal, Slot, QSettings, QTimer, QUrl, QFileSystemWatcher, Qt
from PySide6 import QtQuick3D

# =============================================================================
# PERSISTENT SETTINGS MANAGER
# =============================================================================
class SettingsManager(QObject):
    """Provides local persistence via QSettings for Mahjong Solitaire statistics."""
    def __init__(self, game_id="MahjongSolitaire", parent=None):
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
    def getFastestTime(self):
        try:
            return int(self.settings.value("fastestTime", 0))
        except (ValueError, TypeError):
            return 0

    @Slot(int)
    def setFastestTime(self, seconds):
        curr = self.getFastestTime()
        if curr == 0 or int(seconds) < curr:
            self.settings.setValue("fastestTime", int(seconds))

    @Slot(result=int)
    def getGamesWon(self):
        try:
            return int(self.settings.value("gamesWon", 0))
        except (ValueError, TypeError):
            return 0

    @Slot()
    def incrementGamesWon(self):
        self.settings.setValue("gamesWon", self.getGamesWon() + 1)

    @Slot(result=int)
    def getGamesPlayed(self):
        try:
            return int(self.settings.value("gamesPlayed", 0))
        except (ValueError, TypeError):
            return 0

    @Slot()
    def incrementGamesPlayed(self):
        self.settings.setValue("gamesPlayed", self.getGamesPlayed() + 1)

    @Slot(str, str)
    def setValue(self, key, val):
        self.settings.setValue(key, val)

    @Slot(str, str, result=str)
    def getValue(self, key, default_val=""):
        return str(self.settings.value(key, default_val))

# =============================================================================
# NATIVE LOW-LATENCY SOUND DISPATCHER
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
            self.player = None
            for p in ["pw-play", "paplay", "aplay"]:
                if shutil.which(p):
                    self.player = p
                    break

    @Slot(str)
    def playSound(self, sound_name):
        if self.is_mac and sound_name in self.sounds:
            self.AudioServicesPlaySystemSound(self.sounds[sound_name])
        elif not self.is_mac and hasattr(self, 'player') and self.player:
            wav_path = self.sounds_dir / f"{sound_name}.wav"
            if wav_path.is_file():
                try:
                    subprocess.Popen(
                        [self.player, str(wav_path)],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL
                    )
                except Exception:
                    pass

# =============================================================================
# THEME UTILITIES
# =============================================================================
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

# =============================================================================
# MAIN ENTRYPOINT
# =============================================================================
def main():
    os.environ["QT_ENABLE_HIGHDPI_SCALING"] = "1"
    os.environ["QML_XHR_ALLOW_FILE_READ"] = "1"

    format = QSurfaceFormat()
    format.setSamples(4)
    QSurfaceFormat.setDefaultFormat(format)

    parser = argparse.ArgumentParser(description="Mahjong Solitaire • 3D Cyber Obsidian & Neon Solitaire")
    parser.add_argument("--theme", type=str, help="Theme ID from Themes.js")
    parser.add_argument("--layout", type=str, default="turtle", choices=["turtle", "dragon", "fortress"], help="Starting layout")
    parser.add_argument("--width", type=int, help="Window width override")
    parser.add_argument("--height", type=int, help="Window height override")
    parser.add_argument("--list-themes", action="store_true", help="List all available themes")
    parser.add_argument("--screenshot", type=str, help="Path to save screenshot")
    parser.add_argument("--screenshot-help", type=str, help="Path to save help modal screenshot")
    parser.add_argument("--no-splash", action="store_true", help="Skip splash screen")
    args, unknown = parser.parse_known_args()

    if args.list_themes:
        print(f"Mahjong Solitaire • Available Themes ({len(ALL_THEMES)} total):\n")
        for tid, t in ALL_THEMES.items():
            print(f"  --theme {tid:<20} -> {t['name']}")
        sys.exit(0)

    app = QGuiApplication(sys.argv)
    app.setApplicationName("Mahjong Solitaire")
    app.setOrganizationName("Omarchy")

    engine = QQmlApplicationEngine()
    game_dir = Path(__file__).resolve().parent
    disk_icon = game_dir / "assets" / "disk_icon.png"
    if disk_icon.exists():
        app.setWindowIcon(QIcon(str(disk_icon)))

    settings_manager = SettingsManager("MahjongSolitaire")
    sound_manager = SoundManager(game_dir / "sounds")

    engine.rootContext().setContextProperty("settingsManager", settings_manager)
    engine.rootContext().setContextProperty("soundManager", sound_manager)
    engine.rootContext().setContextProperty("initialLayout", args.layout)
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
                    "background": toml_colors.get("background", "#0d1117"),
                    "foreground": toml_colors.get("foreground", "#c9d1d9"),
                    "accent": toml_colors.get("accent", "#00F0FF"),
                    "color0": toml_colors.get("color0", "#161b22"),
                    "color1": toml_colors.get("color1", "#ff0055"),
                    "color2": toml_colors.get("color2", "#00ff66"),
                    "color3": toml_colors.get("color3", "#ffaa00"),
                    "color4": toml_colors.get("color4", "#00F0FF"),
                    "color5": toml_colors.get("color5", "#bd00ff"),
                    "color6": toml_colors.get("color6", "#00e5ff"),
                    "color7": toml_colors.get("color7", "#e6edf3"),
                }

    if not active_theme:
        active_theme = ALL_THEMES.get("tokyonight", {
            "id": "cyberdark",
            "name": "Cyber Dark",
            "background": "#0a0c10",
            "foreground": "#e2e8f0",
            "accent": "#00F0FF",
            "color0": "#11141d",
            "color1": "#f43f5e",
            "color2": "#10b981",
            "color3": "#f59e0b",
            "color4": "#00F0FF",
            "color5": "#8b5cf6",
            "color6": "#06b6d4",
            "color7": "#e2e8f0"
        })

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
                root_window.setProperty("themeBg", theme_dict.get("background", "#0a0c10"))
                root_window.setProperty("themeFg", theme_dict.get("foreground", "#e2e8f0"))
                root_window.setProperty("themeAccent", theme_dict.get("accent", "#00F0FF"))
                root_window.setProperty("themeColor0", theme_dict.get("color0", "#11141d"))
                root_window.setProperty("themeColor1", theme_dict.get("color1", "#f43f5e"))
                root_window.setProperty("themeColor2", theme_dict.get("color2", "#10b981"))
                root_window.setProperty("themeColor3", theme_dict.get("color3", "#f59e0b"))
                root_window.setProperty("themeColor4", theme_dict.get("color4", "#00F0FF"))
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
                    "background": new_colors.get("background", "#0a0c10"),
                    "foreground": new_colors.get("foreground", "#e2e8f0"),
                    "accent": new_colors.get("accent", "#00F0FF"),
                    "color0": new_colors.get("color0", "#11141d"),
                    "color1": new_colors.get("color1", "#f43f5e"),
                    "color2": new_colors.get("color2", "#10b981"),
                    "color3": new_colors.get("color3", "#f59e0b"),
                    "color4": new_colors.get("color4", "#00F0FF"),
                    "color5": new_colors.get("color5", "#8b5cf6"),
                    "color6": new_colors.get("color6", "#06b6d4"),
                }
                apply_theme(t)
        watcher.fileChanged.connect(on_file_changed)

    # Screenshot handling
    if args.screenshot or args.screenshot_help:
        def capture_screenshot():
            if args.screenshot_help:
                root_window.setProperty("showHelpModal", True)
                app.processEvents()

            target_path = Path(args.screenshot_help if args.screenshot_help else args.screenshot).resolve()
            target_path.parent.mkdir(parents=True, exist_ok=True)
            root_window.captureScreenshot(str(target_path), True)

        QTimer.singleShot(700, capture_screenshot)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

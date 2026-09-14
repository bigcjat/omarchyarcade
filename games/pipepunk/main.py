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
DEFAULT_PRESETS = {
    "dark": {
        "id": "catppuccin",
        "name": "Catppuccin Mocha",
        "bg": "#181825",
        "boardBg": "#11111b",
        "cardBg": "#1e1e2e",
        "surface": "#1e1e2e",
        "border": "#313244",
        "fg": "#cdd6f4",
        "subtext": "#a6adc8",
        "accent": "#f59e0b",
    },
    "light": {
        "id": "catppuccin-latte",
        "name": "Catppuccin Latte",
        "bg": "#eff1f5",
        "boardBg": "#11111b",
        "cardBg": "#ffffff",
        "surface": "#ffffff",
        "border": "#ccd0da",
        "fg": "#4c4f69",
        "subtext": "#6c6f85",
        "accent": "#d97706",
    },
}

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
# MAIN RUNNER
# =============================================================================
def main():
    parser = argparse.ArgumentParser(description="Pipe Punk • Omarchy Arcade")
    parser.add_argument("--theme", type=str, help="Force a specific theme")
    parser.add_argument("--list-themes", action="store_true", help="List available themes")
    parser.add_argument("--screenshot", type=str, help="Capture screenshot to path and exit")
    parser.add_argument("--screenshot-help", type=str, help="Capture help modal screenshot and exit")
    parser.add_argument("--no-splash", action="store_true", help="Skip the startup splash")
    parser.add_argument("--width", type=int, default=0, help="Initial window width")
    parser.add_argument("--height", type=int, default=0, help="Initial window height")
    args = parser.parse_args()

    if args.list_themes:
        print(f"Pipe Punk • Available Themes:\n")
        print("  Presets:")
        for k, v in DEFAULT_PRESETS.items():
            print(f"    --theme {k:<15} -> {v['name']}")
        print("\n  Predefined Themes:")
        for k, v in ALL_THEMES.items():
            print(f"    --theme {k:<15} -> {v['name']}")
        sys.exit(0)

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

    # CLI Theme Argument Parsing
    if args.theme:
        clean_arg = args.theme.lower().replace("_", "-")
        if clean_arg in DEFAULT_PRESETS:
            t = DEFAULT_PRESETS[clean_arg]
            root_window.applyTheme(t, t["name"])
            print(f"Applied preset theme: {t['name']}")
        elif clean_arg in ALL_THEMES:
            t = ALL_THEMES[clean_arg]
            root_window.applyTheme(t, t["name"])
            print(f"Applied theme: {t['name']}")
        else:
            custom_path = Path(args.theme).expanduser().resolve()
            if custom_path.is_file():
                data = load_toml_colors(custom_path)
                if data:
                    root_window.applyTheme(data, custom_path.parent.name.capitalize())
                    print(f"Applied theme from file: {custom_path}")
            else:
                print(f"Warning: Theme '{args.theme}' not found. Falling back to default preset.", file=sys.stderr)
                if any(x in clean_arg for x in ["light", "day", "white"]):
                    t = DEFAULT_PRESETS["light"]
                    root_window.applyTheme(t, t["name"])
                else:
                    t = DEFAULT_PRESETS["dark"]
                    root_window.applyTheme(t, t["name"])

    # 2. Omarchy Desktop System Theme Detection & Hot-Reloading
    else:
        colors_file = find_omarchy_colors_file()
        if colors_file:
            toml_colors = load_toml_colors(colors_file)
            if toml_colors:
                theme_name = colors_file.parent.name.capitalize()
                root_window.applyTheme(toml_colors, theme_name)
                print(f"Detected Omarchy theme: {theme_name} ({colors_file})")

            watcher = QFileSystemWatcher(app)
            watcher.addPath(str(colors_file))
            if colors_file.parent.exists():
                watcher.addPath(str(colors_file.parent))

            def on_theme_updated(path):
                c_path = find_omarchy_colors_file()
                if c_path and c_path.is_file():
                    updated = load_toml_colors(c_path)
                    if updated:
                        root_window.applyTheme(updated, c_path.parent.name.capitalize())
                        print(f"Omarchy theme reloaded: {c_path.parent.name}")

            watcher.fileChanged.connect(on_theme_updated)
            watcher.directoryChanged.connect(on_theme_updated)

        # 3. macOS / System Dark & Light Mode Synchronization
        else:
            def apply_system_scheme():
                scheme = app.styleHints().colorScheme()
                if scheme == Qt.ColorScheme.Light:
                    target_theme = DEFAULT_PRESETS["light"]
                else:
                    target_theme = DEFAULT_PRESETS["dark"]

                root_window.applyTheme(target_theme, target_theme["name"])
                print(f"Detected OS appearance: {target_theme['name']}")

            apply_system_scheme()
            app.styleHints().colorSchemeChanged.connect(lambda _: apply_system_scheme())

    if args.no_splash:
        root_window.setProperty("splashEnabled", False)

    # Screenshot handling
    if args.screenshot or args.screenshot_help:
        root_window.setProperty("splashEnabled", False)
        out_file = args.screenshot_help if args.screenshot_help else args.screenshot
        target_path = Path(out_file).resolve()
        target_path.parent.mkdir(parents=True, exist_ok=True)

        if args.screenshot_help:
            root_window.setProperty("showHelp", True)
        else:
            root_window.setupDemoBoard()

        root_window.screenshotSaved.connect(lambda p: app.quit())
        QTimer.singleShot(250, lambda: root_window.captureScreenshot(str(target_path), False))

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

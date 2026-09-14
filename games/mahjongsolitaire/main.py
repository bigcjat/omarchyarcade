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
- System appearance synchronization (Light vs Dark mode via QStyleHints)
- Persistent stats & records via QSettings
"""

import os
import sys
import tomllib
import ctypes
import shutil
import subprocess
from pathlib import Path

from PySide6.QtGui import QGuiApplication, QIcon, QSurfaceFormat
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QObject, Signal, Slot, QSettings, QTimer, QUrl, QFileSystemWatcher, Qt
from PySide6 import QtQuick3D

# =============================================================================
# THEME PRESETS
# =============================================================================
DEFAULT_PRESETS = {
    "dark": {
        "id": "catppuccin",
        "name": "Catppuccin Mocha",
        "bg": "#080a10",
        "boardBg": "#0c0f18",
        "cardBg": "#121726",
        "surface": "#121726",
        "border": "#1e263c",
        "fg": "#e2e8f0",
        "subtext": "#94a3b8",
        "accent": "#00F0FF",
    },
    "light": {
        "id": "catppuccin-latte",
        "name": "Catppuccin Latte",
        "bg": "#eff1f5",
        "boardBg": "#0c0f18",
        "cardBg": "#ffffff",
        "surface": "#ffffff",
        "border": "#ccd0da",
        "fg": "#4c4f69",
        "subtext": "#6c6f85",
        "accent": "#0284c7",
    },
}

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

def parse_toml_theme(file_path):
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

    app = QGuiApplication(sys.argv)
    app.setApplicationName("Mahjong Solitaire")
    app.setOrganizationName("Omarchy")

    game_dir = Path(__file__).resolve().parent
    disk_icon = game_dir / "assets" / "disk_icon.png"
    if disk_icon.exists():
        app.setWindowIcon(QIcon(str(disk_icon)))

    engine = QQmlApplicationEngine()

    settings_manager = SettingsManager("MahjongSolitaire")
    sound_manager = SoundManager(game_dir / "sounds")

    engine.rootContext().setContextProperty("settingsManager", settings_manager)
    engine.rootContext().setContextProperty("soundManager", sound_manager)

    layout_arg = "turtle"
    if "--layout" in sys.argv:
        l_idx = sys.argv.index("--layout") + 1
        if l_idx < len(sys.argv):
            layout_arg = sys.argv[l_idx]
    engine.rootContext().setContextProperty("initialLayout", layout_arg)
    engine.rootContext().setContextProperty("noSplash", "--no-splash" in sys.argv)
    engine.rootContext().setContextProperty("gameDirectory", str(game_dir))

    qml_file = game_dir / "main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        print("Error: Could not load QML main window", file=sys.stderr)
        sys.exit(-1)

    root = engine.rootObjects()[0]

    if "--width" in sys.argv:
        w_idx = sys.argv.index("--width") + 1
        if w_idx < len(sys.argv):
            root.setWidth(int(sys.argv[w_idx]))
    if "--height" in sys.argv:
        h_idx = sys.argv.index("--height") + 1
        if h_idx < len(sys.argv):
            root.setHeight(int(sys.argv[h_idx]))

    # CLI Theme Argument Parsing
    theme_arg = None
    if "--theme" in sys.argv:
        idx = sys.argv.index("--theme")
        if idx + 1 < len(sys.argv):
            theme_arg = sys.argv[idx + 1]

    if theme_arg:
        clean = theme_arg.lower().replace("_", "-")
        if clean in DEFAULT_PRESETS:
            t = DEFAULT_PRESETS[clean]
            root.applyTheme(t, t["name"])
        elif any(term in clean for term in ["light", "white", "day", "snow", "dawn", "latte"]):
            t = DEFAULT_PRESETS["light"]
            root.applyTheme(t, t["name"])
        else:
            custom_path = Path(theme_arg).expanduser().resolve()
            if custom_path.is_file():
                data = parse_toml_theme(custom_path)
                if data:
                    root.applyTheme(data, custom_path.parent.name.capitalize())
            else:
                t = DEFAULT_PRESETS["dark"]
                root.applyTheme(t, t["name"])
    else:
        theme_path = find_omarchy_colors_file()
        if theme_path and theme_path.is_file():
            theme_data = parse_toml_theme(theme_path)
            t_name = theme_path.parent.name.capitalize()
            root.applyTheme(theme_data, t_name)

            watcher = QFileSystemWatcher(app)
            watcher.addPath(str(theme_path))
            if theme_path.parent.exists():
                watcher.addPath(str(theme_path.parent))

            def on_theme_updated(path):
                colors_path = find_omarchy_colors_file()
                if colors_path and colors_path.is_file():
                    updated = parse_toml_theme(colors_path)
                    if updated:
                        root.applyTheme(updated, colors_path.parent.name.capitalize())

            watcher.fileChanged.connect(on_theme_updated)
            watcher.directoryChanged.connect(on_theme_updated)
        else:
            def apply_system_scheme():
                scheme = app.styleHints().colorScheme()
                preset_key = "light" if scheme == Qt.ColorScheme.Light else "dark"
                t = DEFAULT_PRESETS[preset_key]
                root.applyTheme(t, t["name"])

            apply_system_scheme()
            app.styleHints().colorSchemeChanged.connect(lambda _: apply_system_scheme())

    # Screenshot handling
    if "--screenshot" in sys.argv:
        out_idx = sys.argv.index("--screenshot") + 1
        out_file = sys.argv[out_idx] if out_idx < len(sys.argv) and not sys.argv[out_idx].startswith("--") else "screenshot.png"
        out_path = Path(out_file).resolve()

        if hasattr(root, "screenshotSaved"):
            root.screenshotSaved.connect(lambda p: app.quit())
        QTimer.singleShot(350, lambda: root.captureScreenshot(str(out_path), False))
        QTimer.singleShot(2500, app.quit)

    if "--screenshot-help" in sys.argv:
        def capture_help():
            root.setProperty("showHelp", True)
            out_path = game_dir / "screenshot_help.png"
            root.captureScreenshot(str(out_path), False)
        if hasattr(root, "screenshotSaved"):
            root.screenshotSaved.connect(lambda p: app.quit())
        QTimer.singleShot(350, capture_help)
        QTimer.singleShot(2500, app.quit)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Omarchy Arcade • Klondike Solitaire
Standard 7-Column Tabletop Patience Solitaire with 3D Card Flips & Vector Decks.

Native Qt6/QML frontend with low-latency audio and 22-theme hot-reloading.
Part of the Omarchy Arcade game suite.
"""

import sys
import os
import argparse
import ctypes
import re
import tomllib
from pathlib import Path

from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QObject, Signal, Slot, QSettings, QTimer, QUrl, QFileSystemWatcher, Qt

# =============================================================================
# PERSISTENT SETTINGS MANAGER
# =============================================================================
class SettingsManager(QObject):
    """Provides local persistence via QSettings for Solitaire statistics."""
    def __init__(self, game_id="Solitaire", parent=None):
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

    @Slot(result=int)
    def getFastestTime(self):
        try:
            return int(self.settings.value("fastestTime", 0))
        except (ValueError, TypeError):
            return 0

    @Slot(int)
    def setFastestTime(self, seconds):
        self.settings.setValue("fastestTime", int(seconds))

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
            import shutil
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
                import subprocess
                try:
                    subprocess.Popen(
                        [self.player, str(wav_path)],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL
                    )
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
# APPLICATION ENTRYPOINT
# =============================================================================
def main():
    parser = argparse.ArgumentParser(description="Omarchy Arcade • Klondike Solitaire")
    parser.add_argument("--no-splash", action="store_true", help="Skip arcade startup screen")
    parser.add_argument("--screenshot", type=str, help="Capture screenshot to path and exit")
    parser.add_argument("--theme", type=str, help="Override Omarchy color theme")
    parser.add_argument("--deck", type=str, choices=["synthwave", "crimson", "sapphire", "obsidian"], help="Card back theme")
    parser.add_argument("--draw", type=int, choices=[1, 3], help="Draw mode (1 or 3)")
    args = parser.parse_args()

    app = QGuiApplication(sys.argv)
    app.setOrganizationName("Omarchy")
    app.setApplicationName("Solitaire")

    script_dir = Path(__file__).resolve().parent
    disk_candidates = [
        script_dir / "assets" / "disk_icon.png",
        script_dir.parent.parent / "assets" / "covers" / "solitaire_disk.png",
        script_dir.parent.parent / "assets" / "covers" / "solitaire.png",
        Path.home() / ".local" / "share" / "omarchy-arcade" / "assets" / "covers" / "solitaire.png",
        script_dir / "assets" / "cover.png",
    ]
    for cp in disk_candidates:
        if cp.exists():
            app.setWindowIcon(QIcon(str(cp)))
            break

    engine = QQmlApplicationEngine()

    settings_manager = SettingsManager("Solitaire")
    engine.rootContext().setContextProperty("settingsManager", settings_manager)

    sound_manager = SoundManager(script_dir / "sounds")
    engine.rootContext().setContextProperty("soundManager", sound_manager)

    qml_file = script_dir / "main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        print("Error: Could not load main.qml", file=sys.stderr)
        sys.exit(1)

    root = engine.rootObjects()[0]

    # CLI Overrides & Theme Management
    if args.theme:
        clean_arg = args.theme.lower().replace("_", "-")
        if clean_arg in ALL_THEMES:
            t = ALL_THEMES[clean_arg]
            root.applyTheme(t, t["name"])
        else:
            custom_path = Path(args.theme).expanduser().resolve()
            if custom_path.is_file():
                data = load_toml_colors(custom_path)
                if data:
                    root.applyTheme(data, custom_path.parent.name.capitalize())
            else:
                root.setProperty("forcedTheme", args.theme)
    else:
        system_colors = find_omarchy_colors_file()
        if system_colors:
            data = load_toml_colors(system_colors)
            if data:
                theme_name = system_colors.parent.name.capitalize()
                root.applyTheme(data, theme_name)

            watcher = QFileSystemWatcher(app)
            watcher.addPath(str(system_colors))
            if system_colors.parent.exists():
                watcher.addPath(str(system_colors.parent))

            def on_theme_updated(path):
                colors_path = find_omarchy_colors_file()
                if colors_path and colors_path.is_file():
                    updated = load_toml_colors(colors_path)
                    if updated:
                        root.applyTheme(updated, colors_path.parent.name.capitalize())

            watcher.fileChanged.connect(on_theme_updated)
            watcher.directoryChanged.connect(on_theme_updated)

    if args.no_splash:
        root.setProperty("splashEnabled", False)

    if args.deck:
        root.setProperty("deckStyle", args.deck)

    if args.draw:
        root.setProperty("drawCount", args.draw)

    if args.screenshot:
        def do_capture():
            root.captureScreenshot(args.screenshot, True)
        QTimer.singleShot(600 if not args.no_splash else 200, do_capture)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

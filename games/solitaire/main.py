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
from pathlib import Path

from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QObject, Signal, Slot, QSettings, QTimer, QUrl

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

    # CLI Overrides
    if args.no_splash:
        root.setProperty("splashEnabled", False)

    if args.theme:
        root.setProperty("forcedTheme", args.theme)

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

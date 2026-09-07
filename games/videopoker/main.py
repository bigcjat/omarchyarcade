#!/usr/bin/env python3
"""
Omarchy Arcade • Video Poker & Tabletop Multi-Terminal (OA-025)
Full 8-Game Casino Video Machine with Dual-Era Switcher (1984 Vegas CRT ↔ Neo-Tokyo Cyber Glass).

Includes:
- Jacks or Better (9/6 Full Pay)
- Deuces Wild (Four Deuces 200x)
- Joker Poker (53-card Kings or Better)
- Double Double Bonus Poker (Special Quad Kickers)
- Bonus Poker Deluxe (Flat Quad 80:1)
- Red Dog (In-Between / Acey-Deucey)
- Single-Deck Video Blackjack (3:2 Natural, Dealer Soft 17)
- Casino War (War / Surrender, 50% tie rule)
- Double-Up Gamble (High-card 1-vs-4 pick)

Native Qt6/QML frontend with low-latency CoreAudio / Linux sound dispatchers.
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
    """Provides local persistence via QSettings for Video Poker statistics & machine state."""
    def __init__(self, game_id="VideoPoker", parent=None):
        super().__init__(parent)
        self.settings = QSettings("Arcade", game_id)

    @Slot(result=int)
    def getCredits(self):
        try:
            val = self.settings.value("credits", 1000)
            return int(val) if int(val) > 0 else 1000
        except (ValueError, TypeError):
            return 1000

    @Slot(int)
    def setCredits(self, credits):
        self.settings.setValue("credits", int(credits))

    @Slot(result=int)
    def getBestWin(self):
        try:
            return int(self.settings.value("bestWin", 0))
        except (ValueError, TypeError):
            return 0

    @Slot(int)
    def setBestWin(self, win):
        self.settings.setValue("bestWin", int(win))

    @Slot(result=int)
    def getHandsPlayed(self):
        try:
            return int(self.settings.value("handsPlayed", 0))
        except (ValueError, TypeError):
            return 0

    @Slot(int)
    def setHandsPlayed(self, count):
        self.settings.setValue("handsPlayed", int(count))

    @Slot(result=str)
    def getVisualMode(self):
        return str(self.settings.value("visualMode", "crt"))

    @Slot(str)
    def setVisualMode(self, mode):
        self.settings.setValue("visualMode", str(mode))

    @Slot(result=str)
    def getGameMode(self):
        return str(self.settings.value("gameMode", "jacks_or_better"))

    @Slot(str)
    def setGameMode(self, mode):
        self.settings.setValue("gameMode", str(mode))

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
    parser = argparse.ArgumentParser(description="Omarchy Arcade • Video Poker & Multi-Terminal")
    parser.add_argument("--no-splash", action="store_true", help="Skip arcade startup screen")
    parser.add_argument("--screenshot", type=str, help="Capture screenshot to path and exit")
    parser.add_argument("--theme", type=str, help="Override Omarchy color theme")
    parser.add_argument("--game", type=str, choices=[
        "jacks_or_better", "deuces_wild", "joker_poker",
        "double_double_bonus", "bonus_poker_deluxe",
        "red_dog", "blackjack", "casino_war"
    ], help="Starting game engine")
    parser.add_argument("--mode", "--vibe", dest="mode", type=str, choices=["crt", "cyber"], help="Visual era mode ('crt' or 'cyber')")
    parser.add_argument("--deck", type=str, choices=["synthwave", "crimson", "sapphire", "obsidian"], help="Card back theme")
    args = parser.parse_args()

    app = QGuiApplication(sys.argv)
    app.setOrganizationName("Omarchy")
    app.setApplicationName("VideoPoker")

    script_dir = Path(__file__).resolve().parent
    icon_path = script_dir / "omarchy_arcade.svg"
    if icon_path.exists():
        app.setWindowIcon(QIcon(str(icon_path)))

    engine = QQmlApplicationEngine()

    settings_manager = SettingsManager("VideoPoker")
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

    if args.mode:
        root.setProperty("visualMode", args.mode)

    if args.game:
        root.setProperty("activeGameId", args.game)

    if args.deck:
        root.setProperty("deckStyle", args.deck)

    if args.screenshot:
        def do_capture():
            root.captureScreenshot(args.screenshot, True)
        QTimer.singleShot(600 if not args.no_splash else 200, do_capture)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

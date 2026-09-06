#!/usr/bin/env python3
"""
Omarchy Arcade: CratePusher (Sokoban)
- Pure QML / JavaScript authentic Japanese warehouse crate-pushing puzzle
- Live hot-reloading from ~/.config/omarchy/current/theme/colors.toml
- Zero-overhead low latency audio playback via AudioToolbox (macOS) / PipeWire / ALSA (Linux)
- Persistent level unlocking, move records, and ratings via QSettings
- Fully responsive to tiling window managers
"""

import sys
import os
import tomllib
from pathlib import Path
from PySide6.QtCore import QObject, Slot, QUrl, QFileSystemWatcher, QTimer, QSettings
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
import ctypes
import shutil
import subprocess

class SettingsManager(QObject):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.settings = QSettings("Arcade", "CratePusher")

    @Slot(int, result=int)
    def getBestMoves(self, level_idx):
        try:
            return int(self.settings.value(f"bestMoves_{level_idx}", 0))
        except (ValueError, TypeError):
            return 0

    @Slot(int, int)
    def setBestMoves(self, level_idx, moves):
        curr = self.getBestMoves(level_idx)
        if curr == 0 or moves < curr:
            self.settings.setValue(f"bestMoves_{level_idx}", int(moves))

    @Slot(result=int)
    def getUnlockedLevel(self):
        try:
            return int(self.settings.value("unlockedLevel", 0))
        except (ValueError, TypeError):
            return 0

    @Slot(int)
    def setUnlockedLevel(self, level_idx):
        curr = self.getUnlockedLevel()
        if level_idx > curr:
            self.settings.setValue("unlockedLevel", int(level_idx))

    @Slot(int, result=int)
    def getStars(self, level_idx):
        try:
            return int(self.settings.value(f"stars_{level_idx}", 0))
        except (ValueError, TypeError):
            return 0

    @Slot(int, int)
    def setStars(self, level_idx, stars):
        curr = self.getStars(level_idx)
        if stars > curr:
            self.settings.setValue(f"stars_{level_idx}", int(stars))

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

def parse_toml_theme(path: Path):
    try:
        with open(path, "rb") as f:
            data = tomllib.load(f)
        colors = data.get("colors", {})
        return {
            "bg": colors.get("base", "#181825"),
            "fg": colors.get("text", "#cdd6f4"),
            "accent": colors.get("sapphire", colors.get("blue", "#89b4fa")),
            "boardBg": colors.get("mantle", "#1e1e2e"),
            "cardBg": colors.get("surface0", "#313244"),
            "border": colors.get("surface1", "#45475a"),
            "subtext": colors.get("subtext0", "#a6adc8")
        }
    except Exception:
        return {}

def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("CratePusher")
    app.setOrganizationName("OmarchyArcade")

    base_dir = Path(__file__).resolve().parent
    engine = QQmlApplicationEngine()

    settings_manager = SettingsManager()
    engine.rootContext().setContextProperty("settingsManager", settings_manager)

    sounds_dir = base_dir / "sounds"
    sound_manager = SoundManager(sounds_dir)
    engine.rootContext().setContextProperty("soundManager", sound_manager)

    qml_file = base_dir / "main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        sys.exit(-1)

    root = engine.rootObjects()[0]

    theme_path = Path.home() / ".config/omarchy/current/theme/colors.toml"
    theme_name_path = Path.home() / ".config/omarchy/current/theme.name"

    def update_theme():
        if theme_path.exists():
            theme_data = parse_toml_theme(theme_path)
            t_name = "Custom"
            if theme_name_path.exists():
                try:
                    t_name = theme_name_path.read_text().strip()
                except Exception:
                    pass
            root.applyTheme(theme_data, t_name)

    if theme_path.exists():
        update_theme()

    watcher = QFileSystemWatcher()
    if theme_path.parent.exists():
        watcher.addPath(str(theme_path.parent))
    if theme_path.exists():
        watcher.addPath(str(theme_path))

    def on_theme_changed():
        QTimer.singleShot(150, update_theme)

    watcher.fileChanged.connect(on_theme_changed)
    watcher.directoryChanged.connect(on_theme_changed)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

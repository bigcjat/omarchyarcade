#!/usr/bin/env python3
"""
Omarchy Arcade: Galactic Swarm (Galaga Clone)
- Pure QML / JavaScript vector arcade space shooter
- Live hot-reloading from ~/.config/omarchy/current/theme/colors.toml
- Zero-overhead low latency audio playback via AudioToolbox (macOS) / PipeWire / ALSA (Linux)
- Fully responsive to tiling window managers
"""

import sys
import os
import tomllib
from pathlib import Path
from PySide6.QtCore import QObject, Slot, QUrl, QFileSystemWatcher, QTimer, QSettings
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
import ctypes
import shutil
import subprocess

class SettingsManager(QObject):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.settings = QSettings("Arcade", "GalacticSwarm")

    @Slot(result=int)
    def getBestScore(self):
        try:
            return int(self.settings.value("bestScore", 0))
        except (ValueError, TypeError):
            return 0

    @Slot(int)
    def setBestScore(self, score):
        self.settings.setValue("bestScore", int(score))

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
        colors = data.get("colors") if isinstance(data.get("colors"), dict) else data
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


def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("GalacticSwarm")
    app.setOrganizationName("OmarchyArcade")
    # Set application icon to game floppy disk
    script_dir = Path(__file__).resolve().parent
    disk_candidates = [
        script_dir / "assets" / "disk_icon.png",
        script_dir.parent.parent / "assets" / "covers" / "galacticswarm_disk.png",
        Path.home() / ".local" / "share" / "omarchy-arcade" / "assets" / "covers" / "galacticswarm_disk.png",
    ]
    for cp in disk_candidates:
        if cp.exists():
            app.setWindowIcon(QIcon(str(cp)))
            break


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

    theme_path = find_omarchy_colors_file()
    theme_name_path = Path.home() / ".config/omarchy/current/theme.name"

    def update_theme():
        if theme_path and theme_path.exists():
            theme_data = parse_toml_theme(theme_path)
            t_name = "Custom"
            if theme_name_path.exists():
                try:
                    t_name = theme_name_path.read_text().strip()
                except Exception:
                    pass
            root.applyTheme(theme_data, t_name)

    if theme_path and theme_path.exists():
        update_theme()
        watcher = QFileSystemWatcher([str(theme_path.parent)], app)
        watcher.directoryChanged.connect(lambda: QTimer.singleShot(100, update_theme))
        watcher.fileChanged.connect(lambda: QTimer.singleShot(100, update_theme))

    args = sys.argv[1:]
    requested_screenshot = None
    i = 0
    while i < len(args):
        if args[i] == "--screenshot" and i + 1 < len(args):
            requested_screenshot = args[i + 1]
            i += 2
        else:
            i += 1

    if requested_screenshot:
        def do_shot():
            root.splashEnabled = False
            root.captureScreenshot(requested_screenshot, True)
        QTimer.singleShot(1250, do_shot)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

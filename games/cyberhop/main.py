#!/usr/bin/env python3
"""
Omarchy Arcade: CyberCross (CyberHop / Frogger)
- Pure QML / JavaScript retro road and river crossing arcade classic
- Live hot-reloading from ~/.config/omarchy/current/theme/colors.toml
- Zero-overhead low latency audio playback
- Fully responsive to tiling window managers
"""

import sys
import os
import tomllib
from pathlib import Path
from PySide6.QtCore import QObject, Slot, QUrl, QFileSystemWatcher, QTimer, QSettings
from PySide6.QtGui import QIcon, QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

import ctypes
import shutil
import subprocess

class SettingsManager(QObject):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.settings = QSettings("Arcade", "CyberHop")

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

DEFAULT_PRESETS = {
    "dark": {
        "name": "Omarchy Dark",
        "bg": "#181825",
        "fg": "#cdd6f4",
        "accent": "#a6e3a1",
        "boardBg": "#1e1e2e",
        "card_bg": "#313244",
        "card_hover": "#45475a",
        "border": "#45475a",
        "subtext": "#a6adc8"
    },
    "light": {
        "name": "Omarchy Light",
        "bg": "#eff1f5",
        "fg": "#4c4f69",
        "accent": "#40a02b",
        "boardBg": "#e2e8f0",
        "card_bg": "#ffffff",
        "card_hover": "#f1f5f9",
        "border": "#ccd0da",
        "subtext": "#5c5f77"
    }
}

def parse_toml_theme(path: Path):
    try:
        with open(path, "rb") as f:
            data = tomllib.load(f)
        colors = data.get("colors") if isinstance(data.get("colors"), dict) else data
        bg = colors.get("base") or colors.get("background") or "#181825"
        fg = colors.get("text") or colors.get("foreground") or "#cdd6f4"
        return {
            "bg": bg,
            "fg": fg,
            "accent": colors.get("green", colors.get("accent", "#a6e3a1")),
            "boardBg": "#1e1e2e",
            "card_bg": colors.get("surface0", "#313244"),
            "card_hover": colors.get("surface1", "#45475a"),
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
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    app = QGuiApplication(sys.argv)
    app.setApplicationName("CyberCross")
    app.setOrganizationName("Omarchy")

    script_dir = Path(__file__).resolve().parent
    disk_candidates = [
        script_dir / "assets" / "disk_icon.png",
        script_dir.parent.parent / "assets" / "covers" / "cyberhop_disk.png",
        Path.home() / ".local" / "share" / "omarchy-arcade" / "assets" / "covers" / "cyberhop_disk.png",
    ]
    for cp in disk_candidates:
        if cp.exists():
            app.setWindowIcon(QIcon(str(cp)))
            break

    base_dir = Path(__file__).resolve().parent
    sounds_dir = base_dir / "sounds"
    sound_manager = SoundManager(sounds_dir)
    settings_manager = SettingsManager()

    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("soundManager", sound_manager)
    engine.rootContext().setContextProperty("audioController", sound_manager)
    engine.rootContext().setContextProperty("settingsManager", settings_manager)

    qml_file = base_dir / "main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        sys.exit(-1)

    root = engine.rootObjects()[0]

    icon_path = Path(__file__).resolve().parent / "assets" / "disk_icon.png"

    if icon_path.exists() and hasattr(root, "setIcon"):

        root.setIcon(QIcon(str(icon_path)))

    requested_theme = None
    requested_screenshot = None
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--theme" and i + 1 < len(args):
            requested_theme = args[i + 1].lower()
            i += 2
        elif args[i] == "--screenshot" and i + 1 < len(args):
            requested_screenshot = args[i + 1]
            i += 2
        else:
            i += 1

    def apply_current_theme():
        if requested_theme:
            if requested_theme in DEFAULT_PRESETS:
                root.applyTheme(DEFAULT_PRESETS[requested_theme], requested_theme.capitalize())
                print(f"Applied preset theme: {DEFAULT_PRESETS[requested_theme]['name']}")
                return
        colors_file = find_omarchy_colors_file()
        if colors_file and colors_file.is_file():
            data = parse_toml_theme(colors_file)
            if data:
                root.applyTheme(data, "System")
                return
        hints = QGuiApplication.styleHints()
        if hints and hasattr(hints, "colorScheme"):
            scheme = hints.colorScheme()
            is_dark = (scheme == 2)
            preset_key = "dark" if is_dark else "light"
            root.applyTheme(DEFAULT_PRESETS[preset_key], DEFAULT_PRESETS[preset_key]["name"])
        else:
            root.applyTheme(DEFAULT_PRESETS["dark"], "Omarchy Dark")

    apply_current_theme()

    hints = QGuiApplication.styleHints()
    if hints and hasattr(hints, "colorSchemeChanged"):
        hints.colorSchemeChanged.connect(lambda s: apply_current_theme())

    theme_file = find_omarchy_colors_file()
    watcher = QFileSystemWatcher()
    if theme_file and theme_file.parent.exists():
        watcher.addPath(str(theme_file.parent))
    if theme_file and theme_file.exists():
        watcher.addPath(str(theme_file))

    def on_theme_file_changed(path):
        QTimer.singleShot(150, apply_current_theme)

    watcher.fileChanged.connect(on_theme_file_changed)
    watcher.directoryChanged.connect(on_theme_file_changed)

    if requested_screenshot:
        out_path = Path(requested_screenshot).resolve()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        root.screenshotSaved.connect(lambda p: app.quit())
        def capture():
            root.captureScreenshot(str(out_path))
        QTimer.singleShot(150, capture)

    
    if "--unmute" in sys.argv or "--sound" in sys.argv:
        for _obj in engine.rootObjects():
            _obj.setProperty("isMuted", False)
    elif "--mute" in sys.argv:
        for _obj in engine.rootObjects():
            _obj.setProperty("isMuted", True)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

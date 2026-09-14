#!/usr/bin/env python3
"""
Omarchy Arcade: CyberFlap
- Pure QML / JavaScript retro gravity reflex hopper
- Live hot-reloading from ~/.config/omarchy/current/theme/colors.toml
- Zero-overhead low latency audio playback
- Fully responsive to tiling window managers
"""

import sys
import os
import tomllib
from pathlib import Path
from PySide6.QtCore import QObject, Slot, QUrl, QFileSystemWatcher, QTimer
from PySide6.QtGui import QIcon, QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

import ctypes
import shutil
import subprocess
from PySide6.QtCore import QObject, Slot, QUrl, QFileSystemWatcher, QTimer, QSettings

class SettingsManager(QObject):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.settings = QSettings("Arcade", "CyberFlap")

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
    os.environ["QT_ENABLE_HIGHDPI_SCALING"] = "1"
    os.environ["QML_XHR_ALLOW_FILE_READ"] = "1"

    if "--help" in sys.argv or "-h" in sys.argv:
        print("CyberFlap • Retro Gravity Reflex Hopper")
        sys.exit(0)

    if "--list-themes" in sys.argv:
        print("Arcade Game Template • Preset Themes:\n  --theme light\n  --theme dark\n  --theme <path_to_colors.toml>")
        sys.exit(0)

    app = QGuiApplication(sys.argv)
    app.setApplicationName("CyberFlap")
    app.setOrganizationName("Omarchy")
    # Set application icon to game floppy disk
    script_dir = Path(__file__).resolve().parent
    disk_candidates = [
        script_dir / "assets" / "disk_icon.png",
        script_dir.parent.parent / "assets" / "covers" / "cyberflap_disk.png",
        Path.home() / ".local" / "share" / "omarchy-arcade" / "assets" / "covers" / "cyberflap_disk.png",
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

    # CLI Theme Argument Parsing
    theme_arg = None
    if "--theme" in sys.argv:
        idx = sys.argv.index("--theme")
        if idx + 1 < len(sys.argv):
            theme_arg = sys.argv[idx + 1]

    if theme_arg:
        clean_arg = theme_arg.lower().strip()
        if clean_arg in DEFAULT_PRESETS:
            preset = DEFAULT_PRESETS[clean_arg]
            root.applyTheme(preset, preset["name"])
            print(f"Applied preset theme: {preset['name']}")
        else:
            custom_path = Path(theme_arg).expanduser().resolve()
            if custom_path.is_file():
                data = parse_toml_theme(custom_path)
                if data:
                    root.applyTheme(data, custom_path.parent.name.capitalize())
                    print(f"Applied theme from file: {custom_path}")
            else:
                preset = DEFAULT_PRESETS["dark"]
                root.applyTheme(preset, preset["name"])
    else:
        theme_path = find_omarchy_colors_file()
        if theme_path and theme_path.exists():
            data = parse_toml_theme(theme_path)
            theme_name = theme_path.parent.name.capitalize()
            root.applyTheme(data, theme_name)
            print(f"Detected Omarchy theme: {theme_name} ({theme_path})")

            watcher = QFileSystemWatcher(app)
            watcher.addPath(str(theme_path))
            if theme_path.parent.exists():
                watcher.addPath(str(theme_path.parent))

            def on_theme_updated(p):
                tp = find_omarchy_colors_file()
                if tp and tp.is_file():
                    up = parse_toml_theme(tp)
                    if up:
                        root.applyTheme(up, tp.parent.name.capitalize())

            watcher.fileChanged.connect(on_theme_updated)
            watcher.directoryChanged.connect(on_theme_updated)
        else:
            def apply_system_scheme():
                hints = app.styleHints()
                scheme = hints.colorScheme() if hasattr(hints, "colorScheme") else Qt.ColorScheme.Dark
                preset = DEFAULT_PRESETS["light"] if scheme == Qt.ColorScheme.Light else DEFAULT_PRESETS["dark"]
                root.applyTheme(preset, preset["name"])

            apply_system_scheme()
            if hasattr(app.styleHints(), "colorSchemeChanged"):
                app.styleHints().colorSchemeChanged.connect(lambda _: apply_system_scheme())

    if "--no-splash" in sys.argv:
        root.setProperty("splashEnabled", False)

    if "--screenshot" in sys.argv:
        root.setProperty("splashEnabled", False)
        def capture():
            out_idx = sys.argv.index("--screenshot") + 1
            out_file = sys.argv[out_idx] if out_idx < len(sys.argv) and not sys.argv[out_idx].startswith("--") else "screenshot.png"
            out_path = Path(out_file).resolve()
            root.captureScreenshot(str(out_path))
            QTimer.singleShot(400, app.quit)
        QTimer.singleShot(350, capture)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

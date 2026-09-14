#!/usr/bin/env python3
"""
CyberSweeper - Sleek Modern Retro Minesweeper for macOS & Omarchy Linux.
Features:
- Dynamic theme synchronization with live colors.toml & QStyleHints
- Low latency native CoreAudio sounds on macOS / pw-play on Linux
- Best time records per difficulty via QSettings
"""

import os
import sys
import tomllib
import ctypes
import shutil
import subprocess
from pathlib import Path
from PySide6.QtGui import QIcon, QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QFileSystemWatcher, QTimer, QObject, Slot, QSettings, QUrl

class SettingsManager(QObject):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.settings = QSettings("Arcade", "CyberSweeper")

    @Slot(str, result=int)
    def getBestTime(self, diff):
        key = f"bestTime_{diff}"
        try:
            val = self.settings.value(key, 999)
            return int(val) if val is not None else 999
        except (ValueError, TypeError):
            return 999

    @Slot(str, int)
    def setBestTime(self, diff, timeVal):
        key = f"bestTime_{diff}"
        self.settings.setValue(key, int(timeVal))

class SoundManager(QObject):
    def __init__(self, sounds_dir, parent=None):
        super().__init__(parent)
        self.sounds_dir = Path(sounds_dir)
        self.sounds = {}
        self.is_mac = sys.platform == "darwin"
        self.audiotoolbox = None
        self.player_cmd = None

        if self.is_mac:
            try:
                self.audiotoolbox = ctypes.cdll.LoadLibrary(
                    "/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox"
                )
                self.audiotoolbox.AudioServicesCreateSystemSoundID.argtypes = [
                    ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32)
                ]
                self.audiotoolbox.AudioServicesPlaySystemSound.argtypes = [ctypes.c_uint32]
                self.cf = ctypes.cdll.LoadLibrary(
                    "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"
                )
                self.cf.CFURLCreateFromFileSystemRepresentation.argtypes = [
                    ctypes.c_void_p, ctypes.c_char_p, ctypes.c_long, ctypes.c_bool
                ]
                self.cf.CFURLCreateFromFileSystemRepresentation.restype = ctypes.c_void_p
                self.cf.CFRelease.argtypes = [ctypes.c_void_p]
            except Exception as e:
                print(f"[SoundManager] CoreAudio load failed: {e}")
                self.audiotoolbox = None
        else:
            self.player_cmd = shutil.which("pw-play") or shutil.which("aplay") or shutil.which("paplay")

        self.preload_sounds()

    def preload_sounds(self):
        sound_names = ["click", "flag", "unflag", "explode", "win"]
        for name in sound_names:
            wav_path = self.sounds_dir / f"{name}.wav"
            if not wav_path.exists():
                continue
            if self.is_mac and self.audiotoolbox:
                try:
                    c_path = str(wav_path.resolve()).encode("utf-8")
                    cf_url = self.cf.CFURLCreateFromFileSystemRepresentation(None, c_path, len(c_path), False)
                    if cf_url:
                        sound_id = ctypes.c_uint32(0)
                        status = self.audiotoolbox.AudioServicesCreateSystemSoundID(
                            cf_url, ctypes.byref(sound_id)
                        )
                        self.cf.CFRelease(cf_url)
                        if status == 0:
                            self.sounds[name] = sound_id.value
                except Exception as e:
                    print(f"[SoundManager] Error loading sound {name}: {e}")
            else:
                self.sounds[name] = str(wav_path)

    @Slot(str)
    def play(self, sound_name):
        if not sound_name or sound_name not in self.sounds:
            return

        if self.is_mac and self.audiotoolbox:
            sound_id = self.sounds[sound_name]
            self.audiotoolbox.AudioServicesPlaySystemSound(ctypes.c_uint32(sound_id))
        elif self.player_cmd:
            wav_path = self.sounds[sound_name]
            try:
                subprocess.Popen([self.player_cmd, wav_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception:
                pass

DEFAULT_PRESETS = {
    "dark": {
        "name": "Omarchy Dark",
        "bg": "#181825",
        "fg": "#cdd6f4",
        "accent": "#89b4fa",
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
        "accent": "#1e66f5",
        "boardBg": "#dce0e8",
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
            "accent": colors.get("blue", colors.get("accent", "#89b4fa")),
            "boardBg": colors.get("mantle", "#1e1e2e"),
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
    app.setApplicationName("CyberSweeper")
    app.setOrganizationName("Omarchy")

    base_dir = Path(__file__).resolve().parent
    sounds_dir = base_dir / "sounds"

    # Set icon
    icon_candidates = [
        base_dir / "assets" / "disk_icon.png",
        base_dir.parent.parent / "assets" / "covers" / "cybersweeper_disk.png",
        Path.home() / ".local" / "share" / "omarchy-arcade" / "assets" / "covers" / "cybersweeper_disk.png",
    ]
    for ic in icon_candidates:
        if ic.exists():
            app.setWindowIcon(QIcon(str(ic)))
            break

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
        QTimer.singleShot(400, capture)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

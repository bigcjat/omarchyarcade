#!/usr/bin/env python3
"""
Omarchy Arcade: DinoRunner (Chromium T-Rex Runner)
- Pure QML / JavaScript authentic Chromium T-Rex endless runner
- Live hot-reloading from ~/.config/omarchy/current/theme/colors.toml
- Zero-overhead low latency audio playback via AudioToolbox (macOS) / PipeWire / ALSA (Linux)
- Persistent High Score storage via QSettings
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
        self.settings = QSettings("Arcade", "DinoRunner")
        self.legacy_settings = QSettings("Arcade", "CyberDash")

    @Slot(result=int)
    def getHighScore(self):
        try:
            val = int(self.settings.value("highScore", 0))
            if val == 0:
                val = int(self.legacy_settings.value("highScore", 0))
                if val > 0:
                    self.settings.setValue("highScore", val)
            return val
        except (ValueError, TypeError):
            return 0

    @Slot(int)
    def setHighScore(self, score):
        curr = self.getHighScore()
        if score > curr:
            self.settings.setValue("highScore", int(score))

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
        colors = {}
        if "colors" in data:
            c = data["colors"]
            colors["bg"] = c.get("background") or c.get("bg") or "#1e1e2e"
            colors["fg"] = c.get("foreground") or c.get("fg") or "#cdd6f4"
            colors["accent"] = c.get("accent") or c.get("primary") or "#89b4fa"
            colors["boardBg"] = c.get("selection_background") or c.get("surface") or "#181825"
            colors["cardBg"] = c.get("card") or c.get("surface0") or "#313244"
            colors["border"] = c.get("border") or "#45475a"
            colors["subtext"] = c.get("subtext") or c.get("subtext0") or "#a6adc8"
            colors["name"] = data.get("theme", {}).get("name", path.stem.capitalize())
            return colors
        for section in ["theme", "palette", "base"]:
            if section in data and isinstance(data[section], dict):
                c = data[section]
                if "background" in c or "bg" in c:
                    colors["bg"] = c.get("background") or c.get("bg") or "#1e1e2e"
                    colors["fg"] = c.get("foreground") or c.get("fg") or "#cdd6f4"
                    colors["accent"] = c.get("accent") or c.get("primary") or "#89b4fa"
                    colors["boardBg"] = c.get("surface") or "#181825"
                    colors["cardBg"] = c.get("card") or "#313244"
                    colors["border"] = c.get("border") or "#45475a"
                    colors["subtext"] = c.get("subtext") or "#a6adc8"
                    colors["name"] = path.stem.capitalize()
                    return colors
    except Exception:
        pass
    return None

def load_all_omarchy_themes():
    themes = {}
    themes_dir = Path.home() / ".config" / "omarchy" / "themes"
    if themes_dir.exists():
        for theme_file in themes_dir.glob("*/colors.toml"):
            t = parse_toml_theme(theme_file)
            if t:
                themes[theme_file.parent.name.lower()] = t
    return themes

def hex_to_rgb(h, default=(200, 200, 200)):
    try:
        h = str(h).lstrip('#')
        if len(h) == 6:
            return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
    except Exception:
        pass
    return default

def generate_themed_sprites(theme_colors, assets_dir: Path):
    try:
        from PySide6.QtGui import QImage, QColor
        base_path = assets_dir / "offline-sprite-2x-white.png"
        if not base_path.is_file():
            return
        qimg = QImage(str(base_path)).convertToFormat(QImage.Format.Format_ARGB32)
        if qimg.isNull():
            return

        w, h = qimg.width(), qimg.height()

        accent = QColor(theme_colors.get("accent") or "#89b4fa")
        fg = QColor(theme_colors.get("fg") or "#cdd6f4")
        border = QColor(theme_colors.get("border") or "#45475a")
        subtext = QColor(theme_colors.get("subtext") or "#6c7086")
        red = QColor(theme_colors.get("red") or "#f38ba8")
        peach = QColor(theme_colors.get("peach") or "#fab387")
        yellow = QColor(theme_colors.get("yellow") or "#f9e2af")
        white = QColor("#ffffff")

        out_day = QImage(qimg.size(), QImage.Format.Format_ARGB32)
        out_day.fill(0)
        out_night = QImage(qimg.size(), QImage.Format.Format_ARGB32)
        out_night.fill(0)

        for y in range(h):
            for x in range(w):
                pix = qimg.pixelColor(x, y)
                if pix.alpha() == 0:
                    continue
                factor = pix.red() / 255.0

                if y >= 100:
                    d_col, n_col = border, accent
                elif 160 <= x <= 258:
                    d_col, n_col = subtext, border
                elif 259 <= x <= 444:
                    d_col, n_col = peach, yellow
                elif 445 <= x <= 952:
                    d_col, n_col = red, red
                elif 953 <= x <= 1270:
                    d_col, n_col = yellow, yellow
                elif 1271 <= x <= 1335:
                    d_col, n_col = fg, white
                elif 1336 <= x <= 2110:
                    d_col, n_col = accent, fg
                else:
                    d_col, n_col = accent, fg

                out_day.setPixelColor(x, y, QColor(int(d_col.red() * factor), int(d_col.green() * factor), int(d_col.blue() * factor), pix.alpha()))
                out_night.setPixelColor(x, y, QColor(int(n_col.red() * factor), int(n_col.green() * factor), int(n_col.blue() * factor), pix.alpha()))

        out_day.save(str(assets_dir / "offline-sprite-themed.png"))
        out_night.save(str(assets_dir / "offline-sprite-night.png"))
    except Exception as e:
        print("Theme sprite generation error:", e)

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


def load_system_theme():
    theme_path = find_omarchy_colors_file()
    if theme_path and theme_path.exists():
        return parse_toml_theme(theme_path)
    return None

def main():
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    app = QGuiApplication(sys.argv)
    app.setApplicationName("DinoRunner")
    app.setOrganizationName("Omarchy")
    # Set application icon to game floppy disk
    script_dir = Path(__file__).resolve().parent
    disk_candidates = [
        script_dir / "assets" / "disk_icon.png",
        script_dir.parent.parent / "assets" / "covers" / "dinorunner_disk.png",
        Path.home() / ".local" / "share" / "omarchy-arcade" / "assets" / "covers" / "dinorunner_disk.png",
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
    all_themes = load_all_omarchy_themes()

    requested_theme = None
    requested_screenshot = None
    requested_width = None
    requested_height = None
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--theme" and i + 1 < len(args):
            requested_theme = args[i + 1].lower()
            i += 2
        elif args[i] == "--screenshot" and i + 1 < len(args):
            requested_screenshot = args[i + 1]
            i += 2
        elif args[i] == "--width" and i + 1 < len(args):
            requested_width = int(args[i + 1])
            i += 2
        elif args[i] == "--height" and i + 1 < len(args):
            requested_height = int(args[i + 1])
            i += 2
        else:
            i += 1

    if requested_width:
        root.setWidth(requested_width)
    if requested_height:
        root.setHeight(requested_height)

    assets_dir = base_dir / "assets"
    active_theme = None
    if requested_theme and requested_theme in all_themes:
        active_theme = all_themes[requested_theme]
        generate_themed_sprites(active_theme, assets_dir)
        root.applyTheme(active_theme, requested_theme)
    else:
        sys_theme = load_system_theme()
        if sys_theme:
            active_theme = sys_theme
            generate_themed_sprites(sys_theme, assets_dir)
            root.applyTheme(sys_theme, "System")
        elif "catppuccin" in all_themes:
            active_theme = all_themes["catppuccin"]
            generate_themed_sprites(active_theme, assets_dir)
            root.applyTheme(active_theme, "Catppuccin")
        else:
            default_catppuccin = {
                "bg": "#1e1e2e", "fg": "#cdd6f4", "accent": "#89b4fa",
                "boardBg": "#181825", "cardBg": "#313244", "border": "#45475a",
                "subtext": "#a6adc8", "red": "#f38ba8", "peach": "#fab387", "yellow": "#f9e2af"
            }
            generate_themed_sprites(default_catppuccin, assets_dir)
            root.applyTheme(default_catppuccin, "Catppuccin")

    theme_file = find_omarchy_colors_file()
    watcher = QFileSystemWatcher()
    if theme_file and theme_file.parent.exists():
        watcher.addPath(str(theme_file.parent))
    if theme_file and theme_file.exists():
        watcher.addPath(str(theme_file))

    def on_theme_file_changed(path):
        QTimer.singleShot(150, update_theme)

    def update_theme():
        if requested_theme: return
        t = load_system_theme()
        if t:
            generate_themed_sprites(t, assets_dir)
            root.applyTheme(t, "System")

    watcher.fileChanged.connect(on_theme_file_changed)
    watcher.directoryChanged.connect(on_theme_file_changed)

    requested_test_features = "--test-features" in args

    if requested_screenshot:
        def start_and_shot():
            root.splashEnabled = False
            root.startNewGame()
            if requested_test_features:
                root.toggleNightMode()
                root.spawnPterodactyl()
                QTimer.singleShot(450, lambda: root.captureScreenshot(requested_screenshot, True))
            else:
                QTimer.singleShot(700, lambda: root.captureScreenshot(requested_screenshot, True))
        QTimer.singleShot(400, start_and_shot)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

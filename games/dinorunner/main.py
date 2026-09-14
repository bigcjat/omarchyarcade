#!/usr/bin/env python3
"""
Omarchy Arcade: DinoRunner (Chromium T-Rex Runner)
- Pure QML / JavaScript authentic Chromium T-Rex endless runner
- Live hot-reloading from ~/.local/state/omarchy/current/theme/colors.toml and QStyleHints
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
        "subtext": "#a6adc8",
        "red": "#f38ba8",
        "peach": "#fab387",
        "yellow": "#f9e2af",
        "sprite_fg": "#cdd6f4"
    },
    "light": {
        "name": "Omarchy Light",
        "bg": "#eff1f5",
        "fg": "#4c4f69",
        "accent": "#1e66f5",
        "boardBg": "#1e1e2e",
        "card_bg": "#ffffff",
        "card_hover": "#f1f5f9",
        "border": "#ccd0da",
        "subtext": "#5c5f77",
        "red": "#d20f39",
        "peach": "#fe640b",
        "yellow": "#df8e1d",
        "sprite_fg": "#cdd6f4"
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
            "name": data.get("theme", {}).get("name", path.stem.capitalize()),
            "bg": bg,
            "fg": fg,
            "accent": colors.get("accent") or colors.get("blue") or "#89b4fa",
            "boardBg": "#1e1e2e",
            "card_bg": colors.get("surface0", "#313244"),
            "card_hover": colors.get("surface1", "#45475a"),
            "border": colors.get("surface1", "#45475a"),
            "subtext": colors.get("subtext0", "#a6adc8"),
            "red": colors.get("red", "#f38ba8"),
            "peach": colors.get("peach", "#fab387"),
            "yellow": colors.get("yellow", "#f9e2af"),
            "sprite_fg": "#cdd6f4"
        }
    except Exception:
        return None

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

        # Day colors (for light background): high contrast & crisp!
        d_trex = QColor("#1e66f5")     # Crisp royal blue T-Rex
        d_horizon = QColor("#8c90a4")  # Defined slate ground line
        d_cloud = QColor("#9ca3af")    # Soft cloud
        d_cactus = QColor("#d20f39")   # Deep red cactus
        d_ptero = QColor("#e64553")    # Deep coral pterodactyl

        # Night colors (for dark background): bright neon / retro arcade!
        n_trex = QColor("#89b4fa")     # Bright pastel blue T-Rex
        n_horizon = QColor("#45475a")  # Muted night ground line
        n_cloud = QColor("#585b70")    # Night cloud
        n_cactus = QColor("#f38ba8")   # Neon pink/red cactus
        n_ptero = QColor("#fab387")    # Bright peach pterodactyl
        n_moon = QColor("#f9e2af")     # Golden moon
        n_star = QColor("#ffffff")     # Bright white star

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
                    d_col, n_col = d_horizon, n_horizon
                elif 160 <= x <= 258:
                    d_col, n_col = d_cloud, n_cloud
                elif 259 <= x <= 444:
                    d_col, n_col = d_ptero, n_ptero
                elif 445 <= x <= 952:
                    d_col, n_col = d_cactus, n_cactus
                elif 953 <= x <= 1270:
                    d_col, n_col = d_ptero, n_moon
                elif 1271 <= x <= 1335:
                    d_col, n_col = d_cloud, n_star
                elif 1336 <= x <= 2110:
                    d_col, n_col = d_trex, n_trex
                else:
                    d_col, n_col = d_trex, n_trex

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

    base_dir = script_dir
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

    def apply_theme_data(theme_data, name=""):
        generate_themed_sprites(theme_data, assets_dir)
        root.applyTheme(theme_data, name)

    if requested_theme in DEFAULT_PRESETS:
        apply_theme_data(DEFAULT_PRESETS[requested_theme], DEFAULT_PRESETS[requested_theme]["name"])
        print(f"Applied preset theme: {DEFAULT_PRESETS[requested_theme]['name']}")
    else:
        sys_theme = load_system_theme()
        if sys_theme:
            apply_theme_data(sys_theme, sys_theme.get("name", "System"))
        else:
            is_dark = True
            try:
                from PySide6.QtGui import Qt
                is_dark = app.styleHints().colorScheme() == Qt.ColorScheme.Dark
            except Exception:
                pass
            preset_key = "dark" if is_dark else "light"
            apply_theme_data(DEFAULT_PRESETS[preset_key], DEFAULT_PRESETS[preset_key]["name"])

    theme_file = find_omarchy_colors_file()
    watcher = QFileSystemWatcher()
    if theme_file and theme_file.parent.exists():
        watcher.addPath(str(theme_file.parent))
    if theme_file and theme_file.exists():
        watcher.addPath(str(theme_file))

    def update_theme():
        if requested_theme:
            return
        t = load_system_theme()
        if t:
            apply_theme_data(t, t.get("name", "System"))
        else:
            try:
                from PySide6.QtGui import Qt
                is_dark = app.styleHints().colorScheme() == Qt.ColorScheme.Dark
                preset_key = "dark" if is_dark else "light"
                apply_theme_data(DEFAULT_PRESETS[preset_key], DEFAULT_PRESETS[preset_key]["name"])
            except Exception:
                pass

    watcher.fileChanged.connect(lambda path: QTimer.singleShot(150, update_theme))
    watcher.directoryChanged.connect(lambda path: QTimer.singleShot(150, update_theme))
    app.styleHints().colorSchemeChanged.connect(lambda scheme: update_theme())

    requested_test_features = "--test-features" in args

    if requested_screenshot:
        root.screenshotSaved.connect(lambda p: app.quit())
        def start_and_shot():
            root.splashEnabled = False
            root.startNewGame()
            if requested_test_features:
                root.toggleNightMode()
                root.spawnPterodactyl()
                QTimer.singleShot(500, lambda: root.captureScreenshot(requested_screenshot))
            else:
                QTimer.singleShot(500, lambda: root.captureScreenshot(requested_screenshot))
        QTimer.singleShot(300, start_and_shot)

    
    if "--unmute" in sys.argv or "--sound" in sys.argv:
        for _obj in engine.rootObjects():
            _obj.setProperty("isMuted", False)
    elif "--mute" in sys.argv:
        for _obj in engine.rootObjects():
            _obj.setProperty("isMuted", True)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

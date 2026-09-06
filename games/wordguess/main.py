#!/usr/bin/env python3
"""
Omarchy Arcade: WordGuess (Wordle)
- Pure QML / JavaScript 5-letter deduction puzzle
- Live hot-reloading from ~/.config/omarchy/current/theme/colors.toml
- Zero-overhead low latency audio playback
- Fully responsive to tiling window managers
"""

import sys
import os
import tomllib
from pathlib import Path
from PySide6.QtCore import QObject, Slot, QUrl, QFileSystemWatcher, QTimer
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

try:
    from AppKit import NSSound
    HAS_NSSOUND = True
except ImportError:
    HAS_NSSOUND = False

class AudioController(QObject):
    def __init__(self, sounds_dir: Path):
        super().__init__()
        self.sounds_dir = sounds_dir
        self._sounds = {}
        if HAS_NSSOUND:
            for wav in sounds_dir.glob("*.wav"):
                snd = NSSound.alloc().initWithContentsOfFile_byReference_(str(wav), True)
                if snd:
                    self._sounds[wav.stem] = snd

    @Slot(str)
    def playSound(self, name: str):
        if HAS_NSSOUND and name in self._sounds:
            snd = self._sounds[name]
            snd.stop()
            snd.play()

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

def load_system_theme():
    theme_path = Path.home() / ".config" / "omarchy" / "current" / "theme" / "colors.toml"
    if theme_path.exists():
        return parse_toml_theme(theme_path)
    return None

def main():
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    app = QGuiApplication(sys.argv)
    app.setApplicationName("WordGuess")
    app.setOrganizationName("Omarchy")

    base_dir = Path(__file__).resolve().parent
    sounds_dir = base_dir / "sounds"
    audio_controller = AudioController(sounds_dir)

    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("audioController", audio_controller)

    qml_file = base_dir / "main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        sys.exit(-1)

    root = engine.rootObjects()[0]
    all_themes = load_all_omarchy_themes()

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

    if requested_theme and requested_theme in all_themes:
        root.applyTheme(all_themes[requested_theme], requested_theme)
    else:
        sys_theme = load_system_theme()
        if sys_theme:
            root.applyTheme(sys_theme, "System")
        elif "catppuccin" in all_themes:
            root.applyTheme(all_themes["catppuccin"], "Catppuccin")

    theme_file = Path.home() / ".config" / "omarchy" / "current" / "theme" / "colors.toml"
    watcher = QFileSystemWatcher()
    if theme_file.parent.exists():
        watcher.addPath(str(theme_file.parent))
    if theme_file.exists():
        watcher.addPath(str(theme_file))

    def on_theme_file_changed(path):
        QTimer.singleShot(150, update_theme)

    def update_theme():
        if requested_theme: return
        t = load_system_theme()
        if t: root.applyTheme(t, "System")

    watcher.fileChanged.connect(on_theme_file_changed)
    watcher.directoryChanged.connect(on_theme_file_changed)

    if requested_screenshot:
        def do_shot():
            root.splashEnabled = False
            root.captureScreenshot(requested_screenshot, True)
        QTimer.singleShot(1250, do_shot)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

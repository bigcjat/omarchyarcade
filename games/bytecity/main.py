#!/usr/bin/env python3
"""
Omarchy Arcade • ByteCity (Classic SimCity)
Canonical arcade game host with theme synchronization, native simulation engine,
and low-latency CoreAudio sound effects.
"""

import os
import sys
import re
import shutil
import subprocess
import tomllib
import ctypes
from pathlib import Path

# Add project root to sys.path
ROOT_DIR = Path(__file__).resolve().parent.parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from PySide6.QtCore import QFileSystemWatcher, QTimer, QObject, Slot, QSettings, Qt, QUrl
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterType

from games.bytecity.engine import ByteCityEngine
from games.bytecity.viewport import CityViewport

# =============================================================================
# PERSISTENT SETTINGS MANAGER
# =============================================================================
class SettingsManager(QObject):
    """Provides local persistence via QSettings."""
    def __init__(self, game_id="ByteCity", parent=None):
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

    @Slot(str, str)
    def setValue(self, key, val):
        self.settings.setValue(key, val)

    @Slot(str, str, result=str)
    def getValue(self, key, default_val=""):
        return str(self.settings.value(key, default_val))

# =============================================================================
# THEME UTILITIES
# =============================================================================
DEFAULT_PRESETS = {
    "dark": {
        "name": "Omarchy Dark",
        "background": "#1e1e2e",
        "foreground": "#cdd6f4",
        "accent": "#89b4fa",
        "color0": "#181825",
        "color8": "#313244",
        "cardBg": "#181825",
        "boardBg": "#11111b",
        "border": "#313244",
        "subtext": "#a6adc8",
    },
    "light": {
        "name": "Omarchy Light",
        "background": "#eff1f5",
        "foreground": "#4c4f69",
        "accent": "#1e66f5",
        "color0": "#e6e9ef",
        "color8": "#bcc0cc",
        "cardBg": "#ffffff",
        "boardBg": "#e6e9ef",
        "border": "#ccd0da",
        "subtext": "#5c5f77",
    },
}

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

def load_toml_colors(file_path):
    try:
        with open(file_path, "rb") as f:
            data = tomllib.load(f)
        if isinstance(data, dict) and "colors" in data and isinstance(data["colors"], dict):
            merged = dict(data)
            merged.update(data["colors"])
            return merged
        return data
    except Exception as e:
        print(f"Warning: Failed to load {file_path}: {e}", file=sys.stderr)
        return None

# =============================================================================
# MAIN ENTRYPOINT
# =============================================================================
def main():
    os.environ["QT_ENABLE_HIGHDPI_SCALING"] = "1"
    os.environ["QML_XHR_ALLOW_FILE_READ"] = "1"
    os.environ["QSG_RENDER_LOOP"] = "basic"

    if "--help" in sys.argv or "-h" in sys.argv:
        print("ByteCity \u2022 Classic Metropolis Simulation")
        sys.exit(0)

    if "--list-themes" in sys.argv:
        print("Arcade Game Template \u2022 Preset Themes:\n  --theme light\n  --theme dark\n  --theme <path_to_colors.toml>")
        sys.exit(0)

    app = QGuiApplication(sys.argv)
    app.setApplicationName("ByteCity")
    app.setOrganizationName("Omarchy")

    # Set application icon to game floppy disk
    script_dir = Path(__file__).resolve().parent
    disk_icon = script_dir / "assets" / "disk_icon.png"
    if disk_icon.exists():
        app.setWindowIcon(QIcon(str(disk_icon)))

    # Register 2D City Viewport
    qmlRegisterType(CityViewport, "ByteCity", 1, 0, "CityViewport")
    qmlRegisterType(CityViewport, "OmarchyCity", 1, 0, "CityViewport")

    # Initialize Engine & Settings
    engine_obj = ByteCityEngine()
    settings_mgr = SettingsManager("OmarchyCity")

    qml_engine = QQmlApplicationEngine()
    qml_engine.rootContext().setContextProperty("cityEngine", engine_obj)
    qml_engine.rootContext().setContextProperty("settingsManager", settings_mgr)

    qml_path = script_dir / "main.qml"
    qml_engine.load(QUrl.fromLocalFile(str(qml_path)))

    if not qml_engine.rootObjects():
        print("Failed to load QML interface", file=sys.stderr)
        sys.exit(1)

    root_window = qml_engine.rootObjects()[0]
    vp = root_window.findChild(CityViewport)
    if vp:
        vp.set_city_engine(engine_obj)

    # CLI Theme Argument Parsing
    theme_arg = None
    if "--theme" in sys.argv:
        idx = sys.argv.index("--theme")
        if idx + 1 < len(sys.argv):
            theme_arg = sys.argv[idx + 1]

    if theme_arg:
        clean_arg = theme_arg.lower().strip()
        if clean_arg in DEFAULT_PRESETS:
            t = DEFAULT_PRESETS[clean_arg]
            root_window.applyTheme(t, t["name"])
            print(f"Applied preset theme: {t['name']}")
        else:
            custom_path = Path(theme_arg).expanduser().resolve()
            if custom_path.is_file():
                data = load_toml_colors(custom_path)
                if data:
                    root_window.applyTheme(data, custom_path.parent.name.capitalize())
                    print(f"Applied theme from file: {custom_path}")
            else:
                print(f"Warning: Theme '{theme_arg}' not found.", file=sys.stderr)
    else:
        system_colors = find_omarchy_colors_file()
        if system_colors:
            data = load_toml_colors(system_colors)
            if data:
                theme_name = system_colors.parent.name.capitalize()
                root_window.applyTheme(data, theme_name)

            watcher = QFileSystemWatcher(app)
            watcher.addPath(str(system_colors))
            if system_colors.parent.exists():
                watcher.addPath(str(system_colors.parent))

            def on_theme_updated(path):
                colors_path = find_omarchy_colors_file()
                if colors_path and colors_path.is_file():
                    updated = load_toml_colors(colors_path)
                    if updated:
                        root_window.applyTheme(updated, colors_path.parent.name.capitalize())

            watcher.fileChanged.connect(on_theme_updated)
            watcher.directoryChanged.connect(on_theme_updated)
        else:
            def apply_system_scheme():
                scheme = app.styleHints().colorScheme()
                target_theme = DEFAULT_PRESETS["light"] if scheme == Qt.ColorScheme.Light else DEFAULT_PRESETS["dark"]
                root_window.applyTheme(target_theme, target_theme["name"])
            apply_system_scheme()
            app.styleHints().colorSchemeChanged.connect(lambda _: apply_system_scheme())

    # Disable splash if requested
    if "--no-splash" in sys.argv:
        root_window.setProperty("splashEnabled", False)

    # Screenshot automation
    if "--screenshot" in sys.argv:
        root_window.setProperty("splashEnabled", False)
        root_window.setProperty("showInaugurationModal", False)
        def capture():
            out_idx = sys.argv.index("--screenshot") + 1
            out_file = sys.argv[out_idx] if out_idx < len(sys.argv) and not sys.argv[out_idx].startswith("--") else "screenshot.png"
            out_path = Path(out_file).resolve()
            root_window.captureScreenshot(str(out_path), False)
            QTimer.singleShot(400, app.quit)
        QTimer.singleShot(400, capture)

    def cleanup():
        engine_obj.close()

    app.aboutToQuit.connect(cleanup)
    sys.exit(app.exec())

if __name__ == "__main__":
    main()

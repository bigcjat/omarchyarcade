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
def load_all_omarchy_themes():
    """Parses Themes.js for all predefined Omarchy color schemes."""
    themes_js = Path(__file__).resolve().parent / "Themes.js"
    if not themes_js.is_file():
        return {}
    with open(themes_js, "r", encoding="utf-8") as f:
        content = f.read()
    themes = {}
    blocks = re.findall(r"\{([^{}]+)\}", content)
    for b in blocks:
        t = {}
        for k, v in re.findall(r"(\w+):\s*\"([^\"]+)\"", b):
            t[k] = v
        if "id" in t and "name" in t:
            themes[t["id"]] = t
    return themes

ALL_THEMES = load_all_omarchy_themes()

def find_omarchy_colors_file():
    """Finds current Omarchy desktop theme colors.toml configuration."""
    home = Path.home()
    candidates = [
        home / ".config" / "omarchy" / "current" / "theme" / "colors.toml",
        home / ".config" / "omarchy" / "colors.toml",
    ]
    for c in candidates:
        if c.is_file():
            return c
    return None

def load_toml_colors(file_path):
    """Loads a TOML theme configuration file."""
    try:
        with open(file_path, "rb") as f:
            data = tomllib.load(f)
            return data.get("colors", data)
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

    if "--list-themes" in sys.argv:
        print(f"ByteCity • Available Themes ({len(ALL_THEMES)} total):\n")
        for tid, t in ALL_THEMES.items():
            print(f"    --theme {tid:<20} -> {t['name']}")
        sys.exit(0)

    app = QGuiApplication(sys.argv)
    app.setApplicationName("ByteCity")
    app.setOrganizationName("Omarchy")

    # Set application icon to game floppy disk
    script_dir = Path(__file__).resolve().parent
    disk_candidates = [
        script_dir / "assets" / "disk_icon.png",
        script_dir.parent.parent / "assets" / "covers" / "bytecity_disk.png",
        Path.home() / ".local" / "share" / "omarchy-arcade" / "assets" / "covers" / "bytecity_disk.png",
    ]
    for cp in disk_candidates:
        if cp.exists():
            app.setWindowIcon(QIcon(str(cp)))
            break

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

    # Handle Theme selection
    target_theme = None
    if "--theme" in sys.argv:
        try:
            t_idx = sys.argv.index("--theme") + 1
            if t_idx < len(sys.argv):
                theme_arg = sys.argv[t_idx]
                if theme_arg in ALL_THEMES:
                    target_theme = ALL_THEMES[theme_arg]
                else:
                    for tid, tdata in ALL_THEMES.items():
                        if theme_arg.lower() in tid.lower() or theme_arg.lower() in tdata.get("name", "").lower():
                            target_theme = tdata
                            break
        except Exception:
            pass

    if target_theme:
        root_window.applyTheme(target_theme, target_theme.get("name", "Custom"))
    else:
        colors_file = find_omarchy_colors_file()
        if colors_file:
            toml_colors = load_toml_colors(colors_file)
            if toml_colors:
                root_window.applyTheme(toml_colors, "Omarchy System")

    # Watch for dynamic system theme changes
    colors_file = find_omarchy_colors_file()
    if colors_file:
        watcher = QFileSystemWatcher([str(colors_file)])
        def on_theme_changed(path):
            tc = load_toml_colors(path)
            if tc:
                root_window.applyTheme(tc, "Omarchy System")
        watcher.fileChanged.connect(on_theme_changed)

    # Disable splash if requested
    if "--no-splash" in sys.argv:
        root_window.setProperty("splashEnabled", False)

    def cleanup():
        engine_obj.close()

    app.aboutToQuit.connect(cleanup)
    sys.exit(app.exec())

if __name__ == "__main__":
    main()

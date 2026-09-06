#!/usr/bin/env python3
"""
Omarchy Arcade • Desktop Game Suite Launcher
Lightweight, native PySide6 hub for launching games across the Omarchy Arcade suite.
Features:
- Instant launch with decoupled sub-process game spawning
- Native Omarchy desktop theme synchronization
- Offline-first execution (zero network sockets, zero telemetry)
- Responsive QML UI integration
"""

import os
import sys
import json
import tomllib
import subprocess
import threading
from pathlib import Path
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QObject, Slot, Signal, Property, QTimer, QUrl, QFileSystemWatcher
from PySide6.QtQuickControls2 import QQuickStyle

# Allow local file access for QML XMLHttpRequest if used
os.environ["QML_XHR_ALLOW_FILE_READ"] = "1"

BASE_DIR = Path(__file__).resolve().parent.parent
LAUNCHER_DIR = Path(__file__).resolve().parent
GAMES_DIR = BASE_DIR / "games"
CATALOG_PATH = BASE_DIR / "catalog.json"

class ArcadeBackend(QObject):
    """Backend services bridging the QML Launcher to local desktop execution."""
    gameLaunched = Signal(str)
    gameLaunchFailed = Signal(str, str)
    gameFinished = Signal(str)
    _processExited = Signal(str)
    themeChanged = Signal("QVariantMap")

    def __init__(self, parent=None):
        super().__init__(parent)
        self._active_processes = []
        self._main_window = None
        self._processExited.connect(self._on_game_finished)

    def setMainWindow(self, window):
        self._main_window = window

    @Slot(result="QVariantMap")
    def getThemeColors(self) -> dict:
        """Returns the current theme dictionary to QML."""
        return get_theme_colors()

    @Slot("QVariantMap")
    def applyTheme(self, colors: dict):
        """Allows programmatic or test-based theme application."""
        self.themeChanged.emit(colors)

    @Slot(result=str)
    def getCatalogJson(self) -> str:
        """Returns the raw JSON content of catalog.json directly to QML."""
        if CATALOG_PATH.exists():
            try:
                return CATALOG_PATH.read_text(encoding="utf-8")
            except Exception as e:
                print(f"[Arcade] Error reading catalog: {e}")
        return "{}"

    @Slot(str, result=str)
    def getScreenshotUrl(self, folder: str) -> str:
        """Returns the absolute file URL for a game's screenshot."""
        if not folder:
            return ""
        screenshot_path = BASE_DIR / folder / "screenshot.png"
        if screenshot_path.exists():
            return QUrl.fromLocalFile(str(screenshot_path)).toString()
        return ""

    @Slot(str)
    def launchGame(self, game_id: str):
        """Spawns the requested game as an independent child process and hides the launcher."""
        game_dir = GAMES_DIR / game_id
        if not game_dir.exists():
            print(f"[Arcade] Error: Game directory not found: {game_dir}")
            self.gameLaunchFailed.emit(game_id, "Game directory not found.")
            return

        main_py = game_dir / "main.py"
        main_qml = game_dir / "main.qml"

        cmd = []
        if main_py.exists():
            cmd = [sys.executable, str(main_py)]
        elif main_qml.exists():
            cmd = ["qml6", str(main_qml)]
        else:
            print(f"[Arcade] Error: No main.py or main.qml found in {game_dir}")
            self.gameLaunchFailed.emit(game_id, "Executable entrypoint not found.")
            return

        try:
            print(f"[Arcade] Launching game: {game_id} via {cmd}")
            proc = subprocess.Popen(
                cmd,
                cwd=str(game_dir),
                start_new_session=True
            )
            self._active_processes.append(proc)
            self.gameLaunched.emit(game_id)

            # Option 1: Hide launcher while game is running
            if self._main_window:
                self._main_window.hide()

            # Watch process termination in background thread to restore launcher
            def wait_for_exit(p, gid):
                p.wait()
                self._processExited.emit(gid)

            t = threading.Thread(target=wait_for_exit, args=(proc, game_id), daemon=True)
            t.start()

        except Exception as e:
            print(f"[Arcade] Exception launching {game_id}: {e}")
            if self._main_window:
                self._main_window.show()
            self.gameLaunchFailed.emit(game_id, str(e))

    def _on_game_finished(self, game_id: str):
        """Restores the launcher when the game process terminates."""
        print(f"[Arcade] Game exited: {game_id}. Restoring launcher window...")
        if self._main_window:
            self._main_window.show()
            self._main_window.raise_()
            self._main_window.requestActivate()
        self.gameFinished.emit(game_id)

    @Slot()
    def quit(self):
        QGuiApplication.quit()


def find_omarchy_colors_file():
    candidates = [
        Path.home() / ".config" / "omarchy" / "current" / "theme" / "colors.toml",
        Path.home() / ".config" / "omarchy" / "colors.toml",
    ]
    for c in candidates:
        if c.is_file():
            return c
    return None


def get_theme_colors():
    """Reads the active Omarchy theme colors.toml if present."""
    colors = {
        "themeBackground": "#111116",
        "themeSurface": "#181822",
        "themeSurfaceLight": "#222230",
        "themeBorder": "#2d2d3d",
        "themeText": "#f1f5f9",
        "themeTextMuted": "#94a3b8",
        "themeAccent": "#00f0ff",
        "themeAccentAlt": "#e6458e"
    }

    theme_path = find_omarchy_colors_file()
    if theme_path:
        try:
            with open(theme_path, "rb") as f:
                data = tomllib.load(f)
                if "colors" in data:
                    c = data["colors"]
                    if "background" in c: colors["themeBackground"] = c["background"]
                    if "surface" in c: colors["themeSurface"] = c["surface"]
                    if "text" in c: colors["themeText"] = c["text"]
                    if "accent" in c: colors["themeAccent"] = c["accent"]
                    if "accent_alt" in c: colors["themeAccentAlt"] = c["accent_alt"]
                    if "border" in c: colors["themeBorder"] = c["border"]
                    if "surface_light" in c: colors["themeSurfaceLight"] = c["surface_light"]
                    if "text_muted" in c: colors["themeTextMuted"] = c["text_muted"]
        except Exception as e:
            print(f"[Arcade] Notice: Could not read theme colors: {e}")

    return colors


def main():
    if "--help" in sys.argv or "-h" in sys.argv:
        print("""Omarchy Arcade • Desktop Game Suite Launcher
Usage:
  ./arcade              Launch the full arcade library with retro boot splash
  ./arcade --no-splash  Launch directly to the library view
  ./arcade --help       Show this help message
""")
        sys.exit(0)

    QQuickStyle.setStyle("Basic")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Omarchy Arcade")
    app.setOrganizationName("Omarchy")

    backend = ArcadeBackend()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("arcadeBackend", backend)

    # Initial properties
    colors = get_theme_colors()
    initial_props = {
        "themeBackground": colors["themeBackground"],
        "themeSurface": colors["themeSurface"],
        "themeSurfaceLight": colors["themeSurfaceLight"],
        "themeBorder": colors["themeBorder"],
        "themeText": colors["themeText"],
        "themeTextMuted": colors["themeTextMuted"],
        "themeAccent": colors["themeAccent"],
        "themeAccentAlt": colors["themeAccentAlt"]
    }

    if "--no-splash" in sys.argv:
        initial_props["splashEnabled"] = False

    qml_file = LAUNCHER_DIR / "main.qml"
    engine.setInitialProperties(initial_props)
    engine.load(str(qml_file))

    if not engine.rootObjects():
        print(f"[Arcade] Error: Failed to load QML launcher from {qml_file}")
        sys.exit(1)

    window = engine.rootObjects()[0]
    backend.setMainWindow(window)

    # Set up live file watcher for Omarchy theme switches
    colors_file = find_omarchy_colors_file()
    watcher = None
    if colors_file:
        watcher = QFileSystemWatcher(app)
        watcher.addPath(str(colors_file))
        if colors_file.parent.exists():
            watcher.addPath(str(colors_file.parent))

        def on_theme_updated(path):
            updated_colors = get_theme_colors()
            backend.themeChanged.emit(updated_colors)
            if engine.rootObjects():
                root_obj = engine.rootObjects()[0]
                for k, v in updated_colors.items():
                    root_obj.setProperty(k, v)
            print(f"[Arcade] Omarchy theme live-reloaded from {path}")

        watcher.fileChanged.connect(on_theme_updated)
        watcher.directoryChanged.connect(on_theme_updated)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()

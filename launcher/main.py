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
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QObject, Slot, Signal, Property, QTimer, QUrl, QFileSystemWatcher
from PySide6.QtQuickControls2 import QQuickStyle

# Allow local file access for QML XMLHttpRequest if used
os.environ["QML_XHR_ALLOW_FILE_READ"] = "1"

BASE_DIR = Path(__file__).resolve().parent.parent
LAUNCHER_DIR = Path(__file__).resolve().parent

# If in source repository, use repository paths. Otherwise use ~/.local/share/omarchy-arcade
if (BASE_DIR / "games").is_dir():
    GAMES_DIR = BASE_DIR / "games"
    CATALOG_PATH = BASE_DIR / "catalog.json"
    ASSETS_DIR = BASE_DIR / "assets"
else:
    DATA_DIR = Path.home() / ".local" / "share" / "omarchy-arcade"
    GAMES_DIR = DATA_DIR / "games"
    CATALOG_PATH = DATA_DIR / "catalog.json"
    ASSETS_DIR = DATA_DIR / "assets"

GAMES_DIR.mkdir(parents=True, exist_ok=True)

class ArcadeBackend(QObject):
    """Backend services bridging the QML Launcher to local desktop execution."""
    gameLaunched = Signal(str)
    gameLaunchFailed = Signal(str, str)
    gameFinished = Signal(str)
    gameInstalled = Signal(str)
    gameInstallFailed = Signal(str, str)
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
        """Fetches the game catalog dynamically from GitHub (with local fallback/cache)."""
        import urllib.request
        import time
        remote_url = f"https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/catalog.json?_={int(time.time())}"
        try:
            req = urllib.request.Request(
                remote_url,
                headers={
                    "User-Agent": "OmarchyArcade/1.0",
                    "Cache-Control": "no-cache",
                    "Pragma": "no-cache"
                }
            )
            with urllib.request.urlopen(req, timeout=5) as resp:
                data = resp.read().decode("utf-8")
                if len(data) > 2:
                    # Cache catalog locally only if remote has at least as many games as local
                    try:
                        remote_json = json.loads(data)
                        local_count = 0
                        if CATALOG_PATH.exists():
                            try:
                                local_count = len(json.loads(CATALOG_PATH.read_text(encoding="utf-8")).get("games", []))
                            except Exception:
                                pass
                        if len(remote_json.get("games", [])) >= local_count:
                            CATALOG_PATH.write_text(data, encoding="utf-8")
                            return data
                        elif CATALOG_PATH.exists():
                            return CATALOG_PATH.read_text(encoding="utf-8")
                    except Exception:
                        pass
                    return data
        except Exception as e:
            print(f"[Arcade] Note: Could not reach remote catalog ({e}), trying local cache...")

        if CATALOG_PATH.exists():
            try:
                return CATALOG_PATH.read_text(encoding="utf-8")
            except Exception as e:
                print(f"[Arcade] Error reading local catalog: {e}")
        return "{}"

    @Slot(str, result=str)
    def getCoverUrl(self, game_id: str) -> str:
        """Returns the cover image URL, checking local cache first, then GitHub raw."""
        if not game_id:
            return ""
        # 1. Local path check
        local_path = BASE_DIR / "assets" / "covers" / f"{game_id}.png"
        if not local_path.exists():
            local_path = Path.home() / ".local" / "share" / "omarchy-arcade" / "assets" / "covers" / f"{game_id}.png"
        if local_path.exists():
            return QUrl.fromLocalFile(str(local_path)).toString()
        # 2. Remote GitHub raw URL
        return f"https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/assets/covers/{game_id}.png"

    @Slot(str, result=bool)
    def isGameInstalled(self, game_id: str) -> bool:
        """Checks if a game's executable files exist locally on disk."""
        if not game_id:
            return False
        game_dir = GAMES_DIR / game_id
        return (game_dir / "main.py").exists() or (game_dir / "main.qml").exists()

    @Slot(str, str, result=bool)
    def hasGameUpdate(self, game_id: str, catalog_version: str) -> bool:
        """Checks if an installed game has an update available compared to catalog.json."""
        # Only skip update checking if running directly inside a development git clone
        if (BASE_DIR / ".git").is_dir():
            return False
        if not game_id or not catalog_version:
            return False
        game_dir = GAMES_DIR / game_id
        if not (game_dir / "main.py").exists() and not (game_dir / "main.qml").exists():
            return False
        version_file = game_dir / ".version"
        if not version_file.exists():
            return True  # Installed prior to version stamping -> outdated!
        try:
            installed_v = version_file.read_text(encoding="utf-8").strip()
            return installed_v != str(catalog_version).strip()
        except Exception:
            return True

    @Slot(str, result=str)
    def getScreenshotUrl(self, folder: str) -> str:
        """Returns the file URL for a game's screenshot, with fallback to remote URL."""
        if not folder:
            return ""
        local_path = BASE_DIR / folder / "screenshot.png"
        if not local_path.exists():
            local_path = Path.home() / ".local" / "share" / "omarchy-arcade" / folder / "screenshot.png"
        if local_path.exists():
            return QUrl.fromLocalFile(str(local_path)).toString()
        return f"https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/{folder}/screenshot.png"

    @Slot(str, result=str)
    def getDiskIconUrl(self, game_id: str) -> str:
        """Returns the file URL for a game's 3.5" disk icon."""
        if not game_id:
            return ""
        local_path = GAMES_DIR / game_id / "assets" / "disk_icon.png"
        if not local_path.exists():
            local_path = BASE_DIR / "games" / game_id / "assets" / "disk_icon.png"
        if not local_path.exists():
            local_path = Path.home() / ".local" / "share" / "omarchy-arcade" / "games" / game_id / "assets" / "disk_icon.png"
        if local_path.exists():
            return QUrl.fromLocalFile(str(local_path)).toString()
        return self.getCoverUrl(game_id)

    def _get_settings_path(self) -> Path:
        if (BASE_DIR / ".git").exists():
            return LAUNCHER_DIR / ".launcher_settings.json"
        return Path.home() / ".config" / "omarchy" / "arcade_settings.json"

    @Slot(result=str)
    def getViewMode(self) -> str:
        """Reads persisted view mode preference ('grid', 'carousel', 'desktop', 'sidebar')."""
        settings_file = self._get_settings_path()
        if settings_file.exists():
            try:
                data = json.loads(settings_file.read_text(encoding="utf-8"))
                mode = data.get("view_mode", "sidebar")
                if mode in ("grid", "carousel", "desktop", "sidebar"):
                    return mode
            except Exception:
                pass
        return "sidebar"

    @Slot(str)
    def setViewMode(self, mode: str):
        """Persists view mode preference."""
        if mode not in ("grid", "carousel", "desktop", "sidebar"):
            return
        settings_file = self._get_settings_path()
        data = {}
        if settings_file.exists():
            try:
                data = json.loads(settings_file.read_text(encoding="utf-8"))
            except Exception:
                data = {}
        data["view_mode"] = mode
        try:
            settings_file.parent.mkdir(parents=True, exist_ok=True)
            settings_file.write_text(json.dumps(data, indent=2), encoding="utf-8")
        except Exception as e:
            print(f"[Arcade] Error saving view mode: {e}")

    @Slot(str)
    def installGame(self, game_id: str):
        """Downloads and installs only the requested game from GitHub in the background."""
        def worker():
            import urllib.request
            import tarfile
            import io
            try:
                print(f"[Arcade] Downloading game: {game_id}...")
                url = "https://codeload.github.com/bigcjat/omarchyarcade/tar.gz/main"
                req = urllib.request.Request(url, headers={"User-Agent": "OmarchyArcade/1.0"})
                with urllib.request.urlopen(req, timeout=30) as resp:
                    tar_data = resp.read()

                with tarfile.open(fileobj=io.BytesIO(tar_data), mode="r:gz") as tar:
                    prefix = f"omarchyarcade-main/games/{game_id}/"
                    dest = GAMES_DIR / game_id
                    dest.mkdir(parents=True, exist_ok=True)
                    count = 0
                    for member in tar.getmembers():
                        if member.name.startswith(prefix) and member.name != prefix:
                            rel_path = member.name[len(prefix):]
                            target_file = dest / rel_path
                            if member.isdir():
                                target_file.mkdir(parents=True, exist_ok=True)
                            else:
                                target_file.parent.mkdir(parents=True, exist_ok=True)
                                extracted = tar.extractfile(member)
                                if extracted:
                                    with open(target_file, "wb") as f:
                                        f.write(extracted.read())
                                    count += 1

                # Record installed version stamp
                try:
                    cat_data = json.loads(self.getCatalogJson())
                    for g in cat_data.get("games", []):
                        if g.get("id") == game_id:
                            (dest / ".version").write_text(g.get("version", "1.0.0"), encoding="utf-8")
                            break
                except Exception:
                    pass

                print(f"[Arcade] Installed game: {game_id} ({count} files)")
                self.gameInstalled.emit(game_id)
            except Exception as e:
                print(f"[Arcade] Install failed for {game_id}: {e}")
                self.gameInstallFailed.emit(game_id, str(e))

        t = threading.Thread(target=worker, daemon=True)
        t.start()

    @Slot(str)
    def launchGame(self, game_id: str):
        """Spawns the requested game. If not yet installed, triggers download first."""
        game_dir = GAMES_DIR / game_id
        main_py = game_dir / "main.py"
        main_qml = game_dir / "main.qml"

        if not main_py.exists() and not main_qml.exists():
            print(f"[Arcade] Game not installed: {game_id}. Triggering on-demand download...")
            self.installGame(game_id)
            return

        cmd = []
        if main_py.exists():
            cmd = [sys.executable, str(main_py)]
        elif main_qml.exists():
            cmd = ["qml6", str(main_qml)]
        else:
            print(f"[Arcade] Error: No entrypoint in {game_dir}")
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


def ensure_launcher_assets():
    """Ensure all required launcher components exist locally, downloading any missing ones."""
    if (BASE_DIR / ".git").exists() and (BASE_DIR / "games").is_dir():
        return
    required_files = [
        "ViewCarousel.qml",
        "ViewDesktop.qml",
        "ViewSidebar.qml",
        "FloppyCard.qml",
        "GameDetailSheet.qml",
        "SplashScreen.qml",
        "omarchy_arcade_logo.svg",
        "omarchy_arcade_text.svg",
    ]
    import urllib.request
    for rf in required_files:
        dest = LAUNCHER_DIR / rf
        if not dest.exists():
            print(f"[Arcade] Missing launcher component {rf}, downloading from GitHub...")
            try:
                url = f"https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/launcher/{rf}"
                urllib.request.urlretrieve(url, str(dest))
                print(f"[Arcade] Successfully restored {rf}")
            except Exception as e:
                print(f"[Arcade] Error downloading {rf}: {e}")


def main():
    if "--help" in sys.argv or "-h" in sys.argv:
        print("""Omarchy Arcade • Desktop Game Suite Launcher
Usage:
  ./arcade              Launch the full arcade library with retro boot splash
  ./arcade --no-splash  Launch directly to the library view
  ./arcade --help       Show this help message
""")
        sys.exit(0)

    ensure_launcher_assets()
    QQuickStyle.setStyle("Basic")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Omarchy Arcade")
    app.setOrganizationName("Omarchy")

    # App icon from retro boot splash screen
    icon_candidates = [
        ASSETS_DIR / "splashscreen.png",
        LAUNCHER_DIR / "omarchy_arcade_logo.svg",
        ASSETS_DIR / "omarchy_arcade_logo.png",
        ASSETS_DIR / "omarchy_arcade_logo.svg",
        BASE_DIR / "template" / "omarchy_arcade.svg",
    ]
    for ic in icon_candidates:
        if ic.exists():
            app.setWindowIcon(QIcon(str(ic)))
            break

    backend = ArcadeBackend()
    engine = QQmlApplicationEngine()
    engine.addImportPath(str(LAUNCHER_DIR))
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

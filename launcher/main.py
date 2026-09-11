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

def get_user_data_dir() -> Path:
    """Returns platform-appropriate user data directory with zero external dependencies."""
    if sys.platform == "win32":
        local_app_data = os.environ.get("LOCALAPPDATA")
        if local_app_data:
            return Path(local_app_data) / "omarchy-arcade"
        return Path.home() / "AppData" / "Local" / "omarchy-arcade"
    return Path.home() / ".local" / "share" / "omarchy-arcade"

DATA_DIR = get_user_data_dir()

# If in source repository, use repository paths. Otherwise use installed user data directory
if (BASE_DIR / "games").is_dir():
    GAMES_DIR = BASE_DIR / "games"
    CATALOG_PATH = BASE_DIR / "catalog.json"
    ASSETS_DIR = BASE_DIR / "assets"
else:
    GAMES_DIR = DATA_DIR / "games"
    CATALOG_PATH = DATA_DIR / "catalog.json"
    ASSETS_DIR = DATA_DIR / "assets"

CURRENT_LAUNCHER_VERSION = "1.0.0"

GAMES_DIR.mkdir(parents=True, exist_ok=True)

class ArcadeBackend(QObject):
    """Backend services bridging the QML Launcher to local desktop execution."""
    gameLaunched = Signal(str)
    gameLaunchFailed = Signal(str, str)
    gameFinished = Signal(str)
    gameInstalled = Signal(str)
    gameInstallFailed = Signal(str, str)
    gameUninstalled = Signal(str)
    _processExited = Signal(str)
    themeChanged = Signal("QVariantMap")

    # In-App Update Center signals
    checkUpdatesStarted = Signal()
    updatesChecked = Signal("QVariantMap")
    launcherUpdateStarted = Signal()
    launcherUpdated = Signal(str)
    batchUpdateStarted = Signal(int)
    batchUpdateProgress = Signal(int, int, str)
    batchUpdateFinished = Signal()

    # Desktop Customization & Favorites signals
    favoritesChanged = Signal("QVariantList")
    wallpaperChanged = Signal(str)
    feltColorChanged = Signal(str)
    feltStyleChanged = Signal(str)

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
        """Fetches the game catalog dynamically from GitHub (or uses local repo file in dev mode)."""
        # In local repo development mode, always use local catalog.json
        if (BASE_DIR / "games").is_dir() and CATALOG_PATH.exists():
            try:
                return CATALOG_PATH.read_text(encoding="utf-8")
            except Exception as e:
                print(f"[Arcade] Error reading local dev catalog: {e}")

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
            local_path = DATA_DIR / "assets" / "covers" / f"{game_id}.png"
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
        if (game_dir / "main.py").exists() or (game_dir / "main.qml").exists():
            return True
        user_game_dir = DATA_DIR / "games" / game_id
        if (user_game_dir / "main.py").exists() or (user_game_dir / "main.qml").exists():
            return True
        return False

    @Slot(str, str, result=bool)
    def hasGameUpdate(self, game_id: str, catalog_version: str) -> bool:
        """Checks if an installed game has an update available compared to catalog.json."""
        if not game_id or not catalog_version:
            return False
        game_dir = GAMES_DIR / game_id
        if not (game_dir / "main.py").exists() and not (game_dir / "main.qml").exists():
            user_dir = DATA_DIR / "games" / game_id
            if not (user_dir / "main.py").exists() and not (user_dir / "main.qml").exists():
                return False
            game_dir = user_dir
        version_file = game_dir / ".version"
        if not version_file.exists():
            if (BASE_DIR / ".git").is_dir():
                return False
            return True  # Installed prior to version stamping -> outdated!
        try:
            installed_v = version_file.read_text(encoding="utf-8").strip()
            return installed_v != str(catalog_version).strip()
        except Exception:
            return True

    @Slot(str, result=str)
    def getScreenshotUrl(self, folder: str) -> str:
        """Returns the remote URL to stream preview WebP on demand (or local preview WebP if present)."""
        if not folder:
            return ""
        game_id = Path(folder).name
        # 1. Local preview WebP check (e.g. dev clone)
        for base in [BASE_DIR, DATA_DIR]:
            preview_path = base / "assets" / "previews" / f"{game_id}.webp"
            if preview_path.exists():
                return QUrl.fromLocalFile(str(preview_path)).toString()

        # 2. Stream remote preview WebP on demand from GitHub raw
        return f"https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/assets/previews/{game_id}.webp"

    @Slot(str, result=str)
    def getFallbackScreenshotUrl(self, folder: str) -> str:
        """Fallback to local static screenshot.png when offline or if remote fetch fails."""
        if not folder:
            return ""
        for base in [BASE_DIR, DATA_DIR]:
            local_path = base / folder / "screenshot.png"
            if local_path.exists():
                return QUrl.fromLocalFile(str(local_path)).toString()
        return ""

    @Slot(str, result=str)
    def getDiskIconUrl(self, game_id: str) -> str:
        """Returns the file URL for a game's 3.5" disk icon."""
        if not game_id:
            return ""
        local_path = GAMES_DIR / game_id / "assets" / "disk_icon.png"
        if not local_path.exists():
            local_path = BASE_DIR / "games" / game_id / "assets" / "disk_icon.png"
        if not local_path.exists():
            local_path = DATA_DIR / "games" / game_id / "assets" / "disk_icon.png"
        if local_path.exists():
            return QUrl.fromLocalFile(str(local_path)).toString()
        return self.getCoverUrl(game_id)

    def _get_settings_path(self) -> Path:
        if (BASE_DIR / ".git").exists():
            return LAUNCHER_DIR / ".launcher_settings.json"
        if sys.platform == "win32":
            return DATA_DIR / "arcade_settings.json"
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

    @Slot(result="QVariantList")
    def getFavorites(self) -> list:
        """Returns the list of game IDs marked as favorite."""
        settings_file = self._get_settings_path()
        if settings_file.exists():
            try:
                data = json.loads(settings_file.read_text(encoding="utf-8"))
                favs = data.get("favorites", [])
                if isinstance(favs, list):
                    return favs
            except Exception:
                pass
        return []

    @Slot(str, result=bool)
    def isFavorite(self, game_id: str) -> bool:
        """Returns True if the given game_id is in favorites."""
        return game_id in self.getFavorites()

    @Slot(str, result=bool)
    def toggleFavorite(self, game_id: str) -> bool:
        """Toggles the favorite status for game_id and emits favoritesChanged."""
        if not game_id:
            return False
        settings_file = self._get_settings_path()
        data = {}
        if settings_file.exists():
            try:
                data = json.loads(settings_file.read_text(encoding="utf-8"))
            except Exception:
                data = {}
        favs = data.get("favorites", [])
        if not isinstance(favs, list):
            favs = []
        is_fav = False
        if game_id in favs:
            favs.remove(game_id)
            is_fav = False
        else:
            favs.append(game_id)
            is_fav = True
        data["favorites"] = favs
        try:
            settings_file.parent.mkdir(parents=True, exist_ok=True)
            settings_file.write_text(json.dumps(data, indent=2), encoding="utf-8")
        except Exception as e:
            print(f"[Arcade] Error saving favorites: {e}")
        self.favoritesChanged.emit(favs)
        return is_fav

    @Slot(result=str)
    def getDesktopWallpaper(self) -> str:
        """Returns the saved desktop wallpaper theme ID ('teal', 'matrix', 'cyber', 'sunset', 'starfield', 'blue')."""
        settings_file = self._get_settings_path()
        if settings_file.exists():
            try:
                data = json.loads(settings_file.read_text(encoding="utf-8"))
                return data.get("desktop_wallpaper", "matrix")
            except Exception:
                pass
        return "matrix"

    @Slot(str)
    def setDesktopWallpaper(self, wallpaper: str):
        """Persists the desktop wallpaper theme."""
        settings_file = self._get_settings_path()
        data = {}
        if settings_file.exists():
            try:
                data = json.loads(settings_file.read_text(encoding="utf-8"))
            except Exception:
                data = {}
        data["desktop_wallpaper"] = wallpaper
        try:
            settings_file.parent.mkdir(parents=True, exist_ok=True)
            settings_file.write_text(json.dumps(data, indent=2), encoding="utf-8")
        except Exception as e:
            print(f"[Arcade] Error saving wallpaper: {e}")
        self.wallpaperChanged.emit(wallpaper)

    @Slot(result=str)
    def getFeltColor(self) -> str:
        """Returns the saved poker felt wallpaper color (defaults to '#0a5c36' Casino Green)."""
        settings_file = self._get_settings_path()
        if settings_file.exists():
            try:
                data = json.loads(settings_file.read_text(encoding="utf-8"))
                return data.get("poker_felt_color", "#0a5c36")
            except Exception:
                pass
        return "#0a5c36"

    @Slot(str)
    def setFeltColor(self, color: str):
        """Persists the poker felt wallpaper color."""
        settings_file = self._get_settings_path()
        data = {}
        if settings_file.exists():
            try:
                data = json.loads(settings_file.read_text(encoding="utf-8"))
            except Exception:
                data = {}
        data["poker_felt_color"] = color
        try:
            settings_file.parent.mkdir(parents=True, exist_ok=True)
            settings_file.write_text(json.dumps(data, indent=2), encoding="utf-8")
        except Exception as e:
            print(f"[Arcade] Error saving felt color: {e}")
        self.feltColorChanged.emit(color)

    @Slot(result=str)
    def getFeltStyle(self) -> str:
        """Returns the poker felt pattern style ('suited' or 'monogram', defaults to 'suited')."""
        settings_file = self._get_settings_path()
        if settings_file.exists():
            try:
                data = json.loads(settings_file.read_text(encoding="utf-8"))
                return data.get("poker_felt_style", "suited")
            except Exception:
                pass
        return "suited"

    @Slot(str)
    def setFeltStyle(self, style: str):
        """Persists the poker felt pattern style ('suited' or 'monogram')."""
        settings_file = self._get_settings_path()
        data = {}
        if settings_file.exists():
            try:
                data = json.loads(settings_file.read_text(encoding="utf-8"))
            except Exception:
                data = {}
        data["poker_felt_style"] = style
        try:
            settings_file.parent.mkdir(parents=True, exist_ok=True)
            settings_file.write_text(json.dumps(data, indent=2), encoding="utf-8")
        except Exception as e:
            print(f"[Arcade] Error saving felt style: {e}")
        self.feltStyleChanged.emit(style)

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
    def uninstallGame(self, game_id: str):
        """Uninstalls/removes local game files for the specified game."""
        import shutil
        print(f"[Arcade] Uninstalling game: {game_id}...")

        # 1. Check data dir (<DATA_DIR>/games/<game_id>)
        data_game_dir = DATA_DIR / "games" / game_id
        if data_game_dir.exists():
            try:
                shutil.rmtree(data_game_dir, ignore_errors=True)
                print(f"[Arcade] Removed from data games dir: {data_game_dir}")
            except Exception as e:
                print(f"[Arcade] Error removing {data_game_dir}: {e}")

        # 2. Check GAMES_DIR
        target_dir = GAMES_DIR / game_id
        if target_dir.exists():
            try:
                # If running in development repository, preserve a backup in trash
                # so developer files are never permanently destroyed
                trash_dir = DATA_DIR / "trash" / game_id
                trash_dir.parent.mkdir(parents=True, exist_ok=True)
                if trash_dir.exists():
                    shutil.rmtree(trash_dir, ignore_errors=True)
                shutil.move(str(target_dir), str(trash_dir))
                print(f"[Arcade] Moved {target_dir} to backup trash: {trash_dir}")
            except Exception as e:
                try:
                    shutil.rmtree(target_dir, ignore_errors=True)
                    print(f"[Arcade] Removed from games dir: {target_dir}")
                except Exception as err:
                    print(f"[Arcade] Error removing {target_dir}: {err}")

        self.gameUninstalled.emit(game_id)

    @Slot(str)
    def launchGame(self, game_id: str):
        """Spawns the requested game if installed."""
        game_dir = GAMES_DIR / game_id
        main_py = game_dir / "main.py"
        main_qml = game_dir / "main.qml"

        if not main_py.exists() and not main_qml.exists():
            user_game_dir = DATA_DIR / "games" / game_id
            if (user_game_dir / "main.py").exists() or (user_game_dir / "main.qml").exists():
                game_dir = user_game_dir
                main_py = game_dir / "main.py"
                main_qml = game_dir / "main.qml"
            else:
                print(f"[Arcade] Refusing to launch uninstalled game without consent: {game_id}")
                self.gameLaunchFailed.emit(game_id, "Game is not installed.")
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
            theme_path = find_omarchy_colors_file()
            env = os.environ.copy()
            if theme_path and theme_path.is_file():
                env["OMARCHY_THEME_FILE"] = str(theme_path)

            popen_kwargs = {
                "cwd": str(game_dir),
                "env": env,
            }
            if sys.platform == "win32":
                popen_kwargs["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
            else:
                popen_kwargs["start_new_session"] = True

            print(f"[Arcade] Launching game: {game_id} via {cmd}")
            proc = subprocess.Popen(
                cmd,
                **popen_kwargs
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

    @Slot(result=str)
    def getLauncherVersion(self) -> str:
        """Returns the current launcher version."""
        for v_path in [
            LAUNCHER_DIR / ".launcher_version",
            DATA_DIR / "launcher" / ".launcher_version",
            DATA_DIR / ".launcher_version"
        ]:
            if v_path.exists():
                try:
                    return v_path.read_text(encoding="utf-8").strip()
                except Exception:
                    pass
        return CURRENT_LAUNCHER_VERSION

    @Slot(result="QVariantMap")
    def checkForUpdates(self) -> dict:
        """Fetches latest catalog.json and returns a full report of available launcher and game updates."""
        import urllib.request
        import time
        remote_url = f"https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/catalog.json?_={int(time.time())}"
        cat_data = {}
        try:
            req = urllib.request.Request(
                remote_url,
                headers={"User-Agent": "OmarchyArcade/1.0", "Cache-Control": "no-cache", "Pragma": "no-cache"}
            )
            with urllib.request.urlopen(req, timeout=6) as resp:
                cat_data = json.loads(resp.read().decode("utf-8"))
        except Exception as e:
            print(f"[Arcade] checkForUpdates remote fetch notice: {e}, reading local catalog...")
            if CATALOG_PATH.exists():
                try:
                    cat_data = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
                except Exception:
                    cat_data = {}

        current_lv = self.getLauncherVersion()
        remote_lv = str(cat_data.get("launcher_version", current_lv)).strip()
        launcher_has_update = (remote_lv != current_lv and remote_lv != "")
        launcher_changelog = cat_data.get("launcher_changelog", [
            "Performance and stability enhancements",
            "Updated game catalog entries"
        ])

        outdated_games = []
        for g in cat_data.get("games", []):
            gid = g.get("id")
            gver = g.get("version", "")
            if not gid or not gver:
                continue
            if self.isGameInstalled(gid) and self.hasGameUpdate(gid, gver):
                # Resolve current installed version
                inst_ver = "1.0.0"
                for cand in [GAMES_DIR / gid / ".version", DATA_DIR / "games" / gid / ".version"]:
                    if cand.exists():
                        try:
                            inst_ver = cand.read_text(encoding="utf-8").strip()
                            break
                        except Exception:
                            pass

                outdated_games.append({
                    "id": gid,
                    "title": g.get("title", gid),
                    "current_version": inst_ver,
                    "new_version": gver,
                    "changelog": g.get("changelog", ["General improvements and gameplay polish"]),
                    "size": g.get("size", ""),
                    "category": g.get("category", "")
                })

        report = {
            "launcher": {
                "has_update": launcher_has_update,
                "current_version": current_lv,
                "new_version": remote_lv,
                "changelog": launcher_changelog
            },
            "games": outdated_games,
            "total_updates_count": (1 if launcher_has_update else 0) + len(outdated_games)
        }
        self.updatesChecked.emit(report)
        return report

    @Slot()
    def checkForUpdatesAsync(self):
        """Asynchronously checks for updates in a background worker thread."""
        import threading
        self.checkUpdatesStarted.emit()

        def worker():
            import time
            time.sleep(0.3)  # Brief breathing time so UI transition is cleanly visible
            self.checkForUpdates()

        threading.Thread(target=worker, daemon=True).start()

    @Slot()
    def updateLauncher(self):
        """Downloads updated launcher payload from GitHub in the background."""
        def worker():
            import urllib.request
            import tarfile
            import io
            self.launcherUpdateStarted.emit()
            try:
                print("[Arcade] Downloading launcher update from GitHub...")
                url = "https://codeload.github.com/bigcjat/omarchyarcade/tar.gz/main"
                req = urllib.request.Request(url, headers={"User-Agent": "OmarchyArcade/1.0"})
                with urllib.request.urlopen(req, timeout=30) as resp:
                    tar_data = resp.read()

                dest_dir = DATA_DIR / "launcher"
                if (BASE_DIR / ".git").is_dir() and (BASE_DIR / "launcher").is_dir():
                    dest_dir = BASE_DIR / "launcher"
                dest_dir.mkdir(parents=True, exist_ok=True)

                prefix = "omarchyarcade-main/launcher/"
                count = 0
                with tarfile.open(fileobj=io.BytesIO(tar_data), mode="r:gz") as tar:
                    for member in tar.getmembers():
                        if member.name.startswith(prefix) and member.name != prefix:
                            rel = member.name[len(prefix):]
                            t_file = dest_dir / rel
                            if member.isdir():
                                t_file.mkdir(parents=True, exist_ok=True)
                            else:
                                t_file.parent.mkdir(parents=True, exist_ok=True)
                                ext = tar.extractfile(member)
                                if ext:
                                    with open(t_file, "wb") as f:
                                        f.write(ext.read())
                                    count += 1
                        elif member.name == "omarchyarcade-main/catalog.json":
                            ext = tar.extractfile(member)
                            if ext:
                                cat_dest = dest_dir.parent / "catalog.json" if dest_dir.name == "launcher" else BASE_DIR / "catalog.json"
                                with open(cat_dest, "wb") as f:
                                    f.write(ext.read())

                # Resolve new version
                new_v = "1.1.0"
                try:
                    cat_f = dest_dir.parent / "catalog.json" if dest_dir.name == "launcher" else BASE_DIR / "catalog.json"
                    if cat_f.exists():
                        cat_j = json.loads(cat_f.read_text(encoding="utf-8"))
                        new_v = cat_j.get("launcher_version", new_v)
                except Exception:
                    pass

                (dest_dir / ".launcher_version").write_text(new_v, encoding="utf-8")
                print(f"[Arcade] Launcher update complete: v{new_v} ({count} files)")
                self.launcherUpdated.emit(new_v)
            except Exception as e:
                print(f"[Arcade] Launcher update error: {e}")
                self.launcherUpdateFailed.emit(str(e))

        t = threading.Thread(target=worker, daemon=True)
        t.start()

    @Slot()
    def updateAllGames(self):
        """Batch downloads and applies all available game updates and launcher updates."""
        def worker():
            import urllib.request
            import tarfile
            import io
            report = self.checkForUpdates()
            games_to_update = report.get("games", [])
            launcher_needs_update = report.get("launcher", {}).get("has_update", False)
            total = len(games_to_update) + (1 if launcher_needs_update else 0)

            if total == 0:
                self.batchUpdateFinished.emit()
                return

            self.batchUpdateStarted.emit(total)

            try:
                print("[Arcade] Fetching single archive payload for batch updates...")
                url = "https://codeload.github.com/bigcjat/omarchyarcade/tar.gz/main"
                req = urllib.request.Request(url, headers={"User-Agent": "OmarchyArcade/1.0"})
                with urllib.request.urlopen(req, timeout=45) as resp:
                    tar_data = resp.read()

                with tarfile.open(fileobj=io.BytesIO(tar_data), mode="r:gz") as tar:
                    step = 0
                    # 1. Update each game
                    for g in games_to_update:
                        step += 1
                        gid = g["id"]
                        gtitle = g["title"]
                        self.batchUpdateProgress.emit(step, total, f"Updating {gtitle} ({step}/{total})...")

                        prefix = f"omarchyarcade-main/games/{gid}/"
                        dest = GAMES_DIR / gid
                        dest.mkdir(parents=True, exist_ok=True)

                        for member in tar.getmembers():
                            if member.name.startswith(prefix) and member.name != prefix:
                                rel = member.name[len(prefix):]
                                target_f = dest / rel
                                if member.isdir():
                                    target_f.mkdir(parents=True, exist_ok=True)
                                else:
                                    target_f.parent.mkdir(parents=True, exist_ok=True)
                                    ext = tar.extractfile(member)
                                    if ext:
                                        with open(target_f, "wb") as f:
                                            f.write(ext.read())

                        (dest / ".version").write_text(g["new_version"], encoding="utf-8")
                        self.gameInstalled.emit(gid)

                    # 2. Update launcher if needed
                    if launcher_needs_update:
                        step += 1
                        self.batchUpdateProgress.emit(step, total, f"Updating Omarchy Arcade UI ({step}/{total})...")
                        dest_dir = DATA_DIR / "launcher"
                        if (BASE_DIR / ".git").is_dir() and (BASE_DIR / "launcher").is_dir():
                            dest_dir = BASE_DIR / "launcher"
                        dest_dir.mkdir(parents=True, exist_ok=True)

                        prefix = "omarchyarcade-main/launcher/"
                        for member in tar.getmembers():
                            if member.name.startswith(prefix) and member.name != prefix:
                                rel = member.name[len(prefix):]
                                t_file = dest_dir / rel
                                if member.isdir():
                                    t_file.mkdir(parents=True, exist_ok=True)
                                else:
                                    t_file.parent.mkdir(parents=True, exist_ok=True)
                                    ext = tar.extractfile(member)
                                    if ext:
                                        with open(t_file, "wb") as f:
                                            f.write(ext.read())
                            elif member.name == "omarchyarcade-main/catalog.json":
                                ext = tar.extractfile(member)
                                if ext:
                                    cat_dest = dest_dir.parent / "catalog.json" if dest_dir.name == "launcher" else BASE_DIR / "catalog.json"
                                    with open(cat_dest, "wb") as f:
                                        f.write(ext.read())

                        new_lv = report["launcher"]["new_version"]
                        (dest_dir / ".launcher_version").write_text(new_lv, encoding="utf-8")
                        self.launcherUpdated.emit(new_lv)

                print("[Arcade] Batch update finished successfully!")
                self.batchUpdateFinished.emit()

            except Exception as e:
                print(f"[Arcade] Batch update error: {e}")
                self.batchUpdateFinished.emit()

        t = threading.Thread(target=worker, daemon=True)
        t.start()


def find_omarchy_colors_file():
    env_path = os.environ.get("OMARCHY_THEME_FILE")
    if env_path and Path(env_path).is_file():
        return Path(env_path)

    if sys.platform == "win32":
        return None

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
                c = data.get("colors") if isinstance(data.get("colors"), dict) else data

                bg = c.get("background") or c.get("bg")
                fg = c.get("foreground") or c.get("fg") or c.get("text")
                accent = c.get("accent") or c.get("primary") or c.get("color4")
                accent_alt = c.get("accent_alt") or c.get("color5") or c.get("color1") or c.get("color3")
                muted = c.get("muted") or c.get("text_muted") or c.get("color8") or c.get("subtext")
                border = c.get("border") or c.get("color8") or c.get("selection")

                if bg:
                    colors["themeBackground"] = bg
                    try:
                        from PySide6.QtGui import QColor
                        qc = QColor(bg)
                        lum = 0.299 * qc.redF() + 0.587 * qc.greenF() + 0.114 * qc.blueF()
                        if lum < 0.5:
                            colors["themeSurface"] = qc.lighter(115).name()
                            colors["themeSurfaceLight"] = qc.lighter(130).name()
                            if not border:
                                colors["themeBorder"] = qc.lighter(145).name()
                        else:
                            colors["themeSurface"] = qc.darker(108).name()
                            colors["themeSurfaceLight"] = qc.darker(118).name()
                            if not border:
                                colors["themeBorder"] = qc.darker(125).name()
                    except Exception:
                        pass

                if fg:
                    colors["themeText"] = fg
                    if not muted:
                        try:
                            from PySide6.QtGui import QColor
                            qc_fg = QColor(fg)
                            colors["themeTextMuted"] = qc_fg.darker(135).name()
                        except Exception:
                            pass

                if accent:
                    colors["themeAccent"] = accent
                if accent_alt:
                    colors["themeAccentAlt"] = accent_alt
                if muted:
                    colors["themeTextMuted"] = muted
                if border:
                    colors["themeBorder"] = border
                if "surface" in c:
                    colors["themeSurface"] = c["surface"]
                if "surface_light" in c:
                    colors["themeSurfaceLight"] = c["surface_light"]

        except Exception as e:
            print(f"[Arcade] Notice: Could not read theme colors: {e}")

    return colors


def ensure_launcher_assets():
    """Ensure all required launcher components exist locally, downloading any missing ones."""
    if (BASE_DIR / ".git").exists() and (BASE_DIR / "games").is_dir():
        return
    required_files = [
        "ViewFeatured.qml",
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

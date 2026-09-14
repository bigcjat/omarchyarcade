#!/usr/bin/env python3
"""
Omarchy Arcade • Master Game Template Launcher
Cross-platform PySide6 host supporting Omarchy Linux, macOS, and standard Linux/Windows desktops.

Features:
- Native Omarchy Desktop theme hot-reloading (~/.config/omarchy/current/theme/colors.toml)
- Native OS theme synchronization (detects macOS/system Dark vs Light mode via QStyleHints)
- CoreAudio low-latency sound synthesis on macOS (0ms delay) + PipeWire/PulseAudio on Linux
- QSettings persistent score/save state management
- Canonical splashscreen and responsive 2048 layout integration
- CLI tools: --theme, --list-themes, --no-splash, --screenshot, --screenshot-help
"""

import os
import sys
import re
import shutil
import subprocess
import tomllib
import ctypes
import threading
from pathlib import Path
from PySide6.QtGui import QIcon, QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QFileSystemWatcher, QTimer, QObject, Slot, Signal, QSettings, Qt

from ai_engine import find_best_move

# =============================================================================
# CHESS AI BACKEND BRIDGE
# =============================================================================
class ChessBackend(QObject):
    """
    Asynchronous bridge between QML frontend and self-contained AI engine.
    Runs searches on a background thread so UI animations remain 60 FPS.
    """
    aiMoveReady = Signal(str, str, str)  # from_square, to_square, promotion
    thinkingChanged = Signal(bool)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._thinking = False

    @Slot(str, str)
    def requestAiMove(self, fen, difficulty="casual"):
        if self._thinking:
            return
        self._thinking = True
        self.thinkingChanged.emit(True)

        def worker():
            try:
                uci = find_best_move(fen, difficulty)
                if uci and len(uci) >= 4:
                    from_sq = uci[:2]
                    to_sq = uci[2:4]
                    promo = uci[4:] if len(uci) > 4 else ""
                    self.aiMoveReady.emit(from_sq, to_sq, promo)
                else:
                    self.aiMoveReady.emit("", "", "")
            except Exception as e:
                print(f"Chess AI Engine Error: {e}", file=sys.stderr)
                self.aiMoveReady.emit("", "", "")
            finally:
                self._thinking = False
                self.thinkingChanged.emit(False)

        thread = threading.Thread(target=worker, daemon=True)
        thread.start()

    @Slot(result=bool)
    def isThinking(self):
        return self._thinking

# =============================================================================
# PERSISTENT SETTINGS MANAGER
# =============================================================================
class SettingsManager(QObject):
    """Provides local persistence via QSettings."""
    def __init__(self, game_id="GameTemplate", parent=None):
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
# NATIVE SOUND MANAGER
# =============================================================================
class SoundManager(QObject):
    """
    Ultra-low-latency sound dispatcher.
    Uses native CoreAudio AudioServices on macOS (preloaded system sound IDs).
    Falls back to PipeWire (pw-play), PulseAudio (paplay), or ALSA (aplay) on Linux.
    """
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

                if self.sounds_dir.is_dir():
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
    def play(self, name):
        self.playSound(name)

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

# =============================================================================
# =============================================================================
# THEME UTILITIES
# =============================================================================
DEFAULT_PRESETS = {
    "dark": {
        "name": "Omarchy Dark",
        "background": "#0B0E14",
        "foreground": "#DCE6F5",
        "accent": "#00F0FF",
        "color0": "#171D2A",
        "color8": "#232D42",
        "card_bg": "#171D2A",
        "card_hover": "#232D42",
        "boardBg": "#10141D",
        "border": "#232D42",
        "subtext": "#7B8EA8",
    },
    "light": {
        "name": "Omarchy Light",
        "background": "#f8fafc",
        "foreground": "#0f172a",
        "accent": "#0284c7",
        "color0": "#f1f5f9",
        "color8": "#cbd5e1",
        "card_bg": "#ffffff",
        "card_hover": "#f1f5f9",
        "boardBg": "#0f172a",
        "border": "#cbd5e1",
        "subtext": "#64748b",
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

    if "--help" in sys.argv or "-h" in sys.argv:
        print("Chess • AI Powered Chess")
        sys.exit(0)

    if "--list-themes" in sys.argv:
        print("Arcade Game Template • Preset Themes:\n  --theme light\n  --theme dark\n  --theme <path_to_colors.toml>")
        sys.exit(0)

    app = QGuiApplication(sys.argv)
    app.setApplicationName("Chess")
    app.setOrganizationName("Arcade")
    # Set application icon to game floppy disk
    script_dir = Path(__file__).resolve().parent
    disk_candidates = [
        script_dir / "assets" / "disk_icon.png",
        script_dir.parent.parent / "assets" / "covers" / "chess_disk.png",
        Path.home() / ".local" / "share" / "omarchy-arcade" / "assets" / "covers" / "chess_disk.png",
    ]
    for cp in disk_candidates:
        if cp.exists():
            app.setWindowIcon(QIcon(str(cp)))
            break

    engine = QQmlApplicationEngine()

    chess_backend = ChessBackend()
    engine.rootContext().setContextProperty("chessBackend", chess_backend)

    sound_mgr = SoundManager(Path(__file__).resolve().parent / "sounds")
    engine.rootContext().setContextProperty("soundManager", sound_mgr)

    settings_mgr = SettingsManager("Chess")
    engine.rootContext().setContextProperty("settingsManager", settings_mgr)

    qml_file = Path(__file__).resolve().parent / "main.qml"
    engine.load(str(qml_file))

    if not engine.rootObjects():
        print("Error: Failed to load QML root object.", file=sys.stderr)
        sys.exit(1)

    root_obj = engine.rootObjects()[0]

    # CLI Theme Argument Parsing
    theme_arg = None
    if "--theme" in sys.argv:
        idx = sys.argv.index("--theme")
        if idx + 1 < len(sys.argv):
            theme_arg = sys.argv[idx + 1]

    # 1. Explicit Theme CLI Override
    if theme_arg:
        clean_arg = theme_arg.lower().strip()
        if clean_arg in DEFAULT_PRESETS:
            preset = DEFAULT_PRESETS[clean_arg]
            root_obj.applyTheme(preset, preset["name"])
            print(f"Applied preset theme: {preset['name']}")
        else:
            custom_path = Path(theme_arg).expanduser().resolve()
            if custom_path.is_file():
                data = load_toml_colors(custom_path)
                if data:
                    root_obj.applyTheme(data, custom_path.parent.name.capitalize())
                    print(f"Applied theme from file: {custom_path}")
            else:
                print(f"Warning: Theme '{theme_arg}' not found. Using default preset.", file=sys.stderr)
                preset = DEFAULT_PRESETS["dark"]
                root_obj.applyTheme(preset, preset["name"])

    # 2. Omarchy Desktop System Theme Detection & Hot-Reloading
    else:
        system_colors = find_omarchy_colors_file()
        if system_colors:
            data = load_toml_colors(system_colors)
            if data:
                theme_name = system_colors.parent.name.capitalize()
                root_obj.applyTheme(data, theme_name)
                print(f"Detected Omarchy theme: {theme_name} ({system_colors})")

            # Watch for real-time desktop theme switches
            watcher = QFileSystemWatcher(app)
            watcher.addPath(str(system_colors))
            if system_colors.parent.exists():
                watcher.addPath(str(system_colors.parent))

            def on_theme_updated(path):
                colors_path = find_omarchy_colors_file()
                if colors_path and colors_path.is_file():
                    updated = load_toml_colors(colors_path)
                    if updated:
                        root_obj.applyTheme(updated, colors_path.parent.name.capitalize())
                        print(f"Omarchy theme reloaded: {colors_path.parent.name}")

            watcher.fileChanged.connect(on_theme_updated)
            watcher.directoryChanged.connect(on_theme_updated)

        # 3. macOS / System Dark & Light Mode Synchronization
        else:
            def apply_system_scheme():
                hints = app.styleHints()
                scheme = hints.colorScheme() if hasattr(hints, "colorScheme") else Qt.ColorScheme.Dark
                if scheme == Qt.ColorScheme.Light:
                    target_preset = DEFAULT_PRESETS["light"]
                    name = "System Light"
                else:
                    target_preset = DEFAULT_PRESETS["dark"]
                    name = "System Dark"

                root_obj.applyTheme(target_preset, name)
                print(f"Detected OS appearance: {name} ({target_preset.get('name')})")

            apply_system_scheme()
            if hasattr(app.styleHints(), "colorSchemeChanged"):
                app.styleHints().colorSchemeChanged.connect(lambda _: apply_system_scheme())

    if "--no-splash" in sys.argv:
        root_obj.setProperty("splashEnabled", False)

    # Screenshot / automation helpers
    if "--screenshot" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        def capture():
            out_idx = sys.argv.index("--screenshot") + 1
            out_file = sys.argv[out_idx] if out_idx < len(sys.argv) and not sys.argv[out_idx].startswith("--") else "screenshot.png"
            out_path = Path(out_file).resolve()
            root_obj.captureScreenshot(str(out_path), False)
            QTimer.singleShot(400, app.quit)
        QTimer.singleShot(350, capture)

    if "--screenshot-help" in sys.argv:
        root_obj.setProperty("splashEnabled", False)
        def capture_help():
            root_obj.setProperty("showHelp", True)
            out_path = Path(__file__).resolve().parent / "screenshot_help.png"
            root_obj.captureScreenshot(str(out_path), False)
            QTimer.singleShot(400, app.quit)
        QTimer.singleShot(350, capture_help)

    if "--screenshot-splash" in sys.argv:
        def capture_splash():
            out_path = Path(__file__).resolve().parent / "screenshot_splash.png"
            root_obj.captureScreenshot(str(out_path), False)
            QTimer.singleShot(400, app.quit)
        QTimer.singleShot(600, capture_splash)

    print("Arcade game template running. Press Esc or ? for help, R to restart.")
    sys.exit(app.exec())

if __name__ == "__main__":
    main()

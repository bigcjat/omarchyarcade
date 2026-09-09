#!/usr/bin/env python3
"""
Omarchy Arcade • OmarchyBolo II (OA-029)
Classic Tactical Tank Warfare & P2P WebRTC Battle Arena

Universal host supporting:
- Native compiled Tauri binaries (if present in bin/)
- Zero-bloat standalone web app window (Chromium/Brave/Chrome --app mode or WebKit)
- Local ephemeral zero-dependency HTTP server (pure standard library)
- Full Omarchy Arcade launcher lifecycle integration
"""

import os
import sys
import time
import socket
import signal
import shutil
import argparse
import threading
import subprocess
import webbrowser
from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler

BASE_DIR = Path(__file__).resolve().parent
DIST_DIR = BASE_DIR / "dist"
BIN_DIR = BASE_DIR / "bin"
ASSETS_DIR = BASE_DIR / "assets"
DISK_ICON = ASSETS_DIR / "disk_icon.png"

APP_TITLE = "OmarchyBolo II"
APP_REF = "OA-029"
APP_VERSION = "1.0.4"

class QuietHandler(SimpleHTTPRequestHandler):
    """Quiet handler that serves files from DIST_DIR with explicit CORS and MIME types."""
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".css": "text/css; charset=utf-8",
        ".js": "text/javascript; charset=utf-8",
        ".mjs": "text/javascript; charset=utf-8",
        ".html": "text/html; charset=utf-8",
        ".json": "application/json",
        ".png": "image/png",
        ".svg": "image/svg+xml",
        ".woff2": "font/woff2",
        ".wasm": "application/wasm",
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DIST_DIR), **kwargs)

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        super().end_headers()

    def log_message(self, format, *args):
        # Suppress standard HTTP request logging
        pass

def find_free_port():
    """Finds an available ephemeral port on localhost."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]

def get_native_binary():
    """Checks for precompiled native Tauri or Rust binaries in bin/."""
    candidates = [
        BIN_DIR / "omarchybolo",
        BIN_DIR / "bolo",
        BIN_DIR / "omarchybolo2",
        BIN_DIR / "OmarchyBolo.app" / "Contents" / "MacOS" / "OmarchyBolo",
        BIN_DIR / "Bolo.app" / "Contents" / "MacOS" / "Bolo",
    ]
    for c in candidates:
        if c.exists() and os.access(c, os.X_OK):
            return c
    return None

def find_app_browser():
    """Finds a browser executable capable of running in chromeless --app window mode."""
    # On Linux (Omarchy / Hyprland / Arch)
    linux_candidates = [
        "chromium",
        "brave",
        "brave-browser",
        "google-chrome-stable",
        "google-chrome",
        "chromium-browser",
        "microsoft-edge",
    ]
    for name in linux_candidates:
        p = shutil.which(name)
        if p:
            return p

    # On macOS
    mac_candidates = [
        Path("/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"),
        Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"),
        Path("/Applications/Chromium.app/Contents/MacOS/Chromium"),
        Path("/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"),
    ]
    for p in mac_candidates:
        if p.exists() and os.access(p, os.X_OK):
            return str(p)

    return None

def run_native_binary(binary_path, args):
    """Executes precompiled native binary and blocks until completion."""
    print(f"[{APP_TITLE}] Spawning native binary: {binary_path}")
    try:
        proc = subprocess.Popen([str(binary_path)] + args, cwd=str(BASE_DIR))
        return proc.wait()
    except Exception as e:
        print(f"[{APP_TITLE}] Error executing native binary: {e}", file=sys.stderr)
        return 1

def run_web_app():
    """Runs local HTTP server and launches standalone game window."""
    if not DIST_DIR.is_dir() or not (DIST_DIR / "index.html").is_file():
        print(f"[{APP_TITLE}] Error: Web distribution not found at {DIST_DIR}", file=sys.stderr)
        return 1

    port = find_free_port()
    server = ThreadingHTTPServer(("127.0.0.1", port), QuietHandler)
    server_thread = threading.Thread(target=server.serve_forever, daemon=True)
    server_thread.start()

    url = f"http://127.0.0.1:{port}/index.html"
    print(f"[{APP_TITLE}] Running tactical simulation server at {url}")

    browser_bin = find_app_browser()
    proc = None

    if browser_bin:
        # Launch dedicated chromeless desktop application window
        app_args = [
            browser_bin,
            f"--app={url}",
            "--window-size=1280,820",
            "--window-position=center",
            f"--app-id=omarchyarcade.{APP_REF.lower()}",
            "--user-data-dir=/tmp/omarchy_bolo_chrome_profile",
        ]
        # On Linux allow slight sandbox optimizations if needed
        if sys.platform.startswith("linux"):
            app_args.append("--class=OmarchyBolo")

        try:
            print(f"[{APP_TITLE}] Launching dedicated standalone app window via {browser_bin}")
            proc = subprocess.Popen(app_args, cwd=str(BASE_DIR))
        except Exception as e:
            print(f"[{APP_TITLE}] Could not launch browser app mode: {e}")
            proc = None

    if proc is None:
        print(f"[{APP_TITLE}] Opening default desktop browser: {url}")
        webbrowser.open(url)

    # Wait for the child window process or signal
    stop_event = threading.Event()

    def handle_signal(sig, frame):
        stop_event.set()

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    try:
        if proc:
            while proc.poll() is None and not stop_event.is_set():
                time.sleep(0.2)
        else:
            print(f"[{APP_TITLE}] Press Ctrl+C to stop simulation and return to launcher.")
            while not stop_event.is_set():
                time.sleep(0.5)
    except KeyboardInterrupt:
        pass
    finally:
        if proc and proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=1.0)
            except subprocess.TimeoutExpired:
                proc.kill()
        server.shutdown()
        server.server_close()
        print(f"[{APP_TITLE}] Clean exit. Returning to Omarchy Arcade launcher.")

    return 0

def main():
    parser = argparse.ArgumentParser(
        prog="omarchybolo",
        description=f"Omarchy Arcade • {APP_TITLE} ({APP_REF})\nClassic Tactical Tank Warfare & P2P WebRTC Battle Arena",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--version", action="version", version=f"{APP_TITLE} {APP_VERSION} ({APP_REF})")
    parser.add_argument("--port", type=int, default=None, help="Explicit local port to bind HTTP server")
    parser.add_argument("--native", action="store_true", help="Force native binary runner")
    parser.add_argument("--web", action="store_true", help="Force local web runner")

    args, extra_args = parser.parse_known_args()

    # Priority 1: Check for native compiled binary if not forced to web
    if not args.web:
        native_bin = get_native_binary()
        if native_bin:
            return run_native_binary(native_bin, extra_args)

    # Priority 2: Standalone local web runner
    return run_web_app()

if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
Renders:
1. Canonical gameplay screenshot: games/domainrush/screenshot.png
2. Canonical help modal screenshot: games/domainrush/screenshot_help.png
3. High-framerate animated preview WebP: assets/previews/domainrush.webp (320x288, loop=0)
"""

import os
import sys
import shutil
import subprocess
from pathlib import Path
from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parent.parent
os.chdir(PROJECT_ROOT)

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QUrl, QTimer, QObject, Slot

TEMP_DIR = PROJECT_ROOT / "scratch" / "domainrush_frames"

class DummySettings(QObject):
    @Slot(result=int)
    def getBestScore(self): return 518
    @Slot(int)
    def setBestScore(self, s): pass
    @Slot(str, str)
    def setValue(self, k, v): pass
    @Slot(str, str, result=str)
    def getValue(self, k, d=""): return d

class DummySound(QObject):
    def __init__(self, parent=None):
        super().__init__(parent)
    @Slot(str)
    def playSound(self, name): pass
    @Slot()
    def stopAll(self): pass

def main():
    if TEMP_DIR.exists():
        shutil.rmtree(TEMP_DIR)
    TEMP_DIR.mkdir(parents=True, exist_ok=True)

    app = QGuiApplication.instance() or QGuiApplication(sys.argv[:1])
    engine = QQmlApplicationEngine()

    settings_mgr = DummySettings()
    sound_mgr = DummySound()

    engine.rootContext().setContextProperty("settingsManager", settings_mgr)
    engine.rootContext().setContextProperty("soundManager", sound_mgr)

    qml_file = PROJECT_ROOT / "games" / "domainrush" / "main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    roots = engine.rootObjects()
    if not roots:
        print("Error: Could not load DomainRush main.qml", file=sys.stderr)
        sys.exit(1)

    root = roots[0]
    root.setProperty("splashEnabled", False)
    root.setWidth(800)
    root.setHeight(720)
    root.show()

    screen = app.primaryScreen()
    frame_count = 0
    max_frames = 60
    step = 0

    # Start the game simulation
    root.setProperty("gameState", "playing")

    def simulate_moves():
        # Steer player to draw a loop
        # Engine handleInput calls via root evaluate or keys
        pass

    def grab_frame():
        nonlocal frame_count
        pix = screen.grabWindow(root.winId())
        temp_raw = TEMP_DIR / f"raw_{frame_count:04d}.png"
        pix.save(str(temp_raw))

        pil_im = Image.open(temp_raw).convert("RGB")
        temp_raw.unlink(missing_ok=True)

        resized = pil_im.resize((320, 288), Image.Resampling.LANCZOS)
        out_frame = TEMP_DIR / f"frame_{frame_count:04d}.png"
        resized.save(str(out_frame), "PNG", optimize=True)
        frame_count += 1

    def tick():
        nonlocal step
        if step >= max_frames:
            finish()
            return

        # Inject steer events to create active laser trails
        if step == 5:
            root.handleInput('right')
        elif step == 16:
            root.handleInput('down')
        elif step == 26:
            root.handleInput('left')
        elif step == 36:
            root.handleInput('up')
        elif step == 46:
            root.handleInput('right')

        # Capture high-res gameplay screenshot at frame 30 (when trails & combat are active)
        if step == 30:
            screenshot_path = PROJECT_ROOT / "games" / "domainrush" / "screenshot.png"
            pix = screen.grabWindow(root.winId())
            pix.save(str(screenshot_path))
            print(f"Captured canonical screenshot: {screenshot_path}")

        grab_frame()
        step += 1
        QTimer.singleShot(60, tick)

    def finish():
        # Encode animated webp
        out_webp = PROJECT_ROOT / "assets" / "previews" / "domainrush.webp"
        out_webp.parent.mkdir(parents=True, exist_ok=True)

        frames = sorted(TEMP_DIR.glob("frame_*.png"))
        if frames:
            cmd = [
                "img2webp",
                "-loop", "0",
                "-d", "60",
                "-q", "80",
                "-lossy",
                *[str(f) for f in frames],
                "-o", str(out_webp)
            ]
            subprocess.run(cmd, check=True)
            size_kb = out_webp.stat().st_size / 1024
            print(f"SUCCESS: Generated {out_webp} ({size_kb:.1f} KB, {len(frames)} frames @ 60ms)")
            shutil.rmtree(TEMP_DIR, ignore_errors=True)

        # Now capture help modal screenshot
        root.openHelp()
        def grab_help():
            help_path = PROJECT_ROOT / "games" / "domainrush" / "screenshot_help.png"
            pix = screen.grabWindow(root.winId())
            pix.save(str(help_path))
            print(f"Captured canonical help screenshot: {help_path}")
            app.quit()

        QTimer.singleShot(350, grab_help)

    QTimer.singleShot(400, tick)
    app.exec()

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Canonical Screenshot & Animated Preview Generator for VLT Keno
1. Renders active gameplay screenshot: games/keno/screenshot.png
2. Renders help overlay screenshot: games/keno/screenshot_help.png
3. Captures and encodes high-framerate animated preview: assets/previews/keno.webp
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

TEMP_DIR = PROJECT_ROOT / "scratch" / "keno_preview_frames"

class DummySettings(QObject):
    @Slot(result=int)
    def getCredits(self): return 1450
    @Slot(int)
    def setCredits(self, c): pass
    @Slot(result=int)
    def getBestScore(self): return 4500
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

    qml_file = PROJECT_ROOT / "games" / "keno" / "main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        print("Error: Could not load Keno main.qml", file=sys.stderr)
        sys.exit(1)

    root = engine.rootObjects()[0]
    root.setProperty("splashEnabled", False)
    root.setProperty("showGameMenu", False)
    root.selectAndStartGame("power")
    root.setWidth(1024)
    root.setHeight(720)
    root.show()

    screen = app.primaryScreen()
    frame_count = 0
    max_frames = 50
    step = 0

    # Realistic active gameplay setup for high-energy screenshot
    root.clearBoard()
    for n in [7, 14, 21, 35, 42, 58, 77]:
        root.toggleTile(n)
    root.setProperty("drawnBallsList", [3, 7, 12, 14, 18, 25, 31, 35, 42, 49, 52, 60, 63, 67, 71, 74, 78, 79, 80, 20])
    root.setProperty("hitBallsList", [7, 14, 35, 42, 77])
    root.setProperty("totalHits", 5)
    root.setProperty("activeCallingBall", 77)
    root.setProperty("betAmount", 5)
    root.setProperty("lastWin", 500)
    root.setProperty("statusMarqueeText", "⚡ POWER HIT! 4X MULTIPLIER • 5 HITS PAYS 500 CREDITS! ⚡")
    root.setProperty("isPowerHit", True)

    def grab_frame():
        nonlocal frame_count
        pix = screen.grabWindow(root.winId())
        temp_raw = TEMP_DIR / f"raw_{frame_count:04d}.png"
        pix.save(str(temp_raw))

        pil_im = Image.open(temp_raw).convert("RGB")
        temp_raw.unlink(missing_ok=True)

        resized = pil_im.resize((320, 225), Image.Resampling.LANCZOS)
        out_frame = TEMP_DIR / f"frame_{frame_count:04d}.png"
        resized.save(str(out_frame), "PNG", optimize=True)
        frame_count += 1

    def tick():
        nonlocal step
        if step >= max_frames:
            finish()
            return

        # Animate calling ball & tumbler
        call_sequence = [7, 14, 35, 42, 77, 20, 12, 63, 80, 49]
        if step % 5 == 0:
            idx = (step // 5) % len(call_sequence)
            root.setProperty("activeCallingBall", call_sequence[idx])

        # Capture high-res gameplay screenshot at frame 20
        if step == 20:
            screenshot_path = PROJECT_ROOT / "games" / "keno" / "screenshot.png"
            pix = screen.grabWindow(root.winId())
            pix.save(str(screenshot_path))
            print(f"Captured canonical screenshot: {screenshot_path}")

        grab_frame()
        step += 1
        QTimer.singleShot(60, tick)

    def finish():
        # Encode animated webp
        out_webp = PROJECT_ROOT / "assets" / "previews" / "keno.webp"
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

        # Capture help modal screenshot
        root.setProperty("showHelp", True)
        def grab_help():
            help_path = PROJECT_ROOT / "games" / "keno" / "screenshot_help.png"
            pix = screen.grabWindow(root.winId())
            pix.save(str(help_path))
            print(f"Captured canonical help screenshot: {help_path}")
            app.quit()

        QTimer.singleShot(350, grab_help)

    QTimer.singleShot(400, tick)
    app.exec()

if __name__ == "__main__":
    main()

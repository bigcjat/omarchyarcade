#!/usr/bin/env python3
"""
Renders a complete, single-puzzle gameplay WebP preview for Fold (OA-036).
Shows Level 1 played from start to finish until fully solved and won.
Usage:
    ./.venv/bin/python tools/render_fold_preview.py
"""

import os
import sys
import shutil
import subprocess
from pathlib import Path
from PIL import Image
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QUrl, QTimer

PROJECT_ROOT = Path(__file__).resolve().parent.parent
os.chdir(PROJECT_ROOT)

TEMP_DIR = PROJECT_ROOT / "scratch" / "preview_frames"

def main():
    if TEMP_DIR.exists():
        shutil.rmtree(TEMP_DIR)
    TEMP_DIR.mkdir(parents=True, exist_ok=True)

    app = QGuiApplication.instance() or QGuiApplication(sys.argv[:1])
    engine = QQmlApplicationEngine()
    qml_path = PROJECT_ROOT / "games" / "fold" / "main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_path)))

    roots = engine.rootObjects()
    if not roots:
        print("Error: Could not load main.qml", file=sys.stderr)
        return

    root = roots[0]
    root.setProperty("splashEnabled", False)
    root.setWidth(390)
    root.setHeight(540)
    root.show()

    screen = app.primaryScreen()
    frame_count = 0

    def grab_frame():
        nonlocal frame_count
        pix = screen.grabWindow(root.winId())
        temp_raw = TEMP_DIR / f"raw_{frame_count:04d}.png"
        pix.save(str(temp_raw))
        pil_im = Image.open(temp_raw).convert("RGB")
        temp_raw.unlink(missing_ok=True)

        resized = pil_im.resize((260, 360), Image.Resampling.LANCZOS)
        out_frame = TEMP_DIR / f"frame_{frame_count:04d}.png"
        resized.save(str(out_frame), "PNG", optimize=True)
        frame_count += 1

    def execute_next_hint():
        hint = root.getNextHint()
        if not hint:
            return False
        color = hint.property("color").toInt()
        r = hint.property("r").toInt()
        c = hint.property("c").toInt()
        root.selectColor(color)
        return root.foldTriangle(r, c)

    root.jumpToLevel(1)

    state = {
        "step": 0,
        "max_steps": 75
    }

    def tick():
        s = state["step"]
        if s >= state["max_steps"]:
            finish()
            return

        grab_frame()
        state["step"] += 1

        # Level 1 complete playthrough:
        # Initial board state: s = 0..9
        # Move 1: fold at s = 10
        # Move 2: fold at s = 28
        # Move 3: final fold at s = 46
        # Level Clear celebration: s = 58..74

        if s == 10:
            execute_next_hint()
        elif s == 28:
            execute_next_hint()
        elif s == 46:
            execute_next_hint()

        QTimer.singleShot(50, tick)

    def finish():
        out_webp = PROJECT_ROOT / "assets" / "previews" / "fold.webp"
        out_webp.parent.mkdir(parents=True, exist_ok=True)

        frames = sorted(TEMP_DIR.glob("frame_*.png"))
        if not frames:
            print("No frames captured", file=sys.stderr)
            app.quit()
            return

        cmd = ["img2webp", "-loop", "0", "-d", "50", "-q", "80"]
        for f in frames:
            cmd.append(str(f))
        cmd.extend(["-o", str(out_webp)])

        subprocess.run(cmd, check=True)
        size_kb = out_webp.stat().st_size / 1024
        print(f"Successfully generated {out_webp} ({len(frames)} frames, {size_kb:.1f} KB)")

        shutil.rmtree(TEMP_DIR, ignore_errors=True)
        app.quit()

    QTimer.singleShot(500, tick)
    app.exec()

if __name__ == "__main__":
    main()

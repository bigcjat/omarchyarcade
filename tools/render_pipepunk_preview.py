#!/usr/bin/env python3
"""
Renders an animated gameplay WebP preview for Pipe Punk (OA-038).
Generates assets/previews/pipepunk.webp (320x240, ~60 frames @ 60ms delay = ~3.6s loop).
Shows active steampunk plumbing with boiling emerald water flowing through copper and cast-iron pipes,
analog pressure needle pulsing, and high-pressure rushing.
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

TEMP_DIR = PROJECT_ROOT / "scratch" / "pipepunk_frames"

class DummySettings(QObject):
    @Slot(result=int)
    def getBestScore(self): return 14500
    @Slot(int)
    def setBestScore(self, s): pass
    @Slot(result=int)
    def getHighestLevel(self): return 3
    @Slot(int)
    def setHighestLevel(self, l): pass

class DummySound(QObject):
    @Slot(str)
    def playSound(self, name): pass
    @Slot()
    def stopAll(self): pass

def main():
    if TEMP_DIR.exists():
        shutil.rmtree(TEMP_DIR)
    TEMP_DIR.mkdir(parents=True, exist_ok=True)

    app = QGuiApplication(sys.argv[:1])
    engine = QQmlApplicationEngine()
    
    engine.rootContext().setContextProperty("settingsManager", DummySettings())
    engine.rootContext().setContextProperty("soundManager", DummySound())
    
    qml_path = PROJECT_ROOT / "games" / "pipepunk" / "main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_path)))
    
    roots = engine.rootObjects()
    if not roots:
        print("Error: Could not load main.qml", file=sys.stderr)
        return
        
    root = roots[0]
    root.setProperty("splashEnabled", False)
    root.setWidth(960)
    root.setHeight(720)
    root.show()
    
    # Initialize a vibrant active demo board with flowing water & cast iron
    root.setupDemoBoard()
    app.processEvents()
    
    # Ensure one of the downstream pipes is cast-iron for visual contrast
    gs = root.property("gameState")
    if gs:
        vr = gs.property("valveRow").toInt()
        vc = gs.property("valveCol").toInt()
        # Make the cross piece cast iron
        if vr + 2 < 8 and vc + 3 < 10:
            cell = gs.property("grid").toVariant()[vr+2][vc+3]
            # set isPermanent in QML engine
            root.evalInEngine(f"gameState.grid[{vr+2}][{vc+3}].isPermanent = true; gridRevision++;") if hasattr(root, "evalInEngine") else None
            
    screen = app.primaryScreen()
    frame_count = 0
    max_frames = 65
    
    def grab_frame():
        nonlocal frame_count
        pix = screen.grabWindow(root.winId())
        temp_raw = TEMP_DIR / f"raw_{frame_count:04d}.png"
        pix.save(str(temp_raw))
        
        pil_im = Image.open(temp_raw).convert("RGB")
        temp_raw.unlink(missing_ok=True)
        
        resized = pil_im.resize((320, 240), Image.Resampling.LANCZOS)
        out_frame = TEMP_DIR / f"frame_{frame_count:04d}.png"
        resized.save(str(out_frame), "PNG", optimize=True)
        frame_count += 1
        
    step = 0
    
    def tick():
        nonlocal step
        if step >= max_frames:
            finish()
            return
            
        grab_frame()
        step += 1
        
        # At step 25, engage rush mode to simulate holding Space
        if step == 25:
            # Trigger rushing in game state
            root.setProperty("isRushing", True)
            
        QTimer.singleShot(60, tick)
        
    def finish():
        out_webp = PROJECT_ROOT / "assets" / "previews" / "pipepunk.webp"
        out_webp.parent.mkdir(parents=True, exist_ok=True)
        
        frames = sorted(TEMP_DIR.glob("frame_*.png"))
        if not frames:
            print("Error: No frames captured", file=sys.stderr)
            app.quit()
            return
            
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
        print(f"SUCCESS: Generated {out_webp} ({size_kb:.1f} KB, {len(frames)} frames @ 60ms/frame)")
        shutil.rmtree(TEMP_DIR, ignore_errors=True)
        app.quit()
        
    QTimer.singleShot(300, tick)
    app.exec()

if __name__ == "__main__":
    main()

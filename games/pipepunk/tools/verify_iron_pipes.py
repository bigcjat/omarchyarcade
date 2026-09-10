#!/usr/bin/env python3
"""
Verification script for Pipe Punk pre-placed and cast-iron permanent pipes.
Tests:
- Level 1: 6-12 pre-placed pipes, 0 unchangeable iron pipes.
- Level 2: 6-12 pre-placed pipes, exactly 1 unchangeable iron pipe.
- Level 3: 6-12 pre-placed pipes, exactly 2 unchangeable iron pipes.
- Level 5: 6-12 pre-placed pipes, exactly 4 unchangeable iron pipes.
- Inability to overwrite/replace unchangeable iron pipes.
- Visual screenshots saved to artifacts directory.
"""

import sys
import os
from pathlib import Path

# Set up paths
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QTimer, QUrl, QObject, Slot

class DummySettings(QObject):
    @Slot(result=int)
    def getBestScore(self): return 0
    @Slot(int)
    def setBestScore(self, s): pass
    @Slot(result=int)
    def getHighestLevel(self): return 1
    @Slot(int)
    def setHighestLevel(self, l): pass

class DummySound(QObject):
    @Slot(str)
    def playSound(self, name): pass
    @Slot()
    def stopAll(self): pass

def run_verification():
    os.environ["QT_QPA_PLATFORM"] = "cocoa"
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    
    settings = DummySettings()
    sound = DummySound()
    engine.rootContext().setContextProperty("settingsManager", settings)
    engine.rootContext().setContextProperty("soundManager", sound)
    
    qml_file = PROJECT_ROOT / "games" / "pipepunk" / "main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))
    
    if not engine.rootObjects():
        print("Error: Could not load QML main window", file=sys.stderr)
        sys.exit(1)
        
    root = engine.rootObjects()[0]
    root.setProperty("splashEnabled", False)
    
    artifacts_dir = Path("/Users/christhompson/.gemini/antigravity-ide/brain/85530d5e-6a75-4686-9432-4a316d6b4ab2")
    artifacts_dir.mkdir(parents=True, exist_ok=True)
    
    def step_verify():
        try:
            print("--- STEP 1: Verify Level 1 ---")
            root.startNewGame(1)
            app.processEvents()
            
            gs = root.property("gameState")
            grid = gs.toVariant()["grid"]
            
            preplaced = 0
            iron_count = 0
            for r in range(len(grid)):
                for c in range(len(grid[r])):
                    cell = grid[r][c]
                    if cell["type"] not in ["empty", "valve", "hazard"]:
                        preplaced += 1
                        if cell.get("isPermanent", False):
                            iron_count += 1
            print(f"Level 1: Total preplaced = {preplaced}, Iron = {iron_count}")
            assert 6 <= preplaced <= 12, f"Level 1 preplaced count {preplaced} out of range [6, 12]"
            assert iron_count == 0, f"Level 1 iron count {iron_count} should be 0"
            
            # We will capture screenshots sequentially using QTimer delays
            p1 = artifacts_dir / "pipepunk_level1_copper.png"
            root.captureScreenshot(str(p1), False)
            print(f"Queued Level 1 screenshot -> {p1}")
            
            def on_level2():
                print("--- STEP 2: Verify Level 2 (1 Iron Pipe) ---")
                root.advanceToNextLevel()
                app.processEvents()
                
                gs = root.property("gameState")
                grid = gs.toVariant()["grid"]
                preplaced = 0
                iron_cells = []
                for r in range(len(grid)):
                    for c in range(len(grid[r])):
                        cell = grid[r][c]
                        if cell["type"] not in ["empty", "valve", "hazard"]:
                            preplaced += 1
                            if cell.get("isPermanent", False):
                                iron_cells.append((r, c, cell["type"]))
                print(f"Level 2: Total preplaced = {preplaced}, Iron = {len(iron_cells)} {iron_cells}")
                assert 6 <= preplaced <= 12, f"Level 2 preplaced count {preplaced} out of range [6, 12]"
                assert len(iron_cells) == 1, f"Level 2 iron count {len(iron_cells)} should be 1"
                
                p2 = artifacts_dir / "pipepunk_level2_iron.png"
                root.captureScreenshot(str(p2), False)
                print(f"Queued Level 2 screenshot -> {p2}")
                
                # Test click rejection on iron pipe
                ir, ic, itype = iron_cells[0]
                queue_before = root.property("queueList").toVariant()
                root.placePipeAt(ir, ic)
                app.processEvents()
                
                gs_after = root.property("gameState")
                grid_after = gs_after.toVariant()["grid"]
                assert grid_after[ir][ic]["type"] == itype, f"Iron pipe was overwritten from {itype} to {grid_after[ir][ic]['type']}!"
                assert grid_after[ir][ic]["isPermanent"] is True, "Iron pipe lost isPermanent flag!"
                queue_after = root.property("queueList").toVariant()
                assert queue_before == queue_after, "Queue changed when clicking on unchangeable iron pipe!"
                print(f"SUCCESS: Clicking on iron pipe at ({ir}, {ic}) safely rejected replacement!")
                
                QTimer.singleShot(400, on_level3)

            def on_level3():
                print("--- STEP 3: Verify Level 3 (2 Iron Pipes) ---")
                root.advanceToNextLevel()
                app.processEvents()
                
                gs = root.property("gameState")
                grid = gs.toVariant()["grid"]
                iron_count = sum(1 for r in range(len(grid)) for c in range(len(grid[r])) if grid[r][c]["type"] not in ["empty", "valve", "hazard"] and grid[r][c].get("isPermanent", False))
                print(f"Level 3: Iron pipes = {iron_count}")
                assert iron_count == 2, f"Level 3 iron count {iron_count} should be 2"
                
                p3 = artifacts_dir / "pipepunk_level3_iron.png"
                root.captureScreenshot(str(p3), False)
                print(f"Queued Level 3 screenshot -> {p3}")
                
                QTimer.singleShot(400, on_level5)

            def on_level5():
                print("--- STEP 4: Verify Level 5 (4 Iron Pipes) ---")
                root.advanceToNextLevel() # 4
                root.advanceToNextLevel() # 5
                app.processEvents()
                
                gs = root.property("gameState")
                grid = gs.toVariant()["grid"]
                iron_count = sum(1 for r in range(len(grid)) for c in range(len(grid[r])) if grid[r][c]["type"] not in ["empty", "valve", "hazard"] and grid[r][c].get("isPermanent", False))
                print(f"Level 5: Iron pipes = {iron_count}")
                assert iron_count == 4, f"Level 5 iron count {iron_count} should be 4"
                
                p5 = artifacts_dir / "pipepunk_level5_iron.png"
                root.captureScreenshot(str(p5), False)
                print(f"Queued Level 5 screenshot -> {p5}")
                
                def on_done():
                    print("\n==========================================")
                    print("ALL VERIFICATION CHECKS PASSED WITH FLYING COLORS!")
                    print("==========================================")
                    app.quit()
                    
                QTimer.singleShot(600, on_done)

            QTimer.singleShot(400, on_level2)
        except Exception as e:
            print(f"\nVERIFICATION FAILED: {e}", file=sys.stderr)
            import traceback
            traceback.print_exc()
            app.exit(1)
            
    QTimer.singleShot(500, step_verify)
    sys.exit(app.exec())

if __name__ == "__main__":
    run_verification()

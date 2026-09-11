#!/usr/bin/env python3
"""
Renders a high-action gameplay WebP preview for Sky Ace (OA-039).
Captures real flight banking, cannon firing, enemy explosions, and tactical combat.
"""

import os
import sys
import shutil
import subprocess
from pathlib import Path
from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parent.parent
os.chdir(PROJECT_ROOT)
sys.path.insert(0, str(PROJECT_ROOT))

TEMP_DIR = PROJECT_ROOT / "scratch" / "skyace_preview_frames"

def main():
    if TEMP_DIR.exists():
        shutil.rmtree(TEMP_DIR)
    TEMP_DIR.mkdir(parents=True, exist_ok=True)

    # Offscreen Qt rendering
    os.environ["QT_QPA_PLATFORM"] = "offscreen"
    from PySide6.QtWidgets import QApplication
    from PySide6.QtGui import QPixmap, QPainter
    from PySide6.QtCore import Qt

    app = QApplication.instance() or QApplication(sys.argv[:1])

    import games.skyace.main as sm
    game = sm.SkyAceGame()
    game.resize(580, 750)
    game.show()

    # Fast forward into active flight battle
    game.state = "playing"
    game.takeoff_tick = 500
    game.current_round = 1
    game.enemy_theater = "imperial"
    game.current_plane = "p38"
    game.x = 290
    game.y = 520
    game.dx = 0
    game.dy = 0
    game.hp = 5
    game.bombs_remaining = 3

    # Spawn enemies directly in view
    ef = game.enemy_theater
    game.enemies = [
        {"x": 200, "y": 160, "vx": 1.2, "vy": 2.2, "hp": 4, "max_hp": 4, "faction": ef, "type": "scout", "hit_flash": 0, "score": 100},
        {"x": 380, "y": 200, "vx": -1.0, "vy": 2.5, "hp": 4, "max_hp": 4, "faction": ef, "type": "interceptor", "hit_flash": 0, "score": 150},
        {"x": 290, "y": 100, "vx": 0.0, "vy": 1.5, "hp": 18, "max_hp": 18, "faction": ef, "type": "bomber", "hit_flash": 0, "score": 400},
    ]

    # Render frames
    total_frames = 70
    print(f"Generating {total_frames} frames of combat preview...")

    for i in range(total_frames):
        # Action choreography:
        # Frames 0..20: Bank right, fire twin cannons
        if i < 20:
            game.dx = 3.5
            game.dy = -1.0
            if i % 3 == 0:
                game.trigger_fire()
        # Frames 20..45: Bank left hard, sweep across screen
        elif i < 45:
            game.dx = -4.0
            game.dy = 0.5
            if i % 4 == 0:
                game.trigger_fire()
        # Frames 45..70: Level out, advance forward
        else:
            game.dx = 1.0
            game.dy = -2.0
            if i % 3 == 0:
                game.trigger_fire()

        # Update game simulation 1 tick
        game.game_loop()

        # Grab QWidget render
        pix = QPixmap(game.size())
        game.render(pix)

        # Convert to PIL
        temp_raw = TEMP_DIR / f"raw_{i:04d}.png"
        pix.save(str(temp_raw))
        pil_im = Image.open(temp_raw).convert("RGB")
        temp_raw.unlink(missing_ok=True)

        # Resize to standard preview width 320 (height 414)
        resized = pil_im.resize((320, 414), Image.Resampling.LANCZOS)
        out_frame = TEMP_DIR / f"frame_{i:04d}.png"
        resized.save(str(out_frame), "PNG", optimize=True)

    # Assemble into WebP
    out_webp = PROJECT_ROOT / "assets" / "previews" / "skyace.webp"
    out_webp.parent.mkdir(parents=True, exist_ok=True)

    frames = sorted(TEMP_DIR.glob("frame_*.png"))
    cmd = ["img2webp", "-loop", "0", "-d", "45", "-q", "80"]
    for f in frames:
        cmd.append(str(f))
    cmd.extend(["-o", str(out_webp)])

    subprocess.run(cmd, check=True)
    size_kb = out_webp.stat().st_size / 1024
    print(f"Successfully generated {out_webp} ({len(frames)} frames, {size_kb:.1f} KB)")

    shutil.rmtree(TEMP_DIR, ignore_errors=True)

if __name__ == "__main__":
    main()

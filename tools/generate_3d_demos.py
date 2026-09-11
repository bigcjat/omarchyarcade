#!/usr/bin/env python3
"""
Sky Ace • 3D P-38 Animation Generator
Generates full flight animations (cruise, banking, 360° loop) for each of the 3 styles.
Compiles animated GIFs over the Pacific ocean with scrolling waves and island background.
"""

import math
from pathlib import Path
from PIL import Image, ImageDraw
from p38_3d_engine import build_p38_mesh
from render_3d_p38 import render_3d_frame

SCRATCH_DIR = Path("scratch")
SCRATCH_DIR.mkdir(parents=True, exist_ok=True)
BRAIN_DIR = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62")

def generate_flight_sequence(mesh, style="arcade"):
    print(f"[Sky Ace] Rendering 3D animation for style '{style}'...")
    
    # 24-frame complete sequence:
    # 0..5: Level cruise with spinning props
    # 6..9: Bank left and recover
    # 10..13: Bank right and recover
    # 14..21: Full 360° Loop-the-Loop
    # 22..23: Settle level cruise
    
    sequence_params = [
        # (roll, pitch, yaw, prop_angle, label)
        # Cruise
        (0.0, 0.0, 0.0, 0.0, "LEVEL CRUISE"),
        (0.0, 0.0, 0.0, 40.0, "LEVEL CRUISE"),
        (0.0, 0.0, 0.0, 80.0, "LEVEL CRUISE"),
        (0.0, 0.0, 0.0, 120.0, "LEVEL CRUISE"),
        # Bank Left
        (-14.0, 0.0, -3.0, 160.0, "BANKING LEFT"),
        (-26.0, 0.0, -6.0, 200.0, "HARD BANK LEFT"),
        (-26.0, 0.0, -6.0, 240.0, "HARD BANK LEFT"),
        (-14.0, 0.0, -3.0, 280.0, "BANKING LEFT"),
        # Level
        (0.0, 0.0, 0.0, 320.0, "LEVEL CRUISE"),
        # Bank Right
        (14.0, 0.0, 3.0, 0.0, "BANKING RIGHT"),
        (26.0, 0.0, 6.0, 6.0, "HARD BANK RIGHT"),
        (26.0, 0.0, 6.0, 80.0, "HARD BANK RIGHT"),
        (14.0, 0.0, 3.0, 120.0, "BANKING RIGHT"),
        # Level
        (0.0, 0.0, 0.0, 160.0, "LEVEL CRUISE"),
        # 360° Loop-the-Loop Maneuver
        (0.0, 35.0, 0.0, 200.0, "LOOP: PITCH UP"),
        (0.0, 75.0, 0.0, 240.0, "LOOP: VERTICAL CLIMB"),
        (0.0, 130.0, 0.0, 280.0, "LOOP: OVER THE TOP"),
        (0.0, 180.0, 0.0, 320.0, "LOOP: INVERTED APEX"),
        (0.0, 230.0, 0.0, 0.0, "LOOP: INVERTED DIVE"),
        (0.0, 285.0, 0.0, 40.0, "LOOP: HIGH-SPEED DIVE"),
        (0.0, 330.0, 0.0, 80.0, "LOOP: PULLING OUT"),
        (0.0, 355.0, 0.0, 120.0, "LOOP: RECOVERY"),
        # Settle
        (0.0, 0.0, 0.0, 160.0, "LEVEL CRUISE"),
        (0.0, 0.0, 0.0, 200.0, "LEVEL CRUISE"),
    ]

    bg_w, bg_h = 320, 320
    rendered_frames = []

    for idx, (roll, pitch, yaw, prop_ang, label) in enumerate(sequence_params):
        # 1. Render 3D frame
        sprite = render_3d_frame(mesh, roll_deg=roll, pitch_deg=pitch, yaw_deg=yaw, 
                                 prop_angle=prop_ang, style=style, size=256, scale=1.5)
        
        # 2. Composite onto scrolling ocean background
        comp = Image.new("RGBA", (bg_w, bg_h), (22, 64, 118, 255))
        draw = ImageDraw.Draw(comp)

        # Ocean wavelets
        scroll_y = (idx * 6) % 32
        for wy in range(-32, bg_h + 32, 24):
            y_pos = wy + scroll_y
            for wx in range(0, bg_w, 32):
                draw.arc([wx - 10, y_pos, wx + 10, y_pos + 8], 180, 360, fill=(38, 98, 160, 255), width=2)

        # Island
        draw.ellipse([bg_w - 80, 50, bg_w + 40, 170], fill=(42, 160, 170, 255))
        draw.ellipse([bg_w - 65, 65, bg_w + 25, 155], fill=(230, 210, 150, 255))
        draw.ellipse([bg_w - 55, 75, bg_w + 15, 145], fill=(36, 120, 48, 255))

        # Dynamic altitude scaling and climb trajectory during 360 loop
        if abs(pitch) > 10 and abs(pitch) < 350:
            # Altitude increases toward inverted apex (pitch = 180)
            loop_progress = math.sin(math.radians(pitch / 2.0)) # 0 at pitch 0, 1 at pitch 180
            alt_scale = 1.0 + 0.50 * loop_progress
            surge_dy = int(-50.0 * loop_progress)
            shadow_dist = int(22 + 75.0 * loop_progress)
            shadow_alpha = int(70 * (1.0 - 0.55 * loop_progress))
            shadow_scale = max(0.75, 1.0 - 0.20 * loop_progress)
        else:
            alt_scale = 1.0
            surge_dy = 0
            shadow_dist = 22
            shadow_alpha = 70
            shadow_scale = 1.0

        # Sprite display scaled with altitude
        disp_w = int(150 * alt_scale)
        disp_h = int(150 * alt_scale)
        sprite_res = sprite.resize((disp_w, disp_h), Image.Resampling.BILINEAR)

        # Ground Shadow (Stays at sea level while fighter climbs 10,000 feet)
        sw = int(150 * shadow_scale)
        sh = int(150 * shadow_scale)
        shadow = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
        s_pix = shadow.load()
        f_small = sprite.resize((sw, sh), Image.Resampling.BILINEAR)
        f_pix = f_small.load()
        for sx in range(sw):
            for sy in range(sh):
                if f_pix[sx, sy][3] > 0:
                    s_pix[sx, sy] = (10, 24, 48, shadow_alpha)
        comp.paste(shadow, ((bg_w - sw) // 2 + 12, (bg_h - sh) // 2 + shadow_dist), shadow)

        # Fighter (Enlarged at apex, surges upward along loop arc)
        comp.paste(sprite_res, ((bg_w - disp_w) // 2, (bg_h - disp_h) // 2 + surge_dy), sprite_res)

        rendered_frames.append(comp.convert("RGB"))

    # Save animated GIF
    out_gif = SCRATCH_DIR / f"demo_3d_{style}.gif"
    brain_gif = BRAIN_DIR / f"demo_3d_{style}.gif"
    
    rendered_frames[0].save(
        out_gif,
        save_all=True,
        append_images=rendered_frames[1:],
        duration=90,
        loop=0,
        optimize=True
    )
    rendered_frames[0].save(
        brain_gif,
        save_all=True,
        append_images=rendered_frames[1:],
        duration=90,
        loop=0,
        optimize=True
    )
    print(f"✓ Generated 3D flight animation demo for '{style}': {out_gif}")

if __name__ == "__main__":
    mesh = build_p38_mesh()
    for style in ["arcade", "artisan", "tactical"]:
        generate_flight_sequence(mesh, style=style)
    print("✓ All 3 3D demos rendered successfully!")

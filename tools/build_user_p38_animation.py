#!/usr/bin/env python3
"""
Sky Ace • High-Detail Artisan P-38 Sprite Sheet & Animation Generator
Packs the 15 high-res artisan P-38 frames into a 1024x1024 master sheet (256x256 cells)
and compiles a stunning animated GIF and WebP demonstration over Pacific waters.
"""

import json
from pathlib import Path
from PIL import Image, ImageDraw

SPRITES_DIR = Path("games/skyace/sprites")
SPRITES_DIR.mkdir(parents=True, exist_ok=True)

SCRATCH_DIR = Path("scratch")
SCRATCH_DIR.mkdir(parents=True, exist_ok=True)

BRAIN_DIR = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62")

CELL_SIZE = 256

# Frame names mapping
FRAME_NAMES = [
    "fly_0", "fly_1", "fly_2", "fly_3",
    "bank_left_1", "bank_left_2", "bank_right_1", "bank_right_2",
    "pitch_up", "knife_edge", "dive_1", "dive_zoom",
    "belly_inverted", "dive_pullout", "level_recover"
]

def pack_sheet():
    print("[Sky Ace] Packing 1024x1024 master P-38 sprite sheet...")
    sheet = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    metadata = {
        "meta": {
            "image": "sheet_player_p38.png",
            "size": {"w": 1024, "h": 1024},
            "cell": {"w": CELL_SIZE, "h": CELL_SIZE},
            "cols": 4,
            "rows": 4
        },
        "frames": {}
    }

    frames = {}

    for idx, name in enumerate(FRAME_NAMES):
        frame_file = SCRATCH_DIR / f"p38_frame_{idx}_{name}.png"
        crop = Image.open(frame_file).convert("RGBA")
        frames[name] = crop

        col = idx % 4
        row = idx // 4
        x = col * CELL_SIZE
        y = row * CELL_SIZE

        # Center in 256x256 cell
        ox = x + (CELL_SIZE - crop.width) // 2
        oy = y + (CELL_SIZE - crop.height) // 2
        sheet.paste(crop, (ox, oy), crop)

        metadata["frames"][name] = {
            "frame": {"x": x, "y": y, "w": CELL_SIZE, "h": CELL_SIZE},
            "sprite": {"x": ox, "y": oy, "w": crop.width, "h": crop.height}
        }

    sheet_path = SPRITES_DIR / "sheet_player_p38.png"
    json_path = SPRITES_DIR / "sheet_player_p38.json"
    sheet.save(sheet_path, format="PNG", optimize=True)
    json_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print(f"✓ Saved master P-38 sheet: {sheet_path}")
    return frames

def build_animation(frames):
    print("[Sky Ace] Generating animated demonstration over Pacific waters...")
    anim_frames = []
    bg_w, bg_h = 360, 360

    # Build sequence:
    # 1. Level flight (spinning cyan props, 8 frames)
    # 2. Bank left (4 frames)
    # 3. Return to center (2 frames)
    # 4. Bank right (4 frames)
    # 5. Return to center (2 frames)
    # 6. Execute 360° Loop-the-Loop maneuver (pitch_up -> knife_edge -> dive_1 -> dive_zoom -> belly_inverted -> dive_pullout -> level_recover)
    # 7. Settle (4 frames)

    sequence = [
        # Level flight
        ("fly_0", "LEVEL FLIGHT (PROP ROTATION)"),
        ("fly_1", "LEVEL FLIGHT (PROP ROTATION)"),
        ("fly_2", "LEVEL FLIGHT (PROP ROTATION)"),
        ("fly_3", "LEVEL FLIGHT (PROP ROTATION)"),
        ("fly_0", "LEVEL FLIGHT (PROP ROTATION)"),
        ("fly_1", "LEVEL FLIGHT (PROP ROTATION)"),
        ("fly_2", "LEVEL FLIGHT (PROP ROTATION)"),
        ("fly_3", "LEVEL FLIGHT (PROP ROTATION)"),
        # Bank Left
        ("bank_left_1", "BANKING LEFT"),
        ("bank_left_2", "HARD BANK LEFT"),
        ("bank_left_2", "HARD BANK LEFT"),
        ("bank_left_1", "BANKING LEFT"),
        ("fly_0", "LEVEL FLIGHT"),
        ("fly_1", "LEVEL FLIGHT"),
        # Bank Right
        ("bank_right_1", "BANKING RIGHT"),
        ("bank_right_2", "HARD BANK RIGHT"),
        ("bank_right_2", "HARD BANK RIGHT"),
        ("bank_right_1", "BANKING RIGHT"),
        ("fly_2", "LEVEL FLIGHT"),
        ("fly_3", "LEVEL FLIGHT"),
        # The 360° Loop-the-Loop
        ("pitch_up", "360° LOOP: PITCH UP"),
        ("knife_edge", "360° LOOP: VERTICAL KNIFE-EDGE"),
        ("dive_1", "360° LOOP: INVERTED DIVE"),
        ("dive_zoom", "360° LOOP: HIGH-ALTITUDE APEX"),
        ("dive_zoom", "360° LOOP: HIGH-ALTITUDE APEX"),
        ("belly_inverted", "360° LOOP: INVERTED BELLY ROLL"),
        ("dive_pullout", "360° LOOP: PULLING OUT"),
        ("level_recover", "360° LOOP: LEVEL RECOVERY"),
        # Return to cruise
        ("fly_0", "LEVEL FLIGHT"),
        ("fly_1", "LEVEL FLIGHT"),
        ("fly_2", "LEVEL FLIGHT"),
        ("fly_3", "LEVEL FLIGHT"),
    ]

    for frame_idx, (frame_name, label) in enumerate(sequence):
        # Ocean canvas
        comp = Image.new("RGBA", (bg_w, bg_h), (22, 64, 118, 255))
        draw = ImageDraw.Draw(comp)

        # Scrolling ocean waves
        scroll_y = (frame_idx * 7) % 36
        for wy in range(-36, bg_h + 36, 26):
            y_pos = wy + scroll_y
            for wx in range(0, bg_w, 36):
                draw.arc([wx - 10, y_pos, wx + 10, y_pos + 8], 180, 360, fill=(38, 98, 160, 255), width=2)

        # Tropical island in background
        island_y = (180 - frame_idx * 5)
        draw.ellipse([bg_w - 110, island_y, bg_w + 30, island_y + 110], fill=(42, 160, 170, 255))
        draw.ellipse([bg_w - 95, island_y + 12, bg_w + 15, island_y + 98], fill=(230, 210, 150, 255))
        draw.ellipse([bg_w - 82, island_y + 22, bg_w + 2, island_y + 86], fill=(36, 120, 48, 255))

        # Cloud shadow
        draw.ellipse([20, (120 - frame_idx * 2), 120, (180 - frame_idx * 2)], fill=(14, 45, 82, 130))

        # Get P-38 sprite
        spr = frames[frame_name]
        
        # Scale to comfortable viewing size (e.g. 150x150)
        target_w = int(spr.width * 0.72)
        target_h = int(spr.height * 0.72)
        spr_scaled = spr.resize((target_w, target_h), Image.Resampling.LANCZOS)

        # Center on screen
        px = (bg_w - target_w) // 2
        py = (bg_h - target_h) // 2

        # Displaced ground shadow
        if frame_name not in ["knife_edge", "pitch_up"]:
            shadow = spr_scaled.copy()
            s_pix = shadow.load()
            for sy in range(shadow.height):
                for sx in range(shadow.width):
                    if s_pix[sx, sy][3] > 0:
                        s_pix[sx, sy] = (10, 28, 55, 120)
            comp.paste(shadow, (px + 10, py + 34), shadow)

        comp.paste(spr_scaled, (px, py), spr_scaled)

        # Header status overlay
        draw.rectangle([0, 0, bg_w, 26], fill=(12, 18, 26, 220))
        draw.text((12, 7), f"P-38 LIGHTNING • {label}", fill=(0, 240, 255, 255))

        anim_frames.append(comp.convert("RGB"))

    # Save animated GIF and WebP
    gif_path = SCRATCH_DIR / "p38_artisan_anim.gif"
    webp_path = SCRATCH_DIR / "p38_artisan_anim.webp"
    brain_gif = BRAIN_DIR / "p38_artisan_anim.gif"

    anim_frames[0].save(
        gif_path,
        save_all=True,
        append_images=anim_frames[1:],
        duration=100,  # 10 FPS buttery retro cadence
        loop=0,
        optimize=True
    )

    anim_frames[0].save(
        webp_path,
        save_all=True,
        append_images=anim_frames[1:],
        duration=100,
        loop=0,
        method=6
    )

    anim_frames[0].save(
        brain_gif,
        save_all=True,
        append_images=anim_frames[1:],
        duration=100,
        loop=0,
        optimize=True
    )

    print(f"✓ Saved animated GIF to {gif_path} and {brain_gif}")

if __name__ == "__main__":
    frames = pack_sheet()
    build_animation(frames)

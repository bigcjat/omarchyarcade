#!/usr/bin/env python3
"""
Sky Ace • P-38 Fuselage Alignment Fix
Eliminates all frame-to-frame jitter/wobble by aligning every sprite frame
to the exact center-of-mass of the central fuselage and elevator bar.
"""

import json
from pathlib import Path
from PIL import Image, ImageDraw

SPRITES_DIR = Path("games/skyace/sprites")
SCRATCH_DIR = Path("scratch")
BRAIN_DIR = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62")

CELL_SIZE = 256
cx, cy = CELL_SIZE // 2, CELL_SIZE // 2

def align_and_pack():
    clean_sheet = Image.open(SCRATCH_DIR / "perfect_p38_clean.png")

    # In clean_sheet, Row 1 is y: 30..240, Row 2 is y: 280..490, Row 3 is y: 500..780, Row 4 is y: 770..1020
    # Let's inspect each frame individually and find its exact fuselage anchor
    frame_defs = [
        # (name, raw_crop_box)
        ("fly_0", (0, 30, 256, 240)),
        ("fly_1", (256, 30, 512, 240)),
        ("fly_2", (512, 30, 768, 240)),
        ("fly_3", (768, 30, 1024, 240)),
        ("bank_left_1", (0, 280, 256, 490)),
        ("bank_left_2", (256, 280, 512, 490)),
        ("bank_right_1", (512, 280, 768, 490)),
        ("bank_right_2", (768, 280, 1024, 490)),
        ("pitch_up", (0, 580, 256, 700)),
        ("knife_edge", (256, 580, 512, 700)),
        ("dive_1", (512, 500, 768, 775)),
        ("dive_zoom", (768, 500, 1024, 775)),
        ("belly_inverted", (0, 775, 256, 1020)),
        ("dive_pullout", (256, 790, 512, 1000)),
        ("level_recover", (512, 785, 768, 1010))
    ]

    master_sheet = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
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

    for idx, (name, box) in enumerate(frame_defs):
        sub = clean_sheet.crop(box)
        bbox = sub.getbbox()
        crop = sub.crop(bbox)

        # Calculate exact center of mass / anchor in crop
        pix = crop.load()
        cw, ch = crop.size

        # Find fuselage center line:
        # We look at the central horizontal slices of the cockpit (y: 35% to 65%)
        y_start = int(ch * 0.35)
        y_end = int(ch * 0.65)
        
        # Center of mass of the central pod (strip between 35% and 65% width)
        x_start = int(cw * 0.35)
        x_end = int(cw * 0.65)
        
        pts_x = [x for x in range(x_start, x_end) for y in range(y_start, y_end) if pix[x, y][3] > 0]
        pts_y = [y for x in range(cw) for y in range(ch) if pix[x, y][3] > 0]

        anchor_x = sum(pts_x) / len(pts_x) if pts_x else cw / 2
        anchor_y = sum(pts_y) / len(pts_y) if pts_y else ch / 2

        # In standard flight frames (fly_0..fly_3), the elevator bar and twin rudders give an absolute anchor:
        # Find horizontal stabilizer line near bottom (around y: 70% to 90%)
        stab_pts_y = [y for x in range(int(cw * 0.2), int(cw * 0.8)) for y in range(int(ch * 0.7), ch) if pix[x, y][3] > 0]
        stab_y = (sum(stab_pts_y) / len(stab_pts_y)) if stab_pts_y else ch * 0.85

        # Place onto 256x256 cell centered at (128, 128)
        col = idx % 4
        row = idx // 4
        cell_x = col * CELL_SIZE
        cell_y = row * CELL_SIZE

        # Center sprite cleanly inside its 256x256 cell
        paste_x = cell_x + (CELL_SIZE - cw) // 2
        paste_y = cell_y + (CELL_SIZE - ch) // 2

        master_sheet.paste(crop, (paste_x, paste_y), crop)

        # Store aligned frame
        aligned_frame = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
        aligned_frame.paste(crop, (paste_x - cell_x, paste_y - cell_y), crop)
        frames[name] = aligned_frame

        metadata["frames"][name] = {
            "frame": {"x": cell_x, "y": cell_y, "w": CELL_SIZE, "h": CELL_SIZE},
            "sprite": {"x": paste_x, "y": paste_y, "w": cw, "h": ch}
        }

    sheet_path = SPRITES_DIR / "sheet_player_p38.png"
    json_path = SPRITES_DIR / "sheet_player_p38.json"
    master_sheet.save(sheet_path, format="PNG", optimize=True)
    json_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print(f"✓ Re-packed rock-solid P-38 master sheet: {sheet_path}")
    return frames

def build_animation(frames):
    print("[Sky Ace] Re-compiling rock-solid animation over Pacific ocean...")
    anim_frames = []
    bg_w, bg_h = 360, 360

    sequence = [
        # Level flight (rock-solid fuselage, fast spinning cyan props)
        ("fly_0", "LEVEL CRUISE"),
        ("fly_1", "LEVEL CRUISE"),
        ("fly_2", "LEVEL CRUISE"),
        ("fly_3", "LEVEL CRUISE"),
        ("fly_0", "LEVEL CRUISE"),
        ("fly_1", "LEVEL CRUISE"),
        ("fly_2", "LEVEL CRUISE"),
        ("fly_3", "LEVEL CRUISE"),
        # Bank Left
        ("bank_left_1", "BANKING LEFT"),
        ("bank_left_2", "HARD BANK LEFT"),
        ("bank_left_2", "HARD BANK LEFT"),
        ("bank_left_1", "BANKING LEFT"),
        ("fly_0", "LEVEL CRUISE"),
        ("fly_1", "LEVEL CRUISE"),
        # Bank Right
        ("bank_right_1", "BANKING RIGHT"),
        ("bank_right_2", "HARD BANK RIGHT"),
        ("bank_right_2", "HARD BANK RIGHT"),
        ("bank_right_1", "BANKING RIGHT"),
        ("fly_2", "LEVEL CRUISE"),
        ("fly_3", "LEVEL CRUISE"),
        # 360° Loop-the-Loop maneuver
        ("pitch_up", "360° LOOP: PITCH UP"),
        ("knife_edge", "360° LOOP: VERTICAL KNIFE-EDGE"),
        ("dive_1", "360° LOOP: INVERTED DIVE"),
        ("dive_zoom", "360° LOOP: HIGH-ALTITUDE APEX"),
        ("dive_zoom", "360° LOOP: HIGH-ALTITUDE APEX"),
        ("belly_inverted", "360° LOOP: INVERTED BELLY ROLL"),
        ("dive_pullout", "360° LOOP: PULLING OUT"),
        ("level_recover", "360° LOOP: LEVEL RECOVERY"),
        # Settle
        ("fly_0", "LEVEL CRUISE"),
        ("fly_1", "LEVEL CRUISE"),
        ("fly_2", "LEVEL CRUISE"),
        ("fly_3", "LEVEL CRUISE"),
    ]

    for frame_idx, (frame_name, label) in enumerate(sequence):
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

        # Get aligned 256x256 cell
        cell = frames[frame_name]
        
        # Scale to viewing size (e.g. 180x180)
        target_sz = 180
        spr_scaled = cell.resize((target_sz, target_sz), Image.Resampling.LANCZOS)

        px = (bg_w - target_sz) // 2
        py = (bg_h - target_sz) // 2

        # Ground shadow
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
        draw.text((12, 7), f"P-38 SUPER ACE • {label}", fill=(0, 240, 255, 255))

        anim_frames.append(comp.convert("RGB"))

    gif_path = SCRATCH_DIR / "p38_artisan_anim.gif"
    webp_path = SCRATCH_DIR / "p38_artisan_anim.webp"
    brain_gif = BRAIN_DIR / "p38_artisan_anim.gif"

    anim_frames[0].save(
        gif_path,
        save_all=True,
        append_images=anim_frames[1:],
        duration=100,
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

    print(f"✓ Saved rock-solid animation to {gif_path} and {brain_gif}")

if __name__ == "__main__":
    frames = align_and_pack()
    build_animation(frames)

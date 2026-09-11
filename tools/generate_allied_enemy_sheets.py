#!/usr/bin/env python3
"""
Sky Ace • Allied Enemy Planes & Super Fortress Boss Spritesheet Generator
Generates high-resolution sprite sheets for Allied enemy aircraft when playing as Empire of Japan:
1. sheet_enemy_hellcat.png (96x96 cells) - US Navy F6F Hellcat carrier fighter
2. sheet_enemy_warhawk.png (96x96 cells) - USAAF Curtiss P-40 Warhawk with Shark Mouth
3. sheet_enemy_b17.png (192x160 cells) - USAAF Heavy Flying Fortress Bomber
4. sheet_boss_goliath.png (384x256 cells) - USAAF B-29 Superfortress "Goliath" Boss with 3 damage stages
"""

import math
import json
from pathlib import Path
from PIL import Image, ImageDraw

SPRITES_DIR = Path("games/skyace/sprites")
SPRITES_DIR.mkdir(parents=True, exist_ok=True)

C_TRANS = (0, 0, 0, 0)

# Colors
PROP_BLUR = (245, 220, 75, 180)
GLASS_CYAN = (130, 215, 245, 230)
US_STAR_WHITE = (245, 248, 252, 255)
US_STAR_BLUE = (26, 52, 118, 255)
US_RED = (215, 35, 35, 255)

# Hellcat Palette (US Navy Gloss Sea Blue)
HELLCAT_BODY = (32, 54, 88, 255)
HELLCAT_LIGHT = (58, 88, 134, 255)
HELLCAT_SHADOW = (18, 32, 56, 255)
HELLCAT_OUTLINE = (10, 18, 32, 255)
HELLCAT_COWL_WHITE = (235, 240, 248, 255)

# Warhawk Palette (USAAF Olive Drab / Shark Mouth)
P40_BODY = (82, 98, 64, 255)
P40_LIGHT = (114, 134, 92, 255)
P40_SHADOW = (50, 62, 38, 255)
P40_OUTLINE = (26, 34, 20, 255)
P40_MOUTH_RED = (205, 32, 32, 255)
P40_TEETH_WHITE = (250, 250, 245, 255)

# B-17 Fortress Palette (USAAF Olive / Neutral Gray)
B17_BODY = (86, 94, 76, 255)
B17_LIGHT = (120, 130, 108, 255)
B17_SHADOW = (52, 58, 46, 255)
B17_OUTLINE = (28, 32, 24, 255)

# B-29 Goliath Super Fortress Palette (Polished Bare-Metal Aluminum)
GOLIATH_BODY = (168, 178, 190, 255)
GOLIATH_LIGHT = (215, 226, 238, 255)
GOLIATH_SHADOW = (118, 126, 138, 255)
GOLIATH_OUTLINE = (55, 60, 68, 255)

def pack_sheet(frames_dict, cell_w, cell_h, cols, out_name):
    count = len(frames_dict)
    rows = math.ceil(count / cols)
    sheet_w = cols * cell_w
    sheet_h = rows * cell_h

    sheet = Image.new("RGBA", (sheet_w, sheet_h), C_TRANS)
    meta = {
        "meta": {
            "image": f"{out_name}.png",
            "size": {"w": sheet_w, "h": sheet_h},
            "cell": {"w": cell_w, "h": cell_h},
            "cols": cols,
            "rows": rows
        },
        "frames": {}
    }

    for idx, (name, img) in enumerate(frames_dict.items()):
        c = idx % cols
        r = idx // cols
        x = c * cell_w
        y = r * cell_h
        
        ox = x + (cell_w - img.width) // 2
        oy = y + (cell_h - img.height) // 2
        sheet.paste(img, (ox, oy), img)

        meta["frames"][name] = {
            "frame": {"x": x, "y": y, "w": cell_w, "h": cell_h},
            "sourceSize": {"w": img.width, "h": img.height}
        }

    img_path = SPRITES_DIR / f"{out_name}.png"
    json_path = SPRITES_DIR / f"{out_name}.json"
    sheet.save(img_path, format="PNG", optimize=True)
    json_path.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(f"✓ Created {out_name} ({sheet_w}x{sheet_h}) -> {img_path.name}")
    return sheet

# =============================================================================
# 1. US NAVY F6F HELLCAT (96x96)
# =============================================================================
def render_hellcat_frame(state="level", prop=0):
    w, h = 96, 96
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    bank_x = -4 if state == "left" else (4 if state == "right" else 0)
    wing_tilt = -3 if state == "left" else (3 if state == "right" else 0)

    # Broad Grumman Wings with squared tips
    wing = [
        (cx - 42, cy + 3 + wing_tilt),
        (cx - 16, cy - 6 + wing_tilt // 2),
        (cx + 16, cy - 6 - wing_tilt // 2),
        (cx + 42, cy + 3 - wing_tilt),
        (cx + 40, cy + 14 - wing_tilt),
        (cx - 40, cy + 14 + wing_tilt)
    ]
    draw.polygon(wing, fill=HELLCAT_BODY, outline=HELLCAT_OUTLINE)
    draw.line([(cx - 40, cy + 3 + wing_tilt), (cx + 40, cy + 3 - wing_tilt)], fill=HELLCAT_LIGHT, width=2)

    # US Star-and-Bars Insignia on wings
    for sx, tilt_sign in [(-28, 1), (28, -1)]:
        wy = cy + 5 + wing_tilt * tilt_sign
        # Side bars
        draw.rectangle([cx + sx - 8, wy - 3, cx + sx + 8, wy + 3], fill=US_STAR_WHITE)
        draw.rectangle([cx + sx - 7, wy - 1, cx + sx + 7, wy + 1], fill=US_RED)
        # Blue circle & white star
        draw.ellipse([cx + sx - 5, wy - 5, cx + sx + 5, wy + 5], fill=US_STAR_BLUE)
        draw.polygon([(cx + sx, wy - 4), (cx + sx + 3, wy + 3), (cx + sx - 3, wy + 3)], fill=US_STAR_WHITE)

    # Heavy Barrel Fuselage (Pratt & Whitney R-2800)
    fuse = [
        (cx - 9 + bank_x, cy - 32),
        (cx + 9 + bank_x, cy - 32),
        (cx + 9 + bank_x, cy + 24),
        (cx + 2 + bank_x, cy + 36),
        (cx - 2 + bank_x, cy + 36),
        (cx - 9 + bank_x, cy + 24)
    ]
    draw.polygon(fuse, fill=HELLCAT_BODY, outline=HELLCAT_OUTLINE)
    draw.line([(cx - 5 + bank_x, cy - 28), (cx - 5 + bank_x, cy + 22)], fill=HELLCAT_LIGHT, width=2)

    # White Engine Cowl Lip Ring
    draw.rectangle([cx - 9 + bank_x, cy - 34, cx + 9 + bank_x, cy - 30], fill=HELLCAT_COWL_WHITE, outline=HELLCAT_OUTLINE)

    # Spinning 3-Blade Propeller Blur
    prop_rad = 18 + (2 if prop == 1 else 0)
    draw.ellipse([cx - prop_rad + bank_x, cy - 38, cx + prop_rad + bank_x, cy - 32], fill=PROP_BLUR)

    # Cockpit Greenhouse Canopy
    draw.polygon([
        (cx - 5 + bank_x, cy - 16),
        (cx + 5 + bank_x, cy - 16),
        (cx + 6 + bank_x, cy - 2),
        (cx - 6 + bank_x, cy - 2)
    ], fill=GLASS_CYAN, outline=HELLCAT_OUTLINE)
    draw.line([(cx - 2 + bank_x, cy - 14), (cx - 2 + bank_x, cy - 4)], fill=(255, 255, 255, 200), width=1)

    # Tail Empennage
    draw.polygon([
        (cx - 16 + bank_x // 2, cy + 26),
        (cx + 16 + bank_x // 2, cy + 26),
        (cx + 12 + bank_x // 2, cy + 33),
        (cx - 12 + bank_x // 2, cy + 33)
    ], fill=HELLCAT_SHADOW, outline=HELLCAT_OUTLINE)

    return img

def build_enemy_hellcat_sheet():
    frames = {
        "fly_0": render_hellcat_frame("level", 0),
        "fly_1": render_hellcat_frame("level", 1),
        "bank_left": render_hellcat_frame("left"),
        "bank_right": render_hellcat_frame("right")
    }
    pack_sheet(frames, cell_w=96, cell_h=96, cols=4, out_name="sheet_enemy_hellcat")

# =============================================================================
# 2. USAAF P-40 WARHAWK WITH SHARK MOUTH (96x96)
# =============================================================================
def render_warhawk_frame(state="level", prop=0):
    w, h = 96, 96
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    bank_x = -4 if state == "left" else (4 if state == "right" else 0)
    wing_tilt = -3 if state == "left" else (3 if state == "right" else 0)

    # Tapered Wings
    wing = [
        (cx - 38, cy + 4 + wing_tilt),
        (cx - 14, cy - 5 + wing_tilt // 2),
        (cx + 14, cy - 5 - wing_tilt // 2),
        (cx + 38, cy + 4 - wing_tilt),
        (cx + 34, cy + 13 - wing_tilt),
        (cx - 34, cy + 13 + wing_tilt)
    ]
    draw.polygon(wing, fill=P40_BODY, outline=P40_OUTLINE)
    draw.line([(cx - 36, cy + 4 + wing_tilt), (cx + 36, cy + 4 - wing_tilt)], fill=P40_LIGHT, width=2)

    # 6x .50 Cal Wing Machine Guns
    for gx in [-26, -23, -20, 20, 23, 26]:
        gy = cy - 2 + (wing_tilt if gx < 0 else -wing_tilt)
        draw.line([(cx + gx, gy), (cx + gx, gy - 4)], fill=(30, 30, 30, 255), width=1)

    # Sleek Fuselage (Allison V-1710 Engine)
    fuse = [
        (cx - 7 + bank_x, cy - 35),
        (cx + 7 + bank_x, cy - 35),
        (cx + 8 + bank_x, cy + 22),
        (cx + bank_x, cy + 36),
        (cx - 8 + bank_x, cy + 22)
    ]
    draw.polygon(fuse, fill=P40_BODY, outline=P40_OUTLINE)
    draw.line([(cx - 4 + bank_x, cy - 30), (cx - 4 + bank_x, cy + 20)], fill=P40_LIGHT, width=2)

    # Iconic Painted Shark Mouth Nose Art!
    # Red mouth background
    draw.polygon([
        (cx - 6 + bank_x, cy - 28),
        (cx + 6 + bank_x, cy - 28),
        (cx + 4 + bank_x, cy - 22),
        (cx - 4 + bank_x, cy - 22)
    ], fill=P40_MOUTH_RED)
    # Sharp White Jagged Teeth
    for tx in [-4, -1, 2]:
        draw.polygon([
            (cx + tx + bank_x, cy - 28),
            (cx + tx + 2 + bank_x, cy - 28),
            (cx + tx + 1 + bank_x, cy - 25)
        ], fill=P40_TEETH_WHITE)
        draw.polygon([
            (cx + tx + bank_x, cy - 22),
            (cx + tx + 2 + bank_x, cy - 22),
            (cx + tx + 1 + bank_x, cy - 25)
        ], fill=P40_TEETH_WHITE)
    # Shark Eye
    draw.ellipse([cx - 6 + bank_x, cy - 31, cx - 3 + bank_x, cy - 28], fill=(255, 255, 255, 255))
    draw.point((cx - 5 + bank_x, cy - 30), fill=(0, 0, 0, 255))
    draw.ellipse([cx + 3 + bank_x, cy - 31, cx + 6 + bank_x, cy - 28], fill=(255, 255, 255, 255))
    draw.point((cx + 4 + bank_x, cy - 30), fill=(0, 0, 0, 255))

    # Spinner & Propeller
    draw.polygon([(cx - 3 + bank_x, cy - 35), (cx + 3 + bank_x, cy - 35), (cx + bank_x, cy - 40)], fill=US_RED)
    draw.ellipse([cx - 17 + bank_x, cy - 41, cx + 17 + bank_x, cy - 35], fill=PROP_BLUR)

    # Cockpit
    draw.polygon([
        (cx - 4 + bank_x, cy - 18),
        (cx + 4 + bank_x, cy - 18),
        (cx + 5 + bank_x, cy - 4),
        (cx - 5 + bank_x, cy - 4)
    ], fill=GLASS_CYAN, outline=P40_OUTLINE)

    # Tailplane
    draw.rectangle([cx - 16 + bank_x // 2, cy + 26, cx + 16 + bank_x // 2, cy + 31], fill=P40_BODY, outline=P40_OUTLINE)

    return img

def build_enemy_warhawk_sheet():
    frames = {
        "fly_0": render_warhawk_frame("level", 0),
        "fly_1": render_warhawk_frame("level", 1),
        "bank_left": render_warhawk_frame("left"),
        "bank_right": render_warhawk_frame("right")
    }
    pack_sheet(frames, cell_w=96, cell_h=96, cols=4, out_name="sheet_enemy_warhawk")

# =============================================================================
# 3. USAAF B-17 / B-25 HEAVY BOMBER (192x160)
# =============================================================================
def render_b17_frame(state="level", damaged=False):
    w, h = 192, 160
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    # Giant Straight-Tapered Wings
    wing = [
        (cx - 90, cy + 6),
        (cx - 30, cy - 14),
        (cx + 30, cy - 14),
        (cx + 90, cy + 6),
        (cx + 78, cy + 26),
        (cx - 78, cy + 26)
    ]
    draw.polygon(wing, fill=B17_BODY, outline=B17_OUTLINE)
    draw.line([(cx - 86, cy + 8), (cx + 86, cy + 8)], fill=B17_LIGHT, width=2)

    # US Star insignias on wings
    for sx in [-60, 60]:
        draw.rectangle([cx + sx - 10, cy + 10, cx + sx + 10, cy + 18], fill=US_STAR_WHITE)
        draw.ellipse([cx + sx - 7, cy + 7, cx + sx + 7, cy + 21], fill=US_STAR_BLUE)
        draw.polygon([(cx + sx, cy + 9), (cx + sx + 4, cy + 18), (cx + sx - 4, cy + 18)], fill=US_STAR_WHITE)

    # 4 Wright Cyclone Radial Engine Nacelles
    engines = [-64, -36, 36, 64]
    for ex in engines:
        nx = cx + ex
        draw.rectangle([nx - 8, cy - 36, nx + 8, cy + 26], fill=B17_BODY, outline=B17_OUTLINE)
        draw.line([(nx - 4, cy - 32), (nx - 4, cy + 22)], fill=B17_LIGHT, width=2)
        draw.ellipse([nx - 18, cy - 42, nx + 18, cy - 34], fill=PROP_BLUR)

        if damaged and ex == -64:
            draw.ellipse([nx - 9, cy - 12, nx + 9, cy + 10], fill=(255, 120, 20, 230))
            draw.ellipse([nx - 15, cy + 8, nx + 15, cy + 42], fill=(45, 45, 50, 210))

    # Fuselage
    fuse = [
        (cx - 13, cy - 54),
        (cx + 13, cy - 54),
        (cx + 15, cy + 38),
        (cx + 4, cy + 66),
        (cx - 4, cy + 66),
        (cx - 15, cy + 38)
    ]
    draw.polygon(fuse, fill=B17_BODY, outline=B17_OUTLINE)
    draw.line([(cx - 8, cy - 50), (cx - 8, cy + 46)], fill=B17_LIGHT, width=2)

    # Glazed Greenhouse Nose & Cockpit
    draw.polygon([(cx - 8, cy - 52), (cx + 8, cy - 52), (cx + 10, cy - 30), (cx - 10, cy - 30)], 
                 fill=GLASS_CYAN, outline=B17_OUTLINE)
    draw.line([(cx - 2, cy - 48), (cx - 2, cy - 34)], fill=(255, 255, 255, 200), width=1)

    # Dorsal Sperry Machine Gun Turret
    draw.ellipse([cx - 8, cy - 6, cx + 8, cy + 10], fill=GLASS_CYAN, outline=B17_OUTLINE)
    draw.line([(cx - 2, cy - 2), (cx - 2, cy - 12)], fill=(30, 30, 30, 255), width=2)
    draw.line([(cx + 2, cy - 2), (cx + 2, cy - 12)], fill=(30, 30, 30, 255), width=2)

    # Broad Tailplane & Vertical Stabilizer
    draw.polygon([(cx - 38, cy + 50), (cx + 38, cy + 50), (cx + 30, cy + 62), (cx - 30, cy + 62)], 
                 fill=B17_BODY, outline=B17_OUTLINE)

    return img

def build_enemy_b17_sheet():
    frames = {
        "fly_0": render_b17_frame("level", damaged=False),
        "fly_1": render_b17_frame("level", damaged=False),
        "damaged_engine": render_b17_frame("level", damaged=True)
    }
    pack_sheet(frames, cell_w=192, cell_h=160, cols=3, out_name="sheet_enemy_b17")

# =============================================================================
# 4. USAAF B-29 SUPERFORTRESS "GOLIATH" BOSS (384x256)
# =============================================================================
def render_goliath_frame(damage_stage=0):
    w, h = 384, 256
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    # Colossal High-Aspect Ratio Wings (span 360px)
    wing = [
        (cx - 180, cy + 8),
        (cx - 56, cy - 26),
        (cx + 56, cy - 26),
        (cx + 180, cy + 8),
        (cx + 160, cy + 46),
        (cx - 160, cy + 46)
    ]
    draw.polygon(wing, fill=GOLIATH_BODY, outline=GOLIATH_OUTLINE)
    draw.line([(cx - 176, cy + 12), (cx + 176, cy + 12)], fill=GOLIATH_LIGHT, width=3)

    # USAAF Star Insignias on Outer Wings
    for sx in [-125, 125]:
        draw.rectangle([cx + sx - 16, cy + 14, cx + sx + 16, cy + 28], fill=US_STAR_WHITE)
        draw.rectangle([cx + sx - 14, cy + 18, cx + sx + 14, cy + 24], fill=US_RED)
        draw.ellipse([cx + sx - 11, cy + 9, cx + sx + 11, cy + 33], fill=US_STAR_BLUE)
        draw.polygon([(cx + sx, cy + 12), (cx + sx + 7, cy + 28), (cx + sx - 7, cy + 28)], fill=US_STAR_WHITE)

    # 4 Wright R-3350 Duplex-Cyclone Turbo-Supercharged Engines
    engines = [-120, -72, 72, 120]
    for ex in engines:
        nx = cx + ex
        draw.rectangle([nx - 12, cy - 48, nx + 12, cy + 38], fill=GOLIATH_BODY, outline=GOLIATH_OUTLINE)
        draw.line([(nx - 6, cy - 44), (nx - 6, cy + 32)], fill=GOLIATH_LIGHT, width=2)
        draw.ellipse([nx - 28, cy - 56, nx + 28, cy - 46], fill=PROP_BLUR)

        # Stage 1: Port outer engine burning
        if damage_stage >= 1 and ex == -120:
            draw.ellipse([nx - 12, cy - 20, nx + 12, cy + 2], fill=(255, 120, 20, 240))
            draw.ellipse([nx - 18, cy - 2, nx + 18, cy + 36], fill=(40, 40, 48, 220))

        # Stage 2: Starboard outer engine exploding
        if damage_stage >= 2 and ex == 120:
            draw.ellipse([nx - 14, cy - 24, nx + 14, cy + 6], fill=(255, 70, 20, 250))
            draw.ellipse([nx - 22, cy + 2, nx + 22, cy + 44], fill=(30, 30, 36, 230))

    # Sleek Pressurized Cylindrical Fuselage
    fuse = [
        (cx - 26, cy - 94),
        (cx + 26, cy - 94),
        (cx + 28, cy + 58),
        (cx + 10, cy + 112),
        (cx - 10, cy + 112),
        (cx - 28, cy + 58)
    ]
    draw.polygon(fuse, fill=GOLIATH_BODY, outline=GOLIATH_OUTLINE)
    draw.line([(cx - 16, cy - 88), (cx - 16, cy + 86)], fill=GOLIATH_LIGHT, width=3)

    # Pressurized Stepless Greenhouse Nose Glass
    draw.polygon([
        (cx - 18, cy - 92),
        (cx + 18, cy - 92),
        (cx + 22, cy - 64),
        (cx - 22, cy - 64)
    ], fill=GLASS_CYAN, outline=GOLIATH_OUTLINE)
    # Glass framing ribs
    draw.line([(cx, cy - 92), (cx, cy - 64)], fill=GOLIATH_OUTLINE, width=2)
    draw.line([(cx - 10, cy - 80), (cx + 10, cy - 80)], fill=GOLIATH_OUTLINE, width=1)
    draw.line([(cx - 6, cy - 88), (cx - 6, cy - 68)], fill=(255, 255, 255, 210), width=1)

    # 4 Remote-Controlled Defensive Gun Barbettes (Forward & Aft Upper/Lower)
    # Forward Upper Turret
    draw.ellipse([cx - 12, cy - 38, cx + 12, cy - 14], fill=GOLIATH_SHADOW, outline=GOLIATH_OUTLINE)
    draw.line([(cx - 3, cy - 26), (cx - 3, cy - 44)], fill=(20, 20, 22, 255), width=2)
    draw.line([(cx + 3, cy - 26), (cx + 3, cy - 44)], fill=(20, 20, 22, 255), width=2)

    # Aft Upper Turret
    draw.ellipse([cx - 12, cy + 18, cx + 12, cy + 42], fill=GOLIATH_SHADOW, outline=GOLIATH_OUTLINE)
    draw.line([(cx - 4, cy + 30), (cx - 14, cy + 14)], fill=(20, 20, 22, 255), width=2)
    draw.line([(cx + 4, cy + 30), (cx + 14, cy + 14)], fill=(20, 20, 22, 255), width=2)

    # Tail Gunner Cockpit & Twin 20mm Cannons
    draw.polygon([(cx - 8, cy + 96), (cx + 8, cy + 96), (cx + 6, cy + 112), (cx - 6, cy + 112)], 
                 fill=GLASS_CYAN, outline=GOLIATH_OUTLINE)
    draw.line([(cx - 2, cy + 112), (cx - 2, cy + 124)], fill=(20, 20, 22, 255), width=2)
    draw.line([(cx + 2, cy + 112), (cx + 2, cy + 124)], fill=(20, 20, 22, 255), width=2)

    # Large Swept Vertical Stabilizer & Tailplane
    draw.polygon([(cx - 68, cy + 86), (cx + 68, cy + 86), (cx + 52, cy + 108), (cx - 52, cy + 108)], 
                 fill=GOLIATH_BODY, outline=GOLIATH_OUTLINE)

    # Stage 2: Massive Fuselage & Wing Fire
    if damage_stage >= 2:
        draw.ellipse([cx - 24, cy - 45, cx + 24, cy - 5], fill=(255, 60, 20, 240))
        draw.ellipse([cx - 36, cy - 15, cx + 36, cy + 45], fill=(30, 30, 36, 230))
        draw.ellipse([cx + 50, cy - 10, cx + 90, cy + 30], fill=(255, 140, 30, 220))

    return img

def build_boss_goliath_sheet():
    frames = {
        "pristine": render_goliath_frame(damage_stage=0),
        "wing_damaged": render_goliath_frame(damage_stage=1),
        "critical_wreck": render_goliath_frame(damage_stage=2)
    }
    pack_sheet(frames, cell_w=384, cell_h=256, cols=3, out_name="sheet_boss_goliath")

def main():
    print("=== GENERATING ALLIED ENEMY SPRITE SHEETS FOR DUAL-FACTION PLAY ===")
    build_enemy_hellcat_sheet()
    build_enemy_warhawk_sheet()
    build_enemy_b17_sheet()
    build_boss_goliath_sheet()
    print("=== ALLIED FLEET SPRITESHEETS SUCCESSFULLY GENERATED ===")

if __name__ == "__main__":
    main()

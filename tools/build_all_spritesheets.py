#!/usr/bin/env python3
"""
Sky Ace • Master High-Resolution Sprite Sheet Generator
Generates consistent, high-resolution sprite sheets (1 plane/object per sheet):
1. sheet_player_p38.png (128x128 cells) - Level, banking, 6-stage loop-the-loop, damaged
2. sheet_escort.png (64x64 cells) - Mini-fighter wingman flight and banking
3. sheet_enemy_zero.png (96x96 cells) - Green scout fighter angles & turns
4. sheet_enemy_red.png (96x96 cells) - Red Squadron interceptor angles & turns
5. sheet_enemy_bomber.png (192x160 cells) - Heavy twin-engine bomber, turrets, damaged
6. sheet_boss_ayako.png (384x256 cells) - Giant fortress super-bomber with damage phases
7. sheet_carrier.png (256x512 cells) - Aircraft carrier flight deck, catapult & landing
8. sheet_flak_turret.png (64x64 cells) - Island AA guns in 8 rotational angles
9. sheet_fx.png (96x96 cells) - Bullets, flak bursts, 6-frame explosions, water wakes
10. sheet_pickups.png (64x64 cells) - [POW], [WING], [LOOP], [BOMB] badges and medals

Each sheet is accompanied by a JSON metadata atlas defining frame names and coordinates.
"""

import math
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

SPRITES_DIR = Path("games/skyace/sprites")
SPRITES_DIR.mkdir(parents=True, exist_ok=True)

C_TRANS = (0, 0, 0, 0)

# =============================================================================
# COLOR PALETTES
# =============================================================================
# P-38 Lightning (USAAF Olive Drab / Steel / Titanium)
P38_BODY = (78, 102, 75, 255)
P38_LIGHT = (116, 146, 112, 255)
P38_SHADOW = (46, 62, 44, 255)
P38_OUTLINE = (24, 34, 22, 255)
P38_CANOPY = (145, 220, 255, 240)
P38_CANOPY_DARK = (45, 110, 160, 255)
P38_PROP_BLUR = (245, 215, 65, 180)
P38_STAR_WHITE = (245, 245, 250, 255)
P38_STAR_BLUE = (25, 55, 135, 255)

# Green Zero Scout
ZERO_BODY = (48, 88, 58, 255)
ZERO_LIGHT = (76, 126, 86, 255)
ZERO_SHADOW = (28, 56, 35, 255)
ZERO_OUTLINE = (18, 34, 22, 255)
ZERO_ROUNDEL = (215, 30, 30, 255)
ZERO_YELLOW = (245, 205, 45, 255)

# Red Squadron Interceptor
RED_BODY = (220, 35, 35, 255)
RED_LIGHT = (255, 80, 80, 255)
RED_SHADOW = (145, 18, 18, 255)
RED_OUTLINE = (85, 10, 10, 255)
RED_WHITE = (250, 250, 250, 255)

# Heavy Bomber
BOMB_BODY = (85, 80, 70, 255)
BOMB_LIGHT = (122, 115, 102, 255)
BOMB_SHADOW = (52, 48, 42, 255)
BOMB_OUTLINE = (30, 28, 24, 255)

# Boss Ayako Fortress
BOSS_BODY = (66, 70, 76, 255)
BOSS_LIGHT = (98, 104, 114, 255)
BOSS_SHADOW = (40, 42, 48, 255)
BOSS_OUTLINE = (22, 24, 28, 255)
BOSS_RED = (200, 30, 30, 255)

# =============================================================================
# HELPER: PACK FRAMES INTO UNIFORM SPRITESHEET
# =============================================================================
def pack_sheet(frames_dict, cell_w, cell_h, cols, out_name):
    """Packs a dictionary of {name: Image} into a grid sheet and saves JSON atlas."""
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
        
        # Center image in cell if smaller
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
    print(f"✓ Saved {out_name} ({sheet_w}x{sheet_h}, {count} frames) -> {img_path.name}")
    return sheet

# =============================================================================
# 1. PLAYER: P-38 LIGHTNING (HIGH RES 128x128)
# =============================================================================
def render_p38_frame(state="level", prop_phase=0, scale=1.0, damaged=False):
    w, h = 128, 128
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    bank = -6 if state == "bank_left" else (6 if state == "bank_right" else 0)
    wing_tilt = -3 if state == "bank_left" else (3 if state == "bank_right" else 0)

    # 1. Main Wings (span 96px, chord 14px)
    wing_poly = [
        (cx - 48, cy - 4 + wing_tilt),
        (cx + 48, cy - 4 - wing_tilt),
        (cx + 46, cy + 8 - wing_tilt),
        (cx - 46, cy + 8 + wing_tilt)
    ]
    draw.polygon(wing_poly, fill=P38_BODY, outline=P38_OUTLINE)
    draw.line([(cx - 46, cy - 2 + wing_tilt), (cx + 46, cy - 2 - wing_tilt)], fill=P38_LIGHT, width=2)
    # Wingtips (Yellow combat markings)
    draw.rectangle([cx - 48, cy - 4 + wing_tilt, cx - 42, cy + 8 + wing_tilt], fill=P38_PROP_BLUR)
    draw.rectangle([cx + 42, cy - 4 - wing_tilt, cx + 48, cy + 8 - wing_tilt], fill=P38_PROP_BLUR)

    # USAAF Star Insignia on port wing
    draw.ellipse([cx - 34, cy - 2 + wing_tilt, cx - 18, cy + 6 + wing_tilt], fill=P38_STAR_BLUE)
    draw.polygon([(cx - 26, cy - 2 + wing_tilt), (cx - 22, cy + 6 + wing_tilt), (cx - 30, cy + 6 + wing_tilt)], fill=P38_STAR_WHITE)

    # 2. Twin Engine Booms (Left and Right)
    for sign in [-1, 1]:
        bx = cx + sign * 24 + bank // 2
        # Engine Nacelle / Boom
        draw.rectangle([bx - 6, cy - 32, bx + 6, cy + 36], fill=P38_BODY, outline=P38_OUTLINE)
        hl_x = bx + (2 if sign > 0 else -2)
        draw.line([(hl_x, cy - 28), (hl_x, cy + 32)], fill=P38_LIGHT, width=2)
        # Supercharger intake louvers
        draw.rectangle([bx - 2, cy - 4, bx + 2, cy + 6], fill=P38_SHADOW)
        
        # Twin Tail Rudders (Vertical fins)
        rudder = [
            (bx - 4 + bank // 2, cy + 28),
            (bx + 4 + bank // 2, cy + 28),
            (bx + 6 + bank, cy + 44),
            (bx - 6 + bank, cy + 44)
        ]
        draw.polygon(rudder, fill=P38_SHADOW, outline=P38_OUTLINE)
        draw.line([(bx - 2 + bank, cy + 30), (bx - 2 + bank, cy + 42)], fill=P38_LIGHT, width=2)

        # Spinning Propeller Disc
        prop_y = cy - 34
        rx = 14 + (2 if prop_phase == 1 else 0)
        draw.ellipse([bx - rx, prop_y - 4, bx + rx, prop_y + 4], fill=P38_PROP_BLUR)
        draw.ellipse([bx - 3, prop_y - 4, bx + 3, prop_y + 4], fill=P38_SHADOW)

    # 3. Horizontal Stabilizer connecting twin rudders
    draw.rectangle([cx - 26 + bank // 2, cy + 36, cx + 26 + bank // 2, cy + 42], fill=P38_BODY, outline=P38_OUTLINE)

    # 4. Central Fuselage Pod (Cockpit, Nose Cannons)
    center = [
        (cx - 8 + bank, cy - 36),
        (cx + 8 + bank, cy - 36),
        (cx + 10 + bank, cy - 12),
        (cx + 8 + bank, cy + 16),
        (cx - 8 + bank, cy + 16),
        (cx - 10 + bank, cy - 12)
    ]
    draw.polygon(center, fill=P38_BODY, outline=P38_OUTLINE)
    draw.line([(cx - 4 + bank, cy - 32), (cx - 4 + bank, cy + 12)], fill=P38_LIGHT, width=2)

    # Nose Armament: 4x .50 Browning Machine Guns + 20mm Hispano Cannon
    draw.rectangle([cx - 4 + bank, cy - 40, cx + 4 + bank, cy - 36], fill=(30, 30, 30, 255))
    draw.point((cx + bank, cy - 41), fill=(255, 255, 255, 255))

    # Teardrop Glass Canopy with specular glare
    canopy = [
        (cx - 4 + bank, cy - 24),
        (cx + 4 + bank, cy - 24),
        (cx + 6 + bank, cy - 4),
        (cx - 6 + bank, cy - 4)
    ]
    draw.polygon(canopy, fill=P38_CANOPY, outline=P38_CANOPY_DARK)
    draw.line([(cx - 2 + bank, cy - 20), (cx - 2 + bank, cy - 6)], fill=(255, 255, 255, 220), width=2)

    # Damaged smoke/fire effects
    if damaged:
        draw.ellipse([cx - 28, cy - 10, cx - 18, cy + 10], fill=(255, 100, 20, 220))
        draw.ellipse([cx - 32, cy + 8, cx - 14, cy + 32], fill=(50, 50, 55, 190))

    return img

def render_p38_loop_stage(stage):
    """
    Renders the 6 loop stages:
    1: Pitch up 45°
    2: Pure vertical climb 90°
    3: Inverted 180° apex (scaled up 1.3x high altitude)
    4: Vertical dive 270°
    5: Pull out 315°
    6: Level recovery 360°
    """
    w, h = 128, 128
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    if stage == 1:
        # Pulling Up 45°: Foreshortened wings, dominant nose
        draw.rectangle([cx - 44, cy - 2, cx + 44, cy + 6], fill=P38_BODY, outline=P38_OUTLINE)
        for sign in [-1, 1]:
            bx = cx + sign * 22
            draw.rectangle([bx - 6, cy - 24, bx + 6, cy + 24], fill=P38_BODY, outline=P38_OUTLINE)
            draw.ellipse([bx - 12, cy - 28, bx + 12, cy - 20], fill=P38_PROP_BLUR)
        draw.polygon([(cx - 8, cy - 32), (cx + 8, cy - 32), (cx + 10, cy + 10), (cx - 10, cy + 10)], 
                     fill=P38_LIGHT, outline=P38_OUTLINE)
        draw.rectangle([cx - 4, cy - 20, cx + 4, cy - 4], fill=P38_CANOPY)

    elif stage == 2:
        # Pure Vertical Climb 90°: Edge-on profile, flashing prop blur
        draw.rectangle([cx - 48, cy - 4, cx + 48, cy + 4], fill=P38_LIGHT, outline=P38_OUTLINE)
        for sign in [-1, 1]:
            bx = cx + sign * 22
            draw.rectangle([bx - 6, cy - 10, bx + 6, cy + 12], fill=P38_SHADOW, outline=P38_OUTLINE)
            draw.ellipse([bx - 14, cy - 12, bx + 14, cy - 4], fill=P38_PROP_BLUR)
        draw.rectangle([cx - 8, cy - 14, cx + 8, cy + 14], fill=P38_SHADOW, outline=P38_OUTLINE)

    elif stage == 3:
        # Inverted 180° Apex: Belly visible, enlarged high-altitude perspective
        base = render_p38_frame("level")
        inverted = base.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        scaled = inverted.resize((150, 150), Image.Resampling.BILINEAR)
        img.paste(scaled, ((w - 150) // 2, (h - 150) // 2), scaled)
        d = ImageDraw.Draw(img)
        d.line([(cx - 30, cy - 15), (cx + 30, cy + 15)], fill=(255, 255, 255, 160), width=3)

    elif stage == 4:
        # Vertical Dive 270°: Nose straight down, tails high
        draw.rectangle([cx - 48, cy - 3, cx + 48, cy + 4], fill=P38_SHADOW, outline=P38_OUTLINE)
        for sign in [-1, 1]:
            bx = cx + sign * 22
            draw.rectangle([bx - 6, cy - 12, bx + 6, cy + 14], fill=P38_BODY, outline=P38_OUTLINE)
            draw.ellipse([bx - 14, cy + 8, bx + 14, cy + 16], fill=P38_PROP_BLUR)
        draw.polygon([(cx - 8, cy - 16), (cx + 8, cy - 16), (cx + 6, cy + 24), (cx - 6, cy + 24)], 
                     fill=P38_BODY, outline=P38_OUTLINE)

    elif stage == 5:
        # Pulling out 315°
        base = render_p38_frame("level")
        scaled = base.resize((115, 115), Image.Resampling.BILINEAR)
        img.paste(scaled, ((w - 115) // 2, (h - 115) // 2 + 6), scaled)

    elif stage == 6:
        # Resuming level flight
        img = render_p38_frame("level")

    return img

def build_p38_sheet():
    frames = {
        "fly_0": render_p38_frame("level", prop_phase=0),
        "fly_1": render_p38_frame("level", prop_phase=1),
        "bank_left": render_p38_frame("bank_left"),
        "bank_right": render_p38_frame("bank_right"),
        "loop_1": render_p38_loop_stage(1),
        "loop_2": render_p38_loop_stage(2),
        "loop_3": render_p38_loop_stage(3),
        "loop_4": render_p38_loop_stage(4),
        "loop_5": render_p38_loop_stage(5),
        "loop_6": render_p38_loop_stage(6),
        "damaged_0": render_p38_frame("level", damaged=True),
        "damaged_1": render_p38_frame("bank_left", damaged=True)
    }
    pack_sheet(frames, cell_w=128, cell_h=128, cols=4, out_name="sheet_player_p38")

# =============================================================================
# 2. ESCORT WINGMAN (64x64)
# =============================================================================
def render_escort_frame(state="level", prop=0):
    w, h = 64, 64
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2
    tilt = -2 if state == "left" else (2 if state == "right" else 0)

    # Wings
    draw.rectangle([cx - 24, cy - 2 + tilt, cx + 24, cy + 4 - tilt], fill=P38_BODY, outline=P38_OUTLINE)
    draw.line([(cx - 22, cy - 1 + tilt), (cx + 22, cy - 1 - tilt)], fill=P38_LIGHT)
    # Twin Booms
    for bx in [-12, 12]:
        draw.rectangle([cx + bx - 3, cy - 16, cx + bx + 3, cy + 18], fill=P38_BODY, outline=P38_OUTLINE)
        draw.line([cx + bx - 7, cy - 17, cx + bx + 7, cy - 17], fill=P38_PROP_BLUR, width=2)
    # Center Pod
    draw.rectangle([cx - 4, cy - 18, cx + 4, cy + 8], fill=P38_LIGHT, outline=P38_OUTLINE)
    draw.rectangle([cx - 2, cy - 10, cx + 2, cy - 2], fill=P38_CANOPY)
    return img

def build_escort_sheet():
    frames = {
        "fly_0": render_escort_frame("level", 0),
        "fly_1": render_escort_frame("level", 1),
        "bank_left": render_escort_frame("left"),
        "bank_right": render_escort_frame("right")
    }
    pack_sheet(frames, cell_w=64, cell_h=64, cols=4, out_name="sheet_escort")

# =============================================================================
# 3. ENEMY ZERO SCOUT & 4. RED SQUADRON (96x96)
# =============================================================================
def render_fighter_frame(color_type="zero", state="level"):
    w, h = 96, 96
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    c_body = RED_BODY if color_type == "red" else ZERO_BODY
    c_light = RED_LIGHT if color_type == "red" else ZERO_LIGHT
    c_shadow = RED_SHADOW if color_type == "red" else ZERO_SHADOW
    c_outline = RED_OUTLINE if color_type == "red" else ZERO_OUTLINE

    bank_x = -4 if state == "left" else (4 if state == "right" else 0)
    wing_tilt = -4 if state == "left" else (4 if state == "right" else 0)

    # Elliptical Wings
    wing = [
        (cx - 40, cy + 2 + wing_tilt),
        (cx - 16, cy - 8 + wing_tilt // 2),
        (cx + 16, cy - 8 - wing_tilt // 2),
        (cx + 40, cy + 2 - wing_tilt),
        (cx + 34, cy + 12 - wing_tilt),
        (cx - 34, cy + 12 + wing_tilt)
    ]
    draw.polygon(wing, fill=c_body, outline=c_outline)
    draw.line([(cx - 38, cy + 2 + wing_tilt), (cx + 38, cy + 2 - wing_tilt)], fill=c_light, width=2)

    # Roundels / Markings
    accent = RED_WHITE if color_type == "red" else ZERO_ROUNDEL
    draw.ellipse([cx - 32, cy + 2 + wing_tilt, cx - 22, cy + 10 + wing_tilt], fill=accent)
    draw.ellipse([cx + 22, cy + 2 - wing_tilt, cx + 32, cy + 10 - wing_tilt], fill=accent)

    # Fuselage
    fuse = [
        (cx - 8 + bank_x, cy - 32),
        (cx + 8 + bank_x, cy - 32),
        (cx + 8 + bank_x, cy + 24),
        (cx + bank_x, cy + 36),
        (cx - 8 + bank_x, cy + 24)
    ]
    draw.polygon(fuse, fill=c_body, outline=c_outline)
    draw.line([(cx - 4 + bank_x, cy - 28), (cx - 4 + bank_x, cy + 20)], fill=c_light, width=2)

    # Engine Cowling & Spinning Propeller
    draw.rectangle([cx - 8 + bank_x, cy - 34, cx + 8 + bank_x, cy - 28], fill=(35, 35, 40, 255))
    draw.ellipse([cx - 16 + bank_x, cy - 38, cx + 16 + bank_x, cy - 32], fill=P38_PROP_BLUR)

    # Cockpit Glass
    draw.polygon([
        (cx - 4 + bank_x, cy - 16),
        (cx + 4 + bank_x, cy - 16),
        (cx + 6 + bank_x, cy - 2),
        (cx - 6 + bank_x, cy - 2)
    ], fill=(140, 220, 255, 230), outline=c_outline)

    # Horizontal Tailplane
    draw.rectangle([cx - 18 + bank_x // 2, cy + 26, cx + 18 + bank_x // 2, cy + 32], fill=c_body, outline=c_outline)
    return img

def build_enemy_zero_sheet():
    frames = {
        "fly_0": render_fighter_frame("zero", "level"),
        "fly_1": render_fighter_frame("zero", "level"),
        "bank_left": render_fighter_frame("zero", "left"),
        "bank_right": render_fighter_frame("zero", "right")
    }
    pack_sheet(frames, cell_w=96, cell_h=96, cols=4, out_name="sheet_enemy_zero")

def build_enemy_red_sheet():
    frames = {
        "fly_0": render_fighter_frame("red", "level"),
        "fly_1": render_fighter_frame("red", "level"),
        "bank_left": render_fighter_frame("red", "left"),
        "bank_right": render_fighter_frame("red", "right")
    }
    pack_sheet(frames, cell_w=96, cell_h=96, cols=4, out_name="sheet_enemy_red")

# =============================================================================
# 5. HEAVY BOMBER (192x160)
# =============================================================================
def render_bomber_frame(state="level", damaged=False):
    w, h = 192, 160
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    # Broad Heavy Wings
    wing = [
        (cx - 88, cy + 4),
        (cx - 32, cy - 12),
        (cx + 32, cy - 12),
        (cx + 88, cy + 4),
        (cx + 76, cy + 24),
        (cx - 76, cy + 24)
    ]
    draw.polygon(wing, fill=BOMB_BODY, outline=BOMB_OUTLINE)
    draw.line([(cx - 84, cy + 6), (cx + 84, cy + 6)], fill=BOMB_LIGHT, width=2)

    # Red Roundels on wings
    draw.ellipse([cx - 68, cy + 6, cx - 48, cy + 20], fill=ZERO_ROUNDEL)
    draw.ellipse([cx + 48, cy + 6, cx + 68, cy + 20], fill=ZERO_ROUNDEL)

    # Twin Radial Engine Nacelles
    for sign in [-1, 1]:
        nx = cx + sign * 44
        draw.rectangle([nx - 10, cy - 36, nx + 10, cy + 28], fill=BOMB_BODY, outline=BOMB_OUTLINE)
        draw.line([(nx - 6, cy - 32), (nx - 6, cy + 24)], fill=BOMB_LIGHT, width=2)
        draw.ellipse([nx - 22, cy - 44, nx + 22, cy - 36], fill=P38_PROP_BLUR)

        if damaged and sign == -1:
            draw.ellipse([nx - 8, cy - 10, nx + 8, cy + 10], fill=(255, 120, 20, 230))
            draw.ellipse([nx - 14, cy + 10, nx + 14, cy + 40], fill=(45, 45, 50, 200))

    # Fuselage
    fuse = [
        (cx - 12, cy - 52),
        (cx + 12, cy - 52),
        (cx + 14, cy + 40),
        (cx + 4, cy + 64),
        (cx - 4, cy + 64),
        (cx - 14, cy + 40)
    ]
    draw.polygon(fuse, fill=BOMB_BODY, outline=BOMB_OUTLINE)
    draw.line([(cx - 8, cy - 48), (cx - 8, cy + 48)], fill=BOMB_LIGHT, width=2)

    # Greenhouse Nose Canopy & Dorsal Turret
    draw.polygon([(cx - 8, cy - 50), (cx + 8, cy - 50), (cx + 10, cy - 28), (cx - 10, cy - 28)], 
                 fill=(130, 210, 245, 220), outline=BOMB_OUTLINE)
    draw.ellipse([cx - 8, cy - 4, cx + 8, cy + 12], fill=(130, 210, 245, 240), outline=BOMB_OUTLINE)
    draw.line([(cx, cy + 2), (cx, cy - 10)], fill=(30, 30, 30, 255), width=3)

    # Tail Stabilizers
    draw.polygon([(cx - 36, cy + 48), (cx + 36, cy + 48), (cx + 28, cy + 60), (cx - 28, cy + 60)], 
                 fill=BOMB_BODY, outline=BOMB_OUTLINE)
    return img

def build_enemy_bomber_sheet():
    frames = {
        "fly_0": render_bomber_frame("level", damaged=False),
        "fly_1": render_bomber_frame("level", damaged=False),
        "damaged_engine": render_bomber_frame("level", damaged=True)
    }
    pack_sheet(frames, cell_w=192, cell_h=160, cols=3, out_name="sheet_enemy_bomber")

# =============================================================================
# 6. BOSS: GOLIATH / AYAKO SUPER FORTRESS (384x256)
# =============================================================================
def render_boss_frame(damage_stage=0):
    w, h = 384, 256
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    # Enormous Swept Wings (span 360px)
    wing = [
        (cx - 180, cy + 12),
        (cx - 60, cy - 28),
        (cx + 60, cy - 28),
        (cx + 180, cy + 12),
        (cx + 156, cy + 52),
        (cx - 156, cy + 52)
    ]
    draw.polygon(wing, fill=BOSS_BODY, outline=BOSS_OUTLINE)
    draw.line([(cx - 176, cy + 16), (cx + 176, cy + 16)], fill=BOSS_LIGHT, width=3)


    # 4 Heavy Radial Engine Arrays
    engines = [-124, -76, 76, 124]
    for ex in engines:
        nx = cx + ex
        draw.rectangle([nx - 12, cy - 48, nx + 12, cy + 40], fill=BOSS_BODY, outline=BOSS_OUTLINE)
        draw.line([(nx - 6, cy - 44), (nx - 6, cy + 32)], fill=BOSS_LIGHT, width=2)
        draw.ellipse([nx - 28, cy - 56, nx + 28, cy - 46], fill=P38_PROP_BLUR)

        if damage_stage >= 1 and abs(ex) == 124:
            draw.ellipse([nx - 10, cy - 20, nx + 10, cy], fill=(255, 120, 20, 230))
            draw.ellipse([nx - 16, cy - 4, nx + 16, cy + 30], fill=(40, 40, 45, 210))

    # Center Fortress Fuselage
    fuse = [
        (cx - 28, cy - 92),
        (cx + 28, cy - 92),
        (cx + 32, cy + 60),
        (cx + 12, cy + 108),
        (cx - 12, cy + 108),
        (cx - 32, cy + 60)
    ]
    draw.polygon(fuse, fill=BOSS_BODY, outline=BOSS_OUTLINE)
    draw.line([(cx - 18, cy - 84), (cx - 18, cy + 90)], fill=BOSS_LIGHT, width=3)

    # Nose Machine Cannon Array & Bridge Deck
    draw.polygon([(cx - 16, cy - 90), (cx + 16, cy - 90), (cx + 20, cy - 60), (cx - 20, cy - 60)], 
                 fill=(120, 205, 240, 220), outline=BOSS_OUTLINE)
    draw.rectangle([cx - 4, cy - 100, cx + 4, cy - 90], fill=(20, 20, 20, 255))
    
    # Tail Stabilizers
    draw.polygon([(cx - 72, cy + 84), (cx + 72, cy + 84), (cx + 56, cy + 108), (cx - 56, cy + 108)], 
                 fill=BOSS_BODY, outline=BOSS_OUTLINE)

    if damage_stage >= 2:
        draw.ellipse([cx - 20, cy - 40, cx + 20, cy], fill=(255, 60, 20, 240))
        draw.ellipse([cx - 30, cy - 10, cx + 30, cy + 50], fill=(30, 30, 35, 220))

    return img

def build_boss_ayako_sheet():
    frames = {
        "pristine": render_boss_frame(damage_stage=0),
        "wing_damaged": render_boss_frame(damage_stage=1),
        "critical_wreck": render_boss_frame(damage_stage=2)
    }
    pack_sheet(frames, cell_w=384, cell_h=256, cols=3, out_name="sheet_boss_ayako")

# =============================================================================
# 7. AIRCRAFT CARRIER FLIGHT DECK (256x512)
# =============================================================================
def render_carrier_deck(catapult_steam=False):
    w, h = 256, 512
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx = w // 2

    hull = [
        (cx - 60, 30),
        (cx, 0),
        (cx + 60, 30),
        (cx + 66, h - 40),
        (cx + 58, h),
        (cx - 58, h),
        (cx - 66, h - 40)
    ]
    draw.polygon(hull, fill=(65, 68, 74, 255), outline=(32, 34, 38, 255))
    
    # Wooden deck planks
    for y in range(36, h - 16, 12):
        draw.line([(cx - 56, y), (cx + 56, y)], fill=(75, 78, 85, 255), width=1)

    # Yellow Runway Centerline
    for y in range(60, h - 60, 30):
        draw.rectangle([cx - 3, y, cx + 3, y + 18], fill=(245, 220, 110, 255))

    # Catapult Rails at bow
    draw.line([(cx - 18, 40), (cx - 18, 160)], fill=(30, 32, 35, 255), width=3)
    draw.line([(cx + 18, 40), (cx + 18, 160)], fill=(30, 32, 35, 255), width=3)

    # Arresting Wires at stern
    for cy_w in [h - 100, h - 80, h - 60]:
        draw.line([(cx - 50, cy_w), (cx + 50, cy_w)], fill=(20, 20, 22, 255), width=3)

    # Island Bridge Tower on starboard
    ix, iy = cx + 62, 200
    draw.polygon([(ix - 6, iy - 40), (ix + 18, iy - 32), (ix + 18, iy + 40), (ix - 6, iy + 48)], 
                 fill=(45, 48, 54, 255), outline=(24, 26, 30, 255))
    for wy in range(iy - 28, iy + 28, 12):
        draw.rectangle([ix, wy, ix + 12, wy + 6], fill=(120, 205, 240, 240))
    # Radar Antenna
    draw.line([(ix + 6, iy - 40), (ix + 6, iy - 64)], fill=(30, 32, 36, 255), width=3)
    draw.line([(ix - 2, iy - 58), (ix + 14, iy - 58)], fill=(30, 32, 36, 255), width=3)

    # Steam clouds if launching
    if catapult_steam:
        for sx, sy in [(cx - 18, 60), (cx - 18, 90), (cx + 18, 60), (cx + 18, 90)]:
            draw.ellipse([sx - 12, sy - 12, sx + 12, sy + 12], fill=(255, 255, 255, 140))

    return img

def build_carrier_sheet():
    frames = {
        "deck_idle": render_carrier_deck(catapult_steam=False),
        "deck_launching": render_carrier_deck(catapult_steam=True)
    }
    pack_sheet(frames, cell_w=256, cell_h=512, cols=2, out_name="sheet_carrier")

# =============================================================================
# 8. FLAK TURRETS (64x64)
# =============================================================================
def render_flak_turret_angle(angle_deg):
    w, h = 64, 64
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    # Concrete Bunker Ring
    draw.ellipse([cx - 24, cy - 24, cx + 24, cy + 24], fill=(72, 75, 80, 255), outline=(35, 38, 42, 255), width=2)
    draw.ellipse([cx - 18, cy - 18, cx + 18, cy + 18], fill=(96, 100, 106, 255))

    # Dual Gun Barrels rotated by angle_deg
    rad = math.radians(angle_deg)
    cos_a, sin_a = math.cos(rad), math.sin(rad)
    perp_x, perp_y = -sin_a, cos_a

    barrel_len = 22
    for offset in [-3, 3]:
        bx0 = cx + perp_x * offset
        by0 = cy + perp_y * offset
        bx1 = bx0 + cos_a * barrel_len
        by1 = by0 + sin_a * barrel_len
        draw.line([(bx0, by0), (bx1, by1)], fill=(28, 28, 32, 255), width=3)

    # Turret Shield Mantlet
    draw.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(50, 52, 58, 255), outline=(20, 22, 25, 255))
    return img

def build_flak_sheet():
    angles = [("turret_N", -90), ("turret_NE", -45), ("turret_E", 0), ("turret_SE", 45),
              ("turret_S", 90), ("turret_SW", 135), ("turret_W", 180), ("turret_NW", 225)]
    frames = {name: render_flak_turret_angle(deg) for name, deg in angles}
    pack_sheet(frames, cell_w=64, cell_h=64, cols=4, out_name="sheet_flak_turret")

# =============================================================================
# 9. PROJECTILES & EXPLOSIONS (96x96)
# =============================================================================
def render_bullet_frame(btype):
    w, h = 96, 96
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    if btype == "player_twin":
        for ox in [-6, 6]:
            draw.rounded_rectangle([cx + ox - 3, cy - 16, cx + ox + 3, cy + 16], radius=3, fill=(255, 235, 90, 255))
            draw.rounded_rectangle([cx + ox - 1, cy - 12, cx + ox + 1, cy + 12], radius=1, fill=(255, 255, 255, 255))

    elif btype == "player_quad":
        for ox in [-12, -4, 4, 12]:
            draw.rounded_rectangle([cx + ox - 2, cy - 18, cx + ox + 2, cy + 18], radius=2, fill=(255, 215, 60, 255))
            draw.rounded_rectangle([cx + ox - 1, cy - 14, cx + ox + 1, cy + 14], radius=1, fill=(255, 255, 255, 255))

    elif btype == "enemy_bullet":
        draw.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=(255, 65, 35, 255), outline=(255, 180, 60, 255), width=2)
        draw.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(255, 240, 180, 255))

    elif btype == "flak_burst":
        draw.ellipse([cx - 26, cy - 26, cx + 26, cy + 26], fill=(45, 45, 50, 220))
        draw.ellipse([cx - 16, cy - 16, cx + 16, cy + 16], fill=(25, 25, 30, 240))
        for angle in range(0, 360, 30):
            rad = math.radians(angle)
            sx = cx + math.cos(rad) * 24
            sy = cy + math.sin(rad) * 24
            draw.line([(cx, cy), (sx, sy)], fill=(255, 140, 30, 255), width=3)
            draw.point((sx, sy), fill=(255, 255, 200, 255))

    return img

def render_explosion_frame(stage):
    w, h = 96, 96
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    if stage == 0:
        draw.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], fill=(255, 255, 255, 255))
        for angle in range(0, 360, 45):
            rad = math.radians(angle)
            draw.line([(cx, cy), (cx + math.cos(rad) * 26, cy + math.sin(rad) * 26)], fill=(255, 220, 60, 255), width=3)

    elif stage == 1:
        draw.ellipse([cx - 26, cy - 26, cx + 26, cy + 26], fill=(255, 130, 20, 255))
        draw.ellipse([cx - 16, cy - 16, cx + 16, cy + 16], fill=(255, 235, 80, 255))
        draw.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=(255, 255, 255, 255))

    elif stage == 2:
        draw.ellipse([cx - 38, cy - 38, cx + 38, cy + 38], fill=(225, 40, 20, 240))
        draw.ellipse([cx - 26, cy - 26, cx + 26, cy + 26], fill=(255, 160, 30, 255))
        draw.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], fill=(255, 245, 140, 255))

    elif stage == 3:
        draw.ellipse([cx - 36, cy - 36, cx + 36, cy + 36], fill=(70, 70, 75, 210))
        draw.ellipse([cx - 22, cy - 22, cx + 22, cy + 22], fill=(200, 60, 25, 220))
        draw.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(255, 140, 30, 230))

    elif stage == 4:
        draw.ellipse([cx - 34, cy - 34, cx + 34, cy + 34], fill=(55, 55, 60, 160))
        draw.ellipse([cx - 18, cy - 18, cx + 18, cy + 18], fill=(40, 40, 45, 180))

    elif stage == 5:
        draw.ellipse([cx - 30, cy - 30, cx + 30, cy + 30], fill=(45, 45, 50, 90))

    return img

def build_fx_sheet():
    frames = {
        "bullet_twin": render_bullet_frame("player_twin"),
        "bullet_quad": render_bullet_frame("player_quad"),
        "bullet_enemy": render_bullet_frame("enemy_bullet"),
        "flak_burst": render_bullet_frame("flak_burst"),
        "exp_0": render_explosion_frame(0),
        "exp_1": render_explosion_frame(1),
        "exp_2": render_explosion_frame(2),
        "exp_3": render_explosion_frame(3),
        "exp_4": render_explosion_frame(4),
        "exp_5": render_explosion_frame(5)
    }
    pack_sheet(frames, cell_w=96, cell_h=96, cols=5, out_name="sheet_fx")

# =============================================================================
# 10. POWER-UPS & MEDALS (64x64)
# =============================================================================
def render_badge(label="POW", shimmer=False):
    w, h = 64, 64
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    col = (225, 30, 30, 255)
    if label == "WING": col = (30, 110, 230, 255)
    elif label == "LOOP": col = (235, 165, 20, 255)
    elif label == "BOMB": col = (45, 45, 52, 255)

    # Octagonal Gold/Silver Beveled Capsule
    draw.rounded_rectangle([4, 4, w - 5, h - 5], radius=12, fill=col, outline=(255, 255, 255, 255), width=3)
    draw.line([(10, 10), (w - 11, 10)], fill=(255, 255, 255, 200), width=2)

    if label == "POW":
        # Bold pixel-cut "POW"
        # P
        draw.rectangle([14, 20, 18, 44], fill=(255, 255, 255, 255))
        draw.rectangle([18, 20, 26, 32], fill=(255, 255, 255, 255))
        draw.rectangle([18, 24, 22, 28], fill=col)
        # O
        draw.rectangle([28, 20, 36, 44], fill=(255, 255, 255, 255))
        draw.rectangle([30, 24, 34, 40], fill=col)
        # W
        draw.rectangle([38, 20, 42, 44], fill=(255, 255, 255, 255))
        draw.rectangle([46, 28, 48, 44], fill=(255, 255, 255, 255))
        draw.rectangle([50, 20, 54, 44], fill=(255, 255, 255, 255))
        draw.rectangle([42, 40, 50, 44], fill=(255, 255, 255, 255))

    elif label == "WING":
        draw.polygon([(cx - 20, cy + 8), (cx, cy - 12), (cx + 20, cy + 8), 
                      (cx + 12, cy + 12), (cx, cy), (cx - 12, cy + 12)], fill=(255, 255, 255, 255))

    elif label == "LOOP":
        draw.arc([cx - 16, cy - 16, cx + 16, cy + 16], 45, 315, fill=(255, 255, 255, 255), width=4)
        draw.polygon([(cx + 12, cy - 16), (cx + 20, cy - 8), (cx + 8, cy - 4)], fill=(255, 255, 255, 255))

    elif label == "BOMB":
        draw.ellipse([cx - 12, cy - 6, cx + 12, cy + 18], fill=(255, 60, 20, 255), outline=(255, 255, 255, 255), width=2)
        draw.line([(cx, cy - 6), (cx + 8, cy - 16)], fill=(240, 240, 240, 255), width=3)
        draw.point((cx + 10, cy - 18), fill=(255, 255, 80, 255))

    if shimmer:
        draw.line([(10, h - 14), (w - 14, 10)], fill=(255, 255, 255, 160), width=3)

    return img

def render_medal(tier="gold"):
    w, h = 64, 64
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    c_base = (255, 210, 40, 255) if tier == "gold" else ((220, 225, 230, 255) if tier == "silver" else (210, 135, 65, 255))
    c_rim = (185, 140, 20, 255) if tier == "gold" else ((155, 160, 165, 255) if tier == "silver" else (145, 85, 35, 255))

    # Ribbon
    draw.polygon([(cx - 12, 4), (cx + 12, 4), (cx + 8, 20), (cx - 8, 20)], fill=(220, 30, 30, 255), outline=(140, 20, 20, 255))
    draw.line([(cx, 4), (cx, 20)], fill=(255, 255, 255, 255), width=2)

    # Coin Disc & Star
    draw.ellipse([cx - 18, cy - 4, cx + 18, cy + 28], fill=c_base, outline=c_rim, width=2)
    draw.polygon([(cx, cy + 2), (cx + 6, cy + 18), (cx - 6, cy + 18)], fill=(255, 255, 255, 220))
    return img

def build_pickups_sheet():
    frames = {
        "pow_0": render_badge("POW", False),
        "pow_1": render_badge("POW", True),
        "wing_0": render_badge("WING", False),
        "wing_1": render_badge("WING", True),
        "loop_0": render_badge("LOOP", False),
        "loop_1": render_badge("LOOP", True),
        "bomb_0": render_badge("BOMB", False),
        "bomb_1": render_badge("BOMB", True),
        "medal_gold": render_medal("gold"),
        "medal_silver": render_medal("silver"),
        "medal_bronze": render_medal("bronze")
    }
    pack_sheet(frames, cell_w=64, cell_h=64, cols=4, out_name="sheet_pickups")

# =============================================================================
# MAIN EXECUTION
# =============================================================================
def main():
    print("=== BUILDING HIGH-RES DEDICATED SPRITE SHEETS (1 OBJECT PER SHEET) ===")
    build_p38_sheet()
    build_escort_sheet()
    build_enemy_zero_sheet()
    build_enemy_red_sheet()
    build_enemy_bomber_sheet()
    build_boss_ayako_sheet()
    build_carrier_sheet()
    build_flak_sheet()
    build_fx_sheet()
    build_pickups_sheet()
    print("=== ALL 10 SPRITE SHEETS SUCCESSFULLY GENERATED ===")

if __name__ == "__main__":
    main()

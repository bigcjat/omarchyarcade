#!/usr/bin/env python3
"""
Sky Ace • Custom Pixel & Vector Sprite Generator
Generates all dedicated, original game art assets for Sky Ace (1942 homage):
- Player Lockheed P-38 Lightning (Level, Bank Left, Bank Right, 6 Loop-the-Loop frames, Escort Wingmen)
- Enemy aircraft: Ki-43 / Zero scouts, Red Squadron interceptors, Twin-engine heavy bombers
- Boss: "Goliath" multi-engine Pacific super-bomber with destructible hitboxes
- Naval & Ground: Aircraft carrier flight deck, island atolls with runways, flak turrets
- VFX: 5-frame fiery explosion sequences, flak bursts, tracers, ocean wakes, clouds
- Pickups: Iconic [POW], [WING], [LOOP], [BOMB] badges and Gold Medals
- Master sprite sheet (spritesheet.png) and metadata atlas (spritesheet.json)
- Showcase preview montage (scratch/skyace_art_showcase.png)
"""

import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

OUTPUT_DIR = Path("games/skyace/sprites")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

SHOWCASE_DIR = Path("scratch")
SHOWCASE_DIR.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------------
# COLOR PALETTES (Authentic 1940s Pacific Arcade Tones)
# ---------------------------------------------------------------------------
C_TRANS = (0, 0, 0, 0)

# P-38 Lightning Palette (USAAF Olive Drab / Steel Navy / Aluminum)
C_P38_BODY = (74, 98, 71, 255)         # Classic Olive Drab
C_P38_HIGHLIGHT = (106, 134, 102, 255) # Sunlit top surfaces
C_P38_SHADOW = (48, 64, 46, 255)       # Underside shadow
C_P38_OUTLINE = (28, 38, 27, 255)      # Deep outline
C_P38_CANOPY = (142, 218, 255, 255)    # Glass glare
C_P38_CANOPY_SHADOW = (56, 132, 184, 255)
C_P38_PROP = (245, 210, 60, 160)       # Spinning prop blur yellow
C_P38_STAR = (240, 245, 255, 255)      # USAAF White star
C_P38_STAR_BLUE = (30, 60, 140, 255)   # Star roundel blue

# Green Zero / Scout Palette
C_ZERO_BODY = (45, 85, 55, 255)
C_ZERO_LIGHT = (70, 120, 80, 255)
C_ZERO_SHADOW = (28, 55, 35, 255)
C_ZERO_OUTLINE = (18, 35, 22, 255)
C_ZERO_RED = (210, 35, 35, 255)        # Hinomaru roundel
C_ZERO_YELLOW = (245, 200, 45, 255)

# Red Squadron Palette (High-contrast Scarlet Interceptors)
C_RED_BODY = (220, 40, 40, 255)
C_RED_LIGHT = (255, 85, 85, 255)
C_RED_SHADOW = (150, 20, 20, 255)
C_RED_OUTLINE = (90, 10, 10, 255)
C_RED_WHITE = (255, 255, 255, 255)

# Heavy Bomber Palette (Dark Camo & Rust)
C_BOMB_BODY = (80, 75, 65, 255)
C_BOMB_LIGHT = (115, 108, 95, 255)
C_BOMB_SHADOW = (50, 46, 40, 255)
C_BOMB_OUTLINE = (30, 28, 24, 255)

# Boss Ayako Palette (Imperial Iron Fortress)
C_BOSS_BODY = (68, 72, 78, 255)
C_BOSS_LIGHT = (98, 104, 112, 255)
C_BOSS_SHADOW = (42, 45, 50, 255)
C_BOSS_ACCENT = (195, 35, 35, 255)

# Projectiles & FX
C_BULLET_P = (255, 240, 100, 255)
C_BULLET_P_CORE = (255, 255, 255, 255)
C_BULLET_E = (255, 75, 45, 255)
C_FLAK_SMOKE = (40, 40, 45, 220)
C_FLAK_FIRE = (255, 140, 30, 255)

# Pickups
C_POW_RED = (225, 30, 30, 255)
C_POW_WHITE = (250, 250, 250, 255)
C_GOLD = (255, 205, 35, 255)
C_GOLD_SHADOW = (185, 135, 15, 255)

# Environment
C_OCEAN_DEEP = (18, 54, 96, 255)
C_OCEAN_MID = (24, 76, 128, 255)
C_OCEAN_REEF = (40, 145, 160, 255)
C_SAND = (225, 205, 145, 255)
C_JUNGLE = (35, 105, 45, 255)
C_JUNGLE_DARK = (22, 72, 30, 255)
C_CARRIER_DECK = (65, 68, 72, 255)
C_CARRIER_LINE = (240, 220, 120, 255)

saved_sprites = {}

def register_sprite(name: str, img: Image.Image):
    path = OUTPUT_DIR / f"{name}.png"
    img.save(path, format="PNG", optimize=True)
    saved_sprites[name] = img
    return img

# ===========================================================================
# 1. PLAYER: P-38 LIGHTNING ("SUPER ACE")
# ===========================================================================
def draw_p38(state="level"):
    """
    Renders the twin-boom P-38 Lightning.
    state: "level", "left", "right", "escort"
    """
    w, h = 64, 64
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    if state == "escort":
        w_e, h_e = 32, 32
        img_e = Image.new("RGBA", (w_e, h_e), C_TRANS)
        d_e = ImageDraw.Draw(img_e)
        ecx, ecy = w_e // 2, h_e // 2
        
        # Wings
        d_e.rectangle([ecx - 12, ecy - 1, ecx + 12, ecy + 2], fill=C_P38_BODY, outline=C_P38_OUTLINE)
        # Twin booms
        for bx in [-6, 6]:
            d_e.rectangle([ecx + bx - 1, ecy - 7, ecx + bx + 1, ecy + 9], fill=C_P38_BODY, outline=C_P38_OUTLINE)
            d_e.rectangle([ecx + bx - 1, ecy + 7, ecx + bx + 1, ecy + 10], fill=C_P38_HIGHLIGHT)
            d_e.line([ecx + bx - 3, ecy - 8, ecx + bx + 3, ecy - 8], fill=C_P38_PROP, width=1)
        d_e.rectangle([ecx - 2, ecy - 5, ecx + 2, ecy + 4], fill=C_P38_HIGHLIGHT, outline=C_P38_OUTLINE)
        d_e.rectangle([ecx - 1, ecy - 2, ecx + 1, ecy + 1], fill=C_P38_CANOPY)
        d_e.line([ecx - 6, ecy + 8, ecx + 6, ecy + 8], fill=C_P38_OUTLINE, width=1)
        return img_e

    bank_offset = -3 if state == "left" else (3 if state == "right" else 0)
    wing_slant = -1 if state == "left" else (1 if state == "right" else 0)

    # Wings
    wing_poly = [
        (cx - 24, cy - 2 + wing_slant),
        (cx + 24, cy - 2 - wing_slant),
        (cx + 23, cy + 4 - wing_slant),
        (cx - 23, cy + 4 + wing_slant),
    ]
    draw.polygon(wing_poly, fill=C_P38_BODY, outline=C_P38_OUTLINE)
    draw.line([(cx - 23, cy - 1 + wing_slant), (cx + 23, cy - 1 - wing_slant)], fill=C_P38_HIGHLIGHT, width=1)

    # Yellow wing tips
    draw.rectangle([cx - 24, cy - 2 + wing_slant, cx - 21, cy + 4 + wing_slant], fill=C_P38_PROP)
    draw.rectangle([cx + 21, cy - 2 - wing_slant, cx + 24, cy + 4 - wing_slant], fill=C_P38_PROP)

    # Twin Engine Booms
    for sign in [-1, 1]:
        bx = cx + sign * 12 + bank_offset // 2
        draw.rectangle([bx - 3, cy - 16, bx + 3, cy + 18], fill=C_P38_BODY, outline=C_P38_OUTLINE)
        hl_x = bx + (1 if sign > 0 else -1)
        draw.line([(hl_x, cy - 14), (hl_x, cy + 16)], fill=C_P38_HIGHLIGHT)
        draw.rectangle([bx - 1, cy - 2, bx + 1, cy + 3], fill=C_P38_SHADOW)
        
        rudder_poly = [
            (bx - 2 + bank_offset // 2, cy + 14),
            (bx + 2 + bank_offset // 2, cy + 14),
            (bx + 3 + bank_offset, cy + 22),
            (bx - 3 + bank_offset, cy + 22),
        ]
        draw.polygon(rudder_poly, fill=C_P38_SHADOW, outline=C_P38_OUTLINE)
        draw.line([(bx - 1 + bank_offset, cy + 15), (bx - 1 + bank_offset, cy + 21)], fill=C_P38_HIGHLIGHT)

        # Props
        prop_y = cy - 17
        draw.ellipse([bx - 7, prop_y - 2, bx + 7, prop_y + 2], fill=C_P38_PROP)
        draw.ellipse([bx - 2, prop_y - 2, bx + 2, prop_y + 2], fill=C_P38_SHADOW)

    # Horizontal Tail Plane
    draw.rectangle([cx - 13 + bank_offset // 2, cy + 18, cx + 13 + bank_offset // 2, cy + 21], 
                   fill=C_P38_BODY, outline=C_P38_OUTLINE)

    # Central Fuselage Pod
    center_poly = [
        (cx - 4 + bank_offset, cy - 18),
        (cx + 4 + bank_offset, cy - 18),
        (cx + 5 + bank_offset, cy - 6),
        (cx + 4 + bank_offset, cy + 8),
        (cx - 4 + bank_offset, cy + 8),
        (cx - 5 + bank_offset, cy - 6),
    ]
    draw.polygon(center_poly, fill=C_P38_BODY, outline=C_P38_OUTLINE)
    draw.line([(cx - 2 + bank_offset, cy - 16), (cx - 2 + bank_offset, cy + 6)], fill=C_P38_HIGHLIGHT)

    # Nose Machine Guns
    draw.rectangle([cx - 2 + bank_offset, cy - 20, cx + 2 + bank_offset, cy - 18], fill=(30, 30, 30, 255))
    draw.point((cx + bank_offset, cy - 21), fill=(255, 255, 255, 255))

    # Cockpit Glass
    canopy_poly = [
        (cx - 2 + bank_offset, cy - 12),
        (cx + 2 + bank_offset, cy - 12),
        (cx + 3 + bank_offset, cy - 2),
        (cx - 3 + bank_offset, cy - 2),
    ]
    draw.polygon(canopy_poly, fill=C_P38_CANOPY, outline=C_P38_CANOPY_SHADOW)
    draw.line([(cx - 1 + bank_offset, cy - 10), (cx - 1 + bank_offset, cy - 3)], fill=(255, 255, 255, 230))

    # US Star Insignia on left wing
    draw.ellipse([cx - 16, cy - 1, cx - 8, cy + 3], fill=C_P38_STAR_BLUE)
    draw.polygon([(cx - 12, cy - 1), (cx - 10, cy + 3), (cx - 14, cy + 3)], fill=C_P38_STAR)

    return img

def draw_p38_loop(frame_idx: int):
    w, h = 64, 64
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    if frame_idx == 1:
        draw.rectangle([cx - 22, cy - 1, cx + 22, cy + 3], fill=C_P38_BODY, outline=C_P38_OUTLINE)
        for sign in [-1, 1]:
            bx = cx + sign * 11
            draw.rectangle([bx - 3, cy - 12, bx + 3, cy + 12], fill=C_P38_BODY, outline=C_P38_OUTLINE)
            draw.ellipse([bx - 6, cy - 14, bx + 6, cy - 10], fill=C_P38_PROP)
        draw.polygon([(cx - 4, cy - 16), (cx + 4, cy - 16), (cx + 5, cy + 5), (cx - 5, cy + 5)], 
                     fill=C_P38_HIGHLIGHT, outline=C_P38_OUTLINE)
        draw.rectangle([cx - 2, cy - 10, cx + 2, cy - 2], fill=C_P38_CANOPY)

    elif frame_idx == 2:
        draw.rectangle([cx - 24, cy - 2, cx + 24, cy + 2], fill=C_P38_HIGHLIGHT, outline=C_P38_OUTLINE)
        for sign in [-1, 1]:
            bx = cx + sign * 11
            draw.rectangle([bx - 3, cy - 5, bx + 3, cy + 6], fill=C_P38_SHADOW, outline=C_P38_OUTLINE)
            draw.ellipse([bx - 7, cy - 6, bx + 7, cy - 2], fill=C_P38_PROP)
        draw.rectangle([cx - 4, cy - 7, cx + 4, cy + 7], fill=C_P38_SHADOW, outline=C_P38_OUTLINE)

    elif frame_idx == 3:
        scale = 1.25
        base = draw_p38("level")
        inverted = base.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        nw, nh = int(w * scale), int(h * scale)
        scaled = inverted.resize((nw, nh), Image.Resampling.BILINEAR)
        ox, oy = (w - nw) // 2, (h - nh) // 2
        img.paste(scaled, (ox, oy), scaled)
        d_inv = ImageDraw.Draw(img)
        d_inv.line([(cx - 16, cy - 8), (cx + 16, cy + 8)], fill=(255, 255, 255, 140), width=2)

    elif frame_idx == 4:
        draw.rectangle([cx - 24, cy - 1, cx + 24, cy + 2], fill=C_P38_SHADOW, outline=C_P38_OUTLINE)
        for sign in [-1, 1]:
            bx = cx + sign * 11
            draw.rectangle([bx - 3, cy - 6, bx + 3, cy + 7], fill=C_P38_BODY, outline=C_P38_OUTLINE)
            draw.ellipse([bx - 7, cy + 4, bx + 7, cy + 8], fill=C_P38_PROP)
        draw.polygon([(cx - 4, cy - 8), (cx + 4, cy - 8), (cx + 3, cy + 12), (cx - 3, cy + 12)], 
                     fill=C_P38_BODY, outline=C_P38_OUTLINE)

    elif frame_idx == 5:
        base = draw_p38("level")
        nw, nh = int(w * 0.9), int(h * 0.9)
        scaled = base.resize((nw, nh), Image.Resampling.BILINEAR)
        img.paste(scaled, ((w - nw) // 2, (h - nh) // 2 + 3), scaled)

    elif frame_idx == 6:
        img = draw_p38("level")

    return img

# ===========================================================================
# 2. ENEMY FIGHTERS (ZERO SCOUT & RED SQUADRON)
# ===========================================================================
def draw_fighter(color_type="zero", state="level"):
    w, h = 48, 48
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    c_body = C_RED_BODY if color_type == "red" else C_ZERO_BODY
    c_light = C_RED_LIGHT if color_type == "red" else C_ZERO_LIGHT
    c_shadow = C_RED_SHADOW if color_type == "red" else C_ZERO_SHADOW
    c_outline = C_RED_OUTLINE if color_type == "red" else C_ZERO_OUTLINE

    bank_x = -2 if state == "left" else (2 if state == "right" else 0)
    wing_tilt = -2 if state == "left" else (2 if state == "right" else 0)

    wing_poly = [
        (cx - 20, cy + 1 + wing_tilt),
        (cx - 8, cy - 4 + wing_tilt // 2),
        (cx + 8, cy - 4 - wing_tilt // 2),
        (cx + 20, cy + 1 - wing_tilt),
        (cx + 17, cy + 6 - wing_tilt),
        (cx - 17, cy + 6 + wing_tilt),
    ]
    draw.polygon(wing_poly, fill=c_body, outline=c_outline)
    draw.line([(cx - 19, cy + 1 + wing_tilt), (cx + 19, cy + 1 - wing_tilt)], fill=c_light)

    accent_col = C_RED_WHITE if color_type == "red" else C_ZERO_RED
    draw.ellipse([cx - 16, cy + 1 + wing_tilt, cx - 11, cy + 5 + wing_tilt], fill=accent_col)
    draw.ellipse([cx + 11, cy + 1 - wing_tilt, cx + 16, cy + 5 - wing_tilt], fill=accent_col)

    fuselage_poly = [
        (cx - 4 + bank_x, cy - 16),
        (cx + 4 + bank_x, cy - 16),
        (cx + 4 + bank_x, cy + 12),
        (cx + bank_x, cy + 18),
        (cx - 4 + bank_x, cy + 12),
    ]
    draw.polygon(fuselage_poly, fill=c_body, outline=c_outline)
    draw.line([(cx - 2 + bank_x, cy - 14), (cx - 2 + bank_x, cy + 10)], fill=c_light)

    draw.rectangle([cx - 4 + bank_x, cy - 17, cx + 4 + bank_x, cy - 14], fill=(35, 35, 40, 255))
    draw.ellipse([cx - 8 + bank_x, cy - 19, cx + 8 + bank_x, cy - 16], fill=C_P38_PROP)

    draw.polygon([
        (cx - 2 + bank_x, cy - 8),
        (cx + 2 + bank_x, cy - 8),
        (cx + 3 + bank_x, cy - 1),
        (cx - 3 + bank_x, cy - 1),
    ], fill=(140, 220, 255, 230), outline=c_outline)

    draw.rectangle([cx - 9 + bank_x // 2, cy + 13, cx + 9 + bank_x // 2, cy + 16], fill=c_body, outline=c_outline)
    draw.polygon([(cx - 2 + bank_x, cy + 11), (cx + 2 + bank_x, cy + 11), (cx + bank_x, cy + 17)], fill=c_shadow)

    return img

# ===========================================================================
# 3. HEAVY TWIN-ENGINE BOMBER
# ===========================================================================
def draw_twin_bomber():
    w, h = 96, 80
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    wing_poly = [
        (cx - 44, cy + 2),
        (cx - 16, cy - 6),
        (cx + 16, cy - 6),
        (cx + 44, cy + 2),
        (cx + 38, cy + 12),
        (cx - 38, cy + 12),
    ]
    draw.polygon(wing_poly, fill=C_BOMB_BODY, outline=C_BOMB_OUTLINE)
    draw.line([(cx - 42, cy + 3), (cx + 42, cy + 3)], fill=C_BOMB_LIGHT)

    draw.ellipse([cx - 34, cy + 3, cx - 24, cy + 10], fill=C_ZERO_RED)
    draw.ellipse([cx + 24, cy + 3, cx + 34, cy + 10], fill=C_ZERO_RED)

    for sign in [-1, 1]:
        nx = cx + sign * 22
        draw.rectangle([nx - 5, cy - 18, nx + 5, cy + 14], fill=C_BOMB_BODY, outline=C_BOMB_OUTLINE)
        draw.line([(nx - 3, cy - 16), (nx - 3, cy + 12)], fill=C_BOMB_LIGHT)
        draw.rectangle([nx - 5, cy - 20, nx + 5, cy - 17], fill=(40, 40, 45, 255))
        draw.ellipse([nx - 11, cy - 22, nx + 11, cy - 18], fill=C_P38_PROP)

    fuse_poly = [
        (cx - 6, cy - 26),
        (cx + 6, cy - 26),
        (cx + 7, cy + 20),
        (cx + 2, cy + 32),
        (cx - 2, cy + 32),
        (cx - 7, cy + 20),
    ]
    draw.polygon(fuse_poly, fill=C_BOMB_BODY, outline=C_BOMB_OUTLINE)
    draw.line([(cx - 4, cy - 24), (cx - 4, cy + 24)], fill=C_BOMB_LIGHT)

    draw.polygon([(cx - 4, cy - 25), (cx + 4, cy - 25), (cx + 5, cy - 14), (cx - 5, cy - 14)], 
                 fill=(130, 210, 245, 220), outline=C_BOMB_OUTLINE)
    draw.ellipse([cx - 4, cy - 2, cx + 4, cy + 6], fill=(130, 210, 245, 240), outline=C_BOMB_OUTLINE)
    draw.line([(cx, cy + 1), (cx, cy - 5)], fill=(30, 30, 30, 255), width=2)

    draw.polygon([(cx - 18, cy + 24), (cx + 18, cy + 24), (cx + 14, cy + 30), (cx - 14, cy + 30)], 
                 fill=C_BOMB_BODY, outline=C_BOMB_OUTLINE)
    draw.rectangle([cx - 2, cy + 20, cx + 2, cy + 30], fill=C_BOMB_SHADOW)

    return img

# ===========================================================================
# 4. GIANT BOSS SUPER-BOMBER ("GOLIATH" / AYAKO)
# ===========================================================================
def draw_boss_super_bomber(damaged=False):
    w, h = 192, 140
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    wing_poly = [
        (cx - 90, cy + 6),
        (cx - 30, cy - 14),
        (cx + 30, cy - 14),
        (cx + 90, cy + 6),
        (cx + 78, cy + 26),
        (cx - 78, cy + 26),
    ]
    draw.polygon(wing_poly, fill=C_BOSS_BODY, outline=(25, 27, 30, 255))
    draw.line([(cx - 88, cy + 8), (cx + 88, cy + 8)], fill=C_BOSS_LIGHT, width=2)

    draw.ellipse([cx - 70, cy + 10, cx - 52, cy + 22], fill=C_BOSS_ACCENT)
    draw.ellipse([cx + 52, cy + 10, cx + 70, cy + 22], fill=C_BOSS_ACCENT)

    engine_positions = [-62, -38, 38, 62]
    for ex in engine_positions:
        nx = cx + ex
        draw.rectangle([nx - 6, cy - 24, nx + 6, cy + 20], fill=C_BOSS_BODY, outline=(25, 27, 30, 255))
        draw.line([(nx - 3, cy - 22), (nx - 3, cy + 16)], fill=C_BOSS_LIGHT)
        draw.ellipse([nx - 14, cy - 28, nx + 14, cy - 23], fill=C_P38_PROP)
        draw.rectangle([nx - 6, cy - 26, nx + 6, cy - 23], fill=(30, 30, 35, 255))

        if damaged and abs(ex) == 62:
            draw.ellipse([nx - 5, cy - 10, nx + 5, cy], fill=C_FLAK_FIRE)
            draw.ellipse([nx - 8, cy - 2, nx + 8, cy + 14], fill=C_FLAK_SMOKE)

    fuse_poly = [
        (cx - 14, cy - 46),
        (cx + 14, cy - 46),
        (cx + 16, cy + 30),
        (cx + 6, cy + 54),
        (cx - 6, cy + 54),
        (cx - 16, cy + 30),
    ]
    draw.polygon(fuse_poly, fill=C_BOSS_BODY, outline=(25, 27, 30, 255))
    draw.line([(cx - 9, cy - 42), (cx - 9, cy + 45)], fill=C_BOSS_LIGHT, width=2)

    # Nose Turret
    draw.polygon([(cx - 8, cy - 45), (cx + 8, cy - 45), (cx + 10, cy - 30), (cx - 10, cy - 30)], 
                 fill=(120, 205, 240, 220), outline=(25, 27, 30, 255))
    draw.rectangle([cx - 2, cy - 50, cx + 2, cy - 45], fill=(20, 20, 20, 255))
    
    # Upper Command Deck
    draw.polygon([(cx - 9, cy - 26), (cx + 9, cy - 26), (cx + 11, cy - 10), (cx - 11, cy - 10)], 
                 fill=(140, 225, 255, 240), outline=(25, 27, 30, 255))

    # Dorsal Mid Turret
    draw.ellipse([cx - 8, cy + 4, cx + 8, cy + 18], fill=C_BOSS_LIGHT, outline=(25, 27, 30, 255))
    draw.ellipse([cx - 5, cy + 7, cx + 5, cy + 15], fill=(120, 205, 240, 220))
    draw.line([(cx, cy + 10), (cx - 10, cy - 2)], fill=(20, 20, 20, 255), width=2)
    draw.line([(cx, cy + 10), (cx + 10, cy - 2)], fill=(20, 20, 20, 255), width=2)

    # Tail Stabilizers
    draw.polygon([(cx - 36, cy + 42), (cx + 36, cy + 42), (cx + 28, cy + 54), (cx - 28, cy + 54)], 
                 fill=C_BOSS_BODY, outline=(25, 27, 30, 255))
    draw.rectangle([cx - 4, cy + 34, cx + 4, cy + 52], fill=C_BOSS_SHADOW)

    return img

# ===========================================================================
# 5. ENVIRONMENT & NAVAL ASSETS (CARRIER DECK, ISLANDS, OCEAN)
# ===========================================================================
def draw_carrier_deck():
    w, h = 160, 360
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx = w // 2

    hull_poly = [
        (cx - 38, 20),
        (cx, 0),
        (cx + 38, 20),
        (cx + 42, h - 30),
        (cx + 36, h),
        (cx - 36, h),
        (cx - 42, h - 30),
    ]
    draw.polygon(hull_poly, fill=C_CARRIER_DECK, outline=(35, 38, 42, 255))
    
    for y in range(24, h - 10, 8):
        draw.line([(cx - 36, y), (cx + 36, y)], fill=(75, 78, 83, 255), width=1)

    for y in range(40, h - 40, 20):
        draw.rectangle([cx - 2, y, cx + 2, y + 12], fill=C_CARRIER_LINE)

    draw.line([(cx - 12, 30), (cx - 12, 110)], fill=(30, 32, 35, 255), width=2)
    draw.line([(cx + 12, 30), (cx + 12, 110)], fill=(30, 32, 35, 255), width=2)

    for cy_wire in [h - 70, h - 55, h - 40]:
        draw.line([(cx - 32, cy_wire), (cx + 32, cy_wire)], fill=(20, 20, 22, 255), width=2)

    ix, iy = cx + 40, 140
    draw.polygon([(ix - 4, iy - 30), (ix + 12, iy - 24), (ix + 12, iy + 30), (ix - 4, iy + 36)], 
                 fill=(45, 48, 52, 255), outline=(25, 28, 32, 255))
    for wy in range(iy - 20, iy + 20, 8):
        draw.rectangle([ix, wy, ix + 8, wy + 4], fill=(120, 200, 240, 240))
    draw.line([(ix + 4, iy - 30), (ix + 4, iy - 46)], fill=(30, 32, 36, 255), width=2)
    draw.line([(ix, iy - 42), (ix + 8, iy - 42)], fill=(30, 32, 36, 255), width=2)

    draw.rectangle([cx - 18, 160, cx + 18, 200], outline=(30, 32, 35, 255), fill=(55, 58, 62, 255), width=2)
    draw.line([(cx - 18, 160), (cx + 18, 200)], fill=(45, 48, 52, 255))
    draw.line([(cx - 18, 200), (cx + 18, 160)], fill=(45, 48, 52, 255))

    draw.rectangle([cx - 24, h - 30, cx + 24, h - 26], fill=(240, 240, 240, 255))

    return img

def draw_island_atoll(variant=1):
    w, h = (200, 200) if variant == 1 else (160, 160)
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    draw.ellipse([10, 10, w - 10, h - 10], fill=C_OCEAN_REEF)
    draw.ellipse([26, 26, w - 26, h - 26], fill=C_SAND)
    draw.ellipse([40, 40, w - 40, h - 40], fill=C_JUNGLE)

    for angle in range(0, 360, 30):
        rad = math.radians(angle)
        dist = (w // 2 - 50) * 0.7
        px = cx + math.cos(rad) * dist
        py = cy + math.sin(rad) * dist
        draw.ellipse([px - 14, py - 14, px + 14, py + 14], fill=C_JUNGLE_DARK)

    if variant == 1:
        draw.rectangle([cx - 10, 30, cx + 10, h - 30], fill=(60, 62, 66, 255), outline=(40, 42, 45, 255))
        for ry in range(40, h - 40, 16):
            draw.rectangle([cx - 1, ry, cx + 1, ry + 8], fill=(230, 230, 230, 255))

    return img

def draw_ocean_tile():
    w, h = 128, 128
    img = Image.new("RGBA", (w, h), C_OCEAN_DEEP)
    draw = ImageDraw.Draw(img)

    for y in range(0, h, 16):
        offset = 8 if (y // 16) % 2 == 1 else 0
        for x in range(0, w, 32):
            wx = (x + offset) % w
            draw.arc([wx - 8, y, wx + 8, y + 6], 180, 360, fill=C_OCEAN_MID, width=2)
            draw.point((wx, y + 1), fill=(120, 180, 220, 120))

    return img

def draw_cloud(variant=1):
    w, h = 96, 64
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)

    col_cloud = (255, 255, 255, 140)
    col_highlight = (255, 255, 255, 210)

    draw.ellipse([14, 20, 60, 52], fill=col_cloud)
    draw.ellipse([34, 10, 80, 46], fill=col_cloud)
    draw.ellipse([48, 18, 90, 54], fill=col_cloud)
    draw.ellipse([26, 12, 54, 34], fill=col_highlight)

    return img.filter(ImageFilter.GaussianBlur(radius=1.5))

# ===========================================================================
# 6. FLAK TURRETS & PROJECTILES
# ===========================================================================
def draw_flak_turret():
    w, h = 32, 32
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    draw.ellipse([cx - 13, cy - 13, cx + 13, cy + 13], fill=(70, 72, 75, 255), outline=(40, 42, 45, 255))
    draw.ellipse([cx - 9, cy - 9, cx + 9, cy + 9], fill=(95, 98, 102, 255))

    draw.rectangle([cx - 3, cy - 14, cx - 1, cy - 2], fill=(25, 25, 28, 255))
    draw.rectangle([cx + 1, cy - 14, cx + 3, cy - 2], fill=(25, 25, 28, 255))
    draw.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=(50, 52, 56, 255), outline=(20, 20, 22, 255))

    return img

def draw_bullet(btype="player"):
    if btype == "player":
        w, h = 12, 24
        img = Image.new("RGBA", (w, h), C_TRANS)
        draw = ImageDraw.Draw(img)
        cx = w // 2
        draw.rounded_rectangle([cx - 3, 2, cx + 3, h - 2], radius=3, fill=C_BULLET_P)
        draw.rounded_rectangle([cx - 1, 4, cx + 1, h - 4], radius=1, fill=C_BULLET_P_CORE)
        return img

    elif btype == "enemy":
        w, h = 12, 12
        img = Image.new("RGBA", (w, h), C_TRANS)
        draw = ImageDraw.Draw(img)
        draw.ellipse([1, 1, 10, 10], fill=C_BULLET_E, outline=(255, 180, 60, 255))
        draw.ellipse([3, 3, 8, 8], fill=(255, 240, 180, 255))
        return img

    elif btype == "flak":
        w, h = 36, 36
        img = Image.new("RGBA", (w, h), C_TRANS)
        draw = ImageDraw.Draw(img)
        cx, cy = w // 2, h // 2
        draw.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], fill=C_FLAK_SMOKE)
        draw.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=(25, 25, 30, 240))
        for angle in range(0, 360, 45):
            rad = math.radians(angle)
            sx = cx + math.cos(rad) * 12
            sy = cy + math.sin(rad) * 12
            draw.line([(cx, cy), (sx, sy)], fill=C_FLAK_FIRE, width=2)
            draw.point((sx, sy), fill=(255, 255, 200, 255))
        return img

# ===========================================================================
# 7. RETRO EXPLOSION ANIMATION (5 FRAMES)
# ===========================================================================
def draw_explosion(frame: int):
    w, h = 48, 48
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    if frame == 0:
        draw.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=(255, 255, 255, 255))
        for angle in range(0, 360, 60):
            rad = math.radians(angle)
            draw.line([(cx, cy), (cx + math.cos(rad) * 14, cy + math.sin(rad) * 14)], 
                      fill=(255, 220, 50, 255), width=2)

    elif frame == 1:
        draw.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], fill=(255, 140, 20, 255))
        draw.ellipse([cx - 9, cy - 9, cx + 9, cy + 9], fill=(255, 240, 80, 255))
        draw.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(255, 255, 255, 255))

    elif frame == 2:
        draw.ellipse([cx - 19, cy - 19, cx + 19, cy + 19], fill=(220, 40, 20, 240))
        draw.ellipse([cx - 13, cy - 13, cx + 13, cy + 13], fill=(255, 160, 30, 255))
        draw.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], fill=(255, 255, 160, 255))
        draw.point((cx - 16, cy - 12), fill=(40, 40, 40, 255))
        draw.point((cx + 17, cy - 10), fill=(40, 40, 40, 255))
        draw.point((cx - 12, cy + 16), fill=(40, 40, 40, 255))
        draw.point((cx + 14, cy + 15), fill=(40, 40, 40, 255))

    elif frame == 3:
        draw.ellipse([cx - 17, cy - 17, cx + 17, cy + 17], fill=(60, 60, 65, 200))
        draw.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(180, 50, 20, 210))
        draw.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(255, 140, 30, 220))

    elif frame == 4:
        draw.ellipse([cx - 18, cy - 18, cx + 18, cy + 18], fill=(50, 50, 55, 110))
        draw.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(0, 0, 0, 0))

    return img

# ===========================================================================
# 8. POWER-UPS & PICKUPS ([POW], [WING], [LOOP], [BOMB], MEDALS)
# ===========================================================================
def draw_pow_badge(label="POW"):
    w, h = 32, 32
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    col_bg = C_POW_RED
    if label == "WING": col_bg = (35, 110, 225, 255)
    elif label == "LOOP": col_bg = (235, 165, 25, 255)
    elif label == "BOMB": col_bg = (45, 45, 52, 255)

    draw.rounded_rectangle([2, 2, w - 3, h - 3], radius=6, fill=col_bg, outline=(255, 255, 255, 255), width=2)
    draw.line([(5, 5), (w - 6, 5)], fill=(255, 255, 255, 180), width=1)

    if label == "POW":
        # P
        draw.rectangle([7, 10, 9, 21], fill=C_POW_WHITE)
        draw.rectangle([9, 10, 12, 16], fill=C_POW_WHITE)
        draw.rectangle([9, 12, 10, 14], fill=col_bg)
        # O
        draw.rectangle([14, 10, 18, 21], fill=C_POW_WHITE)
        draw.rectangle([15, 12, 17, 19], fill=col_bg)
        # W
        draw.rectangle([20, 10, 22, 21], fill=C_POW_WHITE)
        draw.rectangle([24, 14, 25, 21], fill=C_POW_WHITE)
        draw.rectangle([27, 10, 29, 21], fill=C_POW_WHITE)
        draw.rectangle([22, 19, 27, 21], fill=C_POW_WHITE)

    elif label == "WING":
        draw.polygon([(cx - 10, cy + 4), (cx, cy - 6), (cx + 10, cy + 4), 
                      (cx + 6, cy + 6), (cx, cy), (cx - 6, cy + 6)], fill=C_POW_WHITE)

    elif label == "LOOP":
        draw.arc([cx - 8, cy - 8, cx + 8, cy + 8], 45, 315, fill=C_POW_WHITE, width=2)
        draw.polygon([(cx + 6, cy - 8), (cx + 10, cy - 4), (cx + 4, cy - 2)], fill=C_POW_WHITE)

    elif label == "BOMB":
        draw.ellipse([cx - 6, cy - 3, cx + 6, cy + 9], fill=(255, 60, 30, 255), outline=C_POW_WHITE)
        draw.line([(cx, cy - 3), (cx + 4, cy - 8)], fill=(240, 240, 240, 255), width=2)
        draw.point((cx + 5, cy - 9), fill=(255, 255, 80, 255))

    return img

def draw_medal(tier="gold"):
    w, h = 24, 24
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    c_base = C_GOLD if tier == "gold" else ((215, 220, 225, 255) if tier == "silver" else (205, 130, 60, 255))
    c_rim = C_GOLD_SHADOW if tier == "gold" else ((150, 155, 160, 255) if tier == "silver" else (140, 80, 30, 255))

    draw.polygon([(cx - 6, 2), (cx + 6, 2), (cx + 4, 10), (cx - 4, 10)], fill=(220, 35, 35, 255), outline=(150, 20, 20, 255))
    draw.line([(cx, 2), (cx, 10)], fill=(255, 255, 255, 255), width=1)

    draw.ellipse([cx - 8, cy - 1, cx + 8, cy + 15], fill=c_base, outline=c_rim, width=1)
    draw.ellipse([cx - 6, cy + 1, cx + 6, cy + 13], outline=c_rim, width=1)
    draw.polygon([(cx, cy + 3), (cx + 3, cy + 11), (cx - 3, cy + 11)], fill=(255, 255, 255, 220))

    return img

# ===========================================================================
# GENERATION PIPELINE & ATLAS CREATION
# ===========================================================================
def generate_all():
    print("[Sky Ace Art Generator] Generating player P-38 sprites...")
    register_sprite("player_level", draw_p38("level"))
    register_sprite("player_bank_left", draw_p38("left"))
    register_sprite("player_bank_right", draw_p38("right"))
    for idx in range(1, 7):
        register_sprite(f"player_loop_{idx}", draw_p38_loop(idx))
    register_sprite("escort_fighter", draw_p38("escort"))

    print("[Sky Ace Art Generator] Generating enemy aircraft...")
    register_sprite("enemy_zero_level", draw_fighter("zero", "level"))
    register_sprite("enemy_zero_left", draw_fighter("zero", "left"))
    register_sprite("enemy_zero_right", draw_fighter("zero", "right"))
    register_sprite("enemy_red_level", draw_fighter("red", "level"))
    register_sprite("enemy_red_left", draw_fighter("red", "left"))
    register_sprite("enemy_red_right", draw_fighter("red", "right"))
    register_sprite("enemy_bomber", draw_twin_bomber())
    register_sprite("boss_ayako", draw_boss_super_bomber(damaged=False))
    register_sprite("boss_ayako_damaged", draw_boss_super_bomber(damaged=True))

    print("[Sky Ace Art Generator] Generating naval & ground targets...")
    register_sprite("carrier_deck", draw_carrier_deck())
    register_sprite("island_atoll_1", draw_island_atoll(variant=1))
    register_sprite("island_atoll_2", draw_island_atoll(variant=2))
    register_sprite("ocean_tile", draw_ocean_tile())
    register_sprite("cloud_1", draw_cloud(1))
    register_sprite("flak_turret", draw_flak_turret())

    print("[Sky Ace Art Generator] Generating projectiles & FX...")
    register_sprite("bullet_player", draw_bullet("player"))
    register_sprite("bullet_enemy", draw_bullet("enemy"))
    register_sprite("flak_burst", draw_bullet("flak"))
    for f in range(5):
        register_sprite(f"explosion_{f}", draw_explosion(f))

    print("[Sky Ace Art Generator] Generating power-ups & medals...")
    register_sprite("pow_quad", draw_pow_badge("POW"))
    register_sprite("pow_wing", draw_pow_badge("WING"))
    register_sprite("pow_loop", draw_pow_badge("LOOP"))
    register_sprite("pow_bomb", draw_pow_badge("BOMB"))
    register_sprite("medal_gold", draw_medal("gold"))
    register_sprite("medal_silver", draw_medal("silver"))
    register_sprite("medal_bronze", draw_medal("bronze"))

    print(f"[Sky Ace Art Generator] Saved {len(saved_sprites)} individual sprite files in {OUTPUT_DIR}")

    build_master_spritesheet()
    build_showcase_montage()

def build_master_spritesheet():
    import json
    atlas_w, atlas_h = 1024, 1024
    atlas = Image.new("RGBA", (atlas_w, atlas_h), C_TRANS)
    metadata = {}

    cur_x, cur_y = 4, 4
    row_h = 0

    sorted_items = sorted(saved_sprites.items(), key=lambda kv: (kv[1].height, kv[1].width), reverse=True)

    for name, img in sorted_items:
        iw, ih = img.size
        if cur_x + iw + 4 > atlas_w:
            cur_x = 4
            cur_y += row_h + 4
            row_h = 0

        if cur_y + ih + 4 > atlas_h:
            print(f"Warning: Atlas full at {name}")
            break

        atlas.paste(img, (cur_x, cur_y), img)
        metadata[name] = {
            "x": cur_x,
            "y": cur_y,
            "w": iw,
            "h": ih
        }

        cur_x += iw + 4
        row_h = max(row_h, ih)

    atlas_path = OUTPUT_DIR / "spritesheet.png"
    atlas.save(atlas_path, format="PNG", optimize=True)

    json_path = OUTPUT_DIR / "spritesheet.json"
    json_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print(f"[Sky Ace Art Generator] Master spritesheet saved to {atlas_path} and {json_path}")

def build_showcase_montage():
    mw, mh = 800, 600
    montage = Image.new("RGBA", (mw, mh), C_OCEAN_DEEP)
    d = ImageDraw.Draw(montage)

    ocean = saved_sprites.get("ocean_tile")
    if ocean:
        for y in range(0, mh, ocean.height):
            for x in range(0, mw, ocean.width):
                montage.paste(ocean, (x, y))

    d.rectangle([0, 0, mw, 48], fill=(16, 24, 36, 230))
    d.line([(0, 48), (mw, 48)], fill=(0, 240, 255, 255), width=2)
    d.text((20, 16), "SKY ACE • OFFICIAL RETRO ARCADE SPRITE SUITE", fill=(0, 240, 255, 255))

    carrier = saved_sprites.get("carrier_deck")
    if carrier:
        montage.paste(carrier, (24, 70), carrier)

    island = saved_sprites.get("island_atoll_1")
    if island:
        montage.paste(island, (mw - 220, 70), island)

    boss = saved_sprites.get("boss_ayako")
    if boss:
        montage.paste(boss, (240, 70), boss)

    bomber = saved_sprites.get("enemy_bomber")
    if bomber:
        montage.paste(bomber, (288, 230), bomber)

    for i, name in enumerate(["enemy_red_left", "enemy_red_level", "enemy_red_right"]):
        spr = saved_sprites.get(name)
        if spr: montage.paste(spr, (210 + i * 56, 330), spr)

    for i, name in enumerate(["enemy_zero_left", "enemy_zero_level", "enemy_zero_right"]):
        spr = saved_sprites.get(name)
        if spr: montage.paste(spr, (390 + i * 56, 330), spr)

    d.text((210, 400), "P-38 LOOP-THE-LOOP EVASIVE MANEUVER:", fill=(255, 255, 255, 220))
    for i in range(1, 7):
        spr = saved_sprites.get(f"player_loop_{i}")
        if spr: montage.paste(spr, (200 + (i - 1) * 64, 420), spr)

    player = saved_sprites.get("player_level")
    escort = saved_sprites.get("escort_fighter")
    if player and escort:
        px, py = 100, 470
        montage.paste(player, (px, py), player)
        montage.paste(escort, (px - 28, py + 14), escort)
        montage.paste(escort, (px + 60, py + 14), escort)

    items = ["pow_quad", "pow_wing", "pow_loop", "pow_bomb", "medal_gold", "medal_silver", "medal_bronze"]
    for i, iname in enumerate(items):
        spr = saved_sprites.get(iname)
        if spr: montage.paste(spr, (240 + i * 44, 530), spr)

    for i in range(5):
        spr = saved_sprites.get(f"explosion_{i}")
        if spr: montage.paste(spr, (570 + i * 40, 520), spr)

    showcase_path = SHOWCASE_DIR / "skyace_art_showcase.png"
    montage.save(showcase_path, format="PNG", optimize=True)
    print(f"[Sky Ace Art Generator] Showcase montage saved to {showcase_path}")

if __name__ == "__main__":
    generate_all()

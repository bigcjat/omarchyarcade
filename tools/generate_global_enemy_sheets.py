#!/usr/bin/env python3
"""
Sky Ace • Global Enemy Fleets & Super Fortress Boss Spritesheet Generator
Generates high-resolution sprite sheets for:
1. German Luftwaffe Fleet: Fw 190 (scout), Me 262 (jet interceptor), He 111 (bomber), BV 238 "Leviathan" (6-engine boss)
2. British RAF Fleet: Hurricane (scout), Typhoon (interceptor), Stirling (bomber), Avro Lancaster "Grand Slam" (boss)
3. Soviet VVS Fleet: La-7 (scout), Il-2 Shturmovik (interceptor), Pe-2 (bomber), Petlyakov Pe-8 "Red Fortress" (boss)
"""

import math
import json
from pathlib import Path
from PIL import Image, ImageDraw

SPRITES_DIR = Path("games/skyace/sprites")
SPRITES_DIR.mkdir(parents=True, exist_ok=True)

C_TRANS = (0, 0, 0, 0)
PROP_BLUR = (245, 220, 75, 180)
GLASS_CYAN = (130, 215, 245, 230)
WHITE = (245, 245, 250, 255)
RED = (215, 30, 30, 255)
YELLOW = (245, 205, 45, 255)

# --- PALETTES ---
# Luftwaffe (Dark Green / Black-Green Splinter Camo + Yellow nose)
FW_BODY = (68, 76, 62, 255)
FW_LIGHT = (98, 110, 88, 255)
FW_OUTLINE = (28, 34, 24, 255)
ME262_BODY = (92, 102, 112, 255)
ME262_LIGHT = (128, 140, 154, 255)
HE111_BODY = (72, 82, 68, 255)
BV238_BODY = (78, 88, 76, 255)
BV238_LIGHT = (112, 126, 110, 255)

# RAF (Ocean Grey & Dark Green Camo)
RAF_GREEN = (62, 78, 54, 255)
RAF_GREY = (88, 96, 104, 255)
RAF_BLUE = (26, 52, 118, 255)
LANC_BODY = (56, 64, 52, 255)
LANC_LIGHT = (88, 98, 82, 255)

# Soviet VVS (Winter White / Grey & Green + Red Stars)
VVS_GREY = (115, 125, 135, 255)
VVS_GREEN = (65, 85, 55, 255)
IL2_BODY = (75, 88, 65, 255)
PE8_BODY = (70, 82, 66, 255)
PE8_LIGHT = (105, 120, 100, 255)

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
# 1. GERMAN LUFTWAFFE FLEET
# =============================================================================
def render_fw190_frame(state="level", prop=0):
    w, h = 96, 96
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2
    bank_x = -4 if state == "left" else (4 if state == "right" else 0)
    wing_tilt = -3 if state == "left" else (3 if state == "right" else 0)

    # Tapered wings
    wing = [(cx - 40, cy + 4 + wing_tilt), (cx - 14, cy - 6 + wing_tilt//2),
            (cx + 14, cy - 6 - wing_tilt//2), (cx + 40, cy + 4 - wing_tilt),
            (cx + 36, cy + 14 - wing_tilt), (cx - 36, cy + 14 + wing_tilt)]
    draw.polygon(wing, fill=FW_BODY, outline=FW_OUTLINE)
    draw.line([(cx - 38, cy + 4 + wing_tilt), (cx + 38, cy + 4 - wing_tilt)], fill=FW_LIGHT, width=2)

    # German Balkenkreuz crosses on wings
    for sx, sign in [(-26, 1), (26, -1)]:
        wy = cy + 5 + wing_tilt * sign
        draw.line([(cx + sx - 5, wy), (cx + sx + 5, wy)], fill=WHITE, width=2)
        draw.line([(cx + sx, wy - 5), (cx + sx, wy + 5)], fill=WHITE, width=2)
        draw.line([(cx + sx - 4, wy), (cx + sx + 4, wy)], fill=(20, 20, 20, 255), width=1)
        draw.line([(cx + sx, wy - 4), (cx + sx, wy + 4)], fill=(20, 20, 20, 255), width=1)

    # Radial BMW 801 cowl & yellow chin
    draw.rectangle([cx - 8 + bank_x, cy - 34, cx + 8 + bank_x, cy - 28], fill=YELLOW, outline=FW_OUTLINE)
    draw.ellipse([cx - 16 + bank_x, cy - 38, cx + 16 + bank_x, cy - 32], fill=PROP_BLUR)

    # Fuselage & teardrop cockpit
    fuse = [(cx - 7 + bank_x, cy - 30), (cx + 7 + bank_x, cy - 30), (cx + 8 + bank_x, cy + 24),
            (cx + bank_x, cy + 36), (cx - 8 + bank_x, cy + 24)]
    draw.polygon(fuse, fill=FW_BODY, outline=FW_OUTLINE)
    draw.polygon([(cx - 4 + bank_x, cy - 16), (cx + 4 + bank_x, cy - 16),
                  (cx + 5 + bank_x, cy - 2), (cx - 5 + bank_x, cy - 2)], fill=GLASS_CYAN, outline=FW_OUTLINE)
    draw.rectangle([cx - 16 + bank_x//2, cy + 26, cx + 16 + bank_x//2, cy + 32], fill=FW_BODY, outline=FW_OUTLINE)
    return img

def render_me262_frame(state="level"):
    w, h = 96, 96
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2
    bank_x = -4 if state == "left" else (4 if state == "right" else 0)
    wing_tilt = -3 if state == "left" else (3 if state == "right" else 0)

    # Swept-back jet wings (18.5° sweep)
    wing = [(cx - 42, cy + 12 + wing_tilt), (cx - 10, cy - 8 + wing_tilt//2),
            (cx + 10, cy - 8 - wing_tilt//2), (cx + 42, cy + 12 - wing_tilt),
            (cx + 36, cy + 18 - wing_tilt), (cx - 36, cy + 18 + wing_tilt)]
    draw.polygon(wing, fill=ME262_BODY, outline=FW_OUTLINE)
    draw.line([(cx - 40, cy + 13 + wing_tilt), (cx + 40, cy + 13 - wing_tilt)], fill=ME262_LIGHT, width=2)

    # Twin Junkers Jumo 004 underslung jet pods
    for jx, sign in [(-22, 1), (22, -1)]:
        jy = cy + 4 + wing_tilt * sign
        draw.rounded_rectangle([cx + jx - 5, jy - 14, cx + jx + 5, jy + 14], radius=3, fill=(45, 50, 56, 255), outline=FW_OUTLINE)
        # Jet exhaust glow
        draw.ellipse([cx + jx - 3, jy + 11, cx + jx + 3, jy + 16], fill=(255, 140, 20, 220))

    # Triangular "Shark" Cross-Section Fuselage
    fuse = [(cx - 6 + bank_x, cy - 36), (cx + 6 + bank_x, cy - 36), (cx + 8 + bank_x, cy + 22),
            (cx + bank_x, cy + 36), (cx - 8 + bank_x, cy + 22)]
    draw.polygon(fuse, fill=ME262_BODY, outline=FW_OUTLINE)
    # Nose Cannon Ports (4x 30mm MK 108)
    for px in [-2, 2]: draw.point((cx + px + bank_x, cy - 36), fill=(10, 10, 10, 255))
    draw.polygon([(cx - 4 + bank_x, cy - 14), (cx + 4 + bank_x, cy - 14),
                  (cx + 5 + bank_x, cy), (cx - 5 + bank_x, cy)], fill=GLASS_CYAN, outline=FW_OUTLINE)
    # Swept tailplane
    draw.polygon([(cx - 18 + bank_x//2, cy + 26), (cx + 18 + bank_x//2, cy + 26),
                  (cx + 12 + bank_x//2, cy + 34), (cx - 12 + bank_x//2, cy + 34)], fill=ME262_BODY, outline=FW_OUTLINE)
    return img

def render_he111_frame(damaged=False):
    w, h = 192, 160
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    # Elliptical "Flying Spade" Wings
    wing = [(cx - 92, cy + 8), (cx - 30, cy - 12), (cx + 30, cy - 12),
            (cx + 92, cy + 8), (cx + 74, cy + 28), (cx - 74, cy + 28)]
    draw.polygon(wing, fill=HE111_BODY, outline=FW_OUTLINE)
    draw.line([(cx - 88, cy + 10), (cx + 88, cy + 10)], fill=FW_LIGHT, width=2)

    # Balkenkreuz crosses
    for sx in [-62, 62]:
        draw.line([(cx + sx - 7, cy + 12), (cx + sx + 7, cy + 12)], fill=WHITE, width=3)
        draw.line([(cx + sx, cy + 5), (cx + sx, cy + 19)], fill=WHITE, width=3)

    # Twin Engine Nacelles
    for ex in [-42, 42]:
        draw.rectangle([cx + ex - 9, cy - 34, cx + ex + 9, cy + 26], fill=HE111_BODY, outline=FW_OUTLINE)
        draw.ellipse([cx + ex - 18, cy - 42, cx + ex + 18, cy - 34], fill=PROP_BLUR)
        if damaged and ex == -42:
            draw.ellipse([cx + ex - 8, cy - 10, cx + ex + 8, cy + 12], fill=(255, 120, 20, 240))
            draw.ellipse([cx + ex - 14, cy + 10, cx + ex + 14, cy + 42], fill=(35, 38, 42, 220))

    # Stepless Glazed Asymmetric Cockpit Nose
    draw.polygon([(cx - 10, cy - 54), (cx + 10, cy - 54), (cx + 12, cy - 28), (cx - 12, cy - 28)], fill=GLASS_CYAN, outline=FW_OUTLINE)
    draw.line([(cx - 2, cy - 54), (cx - 2, cy - 30)], fill=FW_OUTLINE, width=1)
    # Fuselage & Ventral Gondola
    fuse = [(cx - 12, cy - 30), (cx + 12, cy - 30), (cx + 14, cy + 42), (cx + 4, cy + 64), (cx - 4, cy + 64), (cx - 14, cy + 42)]
    draw.polygon(fuse, fill=HE111_BODY, outline=FW_OUTLINE)
    draw.polygon([(cx - 36, cy + 48), (cx + 36, cy + 48), (cx + 26, cy + 60), (cx - 26, cy + 60)], fill=HE111_BODY, outline=FW_OUTLINE)
    return img

def render_bv238_frame(damage_stage=0):
    w, h = 384, 256
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    # Enormous High-Mounted Wings (span 370px, 6 Engines)
    wing = [(cx - 185, cy + 12), (cx - 60, cy - 26), (cx + 60, cy - 26),
            (cx + 185, cy + 12), (cx + 165, cy + 50), (cx - 165, cy + 50)]
    draw.polygon(wing, fill=BV238_BODY, outline=FW_OUTLINE)
    draw.line([(cx - 180, cy + 16), (cx + 180, cy + 16)], fill=BV238_LIGHT, width=3)

    # 6 Heavy Daimler-Benz Engine Nacelles
    engines = [-142, -96, -50, 50, 96, 142]
    for ex in engines:
        nx = cx + ex
        draw.rectangle([nx - 9, cy - 44, nx + 9, cy + 36], fill=BV238_BODY, outline=FW_OUTLINE)
        draw.ellipse([nx - 22, cy - 52, nx + 22, cy - 42], fill=PROP_BLUR)

        if damage_stage >= 1 and ex == -142:
            draw.ellipse([nx - 10, cy - 16, nx + 10, cy + 4], fill=(255, 120, 20, 240))
            draw.ellipse([nx - 16, cy + 2, nx + 16, cy + 34], fill=(35, 38, 42, 220))
        if damage_stage >= 2 and ex == 142:
            draw.ellipse([nx - 12, cy - 20, nx + 12, cy + 6], fill=(255, 70, 20, 250))
            draw.ellipse([nx - 20, cy + 4, nx + 20, cy + 44], fill=(30, 32, 36, 230))

    # Giant Flying Boat Hull (Deep V-planing bottom)
    hull = [(cx - 24, cy - 90), (cx + 24, cy - 90), (cx + 28, cy + 65), (cx + 10, cy + 114), (cx - 10, cy + 114), (cx - 28, cy + 65)]
    draw.polygon(hull, fill=BV238_BODY, outline=FW_OUTLINE)
    draw.line([(cx - 16, cy - 84), (cx - 16, cy + 88)], fill=BV238_LIGHT, width=3)

    # Cockpit Greenhouse
    draw.polygon([(cx - 16, cy - 88), (cx + 16, cy - 88), (cx + 18, cy - 62), (cx - 18, cy - 62)], fill=GLASS_CYAN, outline=FW_OUTLINE)

    # Quad Flak Turrets & Barbettes
    for tx, ty in [(-40, -10), (40, -10), (0, 30)]:
        draw.ellipse([cx + tx - 10, cy + ty - 10, cx + tx + 10, cy + ty + 10], fill=(45, 52, 45, 255), outline=FW_OUTLINE)
        draw.line([(cx + tx, cy + ty), (cx + tx - 6, cy + ty - 14)], fill=(20, 20, 20, 255), width=2)
        draw.line([(cx + tx, cy + ty), (cx + tx + 6, cy + ty - 14)], fill=(20, 20, 20, 255), width=2)

    # Tailplane & Twin Wingtip Stabilizer Floats
    draw.polygon([(cx - 68, cy + 88), (cx + 68, cy + 88), (cx + 52, cy + 108), (cx - 52, cy + 108)], fill=BV238_BODY, outline=FW_OUTLINE)
    draw.rounded_rectangle([cx - 172, cy + 34, cx - 156, cy + 54], radius=4, fill=(55, 62, 55, 255), outline=FW_OUTLINE)
    draw.rounded_rectangle([cx + 156, cy + 34, cx + 172, cy + 54], radius=4, fill=(55, 62, 55, 255), outline=FW_OUTLINE)

    if damage_stage >= 2:
        draw.ellipse([cx - 22, cy - 35, cx + 22, cy + 5], fill=(255, 60, 20, 240))
        draw.ellipse([cx - 32, cy - 5, cx + 32, cy + 55], fill=(30, 30, 36, 230))

    return img

def build_luftwaffe_sheets():
    pack_sheet({
        "fly_0": render_fw190_frame("level", 0), "fly_1": render_fw190_frame("level", 1),
        "bank_left": render_fw190_frame("left"), "bank_right": render_fw190_frame("right")
    }, cell_w=96, cell_h=96, cols=4, out_name="sheet_enemy_fw190")

    pack_sheet({
        "fly_0": render_me262_frame("level"), "fly_1": render_me262_frame("level"),
        "bank_left": render_me262_frame("left"), "bank_right": render_me262_frame("right")
    }, cell_w=96, cell_h=96, cols=4, out_name="sheet_enemy_me262")

    pack_sheet({
        "fly_0": render_he111_frame(False), "fly_1": render_he111_frame(False),
        "damaged_engine": render_he111_frame(True)
    }, cell_w=192, cell_h=160, cols=3, out_name="sheet_enemy_he111")

    pack_sheet({
        "pristine": render_bv238_frame(0),
        "wing_damaged": render_bv238_frame(1),
        "critical_wreck": render_bv238_frame(2)
    }, cell_w=384, cell_h=256, cols=3, out_name="sheet_boss_bv238")

# =============================================================================
# 2. BRITISH RAF FLEET
# =============================================================================
def render_hurricane_frame(state="level", prop=0):
    w, h = 96, 96
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2
    bank_x = -4 if state == "left" else (4 if state == "right" else 0)
    wing_tilt = -3 if state == "left" else (3 if state == "right" else 0)

    # Thick, sturdy wings
    wing = [(cx - 40, cy + 4 + wing_tilt), (cx - 14, cy - 6 + wing_tilt//2),
            (cx + 14, cy - 6 - wing_tilt//2), (cx + 40, cy + 4 - wing_tilt),
            (cx + 34, cy + 14 - wing_tilt), (cx - 34, cy + 14 + wing_tilt)]
    draw.polygon(wing, fill=RAF_GREEN, outline=(24, 32, 20, 255))
    draw.line([(cx - 38, cy + 4 + wing_tilt), (cx + 38, cy + 4 - wing_tilt)], fill=RAF_GREY, width=2)

    # RAF Tricolor Roundel
    for sx, sign in [(-26, 1), (26, -1)]:
        wy = cy + 5 + wing_tilt * sign
        draw.ellipse([cx + sx - 6, wy - 6, cx + sx + 6, wy + 6], fill=RAF_BLUE)
        draw.ellipse([cx + sx - 4, wy - 4, cx + sx + 4, wy + 4], fill=WHITE)
        draw.ellipse([cx + sx - 2, wy - 2, cx + sx + 2, wy + 2], fill=RED)

    # Rolls-Royce Merlin nose & prop
    draw.rectangle([cx - 7 + bank_x, cy - 34, cx + 7 + bank_x, cy - 28], fill=(35, 42, 35, 255))
    draw.ellipse([cx - 16 + bank_x, cy - 38, cx + 16 + bank_x, cy - 32], fill=PROP_BLUR)

    # Fuselage & raised cockpit
    fuse = [(cx - 7 + bank_x, cy - 30), (cx + 7 + bank_x, cy - 30), (cx + 8 + bank_x, cy + 24),
            (cx + bank_x, cy + 36), (cx - 8 + bank_x, cy + 24)]
    draw.polygon(fuse, fill=RAF_GREEN, outline=(24, 32, 20, 255))
    draw.polygon([(cx - 4 + bank_x, cy - 16), (cx + 4 + bank_x, cy - 16),
                  (cx + 5 + bank_x, cy - 2), (cx - 5 + bank_x, cy - 2)], fill=GLASS_CYAN, outline=(24, 32, 20, 255))
    draw.rectangle([cx - 16 + bank_x//2, cy + 26, cx + 16 + bank_x//2, cy + 32], fill=RAF_GREEN)
    return img

def render_typhoon_frame(state="level"):
    w, h = 96, 96
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2
    bank_x = -4 if state == "left" else (4 if state == "right" else 0)
    wing_tilt = -3 if state == "left" else (3 if state == "right" else 0)

    # Broad, heavy wings with yellow leading edge
    wing = [(cx - 42, cy + 4 + wing_tilt), (cx - 14, cy - 6 + wing_tilt//2),
            (cx + 14, cy - 6 - wing_tilt//2), (cx + 42, cy + 4 - wing_tilt),
            (cx + 36, cy + 15 - wing_tilt), (cx - 36, cy + 15 + wing_tilt)]
    draw.polygon(wing, fill=RAF_GREY, outline=(20, 24, 28, 255))
    draw.line([(cx - 40, cy + 4 + wing_tilt), (cx + 40, cy + 4 - wing_tilt)], fill=YELLOW, width=2)

    # Huge chin radiator (Napier Sabre 24-cylinder)
    draw.polygon([(cx - 6 + bank_x, cy - 34), (cx + 6 + bank_x, cy - 34),
                  (cx + 8 + bank_x, cy - 24), (cx - 8 + bank_x, cy - 24)], fill=(30, 32, 34, 255))
    draw.ellipse([cx - 17 + bank_x, cy - 40, cx + 17 + bank_x, cy - 34], fill=PROP_BLUR)

    fuse = [(cx - 7 + bank_x, cy - 28), (cx + 7 + bank_x, cy - 28), (cx + 8 + bank_x, cy + 24),
            (cx + bank_x, cy + 36), (cx - 8 + bank_x, cy + 24)]
    draw.polygon(fuse, fill=RAF_GREY, outline=(20, 24, 28, 255))
    draw.polygon([(cx - 4 + bank_x, cy - 14), (cx + 4 + bank_x, cy - 14),
                  (cx + 5 + bank_x, cy), (cx - 5 + bank_x, cy)], fill=GLASS_CYAN)
    draw.rectangle([cx - 17 + bank_x//2, cy + 26, cx + 17 + bank_x//2, cy + 32], fill=RAF_GREY)
    return img

def render_stirling_frame(damaged=False):
    w, h = 192, 160
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    # High aspect ratio, thick wings
    wing = [(cx - 90, cy + 6), (cx - 30, cy - 12), (cx + 30, cy - 12),
            (cx + 90, cy + 6), (cx + 78, cy + 26), (cx - 78, cy + 26)]
    draw.polygon(wing, fill=RAF_GREEN, outline=(20, 24, 20, 255))
    draw.line([(cx - 86, cy + 8), (cx + 86, cy + 8)], fill=RAF_GREY, width=2)

    # 4 Bristol Hercules radial engines
    for ex in [-64, -36, 36, 64]:
        draw.rectangle([cx + ex - 8, cy - 36, cx + ex + 8, cy + 26], fill=RAF_GREEN, outline=(20, 24, 20, 255))
        draw.ellipse([cx + ex - 18, cy - 42, cx + ex + 18, cy - 34], fill=PROP_BLUR)
        if damaged and ex == -64:
            draw.ellipse([cx + ex - 9, cy - 12, cx + ex + 9, cy + 10], fill=(255, 120, 20, 230))
            draw.ellipse([cx + ex - 15, cy + 8, cx + ex + 15, cy + 42], fill=(40, 44, 48, 210))

    # Boxy high-sided fuselage
    fuse = [(cx - 12, cy - 54), (cx + 12, cy - 54), (cx + 14, cy + 40), (cx + 4, cy + 66), (cx - 4, cy + 66), (cx - 14, cy + 40)]
    draw.polygon(fuse, fill=RAF_GREEN, outline=(20, 24, 20, 255))
    draw.polygon([(cx - 8, cy - 52), (cx + 8, cy - 52), (cx + 9, cy - 32), (cx - 9, cy - 32)], fill=GLASS_CYAN)
    draw.polygon([(cx - 38, cy + 50), (cx + 38, cy + 50), (cx + 30, cy + 62), (cx - 30, cy + 62)], fill=RAF_GREEN)
    return img

def render_lancaster_frame(damage_stage=0):
    w, h = 384, 256
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    # Long high-aspect wings (span 360px)
    wing = [(cx - 180, cy + 8), (cx - 56, cy - 26), (cx + 56, cy - 26),
            (cx + 180, cy + 8), (cx + 160, cy + 46), (cx - 160, cy + 46)]
    draw.polygon(wing, fill=LANC_BODY, outline=(20, 24, 20, 255))
    draw.line([(cx - 176, cy + 12), (cx + 176, cy + 12)], fill=LANC_LIGHT, width=3)

    # 4 Rolls-Royce Merlin engine nacelles
    engines = [-120, -72, 72, 120]
    for ex in engines:
        nx = cx + ex
        draw.rectangle([nx - 11, cy - 46, nx + 11, cy + 38], fill=LANC_BODY, outline=(20, 24, 20, 255))
        draw.ellipse([nx - 26, cy - 54, nx + 26, cy - 44], fill=PROP_BLUR)

        if damage_stage >= 1 and ex == -120:
            draw.ellipse([nx - 12, cy - 18, nx + 12, cy + 4], fill=(255, 120, 20, 240))
            draw.ellipse([nx - 18, cy + 2, nx + 18, cy + 38], fill=(35, 38, 42, 220))
        if damage_stage >= 2 and ex == 120:
            draw.ellipse([nx - 14, cy - 22, nx + 14, cy + 8], fill=(255, 70, 20, 250))
            draw.ellipse([nx - 22, cy + 4, nx + 22, cy + 44], fill=(30, 32, 36, 230))

    # Fuselage & Greenhouse Canopy
    fuse = [(cx - 24, cy - 92), (cx + 24, cy - 92), (cx + 26, cy + 58), (cx + 8, cy + 112), (cx - 8, cy + 112), (cx - 26, cy + 58)]
    draw.polygon(fuse, fill=LANC_BODY, outline=(20, 24, 20, 255))
    draw.polygon([(cx - 16, cy - 90), (cx + 16, cy - 90), (cx + 18, cy - 64), (cx - 18, cy - 64)], fill=GLASS_CYAN)

    # Dorsal Mid-Upper Turret & Tail Turret
    draw.ellipse([cx - 12, cy - 4, cx + 12, cy + 20], fill=(32, 38, 32, 255))
    draw.line([(cx - 3, cy + 8), (cx - 3, cy - 8)], fill=(15, 15, 15, 255), width=2)
    draw.line([(cx + 3, cy + 8), (cx + 3, cy - 8)], fill=(15, 15, 15, 255), width=2)

    # Twin Oval Vertical Fins (Iconic Lancaster Empennage)
    draw.rectangle([cx - 68, cy + 86, cx + 68, cy + 96], fill=LANC_BODY)
    draw.ellipse([cx - 72, cy + 78, cx - 60, cy + 104], fill=LANC_LIGHT)
    draw.ellipse([cx + 60, cy + 78, cx + 72, cy + 104], fill=LANC_LIGHT)

    if damage_stage >= 2:
        draw.ellipse([cx - 24, cy - 40, cx + 24, cy], fill=(255, 60, 20, 240))
        draw.ellipse([cx - 36, cy - 10, cx + 36, cy + 50], fill=(30, 30, 36, 230))

    return img

def build_raf_sheets():
    pack_sheet({
        "fly_0": render_hurricane_frame("level", 0), "fly_1": render_hurricane_frame("level", 1),
        "bank_left": render_hurricane_frame("left"), "bank_right": render_hurricane_frame("right")
    }, cell_w=96, cell_h=96, cols=4, out_name="sheet_enemy_hurricane")

    pack_sheet({
        "fly_0": render_typhoon_frame("level"), "fly_1": render_typhoon_frame("level"),
        "bank_left": render_typhoon_frame("left"), "bank_right": render_typhoon_frame("right")
    }, cell_w=96, cell_h=96, cols=4, out_name="sheet_enemy_typhoon")

    pack_sheet({
        "fly_0": render_stirling_frame(False), "fly_1": render_stirling_frame(False),
        "damaged_engine": render_stirling_frame(True)
    }, cell_w=192, cell_h=160, cols=3, out_name="sheet_enemy_stirling")

    pack_sheet({
        "pristine": render_lancaster_frame(0),
        "wing_damaged": render_lancaster_frame(1),
        "critical_wreck": render_lancaster_frame(2)
    }, cell_w=384, cell_h=256, cols=3, out_name="sheet_boss_lancaster")

# =============================================================================
# 3. SOVIET VVS FLEET
# =============================================================================
def render_la7_frame(state="level", prop=0):
    w, h = 96, 96
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2
    bank_x = -4 if state == "left" else (4 if state == "right" else 0)
    wing_tilt = -3 if state == "left" else (3 if state == "right" else 0)

    # Compact wooden wings
    wing = [(cx - 38, cy + 4 + wing_tilt), (cx - 14, cy - 6 + wing_tilt//2),
            (cx + 14, cy - 6 - wing_tilt//2), (cx + 38, cy + 4 - wing_tilt),
            (cx + 34, cy + 14 - wing_tilt), (cx - 34, cy + 14 + wing_tilt)]
    draw.polygon(wing, fill=VVS_GREY, outline=(25, 30, 35, 255))
    draw.line([(cx - 36, cy + 4 + wing_tilt), (cx + 36, cy + 4 - wing_tilt)], fill=(160, 170, 180, 255), width=2)

    # Soviet Red Stars on wings
    for sx, sign in [(-24, 1), (24, -1)]:
        wy = cy + 5 + wing_tilt * sign
        draw.polygon([(cx + sx, wy - 5), (cx + sx + 3, wy + 4), (cx + sx - 3, wy + 4)], fill=RED)
        draw.polygon([(cx + sx, wy + 4), (cx + sx + 3, wy - 2), (cx + sx - 3, wy - 2)], fill=RED)

    # Shvetsov ASh-82FN Radial Engine & Red Cowl
    draw.rectangle([cx - 8 + bank_x, cy - 34, cx + 8 + bank_x, cy - 28], fill=RED)
    draw.ellipse([cx - 16 + bank_x, cy - 38, cx + 16 + bank_x, cy - 32], fill=PROP_BLUR)

    # Fuselage & Canopy
    fuse = [(cx - 7 + bank_x, cy - 30), (cx + 7 + bank_x, cy - 30), (cx + 8 + bank_x, cy + 24),
            (cx + bank_x, cy + 36), (cx - 8 + bank_x, cy + 24)]
    draw.polygon(fuse, fill=VVS_GREY, outline=(25, 30, 35, 255))
    draw.polygon([(cx - 4 + bank_x, cy - 16), (cx + 4 + bank_x, cy - 16),
                  (cx + 5 + bank_x, cy - 2), (cx - 5 + bank_x, cy - 2)], fill=GLASS_CYAN)
    draw.rectangle([cx - 16 + bank_x//2, cy + 26, cx + 16 + bank_x//2, cy + 32], fill=VVS_GREY)
    return img

def render_il2_frame(state="level"):
    w, h = 96, 96
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2
    bank_x = -4 if state == "left" else (4 if state == "right" else 0)
    wing_tilt = -3 if state == "left" else (3 if state == "right" else 0)

    # Heavy swept wings with arrow leading edge
    wing = [(cx - 44, cy + 5 + wing_tilt), (cx - 15, cy - 7 + wing_tilt//2),
            (cx + 15, cy - 7 - wing_tilt//2), (cx + 44, cy + 5 - wing_tilt),
            (cx + 38, cy + 16 - wing_tilt), (cx - 38, cy + 16 + wing_tilt)]
    draw.polygon(wing, fill=IL2_BODY, outline=(20, 26, 18, 255))
    draw.line([(cx - 42, cy + 5 + wing_tilt), (cx + 42, cy + 5 - wing_tilt)], fill=(110, 125, 95, 255), width=2)

    # Twin 23mm VYa-23 Wing Cannons
    for gx in [-28, 28]:
        draw.line([(cx + gx, cy), (cx + gx, cy - 8)], fill=(15, 15, 15, 255), width=2)

    # Armored Cockpit Bathtub & Rear Gunner (12.7mm UBT)
    fuse = [(cx - 8 + bank_x, cy - 35), (cx + 8 + bank_x, cy - 35), (cx + 9 + bank_x, cy + 24),
            (cx + bank_x, cy + 36), (cx - 9 + bank_x, cy + 24)]
    draw.polygon(fuse, fill=IL2_BODY, outline=(20, 26, 18, 255))
    # Pilot + Gunner Glass
    draw.polygon([(cx - 4 + bank_x, cy - 18), (cx + 4 + bank_x, cy - 18), (cx + 5 + bank_x, cy + 6), (cx - 5 + bank_x, cy + 6)], fill=GLASS_CYAN)
    # Rear machine gun barrel
    draw.line([(cx + bank_x, cy + 4), (cx + bank_x, cy + 14)], fill=(15, 15, 15, 255), width=2)

    draw.ellipse([cx - 17 + bank_x, cy - 41, cx + 17 + bank_x, cy - 35], fill=PROP_BLUR)
    draw.rectangle([cx - 18 + bank_x//2, cy + 26, cx + 18 + bank_x//2, cy + 32], fill=IL2_BODY)
    return img

def render_pe2_frame(damaged=False):
    w, h = 192, 160
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    # Fast, sleek twin-engine dive bomber wings
    wing = [(cx - 86, cy + 6), (cx - 28, cy - 10), (cx + 28, cy - 10),
            (cx + 86, cy + 6), (cx + 74, cy + 24), (cx - 74, cy + 24)]
    draw.polygon(wing, fill=VVS_GREEN, outline=(20, 26, 18, 255))

    # Twin Klimov M-105 engines
    for ex in [-42, 42]:
        draw.rectangle([cx + ex - 8, cy - 34, cx + ex + 8, cy + 26], fill=VVS_GREEN)
        draw.ellipse([cx + ex - 18, cy - 42, cx + ex + 18, cy - 34], fill=PROP_BLUR)
        if damaged and ex == -42:
            draw.ellipse([cx + ex - 8, cy - 10, cx + ex + 8, cy + 12], fill=(255, 120, 20, 240))
            draw.ellipse([cx + ex - 14, cy + 10, cx + ex + 14, cy + 42], fill=(35, 38, 42, 220))

    # Needle nose & twin tail rudders
    fuse = [(cx - 10, cy - 52), (cx + 10, cy - 52), (cx + 12, cy + 42), (cx + 3, cy + 66), (cx - 3, cy + 66), (cx - 12, cy + 42)]
    draw.polygon(fuse, fill=VVS_GREEN)
    draw.polygon([(cx - 7, cy - 48), (cx + 7, cy - 48), (cx + 8, cy - 26), (cx - 8, cy - 26)], fill=GLASS_CYAN)
    # Twin H-tail
    draw.rectangle([cx - 34, cy + 50, cx + 34, cy + 58], fill=VVS_GREEN)
    draw.ellipse([cx - 38, cy + 44, cx - 28, cy + 64], fill=VVS_GREEN)
    draw.ellipse([cx + 28, cy + 44, cx + 38, cy + 64], fill=VVS_GREEN)
    return img

def render_pe8_frame(damage_stage=0):
    w, h = 384, 256
    img = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    # Heavy broad wings (span 360px)
    wing = [(cx - 180, cy + 8), (cx - 56, cy - 26), (cx + 56, cy - 26),
            (cx + 180, cy + 8), (cx + 160, cy + 46), (cx - 160, cy + 46)]
    draw.polygon(wing, fill=PE8_BODY, outline=(20, 24, 20, 255))
    draw.line([(cx - 176, cy + 12), (cx + 176, cy + 12)], fill=PE8_LIGHT, width=3)

    # Red Stars on outer wings
    for sx in [-130, 130]:
        draw.polygon([(cx + sx, cy + 16), (cx + sx + 6, cy + 32), (cx + sx - 6, cy + 32)], fill=RED)
        draw.polygon([(cx + sx, cy + 32), (cx + sx + 6, cy + 20), (cx + sx - 6, cy + 20)], fill=RED)

    # 4 Heavy Mikulin / Charomskiy diesel engine nacelles
    engines = [-120, -72, 72, 120]
    for ex in engines:
        nx = cx + ex
        draw.rectangle([nx - 11, cy - 46, nx + 11, cy + 38], fill=PE8_BODY, outline=(20, 24, 20, 255))
        draw.ellipse([nx - 26, cy - 54, nx + 26, cy - 44], fill=PROP_BLUR)

        if damage_stage >= 1 and ex == -120:
            draw.ellipse([nx - 12, cy - 18, nx + 12, cy + 4], fill=(255, 120, 20, 240))
            draw.ellipse([nx - 18, cy + 2, nx + 18, cy + 38], fill=(35, 38, 42, 220))
        if damage_stage >= 2 and ex == 120:
            draw.ellipse([nx - 14, cy - 22, nx + 14, cy + 8], fill=(255, 70, 20, 250))
            draw.ellipse([nx - 22, cy + 4, nx + 22, cy + 44], fill=(30, 32, 36, 230))

    # Heavy Fuselage & Nose Turret
    fuse = [(cx - 24, cy - 92), (cx + 24, cy - 92), (cx + 26, cy + 58), (cx + 8, cy + 112), (cx - 8, cy + 112), (cx - 26, cy + 58)]
    draw.polygon(fuse, fill=PE8_BODY, outline=(20, 24, 20, 255))
    draw.polygon([(cx - 16, cy - 90), (cx + 16, cy - 90), (cx + 18, cy - 64), (cx - 18, cy - 64)], fill=GLASS_CYAN)

    # Heavy Inboard Engine Nacelle Cannons (Unique to Pe-8!)
    for ex in [-72, 72]:
        draw.line([(cx + ex, cy + 36), (cx + ex, cy + 48)], fill=(15, 15, 15, 255), width=2)

    # Dorsal Cannon Barbette & Tail Turret
    draw.ellipse([cx - 12, cy - 8, cx + 12, cy + 16], fill=(32, 38, 32, 255))
    draw.line([(cx - 3, cy + 4), (cx - 3, cy - 12)], fill=(15, 15, 15, 255), width=2)
    draw.line([(cx + 3, cy + 4), (cx + 3, cy - 12)], fill=(15, 15, 15, 255), width=2)

    # Heavy tailplane
    draw.polygon([(cx - 68, cy + 86), (cx + 68, cy + 86), (cx + 52, cy + 108), (cx - 52, cy + 108)], fill=PE8_BODY)

    if damage_stage >= 2:
        draw.ellipse([cx - 24, cy - 40, cx + 24, cy], fill=(255, 60, 20, 240))
        draw.ellipse([cx - 36, cy - 10, cx + 36, cy + 50], fill=(30, 30, 36, 230))

    return img

def build_vvs_sheets():
    pack_sheet({
        "fly_0": render_la7_frame("level", 0), "fly_1": render_la7_frame("level", 1),
        "bank_left": render_la7_frame("left"), "bank_right": render_la7_frame("right")
    }, cell_w=96, cell_h=96, cols=4, out_name="sheet_enemy_la7")

    pack_sheet({
        "fly_0": render_il2_frame("level"), "fly_1": render_il2_frame("level"),
        "bank_left": render_il2_frame("left"), "bank_right": render_il2_frame("right")
    }, cell_w=96, cell_h=96, cols=4, out_name="sheet_enemy_il2")

    pack_sheet({
        "fly_0": render_pe2_frame(False), "fly_1": render_pe2_frame(False),
        "damaged_engine": render_pe2_frame(True)
    }, cell_w=192, cell_h=160, cols=3, out_name="sheet_enemy_pe2")

    pack_sheet({
        "pristine": render_pe8_frame(0),
        "wing_damaged": render_pe8_frame(1),
        "critical_wreck": render_pe8_frame(2)
    }, cell_w=384, cell_h=256, cols=3, out_name="sheet_boss_pe8")

def main():
    print("=== BUILDING GLOBAL ENEMY FLEET SPRITE SHEETS ===")
    print("1. Generating German Luftwaffe fleet (Fw 190, Me 262, He 111, BV 238)...")
    build_luftwaffe_sheets()
    print("2. Generating British RAF fleet (Hurricane, Typhoon, Stirling, Lancaster)...")
    build_raf_sheets()
    print("3. Generating Soviet VVS fleet (La-7, Il-2, Pe-2, Pe-8)...")
    build_vvs_sheets()
    print("=== ALL GLOBAL FLEET SPRITESHEETS SUCCESSFULLY GENERATED ===")

if __name__ == "__main__":
    main()

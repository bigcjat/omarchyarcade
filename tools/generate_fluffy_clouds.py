#!/usr/bin/env python3
"""
tools/generate_fluffy_clouds.py
Generates 6 authentic, distinct, fluffy 194X arcade cumulus and stratocumulus clouds.
No more square boxes or copy-pasted look! Each cloud has unique puff clusters,
volumetric highlights, and soft atmospheric edge feathering.
"""

import math
import random
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path

def make_puff(draw, cx, cy, r, base_color, highlight_color=None, shadow_color=None):
    """Draws a volumetric organic cloud puff with top highlight and bottom shadow."""
    bbox = [cx - r, cy - r, cx + r, cy + r]
    draw.ellipse(bbox, fill=base_color)

    if shadow_color:
        s_offset_y = int(r * 0.25)
        s_r = int(r * 0.82)
        s_bbox = [cx - s_r, cy - s_r + s_offset_y, cx + s_r, cy + s_r + s_offset_y]
        draw.ellipse(s_bbox, fill=shadow_color)

    if highlight_color:
        h_offset_x = -int(r * 0.16)
        h_offset_y = -int(r * 0.22)
        h_r = int(r * 0.70)
        h_bbox = [cx - h_r + h_offset_x, cy - h_r + h_offset_y, cx + h_r + h_offset_x, cy + h_r + h_offset_y]
        draw.ellipse(h_bbox, fill=highlight_color)

def generate_procedural_cloud(seed, style="wide", width=300, height=160):
    rng = random.Random(seed)
    scale = 2
    sw, sh = width * scale, height * scale
    canvas = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    ccx, ccy = sw // 2, int(sh * 0.52)

    # Palette: soft atmospheric whites and muted skylight blues
    C_SHADOW = (185, 205, 228, 160)
    C_MID = (235, 242, 252, 205)
    C_BRIGHT = (252, 254, 255, 235)
    C_CREST = (255, 255, 255, 250)

    puffs = []

    if style == "wide": # Wide billowy cumulus
        # Base foundation
        for i in range(8):
            ox = (i / 7.0 - 0.5) * 0.8
            oy = rng.uniform(0.1, 0.25)
            r = rng.uniform(0.24, 0.32)
            puffs.append((ox, oy, r, "base"))
        # Body
        for i in range(10):
            ox = (i / 9.0 - 0.5) * 0.75 + rng.uniform(-0.06, 0.06)
            oy = rng.uniform(-0.1, 0.1)
            r = rng.uniform(0.30, 0.40)
            puffs.append((ox, oy, r, "body"))
        # Crests
        for i in range(6):
            ox = (i / 5.0 - 0.5) * 0.6 + rng.uniform(-0.05, 0.05)
            oy = rng.uniform(-0.30, -0.15)
            r = rng.uniform(0.26, 0.35)
            puffs.append((ox, oy, r, "crest"))

    elif style == "compact": # Dense, taller puff cluster
        for i in range(6):
            ox = (i / 5.0 - 0.5) * 0.6
            oy = rng.uniform(0.12, 0.28)
            r = rng.uniform(0.26, 0.34)
            puffs.append((ox, oy, r, "base"))
        for i in range(8):
            ox = (i / 7.0 - 0.5) * 0.55 + rng.uniform(-0.06, 0.06)
            oy = rng.uniform(-0.12, 0.12)
            r = rng.uniform(0.34, 0.44)
            puffs.append((ox, oy, r, "body"))
        for i in range(5):
            ox = (i / 4.0 - 0.5) * 0.45 + rng.uniform(-0.05, 0.05)
            oy = rng.uniform(-0.35, -0.18)
            r = rng.uniform(0.28, 0.38)
            puffs.append((ox, oy, r, "crest"))

    elif style == "elongated": # Low wind-swept stratocumulus band
        for i in range(12):
            ox = (i / 11.0 - 0.5) * 0.9
            oy = rng.uniform(0.08, 0.22)
            r = rng.uniform(0.18, 0.25)
            puffs.append((ox, oy, r, "base"))
        for i in range(14):
            ox = (i / 13.0 - 0.5) * 0.88 + rng.uniform(-0.04, 0.04)
            oy = rng.uniform(-0.08, 0.08)
            r = rng.uniform(0.22, 0.32)
            puffs.append((ox, oy, r, "body"))
        for i in range(8):
            ox = (i / 7.0 - 0.5) * 0.75 + rng.uniform(-0.05, 0.05)
            oy = rng.uniform(-0.24, -0.12)
            r = rng.uniform(0.20, 0.28)
            puffs.append((ox, oy, r, "crest"))

    elif style == "asymmetric": # Dense head on left, wispy tail on right
        for i in range(7):
            ox = -0.4 + i * 0.12
            oy = rng.uniform(0.05, 0.22)
            r = (1.0 - i * 0.08) * rng.uniform(0.24, 0.32)
            puffs.append((ox, oy, r, "base"))
        for i in range(8):
            ox = -0.38 + i * 0.11 + rng.uniform(-0.04, 0.04)
            oy = rng.uniform(-0.1, 0.1)
            r = (1.0 - i * 0.09) * rng.uniform(0.32, 0.42)
            puffs.append((ox, oy, r, "body"))
        for i in range(5):
            ox = -0.35 + i * 0.12 + rng.uniform(-0.04, 0.04)
            oy = rng.uniform(-0.32, -0.16)
            r = (1.0 - i * 0.12) * rng.uniform(0.28, 0.38)
            puffs.append((ox, oy, r, "crest"))

    elif style == "twin_dome": # Double towering peaks
        # Left tower
        puffs.append((-0.24, -0.28, 0.36, "crest"))
        puffs.append((-0.26, -0.05, 0.42, "body"))
        puffs.append((-0.25, 0.18, 0.32, "base"))
        # Right tower
        puffs.append((0.22, -0.24, 0.32, "crest"))
        puffs.append((0.24, -0.04, 0.38, "body"))
        puffs.append((0.23, 0.18, 0.30, "base"))
        # Center saddle
        puffs.append((0.0, -0.10, 0.34, "crest"))
        puffs.append((0.0, 0.05, 0.40, "body"))
        puffs.append((0.0, 0.20, 0.32, "base"))
        # Flanks
        puffs.append((-0.42, 0.10, 0.24, "base"))
        puffs.append((0.42, 0.10, 0.24, "base"))

    else: # "wispy" / small scout puff
        for i in range(5):
            ox = (i / 4.0 - 0.5) * 0.7
            oy = rng.uniform(0.05, 0.2)
            r = rng.uniform(0.22, 0.30)
            puffs.append((ox, oy, r, "base"))
        for i in range(6):
            ox = (i / 5.0 - 0.5) * 0.65 + rng.uniform(-0.05, 0.05)
            oy = rng.uniform(-0.1, 0.08)
            r = rng.uniform(0.28, 0.36)
            puffs.append((ox, oy, r, "body"))
        for i in range(4):
            ox = (i / 3.0 - 0.5) * 0.5 + rng.uniform(-0.04, 0.04)
            oy = rng.uniform(-0.25, -0.12)
            r = rng.uniform(0.22, 0.30)
            puffs.append((ox, oy, r, "crest"))

    # Render base layer
    for ox, oy, r_frac, ptype in puffs:
        if ptype == "base":
            px = int(ccx + ox * sw * 0.8)
            py = int(ccy + oy * sh * 0.6)
            pr = int(sh * r_frac)
            make_puff(draw, px, py, pr, C_SHADOW, highlight_color=C_MID)

    # Render body layer
    for ox, oy, r_frac, ptype in puffs:
        if ptype == "body":
            px = int(ccx + ox * sw * 0.8)
            py = int(ccy + oy * sh * 0.6)
            pr = int(sh * r_frac)
            make_puff(draw, px, py, pr, C_MID, highlight_color=C_BRIGHT, shadow_color=C_SHADOW)

    # Render crest layer
    for ox, oy, r_frac, ptype in puffs:
        if ptype == "crest":
            px = int(ccx + ox * sw * 0.8)
            py = int(ccy + oy * sh * 0.6)
            pr = int(sh * r_frac)
            make_puff(draw, px, py, pr, C_BRIGHT, highlight_color=C_CREST, shadow_color=C_MID)

    # Soft edge atmospheric feathering
    canvas = canvas.filter(ImageFilter.GaussianBlur(radius=scale * 2.2))
    
    # Downsample back to target resolution for crisp, smooth anti-aliased contours
    final_cloud = canvas.resize((width, height), Image.Resampling.LANCZOS)
    return final_cloud

def main():
    out_dir = Path("games/skyace/sprites")
    out_dir.mkdir(parents=True, exist_ok=True)
    art_dir = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62")

    cloud_configs = [
        ("cloud_cumulus_1.png", "wide", 280, 155, 42),
        ("cloud_cumulus_2.png", "compact", 240, 145, 108),
        ("cloud_cumulus_3.png", "elongated", 340, 140, 204),
        ("cloud_cumulus_4.png", "asymmetric", 300, 160, 317),
        ("cloud_cumulus_5.png", "twin_dome", 310, 165, 429),
        ("cloud_cumulus_6.png", "wispy", 210, 120, 553),
    ]

    for filename, style, w, h, seed in cloud_configs:
        c = generate_procedural_cloud(seed=seed, style=style, width=w, height=h)
        c.save(out_dir / filename)
        c.save(art_dir / filename)
        print(f"✓ Saved {filename} ({style}, {w}x{h})")

if __name__ == "__main__":
    main()

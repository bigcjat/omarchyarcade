#!/usr/bin/env python3
"""
tools/generate_meteorological_clouds.py
Generates authentic aerial top-down representations of the meteorological cloud types
from the user's reference charts (as viewed from an aircraft cockpit / high altitude):

1. Cumulus: Classic fair-weather cotton puff cluster with rounded cauliflower domes.
2. Cirrus: High-altitude feathery ice-crystal wisps and curved mare's tails.
3. Altocumulus: "Mackerel sky" dappled field of delicate scattered cloudlets.
4. Stratocumulus: Rolling low-altitude cloud street / elongated undulating wave bands.
5. Cumulonimbus: Massive, majestic towering thunderhead with billowing core and radiating anvil.
6. Popcorn Cumulus: Small, scattered isolated cotton puffs drifting over the ocean.
"""

import math
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path

def blend_puff(canvas_arr, cx, cy, rx, ry, opacity, brightness=1.0, shadow_bias=0.0):
    """
    Renders an organic, soft volumetric puff into a numpy float array (H, W, 4).
    Uses smooth cosine/quartic falloff for soft edges without harsh disc artifacts.
    """
    h, w, _ = canvas_arr.shape
    x0 = max(0, int(cx - rx * 1.5))
    x1 = min(w, int(cx + rx * 1.5) + 1)
    y0 = max(0, int(cy - ry * 1.5))
    y1 = min(h, int(cy + ry * 1.5) + 1)
    if x1 <= x0 or y1 <= y0:
        return

    sub_y, sub_x = np.ogrid[y0:y1, x0:x1]
    dx = (sub_x - cx) / float(rx)
    dy = (sub_y - cy) / float(ry)
    dist_sq = dx*dx + dy*dy

    # Quartic falloff: (1 - r^2)^2 for r < 1
    mask = dist_sq < 1.0
    falloff = np.zeros_like(dist_sq, dtype=np.float32)
    falloff[mask] = (1.0 - dist_sq[mask]) ** 2

    # Sunlight shading: top-left is illuminated, bottom-right has soft ambient shadow
    # Light vector (-0.6, -0.6)
    sun_shading = np.clip(1.0 - (dx * 0.35 + dy * 0.45), 0.70, 1.25)
    sun_shading *= (1.0 - shadow_bias * 0.35)

    # Color components (warm sunlit white -> cool sky-shadow blue)
    # Bright: (255, 255, 255)
    # Shadow: (185, 205, 230)
    col_r = np.clip(220 * brightness * sun_shading, 175, 255)
    col_g = np.clip(232 * brightness * sun_shading, 195, 255)
    col_b = np.clip(248 * brightness * (sun_shading * 0.95 + 0.08), 215, 255)
    col_a = falloff * (opacity * 255.0)

    # Alpha blending into canvas
    dst = canvas_arr[y0:y1, x0:x1]
    src_a = col_a / 255.0
    dst_a = dst[..., 3] / 255.0
    out_a = src_a + dst_a * (1.0 - src_a)

    safe_out_a = np.where(out_a > 0.001, out_a, 1.0)
    out_r = (col_r * src_a + dst[..., 0] * dst_a * (1.0 - src_a)) / safe_out_a
    out_g = (col_g * src_a + dst[..., 1] * dst_a * (1.0 - src_a)) / safe_out_a
    out_b = (col_b * src_a + dst[..., 2] * dst_a * (1.0 - src_a)) / safe_out_a

    dst[..., 0] = np.where(out_a > 0.001, out_r, 0)
    dst[..., 1] = np.where(out_a > 0.001, out_g, 0)
    dst[..., 2] = np.where(out_a > 0.001, out_b, 0)
    dst[..., 3] = out_a * 255.0

def make_cloud_image(arr, blur_radius=1.2):
    """Converts float canvas array into anti-aliased RGBA PIL image."""
    clipped = np.clip(arr, 0, 255).astype(np.uint8)
    img = Image.fromarray(clipped, mode="RGBA")
    if blur_radius > 0:
        img = img.filter(ImageFilter.GaussianBlur(radius=blur_radius))
    return img

def render_cumulus(width=340, height=200, seed=42):
    """1. Cumulus: Classic fair-weather fluffy cotton cluster with rounded domes."""
    rng = random.Random(seed)
    arr = np.zeros((height, width, 4), dtype=np.float32)
    cx, cy = width / 2.0, height / 2.0

    # Macro lobes (main body)
    macro_lobes = [
        (-0.25, 0.05, 55, 45, 0.85, 0.95, 0.1),
        (0.0, -0.05, 65, 52, 0.92, 1.05, 0.0),
        (0.26, 0.08, 52, 42, 0.85, 0.98, 0.15),
        (-0.12, -0.18, 50, 42, 0.88, 1.08, -0.05),
        (0.14, -0.15, 54, 44, 0.90, 1.06, -0.05),
        (0.0, 0.22, 58, 36, 0.80, 0.90, 0.25), # shaded lower base
    ]
    for ox, oy, rx, ry, op, br, sb in macro_lobes:
        px = cx + ox * width
        py = cy + oy * height
        blend_puff(arr, px, py, rx, ry, op, brightness=br, shadow_bias=sb)

    # Bubbling micro-puffs (cauliflower texture)
    for ox, oy, rx, ry, _, _, _ in macro_lobes:
        px = cx + ox * width
        py = cy + oy * height
        for _ in range(8):
            ang = rng.uniform(0, 2 * math.pi)
            dist = rng.uniform(0.4, 0.9) * rx
            mx = px + dist * math.cos(ang)
            my = py + dist * math.sin(ang)
            mr = rng.uniform(16, 26)
            is_top = (my < cy)
            br = 1.08 if is_top else 0.92
            sb = -0.08 if is_top else 0.20
            blend_puff(arr, mx, my, mr, mr * 0.9, 0.75, brightness=br, shadow_bias=sb)

    # Soft outer wisps
    for _ in range(16):
        ang = rng.uniform(0, 2 * math.pi)
        dist = rng.uniform(0.65, 1.1) * (width * 0.35)
        wx = cx + dist * math.cos(ang)
        wy = cy + dist * math.sin(ang) * 0.6
        blend_puff(arr, wx, wy, rng.uniform(18, 30), rng.uniform(14, 24), 0.35, brightness=1.0)

    return make_cloud_image(arr, blur_radius=1.4)

def render_cirrus(width=360, height=150, seed=77):
    """2. Cirrus: Delicate, high-altitude sweeping feathery wisps and mare's tails."""
    rng = random.Random(seed)
    arr = np.zeros((height, width, 4), dtype=np.float32)

    n_bands = 6
    for b in range(n_bands):
        start_x = rng.uniform(30, 80)
        start_y = 25 + b * 20 + rng.uniform(-6, 6)
        length = rng.uniform(width * 0.65, width * 0.85)
        
        n_puffs = 28
        for p in range(n_puffs):
            t = p / float(n_puffs - 1)
            # Gentle sweeping curve with hooked ends (mare's tail)
            px = start_x + t * length
            arch = math.sin(t * 2.8) * 18.0 - (t * t * 16.0)
            py = start_y + arch + rng.uniform(-3, 3)
            
            # Tapering radius and gentle opacity
            rx = rng.uniform(16, 28) * (1.0 - t * 0.4)
            ry = rng.uniform(8, 14) * (1.0 - t * 0.5)
            op = (1.0 - t * 0.45) * rng.uniform(0.35, 0.55)
            blend_puff(arr, px, py, rx, ry, op, brightness=1.05)

            # Feather filaments peeling off
            if p % 4 == 0 and t > 0.15:
                fx = px + rng.uniform(10, 25)
                fy = py - rng.uniform(8, 22)
                blend_puff(arr, fx, fy, rx * 0.6, ry * 0.5, op * 0.5, brightness=1.08)

    return make_cloud_image(arr, blur_radius=1.8)

def render_altocumulus(width=340, height=180, seed=123):
    """3. Altocumulus: 'Mackerel sky' field of small dappled cotton cloudlets."""
    rng = random.Random(seed)
    arr = np.zeros((height, width, 4), dtype=np.float32)

    rows = 5
    cols = 8
    for r in range(rows):
        for c in range(cols):
            stagger = (r % 2) * 0.5
            nx = (c + stagger) / (cols + 0.5)
            ny = r / float(rows - 1)
            
            # Elliptical cluster boundary
            dx = (nx - 0.5) * 2.0
            dy = (ny - 0.5) * 2.0
            if (dx*dx + dy*dy) > 0.85:
                continue

            cx = 40 + nx * (width - 80) + rng.uniform(-10, 10)
            cy = 30 + ny * (height - 60) + rng.uniform(-8, 8)
            
            # Individual small cotton puff
            rx = rng.uniform(14, 22)
            ry = rng.uniform(11, 17)
            # Base shadow
            blend_puff(arr, cx, cy + 3, rx, ry, 0.70, brightness=0.90, shadow_bias=0.25)
            # Illuminated crest
            blend_puff(arr, cx - 2, cy - 2, rx * 0.85, ry * 0.85, 0.82, brightness=1.08, shadow_bias=-0.1)

    return make_cloud_image(arr, blur_radius=1.2)

def render_stratocumulus(width=380, height=160, seed=88):
    """4. Stratocumulus: Low elongated undulating cloud street / rolling horizontal waves."""
    rng = random.Random(seed)
    arr = np.zeros((height, width, 4), dtype=np.float32)

    n_rolls = 16
    for i in range(n_rolls):
        t = i / float(n_rolls - 1)
        cx = 35 + t * (width - 70) + rng.uniform(-8, 8)
        # Undulating gentle wave along length
        cy = height * 0.5 + math.sin(t * math.pi * 3.2) * 16.0 + rng.uniform(-6, 6)

        rx = rng.uniform(28, 42)
        ry = rng.uniform(18, 28)

        # Underbelly shadow
        blend_puff(arr, cx, cy + 6, rx, ry, 0.75, brightness=0.88, shadow_bias=0.30)
        # Main roll body
        blend_puff(arr, cx, cy, rx * 0.95, ry * 0.9, 0.85, brightness=0.98, shadow_bias=0.05)
        # Top-lit ripple
        blend_puff(arr, cx - 3, cy - 4, rx * 0.75, ry * 0.7, 0.90, brightness=1.06, shadow_bias=-0.15)

    return make_cloud_image(arr, blur_radius=1.5)

def render_cumulonimbus(width=360, height=240, seed=999):
    """5. Cumulonimbus: Massive towering thunderhead with billowing core and broad anvil."""
    rng = random.Random(seed)
    arr = np.zeros((height, width, 4), dtype=np.float32)
    cx, cy = width / 2.0, height / 2.0

    # 1. Broad radiating cirrus anvil shelf (top-most layer of ice crystals spreading out)
    anvil_w = width * 0.44
    anvil_h = height * 0.22
    for _ in range(24):
        ang = rng.uniform(0, 2 * math.pi)
        dist = rng.uniform(0.3, 1.0)
        ax = cx + dist * math.cos(ang) * anvil_w
        ay = (cy - 40) + dist * math.sin(ang) * anvil_h
        ar_x = rng.uniform(30, 55)
        ar_y = rng.uniform(18, 35)
        blend_puff(arr, ax, ay, ar_x, ar_y, 0.55, brightness=1.08)

    # 2. Dense central convective updraft core (blindingly bright cauliflower dome)
    core_puffs = [
        (0.0, -0.15, 65, 55, 0.95, 1.10, -0.1),  # Top central dome
        (-0.20, -0.05, 55, 48, 0.92, 1.08, -0.05),
        (0.20, -0.08, 56, 48, 0.92, 1.06, -0.05),
        (-0.12, 0.12, 58, 50, 0.90, 0.98, 0.15),
        (0.14, 0.10, 60, 52, 0.90, 0.95, 0.18),
        (0.0, 0.28, 68, 52, 0.88, 0.85, 0.35),   # Stormy shaded lower base
    ]
    for ox, oy, rx, ry, op, br, sb in core_puffs:
        px = cx + ox * width
        py = cy + oy * height
        blend_puff(arr, px, py, rx, ry, op, brightness=br, shadow_bias=sb)
        # Micro cauliflower bumps
        for _ in range(7):
            ang = rng.uniform(0, 2 * math.pi)
            dist = rng.uniform(0.4, 0.9) * rx
            mx = px + dist * math.cos(ang)
            my = py + dist * math.sin(ang)
            blend_puff(arr, mx, my, rng.uniform(18, 28), rng.uniform(15, 24), 0.80, brightness=br, shadow_bias=sb)

    return make_cloud_image(arr, blur_radius=1.6)

def render_popcorn_cumulus(width=220, height=140, seed=333):
    """6. Popcorn Cumulus: Small, scattered cotton-ball puffs (Photo 2 / Humilis)."""
    rng = random.Random(seed)
    arr = np.zeros((height, width, 4), dtype=np.float32)
    cx, cy = width / 2.0, height / 2.0

    # 3-4 small overlapping cotton puffs
    puffs = [
        (-0.18, 0.05, 36, 28, 0.85, 0.95, 0.15),
        (0.05, -0.08, 42, 34, 0.92, 1.08, -0.10),
        (0.22, 0.08, 34, 26, 0.85, 0.96, 0.12),
        (-0.02, 0.15, 32, 22, 0.80, 0.88, 0.25),
    ]
    for ox, oy, rx, ry, op, br, sb in puffs:
        px = cx + ox * width
        py = cy + oy * height
        blend_puff(arr, px, py, rx, ry, op, brightness=br, shadow_bias=sb)

    return make_cloud_image(arr, blur_radius=1.2)

def main():
    sprites_dir = Path("games/skyace/sprites")
    sprites_dir.mkdir(parents=True, exist_ok=True)
    art_dir = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62")

    generators = [
        ("cloud_cumulus.png", render_cumulus(340, 200, seed=42), "Cumulus (Fair Weather Cotton Heap)"),
        ("cloud_cirrus.png", render_cirrus(360, 150, seed=77), "Cirrus (Sweeping Feather Wisps)"),
        ("cloud_altocumulus.png", render_altocumulus(340, 180, seed=123), "Altocumulus (Mackerel Dappled Sky)"),
        ("cloud_stratocumulus.png", render_stratocumulus(380, 160, seed=88), "Stratocumulus (Rolling Cloud Waves)"),
        ("cloud_cumulonimbus.png", render_cumulonimbus(360, 240, seed=999), "Cumulonimbus (Towering Thunderhead Anvil)"),
        ("cloud_popcorn.png", render_popcorn_cumulus(220, 140, seed=333), "Popcorn Cumulus (Scattered Cotton Puff)"),
    ]

    for filename, img, label in generators:
        img.save(sprites_dir / filename)
        img.save(art_dir / filename)
        print(f"✓ Created {filename} • {label}")

    # Synchronize backward-compatible 1..6 names
    for idx, (filename, img, label) in enumerate(generators, start=1):
        compat_name = f"cloud_cumulus_{idx}.png"
        img.save(sprites_dir / compat_name)
        img.save(art_dir / compat_name)
        print(f"  -> Linked {compat_name}")

if __name__ == "__main__":
    main()

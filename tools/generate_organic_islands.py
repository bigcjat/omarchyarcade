#!/usr/bin/env python3
"""
tools/generate_organic_islands.py
Generates authentic 194X arcade Pacific and European island landmasses.
Features smooth natural coastlines, shallow turquoise reef gradients, golden sand beaches,
textured tropical jungle canopies, rocky mountain ridges, and WWII airfields.
"""

import math
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path

def generate_smooth_island_mask(w, h, seed, style="atoll"):
    """Generates an organic, smooth, continuous island heightmap/distance field."""
    rng = random.Random(seed)
    np_rng = np.random.RandomState(seed)

    y, x = np.ogrid[:h, :w]
    cx, cy = w / 2.0, h / 2.0
    nx = (x - cx) / (w / 2.0)
    ny = (y - cy) / (h / 2.0)
    dist = np.sqrt(nx * nx + ny * ny)

    # Base shape harmonics
    angle = np.arctan2(ny, nx)
    
    if style == "atoll": # Crescent-shaped atoll with a lagoon
        r_base = 0.62 + 0.14 * np.sin(angle * 2.0 + 0.5) + 0.08 * np.sin(angle * 4.0)
        # Cutout lagoon offset from center
        lagoon_dist = np.sqrt((nx - 0.18)**2 + (ny - 0.12)**2)
        field = np.clip(1.0 - (dist / r_base), 0.0, 1.0)
        lagoon_dip = np.clip(1.0 - (lagoon_dist / 0.32), 0.0, 1.0)
        field = np.clip(field - lagoon_dip * 0.9, 0.0, 1.0)

    elif style == "mountain": # Volcanic ridge island with deep bays
        r_base = 0.68 + 0.18 * np.cos(angle * 3.0 - 0.4) + 0.12 * np.sin(angle * 5.0)
        field = np.clip(1.0 - (dist / r_base), 0.0, 1.0)

    else: # "archipelago" - two main bodies connected by a sand spit
        d1 = np.sqrt((nx + 0.32)**2 + (ny - 0.05)**2) / 0.42
        d2 = np.sqrt((nx - 0.28)**2 + (ny + 0.08)**2) / 0.36
        spit = np.sqrt((nx * 0.5)**2 + (ny - 0.02)**2) / 0.25
        field = np.maximum(np.clip(1.0 - d1, 0, 1), np.clip(1.0 - d2, 0, 1))
        field = np.maximum(field, np.clip(1.0 - spit, 0, 1) * 0.62)

    # Multi-octave organic noise for natural coastlines
    noise = np.zeros((h, w), dtype=np.float32)
    for oct in range(4):
        freq = (oct + 1) * 3.5
        phase = rng.uniform(0, 100)
        n = (np.sin(nx * freq + phase) * np.cos(ny * freq - phase) +
             np.sin(ny * freq * 1.2) * np.cos(nx * freq * 0.9)) * 0.5
        noise += n / (oct + 1.5)

    field = np.clip(field + noise * 0.12, 0.0, 1.0)
    return field

def render_island(field, style="atoll", width=280, height=280, seed=101):
    rng = random.Random(seed)
    h, w = field.shape
    rgba = np.zeros((h, w, 4), dtype=np.uint8)

    # Thresholds:
    # 0.00 to 0.12: Deep water / transparent
    # 0.12 to 0.28: Shallow coral reef (turquoise)
    # 0.28 to 0.36: Breaker surf / wet sand / beach
    # 0.36 to 0.55: Lowland jungle / palm forest
    # 0.55 to 1.00: Mountain ridge / high jungle

    # 1. Shallow Coral Reef
    reef_mask = (field >= 0.10) & (field < 0.30)
    reef_t = np.clip((field - 0.10) / 0.20, 0, 1)
    rgba[reef_mask, 0] = (24 + reef_t[reef_mask] * 12).astype(np.uint8)   # R
    rgba[reef_mask, 1] = (155 + reef_t[reef_mask] * 40).astype(np.uint8)  # G
    rgba[reef_mask, 2] = (180 + reef_t[reef_mask] * 25).astype(np.uint8)  # B
    rgba[reef_mask, 3] = (reef_t[reef_mask] * 210).astype(np.uint8)      # Alpha

    # Surf line along outer reef edge
    surf_mask = (field >= 0.10) & (field < 0.14) & (np.random.RandomState(seed).rand(h, w) > 0.35)
    rgba[surf_mask, 0] = 235
    rgba[surf_mask, 1] = 252
    rgba[surf_mask, 2] = 255
    rgba[surf_mask, 3] = 190

    # 2. Golden Sandy Beach
    sand_mask = (field >= 0.30) & (field < 0.42)
    sand_t = np.clip((field - 0.30) / 0.12, 0, 1)
    # Warm golden sand: (236, 218, 162) -> (220, 196, 142)
    rgba[sand_mask, 0] = (220 + sand_t[sand_mask] * 16).astype(np.uint8)
    rgba[sand_mask, 1] = (198 + sand_t[sand_mask] * 20).astype(np.uint8)
    rgba[sand_mask, 2] = (144 + sand_t[sand_mask] * 18).astype(np.uint8)
    rgba[sand_mask, 3] = 255

    # 3. Lush Tropical Jungle
    jungle_mask = field >= 0.42
    jungle_t = np.clip((field - 0.42) / 0.58, 0, 1)
    # Deep vibrant greens: (32, 85, 42) -> (48, 130, 64)
    rgba[jungle_mask, 0] = (30 + jungle_t[jungle_mask] * 26).astype(np.uint8)
    rgba[jungle_mask, 1] = (78 + jungle_t[jungle_mask] * 48).astype(np.uint8)
    rgba[jungle_mask, 2] = (38 + jungle_t[jungle_mask] * 24).astype(np.uint8)
    rgba[jungle_mask, 3] = 255

    # High elevation rocky ridge (for mountain style)
    if style == "mountain":
        rock_mask = field >= 0.68
        rock_t = np.clip((field - 0.68) / 0.32, 0, 1)
        rgba[rock_mask, 0] = (90 + rock_t[rock_mask] * 40).astype(np.uint8)
        rgba[rock_mask, 1] = (95 + rock_t[rock_mask] * 40).astype(np.uint8)
        rgba[rock_mask, 2] = (105 + rock_t[rock_mask] * 45).astype(np.uint8)

    img = Image.fromarray(rgba, mode="RGBA")
    draw = ImageDraw.Draw(img)

    # 4. Textured Canopy Tree Clusters
    tree_rng = random.Random(seed + 99)
    ys, xs = np.where(jungle_mask)
    if len(xs) > 0:
        # Sample points to plant tree puffs
        n_trees = len(xs) // 14
        indices = tree_rng.sample(range(len(xs)), min(n_trees, len(xs)))
        for idx in indices:
            tx, ty = xs[idx], ys[idx]
            tr = tree_rng.uniform(4, 9)
            # Shade bottom
            draw.ellipse([tx - tr, ty - tr + 1, tx + tr, ty + tr + 1], fill=(18, 52, 26, 255))
            # Mid canopy
            draw.ellipse([tx - tr, ty - tr, tx + tr, ty + tr], fill=(42, 115, 58, 255))
            # Sunlit crown
            hr = tr * 0.6
            draw.ellipse([tx - hr - 1, ty - hr - 1, tx + hr - 1, ty + hr - 1], fill=(62, 158, 80, 255))

    # 5. Tactical Features (Airfield, Hangars, Watchtowers)
    if style == "atoll":
        # Military airstrip
        cx, cy = w // 2 - 25, h // 2
        rw_w, rw_h = 18, 120
        # Dark asphalt / crushed coral runway
        draw.rectangle([cx - rw_w//2, cy - rw_h//2, cx + rw_w//2, cy + rw_h//2], fill=(55, 58, 64, 255), outline=(40, 42, 46, 255))
        # Centerline dashes
        for dy in range(cy - rw_h//2 + 8, cy + rw_h//2 - 8, 14):
            draw.line([(cx, dy), (cx, dy + 7)], fill=(245, 245, 245, 255), width=2)
        # Threshold piano keys
        for off in range(-6, 7, 3):
            draw.line([(cx + off, cy - rw_h//2 + 3), (cx + off, cy - rw_h//2 + 8)], fill=(255, 255, 255, 255), width=1)
            draw.line([(cx + off, cy + rw_h//2 - 8), (cx + off, cy + rw_h//2 - 3)], fill=(255, 255, 255, 255), width=1)
        # Hangar buildings
        draw.rectangle([cx + 14, cy - 20, cx + 30, cy - 8], fill=(85, 80, 75, 255), outline=(35, 34, 32, 255))
        draw.rectangle([cx + 14, cy + 6, cx + 30, cy + 18], fill=(85, 80, 75, 255), outline=(35, 34, 32, 255))

    elif style == "mountain":
        # Coastal AA gun revetment & radar mast
        gx, gy = w // 2 + 35, h // 2 + 25
        draw.ellipse([gx - 10, gy - 10, gx + 10, gy + 10], fill=(75, 80, 85, 255), outline=(45, 48, 52, 255))
        draw.ellipse([gx - 5, gy - 5, gx + 5, gy + 5], fill=(35, 38, 42, 255))
        draw.line([(gx, gy), (gx + 12, gy - 5)], fill=(20, 22, 25, 255), width=2)

    # Soft edge anti-aliasing
    img = img.filter(ImageFilter.GaussianBlur(radius=0.6))
    return img.resize((width, height), Image.Resampling.LANCZOS)

def main():
    sprites_dir = Path("games/skyace/sprites")
    sprites_dir.mkdir(parents=True, exist_ok=True)
    art_dir = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62")

    # High-resolution supersampled generation
    f1 = generate_smooth_island_mask(400, 400, seed=101, style="atoll")
    img1 = render_island(f1, style="atoll", width=280, height=280, seed=101)
    img1.save(sprites_dir / "island_atoll_1.png")
    img1.save(art_dir / "island_atoll_1.png")
    print("✓ Created island_atoll_1.png (Coral Atoll with Airfield)")

    f2 = generate_smooth_island_mask(400, 400, seed=202, style="mountain")
    img2 = render_island(f2, style="mountain", width=260, height=260, seed=202)
    img2.save(sprites_dir / "island_atoll_2.png")
    img2.save(art_dir / "island_atoll_2.png")
    print("✓ Created island_atoll_2.png (Volcanic Ridge Mountain Island)")

    f3 = generate_smooth_island_mask(440, 360, seed=303, style="archipelago")
    img3 = render_island(f3, style="archipelago", width=280, height=220, seed=303)
    img3.save(sprites_dir / "island_atoll_3.png")
    img3.save(art_dir / "island_atoll_3.png")
    print("✓ Created island_atoll_3.png (Archipelago & Sandbar Chain)")

if __name__ == "__main__":
    main()

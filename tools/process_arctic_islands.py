#!/usr/bin/env python3
"""
tools/process_arctic_islands.py
Processes the user's 5 authentic Arctic/Canada circular island artworks:
1. island_arctic_1: Frozen Flak Bunker & Icebound Landing Ship
2. island_arctic_2: Penguin Colony & Harbor Seal
3. island_arctic_3: Glacial Ice Spire Fortress & Sea Cave
4. island_arctic_4: Dual Igloos with Warm Firelight
5. island_arctic_5: Arctic Airfield & Snow Runway (27/09) with Fighter & Hangar

Applies smooth radial alpha feathering to blend seamlessly into cold North Atlantic ocean waters.
"""

import numpy as np
from PIL import Image
from pathlib import Path

def process_arctic_island(source_path, target_size=340):
    img = Image.open(source_path).convert("RGBA")
    w, h = img.size # 1024, 559

    cx, cy = w // 2, h // 2
    crop_w, crop_h = 680, 680
    pad_y = (crop_h - h) // 2
    
    corner_col = tuple(img.getpixel((15, 15))[:3])
    
    sq_img = Image.new("RGBA", (crop_w, crop_h), corner_col + (255,))
    src_crop_x0 = max(0, cx - crop_w // 2)
    src_crop_x1 = min(w, cx + crop_w // 2)
    sub = img.crop((src_crop_x0, 0, src_crop_x1, h))
    sq_img.paste(sub, (0, pad_y))

    arr = np.array(sq_img).astype(np.float32)
    sh, sw, _ = arr.shape
    scy, scx = sh / 2.0, sw / 2.0

    y, x = np.ogrid[:sh, :sw]
    dx = (x - scx) / (sw * 0.44)
    dy = (y - scy) / (sh * 0.40)
    dist = np.sqrt(dx*dx + dy*dy)

    r_solid = 0.82
    r_zero = 1.00

    alpha = np.ones_like(dist, dtype=np.float32)
    fade_mask = (dist >= r_solid) & (dist < r_zero)
    t = (dist[fade_mask] - r_solid) / (r_zero - r_solid)
    alpha[fade_mask] = 0.5 * (1.0 + np.cos(t * np.pi))
    alpha[dist >= r_zero] = 0.0

    arr[:, :, 3] = np.clip(alpha * 255.0, 0, 255)
    feathered_img = Image.fromarray(arr.astype(np.uint8), mode="RGBA")

    # Resize to target game dimension
    return feathered_img.resize((target_size, target_size), Image.Resampling.LANCZOS)

def main():
    user_dir = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62/.user_uploaded")
    dest_dir = Path("games/skyace/sprites")
    dest_dir.mkdir(parents=True, exist_ok=True)
    art_dir = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62")

    arctic_sources = [
        ("island_arctic_1", user_dir / "media_1789028496363.jpg", "Frozen Flak Bunker & Ship"),
        ("island_arctic_2", user_dir / "media_1789028543952.jpg", "Penguin Colony & Seal"),
        ("island_arctic_3", user_dir / "media_1789028615259.jpg", "Glacial Spire Fortress"),
        ("island_arctic_4", user_dir / "media_1789028773099.jpg", "Dual Igloos with Firelight"),
        ("island_arctic_5", user_dir / "media_1789028960862.jpg", "Arctic Runway 27/09 & Hangar"),
    ]

    print("[Sky Ace] Processing 5 authentic Arctic/Canada circular islands...")
    for fname, src, label in arctic_sources:
        if not src.exists():
            print(f"Error: missing source {src}")
            continue
        island_img = process_arctic_island(src, target_size=340)
        out_spr = dest_dir / f"{fname}.png"
        out_art = art_dir / f"{fname}.png"
        island_img.save(out_spr)
        island_img.save(out_art)
        print(f"✓ Saved {fname}.png ({label})")

if __name__ == "__main__":
    main()

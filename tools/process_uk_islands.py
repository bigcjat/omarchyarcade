#!/usr/bin/env python3
"""
tools/process_uk_islands.py
Processes the user's 5 authentic UK/British Channel circular island artworks:
1. island_uk_1: Coastal Lighthouse, Slate Cottages & Fishing Trawler
2. island_uk_2: Norman Stone Castle Keep, Curtain Wall & Pier
3. island_uk_3: Quaint English Village Green, Thatched Cottages & Parish Church
4. island_uk_4: Fortified RAF Coastal Airfield & Hardstands with Parked Fighters
5. island_uk_5: Heavy Coastal Flak Bastion & Concrete Airbase Fortress

Applies smooth radial alpha feathering to blend seamlessly into English Channel & North Sea waters.
"""

import numpy as np
from PIL import Image
from pathlib import Path

def process_uk_island(source_path, target_size=340):
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

    uk_sources = [
        ("island_uk_1", user_dir / "media_1789029028432.jpg", "Coastal Lighthouse & Slate Cottages"),
        ("island_uk_2", user_dir / "media_1789029076374.jpg", "Norman Castle Keep & Curtain Wall"),
        ("island_uk_3", user_dir / "media_1789029139744.jpg", "Thatched English Village & Parish Church"),
        ("island_uk_4", user_dir / "media_1789029203156.jpg", "RAF Coastal Airfield & Hardstands"),
        ("island_uk_5", user_dir / "media_1789029208221.jpg", "Heavy Flak Bastion Airfield Fortress"),
    ]

    print("[Sky Ace] Processing 5 authentic UK/British Channel circular islands...")
    for fname, src, label in uk_sources:
        if not src.exists():
            print(f"Error: missing source {src}")
            continue
        island_img = process_uk_island(src, target_size=340)
        out_spr = dest_dir / f"{fname}.png"
        out_art = art_dir / f"{fname}.png"
        island_img.save(out_spr)
        island_img.save(out_art)
        print(f"✓ Saved {fname}.png ({label})")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
tools/process_user_islands.py
Processes the user's 5 authentic circular island artworks:
Preserves full coral reefs, piers, seaplanes, and shallows with smooth elliptical/radial alpha fading.
"""

import numpy as np
from PIL import Image
from pathlib import Path

def process_island_image(source_path, target_size=340):
    img = Image.open(source_path).convert("RGBA")
    w, h = img.size # 1024, 559

    # We want a square crop centered on the island
    # Center is (512, 280)
    cx, cy = w // 2, h // 2
    
    # Pad top and bottom slightly by sampling the corner ocean color
    # to create a generous square canvas of 680 x 680
    crop_w = 680
    crop_h = 680
    pad_y = (crop_h - h) // 2 # ~60px top and bottom
    
    # Corner ocean color
    corner_col = tuple(img.getpixel((15, 15))[:3]) # (8, 32, 57)
    
    # Create padded square image
    sq_img = Image.new("RGBA", (crop_w, crop_h), corner_col + (255,))
    # Paste centered
    src_crop_x0 = max(0, cx - crop_w // 2)
    src_crop_x1 = min(w, cx + crop_w // 2)
    sub = img.crop((src_crop_x0, 0, src_crop_x1, h))
    sq_img.paste(sub, (0, pad_y))

    # Calculate distance from center (scaled by aspect ratio of the reef)
    # The reef is slightly wider than it is tall
    arr = np.array(sq_img).astype(np.float32)
    sh, sw, _ = arr.shape
    scy, scx = sh / 2.0, sw / 2.0

    y, x = np.ogrid[:sh, :sw]
    dx = (x - scx) / (sw * 0.44) # horizontal reef radius
    dy = (y - scy) / (sh * 0.40) # vertical reef radius
    dist = np.sqrt(dx*dx + dy*dy)

    # Smooth alpha feathering:
    # 0.00 to 0.82: 100% solid (all reef, seaplanes, pier, turquoise water, beach, jungle)
    # 0.82 to 1.00: smooth cosine fade into transparent
    # > 1.00: 100% transparent
    r_solid = 0.82
    r_zero = 1.00

    alpha = np.ones_like(dist, dtype=np.float32)
    fade_mask = (dist >= r_solid) & (dist < r_zero)
    t = (dist[fade_mask] - r_solid) / (r_zero - r_solid)
    alpha[fade_mask] = 0.5 * (1.0 + np.cos(t * np.pi))
    alpha[dist >= r_zero] = 0.0

    arr[..., 3] = alpha * 255.0
    out_img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), mode="RGBA")
    
    # Resize to high-resolution sprite
    final_img = out_img.resize((target_size, target_size), Image.Resampling.LANCZOS)
    return final_img

def main():
    user_upload_dir = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62/.user_uploaded")
    sprites_dir = Path("games/skyace/sprites")
    sprites_dir.mkdir(parents=True, exist_ok=True)
    art_dir = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62")

    islands_map = [
        ("island_atoll_1.png", user_upload_dir / "media_1789026356843.jpg", "WWII Airfield & Seaplane Pier"),
        ("island_atoll_2.png", user_upload_dir / "media_1789026364366.jpg", "Volcano Crater & Lava Caldera"),
        ("island_atoll_3.png", user_upload_dir / "media_1789026422248.jpg", "Secret Lagoon & Banyan Canopy"),
        ("island_atoll_4.png", user_upload_dir / "media_1789026493535.jpg", "Lone Palm Rippled Sandbar"),
        ("island_atoll_5.png", user_upload_dir / "media_1789026559553.jpg", "Coastal Flak Bunker & Landing Craft"),
    ]

    for filename, src_path, label in islands_map:
        if not src_path.exists():
            print(f"Error: {src_path} not found!")
            continue
        processed = process_island_image(src_path, target_size=340)
        processed.save(sprites_dir / filename)
        processed.save(art_dir / filename)
        print(f"✓ Successfully processed {filename} • {label}")

if __name__ == "__main__":
    main()

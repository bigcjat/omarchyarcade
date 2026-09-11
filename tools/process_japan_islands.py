#!/usr/bin/env python3
import numpy as np
from PIL import Image
from pathlib import Path

def process_island_image(source_path, target_size=360):
    img = Image.open(source_path).convert("RGBA")
    w, h = img.size # 1024, 559
    cx, cy = w // 2, h // 2
    
    crop_w = 680
    crop_h = 680
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

    arr[..., 3] = alpha * 255.0
    out_img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), mode="RGBA")
    final_img = out_img.resize((target_size, target_size), Image.Resampling.LANCZOS)
    return final_img

def main():
    user_upload_dir = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62/.user_uploaded")
    artifact_dir = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62")
    sprites_dir = Path("games/skyace/sprites")

    japan_sources = [
        ("media_1789030681466.jpg", "island_japan_1.png", "Japanese Feudal Castle with Torii Gate & Fishing Pier"),
        ("media_1789030720529.jpg", "island_japan_2.png", "Overgrown Wisteria Fortress with Courtyard Gardens"),
        ("media_1789030765633.jpg", "island_japan_3.png", "Coastal Island Airfield with Military Tent & Parked Fighters"),
        ("media_1789030828478.jpg", "island_japan_4.png", "Terraced Rice Paddies, Watermill & Traditional Farmhouse"),
        ("media_1789030853558.jpg", "island_japan_5.png", "Pagoda Temple Complex with Arched Red Bridge & Koi Pond")
    ]

    for filename, out_name, title in japan_sources:
        src = user_upload_dir / filename
        if src.exists():
            proc = process_island_image(src, target_size=360)
            dst1 = sprites_dir / out_name
            dst2 = artifact_dir / out_name
            proc.save(dst1, format="PNG")
            proc.save(dst2, format="PNG")
            print(f"✓ Processed {out_name}: {title} ({proc.size})")
        else:
            print(f"✗ File not found: {src}")

if __name__ == "__main__":
    main()

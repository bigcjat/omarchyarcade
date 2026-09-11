#!/usr/bin/env python3
"""
Process mainland scenery, tanks, bunkers, flak emplacements, and military structures
into transparent, cel-shaded arcade sprites for Sky Ace Round 1 and Round 3.
"""

import os
import glob
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
import numpy as np

ARTIFACT_DIR = "/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62"
OUTPUT_DIR = "/Users/christhompson/arcade/games/skyace/sprites"
os.makedirs(OUTPUT_DIR, exist_ok=True)

from collections import deque

def remove_white_background(img, thresh=190):
    """Cleanly remove white background using border flood fill, preserving internal white symbols."""
    img = img.convert("RGBA")
    arr = np.array(img)
    h, w = arr.shape[:2]
    
    # Is candidate background pixel
    is_bg = (arr[:, :, 0] >= thresh) & (arr[:, :, 1] >= thresh) & (arr[:, :, 2] >= thresh)
    
    visited = np.zeros((h, w), dtype=bool)
    queue = deque()
    
    for x in range(w):
        if is_bg[0, x] and not visited[0, x]:
            visited[0, x] = True
            queue.append((0, x))
        if is_bg[h-1, x] and not visited[h-1, x]:
            visited[h-1, x] = True
            queue.append((h-1, x))
    for y in range(h):
        if is_bg[y, 0] and not visited[y, 0]:
            visited[y, 0] = True
            queue.append((y, 0))
        if is_bg[y, w-1] and not visited[y, w-1]:
            visited[y, w-1] = True
            queue.append((y, w-1))
            
    while queue:
        cy, cx = queue.popleft()
        for dy, dx in [(-1,0), (1,0), (0,-1), (0,1)]:
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx]:
                if is_bg[ny, nx]:
                    visited[ny, nx] = True
                    queue.append((ny, nx))
                    
    arr[visited, 3] = 0
    return Image.fromarray(arr, "RGBA")

def tight_crop(img, padding=4):
    """Crop image to non-transparent bounding box."""
    bbox = img.getbbox()
    if bbox:
        x0 = max(0, bbox[0] - padding)
        y0 = max(0, bbox[1] - padding)
        x1 = min(img.width, bbox[2] + padding)
        y1 = min(img.height, bbox[3] + padding)
        return img.crop((x0, y0, x1, y1))
    return img

def create_damaged_variant(img):
    """Create damaged version with scorch marks and battle damage."""
    damaged = img.copy()
    w, h = damaged.size
    
    # Darken slightly
    enhancer = ImageEnhance.Color(damaged)
    damaged = enhancer.enhance(0.85)
    
    # Add scorch overlay
    scorch = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(scorch)
    
    # Burn patches (soft feathered soot, NO cartoon red/yellow circles)
    np.random.seed(42)
    for _ in range(4):
        cx = int(w * np.random.uniform(0.25, 0.75))
        cy = int(h * np.random.uniform(0.25, 0.75))
        rad_x = int(w * np.random.uniform(0.10, 0.20))
        rad_y = int(h * np.random.uniform(0.10, 0.20))
        draw.ellipse([cx - rad_x, cy - rad_y, cx + rad_x, cy + rad_y], fill=(22, 18, 16, 120))
        draw.ellipse([cx - rad_x//2, cy - rad_y//2, cx + rad_x//2, cy + rad_y//2], fill=(12, 10, 8, 160))
        
    scorch = scorch.filter(ImageFilter.GaussianBlur(1.5))
    damaged = Image.alpha_composite(damaged, scorch)
    return damaged

def create_wreck_variant(img):
    """Create burned wreck variant with charred silhouette, soot stains, and blast craters."""
    w, h = img.size
    p_arr = np.array(img, dtype=float)
    alpha = p_arr[:, :, 3]
    
    # Charred dark charcoal tones
    lum = 0.299 * p_arr[:, :, 0] + 0.587 * p_arr[:, :, 1] + 0.114 * p_arr[:, :, 2]
    charred_lum = lum * 0.32 + 10.0
    
    out_arr = np.zeros_like(p_arr)
    out_arr[:, :, 0] = np.clip(charred_lum + 8.0, 0, 255)
    out_arr[:, :, 1] = np.clip(charred_lum + 4.0, 0, 255)
    out_arr[:, :, 2] = np.clip(charred_lum + 2.0, 0, 255)
    out_arr[:, :, 3] = alpha
    
    base_wreck = Image.fromarray(out_arr.astype(np.uint8), "RGBA")
    
    # Blast holes / charred craters with feathered soot
    scorch = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(scorch)
    np.random.seed(99)
    for _ in range(5):
        cx = int(w * np.random.uniform(0.25, 0.75))
        cy = int(h * np.random.uniform(0.25, 0.75))
        rad = int(min(w, h) * np.random.uniform(0.12, 0.24))
        draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=(8, 6, 5, 200))
        
    scorch = scorch.filter(ImageFilter.GaussianBlur(1.8))
    wreck = Image.alpha_composite(base_wreck, scorch)
    
    # Mask back by original alpha
    w_arr = np.array(wreck)
    w_arr[:, :, 3] = np.minimum(w_arr[:, :, 3], alpha.astype(np.uint8))
    return Image.fromarray(w_arr, "RGBA")

def make_seamless_vertical(img, seam_size=120):
    """Blend top and bottom edges so the texture tiles seamlessly vertically."""
    w, h = img.size
    arr = np.array(img).astype(np.float32)
    
    # Top seam and bottom seam blend
    for y in range(seam_size):
        alpha = y / float(seam_size) # 0 at very top, 1 at bottom of seam
        # Blend top row y with bottom row (h - seam_size + y)
        bottom_y = h - seam_size + y
        blended = (1.0 - alpha) * arr[bottom_y] + alpha * arr[y]
        arr[y] = blended
        arr[bottom_y] = blended
        
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))

def process_all():
    print("--- Processing Scenery and Ground Assets ---")
    
    # 1. Cloud Bed Floor (Round 1)
    cloud_file = glob.glob(os.path.join(ARTIFACT_DIR, "cloud_bed_floor_*.jpg"))[0]
    c_img = Image.open(cloud_file).resize((640, 960), Image.Resampling.LANCZOS)
    c_seamless = make_seamless_vertical(c_img, seam_size=100)
    c_out = os.path.join(OUTPUT_DIR, "cloud_bed_floor.png")
    c_seamless.save(c_out, format="PNG")
    print(f"Saved: {c_out} ({c_seamless.size})")

    # 2. Mainland Terrain Floor (Round 3)
    land_file = glob.glob(os.path.join(ARTIFACT_DIR, "mainland_terrain_floor_*.jpg"))[0]
    l_img = Image.open(land_file).resize((640, 1280), Image.Resampling.LANCZOS)
    l_seamless = make_seamless_vertical(l_img, seam_size=120)
    l_out = os.path.join(OUTPUT_DIR, "mainland_terrain_floor.png")
    l_seamless.save(l_out, format="PNG")
    print(f"Saved: {l_out} ({l_seamless.size})")

    # 3. Tanks
    tanks = {
        "tank_sherman": ("tank_sherman_*.jpg", 58, 105),
        "tank_tiger": ("tank_tiger_*.jpg", 64, 110),
        "tank_chiha": ("tank_chiha_*.jpg", 56, 100),
        "tank_t34": ("tank_t34_*.jpg", 58, 105),
        "tank_churchill": ("tank_churchill_*.jpg", 56, 112),
    }
    
    for name, (pat, target_w, target_h) in tanks.items():
        matches = glob.glob(os.path.join(ARTIFACT_DIR, pat))
        if not matches:
            print(f"Warning: no match for {pat}")
            continue
        raw = Image.open(matches[0])
        transparent = remove_white_background(raw)
        cropped = tight_crop(transparent)
        pristine = cropped.resize((target_w, target_h), Image.Resampling.LANCZOS)
        damaged = create_damaged_variant(pristine)
        wreck = create_wreck_variant(pristine)
        
        pristine.save(os.path.join(OUTPUT_DIR, f"{name}_pristine.png"))
        damaged.save(os.path.join(OUTPUT_DIR, f"{name}_damaged.png"))
        wreck.save(os.path.join(OUTPUT_DIR, f"{name}_wreck.png"))
        print(f"Saved tank {name}: pristine, damaged, wreck ({target_w}x{target_h})")

    # 4. Pillbox Bunker & Flak Emplacement
    structures = {
        "pillbox_bunker": ("pillbox_bunker_*.jpg", 84, 84),
        "flak_emplacement": ("flak_emplacement_*.jpg", 96, 96),
        "military_building": ("military_building_*.jpg", 160, 160),
        "military_tent": ("military_tent_*.jpg", 170, 170),
    }
    
    for name, (pat, target_w, target_h) in structures.items():
        matches = glob.glob(os.path.join(ARTIFACT_DIR, pat))
        if not matches:
            print(f"Warning: no match for {pat}")
            continue
        raw = Image.open(matches[0])
        transparent = remove_white_background(raw)
        cropped = tight_crop(transparent)
        pristine = cropped.resize((target_w, target_h), Image.Resampling.LANCZOS)
        damaged = create_damaged_variant(pristine)
        wreck = create_wreck_variant(pristine)
        
        pristine.save(os.path.join(OUTPUT_DIR, f"{name}_pristine.png"))
        damaged.save(os.path.join(OUTPUT_DIR, f"{name}_damaged.png"))
        wreck.save(os.path.join(OUTPUT_DIR, f"{name}_wreck.png"))
        print(f"Saved structure {name}: pristine, damaged, wreck ({target_w}x{target_h})")

    print("--- Asset processing finished successfully! ---")

if __name__ == "__main__":
    process_all()

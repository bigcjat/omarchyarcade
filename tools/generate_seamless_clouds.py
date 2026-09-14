#!/usr/bin/env python3
"""
Generates seamless top-down cloud canopy texture for Sky Ace high-altitude flight.
Pure 90-degree orthographic view with zero perspective distortion and zero vertical tiling seam.
Dense billowy cumulus with subtle soft rifts revealing ocean underneath.
"""

import math
import random
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

def create_seamless_cloud_canopy(width=1024, height=1024):
    print(f"[CloudGen] Generating {width}x{height} seamless top-down cloud canopy...")
    random.seed(1942)

    # Base image with high-alpha cloud foundation
    img = Image.new("RGBA", (width, height), (220, 232, 245, 248))
    draw = ImageDraw.Draw(img)

    # 1. Multi-octave cellular cumulus cloud puffs
    # Use toroidal / periodic wrapping in Y so y=0 seamlessly equals y=height!
    
    # Layer A: Large sweeping cloud billow banks
    for _ in range(140):
        cx = random.uniform(0, width)
        cy = random.uniform(0, height)
        rx = random.uniform(90, 210)
        ry = random.uniform(70, 160)
        
        # Ivory to bright white sunlit billows
        tone = random.randint(238, 255)
        alpha = random.randint(180, 240)
        
        # Draw on torus (wraps in Y, also wraps in X)
        for ox in (-width, 0, width):
            for oy in (-height, 0, height):
                px = cx + ox
                py = cy + oy
                draw.ellipse([px - rx, py - ry, px + rx, py + ry], fill=(tone, tone, min(255, tone + 4), alpha))

    # Layer B: Mid-sized puffy cumulus lobes
    for _ in range(320):
        cx = random.uniform(0, width)
        cy = random.uniform(0, height)
        rx = random.uniform(40, 95)
        ry = random.uniform(35, 80)
        
        tone = random.randint(245, 255)
        alpha = random.randint(120, 220)
        
        for ox in (-width, 0, width):
            for oy in (-height, 0, height):
                px = cx + ox
                py = cy + oy
                draw.ellipse([px - rx, py - ry, px + rx, py + ry], fill=(tone, tone, min(255, tone + 2), alpha))

    # Layer C: Soft cloud underside shadows (gentle blue-grey depth)
    shadow_img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow_img)
    for _ in range(80):
        cx = random.uniform(0, width)
        cy = random.uniform(0, height)
        rx = random.uniform(60, 140)
        ry = random.uniform(50, 110)
        for ox in (-width, 0, width):
            for oy in (-height, 0, height):
                px = cx + ox
                py = cy + oy
                # Underside shade offset slightly down (+Y)
                sdraw.ellipse([px - rx, py - ry + 16, px + rx, py + ry + 16], fill=(175, 195, 220, 38))

    img = Image.alpha_composite(img, shadow_img)

    # Layer D: Rare subtle cloud breaks / rifts where ocean peeks through
    # (Very few, soft feathered edges as requested: "try not to have a break")
    mask = Image.new("L", (width, height), 255)
    mdraw = ImageDraw.Draw(mask)
    for _ in range(4):
        cx = random.uniform(60, width - 60)
        cy = random.uniform(60, height - 60)
        rx = random.uniform(30, 60)
        ry = random.uniform(20, 45)
        for ox in (-width, 0, width):
            for oy in (-height, 0, height):
                px = cx + ox
                py = cy + oy
                mdraw.ellipse([px - rx, py - ry, px + rx, py + ry], fill=110)

    # Soften the mask and cloud transitions
    mask = mask.filter(ImageFilter.GaussianBlur(radius=28))
    img.putalpha(mask)

    # High-quality Gaussian blur to create photo-real smooth cumulus atmospheric shading
    img = img.filter(ImageFilter.GaussianBlur(radius=12))

    # Apply crisp top highlights on cloud summits
    highlight_img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(highlight_img)
    for _ in range(180):
        cx = random.uniform(0, width)
        cy = random.uniform(0, height)
        rx = random.uniform(25, 65)
        ry = random.uniform(20, 50)
        for ox in (-width, 0, width):
            for oy in (-height, 0, height):
                px = cx + ox
                py = cy + oy
                hdraw.ellipse([px - rx, py - ry - 6, px + rx, py + ry - 6], fill=(255, 255, 255, 60))
    highlight_img = highlight_img.filter(ImageFilter.GaussianBlur(radius=8))
    img = Image.alpha_composite(img, highlight_img)

def periodic_blur(img, radius):
    w, h = img.size
    pad = int(radius * 3)
    arr = np.array(img)
    if arr.ndim == 3:
        arr_padded = np.pad(arr, ((pad, pad), (pad, pad), (0, 0)), mode="wrap")
    else:
        arr_padded = np.pad(arr, ((pad, pad), (pad, pad)), mode="wrap")
    im_padded = Image.fromarray(arr_padded)
    im_blurred = im_padded.filter(ImageFilter.GaussianBlur(radius))
    arr_blurred = np.array(im_blurred)
    return Image.fromarray(arr_blurred[pad:-pad, pad:-pad])

def create_seamless_cloud_canopy(width=2048, height=2048):
    print(f"[CloudGen] Generating {width}x{height} seamless top-down cloud canopy...")
    np.random.seed(1942)

    img = Image.new("RGBA", (width, height), (228, 238, 248, 252))
    draw = ImageDraw.Draw(img)

    for _ in range(260):
        cx = np.random.uniform(0, width)
        cy = np.random.uniform(0, height)
        rx = np.random.uniform(160, 360)
        ry = np.random.uniform(120, 280)
        tone = np.random.randint(238, 255)
        alpha = np.random.randint(160, 235)
        for ox in (-width, 0, width):
            for oy in (-height, 0, height):
                draw.ellipse([cx+ox-rx, cy+oy-ry, cx+ox+rx, cy+oy+ry], fill=(tone, tone, min(255, tone+3), alpha))

    for _ in range(550):
        cx = np.random.uniform(0, width)
        cy = np.random.uniform(0, height)
        rx = np.random.uniform(70, 160)
        ry = np.random.uniform(60, 140)
        tone = np.random.randint(245, 255)
        alpha = np.random.randint(140, 225)
        for ox in (-width, 0, width):
            for oy in (-height, 0, height):
                draw.ellipse([cx+ox-rx, cy+oy-ry, cx+ox+rx, cy+oy+ry], fill=(tone, tone, min(255, tone+2), alpha))

    shadow_img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow_img)
    for _ in range(160):
        cx = np.random.uniform(0, width)
        cy = np.random.uniform(0, height)
        rx = np.random.uniform(100, 240)
        ry = np.random.uniform(80, 180)
        for ox in (-width, 0, width):
            for oy in (-height, 0, height):
                sdraw.ellipse([cx+ox-rx, cy+oy-ry+24, cx+ox+rx, cy+oy+ry+24], fill=(172, 192, 218, 35))

    shadow_img = periodic_blur(shadow_img, 18)
    img = Image.alpha_composite(img, shadow_img)

    hl_img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(hl_img)
    for _ in range(350):
        cx = np.random.uniform(0, width)
        cy = np.random.uniform(0, height)
        rx = np.random.uniform(40, 110)
        ry = np.random.uniform(30, 90)
        for ox in (-width, 0, width):
            for oy in (-height, 0, height):
                hdraw.ellipse([cx+ox-rx, cy+oy-ry-10, cx+ox+rx, cy+oy+ry-10], fill=(255, 255, 255, 65))

    hl_img = periodic_blur(hl_img, 12)
    img = Image.alpha_composite(img, hl_img)
    img = periodic_blur(img, 14)

    out_path = Path("games/skyace/sprites/cloud_bed_floor.png")
    img.save(out_path, "PNG", optimize=True)
    print(f"[CloudGen] Saved {out_path} ({out_path.stat().st_size} bytes)")

if __name__ == "__main__":
    create_seamless_cloud_canopy()

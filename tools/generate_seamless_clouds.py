#!/usr/bin/env python3
"""
Generates seamless top-down cloud canopy texture for Sky Ace high-altitude flight.
Pure 90-degree orthographic view with zero perspective distortion and zero vertical tiling seam.
Dense billowy cumulus with subtle soft rifts revealing ocean underneath.
"""

import math
import random
from pathlib import Path
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

    # Seamless wrap in Y (vertical loop)
    blend_h = 80
    for y in range(blend_h):
        alpha = 0.5 * (1.0 - math.cos(math.pi * (y + 1) / blend_h))
        y_bot = height - blend_h + y
        for x in range(width):
            top_px = img.getpixel((x, y))
            bot_px = img.getpixel((x, y_bot))
            r = int(bot_px[0] * (1.0 - alpha) + top_px[0] * alpha)
            g = int(bot_px[1] * (1.0 - alpha) + top_px[1] * alpha)
            b = int(bot_px[2] * (1.0 - alpha) + top_px[2] * alpha)
            a = int(bot_px[3] * (1.0 - alpha) + top_px[3] * alpha)
            img.putpixel((x, y_bot), (r, g, b, a))

    for x in range(width):
        img.putpixel((x, height - 1), img.getpixel((x, 0)))

    # Seamless wrap in X (horizontal loop)
    blend_w = 80
    for x in range(blend_w):
        alpha = 0.5 * (1.0 - math.cos(math.pi * (x + 1) / blend_w))
        x_right = width - blend_w + x
        for y in range(height):
            left_px = img.getpixel((x, y))
            right_px = img.getpixel((x_right, y))
            r = int(right_px[0] * (1.0 - alpha) + left_px[0] * alpha)
            g = int(right_px[1] * (1.0 - alpha) + left_px[1] * alpha)
            b = int(right_px[2] * (1.0 - alpha) + left_px[2] * alpha)
            a = int(right_px[3] * (1.0 - alpha) + left_px[3] * alpha)
            img.putpixel((x_right, y), (r, g, b, a))

    for y in range(height):
        img.putpixel((width - 1, y), img.getpixel((0, y)))

    out_path = Path("games/skyace/sprites/cloud_bed_floor.png")
    img.save(out_path, "PNG", optimize=True)
    print(f"[CloudGen] Saved {out_path} ({out_path.stat().st_size} bytes)")

if __name__ == "__main__":
    create_seamless_cloud_canopy()

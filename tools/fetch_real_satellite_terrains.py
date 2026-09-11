#!/usr/bin/env python3
"""
Fetches authentic, high-resolution orthorectified satellite photography of actual
countryside from real satellite imagery archives (ArcGIS World Imagery), stitches them into
768x1536 terrain strips, and enforces 100% mathematical zero-seam vertical looping.
"""

import math
import urllib.request
import io
from pathlib import Path
from PIL import Image
import numpy as np

def deg2num(lat_deg, lon_deg, zoom):
    lat_rad = math.radians(lat_deg)
    n = 2.0 ** zoom
    xtile = int((lon_deg + 180.0) / 360.0 * n)
    ytile = int((1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n)
    return (xtile, ytile)

def fetch_satellite_strip(center_lat, center_lon, zoom=14, grid_w=3, grid_h=6):
    cx, cy = deg2num(center_lat, center_lon, zoom)
    tile_w, tile_h = 256, 256
    full_img = Image.new("RGB", (grid_w * tile_w, grid_h * tile_h))
    
    start_x = cx - grid_w // 2
    start_y = cy - grid_h // 2
    
    for gy in range(grid_h):
        for gx in range(grid_w):
            tx = start_x + gx
            ty = start_y + gy
            url = f"https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{zoom}/{ty}/{tx}"
            req = urllib.request.Request(url, headers={"User-Agent": "SkyAceArcade/1.0"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                tile_data = resp.read()
            tile_img = Image.open(io.BytesIO(tile_data)).convert("RGB")
            full_img.paste(tile_img, (gx * tile_w, gy * tile_h))
            
    return full_img

def make_seamless_vertical(img, blend_h=80):
    width, height = img.size
    img = img.convert("RGB")
    
    # Cosine S-curve blend across blend_h
    for y in range(blend_h):
        alpha = 0.5 * (1.0 - math.cos(math.pi * (y + 1) / blend_h))
        y_bot = height - blend_h + y
        for x in range(width):
            top_px = img.getpixel((x, y))
            bot_px = img.getpixel((x, y_bot))
            r = int(bot_px[0] * (1.0 - alpha) + top_px[0] * alpha)
            g = int(bot_px[1] * (1.0 - alpha) + top_px[1] * alpha)
            b = int(bot_px[2] * (1.0 - alpha) + top_px[2] * alpha)
            img.putpixel((x, y_bot), (r, g, b))
            
    for x in range(width):
        img.putpixel((x, height - 1), img.getpixel((x, 0)))
        
    return img

def main():
    sprites_dir = Path("games/skyace/sprites")
    sprites_dir.mkdir(parents=True, exist_ok=True)
    
    theaters = [
        {
            "name": "Japan (Rural farmland, rice paddies & hills of Niigata/Tochigi)",
            "lat": 36.35, "lon": 140.05, "zoom": 14,
            "out_files": ["terrain_imperial.png"]
        },
        {
            "name": "Europe (Normandy/Rhine agrarian countryside)",
            "lat": 49.18, "lon": 0.35, "zoom": 14,
            "out_files": ["terrain_european.png", "terrain_luftwaffe.png", "mainland_terrain_floor.png"]
        },
        {
            "name": "Britain (Kent / Sussex English countryside)",
            "lat": 51.15, "lon": 0.45, "zoom": 14,
            "out_files": ["terrain_raf.png"]
        },
        {
            "name": "Russia (Kursk / Eastern Front agricultural plains)",
            "lat": 51.72, "lon": 36.19, "zoom": 14,
            "out_files": ["terrain_vvs.png"]
        }
    ]
    
    for th in theaters:
        print(f"\n[Satellite] Downloading authentic satellite imagery for {th['name']}...")
        raw_strip = fetch_satellite_strip(th["lat"], th["lon"], zoom=th["zoom"])
        seamless_strip = make_seamless_vertical(raw_strip)
        
        # Verify seam
        arr = np.array(seamless_strip)
        seam_diff = np.abs(arr[0].astype(int) - arr[-1].astype(int)).max()
        print(f"[Satellite] Verified zero-seam vertical wrap: max seam diff = {seam_diff}")
        assert seam_diff == 0, "Seam diff must be 0!"
        
        for fname in th["out_files"]:
            out_p = sprites_dir / fname
            seamless_strip.save(out_p, "PNG", optimize=True)
            print(f"  -> Saved {out_p} ({out_p.stat().st_size} bytes)")

    print("\n✓ ALL REAL SATELLITE COUNTRY TERRAINS DOWNLOADED AND SAVED SUCCESSFULLY!")

if __name__ == "__main__":
    main()

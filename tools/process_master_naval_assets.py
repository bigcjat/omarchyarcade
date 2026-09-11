#!/usr/bin/env python3
"""
tools/process_master_naval_assets.py
Processes high-resolution cel-shaded WWII naval assets (destroyer, cruiser, gunboat,
aircraft carrier, and rotating turrets) into transparent arcade sprites matching
the quality of sheet_player_p38.png.
"""

import math
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

BRAIN_DIR = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62")
SPRITES_DIR = Path("games/skyace/sprites")
SPRITES_DIR.mkdir(parents=True, exist_ok=True)

def transparentize_white_bg(img, tolerance=240):
    """Flood-fills from borders to cleanly remove solid white background."""
    img = img.convert("RGBA")
    arr = np.array(img)
    h, w, _ = arr.shape
    
    # Check if pixel is white-ish background
    is_white = (arr[..., 0] >= tolerance) & (arr[..., 1] >= tolerance) & (arr[..., 2] >= tolerance)
    
    visited = np.zeros((h, w), dtype=bool)
    q = deque()
    
    # Seed outer edges
    for x in range(w):
        if is_white[0, x]: q.append((0, x)); visited[0, x] = True
        if is_white[h - 1, x]: q.append((h - 1, x)); visited[h - 1, x] = True
    for y in range(h):
        if is_white[y, 0]: q.append((y, 0)); visited[y, 0] = True
        if is_white[y, w - 1]: q.append((y, w - 1)); visited[y, w - 1] = True
        
    while q:
        y, x = q.popleft()
        for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx]:
                if is_white[ny, nx]:
                    visited[ny, nx] = True
                    q.append((ny, nx))
                    
    arr[visited, 3] = 0
    
    # Soft alpha feathering on boundary
    alpha = arr[..., 3].astype(np.float32)
    # Any pixel close to visited gets feathered
    dilated_visited = np.zeros((h, w), dtype=bool)
    for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        sh = np.roll(np.roll(visited, dy, axis=0), dx, axis=1)
        dilated_visited |= sh
        
    fringe = dilated_visited & (~visited)
    whiteness = (arr[fringe, 0].astype(np.float32) + arr[fringe, 1] + arr[fringe, 2]) / 3.0
    # Modulate alpha based on lightness on fringe
    alpha[fringe] = np.clip((255.0 - whiteness) * 2.5, 0, 255)
    arr[..., 3] = alpha.astype(np.uint8)
    
    res = Image.fromarray(arr, "RGBA")
    bbox = res.getbbox()
    if bbox:
        res = res.crop(bbox)
    return res

def create_damage_variants(base_img):
    """Creates Pristine, Damaged, and Critical Wreck variants with burn marks."""
    w, h = base_img.size
    
    # 1. Pristine
    pristine = base_img.copy()
    
    # 2. Damaged: scorched blast marks and slight smoke plume
    damaged = base_img.copy()
    d_draw = ImageDraw.Draw(damaged)
    np.random.seed(42)
    for _ in range(3):
        cx = np.random.randint(int(w * 0.35), int(w * 0.65))
        cy = np.random.randint(int(h * 0.25), int(h * 0.75))
        rad = np.random.randint(12, 28)
        d_draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=(25, 25, 28, 160))
        d_draw.ellipse([cx - rad // 2, cy - rad // 2, cx + rad // 2, cy + rad // 2], fill=(240, 90, 15, 200))
        d_draw.ellipse([cx - rad // 4, cy - rad // 4, cx + rad // 4, cy + rad // 4], fill=(255, 220, 50, 240))
        
    # 3. Wreck: blackened hull, heavy fires, charred decks
    wreck = base_img.copy()
    w_draw = ImageDraw.Draw(wreck)
    for _ in range(7):
        cx = np.random.randint(int(w * 0.25), int(w * 0.75))
        cy = np.random.randint(int(h * 0.15), int(h * 0.85))
        rad = np.random.randint(18, 42)
        w_draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=(18, 18, 20, 210))
        w_draw.ellipse([cx - rad // 2, cy - rad // 2, cx + rad // 2, cy + rad // 2], fill=(235, 75, 10, 220))
        w_draw.ellipse([cx - rad // 4, cy - rad // 4, cx + rad // 4, cy + rad // 4], fill=(255, 200, 30, 255))
        
    # Tone down wreck overall brightness
    w_arr = np.array(wreck).astype(np.float32)
    w_arr[..., :3] *= 0.65
    wreck = Image.fromarray(np.clip(w_arr, 0, 255).astype(np.uint8), "RGBA")
    
    return pristine, damaged, wreck

def build_turret_sheet(turret_img, frame_size=64, num_frames=16):
    """Bakes a 16-frame 360-degree rotating turret spritesheet."""
    # Rotate turret so it pivots cleanly around its circular base center
    tw, th = turret_img.size
    # Find circular base center (usually slightly below center due to long forward barrels)
    # Resize to fit inside frame with padding
    pad = 4
    scale = (frame_size - pad * 2) / max(tw, th)
    scaled_w = int(tw * scale)
    scaled_h = int(th * scale)
    t_scaled = turret_img.resize((scaled_w, scaled_h), Image.Resampling.LANCZOS)
    
    # Center on a square canvas
    square = Image.new("RGBA", (frame_size, frame_size), (0, 0, 0, 0))
    paste_x = (frame_size - scaled_w) // 2
    paste_y = (frame_size - scaled_h) // 2 + int(scaled_h * 0.08) # Align barbette center
    square.paste(t_scaled, (paste_x, paste_y), t_scaled)
    
    sheet = Image.new("RGBA", (frame_size * num_frames, frame_size), (0, 0, 0, 0))
    for i in range(num_frames):
        # 0 is pointing North (0 degrees), clockwise 22.5 deg per frame
        ang = -(i * 360.0 / num_frames)
        rot = square.rotate(ang, resample=Image.Resampling.BICUBIC, center=(frame_size // 2, frame_size // 2))
        sheet.paste(rot, (i * frame_size, 0), rot)
        
    return sheet

def main():
    print("[Sky Ace] Processing Master 3D Cel-Shaded Naval Warship & Carrier Assets...")

    # File mappings
    destroyer_src = BRAIN_DIR / "topdown_destroyer_1789035753717.jpg"
    cruiser_src   = BRAIN_DIR / "topdown_cruiser_1789035771563.jpg"
    gunboat_src   = BRAIN_DIR / "topdown_gunboat_1789035919496.jpg"
    carrier_src   = BRAIN_DIR / "topdown_carrier_1789035940650.jpg"
    turret_h_src  = BRAIN_DIR / "turret_heavy_isolated_1789035961525.jpg"
    turret_d_src  = BRAIN_DIR / "turret_destroyer_isolated_1789035978327.jpg"

    # 1. Fleet Destroyer (Target Size: 130 x 440)
    if destroyer_src.exists():
        raw_d = Image.open(destroyer_src)
        clean_d = transparentize_white_bg(raw_d)
        d_final = clean_d.resize((130, 440), Image.Resampling.LANCZOS)
        p, d, w = create_damage_variants(d_final)
        p.save(SPRITES_DIR / "ship_destroyer_pristine.png")
        d.save(SPRITES_DIR / "ship_destroyer_damaged.png")
        w.save(SPRITES_DIR / "ship_destroyer_wreck.png")
        p.save(BRAIN_DIR / "ship_destroyer_pristine.png")
        print("✓ Processed Destroyer (Pristine, Damaged, Wreck)")

    # 2. Heavy Cruiser / Battleship (Target Size: 180 x 580)
    if cruiser_src.exists():
        raw_c = Image.open(cruiser_src)
        clean_c = transparentize_white_bg(raw_c)
        c_final = clean_c.resize((180, 580), Image.Resampling.LANCZOS)
        p, d, w = create_damage_variants(c_final)
        p.save(SPRITES_DIR / "ship_cruiser_pristine.png")
        d.save(SPRITES_DIR / "ship_cruiser_damaged.png")
        w.save(SPRITES_DIR / "ship_cruiser_wreck.png")
        p.save(BRAIN_DIR / "ship_cruiser_pristine.png")
        print("✓ Processed Heavy Cruiser (Pristine, Damaged, Wreck)")

    # 3. PT Gunboat (Target Size: 70 x 180)
    if gunboat_src.exists():
        raw_g = Image.open(gunboat_src)
        clean_g = transparentize_white_bg(raw_g)
        g_final = clean_g.resize((70, 180), Image.Resampling.LANCZOS)
        p, d, w = create_damage_variants(g_final)
        p.save(SPRITES_DIR / "ship_gunboat_pristine.png")
        d.save(SPRITES_DIR / "ship_gunboat_damaged.png")
        w.save(SPRITES_DIR / "ship_gunboat_wreck.png")
        p.save(BRAIN_DIR / "ship_gunboat_pristine.png")
        print("✓ Processed PT Gunboat (Pristine, Damaged, Wreck)")

    # 4. Rotating Turrets
    if turret_d_src.exists():
        raw_td = Image.open(turret_d_src)
        clean_td = transparentize_white_bg(raw_td)
        sheet_d = build_turret_sheet(clean_td, frame_size=64, num_frames=16)
        sheet_d.save(SPRITES_DIR / "turret_destroyer_sheet.png")
        sheet_d.save(BRAIN_DIR / "turret_destroyer_sheet.png")
        print("✓ Processed Destroyer Twin Turret Sheet (16 frames, 64x64)")

    if turret_h_src.exists():
        raw_th = Image.open(turret_h_src)
        clean_th = transparentize_white_bg(raw_th)
        sheet_h = build_turret_sheet(clean_th, frame_size=80, num_frames=16)
        sheet_h.save(SPRITES_DIR / "turret_heavy_sheet.png")
        sheet_h.save(BRAIN_DIR / "turret_heavy_sheet.png")
        print("✓ Processed Heavy Triple Turret Sheet (16 frames, 80x80)")

    # 5. Aircraft Carrier Flight Deck (Target Size: 320 x 740)
    if carrier_src.exists():
        raw_cv = Image.open(carrier_src)
        clean_cv = transparentize_white_bg(raw_cv)
        cv_final = clean_cv.resize((320, 740), Image.Resampling.LANCZOS)
        
        # Deploy to all national carrier keys
        planes = ["p38", "zero", "spitfire", "bf109", "yak3", "mosquito", "folgore", "d520", "pzl11", "avia"]
        for p_key in planes:
            out_name = f"carrier_{p_key}.png"
            cv_final.save(SPRITES_DIR / out_name)
            cv_final.save(BRAIN_DIR / out_name)
        print("✓ Processed Master 3D Aircraft Carrier across all 10 national rosters!")

if __name__ == "__main__":
    main()

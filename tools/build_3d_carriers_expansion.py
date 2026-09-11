#!/usr/bin/env python3
"""
tools/build_3d_carriers_expansion.py
Renders 4 new authentic historical carrier flight decks and airbases (320x720):
1. carrier_folgore: Italian Aircraft Carrier 'Aquila' (Regia Marina red/white bow stripes & island)
2. carrier_d520: French Aircraft Carrier 'Béarn' (Steel deck with tricolor roundel & side sponsons)
3. carrier_pzl11: Warsaw Okęcie Frontline Airbase (Concrete slabs, threshold bars, Polish checkerboard)
4. carrier_avia: Prague-Kbely Airbase (Reinforced concrete slabs with Czechoslovak tricolor roundel)
"""

from PIL import Image, ImageDraw
from pathlib import Path

def create_aquila_carrier():
    """Italian Aircraft Carrier Aquila: Teak deck with Regia Marina red/white bow recognition stripes."""
    w, h = 320, 720
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    # Steel hull border
    draw.polygon([(40, 20), (280, 20), (305, 120), (305, 680), (285, 715), (35, 715), (15, 680), (15, 120)], fill=(75, 82, 88, 255), outline=(35, 40, 44, 255), width=2)
    # Flight deck (Teak planks)
    draw.polygon([(44, 24), (276, 24), (300, 120), (300, 676), (280, 710), (40, 710), (20, 676), (20, 120)], fill=(155, 125, 85, 255))

    # Regia Marina Red & White Alternating Diagonal Bow Stripes (High-visibility anti-fratricide stripes)
    for i in range(0, 140, 24):
        draw.polygon([(40 + i, 24), (64 + i, 24), (24, 64 + i), (24, 40 + i)], fill=(215, 38, 38, 240))
        draw.polygon([(64 + i, 24), (88 + i, 24), (24, 88 + i), (24, 64 + i)], fill=(245, 245, 250, 240))

    # Plank lines
    for x in range(30, 290, 8):
        draw.line([(x, 140), (x, 700)], fill=(135, 105, 68, 120), width=1)

    # Centerline & Arrestor Wires
    for y in range(140, 680, 40):
        draw.line([(160, y), (160, y + 22)], fill=(245, 245, 250, 240), width=4)
    for y in [480, 520, 560, 600]:
        draw.line([(30, y), (290, y)], fill=(35, 38, 42, 230), width=2)

    # Starboard Island Tower
    draw.rectangle([270, 260, 305, 420], fill=(68, 74, 80, 255), outline=(32, 36, 40, 255), width=2)
    draw.rectangle([278, 290, 300, 380], fill=(52, 58, 64, 255))
    return im

def create_bearn_carrier():
    """French Aircraft Carrier Béarn: Steel armored deck with side gun sponsons and French Tricolor."""
    w, h = 320, 720
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    # Steel hull with sponsons
    draw.polygon([(48, 15), (272, 15), (298, 110), (312, 280), (298, 340), (312, 520), (298, 680), (270, 715), (50, 715), (22, 680), (8, 520), (22, 340), (8, 280), (22, 110)], fill=(70, 75, 82, 255), outline=(35, 38, 42, 255), width=2)
    # Dark steel deck
    draw.polygon([(52, 20), (268, 20), (292, 110), (292, 676), (266, 710), (54, 710), (28, 676), (28, 110)], fill=(92, 100, 108, 255))

    # Centerline dashed marking
    for y in range(80, 670, 45):
        draw.line([(160, y), (160, y + 25)], fill=(245, 245, 250, 230), width=4)

    # French Tricolor Roundel on flight deck
    cx, cy, rad = 160, 180, 48
    draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=(28, 58, 145, 255))
    draw.ellipse([cx - rad*0.66, cy - rad*0.66, cx + rad*0.66, cy + rad*0.66], fill=(245, 245, 250, 255))
    draw.ellipse([cx - rad*0.33, cy - rad*0.33, cx + rad*0.33, cy + rad*0.33], fill=(215, 35, 35, 255))

    # Starboard Island
    draw.rectangle([265, 310, 298, 450], fill=(62, 68, 74, 255), outline=(30, 34, 38, 255), width=2)
    # Arrestor Wires
    for y in [490, 530, 570, 610]:
        draw.line([(32, y), (288, y)], fill=(32, 35, 38, 230), width=2)
    return im

def create_okecie_airbase():
    """Warsaw Okęcie Airbase (Poland): Concrete slabs with Polish Red/White Checkerboard."""
    w, h = 320, 720
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    # Grassy tarmac apron border
    draw.rectangle([25, 10, 295, 710], fill=(58, 68, 52, 255), outline=(32, 38, 30, 255), width=2)
    # Concrete runway
    draw.rectangle([45, 20, 275, 700], fill=(138, 142, 145, 255), outline=(85, 90, 95, 255), width=2)

    # Expansion Joints
    for y in range(40, 700, 35):
        draw.line([(45, y), (275, y)], fill=(95, 98, 100, 180), width=1)
    for x in range(65, 275, 40):
        draw.line([(x, 20), (x, 700)], fill=(95, 98, 100, 180), width=1)

    # Piano keys threshold bars
    for x in range(60, 265, 22):
        draw.rectangle([x, 30, x + 12, 75], fill=(245, 245, 250, 240))
        draw.rectangle([x, 645, x + 12, 690], fill=(245, 245, 250, 240))

    # Centerline Yellow Line
    for y in range(95, 630, 45):
        draw.line([(160, y), (160, y + 25)], fill=(245, 215, 45, 240), width=4)

    # Polish Red/White Checkerboard (Szachownica) on Runway Center
    cx, cy, sz = 160, 320, 38
    draw.polygon([(cx - sz, cy - sz), (cx, cy - sz), (cx, cy), (cx - sz, cy)], fill=(215, 35, 35, 255))
    draw.polygon([(cx, cy - sz), (cx + sz, cy - sz), (cx + sz, cy), (cx, cy)], fill=(245, 245, 250, 255))
    draw.polygon([(cx - sz, cy), (cx, cy), (cx, cy + sz), (cx - sz, cy + sz)], fill=(245, 245, 250, 255))
    draw.polygon([(cx, cy), (cx + sz, cy), (cx + sz, cy + sz), (cx, cy + sz)], fill=(215, 35, 35, 255))
    draw.rectangle([cx - sz, cy - sz, cx + sz, cy + sz], outline=(30, 30, 30, 255), width=3)
    return im

def create_kbely_airbase():
    """Prague-Kbely Airbase (Czechoslovakia): Concrete runway with Czechoslovak Tricolor Roundel."""
    w, h = 320, 720
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    # Grassy apron
    draw.rectangle([25, 10, 295, 710], fill=(55, 65, 48, 255), outline=(30, 35, 28, 255), width=2)
    # Concrete slab runway
    draw.rectangle([45, 20, 275, 700], fill=(142, 145, 148, 255), outline=(90, 95, 98, 255), width=2)

    # Expansion Joints
    for y in range(40, 700, 35):
        draw.line([(45, y), (275, y)], fill=(100, 104, 106, 180), width=1)
    for x in range(65, 275, 40):
        draw.line([(x, 20), (x, 700)], fill=(100, 104, 106, 180), width=1)

    # Piano keys
    for x in range(60, 265, 22):
        draw.rectangle([x, 30, x + 12, 75], fill=(245, 245, 250, 240))
        draw.rectangle([x, 645, x + 12, 690], fill=(245, 245, 250, 240))

    # Centerline Yellow
    for y in range(95, 630, 45):
        draw.line([(160, y), (160, y + 25)], fill=(245, 215, 45, 240), width=4)

    # Czechoslovak Tricolor Roundel on Runway
    cx, cy, rad = 160, 320, 45
    draw.pieslice([cx - rad, cy - rad, cx + rad, cy + rad], 180, 360, fill=(245, 245, 250, 255))
    draw.pieslice([cx - rad, cy - rad, cx + rad, cy + rad], 0, 180, fill=(215, 35, 35, 255))
    draw.polygon([(cx, cy), (cx - rad, cy - rad*0.7), (cx - rad, cy + rad*0.7)], fill=(32, 65, 155, 255))
    draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], outline=(30, 30, 30, 255), width=2)
    return im

def main():
    spr_dir = Path("games/skyace/sprites")
    art_dir = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62")

    carriers = [
        ("carrier_folgore", create_aquila_carrier()),
        ("carrier_d520", create_bearn_carrier()),
        ("carrier_pzl11", create_okecie_airbase()),
        ("carrier_avia", create_kbely_airbase()),
    ]

    for name, img in carriers:
        img.save(spr_dir / f"{name}.png")
        img.save(art_dir / f"{name}.png")
        print(f"✓ Saved {name}.png")

if __name__ == "__main__":
    main()

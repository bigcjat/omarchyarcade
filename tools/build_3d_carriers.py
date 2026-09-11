#!/usr/bin/env python3
"""
tools/build_3d_carriers.py
Generates authentic historical aircraft carrier flight decks and airbases for all 6 playable nations:
1. USA: USS Enterprise (CV-6) - Teak flight deck, bold "6" numeral, island superstructure, catwalk gun tubs.
2. Japan: IJN Akagi / Hiryu - Cedar wood deck, giant painted Red Hinomaru, arrow approach guides, side funnel.
3. Britain: HMS Ark Royal (R09) - Armored steel deck, Admiralty wave camouflage, bold "R09".
4. Germany: KMS Graf Zeppelin - Baltic splinter camo, forward catapult tracks, Atlantic bow.
5. Canada: HMCS Warrior (R31) - Royal Canadian Navy, bold "31", Canadian Red Maple Leaf deck emblem.
6. USSR: Krasny Luch Runway - Heavy concrete military airstrip, threshold bars, yellow centerline, Red Star.

Dimensions: 320 x 720 px, 32-bit RGBA PNGs.
"""

import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 320, 720

def create_base_canvas():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))

# =============================================================================
# 1. USA: USS ENTERPRISE (CV-6)
# =============================================================================
def build_carrier_usa():
    img = create_base_canvas()
    draw = ImageDraw.Draw(img)

    # Hull Shadow
    shadow_pts = [(50, 40), (270, 40), (280, 680), (40, 680)]
    draw.polygon(shadow_pts, fill=(8, 14, 22, 120))

    # Hull Sponsons / Catwalks (Dark Navy Grey)
    hull_col = (48, 54, 62)
    border_col = (28, 32, 38)
    draw.polygon([(46, 70), (274, 70), (284, 665), (36, 665)], fill=hull_col, outline=border_col)

    # 40mm Bofors & 20mm Oerlikon Sponsons along port and starboard
    for y_spons in [140, 220, 310, 420, 520, 610]:
        # Port tubs
        draw.ellipse([30, y_spons - 12, 46, y_spons + 12], fill=hull_col, outline=border_col)
        draw.ellipse([34, y_spons - 8, 42, y_spons + 8], fill=(30, 34, 40))
        # Starboard tubs
        draw.ellipse([274, y_spons - 12, 290, y_spons + 12], fill=hull_col, outline=border_col)
        draw.ellipse([278, y_spons - 8, 286, y_spons + 8], fill=(30, 34, 40))

    # Main Flight Deck (Tapered Essex / Yorktown bow)
    # Bow at Y=50, Stern at Y=670
    deck_pts = [
        (90, 50),   # Port bow taper
        (230, 50),  # Stbd bow taper
        (268, 90),  # Stbd forward shoulder
        (270, 660), # Stbd aft
        (255, 672), # Stbd stern round
        (65, 672),  # Port stern round
        (50, 660),  # Port aft
        (52, 90),   # Port forward shoulder
    ]
    deck_wood_base = (145, 115, 82) # Weathered stained teak
    draw.polygon(deck_pts, fill=deck_wood_base, outline=(35, 40, 48))

    # Teak Deck Planking lines
    for py in range(54, 670, 6):
        draw.line([(55, py), (265, py)], fill=(125, 98, 70, 160), width=1)
        if py % 24 == 0:
            draw.line([(55, py), (265, py)], fill=(95, 75, 52, 200), width=1)

    # Centerline dashed white stripes
    for cy in range(65, 660, 24):
        draw.rectangle([158, cy, 162, cy + 14], fill=(245, 245, 248))

    # Lateral elevator warning boundaries
    # Forward elevator (Y=160 to 220)
    draw.rectangle([125, 160, 195, 220], outline=(65, 55, 42), width=2)
    # Aft elevator (Y=480 to 540)
    draw.rectangle([125, 480, 195, 540], outline=(65, 55, 42), width=2)

    # Bold High-Contrast Deck Number "6" (Matching user photo #2 of USS Enterprise!)
    # Outer black drop border
    draw.text((128, 76), "6", fill=(25, 28, 35), font=None)
    # Draw large block numeral "6" via polygons/lines for crisp rendering
    # Top bar
    draw.rectangle([132, 85, 188, 103], fill=(245, 248, 252))
    # Left stem
    draw.rectangle([132, 103, 148, 150], fill=(245, 248, 252))
    # Bottom loop
    draw.rectangle([132, 140, 188, 175], fill=(245, 248, 252))
    draw.rectangle([148, 152, 172, 163], fill=(125, 98, 70)) # Hollow center

    # 4 Arresting Gear Wires near stern (Touchdown wire #3 is critical)
    for wy in [560, 585, 610, 635]:
        draw.line([(56, wy), (264, wy)], fill=(225, 230, 240), width=2)
        # Arresting buffer sheaves
        draw.rectangle([54, wy - 2, 60, wy + 2], fill=(20, 24, 28))
        draw.rectangle([260, wy - 2, 266, wy + 2], fill=(20, 24, 28))

    # Starboard Island Superstructure (Y=240 to 340, X=242 to 272)
    island_box = [242, 240, 276, 340]
    draw.rectangle(island_box, fill=(62, 70, 80), outline=(22, 26, 32), width=2)
    # Bridge windows (front facing)
    draw.rectangle([245, 243, 273, 250], fill=(130, 195, 225))
    # Funnel top & soot
    draw.ellipse([248, 280, 270, 310], fill=(30, 32, 36))
    # Tripod Radar Mast & Yardarm
    draw.line([(259, 255), (259, 230)], fill=(20, 24, 28), width=3)
    draw.line([(248, 236), (270, 236)], fill=(20, 24, 28), width=2)
    # Radar dish mesh
    draw.rectangle([254, 222, 264, 230], outline=(20, 24, 28), fill=(80, 90, 102), width=1)

    return img

# =============================================================================
# 2. JAPAN: IJN AKAGI / HIRYU
# =============================================================================
def build_carrier_japan():
    img = create_base_canvas()
    draw = ImageDraw.Draw(img)

    # Hull Shadow
    draw.polygon([(48, 40), (272, 40), (278, 680), (42, 680)], fill=(8, 14, 22, 120))

    # IJN Sasebo Grey Hull & Side Gun Galleries
    hull_col = (68, 72, 76)
    border_col = (30, 32, 36)
    draw.polygon([(46, 65), (274, 65), (280, 665), (40, 665)], fill=hull_col, outline=border_col)

    # Side Twin 12.7cm Type 89 AA Gun Mounts
    for y_gun in [160, 260, 380, 500, 600]:
        draw.ellipse([28, y_gun - 10, 44, y_gun + 10], fill=hull_col, outline=border_col)
        draw.ellipse([276, y_gun - 10, 292, y_gun + 10], fill=hull_col, outline=border_col)

    # Flight Deck (Japanese Cedar Plank Deck)
    deck_pts = [
        (85, 48), (235, 48), (266, 85), (268, 662),
        (250, 672), (70, 672), (52, 662), (54, 85)
    ]
    draw.polygon(deck_pts, fill=(168, 138, 98), outline=(32, 35, 40))

    # Wood plank lines
    for py in range(52, 670, 5):
        draw.line([(56, py), (264, py)], fill=(148, 120, 84, 150), width=1)

    # ICONIC BOLD RED HINOMARU (Rising Sun Disc) - Matches User Reference Photo #4!
    # Painted directly on the forward flight deck
    hinomaru_cy = 135
    hinomaru_r = 38
    # White rectangular background border sometimes used on carriers
    draw.rectangle([160 - hinomaru_r - 10, hinomaru_cy - hinomaru_r - 8,
                    160 + hinomaru_r + 10, hinomaru_cy + hinomaru_r + 8], fill=(245, 245, 245))
    # Red Sun Disc
    draw.ellipse([160 - hinomaru_r, hinomaru_cy - hinomaru_r,
                  160 + hinomaru_r, hinomaru_cy + hinomaru_r], fill=(215, 28, 28))

    # CONVERGING ARROW APPROACH GUIDES (User Reference Photo #3 - IJN Akagi 1942)
    # White dashed touchdown perimeter
    draw.line([(85, 665), (160, 540)], fill=(245, 245, 248), width=3)
    draw.line([(235, 665), (160, 540)], fill=(245, 245, 248), width=3)
    draw.line([(160, 540), (160, 240)], fill=(245, 245, 248), width=3)
    # Transverse white/red recognition stripes across the stern
    draw.rectangle([54, 645, 266, 655], fill=(245, 245, 245))
    draw.rectangle([54, 655, 266, 665], fill=(215, 28, 28))

    # Arresting cables
    for wy in [530, 560, 590, 620]:
        draw.line([(56, wy), (264, wy)], fill=(230, 235, 245), width=2)

    # Port-Side Island Superstructure (IJN Akagi signature: island on PORT side!)
    port_island = [44, 270, 74, 345]
    draw.rectangle(port_island, fill=(62, 66, 72), outline=(22, 24, 28), width=2)
    draw.rectangle([46, 272, 72, 280], fill=(130, 195, 225)) # Bridge

    # Starboard Downward-Curved Funnel (Akagi's signature side funnel blasting exhaust toward sea!)
    funnel_box = [266, 280, 296, 360]
    draw.polygon([(266, 285), (294, 295), (292, 355), (266, 345)], fill=(38, 40, 44), outline=(18, 20, 24))

    return img

# =============================================================================
# 3. GREAT BRITAIN: HMS ARK ROYAL (R09)
# =============================================================================
def build_carrier_britain():
    img = create_base_canvas()
    draw = ImageDraw.Draw(img)

    # Shadow
    draw.polygon([(46, 40), (274, 40), (280, 680), (40, 680)], fill=(8, 14, 22, 120))

    # Royal Navy Admiralty Dark Grey Hull
    hull_col = (52, 58, 66)
    draw.polygon([(44, 65), (276, 65), (282, 665), (38, 665)], fill=hull_col, outline=(24, 28, 34))

    # Armored Steel Flight Deck (Admiralty Standard Camouflage - Blue-Grey / Charcoal)
    deck_pts = [
        (92, 48), (228, 48), (268, 85), (270, 662),
        (254, 672), (66, 672), (50, 662), (52, 85)
    ]
    draw.polygon(deck_pts, fill=(84, 92, 102), outline=(28, 32, 38))

    # Admiralty Wave Camouflage patches across the steel deck
    camo_col = (62, 70, 80)
    draw.polygon([(52, 140), (180, 110), (268, 160), (268, 240), (130, 210), (52, 250)], fill=camo_col)
    draw.polygon([(52, 380), (210, 350), (270, 410), (270, 500), (120, 460), (52, 510)], fill=camo_col)

    # White Runway Guidelines
    for cy in range(60, 660, 20):
        draw.rectangle([158, cy, 162, cy + 12], fill=(245, 245, 250))
    draw.line([(95, 60), (95, 660)], fill=(230, 230, 235, 160), width=2)
    draw.line([(225, 60), (225, 660)], fill=(230, 230, 235, 160), width=2)

    # Bold Royal Navy Pennant Numeral "R09"
    draw.text((120, 85), "R 0 9", fill=(245, 245, 250))
    # Large block "R"
    draw.rectangle([136, 85, 184, 102], fill=(245, 248, 252))
    draw.rectangle([136, 102, 150, 150], fill=(245, 248, 252))
    draw.rectangle([136, 120, 178, 134], fill=(245, 248, 252))

    # Royal Air Force / Fleet Air Arm Roundel on aft deck
    r_cy = 490
    draw.ellipse([160 - 36, r_cy - 36, 160 + 36, r_cy + 36], fill=(25, 45, 105)) # Blue
    draw.ellipse([160 - 24, r_cy - 24, 160 + 24, r_cy + 24], fill=(245, 245, 245)) # White
    draw.ellipse([160 - 12, r_cy - 12, 160 + 12, r_cy + 12], fill=(215, 30, 30)) # Red

    # Arresting wires
    for wy in [570, 595, 620, 645]:
        draw.line([(52, wy), (268, wy)], fill=(235, 235, 245), width=2)

    # Starboard Island Tower with Type 279 Radar
    draw.rectangle([242, 235, 274, 335], fill=(58, 64, 72), outline=(18, 22, 26), width=2)
    draw.rectangle([246, 238, 270, 246], fill=(135, 205, 235))
    draw.ellipse([248, 275, 268, 305], fill=(28, 30, 35)) # Funnel
    draw.line([(258, 250), (258, 225)], fill=(15, 18, 22), width=3) # Mast

    return img

# =============================================================================
# 4. GERMANY: KMS GRAF ZEPPELIN
# =============================================================================
def build_carrier_germany():
    img = create_base_canvas()
    draw = ImageDraw.Draw(img)

    # Shadow
    draw.polygon([(46, 40), (274, 40), (280, 680), (40, 680)], fill=(8, 14, 22, 120))

    # Kriegsmarine Atlantic Bow Hull (Sharp tapered bow)
    hull_col = (72, 76, 82)
    draw.polygon([(44, 60), (276, 60), (282, 665), (38, 665)], fill=hull_col, outline=(24, 26, 30))

    # Armored Deck with Baltic Splinter Camouflage
    deck_pts = [
        (100, 42), (220, 42), (270, 80), (272, 662),
        (256, 672), (64, 672), (48, 662), (50, 80)
    ]
    draw.polygon(deck_pts, fill=(108, 114, 120), outline=(26, 28, 32))

    # Baltic Camo Diagonal Splinter Bands (Black & White stripes)
    for bx, by in [(30, 180), (120, 360), (40, 520)]:
        draw.polygon([(bx, by), (bx + 160, by - 80), (bx + 190, by - 80), (bx + 30, by)], fill=(240, 242, 246))
        draw.polygon([(bx + 30, by), (bx + 190, by - 80), (bx + 215, by - 80), (bx + 55, by)], fill=(28, 30, 34))

    # Twin Forward Steam Catapult Troughs (KMS Graf Zeppelin feature)
    draw.rectangle([115, 48, 123, 190], fill=(35, 38, 42), outline=(15, 16, 18))
    draw.rectangle([197, 48, 205, 190], fill=(35, 38, 42), outline=(15, 16, 18))

    # Yellow Centerline & Arrestor wires
    for cy in range(60, 660, 22):
        draw.rectangle([158, cy, 162, cy + 12], fill=(245, 215, 45))

    for wy in [560, 585, 610, 635]:
        draw.line([(50, wy), (270, wy)], fill=(230, 235, 245), width=2)

    # Massive Kriegsmarine Tower Island & Flak Batteries
    draw.rectangle([242, 220, 276, 330], fill=(65, 70, 78), outline=(20, 22, 25), width=2)
    draw.rectangle([246, 223, 272, 232], fill=(130, 195, 225))
    draw.ellipse([248, 265, 270, 295], fill=(30, 32, 36)) # Funnel

    return img

# =============================================================================
# 5. CANADA: HMCS WARRIOR (R31)
# =============================================================================
def build_carrier_canada():
    img = create_base_canvas()
    draw = ImageDraw.Draw(img)

    # Shadow
    draw.polygon([(48, 40), (272, 40), (278, 680), (42, 680)], fill=(8, 14, 22, 120))

    # RCN Dark Grey Hull & Gun Galleries
    hull_col = (54, 60, 68)
    draw.polygon([(46, 65), (274, 65), (280, 665), (40, 665)], fill=hull_col, outline=(24, 28, 34))

    # Ocean Grey Flight Deck
    deck_pts = [
        (90, 48), (230, 48), (268, 85), (270, 662),
        (254, 672), (66, 672), (50, 662), (52, 85)
    ]
    draw.polygon(deck_pts, fill=(96, 104, 114), outline=(28, 32, 38))

    # Teak plank insert down the central flight strip
    draw.rectangle([100, 52, 220, 665], fill=(128, 106, 78), outline=(65, 54, 38))
    for py in range(54, 665, 6):
        draw.line([(100, py), (220, py)], fill=(112, 92, 68, 140), width=1)

    # Centerline dashed white line
    for cy in range(65, 660, 22):
        draw.rectangle([158, cy, 162, cy + 14], fill=(245, 245, 250))

    # Bold High-Contrast Deck Number "31" (HMCS Warrior R31)
    # Left digit: '3'
    draw.rectangle([125, 80, 155, 95], fill=(245, 248, 252))
    draw.rectangle([142, 95, 155, 140], fill=(245, 248, 252))
    draw.rectangle([125, 108, 155, 120], fill=(245, 248, 252))
    draw.rectangle([125, 130, 155, 145], fill=(245, 248, 252))

    # Right digit: '1'
    draw.rectangle([165, 80, 185, 95], fill=(245, 248, 252))
    draw.rectangle([175, 95, 188, 140], fill=(245, 248, 252))
    draw.rectangle([165, 130, 195, 145], fill=(245, 248, 252))

    # PROMINENT CANADIAN RED MAPLE LEAF EMBLEM ON DECK (Mid-Deck Y=370)
    m_cy = 370
    draw.ellipse([160 - 35, m_cy - 35, 160 + 35, m_cy + 35], fill=(245, 245, 250), outline=(22, 26, 32), width=2)
    # 11-Point Red Maple Leaf
    maple_pts = [
        (160, m_cy - 28), (166, m_cy - 14), (178, m_cy - 18), (172, m_cy - 6),
        (185, m_cy + 2), (170, m_cy + 8), (174, m_cy + 20), (162, m_cy + 14),
        (163, m_cy + 28), (157, m_cy + 28), (158, m_cy + 14), (146, m_cy + 20),
        (150, m_cy + 8), (135, m_cy + 2), (148, m_cy - 6), (142, m_cy - 18),
        (154, m_cy - 14)
    ]
    draw.polygon(maple_pts, fill=(215, 30, 30))

    # Arresting wires
    for wy in [570, 595, 620, 645]:
        draw.line([(52, wy), (268, wy)], fill=(235, 235, 245), width=2)

    # Island
    draw.rectangle([242, 235, 274, 335], fill=(62, 68, 76), outline=(20, 24, 28), width=2)
    draw.rectangle([246, 238, 270, 246], fill=(135, 205, 235))
    draw.ellipse([248, 275, 268, 305], fill=(28, 30, 35))

    return img

# =============================================================================
# 6. USSR: KRASNY LUCH FRONTLINE AIRBASE
# =============================================================================
def build_carrier_soviet():
    img = create_base_canvas()
    draw = ImageDraw.Draw(img)

    # Shadow
    draw.polygon([(46, 40), (274, 40), (278, 680), (42, 680)], fill=(8, 14, 22, 120))

    # Heavy Concrete Runway Border / Grassy Berm
    dirt_col = (68, 60, 48)
    draw.polygon([(42, 50), (278, 50), (280, 670), (40, 670)], fill=dirt_col, outline=(30, 26, 20))

    # Concrete Slabs
    concrete_base = (118, 114, 108)
    draw.rectangle([54, 52, 266, 668], fill=concrete_base, outline=(45, 42, 38), width=2)

    # Expansion joints grid
    for py in range(56, 668, 28):
        draw.line([(54, py), (266, py)], fill=(75, 72, 68), width=2)
    for px in [107, 160, 213]:
        draw.line([(px, 52), (px, 668)], fill=(75, 72, 68), width=2)

    # Piano-Key Runway Threshold Bars (Touchdown points)
    # Bow / North threshold
    for tx in range(66, 255, 18):
        draw.rectangle([tx, 60, tx + 10, 110], fill=(245, 245, 250))
    # Stern / South threshold
    for tx in range(66, 255, 18):
        draw.rectangle([tx, 610, tx + 10, 660], fill=(245, 245, 250))

    # Yellow Dashed Centerline
    for cy in range(120, 600, 24):
        draw.rectangle([157, cy, 163, cy + 14], fill=(245, 215, 35))

    # Large Soviet Red Star emblem on mid-field (Y=360)
    s_cy = 360
    star_r = 38
    draw.ellipse([160 - star_r - 8, s_cy - star_r - 8, 160 + star_r + 8, s_cy + star_r + 8], fill=(245, 245, 250))
    # 5-Point Red Star
    star_pts = []
    for i in range(10):
        r = star_r if i % 2 == 0 else star_r * 0.40
        ang = -math.pi / 2.0 + i * math.pi / 5.0
        star_pts.append((160 + r * math.cos(ang), s_cy + r * math.sin(ang)))
    draw.polygon(star_pts, fill=(215, 28, 28), outline=(245, 215, 35), width=2)

    # Field Control Bunker / Radar Tower
    draw.rectangle([240, 240, 272, 330], fill=(55, 52, 48), outline=(25, 24, 20), width=2)
    draw.rectangle([244, 244, 268, 252], fill=(130, 195, 225))
    draw.line([(256, 255), (256, 220)], fill=(20, 20, 18), width=3) # Mast

    return img

def main():
    sprites_dir = Path("games/skyace/sprites")
    sprites_dir.mkdir(parents=True, exist_ok=True)
    art_dir = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62")

    generators = {
        "p38": ("carrier_p38", build_carrier_usa),
        "zero": ("carrier_zero", build_carrier_japan),
        "spitfire": ("carrier_spitfire", build_carrier_britain),
        "bf109": ("carrier_bf109", build_carrier_germany),
        "mosquito": ("carrier_mosquito", build_carrier_canada),
        "yak3": ("carrier_yak3", build_carrier_soviet),
    }

    print("[Sky Ace] Generating 6 historical 3D aircraft carriers & frontline airbases...")
    for faction, (fname, func) in generators.items():
        carrier_img = func()
        out_spr = sprites_dir / f"{fname}.png"
        out_art = art_dir / f"{fname}.png"
        carrier_img.save(out_spr)
        carrier_img.save(out_art)
        print(f"✓ Saved {fname}.png (320x720)")

    # Also save default carrier_deck.png
    build_carrier_usa().save(sprites_dir / "carrier_deck.png")
    print("✓ Updated default carrier_deck.png")

if __name__ == "__main__":
    main()

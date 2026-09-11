#!/usr/bin/env python3
"""
Sky Ace • Master P-38 "Super Ace" Artisan Sprite Renderer & Animator
Creates the definitive high-resolution P-38 Lightning sprite set:
- Level flight with 3-phase counter-rotating propeller spin
- Smooth 2-stage Banking Left and Right with dynamic light glints
- Complete 8-stage 360° Loop-the-Loop maneuver with altitude scale
- Compiles an animated GIF and WebP displaying flight, banking, and loop-the-loop over Pacific ocean
- Exports sheet_player_p38.png and sheet_player_p38.json
"""

import math
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

SPRITES_DIR = Path("games/skyace/sprites")
SPRITES_DIR.mkdir(parents=True, exist_ok=True)

SCRATCH_DIR = Path("scratch")
SCRATCH_DIR.mkdir(parents=True, exist_ok=True)

BRAIN_DIR = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62")

C_TRANS = (0, 0, 0, 0)

# =============================================================================
# ARTISAN MILITARY PALETTE (Rich Shaded USAAF Olive Drab & Aluminum)
# =============================================================================
C_OUTLINE = (18, 26, 18, 255)         # Crisp dark silhouette
C_DEEP_SHADOW = (34, 46, 32, 255)     # Underside recess
C_SHADOW = (52, 70, 48, 255)          # Shaded fuselage panels
C_BASE = (74, 100, 70, 255)           # Standard USAAF Olive Drab
C_MID_LIGHT = (98, 128, 92, 255)      # Top surface curvature
C_HIGHLIGHT = (130, 164, 122, 255)    # Direct Pacific sunlight rim
C_GLINT = (245, 255, 240, 255)        # Metallic specular sparkle

# Glass Canopy
C_CANOPY_DEEP = (28, 65, 95, 255)
C_CANOPY_MID = (55, 125, 175, 240)
C_CANOPY_LIGHT = (140, 215, 255, 255)
C_CANOPY_SPEC = (255, 255, 255, 230)

# Markings & Mechanicals
C_YELLOW_TIP = (245, 210, 40, 255)
C_PROP_BLUR = (245, 220, 70, 130)
C_PROP_BLADE = (45, 45, 48, 220)
C_STAR_BLUE = (25, 50, 120, 255)
C_STAR_WHITE = (245, 245, 250, 255)
C_GUN_STEEL = (30, 30, 32, 255)
C_EXHAUST = (190, 85, 30, 255)

FRAME_SIZE = 96  # 96x96 px per frame

def create_base_canvas():
    return Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), C_TRANS)

def draw_p38_artisan(state="level", bank_deg=0, prop_angle=0, pitch_deg=0, altitude_scale=1.0, damaged=False):
    """
    Renders an artisan-grade P-38 Lightning with authentic twin-boom geometry,
    subtle curved shading, cockpit interior glass, and counter-rotating props.
    """
    w, h = FRAME_SIZE, FRAME_SIZE
    img = create_base_canvas()
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    # Perspective banking offsets
    rad_b = math.radians(bank_deg)
    bx_shift = int(math.sin(rad_b) * 10)
    wing_droop = int(math.sin(rad_b) * 6)

    # -------------------------------------------------------------------------
    # 1. MAIN WINGS (Span: 76px, Root Chord: 14px, Tip Chord: 8px)
    # -------------------------------------------------------------------------
    span_left = 38 + (4 if bank_deg > 0 else -4 if bank_deg < 0 else 0)
    span_right = 38 + (-4 if bank_deg > 0 else 4 if bank_deg < 0 else 0)

    wing_pts = [
        (cx - span_left, cy - 2 + wing_droop),          # Port wingtip leading edge
        (cx - 16, cy - 6),                             # Port wing root leading edge
        (cx + 16, cy - 6),                             # Starboard wing root leading edge
        (cx + span_right, cy - 2 - wing_droop),         # Starboard wingtip leading edge
        (cx + span_right - 2, cy + 6 - wing_droop),     # Starboard wingtip trailing edge
        (cx + 14, cy + 8),                             # Starboard root trailing edge
        (cx - 14, cy + 8),                             # Port root trailing edge
        (cx - span_left + 2, cy + 6 + wing_droop)      # Port wingtip trailing edge
    ]
    draw.polygon(wing_pts, fill=C_BASE, outline=C_OUTLINE)

    # Wing upper camber highlight
    draw.line([
        (cx - span_left + 4, cy - 1 + wing_droop),
        (cx - 16, cy - 4),
        (cx + 16, cy - 4),
        (cx + span_right - 4, cy - 1 - wing_droop)
    ], fill=C_MID_LIGHT, width=2)

    # Leading edge sunlit glint (port wing catches direct top-left sun)
    draw.line([
        (cx - span_left + 2, cy - 2 + wing_droop),
        (cx - 18, cy - 5)
    ], fill=C_HIGHLIGHT, width=1)

    # Aileron & Flap hinge panel lines
    draw.line([(cx - span_left + 6, cy + 3 + wing_droop), (cx - 24, cy + 4)], fill=C_SHADOW, width=1)
    draw.line([(cx + 24, cy + 4), (cx + span_right - 6, cy + 3 - wing_droop)], fill=C_SHADOW, width=1)

    # Yellow Combat Wingtips
    draw.polygon([
        (cx - span_left, cy - 2 + wing_droop),
        (cx - span_left + 6, cy - 2 + wing_droop),
        (cx - span_left + 6, cy + 6 + wing_droop),
        (cx - span_left + 2, cy + 6 + wing_droop)
    ], fill=C_YELLOW_TIP, outline=C_OUTLINE)

    draw.polygon([
        (cx + span_right - 6, cy - 2 - wing_droop),
        (cx + span_right, cy - 2 - wing_droop),
        (cx + span_right - 2, cy + 6 - wing_droop),
        (cx + span_right - 6, cy + 6 - wing_droop)
    ], fill=C_YELLOW_TIP, outline=C_OUTLINE)

    # USAAF Star Insignia on Port Wing
    draw.ellipse([cx - 30, cy - 1 + wing_droop, cx - 18, cy + 6 + wing_droop], fill=C_STAR_BLUE)
    draw.polygon([
        (cx - 24, cy - 1 + wing_droop),
        (cx - 21, cy + 6 + wing_droop),
        (cx - 27, cy + 6 + wing_droop)
    ], fill=C_STAR_WHITE)

    # -------------------------------------------------------------------------
    # 2. TWIN ENGINE BOOMS (Nacelles, Superchargers, Twin Rudders)
    # -------------------------------------------------------------------------
    for sign in [-1, 1]:
        # Boom X coordinate
        bx = cx + sign * 19 + (bx_shift // 2)
        
        # Engine Nacelle body
        nacelle_pts = [
            (bx - 5, cy - 26),
            (bx + 5, cy - 26),
            (bx + 6, cy - 10),
            (bx + 5, cy + 24),
            (bx - 5, cy + 24),
            (bx - 6, cy - 10)
        ]
        draw.polygon(nacelle_pts, fill=C_BASE, outline=C_OUTLINE)

        # Sunlit longitudinal specular spine
        spine_x = bx - 2 if sign < 0 else bx + 1
        draw.line([(spine_x, cy - 22), (spine_x, cy + 20)], fill=C_HIGHLIGHT, width=1)
        draw.line([(spine_x + (1 if sign < 0 else -1), cy - 20), (spine_x + (1 if sign < 0 else -1), cy + 18)], fill=C_MID_LIGHT, width=1)

        # Turbo-supercharger vents on top of booms
        draw.rectangle([bx - 2, cy - 3, bx + 2, cy + 5], fill=C_DEEP_SHADOW)
        draw.line([(bx - 2, cy), (bx + 2, cy)], fill=C_EXHAUST)

        # Radiator air scoops on boom sides
        draw.rectangle([bx + (4 if sign > 0 else -5), cy + 10, bx + (5 if sign > 0 else -4), cy + 18], fill=C_DEEP_SHADOW)

        # Twin Tail Fins / Vertical Rudders
        rudder_pts = [
            (bx - 3 + bx_shift // 3, cy + 22),
            (bx + 3 + bx_shift // 3, cy + 22),
            (bx + 4 + bx_shift, cy + 36),
            (bx - 4 + bx_shift, cy + 36)
        ]
        draw.polygon(rudder_pts, fill=C_SHADOW, outline=C_OUTLINE)
        draw.line([(bx - 1 + bx_shift // 2, cy + 24), (bx - 1 + bx_shift // 2, cy + 34)], fill=C_HIGHLIGHT, width=1)

        # ---------------------------------------------------------------------
        # PROPELLERS: Counter-rotating 3-blade Curtiss Electric Props
        # ---------------------------------------------------------------------
        prop_y = cy - 27
        # Outer motion disc blur
        draw.ellipse([bx - 11, prop_y - 3, bx + 11, prop_y + 3], fill=C_PROP_BLUR)
        draw.ellipse([bx - 7, prop_y - 2, bx + 7, prop_y + 2], fill=(255, 235, 90, 80))

        # Distinct 3 blades rotating with prop_angle
        p_dir = 1 if sign < 0 else -1  # Counter-rotating!
        for b_idx in range(3):
            theta = math.radians(prop_angle * p_dir + b_idx * 120)
            px_tip = bx + math.cos(theta) * 10
            py_tip = prop_y + math.sin(theta) * 3
            draw.line([(bx, prop_y), (px_tip, py_tip)], fill=C_PROP_BLADE, width=1)
            # Yellow blade tip dot
            draw.point((int(px_tip), int(py_tip)), fill=C_YELLOW_TIP)

        # Spinner nose cone
        draw.ellipse([bx - 2, prop_y - 3, bx + 2, prop_y + 1], fill=C_HIGHLIGHT, outline=C_OUTLINE)

    # -------------------------------------------------------------------------
    # 3. HORIZONTAL STABILIZER (Elevator connecting twin booms)
    # -------------------------------------------------------------------------
    draw.rectangle([cx - 21 + bx_shift // 2, cy + 28, cx + 21 + bx_shift // 2, cy + 33], 
                   fill=C_BASE, outline=C_OUTLINE)
    draw.line([(cx - 20 + bx_shift // 2, cy + 29), (cx + 20 + bx_shift // 2, cy + 29)], fill=C_MID_LIGHT, width=1)

    # -------------------------------------------------------------------------
    # 4. CENTRAL NACELLE POD (Cockpit, Nose Cannons)
    # -------------------------------------------------------------------------
    pod_pts = [
        (cx - 6 + bx_shift, cy - 30),
        (cx + 6 + bx_shift, cy - 30),
        (cx + 8 + bx_shift, cy - 10),
        (cx + 6 + bx_shift, cy + 12),
        (cx - 6 + bx_shift, cy + 12),
        (cx - 8 + bx_shift, cy - 10)
    ]
    draw.polygon(pod_pts, fill=C_BASE, outline=C_OUTLINE)
    draw.line([(cx - 3 + bx_shift, cy - 26), (cx - 3 + bx_shift, cy + 10)], fill=C_HIGHLIGHT, width=1)

    # Nose Armament: 4x .50 cal M2 Brownings + 20mm Hispano Cannon
    draw.rectangle([cx - 3 + bx_shift, cy - 33, cx + 3 + bx_shift, cy - 30], fill=C_GUN_STEEL)
    draw.point((cx - 2 + bx_shift, cy - 34), fill=(255, 255, 255, 255))
    draw.point((cx + 2 + bx_shift, cy - 34), fill=(255, 255, 255, 255))
    draw.point((cx + bx_shift, cy - 35), fill=(240, 240, 240, 255))  # Central 20mm snout

    # Greenhouse Glass Canopy (Pilot visible inside)
    canopy_pts = [
        (cx - 3 + bx_shift, cy - 20),
        (cx + 3 + bx_shift, cy - 20),
        (cx + 5 + bx_shift, cy - 4),
        (cx - 5 + bx_shift, cy - 4)
    ]
    draw.polygon(canopy_pts, fill=C_CANOPY_MID, outline=C_CANOPY_DEEP)
    # Pilot helmet silhouette inside
    draw.ellipse([cx - 2 + bx_shift, cy - 14, cx + 2 + bx_shift, cy - 9], fill=(160, 130, 90, 255))
    # Canopy glass glare streaks
    draw.line([(cx - 2 + bx_shift, cy - 18), (cx - 2 + bx_shift, cy - 6)], fill=C_CANOPY_SPEC, width=1)
    draw.line([(cx + 1 + bx_shift, cy - 17), (cx + 1 + bx_shift, cy - 8)], fill=C_CANOPY_LIGHT, width=1)

    # -------------------------------------------------------------------------
    # SCALE / PITCH TRANSFORMS (For Loop Maneuver)
    # -------------------------------------------------------------------------
    if altitude_scale != 1.0 or pitch_deg != 0:
        new_w = max(16, int(w * altitude_scale))
        new_h = max(16, int(h * altitude_scale * math.cos(math.radians(pitch_deg))))
        scaled = img.resize((new_w, new_h), Image.Resampling.BILINEAR)
        out = create_base_canvas()
        out.paste(scaled, ((w - new_w) // 2, (h - new_h) // 2), scaled)
        return out

    return img

def render_loop_maneuver_frame(stage_idx):
    """
    Renders the 8 authentic loop stages:
    0: Pitch up start (45°)
    1: Steep vertical climb (70°)
    2: Pure vertical knife-edge (90°)
    3: Inverted roll-in (135°)
    4: Inverted 180° apex (scaled up 1.35x high altitude + solar glint)
    5: Vertical dive (270°)
    6: Pull out (315°)
    7: Level recovery (360°)
    """
    w, h = FRAME_SIZE, FRAME_SIZE
    cx, cy = w // 2, h // 2

    if stage_idx == 0:
        # Pitch up 45°: Foreshortened wings
        return draw_p38_artisan(pitch_deg=40, prop_angle=30)

    elif stage_idx == 1:
        # Climb 70°: Highly compressed wings, dominant nose
        return draw_p38_artisan(pitch_deg=65, prop_angle=60, altitude_scale=1.1)

    elif stage_idx == 2:
        # Pure Vertical 90°: Edge-on silver line with roaring prop halo
        img = create_base_canvas()
        draw = ImageDraw.Draw(img)
        # Edge-on wing bar
        draw.rectangle([cx - 36, cy - 3, cx + 36, cy + 3], fill=C_HIGHLIGHT, outline=C_OUTLINE)
        draw.line([(cx - 34, cy), (cx + 34, cy)], fill=C_GLINT, width=1)
        # Twin boom nacelle sides
        for sign in [-1, 1]:
            bx = cx + sign * 19
            draw.rectangle([bx - 4, cy - 8, bx + 4, cy + 8], fill=C_SHADOW, outline=C_OUTLINE)
            draw.ellipse([bx - 10, cy - 10, bx + 10, cy - 4], fill=C_PROP_BLUR)
        draw.rectangle([cx - 5, cy - 12, cx + 5, cy + 12], fill=C_BASE, outline=C_OUTLINE)
        return img

    elif stage_idx == 3:
        # Inverted Roll-in 135°
        base = draw_p38_artisan(prop_angle=90, altitude_scale=1.2)
        inv = base.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        return inv

    elif stage_idx == 4:
        # Inverted 180° Apex: High-altitude giant scale (1.35x), belly up, solar sheen!
        base = draw_p38_artisan(prop_angle=120)
        # Flip vertically to show belly/underside
        inv = base.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        scaled = inv.resize((int(w * 1.32), int(h * 1.32)), Image.Resampling.BILINEAR)
        img = create_base_canvas()
        img.paste(scaled, ((w - scaled.width) // 2, (h - scaled.height) // 2), scaled)
        # Add high-altitude invulnerability glint flash
        d = ImageDraw.Draw(img)
        d.line([(cx - 32, cy - 12), (cx + 32, cy + 12)], fill=(255, 255, 255, 200), width=3)
        d.line([(cx - 16, cy + 16), (cx + 16, cy - 16)], fill=(255, 255, 255, 160), width=2)
        return img

    elif stage_idx == 5:
        # Vertical Dive 270°: Nose pointing straight down
        base = draw_p38_artisan(prop_angle=150)
        # Flip 180 degrees (rotate)
        dive = base.rotate(180)
        scaled = dive.resize((int(w * 1.15), int(h * 1.15)), Image.Resampling.BILINEAR)
        img = create_base_canvas()
        img.paste(scaled, ((w - scaled.width) // 2, (h - scaled.height) // 2), scaled)
        return img

    elif stage_idx == 6:
        # Pull out 315°: Returning to level
        return draw_p38_artisan(pitch_deg=35, prop_angle=180, altitude_scale=1.05)

    elif stage_idx == 7:
        # Level flight resumption
        return draw_p38_artisan(prop_angle=210)

    return draw_p38_artisan()

# =============================================================================
# COMPILE SPRITE SHEET & ANIMATED PREVIEWS
# =============================================================================
def generate_p38_assets():
    print("[Sky Ace] Generating artisan P-38 Lightning sprite sheet...")

    frames = {
        # Level flight (3 prop spin phases)
        "fly_0": draw_p38_artisan(bank_deg=0, prop_angle=0),
        "fly_1": draw_p38_artisan(bank_deg=0, prop_angle=40),
        "fly_2": draw_p38_artisan(bank_deg=0, prop_angle=80),
        # Banking Left
        "bank_left_1": draw_p38_artisan(bank_deg=-15, prop_angle=20),
        "bank_left_2": draw_p38_artisan(bank_deg=-30, prop_angle=60),
        # Banking Right
        "bank_right_1": draw_p38_artisan(bank_deg=15, prop_angle=20),
        "bank_right_2": draw_p38_artisan(bank_deg=30, prop_angle=60),
        # 8-Stage Loop
        "loop_0": render_loop_maneuver_frame(0),
        "loop_1": render_loop_maneuver_frame(1),
        "loop_2": render_loop_maneuver_frame(2),
        "loop_3": render_loop_maneuver_frame(3),
        "loop_4": render_loop_maneuver_frame(4),
        "loop_5": render_loop_maneuver_frame(5),
        "loop_6": render_loop_maneuver_frame(6),
        "loop_7": render_loop_maneuver_frame(7),
    }

    # Pack into sheet_player_p38.png (4 cols x 4 rows, 96x96 cells)
    cols = 4
    rows = math.ceil(len(frames) / cols)
    sheet_w, sheet_h = cols * FRAME_SIZE, rows * FRAME_SIZE
    sheet = Image.new("RGBA", (sheet_w, sheet_h), C_TRANS)
    meta = {"meta": {"image": "sheet_player_p38.png", "cell": FRAME_SIZE, "cols": cols, "rows": rows}, "frames": {}}

    for idx, (name, img) in enumerate(frames.items()):
        c = idx % cols
        r = idx // cols
        x = c * FRAME_SIZE
        y = r * FRAME_SIZE
        sheet.paste(img, (x, y), img)
        meta["frames"][name] = {"x": x, "y": y, "w": FRAME_SIZE, "h": FRAME_SIZE}

    sheet_path = SPRITES_DIR / "sheet_player_p38.png"
    json_path = SPRITES_DIR / "sheet_player_p38.json"
    sheet.save(sheet_path, format="PNG", optimize=True)
    json_path.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(f"✓ Saved master P-38 sheet: {sheet_path} ({sheet_w}x{sheet_h})")

    # =========================================================================
    # RENDER ANIMATED PREVIEW GIF & WEBP
    # =========================================================================
    print("[Sky Ace] Generating animated flight demonstration over Pacific ocean...")
    anim_frames = []

    # Background ocean patch (320x320)
    bg_w, bg_h = 320, 320

    # Build sequence of animation states:
    # 1. Level cruise (propeller spin: 6 frames)
    # 2. Bank left (4 frames)
    # 3. Return to center (2 frames)
    # 4. Bank right (4 frames)
    # 5. Return to center (2 frames)
    # 6. Execute full Loop-the-Loop maneuver (8 frames)
    # 7. Level cruise (4 frames)

    sequence = []
    # Cruise
    for i in range(6): sequence.append(("fly", 0, i * 40))
    # Bank Left
    sequence.append(("bank_left", -15, 240))
    sequence.append(("bank_left", -30, 280))
    sequence.append(("bank_left", -30, 320))
    sequence.append(("bank_left", -15, 360))
    sequence.append(("fly", 0, 400))
    # Bank Right
    sequence.append(("bank_right", 15, 440))
    sequence.append(("bank_right", 30, 480))
    sequence.append(("bank_right", 30, 520))
    sequence.append(("bank_right", 15, 560))
    sequence.append(("fly", 0, 600))
    # Loop
    for l_idx in range(8):
        sequence.append(("loop", l_idx, 0))
    # Settle
    for i in range(4): sequence.append(("fly", 0, i * 40))

    # Render each composite frame over scrolling ocean
    for frame_idx, item in enumerate(sequence):
        mode = item[0]
        comp = Image.new("RGBA", (bg_w, bg_h), (20, 60, 110, 255))
        d_bg = ImageDraw.Draw(comp)

        # Scrolling ocean waves
        scroll_y = (frame_idx * 6) % 32
        for wy in range(-32, bg_h + 32, 24):
            y_pos = wy + scroll_y
            for wx in range(0, bg_w, 32):
                d_bg.arc([wx - 8, y_pos, wx + 8, y_pos + 6], 180, 360, fill=(35, 90, 150, 255), width=2)

        # Tropical island in background on right side
        island_y = (140 - frame_idx * 4)
        d_bg.ellipse([bg_w - 90, island_y, bg_w + 20, island_y + 90], fill=(40, 150, 160, 255))
        d_bg.ellipse([bg_w - 80, island_y + 10, bg_w + 10, island_y + 80], fill=(225, 205, 145, 255))
        d_bg.ellipse([bg_w - 70, island_y + 20, bg_w, island_y + 70], fill=(35, 115, 45, 255))

        # Cloud shadows drifting
        d_bg.ellipse([30, (80 - frame_idx * 2), 110, (130 - frame_idx * 2)], fill=(12, 40, 75, 140))

        # Get P-38 frame
        if mode == "fly":
            spr = draw_p38_artisan(bank_deg=0, prop_angle=item[2])
        elif mode == "bank_left" or mode == "bank_right":
            spr = draw_p38_artisan(bank_deg=item[1], prop_angle=item[2])
        elif mode == "loop":
            spr = render_loop_maneuver_frame(item[1])

        # Paste P-38 centered
        px = (bg_w - FRAME_SIZE) // 2
        py = (bg_h - FRAME_SIZE) // 2 + (10 if mode == "loop" and item[1] in [0, 1] else -15 if mode == "loop" and item[1] == 4 else 0)

        # Shadow beneath plane (displaced during loop)
        if mode != "loop" or item[1] not in [2, 3, 4]:
            shadow_offset = 24 if mode != "loop" else 36
            shadow = spr.copy()
            # Tint shadow dark blue-black
            s_pix = shadow.load()
            for sy in range(shadow.height):
                for sx in range(shadow.width):
                    if s_pix[sx, sy][3] > 0:
                        s_pix[sx, sy] = (10, 30, 60, 110)
            comp.paste(shadow, (px + 6, py + shadow_offset), shadow)

        comp.paste(spr, (px, py), spr)

        # Status text overlay
        d_bg.rectangle([0, 0, bg_w, 24], fill=(12, 18, 26, 210))
        label = "CRUISE (PROP ROTATION)" if mode == "fly" else "BANKING MANEUVER" if "bank" in mode else f"360° LOOP-THE-LOOP (STAGE {item[1]+1}/8)"
        d_bg.text((12, 6), f"P-38 SUPER ACE • {label}", fill=(0, 240, 255, 255))

        anim_frames.append(comp.convert("RGB"))

    # Save animated GIF and WebP
    gif_path = SCRATCH_DIR / "p38_animation.gif"
    webp_path = SCRATCH_DIR / "p38_animation.webp"

    anim_frames[0].save(
        gif_path,
        save_all=True,
        append_images=anim_frames[1:],
        duration=90,  # ~11 FPS smooth
        loop=0,
        optimize=True
    )

    anim_frames[0].save(
        webp_path,
        save_all=True,
        append_images=anim_frames[1:],
        duration=90,
        loop=0,
        method=6
    )

    # Copy to brain artifact directory for artifact embedding
    brain_gif = BRAIN_DIR / "p38_animation.gif"
    anim_frames[0].save(
        brain_gif,
        save_all=True,
        append_images=anim_frames[1:],
        duration=90,
        loop=0,
        optimize=True
    )

    print(f"✓ Saved animated GIF to {gif_path} and {brain_gif}")

if __name__ == "__main__":
    generate_p38_assets()

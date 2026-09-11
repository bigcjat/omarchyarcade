#!/usr/bin/env python3
"""
Sky Ace • Mitsubishi A6M Zero Cel-Shader & Sprite Rasterizer
Renders the 3D Zero mesh into high-detail pixel art sprites in Style 3 (Tactical Matte Naval Green)
with authentic single-engine 3-blade propeller with safety tips, crimson Hinomaru roundels, and blue-black cowl.
"""

import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
from zero_3d_engine import build_zero_mesh

# =============================================================================
# PALETTES FOR MITSUBISHI A6M ZERO (TACTICAL DEFAULT)
# =============================================================================
PALETTES_ZERO = {
    # Tactical Matte Military Camo (Style 3 - IJN Dark Naval Green)
    "tactical": {
        "outline": (16, 22, 16, 255),
        "light_dir": np.array([-0.3, 0.5, 0.81]),
        "steps": [0.3, 0.7],
        "materials": {
            1: {"shadow": (34, 52, 38),   "mid": (56, 84, 62),   "high": (84, 120, 92)},    # Body (IJN Green)
            2: {"shadow": (18, 22, 28),   "mid": (28, 34, 44),   "high": (52, 60, 74)},     # Cowl (Blue-Black)
            3: {"shadow": (160, 22, 22),  "mid": (215, 34, 34),  "high": (245, 65, 65)},    # Hinomaru Red
            4: {"shadow": (175, 130, 20), "mid": (225, 175, 30), "high": (250, 210, 60)},   # Yellow ID Band
            5: {"shadow": (28, 48, 64),   "mid": (52, 90, 120),  "high": (125, 175, 210)},  # Canopy Glass
            6: {"shadow": (22, 34, 25),   "mid": (36, 54, 40),   "high": (58, 82, 64)},     # Canopy Frame
            7: {"shadow": (18, 20, 22),   "mid": (32, 36, 40),   "high": (64, 72, 80)},     # Cannons
            8: {"shadow": (24, 30, 26),   "mid": (42, 52, 45),   "high": (70, 84, 74)},     # Spinner
            9: {"shadow": (32, 50, 36),   "mid": (54, 82, 60),   "high": (82, 118, 90)},    # Tail
            10: {"shadow": (80, 96, 85),  "mid": (122, 142, 128),"high": (160, 182, 168)}, # Belly (Ash Gray)
        },
        "prop_color": (240, 220, 80, 140), # Amber propeller blur
        "prop_core": (255, 245, 180, 200),
        "outline_width": 2,
    },
    "arcade": {
        "outline": (14, 24, 16, 255),
        "light_dir": np.array([-0.35, 0.45, 0.82]),
        "steps": [0.25, 0.65],
        "materials": {
            1: {"shadow": (36, 68, 42),   "mid": (62, 110, 72),  "high": (102, 165, 115)},  # Vibrant Green
            2: {"shadow": (18, 24, 36),   "mid": (32, 42, 62),   "high": (58, 74, 105)},    # Blue Cowl
            3: {"shadow": (180, 20, 20),  "mid": (240, 35, 35),  "high": (255, 80, 80)},    # Red Hinomaru
            4: {"shadow": (190, 145, 20), "mid": (245, 195, 30), "high": (255, 230, 95)},   # Bright Yellow
            5: {"shadow": (35, 75, 115),  "mid": (65, 145, 205), "high": (165, 230, 255)},  # Cyan Canopy
            6: {"shadow": (20, 42, 25),   "mid": (38, 70, 45),   "high": (62, 105, 72)},    # Frame
            7: {"shadow": (22, 24, 26),   "mid": (42, 46, 50),   "high": (85, 92, 100)},    # Guns
            8: {"shadow": (26, 36, 28),   "mid": (48, 68, 52),   "high": (85, 118, 90)},    # Spinner
            9: {"shadow": (34, 65, 40),   "mid": (60, 108, 70),  "high": (98, 162, 112)},   # Tail
            10: {"shadow": (90, 112, 98), "mid": (138, 165, 148),"high": (185, 212, 195)},# Belly
        },
        "prop_color": (95, 230, 245, 160),
        "prop_core": (245, 255, 255, 220),
        "outline_width": 2,
    },
    "artisan": {
        "outline": (12, 18, 14, 255),
        "light_dir": np.array([-0.4, 0.4, 0.82]),
        "steps": [0.15, 0.45, 0.75],
        "materials": {
            1: {"tones": [(26, 42, 30), (44, 68, 48), (68, 102, 74), (105, 148, 112)]},
            2: {"tones": [(14, 18, 24), (24, 30, 40), (40, 48, 64), (72, 85, 110)]},
            3: {"tones": [(130, 18, 18), (185, 28, 28), (235, 42, 42), (255, 95, 95)]},
            4: {"tones": [(150, 110, 15), (200, 152, 22), (242, 195, 32), (255, 232, 90)]},
            5: {"tones": [(24, 55, 85), (48, 108, 155), (92, 175, 230), (210, 245, 255)]},
            6: {"tones": [(18, 30, 20), (32, 50, 36), (50, 76, 54), (80, 114, 85)]},
            7: {"tones": [(16, 18, 20), (28, 32, 36), (52, 58, 65), (95, 105, 115)]},
            8: {"tones": [(20, 28, 22), (36, 48, 38), (58, 76, 60), (90, 116, 92)]},
            9: {"tones": [(24, 40, 28), (42, 66, 46), (65, 98, 72), (102, 144, 110)]},
            10: {"tones": [(65, 80, 70), (98, 118, 104), (135, 158, 142), (175, 200, 182)]},
        },
        "prop_color": (140, 240, 255, 180),
        "prop_core": (255, 255, 255, 240),
        "outline_width": 2,
    }
}

def render_3d_zero_frame(mesh, roll_deg=0.0, pitch_deg=0.0, yaw_deg=0.0, prop_angle=0.0, 
                         style="tactical", size=256, scale=1.75):
    """
    Renders the 3D Mitsubishi A6M Zero into an authentic cel-shaded RGBA sprite.
    """
    config = PALETTES_ZERO[style]
    palette = config["materials"]
    l_dir = config["light_dir"] / np.linalg.norm(config["light_dir"])

    # Rotation matrices
    # Roll (around Y)
    r_rad = math.radians(roll_deg)
    R_roll = np.array([
        [math.cos(r_rad), 0, math.sin(r_rad)],
        [0, 1, 0],
        [-math.sin(r_rad), 0, math.cos(r_rad)]
    ])

    # Pitch (around X)
    p_rad = math.radians(pitch_deg)
    R_pitch = np.array([
        [1, 0, 0],
        [0, math.cos(p_rad), -math.sin(p_rad)],
        [0, math.sin(p_rad), math.cos(p_rad)]
    ])

    # Yaw (around Z)
    y_rad = math.radians(yaw_deg)
    R_yaw = np.array([
        [math.cos(y_rad), -math.sin(y_rad), 0],
        [math.sin(y_rad), math.cos(y_rad), 0],
        [0, 0, 1]
    ])

    R_total = R_yaw @ R_pitch @ R_roll

    # Transform vertices to screen space
    cx, cy = size / 2.0, size / 2.0
    v_screen = []
    v_transformed = []
    
    for v in mesh.vertices:
        v_np = np.array(v)
        v_rot = R_total @ v_np
        v_transformed.append(v_rot)
        # Orthographic projection: top-down view looking down Z axis onto X-Y screen plane
        sx = cx + v_rot[0] * scale
        sy = cy - v_rot[1] * scale
        sz = v_rot[2]
        v_screen.append((sx, sy, sz))

    # Compute face normals and sort for rasterization
    faces_to_render = []
    for face in mesh.faces:
        v0_idx, v1_idx, v2_idx, mat_id = face
        v0 = v_transformed[v0_idx]
        v1 = v_transformed[v1_idx]
        v2 = v_transformed[v2_idx]

        e1 = v1 - v0
        e2 = v2 - v0
        normal = np.cross(e1, e2)
        norm_len = np.linalg.norm(normal)
        if norm_len < 1e-6:
            continue
        normal = normal / norm_len

        # Lighting intensity
        intensity = float(np.dot(normal, l_dir))

        # Mean depth
        mean_z = (v_screen[v0_idx][2] + v_screen[v1_idx][2] + v_screen[v2_idx][2]) / 3.0
        faces_to_render.append((mean_z, face, normal, intensity))

    # Painter's sort from back to front
    faces_to_render.sort(key=lambda x: x[0])

    # Software Z-Buffer Rasterizer
    img_arr = np.zeros((size, size, 4), dtype=np.uint8)
    z_buffer = np.full((size, size), -99999.0, dtype=np.float32)

    for mean_z, (v0_idx, v1_idx, v2_idx, mat_id), normal, intensity in faces_to_render:
        mat_entry = palette.get(mat_id, palette[1])
        
        # Cel-shade tone mapping
        if "tones" in mat_entry:
            tones = mat_entry["tones"]
            if intensity < 0.15:
                col = tones[0]
            elif intensity < 0.45:
                col = tones[1]
            elif intensity < 0.75:
                col = tones[2]
            else:
                col = tones[3]
        else:
            steps = config["steps"]
            if intensity < steps[0]:
                col = mat_entry["shadow"]
            elif intensity < steps[1]:
                col = mat_entry["mid"]
            else:
                col = mat_entry["high"]

        # Triangle rasterization
        p0 = v_screen[v0_idx]
        p1 = v_screen[v1_idx]
        p2 = v_screen[v2_idx]

        min_x = max(0, int(math.floor(min(p0[0], p1[0], p2[0]))))
        max_x = min(size - 1, int(math.ceil(max(p0[0], p1[0], p2[0]))))
        min_y = max(0, int(math.floor(min(p0[1], p1[1], p2[1]))))
        max_y = min(size - 1, int(math.ceil(max(p0[1], p1[1], p2[1]))))

        if min_x > max_x or min_y > max_y:
            continue

        denom = (p1[1] - p2[1]) * (p0[0] - p2[0]) + (p2[0] - p1[0]) * (p0[1] - p2[1])
        if abs(denom) < 1e-6:
            continue

        x_grid, y_grid = np.meshgrid(np.arange(min_x, max_x + 1), np.arange(min_y, max_y + 1))
        w0 = ((p1[1] - p2[1]) * (x_grid - p2[0]) + (p2[0] - p1[0]) * (y_grid - p2[1])) / denom
        w1 = ((p2[1] - p0[1]) * (x_grid - p2[0]) + (p0[0] - p2[0]) * (y_grid - p2[1])) / denom
        w2 = 1.0 - w0 - w1

        inside = (w0 >= 0.0) & (w1 >= 0.0) & (w2 >= 0.0)
        z_interp = w0 * p0[2] + w1 * p1[2] + w2 * p2[2]

        sub_z = z_buffer[min_y:max_y+1, min_x:max_x+1]
        z_pass = inside & (z_interp > sub_z)

        if np.any(z_pass):
            sub_z[z_pass] = z_interp[z_pass]
            sub_img = img_arr[min_y:max_y+1, min_x:max_x+1]
            sub_img[z_pass, :3] = col
            sub_img[z_pass, 3] = 255

    base_img = Image.fromarray(img_arr, "RGBA")

    # Inking pass
    alpha = img_arr[:, :, 3]
    solid_mask = (alpha > 0).astype(np.uint8) * 255
    mask_img = Image.fromarray(solid_mask, "L")
    edges = mask_img.filter(ImageFilter.FIND_EDGES)
    dilated_edges = edges.filter(ImageFilter.MaxFilter(3))
    dil_arr = np.array(dilated_edges)

    outline_col = config["outline"]
    out_mask = (dil_arr > 30) & (alpha == 0)
    img_arr[out_mask] = outline_col

    result_img = Image.fromarray(img_arr, "RGBA")
    draw_final = ImageDraw.Draw(result_img)

    # -------------------------------------------------------------------------
    # AUTHENTIC HINOMARU (RISING SUN) ROUNDELS ON BOTH WINGS
    # -------------------------------------------------------------------------
    # Red circle roundels on mid-wing stations
    # -------------------------------------------------------------------------
    # AUTHENTIC HINOMARU (RISING SUN) ROUNDELS & LEADING EDGE I.D. STRIPES
    # -------------------------------------------------------------------------
    # Yellow leading-edge I.D. band on inner wings
    for side_sign in [-1.0, 1.0]:
        le_start = np.array([side_sign * 8.0, 23.5, 0.4])
        le_end = np.array([side_sign * 26.0, 21.0, 1.0])
        p_start = R_total @ le_start
        p_end = R_total @ le_end
        sx0, sy0 = cx + p_start[0] * scale, cy - p_start[1] * scale
        sx1, sy1 = cx + p_end[0] * scale, cy - p_end[1] * scale
        draw_final.line([sx0, sy0, sx1, sy1], fill=(235, 185, 28, 250), width=int(max(2, 2.4 * scale)))

    # Red circle roundels on mid-wing stations
    for side_sign in [-1.0, 1.0]:
        hino_pos = np.array([side_sign * 44.0, 3.0, 2.0])
        h_rot = R_total @ hino_pos
        hx = cx + h_rot[0] * scale
        hy = cy - h_rot[1] * scale
        h_rad = 10.0 * scale

        # Perspective foreshortening during banking
        bank_squash = max(0.2, math.cos(r_rad))
        pitch_squash = max(0.2, math.cos(p_rad))

        h_w = h_rad * (bank_squash if abs(roll_deg) > 0 else 1.0)
        h_h = h_rad * (pitch_squash if abs(pitch_deg) > 0 else 1.0)

        # White border ring + vibrant crimson Hinomaru core
        h_col = (205, 25, 25, 255) if style != "arcade" else (240, 30, 30, 255)
        draw_final.ellipse([hx - h_w - 1.2, hy - h_h - 1.2, hx + h_w + 1.2, hy + h_h + 1.2], fill=(240, 245, 245, 240))
        draw_final.ellipse([hx - h_w, hy - h_h, hx + h_w, hy + h_h], fill=h_col, outline=(140, 16, 16, 255), width=1)

    # -------------------------------------------------------------------------
    # AUTHENTIC SINGLE SAKAE NOSE PROPELLER (3-Blade with Yellow Safety Tips)
    # -------------------------------------------------------------------------
    prop_pos = np.array([0.0, 56.0, 0.5])
    p_rot = R_total @ prop_pos
    px = cx + p_rot[0] * scale
    py = cy - p_rot[1] * scale

    prop_radius = 23.0 * scale
    p_disc_col = config["prop_color"]
    tip_yellow = (255, 215, 25, 255)
    tip_orange = (255, 150, 15, 210)
    blade_dark = (24, 28, 24, 235)
    blade_light = (55, 65, 55, 245)

    disc_overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d_draw = ImageDraw.Draw(disc_overlay)

    # 1. Subtle background spinning disc
    pitch_rad = math.radians(pitch_deg)
    disc_th = max(2.5, 7.0 * scale * abs(math.sin(pitch_rad)) + 2.5)
    d_draw.ellipse(
        [px - prop_radius, py - disc_th, px + prop_radius, py + disc_th],
        fill=(p_disc_col[0], p_disc_col[1], p_disc_col[2], 38)
    )

    # 2. Render 3 propeller blades with yellow safety tips
    for b_i in range(3):
        b_deg = prop_angle + b_i * 120.0
        rad_b = math.radians(b_deg)

        dx = math.cos(rad_b)
        dz = math.sin(rad_b)

        blade_tip_3d = prop_pos + np.array([dx * 22.0, 0.0, dz * 22.0])
        b_rot = R_total @ blade_tip_3d
        bx = cx + b_rot[0] * scale
        by = cy - b_rot[1] * scale

        # Main dark metal blade body
        d_draw.line([px, py, bx, by], fill=blade_dark, width=int(max(2, 2.5 * scale)))
        inner_x = px + (bx - px) * 0.72
        inner_y = py + (by - py) * 0.72
        d_draw.line([px, py, inner_x, inner_y], fill=blade_light, width=int(max(1, 1.5 * scale)))

        # Outer 28% yellow safety tip
        d_draw.line([inner_x, inner_y, bx, by], fill=tip_yellow, width=int(max(2, 2.8 * scale)))
        d_draw.ellipse([bx - 1.8, by - 1.8, bx + 1.8, by + 1.8], fill=tip_orange)

    result_img = Image.alpha_composite(result_img, disc_overlay)
    return result_img

if __name__ == "__main__":
    m = build_zero_mesh()
    img = render_3d_zero_frame(m, roll_deg=0.0, pitch_deg=0.0, style="tactical")
    out_path = Path("scratch/test_zero_tactical.png")
    out_path.parent.mkdir(exist_ok=True)
    img.save(out_path)
    print(f"[A6M Zero] Rendered test frame to {out_path}")

#!/usr/bin/env python3
"""
Sky Ace • Yakovlev Yak-3 3D Cel-Shader & Rasterizer
Features:
- Compact, tapered high-agility wooden wings with Soviet Red Stars
- Red Guard nose cowling and ShVAK hub spinner with 3-blade prop
- VVS Slate-Grey & Light Earth camouflage
"""

import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PALETTE_YAK3 = {
    "outline": (16, 18, 20, 255),
    "light_dir": np.array([-0.3, 0.5, 0.81]),
    "steps": [0.3, 0.7],
    "materials": {
        1: {"shadow": (42, 48, 52), "mid": (68, 76, 82), "high": (102, 114, 122)}, # VVS Slate Grey
        2: {"shadow": (150, 25, 25), "mid": (205, 35, 35), "high": (240, 60, 60)}, # Guard Red Cowl
        3: {"shadow": (160, 20, 20), "mid": (215, 30, 30), "high": (245, 50, 50)}, # Red Star
        4: {"shadow": (28, 48, 64), "mid": (52, 90, 120), "high": (125, 175, 210)}, # Canopy Glass
        5: {"shadow": (160, 25, 25), "mid": (215, 35, 35), "high": (245, 60, 60)}, # Red Spinner
        6: {"shadow": (40, 46, 50), "mid": (65, 74, 80), "high": (98, 110, 118)},  # Tail
    },
    "prop_color": (240, 220, 80, 140),
    "outline_width": 2,
}

def render_3d_yak3_frame(mesh, roll_deg=0.0, pitch_deg=0.0, yaw_deg=0.0, prop_angle=0.0,
                         style="tactical", size=256, scale=1.75):
    config = PALETTE_YAK3
    palette = config["materials"]
    l_dir = config["light_dir"] / np.linalg.norm(config["light_dir"])

    r_rad = math.radians(roll_deg)
    p_rad = math.radians(pitch_deg)
    y_rad = math.radians(yaw_deg)

    R_roll = np.array([
        [math.cos(r_rad), 0.0, math.sin(r_rad)],
        [0.0, 1.0, 0.0],
        [-math.sin(r_rad), 0.0, math.cos(r_rad)]
    ])

    R_pitch = np.array([
        [1.0, 0.0, 0.0],
        [0.0, math.cos(p_rad), -math.sin(p_rad)],
        [0.0, math.sin(p_rad), math.cos(p_rad)]
    ])

    R_yaw = np.array([
        [math.cos(y_rad), math.sin(y_rad), 0.0],
        [-math.sin(y_rad), math.cos(y_rad), 0.0],
        [0.0, 0.0, 1.0]
    ])

    R_total = R_yaw @ R_pitch @ R_roll

    cx, cy = size / 2.0, size / 2.0
    v_screen = []
    v_transformed = []

    for v in mesh.vertices:
        v_rot = R_total @ np.array(v)
        v_transformed.append(v_rot)
        sx = cx + v_rot[0] * scale
        sy = cy - v_rot[1] * scale
        sz = v_rot[2]
        v_screen.append((sx, sy, sz))

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
        intensity = float(np.dot(normal, l_dir))
        mean_z = (v_screen[v0_idx][2] + v_screen[v1_idx][2] + v_screen[v2_idx][2]) / 3.0
        faces_to_render.append((mean_z, face, normal, intensity))

    faces_to_render.sort(key=lambda x: x[0])

    img_arr = np.zeros((size, size, 4), dtype=np.uint8)
    z_buffer = np.full((size, size), -99999.0, dtype=np.float32)

    for mean_z, (v0_idx, v1_idx, v2_idx, mat_id), normal, intensity in faces_to_render:
        mat_entry = palette.get(mat_id, palette[1])
        steps = config["steps"]
        if intensity < steps[0]: col = mat_entry["shadow"]
        elif intensity < steps[1]: col = mat_entry["mid"]
        else: col = mat_entry["high"]

        p0, p1, p2 = v_screen[v0_idx], v_screen[v1_idx], v_screen[v2_idx]
        min_x = max(0, int(math.floor(min(p0[0], p1[0], p2[0]))))
        max_x = min(size - 1, int(math.ceil(max(p0[0], p1[0], p2[0]))))
        min_y = max(0, int(math.floor(min(p0[1], p1[1], p2[1]))))
        max_y = min(size - 1, int(math.ceil(max(p0[1], p1[1], p2[1]))))

        if min_x > max_x or min_y > max_y: continue
        denom = (p1[1] - p2[1]) * (p0[0] - p2[0]) + (p2[0] - p1[0]) * (p0[1] - p2[1])
        if abs(denom) < 1e-6: continue

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
    # VVS SOVIET RED STARS ON BOTH WINGS
    # -------------------------------------------------------------------------
    for side_sign in [-1.0, 1.0]:
        star_pos = R_total @ np.array([side_sign * 34.0, 3.0, 1.0])
        sx, sy = cx + star_pos[0] * scale, cy - star_pos[1] * scale
        r_star = 8.0 * scale
        b_squash = max(0.2, math.cos(r_rad))

        # 5-pointed star coordinates
        pts = []
        for p_i in range(10):
            ang = -math.pi / 2 + p_i * (math.pi / 5)
            r_pt = r_star if (p_i % 2 == 0) else (r_star * 0.45)
            pts.append((sx + r_pt * math.cos(ang) * b_squash, sy + r_pt * math.sin(ang)))
        draw_final.polygon(pts, fill=(215, 30, 30, 255), outline=(245, 245, 250, 230))

    # -------------------------------------------------------------------------
    # KLIMOV M-105 NOSE PROPELLER (Locked to 3D Spinner Tip)
    # -------------------------------------------------------------------------
    prop_pos = np.array([0.0, 58.0, 0.2])
    p_rot = R_total @ prop_pos
    px = cx + p_rot[0] * scale
    py = cy - p_rot[1] * scale
    prop_radius = 20.0 * scale

    disc_th = max(2.5, 6.0 * scale * abs(math.sin(p_rad)) + 2.5)
    draw_final.ellipse([px - prop_radius, py - disc_th, px + prop_radius, py + disc_th],
                       fill=(240, 220, 80, 40))

    for b_i in range(3):
        b_deg = prop_angle + b_i * 120.0
        b_rad = math.radians(b_deg)
        bx_local = prop_radius * math.cos(b_rad)
        bz_local = prop_radius * math.sin(b_rad)
        v_blade = R_total @ np.array([bx_local, 0.0, bz_local])

        tx = px + v_blade[0]
        ty = py - v_blade[1]
        mx = px + v_blade[0] * 0.75
        my = py - v_blade[1] * 0.75

        draw_final.line([(px, py), (mx, my)], fill=(25, 25, 30, 240), width=int(max(2, 1.8 * scale)))
        draw_final.line([(mx, my), (tx, ty)], fill=(245, 215, 30, 240), width=int(max(2, 2.2 * scale)))

    return result_img

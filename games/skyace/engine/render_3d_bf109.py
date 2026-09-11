#!/usr/bin/env python3
"""
Sky Ace • Messerschmitt Bf 109G "Gustav" 3D Cel-Shader & Rasterizer
Features:
- Clipped trapezoid wings with Balkenkreuz crosses
- Yellow nose cowling (RLM 04 Gelb) and black/white spiral spinner
- Hub-mounted Motorkanone and twin cowl machine guns
"""

import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PALETTE_BF109 = {
    "outline": (16, 20, 16, 255),
    "light_dir": np.array([-0.3, 0.5, 0.81]),
    "steps": [0.3, 0.7],
    "materials": {
        1: {"shadow": (36, 44, 40), "mid": (58, 70, 64), "high": (88, 106, 96)},    # RLM 74/75 Grey-Green
        2: {"shadow": (175, 135, 18), "mid": (230, 180, 28), "high": (255, 218, 65)}, # RLM 04 Yellow Nose
        3: {"shadow": (20, 20, 22), "mid": (40, 40, 44), "high": (230, 230, 235)},  # Cross
        4: {"shadow": (28, 48, 64), "mid": (52, 90, 120), "high": (125, 175, 210)},  # Erla Haube Glass
        5: {"shadow": (20, 22, 20), "mid": (35, 38, 35), "high": (60, 68, 60)},     # Spinner
        6: {"shadow": (34, 42, 38), "mid": (54, 66, 60), "high": (82, 98, 90)},     # Tail
    },
    "prop_color": (240, 220, 80, 140),
    "outline_width": 2,
}

def render_3d_bf109_frame(mesh, roll_deg=0.0, pitch_deg=0.0, yaw_deg=0.0, prop_angle=0.0,
                          style="tactical", size=256, scale=1.75):
    config = PALETTE_BF109
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
    # LUFTWAFFE BALKENKREUZ ON BOTH WINGS
    # -------------------------------------------------------------------------
    for side_sign in [-1.0, 1.0]:
        cross_pos = R_total @ np.array([side_sign * 36.0, 2.0, 1.0])
        kx, ky = cx + cross_pos[0] * scale, cy - cross_pos[1] * scale
        k_sz = 8.0 * scale
        b_squash = max(0.2, math.cos(r_rad))
        kw = k_sz * b_squash
        kh = k_sz

        # White outer cross corners
        draw_final.line([(kx - kw, ky), (kx + kw, ky)], fill=(240, 240, 245, 240), width=int(max(2, 2.5 * scale)))
        draw_final.line([(kx, ky - kh), (kx, ky + kh)], fill=(240, 240, 245, 240), width=int(max(2, 2.5 * scale)))
        # Black inner cross
        draw_final.line([(kx - kw*0.8, ky), (kx + kw*0.8, ky)], fill=(20, 24, 20, 240), width=int(max(1, 1.5 * scale)))
        draw_final.line([(kx, ky - kh*0.8), (kx, ky + kh*0.8)], fill=(20, 24, 20, 240), width=int(max(1, 1.5 * scale)))

    # -------------------------------------------------------------------------
    # DAIMLER-BENZ PROPELLER (Locked to 3D Spinner Tip)
    # -------------------------------------------------------------------------
    prop_pos = np.array([0.0, 60.0, 0.0])
    p_rot = R_total @ prop_pos
    px = cx + p_rot[0] * scale
    py = cy - p_rot[1] * scale
    prop_radius = 21.0 * scale

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

        draw_final.line([(px, py), (mx, my)], fill=(20, 24, 20, 240), width=int(max(2, 1.8 * scale)))
        draw_final.line([(mx, my), (tx, ty)], fill=(245, 215, 30, 240), width=int(max(2, 2.2 * scale)))

    return result_img

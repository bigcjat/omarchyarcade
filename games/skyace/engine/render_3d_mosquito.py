#!/usr/bin/env python3
"""
Sky Ace • de Havilland Mosquito FB.VI 3D Cel-Shader & Rasterizer (Canada / RCAF)
Features:
- "The Wooden Wonder" sleek twin-engine balsa/birch composite strike fighter
- Twin Rolls-Royce Merlin nacelles with counter-rotating props locked to 3D spinners
- RCAF roundels with Red Maple Leaf insignia on outer wings
"""

import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PALETTE_MOSQUITO = {
    "outline": (16, 22, 16, 255),
    "light_dir": np.array([-0.3, 0.5, 0.81]),
    "steps": [0.3, 0.7],
    "materials": {
        1: {"shadow": (36, 48, 34), "mid": (58, 76, 54), "high": (88, 114, 82)},    # RCAF Dark Green
        2: {"shadow": (32, 42, 30), "mid": (52, 68, 48), "high": (78, 102, 74)},    # Nacelles
        3: {"shadow": (20, 24, 20), "mid": (36, 42, 36), "high": (64, 76, 64)},    # Spinners
        4: {"shadow": (28, 48, 64), "mid": (52, 90, 120), "high": (125, 175, 210)}, # Greenhouse Canopy
        5: {"shadow": (18, 20, 22), "mid": (32, 36, 40), "high": (64, 72, 80)},     # Hispanos
        6: {"shadow": (34, 44, 32), "mid": (54, 70, 50), "high": (82, 104, 76)},    # Tail
    },
    "prop_color": (240, 220, 80, 140),
    "outline_width": 2,
}

def render_3d_mosquito_frame(mesh, roll_deg=0.0, pitch_deg=0.0, yaw_deg=0.0, prop_angle=0.0,
                             style="tactical", size=256, scale=1.75):
    config = PALETTE_MOSQUITO
    palette = config["materials"]
    l_dir = config["light_dir"] / np.linalg.norm(config["light_dir"])

    r_rad = math.radians(roll_deg)
    p_rad = math.radians(pitch_deg)
    y_rad = math.radians(yaw_deg)

    # Coordinated aviation banking
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
    # RCAF MAPLE LEAF ROUNDELS ON OUTER WINGS
    # -------------------------------------------------------------------------
    for side_sign in [-1.0, 1.0]:
        r_pos = R_total @ np.array([side_sign * 50.0, 4.0, 2.0])
        rx, ry = cx + r_pos[0] * scale, cy - r_pos[1] * scale
        r_rad_px = 8.5 * scale
        b_squash = max(0.2, math.cos(r_rad))
        p_squash = max(0.2, math.cos(p_rad))
        rw, rh = r_rad_px * b_squash, r_rad_px * p_squash

        # Outer Blue ring, White mid ring, Red Maple Leaf core
        draw_final.ellipse([rx - rw, ry - rh, rx + rw, ry + rh], fill=(24, 48, 120, 255))
        draw_final.ellipse([rx - rw*0.65, ry - rh*0.65, rx + rw*0.65, ry + rh*0.65], fill=(245, 245, 250, 255))
        draw_final.polygon([(rx, ry - rh*0.45), (rx + rw*0.35, ry + rh*0.35), (rx - rw*0.35, ry + rh*0.35)],
                           fill=(215, 30, 30, 255))

    # -------------------------------------------------------------------------
    # TWIN ROLLS-ROYCE MERLIN PROPELLERS (Locked to 3D Nacelle Spinners)
    # -------------------------------------------------------------------------
    prop_centers = [
        (-1.0, np.array([-28.0, 54.0, 0.0])), # Left Merlin nacelle
        ( 1.0, np.array([ 28.0, 54.0, 0.0]))  # Right Merlin nacelle
    ]

    for spin_dir, p_pos in prop_centers:
        p_rot = R_total @ p_pos
        px = cx + p_rot[0] * scale
        py = cy - p_rot[1] * scale
        prop_radius = 19.0 * scale

        # Subtle spinning blur disc (locked to spinner)
        disc_th = max(2.5, 5.5 * scale * abs(math.sin(p_rad)) + 2.5)
        draw_final.ellipse([px - prop_radius, py - disc_th, px + prop_radius, py + disc_th],
                           fill=(240, 220, 80, 40))

        # 3 Rotating Propeller Blades with Yellow Safety Tips
        base_angle = prop_angle * spin_dir
        for b_i in range(3):
            b_deg = base_angle + b_i * 120.0
            b_rad = math.radians(b_deg)
            bx_local = prop_radius * math.cos(b_rad)
            bz_local = prop_radius * math.sin(b_rad)
            v_blade = R_total @ np.array([bx_local, 0.0, bz_local])

            tx = px + v_blade[0]
            ty = py - v_blade[1]
            mx = px + v_blade[0] * 0.75
            my = py - v_blade[1] * 0.75

            draw_final.line([(px, py), (mx, my)], fill=(25, 30, 25, 240), width=int(max(2, 1.8 * scale)))
            draw_final.line([(mx, my), (tx, ty)], fill=(250, 210, 30, 240), width=int(max(2, 2.2 * scale)))

    return result_img

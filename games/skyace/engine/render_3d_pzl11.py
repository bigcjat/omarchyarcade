#!/usr/bin/env python3
"""
Sky Ace • PZL P.11c 3D Cel-Shader & Rasterizer (Poland)
Features:
- Polish Khaki / Polish Olive matte camouflage
- High gull-wing ("Polish Wing") with deep shading under the high shoulder
- Polish Air Force Red & White Checkerboard (Szachownica)
- 2-blade wood/metal propeller with yellow safety tips
"""

import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PALETTE_PZL11 = {
    "outline": (20, 22, 16, 255),
    "light_dir": np.array([-0.3, 0.5, 0.81]),
    "steps": [0.3, 0.7],
    "materials": {
        1: {"shadow": (52, 58, 38), "mid": (86, 96, 62), "high": (124, 138, 92)},     # Polish Khaki / Olive
        2: {"shadow": (35, 38, 36), "mid": (58, 62, 58), "high": (92, 98, 92)},       # Engine Cowling Ring
        3: {"shadow": (160, 25, 25), "mid": (210, 38, 38), "high": (245, 245, 250)},  # Checkerboard
        4: {"shadow": (28, 52, 72), "mid": (56, 96, 130), "high": (130, 185, 220)},   # Windscreen Glass
        5: {"shadow": (45, 50, 32), "mid": (75, 82, 54), "high": (110, 120, 80)},     # Struts
    },
    "prop_color": (240, 220, 80, 140),
    "outline_width": 2,
}

def render_3d_pzl11_frame(mesh, roll_deg=0.0, pitch_deg=0.0, yaw_deg=0.0, prop_angle=0.0,
                          style="tactical", size=256, scale=1.75):
    config = PALETTE_PZL11
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

    sorted_faces = []
    for f in mesh.faces:
        v0, v1, v2, mat_id = f
        z_avg = (v_transformed[v0][2] + v_transformed[v1][2] + v_transformed[v2][2]) / 3.0
        sorted_faces.append((z_avg, f))
    sorted_faces.sort(key=lambda x: x[0])

    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    for _, (v0, v1, v2, mat_id) in sorted_faces:
        p0 = (v_screen[v0][0], v_screen[v0][1])
        p1 = (v_screen[v1][0], v_screen[v1][1])
        p2 = (v_screen[v2][0], v_screen[v2][1])

        e1 = np.array(v_transformed[v1]) - np.array(v_transformed[v0])
        e2 = np.array(v_transformed[v2]) - np.array(v_transformed[v0])
        norm = np.cross(e1, e2)
        norm_len = np.linalg.norm(norm)
        if norm_len > 1e-6:
            norm = norm / norm_len
        else:
            norm = np.array([0.0, 0.0, 1.0])

        dot = np.dot(norm, l_dir)
        mat_colors = palette.get(mat_id, palette[1])

        if dot < 0.2:
            fill_col = mat_colors["shadow"]
        elif dot < 0.6:
            fill_col = mat_colors["mid"]
        else:
            fill_col = mat_colors["high"]

        draw.polygon([p0, p1, p2], fill=fill_col + (255,))

    # Draw Polish Air Force Red & White Checkerboards (Szachownica)
    for side in [-52.0, 52.0]:
        c_pos = R_total @ np.array([side, 5.0, 6.0])
        csx = cx + c_pos[0] * scale
        csy = cy - c_pos[1] * scale
        box_w = 6.0 * scale
        # Red & White quadrant checker
        x0, y0 = csx - box_w, csy - box_w * 0.7
        x1, y1 = csx + box_w, csy + box_w * 0.7
        xm, ym = csx, csy
        # Top-left Red, Bottom-right Red, Top-right White, Bottom-left White
        draw.polygon([(x0, y0), (xm, y0), (xm, ym), (x0, ym)], fill=(210, 35, 35, 255))
        draw.polygon([(xm, y0), (x1, y0), (x1, ym), (xm, ym)], fill=(245, 245, 250, 255))
        draw.polygon([(x0, ym), (xm, ym), (xm, y1), (x0, y1)], fill=(245, 245, 250, 255))
        draw.polygon([(xm, ym), (x1, ym), (x1, y1), (xm, y1)], fill=(210, 35, 35, 255))
        draw.rectangle([x0, y0, x1, y1], outline=(20, 20, 20, 255), width=1)

    # 2-Blade Propeller (P.11c had a classic 2-blade prop)
    hub_pos = R_total @ np.array([0.0, 50.0, 0.0])
    hx = cx + hub_pos[0] * scale
    hy = cy - hub_pos[1] * scale
    p_rad_len = 35.0 * scale

    for b in range(2):
        b_angle = math.radians(prop_angle + b * 180.0)
        bx = hx + p_rad_len * math.cos(b_angle)
        by = hy + p_rad_len * math.sin(b_angle) * 0.4
        draw.line([(hx, hy), (bx, by)], fill=(45, 35, 25, 220), width=4)
        tx = hx + (p_rad_len - 5) * math.cos(b_angle)
        ty = hy + (p_rad_len - 5) * math.sin(b_angle) * 0.4
        draw.line([(tx, ty), (bx, by)], fill=(245, 215, 45, 255), width=4)

    return img

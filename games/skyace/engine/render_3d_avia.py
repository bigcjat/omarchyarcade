#!/usr/bin/env python3
"""
Sky Ace • Avia B.534 Biplane 3D Cel-Shader & Rasterizer (Czechoslovakia)
Features:
- Dual-wing biplane rendering with interplane strut shadows
- Czechoslovak Khaki / Olive Drab camouflage
- Czechoslovak Tricolor roundels (Blue wedge forward, White top, Red bottom)
- 2-blade metal propeller with yellow tips
"""

import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PALETTE_AVIA = {
    "outline": (22, 24, 18, 255),
    "light_dir": np.array([-0.3, 0.5, 0.81]),
    "steps": [0.3, 0.7],
    "materials": {
        1: {"shadow": (48, 56, 36), "mid": (82, 94, 60), "high": (120, 136, 88)},     # Czech Khaki / Olive Drab
        2: {"shadow": (25, 45, 95), "mid": (42, 80, 160), "high": (245, 245, 250)},   # Tricolor Roundel
        3: {"shadow": (28, 52, 72), "mid": (56, 96, 130), "high": (130, 185, 220)},   # Canopy Glass
        4: {"shadow": (32, 35, 30), "mid": (52, 56, 48), "high": (82, 88, 76)},       # Spinner
        5: {"shadow": (35, 40, 28), "mid": (62, 70, 48), "high": (95, 105, 75)},      # Struts
    },
    "prop_color": (240, 220, 80, 140),
    "outline_width": 2,
}

def render_3d_avia_frame(mesh, roll_deg=0.0, pitch_deg=0.0, yaw_deg=0.0, prop_angle=0.0,
                         style="tactical", size=256, scale=1.75):
    config = PALETTE_AVIA
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

    # Draw Interplane N-Struts (Connecting upper and lower wings)
    for side in [-52.0, 52.0]:
        p_top = R_total @ np.array([side, 10.0, 7.0])
        p_bot = R_total @ np.array([side, 5.0, -2.0])
        sx0, sy0 = cx + p_top[0] * scale, cy - p_top[1] * scale
        sx1, sy1 = cx + p_bot[0] * scale, cy - p_bot[1] * scale
        draw.line([(sx0, sy0), (sx1, sy1)], fill=(28, 32, 22, 220), width=2)

    # Draw Czechoslovak Tricolor Roundels on upper wing
    for side in [-54.0, 54.0]:
        r_pos = R_total @ np.array([side, 10.0, 7.2])
        rx = cx + r_pos[0] * scale
        ry = cy - r_pos[1] * scale
        rad = 6.0 * scale
        # Top-half White, Bottom-half Red, Left-wedge Blue
        draw.pieslice([rx - rad, ry - rad*0.6, rx + rad, ry + rad*0.6], 180, 360, fill=(245, 245, 250, 255))
        draw.pieslice([rx - rad, ry - rad*0.6, rx + rad, ry + rad*0.6], 0, 180, fill=(210, 35, 35, 255))
        # Blue forward triangle wedge
        draw.polygon([(rx, ry), (rx - rad, ry - rad*0.5), (rx - rad, ry + rad*0.5)], fill=(32, 65, 155, 255))
        draw.ellipse([rx - rad, ry - rad*0.6, rx + rad, ry + rad*0.6], outline=(20, 20, 20, 255), width=1)

    # Propeller Blades
    hub_pos = R_total @ np.array([0.0, 52.0, 0.0])
    hx = cx + hub_pos[0] * scale
    hy = cy - hub_pos[1] * scale
    p_rad_len = 34.0 * scale

    for b in range(2):
        b_angle = math.radians(prop_angle + b * 180.0)
        bx = hx + p_rad_len * math.cos(b_angle)
        by = hy + p_rad_len * math.sin(b_angle) * 0.4
        draw.line([(hx, hy), (bx, by)], fill=(40, 44, 40, 220), width=3)
        tx = hx + (p_rad_len - 4) * math.cos(b_angle)
        ty = hy + (p_rad_len - 4) * math.sin(b_angle) * 0.4
        draw.line([(tx, ty), (bx, by)], fill=(245, 215, 45, 255), width=3)

    return img

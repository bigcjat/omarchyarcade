#!/usr/bin/env python3
"""
Sky Ace • Dewoitine D.520 3D Cel-Shader & Rasterizer (France)
Features:
- French 1940 Camouflage (Gris-Bleu Fonce, Terre d'Ombre brown, Vert Protege)
- Tricolor wing roundels (Blue outer, White middle, Red center)
- Tricolor rudder vertical stripes (Blue, White, Red)
- 3-blade prop with yellow tips
"""

import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PALETTE_D520 = {
    "outline": (18, 20, 24, 255),
    "light_dir": np.array([-0.3, 0.5, 0.81]),
    "steps": [0.3, 0.7],
    "materials": {
        1: {"shadow": (55, 62, 70), "mid": (88, 98, 110), "high": (125, 138, 155)},   # French Gris-Bleu Fonce
        2: {"shadow": (20, 35, 75), "mid": (35, 65, 140), "high": (245, 245, 250)},   # Roundel
        3: {"shadow": (28, 52, 72), "mid": (56, 96, 130), "high": (130, 185, 220)},   # Canopy Glass
        4: {"shadow": (20, 22, 24), "mid": (38, 42, 46), "high": (65, 72, 78)},       # Black Spinner
        5: {"shadow": (160, 25, 25), "mid": (210, 38, 38), "high": (245, 245, 250)},  # Tricolor Rudder
    },
    "prop_color": (240, 220, 80, 140),
    "outline_width": 2,
}

def render_3d_d520_frame(mesh, roll_deg=0.0, pitch_deg=0.0, yaw_deg=0.0, prop_angle=0.0,
                         style="tactical", size=256, scale=1.75):
    config = PALETTE_D520
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

    # Draw French Tricolor Wing Roundels
    for side in [-50.0, 50.0]:
        r_pos = R_total @ np.array([side, 3.0, 1.4])
        rx = cx + r_pos[0] * scale
        ry = cy - r_pos[1] * scale
        rad = 6.5 * scale
        # Blue outer ring
        draw.ellipse([rx - rad, ry - rad*0.6, rx + rad, ry + rad*0.6], fill=(30, 60, 150, 255))
        # White middle ring
        w_rad = rad * 0.65
        draw.ellipse([rx - w_rad, ry - w_rad*0.6, rx + w_rad, ry + w_rad*0.6], fill=(245, 245, 250, 255))
        # Red center disc
        c_rad = rad * 0.35
        draw.ellipse([rx - c_rad, ry - c_rad*0.6, rx + c_rad, ry + c_rad*0.6], fill=(210, 35, 35, 255))

    # Propeller Blades
    hub_pos = R_total @ np.array([0.0, 57.0, 0.0])
    hx = cx + hub_pos[0] * scale
    hy = cy - hub_pos[1] * scale
    p_rad_len = 36.0 * scale

    for b in range(3):
        b_angle = math.radians(prop_angle + b * 120.0)
        bx = hx + p_rad_len * math.cos(b_angle)
        by = hy + p_rad_len * math.sin(b_angle) * 0.4
        draw.line([(hx, hy), (bx, by)], fill=(32, 35, 38, 220), width=3)
        tx = hx + (p_rad_len - 4) * math.cos(b_angle)
        ty = hy + (p_rad_len - 4) * math.sin(b_angle) * 0.4
        draw.line([(tx, ty), (bx, by)], fill=(245, 215, 45, 255), width=3)

    return img

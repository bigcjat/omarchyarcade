#!/usr/bin/env python3
"""
Sky Ace • Macchi C.202 Folgore 3D Cel-Shader & Rasterizer (Italy)
Features:
- Nocciola Chiaro (Light Hazelnut) base with Verde Mimetico smoke rings / mottle
- White fuselage theater band & Savoia tail cross
- 3-blade spinning prop with yellow safety tips
"""

import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PALETTE_FOLGORE = {
    "outline": (24, 20, 16, 255),
    "light_dir": np.array([-0.3, 0.5, 0.81]),
    "steps": [0.3, 0.7],
    "materials": {
        1: {"shadow": (125, 92, 48), "mid": (185, 142, 82), "high": (224, 182, 118)},  # Italian Nocciola Chiaro / Sand
        2: {"shadow": (210, 210, 215), "mid": (245, 245, 250), "high": (255, 255, 255)}, # White Fuselage Band
        3: {"shadow": (20, 20, 22), "mid": (42, 42, 48), "high": (245, 245, 250)},    # Fasces Insignia
        4: {"shadow": (28, 52, 72), "mid": (56, 96, 130), "high": (130, 185, 220)},   # Canopy Glass
        5: {"shadow": (210, 210, 215), "mid": (245, 245, 250), "high": (255, 255, 255)}, # White Spinner
        6: {"shadow": (200, 200, 205), "mid": (240, 240, 245), "high": (255, 255, 255)}, # Savoia Cross
    },
    "prop_color": (240, 220, 80, 140),
    "outline_width": 2,
}

def render_3d_folgore_frame(mesh, roll_deg=0.0, pitch_deg=0.0, yaw_deg=0.0, prop_angle=0.0,
                            style="tactical", size=256, scale=1.75):
    config = PALETTE_FOLGORE
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

    # Face depth sorting
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

    # Draw Olive Green Smoke Rings on wings
    ring_offsets = [(-45.0, 2.0), (45.0, 2.0), (-25.0, 4.0), (25.0, 4.0), (-65.0, 0.0), (65.0, 0.0)]
    for rx, ry in ring_offsets:
        rw_pos = R_total @ np.array([rx, ry, 1.0])
        rsx = cx + rw_pos[0] * scale
        rsy = cy - rw_pos[1] * scale
        rad = 5.0 * scale
        draw.ellipse([rsx - rad, rsy - rad*0.6, rsx + rad, rsy + rad*0.6], outline=(48, 62, 36, 190), width=2)

    # Propeller Blades (3-blade synchronized)
    hub_pos = R_total @ np.array([0.0, 58.0, 0.2])
    hx = cx + hub_pos[0] * scale
    hy = cy - hub_pos[1] * scale
    p_rad_len = 36.0 * scale

    for b in range(3):
        b_angle = math.radians(prop_angle + b * 120.0)
        bx = hx + p_rad_len * math.cos(b_angle)
        by = hy + p_rad_len * math.sin(b_angle) * 0.4
        draw.line([(hx, hy), (bx, by)], fill=(40, 44, 42, 220), width=3)
        tx = hx + (p_rad_len - 4) * math.cos(b_angle)
        ty = hy + (p_rad_len - 4) * math.sin(b_angle) * 0.4
        draw.line([(tx, ty), (bx, by)], fill=(245, 215, 45, 255), width=3)

    return img

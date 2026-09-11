#!/usr/bin/env python3
"""
Sky Ace • 3D Cel-Shader & Sprite Rasterizer
Renders the 3D P-38 Lightning mesh into high-detail pixel art sprites.
"""

import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
from p38_3d_engine import build_p38_mesh

SCRATCH_DIR = Path("scratch")
SCRATCH_DIR.mkdir(parents=True, exist_ok=True)

# =============================================================================
# PALETTES FOR 3 AESTHETIC DEMOS
# =============================================================================
PALETTES = {
    # Demo 1: Capcom CPS-1 Vibrant Arcade (Bold 16-bit)
    "arcade": {
        "outline": (18, 28, 18, 255),
        "light_dir": np.array([-0.35, 0.45, 0.82]),
        "steps": [0.25, 0.65],  # Shadow, Mid, Highlight thresholds
        "materials": {
            1: {"shadow": (45, 68, 42),   "mid": (72, 108, 68),  "high": (118, 162, 110)},  # Body
            2: {"shadow": (40, 62, 38),   "mid": (68, 102, 64),  "high": (112, 156, 105)},  # Wing
            3: {"shadow": (185, 140, 20), "mid": (245, 195, 30), "high": (255, 230, 95)},   # Yellow tip
            4: {"shadow": (35, 75, 115),  "mid": (65, 145, 205), "high": (165, 230, 255)},  # Canopy
            5: {"shadow": (20, 35, 20),   "mid": (35, 55, 32),   "high": (55, 85, 50)},     # Canopy frame
            6: {"shadow": (38, 55, 36),   "mid": (62, 90, 58),   "high": (95, 135, 88)},    # Engine
            7: {"shadow": (42, 65, 40),   "mid": (70, 105, 66),  "high": (115, 158, 108)},  # Tail
            8: {"shadow": (22, 24, 25),   "mid": (42, 45, 48),   "high": (85, 92, 98)},     # Guns
            9: {"shadow": (65, 35, 20),   "mid": (120, 65, 35),  "high": (180, 110, 60)},   # Exhaust
            10: {"shadow": (25, 35, 25),  "mid": (45, 65, 45),   "high": (85, 115, 85)},    # Spinner
        },
        "prop_color": (95, 230, 245, 160),
        "prop_core": (245, 255, 255, 220),
        "outline_width": 2,
    },
    
    # Demo 2: Artisan Cel-Shaded (Dead Cells / Neo Geo quality)
    "artisan": {
        "outline": (14, 20, 16, 255),
        "light_dir": np.array([-0.4, 0.4, 0.82]),
        "steps": [0.15, 0.45, 0.75],  # 4-tone ramp
        "materials": {
            1: {"tones": [(36, 52, 34), (54, 78, 50), (82, 118, 76), (125, 168, 116)]},
            2: {"tones": [(32, 48, 30), (50, 74, 46), (78, 112, 72), (120, 162, 112)]},
            3: {"tones": [(160, 115, 15), (210, 160, 25), (248, 205, 38), (255, 238, 110)]},
            4: {"tones": [(24, 55, 85), (48, 108, 155), (92, 175, 230), (210, 245, 255)]},
            5: {"tones": [(18, 26, 18), (28, 42, 28), (45, 68, 44), (75, 105, 72)]},
            6: {"tones": [(30, 44, 28), (48, 70, 44), (72, 102, 66), (110, 150, 102)]},
            7: {"tones": [(34, 50, 32), (52, 76, 48), (80, 115, 74), (122, 165, 114)]},
            8: {"tones": [(18, 20, 22), (32, 35, 38), (58, 64, 70), (105, 115, 125)]},
            9: {"tones": [(55, 28, 16), (95, 50, 28), (145, 80, 45), (205, 130, 75)]},
            10: {"tones": [(20, 30, 20), (38, 54, 38), (62, 88, 62), (98, 132, 98)]},
        },
        "prop_color": (140, 240, 255, 180),
        "prop_core": (255, 255, 255, 240),
        "outline_width": 2,
    },

    # Demo 3: Tactical Miniature (Authentic Scale Military Camo)
    "tactical": {
        "outline": (20, 22, 20, 255),
        "light_dir": np.array([-0.3, 0.5, 0.81]),
        "steps": [0.3, 0.7],
        "materials": {
            1: {"shadow": (48, 56, 44),   "mid": (76, 88, 70),   "high": (108, 122, 100)},
            2: {"shadow": (44, 52, 40),   "mid": (72, 84, 66),   "high": (104, 118, 96)},
            3: {"shadow": (165, 130, 25), "mid": (215, 175, 35), "high": (240, 205, 75)},
            4: {"shadow": (30, 50, 68),   "mid": (55, 95, 125),  "high": (130, 180, 215)},
            5: {"shadow": (25, 30, 25),   "mid": (40, 48, 40),   "high": (65, 78, 65)},
            6: {"shadow": (42, 50, 38),   "mid": (68, 80, 62),   "high": (96, 112, 88)},
            7: {"shadow": (46, 54, 42),   "mid": (74, 86, 68),   "high": (106, 120, 98)},
            8: {"shadow": (20, 22, 24),   "mid": (36, 40, 44),   "high": (70, 78, 86)},
            9: {"shadow": (60, 35, 22),   "mid": (105, 62, 38),  "high": (155, 98, 58)},
            10: {"shadow": (28, 34, 28),  "mid": (48, 58, 48),   "high": (75, 90, 75)},
        },
        "prop_color": (240, 220, 80, 140), # Authentic yellow/amber propeller blur
        "prop_core": (255, 245, 180, 200),
        "outline_width": 2,
    }
}

# =============================================================================
# 3D RENDERER WITH Z-BUFFER AND CEL-SHADING
# =============================================================================
def render_3d_frame(mesh, roll_deg=0.0, pitch_deg=0.0, yaw_deg=0.0, prop_angle=0.0, 
                    style="arcade", size=256, scale=1.75):
    """
    Renders the 3D mesh into a transparent RGBA image with cel-shading and crisp inking.
    """
    config = PALETTES[style]
    palette = config["materials"]
    l_dir = config["light_dir"] / np.linalg.norm(config["light_dir"])

    # Rotation matrices
    # 1. Roll (Bank around Y axis: left roll dips left wing, lifts right wing, leans canopy left)
    r_rad = math.radians(roll_deg)
    cr, sr = math.cos(r_rad), math.sin(r_rad)
    R_roll = np.array([
        [ cr, 0.0,  sr],
        [0.0, 1.0, 0.0],
        [-sr, 0.0,  cr]
    ])

    # 2. Pitch (Loop around X axis)
    p_rad = math.radians(pitch_deg)
    cp, sp = math.cos(p_rad), math.sin(p_rad)
    R_pitch = np.array([
        [1.0,  0.0,  0.0],
        [0.0,   cp,  -sp],
        [0.0,   sp,   cp]
    ])

    # 3. Yaw (Turn around Z axis: left turn turns nose left, tail right)
    y_rad = math.radians(yaw_deg)
    cy, sy = math.cos(y_rad), math.sin(y_rad)
    R_yaw = np.array([
        [ cy,  sy, 0.0],
        [-sy,  cy, 0.0],
        [0.0, 0.0, 1.0]
    ])

    R_total = R_yaw @ R_pitch @ R_roll

    # Transform all vertices
    V_raw = np.array(mesh.vertices)
    V_rot = (R_total @ V_raw.T).T

    # Screen projection
    cx, cy = size / 2.0, size / 2.0
    # Top-down view: X -> Screen X, Y -> Screen -Y (Forward is UP), Z -> Depth
    V_screen = np.zeros((len(V_rot), 3))
    V_screen[:, 0] = cx + V_rot[:, 0] * scale
    V_screen[:, 1] = cy - V_rot[:, 1] * scale
    V_screen[:, 2] = V_rot[:, 2] # Depth

    # Buffers
    img_arr = np.zeros((size, size, 4), dtype=np.uint8)
    z_buffer = np.full((size, size), -1e9, dtype=np.float32)
    id_buffer = np.zeros((size, size), dtype=np.int32)

    # Sort faces from back to front (Painter's algorithm fallback + Z-buffer)
    face_depths = []
    for f_idx, (v0, v1, v2, mat_id) in enumerate(mesh.faces):
        avg_z = (V_screen[v0, 2] + V_screen[v1, 2] + V_screen[v2, 2]) / 3.0
        face_depths.append((avg_z, f_idx))
    face_depths.sort(key=lambda x: x[0])

    # Rasterize triangles
    for _, f_idx in face_depths:
        v0_idx, v1_idx, v2_idx, mat_id = mesh.faces[f_idx]
        p0 = V_screen[v0_idx]
        p1 = V_screen[v1_idx]
        p2 = V_screen[v2_idx]

        # Normal vector in 3D world space
        e1 = V_rot[v1_idx] - V_rot[v0_idx]
        e2 = V_rot[v2_idx] - V_rot[v0_idx]
        norm = np.cross(e1, e2)
        norm_len = np.linalg.norm(norm)
        if norm_len < 1e-6:
            continue
        N = norm / norm_len

        # Backface culling: if normal points away from top-down camera (Z < 0)
        # Note: double-sided for thin tail fins, but for bodies, cull backfaces
        if N[2] <= -0.1 and mat_id not in [7]:
            continue

        # Lighting intensity
        diffuse = float(np.dot(N, l_dir))

        # Color lookup based on cel-shading style
        mat_cfg = palette.get(mat_id, palette[1])
        if "tones" in mat_cfg:
            # 4-tone ramp
            steps = config["steps"]
            if diffuse < steps[0]:
                col = mat_cfg["tones"][0]
            elif diffuse < steps[1]:
                col = mat_cfg["tones"][1]
            elif diffuse < steps[2]:
                col = mat_cfg["tones"][2]
            else:
                col = mat_cfg["tones"][3]
        else:
            # 3-tone ramp
            steps = config["steps"]
            if diffuse < steps[0]:
                col = mat_cfg["shadow"]
            elif diffuse < steps[1]:
                col = mat_cfg["mid"]
            else:
                col = mat_cfg["high"]

        # Specular glint on canopy
        if mat_id == 4:
            view_dir = np.array([0.0, 0.0, 1.0])
            half_vec = (l_dir + view_dir)
            half_vec /= np.linalg.norm(half_vec)
            spec = max(0.0, float(np.dot(N, half_vec))) ** 16
            if spec > 0.7:
                col = (255, 255, 255)

        # Bounding box of triangle on screen
        min_x = max(0, int(math.floor(min(p0[0], p1[0], p2[0]))))
        max_x = min(size - 1, int(math.ceil(max(p0[0], p1[0], p2[0]))))
        min_y = max(0, int(math.floor(min(p0[1], p1[1], p2[1]))))
        max_y = min(size - 1, int(math.ceil(max(p0[1], p1[1], p2[1]))))

        if min_x > max_x or min_y > max_y:
            continue

        # Edge functions / Barycentric setup
        x0, y0, z0 = p0
        x1, y1, z1 = p1
        x2, y2, z2 = p2

        denom = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if abs(denom) < 1e-6:
            continue
        inv_denom = 1.0 / denom

        # Vectorized block rasterization
        xs, ys = np.meshgrid(np.arange(min_x, max_x + 1), np.arange(min_y, max_y + 1))
        w0 = ((y1 - y2) * (xs - x2) + (x2 - x1) * (ys - y2)) * inv_denom
        w1 = ((y2 - y0) * (xs - x2) + (x0 - x2) * (ys - y2)) * inv_denom
        w2 = 1.0 - w0 - w1

        inside = (w0 >= 0.0) & (w1 >= 0.0) & (w2 >= 0.0)
        if not np.any(inside):
            continue

        z_interp = w0 * z0 + w1 * z1 + w2 * z2
        
        # Sub-pixel mask & z-buffer update
        sub_z = z_buffer[min_y:max_y+1, min_x:max_x+1]
        z_pass = inside & (z_interp > sub_z)

        if np.any(z_pass):
            sub_z[z_pass] = z_interp[z_pass]
            sub_img = img_arr[min_y:max_y+1, min_x:max_x+1]
            sub_img[z_pass, :3] = col
            sub_img[z_pass, 3] = 255
            id_buffer[min_y:max_y+1, min_x:max_x+1][z_pass] = mat_id

    # Base image from buffer
    base_img = Image.fromarray(img_arr, "RGBA")

    # -------------------------------------------------------------------------
    # CRISP SILHOUETTE & PANEL INKING PASS
    # -------------------------------------------------------------------------
    alpha = img_arr[:, :, 3]
    solid_mask = (alpha > 0).astype(np.uint8) * 255
    mask_img = Image.fromarray(solid_mask, "L")
    
    # Outer edge detection
    edges = mask_img.filter(ImageFilter.FIND_EDGES)
    edge_arr = np.array(edges)
    
    # Draw dark inked outline
    outline_col = config["outline"]
    out_w = config.get("outline_width", 2)
    
    # Expand silhouette outline by 1 pixel (filter size must be odd)
    dilated_edges = edges.filter(ImageFilter.MaxFilter(3))
    dil_arr = np.array(dilated_edges)

    draw = ImageDraw.Draw(base_img)
    # Apply outline where edge is detected outside or right on the border
    out_mask = (dil_arr > 30) & (alpha == 0)
    img_arr[out_mask] = outline_col

    result_img = Image.fromarray(img_arr, "RGBA")
    draw_final = ImageDraw.Draw(result_img)

    # -------------------------------------------------------------------------
    # AUTHENTIC 3-PHASE STROBING AIRPLANE PROPELLERS
    # Counter-rotating 3-blade props in the vertical X-Z plane with yellow safety tips
    # and motion streaks that pulse as they cycle through rotation angles.
    # -------------------------------------------------------------------------
    prop_centers = [
        np.array([-25.0, 48.0, 0.5]),
        np.array([ 25.0, 48.0, 0.5])
    ]

    p_disc_col = config["prop_color"]
    tip_yellow = (255, 215, 25, 255)
    tip_orange = (255, 150, 15, 210)
    blade_dark = (24, 28, 24, 235)
    blade_light = (55, 65, 55, 245)

    for side_idx, p_pos in enumerate(prop_centers):
        # Propeller hub center in screen space
        p_rot = R_total @ p_pos
        px = cx + p_rot[0] * scale
        py = cy - p_rot[1] * scale

        prop_radius = 20.0 * scale
        spin_dir = 1.0 if side_idx == 0 else -1.0
        base_angle = prop_angle * spin_dir

        disc_overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d_draw = ImageDraw.Draw(disc_overlay)

        # 1. Subtle background spinning air disc
        pitch_rad = math.radians(pitch_deg)
        disc_th = max(2.5, 7.0 * scale * abs(math.sin(pitch_rad)) + 2.5)
        d_draw.ellipse(
            [px - prop_radius, py - disc_th, px + prop_radius, py + disc_th],
            fill=(p_disc_col[0], p_disc_col[1], p_disc_col[2], 35)
        )

        # 2. Render the 3 propeller blades with yellow safety tips
        for b_i in range(3):
            b_deg = base_angle + b_i * 120.0
            b_rad = math.radians(b_deg)

            # Blade vector in local plane coordinates (X: across wing, Z: up/down)
            bx_local = prop_radius * math.cos(b_rad)
            bz_local = prop_radius * math.sin(b_rad)

            # Transform through aircraft's 3D rotation matrix
            v_tip_local = np.array([bx_local, 0.0, bz_local])
            v_tip_rot = R_total @ v_tip_local

            # Tip position on screen
            tx = px + v_tip_rot[0]
            ty = py - v_tip_rot[1]

            # 70% point along blade (where yellow tip starts)
            v_mid_rot = v_tip_rot * 0.70
            mx = px + v_mid_rot[0]
            my = py - v_mid_rot[1]

            # 40% point along blade (inner blade)
            v_in_rot = v_tip_rot * 0.35
            ix = px + v_in_rot[0]
            iy = py - v_in_rot[1]

            # Draw dark metallic blade body
            d_draw.line([(px, py), (mx, my)], fill=blade_dark, width=3)
            d_draw.line([(px, py), (mx, my)], fill=blade_light, width=1)

            # Draw bright yellow safety tip (outer 30%)
            d_draw.line([(mx, my), (tx, ty)], fill=tip_orange, width=4)
            d_draw.line([(mx, my), (tx, ty)], fill=tip_yellow, width=2)

            # Draw rotational motion-blur streak behind the yellow tip
            streak_steps = 3
            for s_idx in range(1, streak_steps + 1):
                s_ang = math.radians(b_deg - spin_dir * (s_idx * 14.0))
                sx_loc = prop_radius * math.cos(s_ang)
                sz_loc = prop_radius * math.sin(s_ang)
                v_s_rot = R_total @ np.array([sx_loc, 0.0, sz_loc])
                stx = px + v_s_rot[0]
                sty = py - v_s_rot[1]
                smx = px + v_s_rot[0] * 0.72
                smy = py - v_s_rot[1] * 0.72
                alpha_streak = int(140 / (s_idx + 1))
                d_draw.line([(smx, smy), (stx, sty)], fill=(255, 210, 30, alpha_streak), width=2)

        # 3. Streamlined Spinner Hub Cap with specular shine
        hub_r = 3.8 * scale
        d_draw.ellipse([px - hub_r, py - hub_r, px + hub_r, py + hub_r], fill=(32, 44, 32, 255), outline=(12, 16, 12, 255))
        d_draw.point((int(px - 1), int(py - 1)), fill=(255, 255, 255, 240))

        # Composite propeller overlay
        result_img = Image.alpha_composite(result_img, disc_overlay)

    return result_img

print("✓ 3D Cel-Shader and Sprite Rasterizer compiled successfully.")

if __name__ == "__main__":
    mesh = build_p38_mesh()
    for style in ["arcade", "artisan", "tactical"]:
        img = render_3d_frame(mesh, roll_deg=0.0, pitch_deg=0.0, prop_angle=30.0, style=style)
        out_file = SCRATCH_DIR / f"test_3d_{style}.png"
        img.save(out_file)
        print(f"✓ Rendered test frame for style '{style}' -> {out_file}")

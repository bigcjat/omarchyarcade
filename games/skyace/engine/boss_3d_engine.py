#!/usr/bin/env python3
"""
games/skyace/engine/boss_3d_engine.py
Real-time 3D mathematical mesh and cel-shading rasterizer for the
Colossal 1980s Super-Heavy Flying Fortress Boss (inspired by Antonov An-225 / An-124 / Ace Combat Leviathans).
Uses true Z-buffered polygon rasterization and Sobel silhouette edge-inking for studio-grade cel-shading.
"""

import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

class BossMesh3D:
    def __init__(self):
        self.vertices = []  # List of (x, y, z)
        self.faces = []     # List of (v0, v1, v2, mat_id)

    def add_vertex(self, x, y, z):
        self.vertices.append((float(x), float(y), float(z)))
        return len(self.vertices) - 1

    def add_quad(self, v0, v1, v2, v3, mat_id):
        self.faces.append((v0, v1, v2, mat_id))
        self.faces.append((v0, v2, v3, mat_id))

    def add_tri(self, v0, v1, v2, mat_id):
        self.faces.append((v0, v1, v2, mat_id))

# Materials
MAT_FUSELAGE = 1     # Slate Blue-Grey Tactical Camo
MAT_FUSELAGE_DARK = 2# Underside shadow grey
MAT_RADOME = 3       # Matte Black Nose Radome
MAT_COCKPIT = 4      # Multi-pane Flight Deck Glass
MAT_WING = 5         # Upper Wing Surface
MAT_WING_UNDERSIDE = 6# Lower Wing Surface
MAT_WING_TRIM = 7    # De-icing boot / Leading edge
MAT_ENGINE_COWL = 8  # Turbofan Outer Cowling
MAT_ENGINE_FAN = 9   # Dark Intake Fan Blade Disk
MAT_ENGINE_EXHAUST = 10# Glowing Jet Exhaust Core
MAT_TAIL = 11        # Vertical Fins & Horizontal Stabilizer
MAT_TURRET = 12      # Point Defense Turret Gunmetal
MAT_DAMAGE_FIRE = 13 # Flaming damaged engine

BOSS_PALETTE = {
    MAT_FUSELAGE:       {"base": (75, 90, 108),   "ink": (35, 42, 52),  "spec": 0.25},
    MAT_FUSELAGE_DARK:  {"base": (52, 64, 78),    "ink": (28, 34, 42),  "spec": 0.15},
    MAT_RADOME:         {"base": (36, 42, 50),    "ink": (18, 22, 28),  "spec": 0.40},
    MAT_COCKPIT:        {"base": (130, 210, 245), "ink": (25, 75, 110), "spec": 0.95},
    MAT_WING:           {"base": (80, 96, 115),   "ink": (38, 48, 60),  "spec": 0.25},
    MAT_WING_UNDERSIDE: {"base": (56, 70, 85),    "ink": (30, 38, 48),  "spec": 0.15},
    MAT_WING_TRIM:      {"base": (45, 52, 62),    "ink": (24, 30, 38),  "spec": 0.35},
    MAT_ENGINE_COWL:    {"base": (72, 88, 105),   "ink": (36, 44, 55),  "spec": 0.30},
    MAT_ENGINE_FAN:     {"base": (24, 26, 32),    "ink": (12, 14, 18),  "spec": 0.10},
    MAT_ENGINE_EXHAUST: {"base": (255, 170, 45),  "ink": (255, 90, 20), "spec": 1.00},
    MAT_TAIL:           {"base": (76, 92, 110),   "ink": (36, 46, 56),  "spec": 0.25},
    MAT_TURRET:         {"base": (42, 48, 56),    "ink": (20, 24, 30),  "spec": 0.50},
    MAT_DAMAGE_FIRE:    {"base": (255, 95, 20),   "ink": (220, 35, 10), "spec": 1.00},
}

def build_superboss_mesh(damage_stage=0):
    mesh = BossMesh3D()

    # -------------------------------------------------------------------------
    # 1. BULBOUS STRATEGIC FUSELAGE (Forward is +Y, Up is +Z, Right is +X)
    # -------------------------------------------------------------------------
    sections = [
        (92.0, 2.0, 2.0, 1.0),    # Radome tip
        (86.0, 7.0, 6.5, 1.5),    # Radome base
        (74.0, 13.0, 12.0, 2.5),  # Forward nose
        (56.0, 17.0, 15.0, 4.0),  # Cockpit windshield
        (35.0, 19.0, 16.0, 5.0),  # Upper flight deck
        (10.0, 19.5, 16.0, 5.0),  # Wing box center
        (-22.0, 19.0, 15.5, 5.0), # Mid fuselage
        (-52.0, 17.0, 14.5, 5.5), # Aft cargo bay
        (-78.0, 11.5, 11.0, 6.5), # Aft ramp upsweep
        (-98.0, 4.0, 4.5, 7.5),   # Tail cone
    ]

    rings = []
    n_radial = 14
    for s_idx, (y, rx, rz, zc) in enumerate(sections):
        ring = []
        for i in range(n_radial):
            theta = 2.0 * math.pi * i / n_radial
            vx = rx * math.cos(theta)
            vz = zc + rz * math.sin(theta)
            ring.append(mesh.add_vertex(vx, y, vz))
        rings.append(ring)

    for s in range(len(sections) - 1):
        r0 = rings[s]
        r1 = rings[s + 1]
        for i in range(n_radial):
            i_next = (i + 1) % n_radial
            mat = MAT_FUSELAGE
            if s == 0:
                mat = MAT_RADOME
            elif s in [2, 3] and i in [2, 3, 4, 5]: # Cockpit flight deck
                mat = MAT_COCKPIT
            elif i in [0, 1, 7, 8, 9]: # Lower shaded belly
                mat = MAT_FUSELAGE_DARK
            mesh.add_quad(r0[i], r1[i], r1[i_next], r0[i_next], mat)

    # -------------------------------------------------------------------------
    # 2. HIGH-MOUNTED ANHEDRAL SHOULDER WINGS (Span: X = -145 to +145)
    # -------------------------------------------------------------------------
    wing_stations = [
        (17.0,  28.0, 13.5,  -36.0, 12.0),  # Root
        (52.0,  22.0, 12.0,  -33.0, 11.0),  # Inner engine
        (88.0,  13.0,  9.5,  -28.0,  8.5),  # Mid engine
        (124.0,  3.0,  6.5,  -24.0,  6.0),  # Outer engine
        (146.0, -8.0,  3.8,  -22.0,  3.5),  # Wingtip
    ]

    for side in [-1, 1]:
        w_quads = []
        for sx, ly, lz, ty, tz in wing_stations:
            x = sx * side
            v_lu = mesh.add_vertex(x, ly, lz + 1.2)
            v_tu = mesh.add_vertex(x, ty, tz + 0.6)
            v_tl = mesh.add_vertex(x, ty, tz - 0.6)
            v_ll = mesh.add_vertex(x, ly, lz - 1.2)
            w_quads.append((v_lu, v_tu, v_tl, v_ll))

        for s in range(len(wing_stations) - 1):
            w0 = w_quads[s]
            w1 = w_quads[s + 1]
            mat_up = MAT_WING
            mat_dn = MAT_WING_UNDERSIDE
            if s == len(wing_stations) - 2:
                mat_up = MAT_WING_TRIM

            if side == 1:
                mesh.add_quad(w0[0], w1[0], w1[1], w0[1], mat_up)
                mesh.add_quad(w0[1], w1[1], w1[2], w0[2], MAT_WING_TRIM)
                mesh.add_quad(w1[2], w1[3], w0[3], w0[2], mat_dn)
                mesh.add_quad(w0[3], w1[3], w1[0], w0[0], MAT_WING_TRIM)
            else:
                mesh.add_quad(w1[0], w0[0], w0[1], w1[1], mat_up)
                mesh.add_quad(w1[1], w0[1], w0[2], w1[2], MAT_WING_TRIM)
                mesh.add_quad(w0[2], w0[3], w1[3], w1[2], mat_dn)
                mesh.add_quad(w1[3], w0[3], w0[0], w1[0], MAT_WING_TRIM)

    # -------------------------------------------------------------------------
    # 3. 6 COLOSSAL TURBOFAN JET ENGINES (3 Under Each Wing)
    # -------------------------------------------------------------------------
    engine_positions = [
        (50.0,  20.0,  5.8),   # Inner
        (86.0,  11.5,  3.5),   # Middle
        (120.0,  2.0,  1.0),   # Outer
    ]

    for eng_idx, (ex_abs, ey, ez) in enumerate(engine_positions):
        for side in [-1, 1]:
            ex = ex_abs * side
            is_damaged = (damage_stage >= 1 and eng_idx == 2 and side == 1) or \
                         (damage_stage >= 2 and eng_idx == 1 and side == -1)

            r_cowl = 6.2
            n_eng = 10

            y_front = ey + 11.0
            y_mid   = ey - 2.0
            y_back  = ey - 18.0

            r_f = []; r_m = []; r_b = []
            for i in range(n_eng):
                theta = 2.0 * math.pi * i / n_eng
                vx = ex + r_cowl * math.cos(theta)
                vz = ez + r_cowl * math.sin(theta)
                r_f.append(mesh.add_vertex(vx, y_front, vz))
                r_m.append(mesh.add_vertex(vx * 1.02, y_mid, vz * 1.02))
                r_b.append(mesh.add_vertex(vx * 0.88, y_back, vz * 0.88))

            cowl_mat = MAT_DAMAGE_FIRE if is_damaged else MAT_ENGINE_COWL
            for i in range(n_eng):
                i_next = (i + 1) % n_eng
                if side == 1:
                    mesh.add_quad(r_f[i], r_m[i], r_m[i_next], r_f[i_next], cowl_mat)
                    mesh.add_quad(r_m[i], r_b[i], r_b[i_next], r_m[i_next], cowl_mat)
                else:
                    mesh.add_quad(r_m[i], r_f[i], r_f[i_next], r_m[i_next], cowl_mat)
                    mesh.add_quad(r_b[i], r_m[i], r_m[i_next], r_b[i_next], cowl_mat)

            # Front fan face
            v_fan = mesh.add_vertex(ex, y_front - 2.0, ez)
            for i in range(n_eng):
                i_next = (i + 1) % n_eng
                mesh.add_tri(r_f[i], v_fan, r_f[i_next], MAT_ENGINE_FAN)

            # Rear exhaust nozzle
            v_ex = mesh.add_vertex(ex, y_back - 4.0, ez)
            ex_mat = MAT_DAMAGE_FIRE if is_damaged else MAT_ENGINE_EXHAUST
            for i in range(n_eng):
                i_next = (i + 1) % n_eng
                mesh.add_tri(r_b[i], r_b[i_next], v_ex, ex_mat)

    # -------------------------------------------------------------------------
    # 4. H-TAIL TWIN-FIN EMPENNAGE
    # -------------------------------------------------------------------------
    h_w = 58.0
    h_y0 = -76.0
    h_y1 = -94.0
    h_z  = 14.0
    h_l_le = mesh.add_vertex(-h_w, h_y0, h_z)
    h_r_le = mesh.add_vertex( h_w, h_y0, h_z)
    h_r_te = mesh.add_vertex( h_w, h_y1, h_z)
    h_l_te = mesh.add_vertex(-h_w, h_y1, h_z)
    mesh.add_quad(h_l_le, h_r_le, h_r_te, h_l_te, MAT_TAIL)
    mesh.add_quad(h_l_te, h_r_te, h_r_le, h_l_le, MAT_TAIL)

    for side in [-1, 1]:
        tx = side * h_w
        v_bf = mesh.add_vertex(tx, h_y0 + 2.0, h_z - 4.0)
        v_br = mesh.add_vertex(tx, h_y1, h_z - 4.0)
        v_tr = mesh.add_vertex(tx, h_y1 - 2.0, h_z + 26.0)
        v_tf = mesh.add_vertex(tx, h_y0 + 6.0, h_z + 26.0)
        mesh.add_quad(v_bf, v_br, v_tr, v_tf, MAT_TAIL)
        mesh.add_quad(v_tf, v_tr, v_br, v_bf, MAT_TAIL)

    # -------------------------------------------------------------------------
    # 5. DEFENSE TURRETS
    # -------------------------------------------------------------------------
    dt_cx, dt_cy, dt_cz = 0.0, 32.0, 20.0
    v_dt_base = mesh.add_vertex(dt_cx, dt_cy, dt_cz)
    v_dt_f = mesh.add_vertex(dt_cx, dt_cy + 8.0, dt_cz + 1.0)
    v_dt_l = mesh.add_vertex(dt_cx - 4.0, dt_cy, dt_cz + 3.0)
    v_dt_r = mesh.add_vertex(dt_cx + 4.0, dt_cy, dt_cz + 3.0)
    v_dt_b = mesh.add_vertex(dt_cx, dt_cy - 6.0, dt_cz + 2.0)
    mesh.add_tri(v_dt_base, v_dt_f, v_dt_l, MAT_TURRET)
    mesh.add_tri(v_dt_base, v_dt_r, v_dt_f, MAT_TURRET)
    mesh.add_tri(v_dt_base, v_dt_b, v_dt_r, MAT_TURRET)
    mesh.add_tri(v_dt_base, v_dt_l, v_dt_b, MAT_TURRET)

    return mesh

def render_3d_boss_frame(mesh, roll_deg=0.0, pitch_deg=0.0, yaw_deg=0.0, 
                         damage_stage=0, size=384, scale=1.28):
    """
    Renders the 3D Super-Heavy Boss mesh using high-precision Z-buffered rasterization
    and Sobel contour edge-inking (eliminates internal wireframe lines!).
    """
    palette = BOSS_PALETTE
    l_dir = np.array([-0.45, -0.60, 0.70])
    l_dir = l_dir / np.linalg.norm(l_dir)

    # 1. Roll
    r_rad = math.radians(roll_deg)
    cr, sr = math.cos(r_rad), math.sin(r_rad)
    R_roll = np.array([
        [ cr, 0.0,  sr],
        [0.0, 1.0, 0.0],
        [-sr, 0.0,  cr]
    ])

    # 2. Pitch
    p_rad = math.radians(pitch_deg)
    cp, sp = math.cos(p_rad), math.sin(p_rad)
    R_pitch = np.array([
        [1.0,  0.0,  0.0],
        [0.0,   cp,  -sp],
        [0.0,   sp,   cp]
    ])

    # 3. Yaw
    y_rad = math.radians(yaw_deg)
    cy, sy = math.cos(y_rad), math.sin(y_rad)
    R_yaw = np.array([
        [ cy,  sy, 0.0],
        [-sy,  cy, 0.0],
        [0.0, 0.0, 1.0]
    ])

    R_total = R_yaw @ R_pitch @ R_roll

    # Transform vertices
    V_raw = np.array(mesh.vertices)
    V_rot = (R_total @ V_raw.T).T

    # Screen projection (Forward is UP -> -Y in screen space)
    cx, cy = size / 2.0, size / 2.0
    V_screen = np.zeros((len(V_rot), 3))
    V_screen[:, 0] = cx + V_rot[:, 0] * scale
    V_screen[:, 1] = cy - V_rot[:, 1] * scale
    V_screen[:, 2] = V_rot[:, 2]

    # Buffers
    img_arr = np.zeros((size, size, 4), dtype=np.uint8)
    z_buffer = np.full((size, size), -1e9, dtype=np.float32)
    id_buffer = np.zeros((size, size), dtype=np.int32)

    # Rasterize triangles
    for f_idx, (v0, v1, v2, mat_id) in enumerate(mesh.faces):
        p0 = V_screen[v0]
        p1 = V_screen[v1]
        p2 = V_screen[v2]

        # Backface culling
        cp_z = (p1[0] - p0[0]) * (p2[1] - p0[1]) - (p1[1] - p0[1]) * (p2[0] - p0[0])
        if cp_z >= 0:
            continue

        # 3D normal for lighting
        e1 = V_rot[v1] - V_rot[v0]
        e2 = V_rot[v2] - V_rot[v0]
        norm = np.cross(e1, e2)
        norm_len = np.linalg.norm(norm)
        if norm_len > 1e-6:
            norm /= norm_len
        else:
            norm = np.array([0.0, 0.0, 1.0])

        diff = max(0.0, float(np.dot(norm, l_dir)))
        mat_cfg = palette.get(mat_id, palette[MAT_FUSELAGE])
        base_col = np.array(mat_cfg["base"], dtype=np.float32)

        if mat_id == MAT_ENGINE_EXHAUST or mat_id == MAT_DAMAGE_FIRE:
            shade = 1.18
        elif diff > 0.65:
            shade = 1.10
        elif diff > 0.28:
            shade = 1.00
        else:
            shade = 0.82

        col = tuple(np.clip(base_col * shade, 0, 255).astype(np.uint8))

        # Specular glint on flight deck glass
        if mat_id == MAT_COCKPIT:
            view_dir = np.array([0.0, 0.0, 1.0])
            half_vec = (l_dir + view_dir)
            half_vec /= np.linalg.norm(half_vec)
            spec = max(0.0, float(np.dot(norm, half_vec))) ** 16
            if spec > 0.65:
                col = (255, 255, 255)

        # Bounding box
        min_x = max(0, int(math.floor(min(p0[0], p1[0], p2[0]))))
        max_x = min(size - 1, int(math.ceil(max(p0[0], p1[0], p2[0]))))
        min_y = max(0, int(math.floor(min(p0[1], p1[1], p2[1]))))
        max_y = min(size - 1, int(math.ceil(max(p0[1], p1[1], p2[1]))))
        if min_x > max_x or min_y > max_y:
            continue

        denom = (p1[1] - p2[1]) * (p0[0] - p2[0]) + (p2[0] - p1[0]) * (p0[1] - p2[1])
        if abs(denom) < 1e-6:
            continue
        inv_denom = 1.0 / denom

        xs, ys = np.meshgrid(np.arange(min_x, max_x + 1), np.arange(min_y, max_y + 1))
        w0 = ((p1[1] - p2[1]) * (xs - p2[0]) + (p2[0] - p1[0]) * (ys - p2[1])) * inv_denom
        w1 = ((p2[1] - p0[1]) * (xs - p2[0]) + (p0[0] - p2[0]) * (ys - p2[1])) * inv_denom
        w2 = 1.0 - w0 - w1

        inside = (w0 >= 0.0) & (w1 >= 0.0) & (w2 >= 0.0)
        if not np.any(inside):
            continue

        z_interp = w0 * p0[2] + w1 * p1[2] + w2 * p2[2]
        sub_z = z_buffer[min_y:max_y+1, min_x:max_x+1]
        z_pass = inside & (z_interp > sub_z)

        if np.any(z_pass):
            sub_z[z_pass] = z_interp[z_pass]
            sub_arr = img_arr[min_y:max_y+1, min_x:max_x+1]
            sub_arr[z_pass, 0] = col[0]
            sub_arr[z_pass, 1] = col[1]
            sub_arr[z_pass, 2] = col[2]
            sub_arr[z_pass, 3] = 255
            id_buffer[min_y:max_y+1, min_x:max_x+1][z_pass] = mat_id

    # 4. Sobel Silhouette & Crease Edge Detection
    # Edge occurs where adjacent pixels have different material or alpha transition
    alpha_mask = img_arr[..., 3] > 0
    edge_map = np.zeros((size, size), dtype=bool)

    # Shift comparisons
    for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        shifted_a = np.roll(alpha_mask, (dy, dx), axis=(0, 1))
        shifted_id = np.roll(id_buffer, (dy, dx), axis=(0, 1))
        # Silhouette edge (against transparent background)
        edge_map |= alpha_mask & (~shifted_a)
        # Material boundary edge (e.g. wing to engine, cockpit to fuselage)
        edge_map |= alpha_mask & shifted_a & (id_buffer != shifted_id)

    # Apply crisp dark inking to contour edges
    ink_color = np.array([22, 28, 36, 255], dtype=np.uint8)
    img_arr[edge_map] = ink_color

    out_img = Image.fromarray(img_arr, mode="RGBA")
    draw = ImageDraw.Draw(out_img)

    # Add battle damage smoke and flame fx if damaged
    if damage_stage >= 1:
        for sx in [-1, 1]:
            if damage_stage >= 2 or sx == 1:
                fx = cx + sx * 120.0 * scale
                fy = cy - 2.0 * scale + 18.0
                draw.ellipse([fx - 8, fy - 8, fx + 8, fy + 8], fill=(255, 140, 20, 240))
                draw.ellipse([fx - 14, fy + 4, fx + 14, fy + 26], fill=(45, 45, 50, 210))
                draw.ellipse([fx - 18, fy + 20, fx + 18, fy + 50], fill=(30, 30, 35, 170))

    return out_img

print("✓ 3D Super-Heavy Boss Engine compiled successfully.")

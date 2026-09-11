#!/usr/bin/env python3
"""
tools/build_3d_bosses_expansion.py
Builds 3D models and renders spritesheets for the 4 expansion bosses:
1. Italy Boss: Piaggio P.108 Bombardiere (4-engine heavy with outer wing gun barbettes)
2. France Boss: Farman F.222 Heavy Bomber (4-engine tandem push-pull with twin rudders)
3. Poland Boss: PZL.37 Łoś (Twin-engine glazed heavy bomber with twin vertical fins)
4. Czech Boss: Aero A.300 (Twin-engine aerodynamic heavy bomber with dorsal turret)

Renders 3 battle-damage stages (Pristine, Wing Damaged, Critical Wreck)
into 1152x256 spritesheets (3 frames of 384x256) with matching JSON atlases.
"""

import math
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path

class Mesh3D:
    def __init__(self):
        self.vertices = []
        self.faces = []

    def add_vertex(self, x, y, z):
        self.vertices.append([float(x), float(y), float(z)])
        return len(self.vertices) - 1

    def add_quad(self, v0, v1, v2, v3, mat_id):
        self.faces.append((v0, v1, v2, mat_id))
        self.faces.append((v0, v2, v3, mat_id))

    def add_tri(self, v0, v1, v2, mat_id):
        self.faces.append((v0, v1, v2, mat_id))

def render_mesh_to_image(mesh, palette, scale=1.4, size_w=384, size_h=256, damage_stage=0):
    cx, cy = size_w / 2.0, size_h / 2.0
    l_dir = np.array([-0.3, 0.5, 0.81])
    l_dir = l_dir / np.linalg.norm(l_dir)

    v_screen = []
    for v in mesh.vertices:
        sx = cx + v[0] * scale
        sy = cy - v[1] * scale
        sz = v[2]
        v_screen.append((sx, sy, sz))

    sorted_faces = []
    for f in mesh.faces:
        v0, v1, v2, mat_id = f
        z_avg = (mesh.vertices[v0][2] + mesh.vertices[v1][2] + mesh.vertices[v2][2]) / 3.0
        sorted_faces.append((z_avg, f))
    sorted_faces.sort(key=lambda x: x[0])

    img = Image.new("RGBA", (size_w, size_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    for _, (v0, v1, v2, mat_id) in sorted_faces:
        p0 = (v_screen[v0][0], v_screen[v0][1])
        p1 = (v_screen[v1][0], v_screen[v1][1])
        p2 = (v_screen[v2][0], v_screen[v2][1])

        e1 = np.array(mesh.vertices[v1]) - np.array(mesh.vertices[v0])
        e2 = np.array(mesh.vertices[v2]) - np.array(mesh.vertices[v0])
        norm = np.cross(e1, e2)
        norm_len = np.linalg.norm(norm)
        if norm_len > 1e-6:
            norm = norm / norm_len
        else:
            norm = np.array([0.0, 0.0, 1.0])

        dot = np.dot(norm, l_dir)
        mat_info = palette.get(mat_id, palette[1])

        # Apply battle damage color shifts
        if damage_stage == 1 and mat_id == 11: # charred
            fill_col = (45, 42, 40)
        elif damage_stage == 2 and mat_id in (1, 2, 11):
            fill_col = (35, 32, 30) if mat_id == 11 else (60, 50, 45)
        else:
            if dot < 0.2:
                fill_col = mat_info["shadow"]
            elif dot < 0.6:
                fill_col = mat_info["mid"]
            else:
                fill_col = mat_info["high"]

        draw.polygon([p0, p1, p2], fill=fill_col + (255,))

    return img

# =============================================================================
# 1. PIAGGIO P.108 (ITALY 4-ENGINE HEAVY FORTRESS)
# =============================================================================
def build_p108_mesh(damage_stage=0):
    m = Mesh3D()
    MAT_BODY = 1        # Sand / Ochre
    MAT_WHITE = 2       # White Fuselage Band & Cross
    MAT_CANOPY = 3      # Glass
    MAT_COWLING = 4     # Engine Cowls
    MAT_TURRET = 5      # Outer Wing Barbette Turrets
    MAT_CHARRED = 11

    # Fuselage
    fuse_secs = [
        (75.0, 7.0, 8.0, 0.0, MAT_CANOPY),
        (55.0, 9.0, 10.0, 0.5, MAT_CANOPY),
        (30.0, 11.0, 12.0, 1.0, MAT_BODY),
        (0.0,  11.5, 12.5, 0.8, MAT_BODY),
        (-25.0, 10.0, 11.0, 0.6, MAT_WHITE),
        (-50.0, 7.5, 8.5, 0.4, MAT_WHITE),
        (-75.0, 4.5, 5.5, 0.2, MAT_BODY),
        (-95.0, 1.5, 2.0, 0.0, MAT_BODY),
    ]
    rings = []
    n_rad = 10
    for y, rx, rz, zc, mat in fuse_secs:
        ring = []
        for i in range(n_rad):
            th = 2.0 * math.pi * i / n_rad
            ring.append(m.add_vertex(rx * math.cos(th), y, zc + rz * math.sin(th)))
        rings.append((ring, mat))
    for s in range(len(fuse_secs) - 1):
        r0, _ = rings[s]
        r1, mat1 = rings[s + 1]
        for i in range(n_rad):
            i_next = (i + 1) % n_rad
            m.add_quad(r0[i], r0[i_next], r1[i_next], r1[i], mat1)

    # Wings (Massive 4-engine span)
    wing_spans = [
        (10.0, 24.0, -18.0, 1.0, 4.0),
        (45.0, 20.0, -15.0, 2.0, 3.5),  # Inboard engine
        (85.0, 16.0, -12.0, 3.0, 3.0),  # Outboard engine + BARBETTE
        (125.0, 10.0, -8.0, 4.0, 2.2),
        (150.0, 4.0, -5.0, 4.5, 1.4),   # Tip
    ]
    for side in [1.0, -1.0]:
        if damage_stage == 2 and side > 0: # Right wing torn off in wreck
            continue
        w_rings = []
        for span, f_y, r_y, z_up, thick in wing_spans:
            x = side * span
            top_le = m.add_vertex(x, f_y, z_up + thick * 0.4)
            top_te = m.add_vertex(x, r_y, z_up)
            bot_le = m.add_vertex(x, f_y, z_up - thick * 0.6)
            bot_te = m.add_vertex(x, r_y, z_up - 0.2)
            w_rings.append((top_le, top_te, bot_le, bot_te))

        for i in range(len(wing_spans) - 1):
            t_le0, t_te0, b_le0, b_te0 = w_rings[i]
            t_le1, t_te1, b_le1, b_te1 = w_rings[i + 1]
            mat = MAT_CHARRED if (damage_stage >= 1 and i == 2 and side < 0) else MAT_BODY
            m.add_quad(t_le0, t_le1, t_te1, t_te0, mat)
            m.add_quad(b_te0, b_te1, b_le1, b_le0, mat)

        # Engine Nacelles (2 per wing)
        for eng_x in [side * 45.0, side * 85.0]:
            e_nose = m.add_vertex(eng_x, 26.0, 1.8)
            e_rear = m.add_vertex(eng_x, -12.0, 1.8)
            e_top  = m.add_vertex(eng_x, 15.0, 5.5)
            e_bot  = m.add_vertex(eng_x, 15.0, -1.8)
            m.add_quad(e_nose, e_top, e_rear, e_bot, MAT_COWLING)

        # Wing Gun Barbette (Outer Engine Pod)
        barb_x = side * 85.0
        b_f = m.add_vertex(barb_x, 12.0, 6.2)
        b_r = m.add_vertex(barb_x, -4.0, 6.2)
        b_l = m.add_vertex(barb_x - 3.0, 4.0, 5.0)
        b_rt = m.add_vertex(barb_x + 3.0, 4.0, 5.0)
        m.add_quad(b_f, b_rt, b_r, b_l, MAT_TURRET)

    # Tail & Rudder with Savoia Cross
    for side in [1.0, -1.0]:
        h_f = m.add_vertex(side * 4.0, -78.0, 1.5)
        h_r = m.add_vertex(side * 4.0, -96.0, 1.5)
        h_tf = m.add_vertex(side * 42.0, -84.0, 2.2)
        h_tr = m.add_vertex(side * 38.0, -96.0, 2.0)
        m.add_quad(h_f, h_tf, h_tr, h_r, MAT_BODY)

    fin_f = m.add_vertex(0.0, -68.0, 2.0)
    fin_r = m.add_vertex(0.0, -96.0, 1.5)
    fin_tf = m.add_vertex(0.0, -84.0, 26.0)
    fin_tr = m.add_vertex(0.0, -94.0, 20.0)
    m.add_quad(fin_f, fin_tf, fin_tr, fin_r, MAT_WHITE)

    return m

PALETTE_P108 = {
    1: {"shadow": (120, 88, 45), "mid": (180, 138, 78), "high": (220, 178, 114)}, # Italian Sand
    2: {"shadow": (200, 200, 205), "mid": (240, 240, 245), "high": (255, 255, 255)}, # White
    3: {"shadow": (28, 52, 72), "mid": (56, 96, 130), "high": (130, 185, 220)},     # Glass
    4: {"shadow": (35, 38, 35), "mid": (58, 62, 58), "high": (92, 98, 92)},         # Cowl
    5: {"shadow": (22, 24, 26), "mid": (42, 45, 48), "high": (75, 80, 85)},         # Turret
    11: {"shadow": (30, 28, 26), "mid": (50, 46, 42), "high": (75, 70, 65)},       # Charred
}

# =============================================================================
# 2. FARMAN F.222 (FRANCE 4-ENGINE HEAVY BOMBER)
# =============================================================================
def build_f222_mesh(damage_stage=0):
    m = Mesh3D()
    MAT_BODY = 1        # French Khaki / Dark Olive
    MAT_TRICOLOR = 2    # Tricolor Rudder
    MAT_CANOPY = 3      # Glass
    MAT_NACELLE = 4     # Tandem Push-Pull Nacelles
    MAT_CHARRED = 11

    # Boxy French Fuselage
    fuse_secs = [
        (72.0, 7.0, 8.5, 0.0, MAT_CANOPY),
        (50.0, 8.5, 10.0, 0.5, MAT_CANOPY),
        (25.0, 9.5, 11.0, 1.0, MAT_BODY),
        (-5.0, 9.5, 11.0, 0.8, MAT_BODY),
        (-35.0, 8.5, 9.5, 0.5, MAT_BODY),
        (-65.0, 6.5, 7.5, 0.3, MAT_BODY),
        (-90.0, 3.5, 4.5, 0.2, MAT_BODY),
    ]
    rings = []
    n_rad = 8 # Boxy angular cross section
    for y, rx, rz, zc, mat in fuse_secs:
        ring = []
        for i in range(n_rad):
            th = 2.0 * math.pi * (i + 0.5) / n_rad
            ring.append(m.add_vertex(rx * math.cos(th), y, zc + rz * math.sin(th)))
        rings.append((ring, mat))
    for s in range(len(fuse_secs) - 1):
        r0, _ = rings[s]
        r1, mat1 = rings[s + 1]
        for i in range(n_rad):
            i_next = (i + 1) % n_rad
            m.add_quad(r0[i], r0[i_next], r1[i_next], r1[i], mat1)

    # Parasol High Wing
    wing_spans = [
        (8.0, 22.0, -18.0, 6.0, 3.5),
        (48.0, 18.0, -15.0, 6.2, 3.2),  # Tandem Push-Pull Nacelle
        (92.0, 14.0, -12.0, 6.4, 2.6),
        (142.0, 6.0, -8.0, 6.6, 1.6),   # Wingtip
    ]
    for side in [1.0, -1.0]:
        if damage_stage == 2 and side < 0: # Left wing severed
            continue
        w_rings = []
        for span, f_y, r_y, z_up, thick in wing_spans:
            x = side * span
            top_le = m.add_vertex(x, f_y, z_up + thick * 0.4)
            top_te = m.add_vertex(x, r_y, z_up)
            bot_le = m.add_vertex(x, f_y, z_up - thick * 0.6)
            bot_te = m.add_vertex(x, r_y, z_up - 0.2)
            w_rings.append((top_le, top_te, bot_le, bot_te))

        for i in range(len(wing_spans) - 1):
            t_le0, t_te0, b_le0, b_te0 = w_rings[i]
            t_le1, t_te1, b_le1, b_te1 = w_rings[i + 1]
            mat = MAT_CHARRED if (damage_stage >= 1 and i == 1 and side > 0) else MAT_BODY
            m.add_quad(t_le0, t_le1, t_te1, t_te0, mat)
            m.add_quad(b_te0, b_te1, b_le1, b_le0, mat)

        # Tandem Push-Pull Nacelle (Forward tractor prop + Rear pusher prop!)
        nac_x = side * 48.0
        n_f = m.add_vertex(nac_x, 26.0, 2.0)
        n_r = m.add_vertex(nac_x, -26.0, 2.0)
        n_top = m.add_vertex(nac_x, 0.0, 5.8)
        n_bot = m.add_vertex(nac_x, 0.0, -2.2)
        m.add_quad(n_f, n_top, n_r, n_bot, MAT_NACELLE)

    # Twin Vertical Fins on Horizontal Tail
    for side in [1.0, -1.0]:
        h_f = m.add_vertex(side * 4.0, -75.0, 2.0)
        h_r = m.add_vertex(side * 4.0, -92.0, 2.0)
        h_tf = m.add_vertex(side * 36.0, -80.0, 2.5)
        h_tr = m.add_vertex(side * 34.0, -92.0, 2.5)
        m.add_quad(h_f, h_tf, h_tr, h_r, MAT_BODY)

        # Endplate Fin
        f_b = m.add_vertex(side * 35.0, -78.0, 2.5)
        f_br = m.add_vertex(side * 35.0, -92.0, 2.5)
        f_t = m.add_vertex(side * 35.0, -82.0, 18.0)
        f_tr = m.add_vertex(side * 35.0, -90.0, 16.0)
        m.add_quad(f_b, f_t, f_tr, f_br, MAT_TRICOLOR)

    return m

PALETTE_F222 = {
    1: {"shadow": (48, 54, 42), "mid": (78, 88, 68), "high": (115, 128, 102)},   # French Khaki
    2: {"shadow": (160, 25, 25), "mid": (210, 38, 38), "high": (245, 245, 250)}, # Tricolor
    3: {"shadow": (28, 52, 72), "mid": (56, 96, 130), "high": (130, 185, 220)},   # Glass
    4: {"shadow": (35, 38, 35), "mid": (58, 62, 58), "high": (90, 95, 90)},       # Nacelle
    11: {"shadow": (28, 26, 24), "mid": (48, 44, 40), "high": (72, 68, 64)},     # Charred
}

# =============================================================================
# 3. PZL.37 ŁOŚ (POLAND TWIN-ENGINE HEAVY BOMBER)
# =============================================================================
def build_pzl37_mesh(damage_stage=0):
    m = Mesh3D()
    MAT_BODY = 1        # Polish Khaki
    MAT_CHECKER = 2     # Red/White Checkerboard
    MAT_CANOPY = 3      # Heavily Glazed Nose
    MAT_COWLING = 4     # Bristol Pegasus Radial Engines
    MAT_CHARRED = 11

    # Sleek Polish Monocoque Fuselage with Glazed Nose
    fuse_secs = [
        (68.0, 4.5, 5.5, 0.0, MAT_CANOPY),
        (48.0, 6.5, 7.5, 0.4, MAT_CANOPY),
        (22.0, 7.5, 8.5, 0.8, MAT_BODY),
        (-5.0, 7.5, 8.5, 0.6, MAT_BODY),
        (-30.0, 6.0, 7.0, 0.4, MAT_BODY),
        (-55.0, 4.2, 5.0, 0.2, MAT_BODY),
        (-78.0, 1.8, 2.2, 0.2, MAT_BODY),
    ]
    rings = []
    n_rad = 10
    for y, rx, rz, zc, mat in fuse_secs:
        ring = []
        for i in range(n_rad):
            th = 2.0 * math.pi * i / n_rad
            ring.append(m.add_vertex(rx * math.cos(th), y, zc + rz * math.sin(th)))
        rings.append((ring, mat))
    for s in range(len(fuse_secs) - 1):
        r0, _ = rings[s]
        r1, mat1 = rings[s + 1]
        for i in range(n_rad):
            i_next = (i + 1) % n_rad
            m.add_quad(r0[i], r0[i_next], r1[i_next], r1[i], mat1)

    # Wings (Twin-Engine Low-Wing with Elliptical Trailing Edge)
    wing_spans = [
        (7.0, 18.0, -14.0, 0.0, 3.2),
        (38.0, 16.0, -12.0, 0.8, 3.0),  # Engine Nacelle
        (75.0, 12.0, -9.0, 1.8, 2.4),   # Checkerboard
        (118.0, 4.0, -4.0, 2.8, 1.4),   # Tip
    ]
    for side in [1.0, -1.0]:
        if damage_stage == 2 and side > 0: # Right wing wrecked
            continue
        w_rings = []
        for span, f_y, r_y, z_up, thick in wing_spans:
            x = side * span
            top_le = m.add_vertex(x, f_y, z_up + thick * 0.4)
            top_te = m.add_vertex(x, r_y, z_up)
            bot_le = m.add_vertex(x, f_y, z_up - thick * 0.6)
            bot_te = m.add_vertex(x, r_y, z_up - 0.2)
            w_rings.append((top_le, top_te, bot_le, bot_te))

        for i in range(len(wing_spans) - 1):
            t_le0, t_te0, b_le0, b_te0 = w_rings[i]
            t_le1, t_te1, b_le1, b_te1 = w_rings[i + 1]
            mat = MAT_CHARRED if (damage_stage >= 1 and i == 1 and side < 0) else (MAT_CHECKER if i == 2 else MAT_BODY)
            m.add_quad(t_le0, t_le1, t_te1, t_te0, mat)
            m.add_quad(b_te0, b_te1, b_le1, b_le0, mat)

        # Radial Engine Pod
        eng_x = side * 38.0
        e_f = m.add_vertex(eng_x, 22.0, 0.8)
        e_r = m.add_vertex(eng_x, -14.0, 0.8)
        e_top = m.add_vertex(eng_x, 8.0, 4.2)
        e_bot = m.add_vertex(eng_x, 8.0, -2.6)
        m.add_quad(e_f, e_top, e_r, e_bot, MAT_COWLING)

    # Twin Vertical Tail Fins
    for side in [1.0, -1.0]:
        h_f = m.add_vertex(side * 3.0, -68.0, 1.2)
        h_r = m.add_vertex(side * 3.0, -82.0, 1.2)
        h_tf = m.add_vertex(side * 32.0, -72.0, 1.6)
        h_tr = m.add_vertex(side * 30.0, -82.0, 1.6)
        m.add_quad(h_f, h_tf, h_tr, h_r, MAT_BODY)

        # Endplate Oval Fin
        f_b = m.add_vertex(side * 31.0, -70.0, 1.6)
        f_br = m.add_vertex(side * 31.0, -82.0, 1.6)
        f_t = m.add_vertex(side * 31.0, -74.0, 17.0)
        f_tr = m.add_vertex(side * 31.0, -81.0, 14.0)
        m.add_quad(f_b, f_t, f_tr, f_br, MAT_CHECKER)

    return m

PALETTE_PZL37 = {
    1: {"shadow": (50, 56, 38), "mid": (84, 94, 62), "high": (122, 136, 92)},     # Polish Khaki
    2: {"shadow": (160, 25, 25), "mid": (210, 38, 38), "high": (245, 245, 250)},  # Checkerboard
    3: {"shadow": (28, 52, 72), "mid": (56, 96, 130), "high": (130, 185, 220)},   # Glass
    4: {"shadow": (35, 38, 35), "mid": (58, 62, 58), "high": (92, 98, 92)},       # Radial Cowl
    11: {"shadow": (28, 26, 24), "mid": (48, 44, 40), "high": (72, 68, 64)},     # Charred
}

# =============================================================================
# 4. AERO A.300 (CZECHOSLOVAKIA FAST HEAVY BOMBER)
# =============================================================================
def build_a300_mesh(damage_stage=0):
    m = Mesh3D()
    MAT_BODY = 1        # Czech Khaki
    MAT_ROUNDEL = 2     # Tricolor Roundel
    MAT_CANOPY = 3      # Nose Greenhouse
    MAT_COWLING = 4     # Bristol Mercury Engines
    MAT_TURRET = 5      # Dorsal Gun Turret
    MAT_CHARRED = 11

    # Streamlined Aerodynamic Czech Fuselage
    fuse_secs = [
        (66.0, 5.0, 6.0, 0.0, MAT_CANOPY),
        (46.0, 7.0, 8.0, 0.4, MAT_CANOPY),
        (20.0, 8.0, 9.0, 0.8, MAT_BODY),
        (-6.0, 8.0, 9.0, 0.6, MAT_BODY),
        (-32.0, 6.5, 7.5, 0.4, MAT_BODY),
        (-56.0, 4.5, 5.2, 0.2, MAT_BODY),
        (-76.0, 1.8, 2.2, 0.2, MAT_BODY),
    ]
    rings = []
    n_rad = 10
    for y, rx, rz, zc, mat in fuse_secs:
        ring = []
        for i in range(n_rad):
            th = 2.0 * math.pi * i / n_rad
            ring.append(m.add_vertex(rx * math.cos(th), y, zc + rz * math.sin(th)))
        rings.append((ring, mat))
    for s in range(len(fuse_secs) - 1):
        r0, _ = rings[s]
        r1, mat1 = rings[s + 1]
        for i in range(n_rad):
            i_next = (i + 1) % n_rad
            m.add_quad(r0[i], r0[i_next], r1[i_next], r1[i], mat1)

    # Dorsal Rotating Bubble Gun Turret
    dt_f = m.add_vertex(0.0, -10.0, 11.5)
    dt_r = m.add_vertex(0.0, -22.0, 11.5)
    dt_l = m.add_vertex(-3.8, -16.0, 9.5)
    dt_rt = m.add_vertex(3.8, -16.0, 9.5)
    m.add_quad(dt_f, dt_rt, dt_r, dt_l, MAT_TURRET)

    # Wings (Twin-Engine Low Wing)
    wing_spans = [
        (7.0, 18.0, -14.0, 0.0, 3.2),
        (36.0, 16.0, -12.0, 0.8, 3.0),  # Engine Nacelle
        (72.0, 12.0, -8.0, 1.8, 2.4),   # Roundel
        (115.0, 4.0, -4.0, 2.8, 1.4),   # Tip
    ]
    for side in [1.0, -1.0]:
        if damage_stage == 2 and side < 0: # Left wing severed
            continue
        w_rings = []
        for span, f_y, r_y, z_up, thick in wing_spans:
            x = side * span
            top_le = m.add_vertex(x, f_y, z_up + thick * 0.4)
            top_te = m.add_vertex(x, r_y, z_up)
            bot_le = m.add_vertex(x, f_y, z_up - thick * 0.6)
            bot_te = m.add_vertex(x, r_y, z_up - 0.2)
            w_rings.append((top_le, top_te, bot_le, bot_te))

        for i in range(len(wing_spans) - 1):
            t_le0, t_te0, b_le0, b_te0 = w_rings[i]
            t_le1, t_te1, b_le1, b_te1 = w_rings[i + 1]
            mat = MAT_CHARRED if (damage_stage >= 1 and i == 1 and side > 0) else (MAT_ROUNDEL if i == 2 else MAT_BODY)
            m.add_quad(t_le0, t_le1, t_te1, t_te0, mat)
            m.add_quad(b_te0, b_te1, b_le1, b_le0, mat)

        # Engine Pod
        eng_x = side * 36.0
        e_f = m.add_vertex(eng_x, 22.0, 0.8)
        e_r = m.add_vertex(eng_x, -14.0, 0.8)
        e_top = m.add_vertex(eng_x, 8.0, 4.2)
        e_bot = m.add_vertex(eng_x, 8.0, -2.6)
        m.add_quad(e_f, e_top, e_r, e_bot, MAT_COWLING)

    # Twin Vertical Tail Fins
    for side in [1.0, -1.0]:
        h_f = m.add_vertex(side * 3.0, -66.0, 1.2)
        h_r = m.add_vertex(side * 3.0, -80.0, 1.2)
        h_tf = m.add_vertex(side * 30.0, -70.0, 1.6)
        h_tr = m.add_vertex(side * 28.0, -80.0, 1.6)
        m.add_quad(h_f, h_tf, h_tr, h_r, MAT_BODY)

        # Endplate Fin
        f_b = m.add_vertex(side * 29.0, -68.0, 1.6)
        f_br = m.add_vertex(side * 29.0, -80.0, 1.6)
        f_t = m.add_vertex(side * 29.0, -72.0, 16.0)
        f_tr = m.add_vertex(side * 29.0, -78.0, 13.0)
        m.add_quad(f_b, f_t, f_tr, f_br, MAT_ROUNDEL)

    return m

PALETTE_A300 = {
    1: {"shadow": (46, 54, 36), "mid": (80, 92, 60), "high": (118, 134, 88)},     # Czech Khaki
    2: {"shadow": (25, 45, 95), "mid": (42, 80, 160), "high": (245, 245, 250)},   # Tricolor
    3: {"shadow": (28, 52, 72), "mid": (56, 96, 130), "high": (130, 185, 220)},   # Glass
    4: {"shadow": (35, 38, 35), "mid": (58, 62, 58), "high": (92, 98, 92)},       # Cowl
    5: {"shadow": (22, 24, 26), "mid": (42, 45, 48), "high": (75, 80, 85)},       # Turret
    11: {"shadow": (28, 26, 24), "mid": (48, 44, 40), "high": (72, 68, 64)},     # Charred
}

# =============================================================================
# SPRITESHEET GENERATION & EXPORT
# =============================================================================
def generate_boss_sheet(boss_key, mesh_fn, palette, out_dir, art_dir):
    print(f"[Sky Ace] Rendering 3D Boss: {boss_key.upper()}...")
    frames = []
    for stage in [0, 1, 2]:
        mesh = mesh_fn(damage_stage=stage)
        img = render_mesh_to_image(mesh, palette, scale=1.35, size_w=384, size_h=256, damage_stage=stage)
        frames.append(img)

    sheet = Image.new("RGBA", (1152, 256), (0, 0, 0, 0))
    for idx, fr in enumerate(frames):
        sheet.paste(fr, (idx * 384, 0))

    # Save PNG
    out_png = out_dir / f"sheet_boss_{boss_key}.png"
    art_png = art_dir / f"sheet_boss_{boss_key}.png"
    sheet.save(out_png)
    sheet.save(art_png)

    # Save JSON Atlas
    atlas = {
        "meta": {
            "image": f"sheet_boss_{boss_key}.png",
            "size": {"w": 1152, "h": 256},
            "cell": {"w": 384, "h": 256},
            "cols": 3,
            "rows": 1
        },
        "frames": {
            "pristine": {"frame": {"x": 0, "y": 0, "w": 384, "h": 256}, "sourceSize": {"w": 384, "h": 256}},
            "wing_damaged": {"frame": {"x": 384, "y": 0, "w": 384, "h": 256}, "sourceSize": {"w": 384, "h": 256}},
            "critical_wreck": {"frame": {"x": 768, "y": 0, "w": 384, "h": 256}, "sourceSize": {"w": 384, "h": 256}}
        },
        "pristine": {"x": 0, "y": 0, "w": 384, "h": 256},
        "wing_damaged": {"x": 384, "y": 0, "w": 384, "h": 256},
        "critical_wreck": {"x": 768, "y": 0, "w": 384, "h": 256}
    }
    out_json = out_dir / f"sheet_boss_{boss_key}.json"
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(atlas, f, indent=2)

    print(f"✓ Saved sheet_boss_{boss_key}.png and json atlas")

def main():
    spr_dir = Path("games/skyace/sprites")
    spr_dir.mkdir(parents=True, exist_ok=True)
    art_dir = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62")

    bosses = [
        ("p108", build_p108_mesh, PALETTE_P108),
        ("f222", build_f222_mesh, PALETTE_F222),
        ("pzl37", build_pzl37_mesh, PALETTE_PZL37),
        ("a300", build_a300_mesh, PALETTE_A300),
    ]

    for key, fn, pal in bosses:
        generate_boss_sheet(key, fn, pal, spr_dir, art_dir)

if __name__ == "__main__":
    main()

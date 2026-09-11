#!/usr/bin/env python3
"""
tools/build_3d_carriers_celshaded.py
Builds true 3D polygonal geometric meshes (Mesh3D) of WWII aircraft carriers
and renders them through our software 3D cel-shading and inking rasterizer.

Matches the exact visual quality, directional sunlight, 3-tone shading, and
bold ink contours of our 3D P-38 Lightning, Zero, and B-24 Liberator boss.
"""

import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path

WIDTH, HEIGHT = 320, 720

class Mesh3D:
    def __init__(self):
        self.vertices = []
        self.faces = []

    def add_vertex(self, x, y, z):
        self.vertices.append([float(x), float(y), float(z)])
        return len(self.vertices) - 1

    def add_quad(self, v0, v1, v2, v3, mat_id):
        # Two triangles with counter-clockwise winding
        self.faces.append((v0, v1, v2, mat_id))
        self.faces.append((v0, v2, v3, mat_id))

    def add_tri(self, v0, v1, v2, mat_id):
        self.faces.append((v0, v1, v2, mat_id))


# Materials
MAT_HULL = 1          # Navy Steel Hull & Sponsons
MAT_DECK = 2          # Flight Deck (Teak / Cedar / Steel)
MAT_DECK_DARK = 3     # Recessed Elevator Bays / Shadows
MAT_ISLAND = 4        # Bridge Superstructure Tower
MAT_ISLAND_HIGH = 5   # Bridge Upper Navigation Deck
MAT_WINDOW = 6        # Bridge Glazing (Cyan Specular)
MAT_FUNNEL = 7        # Funnel Stack & Exhaust Grill
MAT_MAST = 8          # Radar Mast & Yardarms
MAT_GUN_TUB = 9       # Bofors / Oerlikon Gun Tubs
MAT_CATWALK = 10      # Steel Grate Catwalks


def build_carrier_mesh(nation="usa"):
    mesh = Mesh3D()

    # Coordinates:
    # X: -Port (Left), +Starboard (Right)
    # Y: +Forward (Bow at +310), -Aft (Stern at -310)
    # Z: 0 is Waterline, +20 is Catwalks, +26 is Flight Deck, +42..+68 is Island

    # 1. HULL KEEL & LOWER SPONSONS (Flared clipper bow and armored sides)
    hull_slices = [
        ( 318.0,  -48.0,   48.0,   2.0, 22.0), # Stem post (Bow)
        ( 280.0,  -76.0,   76.0,   2.0, 24.0), # Forward flare
        ( 200.0,  -94.0,   94.0,   2.0, 25.0), # Forward shoulder
        (  80.0,  -98.0,  102.0,   2.0, 25.0), # Midships forward (island base)
        ( -80.0,  -98.0,  100.0,   2.0, 25.0), # Midships aft
        (-240.0,  -92.0,   92.0,   2.0, 25.0), # Quarterdeck
        (-314.0,  -74.0,   74.0,   2.0, 23.0), # Stern round
    ]

    h_rings = []
    for y, px, sx, zb, zd in hull_slices:
        v_pb = mesh.add_vertex(px * 0.72, y, zb)
        v_pd = mesh.add_vertex(px, y, zd)
        v_sd = mesh.add_vertex(sx, y, zd)
        v_sb = mesh.add_vertex(sx * 0.72, y, zb)
        h_rings.append((v_pb, v_pd, v_sd, v_sb))

    for s in range(len(hull_slices) - 1):
        r0 = h_rings[s]
        r1 = h_rings[s + 1]
        # Port side
        mesh.add_quad(r0[0], r0[1], r1[1], r1[0], MAT_HULL)
        # Starboard side
        mesh.add_quad(r0[3], r1[3], r1[2], r0[2], MAT_HULL)
        # Bottom keel
        mesh.add_quad(r0[0], r1[0], r1[3], r0[3], MAT_HULL)

    # Bow plate
    mesh.add_quad(h_rings[0][0], h_rings[0][3], h_rings[0][2], h_rings[0][1], MAT_HULL)
    # Stern transom
    mesh.add_quad(h_rings[-1][0], h_rings[-1][1], h_rings[-1][2], h_rings[-1][3], MAT_HULL)

    # 2. CATWALKS & GUN SPONSONS (Outboard along port & stbd)
    sponsons_y = [220.0, 110.0, -30.0, -170.0]
    for sy in sponsons_y:
        for side in [-1, 1]:
            bx = side * 102.0
            r = 9.0
            # Sponson platform
            sp0 = mesh.add_vertex(bx - side * 6, sy + 14, 22.0)
            sp1 = mesh.add_vertex(bx + side * 12, sy + 14, 22.0)
            sp2 = mesh.add_vertex(bx + side * 12, sy - 14, 22.0)
            sp3 = mesh.add_vertex(bx - side * 6, sy - 14, 22.0)
            if side == 1:
                mesh.add_quad(sp0, sp1, sp2, sp3, MAT_CATWALK)
            else:
                mesh.add_quad(sp0, sp3, sp2, sp1, MAT_CATWALK)

            # 3D Cylindrical AA Gun Tub
            n_tub = 8
            t_rim, t_base = [], []
            for i in range(n_tub):
                ang = 2.0 * math.pi * i / n_tub
                tx = bx + side * 4 + r * math.cos(ang)
                ty = sy + r * math.sin(ang)
                t_rim.append(mesh.add_vertex(tx, ty, 26.5))
                t_base.append(mesh.add_vertex(tx, ty, 22.2))

            for i in range(n_tub):
                i_next = (i + 1) % n_tub
                mesh.add_quad(t_base[i], t_rim[i], t_rim[i_next], t_base[i_next], MAT_GUN_TUB)
            # Tub floor
            c_floor = mesh.add_vertex(bx + side * 4, sy, 22.8)
            for i in range(n_tub):
                mesh.add_tri(t_base[i], c_floor, t_base[(i + 1) % n_tub], MAT_DECK_DARK)

    # 3. FLIGHT DECK (Broad planar faceted surface with bevel rim)
    deck_contour = [
        (-56.0,  320.0), # Bow Port
        ( 56.0,  320.0), # Bow Stbd
        ( 88.0,  280.0), # Stbd shoulder
        ( 96.0,  150.0), # Stbd mid
        ( 96.0, -250.0), # Stbd aft
        ( 80.0, -316.0), # Stbd stern round
        (-80.0, -316.0), # Port stern round
        (-96.0, -250.0), # Port aft
        (-96.0,  150.0), # Port mid
        (-88.0,  280.0), # Port shoulder
    ]

    deck_v_top = [mesh.add_vertex(x, y, 26.5) for x, y in deck_contour]
    deck_v_bot = [mesh.add_vertex(x, y, 23.5) for x, y in deck_contour]

    # Bevel edge rim around deck perimeter
    n_dc = len(deck_contour)
    for i in range(n_dc):
        i_next = (i + 1) % n_dc
        mesh.add_quad(deck_v_bot[i], deck_v_top[i], deck_v_top[i_next], deck_v_bot[i_next], MAT_HULL)

    # Top flight deck surface (Center spine fan triangulation with upward normal)
    c_fwd = mesh.add_vertex(0.0,  200.0, 26.5)
    c_mid = mesh.add_vertex(0.0,    0.0, 26.5)
    c_aft = mesh.add_vertex(0.0, -200.0, 26.5)

    mesh.add_tri(c_fwd, deck_v_top[1], deck_v_top[0], MAT_DECK)
    mesh.add_tri(c_fwd, deck_v_top[2], deck_v_top[1], MAT_DECK)
    mesh.add_tri(c_fwd, deck_v_top[3], deck_v_top[2], MAT_DECK)
    mesh.add_tri(c_mid, deck_v_top[3], c_fwd, MAT_DECK)
    mesh.add_tri(c_mid, deck_v_top[4], deck_v_top[3], MAT_DECK)
    mesh.add_tri(c_aft, deck_v_top[5], deck_v_top[4], MAT_DECK)
    mesh.add_tri(c_aft, deck_v_top[6], deck_v_top[5], MAT_DECK)
    mesh.add_tri(c_aft, deck_v_top[7], deck_v_top[6], MAT_DECK)
    mesh.add_tri(c_aft, c_mid, deck_v_top[7], MAT_DECK)
    mesh.add_tri(c_mid, deck_v_top[8], deck_v_top[7], MAT_DECK)
    mesh.add_tri(c_mid, c_fwd, deck_v_top[8], MAT_DECK)
    mesh.add_tri(c_fwd, deck_v_top[9], deck_v_top[8], MAT_DECK)
    mesh.add_tri(c_fwd, deck_v_top[0], deck_v_top[9], MAT_DECK)

    # 4. RECESSED AIRCRAFT ELEVATORS (Forward & Aft bays)
    for elev_y in [135.0, -135.0]:
        ew, eh = 30.0, 38.0
        ez = 26.6 # Slightly raised so it renders on top of deck in Z-buffer
        ev0 = mesh.add_vertex(-ew, elev_y - eh, ez)
        ev1 = mesh.add_vertex( ew, elev_y - eh, ez)
        ev2 = mesh.add_vertex( ew, elev_y + eh, ez)
        ev3 = mesh.add_vertex(-ew, elev_y + eh, ez)
        mesh.add_quad(ev0, ev1, ev2, ev3, MAT_DECK_DARK)

    # 5. 3D ISLAND SUPERSTRUCTURE (Starboard side at X = +70..+94, Y = +5..+95)
    if nation != "soviet":
        ix0, ix1 = 70.0, 94.0
        iy0, iy1 = 5.0, 90.0

        # Tier 1: Lower Armored Island Trunk (Z = 26.5 to 44.0)
        t1_b0 = mesh.add_vertex(ix0, iy0, 26.5)
        t1_b1 = mesh.add_vertex(ix1, iy0, 26.5)
        t1_b2 = mesh.add_vertex(ix1, iy1 - 8.0, 26.5)
        t1_b3 = mesh.add_vertex(ix0, iy1, 26.5)

        t1_t0 = mesh.add_vertex(ix0, iy0, 44.0)
        t1_t1 = mesh.add_vertex(ix1, iy0, 44.0)
        t1_t2 = mesh.add_vertex(ix1, iy1 - 8.0, 44.0)
        t1_t3 = mesh.add_vertex(ix0, iy1, 44.0)

        # Island trunk walls
        mesh.add_quad(t1_b0, t1_b1, t1_t1, t1_t0, MAT_ISLAND) # Aft
        mesh.add_quad(t1_b1, t1_b2, t1_t2, t1_t1, MAT_ISLAND) # Outboard
        mesh.add_quad(t1_b2, t1_b3, t1_t3, t1_t2, MAT_ISLAND) # Forward
        mesh.add_quad(t1_b3, t1_b0, t1_t0, t1_t3, MAT_ISLAND) # Inboard (flight deck face)
        mesh.add_quad(t1_t0, t1_t1, t1_t2, t1_t3, MAT_ISLAND_HIGH) # Tier 1 roof

        # Tier 2: Forward Flying Bridge / Navigation House (Y = 55 to 88, Z = 44 to 58)
        bx0, bx1 = 72.0, 92.0
        by0, by1 = 55.0, 86.0

        bb0 = mesh.add_vertex(bx0, by0, 44.0)
        bb1 = mesh.add_vertex(bx1, by0, 44.0)
        bb2 = mesh.add_vertex(bx1, by1, 44.0)
        bb3 = mesh.add_vertex(bx0, by1, 44.0)

        bt0 = mesh.add_vertex(bx0, by0, 58.0)
        bt1 = mesh.add_vertex(bx1, by0, 58.0)
        bt2 = mesh.add_vertex(bx1, by1, 58.0)
        bt3 = mesh.add_vertex(bx0, by1, 58.0)

        mesh.add_quad(bb0, bb1, bt1, bt0, MAT_ISLAND_HIGH)
        mesh.add_quad(bb1, bb2, bt2, bt1, MAT_ISLAND_HIGH)
        mesh.add_quad(bb2, bb3, bt3, bt2, MAT_WINDOW)      # Forward bridge window
        mesh.add_quad(bb3, bb0, bt0, bt3, MAT_WINDOW)      # Inboard observation window
        mesh.add_quad(bt0, bt1, bt2, bt3, MAT_ISLAND_HIGH) # Bridge roof

        # Tier 3: Funnel Exhaust Stack (Aft: Y = 10 to 48, Z = 44 to 62)
        fx0, fx1 = 74.0, 90.0
        fy0, fy1 = 12.0, 48.0
        fb0 = mesh.add_vertex(fx0, fy0, 44.0)
        fb1 = mesh.add_vertex(fx1, fy0, 44.0)
        fb2 = mesh.add_vertex(fx1, fy1, 44.0)
        fb3 = mesh.add_vertex(fx0, fy1, 44.0)

        ft0 = mesh.add_vertex(fx0 + 1, fy0 + 2, 62.0)
        ft1 = mesh.add_vertex(fx1 - 1, fy0 + 2, 62.0)
        ft2 = mesh.add_vertex(fx1 - 1, fy1 - 3, 62.0)
        ft3 = mesh.add_vertex(fx0 + 1, fy1 - 3, 62.0)

        mesh.add_quad(fb0, fb1, ft1, ft0, MAT_FUNNEL)
        mesh.add_quad(fb1, fb2, ft2, ft1, MAT_FUNNEL)
        mesh.add_quad(fb2, fb3, ft3, ft2, MAT_FUNNEL)
        mesh.add_quad(fb3, fb0, ft0, ft3, MAT_FUNNEL)
        mesh.add_quad(ft0, ft1, ft2, ft3, MAT_DECK_DARK) # Funnel black top grill

        # Tier 4: Radar Lattice Mast (Z = 58 to 82)
        mx, my = 82.0, 54.0
        m_bot = mesh.add_vertex(mx, my, 58.0)
        m_top = mesh.add_vertex(mx, my, 82.0)
        y_l   = mesh.add_vertex(mx - 10.0, my, 74.0)
        y_r   = mesh.add_vertex(mx + 10.0, my, 74.0)

        mesh.add_tri(m_bot, y_l, m_top, MAT_MAST)
        mesh.add_tri(m_bot, m_top, y_r, MAT_MAST)
        mesh.add_tri(m_bot, y_r, m_top, MAT_MAST)
        mesh.add_tri(m_bot, m_top, y_l, MAT_MAST)

    else:
        # Soviet Krasny Luch Airfield Control Bunker Tower
        cx0, cx1 = 70.0, 94.0
        cy0, cy1 = 20.0, 75.0
        cb0 = mesh.add_vertex(cx0, cy0, 26.5)
        cb1 = mesh.add_vertex(cx1, cy0, 26.5)
        cb2 = mesh.add_vertex(cx1, cy1, 26.5)
        cb3 = mesh.add_vertex(cx0, cy1, 26.5)

        ct0 = mesh.add_vertex(cx0, cy0, 48.0)
        ct1 = mesh.add_vertex(cx1, cy0, 48.0)
        ct2 = mesh.add_vertex(cx1, cy1, 48.0)
        ct3 = mesh.add_vertex(cx0, cy1, 48.0)

        mesh.add_quad(cb0, cb1, ct1, ct0, MAT_ISLAND)
        mesh.add_quad(cb1, cb2, ct2, ct1, MAT_ISLAND)
        mesh.add_quad(cb2, cb3, ct3, ct2, MAT_ISLAND)
        mesh.add_quad(cb3, cb0, ct0, ct3, MAT_ISLAND)
        mesh.add_quad(ct0, ct1, ct2, ct3, MAT_ISLAND_HIGH)

        # Glass observation strip
        cg0 = mesh.add_vertex(cx0 + 2, cy1 - 2, 40.0)
        cg1 = mesh.add_vertex(cx1 - 2, cy1 - 2, 40.0)
        cg2 = mesh.add_vertex(cx1 - 2, cy1 - 2, 46.0)
        cg3 = mesh.add_vertex(cx0 + 2, cy1 - 2, 46.0)
        mesh.add_quad(cg0, cg1, cg2, cg3, MAT_WINDOW)

    return mesh


# -----------------------------------------------------------------------------
# PALETTES
# -----------------------------------------------------------------------------
PALETTES = {
    "usa": {
        MAT_HULL:        {"base": (64, 76, 92),    "ink": (24, 30, 38)},
        MAT_DECK:        {"base": (168, 134, 96),  "ink": (90, 68, 46)},   # Teak wood
        MAT_DECK_DARK:   {"base": (96, 76, 54),    "ink": (48, 38, 28)},
        MAT_ISLAND:      {"base": (72, 84, 100),   "ink": (28, 34, 42)},
        MAT_ISLAND_HIGH: {"base": (92, 106, 124),  "ink": (38, 46, 56)},
        MAT_WINDOW:      {"base": (120, 210, 248), "ink": (30, 75, 110)},
        MAT_FUNNEL:      {"base": (52, 62, 74),    "ink": (22, 26, 32)},
        MAT_MAST:        {"base": (36, 44, 52),    "ink": (18, 22, 28)},
        MAT_GUN_TUB:     {"base": (56, 68, 82),    "ink": (24, 30, 38)},
        MAT_CATWALK:     {"base": (48, 58, 70),    "ink": (20, 24, 30)},
    },
    "japan": {
        MAT_HULL:        {"base": (68, 72, 78),    "ink": (26, 28, 32)},   # Kure Grey
        MAT_DECK:        {"base": (156, 124, 88),  "ink": (84, 62, 42)},   # Cedar wood
        MAT_DECK_DARK:   {"base": (88, 68, 48),    "ink": (44, 34, 24)},
        MAT_ISLAND:      {"base": (74, 78, 84),    "ink": (30, 32, 36)},
        MAT_ISLAND_HIGH: {"base": (94, 100, 108),  "ink": (40, 44, 50)},
        MAT_WINDOW:      {"base": (120, 210, 248), "ink": (30, 75, 110)},
        MAT_FUNNEL:      {"base": (56, 60, 66),    "ink": (24, 26, 30)},
        MAT_MAST:        {"base": (38, 42, 46),    "ink": (18, 20, 24)},
        MAT_GUN_TUB:     {"base": (60, 64, 70),    "ink": (26, 28, 32)},
        MAT_CATWALK:     {"base": (50, 54, 60),    "ink": (22, 24, 28)},
    },
    "britain": {
        MAT_HULL:        {"base": (62, 74, 88),    "ink": (24, 30, 38)},
        MAT_DECK:        {"base": (92, 104, 118),  "ink": (44, 52, 62)},   # Armored Steel
        MAT_DECK_DARK:   {"base": (58, 66, 76),    "ink": (28, 34, 40)},
        MAT_ISLAND:      {"base": (70, 84, 98),    "ink": (28, 36, 44)},
        MAT_ISLAND_HIGH: {"base": (92, 108, 126),  "ink": (38, 48, 58)},
        MAT_WINDOW:      {"base": (120, 210, 248), "ink": (30, 75, 110)},
        MAT_FUNNEL:      {"base": (50, 62, 74),    "ink": (22, 28, 34)},
        MAT_MAST:        {"base": (36, 44, 54),    "ink": (18, 22, 28)},
        MAT_GUN_TUB:     {"base": (56, 68, 80),    "ink": (24, 30, 36)},
        MAT_CATWALK:     {"base": (46, 56, 68),    "ink": (20, 24, 30)},
    },
    "germany": {
        MAT_HULL:        {"base": (56, 62, 70),    "ink": (22, 26, 30)},
        MAT_DECK:        {"base": (84, 92, 102),   "ink": (38, 44, 50)},
        MAT_DECK_DARK:   {"base": (50, 56, 64),    "ink": (24, 28, 34)},
        MAT_ISLAND:      {"base": (64, 72, 80),    "ink": (26, 30, 36)},
        MAT_ISLAND_HIGH: {"base": (84, 94, 106),   "ink": (36, 42, 48)},
        MAT_WINDOW:      {"base": (120, 210, 248), "ink": (30, 75, 110)},
        MAT_FUNNEL:      {"base": (46, 52, 60),    "ink": (20, 24, 28)},
        MAT_MAST:        {"base": (32, 38, 44),    "ink": (16, 20, 24)},
        MAT_GUN_TUB:     {"base": (50, 56, 64),    "ink": (22, 26, 30)},
        MAT_CATWALK:     {"base": (42, 48, 54),    "ink": (18, 22, 26)},
    },
    "canada": {
        MAT_HULL:        {"base": (64, 76, 90),    "ink": (24, 30, 38)},
        MAT_DECK:        {"base": (90, 102, 116),  "ink": (42, 50, 60)},
        MAT_DECK_DARK:   {"base": (56, 64, 74),    "ink": (26, 32, 38)},
        MAT_ISLAND:      {"base": (72, 84, 98),    "ink": (28, 36, 44)},
        MAT_ISLAND_HIGH: {"base": (94, 108, 126),  "ink": (38, 48, 58)},
        MAT_WINDOW:      {"base": (120, 210, 248), "ink": (30, 75, 110)},
        MAT_FUNNEL:      {"base": (52, 62, 72),    "ink": (22, 28, 34)},
        MAT_MAST:        {"base": (36, 44, 52),    "ink": (18, 22, 28)},
        MAT_GUN_TUB:     {"base": (56, 68, 80),    "ink": (24, 30, 36)},
        MAT_CATWALK:     {"base": (46, 56, 66),    "ink": (20, 24, 30)},
    },
    "soviet": {
        MAT_HULL:        {"base": (84, 82, 78),    "ink": (34, 32, 30)},
        MAT_DECK:        {"base": (132, 130, 124), "ink": (68, 66, 62)},  # Military Concrete
        MAT_DECK_DARK:   {"base": (94, 92, 88),    "ink": (46, 44, 42)},
        MAT_ISLAND:      {"base": (90, 88, 84),    "ink": (38, 36, 34)},
        MAT_ISLAND_HIGH: {"base": (115, 112, 106), "ink": (48, 46, 44)},
        MAT_WINDOW:      {"base": (120, 210, 248), "ink": (30, 75, 110)},
        MAT_FUNNEL:      {"base": (66, 64, 60),    "ink": (28, 26, 24)},
        MAT_MAST:        {"base": (48, 46, 44),    "ink": (22, 20, 18)},
        MAT_GUN_TUB:     {"base": (76, 74, 70),    "ink": (32, 30, 28)},
        MAT_CATWALK:     {"base": (64, 62, 58),    "ink": (26, 24, 22)},
    }
}


def render_carrier_3d(nation="usa"):
    mesh = build_carrier_mesh(nation)
    palette = PALETTES.get(nation, PALETTES["usa"])

    # Sunlight vector: coming from Top-Left, high angle
    l_dir = np.array([-0.35, 0.45, 0.82])
    l_dir /= np.linalg.norm(l_dir)

    cx, cy = WIDTH / 2.0, HEIGHT / 2.0
    scale = 1.0

    V_raw = np.array(mesh.vertices)
    V_screen = np.zeros((len(V_raw), 3))
    V_screen[:, 0] = cx + V_raw[:, 0] * scale
    V_screen[:, 1] = cy - V_raw[:, 1] * scale
    V_screen[:, 2] = V_raw[:, 2]

    img_arr = np.zeros((HEIGHT, WIDTH, 4), dtype=np.uint8)
    z_buffer = np.full((HEIGHT, WIDTH), -1e9, dtype=np.float32)
    id_buffer = np.zeros((HEIGHT, WIDTH), dtype=np.int32)

    # Sort faces by depth
    face_depths = []
    for f_idx, (v0, v1, v2, mat_id) in enumerate(mesh.faces):
        avg_z = (V_screen[v0, 2] + V_screen[v1, 2] + V_screen[v2, 2]) / 3.0
        face_depths.append((avg_z, f_idx))
    face_depths.sort(key=lambda x: x[0])

    for _, f_idx in face_depths:
        v0, v1, v2, mat_id = mesh.faces[f_idx]
        p0, p1, p2 = V_screen[v0], V_screen[v1], V_screen[v2]

        # 3D Normal
        e1 = V_raw[v1] - V_raw[v0]
        e2 = V_raw[v2] - V_raw[v0]
        norm = np.cross(e1, e2)
        norm_len = np.linalg.norm(norm)
        if norm_len < 1e-6:
            continue
        norm = norm / norm_len

        diff = max(0.0, float(np.dot(norm, l_dir)))

        mat_cfg = palette.get(mat_id, palette[MAT_HULL])
        base_col = np.array(mat_cfg["base"], dtype=np.float32)

        # 3-Tone Cel-Shading Ramp
        if diff > 0.65:
            shade = 1.15
        elif diff > 0.28:
            shade = 1.00
        else:
            shade = 0.80

        col = tuple(np.clip(base_col * shade, 0, 255).astype(np.uint8))

        min_x = max(0, int(math.floor(min(p0[0], p1[0], p2[0]))))
        max_x = min(WIDTH - 1, int(math.ceil(max(p0[0], p1[0], p2[0]))))
        min_y = max(0, int(math.floor(min(p0[1], p1[1], p2[1]))))
        max_y = min(HEIGHT - 1, int(math.ceil(max(p0[1], p1[1], p2[1]))))
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

    # Dynamic Inking & Edge Contours
    alpha_mask = img_arr[..., 3] > 0
    edge_map = np.zeros((HEIGHT, WIDTH), dtype=bool)
    for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        shifted_a = np.roll(alpha_mask, (dy, dx), axis=(0, 1))
        shifted_id = np.roll(id_buffer, (dy, dx), axis=(0, 1))
        edge_map |= alpha_mask & (~shifted_a) # Outer silhouette
        edge_map |= alpha_mask & shifted_a & (id_buffer != shifted_id) # Interior creases

    # Dark ink outline
    img_arr[edge_map] = np.array([20, 24, 30, 255], dtype=np.uint8)
    base_img = Image.fromarray(img_arr, mode="RGBA")
    draw = ImageDraw.Draw(base_img)

    # -------------------------------------------------------------------------
    # AUTHENTIC FLIGHT DECK DETAILS & NATIONAL LIVERIES
    # -------------------------------------------------------------------------
    if nation == "usa":
        # USS Enterprise (CV-6)
        # Teak plank lines across flight deck
        for py in range(int(cy - 290), int(cy + 290), 5):
            draw.line([(cx - 78, py), (cx + 64, py)], fill=(138, 108, 76, 95), width=1)
        # White dashed centerline
        for py in range(int(cy - 300), int(cy + 300), 24):
            draw.rectangle([cx - 3, py, cx + 3, py + 14], fill=(245, 245, 250, 240))
        # Bold "6" numeral at forward flight deck
        fwd_y = int(cy - 210)
        draw.rectangle([cx - 26, fwd_y - 38, cx + 26, fwd_y - 24], fill=(245, 245, 250, 245))
        draw.rectangle([cx - 26, fwd_y - 24, cx - 12, fwd_y + 38], fill=(245, 245, 250, 245))
        draw.rectangle([cx - 26, fwd_y + 24, cx + 26, fwd_y + 38], fill=(245, 245, 250, 245))
        draw.rectangle([cx + 12, fwd_y, cx + 26, fwd_y + 38], fill=(245, 245, 250, 245))
        draw.rectangle([cx - 26, fwd_y, cx + 26, fwd_y + 14], fill=(245, 245, 250, 245))
        # 4 Steel Arresting Cables across stern
        for wy in range(int(cy + 175), int(cy + 265), 22):
            draw.line([(cx - 82, wy), (cx + 80, wy)], fill=(24, 28, 34, 245), width=2)
            draw.rectangle([cx - 86, wy - 3, cx - 82, wy + 3], fill=(230, 190, 40))
            draw.rectangle([cx + 80, wy - 3, cx + 84, wy + 3], fill=(230, 190, 40))

    elif nation == "japan":
        # IJN Akagi / Hiryu
        for py in range(int(cy - 290), int(cy + 290), 5):
            draw.line([(cx - 78, py), (cx + 64, py)], fill=(124, 96, 68, 90), width=1)
        # Giant Red Hinomaru (Rising Sun Circle) on Forward Deck
        h_cy = int(cy - 190)
        h_r = 46
        draw.ellipse([cx - h_r - 7, h_cy - h_r - 7, cx + h_r + 7, h_cy + h_r + 7], fill=(245, 245, 250, 230))
        draw.ellipse([cx - h_r, h_cy - h_r, cx + h_r, h_cy + h_r], fill=(210, 28, 28, 245))
        # Stern red & white approach stripes
        for ay in range(int(cy + 210), int(cy + 285), 18):
            draw.polygon([(cx - 50, ay), (cx, ay - 14), (cx + 50, ay), (cx + 50, ay + 6), (cx, ay - 8), (cx - 50, ay + 6)], fill=(240, 240, 245, 230))
        for wy in range(int(cy + 165), int(cy + 235), 18):
            draw.line([(cx - 80, wy), (cx + 78, wy)], fill=(24, 26, 32, 245), width=2)

    elif nation == "britain":
        # HMS Ark Royal (R09)
        # Admiralty Splinter Camo Bands across armored flight deck
        for py in range(int(cy - 260), int(cy + 260), 85):
            draw.polygon([(cx - 85, py), (cx + 80, py + 45), (cx + 80, py + 90), (cx - 85, py + 45)], fill=(54, 66, 80, 130))
        # Bold "R09" at forward deck
        draw.rectangle([cx - 48, cy - 235, cx - 14, cy - 170], fill=(245, 245, 250, 235))
        draw.rectangle([cx - 40, cy - 225, cx - 22, cy - 180], fill=(92, 104, 118, 255))
        draw.rectangle([cx - 4, cy - 235, cx + 30, cy - 170], fill=(245, 245, 250, 235))
        draw.rectangle([cx + 4, cy - 225, cx + 22, cy - 180], fill=(92, 104, 118, 255))
        for py in range(int(cy - 300), int(cy + 300), 24):
            draw.rectangle([cx - 3, py, cx + 3, py + 14], fill=(245, 245, 250, 230))
        for wy in range(int(cy + 175), int(cy + 265), 22):
            draw.line([(cx - 82, wy), (cx + 80, wy)], fill=(22, 26, 32, 245), width=2)

    elif nation == "germany":
        # KMS Graf Zeppelin
        # Catapult tracks
        draw.line([(cx - 32, cy - 300), (cx - 32, cy - 50)], fill=(28, 32, 38, 255), width=3)
        draw.line([(cx + 32, cy - 300), (cx + 32, cy - 50)], fill=(28, 32, 38, 255), width=3)
        for sy in range(int(cy - 200), int(cy + 220), 105):
            draw.polygon([(cx - 85, sy), (cx, sy - 38), (cx + 80, sy), (cx + 80, sy + 28), (cx, sy - 10), (cx - 85, sy + 28)], fill=(34, 40, 48, 170))
            draw.polygon([(cx - 85, sy + 28), (cx, sy - 10), (cx + 80, sy + 28), (cx + 80, sy + 44), (cx, sy + 6), (cx - 85, sy + 44)], fill=(235, 240, 245, 185))
        for wy in range(int(cy + 175), int(cy + 260), 20):
            draw.line([(cx - 82, wy), (cx + 80, wy)], fill=(20, 24, 28, 245), width=2)

    elif nation == "canada":
        # HMCS Warrior (R31)
        for py in range(int(cy - 300), int(cy + 300), 24):
            draw.rectangle([cx - 3, py, cx + 3, py + 14], fill=(245, 245, 250, 230))
        fwd_y = int(cy - 210)
        draw.rectangle([cx - 42, fwd_y - 30, cx - 8, fwd_y + 30], fill=(245, 245, 250, 240))
        draw.rectangle([cx - 34, fwd_y - 20, cx - 16, fwd_y + 20], fill=(90, 102, 116, 255))
        draw.rectangle([cx + 6, fwd_y - 30, cx + 22, fwd_y + 30], fill=(245, 245, 250, 240))
        # Canadian Red Maple Leaf
        m_cy = int(cy)
        m_r = 40
        draw.ellipse([cx - m_r - 6, m_cy - m_r - 6, cx + m_r + 6, m_cy + m_r + 6], fill=(245, 245, 250, 230))
        draw.ellipse([cx - m_r, m_cy - m_r, cx + m_r, m_cy + m_r], fill=(215, 28, 28, 245))
        for wy in range(int(cy + 175), int(cy + 265), 22):
            draw.line([(cx - 82, wy), (cx + 80, wy)], fill=(22, 26, 34, 245), width=2)

    elif nation == "soviet":
        # Krasny Luch Military Concrete Runway
        for py in range(int(cy - 300), int(cy + 300), 30):
            draw.line([(cx - 82, py), (cx + 82, py)], fill=(75, 72, 68, 140), width=2)
        for py in range(int(cy - 290), int(cy + 290), 24):
            draw.rectangle([cx - 4, py, cx + 4, py + 14], fill=(245, 215, 35, 240))
        s_cy = int(cy)
        star_r = 38
        draw.ellipse([cx - star_r - 8, s_cy - star_r - 8, cx + star_r + 8, s_cy + star_r + 8], fill=(245, 245, 250, 230))
        star_pts = []
        for i in range(10):
            r = star_r if i % 2 == 0 else star_r * 0.40
            ang = -math.pi / 2.0 + i * math.pi / 5.0
            star_pts.append((cx + r * math.cos(ang), s_cy + r * math.sin(ang)))
        draw.polygon(star_pts, fill=(215, 28, 28), outline=(245, 215, 35), width=2)

    # -------------------------------------------------------------------------
    # WATER DEPTH SHADOW
    # -------------------------------------------------------------------------
    final_canvas = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    shadow_layer = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow_layer)

    s_draw.polygon([
        (cx - 105, cy - 300),
        (cx + 90, cy - 300),
        (cx + 105, cy + 330),
        (cx - 95, cy + 330)
    ], fill=(6, 14, 24, 125))
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(8))

    final_canvas = Image.alpha_composite(final_canvas, shadow_layer)
    final_canvas = Image.alpha_composite(final_canvas, base_img)

    return final_canvas


def main():
    sprites_dir = Path("games/skyace/sprites")
    sprites_dir.mkdir(parents=True, exist_ok=True)
    art_dir = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62")

    factions = {
        "p38": ("carrier_p38", "usa"),
        "zero": ("carrier_zero", "japan"),
        "spitfire": ("carrier_spitfire", "britain"),
        "bf109": ("carrier_bf109", "germany"),
        "mosquito": ("carrier_mosquito", "canada"),
        "yak3": ("carrier_yak3", "soviet"),
        "folgore": ("carrier_folgore", "germany"),
        "d520": ("carrier_d520", "britain"),
        "pzl11": ("carrier_pzl11", "britain"),
        "avia": ("carrier_avia", "soviet"),
    }

    print("[Sky Ace] Rendering true 3D cel-shaded aircraft carriers for all nations...")
    for plane_key, (fname, nation) in factions.items():
        carrier_img = render_carrier_3d(nation)
        out_spr = sprites_dir / f"{fname}.png"
        carrier_img.save(out_spr)
        try:
            carrier_img.save(art_dir / f"{fname}.png")
        except Exception:
            pass
        print(f"✓ Rendered 3D cel-shaded carrier: {fname}.png ({WIDTH}x{HEIGHT})")

    # Also update default carrier_deck.png
    default_img = render_carrier_3d("usa")
    default_img.save(sprites_dir / "carrier_deck.png")
    print("✓ Updated default carrier_deck.png")

if __name__ == "__main__":
    main()

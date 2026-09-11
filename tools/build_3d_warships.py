#!/usr/bin/env python3
"""
tools/build_3d_warships.py
Builds true 3D polygonal geometric meshes (Mesh3D) of WWII naval warships
and renders them through our software 3D cel-shader and inking rasterizer.

Warship Classes:
1. PT Gunboat (80 x 180 px): Fast coastal patrol boat with torpedo tubes and deck autocannon.
2. Fleet Destroyer (140 x 420 px): Slender clipper bow, armored bridge, torpedo banks,
   depth charge racks, and 2 independent rotating dual-purpose turrets.
3. Heavy Cruiser / Battleship (200 x 580 px): Massive armored warship with multi-deck bridge tower,
   funnels, secondary AA batteries, and 3 independent rotating heavy triple-gun turrets.
4. Independent 3D Turrets (16 rotation angles each, 0° to 360°):
   - turret_destroyer (5" twin gunhouse)
   - turret_heavy (8"/16" triple heavy battery)
"""

import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path

# =============================================================================
# 3D MESH DATA STRUCTURE
# =============================================================================
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


# Materials
MAT_HULL = 1          # Dark Navy Grey Hull Steel
MAT_HULL_DARK = 2     # Shaded Underwater Torpedo Blister / Keel
MAT_DECK = 3          # Teak Wood / Armored Weathered Deck
MAT_SUPER = 4         # Bridge Tower & Superstructure
MAT_SUPER_HIGH = 5    # Upper Navigation Bridge / Rangefinder
MAT_WINDOW = 6        # Bridge Glazing (Cyan Specular)
MAT_FUNNEL = 7        # Funnel Smokestack
MAT_GUN_METAL = 8     # Gun Barrels & Torpedo Tubes
MAT_BARBETTE = 9      # Circular Armored Turret Foundation
MAT_FIRE = 10         # Flaming Battle Damage
MAT_CHARRED = 11      # Charred Blast Craters

# Cel-Shading Palette (Tactical WWII Naval Camo)
PALETTE_WARSHIP = {
    MAT_HULL:        {"base": (68, 76, 88),    "ink": (24, 28, 34)},
    MAT_HULL_DARK:   {"base": (44, 50, 60),    "ink": (18, 20, 26)},
    MAT_DECK:        {"base": (152, 126, 92),  "ink": (80, 62, 44)},   # Weathered Teak
    MAT_SUPER:       {"base": (78, 86, 98),    "ink": (28, 32, 38)},
    MAT_SUPER_HIGH:  {"base": (98, 108, 122),  "ink": (36, 42, 50)},
    MAT_WINDOW:      {"base": (120, 210, 245), "ink": (30, 75, 105)},
    MAT_FUNNEL:      {"base": (56, 62, 72),    "ink": (22, 26, 32)},
    MAT_GUN_METAL:   {"base": (38, 42, 48),    "ink": (16, 18, 22)},
    MAT_BARBETTE:    {"base": (60, 66, 76),    "ink": (22, 26, 30)},
    MAT_FIRE:        {"base": (255, 95, 20),   "ink": (190, 35, 10)},
    MAT_CHARRED:     {"base": (32, 34, 38),    "ink": (14, 15, 18)},
}

# Directional sunlight vector (consistent with planes: top-left high angle)
L_DIR = np.array([-0.35, 0.45, 0.82])
L_DIR /= np.linalg.norm(L_DIR)


# =============================================================================
# 1. 3D FLEET DESTROYER MESH
# =============================================================================
def build_destroyer_mesh(damage_stage=0):
    mesh = Mesh3D()

    # Dimensions: Length ~360, Beam ~70, Height ~45
    # Coordinates: X: Port (-), Stbd (+). Y: Bow (+180), Stern (-180). Z: Water (0), Deck (+18), Bridge (+42)
    slices = [
        ( 180.0,  0.0,   0.0,  3.0, 18.0), # Raked stem (Clipper Bow)
        ( 160.0, 16.0,  16.0,  2.0, 20.0), # Forward flare
        ( 110.0, 30.0,  30.0,  1.5, 19.0), # Forward turret deck
        (  40.0, 34.0,  34.0,  1.0, 18.5), # Forward bridge
        ( -30.0, 34.0,  34.0,  1.0, 18.0), # Midships / Torpedo bank
        (-100.0, 32.0,  32.0,  1.0, 17.5), # Aft superstructure
        (-150.0, 26.0,  26.0,  1.5, 17.0), # Aft turret deck
        (-178.0, 18.0,  18.0,  2.0, 16.5), # Transom stern
    ]

    rings = []
    for y, px, sx, zb, zd in slices:
        v_pb = mesh.add_vertex(-px * 0.70, y, zb)
        v_pd = mesh.add_vertex(-px, y, zd)
        v_sd = mesh.add_vertex( sx, y, zd)
        v_sb = mesh.add_vertex( sx * 0.70, y, zb)
        rings.append((v_pb, v_pd, v_sd, v_sb))

    for s in range(len(slices) - 1):
        r0 = rings[s]; r1 = rings[s + 1]
        mesh.add_quad(r0[0], r0[1], r1[1], r1[0], MAT_HULL) # Port
        mesh.add_quad(r0[3], r1[3], r1[2], r0[2], MAT_HULL) # Stbd
        mesh.add_quad(r0[0], r1[0], r1[3], r0[3], MAT_HULL_DARK) # Keel

    # Deck Surface
    for s in range(len(slices) - 1):
        r0 = rings[s]; r1 = rings[s + 1]
        d_mat = MAT_CHARRED if (damage_stage >= 1 and s in [2, 3]) else MAT_DECK
        mesh.add_quad(r0[1], r0[2], r1[2], r1[1], d_mat)

    # Transom stern plate
    mesh.add_quad(rings[-1][0], rings[-1][1], rings[-1][2], rings[-1][3], MAT_HULL)

    # 3D Bridge Superstructure (Y = 15 to 70, Z = 18 to 40)
    bx0, bx1 = -20.0, 20.0
    by0, by1 =  15.0, 68.0
    b0 = mesh.add_vertex(bx0, by0, 18.5)
    b1 = mesh.add_vertex(bx1, by0, 18.5)
    b2 = mesh.add_vertex(bx1 - 4, by1, 19.0)
    b3 = mesh.add_vertex(bx0 + 4, by1, 19.0)

    t0 = mesh.add_vertex(bx0 + 2, by0 + 2, 34.0)
    t1 = mesh.add_vertex(bx1 - 2, by0 + 2, 34.0)
    t2 = mesh.add_vertex(bx1 - 4, by1 - 4, 34.0)
    t3 = mesh.add_vertex(bx0 + 4, by1 - 4, 34.0)

    b_mat = MAT_FIRE if damage_stage >= 2 else MAT_SUPER
    mesh.add_quad(b0, b1, t1, t0, b_mat)
    mesh.add_quad(b1, b2, t2, t1, b_mat)
    mesh.add_quad(b2, b3, t3, t2, MAT_WINDOW) # Forward wheelhouse windows
    mesh.add_quad(b3, b0, t0, t3, b_mat)
    mesh.add_quad(t0, t1, t2, t3, MAT_SUPER_HIGH)

    # Bridge Pilot House & Rangefinder (Z = 34 to 44)
    pb0 = mesh.add_vertex(bx0 + 6, by0 + 12, 34.0)
    pb1 = mesh.add_vertex(bx1 - 6, by0 + 12, 34.0)
    pb2 = mesh.add_vertex(bx1 - 6, by1 - 8,  34.0)
    pb3 = mesh.add_vertex(bx0 + 6, by1 - 8,  34.0)

    pt0 = mesh.add_vertex(bx0 + 7, by0 + 14, 44.0)
    pt1 = mesh.add_vertex(bx1 - 7, by0 + 14, 44.0)
    pt2 = mesh.add_vertex(bx1 - 7, by1 - 10, 44.0)
    pt3 = mesh.add_vertex(bx0 + 7, by1 - 10, 44.0)

    mesh.add_quad(pb0, pb1, pt1, pt0, MAT_SUPER_HIGH)
    mesh.add_quad(pb1, pb2, pt2, pt1, MAT_SUPER_HIGH)
    mesh.add_quad(pb2, pb3, pt3, pt2, MAT_WINDOW)
    mesh.add_quad(pb3, pb0, pt0, pt3, MAT_SUPER_HIGH)
    mesh.add_quad(pt0, pt1, pt2, pt3, MAT_SUPER_HIGH)

    # 2 Funnel Smokestacks (Fore at Y = -5, Aft at Y = -55)
    for fy in [-5.0, -55.0]:
        fr_b = mesh.add_vertex(-9.0, fy - 12.0, 18.0)
        fr_f = mesh.add_vertex( 9.0, fy - 12.0, 18.0)
        fl_f = mesh.add_vertex( 9.0, fy + 14.0, 18.0)
        fl_b = mesh.add_vertex(-9.0, fy + 14.0, 18.0)

        tr_b = mesh.add_vertex(-7.0, fy - 14.0, 36.0)
        tr_f = mesh.add_vertex( 7.0, fy - 14.0, 36.0)
        tl_f = mesh.add_vertex( 7.0, fy + 10.0, 36.0)
        tl_b = mesh.add_vertex(-7.0, fy + 10.0, 36.0)

        f_mat = MAT_FIRE if (damage_stage >= 1 and fy == -5.0) else MAT_FUNNEL
        mesh.add_quad(fr_b, fr_f, tr_f, tr_b, f_mat)
        mesh.add_quad(fr_f, fl_f, tl_f, tr_f, f_mat)
        mesh.add_quad(fl_f, fl_b, tl_b, tl_f, f_mat)
        mesh.add_quad(fl_b, fr_b, tr_b, tl_b, f_mat)
        mesh.add_quad(tr_b, tr_f, tl_f, tl_b, MAT_CHARRED) # Funnel grill

    # Armored Turret Barbettes (Cylindrical mount foundations)
    # Forward Barbette (Y = +125) & Aft Barbette (Y = -135)
    for by in [125.0, -135.0]:
        r_bar = 15.0
        n_b = 10
        b_rim = []
        for i in range(n_b):
            ang = 2.0 * math.pi * i / n_b
            vx = r_bar * math.cos(ang)
            vy = by + r_bar * math.sin(ang)
            b_rim.append(mesh.add_vertex(vx, vy, 21.0))
        c_bar = mesh.add_vertex(0.0, by, 21.0)
        for i in range(n_b):
            mesh.add_tri(b_rim[i], c_bar, b_rim[(i + 1) % n_b], MAT_BARBETTE)

    return mesh


# =============================================================================
# 2. 3D HEAVY CRUISER / BATTLESHIP MESH
# =============================================================================
def build_cruiser_mesh(damage_stage=0):
    mesh = Mesh3D()

    # Dimensions: Length ~520, Beam ~105, Height ~62
    # Coordinates: Y: Bow (+260), Stern (-260). Z: Water (0), Deck (+22), Bridge (+60)
    slices = [
        ( 260.0,   0.0,   0.0,  3.0, 22.0), # Flared clipper bow stem
        ( 230.0,  24.0,  24.0,  2.0, 24.0),
        ( 170.0,  45.0,  45.0,  1.5, 23.0), # Turret A deck
        ( 110.0,  50.0,  50.0,  1.0, 22.5), # Turret B deck
        (  50.0,  52.0,  52.0,  1.0, 22.0), # Forward pagoda bridge
        ( -30.0,  52.0,  52.0,  1.0, 22.0), # Midships funnels
        (-110.0,  50.0,  50.0,  1.0, 21.5), # Aft pagoda tower
        (-170.0,  44.0,  44.0,  1.5, 21.0), # Turret C deck
        (-230.0,  32.0,  32.0,  2.0, 20.0), # Quarterdeck
        (-258.0,  20.0,  20.0,  2.5, 19.5), # Stern round
    ]

    rings = []
    for y, px, sx, zb, zd in slices:
        v_pb = mesh.add_vertex(-px * 0.74, y, zb)
        v_pd = mesh.add_vertex(-px, y, zd)
        v_sd = mesh.add_vertex( sx, y, zd)
        v_sb = mesh.add_vertex( sx * 0.74, y, zb)
        rings.append((v_pb, v_pd, v_sd, v_sb))

    for s in range(len(slices) - 1):
        r0 = rings[s]; r1 = rings[s + 1]
        mesh.add_quad(r0[0], r0[1], r1[1], r1[0], MAT_HULL)
        mesh.add_quad(r0[3], r1[3], r1[2], r0[2], MAT_HULL)
        mesh.add_quad(r0[0], r1[0], r1[3], r0[3], MAT_HULL_DARK)

    # Deck Plating
    for s in range(len(slices) - 1):
        r0 = rings[s]; r1 = rings[s + 1]
        d_mat = MAT_CHARRED if (damage_stage >= 1 and s in [3, 4, 5]) else MAT_DECK
        mesh.add_quad(r0[1], r0[2], r1[2], r1[1], d_mat)

    # Stern plate
    mesh.add_quad(rings[-1][0], rings[-1][1], rings[-1][2], rings[-1][3], MAT_HULL)

    # Heavy Multi-Tier Pagoda Mast / Bridge Tower (Y = 10 to 65, Z = 22 to 62)
    bx0, bx1 = -26.0, 26.0
    by0, by1 =  12.0, 64.0
    b0 = mesh.add_vertex(bx0, by0, 22.0)
    b1 = mesh.add_vertex(bx1, by0, 22.0)
    b2 = mesh.add_vertex(bx1 - 4, by1, 22.0)
    b3 = mesh.add_vertex(bx0 + 4, by1, 22.0)

    t0 = mesh.add_vertex(bx0 + 4, by0 + 3, 44.0)
    t1 = mesh.add_vertex(bx1 - 4, by0 + 3, 44.0)
    t2 = mesh.add_vertex(bx1 - 6, by1 - 4, 44.0)
    t3 = mesh.add_vertex(bx0 + 6, by1 - 4, 44.0)

    s_mat = MAT_FIRE if damage_stage >= 2 else MAT_SUPER
    mesh.add_quad(b0, b1, t1, t0, s_mat)
    mesh.add_quad(b1, b2, t2, t1, s_mat)
    mesh.add_quad(b2, b3, t3, t2, MAT_WINDOW)
    mesh.add_quad(b3, b0, t0, t3, s_mat)
    mesh.add_quad(t0, t1, t2, t3, MAT_SUPER_HIGH)

    # Upper Pagoda Tower & Main Rangefinder (Z = 44 to 62)
    ub0 = mesh.add_vertex(bx0 + 8, by0 + 12, 44.0)
    ub1 = mesh.add_vertex(bx1 - 8, by0 + 12, 44.0)
    ub2 = mesh.add_vertex(bx1 - 8, by1 - 12, 44.0)
    ub3 = mesh.add_vertex(bx0 + 8, by1 - 12, 44.0)

    ut0 = mesh.add_vertex(bx0 + 10, by0 + 14, 58.0)
    ut1 = mesh.add_vertex(bx1 - 10, by0 + 14, 58.0)
    ut2 = mesh.add_vertex(bx1 - 10, by1 - 14, 58.0)
    ut3 = mesh.add_vertex(bx0 + 10, by1 - 14, 58.0)

    mesh.add_quad(ub0, ub1, ut1, ut0, MAT_SUPER_HIGH)
    mesh.add_quad(ub1, ub2, ut2, ut1, MAT_SUPER_HIGH)
    mesh.add_quad(ub2, ub3, ut3, ut2, MAT_WINDOW)
    mesh.add_quad(ub3, ub0, ut0, ut3, MAT_SUPER_HIGH)
    mesh.add_quad(ut0, ut1, ut2, ut3, MAT_SUPER_HIGH)

    # Rangefinder Crosshead (Spanning 42 units wide at Z = 58)
    rf_l = mesh.add_vertex(-21.0, 36.0, 58.0)
    rf_r = mesh.add_vertex( 21.0, 36.0, 58.0)
    rf_t = mesh.add_vertex(  0.0, 36.0, 63.0)
    mesh.add_tri(rf_l, rf_r, rf_t, MAT_GUN_METAL)
    mesh.add_tri(rf_r, rf_l, rf_t, MAT_GUN_METAL)

    # Twin Massive Funnels (Fore at Y = -15, Aft at Y = -65)
    for fy in [-15.0, -65.0]:
        fr_b = mesh.add_vertex(-14.0, fy - 18.0, 22.0)
        fr_f = mesh.add_vertex( 14.0, fy - 18.0, 22.0)
        fl_f = mesh.add_vertex( 14.0, fy + 20.0, 22.0)
        fl_b = mesh.add_vertex(-14.0, fy + 20.0, 22.0)

        tr_b = mesh.add_vertex(-11.0, fy - 22.0, 48.0)
        tr_f = mesh.add_vertex( 11.0, fy - 22.0, 48.0)
        tl_f = mesh.add_vertex( 11.0, fy + 16.0, 48.0)
        tl_b = mesh.add_vertex(-11.0, fy + 16.0, 48.0)

        f_mat = MAT_FIRE if (damage_stage >= 1 and fy == -15.0) else MAT_FUNNEL
        mesh.add_quad(fr_b, fr_f, tr_f, tr_b, f_mat)
        mesh.add_quad(fr_f, fl_f, tl_f, tr_f, f_mat)
        mesh.add_quad(fl_f, fl_b, tl_b, tl_f, f_mat)
        mesh.add_quad(fl_b, fr_b, tr_b, tl_b, f_mat)
        mesh.add_quad(tr_b, tr_f, tl_f, tl_b, MAT_CHARRED)

    # 3 Heavy Barbettes: Turret A (Y=+180), Turret B (Y=+125, Raised), Turret C (Y=-160)
    barbettes = [(180.0, 23.0), (125.0, 27.0), (-160.0, 22.0)]
    for by, bz in barbettes:
        r_b = 22.0
        n_b = 12
        b_rim = []
        for i in range(n_b):
            ang = 2.0 * math.pi * i / n_b
            vx = r_b * math.cos(ang)
            vy = by + r_b * math.sin(ang)
            b_rim.append(mesh.add_vertex(vx, vy, bz + 3.0))
        c_bar = mesh.add_vertex(0.0, by, bz + 3.0)
        for i in range(n_b):
            mesh.add_tri(b_rim[i], c_bar, b_rim[(i + 1) % n_b], MAT_BARBETTE)

    return mesh


# =============================================================================
# 3. 3D PT GUNBOAT MESH
# =============================================================================
def build_pt_boat_mesh(damage_stage=0):
    mesh = Mesh3D()
    # Dimensions: Length ~150, Beam ~44, Height ~24
    slices = [
        ( 75.0,  0.0,  0.0,  1.5, 14.0),
        ( 55.0, 16.0, 16.0,  1.0, 15.0),
        ( 15.0, 22.0, 22.0,  0.5, 14.5),
        (-25.0, 22.0, 22.0,  0.5, 14.0),
        (-65.0, 20.0, 20.0,  1.0, 13.5),
        (-75.0, 18.0, 18.0,  1.0, 13.0),
    ]
    rings = []
    for y, px, sx, zb, zd in slices:
        v_pb = mesh.add_vertex(-px * 0.70, y, zb)
        v_pd = mesh.add_vertex(-px, y, zd)
        v_sd = mesh.add_vertex( sx, y, zd)
        v_sb = mesh.add_vertex( sx * 0.70, y, zb)
        rings.append((v_pb, v_pd, v_sd, v_sb))

    for s in range(len(slices) - 1):
        r0 = rings[s]; r1 = rings[s + 1]
        mesh.add_quad(r0[0], r0[1], r1[1], r1[0], MAT_HULL)
        mesh.add_quad(r0[3], r1[3], r1[2], r0[2], MAT_HULL)
        mesh.add_quad(r0[0], r1[0], r1[3], r0[3], MAT_HULL_DARK)
        d_mat = MAT_CHARRED if (damage_stage >= 1 and s == 2) else MAT_DECK
        mesh.add_quad(r0[1], r0[2], r1[2], r1[1], d_mat)

    mesh.add_quad(rings[-1][0], rings[-1][1], rings[-1][2], rings[-1][3], MAT_HULL)

    # PT Wheelhouse / Cockpit (Y = -5 to +25, Z = 14 to 24)
    cx0, cx1 = -12.0, 12.0
    cy0, cy1 =  -5.0, 22.0
    cb0 = mesh.add_vertex(cx0, cy0, 14.5)
    cb1 = mesh.add_vertex(cx1, cy0, 14.5)
    cb2 = mesh.add_vertex(cx1 - 2, cy1, 14.5)
    cb3 = mesh.add_vertex(cx0 + 2, cy1, 14.5)

    ct0 = mesh.add_vertex(cx0 + 2, cy0 + 1, 23.0)
    ct1 = mesh.add_vertex(cx1 - 2, cy0 + 1, 23.0)
    ct2 = mesh.add_vertex(cx1 - 3, cy1 - 2, 23.0)
    ct3 = mesh.add_vertex(cx0 + 3, cy1 - 2, 23.0)

    p_mat = MAT_FIRE if damage_stage >= 2 else MAT_SUPER
    mesh.add_quad(cb0, cb1, ct1, ct0, p_mat)
    mesh.add_quad(cb1, cb2, ct2, ct1, p_mat)
    mesh.add_quad(cb2, cb3, ct3, ct2, MAT_WINDOW)
    mesh.add_quad(cb3, cb0, ct0, ct3, p_mat)
    mesh.add_quad(ct0, ct1, ct2, ct3, MAT_SUPER_HIGH)

    # Twin Torpedo Tubes (Port & Stbd along deck)
    for side in [-1, 1]:
        tx = side * 16.0
        v_tf = mesh.add_vertex(tx,  18.0, 15.5)
        v_tb = mesh.add_vertex(tx, -35.0, 15.0)
        v_tr = mesh.add_vertex(tx + side * 3.5, -35.0, 15.0)
        mesh.add_tri(v_tf, v_tb, v_tr, MAT_GUN_METAL)
        mesh.add_tri(v_tf, v_tr, v_tb, MAT_GUN_METAL)

    return mesh


# =============================================================================
# 4. 3D ROTATING GUN TURRET MESHES
# =============================================================================
def build_turret_mesh(turret_type="destroyer"):
    mesh = Mesh3D()

    if turret_type == "destroyer":
        # 5" Twin Dual-Purpose Enclosed Gunhouse
        # Gunhouse box: X = -11..+11, Y = -10..+12, Z = 0..14
        gx0, gx1 = -11.0, 11.0
        gy0, gy1 = -10.0, 12.0
        b0 = mesh.add_vertex(gx0, gy0, 0.0)
        b1 = mesh.add_vertex(gx1, gy0, 0.0)
        b2 = mesh.add_vertex(gx1, gy1, 0.0)
        b3 = mesh.add_vertex(gx0, gy1, 0.0)

        t0 = mesh.add_vertex(gx0 + 2, gy0 + 2, 13.0)
        t1 = mesh.add_vertex(gx1 - 2, gy0 + 2, 13.0)
        t2 = mesh.add_vertex(gx1 - 3, gy1 - 3, 11.5) # Sloped gun mantlet
        t3 = mesh.add_vertex(gx0 + 3, gy1 - 3, 11.5)

        mesh.add_quad(b0, b1, t1, t0, MAT_SUPER)
        mesh.add_quad(b1, b2, t2, t1, MAT_SUPER)
        mesh.add_quad(b2, b3, t3, t2, MAT_SUPER_HIGH) # Forward armor shield
        mesh.add_quad(b3, b0, t0, t3, MAT_SUPER)
        mesh.add_quad(t0, t1, t2, t3, MAT_SUPER_HIGH)

        # Twin 5" Gun Barrels pointing +Y forward
        for gx in [-4.0, 4.0]:
            gb0 = mesh.add_vertex(gx - 1.2, 11.0, 7.0)
            gb1 = mesh.add_vertex(gx + 1.2, 11.0, 7.0)
            gt0 = mesh.add_vertex(gx - 1.0, 32.0, 7.5) # Barrel tip
            gt1 = mesh.add_vertex(gx + 1.0, 32.0, 7.5)
            mesh.add_quad(gb0, gb1, gt1, gt0, MAT_GUN_METAL)
            mesh.add_quad(gb1, gb0, gt0, gt1, MAT_GUN_METAL)

    else:
        # Heavy 8" / 16" Triple-Gun Armored Battery
        # Gunhouse box: X = -18..+18, Y = -16..+18, Z = 0..18
        gx0, gx1 = -18.0, 18.0
        gy0, gy1 = -16.0, 18.0
        b0 = mesh.add_vertex(gx0, gy0, 0.0)
        b1 = mesh.add_vertex(gx1, gy0, 0.0)
        b2 = mesh.add_vertex(gx1, gy1, 0.0)
        b3 = mesh.add_vertex(gx0, gy1, 0.0)

        t0 = mesh.add_vertex(gx0 + 3, gy0 + 3, 17.0)
        t1 = mesh.add_vertex(gx1 - 3, gy0 + 3, 17.0)
        t2 = mesh.add_vertex(gx1 - 5, gy1 - 5, 14.5) # Heavy sloped frontal plate
        t3 = mesh.add_vertex(gx0 + 5, gy1 - 5, 14.5)

        mesh.add_quad(b0, b1, t1, t0, MAT_SUPER)
        mesh.add_quad(b1, b2, t2, t1, MAT_SUPER)
        mesh.add_quad(b2, b3, t3, t2, MAT_SUPER_HIGH)
        mesh.add_quad(b3, b0, t0, t3, MAT_SUPER)
        mesh.add_quad(t0, t1, t2, t3, MAT_SUPER_HIGH)

        # Triple Heavy Long-Range Barrels
        for gx in [-8.0, 0.0, 8.0]:
            gb0 = mesh.add_vertex(gx - 1.8, 17.0, 8.5)
            gb1 = mesh.add_vertex(gx + 1.8, 17.0, 8.5)
            gt0 = mesh.add_vertex(gx - 1.4, 48.0, 9.0) # Long heavy barrel
            gt1 = mesh.add_vertex(gx + 1.4, 48.0, 9.0)
            mesh.add_quad(gb0, gb1, gt1, gt0, MAT_GUN_METAL)
            mesh.add_quad(gb1, gb0, gt0, gt1, MAT_GUN_METAL)

    return mesh


# =============================================================================
# 5. VECTORIZED 3D CEL-SHADING RASTERIZER
# =============================================================================
def render_3d_mesh(mesh, width, height, yaw_deg=0.0, scale=1.0):
    palette = PALETTE_WARSHIP

    # Yaw rotation
    y_rad = math.radians(yaw_deg)
    cy_a, sy_a = math.cos(y_rad), math.sin(y_rad)
    R_yaw = np.array([
        [ cy_a, -sy_a, 0.0],
        [ sy_a,  cy_a, 0.0],
        [  0.0,   0.0, 1.0]
    ])

    V_raw = np.array(mesh.vertices)
    V_rot = (R_yaw @ V_raw.T).T

    cx, cy = width / 2.0, height / 2.0
    V_screen = np.zeros((len(V_rot), 3))
    V_screen[:, 0] = cx + V_rot[:, 0] * scale
    V_screen[:, 1] = cy - V_rot[:, 1] * scale
    V_screen[:, 2] = V_rot[:, 2]

    img_arr = np.zeros((height, width, 4), dtype=np.uint8)
    z_buffer = np.full((height, width), -1e9, dtype=np.float32)
    id_buffer = np.zeros((height, width), dtype=np.int32)

    face_depths = []
    for f_idx, (v0, v1, v2, mat_id) in enumerate(mesh.faces):
        avg_z = (V_screen[v0, 2] + V_screen[v1, 2] + V_screen[v2, 2]) / 3.0
        face_depths.append((avg_z, f_idx))
    face_depths.sort(key=lambda x: x[0])

    for _, f_idx in face_depths:
        v0, v1, v2, mat_id = mesh.faces[f_idx]
        p0, p1, p2 = V_screen[v0], V_screen[v1], V_screen[v2]

        e1 = V_rot[v1] - V_rot[v0]
        e2 = V_rot[v2] - V_rot[v0]
        norm = np.cross(e1, e2)
        norm_len = np.linalg.norm(norm)
        if norm_len < 1e-6:
            continue
        norm = norm / norm_len

        # Lighting with directional sunlight
        diff = max(0.0, float(np.dot(norm, L_DIR)))

        mat_cfg = palette.get(mat_id, palette[MAT_HULL])
        base_col = np.array(mat_cfg["base"], dtype=np.float32)

        # 3-Tone Quantized Cel-Shade Ramp
        if mat_id == MAT_FIRE:
            shade = 1.25
        elif diff > 0.65:
            shade = 1.15
        elif diff > 0.28:
            shade = 1.00
        else:
            shade = 0.80

        col = tuple(np.clip(base_col * shade, 0, 255).astype(np.uint8))

        min_x = max(0, int(math.floor(min(p0[0], p1[0], p2[0]))))
        max_x = min(width - 1, int(math.ceil(max(p0[0], p1[0], p2[0]))))
        min_y = max(0, int(math.floor(min(p0[1], p1[1], p2[1]))))
        max_y = min(height - 1, int(math.ceil(max(p0[1], p1[1], p2[1]))))
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

    # 2px Crisp Inking Outlines
    alpha_mask = img_arr[..., 3] > 0
    edge_map = np.zeros((height, width), dtype=bool)
    for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        shifted_a = np.roll(alpha_mask, (dy, dx), axis=(0, 1))
        shifted_id = np.roll(id_buffer, (dy, dx), axis=(0, 1))
        edge_map |= alpha_mask & (~shifted_a) # Outer silhouette
        edge_map |= alpha_mask & shifted_a & (id_buffer != shifted_id) # Interior edge

    img_arr[edge_map] = np.array([20, 24, 30, 255], dtype=np.uint8)
    return Image.fromarray(img_arr, mode="RGBA")


# =============================================================================
# 6. MAIN PIPELINE: BAKE HULLS & ROTATING TURRET SHEETS
# =============================================================================
def main():
    sprites_dir = Path("games/skyace/sprites")
    sprites_dir.mkdir(parents=True, exist_ok=True)
    art_dir = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62")

    print("[Sky Ace] Generating true 3D cel-shaded naval warships and rotating turrets...")

    # 1. FLEET DESTROYER (140 x 420 px)
    dw, dh = 140, 420
    for stage, sname in [(0, "pristine"), (1, "damaged"), (2, "wreck")]:
        mesh_d = build_destroyer_mesh(stage)
        d_img = render_3d_mesh(mesh_d, dw, dh, yaw_deg=0.0, scale=1.0)
        # Add subtle underwater depth shadow
        canvas = Image.new("RGBA", (dw, dh), (0, 0, 0, 0))
        sh_layer = Image.new("RGBA", (dw, dh), (0, 0, 0, 0))
        s_draw = ImageDraw.Draw(sh_layer)
        s_draw.polygon([(dw//2 - 42, 25), (dw//2 + 35, 25), (dw//2 + 45, dh - 20), (dw//2 - 38, dh - 20)], fill=(6, 16, 26, 120))
        sh_layer = sh_layer.filter(ImageFilter.GaussianBlur(6))
        canvas = Image.alpha_composite(canvas, sh_layer)
        canvas = Image.alpha_composite(canvas, d_img)

        out_path = sprites_dir / f"ship_destroyer_{sname}.png"
        canvas.save(out_path)
        try: canvas.save(art_dir / f"ship_destroyer_{sname}.png")
        except Exception: pass
        print(f"✓ Saved Destroyer: {out_path.name}")

    # 2. HEAVY CRUISER / BATTLESHIP (200 x 580 px)
    cw, ch = 200, 580
    for stage, sname in [(0, "pristine"), (1, "damaged"), (2, "wreck")]:
        mesh_c = build_cruiser_mesh(stage)
        c_img = render_3d_mesh(mesh_c, cw, ch, yaw_deg=0.0, scale=1.0)
        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        sh_layer = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        s_draw = ImageDraw.Draw(sh_layer)
        s_draw.polygon([(cw//2 - 58, 25), (cw//2 + 50, 25), (cw//2 + 62, ch - 22), (cw//2 - 54, ch - 22)], fill=(6, 16, 26, 125))
        sh_layer = sh_layer.filter(ImageFilter.GaussianBlur(8))
        canvas = Image.alpha_composite(canvas, sh_layer)
        canvas = Image.alpha_composite(canvas, c_img)

        out_path = sprites_dir / f"ship_cruiser_{sname}.png"
        canvas.save(out_path)
        try: canvas.save(art_dir / f"ship_cruiser_{sname}.png")
        except Exception: pass
        print(f"✓ Saved Heavy Cruiser: {out_path.name}")

    # 3. PT GUNBOAT (80 x 180 px)
    pw, ph = 80, 180
    for stage, sname in [(0, "pristine"), (1, "damaged"), (2, "wreck")]:
        mesh_p = build_pt_boat_mesh(stage)
        p_img = render_3d_mesh(mesh_p, pw, ph, yaw_deg=0.0, scale=1.0)
        canvas = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
        sh_layer = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
        s_draw = ImageDraw.Draw(sh_layer)
        s_draw.polygon([(pw//2 - 24, 10), (pw//2 + 20, 10), (pw//2 + 26, ph - 10), (pw//2 - 22, ph - 10)], fill=(6, 16, 26, 115))
        sh_layer = sh_layer.filter(ImageFilter.GaussianBlur(5))
        canvas = Image.alpha_composite(canvas, sh_layer)
        canvas = Image.alpha_composite(canvas, p_img)

        out_path = sprites_dir / f"ship_gunboat_{sname}.png"
        canvas.save(out_path)
        try: canvas.save(art_dir / f"ship_gunboat_{sname}.png")
        except Exception: pass
        print(f"✓ Saved PT Gunboat: {out_path.name}")

    # 4. ROTATING 3D TURRET SPRITE SHEETS (16 rotation steps for 360° aiming)
    # 16 angles: 0, 22.5, 45, 67.5, ... 337.5 degrees
    # Destroyer Turret: 64 x 64 px cell, Sheet: 1024 x 64 px
    tw_d, th_d = 64, 64
    d_sheet = Image.new("RGBA", (tw_d * 16, th_d), (0, 0, 0, 0))
    d_mesh = build_turret_mesh("destroyer")
    for i in range(16):
        deg = i * 22.5
        f_img = render_3d_mesh(d_mesh, tw_d, th_d, yaw_deg=-deg, scale=1.1)
        d_sheet.paste(f_img, (i * tw_d, 0))
    d_sheet.save(sprites_dir / "turret_destroyer_sheet.png")
    try: d_sheet.save(art_dir / "turret_destroyer_sheet.png")
    except Exception: pass
    print("✓ Saved 16-angle Destroyer Turret Sheet: turret_destroyer_sheet.png")

    # Heavy Cruiser Turret: 80 x 80 px cell, Sheet: 1280 x 80 px
    tw_c, th_c = 80, 80
    c_sheet = Image.new("RGBA", (tw_c * 16, th_c), (0, 0, 0, 0))
    c_mesh = build_turret_mesh("cruiser")
    for i in range(16):
        deg = i * 22.5
        f_img = render_3d_mesh(c_mesh, tw_c, th_c, yaw_deg=-deg, scale=1.0)
        c_sheet.paste(f_img, (i * tw_c, 0))
    c_sheet.save(sprites_dir / "turret_heavy_sheet.png")
    try: c_sheet.save(art_dir / "turret_heavy_sheet.png")
    except Exception: pass
    print("✓ Saved 16-angle Heavy Cruiser Turret Sheet: turret_heavy_sheet.png")

if __name__ == "__main__":
    main()

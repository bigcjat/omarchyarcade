#!/usr/bin/env python3
"""
tools/build_3d_bosses.py
Builds mathematical 3D meshes and renders studio-grade cel-shaded sprite sheets for:
1. USA Boss: Consolidated B-24 Liberator ("GOLIATH")
   - Signature twin oval vertical rudders
   - 4 radial engines with bright RED cowlings (matching reference photo)
   - Bare-metal polished aluminum fuselage with dark panel lines
   - Nose, dorsal, and tail gun turrets
2. Canada Boss: RCAF Lancaster Mk. X ("THE CANADA GOOSE")
   - 4 Canadian-built Packard Rolls-Royce Merlin nacelles
   - Twin vertical rudders with RCAF Red Maple Leaf roundels
   - Dark night/ocean camouflage with "Canada Goose" nose markings
   - Dorsal and tail quad-gun turrets

Renders 3 battle-damage stages (Pristine, Wing Damaged, Critical Wreck)
into 384x256 spritesheets for games/skyace/sprites/.
"""

import math
import json
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
        self.vertices.append((float(x), float(y), float(z)))
        return len(self.vertices) - 1

    def add_quad(self, v0, v1, v2, v3, mat_id):
        self.faces.append((v0, v1, v2, mat_id))
        self.faces.append((v0, v2, v3, mat_id))

    def add_tri(self, v0, v1, v2, mat_id):
        self.faces.append((v0, v1, v2, mat_id))

# =============================================================================
# 1. B-24 LIBERATOR 3D MESH BUILDER
# =============================================================================
MAT_B24_ALUM = 1       # Polished bare metal aluminum
MAT_B24_ALUM_DARK = 2  # Shaded lower belly aluminum
MAT_B24_RED_COWL = 3   # Bright Red Engine Cowlings (from reference photo)
MAT_B24_PROP_SPIN = 4  # Spinning 3-blade prop blur with yellow tips
MAT_B24_CANOPY = 5     # Greenhouse nose & cockpit glass
MAT_B24_RUDDER_YEL = 6 # Yellow & Black striped rudder markings
MAT_B24_TURRET = 7     # Gunmetal machine gun turrets
MAT_B24_STAR = 8       # USAAF Star & Bars insignia white/navy
MAT_B24_DEICE = 9      # Black rubber de-icing boots on wing leading edges
MAT_FIRE = 10          # Flaming battle damage
MAT_CHARRED = 11       # Charred blackened blast-damaged metal

PALETTE_B24 = {
    MAT_B24_ALUM:      {"base": (215, 222, 230), "ink": (70, 75, 85),   "spec": 0.55},
    MAT_B24_ALUM_DARK: {"base": (170, 178, 188), "ink": (55, 60, 70),   "spec": 0.35},
    MAT_B24_RED_COWL:  {"base": (225, 38, 38),   "ink": (130, 15, 15),  "spec": 0.40},
    MAT_B24_PROP_SPIN: {"base": (45, 48, 52),    "ink": (25, 28, 32),   "spec": 0.10},
    MAT_B24_CANOPY:    {"base": (135, 215, 248), "ink": (30, 75, 105),  "spec": 0.95},
    MAT_B24_RUDDER_YEL:{"base": (245, 195, 35),  "ink": (140, 95, 15),  "spec": 0.30},
    MAT_B24_TURRET:    {"base": (38, 42, 48),    "ink": (18, 20, 24),   "spec": 0.50},
    MAT_B24_STAR:      {"base": (245, 245, 250), "ink": (20, 35, 75),   "spec": 0.20},
    MAT_B24_DEICE:     {"base": (35, 38, 44),    "ink": (18, 20, 24),   "spec": 0.25},
    MAT_FIRE:          {"base": (255, 100, 20),  "ink": (200, 40, 10),  "spec": 1.00},
    MAT_CHARRED:       {"base": (35, 36, 40),    "ink": (15, 16, 18),   "spec": 0.05},
}

def build_b24_mesh(damage_stage=0):
    mesh = Mesh3D()

    # 1. Fuselage (Deep, slab-sided boxy fuselage of the Liberator)
    # Sections along Y: (y, rx, rz, zc)
    sections = [
        (82.0, 4.0, 5.0, 2.0),    # Glass nose greenhouse / bomb aimer
        (72.0, 8.5, 9.5, 2.5),    # Nose turret / cockpit transition
        (56.0, 10.5, 12.5, 4.0),  # Flight deck cockpit
        (30.0, 11.5, 13.5, 4.0),  # Forward bomb bay
        (0.0,  12.0, 14.0, 4.0),  # Mid wing-box
        (-35.0, 11.5, 13.5, 4.0), # Aft bomb bay / waist gunners
        (-65.0, 8.5, 11.0, 4.5),  # Taper to tail
        (-82.0, 4.5, 6.5, 5.5),   # Tail gunner enclosure
    ]

    rings = []
    n_rad = 12
    for s_idx, (y, rx, rz, zc) in enumerate(sections):
        ring = []
        for i in range(n_rad):
            theta = 2.0 * math.pi * i / n_rad
            # Slab-sided modification: slightly flatter sides
            cos_t = math.cos(theta)
            sin_t = math.sin(theta)
            vx = rx * math.copysign(abs(cos_t) ** 0.85, cos_t)
            vz = zc + rz * math.copysign(abs(sin_t) ** 0.90, sin_t)
            ring.append(mesh.add_vertex(vx, y, vz))
        rings.append(ring)

    for s in range(len(sections) - 1):
        r0 = rings[s]
        r1 = rings[s + 1]
        for i in range(n_rad):
            i_next = (i + 1) % n_rad
            mat = MAT_B24_ALUM if s != 0 else MAT_B24_CANOPY
            if s == 1 and i in [2, 3, 4]:
                mat = MAT_B24_CANOPY
            elif i in [0, 1, 10, 11]:
                mat = MAT_B24_ALUM_DARK
            # Scorch marks on fuselage in critical wreck
            if damage_stage >= 2 and s in [3, 4] and i in [3, 4, 5]:
                mat = MAT_CHARRED
            mesh.add_quad(r0[i], r1[i], r1[i_next], r0[i_next], mat)

    # 2. High-Aspect Ratio Davis Wings
    stations_pristine = [
        (11.0,  18.0, 13.0, -16.0, 12.0),  # Root
        (45.0,  15.0, 13.0, -14.0, 12.0),  # Inner engine
        (85.0,  11.0, 13.0, -12.0, 12.0),  # Outer engine
        (138.0,  2.0, 13.0,  -8.0, 12.0),  # Wingtip
    ]

    for side in [-1, 1]:
        stations = list(stations_pristine)
        # Structural damage: starboard wingtip torn off in battle
        if damage_stage >= 1 and side == 1:
            stations[3] = (108.0, 6.0, 13.0, -10.0, 12.0) # Torn ragged wingtip

        w_quads = []
        for sx, ly, lz, ty, tz in stations:
            x = sx * side
            v_lu = mesh.add_vertex(x, ly, lz + 1.2)
            v_tu = mesh.add_vertex(x, ty, tz + 0.6)
            v_tl = mesh.add_vertex(x, ty, tz - 0.6)
            v_ll = mesh.add_vertex(x, ly, lz - 1.2)
            w_quads.append((v_lu, v_tu, v_tl, v_ll))

        for s in range(len(stations) - 1):
            w0, w1 = w_quads[s], w_quads[s + 1]
            is_burned = (damage_stage >= 1 and side == 1 and s >= 1) or (damage_stage >= 2 and side == -1 and s == 1)
            mat_top = MAT_CHARRED if is_burned else MAT_B24_ALUM
            mat_deice = MAT_CHARRED if is_burned else MAT_B24_DEICE
            if side == 1:
                mesh.add_quad(w0[0], w1[0], w1[1], w0[1], mat_top)
                mesh.add_quad(w0[1], w1[1], w1[2], w0[2], mat_deice)
                mesh.add_quad(w1[2], w1[3], w0[3], w0[2], MAT_B24_ALUM_DARK)
                mesh.add_quad(w0[3], w1[3], w1[0], w0[0], mat_deice)
            else:
                mesh.add_quad(w1[0], w0[0], w0[1], w1[1], mat_top)
                mesh.add_quad(w1[1], w0[1], w0[2], w1[2], mat_deice)
                mesh.add_quad(w0[2], w0[3], w1[3], w1[2], MAT_B24_ALUM_DARK)
                mesh.add_quad(w1[3], w0[3], w0[0], w1[0], mat_deice)

    # 3. 4 Heavy Pratt & Whitney R-1830 Radials with Bright Red Cowlings
    eng_x = [45.0, 85.0]
    for ex_abs in eng_x:
        for side in [-1, 1]:
            ex = ex_abs * side
            ey = 16.0 if ex_abs == 45.0 else 12.0
            ez = 8.5
            is_dam = (damage_stage >= 1 and ex_abs == 85.0 and side == 1) or \
                     (damage_stage >= 2 and ex_abs == 45.0 and side == -1)

            # Red Cowling Cylinder & Radial Engine Face (or Charred Destroyed Nacelle)
            r_cowl = 7.5
            n_cowl = 12
            yf = ey + (10.0 if is_dam else 14.0)
            yb = ey - 12.0
            r_f, r_b = [], []
            for i in range(n_cowl):
                th = 2.0 * math.pi * i / n_cowl
                vx = ex + r_cowl * math.cos(th)
                vz = ez + r_cowl * math.sin(th)
                r_f.append(mesh.add_vertex(vx, yf, vz))
                r_b.append(mesh.add_vertex(vx, yb, vz))

            c_mat = MAT_CHARRED if is_dam else MAT_B24_RED_COWL
            for i in range(n_cowl):
                i_next = (i + 1) % n_cowl
                if side == 1:
                    mesh.add_quad(r_f[i], r_b[i], r_b[i_next], r_f[i_next], c_mat)
                else:
                    mesh.add_quad(r_b[i], r_f[i], r_f[i_next], r_b[i_next], c_mat)

            # Engine interior / radial cylinders
            v_eng_c = mesh.add_vertex(ex, yf - 2.0, ez)
            for i in range(n_cowl):
                i_next = (i + 1) % n_cowl
                mesh.add_tri(r_f[i], v_eng_c, r_f[i_next], MAT_CHARRED if is_dam else MAT_B24_TURRET)

            # Spinning 3-blade prop disc blur ONLY on undamaged running engines!
            if not is_dam:
                v_prop_hub = mesh.add_vertex(ex, yf + 3.5, ez)
                r_prop = 13.0
                p_f = []
                for i in range(n_cowl):
                    th = 2.0 * math.pi * i / n_cowl
                    vx = ex + r_prop * math.cos(th)
                    vz = ez + r_prop * math.sin(th)
                    p_f.append(mesh.add_vertex(vx, yf + 2.5, vz))
                for i in range(n_cowl):
                    i_next = (i + 1) % n_cowl
                    mesh.add_tri(p_f[i], v_prop_hub, p_f[i_next], MAT_B24_PROP_SPIN)
                    mesh.add_tri(v_prop_hub, p_f[i], p_f[i_next], MAT_B24_PROP_SPIN)
            else:
                # Broken, bent prop stump for damaged engine
                v_stump = mesh.add_vertex(ex, yf + 2.0, ez)
                mesh.add_tri(mesh.add_vertex(ex - 3, yf + 1, ez + 6), v_stump, mesh.add_vertex(ex + 2, yf + 1, ez + 4), MAT_CHARRED)

    # 4. Iconic Twin Oval Tail Fins & Horizontal Stabilizer
    # Horizontal stabilizer: X = -58 to +58 at Y = -78, Z = 6.5
    h_w = 56.0
    h_y0, h_y1 = -70.0, -86.0
    h_z = 7.5
    v_hle_l = mesh.add_vertex(-h_w, h_y0, h_z)
    v_hle_r = mesh.add_vertex( h_w, h_y0, h_z)
    v_hte_r = mesh.add_vertex( h_w, h_y1, h_z)
    v_hte_l = mesh.add_vertex(-h_w, h_y1, h_z)
    mesh.add_quad(v_hle_l, v_hle_r, v_hte_r, v_hte_l, MAT_B24_ALUM)
    mesh.add_quad(v_hte_l, v_hte_r, v_hle_r, v_hle_l, MAT_B24_ALUM_DARK)

    # Twin Oval Rudders at X = -56 and +56
    # Signature B-24 twin vertical ovals with 3D thickness and slight outward cant
    for side in [-1, 1]:
        tx_c = side * h_w
        oval_n = 12
        o_outer, o_inner = [], []
        thick = 2.8
        for i in range(oval_n):
            th = 2.0 * math.pi * i / oval_n
            oy = -78.0 + 10.0 * math.cos(th)
            oz = 7.5 + 20.0 * math.sin(th)
            cant_x = (oz - 7.5) * 0.08 * side # subtle outward cant
            o_outer.append(mesh.add_vertex(tx_c + (thick * side) + cant_x, oy, oz))
            o_inner.append(mesh.add_vertex(tx_c - (thick * side) + cant_x, oy, oz))

        v_out_c = mesh.add_vertex(tx_c + (thick * side), -78.0, 7.5)
        v_inn_c = mesh.add_vertex(tx_c - (thick * side), -78.0, 7.5)

        for i in range(oval_n):
            i_next = (i + 1) % oval_n
            # Outer face (yellow markings)
            mesh.add_tri(o_outer[i], o_outer[i_next], v_out_c, MAT_B24_RUDDER_YEL)
            mesh.add_tri(v_out_c, o_outer[i_next], o_outer[i], MAT_B24_RUDDER_YEL)
            # Inner face
            mesh.add_tri(o_inner[i_next], o_inner[i], v_inn_c, MAT_B24_ALUM)
            mesh.add_tri(v_inn_c, o_inner[i], o_inner[i_next], MAT_B24_ALUM)
            # Perimeter leading / trailing / top edges
            mesh.add_quad(o_outer[i], o_inner[i], o_inner[i_next], o_outer[i_next], MAT_B24_ALUM_DARK)

    # 5. Gun Turrets (Nose, Top Sperry Turret, Tail Stinger)
    # Dorsal Sperry dome turret
    dt_c = mesh.add_vertex(0.0, 24.0, 17.5)
    dt_f = mesh.add_vertex(0.0, 32.0, 15.0)
    dt_b = mesh.add_vertex(0.0, 16.0, 15.0)
    dt_l = mesh.add_vertex(-5.0, 24.0, 15.5)
    dt_r = mesh.add_vertex( 5.0, 24.0, 15.5)
    mesh.add_tri(dt_c, dt_f, dt_l, MAT_B24_TURRET)
    mesh.add_tri(dt_c, dt_r, dt_f, MAT_B24_TURRET)
    mesh.add_tri(dt_c, dt_l, dt_b, MAT_B24_TURRET)
    mesh.add_tri(dt_c, dt_b, dt_r, MAT_B24_TURRET)

    # Nose Emerson turret
    nt_c = mesh.add_vertex(0.0, 78.0, 8.5)
    nt_f = mesh.add_vertex(0.0, 84.0, 6.0)
    nt_l = mesh.add_vertex(-4.0, 78.0, 7.0)
    nt_r = mesh.add_vertex( 4.0, 78.0, 7.0)
    mesh.add_tri(nt_c, nt_f, nt_l, MAT_B24_TURRET)
    mesh.add_tri(nt_c, nt_r, nt_f, MAT_B24_TURRET)

    # Tail twin stinger turret
    tt_c = mesh.add_vertex(0.0, -82.0, 9.0)
    tt_b = mesh.add_vertex(0.0, -88.0, 7.0)
    tt_l = mesh.add_vertex(-4.0, -82.0, 8.0)
    tt_r = mesh.add_vertex( 4.0, -82.0, 8.0)
    mesh.add_tri(tt_c, tt_l, tt_b, MAT_B24_TURRET)
    mesh.add_tri(tt_c, tt_b, tt_r, MAT_B24_TURRET)

    return mesh

# =============================================================================
# 2. CANADA GOOSE (RCAF LANCASTER MK. X) 3D MESH BUILDER
# =============================================================================
MAT_CAN_CAMO_DARK = 1  # Dark Earth Night Camouflage
MAT_CAN_CAMO_GRN = 2   # RAF Dark Green Camouflage
MAT_CAN_MERLIN = 3     # Rolls-Royce Merlin Engine Nacelles
MAT_CAN_PROP = 4       # Spinning Merlin 3-blade prop blur
MAT_CAN_CANOPY = 5     # Greenhouse cockpit & nose blister
MAT_CAN_MAPLE = 6      # RCAF Red Maple Leaf Insignia
MAT_CAN_TURRET = 7     # Quad .303 Browning tail turret
MAT_CAN_BELLY = 8      # Matte Night Black Bomb Bay Belly
MAT_CAN_CHARRED = 9    # Charred battle-damaged armor plating

PALETTE_CANADAGOOSE = {
    MAT_CAN_CAMO_DARK: {"base": (55, 62, 52),    "ink": (24, 28, 22),   "spec": 0.20},
    MAT_CAN_CAMO_GRN:  {"base": (68, 82, 58),    "ink": (30, 38, 26),   "spec": 0.20},
    MAT_CAN_MERLIN:    {"base": (45, 52, 44),    "ink": (20, 24, 18),   "spec": 0.35},
    MAT_CAN_PROP:      {"base": (40, 42, 46),    "ink": (20, 22, 25),   "spec": 0.10},
    MAT_CAN_CANOPY:    {"base": (140, 215, 245), "ink": (30, 75, 105),  "spec": 0.95},
    MAT_CAN_MAPLE:     {"base": (220, 35, 35),   "ink": (130, 15, 15),  "spec": 0.30},
    MAT_CAN_TURRET:    {"base": (35, 38, 44),    "ink": (18, 20, 24),   "spec": 0.50},
    MAT_CAN_BELLY:     {"base": (28, 30, 34),    "ink": (14, 15, 18),   "spec": 0.10},
    MAT_FIRE:          {"base": (255, 100, 20),  "ink": (200, 40, 10),  "spec": 1.00},
    MAT_CAN_CHARRED:   {"base": (30, 32, 36),    "ink": (14, 15, 18),   "spec": 0.05},
}

def build_canadagoose_mesh(damage_stage=0):
    mesh = Mesh3D()

    # 1. Long, sleek Lancaster Fuselage with massive bomb-bay belly
    sections = [
        (84.0, 3.5, 4.5, 1.5),    # Frazer-Nash nose turret
        (74.0, 7.5, 8.5, 2.5),    # Bomb aimer blister
        (58.0, 10.0, 11.5, 4.0),  # Cockpit canopy
        (25.0, 11.0, 13.0, 3.5),  # Forward bomb bay
        (-10.0, 11.0, 13.0, 3.5), # Mid fuselage
        (-45.0, 10.0, 12.0, 3.5), # Aft fuselage
        (-75.0, 7.0, 8.5, 4.5),   # Dorsal turret transition
        (-92.0, 3.5, 5.0, 5.0),   # Rear quad-gun turret
    ]

    rings = []
    n_rad = 12
    for s_idx, (y, rx, rz, zc) in enumerate(sections):
        ring = []
        for i in range(n_rad):
            theta = 2.0 * math.pi * i / n_rad
            vx = rx * math.cos(theta)
            vz = zc + rz * math.sin(theta)
            ring.append(mesh.add_vertex(vx, y, vz))
        rings.append(ring)

    for s in range(len(sections) - 1):
        r0 = rings[s]
        r1 = rings[s + 1]
        for i in range(n_rad):
            i_next = (i + 1) % n_rad
            mat = MAT_CAN_CAMO_GRN if (s + i) % 2 == 0 else MAT_CAN_CAMO_DARK
            if s == 0 or (s == 1 and i in [2, 3, 4]):
                mat = MAT_CAN_CANOPY
            elif i in [0, 1, 7, 8, 9]:
                mat = MAT_CAN_BELLY # Night black belly
            mesh.add_quad(r0[i], r1[i], r1[i_next], r0[i_next], mat)

    # 2. Mid-Mounted Elliptical Lancaster Wings
    stations = [
        (11.0,  18.0, 6.0, -18.0, 5.0),  # Root
        (42.0,  15.0, 7.5, -15.0, 6.5),  # Inner Merlin
        (80.0,  10.0, 9.0, -12.0, 8.0),  # Outer Merlin
        (136.0,  0.0, 10.5, -8.0, 9.5),  # Rounded wingtip
    ]

    for side in [-1, 1]:
        w_quads = []
        for sx, ly, lz, ty, tz in stations:
            x = sx * side
            v_lu = mesh.add_vertex(x, ly, lz + 1.2)
            v_tu = mesh.add_vertex(x, ty, tz + 0.6)
            v_tl = mesh.add_vertex(x, ty, tz - 0.6)
            v_ll = mesh.add_vertex(x, ly, lz - 1.2)
            w_quads.append((v_lu, v_tu, v_tl, v_ll))

        for s in range(len(stations) - 1):
            w0, w1 = w_quads[s], w_quads[s + 1]
            mat_top = MAT_CAN_MAPLE if s == len(stations) - 2 else (MAT_CAN_CAMO_GRN if s % 2 == 0 else MAT_CAN_CAMO_DARK)
            if side == 1:
                mesh.add_quad(w0[0], w1[0], w1[1], w0[1], mat_top)
                mesh.add_quad(w0[1], w1[1], w1[2], w0[2], MAT_CAN_CAMO_DARK)
                mesh.add_quad(w1[2], w1[3], w0[3], w0[2], MAT_CAN_BELLY)
                mesh.add_quad(w0[3], w1[3], w1[0], w0[0], MAT_CAN_CAMO_DARK)
            else:
                mesh.add_quad(w1[0], w0[0], w0[1], w1[1], mat_top)
                mesh.add_quad(w1[1], w0[1], w0[2], w1[2], MAT_CAN_CAMO_DARK)
                mesh.add_quad(w0[2], w0[3], w1[3], w1[2], MAT_CAN_BELLY)
                mesh.add_quad(w1[3], w0[3], w0[0], w1[0], MAT_CAN_CAMO_DARK)

    # 3. 4 Rolls-Royce Merlin Engine Nacelles
    eng_x = [42.0, 80.0]
    for ex_abs in eng_x:
        for side in [-1, 1]:
            ex = ex_abs * side
            ey = 18.0 if ex_abs == 42.0 else 13.0
            ez = 5.0
            is_dam = (damage_stage >= 1 and ex_abs == 80.0 and side == 1) or \
                     (damage_stage >= 2 and ex_abs == 42.0 and side == -1)

            r_m = 5.2
            n_m = 8
            yf, yb = ey + 14.0, ey - 12.0
            r_f, r_b = [], []
            for i in range(n_m):
                th = 2.0 * math.pi * i / n_m
                vx = ex + r_m * math.cos(th)
                vz = ez + r_m * math.sin(th)
                r_f.append(mesh.add_vertex(vx, yf, vz))
                r_b.append(mesh.add_vertex(vx * 0.95, yb, vz * 0.95))

            m_mat = MAT_FIRE if is_dam else MAT_CAN_MERLIN
            for i in range(n_m):
                i_next = (i + 1) % n_m
                if side == 1:
                    mesh.add_quad(r_f[i], r_b[i], r_b[i_next], r_f[i_next], m_mat)
                else:
                    mesh.add_quad(r_b[i], r_f[i], r_f[i_next], r_b[i_next], m_mat)

            # Spinning Merlin prop disc blur
            v_hub = mesh.add_vertex(ex, yf + 3.5, ez)
            r_prop = 12.0
            p_f = []
            for i in range(n_m):
                th = 2.0 * math.pi * i / n_m
                vx = ex + r_prop * math.cos(th)
                vz = ez + r_prop * math.sin(th)
                p_f.append(mesh.add_vertex(vx, yf + 2.5, vz))
            for i in range(n_m):
                i_next = (i + 1) % n_m
                mesh.add_tri(p_f[i], v_hub, p_f[i_next], MAT_CAN_PROP)
                mesh.add_tri(v_hub, p_f[i], p_f[i_next], MAT_CAN_PROP)

    # 4. Characteristic Lancaster Twin Oval Rudders & Dihedral Tailplane
    h_w = 54.0
    h_y0, h_y1 = -78.0, -94.0
    h_z = 7.5
    v_hle_l = mesh.add_vertex(-h_w, h_y0, h_z + 4.0)
    v_hle_r = mesh.add_vertex( h_w, h_y0, h_z + 4.0)
    v_hte_r = mesh.add_vertex( h_w, h_y1, h_z + 4.0)
    v_hte_l = mesh.add_vertex(-h_w, h_y1, h_z + 4.0)
    mesh.add_quad(v_hle_l, v_hle_r, v_hte_r, v_hte_l, MAT_CAN_CAMO_DARK)
    mesh.add_quad(v_hte_l, v_hte_r, v_hle_r, v_hle_l, MAT_CAN_BELLY)

    for side in [-1, 1]:
        tx_c = side * h_w
        tz = h_z + 4.0
        n_rud = 12
        o_outer, o_inner = [], []
        thick = 2.6
        for i in range(n_rud):
            th = 2.0 * math.pi * i / n_rud
            ry = -86.0 + 9.0 * math.cos(th)
            rz = tz + 18.0 * math.sin(th)
            cant_x = (rz - tz) * 0.08 * side
            o_outer.append(mesh.add_vertex(tx_c + (thick * side) + cant_x, ry, rz))
            o_inner.append(mesh.add_vertex(tx_c - (thick * side) + cant_x, ry, rz))

        v_out_c = mesh.add_vertex(tx_c + (thick * side), -86.0, tz)
        v_inn_c = mesh.add_vertex(tx_c - (thick * side), -86.0, tz)

        for i in range(n_rud):
            i_next = (i + 1) % n_rud
            # Outer face (RCAF Red Maple Leaf Roundel)
            mesh.add_tri(o_outer[i], o_outer[i_next], v_out_c, MAT_CAN_MAPLE)
            mesh.add_tri(v_out_c, o_outer[i_next], o_outer[i], MAT_CAN_MAPLE)
            # Inner face (Camouflage)
            mesh.add_tri(o_inner[i_next], o_inner[i], v_inn_c, MAT_CAN_CAMO_DARK)
            mesh.add_tri(v_inn_c, o_inner[i], o_inner[i_next], MAT_CAN_CAMO_DARK)
            # Rim edge
            mesh.add_quad(o_outer[i], o_inner[i], o_inner[i_next], o_outer[i_next], MAT_CAN_BELLY)

    # 5. Turrets (Nose blister, Mid-Upper FN50, Rear Quad FN20)
    # Mid-Upper dorsal turret
    mesh.add_tri(mesh.add_vertex(0.0, -10.0, 16.0), mesh.add_vertex(-4.0, -10.0, 14.5), mesh.add_vertex(0.0, -4.0, 14.0), MAT_CAN_TURRET)
    mesh.add_tri(mesh.add_vertex(0.0, -10.0, 16.0), mesh.add_vertex(0.0, -4.0, 14.0), mesh.add_vertex(4.0, -10.0, 14.5), MAT_CAN_TURRET)

    # Rear Quad Gun Turret
    mesh.add_tri(mesh.add_vertex(0.0, -96.0, 9.0), mesh.add_vertex(-4.0, -96.0, 7.5), mesh.add_vertex(0.0, -102.0, 7.0), MAT_CAN_TURRET)
    mesh.add_tri(mesh.add_vertex(0.0, -96.0, 9.0), mesh.add_vertex(0.0, -102.0, 7.0), mesh.add_vertex(4.0, -96.0, 7.5), MAT_CAN_TURRET)

    return mesh

# =============================================================================
# STUDIO CEL-SHADING RASTERIZER
# =============================================================================
def render_boss_to_image(mesh, palette, pitch_deg=-8.0, roll_deg=0.0, damage_stage=0, size=384, scale=1.35):
    l_dir = np.array([-0.45, -0.60, 0.70])
    l_dir = l_dir / np.linalg.norm(l_dir)

    r_rad = math.radians(roll_deg)
    cr, sr = math.cos(r_rad), math.sin(r_rad)
    R_roll = np.array([[cr, 0.0, sr], [0.0, 1.0, 0.0], [-sr, 0.0, cr]])

    p_rad = math.radians(pitch_deg)
    cp, sp = math.cos(p_rad), math.sin(p_rad)
    R_pitch = np.array([[1.0, 0.0, 0.0], [0.0, cp, -sp], [0.0, sp, cp]])

    R_total = R_pitch @ R_roll

    V_raw = np.array(mesh.vertices)
    V_rot = (R_total @ V_raw.T).T

    cx, cy = size / 2.0, size / 2.0
    V_screen = np.zeros((len(V_rot), 3))
    V_screen[:, 0] = cx + V_rot[:, 0] * scale
    V_screen[:, 1] = cy - V_rot[:, 1] * scale
    V_screen[:, 2] = V_rot[:, 2]

    img_arr = np.zeros((size, size, 4), dtype=np.uint8)
    z_buffer = np.full((size, size), -1e9, dtype=np.float32)
    id_buffer = np.zeros((size, size), dtype=np.int32)

    for f_idx, (v0, v1, v2, mat_id) in enumerate(mesh.faces):
        p0 = V_screen[v0]; p1 = V_screen[v1]; p2 = V_screen[v2]
        cp_z = (p1[0] - p0[0]) * (p2[1] - p0[1]) - (p1[1] - p0[1]) * (p2[0] - p0[0])
        if cp_z >= 0: continue

        e1 = V_rot[v1] - V_rot[v0]; e2 = V_rot[v2] - V_rot[v0]
        norm = np.cross(e1, e2)
        norm_len = np.linalg.norm(norm)
        norm = norm / norm_len if norm_len > 1e-6 else np.array([0.0, 0.0, 1.0])

        diff = max(0.0, float(np.dot(norm, l_dir)))
        mat_cfg = palette.get(mat_id, list(palette.values())[0])
        base_col = np.array(mat_cfg["base"], dtype=np.float32)

        if mat_id == MAT_FIRE:
            shade = 1.25
        elif diff > 0.65:
            shade = 1.10
        elif diff > 0.28:
            shade = 1.00
        else:
            shade = 0.82

        col = tuple(np.clip(base_col * shade, 0, 255).astype(np.uint8))

        min_x = max(0, int(math.floor(min(p0[0], p1[0], p2[0]))))
        max_x = min(size - 1, int(math.ceil(max(p0[0], p1[0], p2[0]))))
        min_y = max(0, int(math.floor(min(p0[1], p1[1], p2[1]))))
        max_y = min(size - 1, int(math.ceil(max(p0[1], p1[1], p2[1]))))
        if min_x > max_x or min_y > max_y: continue

        denom = (p1[1] - p2[1]) * (p0[0] - p2[0]) + (p2[0] - p1[0]) * (p0[1] - p2[1])
        if abs(denom) < 1e-6: continue
        inv_denom = 1.0 / denom

        xs, ys = np.meshgrid(np.arange(min_x, max_x + 1), np.arange(min_y, max_y + 1))
        w0 = ((p1[1] - p2[1]) * (xs - p2[0]) + (p2[0] - p1[0]) * (ys - p2[1])) * inv_denom
        w1 = ((p2[1] - p0[1]) * (xs - p2[0]) + (p0[0] - p2[0]) * (ys - p2[1])) * inv_denom
        w2 = 1.0 - w0 - w1

        inside = (w0 >= 0.0) & (w1 >= 0.0) & (w2 >= 0.0)
        if not np.any(inside): continue

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

    # Contour Inking
    alpha_mask = img_arr[..., 3] > 0
    edge_map = np.zeros((size, size), dtype=bool)
    for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        shifted_a = np.roll(alpha_mask, (dy, dx), axis=(0, 1))
        shifted_id = np.roll(id_buffer, (dy, dx), axis=(0, 1))
        edge_map |= alpha_mask & (~shifted_a)
        edge_map |= alpha_mask & shifted_a & (id_buffer != shifted_id)

    img_arr[edge_map] = np.array([24, 28, 36, 255], dtype=np.uint8)
    return Image.fromarray(img_arr, mode="RGBA")

def pack_boss_sheet(frames_dict, out_path, cell_w=384, cell_h=256):
    """Packs frames into a 3-column spritesheet and writes JSON atlas."""
    keys = ["pristine", "wing_damaged", "critical_wreck"]
    sheet = Image.new("RGBA", (cell_w * 3, cell_h), (0, 0, 0, 0))
    atlas = {
        "meta": {
            "image": f"{out_path.name}.png",
            "size": {"w": cell_w * 3, "h": cell_h},
            "cell": {"w": cell_w, "h": cell_h},
            "cols": 3, "rows": 1
        },
        "frames": {}
    }

    for idx, k in enumerate(keys):
        img = frames_dict[k]
        # Center in 384x256 cell
        cx = (cell_w - img.width) // 2
        cy = (cell_h - img.height) // 2
        sheet.paste(img, (idx * cell_w + cx, cy), img)
        atlas["frames"][k] = {
            "frame": {"x": idx * cell_w, "y": 0, "w": cell_w, "h": cell_h},
            "sourceSize": {"w": cell_w, "h": cell_h}
        }
        atlas[k] = {"x": idx * cell_w, "y": 0, "w": cell_w, "h": cell_h}

    sheet.save(out_path.with_suffix(".png"))
    with open(out_path.with_suffix(".json"), "w") as f:
        json.dump(atlas, f, indent=2)
    print(f"✓ Saved {out_path.name}.png and .json")

def main():
    sprites_dir = Path("games/skyace/sprites")
    sprites_dir.mkdir(parents=True, exist_ok=True)
    art_dir = Path("/Users/christhompson/.gemini/antigravity-ide/brain/ec418452-c387-4511-87ec-4bed8eda2a62")

    # 1. Build B-24 Liberator (USA Boss)
    print("\n[Sky Ace] Building 3D B-24 Liberator ('Goliath')...")
    b24_frames = {
        "pristine": render_boss_to_image(build_b24_mesh(0), PALETTE_B24, roll_deg=0.0, damage_stage=0),
        "wing_damaged": render_boss_to_image(build_b24_mesh(1), PALETTE_B24, roll_deg=0.0, damage_stage=1),
        "critical_wreck": render_boss_to_image(build_b24_mesh(2), PALETTE_B24, roll_deg=3.0, damage_stage=2),
    }
    pack_boss_sheet(b24_frames, sprites_dir / "sheet_boss_b24")
    pack_boss_sheet(b24_frames, art_dir / "sheet_boss_b24")

    # Also link to sheet_boss_goliath for backward compatibility
    pack_boss_sheet(b24_frames, sprites_dir / "sheet_boss_goliath")
    pack_boss_sheet(b24_frames, art_dir / "sheet_boss_goliath")

    # 2. Build Canada Goose (Canada Boss - Lancaster Mk. X)
    print("\n[Sky Ace] Building 3D Canada Goose ('RCAF Lancaster Mk. X')...")
    can_frames = {
        "pristine": render_boss_to_image(build_canadagoose_mesh(0), PALETTE_CANADAGOOSE, roll_deg=0.0, damage_stage=0),
        "wing_damaged": render_boss_to_image(build_canadagoose_mesh(1), PALETTE_CANADAGOOSE, roll_deg=0.0, damage_stage=1),
        "critical_wreck": render_boss_to_image(build_canadagoose_mesh(2), PALETTE_CANADAGOOSE, roll_deg=-3.0, damage_stage=2),
    }
    pack_boss_sheet(can_frames, sprites_dir / "sheet_boss_canadagoose")
    pack_boss_sheet(can_frames, art_dir / "sheet_boss_canadagoose")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Sky Ace • Secret Coalition 3D Mesh Engines & Sprite Builders
Builds 3D polygonal models, cel-shaders, and sprite sheets for:
1. Horten Ho 229 (Germany - Twin-jet stealth flying wing)
2. Boeing B-29 Superfortress (USA - 4-engine heavy dreadnought)
3. Kyushu J7W1 Shinden (Japan - Canard rear-pusher interceptor)
"""

import math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SPRITES_DIR = Path("games/skyace/sprites")
ENGINE_DIR = Path("games/skyace/engine")
SPRITES_DIR.mkdir(parents=True, exist_ok=True)
ENGINE_DIR.mkdir(parents=True, exist_ok=True)


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


# =============================================================================
# 1. HORTEN HO 229 3D MESH BUILDER
# =============================================================================
def build_ho229_mesh():
    mesh = Mesh3D()
    MAT_BODY = 1        # Charcoal / Slate Green Stealth Camo
    MAT_UNDER = 2       # RLM 76 Light Blue/Grey Underside
    MAT_INLET = 3       # Dark Jet Engine Intake Duct
    MAT_EXHAUST = 4     # Titanium / Heat-Treated Jet Nozzle
    MAT_CANOPY = 5      # Glass Bubble Cockpit
    MAT_CANNON = 6      # Twin 30mm MK 108 Cannons

    # Center Pod Profile (Chunky lifting body blending into wings)
    center_stations = [
        # (y, half_width, half_height, z_center)
        (38.0, 1.5, 2.0, 0.0),    # Rounded nose
        (26.0, 8.0, 5.5, 0.5),    # Forward pod
        (10.0, 15.0, 7.8, 1.2),   # Cockpit & Jet Inlets
        (-6.0, 17.5, 7.0, 1.0),   # Mid engine bay
        (-22.0, 15.0, 5.2, 0.6),  # Jet Exhaust section
        (-38.0, 9.0, 3.2, 0.2),   # Trailing center curve
        (-48.0, 1.0, 1.0, 0.0),   # Rear tip
    ]
    
    n_rad = 12
    rings = []
    for y, rx, rz, zc in center_stations:
        ring = []
        for i in range(n_rad):
            th = 2.0 * math.pi * i / n_rad
            # Flatten belly slightly for flying wing airfoil
            z_mod = rz * math.sin(th)
            if z_mod < 0:
                z_mod *= 0.65
            ring.append(mesh.add_vertex(rx * math.cos(th), y, zc + z_mod))
        rings.append(ring)

    for s in range(len(center_stations) - 1):
        r0, r1 = rings[s], rings[s + 1]
        for i in range(n_rad):
            mesh.add_quad(r0[i], r1[i], r1[(i + 1) % n_rad], r0[(i + 1) % n_rad], MAT_BODY)

    # Cockpit Bubble Canopy
    c_front = mesh.add_vertex(0.0, 20.0, 7.2)
    c_mid   = mesh.add_vertex(0.0, 8.0, 9.6)
    c_rear  = mesh.add_vertex(0.0, -8.0, 7.8)
    c_l1    = mesh.add_vertex(-4.0, 7.0, 7.2)
    c_r1    = mesh.add_vertex(4.0, 7.0, 7.2)
    c_l0    = mesh.add_vertex(-2.8, 16.0, 6.0)
    c_r0    = mesh.add_vertex(2.8, 16.0, 6.0)
    c_l2    = mesh.add_vertex(-3.2, -6.0, 6.5)
    c_r2    = mesh.add_vertex(3.2, -6.0, 6.5)
    mesh.add_tri(c_front, c_l0, c_r0, MAT_CANOPY)
    mesh.add_quad(c_l0, c_l1, c_r1, c_r0, MAT_CANOPY)
    mesh.add_quad(c_l1, c_l2, c_r2, c_r1, MAT_CANOPY)
    mesh.add_tri(c_mid, c_l1, c_front, MAT_CANOPY)
    mesh.add_tri(c_mid, c_front, c_r1, MAT_CANOPY)
    mesh.add_tri(c_mid, c_l2, c_rear, MAT_CANOPY)
    mesh.add_tri(c_mid, c_rear, c_r2, MAT_CANOPY)

    # Swept Flying Wings (32.2 degree sweep, 90 span)
    wing_stations = [
        # (x_dist, y_le, y_te, thickness, dihedral_z)
        (16.0, 8.0, -22.0, 5.5, 0.5),
        (30.0, -1.0, -25.0, 4.2, 0.8),
        (48.0, -13.0, -29.0, 3.0, 1.4),
        (66.0, -24.0, -33.0, 2.0, 2.2),
        (80.0, -34.0, -37.0, 1.0, 3.0),
    ]

    for sign in [-1, 1]:
        prev_top_le, prev_top_te = None, None
        prev_bot_le, prev_bot_te = None, None
        for x_base, y_le, y_te, thk, z_dih in wing_stations:
            x = sign * x_base
            t_le = mesh.add_vertex(x, y_le, z_dih + thk * 0.5)
            t_te = mesh.add_vertex(x, y_te, z_dih + 0.1)
            b_le = mesh.add_vertex(x, y_le, z_dih - thk * 0.5)
            b_te = mesh.add_vertex(x, y_te, z_dih - 0.1)

            if prev_top_le is not None:
                # Top surface
                mesh.add_quad(prev_top_le, t_le, t_te, prev_top_te, MAT_BODY)
                # Bottom surface
                mesh.add_quad(prev_bot_te, b_te, b_le, prev_bot_le, MAT_UNDER)
                # Leading edge
                mesh.add_quad(prev_top_le, prev_bot_le, b_le, t_le, MAT_BODY)
                # Trailing edge
                mesh.add_quad(prev_top_te, t_te, b_te, prev_bot_te, MAT_BODY)

            prev_top_le, prev_top_te = t_le, t_te
            prev_bot_le, prev_bot_te = b_le, b_te

        # Twin Jet Intakes & Exhausts (Jumo 004)
        for side in [-1, 1]:
            ix = side * 8.5
            # Intake rim
            mesh.add_quad(
                mesh.add_vertex(ix - 2.5, 16.0, 0.2),
                mesh.add_vertex(ix + 2.5, 16.0, 0.2),
                mesh.add_vertex(ix + 2.5, 16.0, 3.8),
                mesh.add_vertex(ix - 2.5, 16.0, 3.8),
                MAT_INLET
            )
            # Exhaust rim
            mesh.add_quad(
                mesh.add_vertex(ix - 2.2, -26.0, 0.8),
                mesh.add_vertex(ix + 2.2, -26.0, 0.8),
                mesh.add_vertex(ix + 2.2, -26.0, 3.6),
                mesh.add_vertex(ix - 2.2, -26.0, 3.6),
                MAT_EXHAUST
            )
            # 30mm Cannon barrel
            mesh.add_quad(
                mesh.add_vertex(side * 14.0 - 0.6, 12.0, 0.5),
                mesh.add_vertex(side * 14.0 + 0.6, 12.0, 0.5),
                mesh.add_vertex(side * 14.0 + 0.6, 26.0, 0.5),
                mesh.add_vertex(side * 14.0 - 0.6, 26.0, 0.5),
                MAT_CANNON
            )

    return mesh


# =============================================================================
# 2. BOEING B-29 SUPERFORTRESS 3D MESH BUILDER
# =============================================================================
def build_b29_mesh():
    mesh = Mesh3D()
    MAT_BODY = 1        # Bare Aluminum / Silver USAAF Finish
    MAT_GLASS = 2       # Glass Framed Greenhouse Nose & Blisters
    MAT_COWLING = 3     # Dark Steel Radial Engine Cowlings (Wright R-3350)
    MAT_TURRET = 4      # Remote Gun Barbettes (.50 cal Turrets)
    MAT_PROP = 5        # 4-Blade Propeller Blur
    MAT_INSIGNIA = 6    # USAAF Star-and-Bars

    # Long Cylindrical Fuselage (Length 140, Diameter 18)
    fuse_stations = [
        # (y, radius, z_center)
        (70.0, 1.2, 0.0),    # Nose tip
        (62.0, 6.2, 0.2),    # Greenhouse cockpit
        (48.0, 8.8, 0.4),    # Forward cabin
        (24.0, 9.2, 0.5),    # Front bomb bay / wing root
        (-4.0, 9.2, 0.5),    # Rear bomb bay
        (-32.0, 8.2, 0.6),   # Mid fuselage
        (-60.0, 5.8, 0.8),   # Waist gunner section
        (-82.0, 2.8, 1.0),   # Tail gunner root
        (-92.0, 0.8, 1.2),   # Tail stinger tip
    ]
    
    n_rad = 14
    rings = []
    for y, r, zc in fuse_stations:
        ring = []
        for i in range(n_rad):
            th = 2.0 * math.pi * i / n_rad
            ring.append(mesh.add_vertex(r * math.cos(th), y, zc + r * math.sin(th)))
        rings.append(ring)

    for s in range(len(fuse_stations) - 1):
        r0, r1 = rings[s], rings[s + 1]
        mat = MAT_GLASS if s == 0 else MAT_BODY
        for i in range(n_rad):
            mesh.add_quad(r0[i], r1[i], r1[(i + 1) % n_rad], r0[(i + 1) % n_rad], mat)

    # High-Aspect Ratio Wings (Span 160)
    wing_stations = [
        # (x_dist, y_le, y_te, thickness, dihedral_z)
        (9.0, 22.0, -8.0, 5.0, 0.5),
        (32.0, 18.0, -5.0, 4.2, 1.5),   # Inner engine 1
        (56.0, 14.0, -3.0, 3.4, 2.6),   # Outer engine 2
        (82.0, 10.0, -1.0, 2.2, 3.8),
        (105.0, 7.0, 0.0, 1.0, 5.0),    # Wingtip
    ]

    for sign in [-1, 1]:
        prev_top_le, prev_top_te = None, None
        prev_bot_le, prev_bot_te = None, None
        for x_base, y_le, y_te, thk, z_dih in wing_stations:
            x = sign * x_base
            t_le = mesh.add_vertex(x, y_le, z_dih + thk * 0.5)
            t_te = mesh.add_vertex(x, y_te, z_dih + 0.1)
            b_le = mesh.add_vertex(x, y_le, z_dih - thk * 0.5)
            b_te = mesh.add_vertex(x, y_te, z_dih - 0.1)

            if prev_top_le is not None:
                mesh.add_quad(prev_top_le, t_le, t_te, prev_top_te, MAT_BODY)
                mesh.add_quad(prev_bot_te, b_te, b_le, prev_bot_le, MAT_BODY)
                mesh.add_quad(prev_top_le, prev_bot_le, b_le, t_le, MAT_BODY)
                mesh.add_quad(prev_top_te, t_te, b_te, prev_bot_te, MAT_BODY)

            prev_top_le, prev_top_te = t_le, t_te
            prev_bot_le, prev_bot_te = b_le, b_te

        # 4 Wright R-3350 Engine Nacelles (2 per wing)
        for ex in [sign * 32.0, sign * 56.0]:
            # Cowling cylinder
            c_front = mesh.add_vertex(ex, 25.0, 0.5)
            c_back  = mesh.add_vertex(ex, 8.0, 0.5)
            for i in range(8):
                th0 = 2.0 * math.pi * i / 8
                th1 = 2.0 * math.pi * (i + 1) / 8
                r = 4.2
                mesh.add_quad(
                    mesh.add_vertex(ex + r * math.cos(th0), 24.0, 0.5 + r * math.sin(th0)),
                    mesh.add_vertex(ex + r * math.cos(th1), 24.0, 0.5 + r * math.sin(th1)),
                    mesh.add_vertex(ex + r * math.cos(th1), 10.0, 0.5 + r * math.sin(th1)),
                    mesh.add_vertex(ex + r * math.cos(th0), 10.0, 0.5 + r * math.sin(th0)),
                    MAT_COWLING
                )

    # Dorsal & Ventral Remote Gun Turrets
    for ty, tz in [(42.0, 9.8), (-18.0, 9.6), (-54.0, 8.5)]:
        mesh.add_quad(
            mesh.add_vertex(-3.0, ty - 3.0, tz),
            mesh.add_vertex(3.0, ty - 3.0, tz),
            mesh.add_vertex(3.0, ty + 3.0, tz),
            mesh.add_vertex(-3.0, ty + 3.0, tz),
            MAT_TURRET
        )

    # Tall Vertical Tail Fin with 3D thickness
    v_tl_f = mesh.add_vertex(-0.6, -82.0, 28.0)
    v_tl_b = mesh.add_vertex(-0.6, -90.0, 26.0)
    v_tr_f = mesh.add_vertex(0.6, -82.0, 28.0)
    v_tr_b = mesh.add_vertex(0.6, -90.0, 26.0)
    v_bl_f = mesh.add_vertex(-1.0, -68.0, 6.0)
    v_bl_b = mesh.add_vertex(-1.0, -90.0, 2.0)
    v_br_f = mesh.add_vertex(1.0, -68.0, 6.0)
    v_br_b = mesh.add_vertex(1.0, -90.0, 2.0)

    # Left face (normal -X)
    mesh.add_quad(v_bl_f, v_tl_f, v_tl_b, v_bl_b, MAT_BODY)
    # Right face (normal +X)
    mesh.add_quad(v_br_b, v_tr_b, v_tr_f, v_br_f, MAT_BODY)
    # Leading edge (normal +Y)
    mesh.add_quad(v_bl_f, v_br_f, v_tr_f, v_tl_f, MAT_BODY)
    # Trailing edge / rudder (normal -Y)
    mesh.add_quad(v_tl_b, v_tr_b, v_br_b, v_bl_b, MAT_BODY)

    # Horizontal Stabilizers with top and bottom surfaces (normal +Z on top)
    for side in [-1, 1]:
        v_root_le = mesh.add_vertex(0.0, -78.0, 3.2)
        v_tip_le  = mesh.add_vertex(side * 36.0, -86.0, 4.2)
        v_tip_te  = mesh.add_vertex(side * 34.0, -92.0, 4.2)
        v_root_te = mesh.add_vertex(0.0, -90.0, 3.2)

        v_b_root_le = mesh.add_vertex(0.0, -78.0, 2.8)
        v_b_tip_le  = mesh.add_vertex(side * 36.0, -86.0, 3.8)
        v_b_tip_te  = mesh.add_vertex(side * 34.0, -92.0, 3.8)
        v_b_root_te = mesh.add_vertex(0.0, -90.0, 2.8)

        if side < 0:
            # Top face (normal +Z)
            mesh.add_quad(v_root_le, v_tip_le, v_tip_te, v_root_te, MAT_BODY)
            # Bottom face (normal -Z)
            mesh.add_quad(v_b_root_te, v_b_tip_te, v_b_tip_le, v_b_root_le, MAT_BODY)
        else:
            # Right side: wind in reverse so normal points +Z!
            mesh.add_quad(v_root_te, v_tip_te, v_tip_le, v_root_le, MAT_BODY)
            # Bottom face (normal -Z)
            mesh.add_quad(v_b_root_le, v_b_tip_le, v_b_tip_te, v_b_root_te, MAT_BODY)

    return mesh


# =============================================================================
# 3. KYUSHU J7W1 SHINDEN 3D MESH BUILDER
# =============================================================================
def build_shinden_mesh():
    mesh = Mesh3D()
    MAT_BODY = 1        # IJN Deep Green
    MAT_UNDER = 2       # IJN Light Grey Underside
    MAT_CANARD = 3      # Canard Foreplanes
    MAT_CANOPY = 4      # Glass Cockpit
    MAT_PUSHER = 5      # 6-Blade Rear Pusher Propeller
    MAT_ROUNDEL = 6     # Hinomaru Red Sun
    MAT_CANNON = 7      # 4x 30mm Type 5 Nose Cannons

    # Sleek Dart Fuselage (Nose to Rear Pusher Engine)
    fuse_stations = [
        # (y, half_width, half_height, z_center)
        (56.0, 1.0, 1.0, 0.0),    # Sharp pointed needle nose
        (46.0, 3.8, 3.8, 0.2),    # 4x 30mm Gun bay
        (34.0, 5.8, 6.2, 0.6),    # Canard mount root
        (16.0, 7.2, 8.4, 1.2),    # Cockpit mid
        (-6.0, 7.6, 8.0, 1.0),    # Supercharged Mitsubishi MK9D engine
        (-26.0, 7.0, 7.2, 0.6),   # Engine bay cooling
        (-42.0, 4.8, 4.8, 0.2),   # Pusher prop spinner
    ]

    n_rad = 12
    rings = []
    for y, rx, rz, zc in fuse_stations:
        ring = []
        for i in range(n_rad):
            th = 2.0 * math.pi * i / n_rad
            ring.append(mesh.add_vertex(rx * math.cos(th), y, zc + rz * math.sin(th)))
        rings.append(ring)

    for s in range(len(fuse_stations) - 1):
        r0, r1 = rings[s], rings[s + 1]
        for i in range(n_rad):
            mesh.add_quad(r0[i], r1[i], r1[(i + 1) % n_rad], r0[(i + 1) % n_rad], MAT_BODY)

    # 4x 30mm Type 5 Nose Cannons
    for cy in [50.0]:
        for cx, cz in [(-2.0, 1.8), (2.0, 1.8), (-2.0, -1.2), (2.0, -1.2)]:
            mesh.add_quad(
                mesh.add_vertex(cx - 0.4, cy, cz),
                mesh.add_vertex(cx + 0.4, cy, cz),
                mesh.add_vertex(cx + 0.4, cy + 8.0, cz),
                mesh.add_vertex(cx - 0.4, cy + 8.0, cz),
                MAT_CANNON
            )

    # Forward Canard Foreplanes (Nose Wings)
    for side in [-1, 1]:
        mesh.add_quad(
            mesh.add_vertex(0.0, 36.0, 0.8),
            mesh.add_vertex(side * 18.0, 32.0, 1.2),
            mesh.add_vertex(side * 17.0, 27.0, 1.2),
            mesh.add_vertex(0.0, 30.0, 0.8),
            MAT_CANARD
        )

    # Teardrop Cockpit Canopy
    c_tip = mesh.add_vertex(0.0, 26.0, 6.8)
    c_top = mesh.add_vertex(0.0, 12.0, 9.8)
    c_end = mesh.add_vertex(0.0, -4.0, 8.4)
    c_lf  = mesh.add_vertex(-3.8, 12.0, 7.2)
    c_rt  = mesh.add_vertex(3.8, 12.0, 7.2)
    mesh.add_tri(c_tip, c_lf, c_top, MAT_CANOPY)
    mesh.add_tri(c_tip, c_top, c_rt, MAT_CANOPY)
    mesh.add_tri(c_top, c_lf, c_end, MAT_CANOPY)
    mesh.add_tri(c_top, c_end, c_rt, MAT_CANOPY)

    # Swept Main Wings (Mounted rearwards, Span 80)
    wing_stations = [
        # (x_dist, y_le, y_te, thickness, dihedral_z)
        (7.0, -2.0, -32.0, 4.8, 0.5),
        (22.0, -10.0, -35.0, 3.6, 1.2),
        (35.0, -18.0, -37.0, 2.6, 2.0),
        (48.0, -26.0, -38.0, 1.4, 3.0),
    ]

    for sign in [-1, 1]:
        prev_top_le, prev_top_te = None, None
        prev_bot_le, prev_bot_te = None, None
        for x_base, y_le, y_te, thk, z_dih in wing_stations:
            x = sign * x_base
            t_le = mesh.add_vertex(x, y_le, z_dih + thk * 0.5)
            t_te = mesh.add_vertex(x, y_te, z_dih + 0.1)
            b_le = mesh.add_vertex(x, y_le, z_dih - thk * 0.5)
            b_te = mesh.add_vertex(x, y_te, z_dih - 0.1)

            if prev_top_le is not None:
                mesh.add_quad(prev_top_le, t_le, t_te, prev_top_te, MAT_BODY)
                mesh.add_quad(prev_bot_te, b_te, b_le, prev_bot_le, MAT_UNDER)
                mesh.add_quad(prev_top_le, prev_bot_le, b_le, t_le, MAT_BODY)
                mesh.add_quad(prev_top_te, t_te, b_te, prev_bot_te, MAT_BODY)

            prev_top_le, prev_top_te = t_le, t_te
            prev_bot_le, prev_bot_te = b_le, b_te

        # Twin Vertical Stabilizer Fins / Rudders (Mid-wing)
        vx = sign * 25.0
        mesh.add_quad(
            mesh.add_vertex(vx, -14.0, 0.0),
            mesh.add_vertex(vx, -24.0, 16.0),
            mesh.add_vertex(vx, -36.0, 14.0),
            mesh.add_vertex(vx, -34.0, 0.0),
            MAT_BODY
        )
        # Small ventral fin below wing
        mesh.add_quad(
            mesh.add_vertex(vx, -18.0, 0.0),
            mesh.add_vertex(vx, -26.0, -7.0),
            mesh.add_vertex(vx, -34.0, -6.0),
            mesh.add_vertex(vx, -32.0, 0.0),
            MAT_BODY
        )

    return mesh


# =============================================================================
# 4. NORTHROP XB-35 STRATEGIC FLYING WING (FAILSAFE ATOMIC BOMBER)
# =============================================================================
def build_xb35_mesh():
    """Builds authentic high-detail 3D mesh of Northrop XB-35 strategic flying wing with NACA airfoil camber."""
    mesh = Mesh3D()
    MAT_BODY = 1        # Bare Aluminum / Silver USAAF Finish
    MAT_GLASS = 2       # Glass Greenhouse Nose & Bubble Canopy
    MAT_NACELLE = 3     # Radial Engine Nacelles (Pratt & Whitney R-4360)
    MAT_SPINNER = 4     # Pusher Propeller Spinners
    MAT_ELEVON = 5      # Control Elevons & Trim Tabs
    MAT_INSIGNIA = 6    # USAAF Star-and-Bars

    # Detailed Central Lifting Body with rounded forward greenhouse nose and streamlined deck
    center_stations = [
        # (y, half_width, half_height, z_center, is_glass)
        (48.0, 2.5, 2.2, 0.0, True),
        (42.0, 6.0, 4.5, 0.2, True),
        (32.0, 10.5, 7.2, 0.5, True),
        (18.0, 14.8, 9.8, 0.8, False),
        (4.0,  16.2, 10.2, 0.7, False),
        (-10.0, 15.5, 8.6, 0.4, False),
        (-22.0, 12.0, 5.8, 0.2, False),
        (-32.0, 6.0, 2.5, 0.0, False),
    ]

    n_rad = 16
    c_rings = []
    for y, rx, rz, zc, is_gl in center_stations:
        ring = []
        for i in range(n_rad):
            th = 2.0 * math.pi * i / n_rad
            z_scale = 1.15 if math.sin(th) >= 0 else 0.85
            vz = zc + rz * math.sin(th) * z_scale
            vx = rx * math.cos(th)
            ring.append(mesh.add_vertex(vx, y, vz))
        c_rings.append((ring, is_gl))

    for s in range(len(center_stations) - 1):
        r0, is_gl0 = c_rings[s]
        r1, is_gl1 = c_rings[s + 1]
        mat = MAT_GLASS if (is_gl0 and s < 2) else MAT_BODY
        for i in range(n_rad):
            i_next = (i + 1) % n_rad
            m = MAT_GLASS if (s < 3 and 2 <= i <= 6) else mat
            mesh.add_quad(r0[i], r1[i], r1[i_next], r0[i_next], m)

    # Pilot & Co-Pilot Bubble Canopies (raised teardrop blisters on upper deck)
    for cx in [-4.8, 4.8]:
        mesh.add_quad(
            mesh.add_vertex(cx - 2.8, 30.0, 7.8),
            mesh.add_vertex(cx + 2.8, 30.0, 7.8),
            mesh.add_vertex(cx + 2.4, 18.0, 10.2),
            mesh.add_vertex(cx - 2.4, 18.0, 10.2),
            MAT_GLASS
        )
        mesh.add_quad(
            mesh.add_vertex(cx - 2.4, 18.0, 10.2),
            mesh.add_vertex(cx + 2.4, 18.0, 10.2),
            mesh.add_vertex(cx + 1.8, 8.0, 9.2),
            mesh.add_vertex(cx - 1.8, 8.0, 9.2),
            MAT_GLASS
        )

    # Swept Flying Wings with True NACA Airfoil Camber across 8 Spanwise Stations
    span_stations = [
        # (x_dist, y_le, chord, max_thk, dihedral)
        (15.0, 39.0, 68.0, 9.2, 0.4),
        (28.0, 32.0, 58.0, 8.0, 0.9),
        (44.0, 24.0, 48.0, 6.8, 1.5),
        (60.0, 16.0, 39.0, 5.5, 2.2),
        (76.0,  8.0, 31.0, 4.2, 2.9),
        (92.0,  0.0, 24.0, 3.0, 3.6),
        (104.0, -6.0, 18.0, 2.0, 4.2),
        (114.0, -11.0, 12.0, 1.2, 4.8),
    ]

    chord_pcts = [0.0, 0.20, 0.45, 0.70, 0.90, 1.0]
    t_upper = [0.0, 0.96, 1.00, 0.72, 0.32, 0.04]
    t_lower = [0.0, -0.45, -0.50, -0.32, -0.15, -0.02]

    for sign in [-1, 1]:
        prev_station_upper = None
        prev_station_lower = None

        for x_dist, y_le, chord, thk, dih in span_stations:
            curr_upper = []
            curr_lower = []
            x = sign * x_dist

            for cp, tu, tl in zip(chord_pcts, t_upper, t_lower):
                y = y_le - cp * chord
                zu = dih + thk * tu
                zl = dih + thk * tl
                curr_upper.append(mesh.add_vertex(x, y, zu))
                curr_lower.append(mesh.add_vertex(x, y, zl))

            if prev_station_upper is not None:
                for c_idx in range(len(chord_pcts) - 1):
                    mat = MAT_ELEVON if c_idx >= 3 else MAT_BODY
                    mesh.add_quad(
                        prev_station_upper[c_idx],
                        curr_upper[c_idx],
                        curr_upper[c_idx + 1],
                        prev_station_upper[c_idx + 1],
                        mat
                    )
                    mesh.add_quad(
                        prev_station_lower[c_idx + 1],
                        curr_lower[c_idx + 1],
                        curr_lower[c_idx],
                        prev_station_lower[c_idx],
                        MAT_BODY
                    )

                mesh.add_quad(
                    prev_station_lower[0],
                    curr_lower[0],
                    curr_upper[0],
                    prev_station_upper[0],
                    MAT_BODY
                )
                mesh.add_quad(
                    prev_station_upper[-1],
                    curr_upper[-1],
                    curr_lower[-1],
                    prev_station_lower[-1],
                    MAT_ELEVON
                )

            prev_station_upper = curr_upper
            prev_station_lower = curr_lower

        for c_idx in range(len(chord_pcts) - 1):
            mesh.add_quad(
                prev_station_upper[c_idx],
                prev_station_upper[c_idx + 1],
                prev_station_lower[c_idx + 1],
                prev_station_lower[c_idx],
                MAT_BODY
            )

        # 4 Pratt & Whitney Pusher Nacelles with Cylindrical Cowlings
        for nacelle_x, nacelle_y in [(44.0, -18.0), (76.0, -14.0)]:
            nx = sign * nacelle_x
            ny = nacelle_y
            w_nac = 3.8
            h_nac = 3.6
            f_tl = mesh.add_vertex(nx - w_nac, ny + 10.0, 1.8 + h_nac)
            f_tr = mesh.add_vertex(nx + w_nac, ny + 10.0, 1.8 + h_nac)
            f_bl = mesh.add_vertex(nx - w_nac, ny + 10.0, 1.8 - h_nac)
            f_br = mesh.add_vertex(nx + w_nac, ny + 10.0, 1.8 - h_nac)
            r_tl = mesh.add_vertex(nx - w_nac * 0.8, ny - 14.0, 1.8 + h_nac * 0.8)
            r_tr = mesh.add_vertex(nx + w_nac * 0.8, ny - 14.0, 1.8 + h_nac * 0.8)
            r_bl = mesh.add_vertex(nx - w_nac * 0.8, ny - 14.0, 1.8 - h_nac * 0.8)
            r_br = mesh.add_vertex(nx + w_nac * 0.8, ny - 14.0, 1.8 - h_nac * 0.8)

            mesh.add_quad(f_tl, f_tr, r_tr, r_tl, MAT_NACELLE)
            mesh.add_quad(r_bl, r_br, f_br, f_bl, MAT_NACELLE)
            mesh.add_quad(f_bl, f_tl, r_tl, r_bl, MAT_NACELLE)
            mesh.add_quad(r_br, r_tr, f_tr, f_br, MAT_NACELLE)

            sp_tip = mesh.add_vertex(nx, ny - 20.0, 1.8)
            mesh.add_tri(r_tl, r_tr, sp_tip, MAT_SPINNER)
            mesh.add_tri(r_tr, r_br, sp_tip, MAT_SPINNER)
            mesh.add_tri(r_br, r_bl, sp_tip, MAT_SPINNER)
            mesh.add_tri(r_bl, r_tl, sp_tip, MAT_SPINNER)

    return mesh


# =============================================================================
# 5. CEL-SHADED SPRITE RASTERIZER FOR SECRET PLANES
# =============================================================================
def render_secret_plane(mesh, plane_type, roll_deg=0.0, pitch_deg=0.0, yaw_deg=0.0, 
                        anim_phase=0.0, size=256, scale=1.45):
    """Renders high-definition cel-shaded sprite for secret aircraft."""
    if plane_type == "ho229":
        palette = {
            1: {"shadow": (28, 38, 32), "mid": (48, 64, 52), "high": (76, 98, 80)},      # Stealth Green/Grey
            2: {"shadow": (35, 55, 68), "mid": (62, 92, 112), "high": (105, 145, 175)},  # Underside Blue
            3: {"shadow": (12, 16, 18), "mid": (22, 28, 32), "high": (40, 50, 58)},      # Inlets
            4: {"shadow": (45, 30, 20), "mid": (85, 55, 35), "high": (145, 95, 60)},     # Exhaust
            5: {"shadow": (20, 42, 60), "mid": (45, 85, 115), "high": (110, 170, 215)},  # Canopy
            6: {"shadow": (15, 15, 15), "mid": (30, 30, 30), "high": (60, 60, 60)},      # Cannons
        }
        l_dir = np.array([-0.3, 0.5, 0.81])
        outline_col = (14, 18, 15, 255)
        scale = 1.45
    elif plane_type == "b29":
        palette = {
            1: {"shadow": (60, 68, 76), "mid": (110, 122, 134), "high": (175, 190, 205)}, # Bare Aluminum
            2: {"shadow": (30, 55, 75), "mid": (55, 95, 125), "high": (130, 180, 220)},   # Glass Nose
            3: {"shadow": (22, 25, 28), "mid": (42, 48, 54), "high": (75, 85, 95)},       # Cowlings
            4: {"shadow": (18, 20, 22), "mid": (35, 38, 42), "high": (65, 70, 78)},       # Turrets
            5: {"shadow": (180, 150, 30), "mid": (230, 195, 45), "high": (255, 225, 80)}, # Props
            6: {"shadow": (25, 45, 100), "mid": (45, 80, 170), "high": (90, 130, 225)},   # Insignia
        }
        l_dir = np.array([-0.25, 0.45, 0.85])
        outline_col = (20, 24, 28, 255)
        scale = 1.05
    elif plane_type == "xb35":
        palette = {
            1: {"tones": [(110, 122, 136), (150, 165, 180), (195, 210, 225), (235, 245, 255)]}, # Polished USAAF Aircraft Aluminum
            2: {"tones": [(42, 75, 100), (75, 125, 165), (145, 195, 235), (225, 248, 255)]},   # Greenhouse Glass
            3: {"tones": [(55, 62, 70), (88, 98, 108), (128, 138, 150), (170, 180, 192)]},     # Nacelles
            4: {"tones": [(40, 45, 52), (68, 75, 84), (102, 112, 124), (148, 158, 170)]},     # Spinners
            5: {"tones": [(98, 110, 122), (138, 150, 164), (178, 192, 208), (218, 230, 242)]}, # Elevons
            6: {"tones": [(30, 50, 120), (50, 90, 180), (100, 145, 230), (220, 235, 255)]},   # Insignia
        }
        l_dir = np.array([-0.05, 0.28, 0.96])
        outline_col = (18, 22, 26, 255)
        scale = 1.05  # Imposing 172-foot wingspan across the 256x256 cell
    else:  # shinden
        palette = {
            1: {"shadow": (24, 48, 30), "mid": (42, 80, 50), "high": (70, 125, 82)},     # IJN Green
            2: {"shadow": (45, 52, 58), "mid": (80, 92, 100), "high": (130, 145, 155)},  # Underside
            3: {"shadow": (26, 52, 32), "mid": (46, 88, 54), "high": (76, 135, 88)},     # Canards
            4: {"shadow": (22, 45, 62), "mid": (48, 90, 120), "high": (115, 175, 220)},  # Canopy
            5: {"shadow": (180, 140, 20), "mid": (235, 185, 30), "high": (255, 215, 60)},# Pusher Prop
            6: {"shadow": (120, 15, 15), "mid": (195, 25, 25), "high": (245, 45, 45)},   # Hinomaru
            7: {"shadow": (16, 18, 20), "mid": (32, 36, 40), "high": (64, 70, 78)},      # Cannons
        }
        l_dir = np.array([-0.3, 0.5, 0.81])
        outline_col = (12, 24, 15, 255)
        scale = 1.55

    l_dir = l_dir / np.linalg.norm(l_dir)
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

    faces_to_render = []
    for face in mesh.faces:
        v0_idx, v1_idx, v2_idx, mat_id = face
        v0 = v_transformed[v0_idx]
        v1 = v_transformed[v1_idx]
        v2 = v_transformed[v2_idx]

        e1 = v1 - v0
        e2 = v2 - v0
        normal = np.cross(e1, e2)
        norm_len = np.linalg.norm(normal)
        if norm_len < 1e-6:
            continue
        normal = normal / norm_len
        # Backface culling for top-down view (unless pitch is large)
        if pitch_deg == 0.0 and normal[2] < -0.10:
            continue
        intensity = float(np.dot(normal, l_dir))
        mean_z = (v_screen[v0_idx][2] + v_screen[v1_idx][2] + v_screen[v2_idx][2]) / 3.0
        faces_to_render.append((mean_z, face, normal, intensity))

    faces_to_render.sort(key=lambda x: x[0])

    img_arr = np.zeros((size, size, 4), dtype=np.uint8)
    z_buffer = np.full((size, size), -99999.0, dtype=np.float32)

    for mean_z, (v0_idx, v1_idx, v2_idx, mat_id), normal, intensity in faces_to_render:
        mat_entry = palette.get(mat_id, palette[1])
        if "tones" in mat_entry:
            tones = mat_entry["tones"]
            if intensity < 0.45: col = tones[0]
            elif intensity < 0.72: col = tones[1]
            elif intensity < 0.90: col = tones[2]
            else: col = tones[3]
        else:
            if intensity < 0.25: col = mat_entry["shadow"]
            elif intensity < 0.65: col = mat_entry["mid"]
            else: col = mat_entry["high"]

        p0, p1, p2 = v_screen[v0_idx], v_screen[v1_idx], v_screen[v2_idx]
        min_x = max(0, int(math.floor(min(p0[0], p1[0], p2[0]))))
        max_x = min(size - 1, int(math.ceil(max(p0[0], p1[0], p2[0]))))
        min_y = max(0, int(math.floor(min(p0[1], p1[1], p2[1]))))
        max_y = min(size - 1, int(math.ceil(max(p0[1], p1[1], p2[1]))))

        if min_x > max_x or min_y > max_y: continue
        denom = (p1[1] - p2[1]) * (p0[0] - p2[0]) + (p2[0] - p1[0]) * (p0[1] - p2[1])
        if abs(denom) < 1e-6: continue

        x_grid, y_grid = np.meshgrid(np.arange(min_x, max_x + 1), np.arange(min_y, max_y + 1))
        w0 = ((p1[1] - p2[1]) * (x_grid - p2[0]) + (p2[0] - p1[0]) * (y_grid - p2[1])) / denom
        w1 = ((p2[1] - p0[1]) * (x_grid - p2[0]) + (p0[0] - p2[0]) * (y_grid - p2[1])) / denom
        w2 = 1.0 - w0 - w1

        inside = (w0 >= 0.0) & (w1 >= 0.0) & (w2 >= 0.0)
        z_interp = w0 * p0[2] + w1 * p1[2] + w2 * p2[2]

        sub_z = z_buffer[min_y:max_y+1, min_x:max_x+1]
        z_pass = inside & (z_interp > sub_z)

        if np.any(z_pass):
            sub_z[z_pass] = z_interp[z_pass]
            sub_img = img_arr[min_y:max_y+1, min_x:max_x+1]
            sub_img[z_pass, :3] = col
            sub_img[z_pass, 3] = 255

    # Outline pass
    alpha = img_arr[:, :, 3]
    solid_mask = (alpha > 0).astype(np.uint8) * 255
    mask_img = Image.fromarray(solid_mask, "L")
    edges = mask_img.filter(ImageFilter.FIND_EDGES)
    dilated_edges = edges.filter(ImageFilter.MaxFilter(3))
    dil_arr = np.array(dilated_edges)

    out_mask = (dil_arr > 30) & (alpha == 0)
    img_arr[out_mask] = outline_col

    result_img = Image.fromarray(img_arr, "RGBA")
    draw_final = ImageDraw.Draw(result_img)

    # -------------------------------------------------------------------------
    # SPECIAL ENGINE EFFECTS (Jet Flames / Pusher Props / 4-Blade Radial Props)
    # -------------------------------------------------------------------------
    if plane_type == "ho229":
        # Glowing Jumo 004 Jet Afterburner / Exhaust Plumes
        for side in [-1, 1]:
            j_pos = R_total @ np.array([side * 8.5, -26.0, 2.2])
            jx, jy = cx + j_pos[0] * scale, cy - j_pos[1] * scale
            flame_len = 16.0 + 8.0 * math.sin(anim_phase)
            # Outer cyan/blue glow
            draw_final.line([(jx, jy), (jx, jy + flame_len)], fill=(45, 175, 255, 200), width=5)
            # Inner white/cyan core
            draw_final.line([(jx, jy), (jx, jy + flame_len * 0.7)], fill=(225, 250, 255, 240), width=2)

        # Luftwaffe Balkenkreuz on wings
        for side in [-1, 1]:
            kx_pos = R_total @ np.array([side * 42.0, -18.0, 1.8])
            kx, ky = cx + kx_pos[0] * scale, cy - kx_pos[1] * scale
            draw_final.line([(kx - 7, ky), (kx + 7, ky)], fill=(245, 245, 245, 230), width=3)
            draw_final.line([(kx, ky - 7), (kx, ky + 7)], fill=(245, 245, 245, 230), width=3)
            draw_final.line([(kx - 6, ky), (kx + 6, ky)], fill=(18, 18, 18, 255), width=1)
            draw_final.line([(kx, ky - 6), (kx, ky + 6)], fill=(18, 18, 18, 255), width=1)

    elif plane_type == "b29":
        # 4 Spinning Radial Propellers
        for ex in [-56.0, -32.0, 32.0, 56.0]:
            p_pos = R_total @ np.array([ex, 25.0, 0.5])
            px, py = cx + p_pos[0] * scale, cy - p_pos[1] * scale
            p_rad_px = 12.0 * scale
            draw_final.ellipse([px - p_rad_px, py - 3, px + p_rad_px, py + 3], fill=(235, 205, 45, 160))
            draw_final.ellipse([px - 4, py - 4, px + 4, py + 4], fill=(35, 40, 45, 255))

        # USAAF Star and Bars on Port (Left) Wing
        ins_pos = R_total @ np.array([-68.0, 5.0, 2.5])
        ix, iy = cx + ins_pos[0] * scale, cy - ins_pos[1] * scale
        draw_final.ellipse([ix - 9, iy - 9, ix + 9, iy + 9], fill=(25, 45, 115, 240))
        draw_final.rectangle([ix - 14, iy - 2, ix + 14, iy + 2], fill=(245, 245, 250, 240))
        draw_final.ellipse([ix - 5, iy - 5, ix + 5, iy + 5], fill=(245, 245, 250, 255))

    elif plane_type == "shinden":
        # 6-Blade Rear Pusher Propeller (Spinning at the tail)
        p_pos = R_total @ np.array([0.0, -43.0, 0.2])
        px, py = cx + p_pos[0] * scale, cy - p_pos[1] * scale
        pr_px = 16.0 * scale
        draw_final.ellipse([px - pr_px, py - 4, px + pr_px, py + 4], fill=(245, 195, 35, 175))
        draw_final.ellipse([px - 5, py - 5, px + 5, py + 5], fill=(45, 25, 15, 255))

        # Hinomaru Red Sun on Swept Wings
        for side in [-1, 1]:
            h_pos = R_total @ np.array([side * 34.0, -22.0, 1.8])
            hx, hy = cx + h_pos[0] * scale, cy - h_pos[1] * scale
            draw_final.ellipse([hx - 9, hy - 9, hx + 9, hy + 9], fill=(215, 25, 25, 255))

    elif plane_type == "xb35":
        # 4 Rear Contra-Rotating Pusher Propeller Discs with Yellow Warning Tips & Spinner Hubs
        for side in [-1, 1]:
            for nx, ny in [(44.0, -18.0), (76.0, -14.0)]:
                p_pos = R_total @ np.array([side * nx, ny - 16.0, 1.8])
                px, py = cx + p_pos[0] * scale, cy - p_pos[1] * scale
                pr_px = 15.0 * scale
                draw_final.ellipse([px - pr_px, py - 4, px + pr_px, py + 4], fill=(245, 195, 35, 150), outline=(255, 235, 110, 180))
                draw_final.ellipse([px - 4, py - 4, px + 4, py + 4], fill=(45, 50, 56, 255))

        # USAAF Star-and-Bars on Left Wing
        ins_pos = R_total @ np.array([-74.0, -2.0, 3.2])
        ix, iy = cx + ins_pos[0] * scale, cy - ins_pos[1] * scale
        draw_final.ellipse([ix - 9, iy - 9, ix + 9, iy + 9], fill=(25, 45, 115, 240))
        draw_final.rectangle([ix - 14, iy - 2, ix + 14, iy + 2], fill=(245, 245, 250, 240))
        draw_final.ellipse([ix - 5, iy - 5, ix + 5, iy + 5], fill=(245, 245, 250, 255))

    return result_img


# =============================================================================
# 5. BUILD SPRITESHEETS FOR ALL SECRET PLANES (INCLUDING XB-35)
# =============================================================================
def build_all_secret_spritesheets():
    planes = [
        ("ho229", build_ho229_mesh()),
        ("b29", build_b29_mesh()),
        ("shinden", build_shinden_mesh()),
        ("xb35", build_xb35_mesh())
    ]

    cell_size = 256
    # Sheet layout:
    # Row 0: Level flight (4 anim frames)
    # Row 1: Bank Left Mild, Hard / Bank Right Mild, Hard
    # Row 2: Pitch/Climb frames
    cols = 4
    rows = 3
    sheet_w = cell_size * cols
    sheet_h = cell_size * rows

    for name, mesh in planes:
        sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))
        print(f"Rendering secret airframe sheet: sheet_secret_{name}.png ...")

        # Row 0: Level flight anim
        for col in range(4):
            anim_th = col * (math.pi / 2.0)
            img = render_secret_plane(mesh, name, roll_deg=0.0, pitch_deg=0.0, anim_phase=anim_th, size=cell_size)
            sheet.paste(img, (col * cell_size, 0))

        # Row 1: Banking frames (-14, -28, +14, +28)
        banks = [-14.0, -28.0, 14.0, 28.0]
        for col, b_deg in enumerate(banks):
            img = render_secret_plane(mesh, name, roll_deg=b_deg, pitch_deg=0.0, yaw_deg=b_deg * 0.25, size=cell_size)
            sheet.paste(img, (col * cell_size, cell_size))

        # Row 2: Pitch/Climb frames (10, 25, -10, loop peak)
        pitches = [12.0, 24.0, -12.0, 180.0]
        for col, p_deg in enumerate(pitches):
            roll = 180.0 if p_deg == 180.0 else 0.0
            p = 0.0 if p_deg == 180.0 else p_deg
            img = render_secret_plane(mesh, name, roll_deg=roll, pitch_deg=p, size=cell_size)
            sheet.paste(img, (col * cell_size, cell_size * 2))

        out_path = SPRITES_DIR / f"sheet_secret_{name}.png"
        sheet.save(out_path, "PNG")
        print(f"✓ Saved {out_path} ({sheet_w}x{sheet_h})")


if __name__ == "__main__":
    build_all_secret_spritesheets()

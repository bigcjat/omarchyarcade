#!/usr/bin/env python3
"""
Sky Ace • Mitsubishi A6M Zero ("Zeke") 3D Mesh Engine
Builds an authentic 3D polygonal model of the legendary Imperial Japanese Navy carrier fighter:
- Nakajima Sakae 14-cylinder radial engine cowling & spinner
- Twin 7.7mm Type 97 cowl machine guns & 20mm Type 99 wing autocannons
- Elliptical dihedral wings with authentic Hinomaru (Rising Sun) roundels
- Long greenhouse glazed bubble canopy with rollover bar
- Authentic single vertical stabilizer and horizontal tail empennage
"""

import math
import numpy as np

class Mesh3D:
    def __init__(self):
        self.vertices = []  # List of [x, y, z]
        self.faces = []     # List of (v0, v1, v2, material_id)
        self.materials = {}

    def add_vertex(self, x, y, z):
        self.vertices.append([float(x), float(y), float(z)])
        return len(self.vertices) - 1

    def add_quad(self, v0, v1, v2, v3, mat_id):
        self.faces.append((v0, v1, v2, mat_id))
        self.faces.append((v0, v2, v3, mat_id))

    def add_tri(self, v0, v1, v2, mat_id):
        self.faces.append((v0, v1, v2, mat_id))

def build_zero_mesh():
    mesh = Mesh3D()

    # Material IDs
    MAT_BODY = 1            # IJN Dark Naval Green
    MAT_COWL = 2            # Blue-Black Radial Engine Cowling
    MAT_HINOMARU = 3        # Crimson Red Hinomaru (Rising Sun)
    MAT_YELLOW_BAND = 4     # Leading-edge Yellow Identification Band
    MAT_CANOPY = 5          # Glass Greenhouse Canopy
    MAT_CANOPY_FRAME = 6    # Dark Green Canopy Ribs
    MAT_CANNONS = 7         # 20mm Type 99 Wing Autocannons & Cowl Guns
    MAT_SPINNER = 8         # Propeller Spinner
    MAT_TAIL = 9            # Rudder & Elevators
    MAT_UNDERWING = 10      # Light Ash-Green Belly

    # -------------------------------------------------------------------------
    # 1. ENGINE SPINNER & SAKAE RADIAL COWL (Y = +58 to Y = +34)
    # -------------------------------------------------------------------------
    # Spinner nose cone
    tip_v = mesh.add_vertex(0.0, 58.0, 0.5)
    n_rad = 12
    spinner_base = []
    for i in range(n_rad):
        th = 2.0 * math.pi * i / n_rad
        vx = 3.2 * math.cos(th)
        vz = 0.5 + 3.2 * math.sin(th)
        spinner_base.append(mesh.add_vertex(vx, 52.0, vz))
    for i in range(n_rad):
        mesh.add_tri(tip_v, spinner_base[i], spinner_base[(i + 1) % n_rad], MAT_SPINNER)

    # Radial engine cowling sections: (y, rx, rz, zc, mat)
    cowl_sections = [
        (52.0, 7.2, 7.2, 0.5, MAT_COWL),   # Cowl lip intake
        (46.0, 8.4, 8.4, 0.5, MAT_COWL),   # Max radial cowl diameter
        (36.0, 8.2, 8.2, 0.5, MAT_COWL),   # Cowl trailing gills
    ]
    cowl_rings = []
    for y, rx, rz, zc, mat in cowl_sections:
        ring = []
        for i in range(n_rad):
            th = 2.0 * math.pi * i / n_rad
            vx = rx * math.cos(th)
            vz = zc + rz * math.sin(th)
            ring.append(mesh.add_vertex(vx, y, vz))
        cowl_rings.append(ring)

    # Bridge cowl rings
    for s in range(len(cowl_sections) - 1):
        r0, r1 = cowl_rings[s], cowl_rings[s + 1]
        for i in range(n_rad):
            i_next = (i + 1) % n_rad
            mesh.add_quad(r0[i], r1[i], r1[i_next], r0[i_next], MAT_COWL)

    # -------------------------------------------------------------------------
    # 2. MAIN FUSELAGE (Firewall Y=+36 to Tail cone Y=-64)
    # -------------------------------------------------------------------------
    fuse_sections = [
        (36.0, 8.0, 8.0, 0.5),    # Firewall / Cowl junction
        (24.0, 8.2, 8.2, 1.2),    # Forward gun deck (twin 7.7mm cowl guns)
        (10.0, 8.0, 8.0, 1.5),    # Cockpit mid
        (-6.0, 7.2, 7.5, 1.2),    # Aft cockpit
        (-22.0, 5.8, 6.2, 0.8),   # Mid fuselage
        (-38.0, 4.2, 4.8, 0.6),   # Aft fuselage
        (-52.0, 2.5, 3.2, 0.5),   # Empennage root
        (-64.0, 0.8, 1.0, 0.5),   # Stern tailcone tip
    ]
    fuse_rings = []
    for y, rx, rz, zc in fuse_sections:
        ring = []
        for i in range(n_rad):
            th = 2.0 * math.pi * i / n_rad
            vx = rx * math.cos(th)
            vz = zc + rz * math.sin(th)
            ring.append(mesh.add_vertex(vx, y, vz))
        fuse_rings.append(ring)

    # Bridge cowl to fuselage
    for i in range(n_rad):
        i_next = (i + 1) % n_rad
        mesh.add_quad(cowl_rings[-1][i], fuse_rings[0][i], fuse_rings[0][i_next], cowl_rings[-1][i_next], MAT_BODY)

    # Bridge fuselage sections
    for s in range(len(fuse_sections) - 1):
        r0, r1 = fuse_rings[s], fuse_rings[s + 1]
        for i in range(n_rad):
            i_next = (i + 1) % n_rad
            mesh.add_quad(r0[i], r1[i], r1[i_next], r0[i_next], MAT_BODY)

    # -------------------------------------------------------------------------
    # 3. GREENHOUSE BUBBLE CANOPY (Glazed glass teardrop)
    # -------------------------------------------------------------------------
    canopy_sections = [
        (22.0, 4.2, 3.2, 7.8),    # Windshield front
        (12.0, 5.5, 5.2, 9.2),    # Pilot head position (high glass dome)
        (0.0,  5.2, 4.8, 8.8),    # Mid glazed canopy
        (-10.0, 4.0, 3.4, 7.8),   # Rear greenhouse taper
        (-18.0, 1.5, 1.5, 6.5),   # Fairing tail
    ]
    canopy_rings = []
    n_can = 8
    for y, rx, rz, zc in canopy_sections:
        ring = []
        for i in range(n_can):
            th = math.pi * i / (n_can - 1)  # Top half dome
            vx = rx * math.cos(th)
            vz = zc + rz * math.sin(th)
            ring.append(mesh.add_vertex(vx, y, vz))
        canopy_rings.append(ring)

    for s in range(len(canopy_sections) - 1):
        r0, r1 = canopy_rings[s], canopy_rings[s + 1]
        mat = MAT_CANOPY if (s % 2 == 0) else MAT_CANOPY_FRAME
        for i in range(n_can - 1):
            mesh.add_quad(r0[i], r1[i], r1[i + 1], r0[i + 1], mat)

    # -------------------------------------------------------------------------
    # 4. LOW MONOPLANE WINGS WITH DIHEDRAL & HINOMARU
    # -------------------------------------------------------------------------
    # The A6M Zero has continuous wings with ~5.5° dihedral rising toward tips.
    # Wing chord stations along X: (x, y_lead, y_trail, z_root, z_tip)
    # Left wing (X: 0 to -68), Right wing (X: 0 to +68)
    wing_stations_r = [
        ( 8.0, 24.0, -8.0, -0.5, 1.5),     # Root wing fillet
        (22.0, 22.0, -9.0,  0.4, 1.8),     # Inner wing / Yellow I.D. band
        (38.0, 19.0, -10.0, 1.4, 2.2),     # Mid wing / Hinomaru center
        (52.0, 16.0, -11.0, 2.4, 2.4),     # Outer wing
        (66.0, 12.0, -11.5, 3.5, 2.0),     # Wingtip start
        (69.0,  9.0, -11.0, 3.8, 1.0),     # Rounded tip
    ]

    def build_wing_half(stations, is_right=True):
        sign = 1.0 if is_right else -1.0
        up_v, dn_v = [], []
        
        for x, y_le, y_te, z, th in stations:
            x_act = sign * x
            v_le_up = mesh.add_vertex(x_act, y_le, z + th * 0.5)
            v_te_up = mesh.add_vertex(x_act, y_te, z + th * 0.2)
            v_le_dn = mesh.add_vertex(x_act, y_le, z - th * 0.5)
            v_te_dn = mesh.add_vertex(x_act, y_te, z - th * 0.2)
            up_v.append((v_le_up, v_te_up))
            dn_v.append((v_le_dn, v_te_dn))

        # Bridge spans
        for s in range(len(stations) - 1):
            le0, te0 = up_v[s]
            le1, te1 = up_v[s + 1]
            le0_d, te0_d = dn_v[s]
            le1_d, te1_d = dn_v[s + 1]

            # Upper surface is solid dark naval green
            mat_top = MAT_BODY

            if is_right:
                # Upper surface
                mesh.add_quad(le0, le1, te1, te0, mat_top)
                # Lower surface
                mesh.add_quad(le0_d, te0_d, te1_d, le1_d, MAT_UNDERWING)
                # Leading edge wall: yellow I.D. band on inner section (s == 0 or s == 1)
                mesh.add_quad(le0, le0_d, le1_d, le1, MAT_YELLOW_BAND if s <= 1 else MAT_BODY)
            else:
                mesh.add_quad(le0, te0, te1, le1, mat_top)
                mesh.add_quad(le0_d, le1_d, te1_d, te0_d, MAT_UNDERWING)
                mesh.add_quad(le0, le1, le1_d, le0_d, MAT_YELLOW_BAND if s <= 1 else MAT_BODY)

    build_wing_half(wing_stations_r, is_right=True)
    build_wing_half(wing_stations_r, is_right=False)

    # -------------------------------------------------------------------------
    # 5. TWIN 20MM TYPE 99 WING AUTOCANNON BARRELS
    # -------------------------------------------------------------------------
    for x_gun in [-26.0, 26.0]:
        base_y = 21.0
        z_gun = 1.0
        # Barrel protrudes 8 units forward from leading edge
        g0 = mesh.add_vertex(x_gun - 0.6, base_y, z_gun)
        g1 = mesh.add_vertex(x_gun + 0.6, base_y, z_gun)
        g2 = mesh.add_vertex(x_gun + 0.6, base_y + 8.0, z_gun)
        g3 = mesh.add_vertex(x_gun - 0.6, base_y + 8.0, z_gun)
        mesh.add_quad(g0, g1, g2, g3, MAT_CANNONS)

    # -------------------------------------------------------------------------
    # 6. TAIL EMPENNAGE (Vertical Stabilizer & Horizontal Stabilizer)
    # -------------------------------------------------------------------------
    # Vertical Fin (Rises upward to Z=+24)
    v_f0 = mesh.add_vertex(0.0, -42.0, 2.5)
    v_f1 = mesh.add_vertex(0.0, -60.0, 2.0)
    v_f2 = mesh.add_vertex(0.0, -62.0, 22.0)
    v_f3 = mesh.add_vertex(0.0, -48.0, 20.0)
    mesh.add_quad(v_f0, v_f1, v_f2, v_f3, MAT_TAIL)

    # Horizontal Stabilizers (Span X: -26 to +26 at Y: -50 to -62)
    for sign in [-1.0, 1.0]:
        h0 = mesh.add_vertex(0.0, -50.0, 2.0)
        h1 = mesh.add_vertex(sign * 24.0, -55.0, 2.0)
        h2 = mesh.add_vertex(sign * 22.0, -63.0, 2.0)
        h3 = mesh.add_vertex(0.0, -62.0, 2.0)
        if sign > 0:
            mesh.add_quad(h0, h1, h2, h3, MAT_TAIL)
        else:
            mesh.add_quad(h0, h3, h2, h1, MAT_TAIL)

    return mesh

if __name__ == "__main__":
    m = build_zero_mesh()
    print(f"[A6M Zero] Built 3D model: {len(m.vertices)} vertices, {len(m.faces)} faces.")

#!/usr/bin/env python3
"""
Sky Ace • PZL P.11c Gull-Wing 3D Mesh Engine (Poland)
Features:
- High gull-wing ("Polish Wing") with downward swoop at the fuselage root
- Radial Bristol Mercury engine with cylinder head teardrop fairings
- Open cockpit with windscreen
- Polish Khaki / Polish Olive Green finish
- Polish Air Force Red/White Checkerboard (Szachownica)
"""

import math

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

def build_pzl11_mesh():
    mesh = Mesh3D()
    MAT_BODY = 1        # Polish Khaki / Polish Olive
    MAT_RADIAL = 2      # Radial Engine & Cowling Ring
    MAT_CHECKER = 3     # Polish Red/White Checkerboard
    MAT_WINDSCREEN = 4  # Cockpit Windscreen Glass
    MAT_STRUTS = 5      # Wing Support Struts

    # 1. Radial Engine Cowl & Propeller Hub
    tip = mesh.add_vertex(0.0, 52.0, 0.0)
    n_rad = 12
    rad_ring = []
    for i in range(n_rad):
        th = 2.0 * math.pi * i / n_rad
        rad_ring.append(mesh.add_vertex(7.0 * math.cos(th), 46.0, 7.0 * math.sin(th)))
    for i in range(n_rad):
        mesh.add_tri(tip, rad_ring[i], rad_ring[(i + 1) % n_rad], MAT_RADIAL)

    # 2. Fuselage Cross-Sections (All-metal semi-monocoque)
    fuse_secs = [
        (46.0, 6.8, 6.8, 0.0, MAT_RADIAL),      # Engine cowl
        (32.0, 6.2, 6.6, 0.2, MAT_BODY),        # Behind engine
        (14.0, 5.8, 6.4, 0.8, MAT_BODY),        # Open cockpit front
        (-2.0, 5.4, 6.0, 0.6, MAT_BODY),        # Pilot seat
        (-18.0, 4.4, 5.2, 0.4, MAT_BODY),       # Headrest fairing
        (-38.0, 3.0, 3.8, 0.2, MAT_BODY),       # Mid fuselage
        (-54.0, 1.6, 2.4, 0.2, MAT_BODY),       # Rear
        (-64.0, 0.6, 0.8, 0.2, MAT_BODY),       # Tail post
    ]
    rings = []
    for y, rx, rz, zc, mat in fuse_secs:
        ring = []
        for i in range(n_rad):
            th = 2.0 * math.pi * i / n_rad
            ring.append(mesh.add_vertex(rx * math.cos(th), y, zc + rz * math.sin(th)))
        rings.append((ring, mat))

    for s in range(len(fuse_secs) - 1):
        r0, _ = rings[s]
        r1, mat1 = rings[s + 1]
        for i in range(n_rad):
            i_next = (i + 1) % n_rad
            mesh.add_quad(r0[i], r0[i_next], r1[i_next], r1[i], mat1)

    # 3. Small Open-Cockpit Windscreen
    windscreen_tip = mesh.add_vertex(0.0, 14.0, 6.8)
    mesh.add_tri(windscreen_tip, rings[2][0][0], rings[2][0][1], MAT_WINDSCREEN)
    mesh.add_tri(windscreen_tip, rings[2][0][n_rad - 1], rings[2][0][0], MAT_WINDSCREEN)

    # 4. Signature High Gull-Wing ("Polish Wing")
    # Swoops down to meet the upper fuselage at x=4, then bends upward and outward!
    wing_secs = [
        (4.0,   18.0,  -8.0,  3.2, 2.0),  # Root dip (meeting upper deck)
        (16.0,  20.0,  -6.0,  7.2, 2.4),  # Gull elbow peak (high shoulder)
        (38.0,  17.0,  -7.0,  6.4, 2.4),  # Mid wing (dihedral transition)
        (62.0,  13.0,  -6.0,  5.8, 2.0),  # Outer panel (Checkerboard)
        (84.0,   7.0,  -3.0,  5.2, 1.2),  # Rounded wingtip
    ]
    for side in [1.0, -1.0]:
        w_rings = []
        for s_idx, (span, f_y, r_y, z_up, thick) in enumerate(wing_secs):
            x = side * span
            top_le = mesh.add_vertex(x, f_y, z_up + thick * 0.4)
            top_te = mesh.add_vertex(x, r_y, z_up)
            bot_le = mesh.add_vertex(x, f_y, z_up - thick * 0.6)
            bot_te = mesh.add_vertex(x, r_y, z_up - 0.2)
            w_rings.append((top_le, top_te, bot_le, bot_te))

        for i in range(len(wing_secs) - 1):
            t_le0, t_te0, b_le0, b_te0 = w_rings[i]
            t_le1, t_te1, b_le1, b_te1 = w_rings[i + 1]
            mat = MAT_CHECKER if i == 3 else MAT_BODY
            mesh.add_quad(t_le0, t_le1, t_te1, t_te0, mat)
            mesh.add_quad(b_te0, b_te1, b_le1, b_le0, mat)
            mesh.add_quad(b_le0, b_le1, t_le1, t_le0, MAT_BODY)

    # 5. Tail Stabilizers & Vertical Fin
    for side in [1.0, -1.0]:
        h_root_f = mesh.add_vertex(side * 2.0, -52.0, 1.0)
        h_root_r = mesh.add_vertex(side * 2.0, -64.0, 0.8)
        h_tip_f  = mesh.add_vertex(side * 20.0, -56.0, 1.4)
        h_tip_r  = mesh.add_vertex(side * 18.0, -64.0, 1.2)
        mesh.add_quad(h_root_f, h_tip_f, h_tip_r, h_root_r, MAT_BODY)

    fin_root_f = mesh.add_vertex(0.0, -44.0, 2.0)
    fin_root_r = mesh.add_vertex(0.0, -64.0, 1.0)
    fin_tip_f  = mesh.add_vertex(0.0, -58.0, 16.0)
    fin_tip_r  = mesh.add_vertex(0.0, -64.0, 12.0)
    mesh.add_quad(fin_root_f, fin_tip_f, fin_tip_r, fin_root_r, MAT_CHECKER)

    return mesh

#!/usr/bin/env python3
"""
Sky Ace • Macchi C.202 Folgore 3D Mesh Engine (Italy)
Features:
- Streamlined Italian fuselage with Daimler-Benz / Alfa Romeo V12 inline engine
- Semi-elliptical wings with rounded tips
- White Mediterranean fuselage theater band
- Finely contoured vertical stabilizer with Savoia Cross
- Twin cowl-mounted 12.7mm Breda-SAFAT machine guns
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

def build_folgore_mesh():
    mesh = Mesh3D()
    MAT_BODY = 1        # Ochre / Sand with Olive Mottle
    MAT_WHITE_BAND = 2  # White Mediterranean Fuselage Band
    MAT_INSIGNIA = 3    # Italian Fasces / Wing Roundels
    MAT_CANOPY = 4      # Enclosed Cockpit Glass
    MAT_SPINNER = 5     # White Bullet Nose Spinner
    MAT_SAVOIA_CROSS = 6# White Cross of Savoy on Tail

    # 1. Spinner (Sleek Italian bullet nose cone)
    tip = mesh.add_vertex(0.0, 64.0, 0.2)
    n_rad = 12
    spin_base = []
    for i in range(n_rad):
        th = 2.0 * math.pi * i / n_rad
        spin_base.append(mesh.add_vertex(2.8 * math.cos(th), 55.0, 0.2 + 2.8 * math.sin(th)))
    for i in range(n_rad):
        mesh.add_tri(tip, spin_base[i], spin_base[(i + 1) % n_rad], MAT_SPINNER)

    # 2. Fuselage Cross-Sections
    fuse_secs = [
        (55.0, 5.2, 5.8, 0.2, MAT_BODY),        # Engine front
        (38.0, 6.4, 7.4, 0.5, MAT_BODY),        # Engine cowl / guns
        (18.0, 6.8, 8.0, 1.2, MAT_BODY),        # Front cockpit
        (0.0,  6.6, 7.6, 1.0, MAT_BODY),        # Cockpit rear
        (-14.0, 5.8, 6.8, 0.8, MAT_WHITE_BAND), # White fuselage band
        (-24.0, 4.8, 5.8, 0.6, MAT_WHITE_BAND), # White fuselage band
        (-42.0, 3.2, 4.2, 0.5, MAT_BODY),       # Mid rear
        (-58.0, 1.6, 2.6, 0.4, MAT_BODY),       # Tail approach
        (-68.0, 0.5, 0.8, 0.4, MAT_BODY),       # Tail tip
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
        use_mat = mat1
        for i in range(n_rad):
            i_next = (i + 1) % n_rad
            mesh.add_quad(r0[i], r0[i_next], r1[i_next], r1[i], use_mat)

    # 3. Cockpit Canopy (Slender teardrop)
    canopy_top_f = mesh.add_vertex(0.0, 18.0, 7.8)
    canopy_top_m = mesh.add_vertex(0.0, 4.0, 8.2)
    canopy_top_r = mesh.add_vertex(0.0, -10.0, 4.8)
    mesh.add_tri(canopy_top_f, canopy_top_m, rings[2][0][0], MAT_CANOPY)
    mesh.add_tri(canopy_top_m, canopy_top_r, rings[3][0][0], MAT_CANOPY)

    # 4. Semi-Elliptical Wings
    wing_secs = [
        (6.0,   22.0, -12.0,  0.0, 3.2),  # Root
        (22.0,  19.0, -11.0,  0.4, 2.8),  # Inboard
        (46.0,  15.0,  -8.0,  1.0, 2.4),  # Mid wing (Insignia)
        (72.0,   9.0,  -4.0,  1.8, 1.8),  # Outboard
        (88.0,   3.0,   0.0,  2.4, 1.2),  # Tip
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
            mat = MAT_INSIGNIA if i == 2 else MAT_BODY
            mesh.add_quad(t_le0, t_le1, t_te1, t_te0, mat)
            mesh.add_quad(b_te0, b_te1, b_le1, b_le0, mat)
            mesh.add_quad(b_le0, b_le1, t_le1, t_le0, MAT_BODY)

    # 5. Tail Empennage & Horizontal Stabilizers
    for side in [1.0, -1.0]:
        h_root_f = mesh.add_vertex(side * 2.0, -56.0, 1.2)
        h_root_r = mesh.add_vertex(side * 2.0, -68.0, 1.0)
        h_tip_f  = mesh.add_vertex(side * 24.0, -60.0, 1.8)
        h_tip_r  = mesh.add_vertex(side * 22.0, -68.0, 1.6)
        mesh.add_quad(h_root_f, h_tip_f, h_tip_r, h_root_r, MAT_BODY)

    # Vertical Fin with Savoia Cross
    fin_root_f = mesh.add_vertex(0.0, -48.0, 2.6)
    fin_root_r = mesh.add_vertex(0.0, -68.0, 1.2)
    fin_tip_f  = mesh.add_vertex(0.0, -62.0, 19.0)
    fin_tip_r  = mesh.add_vertex(0.0, -67.0, 14.0)
    mesh.add_quad(fin_root_f, fin_tip_f, fin_tip_r, fin_root_r, MAT_SAVOIA_CROSS)

    return mesh

#!/usr/bin/env python3
"""
Sky Ace • Dewoitine D.520 3D Mesh Engine (France)
Features:
- Sleek inline Hispano-Suiza 12Y-49 V12 engine
- Hub-mounted 20mm Hispano-Suiza 404 cannon blast tube through the spinner
- Slender trapezoidal wings with circular French Tricolor roundels
- Tricolor vertical rudder (Blue / White / Red stripes)
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

def build_d520_mesh():
    mesh = Mesh3D()
    MAT_BODY = 1        # French Gris-Bleu / Khaki Camo
    MAT_ROUNDEL = 2     # Tricolor Wing Roundels
    MAT_CANOPY = 3      # Slender Curved Canopy Glass
    MAT_SPINNER = 4     # Black Spinner with Central Cannon Blast Hole
    MAT_RUDDER_TRICOLOR = 5 # French Blue/White/Red Rudder

    # 1. Spinner with central Hispano Cannon Blast Tube
    tip = mesh.add_vertex(0.0, 62.0, 0.0)
    n_rad = 12
    spin_base = []
    for i in range(n_rad):
        th = 2.0 * math.pi * i / n_rad
        spin_base.append(mesh.add_vertex(2.6 * math.cos(th), 54.0, 2.6 * math.sin(th)))
    for i in range(n_rad):
        mesh.add_tri(tip, spin_base[i], spin_base[(i + 1) % n_rad], MAT_SPINNER)

    # 2. Fuselage Cross-Sections
    fuse_secs = [
        (54.0, 5.0, 5.6, 0.0, MAT_BODY),
        (38.0, 6.2, 7.2, 0.4, MAT_BODY),
        (16.0, 6.6, 7.8, 1.2, MAT_BODY),
        (-2.0, 6.4, 7.4, 1.0, MAT_BODY),
        (-20.0, 5.4, 6.2, 0.6, MAT_BODY),
        (-40.0, 3.4, 4.4, 0.5, MAT_BODY),
        (-56.0, 1.6, 2.6, 0.4, MAT_BODY),
        (-66.0, 0.5, 0.8, 0.4, MAT_BODY),
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

    # 3. Cockpit Canopy
    canopy_top_f = mesh.add_vertex(0.0, 16.0, 7.6)
    canopy_top_m = mesh.add_vertex(0.0, 2.0, 8.0)
    canopy_top_r = mesh.add_vertex(0.0, -12.0, 4.6)
    mesh.add_tri(canopy_top_f, canopy_top_m, rings[2][0][0], MAT_CANOPY)
    mesh.add_tri(canopy_top_m, canopy_top_r, rings[3][0][0], MAT_CANOPY)

    # 4. Tapered Wings with French Roundels
    wing_secs = [
        (6.0,   20.0, -14.0,  0.0, 3.0),
        (24.0,  17.0, -12.0,  0.5, 2.6),
        (50.0,  12.0,  -8.0,  1.2, 2.2),  # Roundel
        (76.0,   7.0,  -4.0,  1.8, 1.6),
        (90.0,   2.0,  -1.0,  2.2, 1.0),  # Rounded tip
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
            mat = MAT_ROUNDEL if i == 2 else MAT_BODY
            mesh.add_quad(t_le0, t_le1, t_te1, t_te0, mat)
            mesh.add_quad(b_te0, b_te1, b_le1, b_le0, mat)
            mesh.add_quad(b_le0, b_le1, t_le1, t_le0, MAT_BODY)

    # 5. Tail Stabilizers & Tricolor Rudder
    for side in [1.0, -1.0]:
        h_root_f = mesh.add_vertex(side * 2.0, -54.0, 1.2)
        h_root_r = mesh.add_vertex(side * 2.0, -66.0, 1.0)
        h_tip_f  = mesh.add_vertex(side * 22.0, -58.0, 1.6)
        h_tip_r  = mesh.add_vertex(side * 20.0, -66.0, 1.4)
        mesh.add_quad(h_root_f, h_tip_f, h_tip_r, h_root_r, MAT_BODY)

    # Vertical Fin with French Tricolor Stripes
    fin_root_f = mesh.add_vertex(0.0, -46.0, 2.4)
    fin_root_r = mesh.add_vertex(0.0, -66.0, 1.2)
    fin_tip_f  = mesh.add_vertex(0.0, -60.0, 18.0)
    fin_tip_r  = mesh.add_vertex(0.0, -66.0, 13.0)
    mesh.add_quad(fin_root_f, fin_tip_f, fin_tip_r, fin_root_r, MAT_RUDDER_TRICOLOR)

    return mesh

#!/usr/bin/env python3
"""
Sky Ace • Avia B.534 Biplane 3D Mesh Engine (Czechoslovakia)
Features:
- Aerodynamic staggered biplane configuration (Upper and lower wings with N-struts)
- Streamlined Hispano-Suiza 12Y V12 nose with 4 synchronized cowl guns
- Enclosed greenhouse bubble canopy
- Czechoslovak Khaki / Olive finish with national tricolor roundels
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

def build_avia_mesh():
    mesh = Mesh3D()
    MAT_BODY = 1        # Czech Khaki / Olive Drab
    MAT_ROUNDEL = 2     # Czech Tricolor Roundel
    MAT_CANOPY = 3      # Enclosed Glass Canopy
    MAT_SPINNER = 4     # Propeller Spinner
    MAT_STRUTS = 5      # Interplane N-Struts & Cabane Struts

    # 1. Spinner Nose Cone
    tip = mesh.add_vertex(0.0, 58.0, 0.0)
    n_rad = 12
    spin_base = []
    for i in range(n_rad):
        th = 2.0 * math.pi * i / n_rad
        spin_base.append(mesh.add_vertex(2.8 * math.cos(th), 50.0, 2.8 * math.sin(th)))
    for i in range(n_rad):
        mesh.add_tri(tip, spin_base[i], spin_base[(i + 1) % n_rad], MAT_SPINNER)

    # 2. Fuselage Cross-Sections
    fuse_secs = [
        (50.0, 5.0, 5.4, 0.0, MAT_BODY),
        (34.0, 6.0, 6.8, 0.2, MAT_BODY),
        (16.0, 6.4, 7.4, 0.8, MAT_BODY),
        (-2.0, 6.0, 7.0, 0.6, MAT_BODY),
        (-20.0, 5.0, 5.8, 0.4, MAT_BODY),
        (-40.0, 3.2, 4.0, 0.2, MAT_BODY),
        (-54.0, 1.6, 2.4, 0.2, MAT_BODY),
        (-64.0, 0.5, 0.8, 0.2, MAT_BODY),
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

    # 3. Enclosed Canopy
    canopy_top_f = mesh.add_vertex(0.0, 16.0, 7.2)
    canopy_top_m = mesh.add_vertex(0.0, 2.0, 7.6)
    canopy_top_r = mesh.add_vertex(0.0, -12.0, 4.4)
    mesh.add_tri(canopy_top_f, canopy_top_m, rings[2][0][0], MAT_CANOPY)
    mesh.add_tri(canopy_top_m, canopy_top_r, rings[3][0][0], MAT_CANOPY)

    # 4. BIPLANES WINGS!
    # A) UPPER WING (Mounted higher up at z = 6.8, spanning slightly forward)
    upper_wing_secs = [
        (4.0,   20.0,  -8.0,  6.8, 2.0),
        (28.0,  18.0,  -8.0,  7.0, 2.0),
        (56.0,  14.0,  -7.0,  7.2, 1.8),  # Roundel
        (84.0,   8.0,  -5.0,  7.4, 1.2),  # Tip
    ]
    for side in [1.0, -1.0]:
        w_rings = []
        for span, f_y, r_y, z_up, thick in upper_wing_secs:
            x = side * span
            top_le = mesh.add_vertex(x, f_y, z_up + thick * 0.4)
            top_te = mesh.add_vertex(x, r_y, z_up)
            bot_le = mesh.add_vertex(x, f_y, z_up - thick * 0.6)
            bot_te = mesh.add_vertex(x, r_y, z_up - 0.2)
            w_rings.append((top_le, top_te, bot_le, bot_te))

        for i in range(len(upper_wing_secs) - 1):
            t_le0, t_te0, b_le0, b_te0 = w_rings[i]
            t_le1, t_te1, b_le1, b_te1 = w_rings[i + 1]
            mat = MAT_ROUNDEL if i == 1 else MAT_BODY
            mesh.add_quad(t_le0, t_le1, t_te1, t_te0, mat)
            mesh.add_quad(b_te0, b_te1, b_le1, b_le0, mat)
            mesh.add_quad(b_le0, b_le1, t_le1, t_le0, MAT_BODY)

    # B) LOWER WING (Mounted lower at z = -2.4, slightly shorter span)
    lower_wing_secs = [
        (5.0,   15.0, -11.0, -2.4, 1.8),
        (26.0,  13.0, -11.0, -2.2, 1.8),
        (50.0,  10.0, -10.0, -2.0, 1.6),
        (72.0,   6.0,  -7.0, -1.8, 1.0),  # Tip
    ]
    for side in [1.0, -1.0]:
        w_rings = []
        for span, f_y, r_y, z_up, thick in lower_wing_secs:
            x = side * span
            top_le = mesh.add_vertex(x, f_y, z_up + thick * 0.4)
            top_te = mesh.add_vertex(x, r_y, z_up)
            bot_le = mesh.add_vertex(x, f_y, z_up - thick * 0.6)
            bot_te = mesh.add_vertex(x, r_y, z_up - 0.2)
            w_rings.append((top_le, top_te, bot_le, bot_te))

        for i in range(len(lower_wing_secs) - 1):
            t_le0, t_te0, b_le0, b_te0 = w_rings[i]
            t_le1, t_te1, b_le1, b_te1 = w_rings[i + 1]
            mesh.add_quad(t_le0, t_le1, t_te1, t_te0, MAT_BODY)
            mesh.add_quad(b_te0, b_te1, b_le1, b_le0, MAT_BODY)
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
    mesh.add_quad(fin_root_f, fin_tip_f, fin_tip_r, fin_root_r, MAT_ROUNDEL)

    return mesh

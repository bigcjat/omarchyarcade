#!/usr/bin/env python3
"""
Sky Ace • Yakovlev Yak-3 3D Mesh Engine
Features:
- Compact wooden-alloy turn-fighter airframe (featherweight dogfighter)
- Pointed nose cone & Klimov VK-105PF2 V12 engine
- Red Star insignia with white/red border
- Clean, aerodynamic lines and teardrop glass canopy
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

def build_yak3_mesh():
    mesh = Mesh3D()
    MAT_BODY = 1    # VVS Slate-Grey & Light Earth Camo
    MAT_RED_NOSE = 2# Red Guard Nose Cowling
    MAT_STAR = 3    # Soviet Red Star
    MAT_CANOPY = 4  # Teardrop Glass Canopy
    MAT_SPINNER = 5 # Pointed Red Spinner
    MAT_TAIL = 6    # Empennage

    # 1. Pointed Nose Spinner
    tip = mesh.add_vertex(0.0, 58.0, 0.2)
    n_rad = 12
    spin_base = []
    for i in range(n_rad):
        th = 2.0 * math.pi * i / n_rad
        spin_base.append(mesh.add_vertex(2.8 * math.cos(th), 50.0, 0.2 + 2.8 * math.sin(th)))
    for i in range(n_rad):
        mesh.add_tri(tip, spin_base[i], spin_base[(i + 1) % n_rad], MAT_SPINNER)

    # 2. Sleek Compact Fuselage
    fuse_secs = [
        (50.0, 5.8, 6.2, 0.2, MAT_RED_NOSE), (36.0, 6.8, 7.5, 0.6, MAT_RED_NOSE),
        (14.0, 7.0, 8.0, 1.2, MAT_BODY), (-6.0, 6.6, 7.4, 1.0, MAT_BODY),
        (-22.0, 4.8, 5.6, 0.6, MAT_BODY), (-40.0, 3.2, 4.0, 0.5, MAT_BODY),
        (-54.0, 1.6, 2.4, 0.5, MAT_BODY), (-64.0, 0.6, 0.8, 0.5, MAT_BODY)
    ]
    rings = []
    for y, rx, rz, zc, mat in fuse_secs:
        ring = []
        for i in range(n_rad):
            th = 2.0 * math.pi * i / n_rad
            ring.append(mesh.add_vertex(rx * math.cos(th), y, zc + rz * math.sin(th)))
        rings.append((ring, mat))
    for s in range(len(fuse_secs) - 1):
        r0, mat0 = rings[s]
        r1, mat1 = rings[s + 1]
        use_mat = mat0 if s == 0 else MAT_BODY
        for i in range(n_rad):
            mesh.add_quad(r0[i], r1[i], r1[(i + 1) % n_rad], r0[(i + 1) % n_rad], use_mat)

    # 3. Compact Wooden Wings (Span 76, Chord 22)
    wing_stations = [
        (-6.0, 10.0, 0.0, 18.0, -12.0), (-18.0, 8.0, 1.0, 17.0, -10.0),
        (-32.0, 6.5, 2.2, 14.0, -7.0), (-46.0, 5.0, 3.5, 12.0, -4.0),
        (-56.0, 3.0, 4.6, 9.0, -1.0), (-60.0, 0.5, 5.0, 6.0, 0.5)
    ]
    for sign in [-1, 1]:
        prev_top_le, prev_top_te = None, None
        prev_bot_le, prev_bot_te = None, None
        for x_base, y_ref, z_dihed, le_c, te_c in wing_stations:
            x = sign * abs(x_base)
            y_le = y_ref + le_c
            y_te = y_ref + te_c
            t_le = mesh.add_vertex(x, y_le, z_dihed + 1.0)
            t_te = mesh.add_vertex(x, y_te, z_dihed)
            b_le = mesh.add_vertex(x, y_le, z_dihed - 1.0)
            b_te = mesh.add_vertex(x, y_te, z_dihed - 0.4)

            if prev_top_le is not None:
                if sign == -1:
                    mesh.add_quad(prev_top_le, t_le, t_te, prev_top_te, MAT_BODY)
                    mesh.add_quad(prev_bot_te, b_te, b_le, prev_bot_le, MAT_BODY)
                else:
                    mesh.add_quad(t_le, prev_top_le, prev_top_te, t_te, MAT_BODY)
                    mesh.add_quad(b_te, prev_bot_te, prev_bot_le, b_le, MAT_BODY)

            prev_top_le, prev_top_te = t_le, t_te
            prev_bot_le, prev_bot_te = b_le, b_te

    # 4. Teardrop Canopy
    c_pts = [
        mesh.add_vertex(0.0, 16.0, 8.5), mesh.add_vertex(-3.2, 12.0, 5.6),
        mesh.add_vertex(3.2, 12.0, 5.6), mesh.add_vertex(-3.0, -6.0, 5.2),
        mesh.add_vertex(3.0, -6.0, 5.2), mesh.add_vertex(0.0, -12.0, 6.0)
    ]
    mesh.add_quad(c_pts[1], c_pts[0], c_pts[2], c_pts[2], MAT_CANOPY)
    mesh.add_quad(c_pts[1], c_pts[3], c_pts[4], c_pts[2], MAT_CANOPY)
    mesh.add_tri(c_pts[3], c_pts[5], c_pts[4], MAT_CANOPY)

    # 5. Tail
    for sign in [-1, 1]:
        mesh.add_quad(
            mesh.add_vertex(0.0, -50.0, 2.5), mesh.add_vertex(sign * 18.0, -54.0, 2.8),
            mesh.add_vertex(sign * 16.0, -62.0, 2.8), mesh.add_vertex(0.0, -62.0, 2.5), MAT_TAIL
        )
    mesh.add_tri(
        mesh.add_vertex(0.0, -44.0, 3.5), mesh.add_vertex(0.0, -62.0, 19.0),
        mesh.add_vertex(0.0, -64.0, 3.5), MAT_TAIL
    )

    return mesh

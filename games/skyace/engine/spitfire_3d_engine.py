#!/usr/bin/env python3
"""
Sky Ace • Supermarine Spitfire Mk.IX 3D Mesh Engine
Features:
- Iconic thin elliptical wings with 20mm Hispano cannon barrels
- Rolls-Royce Merlin 60-series pointed nose spinner
- Teardrop blown canopy with rollover pylon
- RAF roundels & yellow leading-edge recognition stripes
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

def build_spitfire_mesh():
    mesh = Mesh3D()
    MAT_BODY = 1        # RAF Dark Green / Ocean Grey Camo
    MAT_SPINNER = 2     # Black/Yellow Prop Spinner
    MAT_ROUNDEL = 3     # RAF Tricolor Roundel (Blue/White/Red)
    MAT_YELLOW_BAND = 4 # Leading Edge Yellow Stripe
    MAT_CANOPY = 5      # Glass Bubble Canopy
    MAT_CANNONS = 6     # 20mm Hispano Autocannon Barrels
    MAT_TAIL = 7        # Rudder & Elevators

    # 1. Pointed Nose Spinner (Rolls-Royce Merlin)
    tip = mesh.add_vertex(0.0, 62.0, 0.5)
    n_rad = 12
    spin_base = []
    for i in range(n_rad):
        th = 2.0 * math.pi * i / n_rad
        spin_base.append(mesh.add_vertex(2.8 * math.cos(th), 54.0, 0.5 + 2.8 * math.sin(th)))
    for i in range(n_rad):
        mesh.add_tri(tip, spin_base[i], spin_base[(i + 1) % n_rad], MAT_SPINNER)

    # 2. Sleek Fuselage Sections (Cowl -> Cockpit -> Tail)
    fuse_secs = [
        (54.0, 6.2, 6.2, 0.5), (38.0, 7.2, 7.5, 0.8), (14.0, 7.5, 8.2, 1.4),
        (-6.0, 7.0, 7.8, 1.2), (-24.0, 5.2, 6.0, 0.8), (-42.0, 3.6, 4.4, 0.6),
        (-56.0, 2.0, 3.0, 0.5), (-66.0, 0.6, 1.0, 0.5)
    ]
    rings = []
    for y, rx, rz, zc in fuse_secs:
        ring = []
        for i in range(n_rad):
            th = 2.0 * math.pi * i / n_rad
            ring.append(mesh.add_vertex(rx * math.cos(th), y, zc + rz * math.sin(th)))
        rings.append(ring)
    for s in range(len(fuse_secs) - 1):
        r0, r1 = rings[s], rings[s + 1]
        for i in range(n_rad):
            mesh.add_quad(r0[i], r1[i], r1[(i + 1) % n_rad], r0[(i + 1) % n_rad], MAT_BODY)

    # 3. Famous Elliptical Wings (Span 84, Chord 32)
    wing_stations = [
        (-7.0, 10.0, 0.0, 26.0, -18.0), (-22.0, 8.0, 1.2, 24.0, -15.0),
        (-38.0, 6.5, 2.6, 20.0, -10.0), (-52.0, 5.0, 4.2, 14.0, -4.0),
        (-62.0, 3.0, 5.4, 8.0, 1.0), (-68.0, 0.5, 6.2, 2.0, 3.0)
    ]
    for sign in [-1, 1]:
        prev_top_le, prev_top_te = None, None
        prev_bot_le, prev_bot_te = None, None
        for x_base, y_ref, z_dihed, le_c, te_c in wing_stations:
            x = sign * abs(x_base)
            y_le = y_ref + le_c
            y_te = y_ref + te_c
            mat = MAT_YELLOW_BAND if abs(x_base) > 45 else MAT_BODY

            t_le = mesh.add_vertex(x, y_le, z_dihed + 1.2)
            t_te = mesh.add_vertex(x, y_te, z_dihed)
            b_le = mesh.add_vertex(x, y_le, z_dihed - 1.2)
            b_te = mesh.add_vertex(x, y_te, z_dihed - 0.5)

            if prev_top_le is not None:
                if sign == -1:
                    mesh.add_quad(prev_top_le, t_le, t_te, prev_top_te, mat)
                    mesh.add_quad(prev_bot_te, b_te, b_le, prev_bot_le, MAT_BODY)
                else:
                    mesh.add_quad(t_le, prev_top_le, prev_top_te, t_te, mat)
                    mesh.add_quad(b_te, prev_bot_te, prev_bot_le, b_le, MAT_BODY)

            prev_top_le, prev_top_te = t_le, t_te
            prev_bot_le, prev_bot_te = b_le, b_te

        # Twin 20mm Hispano Autocannons
        gun_x = sign * 28.0
        g0 = mesh.add_vertex(gun_x, 30.0, 1.8)
        g1 = mesh.add_vertex(gun_x, 48.0, 1.8)
        mesh.add_quad(g0, g1, g1, g0, MAT_CANNONS)

    # 4. Bubble Canopy
    c_pts = [
        mesh.add_vertex(0.0, 18.0, 9.2), mesh.add_vertex(-3.8, 14.0, 6.2),
        mesh.add_vertex(3.8, 14.0, 6.2), mesh.add_vertex(-3.4, -8.0, 5.8),
        mesh.add_vertex(3.4, -8.0, 5.8), mesh.add_vertex(0.0, -14.0, 6.5)
    ]
    mesh.add_quad(c_pts[1], c_pts[0], c_pts[2], c_pts[2], MAT_CANOPY)
    mesh.add_quad(c_pts[1], c_pts[3], c_pts[4], c_pts[2], MAT_CANOPY)
    mesh.add_tri(c_pts[3], c_pts[5], c_pts[4], MAT_CANOPY)

    # 5. Tail Empennage
    t_fin = [
        mesh.add_vertex(0.0, -48.0, 4.0), mesh.add_vertex(0.0, -64.0, 22.0),
        mesh.add_vertex(0.0, -68.0, 4.0)
    ]
    mesh.add_tri(t_fin[0], t_fin[1], t_fin[2], MAT_TAIL)
    for sign in [-1, 1]:
        mesh.add_quad(
            mesh.add_vertex(0.0, -54.0, 2.0), mesh.add_vertex(sign * 22.0, -58.0, 2.5),
            mesh.add_vertex(sign * 20.0, -66.0, 2.5), mesh.add_vertex(0.0, -66.0, 2.0), MAT_TAIL
        )

    return mesh

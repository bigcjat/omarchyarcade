#!/usr/bin/env python3
"""
Sky Ace • de Havilland Mosquito FB.VI 3D Mesh Engine (Canada / RCAF)
Features:
- "The Wooden Wonder" sleek twin-engine balsa/birch composite strike fighter
- Twin Rolls-Royce / Packard Merlin 25 nacelles with counter-rotating props
- Four 20mm Hispano cannons in nose belly + four .303 Browning machine guns
- RCAF roundels with Red Maple Leaf insignia
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

def build_mosquito_mesh():
    mesh = Mesh3D()
    MAT_BODY = 1        # RCAF Dark Green & Medium Sea Grey
    MAT_NACELLE = 2     # Twin Engine Nacelles
    MAT_SPINNER = 3     # Prop Spinners
    MAT_CANOPY = 4      # Bulged Greenhouse Canopy
    MAT_CANNONS = 5     # Belly 20mm Cannons
    MAT_TAIL = 6        # Single Tailfin & Elevators

    # 1. Central Wooden Fuselage
    fuse_secs = [
        (52.0, 4.0, 5.0, 0.0), (38.0, 6.5, 7.5, 0.6), (16.0, 7.6, 8.8, 1.4),
        (-6.0, 7.2, 8.2, 1.2), (-24.0, 5.4, 6.4, 0.8), (-44.0, 3.8, 4.6, 0.6),
        (-60.0, 2.0, 2.8, 0.5), (-72.0, 0.6, 0.8, 0.5)
    ]
    n_rad = 12
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

    # 2. Main Wooden Wings (Span 94, Chord 26)
    wing_stations = [
        (-7.0, 10.0, 0.0, 20.0, -14.0), (-24.0, 8.0, 0.8, 19.0, -12.0),
        (-42.0, 6.0, 1.8, 16.0, -8.0), (-58.0, 4.5, 2.8, 13.0, -4.0),
        (-72.0, 3.0, 3.8, 9.0, -1.0), (-76.0, 0.5, 4.2, 5.0, 1.0)
    ]
    for sign in [-1, 1]:
        prev_top_le, prev_top_te = None, None
        prev_bot_le, prev_bot_te = None, None
        for x_base, y_ref, z_dihed, le_c, te_c in wing_stations:
            x = sign * abs(x_base)
            y_le = y_ref + le_c
            y_te = y_ref + te_c
            t_le = mesh.add_vertex(x, y_le, z_dihed + 1.2)
            t_te = mesh.add_vertex(x, y_te, z_dihed)
            b_le = mesh.add_vertex(x, y_le, z_dihed - 1.2)
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

        # Twin Rolls-Royce Merlin Nacelles (Left and Right)
        nx = sign * 28.0
        nac_tip = mesh.add_vertex(nx, 54.0, 0.0)
        nac_base = []
        for i in range(8):
            th = 2.0 * math.pi * i / 8
            nac_base.append(mesh.add_vertex(nx + 3.4 * math.cos(th), 46.0, 3.4 * math.sin(th)))
            mesh.add_tri(nac_tip, nac_base[i], mesh.add_vertex(nx + 3.4 * math.cos(th + 0.8), 46.0, 3.4 * math.sin(th + 0.8)), MAT_SPINNER)
        # Nacelle Body
        mesh.add_quad(
            mesh.add_vertex(nx - 4, 46.0, 2.0), mesh.add_vertex(nx + 4, 46.0, 2.0),
            mesh.add_vertex(nx + 4, -18.0, 0.0), mesh.add_vertex(nx - 4, -18.0, 0.0), MAT_NACELLE
        )

    # 3. Bulged Canopy
    c_pts = [
        mesh.add_vertex(0.0, 18.0, 9.2), mesh.add_vertex(-3.8, 14.0, 6.2),
        mesh.add_vertex(3.8, 14.0, 6.2), mesh.add_vertex(-3.6, -6.0, 5.8),
        mesh.add_vertex(3.6, -6.0, 5.8), mesh.add_vertex(0.0, -12.0, 6.5)
    ]
    mesh.add_quad(c_pts[1], c_pts[0], c_pts[2], c_pts[2], MAT_CANOPY)
    mesh.add_quad(c_pts[1], c_pts[3], c_pts[4], c_pts[2], MAT_CANOPY)
    mesh.add_tri(c_pts[3], c_pts[5], c_pts[4], MAT_CANOPY)

    # 4. Tail Empennage
    for sign in [-1, 1]:
        mesh.add_quad(
            mesh.add_vertex(0.0, -56.0, 2.0), mesh.add_vertex(sign * 22.0, -60.0, 2.4),
            mesh.add_vertex(sign * 18.0, -68.0, 2.4), mesh.add_vertex(0.0, -68.0, 2.0), MAT_TAIL
        )
    mesh.add_tri(
        mesh.add_vertex(0.0, -48.0, 3.5), mesh.add_vertex(0.0, -70.0, 24.0),
        mesh.add_vertex(0.0, -72.0, 3.5), MAT_TAIL
    )

    return mesh

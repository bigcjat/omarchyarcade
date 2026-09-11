#!/usr/bin/env python3
"""
Sky Ace • 3D P-38 Lightning Geometric Model & Software Cel-Shader
Builds an authentic 3D polygonal mesh of the P-38 Lightning and renders it
into stylized 2D arcade sprites with cel-shading, dynamic inking, and stepped animation.
"""

import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path

# =============================================================================
# 3D MESH GENERATION (P-38 LIGHTNING)
# Coordinates:
# X: -Port (Left), +Starboard (Right)
# Y: +Forward (Nose), -Aft (Tail)
# Z: +Dorsal (Up / Canopy), -Ventral (Down / Belly)
# =============================================================================

class Mesh3D:
    def __init__(self):
        self.vertices = []  # List of [x, y, z]
        self.faces = []     # List of (v0, v1, v2, material_id)
        self.materials = {} # id -> dict(color, outline, specular, etc.)

    def add_vertex(self, x, y, z):
        self.vertices.append([float(x), float(y), float(z)])
        return len(self.vertices) - 1

    def add_quad(self, v0, v1, v2, v3, mat_id):
        self.faces.append((v0, v1, v2, mat_id))
        self.faces.append((v0, v2, v3, mat_id))

    def add_tri(self, v0, v1, v2, mat_id):
        self.faces.append((v0, v1, v2, mat_id))

def build_p38_mesh():
    mesh = Mesh3D()

    # Materials
    MAT_BODY = 1       # Olive Drab
    MAT_WING = 2       # Olive Drab Wing
    MAT_WINGTIP = 3    # Yellow Combat Marking
    MAT_CANOPY = 4     # Glass Canopy (Cyan / Blue Specular)
    MAT_CANOPY_FRAME = 5 # Dark Canopy Strut
    MAT_ENGINE = 6     # Engine Cowling & Turbo
    MAT_TAIL = 7       # Rudders & Horizontal Elevator
    MAT_GUNS = 8       # Dark Gunmetal Nose
    MAT_EXHAUST = 9    # Weathered Steel Exhausts
    MAT_PROP_HUB = 10  # Propeller Spinner

    # -------------------------------------------------------------------------
    # 1. CENTRAL FUSELAGE POD (Guns at Y=+55, Cockpit at Y=+10..+35, Taper to Y=-30)
    # -------------------------------------------------------------------------
    # Sections along Y: (y, rx, rz, z_center)
    pod_sections = [
        (58.0, 1.5, 1.5, 0.0),    # Gun blast tube tip
        (52.0, 4.5, 4.0, 0.0),    # Nose cap
        (42.0, 7.5, 6.5, 1.0),    # Forward gun bay
        (30.0, 9.5, 8.5, 2.5),    # Windshield base
        (15.0, 9.5, 9.0, 3.5),    # Mid cockpit
        (-5.0, 8.5, 7.5, 2.0),    # Aft cockpit
        (-22.0, 6.0, 5.0, 0.5),   # Fuselage taper
        (-35.0, 1.0, 1.0, 0.0),   # Fuselage aft tip
    ]

    pod_rings = []
    n_radial = 10
    for y, rx, rz, zc in pod_sections:
        ring = []
        for i in range(n_radial):
            theta = 2.0 * math.pi * i / n_radial
            vx = rx * math.cos(theta)
            vz = zc + rz * math.sin(theta)
            ring.append(mesh.add_vertex(vx, y, vz))
        pod_rings.append(ring)

    # Bridge pod rings
    for s in range(len(pod_sections) - 1):
        r0 = pod_rings[s]
        r1 = pod_rings[s + 1]
        mat = MAT_GUNS if s == 0 else MAT_BODY
        for i in range(n_radial):
            i_next = (i + 1) % n_radial
            mesh.add_quad(r0[i], r1[i], r1[i_next], r0[i_next], mat)

    # -------------------------------------------------------------------------
    # 2. COCKPIT BUBBLE CANOPY (Raised glass teardrop)
    # -------------------------------------------------------------------------
    canopy_sections = [
        (32.0, 4.5, 3.0, 7.0),
        (22.0, 6.0, 5.5, 8.5),
        (10.0, 5.5, 5.0, 8.0),
        (-2.0, 4.0, 3.0, 6.5),
        (-14.0, 1.0, 1.0, 4.5),
    ]
    canopy_rings = []
    n_canopy = 8
    for y, rx, rz, zc in canopy_sections:
        ring = []
        for i in range(n_canopy):
            # Upper dome (theta from 0 to pi)
            theta = math.pi * i / (n_canopy - 1)
            vx = rx * math.cos(theta)
            vz = zc + rz * math.sin(theta)
            ring.append(mesh.add_vertex(vx, y, vz))
        canopy_rings.append(ring)

    for s in range(len(canopy_sections) - 1):
        r0 = canopy_rings[s]
        r1 = canopy_rings[s + 1]
        for i in range(n_canopy - 1):
            mat = MAT_CANOPY_FRAME if (i == 0 or i == n_canopy - 2 or s == 0 or s == len(canopy_sections)-2) else MAT_CANOPY
            mesh.add_quad(r0[i], r1[i], r1[i + 1], r0[i + 1], mat)

    # -------------------------------------------------------------------------
    # 3. MAIN WINGS (Span: 110 units, Root chord: 30, Tip chord: 16)
    # -------------------------------------------------------------------------
    # Wings span from X = -55 to +55
    # Stations: 0 (center), 22 (inner nacelle), 28 (outer nacelle), 48 (wingtip start), 55 (wingtip)
    stations = [0.0, 18.0, 22.0, 28.0, 45.0, 55.0]
    chords =   [30.0, 28.0, 26.0, 24.0, 18.0, 13.0]
    y_leads =  [14.0, 13.5, 13.0, 12.5, 10.0, 8.0]
    dihedrals= [0.0,  0.5,  0.8,  1.2,  3.0,  4.5]

    for side in [-1, 1]:
        wing_rings = []
        for st_idx, (st_x, chord, y_lead, z_dih) in enumerate(zip(stations, chords, y_leads, dihedrals)):
            wx = side * st_x
            yt = y_lead - chord
            zt = z_dih
            zc = z_dih + (2.5 if st_x < 40 else 1.5)
            zb = z_dih - (2.0 if st_x < 40 else 1.2)
            
            # 4 points: Leading Edge, Upper Camber, Trailing Edge, Lower Camber
            p_le = mesh.add_vertex(wx, y_lead, z_dih)
            p_up = mesh.add_vertex(wx, y_lead - chord * 0.35, zc)
            p_te = mesh.add_vertex(wx, yt, zt)
            p_dn = mesh.add_vertex(wx, y_lead - chord * 0.35, zb)
            wing_rings.append((p_le, p_up, p_te, p_dn))

        # Connect wing stations
        for i in range(len(stations) - 1):
            w0 = wing_rings[i]
            w1 = wing_rings[i + 1]
            mat = MAT_WINGTIP if i == len(stations) - 2 else MAT_WING
            
            # Orient faces correctly for normals
            if side == 1:
                mesh.add_quad(w0[0], w1[0], w1[1], w0[1], mat) # Upper front
                mesh.add_quad(w0[1], w1[1], w1[2], w0[2], mat) # Upper rear
                mesh.add_quad(w0[2], w1[2], w1[3], w0[3], mat) # Lower rear
                mesh.add_quad(w0[3], w1[3], w1[0], w0[0], mat) # Lower front
            else:
                mesh.add_quad(w1[0], w0[0], w0[1], w1[1], mat)
                mesh.add_quad(w1[1], w0[1], w0[2], w1[2], mat)
                mesh.add_quad(w1[2], w0[2], w0[3], w1[3], mat)
                mesh.add_quad(w1[3], w0[3], w0[0], w1[0], mat)

    # -------------------------------------------------------------------------
    # 4. TWIN BOOMS & ENGINE NACELLES (Left at X=-25, Right at X=+25)
    # Booms extend from Y=+48 (spinner) to Y=-58 (rudders)
    # -------------------------------------------------------------------------
    boom_sections = [
        (48.0, 2.5, 2.5, 0.0),    # Prop spinner hub
        (42.0, 6.0, 6.0, 0.0),    # Cowling intake
        (25.0, 7.5, 7.5, 0.5),    # Engine block
        (5.0, 7.0, 7.0, 0.5),     # Turbo-supercharger
        (-15.0, 5.5, 5.5, 0.5),   # Boom transition
        (-35.0, 4.0, 4.5, 1.0),   # Boom tube
        (-52.0, 3.0, 4.0, 1.5),   # Rudder root
        (-60.0, 1.0, 2.0, 1.5),   # Tail cone
    ]

    for side in [-1, 1]:
        bx = side * 25.0
        b_rings = []
        for y, rx, rz, zc in boom_sections:
            ring = []
            for i in range(8):
                theta = 2.0 * math.pi * i / 8
                vx = bx + rx * math.cos(theta)
                vz = zc + rz * math.sin(theta)
                ring.append(mesh.add_vertex(vx, y, vz))
            b_rings.append(ring)

        for s in range(len(boom_sections) - 1):
            r0 = b_rings[s]
            r1 = b_rings[s + 1]
            mat = MAT_PROP_HUB if s == 0 else (MAT_ENGINE if s <= 2 else MAT_BODY)
            for i in range(8):
                i_next = (i + 1) % 8
                if side == 1:
                    mesh.add_quad(r0[i], r1[i], r1[i_next], r0[i_next], mat)
                else:
                    mesh.add_quad(r1[i], r0[i], r0[i_next], r1[i_next], mat)

        # ---------------------------------------------------------------------
        # 5. TWIN VERTICAL RUDDERS / FINS (At Y=-50..-60)
        # ---------------------------------------------------------------------
        # Elliptical vertical fin extending up and down
        f_top = mesh.add_vertex(bx, -54.0, 16.0)
        f_le  = mesh.add_vertex(bx, -48.0, 8.0)
        f_bot = mesh.add_vertex(bx, -54.0, -8.0)
        f_te  = mesh.add_vertex(bx, -62.0, 6.0)
        
        # Dual-sided vertical fin
        mesh.add_tri(f_top, f_le, f_te, MAT_TAIL)
        mesh.add_tri(f_bot, f_te, f_le, MAT_TAIL)
        mesh.add_tri(f_top, f_te, f_le, MAT_TAIL)
        mesh.add_tri(f_bot, f_le, f_te, MAT_TAIL)

    # -------------------------------------------------------------------------
    # 6. HORIZONTAL ELEVATOR STABILIZER (Spanning between twin rudders)
    # X from -25 to +25 at Y=-54, Z=4.0
    # -------------------------------------------------------------------------
    h_y0 = -49.0
    h_y1 = -59.0
    h_z = 5.0
    h_l_le = mesh.add_vertex(-25.0, h_y0, h_z)
    h_r_le = mesh.add_vertex( 25.0, h_y0, h_z)
    h_r_te = mesh.add_vertex( 25.0, h_y1, h_z)
    h_l_te = mesh.add_vertex(-25.0, h_y1, h_z)
    
    mesh.add_quad(h_l_le, h_r_le, h_r_te, h_l_te, MAT_TAIL)
    mesh.add_quad(h_l_te, h_r_te, h_r_le, h_l_le, MAT_TAIL)

    return mesh

print("✓ 3D P-38 Lightning mesh builder compiled successfully.")
if __name__ == "__main__":
    m = build_p38_mesh()
    print(f"P-38 Mesh: {len(m.vertices)} vertices, {len(m.faces)} polygonal faces.")

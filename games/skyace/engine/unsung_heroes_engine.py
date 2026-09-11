#!/usr/bin/env python3
"""
Sky Ace • 8 Unsung WWII Warbirds 3D Mesh Engines & Sprite Builders
Builds 3D polygonal models, cel-shaders, and spritesheets for the 10-Second Tactical Air Support system:
1. Hawker Hurricane (UK) - Bullet Sponge & 8x Browning gunner
2. Bell P-39 Airacobra (USA) - Mid-engine 37mm Heavy Sniper
3. Nakajima Ki-43 Oscar (Japan) - Acrobatic Butterfly Flaps Interceptor
4. Henschel Hs 129 Panzerknacker (Germany) - Armored Bathtub Tank Buster
5. Polikarpov I-16 Ishak (USSR) - Stubby Barrel-Chested Dogfighter
6. Fiat CR.42 Falco (Italy) - Supreme Aerobatic Biplane Decoy
7. Morane-Saulnier M.S.406 (France) - Frontline Aegis & 20mm Motor-Cannon
8. Bristol Beaufighter (Canada/Allies) - "Whispering Death" Heavy Gunship
"""

import math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SPRITES_DIR = Path("games/skyace/sprites")
SPRITES_DIR.mkdir(parents=True, exist_ok=True)


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
# MESH BUILDERS
# =============================================================================
def build_cylinder(mesh, stations, n_rad=10, mat_id=1):
    rings = []
    for y, rx, rz, zc in stations:
        ring = []
        for i in range(n_rad):
            th = 2.0 * math.pi * i / n_rad
            ring.append(mesh.add_vertex(rx * math.cos(th), y, zc + rz * math.sin(th)))
        rings.append(ring)
    for s in range(len(stations) - 1):
        r0, r1 = rings[s], rings[s + 1]
        for i in range(n_rad):
            mesh.add_quad(r0[i], r1[i], r1[(i + 1) % n_rad], r0[(i + 1) % n_rad], mat_id)
    return rings


def build_wings(mesh, wing_stations, mat_top=1, mat_bot=2):
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
                mesh.add_quad(prev_top_le, t_le, t_te, prev_top_te, mat_top)
                mesh.add_quad(prev_bot_te, b_te, b_le, prev_bot_le, mat_bot)
                mesh.add_quad(prev_top_le, prev_bot_le, b_le, t_le, mat_top)
                mesh.add_quad(prev_top_te, t_te, b_te, prev_bot_te, mat_top)

            prev_top_le, prev_top_te = t_le, t_te
            prev_bot_le, prev_bot_te = b_le, b_te


# 1. Hawker Hurricane
def build_hurricane_mesh():
    mesh = Mesh3D()
    stations = [
        (48.0, 1.0, 1.0, 0.0), (44.0, 4.2, 4.2, 0.2), (24.0, 6.2, 6.8, 0.5),
        (6.0, 6.8, 7.8, 1.2), (-18.0, 5.8, 6.5, 0.8), (-38.0, 3.8, 4.5, 0.5),
        (-56.0, 1.4, 2.0, 0.4)
    ]
    build_cylinder(mesh, stations, mat_id=1)
    wings = [(6.0, 16.0, -18.0, 4.6, 0.2), (24.0, 12.0, -15.0, 3.8, 1.2), (44.0, 7.0, -11.0, 2.6, 2.4), (58.0, 2.0, -6.0, 1.2, 3.2)]
    build_wings(mesh, wings, mat_top=1, mat_bot=2)
    # Tail
    mesh.add_quad(mesh.add_vertex(0, -44, 4), mesh.add_vertex(0, -56, 18), mesh.add_vertex(0, -60, 16), mesh.add_vertex(0, -56, 3), 1)
    for s in [-1, 1]:
        mesh.add_quad(mesh.add_vertex(0, -50, 3), mesh.add_vertex(s * 22, -54, 3.5), mesh.add_vertex(s * 20, -58, 3.5), mesh.add_vertex(0, -56, 3), 1)
    return mesh


# 2. Bell P-39 Airacobra
def build_p39_mesh():
    mesh = Mesh3D()
    stations = [
        (46.0, 0.8, 0.8, 0.0), (38.0, 3.6, 3.6, 0.2), (20.0, 5.8, 6.5, 0.8), # Cannon nose
        (4.0, 6.2, 7.5, 1.4), (-12.0, 6.4, 7.2, 1.0), (-32.0, 4.2, 4.8, 0.6), (-54.0, 1.2, 1.8, 0.4) # Mid engine
    ]
    build_cylinder(mesh, stations, mat_id=1)
    wings = [(6.0, 12.0, -16.0, 4.2, 0.2), (22.0, 9.0, -13.0, 3.4, 1.2), (38.0, 5.0, -9.0, 2.4, 2.2), (52.0, 2.0, -5.0, 1.0, 3.0)]
    build_wings(mesh, wings, mat_top=1, mat_bot=2)
    # 37mm Cannon Barrel in prop hub
    mesh.add_quad(mesh.add_vertex(-0.5, 46, 0), mesh.add_vertex(0.5, 46, 0), mesh.add_vertex(0.5, 56, 0), mesh.add_vertex(-0.5, 56, 0), 3)
    # Tail
    mesh.add_quad(mesh.add_vertex(0, -42, 3), mesh.add_vertex(0, -52, 16), mesh.add_vertex(0, -56, 15), mesh.add_vertex(0, -54, 2), 1)
    for s in [-1, 1]:
        mesh.add_quad(mesh.add_vertex(0, -48, 2), mesh.add_vertex(s * 20, -52, 2.5), mesh.add_vertex(s * 18, -56, 2.5), mesh.add_vertex(0, -54, 2), 1)
    return mesh


# 3. Nakajima Ki-43 Oscar
def build_ki43_mesh():
    mesh = Mesh3D()
    stations = [
        (42.0, 4.8, 4.8, 0.0), (32.0, 5.4, 5.4, 0.2), (16.0, 5.2, 5.8, 0.8), # Radial nose
        (-2.0, 4.8, 5.2, 0.8), (-24.0, 3.2, 3.6, 0.5), (-46.0, 1.0, 1.5, 0.2)
    ]
    build_cylinder(mesh, stations, mat_id=1)
    wings = [(5.0, 14.0, -14.0, 4.0, 0.2), (20.0, 11.0, -11.0, 3.2, 1.4), (36.0, 7.0, -8.0, 2.2, 2.6), (54.0, 2.0, -4.0, 1.0, 3.6)]
    build_wings(mesh, wings, mat_top=1, mat_bot=2)
    # Tail
    mesh.add_quad(mesh.add_vertex(0, -36, 2), mesh.add_vertex(0, -44, 15), mesh.add_vertex(0, -48, 14), mesh.add_vertex(0, -46, 1), 1)
    for s in [-1, 1]:
        mesh.add_quad(mesh.add_vertex(0, -40, 1), mesh.add_vertex(s * 19, -44, 1.5), mesh.add_vertex(s * 17, -48, 1.5), mesh.add_vertex(0, -46, 1), 1)
    return mesh


# 4. Henschel Hs 129 Panzerknacker
def build_hs129_mesh():
    mesh = Mesh3D()
    # Armored triangular/trapezoid bathtub fuselage
    stations = [
        (38.0, 2.8, 2.8, 0.0), (28.0, 4.6, 5.2, 0.4), (10.0, 5.2, 6.2, 0.8),
        (-10.0, 5.0, 5.8, 0.6), (-30.0, 3.6, 4.2, 0.4), (-50.0, 1.2, 1.6, 0.2)
    ]
    build_cylinder(mesh, stations, mat_id=1)
    wings = [(5.0, 12.0, -14.0, 4.4, 0.0), (18.0, 10.0, -12.0, 3.8, 0.6), (36.0, 7.0, -9.0, 2.8, 1.4), (52.0, 4.0, -6.0, 1.4, 2.0)]
    build_wings(mesh, wings, mat_top=1, mat_bot=2)
    # Twin Gnome-Rhone radial engines on wings
    for s in [-1, 1]:
        ex = s * 18.0
        for i in range(8):
            th0, th1 = 2*math.pi*i/8, 2*math.pi*(i+1)/8
            r = 3.2
            mesh.add_quad(
                mesh.add_vertex(ex + r*math.cos(th0), 16, r*math.sin(th0)),
                mesh.add_vertex(ex + r*math.cos(th1), 16, r*math.sin(th1)),
                mesh.add_vertex(ex + r*math.cos(th1), 4, r*math.sin(th1)),
                mesh.add_vertex(ex + r*math.cos(th0), 4, r*math.sin(th0)),
                1
            )
    # Underslung 30mm/75mm Anti-Tank Gun Pod
    mesh.add_quad(mesh.add_vertex(-1.5, 26, -3), mesh.add_vertex(1.5, 26, -3), mesh.add_vertex(1.5, -8, -3), mesh.add_vertex(-1.5, -8, -3), 3)
    mesh.add_quad(mesh.add_vertex(-0.6, 26, -3), mesh.add_vertex(0.6, 26, -3), mesh.add_vertex(0.6, 42, -3), mesh.add_vertex(-0.6, 42, -3), 3)
    # Tail
    mesh.add_quad(mesh.add_vertex(0, -40, 2), mesh.add_vertex(0, -48, 14), mesh.add_vertex(0, -52, 13), mesh.add_vertex(0, -50, 1), 1)
    for s in [-1, 1]:
        mesh.add_quad(mesh.add_vertex(0, -44, 1), mesh.add_vertex(s * 20, -47, 1.5), mesh.add_vertex(s * 18, -51, 1.5), mesh.add_vertex(0, -50, 1), 1)
    return mesh


# 5. Polikarpov I-16 Ishak
def build_i16_mesh():
    mesh = Mesh3D()
    # Stubby barrel-chested fuselage
    stations = [
        (30.0, 5.8, 5.8, 0.0), (20.0, 6.8, 6.8, 0.2), (4.0, 6.5, 6.8, 0.6),
        (-12.0, 4.8, 5.2, 0.4), (-26.0, 1.8, 2.2, 0.2)
    ]
    build_cylinder(mesh, stations, mat_id=1)
    wings = [(6.0, 14.0, -12.0, 4.4, 0.2), (20.0, 10.0, -9.0, 3.2, 1.2), (34.0, 5.0, -6.0, 2.0, 2.2), (44.0, 1.0, -3.0, 1.0, 3.0)]
    build_wings(mesh, wings, mat_top=1, mat_bot=2)
    # Open cockpit windshield
    mesh.add_tri(mesh.add_vertex(0, 8, 7.5), mesh.add_vertex(-2.5, 5, 6.5), mesh.add_vertex(2.5, 5, 6.5), 4)
    # Tail
    mesh.add_quad(mesh.add_vertex(0, -18, 2), mesh.add_vertex(0, -26, 14), mesh.add_vertex(0, -29, 13), mesh.add_vertex(0, -26, 1), 1)
    for s in [-1, 1]:
        mesh.add_quad(mesh.add_vertex(0, -22, 1), mesh.add_vertex(s * 16, -25, 1.5), mesh.add_vertex(s * 14, -28, 1.5), mesh.add_vertex(0, -26, 1), 1)
    return mesh


# 6. Fiat CR.42 Falco (Biplane)
def build_cr42_mesh():
    mesh = Mesh3D()
    stations = [
        (38.0, 4.5, 4.5, 0.0), (28.0, 5.2, 5.2, 0.2), (10.0, 4.8, 5.4, 0.6),
        (-10.0, 4.0, 4.6, 0.4), (-30.0, 2.4, 2.8, 0.2), (-46.0, 1.0, 1.2, 0.1)
    ]
    build_cylinder(mesh, stations, mat_id=1)
    # Upper Wing (Mounted higher on cabane struts, span 52)
    upper_wings = [(0.0, 14.0, -6.0, 2.2, 7.5), (20.0, 12.0, -5.0, 2.0, 7.8), (38.0, 9.0, -4.0, 1.6, 8.2), (52.0, 5.0, -2.0, 1.0, 8.5)]
    build_wings(mesh, upper_wings, mat_top=1, mat_bot=2)
    # Lower Wing (Shorter sesquiplane span 36, mounted low)
    lower_wings = [(5.0, 8.0, -8.0, 2.0, -1.0), (20.0, 7.0, -7.0, 1.6, -0.6), (36.0, 5.0, -5.0, 1.0, -0.2)]
    build_wings(mesh, lower_wings, mat_top=1, mat_bot=2)
    # Interplane Struts connecting wings
    for s in [-1, 1]:
        sx = s * 28.0
        mesh.add_quad(mesh.add_vertex(sx, 10, 7.8), mesh.add_vertex(sx+0.5, 10, 7.8), mesh.add_vertex(sx+0.5, 6, -0.6), mesh.add_vertex(sx, 6, -0.6), 3)
    # Tail
    mesh.add_quad(mesh.add_vertex(0, -38, 2), mesh.add_vertex(0, -45, 13), mesh.add_vertex(0, -48, 12), mesh.add_vertex(0, -46, 1), 1)
    for s in [-1, 1]:
        mesh.add_quad(mesh.add_vertex(0, -42, 1), mesh.add_vertex(s * 18, -44, 1.5), mesh.add_vertex(s * 16, -47, 1.5), mesh.add_vertex(0, -46, 1), 1)
    return mesh


# 7. Morane-Saulnier M.S.406
def build_ms406_mesh():
    mesh = Mesh3D()
    stations = [
        (44.0, 1.2, 1.2, 0.0), (38.0, 4.4, 4.6, 0.2), (18.0, 5.8, 6.6, 0.8),
        (0.0, 6.2, 7.0, 1.0), (-20.0, 4.8, 5.6, 0.6), (-42.0, 2.2, 2.8, 0.3), (-56.0, 1.0, 1.2, 0.1)
    ]
    build_cylinder(mesh, stations, mat_id=1)
    wings = [(6.0, 14.0, -15.0, 4.2, 0.2), (22.0, 10.0, -12.0, 3.4, 1.2), (38.0, 6.0, -8.0, 2.4, 2.2), (54.0, 2.0, -4.0, 1.0, 3.0)]
    build_wings(mesh, wings, mat_top=1, mat_bot=2)
    # Retractable Ventral Radiator under belly
    mesh.add_quad(mesh.add_vertex(-2.0, 8, -4.2), mesh.add_vertex(2.0, 8, -4.2), mesh.add_vertex(2.0, -6, -4.2), mesh.add_vertex(-2.0, -6, -4.2), 3)
    # Tail
    mesh.add_quad(mesh.add_vertex(0, -44, 2), mesh.add_vertex(0, -54, 15), mesh.add_vertex(0, -58, 14), mesh.add_vertex(0, -56, 1), 1)
    for s in [-1, 1]:
        mesh.add_quad(mesh.add_vertex(0, -48, 1), mesh.add_vertex(s * 20, -52, 1.5), mesh.add_vertex(s * 18, -56, 1.5), mesh.add_vertex(0, -56, 1), 1)
    return mesh


# 8. Bristol Beaufighter
def build_beaufighter_mesh():
    mesh = Mesh3D()
    # Brute blunt nose fuselage
    stations = [
        (34.0, 3.5, 3.8, 0.2), (24.0, 6.0, 6.5, 0.6), (6.0, 6.6, 7.4, 1.0),
        (-16.0, 6.2, 6.8, 0.8), (-38.0, 4.6, 5.2, 0.5), (-60.0, 2.2, 2.6, 0.3), (-74.0, 0.8, 1.0, 0.1)
    ]
    build_cylinder(mesh, stations, mat_id=1)
    wings = [(6.0, 16.0, -16.0, 4.6, 0.2), (22.0, 13.0, -13.0, 4.0, 1.0), (44.0, 9.0, -9.0, 3.0, 2.0), (68.0, 4.0, -5.0, 1.2, 3.0)]
    build_wings(mesh, wings, mat_top=1, mat_bot=2)
    # Twin Hercules radial engines on wings
    for s in [-1, 1]:
        ex = s * 24.0
        for i in range(8):
            th0, th1 = 2*math.pi*i/8, 2*math.pi*(i+1)/8
            r = 4.4
            mesh.add_quad(
                mesh.add_vertex(ex + r*math.cos(th0), 20, r*math.sin(th0)),
                mesh.add_vertex(ex + r*math.cos(th1), 20, r*math.sin(th1)),
                mesh.add_vertex(ex + r*math.cos(th1), 6, r*math.sin(th1)),
                mesh.add_vertex(ex + r*math.cos(th0), 6, r*math.sin(th0)),
                1
            )
    # Tail with dihedral horizontal stabilizers
    mesh.add_quad(mesh.add_vertex(0, -60, 3), mesh.add_vertex(0, -72, 19), mesh.add_vertex(0, -76, 17), mesh.add_vertex(0, -74, 1), 1)
    for s in [-1, 1]:
        mesh.add_quad(mesh.add_vertex(0, -64, 2), mesh.add_vertex(s * 26, -70, 7.0), mesh.add_vertex(s * 24, -75, 7.0), mesh.add_vertex(0, -74, 2), 1)
    return mesh


# =============================================================================
# SPRITE RASTERIZER & GENERATOR
# =============================================================================
PALETTES = {
    "hurricane": {
        "body": (72, 85, 60), "shadow": (42, 52, 35), "high": (105, 122, 90),
        "under": (115, 135, 140), "roundel": (25, 55, 135), "outline": (18, 24, 16, 255)
    },
    "p39": {
        "body": (68, 88, 62), "shadow": (40, 54, 38), "high": (98, 125, 90),
        "under": (100, 115, 125), "roundel": (25, 45, 115), "outline": (16, 22, 16, 255)
    },
    "ki43": {
        "body": (60, 95, 65), "shadow": (35, 60, 38), "high": (90, 138, 98),
        "under": (120, 125, 130), "roundel": (215, 25, 25), "outline": (15, 25, 15, 255)
    },
    "hs129": {
        "body": (55, 70, 58), "shadow": (32, 44, 35), "high": (85, 105, 90),
        "under": (85, 115, 130), "roundel": (235, 235, 235), "outline": (16, 20, 18, 255)
    },
    "i16": {
        "body": (58, 82, 50), "shadow": (34, 50, 30), "high": (88, 118, 76),
        "under": (75, 110, 140), "roundel": (220, 30, 30), "outline": (16, 24, 14, 255)
    },
    "cr42": {
        "body": (145, 125, 75), "shadow": (95, 80, 48), "high": (195, 170, 110),
        "under": (120, 125, 130), "roundel": (245, 245, 245), "outline": (35, 30, 18, 255)
    },
    "ms406": {
        "body": (70, 78, 82), "shadow": (42, 48, 52), "high": (105, 115, 122),
        "under": (95, 120, 145), "roundel": (30, 60, 150), "outline": (18, 20, 24, 255)
    },
    "beaufighter": {
        "body": (60, 72, 78), "shadow": (36, 44, 48), "high": (92, 108, 116),
        "under": (110, 125, 135), "roundel": (25, 55, 135), "outline": (16, 20, 22, 255)
    }
}


def render_unsung_plane(mesh, plane_key, roll_deg=0.0, pitch_deg=0.0, size=256, scale=1.55):
    pal = PALETTES[plane_key]
    r_rad = math.radians(roll_deg)
    p_rad = math.radians(pitch_deg)

    R_roll = np.array([[math.cos(r_rad), 0.0, math.sin(r_rad)], [0.0, 1.0, 0.0], [-math.sin(r_rad), 0.0, math.cos(r_rad)]])
    R_pitch = np.array([[1.0, 0.0, 0.0], [0.0, math.cos(p_rad), -math.sin(p_rad)], [0.0, math.sin(p_rad), math.cos(p_rad)]])
    R_total = R_pitch @ R_roll

    cx, cy = size / 2.0, size / 2.0
    v_screen, v_trans = [], []
    for v in mesh.vertices:
        v_rot = R_total @ np.array(v)
        v_trans.append(v_rot)
        v_screen.append((cx + v_rot[0] * scale, cy - v_rot[1] * scale, v_rot[2]))

    l_dir = np.array([-0.3, 0.5, 0.81])
    l_dir = l_dir / np.linalg.norm(l_dir)

    faces_to_render = []
    for face in mesh.faces:
        v0, v1, v2 = v_trans[face[0]], v_trans[face[1]], v_trans[face[2]]
        norm = np.cross(v1 - v0, v2 - v0)
        n_len = np.linalg.norm(norm)
        if n_len < 1e-6: continue
        norm = norm / n_len
        intensity = float(np.dot(norm, l_dir))
        mean_z = (v_screen[face[0]][2] + v_screen[face[1]][2] + v_screen[face[2]][2]) / 3.0
        faces_to_render.append((mean_z, face, intensity))

    faces_to_render.sort(key=lambda x: x[0])

    img_arr = np.zeros((size, size, 4), dtype=np.uint8)
    z_buffer = np.full((size, size), -99999.0, dtype=np.float32)

    for mean_z, (v0_idx, v1_idx, v2_idx, mat_id), intensity in faces_to_render:
        if mat_id == 2: base_col = pal["under"]
        elif mat_id == 3: base_col = (45, 48, 52)
        elif mat_id == 4: base_col = (110, 160, 210)
        else: base_col = pal["body"]

        if intensity < 0.25:
            col = tuple(max(0, int(c * 0.6)) for c in base_col)
        elif intensity < 0.65:
            col = base_col
        else:
            col = tuple(min(255, int(c * 1.35)) for c in base_col)

        p0, p1, p2 = v_screen[v0_idx], v_screen[v1_idx], v_screen[v2_idx]
        min_x, max_x = max(0, int(math.floor(min(p0[0], p1[0], p2[0])))), min(size - 1, int(math.ceil(max(p0[0], p1[0], p2[0]))))
        min_y, max_y = max(0, int(math.floor(min(p0[1], p1[1], p2[1])))), min(size - 1, int(math.ceil(max(p0[1], p1[1], p2[1]))))
        if min_x > max_x or min_y > max_y: continue
        denom = (p1[1] - p2[1]) * (p0[0] - p2[0]) + (p2[0] - p1[0]) * (p0[1] - p2[1])
        if abs(denom) < 1e-6: continue

        x_g, y_g = np.meshgrid(np.arange(min_x, max_x + 1), np.arange(min_y, max_y + 1))
        w0 = ((p1[1] - p2[1]) * (x_g - p2[0]) + (p2[0] - p1[0]) * (y_g - p2[1])) / denom
        w1 = ((p2[1] - p0[1]) * (x_g - p2[0]) + (p0[0] - p2[0]) * (y_g - p2[1])) / denom
        w2 = 1.0 - w0 - w1
        inside = (w0 >= 0.0) & (w1 >= 0.0) & (w2 >= 0.0)
        z_int = w0 * p0[2] + w1 * p1[2] + w2 * p2[2]

        sub_z = z_buffer[min_y:max_y+1, min_x:max_x+1]
        z_pass = inside & (z_int > sub_z)
        if np.any(z_pass):
            sub_z[z_pass] = z_int[z_pass]
            sub_img = img_arr[min_y:max_y+1, min_x:max_x+1]
            sub_img[z_pass, :3] = col
            sub_img[z_pass, 3] = 255

    # Outlines
    alpha = img_arr[:, :, 3]
    mask_img = Image.fromarray((alpha > 0).astype(np.uint8) * 255, "L")
    edges = mask_img.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.MaxFilter(3))
    out_mask = (np.array(edges) > 30) & (alpha == 0)
    img_arr[out_mask] = pal["outline"]

    res = Image.fromarray(img_arr, "RGBA")
    draw = ImageDraw.Draw(res)

    # Spinning Propeller Blur at Nose
    if plane_key != "beaufighter" and plane_key != "hs129":
        # Single nose prop
        draw.ellipse([cx - 24 * scale * 0.5, cy - 38 * scale - 3, cx + 24 * scale * 0.5, cy - 38 * scale + 3], fill=(245, 215, 45, 175))
        draw.ellipse([cx - 4, cy - 38 * scale - 4, cx + 4, cy - 38 * scale + 4], fill=(30, 32, 35, 255))
    else:
        # Twin wing props
        for ex in [-24.0, 24.0]:
            px = cx + ex * scale
            py = cy - 20 * scale
            draw.ellipse([px - 14 * scale, py - 3, px + 14 * scale, py + 3], fill=(245, 215, 45, 170))
            draw.ellipse([px - 4, py - 4, px + 4, py + 4], fill=(30, 32, 35, 255))

    return res


def build_all_unsung_heroes():
    heroes = [
        ("hurricane", build_hurricane_mesh()),
        ("p39", build_p39_mesh()),
        ("ki43", build_ki43_mesh()),
        ("hs129", build_hs129_mesh()),
        ("i16", build_i16_mesh()),
        ("cr42", build_cr42_mesh()),
        ("ms406", build_ms406_mesh()),
        ("beaufighter", build_beaufighter_mesh()),
    ]

    cell_size = 256
    sheet_w = cell_size * 3
    sheet_h = cell_size * 1

    for key, mesh in heroes:
        sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))
        # Frame 0: Level
        sheet.paste(render_unsung_plane(mesh, key, roll_deg=0.0), (0, 0))
        # Frame 1: Bank Left
        sheet.paste(render_unsung_plane(mesh, key, roll_deg=-20.0), (cell_size, 0))
        # Frame 2: Bank Right
        sheet.paste(render_unsung_plane(mesh, key, roll_deg=20.0), (cell_size * 2, 0))

        out_path = SPRITES_DIR / f"sheet_unsung_{key}.png"
        sheet.save(out_path, "PNG")
        print(f"✓ Saved {out_path} ({sheet_w}x{sheet_h})")


if __name__ == "__main__":
    build_all_unsung_heroes()

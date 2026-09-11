#!/usr/bin/env python3
"""
Sky Ace • Player 3D Airframe Engines & Cel-Shaders
Builds high-fidelity 3D polygonal models and cel-shaders for:
1. Supermarine Spitfire Mk.IX (Great Britain)
2. Messerschmitt Bf 109 Gustav (Germany)
3. Yakovlev Yak-3 (Soviet Union)
4. de Havilland Mosquito FB.VI (Canada)
"""

from pathlib import Path

ENGINE_DIR = Path("games/skyace/engine")
ENGINE_DIR.mkdir(parents=True, exist_ok=True)

# -----------------------------------------------------------------------------
# 1. SPITFIRE MK.IX 3D ENGINE
# -----------------------------------------------------------------------------
spitfire_mesh_code = '''#!/usr/bin/env python3
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
'''

spitfire_render_code = '''#!/usr/bin/env python3
import math
from PIL import Image, ImageDraw

def render_3d_spitfire_frame(mesh, roll_deg=0.0, pitch_deg=0.0, yaw_deg=0.0, prop_angle=0.0, style="tactical"):
    w, h = 180, 180
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    # Palettes
    C_BODY = (68, 86, 60, 255)
    C_LIGHT = (104, 126, 94, 255)
    C_OUTLINE = (22, 30, 20, 255)
    C_YELLOW = (245, 205, 45, 255)
    C_CANOPY = (140, 220, 255, 230)
    C_ROUNDEL_BLUE = (24, 48, 120, 255)
    C_ROUNDEL_WHITE = (245, 245, 250, 255)
    C_ROUNDEL_RED = (215, 30, 30, 255)

    r_rad = math.radians(roll_deg)
    p_rad = math.radians(pitch_deg)
    cos_r, sin_r = math.cos(r_rad), math.sin(r_rad)
    cos_p, sin_p = math.cos(p_rad), math.sin(p_rad)

    transformed = []
    for x, y, z in mesh.vertices:
        # Pitch (around X)
        yp = y * cos_p - z * sin_p
        zp = y * sin_p + z * cos_p
        # Roll (around Y)
        xr = x * cos_r + zp * sin_r
        zr = -x * sin_r + zp * cos_r
        # Project orthographic
        sx = cx + xr * 1.15
        sy = cy - yp * 1.15
        transformed.append((sx, sy, zr))

    # Sort faces by depth
    face_depths = []
    for idx, f in enumerate(mesh.faces):
        v0, v1, v2, mat = f
        avg_z = (transformed[v0][2] + transformed[v1][2] + transformed[v2][2]) / 3.0
        face_depths.append((avg_z, idx, f))
    face_depths.sort(key=lambda x: x[0])

    for _, _, (v0, v1, v2, mat) in face_depths:
        p0 = (transformed[v0][0], transformed[v0][1])
        p1 = (transformed[v1][0], transformed[v1][1])
        p2 = (transformed[v2][0], transformed[v2][1])

        col = C_BODY
        if mat == 4: col = C_YELLOW
        elif mat == 5: col = C_CANOPY
        elif mat == 2: col = (35, 40, 45, 255)

        draw.polygon([p0, p1, p2], fill=col, outline=C_OUTLINE)

    # RAF Roundels on wings
    for sign in [-1, 1]:
        rx = cx + sign * 38 * cos_r
        ry = cy - 2 * sin_r
        draw.ellipse([rx - 10, ry - 8, rx + 10, ry + 8], fill=C_ROUNDEL_BLUE)
        draw.ellipse([rx - 6, ry - 5, rx + 6, ry + 5], fill=C_ROUNDEL_WHITE)
        draw.ellipse([rx - 3, ry - 2.5, rx + 3, ry + 2.5], fill=C_ROUNDEL_RED)

    # 4-Blade Spinning Propeller Disc
    nose_x = cx + sin_r * 2
    nose_y = cy - 62 * cos_p
    draw.ellipse([nose_x - 22, nose_y - 6, nose_x + 22, nose_y + 6], fill=(245, 220, 75, 180))

    return img
'''

# -----------------------------------------------------------------------------
# 2. MESSERSCHMITT BF 109 3D ENGINE
# -----------------------------------------------------------------------------
bf109_mesh_code = '''#!/usr/bin/env python3
"""
Sky Ace • Messerschmitt Bf 109 Gustav 3D Mesh Engine
Features:
- Angular clipped wings with slats and radiator baths
- Inverted Daimler-Benz DB 605 V12 nose with yellow cowl
- Square-framed canopy & centerline 20mm MG 151/20 cannon
- Balkenkreuz crosses & tail swastika stripe
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

def build_bf109_mesh():
    mesh = Mesh3D()
    MAT_BODY = 1        # RLM 74/75 Grey-Green Camo
    MAT_YELLOW_COWL = 2 # Yellow Eastern Front / Channel Nose Cowl
    MAT_CROSS = 3       # Balkenkreuz
    MAT_CANOPY = 4      # Square Erla Haube Canopy
    MAT_SPINNER = 5     # Black & White Spiral Spinner
    MAT_TAIL = 6        # Empennage

    # 1. Spinner Nose Cone
    tip = mesh.add_vertex(0.0, 60.0, 0.0)
    n_rad = 12
    spin_base = []
    for i in range(n_rad):
        th = 2.0 * math.pi * i / n_rad
        spin_base.append(mesh.add_vertex(3.0 * math.cos(th), 52.0, 3.0 * math.sin(th)))
    for i in range(n_rad):
        mesh.add_tri(tip, spin_base[i], spin_base[(i + 1) % n_rad], MAT_SPINNER)

    # 2. Fuselage (Angular Daimler-Benz V12)
    fuse_secs = [
        (52.0, 6.0, 6.5, 0.0, MAT_YELLOW_COWL),
        (38.0, 7.0, 8.0, 0.5, MAT_YELLOW_COWL),
        (16.0, 7.2, 8.4, 1.2, MAT_BODY),
        (-6.0, 6.8, 7.8, 1.0, MAT_BODY),
        (-24.0, 5.0, 6.0, 0.6, MAT_BODY),
        (-42.0, 3.5, 4.4, 0.5, MAT_BODY),
        (-56.0, 1.8, 2.8, 0.5, MAT_BODY),
        (-66.0, 0.6, 0.8, 0.5, MAT_BODY)
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

    # 3. Tapered Square-Tipped Wings (Span 80, Chord 24)
    wing_stations = [
        (-6.5, 12.0, 0.0, 18.0, -14.0), (-20.0, 10.0, 1.0, 17.0, -12.0),
        (-36.0, 8.0, 2.2, 15.0, -8.0), (-50.0, 6.0, 3.5, 13.0, -5.0),
        (-62.0, 4.0, 4.8, 10.0, -2.0), (-66.0, 0.5, 5.2, 8.0, 0.0)
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

        # Underwing Radiator Bath
        rad_x = sign * 26.0
        r_box = [
            mesh.add_vertex(rad_x - 3, 4.0, -1.2), mesh.add_vertex(rad_x + 3, 4.0, -1.2),
            mesh.add_vertex(rad_x + 3, -6.0, -3.2), mesh.add_vertex(rad_x - 3, -6.0, -3.2)
        ]
        mesh.add_quad(r_box[0], r_box[1], r_box[2], r_box[3], (25, 30, 25, 255))

    # 4. Angular Canopy
    c_pts = [
        mesh.add_vertex(0.0, 16.0, 8.8), mesh.add_vertex(-3.5, 12.0, 5.8),
        mesh.add_vertex(3.5, 12.0, 5.8), mesh.add_vertex(-3.2, -8.0, 5.4),
        mesh.add_vertex(3.2, -8.0, 5.4), mesh.add_vertex(0.0, -14.0, 6.2)
    ]
    mesh.add_quad(c_pts[1], c_pts[0], c_pts[2], c_pts[2], MAT_CANOPY)
    mesh.add_quad(c_pts[1], c_pts[3], c_pts[4], c_pts[2], MAT_CANOPY)
    mesh.add_tri(c_pts[3], c_pts[5], c_pts[4], MAT_CANOPY)

    # 5. Strut-Braced Tailplane
    for sign in [-1, 1]:
        mesh.add_quad(
            mesh.add_vertex(0.0, -52.0, 3.0), mesh.add_vertex(sign * 20.0, -56.0, 3.5),
            mesh.add_vertex(sign * 18.0, -64.0, 3.5), mesh.add_vertex(0.0, -64.0, 3.0), MAT_TAIL
        )
    mesh.add_tri(
        mesh.add_vertex(0.0, -46.0, 4.0), mesh.add_vertex(0.0, -64.0, 20.0),
        mesh.add_vertex(0.0, -66.0, 4.0), MAT_TAIL
    )

    return mesh
'''

bf109_render_code = '''#!/usr/bin/env python3
import math
from PIL import Image, ImageDraw

def render_3d_bf109_frame(mesh, roll_deg=0.0, pitch_deg=0.0, yaw_deg=0.0, prop_angle=0.0, style="tactical"):
    w, h = 180, 180
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    # Palettes
    C_BODY = (78, 88, 76, 255)
    C_LIGHT = (112, 126, 110, 255)
    C_OUTLINE = (24, 30, 24, 255)
    C_YELLOW = (245, 205, 45, 255)
    C_CANOPY = (140, 220, 255, 230)
    C_WHITE = (245, 245, 250, 255)

    r_rad = math.radians(roll_deg)
    p_rad = math.radians(pitch_deg)
    cos_r, sin_r = math.cos(r_rad), math.sin(r_rad)
    cos_p, sin_p = math.cos(p_rad), math.sin(p_rad)

    transformed = []
    for x, y, z in mesh.vertices:
        yp = y * cos_p - z * sin_p
        zp = y * sin_p + z * cos_p
        xr = x * cos_r + zp * sin_r
        zr = -x * sin_r + zp * cos_r
        sx = cx + xr * 1.15
        sy = cy - yp * 1.15
        transformed.append((sx, sy, zr))

    face_depths = []
    for idx, f in enumerate(mesh.faces):
        v0, v1, v2, mat = f
        avg_z = (transformed[v0][2] + transformed[v1][2] + transformed[v2][2]) / 3.0
        face_depths.append((avg_z, idx, f))
    face_depths.sort(key=lambda x: x[0])

    for _, _, (v0, v1, v2, mat) in face_depths:
        p0 = (transformed[v0][0], transformed[v0][1])
        p1 = (transformed[v1][0], transformed[v1][1])
        p2 = (transformed[v2][0], transformed[v2][1])

        col = C_BODY
        if mat == 2: col = C_YELLOW
        elif mat == 4: col = C_CANOPY
        elif mat == 5: col = (30, 32, 35, 255)

        draw.polygon([p0, p1, p2], fill=col, outline=C_OUTLINE)

    # Balkenkreuz crosses on wings
    for sign in [-1, 1]:
        rx = cx + sign * 36 * cos_r
        ry = cy - 2 * sin_r
        draw.line([(rx - 8, ry), (rx + 8, ry)], fill=C_WHITE, width=3)
        draw.line([(rx, ry - 6), (rx, ry + 6)], fill=C_WHITE, width=3)
        draw.line([(rx - 7, ry), (rx + 7, ry)], fill=(15, 15, 15, 255), width=1)
        draw.line([(rx, ry - 5), (rx, ry + 5)], fill=(15, 15, 15, 255), width=1)

    # 3-Blade Propeller
    nose_x = cx + sin_r * 2
    nose_y = cy - 60 * cos_p
    draw.ellipse([nose_x - 20, nose_y - 5, nose_x + 20, nose_y + 5], fill=(245, 220, 75, 180))

    return img
'''

# -----------------------------------------------------------------------------
# 3. YAKOVLEV YAK-3 3D ENGINE
# -----------------------------------------------------------------------------
yak3_mesh_code = '''#!/usr/bin/env python3
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
'''

yak3_render_code = '''#!/usr/bin/env python3
import math
from PIL import Image, ImageDraw

def render_3d_yak3_frame(mesh, roll_deg=0.0, pitch_deg=0.0, yaw_deg=0.0, prop_angle=0.0, style="tactical"):
    w, h = 180, 180
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    # Palettes
    C_BODY = (108, 118, 126, 255)
    C_LIGHT = (144, 156, 166, 255)
    C_OUTLINE = (24, 28, 32, 255)
    C_RED = (215, 30, 30, 255)
    C_CANOPY = (140, 220, 255, 230)
    C_WHITE = (245, 245, 250, 255)

    r_rad = math.radians(roll_deg)
    p_rad = math.radians(pitch_deg)
    cos_r, sin_r = math.cos(r_rad), math.sin(r_rad)
    cos_p, sin_p = math.cos(p_rad), math.sin(p_rad)

    transformed = []
    for x, y, z in mesh.vertices:
        yp = y * cos_p - z * sin_p
        zp = y * sin_p + z * cos_p
        xr = x * cos_r + zp * sin_r
        zr = -x * sin_r + zp * cos_r
        sx = cx + xr * 1.15
        sy = cy - yp * 1.15
        transformed.append((sx, sy, zr))

    face_depths = []
    for idx, f in enumerate(mesh.faces):
        v0, v1, v2, mat = f
        avg_z = (transformed[v0][2] + transformed[v1][2] + transformed[v2][2]) / 3.0
        face_depths.append((avg_z, idx, f))
    face_depths.sort(key=lambda x: x[0])

    for _, _, (v0, v1, v2, mat) in face_depths:
        p0 = (transformed[v0][0], transformed[v0][1])
        p1 = (transformed[v1][0], transformed[v1][1])
        p2 = (transformed[v2][0], transformed[v2][1])

        col = C_BODY
        if mat in (2, 5): col = C_RED
        elif mat == 4: col = C_CANOPY

        draw.polygon([p0, p1, p2], fill=col, outline=C_OUTLINE)

    # Soviet Red Stars on wings
    for sign in [-1, 1]:
        rx = cx + sign * 34 * cos_r
        ry = cy - 2 * sin_r
        draw.polygon([(rx, ry - 7), (rx + 4, ry + 6), (rx - 4, ry + 6)], fill=C_RED)
        draw.polygon([(rx, ry + 6), (rx + 4, ry - 3), (rx - 4, ry - 3)], fill=C_RED)
        draw.line([(rx, ry - 7), (rx + 4, ry + 6), (rx - 4, ry + 6), (rx, ry - 7)], fill=C_WHITE, width=1)

    # Propeller
    nose_x = cx + sin_r * 2
    nose_y = cy - 58 * cos_p
    draw.ellipse([nose_x - 19, nose_y - 5, nose_x + 19, nose_y + 5], fill=(245, 220, 75, 180))

    return img
'''

# -----------------------------------------------------------------------------
# 4. DE HAVILLAND MOSQUITO FB.VI 3D ENGINE
# -----------------------------------------------------------------------------
mosquito_mesh_code = '''#!/usr/bin/env python3
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
'''

mosquito_render_code = '''#!/usr/bin/env python3
import math
from PIL import Image, ImageDraw

def render_3d_mosquito_frame(mesh, roll_deg=0.0, pitch_deg=0.0, yaw_deg=0.0, prop_angle=0.0, style="tactical"):
    w, h = 180, 180
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    # Palettes (RCAF Canadian Camo)
    C_BODY = (66, 78, 62, 255)
    C_LIGHT = (100, 116, 96, 255)
    C_OUTLINE = (22, 28, 20, 255)
    C_CANOPY = (140, 220, 255, 230)
    C_ROUNDEL_BLUE = (24, 48, 120, 255)
    C_ROUNDEL_WHITE = (245, 245, 250, 255)
    C_MAPLE_RED = (215, 30, 30, 255)

    r_rad = math.radians(roll_deg)
    p_rad = math.radians(pitch_deg)
    cos_r, sin_r = math.cos(r_rad), math.sin(r_rad)
    cos_p, sin_p = math.cos(p_rad), math.sin(p_rad)

    transformed = []
    for x, y, z in mesh.vertices:
        yp = y * cos_p - z * sin_p
        zp = y * sin_p + z * cos_p
        xr = x * cos_r + zp * sin_r
        zr = -x * sin_r + zp * cos_r
        sx = cx + xr * 1.15
        sy = cy - yp * 1.15
        transformed.append((sx, sy, zr))

    face_depths = []
    for idx, f in enumerate(mesh.faces):
        v0, v1, v2, mat = f
        avg_z = (transformed[v0][2] + transformed[v1][2] + transformed[v2][2]) / 3.0
        face_depths.append((avg_z, idx, f))
    face_depths.sort(key=lambda x: x[0])

    for _, _, (v0, v1, v2, mat) in face_depths:
        p0 = (transformed[v0][0], transformed[v0][1])
        p1 = (transformed[v1][0], transformed[v1][1])
        p2 = (transformed[v2][0], transformed[v2][1])

        col = C_BODY
        if mat == 4: col = C_CANOPY
        elif mat == 3: col = (30, 32, 35, 255)

        draw.polygon([p0, p1, p2], fill=col, outline=C_OUTLINE)

    # RCAF Maple Leaf Roundels on outer wings
    for sign in [-1, 1]:
        rx = cx + sign * 48 * cos_r
        ry = cy - 2 * sin_r
        draw.ellipse([rx - 10, ry - 8, rx + 10, ry + 8], fill=C_ROUNDEL_BLUE)
        draw.ellipse([rx - 6, ry - 5, rx + 6, ry + 5], fill=C_ROUNDEL_WHITE)
        # Red Maple Leaf center
        draw.polygon([(rx, ry - 4), (rx + 3, ry + 3), (rx - 3, ry + 3)], fill=C_MAPLE_RED)

    # Twin Spinning Propeller Discs (Rolls-Royce Merlins)
    for sign in [-1, 1]:
        nx = cx + (sign * 28) * cos_r
        ny = cy - 54 * cos_p - (sign * 28) * sin_r
        draw.ellipse([nx - 18, ny - 5, nx + 18, ny + 5], fill=(245, 220, 75, 180))

    return img
'''

def write_engines():
    print("Writing 3D airframe builders...")
    (ENGINE_DIR / "spitfire_3d_engine.py").write_text(spitfire_mesh_code)
    (ENGINE_DIR / "render_3d_spitfire.py").write_text(spitfire_render_code)
    (ENGINE_DIR / "bf109_3d_engine.py").write_text(bf109_mesh_code)
    (ENGINE_DIR / "render_3d_bf109.py").write_text(bf109_render_code)
    (ENGINE_DIR / "yak3_3d_engine.py").write_text(yak3_mesh_code)
    (ENGINE_DIR / "render_3d_yak3.py").write_text(yak3_render_code)
    (ENGINE_DIR / "mosquito_3d_engine.py").write_text(mosquito_mesh_code)
    (ENGINE_DIR / "render_3d_mosquito.py").write_text(mosquito_render_code)
    print("✓ All 4 new player 3D engines and cel-shaders written successfully.")

if __name__ == "__main__":
    write_engines()

import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

OUTPUT_DIR = Path(__file__).resolve().parent / "sprites"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

NUM_FRAMES = 12
CANVAS_W = 140
CANVAS_H = 100
BOLT_H = 240
SCALE = 3

COLORS = {
    "red":    {"main": (220, 28, 45),   "top": (238, 52, 70),   "dark": (135, 15, 28),  "light": (255, 160, 175), "rim": (255, 210, 220), "ambient": (180, 20, 35)},
    "blue":   {"main": (28, 115, 240),  "top": (55, 145, 255),  "dark": (15, 65, 170),  "light": (160, 210, 255), "rim": (215, 235, 255), "ambient": (20, 90, 200)},
    "yellow": {"main": (230, 150, 5),   "top": (250, 175, 25),  "dark": (155, 90, 2),   "light": (255, 225, 140), "rim": (255, 245, 200), "ambient": (195, 120, 4)},
    "green":  {"main": (10, 170, 95),   "top": (25, 195, 115),  "dark": (5, 95, 52),    "light": (140, 240, 190), "rim": (210, 255, 230), "ambient": (8, 135, 75)},
    "purple": {"main": (130, 60, 230),  "top": (155, 90, 250),  "dark": (75, 25, 145),  "light": (215, 175, 255), "rim": (240, 225, 255), "ambient": (105, 45, 190)},
    "cyan":   {"main": (5, 165, 205),   "top": (20, 195, 235),  "dark": (8, 98, 125),   "light": (150, 240, 255), "rim": (215, 250, 255), "ambient": (4, 135, 170)},
    "orange": {"main": (235, 95, 12),   "top": (255, 120, 35),  "dark": (155, 50, 5),   "light": (255, 190, 140), "rim": (255, 230, 205), "ambient": (195, 75, 10)},
    "pink":   {"main": (225, 45, 140),  "top": (245, 75, 165),  "dark": (140, 18, 85),  "light": (255, 170, 220), "rim": (255, 225, 245), "ambient": (185, 32, 112)},
    "black":  {"main": (40, 48, 60),    "top": (58, 68, 82),    "dark": (20, 25, 32),   "light": (120, 135, 155), "rim": (190, 205, 225), "ambient": (30, 36, 46)},
    "lime":   {"main": (118, 190, 15),  "top": (145, 218, 35),  "dark": (65, 110, 8),   "light": (215, 250, 130), "rim": (240, 255, 195), "ambient": (95, 155, 12)},
    "silver": {"main": (185, 198, 212), "top": (222, 230, 240), "dark": (115, 128, 142),"light": (250, 252, 255), "rim": (255, 255, 255), "ambient": (150, 162, 175)}
}

def render_bolt_base():
    w = CANVAS_W * SCALE
    h = BOLT_H * SCALE
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    cx = w / 2
    by = 208 * SCALE
    base_r = 54 * SCALE
    base_h = 16 * SCALE
    tilt = 0.52

    # 1. Soft contact shadow on ground
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    s_draw.ellipse([cx - base_r * 1.12, by - 4, cx + base_r * 1.12, by + base_r * tilt * 1.15], fill=(0, 0, 0, 140))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=7 * SCALE))
    im.paste(shadow, (0, 0), shadow)

    # 2. Pedestal side cylinder
    draw.polygon([
        (cx - base_r, by - base_h),
        (cx + base_r, by - base_h),
        (cx + base_r, by),
        (cx - base_r, by)
    ], fill=(64, 76, 94, 255))
    # Bottom rim
    draw.ellipse([cx - base_r, by - base_r * tilt, cx + base_r, by + base_r * tilt], fill=(45, 55, 72, 255))
    # Top face
    draw.ellipse([cx - base_r, (by - base_h) - base_r * tilt, cx + base_r, (by - base_h) + base_r * tilt],
                 fill=(115, 130, 150, 255), outline=(160, 175, 195, 255), width=int(1.8 * SCALE))

    return im.resize((CANVAS_W, BOLT_H), Image.Resampling.LANCZOS)

def render_bolt_rod():
    w = CANVAS_W * SCALE
    h = BOLT_H * SCALE
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    cx = w / 2
    bolt_w = 30 * SCALE
    rod_top = 72 * SCALE
    base_top = (208 - 16) * SCALE
    tilt = 0.52

    # Rod body
    draw.rectangle([cx - bolt_w / 2, rod_top, cx + bolt_w / 2, base_top], fill=(155, 168, 185, 255))

    # Specular metallic reflection column
    shine_w = bolt_w * 0.38
    draw.rectangle([cx - shine_w * 0.7, rod_top, cx + shine_w * 0.3, base_top], fill=(230, 238, 248, 255))

    # Threads
    step = int(6.5 * SCALE)
    for ty in range(int(rod_top + 4 * SCALE), int(base_top - 2 * SCALE), step):
        # Groove shadow
        draw.line([cx - bolt_w / 2, ty, cx + bolt_w / 2, ty - int(2.5 * SCALE)],
                  fill=(60, 72, 90, 255), width=max(1, int(2.2 * SCALE)))
        # Crest highlight
        draw.line([cx - bolt_w / 2, ty + int(SCALE), cx + bolt_w / 2, ty - int(1.5 * SCALE)],
                  fill=(245, 248, 255, 255), width=max(1, int(1.2 * SCALE)))

    # Flat chamfered open top cap (NO rounded dome!)
    top_r = bolt_w / 2
    draw.ellipse([cx - top_r, rod_top - top_r * tilt, cx + top_r, rod_top + top_r * tilt],
                 fill=(215, 225, 238, 255), outline=(130, 145, 165, 255), width=int(1.5 * SCALE))

    # Top cap specular gleam
    gleam = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(gleam)
    g_draw.ellipse([cx - top_r * 0.5, rod_top - top_r * tilt * 0.6, cx + top_r * 0.2, rod_top + top_r * tilt * 0.2],
                   fill=(255, 255, 255, 200))
    gleam = gleam.filter(ImageFilter.GaussianBlur(radius=2 * SCALE))
    im.paste(gleam, (0, 0), gleam)

    return im.resize((CANVAS_W, BOLT_H), Image.Resampling.LANCZOS)

def render_nut_frame(angle_rad, color_cfg):
    w = CANVAS_W * SCALE
    h = CANVAS_H * SCALE
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    cx = w / 2
    cy = 40 * SCALE
    nut_r = 44 * SCALE
    nut_thick = 26 * SCALE
    bevel_h = 3.5 * SCALE
    bevel_r = nut_r - 3.5 * SCALE
    hole_r = 16.0 * SCALE
    tilt = 0.52

    outer_pts = []
    inner_bevel_pts = []
    for i in range(6):
        a = angle_rad + i * (math.pi / 3)
        ox = cx + math.cos(a) * nut_r
        oy = cy + math.sin(a) * (nut_r * tilt)
        outer_pts.append((ox, oy))

        bx = cx + math.cos(a) * bevel_r
        by = (cy - bevel_h) + math.sin(a) * (bevel_r * tilt)
        inner_bevel_pts.append((bx, by))

    lx, ly, lz = -0.55, -0.65, 0.52
    l_len = math.sqrt(lx*lx + ly*ly + lz*lz)
    lx, ly, lz = lx/l_len, ly/l_len, lz/l_len

    # --- 1. Soft contact shadow cast underneath the nut ---
    cy_bottom = cy + nut_thick
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    bottom_pts = [(p[0], p[1] + nut_thick) for p in outer_pts]
    s_draw.polygon(bottom_pts, fill=(0, 0, 0, 160))
    s_draw.ellipse([cx - nut_r * 0.95, cy_bottom - nut_r * tilt * 0.5,
                    cx + nut_r * 0.95, cy_bottom + nut_r * tilt * 0.95],
                   fill=(0, 0, 0, 140))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=2.5 * SCALE))
    im.paste(shadow, (0, 0), shadow)

    # --- 2. Side Facets (Rich Anodized Metallic Luster) ---
    facets = []
    visible_bottom_edges = []
    creases = []

    for i in range(6):
        p1 = outer_pts[i]
        p2 = outer_pts[(i + 1) % 6]
        a_mid = angle_rad + (i + 0.5) * (math.pi / 3)
        nx = math.cos(a_mid)
        ny = math.sin(a_mid)

        if ny > -0.15:
            poly = [p1, p2, (p2[0], p2[1] + nut_thick), (p1[0], p1[1] + nut_thick)]
            dot = nx * lx + ny * (-ly)

            # Anisotropic specular highlight down the illuminated face
            vx, vy = 0.0, -0.48
            hx = lx + vx
            hy = (-ly) + vy
            h_len = math.sqrt(hx*hx + hy*hy)
            hx, hy = hx/h_len, hy/h_len
            spec_dot = max(0.0, nx * hx + ny * hy)
            specular = math.pow(spec_dot, 7.0) * 0.40

            brightness = max(0.40, min(1.35, 0.70 + dot * 0.48 + specular))
            base = color_cfg["main"]
            facet_col = tuple(min(255, int(c * brightness)) for c in base)

            facets.append((ny, poly, facet_col))
            visible_bottom_edges.append(((p1[0], p1[1] + nut_thick), (p2[0], p2[1] + nut_thick)))
            creases.append((p1, (p1[0], p1[1] + nut_thick)))

    facets.sort(key=lambda x: x[0])
    for _, poly, f_col in facets:
        draw.polygon(poly, fill=f_col + (255,))

    # Vertical facet creases (machined precision corner)
    for p_top, p_bot in creases:
        draw.line([p_top, p_bot], fill=(15, 20, 30, 170), width=max(1, int(1.2 * SCALE)))
        draw.line([(p_top[0] - 0.6 * SCALE, p_top[1]), (p_bot[0] - 0.6 * SCALE, p_bot[1])],
                  fill=color_cfg["rim"] + (110,), width=max(1, int(0.8 * SCALE)))

    # Bottom seam
    for b1, b2 in visible_bottom_edges:
        draw.line([b1, b2], fill=(12, 16, 24, 240), width=max(1, int(1.8 * SCALE)))

    # --- 3. Beveled Top Chamfer (Machined Anodized Diamond Chamfer) ---
    for i in range(6):
        p1 = outer_pts[i]
        p2 = outer_pts[(i + 1) % 6]
        b1 = inner_bevel_pts[i]
        b2 = inner_bevel_pts[(i + 1) % 6]
        a_mid = angle_rad + (i + 0.5) * (math.pi / 3)
        nx = math.cos(a_mid)
        ny = math.sin(a_mid)
        dot = nx * lx + ny * (-ly) + 0.60 * lz
        brightness = max(0.58, min(1.38, 0.82 + dot * 0.52))
        base = color_cfg["top"]
        bev_col = tuple(min(255, int(c * brightness)) for c in base)
        draw.polygon([p1, p2, b2, b1], fill=bev_col + (255,))

    # Diamond-cut outer chamfer rim highlight
    for i in range(6):
        p1 = outer_pts[i]
        p2 = outer_pts[(i + 1) % 6]
        a_mid = angle_rad + (i + 0.5) * (math.pi / 3)
        if math.sin(a_mid) > 0:
            draw.line([p1, p2], fill=color_cfg["rim"] + (230,), width=max(1, int(1.2 * SCALE)))

    # Inner bevel crease (metallic light catch)
    for i in range(6):
        b1 = inner_bevel_pts[i]
        b2 = inner_bevel_pts[(i + 1) % 6]
        draw.line([b1, b2], fill=color_cfg["light"] + (180,), width=max(1, int(1.0 * SCALE)))

    # --- 4. Top Hex Face with Anodized Brushed Luster ---
    top_mask = Image.new("L", (w, h), 0)
    m_draw = ImageDraw.Draw(top_mask)
    m_draw.polygon(inner_bevel_pts, fill=255)

    top_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    t_draw = ImageDraw.Draw(top_layer)
    t_draw.polygon(inner_bevel_pts, fill=color_cfg["top"] + (255,))

    # Smooth diagonal metallic sheen streak
    sheen = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(sheen)
    s_cy = cy - bevel_h
    for offset in range(-18, 19):
        dist = abs(offset) / 18.0
        alpha = int(70 * math.exp(-dist * dist * 3.0))
        if alpha > 2:
            x1 = cx - 45 * SCALE + offset * 1.5 * SCALE
            y1 = s_cy - 25 * SCALE
            x2 = cx - 15 * SCALE + offset * 1.5 * SCALE
            y2 = s_cy + 25 * SCALE
            s_draw.line([(x1, y1), (x2, y2)], fill=color_cfg["rim"] + (alpha,), width=int(2.0 * SCALE))

    sheen = sheen.filter(ImageFilter.GaussianBlur(radius=1.8 * SCALE))
    top_layer.paste(sheen, (0, 0), sheen)
    top_layer.putalpha(top_mask)
    im.paste(top_layer, (0, 0), top_layer)

    # Crisp perimeter line around the top face
    draw.polygon(inner_bevel_pts, outline=color_cfg["light"] + (200,), width=max(1, int(1.1 * SCALE)))

    # --- 5. Inner Hole Chamfer & Crisp Machined Outline ---
    hole_cy = cy - bevel_h
    hole_bbox = [cx - hole_r, hole_cy - hole_r * tilt, cx + hole_r, hole_cy + hole_r * tilt]

    # Metallic chamfer around hole
    chamfer_r = hole_r + 1.5 * SCALE
    chamfer_bbox = [cx - chamfer_r, hole_cy - chamfer_r * tilt, cx + chamfer_r, hole_cy + chamfer_r * tilt]
    draw.arc(chamfer_bbox, start=180, end=360, fill=color_cfg["rim"] + (230,), width=max(1, int(1.4 * SCALE)))
    draw.arc(chamfer_bbox, start=0, end=180, fill=color_cfg["dark"] + (220,), width=max(1, int(1.4 * SCALE)))

    # Crisp dark machined seam right at hole edge in nut color
    dark_seam = tuple(max(10, int(c * 0.35)) for c in color_cfg["dark"])
    draw.ellipse(hole_bbox, outline=dark_seam + (255,), width=max(1, int(1.6 * SCALE)))

    # --- 6. Fully Anodized Threaded Bore (Matching Nut Color) ---
    bore = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(bore)

    # Anodized interior wall in dark saturated nut color
    bore_wall = tuple(int(c * 0.78) for c in color_cfg["dark"])
    b_draw.ellipse(hole_bbox, fill=bore_wall + (255,))

    # Anodized thread colors: groove is deep shaded tone, crest is vibrant metallic catch
    thread_groove = tuple(int(c * 0.42) for c in color_cfg["dark"])
    thread_crest = tuple(min(255, int(c * 0.75 + r * 0.25)) for c, r in zip(color_cfg["light"], color_cfg["rim"]))

    threads = [
        {"y_off": -0.48, "r_scale": 0.96, "w_crest": 1.4, "w_groove": 2.0},
        {"y_off": -0.22, "r_scale": 0.90, "w_crest": 1.3, "w_groove": 1.8},
        {"y_off":  0.04, "r_scale": 0.84, "w_crest": 1.2, "w_groove": 1.6},
        {"y_off":  0.30, "r_scale": 0.78, "w_crest": 1.1, "w_groove": 1.4},
    ]
    for t in threads:
        r = hole_r * t["r_scale"]
        ty = hole_cy + (hole_r * tilt) * t["y_off"]
        t_box = [cx - r, ty - r * tilt * 0.70, cx + r, ty + r * tilt * 0.70]
        # Dark thread groove in anodized color shadow
        b_draw.arc(t_box, start=180, end=360, fill=thread_groove + (255,), width=int(t["w_groove"] * SCALE))
        # Bright thread crest in metallic anodized reflection
        t_crest_box = [cx - r, ty - r * tilt * 0.70 - 1.0 * SCALE, cx + r, ty + r * tilt * 0.70 - 1.0 * SCALE]
        b_draw.arc(t_crest_box, start=185, end=355, fill=thread_crest + (255,), width=int(t["w_crest"] * SCALE))

    b_mask = Image.new("L", (w, h), 0)
    bm_draw = ImageDraw.Draw(b_mask)
    bm_draw.ellipse(hole_bbox, fill=255)
    bore.putalpha(b_mask)
    im.paste(bore, (0, 0), bore)

    final_im = im.resize((CANVAS_W, CANVAS_H), Image.Resampling.LANCZOS)
    return final_im

def split_nut_back_front(full_im, color_cfg):
    split_y = int(40 - 3.5) # cy - bevel_h in 140x100 canvas

    back_im = full_im.copy()
    b_draw = ImageDraw.Draw(back_im)
    b_draw.rectangle([0, split_y, CANVAS_W, CANVAS_H], fill=(0, 0, 0, 0))

    front_im = full_im.copy()
    f_draw = ImageDraw.Draw(front_im)
    f_draw.rectangle([0, 0, CANVAS_W, split_y - 1], fill=(0, 0, 0, 0))

    # Clear inner hole completely from front_im so bolt shaft shows through cleanly
    hole_cx = CANVAS_W / 2
    hole_cy = 40 - 3.5
    hole_r = 16.0
    tilt = 0.52
    hole_box = [hole_cx - hole_r, hole_cy - hole_r * tilt,
                hole_cx + hole_r, hole_cy + hole_r * tilt]
    f_draw.ellipse(hole_box, fill=(0, 0, 0, 0))

    # Crisp dark machined seam right at hole edge on front_im
    dark_seam = tuple(max(10, int(c * 0.35)) for c in color_cfg["dark"])
    f_draw.arc(hole_box, start=0, end=180, fill=dark_seam + (255,), width=1)
    # Subtle front chamfer line right outside hole edge
    chamfer_box = [hole_cx - (hole_r + 0.8), hole_cy - (hole_r + 0.8) * tilt,
                   hole_cx + (hole_r + 0.8), hole_cy + (hole_r + 0.8) * tilt]
    f_draw.arc(chamfer_box, start=0, end=180, fill=color_cfg["dark"] + (210,), width=1)

    return back_im, front_im

print("Rendering 3D bolt base and rod sprites...")
base_img = render_bolt_base()
base_img.save(OUTPUT_DIR / "bolt_base.png")

rod_img = render_bolt_rod()
rod_img.save(OUTPUT_DIR / "bolt_rod.png")

# Combined bolt for fallback/preview
combined_bolt = Image.new("RGBA", (CANVAS_W, BOLT_H), (0, 0, 0, 0))
combined_bolt.paste(base_img, (0, 0), base_img)
combined_bolt.paste(rod_img, (0, 0), rod_img)
combined_bolt.save(OUTPUT_DIR / "bolt.png")
print("Saved bolt_base.png, bolt_rod.png, bolt.png")

print(f"Rendering {NUM_FRAMES} rotation frames and back/front splits for each color...")
for color_id, cfg in COLORS.items():
    for f in range(NUM_FRAMES):
        ang = f * (math.pi / 3 / NUM_FRAMES)
        frame_img = render_nut_frame(ang, cfg)
        frame_img.save(OUTPUT_DIR / f"nut_{color_id}_{f}.png")
        back_im, front_im = split_nut_back_front(frame_img, cfg)
        frame_img.save(OUTPUT_DIR / f"nut_{color_id}_{f}.png")
        back_im.save(OUTPUT_DIR / f"nut_back_{color_id}_{f}.png")
        front_im.save(OUTPUT_DIR / f"nut_front_{color_id}_{f}.png")
        if f == 0:
            back_im.save(OUTPUT_DIR / f"nut_back_{color_id}.png")
            front_im.save(OUTPUT_DIR / f"nut_front_{color_id}.png")
    print(f"  Rendered {color_id} ({NUM_FRAMES} frames + back/front splits)")

print("All 3D hardware sprites generated successfully!")

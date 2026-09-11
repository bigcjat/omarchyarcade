#!/usr/bin/env python3
"""
Generates demos of different cartooning and stylization techniques for satellite terrain images.
Creates side-by-side comparison images and an interactive HTML viewer.
"""

import cv2
import numpy as np
from pathlib import Path
from PIL import Image, ImageEnhance, ImageOps

def load_crop(img_path, crop_box=(100, 300, 680, 880)):
    im = Image.open(img_path).convert("RGB")
    crop = im.crop(crop_box)
    return np.array(crop)

def style_original(img):
    return img.copy()

def style_a_meanshift_anime(img):
    """Style A: Mean-Shift Segmentation (Anime / Ghibli Background style)"""
    # Flattens micro-details into discrete painted color zones while keeping edges sharp
    shifted = cv2.pyrMeanShiftFiltering(img, sp=15, sr=25)
    # Enhance contrast and saturation
    pil_img = Image.fromarray(shifted)
    enh_c = ImageEnhance.Contrast(pil_img).enhance(1.25)
    enh_s = ImageEnhance.Color(enh_c).enhance(1.30)
    return np.array(enh_s)

def style_b_bilateral_smooth(img):
    """Style B: Surface Smoothing (Bilateral Edge-Preserving Filter)"""
    # Smooths flat textures (eliminates noise/micro-bushes) without blurring edges
    filtered = cv2.bilateralFilter(img, d=9, sigmaColor=75, sigmaSpace=75)
    filtered = cv2.bilateralFilter(filtered, d=7, sigmaColor=50, sigmaSpace=50)
    pil_img = Image.fromarray(filtered)
    enh_c = ImageEnhance.Contrast(pil_img).enhance(1.20)
    enh_s = ImageEnhance.Color(enh_c).enhance(1.25)
    return np.array(enh_s)

def style_c_arcade_posterize(img):
    """Style C: Arcade Posterization (16-bit Tonal Stepping)"""
    # Bilateral smoothing first to clean noise
    smooth = cv2.bilateralFilter(img, d=9, sigmaColor=60, sigmaSpace=60)
    # Quantize / posterize to discrete color levels
    pil_img = Image.fromarray(smooth)
    post = ImageOps.posterize(pil_img, 4) # 4 bits per channel = 16 levels
    enh_c = ImageEnhance.Contrast(post).enhance(1.20)
    enh_s = ImageEnhance.Color(enh_c).enhance(1.35)
    return np.array(enh_s)

def style_d_cartoon_linework(img):
    """Style D: Cartoon with Subtle Inked Edges"""
    # 1. Edge-preserving color smoothing
    smooth = cv2.bilateralFilter(img, d=9, sigmaColor=80, sigmaSpace=80)
    # 2. Extract edge lines using adaptive threshold
    gray = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)
    gray = cv2.medianBlur(gray, 5)
    edges = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 9, 3)
    edges_rgb = cv2.cvtColor(edges, cv2.COLOR_GRAY2RGB)
    # 3. Multiply edges gently onto smooth color
    edge_weight = 0.85
    result = cv2.bitwise_and(smooth, edges_rgb)
    blended = cv2.addWeighted(smooth, 0.35, result, 0.65, 0)
    pil_img = Image.fromarray(blended)
    enh_c = ImageEnhance.Contrast(pil_img).enhance(1.20)
    enh_s = ImageEnhance.Color(enh_c).enhance(1.25)
    return np.array(enh_s)

def style_e_opencv_stylize(img):
    """Style E: Computational Photography Stylization"""
    # OpenCV's built-in non-photorealistic rendering stylization
    stylized = cv2.stylization(img, sigma_s=40, sigma_r=0.45)
    pil_img = Image.fromarray(stylized)
    enh_c = ImageEnhance.Contrast(pil_img).enhance(1.15)
    enh_s = ImageEnhance.Color(enh_c).enhance(1.20)
    return np.array(enh_s)

def style_f_vibrant_contrast(img):
    """Style F: Vibrant Arcade Color Grade (No Blur, Contrast + Saturation Boost)"""
    # Keeps structure 100% sharp, but crushes photo haze into rich arcade primaries
    pil_img = Image.fromarray(img)
    enh_c = ImageEnhance.Contrast(pil_img).enhance(1.40)
    enh_s = ImageEnhance.Color(enh_c).enhance(1.45)
    enh_b = ImageEnhance.Brightness(enh_s).enhance(0.95)
    return np.array(enh_b)

def main():
    out_dir = Path("tools/satellite_demos")
    out_dir.mkdir(parents=True, exist_ok=True)
    
    # Use Japan and Europe real satellite terrains
    sources = [
        ("japan", "games/skyace/sprites/terrain_imperial.png"),
        ("europe", "games/skyace/sprites/terrain_european.png")
    ]
    
    styles = [
        ("0_original", "Original Raw Satellite Photo", style_original, "High-resolution unprocessed satellite imagery."),
        ("1_meanshift_anime", "Style A: Anime Cel-Shade (Mean-Shift)", style_a_meanshift_anime, "Segments flat fields into painted color blocks while keeping natural boundaries sharp. Studio Ghibli background feel."),
        ("2_bilateral_smooth", "Style B: Surface Smoothing (Bilateral)", style_b_bilateral_smooth, "Removes micro-shrubs, roof grain, and pixel noise without blurring borders. Clean, polished look."),
        ("3_arcade_posterize", "Style C: Arcade Posterization", style_c_arcade_posterize, "Groups shades into discrete steps with boosted saturation. Classic 16-bit / 32-bit arcade aesthetic."),
        ("4_cartoon_linework", "Style D: Cartoon Inked Contours", style_d_cartoon_linework, "Adds subtle, clean dark outlines along field boundaries and rivers combined with smoothed colors."),
        ("5_opencv_stylize", "Style E: Painterly Watercolor", style_e_opencv_stylize, "Gentle brushwork watercolor effect that softens photo realism into illustrated game art."),
        ("6_vibrant_contrast", "Style F: Vibrant Contrast Grade", style_f_vibrant_contrast, "Zero blur: sharp boundaries, but boosts contrast (+40%) and saturation (+45%) to eliminate photo haze.")
    ]
    
    demo_manifest = []
    
    for country, path in sources:
        print(f"\n[DemoGen] Processing {country.upper()} terrain ({path})...")
        base_crop = load_crop(path, crop_box=(80, 250, 680, 850)) # 600x600 crop
        
        country_demos = []
        for s_id, title, func, desc in styles:
            res = func(base_crop)
            out_name = f"{country}_{s_id}.jpg"
            out_path = out_dir / out_name
            Image.fromarray(res).save(out_path, quality=92)
            print(f"  -> Generated {out_name}")
            country_demos.append({
                "id": s_id, "title": title, "file": out_name, "desc": desc
            })
            
        demo_manifest.append({"country": country, "demos": country_demos})

    # Also build a side-by-side montage sheet for quick visual inspection
    for country, cmeta in zip(["japan", "europe"], demo_manifest):
        cols = 3
        rows = 2
        thumb_w, thumb_h = 360, 360
        montage = Image.new("RGB", (cols * thumb_w, rows * thumb_h + 80), (20, 24, 32))
        
        # Add the 6 stylized versions
        for idx, item in enumerate(cmeta["demos"][1:]): # skip raw original for 2x3 grid of the 6 styles
            c_idx = idx % cols
            r_idx = idx // cols
            im_p = out_dir / item["file"]
            im = Image.open(im_p).resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
            montage.paste(im, (c_idx * thumb_w, r_idx * thumb_h))
            
        montage_path = out_dir / f"montage_{country}.jpg"
        montage.save(montage_path, quality=90)
        print(f"[DemoGen] Created montage: {montage_path}")

    # Build an interactive HTML preview page
    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Sky Ace • Satellite Terrain Cartoon Stylization Demos</title>
    <style>
        body {{
            background: #0d1117;
            color: #e6edf3;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            margin: 0;
            padding: 24px;
        }}
        h1 {{
            color: #f0883e;
            margin-bottom: 8px;
            font-size: 28px;
        }}
        p.subtitle {{
            color: #8b949e;
            margin-top: 0;
            margin-bottom: 24px;
            font-size: 15px;
        }}
        .country-section {{
            margin-bottom: 48px;
            background: #161b22;
            padding: 24px;
            border-radius: 12px;
            border: 1px solid #30363d;
        }}
        h2 {{
            color: #58a6ff;
            border-bottom: 1px solid #30363d;
            padding-bottom: 10px;
            margin-top: 0;
        }}
        .grid {{
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(360px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }}
        .card {{
            background: #0d1117;
            border: 1px solid #30363d;
            border-radius: 8px;
            overflow: hidden;
            display: flex;
            flex-direction: column;
        }}
        .card.highlight {{
            border-color: #f0883e;
            box-shadow: 0 0 12px rgba(240, 136, 62, 0.25);
        }}
        .card img {{
            width: 100%;
            height: 360px;
            object-fit: cover;
            display: block;
        }}
        .card-body {{
            padding: 16px;
            flex: 1;
        }}
        .card-title {{
            font-size: 17px;
            font-weight: 600;
            margin: 0 0 8px 0;
            color: #f0f6fc;
        }}
        .card-desc {{
            font-size: 13px;
            color: #8b949e;
            line-height: 1.5;
            margin: 0;
        }}
        .badge {{
            display: inline-block;
            padding: 3px 8px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: bold;
            margin-bottom: 8px;
            background: #238636;
            color: #fff;
        }}
    </style>
</head>
<body>
    <h1>Sky Ace • Satellite Terrain Cartoon Stylization Demos</h1>
    <p class="subtitle">Exploring techniques to simplify micro-photographic details, increase contrast, and give real satellite imagery an authentic arcade / cel-shaded video game aesthetic without heavy blur.</p>

    <!-- JAPAN SECTION -->
    <div class="country-section">
        <h2>🇯🇵 Japanese Farmland & Mountain Valleys (Imperial Theater)</h2>
        <div class="grid">
"""
    for item in demo_manifest[0]["demos"]:
        is_orig = "0_original" in item["id"]
        hl = "highlight" if "meanshift" in item["id"] or "bilateral" in item["id"] else ""
        badge = "<span class='badge' style='background:#f0883e;'>RECOMMENDED FOR ARCADE</span>" if ("meanshift" in item["id"] or "bilateral" in item["id"]) else ("<span class='badge' style='background:#6e7681;'>BASE PHOTO</span>" if is_orig else "")
        html_content += f"""
            <div class="card {hl}">
                <img src="{item['file']}" alt="{item['title']}">
                <div class="card-body">
                    {badge}
                    <h3 class="card-title">{item['title']}</h3>
                    <p class="card-desc">{item['desc']}</p>
                </div>
            </div>
        """

    html_content += """
        </div>
    </div>

    <!-- EUROPE SECTION -->
    <div class="country-section">
        <h2>🇪🇺 European / Normandy Countryside (Luftwaffe & Western Front)</h2>
        <div class="grid">
    """

    for item in demo_manifest[1]["demos"]:
        is_orig = "0_original" in item["id"]
        hl = "highlight" if "meanshift" in item["id"] or "bilateral" in item["id"] else ""
        badge = "<span class='badge' style='background:#f0883e;'>RECOMMENDED FOR ARCADE</span>" if ("meanshift" in item["id"] or "bilateral" in item["id"]) else ("<span class='badge' style='background:#6e7681;'>BASE PHOTO</span>" if is_orig else "")
        html_content += f"""
            <div class="card {hl}">
                <img src="{item['file']}" alt="{item['title']}">
                <div class="card-body">
                    {badge}
                    <h3 class="card-title">{item['title']}</h3>
                    <p class="card-desc">{item['desc']}</p>
                </div>
            </div>
        """

    html_content += """
        </div>
    </div>
</body>
</html>
"""
    html_path = out_dir / "index.html"
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html_content)
    print(f"\n✓ Saved interactive HTML demo gallery: {html_path}")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Omarchy Arcade • Standard Floppy Disk Renderer
Renders pixel-perfect, 1024x1024 and 256x256 3.5" floppy diskette cover art
directly from launcher/FloppyCard.qml and catalog.json.

Usage:
    python tools/render_disk.py <game_id>
    python tools/render_disk.py --all
"""

import os
import sys
import json
import argparse
from pathlib import Path
from PIL import Image

# Ensure project root is in working directory
PROJECT_ROOT = Path(__file__).resolve().parent.parent
os.chdir(PROJECT_ROOT)

def render_floppy(game_id: str, catalog: dict):
    from PySide6.QtGui import QGuiApplication, QImage, QPainter
    from PySide6.QtQuick import QQuickView
    from PySide6.QtCore import QUrl, QTimer, Qt, QRect

    game_data = next((g for g in catalog.get("games", []) if g["id"] == game_id), None)
    if not game_data:
        print(f"Error: Game '{game_id}' not found in catalog.json", file=sys.stderr)
        return False

    print(f"Rendering floppy disk for {game_data.get('title', game_id)} ({game_id})...")

    # Temporary QML wrapper
    temp_qml = PROJECT_ROOT / f".temp_render_{game_id}.qml"
    qml_content = """import QtQuick
import "launcher"

FloppyCard {
    id: card
    gameData: null
}
"""
    temp_qml.write_text(qml_content, encoding="utf-8")

    app = QGuiApplication.instance() or QGuiApplication(sys.argv[:1])

    view = QQuickView()
    view.setColor(Qt.transparent)
    view.setSource(QUrl.fromLocalFile(str(temp_qml)))

    root = view.rootObject()
    if not root:
        print(f"Error: Failed to load FloppyCard.qml", file=sys.stderr)
        temp_qml.unlink(missing_ok=True)
        return False

    root.setProperty("gameData", game_data)
    view.resize(220, 286)
    view.show()

    success = [False]

    def on_grab(res):
        try:
            raw_img = res.image()
            # Render onto 1024x1024 transparent square canvas
            canvas = QImage(1024, 1024, QImage.Format_ARGB32_Premultiplied)
            canvas.fill(Qt.transparent)

            painter = QPainter(canvas)
            painter.setRenderHint(QPainter.SmoothPixmapTransform)

            target_h = 972
            target_w = int(raw_img.width() * (target_h / raw_img.height()))
            x = (1024 - target_w) // 2
            y = (1024 - target_h) // 2
            painter.drawImage(QRect(x, y, target_w, target_h), raw_img)
            painter.end()

            # Save temporary raw 1024x1024
            temp_raw = PROJECT_ROOT / f".temp_raw_{game_id}.png"
            canvas.save(str(temp_raw), "PNG")

            # Process with PIL for palette quantization (featherweight file size)
            pil_img = Image.open(temp_raw).convert("RGBA")
            temp_raw.unlink(missing_ok=True)

            # 1. 1024x1024 cover disk
            out_disk = PROJECT_ROOT / "assets" / "covers" / f"{game_id}_disk.png"
            out_disk.parent.mkdir(parents=True, exist_ok=True)
            disk_quant = pil_img.quantize(colors=256, method=Image.Quantize.FASTOCTREE)
            disk_quant.save(str(out_disk), "PNG", optimize=True)
            print(f"  -> Saved {out_disk.relative_to(PROJECT_ROOT)} ({out_disk.stat().st_size / 1024:.1f} KB)")

            # 2. 256x256 in-game disk app icon
            game_folder = PROJECT_ROOT / game_data.get("folder", f"games/{game_id}")
            out_icon = game_folder / "assets" / "disk_icon.png"
            out_icon.parent.mkdir(parents=True, exist_ok=True)
            icon_256 = pil_img.resize((256, 256), Image.Resampling.LANCZOS)
            icon_quant = icon_256.quantize(colors=256, method=Image.Quantize.FASTOCTREE)
            icon_quant.save(str(out_icon), "PNG", optimize=True)
            print(f"  -> Saved {out_icon.relative_to(PROJECT_ROOT)} ({out_icon.stat().st_size / 1024:.1f} KB)")

            success[0] = True
        except Exception as e:
            print(f"Error saving floppy renders: {e}", file=sys.stderr)
        finally:
            temp_qml.unlink(missing_ok=True)
            view.close()
            app.quit()

    def do_grab():
        grab_res = root.grabToImage()
        if grab_res:
            grab_res.ready.connect(lambda: on_grab(grab_res))
        else:
            print("Error: grabToImage returned null", file=sys.stderr)
            temp_qml.unlink(missing_ok=True)
            view.close()
            app.quit()

    QTimer.singleShot(600, do_grab)
    app.exec()

    temp_qml.unlink(missing_ok=True)
    return success[0]

def main():
    parser = argparse.ArgumentParser(description="Render official 3.5\" floppy disk cover art and app icons.")
    parser.add_argument("game_id", nargs="?", help="ID of the game to render (e.g. bytecity)")
    parser.add_argument("--all", action="store_true", help="Render floppy disks for all games in catalog.json")
    args = parser.parse_args()

    catalog_path = PROJECT_ROOT / "catalog.json"
    if not catalog_path.exists():
        print("Error: catalog.json not found", file=sys.stderr)
        sys.exit(1)

    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))

    if args.all:
        for game in catalog.get("games", []):
            gid = game["id"]
            render_floppy(gid, catalog)
    elif args.game_id:
        if not render_floppy(args.game_id, catalog):
            sys.exit(1)
    else:
        parser.print_help()
        sys.exit(1)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Omarchy Arcade • Standard Floppy Disk App Icon Renderer

The launcher renders floppy disks dynamically in QML from catalog.json.
This tool renders ONLY the single 256x256 app icon (games/<game_id>/assets/disk_icon.png)
used for the standalone game window icon (app.setWindowIcon).

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

PROJECT_ROOT = Path(__file__).resolve().parent.parent
os.chdir(PROJECT_ROOT)

def render_disk_icon(game_id: str, catalog: dict):
    from PySide6.QtGui import QGuiApplication, QImage, QPainter
    from PySide6.QtQuick import QQuickView
    from PySide6.QtCore import QUrl, QTimer, Qt, QRect

    game_data = next((g for g in catalog.get("games", []) if g["id"] == game_id), None)
    if not game_data:
        print(f"Error: Game '{game_id}' not found in catalog.json", file=sys.stderr)
        return False

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
            # Render onto 256x256 transparent square canvas
            canvas = QImage(256, 256, QImage.Format_ARGB32_Premultiplied)
            canvas.fill(Qt.transparent)

            painter = QPainter(canvas)
            painter.setRenderHint(QPainter.SmoothPixmapTransform)

            target_h = 243
            target_w = int(raw_img.width() * (target_h / raw_img.height()))
            x = (256 - target_w) // 2
            y = (256 - target_h) // 2
            painter.drawImage(QRect(x, y, target_w, target_h), raw_img)
            painter.end()

            temp_raw = PROJECT_ROOT / f".temp_raw_{game_id}.png"
            canvas.save(str(temp_raw), "PNG")

            # Quantize to 256 colors for featherweight ~14 KB size
            pil_img = Image.open(temp_raw).convert("RGBA")
            temp_raw.unlink(missing_ok=True)

            game_folder = PROJECT_ROOT / game_data.get("folder", f"games/{game_id}")
            out_icon = game_folder / "assets" / "disk_icon.png"
            out_icon.parent.mkdir(parents=True, exist_ok=True)
            icon_quant = pil_img.quantize(colors=256, method=Image.Quantize.FASTOCTREE)
            icon_quant.save(str(out_icon), "PNG", optimize=True)
            print(f"  -> Saved {out_icon.relative_to(PROJECT_ROOT)} ({out_icon.stat().st_size / 1024:.1f} KB)")

            success[0] = True
        except Exception as e:
            print(f"Error saving disk icon: {e}", file=sys.stderr)
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
    parser = argparse.ArgumentParser(description="Render the 256x256 3.5\" floppy disk app icon.")
    parser.add_argument("game_id", nargs="?", help="ID of the game to render (e.g. bytecity)")
    parser.add_argument("--all", action="store_true", help="Render disk icons for all games in catalog.json")
    args = parser.parse_args()

    catalog_path = PROJECT_ROOT / "catalog.json"
    if not catalog_path.exists():
        print("Error: catalog.json not found", file=sys.stderr)
        sys.exit(1)

    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))

    if args.all:
        for game in catalog.get("games", []):
            gid = game["id"]
            render_disk_icon(gid, catalog)
    elif args.game_id:
        if not render_disk_icon(args.game_id, catalog):
            sys.exit(1)
    else:
        parser.print_help()
        sys.exit(1)

if __name__ == "__main__":
    main()

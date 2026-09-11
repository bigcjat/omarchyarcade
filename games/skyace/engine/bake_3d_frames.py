import os
import sys
import time
from pathlib import Path

current_dir = Path("/Users/christhompson/arcade/games/skyace")
sys.path.insert(0, str(current_dir))
sys.path.insert(0, str(current_dir / "engine"))

from PIL import Image
import numpy as np

from p38_3d_engine import build_p38_mesh
from render_3d_p38 import render_3d_frame
from zero_3d_engine import build_zero_mesh
from render_3d_zero import render_3d_zero_frame
from spitfire_3d_engine import build_spitfire_mesh
from render_3d_spitfire import render_3d_spitfire_frame
from bf109_3d_engine import build_bf109_mesh
from render_3d_bf109 import render_3d_bf109_frame
from yak3_3d_engine import build_yak3_mesh
from render_3d_yak3 import render_3d_yak3_frame
from mosquito_3d_engine import build_mosquito_mesh
from render_3d_mosquito import render_3d_mosquito_frame
from folgore_3d_engine import build_folgore_mesh
from render_3d_folgore import render_3d_folgore_frame
from d520_3d_engine import build_d520_mesh
from render_3d_d520 import render_3d_d520_frame
from pzl11_3d_engine import build_pzl11_mesh
from render_3d_pzl11 import render_3d_pzl11_frame
from avia_3d_engine import build_avia_mesh
from render_3d_avia import render_3d_avia_frame

planes_config = {
    "p38": (build_p38_mesh(), render_3d_frame),
    "zero": (build_zero_mesh(), render_3d_zero_frame),
    "spitfire": (build_spitfire_mesh(), render_3d_spitfire_frame),
    "bf109": (build_bf109_mesh(), render_3d_bf109_frame),
    "yak3": (build_yak3_mesh(), render_3d_yak3_frame),
    "mosquito": (build_mosquito_mesh(), render_3d_mosquito_frame),
    "folgore": (build_folgore_mesh(), render_3d_folgore_frame),
    "d520": (build_d520_mesh(), render_3d_d520_frame),
    "pzl11": (build_pzl11_mesh(), render_3d_pzl11_frame),
    "avia": (build_avia_mesh(), render_3d_avia_frame),
}

loop_stages = [
    (0.0, 0.0, 0.0),
    (0.0, 45.0, 0.0),
    (0.0, 90.0, 0.0),
    (180.0, 135.0, 0.0),
    (180.0, 180.0, 0.0),
    (180.0, 225.0, 0.0),
    (0.0, 270.0, 0.0),
    (0.0, 315.0, 0.0),
]

output_base = current_dir / "sprites" / "rendered_3d"
output_base.mkdir(parents=True, exist_ok=True)

def bake_all_planes(verbose=True):
    start_time = time.time()
    if verbose:
        print(f"[Bake 3D] Baking 3D tactical frames to {output_base}...")

    total_frames = 0
    for plane, (mesh, render_fn) in planes_config.items():
        p_dir = output_base / plane
        p_dir.mkdir(parents=True, exist_ok=True)
        style = "tactical"
        
        # 1. Level flight frames (4 frames)
        for p_idx, p_ang in enumerate([0.0, 40.0, 80.0, 120.0]):
            img = render_fn(mesh, roll_deg=0.0, pitch_deg=0.0, prop_angle=p_ang, style=style)
            img.save(p_dir / f"level_{p_idx}.png", optimize=True)
            total_frames += 1

        # 2. Banking frames (12 frames)
        for roll in [-28, -14, 14, 28]:
            tag = "left" if roll < 0 else "right"
            hard = "hard_" if abs(roll) > 20 else ""
            for p_idx, p_ang in enumerate([0.0, 40.0, 80.0]):
                name = f"bank_{hard}{tag}_{p_idx}"
                img = render_fn(mesh, roll_deg=float(roll), pitch_deg=0.0, 
                                yaw_deg=float(roll)*0.2, prop_angle=p_ang, style=style)
                img.save(p_dir / f"{name}.png", optimize=True)
                total_frames += 1

        # 3. 360 Loop stages (24 frames)
        for st_idx, (r, p, y) in enumerate(loop_stages):
            for p_idx, p_ang in enumerate([0.0, 40.0, 80.0]):
                img = render_fn(mesh, roll_deg=r, pitch_deg=p, yaw_deg=y, prop_angle=p_ang, style=style)
                img.save(p_dir / f"loop_{st_idx}_{p_idx}.png", optimize=True)
                total_frames += 1

        # 4. Climbs (6 frames)
        for pitch, p_name in [(22.0, "climb_steep"), (12.0, "climb_mild")]:
            for p_idx, p_ang in enumerate([0.0, 40.0, 80.0]):
                img = render_fn(mesh, roll_deg=0.0, pitch_deg=pitch, yaw_deg=0.0, prop_angle=p_ang, style=style)
                img.save(p_dir / f"{p_name}_{p_idx}.png", optimize=True)
                total_frames += 1

        # 5. Showcase roll (24 frames)
        for i in range(24):
            roll = (i / 24.0) * 360.0
            p_ang = (i * 35.0) % 360.0
            img = render_fn(mesh, roll_deg=roll, pitch_deg=0.0, yaw_deg=0.0, prop_angle=p_ang, style=style, size=256, scale=1.75)
            img.save(p_dir / f"showcase_{i}.png", optimize=True)
            total_frames += 1

        if verbose:
            print(f"  ✓ Baked {plane} (70 frames)")

    elapsed = time.time() - start_time
    if verbose:
        print(f"[Bake 3D] Successfully baked {total_frames} frames across {len(planes_config)} planes in {elapsed:.2f}s.")
    return total_frames

if __name__ == "__main__":
    bake_all_planes(verbose=True)

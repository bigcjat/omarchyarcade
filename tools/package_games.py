#!/usr/bin/env python3
"""
Omarchy Arcade • Standalone Game Packaging Utility
Generates lightweight, individually distributable .tar.gz packages (~450 KB each)
for all Omarchy Arcade games to enable fast per-game installation and updates.

Usage:
    python tools/package_games.py [--output-dir dist/packages] [--game <game_id>]
"""

import os
import sys
import json
import tarfile
import argparse
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
GAMES_DIR = ROOT_DIR / "games"
CATALOG_PATH = ROOT_DIR / "catalog.json"


def package_game(game_dir: Path, output_dir: Path, compress_level: int = 9) -> tuple[Path, int]:
    """Packages a single game directory into a .tar.gz archive."""
    game_id = game_dir.name
    tar_path = output_dir / f"{game_id}.tar.gz"

    # Exclude temporary, cache, and OS metadata files
    exclude_suffixes = {".pyc", ".pyo", ".DS_Store", ".tmp"}
    exclude_dirs = {"__pycache__", ".pytest_cache", "build"}

    def tar_filter(tarinfo):
        path = Path(tarinfo.name)
        if any(part in exclude_dirs for part in path.parts):
            return None
        if path.suffix in exclude_suffixes or path.name.startswith("._"):
            return None
        return tarinfo

    with tarfile.open(tar_path, "w:gz", compresslevel=compress_level) as tar:
        tar.add(game_dir, arcname=game_id, filter=tar_filter)

    return tar_path, tar_path.stat().st_size


def main():
    parser = argparse.ArgumentParser(description="Package Omarchy Arcade games into individual archives")
    parser.add_argument("--output-dir", "-o", type=Path, default=ROOT_DIR / "dist" / "packages",
                        help="Output directory for packaged tarballs")
    parser.add_argument("--game", "-g", type=str, default=None,
                        help="Package a specific game ID only")
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)

    if args.game:
        target = GAMES_DIR / args.game
        if not target.is_dir():
            print(f"Error: Game '{args.game}' not found in {GAMES_DIR}", file=sys.stderr)
            sys.exit(1)
        targets = [target]
    else:
        # Strictly skip omarchybolo (off-limits)
        targets = [
            d for d in sorted(GAMES_DIR.iterdir())
            if d.is_dir() and d.name != "omarchybolo" and not d.name.startswith(".")
        ]

    print(f"Packaging {len(targets)} game(s) to: {args.output_dir}...")
    manifest = {}
    total_bytes = 0

    for g_dir in targets:
        tar_path, size_bytes = package_game(g_dir, args.output_dir)
        size_kb = size_bytes / 1024
        total_bytes += size_bytes
        manifest[g_dir.name] = {
            "archive": tar_path.name,
            "size_bytes": size_bytes,
            "size_kb": round(size_kb, 1),
        }
        print(f"  ✓ {g_dir.name:<24} {size_kb:>8.1f} KB -> {tar_path.name}")

    manifest_path = args.output_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    total_mb = total_bytes / (1024 * 1024)
    avg_kb = (total_bytes / len(targets)) / 1024 if targets else 0
    print("-" * 60)
    print(f"Successfully packaged {len(targets)} games.")
    print(f"Total size: {total_mb:.2f} MB | Average archive size: {avg_kb:.1f} KB")
    print(f"Manifest written to: {manifest_path}")


if __name__ == "__main__":
    main()

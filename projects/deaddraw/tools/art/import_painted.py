#!/usr/bin/env python3
"""DeadDraw painted art import (art pack 1, board task dd-art-import).

Purpose: Turns the reviewed ChatGPT originals (full-size PNGs on the art/deaddraw-pack-1 branch, never
  committed to main) into the game-ready copies in assets/art/painted/: resized to the in-game sizes
  from documentation/art/art-pack-1-list.csv and saved as WebP (lossy, alpha kept for Patches and
  icons) so the web build stays small. Godot imports them with compress/mode=1 (lossy WebP).
  gen_art.py then points the manifest at every painted file that exists (PAINTED there), so the SVG
  art stays the fallback for anything not painted (or rejected in review).
Usage: python3 projects/deaddraw/tools/art/import_painted.py <folder with the original PNGs>
  e.g. git archive origin/art/deaddraw-pack-1 projects/deaddraw/documentation/art/chatgpt/images/art-pack-1
  | tar -x -C /tmp/raw, then pass /tmp/raw/projects/.../art-pack-1. Run gen_art.py afterwards.
Author: Sr Game Artist Agent
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / "source" / "project-deaddraw"
OUT = ROOT / "assets" / "art" / "painted"

# Rejected in review (retry prompts in documentation/art/chatgpt/dd-art-pack-1-retry-prompts.md) or blocked.
# dd-art-fit: the two retries (title landscape, Retrofit Bench) passed review and are imported.
SKIP: set[str] = set()

# District banners: the 1536x480 band kept from a 1536x1024 original (landmarks sit at 30-62% height).
BAND_TOP = 0.20


def target(name: str, w: int, h: int) -> tuple[int, int] | None:
    """In-game size (art-pack-1-list.csv) for an original."""
    if name.startswith("dd_patch_"):
        return (256, 256)
    if name.startswith("dd_icon_"):
        return (128, 128)
    if name.startswith("dd_title_"):
        return (w, h)
    if name.startswith("dd_district_"):
        return (1536, 480)
    return (w // 2, h // 2)


def convert(src: Path, dst: Path) -> int:
    im = Image.open(src)
    im.load()
    alpha = im.mode in ("RGBA", "LA") or "transparency" in im.info
    im = im.convert("RGBA" if alpha else "RGB")
    size = target(src.name, im.width, im.height)
    if src.name.startswith("dd_district_"):
        top = int(im.height * BAND_TOP)
        band_h = int(im.width * size[1] / size[0])
        im = im.crop((0, top, im.width, top + band_h))
    if im.size != size:
        im = im.resize(size, Image.LANCZOS)
    im.save(dst, "WEBP", quality=90 if alpha else 86, method=6, alpha_quality=95)
    return dst.stat().st_size


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src_dir = Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    n = 0
    for src in sorted(src_dir.glob("dd_*.png")):
        if src.name in SKIP:
            print("skip (rejected / blocked):", src.name)
            continue
        total += convert(src, OUT / (src.stem + ".webp"))
        n += 1
    print("wrote %d painted files (%.1f MB) to %s" % (n, total / 1e6, OUT))


if __name__ == "__main__":
    main()

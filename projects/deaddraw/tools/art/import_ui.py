#!/usr/bin/env python3
"""DeadDraw painted UI kit import (art pack 2, board task dd-art2-import).

Purpose: Turns the reviewed ChatGPT originals (1024/1536 px PNGs on the art/deaddraw-pack-2 branch, never
  committed to main) into the game-ready copies in assets/art/painted/ui/:
  - trims each PNG to its painted shape (the alpha bounding box) and clears near-zero alpha specks,
  - scales it to TWICE the in-game size from documentation/art/art-pack-2-ui-list.csv (the game draws
    9-slice pieces at half scale with DDNine, so the painted edges stay crisp on 2x desktop screens);
    badges and pills are kept at 1x (they are already drawn smaller than their file),
  - saves WebP with alpha (Godot re-imports it as lossy WebP, compress/mode=1).
  The 9-slice margins (in game px) live in scripts/ui/dd_skin.gd (SPEC), next to the file names.
Usage: python3 projects/deaddraw/tools/art/import_ui.py <folder with the original PNGs>
  e.g. git archive FETCH_HEAD projects/deaddraw/documentation/art/chatgpt/images/art-pack-2 | tar -x -C /tmp/raw
Author: Technical Artist Agent
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / "source" / "project-deaddraw"
OUT = ROOT / "assets" / "art" / "painted" / "ui"

# Rejected in review (retry prompts in documentation/art/chatgpt/dd-art-pack-2-retry-prompts.md).
SKIP: set[str] = set()


def target(name: str) -> tuple[int, int]:
    """File size in px (in-game size from the CSV, x2 for the 9-slice pieces)."""
    if name.startswith("dd_badge_"):
        return (128, 128)
    if name.startswith("dd_pill_"):
        return (328, 128)
    if name.startswith(("dd_btn_", "dd_chip_filter_", "dd_plate_door_")):
        return (352, 160)
    if name.startswith(("dd_plate_fullset_", "dd_tag_")):
        return (352, 128)
    if name.startswith("dd_bar_name"):
        return (368, 80)
    if name.startswith("dd_bar_"):
        return (248, 32)
    if name.startswith(("dd_panel_", "dd_frame_")):
        return (480, 480)
    if name.startswith("dd_socket_"):
        return (112, 168)
    raise SystemExit("no size for " + name)


def steel_rim(im: Image.Image, band: int = 140) -> Image.Image:
    """Review fix (sockets): the rim came out olive, off the palette; turn the outer band cool steel grey."""
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if band <= x < w - band and band <= y < h - band:
                continue
            r, g, b, a = px[x, y]
            if a == 0 or (r > 150 and g > 110 and b < 120):  # keep any yellow glow
                continue
            lum = 0.3 * r + 0.59 * g + 0.11 * b
            px[x, y] = (int(min(255, lum * 0.92)), int(min(255, lum * 1.0)), int(min(255, lum * 1.08)), a)
    return im


def convert(src: Path, dst: Path) -> int:
    im = Image.open(src).convert("RGBA")
    a = im.getchannel("A").point(lambda v: 0 if v < 10 else v)
    im.putalpha(a)
    im = im.crop(a.getbbox())
    if src.name.startswith("dd_socket_"):
        im = steel_rim(im)
    im = im.resize(target(src.name), Image.LANCZOS)
    im.save(dst, "WEBP", quality=92, method=6, alpha_quality=100)
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
            print("skip (rejected):", src.name)
            continue
        total += convert(src, OUT / (src.stem + ".webp"))
        n += 1
    print("wrote %d UI files (%.2f MB) to %s" % (n, total / 1e6, OUT))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""DeadDraw painted art import (art pack 1, board task dd-art-import).

Purpose: Turns the reviewed ChatGPT originals (full-size PNGs on the art/deaddraw-pack-1 branch, never
  committed to main) into the game-ready copies in assets/art/painted/: resized to the in-game sizes
  from documentation/art/art-pack-1-list.csv and saved as WebP (lossy, alpha kept for Patches and
  icons) so the web build stays small. Godot imports them with compress/mode=1 (lossy WebP).
  gen_art.py then points the manifest at every painted file that exists (PAINTED there), so the SVG
  art stays the fallback for anything not painted (or rejected in review).
  Art pack 3 (dd-mods-import): the Gun Mod badges dd_mod_*.png -> 256 px + a 64 px _sm copy.
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

# Gun Mod badges (art pack 3, dd-mods-import): 256 px for the inspect zoom plus a 64 px "_sm" copy for the
# 24 px gun-tile chip and the 48 px safehouse offer card (the game has no mipmaps, so a 256 px texture
# drawn at 24 px would shimmer). Each tag is cropped to its alpha box and centred with the same margin, so
# the four read as one set; the near-opaque alpha (251-253 in the originals) is snapped to 255.
MOD_SIZE = 256
MOD_SMALL = 64
MOD_MARGIN = 0.04

# District banners: the 1536x480 band kept from a 1536x1024 original (landmarks sit at 30-62% height).
BAND_TOP = 0.20


def target(name: str, w: int, h: int) -> tuple[int, int] | None:
    """In-game size (art-pack-1-list.csv) for an original."""
    if name.startswith("dd_patch_"):
        return (256, 256)
    if name.startswith("dd_icon_"):
        return (128, 128)
    if name.startswith("dd_mod_"):
        return (MOD_SIZE, MOD_SIZE)
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


def mod_square(im: Image.Image) -> Image.Image:
    """Snap the alpha, crop to the tag, centre it on a square transparent canvas with MOD_MARGIN."""
    r, g, b, a = im.split()
    a = a.point(lambda v: 0 if v < 8 else (255 if v >= 240 else v))
    im = Image.merge("RGBA", (r, g, b, a))
    box = a.getbbox() or (0, 0, im.width, im.height)
    im = im.crop(box)
    side = int(max(im.size) / (1 - 2 * MOD_MARGIN))
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    return sq


def convert_mod(src: Path) -> int:
    from PIL import ImageEnhance, ImageFilter
    im = Image.open(src).convert("RGBA")
    sq = mod_square(im)
    big = sq.resize((MOD_SIZE, MOD_SIZE), Image.LANCZOS)
    dst = OUT / (src.stem + ".webp")
    big.save(dst, "WEBP", quality=90, method=6, alpha_quality=95)
    # the small copy: a touch more contrast and an unsharp pass so the symbol survives 24 px
    sm = sq.resize((MOD_SMALL, MOD_SMALL), Image.LANCZOS)
    rgb = ImageEnhance.Contrast(sm.convert("RGB")).enhance(1.12).filter(ImageFilter.UnsharpMask(1.0, 70, 2))
    sm = Image.merge("RGBA", (*rgb.split(), sm.getchannel("A")))
    dst2 = OUT / (src.stem + "_sm.webp")
    sm.save(dst2, "WEBP", quality=92, method=6, alpha_quality=100)
    return dst.stat().st_size + dst2.stat().st_size


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
        if src.name.startswith("dd_mod_"):
            total += convert_mod(src)
        else:
            total += convert(src, OUT / (src.stem + ".webp"))
        n += 1
    print("wrote %d painted files (%.1f MB) to %s" % (n, total / 1e6, OUT))


if __name__ == "__main__":
    main()

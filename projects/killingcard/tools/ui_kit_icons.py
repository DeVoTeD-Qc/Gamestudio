#!/usr/bin/env python3
"""UI kit icon import (ui-kit-prompt-pack.md 7.2, kind `luma`). Technical Artist, kc-ui-import.

Raw ChatGPT icons (white pictogram on flat black, any square size) -> brightness becomes alpha
(levels 8%..92% crush near-black noise and near-white edges), RGB is pure white, trimmed to the
glyph and centred on a square with 8% padding; ships a 256 px master plus 128/64/48/32 exports
(<dst>/ico_x.png and <dst>/<px>/ico_x.png). UiKit (scripts/ui/ui_kit.gd) picks the export
nearest the on-screen size.

Usage (run with python3 -I; raw files are image data only):
  python3 -I tools/ui_kit_icons.py <raw_dir> source/project-killingcard/assets/ui/kit/icons
Then, from the Godot project: godot --headless --path . --import, set mipmaps/generate=true
in the new .png.import files and import again.
"""
import sys, os, glob, json
from PIL import Image, ImageOps

PAD = 0.08
MASTER = 256
EXPORTS = [128, 64, 48, 32]
LO, HI = 0.08, 0.92  # -level 8%,92%

def key(path):
    g = Image.open(path).convert('L')
    lut = [0 if v <= LO*255 else 255 if v >= HI*255 else round((v - LO*255) / ((HI-LO)*255) * 255) for v in range(256)]
    a = g.point(lut)
    bbox = a.point(lambda v: 255 if v > 24 else 0).getbbox()
    a = a.crop(bbox)
    w, h = a.size
    side = int(round(max(w, h) / (1 - 2*PAD)))
    sq = Image.new('L', (side, side), 0)
    sq.paste(a, ((side - w)//2, (side - h)//2))
    return sq, bbox

def rgba(alpha):
    im = Image.new('RGBA', alpha.size, (255, 255, 255, 0))
    im.putalpha(alpha)
    return im

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
for s in EXPORTS:
    os.makedirs(os.path.join(dst, str(s)), exist_ok=True)
report = {}
for f in sorted(glob.glob(os.path.join(src, 'ico_*.png'))):
    name = os.path.basename(f)
    sq, bbox = key(f)
    master = sq.resize((MASTER, MASTER), Image.LANCZOS)
    rgba(master).save(os.path.join(dst, name), optimize=True)
    for s in EXPORTS:
        # alpha-only resample: RGB is uniformly white, so no premultiply fringe
        rgba(sq.resize((s, s), Image.LANCZOS)).save(os.path.join(dst, str(s), name), optimize=True)
    report[name] = {'bbox': bbox, 'square': sq.size[0]}
    print(name, bbox, sq.size)

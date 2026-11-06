#!/usr/bin/env python3
"""UI kit import (ui-kit-prompt-pack.md 7.2). Technical Artist, kc-ui-import; manifest mode kc-ui-hooks.

Two modes.

1. Icons only (batch 1, unchanged): raw ChatGPT icons (white pictogram on flat black) -> `luma`:
   brightness becomes alpha (levels 8%..92%), RGB pure white, trimmed to the glyph, centred on a
   square with 8% padding; a 256 px master plus 128/64/48/32 exports (<dst>/ico_x.png and
   <dst>/<px>/ico_x.png). UiKit (scripts/ui/ui_kit.gd) picks the export nearest the on-screen size.
     python3 -I tools/ui_kit_icons.py <raw_dir> source/project-killingcard/assets/ui/kit/icons

2. Any batch, driven by the manifest (documentation/art/ui-kit-manifest.csv): every raw file in
   <raw_dir> whose name is a manifest `filename` (a `_v2` / `_v3` retry wins over the plain name) is
   processed by its kind and written to the manifest's `final_folder` under the project, at its
   `ship_size`, where UiKit looks for it (UiKit.ICON_DIR / UiKit.PIECE_DIRS):
     - icons (`ico_*`)                   -> luma, master + exports (mode 1)
     - "luma", or fx_glow_rail           -> luma (white + alpha), cropped to the content, fitted
       (fx_crack_damage, fx_glow_rail)      to the ship size (the 7.2 v2 exceptions)
     - "alpha or magenta key"            -> real alpha kept, else the magenta field keyed (12% fuzz,
       (frames, plates, coins)              1 px erode, edge despill), cropped, resized to ship size
     - `transparent` = "no" (tiles)      -> centre square, resized, made seamless (half-offset blend)
   Files not in the manifest, and RETIRED slots, are listed and skipped.
     python3 -I tools/ui_kit_icons.py --manifest <manifest.csv> <raw_dir> <godot_project_dir> [--dry-run]

After either mode, from the Godot project:
     godot --headless --path . --import
     python3 -I ../../tools/ui_kit_icons.py --post-import .    (icons: mipmaps on; then --import again)
"""
import csv
import glob
import os
import re
import sys

from PIL import Image, ImageChops, ImageFilter

PAD = 0.08
MASTER = 256
EXPORTS = [128, 64, 48, 32]
LO, HI = 0.08, 0.92  # -level 8%,92%
FUZZ = 0.12
## 7.2 v2 exceptions: generated as a glow / crack on black, processed as luma (white + alpha) so the
## code draws them with a normal blend and tints them.
LUMA_PIECES = {'fx_glow_rail.png', 'fx_crack_damage.png'}


# --- luma (icons, fx) ---------------------------------------------------------------------

def luma_alpha(img):
    """Brightness -> alpha with the 8%..92% levels."""
    g = img.convert('L')
    lut = [0 if v <= LO * 255 else 255 if v >= HI * 255 else round((v - LO * 255) / ((HI - LO) * 255) * 255) for v in range(256)]
    return g.point(lut)


def key(path):
    a = luma_alpha(Image.open(path))
    bbox = a.point(lambda v: 255 if v > 24 else 0).getbbox()
    a = a.crop(bbox)
    w, h = a.size
    side = int(round(max(w, h) / (1 - 2 * PAD)))
    sq = Image.new('L', (side, side), 0)
    sq.paste(a, ((side - w) // 2, (side - h) // 2))
    return sq, bbox


def rgba(alpha):
    im = Image.new('RGBA', alpha.size, (255, 255, 255, 0))
    im.putalpha(alpha)
    return im


def ship_icon(src_path, dst_dir, name):
    os.makedirs(dst_dir, exist_ok=True)
    for s in EXPORTS:
        os.makedirs(os.path.join(dst_dir, str(s)), exist_ok=True)
    sq, bbox = key(src_path)
    rgba(sq.resize((MASTER, MASTER), Image.LANCZOS)).save(os.path.join(dst_dir, name), optimize=True)
    for s in EXPORTS:
        # alpha-only resample: RGB is uniformly white, so no premultiply fringe
        rgba(sq.resize((s, s), Image.LANCZOS)).save(os.path.join(dst_dir, str(s), name), optimize=True)
    return 'icon luma, bbox %s, square %d, master + %s' % (bbox, sq.size[0], EXPORTS)


# --- pieces ---------------------------------------------------------------------------------

def parse_size(text):
    m = re.search(r'(\d+)\s*x\s*(\d+)', text)
    return (int(m.group(1)), int(m.group(2))) if m else None


def fit(im, size, contain=False):
    """Exactly `size`, aspect kept. 9-slice pieces cover and centre-crop (they are generated at the
    ship aspect, so this only trims slack); the rest (plates, coins, the crack) are contained and
    centred on a transparent canvas, so nothing is cut off."""
    w, h = im.size
    k = (min if contain else max)(size[0] / w, size[1] / h)
    im = im.resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)
    if contain:
        canvas = Image.new(im.mode, size, 0)
        canvas.paste(im, ((size[0] - im.size[0]) // 2, (size[1] - im.size[1]) // 2))
        return canvas
    l = (im.size[0] - size[0]) // 2
    t = (im.size[1] - size[1]) // 2
    return im.crop((l, t, l + size[0], t + size[1]))


def ship_luma_piece(src_path, dst_path, size, contain=False):
    a = luma_alpha(Image.open(src_path))
    bbox = a.point(lambda v: 255 if v > 8 else 0).getbbox() or (0, 0) + a.size
    rgba(fit(a.crop(bbox), size, contain)).save(dst_path, optimize=True)
    return 'luma piece, content %s -> %dx%d' % (bbox, size[0], size[1])


def key_magenta(im):
    """Alpha from the magenta field (12% fuzz), a 1 px erode, and a despill of the edge."""
    im = im.convert('RGB')
    r, g, b = im.split()
    # distance from #FF00FF: max(255 - r, g, 255 - b)
    d = ImageChops.lighter(ImageChops.lighter(r.point(lambda v: 255 - v), g), b.point(lambda v: 255 - v))
    alpha = d.point(lambda v: 0 if v <= FUZZ * 255 else 255).filter(ImageFilter.MinFilter(3))
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            rr, gg, bb = px[x, y]
            lim = gg + 24
            if rr > lim and bb > lim:
                px[x, y] = (min(rr, lim), gg, min(bb, lim))
    out = im.convert('RGBA')
    out.putalpha(alpha)
    return out


def ship_alpha_piece(src_path, dst_path, size, contain=False):
    im = Image.open(src_path)
    how = 'real alpha'
    if im.mode in ('RGBA', 'LA') and im.getchannel('A').getextrema()[0] < 250:
        im = im.convert('RGBA')
    else:
        im = key_magenta(im)
        how = 'magenta key'
    bbox = im.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox() or (0, 0) + im.size
    fit(im.crop(bbox), size, contain).save(dst_path, optimize=True)
    return '%s, crop %s -> %dx%d' % (how, bbox, size[0], size[1])


def ship_tile(src_path, dst_path, size):
    im = Image.open(src_path).convert('RGB')
    s = min(im.size)
    l, t = (im.size[0] - s) // 2, (im.size[1] - s) // 2
    im = im.crop((l, t, l + s, t + s)).resize(size, Image.LANCZOS)
    # Seamless: blend in a half-offset copy towards the edges (its edges are the tile's centre).
    w, h = size
    off = ImageChops.offset(im, w // 2, h // 2)
    mask = Image.new('L', size, 0)
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            ex = min(x, w - 1 - x) / (w * 0.25)
            ey = min(y, h - 1 - y) / (h * 0.25)
            mp[x, y] = int(255 * max(0.0, 1.0 - min(1.0, ex, ey)))
    Image.composite(off, im, mask).save(dst_path, optimize=True)
    return 'tile, centre square -> %dx%d, seam blend' % size


def pick_raw(raw_dir, filename, slots=()):
    """The newest try of a slot: name_v3.png > name_v2.png > name.png. A file that is a slot of its
    own (ico_kw_pick_v2.png) is never a retry of another (ico_kw_pick.png)."""
    stem, ext = os.path.splitext(filename)
    best, best_n = None, -1
    for p in glob.glob(os.path.join(raw_dir, stem + '_v*' + ext)):
        m = re.fullmatch(re.escape(stem) + r'_v(\d+)' + re.escape(ext), os.path.basename(p))
        if m and os.path.basename(p) not in slots and int(m.group(1)) > best_n:
            best, best_n = p, int(m.group(1))
    if best:
        return best
    plain = os.path.join(raw_dir, filename)
    return plain if os.path.exists(plain) else None


def manifest_mode(manifest, raw_dir, project, dry):
    rows = list(csv.DictReader(open(manifest, newline='')))
    by_file = {r['filename']: r for r in rows}
    done, skipped = [], []
    for f in sorted(os.listdir(raw_dir)):
        if f.lower().endswith('.png') and f not in by_file and re.sub(r'_v\d+(\.png)$', r'\1', f) not in by_file:
            skipped.append((f, 'not in the manifest'))
    for name, r in sorted(by_file.items()):
        src = pick_raw(raw_dir, name, by_file)
        if src is None:
            continue
        if r['status'].startswith('RETIRED'):
            skipped.append((os.path.basename(src), 'RETIRED slot'))
            continue
        folder = os.path.join(project, r['final_folder'])
        dst = os.path.join(folder, name)
        trans = r['transparent'].lower()
        size = parse_size(r['ship_size'])
        if dry:
            done.append((os.path.basename(src), r['final_folder'] + name, 'dry run (%s)' % trans))
            continue
        os.makedirs(folder, exist_ok=True)
        nine = r['nine_slice_margins_ltrb'][:1].isdigit()
        if name.startswith('ico_'):
            note = ship_icon(src, folder, name)
        elif 'luma' in trans or name in LUMA_PIECES:
            note = ship_luma_piece(src, dst, size, not nine)
        elif trans.startswith('no'):
            note = ship_tile(src, dst, size)
        else:
            note = ship_alpha_piece(src, dst, size, not nine)
        if nine:
            note += '; 9-slice %s: check the corners sit inside it' % r['nine_slice_margins_ltrb']
        done.append((os.path.basename(src), r['final_folder'] + name, note))
    for d in done:
        print('SHIP  %-30s -> %-44s %s' % d)
    for s in skipped:
        print('SKIP  %-30s %s' % s)
    print('%d shipped, %d skipped' % (len(done), len(skipped)))


def post_import(project):
    """Icons (assets/ui/kit/icons/**.png.import): mipmaps on (7.3). Pieces keep Godot's defaults
    (lossless, no mipmaps, fix_alpha_border on). Run `godot --import` again afterwards."""
    n = 0
    for p in glob.glob(os.path.join(project, 'assets/ui/kit/icons/**/*.png.import'), recursive=True):
        s = open(p).read()
        t = s.replace('mipmaps/generate=false', 'mipmaps/generate=true')
        if t != s:
            open(p, 'w').write(t)
            n += 1
    print('mipmaps switched on in %d icon .import files' % n)


def main(argv):
    if argv[:1] == ['--post-import'] and len(argv) == 2:
        post_import(argv[1])
    elif argv[:1] == ['--manifest'] and len(argv) >= 4:
        manifest_mode(argv[1], argv[2], argv[3], '--dry-run' in argv)
    elif len(argv) == 2 and not argv[0].startswith('--'):
        src, dst = argv
        for f in sorted(glob.glob(os.path.join(src, 'ico_*.png'))):
            print(os.path.basename(f), ship_icon(f, dst, os.path.basename(f)))
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

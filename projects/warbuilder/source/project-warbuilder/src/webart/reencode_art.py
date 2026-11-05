#!/usr/bin/env python3
"""Re-encode the web art (src/webart/**) into small, sized-to-display WebP files.

    python3 src/webart/reencode_art.py                # read the originals from git, write src/webart
    python3 src/webart/reencode_art.py --from DIR     # read originals from DIR (same layout as src/webart)
    python3 src/webart/reencode_art.py --check        # print what it would write, change nothing

Always start from the ORIGINALS, never from files this script already wrote (re-encoding a lossy
file again only loses quality). The originals are in git at ORIGINALS_REV (the 520 px RGBA card art,
360 px gun art, 420 px location art as imported). Needs Pillow (with WebP) and numpy.

Sizes and qualities were picked to keep build/index.html under 1.5 MB (DESIGN_REVIEW Q4) while the
art still reads at 1x on phone (844x390) and desktop (1440x900). Why each setting:
  * Card art (40 files, RGBA ink-on-transparent): shown at most ~317 CSS px wide (enlarged codex card),
    ~211 px on a card face, ~150 px in the hand, 134 px in the codex grid. Capped at 280 px.
    Its alpha channel holds all the ink detail, and WebP stores alpha (near) losslessly, so the alpha
    alone cost more than the picture. "Soft matte": keep the picture exactly as it looks on white
    paper, but replace the alpha with a smooth, slightly grown copy of the silhouette and re-solve
    the colour so  colour*alpha + white*(1-alpha)  is unchanged. On the light card faces and the
    loot cards it looks the same as before; the silhouette (no rectangle) is kept for the faint
    hand-card background, which the dark theme inverts. The alpha then costs almost nothing.
  * Gun art (RGB): shown at most ~272 CSS px wide (enlarged codex gun). Capped at 280 px.
  * Location art (RGB): drawn as a card-face photo (336 px face) and a cover background. Capped at 336 px.
"""
import argparse
import io
import os
import subprocess
import sys
from concurrent.futures import ProcessPoolExecutor

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ORIGINALS_REV = '9610a97'  # studio import commit: the art as it came from the wardeckbuilder repo
REPO_PATH = 'projects/warbuilder/source/project-warbuilder/src/webart'

# folder (relative to src/webart) -> settings
GROUPS = {
    '':     dict(max_w=280, quality=42, alpha='soft'),
    'guns': dict(max_w=280, quality=45, alpha=None),
    'locs': dict(max_w=336, quality=45, alpha=None),
}
ALPHA_QUALITY = 50
MATTE_RADIUS = 3  # px the soft silhouette grows past the ink (at the output size)


def resize(im, max_w):
    if im.width <= max_w:
        return im
    return im.resize((max_w, round(im.height * max_w / im.width)), Image.LANCZOS)


def soft_matte(im, r=MATTE_RADIUS):
    """Same look on white, smooth alpha. Returns RGBA."""
    a = np.asarray(im.convert('RGBA'), dtype=np.float32) / 255.0
    A, C = a[..., 3:4], a[..., :3]
    on_white = A * C + (1.0 - A)
    need = 1.0 - on_white.min(axis=2)  # least alpha that can still reproduce on_white
    soft = im.getchannel('A').filter(ImageFilter.MaxFilter(2 * r + 1)).filter(ImageFilter.GaussianBlur(r / 2))
    al = np.clip(np.maximum(np.asarray(soft, dtype=np.float32) / 255.0, need), 1e-3, 1.0)[..., None]
    rgb = np.clip((on_white - (1.0 - al)) / al, 0.0, 1.0)
    return Image.fromarray((np.dstack([rgb, al]) * 255.0 + 0.5).astype(np.uint8), 'RGBA')


def encode(im, cfg):
    im = resize(im.convert('RGBA') if cfg['alpha'] else im.convert('RGB'), cfg['max_w'])
    if cfg['alpha'] == 'soft':
        im = soft_matte(im)
    buf = io.BytesIO()
    im.save(buf, 'WEBP', quality=cfg['quality'], alpha_quality=ALPHA_QUALITY, method=6)
    return buf.getvalue(), im.size


def _encode_bytes(job):
    rel, orig, cfg = job
    return encode(Image.open(io.BytesIO(orig)), cfg)


def read_original(src_dir, rel):
    if src_dir:
        with open(os.path.join(src_dir, rel), 'rb') as f:
            return f.read()
    out = subprocess.run(['git', 'show', f'{ORIGINALS_REV}:{REPO_PATH}/{rel}'], cwd=HERE, capture_output=True)
    if out.returncode:
        sys.exit(f'git show failed for {rel}: {out.stderr.decode().strip()}')
    return out.stdout


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--from', dest='src', help='folder with the original art (default: git ' + ORIGINALS_REV + ')')
    ap.add_argument('--check', action='store_true', help='report sizes only, write nothing')
    args = ap.parse_args()
    jobs = []
    for sub, cfg in GROUPS.items():
        listing = os.path.join(args.src or HERE, sub)  # with --from, encode every original there
        for f in sorted(os.listdir(listing)):
            if f.endswith('.webp'):
                rel = os.path.join(sub, f) if sub else f
                jobs.append((rel, read_original(args.src, rel), cfg))
    total_in = total_out = 0
    with ProcessPoolExecutor() as ex:
        for (rel, orig, _), (data, size) in zip(jobs, ex.map(_encode_bytes, jobs)):
            total_in += len(orig); total_out += len(data)
            print(f'{rel:32s} {len(orig):7d} -> {len(data):6d}  {size[0]}x{size[1]}')
            if not args.check:
                with open(os.path.join(HERE, rel), 'wb') as fh:
                    fh.write(data)
    print(f'total {total_in:,} -> {total_out:,} bytes ({100 * total_out / total_in:.0f}%)')


if __name__ == '__main__':
    main()

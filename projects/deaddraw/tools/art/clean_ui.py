#!/usr/bin/env python3
"""DeadDraw UI skin A "Clean painted" (board task dd-ui-clean).

Purpose: Makes the bolt-free copies of the painted UI kit in assets/art/painted/ui_clean/ from the game-ready
  2x pieces in assets/art/painted/ui/ (so it runs on main, without the raw PNGs):
  1. calms the edge: light grey chips and scratches (much lighter and greyer than their neighbourhood) are
     replaced with the local median colour, so the rims read as one calm painted band;
  2. re-cuts both ends of every piece: the end region (R px wide, which holds every bolt and rivet) is
     rebuilt from the piece's own bolt-free top and bottom edge profile, sampled at each pixel's depth
     inside a new rounded rectangle with a much smaller corner radius; the face comes from a mirror of
     the bolt-free face next to it. The painted texture and colours stay; the bolts, rivets and the big
     round corners go.
  Badges and pills are not touched (skin A uses the painted ones as they are).
Usage: python3 projects/deaddraw/tools/art/clean_ui.py
Author: Technical Artist Agent
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2] / "source" / "project-deaddraw"
SRC = ROOT / "assets" / "art" / "painted" / "ui"
OUT = ROOT / "assets" / "art" / "painted" / "ui_clean"

# name prefix -> (mode, R: region rebuilt, tex px; D: rim band depth; r: new corner radius, tex px).
# "corner": the four R x R corner squares are rebuilt from their own top / side edges (pieces with straight
# sides); "ends": the whole left and right R-wide ends are rebuilt (round-capped tags, plates and bars).
RECUT: dict[str, tuple[str, int, int, int]] = {
    "dd_btn_": ("corner", 46, 16, 12),
    "dd_chip_filter_": ("corner", 46, 16, 12),
    "dd_plate_door_": ("corner", 52, 16, 12),
    "dd_plate_fullset_": ("ends", 58, 16, 18),
    "dd_tag_": ("ends", 58, 16, 18),
    "dd_bar_name": ("corner", 30, 12, 10),
    "dd_bar_": ("ends", 18, 10, 8),
    "dd_panel_": ("corner", 104, 40, 16),
    "dd_frame_": ("corner", 104, 40, 16),
    "dd_socket_": ("corner", 24, 12, 8),
}


def _smooth(e0: float, e1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - e0) / max(1e-6, e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _sample(a: np.ndarray, x: np.ndarray, y: np.ndarray) -> np.ndarray:
    """Bilinear sample of a premultiplied HxWx4 float image at continuous pixel-centre coords (index space)."""
    h, w = a.shape[:2]
    x = np.clip(x, 0.0, w - 1.0)
    y = np.clip(y, 0.0, h - 1.0)
    x0 = np.floor(x).astype(int)
    y0 = np.floor(y).astype(int)
    x1 = np.minimum(x0 + 1, w - 1)
    y1 = np.minimum(y0 + 1, h - 1)
    fx = (x - x0)[..., None]
    fy = (y - y0)[..., None]
    top = a[y0, x0] * (1 - fx) + a[y0, x1] * fx
    bot = a[y1, x0] * (1 - fx) + a[y1, x1] * fx
    return top * (1 - fy) + bot * fy


def calm(im: Image.Image) -> Image.Image:
    """Paints out the light grey chips and scratches with the local median colour."""
    rgb = im.convert("RGB")
    med = np.asarray(rgb.filter(ImageFilter.MedianFilter(9)), dtype=np.float32)
    src = np.asarray(im, dtype=np.float32).copy()
    lum = src[..., :3] @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    mlum = med @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    sat = src[..., :3].max(axis=2) - src[..., :3].min(axis=2)
    msat = med.max(axis=2) - med.min(axis=2)
    # light grey chips anywhere, and grey chips on a coloured plate
    mask = ((lum > mlum + 38.0) & (sat < 60.0)) | ((msat > 70.0) & (sat < msat * 0.45))
    mask &= src[..., 3] > 230.0
    soft = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7))
                      .filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float32)[..., None] / 255.0
    src[..., :3] = src[..., :3] * (1 - soft) + med * soft
    return Image.fromarray(np.clip(src, 0, 255).astype(np.uint8), "RGBA")


def recut_left(a: np.ndarray, big_r: int, depth: int, rad: int) -> np.ndarray:
    """Rebuilds the left end [0, R) of a premultiplied image (see the module doc)."""
    h, w = a.shape[:2]
    big_r = min(big_r, w // 2 - 1)
    rad = min(rad, h // 2)
    ys, xs = np.mgrid[0:h, 0:big_r].astype(np.float32)
    px = xs + 0.5
    py = ys + 0.5
    t_top = py
    t_bot = h - py
    t_left = px
    # depth inside the new rounded rectangle (whole image bounds, corner radius rad)
    d = np.minimum(np.minimum(t_top, t_bot), t_left)
    for cy, inside in ((rad, py < rad), (h - rad, py > h - rad)):
        corner = inside & (px < rad)
        d = np.where(corner, rad - np.hypot(px - rad, py - cy), d)
    # top / bottom / left profile samples (the edge's own rows at that depth)
    span = max(1, min(w - 2 * big_r, big_r))
    col_tb = 2.0 * big_r - px - 0.5
    col_l = big_r + (py % span) - 0.5
    dd = np.maximum(d, 0.0)
    p_top = _sample(a, col_tb, dd - 0.5)
    p_bot = _sample(a, col_tb, h - dd - 0.5)
    l_top = _sample(a, col_l, dd - 0.5)
    l_bot = _sample(a, col_l, h - dd - 0.5)
    k_bot = _smooth(h * 0.42, h * 0.58, py)[..., None]
    p_tb = p_top * (1 - k_bot) + p_bot * k_bot
    p_l = l_top * (1 - k_bot) + l_bot * k_bot
    w_left = (1.0 / (1.0 + np.exp(-(np.minimum(t_top, t_bot) - t_left) / 1.5)))[..., None]
    band = p_tb * (1 - w_left) + p_l * w_left
    face = _sample(a, 2.0 * big_r - px - 0.5, py - 0.5)
    k_face = _smooth(depth - 2.0, depth + 3.0, d)[..., None]
    new = band * (1 - k_face) + face * k_face
    new = new * np.clip(d + 0.5, 0.0, 1.0)[..., None]
    k_orig = _smooth(big_r - 8.0, big_r - 0.5, px)[..., None]
    new = new * (1 - k_orig) + a[:, :big_r] * k_orig
    out = a.copy()
    out[:, :big_r] = new
    return out


def recut_corner(a: np.ndarray, big_r: int, depth: int, rad: int) -> np.ndarray:
    """Rebuilds the top-left R x R corner square: each pixel takes its nearest edge's own profile (the top edge
    mirrored about x = R, or the left edge mirrored about y = R) at its depth inside the new corner."""
    big_r = min(big_r, a.shape[0] // 2 - 1, a.shape[1] // 2 - 1)
    ys, xs = np.mgrid[0:big_r, 0:big_r].astype(np.float32)
    px = xs + 0.5
    py = ys + 0.5
    d = np.minimum(px, py)
    corner = (px < rad) & (py < rad)
    d = np.where(corner, rad - np.hypot(px - rad, py - rad), d)
    dd = np.maximum(d, 0.0)
    mx = 2.0 * big_r - px - 0.5
    my = 2.0 * big_r - py - 0.5
    top = _sample(a, mx, dd - 0.5)
    left = _sample(a, dd - 0.5, my)
    top_face = _sample(a, mx, py - 0.5)
    left_face = _sample(a, px - 0.5, my)
    k_face = _smooth(depth - 2.0, depth + 3.0, d)[..., None]
    top = top * (1 - k_face) + top_face * k_face
    left = left * (1 - k_face) + left_face * k_face
    w_left = (1.0 / (1.0 + np.exp(-(py - px) / 1.5)))[..., None]
    new = top * (1 - w_left) + left * w_left
    new = new * np.clip(d + 0.5, 0.0, 1.0)[..., None]
    k_orig = np.maximum(_smooth(big_r - 8.0, big_r - 0.5, px), _smooth(big_r - 8.0, big_r - 0.5, py))[..., None]
    out = a.copy()
    out[:big_r, :big_r] = new * (1 - k_orig) + a[:big_r, :big_r] * k_orig
    return out


## pieces with a rivet in the middle of each side (painted out with the band next to it)
MID_RIVETS: set[str] = {"dd_frame_chip_rim"}


def patch_mid_top(a: np.ndarray, depth: int, half: int = 22) -> np.ndarray:
    """Covers the rivet in the middle of the top band with the band 2 * half px to its right."""
    w = a.shape[1]
    c = w // 2
    xs = np.arange(c - half - 6, c + half + 6)
    k = (1.0 - _smooth(half, half + 6.0, np.abs(xs - c + 0.5).astype(np.float32)))[None, :, None]
    out = a.copy()
    out[:depth, xs] = a[:depth, xs] * (1 - k) + a[:depth, xs + 2 * half + 12] * k
    return out


def clean(im: Image.Image, spec: tuple[str, int, int, int], name: str = "") -> Image.Image:
    im = calm(im)
    a = np.asarray(im, dtype=np.float32) / 255.0
    a[..., :3] *= a[..., 3:4]
    mode, big_r, depth, rad = spec
    if mode == "ends":
        a = recut_left(a, big_r, depth, rad)
        a = recut_left(a[:, ::-1].copy(), big_r, depth, rad)[:, ::-1]
    else:
        for fx, fy in ((False, False), (True, False), (False, True), (True, True)):
            v = a[:, ::-1] if fx else a
            v = v[::-1] if fy else v
            v = recut_corner(v.copy(), big_r, depth, rad)
            v = v[::-1] if fy else v
            a = (v[:, ::-1] if fx else v).copy()
    if name in MID_RIVETS:
        for k in range(4):
            a = np.rot90(patch_mid_top(np.rot90(a, k).copy(), depth), -k).copy()
    rgb = np.where(a[..., 3:4] > 1e-4, a[..., :3] / np.maximum(a[..., 3:4], 1e-4), 0.0)
    o = np.concatenate([rgb, a[..., 3:4]], axis=2)
    return Image.fromarray(np.clip(o * 255.0 + 0.5, 0, 255).astype(np.uint8), "RGBA")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    n = 0
    for f in sorted(SRC.glob("*.webp")):
        spec = next((v for k, v in RECUT.items() if f.stem.startswith(k)), None)
        if spec is None:
            continue
        clean(Image.open(f).convert("RGBA"), spec, f.stem).save(OUT / f.name, "WEBP", quality=92, method=6, alpha_quality=100)
        n += 1
    print(f"{n} clean pieces -> {OUT}")


if __name__ == "__main__":
    main()

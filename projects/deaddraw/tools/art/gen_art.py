#!/usr/bin/env python3
"""DeadDraw card art generator.

Purpose: Writes every original DeadDraw SVG (cards, finales, card back, survivor portraits,
  district banners, perk icons) plus assets/art/manifest.json. The art is hand-authored
  vector shapes; this script only holds the shared style (ink outline, palette, backgrounds)
  so every file follows documentation/art/style-guides/art-direction.md.
Usage: python3 projects/deaddraw/tools/art/gen_art.py
Godot note: ThorVG (Godot's SVG importer) is fed plain paths, circles, ellipses, rects,
  polylines, groups with transforms and linear/radial gradients only. No <text>, filters,
  masks, CSS or external refs.
Author: Sr Game Artist Agent
"""
from __future__ import annotations

import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "source" / "project-deaddraw"
ART = ROOT / "assets" / "art"

# ---------------------------------------------------------------- palette
INK = "#151214"
BONE = "#ece6d6"
BONE_D = "#bdb5a0"
EYE = "#f4ea9c"
GORE = "#8e2a24"       # stylised blood, used sparingly
SOCKET = "#2a1c1c"

PAL = {
    # kind: (bg, mid, motif, accent)  bg/accent match DDUi.card_bg / DDUi.accent
    "zombie":    ("#3b2321", "#5c302a", "#2c1918", "#e2574c"),
    "weapon":    ("#1f2e3a", "#2e4a5f", "#18242e", "#5bb0e0"),
    "medkit":    ("#1d3325", "#2b4d37", "#16281d", "#6fd08a"),
    "barricade": ("#37301d", "#56472a", "#2a2416", "#e0b04a"),
    "finale":    ("#2c1d35", "#4a3060", "#21152a", "#c27ce0"),
    "survivor":  ("#2a2a24", "#4a4532", "#201f1a", "#f0d27a"),
    "perk":      ("#26283a", "#3a3e5c", "#1d1f2e", "#9aa8ff"),
    "district":  ("#22282c", "#38424a", "#1a1f22", "#b8c4c0"),
}

SKIN_Z = ("#8ea476", "#62774f")     # zombie skin, shade
SKIN_PZ = ("#a9b996", "#77876a")    # Patient Zero, paler
STEEL = ("#b8c4c0", "#6d7b80")
WOOD = ("#a87443", "#744b2a")


def f(v: float) -> str:
    return ("%.1f" % v).rstrip("0").rstrip(".")


def pts(p) -> str:
    return " ".join("%s,%s" % (f(x), f(y)) for x, y in p)


# ---------------------------------------------------------------- primitives
def path(d: str, fill: str, sw: float = 4, stroke: str = INK, extra: str = "") -> str:
    if sw <= 0:
        return '<path d="%s" fill="%s"%s/>' % (d, fill, (" " + extra) if extra else "")
    return ('<path d="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round" '
            'stroke-linecap="round"%s/>' % (d, fill, stroke, f(sw), (" " + extra) if extra else ""))


def poly(p, fill: str, sw: float = 4, extra: str = "") -> str:
    return path("M" + " L".join("%s %s" % (f(x), f(y)) for x, y in p) + " Z", fill, sw, extra=extra)


def line(p, w: float, color: str, extra: str = "") -> str:
    return ('<polyline points="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round" '
            'stroke-linecap="round"%s/>' % (pts(p), color, f(w), (" " + extra) if extra else ""))


def limb(p, w: float, fill: str, ink: float = 4) -> str:
    """Outlined capsule chain: ink pass then colour pass."""
    return line(p, w + 2 * ink, INK) + line(p, w, fill)


def circ(cx, cy, r, fill, sw=4, extra="") -> str:
    s = ' stroke="%s" stroke-width="%s"' % (INK, f(sw)) if sw > 0 else ""
    return '<circle cx="%s" cy="%s" r="%s" fill="%s"%s%s/>' % (f(cx), f(cy), f(r), fill, s, (" " + extra) if extra else "")


def ell(cx, cy, rx, ry, fill, sw=4, rot=0.0, extra="") -> str:
    s = ' stroke="%s" stroke-width="%s"' % (INK, f(sw)) if sw > 0 else ""
    t = ' transform="rotate(%s %s %s)"' % (f(rot), f(cx), f(cy)) if rot else ""
    return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"%s%s%s/>' % (
        f(cx), f(cy), f(rx), f(ry), fill, s, t, (" " + extra) if extra else "")


def rect(x, y, w, h, fill, sw=4, rx=0, extra="") -> str:
    s = ' stroke="%s" stroke-width="%s" stroke-linejoin="round"' % (INK, f(sw)) if sw > 0 else ""
    r = ' rx="%s"' % f(rx) if rx else ""
    return '<rect x="%s" y="%s" width="%s" height="%s"%s fill="%s"%s%s/>' % (
        f(x), f(y), f(w), f(h), r, fill, s, (" " + extra) if extra else "")


def g(body: str, transform: str = "", opacity: float | None = None) -> str:
    a = ""
    if transform:
        a += ' transform="%s"' % transform
    if opacity is not None:
        a += ' opacity="%s"' % f(opacity)
    return "<g%s>%s</g>" % (a, body)


def svg(w: int, h: int, body: str, defs: str = "") -> str:
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n'
            '<defs>%s</defs>\n%s\n</svg>\n' % (w, h, w, h, defs, body))


def radial(id_: str, inner: str, outer: str, cx=0.6, cy=0.42, r=0.75) -> str:
    return ('<radialGradient id="%s" cx="%s" cy="%s" r="%s"><stop offset="0" stop-color="%s"/>'
            '<stop offset="1" stop-color="%s"/></radialGradient>' % (id_, f(cx), f(cy), f(r), inner, outer))


def linear(id_: str, stops, vertical=True) -> str:
    x2, y2 = ("0", "1") if vertical else ("1", "0")
    s = "".join('<stop offset="%s" stop-color="%s"/>' % (f(o), c) for o, c in stops)
    return '<linearGradient id="%s" x1="0" y1="0" x2="%s" y2="%s">%s</linearGradient>' % (id_, x2, y2, s)


# ---------------------------------------------------------------- card art frame (240 x 180)
CW, CH = 240, 180
GROUND = 158


def motif_zombie(m: str) -> str:
    b = [(0, 96, 26), (24, 70, 22), (44, 104, 30), (72, 58, 20), (90, 88, 34), (122, 64, 24),
         (144, 98, 28), (170, 52, 22), (190, 84, 30), (218, 66, 22)]
    s = "".join(rect(x, y, w, CH - y, m, 0) for x, y, w in b)
    win = [(30, 80), (96, 98), (128, 76), (176, 64), (196, 96), (224, 78), (52, 112)]
    s += "".join(rect(x, y, 5, 7, "#4a2d27", 0) for x, y in win)
    return s


def motif_weapon(m: str) -> str:   # pegboard
    return "".join(circ(x, y, 2.4, m, 0) for x in range(14, CW, 22) for y in range(14, GROUND, 22))


def motif_medkit(m: str) -> str:   # quiet plus pattern
    out = ""
    for i, x in enumerate(range(18, CW, 44)):
        for j, y in enumerate(range(18, GROUND, 44)):
            if (i + j) % 2 == 0:
                out += rect(x - 2.5, y - 8, 5, 16, m, 0) + rect(x - 8, y - 2.5, 16, 5, m, 0)
    return out


def motif_barricade(m: str) -> str:  # brick wall
    out = ""
    for r, y in enumerate(range(0, GROUND, 18)):
        off = 0 if r % 2 == 0 else -20
        for x in range(off, CW, 40):
            out += rect(x + 1.5, y + 1.5, 37, 15, m, 0, rx=2)
    return out


def motif_finale(m: str) -> str:
    return circ(176, 52, 40, "#5a4170", 0) + circ(162, 44, 8, "#4f3863", 0) + circ(190, 66, 5, "#4f3863", 0)


MOTIFS = {"zombie": motif_zombie, "weapon": motif_weapon, "medkit": motif_medkit,
          "barricade": motif_barricade, "finale": motif_finale}


def card_art(kind: str, body: str, ground: bool = True, extra_bg: str = "") -> str:
    bg, mid, motif, _acc = PAL[kind]
    defs = radial("bg", mid, bg)
    s = rect(0, 0, CW, CH, bg, 0) + rect(0, 0, CW, CH, "url(#bg)", 0)
    s += g(MOTIFS[kind](motif), opacity=0.9)
    s += extra_bg
    if ground:
        s += rect(0, GROUND, CW, CH - GROUND, INK, 0, extra='opacity="0.45"')
        s += ell(140, GROUND + 2, 70, 7, INK, 0, extra='opacity="0.4"')
    s += body
    return svg(CW, CH, s, defs)


# ---------------------------------------------------------------- zombie figure builder
def hem(x1: float, x2: float, y: float, teeth: int = 5, depth: float = 6):
    """Torn hem points from x2 back to x1."""
    out = []
    n = teeth * 2
    for i in range(n + 1):
        x = x2 + (x1 - x2) * i / n
        out.append((x, y + (depth if i % 2 else 0) - (2 if i % 4 == 0 else 0)))
    return out


def zhead(hx, hy, rx, ry, skin, tilt=0.0, hair=None, mouth=True, brow=True, hat="") -> str:
    sk, sd = skin
    s = ell(hx, hy, rx, ry, sk)
    s += path("M%s %s Q%s %s %s %s" % (f(hx - rx * 0.75), f(hy + ry * 0.35), f(hx), f(hy + ry * 1.05),
                                       f(hx + rx * 0.75), f(hy + ry * 0.35)), "none", 0)
    # cheek shade
    s += path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % (
        f(hx + rx * 0.2), f(hy + ry * 0.9), f(hx + rx * 0.95), f(hy + ry * 0.4), f(hx + rx * 0.92), f(hy - ry * 0.2),
        f(hx + rx * 0.7), f(hy + ry * 0.5), f(hx + rx * 0.2), f(hy + ry * 0.9)), sd, 0)
    ex = rx * 0.42
    s += ell(hx - ex, hy - ry * 0.05, rx * 0.3, ry * 0.22, SOCKET, 0)
    s += ell(hx + ex, hy - ry * 0.02, rx * 0.33, ry * 0.25, SOCKET, 0)
    s += circ(hx - ex + 0.5, hy - ry * 0.02, max(1.8, rx * 0.13), EYE, 0)
    s += circ(hx + ex - 0.5, hy + ry * 0.0, max(1.8, rx * 0.15), EYE, 0)
    if brow:
        s += line([(hx - ex - rx * 0.3, hy - ry * 0.32), (hx - 1, hy - ry * 0.18)], 2.6, INK)
        s += line([(hx + 1, hy - ry * 0.16), (hx + ex + rx * 0.32, hy - ry * 0.3)], 2.6, INK)
    if mouth:
        my = hy + ry * 0.5
        mw = rx * 0.48
        s += poly([(hx - mw, my - 2), (hx + mw, my - 3), (hx + mw * 0.7, my + ry * 0.26), (hx - mw * 0.8, my + ry * 0.24)], SOCKET, 2)
        s += rect(hx - mw * 0.55, my - 2.5, 3, 3.2, BONE, 0) + rect(hx + mw * 0.1, my - 3, 3, 3.6, BONE, 0)
    if hair:
        s += hair
    s += hat
    s += ell(hx, hy, rx, ry, "none")  # crisp outline on top
    if tilt:
        return g(s, "rotate(%s %s %s)" % (f(tilt), f(hx), f(hy)))
    return s


def hand(x, y, ang, r, skin, claws=True) -> str:
    s = ""
    if claws:
        for d in (-0.5, 0.0, 0.5):
            a = ang + d
            s += limb([(x, y), (x + math.cos(a) * r * 2.0, y + math.sin(a) * r * 2.0)], r * 0.55, skin, 3)
    s += circ(x, y, r, skin, 3.5)
    return s


def zombie(cx, gy, *, leg=46, torso=46, sw=21, hw=15, legw=13, armw=10, hr=(14, 16), neck=5,
           lean=0.0, tilt=0.0, skin=SKIN_Z, shirt="#6c6a78", pants="#3a3f47", shoe="#262222",
           arms=None, sleeve=0.5, hair=None, hat="", torso_extra="", over="", stance=4,
           scale=1.0, hemd=6) -> str:
    """Front-ish zombie, origin at feet centre. arms: {"L": [(dx,dy) elbow, (dx,dy) hand], "R": ...}
    relative to the shoulder joint. Returns a group already placed at (cx, gy)."""
    sk, sd = skin
    hip = -leg
    sh = hip - torso
    s = ""
    # legs
    for side in (-1, 1):
        top = (side * hw * 0.55, hip + 4)
        foot = (side * (hw * 0.55 + stance), -5)
        s += limb([top, ((top[0] + foot[0]) / 2 + side * 1.5, hip / 2), foot], legw, pants)
        s += ell(foot[0] + side * 3, -3, legw * 0.75, 5, shoe, 3)
    s += rect(-hw - 1, hip - 6, 2 * hw + 2, 14, pants, 4, rx=4)
    # arms (behind torso drawn later on top for reaching arms)
    arms = arms or {"L": [(-6, 22), (-4, 44)], "R": [(6, 22), (4, 44)]}
    arm_s = {}
    for k, side in (("L", -1), ("R", 1)):
        shx, shy = side * (sw - 4), sh + 6
        el = (shx + arms[k][0][0], shy + arms[k][0][1])
        hd = (shx + arms[k][1][0], shy + arms[k][1][1])
        a = limb([(shx, shy), el, hd], armw, sk)
        if sleeve > 0:
            mx = shx + (el[0] - shx) * sleeve * 1.6
            my = shy + (el[1] - shy) * sleeve * 1.6
            a += limb([(shx, shy), (mx, my)], armw + 5, shirt)
        ang = math.atan2(hd[1] - el[1], hd[0] - el[0])
        a += hand(hd[0], hd[1], ang, armw * 0.62, sk)
        arm_s[k] = a
    # torso
    hp = hem(-hw - 3, hw + 3, hip + 6, 4, hemd)
    d = "M%s %s Q0 %s %s %s L%s %s " % (f(-sw), f(sh + 4), f(sh - 4), f(sw), f(sh + 4), f(hw + 3), f(hip + 6))
    d += " ".join("L%s %s" % (f(x), f(y)) for x, y in hp[1:]) + " Z"
    s += path(d, shirt)
    s += path("M%s %s L0 %s L%s %s" % (f(-7), f(sh - 1), f(sh + 12), f(7), f(sh - 1)), sk, 3)
    s += torso_extra
    s += arm_s["L"] + arm_s["R"]
    # neck + head
    hx, hy = 0, sh - neck - hr[1] + 4
    s += limb([(0, sh + 2), (0, hy + hr[1] * 0.6)], 9, sd, 3)
    s += zhead(hx, hy, hr[0], hr[1], skin, tilt, hair, hat=hat)
    s += over
    t = "matrix(%s 0 %s %s %s %s)" % (f(scale), f(-lean * scale), f(scale), f(cx), f(gy))
    return g(s, t)


def hair_tufts(hx, hy, rx, ry, color="#3b3530") -> str:
    d = "M%s %s Q%s %s %s %s L%s %s L%s %s L%s %s L%s %s Q%s %s %s %s Z" % (
        f(hx - rx * 1.02), f(hy - ry * 0.1), f(hx - rx * 0.9), f(hy - ry * 1.2), f(hx), f(hy - ry * 1.08),
        f(hx + rx * 0.3), f(hy - ry * 1.3), f(hx + rx * 0.45), f(hy - ry * 0.95), f(hx + rx * 0.8), f(hy - ry * 1.15),
        f(hx + rx * 0.85), f(hy - ry * 0.7), f(hx + rx * 1.05), f(hy - ry * 0.4), f(hx + rx * 0.4), f(hy - ry * 0.75))
    return path(d, color, 3)


# ---------------------------------------------------------------- zombie cards
def z_shambler() -> str:
    hr = (13, 15)
    body = zombie(140, GROUND, leg=40, torso=40, sw=18, hw=13, legw=12, armw=10, hr=hr, lean=0.12, tilt=-14, scale=1.25,
                  shirt="#7a6a58", pants="#454a52",
                  arms={"L": [(-6, 20), (-2, 40)], "R": [(18, 6), (40, 2)]},
                  hair=hair_tufts(0, -40 - 40 - 5 - 15 + 4, 13, 15, "#4a4038"),
                  torso_extra=ell(-6, -62, 4, 3, GORE, 0) + line([(4, -70), (10, -60)], 2, "#5a4c3e"))
    return card_art("zombie", body)


def z_lurcher() -> str:
    hr = (14, 16)
    hy = -50 - 46 - 5 - 16 + 4
    body = zombie(114, GROUND, leg=50, torso=46, sw=20, hw=14, legw=13, armw=11, hr=hr, lean=0.3, tilt=12, scale=1.1,
                  shirt="#46607c", pants="#2f3540", stance=10,
                  arms={"L": [(20, 6), (42, 2)], "R": [(20, -4), (40, -12)]}, sleeve=0.7,
                  hair=path("M-14 %s Q-10 %s 0 %s Q12 %s 15 %s Q8 %s -2 %s Q-8 %s -14 %s Z" % (
                      f(hy - 2), f(hy - 20), f(hy - 17), f(hy - 19), f(hy - 4), f(hy - 11), f(hy - 9), f(hy - 12), f(hy - 2)), "#2b2420", 3),
                  torso_extra=line([(-10, -86), (-4, -60)], 2.5, "#33475d") + line([(9, -88), (6, -66)], 2.5, "#33475d")
                  + ell(8, -70, 4, 5, GORE, 0))
    return card_art("zombie", body)


def z_bruiser() -> str:
    hr = (15, 15)
    hy = -44 - 50 - 4 - 17 + 4
    vest = (poly([(-30, -90), (-12, -90), (-14, -44), (-22, -44)], "#d9a03a", 3)
            + poly([(12, -90), (30, -90), (22, -44), (14, -44)], "#d9a03a", 3)
            + rect(-28, -70, 15, 5, BONE, 0) + rect(13, -70, 15, 5, BONE, 0))
    hat = (path("M-21 %s Q0 %s 21 %s Z" % (f(hy - 6), f(hy - 32), f(hy - 6)), "#d9a03a", 3.5)
           + rect(-25, hy - 9, 50, 6, "#c08a2c", 3.5, rx=3) + line([(0, hy - 26), (0, hy - 10)], 2.5, "#a8772a"))
    body = zombie(138, GROUND, leg=44, torso=50, sw=36, hw=24, legw=19, armw=17, hr=(17, 17), neck=4, lean=0.05, scale=1.0,
                  shirt="#4b4f58", pants="#3a3226", stance=8,
                  arms={"L": [(-12, 26), (-12, 52)], "R": [(14, 24), (18, 50)]}, sleeve=0.55,
                  hat=hat, torso_extra=vest)
    return card_art("zombie", body)


def z_hulk() -> str:
    hr = (12, 12)
    s = ""
    # massive hunched hulk: built by hand for the oversized silhouette
    sk, sd = SKIN_Z
    s += limb([(-26, -60), (-34, -30), (-36, -4)], 24, "#3e3a34") + ell(-38, -3, 18, 6, "#262222", 3)
    s += limb([(26, -60), (34, -30), (38, -4)], 24, "#3e3a34") + ell(40, -3, 18, 6, "#262222", 3)
    s += rect(-36, -70, 72, 22, "#3e3a34", 4, rx=8)
    # back arms
    s += limb([(-50, -112), (-74, -70), (-70, -26)], 26, sk)
    s += hand(-70, -22, math.pi / 2, 14, sk)
    # torso: barrel with ripped tank top
    s += path("M-58 -122 Q0 -150 58 -122 Q66 -90 40 -62 L-40 -62 Q-66 -90 -58 -122 Z", sk)
    s += path("M-30 -128 Q0 -136 30 -128 L36 -70 L24 -64 L14 -72 L2 -62 L-10 -72 L-22 -63 L-36 -70 Z", "#6b5b4b")
    s += path("M-58 -122 Q-50 -100 -42 -96", "none", 3) + path("M58 -122 Q50 -100 42 -96", "none", 3)
    s += path("M-14 -110 Q-6 -100 2 -112 M6 -96 Q14 -88 22 -98", "none", 3, stroke="#4e4033")
    s += line([(-46, -110), (-38, -104), (-46, -98)], 2.5, "#4e5c40")  # stitches
    s += ell(28, -106, 5, 6, GORE, 0)
    s += limb([(50, -112), (76, -72), (74, -28)], 26, sk)
    s += hand(74, -24, math.pi / 2, 14, sk)
    s += line([(70, -88), (80, -80)], 2.5, sd) + line([(-74, -84), (-64, -78)], 2.5, sd)
    # tiny head sunk into shoulders
    s += zhead(4, -140, hr[0], hr[1], SKIN_Z, -6, hair=None, brow=True)
    body = g(s, "matrix(1 0 -0.08 1 136 %s)" % GROUND)
    return card_art("zombie", body)


# ---------------------------------------------------------------- finales
def fin_groundskeeper() -> str:
    hr = (14, 16)
    hy = -54 - 50 - 5 - 16 + 4
    brim = (ell(0, hy - 8, 30, 6, "#5a4a32", 3.5) + path("M-15 %s Q0 %s 15 %s Z" % (f(hy - 8), f(hy - 30), f(hy - 8)), "#6b5838", 3.5)
            + rect(-15, hy - 13, 30, 4, "#3b2f20", 0))
    overall = (rect(-16, -100, 32, 28, "#4d6040", 3.5, rx=3) + line([(-14, -100), (-18, -112)], 5, "#4d6040")
               + line([(14, -100), (18, -112)], 5, "#4d6040") + circ(-11, -95, 2.5, BONE_D, 0) + circ(11, -95, 2.5, BONE_D, 0)
               + rect(-6, -90, 12, 9, "#3d4e33", 2))
    shovel = (limb([(44, -150), (46, -40)], 6, WOOD[0]) + path("M34 -40 L58 -40 L56 -12 Q46 2 36 -12 Z", STEEL[1], 4)
              + line([(40, -32), (40, -14)], 2.5, STEEL[0]) + rect(34, -156, 20, 8, WOOD[1], 3.5, rx=3))
    body = shovel + zombie(0, 0, leg=54, torso=50, sw=21, hw=16, legw=13, armw=11, hr=hr, lean=0.0, tilt=-6,
                           shirt="#7b6d5a", pants="#4d6040", stance=6,
                           arms={"L": [(-8, 24), (-6, 48)], "R": [(16, 10), (28, -10)]}, sleeve=0.6,
                           hat=brim, torso_extra=overall)
    return card_art("finale", g(body, "translate(122 %s)" % GROUND))


def fin_horde() -> str:
    def suit(cx, sc, shirt, tie, tilt, arms, extra=""):
        sh = -46 - 46
        torso = (path("M-7 %s L0 %s L7 %s L4 %s L0 %s L-4 %s Z" % (sh - 1, sh + 16, sh - 1, sh + 6, sh + 30, sh + 6), "#d8d2c2", 0)
                 + poly([(-3, sh + 4), (3, sh + 4), (4, sh + 26), (0, sh + 32), (-4, sh + 26)], tie, 2)
                 + line([(-8, sh + 2), (-3, sh + 30)], 2.5, INK) + line([(8, sh + 2), (3, sh + 30)], 2.5, INK))
        return zombie(cx, GROUND, leg=46, torso=46, sw=20, hw=15, legw=12, armw=10, hr=(14, 16), lean=0.1, tilt=tilt,
                      shirt=shirt, pants=shirt, arms=arms, sleeve=0.9, scale=sc, torso_extra=torso + extra,
                      hair=hair_tufts(0, -46 - 46 - 5 - 16 + 4, 14, 16, "#2b2622"))
    back = g(suit(70, 0.78, "#3d4250", "#7a3b3b", 8, {"L": [(-10, -16), (-6, -40)], "R": [(14, 18), (12, 40)]})
             + suit(196, 0.8, "#4a4038", "#3f5f7a", -10, {"L": [(-14, 16), (-10, 40)], "R": [(16, -14), (12, -38)]}), opacity=0.92)
    front = suit(128, 1.0, "#2f3442", "#8e6a2a", 6, {"L": [(-10, 22), (-12, 42)], "R": [(22, -6), (42, -26)]}, extra="")
    lights = rect(14, 20, 16, 44, "#2a2a2e", 3.5, rx=4) + circ(22, 30, 4.5, "#5a2420", 0) + circ(22, 42, 4.5, "#e0b04a", 0) + circ(22, 54, 4.5, "#2e4434", 0) + rect(19.5, 64, 5, 94, "#2a2a2e", 3)
    return card_art("finale", back + front, extra_bg=lights)


def fin_patient_zero() -> str:
    hr = (15, 17)
    hy = -52 - 48 - 5 - 17 + 4
    gown = ("#8fb0b8", "#6f8f98")
    dots = "".join(circ(x, y, 2, gown[1], 0) for x, y in ((-10, -84), (6, -90), (12, -74), (-4, -68), (-14, -64), (10, -60)))
    tape = g(rect(-20, -9, 300, 18, "#e0b04a", 0)
             + "".join(poly([(x, -9), (x + 12, -9), (x + 2, 9), (x - 10, 9)], INK, 0) for x in range(-10, 290, 26)),
             "translate(-10 166) rotate(-14)")
    iv = (line([(60, 34), (60, 150)], 4, STEEL[1]) + line([(50, 34), (70, 34)], 4, STEEL[1])
          + rect(48, 38, 18, 26, "#bcd8de", 3, rx=5) + line([(57, 64), (66, 96), (96, 92)], 2, "#bcd8de")
          + line([(48, 152), (72, 152)], 4, STEEL[1]))
    band = rect(-34, -36, 10, 5, BONE, 2)
    body = zombie(0, 0, leg=52, torso=48, sw=20, hw=17, legw=12, armw=10, hr=hr, lean=-0.04, tilt=8,
                  skin=SKIN_PZ, shirt=gown[0], pants=SKIN_PZ[1], shoe=SKIN_PZ[1], stance=7,
                  arms={"L": [(-12, 20), (-14, 44)], "R": [(20, -2), (44, -22)]}, sleeve=0.45, hemd=10,
                  hair=path("M-15 %s Q-14 %s -4 %s Q-6 %s -15 %s Z" % (f(hy - 2), f(hy - 18), f(hy - 16), f(hy - 8), f(hy - 2)), "#5a5048", 3),
                  torso_extra=dots + band)
    return card_art("finale", g(body, "translate(140 %s)" % (GROUND - 2)), extra_bg=iv + g(tape, opacity=0.6))


# ---------------------------------------------------------------- weapons
def weapon_card(body: str, rot: float = -30, cx: float = 132, cy: float = 92) -> str:
    shadow = g(body, "translate(%s %s) rotate(%s)" % (f(cx + 6), f(cy + 8), f(rot)), opacity=0.0)
    return card_art("weapon", shadow + g(body, "translate(%s %s) rotate(%s)" % (f(cx), f(cy), f(rot))), ground=False)


def grip(x1, x2, w, color, band="#2a2f36", step=9) -> str:
    s = limb([(x1, 0), (x2, 0)], w, color)
    for x in range(int(x1) + 4, int(x2) - 2, step):
        s += line([(x, -w / 2 + 1), (x + 4, w / 2 - 1)], 2.2, band)
    return s


def w_bottle() -> str:
    glass, glass_d, hi = "#4f8a5a", "#35623f", "#9bd0a4"
    s = rect(-92, -8, 34, 16, glass, 4, rx=4) + rect(-96, -10, 8, 20, glass_d, 3.5, rx=2)
    s += path("M-60 -9 Q-44 -10 -36 -22 L34 -22 L46 -30 L52 -14 L62 -20 L58 -2 L70 4 L56 10 L60 22 L44 16 L36 22 L-36 22 Q-44 10 -60 9 Z", glass)
    s += path("M-30 -14 L28 -14", "none", 5, stroke=hi) + path("M-80 -3 L-62 -3", "none", 3, stroke=hi)
    s += rect(-20, -16, 36, 32, "#c9b98a", 3) + path("M16 -16 L10 -4 L16 6 L12 16", "none", 3)
    s += path("M-14 -6 L4 -6 M-14 2 L0 2", "none", 2.5, stroke="#8f7f58")
    return weapon_card(s, -34, 128, 96)


def w_hammer() -> str:
    s = limb([(-92, 0), (50, 0)], 14, WOOD[0]) + grip(-92, -46, 16, "#3a3f47", "#23272c")
    s += path("M40 -14 L66 -14 L66 30 L40 30 Z", STEEL[0])
    s += rect(42, 30, 22, 14, STEEL[1], 4, rx=3)
    s += path("M42 -14 Q40 -40 26 -58 L36 -60 Q48 -44 52 -14 Z M56 -14 Q60 -42 50 -62 L60 -62 Q70 -40 66 -14 Z", STEEL[1])
    s += line([(48, -6), (48, 22)], 3, "#e1e8e5")
    return weapon_card(s, -34, 120, 100)


def w_crowbar() -> str:
    bar = "#4a555b"
    s = limb([(-96, 6), (-84, 0), (66, 0), (84, -12), (84, -34), (70, -44)], 13, bar)
    s += line([(-80, -3), (60, -3)], 3, "#8c9aa0")
    s += line([(-100, 12), (-92, 4)], 4, INK) + line([(64, -45), (74, -42)], 3, INK)
    for x in (-40, 12, 40):
        s += ell(x, 2, 4, 3, "#9a5b32", 0)
    return weapon_card(s, -28, 124, 100)


def w_cricket_bat() -> str:
    willow, willow_d = "#dcbb7c", "#b08e52"
    s = grip(-98, -30, 14, "#3a6a8e", "#244862", 8)
    s += circ(-100, 0, 8, "#244862", 3.5)
    s += path("M-34 -8 Q-22 -20 -6 -20 L82 -20 Q98 -20 98 0 Q98 20 82 20 L-6 20 Q-22 20 -34 8 Z", willow)
    s += path("M-6 -12 L78 -12", "none", 4, stroke="#ead1a0") + path("M-30 0 L-10 0", "none", 3, stroke=willow_d)
    s += path("M10 -20 L20 0 L10 20", "none", 2.5, stroke=willow_d)
    for x, y, r in ((50, 6, 3), (64, -4, 2.2), (72, 10, 2.5), (40, -8, 1.8)):
        s += circ(x, y, r, GORE, 0, extra='opacity="0.85"')
    return weapon_card(s, -30, 122, 96)


def w_machete() -> str:
    s = path("M-26 -12 L80 -14 Q102 -14 106 -26 Q108 6 82 14 L-26 14 Z", STEEL[0])
    s += path("M-20 -6 L80 -8 Q96 -8 102 -18", "none", 3.5, stroke="#e6eeeb")
    s += path("M-26 6 L76 6", "none", 2.5, stroke=STEEL[1])
    s += rect(-36, -18, 10, 36, "#2b2a2a", 4, rx=3)
    s += path("M-94 -10 Q-66 -14 -36 -10 L-36 10 Q-66 14 -96 12 Q-102 0 -94 -10 Z", "#2b2a2a")
    s += circ(-76, 0, 3, BONE_D, 0) + circ(-52, 0, 3, BONE_D, 0)
    return weapon_card(s, -30, 122, 98)


def w_fire_axe() -> str:
    s = limb([(-100, 0), (56, 0)], 14, "#d9a03a") + grip(-100, -62, 16, "#2a2f36", "#121416")
    s += line([(-58, -5), (40, -5)], 3, "#f0c46a")
    s += path("M40 -14 L66 -14 L66 14 L40 14 Z", "#b5402f")
    s += path("M44 14 Q34 46 30 58 Q56 66 80 58 Q72 40 62 14 Z", "#b5402f")
    s += path("M30 58 Q56 66 80 58", "none", 7, stroke=STEEL[0]) + path("M30 58 Q56 66 80 58", "none", 0)
    s += path("M44 -14 L54 -48 L62 -14 Z", "#8a2f24")
    s += line([(48, 24), (52, 44)], 3, "#d76250")
    return weapon_card(s, -36, 120, 92)


def w_sledge() -> str:
    s = limb([(-100, 0), (40, 0)], 15, WOOD[0]) + grip(-100, -60, 17, "#3a3f47", "#23272c")
    s += line([(-56, -5), (36, -5)], 3, "#c99566")
    s += rect(30, -38, 48, 76, STEEL[1], 4, rx=4)
    s += rect(24, -42, 60, 12, "#55636a", 4, rx=3) + rect(24, 30, 60, 12, "#55636a", 4, rx=3)
    s += line([(40, -24), (40, 20)], 4, "#9fadb2")
    return weapon_card(s, -30, 116, 98)


def w_chainsaw() -> str:
    orange, orange_d = "#d9772f", "#a85520"
    s = path("M-6 -16 L94 -16 Q108 -16 108 0 Q108 16 94 16 L-6 16 Z", STEEL[0])
    for x in range(0, 100, 10):
        s += poly([(x, -16), (x + 5, -24), (x + 9, -16)], INK, 0) + poly([(x, 16), (x + 5, 24), (x + 9, 16)], INK, 0)
    s += path("M4 -6 L92 -6", "none", 3, stroke="#e1e8e5") + circ(94, 0, 4, STEEL[1], 3)
    s += path("M-78 -30 L-6 -30 L4 -20 L4 24 L-70 24 Q-84 24 -84 10 L-84 -24 Z", orange)
    s += rect(-70, -22, 30, 10, orange_d, 0, rx=3) + rect(-34, 0, 28, 16, "#2b2a2a", 3, rx=3)
    s += path("M-74 -30 Q-74 -56 -44 -56 L-20 -56 Q-12 -56 -12 -46 L-12 -30", "none", 12, stroke=INK)
    s += path("M-74 -30 Q-74 -56 -44 -56 L-20 -56 Q-12 -56 -12 -46 L-12 -30", "none", 5, stroke="#2b2a2a")
    s += limb([(-84, 14), (-104, 14)], 10, "#2b2a2a") + circ(-62, 6, 6, "#2b2a2a", 3)
    return weapon_card(s, -24, 128, 102)


# ---------------------------------------------------------------- medkits
def m_bandage() -> str:
    roll, roll_d = BONE, BONE_D
    s = path("M140 108 Q170 96 186 116 Q202 136 226 126", "none", 26, stroke=INK)
    s += path("M140 108 Q170 96 186 116 Q202 136 226 126", "none", 18, stroke=roll)
    s += path("M150 104 L150 112 M164 102 L164 110 M178 106 L176 114 M196 124 L192 132 M212 128 L210 136", "none", 2, stroke=roll_d)
    s += path("M92 70 L148 70 L148 130 L92 130 Z", roll)
    s += ell(92, 100, 16, 30, roll_d) + ell(92, 100, 7, 13, "#8a8270")
    s += ell(148, 100, 16, 30, roll)
    s += ell(148, 100, 7, 13, "#8a8270", 3)
    s += line([(104, 80), (136, 80)], 3, "#ffffff")
    # safety pin + adhesive strip with a green plus
    s += g(rect(-34, -11, 68, 22, "#d8a678", 3.5, rx=10) + rect(-12, -9, 24, 18, "#f0dcc0", 0, rx=3)
           + rect(-3, -7, 6, 14, "#3f9a5e", 0) + rect(-7, -3, 14, 6, "#3f9a5e", 0), "translate(70 140) rotate(-12)")
    s += g(line([(0, 0), (34, 0)], 2.5, STEEL[0]) + path("M34 -3 Q42 0 34 3", "none", 2.5, stroke=STEEL[0]) + rect(-8, -4, 10, 8, STEEL[1], 2.5, rx=2),
           "translate(170 62) rotate(18)")
    return card_art("medkit", s)


def m_first_aid() -> str:
    s = path("M114 40 L114 30 Q114 24 120 24 L160 24 Q166 24 166 30 L166 40", "none", 12, stroke=INK)
    s += path("M114 40 L114 30 Q114 24 120 24 L160 24 Q166 24 166 30 L166 40", "none", 5, stroke="#5c6a62")
    s += rect(78, 40, 124, 104, BONE, 4, rx=12)
    s += rect(78, 82, 124, 20, "#3f9a5e", 0) + rect(78, 40, 124, 104, "none", 4, rx=12)
    s += circ(140, 92, 26, "#3f9a5e") + rect(133, 74, 14, 36, BONE, 0) + rect(122, 85, 36, 14, BONE, 0)
    s += rect(84, 48, 10, 6, BONE_D, 0, rx=2) + rect(186, 48, 10, 6, BONE_D, 0, rx=2)
    s += line([(86, 132), (194, 132)], 3, BONE_D)
    s += path("M90 130 L104 116 L118 130", "none", 2.5, stroke="#8a8270")
    return card_art("medkit", s)


def m_trauma() -> str:
    olive, olive_d = "#4d5a3e", "#38432c"
    s = path("M64 70 Q64 52 82 52 L202 52 Q220 52 220 70 L220 140 Q220 148 212 148 L72 148 Q64 148 64 140 Z", olive)
    s += path("M64 84 L220 84", "none", 3) + rect(64, 52, 156, 32, olive_d, 0, rx=0, extra='opacity="0.5"')
    s += path("M110 52 Q110 30 142 30 Q174 30 174 52", "none", 13, stroke=INK) + path("M110 52 Q110 30 142 30 Q174 30 174 52", "none", 6, stroke="#2e3626")
    s += rect(118, 94, 48, 42, "#3f9a5e", 4, rx=6) + rect(136, 99, 12, 32, BONE, 0) + rect(126, 109, 32, 12, BONE, 0)
    s += line([(80, 84), (80, 148)], 6, olive_d) + line([(204, 84), (204, 148)], 6, olive_d)
    s += rect(74, 66, 14, 10, "#9a9a8a", 3, rx=2) + rect(196, 66, 14, 10, "#9a9a8a", 3, rx=2)
    # tourniquet hanging off the side
    s += path("M220 98 Q238 112 228 140 Q222 156 206 160", "none", 11, stroke=INK)
    s += path("M220 98 Q238 112 228 140 Q222 156 206 160", "none", 6, stroke="#1f2224")
    s += g(rect(-12, -3, 24, 6, "#e0b04a", 3, rx=2), "translate(231 126) rotate(70)")
    return card_art("medkit", s)


# ---------------------------------------------------------------- barricades
def b_plywood() -> str:
    ply, ply_d = "#c9a065", "#9e7a46"
    s = g(rect(-70, -56, 140, 112, ply, 4, rx=2)
          + "".join(path("M-66 %s Q-20 %s 20 %s T66 %s" % (y, y - 6, y + 4, y), "none", 2, stroke=ply_d) for y in (-38, -18, 4, 26, 44))
          + path("M-52 -40 L50 38 M50 -40 L-52 38", "none", 9, stroke="#8a3b2c", extra='opacity="0.9"')
          + "".join(circ(x, y, 3, STEEL[1], 2) for x, y in ((-62, -48), (62, -48), (-62, 48), (62, 48), (0, -48), (0, 48))),
          "translate(140 92) rotate(-6)")
    s += g(rect(-86, -9, 172, 18, WOOD[0], 4, rx=2) + line([(-80, -2), (80, -2)], 2.5, WOOD[1])
           + circ(-74, 0, 3, STEEL[1], 2) + circ(74, 0, 3, STEEL[1], 2), "translate(140 120) rotate(8)")
    return card_art("barricade", s)


def b_car_door() -> str:
    paint, paint_d = "#5a7d8a", "#41606b"
    s = path("M62 74 L84 40 Q90 32 102 32 L188 32 Q198 32 198 42 L198 74 Z", "#2a3236")
    s += path("M74 70 L92 42 L186 42 L186 70 Z", "#9fc3cf", 3)
    s += path("M120 46 L132 58 L126 66 M132 58 L150 52 M132 58 L140 70", "none", 2, stroke="#5f8796")
    s += path("M56 74 L204 74 L204 140 Q204 152 192 152 L70 152 Q56 152 56 138 Z", paint)
    s += line([(60, 96), (200, 96)], 3, paint_d) + rect(150, 104, 30, 9, "#2a3236", 3, rx=4)
    s += ell(98, 128, 14, 9, paint_d, 0) + path("M86 124 Q98 118 110 126", "none", 2.5, stroke="#2f4a54")
    s += circ(176, 136, 5, "#9a5b32", 0) + circ(186, 130, 3, "#9a5b32", 0) + circ(70, 92, 3.5, "#9a5b32", 0)
    s += path("M40 52 L60 50 L62 70 L42 70 Z", "#2a3236")
    return card_art("barricade", s)


def b_dumpster() -> str:
    body, body_d = "#41575e", "#2e4045"
    s = path("M52 66 L216 66 L206 146 L62 146 Z", body)
    s += path("M46 52 L222 52 L218 66 L50 66 Z", body_d)
    s += path("M60 60 L208 60", "none", 2.5, stroke="#5a7279")
    for x in (92, 134, 176):
        s += line([(x, 72), (x - 2, 140)], 3, body_d)
    s += g(poly([(66, 118), (202, 118), (200, 132), (68, 132)], "#e0b04a", 3)
           + "".join(poly([(x, 118), (x + 8, 118), (x - 2, 132), (x - 10, 132)], INK, 0) for x in range(76, 200, 18)))
    s += circ(80, 152, 8, "#262222", 3.5) + circ(188, 152, 8, "#262222", 3.5)
    s += ell(110, 92, 12, 7, "#8a4a2a", 0, extra='opacity="0.8"') + ell(186, 100, 8, 5, "#8a4a2a", 0, extra='opacity="0.8"')
    s += rect(36, 74, 16, 9, body_d, 3, rx=2) + rect(216, 74, 16, 9, body_d, 3, rx=2)
    return card_art("barricade", s)


# ---------------------------------------------------------------- card back (240 x 336)
def card_back() -> str:
    W, H = 240, 336
    defs = radial("bk", "#3a2724", "#141618", 0.5, 0.5, 0.7)
    s = rect(0, 0, W, H, "#141618", 0) + rect(0, 0, W, H, "url(#bk)", 0)
    s += "".join(line([(x, 0), (x - 120, H)], 2, "#1f2326") for x in range(0, W + 140, 14))
    s += rect(10, 10, W - 20, H - 20, "none", 0) + rect(12, 12, W - 24, H - 24, "none", 0)
    s += '<rect x="12" y="12" width="216" height="312" rx="12" fill="none" stroke="%s" stroke-width="4"/>' % BONE_D
    s += '<rect x="22" y="22" width="196" height="292" rx="8" fill="none" stroke="#e2574c" stroke-width="2"/>'
    # crossed boards
    s += g(rect(-96, -11, 192, 22, WOOD[0], 4, rx=2) + circ(-82, 0, 3, STEEL[1], 2) + circ(82, 0, 3, STEEL[1], 2), "translate(120 168) rotate(35)")
    s += g(rect(-96, -11, 192, 22, WOOD[1], 4, rx=2) + circ(-82, 0, 3, STEEL[1], 2) + circ(82, 0, 3, STEEL[1], 2), "translate(120 168) rotate(-35)")
    # emblem: a hand rising out of a card-shaped hole
    s += circ(120, 168, 58, "#3b2321", 5) + circ(120, 168, 50, "none", 0)
    s += '<circle cx="120" cy="168" r="50" fill="none" stroke="#e2574c" stroke-width="3"/>'
    sk = SKIN_Z[0]
    hand_s = (limb([(0, 40), (0, 4)], 18, sk) + path("M-14 6 L-14 -14 Q-14 -22 -8 -22 L8 -22 Q14 -22 14 -14 L14 6 Z", sk)
              + limb([(-10, -20), (-14, -42)], 6, sk, 3.5) + limb([(-2, -22), (-2, -48)], 6, sk, 3.5)
              + limb([(6, -22), (10, -46)], 6, sk, 3.5) + limb([(13, -14), (22, -32)], 6, sk, 3.5)
              + limb([(-14, -2), (-26, -16)], 7, sk, 3.5) + line([(-8, 14), (6, 20)], 2.5, SKIN_Z[1]))
    s += g(hand_s, "translate(120 186) rotate(8)")
    s += path("M84 214 Q120 200 156 214 L150 222 Q120 214 90 222 Z", INK, 0)
    for cx, cy in ((40, 40), (200, 40), (40, 296), (200, 296)):
        s += g(poly([(0, -9), (7, 0), (0, 9), (-7, 0)], "#e2574c", 2.5), "translate(%d %d)" % (cx, cy))
    return svg(W, H, s, defs)


# ---------------------------------------------------------------- survivors (200 x 200 portraits)
def portrait(skin, skin_d, body: str, hair_back: str, hair_front: str, face_extra: str = "", brows=(0, 0)) -> str:
    W = H = 200
    bg, mid, motif, acc = PAL["survivor"]
    defs = radial("pb", mid, bg, 0.5, 0.4, 0.7)
    s = rect(0, 0, W, H, bg, 0) + rect(0, 0, W, H, "url(#pb)", 0)
    s += circ(100, 92, 74, motif, 0) + '<circle cx="100" cy="92" r="74" fill="none" stroke="%s" stroke-width="3" opacity="0.6"/>' % acc
    s += hair_back
    s += body
    s += limb([(100, 140), (100, 116)], 26, skin_d)
    s += ell(100, 92, 32, 38, skin)
    s += ell(68, 96, 6, 10, skin) + ell(132, 96, 6, 10, skin)
    s += ell(100, 92, 32, 38, skin, 0)
    s += path("M82 118 Q100 132 118 118 Q112 128 100 130 Q88 128 82 118 Z", skin_d, 0)
    # face: tired but alive
    s += ell(88, 92, 4.5, 5, INK, 0) + ell(112, 92, 4.5, 5, INK, 0) + circ(89.5, 90.5, 1.4, BONE, 0) + circ(113.5, 90.5, 1.4, BONE, 0)
    s += line([(80, 82 + brows[0]), (94, 80)], 3.5, INK) + line([(106, 80), (120, 82 + brows[1])], 3.5, INK)
    s += path("M100 94 L96 108 L102 108", "none", 2.5, stroke=skin_d)
    s += path("M92 116 Q100 119 108 115", "none", 3)
    s += line([(84, 99), (91, 99)], 1.8, skin_d) + line([(109, 99), (116, 99)], 1.8, skin_d)
    s += face_extra
    s += hair_front
    return svg(W, H, s, defs)


def sv_rosa() -> str:
    skin, skin_d = "#c98f62", "#9c6a44"
    body = (path("M30 200 Q34 150 72 140 L128 140 Q166 150 170 200 Z", "#4a5d6e")
            + path("M86 140 L100 162 L114 140", "none", 4) + rect(122, 160, 26, 14, "#d8d2c2", 3, rx=2)
            + line([(100, 162), (100, 200)], 3, "#33424f") + circ(100, 176, 2.5, BONE_D, 0)
            + g(limb([(-36, 0), (24, 0)], 9, STEEL[1]) + path("M24 -14 L40 -14 L44 -4 L36 -4 L36 4 L44 4 L40 14 L24 14 Z", STEEL[1])
                + path("M-36 -12 A12 12 0 1 0 -36 12 L-40 4 L-40 -4 Z", STEEL[1]), "translate(58 168) rotate(-58)"))
    hair_back = path("M66 86 Q64 44 100 42 Q140 42 136 92 L150 120 Q156 140 142 146 Q144 120 132 104 Z", "#2e211a")
    hair_front = (path("M68 80 Q70 50 100 50 Q130 50 132 80 Q118 66 100 66 Q82 66 68 80 Z", "#2e211a")
                  + path("M66 74 Q100 46 134 74 L134 64 Q100 38 66 64 Z", "#3f8f8a") + path("M132 66 L150 58 L146 74 Z", "#3f8f8a"))
    extra = rect(112, 102, 12, 6, "#e8d8b8", 2, rx=2) + line([(84, 106), (88, 104)], 2, "#7a4a32")
    return portrait(skin, skin_d, body, hair_back, hair_front, extra, (0, 2))


def sv_imani() -> str:
    skin, skin_d = "#7a4a2e", "#5a3420"
    body = (path("M30 200 Q34 150 72 140 L128 140 Q166 150 170 200 Z", "#4f8f7f")
            + path("M84 140 L100 166 L116 140", "#3e7466", 4)
            + path("M76 142 Q70 176 92 184 M124 142 Q130 176 110 184", "none", 7, stroke=INK)
            + path("M76 142 Q70 176 92 184 M124 142 Q130 176 110 184", "none", 3.5, stroke="#9aa6a8")
            + circ(101, 186, 7, STEEL[0], 3.5) + rect(132, 164, 22, 26, "#d8d2c2", 3, rx=2) + rect(138, 170, 4, 12, "#3f9a5e", 0) + rect(134, 174, 12, 4, "#3f9a5e", 0))
    hair_back = path("M58 92 Q50 34 100 30 Q150 34 142 92 Q146 70 136 66 L64 66 Q54 70 58 92 Z", "#1e1714")
    hair_front = (path("M62 84 Q56 40 100 36 Q144 40 138 84 Q134 64 118 60 Q100 70 82 60 Q66 64 62 84 Z", "#1e1714")
                  + '<circle cx="88" cy="92" r="9" fill="none" stroke="%s" stroke-width="3"/>' % INK
                  + '<circle cx="112" cy="92" r="9" fill="none" stroke="%s" stroke-width="3"/>' % INK
                  + line([(97, 92), (103, 92)], 3, INK))
    return portrait(skin, skin_d, body, hair_back, hair_front, "", (2, 0))


def sv_theo() -> str:
    skin, skin_d = "#e0b48a", "#b68866"
    body = (path("M30 200 Q34 150 72 140 L128 140 Q166 150 170 200 Z", "#5b6fb0")
            + path("M84 140 Q100 152 116 140", "none", 4) + line([(100, 150), (100, 200)], 3, "#46578e")
            + path("M60 148 L150 200", "none", 16, stroke=INK) + path("M60 148 L150 200", "none", 9, stroke="#d9a03a")
            + rect(124, 178, 18, 12, "#8a6a2a", 3, rx=2))
    hair_back = path("M66 90 Q64 60 76 56 L124 56 Q136 60 134 90 Z", "#3a2c20")
    hair_front = (path("M66 76 Q66 44 100 42 Q134 44 134 76 Z", "#d9a03a") + path("M128 70 Q150 66 160 76 L134 80 Z", "#b9852a")
                  + rect(66, 70, 68, 8, "#b9852a", 3.5, rx=3) + circ(100, 46, 3.5, "#b9852a", 2)
                  + path("M70 80 Q72 92 74 98 M130 80 Q128 92 126 98", "none", 4, stroke="#3a2c20"))
    extra = path("M118 112 L126 106 M120 116 L128 110", "none", 2, stroke="#b06a50")
    return portrait(skin, skin_d, body, hair_back, hair_front, extra, (-2, 0))


# ---------------------------------------------------------------- districts (480 x 160 banners)
def banner(sky_top, sky_bot, body: str) -> str:
    W, H = 480, 160
    defs = linear("sky", [(0, sky_top), (1, sky_bot)])
    return svg(W, H, rect(0, 0, W, H, "url(#sky)", 0) + body + rect(0, 146, W, 14, INK, 0), defs)


def windows(x, y, cols, rows, dx, dy, lit, off="#1a1d20", w=7, h=9) -> str:
    out = ""
    for c in range(cols):
        for r in range(rows):
            on = ((c * 7 + r * 3 + x) % 5) in (0, 2)
            out += rect(x + c * dx, y + r * dy, w, h, lit if on else off, 0)
    return out


def d_maple_row() -> str:
    s = circ(392, 44, 22, "#f2c48a", 0, extra='opacity="0.85"')
    s += path("M0 120 Q120 108 240 116 T480 112 L480 160 L0 160 Z", "#2b2230")
    for i, (x, w, h, roof) in enumerate(((24, 92, 46, "#3a2a2e"), (176, 104, 54, "#33262e"), (338, 96, 44, "#3a2a2e"))):
        base = 140
        s += rect(x, base - h, w, h, "#4a3a3c", 4)
        s += poly([(x - 8, base - h), (x + w / 2, base - h - 34), (x + w + 8, base - h)], roof)
        s += rect(x + 12, base - h + 12, 18, 16, "#f2c14e" if i != 1 else "#1a1d20", 3)
        s += rect(x + w - 30, base - h + 12, 18, 16, "#1a1d20", 3)
        s += path("M%s %s L%s %s L%s %s" % (x + w - 28, base - h + 14, x + w - 20, base - h + 22, x + w - 14, base - h + 16), "none", 2, stroke="#5a6470")
        s += rect(x + w / 2 - 8, base - 26, 16, 26, "#2a1f22", 3)
    # maple tree
    s += limb([(150, 146), (152, 96)], 10, "#3a2a20")
    for cx, cy, r in ((136, 84, 22), (166, 80, 24), (152, 62, 22), (126, 66, 16), (176, 60, 16)):
        s += circ(cx, cy, r, "#b8542c")
    for cx, cy, r in ((140, 74, 8), (164, 68, 9), (150, 88, 7)):
        s += circ(cx, cy, r, "#d9773a", 0)
    # picket fence
    for x in range(0, 480, 16):
        s += poly([(x + 2, 146), (x + 2, 128), (x + 7, 122), (x + 12, 128), (x + 12, 146)], "#8e8676", 2.5)
    s += rect(0, 132, 480, 5, "#8e8676", 0)
    return banner("#2a2040", "#b0624a", s)


def d_downtown() -> str:
    s = ""
    for x, w, h in ((0, 52, 70), (40, 44, 104), (90, 60, 86), (156, 40, 124), (200, 70, 92), (276, 46, 112), (326, 64, 80), (396, 40, 118), (440, 40, 90)):
        s += rect(x, 146 - h, w, h, "#232a33", 3)
        s += windows(x + 7, 146 - h + 10, max(1, (w - 8) // 12), max(1, (h - 20) // 16), 12, 16, "#e0c070")
    s += rect(176, 8, 4, 16, "#232a33", 0)
    # stalled bus
    s += rect(240, 108, 150, 36, "#d9a03a", 4, rx=6) + rect(248, 114, 120, 14, "#2a3236", 0) + rect(370, 114, 14, 22, "#2a3236", 0)
    s += circ(270, 146, 9, "#1a1d20", 3.5) + circ(360, 146, 9, "#1a1d20", 3.5) + line([(240, 132), (390, 132)], 3, "#a8772a")
    # traffic light
    s += rect(92, 60, 6, 86, "#1a1d20", 0) + rect(84, 40, 22, 46, "#1a1d20", 3.5, rx=4)
    s += circ(95, 50, 5, "#5a2420", 0) + circ(95, 63, 5, "#e0b04a", 0) + circ(95, 76, 5, "#2e4434", 0)
    return banner("#1b2030", "#4a3a52", s)


def d_st_agnes() -> str:
    s = circ(70, 40, 16, "#d8e6e2", 0, extra='opacity="0.7"')
    s += rect(130, 40, 220, 106, "#c9cfc8", 4) + rect(130, 40, 220, 14, "#a9b0a8", 0)
    s += windows(144, 62, 9, 4, 22, 20, "#bfe6d0", "#3d4a48", 12, 12)
    s += rect(220, 112, 40, 34, "#2e3c3a", 4) + rect(214, 104, 52, 10, "#6fb08a", 3)
    s += rect(218, 6, 44, 44, "#3f9a5e", 4, rx=6) + rect(234, 12, 12, 32, BONE, 0) + rect(224, 22, 32, 12, BONE, 0)
    s += rect(80, 90, 52, 56, "#a9b0a8", 4) + rect(348, 80, 70, 66, "#a9b0a8", 4)
    s += windows(88, 100, 3, 2, 14, 18, "#bfe6d0", "#3d4a48", 8, 10) + windows(356, 92, 4, 3, 16, 16, "#bfe6d0", "#3d4a48", 9, 10)
    # ambulance
    s += path("M18 146 L18 112 L74 112 L74 120 L92 122 L100 134 L100 146 Z", BONE)
    s += rect(30, 120, 16, 4, "#3f9a5e", 0) + rect(36, 114, 4, 16, "#3f9a5e", 0) + rect(80, 124, 12, 8, "#2a3236", 0)
    s += circ(36, 146, 8, "#1a1d20", 3.5) + circ(86, 146, 8, "#1a1d20", 3.5)
    # quarantine fence
    for x in range(410, 480, 14):
        s += line([(x, 146), (x + 14, 118)], 2, "#6a7278") + line([(x, 118), (x + 14, 146)], 2, "#6a7278")
    s += poly([(404, 126), (480, 120), (480, 130), (404, 136)], "#e0b04a", 2.5)
    return banner("#18282a", "#3b5a50", s)


# ---------------------------------------------------------------- perk icons (128 x 128)
def perk(body: str) -> str:
    bg, mid, motif, acc = PAL["perk"]
    defs = radial("kb", mid, bg, 0.5, 0.4, 0.7)
    s = circ(64, 64, 60, "url(#kb)", 0) + '<circle cx="64" cy="64" r="58" fill="none" stroke="%s" stroke-width="5"/>' % acc
    s += '<circle cx="64" cy="64" r="51" fill="none" stroke="%s" stroke-width="2" opacity="0.6"/>' % INK
    return svg(128, 128, s + body, defs)


def p_thick_jacket() -> str:
    c, d = "#8a5a36", "#6a4228"
    s = path("M44 34 L54 30 Q64 38 74 30 L84 34 L104 54 L96 66 L88 60 L88 102 L40 102 L40 60 L32 66 L24 54 Z", c)
    s += path("M54 30 L64 50 L74 30", "none", 4) + path("M64 50 L64 102", "none", 3, stroke=INK)
    s += path("M54 30 L48 44 L60 46 Z M74 30 L80 44 L68 46 Z", "#d8c8a8", 3)
    s += rect(46, 72, 12, 8, d, 2.5, rx=2) + rect(70, 72, 12, 8, d, 2.5, rx=2)
    s += path("M40 92 L88 92", "none", 2.5, stroke=d)
    return perk(s)


def p_fire_axe() -> str:
    s = path("M22 92 L22 80 Q24 72 34 70 L94 70 Q104 72 106 80 L106 92 Z", "#46505a")
    s += rect(22, 88, 84, 14, "#2a3236", 3.5, rx=3) + rect(56, 76, 16, 6, "#8e8676", 2)
    s += g(limb([(-38, 0), (30, 0)], 8, "#d9a03a") + path("M22 -8 L36 -8 L36 8 L22 8 Z", "#b5402f")
           + path("M24 8 Q18 26 16 32 Q32 36 44 32 Q38 22 34 8 Z", "#b5402f") + path("M16 32 Q32 36 44 32", "none", 4, stroke=STEEL[0])
           + path("M24 -8 L30 -24 L34 -8 Z", "#8a2f24"), "translate(62 52) rotate(-24)")
    return perk(s)


def p_field_kit() -> str:
    s = rect(18, 56, 92, 10, "#3a3226", 3.5, rx=2)
    s += path("M36 50 Q36 42 44 42 L84 42 Q92 42 92 50 L92 96 Q92 102 86 102 L42 102 Q36 102 36 96 Z", "#4d5a3e")
    s += path("M36 50 Q36 42 44 42 L84 42 Q92 42 92 50 L92 62 L36 62 Z", "#38432c")
    s += circ(64, 60, 3, BONE_D, 2)
    s += rect(58, 70, 12, 26, BONE, 0) + rect(51, 77, 26, 12, BONE, 0)
    s += rect(58, 70, 12, 26, "none", 0)
    return perk(s.replace(BONE, "#6fd08a"))


def p_knuckle_wraps() -> str:
    sk = "#c98f62"
    s = path("M36 60 Q36 44 48 44 L86 44 Q98 44 98 58 L98 84 Q98 100 82 104 L56 104 Q36 100 36 84 Z", sk)
    for y in (52, 64, 76):
        s += path("M38 %d L96 %d" % (y, y - 6), "none", 9, stroke=INK) + path("M38 %d L96 %d" % (y, y - 6), "none", 5, stroke=BONE)
    s += path("M48 44 L48 60 M62 44 L62 58 M76 44 L76 58", "none", 3)
    s += path("M36 82 Q26 76 30 64 Q36 58 44 66 L50 84", sk, 4)
    s += rect(44, 102, 46, 14, BONE, 3.5, rx=2) + line([(54, 104), (58, 114)], 2, BONE_D) + line([(70, 104), (74, 114)], 2, BONE_D)
    return perk(s)


def p_sandbags() -> str:
    bag, bag_d = "#c2a874", "#9a8256"

    def b(cx, cy):
        return (path("M%d %d Q%d %d %d %d Q%d %d %d %d Q%d %d %d %d Q%d %d %d %d Z" % (
            cx - 22, cy, cx - 22, cy - 13, cx, cy - 13, cx + 22, cy - 13, cx + 22, cy, cx + 22, cy + 13, cx, cy + 13, cx - 22, cy + 13, cx - 22, cy), bag)
            + line([(cx - 14, cy - 6), (cx + 14, cy - 6)], 2, bag_d) + line([(cx + 16, cy - 10), (cx + 16, cy + 10)], 2.5, INK))
    s = b(40, 92) + b(86, 92) + b(63, 68) + b(63, 44).replace(bag, "#d0b884")
    return perk(s)


def p_scrounger() -> str:
    pack, pack_d = "#5a6a4a", "#43503a"
    s = g(limb([(-6, 0), (34, 0)], 8, STEEL[0]) + path("M34 -6 L44 -12 L46 -4 L40 0 L46 4 L44 12 L34 6 Z", STEEL[0]), "translate(54 34) rotate(-70)")
    s += g(rect(-8, -16, 16, 30, "#b5402f", 3, rx=3) + rect(-8, -16, 16, 6, "#2a3236", 0), "translate(78 34) rotate(18)")
    s += path("M34 50 Q34 38 50 38 L78 38 Q94 38 94 50 L94 100 Q94 106 88 106 L40 106 Q34 106 34 100 Z", pack)
    s += path("M34 50 Q34 38 50 38 L78 38 Q94 38 94 50 L94 58 Q64 66 34 58 Z", pack_d)
    s += rect(46, 74, 36, 22, pack_d, 3.5, rx=4) + line([(46, 80), (82, 80)], 2.5, INK)
    return perk(s)


def p_second_wind() -> str:
    s = path("M64 100 L32 68 Q20 54 30 40 Q42 28 56 38 L64 46 L72 38 Q86 28 98 40 Q108 54 96 68 Z", "#e2574c")
    s += path("M38 44 Q42 38 50 40", "none", 4, stroke="#f08a7e")
    s += path("M40 66 L54 66 L60 54 L68 80 L74 66 L90 66", "none", 9, stroke=INK)
    s += path("M40 66 L54 66 L60 54 L68 80 L74 66 L90 66", "none", 4.5, stroke=BONE)
    s += path("M14 96 Q34 88 52 98 M84 104 Q100 94 116 100", "none", 4, stroke="#9aa8ff")
    return perk(s)


def p_tripwire() -> str:
    s = limb([(22, 52), (22, 104)], 6, WOOD[0]) + limb([(106, 52), (106, 104)], 6, WOOD[0])
    s += line([(22, 60), (106, 60)], 2.5, STEEL[0])
    for cx in (48, 80):
        s += line([(cx, 60), (cx, 70)], 2, STEEL[0])
        s += rect(cx - 9, 70, 18, 24, "#8e9aa0", 3.5, rx=2) + rect(cx - 9, 76, 18, 10, "#b5402f", 0) + rect(cx - 9, 70, 18, 24, "none", 3.5, rx=2)
    s += path("M60 104 Q64 96 68 104 M40 106 Q44 100 48 106", "none", 3, stroke="#9aa8ff")
    s += line([(14, 104), (114, 104)], 3, INK)
    return perk(s)


# ================================================================ v2 ("Last Stand" waves) art
# Everything below was added for core-rules-v2.md (board task dd-v2-art): guns, the Kitchen Knife,
# ammo cards, carrier drops + carrier badge, the four machines, Jawbreaker buff icons, room door
# tiles, the two new perks and the wave marker. Same style rules as v1. All designs are original.

GUN = ("#4a5258", "#2c3236")
GUN_HI = "#8a979c"
POLYMER = "#2b2a2a"
FURN = ("#5e6a48", "#444e34")        # carbine furniture
BRASS = ("#d6a84a", "#a87d2e")
COPPER = ("#b8693a", "#7d4a22")
CHALK = "#dcd8c8"
SPARK = ("#8ff0ff", "#e8ffff")       # Static Lance arc


def trigger(x, y, w=22, h=18) -> str:
    """Open trigger guard + trigger below a receiver (x = front of the guard)."""
    s = path("M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s" % (
        f(x), f(y), f(x), f(y + h), f(x - w * 0.4), f(y + h), f(x - w * 0.8), f(y + h),
        f(x - w), f(y + h), f(x - w), f(y + h * 0.4)), "none", 5)
    s += line([(x - w * 0.45, y + 1), (x - w * 0.55, y + h * 0.65)], 3.5, INK)
    return s


def bullet(x, y, ang=0.0, sc=1.0, case=BRASS[0], tip=COPPER[0]) -> str:
    """One cartridge, tip up at ang=0, origin at its middle."""
    s = rect(-5, -4, 10, 22, case, 3, rx=1.5) + path("M-5 -4 Q-5 -15 0 -19 Q5 -15 5 -4 Z", tip, 3)
    s += line([(-2, -1), (-2, 14)], 2, "#f0d488") + rect(-6, 16, 12, 3, BRASS[1], 0)
    return g(s, "translate(%s %s) rotate(%s) scale(%s)" % (f(x), f(y), f(ang), f(sc)))


# ---------------------------------------------------------------- v2 guns (local coords, muzzle at +x)
def gun_pistol() -> str:
    s = poly([(-52, -2), (-20, -2), (-24, 54), (-56, 56), (-60, 46)], "#5a4634")
    s += "".join(line([(-50 + d, 10), (-46 + d, 44)], 2.2, "#3f3124") for d in (4, 12, 20))
    s += rect(-62, -10, 116, 16, POLYMER, 4, rx=3) + trigger(-4, 4)
    s += rect(-66, -36, 134, 28, GUN[0], 4, rx=4)
    s += "".join(line([(x, -32), (x, -14)], 2.5, GUN[1]) for x in (-58, -52, -46))
    s += line([(-36, -31), (60, -31)], 3, GUN_HI) + rect(-4, -30, 24, 9, GUN[1], 3, rx=2)
    s += rect(56, -42, 7, 7, GUN[1], 2.5) + rect(-62, -42, 11, 7, GUN[1], 2.5)
    s += rect(68, -30, 8, 15, GUN[1], 3.5, rx=2)
    return g(s, "scale(1.18)")


def gun_revolver() -> str:
    s = path("M-50 -8 Q-56 20 -74 48 Q-80 62 -64 64 L-48 64 Q-40 38 -28 4 Z", WOOD[0])
    s += line([(-58, 30), (-50, 12)], 2.5, WOOD[1]) + circ(-56, 40, 3, BONE_D, 2)
    s += path("M-58 -30 L-28 -30 L-28 6 L-50 6 Z", GUN[0]) + trigger(-26, 4, 20, 18)
    s += path("M-56 -28 L-70 -44 L-62 -48 L-48 -32 Z", GUN[1], 3.5)
    s += rect(-28, -36, 46, 40, GUN[1], 4, rx=7)
    s += "".join(line([(x, -30), (x, -2)], 3, "#1b1f22") for x in (-18, -5, 8))
    s += rect(18, -14, 64, 8, GUN[1], 3.5, rx=2)
    s += rect(18, -32, 100, 18, GUN[0], 4, rx=2) + line([(22, -27), (112, -27)], 3, GUN_HI)
    s += poly([(108, -32), (114, -40), (118, -32)], GUN[1], 3)
    return s


def gun_smg() -> str:
    s = line([(-50, -20), (-98, -20), (-98, 2), (-50, 2)], 11, INK) + line([(-50, -20), (-98, -20), (-98, 2), (-50, 2)], 5, GUN[1])
    s += poly([(-40, -2), (-20, -2), (-24, 40), (-46, 40)], POLYMER) + trigger(-14, 2, 18, 16)
    s += poly([(-6, -2), (14, -2), (16, 70), (-4, 70)], POLYMER) + rect(-8, 66, 26, 8, GUN[1], 3, rx=2)
    s += line([(4, 6), (5, 60)], 2.5, "#4a4848")
    s += rect(-56, -34, 112, 32, GUN[0], 4, rx=4) + line([(-50, -29), (50, -29)], 3, GUN_HI)
    s += rect(-40, -42, 64, 8, GUN[1], 3, rx=1) + rect(30, -2, 10, 22, POLYMER, 3.5, rx=3)
    s += rect(56, -30, 34, 22, GUN[1], 4, rx=3) + "".join(circ(x, -19, 3, "#151214", 0) for x in (64, 73, 82))
    s += rect(90, -25, 10, 12, GUN[0], 3.5, rx=1)
    return s


def gun_shotgun() -> str:
    s = path("M-120 -12 L-50 -22 L-46 4 L-62 10 Q-92 22 -122 32 Q-128 10 -120 -12 Z", WOOD[0])
    s += line([(-112, 12), (-62, 2)], 3, WOOD[1]) + rect(-126, -14, 8, 46, "#2b2a2a", 3.5, rx=2)
    s += rect(-52, -26, 56, 30, GUN[0], 4, rx=4) + trigger(-26, 4, 20, 18)
    s += rect(4, -10, 100, 10, GUN[1], 3.5, rx=3)
    s += rect(2, -24, 120, 12, GUN[0], 4, rx=2) + line([(8, -20), (116, -20)], 2.5, GUN_HI)
    s += rect(18, -14, 50, 20, WOOD[0], 4, rx=7) + "".join(line([(x, -10), (x, 2)], 2.5, WOOD[1]) for x in (28, 36, 44, 52, 60))
    s += circ(119, -26, 2.8, BONE_D, 2)
    return s


def gun_rifle() -> str:
    s = path("M-122 -10 L-40 -18 L-32 4 L-52 8 Q-86 16 -122 30 Q-128 8 -122 -10 Z", WOOD[0])
    s += path("M-96 -12 Q-72 -24 -50 -16", "none", 3, stroke=WOOD[1]) + line([(-112, 14), (-60, 6)], 2.5, WOOD[1])
    s += path("M-34 -14 L64 -12 L60 2 L-34 6 Z", WOOD[0])
    s += rect(-40, -20, 160, 8, GUN[0], 3.5, rx=2) + trigger(-26, 4, 18, 16)
    s += rect(-44, -24, 40, 14, GUN[1], 3.5, rx=2)
    s += limb([(-30, -16), (-24, 2)], 4, GUN[1], 3) + circ(-24, 4, 5, GUN[1], 3)
    s += rect(-36, -36, 6, 10, GUN[1], 3) + rect(8, -36, 6, 10, GUN[1], 3)
    s += rect(-46, -46, 72, 13, GUN[1], 4, rx=6)
    s += rect(-54, -50, 12, 21, GUN[0], 3.5, rx=3) + rect(22, -50, 14, 21, GUN[0], 3.5, rx=3)
    s += line([(-40, -43), (18, -43)], 2.5, GUN_HI) + ell(36, -39.5, 2, 6, "#9fd8ff", 0)
    return g(s, "scale(0.94)")


def gun_carbine() -> str:
    s = rect(-112, -24, 40, 30, FURN[0], 4, rx=5) + line([(-106, -12), (-80, -12)], 2.5, FURN[1])
    s += rect(-74, -18, 26, 12, GUN[1], 3.5, rx=2)
    s += path("M-14 -4 L6 -4 Q8 30 22 56 L2 64 Q-12 34 -14 -4 Z", GUN[1])
    s += poly([(-46, -4), (-28, -4), (-34, 36), (-52, 34)], POLYMER) + trigger(-18, 0, 16, 16)
    s += rect(-52, -28, 64, 26, GUN[0], 4, rx=3) + line([(-46, -23), (8, -23)], 3, GUN_HI)
    s += rect(-44, -36, 52, 8, GUN[1], 3, rx=1) + rect(-40, -44, 10, 8, GUN[1], 3)
    s += rect(10, -28, 64, 22, FURN[0], 4, rx=4) + "".join(rect(x, -22, 8, 4, FURN[1], 0, rx=1.5) for x in (18, 32, 46, 60))
    s += rect(74, -22, 36, 9, GUN[0], 3.5, rx=1) + poly([(80, -22), (86, -38), (92, -22)], GUN[1], 3)
    s += rect(108, -25, 10, 15, GUN[1], 3.5, rx=2)
    return s


def gun_lmg() -> str:
    s = limb([(68, -8), (50, 54)], 5, GUN[1], 3) + limb([(72, -8), (92, 54)], 5, GUN[1], 3)
    s += path("M-120 -22 L-70 -28 L-70 8 L-120 16 Q-126 -4 -120 -22 Z", POLYMER)
    s += poly([(-60, 2), (-40, 2), (-44, 40), (-64, 40)], POLYMER) + trigger(-30, 4, 18, 16)
    s += rect(-74, -36, 80, 40, GUN[0], 4, rx=4) + rect(-64, -46, 56, 12, GUN[1], 3.5, rx=2)
    s += line([(-66, -30), (0, -30)], 3, GUN_HI)
    s += path("M8 -28 Q24 -52 42 -28", "none", 9) + path("M8 -28 Q24 -52 42 -28", "none", 4, stroke=GUN[1])
    s += rect(6, -28, 84, 22, GUN[1], 4, rx=3) + "".join(circ(x, -17, 3.5, "#151214", 0) for x in range(16, 86, 12))
    s += rect(90, -23, 30, 12, GUN[0], 3.5, rx=1) + rect(118, -26, 8, 18, GUN[1], 3.5, rx=2)
    # hanging brass belt: the one saturated prop colour
    belt = [(-66 + 6 * t, 8 + 54 * math.sin(min(t, 9) / 9 * math.pi / 2) - (t - 9) * 1.2 * (t > 9)) for t in range(0, 14)]
    for i, (x, y) in enumerate(belt[1:], 1):
        px, py = belt[i - 1]
        ang = math.degrees(math.atan2(y - py, x - px)) - 90
        s += bullet(x, y + 10, ang, 0.62)
    return s


def gun_lance() -> str:
    """Static Lance: a jury-rigged shock pike (car battery, jumper leads, copper coil, two prongs).
    Deliberately not a sci-fi pistol: a farm-shed prototype on a wooden pole."""
    s = circ(114, 0, 22, SPARK[0], 0, extra='opacity="0.28"') + circ(114, 0, 12, SPARK[0], 0, extra='opacity="0.35"')
    s += limb([(-120, 0), (-4, 0)], 12, WOOD[0])
    s += rect(-108, -9, 12, 18, "#9aa0a0", 3, rx=2) + rect(-62, -9, 10, 18, "#9aa0a0", 3, rx=2)
    s += path("M-62 22 Q-40 34 -14 22 Q-4 16 0 8", "none", 9) + path("M-62 22 Q-40 34 -14 22 Q-4 16 0 8", "none", 4, stroke="#b5402f")
    s += rect(-92, 10, 44, 30, "#2f3a33", 4, rx=3) + rect(-92, 10, 44, 9, "#3e4c43", 3, rx=2)
    s += rect(-86, 4, 8, 7, "#b5402f", 2.5) + rect(-62, 4, 8, 7, "#55636a", 2.5)
    s += rect(-4, -14, 9, 28, BONE, 3.5, rx=2)
    s += rect(5, -10, 64, 20, COPPER[0], 4, rx=3) + "".join(line([(x, -9), (x + 6, 9)], 2.2, COPPER[1]) for x in range(8, 64, 6))
    s += rect(68, -14, 9, 28, BONE, 3.5, rx=2)
    s += limb([(76, -5), (96, -16), (114, -18)], 4, STEEL[0], 3) + limb([(76, 5), (96, 16), (114, 18)], 4, STEEL[0], 3)
    arc = [(114, -18), (108, -9), (118, -3), (109, 4), (117, 10), (114, 18)]
    s += line(arc, 7, SPARK[0]) + line(arc, 2.5, SPARK[1])
    s += line([(122, -12), (130, -16)], 2.5, SPARK[0]) + line([(122, 12), (129, 18)], 2.5, SPARK[0]) + line([(124, 0), (133, 1)], 2.5, SPARK[0])
    return s


def w_knife() -> str:
    s = path("M-10 -12 L66 -12 Q94 -10 108 -2 Q84 14 -10 12 Z", STEEL[0])
    s += path("M-6 6 L80 6 Q96 4 104 -1", "none", 2.5, stroke=STEEL[1]) + line([(-2, -6), (70, -6)], 3, "#e6eeeb")
    s += rect(-16, -14, 8, 28, STEEL[1], 3.5, rx=2)
    s += rect(-78, -11, 64, 22, POLYMER, 4, rx=8) + "".join(circ(x, 0, 3, BONE_D, 0) for x in (-64, -46, -28))
    return weapon_card(g(s, "scale(0.92)"), -30, 128, 98)


GUNS_V2 = {  # file id: (body maker, rotation, cx, cy, display name, sim id)
    "weapon_service_pistol": (gun_pistol, -10, 150, 102, "Service Pistol", "pistol"),
    "weapon_revolver": (gun_revolver, -10, 140, 104, "Revolver", "revolver"),
    "weapon_compact_smg": (gun_smg, -10, 146, 96, "Compact SMG", "smg"),
    "weapon_pump_shotgun": (gun_shotgun, -12, 132, 112, "Pump Shotgun", "shotgun"),
    "weapon_hunting_rifle": (gun_rifle, -12, 130, 114, "Hunting Rifle", "rifle"),
    "weapon_carbine": (gun_carbine, -12, 134, 106, "Carbine", "carbine"),
    "weapon_belt_fed_mg": (gun_lmg, -10, 132, 104, "Belt-fed MG", "lmg"),
    "weapon_static_lance": (gun_lance, -14, 118, 108, "Static Lance", "lance"),
}


def gun_card(fid: str) -> str:
    maker, rot, cx, cy, _n, _i = GUNS_V2[fid]
    return weapon_card(g(maker(), "scale(0.9)"), rot, cx, cy)  # 0.9 keeps stocks out of the number zone


# ---------------------------------------------------------------- new kinds: palette + motifs
PAL.update({
    "ammo":    ("#17302f", "#24494a", "#122524", "#4fd1c5"),   # stencil teal: reserve ammo cards
    "drop":    ("#302a17", "#4f4524", "#26210f", "#f2d65c"),   # carrier gold: drops + carrier badge
    "machine": ("#2a2420", "#463a30", "#211c19", "#d9a066"),   # workshop copper: machine cards
    "room":    ("#22282c", "#38424a", "#1a1f22", "#b8c4c0"),   # = district: door tiles
    "jawbreaker": ("#1e1a26", "#332c40", "#16131c", "#f08cc0"),
})


def motif_ammo(m: str) -> str:     # stencilled crate slats
    out = "".join(rect(0, y, CW, 3, m, 0) for y in range(10, GROUND, 24))
    return out + "".join(rect(x, 0, 3, GROUND, m, 0) for x in range(30, CW, 60))


def motif_drop(m: str) -> str:     # sunburst rays from behind the subject
    out = ""
    cx, cy = 150, 96
    for i in range(0, 16, 2):
        a1, a2 = i * math.pi / 8, (i + 1) * math.pi / 8
        out += poly([(cx, cy), (cx + math.cos(a1) * 260, cy + math.sin(a1) * 260), (cx + math.cos(a2) * 260, cy + math.sin(a2) * 260)], m, 0)
    return out


def motif_machine(m: str) -> str:  # tiled back wall
    out = ""
    for r, y in enumerate(range(0, GROUND, 26)):
        for x in range((r % 2) * -16, CW, 32):
            out += rect(x + 1.5, y + 1.5, 29, 23, m, 0, rx=1)
    return out


MOTIFS.update({"ammo": motif_ammo, "drop": motif_drop, "machine": motif_machine})


# ---------------------------------------------------------------- ammo cards
def a_box() -> str:
    tan, tan_d = "#b89a66", "#8a7044"
    s = poly([(58, 80), (40, 58), (70, 54), (86, 80)], tan_d, 3.5) + poly([(192, 80), (214, 62), (220, 86), (196, 92)], tan_d, 3.5)
    s += poly([(62, 80), (190, 80), (196, 94), (56, 94)], "#3a2c1c", 3.5)
    for i, x in enumerate(range(74, 182, 14)):
        s += bullet(x, 78 - (i % 2) * 3, 0, 0.9)
    s += poly([(56, 94), (196, 94), (190, 152), (62, 152)], tan)
    s += rect(108, 94, 34, 58, tan_d, 0, extra='opacity="0.55"') + line([(56, 94), (196, 94)], 4, INK)
    s += path("M78 112 L78 136 L90 136 L90 112 Q84 102 78 112 Z", "#6b5434", 0) + path("M160 112 L160 136 L172 136 L172 112 Q166 102 160 112 Z", "#6b5434", 0)
    s = g(s, "translate(24 20) scale(0.86)")
    s += bullet(222, 150, 84, 0.85) + bullet(66, 154, -76, 0.85)
    return card_art("ammo", s)


def a_can() -> str:
    od, od_d = "#5b6440", "#434a2e"
    s = rect(66, 76, 132, 80, od, 4, rx=5) + rect(66, 76, 132, 14, od_d, 0)
    s += rect(60, 62, 144, 18, od_d, 4, rx=4) + path("M104 62 Q132 36 160 62", "none", 10) + path("M104 62 Q132 36 160 62", "none", 4, stroke=STEEL[1])
    s += rect(196, 84, 14, 40, STEEL[1], 3.5, rx=3) + rect(78, 104, 108, 10, "#d8c8a8", 0, extra='opacity="0.55"')
    s += line([(72, 140), (192, 140)], 2.5, od_d)
    for i in range(7):
        s += bullet(70 + i * 15, 66 + (i % 2) * 2, 90, 0.8)
    s = g(s, "translate(18 10) scale(0.92)")
    s += bullet(60, 150, -70, 0.85) + bullet(226, 152, 80, 0.85) + bullet(218, 138, 64, 0.85)
    return card_art("ammo", s)


# ---------------------------------------------------------------- carrier drops (shown when a Carrier dies)
def satchel(sc=1.0, open_=False) -> str:
    kh, kh_d = "#9a8656", "#76653e"
    s = path("M-30 -16 Q0 -66 30 -16", "none", 9) + path("M-30 -16 Q0 -66 30 -16", "none", 4, stroke=kh_d)
    s += path("M-36 -18 L36 -18 L40 26 Q40 34 32 34 L-32 34 Q-40 34 -40 26 Z", kh)
    if open_:
        s += path("M-36 -18 L36 -18 L30 -32 L-30 -32 Z", kh_d)
    else:
        s += path("M-36 -18 L36 -18 L32 8 Q0 14 -32 8 Z", kh_d)
        s += rect(-6, 2, 12, 12, BRASS[0], 3, rx=2)
    s += line([(-28, 24), (28, 24)], 2.5, kh_d)
    return g(s, "scale(%s)" % f(sc))


def star(cx, cy, r, fill, sw=3) -> str:
    p = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        p.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return poly(p, fill, sw)


def d_full_load() -> str:
    mag = "M-14 -40 L14 -40 Q16 6 30 44 L4 52 Q-12 10 -14 -40 Z"
    one = path(mag, GUN[1]) + line([(-6, -30), (-2, 10)], 3, GUN_HI) + bullet(0, -46, 0, 0.8)
    s = g(one, "translate(136 98) rotate(-10)") + g(one, "translate(166 96) rotate(8)")
    s += rect(122, 76, 64, 14, "#9aa0a0", 3.5, rx=2) + rect(124, 112, 64, 14, "#9aa0a0", 3.5, rx=2)
    s += bullet(98, 146, -70, 0.9) + bullet(212, 140, 76, 0.9) + bullet(222, 120, 58, 0.8) + bullet(90, 120, -40, 0.8)
    return card_art("drop", s)


def d_payday() -> str:
    tk, tk_d = "#e8b0b8", "#b9828c"
    s = g(satchel(1.25, open_=True), "translate(124 112)")
    strip = [(118, 74), (140, 52), (170, 50), (196, 70), (206, 100), (214, 130)]
    for i in range(len(strip) - 1):
        (x1, y1), (x2, y2) = strip[i], strip[i + 1]
        ang = math.degrees(math.atan2(y2 - y1, x2 - x1))
        s += g(rect(-15, -9, 30, 18, tk, 3, rx=1) + circ(-15, 0, 3, tk_d, 0) + circ(15, 0, 3, tk_d, 0) + star(0, 0, 5, tk_d, 0),
               "translate(%s %s) rotate(%s)" % (f((x1 + x2) / 2), f((y1 + y2) / 2), f(ang)))
    s += star(86, 140, 12, BRASS[0]) + star(206, 150, 10, BRASS[0]) + star(176, 30, 9, BRASS[0])
    return card_art("drop", s)


def d_boards() -> str:
    s = ""
    for i, (y, rot) in enumerate(((118, -8), (100, -4), (82, 2))):
        s += g(rect(-78, -10, 156, 20, WOOD[0] if i != 1 else "#b8875a", 4, rx=2) + line([(-70, -2), (66, -2)], 2.5, WOOD[1])
               + circ(-66, 3, 2.6, STEEL[1], 0) + circ(66, 3, 2.6, STEEL[1], 0), "translate(146 %s) rotate(%s)" % (y, rot))
    s += line([(104, 72), (110, 132)], 9, INK) + line([(104, 72), (110, 132)], 4, "#c9b98a")
    s += line([(184, 70), (180, 130)], 9, INK) + line([(184, 70), (180, 130)], 4, "#c9b98a")
    s += g(limb([(-40, 0), (26, 0)], 10, WOOD[0]) + path("M20 -12 L40 -12 L40 16 L20 16 Z", STEEL[0]) + path("M22 -12 Q20 -28 10 -36 L18 -38 Q30 -26 32 -12 Z", STEEL[1]),
           "translate(84 148) rotate(-14)")
    for x, y, a in ((196, 150, 30), (210, 146, -20), (220, 154, 70)):
        s += g(line([(0, -9), (0, 9)], 3, STEEL[1]) + rect(-4, -11, 8, 3, STEEL[1], 0), "translate(%s %s) rotate(%s)" % (x, y, a))
    return card_art("drop", s)


# ---------------------------------------------------------------- badges (64 x 64, transparent, overlay on a card)
def badge_disc(ring: str) -> str:
    return circ(32, 32, 29, INK, 0) + '<circle cx="32" cy="32" r="27" fill="none" stroke="%s" stroke-width="4"/>' % ring


def badge_carrier_body() -> str:
    return badge_disc(PAL["drop"][3]) + g(satchel(0.52), "translate(32 35)") + star(48, 16, 5.5, PAL["drop"][3], 2)


def badge_carrier() -> str:
    return svg(64, 64, badge_carrier_body())


def badge_locked() -> str:
    s = badge_disc(PAL["room"][3])
    s += g(rect(-24, -5, 48, 10, WOOD[0], 2.5, rx=1), "translate(32 33) rotate(-30)") + g(rect(-24, -5, 48, 10, WOOD[1], 2.5, rx=1), "translate(32 33) rotate(30)")
    s += path("M23 30 L23 22 Q23 12 32 12 Q41 12 41 22 L41 30", "none", 8) + path("M23 30 L23 22 Q23 12 32 12 Q41 12 41 22 L41 30", "none", 3.5, stroke=STEEL[0])
    s += rect(19, 28, 26, 22, BRASS[0], 3, rx=3) + circ(32, 36, 3, INK, 0) + rect(31, 37, 2.5, 7, INK, 0)
    return svg(64, 64, s)


def badge_retrofit() -> str:
    """Brass plate for a Retrofit weapon. No letter baked in (no text in SVGs): a gear emblem instead;
    the UI may add the "R" as a label on top."""
    s = badge_disc(BRASS[0])
    s += rect(12, 20, 40, 24, BRASS[0], 3, rx=4) + "".join(circ(x, y, 1.8, BRASS[1], 0) for x in (17, 47) for y in (25, 39))
    teeth = "".join(g(rect(-2.5, -11, 5, 5, BRASS[1], 0), "rotate(%d)" % a) for a in range(0, 360, 45))
    s += g(teeth + circ(0, 0, 7.5, BRASS[1], 0) + circ(0, 0, 3, BRASS[0], 0), "translate(32 32)")
    return svg(64, 64, s)


def carrier_variant(card_svg: str) -> str:
    """Bake the carrier badge into a zombie card: bottom-left of the art window (ground, never the
    number safe zone, never the zombie's head)."""
    return card_svg.replace("\n</svg>", g(badge_carrier_body(), "translate(6 114) scale(0.84)") + "\n</svg>")


# ---------------------------------------------------------------- machines (240 x 180 cards)
def mc_retrofit() -> str:
    s = "".join(circ(x, y, 2.2, "#3a302a", 0) for x in range(112, 236, 14) for y in range(18, 72, 14))
    s += g(limb([(-26, 0), (14, 0)], 6, STEEL[1], 3) + circ(20, 0, 8, "none", 0) + path("M14 -8 L26 -8 L26 8 L14 8", "none", 5, stroke=STEEL[1]), "translate(150 40) rotate(-20)")
    s += path("M196 26 L226 26 L226 34 Q212 46 196 34 Z", "#6d7b80", 3)
    s += limb([(52, 112), (50, GROUND + 6)], 10, WOOD[1]) + limb([(214, 112), (216, GROUND + 6)], 10, WOOD[1])
    s += rect(36, 102, 196, 16, WOOD[0], 4, rx=2) + line([(42, 108), (226, 108)], 2.5, WOOD[1])
    s += rect(110, 70, 34, 32, "#5a6e5e", 4, rx=3) + rect(186, 78, 22, 24, "#5a6e5e", 4, rx=3)
    s += limb([(144, 86), (186, 86)], 7, STEEL[0], 3) + rect(156, 80, 14, 12, STEEL[1], 3, rx=2)
    s += circ(126, 72, 20, "none", 8) + '<circle cx="126" cy="72" r="20" fill="none" stroke="%s" stroke-width="3.5"/>' % GUN_HI
    s += line([(126, 72), (126, 52)], 4, STEEL[1]) + limb([(126, 52), (110, 46)], 5, WOOD[0], 3)
    s += path("M58 80 L58 100 Q58 104 62 104 L88 104 Q92 104 92 100 L92 80 Z", "#a8c4c8", 3.5, extra='fill-opacity="0.5"')
    s += rect(56, 74, 38, 8, "#6d7b80", 3, rx=2)
    for x, y in ((64, 96), (74, 90), (84, 97), (68, 88), (82, 88), (76, 98)):
        s += g(rect(-4, -2, 8, 4, STEEL[1], 0) + circ(0, 0, 2.2, STEEL[0], 0), "translate(%d %d) rotate(%d)" % (x, y, x * 7))
    return card_art("machine", s)


def mc_grin() -> str:
    """Grin Machine: an original candy cabinet. A tall tin kiosk whose face IS the dispenser: dome
    head full of jawbreakers, two bolt eyes, a toothy grin for a chute, a crank for an ear."""
    tin, tin_d, trim = "#4f8f88", "#386a65", "#e8dcc0"
    s = rect(110, 128, 90, 30, tin_d, 4, rx=4) + rect(104, 150, 102, 10, INK, 0)
    s += path("M114 74 L196 74 L190 132 L120 132 Z", tin)
    s += path("M114 74 L196 74 L194 88 L116 88 Z", tin_d, 0) + line([(114, 74), (196, 74)], 4, INK)
    s += path("M126 94 Q155 126 184 94 Q182 118 155 122 Q128 118 126 94 Z", INK, 3)
    s += "".join(poly([(x, 97 + (x - 126) * 0.1), (x + 7, 98 + (x - 126) * 0.12), (x + 3.5, 106)], trim, 0) for x in range(130, 178, 9))
    s += circ(134, 82, 4.5, STEEL[0], 3) + circ(176, 82, 4.5, STEEL[0], 3)
    s += path("M118 74 Q118 18 155 16 Q192 18 192 74 Z", "#cfe6ec", 0, extra='opacity="0.35"')
    candies = [(132, 62, "#e77fae"), (148, 66, "#4f9ad8"), (166, 64, "#e6b83a"), (180, 66, "#9b6cd0"), (140, 50, "#8fd6c0"),
               (158, 50, "#e77fae"), (174, 50, "#7c8aa0"), (150, 36, "#e6b83a"), (166, 34, "#4f9ad8"), (128, 70, "#9b6cd0")]
    s += "".join(circ(x, y, 7.5, c, 2.5) for x, y, c in candies)
    s += path("M118 74 Q118 18 155 16 Q192 18 192 74 Z", "none", 4)
    s += path("M128 40 Q136 26 150 22", "none", 4, stroke="#f4fbfc", extra='opacity="0.8"')
    s += line([(170, 22), (176, 34), (172, 42), (182, 52)], 2.5, INK) + line([(176, 34), (186, 36)], 2, INK)
    s += rect(150, 8, 10, 10, tin_d, 3.5, rx=2)
    s += circ(200, 96, 7, tin_d, 3.5) + limb([(200, 96), (214, 80)], 5, STEEL[0], 3) + circ(214, 78, 6, "#b5402f", 3)
    s += circ(110, 144, 5, "#e77fae", 2.5) + circ(96, 152, 5, "#4f9ad8", 2.5)
    return card_art("machine", s)


def mc_locker() -> str:
    body, body_d = "#7a8f5a", "#5c6d42"
    s = rect(116, 16, 84, 142, body_d, 4, rx=3) + rect(122, 22, 72, 132, body, 4, rx=2)
    s += "".join(rect(140, y, 36, 3.5, INK, 0, rx=1.5) for y in (32, 40, 48))
    s += path("M132 88 Q144 94 140 108", "none", 3, stroke=body_d) + path("M170 120 Q182 116 186 128", "none", 3, stroke=body_d)
    s += rect(178, 76, 8, 30, STEEL[1], 3, rx=3)
    s += path("M168 96 L168 88 Q168 80 175 80 Q182 80 182 88 L182 96", "none", 7) + path("M168 96 L168 88 Q168 80 175 80 Q182 80 182 88 L182 96", "none", 3, stroke=STEEL[0])
    s += rect(164, 94, 22, 18, BRASS[0], 3, rx=3) + circ(175, 101, 2.5, INK, 0) + rect(174, 102, 2, 6, INK, 0)
    s += line([(192, 84), (200, 80)], 2.5, BONE) + line([(192, 100), (202, 102)], 2.5, BONE) + line([(158, 90), (152, 86)], 2.5, BONE)
    s += star(138, 66, 9, "#e6b83a", 2.5) + circ(150, 134, 8, "#e77fae", 2.5) + circ(150, 134, 3, BONE, 0)
    s += poly([(136, 114), (128, 128), (134, 128), (130, 140), (142, 124), (136, 124), (140, 114)], "#4fd1c5", 2.5)
    s += rect(178, 128, 12, 16, "#ece6d6", 2.5, rx=1, extra='transform="rotate(12 184 136)"')
    return card_art("machine", s)


def silhouette(body: str, color: str, grow: float) -> str:
    """Flatten a drawing to one colour (fills + strokes), widening every stroke by `grow`."""
    out = re.sub(r'stroke-width="([\d.]+)"', lambda m: 'stroke-width="%s"' % f(float(m.group(1)) + grow), body)
    out = re.sub(r'fill="#[0-9a-fA-F]{6}"', 'fill="%s"' % color, out)
    out = re.sub(r'stroke="#[0-9a-fA-F]{6}"', 'stroke="%s"' % color, out)
    return out.replace('opacity="0.28"', 'opacity="0"').replace('opacity="0.35"', 'opacity="0"')


WALL_BOARD = ("#26302b", "#1c2420")


def wallrack(gun_maker=None, sc: float = 0.74) -> str:
    """Wall Rack: a chalk-outlined gun on a board. Empty outline = the generic machine card."""
    s = rect(26, 30, 208, 112, WALL_BOARD[0], 4, rx=4) + rect(26, 30, 208, 112, "none", 0)
    s += "".join(line([(x, 36), (x - 30, 136)], 2, WALL_BOARD[1]) for x in range(60, 240, 34))
    s += circ(40, 44, 3, STEEL[1], 2) + circ(220, 44, 3, STEEL[1], 2) + circ(40, 128, 3, STEEL[1], 2) + circ(220, 128, 3, STEEL[1], 2)
    body = (gun_maker or gun_carbine)()
    place = "translate(136 88) scale(%g)" % sc
    s += g(silhouette(body, CHALK, 10), place, opacity=0.9)
    if gun_maker is None:
        s += g(silhouette(body, WALL_BOARD[0], 0), place)
        s += g(line([(-90, 30), (-70, 38)], 3, CHALK) + line([(60, 34), (84, 26)], 3, CHALK), place, opacity=0.6)
    else:
        s += g(body, place)
    for x in (104, 172):
        s += path("M%d 58 L%d 68 Q%d 76 %d 70" % (x, x, x + 6, x + 8), "none", 7) + path("M%d 58 L%d 68 Q%d 76 %d 70" % (x, x, x + 6, x + 8), "none", 3, stroke=STEEL[0])
    s += line([(34, 150), (226, 150)], 4, WOOD[1])
    return card_art("machine", s, ground=False)


MACHINES = {  # file id: (maker, sim kind, display name)
    "machine_retrofit_bench": (mc_retrofit, "retrofit", "Retrofit Bench"),
    "machine_grin_machine": (mc_grin, "grin", "Grin Machine"),
    "machine_lucky_locker": (mc_locker, "locker", "Lucky Locker"),
    "machine_wall_rack": (lambda: wallrack(None), "wallrack", "Wall Rack"),
}
WALLRACKS = {  # sim weapon id -> (file id, gun maker, gun name)
    "smg": ("machine_wall_rack_compact_smg", gun_smg, "Compact SMG"),
    "shotgun": ("machine_wall_rack_pump_shotgun", gun_shotgun, "Pump Shotgun"),
    "carbine": ("machine_wall_rack_carbine", gun_carbine, "Carbine"),
}


# ---------------------------------------------------------------- Jawbreakers (128 x 128 round buff icons)
def jawbreaker(candy: str, shade: str, symbol: str) -> str:
    bg, mid, _m, _a = PAL["jawbreaker"]
    defs = radial("jb", mid, bg, 0.5, 0.4, 0.7)
    s = circ(64, 64, 60, "url(#jb)", 0) + '<circle cx="64" cy="64" r="57" fill="none" stroke="%s" stroke-width="6"/>' % candy
    s += "".join(rect(-3, -62, 6, 7, INK, 0, extra='transform="translate(64 64) rotate(%d)"' % a) for a in range(0, 360, 30))
    s += circ(64, 66, 40, candy)
    s += path("M98 56 Q104 92 72 104 Q100 96 98 56 Z", shade, 0) + path("M30 78 Q44 104 74 104 Q40 108 30 78 Z", shade, 0)
    s += ell(48, 46, 12, 7, "#ffffff", 0, rot=-30, extra='opacity="0.55"')
    s += circ(64, 66, 40, "none")
    return svg(128, 128, s + symbol, defs)


def jb_thick_skin() -> str:
    sym = path("M64 46 L84 54 Q84 78 64 90 Q44 78 44 54 Z", BONE, 4) + path("M64 52 L64 84", "none", 3, stroke=BONE_D)
    return jawbreaker("#8b96ab", "#66708a", sym)


def jb_steady_aim() -> str:
    sym = circ(64, 68, 18, "none", 5) + line([(64, 42), (64, 56)], 5, INK) + line([(64, 80), (64, 94)], 5, INK)
    sym += line([(38, 68), (52, 68)], 5, INK) + line([(76, 68), (90, 68)], 5, INK) + circ(64, 68, 4, BONE, 2.5)
    return jawbreaker("#4f9ad8", "#3a74a8", sym)


def jb_sleight() -> str:
    sym = path("M46 62 Q50 44 70 46", "none", 9) + path("M46 62 Q50 44 70 46", "none", 4.5, stroke=BONE)
    sym += poly([(68, 38), (80, 47), (68, 55)], BONE, 3)
    sym += path("M82 72 Q78 90 58 88", "none", 9) + path("M82 72 Q78 90 58 88", "none", 4.5, stroke=BONE)
    sym += poly([(60, 80), (48, 89), (60, 96)], BONE, 3)
    return jawbreaker("#9b6cd0", "#7650a6", sym)


def jb_payday() -> str:
    return jawbreaker("#e6b83a", "#b58a22", star(54, 70, 15, BONE, 3.5) + star(78, 62, 11, BONE, 3))


def jb_sugar_rush() -> str:
    sym = path("M64 92 Q38 74 42 58 Q46 46 58 50 Q62 52 64 58 Q66 52 70 50 Q82 46 86 58 Q90 74 64 92 Z", BONE, 4)
    return jawbreaker("#e77fae", "#b85a86", sym)


def jb_light_step() -> str:
    def sole(x, y, a):
        return g(ell(0, -6, 7, 11, BONE, 3) + ell(0, 12, 5.5, 6, BONE, 3), "translate(%s %s) rotate(%s)" % (x, y, a))
    sym = sole(54, 74, -14) + sole(76, 58, -14) + line([(36, 92), (46, 86)], 3, INK) + line([(40, 98), (50, 94)], 3, INK)
    return jawbreaker("#8fd6c0", "#62a892", sym)


JAWBREAKERS = {  # sim id: (maker, display name, extra keys)
    "thick_skin": (jb_thick_skin, "Thick Skin", []),
    "steady_aim": (jb_steady_aim, "Steady Aim", []),
    "sleight": (jb_sleight, "Sleight of Hand", ["sleight_of_hand"]),
    "payday": (jb_payday, "Payday Jawbreaker", []),
    "sugar_rush": (jb_sugar_rush, "Sugar Rush", []),
    "light_step": (jb_light_step, "Light Step", []),
}


# ---------------------------------------------------------------- room door tiles (240 x 180)
def room_tile(sky_top, sky_bot, wall, body: str) -> str:
    defs = linear("sky", [(0, sky_top), (1, sky_bot)])
    s = rect(0, 0, CW, CH, "url(#sky)", 0) + wall + body
    s += rect(0, GROUND, CW, CH - GROUND, INK, 0, extra='opacity="0.55"')
    return svg(CW, CH, s, defs)


def lamp(x, y, r=10, col="#f4d27a") -> str:
    return circ(x, y, r * 2.2, col, 0, extra='opacity="0.18"') + circ(x, y, r, col, 3)


def siding(col, col_d, top=22) -> str:
    return rect(0, top, CW, GROUND - top, col, 0) + "".join(line([(0, y), (CW, y)], 2.5, col_d) for y in range(top + 12, GROUND, 13))


def brick(col, col_d, top=0) -> str:
    out = rect(0, top, CW, GROUND - top, col, 0)
    for r, y in enumerate(range(top, GROUND, 14)):
        out += line([(0, y), (CW, y)], 2, col_d)
        for x in range((r % 2) * 14, CW, 28):
            out += line([(x, y), (x, y + 14)], 2, col_d)
    return out


def tiles(col, col_d, top=0, step=20) -> str:
    out = rect(0, top, CW, GROUND - top, col, 0)
    out += "".join(line([(0, y), (CW, y)], 1.8, col_d) for y in range(top, GROUND, step))
    return out + "".join(line([(x, top), (x, GROUND)], 1.8, col_d) for x in range(0, CW, step))


MAPLE_SKY = ("#2b2a3f", "#7a5a52")
DOWN_SKY = ("#141b2a", "#2d3a52")
AGNES_SKY = ("#18282a", "#3b5a50")


def r_maple_entrance() -> str:
    s = rect(96, 40, 104, 118, "#e8dcc0", 4) + poly([(88, 40), (148, 18), (208, 40)], "#5a4a3a")
    s += rect(122, 58, 52, 100, "#6e3b30", 4, rx=2) + rect(132, 68, 32, 26, "#f4d27a", 3, extra='opacity="0.85"')
    s += line([(148, 68), (148, 94)], 2.5, INK) + rect(130, 102, 14, 46, "#5a2f27", 0) + rect(152, 102, 14, 46, "#5a2f27", 0)
    s += circ(166, 112, 3.5, BRASS[0], 2) + lamp(210, 70, 7)
    s += rect(110, 150, 76, 8, "#7a6a58", 3) + rect(126, 144, 44, 7, "#4d6040", 2.5)
    return room_tile(*MAPLE_SKY, siding("#6b5a4a", "#55473a"), s)


def r_garage() -> str:
    s = rect(80, 44, 140, 114, "#4a4038", 4) + rect(90, 54, 120, 104, "#8a9196", 4)
    s += "".join(line([(92, y), (208, y)], 3, "#6a7176") for y in range(70, 158, 16))
    s += path("M130 118 Q140 110 152 120", "none", 3, stroke="#5a6064") + rect(140, 146, 22, 5, "#c9ccce", 2, rx=2)
    s += ell(150, 156, 20, 3, "#151214", 0, extra='opacity="0.6"') + lamp(150, 38, 5)
    return room_tile(*MAPLE_SKY, siding("#6b5a4a", "#55473a"), s)


def r_corner_store() -> str:
    s = rect(86, 64, 140, 94, "#3a3a34", 4)
    s += "".join(poly([(86 + i * 20, 48), (106 + i * 20, 48), (106 + i * 20, 62), (86 + i * 20, 66)], "#4d6040" if i % 2 == 0 else "#e8dcc0", 3) for i in range(7))
    s += rect(96, 76, 58, 44, "#f4d27a", 3, extra='opacity="0.55"') + line([(98, 98), (152, 98)], 3, "#5a4a3a")
    s += "".join(rect(x, 86, 7, 11, c, 2) for x, c in ((102, "#b5402f"), (112, "#46607c"), (122, "#d9a03a"), (134, "#6fd08a")))
    s += rect(170, 76, 42, 82, "#46607c", 4) + rect(176, 84, 30, 40, "#cfe6ec", 3, extra='opacity="0.6"') + rect(198, 128, 8, 4, STEEL[0], 2)
    s += circ(204, 70, 5, BRASS[0], 2.5)
    return room_tile(*MAPLE_SKY, brick("#6a4034", "#4f2f26", 24), s)


def r_workshop() -> str:
    s = rect(92, 46, 124, 112, "#3a2c20", 4)
    for x in (98, 156):
        s += rect(x, 52, 54, 106, WOOD[0], 4) + line([(x + 4, 56), (x + 50, 152)], 6, WOOD[1]) + rect(x, 52, 54, 106, "none", 4)
        s += "".join(line([(x + 13 * i + 13, 54), (x + 13 * i + 13, 156)], 2, WOOD[1]) for i in range(3))
    s += circ(154, 34, 14, STEEL[0], 4) + "".join(poly([(154 + math.cos(a) * 14, 34 + math.sin(a) * 14), (154 + math.cos(a + 0.3) * 19, 34 + math.sin(a + 0.3) * 19),
                                                         (154 + math.cos(a + 0.5) * 14, 34 + math.sin(a + 0.5) * 14)], STEEL[0], 2) for a in [i * math.pi / 5 for i in range(10)])
    s += circ(154, 34, 4, INK, 0) + lamp(224, 68, 6)
    return room_tile(*MAPLE_SKY, siding("#5a4c3e", "#46392e"), s)


def r_down_entrance() -> str:
    s = rect(116, 60, 58, 98, "#46505a", 4) + rect(124, 70, 42, 14, "#2c3236", 3) + rect(156, 108, 8, 14, STEEL[0], 2.5, rx=2)
    s += "".join(line([(124, y), (166, y)], 2, "#38414a") for y in (96, 132, 146))
    s += lamp(145, 48, 6, "#cfe6ec")
    s += line([(186, 20), (186, 120)], 4, "#2a2f36") + line([(226, 20), (226, 120)], 4, "#2a2f36")
    s += "".join(line([(186, y), (226, y)], 3.5, "#2a2f36") for y in range(30, 120, 14)) + rect(180, 60, 52, 6, "#2a2f36", 0)
    s += ell(150, 156, 24, 3, "#4a6a80", 0, extra='opacity="0.6"')
    return room_tile(*DOWN_SKY, brick("#4a3a36", "#33282a", 0), s)


def r_subway() -> str:
    s = poly([(100, 98), (224, 98), (240, 158), (88, 158)], "#1a1d20", 4)
    s += "".join(line([(96 - i * 2, 110 + i * 12), (226 + i * 3, 110 + i * 12)], 3, "#3a4048") for i in range(4))
    s += line([(100, 98), (88, 72), (88, 158)], 5, STEEL[1]) + line([(224, 98), (234, 72), (236, 158)], 5, STEEL[1])
    s += line([(88, 72), (100, 72), (110, 98)], 5, STEEL[1]) + line([(234, 72), (222, 72), (214, 98)], 5, STEEL[1])
    s += line([(96, 72), (96, 44)], 5, "#2a2f36") + lamp(96, 38, 9, "#7fe0a0")
    return room_tile(*DOWN_SKY, tiles("#5c6a62", "#4a564f", 40, 18) + rect(0, 0, CW, 40, "none", 0), s)


def r_pawn_shop() -> str:
    s = rect(96, 56, 74, 66, "#f4d27a", 4, extra='opacity="0.4"') + rect(96, 56, 74, 66, "none", 4)
    s += "".join(line([(x, 58), (x, 120)], 4, "#2a2f36") for x in range(106, 168, 12))
    s += rect(178, 60, 44, 98, "#3a3226", 4) + "".join(line([(184, y), (216, y)], 3, "#2a2f36") for y in range(70, 150, 12))
    s += line([(150, 30), (196, 30)], 4, "#2a2f36") + line([(196, 30), (196, 22)], 4, "#2a2f36")
    s += line([(178, 30), (178, 38)], 2.5, "#2a2f36")
    s += circ(170, 44, 7, BRASS[0], 3) + circ(186, 44, 7, BRASS[0], 3) + circ(178, 57, 7, BRASS[0], 3)
    return room_tile(*DOWN_SKY, brick("#4a3a36", "#33282a", 0), s)


def r_parking() -> str:
    s = rect(80, 40, 160, 118, "#6a6e70", 0) + rect(92, 58, 148, 100, "#141618", 4)
    s += poly([(92, 158), (240, 120), (240, 158)], "#2a2e30", 0)
    s += rect(82, 40, 14, 118, "#7d8284", 4) + "".join(poly([(82, y), (96, y - 8), (96, y + 2), (82, y + 10)], "#e0b04a", 0) for y in range(120, 156, 18))
    s += rect(104, 108, 18, 40, "#46505a", 4) + rect(108, 114, 10, 10, "#cfe6ec", 2.5, extra='opacity="0.7"')
    s += g(rect(0, -5, 104, 10, "#e8dcc0", 3.5, rx=2) + "".join(rect(x, -5, 10, 10, "#b5402f", 0) for x in range(10, 100, 22)), "translate(118 116) rotate(-8)")
    s += lamp(170, 74, 5, "#cfe6ec") + lamp(214, 74, 5, "#cfe6ec")
    return room_tile(*DOWN_SKY, rect(0, 0, CW, GROUND, "#4f5456", 0) + "".join(line([(0, y), (CW, y)], 2, "#3f4446") for y in (20, 40)), s)


def plus(cx, cy, r, fill="#6fd08a", bg=BONE) -> str:
    return (rect(cx - r, cy - r, 2 * r, 2 * r, bg, 3, rx=3) + rect(cx - r * 0.25, cy - r * 0.75, r * 0.5, r * 1.5, fill, 0)
            + rect(cx - r * 0.75, cy - r * 0.25, r * 1.5, r * 0.5, fill, 0))


def r_agnes_entrance() -> str:
    s = poly([(80, 44), (234, 44), (226, 58), (88, 58)], "#cfd6d0", 4) + limb([(94, 58), (94, 158)], 4, STEEL[1], 3) + limb([(222, 58), (222, 158)], 4, STEEL[1], 3)
    s += rect(110, 70, 96, 88, "#a8c4c8", 4, extra='fill-opacity="0.45"') + line([(158, 70), (158, 158)], 4, INK)
    s += rect(150, 70, 4, 88, "#f4fbfc", 0, extra='opacity="0.5"') + plus(158, 30, 12)
    s += g(line([(0, 0), (130, 12)], 7, "#e0b04a") + "".join(line([(x, x * 0.092 - 3), (x + 5, x * 0.092 + 3.5)], 3, INK) for x in range(4, 126, 14)), "translate(100 116)")
    return room_tile(*AGNES_SKY, tiles("#8e9a92", "#78857d", 0, 22), s)


def r_pharmacy() -> str:
    s = rect(92, 50, 132, 108, "#2c3236", 4) + rect(100, 96, 116, 54, "#1d3325", 0)
    s += "".join(rect(x, 104 + (x % 3) * 0, 8, 12, c, 2) for x, c in ((106, BONE), (118, "#6fd08a"), (130, BONE), (142, "#d9a03a"), (178, BONE), (190, "#6fd08a"), (202, BONE)))
    s += line([(100, 118), (216, 118)], 3, "#3e4c43") + "".join(rect(x, 124, 9, 14, c, 2) for x, c in ((110, "#6fd08a"), (124, BONE), (184, BONE), (198, "#6fd08a")))
    s += rect(96, 54, 124, 42, "#6d7b80", 4) + "".join(line([(98, y), (218, y)], 2.5, "#55636a") for y in range(62, 96, 8))
    s += rect(96, 140, 124, 18, "#cfd6d0", 4) + plus(158, 30, 13)
    return room_tile(*AGNES_SKY, tiles("#8e9a92", "#78857d", 0, 22), s)


def r_security() -> str:
    s = rect(120, 52, 60, 106, "#55636a", 4) + rect(132, 62, 36, 26, "#cfe6ec", 3, extra='opacity="0.55"')
    s += "".join(line([(132 + d, 62), (132 + d + 26, 88)], 1.6, INK) for d in (-18, -6, 6, 18) if True)
    s += rect(132, 62, 36, 26, "none", 3) + rect(166, 104, 8, 16, STEEL[0], 2.5, rx=2)
    s += rect(188, 96, 16, 22, "#2c3236", 3, rx=2) + "".join(circ(193 + (i % 2) * 6, 101 + (i // 2) * 5, 1.6, "#9fd8ff", 0) for i in range(6))
    s += line([(214, 40), (226, 40)], 5, "#2c3236") + g(rect(-24, -8, 30, 16, BONE_D, 3.5, rx=3) + circ(-24, 0, 4, "#2c3236", 2.5), "translate(214 50) rotate(20)")
    s += circ(212, 44, 2.5, "#e2574c", 0)
    return room_tile(*AGNES_SKY, tiles("#8e9a92", "#78857d", 0, 22), s)


def r_morgue() -> str:
    s = rect(100, 46, 120, 112, "#3a4a52", 4)
    for x in (106, 162):
        s += rect(x, 52, 52, 106, "#b8c4c0", 4) + rect(x, 118, 52, 10, "#6d7b80", 0) + circ(x + 26, 80, 13, "#9fd8ff", 4) + ell(x + 22, 76, 4, 3, "#f4fbfc", 0, extra='opacity="0.7"')
    s += "".join(path("M%d 156 Q%d 146 %d 152 T%d 150" % (x, x + 10, x + 20, x + 40), "none", 4, stroke="#cfe6ec", extra='opacity="0.45"') for x in (92, 140, 186))
    s += lamp(160, 34, 6, "#cfe6ec")
    return room_tile(*AGNES_SKY, tiles("#7f8c8a", "#6b7876", 0, 22), s)


ROOMS = {  # district id: [(room slug, display name, maker)] entrance first, then the 3 rooms in sim order
    "maple_row": [("entrance", "Maple Row Entrance", r_maple_entrance), ("garage", "Garage", r_garage),
                  ("corner_store", "Corner Store", r_corner_store), ("workshop", "Workshop", r_workshop)],
    "downtown": [("entrance", "Downtown Entrance", r_down_entrance), ("subway_kiosk", "Subway Kiosk", r_subway),
                 ("pawn_shop", "Pawn Shop", r_pawn_shop), ("parking_garage", "Parking Garage", r_parking)],
    "st_agnes": [("entrance", "St. Agnes Entrance", r_agnes_entrance), ("pharmacy", "Pharmacy", r_pharmacy),
                 ("security_office", "Security Office", r_security), ("morgue_lab", "Morgue Lab", r_morgue)],
}


# ---------------------------------------------------------------- v2 perks + wave marker
def p_fast_hands() -> str:
    s = g(path("M-12 -34 L12 -34 Q14 4 26 36 L4 42 Q-10 8 -12 -34 Z", STEEL[1]) + line([(-4, -26), (0, 8)], 3.5, STEEL[0]) + bullet(0, -40, 0, 0.7),
          "translate(74 60) rotate(18)")
    s += line([(24, 40), (48, 40)], 5, "#9aa8ff") + line([(18, 58), (46, 58)], 5, "#9aa8ff") + line([(26, 76), (50, 76)], 5, "#9aa8ff")
    return perk(s)


def p_bandolier() -> str:
    s = g(rect(-50, -11, 100, 22, "#7a4f2c", 4, rx=4) + "".join(bullet(x, -6, 0, 0.62) for x in range(-40, 44, 14))
          + "".join(rect(x - 6, -2, 12, 13, "#5e3b20", 2.5, rx=1) for x in range(-40, 44, 14)) + rect(-10, -14, 20, 28, BRASS[0], 3.5, rx=3)
          + rect(-4, -8, 8, 16, "#7a4f2c", 0), "translate(64 66) rotate(-35)")
    return perk(s)


def icon_wave() -> str:
    bg, mid, motif, acc = PAL["zombie"]
    defs = radial("wv", mid, bg, 0.5, 0.4, 0.7)
    s = circ(64, 64, 60, "url(#wv)", 0) + circ(88, 40, 16, "#7a4a40", 0)
    s += "".join(rect(x, y, w, 104 - y, motif, 0) for x, y, w in ((22, 70, 14), (36, 58, 12), (84, 62, 14), (98, 74, 10)))
    sk = SKIN_Z[0]
    s += limb([(60, 112), (60, 78)], 15, "#5c5048") + path("M50 86 L54 78 L58 86 L62 78 L66 86 L70 78 L70 92 L50 92 Z", "#5c5048", 3)
    s += limb([(60, 84), (62, 50)], 14, sk) + hand(62, 42, -math.pi / 2, 12, sk) + circ(56, 72, 3, GORE, 0)
    s += path("M12 94 Q38 88 64 96 Q90 102 116 94 A60 60 0 0 1 12 94 Z", INK, 0) + "".join(line([(x, 96), (x + 6, 88)], 3, INK) for x in (34, 80, 96))
    s += '<circle cx="64" cy="64" r="57" fill="none" stroke="%s" stroke-width="6"/>' % acc
    return svg(128, 128, s, defs)


# ================================================================ v3 ("Kill Stacks") art
# Everything below was added for core-rules-v3.md (board task dd-v3-art): the five new guns
# (Ratchet Crossbow, Twin-Bore, Lever Rifle, Nail Driver, Elephant Gun; Service Pistol, Hunting Rifle,
# Pump Shotgun and Scout Carbine reuse v2 art), the Patch Press, the 8 Patches, gun-rule glyphs,
# challenge / bench badges, wave-deck and room-deck backs and Patient Zero's 3 phases.
# Same style rules as v1/v2. All designs are original to DeadDraw.
NAIL_ORANGE = ("#d9772e", "#a8551c")   # Nail Driver tool body
THREAD = "#f4ead0"                     # embroidery thread on Patches


# ---------------------------------------------------------------- v3 guns (local coords, muzzle at +x)
def gun_crossbow() -> str:
    """Ratchet Crossbow, seen from above so the bow reads at a glance: wooden tiller, steel prod with
    curled tips, a toothed ratchet wheel + crank at the back, a bolt on the rail."""
    s = limb([(70, -60), (84, -30), (88, 0), (84, 30), (70, 60)], 9, STEEL[1])
    s += line([(70, -60), (84, -30), (88, 0), (84, 30), (70, 60)], 3, STEEL[0])
    s += circ(70, -62, 5, STEEL[1], 3) + circ(70, 62, 5, STEEL[1], 3)
    s += line([(70, -62), (-12, -6)], 2.5, BONE_D) + line([(70, 62), (-12, 6)], 2.5, BONE_D)
    s += path("M-124 -14 L-60 -10 L60 -8 L96 -6 L96 6 L60 8 L-60 10 L-124 14 Q-130 0 -124 -14 Z", WOOD[0])
    s += line([(-116, 0), (-70, 0)], 3, WOOD[1]) + rect(84, -10, 16, 20, STEEL[1], 3.5, rx=2)
    s += rect(-20, -9, 18, 18, GUN[0], 3.5, rx=2)
    # bolt
    s += line([(-12, 0), (118, 0)], 4, INK) + line([(-12, 0), (114, 0)], 2, "#d8c8a8")
    s += poly([(114, -5), (126, 0), (114, 5)], STEEL[0], 2.5)
    s += poly([(-12, 0), (-2, -8), (8, -8), (0, 0)], "#b5402f", 2) + poly([(-12, 0), (-2, 8), (8, 8), (0, 0)], "#b5402f", 2)
    # ratchet wheel + crank (the "ratchet")
    teeth = "".join(poly([(math.cos(a) * 15, math.sin(a) * 15), (math.cos(a + 0.22) * 21, math.sin(a + 0.22) * 21),
                          (math.cos(a + 0.4) * 15, math.sin(a + 0.4) * 15)], STEEL[0], 2) for a in [i * math.pi / 5 for i in range(10)])
    s += g(teeth + circ(0, 0, 16, STEEL[0], 3.5) + circ(0, 0, 5, GUN[1], 2.5)
           + limb([(0, 0), (16, 22)], 5, GUN[1], 3) + circ(16, 24, 6, WOOD[0], 3), "translate(-62 -20)")
    return s


def gun_twin_bore() -> str:
    """Twin-Bore: a stubby over-and-under break-action. Two stacked barrels and a muzzle plate that
    shows both bores, so 'twin' reads from the side."""
    s = path("M-104 -6 L-46 -18 L-40 10 L-58 16 Q-80 26 -104 40 Q-114 18 -104 -6 Z", WOOD[0])
    s += line([(-96, 18), (-58, 8)], 3, WOOD[1]) + rect(-110, -8, 8, 50, POLYMER, 3.5, rx=2)
    s += rect(-48, -24, 40, 38, GUN[0], 4, rx=5) + line([(-44, -19), (-14, -19)], 2.5, GUN_HI) + trigger(-22, 14, 18, 16)
    s += circ(-28, -2, 4, GUN[1], 2.5)
    s += poly([(-38, -24), (-46, -36), (-38, -38), (-30, -24)], GUN[1], 3)
    s += rect(-10, -26, 96, 15, GUN[0], 4, rx=2) + rect(-10, -12, 96, 15, GUN[0], 4, rx=2)
    s += line([(-4, -22), (80, -22)], 2.5, GUN_HI) + line([(-4, -8), (80, -8)], 2.5, GUN_HI)
    s += rect(-2, 2, 52, 12, WOOD[0], 3.5, rx=5)
    s += ell(90, -11, 9, 19, GUN[1], 4) + circ(90, -19, 4.5, INK, 0) + circ(90, -3, 4.5, INK, 0)
    return g(s, "scale(1.08)")


def gun_lever_rifle() -> str:
    """Lever Rifle: straight wooden stock, brass receiver, long barrel over a tube magazine and a big
    loop lever. Reads apart from the Hunting Rifle (bolt + scope) by the brass and the loop."""
    s = path("M-126 -12 L-52 -16 L-46 2 L-60 6 Q-92 14 -126 28 Q-132 6 -126 -12 Z", WOOD[0])
    s += line([(-116, 12), (-64, 4)], 2.5, WOOD[1]) + rect(-132, -14, 8, 44, "#3a2c20", 3.5, rx=2)
    s += path("M-48 6 Q-46 34 -26 34 Q-6 34 -8 12", "none", 9) + path("M-48 6 Q-46 34 -26 34 Q-6 34 -8 12", "none", 4.5, stroke=GUN[1])
    s += rect(-54, -20, 52, 26, BRASS[0], 4, rx=3) + line([(-48, -15), (-8, -15)], 2.5, "#f0d488")
    s += circ(-40, -6, 3, BRASS[1], 2) + circ(-16, -6, 3, BRASS[1], 2)
    s += rect(-4, -4, 118, 8, GUN[1], 3.5, rx=3)
    s += rect(-4, -18, 128, 12, GUN[0], 4, rx=1) + line([(0, -14), (118, -14)], 2.5, GUN_HI)
    s += rect(4, -6, 54, 14, WOOD[0], 4, rx=5)
    s += poly([(112, -18), (116, -27), (120, -18)], GUN[1], 3) + rect(26, -25, 8, 7, GUN[1], 2.5)
    s += rect(108, -6, 8, 12, BRASS[1], 3, rx=1)
    return g(s, "scale(0.94)")


def gun_nail_driver() -> str:
    """Nail Driver: a pneumatic site nailer (orange tool body, nose down-front, angled nail strip,
    coiled air hose). A tool turned weapon, not a gun shape."""
    s = path("M-70 46 Q-84 72 -108 64 Q-130 56 -122 40 Q-114 28 -104 40 Q-96 52 -122 78", "none", 9)
    s += path("M-70 46 Q-84 72 -108 64 Q-130 56 -122 40 Q-114 28 -104 40 Q-96 52 -122 78", "none", 4.5, stroke="#d8c060")
    s += rect(-76, 38, 14, 10, BRASS[0], 3, rx=2)
    s += poly([(-62, -10), (-34, -10), (-30, 46), (-58, 50)], POLYMER) + trigger(-26, -4, 18, 16)
    s += "".join(line([(-58 + d, 4), (-54 + d, 40)], 2.2, "#4a4848") for d in (6, 14))
    s += path("M-70 -36 L40 -36 Q58 -36 58 -18 L58 -6 L-70 -6 Q-80 -20 -70 -36 Z", NAIL_ORANGE[0])
    s += path("M-64 -14 L52 -14 L52 -6 L-66 -6 Z", NAIL_ORANGE[1], 0) + path("M-70 -36 L40 -36 Q58 -36 58 -18 L58 -6 L-70 -6 Q-80 -20 -70 -36 Z", "none", 4)
    s += rect(-30, -44, 44, 10, GUN[1], 3, rx=3)
    s += rect(52, -32, 20, 62, GUN[0], 4, rx=3) + rect(56, 28, 12, 18, STEEL[1], 3.5, rx=2)
    s += line([(62, 46), (62, 56)], 3, STEEL[0])
    strip = poly([(-24, 12), (54, 2), (56, 16), (-22, 26)], STEEL[1], 3.5)
    strip += "".join(line([(x, 12 - (x + 24) * 0.128 + 2), (x + 1, 24 - (x + 24) * 0.128)], 2, STEEL[0]) for x in range(-18, 52, 7))
    s = strip + s
    s += rect(-58, -28, 12, 12, "#2b2a2a", 2.5, rx=2) + rect(-40, -28, 50, 6, NAIL_ORANGE[1], 0, rx=2)
    return g(s, "scale(1.05)")


def gun_elephant() -> str:
    """Elephant Gun: the heaviest gun in the game. Deep wooden stock with a thick recoil pad, big
    break-action receiver, one fat barrel with a raised rib and express sights."""
    s = path("M-132 -16 L-50 -22 L-44 6 L-60 12 Q-96 24 -132 40 Q-140 12 -132 -16 Z", WOOD[0])
    s += path("M-118 -6 Q-90 -16 -60 -12", "none", 3, stroke=WOOD[1]) + line([(-122, 20), (-66, 8)], 3, WOOD[1])
    s += rect(-142, -18, 12, 60, "#3a2c20", 4, rx=3)
    s += "".join(line([(-104 + d, 2), (-98 + d, 18)], 2.2, WOOD[1]) for d in (0, 8, 16))
    s += rect(-50, -30, 52, 40, GUN[0], 4, rx=5) + line([(-44, -25), (-6, -25)], 3, GUN_HI) + trigger(-22, 10, 22, 18)
    s += circ(-24, -8, 5, GUN[1], 3) + poly([(-40, -30), (-48, -44), (-38, -46), (-30, -30)], GUN[1], 3)
    s += path("M2 -30 L132 -24 L132 2 L2 8 Z", GUN[0]) + line([(8, -24), (126, -19)], 3, GUN_HI)
    s += rect(2, -36, 120, 7, GUN[1], 3, rx=2)
    s += rect(4, 0, 64, 16, WOOD[0], 4, rx=6) + "".join(line([(x, 4), (x, 12)], 2.5, WOOD[1]) for x in (16, 26, 36, 46, 56))
    s += poly([(116, -36), (122, -46), (128, -36)], GUN[1], 3) + rect(36, -44, 12, 9, GUN[1], 3)
    s += rect(128, -27, 10, 32, GUN[1], 4, rx=2)
    return g(s, "scale(0.86)")


def weapon_card_v3(fid: str) -> str:
    maker, rot, cx, cy, _n, _i = GUNS_V3[fid]
    extra = ""
    if fid == "weapon_elephant_gun":   # one oversized cartridge lies in front: the heft cue
        extra = bullet(206, 150, 76, 1.25)
    return weapon_card(g(maker(), "scale(0.9)"), rot, cx, cy).replace("\n</svg>", extra + "\n</svg>")


GUNS_V3 = {  # file id: (body maker, rotation, cx, cy, display name, sim id)
    "weapon_ratchet_crossbow": (gun_crossbow, -12, 142, 100, "Ratchet Crossbow", "crossbow"),
    "weapon_twin_bore": (gun_twin_bore, -10, 142, 106, "Twin-Bore", "twin"),
    "weapon_lever_rifle": (gun_lever_rifle, -12, 132, 112, "Lever Rifle", "lever"),
    "weapon_nail_driver": (gun_nail_driver, -10, 140, 98, "Nail Driver", "nailer"),
    "weapon_elephant_gun": (gun_elephant, -12, 130, 110, "Elephant Gun", "elephant"),
}
# v3 guns already drawn for v2 (sim_deaddraw_v3.py CONFIG ids -> existing files)
GUNS_V3_REUSE = {"pistol": ("Service Pistol", "cards/weapon_service_pistol.svg"),
                 "rifle": ("Hunting Rifle", "cards/weapon_hunting_rifle.svg"),
                 "shotgun": ("Pump Shotgun", "cards/weapon_pump_shotgun.svg"),
                 "carbine": ("Scout Carbine", "cards/weapon_carbine.svg")}


# ---------------------------------------------------------------- Patch Press (machine card, 240 x 180)
def mc_patch_press() -> str:
    """Patch Press: a rusty clamshell heat press on a workbench. Hinged top platen on a long lever,
    orange heat glow, a round patch on the lower plate, a pressure dial and thread spools. Nothing
    like a drinks machine: it is a garment-shop tool."""
    rust, rust_d = "#8a5a3a", "#64402a"
    s = limb([(62, 140), (60, GROUND + 6)], 10, WOOD[1]) + limb([(222, 140), (224, GROUND + 6)], 10, WOOD[1])
    s += rect(44, 128, 192, 16, WOOD[0], 4, rx=2) + line([(50, 134), (230, 134)], 2.5, WOOD[1])
    # base + lower plate
    s += rect(96, 112, 116, 18, rust_d, 4, rx=3) + rect(104, 104, 100, 10, STEEL[0], 3.5, rx=2)
    s += ell(150, 104, 22, 4, "#f2a65a", 0, extra='opacity="0.55"')
    # the patch being pressed (bright, on the plate)
    s += ell(150, 101, 18, 5, "#4f9ad8", 3) + ell(150, 100, 10, 2.5, THREAD, 0)
    # column + hinge
    s += rect(196, 40, 18, 74, rust, 4, rx=3) + circ(205, 48, 9, rust_d, 3.5) + circ(205, 48, 3, STEEL[0], 0)
    # top platen, raised at an angle
    s += g(rect(-96, -10, 100, 20, rust, 4, rx=4) + rect(-92, 8, 92, 7, STEEL[1], 3, rx=2)
           + "".join(line([(x, -6), (x, 6)], 2.5, rust_d) for x in range(-84, -6, 12)), "translate(205 48) rotate(-14)")
    # heat glow between the plates
    s += path("M118 96 Q150 70 182 92", "none", 5, stroke="#f2a65a", extra='opacity="0.7"')
    s += path("M128 88 Q150 70 172 86", "none", 3, stroke="#ffd59a", extra='opacity="0.7"')
    # lever handle up and right
    s += limb([(205, 48), (226, 18)], 6, STEEL[1], 3) + limb([(222, 22), (232, 8)], 9, "#2b2a2a", 3.5)
    # pressure dial
    s += circ(205, 86, 10, BONE, 3.5) + line([(205, 86), (211, 80)], 2.5, "#b5402f") + circ(205, 86, 2, INK, 0)
    # thread spools on the bench
    for x, c in ((70, "#e2574c"), (86, "#e6b83a")):
        s += rect(x - 6, 110, 12, 18, c, 3, rx=2) + rect(x - 8, 108, 16, 4, WOOD[1], 2.5, rx=1) + rect(x - 8, 126, 16, 4, WOOD[1], 2.5, rx=1)
    s += path("M86 112 Q100 96 112 102", "none", 2, stroke="#e6b83a")
    # steam
    s += "".join(path("M%d 66 Q%d 58 %d 50 Q%d 42 %d 34" % (x, x - 6, x, x + 6, x), "none", 3, stroke="#cfd6d0", extra='opacity="0.45"') for x in (138, 158))
    return card_art("machine", s)


# ---------------------------------------------------------------- Patches (128 x 128 embroidered badges)
def patch(field: str, rim: str, symbol: str) -> str:
    """Round embroidered patch: thick twill rim, stitch ring, cloth field, thread-coloured symbol.
    Transparent outside the patch so it can sit on the survivor portrait."""
    defs = radial("pf", field, field, 0.5, 0.4, 0.7)
    s = circ(64, 64, 60, rim, 4)
    s += "".join(rect(-1.6, -56, 3.2, 7, INK, 0, extra='opacity="0.55" transform="translate(64 64) rotate(%d)"' % a) for a in range(0, 360, 15))
    s += circ(64, 64, 47, field, 4)
    s += "".join(rect(-1.2, -43, 2.4, 5, THREAD, 0, extra='opacity="0.7" transform="translate(64 64) rotate(%d)"' % a) for a in range(0, 360, 12))
    s += path("M30 46 Q44 26 70 24", "none", 3, stroke="#ffffff", extra='opacity="0.18"')
    return svg(128, 128, s + symbol, defs)


def pa_lookout() -> str:
    s = g(rect(-30, -14, 24, 34, "#3a3e5c", 4, rx=8) + rect(6, -14, 24, 34, "#3a3e5c", 4, rx=8) + rect(-8, -6, 16, 14, "#2c3040", 4, rx=3)
          + circ(-18, 26, 11, THREAD, 4) + circ(18, 26, 11, THREAD, 4) + circ(-18, 26, 5, "#9fd8ff", 0) + circ(18, 26, 5, "#9fd8ff", 0)
          + ell(-21, 23, 2.2, 1.6, "#ffffff", 0) + ell(15, 23, 2.2, 1.6, "#ffffff", 0), "translate(64 52)")
    return patch("#2a3550", "#9aa8ff", s)


def pa_thick_jacket() -> str:
    c, d = "#a86a3c", "#7a4a28"
    s = path("M46 36 L56 32 Q64 40 72 32 L82 36 L100 54 L92 66 L86 60 L86 98 L42 98 L42 60 L36 66 L28 54 Z", c)
    s += "".join(path("M43 %d Q64 %d 85 %d" % (y, y + 4, y), "none", 3, stroke=d) for y in (56, 70, 84))
    s += path("M56 32 L64 46 L72 32", "none", 4) + line([(64, 46), (64, 98)], 3.5, INK)
    s += path("M42 98 L86 98", "none", 4)
    return patch("#3a2e26", "#e0b04a", s)


def pa_field_medic() -> str:
    s = rect(36, 36, 56, 56, THREAD, 4, rx=10) + rect(57, 44, 14, 40, "#3fae5e", 0) + rect(44, 57, 40, 14, "#3fae5e", 0)
    s += rect(57, 44, 14, 40, "none", 0)
    s += g(rect(-8, -14, 16, 28, BONE_D, 3.5, rx=3) + line([(-8, -4), (8, -4)], 2, "#8a826e"), "translate(92 92) rotate(-30)")
    return patch("#3c4a2e", "#6fd08a", s)


def pa_brawler() -> str:
    sk, sd = "#d8a882", "#b07e5a"
    s = rect(40, 48, 50, 36, sk, 4, rx=12)
    s += "".join(line([(x, 50), (x, 66)], 3, sd) for x in (53, 65, 77))
    s += path("M40 64 Q30 66 32 80 Q36 92 50 90 L52 74", sk, 4)
    s += rect(40, 82, 46, 18, "#b5402f", 4, rx=4) + line([(46, 91), (80, 91)], 2.5, "#8a2f24")
    s += line([(96, 44), (106, 36)], 4, THREAD) + line([(100, 58), (112, 56)], 4, THREAD) + line([(92, 32), (94, 22)], 4, THREAD)
    return patch("#5a2420", "#e2574c", s)


def pa_bounty_hunter() -> str:
    s = star(64, 60, 26, "#e6b83a", 4) + circ(64, 60, 8, "#b58a22", 3)
    s += path("M40 80 L32 100 L44 96 L50 106 L56 86 Z", "#b5402f", 3.5) + path("M88 80 L96 100 L84 96 L78 106 L72 86 Z", "#b5402f", 3.5)
    return patch("#3a3020", "#f2d65c", s)


def pa_loose_grip() -> str:
    s = rect(30, 70, 68, 12, BONE_D, 3.5, rx=3) + line([(34, 76), (94, 76)], 2, "#8a826e")
    s += path("M34 96 Q36 38 64 38 Q92 38 94 62", "none", 11) + path("M34 96 Q36 38 64 38 Q92 38 94 62", "none", 5.5, stroke=THREAD)
    s += poly([(82, 60), (106, 58), (94, 80)], THREAD, 3.5)
    return patch("#3a2a4e", "#b48ae0", s)


def pa_second_wind() -> str:
    s = path("M64 98 Q30 76 34 54 Q38 38 52 40 Q60 42 64 50 Q68 42 76 40 Q90 38 94 54 Q98 76 64 98 Z", "#e2574c", 4)
    s += ell(50, 52, 6, 4, "#f4a49a", 0, rot=-30)
    s += path("M20 66 Q40 60 52 68 Q62 74 72 66", "none", 8) + path("M20 66 Q40 60 52 68 Q62 74 72 66", "none", 4, stroke=THREAD)
    s += path("M26 84 Q46 78 60 86 Q70 92 80 84 Q88 78 96 82", "none", 8) + path("M26 84 Q46 78 60 86 Q70 92 80 84 Q88 78 96 82", "none", 4, stroke=THREAD)
    return patch("#1f3a3a", "#4fd1c5", s)


def pa_trophy_belt() -> str:
    s = rect(14, 58, 100, 20, "#5a3a24", 4, rx=3) + "".join(circ(x, 68, 2.5, INK, 0) for x in (20, 26, 102, 108))
    s += ell(64, 68, 30, 24, BRASS[0], 4) + ell(64, 68, 22, 16, BRASS[1], 3)
    s += path("M54 58 L74 58 Q74 72 64 74 Q54 72 54 58 Z", "#f0d488", 3) + rect(60, 74, 8, 5, "#f0d488", 2.5) + rect(55, 79, 18, 4, "#f0d488", 2.5)
    s += path("M54 61 Q48 61 49 66 Q50 70 56 69", "none", 2.5) + path("M74 61 Q80 61 79 66 Q78 70 72 69", "none", 2.5)
    return patch("#4a2228", "#e0b04a", s)


PATCHES = {  # sim id: (maker, display name, extra keys)
    "lookout": (pa_lookout, "Lookout", []),
    "thick_jacket": (pa_thick_jacket, "Thick Jacket", []),
    "field_medic": (pa_field_medic, "Field Medic", []),
    "brawler": (pa_brawler, "Brawler", []),
    "bounty": (pa_bounty_hunter, "Bounty Hunter", ["bounty_hunter"]),
    "loose_grip": (pa_loose_grip, "Loose Grip", []),
    "second_wind": (pa_second_wind, "Second Wind", []),
    "trophy_belt": (pa_trophy_belt, "Trophy Belt", []),
}


# ---------------------------------------------------------------- gun-rule glyphs (64 x 64, transparent)
RULE_RING = PAL["weapon"][3]


def glyph(body: str, ring: str = RULE_RING) -> str:
    return svg(64, 64, circ(32, 32, 30, INK, 0) + '<circle cx="32" cy="32" r="27.5" fill="none" stroke="%s" stroke-width="4"/>' % ring + body)


def arrow_v(x, y1, y2, w=9, col=BONE) -> str:
    """Bold arrow from y1 to y2 (head at y2), ink-outlined."""
    d = 1 if y2 > y1 else -1
    shaft = limb([(x, y1), (x, y2 - d * 14)], w, col, 3)
    head = poly([(x - 16, y2 - d * 18), (x + 16, y2 - d * 18), (x, y2)], col, 3)
    return shaft + head


def rg_any() -> str:  # no rule: a wild star
    return glyph(star(32, 33, 15, BONE, 3) + circ(32, 33, 4, RULE_RING, 0))


def rg_down() -> str:
    return glyph(arrow_v(32, 12, 52, 7))


def rg_up() -> str:
    return glyph(arrow_v(32, 52, 12, 7))


def rg_same() -> str:
    return glyph(rect(14, 20, 36, 9, BONE, 3, rx=2) + rect(14, 35, 36, 9, BONE, 3, rx=2))


def rg_zigzag() -> str:
    p = [(12, 40), (22, 22), (32, 42), (42, 22)]
    return glyph(line(p, 12, INK) + line(p, 6, BONE) + poly([(36, 20), (52, 14), (48, 30)], BONE, 3))


def rg_close() -> str:  # within 1: two chevrons squeezing a dot
    s = poly([(10, 20), (24, 32), (10, 44), (10, 36), (15, 32), (10, 28)], BONE, 3)
    s += poly([(54, 20), (40, 32), (54, 44), (54, 36), (49, 32), (54, 28)], BONE, 3)
    return glyph(s + circ(32, 32, 6, RULE_RING, 3))


def rg_parity() -> str:  # one pip <-> two pips
    s = rect(9, 18, 20, 20, BONE, 3, rx=4) + circ(19, 28, 3.6, INK, 0)
    s += rect(35, 26, 20, 20, BONE, 3, rx=4) + circ(40.5, 31.5, 3.2, INK, 0) + circ(49.5, 40.5, 3.2, INK, 0)
    s += path("M18 44 Q22 52 32 50", "none", 3, stroke=RULE_RING) + path("M46 20 Q42 12 32 14", "none", 3, stroke=RULE_RING)
    return glyph(s)


def rg_spread() -> str:  # sum cap: blocks stacked under a ceiling
    s = rect(22, 38, 20, 10, BONE, 2.5, rx=1.5) + rect(22, 28, 20, 10, BONE_D, 2.5, rx=1.5) + rect(22, 21, 20, 7, BONE, 2.5, rx=1.5)
    s += line([(12, 15), (52, 15)], 9, INK) + line([(12, 15), (52, 15)], 4.5, "#e2574c")
    s += line([(14, 50), (50, 50)], 3, BONE_D)
    return glyph(s)


def rg_big() -> str:  # 6 or more: a six-face die with an up chevron
    s = rect(12, 18, 30, 30, BONE, 3, rx=6)
    s += "".join(circ(x, y, 3, INK, 0) for x in (20, 34) for y in (25, 33, 41))
    s += poly([(44, 26), (52, 16), (60, 26), (55, 26), (52, 22), (49, 26)], BONE, 2.5)
    return glyph(s)


def rg_bent() -> str:  # Loose Grip: the rule bent out of the way
    s = rect(10, 34, 44, 7, BONE_D, 2.5, rx=2)
    s += path("M16 50 Q18 14 36 14 Q48 14 50 28", "none", 9) + path("M16 50 Q18 14 36 14 Q48 14 50 28", "none", 4, stroke="#b48ae0")
    s += poly([(42, 26), (58, 26), (50, 38)], "#b48ae0", 2.5)
    return glyph(s, "#b48ae0")


RULE_GLYPHS = {  # sim rule id: (maker, extra keys)
    "any": (rg_any, ["none", "no_rule"]),
    "down": (rg_down, ["lower", "down_arrow"]),
    "up": (rg_up, ["higher", "up_arrow"]),
    "same": (rg_same, ["equal", "equals"]),
    "zigzag": (rg_zigzag, ["zig_zag"]),
    "close": (rg_close, ["within_1", "within1"]),
    "parity": (rg_parity, ["odd_even"]),
    "spread": (rg_spread, ["sum_cap", "total_cap"]),
    "big": (rg_big, ["min_6", "six_plus"]),
    "bent": (rg_bent, ["loose_grip", "ignore_rule"]),
}


# ---------------------------------------------------------------- v3 badges (64 x 64)
def badge_challenge() -> str:
    """Challenge complete: gold medal on a red ribbon with a check mark."""
    s = poly([(18, 4), (30, 4), (36, 30), (24, 30)], "#b5402f", 3) + poly([(46, 4), (34, 4), (28, 30), (40, 30)], "#8a2f24", 3)
    s += circ(32, 40, 20, BRASS[0], 3.5) + circ(32, 40, 14, BRASS[1], 0)
    s += "".join(rect(-1.5, -19, 3, 4, "#f0d488", 0, extra='transform="translate(32 40) rotate(%d)"' % a) for a in range(0, 360, 30))
    s += line([(23, 40), (30, 47), (42, 33)], 10, INK) + line([(23, 40), (30, 47), (42, 33)], 5, BONE)
    return svg(64, 64, s)


def badge_challenge_open() -> str:
    """Challenge not yet met: the same medal as an empty grey outline."""
    s = poly([(18, 4), (30, 4), (36, 30), (24, 30)], "#4a4f55", 3) + poly([(46, 4), (34, 4), (28, 30), (40, 30)], "#3a3f45", 3)
    s += circ(32, 40, 20, "#2a2e33", 3.5) + '<circle cx="32" cy="40" r="14" fill="none" stroke="%s" stroke-width="2.5" opacity="0.8"/>' % BONE_D
    return svg(64, 64, s)


def badge_full_set() -> str:
    """dd-ui6 Full set (the completion bonus): a gold cup whose bowl holds 4 filled kill sockets."""
    return svg(64, 64, '<path d="M17 14 C6 14 6 30 20 31" fill="none" stroke="#151214" stroke-width="8" stroke-linecap="round"/><path d="M47 14 C58 14 58 30 44 31" fill="none" stroke="#151214" stroke-width="8" stroke-linecap="round"/><path d="M17 14 C6 14 6 30 20 31" fill="none" stroke="#d6a84a" stroke-width="4" stroke-linecap="round"/><path d="M47 14 C58 14 58 30 44 31" fill="none" stroke="#d6a84a" stroke-width="4" stroke-linecap="round"/><path d="M13 6 L51 6 L49 22 C47 34 40 40 32 41 C24 40 17 34 15 22 Z" fill="#f2c14e" stroke="#151214" stroke-width="3.5" stroke-linejoin="round"/><path d="M19 9 L45 9 L44 19 L20 19 Z" fill="#f7da8a" opacity="0.55"/><rect x="18" y="13" width="6" height="11" rx="1.5" fill="#c8322a" stroke="#151214" stroke-width="2"/><rect x="25.7" y="13" width="6" height="11" rx="1.5" fill="#c8322a" stroke="#151214" stroke-width="2"/><rect x="33.3" y="13" width="6" height="11" rx="1.5" fill="#c8322a" stroke="#151214" stroke-width="2"/><rect x="41" y="13" width="6" height="11" rx="1.5" fill="#c8322a" stroke="#151214" stroke-width="2"/><rect x="28" y="40" width="8" height="9" fill="#d6a84a" stroke="#151214" stroke-width="3" stroke-linejoin="round"/><path d="M18 58 L46 58 L43 49 L21 49 Z" fill="#d6a84a" stroke="#151214" stroke-width="3.5" stroke-linejoin="round"/><rect x="25" y="52" width="14" height="3" rx="1" fill="#a87d2e"/>')


def badge_flip() -> str:
    """Bench Flip plate: brass plate with an up and a down arrow."""
    s = badge_disc(BRASS[0]) + rect(12, 16, 40, 32, BRASS[0], 3, rx=4)
    s += "".join(circ(x, y, 1.8, BRASS[1], 0) for x in (17, 47) for y in (21, 43))
    s += poly([(20, 30), (26, 20), (32, 30)], INK, 0) + rect(24, 29, 4, 10, INK, 0)
    s += poly([(32, 34), (38, 44), (44, 34)], INK, 0) + rect(36, 25, 4, 10, INK, 0)
    return svg(64, 64, s)


def badge_honed() -> str:
    """Bench Hone plate: brass plate with a whetstone spark (+1 power is a label on top)."""
    s = badge_disc(BRASS[0]) + rect(12, 16, 40, 32, BRASS[0], 3, rx=4)
    s += "".join(circ(x, y, 1.8, BRASS[1], 0) for x in (17, 47) for y in (21, 43))
    s += g(rect(-14, -4, 28, 8, "#6d7b80", 2.5, rx=2), "translate(28 36) rotate(-25)")
    s += poly([(40, 18), (43, 26), (51, 27), (44, 31), (46, 39), (40, 34), (34, 39), (36, 31), (29, 27), (37, 26)], BONE, 2)
    return svg(64, 64, s)


def badge_no_escape() -> str:
    """Patient Zero street: a chain wrapped round a padlock (the NO ESCAPE banner text is UI)."""
    s = badge_disc(PAL["finale"][3])
    for i, (x, y) in enumerate(((10, 22), (19, 18), (28, 15), (36, 15), (45, 18), (54, 22))):
        s += ell(x, y, 5, 3.5 if i % 2 else 4.5, "none", 0) + '<ellipse cx="%s" cy="%s" rx="5.5" ry="%s" fill="none" stroke="%s" stroke-width="3"/>' % (x, y, "3.5" if i % 2 else "4.5", STEEL[0])
    s += path("M24 34 L24 28 Q24 21 32 21 Q40 21 40 28 L40 34", "none", 7) + path("M24 34 L24 28 Q24 21 32 21 Q40 21 40 28 L40 34", "none", 3, stroke=STEEL[0])
    s += rect(19, 32, 26, 20, BRASS[0], 3, rx=3) + circ(32, 40, 3, INK, 0) + rect(31, 41, 2.5, 6, INK, 0)
    return svg(64, 64, s)


# ---------------------------------------------------------------- deck backs (240 x 336)
def back_wave() -> str:
    """Wave-deck back: zombie red, a tide of reaching hands under a moon, the wave emblem."""
    W, H = 240, 336
    defs = radial("wb", "#5c302a", "#1a0f0e", 0.5, 0.42, 0.75)
    s = rect(0, 0, W, H, "#1a0f0e", 0) + rect(0, 0, W, H, "url(#wb)", 0)
    s += "".join(path("M0 %d Q60 %d 120 %d T240 %d L240 %d L0 %d Z" % (y, y - 10, y, y, y + 6, y + 6), "#2c1918", 0) for y in range(40, 336, 24))
    s += '<rect x="12" y="12" width="216" height="312" rx="12" fill="none" stroke="%s" stroke-width="4"/>' % BONE_D
    s += '<rect x="22" y="22" width="196" height="292" rx="8" fill="none" stroke="#e2574c" stroke-width="2"/>'
    s += circ(120, 112, 42, "#7a4a40", 0) + circ(106, 102, 8, "#6a3e36", 0) + circ(134, 124, 5, "#6a3e36", 0)
    sk = SKIN_Z[0]
    for x, y, a, sc in ((50, 258, -10, 1.0), (86, 238, 4, 1.15), (120, 224, -2, 1.3), (154, 240, 8, 1.15), (190, 260, -8, 1.0)):
        arm = limb([(0, 34), (0, 0)], 14, sk) + hand(0, -6, -math.pi / 2, 10, sk)
        s += g(arm, "translate(%d %d) rotate(%d) scale(%s)" % (x, y, a, f(sc)))
    s += path("M22 270 Q70 254 120 268 Q170 282 218 266 L218 314 L22 314 Z", INK, 0)
    s += "".join(line([(x, 276), (x + 8, 266)], 3, INK) for x in (40, 96, 150, 196))
    for cx, cy in ((40, 40), (200, 40), (40, 296), (200, 296)):
        s += g(poly([(0, -9), (7, 0), (0, 9), (-7, 0)], "#e2574c", 2.5), "translate(%d %d)" % (cx, cy))
    return svg(W, H, s, defs)


def back_room() -> str:
    """Room-deck back: district slate, brick wall, a door with a blank price tag and a key."""
    W, H = 240, 336
    defs = radial("rb", "#38424a", "#14181b", 0.5, 0.45, 0.75)
    s = rect(0, 0, W, H, "#14181b", 0) + rect(0, 0, W, H, "url(#rb)", 0)
    for r, y in enumerate(range(0, H, 20)):
        s += line([(0, y), (W, y)], 2, "#1f2529")
        s += "".join(line([(x, y), (x, y + 20)], 2, "#1f2529") for x in range((r % 2) * 20, W, 40))
    s += '<rect x="12" y="12" width="216" height="312" rx="12" fill="none" stroke="%s" stroke-width="4"/>' % BONE_D
    s += '<rect x="22" y="22" width="196" height="292" rx="8" fill="none" stroke="#b8c4c0" stroke-width="2"/>'
    s += rect(70, 90, 100, 170, "#2a2420", 5, rx=4) + rect(82, 102, 76, 158, "#6e3b30", 4, rx=3)
    s += rect(92, 114, 56, 56, "#5a2f27", 3, rx=2) + rect(92, 182, 56, 66, "#5a2f27", 3, rx=2)
    s += circ(146, 178, 5, BRASS[0], 3)
    s += lamp(120, 72, 9)
    # blank price tag hanging off the handle on a string
    s += line([(146, 182), (160, 210)], 2.5, BONE_D)
    s += g(path("M0 -14 L34 -14 L44 0 L34 14 L0 14 Z", BONE, 4) + circ(36, 0, 3.5, "#2a2420", 2), "translate(156 222) rotate(70) translate(-44 0)")
    # key
    s += g(circ(0, 0, 11, BRASS[0], 4) + circ(0, 0, 4, "#2a2420", 0) + limb([(10, 0), (46, 0)], 6, BRASS[0], 3)
           + rect(34, 2, 5, 9, BRASS[0], 2.5) + rect(42, 2, 5, 7, BRASS[0], 2.5), "translate(60 286) rotate(-12)")
    s += rect(22, 260, 196, 6, INK, 0, extra='opacity="0.5"')
    for cx, cy in ((40, 40), (200, 40), (40, 296), (200, 296)):
        s += g(poly([(0, -9), (7, 0), (0, 9), (-7, 0)], "#b8c4c0", 2.5), "translate(%d %d)" % (cx, cy))
    return svg(W, H, s, defs)


# ---------------------------------------------------------------- Patient Zero phases (240 x 180 finale cards)
def fin_patient_zero_2() -> str:
    """Phase 2 (10): the IV pole is down, the gown is torn, both arms reach, eyes burn brighter."""
    hr = (16, 18)
    hy = -54 - 52 - 5 - 18 + 4
    gown = ("#8fb0b8", "#6f8f98")
    rips = (path("M-22 -72 L-10 -66 L-18 -58", "none", 3) + path("M10 -90 L18 -80 L8 -76", "none", 3)
            + "".join(circ(x, y, 2, gown[1], 0) for x, y in ((-8, -92), (8, -96), (-14, -80))) + ell(14, -66, 4, 5, GORE, 0))
    pole = g(line([(0, 0), (120, 0)], 4, STEEL[1]) + line([(118, -10), (118, 10)], 4, STEEL[1])
             , "translate(30 154) rotate(-16)")
    body = zombie(0, 0, leg=54, torso=52, sw=23, hw=18, legw=13, armw=11, hr=hr, lean=-0.02, tilt=-6,
                  skin=SKIN_PZ, shirt=gown[0], pants=SKIN_PZ[1], shoe=SKIN_PZ[1], stance=10,
                  arms={"L": [(-22, -6), (-46, -26)], "R": [(22, -6), (46, -26)]}, sleeve=0.4, hemd=12,
                  hair=path("M-16 %s Q-15 %s -4 %s Q-6 %s -16 %s Z" % (f(hy - 2), f(hy - 20), f(hy - 18), f(hy - 8), f(hy - 2)), "#5a5048", 3),
                  torso_extra=rips)
    glow = circ(140, 36, 30, "#c27ce0", 0, extra='opacity="0.18"')
    return card_art("finale", g(body, "translate(148 %s) scale(0.92)" % (GROUND - 2)), extra_bg=pole + glow)


def fin_patient_zero_3() -> str:
    """Phase 3 (12): swollen and hunched, glowing violet veins, gown in shreds. Still mild: no wounds."""
    sk, sd = SKIN_PZ
    vein = PAL["finale"][3]
    s = limb([(-24, -56), (-30, -28), (-34, -4)], 22, sd) + ell(-36, -3, 16, 6, sd, 3)
    s += limb([(24, -56), (30, -28), (34, -4)], 22, sd) + ell(36, -3, 16, 6, sd, 3)
    s += limb([(-46, -108), (-78, -78), (-84, -40)], 24, sk) + hand(-84, -36, math.pi / 2 + 0.3, 13, sk)
    s += path("M-54 -118 Q0 -146 54 -118 Q62 -86 36 -58 L-36 -58 Q-62 -86 -54 -118 Z", sk)
    s += path("M-34 -124 Q0 -132 34 -124 L40 -70 L26 -60 L18 -72 L6 -58 L-6 -72 L-18 -60 L-30 -72 L-40 -66 Z", "#8fb0b8")
    s += "".join(path(d, "none", 3, stroke=vein) for d in ("M-48 -112 Q-40 -96 -46 -82", "M44 -110 Q36 -94 42 -80", "M-70 -80 Q-74 -64 -80 -56"))
    s += path("M-20 -100 L-10 -92 L-18 -84", "none", 3) + path("M12 -110 L22 -100", "none", 3)
    s += g(rect(-8, -3, 16, 6, BONE, 2.5), "translate(-83 -52) rotate(80)")
    s += limb([(46, -108), (80, -86), (92, -56)], 24, sk) + hand(92, -52, math.pi / 2 - 0.3, 13, sk)
    s += path("M70 -96 Q76 -84 86 -78", "none", 3, stroke=vein)
    s += zhead(2, -134, 15, 16, SKIN_PZ, 10, hair=path("M-13 -145 Q-12 -159 0 -157 Q-2 -150 -13 -145 Z", "#5a5048", 3))
    s += circ(-5, -135, 7, vein, 0, extra='opacity="0.35"') + circ(9, -134, 7, vein, 0, extra='opacity="0.35"')
    body = g(s, "matrix(0.9 0 0.05 0.9 138 %s)" % GROUND)
    glow = circ(140, 60, 64, "#c27ce0", 0, extra='opacity="0.16"') + circ(140, 60, 40, "#c27ce0", 0, extra='opacity="0.14"')
    return card_art("finale", body, extra_bg=glow)


BOSS_PHASES = {  # boss slug: [(phase number, zombie value, file id or None = reuse the finale card, maker)]
    "patient_zero": [(1, 8, None, None), (2, 10, "finale_patient_zero_phase2", fin_patient_zero_2),
                     (3, 12, "finale_patient_zero_phase3", fin_patient_zero_3)],
}


# ---------------------------------------------------------------- v4 placeholders (core-rules-v4.md
# section 12, board task dd-v4-impl). Simple shapes in the house style so nothing renders blank;
# the Sr Game Artist replaces them. Original designs, no shooter-series likenesses.
def gun_launcher() -> str:
    """Stovepipe Launcher: a fat olive tube with a flared muzzle, pistol grip, sight and one round."""
    olive, olive_d = "#6b7a3c", "#4a5628"
    s = rect(-92, -14, 170, 28, olive, 4, rx=8) + rect(70, -20, 22, 40, olive_d, 4, rx=4)
    s += rect(-98, -18, 14, 36, olive_d, 4, rx=3) + line([(-80, -6), (60, -6)], 3, "#9aab62")
    s += path("M-20 14 L-14 44 L2 44 L0 14 Z", POLYMER) + path("M14 14 L18 34 L30 34 L28 14 Z", POLYMER)
    s += rect(-30, -28, 24, 12, STEEL[1], 3.5, rx=2)
    s += g(ell(0, 0, 18, 8, COPPER[0], 3.5) + path("M14 -7 L30 0 L14 7 Z", "#b5402f", 3), "translate(108 0)")
    return weapon_card(g(s, "scale(0.86)"), -10, 132, 102)


def gun_sweeper() -> str:
    """Alley Sweeper: a sawn-off pump with a stubby wide barrel and a drum of small shells."""
    s = rect(-30, -12, 110, 14, STEEL[1], 4, rx=3) + rect(-30, 2, 90, 10, "#55636a", 4, rx=3)
    s += rect(4, 0, 34, 16, WOOD[0], 4, rx=4) + line([(8, 8), (34, 8)], 2.5, WOOD[1])
    s += path("M-30 -12 L-62 -6 L-92 26 L-74 34 L-44 10 L-30 10 Z", WOOD[0])
    s += circ(-22, 22, 16, "#3a3f47", 4) + "".join(circ(-22 + 9 * math.cos(a), 22 + 9 * math.sin(a), 3.2, BRASS[0], 0)
                                                   for a in (0, 1.57, 3.14, 4.71))
    s += line([(-26, -8), (74, -8)], 2.5, "#e1e8e5")
    return weapon_card(g(s, "scale(0.92)"), -12, 136, 100)


def w_pipe_wrench() -> str:
    """Pipe Wrench: red cast handle, steel hook jaw with teeth and the knurled adjuster ring."""
    s = limb([(-98, 0), (40, 0)], 16, "#b5402f") + line([(-90, -4), (30, -4)], 3, "#d76250")
    s += circ(-96, 0, 6, INK, 0)
    s += rect(34, -12, 30, 24, STEEL[1], 4, rx=3)
    s += path("M60 -12 L60 -40 L86 -40 L86 -30 L70 -30 L70 -12 Z", STEEL[0])
    s += path("M60 12 L60 26 L90 26 L90 16 L70 16 L70 12 Z", STEEL[0])
    s += "".join(line([(x, -30), (x + 3, -26)], 2.2, INK) for x in (72, 78, 84))
    s += rect(40, -18, 14, 36, "#8c9aa0", 3.5, rx=3) + "".join(line([(x, -16), (x, 16)], 1.8, INK) for x in (44, 48, 52))
    return weapon_card(s, -30, 124, 100)


def w_bare_hands() -> str:
    """Bare Hands: two taped fists (the melee slot when no weapon is held)."""
    sk, sd, tape = "#d8a882", "#b07e5a", "#e6e0cc"

    def fist(x, y, flip=1) -> str:
        s = rect(x - 30, y - 22, 60, 44, sk, 4, rx=14)
        s += "".join(line([(x + k, y - 20), (x + k, y - 4)], 3, sd) for k in (-14, 0, 14))
        s += rect(x - 30, y - 4, 60, 16, tape, 3.5, rx=4) + line([(x - 26, y + 4), (x + 26, y + 4)], 2, "#bdb5a0")
        s += path("M%s %s Q%s %s %s %s" % (f(x - 30 * flip), f(y + 6), f(x - 44 * flip), f(y + 10), f(x - 40 * flip), f(y + 26)), "none", 4)
        return s
    return card_art("weapon", fist(92, 96, 1) + fist(156, 104, -1), ground=False)


def pa_lockpick() -> str:
    s = rect(46, 60, 36, 32, BRASS[0], 4, rx=6) + path("M52 60 L52 46 Q64 30 76 46 L76 60", "none", 6)
    s += circ(64, 74, 5, INK, 0) + rect(62, 74, 4, 10, INK, 0)
    s += line([(84, 98), (104, 78), (108, 82)], 4, THREAD)
    return patch("#2e3a4a", "#d6a84a", s)


def pa_iron_stomach() -> str:
    s = path("M44 44 Q40 92 64 96 Q88 92 84 44 Z", "#8c9aa0") + line([(50, 56), (78, 56)], 3, INK)
    s += rect(56, 36, 16, 10, "#55636a", 3.5, rx=2) + plus(64, 74, 9, "#3fae5e", THREAD)
    return patch("#2e3a32", "#9fadb2", s)


def pa_adrenaline() -> str:
    s = poly([(70, 26), (44, 70), (62, 70), (54, 102), (86, 54), (66, 54)], "#f2d65c", 4)
    s += path("M28 82 Q36 76 40 84", "none", 3.5, stroke=THREAD) + path("M90 84 Q96 76 102 82", "none", 3.5, stroke=THREAD)
    return patch("#4a2a20", "#f2a03a", s)


def pa_grudge() -> str:
    s = circ(64, 64, 22, "#e2574c", 4) + circ(64, 64, 12, THREAD, 3.5) + circ(64, 64, 4, "#e2574c", 0)
    s += line([(64, 30), (64, 42)], 4, THREAD) + line([(64, 86), (64, 98)], 4, THREAD)
    s += line([(30, 64), (42, 64)], 4, THREAD) + line([(86, 64), (98, 64)], 4, THREAD)
    return patch("#3a1e22", "#e2574c", s)


def pa_show_off() -> str:
    s = star(64, 62, 24, "#f2d65c", 4) + "".join(line([(64 + 34 * math.cos(a), 62 + 34 * math.sin(a)),
                                                       (64 + 42 * math.cos(a), 62 + 42 * math.sin(a))], 3.5, THREAD)
                                                 for a in (0.3, 1.2, 2.0, 2.9, 3.8, 4.7, 5.6))
    return patch("#3a2448", "#f08cc0", s)


def pa_whetstone() -> str:
    s = rect(34, 70, 60, 20, "#8a826e", 4, rx=4) + line([(40, 76), (88, 76)], 2.5, "#bdb5a0")
    s += path("M44 66 L92 40 L98 48 L52 70 Z", STEEL[0])
    s += line([(96, 30), (104, 22)], 3.5, THREAD) + line([(102, 40), (112, 38)], 3.5, THREAD)
    return patch("#2a3036", "#b8c4c0", s)


def rg_heavy() -> str:  # One Shot: a single rocket over one socket
    s = path("M32 10 Q42 18 40 34 L24 34 Q22 18 32 10 Z", BONE, 3) + rect(24, 34, 16, 6, "#e2574c", 2.5)
    s += poly([(24, 34), (16, 44), (24, 40)], BONE_D, 2.5) + poly([(40, 34), (48, 44), (40, 40)], BONE_D, 2.5)
    s += circ(32, 50, 5, "none", 3)
    return glyph(s)


def rg_small() -> str:  # Small Fry: a small die face with a down chevron (6 or less)
    s = rect(10, 20, 26, 26, BONE, 3, rx=5) + "".join(circ(x, y, 2.6, INK, 0) for x in (17, 29) for y in (26, 33, 40))
    s += poly([(42, 30), (50, 42), (58, 30), (53, 30), (50, 34), (47, 30)], BONE, 2.5)
    return glyph(s)


GUNS_V4 = {  # file id: (maker, display name, sim id)
    "weapon_stovepipe_launcher": (gun_launcher, "Stovepipe Launcher", "launcher"),
    "weapon_alley_sweeper": (gun_sweeper, "Alley Sweeper", "sweeper"),
}
MELEE_V4 = {  # melee id: (file id, maker or None to reuse the v1 file, display name)
    "wrench": ("weapon_pipe_wrench", w_pipe_wrench, "Pipe Wrench"),
    "axe": ("weapon_fire_axe", None, "Fire Axe"),
    "sledge": ("weapon_sledgehammer", None, "Sledgehammer"),
    "bare_hands": ("weapon_bare_hands", w_bare_hands, "Bare Hands"),
}
PATCHES_V4 = {
    "lockpick": (pa_lockpick, "Lockpick"), "iron_stomach": (pa_iron_stomach, "Iron Stomach"),
    "adrenaline": (pa_adrenaline, "Adrenaline"), "grudge": (pa_grudge, "Grudge"),
    "show_off": (pa_show_off, "Show-Off"), "whetstone": (pa_whetstone, "Whetstone"),
}
RULE_GLYPHS_V4 = {"heavy": (rg_heavy, ["one_shot"]), "small": (rg_small, ["small_fry", "max_6"])}


# ---------------------------------------------------------------- catalogue
CARDS = {
    # id: (file, maker, kind, display name, values)
    "zombie_shambler": (z_shambler, "zombie", "Shambler", [2, 3, 4]),
    "zombie_lurcher": (z_lurcher, "zombie", "Lurcher", [5, 6, 7]),
    "zombie_bruiser": (z_bruiser, "zombie", "Bruiser", [8, 9, 10]),
    "zombie_hulk": (z_hulk, "zombie", "Hulk", [11, 12, 13, 14, 15, 16]),
    "weapon_broken_bottle": (w_bottle, "weapon", "Broken Bottle", [2]),
    "weapon_claw_hammer": (w_hammer, "weapon", "Claw Hammer", [3]),
    "weapon_crowbar": (w_crowbar, "weapon", "Crowbar", [4]),
    "weapon_cricket_bat": (w_cricket_bat, "weapon", "Cricket Bat", [5]),
    "weapon_machete": (w_machete, "weapon", "Machete", [6]),
    "weapon_fire_axe": (w_fire_axe, "weapon", "Fire Axe", [7]),
    "weapon_sledgehammer": (w_sledge, "weapon", "Sledgehammer", [8]),
    "weapon_chainsaw": (w_chainsaw, "weapon", "Chainsaw", [9]),
    "medkit_bandage": (m_bandage, "medkit", "Bandage", [2, 3]),
    "medkit_first_aid_kit": (m_first_aid, "medkit", "First Aid Kit", [4, 5, 6]),
    "medkit_trauma_kit": (m_trauma, "medkit", "Trauma Kit", [7, 8]),
    "barricade_plywood": (b_plywood, "barricade", "Plywood", [2]),
    "barricade_car_door": (b_car_door, "barricade", "Car Door", [3]),
    "barricade_dumpster": (b_dumpster, "barricade", "Dumpster", [4]),
}
FINALES = {
    "finale_the_groundskeeper": (fin_groundskeeper, "The Groundskeeper", "maple_row"),
    "finale_rush_hour_horde": (fin_horde, "Rush Hour Horde", "downtown"),
    "finale_patient_zero": (fin_patient_zero, "Patient Zero", "st_agnes"),
}
SURVIVORS = {"rosa": (sv_rosa, "Rosa Vance"), "imani": (sv_imani, "Dr. Imani Hale"), "theo": (sv_theo, "Theo Park")}
DISTRICTS = {"maple_row": (d_maple_row, "Maple Row"), "downtown": (d_downtown, "Downtown"), "st_agnes": (d_st_agnes, "St. Agnes Hospital")}
PERKS = {"thick_jacket": (p_thick_jacket, "Thick Jacket"), "fire_axe": (p_fire_axe, "Axe in the Trunk"),
         "field_kit": (p_field_kit, "Field Kit"), "knuckle_wraps": (p_knuckle_wraps, "Knuckle Wraps"),
         "sandbags": (p_sandbags, "Sandbags"), "scrounger": (p_scrounger, "Scrounger"),
         "second_wind": (p_second_wind, "Second Wind"), "tripwire": (p_tripwire, "Tripwire"),
         "fast_hands": (p_fast_hands, "Fast Hands"), "bandolier": (p_bandolier, "Bandolier")}
AMMO = {"ammo_box": (a_box, "Ammo Box", [3, 4]), "ammo_can": (a_can, "Ammo Can", [5, 6])}
DROPS = {"full_load": (d_full_load, "Full Load"), "payday": (d_payday, "Payday"), "boards": (d_boards, "Boards")}
CARRIERS = ["shambler", "lurcher", "bruiser", "hulk"]
# v2 weapon roster by sim id (tools/sim_deaddraw_v2.py CONFIG["weapons"]): new art + reused v1 melee art
WEAPONS_V2 = {"knife": "cards/weapon_kitchen_knife.svg", "crowbar": "cards/weapon_crowbar.svg",
              "bat": "cards/weapon_cricket_bat.svg", "machete": "cards/weapon_machete.svg",
              "axe": "cards/weapon_fire_axe.svg", "sledge": "cards/weapon_sledgehammer.svg"}


def main() -> None:
    res = "res://assets/art/"
    man = {
        "_note": "Generated by projects/deaddraw/tools/art/gen_art.py. Paths are relative to res://assets/art/. "
                 "Look up card art by display name (DDText.card_name) in by_name, or by kind + value in by_kind_value. "
                 "'art' holds flat file-id keys. Group order matters for DDArt: districts before finales so a bare "
                 "district id resolves to its banner.",
        "version": 1, "base": res,
        "sizes": {"card": [CW, CH], "card_back": [240, 336], "survivor": [200, 200], "district": [480, 160], "perk": [128, 128]},
        "number_safe_zone": {"card": [0, 0, 84, 70], "note": "top-left of card art kept quiet for a number badge"},
        "palette": {k: {"bg": v[0], "mid": v[1], "accent": v[3]} for k, v in PAL.items()},
        "art": {}, "by_name": {}, "by_kind_value": {"zombie": {}, "weapon": {}, "medkit": {}, "barricade": {}},
        "card_back": "cards/card_back.svg", "survivors": {}, "districts": {}, "perks": {}, "finales": {},
    }
    out = []

    def write(rel: str, text: str) -> None:
        p = ART / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
        out.append(rel)
        if rel.startswith("cards/"):
            man["art"][Path(rel).stem] = rel      # flat file-id keys (zombie_hulk, finale_patient_zero...)

    for cid, (maker, kind, name, values) in CARDS.items():
        rel = "cards/%s.svg" % cid
        write(rel, maker())
        man["by_name"][name] = rel
        for v in values:
            man["by_kind_value"][kind][str(v)] = rel
    for fid, (maker, name, district) in FINALES.items():
        rel = "cards/%s.svg" % fid
        write(rel, maker())
        man["by_name"][name] = rel
        man["finales"][district] = rel
        man["art"][fid.replace("finale_", "", 1)] = rel   # DDArt slug key, e.g. the_groundskeeper
    write("cards/card_back.svg", card_back())
    for sid, (maker, name) in SURVIVORS.items():
        rel = "survivors/%s.svg" % sid
        write(rel, maker())
        man["survivors"][sid] = rel
        man["by_name"][name] = rel
    for did, (maker, name) in DISTRICTS.items():
        rel = "districts/%s.svg" % did
        write(rel, maker())
        man["districts"][did] = rel
    for pid, (maker, name) in PERKS.items():
        rel = "perks/%s.svg" % pid
        write(rel, maker())
        man["perks"][pid] = rel
        man["by_name"][name] = rel
    # ------------------------------------------------ v2 groups (added after the v1 groups so a bare key
    # that both use, e.g. "payday", resolves to the first: the drop card before the Jawbreaker)
    man["version"] = 2
    man["sizes"].update({"machine": [CW, CH], "room": [CW, CH], "jawbreaker": [128, 128], "badge": [64, 64], "icon": [128, 128]})
    man["badge_placement"] = {"carrier": [6, 114, 54, 54], "note": "carrier badge on a 240x180 card: bottom-left "
                              "(x, y, w, h); the *_carrier card files already have it baked in"}
    man["weapons"], man["ammo"], man["drops"], man["carriers"] = {}, {}, {}, {}
    man["machines"], man["wall_racks"], man["jawbreakers"], man["rooms"] = {}, {}, {}, {}
    man["badges"], man["icons"] = {}, {}
    man["by_kind_value"]["ammo"] = {}
    man["by_kind_value"]["zombie_carrier"] = {}
    write("cards/weapon_kitchen_knife.svg", w_knife())
    man["by_name"]["Kitchen Knife"] = "cards/weapon_kitchen_knife.svg"
    for fid, (_m, _r, _x, _y, name, wid) in GUNS_V2.items():
        rel = "cards/%s.svg" % fid
        write(rel, gun_card(fid))
        man["by_name"][name] = rel
        WEAPONS_V2[wid] = rel
    man["weapons"].update(WEAPONS_V2)
    for aid, (maker, name, values) in AMMO.items():
        rel = "cards/%s.svg" % aid
        write(rel, maker())
        man["ammo"][aid] = rel
        for v in values:
            man["by_kind_value"]["ammo"][str(v)] = rel
    man["by_name"]["Ammo"] = man["ammo"]["ammo_box"]
    for did, (maker, name) in DROPS.items():
        rel = "cards/drop_%s.svg" % did
        write(rel, maker())
        man["drops"][did] = rel
        man["by_name"][name] = rel
    for zid in CARRIERS:
        rel = "cards/zombie_%s_carrier.svg" % zid
        write(rel, carrier_variant(CARDS["zombie_" + zid][0]()))
        man["carriers"][zid] = rel
        for v in CARDS["zombie_" + zid][3]:
            man["by_kind_value"]["zombie_carrier"][str(v)] = rel
    for mid, (maker, kind, name) in MACHINES.items():
        rel = "cards/%s.svg" % mid
        write(rel, maker())
        man["machines"][kind] = rel
        man["machines"][mid.replace("machine_", "", 1)] = rel
        man["by_name"][name] = rel
    for wid, (fid, maker, gname) in WALLRACKS.items():
        rel = "cards/%s.svg" % fid
        write(rel, wallrack(maker))
        man["wall_racks"][wid] = rel
        man["by_name"]["Wall Rack (%s)" % gname] = rel
    for jid, (maker, name, extra) in JAWBREAKERS.items():
        rel = "jawbreakers/%s.svg" % jid
        write(rel, maker())
        for k in [jid] + extra:
            man["jawbreakers"][k] = rel
        man["by_name"][name] = rel
    for did, rooms in ROOMS.items():
        for slug_, name, maker in rooms:
            rel = "rooms/%s_%s.svg" % (did, slug_)
            write(rel, maker())
            man["rooms"]["%s_%s" % (did, slug_)] = rel
            if slug_ != "entrance":
                man["rooms"][slug_] = rel
            man["by_name"][name] = rel
    for bid, maker in (("carrier", badge_carrier), ("locked", badge_locked), ("retrofit", badge_retrofit)):
        rel = "badges/%s.svg" % bid
        write(rel, maker())
        man["badges"][bid] = rel
    write("icons/wave.svg", icon_wave())
    man["icons"]["wave"] = "icons/wave.svg"
    man["by_name"]["Wave"] = "icons/wave.svg"
    # ------------------------------------------------ v3 groups (core-rules-v3.md, board task dd-v3-art).
    # Added after every v2 group and never re-using a v2 key, so all v1/v2 keys resolve as before
    # (DDArt keeps the first file it sees for a key). The v3 Patches share two names with v2 perks
    # ("Thick Jacket", "Second Wind"): by_name keeps the v2 perk; the Patch is "<Name> Patch" there
    # and patches_<id> / patch_<id> in DDArt.
    man["version"] = 3
    man["sizes"].update({"patch": [128, 128], "rule": [64, 64], "deck_back": [240, 336]})
    man["patches"], man["rules"], man["deck_backs"], man["boss_phases"] = {}, {}, {}, {}
    for fid, (_m, _r, _x, _y, name, wid) in GUNS_V3.items():
        rel = "cards/%s.svg" % fid
        write(rel, weapon_card_v3(fid))
        man["by_name"][name] = rel
        man["weapons"][wid] = rel
    for wid, (name, rel) in GUNS_V3_REUSE.items():
        man["by_name"].setdefault(name, rel)
        man["weapons"].setdefault(wid, rel)
    write("cards/machine_patch_press.svg", mc_patch_press())
    man["machines"]["patch"] = man["machines"]["patch_press"] = "cards/machine_patch_press.svg"
    man["by_name"]["Patch Press"] = "cards/machine_patch_press.svg"
    for wid, fid, maker, gname, sc in (("crossbow", "machine_wall_rack_ratchet_crossbow", gun_crossbow, "Ratchet Crossbow", 0.66),
                                       ("elephant", "machine_wall_rack_elephant_gun", gun_elephant, "Elephant Gun", 0.7)):
        rel = "cards/%s.svg" % fid
        write(rel, wallrack(maker, sc))
        man["wall_racks"][wid] = rel
        man["by_name"]["Wall Rack (%s)" % gname] = rel
    for pid, (maker, name, extra) in PATCHES.items():
        rel = "patches/%s.svg" % pid
        write(rel, maker())
        for k in [pid] + extra:
            man["patches"][k] = rel
        man["by_name"].setdefault(name, rel)
        man["by_name"]["%s Patch" % name] = rel
    for rid, (maker, extra) in RULE_GLYPHS.items():
        rel = "icons/rule_%s.svg" % rid
        write(rel, maker())
        for k in [rid] + extra:
            man["rules"][k] = rel
    for bid, maker in (("challenge", badge_challenge), ("challenge_open", badge_challenge_open), ("flip", badge_flip),
                       ("honed", badge_honed), ("no_escape", badge_no_escape), ("full_set", badge_full_set)):
        rel = "badges/%s.svg" % bid
        write(rel, maker())
        man["badges"][bid] = rel
    man["icons"]["challenge"] = "badges/challenge.svg"
    for bid, maker in (("wave_deck", back_wave), ("room_deck", back_room)):
        rel = "cards/back_%s.svg" % bid.replace("_deck", "")
        write(rel, maker())
        man["deck_backs"][bid] = rel
        man["deck_backs"][bid.replace("_deck", "")] = rel
    man["deck_backs"]["pile"] = "cards/card_back.svg"
    for boss, phases in BOSS_PHASES.items():
        base = man["art"][boss]
        for n, value, fid, maker in phases:
            rel = base if fid is None else "cards/%s.svg" % fid
            if maker is not None:
                write(rel, maker())
            man["boss_phases"]["%s_%d" % (boss, n)] = rel
            man["boss_phases"]["%s_v%d" % (boss, value)] = rel
    # ------------------------------------------------ v4 group (core-rules-v4.md, dd-v4-impl placeholders).
    # New keys only; "melee" maps a melee id (and bare_hands) to its card file.
    man["version"] = 4
    man["melee"] = {}
    for fid, (maker, name, wid) in GUNS_V4.items():
        rel = "cards/%s.svg" % fid
        write(rel, maker())
        man["by_name"][name] = rel
        man["weapons"][wid] = rel
    for mid, (fid, maker, name) in MELEE_V4.items():
        rel = "cards/%s.svg" % fid
        if maker is not None:
            write(rel, maker())
        man["melee"][mid] = rel
        man["by_name"].setdefault(name, rel)
    for pid, (maker, name) in PATCHES_V4.items():
        rel = "patches/%s.svg" % pid
        write(rel, maker())
        man["patches"][pid] = rel
        man["by_name"].setdefault(name, rel)
        man["by_name"]["%s Patch" % name] = rel
    for rid, (maker, extra) in RULE_GLYPHS_V4.items():
        rel = "icons/rule_%s.svg" % rid
        write(rel, maker())
        for k in [rid] + extra:
            man["rules"][k] = rel
    apply_painted(man)
    (ART / "manifest.json").write_text(json.dumps(man, indent=2) + "\n", encoding="utf-8")
    print("wrote %d svg files + manifest.json to %s" % (len(out), ART))


# ---------------------------------------------------------------- painted art (art pack 1, dd-art-import)
# Every SVG below is replaced in the manifest (in every group: by_name, by_kind_value, weapons, rooms...)
# by its painted WebP in assets/art/painted/ (made by tools/art/import_painted.py), but only when that
# file exists, so anything not painted or rejected in review keeps its SVG. The SVGs are still written
# and stay the fallback.
PAINTED = {
    "cards/zombie_shambler.svg": "dd_zombie_shambler", "cards/zombie_lurcher.svg": "dd_zombie_lurcher",
    "cards/zombie_bruiser.svg": "dd_zombie_bruiser", "cards/zombie_hulk.svg": "dd_zombie_hulk",
    "cards/finale_the_groundskeeper.svg": "dd_boss_groundskeeper", "cards/finale_rush_hour_horde.svg": "dd_boss_rush_hour_horde",
    "cards/finale_patient_zero.svg": "dd_boss_patient_zero_1", "cards/finale_patient_zero_phase2.svg": "dd_boss_patient_zero_2",
    "cards/finale_patient_zero_phase3.svg": "dd_boss_patient_zero_3",
    "cards/weapon_service_pistol.svg": "dd_gun_service_pistol", "cards/weapon_hunting_rifle.svg": "dd_gun_hunting_rifle",
    "cards/weapon_ratchet_crossbow.svg": "dd_gun_ratchet_crossbow", "cards/weapon_twin_bore.svg": "dd_gun_twin_bore",
    "cards/weapon_lever_rifle.svg": "dd_gun_lever_rifle", "cards/weapon_carbine.svg": "dd_gun_scout_carbine",
    "cards/weapon_nail_driver.svg": "dd_gun_nail_driver", "cards/weapon_pump_shotgun.svg": "dd_gun_pump_shotgun",
    "cards/weapon_elephant_gun.svg": "dd_gun_elephant_gun", "cards/weapon_stovepipe_launcher.svg": "dd_gun_stovepipe_launcher",
    "cards/weapon_alley_sweeper.svg": "dd_gun_alley_sweeper",
    "cards/weapon_bare_hands.svg": "dd_melee_bare_hands", "cards/weapon_pipe_wrench.svg": "dd_melee_pipe_wrench",
    "cards/weapon_fire_axe.svg": "dd_melee_fire_axe", "cards/weapon_sledgehammer.svg": "dd_melee_sledgehammer",
    "cards/medkit_bandage.svg": "dd_item_bandage", "cards/medkit_first_aid_kit.svg": "dd_item_first_aid_kit",
    "cards/medkit_trauma_kit.svg": "dd_item_trauma_kit",
    "cards/barricade_plywood.svg": "dd_cover_plywood", "cards/barricade_car_door.svg": "dd_cover_car_door",
    "cards/barricade_dumpster.svg": "dd_cover_dumpster",
    "cards/machine_retrofit_bench.svg": "dd_machine_retrofit_bench", "cards/machine_patch_press.svg": "dd_machine_patch_press",
    "cards/machine_wall_rack.svg": "dd_machine_wall_rack", "cards/machine_wall_rack_ratchet_crossbow.svg": "dd_machine_wall_rack_crossbow",
    "cards/machine_wall_rack_pump_shotgun.svg": "dd_machine_wall_rack_shotgun",
    "cards/machine_wall_rack_elephant_gun.svg": "dd_machine_wall_rack_elephant_gun",
    "cards/card_back.svg": "dd_back_pile", "cards/back_wave.svg": "dd_back_wave", "cards/back_room.svg": "dd_back_room",
    "badges/locked.svg": "dd_icon_locked", "badges/challenge.svg": "dd_icon_challenge_met",
    "badges/challenge_open.svg": "dd_icon_challenge_open", "icons/wave.svg": "dd_icon_wave",
}
for _d in ("maple_row", "downtown", "st_agnes"):
    PAINTED["districts/%s.svg" % _d] = "dd_district_" + _d
for _r in ("entrance", "garage", "corner_store", "workshop"):
    PAINTED["rooms/maple_row_%s.svg" % _r] = "dd_room_maple_row_" + _r
for _r in ("entrance", "subway_kiosk", "pawn_shop", "parking_garage"):
    PAINTED["rooms/downtown_%s.svg" % _r] = "dd_room_downtown_" + _r
for _r in ("entrance", "pharmacy", "security_office", "morgue_lab"):
    PAINTED["rooms/st_agnes_%s.svg" % _r] = "dd_room_st_agnes_" + _r
for _s in ("rosa", "imani", "theo"):
    PAINTED["survivors/%s.svg" % _s] = "dd_survivor_" + _s
for _p in ("lookout", "thick_jacket", "field_medic", "brawler", "bounty", "loose_grip", "second_wind", "trophy_belt",
           "lockpick", "iron_stomach", "adrenaline", "grudge", "show_off", "whetstone"):
    PAINTED["patches/%s.svg" % _p] = "dd_patch_" + _p


def apply_painted(man: dict) -> None:
    have = {svg: "painted/%s.webp" % stem for svg, stem in PAINTED.items() if (ART / "painted" / ("%s.webp" % stem)).exists()}
    if not have:
        return

    def swap(v):
        if isinstance(v, str):
            return have.get(v, v)
        if isinstance(v, dict):
            return {k: swap(x) for k, x in v.items()}
        if isinstance(v, list):
            return [swap(x) for x in v]
        return v

    for k in list(man.keys()):
        if k not in ("_note", "base", "sizes", "palette", "number_safe_zone", "badge_placement"):
            man[k] = swap(man[k])
    man["version"] = 5
    man["sizes"].update({"painted_card": [768, 512], "painted_room": [512, 512], "painted_district": [1536, 480],
                         "painted_survivor": [512, 512], "painted_back": [512, 768], "painted_patch": [256, 256],
                         "painted_icon": [128, 128], "painted_title": [1024, 1536]})
    # the title screen background: portrait art on phones; landscape art on desktop (until the retry lands,
    # the portrait art, which main.gd crops to its middle band behind a scrim)
    title = {}
    for orient in ("portrait", "landscape"):
        if (ART / "painted" / ("dd_title_%s.webp" % orient)).exists():
            title[orient] = "painted/dd_title_%s.webp" % orient
    if title:
        title.setdefault("landscape", title.get("portrait", ""))
        title.setdefault("portrait", title["landscape"])
        man["title"] = title
    man["_note"] += " v5: painted art pack 1 (assets/art/painted/*.webp) replaces the SVGs it covers; the SVGs stay the fallback."


if __name__ == "__main__":
    main()

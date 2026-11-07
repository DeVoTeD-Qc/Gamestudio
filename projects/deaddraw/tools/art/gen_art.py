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


# ---------------------------------------------------------------- catalogue
CARDS = {
    # id: (file, maker, kind, display name, values)
    "zombie_shambler": (z_shambler, "zombie", "Shambler", [2, 3, 4]),
    "zombie_lurcher": (z_lurcher, "zombie", "Lurcher", [5, 6, 7]),
    "zombie_bruiser": (z_bruiser, "zombie", "Bruiser", [8, 9, 10]),
    "zombie_hulk": (z_hulk, "zombie", "Hulk", [11, 12, 13, 14]),
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
         "second_wind": (p_second_wind, "Second Wind"), "tripwire": (p_tripwire, "Tripwire")}


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
    (ART / "manifest.json").write_text(json.dumps(man, indent=2) + "\n", encoding="utf-8")
    print("wrote %d svg files + manifest.json to %s" % (len(out), ART))


if __name__ == "__main__":
    main()

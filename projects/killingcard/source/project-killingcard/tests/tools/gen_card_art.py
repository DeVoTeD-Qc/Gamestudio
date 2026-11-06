# gen_card_art.py: regenerates scripts/ui/art/card_art_data.gd (v01 visual polish).
# Usage (from the project folder):
#   python3 tests/tools/gen_card_art.py scripts/ui/art/card_art_data.gd [preview_dir]
# With preview_dir it also writes every SVG as a file there for review (not part of the project).
#
# All art is ORIGINAL vector work for Killstreak: faceless, helmeted contractor silhouettes in
# generic gear, generic weapons, tactics diagrams, gadgets and the fictional Port Vasel container
# port. No franchise logos, HUDs, insignia, likenesses or map art. Style (art-direction.md):
# duotone dusk scene + one accent, strong rim-lit silhouettes, flat shapes, readable at thumb size.
# The SVGs are rasterised at runtime by scripts/ui/art/card_art.gd (Image.load_svg_from_string),
# at the size they are shown, so they stay crisp on a 3x phone and cost almost nothing in the pck.
# Only plain SVG is used (paths, rects, circles, linear/radial gradients, opacity): no filters,
# masks, patterns, <use> or text, so ThorVG renders it the same on every platform.
# Author: Sr Game Artist Agent (v01)
import math
import re
import os
import sys

W, H = 222, 136  # CardView art window (scenes/match/CardView.tscn ArtPanel)

# Palette (art-direction.md) plus scene tones.
SLATE = '#12161A'
FIG = '#0A0E11'       # silhouette fill
FIG_MID = '#1E272E'   # gear panels on the silhouette
AMBER = '#FFB020'
SODIUM = '#F0A040'
TEAL = '#2EC4B6'
RED = '#E5383B'
CYAN = '#5BC0EB'
BRASS = '#C9A227'
OLIVE = '#5B6B3A'
SAND = '#C2A878'
CONCRETE = '#7A828A'
FOG = '#D8DEE3'

_gid = [0]


def gid(prefix):
    _gid[0] += 1
    return '%s%d' % (prefix, _gid[0])


def P(pts):
    return 'M' + ' L'.join('%g %g' % (x, y) for x, y in pts) + ' Z'


def svg(body, w=W, h=H):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>'
            % (w, h, w, h, ''.join(body)))


def lin(stops, x2=0, y2=1):
    i = gid('l')
    s = ''.join('<stop offset="%g" stop-color="%s" stop-opacity="%g"/>' % (o, c, a) for o, c, a in stops)
    return i, '<linearGradient id="%s" x1="0" y1="0" x2="%g" y2="%g">%s</linearGradient>' % (i, x2, y2, s)


def rad(color, a0=0.6):
    i = gid('r')
    return i, ('<radialGradient id="%s"><stop offset="0" stop-color="%s" stop-opacity="%g"/>'
               '<stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient>' % (i, color, a0, color))


def glow(cx, cy, r, color, a0=0.6, defs=None):
    i, d = rad(color, a0)
    defs.append(d)
    return '<circle cx="%g" cy="%g" r="%g" fill="url(#%s)"/>' % (cx, cy, r, i)


# --- Backdrops --------------------------------------------------------------------------------

def sky(defs, top, mid, horizon, w=W, h=H, horizon_at=0.72):
    i, d = lin([(0, top, 1), (0.55, mid, 1), (horizon_at, horizon, 1), (1, horizon, 1)])
    defs.append(d)
    return '<rect width="%d" height="%d" fill="url(#%s)"/>' % (w, h, i)


def crane(x, base, s, color, op=1.0, flip=False):
    """Ship-to-shore gantry crane silhouette: A-frame legs, boom, trolley and cables."""
    d = -1 if flip else 1
    legs_h = 46 * s
    top = base - legs_h
    out = []
    lw = 3 * s
    out.append('<g fill="%s" stroke="%s" opacity="%g">' % (color, color, op))
    # two legs + cross beams
    for lx in (x, x + 18 * s * d):
        out.append('<rect x="%g" y="%g" width="%g" height="%g" stroke="none"/>' % (min(lx, lx + lw), top, lw, legs_h))
    out.append('<path d="M%g %g L%g %g M%g %g L%g %g" stroke-width="%g" fill="none"/>' % (
        x, top + 12 * s, x + 18 * s * d, top + 30 * s, x + 18 * s * d, top + 12 * s, x, top + 30 * s, 1.2 * s))
    # apex frame
    out.append('<path d="%s" stroke="none"/>' % P([(x, top), (x + 9 * s * d, top - 16 * s), (x + 18 * s * d + lw * d, top),
                                                   (x + 18 * s * d, top + 3 * s), (x + 9 * s * d, top - 11 * s), (x + lw * d, top + 3 * s)]))
    # boom: long out over the water, short back reach
    out.append('<rect x="%g" y="%g" width="%g" height="%g" stroke="none"/>' % (
        min(x - 16 * s * d, x + 70 * s * d), top - 4 * s, 86 * s, 3.2 * s))
    # stays from apex
    out.append('<path d="M%g %g L%g %g M%g %g L%g %g" stroke-width="%g" fill="none"/>' % (
        x + 9 * s * d, top - 16 * s, x + 66 * s * d, top - 3 * s, x + 9 * s * d, top - 16 * s, x - 14 * s * d, top - 3 * s, 0.9 * s))
    # trolley + hoist cables + spreader
    tx = x + 48 * s * d
    out.append('<rect x="%g" y="%g" width="%g" height="%g" stroke="none"/>' % (tx - 3 * s, top - 1 * s, 6 * s, 3 * s))
    out.append('<path d="M%g %g V%g M%g %g V%g" stroke-width="%g" fill="none"/>' % (
        tx - 2 * s, top + 2 * s, top + 22 * s, tx + 2 * s, top + 2 * s, top + 22 * s, 0.6 * s))
    out.append('<rect x="%g" y="%g" width="%g" height="%g" stroke="none"/>' % (tx - 6 * s, top + 22 * s, 12 * s, 2 * s))
    out.append('</g>')
    return ''.join(out)


def stack(x, base, cols, rows, cw, ch, colors, op=1.0, rib=None, seed=0):
    """Stacked shipping containers with corrugation ribs."""
    out = ['<g opacity="%g">' % op]
    k = seed
    for c in range(cols):
        hgt = rows - ((c * 7 + seed) % 2 if rows > 1 else 0)
        for r in range(hgt):
            col = colors[k % len(colors)]
            k += 3
            cx = x + c * cw
            cy = base - (r + 1) * ch
            out.append('<rect x="%g" y="%g" width="%g" height="%g" fill="%s"/>' % (cx + 0.4, cy + 0.4, cw - 0.8, ch - 0.8, col))
            if rib:
                n = max(3, int(cw / 3.2))
                ribs = ' '.join('M%g %g V%g' % (cx + 1.5 + i * (cw - 3) / n, cy + 1.5, cy + ch - 1.5) for i in range(1, n))
                out.append('<path d="%s" stroke="%s" stroke-width="0.6" fill="none"/>' % (ribs, rib))
    out.append('</g>')
    return ''.join(out)


def light_mast(x, base, h, color, defs, glow_color=SODIUM, a=0.55):
    return ('<rect x="%g" y="%g" width="1.6" height="%g" fill="%s"/>' % (x - 0.8, base - h, h, color) +
            '<path d="M%g %g h10 l-2 4 h-6 Z" fill="%s"/>' % (x - 5, base - h - 1, color) +
            glow(x, base - h + 4, 16, glow_color, a, defs) +
            '<path d="M%g %g h6 l-1 1.6 h-4 Z" fill="%s" opacity="0.9"/>' % (x - 3, base - h + 3, '#FFE3B0'))


def port_scene(defs, palette='dusk', w=W, h=H, ground=106, cranes=True):
    """Shared Port Vasel dusk backdrop for unit / operator art."""
    if palette == 'dusk':
        out = [sky(defs, '#121A20', '#25303A', '#7A5A3A', w, h)]
        haze, far, near = '#2C353D', '#222A31', '#182026'
    elif palette == 'teal':
        out = [sky(defs, '#0F1A1C', '#1C3233', '#4F6B57', w, h)]
        haze, far, near = '#24383A', '#1C2C2E', '#142022'
    elif palette == 'brass':
        out = [sky(defs, '#14181D', '#2B2C2C', '#8A6F3A', w, h)]
        haze, far, near = '#33322E', '#262725', '#1B1C1C'
    else:  # warm
        out = [sky(defs, '#1A1714', '#33291F', '#7A5230', w, h)]
        haze, far, near = '#3A2F25', '#2A231C', '#1E1915'
    out.append(glow(w * 0.78, ground - 30, 70, SODIUM, 0.35, defs))
    if cranes:
        out.append(crane(w * 0.56, ground - 6, 0.8, haze, 0.95))
        out.append(crane(w * 0.86, ground - 6, 0.62, haze, 0.8, flip=True))
    out.append(stack(w * 0.02, ground - 4, 6, 2, 12, 7, [far, haze, far], 0.95, rib=near, seed=1))
    out.append(stack(w * 0.62, ground - 4, 5, 3, 13, 7, [far, '#262F37', far], 0.95, rib=near, seed=2))
    out.append(light_mast(w * 0.43, ground - 4, 44, far, defs))
    out.append('<rect x="0" y="%g" width="%d" height="%g" fill="%s"/>' % (ground - 4, w, h - ground + 4, near))
    out.append('<path d="M0 %g H%d" stroke="%s" stroke-width="1" opacity="0.6"/>' % (ground - 4, w, SODIUM))
    return ''.join(out)


def topo_scene(defs, base='#15211E', line='#2A3D36', accent=TEAL, w=W, h=H):
    """Tactical map board: dark terrain with contour lines and a grid (tactic cards)."""
    out = [sky(defs, '#121C1A', base, '#1E2D28', w, h, 0.9)]
    for i in range(6):
        cx, cy = 40 + i * 37, 20 + (i * 53) % 110
        for r in (10, 18, 27):
            out.append('<ellipse cx="%g" cy="%g" rx="%g" ry="%g" fill="none" stroke="%s" stroke-width="0.8" opacity="0.7"/>'
                       % (cx, cy, r * 1.4, r, line))
    grid = ' '.join('M%d 0 V%d' % (x, h) for x in range(0, w, 22)) + ' ' + ' '.join('M0 %d H%d' % (y, w) for y in range(0, h, 22))
    out.append('<path d="%s" stroke="%s" stroke-width="0.6" opacity="0.35"/>' % (grid, accent))
    return ''.join(out)


def tablet_scene(defs, w=W, h=H):
    """Uplink feed backdrop (killstreak cards): deep cyan with range rings and a horizon."""
    out = [sky(defs, '#08141B', '#0E2633', '#16384A', w, h, 0.85)]
    out.append(glow(w * 0.5, h * 0.55, 110, CYAN, 0.18, defs))
    for r in (30, 55, 80):
        out.append('<circle cx="%g" cy="%g" r="%g" fill="none" stroke="%s" stroke-width="0.7" opacity="0.25"/>' % (w * 0.5, h * 0.55, r, CYAN))
    out.append('<path d="M%g %g H%g M%g %g V%g" stroke="%s" stroke-width="0.7" opacity="0.25"/>' % (0, h * 0.55, w, w * 0.5, 0, h, CYAN))
    return ''.join(out)


# --- Contractor figure --------------------------------------------------------------------------
# Local box: 100 units tall, feet at y=100, facing right. Generic helmeted contractor, faceless
# (visor / goggles + mask), plate carrier with pouches. Drawn twice: an offset rim-light copy,
# then the dark silhouette, which reads as a lit edge at any size.

def weapon(kind, x, y, s=1.0, ang=0.0, bipod=False):
    if kind == 'none':
        return ''
    parts = []
    if kind == 'ar':
        parts = [P([(0, 0), (6, -2), (36, -2), (36, 5), (24, 5), (22, 14), (17, 14), (19, 5), (8, 5), (1, 8)]),
                 'M36 -1 h17 v2.6 h-17 Z', P([(25, 5), (28, 14), (33, 14), (30, 5)]), 'M20 -5 h9 v3 h-9 Z']
    elif kind == 'smg':
        parts = [P([(0, 1), (30, 1), (30, 7), (20, 7), (19, 14), (14, 14), (15, 7), (0, 7)]),
                 'M30 2 h8 v2.4 h-8 Z', 'M21 7 h4 v11 h-4 Z', 'M14 -2 h8 v3 h-8 Z']
    elif kind == 'shotgun':
        parts = [P([(0, 2), (8, -1), (32, -1), (32, 5), (14, 5), (8, 9), (0, 9)]),
                 'M32 -0.5 h18 v2.6 h-18 Z', 'M32 2.6 h12 v4 h-12 Z']
    elif kind == 'sniper':
        parts = [P([(0, 1), (7, -2), (34, -2), (34, 4), (15, 4), (8, 9), (0, 9)]),
                 'M34 -1 h28 v2.2 h-28 Z', 'M13 -8 h16 v4.4 h-16 Z', 'M17 -4 h2 v2 h-2 Z M24 -4 h2 v2 h-2 Z',
                 'M60 -2 h4 v4 h-4 Z']
    elif kind == 'lmg':
        parts = [P([(0, 0), (6, -3), (42, -3), (42, 6), (10, 6), (3, 8)]), 'M42 -2 h18 v3.4 h-18 Z',
                 'M14 6 h12 v10 h-12 Z', 'M20 -7 h12 v2 h-12 Z M22 -5 h2 v2 h-2 Z M29 -5 h2 v2 h-2 Z']
        if bipod:
            parts.append('M52 1 L47 15 L49 15 L53.5 2 Z M53 1 L58 15 L60 15 L55 1 Z')
    elif kind == 'pistol':
        parts = ['M0 0 H19 V4.2 H0 Z', P([(1, 4), (16, 4), (16, 6.2), (8.5, 6.2), (6.5, 14.5), (1.2, 14.5), (2.4, 6.2), (1, 6.2)]),
                 'M8.5 6.2 Q9 9.5 12 9.5 L12.5 8.6 Q10.5 8.6 10.2 6.2 Z']
    return ('<g transform="translate(%g %g) rotate(%g) scale(%g)"><path d="%s"/></g>'
            % (x, y, ang, s, ' '.join(parts)))


def helmet(hx, hy):
    return ''.join([
        '<path d="M%g %g A12.5 12.5 0 0 1 %g %g L%g %g L%g %g Z"/>' % (hx - 12, hy + 3, hx + 13, hy + 3, hx + 14, hy + 6, hx - 12, hy + 6),
        '<rect x="%g" y="%g" width="5" height="5"/>' % (hx + 8, hy - 7),  # mount
        '<rect x="%g" y="%g" width="15" height="12" rx="3"/>' % (hx - 6, hy + 5),  # face / mask
        '<rect x="%g" y="%g" width="7" height="3.5"/>' % (hx - 2, hy + 21 - 4),  # neck
    ])


def helmet_detail(hx, hy, glint):
    return ''.join([
        '<path d="M%g %g A11 11 0 0 1 %g %g" fill="none" stroke="%s" stroke-width="1.4" opacity="0.8"/>' % (hx - 8, hy - 3, hx + 6, hy - 8, FIG_MID),
        '<circle cx="%g" cy="%g" r="3.4" fill="%s"/>' % (hx - 6, hy + 8, FIG_MID),  # ear protection
        '<rect x="%g" y="%g" width="9" height="3.6" rx="1.2" fill="%s"/>' % (hx + 1.5, hy + 6.5, glint),  # goggles
    ])


def torso(x0, y0, lean=0):
    # shoulders y0, waist y0+32
    return ''.join([
        '<path d="%s"/>' % P([(x0 - 13, y0), (x0 + 12, y0), (x0 + 11 + lean, y0 + 33), (x0 - 10 + lean, y0 + 33)]),
        '<rect x="%g" y="%g" width="24" height="23" rx="2"/>' % (x0 - 11, y0 + 3),
    ])


def torso_detail(x0, y0, accent, extra):
    out = ['<rect x="%g" y="%g" width="20" height="10" rx="1.5" fill="%s"/>' % (x0 - 9, y0 + 5, FIG_MID)]
    for i in range(3):
        out.append('<rect x="%g" y="%g" width="5.4" height="7" rx="1" fill="%s"/>' % (x0 - 9 + i * 7, y0 + 17, FIG_MID))
    if extra == 'medic':
        out.append('<rect x="%g" y="%g" width="8" height="8" fill="%s"/>' % (x0 - 4, y0 + 6, FOG))
        out.append('<path d="M%g %g h2.4 v-2.4 h2.4 v2.4 h2.4 v2.4 h-2.4 v2.4 h-2.4 v-2.4 h-2.4 Z" fill="%s"/>' % (x0 - 3.8, y0 + 8.8, RED))
    if extra == 'patch':
        out.append('<circle cx="%g" cy="%g" r="3.2" fill="%s"/>' % (x0 + 6, y0 + 9, accent))
    return ''.join(out)


def legs(pose, x0, y0):
    """x0 = hip centre, y0 = hip line."""
    if pose == 'stand':
        return ('<path d="%s"/>' % P([(x0 - 10, y0), (x0 - 1, y0), (x0 - 3, y0 + 18), (x0 - 5, y0 + 38), (x0 - 14, y0 + 38), (x0 - 12, y0 + 18)]) +
                '<path d="%s"/>' % P([(x0, y0), (x0 + 10, y0), (x0 + 13, y0 + 18), (x0 + 17, y0 + 38), (x0 + 8, y0 + 38), (x0 + 3, y0 + 18)]) +
                '<path d="M%g %g h12 v4 h-14 Z M%g %g h13 v4 h-13 Z"/>' % (x0 - 15, y0 + 36, x0 + 7, y0 + 36))
    if pose == 'wide':
        return ('<path d="%s"/>' % P([(x0 - 9, y0), (x0 + 1, y0), (x0 - 6, y0 + 18), (x0 - 12, y0 + 38), (x0 - 21, y0 + 38), (x0 - 15, y0 + 18)]) +
                '<path d="%s"/>' % P([(x0, y0), (x0 + 10, y0), (x0 + 17, y0 + 18), (x0 + 24, y0 + 38), (x0 + 15, y0 + 38), (x0 + 7, y0 + 18)]) +
                '<path d="M%g %g h12 v4 h-14 Z M%g %g h13 v4 h-13 Z"/>' % (x0 - 22, y0 + 36, x0 + 14, y0 + 36))
    if pose == 'run':
        return ('<path d="%s"/>' % P([(x0 - 8, y0 - 1), (x0 + 3, y0 + 1), (x0 + 14, y0 + 16), (x0 + 22, y0 + 32), (x0 + 15, y0 + 36), (x0 + 5, y0 + 20)]) +
                '<path d="%s"/>' % P([(x0 - 2, y0), (x0 + 6, y0 + 4), (x0 - 8, y0 + 20), (x0 - 24, y0 + 30), (x0 - 28, y0 + 24), (x0 - 14, y0 + 15)]) +
                '<path d="M%g %g l10 -3 l2 4 l-10 4 Z M%g %g l-4 -7 l5 -2 l4 8 Z"/>' % (x0 + 14, y0 + 33, x0 - 30, y0 + 28))
    if pose == 'kneel':
        return ('<path d="%s"/>' % P([(x0 - 2, y0), (x0 + 9, y0), (x0 + 24, y0 + 6), (x0 + 22, y0 + 14), (x0 + 6, y0 + 10)]) +
                '<path d="%s"/>' % P([(x0 + 15, y0 + 7), (x0 + 24, y0 + 7), (x0 + 25, y0 + 24), (x0 + 17, y0 + 24)]) +
                '<path d="M%g %g h13 v4 h-13 Z"/>' % (x0 + 15, y0 + 22) +
                '<path d="%s"/>' % P([(x0 - 11, y0), (x0, y0), (x0 - 4, y0 + 17), (x0 - 13, y0 + 17)]) +
                '<path d="%s"/>' % P([(x0 - 13, y0 + 13), (x0 - 4, y0 + 13), (x0 - 24, y0 + 26), (x0 - 31, y0 + 26), (x0 - 30, y0 + 21)]))
    return ''


def figure(x, y, s, pose='stand', gun='ar', extra='', glint=AMBER, rim=SODIUM, flip=False, aim=0.0):
    """Contractor at (x, y) = feet centre, scale s (100 units tall at s=1)."""
    shapes = []
    detail = []
    if pose == 'prone':
        # lying on the quay, sniper on a bipod, facing right
        shapes.append('<path d="%s"/>' % P([(8, 88), (24, 84), (56, 82), (66, 86), (64, 96), (24, 97), (6, 97)]))
        shapes.append('<path d="%s"/>' % P([(-26, 92), (8, 88), (8, 97), (-28, 98)]))
        shapes.append(helmet(72, 76))
        shapes.append('<path d="%s"/>' % P([(56, 84), (70, 88), (84, 92), (82, 97), (66, 95)]))
        shapes.append(weapon('sniper', 70, 86, 1.25, -4))
        shapes.append('<path d="M140 85 L134 98 L137 98 L142 86 Z M142 85 L148 98 L151 98 L144 85 Z"/>')
        detail.append(helmet_detail(72, 76, glint))
        if extra == 'ghillie':
            for i in range(9):
                shapes.append('<path d="M%g %g l4 -7 l3 7 Z"/>' % (-20 + i * 9, 86 - (i % 3)))
    else:
        if pose == 'kneel':
            hip = (48, 74); sh = (50, 44); head = (52, 28)
        elif pose == 'run':
            hip = (50, 62); sh = (56, 31); head = (60, 15)
        else:
            hip = (50, 62); sh = (50, 29); head = (51, 13)
        shapes.append(legs('wide' if pose in ('hip', 'shield') else ('stand' if pose == 'stand' else pose), hip[0], hip[1]))
        lean = 6 if pose == 'run' else 0
        shapes.append(torso(sh[0], sh[1], lean))
        if extra == 'pack':
            shapes.append('<rect x="%g" y="%g" width="10" height="24" rx="2"/>' % (sh[0] - 22, sh[1] + 2))
            shapes.append('<path d="M%g %g L%g %g" stroke="%s" stroke-width="1.6"/>' % (sh[0] - 18, sh[1] + 2, sh[0] - 26, sh[1] - 26, FIG))
            detail.append('<circle cx="%g" cy="%g" r="1.6" fill="%s"/>' % (sh[0] - 26, sh[1] - 26, RED))
        if extra == 'charge':
            shapes.append('<rect x="%g" y="%g" width="12" height="18" rx="2"/>' % (sh[0] - 24, sh[1] + 4))
            detail.append('<rect x="%g" y="%g" width="8" height="3" fill="%s"/>' % (sh[0] - 22, sh[1] + 8, AMBER))
        shapes.append(helmet(*head))
        detail.append(helmet_detail(head[0], head[1], glint))
        detail.append(torso_detail(sh[0], sh[1], glint, extra))
        sx, sy = sh
        if pose == 'shield':
            # ballistic shield held in front, pistol over the top edge
            shapes.append('<path d="M%g %g L%g %g" stroke="%s" stroke-width="6" stroke-linecap="round"/>' % (sx + 4, sy + 6, sx + 18, sy + 16, FIG))
            shapes.append(weapon('pistol', sx + 20, sy + 2, 1.2, -4))
            shapes.append('<path d="%s"/>' % P([(sx + 16, sy - 6), (sx + 34, sy - 10), (sx + 38, sy + 56), (sx + 18, sy + 64)]))
            detail.append('<path d="%s" fill="%s"/>' % (P([(sx + 22, sy - 1), (sx + 32, sy - 3), (sx + 32, sy + 4), (sx + 22, sy + 6)]), CYAN))
            detail.append('<path d="M%g %g L%g %g" stroke="%s" stroke-width="1.2" opacity="0.8"/>' % (sx + 19, sy + 12, sx + 35, sy + 9, FIG_MID))
            detail.append('<path d="M%g %g L%g %g" stroke="%s" stroke-width="1.2" opacity="0.8"/>' % (sx + 20, sy + 40, sx + 36, sy + 38, FIG_MID))
        elif pose == 'hip':
            shapes.append('<path d="%s"/>' % P([(sx + 6, sy + 1), (sx + 13, sy + 3), (sx + 16, sy + 20), (sx + 10, sy + 22)]))
            shapes.append('<path d="%s"/>' % P([(sx - 10, sy + 2), (sx - 3, sy + 2), (sx + 30, sy + 18), (sx + 28, sy + 24), (sx - 4, sy + 14)]))
            shapes.append(weapon(gun, sx - 6, sy + 18, 1.15, -6 + aim))
        else:
            # shouldered: rear arm to the stock, front arm to the fore-grip
            shapes.append('<path d="%s"/>' % P([(sx + 4, sy + 1), (sx + 12, sy + 3), (sx + 16, sy + 15), (sx + 9, sy + 17)]))
            shapes.append('<path d="%s"/>' % P([(sx - 9, sy + 2), (sx - 1, sy + 1), (sx + 32, sy + 9), (sx + 30, sy + 16), (sx - 2, sy + 11)]))
            gs = 1.25 if gun in ('sniper', 'lmg') else 1.15
            shapes.append(weapon(gun, sx + 4, sy + 7, gs, -3 + aim))
        if extra == 'flag':
            shapes.append('<rect x="%g" y="%g" width="2.2" height="70"/>' % (sx - 30, sy - 22))
            detail.append('<path d="%s" fill="%s"/>' % (P([(sx - 27.8, sy - 22), (sx - 6, sy - 18), (sx - 13, sy - 11), (sx - 6, sy - 4), (sx - 27.8, sy - 6)]), AMBER))
        if extra == 'binos':
            detail.append('<rect x="%g" y="%g" width="5" height="3" fill="%s"/>' % (head[0] + 10, head[1] + 6, glint))
    body = ''.join(shapes)
    tr = 'translate(%g %g) scale(%g %g)' % (x, y - 100 * s, -s if flip else s, s)
    d = -1.4 if not flip else 1.4
    return ('<g transform="%s">' % tr +
            '<g fill="%s" stroke="none" transform="translate(%g -1.1)">%s</g>' % (rim, d, body) +
            '<g fill="%s" stroke="none">%s</g>' % (FIG, body) +
            detail_wrap(''.join(detail)) + '</g>')


def detail_wrap(d):
    return '<g>%s</g>' % d


# --- Card illustrations -------------------------------------------------------------------------

def unit_card(fig_args, palette='dusk', extra_fx=''):
    defs = []
    body = [port_scene(defs, palette)]
    body.append(extra_fx)
    for fa in fig_args:
        fa = dict(fa)
        # v01 iteration: figures fill the art window (feet below the horizon, head near the top)
        fa['s'] = fa['s'] * 1.2
        fa['y'] = fa['y'] + 22
        fa['x'] = fa['x'] - 6
        body.append(figure(**fa))
    body.append(vignette(defs))
    return svg(['<defs>%s</defs>' % ''.join(defs)] + body)


def vignette(defs, w=W, h=H):
    i, d = lin([(0, SLATE, 0.0), (0.7, SLATE, 0.0), (1, SLATE, 0.55)])
    defs.append(d)
    return '<rect width="%d" height="%d" fill="url(#%s)"/>' % (w, h, i)


def muzzle(x, y, s=1.0, color=AMBER):
    return ('<path d="M%g %g l%g %g l%g %g l%g %g l%g %g l%g %g Z" fill="%s" opacity="0.95"/>' %
            (x, y, 8 * s, -4 * s, -3 * s, 4 * s, 9 * s, 0, -9 * s, 1 * s, 3 * s, 4 * s, color) +
            '<circle cx="%g" cy="%g" r="%g" fill="#FFE9B8"/>' % (x + 2 * s, y + 0.5 * s, 1.6 * s))


def tracer(x1, y1, x2, y2, color=AMBER, w=1.2, op=0.8):
    return '<path d="M%g %g L%g %g" stroke="%s" stroke-width="%g" stroke-linecap="round" opacity="%g"/>' % (x1, y1, x2, y2, color, w, op)


def cards():
    out = {}
    G = 106  # ground line
    out['rifleman'] = unit_card([dict(x=88, y=G, s=0.9, pose='stand', gun='ar')])
    out['point_man'] = unit_card([dict(x=92, y=G, s=0.88, pose='stand', gun='smg')],
                                 extra_fx=muzzle(150, 55, 1.0))
    out['breacher'] = unit_card([dict(x=86, y=G, s=0.92, pose='stand', gun='shotgun', glint=RED)], palette='warm',
                                extra_fx=door_frame(150, G))
    out['flanker'] = unit_card([dict(x=96, y=G, s=0.88, pose='run', gun='smg')],
                               extra_fx=dash_arrow(30, 118, 190, 96))
    out['marksman'] = unit_card([dict(x=90, y=G, s=0.92, pose='kneel', gun='sniper')],
                                extra_fx=tracer(150, 60, 222, 52, AMBER, 1.0, 0.7))
    out['gunner'] = unit_card([dict(x=84, y=G, s=0.92, pose='hip', gun='lmg')],
                              extra_fx=muzzle(150, 72, 1.1) + tracer(160, 72, 222, 66) + tracer(160, 74, 222, 80))
    out['demolitions_expert'] = unit_card([dict(x=88, y=G, s=0.9, pose='hip', gun='lmg', extra='charge', glint=RED)], palette='warm')
    out['combat_medic'] = unit_card([dict(x=84, y=G, s=0.92, pose='kneel', gun='ar', extra='medic', glint=TEAL, rim=TEAL)], palette='teal')
    out['recon_specialist'] = unit_card([dict(x=86, y=G, s=0.9, pose='stand', gun='ar', extra='pack', glint=CYAN, rim=CYAN)], palette='teal',
                                        extra_fx=mini_drone(170, 32, 0.9))
    out['shieldman'] = unit_card([dict(x=86, y=G, s=0.92, pose='shield', gun='pistol')],
                                 extra_fx=tracer(222, 40, 160, 56, RED, 1.0, 0.6) + tracer(222, 70, 168, 74, RED, 1.0, 0.6))
    out['sentry'] = unit_card([], extra_fx=turret(112, G, 1.15))
    out['okafor_anvil'] = unit_card([dict(x=90, y=G, s=0.94, pose='stand', gun='ar', extra='flag', glint=BRASS, rim=BRASS)], palette='brass',
                                    extra_fx='')
    out['halek_wren'] = unit_card([dict(x=70, y=G + 4, s=0.9, pose='prone', gun='sniper', extra='ghillie', glint=BRASS, rim=BRASS)], palette='brass',
                                  extra_fx=scope_glint(196, 38))
    # Squad-only units fall back to their class (see card_art.gd).
    # Tactics
    out['ammo_resupply'] = tactic_ammo()
    out['breach_and_clear'] = tactic_breach()
    out['callout'] = tactic_callout()
    out['flank_route'] = tactic_flank()
    out['hold_the_line'] = tactic_hold()
    out['suppressing_fire'] = tactic_suppress()
    # Equipment
    out['comms_relay'] = equip_relay()
    out['tripwire_charge'] = equip_tripwire()
    # Killstreaks
    out['recon_drone'] = ks_drone()
    out['mortar_barrage'] = ks_mortar()
    out['sentry_turret'] = ks_sentry()
    out['attack_helo'] = ks_helo()
    out['gunship'] = ks_gunship()
    # Operator weapons (kc-loadout-cut: the Frag Grenade / Flashbang / P-12 gear art is gone)
    out['kestrel_ar7'] = operator_card('ar')
    out['wasp_9'] = operator_card('smg')
    out['longreach_338'] = operator_card('sniper')
    return out


# Fallback keys share another card's art (no duplicate SVG in the build).
ALIASES = {
    'class_ar': 'rifleman', 'class_smg': 'point_man', 'class_shotgun': 'breacher', 'class_sniper': 'marksman',
    'class_lmg': 'gunner', 'type_unit': 'shieldman', 'type_tactic': 'callout', 'type_equipment': 'comms_relay',
    'type_killstreak': 'recon_drone', 'type_operator': 'kestrel_ar7',
    'ks_recon_drone': 'recon_drone', 'ks_mortar': 'mortar_barrage', 'ks_sentry': 'sentry_turret',
    'ks_attack_helo': 'attack_helo', 'ks_gunship': 'gunship',
}


def door_frame(x, g):
    return ('<rect x="%g" y="%g" width="44" height="74" fill="#2A221C"/>' % (x, g - 78) +
            '<rect x="%g" y="%g" width="34" height="70" fill="#120F0D"/>' % (x + 5, g - 74) +
            '<path d="M%g %g l18 -10 l-6 14 l16 2 l-18 8 Z" fill="%s" opacity="0.9"/>' % (x + 8, g - 40, AMBER) +
            '<path d="M%g %g l12 -6 M%g %g l14 3 M%g %g l10 9" stroke="#FFE3B0" stroke-width="1.4"/>' % (x + 20, g - 38, x + 20, g - 36, x + 20, g - 34))


def dash_arrow(x1, y1, x2, y2, color=AMBER):
    mx, my = (x1 + x2) / 2, min(y1, y2) - 40
    return ('<path d="M%g %g Q%g %g %g %g" fill="none" stroke="%s" stroke-width="2.2" stroke-dasharray="6 5" opacity="0.85"/>' % (x1, y1, mx, my, x2, y2, color) +
            '<path d="M%g %g l-9 -7 l1 11 Z" fill="%s"/>' % (x2 + 2, y2 + 1, color))


def mini_drone(x, y, s, color=FIG, light=CYAN):
    return ('<g transform="translate(%g %g) scale(%g)">' % (x, y, s) +
            '<path d="M-14 -2 H14 M-14 -2 v-3 M14 -2 v-3" stroke="%s" stroke-width="2"/>' % color +
            '<ellipse cx="-14" cy="-6" rx="9" ry="1.6" fill="%s" opacity="0.8"/><ellipse cx="14" cy="-6" rx="9" ry="1.6" fill="%s" opacity="0.8"/>' % (color, color) +
            '<rect x="-6" y="-4" width="12" height="7" rx="2" fill="%s"/>' % color +
            '<circle cx="0" cy="4" r="2" fill="%s"/></g>' % light)


def turret(x, g, s):
    return ('<g transform="translate(%g %g) scale(%g)">' % (x, g, s) +
            '<g fill="%s" transform="translate(-1.4 -1.1)">%s</g>' % (SODIUM, turret_shape()) +
            '<g fill="%s">%s</g>' % (FIG, turret_shape()) +
            '<rect x="2" y="-56" width="10" height="5" rx="1" fill="%s"/>' % RED +
            '</g>')


def turret_shape():
    return ('<path d="M-2 -40 L-26 0 L-21 0 L0 -34 L21 0 L26 0 L2 -40 Z"/>'
            '<rect x="-3" y="-44" width="6" height="40"/>'
            '<rect x="-16" y="-62" width="34" height="20" rx="4"/>'
            '<rect x="18" y="-56" width="40" height="4"/><rect x="18" y="-50" width="34" height="3"/>'
            '<rect x="-12" y="-42" width="14" height="10" rx="1"/>')


def scope_glint(x, y):
    defs = []
    return glow(x, y, 16, '#FFFFFF', 0.25, defs).replace('url(#', 'url(#') if False else (
        '<path d="M%g %g l2 -9 l2 9 l9 2 l-9 2 l-2 9 l-2 -9 l-9 -2 Z" fill="#FFF6DA" opacity="0.9"/>' % (x - 2, y - 2))


def tactic_wrap(content, accent=TEAL):
    defs = []
    body = [topo_scene(defs, accent=accent)]
    body.append(content(defs))
    body.append(vignette(defs))
    return svg(['<defs>%s</defs>' % ''.join(defs)] + body)


def tactic_ammo():
    def c(defs):
        o = [glow(111, 70, 70, SODIUM, 0.25, defs)]
        # crate
        o.append('<path d="%s" fill="#3C3426"/>' % P([(62, 80), (160, 80), (160, 120), (62, 120)]))
        o.append('<path d="%s" fill="#2B251C"/>' % P([(62, 80), (160, 80), (170, 66), (72, 66)]))
        o.append('<path d="%s" fill="#4A4030"/>' % P([(72, 66), (170, 66), (176, 44), (78, 44)]))  # open lid
        o.append('<path d="M62 92 H160 M62 108 H160" stroke="#1B1712" stroke-width="2"/>')
        o.append('<rect x="100" y="94" width="22" height="8" fill="%s"/>' % AMBER)
        # magazines standing in the crate
        for i in range(6):
            o.append('<path d="M%g 80 l2 -16 h7 l-2 16 Z" fill="%s"/>' % (80 + i * 12, '#11161A'))
            o.append('<rect x="%g" y="63" width="6" height="2" fill="%s"/>' % (82 + i * 12, SAND))
        # parachute lines
        o.append('<path d="M40 8 Q111 -14 182 8" fill="none" stroke="%s" stroke-width="2" opacity="0.6"/>' % FOG)
        o.append('<path d="M40 8 L72 44 M80 4 L90 44 M142 4 L150 44 M182 8 L170 44" stroke="%s" stroke-width="0.8" opacity="0.5"/>' % FOG)
        return ''.join(o)
    return tactic_wrap(c, SODIUM)


def tactic_breach():
    def c(defs):
        o = [glow(150, 70, 60, AMBER, 0.45, defs)]
        o.append('<rect x="120" y="22" width="60" height="100" fill="#2C3530"/>')
        o.append('<path d="%s" fill="#101614"/>' % P([(128, 28), (172, 28), (172, 122), (128, 122)]))
        # door blown inward
        o.append('<path d="%s" fill="#3E4A43"/>' % P([(172, 28), (196, 18), (196, 116), (172, 122)]))
        o.append('<path d="M150 70 l22 -14 l-8 18 l20 4 l-22 10 l4 18 l-16 -16 l-14 14 l2 -20 l-18 -4 l18 -8 Z" fill="%s" opacity="0.9"/>' % AMBER)
        o.append('<circle cx="152" cy="74" r="6" fill="#FFE9B8"/>')
        # stack of two contractors at the wall
        o.append(figure(78, 122, 0.82, 'stand', 'smg', rim=TEAL, glint=TEAL))
        o.append(figure(54, 122, 0.78, 'stand', 'shotgun', rim=TEAL, glint=TEAL))
        return ''.join(o)
    return tactic_wrap(c)


def tactic_callout():
    def c(defs):
        o = []
        # zone map with three lane boxes and red contacts revealed
        for i, x in enumerate((24, 86, 148)):
            o.append('<rect x="%g" y="26" width="52" height="84" rx="3" fill="#0F1715" stroke="%s" stroke-width="1.2" opacity="0.95"/>' % (x, TEAL))
        o.append(glow(112, 52, 34, RED, 0.5, defs))
        for cx, cy in ((104, 46), (122, 58), (112, 72)):
            o.append('<circle cx="%g" cy="%g" r="4.5" fill="%s"/><circle cx="%g" cy="%g" r="9" fill="none" stroke="%s" stroke-width="1" opacity="0.6"/>' % (cx, cy, RED, cx, cy, RED))
        # radio waves from a handset
        o.append('<rect x="38" y="70" width="16" height="30" rx="3" fill="%s"/><rect x="44" y="56" width="3" height="16" fill="%s"/>' % (FIG, FIG))
        o.append('<rect x="41" y="76" width="10" height="6" fill="%s"/>' % TEAL)
        for r in (10, 18, 26):
            o.append('<path d="M%g %g A%g %g 0 0 1 %g %g" fill="none" stroke="%s" stroke-width="1.8" opacity="0.8"/>' % (52, 60 - r * 0.6, r, r, 52 + r * 0.8, 60, AMBER))
        # waveform strip
        pts = ' '.join('%g %g' % (24 + i * 7.3, 120 + (5 if i % 2 else -5) * abs(math.sin(i * 1.3))) for i in range(25))
        o.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="1.4" opacity="0.8"/>' % (pts, TEAL))
        return ''.join(o)
    return tactic_wrap(c)


def tactic_flank():
    def c(defs):
        o = []
        # blocks (buildings) top-down
        for x, y, w, h in ((84, 34, 56, 56), (24, 92, 40, 30), (160, 20, 44, 34)):
            o.append('<rect x="%g" y="%g" width="%g" height="%g" fill="#24302B" stroke="#33443D" stroke-width="1"/>' % (x, y, w, h))
            o.append('<path d="M%g %g L%g %g M%g %g L%g %g" stroke="#1A2420" stroke-width="1"/>' % (x, y, x + w, y + h, x + w, y, x, y + h))
        # enemy contact behind the block
        o.append(glow(170, 92, 22, RED, 0.6, defs))
        o.append('<circle cx="170" cy="92" r="5" fill="%s"/>' % RED)
        # direct path blocked (x) and the flank route around
        o.append('<path d="M40 62 L80 62" stroke="%s" stroke-width="2" stroke-dasharray="4 4" opacity="0.5"/>' % FOG)
        o.append('<path d="M74 56 l10 10 M84 56 l-10 10" stroke="%s" stroke-width="2.4"/>' % RED)
        o.append('<path d="M40 62 C 40 120, 150 128, 162 98" fill="none" stroke="%s" stroke-width="3" stroke-dasharray="8 5"/>' % AMBER)
        o.append('<path d="M158 96 l10 -8 l0 13 Z" fill="%s"/>' % AMBER)
        o.append('<path d="M34 54 l12 8 l-12 8 Z" fill="%s"/>' % TEAL)
        return ''.join(o)
    return tactic_wrap(c, SODIUM)


def tactic_hold():
    def c(defs):
        o = [glow(110, 40, 80, SODIUM, 0.3, defs)]
        o.append('<rect x="0" y="100" width="222" height="36" fill="#121A17"/>')
        # sandbag wall
        for row in range(3):
            for i in range(9):
                x = 18 + i * 21 + (10 if row % 2 else 0)
                y = 102 - row * 11
                if x > 196:
                    continue
                o.append('<rect x="%g" y="%g" width="20" height="10" rx="5" fill="%s" stroke="#1E1A14" stroke-width="1"/>' % (x, y, '#6E6448' if row % 2 else '#7A6E50'))
        # helmets and muzzles over the wall
        for x in (50, 110, 170):
            o.append(figure(x, 112, 0.55, 'stand', 'ar', rim=SODIUM))
        o.append('<rect x="40" y="96" width="150" height="32" fill="#7A6E50" opacity="0"/>')
        # flag
        o.append('<rect x="200" y="20" width="2" height="72" fill="%s"/>' % FIG)
        o.append('<path d="M202 22 L222 26 L214 32 L222 38 L202 40 Z" fill="%s"/>' % TEAL)
        return ''.join(o)
    return tactic_wrap(c)


def tactic_suppress():
    def c(defs):
        o = [glow(60, 80, 50, AMBER, 0.35, defs)]
        for i in range(7):
            y = 30 + i * 9
            o.append(tracer(70, 82, 222, y + (i % 2) * 4, AMBER, 1.4 if i % 2 else 1.0, 0.75))
        # impacts on the far wall
        o.append('<rect x="176" y="20" width="46" height="96" fill="#26302B"/>')
        for i in range(7):
            o.append('<circle cx="%g" cy="%g" r="2.2" fill="#FFE3B0" opacity="0.9"/>' % (180 + (i * 7) % 20, 30 + i * 9 + (i % 2) * 4))
        # enemy keeping head down: suppression chevrons
        o.append('<path d="M196 52 l8 8 l8 -8 M196 64 l8 8 l8 -8" fill="none" stroke="%s" stroke-width="2.4"/>' % RED)
        o.append(figure(46, 122, 0.82, 'hip', 'lmg', rim=SODIUM))
        o.append(muzzle(80, 84, 1.2))
        return ''.join(o)
    return tactic_wrap(c, SODIUM)


def equip_wrap(content):
    defs = []
    body = [port_scene(defs, 'warm', cranes=False)]
    body.append(content(defs))
    # hazard tape strip along the bottom (gear-tag look; solid, not hazard stripes)
    body.append('<rect x="0" y="126" width="222" height="10" fill="%s" opacity="0.85"/>' % SAND)
    body.append(vignette(defs))
    return svg(['<defs>%s</defs>' % ''.join(defs)] + body)


def equip_relay():
    def c(defs):
        o = [glow(120, 36, 50, CYAN, 0.35, defs)]
        o.append('<rect x="92" y="88" width="56" height="30" rx="3" fill="#1A1714"/>')
        o.append('<rect x="98" y="94" width="18" height="10" fill="%s" opacity="0.9"/>' % TEAL)
        o.append('<circle cx="128" cy="99" r="3" fill="%s"/><circle cx="138" cy="99" r="3" fill="%s"/>' % (AMBER, FOG))
        o.append('<path d="M120 88 L120 30 M112 88 L120 50 L128 88" stroke="#1A1714" stroke-width="3" fill="none"/>')
        o.append('<circle cx="120" cy="28" r="3" fill="%s"/>' % RED)
        for r in (12, 22, 32):
            o.append('<path d="M%g %g A%g %g 0 0 1 %g %g" fill="none" stroke="%s" stroke-width="1.8" opacity="0.8"/>' % (120 - r, 28, r, r, 120 + r, 28, CYAN))
        return ''.join(o)
    return equip_wrap(c)


def equip_tripwire():
    def c(defs):
        o = [glow(60, 90, 40, RED, 0.35, defs)]
        o.append('<rect x="0" y="20" width="26" height="102" fill="#2A231C"/><rect x="196" y="20" width="26" height="102" fill="#2A231C"/>')
        o.append('<path d="M26 98 L196 92" stroke="%s" stroke-width="1.2" opacity="0.9"/>' % FOG)
        o.append('<path d="%s" fill="#1A1714"/>' % P([(40, 104), (78, 98), (82, 116), (42, 120)]))
        o.append('<path d="M46 120 l-4 6 M76 116 l4 6" stroke="#1A1714" stroke-width="2"/>')
        o.append('<circle cx="62" cy="106" r="2.4" fill="%s"/>' % RED)
        o.append('<path d="M78 104 L100 96" stroke="%s" stroke-width="1"/>' % FOG)
        # wire glint and a warning glow where it is anchored
        o.append('<circle cx="190" cy="92" r="3" fill="%s"/>' % AMBER)
        o.append(glow(190, 92, 14, AMBER, 0.5, defs))
        return ''.join(o)
    return equip_wrap(c)


def ks_wrap(content):
    defs = []
    body = [tablet_scene(defs)]
    body.append(content(defs))
    body.append(vignette(defs))
    return svg(['<defs>%s</defs>' % ''.join(defs)] + body)


def ks_drone():
    def c(defs):
        o = [glow(111, 52, 50, CYAN, 0.35, defs)]
        # scan cone onto port below
        o.append('<path d="M111 62 L52 130 L170 130 Z" fill="%s" opacity="0.14"/>' % CYAN)
        o.append(stack(40, 132, 8, 2, 18, 9, ['#11303E', '#163A4B'], 0.9, rib='#0B2230'))
        o.append(mini_drone(111, 50, 2.6, '#0A1A22', CYAN))
        for cx, cy in ((80, 118), (136, 114)):
            o.append('<path d="M%g %g h8 M%g %g v8" stroke="%s" stroke-width="1.6" transform="translate(-4 -4)"/>' % (cx, cy + 4, cx + 4, cy, RED))
            o.append('<rect x="%g" y="%g" width="14" height="14" fill="none" stroke="%s" stroke-width="1.2"/>' % (cx - 7, cy - 7, RED))
        return ''.join(o)
    return ks_wrap(c)


def ks_mortar():
    def c(defs):
        o = []
        o.append('<path d="M20 120 Q100 -10 196 104" fill="none" stroke="%s" stroke-width="1.6" stroke-dasharray="5 5" opacity="0.8"/>' % CYAN)
        o.append('<path d="M40 120 Q110 10 176 108" fill="none" stroke="%s" stroke-width="1.2" stroke-dasharray="4 6" opacity="0.5"/>' % CYAN)
        for x, r in ((188, 22), (166, 16)):
            o.append(glow(x, 112, r * 2, AMBER, 0.6, defs))
            o.append('<path d="M%g 120 l%g -%g l%g %g l%g -%g l%g %g Z" fill="%s"/>' % (x - r, r * 0.4, r * 0.9, r * 0.3, r * 0.5, r * 0.3, r * 1.1, r * 0.3, r * 0.9, AMBER))
        # tube + baseplate + bipod
        o.append('<path d="M22 124 L48 74" stroke="#05121A" stroke-width="9" stroke-linecap="round"/>')
        o.append('<path d="M10 126 H54 M38 96 L56 124" stroke="#05121A" stroke-width="3"/>')
        o.append('<path d="M46 72 L52 62" stroke="%s" stroke-width="2"/>' % AMBER)
        o.append('<rect x="0" y="124" width="222" height="12" fill="#06141B"/>')
        return ''.join(o)
    return ks_wrap(c)


def ks_sentry():
    def c(defs):
        o = [glow(130, 60, 40, CYAN, 0.3, defs)]
        o.append('<path d="M126 54 L222 34 L222 76 Z" fill="%s" opacity="0.12"/>' % CYAN)
        o.append('<rect x="0" y="118" width="222" height="18" fill="#06141B"/>')
        o.append('<g transform="translate(100 118) scale(1.15)"><g fill="#05121A">%s</g>'
                 '<rect x="2" y="-56" width="10" height="5" rx="1" fill="%s"/></g>' % (turret_shape(), CYAN))
        return ''.join(o)
    return ks_wrap(c)


def heli_shape():
    return ('<path d="M-46 -2 C-46 -16 -30 -22 -14 -22 H14 C30 -22 40 -12 40 0 V6 H-30 C-40 6 -46 4 -46 -2 Z"/>'
            '<path d="M36 -8 H96 L104 -22 H110 L106 -4 H40 Z"/>'
            '<rect x="-4" y="-30" width="6" height="8"/>'
            '<path d="M-30 12 H24 M-22 6 V12 M16 6 V12" stroke="#05121A" stroke-width="3"/>'
            '<rect x="-20" y="2" width="30" height="5" rx="2"/>')


def ks_helo():
    def c(defs):
        o = [glow(80, 60, 70, CYAN, 0.25, defs)]
        o.append(stack(10, 136, 12, 1, 18, 9, ['#11303E', '#163A4B'], 0.8, rib='#0B2230'))
        o.append('<g transform="translate(86 62) rotate(-6) scale(1.05)">')
        o.append('<ellipse cx="0" cy="-31" rx="74" ry="3" fill="%s" opacity="0.45"/>' % CYAN)
        o.append('<g fill="#05121A">%s</g>' % heli_shape())
        o.append('<path d="M-38 -10 C-36 -16 -28 -18 -20 -18 V-6 H-38 Z" fill="%s" opacity="0.9"/>' % CYAN)
        o.append('<circle cx="106" cy="-14" r="8" fill="none" stroke="%s" stroke-width="1" opacity="0.6"/>' % CYAN)
        o.append('</g>')
        o.append(tracer(56, 76, 20, 128, AMBER, 1.4, 0.8) + tracer(62, 76, 34, 130, AMBER, 1.0, 0.6))
        return ''.join(o)
    return ks_wrap(c)


def ks_gunship():
    def c(defs):
        o = []
        o.append('<ellipse cx="111" cy="70" rx="96" ry="40" fill="none" stroke="%s" stroke-width="1.4" stroke-dasharray="6 6" opacity="0.7"/>' % CYAN)
        o.append(stack(44, 104, 7, 2, 20, 10, ['#11303E', '#163A4B'], 0.85, rib='#0B2230'))
        for x, y in ((70, 84), (112, 78), (150, 86)):
            o.append(glow(x, y, 16, AMBER, 0.7, defs))
        o.append('<g transform="translate(150 34) rotate(14) scale(0.9)" fill="#05121A">'
                 '<path d="M-50 0 C-50 -6 -40 -8 -30 -8 H40 C48 -8 54 -4 56 0 C54 4 48 6 40 6 H-30 C-40 6 -50 6 -50 0 Z"/>'
                 '<path d="M-8 -6 L-30 -46 L-18 -46 L14 -6 Z M-8 6 L-30 46 L-18 46 L14 6 Z"/>'
                 '<path d="M-48 -2 L-60 -18 L-52 -18 L-40 -4 Z M-48 2 L-60 18 L-52 18 L-40 4 Z"/></g>')
        o.append(tracer(150, 40, 112, 78, AMBER, 1.2, 0.7) + tracer(146, 44, 72, 84, AMBER, 1.0, 0.5))
        return ''.join(o)
    return ks_wrap(c)


def operator_card(kind):
    defs = []
    body = [port_scene(defs, 'brass')]
    body.append(figure(70, 106, 0.94, 'stand', kind, glint=BRASS, rim=BRASS))
    body.append(vignette(defs))
    return svg(['<defs>%s</defs>' % ''.join(defs)] + body)


# --- Board tokens (unit slots): silhouette only, tinted in-engine -------------------------------

def tokens():
    out = {}
    TW, TH = 100, 110
    poses = {'ar': ('stand', 'ar'), 'smg': ('run', 'smg'), 'shotgun': ('stand', 'shotgun'), 'sniper': ('kneel', 'sniper'),
             'lmg': ('hip', 'lmg'), 'shield': ('shield', 'pistol'), 'operator': ('stand', 'ar')}
    for k, (pose, gun) in poses.items():
        g = figure(28 if pose != 'run' else 30, 106, 0.95, pose, gun, rim='#FFFFFF', glint='#FFFFFF')
        g = re.sub(r'#[0-9A-Fa-f]{6}', '#FFFFFF', g)
        out[k] = svg([g], TW, TH)
    tur = '<g transform="translate(40 106)"><g fill="#FFFFFF">%s</g></g>' % turret_shape()
    out['sentry'] = svg([tur], TW, TH)
    return out


# --- Lane backdrops (match board, low contrast) --------------------------------------------------

LW, LH = 400, 360


def lane_containers():
    c1, c2, rib = '#1E272E', '#232D35', '#182027'
    o = []
    o.append(stack(-10, 360, 7, 5, 62, 30, [c1, c2, '#202A2F'], 1.0, rib=rib, seed=1))
    o.append('<path d="M0 210 H400 M0 300 H400" stroke="#2A343C" stroke-width="2" opacity="0.6"/>')
    defs = []
    o.append(glow(330, 40, 120, SODIUM, 0.10, defs))
    # twist-lock corner castings + stenciled bay numbers as blocks
    for x in range(-10, 400, 62):
        for y in (330, 300, 270, 240, 210):
            o.append('<rect x="%g" y="%g" width="5" height="4" fill="#2C373F"/>' % (x + 2, y + 2))
    return svg(['<defs>%s</defs>' % ''.join(defs)] + o, LW, LH)


def lane_cranes():
    defs = []
    o = [glow(200, 60, 160, SODIUM, 0.08, defs)]
    o.append(crane(80, 360, 4.2, '#222C34', 1.0))
    o.append(crane(330, 360, 2.6, '#1E272E', 1.0, flip=True))
    # rails
    o.append('<path d="M0 330 H400 M0 344 H400" stroke="#2A343C" stroke-width="3"/>')
    for x in range(0, 400, 18):
        o.append('<rect x="%d" y="328" width="6" height="20" fill="#1C252B"/>' % x)
    return svg(['<defs>%s</defs>' % ''.join(defs)] + o, LW, LH)


def lane_offices():
    defs = []
    o = [glow(80, 120, 140, SODIUM, 0.08, defs)]
    o.append('<rect x="20" y="120" width="360" height="240" fill="#1E262D"/>')
    o.append('<rect x="20" y="108" width="360" height="14" fill="#232C34"/>')
    # windows (some lit)
    for row in range(2):
        for i in range(8):
            lit = (i * 3 + row) % 5 == 0
            o.append('<rect x="%d" y="%d" width="30" height="22" fill="%s"/>' % (38 + i * 43, 138 + row * 40, '#2A2721' if lit else '#161D22'))
    # roller doors
    for i in range(3):
        x = 40 + i * 118
        o.append('<rect x="%d" y="236" width="92" height="124" fill="#182026"/>' % x)
        o.append('<path d="%s" stroke="#222B32" stroke-width="2"/>' % ' '.join('M%d %d H%d' % (x, y, x + 92) for y in range(244, 360, 10)))
    o.append('<rect x="290" y="70" width="60" height="38" fill="#1C242A"/>')  # rooftop unit
    o.append('<path d="M300 70 V50 M300 50 H330" stroke="#1C242A" stroke-width="3"/>')
    return svg(['<defs>%s</defs>' % ''.join(defs)] + o, LW, LH)


# --- Title key art -------------------------------------------------------------------------------

KW, KH = 1280, 720


def key_art():
    defs = []
    o = [sky(defs, '#0B1014', '#172129', '#6A4A30', KW, KH, 0.66)]
    o.append(glow(980, 430, 520, SODIUM, 0.28, defs))
    o.append(glow(240, 470, 300, SODIUM, 0.16, defs))
    # far skyline: cranes and stacks
    for x, s, flip in ((520, 3.2, False), (760, 4.0, False), (1060, 3.0, True), (180, 2.6, True)):
        o.append(crane(x, 470, s, '#1E262D', 0.95, flip))
    o.append(stack(0, 476, 14, 3, 46, 22, ['#231F1D', '#1B2526', '#1C242A', '#21231C'], 1.0, rib='#151B20', seed=3))
    o.append(stack(700, 476, 14, 4, 46, 22, ['#2A2320', '#1D2A2B', '#24271F', '#1C242A'], 1.0, rib='#151B20', seed=5))
    for x in (380, 640, 1180):
        o.append(light_mast(x, 476, 170, '#161D22', defs, SODIUM, 0.5))
    # quay + water with reflections
    o.append('<rect x="0" y="472" width="%d" height="20" fill="#11171B"/>' % KW)
    i, d = lin([(0, '#141B20', 1), (1, '#0A0E11', 1)])
    defs.append(d)
    o.append('<rect x="0" y="492" width="%d" height="%d" fill="url(#%s)"/>' % (KW, KH - 492, i))
    for k in range(26):
        y = 500 + k * 8
        x = (k * 173) % 1100 + 80
        o.append('<rect x="%d" y="%d" width="%d" height="2" fill="%s" opacity="%g"/>' % (x, y, 60 + (k * 37) % 140, SODIUM, 0.25 - k * 0.008))
    # foreground quay with a squad silhouette on the right
    o.append('<path d="%s" fill="#0C1114"/>' % P([(820, 600), (1280, 560), (1280, 720), (760, 720)]))
    o.append('<path d="M820 600 L1280 560" stroke="%s" stroke-width="2" opacity="0.6"/>' % SODIUM)
    o.append(figure(1000, 598, 1.65, 'stand', 'ar'))
    o.append(figure(1120, 588, 1.85, 'shield', 'pistol'))
    o.append(figure(880, 606, 1.35, 'kneel', 'sniper'))
    i2, d2 = lin([(0, SLATE, 0.0), (0.75, SLATE, 0.0), (1, SLATE, 0.9)])
    defs.append(d2)
    o.append('<rect width="%d" height="%d" fill="url(#%s)"/>' % (KW, KH, i2))
    return svg(['<defs>%s</defs>' % ''.join(defs)] + o, KW, KH)


# --- Output ----------------------------------------------------------------------------------------

def gd_string(s):
    assert "'" not in s and '\\' not in s and '\n' not in s
    return "'" + s + "'"


def main():
    out_path = sys.argv[1]
    preview = sys.argv[2] if len(sys.argv) > 2 else None
    c = cards()
    t = tokens()
    lanes = {'containers': lane_containers(), 'cranes': lane_cranes(), 'offices': lane_offices()}
    ka = key_art()
    lines = [
        '# card_art_data.gd: GENERATED by tests/tools/gen_card_art.py (v01). Do not edit by hand:',
        '#   change the generator and run  python3 tests/tools/gen_card_art.py scripts/ui/art/card_art_data.gd',
        '# Original vector art (SVG text) for card illustrations, board tokens, lane backdrops and the',
        '# Title key art. Rasterised at runtime by card_art.gd at the size shown.',
        'extends RefCounted', '',
        'const CARD_SIZE: Vector2i = Vector2i(%d, %d)' % (W, H),
        'const TOKEN_SIZE: Vector2i = Vector2i(100, 110)',
        'const LANE_SIZE: Vector2i = Vector2i(%d, %d)' % (LW, LH),
        'const KEY_ART_SIZE: Vector2i = Vector2i(%d, %d)' % (KW, KH), '',
        'const CARDS: Dictionary = {',
    ]
    for k in sorted(c):
        lines.append('\t&"%s": %s,' % (k, gd_string(c[k])))
    lines.append('}')
    lines.append('')
    lines.append('const TOKENS: Dictionary = {')
    for k in sorted(t):
        lines.append('\t&"%s": %s,' % (k, gd_string(t[k])))
    lines.append('}')
    lines.append('')
    lines.append('const LANES: Dictionary = {')
    for k in sorted(lanes):
        lines.append('\t&"%s": %s,' % (k, gd_string(lanes[k])))
    lines.append('}')
    lines.append('')
    lines.append('const ALIASES: Dictionary = {')
    for k in sorted(ALIASES):
        lines.append('\t&"%s": &"%s",' % (k, ALIASES[k]))
    lines.append('}')
    lines.append('')
    lines.append('const KEY_ART: String = %s' % gd_string(ka))
    with open(out_path, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    total = sum(len(v) for v in c.values()) + sum(len(v) for v in t.values()) + sum(len(v) for v in lanes.values()) + len(ka)
    print('%d card illustrations, %d tokens, %d lanes, key art; %d bytes of SVG' % (len(c), len(t), len(lanes), total))
    if preview:
        os.makedirs(preview, exist_ok=True)
        for group, d in (('card', c), ('token', t), ('lane', lanes), ('key', {'art': ka})):
            for k, v in d.items():
                open(os.path.join(preview, '%s_%s.svg' % (group, k)), 'w').write(v)


if __name__ == '__main__':
    main()

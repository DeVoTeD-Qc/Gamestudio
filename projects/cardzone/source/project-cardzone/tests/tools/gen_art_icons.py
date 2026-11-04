# gen_art_icons.py: regenerates the CardZone stencil icon set, gear silhouettes and area glyphs (cz16).
# Adapted from CallingCard tests/tools/gen_art_icons.py (same pipeline, new art).
# Usage (from the project folder):
#   python3 tests/tools/gen_art_icons.py
# Writes:
#   assets/icons/<name>.svg          one file per icon / silhouette / glyph (Godot imports them as textures)
#   scripts/art/art_icon_data.gd     the same SVG text as constants; CzIcons rasterises it at runtime at the
#                                    size it is shown, so marks stay crisp on a 3x phone.
#
# Everything here is an ORIGINAL vector mark drawn for CardZone from the words in
# documentation/art/style-guides/art-direction.md sections 4-6. No brands, model names, insignia or fonts.
# Style (section 5): 24 pt grid, stencil-cut, one colour: solid shapes with 2 pt bridges (gaps), white on
# transparent and tinted at runtime. Silhouettes (section 6) are side views facing right on a 96 x 40 grid.
# Area glyphs (section 4) are top-down marks in basalt + rust on a 48 x 48 grid (real colours; CzIcons can
# recolour them for the gassed state). Only plain SVG (paths, circles, rects, strokes): no text, filters,
# masks or <use>, so ThorVG renders them the same on every platform.
# Author: Technical Artist Agent (cz16)
import os
import sys

W = '#FFFFFF'
BASALT = '#2F333B'
RUST = '#B0573A'
SCRUB = '#7A8466'
SHOAL = '#2C6E7F'


def svg(body, w=24, h=24):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>'
            % (w, h, w, h, ''.join(body)))


def fill(d, col=W, evenodd=False):
    rule = ' fill-rule="evenodd"' if evenodd else ''
    return '<path d="%s" fill="%s"%s/>' % (d, col, rule)


def stroke(d, w=2.5, col=W, cap='butt'):
    return ('<path d="%s" fill="none" stroke="%s" stroke-width="%g" stroke-linecap="%s" stroke-linejoin="miter"/>'
            % (d, col, w, cap))


def rect(x, y, w, h, col=W):
    return '<rect x="%g" y="%g" width="%g" height="%g" fill="%s"/>' % (x, y, w, h, col)


def circle(cx, cy, r, col=W, ring=0.0):
    if ring > 0.0:
        return '<circle cx="%g" cy="%g" r="%g" fill="none" stroke="%s" stroke-width="%g"/>' % (cx, cy, r, col, ring)
    return '<circle cx="%g" cy="%g" r="%g" fill="%s"/>' % (cx, cy, r, col)


def arc(cx, cy, r, a0, a1, w=2.5, col=W):
    """Stroked arc from angle a0 to a1 (degrees, 0 = right, clockwise in screen space)."""
    import math
    x0, y0 = cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0))
    x1, y1 = cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1))
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return stroke('M%.2f %.2f A%g %g 0 %d 1 %.2f %.2f' % (x0, y0, r, r, large, x1, y1), w, col)


def ring_stencil(cx, cy, r, w=2.5, gaps=(0, 90, 180, 270), gap_deg=26):
    """A ring broken by stencil bridges at the given angles."""
    out = []
    n = len(gaps)
    for i in range(n):
        a0 = gaps[i] + gap_deg / 2.0
        a1 = gaps[(i + 1) % n] - gap_deg / 2.0
        if a1 <= a0:
            a1 += 360
        out.append(arc(cx, cy, r, a0, a1, w))
    return out


def tag(x, y, w, h, c):
    """Clipped tag outline path: top-left and bottom-right corners cut at 45 degrees by c."""
    return 'M%g %g H%g V%g L%g %g H%g V%g Z' % (x + c, y, x + w, y + h - c, x + w - c, y + h, x, y + c)


ICONS = {}
SIL = {}
AREA = {}

# ================================================================================================
# Card types (section 5)
# ================================================================================================
# Crosshair-burst: a stencil ring with four outward ticks and a centre dot. Also "damage" and "shoot".
CROSSHAIR = ring_stencil(12, 12, 6.5, 2.6) + [
    rect(11, 1.5, 2, 5), rect(11, 17.5, 2, 5), rect(1.5, 11, 5, 2), rect(17.5, 11, 5, 2), circle(12, 12, 2.2)]
ICONS['weapon'] = svg(CROSSHAIR)
ICONS['damage'] = svg(CROSSHAIR)
# Crate: lid and two body planks with 2 pt bridges, plus a stencil cross on the front.
ICONS['item'] = svg([  # crate: a solid box with a stencil-cut X brace and lid line (evenodd cuts)
    fill('M3 3 H21 V21 H3 Z M6 8 H18 V18 H6 Z', evenodd=True),
    fill('M6 8 H8.5 L18 15.5 V18 H15.5 L6 10.5 Z'),
    fill('M18 8 V10.5 L8.5 18 H6 V15.5 L15.5 8 Z'),
])
# Rail clip: a rail with teeth and a clamp below.
CLIP = [rect(2, 6, 20, 3), rect(4, 3, 2, 3), rect(9, 3, 2, 3), rect(14, 3, 2, 3), rect(19, 3, 2, 3),
        fill('M5 11 H19 L16 15 H14 V21 H10 V15 H8 Z')]
ICONS['attachment'] = svg(CLIP)
ICONS['attach'] = svg(CLIP)
# Starter: an empty dashed clipped tag.
ICONS['starter'] = svg(['<path d="%s" fill="none" stroke="%s" stroke-width="2" stroke-dasharray="4 2.5"/>'
                        % (tag(3, 5, 18, 14, 4), W)])
# Hit: a shield split by a zig-zag crack (two halves with a gap).
ICONS['hit'] = svg([
    fill('M12 2 L3 5 V11 Q3 18 10.5 22 L9 15 L11.5 11 L9.5 7 Z'),
    fill('M14 2 L21 5 V11 Q21 18 13.5 22 L12 15 L14.5 11 L12.5 7 Z'),
])
# Bounty: a clipped tag with a star cut through it (evenodd hole) and a hanging hole.
STAR = 'M12 7.5 L13.5 11 L17.2 11.2 L14.3 13.5 L15.3 17.1 L12 15.1 L8.7 17.1 L9.7 13.5 L6.8 11.2 L10.5 11 Z'
ICONS['bounty'] = svg([fill(tag(3, 3, 18, 18, 5) + ' ' + STAR + ' M10.6 5.2 h2.8 v2 h-2.8 Z', evenodd=True)])

# ================================================================================================
# Stats and keywords
# ================================================================================================
ICONS['search'] = svg(ring_stencil(10, 10, 6, 3, gaps=(135,), gap_deg=40) + [
    fill('M14.5 16.6 L16.6 14.5 L22 19.9 L19.9 22 Z')])
# Boot print: sole and heel as two stencil parts.
ICONS['move'] = svg([
    fill('M9 2 Q15 2 15 8 Q15 12 13 14 H6 Q5 8 6 4 Q7 2 9 2 Z'),
    fill('M6.5 16 H13 V19 Q13 22 9.7 22 Q6.5 22 6.5 19 Z'),
    circle(18.5, 6, 1.6), circle(19.5, 10.5, 1.4),
])
# Range: concentric arcs from a base point, with three ticks (0 / 1 / 2).
ICONS['range'] = svg([
    circle(4, 20, 2.4),
    arc(4, 20, 8, -90, 0, 2.4), arc(4, 20, 15, -90, 0, 2.4),
    rect(1, 7.5, 3, 2), rect(1, 2.5, 3, 2),
])
SHIELD = 'M12 2 L21 5 V11 Q21 18 12 22 Q3 18 3 11 V5 Z'
ICONS['brace'] = svg([fill(SHIELD)])
ICONS['heal'] = svg([fill(tag(2, 2, 20, 20, 4) + ' M10 6 H14 V10 H18 V14 H14 V18 H10 V14 H6 V10 H10 Z', evenodd=True)])
ICONS['pull'] = svg([
    fill(tag(3, 9, 12, 13, 3)),
    fill('M18 2 L23 8 H20 V15 H16 V8 H13 Z'),
])
ICONS['spent'] = svg([
    fill(tag(5, 2, 14, 20, 3) + ' M7 18.5 L17 4.5 L18.6 5.7 L8.6 19.7 Z', evenodd=True),
])
ICONS['down'] = svg([
    fill('M2 6 L12 14 L22 6 V11 L12 19 L2 11 Z'),
])
ICONS['cover'] = svg([
    rect(2, 12, 9, 4), rect(13, 12, 9, 4), rect(2, 18, 4, 4), rect(8, 18, 8, 4), rect(18, 18, 4, 4),
    rect(7, 6, 10, 4),
])
ICONS['fires_twice'] = svg([
    fill('M3 4 L11 12 L3 20 V15 L6 12 L3 9 Z'),
    fill('M12 4 L20 12 L12 20 V15 L15 12 L12 9 Z'),
])

# ================================================================================================
# Map and Zone
# ================================================================================================
GAS = [circle(7, 16, 4.2), circle(13, 14, 5), circle(18.5, 16.5, 3.8), rect(3, 18.5, 19, 3.5),
       circle(10, 6.5, 2.4), circle(16, 5, 1.8)]
ICONS['gas'] = svg(GAS)
ICONS['safe_zone'] = svg(ring_stencil(12, 12, 8.5, 3))
ICONS['final_circle'] = svg(ring_stencil(12, 12, 8.5, 3) + [circle(12, 12, 3)])
ICONS['supply_drop'] = svg([
    fill('M3 9 Q12 -1 21 9 Z'),
    stroke('M4 10 L9.5 15 M20 10 L14.5 15', 1.6),
    rect(8, 15, 8, 7),
])
ICONS['crate_open'] = svg([
    fill('M2 6 L8 2 L10 4 L4 8 Z'), rect(3, 10, 18, 3), rect(3, 15, 8, 7), rect(13, 15, 8, 7),
])
ICONS['loot_pile'] = svg([
    fill(tag(8, 2, 13, 15, 3)), rect(5, 6, 2, 13), rect(5, 19, 13, 2), rect(2, 9, 2, 13),
])
ICONS['pawn_player'] = svg([fill('M12 1 A11 11 0 1 1 11.99 1 Z M6.5 15 L12 8 L17.5 15 L15 15 L12 11.5 L9 15 Z', evenodd=True)])
ICONS['pawn_ai'] = svg([fill('M12 1 A11 11 0 1 1 11.99 1 Z M8 8 H16 V16 H8 Z', evenodd=True)])
ICONS['zone_card'] = svg([  # a Zone card: clipped card with three gas blobs cut through it
    fill(tag(4, 2, 16, 20, 4) + ' M7.5 12 A2 2 0 1 1 7.6 12 Z M11 10 A2.6 2.6 0 1 1 11.1 10 Z'
         ' M14.6 12 A1.8 1.8 0 1 1 14.7 12 Z M7 15 H17 V17 H7 Z', evenodd=True)])
# Route tags: clipped tag with the letter cut as a stencil (strokes knocked out with evenodd holes).
ROUTE_LETTERS = {
    'a': 'M9 18 L11.2 7 H12.8 L15 18 H13.4 L12.9 15.4 H11.1 L10.6 18 Z M11.4 13.8 H12.6 L12 10.5 Z',
    'b': 'M9 7 H13 Q15.5 7 15.5 9.6 Q15.5 11.4 14 12 Q16 12.6 16 15 Q16 18 13 18 H9 Z M10.7 8.6 V11.4 H12.8 Q13.9 11.4 13.9 10 Q13.9 8.6 12.8 8.6 Z M10.7 13 V16.4 H13 Q14.3 16.4 14.3 14.7 Q14.3 13 13 13 Z',
    'c': 'M15.5 9.6 Q14.8 7 12.4 7 Q9 7 9 12.5 Q9 18 12.4 18 Q14.8 18 15.5 15.4 L14 15 Q13.6 16.4 12.4 16.4 Q10.7 16.4 10.7 12.5 Q10.7 8.6 12.4 8.6 Q13.6 8.6 14 10 Z',
}
for k, d in ROUTE_LETTERS.items():
    ICONS['route_' + k] = svg([fill(tag(3, 3, 18, 18, 5) + ' ' + d, evenodd=True)])
ICONS['padlock'] = svg([
    stroke('M7.5 11 V7.5 A4.5 4.5 0 0 1 16.5 7.5 V11', 2.6),
    fill('M4 11 H20 V22 H4 Z M11 14 H13 V19 H11 Z', evenodd=True),
])

# ================================================================================================
# Actions
# ================================================================================================
ICONS['play'] = svg([fill(tag(2, 4, 11, 16, 3)), fill('M14 7 L22 12 L14 17 Z')])
ICONS['hold'] = svg([
    fill('M8 2 H16 V4 H14.5 V10 L18 14 H6 L9.5 10 V4 H8 Z'),
    rect(11, 16, 2, 6),
])
ICONS['stow'] = svg([
    fill('M10 2 H14 V8 H18 L12 14 L6 8 H10 Z'),
    fill('M2 13 H5 V18 H19 V13 H22 V22 H2 Z'),
])
ICONS['end_turn'] = svg([
    arc(12, 12, 8, -160, 110, 3),
    fill('M3 4 L9.5 6 L4.5 10.5 Z'),
    rect(10.5, 7, 3, 6), rect(13.5, 12, 3.5, 2.6),
])
ICONS['undo'] = svg([
    fill('M2 9 L9 3 V6.5 H14 Q21 6.5 21 13.5 Q21 20.5 14 20.5 H8 V17 H14 Q17.5 17 17.5 13.5 Q17.5 10 14 10 H9 V15 Z'),
])
ICONS['shoot'] = svg(CROSSHAIR)
ICONS['loot'] = svg([
    rect(3, 12, 18, 3), rect(3, 17, 8, 5), rect(13, 17, 8, 5),
    fill('M10 1 H14 V6 H17 L12 11 L7 6 H10 Z'),
])
ICONS['patch_up'] = svg([
    fill('M5.5 9.5 L14.5 0.5 L23.5 9.5 L14.5 18.5 Z M12.5 6.5 H16.5 V8.5 H18.5 V10.5 H16.5 V12.5 H12.5 V10.5 H10.5 V8.5 H12.5 Z', evenodd=True),
    fill('M3.5 11.5 L12.5 20.5 L10 23 L1 14 Z'),
])
ICONS['ditch'] = svg([
    rect(4, 4, 16, 3), rect(9, 1.5, 6, 2),
    fill('M5 9 H19 L17.5 22 H6.5 Z M8.5 11 V20 H10.2 V11 Z M13.8 11 V20 H15.5 V11 Z', evenodd=True),
])
ICONS['adrenaline'] = svg([fill('M14 1 L4 13 H10.5 L8 23 L20 9.5 H13.5 L16.5 1 Z')])

# ================================================================================================
# Loadout and HUD
# ================================================================================================
ICONS['loadout'] = svg([rect(4, 2, 16, 4), rect(4, 8, 16, 4), rect(4, 14, 16, 4), rect(4, 20, 16, 2)])
ICONS['next_hand'] = svg([
    fill(tag(2, 9, 9, 13, 2)), fill(tag(13, 9, 9, 13, 2)),
    fill('M12 1 L18 3 V6 Q18 9.5 12 11.5 Q6 9.5 6 6 V3 Z'),
])
ICONS['health'] = svg([rect(5, 2, 14, 3.4), rect(5, 7.2, 14, 3.4), rect(5, 12.4, 14, 3.4), rect(5, 17.6, 14, 3.4)])
ICONS['round'] = svg(ring_stencil(12, 12, 9, 3, gaps=(-90,), gap_deg=36) + [fill('M10.5 6 H13.5 V12 L17 15.5 L15 17.5 L10.5 13 Z')])
ICONS['opp_hand'] = svg([
    fill(tag(2, 5, 10, 15, 2.5)), fill(tag(8, 3, 10, 15, 2.5) + ' M10 6 H16 V15 H10 Z', evenodd=True),
    fill(tag(14, 5, 8, 15, 2.5)),
])
EYE = 'M1.5 12 Q12 1 22.5 12 Q12 23 1.5 12 Z M12 7.5 A4.5 4.5 0 1 0 12.01 7.5 Z'
ICONS['public'] = svg([fill(EYE, evenodd=True), circle(12, 12, 2)])
ICONS['hidden'] = svg([
    fill(EYE, evenodd=True),
    fill('M3.3 21.6 L21.6 3.3 L23 4.7 L4.7 23 Z'),
])
ICONS['ai_thinking'] = svg([circle(5, 12, 2.6), circle(12, 12, 2.6), circle(19, 12, 2.6)])
ICONS['timer'] = svg(ring_stencil(12, 13.5, 8, 2.8, gaps=(-90,), gap_deg=34) + [
    rect(9, 1, 6, 2.5), fill('M11 8 H13 V14 H11 Z'),
])

# ================================================================================================
# Shell
# ================================================================================================
ICONS['info'] = svg(ring_stencil(12, 12, 9.5, 2.4, gaps=(90,), gap_deg=30) + [rect(10.7, 10, 2.6, 7.5), rect(10.7, 6, 2.6, 2.4)])
ICONS['pause'] = svg([rect(5, 3, 5, 18), rect(14, 3, 5, 18)])
ICONS['settings'] = svg([
    fill('M10 1 H14 L14.6 4 L17.5 5.6 L20.4 4.6 L22.4 8 L20 10 V14 L22.4 16 L20.4 19.4 L17.5 18.4 L14.6 20 L14 23 H10 '
         'L9.4 20 L6.5 18.4 L3.6 19.4 L1.6 16 L4 14 V10 L1.6 8 L3.6 4.6 L6.5 5.6 L9.4 4 Z '
         'M12 8.5 A3.5 3.5 0 1 0 12.01 8.5 Z', evenodd=True),
])
ICONS['close'] = svg([fill('M3 5 L5 3 L12 10 L19 3 L21 5 L14 12 L21 19 L19 21 L12 14 L5 21 L3 19 L10 12 Z')])
ICONS['back'] = svg([fill('M2 12 L11 3 V9 H22 V15 H11 V21 Z')])
ICONS['confirm'] = svg([fill('M2 12.5 L5 9.5 L9.5 14 L19 4.5 L22 7.5 L9.5 20 Z')])
ICONS['dev'] = svg([
    fill('M15 1.5 A6.5 6.5 0 0 0 9.2 10.6 L1.5 18.3 L5.7 22.5 L13.4 14.8 A6.5 6.5 0 0 0 22.5 9 L18.6 12.9 L14.6 12 L13.7 8 L17.6 4.1 '
         'A6.5 6.5 0 0 0 15 1.5 Z'),
])
ICONS['coach'] = svg([fill(tag(2, 2, 20, 15, 4) + ' M6 7 H18 V9 H6 Z M6 11 H14 V13 H6 Z', evenodd=True), fill('M6 17 H11 L6 22 Z')])
ICONS['hotseat'] = svg([
    fill('M2 7 L8 2 V5 H19 V9 H8 V12 Z'),
    fill('M22 17 L16 22 V19 H5 V15 H16 V12 Z'),
])

# ================================================================================================
# Gear silhouettes (section 6): side view facing right, 96 x 40 grid. Generic and fictional.
# ================================================================================================
def sil(*parts):
    return svg(list(parts), 96, 40)


SIL['sidearm'] = sil(  # short square slide, grip at ~100 deg, open-D trigger guard, no hammer
    fill('M30 9 H66 V18 H30 Z'),
    fill('M33 18 H47 L43 37 H31 Z'),
    fill('M47 18 H54 Q55 26 47 27 L46.5 24 Q51 24 50.5 21 H47 Z'),
)
SIL['smg'] = sil(  # stubby box body, straight vertical mag, folded wire-loop stock, welded patch plate
    fill('M30 10 H70 V22 H30 Z M48 13 H58 V18 H48 Z', evenodd=True),
    rect(70, 13, 12, 4),
    fill('M44 22 H51 V38 H44 Z'),
    fill('M34 22 H41 L39 32 H33 Z'),
    stroke('M30 12 H14 V20 H30', 2.5),
)
SIL['pump_shotgun'] = sil(  # long barrel over a tube, ribbed forend, straight solid stock
    rect(36, 9, 56, 4), rect(40, 14, 40, 4),
    fill('M52 13 H54 V22 H52 Z M56 13 H58 V22 H56 Z M60 13 H62 V22 H60 Z M64 13 H66 V22 H64 Z'),
    fill('M24 8 H38 V20 H24 Z'),
    fill('M24 12 L4 16 V25 L24 20 Z'),
    fill('M28 20 H33 L31 26 H27 Z'),
)
SIL['hunting_rifle'] = sil(  # slim one-piece stock, long thin barrel, bolt knob, no visible mag
    rect(40, 12, 54, 3),
    fill('M4 15 L22 12 H62 V17 H34 L28 21 L4 24 Z'),
    rect(36, 7, 2, 5), circle(37, 6.5, 2.2),
    fill('M30 17 H34 L32 22 H29 Z'),
)
SIL['assault_rifle'] = sil(  # mid-length angular receiver, mag angled 10 deg forward, flat top rail, block stock
    rect(64, 12, 26, 3),
    fill('M28 10 H66 V20 H36 L34 18 H28 Z'),
    rect(30, 6, 32, 3),
    fill('M44 20 H51 L55 35 H48 Z'),
    fill('M34 20 H40 L38 30 H32 Z'),
    fill('M6 10 H28 V20 H6 Z M10 13 H24 V17 H10 Z', evenodd=True),
)
SIL['marksman_rifle'] = sil(  # longest thin barrel, open skeleton stock, folded bipod, tall optic stub
    rect(52, 13, 43, 2.5),
    fill('M30 11 H58 V19 H30 Z'),
    rect(36, 3, 14, 5), rect(40, 8, 4, 3),
    fill('M44 19 H49 L50 27 H45 Z'),
    stroke('M30 13 H6 V22 L16 22 L30 17', 2.5),
    rect(60, 16, 22, 2.2),
)
SIL['lmg'] = sil(  # heavy square receiver, two round drums side by side, loop carry handle, bipod
    rect(62, 13, 30, 4),
    fill('M26 9 H64 V21 H26 Z'),
    stroke('M38 9 V4 H52 V9', 2.5),
    circle(38, 28, 7), circle(54, 28, 7),
    fill('M4 11 H26 V20 L4 24 Z'),
    stroke('M74 17 L68 33 M74 17 L80 33', 2.2),
)
SIL['anti_materiel'] = sil(  # widest: very long barrel, box muzzle brake, rear monopod spike, long scope
    rect(46, 15, 42, 3.4), rect(86, 12, 8, 9),
    fill('M18 12 H50 V22 H18 Z'),
    rect(24, 4, 30, 5), rect(30, 9, 3, 3), rect(44, 9, 3, 3),
    fill('M2 12 H18 V22 L2 26 Z'),
    fill('M8 24 H11 V36 L9.5 39 L8 36 Z'),
    fill('M30 22 H36 L34 30 H29 Z'),
)
SIL['long_scope'] = sil(  # hooded tube
    fill('M20 14 H72 V24 H20 Z'),
    fill('M72 11 H86 V27 H72 Z'),
    fill('M10 12 H20 V26 H10 Z'),
    rect(34, 24, 5, 5), rect(54, 24, 5, 5), rect(28, 29, 40, 3),
)
SIL['red_dot'] = sil(  # open square window
    fill('M32 6 H64 V30 H32 Z M37 11 H59 V25 H37 Z', evenodd=True),
    rect(26, 30, 44, 4), circle(48, 18, 2.2),
)
SIL['ext_mag'] = sil(  # tall stepped mag
    fill('M40 2 H56 V14 L58 16 V27 L60 29 V38 H44 V29 L42 27 V16 L40 14 Z'),
    rect(37, 2, 22, 3),
)
SIL['suppressor'] = sil(  # plain cylinder with two band rings
    fill('M12 13 H84 V27 H12 Z M28 13 H31 V27 H28 Z M64 13 H67 V27 H64 Z', evenodd=True),
    rect(6, 16, 6, 8),
)
SIL['frag'] = sil(  # ribbed rounded canister with a pull ring
    fill('M38 14 Q38 8 48 8 Q58 8 58 14 V30 Q58 37 48 37 Q38 37 38 30 Z '
         'M38 17 H58 V19 H38 Z M38 23 H58 V25 H38 Z M38 29 H58 V31 H38 Z', evenodd=True),
    rect(44, 4, 8, 4),
    '<circle cx="58" cy="5" r="3.5" fill="none" stroke="#FFFFFF" stroke-width="2"/>',
)
SIL['smoke'] = sil(  # tall can with a vent row
    fill('M40 6 H56 V38 H40 Z M42.5 9 H45 V12 H42.5 Z M46.8 9 H49.3 V12 H46.8 Z M51 9 H53.5 V12 H51 Z', evenodd=True),
    rect(44, 2, 8, 4), rect(56, 8, 3, 14),
)
SIL['plate_vest'] = sil(  # vest with one plate
    fill('M34 4 H42 Q48 10 54 4 H62 L66 12 V38 H30 V12 Z M40 16 H56 V30 H40 Z', evenodd=True),
    rect(42, 18, 12, 10),
)
SIL['heavy_plate'] = sil(  # vest with three stacked plates and a collar
    fill('M30 2 H66 V8 H30 Z'),
    fill('M32 9 H64 L68 14 V39 H28 V14 Z M36 14 H60 V19 H36 Z M36 22 H60 V27 H36 Z M36 30 H60 V35 H36 Z', evenodd=True),
)
SIL['phantom_suit'] = sil(  # hooded cloak with a frayed hem
    fill('M48 2 Q60 2 62 14 L70 38 L66 34 L62 38 L58 34 L54 38 L50 34 L46 38 L42 34 L38 38 L34 34 L30 38 L26 34 '
         'L34 14 Q36 2 48 2 Z M42 10 Q48 6 54 10 L53 17 H43 Z', evenodd=True),
)
SIL['boots'] = sil(
    fill('M22 6 H36 V24 L52 28 Q56 30 56 36 H22 Z'),
    fill('M52 6 H66 V24 L82 28 Q86 30 86 36 H52 V30 Q52 27 49 27 L52 26 Z'),
)
SIL['bandage'] = sil(
    fill('M36 6 A14 14 0 1 1 35.99 6 Z M36 15 A5 5 0 1 0 36.01 15 Z', evenodd=True),
    fill('M36 6 H80 V18 L76 22 L80 26 V34 H36 Z'),
)
SIL['medkit'] = sil(
    fill('M22 10 H74 V38 H22 Z M44 16 H52 V20 H56 V28 H52 V32 H44 V28 H40 V20 H44 Z', evenodd=True),
    stroke('M40 10 V4 H56 V10', 3),
)
SIL['crowbar'] = sil(
    fill('M8 30 L76 10 L78 12 L12 34 Z'),
    fill('M76 10 Q86 6 88 14 L84 15 Q83 11 78 12 Z'),
    fill('M8 30 L4 36 L7 37 L12 33 Z'),
)
SIL['backpack'] = sil(
    fill('M34 8 Q34 4 40 4 H56 Q62 4 62 8 V38 H34 Z M38 22 H58 V32 H38 Z', evenodd=True),
    stroke('M42 4 V1 H54 V4', 2.4),
    rect(40, 24, 16, 2),
)
SIL['drone'] = sil(
    rect(38, 16, 20, 9), rect(20, 18, 56, 3),
    rect(14, 13, 16, 2.4), rect(66, 13, 16, 2.4), rect(21, 15, 2, 3), rect(73, 15, 2, 3),
    rect(44, 25, 8, 4), circle(48, 31, 3),
)
SIL['pouch'] = sil(  # Scavenge: a cloth pouch with a flap
    fill('M30 12 H66 L70 38 H26 Z M30 12 L48 24 L66 12 Z', evenodd=True),
    rect(44, 6, 8, 6),
)
SIL['dash'] = sil(  # Dash: three speed bars and a forward chevron
    rect(10, 10, 30, 4), rect(18, 18, 30, 4), rect(10, 26, 30, 4),
    fill('M52 6 L72 20 L52 34 V26 L61 20 L52 14 Z'),
    fill('M70 6 L90 20 L70 34 V26 L79 20 L70 14 Z'),
)
SIL['duck'] = sil(  # Duck: a crouched figure behind a half wall
    circle(44, 11, 5),
    fill('M36 18 H54 L58 26 H32 Z'),
    rect(14, 26, 30, 6), rect(48, 26, 30, 6), rect(20, 33, 22, 6), rect(46, 33, 26, 6),
)

# ================================================================================================
# Area glyphs (section 4): top-down marks in basalt and rust on dune (48 x 48 grid).
# ================================================================================================
def area(*parts):
    return svg(list(parts), 48, 48)


AREA['area_docks'] = area(  # crane over a jetty, water
    rect(0, 34, 48, 14, SHOAL),
    rect(4, 30, 30, 5, RUST), rect(8, 35, 3, 8, BASALT), rect(26, 35, 3, 8, BASALT),
    rect(36, 6, 4, 28, BASALT), rect(14, 6, 30, 4, BASALT),
    stroke('M18 10 V22', 1.5, BASALT), rect(15, 22, 7, 5, RUST),
)
AREA['area_farmstead'] = area(  # silo and barn
    rect(26, 10, 12, 30, BASALT), fill('M26 10 Q32 2 38 10 Z', BASALT),
    fill('M4 24 L15 14 L26 24 V40 H4 Z', RUST), rect(11, 30, 8, 10, BASALT),
    rect(0, 40, 48, 3, '#7A8466'),
)
AREA['area_quarry'] = area(  # stepped terraces
    rect(2, 34, 44, 8, BASALT), rect(8, 26, 34, 6, BASALT), rect(14, 18, 22, 6, BASALT),
    rect(20, 10, 10, 6, BASALT), rect(34, 12, 8, 4, RUST),
)
AREA['area_radio_hill'] = area(  # lattice mast on a hill
    fill('M0 42 Q24 30 48 42 V48 H0 Z', '#7A8466'),
    stroke('M24 4 L16 38 M24 4 L32 38 M18.5 28 H29.5 M20.5 19 H27.5 M18.5 28 L27.5 19 M29.5 28 L20.5 19', 2, BASALT),
    circle(24, 4, 2.5, RUST),
)
AREA['area_motel'] = area(  # roadside sign
    fill(tag(8, 4, 32, 18, 5), RUST), rect(12, 9, 24, 3, '#D8C8A2'), rect(12, 14, 16, 3, '#D8C8A2'),
    rect(22, 22, 4, 20, BASALT), rect(4, 42, 40, 3, BASALT),
)
AREA['area_rail_yard'] = area(  # sidings: diverging tracks with sleepers and a wagon
    stroke('M2 38 H46 M2 30 H24 L40 18 H46', 2.4, BASALT),
    stroke('M6 35 V41 M12 35 V41 M18 35 V41 M24 35 V41 M30 35 V41 M36 35 V41 M42 35 V41', 1.6, BASALT),
    rect(8, 22, 14, 6, RUST),
)
AREA['area_old_town'] = area(  # roof cluster
    fill('M4 20 L12 12 L20 20 Z', RUST), rect(5, 20, 14, 12, BASALT),
    fill('M18 14 L28 4 L38 14 Z', RUST), rect(20, 14, 16, 14, BASALT),
    fill('M26 30 L35 22 L44 30 Z', RUST), rect(27, 30, 16, 12, BASALT),
    rect(8, 34, 16, 8, BASALT),
)

ALL = {}
ALL.update(ICONS)
ALL.update({'sil_' + k: v for k, v in SIL.items()})
ALL.update(AREA)
NAMES = sorted(ALL)


def write_gd(path):
    lines = [
        '# art_icon_data.gd',
        '# GENERATED by tests/tools/gen_art_icons.py (cz16). Do not edit by hand: edit the generator and re-run.',
        '# Purpose: SVG text of every CardZone icon (24 grid), gear silhouette (96 x 40, "sil_*") and area',
        '#   glyph (48 x 48, "area_*"). Original marks. CzIcons rasterises it at runtime.',
        '# Author: Technical Artist Agent (cz16)',
        'extends RefCounted',
        '',
        'const ICON_NAMES: Array[StringName] = [%s]' % ', '.join('&"%s"' % n for n in sorted(ICONS)),
        'const SILHOUETTE_NAMES: Array[StringName] = [%s]' % ', '.join('&"%s"' % n for n in sorted(SIL)),
        'const AREA_NAMES: Array[StringName] = [%s]' % ', '.join('&"%s"' % n for n in sorted(AREA)),
        'const SVG: Dictionary = {',
    ]
    for n in NAMES:
        lines.append('\t&"%s": \'%s\',' % (n, ALL[n]))
    lines.append('}')
    with open(path, 'w') as f:
        f.write('\n'.join(lines) + '\n')


def main():
    root = os.getcwd()
    out_dir = os.path.join(root, 'assets', 'icons')
    os.makedirs(out_dir, exist_ok=True)
    for n in NAMES:
        with open(os.path.join(out_dir, n + '.svg'), 'w') as f:
            f.write(ALL[n])
    write_gd(os.path.join(root, 'scripts', 'art', 'art_icon_data.gd'))
    print('wrote %d marks (%d icons, %d silhouettes, %d area glyphs)' % (len(NAMES), len(ICONS), len(SIL), len(AREA)))


if __name__ == '__main__':
    sys.exit(main())

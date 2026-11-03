# gen_art_icons.py: regenerates the Banner Wall icon set (cc14).
# Usage (from the project folder):
#   python3 tests/tools/gen_art_icons.py
# Writes:
#   assets/icons/<name>.svg          one file per icon (imported by Godot as textures, for TextureRect use)
#   scripts/art/art_icon_data.gd     the same SVG text as constants; ArtIcons rasterises it at runtime
#                                    at the size it is shown, so icons stay crisp on a 3x phone.
#
# All icons are ORIGINAL vector marks drawn for this project from the words in
# documentation/art/style-guides/art-direction.md section 2 (trait icons) and banner-wall-spec.md
# section 5 (cipher glyphs). No franchise emblems, rank insignia, logos or fonts.
# Style: 48x48 grid, white on transparent (tinted at runtime with modulate), 4 px strokes with
# round caps so they read at 16-20 px. Only plain SVG (paths, circles, rects, strokes): no text,
# filters, masks or <use>, so ThorVG renders them the same on every platform.
# Author: Technical Artist Agent (cc14)
import os
import sys

S = 48
W = '#FFFFFF'


def svg(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>'
            % (S, S, S, S, ''.join(body)))


def stroke(d, w=4, extra=''):
    return ('<path d="%s" fill="none" stroke="%s" stroke-width="%g" stroke-linecap="round" '
            'stroke-linejoin="round"%s/>' % (d, W, w, extra))


def fill(d, op=1.0):
    return '<path d="%s" fill="%s" fill-opacity="%g"/>' % (d, W, op)


def circle(cx, cy, r, filled=True, w=4, op=1.0):
    if filled:
        return '<circle cx="%g" cy="%g" r="%g" fill="%s" fill-opacity="%g"/>' % (cx, cy, r, W, op)
    return '<circle cx="%g" cy="%g" r="%g" fill="none" stroke="%s" stroke-width="%g"/>' % (cx, cy, r, W, w)


ICONS = {}

# --- Traits (art-direction section 2) -----------------------------------------------------------
# Steady = anchor bar: a heavy base plate with a post and a hub, "planted".
ICONS['trait_steady'] = svg([
    fill('M6 36 H42 V43 H6 Z'),
    fill('M21 12 H27 V37 H21 Z'),
    circle(24, 11, 6.5, False, 4),
    stroke('M13 29 L21 29 M27 29 L35 29', 4),
])
# Veteran = double chevron pointing up.
ICONS['trait_veteran'] = svg([
    stroke('M9 24 L24 12 L39 24', 6),
    stroke('M9 38 L24 26 L39 38', 6),
])
# Ambush = closed eye: lower-lid arc with lashes falling down.
ICONS['trait_ambush'] = svg([
    stroke('M5 20 Q24 38 43 20', 4.5),
    stroke('M12 28 L8 35 M20 32 L18 40 M28 32 L30 40 M36 28 L40 35', 3.5),
])
# Reclaim = curved arrow turning back on itself.
ICONS['trait_reclaim'] = svg([
    stroke('M36 34 A14 14 0 1 1 38 17', 5),
    fill('M31 9 L44 13 L36 24 Z'),
])
# Clutch = lightning tick: a check mark whose long stroke is a bolt.
ICONS['trait_clutch'] = svg([
    stroke('M5 26 L15 37 L24 23 L29 29 L43 7', 5),
])
# Cipher = keyhole in a rounded plate.
ICONS['trait_cipher'] = svg([
    '<rect x="7" y="5" width="34" height="38" rx="7" fill="none" stroke="%s" stroke-width="4"/>' % W,
    circle(24, 19, 6),
    fill('M21 22 H27 L29.5 35 H18.5 Z'),
])

# --- Cipher glyphs (spec section 5): four original marks, hidden in the art of cards 1, 5, 9, 13 --
ICONS['cipher_1'] = svg([  # "hook": a stem with a hooked head and a satellite dot
    stroke('M18 42 V14 Q18 6 26 6 Q33 6 33 13', 4.5),
    circle(34, 30, 4),
])
ICONS['cipher_2'] = svg([  # "split": a diamond cut by a bar that overshoots one side
    stroke('M24 5 L41 24 L24 43 L7 24 Z', 4),
    stroke('M3 24 H33', 4),
])
ICONS['cipher_3'] = svg([  # "rays": three strokes fanning from a footing
    stroke('M10 42 H38', 4.5),
    stroke('M24 42 V8 M24 42 L10 14 M24 42 L38 14', 4),
])
ICONS['cipher_4'] = svg([  # "ladder": two rails, one slanted rung, a ring on top
    stroke('M14 44 V18 M34 44 V18', 4),
    stroke('M14 38 L34 26', 4),
    circle(24, 10, 6, False, 4),
])

# --- Set glyphs -----------------------------------------------------------------------------------
ICONS['set_night_shift'] = svg([  # crescent and a lit window
    fill('M30 6 A18 18 0 1 0 42 32 A14 14 0 1 1 30 6 Z'),
    '<rect x="30" y="16" width="8" height="10" fill="%s"/>' % W,
])
ICONS['set_whiteout'] = svg([  # six-arm crystal
    stroke('M24 4 V44 M6.7 14 L41.3 34 M6.7 34 L41.3 14', 4),
    stroke('M19 8 L24 12 L29 8 M19 40 L24 36 L29 40', 3),
])
ICONS['set_signal_fire'] = svg([  # a flare rising on an arc with a starburst
    stroke('M6 44 Q12 18 30 14', 4),
    circle(33, 13, 5),
    stroke('M33 3 V6 M43 13 H40 M40 6 L38 8 M40 20 L38 18 M26 6 L28 8', 3),
])
ICONS['set_old_guard'] = svg([  # a column: pediment, three shafts, plinth
    fill('M6 14 L24 4 L42 14 Z'),
    fill('M10 17 H15 V36 H10 Z M21.5 17 H26.5 V36 H21.5 Z M33 17 H38 V36 H33 Z'),
    fill('M6 39 H42 V44 H6 Z'),
])
ICONS['set_cipher'] = svg([  # dot grid with one ringed cell
    circle(10, 10, 3.5), circle(24, 10, 3.5), circle(38, 10, 3.5),
    circle(10, 24, 3.5), circle(38, 24, 3.5),
    circle(10, 38, 3.5), circle(24, 38, 3.5), circle(38, 38, 3.5),
    circle(24, 24, 7, False, 3.5),
])
ICONS['set_showcase'] = svg([  # faceted gem
    stroke('M8 18 L16 7 H32 L40 18 L24 42 Z', 3.5),
    stroke('M8 18 H40 M16 7 L20 18 L24 42 M32 7 L28 18 L24 42', 2.5),
])

# --- Utility --------------------------------------------------------------------------------------
ICONS['eye_open'] = svg([  # Ambush spring
    stroke('M4 24 Q24 4 44 24 Q24 44 4 24 Z', 4),
    circle(24, 24, 7),
])
ICONS['lock'] = svg([  # locked card / album silhouette
    stroke('M15 22 V15 A9 9 0 0 1 33 15 V22', 4.5),
    '<rect x="9" y="21" width="30" height="23" rx="4" fill="%s"/>' % W,
])
ICONS['capture_arrow'] = svg([  # capture preview badge: "this flips"
    fill('M6 20 H26 V9 L44 24 L26 39 V28 H6 Z'),
])
ICONS['signature'] = svg([  # Signature: a ribbon with a forked tail and a star cut
    fill('M10 4 H38 V44 L24 34 L10 44 Z'),
    '<path d="M24 10 L26.4 16.2 L33 16.4 L27.8 20.6 L29.6 27 L24 23.3 L18.4 27 L20.2 20.6 L15 16.4 L21.6 16.2 Z" fill="#14161B"/>',
])

NAMES = sorted(ICONS)


def write_gd(path):
    lines = [
        '# art_icon_data.gd',
        '# GENERATED by tests/tools/gen_art_icons.py (cc14). Do not edit by hand: edit the generator and re-run.',
        '# Purpose: SVG text of every Banner Wall icon (original marks). ArtIcons rasterises it at runtime.',
        '# Author: Technical Artist Agent (cc14)',
        'extends RefCounted',
        '',
        'const SIZE: int = %d' % S,
        'const ICONS: Dictionary = {',
    ]
    for n in NAMES:
        lines.append('\t&"%s": \'%s\',' % (n, ICONS[n]))
    lines.append('}')
    with open(path, 'w') as f:
        f.write('\n'.join(lines) + '\n')


def main():
    root = os.getcwd()
    out_dir = os.path.join(root, 'assets', 'icons')
    os.makedirs(out_dir, exist_ok=True)
    for n in NAMES:
        with open(os.path.join(out_dir, n + '.svg'), 'w') as f:
            f.write(ICONS[n])
    write_gd(os.path.join(root, 'scripts', 'art', 'art_icon_data.gd'))
    print('wrote %d icons' % len(NAMES))


if __name__ == '__main__':
    sys.exit(main())

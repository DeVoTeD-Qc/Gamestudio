#!/usr/bin/env python3
"""Run v2 map pictograms (kc-v2-icons, Sr Game Artist, 2026-11-07).

The 6 run-map node icons (node_<type>) and the 10 Terrain icons (terrain_<id>), drawn in code as
original geometric glyphs: white on flat black, 1024x1024, the same "raw" form the ChatGPT batches
arrive in, so they go through the normal importer unchanged:

    python3 -I run_v2_icons.py <raw_dir>
    python3 -I ../../../tools/ui_kit_icons.py --manifest ../ui-kit-manifest.csv <raw_dir> ../../../source/project-killingcard

Style (pack section 2.1 and the batch-1 feedback in ui-kit-import-log.md): bold filled silhouettes,
strokes and gaps of at least 1/10 of the glyph, no detail under 1/8, 45-degree cuts, compact
roughly-square silhouettes. Every shape here is a plain primitive (rects, circles, polygons); nothing
is traced from or based on any reference image, logo or licensed art.

Units: a 1200 x 1200 design canvas, rendered at 2x and downsampled (anti-aliased edges).
"""
import math
import os
import sys

from PIL import Image, ImageDraw

U = 1200
OUT = 1024
SS = 2  # supersample
K = OUT * SS / U
W, B = 255, 0


class Pen:
    def __init__(self):
        self.im = Image.new('L', (OUT * SS, OUT * SS), 0)
        self.d = ImageDraw.Draw(self.im)

    @staticmethod
    def _p(pts):
        return [(x * K, y * K) for x, y in pts]

    def poly(self, pts, c=W):
        self.d.polygon(self._p(pts), fill=c)

    def rect(self, x0, y0, x1, y1, c=W, ch=0):
        """Rect with optional 45-degree chamfered corners (ch units)."""
        if ch <= 0:
            self.d.rectangle([x0 * K, y0 * K, x1 * K, y1 * K], fill=c)
            return
        self.poly([(x0 + ch, y0), (x1 - ch, y0), (x1, y0 + ch), (x1, y1 - ch), (x1 - ch, y1), (x0 + ch, y1),
                   (x0, y1 - ch), (x0, y0 + ch)], c)

    def circle(self, cx, cy, r, c=W):
        self.d.ellipse([(cx - r) * K, (cy - r) * K, (cx + r) * K, (cy + r) * K], fill=c)

    def ellipse(self, x0, y0, x1, y1, c=W):
        self.d.ellipse([x0 * K, y0 * K, x1 * K, y1 * K], fill=c)

    def line(self, a, b, w, c=W):
        """Thick segment with flat (square-cut) ends."""
        dx, dy = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dx, dy) or 1.0
        ox, oy = -dy / n * w / 2, dx / n * w / 2
        self.poly([(a[0] + ox, a[1] + oy), (b[0] + ox, b[1] + oy), (b[0] - ox, b[1] - oy), (a[0] - ox, a[1] - oy)], c)

    def arc(self, cx, cy, r, a0, a1, w, c=W):
        """Thick arc, angles in degrees, 0 = 3 o'clock, clockwise (PIL)."""
        self.d.arc([(cx - r - w / 2) * K, (cy - r - w / 2) * K, (cx + r + w / 2) * K, (cy + r + w / 2) * K],
                   a0, a1, fill=c, width=max(1, int(round(w * K))))

    def save(self, path):
        self.im.resize((OUT, OUT), Image.LANCZOS).convert('RGB').save(path)


def frame(cx, cy, ang):
    """Local (u along, v across) -> canvas, rotated by ang (radians) about (cx, cy)."""
    ca, sa = math.cos(ang), math.sin(ang)
    return lambda u, v: (cx + u * ca - v * sa, cy + u * sa + v * ca)


def rifle_parts(f, s=1.0, grow=0.0):
    """A generic long gun along u (butt at u<0, muzzle at u>0), v>0 is the underside. grow pads every
    part (used to cut the gap that lets one gun cross over the other). Returns polygons."""
    g = grow
    parts = [
        # stock: wide at the butt, tapering to the receiver
        [(-560 - g, -100 - g), (-300, -80 - g), (-300, 80 + g), (-560 - g, 140 + g)],
        # receiver
        [(-310, -85 - g), (60 + g, -85 - g), (60 + g, 85 + g), (-310, 85 + g)],
        # barrel
        [(40, -58 - g), (560 + g, -58 - g), (560 + g, 52 + g), (40, 52 + g)],
        # front sight block
        [(460 - g, -50), (550 + g, -50), (550 + g, -120 - g), (460 - g, -120 - g)],
        # magazine, raked forward
        [(-130 - g, 80), (-10 + g, 80), (30 + g, 230 + g), (-90 - g, 230 + g)],
    ]
    return [[f(u * s, v * s) for u, v in p] for p in parts]


def crossed_rifles(p, cy=600, s=1.0):
    a = frame(600, cy, -math.pi / 4)           # butt bottom-left, muzzle top-right
    # second gun: butt bottom-right, muzzle top-left; flip v so its magazine also hangs down
    ang = -3 * math.pi / 4
    ca, sa = math.cos(ang), math.sin(ang)
    b = lambda u, v: (600 + u * ca + v * sa, cy + u * sa - v * ca)
    for poly in rifle_parts(a, s):
        p.poly(poly)
    for poly in rifle_parts(b, s, grow=45):
        p.poly(poly, B)
    for poly in rifle_parts(b, s):
        p.poly(poly)


def star(p, cx, cy, r, c=W, inner=0.45):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * inner
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    p.poly(pts, c)


def spline(pts, n=12):
    """Closed Catmull-Rom through pts."""
    out = []
    m = len(pts)
    for i in range(m):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % m], pts[(i + 2) % m]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in range(2)))
    return out


# ------------------------------------------------------------------------------------ nodes

def node_fight(p):
    crossed_rifles(p)


def node_elite(p):
    crossed_rifles(p, cy=700, s=0.86)
    star(p, 600, 250, 250, B)
    star(p, 600, 265, 190)


def node_event(p):
    # field radio: body, antenna with a tip, a tuning dial and a speaker grille (cut out)
    p.line((800, 520), (960, 120), 80)
    p.circle(960, 120, 60)
    p.rect(150, 470, 1050, 1060, ch=80)
    p.circle(410, 765, 165, B)
    p.circle(410, 765, 65)
    for y in (610, 735, 860):
        p.rect(660, y, 930, y + 70, B)


def node_shop(p):
    # supply crate front: frame, lid band, cross braces
    p.rect(130, 200, 1070, 1080, ch=60)
    p.rect(230, 420, 970, 980, B)
    p.rect(230, 300, 970, 340, B)  # lid seam
    p.line((230, 420), (970, 980), 110)
    p.line((970, 420), (230, 980), 110)
    # restore the side frame where the braces' square ends poke past it
    p.rect(130, 420, 230, 980)
    p.rect(970, 420, 1070, 980)


def node_rest(p):
    # tent with an open door and a ground line
    p.poly([(110, 990), (600, 200), (1090, 990)])
    p.rect(580, 110, 620, 220)
    p.poly([(600, 560), (430, 990), (770, 990)], B)
    p.poly([(600, 560), (640, 990), (560, 990)])  # door pole
    p.rect(40, 990, 1160, 1090, ch=0)


def node_boss(p):
    # front skull: cranium, jaw, angular eye sockets, nose, teeth slots
    p.circle(600, 520, 420)
    p.rect(360, 700, 840, 1100, ch=70)
    p.poly([(150, 760), (360, 760), (360, 900)], B)  # cheek notches
    p.poly([(1050, 760), (840, 760), (840, 900)], B)
    for cx in (420, 780):
        p.rect(cx - 125, 450, cx + 125, 690, B, ch=60)
    p.poly([(600, 700), (530, 830), (670, 830)], B)
    for x in (480, 570, 660):
        p.rect(x, 950, x + 60, 1100, B)


# ------------------------------------------------------------------------------------ terrain

def terrain_rooftops(p):
    # stepped skyline; the tall middle block has a parapet, a high vantage over the others
    p.rect(80, 560, 400, 1100)
    p.rect(450, 230, 750, 1100)
    p.rect(800, 430, 1120, 1100)
    p.rect(420, 160, 520, 230)
    p.rect(680, 160, 780, 230)
    for y in (380, 560, 740):  # window slots, wide enough to survive 24 px
        p.rect(540, y, 660, y + 80, B)


def terrain_smoke(p):
    # a canister at the bottom left with a billowing cloud rising from it
    for cx, cy, r in ((450, 560, 230), (700, 420, 270), (900, 640, 210), (620, 720, 230), (360, 790, 180)):
        p.circle(cx, cy, r)
    p.rect(80, 820, 400, 1120, B, ch=40)
    p.rect(130, 870, 350, 1100, ch=30)
    p.rect(130, 950, 350, 995, B)


def terrain_dust_storm(p):
    # three wind streaks with curled ends, and grit
    r = 120
    p.line((100, 330), (700, 330), 100)
    p.arc(700, 330 - r, r, 180, 450, 100)   # curls up and back over the line
    p.line((200, 620), (920, 620), 100)
    p.arc(920, 620 - r, r, 180, 450, 100)
    p.line((60, 900), (640, 900), 100)
    p.arc(640, 900 + r, r, 270, 540, 100)   # curls down and back under the line
    for cx, cy in ((1020, 250), (1060, 900)):
        p.circle(cx, cy, 65)


def terrain_breach_point(p):
    # a wall slab with an arrow driven through it
    p.rect(430, 100, 730, 1100)
    p.rect(430, 330, 730, 375, B)      # mortar lines
    p.rect(430, 825, 730, 870, B)
    p.rect(565, 100, 610, 330, B)
    p.rect(545, 870, 590, 1100, B)
    p.rect(60, 480, 1180, 720, B)      # gap around the arrow
    p.poly([(430, 480), (500, 400), (560, 480)], B)  # broken edges
    p.poly([(640, 720), (700, 800), (730, 720)], B)
    p.rect(60, 545, 880, 655)          # shaft
    p.poly([(820, 410), (1150, 600), (820, 790)])


def terrain_floodlights(p):
    # a lamp head on a mount, throwing three beams down
    p.rect(560, 50, 640, 160)
    p.poly([(400, 160), (800, 160), (900, 400), (300, 400)])
    p.rect(330, 330, 870, 360, B)
    p.line((440, 480), (190, 1070), 110)
    p.line((600, 480), (600, 1100), 110)
    p.line((760, 480), (1010, 1070), 110)


def terrain_comms_tower(p):
    # lattice mast: two legs, a crossbar, a top mast and two signal arcs
    p.line((340, 1110), (580, 470), 95)
    p.line((860, 1110), (620, 470), 95)
    p.line((420, 860), (780, 860), 85)
    p.line((420, 860), (700, 650), 70)
    p.rect(555, 420, 645, 540)
    p.circle(600, 410, 85)
    p.arc(600, 410, 210, 210, 330, 85)
    p.arc(600, 410, 350, 215, 325, 85)


def terrain_supply_cache(p):
    # an air-dropped crate under a canopy
    p.poly([(140, 470)] + [(600 + 460 * math.cos(math.radians(a)), 470 - 360 * math.sin(math.radians(a)))
                           for a in range(180, -1, -6)] + [(1060, 470)])
    for cx in (293, 600, 907):  # scalloped hem
        p.ellipse(cx - 150, 400, cx + 150, 540, B)
    p.line((200, 470), (470, 760), 70)
    p.line((1000, 470), (730, 760), 70)
    p.line((600, 470), (600, 760), 70)
    p.rect(400, 740, 800, 1100, ch=40)
    p.rect(400, 890, 800, 950, B)


def terrain_hot_zone(p):
    # a flame with an inner tongue cut out
    outer = [(640, 60), (820, 300), (960, 520), (990, 760), (900, 960), (720, 1100), (480, 1100), (290, 960),
             (210, 760), (250, 560), (360, 420), (430, 600), (500, 360)]
    p.poly(spline(outer))
    inner = [(620, 560), (720, 740), (740, 900), (640, 1010), (520, 1010), (440, 900), (470, 760), (540, 820)]
    p.poly(spline(inner), B)


def terrain_minefield(p):
    # a flat disc mine seen from a low angle, with a burst of shards going up
    p.ellipse(110, 720, 1090, 1080)        # body (side)
    p.rect(110, 760, 1090, 900)
    p.ellipse(110, 620, 1090, 900, B)      # rim gap
    p.ellipse(170, 655, 1030, 865)         # top face
    p.ellipse(470, 690, 730, 790, B)       # pressure plate ring
    p.ellipse(520, 705, 680, 775)
    p.poly([(600, 80), (680, 540), (520, 540)])             # shards
    p.poly([(200, 230), (470, 560), (370, 610)])
    p.poly([(1000, 230), (830, 610), (730, 560)])


def terrain_field_hospital(p):
    # a first-aid case: handle, case, a plus cut out of the face (no emblem, no red)
    p.rect(400, 140, 800, 340, ch=40)
    p.rect(500, 230, 700, 340, B)
    p.rect(110, 320, 1090, 1060, ch=70)
    p.rect(390, 620, 810, 760, B)
    p.rect(530, 480, 670, 900, B)


ICONS = {
    'node_fight': node_fight, 'node_elite': node_elite, 'node_event': node_event, 'node_shop': node_shop,
    'node_rest': node_rest, 'node_boss': node_boss,
    'terrain_rooftops': terrain_rooftops, 'terrain_smoke': terrain_smoke, 'terrain_dust_storm': terrain_dust_storm,
    'terrain_breach_point': terrain_breach_point, 'terrain_floodlights': terrain_floodlights,
    'terrain_comms_tower': terrain_comms_tower, 'terrain_supply_cache': terrain_supply_cache,
    'terrain_hot_zone': terrain_hot_zone, 'terrain_minefield': terrain_minefield,
    'terrain_field_hospital': terrain_field_hospital,
}


def main(argv):
    if len(argv) != 1:
        print(__doc__)
        return 2
    os.makedirs(argv[0], exist_ok=True)
    for name, fn in ICONS.items():
        p = Pen()
        fn(p)
        p.save(os.path.join(argv[0], 'ico_%s.png' % name))
        print('ico_%s.png' % name)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

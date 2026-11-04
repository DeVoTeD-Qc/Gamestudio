#!/usr/bin/env python3
"""Cuts the gameplay recording into a short trailer-style teaser and writes <rec>/trailer.json.

Usage: python3 media/demo/trailer_cut.py <rec-dir>

Every shot is real footage from record_game.js (anchored to the marks it logged, in game-time
seconds). replay.html adds the trailer treatment at render time: punch-in zooms on the action point
(`zoom`: focus x, y in the recording's 1280x720 CSS px brought to the frame centre, scale from -> to;
`focus2` tracks the focus to a second point; `inset` shows an edge subject's rectangle enlarged in the centre), camera shake on impacts,
flash frames on cuts, speed ramps, letterbox bars, a short RGB-split glitch, and the kinetic title
cards. Nothing is added to the game image itself.
"""
import json
import os
import sys

REC = sys.argv[1]
marks = json.load(open(os.path.join(REC, 'marks.json')))


def m(label, n=1, **match):
    hits = [x for x in marks if x['label'] == label and all(x.get(k) == v for k, v in match.items())]
    return hits[n - 1]['t']


def after(label, t, **match):
    """First mark with this label after game time t."""
    return next(x['t'] for x in marks if x['label'] == label and x['t'] > t and all(x.get(k) == v for k, v in match.items()))


def before(label, t, **match):
    """Last mark with this label at or before game time t."""
    return [x['t'] for x in marks if x['label'] == label and x['t'] <= t and all(x.get(k) == v for k, v in match.items())][-1]


# The recording plays up to MAXM matches; the call-in can land in any of them, so every anchor is
# taken relative to the killstreak mark (not by round number, which repeats in each match).
ks = m('killstreak')
FK = after('fight', ks)                     # the call-in round: takeover, hostile call-in, firefight
F2 = after('fight', before('frag', ks))     # the frag round before it: tracers, OPERATOR DOWN, ELIMINATED
D3 = before('deploy', ks, round=3)          # a deploy phase with painted units on the board and in hand
R = m('runmap')


def clip(a, b, dur, zoom, shake=0, flash=None, ramp=None, glitch=False, label=None):
    return {'type': 'clip', 'src': [round(a, 3), round(b, 3)], 'dur': dur, 'zoom': zoom, 'shake': shake,
            'flash': flash, 'ramp': ramp, 'glitch': glitch, 'label': label}


def card(text, dur, kicker=None, color='amber'):
    return {'type': 'card', 'text': text, 'dur': dur, 'kicker': kicker, 'color': color}


# Focus points / rectangles were measured on the recorded frames (grid overlays of the source frames,
# 1280x720 CSS px): tracer start/end, stamp centres, lane, hand and unit-slot rectangles.
def inset(c, box, zoom=(1.0, 1.06)):
    c['inset'] = list(box)
    c['insetZoom'] = list(zoom)
    return c


shots = [
    card('DEPLOY.', 0.9, kicker='KILLSTREAK'),
    # run map: the five match cards with the painted mode art (cards 25-1530 x 85-470 at 1.0 zoom)
    clip(R + 0.5, R + 1.7, 1.1, [640, 290, 1.0, 1.12], flash='white', ramp='fast', label='run map'),
    # painted units deployed in the crane yard (lane 435-840 x 130-455) and the contested lanes
    clip(D3 + 2.6, D3 + 4.4, 1.2, [600, 290, 1.3, 1.45], flash='white', label='deploy'),
    # the hand: painted art on every chip (hand 465-1050 x 520-680)
    clip(D3 + 5.0, D3 + 5.8, 0.9, [760, 600, 1.6, 1.75], flash='white', label='hand'),
    # card inspector (card 230-585 x 115-605 + text panel to 1040)
    clip(m('inspector') + 2.3, m('inspector') + 3.2, 0.9, [635, 360, 1.05, 1.15], flash='white', label='card'),
    card('CALL IN.', 0.9, kicker='STREAK 2', color='cyan'),
    # call-in takeover over the painted field tablet (band y ~ 290-430, tablet fills the frame)
    clip(FK + 0.05, FK + 1.65, 1.4, [640, 360, 1.0, 1.15], shake=0.6, flash='white', ramp='slow', glitch=True, label='recon drone takeover'),
    # the enemy answers with its own call-in, graded red
    clip(FK + 2.55, FK + 3.45, 0.8, [640, 360, 1.08, 1.18], flash='red', label='hostile takeover'),
    # tracers in the crane yard: our Kestrel operator (486,230) -> enemy Marksman (678,358)
    dict(clip(F2 + 1.6, F2 + 2.3, 0.8, [540, 260, 1.45, 1.6], flash='white', label='tracers'), focus2=[640, 340]),
    # OPERATOR DOWN stamp on our Kestrel slot (486,371)
    clip(F2 + 2.5, F2 + 3.2, 0.8, [500, 360, 1.55, 1.7], shake=1.2, flash='red', label='operator down'),
    # ELIMINATED stamp + "+100 ELIMINATION" on the enemy Rifleman slot (589,209 / 589,128)
    clip(F2 + 3.3, F2 + 4.0, 0.9, [580, 185, 1.5, 1.7], shake=1.0, flash='amber', label='eliminated'),
    card('KILLSTREAK.', 1.0, kicker='PORT VASEL', color='amber'),
    # DOWN stamp in the left lane at the screen edge (stamp ~70,375; lower lane row 15-260 x 235-455): picture-in-picture
    inset(clip(FK + 5.45, FK + 6.25, 0.8, [135, 345, 1, 1], shake=1.0, flash='amber', label='down'), (0, 230, 270, 460)),
    # crane-yard tracers after the call-in: Kestrel (486,228) -> Breacher slots (576-627, 356)
    dict(clip(FK + 6.65, FK + 7.35, 0.8, [520, 280, 1.4, 1.55], shake=0.5, flash='white', label='tracers'), focus2=[610, 345]),
    # STREAK LOST over the left lane + the streak arc on the Operator panel (left edge): picture-in-picture
    inset(clip(F2 + 3.8, F2 + 4.9, 1.2, [150, 500, 1, 1], shake=0.8, flash='red', glitch=True, label='streak lost'), (0, 400, 360, 600)),
    # hero: the real Title screen with the new painted key art, slow pull back to the full frame
    clip(m('title') + 0.3, m('title') + 1.6, 3.6, [640, 360, 1.12, 1.0], flash='white', ramp='hero', label='hero'),
]
json.dump({'shots': shots}, open(os.path.join(REC, 'trailer.json'), 'w'), indent=1)
t = 0
for s in shots:
    print('  %5.2f  %4.1fs  %s' % (t, s['dur'], s.get('text') or '%s  [%s]' % (s['label'], '-'.join('%.1f' % x for x in s['src']))))
    t += s['dur']
print('trailer: %.1f s' % t)

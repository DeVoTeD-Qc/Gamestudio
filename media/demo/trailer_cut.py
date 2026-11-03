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


ks = m('killstreak')
ks_round = max(x['round'] for x in marks if x['label'] == 'deploy' and x['t'] <= ks)
F = m('fight', round=ks_round)          # the call-in round's reveal + firefight
F1 = m('fight', round=1)


def clip(a, b, dur, zoom, shake=0, flash=None, ramp=None, glitch=False, label=None):
    return {'type': 'clip', 'src': [round(a, 3), round(b, 3)], 'dur': dur, 'zoom': zoom, 'shake': shake,
            'flash': flash, 'ramp': ramp, 'glitch': glitch, 'label': label}


def card(text, dur, kicker=None, color='amber'):
    return {'type': 'card', 'text': text, 'dur': dur, 'kicker': kicker, 'color': color}


# Focus points / rectangles were measured on the recorded frames (grid overlays of the source frames,
# 1280x720 CSS px): tracer start/end, stamp centres, lane and unit-slot rectangles.
def inset(c, box, zoom=(1.0, 1.06)):
    c['inset'] = list(box)
    c['insetZoom'] = list(zoom)
    return c


shots = [
    card('DEPLOY.', 0.9, kicker='KILLSTREAK'),
    # Operator + Point Man arriving in the crane yard lane
    clip(m('deploy', round=1) + 0.4, F1 - 0.6, 1.2, [540, 330, 1.15, 1.3], flash='white', ramp='fast', label='deploy'),
    # FIRST SHOT tracer: enemy Point Man (483,228) -> our Point Man (575,360)
    dict(clip(F1 + 0.6, F1 + 1.6, 1.0, [500, 250, 1.4, 1.6], flash='white', label='first shot'), focus2=[560, 320]),
    # ELIMINATED stamp on the crane-yard enemy slot (490,210)
    clip(F1 + 3.3, F1 + 4.2, 0.9, [500, 200, 1.5, 1.7], shake=1.0, flash='amber', label='eliminated'),
    # card inspector (card 230-585 x 115-605 + text panel to 1040)
    clip(m('inspector') + 2.3, m('inspector') + 3.2, 0.8, [635, 360, 1.05, 1.15], flash='white', label='card'),
    card('CALL IN.', 0.9, kicker='STREAK 2', color='cyan'),
    # call-in band across the board, y ~ 290-430
    clip(F + 0.5, F + 2.3, 1.4, [640, 360, 1.0, 1.2], shake=0.6, flash='white', ramp='slow', glitch=True, label='recon drone takeover'),
    # FRAG GRENADE impact on the crane-yard enemy row (640,220)
    clip(F + 3.7, F + 4.6, 0.9, [640, 225, 1.45, 1.65], shake=1.0, flash='amber', label='frag lands'),
    # FIRST SHOT in the left lane (shooter slot at the screen edge, lane 20-420 x 105-455): picture-in-picture
    inset(clip(F + 4.6, F + 5.4, 0.8, [220, 270, 1, 1], flash='white', label='first shot'), (10, 100, 430, 458)),
    # ELIMINATED stamp at the left screen edge (enemy Point Man slot 20-120 x 130-290): picture-in-picture
    inset(clip(F + 6.1, F + 7.0, 0.9, [70, 210, 1, 1], shake=1.0, flash='amber', label='eliminated'), (0, 105, 300, 300)),
    # enemy FIRST SHOT tracer (625,290) -> (770,370), hit markers on our slots
    dict(clip(F + 7.7, F + 8.6, 0.9, [630, 285, 1.45, 1.6], shake=0.5, flash='white', label='tracers'), focus2=[700, 330]),
    # OPERATOR DOWN / DOWN stamps (415-625, 375)
    clip(F + 8.7, F + 9.6, 0.9, [520, 375, 1.55, 1.7], shake=1.2, flash='red', label='operator down'),
    # killfeed lines at the top-right edge (830-1075 x 12-82): picture-in-picture
    inset(clip(F + 9.8, F + 10.6, 0.8, [950, 45, 1, 1], flash='white', label='killfeed'), (820, 8, 1085, 86)),
    card('KILLSTREAK.', 1.0, kicker='STREAK 3', color='amber'),
    # STREAK LOST over the left lane + the streak arc on the Operator panel (left edge): picture-in-picture
    inset(clip(F + 13.9, F + 15.8, 1.4, [150, 480, 1, 1], shake=0.8, flash='red', glitch=True, label='streak lost'), (10, 405, 300, 610)),
    # hero: the real Title screen, slow pull back to the full frame
    clip(m('title') + 0.3, m('title') + 1.6, 3.6, [640, 360, 1.12, 1.0], flash='white', ramp='hero', label='hero'),
]
json.dump({'shots': shots}, open(os.path.join(REC, 'trailer.json'), 'w'), indent=1)
t = 0
for s in shots:
    print('  %5.2f  %4.1fs  %s' % (t, s['dur'], s.get('text') or '%s  [%s]' % (s['label'], '-'.join('%.1f' % x for x in s['src']))))
    t += s['dur']
print('trailer: %.1f s' % t)

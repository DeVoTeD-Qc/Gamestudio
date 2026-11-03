#!/usr/bin/env python3
"""Cuts the gameplay recording into a short trailer-style teaser and writes <rec>/trailer.json.

Usage: python3 media/demo/trailer_cut.py <rec-dir>

Every shot is real footage from record_game.js (anchored to the marks it logged, in game-time
seconds). replay.html adds the trailer treatment at render time: punch-in zooms on the action point
(`zoom`: x, y in the recording's 1280x720 CSS pixels, scale from -> to; `dy` pans down, in output px), camera shake on impacts,
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


shots = [
    card('DEPLOY.', 0.9, kicker='KILLSTREAK'),
    clip(m('deploy', round=1) + 0.4, F1 - 0.6, 1.2, [700, 300, 1.05, 1.2], flash='white', ramp='fast', label='deploy'),
    clip(F1 + 0.6, F1 + 1.6, 1.0, [560, 240, 1.15, 1.4], flash='white', label='first shot'),
    clip(F1 + 3.3, F1 + 4.2, 0.9, [486, 215, 1.35, 1.55], shake=1.0, flash='amber', label='eliminated'),
    clip(m('inspector') + 2.3, m('inspector') + 3.2, 0.8, [560, 340, 1.0, 1.15], flash='white', label='card'),
    card('CALL IN.', 0.9, kicker='STREAK 2', color='cyan'),
    clip(F + 0.5, F + 2.3, 1.4, [640, 360, 1.0, 1.25], shake=0.6, flash='white', ramp='slow', glitch=True, label='recon drone takeover'),
    clip(F + 3.7, F + 4.6, 0.9, [560, 240, 1.2, 1.45], shake=1.0, flash='amber', label='frag lands'),
    clip(F + 4.6, F + 5.4, 0.8, [260, 260, 1.3, 1.5], flash='white', label='first shot'),
    clip(F + 6.1, F + 7.0, 0.8, [200, 230, 1.4, 1.6], shake=1.0, flash='amber', label='eliminated'),
    clip(F + 7.7, F + 8.6, 0.9, [640, 260, 1.2, 1.45], shake=0.5, flash='white', label='tracers'),
    clip(F + 8.7, F + 9.6, 0.9, [500, 330, 1.3, 1.5], shake=1.2, flash='red', label='operator down'),
    dict(clip(F + 9.8, F + 10.6, 0.8, [1040, 35, 1.6, 1.8], flash='white', label='killfeed'), dy=110),
    card('KILLSTREAK.', 1.0, kicker='STREAK 3', color='amber'),
    clip(F + 13.9, F + 15.8, 1.4, [150, 460, 1.25, 1.5], shake=0.8, flash='red', glitch=True, label='streak lost'),
    clip(m('title') + 0.3, m('title') + 1.6, 3.6, [1180, 500, 1.6, 1.0], flash='white', ramp='hero', label='hero'),
]
json.dump({'shots': shots}, open(os.path.join(REC, 'trailer.json'), 'w'), indent=1)
t = 0
for s in shots:
    print('  %5.2f  %4.1fs  %s' % (t, s['dur'], s.get('text') or '%s  [%s]' % (s['label'], '-'.join('%.1f' % x for x in s['src']))))
    t += s['dur']
print('trailer: %.1f s' % t)

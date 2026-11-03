#!/usr/bin/env python3
"""Picks gameplay highlights from a record_game.js recording and writes <rec>/clips.json.

Usage: python3 media/demo/pick_clips.py <rec-dir>

Clips are defined relative to the marks the driver logged (marks.json, game-time seconds), so a new
recording with a different seed still lines up. `rate` > 1 speeds a clip up (menus only; matches play
at normal speed). Every frame is real gameplay; the captions only name what is on screen.
"""
import json
import os
import sys

REC = sys.argv[1]
marks = json.load(open(os.path.join(REC, 'marks.json')))


def m(label, n=1, **match):
    """Time of the n-th mark with this label (and matching fields)."""
    hits = [x for x in marks if x['label'] == label and all(x.get(k) == v for k, v in match.items())]
    return hits[n - 1]['t']


ks = m('killstreak')
ks_round = max(x['round'] for x in marks if x['label'] == 'deploy' and x['t'] <= ks)
fight_ks = m('fight', round=ks_round)
end_ks = m('fight-end', round=ks_round)
banner = m('banner')
frag1 = m('frag')
clips = [
    (0.0, m('consent') + 2.1, 1.3, 'The real web build of Killstreak, running in Chromium'),
    (m('consent') + 2.1, m('title') + 4.4, 3.0, 'Playtest consent, three quick survey questions, then the Title'),
    (m('title') + 4.4, m('mulligan') - 0.1, 3.0, 'New run: three killstreaks picked, the run map, DEPLOY'),
    (m('mulligan') - 0.1, m('fight', round=1), 1.2, 'Round 1: keep the hand, tap the Operator and a zone, deploy a unit'),
    (m('fight', round=1), m('fight-end', round=1), 1.0, 'Simultaneous reveal. FIRST SHOT resolves before MAIN; eliminated units are stamped'),
    (m('inspector') + 0.4, m('inspector') + 4.2, 1.0, 'Long-press any card to read its full rules'),
    (frag1 - 1.6, frag1 + 0.8, 1.0, 'Frag Grenade: tap a zone near your Operator to throw it'),
    (m('deploy', round=ks_round) - 0.1, fight_ks, 1.0, 'Streak 2 earned: call in the Recon Drone, throw a Frag, deploy'),
    (fight_ks, fight_ks + 3.8, 1.0, 'Killstreak call-in: the full-screen takeover'),
    (fight_ks + 3.8, fight_ks + 7.4, 1.0, 'The Frag lands, FIRST SHOT fires before MAIN, an enemy is ELIMINATED'),
    (fight_ks + 7.4, fight_ks + 11.4, 1.0, 'Enemy First Shot units fire back: OPERATOR DOWN, and the killfeed logs it'),
    (fight_ks + 11.4, fight_ks + 15.0, 1.0, 'The streak reached 3 (Mortar ready), but the Operator went down: STREAK LOST'),
    (banner - 0.2, banner + 3.6, 1.0, 'Match result. The enemy squad won this one, 7 to 4'),
]
out = []
for a, b, rate, cap in clips:
    out.append({'src': [round(a, 3), round(b, 3)], 'rate': rate, 'dur': round((b - a) / rate, 3), 'caption': cap})
json.dump({'clips': out}, open(os.path.join(REC, 'clips.json'), 'w'), indent=1)
print('clips: %.1f s' % sum(c['dur'] for c in out))
for c in out:
    print('  %6.2f-%6.2f x%.1f %5.1fs  %s' % (c['src'][0], c['src'][1], c['rate'], c['dur'], c['caption']))

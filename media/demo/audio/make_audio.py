#!/usr/bin/env python3
"""Synthesizes the demo video's soundtrack (music bed + SFX) from timeline.json. Everything is
generated here in code with numpy (seeded, deterministic): no samples, loops or downloaded audio.

Usage: python3 media/demo/audio/make_audio.py <out.wav> [timeline.json]

Writes a 48 kHz stereo 16-bit WAV, peak-normalized to -3 dBFS before loudness normalization
(ffmpeg loudnorm, see README.md).

Music: A minor, 96 BPM (bar = 2.5 s), i-VI-III-VII (Am-F-C-G). A detuned additive pad is always there.
A soft plucked arpeggio comes in at the design phase. Bass pulses and light hats build through the
parallel-work section. It drops back to the pad while the usage limit is shown, then a noise/sine
riser leads into the trailer. In the trailer the bed lifts: kick grid, sub ostinato, sub hits on the
cuts. The end card has a soft add9 outro.

SFX are placed on the timeline's real events: card adds (blips), task starts (ticks), Review/
approvals (chimes), taps (clicks), typing ticks for the terminal, chat pops, whooshes on scene and
drawer changes, a two-tone alert for the usage limit. In the trailer there are booms on shakes,
whoosh plus bass drop on title cards, an uplink/static sweep on the call-in, glitch blips on
RGB-split shots, and a big low hit on the hero reveal.
"""
import json
import os
import sys
import wave

import numpy as np

SR = 48000
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1]
TL = json.load(open(sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, '..', 'timeline.json')))
DUR = TL['duration']
N = int((DUR + 0.5) * SR)
rng = np.random.default_rng(20261103)
music = np.zeros((N, 2))
sfx = np.zeros((N, 2))
scene_at = {s['id']: s['start'] for s in TL['scenes']}
scene_end = {s['id']: s['end'] for s in TL['scenes']}
GAME0, GAME1, END0 = scene_at['game'], scene_end['game'], scene_at['end']
BEAT = 60 / 96
BAR = 4 * BEAT
GRID0 = GAME0 % BAR            # bar grid aligned so a bar starts exactly when the trailer starts


def place(buf, t, sig, pan=0.0, gain=1.0):
    """Mixes mono or stereo sig into buf at time t (s). pan -1..1, constant power."""
    i = int(round(t * SR))
    if sig.ndim == 1:
        a = (pan + 1) * np.pi / 4
        sig = np.stack([sig * np.cos(a), sig * np.sin(a)], 1) * np.sqrt(2)
    if i < 0:
        sig, i = sig[-i:], 0
    n = min(len(sig), N - i)
    if n > 0:
        buf[i:i + n] += sig[:n] * gain


def tt(d):
    return np.arange(int(d * SR)) / SR


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def onepole_lp(x, fc):
    """One-pole low-pass; fc may be an array (per-sample cutoff)."""
    fc = np.broadcast_to(np.asarray(fc, float), x.shape)
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x)
    s = 0.0
    for i in range(len(x)):
        s = (1 - a[i]) * x[i] + a[i] * s
        y[i] = s
    return y


def env(n, a, r, shape=1.0):
    e = np.ones(n)
    na, nr = int(a * SR), int(r * SR)
    if na:
        e[:na] = np.linspace(0, 1, na) ** shape
    if nr:
        e[-nr:] *= np.linspace(1, 0, nr) ** shape
    return e


def expdecay(d, tau):
    return np.exp(-tt(d) / tau)


def gliss(f0, f1, d, curve=1.0):
    t = tt(d)
    f = f0 + (f1 - f0) * (t / d) ** curve
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


# ----------------------------------------------------------------------------- music
CHORDS = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]   # Am F C G (pad voicings)
ROOTS = [45, 41, 48, 43]


def keyframes(points):
    xs, ys = zip(*points)
    return lambda t: float(np.interp(t, xs, ys))


S = scene_at
pad_lvl = keyframes([(0, 0.0), (1.5, .55), (S['parallel'], .6), (S['created'], .65), (S['stats'], .6),
                     (GAME0, .75), (GAME1, .9), (DUR, .8)])
# the art pass (artpack -> upload -> artin, Nov 4) brings the arpeggio back softly, then bass and hats
# build under the before/after wipes into the riser
ART0 = S.get('artpack', GAME0)
arp_lvl = keyframes([(0, 0), (S['design'] - 1, 0), (S['design'] + 2, .35), (S['parallel'], .4),
                     (S['created'] - 1, .75), (S['created'], .55), (S['stats'], .45), (S['stats'] + 2, 0),
                     (ART0, 0), (ART0 + 2, .3), (GAME0 - 4, .5), (GAME0, 0), (DUR, 0)])
bass_lvl = keyframes([(0, 0), (S['parallel'] - 1, 0), (S['parallel'] + 2, .3), (S['created'] - 1, .7),
                      (S['created'], .45), (S['stats'], .4), (S['stats'] + 2, 0),
                      (S.get('upload', GAME0), 0), (S.get('artin', GAME0), .35), (GAME0 - 3, .55), (GAME0, 0), (DUR, 0)])
hat_lvl = keyframes([(0, 0), (S['parallel'] + 6, 0), (S['created'] - 1, .55), (S['created'], .25),
                     (S['feedback'] + 10, .3), (S['stats'], 0), (S.get('artin', GAME0), 0),
                     (S.get('artin', GAME0) + 3, .3), (GAME0 - 3, .3), (GAME0, 0), (DUR, 0)])
# the usage-limit banner: everything but the pad drops out while it is up
lim = [e['t'] for e in TL['events'] if e['k'] == 'limit']
mute = (lambda t: 0.15 if lim and lim[0] <= t < lim[1] else 1.0) if len(lim) == 2 else (lambda t: 1.0)

bar = 0
tb = GRID0 - BAR
while tb < DUR:
    ch = CHORDS[bar % 4]
    in_trailer = GAME0 <= tb < GAME1
    if tb >= END0 - 0.01:
        ch = [57, 60, 64, 71]                 # outro: Am(add9)
    d = BAR + 1.6
    t = tt(d)
    e = env(len(t), .9, 1.4, 1.5)
    lv = pad_lvl(max(tb, 0) + 1)
    for k, m in enumerate(ch):
        for det, pan in ((-0.0025, -.5), (0.0025, .5)):
            f = midi(m) * (1 + det)
            vib = 1 + 0.0015 * np.sin(2 * np.pi * (0.2 + 0.05 * k) * t)
            ph = 2 * np.pi * np.cumsum(f * vib) / SR
            sig = sum(np.sin(h * ph) / h ** 1.7 for h in range(1, 7))
            place(music, tb, sig * e * 0.05 * lv, pan)
    # arpeggio: plucked 8ths (16ths late in the parallel section), chord tones up an octave
    la = arp_lvl(tb + 1) * mute(tb + 1)
    if la > 0.01:
        step = BEAT / 4 if S['parallel'] + 14 <= tb < S['created'] else BEAT / 2
        notes = [m + 12 for m in ch] + [ch[1] + 24]
        for j in range(int(round(BAR / step))):
            m = notes[[0, 1, 2, 3, 2, 1][j % 6]]
            pl = np.sin(2 * np.pi * midi(m) * tt(.5)) * expdecay(.5, .12)
            pl += 0.3 * np.sin(4 * np.pi * midi(m) * tt(.5)) * expdecay(.5, .05)
            place(music, tb + j * step, pl * 0.045 * la, pan=0.35 * np.sin(j * 1.3))
    lb = bass_lvl(tb + 1) * mute(tb + 1)
    if lb > 0.01:
        for j in range(8):
            f = midi(ROOTS[bar % 4] - 12 + (12 if j % 4 == 3 else 0))
            b = np.sin(2 * np.pi * f * tt(BEAT / 2)) * env(int(BEAT / 2 * SR), .01, .15)
            place(music, tb + j * BEAT / 2, b * 0.11 * lb)
    lh = hat_lvl(tb + 1) * mute(tb + 1)
    if lh > 0.01:
        for j in range(8):
            n = np.diff(rng.standard_normal(int(.03 * SR) + 1)) * expdecay(.03, .008)
            place(music, tb + j * BEAT / 2 + BEAT / 4, n * 0.025 * lh * (1.0 if j % 2 else .6), pan=.3)
    # trailer kit: kick on the beat, offbeat hats, sub ostinato
    if in_trailer and tb < GAME1 - BAR * 0.5:
        for j in range(4):
            tk = tb + j * BEAT
            if tk >= GAME1 - 3.4:      # stop before the hero reveal
                break
            place(music, tk, gliss(120, 42, .28, .4) * expdecay(.28, .09) * .5)
            n = np.diff(rng.standard_normal(int(.04 * SR) + 1)) * expdecay(.04, .01)
            place(music, tk + BEAT / 2, n * .05, pan=.25)
            for q in range(2):
                f = midi(ROOTS[bar % 4] - 12)
                place(music, tk + q * BEAT / 2, np.sin(2 * np.pi * f * tt(BEAT / 2)) * env(int(BEAT / 2 * SR), .005, .12) * .16)
    tb += BAR
    bar += 1

# riser into the trailer (last 3 s of the stats card)
rd = 3.0
t = tt(rd)
noise = rng.standard_normal(len(t))
rise = onepole_lp(noise, 300 + 6000 * (t / rd) ** 2) * (t / rd) ** 2 * .22
rise += gliss(110, 440, rd, 2) * (t / rd) ** 3 * .06
place(music, GAME0 - rd, rise)

# reverb on the music bus (synthetic decaying-noise impulse response, FFT convolution)
ir_t = tt(1.8)
for c in range(2):
    ir = rng.standard_normal(len(ir_t)) * np.exp(-ir_t / 0.45)
    ir = onepole_lp(ir, 3500)
    ir /= np.sqrt(np.sum(ir ** 2))
    L = 1 << int(np.ceil(np.log2(N + len(ir))))
    wet = np.fft.irfft(np.fft.rfft(music[:, c], L) * np.fft.rfft(ir, L), L)[:N]
    music[:, c] = music[:, c] * .8 + wet * .35


# ----------------------------------------------------------------------------- SFX
def blip(f=1500):
    d = .06
    return gliss(f, f * 1.25, d) * expdecay(d, .018)


def tick():
    n = np.diff(rng.standard_normal(int(.012 * SR) + 1))
    return n * expdecay(.012, .003)


def click():
    return (np.sin(2 * np.pi * 2300 * tt(.015)) * .6 + np.diff(rng.standard_normal(int(.015 * SR) + 1)) * .4) * expdecay(.015, .004)


def chime(base=1318.5):
    d = .9
    t = tt(d)
    s = np.sin(2 * np.pi * base * t) + .6 * np.sin(2 * np.pi * base * 1.5 * t + .3) * np.exp(-t / .25)
    s += .15 * np.sin(2 * np.pi * base * 2.76 * t) * np.exp(-t / .08)
    return s * np.exp(-t / .32) * env(len(t), .004, .1)


def pop():
    return gliss(520, 880, .07, .5) * expdecay(.07, .02)


def whoosh(d=.55, up=True, gain=1.0):
    t = tt(d)
    n = rng.standard_normal(len(t))
    fc = 400 + 4000 * ((t / d) if up else (1 - t / d)) ** 1.5
    return onepole_lp(n, fc) * np.sin(np.pi * t / d) ** 2 * gain


def alert():
    a = np.sin(2 * np.pi * 660 * tt(.18)) * env(int(.18 * SR), .01, .08)
    b = np.sin(2 * np.pi * 495 * tt(.3)) * env(int(.3 * SR), .01, .2)
    return np.concatenate([a, np.zeros(int(.05 * SR)), b])


def boom(gain=1.0):
    d = .9
    s = gliss(95, 32, d, .35) * expdecay(d, .28)
    n = onepole_lp(rng.standard_normal(int(.25 * SR)), 900) * expdecay(.25, .05)
    s[:len(n)] += n * 1.2
    return s * gain


def snap():
    n = np.diff(rng.standard_normal(int(.09 * SR) + 1)) * expdecay(.09, .02)
    body = np.sin(2 * np.pi * 190 * tt(.09)) * expdecay(.09, .03)
    return n * .5 + body * .6


def drop():
    return gliss(160, 38, .8, .5) * expdecay(.8, .3)


def glitch():
    d = .16
    out = np.zeros(int(d * SR))
    seg = int(.016 * SR)
    for k in range(0, len(out), seg):
        f = rng.choice([180, 420, 900, 1600, 2600])
        x = np.sign(np.sin(2 * np.pi * f * np.arange(seg) / SR))
        out[k:k + seg] = x[:len(out[k:k + seg])] * (rng.random() > .25)
    return np.round(out * 4) / 4 * expdecay(d, .08)


def uplink(d=1.4):
    """Generic radio-static sweep with two data chirps (no recognizable franchise cue)."""
    t = tt(d)
    n = rng.standard_normal(len(t))
    fc = 700 + 2600 * np.sin(np.pi * t / d)
    hp = n - onepole_lp(n, fc * .5)
    st = onepole_lp(hp, fc) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 17 * t))) * env(len(t), .05, .4)
    for c0 in (.15, .55):
        i0 = int(c0 * SR)
        ch = gliss(1800, 2600, .12) * env(int(.12 * SR), .005, .03) * .5
        st[i0:i0 + len(ch)] += ch
    return st


def big_hit():
    d = 2.6
    s = gliss(70, 28, d, .3) * expdecay(d, .9)
    n = onepole_lp(rng.standard_normal(int(.5 * SR)), 1200) * expdecay(.5, .12)
    s[:len(n)] += n
    return s


def reverse_swell(d=.8):
    t = tt(d)
    return onepole_lp(rng.standard_normal(len(t)), 200 + 3000 * (t / d) ** 2) * (t / d) ** 3


last = {}


def limited(kind, t, gap):
    if t - last.get(kind, -9) < gap:
        return False
    last[kind] = t
    return True


views = {s['id']: s['view'] for s in TL['scenes']}
prev = None
for s in TL['scenes']:
    if prev and s['view'] != prev['view'] and s['id'] not in ('game',):
        place(sfx, s['start'] - .3, whoosh(.6), gain=.1)
    prev = s

for e in TL['events']:
    t, k = e['t'], e['k']
    if t >= GAME0:
        break
    if k == 'add' and limited('add', t, .07):
        place(sfx, t, blip(1300 + 300 * rng.random()), pan=rng.uniform(-.4, .4), gain=.07)
    elif k == 'status':
        if e['status'] == 'doing' and limited('tick', t, .06):
            place(sfx, t, tick(), pan=-.2, gain=.12)
        elif e['status'] in ('review', 'done') and limited('chime', t, .3):
            place(sfx, t, chime(1318.5 if e['status'] == 'review' else 1567.98), pan=.2, gain=.05)
    elif k == 'tap':
        place(sfx, t, click(), gain=.12)
    elif k == 'toast':
        place(sfx, t, chime(1046.5), gain=.06)
        place(sfx, t + .09, chime(1567.98), gain=.05)
    elif k == 'chat':
        place(sfx, t, pop(), gain=.09)
    elif k == 'term':
        if e.get('who') == 'you':
            for j in range(len(e['text'])):
                if e['text'][j] != ' ' or rng.random() < .5:
                    place(sfx, t + j / 55 + rng.uniform(0, .006), tick(), pan=rng.uniform(-.2, .2), gain=.03 + .02 * rng.random())
        else:
            place(sfx, t, blip(900), gain=.06)
    elif k == 'termnote':
        place(sfx, t, chime(1174.66), gain=.05)
    elif k == 'drawer' and e.get('kind'):
        place(sfx, t, whoosh(.35), gain=.05)
    elif k == 'limit':
        place(sfx, t, alert() if e['on'] else blip(1100), gain=.07 if e['on'] else .06)
    elif k == 'spot':
        place(sfx, t, blip(1700), gain=.07)
        place(sfx, t + .05, tick(), gain=.08)
    elif k == 'stats':
        place(sfx, t, whoosh(.5), gain=.08)
    elif k == 'upmark':
        if e['what'] == 'refused':          # soft low two-tone: the generator said no
            place(sfx, t, alert(), gain=.05)
        elif e['what'] == 'reprompt':       # a quick burst of typing for the re-prompt
            for j in range(14):
                place(sfx, t + j * .045 + rng.uniform(0, .01), tick(), pan=rng.uniform(-.2, .2), gain=.04)
        else:                               # batch 2 lands: 48 of 48
            place(sfx, t, chime(1318.5), gain=.06)
            place(sfx, t + .1, chime(1975.5), gain=.05)
    if k == 'drawer' and e.get('kind') == 'prompt':
        # style block pasted, then the card's own lines typed at 130 chars/s (as replay.html types them)
        place(sfx, t + .5, snap(), gain=.12)
        for j in range(0, len(e['prompt']), 2):
            place(sfx, t + 1.4 + j / 130 + rng.uniform(0, .006), tick(), pan=rng.uniform(-.2, .2), gain=.025 + .015 * rng.random())
        place(sfx, t + 1.6 + len(e['prompt']) / 130 + .3, chime(1567.98), gain=.05)
    elif k == 'drawer' and e.get('kind') == 'upload':
        for j in range(e['zips']):         # zip parts arrive
            place(sfx, t + .2 + j * .18, pop(), pan=-.3 + .12 * j, gain=.08)
        for j in range(0, 48, 3):          # thumbnails fill in (every third one ticks)
            place(sfx, t + 1.0 + j * .045, blip(1600 + 20 * j), pan=-.4 + j / 60, gain=.035)
    elif k == 'drawer' and e.get('kind') == 'wipes':
        for j, pr in enumerate(e['pairs']):
            a = t + .3 + j * e['step']
            place(sfx, a + .1, whoosh(.5 if e['step'] < 2 else .9), pan=-.3, gain=.12)
            if pr.get('chip'):
                place(sfx, a + .6, chime(1567.98), gain=.05)

# trailer shots
for sh in TL['game'].get('shots', []):
    a = sh['at']
    if sh['type'] == 'card':
        place(sfx, a - .4, whoosh(.5), gain=.35)
        place(sfx, a + .02, drop(), gain=.5)
        place(sfx, a + .02, snap(), gain=.35)
        continue
    lab = sh.get('label')
    if lab == 'hero':
        place(sfx, a - .8, reverse_swell(), gain=.25)
        place(sfx, a, big_hit(), gain=.75)
        continue
    if sh.get('shake', 0) >= 1:
        place(sfx, a, boom(), gain=.6)
    elif sh.get('shake', 0) > 0:
        place(sfx, a, boom(), gain=.35)
    else:
        place(sfx, a, snap(), gain=.3)
    if sh.get('glitch'):
        place(sfx, a, glitch(), pan=.2, gain=.12)
    if lab and 'takeover' in lab:
        place(sfx, a, uplink(min(1.4, sh['dur'])), gain=.25)
    place(sfx, a - .12, whoosh(.18), gain=.08)

# ----------------------------------------------------------------------------- mix
# duck the music under SFX (smoothed SFX envelope, ~60 ms)
envs = np.abs(sfx).max(1)
w = int(.06 * SR)
sm = np.convolve(envs, np.ones(w) / w, mode='same')
duck = 1 - .45 * np.clip(sm / .05, 0, 1)
# section balance: the replay bed sits well under the trailer (about -8 dB), rising into the riser
tsec = np.arange(N) / SR
bed = np.interp(tsec, [0, GAME0 - 3.2, GAME0 - 0.2, GAME1, END0 + 1, DUR + 1], [.42, .5, 1, 1, .7, .7])
mix = music * (duck * bed)[:, None] + sfx * np.interp(tsec, [0, GAME0 - .5, GAME0, DUR + 1], [.75, .75, 1, 1])[:, None]
# fades
fi, fo = int(1.2 * SR), int(3.0 * SR)
mix[:fi] *= np.linspace(0, 1, fi)[:, None]
end = int(DUR * SR)
mix[end - fo:end] *= np.linspace(1, 0, fo)[:, None] ** 1.5
mix = mix[:end]
mix *= 10 ** (-3 / 20) / np.max(np.abs(mix))
pcm = np.clip(mix + rng.uniform(-.5, .5, mix.shape) / 32768, -1, 1)
pcm = (pcm * 32767).astype('<i2')
with wave.open(OUT, 'wb') as wf:
    wf.setnchannels(2)
    wf.setsampwidth(2)
    wf.setframerate(SR)
    wf.writeframes(pcm.tobytes())
print('wrote %s: %.2f s' % (OUT, len(pcm) / SR))

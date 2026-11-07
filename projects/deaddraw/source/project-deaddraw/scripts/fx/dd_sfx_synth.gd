# dd_sfx_synth.gd
# Purpose: dd-feel. Every DeadDraw sound effect, synthesised from code (original, no samples or
#   licensed audio): short mono 16-bit PCM at 22050 Hz. tests/tools/gen_sfx.gd writes them to
#   res://assets/audio/sfx/<id>.wav (the shipped files); DDSfx falls back to building the same
#   sound here when a file cannot be loaded (e.g. a checkout that was never imported).
#   Deterministic: noise uses a fixed seed per cue, so regenerating never changes the files.
#   Cues (CUES):
#     deal    card slides off the deck (soft paper swish)      flip     card turns face up (snap)
#     button  UI press (short tick)                            hit      zombie hurts you (thump + crack)
#     kill    weapon kill (slash + low thud)                   notch    a notch carved in the weapon (scrape tick)
#     block   Cover soaks damage (wooden knock)                equip    weapon into the slot (metal clack)
#     scrap   weapon scrapped (dull clatter)                   break    weapon shatters (bright crack + rattle)
#     heal    medkit heals (soft rising two-note)              warn     no effect / not possible (low double buzz)
#     cover   barricade raised (two wood knocks)               retreat  cards go back to the deck (falling whoosh)
#     finale  the Finale arrives (low dissonant swell + hit)   clear    district cleared (bright 3-note rise)
#     perk    safehouse perk taken (chime)                     death    overrun (low falling groan + thud)
#     win     you made it out (major arpeggio + shimmer)
# Dependencies: none.
# Author: Game Feel Engineer Agent (dd-feel)
extends RefCounted

const RATE: int = 22050
## Loudest sample value after synthesis (headroom for layering cues).
const PEAK: float = 0.85
const CUES: Array[StringName] = [
	&"deal", &"flip", &"button", &"hit", &"kill", &"notch", &"block", &"equip", &"scrap", &"break",
	&"heal", &"warn", &"cover", &"retreat", &"finale", &"clear", &"perk", &"death", &"win",
]


## Samples (-1..1) of one cue, peak-limited to PEAK; [] for an unknown id.
static func samples(id: StringName) -> PackedFloat32Array:
	var s: PackedFloat32Array = _voice(id)
	var peak: float = 0.0
	for v: float in s:
		peak = maxf(peak, absf(v))
	if peak > PEAK:
		for i: int in s.size():
			s[i] *= PEAK / peak
	# 3 ms fade out so no cue ends on a click
	var tail: int = mini(s.size(), int(0.003 * RATE))
	for k: int in tail:
		s[s.size() - 1 - k] *= float(k) / float(tail)
	return s


static func _voice(id: StringName) -> PackedFloat32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(String(id))
	match id:
		&"deal":
			return _swish(rng, 0.11, 0.55, 1.1)
		&"flip":
			return _flip(rng)
		&"button":
			return _tick(rng, 1900.0, 0.03, 0.3)
		&"hit":
			return _hit(rng)
		&"kill":
			return _kill(rng)
		&"notch":
			return _notch(rng)
		&"block":
			return _knock(rng, 0.0, 1)
		&"equip":
			return _equip(rng)
		&"scrap":
			return _scrap(rng)
		&"break":
			return _break(rng)
		&"heal":
			return _notes([523.25, 783.99], 0.07, 0.5, 0.38)
		&"warn":
			return _warn()
		&"cover":
			return _knock(rng, 0.075, 2)
		&"retreat":
			return _retreat(rng)
		&"finale":
			return _finale(rng)
		&"clear":
			return _notes([587.33, 739.99, 880.0], 0.075, 0.6, 0.42)
		&"perk":
			return _chime()
		&"death":
			return _death(rng)
		&"win":
			return _win(rng)
	return PackedFloat32Array()


## 16-bit little-endian PCM bytes of a cue.
static func pcm16(id: StringName) -> PackedByteArray:
	var s: PackedFloat32Array = samples(id)
	var out: PackedByteArray = PackedByteArray()
	out.resize(s.size() * 2)
	for i: int in s.size():
		out.encode_s16(i * 2, int(round(clampf(s[i], -1.0, 1.0) * 32767.0)))
	return out


## A ready AudioStreamWAV of a cue (built in memory).
static func stream(id: StringName) -> AudioStreamWAV:
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = pcm16(id)
	return w


## A complete .wav file (RIFF, PCM, mono, 16-bit) of a cue.
static func wav_bytes(id: StringName) -> PackedByteArray:
	var pcm: PackedByteArray = pcm16(id)
	var h: PackedByteArray = PackedByteArray()
	h.resize(44)
	h.encode_u32(0, 0x46464952)       # "RIFF"
	h.encode_u32(4, 36 + pcm.size())
	h.encode_u32(8, 0x45564157)       # "WAVE"
	h.encode_u32(12, 0x20746d66)      # "fmt "
	h.encode_u32(16, 16)
	h.encode_u16(20, 1)               # PCM
	h.encode_u16(22, 1)               # mono
	h.encode_u32(24, RATE)
	h.encode_u32(28, RATE * 2)
	h.encode_u16(32, 2)
	h.encode_u16(34, 16)
	h.encode_u32(36, 0x61746164)      # "data"
	h.encode_u32(40, pcm.size())
	h.append_array(pcm)
	return h


# --- building blocks -----------------------------------------------------------------------

static func _buf(sec: float) -> PackedFloat32Array:
	var b: PackedFloat32Array = PackedFloat32Array()
	b.resize(int(sec * RATE))
	b.fill(0.0)
	return b


## Exponential decay envelope with a short linear attack.
static func _env(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / attack
	return exp(-(t - attack) / decay)


## Filtered noise swish: one-pole low-pass whose cutoff sweeps down; a bell-shaped envelope.
static func _swish(rng: RandomNumberGenerator, sec: float, bright: float, gain: float) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(sec)
	var lp: float = 0.0
	var hp_prev: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		var x: float = t / sec
		var k: float = bright * (1.0 - 0.6 * x)
		var n: float = rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * k
		var hp: float = lp - hp_prev * 0.6
		hp_prev = lp
		var e: float = sin(PI * minf(1.0, x * 1.4)) * (1.0 - x)
		b[i] = hp * e * gain
	return b


static func _tick(rng: RandomNumberGenerator, f: float, sec: float, gain: float) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(sec)
	for i: int in b.size():
		var t: float = float(i) / RATE
		b[i] = (sin(TAU * f * t) * 0.6 + rng.randf_range(-1.0, 1.0) * 0.4) * exp(-t / 0.005) * gain
	return b


## A run of short sine notes (sine + a little 2nd harmonic), each `step` s apart, ringing `ring` s.
static func _notes(freqs: Array, step: float, ring: float, gain: float) -> PackedFloat32Array:
	var sec: float = step * float(freqs.size() - 1) + ring * 0.4
	var b: PackedFloat32Array = _buf(sec)
	for k: int in freqs.size():
		var f: float = float(freqs[k])
		var start: int = int(step * k * RATE)
		for i: int in range(start, b.size()):
			var t: float = float(i - start) / RATE
			b[i] += (sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t)) * _env(t, 0.004, ring * 0.14) * gain / sqrt(float(freqs.size()))
	return b


# --- voices --------------------------------------------------------------------------------

## Card flip: a short bright noise snap with a tiny pitched body.
static func _flip(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.06)
	var lp: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.7
		var body: float = sin(TAU * (900.0 - 4000.0 * t) * t) * exp(-t / 0.012)
		b[i] = (lp * exp(-t / 0.007) * 0.6 + body * 0.3) * 0.6
	return b


## Zombie hits you: a low sine thump with a falling pitch, a noise crack, a short growl buzz.
static func _hit(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.18)
	var phase: float = 0.0
	var lp: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		var f: float = 90.0 * (1.0 + 1.6 * exp(-t / 0.018))
		phase += TAU * f / RATE
		var thump: float = sin(phase) * _env(t, 0.001, 0.06)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.3
		var crack: float = lp * exp(-t / 0.014)
		var growl: float = signf(sin(TAU * 62.0 * t)) * 0.18 * _env(t, 0.01, 0.05)
		b[i] = (thump * 0.75 + crack * 0.6 + growl) * 0.8
	return b


## Weapon kill: a fast high-to-low noise slash then a low thud.
static func _kill(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.22)
	var lp: float = 0.0
	var phase: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		var k: float = clampf(0.95 - t * 9.0, 0.08, 0.95)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * k
		var slash: float = lp * _env(t, 0.004, 0.035)
		var td: float = maxf(0.0, t - 0.03)
		phase += TAU * (55.0 + 140.0 * exp(-td / 0.03)) / RATE
		var thud: float = sin(phase) * (_env(td, 0.002, 0.07) if t >= 0.03 else 0.0)
		b[i] = (slash * 0.7 + thud * 0.8) * 0.75
	return b


## Notch carved: a quick metallic scrape (narrow noise band) ending in a tick.
static func _notch(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.12)
	var lp: float = 0.0
	var lp2: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.6
		lp2 += (lp - lp2) * 0.6
		var band: float = (lp - lp2) * sin(TAU * 2600.0 * t)
		var scrape: float = band * (sin(PI * minf(1.0, t / 0.08)) if t < 0.08 else 0.0)
		var tick: float = sin(TAU * 3200.0 * t) * (exp(-(t - 0.085) / 0.008) if t >= 0.085 else 0.0)
		b[i] = (scrape * 1.4 + tick * 0.35) * 0.5
	return b


## Wooden knock(s): a damped resonant body at ~380 Hz with a noise click. `count` knocks `gap` apart.
static func _knock(rng: RandomNumberGenerator, gap: float, count: int) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.13 + gap * float(count - 1))
	for k: int in count:
		var start: int = int(gap * k * RATE)
		var f: float = 380.0 * (1.0 + 0.12 * k)
		for i: int in range(start, b.size()):
			var t: float = float(i - start) / RATE
			var v: float = sin(TAU * f * t) + 0.4 * sin(TAU * f * 2.3 * t) * exp(-t / 0.01)
			b[i] += (v * _env(t, 0.001, 0.03) * 0.5 + rng.randf_range(-1.0, 1.0) * exp(-t / 0.003) * 0.35)
	return b


## Weapon equipped: a metal clack (inharmonic partials) and a low slide-in thunk.
static func _equip(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.2)
	var phase: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		var ring: float = sin(TAU * 1180.0 * t) + 0.6 * sin(TAU * 1180.0 * 2.71 * t) * exp(-t / 0.02) + 0.35 * sin(TAU * 1180.0 * 4.1 * t) * exp(-t / 0.01)
		phase += TAU * (140.0 + 120.0 * exp(-t / 0.01)) / RATE
		var thunk: float = sin(phase) * _env(t, 0.001, 0.035)
		var click: float = rng.randf_range(-1.0, 1.0) * exp(-t / 0.002)
		b[i] = ring * _env(t, 0.001, 0.05) * 0.28 + thunk * 0.5 + click * 0.25
	return b


## Weapon scrapped: a dull clatter (three short low knocks of falling level).
static func _scrap(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.24)
	var hits: Array = [[0.0, 1.0, 260.0], [0.06, 0.6, 310.0], [0.11, 0.35, 230.0]]
	for h: Variant in hits:
		var a: Array = h
		var start: int = int(float(a[0]) * RATE)
		for i: int in range(start, b.size()):
			var t: float = float(i - start) / RATE
			var v: float = sin(TAU * float(a[2]) * t) * _env(t, 0.001, 0.025) + rng.randf_range(-1.0, 1.0) * exp(-t / 0.006) * 0.5
			b[i] += v * float(a[1]) * 0.45
	return b


## Weapon breaks: a bright crack, inharmonic shards and a falling rattle.
static func _break(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.3)
	var lp: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.85
		var crack: float = lp * exp(-t / 0.012)
		var shards: float = (sin(TAU * 2100.0 * t) + sin(TAU * 3170.0 * t) + sin(TAU * 4410.0 * t)) / 3.0 * _env(t, 0.001, 0.06)
		var rattle: float = (rng.randf_range(-1.0, 1.0) if fmod(t, 0.035) < 0.004 else 0.0) * exp(-t / 0.12)
		b[i] = crack * 0.7 + shards * 0.35 + rattle * 0.5
	return b


## No effect: two short low square-ish buzzes.
static func _warn() -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.2)
	for i: int in b.size():
		var t: float = float(i) / RATE
		var local: float = fmod(t, 0.1)
		var on: float = 1.0 if local < 0.07 else 0.0
		var f: float = 196.0 if t < 0.1 else 164.8
		var v: float = sin(TAU * f * t) + 0.33 * sin(TAU * f * 3.0 * t)
		b[i] = v * on * _env(local, 0.004, 0.04) * 0.4
	return b


## Cards go back to the deck: a falling whoosh then a soft stack thud.
static func _retreat(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b: PackedFloat32Array = _swish(rng, 0.22, 0.75, 0.9)
	var phase: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		if t >= 0.16:
			var td: float = t - 0.16
			phase += TAU * (120.0 + 60.0 * exp(-td / 0.01)) / RATE
			b[i] += sin(phase) * _env(td, 0.001, 0.02) * 0.4
	return b


## The Finale arrives: a low swell of two detuned tones (a tritone) with a hit at the top.
static func _finale(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var sec: float = 0.55
	var b: PackedFloat32Array = _buf(sec)
	var phase: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		var swell: float = minf(1.0, t / 0.22) * exp(-maxf(0.0, t - 0.22) / 0.12)
		var v: float = sin(TAU * 73.4 * t) + 0.7 * sin(TAU * 103.8 * t) + 0.3 * sin(TAU * 146.8 * t * 1.003)
		var td: float = t - 0.2
		var hit: float = 0.0
		if td >= 0.0:
			phase += TAU * (70.0 + 110.0 * exp(-td / 0.02)) / RATE
			hit = sin(phase) * _env(td, 0.001, 0.09) + rng.randf_range(-1.0, 1.0) * exp(-td / 0.015) * 0.4
		b[i] = v * swell * 0.35 + hit * 0.6
	return b


## Perk taken: a bell-like chime (two inharmonic partials) plus a fifth above.
static func _chime() -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.45)
	for i: int in b.size():
		var t: float = float(i) / RATE
		var v: float = sin(TAU * 880.0 * t) + 0.5 * sin(TAU * 880.0 * 2.76 * t) * exp(-t / 0.05)
		var t2: float = t - 0.06
		var v2: float = (sin(TAU * 1318.5 * t2) * _env(t2, 0.003, 0.09)) if t2 >= 0.0 else 0.0
		b[i] = v * _env(t, 0.002, 0.1) * 0.3 + v2 * 0.25
	return b


## Overrun: a low falling groan (detuned saw-ish) over a heavy thud.
static func _death(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var sec: float = 0.75
	var b: PackedFloat32Array = _buf(sec)
	var p1: float = 0.0
	var p2: float = 0.0
	var p3: float = 0.0
	var lp: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		var f: float = 150.0 * pow(0.45, t / sec)
		p1 += TAU * f / RATE
		p2 += TAU * f * 1.012 / RATE
		var saw: float = (fmod(p1, TAU) / PI - 1.0) * 0.5 + (fmod(p2, TAU) / PI - 1.0) * 0.5
		lp += (saw - lp) * 0.12
		var groan: float = lp * minf(1.0, t / 0.05) * exp(-t / 0.35)
		p3 += TAU * (45.0 + 120.0 * exp(-t / 0.03)) / RATE
		var thud: float = sin(p3) * _env(t, 0.002, 0.14) + rng.randf_range(-1.0, 1.0) * exp(-t / 0.02) * 0.3
		b[i] = groan * 0.9 + thud * 0.7
	return b


## You made it out: a rising major arpeggio with a light shimmer on top.
static func _win(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b: PackedFloat32Array = _notes([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.07, 1.0, 0.45)
	var lp: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.9
		b[i] += lp * 0.04 * (0.5 + 0.5 * sin(TAU * 9.0 * t)) * exp(-t / 0.2)
	return b

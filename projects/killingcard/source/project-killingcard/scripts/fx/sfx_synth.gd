# sfx_synth.gd
# Purpose: kc-juice. Every sound effect of the game, synthesised from code (original, no samples):
#   short mono 16-bit PCM at 22050 Hz. tests/tools/gen_sfx.gd writes them to
#   res://assets/audio/sfx/<id>.wav (the shipped files); SfxBank falls back to building the same
#   sound here when a file cannot be loaded (e.g. a checkout that was never imported).
#   Cues (CUES): the firefight beat ticks (beat_1..beat_4: the pitch rises a minor third per beat
#   and each step layers one more partial), the round-step cues (step_1 Reveal, step_2 Firefight,
#   step_3 Score: rising two-tone chirps), hit, hit_big, kill, block (Cover / no damage), card_land
#   (the calling-card stamp), click (button press), supply (a Supply hex spent), column_win and
#   reward. kc-ks-seq: the killstreak sequences (ks_whistle: the mortar's falling whistle,
#   ks_rotor: the helo's rotor chop, ks_scan: the recon drone's rising scan ping).
#   Deterministic: the noise uses a fixed seed per cue, so the generated files never change.
# Dependencies: none.
# Author: Game Feel Engineer Agent (kc-juice)
extends RefCounted

const RATE: int = 22050
## Loudest sample value after synthesis (headroom for layering several cues).
const PEAK: float = 0.85
const CUES: Array[StringName] = [
	&"beat_1", &"beat_2", &"beat_3", &"beat_4",
	&"step_1", &"step_2", &"step_3",
	&"hit", &"hit_big", &"kill", &"block", &"card_land", &"click", &"supply", &"column_win", &"reward",
	&"ks_whistle", &"ks_rotor", &"ks_scan",
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
	return s


static func _voice(id: StringName) -> PackedFloat32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(String(id))
	match id:
		&"beat_1", &"beat_2", &"beat_3", &"beat_4":
			return _beat(int(String(id).right(1)), rng)
		&"step_1", &"step_2", &"step_3":
			return _step(int(String(id).right(1)))
		&"hit":
			return _hit(rng, 0.09, 150.0, 0.55)
		&"hit_big":
			return _hit(rng, 0.15, 95.0, 0.8)
		&"kill":
			return _kill(rng)
		&"block":
			return _block(rng)
		&"card_land":
			return _card_land(rng)
		&"click":
			return _click(rng)
		&"supply":
			return _notes([1046.5, 1568.0], 0.045, 0.6, 0.35)
		&"column_win":
			return _notes([523.25, 659.25, 783.99, 1046.5], 0.07, 0.75, 0.45)
		&"reward":
			return _reward(rng)
		&"ks_whistle":
			return _whistle()
		&"ks_rotor":
			return _rotor(rng)
		&"ks_scan":
			return _scan()
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


# --- voices ------------------------------------------------------------------------------

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


## The firefight beat tick: a bright blip, a minor third higher per beat; beat n layers n partials
## (octave, fifth above it, a noise click) so the steps also differ in colour, not only in pitch.
static func _beat(n: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.075)
	var f: float = 587.33 * pow(2.0, 3.0 * float(n - 1) / 12.0)
	for i: int in b.size():
		var t: float = float(i) / RATE
		var e: float = _env(t, 0.002, 0.022)
		var v: float = sin(TAU * f * t)
		if n >= 2:
			v += 0.45 * sin(TAU * f * 2.0 * t)
		if n >= 3:
			v += 0.3 * sin(TAU * f * 3.0 * t)
		if n >= 4:
			v += 0.35 * rng.randf_range(-1.0, 1.0) * exp(-t / 0.006)
		b[i] = v * e * 0.32
	return b


## Round-step cue: a two-tone rising chirp, higher for each step (Reveal < Firefight < Score).
static func _step(n: int) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.16)
	var f0: float = 330.0 * pow(2.0, 4.0 * float(n - 1) / 12.0)
	var phase: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		var f: float = f0 if t < 0.06 else f0 * 1.5
		phase += TAU * f / RATE
		var e: float = _env(fmod(t, 0.08) if t < 0.06 else t - 0.06, 0.004, 0.05)
		b[i] = (sin(phase) * 0.8 + 0.2 * sin(phase * 2.0)) * e * 0.3
	return b


## Impact: a low sine thump with a falling pitch plus a short band-limited noise crack.
static func _hit(rng: RandomNumberGenerator, sec: float, f_low: float, gain: float) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(sec)
	var phase: float = 0.0
	var lp: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		var f: float = f_low * (1.0 + 1.5 * exp(-t / 0.015))
		phase += TAU * f / RATE
		var thump: float = sin(phase) * _env(t, 0.001, sec * 0.35)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		var crack: float = lp * exp(-t / 0.012)
		b[i] = (thump * 0.7 + crack * 0.6) * gain
	return b


## Elimination: a deep down-sweep thud, a noise burst and a dull ring.
static func _kill(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.24)
	var phase: float = 0.0
	var lp: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		var f: float = 60.0 + 180.0 * exp(-t / 0.04)
		phase += TAU * f / RATE
		var thud: float = sin(phase) * _env(t, 0.002, 0.09)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.22
		var burst: float = lp * exp(-t / 0.03)
		var ring: float = sin(TAU * 220.0 * t) * 0.25 * _env(t, 0.01, 0.07)
		b[i] = (thud * 0.75 + burst * 0.7 + ring) * 0.7
	return b


## Cover / no damage: a short metallic "tink" (inharmonic partials) with a tiny click.
static func _block(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.14)
	var f: float = 1250.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		var v: float = sin(TAU * f * t) + 0.55 * sin(TAU * f * 2.76 * t) * exp(-t / 0.02) + 0.3 * sin(TAU * f * 5.4 * t) * exp(-t / 0.01)
		var click: float = rng.randf_range(-1.0, 1.0) * exp(-t / 0.002)
		b[i] = (v * _env(t, 0.001, 0.035) * 0.3 + click * 0.25)
	return b


## The calling-card stamp: a soft low thud plus a short paper slap. Subtle by design.
static func _card_land(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.12)
	var lp: float = 0.0
	var phase: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		phase += TAU * (110.0 + 90.0 * exp(-t / 0.01)) / RATE
		var thud: float = sin(phase) * _env(t, 0.001, 0.03)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.5
		var slap: float = lp * exp(-t / 0.008)
		b[i] = (thud * 0.6 + slap * 0.45) * 0.55
	return b


## Button press: a 25 ms high tick.
static func _click(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.025)
	for i: int in b.size():
		var t: float = float(i) / RATE
		b[i] = (sin(TAU * 2200.0 * t) * 0.6 + rng.randf_range(-1.0, 1.0) * 0.4) * exp(-t / 0.004) * 0.3
	return b


## A run of short sine notes (sine + a little 2nd harmonic), each `step` s apart, ringing `ring` s.
static func _notes(freqs: Array, step: float, ring: float, gain: float) -> PackedFloat32Array:
	var sec: float = step * float(freqs.size() - 1) + ring * 0.35
	var b: PackedFloat32Array = _buf(sec)
	for k: int in freqs.size():
		var f: float = float(freqs[k])
		var start: int = int(step * k * RATE)
		for i: int in range(start, b.size()):
			var t: float = float(i - start) / RATE
			b[i] += (sin(TAU * f * t) + 0.2 * sin(TAU * f * 2.0 * t)) * _env(t, 0.003, ring * 0.12) * gain / sqrt(float(freqs.size()))
	return b


## Reward reveal: a rising arpeggio with a light sparkle on top.
static func _reward(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b: PackedFloat32Array = _notes([659.25, 783.99, 987.77, 1318.5], 0.06, 0.8, 0.4)
	var lp: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.9
		b[i] += lp * 0.05 * sin(TAU * 7.0 * t) * exp(-t / 0.15)
	return b


## kc-ks-seq: a falling shell's whistle, a sine gliding down an octave with a little vibrato.
static func _whistle() -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.55)
	var phase: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		var k: float = t / 0.55
		var f: float = 1900.0 * pow(0.5, k) * (1.0 + 0.01 * sin(TAU * 9.0 * t))
		phase += TAU * f / RATE
		var e: float = minf(1.0, t / 0.06) * (1.0 - k * 0.6)
		b[i] = sin(phase) * e * 0.28
	return b


## kc-ks-seq: helicopter rotor chop: noise pulsed at 14 Hz over a low hum.
static func _rotor(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.7)
	var lp: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08
		var chop: float = pow(maxf(0.0, sin(TAU * 14.0 * t)), 6.0)
		var e: float = minf(1.0, t / 0.08) * minf(1.0, (0.7 - t) / 0.15)
		b[i] = (lp * 2.6 * chop + 0.18 * sin(TAU * 70.0 * t)) * e * 0.6
	return b


## kc-ks-seq: recon scan: two short rising pings.
static func _scan() -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.4)
	for k: int in 2:
		var start: int = int(0.16 * k * RATE)
		for i: int in range(start, b.size()):
			var t: float = float(i - start) / RATE
			var f: float = 1400.0 + 900.0 * minf(1.0, t / 0.08) + 300.0 * k
			b[i] += sin(TAU * f * t) * _env(t, 0.004, 0.05) * 0.3
	return b

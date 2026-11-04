# fx_sfx.gd
# Adapted from CallingCard scripts/fx/fx_sfx.gd (cc15): same pool and synthesis approach, new sounds.
# Purpose: Procedural placeholder SFX for CardZone's looting and shooting feedback (cz17). Each sound
#   is synthesised once into an AudioStreamWAV (16-bit mono, 22.05 kHz, a few KB) and played from a
#   small pool of AudioStreamPlayers so overlapping beats never cut each other off. No audio files.
#   Sounds:
#     shot     dry crack + short noise tail          marker   two-click tick (hit marker)
#     frag     low thump with a noise burst           slam     heavy card slap (Hit on the loadout)
#     burn     crackling noise swell (Brace burn)     loot     soft card flick + tone (pitch by rarity)
#     loot_rare  two-note chime added for Epic / Legendary
#     drop     falling whistle + thud (supply drop)   gas      filtered hiss sweep
#     down     falling two-tone                       heal     rising two-tone
#     stamp    elimination slam + low ring            move     soft step
#   Swap in real assets later with set_stream(id, stream).
# Usage: var sfx := FxSfx.new(); add_child(sfx); sfx.play(&"shot")
# Dependencies: Settings autoload (master_volume, optional).
# Author: Game Feel Engineer Agent (cz17)
extends Node

const RATE: int = 22050
const POOL: int = 6
const IDS: Array[StringName] = [&"shot", &"marker", &"frag", &"slam", &"burn", &"loot", &"loot_rare", &"drop",
		&"gas", &"down", &"heal", &"stamp", &"move"]
const LENGTH: Dictionary = {&"shot": 0.22, &"marker": 0.10, &"frag": 0.45, &"slam": 0.20, &"burn": 0.45,
		&"loot": 0.16, &"loot_rare": 0.42, &"drop": 0.40, &"gas": 0.50, &"down": 0.30, &"heal": 0.32,
		&"stamp": 0.60, &"move": 0.10}

static var _cache: Dictionary = {}

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
## Last sounds played (tests, newest last; capped).
var history: Array[StringName] = []


func _ready() -> void:
	for i: int in POOL:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "Voice%d" % i
		add_child(p)
		_players.append(p)


func play(id: StringName, pitch: float = 1.0) -> void:
	history.append(id)
	if history.size() > 48:
		history.remove_at(0)
	if _players.is_empty() or DisplayServer.get_name() == "headless":
		return
	var s: Node = get_node_or_null(^"/root/Settings")
	var vol: float = clampf(float(s.get(&"master_volume")), 0.0, 1.0) if s != null else 0.8
	if vol <= 0.001:
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream(id)
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(vol) - 6.0
	p.play()


func stop_all() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()


static func set_stream(id: StringName, s: AudioStream) -> void:
	_cache[id] = s


static func stream(id: StringName) -> AudioStream:
	if not _cache.has(id):
		_cache[id] = _make(id)
	return _cache[id]


# --- Synthesis ---------------------------------------------------------------------------------

static func _make(id: StringName) -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(id)
	var len_s: float = float(LENGTH.get(id, 0.2))
	var n: int = int(len_s * RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	var phase: float = 0.0
	var lp: float = 0.0
	var hp_prev: float = 0.0
	for i: int in n:
		var t: float = float(i) / RATE
		var v: float = 0.0
		var noise: float = rng.randf_range(-1.0, 1.0)
		match id:
			&"shot":
				lp = lerpf(lp, noise, 0.55)
				phase += TAU * lerpf(900.0, 160.0, minf(t / 0.05, 1.0)) / RATE
				v = noise * exp(-t * 70.0) * 0.8 + lp * exp(-t * 18.0) * 0.35 + sin(phase) * exp(-t * 40.0) * 0.4
			&"marker":
				var click: float = exp(-t * 400.0) + exp(-maxf(t - 0.045, 0.0) * 400.0) * float(t > 0.045)
				v = sin(TAU * 2400.0 * t) * click * 0.45
			&"frag":
				lp = lerpf(lp, noise, 0.08)
				phase += TAU * lerpf(110.0, 38.0, minf(t / 0.3, 1.0)) / RATE
				v = sin(phase) * exp(-t * 7.0) * 0.8 + lp * exp(-t * 6.0) * 1.4
			&"slam":
				lp = lerpf(lp, noise, 0.35)
				phase += TAU * lerpf(170.0, 60.0, minf(t / 0.1, 1.0)) / RATE
				v = sin(phase) * exp(-t * 24.0) * 0.9 + lp * exp(-t * 50.0) * 0.7
			&"burn":
				# Crackle: sparse pops over a soft noise bed that swells and fades.
				lp = lerpf(lp, noise, 0.12)
				var env: float = sin(PI * clampf(t / len_s, 0.0, 1.0))
				var pop: float = noise * 0.9 if rng.randf() < 0.004 else 0.0
				v = lp * env * 0.6 + pop
			&"loot":
				phase += TAU * lerpf(700.0, 1100.0, t / len_s) / RATE
				v = sin(phase) * exp(-t * 26.0) * 0.45 + noise * exp(-t * 120.0) * 0.35
			&"loot_rare":
				for k: int in 2:
					var start: float = k * 0.09
					if t >= start:
						var f: float = [987.77, 1318.51][k]
						v += sin(TAU * f * (t - start)) * exp(-(t - start) * 7.0) * 0.28 * minf((t - start) * 300.0, 1.0)
			&"drop":
				var fall: float = clampf(t / 0.22, 0.0, 1.0)
				phase += TAU * lerpf(1400.0, 500.0, fall) / RATE
				lp = lerpf(lp, noise, 0.2)
				var thud_t: float = maxf(t - 0.22, 0.0)
				v = sin(phase) * 0.12 * float(t < 0.22) * fall \
						+ (sin(TAU * 70.0 * thud_t) * 0.9 + lp * 0.6) * exp(-thud_t * 16.0) * float(t >= 0.22)
			&"gas":
				# High-passed noise, swelling then fading: a hiss sweeping across.
				var hp: float = noise - hp_prev
				hp_prev = noise
				lp = lerpf(lp, hp, lerpf(0.1, 0.5, t / len_s))
				v = lp * sin(PI * clampf(t / len_s, 0.0, 1.0)) * 0.7
			&"down":
				var f2: float = 330.0 if t < 0.14 else 247.0
				var tt: float = t if t < 0.14 else t - 0.14
				v = sin(TAU * f2 * t) * exp(-tt * 14.0) * 0.4 * minf(tt * 400.0, 1.0)
			&"heal":
				var f3: float = 523.25 if t < 0.12 else 783.99
				var tu: float = t if t < 0.12 else t - 0.12
				v = sin(TAU * f3 * t) * exp(-tu * 10.0) * 0.32 * minf(tu * 400.0, 1.0)
			&"stamp":
				phase += TAU * lerpf(130.0, 45.0, minf(t / 0.25, 1.0)) / RATE
				lp = lerpf(lp, noise, 0.5)
				v = sin(phase) * exp(-t * 9.0) * 0.9 + lp * exp(-t * 40.0) * 0.6 \
						+ sin(TAU * 196.0 * t) * exp(-maxf(t - 0.05, 0.0) * 5.0) * 0.16 * float(t > 0.05)
			&"move":
				lp = lerpf(lp, noise, 0.25)
				v = lp * exp(-t * 45.0) * 0.5
		var fade: float = minf(1.0, float(n - i) / 200.0)
		var s: int = int(clampf(v * fade, -1.0, 1.0) * 30000.0)
		data.encode_s16(i * 2, s)
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

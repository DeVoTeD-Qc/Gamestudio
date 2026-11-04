# fx_sfx.gd
# Purpose: Procedural placeholder SFX for the duel feedback layer (cc15). Killstreak had no audio
#   code to reuse, so this is new and tiny: each sound is synthesised once into an AudioStreamWAV
#   (16-bit mono, 22.05 kHz, a few KB) and played from a small pool of AudioStreamPlayers so
#   overlapping hits never cut each other off. No audio files, nothing to download on the web.
#   Sounds: drop (soft thud + dust hiss), thunk (capture / reclaim), flip (Ambush eye-open click),
#   link (Set Link chime), stamp ("Carded!" slam + bell), triptych (rising three-note chord).
#   Swap in real assets later with set_stream(id, stream).
# Usage: var sfx := FxSfx.new(); add_child(sfx); sfx.play(&"thunk")
# Dependencies: Settings autoload (master_volume, optional).
# Author: Game Feel Engineer Agent (cc15)
extends Node

const RATE: int = 22050
const POOL: int = 6
const IDS: Array[StringName] = [&"drop", &"thunk", &"flip", &"link", &"stamp", &"triptych"]

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
	if history.size() > 32:
		history.remove_at(0)
	if _players.is_empty():
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream(id)
	p.pitch_scale = pitch
	var s: Node = get_node_or_null(^"/root/Settings")
	var vol: float = clampf(float(s.get(&"master_volume")), 0.0, 1.0) if s != null else 0.8
	if vol <= 0.001:
		return
	p.volume_db = linear_to_db(vol) - 6.0
	p.play()


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
	var len_s: float = {&"drop": 0.16, &"thunk": 0.18, &"flip": 0.14, &"link": 0.35, &"stamp": 0.45, &"triptych": 0.8}.get(id, 0.2)
	var n: int = int(len_s * RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	var phase: float = 0.0
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / RATE
		var v: float = 0.0
		match id:
			&"drop":
				phase += TAU * lerpf(140.0, 70.0, t / len_s) / RATE
				lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.15)
				v = sin(phase) * exp(-t * 30.0) * 0.8 + lp * exp(-t * 18.0) * 0.5
			&"thunk":
				phase += TAU * lerpf(190.0, 75.0, minf(t / 0.12, 1.0)) / RATE
				lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.3)
				v = sin(phase) * exp(-t * 22.0) * 0.9 + lp * exp(-t * 60.0) * 0.4
			&"flip":
				phase += TAU * lerpf(500.0, 1500.0, t / len_s) / RATE
				v = sin(phase) * exp(-t * 28.0) * 0.5 + (rng.randf_range(-1.0, 1.0) * exp(-t * 300.0)) * 0.6
			&"link":
				v = (sin(TAU * 880.0 * t) * 0.5 + sin(TAU * 1320.0 * t) * 0.35) * exp(-t * 9.0) * minf(t * 200.0, 1.0)
			&"stamp":
				phase += TAU * lerpf(120.0, 48.0, minf(t / 0.2, 1.0)) / RATE
				lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.5)
				v = sin(phase) * exp(-t * 12.0) * 0.9 + lp * exp(-t * 40.0) * 0.6 \
						+ sin(TAU * 1760.0 * t) * exp(-maxf(t - 0.05, 0.0) * 8.0) * 0.18 * float(t > 0.05)
			&"triptych":
				for k: int in 3:
					var start: float = k * 0.12
					if t >= start:
						var f: float = [523.25, 659.25, 783.99][k]
						v += sin(TAU * f * (t - start)) * exp(-(t - start) * 4.0) * 0.3 * minf((t - start) * 300.0, 1.0)
		var fade: float = minf(1.0, float(n - i) / 200.0)
		var s: int = int(clampf(v * fade, -1.0, 1.0) * 30000.0)
		data.encode_s16(i * 2, s)
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

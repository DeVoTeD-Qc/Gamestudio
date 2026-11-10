# sfx_bank.gd
# Purpose: kc-juice. Plays the game's sound effects (all procedurally made, see sfx_synth.gd).
#   One node, created by the Settings autoload as /root/Settings/Sfx, so it exists in every scene
#   and in the headless tests. It
#   - loads res://assets/audio/sfx/<id>.wav (falls back to synthesising the cue in memory);
#   - plays through a pool of POOL_SIZE AudioStreamPlayers on the "SFX" bus, so a new cue never
#     cuts off the one before it (the oldest voice is reused when all are busy);
#   - drops a repeat of the same cue inside REPEAT_GUARD s (two shots landing on one frame);
#   - creates the "SFX" bus (sent to Master) and applies Settings.master_volume / sfx_volume;
#   - gives every BaseButton in the tree press feedback: a click and a short brighten
#     (self_modulate, no size or position change). A button with meta &"no_press_fx" opts out.
#   Use: SfxBank.cue(&"hit") from anywhere (a no-op when the bank is missing).
#   `played` lists every cue played ({id, pitch}) for the tests.
# Dependencies: sfx_synth.gd, Settings autoload (volumes; it owns this node).
# Author: Game Feel Engineer Agent (kc-juice)
extends Node

const SfxSynth: GDScript = preload("res://scripts/fx/sfx_synth.gd")
const DIR: String = "res://assets/audio/sfx"
const BUS: StringName = &"SFX"
const POOL_SIZE: int = 8
const REPEAT_GUARD: float = 0.03
## Per-cue level (dB) so the set sits together: the impacts are loud by nature, ticks are not.
const CUE_DB: Dictionary = {
	&"click": -8.0, &"card_land": -4.0, &"supply": -6.0, &"hit": -2.0, &"hit_big": -1.0, &"kill": -1.0,
	&"block": -4.0, &"beat_1": -5.0, &"beat_2": -5.0, &"beat_3": -5.0, &"beat_4": -5.0,
	&"step_1": -6.0, &"step_2": -6.0, &"step_3": -6.0, &"column_win": -4.0, &"reward": -3.0,
	&"ks_whistle": -6.0, &"ks_rotor": -5.0, &"ks_scan": -7.0,
}

var played: Array[Dictionary] = []
## Off: play() logs nothing and makes no sound (tests that count other things may turn it off).
var enabled: bool = true
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _last_at: Dictionary = {}   # id -> ticks msec of its last play


## The bank under the Settings autoload, or null.
static func bank() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(^"Settings/Sfx")
	return null


## Plays a cue if the bank exists. pitch: playback pitch scale; db: extra level.
static func cue(id: StringName, pitch: float = 1.0, db: float = 0.0) -> void:
	var b: Node = bank()
	if b != null:
		b.play(id, pitch, db)


func _ready() -> void:
	ensure_bus()
	for i: int in POOL_SIZE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "Voice%d" % i
		p.bus = BUS
		add_child(p)
		_players.append(p)
	var settings: Node = get_parent()
	if settings != null and settings.has_signal(&"settings_changed"):
		settings.settings_changed.connect(apply_volumes)
	apply_volumes()
	get_tree().node_added.connect(_on_node_added)


## Creates the SFX bus (sent to Master) once.
static func ensure_bus() -> int:
	var idx: int = AudioServer.get_bus_index(BUS)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, &"Master")
	return idx


## Settings.master_volume -> Master, Settings.sfx_volume -> SFX (linear 0..1; 0 mutes).
func apply_volumes() -> void:
	var settings: Node = get_parent()
	var master: float = float(settings.get(&"master_volume")) if settings != null and "master_volume" in settings else 0.8
	var sfx: float = float(settings.get(&"sfx_volume")) if settings != null and "sfx_volume" in settings else 0.8
	_set_bus(AudioServer.get_bus_index(&"Master"), master)
	_set_bus(ensure_bus(), sfx)


static func _set_bus(idx: int, linear: float) -> void:
	if idx < 0:
		return
	var v: float = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


## The stream of a cue (file first, else synthesised), cached. null for an unknown id.
func stream_for(id: StringName) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var s: AudioStream = null
	var path: String = DIR.path_join("%s.wav" % id)
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
	if s == null and id in SfxSynth.CUES:
		s = SfxSynth.stream(id)
	_streams[id] = s
	return s


## Plays a cue. Returns true if it played (false: unknown, disabled, or a repeat inside the guard).
func play(id: StringName, pitch: float = 1.0, db: float = 0.0) -> bool:
	if not enabled:
		return false
	var now: int = Time.get_ticks_msec()
	if _last_at.has(id) and now - int(_last_at[id]) < int(REPEAT_GUARD * 1000.0):
		return false
	var s: AudioStream = stream_for(id)
	if s == null or _players.is_empty():
		return false
	_last_at[id] = now
	var p: AudioStreamPlayer = _free_player()
	p.stream = s
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = float(CUE_DB.get(id, 0.0)) + db
	p.play()
	played.append({"id": id, "pitch": p.pitch_scale})
	if played.size() > 512:
		played = played.slice(-256)
	return true


func clear_log() -> void:
	played.clear()
	_last_at.clear()


## Ids played since clear_log(), in order.
func played_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Dictionary in played:
		out.append(e["id"])
	return out


func _free_player() -> AudioStreamPlayer:
	for i: int in _players.size():
		var p: AudioStreamPlayer = _players[(_next + i) % _players.size()]
		if not p.playing:
			_next = (_next + i + 1) % _players.size()
			return p
	var oldest: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	return oldest


# --- button press feedback -------------------------------------------------------------------

func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta(&"no_press_fx"):
		var b: BaseButton = node as BaseButton
		if not b.button_down.is_connected(press_feedback):
			b.button_down.connect(press_feedback.bind(b))


## A click and a 120 ms brighten on the button (colour only: no layout change, so it also runs
## with reduced motion).
func press_feedback(b: BaseButton) -> void:
	if b == null or not is_instance_valid(b) or b.disabled:
		return
	play(&"click", randf_range(0.96, 1.04))
	if not b.is_inside_tree():
		return
	var old: Tween = b.get_meta(&"press_tween") as Tween if b.has_meta(&"press_tween") else null
	if old != null and old.is_valid():
		old.kill()
	b.self_modulate = Color(1.3, 1.3, 1.3)
	var tw: Tween = b.create_tween()
	tw.tween_property(b, "self_modulate", Color.WHITE, 0.12)
	b.set_meta(&"press_tween", tw)

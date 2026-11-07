# dd_sfx.gd
# Purpose: dd-feel. Plays DeadDraw's sound effects (all generated, see dd_sfx_synth.gd). One node,
#   created by the Game autoload as /root/Game/Sfx, so it exists in every scene and in the tests.
#   - loads res://assets/audio/sfx/<id>.wav, else synthesises the cue in memory;
#   - plays through POOL_SIZE AudioStreamPlayers on the "SFX" bus, so a new cue never cuts off the
#     one before it (the oldest voice is reused when all are busy);
#   - drops a repeat of the same cue inside REPEAT_GUARD_MS (two events on one frame);
#   - creates the "SFX" bus (sent to Master) and applies the profile's master / SFX volume;
#   - gives every Button in the tree a press click (meta &"no_click" opts out).
#   Use: DDSfx.cue(&"hit") from anywhere (a no-op when the bank is missing).
#   `played` lists the cue ids played, for the tests.
# Dependencies: dd_sfx_synth.gd.
# Author: Game Feel Engineer Agent (dd-feel)
extends Node

const Synth: GDScript = preload("res://scripts/fx/dd_sfx_synth.gd")
const DIR: String = "res://assets/audio/sfx"
const BUS: StringName = &"SFX"
const POOL_SIZE: int = 8
const REPEAT_GUARD_MS: int = 30
## Per-cue level (dB) so the set sits together.
const CUE_DB: Dictionary = {
	&"deal": -6.0, &"flip": -8.0, &"button": -10.0, &"hit": -2.0, &"kill": -2.0, &"notch": -6.0,
	&"block": -5.0, &"equip": -4.0, &"scrap": -5.0, &"break": -3.0, &"heal": -4.0, &"warn": -7.0,
	&"cover": -4.0, &"retreat": -5.0, &"finale": -2.0, &"clear": -3.0, &"perk": -4.0,
	&"death": -1.0, &"win": -3.0,
}

var played: Array[StringName] = []
## Off: play() logs nothing and makes no sound.
var enabled: bool = true
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _last_at: Dictionary = {}


## The bank under the Game autoload, or null.
static func bank() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(^"Game/Sfx")
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
	get_tree().node_added.connect(_on_node_added)


## Creates the SFX bus (sent to Master) once. Returns its index.
static func ensure_bus() -> int:
	var idx: int = AudioServer.get_bus_index(BUS)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, &"Master")
	return idx


## master / sfx: linear 0..1 (0 mutes the bus).
static func apply_volumes(master: float, sfx: float) -> void:
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
	if s == null and id in Synth.CUES:
		s = Synth.stream(id)
	_streams[id] = s
	return s


## Plays a cue. True if it played (false: unknown id, disabled, or a repeat inside the guard).
func play(id: StringName, pitch: float = 1.0, db: float = 0.0) -> bool:
	if not enabled:
		return false
	var now: int = Time.get_ticks_msec()
	if _last_at.has(id) and now - int(_last_at[id]) < REPEAT_GUARD_MS:
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
	played.append(id)
	if played.size() > 512:
		played = played.slice(-256)
	return true


func clear_log() -> void:
	played.clear()
	_last_at.clear()


func _free_player() -> AudioStreamPlayer:
	for i: int in _players.size():
		var p: AudioStreamPlayer = _players[(_next + i) % _players.size()]
		if not p.playing:
			_next = (_next + i + 1) % _players.size()
			return p
	var oldest: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	return oldest


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta(&"no_click"):
		var b: BaseButton = node as BaseButton
		if not b.button_down.is_connected(_on_button_down):
			b.button_down.connect(_on_button_down.bind(b))


func _on_button_down(b: BaseButton) -> void:
	if b != null and is_instance_valid(b) and not b.disabled:
		play(&"button", randf_range(0.96, 1.04))

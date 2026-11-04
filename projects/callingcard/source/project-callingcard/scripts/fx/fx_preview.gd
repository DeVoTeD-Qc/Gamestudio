# fx_preview.gd
# Purpose: FX preview (scenes/fx/FxPreview.tscn): the duel screen on the cc07 mock mid-duel wall,
#   replaying the cc15 effects in a loop so designers can judge timing without playing a duel:
#   drop -> Set Link light -> capture wipe -> "Carded!" -> Ambush flip -> Triptych merge, then reset.
#   Prints "FXPREVIEW <effect>" as each one starts (QA screenshots key off it).
#   Keys: F = toggle fast animations, R = toggle reduced motion (printed).
# Dependencies: scenes/Duel.tscn, DuelFx, MockDuelData, EventBus, Settings.
# Author: Game Feel Engineer Agent (cc15)
extends Node

const DUEL_SCENE: String = "res://scenes/Duel.tscn"
const MockDuelData: GDScript = preload("res://scripts/ui/mock_duel_data.gd")
const DuelControllerScript: GDScript = preload("res://scripts/duel/duel_controller.gd")

var _duel: Control = null


func _ready() -> void:
	DuelControllerScript.set_autostart(false)
	_duel = (load(DUEL_SCENE) as PackedScene).instantiate()
	add_child(_duel)
	DuelControllerScript.set_autostart(true)
	_loop.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var s: Node = get_node_or_null(^"/root/Settings")
		if s == null:
			return
		if event.keycode == KEY_F:
			s.set_value(&"fast_animations", not s.fast_animations)
			print("FXPREVIEW fast_animations=%s" % s.fast_animations)
		elif event.keycode == KEY_R:
			s.set_value(&"reduced_motion", not s.reduced_motion)
			print("FXPREVIEW reduced_motion=%s" % s.reduced_motion)


func _loop() -> void:
	var fx: DuelFx = _duel.get_node("%FX")
	while is_inside_tree():
		var st: Dictionary = MockDuelData.mid_state()
		st["wall"].erase(&"a2")
		_duel.show_state(st)
		await _wait(1.0)
		_fire("drop", func() -> void: EventBus.card_placed.emit(&"player", &"neon_rain", &"b1", []))
		await _wait(0.5)
		_fire("link", func() -> void: EventBus.set_linked.emit(&"player", &"b1", [&"a1", &"c1"]))
		await _wait(0.8)
		fx.stage_changes = true
		_fire("capture", func() -> void: EventBus.card_captured.emit(&"player", &"brass_tacks", &"b2"))
		await fx.wait_idle()
		_fire("carded", func() -> void: EventBus.carded.emit(&"player", &"brass_tacks"))
		await fx.wait_idle()
		await _wait(0.6)
		_fire("flip", func() -> void: EventBus.ambush_sprung.emit(&"rival", &"flare_up", &"b3"))
		await _wait(0.8)
		var trip: Dictionary = st.duplicate(true)
		trip["wall"] = {&"c1": {"card_id": &"graveyard_shift", "owner": &"player"},
				&"c2": {"card_id": &"neon_rain", "owner": &"player"}, &"c3": {"card_id": &"last_train", "owner": &"player"}}
		_duel.show_state(trip)
		await _wait(0.4)
		_fire("triptych", func() -> void: EventBus.triptych_scored.emit(&"player", &"midnight_run", true))
		await fx.wait_idle(3.0)
		fx.stage_changes = false
		await _wait(1.0)


func _fire(label: String, f: Callable) -> void:
	print("FXPREVIEW %s" % label)
	f.call()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

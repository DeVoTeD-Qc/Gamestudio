# fx_preview.gd
# Purpose: Preview / QA scene for the combat feedback layer (p14). It shows the p08 match
#   screen with its static mock snapshot (Match.tscn, unchanged; its p09 MatchController
#   gets autostart = false), wires a Killfeed into
#   KillfeedSlot and a StreakArc next to the Operator panel's streak number at runtime (the
#   same wiring p09's match controller will do), and replays a scripted list of RulesEvent
#   dictionaries through FeedbackDirector in a loop.
#   Checkpoints for screenshots: open with `#cp=<name>&t=<seconds>` on the web (or
#   `-- --cp=<name> --t=<seconds>` on desktop). Everything before the checkpoint is played
#   instantly (skip), then the checkpoint plays and the tree pauses after t seconds.
#   Names: mid_firefight, left_trade, takeover (kc-ks-seq: the mortar's queue + strike), streak, shatter.
# Dependencies: scenes/Match.tscn (read-only), scenes/fx/*, scripts/fx/*.
# Author: Game Feel Engineer Agent (p14)
extends Control

const BoardFxLocator: GDScript = preload("res://scripts/fx/board_fx_locator.gd")
const KillfeedScene: PackedScene = preload("res://scenes/fx/Killfeed.tscn")
const StreakArcScene: PackedScene = preload("res://scenes/fx/StreakArc.tscn")
const MatchScene: PackedScene = preload("res://scenes/Match.tscn")
const LOOP_PAUSE: float = 1.4

var _match: Control = null
@onready var _director: Control = $FeedbackDirector

var _streak_value: Label = null
var _checkpoints: Dictionary = {}   # name -> index of its first event
var _events: Array = []


func _ready() -> void:
	# The match screen with its static mock snapshot: the p09 controller must not start a match.
	_match = MatchScene.instantiate()
	var controller: Node = _match.get_node_or_null(^"MatchController")
	if controller != null and "autostart" in controller:
		controller.set(&"autostart", false)
	if "use_mock_data" in _match:
		_match.set(&"use_mock_data", true)
	add_child(_match)
	move_child(_match, 0)
	await get_tree().process_frame
	_wire()
	_events = _script_events()
	var args: Dictionary = _read_args()
	if args.has("cp") and _checkpoints.has(args["cp"]):
		_play_checkpoint(String(args["cp"]), float(args.get("t", 0.3)))
	else:
		_loop()


## The wiring the match controller will do (see the p14 hand-off notes).
func _wire() -> void:
	var slot: Control = _match.get_node(^"%KillfeedSlot")
	for child: Node in slot.get_children():   # p08 placeholder lines
		slot.remove_child(child)
		child.queue_free()
	var feed: Control = KillfeedScene.instantiate()
	slot.add_child(feed)
	_director.killfeed = feed

	var panel: Control = _match.get_node(^"%OperatorPanel")
	var segments: Control = panel.get_node(^"%StreakSegments")
	_streak_value = panel.get_node(^"%StreakValue")
	var arc: Control = StreakArcScene.instantiate()
	arc.custom_minimum_size = Vector2(0, 30)
	segments.get_parent().add_child(arc)
	segments.get_parent().move_child(arc, segments.get_index())
	segments.visible = false
	arc.configure(5, [2, 3, 5], 1)
	_director.streak_arc = arc

	var locator: RefCounted = BoardFxLocator.new(_match.get_node(^"%Board"))
	locator.anchors[&"score"] = _match.get_node(^"%ScoreBar")
	locator.anchors[&"streak"] = panel
	# Mock snapshot (mock_match_data.gd round_3_sample) slots -> uids.
	locator.set_unit(1, &"player", &"left", 0)    # Point Man
	locator.set_unit(21, &"enemy", &"left", 0)    # incoming red dot, revealed as a Breacher
	locator.set_unit(10, &"player", &"mid", 0)    # Operator
	locator.set_unit(22, &"enemy", &"mid", 0)     # Marksman
	locator.set_unit(23, &"enemy", &"right", 0)   # Rifleman
	locator.set_unit(24, &"enemy", &"right", 1)   # Gunner
	_director.locator = locator
	_director.unit_names = {1: "Point Man", 10: "Kestrel AR-7", 21: "Breacher", 22: "Marksman",
			23: "Rifleman", 24: "Gunner"}
	_director.event_started.connect(_on_event)


func _on_event(ev: Dictionary) -> void:
	if ev.get("type") == RulesEvent.UNIT_ARRIVED:
		_director.locator.set_unit(int(ev["uid"]), ev["side"], ev["zone"], int(ev["index"]))
	elif ev.get("type") == RulesEvent.STREAK_CHANGED and ev.get("side") == &"player":
		_streak_value.text = str(int(ev.get("streak", 0)))


func _loop() -> void:
	while is_inside_tree():
		_reset()
		await _director.play(_events.duplicate(true))
		await get_tree().create_timer(LOOP_PAUSE).timeout


func _play_checkpoint(cp: String, hold: float) -> void:
	_reset()
	var start: int = _checkpoints[cp]
	if start > 0:
		var before: Array = _events.slice(0, start)
		_director.play(before)
		_director.skip()
		await get_tree().process_frame
	_director.play(_events.slice(start))
	await get_tree().create_timer(hold).timeout
	get_tree().paused = true
	print("FxPreview: paused at %s + %.2f s" % [cp, hold])


func _reset() -> void:
	_director.streak_arc.configure(5, [2, 3, 5], 1)
	_streak_value.text = "1"
	_director.killfeed.clear()


func _read_args() -> Dictionary:
	var out: Dictionary = {}
	var raw: String = ""
	if OS.has_feature("web"):
		raw = String(JavaScriptBridge.eval("window.location.hash || ''", true)).trim_prefix("#")
	else:
		raw = "&".join(OS.get_cmdline_user_args()).replace("--", "")
	for part: String in raw.split("&", false):
		var kv: PackedStringArray = part.split("=")
		if kv.size() == 2:
			out[kv[0]] = kv[1]
	return out


func _ev(type: StringName, fields: Dictionary) -> Dictionary:
	return RulesEvent.make(type, 3, fields)


func _mark(cp: String, list: Array) -> void:
	_checkpoints[cp] = list.size()


## A Round 3 Reveal + Firefight + Score on the mock board, then a Round 4 Operator trade.
func _script_events() -> Array:
	var e: Array = []
	_mark("mid_firefight", e)
	e.append(_ev(RulesEvent.FIREFIGHT_STARTED, {"zone": &"mid"}))
	e.append(_ev(RulesEvent.FIREFIGHT_STEP, {"zone": &"mid", "step": &"main"}))
	e.append(_ev(RulesEvent.SHOT_FIRED, {"side": &"player", "shooter_uid": 10, "target_uid": 22, "zone": &"mid", "damage": 3, "step": &"main"}))
	e.append(_ev(RulesEvent.SHOT_FIRED, {"side": &"enemy", "shooter_uid": 22, "target_uid": 10, "zone": &"mid", "damage": 2, "step": &"main"}))
	e.append(_ev(RulesEvent.DAMAGE_DEALT, {"target_uid": 22, "side": &"enemy", "amount": 3, "remaining": 0, "source_id": &"kestrel_ar7"}))
	e.append(_ev(RulesEvent.DAMAGE_DEALT, {"target_uid": 10, "side": &"player", "amount": 2, "remaining": 3, "source_id": &"marksman"}))
	e.append(_ev(RulesEvent.UNIT_ELIMINATED, {"victim_uid": 22, "victim_side": &"enemy", "victim_id": &"marksman", "is_operator": false,
			"by_uid": 10, "by_side": &"player", "by_id": &"kestrel_ar7", "zone": &"mid", "source_kind": &"operator", "by_killstreak": false, "credit": true}))
	_mark("left_trade", e)
	e.append(_ev(RulesEvent.FIREFIGHT_STARTED, {"zone": &"left"}))
	e.append(_ev(RulesEvent.FIREFIGHT_STEP, {"zone": &"left", "step": &"first_shot"}))
	e.append(_ev(RulesEvent.SHOT_FIRED, {"side": &"player", "shooter_uid": 1, "target_uid": 21, "zone": &"left", "damage": 3, "step": &"first_shot"}))
	e.append(_ev(RulesEvent.SHOT_FIRED, {"side": &"enemy", "shooter_uid": 21, "target_uid": 1, "zone": &"left", "damage": 5, "step": &"first_shot"}))
	e.append(_ev(RulesEvent.DAMAGE_DEALT, {"target_uid": 21, "side": &"enemy", "amount": 3, "remaining": 1, "source_id": &"point_man"}))
	e.append(_ev(RulesEvent.DAMAGE_DEALT, {"target_uid": 1, "side": &"player", "amount": 5, "remaining": 0, "source_id": &"breacher"}))
	e.append(_ev(RulesEvent.UNIT_ELIMINATED, {"victim_uid": 1, "victim_side": &"player", "victim_id": &"point_man", "is_operator": false,
			"by_uid": 21, "by_side": &"enemy", "by_id": &"breacher", "zone": &"left", "source_kind": &"unit", "by_killstreak": false, "credit": true}))
	_mark("takeover", e)
	# kc-ks-seq: revealed and queued at Reveal (INCOMING on column C), then Firefight step 0.
	e.append(_ev(RulesEvent.ITEM_REVEALED, {"side": &"player", "item_id": &"mortar_barrage", "zone": &"right"}))
	e.append(_ev(RulesEvent.KILLSTREAK_QUEUED, {"side": &"player", "item_id": &"mortar_barrage", "zone": &"right",
			"zones": [&"right"], "fights": 1, "resolves": &"firefight"}))
	e.append(_ev(RulesEvent.KILLSTREAK_STRIKE, {"side": &"player", "item_id": &"mortar_barrage", "zone": &"right",
			"zones": [&"right"], "pass": 1, "passes": 1}))
	e.append(_ev(RulesEvent.DAMAGE_DEALT, {"target_uid": 23, "side": &"enemy", "amount": 3, "remaining": 0, "source_id": &"mortar_barrage"}))
	e.append(_ev(RulesEvent.DAMAGE_DEALT, {"target_uid": 24, "side": &"enemy", "amount": 3, "remaining": 3, "source_id": &"mortar_barrage"}))
	e.append(_ev(RulesEvent.UNIT_ELIMINATED, {"victim_uid": 23, "victim_side": &"enemy", "victim_id": &"rifleman", "is_operator": false,
			"by_uid": -1, "by_side": &"player", "by_id": &"mortar_barrage", "zone": &"right", "source_kind": &"killstreak", "by_killstreak": true, "credit": true}))
	e.append(_ev(RulesEvent.KILLSTREAK_RESOLVED, {"side": &"player", "item_id": &"mortar_barrage", "zone": &"right",
			"zones": [&"right"], "pass": 1, "passes": 1, "kills": [23],
			"hits": [{"uid": 23, "side": &"enemy", "amount": 3, "remaining": 0, "name": "Rifleman"},
				{"uid": 24, "side": &"enemy", "amount": 3, "remaining": 3, "name": "Gunner"}]}))
	_mark("streak", e)
	e.append(_ev(RulesEvent.ZONE_CONTROL, {"zone": &"mid", "owner": &"player"}))
	e.append(_ev(RulesEvent.MODE_SCORED, {"mode": &"zone_control", "player_gained": 2, "enemy_gained": 1, "player_score": 3, "enemy_score": 2, "target": 6}))
	e.append(_ev(RulesEvent.STREAK_CHANGED, {"side": &"player", "streak": 2, "before": 1, "gained": 1, "reset": false, "earned": [&"recon_drone"]}))
	e.append(_ev(RulesEvent.KILLSTREAK_EARNED, {"side": &"player", "item_id": &"recon_drone", "streak": 2, "threshold": 2}))
	_mark("shatter", e)
	e.append(RulesEvent.make(RulesEvent.UNIT_ARRIVED, 4, {"side": &"enemy", "uid": 26, "card_id": &"rifleman", "zone": &"mid", "index": 0}))
	e.append(RulesEvent.make(RulesEvent.FIREFIGHT_STARTED, 4, {"zone": &"mid"}))
	e.append(RulesEvent.make(RulesEvent.SHOT_FIRED, 4, {"side": &"enemy", "shooter_uid": 26, "target_uid": 10, "zone": &"mid", "damage": 5, "step": &"main"}))
	e.append(RulesEvent.make(RulesEvent.SHOT_FIRED, 4, {"side": &"player", "shooter_uid": 10, "target_uid": 26, "zone": &"mid", "damage": 3, "step": &"main"}))
	e.append(RulesEvent.make(RulesEvent.DAMAGE_DEALT, 4, {"target_uid": 10, "side": &"player", "amount": 5, "remaining": 0, "source_id": &"rifleman"}))
	e.append(RulesEvent.make(RulesEvent.DAMAGE_DEALT, 4, {"target_uid": 26, "side": &"enemy", "amount": 3, "remaining": 0, "source_id": &"kestrel_ar7"}))
	e.append(RulesEvent.make(RulesEvent.UNIT_ELIMINATED, 4, {"victim_uid": 10, "victim_side": &"player", "victim_id": &"kestrel_ar7", "is_operator": true,
			"by_uid": 26, "by_side": &"enemy", "by_id": &"rifleman", "zone": &"mid", "source_kind": &"unit", "by_killstreak": false, "credit": true}))
	e.append(RulesEvent.make(RulesEvent.OPERATOR_DOWN, 4, {"side": &"player", "uid": 10}))
	e.append(RulesEvent.make(RulesEvent.UNIT_ELIMINATED, 4, {"victim_uid": 26, "victim_side": &"enemy", "victim_id": &"rifleman", "is_operator": false,
			"by_uid": 10, "by_side": &"player", "by_id": &"kestrel_ar7", "zone": &"mid", "source_kind": &"operator", "by_killstreak": false, "credit": true}))
	e.append(RulesEvent.make(RulesEvent.STREAK_CHANGED, 4, {"side": &"player", "streak": 0, "before": 2, "gained": 1, "reset": true, "earned": [&"mortar_barrage"]}))
	return e

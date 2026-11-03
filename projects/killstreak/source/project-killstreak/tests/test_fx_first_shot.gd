# test_fx_first_shot.gd
# Purpose: b01 "First Shot unit still gets shot": the combat playback must make clear WHO hit the
#   First Shot unit and WHEN. Checks, on real engine events from scripted boards:
#   - the First Shot / Main steps are labelled at the zone,
#   - an eliminated unit's slot is veiled for the rest of the sequence, and the Main-step tracer
#     that hits the First Shot unit starts at the NEXT enemy unit's slot, not the dead one,
#   - an enemy unit that also has First Shot is tagged "FIRST SHOT" when it fires,
#   - the killfeed names the real shooter,
#   - veils are gone when the sequence ends.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const DirectorScene: PackedScene = preload("res://scenes/fx/FeedbackDirector.tscn")
const KillfeedScene: PackedScene = preload("res://scenes/fx/Killfeed.tscn")
const P: int = 0
const E: int = 1

var _root: Control
var _director: Control
var _nodes: Array[Dictionary] = []


## Slot rects by line position: player row y=460, enemy row y=160, 90 px per slot.
class LineLocator:
	extends RefCounted
	var rects: Dictionary = {}

	func sync(m: MatchState) -> void:
		for si: int in 2:
			for z: int in 3:
				var line: Array = m.sides[si].line(z)
				for i: int in line.size():
					rects[(line[i] as RulesUnit).uid] = Rect2(100 + z * 400 + i * 90, 460 if si == 0 else 160, 80, 80)

	func unit_rect(uid: int) -> Rect2:
		return rects.get(uid, Rect2())

	func zone_rect(zone: StringName) -> Rect2:
		var z: int = MapData.ZONE_IDS.find(zone)
		return Rect2(z * 400, 100, 400, 500)

	func anchor_rect(_name: StringName) -> Rect2:
		return Rect2(20, 10, 300, 60)


func _setup(m: MatchState) -> void:
	_root = Control.new()
	_root.size = Vector2(1280, 720)
	tree.root.add_child(_root)
	_director = DirectorScene.instantiate()
	_director.use_settings = false
	_director.fast = true
	_director.reduced_motion = true
	_root.add_child(_director)
	var feed: Control = KillfeedScene.instantiate()
	_root.add_child(feed)
	feed.set_anchors_preset(Control.PRESET_TOP_LEFT)
	feed.size = Vector2(400, 72)
	_director.killfeed = feed
	var loc: LineLocator = LineLocator.new()
	loc.sync(m)  # pre-resolve board, like the match screen
	_director.locator = loc
	var names: Dictionary = {}
	for s: RulesSide in m.sides:
		for u: RulesUnit in s.units_on_board():
			names[u.uid] = "%s#%d" % [u.card.display_name, u.uid]
	_director.unit_names = names
	_nodes.clear()
	_director.fx_started.connect(func(kind: StringName, node: Object, _d: float) -> void:
		_nodes.append({"kind": kind,
				"from": node.from if node != null and "from" in node else Vector2.ZERO,
				"text": String(node.label.text) if node != null and "label" in node and node.label != null else ""}))


func _teardown() -> void:
	if _director != null and _director.is_playing():
		_director.skip()
	_root.queue_free()
	await tree.process_frame


func _texts(kind: StringName) -> Array[String]:
	var out: Array[String] = []
	for n: Dictionary in _nodes:
		if n["kind"] == kind:
			out.append(n["text"])
	return out


func test_next_unit_return_fire_comes_from_its_own_slot_and_dead_unit_is_veiled() -> void:
	var m: MatchState = F.new_match(null, null, F.map())
	var b: RulesUnit = F.place(m, P, F.breacher(), F.LEFT)
	var front: RulesUnit = F.place(m, E, F.rifleman(), F.LEFT)
	var back: RulesUnit = F.place(m, E, F.unit("back", 2, 6), F.LEFT)
	_setup(m)
	var start: int = m.events.size()
	m.firefight()
	var veiled_mid_sequence: Array = [false]
	_director.event_started.connect(func(ev: Dictionary) -> void:
		if ev["type"] == RulesEvent.SHOT_FIRED and ev["step"] == &"main":
			veiled_mid_sequence[0] = _director.veiled_uids().has(front.uid))
	await _director.play(m.events_since(start))
	assert_eq(_texts(&"step"), ["FIRST SHOT", "MAIN"] as Array[String], "both steps labelled, in order")
	assert_true(veiled_mid_sequence[0], "the dead point man is veiled before the Main step fires")
	# The Main-step tracer onto the Breacher starts at the back unit's slot.
	var loc: LineLocator = _director.locator
	var tracers: Array = _nodes.filter(func(n: Dictionary) -> bool: return n["kind"] == &"tracer")
	assert_eq(tracers.size(), 2, "two shots: Breacher (First Shot), back unit (Main)")
	var from: Vector2 = tracers[1]["from"]
	assert_true(loc.unit_rect(back.uid).grow(30.0).has_point(from), "Main tracer starts at the back unit")
	assert_false(loc.unit_rect(front.uid).has_point(from), "not inside the dead point man's slot")
	assert_eq(_texts(&"tag").filter(func(t: String) -> bool: return t == "FIRST SHOT").size(), 0,
			"no enemy First Shot tag: the enemy had no First Shot unit")
	assert_true(_director.veiled_uids().is_empty(), "veils cleared at the end of the sequence")
	assert_eq(b.armor, 2, "engine: hit by the back unit only")
	await _teardown()


func test_enemy_first_shot_unit_is_tagged_and_named_in_killfeed() -> void:
	var m: MatchState = F.new_match(null, null, F.map())
	var b: RulesUnit = F.place(m, P, F.unit("breacher", 3, 2, F.W.SHOTGUN, {"first_shot": true}), F.LEFT)
	var epm: RulesUnit = F.place(m, E, F.point_man(), F.LEFT)  # First Shot, 3 at Close
	_setup(m)
	var start: int = m.events.size()
	m.firefight()
	await _director.play(m.events_since(start))
	assert_eq(_texts(&"step"), ["FIRST SHOT"] as Array[String], "only the First Shot step happens")
	assert_eq(_texts(&"tag").filter(func(t: String) -> bool: return t == "FIRST SHOT").size(), 1,
			"the enemy Point Man is tagged FIRST SHOT: it fired at the same time")
	var feed: Control = _director.killfeed
	var attackers: Array[String] = []
	for line: Control in feed.get_entries():
		attackers.append(String(line.entry["attacker"]))
	assert_true(attackers.has("Point Man#%d" % epm.uid), "killfeed names the enemy Point Man as the Breacher's killer")
	assert_false(b.is_alive(), "engine: simultaneous trade")
	await _teardown()


func test_no_shot_after_its_shooters_elimination_in_event_log() -> void:
	# Event-log invariant the playback relies on: once UNIT_ELIMINATED is logged for a uid,
	# no later SHOT_FIRED has that uid as shooter (in this firefight).
	var m: MatchState = F.new_match(null, null, F.map())
	F.place(m, P, F.breacher(), F.LEFT)
	F.place(m, P, F.point_man(), F.LEFT)
	F.place(m, P, F.rifleman(), F.LEFT)
	F.place(m, E, F.rifleman(), F.LEFT)
	F.place(m, E, F.point_man(), F.LEFT)
	F.place(m, E, F.gunner(), F.LEFT)
	F.place(m, E, F.unit("tough", 3, 7), F.LEFT)
	var start: int = m.events.size()
	m.firefight()
	var dead: Dictionary = {}
	var ok: bool = true
	for e: Dictionary in m.events_since(start):
		if e["type"] == RulesEvent.UNIT_ELIMINATED:
			dead[int(e["victim_uid"])] = true
		elif e["type"] == RulesEvent.SHOT_FIRED and dead.has(int(e["shooter_uid"])):
			ok = false
	assert_true(ok, "no eliminated unit fires afterwards")
	assert_false(dead.is_empty(), "the scenario had eliminations")

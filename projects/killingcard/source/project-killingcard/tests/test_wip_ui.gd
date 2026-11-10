# test_wip_ui.gd
# Purpose: kc-wip-impl, the Wip mechanics on the match screen: tapping your Agile unit selects its free
#   move and a tap on an adjacent column queues it (pending in the destination, UNDO names it);
#   Premium Loadout plays as soon as you pick your unit (no column step); the log says what a Beam hit
#   (friends marked), where an Agile unit went, the Hacker's Supply and the +1/+1 buffs.
# Author: Mechanics Developer Agent (kc-wip-impl)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const MatchSnapshot: GDScript = preload("res://scripts/ui/match_snapshot.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"

var _saved_root_size: Vector2i = Vector2i.ZERO


func test_agile_tap_select_and_move() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var c: Node = s[2]
	var st: MatchState = c.state
	var me: RulesSide = st.sides[0]
	var runner: RulesUnit = st.create_unit(0, CardDB.get_card(&"kc_wip_runner"))
	st.put_in_line(runner, 0)
	c.refresh()
	await _frames(2)
	c._on_lane_tapped(0, &"player", runner.uid)
	assert_eq(c.selection.get("kind"), &"agile", "a tap on my Agile unit selects its move")
	assert_eq(c.check_play(2)["ok"], false, "C is not adjacent to A")
	assert_eq(c.check_play(1)["badge"], "MOVE HERE", "B: MOVE HERE")
	var res: Dictionary = c.play_at(1)
	assert_true(res["ok"], "move queued: %s" % res.get("reason", ""))
	assert_true(c.selection.is_empty(), "selection cleared")
	var agile: Array = me.plays.filter(func(p: Dictionary) -> bool: return p["kind"] == &"agile")
	assert_eq(agile.size(), 1, "one Agile order")
	assert_eq(MatchSnapshot.play_name(st, me, agile[0]), "Move Runner", "UNDO names it")
	var snap: Dictionary = MatchSnapshot.build(st, null)
	var pending: Array = (snap["lanes"][1]["friendly"] as Array).filter(func(e: Dictionary) -> bool: return bool(e.get("pending", false)))
	assert_eq(pending.map(func(e: Dictionary) -> int: return int(e["uid"])), [runner.uid], "pending in B")
	c._on_lane_tapped(0, &"player", runner.uid)
	assert_true(c.selection.is_empty(), "a second tap this round does not select it again (already moved)")
	_despawn(s[0])


func test_premium_loadout_plays_on_the_unit_pick() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var c: Node = s[2]
	var st: MatchState = c.state
	var me: RulesSide = st.sides[0]
	var u: RulesUnit = st.create_unit(0, CardDB.get_card(&"rifleman"))
	st.put_in_line(u, 2)
	var rc: RulesCard = RulesCard.new(st.new_uid(), CardDB.get_card(&"kc_wip_premium_loadout"))
	me.hand.append(rc)
	me.supply = 9
	c.refresh()
	await _frames(2)
	c.select_card(rc.uid)
	c._pick_or_play(2, &"player", u.uid)
	var tac: Array = me.plays.filter(func(p: Dictionary) -> bool: return p["kind"] == &"tactic")
	assert_eq(tac.size(), 1, "played on the pick, no column step")
	if not tac.is_empty():
		assert_eq(int(tac[0]["target_uid"]), u.uid, "on my Rifleman")
	_despawn(s[0])


func test_log_lines_for_the_wip_effects() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var c: Node = s[2]
	var st: MatchState = c.state
	var laser: RulesUnit = st.create_unit(0, CardDB.get_card(&"kc_wip_laser_gunner"))
	st.put_in_line(laser, 1)
	var friend: RulesUnit = st.create_unit(0, CardDB.get_card(&"rifleman"))
	st.put_in_line(friend, 1)
	var foe: RulesUnit = st.create_unit(1, CardDB.get_card(&"rifleman"))
	st.put_in_line(foe, 1)
	c._add_v2_line(RulesEvent.make(RulesEvent.BEAM_FIRED, 1, {"side": &"player", "shooter_uid": laser.uid, "zone": &"mid", "beat": 2,
			"hits": [{"uid": friend.uid, "side": &"player", "damage": 2, "friendly": true}, {"uid": foe.uid, "side": &"enemy", "damage": 2, "friendly": false}]}))
	assert_eq(String(c.killfeed[0]["text"]), "LASER GUNNER BEAM: 2 TO YOUR RIFLEMAN, 2 TO RIFLEMAN", "beam line marks the friend")
	c._add_v2_line(RulesEvent.make(RulesEvent.AGILE_MOVED, 1, {"side": &"player", "uid": friend.uid, "card_id": &"rifleman",
			"from_zone": &"mid", "zone": &"right", "moved": true}))
	assert_eq(String(c.killfeed[0]["text"]), "RIFLEMAN MOVES B > C (AGILE)", "Agile move line")
	c._add_v2_line(RulesEvent.make(RulesEvent.EFFECT_APPLIED, 1, {"side": &"player", "source_id": &"kc_wip_hacker",
			"kind": "GAIN_SUPPLY_NEXT_ROUND", "target_uid": -1, "amount": 1}))
	assert_eq(String(c.killfeed[0]["text"]), "HACKER: +1 SUPPLY NEXT ROUND", "Hacker line")
	c._add_v2_line(RulesEvent.make(RulesEvent.EFFECT_APPLIED, 1, {"side": &"player", "source_id": &"kc_wip_flag_bearer",
			"kind": "MODIFY_ARMOR", "target_uid": friend.uid, "amount": 1}))
	assert_eq(String(c.killfeed[0]["text"]), "FLAG BEARER: +1/+1 TO RIFLEMAN", "Flag Bearer line")
	var fl: RulesUnit = st.create_unit(0, CardDB.get_card(&"kc_wip_fast_learner"))
	st.put_in_line(fl, 2)
	c._add_v2_line(RulesEvent.make(RulesEvent.EFFECT_APPLIED, 1, {"side": &"player", "source_id": &"kc_wip_fast_learner",
			"kind": "MODIFY_ARMOR", "target_uid": fl.uid, "amount": 1}))
	assert_eq(String(c.killfeed[0]["text"]), "FAST LEARNER GROWS +1/+1", "growth line")
	_despawn(s[0])


func _spawn(screen: Dictionary) -> Array:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(Layout.logical_size(screen))
	vp.disable_3d = true
	vp.handle_input_locally = true
	tree.root.add_child(vp)
	var m: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
	vp.add_child(m)
	await _frames(4)
	var c: Node = m.get_node("%MatchController")
	assert_not_null(c.state, "%s live match started" % screen["name"])
	if c.is_mulligan_open():
		c.keep_hand()
		await _frames(2)
	return [vp, m, c]


func _despawn(vp: SubViewport) -> void:
	vp.queue_free()
	tree.root.size = _saved_root_size


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame

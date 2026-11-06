# test_fight_ui.gd
# Purpose: kc-fight-ui, the step-by-step firefight playback (firefight-order.md §8 / §10.2):
#   - the director lands every event in the stream's order, paces each beat to fight_beat, plays the
#     Pierce carry as a second tracer with a smaller "-n PIERCE" number, names the column and sums
#     it up; the overlay outlines the shooters and pips the units that fired, and clears at the end;
#   - on the match screen the playback board (fight_playback.gd) removes the dead when they land and
#     slides the line up only at LINE_ADVANCED, after the eliminations; the order strip lights A, B,
#     C and greys columns with no fight; links / the trait rail follow the playback board;
#   - a skip lands exactly on the final board of the live state;
#   - speed: x1 for the first runs, x2 after the tutorial, a chosen speed wins (Settings.speed_chosen);
#   - the phone strip folds RIVAL into SCORE and gives the trait rail a full badge slot;
#   - hand cards that would switch a set on glow at the start of Deploy;
#   - Pierce has a glossary entry and a drawn glyph; First Shot's line is the exchange rule.
#   Runs with or without the git-ignored licensed art folder.
# Author: UI/UX Agent (kc-fight-ui)
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const DirectorScene: PackedScene = preload("res://scenes/fx/FeedbackDirector.tscn")
const MatchSnapshot: GDScript = preload("res://scripts/ui/match_snapshot.gd")
const MatchScreen: GDScript = preload("res://scripts/ui/match_screen.gd")
const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")
const Glossary: GDScript = preload("res://scripts/ui/codex/glossary.gd")
const FightPlayback: GDScript = preload("res://scripts/ui/fight_playback.gd")
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"
const P: int = 0
const E: int = 1

var _saved_root_size: Vector2i = Vector2i.ZERO


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


# =============================================================================
# Director: order, pacing, Pierce, overlay
# =============================================================================

func test_director_lands_events_in_order_paces_beats_and_shows_pierce() -> void:
	var m: MatchState = F.new_match(null, null, F.map())
	var lmg: RulesUnit = F.place(m, P, F.unit("lmg", 4, 4, F.W.LMG, {"pierce": true}), F.LEFT)
	var front: RulesUnit = F.place(m, E, F.unit("front", 1, 1), F.LEFT)
	var back: RulesUnit = F.place(m, E, F.unit("back", 1, 5), F.LEFT)
	var root: Control = Control.new()
	root.size = Vector2(1280, 720)
	tree.root.add_child(root)
	var d: Control = DirectorScene.instantiate()
	d.use_settings = false
	d.fast = true
	d.reduced_motion = false
	root.add_child(d)
	var loc: LineLocator = LineLocator.new()
	loc.sync(m)
	d.locator = loc
	d.unit_sides = {lmg.uid: &"player", front.uid: &"enemy", back.uid: &"enemy"}
	d.unit_names = {lmg.uid: "Gunner", front.uid: "Rifleman", back.uid: "Point Man"}
	var caps: Array[String] = []
	d.caption_changed.connect(func(lines: Array) -> void:
		for l: Variant in lines:
			if not caps.has(String(l)):
				caps.append(String(l)))
	var start: int = m.events.size()
	m.firefight()
	var events: Array[Dictionary] = m.events_since(start)
	var landed: Array = []
	var beat_ms: Array[int] = []
	var outlined: Array = []
	var pips_mid: Array = [0]
	var texts: Array[String] = []
	d.event_landed.connect(func(ev: Dictionary) -> void:
		landed.append(ev)
		if ev["type"] == RulesEvent.FIREFIGHT_BEAT or ev["type"] == RulesEvent.FIREFIGHT_COLUMN_ENDED:
			beat_ms.append(Time.get_ticks_msec())
		if ev["type"] == RulesEvent.LINE_ADVANCED:
			pips_mid[0] = d.overlay.fired.size())
	d.fx_started.connect(func(kind: StringName, node: Object, _dur: float) -> void:
		if node != null and "label" in node and node.label != null:
			texts.append("%s:%s" % [kind, String(node.label.text)])
		if kind == &"tracer":
			outlined.append(d.overlay.shooters.keys()))
	await d.play(events)
	# Every event lands, in the stream's order.
	assert_eq(landed.size(), events.size(), "every event landed")
	var same: bool = landed.size() == events.size()
	for i: int in mini(landed.size(), events.size()):
		same = same and landed[i] == events[i]
	assert_true(same, "landed in the stream's order")
	# Eliminations land before the line advance of their beat.
	var types: Array = landed.map(func(e: Dictionary) -> StringName: return e["type"])
	assert_true(types.has(RulesEvent.PIERCE_CARRIED), "the scenario has a Pierce carry")
	assert_true(types.find(RulesEvent.UNIT_ELIMINATED) < types.find(RulesEvent.LINE_ADVANCED), "elimination before the line advance")
	# Pacing: each beat lasts at least fight_beat (x0.5 here: fast animations).
	var min_ms: float = FxTimingScript().BASE[&"fight_beat"] * 0.5 * 1000.0 - 40.0
	for i: int in range(1, beat_ms.size()):
		assert_true(beat_ms[i] - beat_ms[i - 1] >= min_ms, "beat %d lasted %d ms (>= %.0f)" % [i, beat_ms[i] - beat_ms[i - 1], min_ms])
	# Pierce: a second, thinner tracer and a smaller, named number on the unit behind.
	assert_true(d.logged_kinds().has(&"pierce_tracer"), "Pierce tracer (%s)" % [d.logged_kinds()])
	assert_true(texts.has("damage_number:-3 PIERCE"), "-3 PIERCE on the back unit (%s)" % [texts])
	assert_true(texts.has("column:COLUMN A"), "column banner")
	assert_true(texts.any(func(t: String) -> bool: return t.begins_with("summary:COLUMN A: 1 KILL")), "column summary (%s)" % [texts])
	# Now firing outline while the tracers leave; fired pips after the shots.
	assert_true(outlined.size() >= 1 and (outlined[0] as Array).has(lmg.uid), "the shooter is outlined while it fires (%s)" % [outlined])
	assert_eq(pips_mid[0], 2, "both first-beat shooters carry a fired pip")
	assert_false(d.overlay.is_active(), "overlay cleared when the sequence ends")
	# One plain line per shot (head): who, where, whom, how much, what happened.
	assert_true(caps.has("Gunner (A) hits Rival Rifleman for 4 — destroyed; Pierce 3 into Rival Point Man"),
			"shot caption with the kill and the Pierce carry (%s)" % [caps])
	assert_true(caps.any(func(c: String) -> bool: return c.begins_with("Rival Rifleman (A) hits Gunner for")), "the rival's shot too (%s)" % [caps])
	assert_true(caps.has("Column A fights: front to back, one shot each."), "column caption")
	assert_true(d.captions.is_empty(), "caption cleared at the end")
	assert_true(not back.is_alive() or back.armor <= 2, "engine: the back unit took the carry (armor %d)" % back.armor)
	root.queue_free()
	await tree.process_frame


func FxTimingScript() -> GDScript:
	return load("res://scripts/fx/fx_timing.gd") as GDScript


func test_playback_board_applies_events_in_order() -> void:
	var m: MatchState = F.new_match(null, null, F.map())
	F.place(m, P, F.unit("lmg", 4, 4, F.W.LMG, {"pierce": true}), F.LEFT)
	var front: RulesUnit = F.place(m, E, F.unit("front", 1, 1), F.LEFT)
	var back: RulesUnit = F.place(m, E, F.unit("back", 1, 5), F.LEFT)
	var pb: RefCounted = FightPlayback.start(m, F.map(), P)
	var start: int = m.events.size()
	m.firefight()
	var refresh_at: Array[StringName] = []
	for ev: Dictionary in m.events_since(start):
		var before: Array[int] = pb.line_uids(E, 0)
		if pb.apply(ev):
			refresh_at.append(ev["type"])
		if ev["type"] == RulesEvent.UNIT_ELIMINATED:
			assert_false(pb.line_uids(E, 0).has(front.uid), "the dead leave the playback line when they land")
		if ev["type"] == RulesEvent.LINE_ADVANCED:
			for mv: Dictionary in ev["moves"]:
				assert_eq(pb.line_uids(E, 0).find(int(mv["uid"])), int(mv["to_row"]), "the moved unit is at its new row")
			assert_eq(before, pb.line_uids(E, 0), "the line was already closed up by the elimination")
	assert_true(refresh_at.has(RulesEvent.LINE_ADVANCED), "the board redraws at the line advance (%s)" % [refresh_at])
	assert_false(refresh_at.has(RulesEvent.UNIT_ELIMINATED), "not at the elimination itself (the stamp is read first)")
	assert_eq(pb.applied.size(), m.events_since(start).size(), "every event applied")
	var live: Array[int] = []
	for u: RulesUnit in m.sides[E].line(0):
		live.append(u.uid)
	assert_eq(pb.line_uids(E, 0), live, "the playback board ends where the live board ends")
	# The live state is untouched by the playback.
	assert_true(m.sides[E].find_unit(front.uid) == null, "live: front down")


# =============================================================================
# Match screen
# =============================================================================

## Column A: three of yours (an LMG with Pierce among them) against three weak rivals, so the first
## beat kills the rival front and its line moves up.
func _stage_fight(c: Node) -> void:
	var st: MatchState = c.state
	for s: RulesSide in st.sides:
		for z: int in 3:
			s.line(z).clear()
		s.plays.clear()
	st.sides[E].ready = false
	for id: StringName in [&"breacher", &"gunner", &"rifleman"]:
		var u: RulesUnit = st.create_unit(P, CardDB.get_card(id), -1, SynergyRules.LEVEL_TRAINED)
		st.put_in_line(u, 0)
	for id: StringName in [&"rifleman", &"rifleman", &"rifleman"]:
		var e: RulesUnit = st.create_unit(E, CardDB.get_card(id), -1, SynergyRules.LEVEL_RECRUIT)
		st.put_in_line(e, 0)
	# Column C: one each, so two columns fight and B is skipped.
	st.put_in_line(st.create_unit(P, CardDB.get_card(&"rifleman"), -1, SynergyRules.LEVEL_RECRUIT), 2)
	st.put_in_line(st.create_unit(E, CardDB.get_card(&"rifleman"), -1, SynergyRules.LEVEL_RECRUIT), 2)
	c.refresh()


func test_match_screen_plays_beats_and_slides_after_eliminations() -> void:
	var was_fast: bool = Settings.fast_animations
	Settings.fast_animations = true
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	_stage_fight(c)
	await _frames(3)
	var fx: Control = m.get_fx()
	var log: Array[String] = []
	var ok: Dictionary = {"victim_on_board_at_elim": true, "moved_after_advance": true, "strip_mid": "", "lifted": false}
	c.press_ready()
	# Connected after the controller's own handler: the board is already refreshed when this runs.
	fx.event_landed.connect(_check_land.bind(m, fx, ok, log))
	await c.round_presented
	assert_true(log.has(String(RulesEvent.LINE_ADVANCED)), "the round had a line advance (%s)" % [log])
	assert_true(ok["victim_on_board_at_elim"], "an eliminated unit is still on the board (veiled) when it lands")
	assert_true(ok["moved_after_advance"], "after LINE_ADVANCED the moved units are in their new rows")
	assert_true(c.fight_refreshes >= 1, "the board was redrawn during the firefight (%d)" % c.fight_refreshes)
	assert_true(String(ok["strip_mid"]).contains("B-"), "column B greyed and skipped (%s)" % ok["strip_mid"])
	assert_true(String(ok["strip_mid"]).contains("*"), "a column is lit while it plays (%s)" % ok["strip_mid"])
	assert_eq(m.get_order_strip().describe(), "A+>B->C+", "all fought columns ticked at the end")
	assert_true(ok["lifted"], "the shooters lift while they fire")
	assert_true(fx.lifted_uids().is_empty(), "nothing left lifted")
	# Back in Deploy: the board is the live state's.
	_assert_board_is_live(m, c, "after the round")
	_despawn(vp)
	Settings.fast_animations = was_fast
	await tree.process_frame


func _check_land(ev: Dictionary, m: Control, fx: Control, ok: Dictionary, log: Array[String]) -> void:
	log.append(String(ev["type"]))
	match ev["type"]:
		RulesEvent.UNIT_ELIMINATED:
			if fx.locator.find_slot(int(ev["victim_uid"])) == null:
				ok["victim_on_board_at_elim"] = false
		RulesEvent.LINE_ADVANCED:
			var lane: Node = m.get_board().get_lane(StringName(ev["zone"]))
			var slots: Array = lane.get_enemy_slots() if StringName(ev["side"]) == &"enemy" else lane.get_friendly_slots()
			for mv: Dictionary in ev["moves"]:
				if int(slots[int(mv["to_row"])].slot_uid) != int(mv["uid"]):
					ok["moved_after_advance"] = false
		RulesEvent.FIREFIGHT_BEAT:
			ok["strip_mid"] = m.get_order_strip().describe()
		RulesEvent.SHOT_FIRED:
			ok["lifted"] = ok["lifted"] or not fx.lifted_uids().is_empty()


func test_skip_lands_on_the_final_state() -> void:
	var s: Array = await _spawn(Layout.DESKTOP)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	_stage_fight(c)
	await _frames(3)
	var fx: Control = m.get_fx()
	var beats: Array = [0]
	var refreshes_at_skip: Array = [-1]
	c.press_ready()
	fx.event_landed.connect(func(ev: Dictionary) -> void:
		if ev["type"] == RulesEvent.FIREFIGHT_BEAT:
			beats[0] += 1
			if beats[0] == 1:
				refreshes_at_skip[0] = c.fight_refreshes
				c.skip_feedback.call_deferred())
	var t0: int = Time.get_ticks_msec()
	await c.round_presented
	var took: int = Time.get_ticks_msec() - t0
	assert_true(beats[0] >= 1, "the firefight started before the skip")
	assert_eq(c.fight_refreshes, refreshes_at_skip[0], "no per-beat redraws after the skip")
	assert_true(took < 2500, "the skip finished the round at once (%d ms)" % took)
	assert_false(fx.overlay.is_active(), "no dim, outline or pips after a skip")
	assert_true(fx.lifted_uids().is_empty(), "nothing left lifted")
	_assert_board_is_live(m, c, "after a skip")
	_despawn(vp)
	await tree.process_frame


func _assert_board_is_live(m: Control, c: Node, label: String) -> void:
	var want: Dictionary = MatchSnapshot.build(c.state, c.map, 0)
	for z: int in 3:
		var lane: Node = m.get_board().get_lanes()[z]
		for pair: Array in [[lane.get_friendly_slots(), want["lanes"][z]["friendly"]], [lane.get_enemy_slots(), want["lanes"][z]["enemy"]]]:
			var shown: Array[int] = []
			for slot: Node in pair[0]:
				if int(slot.slot_uid) >= 0:
					shown.append(int(slot.slot_uid))
			var exp: Array[int] = []
			for e: Dictionary in pair[1]:
				if int(e.get("uid", -1)) >= 0 and not bool(e.get("pending", false)):
					exp.append(int(e["uid"]))
			shown.sort()
			exp.sort()
			assert_eq(shown, exp, "%s column %d shows the live line" % [label, z])


func test_reveal_turns_rival_cards_over_one_at_a_time() -> void:
	var after: Dictionary = {"lanes": [
		{"id": &"left", "enemy": [{"uid": 1}, {"uid": 2}, {"uid": 3}], "friendly": [{"uid": 9}], "incoming": 0, "revealed": []},
		{"id": &"mid", "enemy": [{"uid": 4}], "friendly": [], "incoming": 0, "revealed": []},
		{"id": &"right", "enemy": [], "friendly": [], "incoming": 0, "revealed": []}]}
	var evs: Array = [
		{"type": RulesEvent.PHASE_CHANGED, "phase": &"reveal"},
		{"type": RulesEvent.UNIT_ARRIVED, "side": &"enemy", "uid": 2, "zone": &"left"},
		{"type": RulesEvent.UNIT_ARRIVED, "side": &"enemy", "uid": 3, "zone": &"left"},
		{"type": RulesEvent.UNIT_ARRIVED, "side": &"enemy", "uid": 4, "zone": &"mid"},
		{"type": RulesEvent.PHASE_CHANGED, "phase": &"firefight"}]
	var MC: GDScript = load("res://scripts/ui/match_controller.gd") as GDScript
	var lanes: Array = MC._reveal_lanes(after, {1: true, 9: true}, {2: true}, evs)
	assert_eq((lanes[0]["enemy"] as Array).map(func(e: Dictionary) -> int: return e["uid"]), [1, 2], "A: the old unit and the first reveal")
	assert_eq(int(lanes[0]["incoming"]), 1, "A: one card still face-down")
	assert_eq((lanes[1]["enemy"] as Array).size(), 0, "B: not revealed yet")
	assert_eq(int(lanes[1]["incoming"]), 1, "B: face-down")
	assert_eq((lanes[0]["friendly"] as Array).size(), 1, "your own units are shown")


func test_speed_defaults_and_choice() -> void:
	assert_eq(FirefightResolver.default_playback_speed(false), 1.0, "x1 for the first runs")
	assert_eq(FirefightResolver.default_playback_speed(true), 2.0, "x2 after the tutorial")
	assert_false(MatchScreen.default_speed_x2(false, false, false), "no choice, tutorial not done: x1")
	assert_eq(MatchScreen.default_speed_x2(false, false, true), MatchScreen.FOLLOW_TUTORIAL_DEFAULT,
			"no choice, tutorial done: x1 while the head wants x1 everywhere")
	assert_false(MatchScreen.default_speed_x2(false, true, true), "chose x1: x1")
	assert_true(MatchScreen.default_speed_x2(true, true, false), "chose x2: x2")
	assert_false(MatchScreen.default_speed_x2(true, false, false), "an older save's SPEED x2 (no pick with the new toggle): x1")
	var was: Array = [Settings.speed_x2, Settings.speed_chosen]
	Settings.speed_x2 = false
	Settings.speed_chosen = false
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	assert_false(m.get_speed_button().button_pressed, "headless (tutorial record not read): x1")
	assert_eq(m.get_speed_button().text, "SPEED x1", "labelled x1")
	m.get_speed_button().button_pressed = true
	assert_true(Settings.speed_x2 and Settings.speed_chosen, "the toggle records the choice")
	m._apply_speed(true)
	assert_eq(Engine.time_scale, 2.0, "x2 while the round plays")
	m._apply_speed(false)
	assert_eq(Engine.time_scale, 1.0, "x1 between rounds")
	_despawn(vp)
	await tree.process_frame
	Settings.speed_x2 = was[0]
	Settings.speed_chosen = was[1]


func test_phone_strip_folds_rival_into_score() -> void:
	for screen: Dictionary in [Layout.PHONE, Layout.DESKTOP]:
		var s: Array = await _spawn(screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var c: Node = s[2]
		var label: String = screen["name"]
		var phone: bool = screen == Layout.PHONE
		var rival: Control = m.get_node("%RivalBadge")
		var score: Control = m.get_badge(&"score")
		var hand_n: int = c.state.sides[E].hand.size()
		assert_eq(rival.visible, not phone, "%s RIVAL badge %s" % [label, "folded" if phone else "kept"])
		if phone:
			assert_true(score.get_text().ends_with(str(hand_n)), "%s SCORE shows the rival hand (%s)" % [label, score.get_text()])
			var rail: Control = m.get_trait_rail()
			var badge_h: float = float(m.metrics["badge_h"])
			# kc-onboard-ui: the slot holds the initiative chip while no trait is in play (a full
			# badge), the trait rail once one is (a full badge slot or more).
			var chip: Control = m.get_initiative_chip()
			var holder: Control = chip if chip.visible else rail
			assert_true(holder.size.y >= badge_h, "%s the %s has a full badge slot (%.0f >= %.0f px)" % [label, holder.name, holder.size.y, badge_h])
			assert_true(m.get_badge(&"preview").position.y < rail.position.y, "%s PREVIEW sits above the rail" % label)
			m.toggle_flyout(&"score")
			await _frames(2)
			assert_true(m.get_node("%Minimap").is_visible_in_tree() and m.get_node("%ScoreBar").is_visible_in_tree(),
					"%s SCORE flyout holds the score and the rival intel" % label)
			m.close_flyout()
			var strip_r: Rect2 = m.get_badge(&"deck").get_parent().get_global_rect().grow(0.6)
			assert_true(strip_r.encloses(rail.get_global_rect()), "%s rail inside the strip" % label)
		else:
			assert_false(score.get_text().contains(" %d" % hand_n) and score.get_text().count(" ") > 1, "%s SCORE keeps two lines" % label)
		_despawn(vp)
		await tree.process_frame


func test_hand_cards_that_switch_a_set_on_glow_at_deploy() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var st: MatchState = c.state
	var pm: RulesUnit = st.create_unit(P, CardDB.get_card(&"point_man"), -1, SynergyRules.LEVEL_TRAINED)
	st.put_in_line(pm, 0)
	var rc: RulesCard = RulesCard.new(st.new_uid(), CardDB.get_card(&"breacher"), SynergyRules.LEVEL_TRAINED)
	st.sides[P].hand.append(rc)
	st.sides[P].supply = 9
	c.refresh()
	await _frames(2)
	var hand: Array = MatchSnapshot.build(st, c.map, 0)["hand"]
	var glow: Array[int] = m.glow_set_cards(hand)
	assert_true(glow.has(rc.uid), "the Trained Breacher (Vanguard 2) glows (%s)" % [glow])
	var glows: int = 0
	for n: Node in m.get_fx().get_children():
		if n.get(&"fx_kind") == &"hand_glow":
			glows += 1
	assert_eq(glows, glow.size(), "one glow per card")
	for e: Dictionary in hand:
		if String(e.get("completes_tier", "")) == "":
			assert_false(glow.has(int(e["uid"])), "a card that switches nothing on does not glow")
	_despawn(vp)
	await tree.process_frame


func test_pierce_glossary_glyph_and_first_shot_line() -> void:
	assert_true(CardInfo.KEYWORD_RULES.has(&"pierce"), "Pierce keyword rule")
	assert_eq(CardInfo.KEYWORD_RULES[&"first_shot"][1], "Fires first in its exchange; a partner it kills doesn't fire back.", "First Shot line")
	var gunner: CardData = CardDB.get_card(&"gunner")
	var ids: Array = CardInfo.keywords(gunner).map(func(k: Dictionary) -> StringName: return k["id"])
	assert_true(ids.has(&"pierce"), "the Gunner lists Pierce (%s)" % [ids])
	assert_true(CardInfo.icon_keywords(CardInfo.keywords(gunner)).any(func(k: Dictionary) -> bool: return k["id"] == &"pierce"),
			"Pierce reaches the banner keyword list")
	var e: Dictionary = {}
	for g: Dictionary in Glossary.entries():
		if g["key"] == &"pierce":
			e = g
	assert_false(e.is_empty(), "glossary entry")
	assert_eq(e.get("drawn", &""), &"pierce", "with the drawn Pierce glyph")
	# The glyph draws (no errors) on a canvas.
	var ci: Control = Control.new()
	ci.size = Vector2(40, 40)
	tree.root.add_child(ci)
	ci.draw.connect(func() -> void: SynergyGlyphs.draw_pierce_plate(ci, Rect2(0, 0, 40, 40), Color.WHITE))
	ci.queue_redraw()
	await tree.process_frame
	ci.queue_free()


# =============================================================================
# Helpers
# =============================================================================

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
	Engine.time_scale = 1.0


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame

# test_feedback_nov17.gd
# Purpose: kc-feedback, the studio head's 17 Nov 2026 notes on KillingCard:
#   1. tips: every callout opened during a scripted match has a real, visible, on-screen target, a ring
#      around it and an arrow from the bubble that ends on it;
#   2. UAV: revealed rival plays show as the real cards (art, cost, FP, Armor, keywords), inspectable;
#   3. first playthrough: START NEW RUN skips the Operator and killstreak screens with the beginner kit,
#      remembers it (Settings, SaveMirror), and shows the screens from the second run on;
#   4. score: the score race over the board (two bars toward the target, numbers at the ends, "+N");
#   6. movement: a move reaches any other column on the match screen too;
#   7. no round recap panel: what happened is on the board, the details are in the LOG.
#   (5, no initiative, is in test_rules_round.gd / test_rules_modes.gd / test_onboard_ui.gd.)
# Author: Mechanics Developer Agent (kc-feedback)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const Callout: GDScript = preload("res://scripts/ui/concepts/concept_callout.gd")
const MatchSnapshot: GDScript = preload("res://scripts/ui/match_snapshot.gd")
const RunFlow: GDScript = preload("res://scripts/ui/run/run_flow.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"
const PORTRAIT: Dictionary = {"name": "iPhone 390x844 @3x", "pt": Vector2(390, 844), "ratio": 3.0}
const DESKTOP: Dictionary = {"name": "desktop 1280x720", "pt": Vector2(1280, 720), "ratio": 1.0}

var _saved_root_size: Vector2i = Vector2i.ZERO
var _guide_saved: Dictionary = {}


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _spawn(screen: Dictionary) -> Array:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(Layout.logical_size(screen))
	vp.disable_3d = true
	vp.handle_input_locally = true
	tree.root.add_child(vp)
	var m: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
	vp.add_child(m)
	await _frames(4)
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
		await _frames(2)
	return [vp, m, c]


func _despawn(vp: SubViewport) -> void:
	vp.queue_free()
	tree.root.size = _saved_root_size
	await tree.process_frame


func _guide_begin(vp: SubViewport) -> Node:
	var g: Node = tree.root.get_node("ConceptGuide")
	_guide_saved = {"auto": g.auto_show, "seen": g.seen_override, "tips": g.tips_override, "host": g.host}
	g.seen_override = {}
	g.tips_override = true
	g.auto_show = false
	g.host = vp
	g.clear_queue()
	return g


func _guide_end() -> void:
	var g: Node = tree.root.get_node("ConceptGuide")
	g.dismiss()
	g.clear_queue()
	g.auto_show = _guide_saved["auto"]
	g.seen_override = _guide_saved["seen"]
	g.tips_override = _guide_saved["tips"]
	g.host = _guide_saved["host"]


## Plays one round: the first affordable hand card in `zone`, READY, the playback skipped.
func _play_round(c: Node, zone: int) -> void:
	var me: RulesSide = c.state.sides[0]
	for rc: RulesCard in me.hand:
		if rc.card.card_type == DataEnums.CardType.UNIT and rc.card.cost <= me.supply:
			if c.state.submit(0, RulesIntent.play_card(rc.uid, zone))["ok"]:
				break
	c.refresh()
	c.press_ready()
	var guard: int = 0
	while c.is_busy() and guard < 600:
		guard += 1
		c.skip_feedback()
		await tree.process_frame
	await _frames(3)


# --- 1. tips: highlight + arrow, always on a real target --------------------------------------

## Every callout the match opens (three Deploys, the guide draining its queue each time): its target
## is a real, visible, on-screen rect; the ring is drawn round it; the arrow leaves the bubble's edge
## and ends on the ring (inside the target's highlight), and the bubble never covers the target.
func test_every_tip_in_a_scripted_match_points_at_its_target() -> void:
	for screen: Dictionary in [Layout.PHONE, PORTRAIT]:
		var s: Array = await _spawn(screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var c: Node = s[2]
		var g: Node = _guide_begin(vp)
		var view: Rect2 = Rect2(Vector2.ZERO, Vector2(vp.size))
		var opened: Array[StringName] = []
		for rnd: int in 3:
			c.notice_concepts()
			var guard: int = 0
			while guard < 40:
				guard += 1
				var id: StringName = g.show_next()
				if id == &"":
					break
				await _frames(2)
				var callout: Control = g.get_callout()
				assert_not_null(callout, "%s %s: a callout is up" % [screen["name"], id])
				if callout == null:
					break
				opened.append(id)
				var t: Rect2 = callout.target
				var label: String = "%s round %d %s" % [screen["name"], rnd + 1, id]
				assert_true(t.size.x >= 2.0 and t.size.y >= 2.0, "%s: a real target (%s)" % [label, t])
				assert_true(view.intersects(t), "%s: the target is on screen (%s in %s)" % [label, t, view])
				var c2: Dictionary = callout.connector()
				assert_false(c2.is_empty(), "%s: an arrow links the bubble to the target" % label)
				if not c2.is_empty():
					var ring: Rect2 = callout.ring_rect()
					var to: Vector2 = c2["to"]
					var from: Vector2 = c2["from"]
					assert_true(ring.grow(1.0).has_point(to), "%s: the arrow ends on the ring (%s, ring %s)" % [label, to, ring])
					var b: Rect2 = callout.bubble_rect()
					var on_edge: bool = b.grow(1.0).has_point(from) and not b.grow(-1.0).has_point(from)
					assert_true(on_edge, "%s: the arrow leaves the bubble's edge (%s, bubble %s)" % [label, from, b])
					assert_true(from.distance_to(to) >= 8.0, "%s: the arrow is long enough to see (%.0f px)" % [label, from.distance_to(to)])
				assert_false(callout.bubble_rect().intersects(t), "%s: the bubble does not cover the target (%s over %s, view %s)" % [label, callout.bubble_rect(), t, view])
				g.dismiss()
				await _frames(2)
			await _play_round(c, rnd % 3)
			if c.state.phase != MatchState.Phase.DEPLOY:
				break
		assert_true(opened.size() >= 5, "%s: the scripted match opened tips (%s)" % [screen["name"], opened])
		assert_true(opened.has(&"goal"), "%s: the goal tip opened" % screen["name"])
		_guide_end()
		await _despawn(vp)


func test_goal_tip_points_at_the_score_race() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var g: Node = _guide_begin(vp)
	c.notice_concepts()
	assert_eq(g.peek_id(), &"goal", "the goal comes first")
	g.show_next()
	await _frames(2)
	assert_true(g.get_callout().target.is_equal_approx(m.get_score_race().get_global_rect().intersection(Rect2(Vector2.ZERO, Vector2(vp.size)))),
			"the goal tip highlights the score race")
	_guide_end()
	await _despawn(vp)


func test_no_anchor_no_tip() -> void:
	var g: Node = tree.root.get_node("ConceptGuide")
	var saved: Dictionary = {"seen": g.seen_override, "tips": g.tips_override, "auto": g.auto_show}
	g.seen_override = {}
	g.tips_override = true
	g.auto_show = false
	g.clear_queue()
	g.notice(&"supply", null)
	assert_eq(g.show_next(), &"", "a tip without a target never opens (no centred bubble)")
	assert_false(g.is_seen(&"supply"), "and it is not marked seen (it comes back with a target)")
	g.notice(&"supply", Rect2())
	assert_eq(g.show_next(), &"", "an empty rect is no target either")
	g.clear_queue()
	g.seen_override = saved["seen"]
	g.tips_override = saved["tips"]
	g.auto_show = saved["auto"]


func test_connector_geometry() -> void:
	var cases: Array = [
		[Rect2(100, 300, 300, 120), Rect2(150, 100, 80, 60)],   # bubble below the target
		[Rect2(100, 20, 300, 120), Rect2(150, 300, 80, 60)],    # above
		[Rect2(500, 100, 300, 120), Rect2(100, 120, 80, 60)],   # right of it
		[Rect2(10, 100, 300, 120), Rect2(600, 120, 80, 60)],    # left of it
		[Rect2(700, 400, 300, 120), Rect2(100, 20, 80, 60)],    # a far corner
	]
	for cs: Array in cases:
		var b: Rect2 = cs[0]
		var ring: Rect2 = cs[1]
		var c: Dictionary = Callout.connector_points(b, ring)
		assert_false(c.is_empty(), "an arrow for %s -> %s" % [b, ring])
		assert_true(ring.grow(0.5).has_point(c["to"]), "ends on the ring %s" % [c])
		assert_true(b.grow(0.5).has_point(c["from"]) and not b.grow(-0.5).has_point(c["from"]), "leaves the bubble's edge %s" % [c])


# --- 2. UAV: the real cards -------------------------------------------------------------------

func test_recon_shows_the_real_rival_cards_and_they_are_inspectable() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var st: MatchState = c.state
	var foe: RulesSide = st.sides[1]
	foe.plays.clear()
	var card: CardData = CardDB.get_card(&"kc_wip_private_2")
	var rc: RulesCard = RulesCard.new()
	rc.uid = st.new_uid()
	rc.card = card
	foe.hand.append(rc)
	foe.supply = 9
	foe.ready = false
	assert_true(st.submit(1, RulesIntent.play_card(rc.uid, 1))["ok"], "the rival plays a unit face down in B")
	var before: Array = MatchSnapshot.spotted_cards(st, 0, 1)
	assert_true(before.is_empty(), "nothing spotted without recon")
	st.sides[0].flags[DataEnums.EffectKind.REVEAL_DEPLOYMENTS] = st.round_number  # a Recon Drone
	var spotted: Array = MatchSnapshot.spotted_cards(st, 0, 1)
	assert_eq(spotted.size(), 1, "one spotted card in B")
	var e: Dictionary = spotted[0]
	assert_eq([e["name"], int(e["cost"]), int(e["fp"]), int(e["armor"])], [card.display_name, card.cost, card.firepower, card.armor],
			"the entry is the card: name, cost, FP, Armor")
	assert_true(e.has("banner") and e.has("keywords"), "with its art and keywords")
	c.refresh()
	await _frames(2)
	var lane: Node = m.get_board().get_lane(MapData.ZONE_IDS[1])
	var slot: Node = null
	for es: Node in lane.get_enemy_slots():
		if es.kind == es.Kind.INCOMING:
			slot = es
	assert_not_null(slot, "an incoming slot in B")
	assert_true(slot.banner.is_spotted(), "it shows the card face (SPOTTED), not a back")
	assert_eq(int(slot.banner.entry.get("fp", -1)), card.firepower, "with the card's FP")
	assert_true((slot as Control).size.x * Layout.points_per_px(Layout.PHONE) >= 140.0, "a full-size banner on the phone")
	# Studio rule: long press / right click opens it (the card inspector, with the card's name).
	c._on_lane_long_pressed(1, &"incoming", int(slot.slot_uid))
	await _frames(2)
	var insp: Control = m.get_inspector()
	assert_true(insp.is_open(), "the spotted card is inspectable")
	var text: String = "\n".join(insp.find_children("*", "", true, false).map(func(l: Node) -> String: return IconText.plain(l)))
	assert_true(text.contains(card.display_name) and text.contains("Spotted"), "the inspector shows the card and says it was spotted")
	insp.close()
	await _despawn(vp)


# --- 3. first playthrough -----------------------------------------------------------------------

func test_first_playthrough_skips_the_setup_screens_once() -> void:
	var rs: Node = tree.root.get_node("RunState")
	var st: Node = tree.root.get_node("Settings")
	var router: Node = tree.root.get_node("SceneRouter")
	var saved: Dictionary = {"quick": st.quick_start_done, "profile": st.run_profile, "save_path": rs.save_path,
			"autosave": rs.autosave, "dry": router.dry_run, "last": router.last_requested, "persist": st.persist, "pref": st.operator_primary}
	var dir: String = "user://test_feedback_nov17/s%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	rs.save_path = dir.path_join("run.json")
	rs.autosave = false
	st.persist = false
	st.run_profile = {}
	st.quick_start_done = false
	st.operator_primary = "longreach_338"
	router.dry_run = true
	assert_true(rs.first_playthrough(), "a fresh profile is a first playthrough")
	var title: Control = (load(RunFlow.SCENE_TITLE) as PackedScene).instantiate()
	tree.root.add_child(title)
	await _frames(3)
	title.call(&"_start_new_run")
	await _frames(2)
	assert_true(rs.run.phase != RunProgress.PHASE_LOADOUT, "the run has begun (%s)" % rs.run.phase)
	assert_eq(rs.run.primary, rs.run.config.starter_primary.id, "the beginner Operator (the starter primary)")
	var starter_ks: Array[StringName] = []
	for ks: LoadoutItem in rs.run.config.starter_killstreaks:
		starter_ks.append(ks.id)
	assert_eq(rs.run.killstreaks, starter_ks, "the starter killstreaks")
	assert_eq(router.last_requested, RunFlow.SCENE_RUN_MAP, "straight to the run map (no Operator / killstreak screens)")
	assert_true(st.quick_start_done, "remembered")
	assert_false(rs.first_playthrough(), "the next run is not a first playthrough")
	# Persisted like every option (Settings file, mirrored by SaveMirror on the web).
	var path: String = dir.path_join("settings.cfg")
	assert_eq(st.save_to(path), OK, "saved")
	st.quick_start_done = false
	assert_true(st.load_from(path), "read back")
	assert_true(st.quick_start_done, "a reload keeps it")
	# The second run shows the screens.
	title.call(&"_start_new_run")
	await _frames(2)
	assert_eq(router.last_requested, RunFlow.SCENE_LOADOUT, "the second run opens the Operator / killstreak screens")
	assert_eq(rs.run.phase, RunProgress.PHASE_LOADOUT, "and waits for BEGIN RUN there")
	title.queue_free()
	rs.reset()
	rs.save_path = saved["save_path"]
	rs.autosave = saved["autosave"]
	router.dry_run = saved["dry"]
	router.last_requested = saved["last"]
	st.quick_start_done = saved["quick"]
	st.run_profile = saved["profile"]
	st.persist = saved["persist"]
	st.operator_primary = saved["pref"]
	await _frames(1)


func test_a_player_with_a_finished_run_sees_the_screens() -> void:
	var rs: Node = tree.root.get_node("RunState")
	var st: Node = tree.root.get_node("Settings")
	var saved: Dictionary = {"quick": st.quick_start_done, "profile": st.run_profile}
	st.quick_start_done = false
	st.run_profile = {"runs_finished": 2}
	assert_false(rs.first_playthrough(), "an existing player (2 runs finished) keeps the screens")
	st.quick_start_done = saved["quick"]
	st.run_profile = saved["profile"]


# --- 4. the score race -----------------------------------------------------------------------

func test_score_race_on_top_of_the_board_with_plus_n() -> void:
	for screen: Dictionary in [Layout.PHONE, PORTRAIT, DESKTOP]:
		var s: Array = await _spawn(screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var c: Node = s[2]
		var label: String = screen["name"]
		var race: ScoreRaceBar = m.get_score_race()
		var board: Rect2 = m.get_board().get_global_rect()
		var rr: Rect2 = race.get_global_rect()
		assert_true(race.is_visible_in_tree(), "%s: the score race shows" % label)
		assert_true(rr.end.y <= board.position.y + 0.5 and rr.end.y >= board.position.y - 8.0, "%s: right over the board (%s / %s)" % [label, rr, board])
		assert_true(absf(rr.size.x - board.size.x) < 1.0, "%s: as wide as the board" % label)
		assert_true(Rect2(Vector2.ZERO, Vector2(vp.size)).grow(0.5).encloses(rr), "%s: on screen" % label)
		var g: Dictionary = race.layout()
		var bars: Array = g["bars"]
		assert_true((bars[0] as Rect2).end.x <= (g["goal"] as Rect2).position.x + 0.5 and (bars[1] as Rect2).position.x >= (g["goal"] as Rect2).end.x - 0.5,
				"%s: two bars, the target between them" % label)
		assert_true((g["nums"][0] as Rect2).end.x <= (bars[0] as Rect2).position.x + 0.5 and (g["nums"][1] as Rect2).position.x >= (bars[1] as Rect2).end.x - 0.5,
				"%s: the numbers at the ends" % label)
		var k: float = Layout.points_per_px(screen)
		assert_true(float(race.font_size()) * k >= 10.5, "%s: readable text (%.1f pt)" % [label, float(race.font_size()) * k])
		# Points scored: the fill slides and "+N" pops for whoever scored.
		var target: int = race.target
		assert_true(target > 0, "%s: the target (%d)" % [label, target])
		m.score_race_scored(2, 1)
		assert_eq(race.pop_texts(), ["+2", "+1"] as Array[String], "%s: +2 for you, +1 for the rival" % label)
		await _frames(2)
		assert_true(race.shown.x > 0.0 and race.shown.x <= 2.0, "%s: the fill is sliding toward 2" % label)
		assert_eq(race.get_text(), "You 2, rival 1. First to %d." % target, "%s: the words" % label)
		# The old score displays are gone: the strip badge is the round + LOG, the flyout has no ScoreBar.
		assert_eq(m.get_badge(&"score").get_text(), "R%d LOG" % c.state.round_number, "%s: the old SCORE badge is the LOG" % label)
		await _despawn(vp)


# --- 6. movement: any column, on screen too ---------------------------------------------------

func test_operator_move_reaches_the_far_column_on_screen() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var c: Node = s[2]
	var st: MatchState = c.state
	var op: RulesUnit = st.sides[0].operator_unit
	st.put_in_line(op, 0)
	st.sides[0].operator_can_deploy = false
	c.refresh()
	await _frames(2)
	assert_true(MatchSnapshot.can_move(st, 0, op), "the Operator in A can move")
	c.select_operator()
	assert_eq(c.check_play(2)["ok"], true, "A -> C: the far column lights up too")
	assert_eq(c.check_play(1)["ok"], true, "A -> B")
	assert_eq(c.check_play(0)["ok"], false, "not where it is")
	c.clear_selection()
	await _despawn(vp)


# --- 7. no round recap panel; the LOG -----------------------------------------------------------

func test_no_recap_panel_round_log_behind_the_log_badge() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	await _play_round(c, 1)
	assert_eq(c.state.round_number, 2, "round 2")
	assert_false(m.has_method(&"get_round_recap"), "no recap panel")
	assert_true(m.find_children("RoundRecap", "", true, false).is_empty(), "nothing called RoundRecap on screen")
	assert_eq(c.round_log.size(), 1, "the round went to the log")
	m.get_badge(&"score").tapped.emit()
	await _frames(2)
	var insp: Control = m.get_inspector()
	assert_true(insp.is_open(), "LOG opens the round log")
	var text: String = "\n".join(insp.find_children("*", "", true, false).map(func(l: Node) -> String: return IconText.plain(l)))
	assert_true(text.contains("Round log") and text.contains("ROUND 1"), "it lists round 1: %s" % text.left(200))
	insp.close()
	# What just happened shows on the board: a column that scored says "+1 YOU" / "+1 RIVAL".
	var zc: Array = c.state.events.filter(func(e: Dictionary) -> bool: return e["type"] == RulesEvent.ZONE_CONTROL)
	assert_eq(zc.size(), 3, "three columns scored or not")
	for e: Dictionary in zc:
		var owner: StringName = StringName(e["owner"])
		assert_eq(int(e["points"]), 1 if owner in [&"player", &"enemy"] else 0, "points on the event (%s)" % owner)
	assert_false(ConceptRegistry.get_concept(&"firefight").get("trigger", "").contains("recap"), "no tip refers to the recap")
	await _despawn(vp)

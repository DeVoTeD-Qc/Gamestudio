# test_p18_regressions.gd
# Purpose: Regression tests for the bugs QA found in p18 (one test per bug report in
#   projects/killstreak/qa/bug-reports/), plus rules edge cases from core-rules §9 and the
#   two Rulings sections that the p04-p07 suites did not pin down yet.
# Author: QA Agent (p18)
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = MatchState.PLAYER
const E: int = MatchState.ENEMY


# --- Bug p18-001: the AI moved one unit with two Flank Routes in the same Deploy -------------

func test_bug001_ai_never_plans_a_second_move_for_the_same_unit() -> void:
	var deck: Array = [F.flank_route(), F.flank_route(), F.rifleman(), F.rifleman(), F.rifleman()]
	var m: MatchState = F.new_match(F.setup(), F.setup(deck))
	var mover: RulesUnit = F.place(m, E, F.rifleman(), F.LEFT)
	var planner: AiPlanner = AiPlanner.new()
	planner._begin(AiView.capture(m, E))
	var root = planner._root_plan()
	var first: Dictionary = {}
	for c: Dictionary in planner._candidates(root):
		if int(c["target_uid"]) == mover.uid:
			first = c
			break
	assert_false(first.is_empty(), "a Flank Route on the unit is a candidate")
	var after = planner._child(root, first)
	var again: int = 0
	for c: Dictionary in planner._candidates(after):
		if int(c["target_uid"]) == mover.uid:
			again += 1
	assert_eq(again, 0, "no second move for a unit that already moves this Deploy")
	# And the engine agrees: the second move is refused (it checks the board zone).
	var fr: Array[int] = []
	for rc: RulesCard in m.sides[E].hand:
		if rc.card.id == &"flank_route":
			fr.append(rc.uid)
	assert_true(m.submit(E, RulesIntent.play_card(fr[0], F.LEFT, mover.uid, F.MID))["ok"], "first move")
	assert_false(m.submit(E, RulesIntent.play_card(fr[1], F.MID, mover.uid, F.RIGHT))["ok"], "second move refused")


# --- Edge cases not yet pinned down (core-rules §9, Rulings 1 and 2) --------------------------

func test_suppress_applies_after_attack_helo_to_the_new_point_man() -> void:
	# Rulings 2 #6: Helo kills the point man first, Suppress then hits whoever is point man.
	var p: SideSetup = F.setup()
	p.killstreaks.assign([F.attack_helo()])
	var m: MatchState = F.new_match(p)
	StreakTracker.grant(m, P, &"attack_helo")
	F.place(m, P, F.gunner(), F.MID)
	var front: RulesUnit = F.place(m, E, F.unit("front", 3, 2), F.MID)
	var back: RulesUnit = F.place(m, E, F.unit("back", 3, 9), F.MID)
	assert_true(m.submit(P, RulesIntent.use_item(&"attack_helo"))["ok"], "helo")
	m.reveal()
	m.firefight()
	assert_false(front.is_alive(), "Helo took the old point man")
	assert_eq(m.firepower_of(back), 1, "Suppress hit the new point man (3 - 2)")


func test_several_suppress_stack_with_a_floor_of_zero() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, F.gunner(), F.MID)
	F.place(m, P, F.gunner(), F.MID)
	var pm: RulesUnit = F.place(m, E, F.unit("pm", 3, 20), F.MID)
	var pm2: RulesUnit = F.place(m, E, F.unit("pm2", 5, 20), F.MID)
	m.firefight()
	assert_eq(m.firepower_of(pm), 0, "two Suppress: 3 - 4 clamps to 0")
	m.score()
	m.sides[E].line(F.MID).erase(pm)
	pm.zone = -1
	m.firefight()
	assert_eq(m.firepower_of(pm2), 1, "two Suppress stack: 5 - 4")


func test_second_in_line_hit_reads_the_line_as_it_was() -> void:
	# Rulings 2 #7: the point man dies to the 2, but "1 to the next enemy" is still the 2nd unit.
	var p: SideSetup = F.setup([], F.kestrel())
	var m: MatchState = F.new_match(p)
	F.grant(m, P, F.point_strike())
	F.place_operator(m, P, F.MID)
	var pm: RulesUnit = F.place(m, E, F.unit("pm", 0, 2), F.MID)
	var second: RulesUnit = F.place(m, E, F.unit("second", 0, 5), F.MID)
	var third: RulesUnit = F.place(m, E, F.unit("third", 0, 5), F.MID)
	assert_true(m.submit(P, RulesIntent.use_item(&"point_strike", F.MID))["ok"], "point strike")
	m.reveal()
	assert_false(pm.is_alive(), "point man down")
	assert_eq([second.armor, third.armor], [4, 5], "the 1 went to the original 2nd unit")


func test_callout_buffs_a_unit_played_before_it() -> void:
	# Ruling 7: "whether played before or after the Callout".
	var p: SideSetup = F.setup([F.rifleman(), F.callout()])
	var m: MatchState = F.new_match(p)
	var r_uid: int = F.hand_uid(m, P, "rifleman")
	assert_true(m.submit(P, RulesIntent.play_card(r_uid, F.RIGHT))["ok"], "unit first")
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "callout"), F.RIGHT))["ok"], "then Callout")
	m.reveal()
	assert_eq(m.firepower_of(m.sides[P].find_unit(r_uid)), 4, "2 + 1 (AR in Mid) + 1 from the later Callout")


func test_patch_tie_goes_to_the_front_most() -> void:
	var m: MatchState = F.new_match()
	var a: RulesUnit = F.place(m, P, F.unit("a", 0, 6), F.MID)
	var b: RulesUnit = F.place(m, P, F.unit("b", 0, 6), F.MID)
	F.place(m, P, F.combat_medic(), F.MID)
	F.place(m, E, F.unit("e", 0, 9), F.MID)
	a.armor = 3
	b.armor = 3
	m.firefight()
	assert_eq([a.armor, b.armor], [5, 3], "tie in missing Armor: front-most is healed")


func test_zone_capacity_counts_the_operator_rotating_out() -> void:
	# Rulings 2 #9: current units + queued arrivals - the Operator rotating out.
	var deck: Array = [F.rifleman(), F.rifleman()]
	var m: MatchState = F.new_match(F.setup(deck, F.kestrel()))
	m.sides[P].supply = 5
	F.place_operator(m, P, F.MID)
	for i: int in 3:
		F.place(m, P, F.unit("u%d" % i, 1, 1), F.MID)
	var r1: int = m.sides[P].hand[0].uid
	assert_false(m.submit(P, RulesIntent.play_card(r1, F.MID))["ok"], "Mid is full (Operator + 3)")
	assert_true(m.submit(P, RulesIntent.rotate(F.LEFT))["ok"], "Operator rotates out")
	assert_true(m.submit(P, RulesIntent.play_card(r1, F.MID))["ok"], "now there is room")


func test_two_holders_contest_the_zone() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, F.anvil(), F.MID)
	F.place(m, E, F.anvil(), F.MID)
	assert_eq(m.control_of(F.MID), MatchState.CONTROL_CONTESTED, "Holder vs Holder: contested")


func test_overtime_supply_stays_capped() -> void:
	var cfg: RunConfig = load("res://data/run_config.tres") as RunConfig
	for r: int in [8, 9, 10]:
		assert_eq(cfg.supply_for_round(r), cfg.supply_cap, "round %d supply capped" % r)


func test_full_hand_draw_is_discarded_and_logged() -> void:
	# §9: hand full (7) on draw -> the drawn card is discarded and shown in the log.
	var deck: Array = []
	for i: int in 12:
		deck.append(F.unit("c%d" % i, 1, 1))
	var m: MatchState = F.new_match(F.setup(deck))
	var s: RulesSide = m.sides[P]
	while s.hand.size() < 7:
		m.draw_cards(P, 1)
	var before_discard: int = s.discard.size()
	var top: StringName = s.deck[0].card.id
	m.draw_cards(P, 1)
	assert_eq(s.hand.size(), 7, "hand stays at 7")
	assert_eq(s.discard.size(), before_discard + 1, "card went to the discard pile")
	var burned: Array[Dictionary] = F.events_of(m, RulesEvent.CARD_BURNED)
	assert_eq(burned.size(), 1, "logged as card_burned")
	assert_eq(burned[0]["card_id"], top, "the drawn card")


func test_elimination_credit_goes_to_the_shot_that_crossed_lethal() -> void:
	# Rulings 2 #8: shots resolve in line order; the shot that crosses lethal gets the credit.
	var m: MatchState = F.new_match()
	var first: RulesUnit = F.place(m, P, F.unit("first", 2, 9), F.MID)
	var second: RulesUnit = F.place(m, P, F.unit("second", 2, 9), F.MID)
	F.place(m, E, F.unit("target", 0, 3), F.MID)
	m.firefight()
	var rec: Dictionary = F.events_of(m, RulesEvent.UNIT_ELIMINATED)[0]
	assert_eq(int(rec["by_uid"]), second.uid, "2 + 2 crosses 3 on the second shot")
	assert_true(first.uid != second.uid, "distinct shooters")


# --- Bug p18-003: the drill's score bar said "FIRST TO 20" -------------------------------------

func test_bug003_tutorial_score_bar_shows_the_drill_length_not_the_dummy_target() -> void:
	const TutorialController: GDScript = preload("res://scripts/ui/tutorial/tutorial_match_controller.gd")
	const MatchSnapshot: GDScript = preload("res://scripts/ui/match_snapshot.gd")
	var script: TutorialScript = CardDB.get_tutorial_script(&"tutorial_basic")
	var m: MatchState = TutorialController.build_state(script)
	m.start_match()
	var snap: Dictionary = MatchSnapshot.build(m, script.map, MatchState.PLAYER, [])
	assert_eq(snap["goal"], "%d-ROUND DRILL" % script.round_cap, "drill goal text")
	assert_false(String(snap["goal"]).contains(str(script.score_target)), "no dummy target shown")
	# A run match still shows its real target.
	var cfg: RunConfig = load("res://data/run_config.tres") as RunConfig
	var hooks: MatchHooks = MatchHooks.new()
	hooks.mode_rules = ModeRules.create(DataEnums.GameMode.ZONE_CONTROL, cfg)
	var run_m: MatchState = MatchState.new(cfg, script.map, SideSetup.new(), SideSetup.new(), 1, hooks)
	run_m.start_match()
	assert_eq(MatchSnapshot.build(run_m, script.map, MatchState.PLAYER, [])["goal"], "FIRST TO %d" % cfg.zone_control_target, "run goal")
	assert_false(cfg.has_meta(&"goal_text"), "the shared run config is untouched")

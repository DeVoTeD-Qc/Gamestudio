# test_duel_match.gd
# Purpose: kc-duel-impl: DuelMatch (duel-mode.md §4): vs AI at the three tiers (Recruit -1 Armor, the
#   planner settings), Pass & Play hot seat (covers, private Deploys, the turn guard, who deploys first
#   alternating, private events), forfeit, results, DuelState start / finish, and a short soak of every
#   preset pair to the end on the real engine.
# Author: Mechanics Developer Agent (kc-duel-impl)
extends "res://tests/test_case.gd"


func _cfg() -> DuelConfig:
	return load("res://data/duel/duel_config.tres") as DuelConfig


func _base() -> RunConfig:
	return load("res://data/run_config.tres") as RunConfig


func test_ai_tiers() -> void:
	var r: AiPlayer = AiPlayer.for_duel_tier(&"recruit")
	var g: AiPlayer = AiPlayer.for_duel_tier(&"regular")
	var v: AiPlayer = AiPlayer.for_duel_tier(&"veteran")
	assert_false(r.planner.synergy_aware, "Recruit ignores sets")
	assert_false(g.planner.synergy_aware, "Regular ignores sets")
	assert_true(v.planner.synergy_aware, "Veteran is set-aware")
	assert_eq(r.personality.second_best_chance, 0.6, "Recruit 2nd-best 60%")
	assert_eq(g.personality.second_best_chance, 0.6, "Regular 2nd-best 60%")
	assert_eq(v.personality.second_best_chance, 0.0, "Veteran always its best")
	assert_eq(r.personality.weight_damage_dealt, 1.5, "casual weights")
	assert_eq(AiPlayer.for_duel_tier(&"regular", 0.4).personality.second_best_chance, 0.4, "tunable from DuelConfig")
	var c: DuelConfig = _cfg()
	var m: DuelMatch = DuelMatch.vs_ai(c.preset(&"spearhead"), c.preset(&"iron_wall"), &"recruit", c, _base(), 3)
	assert_eq(m.armor_bonus(1), -1, "Recruit's side: -1 Armor")
	assert_eq(m.armor_bonus(0), 0, "the player's side: none")
	m = DuelMatch.vs_ai(c.preset(&"spearhead"), c.preset(&"iron_wall"), &"veteran", c, _base(), 3)
	assert_eq(m.armor_bonus(1), 0, "Veteran: no handicap")


func test_vs_ai_flow() -> void:
	var c: DuelConfig = _cfg()
	var m: DuelMatch = DuelMatch.vs_ai(c.preset(&"overwatch"), c.preset(&"hollow_ranks"), &"regular", c, _base(), 11)
	var started: Array = []
	var ready_count: Array = [0]
	m.deploy_started.connect(func(s: int) -> void: started.append(s))
	m.round_ready.connect(func() -> void: ready_count[0] += 1)
	m.start()
	assert_eq(started, [0], "the human's Deploy opens")
	assert_true(m.state.sides[1].ready, "the AI committed first")
	assert_eq(m.active_side, 0, "human active")
	assert_true(m.can_view_private(0), "own hand visible")
	assert_false(m.can_view_private(1), "never the AI's")
	assert_eq(m.submit(1, {})["code"], DuelMatch.CODE_NOT_YOUR_TURN, "can't play for the AI")
	assert_eq(m.finish_deploy(0), "", "READY")
	assert_eq(ready_count[0], 1, "round ready")
	m.resolve_round()
	m.round_done()
	assert_eq(m.state.round_number, 2, "round 2")
	assert_eq(started, [0, 0], "Deploy opens again")


func test_hot_seat_covers_turns_and_privacy() -> void:
	var c: DuelConfig = _cfg()
	var m: DuelMatch = DuelMatch.hot_seat(c.preset(&"spearhead"), c.preset(&"overwatch"), ["Ana", "Ben"], c, _base(), 21)
	assert_eq(m.humans, [true, true] as Array[bool], "two humans")
	var p1_side: int = m.seat_of_player(0)
	assert_eq(m.names[p1_side], "Ana", "Player 1 sits where the coin put her")
	assert_eq(m.decks[p1_side].id, &"spearhead", "with her deck")
	assert_eq(m.player_of_side(p1_side), 0, "inverse")
	var covers: Array = []
	var log: Array = []
	m.cover_needed.connect(func(s: int, n: String) -> void: covers.append([s, n]))
	m.deploy_started.connect(func(s: int) -> void: log.append("deploy%d" % s))
	m.side_ready.connect(func(s: int) -> void: log.append("ready%d" % s))
	m.round_ready.connect(func() -> void: log.append("round"))
	m.start()
	assert_eq(covers, [[0, m.names[0]]], "round 1: seat 0 deploys first, behind a cover")
	assert_eq(m.active_side, -1, "nobody active under the cover")
	assert_false(m.can_view_private(0) or m.can_view_private(1), "no hand under a cover")
	assert_eq(m.accept_cover(1), "Wait for your turn", "the wrong player can't take the cover")
	assert_eq(m.mulligan(0, [])["code"], DuelMatch.CODE_NOT_YOUR_TURN, "nothing before the cover")
	assert_eq(m.accept_cover(0), "", "Player on seat 0 takes the device")
	assert_true(m.can_view_private(0), "own hand")
	assert_false(m.can_view_private(1), "not the other's")
	assert_eq(m.viewer(), 0, "board drawn for seat 0")
	assert_eq(m.submit(1, {})["code"], DuelMatch.CODE_NOT_YOUR_TURN, "side 1 waits")
	assert_true(m.mulligan(0, [])["ok"], "private mulligan (keep)")
	# The opening draws are private to their side.
	var vis: Array[Dictionary] = m.visible_events(m.state.events, 0)
	for e: Dictionary in vis:
		assert_true(e.get("private_to", &"player") == &"player", "only side 0's private events")
	assert_true(vis.size() < m.state.events.size(), "side 1's draws are hidden")
	assert_eq(m.finish_deploy(1), "Wait for your turn", "can't ready the other side")
	assert_eq(m.finish_deploy(0), "", "seat 0 ready")
	assert_eq(covers.back(), [1, m.names[1]], "cover for seat 1")
	assert_false(m.state.both_ready(), "not resolved yet")
	assert_eq(m.accept_cover(1), "", "seat 1 takes the device")
	assert_eq(m.finish_deploy(1), "", "seat 1 ready")
	assert_eq(log, ["deploy0", "ready0", "deploy1", "ready1", "round"], "the order of the handoff")
	m.resolve_round()
	m.round_done()
	assert_eq(covers.back()[0], 1, "round 2: seat 1 deploys first (alternates)")
	assert_eq(m.first_deployer(3), 0, "round 3: seat 0 again")


func test_forfeit_and_result() -> void:
	var c: DuelConfig = _cfg()
	var m: DuelMatch = DuelMatch.vs_ai(c.preset(&"spearhead"), c.preset(&"overwatch"), &"veteran", c, _base(), 8)
	var ended: Array = []
	m.match_ended.connect(func(r: Dictionary) -> void: ended.append(r))
	m.start()
	assert_true(m.forfeit(0), "concede")
	assert_eq(ended.size(), 1, "match_ended once")
	var r: Dictionary = ended[0]
	assert_eq(r["winner_side"], 1, "the AI wins")
	assert_eq(r["reason"], DuelMatch.REASON_FORFEIT, "forfeit")
	assert_eq(r["heroes"], [&"kestrel_ar7", &"longreach_338"], "heroes")
	assert_eq(r["decks"], [&"spearhead", &"overwatch"], "decks")
	assert_false(r["human_won"], "lost")
	assert_false(m.forfeit(0), "only once")


func test_duel_state_start_and_finish() -> void:
	var st: Node = tree.root.get_node("Settings")
	var ds: Node = tree.root.get_node("DuelState")
	var saved: Variant = st.run_profile
	st.run_profile = RunProfile.blank()
	var bad: DuelDeck = DuelDeck.new()
	var r: Dictionary = ds.start_vs_ai(bad, &"random", &"recruit", 1)
	assert_false(r["ok"], "an illegal deck can't play")
	assert_eq(r["reason"], "Pick 10 more cards (0/10)", "the first red line")
	assert_false(ds.start_vs_ai(ds.preset(&"spearhead"), &"spearhead", &"godlike", 1)["ok"], "unknown tier")
	r = ds.start_vs_ai(ds.preset(&"spearhead"), &"random", &"recruit", 1)
	assert_true(r["ok"], "a preset (loaner) plays at once")
	var m: DuelMatch = r["match"]
	assert_true(m == ds.take_current(), "kept for the match scene")
	assert_true(m.decks[1].preset, "the AI plays a preset")
	assert_false(ds.finish(m)["ok"], "not over yet")
	m.start()
	m.forfeit(1)
	var f: Dictionary = ds.finish(m)
	assert_true(f["ok"], "recorded")
	assert_eq(f["records"]["heroes"]["kestrel_ar7"]["w"], 1, "the hero's win")
	assert_eq(f["new_cosmetics"][0]["kind"], DuelProfile.KIND_FRAME, "Duelist frame")
	var copy: DuelDeck = ds.preset(&"iron_wall").copy()
	r = ds.start_hot_seat(copy, ds.preset(&"overwatch"), ["", ""])
	assert_false(r["ok"], "a locked card blocks a copied preset")
	assert_eq(r["reason"], "Player 1: Mortar Pit isn't in your collection: find it in the campaign", "names the player")
	r = ds.start_hot_seat(copy, ds.preset(&"overwatch"), ["", ""], {"open_pool": true, "seed": 5})
	assert_true(r["ok"], "open pool for this match")
	assert_eq(r["match"].kind, DuelMatch.KIND_HOT_SEAT, "hot seat")
	st.run_profile = saved


## Every preset pair plays to the end on the real engine, both seats, every tier (a light soak; the
## balance numbers come from tests/tools/duel_sim.gd).
func test_soak_presets_reach_an_end() -> void:
	var c: DuelConfig = _cfg()
	var ids: Array[StringName] = [&"spearhead", &"overwatch", &"iron_wall", &"hollow_ranks"]
	var tiers: Array[StringName] = [&"recruit", &"regular", &"veteran"]
	var games: int = 0
	var max_rounds: int = 0
	for a: int in ids.size():
		for b: int in ids.size():
			if a == b:
				continue
			var m: DuelMatch = DuelMatch.vs_ai(c.preset(ids[a]), c.preset(ids[b]), tiers[(a + b) % 3], c, _base(), 900 + a * 31 + b)
			var p: AiPlayer = AiPlayer.for_duel_tier(&"veteran")
			m.start()
			var guard: int = 0
			while m.state.phase != MatchState.Phase.ENDED and guard < 15:
				p.take_turn(m.state, 0, false)
				m.finish_deploy(0)
				m.resolve_round()
				m.round_done()
				guard += 1
			games += 1
			max_rounds = maxi(max_rounds, m.state.round_number)
			assert_eq(m.state.phase, MatchState.Phase.ENDED, "%s vs %s ends" % [ids[a], ids[b]])
			assert_true(m.result()["ended"], "result says ended")
	assert_eq(games, 12, "12 games")
	assert_true(max_rounds <= c.match_config(_base()).overtime_draw_round, "no match runs past overtime (%d)" % max_rounds)

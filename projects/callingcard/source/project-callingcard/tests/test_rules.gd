# test_rules.gd
# Purpose: Engine-contract tests for scripts/rules beyond QA's case list: the RQ-08 / RQ-09 /
#   RQ-02 / RQ-04 switches, preview() never changing the state, copy() independence, hidden
#   face-down identity, generic wall sizes, and seeded random full duels (preview == place on
#   every move, score bookkeeping, events match results).
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const Fx: GDScript = preload("res://tests/test_rules_fixtures.gd")

var _cards: Dictionary = Fx.build_cards()
var _triptychs: Array[TriptychData] = Fx.build_triptychs(_cards)


func _case(id: String) -> Dictionary:
	for c: Dictionary in Fx.load_cases().get("cases", []):
		if c["id"] == id:
			return c
	return {}


## Runs one QA case's steps with the given options; returns the step results.
func _play_case(id: String, options: RulesOptions) -> Array[PlacementResult]:
	var c: Dictionary = _case(id)
	var state: WallState = WallState.from_setup(c["setup"], _cards, Fx.build_balance(c.get("balance_overrides", {})),
			options, _triptychs)
	var out: Array[PlacementResult] = []
	for step: Dictionary in c["steps"]:
		var a: Dictionary = step["action"]
		var cf: StringName = StringName(str(a["cipher_copy_from"])) if a.get("cipher_copy_from") != null else &""
		out.append(WallRules.place(state, WallState.player_from_string(a["player"]), _cards[StringName(a["card"])],
				StringName(a["slot"]), cf, bool(a["signature"])))
	return out


func test_showcase_set_link_flag_rq08() -> void:
	assert_true(_play_case("BW-064", RulesOptions.new())[0].set_link, "default: Showcase links (decided yes)")
	var o: RulesOptions = RulesOptions.new()
	o.showcase_set_link = false
	var r: PlacementResult = _play_case("BW-064", o)[0]
	assert_false(r.set_link, "flag off: no Showcase Set Link")
	assert_eq(r.effective_values, {&"top": 5, &"side": 4, &"bottom": 4}, "printed values")
	# Other sets are unaffected by the flag.
	assert_true(_play_case("BW-058", o)[0].set_link, "Whiteout still links with the flag off")


func test_clutch_full_score_flag_rq09() -> void:
	assert_true(_play_case("BW-045", RulesOptions.new())[0].clutch, "default: face-down card counts, P2 behind")
	var o: RulesOptions = RulesOptions.new()
	o.clutch_uses_full_score = false
	assert_true(_play_case("BW-045", o)[0].clutch, "public score: face-down still counts 1")
	# A face-down Signature: full score counts it 2, the public score 1.
	var setup: Dictionary = {"first_player": "P1", "to_move": "P2", "board": [
		{"slot": "a1", "card": "snow_blind", "lineup": "P1", "controller": "P1", "face_down": true, "signature": true},
		{"slot": "c3", "card": "gold_leaf", "lineup": "P2", "controller": "P2", "face_down": false, "signature": false},
		{"slot": "a3", "card": "chrome_tiger", "lineup": "P2", "controller": "P2", "face_down": false, "signature": false}]}
	var full: WallState = WallState.from_setup(setup, _cards, BalanceConfig.new(), RulesOptions.new(), _triptychs)
	assert_true(WallRules.is_behind(full, WallState.P2) == false and WallRules.score(full, WallState.P1) == 2, "full: level 2-2")
	var pub: WallState = WallState.from_setup(setup, _cards, BalanceConfig.new(), o, _triptychs)
	assert_false(WallRules.is_behind(pub, WallState.P2), "public: P2 ahead 2-1")
	assert_true(WallRules.is_behind(pub, WallState.P1), "public: P1 behind 1-2")


func test_cipher_copy_flags_rq02_rq04() -> void:
	var o: RulesOptions = RulesOptions.new()
	o.cipher_copies_printed_trait = false
	assert_eq(_play_case("BW-053", o)[0].trait_name(), &"veteran", "active-trait copy passes Veteran on")
	assert_eq(_play_case("BW-053", RulesOptions.new())[0].trait_name(), &"none", "default copies printed Cipher -> none")
	var lost: Array[PlacementResult] = _play_case("BW-051", RulesOptions.new())
	assert_eq(lost[1].springs.size(), 0, "captured Cipher-Ambush doesn't spring")
	assert_eq(lost[1].springs_cancelled, [&"b2"] as Array[StringName], "spring cancelled (RQ-04)")


func test_preview_never_changes_state() -> void:
	var c: Dictionary = _case("BW-034")
	var state: WallState = WallState.from_setup(c["setup"], _cards, BalanceConfig.new(), RulesOptions.new(), _triptychs)
	var before: String = var_to_str(state.to_dict())
	var pv: PlacementResult = WallRules.preview(state, WallState.P1, _cards[&"city_never_sleeps"], &"b2")
	assert_true(pv.ok and pv.is_preview, "preview ok")
	assert_eq(var_to_str(state.to_dict()), before, "state unchanged after preview")
	assert_eq(pv.reclaimed.size(), 2, "preview shows the reclaims with their own marker")
	var bad: PlacementResult = WallRules.preview(state, WallState.P1, _cards[&"neon_rain"], &"a1")
	assert_eq(bad.error, WallRules.ERR_SLOT_OCCUPIED, "illegal preview is rejected")


func test_preview_shows_steady_blocks_and_own_last_spring() -> void:
	var c: Dictionary = _case("BW-018")
	var state: WallState = WallState.from_setup(c["setup"], _cards, BalanceConfig.new(), RulesOptions.new(), _triptychs)
	var pv: PlacementResult = WallRules.preview(state, WallState.P1, _cards[&"glacier"], &"c1")
	assert_eq(pv.steady_blocked, [&"b2"] as Array[StringName], "Steady block is visible in the preview")
	var last: Dictionary = _case("BW-029")
	var s2: WallState = WallState.from_setup(last["setup"], _cards, BalanceConfig.new(), RulesOptions.new(), _triptychs)
	var pv2: PlacementResult = WallRules.preview(s2, WallState.P2, _cards[&"flare_up"], &"c2")
	assert_eq(pv2.springs.size(), 1, "last-placement Ambush: its own spring is in the preview (RQ-20)")
	assert_eq(pv2.score_after, [5, 7] as Array[int], "preview score includes it")


func test_copy_is_independent() -> void:
	var c: Dictionary = _case("BW-013")
	var state: WallState = WallState.from_setup(c["setup"], _cards, BalanceConfig.new(), RulesOptions.new(), _triptychs)
	var snap: String = var_to_str(state.to_dict())
	var cp: WallState = state.copy()
	WallRules.place(cp, WallState.P1, _cards[&"brass_tacks"], &"b2")
	assert_eq(var_to_str(state.to_dict()), snap, "original untouched by placing on the copy")
	assert_eq(cp.controller_of(&"a1"), WallState.P1, "copy changed")


func test_face_down_identity_is_hidden_from_the_opponent() -> void:
	var c: Dictionary = _case("BW-025")
	var state: WallState = WallState.from_setup(c["setup"], _cards, BalanceConfig.new(), RulesOptions.new(), _triptychs)
	assert_eq(state.to_dict(WallState.P2)["wall"][&"b2"]["card"], &"?", "opponent sees '?'")
	assert_eq(state.to_dict(WallState.P2)["wall"][&"b2"]["active_trait"], &"ambush", "but knows it is an Ambush")
	assert_eq(state.to_dict(WallState.P1)["wall"][&"b2"]["card"], &"snow_blind", "owner sees it")


func test_cipher_pick_rules() -> void:
	var state: WallState = WallState.from_setup({"to_move": "P1", "board": [
		{"slot": "a1", "card": "neon_rain", "lineup": "P2", "controller": "P2"}]}, _cards)
	var ng: CardData = _cards[&"null_glyph"]
	assert_eq(WallRules.check_place(state, WallState.P1, ng, &"b2"), WallRules.ERR_CIPHER_PICK_REQUIRED, "pick required")
	assert_eq(WallRules.check_place(state, WallState.P1, ng, &"b2", &"c3"), WallRules.ERR_INVALID_CIPHER_PICK, "pick must be a neighbour")
	assert_eq(WallRules.check_place(state, WallState.P1, ng, &"c3"), &"", "no neighbours: no pick")
	assert_eq(WallRules.cipher_picks(state, &"b2"), [&"a1"] as Array[StringName], "picks")


func test_generic_wall_layout() -> void:
	var t: WallTopology = WallTopology.get_for(PackedInt32Array([4, 5, 4]))
	assert_eq(t.slot_count(), 13, "4/5/4 has 13 slots")
	assert_eq(t.neighbour_slots(&"b3").size(), 6, "middle brick has 6 neighbours")
	assert_eq(t.neighbours_in(&"b1", WallTopology.Dir.ABOVE), [&"a1"] as Array[StringName], "b1 above")
	assert_eq(t.neighbours_in(&"a4", WallTopology.Dir.BELOW), [&"b4", &"b5"] as Array[StringName], "a4 below")
	assert_eq(t.runs_of_three.size(), 2 + 3 + 2, "Triptych runs")


func test_lineup_rules_extra() -> void:
	var b: BalanceConfig = BalanceConfig.new()
	var ids: Array = ["graveyard_shift", "neon_rain", "last_train", "snow_blind", "mayday"]
	var cards: Array = Fx.cards_from_ids(_cards, ids)
	var ineligible: CardData = (_cards[&"mayday"] as CardData).duplicate()
	ineligible.signature_eligible = false
	cards[4] = ineligible
	var res: Dictionary = LineupRules.validate(cards, [ineligible], null, b)
	assert_eq(res["errors"], [LineupRules.SIGNATURE_INELIGIBLE] as Array[StringName], "ineligible Signature")
	var found: Dictionary = LineupRules.find_legal_lineup(_cards.values(), b)
	assert_eq(LineupRules.validate(found["cards"], [found["signature"]], null, b)["valid"], true, "found lineup is legal")
	var all_c3: Array = Fx.cards_from_ids(_cards, ["snow_blind", "polar_night", "dead_air", "brass_tacks", "honor_roll"])
	assert_true(LineupRules.should_offer_loaner(all_c3, b), "five Clearance-3 cards can't make a lineup (RQ-16)")


func test_random_full_duels() -> void:
	var lineups: Array = [
		[["graveyard_shift", "neon_rain", "last_train", "snow_blind", "mayday"], "snow_blind"],
		[["frostbite", "glacier", "polar_night", "open_channel", "service_ribbon"], "polar_night"],
		[["city_never_sleeps", "null_glyph", "flare_up", "chrome_tiger", "gold_leaf"], "null_glyph"],
		[["honor_roll", "key_fragment", "frostbite", "service_ribbon", "gold_leaf"], "key_fragment"],
		[["dead_air", "mayday", "open_channel", "flare_up", "graveyard_shift"], "dead_air"],
	]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var mismatches: int = 0
	var bad_scores: int = 0
	var bad_events: int = 0
	for game: int in 60:
		rng.seed = 1000 + game
		var a: Array = lineups[rng.randi_range(0, lineups.size() - 1)]
		var b: Array = lineups[rng.randi_range(0, lineups.size() - 1)]
		var bal: BalanceConfig = BalanceConfig.new()
		bal.chain_captures = game % 3 == 0
		var state: WallState = WallState.new_match(_typed(a[0]), _cards[StringName(a[1])], _typed(b[0]),
				_cards[StringName(b[1])], WallState.coin_flip(game), bal, RulesOptions.new(), _triptychs)
		while not state.is_game_over():
			var moves: Array[Dictionary] = WallRules.legal_moves(state)
			var m: Dictionary = moves[rng.randi_range(0, moves.size() - 1)]
			var p: int = state.to_move
			var pv: PlacementResult = WallRules.preview(state, p, m["card"], m["slot"], m["copy_from"])
			var r: PlacementResult = WallRules.place(state, p, m["card"], m["slot"], m["copy_from"])
			if not r.ok or not Fx.same(pv.placement_part(), r.placement_part()):
				mismatches += 1
			var flips: int = r.captured.size()
			for s: Dictionary in r.springs:
				flips += (s["captured"] as Array).size()
			if r.events.filter(func(e: Dictionary) -> bool: return e["type"] == &"captured").size() != flips:
				bad_events += 1
		# Points: 10 cards + (signature_value - 1) per Signature + Triptych bonuses.
		var res: Dictionary = WallRules.final_result(state)
		var expect_total: int = 10 + 2 * (bal.signature_value - 1) \
				+ bal.triptych_bonus * ((res["triptychs"][0] as Array).size() + (res["triptychs"][1] as Array).size())
		if res["score"][0] + res["score"][1] != expect_total or state.placements != 10:
			bad_scores += 1
		for slot: StringName in state.cells:
			if (state.cells[slot] as PlacedCard).face_down or (state.cells[slot] as PlacedCard).spring_pending:
				bad_scores += 1
	assert_eq(mismatches, 0, "preview == place on every random move")
	assert_eq(bad_scores, 0, "final scores add up, no face-down cards left")
	assert_eq(bad_events, 0, "captured events match the results")


func _typed(ids: Array) -> Array[CardData]:
	var out: Array[CardData] = []
	for id: String in ids:
		out.append(_cards[StringName(id)])
	return out


func _tempo_balance(bonus: int, tie: DataEnums.TieWinner) -> BalanceConfig:
	var b: BalanceConfig = BalanceConfig.new()
	b.first_player_bonus = bonus
	b.tie_winner = tie
	return b


## Tempo (cc06 Proposal A, decided 2026-11-04): the first player's score includes
## first_player_bonus, public and full, from the first placement on.
func test_tempo_bonus_in_score() -> void:
	assert_eq(BalanceConfig.new().first_player_bonus, 0, "class default off")
	var setup: Dictionary = {"first_player": "P2", "to_move": "P1", "board": [
		{"slot": "a1", "card": "gold_leaf", "lineup": "P1", "controller": "P1", "face_down": false, "signature": false},
		{"slot": "c3", "card": "snow_blind", "lineup": "P2", "controller": "P2", "face_down": true, "signature": true}]}
	var s: WallState = WallState.from_setup(setup, _cards, _tempo_balance(2, DataEnums.TieWinner.DRAW), RulesOptions.new(), _triptychs)
	assert_eq(WallRules.score(s, WallState.P2), 2 + 2, "first player (P2): Signature 2 + Tempo 2")
	assert_eq(WallRules.score(s, WallState.P2, false), 1 + 2, "public: face-down 1 + Tempo 2")
	assert_eq(WallRules.score(s, WallState.P1), 1, "second player: no bonus")
	assert_eq(WallRules.scores(s), [1, 4] as Array[int], "scores()")
	var empty: WallState = WallState.from_setup({"first_player": "P1", "to_move": "P1", "board": []}, _cards,
			_tempo_balance(2, DataEnums.TieWinner.DRAW))
	assert_eq(WallRules.scores(empty), [2, 0] as Array[int], "2-0 before anyone places")


func test_tempo_ties_are_draws() -> void:
	# 6-6 on the board, first player P1 with Tempo 2 -> 8-6, P1 wins; 4-8 board -> 6-8 P2 wins;
	# 4-6 board (P1 first) -> 6-6, a draw under DRAW, P1 under FIRST_PLAYER.
	var board: Array = []
	var ids: Array[String] = ["gold_leaf", "chrome_tiger", "mayday", "glacier", "frostbite", "flare_up", "neon_rain",
			"graveyard_shift", "service_ribbon", "open_channel"]
	var slots: Array[String] = ["a1", "a2", "a3", "b1", "b2", "b3", "b4", "c1", "c2", "c3"]
	for i: int in 10:
		var owner: String = "P1" if i < 4 else "P2"
		board.append({"slot": slots[i], "card": ids[i], "lineup": owner, "controller": owner, "face_down": false,
				"signature": false})
	var setup: Dictionary = {"first_player": "P1", "to_move": "P2", "board": board}
	var draw_rule: WallState = WallState.from_setup(setup, _cards, _tempo_balance(2, DataEnums.TieWinner.DRAW))
	var res: Dictionary = WallRules.final_result(draw_rule)
	assert_eq(res["score"], [6, 6], "4 cards + Tempo 2 vs 6 cards")
	assert_true(res["tie"], "level")
	assert_eq(res["winner"], WallState.NO_PLAYER, "DRAW: nobody wins")
	var first_rule: WallState = WallState.from_setup(setup, _cards, _tempo_balance(2, DataEnums.TieWinner.FIRST_PLAYER))
	assert_eq(WallRules.final_result(first_rule)["winner"], WallState.P1, "FIRST_PLAYER: the first player takes it")
	var no_bonus: WallState = WallState.from_setup(setup, _cards, _tempo_balance(0, DataEnums.TieWinner.DRAW))
	assert_eq(WallRules.final_result(no_bonus)["winner"], WallState.P2, "no Tempo: 4-6, P2 wins")
	setup["first_player"] = "P2"
	var p2_first: WallState = WallState.from_setup(setup, _cards, _tempo_balance(2, DataEnums.TieWinner.DRAW))
	assert_eq(WallRules.final_result(p2_first)["score"], [4, 8], "the bonus follows the first player")


## Clutch's behind-check counts the Tempo bonus (part of the real score): the second player is
## behind at 0-2 and gets Clutch on an empty wall.
func test_tempo_counts_for_clutch() -> void:
	var setup: Dictionary = {"first_player": "P1", "to_move": "P2", "board": []}
	for bonus: int in [0, 2]:
		var s: WallState = WallState.from_setup(setup, _cards, _tempo_balance(bonus, DataEnums.TieWinner.DRAW),
				RulesOptions.new(), _triptychs)
		assert_eq(WallRules.is_behind(s, WallState.P2), bonus > 0, "Tempo %d: P2 behind" % bonus)
		var r: PlacementResult = WallRules.place(s, WallState.P2, _cards[&"open_channel"], &"c3")
		assert_eq(r.clutch, bonus > 0, "Tempo %d: Clutch fires" % bonus)

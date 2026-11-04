# test_ai_matches.gd
# Purpose: cz09 AI full-match tests on the live content (CardDB): every level pairing plays legal,
#   finished matches that replay exactly from their log; the AI stays legal under the other §16.8
#   switch values (hand 4, rack swap, move-only Adrenaline with a cap, public held cards, hidden
#   counts, ready delay, health 4, hard end 12); a small ladder shows the Veteran is clearly the
#   stronger level; the Veteran's turn time stays inside the budget (printed; the sweep tool
#   tests/tools/ai_sweep.gd measures the full 216-game set).
# Dependencies: CzAI, CzAiArena, LoadoutRules, MatchState, RulesData, CardDB (autoload).
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

## A turn may take at most this long here in the test (2x the 75 ms target, so a busy CI
## machine does not flake; the sweep reports the real distribution).
const TURN_MS_LIMIT: float = 150.0

var _content: RulesData = null


func _data() -> RulesData:
	if _content == null:
		_content = RulesData.from_card_db(tree.root.get_node_or_null("CardDB"))
	return _content


func test_every_pairing_plays_legal_finished_matches() -> void:
	var pairs: Array = [[&"rookie", &"rookie"], [&"rookie", &"veteran"], [&"veteran", &"rookie"], [&"veteran", &"veteran"]]
	var route: int = 0
	for pair: Array in pairs:
		var r: Dictionary = CzAiArena.play(_data(), route % 3, CzAI.for_level(pair[0]), CzAI.for_level(pair[1]))
		route += 1
		var label: String = "%s vs %s" % [pair[0], pair[1]]
		var s: MatchState = r["state"]
		assert_eq(int(r["illegal"]), 0, "%s: no illegal action" % label)
		assert_true(s.is_over(), "%s: the match ends (%s after round %d)" % [label, r["cause"], r["rounds"]])
		var errors: Array = []
		var again: MatchState = LoadoutRules.replay_of(s, errors)
		assert_true(errors.is_empty() and again.fingerprint() == s.fingerprint(), "%s: the log replays exactly %s" % [label, errors])
		assert_true(float(r["max_turn_ms"]) <= TURN_MS_LIMIT, "%s: slowest AI turn %.1f ms" % [label, r["max_turn_ms"]])
		print("     %s: %s by %s in round %d, %d actions, slowest turn %.1f ms" % [label,
				"P%d wins" % (int(r["winner"]) + 1) if int(r["winner"]) >= 0 else "draw", r["cause"], r["rounds"],
				r["actions"], r["max_turn_ms"]])


func test_switch_values_stay_legal() -> void:
	var sets: Array[Dictionary] = [
		{"hand_size": 4, "supply_drop_cost": 3, "hold_limit": 1, "hold_looted": true},
		{"packing_rule": DataEnums.PackingRule.RACK_SWAP, "adrenaline_mode": DataEnums.AdrenalineMode.MOVE_ONLY,
			"adrenaline_cap_per_turn": 2, "ditch_per_turn": 0},
		{"held_cards_public": true, "hits_on_top_public": false, "loadout_count_public": false,
			"down_enabled": false, "bounty_holder_loses_cover": true, "supply_drop_ready_delay": 1,
			"health": 4, "zone_hard_end_card": 12, "crate_cost": 0},
	]
	var n: int = 0
	for overrides: Dictionary in sets:
		var errors: Array = []
		var content: RulesData = _data().with_balance(overrides, errors)
		assert_true(errors.is_empty(), "overrides: %s" % [errors])
		for order: Array in [[&"veteran", &"rookie"], [&"rookie", &"veteran"]]:
			var r: Dictionary = CzAiArena.play(content, n % 3, CzAI.for_level(order[0]), CzAI.for_level(order[1]))
			n += 1
			assert_eq(int(r["illegal"]), 0, "%s %s vs %s: no illegal action" % [overrides.keys(), order[0], order[1]])
			assert_true((r["state"] as MatchState).is_over(), "%s: the match ends" % [overrides.keys()])


## Ladder: Veteran vs Rookie from both seats over 12 drop pairs on all routes (24 games).
func test_veteran_is_clearly_stronger_than_rookie() -> void:
	var outer: Array[String] = ["docks", "farmstead", "quarry", "radio_hill", "motel", "rail_yard"]
	var vet_wins: int = 0
	var games: int = 0
	for i: int in 12:
		var a: String = outer[i % 6]
		var b: String = outer[(i * 5 + 2) % 6]
		for vet_seat: int in 2:
			var p1: CzAI = CzAI.for_level(&"veteran" if vet_seat == 0 else &"rookie")
			var p2: CzAI = CzAI.for_level(&"rookie" if vet_seat == 0 else &"veteran")
			var r: Dictionary = CzAiArena.play(_data(), i % 3, p1, p2, {0: a, 1: b})
			games += 1
			if int(r["winner"]) == vet_seat:
				vet_wins += 1
	print("     ladder: Veteran won %d of %d against Rookie" % [vet_wins, games])
	assert_true(vet_wins * 100 >= games * 60, "Veteran wins at least 60%% (%d/%d)" % [vet_wins, games])

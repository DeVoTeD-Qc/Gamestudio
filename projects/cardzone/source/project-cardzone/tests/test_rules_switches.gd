# test_rules_switches.gd
# Purpose: Rules cases for the cz07b first-player balance switches (BalanceConfig.SWITCHES):
#   both are off by default and change nothing then (snapshot, hash, health, legal shots);
#   p2_start_health_bonus = 1 gives P2 one more health at the start and as its heal cap (S4,
#   R15) and the view shows it; no_shooting_round1 = true makes shoot and frag illegal in
#   round 1 only (LoadoutRules.ERR_NO_SHOOTING_ROUND1), and legal_actions lists neither.
# Dependencies: LoadoutRules, MatchState, MatchView, BalanceConfig, tests/test_rules_fixtures.gd.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const Fx: GDScript = preload("res://tests/test_rules_fixtures.gd")


## A play-phase fixture: P1 at Radio Hill with a Hunting Rifle (RNG 1) in the line and a Frag in
## hand, P2 next door at Quarry. `balance` is JSON-style ({"no_shooting_round1": true}).
func _duel(round_number: int, balance: Dictionary, p1: Dictionary = {}, p2: Dictionary = {}) -> MatchState:
	var players: Dictionary = {
		"P1": {"area": "radio_hill", "health": 5, "loadout": ["SCV", "SCV", "DSH", "DCK", "SCV", "DSH"],
				"hand": ["FRG", "HIT"], "line": ["HRF"], "move": 0, "search": 0},
		"P2": {"area": "quarry", "health": 5, "loadout": ["SCV", "SCV", "SCV", "DCK", "DSH", "DSH", "P9"],
				"hand": [], "line": [], "move": 0, "search": 0},
	}
	(players["P1"] as Dictionary).merge(p1, true)
	(players["P2"] as Dictionary).merge(p2, true)
	var setup: Dictionary = {"round": round_number, "zone_card": round_number, "route": "A", "active": "P1",
			"balance": balance, "players": players}
	var errors: Array = []
	var s: MatchState = MatchState.from_fixture(setup, Fx.content(), Fx.code_map(), errors)
	assert_eq(errors, [], "fixture builds")
	return s


func _types(list: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for a: Dictionary in list:
		if not out.has(String(a["type"])):
			out.append(String(a["type"]))
	return out


# --- Defaults ------------------------------------------------------------------------------

func test_switches_are_off_by_default_and_leave_snapshot_and_hash() -> void:
	var b: BalanceConfig = BalanceConfig.new()
	assert_eq([b.p2_start_health_bonus, b.no_shooting_round1], [0, false], "both off on new()")
	var live: BalanceConfig = tree.root.get_node("CardDB").get_balance()
	assert_eq([live.p2_start_health_bonus, live.no_shooting_round1], [0, false], "both off in balance.tres")
	assert_eq(BalanceConfig.switch_keys(), [&"p2_start_health_bonus", &"no_shooting_round1"], "switch keys")
	assert_eq(BalanceConfig.default_value(&"p2_start_health_bonus"), 0, "bonus default")
	assert_eq(BalanceConfig.default_value(&"no_shooting_round1"), false, "round-1 default")
	assert_eq(BalanceConfig.allowed_values(&"p2_start_health_bonus"), [0, 1], "bonus allowed 0, 1")
	assert_eq(BalanceConfig.allowed_values(&"no_shooting_round1"), [false, true], "round-1 allowed false, true")
	assert_false(BalanceConfig.tunable_keys().has(&"no_shooting_round1"), "switches aren't §16.8 keys")
	var snap: Dictionary = b.snapshot()
	var hash_off: String = b.tunables_hash()
	assert_false(snap.has("p2_start_health_bonus") or snap.has("no_shooting_round1"), "off switches stay out of the snapshot")
	assert_false(b.set_tunable(&"p2_start_health_bonus", 2), "bonus 2 refused")
	assert_false(b.set_tunable(&"no_shooting_round1", 1), "int for the bool switch refused")
	assert_true(b.set_tunable(&"p2_start_health_bonus", 1), "bonus 1 accepted")
	assert_true(b.set_tunable(&"no_shooting_round1", true), "round-1 switch accepted")
	assert_eq([b.snapshot()["p2_start_health_bonus"], b.snapshot()["no_shooting_round1"]], [1, true], "on switches are snapshotted")
	assert_true(b.tunables_hash() != hash_off, "hash follows a switch")
	assert_eq([b.start_health(0), b.start_health(1)], [5, 6], "start health with the bonus")
	b.set_tunable(&"p2_start_health_bonus", 0)
	b.set_tunable(&"no_shooting_round1", false)
	assert_eq(b.tunables_hash(), hash_off, "back off: the same hash as before")
	var errors: Array = []
	Fx.content().with_balance({"no_shooting_round1": true, "p2_start_health_bonus": 1}, errors)
	assert_eq(errors, [], "with_balance takes both switches")


func test_defaults_allow_round1_shots() -> void:
	var s: MatchState = _duel(1, {})
	var shot: Dictionary = {"type": "shoot", "seat": 0, "weapon": s.seats[0].line[0], "target": 1}
	assert_true(LoadoutRules.is_legal(s, shot), "switch off: a round-1 shot is legal")
	assert_true(LoadoutRules.is_legal(s, {"type": "frag", "seat": 0, "area": "quarry"}), "switch off: a round-1 Frag is legal")
	var m: MatchState = MatchState.new_match(Fx.content(), DataEnums.Route.A)
	assert_eq([m.health_of(0), m.health_of(1)], [5, 5], "switch off: equal health")


# --- p2_start_health_bonus -----------------------------------------------------------------

func test_p2_bonus_gives_p2_one_more_health_at_the_start() -> void:
	var content: RulesData = Fx.content().with_balance({"p2_start_health_bonus": 1})
	var s: MatchState = MatchState.new_match(content, DataEnums.Route.B)
	assert_eq([s.health_of(0), s.health_of(1)], [5, 6], "P1 5, P2 6")
	assert_true(LoadoutRules.apply(s, {"type": "drop", "seat": 1, "area": "docks"}).ok, "P2 drops")
	assert_true(LoadoutRules.apply(s, {"type": "drop", "seat": 0, "area": "motel"}).ok, "P1 drops")
	assert_eq(LoadoutRules.view(s, 0)["opponent"]["health"], 6, "P1 sees P2's 6 health")
	assert_eq(LoadoutRules.view(s, 1)["me"]["health"], 6, "P2 sees its own 6")
	# The log replays to the same state (the bonus is in the origin's balance snapshot).
	var errors: Array = []
	var again: MatchState = LoadoutRules.replay_of(s, errors)
	assert_eq(errors, [], "replays")
	assert_eq(again.fingerprint(), s.fingerprint(), "replay equals the match")


func test_p2_bonus_raises_p2_heal_cap_only() -> void:
	# Both seats at 5 health, a Bandage (Heal 1) in hand and a Hit in the line to return.
	var on: Dictionary = {"no_shooting_round1": false, "p2_start_health_bonus": 1}
	var s: MatchState = _duel(3, on, {}, {"hand": ["BND"], "line": ["HIT"]})
	s.active = 1
	var r: ActionResult = LoadoutRules.apply(s, {"type": "play", "seat": 1, "card": s.seats[1].hand[0]})
	assert_true(r.ok, "P2 plays Bandage")
	assert_eq(s.health_of(1), 6, "P2 heals to 6 (its start health) with the bonus")
	var p1: MatchState = _duel(3, on, {"hand": ["BND"], "line": ["HIT"]})
	assert_true(LoadoutRules.apply(p1, {"type": "play", "seat": 0, "card": p1.seats[0].hand[0]}).ok, "P1 plays Bandage")
	assert_eq(p1.health_of(0), 5, "P1 stays capped at 5")
	var off: MatchState = _duel(3, {}, {}, {"hand": ["BND"], "line": ["HIT"]})
	off.active = 1
	LoadoutRules.apply(off, {"type": "play", "seat": 1, "card": off.seats[1].hand[0]})
	assert_eq(off.health_of(1), 5, "switch off: P2 capped at 5")


# --- no_shooting_round1 --------------------------------------------------------------------

func test_round1_shoot_and_frag_are_illegal_with_the_switch() -> void:
	var s: MatchState = _duel(1, {"no_shooting_round1": true})
	var before: String = s.fingerprint()
	var shot: Dictionary = {"type": "shoot", "seat": 0, "weapon": s.seats[0].line[0], "target": 1}
	var r: ActionResult = LoadoutRules.apply(s, shot)
	assert_false(r.ok, "round-1 shot rejected")
	assert_eq(r.error, LoadoutRules.ERR_NO_SHOOTING_ROUND1, "error code no_shooting_round1")
	assert_eq(String(LoadoutRules.ERR_NO_SHOOTING_ROUND1), "no_shooting_round1", "error text")
	var f: ActionResult = LoadoutRules.apply(s, {"type": "frag", "seat": 0, "area": "quarry"})
	assert_eq([f.ok, f.error], [false, LoadoutRules.ERR_NO_SHOOTING_ROUND1], "round-1 Frag rejected")
	assert_eq(s.fingerprint(), before, "rejected actions leave the state untouched")
	assert_false(LoadoutRules.apply_fast(s, shot), "the fast path refuses it too")
	assert_false(LoadoutRules.shooting_open(s), "shooting closed")
	var p: Dictionary = LoadoutRules.preview_shot(s, 0, s.seats[0].line[0], 1)
	assert_eq([p["legal"], p["error"]], [false, LoadoutRules.ERR_NO_SHOOTING_ROUND1], "shot preview says why")
	var types: Array[String] = _types(LoadoutRules.legal_actions(s))
	assert_false(types.has("shoot") or types.has("frag"), "legal_actions lists no shoot or frag in round 1: %s" % [types])
	assert_true(types.has("play") and types.has("end_turn"), "other actions stay legal")


func test_round2_shots_are_legal_with_the_switch() -> void:
	var s: MatchState = _duel(2, {"no_shooting_round1": true})
	assert_true(LoadoutRules.shooting_open(s), "shooting open from round 2")
	var types: Array[String] = _types(LoadoutRules.legal_actions(s))
	assert_true(types.has("shoot") and types.has("frag"), "round 2 lists shoot and frag")
	var r: ActionResult = LoadoutRules.apply(s, {"type": "shoot", "seat": 0, "weapon": s.seats[0].line[0], "target": 1})
	assert_true(r.ok, "round-2 shot legal")


func test_round1_switch_in_a_full_match_from_new_match() -> void:
	# The switch holds for both seats' round-1 turns and opens at the round-2 start.
	var content: RulesData = Fx.content().with_balance({"no_shooting_round1": true})
	var s: MatchState = MatchState.new_match(content, DataEnums.Route.A)
	LoadoutRules.apply(s, {"type": "drop", "seat": 1, "area": "radio_hill"})
	LoadoutRules.apply(s, {"type": "drop", "seat": 0, "area": "radio_hill"})
	var seen_round1: int = 0
	while s.round_number == 1 and not s.is_over():
		for a: Dictionary in LoadoutRules.legal_actions(s):
			assert_false(String(a["type"]) in ["shoot", "frag"], "no shot listed in round 1")
		seen_round1 += 1
		LoadoutRules.apply(s, {"type": "end_turn", "seat": s.active, "hold": []})
	assert_eq(seen_round1, 2, "both round-1 turns checked")
	assert_true(LoadoutRules.shooting_open(s), "open in round 2")

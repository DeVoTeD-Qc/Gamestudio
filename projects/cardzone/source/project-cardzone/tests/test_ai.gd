# test_ai.gd
# Purpose: cz09 AI unit tests: the factory and interface, the fairness wall (CzBelief: two states
#   that differ only in the opponent's hidden cards give the same belief world and the same move,
#   at every decision of real matches, Brace prompts and segment anchors included), determinism
#   (the same state gives the same move from any instance, mid-turn too; choose_action never
#   changes the state), the belief world's public card count, and the Rookie's sim rules (greedy
#   Brace, Hold, drop) on hand-built states.
#   Full matches, switches, the ladder and the timing budget are in test_ai_matches.gd.
# Dependencies: CzAI, CzRookieAI, CzVeteranAI, CzBelief, CzSim, CzAiArena, LoadoutRules,
#   MatchState, RulesData, CardDB (autoload), tests/test_rules_soak.gd (scramble_private).
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const Soak: GDScript = preload("res://tests/test_rules_soak.gd")

var _content: RulesData = null


func _data() -> RulesData:
	if _content == null:
		var db: Node = tree.root.get_node_or_null("CardDB")
		_content = RulesData.from_card_db(db)
	return _content


# --- Interface -----------------------------------------------------------------------------

func test_factory_levels() -> void:
	var r: CzAI = CzAI.for_level(&"rookie", 7)
	var v: CzAI = CzAI.for_level(&"veteran", 7)
	assert_true(r is CzRookieAI, "rookie factory")
	assert_true(v is CzVeteranAI, "veteran factory")
	assert_eq(r.level, &"rookie", "rookie level name")
	assert_eq(v.level, &"veteran", "veteran level name")
	assert_eq(v.seed_value, 7, "seed kept")
	assert_true(CzAI.for_level(&"nonsense") is CzRookieAI, "unknown level falls back to Rookie")


func test_no_action_when_not_deciding() -> void:
	var s: MatchState = MatchState.new_match(_data(), DataEnums.Route.A)
	var ai: CzAI = CzAI.for_level(&"veteran")
	assert_eq(ai.choose_action(s, MatchState.P1), {}, "P1 does not act during P2's drop")
	var drop: Dictionary = ai.choose_action(s, MatchState.P2)
	assert_eq(String(drop.get("type", "")), "drop", "P2 drops first (S5)")
	assert_true(LoadoutRules.is_legal(s, drop), "the drop is legal (outer area)")


func test_drop_rule_is_pure_and_avoids_the_hot_drop() -> void:
	for level: StringName in CzAI.LEVELS:
		for route: int in [DataEnums.Route.A, DataEnums.Route.B, DataEnums.Route.C]:
			var s: MatchState = MatchState.new_match(_data(), route)
			var a1: Dictionary = CzAI.for_level(level).choose_action(s, MatchState.P2)
			var a2: Dictionary = CzAI.for_level(level, 99).choose_action(s, MatchState.P2)
			assert_eq(a1, a2, "%s drop on route %d is a pure function" % [level, route])
			LoadoutRules.apply(s, a1)
			var p1: Dictionary = CzAI.for_level(level).choose_action(s, MatchState.P1)
			assert_true(LoadoutRules.is_legal(s, p1), "%s P1 drop legal" % level)
			assert_true(String(p1["area"]) != String(a1["area"]), "%s P1 does not drop on P2 (route %d)" % [level, route])


# --- Fairness wall -----------------------------------------------------------------------

## P18 + the CallingCard RivalAI test: at every decision of real matches, a copy whose opponent
## private cards are changed and reordered (and whose segment anchor is changed the same way)
## gives the same belief world and the same action, for both levels.
func test_hidden_opponent_cards_never_change_the_move() -> void:
	var checks: int = 0
	var problems: Array[String] = []
	for g: int in 3:
		var s: MatchState = MatchState.new_match(_data(), g)
		var ais: Array[CzAI] = [CzAI.for_level(&"veteran"), CzAI.for_level(&"rookie")]
		if g == 1:
			ais = [CzAI.for_level(&"rookie"), CzAI.for_level(&"veteran")]
		var n: int = 0
		while not s.is_over() and n < 700:
			n += 1
			var seat: int = s.deciding_seat()
			var a: Dictionary = ais[seat].choose_action(s, seat)
			if n % 4 == 0 or not s.pending.is_empty():
				var other: MatchState = _hidden_variant(s, 1 - seat)
				var w1: String = CzBelief.world(s, seat).fingerprint()
				var w2: String = CzBelief.world(other, seat).fingerprint()
				var fresh: CzAI = CzAI.for_level(ais[seat].level)
				var b: Dictionary = fresh.choose_action(other, seat)
				checks += 1
				if w1 != w2:
					problems.append("game %d action %d: belief world reads hidden cards (%s)" % [g, n,
							Soak.first_difference(JSON.parse_string(w1), JSON.parse_string(w2), "world")])
				if str(a) != str(b):
					problems.append("game %d action %d (%s): %s vs %s" % [g, n, ais[seat].level, a, b])
			LoadoutRules.apply(s, a)
			if problems.size() > 5:
				break
	print("     fairness: %d decisions checked" % checks)
	assert_true(checks > 100, "enough decisions checked (%d)" % checks)
	assert_eq(problems.size(), 0, "moves depend on hidden cards: %s" % [problems.slice(0, 5)])


## A hand-built pair (CallingCard style): the opponent holds a Plate Vest on top in one state and
## a Scavenge in the other; everything public is the same. Same world, same move.
func test_held_card_identity_is_not_read() -> void:
	var s: MatchState = _mid_game_state(DataEnums.Route.B, 4)
	var me: int = s.active
	var opp: int = 1 - me
	var other: MatchState = s.clone()
	var idx: int = -1
	for i: int in s.seats[opp].loadout.size():
		if not s.is_hit(s.seats[opp].loadout[i]):
			idx = i
			break
	assert_true(idx >= 0, "the opponent has a private card")
	var inst: int = s.seats[opp].loadout[idx]
	for copy: MatchState in [s, other]:
		copy.seats[opp].held.assign([inst])
	s.defs[inst] = &"plate_vest"
	other.defs[inst] = &"scavenge"
	for level: StringName in CzAI.LEVELS:
		var a: Dictionary = CzAI.for_level(level).choose_action(s, me)
		var b: Dictionary = CzAI.for_level(level).choose_action(other, me)
		assert_eq(str(a), str(b), "%s: the held card's identity does not change the move" % level)
	assert_eq(CzBelief.world(s, me).fingerprint(), CzBelief.world(other, me).fingerprint(),
			"identical belief worlds")


## The guess holds exactly the opponent's real card multiset (it is derivable from public facts
## when both start from the Standard pack) and matches every public count.
func test_belief_world_matches_public_counts() -> void:
	var problems: Array[String] = []
	var s: MatchState = MatchState.new_match(_data(), DataEnums.Route.C)
	var ais: Array[CzAI] = [CzAI.for_level(&"rookie"), CzAI.for_level(&"rookie")]
	var n: int = 0
	var checked: int = 0
	while not s.is_over() and n < 600:
		n += 1
		var seat: int = s.deciding_seat()
		if n % 3 == 0:
			checked += 1
			var opp: int = 1 - seat
			var w: MatchState = CzBelief.world(s, seat)
			var real: SeatState = s.seats[opp]
			var guess: SeatState = w.seats[opp]
			if _ids(s, real.loadout + real.hand) != _ids(w, guess.loadout + guess.hand):
				problems.append("action %d: multiset %s vs %s" % [n, _ids(s, real.loadout + real.hand), _ids(w, guess.loadout + guess.hand)])
			for pair: Array in [[real.loadout.size(), guess.loadout.size(), "loadout"], [real.hand.size(), guess.hand.size(), "hand"],
					[real.held.size(), guess.held.size(), "held"], [s.next_draw_hits(opp), w.next_draw_hits(opp), "next draw Hits"],
					[s.is_down(opp), w.is_down(opp), "Down"], [s.health_of(opp), w.health_of(opp), "health"]]:
				if pair[0] != pair[1]:
					problems.append("action %d: %s %s vs %s" % [n, pair[2], pair[0], pair[1]])
			if w.seats[seat].to_dict() != s.seats[seat].to_dict():
				problems.append("action %d: own seat changed in the belief world" % n)
		LoadoutRules.apply(s, ais[seat].choose_action(s, seat))
		if problems.size() > 5:
			break
	assert_true(checked > 30, "checked %d states" % checked)
	assert_eq(problems.size(), 0, "belief counts: %s" % [problems.slice(0, 5)])


# --- Determinism ---------------------------------------------------------------------------

## Same state, same move: a fresh instance asked at any decision (mid-turn, inside a segment)
## agrees with the instance that has been playing; a second ask agrees too.
func test_same_state_same_move_any_instance() -> void:
	var problems: Array[String] = []
	var s: MatchState = MatchState.new_match(_data(), DataEnums.Route.A)
	var ais: Array[CzAI] = [CzAI.for_level(&"veteran", 1), CzAI.for_level(&"veteran", 2)]
	var n: int = 0
	while not s.is_over() and n < 700:
		n += 1
		var seat: int = s.deciding_seat()
		var a: Dictionary = ais[seat].choose_action(s, seat)
		if n % 2 == 0:
			var b: Dictionary = CzAI.for_level(&"veteran", 3).choose_action(s, seat)
			var c: Dictionary = ais[seat].choose_action(s, seat)
			if str(a) != str(b) or str(a) != str(c):
				problems.append("action %d: %s / fresh %s / again %s" % [n, a, b, c])
		LoadoutRules.apply(s, a)
		if problems.size() > 5:
			break
	assert_true(s.is_over(), "match finished")
	assert_eq(problems.size(), 0, "nondeterministic: %s" % [problems.slice(0, 5)])


func test_choose_action_never_changes_the_state() -> void:
	var s: MatchState = _mid_game_state(DataEnums.Route.A, 5)
	for i: int in 6:
		var before: String = s.fingerprint()
		var log_size: int = s.actions.size()
		var undo_size: int = s.undo_stack.size()
		var seat: int = s.deciding_seat()
		var a: Dictionary = CzAI.for_level(&"veteran").choose_action(s, seat)
		CzAI.for_level(&"rookie").choose_action(s, seat)
		assert_eq(s.fingerprint(), before, "state unchanged")
		assert_eq(s.actions.size(), log_size, "log unchanged")
		assert_eq(s.undo_stack.size(), undo_size, "undo snapshots unchanged")
		LoadoutRules.apply(s, a)


func test_match_replays_identically() -> void:
	var r1: Dictionary = CzAiArena.play(_data(), DataEnums.Route.B, CzAI.for_level(&"veteran"), CzAI.for_level(&"rookie"))
	var r2: Dictionary = CzAiArena.play(_data(), DataEnums.Route.B, CzAI.for_level(&"veteran"), CzAI.for_level(&"rookie"))
	var s1: MatchState = r1["state"]
	var s2: MatchState = r2["state"]
	assert_eq(s1.actions.size(), s2.actions.size(), "same number of actions")
	assert_eq(JSON.stringify(s1.actions), JSON.stringify(s2.actions), "same action log")
	assert_eq(s1.fingerprint(), s2.fingerprint(), "same end state")
	# And a saved, reloaded mid-match state gives the same next move (undo snapshots rebuilt).
	var mid: MatchState = _mid_game_state(DataEnums.Route.B, 6)
	var errors: Array = []
	var loaded: MatchState = MatchState.load_text(mid.save_text(), _data(), errors)
	assert_true(errors.is_empty(), "reload: %s" % [errors])
	var seat: int = mid.deciding_seat()
	assert_eq(str(CzAI.for_level(&"veteran").choose_action(loaded, seat)),
			str(CzAI.for_level(&"veteran").choose_action(mid, seat)), "same move after save and load")


# --- Rookie rules (sim policy) ---------------------------------------------------------------

func test_rookie_braces_highest_first_until_covered() -> void:
	var s: MatchState = _fixture({"active": "P1", "players": {
		"P1": {"area": "quarry", "health": 5, "loadout": ["scavenge", "dash"], "line": ["pump_shotgun"]},
		"P2": {"area": "quarry", "health": 5, "loadout": ["duck", "plate_vest", "smoke_grenade", "scavenge", "dash", "duck"]}}})
	var r: ActionResult = LoadoutRules.apply(s, {"type": "shoot", "seat": 0, "weapon": s.seats[0].line[0], "target": 1})
	assert_true(r.ok, "shot declared: %s" % r.error)
	var a: Dictionary = CzAI.for_level(&"rookie").choose_action(s, MatchState.P2)
	assert_eq(String(a["type"]), "brace", "defender braces")
	var ids: Array = []
	for x: Variant in a["cards"]:
		ids.append(String(s.card_id(int(x))))
	# Damage 3 (same area, no Cover): Plate Vest 2 then Smoke 2 covers it; the Ducks stay.
	assert_eq(ids, ["plate_vest", "smoke_grenade"], "highest Brace first until the damage is covered")
	assert_true(LoadoutRules.is_legal(s, a), "legal brace")
	var v: Dictionary = CzAI.for_level(&"veteran").choose_action(s, MatchState.P2)
	assert_true(LoadoutRules.is_legal(s, v), "Veteran's brace is legal")


func test_rookie_holds_brace_cards_and_ends_turn() -> void:
	var s: MatchState = _fixture({"active": "P1", "players": {
		"P1": {"area": "docks", "health": 5, "loadout": [], "hand": ["duck", "plate_vest", "smoke_grenade", "scavenge"]},
		"P2": {"area": "motel", "health": 5, "loadout": ["scavenge"]}}})
	var ai: CzAI = CzAI.for_level(&"rookie")
	var a: Dictionary = ai.choose_action(s, MatchState.P1)
	var guard: int = 0
	while String(a["type"]) != "end_turn" and guard < 20:
		guard += 1
		assert_true(LoadoutRules.is_legal(s, a), "legal: %s" % a)
		LoadoutRules.apply(s, a)
		a = ai.choose_action(s, MatchState.P1)
	assert_eq(String(a["type"]), "end_turn", "turn ends")
	assert_true(LoadoutRules.is_legal(s, a), "legal end_turn with holds")
	# Sim rule: hold the hand's Brace cards, highest first, up to hold_limit.
	var braces: Array[int] = []
	for inst: int in s.seats[0].hand:
		if s.def_of(inst).brace > 0:
			braces.append(inst)
	braces.sort_custom(func(x: int, y: int) -> bool:
		var bx: int = s.def_of(x).brace
		var by: int = s.def_of(y).brace
		return bx > by if bx != by else s.seats[0].hand.find(x) < s.seats[0].hand.find(y))
	var expected: Array = braces.slice(0, s.data.balance.hold_limit)
	assert_eq(str(a["hold"]), str(expected), "holds the Brace cards highest first")
	assert_true(s.seats[0].hand.has(_find(s, 0, &"scavenge")) == false, "the Scavenge (no Brace) was played")


func test_veteran_takes_a_lethal_shot() -> void:
	var s: MatchState = _fixture({"active": "P1", "players": {
		"P1": {"area": "quarry", "health": 5, "loadout": ["scavenge"], "hand": ["pump_shotgun", "dash", "scavenge"]},
		"P2": {"area": "quarry", "health": 1, "loadout": ["scavenge", "dash", "scavenge", "dash", "scavenge"]}}})
	var ai: CzAI = CzAI.for_level(&"veteran")
	var guard: int = 0
	while not s.is_over() and s.active == MatchState.P1 and guard < 20:
		guard += 1
		var seat: int = s.deciding_seat()
		var a: Dictionary = ai.choose_action(s, seat) if seat == MatchState.P1 else CzAI.for_level(&"rookie").choose_action(s, seat)
		assert_true(LoadoutRules.is_legal(s, a), "legal: %s" % a)
		LoadoutRules.apply(s, a)
	assert_true(s.is_over() and int(s.match_end.get("winner", -1)) == MatchState.P1, "Veteran finishes a 1-health target in its area")


# --- Helpers -----------------------------------------------------------------------------

## A state where an opponent's private fields (and those in every undo snapshot, so the segment
## anchor too) are changed and reordered; everything public stays.
func _hidden_variant(s: MatchState, opp: int) -> MatchState:
	var other: MatchState = Soak.scramble_private(s, opp)
	for snap: Dictionary in other.undo_stack:
		var tmp: MatchState = MatchState.new()
		tmp.data = s.data
		tmp.load_dict(snap["state"])
		snap["state"] = Soak.scramble_private(tmp, opp).to_dict()
	return other


## Rookie vs Rookie from the drop until `round` starts and it is P1's turn (a real state, with
## a log and undo snapshots).
func _mid_game_state(route: int, round_no: int) -> MatchState:
	var s: MatchState = MatchState.new_match(_data(), route)
	var ais: Array[CzAI] = [CzAI.for_level(&"rookie"), CzAI.for_level(&"rookie")]
	while not s.is_over() and (s.round_number < round_no or s.active != MatchState.P1 or not s.pending.is_empty()):
		var seat: int = s.deciding_seat()
		LoadoutRules.apply(s, ais[seat].choose_action(s, seat))
	# One play into the turn, so there is an undo snapshot (a segment anchor).
	if not s.is_over():
		var seat2: int = s.deciding_seat()
		LoadoutRules.apply(s, ais[seat2].choose_action(s, seat2))
	return s


func _fixture(setup: Dictionary) -> MatchState:
	var errors: Array = []
	var s: MatchState = MatchState.from_fixture(setup, _data(), {}, errors)
	assert_true(errors.is_empty(), "fixture: %s" % [errors])
	return s


static func _find(s: MatchState, seat: int, id: StringName) -> int:
	for inst: int in s.seats[seat].hand + s.seats[seat].line:
		if s.card_id(inst) == id:
			return inst
	return 0


## Sorted card ids of non-Hit cards (attachments included).
static func _ids(s: MatchState, list: Array) -> Array:
	var out: Array = []
	for x: Variant in list:
		var inst: int = int(x)
		if s.is_hit(inst):
			continue
		out.append(String(s.card_id(inst)))
		for att: int in s.attachments_of(inst):
			out.append(String(s.card_id(att)))
	out.sort()
	return out

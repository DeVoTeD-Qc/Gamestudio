# test_rules.gd
# Purpose: Unit tests for the rules engine API around the QA cases: a full match from new_match
#   (drop, draw, round start) replays exactly from its action list; legal_actions only lists
#   legal actions; preview() equals apply(); undo stops at the U3 boundaries; events carry their
#   secret part only to the owner; views omit hidden fields; every §16.8 tunable is read from
#   the match's BalanceConfig copy (the live config can change without touching a match).
# Dependencies: LoadoutRules, MatchState, MatchView, RulesData, ActionResult,
#   tests/test_rules_fixtures.gd.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const Fx: GDScript = preload("res://tests/test_rules_fixtures.gd")


func _new_match(overrides: Dictionary = {}) -> MatchState:
	var content: RulesData = Fx.content().with_balance(overrides)
	var s: MatchState = MatchState.new_match(content, DataEnums.Route.B)
	LoadoutRules.apply(s, {"type": "drop", "seat": MatchState.P2, "area": "docks"})
	LoadoutRules.apply(s, {"type": "drop", "seat": MatchState.P1, "area": "docks"})
	return s


func test_new_match_drop_and_first_draw() -> void:
	var s: MatchState = MatchState.new_match(Fx.content(), DataEnums.Route.A)
	assert_eq(s.phase, MatchState.PHASE_DROP, "starts at the drop")
	assert_false(LoadoutRules.apply(s, {"type": "drop", "seat": MatchState.P1, "area": "motel"}).ok, "P2 drops first")
	assert_false(LoadoutRules.apply(s, {"type": "drop", "seat": MatchState.P2, "area": "old_town"}).ok, "never the Core")
	assert_true(LoadoutRules.apply(s, {"type": "drop", "seat": MatchState.P2, "area": "motel"}).ok, "P2 drops")
	var r: ActionResult = LoadoutRules.apply(s, {"type": "drop", "seat": MatchState.P1, "area": "motel"})
	assert_true(r.ok, "P1 hot-drops")
	assert_eq([s.round_number, s.zone_card, s.active, s.seats[0].hand.size()], [1, 1, 0, 5], "round 1, P1 holds 5")
	var types: Array[String] = r.event_types()
	assert_true(types.has("round_started") and types.has("zone_flipped") and types.has("drew"), "round-start events")
	assert_eq(s.actions.size(), 2, "both drops are logged (RQ-04)")


func test_events_hide_secrets_from_the_opponent() -> void:
	var s: MatchState = _new_match()
	var r: ActionResult = LoadoutRules.apply(s, {"type": "end_turn", "seat": 0, "hold": [s.seats[0].hand[3]]})
	assert_true(r.ok, "end turn with a hold")
	var mine: Array[Dictionary] = r.events_for(0)
	var theirs: Array[Dictionary] = r.events_for(1)
	var packed_mine: Dictionary = mine.filter(func(e: Dictionary) -> bool: return e["type"] == "packed")[0]
	var packed_theirs: Dictionary = theirs.filter(func(e: Dictionary) -> bool: return e["type"] == "packed")[0]
	assert_true(packed_mine.has("held") and packed_mine["held"].size() == 1, "the owner sees which card was held")
	assert_false(packed_theirs.has("held") or packed_theirs.has("hand_stowed"), "the opponent sees only counts (P2, P14)")
	assert_eq(packed_theirs["held_count"], 1, "held count is public (P3)")
	var drew_p2: Array = theirs.filter(func(e: Dictionary) -> bool: return e["type"] == "drew")
	assert_true(drew_p2.size() == 1 and drew_p2[0].has("cards"), "P2 sees their own draw")
	var drew_seen_by_p1: Array = mine.filter(func(e: Dictionary) -> bool: return e["type"] == "drew")
	assert_false(drew_seen_by_p1[0].has("cards"), "P1 doesn't see P2's draw")
	for e: Dictionary in mine + theirs:
		assert_false(e.has("secret") or e.has("secret_for"), "secret wrappers are removed")


func test_legal_actions_are_legal_and_preview_equals_apply() -> void:
	var s: MatchState = _new_match()
	var checked: int = 0
	for turn: int in 6:
		var legal: Array[Dictionary] = LoadoutRules.legal_actions(s)
		assert_false(legal.is_empty(), "something is always legal")
		for a: Dictionary in legal:
			var p: ActionResult = LoadoutRules.preview(s, a)
			var copy: MatchState = s.clone()
			var real: ActionResult = LoadoutRules.apply(copy, a)
			checked += 1
			if not (p.ok and real.ok and JSON.stringify(p.events) == JSON.stringify(real.events)):
				assert_true(false, "preview == apply for %s" % [a])
				return
		# Play everything playable, then end the turn holding nothing.
		var acted: bool = true
		while acted:
			acted = false
			for a: Dictionary in LoadoutRules.legal_actions(s):
				if a["type"] == "play":
					LoadoutRules.apply(s, a)
					acted = true
					break
		LoadoutRules.apply(s, {"type": "end_turn", "seat": s.active, "hold": []})
	assert_true(checked > 50, "checked %d legal actions" % checked)


func test_undo_boundaries() -> void:
	var s: MatchState = _new_match()
	var hand: Array[int] = s.seats[0].hand.duplicate()
	assert_false(LoadoutRules.apply(s, {"type": "undo", "seat": 0}).ok, "nothing to undo at turn start (U3)")
	var before: String = s.fingerprint()
	LoadoutRules.apply(s, {"type": "play", "seat": 0, "card": hand[0]})
	LoadoutRules.apply(s, {"type": "play", "seat": 0, "card": hand[1]})
	assert_true(LoadoutRules.apply(s, {"type": "undo", "seat": 0}).ok, "undo a play")
	assert_true(LoadoutRules.apply(s, {"type": "undo", "seat": 0}).ok, "undo another")
	assert_eq(s.fingerprint(), before, "exact state restored (U2)")
	assert_eq(s.actions.size(), 2, "undone actions leave the log")
	assert_false(LoadoutRules.apply(s, {"type": "undo", "seat": 1}).ok, "only the active seat undoes")
	LoadoutRules.apply(s, {"type": "end_turn", "seat": 0, "hold": []})
	assert_false(LoadoutRules.apply(s, {"type": "undo", "seat": 0}).ok, "end_turn commits (U3)")
	# A declared shot commits everything before it (fixture: P1 with an SMG in the line).
	var setup: Dictionary = {"round": 5, "zone_card": 5, "route": "A", "active": "P1",
		"players": {"P1": {"area": "quarry", "health": 5, "loadout": ["DSH"], "hand": ["DSH"], "line": ["SMG"]},
			"P2": {"area": "quarry", "health": 5, "loadout": ["SCV", "SCV", "SCV", "DCK", "DSH", "DSH", "P9", "SCV", "DCK", "DSH"]}}}
	var f: MatchState = MatchState.from_fixture(setup, Fx.content(), Fx.code_map())
	LoadoutRules.apply(f, {"type": "play", "seat": 0, "card": f.seats[0].hand[0]})
	LoadoutRules.apply(f, {"type": "shoot", "seat": 0, "weapon": f.seats[0].line[0], "target": 1})
	assert_false(LoadoutRules.apply(f, {"type": "undo", "seat": 0}).ok, "a shot commits (U3)")


func test_view_hides_private_fields() -> void:
	var s: MatchState = _new_match()
	var v: Dictionary = LoadoutRules.view(s, 1)
	assert_false(v["opponent"].has("hand") or v["opponent"].has("loadout") or v["opponent"].has("held_cards"),
			"opponent hand/loadout/held cards are left out (P1, P2, P9)")
	assert_eq(v["opponent"]["hand_count"], 5, "hand count is public (P8)")
	assert_true(v["me"].has("loadout"), "my own loadout is visible to me")
	var hidden: MatchState = _new_match({"hits_on_top_public": false, "loadout_count_public": false,
			"held_cards_public": false})
	var hv: Dictionary = LoadoutRules.view(hidden, 0)
	for key: String in ["next_draw_hits", "hand_hits", "loadout_count", "held_cards"]:
		assert_false(hv["opponent"].has(key), "%s omitted when hidden" % key)
	assert_true(hv["opponent"].has("down"), "Down always shows (P5, P16)")


func test_tunables_come_from_the_match_balance() -> void:
	var content: RulesData = Fx.content()
	var s: MatchState = MatchState.new_match(content.with_balance({"hand_size": 4, "health": 6,
			"pile_size_outer": 4, "pile_size_core": 3}), DataEnums.Route.C)
	assert_eq(s.seats[0].health.size(), 6, "health 6")
	assert_eq(s.pile_counts()[&"docks"][&"scrap_smg"], 4, "outer piles 4")
	assert_eq(s.pile_counts()[&"old_town"][&"assault_rifle"], 3, "core piles 3")
	LoadoutRules.apply(s, {"type": "drop", "seat": 1, "area": "quarry"})
	LoadoutRules.apply(s, {"type": "drop", "seat": 0, "area": "motel"})
	assert_eq(s.seats[0].hand.size(), 4, "hand 4")
	assert_eq(content.balance.hand_size, 5, "the shared content's balance is untouched")
	# The match keeps its own copy: changing a config afterwards doesn't change the match.
	var live: RulesData = content.with_balance()
	var m: MatchState = MatchState.new_match(live, DataEnums.Route.A)
	live.balance.set_tunable(&"health", 4)
	assert_eq(m.data.balance.health, 5, "a running match keeps its tunables")


func test_replay_of_a_full_scripted_match() -> void:
	var s: MatchState = _new_match()
	var guard: int = 0
	while not s.is_over() and guard < 400:
		guard += 1
		var legal: Array[Dictionary] = LoadoutRules.legal_actions(s)
		var pick: Dictionary = legal[0]
		for a: Dictionary in legal:  # deterministic: first shot, else first loot, else first play
			if a["type"] in ["shoot", "brace"]:
				pick = a
				break
			if a["type"] == "loot" and pick["type"] != "loot":
				pick = a
			elif a["type"] == "play" and not (pick["type"] in ["loot", "play"]):
				pick = a
		assert_true(LoadoutRules.apply(s, pick).ok, "legal action applies")
	assert_true(s.is_over(), "the match ends (hard end at the latest)")
	var again: MatchState = LoadoutRules.replay_of(s)
	assert_eq(again.fingerprint(), s.fingerprint(), "replay is exact")
	var errors: Array = []
	var restored: MatchState = MatchState.load_text(s.save_text(), s.data, errors)
	assert_true(restored != null and errors.is_empty(), "save text loads: %s" % [errors])
	if restored != null:
		assert_eq(restored.fingerprint(), s.fingerprint(), "save text (origin + actions) restores the match")

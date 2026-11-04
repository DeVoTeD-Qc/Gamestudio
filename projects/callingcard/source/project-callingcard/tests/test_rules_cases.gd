# test_rules_cases.gd
# Purpose: Runs every case in QA's rules-test-cases.json (cc04, 103 cases) against the rules engine
#   (scripts/rules). Each case reports PASS/FAIL by id; any failure fails the suite. BW-100
#   (preview == place) is checked on every placement step of every placement/sequence case.
#   Only selected cases: godot ... -s res://tests/run_tests.gd -- --only=rules --case=BW-101,BW-103
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const Fx: GDScript = preload("res://tests/test_rules_fixtures.gd")

var _cards: Dictionary
var _triptychs: Array[TriptychData]
var _case_fail: Array[String] = []
var _preview_checks: int = 0
var _preview_mismatches: Array[String] = []


func test_qa_rules_cases() -> void:
	var doc: Dictionary = Fx.load_cases()
	assert_false(doc.is_empty(), "rules-test-cases.json loads from %s" % Fx.json_path())
	if doc.is_empty():
		return
	_cards = Fx.build_cards(doc)
	_triptychs = Fx.build_triptychs(_cards, doc)
	var only: PackedStringArray = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			only = arg.trim_prefix("--case=").split(",")
	var cases: Array = doc["cases"]
	var meta_cases: Array = []
	var passed: int = 0
	var failed_ids: PackedStringArray = []
	for c: Dictionary in cases:
		if not only.is_empty() and not only.has(c["id"]):
			continue
		if c["kind"] == "meta":
			meta_cases.append(c)  # judged after every placement step has been previewed
			continue
		if _run_case(c, doc):
			passed += 1
		else:
			failed_ids.append(c["id"])
	for c: Dictionary in meta_cases:
		_case_fail.clear()
		_check(_preview_checks >= 1, "no placement steps were previewed")
		for m: String in _preview_mismatches:
			_case_fail.append(m)
		if _case_fail.is_empty():
			passed += 1
		else:
			failed_ids.append(c["id"])
			_report(c["id"])
	var total: int = passed + failed_ids.size()
	print("     rules cases: %d / %d passed (%d preview checks)%s" % [passed, total, _preview_checks,
			"" if failed_ids.is_empty() else ", failed: " + ", ".join(failed_ids)])
	assert_eq(failed_ids.size(), 0, "failed QA cases: %s" % ", ".join(failed_ids))
	if only.is_empty():
		assert_eq(total, cases.size(), "every case ran")


func _run_case(c: Dictionary, doc: Dictionary) -> bool:
	_case_fail.clear()
	match c["kind"]:
		"adjacency":
			_run_adjacency(c)
		"placement", "sequence", "score":
			_run_board(c)
		"lineup":
			_run_lineup(c)
		"loaner":
			_run_loaner(c)
		"data":
			_run_data(c, doc)
		"flow":
			_run_flow(c)
		_:
			_case_fail.append("unknown case kind %s" % c["kind"])
	if _case_fail.is_empty():
		return true
	_report(c["id"])
	return false


func _report(id: String) -> void:
	for f: String in _case_fail:
		failures.append("%s: %s" % [id, f])


func _check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		_case_fail.append(msg)


func _check_same(actual: Variant, expected: Variant, what: String) -> void:
	_check(Fx.same(actual, expected), "%s expected %s got %s" % [what, Fx.show(expected), Fx.show(actual)])


# --- Board cases ------------------------------------------------------------------

func _state_for(c: Dictionary) -> WallState:
	return WallState.from_setup(c["setup"], _cards, Fx.build_balance(c.get("balance_overrides", {})),
			RulesOptions.new(), _triptychs)


func _players_map(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in d.keys():
		out[str(k)] = WallState.player_name(d[k])
	return out


func _run_board(c: Dictionary) -> void:
	var state: WallState = _state_for(c)
	var step_no: int = 0
	for step: Dictionary in c.get("steps", []):
		step_no += 1
		var a: Dictionary = step["action"]
		var player: int = WallState.player_from_string(a["player"])
		var card: CardData = _cards.get(StringName(a["card"]), null)
		var slot: StringName = StringName(a["slot"])
		var copy_from: StringName = StringName(str(a["cipher_copy_from"])) if a.get("cipher_copy_from") != null else &""
		var sig: bool = bool(a.get("signature", false))
		var label: String = "step %d (%s %s->%s)" % [step_no, a["player"], a["card"], a["slot"]]
		var pv: PlacementResult = WallRules.preview(state, player, card, slot, copy_from, sig)
		var r: PlacementResult = WallRules.place(state, player, card, slot, copy_from, sig)
		_check(r.ok, "%s rejected: %s" % [label, r.error])
		if not r.ok:
			return
		_preview_checks += 1
		if not Fx.same(pv.placement_part(), r.placement_part()):
			_preview_mismatches.append("%s %s preview %s != place %s" % [c["id"], label,
					Fx.show(pv.placement_part()), Fx.show(r.placement_part())])
		_check_step(step["expect"], r, state, label)
	if c.has("final"):
		_check_final(c["final"], state)


func _check_step(e: Dictionary, r: PlacementResult, state: WallState, label: String) -> void:
	for key: String in e.keys():
		var want: Variant = e[key]
		match key:
			"captured":
				_check_same(Fx.sorted_strings(r.captured), Fx.sorted_strings(want), label + " captured")
			"reclaimed":
				_check_same(Fx.sorted_strings(r.reclaimed), Fx.sorted_strings(want), label + " reclaimed")
			"carded":
				_check_same(Fx.sorted_strings(r.carded), Fx.sorted_strings(want), label + " carded")
			"springs_after":
				var got: Array = []
				for s: Dictionary in r.springs:
					got.append({"slot": str(s["slot"]), "captured": Fx.sorted_strings(s["captured"])})
				var exp: Array = []
				for s: Dictionary in want:
					exp.append({"slot": str(s["slot"]), "captured": Fx.sorted_strings(s["captured"])})
				_check_same(got, exp, label + " springs_after")
			"controllers_after":
				_check_same(_players_map(state.controllers()), want, label + " controllers_after")
			"score_after":
				_check_same({"P1": r.score_after[0], "P2": r.score_after[1]}, want, label + " score_after")
			"set_link":
				_check_same(r.set_link, want, label + " set_link")
			"clutch":
				_check_same(r.clutch, want, label + " clutch")
			"face_down":
				_check_same(r.face_down, want, label + " face_down")
			"active_trait":
				_check_same(r.trait_name(), want, label + " active_trait")
			"effective_values":
				_check_same(r.effective_values, want, label + " effective_values")
			_:
				_check(false, "%s unknown expectation '%s'" % [label, key])


func _check_final(f: Dictionary, state: WallState) -> void:
	var res: Dictionary = WallRules.final_result(state)
	_check_same({"P1": res["score"][0], "P2": res["score"][1]}, f["score"], "final score")
	var winner: String = "draw" if res["winner"] == WallState.NO_PLAYER else WallState.player_name(res["winner"])
	_check_same(winner, f["winner"], "final winner")
	_check_same(res["tie"], f["tie"], "final tie")
	if f.has("triptychs"):
		_check_same({"P1": Fx.sorted_strings(res["triptychs"][0]), "P2": Fx.sorted_strings(res["triptychs"][1])},
				{"P1": Fx.sorted_strings(f["triptychs"]["P1"]), "P2": Fx.sorted_strings(f["triptychs"]["P2"])},
				"final triptychs")
	if f.has("controllers"):
		_check_same(_players_map(state.controllers()), f["controllers"], "final controllers")
	_check(state.is_game_over() or not f.has("controllers"), "game over at the final board")


# --- Adjacency --------------------------------------------------------------------

func _run_adjacency(c: Dictionary) -> void:
	var topo: WallTopology = WallTopology.get_for(BalanceConfig.new().wall_rows)
	var e: Dictionary = c["expect"]
	if e.has("degree"):
		var deg: Dictionary = {}
		for s: StringName in topo.slots:
			deg[str(s)] = topo.neighbours(s).size()
		_check_same(deg, e["degree"], "degrees")
		_check_same(topo.edge_count(), e["edge_count"], "edge count")
		var sym: bool = true
		for s: StringName in topo.slots:
			for n: StringName in topo.neighbour_slots(s):
				sym = sym and topo.are_adjacent(n, s)
		_check_same(sym, e["symmetric"], "symmetric")
		for pair: Array in e["never_adjacent"]:
			_check(not topo.are_adjacent(StringName(pair[0]), StringName(pair[1])), "%s-%s adjacent" % [pair[0], pair[1]])
		return
	_check_same(topo.slots.size(), e.size(), "slot count")
	for slot: String in e.keys():
		var got: Dictionary = {}
		for d: int in WallTopology.Dir.values():
			got[str(WallTopology.DIR_NAMES[d])] = Fx.sorted_strings(topo.neighbours_in(StringName(slot), d))
		var want: Dictionary = {}
		for k: String in e[slot].keys():
			want[k] = Fx.sorted_strings(e[slot][k])
		_check_same(got, want, "neighbours of " + slot)


# --- Lineups ----------------------------------------------------------------------

func _run_lineup(c: Dictionary) -> void:
	var inp: Dictionary = c["input"]
	var collection: Variant = null
	if inp.get("collection") != null:
		collection = Fx.cards_from_ids(_cards, inp["collection"])
	var res: Dictionary = LineupRules.validate(Fx.cards_from_ids(_cards, inp["cards"]),
			Fx.cards_from_ids(_cards, inp["signatures"]), collection, BalanceConfig.new())
	_check_same(res["valid"], c["expect"]["valid"], "valid")
	_check_same(Fx.sorted_strings(res["errors"]), Fx.sorted_strings(c["expect"]["errors"]), "errors")


func _run_loaner(c: Dictionary) -> void:
	var b: BalanceConfig = BalanceConfig.new()
	var collection: Array = Fx.cards_from_ids(_cards, c["input"]["collection"])
	var offer: bool = LineupRules.should_offer_loaner(collection, b)
	_check_same(offer, c["expect"]["offer_loaner"], "offer_loaner")
	if c["expect"].get("loaner_lineup_must_validate", false):
		# The project's loaner lineup (balance.tres) is authored in cc03; until then, check the
		# lineup the engine would pick from the full card list.
		var loaner: Dictionary = _project_loaner()
		if loaner.is_empty():
			loaner = LineupRules.find_legal_lineup(_cards.values(), b)
		_check(not loaner.is_empty(), "a loaner lineup exists")
		if not loaner.is_empty():
			var res: Dictionary = LineupRules.validate(loaner["cards"], [loaner["signature"]], null, b)
			_check(res["valid"], "loaner lineup is legal: %s" % " ".join(res["messages"]))


func _project_loaner() -> Dictionary:
	var db: Node = tree.root.get_node_or_null("CardDB") if tree != null else null
	if db == null:
		return {}
	var b: BalanceConfig = db.get_balance()
	if b == null or b.loaner_lineup.is_empty():
		return {}
	return {"cards": b.loaner_lineup, "signature": b.loaner_signature}


# --- Card data rules (BW-097) -----------------------------------------------------

func _run_data(c: Dictionary, doc: Dictionary) -> void:
	var e: Dictionary = c["expect"]
	var b: BalanceConfig = BalanceConfig.new()
	for k: String in e["budget_by_clearance"].keys():
		_check_same(b.budget_for(int(k)), e["budget_by_clearance"][k], "budget for Clearance " + k)
	if e.get("every_demo_card_matches_budget", false):
		for id: StringName in _cards.keys():
			var codes: Array = _rule_issues(_cards[id], b)
			_check(codes.is_empty(), "%s breaks card rules: %s" % [id, codes])
	for mf: Dictionary in e.get("must_fail", []):
		var card: CardData = (_cards[StringName(mf["card"])] as CardData).duplicate()
		for k: String in mf["override"].keys():
			if k == "trait":
				var origin: Variant = DataEnums.TRAIT_BY_ORIGIN.find(WallState.trait_from_string(mf["override"][k]))
				card.origin = origin
			else:
				card.set(k, int(mf["override"][k]))
		_check(_rule_issues(card, b).has(DataValidator.STORE_RULE), "%s must fail: %s" % [mf["card"], mf["reason"]])
	var owned: Array = Fx.sorted_strings(e["demo_owned"])
	_check_same(owned.size(), e["demo_owned_count"], "demo owned count")
	for id: String in owned:
		_check(_cards.has(StringName(id)), "demo owned card %s exists" % id)
	# Cards already authored in res://data must agree on starting ownership (the rest come in cc03).
	var db: Node = tree.root.get_node_or_null("CardDB") if tree != null else null
	if db != null:
		for card: CardData in db.all_cards():
			if _cards.has(card.id):
				_check_same(card.starts_owned, owned.has(str(card.id)), "data/%s starts_owned" % card.id)


## Budget and store-rule issue codes for one card (other authoring fields aren't the point here).
func _rule_issues(card: CardData, b: BalanceConfig) -> Array:
	var v: DataValidator = DataValidator.new()
	v.balance = b
	v.begin("memory", str(card.id))
	card.validate(v)
	var out: Array = []
	for issue: Dictionary in v.issues:
		if issue["code"] in [DataValidator.BUDGET_MISMATCH, DataValidator.STORE_RULE] and not out.has(issue["code"]):
			out.append(issue["code"])
	return out


# --- Turn flow --------------------------------------------------------------------

func _run_flow(c: Dictionary) -> void:
	if c.has("attempts"):
		var state: WallState = _state_for(c)
		for att: Dictionary in c["attempts"]:
			var a: Dictionary = att["action"]
			var before: String = var_to_str(state.to_dict())
			var r: PlacementResult = WallRules.place(state, WallState.player_from_string(a["player"]),
					_cards.get(StringName(a["card"]), null), StringName(a["slot"]))
			_check(not r.ok, "%s->%s should be rejected" % [a["card"], a["slot"]])
			_check_same(r.error, att["expect_rejected"], "%s->%s error" % [a["card"], a["slot"]])
			if att.get("expect_state_unchanged", false):
				_check(var_to_str(state.to_dict()) == before, "%s->%s changed the state" % [a["card"], a["slot"]])
		return
	var e: Dictionary = c["expect"]
	if e.get("coin_flip_deterministic_with_seed", false):
		var seen: Dictionary = {}
		for s: int in 32:
			_check_same(WallState.coin_flip(s), WallState.coin_flip(s), "coin flip seed %d" % s)
			seen[WallState.coin_flip(s)] = true
		_check(seen.size() == 2, "coin flip gives both players over 32 seeds")
	for first: int in [WallState.P1, WallState.P2]:
		var l1: Array[CardData] = _typed([&"graveyard_shift", &"neon_rain", &"last_train", &"snow_blind", &"mayday"])
		var l2: Array[CardData] = _typed([&"frostbite", &"glacier", &"polar_night", &"open_channel", &"key_fragment"])
		var state: WallState = WallState.new_match(l1, _cards[&"snow_blind"], l2, _cards[&"polar_night"],
				first, BalanceConfig.new(), RulesOptions.new(), _triptychs)
		var firsts: Array = []
		var seconds: Array = []
		for n: int in range(1, 11):
			var moves: Array[Dictionary] = WallRules.legal_moves(state)
			_check(not moves.is_empty(), "placement %d has a legal move" % n)
			if moves.is_empty():
				return
			var mover: int = state.to_move
			(firsts if mover == first else seconds).append(n)
			var m: Dictionary = moves[(n * 7) % moves.size()]
			var r: PlacementResult = WallRules.place(state, mover, m["card"], m["slot"], m["copy_from"])
			_check(r.ok, "placement %d ok (%s)" % [n, r.error])
			_check_same(r.game_over, n == 10, "game over after placement %d" % n)
		_check_same(firsts, e["first_player_placements"], "first player's placements")
		_check_same(seconds, e["second_player_placements"], "second player's placements")
		_check_same(state.hand_of(WallState.P1).size() + state.hand_of(WallState.P2).size(), 0, "both hands spent")
		_check_same(str(e["after_10_placements"]), "game_over", "expectation shape")
		_check(state.is_game_over(), "game over after 10")
		var r11: PlacementResult = WallRules.place(state, state.to_move, _cards[&"mayday"], &"a1")
		_check_same(r11.error, e["eleventh_placement_rejected"], "11th placement")
		_check(WallRules.legal_moves(state).is_empty(), "no legal moves after the game")


func _typed(ids: Array) -> Array[CardData]:
	var out: Array[CardData] = []
	for id: StringName in ids:
		out.append(_cards[id])
	return out

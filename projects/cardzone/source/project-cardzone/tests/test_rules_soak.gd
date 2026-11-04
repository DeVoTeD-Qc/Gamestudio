# test_rules_soak.gd
# Purpose: Random-playout soak of the rules engine. 200 seeded 1v1 games (routes A/B/C in turn)
#   are played from new_match() to the end by a random policy drawn from legal_actions(), with
#   random Brace choices, holds, undos and the odd concede. After every action:
#   - card conservation: every card instance is in exactly one place;
#   - health: each seat's Hits (health stack + loadout + hand + line) total `health`, and
#     health = the health stack, 0..health; pools are never negative; held marks <= hold_limit;
#   - fairness (P18): each seat's view is identical when the opponent's private cards are
#     changed and reordered (loadout and hand; held cards too when they are hidden), checked
#     on every third action and at every Brace step;
#   - an undo restores the exact state; a shot's preview equals the declared shot.
#   At the end of each game: replaying the action log from the origin gives the same state.
#   The seeds come from the test (RandomNumberGenerator); the engine itself has no randomness.
# Dependencies: LoadoutRules, MatchState, MatchView, RulesData, tests/test_rules_fixtures.gd.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const Fx: GDScript = preload("res://tests/test_rules_fixtures.gd")
const GAMES: int = 200
const MAX_ACTIONS_PER_GAME: int = 3000
const MAX_ACTIONS_PER_TURN: int = 20

var _problems: Array[String] = []
var _stats: Dictionary = {}


func test_soak_200_games_spec_content() -> void:
	var content: RulesData = Fx.content()
	_run_soak(content, GAMES, 1000, true)


func test_soak_balance_switches() -> void:
	# The same invariants under the other §16.8 switch values (30 games each set).
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
		var content: RulesData = Fx.content().with_balance(overrides, errors)
		assert_true(errors.is_empty(), "overrides apply: %s" % [errors])
		_run_soak(content, 30, 5000 + 100 * n, true)
		n += 1


func test_soak_live_card_db() -> void:
	# The game builds its content from the CardDB autoload (res://data, authored by cz06).
	var db: Node = tree.root.get_node_or_null("CardDB")
	assert_not_null(db, "CardDB autoload")
	if db == null:
		return
	assert_true(db.is_valid(), "res://data loads without errors (cz06):\n" + "\n".join(db.get_errors()))
	var content: RulesData = RulesData.from_card_db(db)
	assert_eq(content.area_order.size(), 7, "7 areas from CardDB")
	assert_eq(content.start_pack().size(), 10, "Standard pack from CardDB")
	_run_soak(content, 20, 9000, false)


func _run_soak(content: RulesData, games: int, seed_base: int, check_views: bool) -> void:
	_problems.clear()
	_stats = {"games": 0, "actions": 0, "undos": 0, "previews": 0, "view_checks": 0, "replays": 0,
			"rounds": 0, "min_round": 99, "max_round": 0, "results": {}, "winners": {}, "shots": 0,
			"braces": 0, "loots": 0}
	var started: int = Time.get_ticks_msec()
	for g: int in games:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_base + g
		_play_one(content, g % 3, rng, check_views, "game %d (seed %d)" % [g, seed_base + g])
		if _problems.size() > 20:
			break
	var ms: int = Time.get_ticks_msec() - started
	print("     soak: %d games, %d actions, %d undos, %d shot previews, %d view checks, %d replays, %d ms" % [
			_stats["games"], _stats["actions"], _stats["undos"], _stats["previews"], _stats["view_checks"],
			_stats["replays"], ms])
	print("     soak: end round avg %.1f (min %d, max %d); results %s; winners %s; shots %d, braces %d, loots %d" % [
			float(_stats["rounds"]) / maxf(1.0, float(_stats["games"])), _stats["min_round"], _stats["max_round"],
			_stats["results"], _stats["winners"], _stats["shots"], _stats["braces"], _stats["loots"]])
	for p: String in _problems.slice(0, 20):
		print("     - %s" % p)
	assert_eq(_problems.size(), 0, "soak invariants broken: %d problems (first: %s)" % [_problems.size(),
			_problems[0] if not _problems.is_empty() else ""])
	assert_eq(int(_stats["games"]), games, "every game finished")


func _play_one(content: RulesData, route: int, rng: RandomNumberGenerator, check_views: bool, label: String) -> void:
	var state: MatchState = MatchState.new_match(content, route)
	var concede_at: int = rng.randi_range(5, 400) if rng.randf() < 0.02 else -1
	var turn_actions: int = 0
	var last_active: int = -1
	var n: int = 0
	_check_invariants(state, label + " start")
	while not state.is_over() and n < MAX_ACTIONS_PER_GAME:
		n += 1
		if state.active != last_active:
			turn_actions = 0
			last_active = state.active
		var where: String = "%s action %d (round %d)" % [label, n, state.round_number]
		var action: Dictionary
		if n == concede_at:
			action = {"type": "concede", "seat": rng.randi_range(0, 1)}
		else:
			var legal: Array[Dictionary] = LoadoutRules.legal_actions(state)
			if legal.is_empty():
				_problems.append("%s: no legal action" % where)
				return
			action = _choose(state, legal, rng, turn_actions)
		var t: String = action["type"]
		# Undo restores the exact state (U2).
		if t in LoadoutRules.UNDOABLE and rng.randf() < 0.08:
			var before: Dictionary = state.to_dict()
			var log_size: int = state.actions.size()
			var tried: ActionResult = LoadoutRules.apply(state, action)
			var undone: ActionResult = LoadoutRules.apply(state, {"type": "undo", "seat": state.active})
			_stats["undos"] += 1
			if not tried.ok or not undone.ok or state.to_dict() != before or state.actions.size() != log_size:
				_problems.append("%s: undo of %s did not restore the state" % [where, action])
				return
		var preview: Dictionary = {}
		if t == "shoot":
			preview = LoadoutRules.preview_shot(state, action["seat"], action["weapon"], action["target"])
		var r: ActionResult = LoadoutRules.apply(state, action)
		if not r.ok:
			_problems.append("%s: legal action %s rejected: %s" % [where, action, r.error])
			return
		_stats["actions"] += 1
		turn_actions += 1
		match t:
			"shoot":
				_stats["shots"] += 1
				_stats["previews"] += 1
				var rec: Dictionary = r.shot["targets"][int(action["target"])]
				if int(preview["damage"]) != int(rec["damage_before_brace"]) or int(preview["cover"]) != int(rec["cover"]) \
						or int(preview["down"]) != int(rec["down"]) or bool(preview["suppressed"]) != bool(rec["suppressed"]):
					_problems.append("%s: preview %s != shot %s" % [where, preview, rec])
			"brace":
				_stats["braces"] += 1
			"loot":
				_stats["loots"] += 1
		_check_invariants(state, where)
		# Fairness on every third action, and always while a Brace is pending (the step where a
		# private next hand meets the opponent's view); keeps the suite fast.
		if check_views and (n % 3 == 0 or not state.pending.is_empty() or t == "brace"):
			_check_fairness(state, where)
		if _problems.size() > 20:
			return
	if not state.is_over():
		_problems.append("%s: did not end within %d actions" % [label, MAX_ACTIONS_PER_GAME])
		return
	var errors: Array = []
	var again: MatchState = LoadoutRules.replay_of(state, errors)
	_stats["replays"] += 1
	if not errors.is_empty() or again.fingerprint() != state.fingerprint():
		_problems.append("%s: replay differs %s" % [label, errors])
	_stats["games"] += 1
	_stats["rounds"] += state.round_number
	_stats["min_round"] = mini(_stats["min_round"], state.round_number)
	_stats["max_round"] = maxi(_stats["max_round"], state.round_number)
	var cause: String = state.match_end.get("cause", "?")
	_stats["results"][cause] = int(_stats["results"].get(cause, 0)) + 1
	var who: String = MatchState.seat_name(int(state.match_end.get("winner", -1))) if state.match_end.has("winner") else "draw"
	_stats["winners"][who] = int(_stats["winners"].get(who, 0)) + 1


## A loose, aggressive random policy: shoot and loot when possible, play most cards, then end
## the turn with a random hold. Braces are random subsets.
func _choose(state: MatchState, legal: Array[Dictionary], rng: RandomNumberGenerator, turn_actions: int) -> Dictionary:
	var by_type: Dictionary = {}
	for a: Dictionary in legal:
		var t: String = a["type"]
		if not by_type.has(t):
			by_type[t] = []
		by_type[t].append(a)
	var pick: Callable = func(t: String) -> Dictionary:
		var list: Array = by_type[t]
		return list[rng.randi_range(0, list.size() - 1)]
	if by_type.has("drop"):
		return pick.call("drop")
	if by_type.has("brace"):
		return pick.call("brace")
	if turn_actions < MAX_ACTIONS_PER_TURN:
		var order: Array = [["shoot", 0.85], ["frag", 0.4], ["attach", 0.9], ["loot", 0.75], ["patch_up", 0.5],
				["play", 0.85], ["move", 0.35], ["ditch", 0.15]]
		for entry: Array in order:
			if by_type.has(entry[0]) and rng.randf() < float(entry[1]):
				return pick.call(entry[0])
	return pick.call("end_turn")


func _check_invariants(state: MatchState, where: String) -> void:
	var b: BalanceConfig = state.data.balance
	var located: Dictionary = state.locate_all()
	if located.size() != state.defs.size():
		var missing: Array = state.defs.keys().filter(func(k: Variant) -> bool: return not located.has(k))
		_problems.append("%s: %d cards registered, %d located (missing %s)" % [where, state.defs.size(), located.size(), missing])
	for inst: Variant in located.keys():
		if "DUPLICATE" in String(located[inst]):
			_problems.append("%s: card %d is in two places: %s" % [where, inst, located[inst]])
	for seat: int in [MatchState.P1, MatchState.P2]:
		var st: SeatState = state.seats[seat]
		var hits: int = st.health.size() + state.hits_in(st.loadout) + state.hits_in(st.hand) + state.hits_in(st.line)
		if hits != b.health:
			_problems.append("%s: %s has %d Hits in play (health %d)" % [where, MatchState.seat_name(seat), hits, b.health])
		for inst: int in st.health:
			if not state.is_hit(inst) or int(state.owners.get(inst, -1)) != seat:
				_problems.append("%s: health stack holds %s" % [where, state.label(inst)])
		if st.health.size() > b.health or st.move < 0 or st.search < 0:
			_problems.append("%s: %s health %d move %d search %d" % [where, MatchState.seat_name(seat), st.health.size(), st.move, st.search])
		if st.held.size() > b.hold_limit:
			_problems.append("%s: %d held marks" % [where, st.held.size()])
		for inst: int in st.held:
			if not st.loadout.has(inst):
				_problems.append("%s: held mark on a card outside the loadout" % where)
		for weapon: Variant in state.attachments.keys():
			var atts: Array = state.attachments[weapon]
			if atts.size() > 2:
				_problems.append("%s: %d attachments on one weapon" % [where, atts.size()])


## P18: changing and reordering the opponent's private cards never changes a seat's view.
func _check_fairness(state: MatchState, where: String) -> void:
	for seat: int in [MatchState.P1, MatchState.P2]:
		var view_a: Dictionary = LoadoutRules.view(state, seat)
		if int(view_a["me"]["health"]) != state.health_of(seat) or int(view_a["opponent"]["health"]) != state.health_of(1 - seat):
			_problems.append("%s: shown health != health stack" % where)
		var scrambled: MatchState = scramble_private(state, 1 - seat)
		var view_b: Dictionary = LoadoutRules.view(scrambled, seat)
		_stats["view_checks"] += 1
		if view_a != view_b and JSON.stringify(view_a, "", true) != JSON.stringify(view_b, "", true):
			_problems.append("%s: %s's view depends on the opponent's private cards (%s)" % [where,
					MatchState.seat_name(seat), first_difference(view_a, view_b, "view")])
			return


## A copy where `seat`'s private cards (loadout and hand non-Hit cards; held cards only when
## they are hidden) are rotated among their own positions and swapped for other card ids.
static func scramble_private(state: MatchState, seat: int) -> MatchState:
	var s: MatchState = state.clone()
	var st: SeatState = s.seats[seat]
	var public_ids: Array = []
	if s.data.balance.held_cards_public:
		public_ids.append_array(st.held)
	var swap: Array[StringName] = [&"plate_vest", &"scavenge", &"dash", &"medkit", &"crowbar"]
	for which: int in 2:
		var list: Array[int] = st.loadout if which == 0 else st.hand
		var slots: Array[int] = []
		for i: int in list.size():
			var inst: int = list[i]
			if not s.is_hit(inst) and not public_ids.has(inst) and not (which == 0 and st.held.has(inst)):
				slots.append(i)
		if slots.size() >= 2:
			var first: int = list[slots[0]]
			for k: int in range(slots.size() - 1):
				list[slots[k]] = list[slots[k + 1]]
			list[slots[slots.size() - 1]] = first
		for k: int in slots.size():
			var inst: int = list[slots[k]]
			if s.attachments_of(inst).is_empty() and s.data.card(swap[k % swap.size()]) != null:
				s.defs[inst] = swap[(k + inst) % swap.size()]
	if not s.data.balance.held_cards_public:
		for inst: int in st.held:
			if s.attachments_of(inst).is_empty() and not public_ids.has(inst):
				s.defs[inst] = &"duck" if s.card_id(inst) != &"duck" else &"dash"
	return s


## The path of the first difference between two values ("" when equal).
static func first_difference(a: Variant, b: Variant, path: String) -> String:
	if a is Dictionary and b is Dictionary:
		for k: Variant in a.keys():
			if not b.has(k):
				return "%s.%s missing" % [path, k]
			var d: String = first_difference(a[k], b[k], "%s.%s" % [path, k])
			if d != "":
				return d
		for k: Variant in b.keys():
			if not a.has(k):
				return "%s.%s extra" % [path, k]
		return ""
	if a is Array and b is Array:
		if a.size() != b.size():
			return "%s size %d vs %d" % [path, a.size(), b.size()]
		for i: int in a.size():
			var d: String = first_difference(a[i], b[i], "%s[%d]" % [path, i])
			if d != "":
				return d
		return ""
	return "" if JSON.stringify(a) == JSON.stringify(b) else "%s: %s vs %s" % [path, a, b]

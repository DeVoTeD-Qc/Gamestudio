# test_ai.gd
# Purpose: Contract tests for the AI rivals (cc06, scripts/ai): the factory, legal and
#   deterministic moves, no state changes, hidden information (RQ-19), the greedy pick, Warden's
#   node cap and time, and Warden's strength against the Quartermaster.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const RivalBrain: GDScript = preload("res://scripts/duel/rival_brain.gd")

var _balance: BalanceConfig = load("res://data/balance.tres")
var _triptychs: Array[TriptychData] = [
	load("res://data/triptychs/cold_signal.tres"), load("res://data/triptychs/midnight_run.tres"),
	load("res://data/triptychs/open_book.tres")]
var _rivals: Dictionary = {
	"quartermaster": load("res://data/rivals/quartermaster.tres"),
	"archivist": load("res://data/rivals/archivist.tres"),
	"warden": load("res://data/rivals/warden.tres")}


func _card(id: String) -> CardData:
	return load("res://data/cards/%s.tres" % id)


func _match(a: RivalData, b: RivalData, first: int) -> WallState:
	return WallState.new_match(a.lineup, a.signature, b.lineup, b.signature, first, _balance,
			RulesOptions.new(), _triptychs)


## Plays a full duel; returns the move log as strings.
func _play(a: RivalData, b: RivalData, seed_value: int, legal_ok: Array) -> Array[String]:
	var state: WallState = _match(a, b, WallState.coin_flip(seed_value))
	var brains: Array[RivalAI] = [RivalAI.for_rival(a, seed_value), RivalAI.for_rival(b, seed_value + 1)]
	var log: Array[String] = []
	while not state.is_game_over():
		var me: int = state.to_move
		var before: Dictionary = state.to_dict()
		var legal: Array[Dictionary] = WallRules.legal_moves(state)
		var move: Dictionary = brains[me].choose_move(state, me)
		if state.to_dict() != before or not legal.has(move):
			legal_ok[0] = false
		if move.is_empty():
			legal_ok[0] = false
			break
		log.append("%s:%s:%s" % [move["card"].id, move["slot"], move["copy_from"]])
		WallRules.place(state, me, move["card"], move["slot"], move["copy_from"])
	return log


func test_factory_picks_brain_from_tuning() -> void:
	var q: RivalAI = RivalAI.for_rival(_rivals["quartermaster"], 1)
	var a: RivalAI = RivalAI.for_rival(_rivals["archivist"], 1)
	var w: RivalAI = RivalAI.for_rival(_rivals["warden"], 1)
	assert_true(q is QuartermasterAI and a is ArchivistAI and w is WardenAI, "0 / 1 / 2 plies")
	assert_eq(q.best_capture_chance, 0.5, "Quartermaster best-capture chance from data")
	assert_eq(w.signature_safety_weight, 3.0, "Warden Signature weight from data")
	assert_true(w.rival == _rivals["warden"], "keeps its RivalData")
	assert_true(is_instance_of(w, RivalBrain), "is a RivalBrain for the duel controller")


func test_moves_are_legal_and_state_untouched() -> void:
	var ok: Array = [true]
	var n: int = 0
	for a: String in _rivals:
		for b: String in _rivals:
			n += _play(_rivals[a], _rivals[b], 11 + n, ok).size()
	assert_true(ok[0], "every move is one of legal_moves and choose_move never changes the state")
	assert_eq(n, 90, "9 full duels of 10 placements")


func test_same_seed_same_duel() -> void:
	var ok: Array = [true]
	for id: String in _rivals:
		var r: RivalData = _rivals[id]
		assert_eq(_play(r, _rivals["warden"], 77, ok), _play(r, _rivals["warden"], 77, ok), "%s replays" % id)


func test_no_move_when_not_its_turn() -> void:
	var state: WallState = _match(_rivals["archivist"], _rivals["warden"], WallState.P1)
	assert_eq(RivalAI.for_rival(_rivals["warden"], 1).choose_move(state, WallState.P2), {}, "P1 to move")
	assert_false(RivalAI.for_rival(_rivals["warden"], 1).choose_move(state).is_empty(), "default player = to_move")


## Two duels identical except which Ambush the opponent put face-down (and so which stays in
## hand). The AI must not tell them apart (RQ-19).
func _hidden_pair() -> Array[WallState]:
	var opp_lineup: Array[CardData] = [_card("last_train"), _card("snow_blind"), _card("mayday"),
			_card("graveyard_shift"), _card("neon_rain")]
	var out: Array[WallState] = []
	for down: String in ["last_train", "snow_blind"]:
		var s: WallState = WallState.new_match(opp_lineup, _card("snow_blind"), _rivals["archivist"].lineup,
				_rivals["archivist"].signature, WallState.P1, _balance, RulesOptions.new(), _triptychs)
		WallRules.place(s, WallState.P1, _card(down), &"b2")
		out.append(s)
	return out


func test_hidden_face_down_card_is_not_read() -> void:
	var pair: Array[WallState] = _hidden_pair()
	assert_true(pair[0].get_card(&"b2").face_down, "the Ambush is face-down")
	for id: String in _rivals:
		for seed_value: int in [1, 2, 3]:
			var m0: Dictionary = RivalAI.for_rival(_rivals[id], seed_value).choose_move(pair[0], WallState.P2)
			var m1: Dictionary = RivalAI.for_rival(_rivals[id], seed_value).choose_move(pair[1], WallState.P2)
			assert_eq(m0, m1, "%s seed %d: same move whichever Ambush is face-down" % [id, seed_value])


func test_belief_world_masks_hidden_cards() -> void:
	var pair: Array[WallState] = _hidden_pair()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for s: WallState in pair:
		var before: Dictionary = s.to_dict()
		rng.seed = 5
		var w: WallState = RivalAI.belief_world(s, WallState.P2, rng)
		assert_eq(s.to_dict(), before, "the real state is untouched")
		var guess: CardData = w.get_card(&"b2").card
		assert_true(guess.id in [&"last_train", &"snow_blind"], "the hidden card is one of the unseen Ambush cards")
		var hand_ids: Array = (w.hand_of(WallState.P1) as Array).map(func(c: CardData) -> StringName: return c.id)
		assert_eq(hand_ids.size(), 4, "opponent hand = unseen cards minus the guess")
		assert_false(hand_ids.has(guess.id), "the guess left the hand")
		assert_eq(w.get_card(&"b2").signature, guess.id == &"snow_blind", "Signature flag follows the guess")
		assert_eq(w.hand_of(WallState.P2), s.hand_of(WallState.P2), "own hand is known")
	# Same seed -> same guess in both worlds: the guess doesn't depend on the true card.
	rng.seed = 9
	var g0: StringName = RivalAI.belief_world(pair[0], WallState.P2, rng).get_card(&"b2").card.id
	rng.seed = 9
	var g1: StringName = RivalAI.belief_world(pair[1], WallState.P2, rng).get_card(&"b2").card.id
	assert_eq(g0, g1, "guess is independent of the hidden identity")
	# The owner sees its own face-down card.
	rng.seed = 1
	assert_eq(RivalAI.belief_world(pair[0], WallState.P1, rng).get_card(&"b2").card.id, &"last_train", "owner view")


func test_archivist_takes_the_best_immediate_result() -> void:
	var s: WallState = _match(_rivals["quartermaster"], _rivals["archivist"], WallState.P1)
	WallRules.place(s, WallState.P1, _card("gold_leaf"), &"b2")
	var ai: RivalAI = RivalAI.for_rival(_rivals["archivist"], 3)
	var move: Dictionary = ai.choose_move(s, WallState.P2)
	var best: int = -99
	for m: Dictionary in WallRules.legal_moves(s):
		var w: WallState = RivalAI.after_move(s, WallState.P2, m)
		best = maxi(best, WallRules.score(w, WallState.P2) - WallRules.score(w, WallState.P1))
	var got: WallState = RivalAI.after_move(s, WallState.P2, move)
	assert_eq(WallRules.score(got, WallState.P2) - WallRules.score(got, WallState.P1), best, "greedy = best margin")
	assert_true(WallRules.preview(s, WallState.P2, move["card"], move["slot"]).captured.size() > 0, "it captures")


func test_warden_node_cap_and_time() -> void:
	var worst_ms: float = 0.0
	for first: int in [WallState.P1, WallState.P2]:
		for opp: String in _rivals:
			var s: WallState = _match(_rivals["warden"], _rivals[opp], first)
			if first == WallState.P2:
				var reply: Dictionary = RivalAI.for_rival(_rivals[opp], 2).choose_move(s)
				WallRules.place(s, WallState.P2, reply["card"], reply["slot"], reply["copy_from"])
			var ai: WardenAI = RivalAI.for_rival(_rivals["warden"], 4)
			var t0: int = Time.get_ticks_usec()
			var move: Dictionary = ai.choose_move(s, WallState.P1)
			worst_ms = maxf(worst_ms, (Time.get_ticks_usec() - t0) / 1000.0)
			assert_false(move.is_empty(), "Warden moves vs %s" % opp)
			assert_true(ai.last_nodes <= ai.max_nodes + 60, "node cap holds (%d)" % ai.last_nodes)
	# Budget: 200 ms on a phone, 4x headroom -> 50 ms here. The bound below is loose so a busy CI
	# machine doesn't fail it; the sim tool reports the real distribution.
	print("     Warden opening moves: worst %.1f ms" % worst_ms)
	assert_true(worst_ms < 150.0, "Warden opening move under 150 ms here (%.1f)" % worst_ms)


func test_warden_beats_quartermaster() -> void:
	var wins: int = 0
	for seed_value: int in range(100, 110):
		var first: int = WallState.coin_flip(seed_value)
		var s: WallState = _match(_rivals["warden"], _rivals["quartermaster"], first)
		var brains: Array[RivalAI] = [RivalAI.for_rival(_rivals["warden"], seed_value),
				RivalAI.for_rival(_rivals["quartermaster"], seed_value)]
		while not s.is_game_over():
			var m: Dictionary = brains[s.to_move].choose_move(s)
			WallRules.place(s, s.to_move, m["card"], m["slot"], m["copy_from"])
		if WallRules.final_result(s)["winner"] == WallState.P1:
			wins += 1
	assert_true(wins >= 7, "Warden wins at least 7 of 10 seeded duels vs Quartermaster (%d)" % wins)

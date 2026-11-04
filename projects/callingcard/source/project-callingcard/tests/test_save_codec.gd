# test_save_codec.gd
# Purpose: cc09 WallStateCodec: a saved duel must play on exactly like the original.
#   Seeded random duels with the real data: after every placement the state goes through
#   encode -> JSON text -> parse -> decode, must equal the original, and the next move played on
#   both must give the same PlacementResult and state. Also: rules options survive, bad input fails.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"


func _db() -> Node:
	return tree.root.get_node("CardDB")


func _triptychs() -> Array[TriptychData]:
	var out: Array[TriptychData] = []
	out.assign(_db().all_triptychs())
	return out


## A real duel: loaner lineup (P1) vs a rival lineup (P2).
func _new_duel(rival_id: StringName, first: int, options: RulesOptions = null) -> WallState:
	var b: BalanceConfig = _db().get_balance()
	var rival: RivalData = _db().get_rival(rival_id)
	var p1: Array[CardData] = []
	p1.assign(b.loaner_lineup)
	var p2: Array[CardData] = []
	p2.assign(rival.lineup)
	return WallState.new_match(p1, b.loaner_signature, p2, rival.signature, first, b, options, _triptychs())


func _round_trip(s: WallState) -> WallState:
	var text: String = JSON.stringify(WallStateCodec.encode(s))
	var parsed: Variant = JSON.parse_string(text)
	return WallStateCodec.decode(parsed, Callable(_db(), "get_card"), _db().get_balance(), _triptychs())


func _pick(s: WallState, rng: RandomNumberGenerator) -> Dictionary:
	var moves: Array[Dictionary] = WallRules.legal_moves(s)
	return moves[rng.randi_range(0, moves.size() - 1)]


func test_round_trip_every_placement_of_random_duels() -> void:
	var rivals: Array[StringName] = [&"quartermaster", &"archivist", &"warden"]
	var checked: int = 0
	for seed_value: int in range(1, 31):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		var opts: RulesOptions = RulesOptions.new()
		opts.cancel_spring_if_lost = seed_value % 2 == 0
		opts.cipher_copies_printed_trait = seed_value % 3 != 0
		var a: WallState = _new_duel(rivals[seed_value % 3], WallState.coin_flip(seed_value), opts)
		while not a.is_game_over():
			var b: WallState = _round_trip(a)
			if b == null:
				assert_true(false, "seed %d: decode failed: %s" % [seed_value, WallStateCodec.last_error])
				return
			if not WallStateCodec.same_state(a, b) or a.to_dict() != b.to_dict():
				assert_true(false, "seed %d after %d placements: state differs" % [seed_value, a.placements])
				return
			var m: Dictionary = _pick(a, rng)
			var ra: PlacementResult = WallRules.place(a, a.to_move, m["card"], m["slot"], m["copy_from"])
			var rb: PlacementResult = WallRules.place(b, b.to_move, m["card"], m["slot"], m["copy_from"])
			if not ra.ok or ra.to_dict() != rb.to_dict() or not WallStateCodec.same_state(a, b):
				assert_true(false, "seed %d: move %s plays differently after a reload" % [seed_value, str(m["slot"])])
				return
			checked += 1
		assert_eq(WallRules.final_result(a), WallRules.final_result(_round_trip(a)), "seed %d final result" % seed_value)
	assert_true(checked >= 30 * 9, "checked %d placements" % checked)


func test_hidden_fields_and_options_survive() -> void:
	var opts: RulesOptions = RulesOptions.new()
	opts.showcase_set_link = false
	opts.clutch_uses_full_score = false
	opts.cipher_copies_printed_trait = false
	opts.cancel_spring_if_lost = false
	var a: WallState = _new_duel(&"warden", WallState.P1, opts)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 5:
		var m: Dictionary = _pick(a, rng)
		WallRules.place(a, a.to_move, m["card"], m["slot"], m["copy_from"])
	# A captured card: controller != placed_by, which WallState.to_dict() doesn't keep.
	var some: PlacedCard = a.cells.values()[0]
	some.controller = WallState.other(some.placed_by)
	var b: WallState = _round_trip(a)
	assert_not_null(b, "decodes")
	assert_eq(b.get_card(a.cells.keys()[0]).placed_by, some.placed_by, "placed_by kept")
	assert_false(b.options.showcase_set_link, "showcase_set_link kept")
	assert_false(b.options.clutch_uses_full_score, "clutch_uses_full_score kept")
	assert_false(b.options.cipher_copies_printed_trait, "cipher_copies_printed_trait kept")
	assert_false(b.options.cancel_spring_if_lost, "cancel_spring_if_lost kept")
	assert_eq(b.triptychs.size(), _triptychs().size(), "Triptychs from current data")
	assert_true(b.balance == _db().get_balance(), "balance from current data")


func test_bad_input_fails_safely() -> void:
	var lookup: Callable = Callable(_db(), "get_card")
	var good: Dictionary = WallStateCodec.encode(_new_duel(&"archivist", WallState.P2))
	assert_not_null(WallStateCodec.decode(good, lookup), "good input decodes")
	for bad: Variant in [null, 5, "text", [], {}]:
		assert_true(WallStateCodec.decode(bad, lookup) == null, "garbage %s fails" % str(bad))
	var newer: Dictionary = good.duplicate(true)
	newer["format"] = WallStateCodec.FORMAT + 1
	assert_true(WallStateCodec.decode(newer, lookup) == null, "newer format fails")
	var unknown: Dictionary = good.duplicate(true)
	unknown["hands"][0][0] = "no_such_card"
	assert_true(WallStateCodec.decode(unknown, lookup) == null, "unknown card fails")
	assert_true(WallStateCodec.last_error.contains("no_such_card"), "error names the card: %s" % WallStateCodec.last_error)
	var shape: Dictionary = good.duplicate(true)
	shape["rows"] = [3, 3, 3]
	assert_true(WallStateCodec.decode(shape, lookup) == null, "changed wall shape fails")
	var turn: Dictionary = good.duplicate(true)
	turn["to_move"] = 2
	assert_true(WallStateCodec.decode(turn, lookup) == null, "bad player fails")
	assert_true(WallStateCodec.decode(good, Callable()) == null, "no card lookup fails")

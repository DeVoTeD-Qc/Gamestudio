# test_dossier.gd
# Purpose: cc12 Dossier puzzles on the real rules engine (scripts/dossier/dossier_puzzle.gd):
#   - each of the 5 known solutions meets its goal through WallState.from_setup + WallRules.place,
#   - a named wrong line fails each goal, and an exhaustive search finds the solution among the
#     winning lines (so the goal check is not trivially true),
#   - scripted rival replies go through WallRules.place, and their slots are reserved,
#   - Retry resets the start board exactly, D5's Cipher pick comes from DossierPlacement.copy_from,
#   - the reward is paid once only (cc09 Collection.complete_dossier on a test Collection).
# Author: Mechanics Developer Agent (cc12)
extends "res://tests/test_case.gd"

const Fixtures: GDScript = preload("res://tests/test_collection_fixtures.gd")

const IDS: Array[StringName] = [&"dossier_first_contact", &"dossier_same_page", &"dossier_lights_out",
		&"dossier_carded", &"dossier_clean_copy"]

## A wrong line per Dossier: [card id, slot, copy_from] steps. Each is legal but misses the goal.
const WRONG: Dictionary = {
	&"dossier_first_contact": [[&"frostbite", &"b2", &""], [&"glacier", &"b4", &""]],
	&"dossier_same_page": [[&"graveyard_shift", &"c1", &""], [&"neon_rain", &"c2", &""]],
	&"dossier_lights_out": [[&"graveyard_shift", &"b2", &""], [&"flare_up", &"b1", &""]],
	&"dossier_carded": [[&"honor_roll", &"b2", &""], [&"service_ribbon", &"b3", &""]],
	&"dossier_clean_copy": [[&"null_glyph", &"c1", &"b2"], [&"gold_leaf", &"a2", &""]],
}


func _dossier(id: StringName) -> DossierData:
	return load("res://data/dossiers/%s.tres" % id) as DossierData


func _card(d: DossierData, id: StringName) -> CardData:
	return DossierPuzzle.card_table(d)[id]


func _line(d: DossierData, steps: Array) -> Array:
	return steps.map(func(s: Array) -> Dictionary: return {"card": _card(d, s[0]), "slot": s[1], "copy_from": s[2]})


# --- Solutions ------------------------------------------------------------------------

func test_five_dossiers_in_order() -> void:
	for i: int in IDS.size():
		var d: DossierData = _dossier(IDS[i])
		assert_not_null(d, "%s loads" % IDS[i])
		assert_eq(d.number, i + 1, "%s is D%d" % [IDS[i], i + 1])
		assert_false(d.solution.is_empty(), "%s has a solution" % IDS[i])


func test_each_solution_meets_its_goal() -> void:
	for id: StringName in IDS:
		var d: DossierData = _dossier(id)
		var p: DossierPuzzle = DossierPuzzle.new(d)
		assert_eq(p.play_line(d.solution), &"", "%s solution is legal" % id)
		assert_true(p.is_finished(), "%s finished after the solution" % id)
		var r: Dictionary = p.evaluate()
		assert_true(r["success"], "%s solution clears the goal (%s)" % [id, r["reason"]])


func test_solution_details_match_the_content_table() -> void:
	# prototype-content.md "Dossiers": final scores and the key effects.
	var p: DossierPuzzle = _solved(&"dossier_first_contact")
	assert_eq(p.player_captures(), 3, "D1 captures 3")
	assert_true(_carded_any(p), "D1 Glacier Cards Chrome Tiger")
	p = _solved(&"dossier_same_page")
	assert_eq(p.scores(), [5, 3] as Array[int], "D2 wins 5–3")
	assert_true(p.results[1].set_link, "D2 Graveyard Shift gets Set Link")
	p = _solved(&"dossier_lights_out")
	assert_eq(p.best_spring(), 2, "D3 one spring captures 2")
	assert_eq(p.results[1].player, WallState.P2, "D3 rival reply resolves between the player's placements")
	assert_eq(p.results[1].slot, &"a2", "D3 rival walks into a2")
	p = _solved(&"dossier_carded")
	assert_eq(p.scores(), [8, 1] as Array[int], "D4 wins 8–1")
	assert_true(p.holds_rival_signature(), "D4 Mayday* is yours")
	assert_eq(p.results[2].reclaimed, [&"c2"] as Array[StringName], "D4 Honor Roll reclaims c2")
	p = _solved(&"dossier_clean_copy")
	assert_eq(p.scores(), [5, 4] as Array[int], "D5 wins 5–4")
	assert_eq(p.results[0].copy_from, &"c2", "D5 Null Glyph copies c2 (DossierPlacement.copy_from)")
	assert_true(p.results[0].clutch, "D5 copied Clutch fires (behind)")


func _solved(id: StringName) -> DossierPuzzle:
	var d: DossierData = _dossier(id)
	var p: DossierPuzzle = DossierPuzzle.new(d)
	p.play_line(d.solution)
	return p


func _carded_any(p: DossierPuzzle) -> bool:
	return p.results.any(func(r: PlacementResult) -> bool: return not r.carded.is_empty())


# --- Wrong lines --------------------------------------------------------------------------

func test_a_wrong_line_fails_each_goal() -> void:
	for id: StringName in IDS:
		var d: DossierData = _dossier(id)
		var p: DossierPuzzle = DossierPuzzle.new(d)
		assert_eq(p.play_line(_line(d, WRONG[id])), &"", "%s wrong line is legal" % id)
		assert_true(p.is_finished(), "%s wrong line uses every placement" % id)
		var r: Dictionary = p.evaluate()
		assert_false(r["success"], "%s wrong line fails (%s)" % [id, r["reason"]])
		assert_true(String(r["reason"]) != "", "%s failure says why" % id)


func test_exhaustive_search_finds_the_solution_and_failures() -> void:
	for id: StringName in IDS:
		var d: DossierData = _dossier(id)
		var counts: Dictionary = {"win": 0, "lose": 0, "solution": false}
		_search(d, [], counts)
		assert_true(counts["solution"], "%s: the known solution is among the winning lines" % id)
		assert_true(counts["lose"] > counts["win"], "%s: most lines fail (%d win / %d lose)" % [id, counts["win"], counts["lose"]])


func _search(d: DossierData, prefix: Array, counts: Dictionary) -> void:
	var p: DossierPuzzle = DossierPuzzle.new(d)
	p.play_line(prefix)
	if p.is_finished():
		var ok: bool = p.evaluate()["success"]
		counts["win" if ok else "lose"] += 1
		if ok and prefix.size() == d.solution.size():
			var same: bool = true
			for i: int in prefix.size():
				same = same and prefix[i]["card"] == d.solution[i].card and prefix[i]["slot"] == d.solution[i].slot \
						and prefix[i]["copy_from"] == d.solution[i].copy_from
			counts["solution"] = counts["solution"] or same
		return
	for card: CardData in p.player_hand():
		for slot: StringName in p.valid_slots(card):
			var picks: Array = [&""]
			if card.card_trait() == DataEnums.CardTrait.CIPHER and not WallRules.cipher_picks(p.state, slot).is_empty():
				picks = WallRules.cipher_picks(p.state, slot)
			for pick: StringName in picks:
				_search(d, prefix + [{"card": card, "slot": slot, "copy_from": pick}], counts)


func test_goal_needs_its_specific_condition() -> void:
	# D5: winning without a rival-trait copy is not a clear (Null Glyph copies own Frostbite).
	var d: DossierData = _dossier(&"dossier_clean_copy")
	var p: DossierPuzzle = DossierPuzzle.new(d)
	p.play_line(_line(d, [[&"null_glyph", &"c1", &"c2"]]))
	assert_true(p.copied_rival_trait(), "copying Polar Night counts")
	p.reset()
	p.play_line(_line(d, [[&"gold_leaf", &"a2", &""], [&"null_glyph", &"a3", &"b3"]]))
	assert_false(p.copied_rival_trait(), "copying your own Frostbite does not")
	assert_false(p.evaluate()["success"], "no rival copy -> no clear")
	# D2: WIN_IN_PLACEMENTS needs exactly max_placements placements.
	var d2: DossierData = _dossier(&"dossier_same_page")
	var p2: DossierPuzzle = DossierPuzzle.new(d2)
	p2.play_line(_line(d2, [[&"neon_rain", &"c2", &""]]))
	assert_false(p2.is_finished(), "one placement is not the end")
	assert_false(p2.evaluate()["success"], "one placement is not exactly two")


# --- Rival replies and reserved slots ---------------------------------------------------------

func test_reply_slots_are_reserved_until_the_reply() -> void:
	for spec: Array in [[&"dossier_lights_out", &"a2", &"flare_up"], [&"dossier_carded", &"c1", &"service_ribbon"]]:
		var d: DossierData = _dossier(spec[0])
		var p: DossierPuzzle = DossierPuzzle.new(d)
		var card: CardData = _card(d, spec[2])
		assert_true(p.reserved_slots().has(spec[1]), "%s: %s reserved at start" % [spec[0], spec[1]])
		assert_eq(p.check_place(card, spec[1]), DossierPuzzle.ERR_RESERVED, "%s: placing into %s is refused" % [spec[0], spec[1]])
		assert_false(p.valid_slots(card).has(spec[1]), "%s: %s not offered as a drop" % [spec[0], spec[1]])
		assert_false(p.place_player(card, spec[1]).ok, "%s: place_player refuses %s" % [spec[0], spec[1]])
		assert_eq(p.placements_made(), 0, "%s: refusal changes nothing" % spec[0])
		var out: Dictionary = p.place(d.solution[0].card, d.solution[0].slot, d.solution[0].copy_from)
		var reply: PlacementResult = out["rival"]
		assert_not_null(reply, "%s: reply follows the first placement" % spec[0])
		assert_true(reply.ok and reply.player == WallState.P2 and reply.slot == spec[1],
				"%s: reply is a WallRules placement by the rival into %s" % [spec[0], spec[1]])
		assert_false(p.reserved_slots().has(spec[1]), "%s: no longer reserved once filled" % spec[0])
		assert_eq(p.state.to_move, WallState.P1, "%s: back to the player after the reply" % spec[0])


func test_reply_uses_engine_rules() -> void:
	# D4: Open Channel's reply is a real capture: it Cards your Signature Graveyard Shift.
	var d: DossierData = _dossier(&"dossier_carded")
	var p: DossierPuzzle = DossierPuzzle.new(d)
	var out: Dictionary = p.place(_card(d, &"service_ribbon"), &"b3")
	var reply: PlacementResult = out["rival"]
	assert_eq(reply.carded, [&"c2"] as Array[StringName], "rival reply Cards your Signature at c2")
	assert_eq(p.state.controller_of(&"c2"), WallState.P2, "c2 is the rival's after the reply")


func test_no_reply_hands_the_turn_back() -> void:
	var d: DossierData = _dossier(&"dossier_first_contact")
	var p: DossierPuzzle = DossierPuzzle.new(d)
	var out: Dictionary = p.place(_card(d, &"glacier"), &"b2")
	assert_true(out["ok"], "placement ok")
	assert_eq(out["rival"], null, "no scripted reply")
	assert_eq(p.state.to_move, WallState.P1, "player moves again")


# --- Retry -----------------------------------------------------------------------------------

func test_retry_resets_the_start_board() -> void:
	for id: StringName in IDS:
		var d: DossierData = _dossier(id)
		var p: DossierPuzzle = DossierPuzzle.new(d)
		var start: Dictionary = p.state.to_dict()
		p.play_line(d.solution)
		assert_true(p.state.to_dict() != start, "%s board changed" % id)
		p.reset()
		assert_eq(p.state.to_dict(), start, "%s retry restores the start board" % id)
		assert_eq(p.placements_made(), 0, "%s retry clears placements" % id)
		assert_eq(p.replies_made, 0, "%s retry clears replies" % id)
		assert_eq(p.player_hand().size(), d.player_hand.size(), "%s retry refills the hand" % id)
		assert_eq(p.player_captures(), 0, "%s retry clears captures" % id)
		assert_eq(p.play_line(d.solution), &"", "%s solution plays again after retry" % id)
		assert_true(p.evaluate()["success"], "%s clears again after retry" % id)


func test_start_board_matches_the_data() -> void:
	for id: StringName in IDS:
		var d: DossierData = _dossier(id)
		var p: DossierPuzzle = DossierPuzzle.new(d)
		assert_eq(p.state.cells.size(), d.board.size(), "%s board size" % id)
		for b: DossierPlacement in d.board:
			var pc: PlacedCard = p.state.get_card(b.slot)
			var who: int = WallState.P1 if b.side == DataEnums.Side.PLAYER else WallState.P2
			assert_true(pc != null and pc.card == b.card and pc.controller == who and pc.signature == b.is_signature,
					"%s %s holds %s for %s" % [id, b.slot, b.card.id, WallState.player_name(who)])


# --- Hint ------------------------------------------------------------------------------------

func test_hint_follows_the_solution_line() -> void:
	var d: DossierData = _dossier(&"dossier_clean_copy")
	var p: DossierPuzzle = DossierPuzzle.new(d)
	var h: Dictionary = p.hint_move()
	assert_eq(h.get("slot"), &"c1", "first hint: c1")
	assert_eq(h.get("copy_from"), &"c2", "first hint names the Cipher pick")
	p.place(h["card"], h["slot"], h["copy_from"])
	assert_eq(p.hint_move().get("slot"), &"a2", "second hint: a2")
	p.reset()
	p.place(_card(d, &"gold_leaf"), &"b4")
	assert_true(p.hint_move().is_empty(), "off the line: no move hint")


# --- Reward ------------------------------------------------------------------------------------

func test_reward_is_paid_once_only() -> void:
	var fx: RefCounted = Fixtures.new(tree)
	var col: Node = fx.make("dossier_reward")
	var d: DossierData = _dossier(&"dossier_carded")
	assert_false(col.owns(&"null_glyph"), "Null Glyph locked at demo start")
	var p: DossierPuzzle = DossierPuzzle.new(d)
	p.play_line(d.solution)
	assert_true(p.evaluate()["success"], "D4 cleared")
	assert_eq(DossierRewards.reward_lines(d, col), PackedStringArray(["Card: Null Glyph"]), "reward named before payout")
	assert_eq(DossierRewards.pay(d, 1, 12.0, col), DossierRewards.VIA_COLLECTION, "paid through Collection.complete_dossier")
	assert_true(col.owns(&"null_glyph"), "Null Glyph granted")
	assert_true(col.is_dossier_cleared(d.id), "D4 recorded")
	DossierRewards.pay(d, 2, 9.0, col)
	assert_eq(fx.unlocked_cards().filter(func(c: StringName) -> bool: return c == &"null_glyph").size(), 1,
			"card_unlocked(null_glyph) emitted once")
	assert_eq(col.dossier_record(d.id)["attempts"], 1, "first clear's attempts kept")
	assert_true(DossierRewards.reward_lines(d, col).is_empty(), "nothing new to earn after the clear")
	# Title and frame rewards: once each.
	var d5: DossierData = _dossier(&"dossier_clean_copy")
	DossierRewards.pay(d5, 1, 5.0, col)
	DossierRewards.pay(d5, 1, 5.0, col)
	assert_eq(fx.events_named("title_earned").filter(func(e: Array) -> bool: return e[2] == "Copycat").size(), 1, "Copycat once")
	var d3: DossierData = _dossier(&"dossier_lights_out")
	DossierRewards.pay(d3, 1, 5.0, col)
	DossierRewards.pay(d3, 1, 5.0, col)
	assert_eq(fx.events_named("frame_earned").filter(func(e: Array) -> bool: return e[1] == &"flare_up_gold").size(), 1, "flare_up_gold once")
	fx.finish()


func test_d1_falls_back_to_the_title_when_mayday_is_owned() -> void:
	var fx: RefCounted = Fixtures.new(tree)
	var col: Node = fx.make("dossier_d1_title")
	var d: DossierData = _dossier(&"dossier_first_contact")
	var expect: String = "Title: Contact Made" if col.owns(&"mayday") else "Card: Mayday"
	assert_eq(DossierRewards.reward_lines(d, col), PackedStringArray([expect]), "D1 reward wording matches ownership")
	DossierRewards.pay(d, 1, 3.0, col)
	assert_true(col.owns(&"mayday"), "Mayday owned after D1")
	if expect.begins_with("Title"):
		assert_true(col.has_title(d.id), "title Contact Made granted when Mayday was owned")
	fx.finish()

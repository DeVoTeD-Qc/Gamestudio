# Retreat: cards to the BOTTOM of the deck, not twice in a row, never on the Finale or a short
# street, bottom-card tracking for the deck counter, Theo's Slip Away, Scrounger and Tripwire.
extends "res://tests/dd_test_case.gd"

const STREET1: Array = ["Z5", "W6", "M3", "B2"]
const STREET2: Array = ["B4", "B3", "Z2", "Z3"]


func test_retreat_sends_street_to_bottom() -> void:
	var r: DDRun = plain_run(STREET1 + STREET2 + ["M2", "M4", "M5", "M6"])
	var ev: Dictionary = r.retreat()
	check(bool(ev["ok"]), "retreat ok")
	eq(codes(r.street), STREET2, "fresh street comes from the top")
	eq(r.deck.size(), 8, "4 left + 4 returned")
	var bottom4: Array = codes(r.deck.slice(0, 4))
	bottom4.sort()
	var want: Array = STREET1.duplicate()
	want.sort()
	eq(bottom4, want, "the retreated cards are the bottom 4 (deck deals from the back)")
	eq(codes(r.deck.slice(4, 8)), ["M6", "M5", "M4", "M2"], "rest of the deck above them, unchanged")
	check(str(ev["text"]).contains("bottom of the deck"), "log says bottom: " + str(ev["text"]))
	eq(r.hp, 20, "retreat costs no HP")


func test_retreated_cards_come_back_last() -> void:
	var r: DDRun = plain_run(STREET1 + STREET2 + ["M2", "M4", "M5", "M6"])
	r.retreat()
	# search street 2 (B4 B3 Z2 kept? resolve 3, holdover 1), then the next street deals M2 M4 M5
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.BARE)
	eq(codes(r.street).slice(1, 4), ["M2", "M4", "M5"], "unretreated cards are dealt first")
	r.resolve(1, DDRun.USE)
	r.resolve(1, DDRun.USE)
	r.resolve(1, DDRun.USE)
	var seen: Array = codes(r.street).slice(1)
	for c: String in seen:
		check(STREET1.has(c) or c == "M6", "late cards are M6 or the retreated ones: " + c)


func test_bottom_cards_tracked_for_deck_counter() -> void:
	var r: DDRun = plain_run(STREET1 + STREET2 + ["M2", "M4", "M5", "M6"])
	eq(r.bottom_cards().size(), 0, "nothing at the bottom yet")
	r.retreat()
	var b: Array = codes(r.bottom_cards())
	b.sort()
	var want: Array = STREET1.duplicate()
	want.sort()
	eq(b, want, "the 4 retreated cards are listed face up")
	for c: DDCard in r.street:
		check(not c.retreated, "street cards are not flagged")


func test_bottom_flag_clears_when_dealt() -> void:
	var r: DDRun = plain_run(STREET1 + ["B2", "B2", "B2", "B2"])
	r.retreat()
	# deck now: [STREET1 bottom..., (none above after dealing 4 B2)] -> deck holds only the 4 retreated
	eq(r.bottom_cards().size(), 4, "4 waiting")
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	eq(r.bottom_cards().size(), 1, "3 dealt back, 1 still at the bottom")
	for c: DDCard in r.street:
		check(not c.retreated, "dealt cards lose the flag")


func test_not_twice_in_a_row() -> void:
	var r: DDRun = plain_run(STREET1 + STREET2 + filler(12))
	r.retreat()
	check(not r.can_retreat(), "second retreat blocked")
	eq(r.retreat_block_reason(), "you retreated last street", "reason")
	check(not bool(r.retreat()["ok"]), "retreat call rejected")
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.BARE)
	check(r.can_retreat(), "allowed again after a searched street")


func test_no_retreat_on_short_street() -> void:
	var r: DDRun = plain_run(["B2", "B2", "B2", "Z4", "B3", "B3"])
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	eq(r.street.size(), 3, "short street")
	check(not r.can_retreat(), "no retreat on a short street")


func test_no_retreat_on_finale() -> void:
	var r: DDRun = plain_run(["B2", "B2", "B2", "Z4"])
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	check(r.finale_in, "finale dealt")
	check(not r.can_retreat(), "no retreat on the finale")
	eq(r.retreat_block_reason(), "no retreat from the Finale", "reason")


func test_shuffle_mode_still_supported() -> void:
	var b: DDBalance = balance_with({"retreat_mode": "shuffle"})
	var r: DDRun = plain_run(STREET1 + STREET2 + filler(8, "M2"), [], b)
	r.retreat()
	eq(r.deck.size(), 12, "returned into the deck")
	eq(r.bottom_cards().size(), 0, "not tracked as bottom cards in shuffle mode")


func test_scrounger_heals_on_retreat() -> void:
	var r: DDRun = plain_run(STREET1 + STREET2 + filler(8))
	r.perks.append("scrounger")
	r.hp = 15
	var ev: Dictionary = r.retreat()
	eq(r.hp, 16, "+1")
	eq(int(ev["hp_delta"]), 1, "event shows heal")
	r.hp = 20
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.BARE)
	r.retreat()
	eq(r.hp, 20, "capped at max")


func test_tripwire_cover_after_retreat_only() -> void:
	var r: DDRun = plain_run(STREET1 + ["Z2", "B3", "M2", "Z4"] + filler(8))
	r.perks.append("tripwire")
	r.retreat()
	eq(r.cover, 2, "street after a retreat starts with 2 Cover")
	r.resolve(0, DDRun.BARE)
	eq(r.cover, 0, "used on Z2")
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	eq(r.cover, 0, "next street has no tripwire cover")


func test_theo_slip_away() -> void:
	var r: DDRun = make_run("theo", ["M3", "Z9", "Z8", "W2"] + STREET2 + filler(8))
	check(not r.can_slip_away(), "not before resolving a card")
	check(r.can_retreat(), "normal retreat still possible")
	r.hp = 10
	r.resolve(0, DDRun.USE)
	check(r.can_slip_away(), "slip after exactly 1 card")
	var ev: Dictionary = r.slip_away()
	check(bool(ev["ok"]), "slip ok")
	eq(r.hp, 13, "the resolved medkit stays resolved")
	var b: Array = codes(r.bottom_cards())
	b.sort()
	eq(b, ["W2", "Z8", "Z9"], "the other 3 go to the bottom")
	eq(codes(r.street), STREET2, "fresh street")
	check(r.fled_last, "counts as a retreat")
	check(not r.can_retreat(), "no retreat next street")
	r.resolve(0, DDRun.USE)
	check(not r.can_slip_away(), "no slip right after a slip either")


func test_theo_cannot_slip_after_two_cards() -> void:
	var r: DDRun = make_run("theo", ["B2", "B2", "Z2", "Z3"] + filler(8))
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	check(not r.can_slip_away(), "only after exactly 1")
	check(not bool(r.slip_away()["ok"]), "rejected")


func test_others_cannot_slip() -> void:
	var r: DDRun = make_run("rosa", ["B2", "B2", "Z2", "Z3"] + filler(8))
	r.resolve(0, DDRun.USE)
	check(not r.can_slip_away(), "Rosa has no Slip Away")

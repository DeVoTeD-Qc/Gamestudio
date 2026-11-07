# Medkits (one per street), barricade Cover, deck counts.
extends "res://tests/dd_test_case.gd"


func test_medkit_heals_capped() -> void:
	var r: DDRun = plain_run(["M7", "B2", "B2", "B2"] + filler(8))
	r.hp = 16
	var ev: Dictionary = r.resolve(0, DDRun.USE)
	eq(r.hp, 20, "capped at max")
	eq(int(ev["hp_delta"]), 4, "event shows real heal")


func test_second_medkit_same_street_wasted() -> void:
	var r: DDRun = plain_run(["M3", "M5", "B2", "B2"] + filler(8))
	r.hp = 10
	r.resolve(0, DDRun.USE)
	eq(r.hp, 13, "first heals")
	check(not r.medkit_would_heal(), "won't heal badge state")
	var p: Dictionary = r.preview(0, DDRun.USE)
	check(bool(p["wasted"]), "preview says wasted")
	r.resolve(0, DDRun.USE)
	eq(r.hp, 13, "second used up")


func test_medkit_limit_resets_next_street() -> void:
	var r: DDRun = plain_run(["M3", "B2", "B2", "M4", "M5", "B2", "B2"] + filler(8))
	r.hp = 5
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	check(r.medkit_would_heal(), "new street, medkit heals again")
	r.resolve(idx(r, "M5"), DDRun.USE)
	eq(r.hp, 13, "5 + 3 + 5")


func test_imani_triage_two_medkits_plus_one() -> void:
	var r: DDRun = make_run("imani", ["M3", "M4", "M5", "B2"] + filler(8))
	r.hp = 5
	r.resolve(0, DDRun.USE)
	eq(r.hp, 9, "3 + 1 triage bonus")
	r.resolve(0, DDRun.USE)
	eq(r.hp, 14, "second heals, 4 + 1")
	check(not r.medkit_would_heal(), "third won't")
	r.resolve(0, DDRun.USE)
	eq(r.hp, 14, "third wasted")


func test_triage_bonus_follows_balance() -> void:
	var b: DDBalance = balance_with({"triage_heal_bonus": 0})
	var r: DDRun = make_run("imani", ["M3", "B2", "B2", "B2"] + filler(8), [], b)
	r.hp = 5
	r.resolve(0, DDRun.USE)
	eq(r.hp, 8, "no bonus when tuned to 0")


func test_barricade_cover_soaks_then_expires() -> void:
	var r: DDRun = plain_run(["B3", "Z5", "B2", "Z6"] + filler(8))
	r.resolve(0, DDRun.USE)
	eq(r.cover, 3, "cover 3")
	var ev: Dictionary = r.resolve(0, DDRun.BARE)
	eq(r.hp, 18, "5 - 3 cover = 2")
	eq(r.cover, 0, "cover spent")
	check(str(ev["text"]).contains("Cover soaked 3"), "log mentions cover")
	r.resolve(0, DDRun.USE)
	eq(r.cover, 0, "cover gained on the last card is gone at end of street")
	check(r.street[0].code() == "Z6", "Z6 is the holdover")


func test_cover_bigger_than_hit() -> void:
	var r: DDRun = plain_run(["B4", "Z2", "Z3", "B2"] + filler(8))
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.BARE)
	eq(r.hp, 20, "fully soaked")
	eq(r.cover, 2, "2 cover left")
	r.resolve(0, DDRun.BARE)
	eq(r.hp, 19, "3 - 2")


func test_cover_applies_after_weapon() -> void:
	var r: DDRun = plain_run(["B2", "Z9", "B2", "B2"] + filler(8))
	r.weapon = 5
	r.resolve(0, DDRun.USE)
	var p: Dictionary = r.preview(0, DDRun.WEAPON)
	eq(int(p["dmg"]), 4, "9 - 5")
	eq(int(p["absorbed"]), 2, "cover 2")
	eq(int(p["hp_loss"]), 2, "hp loss 2")


func test_deck_counts_by_type() -> void:
	var r: DDRun = plain_run(["B2", "B2", "B2", "B2", "Z5", "W3", "M2", "Z9"])
	var c: Dictionary = r.deck_counts()
	eq(c["Z"], [5, 9], "zombies left")
	eq(c["W"], [3], "weapons left")
	eq(c["M"], [2], "medkits left")
	eq((c["B"] as Array).size(), 0, "barricades left")


func test_card_names() -> void:
	eq(DDText.card_name(DDCard.parse("Z3")), "Shambler", "2-4")
	eq(DDText.card_name(DDCard.parse("Z7")), "Lurcher", "5-7")
	eq(DDText.card_name(DDCard.parse("Z10")), "Bruiser", "8-10")
	eq(DDText.card_name(DDCard.parse("Z11")), "Hulk", "11-14")
	eq(DDText.card_name(DDCard.parse("W9")), "Chainsaw", "weapon 9")
	eq(DDText.card_name(DDCard.parse("M7")), "Trauma Kit", "medkit 7")
	eq(DDText.card_name(DDCard.parse("B4")), "Dumpster", "barricade 4")
	check(DDText.card_rules(DDCard.parse("Z9"), null, bal()).contains("strength 9"), "rules text")

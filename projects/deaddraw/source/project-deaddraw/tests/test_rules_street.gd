# Street loop: deal 4, resolve 3, Holdover, no stopping partway, illegal moves rejected.
extends "res://tests/dd_test_case.gd"


func test_start_deals_four_from_full_deck() -> void:
	var r: DDRun = DDRun.new(bal())
	r.start("rosa", bal().starter_perks(), 5)
	eq(r.street.size(), 4, "street size")
	eq(r.deck.size(), 28 - 4, "Maple Row deck after the first deal")
	eq(r.hp, 20, "start hp")
	eq(r.to_resolve, 3, "resolve 3 of 4")
	eq(r.phase, DDRun.Phase.STREET, "phase")


func test_deck_sizes_are_4_plus_3k() -> void:
	for d: Variant in bal().districts():
		var n: int = DDRun.build_deck(d).size()
		eq((n - 4) % 3, 0, "%s deck size %d is 4+3k" % [str(d["id"]), n])
	eq(DDRun.build_deck(bal().district(0)).size(), 28, "Maple Row 28")
	eq(DDRun.build_deck(bal().district(1)).size(), 31, "Downtown 31")
	eq(DDRun.build_deck(bal().district(2)).size(), 34, "St. Agnes 34")


func test_resolve_three_leaves_holdover() -> void:
	var r: DDRun = plain_run(["B2", "B3", "M2", "Z4", "Z2", "W5", "M3", "B2"] + filler(6))
	eq(codes(r.street), ["B2", "B3", "M2", "Z4"], "street dealt top-first")
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	var ev: Dictionary = r.resolve(0, DDRun.USE)
	check(bool(ev["street_ended"]), "street ended after 3")
	eq((ev["holdover"] as DDCard).code(), "Z4", "Z4 is the holdover")
	eq(codes(r.street), ["Z4", "Z2", "W5", "M3"], "holdover stays, 3 new cards fill the street")
	check(r.street[0].holdover, "holdover flag set")
	check(not r.street[1].holdover, "new cards are not holdovers")
	eq(r.resolved_count, 0, "counter reset")


func test_cannot_stop_partway_or_retreat_after_starting() -> void:
	var r: DDRun = plain_run(["B2", "B3", "M2", "Z4"] + filler(8))
	check(r.can_retreat(), "retreat allowed before resolving")
	r.resolve(0, DDRun.USE)
	check(not r.can_retreat(), "no retreat once searching")
	eq(r.retreat_block_reason(), "you already started searching", "reason")
	var ev: Dictionary = r.retreat()
	check(not bool(ev["ok"]), "retreat call rejected")
	eq(r.street.size(), 3, "street untouched")


func test_illegal_choices_rejected() -> void:
	var r: DDRun = plain_run(["M3", "W5", "Z6", "B2"] + filler(8))
	check(not bool(r.resolve(0, DDRun.WEAPON)["ok"]), "weapon on a medkit")
	check(not bool(r.resolve(1, DDRun.USE)["ok"]), "use on a weapon")
	check(not bool(r.resolve(2, DDRun.EQUIP)["ok"]), "equip a zombie")
	check(not bool(r.resolve(9, DDRun.USE)["ok"]), "index out of range")
	check(not bool(r.resolve(2, DDRun.WEAPON)["ok"]), "no weapon yet")
	eq(r.resolved_count, 0, "nothing resolved")
	eq(r.street.size(), 4, "street intact")


func test_zombie_damage_bare_and_hp_event() -> void:
	var r: DDRun = plain_run(["Z7", "B2", "B2", "B2"] + filler(8))
	var p: Dictionary = r.preview(0, DDRun.BARE)
	eq(int(p["hp_loss"]), 7, "preview bare")
	var ev: Dictionary = r.resolve(0, DDRun.BARE)
	eq(r.hp, 13, "hp after bare 7")
	eq(int(ev["hp_delta"]), -7, "event hp delta")
	check(str(ev["text"]).contains("you took 7"), "log text: " + str(ev["text"]))
	check(r.log_lines[r.log_lines.size() - 1] == str(ev["text"]), "log line recorded")


func test_death_ends_run() -> void:
	var r: DDRun = plain_run(["Z9", "Z8", "Z7", "B2"] + filler(8))
	r.hp = 10
	r.resolve(0, DDRun.BARE)
	eq(r.phase, DDRun.Phase.STREET, "alive at 1")
	var ev: Dictionary = r.resolve(0, DDRun.BARE)
	check(bool(ev["dead"]), "dead flag")
	eq(r.phase, DDRun.Phase.DEAD, "phase dead")
	eq(r.hp, 0, "hp clamps at 0")
	check(not bool(r.resolve(0, DDRun.BARE)["ok"]), "no actions after death")
	check(bool(r.preview(0, DDRun.BARE)["dies"]) == false, "preview disabled after death")


func test_preview_predicts_death() -> void:
	var r: DDRun = plain_run(["Z9", "B2", "B2", "B2"] + filler(8))
	r.hp = 9
	check(bool(r.preview(0, DDRun.BARE)["dies"]), "preview flags a lethal fight")


func test_same_seed_same_deck() -> void:
	var a: DDRun = DDRun.new(bal())
	var b: DDRun = DDRun.new(bal())
	a.start("rosa", bal().starter_perks(), 42)
	b.start("rosa", bal().starter_perks(), 42)
	eq(codes(a.deck), codes(b.deck), "seeded decks match")
	eq(codes(a.street), codes(b.street), "seeded streets match")

# Safehouse (heal, pick 1 of 3) and every perk.
extends "res://tests/dd_test_case.gd"


## Clears the current district quickly: three barricades, a holdover, then the finale bare.
func clear(r: DDRun, holdover: String = "B2") -> void:
	r.setup_street(["B2", "B2", "B2", holdover])
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	while r.phase == DDRun.Phase.STREET:
		var c: DDCard = r.street[0]
		r.resolve(0, DDRun.BARE if c.kind == DDCard.ZOMBIE else DDRun.USE)


func test_safehouse_heals_12_capped() -> void:
	var r: DDRun = plain_run(filler(4))
	r.hp = 20
	clear(r)
	# B2 holdover gives 2 cover vs boss 12 -> 10 damage -> 10 hp, +12 -> capped 20
	eq(r.phase, DDRun.Phase.SAFEHOUSE, "safehouse")
	eq(r.hp, 20, "capped at max")
	var r2: DDRun = plain_run(filler(4))
	r2.hp = 12
	clear(r2)
	eq(r2.hp, 2 + 12, "12 - 10 = 2, +12")


func test_offer_three_distinct_from_pool_excluding_owned() -> void:
	for s: int in 20:
		var r: DDRun = DDRun.new(bal())
		r.start("rosa", bal().starter_perks(), s)
		r.perks.append("field_kit")
		clear(r)
		eq(r.perk_offer.size(), 3, "3 offered")
		var seen: Dictionary = {}
		for p: String in r.perk_offer:
			check(not seen.has(p), "no duplicates")
			seen[p] = true
			check(bal().starter_perks().has(p), "from the unlocked pool: " + p)
			check(p != "field_kit", "owned perk not offered")


func test_choose_perk_moves_on_and_keeps_weapon() -> void:
	var r: DDRun = plain_run(filler(4))
	clear(r)
	r.weapon = 6
	r.notch = 5
	var offered: String = r.perk_offer[0]
	check(not bool(r.choose_perk("not_a_perk")["ok"]), "unknown perk rejected")
	check(not bool(r.choose_perk("")["ok"]), "must pick when offered")
	var ev: Dictionary = r.choose_perk(offered)
	check(bool(ev["ok"]), "picked")
	check(r.perks.has(offered), "perk owned")
	eq(r.district_index, 1, "now Downtown")
	eq(r.phase, DDRun.Phase.STREET, "on the street")
	eq(r.deck.size(), 31 - 4, "Downtown deck dealt")
	if offered != "fire_axe":
		eq(r.weapon, 6, "weapon kept")
		eq(r.notch, 5, "notch kept")


func test_empty_pool_skips_pick() -> void:
	var r: DDRun = DDRun.new(bal())
	var none: Array[String] = []
	r.start("rosa", none, 1)
	clear(r)
	eq(r.perk_offer.size(), 0, "nothing to offer")
	check(bool(r.choose_perk("")["ok"]), "continue without a perk")


func test_thick_jacket() -> void:
	var r: DDRun = plain_run(filler(4))
	clear(r)
	r.perk_offer = ["thick_jacket"]
	r.hp = 15
	r.choose_perk("thick_jacket")
	eq(r.max_hp, 24, "+4 max")
	eq(r.hp, 19, "+4 now")


func test_second_wind_once() -> void:
	var r: DDRun = plain_run(filler(4))
	clear(r)
	r.perk_offer = ["second_wind"]
	r.choose_perk("second_wind")
	r.setup_street(["Z14", "Z9", "B2", "B2"] + filler(8))
	r.hp = 5
	var p: Dictionary = r.preview(0, DDRun.BARE)
	check(bool(p["second_wind"]) and not bool(p["dies"]), "preview shows Second Wind")
	r.resolve(0, DDRun.BARE)
	eq(r.hp, 1, "stays at 1")
	eq(r.phase, DDRun.Phase.STREET, "alive")
	r.resolve(0, DDRun.BARE)
	eq(r.phase, DDRun.Phase.DEAD, "only once")


func test_fire_axe_rules() -> void:
	# weaker weapon -> fresh axe
	var r: DDRun = plain_run(filler(4))
	clear(r)
	r.perk_offer = ["fire_axe"]
	r.weapon = 5
	r.choose_perk("fire_axe")
	eq(r.weapon, 7, "axe equipped")
	eq(r.notch, DDRun.NO_NOTCH, "fresh")
	# stronger fresh weapon kept
	var r2: DDRun = plain_run(filler(4))
	clear(r2)
	r2.perk_offer = ["fire_axe"]
	r2.weapon = 9
	r2.notch = DDRun.NO_NOTCH
	r2.choose_perk("fire_axe")
	eq(r2.weapon, 9, "chainsaw kept")
	# stronger but notched -> axe
	var r3: DDRun = plain_run(filler(4))
	clear(r3)
	r3.perk_offer = ["fire_axe"]
	r3.weapon = 9
	r3.notch = 6
	r3.choose_perk("fire_axe")
	eq(r3.weapon, 7, "notched chainsaw swapped for a fresh axe")


func test_field_kit() -> void:
	var r: DDRun = plain_run(["M4", "B2", "B2", "B2"] + filler(8))
	r.perks.append("field_kit")
	r.hp = 10
	r.resolve(0, DDRun.USE)
	eq(r.hp, 15, "4 + 1")


func test_knuckle_wraps_bare_only() -> void:
	var r: DDRun = plain_run(["Z5", "Z1", "Z6", "B2"] + filler(8))
	r.perks.append("knuckle_wraps")
	r.resolve(0, DDRun.BARE)
	eq(r.hp, 17, "5 - 2")
	r.resolve(0, DDRun.BARE)
	eq(r.hp, 17, "minimum 0")
	r.weapon = 4
	r.resolve(0, DDRun.WEAPON)
	eq(r.hp, 15, "weapon fights unchanged: 6 - 4")


func test_sandbags() -> void:
	var r: DDRun = plain_run(["B3", "B2", "B2", "B2"] + filler(8))
	r.perks.append("sandbags")
	r.resolve(0, DDRun.USE)
	eq(r.cover, 5, "3 + 2")


func test_perk_texts_exist() -> void:
	for p: String in bal().all_perks():
		check(DDText.perk_text(p, bal()) != "", "text for " + p)
		check(DDText.perk_name(p) != p, "name for " + p)

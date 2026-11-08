# Safehouse (heal, pick 1 of 3) and every v2 perk.
extends "res://tests/dd_test_case.gd"


func test_safehouse_heals_capped() -> void:
	var r: DDRun = plain_run([])
	clear_district(r)
	eq(r.phase, DDRun.Phase.SAFEHOUSE, "safehouse")
	eq(r.hp, r.max_hp, "capped at max")
	var r2: DDRun = plain_run([])
	r2.hp = r2.max_hp
	to_boss_wave(r2, [], [])
	r2.resolve(0, DDRun.BARE)
	var boss: int = int((r2.bal.district(0)["finale"]["zombies"] as Array)[0])
	eq(r2.hp, mini(r2.max_hp, r2.max_hp - boss + bal().num("safehouse_heal")), "heal after the boss")


func test_offer_three_distinct_from_pool_excluding_owned() -> void:
	for s: int in 10:
		var r: DDRun = DDRun.new(bal())
		r.start("rosa", bal().starter_perks(), s)
		r.perks.append("field_kit")
		clear_district(r)
		eq(r.perk_offer.size(), 3, "3 offered")
		var seen: Dictionary = {}
		for p: String in r.perk_offer:
			check(not seen.has(p), "no duplicates")
			seen[p] = true
			check(bal().starter_perks().has(p), "from the unlocked pool: " + p)
			check(p != "field_kit", "owned perk not offered")


func test_choose_perk_moves_on_and_keeps_kit() -> void:
	var r: DDRun = plain_run([])
	gun(r, 1, "revolver")
	r.reserve = 9
	r.points = 33
	clear_district(r)
	var offered: String = r.perk_offer[0]
	check(not bool(r.choose_perk("not_a_perk")["ok"]), "unknown perk rejected")
	check(not bool(r.choose_perk("")["ok"]), "must pick when offered")
	check(bool(r.choose_perk(offered)["ok"]), "picked")
	eq(r.district_index, 1, "now Downtown")
	eq(r.wave_index, 0, "wave 1")
	eq(r.phase, DDRun.Phase.STREET, "on the street")
	check(r.slot(1) != null and r.slot(1).wid == "revolver" or offered == "fire_axe", "weapons kept")
	check(r.reserve >= 9, "ammo kept")


func _with_perk(id: String, deck: Array = []) -> DDRun:
	var r: DDRun = plain_run([])
	clear_district(r)
	r.perk_offer = [id] as Array[String]
	r.choose_perk(id)
	if not deck.is_empty():
		r.setup_street(deck)
	return r


func test_thick_jacket() -> void:
	var r: DDRun = plain_run([])
	clear_district(r)
	r.perk_offer = ["thick_jacket"] as Array[String]
	r.hp = 15
	var m0: int = r.max_hp
	r.choose_perk("thick_jacket")
	eq(r.max_hp, m0 + bal().rule("thick_jacket_hp"), "+4 max")
	eq(r.hp, 15 + bal().rule("thick_jacket_hp"), "+4 now")


func test_field_kit_and_knuckle_wraps() -> void:
	var r: DDRun = _with_perk("field_kit", ["M3", "B2", "B2", "B2"] + filler(4))
	r.hp = 5
	r.resolve(0, DDRun.USE)
	eq(r.hp, 5 + 3 + bal().rule("field_kit_bonus"), "medkit +1")
	var k: DDRun = _with_perk("knuckle_wraps", ["Z5", "B2", "B2", "B2"] + filler(4))
	eq(int(k.preview(0, DDRun.BARE)["hp_loss"]), 5 - bal().rule("knuckle_wraps_reduction"), "bare -2")


func test_bandolier_and_fast_hands() -> void:
	var r: DDRun = plain_run([])
	clear_district(r)
	r.perk_offer = ["bandolier"] as Array[String]
	r.reserve = 1
	r.choose_perk("bandolier")
	eq(r.reserve, 1 + bal().num("bandolier_reserve"), "+2 reserve at the wave start")
	var f: DDRun = _with_perk("fast_hands", ["Z5", "Z2", "B2", "B2"] + filler(8))
	check(f.free_reload, "free reload ready")
	f.resolve(0, DDRun.SLOT1)
	eq(int(f.reload_preview(0)["cost"]), 0, "first reload free")
	f.reload(0)
	eq(f.actions_used, 1, "no action spent")
	check(not f.free_reload, "used up for this wave")


func test_second_wind_and_tripwire() -> void:
	var s: DDRun = _with_perk("second_wind", ["Z20", "B2", "B2", "B2"] + filler(4))
	check(s.second_wind, "armed")
	s.hp = 3
	s.resolve(0, DDRun.BARE)
	eq(s.hp, 1, "saved at 1")
	var t: DDRun = _with_perk("tripwire", filler(12))
	t.skip()
	eq(t.cover, bal().rule("tripwire_cover"), "Cover after a skip")


func test_axe_in_the_trunk() -> void:
	var r: DDRun = plain_run([])
	clear_district(r)
	r.perk_offer = ["fire_axe"] as Array[String]
	r.choose_perk("fire_axe")
	var found: bool = false
	for w: Variant in r.slots:
		if w != null and (w as DDWeapon).wid == "axe":
			found = true
			eq((w as DDWeapon).power, bal().num("fire_axe_power"), "axe power from CONFIG")
	check(found, "a Fire Axe went into the empty slot")

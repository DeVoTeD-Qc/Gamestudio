# Finale streets (face-up, joined by the Holdover, resolve all), traits, short streets,
# district structure.
extends "res://tests/dd_test_case.gd"


func _to_finale(r: DDRun, last: String = "Z4") -> void:
	r.setup_street(["B2", "B2", "B2", last])
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)


func test_finale_joins_holdover_and_must_resolve_all() -> void:
	var r: DDRun = plain_run(filler(4))
	_to_finale(r)
	check(r.finale_in, "finale dealt")
	eq(codes(r.street), ["Z4", "Z12"], "holdover + The Groundskeeper")
	eq(r.to_resolve, 2, "resolve every card")
	eq(r.street[1].boss_trait, "shatter", "boss trait")
	eq(DDText.card_name(r.street[1]), "The Groundskeeper", "boss name")
	r.resolve(0, DDRun.BARE)
	eq(r.phase, DDRun.Phase.STREET, "not cleared with the boss still up")
	r.resolve(0, DDRun.BARE)
	eq(r.phase, DDRun.Phase.SAFEHOUSE, "cleared -> safehouse")


func test_finale_visible_from_start() -> void:
	var r: DDRun = DDRun.new(bal())
	r.start("rosa", bal().starter_perks(), 3)
	eq(codes(r.finale_cards()), ["Z12"], "Maple Row finale known up front")
	check(DDText.finale_summary(r.finale()).contains("The Groundskeeper"), "summary")


func test_shatter_breaks_weapon_but_reduces_damage() -> void:
	var r: DDRun = plain_run(filler(4))
	_to_finale(r, "M2")
	r.weapon = 9
	r.resolve(0, DDRun.USE)
	var ev: Dictionary = r.resolve(0, DDRun.WEAPON)
	check(bool((ev["preview"] as Dictionary)["breaks"]), "breaks flag")
	eq(r.district_scores[0], 10 + 20 - 3, "took 3, score 10 + 17")
	eq(r.weapon, 0, "weapon broke")


func test_horde_ordered_one_weapon() -> void:
	var r: DDRun = plain_run(filler(4))
	r.district_index = 1
	_to_finale(r, "M2")
	eq(codes(r.street), ["M2", "Z10", "Z9", "Z8"], "Rush Hour Horde arrives at once")
	r.weapon = 8
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.WEAPON)
	check(r.can_use_weapon_on(9), "9 under the notch of 10")
	r.resolve(0, DDRun.WEAPON)
	r.resolve(0, DDRun.WEAPON)
	eq(r.district_scores[0], 10 + 20 - 3, "2 + 1 + 0 damage")
	eq(r.phase, DDRun.Phase.SAFEHOUSE, "cleared")


func test_horde_wrong_order_blocks_weapon() -> void:
	var r: DDRun = plain_run(filler(4))
	r.district_index = 1
	_to_finale(r, "B2")
	r.weapon = 8
	r.resolve(3, DDRun.WEAPON)  # the 8 first
	check(not r.can_use_weapon_on(9), "now the 9 is blocked")
	check(not r.can_use_weapon_on(10), "and the 10")


func test_quarantine_no_heal_on_finale_and_win() -> void:
	var r: DDRun = plain_run(filler(4))
	r.district_index = 2
	_to_finale(r, "M8")
	check(r.is_quarantine(), "quarantine active")
	r.hp = 16
	check(not r.medkit_would_heal(), "won't heal")
	var ev: Dictionary = r.resolve(0, DDRun.USE)
	eq(r.hp, 16, "no heal")
	check(str(ev["text"]).contains("Quarantine"), "log explains")
	r.resolve(0, DDRun.BARE)
	eq(r.phase, DDRun.Phase.WON, "clearing St. Agnes wins the run")


func test_quarantine_only_on_finale_street() -> void:
	var r: DDRun = plain_run(["M8", "B2", "B2", "B2"] + filler(8))
	r.district_index = 2
	r.hp = 10
	r.resolve(0, DDRun.USE)
	eq(r.hp, 18, "medkits heal before the finale in St. Agnes")


func test_short_street_resolves_all_but_one() -> void:
	var r: DDRun = plain_run(["B2", "B2", "B2", "Z4", "B3", "M2"])
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	eq(r.street.size(), 3, "Z4 + 2 new")
	eq(r.to_resolve, 2, "all but one")
	r.resolve(1, DDRun.USE)
	r.resolve(1, DDRun.USE)
	check(r.finale_in, "then the finale")
	eq(codes(r.street), ["Z4", "Z12"], "holdover joins the finale")


func test_full_maple_row_structure() -> void:
	var r: DDRun = DDRun.new(bal())
	r.start("rosa", bal().starter_perks(), 11)
	r.max_hp = 999
	r.hp = 999
	var guard: int = 0
	while r.phase == DDRun.Phase.STREET and guard < 100:
		guard += 1
		var c: DDCard = r.street[0]
		r.resolve(0, DDRun.BARE if c.kind == DDCard.ZOMBIE else (DDRun.SCRAP if c.kind == DDCard.WEAPON else DDRun.USE))
	eq(r.phase, DDRun.Phase.SAFEHOUSE, "district cleared")
	eq(r.streets_played, 10, "9 normal streets + the finale street")
	eq(guard, 28 + 1, "every card + the boss resolved once")
	eq(r.cleared_ids, ["maple_row"], "cleared id")

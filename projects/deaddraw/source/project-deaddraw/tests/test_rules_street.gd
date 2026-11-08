# v2 street basics: start kit, street of 4 with 3 actions, Holdover, the card types, equip/scrap
# into two slots, medkit limit, Cover, short streets.
extends "res://tests/dd_test_case.gd"


func test_run_start_state() -> void:
	var r: DDRun = DDRun.new(bal())
	r.start("rosa", bal().starter_perks(), 5)
	var kit: Array = bal().list("start_kit")
	check(r.slot(0) != null and r.slot(0).wid == str(kit[0]), "slot 1 holds the start kit")
	eq(r.slot(0).ammo, bal().weapon_mag(str(kit[0])), "full magazine")
	check(r.slot(1) == null, "slot 2 empty")
	eq(r.reserve, bal().num("start_reserve"), "start reserve")
	eq(r.points, bal().num("start_points"), "start points")
	eq(r.hp, bal().survivor_hp("rosa"), "start HP")
	eq(r.wave_index, 0, "wave 1")
	var wave1: int = bal().wave_zombies(0, 0).size()
	var entrance: int = (bal().district(0).get("entrance", []) as Array).size()
	eq(r.street.size(), 4, "street of 4")
	eq(r.deck.size() + r.street.size(), wave1 + entrance, "deck = wave 1 pack + Entrance loot")
	eq(r.budget, bal().num("actions_per_street"), "3 actions")
	var carriers: int = 0
	for c: DDCard in r.deck + r.street:
		if c.drop != "":
			carriers += 1
	eq(carriers, 1, "one Carrier in the wave pack")


func test_three_actions_then_holdover_and_refill() -> void:
	var r: DDRun = plain_run(["B2", "M3", "A3", "Z4", "Z2", "Z2", "B3", "B3"])
	eq(codes(r.street), ["B2", "M3", "A3", "Z4"], "dealt top first")
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	eq(r.actions_left(), 1, "one action left")
	var ev: Dictionary = r.resolve(0, DDRun.USE)
	check(bool(ev["street_ended"]), "street ended after 3 actions")
	eq(r.street.size(), 4, "refilled to 4")
	eq(r.street[0].code(), "Z4", "the Holdover stays first")
	check(r.street[0].holdover, "marked as Holdover")
	eq(r.actions_used, 0, "fresh actions")


func test_choices_per_kind() -> void:
	var r: DDRun = plain_run(["Z5", "W:revolver", "M3", "A4"] + filler(4))
	eq(r.choices_for(idx(r, "Z5")), [DDRun.SLOT1, DDRun.SLOT2, DDRun.BARE] as Array[String], "zombie: slot 1 / slot 2 / bare")
	eq(r.choices_for(idx(r, "W:revolver")), [DDRun.EQUIP1, DDRun.EQUIP2, DDRun.SCRAP] as Array[String], "weapon: slot 1 / slot 2 / scrap")
	eq(r.choices_for(idx(r, "M3")), [DDRun.USE] as Array[String], "medkit: use")
	eq(r.choices_for(idx(r, "A4")), [DDRun.USE] as Array[String], "ammo: use")
	check(not bool(r.preview(idx(r, "Z5"), DDRun.SLOT2)["enabled"]), "empty slot 2 can't fight")
	eq(str(r.preview(idx(r, "Z5"), DDRun.SLOT2)["reason"]), "slot empty", "reason given")


func test_equip_into_slots_and_scrap_pay_points() -> void:
	var scrap: int = int(bal().points("scrap"))
	var r: DDRun = plain_run(["W:revolver", "W:machete", "W:knife", "B2"] + filler(4))
	var p0: int = r.points
	r.resolve(idx(r, "W:revolver"), DDRun.EQUIP2)
	eq(r.slot(1).wid, "revolver", "revolver in slot 2")
	eq(r.slot(1).ammo, bal().weapon_mag("revolver"), "arrives with a full magazine")
	eq(r.points, p0, "empty slot: no scrap points")
	var pr: Dictionary = r.preview(idx(r, "W:machete"), DDRun.EQUIP1)
	eq(str(pr["replaces"]), r.slot(0).display_name(), "preview names the weapon it replaces")
	r.resolve(idx(r, "W:machete"), DDRun.EQUIP1)
	eq(r.slot(0).wid, "machete", "machete replaced the pistol")
	eq(r.slot(0).power, bal().weapon_power("machete"), "melee power includes the melee bonus")
	eq(r.points, p0 + scrap, "replaced weapon scrapped for points")
	r.resolve(idx(r, "W:knife"), DDRun.SCRAP)
	eq(r.points, p0 + scrap * 2, "scrap pays")
	eq(r.points_earned, scrap * 2, "earned counts it")


func test_ammo_card_fills_reserve_to_cap() -> void:
	var r: DDRun = plain_run(["A5", "A5", "B2", "B2"] + filler(4))
	r.reserve = bal().num("reserve_cap") - 2
	var pr: Dictionary = r.preview(0, DDRun.USE)
	eq(int(pr["ammo_gain"]), 2, "capped gain previewed")
	r.resolve(0, DDRun.USE)
	eq(r.reserve, bal().num("reserve_cap"), "reserve at cap")


func test_medkit_one_heal_per_street() -> void:
	var r: DDRun = plain_run(["M3", "M5", "B2", "B2"] + filler(4))
	r.hp = 5
	r.resolve(0, DDRun.USE)
	eq(r.hp, 8, "first medkit heals")
	var pr: Dictionary = r.preview(0, DDRun.USE)
	check(bool(pr["wasted"]), "second one won't heal")
	r.resolve(0, DDRun.USE)
	eq(r.hp, 8, "no heal")


func test_cover_soaks_then_clears() -> void:
	var r: DDRun = plain_run(["B3", "Z5", "B2", "B2"] + filler(4))
	r.resolve(0, DDRun.USE)
	eq(r.cover, 3, "cover 3")
	var hp0: int = r.hp
	var pr: Dictionary = r.preview(0, DDRun.BARE)
	eq(int(pr["absorbed"]), 3, "cover soaks 3")
	r.resolve(0, DDRun.BARE)
	eq(r.hp, hp0 - 2, "took 2")
	r.resolve(0, DDRun.USE)
	eq(r.cover, 0, "new street, cover gone")


func test_short_street_resolves_all_but_one() -> void:
	var r: DDRun = plain_run([], ["B2", "B2", "B3"])
	eq(r.street.size(), 3, "3 cards, deck empty")
	eq(r.budget, 2, "resolve all but one")
	check(r.is_last_street(), "last street of the wave")
	check(not r.can_skip(), "short street can't be skipped")


func test_reload_counts_as_an_action_and_leaves_two_holdovers() -> void:
	var r: DDRun = plain_run(["Z4", "Z3", "B2", "B2", "B3", "B3", "B3", "B3"])
	r.resolve(idx(r, "Z4"), DDRun.SLOT1)
	r.reload(0)
	eq(r.actions_left(), 1, "reload used an action")
	r.resolve(idx(r, "Z3"), DDRun.SLOT1)
	eq(r.street.size(), 4, "refilled")
	eq(codes(r.street).slice(0, 2), ["B2", "B2"], "two cards held over")

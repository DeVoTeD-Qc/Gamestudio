# Weapons and the Notch rule; Equip / Scrap.
extends "res://tests/dd_test_case.gd"


func _armed(power: int, deck: Array) -> DDRun:
	var r: DDRun = plain_run(deck)
	r.weapon = power
	r.notch = DDRun.NO_NOTCH
	return r


func test_fresh_weapon_hits_anything() -> void:
	var r: DDRun = _armed(6, ["Z14", "B2", "B2", "B2"] + filler(8))
	check(r.can_use_weapon_on(14), "fresh weapon hits 14")
	var ev: Dictionary = r.resolve(0, DDRun.WEAPON)
	eq(r.hp, 20 - 8, "14 - 6 = 8 damage")
	eq(r.notch, 14, "notch at 14")
	check(str(ev["text"]).contains("Machete blocked 6"), "log names weapon and block: " + str(ev["text"]))


func test_damage_minimum_zero() -> void:
	var r: DDRun = _armed(7, ["Z3", "B2", "B2", "B2"] + filler(8))
	r.resolve(0, DDRun.WEAPON)
	eq(r.hp, 20, "no damage when power > strength")
	eq(r.notch, 3, "still notched at 3")


func test_notch_blocks_equal_and_higher() -> void:
	var r: DDRun = _armed(6, ["Z9", "Z9", "Z10", "Z8"] + filler(8))
	r.resolve(0, DDRun.WEAPON)
	eq(r.notch, 9, "notch 9")
	check(not r.can_use_weapon_on(9), "cannot hit equal")
	check(not r.can_use_weapon_on(10), "cannot hit higher")
	check(r.can_use_weapon_on(8), "can hit lower")
	var p: Dictionary = r.preview(0, DDRun.WEAPON)
	check(not bool(p["enabled"]), "weapon option disabled on 9")
	eq(str(p["reason"]), "hits under 9", "reason tag")
	eq(r.weapon_block_reason(10), "hits under 9", "reason on 10")


func test_notch_chain_lowers() -> void:
	var r: DDRun = _armed(6, ["Z9", "Z4", "Z3", "Z2"] + filler(8))
	r.resolve(0, DDRun.WEAPON)
	r.resolve(0, DDRun.WEAPON)
	eq(r.notch, 4, "notch now 4")
	check(r.can_use_weapon_on(3), "hits 3")
	check(not r.can_use_weapon_on(4), "not 4")
	check(not r.can_use_weapon_on(5), "not 5")


func test_bare_hands_keeps_notch() -> void:
	var r: DDRun = _armed(6, ["Z9", "Z2", "Z8", "B2"] + filler(8))
	r.resolve(0, DDRun.WEAPON)
	r.resolve(0, DDRun.BARE)
	eq(r.notch, 9, "bare fight leaves the notch alone")
	eq(r.weapon, 6, "weapon kept")
	check(r.can_use_weapon_on(8), "still hits 8")


func test_can_choose_bare_when_weapon_allowed() -> void:
	var r: DDRun = _armed(6, ["Z5", "B2", "B2", "B2"] + filler(8))
	check(bool(r.preview(0, DDRun.BARE)["enabled"]), "bare always allowed")
	r.resolve(0, DDRun.BARE)
	eq(r.hp, 15, "bare 5")


func test_equip_replaces_and_resets_notch() -> void:
	var r: DDRun = _armed(6, ["Z9", "W3", "B2", "B2"] + filler(8))
	r.resolve(0, DDRun.WEAPON)
	var ev: Dictionary = r.resolve(0, DDRun.EQUIP)
	eq(r.weapon, 3, "new weapon")
	eq(r.notch, DDRun.NO_NOTCH, "fresh, no notch")
	check(str(ev["text"]).contains("dropped Machete"), "old weapon discarded in log")


func test_scrap_keeps_current_weapon() -> void:
	var r: DDRun = _armed(6, ["Z9", "W2", "B2", "B2"] + filler(8))
	r.resolve(0, DDRun.WEAPON)
	r.resolve(0, DDRun.SCRAP)
	eq(r.weapon, 6, "weapon unchanged")
	eq(r.notch, 9, "notch unchanged")


func test_no_scrap_when_config_forbids() -> void:
	var b: DDBalance = balance_with({"weapon_scrap": false})
	var r: DDRun = plain_run(["W2", "B2", "B2", "B2"] + filler(8), [], b)
	r.weapon = 6
	eq(r.choices_for(0), [DDRun.EQUIP], "only equip")
	check(not bool(r.resolve(0, DDRun.SCRAP)["ok"]), "scrap rejected")


func test_rosa_steady_hands_hits_equal() -> void:
	var r: DDRun = make_run("rosa", ["Z9", "Z9", "Z10", "B2"] + filler(8))
	r.weapon = 6
	r.resolve(0, DDRun.WEAPON)
	check(r.can_use_weapon_on(9), "Rosa hits equal to the notch")
	check(not r.can_use_weapon_on(10), "but not higher")
	eq(r.weapon_block_reason(10), "hits 9 or less", "Rosa reason text")


func test_no_weapon_reason() -> void:
	var r: DDRun = plain_run(["Z4", "B2", "B2", "B2"] + filler(8))
	eq(r.weapon_block_reason(4), "no weapon", "bare hands")
	eq(DDText.notch_tag(DDRun.NO_NOTCH, ""), "fresh: hits anything", "fresh tag")

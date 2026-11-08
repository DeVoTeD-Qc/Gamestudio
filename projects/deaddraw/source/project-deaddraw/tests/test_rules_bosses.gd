# Bosses (face-up, wave 3's boss street): Shatter destroys the weapon used, Horde arrives all at
# once, Quarantine blocks healing; boss kills pay the boss bonus; reloads are free on the boss street.
extends "res://tests/dd_test_case.gd"


func test_maple_row_groundskeeper_shatter() -> void:
	var r: DDRun = plain_run([])
	to_boss_wave(r, [], [])
	eq(r.street.size(), 1, "the boss alone")
	var c: DDCard = r.street[0]
	eq(c.boss_trait, "shatter", "The Groundskeeper")
	gun(r, 1, "sledge")
	var pr: Dictionary = r.preview(0, DDRun.SLOT2)
	check(bool(pr["breaks"]), "preview warns the weapon breaks")
	var p0: int = r.points
	r.resolve(0, DDRun.SLOT2)
	check(r.slot(1) == null, "weapon destroyed")
	eq(r.points - p0, int(c.value * bal().points("kill")) + int(bal().points("up_close")) + int(bal().points("boss")), "boss bonus paid")
	eq(r.phase, DDRun.Phase.SAFEHOUSE, "district cleared")


func test_downtown_horde_and_free_reload() -> void:
	var r: DDRun = plain_run([])
	clear_district(r)
	r.choose_perk(r.perk_offer[0] if not r.perk_offer.is_empty() else "")
	to_boss_wave(r, [], ["B2"])
	var fin: Array = r.finale().get("zombies", [])
	eq(r.street.size(), 1 + fin.size(), "Holdover + the whole horde")
	eq(r.street[1].boss_trait, "horde", "Horde")
	var w: DDWeapon = r.slot(0)
	w.ammo = 0
	r.reserve = 10
	var pr: Dictionary = r.reload_preview(0)
	eq(int(pr["cost"]), 0, "reload is free on the boss street")
	eq(str(pr["free_why"]), "boss street", "and says why")
	r.reload(0)
	eq(r.actions_used, 0, "no action used")


func test_st_agnes_quarantine() -> void:
	var r: DDRun = plain_run([])
	for k: int in 2:
		clear_district(r)
		r.choose_perk(r.perk_offer[0] if not r.perk_offer.is_empty() else "")
	eq(r.district_index, 2, "St. Agnes")
	to_boss_wave(r, [], ["M5"])
	check(r.is_quarantine(), "Quarantine")
	r.hp = 10
	var pr: Dictionary = r.preview(idx(r, "M5"), DDRun.USE)
	check(bool(pr["wasted"]), "medkit won't heal")
	r.resolve(idx(r, "M5"), DDRun.USE)
	eq(r.hp, 10, "no heal")
	r.hp = 40
	r.max_hp = 40
	r.resolve(0, DDRun.BARE)
	eq(r.phase, DDRun.Phase.WON, "beating Patient Zero wins the run")

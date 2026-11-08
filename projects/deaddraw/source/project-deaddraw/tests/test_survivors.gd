# Survivors: HP from CONFIG, passives (Steady Hands, Triage, Slip Away), Theo starts locked.
extends "res://tests/dd_test_case.gd"


func test_survivor_hp() -> void:
	for s: String in bal().survivor_ids():
		var r: DDRun = make_run(s)
		eq(r.hp, bal().survivor_hp(s), s + " HP")
		eq(r.passive, str(bal().survivor(s)["passive"]), s + " passive")


func test_imani_triage_two_heals() -> void:
	var r: DDRun = make_run("imani", ["M3", "M3", "M3", "B2"] + filler(4))
	r.hp = 2
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	var bonus: int = bal().num("triage_heal_bonus")
	eq(r.hp, 2 + (3 + bonus) * 2, "two medkits heal")
	check(bool(r.preview(0, DDRun.USE)["wasted"]), "the third won't")


func test_theo_slip_away() -> void:
	var r: DDRun = make_run("theo", ["Z9", "M3", "Z8", "Z7"] + filler(8))
	check(not r.can_slip_away(), "not before acting")
	r.resolve(idx(r, "M3"), DDRun.USE)
	check(r.can_slip_away(), "after exactly 1 card")
	r.slip_away()
	eq(r.skipped.size(), 3, "the other 3 skipped")
	check(not r.can_skip(), "still no two skips in a row")


func test_theo_locked_on_fresh_profile() -> void:
	var p: DDProfile = DDProfile.new(bal(), "user://dd_test_surv_unused.json")
	check(not p.survivor_unlocked("theo"), "Theo locked")
	check(p.survivor_unlocked("rosa") and p.survivor_unlocked("imani"), "Rosa and Imani open")

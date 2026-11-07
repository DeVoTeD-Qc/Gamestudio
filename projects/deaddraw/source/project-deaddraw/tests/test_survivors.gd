# Survivors: HP, passives, availability.
extends "res://tests/dd_test_case.gd"


func test_survivor_hp() -> void:
	eq(make_run("rosa").max_hp, 20, "Rosa 20")
	eq(make_run("imani").max_hp, 20, "Imani 20")
	var t: DDRun = make_run("theo")
	eq(t.max_hp, 24, "Theo 24")
	eq(t.hp, 24, "Theo starts full")


func test_passives() -> void:
	eq(make_run("rosa").passive, "steady_hands", "Rosa")
	eq(make_run("imani").passive, "triage", "Imani")
	eq(make_run("theo").passive, "slip_away", "Theo")
	for p: String in ["steady_hands", "triage", "slip_away"]:
		check(DDText.passive_text(p, bal()) != "", "text " + p)


func test_imani_normal_heal_limit_for_others() -> void:
	var r: DDRun = make_run("rosa", ["M3", "M4", "B2", "B2"] + filler(8))
	r.hp = 5
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	eq(r.hp, 8, "Rosa: one medkit, no bonus")


func test_theo_locked_on_fresh_profile() -> void:
	var prof: DDProfile = DDProfile.new(bal(), "user://dd_test_surv.json")
	check(prof.survivor_unlocked("rosa"), "Rosa starts unlocked")
	check(prof.survivor_unlocked("imani"), "Imani starts unlocked")
	check(not prof.survivor_unlocked("theo"), "Theo locked")
	eq(prof.unlock_milestone_for("survivor:theo"), "downtown", "unlocked by Downtown")

# v3 Patches (permanent perks from the Patch Press / boss reward) and survivor passives.
extends "res://tests/dd_test_case.gd"


func test_thick_jacket() -> void:
	var r: DDRun = plain_run(filler(8))
	r.pending_patch = {"offer": ["thick_jacket", "brawler"], "source": "press", "room": 1}
	r.take_patch("thick_jacket")
	eq(r.max_hp, 24, "+4 max HP")
	eq(r.hp, 24, "and heal 4")


func test_brawler() -> void:
	var r: DDRun = plain_run(filler(8))
	r.patches.append("brawler")
	eq(r.melee_power(), 4, "melee 2 + 2")


func test_bounty_hunter_and_trophy_belt() -> void:
	var r: DDRun = plain_run(filler(8), ["Z3", "C2", "C2", "C2"])
	r.patches.append_array(["bounty", "trophy_belt"])
	gun(r, 0, "pistol", [3, 3, 3])
	r.hp = 10
	var p0: int = r.points
	r.attack(0, 0)
	eq(r.points - p0, 3 + bal().num("finish_bonus") + 4, "Bounty Hunter: +1 per zombie in the stack")
	eq(r.hp, 10 - 1 + bal().num("trophy_belt_heal"), "Trophy Belt: heal 2 on a finish")


func test_loose_grip_resets_each_wave() -> void:
	var r: DDRun = plain_run(["Z1"], [])
	r.patches.append("loose_grip")
	r.loose = false
	r.pile.clear()
	r.street.clear()
	r.setup_street([], [])
	check(r.loose, "a new wave gives Loose Grip back")


func test_second_wind_listed_and_text() -> void:
	for p: String in bal().patches():
		check(DDText.patch_text(p, bal()) != "", "Patch %s has rules text" % p)
		check(DDText.patch_name(p) != p or p == "", "Patch %s has a name" % p)
	eq(bal().patches().size(), 8, "8 Patches")


func test_survivor_passives() -> void:
	eq(DDText.passive_name("steady_hands"), "Steady Hands", "Rosa")
	var t: DDRun = make_run("theo", filler(8), ["Z9", "Z9", "Z9", "Z9"])
	eq(t.run_cost(), 0, "Theo: Run costs nothing")
	var r: DDRun = make_run("rosa")
	eq(r.run_cost(), 1, "others: 1")

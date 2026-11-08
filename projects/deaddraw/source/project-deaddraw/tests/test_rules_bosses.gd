# v3 bosses and district ends: the boss street (Holdover + boss cards, resolve every card),
# Shatter (the killing gun is finished, no challenge), Horde (6/6/6 at once), Patient Zero's
# phases (8 -> 10 -> 12, each appears when the last dies) and NO ESCAPE (no Run, no run-past),
# run past a district boss (3 damage, no reward), boss reward (+10, free Patch pick 1 of 3),
# safehouse heal 8, win score.
extends "res://tests/dd_test_case.gd"


func test_boss_street_holdover_plus_boss() -> void:
	var r: DDRun = plain_run([], [])
	to_boss(r, ["M4"])
	check(r.boss_street, "boss street")
	eq(codes(r.street), ["M4", "Z9"], "Holdover + The Groundskeeper 9")
	check(r.street[1].is_boss(), "boss card")
	eq(r.cards_left_to_resolve(), 2, "resolve every card")


func test_groundskeeper_shatter() -> void:
	var r: DDRun = plain_run([], [])
	gun(r, 0, "pistol", [1, 2])
	to_boss(r, [])
	r.cover = 30
	var p0: int = r.points
	var pr: Dictionary = r.preview(0, 0)
	check(bool(pr["shatter"]) and bool(pr["finishes"]), "preview: Shatter finishes the gun")
	check(not bool(pr["challenge"]), "no challenge")
	var ev: Dictionary = r.attack(0, 0)
	eq(r.slot(0), null, "the pistol is finished")
	var info: Dictionary = ev["collects"][0]
	check(bool(info["shatter"]) and bool(info["finished"]), "shatter collect")
	check(not bool(info["challenge"]), "no challenge even though 1-2-9 are all different")
	check(bool(ev["district_cleared"]), "district cleared")
	eq(r.points - p0, 9 + bal().num("finish_bonus") + bal().num("boss_reward_points"), "kill 9 + finish bonus + boss reward 10")
	eq(r.phase, DDRun.Phase.SAFEHOUSE, "safehouse")
	eq((r.pending_patch["offer"] as Array).size(), 3, "free Patch: pick 1 of 3")


func test_melee_is_not_shattered() -> void:
	var r: DDRun = plain_run([], [])
	gun(r, 0, "pistol", [1])
	to_boss(r, [])
	r.cover = 30
	r.attack(0, DDRun.MELEE)
	eq(r.slot(0).stack, [1] as Array[int], "pistol untouched")


func test_horde_all_three_at_once() -> void:
	var r: DDRun = make_run("rosa")
	r.district_index = 1
	r._start_district()
	to_boss(r, [])
	eq(codes(r.street), ["Z6", "Z6", "Z6"], "Rush Hour Horde 6 / 6 / 6")
	gun(r, 0, "twin")
	r.cover = 30
	r.attack(0, 0)
	r.attack(0, 0)
	var ev: Dictionary = r.attack(0, 0)
	check(bool((ev["collects"][0] as Dictionary)["challenge"]), "Twin-Bore Big Game on 6-6-6")
	check(bool(ev["district_cleared"]), "cleared")


func test_patient_zero_phases_and_no_escape() -> void:
	var r: DDRun = make_run("rosa")
	r.district_index = 2
	r._start_district()
	to_boss(r, ["C2"])
	eq(codes(r.street), ["C2", "Z8"], "phase 1 only (8)")
	eq(r.cards_left_to_resolve(), 4, "Holdover + 3 phases to go")
	check(not r.can_run(), "no Run")
	check(not r.can_run_past(), "no run past")
	check(r.run_past_block_reason().begins_with("NO ESCAPE"), "NO ESCAPE")
	r.cover = 99
	gun(r, 0, "crossbow")
	r.attack(1, 0)
	eq(codes(r.street), ["C2", "Z10"], "phase 2 appears when phase 1 dies")
	eq(r.street[1].phase, 2, "phase 2")
	r.attack(1, 0)
	eq(codes(r.street), ["C2", "Z12"], "phase 3")
	var ev: Dictionary = r.attack(1, 0)
	check(not bool(ev["district_cleared"]), "the Holdover is still on the street")
	r.resolve(0, DDRun.USE)
	eq(r.phase, DDRun.Phase.WON, "Patient Zero beaten: run won")
	eq(r.run_score(), r.points_earned + r.hp, "score = points earned + HP left")


func test_run_past_district_boss() -> void:
	var r: DDRun = plain_run([], [])
	to_boss(r, [])
	check(r.can_run_past(), "Maple Row boss can be run past")
	var p0: int = r.points
	var ev: Dictionary = r.run_past()
	check(bool(ev["ok"]) and bool(ev["district_cleared"]), "ran past")
	eq(r.hp, 20 - bal().num("boss_runpast_damage"), "-3 HP")
	eq(r.points, p0, "no boss reward")
	check(r.pending_patch.is_empty(), "no free Patch")
	check(bool(r.boss_results[0]["ran_past"]), "recorded")


func test_run_past_only_before_the_fight() -> void:
	var r: DDRun = plain_run([], [])
	to_boss(r, ["C2"])
	r.resolve(0, DDRun.USE)
	check(not r.can_run_past(), "not after the first card")


func test_safehouse_heals_and_takes_the_patch() -> void:
	var r: DDRun = make_run("rosa")
	clear_district(r)
	r.hp = 5
	check(not bool(r.leave_safehouse("")["ok"]), "pick the free Patch first")
	var offer: Array = r.pending_patch["offer"]
	var pick: String = "thick_jacket" if offer.has("thick_jacket") else str(offer[0])
	var ev: Dictionary = r.leave_safehouse(pick)
	check(bool(ev["ok"]), "left")
	check(r.has_patch(pick), "Patch owned")
	var expect: int = mini(r.max_hp, 5 + (bal().num("thick_jacket_hp") if pick == "thick_jacket" else 0) + bal().num("safehouse_heal"))
	eq(r.hp, expect, "heal 8 (after the Patch, as in the sim)")
	eq(r.district_index, 1, "Downtown")
	eq(r.slot(0) != null, true, "guns carry over")

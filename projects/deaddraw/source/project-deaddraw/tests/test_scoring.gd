# Scoring: district = 10 + HP left at the clear, run = sum, death district = 0.
extends "res://tests/dd_test_case.gd"


func clear_bare(r: DDRun) -> void:
	r.setup_street(["M2", "M2", "M2", "M2"])
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	while r.phase == DDRun.Phase.STREET:
		var c: DDCard = r.street[0]
		r.resolve(0, DDRun.BARE if c.kind == DDCard.ZOMBIE else DDRun.USE)


func test_district_score() -> void:
	var r: DDRun = plain_run(filler(4))
	clear_bare(r)  # boss 12 bare from 20 -> 8
	eq(r.district_scores, [18], "10 + 8")
	eq(r.run_score(), 18, "run score")


func test_death_scores_zero_and_keeps_earlier() -> void:
	var r: DDRun = plain_run(filler(4))
	clear_bare(r)
	r.choose_perk(r.perk_offer[0])
	r.setup_street(["Z14", "Z14", "B2", "B2"] + filler(8))
	r.hp = 10
	r.second_wind = false
	r.resolve(0, DDRun.BARE)
	eq(r.phase, DDRun.Phase.DEAD, "dead in Downtown")
	eq(r.district_scores, [18, 0], "district you die in scores 0")
	eq(r.run_score(), 18, "run score keeps Maple Row")


func test_win_sums_three() -> void:
	var r: DDRun = plain_run(filler(4))
	r.max_hp = 99
	r.hp = 99
	var none: Array[String] = []
	r.perk_pool = none
	clear_bare(r)       # 99 - 12 = 87 -> 97, heal to 99
	r.choose_perk("")
	r.setup_street(["M2", "M2", "M2", "M2"])
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	while r.phase == DDRun.Phase.STREET:
		var c: DDCard = r.street[0]
		r.resolve(0, DDRun.BARE if c.kind == DDCard.ZOMBIE else DDRun.USE)
	# horde 27 bare: 99 - 27 = 72 -> 82; heal +12 -> 84
	r.choose_perk("")
	clear_bare(r)       # first M2 heals 2 (86), quarantine: finale M2 does not heal; 86 - 15 = 71 -> 81
	eq(r.phase, DDRun.Phase.WON, "won")
	eq(r.district_scores, [97, 82, 81], "per-district scores")
	eq(r.run_score(), 97 + 82 + 81, "sum")

# Score = every point earned (spending doesn't lower it) + HP left at each boss; shown x10.
extends "res://tests/dd_test_case.gd"


func test_spending_does_not_lower_the_score() -> void:
	var r: DDRun = plain_run(["Z6", "B2", "B2", "B2"] + filler(8))
	r.resolve(0, DDRun.BARE)
	var earned: int = r.points_earned
	check(earned > 0, "kill earned points")
	r.points += 200
	r.open_room(0)
	eq(r.points_earned, earned, "earned unchanged by a door")
	eq(r.run_score(), earned, "score = earned so far")


func test_boss_hp_adds_to_the_score() -> void:
	var r: DDRun = plain_run([])
	to_boss_wave(r, [], [])
	r.hp = r.max_hp
	r.cover = 50
	r.resolve(0, DDRun.BARE)
	eq(r.boss_hp.size(), 1, "one boss beaten")
	eq(r.boss_hp[0], r.max_hp * bal().rule("score_hp_mult"), "HP left counted")
	eq(r.run_score(), r.points_earned + r.boss_hp[0], "score")
	eq(bal().shown(r.run_score()), r.run_score() * 10, "shown x10")


func test_wave_bonus_counts_as_earned() -> void:
	var r: DDRun = plain_run([], ["B2", "B2", "B2"])
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	eq(r.points_earned, int(bal().points("wave")), "wave bonus earned")

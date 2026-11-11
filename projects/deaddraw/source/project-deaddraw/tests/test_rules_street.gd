# v3 street: start kit, deal 4 / resolve 3 / Holdover (K4), medkit limit and bonuses, Cover cards,
# equip into two slots, short streets, Run (K3) and its limits, Theo's free Run, death and score.
extends "res://tests/dd_test_case.gd"


func _take(r: DDRun) -> void:
	if r.street[0].kind == DDCard.ZOMBIE:
		r.attack(0, DDRun.MELEE)
	elif r.street[0].kind == DDCard.WEAPON:
		r.resolve(0, DDRun.SCRAP)
	else:
		r.resolve(0, DDRun.USE)


func test_run_start_state() -> void:
	var r: DDRun = make_run("rosa")
	eq(r.hp, 20, "Rosa 20 HP")
	eq(r.slot(0).wid, "pistol", "Service Pistol in slot 1")
	eq(r.slot(1), null, "slot 2 empty")
	eq(r.active, DDRun.SLOT1, "pistol active")
	eq(r.street.size(), 4, "street of 4")
	eq(r.budget, 3, "resolve 3")
	eq(r.pile.size() + r.street.size(), 3 + 1 + 7, "Entrance (3 + a v4 melee weapon card) + Wave 1 (7) in the pile at the start")
	eq(r.wave_index, 0, "wave 1 active")
	eq(r.points, 0, "no points")
	eq(make_run("imani").hp, 18, "v4: Imani 18 HP")
	eq(make_run("rosa").melee_name(), "Bare Hands", "v4: you start with bare hands")
	eq(make_run("theo").hp, 21, "Theo 21 HP")


func test_three_resolves_then_holdover_and_deal() -> void:
	var r: DDRun = plain_run(["Z1", "Z2", "Z3", "Z4", "C2", "C2", "C2", "C2"], [])
	eq(codes(r.street), ["Z1", "Z2", "Z3", "Z4"], "dealt in order")
	r.set_active(DDRun.MELEE)
	r.attack(0)
	r.attack(0)
	eq(r.resolved, 2, "two resolved")
	var ev: Dictionary = r.attack(0)
	check(bool(ev["street_ended"]), "third resolve ends the street")
	eq(codes(r.street), ["Z4", "C2", "C2", "C2"], "Holdover Z4 + 3 new cards")
	check(r.street[0].holdover, "Z4 is the Holdover")


func test_medkits_no_limit_and_bonuses() -> void:
	var r: DDRun = plain_run(filler(8), ["M5", "M4", "M3", "C2"])
	r.hp = 5
	var pv: Dictionary = r.card_preview(0, DDRun.USE)
	eq(int(pv["heal"]), 5, "preview heal 5")
	r.resolve(0, DDRun.USE)
	eq(r.hp, 10, "+5")
	check(not bool(r.card_preview(0, DDRun.USE)["wasted"]), "v4: a second medkit is not wasted")
	r.resolve(0, DDRun.USE)
	eq(r.hp, 14, "second medkit heals")
	r.resolve(0, DDRun.USE)
	eq(r.hp, 17, "and a third")
	for line: String in r.log_lines:
		check(not line.contains("discarded"), "no 'discarded' line")
	var v3: DDBalance = DDBalance.from_file(DDBalance.DEFAULT_PATH)
	v3.config["medkits_per_street"] = 1
	var o: DDRun = plain_run(filler(8), ["M5", "M4", "C2", "C2"], v3)
	o.hp = 5
	o.resolve(0, DDRun.USE)
	check(bool(o.card_preview(0, DDRun.USE)["wasted"]), "the v3 setting still limits")
	var t: DDRun = make_run("imani", filler(8), ["M5", "C2", "C2", "C2"])
	t.hp = 5
	t.resolve(0, DDRun.USE)
	eq(t.hp, 5 + 5 + bal().num("triage_bonus"), "Triage +1")
	t.patches.append("field_medic")
	t.setup_street(filler(8), ["M3", "C2", "C2", "C2"])
	var hp0: int = t.hp
	t.resolve(0, DDRun.USE)
	eq(t.hp - hp0, 3 + 1 + bal().num("field_medic_bonus"), "Field Medic +2 stacks with Triage")


func test_cover_card() -> void:
	var r: DDRun = plain_run(filler(8), ["C3", "Z5", "C2", "C2"])
	r.resolve(0, DDRun.USE)
	eq(r.cover, 3, "+3 Cover")
	r.set_active(DDRun.MELEE)
	r.attack(idx(r, "Z5"))
	eq(r.cover, 0, "soaked")
	eq(r.hp, 19, "5 - 1 (bare hands) = 4: Cover 3, 1 HP")


func test_equip_into_both_slots() -> void:
	var r: DDRun = plain_run(filler(8), ["W:rifle", "W:twin", "C2", "C2"])
	r.resolve(0, DDRun.EQUIP2)
	eq(r.slot(1).wid, "rifle", "slot 2 rifle")
	r.resolve(0, DDRun.EQUIP1)
	eq(r.slot(0).wid, "twin", "slot 1 Twin-Bore (pistol replaced)")
	eq(r.slot(0).power, 5, "Twin-Bore power 5")


func test_short_street_at_the_end_of_the_district() -> void:
	var r: DDRun = plain_run([], ["Z1", "Z2", "Z3"])
	r.wave_index = r.wave_count() - 1
	r.setup_street([], ["Z1", "Z2", "Z3"])
	eq(r.budget, 2, "3 cards and an empty pile: resolve 2")
	r.set_active(DDRun.MELEE)
	r.attack(0)
	var ev: Dictionary = r.attack(0)
	check(r.boss_street, "the last card + the boss: boss street")
	check(bool(ev.get("boss_street", false)), "event says so")


func test_run_shuffles_back_and_costs_one() -> void:
	var r: DDRun = plain_run(filler(8, "M3"), ["Z9", "Z9", "Z9", "Z9"])
	check(r.can_run(), "can run before resolving")
	var ev: Dictionary = r.run_street()
	check(bool(ev["ok"]), "ran")
	eq(r.hp, 20 - bal().num("run_damage"), "-1 HP")
	eq(r.street.size(), 4, "a new street")
	eq(r.pile.size() + r.street.size(), 12, "the 4 cards went back into the pile")
	check(not r.can_run(), "not twice in a row")
	eq(r.run_block_reason(), "you ran last street", "reason")
	_take(r)
	check(not r.can_run(), "still the street after a Run, even after resolving")
	eq(r.run_block_reason(), "you ran last street", "reason 2")


func test_run_any_time_and_to_the_bottom() -> void:
	# Q5 (head, 2026-11-11): Run whenever the street has cards, even with no zombie on it; every
	# card still on the street goes to the BOTTOM of the pile, in street order, unshuffled.
	var r: DDRun = plain_run(["Z1", "Z2", "Z3", "Z4", "C2", "C2", "C2", "C2"], ["M3", "W:rifle", "K:wrench", "C3"])
	check(r.can_run(), "no zombie on the street: Run is allowed")
	r.resolve(0, DDRun.USE)
	check(r.can_run(), "after resolving a card: still allowed")
	var hp0: int = r.hp
	var ev: Dictionary = r.run_street()
	check(bool(ev["ok"]), "ran")
	check(bool(ev["to_bottom"]), "the event says they went to the bottom")
	eq(hp0 - r.hp, 1, "-1 HP")
	eq(codes(ev["returned"]), ["W:rifle", "K:wrench", "C3"], "every card left on the street came back")
	eq(codes(r.street), ["Z1", "Z2", "Z3", "Z4"], "the new street is the old top of the pile")
	eq(codes(r.pile.slice(0, 3)), ["W:rifle", "K:wrench", "C3"], "they sit at the bottom, unshuffled")
	eq(r.resolved, 0, "a fresh street")
	check(r.log_lines[r.log_lines.size() - 1].contains("3 cards (a gun, a melee weapon, a cover) go to the bottom of the pile"), "log line counts them")
	var e: DDRun = plain_run(filler(8), ["C2", "C2", "C2", "C2"])
	e.street.clear()
	eq(e.run_block_reason(), "nothing on the street", "an empty street can't Run")


func test_run_v3_settings_still_work() -> void:
	var b: DDBalance = DDBalance.from_file(DDBalance.DEFAULT_PATH)
	b.config["run_mode"] = "before"
	b.config["run_return"] = "shuffle"
	var r: DDRun = plain_run(filler(8, "M3"), ["Z9", "Z9", "Z9", "Z9"], b)
	_take(r)
	eq(r.run_block_reason(), "only before you resolve a card", "v3: before the first resolve only")


func test_run_again_after_a_normal_street() -> void:
	var r: DDRun = plain_run(filler(12, "M3"), ["Z9", "Z9", "Z9", "Z9"])
	r.run_street()
	for k: int in 3:
		_take(r)
	check(r.can_run(), "the next street may Run again")


func test_theo_runs_free() -> void:
	var r: DDRun = make_run("theo", filler(8), ["Z9", "Z9", "Z9", "Z9"])
	r.run_street()
	eq(r.hp, 21, "Slip Away: no HP")


func test_no_run_on_a_boss_street() -> void:
	var r: DDRun = plain_run([], [])
	to_boss(r, ["C2"])
	check(r.boss_street, "boss street")
	check(not r.can_run(), "no Run on a boss street")


func test_death_and_second_wind() -> void:
	var r: DDRun = plain_run(filler(8), ["Z11", "Z11", "C2", "C2"])
	r.hp = 3
	r.set_active(DDRun.MELEE)
	check(bool(r.preview(0, DDRun.MELEE)["dies"]), "preview warns: this kills you")
	var ev: Dictionary = r.attack(0)
	check(bool(ev["dead"]), "dead")
	eq(r.phase, DDRun.Phase.DEAD, "phase DEAD")
	eq(r.run_score(), r.points_earned, "a loss scores the points earned")
	var s: DDRun = plain_run(filler(8), ["Z11", "Z11", "C2", "C2"])
	s.patches.append("second_wind")
	s.hp = 3
	s.set_active(DDRun.MELEE)
	s.attack(0)
	eq(s.hp, bal().num("second_wind_hp"), "Second Wind: back to 6")
	check(s.phase == DDRun.Phase.STREET, "alive")
	s.hp = 3
	s.attack(0)
	eq(s.phase, DDRun.Phase.DEAD, "only once per run")

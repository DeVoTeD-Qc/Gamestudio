# Hybrid combat: two slots + bare hands, magazines and the shared reserve, Reload (one action,
# drops the rest of the magazine, refills from the reserve, clears the notch), the notch on every
# weapon (guns: reload clears it; melee: each new wave), Steady Hands and Keen melee, points.
extends "res://tests/dd_test_case.gd"


func test_gun_kill_spends_a_round_and_notches() -> void:
	var r: DDRun = plain_run(["Z5", "Z6", "Z4", "B2"] + filler(4))
	var w: DDWeapon = r.slot(0)
	var mag: int = w.ammo
	var hp0: int = r.hp
	var pr: Dictionary = r.preview(idx(r, "Z5"), DDRun.SLOT1)
	eq(int(pr["hp_loss"]), 5 - w.power, "damage = strength - power")
	eq(int(pr["ammo_after"]), mag - 1, "preview shows the round spent")
	r.resolve(idx(r, "Z5"), DDRun.SLOT1)
	eq(w.ammo, mag - 1, "1 round spent")
	eq(w.notch, 5, "notched at 5")
	eq(r.hp, hp0 - (5 - w.power), "took the difference")
	check(not bool(r.preview(idx(r, "Z6"), DDRun.SLOT1)["enabled"]), "can't hit a stronger zombie")
	eq(str(r.preview(idx(r, "Z6"), DDRun.SLOT1)["reason"]), "hits under 5", "reason is the notch tag")
	check(bool(r.preview(idx(r, "Z4"), DDRun.SLOT1)["enabled"]), "weaker zombie is fine")


func test_empty_magazine_blocks_the_gun() -> void:
	var r: DDRun = plain_run(["Z2", "B2", "B2", "B2"] + filler(4))
	r.slot(0).ammo = 0
	eq(str(r.preview(0, DDRun.SLOT1)["reason"]), "mag empty - reload", "empty mag blocks")
	check(bool(r.preview(0, DDRun.BARE)["enabled"]), "bare hands always work")


func test_melee_is_unlimited_and_pays_up_close() -> void:
	var r: DDRun = plain_run(["Z9", "Z7", "Z3", "B2", "Z2", "Z2", "B2", "B2"])
	var m: DDWeapon = gun(r, 1, "machete")
	var kill: float = bal().points("kill")
	var close: int = int(bal().points("up_close"))
	var p0: int = r.points
	r.resolve(idx(r, "Z9"), DDRun.SLOT2)
	eq(m.notch, 9, "melee notches too")
	eq(r.points, p0 + int(9 * kill) + close, "kill points + up close bonus")
	r.resolve(idx(r, "Z7"), DDRun.SLOT2)
	r.resolve(idx(r, "Z3"), DDRun.SLOT2)
	eq(m.ammo, 0, "melee has no magazine to spend")
	check(not r.reload_preview(1)["enabled"], "melee never reloads")


func test_gun_kill_pays_no_up_close_bonus() -> void:
	var r: DDRun = plain_run(["Z8", "B2", "B2", "B2"] + filler(4))
	var p0: int = r.points
	r.resolve(0, DDRun.SLOT1)
	eq(r.points, p0 + int(8 * bal().points("kill")), "gun kill: kill points only")


func test_bare_hands_full_damage_no_notch() -> void:
	var r: DDRun = plain_run(["Z6", "B2", "B2", "B2"] + filler(4))
	var hp0: int = r.hp
	var p0: int = r.points
	r.resolve(0, DDRun.BARE)
	eq(r.hp, hp0 - 6, "full damage")
	eq(r.slot(0).notch, DDRun.NO_NOTCH, "weapons untouched")
	eq(r.points, p0 + int(6 * bal().points("kill")) + int(bal().points("up_close")), "up close bonus bare-handed")


func test_two_slots_have_their_own_notch() -> void:
	var r: DDRun = plain_run(["Z6", "Z5", "Z4", "B2"] + filler(4))
	gun(r, 1, "crowbar")
	r.resolve(idx(r, "Z6"), DDRun.SLOT1)
	eq(r.slot(0).notch, 6, "slot 1 notched")
	eq(r.slot(1).notch, DDRun.NO_NOTCH, "slot 2 still fresh")
	r.resolve(idx(r, "Z5"), DDRun.SLOT2)
	eq(r.slot(1).notch, 5, "slot 2 notched separately")


func test_reload_drops_the_rest_and_clears_the_notch() -> void:
	var r: DDRun = plain_run(["Z5", "B2", "B2", "B2"] + filler(4))
	r.resolve(idx(r, "Z5"), DDRun.SLOT1)
	var w: DDWeapon = r.slot(0)
	r.reserve = 10
	var left: int = w.ammo
	var pr: Dictionary = r.reload_preview(0)
	check(bool(pr["enabled"]), "reload allowed")
	eq(int(pr["drop"]), left, "drops what was left")
	eq(int(pr["load"]), w.cap, "loads a full magazine")
	eq(int(pr["cost"]), 1, "costs an action")
	var ev: Dictionary = r.reload(0)
	check(bool(ev["ok"]), "reloaded")
	eq(w.ammo, w.cap, "full")
	eq(r.reserve, 10 - w.cap, "taken from the reserve")
	eq(w.notch, DDRun.NO_NOTCH, "notch cleared")
	eq(r.actions_used, 2, "1 card + 1 reload")
	check(not bool(r.reload_preview(0)["enabled"]), "one reload per street")


func test_reload_partial_reserve_and_limits() -> void:
	var r: DDRun = plain_run(["Z5", "B2", "B2", "B2"] + filler(4))
	var w: DDWeapon = r.slot(0)
	eq(str(r.reload_preview(0)["reason"]), "full and fresh", "nothing to gain")
	w.ammo = 1
	r.reserve = 0
	eq(str(r.reload_preview(0)["reason"]), "no reserve ammo", "empty reserve")
	r.reserve = 3
	r.reload(0)
	eq(w.ammo, 3, "only what the reserve had")
	eq(r.reserve, 0, "reserve spent")
	# a paid reload needs an action to spare afterwards
	var r2: DDRun = plain_run(["Z5", "Z2", "B2", "B2"] + filler(4))
	r2.resolve(idx(r2, "Z5"), DDRun.SLOT1)
	r2.resolve(idx(r2, "B2"), DDRun.USE)
	eq(str(r2.reload_preview(0)["reason"]), "no action to spare", "last action must resolve a card")


func test_melee_notch_clears_each_wave_gun_notch_stays() -> void:
	var r: DDRun = plain_run([], ["Z6", "Z5", "B2"])
	gun(r, 1, "machete")
	r.resolve(idx(r, "Z6"), DDRun.SLOT2)
	r.resolve(idx(r, "Z5"), DDRun.SLOT1)
	eq(r.wave_index, 1, "the wave ended")
	eq(r.slot(1).notch, DDRun.NO_NOTCH, "melee notch wiped at the new wave")
	eq(r.slot(0).notch, 5, "gun notch stays until a reload")


func test_steady_hands_and_keen_hit_equal() -> void:
	var r: DDRun = make_run("rosa", ["Z5", "Z5", "B2", "B2"] + filler(4))
	r.resolve(0, DDRun.SLOT1)
	check(bool(r.preview(0, DDRun.SLOT1)["enabled"]), "Rosa hits equal to the notch")
	var p: DDRun = plain_run(["Z5", "Z5", "Z5", "B2"] + filler(4))
	var m: DDWeapon = gun(p, 1, "crowbar")
	p.resolve(0, DDRun.SLOT2)
	check(not bool(p.preview(0, DDRun.SLOT2)["enabled"]), "plain melee can't hit equal")
	m.upgraded = true
	check(bool(p.preview(0, DDRun.SLOT2)["enabled"]), "Keen (retrofitted) melee can")
	p.resolve(0, DDRun.SLOT1)
	check(not bool(p.preview(0, DDRun.SLOT1)["enabled"]), "a retrofitted gun is not Keen")


func test_death_and_second_wind() -> void:
	var r: DDRun = plain_run(["Z9", "B2", "B2", "B2"] + filler(4))
	r.hp = 9
	check(bool(r.preview(0, DDRun.BARE)["dies"]), "preview says you die")
	var ev: Dictionary = r.resolve(0, DDRun.BARE)
	check(bool(ev["dead"]), "dead")
	eq(r.phase, DDRun.Phase.DEAD, "run over")
	var s: DDRun = plain_run(["Z9", "B2", "B2", "B2"] + filler(4))
	s.hp = 9
	s.second_wind = true
	s.resolve(0, DDRun.BARE)
	eq(s.hp, bal().rule("second_wind_hp"), "Second Wind keeps you at 1")
	check(not s.second_wind, "used up")

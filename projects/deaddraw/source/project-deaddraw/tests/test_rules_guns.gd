# v3 guns: every gun rule (legal / blocked, Steady Hands), every challenge and its reward, kill
# stacks, per-kill points (K1), finishing (+finish bonus), Encore, early replace (pays nothing),
# melee (no rule, no stack, no points: K2), the active weapon and its auto-switch, previews.
extends "res://tests/dd_test_case.gd"


func _legal(r: DDRun, rule: String, stack: Array, z: int, rosa: bool = false) -> bool:
	var st: Array[int] = []
	for v: Variant in stack:
		st.append(int(v))
	return r.legal(rule, st, z, rosa)


func test_every_gun_rule() -> void:
	var r: DDRun = plain_run(filler(8))
	# any
	check(_legal(r, "any", [9], 1) and _legal(r, "any", [1], 11), "pistol: anything")
	# down / up (the classic notch and its mirror); first kill free
	check(_legal(r, "down", [], 11), "down: first kill free")
	check(_legal(r, "down", [6], 5) and not _legal(r, "down", [6], 6) and not _legal(r, "down", [6], 7), "down: lower only")
	check(_legal(r, "down", [6], 6, true), "down: Rosa takes equal")
	check(_legal(r, "up", [4], 5) and not _legal(r, "up", [4], 4) and not _legal(r, "up", [4], 3), "up: higher only")
	check(_legal(r, "up", [4], 4, true), "up: Rosa takes equal")
	# same as the FIRST kill
	check(_legal(r, "same", [6, 6], 6) and not _legal(r, "same", [6], 7), "same: the first kill's number")
	# zigzag
	check(_legal(r, "zigzag", [5], 3) and _legal(r, "zigzag", [5], 8) and not _legal(r, "zigzag", [5], 5), "zigzag: any step but equal after one kill")
	check(_legal(r, "zigzag", [3, 7], 4) and not _legal(r, "zigzag", [3, 7], 9), "zigzag: up then down")
	check(_legal(r, "zigzag", [7, 3], 5) and not _legal(r, "zigzag", [7, 3], 2), "zigzag: down then up")
	check(_legal(r, "zigzag", [7, 7], 3) and _legal(r, "zigzag", [7, 7], 9) and not _legal(r, "zigzag", [7, 7], 7), "zigzag: after a flat step (a Gun Mod), any change restarts it (no dead gun)")
	# close
	check(_legal(r, "close", [5], 4) and _legal(r, "close", [5], 5) and _legal(r, "close", [5], 6) and not _legal(r, "close", [5], 7), "close: within 1")
	# parity
	check(_legal(r, "parity", [4], 5) and not _legal(r, "parity", [4], 6) and _legal(r, "parity", [3], 8), "parity: odd/even alternate")
	# spread: total <= 16
	check(_legal(r, "spread", [7, 5], 4) and not _legal(r, "spread", [7, 5], 5), "spread: total stays at 16 or less")
	# big: 6+ only, even the first kill
	check(not _legal(r, "big", [], 5) and _legal(r, "big", [], 6) and _legal(r, "big", [9], 6), "big: 6 or more")


func test_rule_lock_blocks_without_spending_a_resolve() -> void:
	var r: DDRun = plain_run(filler(8), ["Z6", "Z7", "C2", "C2"])
	gun(r, 0, "rifle", [5])
	var pr: Dictionary = r.preview(0, 0)
	check(not bool(pr["ok"]), "rifle on 5 can't take a 6")
	check(str(pr["reason"]).contains("needs ≤4"), "the reason says what it needs: " + str(pr["reason"]))
	var ev: Dictionary = r.attack(0, 0)
	check(not bool(ev["ok"]), "blocked attack")
	eq(r.resolved, 0, "no resolve spent")
	eq(r.street.size(), 4, "card stays")
	check(bool(r.preview(0, DDRun.MELEE)["ok"]), "melee is always legal")


func test_gun_kill_stacks_and_pays_its_number() -> void:
	var r: DDRun = plain_run(filler(8), ["Z5", "Z4", "C2", "C2"])
	gun(r, 0, "rifle")
	var p0: int = r.points
	var hp0: int = r.hp
	var pr: Dictionary = r.preview(0, 0)
	eq(int(pr["damage"]), 1, "preview: 5 - power 4 = 1")
	eq(int(pr["points"]), 5, "preview: +5 points")
	var ev: Dictionary = r.attack(0)
	check(bool(ev["ok"]), "attack ok")
	eq(r.slot(0).stack, [5] as Array[int], "5 on the rifle's stack")
	eq(r.points - p0, 5, "K1: the kill pays its number at once")
	eq(r.points_earned, 5, "earned")
	eq(hp0 - r.hp, 1, "damage = zombie - power")
	r.attack(idx(r, "Z4"))
	eq(r.slot(0).stack, [5, 4] as Array[int], "stack grows (top = last)")
	eq(r.points - p0, 9, "two kills paid")


func test_finish_pays_bonus_and_leaves() -> void:
	var r: DDRun = plain_run(filler(10), ["Z1", "Z2", "Z2", "C2"])
	gun(r, 0, "pistol", [3, 4, 5])
	gun(r, 1, "rifle")
	var p0: int = r.points
	var ev: Dictionary = r.attack(idx(r, "Z2"), 0)
	var fb: int = bal().num("finish_bonus")
	eq(r.slot(0), null, "finished gun leaves the slot")
	eq(r.points - p0, 2 + fb + 5, "kill 2 + finish bonus + Mixed Bag 5 (3-4-5-2 all different)")
	var col: Array = ev["collects"]
	eq(col.size(), 1, "one collect event")
	eq((col[0] as Dictionary)["stack"], [3, 4, 5, 2] as Array[int], "collected stack")
	check(bool((col[0] as Dictionary)["challenge"]), "challenge flagged")
	eq(r.active, 1, "active gun finished -> the other gun becomes active")
	eq(int(r.stats["finished"]), 1, "finished counted")
	r.slots[1] = null
	gun(r, 1, "pistol", [2, 2, 3])
	r.active = 1
	r.attack(idx(r, "Z2"), 1)
	eq(r.active, DDRun.MELEE, "no other gun -> melee becomes active")


func test_every_challenge_and_reward() -> void:
	# [wid, stack before, last kill, met?, reward check]
	var cases: Array = [
		["pistol", [1, 2, 3], 4, true], ["pistol", [1, 2, 3], 3, false],
		["rifle", [9, 6, 5], 4, true], ["rifle", [9, 7, 5], 4, false],
		["crossbow", [2, 4, 5], 6, true], ["crossbow", [2, 4, 6], 8, false],
		["twin", [6, 6], 6, true], ["twin", [5, 5], 5, false],
		["lever", [2, 6, 3, 8], 4, true], ["lever", [2, 6, 5, 8], 4, false],
		["carbine", [4, 5, 6, 7], 7, true], ["carbine", [4, 4, 5, 5], 5, false],
		["nailer", [1, 2, 3], 4, true], ["nailer", [1, 2, 1], 2, false],
		["shotgun", [5, 5, 3], 3, true], ["shotgun", [5, 5, 3], 2, false],
		["elephant", [8], 9, true], ["elephant", [7], 9, false],
	]
	for cs: Array in cases:
		var r: DDRun = plain_run(filler(10), ["Z%d" % int(cs[2]), "C2", "C2", "C2"])
		r.cover = 50
		var wid: String = cs[0]
		gun(r, 0, wid, cs[1])
		r.hp = 10
		var p0: int = r.points
		var c0: int = r.cover
		var ev: Dictionary = r.attack(0, 0)
		check(bool(ev["ok"]), "%s %s + %d is legal" % [wid, str(cs[1]), int(cs[2])])
		var col: Array = ev.get("collects", [])
		check(col.size() == 1 and bool((col[0] as Dictionary)["finished"]), "%s finishes" % wid)
		if col.is_empty():
			continue
		var info: Dictionary = col[0]
		eq(bool(info["challenge"]), bool(cs[3]), "%s %s+%d challenge" % [wid, str(cs[1]), int(cs[2])])
		var rw: Array = bal().weapon_reward(wid)
		var gain: int = r.points - p0 - int(cs[2]) - bal().num("finish_bonus")
		if bool(cs[3]):
			match str(rw[0]):
				"points":
					eq(gain, int(rw[1]), wid + " pays its points reward")
				"heal":
					eq(r.hp, 10 + int(rw[1]), wid + " heals")
				"cover":
					eq(r.cover - c0, int(rw[1]), wid + " gives Cover")
				"encore":
					check(r.slot(0) != null and r.slot(0).stack.is_empty(), "Encore: the crossbow stays with an empty stack")
		else:
			eq(gain, 0, wid + " no challenge reward")
			eq(r.slot(0), null, wid + " leaves")


func test_shotgun_finishes_at_sixteen() -> void:
	var r: DDRun = plain_run(filler(8), ["Z6", "C2", "C2", "C2"])
	gun(r, 0, "shotgun", [10])
	r.cover = 20
	var ev: Dictionary = r.attack(0, 0)
	eq((ev["collects"] as Array).size(), 1, "total 16 finishes the shotgun at 2 kills")
	check(bool((ev["collects"][0] as Dictionary)["challenge"]), "Point Blank: exactly 16")


func test_early_replace_pays_salvage() -> void:
	var r: DDRun = plain_run(filler(8), ["W:rifle", "C2", "C2", "C2"])
	gun(r, 0, "pistol", [3, 4])
	var p0: int = r.points
	var pv: Dictionary = r.card_preview(0, DDRun.EQUIP1)
	eq(str(pv["replaces"]), "Service Pistol", "preview names the replaced gun")
	eq(int(pv["kills"]), 2, "preview: 2 kills on it")
	eq(int(pv["salvage"]), 2, "v4 Salvage: +1 per kill (ditch_share 0)")
	eq(int(pv["points"]), 2, "preview points = salvage")
	var ev: Dictionary = r.resolve(0, DDRun.EQUIP1)
	eq(r.slot(0).wid, "rifle", "rifle in slot 1")
	eq(r.points, p0 + 2, "salvage paid, no finish bonus")
	eq(int(ev["salvage"]), 2, "the event carries the salvage for the +N float")
	var info: Dictionary = ev["collects"][0]
	check(not bool(info["finished"]), "collected unfinished")
	eq(int(info["salvage"]), 2, "collect info: salvage")
	eq(int(info["bonus"]), 0, "no finish bonus")
	check(not bool(info["challenge"]), "no challenge")
	eq(int(r.stats["finished"]), 0, "not a finish")
	eq(int(r.stats["salvage"]), 2, "salvage stat")
	check(r.log_lines[r.log_lines.size() - 2].contains("salvage +20"), "log shows salvage +20")
	eq(DDText.salvage_text(3, bal()), "SALVAGE +30", "salvage text x10")


func test_salvage_empty_stack_and_wall_rack() -> void:
	var r: DDRun = plain_run(filler(8), ["W:rifle", "C2", "C2", "C2"])
	gun(r, 0, "pistol", [])
	eq(int(r.card_preview(0, DDRun.EQUIP1)["salvage"]), 0, "empty stack: no salvage")
	var p0: int = r.points
	r.resolve(0, DDRun.EQUIP1)
	eq(r.points, p0, "nothing paid")
	# Wall Rack swap salvages too (sim spend(): collect(s, i, False))
	var r2: DDRun = plain_run(filler(8))
	r2.points = 100
	r2.room_open[0] = true
	gun(r2, 0, "rifle", [9, 7, 5])
	gun(r2, 1, "pistol", [1])
	var opts: Array[Dictionary] = r2.machine_options(0)
	eq(int(opts[0]["salvage"]), 3, "Wall Rack option shows salvage")
	check(str(opts[0]["result"]).contains("salvage +30"), "Wall Rack result text: salvage +30")
	var ev: Dictionary = r2.use_machine(0, "slot1")
	check(bool(ev["ok"]), "bought")
	eq(r2.points, 100 - bal().weapon_price("crossbow") + 3, "price paid, salvage +3")
	eq(int((ev["collects"][0] as Dictionary)["salvage"]), 3, "collect info salvage")


func test_salvage_off_with_v3_setting() -> void:
	var b: DDBalance = DDBalance.from_file(DDBalance.DEFAULT_PATH)
	b.config["swap_salvage"] = "none"
	var r: DDRun = plain_run(filler(8), ["W:rifle", "C2", "C2", "C2"], b)
	gun(r, 0, "pistol", [3, 4])
	var p0: int = r.points
	r.resolve(0, DDRun.EQUIP1)
	eq(r.points, p0, "v3: nothing")


func test_scrap_pays() -> void:
	var r: DDRun = plain_run(filler(8), ["W:rifle", "C2", "C2", "C2"])
	r.resolve(0, DDRun.SCRAP)
	eq(r.points, bal().num("scrap_points"), "scrap +2")


func test_melee_no_rule_no_stack_no_points() -> void:
	var r: DDRun = plain_run(filler(8), ["Z5", "C2", "C2", "C2"])
	gun(r, 0, "rifle", [2])
	r.set_active(DDRun.MELEE)
	var hp0: int = r.hp
	var ev: Dictionary = r.attack(0)
	check(bool(ev["ok"]), "melee ok")
	eq(hp0 - r.hp, 5 - bal().num("hands_power"), "v4 bare hands power 1")
	eq(r.points, 0, "K2: melee pays nothing")
	eq(r.slot(0).stack, [2] as Array[int], "no stack change")
	eq(int(r.stats["melee_kills"]), 1, "melee kill counted")


func test_active_weapon_toggle() -> void:
	var r: DDRun = plain_run(filler(8))
	r.slots[1] = null
	check(not bool(r.set_active(1)["ok"]), "empty slot can't be active")
	check(bool(r.set_active(2)["ok"]) and r.active == 2, "melee active")
	check(bool(r.set_active(0)["ok"]) and r.active == 0, "slot 1 active")


func test_cover_soaks_first() -> void:
	var r: DDRun = plain_run(filler(8), ["Z9", "C2", "C2", "C2"])
	r.cover = 3
	r.set_active(DDRun.MELEE)
	var pr: Dictionary = r.preview(0, DDRun.MELEE)
	eq(int(pr["absorbed"]), 3, "cover soaks 3")
	eq(int(pr["hp_loss"]), 5, "9 - 1 (bare hands) - 3 Cover = 5 to HP")
	var hp0: int = r.hp
	r.attack(0)
	eq(r.cover, 0, "cover spent")
	eq(hp0 - r.hp, 5, "HP loss")


func test_steady_hands_rosa() -> void:
	var r: DDRun = make_run("rosa", filler(8), ["Z5", "C2", "C2", "C2"])
	gun(r, 0, "rifle", [5])
	check(bool(r.preview(0, 0)["ok"]), "Rosa's rifle takes an equal 5")
	var t: DDRun = make_run("imani", filler(8), ["Z5", "C2", "C2", "C2"])
	gun(t, 0, "rifle", [5])
	check(not bool(t.preview(0, 0)["ok"]), "Imani's rifle doesn't")


func test_can_take_list() -> void:
	var r: DDRun = plain_run(filler(8))
	var g: DDGun = gun(r, 0, "rifle", [4])
	eq(r.can_take(g), [1, 2, 3] as Array[int], "rifle on 4 can still take 1-3")
	eq(r.challenge_state(gun(r, 1, "pistol", [3, 3])), "broken", "mixed bag broken by a pair")

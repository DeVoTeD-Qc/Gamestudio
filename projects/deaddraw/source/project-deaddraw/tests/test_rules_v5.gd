# DeadDraw v5 economy pass (documentation/design/economy-v5.md): Gun Mods fitted to a gun slot at
# the safehouse (Open Breech, Last Round, Echo Chamber, Short Barrel), the room cost helpers (door +
# one use of the machine inside), and the Gun Mod save round trip. The sim parity of legal_mod /
# fit_mod is in test_v4_parity.gd.
extends "res://tests/dd_test_case.gd"


func _at_safehouse(points: int) -> DDRun:
	var r: DDRun = plain_run(filler(8))
	clear_district(r)
	r.points = points
	return r


func _take_boss_patch(r: DDRun) -> void:
	if not r.pending_patch.is_empty():
		r.take_patch(str(r.pending_patch["offer"][0]))


# ---------------------------------------------------------------- the four mods
func test_open_breech_first_two_kills_ignore_the_rule() -> void:
	var r: DDRun = plain_run(filler(8), ["Z9", "Z9", "Z9", "C2"])
	gun(r, 0, "rifle", [3])
	check(not r.slot_allows(0, 9), "without a mod: the rifle wants lower than 3")
	r.slot_mods[0] = "open_breech"
	check(r.slot_allows(0, 9), "Open Breech: kill 2 ignores the rule")
	check(r.mod_lets_in(0, 9), "and the mod is what lets it in")
	r.slot(0).stack.append(9)
	check(not r.slot_allows(0, 9), "kill 3 follows the rule again")
	check(r.slot_allows(0, 8), "kill 3: lower than 9 is fine")


func test_last_round_and_echo() -> void:
	var r: DDRun = plain_run(filler(8))
	gun(r, 0, "rifle", [9, 7, 5])
	r.slot_mods[0] = "last_round"
	check(r.slot_allows(0, 12), "Last Round: the kill that fills the gun can be anything")
	gun(r, 1, "rifle", [9, 7])
	r.slot_mods[1] = "echo"
	check(r.slot_allows(1, 7), "Echo Chamber: the same number as the top kill fits")
	check(not r.slot_allows(1, 8), "Echo Chamber: other numbers still follow the rule")
	eq(r.can_take_slot(1), [1, 2, 3, 4, 5, 6, 7] as Array[int], "can_take_slot shows what the mod adds")
	eq(r.can_take(r.slot(1)), [1, 2, 3, 4, 5, 6] as Array[int], "can_take is the gun alone")


func test_short_barrel_new_guns_hold_one_less() -> void:
	var r: DDRun = plain_run(filler(6), ["W:rifle", "Z2", "Z3", "C2"])
	r.slot_mods[1] = "short_barrel"
	r.slots[1] = null
	r.resolve(idx(r, "W:rifle"), DDRun.EQUIP2)
	eq(r.slot(1).cap, bal().weapon_cap("rifle") - 1, "a gun put in the slot holds 1 less")
	eq(DDRun.mod_cap(1, "short_barrel"), 1, "never below 1")


func test_attack_through_a_mod() -> void:
	var r: DDRun = plain_run(filler(8), ["Z9", "Z2", "C2", "C2"])
	gun(r, 0, "rifle", [3])
	r.slot_mods[0] = "open_breech"
	var ev: Dictionary = r.attack(idx(r, "Z9"), 0)
	check(bool(ev["ok"]), "the mod lets the 9 on the rifle")
	eq(r.slot(0).stack, [3, 9] as Array[int], "stack 3, 9")


# ---------------------------------------------------------------- the safehouse step
func test_mod_offer_and_fit() -> void:
	var r: DDRun = _at_safehouse(40)
	eq(r.mod_offer.size(), bal().num("mod_offer"), "the safehouse offers %d Gun Mods" % bal().num("mod_offer"))
	check(not r.mod_step_open(), "after the boss Patch")
	var m: String = r.mod_offer[0]
	eq(r.mod_block_reason(m, 0), "pick your free Patch first", "the boss Patch comes first")
	_take_boss_patch(r)
	check(r.mod_step_open(), "then the Gun Mod step")
	eq(r.mod_block_reason("nope", 0), "not offered", "only offered mods")
	var p0: int = r.points
	var ev: Dictionary = r.fit_mod(m, 0)
	check(bool(ev["ok"]), "fit")
	eq(r.slot_mod(0), m, "slot 1 has it")
	eq(r.points, p0 - r.mod_price(), "it costs mod_price")
	check(not r.mod_step_open(), "one per safehouse: the step closes")
	eq(r.mod_block_reason(m, 1), "one Gun Mod per safehouse", "no second mod")
	eq(r.shop_patch_offer().size(), 2, "the shop is next")


func test_mod_needs_the_points_and_can_be_skipped() -> void:
	var r: DDRun = _at_safehouse(0)
	_take_boss_patch(r)
	var m: String = r.mod_offer[0]
	if r.mod_price() > 0:
		eq(r.mod_block_reason(m, 0), "need %d pts" % bal().shown(r.mod_price()), "too poor")
	check(bool(r.skip_mod()["ok"]), "skip")
	check(not r.mod_step_open(), "skipped")
	eq(r.slot_mod(0), "", "no mod")


func test_short_barrel_fit_can_finish_the_gun_now() -> void:
	var r: DDRun = _at_safehouse(40)
	_take_boss_patch(r)
	r.mod_offer = ["short_barrel", "echo"] as Array[String]
	gun(r, 0, "rifle", [9, 7, 5])
	var pv: Dictionary = r.mod_preview("short_barrel", 0)
	check(bool(pv["finishes"]), "the preview says the rifle fills at once")
	var e0: int = r.points_earned
	var ev: Dictionary = r.fit_mod("short_barrel", 0)
	eq((ev["collects"] as Array).size(), 1, "the rifle is collected")
	check(bool((ev["collects"][0] as Dictionary)["finished"]), "as a finished gun")
	check(r.points_earned > e0, "it pays the finish bonus")
	eq(r.slot(0), null, "and leaves")


func test_mods_save_round_trip() -> void:
	var r: DDRun = _at_safehouse(40)
	_take_boss_patch(r)
	var m: String = r.mod_offer[0]
	r.fit_mod(m, 1)
	var d: Dictionary = JSON.parse_string(JSON.stringify(r.to_dict()))
	var r2: DDRun = DDRun.from_dict(d)
	check(r2 != null, "loads")
	eq(r2.slot_mod(1), m, "the mod survives a save")
	check(r2.mod_fitted_here, "and so does 'fitted here'")
	var old: Dictionary = d.duplicate(true)
	old.erase("slot_mods")
	var r3: DDRun = DDRun.from_dict(old)
	check(r3 != null and r3.slot_mod(0) == "" and r3.slot_mod(1) == "", "a v4 save without mods still loads")


func test_mods_leave_the_safehouse_with_you() -> void:
	var r: DDRun = _at_safehouse(40)
	_take_boss_patch(r)
	var m: String = r.mod_offer[0]
	r.fit_mod(m, 0)
	r.leave_safehouse()
	eq(r.district_index, 1, "Downtown")
	eq(r.slot_mod(0), m, "the mod comes along")
	eq(r.mod_offer.size(), 0, "no offer on the street")
	eq(r.mod_block_reason(m, 1), "Gun Mods are fitted at a safehouse", "only at a safehouse")


# ---------------------------------------------------------------- rooms: door + one use
func test_room_total_cost_and_short_flag() -> void:
	var r: DDRun = plain_run(filler(8))
	for i: int in r.room_count():
		check(r.machine_min_price(i) > 0, "room %d: its machine has a price" % i)
		eq(r.room_total_cost(i), r.room_cost(i) + r.machine_min_price(i), "room %d: total = door + one use" % i)
	var wall: int = -1
	for i: int in r.room_count():
		if str(r.machine(i).get("kind", "")) == "wall":
			wall = i
	eq(r.machine_min_price(wall), bal().weapon_price(str(r.machine(wall)["wid"])), "Wall Rack: its gun's price")
	r.points = r.room_cost(wall)
	check(r.room_machine_short(wall), "door money only: the machine is out of reach this wave")
	r.points = r.room_total_cost(wall)
	check(not r.room_machine_short(wall), "door + gun: fine")
	r.points = r.room_cost(wall) - 1
	check(not r.room_machine_short(wall), "can't open: not 'short' either")

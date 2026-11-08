# v3 board: wave decks shuffle into the pile when it runs dry (dealing continues), opened rooms
# restock 1 card per new wave (cycling their pack), rooms open any time for their price (pack
# shuffled in, machine on), machines once per wave: Retrofit Bench (Trim / Flip / Hone), Patch
# Press (rising price, pick 1 of 2), Wall Rack (buy a known gun into a slot). Rooms reset.
extends "res://tests/dd_test_case.gd"


func test_pile_runs_dry_next_wave_shuffles_in() -> void:
	var r: DDRun = plain_run(["Z1", "Z2"], [])
	eq(r.wave_index, 1, "the pile ran dry while dealing: wave 2 shuffled in")
	eq(r.street.size(), 4, "dealing continued")
	eq(r.pile.size() + 2, bal().wave_spec(0, 1).size(), "wave 2's 8 cards: 2 dealt, rest in the pile")
	eq(r.wave_status(0), "done", "wave 1 done")
	eq(r.wave_status(1), "active", "wave 2 active")
	eq(r.wave_status(2), "waiting", "wave 3 waiting")
	eq(int(r.last_wave_info["wave"]), 1, "wave info for the banner")


func test_wave_zombies_match_the_sim() -> void:
	var b: DDBalance = bal()
	eq(b.wave_zombies(0, 0), [1, 2, 3, 3, 4, 5] as Array[int], "Maple Row wave 1")
	eq(b.wave_zombies(2, 2), [6, 7, 8, 9, 9, 10, 11] as Array[int], "St. Agnes wave 3")
	eq(b.wave_spec(0, 0).size(), 7, "6 zombies + a gun")


func test_open_room_any_time_shuffles_pack_in() -> void:
	var r: DDRun = plain_run(filler(6), [])
	var cost: int = r.room_cost(0)
	eq(cost, 21, "Garage costs 21 (dd-v3-tune)")
	check(not r.can_open_room(0), "can't afford")
	check(r.room_block_reason(0).contains("need"), "reason: need points")
	r.points = 40
	var n0: int = r.pile.size()
	var ev: Dictionary = r.open_room(0)
	check(bool(ev["ok"]), "opened")
	eq(r.points, 40 - cost, "paid")
	eq(r.pile.size(), n0 + 3, "3 pack cards shuffled into the pile")
	eq((ev["cards"] as Array).size(), 3, "event lists the cards (for the fly-in animation)")
	check(r.room_open[0], "room open")
	check(not r.can_open_room(0), "not twice")
	r.points = 99
	r.set_active(DDRun.MELEE)
	r.resolve(0, DDRun.USE)
	check(r.can_open_room(2), "rooms in any order, mid-street")
	r.open_room(2)
	check(r.room_open[2], "Workshop opened before the Corner Store")


func test_restock_one_card_per_room_per_wave() -> void:
	var r: DDRun = plain_run(filler(5), [])
	r.points = 999
	r.open_room(0)
	r.open_room(1)
	r.pile.clear()
	r.street.clear()
	r.setup_street([], [])
	eq(int(r.last_wave_info["restock"]), 2, "2 opened rooms restock 1 card each")
	eq(r.room_pack_i[0], 1, "Garage restock cycles its pack")
	eq(r.pile.size() + r.street.size(), bal().wave_spec(0, 1).size() + 2, "wave 2 + 2 restock cards")


func test_machines_once_per_wave() -> void:
	var r: DDRun = plain_run(filler(10), [])
	r.points = 999
	r.open_room(0)
	gun(r, 1, "rifle")
	var ev: Dictionary = r.use_machine(0, "slot2")
	check(bool(ev["ok"]), "Wall Rack bought")
	eq(r.slot(1).wid, "crossbow", "Garage Wall Rack: Ratchet Crossbow")
	eq(r.points, 999 - 21 - bal().weapon_price("crossbow"), "Wall Rack price 15")
	check(not bool(r.use_machine(0, "slot1")["ok"]), "once per wave")
	eq(str(r.machine_options(0)[0]["reason"]), "used this wave", "reason shown")
	r.pile.clear()
	r.street.clear()
	r.setup_street([], [])
	check(bool(r.machine_options(0)[0]["enabled"]), "a new wave resets the machine")


func test_bench_trim_flip_hone() -> void:
	var r: DDRun = plain_run(filler(10), ["Z6", "C2", "C2", "C2"])
	r.points = 999
	r.open_room(2)
	var g: DDGun = gun(r, 0, "rifle", [7, 2])
	var p0: int = r.points
	var ev: Dictionary = r.use_machine(2, "trim1")
	check(bool(ev["ok"]), "trim")
	eq(g.stack, [7] as Array[int], "top kill (2) removed")
	eq(r.points, p0 - bal().bench_price("trim"), "Trim: pay 5, the removed 2 is NOT paid again (it paid on the kill, K1)")
	eq(r.points_earned, 0, "Trim earns nothing")
	check(bool(r.preview(0, 0)["ok"]), "the rifle can take the 6 again")
	check(not bool(r.use_machine(2, "hone1")["ok"]), "Bench once per wave")
	r.machine_used[2] = false
	var flip_opts: Array = r.machine_options(2).filter(func(o: Dictionary) -> bool: return str(o["id"]) == "flip1")
	check(bool(flip_opts[0]["enabled"]), "Flip offered for a rifle")
	r.use_machine(2, "flip1")
	eq(g.rule, "up", "rifle now goes UP")
	check(g.flipped, "flipped plate")
	r.machine_used[2] = false
	r.use_machine(2, "hone1")
	eq(g.power, 5, "Hone +1 power")
	check(g.honed, "honed")
	r.machine_used[2] = false
	check(not bool(r.use_machine(2, "hone1")["ok"]), "Hone once per gun")
	gun(r, 1, "pistol")
	r.machine_used[2] = false
	check(not bool(r.use_machine(2, "flip2")["ok"]), "Flip only for down / up rules")
	check(not bool(r.use_machine(2, "trim2")["ok"]), "Trim needs a stack")


func test_patch_press_pick_and_price() -> void:
	var r: DDRun = plain_run(filler(10), [])
	r.points = 999
	r.open_room(1)
	eq(r.machine(1).get("kind"), "patch", "Corner Store: Patch Press")
	eq(int(r.machine_options(1)[0]["price"]), 15, "first Patch 15")
	var ev: Dictionary = r.use_machine(1, "press")
	check(bool(ev["ok"]), "pressed")
	var offer: Array = r.pending_patch["offer"]
	eq(offer.size(), 2, "2 Patches shown")
	check(not bool(r.attack(0, DDRun.MELEE)["ok"]) or r.street[0].kind != DDCard.ZOMBIE, "board waits for the pick")
	check(not r.can_open_room(2), "rooms wait for the pick")
	check(not bool(r.take_patch("nonsense")["ok"]), "only an offered one")
	r.take_patch(str(offer[0]))
	check(r.has_patch(str(offer[0])), "Patch owned")
	check(r.pending_patch.is_empty(), "offer closed")
	r.machine_used[1] = false
	eq(int(r.machine_options(1)[0]["price"]), 25, "next Patch 25")


func test_rooms_reset_next_district() -> void:
	var r: DDRun = make_run("rosa")
	r.points = 999
	r.open_room(0)
	clear_district(r)
	eq(r.phase, DDRun.Phase.SAFEHOUSE, "safehouse")
	r.leave_safehouse(str(r.pending_patch["offer"][0]) if not r.pending_patch.is_empty() else "")
	eq(r.district_index, 1, "Downtown")
	eq(r.room_open, [false, false, false] as Array[bool], "rooms closed again")
	eq(r.wave_index, 0, "wave 1")
	eq(r.room_cost(0), 27, "Subway Kiosk 27")


func test_lookout_shows_and_buries_the_top_card() -> void:
	var r: DDRun = plain_run(["C2", "C2", "C2", "C2", "Z9", "M4"], [])
	eq(r.lookout_card(), null, "no Patch: hidden")
	r.patches.append("lookout")
	eq(r.lookout_card().code(), "Z9", "Lookout: top card visible")
	check(bool(r.bury_top()["ok"]), "bury")
	eq(r.lookout_card().code(), "M4", "next one up")
	eq(r.pile[0].code(), "Z9", "Z9 at the bottom")
	check(not r.can_bury(), "once per street")


func test_loose_grip_once_per_wave() -> void:
	var r: DDRun = plain_run(filler(10), ["Z8", "Z9", "C2", "C2"])
	r.patches.append("loose_grip")
	r.loose = true
	gun(r, 0, "rifle", [3])
	var pr: Dictionary = r.preview(0, 0)
	check(bool(pr["ok"]) and bool(pr["uses_loose"]), "Loose Grip bends the rule")
	r.attack(0, 0)
	eq(r.slot(0).stack, [3, 8] as Array[int], "8 on a rifle at 3")
	check(not r.loose, "used up")
	check(not bool(r.preview(idx(r, "Z9"), 0)["ok"]), "only one per wave")

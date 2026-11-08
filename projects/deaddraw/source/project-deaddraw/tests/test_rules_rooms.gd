# Rooms and machines: doors open in order for points, between streets only; the loot pack goes
# into the deck at once (a short street refills); restock each wave; machines once per wave:
# Retrofit Bench, Grin Machine (price step), Lucky Locker (slot or leave), Wall Rack (buy / ammo).
# Rooms reset in the next district.
extends "res://tests/dd_test_case.gd"


func _room_of(r: DDRun, kind: String) -> int:
	for i: int in r.room_count():
		if str(r.machine(i).get("kind", "")) == kind:
			return i
	return -1


## Opens rooms 0..n (paying for them) on a fresh street.
func _open_to(r: DDRun, n: int) -> void:
	for i: int in n + 1:
		if not r.opened.has(i):
			r.points += int(r.room(i)["cost"])
			check(bool(r.open_room(i)["ok"]), "opened room %d" % i)


func test_doors_open_in_order_for_points() -> void:
	var r: DDRun = plain_run(filler(12))
	var cost0: int = int(r.room(0)["cost"])
	r.points = cost0 - 1
	check(not r.can_open_room(0), "can't afford")
	check(r.room_block_reason(0).begins_with("need"), "reason: need points")
	eq(r.room_status(1), "locked", "room 2 locked until room 1 is open")
	r.points = cost0 + 3
	var deck0: int = r.deck.size()
	var ev: Dictionary = r.open_room(0)
	check(bool(ev["ok"]), "opened")
	eq(r.points, 3, "paid")
	eq(int(ev["points_delta"]), -cost0, "event shows the spend")
	eq(r.deck.size(), deck0 + (r.room(0)["pack"] as Array).size(), "loot pack shuffled into the deck")
	eq(r.room_status(0), "open", "open")
	eq(r.room_status(1), "next", "next one buyable")
	eq(r.points_earned, 0, "spending doesn't count as earning")


func test_doors_only_between_streets() -> void:
	var r: DDRun = plain_run(filler(12))
	r.points = 999
	r.resolve(0, DDRun.USE)
	eq(r.room_block_reason(0), "between streets only", "not mid-street")


func test_opening_a_door_refills_a_short_street() -> void:
	var r: DDRun = plain_run([], ["B2", "B2", "B3"])
	eq(r.budget, 2, "short street")
	r.points = 999
	r.open_room(0)
	eq(r.street.size(), 4, "the new loot fills the street")
	eq(r.budget, 3, "3 actions again")


func test_restock_each_wave() -> void:
	var r: DDRun = plain_run([], ["B2", "B2", "B3"])
	r.opened.append(0)
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	eq(r.wave_index, 1, "wave 2")
	eq(int(r.last_wave_info["restock"]), bal().num("restock_per_room"), "1 restock card from the open room")
	eq(r.deck.size() + r.street.size(), 1 + bal().wave_zombies(0, 1).size() + bal().num("restock_per_room"), "Holdover + pack + restock")


func test_retrofit_bench() -> void:
	var r: DDRun = plain_run(filler(12))
	var i: int = _room_of(r, "retrofit")
	_open_to(r, i)
	r.setup_street(filler(12))
	var w: DDWeapon = r.slot(0)
	w.ammo = 2
	w.notch = 5
	var cost: int = int(bal().fixture_num("retrofit", "cost"))
	r.points = cost
	var opts: Array[Dictionary] = r.machine_options(i)
	eq(opts.size(), 2, "one option per slot")
	check(bool(opts[0]["enabled"]), "slot 1 can be retrofitted")
	check(str(opts[0]["result"]).contains("->"), "states the result before the tap")
	check(not bool(opts[1]["enabled"]), "slot 2 is empty")
	var p0: int = w.power
	var c0: int = w.cap
	var ev: Dictionary = r.use_machine(i, "retrofit1")
	check(bool(ev["ok"]), "used")
	var nw: DDWeapon = r.slot(0)
	eq(nw.power, p0 + int(bal().fixture_num("retrofit", "power")), "+2 power")
	eq(nw.cap, int(c0 * bal().fixture_num("retrofit", "mag_mult") + 0.5), "+50% magazine")
	eq(nw.ammo, nw.cap, "free full reload")
	eq(nw.notch, DDRun.NO_NOTCH, "notch cleared")
	check(nw.upgraded and nw.display_name().begins_with("Retrofit"), "named Retrofit")
	eq(r.points, 0, "paid")
	eq(str(r.machine_options(i)[0]["reason"]), "once per weapon", "once per weapon")
	check(r.machine_used(i), "and once per wave")


func test_grin_machine_price_steps_and_buffs() -> void:
	var r: DDRun = plain_run(filler(12))
	var i: int = _room_of(r, "grin")
	_open_to(r, i)
	r.setup_street(filler(12))
	var base: int = int(bal().fixture_num("grin", "cost"))
	var step: int = int(bal().fixture_num("grin", "step"))
	eq(r.grin_price(i), base, "first price")
	r.points = 999
	r.hp = 10
	var ev: Dictionary = r.use_machine(i, "grin")
	var e: String = str(ev["result"]["effect"])
	check(bal().list("grin_effects").has(e), "a Jawbreaker: " + e)
	if e == "sugar_rush":
		eq(r.hp, 10 + bal().rule("sugar_rush_heal"), "Sugar Rush heals")
	else:
		check(r.has_buff(e), "buff active")
	eq(r.grin_price(i), base + step, "price goes up")
	check(not bool(r.machine_options(i)[0]["enabled"]), "once per wave")
	r.machine_state[i]["used"] = false
	r.use_machine(i, "grin")
	eq(r.grin_price(i), base + step * 2, "and up again")


func test_jawbreaker_effects() -> void:
	var r: DDRun = plain_run(["Z6", "Z6", "B2", "B2"] + filler(4))
	r.buffs.append("steady_aim")
	eq(int(r.preview(0, DDRun.SLOT1)["hp_loss"]), 6 - r.slot(0).power - bal().rule("steady_aim_power"), "Steady Aim: guns +2")
	r.buffs = ["thick_skin"] as Array[String]
	eq(int(r.preview(0, DDRun.BARE)["hp_loss"]), 6 - bal().rule("thick_skin_reduction"), "Thick Skin: -1 damage")
	r.buffs = ["sleight"] as Array[String]
	r.resolve(0, DDRun.SLOT1)
	eq(int(r.reload_preview(0)["cost"]), 0, "Sleight of Hand: free reload")
	r.reload(0)
	eq(r.actions_used, 1, "reload didn't use an action")


func test_lucky_locker_offer() -> void:
	var r: DDRun = plain_run(filler(12))
	var i: int = _room_of_all(r, "locker")
	check(i >= 0, "a district has a Lucky Locker")
	_open_to(r, i)
	r.setup_street(filler(12))
	r.points = int(bal().fixture_num("locker", "cost"))
	var ev: Dictionary = r.use_machine(i, "locker")
	check(bool(ev["ok"]), "rolled")
	check(not r.pending_offer.is_empty(), "weapon waiting for a slot")
	check(bal().list("locker_pool").has((r.pending_offer["weapon"] as DDWeapon).wid), "from the pool")
	check(not bool(r.preview(0, DDRun.USE)["enabled"]), "street waits for the choice")
	check(not r.can_skip(), "no skip while choosing")
	var p0: int = r.points
	r.take_offer(DDRun.SCRAP)
	eq(r.points, p0 + int(bal().points("scrap")), "left it: scrap points")
	check(r.pending_offer.is_empty(), "offer done")
	check(bool(r.preview(0, DDRun.USE)["enabled"]), "street goes on")


## Opens districts until one has a machine of this kind (Lucky Locker is in Downtown).
func _room_of_all(r: DDRun, kind: String) -> int:
	for d: int in 3:
		var i: int = _room_of(r, kind)
		if i >= 0:
			return i
		clear_district(r)
		r.choose_perk(r.perk_offer[0] if not r.perk_offer.is_empty() else "")
	return -1


func test_wall_rack_buy_then_ammo() -> void:
	var r: DDRun = plain_run(filler(12))
	var i: int = _room_of(r, "wallrack")
	_open_to(r, i)
	r.setup_street(filler(12))
	var wid: String = str(r.machine(i)["wid"])
	r.points = bal().weapon_price(wid)
	var opts: Array[Dictionary] = r.machine_options(i)
	eq(str(opts[0]["id"]), "wall_buy", "buy option")
	r.use_machine(i, "wall_buy")
	check(not bool(r.offer_preview(DDRun.SCRAP)["enabled"]), "a bought gun can't be left")
	r.take_offer(DDRun.EQUIP2)
	eq(r.slot(1).wid, wid, "gun in slot 2")
	r.machine_state[i]["used"] = false
	opts = r.machine_options(i)
	eq(str(opts[0]["id"]), "wall_ammo", "now it sells ammo")
	r.slot(1).ammo = 0
	r.reserve = 0
	r.points = int(bal().fixture_num("wallrack", "ammo_cost"))
	r.use_machine(i, "wall_ammo")
	eq(r.slot(1).ammo, r.slot(1).cap, "magazine full")
	eq(r.reserve, r.slot(1).cap, "a magazine's worth into the reserve")


func test_rooms_reset_next_district() -> void:
	var r: DDRun = plain_run(filler(12))
	_open_to(r, 1)
	r.points = 77
	clear_district(r)
	r.choose_perk(r.perk_offer[0] if not r.perk_offer.is_empty() else "")
	eq(r.district_index, 1, "Downtown")
	eq(r.opened.size(), 0, "rooms closed again")
	check(r.points >= 77, "points carry over")

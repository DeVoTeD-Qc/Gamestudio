# Waves: the deck running out ends the wave (bonus, next pack + Skipped pile + restock), Skip and
# its limits, skipped cards coming back next wave, the last-street banner and next-wave preview,
# the boss wave's last lap and the boss street, Carriers.
extends "res://tests/dd_test_case.gd"


func test_wave_end_bonus_and_next_pack() -> void:
	var r: DDRun = plain_run([], ["B2", "B2", "B2"])
	var p0: int = r.points
	var ev: Dictionary = r.resolve(0, DDRun.USE)
	ev = r.resolve(0, DDRun.USE)
	eq(r.wave_index, 1, "wave 2 started")
	eq(r.points, p0 + int(bal().points("wave")), "wave bonus")
	check(ev.has("wave_changed"), "event carries the wave change")
	var info: Dictionary = ev["wave_changed"]
	eq(int(info["wave"]), 1, "banner: wave 2")
	eq((info["zombies"] as Array).size(), bal().wave_zombies(0, 1).size(), "banner lists the pack")
	var zs: Array = []
	for c: DDCard in r.deck + r.street:
		if c.kind == DDCard.ZOMBIE:
			zs.append(c.value)
	zs.sort()
	var want: Array = Array(bal().wave_zombies(0, 1))
	want.sort()
	eq(zs, want, "deck holds exactly the wave 2 pack")
	eq(r.street[0].code(), "B2", "the Holdover stays on the street")


func test_skip_returns_next_wave() -> void:
	var r: DDRun = plain_run(["Z9", "Z8", "M3", "A4", "B2", "B2", "B2", "B2"])
	var ev: Dictionary = r.skip()
	check(bool(ev["ok"]), "skipped")
	eq(r.skipped.size(), 4, "4 cards on the Skipped pile")
	check(r.skipped[0].skipped, "flagged as skipped")
	eq(r.street.size(), 4, "a new street is dealt")
	check(not r.can_skip(), "not twice in a row")
	eq(r.skip_block_reason(), "you skipped last street", "reason")
	# finish the wave: the 4 skipped cards come back in wave 2
	var guard: int = 0
	while r.wave_index == 0 and guard < 10:
		guard += 1
		r.resolve(0, DDRun.USE)
	eq(r.wave_index, 1, "wave 2")
	eq(r.skipped.size(), 0, "pile emptied")
	var back: int = 0
	for c: DDCard in r.deck + r.street:
		if c.skipped:
			back += 1
	eq(back, 4, "skipped cards are back in the new deck")
	eq(int(r.last_wave_info["skipped"]), 4, "banner counts them")


func test_skip_limits() -> void:
	var r: DDRun = plain_run(["B2", "B2", "B2", "B2"] + filler(8))
	r.resolve(0, DDRun.USE)
	eq(r.skip_block_reason(), "you already started this street", "no skip after acting")
	var s: DDRun = plain_run(filler(8))
	s.skip()
	s.buffs.append("light_step")
	check(s.can_skip(), "Light Step allows a second skip in a row")


func test_last_street_banner_and_preview() -> void:
	var r: DDRun = plain_run(["B2", "B2", "B2", "B2"])
	check(r.is_last_street(), "deck empty: last street")
	var nx: Dictionary = r.next_preview()
	eq(str(nx["kind"]), "wave", "next is a wave")
	check(str(nx["text"]).begins_with("Next: Wave 2 - "), "preview text: " + str(nx["text"]))
	r.opened.append(0)
	check(r.next_preview()["text"].contains("restock"), "preview counts restock once a room is open")


func test_boss_wave_last_lap_then_boss_street() -> void:
	var r: DDRun = plain_run([])
	to_boss_wave(r, [], ["B2", "B2", "B2", "B2"], ["M3", "Z2"])
	eq(r.next_preview()["kind"], "last_lap", "preview: last lap")
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	var ev: Dictionary = r.resolve(0, DDRun.USE)
	check(r.last_lap, "last lap started")
	check(bool(ev.get("last_lap", false)), "event says so")
	eq(r.street.size(), 3, "Holdover + the 2 skipped cards")
	check(not r.can_skip(), "no skipping on the last lap")
	eq(r.skip_block_reason(), "no skipping on the last lap", "reason")
	r.resolve(idx(r, "Z2"), DDRun.BARE)
	ev = r.resolve(idx(r, "M3"), DDRun.USE)
	check(r.boss_street, "boss street dealt")
	check(bool(ev.get("boss_street", false)), "event says so")
	var fin: int = (r.finale().get("zombies", []) as Array).size()
	eq(r.street.size(), 1 + fin, "Holdover + boss card(s)")
	eq(r.budget, r.street.size(), "resolve every card")
	check(not r.can_skip(), "no skipping the boss")


func test_boss_street_clears_the_district() -> void:
	var r: DDRun = plain_run([])
	to_boss_wave(r, [], ["B3"])
	check(r.boss_street, "boss street")
	r.resolve(idx(r, "B3"), DDRun.USE)
	r.cover = 40
	var ev: Dictionary = r.resolve(0, DDRun.BARE)
	check(bool(ev["district_cleared"]), "district cleared")
	eq(r.phase, DDRun.Phase.SAFEHOUSE, "safehouse")
	eq(r.cleared_ids, ["maple_row"] as Array[String], "Maple Row recorded")


func test_every_wave_pack_has_one_carrier_and_drops_work() -> void:
	var r: DDRun = make_run("rosa")
	for w: int in 3:
		var pack: Array[DDCard] = r.wave_pack(w)
		var n: int = 0
		for c: DDCard in pack:
			if c.drop != "":
				n += 1
				check(bal().list("drops").has(c.drop), "known drop " + c.drop)
		eq(n, 1, "one Carrier in wave %d" % (w + 1))
	var f: DDRun = plain_run(["Z3!full_load", "Z2!payday", "Z2!boards", "B2"] + filler(4))
	var g: DDWeapon = f.slot(0)
	g.ammo = 1
	g.notch = 4
	f.reserve = 0
	var ev: Dictionary = f.resolve(idx(f, "Z3!full_load"), DDRun.SLOT1)
	eq(str(ev.get("drop", "")), "full_load", "drop in the event")
	eq(g.ammo, g.cap, "Full Load fills the magazine")
	eq(g.notch, DDRun.NO_NOTCH, "and clears the notch")
	eq(f.reserve, bal().num("full_load_reserve"), "+reserve")
	f.resolve(idx(f, "Z2!payday"), DDRun.BARE)
	check(f.has_buff("payday"), "Payday buff")
	var p0: int = f.points
	f.resolve(idx(f, "Z2!boards"), DDRun.BARE)
	eq(f.points - p0, (int(2 * bal().points("kill")) + int(bal().points("up_close"))) * bal().rule("payday_mult"), "Payday doubles kill points")


func test_boards_drop_gives_cover() -> void:
	var r: DDRun = plain_run(["Z2!boards", "Z5", "B2", "B2"] + filler(4))
	r.resolve(0, DDRun.BARE)
	eq(r.cover, bal().num("boards_cover"), "Boards: cover now")


func test_buffs_end_with_the_wave() -> void:
	var r: DDRun = plain_run([], ["B2", "B2", "B2"])
	r.buffs.append("steady_aim")
	r.resolve(0, DDRun.USE)
	r.resolve(0, DDRun.USE)
	eq(r.wave_index, 1, "new wave")
	check(r.buffs.is_empty(), "buffs gone")

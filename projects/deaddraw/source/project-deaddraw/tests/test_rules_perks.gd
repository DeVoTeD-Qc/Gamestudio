# v3 + v4 Patches (permanent perks from the Patch Press / boss reward / Safehouse Shop) and
# survivor passives.
extends "res://tests/dd_test_case.gd"


func test_thick_jacket() -> void:
	var r: DDRun = plain_run(filler(8))
	r.pending_patch = {"offer": ["thick_jacket", "brawler"], "source": "press", "room": 1}
	r.take_patch("thick_jacket")
	eq(r.max_hp, 24, "+4 max HP")
	eq(r.hp, 24, "and heal 4")


func test_brawler() -> void:
	var r: DDRun = plain_run(filler(8))
	r.patches.append("brawler")
	eq(r.melee_power(), 3, "v4: bare hands 1 + 2")
	r.setup_street(filler(8), ["K:wrench", "C2", "C2", "C2"])
	r.resolve(0, DDRun.TAKE)
	eq(r.melee_power(), 3, "v4: no Brawler power on a melee weapon (wrench stays 3)")
	eq(r.melee_uses(), 4 + 1, "v4: Brawler +1 use on pick-up")
	check(DDText.patch_text("brawler", bal()).begins_with("Bare Hands hit 2 harder"), "Brawler v4 text")


func test_bounty_hunter_and_trophy_belt() -> void:
	var r: DDRun = plain_run(filler(8), ["Z3", "C2", "C2", "C2"])
	r.patches.append_array(["bounty", "trophy_belt"])
	gun(r, 0, "pistol", [3, 3, 3])
	r.hp = 10
	var p0: int = r.points
	r.attack(0, 0)
	eq(r.points - p0, 3 + bal().num("finish_bonus") + 4, "Bounty Hunter: +1 per zombie in the stack")
	eq(r.hp, 10 - 1 + bal().num("trophy_belt_heal"), "Trophy Belt: heal 2 on a finish")


func test_loose_grip_resets_each_wave() -> void:
	var r: DDRun = plain_run(["Z1"], [])
	r.patches.append("loose_grip")
	r.loose = false
	r.pile.clear()
	r.street.clear()
	r.setup_street([], [])
	check(r.loose, "a new wave gives Loose Grip back")


func test_second_wind_listed_and_text() -> void:
	for p: String in bal().patches():
		check(DDText.patch_text(p, bal()) != "", "Patch %s has rules text" % p)
		check(DDText.patch_name(p) != p or p == "", "Patch %s has a name" % p)
	eq(bal().patches().size(), 14, "14 Patches (v4: + 6)")


func test_survivor_passives() -> void:
	eq(DDText.passive_name("steady_hands"), "Steady Hands", "Rosa")
	var t: DDRun = make_run("theo", filler(8), ["Z9", "Z9", "Z9", "Z9"])
	eq(t.run_cost(), 0, "Theo: Run costs nothing")
	var r: DDRun = make_run("rosa")
	eq(r.run_cost(), 1, "others: 1")


# ---------------------------------------------------------------- v4 Patches
func test_lockpick() -> void:
	var r: DDRun = plain_run(filler(8))
	var c0: int = r.room_cost(0)
	r.patches.append("lockpick")
	eq(r.room_cost(0), c0 - bal().num("lockpick_off"), "rooms cost 5 (50 on screen) less")
	r.points = r.room_cost(0)
	check(r.can_open_room(0), "the lower price is what you need")
	r.open_room(0)
	eq(r.points, 0, "paid the Lockpick price")
	eq(DDText.patch_text("lockpick", bal()), "Rooms cost 50 less.", "card text")


func test_iron_stomach() -> void:
	var r: DDRun = plain_run(filler(8), ["M5", "M5", "C2", "C2"])
	r.hp = 18
	var pv: Dictionary = r.card_preview(0, DDRun.USE)
	eq([int(pv["heal"]), int(pv["overheal"]), int(pv["cover"])], [2, 3, 0], "without the Patch: 3 wasted")
	r.patches.append("iron_stomach")
	pv = r.card_preview(0, DDRun.USE)
	eq(int(pv["cover"]), 3, "preview: overflow 3 becomes Cover")
	r.resolve(0, DDRun.USE)
	eq([r.hp, r.cover], [20, 3], "healed to max, +3 Cover")
	# only medkits overflow (sim heal(..., overflow_cover) on medkits only)
	r.hp = 19
	r._heal(5)
	eq(r.cover, 3, "a plain heal does not make Cover")


func test_adrenaline() -> void:
	var r: DDRun = plain_run(filler(8), ["Z8", "Z8", "C2", "C2"])
	r.patches.append("adrenaline")
	gun(r, 0, "rifle", [])
	r.hp = 7
	eq(int(r.preview(0, 0)["damage"]), 8 - 4, "above 6 HP: no bonus")
	eq(r.melee_power(), 1, "bare hands 1")
	r.hp = 6
	eq(int(r.preview(0, 0)["damage"]), 8 - 5, "at 6 HP: +1 on guns")
	eq(int(r.preview(0, DDRun.MELEE)["damage"]), 8 - 2, "and on melee")
	eq(r.power_of(0), 5, "power_of shows it")
	var hp0: int = r.hp
	r.attack(0, 0)
	eq(hp0 - r.hp, 3, "the attack uses the boosted power")


func test_grudge() -> void:
	var r: DDRun = plain_run(filler(8), ["Z9", "Z8", "C2", "C2"])
	r.patches.append("grudge")
	gun(r, 0, "pistol", [])
	eq(int(r.preview(idx(r, "Z9"), 0)["damage"]), 9 - 3, "+1 against a 9")
	eq(int(r.preview(idx(r, "Z8"), 0)["damage"]), 8 - 2, "nothing against an 8")
	eq(r.melee_power(10), 2, "bare hands +1 against a 10")
	var b: DDRun = plain_run([], [])
	b.patches.append("grudge")
	to_boss(b, [])
	gun(b, 0, "pistol", [])
	eq(int(b.preview(0, 0)["damage"]), 9 - 3, "bosses too (Groundskeeper 9)")


func test_show_off() -> void:
	var r: DDRun = plain_run(filler(8), ["Z4", "C2", "C2", "C2"])
	r.patches.append("show_off")
	gun(r, 0, "pistol", [1, 2, 3])
	var p0: int = r.points
	var ev: Dictionary = r.attack(0, 0)
	var info: Dictionary = ev["collects"][0]
	check(bool(info["challenge"]), "Mixed Bag met")
	eq(int(info["show_off"]), bal().num("show_off_points"), "Show-Off +4")
	eq(r.points - p0, 4 + bal().num("finish_bonus") + 5 + 4, "kill 4 + finish 5 + Mixed Bag 5 + Show-Off 4")
	var r2: DDRun = plain_run(filler(8), ["Z4", "C2", "C2", "C2"])
	r2.patches.append("show_off")
	gun(r2, 0, "pistol", [4, 2, 3])
	p0 = r2.points
	r2.attack(0, 0)
	eq(r2.points - p0, 4 + bal().num("finish_bonus"), "no challenge: no Show-Off")


func test_whetstone() -> void:
	var r: DDRun = plain_run(filler(8), ["K:axe", "C2", "C2", "C2"])
	r.patches.append("whetstone")
	eq(int(r.card_preview(0, DDRun.TAKE)["uses"]), 3 + 2, "preview: axe 3 + 2 uses")
	r.resolve(0, DDRun.TAKE)
	eq(r.melee_uses(), 5, "Whetstone +2 uses")
	r.patches.append("brawler")
	r.setup_street(filler(8), ["K:sledge", "C2", "C2", "C2"])
	r.resolve(0, DDRun.TAKE)
	eq(r.melee_uses(), 2 + 2 + 1, "Whetstone and Brawler stack")

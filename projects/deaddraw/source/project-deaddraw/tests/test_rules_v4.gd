# DeadDraw v4 rules (core-rules-v4.md + the head's answers): Bare Hands and melee weapon cards
# with uses, the Stovepipe Launcher (one shot) and the Alley Sweeper (6 or less), the Safehouse
# Shop (points don't leave a district), and the card supply (melee cards in every Entrance and
# Wave 2, new guns in the district pools).
extends "res://tests/dd_test_case.gd"


# ---------------------------------------------------------------- melee
func test_bare_hands() -> void:
	var r: DDRun = plain_run(filler(8), ["Z4", "Z1", "C2", "C2"])
	r.set_active(DDRun.MELEE)
	eq(r.melee_name(), "Bare Hands", "no weapon: bare hands")
	eq(r.melee_power(), 1, "power 1")
	var pr: Dictionary = r.preview(0, DDRun.MELEE)
	eq(int(pr["damage"]), 3, "4 - 1")
	eq(int(pr["points"]), 0, "no points")
	eq(str(pr["melee_weapon"]), "", "no weapon in the preview")
	var p0: int = r.points
	for k: int in 2:
		r.attack(0)
	eq(r.points, p0, "bare-hands kills score nothing")
	eq(r.melee_name(), "Bare Hands", "unlimited: still there")


func test_take_a_melee_weapon_and_break_it() -> void:
	var r: DDRun = plain_run(filler(12), ["K:sledge", "Z9", "Z8", "C2"])
	eq(r.choices_for(0), [DDRun.TAKE, DDRun.SCRAP] as Array[String], "take or scrap")
	var pv: Dictionary = r.card_preview(0, DDRun.TAKE)
	check(bool(pv["ok"]), "take ok")
	eq(int(pv["uses"]), 2, "Sledgehammer 2 uses")
	eq(str(pv["replaces"]), "", "replaces nothing (bare hands)")
	r.resolve(0, DDRun.USE)   # the current UI taps a non-zombie card with USE: it takes the weapon
	check(r.has_melee_weapon(), "taken with USE as well")
	eq(r.melee, {"id": "sledge", "power": 6, "uses": 2}, "melee slot")
	eq(r.melee_name(), "Sledgehammer", "name")
	r.set_active(DDRun.MELEE)
	var p0: int = r.points
	var pr: Dictionary = r.preview(idx(r, "Z9"), DDRun.MELEE)
	eq([int(pr["damage"]), int(pr["uses_left"]), bool(pr["breaks"])], [3, 1, false], "9 - 6, 1 use left")
	r.attack(idx(r, "Z9"))
	eq(r.melee_uses(), 1, "one use spent")
	pr = r.preview(idx(r, "Z8"), DDRun.MELEE)
	check(bool(pr["breaks"]), "the next kill breaks it")
	var ev: Dictionary = r.attack(idx(r, "Z8"))
	check(bool(ev["melee_broke"]), "event: it broke")
	check(not r.has_melee_weapon(), "broken")
	eq(r.melee_power(), 1, "back to bare hands")
	eq(r.points, p0, "Q4: melee weapon kills score no points")
	eq(int(r.stats["melee_broken"]), 1, "stat")
	eq(int(r.stats["melee_weapon_kills"]), 2, "two weapon kills")
	var found: bool = false
	for l: String in r.log_lines:
		found = found or l.contains("Sledgehammer breaks")
	check(found, "log: it breaks")


func test_melee_card_replaces_and_scraps() -> void:
	var r: DDRun = plain_run(filler(8), ["K:wrench", "K:axe", "K:sledge", "C2"])
	r.resolve(0, DDRun.TAKE)
	var pv: Dictionary = r.card_preview(0, DDRun.TAKE)
	eq([str(pv["replaces"]), int(pv["replaces_uses"]), int(pv["uses"])], ["Pipe Wrench", 4, 3], "preview: the axe replaces the wrench (4 uses left)")
	r.resolve(0, DDRun.TAKE)
	eq(str(r.melee["id"]), "axe", "the axe replaced the wrench")
	var p0: int = r.points
	eq(int(r.card_preview(0, DDRun.SCRAP)["points"]), bal().num("scrap_points"), "scrap preview +20")
	r.resolve(0, DDRun.SCRAP)
	eq(r.points, p0 + bal().num("scrap_points"), "scrapped")
	eq(str(r.melee["id"]), "axe", "scrapping keeps your weapon")


func test_melee_card_texts() -> void:
	var c: DDCard = DDCard.parse("K:wrench")
	eq([c.kind, c.wid, c.code()], [DDCard.MELEE, "wrench", "K:wrench"], "parse / code")
	eq(DDText.card_name(c, bal()), "Pipe Wrench", "name")
	eq(DDText.kind_label(DDCard.MELEE), "MELEE", "kind label")
	check(DDText.melee_card_text("axe", bal()).begins_with("Power 4 - 3 uses"), "card text")
	eq(DDCard.from_dict(c.to_dict()).code(), "K:wrench", "round trip")


func test_v3_crowbar_setting() -> void:
	var b: DDBalance = DDBalance.from_file(DDBalance.DEFAULT_PATH)
	b.config["melee_mode"] = "crowbar"
	b.config["brawler_mode"] = "all"
	var r: DDRun = plain_run(filler(8), [], b)
	eq([r.melee_power(), r.melee_name()], [2, "Crowbar"], "v3 crowbar")
	r.patches.append("brawler")
	eq(r.melee_power(), 4, "v3 Brawler +2")


# ---------------------------------------------------------------- new guns
func test_stovepipe_launcher_one_shot() -> void:
	var r: DDRun = plain_run(filler(8), ["Z3", "Z11", "C2", "C2"])
	gun(r, 0, "launcher", [])
	eq(r.slot(0).cap, 1, "Q3: capacity 1 (one kill socket)")
	check(r.can_attack(idx(r, "Z3"), 0), "any zombie")
	var pr: Dictionary = r.preview(idx(r, "Z11"), 0)
	eq(int(pr["damage"]), 4, "11 - 7")
	check(bool(pr["finishes"]) and bool(pr["challenge"]), "one kill finishes it; 11 is a Big Bang")
	var p0: int = r.points
	var ev: Dictionary = r.attack(idx(r, "Z11"), 0)
	eq(r.points - p0, 11 + bal().num("finish_bonus") + 5, "11 + finish 5 + Big Bang 5")
	eq(r.slot(0), null, "the launcher is finished and leaves")
	eq(str((ev["collects"][0] as Dictionary)["challenge_id"]), "big_bang", "Big Bang")
	var r2: DDRun = plain_run(filler(8), ["Z8", "C2", "C2", "C2"])
	gun(r2, 0, "launcher", [])
	r2.attack(0, 0)
	eq(int(r2.stats["challenges"]), 0, "an 8 is not a Big Bang")
	eq(DDText.rule_tag("heavy"), "ONE SHOT", "rule tag")
	eq(DDText.challenge_name("big_bang"), "Big Bang", "challenge name")


func test_heavy_rule_one_kill_per_street() -> void:
	# the launcher has capacity 1, so this only shows with a bigger capacity (sim State.fired)
	var b: DDBalance = DDBalance.from_file(DDBalance.DEFAULT_PATH)
	(b.config["weapons"]["launcher"] as Dictionary)["cap"] = 2
	b.config["heavy_min"] = 5
	var r: DDRun = plain_run(filler(12), ["Z6", "Z7", "Z4", "C2"], b)
	gun(r, 0, "launcher", [])
	eq(str(r.preview(idx(r, "Z4"), 0)["reason"]), "rule: needs 5 or more", "heavy_min")
	r.attack(idx(r, "Z6"), 0)
	check(r.fired[0], "fired this street")
	eq(str(r.preview(idx(r, "Z7"), 0)["reason"]), "one kill per street", "no second kill this street")
	r.attack(idx(r, "Z7"), DDRun.MELEE)
	r.resolve(idx(r, "C2"), DDRun.USE)
	check(not r.fired[0], "a new street resets it")


func test_alley_sweeper_small_fry() -> void:
	var r: DDRun = plain_run(filler(8), ["Z7", "Z6", "C2", "C2"])
	gun(r, 0, "sweeper", [])
	check(not r.can_attack(idx(r, "Z7"), 0), "7 is too big, even on an empty stack")
	eq(str(r.preview(idx(r, "Z7"), 0)["reason"]), "rule: needs 6 or less", "reason")
	check(r.can_attack(idx(r, "Z6"), 0), "6 is fine")
	eq(r.can_take(r.slot(0)), [1, 2, 3, 4, 5, 6] as Array[int], "can take 1-6")
	eq(DDText.rule_tag("small"), "6 OR LESS", "rule tag")
	# Pest Control: the full stack totals 15 or less
	gun(r, 0, "sweeper", [2, 3, 4])
	eq(r.challenge_state(r.slot(0)), "on_track", "9 so far: on track")
	var p0: int = r.points
	r.attack(idx(r, "Z6"), 0)
	eq(r.points - p0, 6 + bal().num("finish_bonus") + 6, "total 15: Pest Control +6")
	var r2: DDRun = plain_run(filler(8), ["Z6", "C2", "C2", "C2"])
	gun(r2, 0, "sweeper", [5, 6])
	eq(r2.challenge_state(r2.slot(0)), "on_track", "11")
	gun(r2, 0, "sweeper", [5, 6, 6])
	eq(r2.challenge_state(r2.slot(0)), "broken", "17 > 15: broken")


func test_card_supply() -> void:
	var b: DDBalance = bal()
	var r: DDRun = make_run("rosa")
	var all: Array[DDCard] = r.pile.duplicate()
	all.append_array(r.street)
	var k: int = 0
	for c: DDCard in all:
		if c.kind == DDCard.MELEE:
			k += 1
			check(b.melee_pool(0).has(c.wid), "Maple Row melee card is from its pool")
	eq(k, 1, "one melee card in the Entrance")
	# every "W" in Downtown can be a launcher; every "K" a wrench or an axe
	r.district_index = 1
	var seen: Dictionary = {}
	for n: int in 300:
		for c: DDCard in r.make_cards(["W", "K"]):
			seen[c.code()] = true
	check(seen.has("W:launcher") and seen.has("W:sweeper"), "Downtown deals the new guns")
	check(seen.has("K:wrench") and seen.has("K:axe") and not seen.has("K:sledge"), "Downtown melee pool")
	eq(r.make_cards(["K:sledge", "W:launcher"]).map(func(c: DDCard) -> String: return c.code()), ["K:sledge", "W:launcher"], "fixed cards")


# ---------------------------------------------------------------- Safehouse Shop
func _at_safehouse(points: int, hp: int) -> DDRun:
	var r: DDRun = plain_run(filler(8))
	clear_district(r)
	r.points = points
	r.hp = hp
	return r


func test_shop_waits_for_the_boss_patch() -> void:
	var r: DDRun = _at_safehouse(60, 5)
	eq(r.phase, DDRun.Phase.SAFEHOUSE, "at the safehouse")
	check(not r.pending_patch.is_empty(), "boss Patch pending")
	eq(r.shop_patch_offer().size(), 0, "no shop offer before the boss Patch")
	eq(r.supplies_max(), 0, "no supplies before the boss Patch")
	eq(r.shop_patch_block_reason(), "pick your free Patch first", "reason")
	check(bool(r.shop_state()["waiting_for_boss_patch"]), "state says so")
	r.take_patch(str(r.pending_patch["offer"][0]))
	eq(r.shop_patch_offer().size(), 2, "then 2 Patches on offer")
	for p: String in r.shop_patch_offer():
		check(not r.has_patch(p), "offer excludes owned Patches")


func test_shop_patch_and_supplies() -> void:
	var r: DDRun = _at_safehouse(60, 5)
	r.take_patch(str(r.pending_patch["offer"][0]))
	var owned: int = r.patches.size()
	var price: int = bal().patch_price(owned)
	eq(r.shop_patch_price(), price, "the Patch Press price (%d owned)" % owned)
	var pick: String = r.shop_patch_offer()[0]
	var ev: Dictionary = r.buy_shop_patch(pick)
	check(bool(ev["ok"]), "bought")
	check(r.has_patch(pick), "sewn on")
	eq(r.points, 60 - price, "paid")
	eq(r.shop_patch_offer().size(), 0, "one Patch per safehouse")
	check(not bool(r.buy_shop_patch(pick)["ok"]), "not twice")
	# supplies: 3 points (30 on screen) per HP, up to max HP after the free safehouse heal
	var room: int = r.max_hp - mini(r.max_hp, r.hp + r.safehouse_heal())
	eq(r.supplies_max(), mini(r.points / 3, room), "max HP you can buy")
	var pts: int = r.points
	var hp0: int = r.hp
	var n: int = mini(2, r.supplies_max())
	check(bool(r.buy_supplies(n)["ok"]), "bought %d HP" % n)
	eq([r.hp, r.points], [hp0 + n, pts - 3 * n], "healed now, paid 3 per HP")
	check(not bool(r.buy_supplies(999)["ok"]), "can't buy past max HP")
	var left: int = r.points
	eq(int(r.shop_state()["left_behind"]), left, "state: what leaving loses")
	eq(DDText.leave_text(left, bal()), "LEAVE - %d left behind" % bal().shown(left), "Leave button text")
	var earned: int = r.points_earned
	var lv: Dictionary = r.leave_safehouse()
	check(bool(lv["ok"]), "left")
	eq(int(lv["left_behind"]), left, "event: left behind")
	eq(r.points, 0, "points don't leave the district")
	eq(r.points_earned, earned, "the score keeps them")
	eq(r.district_index, 1, "Downtown")
	eq(r.hp, mini(r.max_hp, hp0 + n + bal().num("safehouse_heal")), "the free heal still comes on leaving")


func test_supplies_capped_by_the_free_heal() -> void:
	var r: DDRun = _at_safehouse(90, 15)
	r.take_patch(str(r.pending_patch["offer"][0]))
	if r.has_patch("thick_jacket"):
		r.hp -= bal().num("thick_jacket_hp")
	eq(r.supplies_max(), maxi(0, r.max_hp - mini(r.max_hp, r.hp + 8)), "only what the free heal won't cover")
	r.hp = r.max_hp - 3
	eq(r.supplies_max(), 0, "the free heal fills you up: nothing to buy")
	eq(r.supplies_block_reason(1), "the rest heals you to full", "reason")


func test_carry_all_setting_keeps_points() -> void:
	var b: DDBalance = DDBalance.from_file(DDBalance.DEFAULT_PATH)
	b.config["carry_mode"] = "all"
	var r: DDRun = plain_run(filler(8), [], b)
	clear_district(r)
	r.points = 40
	r.leave_safehouse(str(r.pending_patch["offer"][0]) if not r.pending_patch.is_empty() else "")
	eq(r.points, 40, "v3: points carry over")
	check(not r.shop_enabled(), "no shop")


func test_shop_after_running_past_the_boss() -> void:
	var r: DDRun = plain_run(filler(8))
	to_boss(r, [])
	r.run_past()
	eq(r.phase, DDRun.Phase.SAFEHOUSE, "safehouse")
	check(r.pending_patch.is_empty(), "no boss Patch")
	eq(r.shop_patch_offer().size(), 2, "the shop is open at once")

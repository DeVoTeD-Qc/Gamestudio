# dd-v4-impl UI hooks: DDV4Hooks (melee slot, melee cards, salvage "+N", launcher socket, Run,
# shop payloads; every payload has an inspect title / body and the t1 / t2 tooltip) and the
# DDShopPanel (buy a Patch, buy supplies, Leave with "N left behind", right click inspects).
extends "res://tests/dd_test_case.gd"

const Art: GDScript = preload("res://scripts/ui/dd_art.gd")


func _tip(p: Dictionary, what: String) -> void:
	check(str(p.get("title", "")) != "" and str(p.get("body", "")) != "", what + ": title + body")
	check(str(p.get("t1", "")) != "" and str(p.get("t2", "")) != "", what + ": 2-line tooltip")


func test_melee_hooks() -> void:
	var r: DDRun = plain_run(filler(8), ["K:wrench", "K:axe", "Z5", "C2"])
	var sp: Dictionary = DDV4Hooks.melee_spec(r)
	check(bool(sp["bare"]) and str(sp["name"]) == "Bare Hands" and int(sp["power"]) == 1, "bare hands tile")
	check((sp["art_keys"] as Array).has("melee_bare_hands"), "bare hands art key")
	check(Art.texture_for(sp["art_keys"]) != null, "bare hands art exists")
	_tip(sp["payload"], "bare hands zoom")
	var cs: Dictionary = DDV4Hooks.melee_card_spec(r.street[0], 0, r)
	eq(str(cs["title"]), "Pipe Wrench", "melee card tile")
	check(Art.texture_for(cs["art_keys"]) != null, "wrench art exists")
	check(Art.texture_for(Art.card_keys(r.street[0])) != null, "the generic card lookup finds the wrench too")
	_tip(cs["payload"], "melee card zoom")
	var ch: Array[Dictionary] = DDV4Hooks.melee_choices(r, 0)
	eq([str(ch[0]["choice"]), str(ch[1]["choice"])], [DDRun.TAKE, DDRun.SCRAP], "TAKE / SCRAP")
	r.resolve(0, DDRun.TAKE)
	ch = DDV4Hooks.melee_choices(r, 0)
	check(str(ch[0]["label"]).contains("replaces Pipe Wrench (4 uses left)"), "TAKE label names the replaced weapon: " + str(ch[0]["label"]))
	sp = DDV4Hooks.melee_spec(r)
	eq([bool(sp["bare"]), int(sp["uses"]), int(sp["uses_max"]), int(sp["power"])], [false, 4, 4, 3], "wrench tile: 4 use pips")
	_tip(sp["payload"], "wrench zoom")
	for mid: String in ["wrench", "axe", "sledge"]:
		check(Art.texture_for(DDV4Hooks.melee_art_keys(mid, bal().melee_name(mid))) != null, "art for " + mid)


func test_gun_hooks() -> void:
	var r: DDRun = plain_run(filler(8), ["W:launcher", "C2", "C2", "C2"])
	gun(r, 0, "rifle", [9, 7, 5])
	eq(DDV4Hooks.equip_label(r, 0, 0), "INTO SLOT 1\nreplaces Hunting Rifle 3/4 · salvage +30", "equip sheet shows salvage")
	eq(DDV4Hooks.equip_label(r, 0, 1), "INTO SLOT 2\n(empty)", "empty slot")
	var ev: Dictionary = r.resolve(0, DDRun.EQUIP1)
	var fl: Array[Dictionary] = DDV4Hooks.salvage_floats(ev, bal())
	eq(fl.size(), 1, "one salvage float")
	eq([int(fl[0]["slot"]), int(fl[0]["shown"]), str(fl[0]["text"])], [0, 30, "SALVAGE +30"], "+30 over slot 1")
	eq(DDV4Hooks.play_salvage(null, [], ev, bal()).size(), 1, "play_salvage is safe without views")
	eq(DDV4Hooks.sockets(r.slot(0)).size(), 1, "the launcher has one kill socket")
	check(Art.texture_for(Art.weapon_keys("launcher", "Stovepipe Launcher")) != null, "launcher art")
	check(Art.texture_for(Art.weapon_keys("sweeper", "Alley Sweeper")) != null, "sweeper art")
	check(Art.texture_for(Art.rule_keys("heavy")) != null and Art.texture_for(Art.rule_keys("small")) != null, "rule icons")
	_tip(DDV4Hooks.run_payload(r), "Run zoom")


func test_shop_panel() -> void:
	var r: DDRun = plain_run(filler(8))
	clear_district(r)
	r.take_patch(str(r.pending_patch["offer"][0]))
	r.points = 50
	r.hp = 4
	var panel: DDShopPanel = DDShopPanel.new()
	var got: Array = []
	var inspected: Array = []
	var left: Array = []
	panel.changed.connect(func(ev: Dictionary) -> void: got.append(str(ev["kind"])))
	panel.inspect_requested.connect(func(p: Dictionary) -> void: inspected.append(p))
	panel.leave_requested.connect(func() -> void: left.append(true))
	panel.setup(r, true)
	var buy: Button = panel.find_child("ShopBuySupplies", true, false)
	check(buy != null and not buy.disabled, "supplies button")
	buy.pressed.emit()
	eq(got, ["supplies"], "bought 1 HP")
	eq([r.hp, r.points], [5, 47], "healed 1 for 30 on screen")
	var offer: Array[String] = r.shop_patch_offer()
	var pb: Button = panel.find_child("ShopPatch_" + offer[0], true, false)
	check(pb != null, "a BUY button per offered Patch")
	var rc: InputEventMouseButton = InputEventMouseButton.new()
	rc.button_index = MOUSE_BUTTON_RIGHT
	rc.pressed = true
	pb.gui_input.emit(rc)
	eq(inspected.size(), 1, "right click inspects the Patch")
	pb.pressed.emit()
	check(r.has_patch(offer[0]), "Patch bought")
	var lv: Button = panel.find_child("ShopLeave", true, false)
	eq(lv.text, DDText.leave_text(r.points, bal()), "Leave says what is left behind")
	lv.pressed.emit()
	eq(left.size(), 1, "Leave asks the screen to leave")
	_tip(DDV4Hooks.supplies_payload(r), "supplies zoom")
	_tip(DDV4Hooks.leave_payload(r), "leave zoom")
	panel.free()

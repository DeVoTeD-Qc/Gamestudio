# Headless UI flow (v3): the Main scene builds every screen in phone portrait and landscape; the
# street matches the head's layout (wave decks + boss LEFT, draw pile TOP MIDDLE, 3 room decks
# with price + OPEN on the RIGHT, the street, the 2 gun cards with their kill stacks + melee at
# the BOTTOM); every tile is inspectable and inside the screen; the active weapon toggles; a tap
# on a zombie attacks with it (damage chip before, the kill lands on the stack after); a rule lock
# blocks the tap with the reason; gun cards open the slot / scrap sheet; OPEN is lit only when
# affordable; machines open their sheet (Bench, Patch Press -> mandatory pick, Wall Rack); Run;
# first-run hints show and dismiss; boss streets (Run past, NO ESCAPE); safehouse and end screens.
extends "res://tests/dd_test_case.gd"


func _views(n: Node, out: Array) -> Array:
	for c: Node in n.get_children():
		if c is DDCardView and not c.has_meta(&"ghost"):
			out.append(c)
		_views(c, out)
	return out


func _buttons(n: Node, out: Array) -> Array:
	for c: Node in n.get_children():
		if c is Button:
			out.append(c)
		_buttons(c, out)
	return out


func _button(m: Node, prefix: String) -> Button:
	for b: Variant in _buttons(m, []):
		if (b as Button).text.begins_with(prefix) and (b as Button).is_visible_in_tree():
			return b
	return null


func _named(m: Node, nm: String) -> Node:
	return m.find_child(nm, true, false)


func _view_idx(m: Node, i: int) -> DDCardView:
	for v: Variant in _views(m, []):
		if (v as DDCardView).index == i:
			return v
	return null


var _paths: Array[String] = []


func _main() -> Control:
	var game: Node = tree.root.get_node_or_null("Game")
	var pp: String = "user://dd_test_ui_profile_%d.json" % Time.get_ticks_usec()
	_paths.append(pp)
	_paths.append(pp + ".run")
	game.set("profile", DDProfile.new(bal(), pp))
	game.set("run_save", DDRunSave.new(pp + ".run"))
	var m: Control = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	tree.root.add_child(m)
	return m


func _cleanup() -> void:
	for p: String in _paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_paths.clear()


func _settle() -> void:
	for k: int in 3:
		await tree.process_frame


func _all_inspectable_and_on_screen(m: Control, where: String, need_tiles: bool = true) -> void:
	var vs: Array = _views(m, [])
	if need_tiles:
		check(vs.size() > 0, "%s: has tiles" % where)
	var vp: Rect2 = m.get_viewport_rect()
	for v: Variant in vs:
		var cv: DDCardView = v
		if not cv.is_visible_in_tree():
			continue
		check(not cv.payload.is_empty(), "%s: tile '%s' (%d) is inspectable" % [where, cv.kind, cv.index])
		var r: Rect2 = cv.get_global_rect()
		check(r.position.x >= -1 and r.position.y >= -1 and r.end.x <= vp.size.x + 1 and r.end.y <= vp.size.y + 1,
			"%s: tile %s/%d inside the screen (%s in %s)" % [where, cv.kind, cv.index, str(r), str(vp.size)])
	for b: Variant in _buttons(m, []):
		var bb: Button = b
		if not bb.is_visible_in_tree():
			continue
		var r2: Rect2 = bb.get_global_rect()
		check(r2.end.x <= vp.size.x + 1 and r2.end.y <= vp.size.y + 1, "%s: button '%s' inside the screen (%s)" % [where, bb.text.replace("\n", " "), str(r2)])
		check(r2.size.y >= 44, "%s: button '%s' is a big enough tap target (%s)" % [where, bb.text.replace("\n", " "), str(r2.size)])


func test_street_layout_and_flow_portrait_and_landscape() -> void:
	var game: Node = tree.root.get_node_or_null("Game")
	if game == null:
		check(false, "Game autoload missing from the test runner")
		return
	for sz: Vector2i in [Vector2i(390, 844), Vector2i(844, 390)]:
		tree.root.size = sz
		var tag: String = "%dx%d" % [sz.x, sz.y]
		var m: Control = _main()
		await _settle()
		eq(m.call("screen_name"), "TITLE", tag + " title first")
		_all_inspectable_and_on_screen(m, tag + " title")
		m.call("_start_run")
		await _settle()
		eq(m.call("screen_name"), "MAP", tag + " map")
		_all_inspectable_and_on_screen(m, tag + " map")
		m.call("enter_district")
		await _settle()
		eq(m.call("screen_name"), "STREET", tag + " street")
		var run: DDRun = game.get("run")
		# K5: first-run hint (pick a weapon then tap zombies)
		eq(str(m.get("hint_id")), "weapon", tag + " first hint: pick a weapon, tap zombies")
		check(_named(m, "Hint") != null, tag + " hint shown")
		# dd-ui-clean: the hint is a floating toast: it takes no layout space, so no card moves or
		# resizes when it comes or goes, and it never covers the gun row or the draw pile
		var hint_c: Control = _named(m, "Hint") as Control
		var c0: Rect2 = _view_idx(m, 0).get_global_rect()
		var gun_r: Rect2 = _view_idx(m, 200).get_global_rect()
		var pile_r: Rect2 = _view_idx(m, 400).get_global_rect()
		if hint_c != null:
			var hr: Rect2 = hint_c.get_global_rect()
			var vps: Vector2 = m.get_viewport_rect().size
			check(hr.end.y <= vps.y + 1 and hr.position.y >= -1, tag + " hint toast on screen (%s in %s)" % [str(hr), str(vps)])
			check(not hr.grow(-1).intersects(gun_r), tag + " hint toast clear of the gun row")
			check(not hr.grow(-1).intersects(pile_r), tag + " hint toast clear of the draw pile")
		m.call("dismiss_hint")
		await _settle()
		check(str(m.get("hint_id")).begins_with("rule_"), tag + " next hint: the active gun's rule (%s)" % str(m.get("hint_id")))
		m.call("dismiss_hint")
		await _settle()
		eq(_view_idx(m, 0).get_global_rect(), c0, tag + " street card unmoved when the hint goes")
		eq(_view_idx(m, 200).get_global_rect(), gun_r, tag + " gun unmoved when the hint goes")
		_all_inspectable_and_on_screen(m, tag + " street")
		# the head's layout
		var w1: DDCardView = _view_idx(m, 300)
		var boss: DDCardView = _view_idx(m, 410)
		var pile: DDCardView = _view_idx(m, 400)
		var room0: DDCardView = _view_idx(m, 100)
		var g1: DDCardView = _view_idx(m, 200)
		var g2: DDCardView = _view_idx(m, 201)
		var melee: DDCardView = _view_idx(m, 202)
		var st0: DDCardView = _view_idx(m, 0)
		check(w1 != null and boss != null and pile != null and room0 != null and g1 != null and g2 != null and melee != null and st0 != null, tag + " every zone is on screen")
		if st0 == null or pile == null or w1 == null or room0 == null or g1 == null:
			m.queue_free()
			continue
		# dd-ux-v4 (direction B, the Door row): the wave door and the room doors in one row
		# (portrait) or one column (landscape), the pile right under the street, the guns at the
		# bottom (portrait) or in the right column (landscape)
		var portrait_now: bool = bool(m.get("portrait"))
		var wr: Rect2 = w1.get_global_rect()
		var rr: Rect2 = room0.get_global_rect()
		if portrait_now:
			check(absf(wr.position.y - rr.position.y) < 2.0 and wr.position.x < rr.position.x, tag + " wave door then the rooms, one row")
		else:
			check(absf(wr.position.x - rr.position.x) < 2.0 and wr.position.y < rr.position.y, tag + " wave door then the rooms, one column")
		check(absf(wr.size.y - rr.size.y) < 2.0 and absf(wr.size.x - rr.size.x) < 2.0, tag + " the wave door is the size of a room door")
		check(wr.encloses(boss.get_global_rect()), tag + " the boss chip sits on the wave door")
		check(pile.get_global_rect().position.y >= st0.get_global_rect().end.y - 1, tag + " pile next to the street, under it")
		if portrait_now:
			check(g1.get_global_rect().position.y > st0.get_global_rect().end.y - 1, tag + " guns at the BOTTOM")
		else:
			check(g1.get_global_rect().position.x > st0.get_global_rect().end.x - 1, tag + " guns in the RIGHT column")
		check(_named(m, "Open0") != null, tag + " each room has an OPEN button")
		check((_named(m, "Open0") as Button).text.contains(str(bal().shown(bal().room_cost(0, 0)))), tag + " OPEN shows the price")
		check((_named(m, "Open0") as Button).disabled, tag + " OPEN is off when you can't pay")
		# active weapon: melee, then the pistol
		run.setup_street(["Z5", "Z3", "W:rifle", "M4"] + filler(10, "Z2"))
		m.call("tap_weapon", DDRun.MELEE)
		await _settle()
		eq(run.active, DDRun.MELEE, tag + " melee active")
		var z5: DDCardView = _view_idx(m, idx(run, "Z5"))
		eq(str(z5.payload.get("title", "")), "Lurcher", tag + " zombie zoom")
		var spec5: Dictionary = (m.get("_street_specs") as Dictionary)[run.street[idx(run, "Z5")].get_instance_id()]
		eq(str(spec5["badge"]), "-4", tag + " damage chip with melee (v4 bare hands: 5 - 1)")
		m.call("tap_weapon", DDRun.SLOT1)
		await _settle()
		eq(run.active, DDRun.SLOT1, tag + " pistol active")
		spec5 = (m.get("_street_specs") as Dictionary)[run.street[idx(run, "Z5")].get_instance_id()]
		eq(str(spec5["badge"]), "-3", tag + " damage chip with the pistol (5 - 2)")
		# tap a zombie: it attacks with the active gun and lands on the stack
		var pts0: int = run.points
		var pips: Node = _named(m, "ResolvePips")
		check(pips != null and pips.get_child_count() == 3, tag + " 3 resolve pips")
		m.call("tap_street", idx(run, "Z5"))
		await _settle()
		pips = _named(m, "ResolvePips")
		var filled: int = 0
		for c: Node in pips.get_children():
			if c.has_meta(&"filled") and bool(c.get_meta(&"filled")):
				filled += 1
		eq(filled, 1, tag + " one pip filled after one resolve")
		eq(run.slot(0).stack, [5] as Array[int], tag + " kill on the pistol's stack")
		eq(run.points - pts0, 5, tag + " +5 points (K1)")
		var gv: DDGunView = m.get("_gun_views")[0]
		eq(gv.stack_cards.size(), 1, tag + " the gun card shows the stack")
		eq(gv.stack_cards[0].big_label.text, "5", tag + " the number is visible")
		check(not gv.stack_cards[0].payload.is_empty(), tag + " stack card inspectable")
		# gun card with slot 2 empty (dd-ux-equip): a tap equips it straight into the empty slot
		m.call("tap_street", idx(run, "W:rifle"))
		await _settle()
		eq((m.get("sheet") as Dictionary).size(), 0, tag + " no sheet with an empty slot")
		eq(run.slot(1).wid, "rifle", tag + " rifle auto-equipped in slot 2")
		eq(run.slot(0).name, "Service Pistol", tag + " the pistol stays in slot 1")
		# street ended after 2 resolves? no: 2 of 3 used; resolve the medkit
		m.call("tap_street", idx(run, "M4"))
		await _settle()
		check(run.resolved == 0, tag + " the street ended after 3 resolves (Holdover + new cards)")
		# rule lock: rifle on a stack of 3 can't take a 5
		run.setup_street(["Z5", "Z2", "C2", "C2"] + filler(10, "Z2"))
		run.slot(1).stack = [3] as Array[int]
		run.set_active(1)
		m.call("_render")
		await _settle()
		var lspec: Dictionary = (m.get("_street_specs") as Dictionary)[run.street[idx(run, "Z5")].get_instance_id()]
		eq(str(lspec["badge"]), "LOCK", tag + " LOCK before the tap")
		m.call("tap_street", idx(run, "Z5"))
		await _settle()
		eq(run.resolved, 0, tag + " a locked tap spends nothing")
		check(str(m.get("last_block")).contains("needs ≤3"), tag + " and says why: " + str(m.get("last_block")))
		# dd-ux-text (playtest): the blocked tap answers at once with a toast saying why
		var toast: Node = m.find_child("BlockToast", true, false)
		check(toast != null and str((toast.find_child("ToastText", true, false) as Label).text).contains("needs ≤3"), tag + " a toast says why")
		# Run
		var rb: Button = _named(m, "Run")
		check(rb != null and not rb.disabled and rb.text.begins_with("RUN"), tag + " Run button")
		rb.pressed.emit()
		await _settle()
		eq(int(run.stats["runs"]), 1, tag + " ran")
		check((_named(m, "Run") as Button).disabled, tag + " not twice in a row")
		# rooms: OPEN lights up when you can pay; USE opens the machine sheet
		run.points = 200
		m.call("_render")
		await _settle()
		var ob: Button = _named(m, "Open0")
		check(not ob.disabled, tag + " OPEN lit when affordable")
		ob.pressed.emit()
		await _settle()
		check(run.room_open[0], tag + " Garage open")
		check(_named(m, "Use0") != null, tag + " the opened room shows USE")
		(_named(m, "Use0") as Button).pressed.emit()
		await _settle()
		check(_button(m, "BUY INTO SLOT 1") != null, tag + " Wall Rack sheet (%s)" % str(m.get("sheet")))
		_button(m, "BUY INTO SLOT 1").pressed.emit()
		await _settle()
		eq(run.slot(0).wid, "crossbow", tag + " bought the Crossbow")
		await tree.process_frame
		(m.get("_inspect") as DDInspect).close()
		m.call("do_open_room", 1)
		await _settle()
		m.call("open_machine", 1)
		await _settle()
		_button(m, "PRESS A PATCH").pressed.emit()
		await _settle()
		check(_named(m, "Sheet") != null, tag + " the Patch pick is a sheet")
		check(_button(m, "TAKE ") != null, tag + " with TAKE buttons")
		check(_button(m, "Close") == null and _button(m, "Cancel") == null, tag + " that must be answered")
		var tb: Button = _button(m, "TAKE ")
		tb.pressed.emit()
		await _settle()
		eq(run.patches.size(), 1, tag + " Patch taken")
		(m.get("_inspect") as DDInspect).close()
		await _settle()
		_all_inspectable_and_on_screen(m, tag + " street with a Patch chip and open rooms")
		run.points = 200
		m.call("do_open_room", 2)
		await _settle()
		m.call("open_machine", 2)
		await _settle()
		check(_button(m, "TRIM") != null and _button(m, "FLIP") != null and _button(m, "HONE") != null, tag + " Bench: Trim / Flip / Hone with prices")
		m.call("close_sheet")
		await _settle()
		m.queue_free()
		await tree.process_frame
	_cleanup()


func test_boss_streets() -> void:
	var game: Node = tree.root.get_node_or_null("Game")
	for sz: Vector2i in [Vector2i(390, 844), Vector2i(844, 390)]:
		tree.root.size = sz
		var tag: String = "%dx%d" % [sz.x, sz.y]
		var m: Control = _main()
		await _settle()
		m.call("apply_debug", {"screen": "street", "boss": "1", "seed": "4"})
		m.call("_render")
		await _settle()
		var run: DDRun = game.get("run")
		check(run.boss_street, tag + " Maple Row boss street")
		check(_named(m, "RunPast") != null and not (_named(m, "RunPast") as Button).disabled, tag + " Run past offered")
		check(_named(m, "Run") == null, tag + " no Run on a boss street")
		_all_inspectable_and_on_screen(m, tag + " boss street")
		m.call("apply_debug", {"screen": "street", "boss": "1", "district": "2", "seed": "4"})
		m.call("_render")
		await _settle()
		run = game.get("run")
		check(_named(m, "NoEscape") != null, tag + " Patient Zero: NO ESCAPE banner")
		check(_named(m, "RunPast") == null and _named(m, "Run") == null, tag + " no Run, no Run past")
		var pz: int = -1
		for k: int in run.street.size():
			if run.street[k].phase == 1:
				pz = k
		check(pz >= 0, tag + " phase 1 on the street")
		m.queue_free()
		await tree.process_frame
	_cleanup()


func test_safehouse_and_end_screens() -> void:
	for sz: Vector2i in [Vector2i(390, 844), Vector2i(844, 390)]:
		tree.root.size = sz
		var tag: String = "%dx%d" % [sz.x, sz.y]
		var m: Control = _main()
		await _settle()
		m.call("apply_debug", {"screen": "safehouse"})
		m.call("_render")
		await _settle()
		eq(m.call("screen_name"), "SAFEHOUSE", tag + " safehouse")
		_all_inspectable_and_on_screen(m, tag + " safehouse")
		# v4: no way out before the free boss Patch is taken; tapping it sews it on and opens the shop
		check(_named(m, "ShopLeave") == null and _named(m, "LeaveSafehouse") == null, tag + " pick the free Patch first")
		var run: DDRun = tree.root.get_node("Game").get("run")
		var pid: String = str(run.pending_patch["offer"][0])
		var bp: DDCardView = _named(m, "BossPatch_" + pid)
		check(bp != null, tag + " the boss Patches are tiles")
		bp.tapped.emit(bp)
		await _settle()
		check(run.has_patch(pid) and run.pending_patch.is_empty(), tag + " a tap takes the boss Patch")
		var go: Button = _named(m, "ShopLeave")
		check(go != null and not go.disabled and go.text.begins_with("LEAVE"), tag + " then the shop's LEAVE: " + (go.text if go != null else "-"))
		_all_inspectable_and_on_screen(m, tag + " safehouse shop")
		go.pressed.emit()
		await _settle()
		eq(m.call("screen_name"), "MAP", tag + " map after the safehouse")
		eq(run.district_index, 1, tag + " Downtown next")
		m.call("apply_debug", {"screen": "end"})
		m.call("_render")
		await _settle()
		eq(m.call("screen_name"), "END", tag + " end screen")
		_all_inspectable_and_on_screen(m, tag + " end", false)
		check(_button(m, "Run again") != null, tag + " run again")
		m.queue_free()
		await tree.process_frame
	_cleanup()


func test_finish_moment_in_the_ui() -> void:
	var game: Node = tree.root.get_node_or_null("Game")
	tree.root.size = Vector2i(390, 844)
	var m: Control = _main()
	await _settle()
	m.call("apply_debug", {"screen": "street", "near": "1", "seed": "2"})
	m.call("_render")
	await _settle()
	var run: DDRun = game.get("run")
	eq(run.slot(0).kills_left(), 1, "one kill from finishing")
	var spec: Dictionary = (m.get("_street_specs") as Dictionary)[run.street[0].get_instance_id()]
	check(str(spec["lines"][0][0]).contains("FINISH"), "the zombie says it finishes the gun: " + str(spec["lines"]))
	var p0: int = run.points
	m.call("tap_street", 0)
	await _settle()
	eq(int(run.stats["finished"]), 1, "finished")
	check(run.points - p0 >= 6 + bal().num("finish_bonus"), "paid the kill + finish bonus (+ challenge)")
	check((m.get("feedback").get("last_played") as Array).has("collect"), "collect animation")
	eq(run.active, DDRun.MELEE, "slot 2 empty: melee becomes active")
	m.queue_free()
	await tree.process_frame
	_cleanup()


func test_long_names_shrink_to_fit() -> void:
	var v: DDCardView = DDCardView.new()
	var tex: Texture2D = ImageTexture.create_from_image(Image.create(8, 6, false, Image.FORMAT_RGB8))
	v.setup({"kind": "Z", "tag": "ZOMBIE", "big": "3", "title": "Shambler", "art": tex, "payload": {"title": "x"}})
	v.custom_minimum_size = Vector2(124, 170)
	tree.root.add_child(v)
	v.size = Vector2(124, 170)
	await _settle()
	var name_label: Label = null
	for l: Variant in v.find_children("*", "Label", true, false):
		if (l as Label).text == "Shambler":
			name_label = l
	check(name_label != null, "name label")
	if name_label != null:
		var font: Font = name_label.get_theme_font("font")
		var w: float = font.get_string_size("Shambler", HORIZONTAL_ALIGNMENT_LEFT, -1, name_label.get_theme_font_size("font_size")).x
		check(w <= name_label.size.x + 0.5 or name_label.get_theme_font_size("font_size") == 10, "Shambler fits its card (%.0f <= %.0f)" % [w, name_label.size.x])
		check(name_label.get_theme_font_size("font_size") < DDUi.FONT_S, "by shrinking the font")
	v.queue_free()
	await tree.process_frame


func test_hints_only_on_the_first_run() -> void:
	var game: Node = tree.root.get_node_or_null("Game")
	tree.root.size = Vector2i(390, 844)
	var m: Control = _main()
	await _settle()
	var prof: DDProfile = game.get("profile")
	prof.record_run_end("rosa", 1, false)
	m.call("_start_run")
	m.call("enter_district")
	await _settle()
	eq(str(m.get("hint_id")), "", "no hints after the first run")
	m.queue_free()
	await tree.process_frame
	_cleanup()


func test_payloads_cover_everything() -> void:
	var r: DDRun = make_run("imani")
	r.points = 999
	for i: int in 3:
		r.open_room(i)
		check(not DDPayloads.room(r, i).is_empty() and str(DDPayloads.room(r, i)["body"]).contains("Pack"), "room %d zoom" % i)
	for w: int in 3:
		check(str(DDPayloads.wave(r, w)["body"]).contains("zombies"), "wave %d zoom lists its numbers" % w)
	check(str(DDPayloads.pile(r)["body"]).contains("Zombies"), "pile zoom: counts by number")
	check(str(DDPayloads.boss(r)["body"]).contains("Groundskeeper") or str(DDPayloads.boss(r)["title"]).contains("Groundskeeper"), "boss zoom")
	r.slots[1] = r.make_gun("rifle")
	r.slot(1).stack = [6, 4] as Array[int]
	var gp: Dictionary = DDPayloads.gun(r, 1)
	check(str(gp["body"]).contains("Next kill: ≤3"), "gun zoom: next kill ≤3 (%s)" % str(gp["body"]))
	check(str(gp["body"]).contains("COUNTDOWN"), "gun zoom: challenge")
	check(str(DDPayloads.stack_card(r, 1, 1)["body"]).contains("LAST kill"), "stack card zoom")
	for p: String in bal().patches():
		check(str(DDPayloads.patch(p, bal())["body"]) != "", "patch zoom " + p)
	for wid: Variant in bal().weapons().keys():
		check(str(DDPayloads.gun_def(str(wid), bal())["body"]).contains("Challenge"), "gun card zoom " + str(wid))
	check(str(DDPayloads.melee(r)["body"]).contains("no points"), "melee zoom (v4: Bare Hands)")
	check(not DDPayloads.how_to_play(bal()).is_empty(), "how to play")
	var z: DDRun = plain_run(["Z7", "C2", "C2", "C2"] + filler(4))
	z.slots[0] = z.make_gun("rifle")
	z.slot(0).stack = [5] as Array[int]
	var zp: Dictionary = DDPayloads.card(z.street[0], z, 0)
	check(str(zp["body"]).contains("NO: needs ≤4"), "zombie zoom: which rules allow it (%s)" % str(zp["body"]))
	check(str(zp["body"]).contains("Melee (hit 1): -6 HP"), "zombie zoom: damage with each weapon")

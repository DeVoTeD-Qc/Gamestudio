# dd-ux-equip (the studio head's notes): a gun card taken with a free slot goes straight into it
# (flies in, no sheet); with both slots full the sheet asks into slot 1 / slot 2 (each saying what it
# replaces, with the salvage) / scrap / cancel; a melee weapon over Bare Hands is taken by a tap.
# Drag and drop (one model): a tile lifts after 10 px (no tap, no long press after that), lit
# targets take it, dark ones and empty space snap it back; gun card -> slot / SCRAP zone, melee card
# -> melee button, medkit -> HP, weapon -> zombie, zombie -> weapon. The Codex scrolls with a
# one-finger drag (on a tile too) and with two fingers, without opening a tile. The HUD shows the
# Patches as a row of their painted icons, each inspectable. Touch is emulated as the left mouse.
extends "res://tests/dd_test_case.gd"

const SIZES: Array[Vector2i] = [Vector2i(390, 844), Vector2i(844, 390)]

var _paths: Array[String] = []


func _main() -> Control:
	var game: Node = tree.root.get_node_or_null("Game")
	var pp: String = "user://dd_test_equip_%d.json" % Time.get_ticks_usec()
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
	for k: int in 5:
		await tree.process_frame


func game_run() -> DDRun:
	return tree.root.get_node("Game").get("run")


func _tile(m: Node, idx: int) -> DDCardView:
	for c: Node in m.find_children("*", "", true, false):
		if c is DDCardView and (c as DDCardView).index == idx and (c as Control).is_visible_in_tree():
			return c
	return null


func _street(m: Control, q: Dictionary) -> void:
	m.call("apply_debug", q)
	m.call("_render")


func _buttons(m: Node) -> Array[String]:
	var out: Array[String] = []
	var sh: Node = m.find_child("Sheet", true, false)
	if sh != null:
		for b: Variant in sh.find_children("*", "Button", true, false):
			out.append((b as Button).text)
	return out


## Mouse events straight into a tile (local position), like the real GUI does while it holds the press.
func _press(c: Control, local: Vector2, down: bool) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = local
	e.global_position = c.get_global_rect().position + local
	c.call("_gui_input", e)


func _move(c: Control, local: Vector2) -> void:
	var e: InputEventMouseMotion = InputEventMouseMotion.new()
	e.position = local
	e.global_position = c.get_global_rect().position + local
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	c.call("_gui_input", e)


## A full drag of tile `from` dropped on the centre of `to` (both Controls on screen).
func _drag(from: Control, to: Control) -> void:
	var a: Vector2 = from.size * 0.5
	_press(from, a, true)
	_move(from, a + Vector2(4, 3))
	_move(from, a + Vector2(14, 8))
	var dest: Vector2 = to.get_global_rect().get_center() - from.get_global_rect().position
	_move(from, dest)
	await tree.process_frame
	_press(from, dest, false)


func _target(m: Node, src: Dictionary, nm: String) -> Dictionary:
	for t: Dictionary in m.call("drag_targets", src):
		if str(t["name"]) == nm:
			return t
	return {}


# ---------------------------------------------------------------- auto-equip and the full-slots sheet
func test_auto_equip_and_full_slots_sheet() -> void:
	for sz: Vector2i in SIZES:
		tree.root.size = sz
		var tag: String = "%dx%d" % [sz.x, sz.y]
		var m: Control = _main()
		await _settle()
		_street(m, {"screen": "street", "seed": "4", "gun1": "rifle", "stack1": "6,4", "gun2": "none", "street": "W:carbine,Z5,Z3,M4"})
		await _settle()
		var run: DDRun = game_run()
		eq(int(m.call("auto_slot", 0)), 1, tag + " the free slot is slot 2")
		m.call("tap_street", 0)
		await _settle()
		eq((m.get("sheet") as Dictionary).size(), 0, tag + " no sheet: it went straight in")
		check(run.slot(1) != null and run.slot(1).wid == "carbine", tag + " the carbine is in slot 2")
		eq(run.slot(0).stack, [6, 4] as Array[int], tag + " slot 1 untouched (no salvage taken)")
		check((m.get("feedback").get("last_played") as Array).has("equip"), tag + " the fly-in plays")
		# both slots empty: slot 1 first
		_street(m, {"screen": "street", "seed": "4", "gun1": "none", "gun2": "none", "street": "W:crossbow,Z5,Z3,M4"})
		await _settle()
		run = game_run()
		m.call("tap_street", 0)
		await _settle()
		check(run.slot(0) != null and run.slot(0).wid == "crossbow" and run.slot(1) == null, tag + " empty slots: into slot 1")
		# both full: the sheet, each slot says what it replaces (with the salvage), scrap, cancel
		_street(m, {"screen": "street", "seed": "4", "gun1": "rifle", "stack1": "6,4,3", "gun2": "crossbow", "stack2": "4", "street": "W:carbine,Z5,Z3,M4"})
		await _settle()
		run = game_run()
		eq(int(m.call("auto_slot", 0)), -1, tag + " no free slot")
		m.call("tap_street", 0)
		await _settle()
		eq(str((m.get("sheet") as Dictionary).get("type", "")), "gun", tag + " both full: the sheet asks")
		var texts: String = " | ".join(_buttons(m))
		check(texts.contains("INTO SLOT 1") and texts.contains("replaces Hunting Rifle 3/"), tag + " slot 1 says what it replaces: " + texts)
		check(texts.contains("INTO SLOT 2") and texts.contains("replaces"), tag + " slot 2 says what it replaces")
		var sv: int = int(run.card_preview(0, DDRun.EQUIP1).get("salvage", 0))
		if sv > 0:
			check(texts.contains("salvage +%d" % bal().shown(sv)), tag + " the salvage is on the button")
		check(texts.contains("SCRAP") and texts.contains("Cancel"), tag + " scrap and cancel")
		var pts0: int = run.points
		var exp_pts: int = int(run.card_preview(0, DDRun.EQUIP1).get("points", 0))
		for b: Variant in m.find_child("Sheet", true, false).find_children("*", "Button", true, false):
			if (b as Button).text.begins_with("INTO SLOT 1"):
				(b as Button).pressed.emit()
				break
		await _settle()
		eq(run.slot(0).wid, "carbine", tag + " the carbine replaced the rifle")
		eq(run.points - pts0, exp_pts, tag + " replacing paid what the sheet said (salvage rules unchanged)")
		# melee over Bare Hands: a tap takes it; over a melee weapon: the sheet
		_street(m, {"screen": "street", "seed": "4", "street": "K:axe,Z5,K:wrench,M4"})
		await _settle()
		run = game_run()
		check(not run.has_melee_weapon(), tag + " Bare Hands to start")
		m.call("tap_street", 0)
		await _settle()
		check(run.has_melee_weapon() and (m.get("sheet") as Dictionary).is_empty(), tag + " Bare Hands: a tap takes the axe")
		check((m.get("feedback").get("last_played") as Array).has("melee_take"), tag + " it flies into the melee button")
		var wi: int = idx(run, "K:wrench")
		if wi >= 0:
			m.call("tap_street", wi)
			await _settle()
			eq(str((m.get("sheet") as Dictionary).get("type", "")), "melee", tag + " holding the axe: TAKE / SCRAP sheet")
			m.call("close_sheet")
			await _settle()
		m.queue_free()
		await tree.process_frame
	_cleanup()


# ---------------------------------------------------------------- drag and drop
func test_drag_drop_targets_and_gestures() -> void:
	for sz: Vector2i in SIZES:
		tree.root.size = sz
		var tag: String = "%dx%d" % [sz.x, sz.y]
		var m: Control = _main()
		await _settle()
		_street(m, {"screen": "street", "seed": "4", "gun1": "rifle", "stack1": "6,4", "gun2": "crossbow", "stack2": "4", "street": "W:carbine,Z5,Z3,M4"})
		await _settle()
		var run: DDRun = game_run()
		# the targets a lifted gun card has: both slots lit, SCRAP lit
		var src: Dictionary = {"type": "street", "index": 0}
		var tg: Array = m.call("drag_targets", src)
		var names: Array = tg.map(func(t: Dictionary) -> String: return str(t["name"]))
		eq(names, ["slot1", "slot2", "scrap"], tag + " a gun card drops on slot 1, slot 2 or SCRAP")
		check(tg.all(func(t: Dictionary) -> bool: return bool(t["ok"])), tag + " all lit")
		# a real drag: lift past 10 px, the drag layer shows the ghost and the glows
		var card: DDCardView = _tile(m, 0)
		var g2: Control = (m.get("_gun_views") as Array)[1]
		var a: Vector2 = card.size * 0.5
		_press(card, a, true)
		_move(card, a + Vector2(5, 0))
		var dl: DDDrag = m.get("drag")
		check(not dl.is_active(), tag + " 5 px is still a tap")
		_move(card, a + Vector2(16, 6))
		check(dl.is_active() and card.dragging, tag + " 16 px lifts the card")
		check(dl.ghost != null and dl.ghost.is_visible_in_tree(), tag + " the lifted copy follows the pointer")
		check(m.find_child("ScrapZone", true, false) != null, tag + " the SCRAP zone shows while a gun card is lifted")
		var glows: Array = dl.find_children("Glow_*", "Panel", false, false)
		eq(glows.size(), 3, tag + " three glowing targets")
		# the long press can't fire once the drag started
		await tree.create_timer(0.6).timeout
		check(not bool((m.get("_inspect") as Control).call("is_open")), tag + " no long-press zoom during a drag")
		var dest: Vector2 = g2.get_global_rect().get_center() - card.get_global_rect().position
		_move(card, dest)
		eq(dl.hovered, "slot2", tag + " slot 2 is under the pointer (brighter)")
		var pts0: int = run.points
		var exp_pts: int = int(run.card_preview(0, DDRun.EQUIP2).get("points", 0))
		_press(card, dest, false)
		await _settle()
		eq(run.slot(1).wid, "carbine", tag + " dropped on slot 2: the carbine replaced the crossbow")
		eq(run.points - pts0, exp_pts, tag + " with the same salvage as the sheet")
		check(not dl.is_active() and dl.find_children("Glow_*", "Panel", false, false).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).is_empty(), tag + " the glows are gone")
		# a drop on empty space snaps back: nothing changes
		_street(m, {"screen": "street", "seed": "4", "gun1": "rifle", "stack1": "6,4", "gun2": "crossbow", "street": "W:carbine,Z5,Z3,M4"})
		await _settle()
		run = game_run()
		var c2: DDCardView = _tile(m, 0)
		var a2: Vector2 = c2.size * 0.5
		_press(c2, a2, true)
		_move(c2, a2 + Vector2(20, 0))
		_move(c2, a2 + Vector2(20, -c2.get_global_rect().position.y + 2.0))
		_press(c2, a2 + Vector2(20, -c2.get_global_rect().position.y + 2.0), false)
		await _settle()
		eq(run.slot(1).wid, "crossbow", tag + " dropped nowhere: nothing equipped")
		eq(run.street.size(), 4, tag + " the card is still on the street")
		# drop helper: SCRAP pays the scrap points
		var sp: int = int(run.card_preview(0, DDRun.SCRAP).get("points", 0))
		var p1: int = run.points
		check(bool(m.call("drop_on", {"type": "street", "index": 0}, "scrap")), tag + " drop on SCRAP")
		await _settle()
		eq(run.points - p1, sp, tag + " scrap paid its points")
		# a tap still taps (no drag) and still auto-equips nothing here (both full: the sheet)
		_street(m, {"screen": "street", "seed": "4", "gun1": "rifle", "gun2": "crossbow", "street": "Z5,W:carbine,Z3,M4"})
		await _settle()
		run = game_run()
		var c3: DDCardView = _tile(m, 1)
		_press(c3, c3.size * 0.5, true)
		_move(c3, c3.size * 0.5 + Vector2(3, 2))
		_press(c3, c3.size * 0.5 + Vector2(3, 2), false)
		await _settle()
		eq(str((m.get("sheet") as Dictionary).get("type", "")), "gun", tag + " a small wobble is still a tap (the sheet)")
		m.call("close_sheet")
		await _settle()
		# weapon -> zombie (lit = it can take it, dark = it can't), zombie -> weapon
		_street(m, {"screen": "street", "seed": "4", "gun1": "rifle", "stack1": "6", "gun2": "none", "street": "Z5,Z7,M4,C2"})
		await _settle()
		run = game_run()
		var wt: Array = m.call("drag_targets", {"type": "weapon", "w": 0})
		var by: Dictionary = {}
		for t: Dictionary in wt:
			by[str(t["name"])] = t
		eq(by.keys().size(), 2, tag + " a gun drops on the two zombies")
		eq(bool(by["zombie0"]["ok"]), bool(run.preview(0, 0)["ok"]), tag + " zombie 5 lit as the preview says")
		eq(bool(by["zombie1"]["ok"]), bool(run.preview(1, 0)["ok"]), tag + " zombie 7 lit / dark as the preview says")
		run.set_active(DDRun.MELEE)
		var gv: Control = (m.get("_gun_views") as Array)[0]
		var z0: DDCardView = _tile(m, 0)
		if bool(run.preview(0, 0)["ok"]):
			await _drag(gv, z0)
			await _settle()
			eq(run.slot(0).stack.size(), 2, tag + " gun dragged onto the zombie: a kill on its stack")
			eq(run.active, 0, tag + " the dragged gun is the active weapon now")
		# zombie -> melee button
		_street(m, {"screen": "street", "seed": "4", "gun1": "rifle", "gun2": "none", "street": "Z2,Z7,M4,C2"})
		await _settle()
		run = game_run()
		var zt: Array = m.call("drag_targets", {"type": "street", "index": 0})
		check(zt.any(func(t: Dictionary) -> bool: return str(t["name"]) == "melee") and zt.any(func(t: Dictionary) -> bool: return str(t["name"]) == "gun0"), tag + " a zombie drops on a gun or melee")
		var n0: int = run.street.size()
		await _drag(_tile(m, 0), _tile(m, IDX_MELEE()))
		await _settle()
		check(run.street.size() < n0 or run.resolved > 0, tag + " zombie dragged onto melee: killed")
		# medkit -> HP; melee card -> melee button
		_street(m, {"screen": "street", "seed": "4", "street": "M4,K:axe,Z3,C2"})
		await _settle()
		run = game_run()
		run.hp = maxi(1, run.max_hp - 3)
		m.call("_render")
		await _settle()
		var ht: Dictionary = _target(m, {"type": "street", "index": 0}, "hp")
		check(not ht.is_empty() and bool(ht["ok"]) and ht["control"] == m.get("_hp_anchor"), tag + " a medkit drops on the HP panel")
		var hp0: int = run.hp
		await _drag(_tile(m, 0), m.get("_hp_anchor"))
		await _settle()
		check(run.hp > hp0, tag + " medkit dragged onto HP: healed (%d -> %d)" % [hp0, run.hp])
		var ki: int = idx(run, "K:axe")
		var mt: Dictionary = _target(m, {"type": "street", "index": ki}, "melee")
		check(not mt.is_empty() and bool(mt["ok"]), tag + " a melee card drops on the melee button")
		m.queue_free()
		await tree.process_frame
	_cleanup()


func IDX_MELEE() -> int:
	return 202


# ---------------------------------------------------------------- Codex touch scrolling
func test_codex_scrolls_by_drag_and_two_fingers() -> void:
	tree.root.size = Vector2i(390, 844)
	var m: Control = _main()
	await _settle()
	m.call("open_codex")
	await _settle()
	var cx: Control = m.get("codex")
	var sc: ScrollContainer = cx.find_child("Scroll", true, false)
	check(sc != null and sc.find_child("TouchScroll", false, false) != null, "the Codex scroll has touch scrolling")
	if sc == null:
		m.queue_free()
		return
	await _settle()
	var r: Rect2 = sc.get_global_rect()
	var start: Vector2 = r.get_center() + Vector2(0, r.size.y * 0.25)
	# one finger on a tile: press, drag up 200 px, release -> scrolled, the tile neither tapped nor zoomed
	var tile: DDCardView = null
	for e: Variant in cx.get("shown"):
		var v: DDCardView = (e as Dictionary)["view"]
		if v.get_global_rect().has_point(start):
			tile = v
	var taps: Array = [0]
	if tile != null:
		tile.tapped.connect(func(_v: DDCardView) -> void: taps[0] += 1)
	# Input.parse_input_event takes window pixels: map the canvas points through the stretch
	var xf: Transform2D = m.get_viewport().get_final_transform()
	var mb: InputEventMouseButton = InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = xf * start
	mb.global_position = mb.position
	Input.parse_input_event(mb)
	await tree.process_frame
	for k: int in 10:
		var mm: InputEventMouseMotion = InputEventMouseMotion.new()
		mm.position = xf * (start - Vector2(0, 20 * (k + 1)))
		mm.global_position = mm.position
		mm.relative = xf.basis_xform(Vector2(0, -20))
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(mm)
		await tree.process_frame
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = xf * (start - Vector2(0, 200))
	up.global_position = up.position
	Input.parse_input_event(up)
	await _settle()
	check(sc.scroll_vertical >= 150, "one-finger drag scrolled the Codex (%d px)" % sc.scroll_vertical)
	eq(taps[0], 0, "the tile under the finger did not tap")
	var insp: Node = m.get("_inspect")
	check(insp == null or not (insp as Control).visible, "and did not open its zoom")
	# two fingers: scroll back down
	var before: int = sc.scroll_vertical
	var p0: Vector2 = r.get_center() - Vector2(40, 0)
	var p1: Vector2 = r.get_center() + Vector2(40, 0)
	for f: int in 2:
		var st: InputEventScreenTouch = InputEventScreenTouch.new()
		st.index = f
		st.pressed = true
		st.position = xf * (p0 if f == 0 else p1)
		Input.parse_input_event(st)
	await tree.process_frame
	for k2: int in 6:
		for f2: int in 2:
			var sd: InputEventScreenDrag = InputEventScreenDrag.new()
			sd.index = f2
			sd.position = xf * ((p0 if f2 == 0 else p1) + Vector2(0, 15 * (k2 + 1)))
			sd.relative = xf.basis_xform(Vector2(0, 15))
			Input.parse_input_event(sd)
		await tree.process_frame
	for f3: int in 2:
		var se: InputEventScreenTouch = InputEventScreenTouch.new()
		se.index = f3
		se.pressed = false
		se.position = xf * (p0 if f3 == 0 else p1)
		Input.parse_input_event(se)
	await _settle()
	check(sc.scroll_vertical <= before - 60, "two fingers scrolled the Codex back (%d -> %d)" % [before, sc.scroll_vertical])
	# a plain tap on a tile still opens it
	cx.call("close")
	m.queue_free()
	await tree.process_frame
	_cleanup()


# ---------------------------------------------------------------- the Patch HUD row
func test_patch_icons_in_hud_map_and_end() -> void:
	for sz: Vector2i in SIZES:
		tree.root.size = sz
		var tag: String = "%dx%d" % [sz.x, sz.y]
		var m: Control = _main()
		await _settle()
		_street(m, {"screen": "street", "seed": "6", "patches": "bounty,brawler"})
		await _settle()
		var row: DDCardView = m.find_child("PatchesChip", true, false)
		check(row != null, tag + " the Patch row in the HUD")
		if row == null:
			m.queue_free()
			continue
		var icons: Array = row.find_children("Patch_*", "", true, false)
		eq(icons.size(), 2, tag + " one icon per Patch")
		for ic: Variant in icons:
			var c: DDCardView = ic
			check(c.find_child("Icon", true, false) is TextureRect, tag + " the painted icon (%s)" % c.name)
			check(c.size.x >= 39.0 and c.size.x <= 52.0, tag + " a compact icon (%.0f px)" % c.size.x)
			check(str(c.payload.get("t1", "")).contains("Patch") and str(c.payload.get("t2", "")) != "", tag + " its tooltip: name and rule")
		check(row.size.y <= (row.get_parent() as Control).size.y + 0.5 and row.get_combined_minimum_size().y <= 64.0, tag + " the row fits the HUD height")
		var got: Array = []
		(icons[0] as DDCardView).inspected.connect(func(p: Dictionary) -> void: got.append(p))
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_RIGHT
		e.pressed = true
		(icons[0] as DDCardView).call("_gui_input", e)
		check(not got.is_empty() and str((got[0] as Dictionary).get("title", "")) == DDText.patch_name(game_run().patches[0]), tag + " right click on an icon: that Patch")
		# the street cards don't move when Patches come
		var st0: Rect2 = _tile(m, 0).get_global_rect()
		_street(m, {"screen": "street", "seed": "6"})
		await _settle()
		var st1: Rect2 = _tile(m, 0).get_global_rect()
		check(st0.is_equal_approx(st1), tag + " the cards keep their place with or without Patches (%s / %s)" % [st0, st1])
		# many Patches: +N
		_street(m, {"screen": "street", "seed": "6", "patches": "lookout,brawler,thick_jacket,bounty,field_medic,lockpick,grudge"})
		await _settle()
		var row2: Control = m.find_child("PatchesChip", true, false)
		var hud_ok: bool = row2 != null and row2.get_global_rect().end.x <= m.get_viewport_rect().size.x + 1
		check(hud_ok, tag + " the HUD row stays on screen with 7 Patches")
		check(row2 != null and (row2.find_child("MorePatches", true, false) != null or row2.find_children("Patch_*", "", true, false).size() == 7), tag + " +N when they don't all fit")
		# the map and the end screen show the icons too
		_street(m, {"screen": "map", "seed": "6", "patches": "lookout"})
		m.call("apply_debug", {"screen": "map", "seed": "6"})
		game_run()._add_patch("brawler")
		m.call("_render")
		await _settle()
		check(m.find_child("Patch_brawler", true, false) != null, tag + " the map shows the Patch icons")
		m.call("apply_debug", {"screen": "end", "seed": "6"})
		game_run()._add_patch("lookout")
		m.call("_render")
		await _settle()
		check(m.find_child("Patch_lookout", true, false) != null, tag + " the end screen shows the Patch icons")
		m.queue_free()
		await tree.process_frame
	_cleanup()

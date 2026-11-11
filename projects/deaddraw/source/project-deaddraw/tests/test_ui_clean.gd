# dd-ux-clean: the cleaned-up street in phone portrait (390x844), phone landscape (844x390) and
# desktop (1440x900): nothing overlaps or leaves the screen, every street button is a 44 CSS px
# tap target (64 logical px at the 560 px base), the street cards are the biggest tiles, the waves
# are ONE stack whose zoom lists every wave, rooms state their price on the OPEN button, gun tiles
# show the short rule (full text in the zoom), the log is one line with the history behind a tap.
# Rotating mid-run reflows without losing state. dd-ux-clean2: desktop sizes (1440x900, 1920x1080)
# get a bigger logical base (phones keep 560) and full-size text; the boss street's two cards are
# drawn bigger than a normal street's cards. Every inspect path works by right click and by
# long press (touch is emulated as the left mouse button).
extends "res://tests/dd_test_case.gd"

const SIZES: Array[Vector2i] = [Vector2i(390, 844), Vector2i(844, 390), Vector2i(1440, 900), Vector2i(1920, 1080)]

var _paths: Array[String] = []


func _main() -> Control:
	var game: Node = tree.root.get_node_or_null("Game")
	var pp: String = "user://dd_test_clean_%d.json" % Time.get_ticks_usec()
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
	for k: int in 4:
		await tree.process_frame


func _all(n: Node, out: Array) -> Array:
	for c: Node in n.get_children():
		if (c is DDCardView or c is Button) and not c.has_meta(&"ghost") and (c as Control).is_visible_in_tree():
			out.append(c)
		_all(c, out)
	return out


func _tile(m: Node, idx: int) -> DDCardView:
	for c: Variant in _all(m, []):
		if c is DDCardView and (c as DDCardView).index == idx:
			return c
	return null


func _street_ok(m: Control, where: String) -> void:
	var vp: Rect2 = m.get_viewport_rect()
	var items: Array = _all(m.get("_content"), [])
	var rects: Array = []
	for c: Variant in items:
		var cc: Control = c
		if cc is DDCardView and (cc as DDCardView).index >= 500:
			continue  # kill-stack cards live inside their gun card
		var r: Rect2 = cc.get_global_rect()
		check(r.position.x >= -1 and r.position.y >= -1 and r.end.x <= vp.size.x + 1 and r.end.y <= vp.size.y + 1,
			"%s: %s inside the screen (%s in %s)" % [where, _name(cc), str(r), str(vp.size)])
		if cc is Button:
			check(r.size.y >= 63.5, "%s: button %s is a 44 CSS px tap target (%s)" % [where, _name(cc), str(r.size)])
		rects.append([cc, r])
	for i: int in rects.size():
		for j: int in range(i + 1, rects.size()):
			var a: Control = rects[i][0]
			var b: Control = rects[j][0]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var ov: Rect2 = (rects[i][1] as Rect2).grow(-1.0).intersection((rects[j][1] as Rect2).grow(-1.0))
			check(ov.size.x <= 0.5 or ov.size.y <= 0.5, "%s: %s and %s don't overlap" % [where, _name(a), _name(b)])


func _name(c: Control) -> String:
	if c is Button:
		return "'%s'" % (c as Button).text.replace("\n", " ")
	if c is DDCardView:
		return "%s/%d(%s)" % [(c as DDCardView).kind, (c as DDCardView).index, str(c.name)]
	return str(c.name)


func _area(c: Control) -> float:
	return c.size.x * c.size.y if c != null else 0.0


func test_street_clean_in_every_orientation() -> void:
	var game: Node = tree.root.get_node_or_null("Game")
	for sz: Vector2i in SIZES:
		tree.root.size = sz
		var tag: String = "%dx%d" % [sz.x, sz.y]
		var m: Control = _main()
		await _settle()
		m.call("apply_debug", {"screen": "street", "seed": "5", "gun2": "crossbow", "stack1": "3,5,6", "stack2": "4,5", "open": "1", "points": "30",
			"patches": "lookout,brawler"})
		m.call("_render")
		await _settle()
		var run: DDRun = game.get("run")
		eq(bool(m.get("portrait")), sz.y > sz.x, tag + " orientation detected")
		_street_ok(m, tag + " street")
		# one focus: the street cards are the biggest tiles on the board
		var card: DDCardView = _tile(m, 0)
		for idx: int in [300, 400, 410, 100, 101, 102, 420]:
			var t: DDCardView = _tile(m, idx)
			check(t != null, "%s tile %d shown" % [tag, idx])
			check(_area(card) > _area(t), "%s: a street card (%s) is bigger than tile %d (%s)" % [tag, str(card.size), idx, str(t.size if t != null else Vector2.ZERO)])
		# waves: one stack with a count and the next threat; the zoom lists every wave
		for w: int in range(1, 3):
			check(_tile(m, 300 + w) == null, tag + " no separate wave deck %d" % (w + 1))
		var wt: DDCardView = _tile(m, 300)
		check(str(wt.payload.get("body", "")).contains("WAVE 1") and str(wt.payload.get("body", "")).contains("WAVE 3"), tag + " wave zoom lists every wave")
		check(wt.big_label != null and wt.big_label.text.begins_with("×"), tag + " wave stack shows a count: " + (wt.big_label.text if wt.big_label != null else ""))
		# rooms: the price on the button, plainly
		var ob: Button = m.find_child("Open1", true, false)
		var price: int = bal().shown(run.room_cost(1))
		check(ob != null and ob.text.contains("%d pts" % price), tag + " OPEN states the price: " + (ob.text.replace("\n", " ") if ob != null else "-"))
		check(ob != null and ob.disabled and ob.text.contains("need %d more" % (price - bal().shown(run.points))), tag + " and how much is missing when you can't pay")
		check(m.find_child("Use0", true, false) != null, tag + " the open room shows USE")
		run.points = run.room_cost(1) + 5
		m.call("_render")
		await _settle()
		ob = m.find_child("Open1", true, false)
		check(not ob.disabled and ob.text.begins_with("OPEN") and ob.text.contains("%d pts" % price), tag + " OPEN · price lit when you can pay")
		# guns: short rule label, no "takes:" line, the full rule in the zoom
		var gv: DDGunView = (m.get("_gun_views") as Array)[1]
		var texts: PackedStringArray = []
		for l: Variant in gv.find_children("*", "Label", true, false):
			texts.append((l as Label).text)
		check(texts.has(DDText.rule_tag("up", run.steady())) or texts.has(DDText.rule_tag("down", run.steady())), tag + " gun shows the short rule label: " + str(texts))
		check(not " ".join(texts).contains("takes:"), tag + " no 'takes' line on the tile")
		check(str(gv.payload.get("body", "")).contains("RULE:") and str(gv.payload.get("body", "")).contains("Can still take"), tag + " full rule in the gun zoom")
		# HUD: one source per stat (no survivor chip, no Patch chip row), Patches behind one chip
		var pts_tiles: int = 0
		for c: Variant in _all(m, []):
			if c is DDCardView and str((c as DDCardView).payload.get("tag", "")) == "POINTS":
				pts_tiles += 1
		eq(pts_tiles, 1, tag + " points shown once")
		var pc: DDCardView = m.find_child("PatchesChip", true, false)
		check(pc != null and str(pc.payload.get("body", "")).contains("Lookout"), tag + " one Patches chip, the list in its zoom")
		# the log: one line on the board, history behind a tap
		var log_tile: DDCardView = m.find_child("Log", true, false)
		check(log_tile != null and str(log_tile.payload.get("tag", "")) == "WHAT HAPPENED", tag + " history behind the prompt bar")
		var ll: Label = m.find_child("LastLine", true, false)
		check(ll != null and ll.autowrap_mode == TextServer.AUTOWRAP_OFF and ll.get_minimum_size().y >= 14.0, tag + " one readable 'what happened' line")
		m.queue_free()
		await tree.process_frame
	_cleanup()


func test_rotate_mid_run() -> void:
	var game: Node = tree.root.get_node_or_null("Game")
	tree.root.size = Vector2i(390, 844)
	var m: Control = _main()
	await _settle()
	m.call("apply_debug", {"screen": "street", "seed": "8"})
	var run: DDRun = game.get("run")
	run.setup_street(["Z3", "Z4", "M3", "C2"] + filler(8, "Z2"))
	run.set_active(DDRun.MELEE)
	m.call("_render")
	await _settle()
	m.call("tap_street", 0)
	await _settle()
	var said: Label = m.find_child("LastLine", true, false)
	check(said != null and said.text != "" and said.text == str((m.get("last_event") as Dictionary).get("text", "")), "after a tap the bar says what happened: " + (said.text if said != null else "-"))
	var before: Array = [run.hp, run.resolved, run.street.size(), run.pile.size(), run.points]
	for sz: Vector2i in [Vector2i(844, 390), Vector2i(1440, 900), Vector2i(390, 844), Vector2i(844, 390)]:
		tree.root.size = sz
		await _settle()
		var tag: String = "rotated to %dx%d" % [sz.x, sz.y]
		eq(m.call("screen_name"), "STREET", tag + ": still on the street")
		eq(bool(m.get("portrait")), sz.y > sz.x, tag + ": layout follows")
		eq([run.hp, run.resolved, run.street.size(), run.pile.size(), run.points], before, tag + ": run state unchanged")
		_street_ok(m, tag)
		check(_tile(m, 200) != null and _tile(m, 202) != null and _tile(m, 0) != null, tag + ": guns, melee and street rebuilt")
	# a sheet survives a rotation too
	run.points = 999
	m.call("do_open_room", 0)
	await _settle()
	m.call("open_machine", 0)
	await _settle()
	tree.root.size = Vector2i(390, 844)
	await _settle()
	check(m.find_child("Sheet", true, false) != null, "the machine sheet is still open after rotating")
	m.queue_free()
	await tree.process_frame
	_cleanup()


func _right_click(c: Control) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	e.position = c.size * 0.5
	c.call("_gui_input", e)


func _long_press(c: Control) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = c.size * 0.5
	c.call("_gui_input", e)
	await tree.create_timer(0.6).timeout
	await tree.process_frame
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = c.size * 0.5
	c.call("_gui_input", up)


func test_every_inspect_path_right_click_and_long_press() -> void:
	var game: Node = tree.root.get_node_or_null("Game")
	for sz: Vector2i in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(1440, 900)]:
		tree.root.size = sz
		var tag: String = "%dx%d" % [sz.x, sz.y]
		var m: Control = _main()
		await _settle()
		m.call("apply_debug", {"screen": "street", "seed": "6", "stack1": "4,2", "open": "1", "points": "20", "patches": "lookout"})
		var run: DDRun = game.get("run")
		run.cover = 2
		m.call("_render")
		await _settle()
		var insp: DDInspect = m.get("_inspect")
		var targets: Dictionary = {"wave stack": _tile(m, 300), "pile": _tile(m, 400), "boss": _tile(m, 410), "room": _tile(m, 100),
			"open room": _tile(m, 101), "gun": _tile(m, 200), "empty gun slot": _tile(m, 201), "melee": _tile(m, 202), "points": _tile(m, 420),
			"street card": _tile(m, 0), "kill-stack card": _tile(m, 500), "HP": m.find_child("HpPanel", true, false),
			"cover": m.get("_cover_view"), "Patches": m.find_child("PatchesChip", true, false), "prompt / history": m.find_child("Log", true, false)}
		var k: int = 0
		for what: String in targets:
			var c: Control = targets[what]
			check(c != null, "%s %s on screen" % [tag, what])
			if c == null:
				continue
			# alternate: right click (desktop) and long press (touch) - both must work everywhere
			_right_click(c)
			await tree.process_frame
			check(insp.is_open(), "%s %s: right click opens its zoom" % [tag, what])
			insp.close()
			await tree.process_frame
			if k % 2 == 0 or what in ["wave stack", "room", "gun", "street card", "prompt / history"]:
				await _long_press(c)
				check(insp.is_open(), "%s %s: long press opens its zoom" % [tag, what])
				insp.close()
				await tree.process_frame
			k += 1
		# a plain tap on a deck / room / the prompt opens the zoom too (they have no other action)
		for idx: int in [300, 400, 100]:
			(_tile(m, idx) as DDCardView).tapped.emit(_tile(m, idx))
			await tree.process_frame
			check(insp.is_open(), "%s tile %d: a tap reads it" % [tag, idx])
			insp.close()
		m.queue_free()
		await tree.process_frame
	_cleanup()


func test_other_screens_fit_both_orientations() -> void:
	for sz: Vector2i in SIZES:
		tree.root.size = sz
		var tag: String = "%dx%d" % [sz.x, sz.y]
		var m: Control = _main()
		await _settle()
		_screen_ok(m, tag + " title")
		var start: Button = null
		for b: Variant in m.find_children("*", "Button", true, false):
			if (b as Button).text.begins_with("Start run"):
				start = b
		check(start != null, tag + " Start run button")
		m.call("_start_run")
		await _settle()
		_screen_ok(m, tag + " map")
		for sh: String in ["gun", "machine0", "machine2", "patch"]:
			m.call("apply_debug", {"screen": "street", "seed": "3", "sheet": sh})
			m.call("_render")
			await _settle()
			var sheet: Control = m.find_child("Sheet", true, false)
			check(sheet != null, "%s %s sheet open" % [tag, sh])
			if sheet != null:
				var vp: Rect2 = m.get_viewport_rect()
				var r: Rect2 = sheet.get_global_rect()
				check(r.position.y >= -1 and r.end.y <= vp.size.y + 1 and r.end.x <= vp.size.x + 1, "%s %s sheet fits the screen (%s)" % [tag, sh, str(r)])
				for b: Variant in sheet.find_children("*", "Button", true, false):
					check((b as Button).size.y >= 63.5, "%s %s sheet: '%s' is a 44 CSS px target" % [tag, sh, (b as Button).text.replace("\n", " ")])
		m.call("apply_debug", {"screen": "safehouse"})
		m.call("_render")
		await _settle()
		_screen_ok(m, tag + " safehouse")
		m.call("apply_debug", {"screen": "end"})
		m.call("_render")
		await _settle()
		_screen_ok(m, tag + " end")
		m.queue_free()
		await tree.process_frame
	_cleanup()


## Title / map / safehouse / end scroll when they must: tiles stay inside the width, nothing
## overlaps, every button is a 44 CSS px target, every tile is inspectable.
func _screen_ok(m: Control, where: String) -> void:
	var vp: Rect2 = m.get_viewport_rect()
	var items: Array = _all(m.get("_content"), [])
	check(items.size() > 0, where + " has content")
	for c: Variant in items:
		var cc: Control = c
		var r: Rect2 = cc.get_global_rect()
		check(r.position.x >= -1 and r.end.x <= vp.size.x + 1, "%s: %s inside the width (%s)" % [where, _name(cc), str(r)])
		if cc is Button:
			check(r.size.y >= 63.5, "%s: %s is a 44 CSS px target (%s)" % [where, _name(cc), str(r.size)])
		if cc is DDCardView:
			check(not (cc as DDCardView).payload.is_empty(), "%s: %s is inspectable" % [where, _name(cc)])
	for i: int in items.size():
		for j: int in range(i + 1, items.size()):
			var a: Control = items[i]
			var b: Control = items[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var ov: Rect2 = a.get_global_rect().grow(-1.0).intersection(b.get_global_rect().grow(-1.0))
			check(ov.size.x <= 0.5 or ov.size.y <= 0.5, "%s: %s and %s don't overlap" % [where, _name(a), _name(b)])


# ---------------------------------------------------------------- dd-ux-clean2
## Labels that shrink to fit (fit_label) and are smaller than their base size.
func _shrunk(n: Node, out: Array) -> Array:
	for l: Variant in n.find_children("*", "Label", true, false):
		var lb: Label = l
		if lb.has_meta(&"fit_base") and lb.is_visible_in_tree() and lb.get_theme_font_size("font_size") < int(lb.get_meta(&"fit_base")):
			out.append(lb.text)
	return out


func test_desktop_gets_a_bigger_base_phones_keep_560() -> void:
	var game: Node = tree.root.get_node_or_null("Game")
	var want: Dictionary = {Vector2i(390, 844): Vector2(560, 1212), Vector2i(844, 390): Vector2(1212, 560),
		Vector2i(1440, 900): Vector2(1216, 760), Vector2i(1920, 1080): Vector2(1564, 880)}
	for sz: Vector2i in want:
		tree.root.size = sz
		var tag: String = "%dx%d" % [sz.x, sz.y]
		var m: Control = _main()
		await _settle()
		# title (and map, safehouse, end) keep the 560 base everywhere; the street grows on desktop
		var vt: Vector2 = m.get_viewport_rect().size
		check(absf(minf(vt.x, vt.y) - 560.0) <= 2.0, "%s: the title keeps the 560 base (%s)" % [tag, str(vt)])
		m.call("apply_debug", {"screen": "street", "seed": "5"})
		m.call("_render")
		await _settle()
		var vp: Vector2 = m.get_viewport_rect().size
		var w: Vector2 = want[sz]
		check(absf(vp.x - w.x) <= 2.0 and absf(vp.y - w.y) <= 2.0, "%s: logical street screen %s (want %s)" % [tag, str(vp), str(w)])
		m.call("apply_debug", {"screen": "safehouse"})
		m.call("_render")
		await _settle()
		var vs: Vector2 = m.get_viewport_rect().size
		check(absf(minf(vs.x, vs.y) - 560.0) <= 2.0, "%s: the safehouse is back on the 560 base (%s)" % [tag, str(vs)])
		if sz.x >= 1440:
			# full-size text: no gun name, rule or boss name shrunk to fit on the street
			for q: Dictionary in [{"screen": "street", "seed": "5", "gun2": "crossbow", "stack1": "3,5,6", "stack2": "4,5", "open": "1"},
					{"screen": "street", "seed": "4", "district": "0"}, {"screen": "street", "seed": "4", "district": "1"},
					{"screen": "street", "seed": "4", "district": "2"}]:
				m.call("apply_debug", q)
				m.call("_render")
				await _settle()
				var run: DDRun = game.get("run")
				var shrunk: Array = []
				for idx: int in [200, 201, 202, 410]:
					var t: DDCardView = _tile(m, idx)
					if t != null:
						_shrunk(t, shrunk)
				check(shrunk.is_empty(), "%s %s: gun and boss text at full size (shrunk: %s)" % [tag, str(run.district().get("id", "")), str(shrunk)])
				for k: int in run.street.size():
					var sh: Array = _shrunk(_tile(m, k), [])
					check(sh.is_empty(), "%s: street card %d name at full size (shrunk: %s)" % [tag, k, str(sh)])
		m.queue_free()
		await tree.process_frame
	_cleanup()


func test_boss_street_cards_are_big() -> void:
	var game: Node = tree.root.get_node_or_null("Game")
	for sz: Vector2i in SIZES:
		tree.root.size = sz
		var tag: String = "%dx%d" % [sz.x, sz.y]
		var m: Control = _main()
		await _settle()
		m.call("apply_debug", {"screen": "street", "seed": "9"})
		m.call("_render")
		await _settle()
		var normal: float = _area(_tile(m, 0))
		for d: int in [0, 2]:
			m.call("apply_debug", {"screen": "street", "seed": "9", "boss": "1", "district": str(d)})
			m.call("_render")
			await _settle()
			var run: DDRun = game.get("run")
			var where: String = "%s boss street %d" % [tag, d]
			check(run.boss_street and run.street.size() == 2, where + ": 2 cards (%d)" % run.street.size())
			_street_ok(m, where)
			var boss_seen: bool = false
			for k: int in run.street.size():
				var t: DDCardView = _tile(m, k)
				check(t != null and _area(t) > normal * 1.2, "%s: card %d (%s) drawn bigger than a normal street card (%.0f vs %.0f)" % [where, k, str(t.size if t != null else Vector2.ZERO), _area(t), normal])
				if t == null:
					continue
				boss_seen = boss_seen or run.street[k].is_boss()
				if sz.y > sz.x:
					check(t.size.x >= (m.get_viewport_rect().size.x - 32.0 - 8.0) / 2.0 - 1.0, where + ": the two cards fill the width in portrait")
				# still inspectable both ways
				var insp: DDInspect = m.get("_inspect")
				_right_click(t)
				await tree.process_frame
				check(insp.is_open(), where + ": right click reads card %d" % k)
				insp.close()
				await tree.process_frame
				await _long_press(t)
				check(insp.is_open(), where + ": long press reads card %d" % k)
				insp.close()
				await tree.process_frame
			check(boss_seen, where + ": the boss card is on the street")
			for b: Variant in [m.find_child("RunPast", true, false), m.find_child("NoEscape", true, false)]:
				if b != null:
					check((b as Control).size.y >= 63.5, where + ": %s is a 44 CSS px target" % (b as Control).name)
		m.queue_free()
		await tree.process_frame
	_cleanup()

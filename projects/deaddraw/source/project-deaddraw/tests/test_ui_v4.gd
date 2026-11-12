# dd-ux-v4: the Door row street (head's M1 a) at 390x844, 844x390, 1440x900 and 1920x1080: the wave
# door and the room doors are one row / column of equal doors, the wave door carries the big wave
# number, the pile sits by the street, the street sits right above the guns (no middle band), Run
# and melee are small buttons in the gun row; every gun and melee shows the hit burst; every gun
# shows one kill socket per kill it holds (the next one says what it takes); every zombie shows
# the strength mark; the padlock plate's four states; tooltips are 2 lines (M3 b); the Glossary
# (the ?) and the Codex (title, Menu) with its type / district / met filters and met-tracking in
# the profile (M4 a: silhouettes until met); the WAVE banner lasts 1.8 s and a tap skips it (M5 a);
# right click and long press work on tiles and on the small buttons. Touch is emulated as the
# left mouse button.
extends "res://tests/dd_test_case.gd"

const SIZES: Array[Vector2i] = [Vector2i(390, 844), Vector2i(844, 390), Vector2i(1440, 900), Vector2i(1920, 1080)]
const Marks: GDScript = preload("res://scripts/ui/dd_marks.gd")

var _paths: Array[String] = []


func _main() -> Control:
	var game: Node = tree.root.get_node_or_null("Game")
	var pp: String = "user://dd_test_v4_%d.json" % Time.get_ticks_usec()
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


func _tile(m: Node, idx: int) -> DDCardView:
	for c: Node in m.find_children("*", "", true, false):
		if c is DDCardView and (c as DDCardView).index == idx and (c as Control).is_visible_in_tree():
			return c
	return null


func _street(m: Control, q: Dictionary) -> void:
	m.call("apply_debug", q)
	m.call("_render")


func _inside(m: Control, c: Control) -> bool:
	var vp: Rect2 = m.get_viewport_rect()
	var r: Rect2 = c.get_global_rect()
	return r.position.x >= -1 and r.position.y >= -1 and r.end.x <= vp.size.x + 1 and r.end.y <= vp.size.y + 1


func _right_click(c: Control) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	e.position = c.size * 0.5
	if c is Button:
		c.gui_input.emit(e)
	else:
		c.call("_gui_input", e)


func _long_press(c: Control) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = c.size * 0.5
	if c is Button:
		c.gui_input.emit(e)
	else:
		c.call("_gui_input", e)
	await tree.create_timer(0.6).timeout
	await tree.process_frame
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = c.size * 0.5
	if c is Button:
		c.gui_input.emit(up)
	else:
		c.call("_gui_input", up)


# ---------------------------------------------------------------- the door row street
func test_door_row_layout_every_size() -> void:
	for sz: Vector2i in SIZES:
		tree.root.size = sz
		var tag: String = "%dx%d" % [sz.x, sz.y]
		var m: Control = _main()
		await _settle()
		_street(m, {"screen": "street", "seed": "5", "gun1": "rifle", "stack1": "8,6", "gun2": "crossbow", "stack2": "4", "points": "24"})
		await _settle()
		var portrait: bool = sz.y > sz.x
		var wave: DDCardView = _tile(m, 300)
		var rooms: Array = [_tile(m, 100), _tile(m, 101), _tile(m, 102)]
		check(wave != null and not rooms.has(null), tag + " the wave door and three room doors")
		if wave == null or rooms.has(null):
			m.queue_free()
			continue
		# one row (portrait) or one column (landscape) of four equal doors
		for r: Variant in rooms:
			var rr: Rect2 = (r as Control).get_global_rect()
			check(absf(rr.size.x - wave.size.x) < 2.0 and absf(rr.size.y - wave.size.y) < 2.0, "%s: door %s is the size of the wave door" % [tag, str(r.name)])
			if portrait:
				check(absf(rr.position.y - wave.global_position.y) < 2.0, tag + " doors share one row")
			else:
				check(absf(rr.position.x - wave.global_position.x) < 2.0, tag + " doors share one column")
		var num: Control = wave.get_meta(&"numeral")
		check(num != null and num.size.y >= 40.0, "%s: the big wave number (%s px tall)" % [tag, str(num.size if num != null else Vector2.ZERO)])
		# the pile is by the street; the street sits right above the guns: no middle band
		var st: Rect2 = Rect2()
		for k: int in (game_run()).street.size():
			st = st.merge(_tile(m, k).get_global_rect()) if st.size != Vector2.ZERO else _tile(m, k).get_global_rect()
		var pile: DDCardView = _tile(m, 400)
		check(pile.global_position.y >= st.end.y - 1.0, tag + " the pile sits under the street")
		check(m.find_child("Prompt", true, false) == null, tag + " no middle prompt band")
		var g1: DDGunView = _tile(m, 200)
		if portrait:
			var gap: float = g1.global_position.y - st.end.y
			check(gap <= float(m.get("STRIP_H")) + 8.0 * 2 + 30.0, "%s: the street sits right above the guns (gap %.0f)" % [tag, gap])
		# Run and melee: small buttons beside the guns
		var melee: DDCardView = _tile(m, 202)
		var run_b: Button = m.find_child("Run", true, false)
		check(melee != null and run_b != null, tag + " melee and Run in the gun row")
		if melee != null and run_b != null:
			check(_area(melee) < _area(g1) * 0.6 and run_b.size.x * run_b.size.y < _area(g1) * 0.6, tag + " melee and Run are smaller than a gun")
			check(run_b.size.y >= 63.5 and melee.size.y >= 63.5, tag + " both are 44 CSS px targets")
			if portrait:
				check(melee.global_position.y >= g1.global_position.y - 1.0 and run_b.global_position.y >= g1.global_position.y - 1.0, tag + " aligned with the guns")
			else:
				check(melee.global_position.x >= g1.global_position.x - 1.0, tag + " in the gun column")
		# the hit burst on every gun and on melee
		for idx: int in [200, 201, 202]:
			var t: DDCardView = _tile(m, idx)
			check(t != null and t.hit_burst != null and int(t.hit_burst.get("value")) > 0, "%s: tile %d shows the hit burst" % [tag, idx])
		# kill sockets: one per kill the gun holds; filled ones carry the zombie's number; the next says what it takes
		var run: DDRun = game_run()
		for s: int in 2:
			var gv: DDGunView = _tile(m, 200 + s)
			eq(gv.stack_area.get_child_count(), run.slot(s).cap, "%s gun %d: one socket per kill it holds" % [tag, s + 1])
			eq(gv.stack_cards.size(), run.slot(s).stack.size(), "%s gun %d: filled sockets" % [tag, s + 1])
			var nx: Control = gv.find_child("NextSocket", true, false)
			check(nx != null and str(nx.get("next_text")) == DDPayloads.accept_tag(run.can_take(run.slot(s))), "%s gun %d: the next socket says %s" % [tag, s + 1, str(nx.get("next_text")) if nx != null else "-"])
			for mc: DDCardView in gv.stack_cards:
				check(mc.size.x >= 26.0 and mc.size.y >= 44.0 and _inside(m, mc), "%s gun %d: socket %s big and on screen" % [tag, s + 1, str(mc.size)])
		eq(str((_tile(m, 200) as DDGunView).find_child("NextSocket", true, false).get("next_text")), "≤6", tag + " Rifle on a 6 (Rosa: last or lower) takes ≤6")
		# the strength mark on every zombie
		for k2: int in run.street.size():
			if run.street[k2].kind == DDCard.ZOMBIE:
				var zt: DDCardView = _tile(m, k2)
				check(zt.strength_mark != null and int(zt.strength_mark.get("value")) == run.street[k2].value, "%s: zombie %d shows its strength mark" % [tag, k2])
		check(m.find_child("HelpButton", true, false) != null, tag + " the ? in the HUD")
		m.queue_free()
		await tree.process_frame
	_cleanup()


func game_run() -> DDRun:
	return tree.root.get_node("Game").get("run")


func _area(c: Control) -> float:
	return c.size.x * c.size.y if c != null else 0.0


# ---------------------------------------------------------------- the padlock plate
func test_room_plate_four_states() -> void:
	tree.root.size = Vector2i(390, 844)
	var m: Control = _main()
	await _settle()
	_street(m, {"screen": "street", "seed": "5", "points": "10", "open": "1"})
	await _settle()
	var run: DDRun = game_run()
	# locked: dark plate, padlock, price, progress bar; the door under it takes the taps
	var lk: Button = m.find_child("Open1", true, false)
	check(lk != null and lk.disabled and lk.mouse_filter == Control.MOUSE_FILTER_IGNORE, "locked: the plate is off, the door reads it")
	check(lk.find_child("Padlock", true, false) != null and not bool(lk.find_child("Padlock", true, false).get("open")), "locked: a closed padlock")
	var pg: ProgressBar = lk.find_child("Progress", true, false)
	check(pg != null and pg.value == bal().shown(run.points) and pg.max_value == bal().shown(run.room_cost(1)), "locked: the bar shows how close you are")
	# affordable: gold, open padlock, OPEN; tap opens the room
	run.points = run.room_cost(1)
	m.call("_render")
	await _settle()
	var rd: Button = m.find_child("Open1", true, false)
	check(not rd.disabled and rd.text.contains("OPEN") and bool(rd.find_child("Padlock", true, false).get("open")), "affordable: the gold plate with an open padlock")
	check(rd.has_meta(&"ready"), "affordable: marked for the slow glow")
	# the room that just became affordable rang twice
	await tree.create_timer(0.2).timeout
	check((m.get("feedback").get("last_played") as Array).has("room_ready") or Game_reduce(), "affordable: the two-ring pulse")
	rd.pressed.emit()
	await _settle()
	# v5: just enough for the door, not for its machine: a short sheet asks first
	eq(str(m.get("sheet").get("type", "")), "room_confirm", "door only: the plate asks before opening")
	var rc: Label = m.find_child("RoomConfirmText", true, false)
	check(rc != null and rc.text.contains("not enough to use it this wave"), "the sheet says the machine is out of reach this wave")
	(m.find_child("RoomConfirmOpen", true, false) as Button).pressed.emit()
	await _settle()
	check(run.room_open[1], "tap the gold plate: the room opens")
	# open: USE; used: grey "used"
	var use: Button = m.find_child("Use1", true, false)
	check(use != null and not use.disabled and use.text == "USE", "open: USE")
	run.machine_used[1] = true
	m.call("_render")
	await _settle()
	var used: Button = m.find_child("Use1", true, false)
	check(used != null and used.disabled and used.text == "used", "used: back next wave")
	check(str(_tile(m, 101).payload.get("t2", "")).contains("next wave"), "used: the tooltip says when it is back")
	m.queue_free()
	await tree.process_frame
	_cleanup()


func Game_reduce() -> bool:
	return bool(tree.root.get_node("Game").call("reduce_motion"))


# ---------------------------------------------------------------- 2-line tooltips
func test_tooltips_are_two_short_lines() -> void:
	tree.root.size = Vector2i(390, 844)
	var m: Control = _main()
	await _settle()
	_street(m, {"screen": "street", "seed": "6", "stack1": "4,2", "open": "1", "points": "20", "patches": "lookout,brawler"})
	var run: DDRun = game_run()
	run.cover = 2
	m.call("_render")
	await _settle()
	var payloads: Array = [DDPayloads.waves(run), DDPayloads.boss(run), DDPayloads.pile(run), DDPayloads.room(run, 0), DDPayloads.room(run, 1),
		DDPayloads.gun(run, 0), DDPayloads.gun(run, 1), DDPayloads.melee(run), DDPayloads.stack_card(run, 0, 1), DDPayloads.hp(run),
		DDPayloads.points(run), DDPayloads.cover(run), DDPayloads.patches(run), DDPayloads.patch("loose_grip", bal()),
		DDPayloads.survivor("rosa", bal(), null), DDPayloads.gun_def("shotgun", bal())]
	for k: int in run.street.size():
		payloads.append(DDPayloads.card(run.street[k], run, k))
	for p: Variant in payloads:
		var d: Dictionary = p
		var t1: String = str(d.get("t1", ""))
		var t2: String = str(d.get("t2", ""))
		check(t1 != "" and t2 != "", "tooltip has 2 lines: %s / %s" % [t1, t2])
		check(not t1.contains("\n") and not t2.contains("\n"), "each is one line: " + t1)
		check(t1.length() <= 70 and t2.length() <= 80, "short: '%s' (%d) / '%s' (%d)" % [t1, t1.length(), t2, t2.length()])
	# the overlay shows those two lines only (no rules paragraph)
	var insp: DDInspect = m.get("_inspect")
	insp.open(DDPayloads.gun(run, 0))
	await _settle()
	# (dd-polish5: the number inside the hit badge is the badge's own label, not a text line)
	# (dd-ui6: the icon key under the lines - rule, Full set, challenge - is glyph + word, not a text line)
	# (dd-capacity: the capacity mark row - mark + "Holds 4 kills before it pays out" - is a key row too)
	var labels: Array = insp.find_children("*", "Label", true, false).filter(func(l: Node) -> bool: return l.name != "Num" and not str(l.get_path()).contains("IconRow") and not str(l.get_path()).contains("StatRow"))
	eq(labels.size(), 2, "the tooltip is two labels")
	check(insp.find_child("IconRow", true, false) != null, "the gun tooltip shows its icon key (rule, Full set, challenge)")
	eq(insp.last_lines[0], str(DDPayloads.gun(run, 0)["t1"]), "line 1 is t1")
	insp.close()
	# the full rules live in the Glossary: every gun rule has a line there
	var rules_text: String = JSON.stringify(m.get("codex").call("sections", bal()))
	for wid: Variant in bal().weapons().keys():
		if bal().is_gun(str(wid)):
			check(rules_text.contains("(%s)" % bal().weapon_name(str(wid))), "the Glossary explains the %s's rule" % bal().weapon_name(str(wid)))
	m.queue_free()
	await tree.process_frame
	_cleanup()


# ---------------------------------------------------------------- inspect on the small buttons
func test_buttons_inspect_by_right_click_and_long_press() -> void:
	for sz: Vector2i in [Vector2i(390, 844), Vector2i(1440, 900)]:
		tree.root.size = sz
		var m: Control = _main()
		await _settle()
		_street(m, {"screen": "street", "seed": "5", "patches": "lookout"})
		await _settle()
		var insp: DDInspect = m.get("_inspect")
		for nm: String in ["Run", "HelpButton", "BuryButton"]:
			var b: Button = m.find_child(nm, true, false)
			check(b != null, "%s on screen" % nm)
			if b == null:
				continue
			_right_click(b)
			await tree.process_frame
			check(insp.is_open(), "%s: right click opens its tooltip" % nm)
			insp.close()
			await tree.process_frame
			var run: DDRun = game_run()
			var hp0: int = run.hp
			await _long_press(b)
			await tree.process_frame
			check(insp.is_open(), "%s: long press opens its tooltip" % nm)
			insp.close()
			eq(run.hp, hp0, "%s: a long press doesn't press it" % nm)
			check(not (m.get("codex") as Control).call("is_open"), "%s: a long press doesn't open the Glossary" % nm)
		m.queue_free()
		await tree.process_frame
	_cleanup()


# ---------------------------------------------------------------- Glossary and Codex
func test_glossary_from_the_help_button() -> void:
	for sz: Vector2i in SIZES:
		tree.root.size = sz
		var tag: String = "%dx%d" % [sz.x, sz.y]
		var m: Control = _main()
		await _settle()
		_street(m, {"screen": "street", "seed": "5"})
		await _settle()
		(m.find_child("HelpButton", true, false) as Button).pressed.emit()
		await _settle()
		var cx: Control = m.get("codex")
		check(cx.call("is_open") and str(cx.get("mode")) == "glossary", tag + " ? opens the Glossary")
		var rows: Array = []
		for c: Node in cx.find_children("Gl_*", "", true, false):
			rows.append(c)
		check(rows.size() >= 30, "%s: the Glossary lists every icon (%d rows)" % [tag, rows.size()])
		for r: Variant in rows:
			var p: Dictionary = (r as DDCardView).payload
			check(str(p.get("t1", "")) != "" and str(p.get("t2", "")) != "", tag + " glossary row has its line: " + str(p.get("t1", "")))
		var insp: DDInspect = m.get("_inspect")
		_right_click(rows[0])
		await tree.process_frame
		check(insp.is_open(), tag + " a glossary row opens its tooltip (right click)")
		insp.close()
		await _long_press(rows[1])
		check(insp.is_open(), tag + " a glossary row opens its tooltip (long press)")
		insp.close()
		var close: Button = cx.find_child("CloseOverlay", true, false)
		check(close != null and close.size.y >= 63.5 and _inside(m, close), tag + " Close is a 44 CSS px target on screen")
		close.pressed.emit()
		await _settle()
		check(not cx.call("is_open"), tag + " Close closes it")
		m.queue_free()
		await tree.process_frame
	_cleanup()


func test_codex_filters_and_met_tracking() -> void:
	for sz: Vector2i in SIZES:
		tree.root.size = sz
		var tag: String = "%dx%d" % [sz.x, sz.y]
		var m: Control = _main()
		await _settle()
		# from the title
		var cb: Button = m.find_child("CodexButton", true, false)
		check(cb != null and cb.size.y >= 63.5, tag + " a Codex button on the title")
		cb.pressed.emit()
		await _settle()
		var cx: Control = m.get("codex")
		check(cx.call("is_open") and str(cx.get("mode")) == "codex", tag + " the title opens the Codex")
		var all: Array = cx.get("shown")
		var total: int = (cx.call("entries", bal()) as Array).size()
		eq(all.size(), total, tag + " every entry listed")
		var types: Dictionary = {}
		for e: Variant in all:
			types[str((e as Dictionary)["type"])] = true
		for t: String in ["guns", "melee", "zombies", "bosses", "items", "patches"]:
			check(types.has(t), tag + " the Codex has " + t)
		# nothing met yet: dark silhouettes named ???
		for e2: Variant in all:
			var v: DDCardView = (e2 as Dictionary)["view"]
			check(not bool((e2 as Dictionary)["met"]) and str(v.payload.get("t1", "")).begins_with("???"), tag + " unmet entries are ???")
			if v.art_rect != null:
				check(v.art_rect.self_modulate.v < 0.2, tag + " unmet art is a dark silhouette")
		# filters: type, district, met only
		cx.call("set_filters", "guns", "any", false)
		await _settle()
		for e3: Variant in cx.get("shown"):
			eq(str((e3 as Dictionary)["type"]), "guns", tag + " Guns filter")
		cx.call("set_filters", "bosses", "downtown", false)
		await _settle()
		eq((cx.get("shown") as Array).size(), 1, tag + " Bosses + Downtown: the Rush Hour Horde only")
		# chips are 44 CSS px targets and work by tap
		var chip: Button = cx.find_child("Type_zombies", true, false)
		check(chip != null and chip.size.y >= 63.5 and _inside(m, chip), tag + " filter chips are 44 CSS px targets on screen")
		chip.pressed.emit()
		await _settle()
		await _settle()
		for e4: Variant in cx.get("shown"):
			eq(str((e4 as Dictionary)["type"]), "zombies", tag + " tapping the Zombies chip filters")
		cx.call("close")
		# meet things on the street: they are saved in the profile
		_street(m, {"screen": "street", "seed": "5", "gun2": "crossbow"})
		await _settle()
		var prof: DDProfile = tree.root.get_node("Game").get("profile")
		check(prof.codex_met("gun:crossbow") and prof.codex_met("melee:bare_hands"), tag + " equipped guns and melee are met")
		var again: DDProfile = DDProfile.new(bal(), prof.path)
		again.load_profile()
		check(again.codex_met("gun:crossbow"), tag + " met entries are saved in the profile")
		# from the Menu; met-only shows exactly the met entries, unmasked
		m.call("open_settings")
		await _settle()
		(m.find_child("MenuCodex", true, false) as Button).pressed.emit()
		await _settle()
		check(cx.call("is_open") and not (m.get("settings_panel") as Control).call("is_open"), tag + " the Menu opens the Codex")
		cx.call("set_filters", "all", "any", true)
		await _settle()
		var met_shown: Array = cx.get("shown")
		check(not met_shown.is_empty(), tag + " met only: something is met")
		for e5: Variant in met_shown:
			var v5: DDCardView = (e5 as Dictionary)["view"]
			check(bool((e5 as Dictionary)["met"]) and not str(v5.payload.get("t1", "")).begins_with("???"), tag + " met only: met entries, named")
			check(_inside(m, v5) or v5.global_position.y > 0, tag + " tile within the width")
		cx.call("set_filters", "all", "any", false)
		# dd-art-fit: Show all reveals every entry without marking it met; the filters still work
		var met_before: int = 0
		for ek: Variant in cx.call("entries", bal()):
			if prof.codex_met(str((ek as Dictionary)["key"])):
				met_before += 1
		var sa: Button = cx.find_child("ShowAll", true, false)
		check(sa != null and sa.text == "Show all" and sa.size.y >= 63.5 and _inside(m, sa), tag + " a Show all chip on screen")
		sa.pressed.emit()
		await _settle()
		await _settle()
		check(bool(cx.get("show_all")), tag + " Show all is on")
		var rev: Array = cx.get("shown")
		eq(rev.size(), total, tag + " Show all: every entry")
		for e6: Variant in rev:
			var v6: DDCardView = (e6 as Dictionary)["view"]
			check(bool((e6 as Dictionary)["revealed"]) and not str(v6.payload.get("t1", "")).begins_with("???"), tag + " Show all: named")
			if v6.art_rect != null:
				check(v6.art_rect.self_modulate.v > 0.5, tag + " Show all: art in full")
		var after_n: int = 0
		for ek2: Variant in cx.call("entries", bal()):
			if prof.codex_met(str((ek2 as Dictionary)["key"])):
				after_n += 1
		eq(after_n, met_before, tag + " Show all marks nothing met")
		cx.call("set_filters", "guns", "any", false)
		await _settle()
		for e7: Variant in cx.get("shown"):
			check(str((e7 as Dictionary)["type"]) == "guns" and bool((e7 as Dictionary)["revealed"]), tag + " Show all + Guns filter")
		var ha: Button = cx.find_child("ShowAll", true, false)
		check(ha != null and ha.text == "Hide unmet", tag + " the chip now says Hide unmet")
		cx.call("close")
		cx.call("open_codex", bal(), prof)
		await _settle()
		check(bool(cx.get("show_all")), tag + " Show all is remembered for the session")
		cx.call("set_show_all", false)
		cx.call("set_filters", "all", "any", false)
		await _settle()
		for e8: Variant in cx.get("shown"):
			if not bool((e8 as Dictionary)["met"]):
				check(str(((e8 as Dictionary)["view"] as DDCardView).payload.get("t1", "")).begins_with("???"), tag + " Hide unmet: ??? again")
		cx.call("close")
		m.queue_free()
		await tree.process_frame
	_cleanup()


# ---------------------------------------------------------------- the WAVE banner
func test_wave_banner_lasts_and_tap_skips() -> void:
	for sz: Vector2i in [Vector2i(390, 844), Vector2i(844, 390)]:
		tree.root.size = sz
		var m: Control = _main()
		await _settle()
		_street(m, {"screen": "street", "seed": "5", "lastcards": "1"})
		await _settle()
		for k: int in 3:
			m.call("tap_street", 0)
			await _settle()
		await tree.create_timer(0.1).timeout
		check(bool(m.call("banner_open")) and str(m.get("last_banner")) == "WAVE 2", "a new wave shows the WAVE 2 banner (%s)" % str(m.get("last_banner")))
		var num: Control = (_tile(m, 300) as DDCardView).get_meta(&"numeral")
		# a tap anywhere skips it
		var layer: Control = m.find_child("BannerLayer", true, false)
		check(layer != null and layer.size.x >= m.get_viewport_rect().size.x - 1.0, "the banner catches a tap anywhere")
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		layer.gui_input.emit(e)
		await _settle()
		check(not bool(m.call("banner_open")), "a tap skips the banner")
		check(num != null and str(num.get("text")) == "2" and is_equal_approx(num.scale.x, 1.0), "the wave door shows 2 after the skip")
		# untouched, it lasts 1.8 s
		m.call("_wave_banner", 3, "test")
		await tree.create_timer(1.5).timeout
		check(bool(m.call("banner_open")), "still up at 1.5 s")
		await tree.create_timer(1.0).timeout
		check(not bool(m.call("banner_open")), "gone by 2.5 s (1.8 s on screen after a 0.4 s lead-in)")
		m.queue_free()
		await tree.process_frame
	_cleanup()


func test_wave_banner_reduce_motion() -> void:
	var game: Node = tree.root.get_node_or_null("Game")
	tree.root.size = Vector2i(390, 844)
	var m: Control = _main()
	await _settle()
	(game.get("profile") as DDProfile).set_setting("reduce_motion", true)
	_street(m, {"screen": "street", "seed": "5"})
	await _settle()
	m.call("_wave_banner", 2, "test")
	await tree.create_timer(0.2).timeout
	var ban: Control = m.find_child("Banner", true, false)
	check(ban != null and is_equal_approx(ban.position.x, 0.0), "reduce motion: the banner fades in place (no sweep)")
	var num: Control = (_tile(m, 300) as DDCardView).get_meta(&"numeral")
	check(is_equal_approx(num.scale.x, 1.0), "reduce motion: no slam")
	m.call("dismiss_banner")
	(game.get("profile") as DDProfile).set_setting("reduce_motion", false)
	m.queue_free()
	await tree.process_frame
	_cleanup()


# ---------------------------------------------------------------- the strength mark
func test_strength_mark_tiers() -> void:
	for v: int in range(1, 13):
		var t: int = Marks.tier_of(v)
		eq(t, 0 if v <= 3 else (1 if v <= 6 else (2 if v <= 9 else 3)), "tier of %d" % v)
	# dd-polish5: one circle badge for every number; the role only changes its colours
	eq(str(Marks.STRENGTH_VARIANT), "circle", "the circle badge is the one in use")
	var m: Control = Marks.StrengthMark.new(8)
	eq(str(m.get("variant")), "circle", "zombie badges are circles")
	eq(m.get("ring"), Marks.TIER_COLORS[2], "a Bruiser's ring is its tier colour")
	eq(m.get("fill"), Marks.ZOMBIE_FILL, "zombie badges have the blood fill")
	var hb: Control = Marks.HitBurst.new(3)
	eq(str(hb.get("variant")), "circle", "hit badges are circles")
	eq(hb.get("fill"), Marks.WEAPON_FILL, "hit badges have the yellow fill")
	eq(str((hb.get("num_label") as Label).text), "3", "the badge shows its number")
	var ib: Control = Marks.NumBadge.new(4, "item", DDUi.accent("M"))
	eq(ib.get("ring"), DDUi.accent("M"), "an item badge's ring is the kind's accent")
	eq(ib.get("fill"), Marks.INK, "item badges have the ink fill")
	m.free()
	hb.free()
	ib.free()
	eq(DDPayloads.accept_tag([1, 2, 3, 4, 5] as Array[int]), "≤5", "accept: 5 or lower")
	eq(DDPayloads.accept_tag([5, 6, 7, 8, 9, 10, 11, 12] as Array[int]), "≥5", "accept: 5 or higher")
	eq(DDPayloads.accept_words([1, 2, 3, 4, 5] as Array[int]), "≤5", "dd-ux-text: the words use the same notation")
	eq(DDText.rule_block(null, 7, null), "empty slot", "rule_block on an empty slot")
	eq(DDPayloads.accept_tag([5] as Array[int]), "=5", "accept: exactly 5")
	eq(DDPayloads.accept_tag([1, 3, 5, 7, 9, 11] as Array[int]), "odd", "accept: odd")
	var every: Array[int] = []
	for z: int in range(1, 13):
		every.append(z)
	eq(DDPayloads.accept_tag(every), "any", "accept: any")


# ---------------------------------------------------------------- v4 rules in the Door row
func test_v4_melee_launcher_salvage_and_run_flight() -> void:
	for sz: Vector2i in [Vector2i(390, 844), Vector2i(1440, 900)]:
		tree.root.size = sz
		var tag: String = "%dx%d" % [sz.x, sz.y]
		var m: Control = _main()
		await _settle()
		_street(m, {"screen": "street", "seed": "5", "gun1": "rifle", "stack1": "8,6,5", "gun2": "launcher"})
		await _settle()
		var run: DDRun = game_run()
		# Bare Hands in the melee button
		var mv: DDCardView = _tile(m, 202)
		eq(str((mv.find_child("MeleeName", true, false) as Label).text), "Bare Hands", tag + " melee starts as Bare Hands")
		eq(int(mv.hit_burst.get("value")), bal().num("hands_power"), tag + " the burst shows the hands' hit")
		check(mv.find_child("UsesMark", true, false) == null, tag + " bare hands have no uses mark")
		# the launcher: one socket
		var lv: DDGunView = _tile(m, 201)
		eq(lv.stack_area.get_child_count(), 1, tag + " the launcher has one kill socket")
		# a melee weapon card on the street: TAKE / SCRAP sheet, then use pips on the melee button
		run.setup_street(["K:axe", "Z5", "Z3", "M4"] + _filler(10))
		m.call("_render")
		await _settle()
		var kc: DDCardView = _tile(m, 0)
		check(kc != null and kc.hit_burst != null and kc.kind == "K", tag + " the melee card shows its hit burst")
		check(str(kc.payload.get("t1", "")).contains("Fire Axe"), tag + " the melee card's tooltip: " + str(kc.payload.get("t1", "")))
		# dd-ux-equip: with Bare Hands a tap takes it (no sheet)
		m.call("tap_street", 0)
		await _settle()
		check(m.find_child("Melee_" + DDRun.TAKE, true, false) == null, tag + " no TAKE / SCRAP sheet over Bare Hands")
		# dd-polish5: the taken card flies into the melee button; no ghost stays on the street
		check((m.get("feedback").get("last_played") as Array).has("melee_take"), tag + " TAKE plays the melee fly-in")
		await tree.create_timer(1.2).timeout
		var ghosts: Array = m.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.has_meta(&"ghost") and is_instance_valid(n) and not n.is_queued_for_deletion())
		eq(ghosts.size(), 0, tag + " no melee card ghost is left on the street")
		mv = _tile(m, 202)
		var mbox: Control = mv.find_child("MeleeBox", true, false)
		var inner: Rect2 = mv.get_global_rect().grow(1.0)
		for part: String in ["HitBurst", "MeleeName", "MeleeTag", "UsesMark"]:
			var pc: Control = mv.find_child(part, true, false)
			check(pc != null and inner.encloses(pc.get_global_rect()), "%s melee %s inside the button: %s in %s" % [tag, part, pc.get_global_rect() if pc != null else Rect2(), inner])
		check(mbox != null, tag + " the melee button has its two-row box")
		eq(str((mv.find_child("MeleeName", true, false) as Label).text), "Fire Axe", tag + " melee is the Fire Axe now")
		# dd-capacity: the uses mark (icon + number) shows the uses left
		var um: Node = mv.find_child("UsesMark", true, false)
		check(um != null and int(um.get("value")) == run.melee_uses() and str(um.get("role")) == "uses", tag + " uses mark = uses left (%d)" % run.melee_uses())
		# the equip sheet names the salvage
		run.setup_street(["W:carbine", "Z5", "Z3", "M4"] + _filler(10))
		m.call("_render")
		await _settle()
		m.call("tap_street", 0)
		await _settle()
		var texts: Array = []
		for b: Variant in m.find_child("Sheet", true, false).find_children("*", "Button", true, false):
			texts.append((b as Button).text)
		check(" ".join(texts).contains("replaces Hunting Rifle 3/4") and not " ".join(texts).contains("loses"), tag + " equip says what it replaces: " + str(texts))
		m.call("close_sheet")
		await _settle()
		# Run: allowed with no zombie; the cards fly face up to the bottom with a count
		run.setup_street(["M4", "C2", "M3", "C3"] + _filler(10))
		run.ran_last = false
		m.call("_render")
		await _settle()
		var rb: Button = m.find_child("Run", true, false)
		check(rb != null and not rb.disabled, tag + " Run with no zombie on the street")
		check(str(rb.get_meta(&"tip").get("t2", "")).contains("bottom"), tag + " Run's tooltip: cards go to the bottom")
		m.call("do_run")
		await _settle()
		await tree.create_timer(0.3).timeout
		var fb: Node = m.get("feedback")
		check((fb.get("last_played") as Array).has("run_to_bottom"), tag + " the street flies to the bottom of the pile (%s)" % str(fb.get("last_played")))
		var floats: Array = []
		for c: Node in (m.get("_fx") as Control).find_children("*", "Label", true, false):
			floats.append((c as Label).text)
		await tree.create_timer(0.9).timeout
		m.queue_free()
		await tree.process_frame
	_cleanup()


# ---------------------------------------------------------------- dd-capacity
## Head: "capacity of guns as an icon and number on cards for easy comparison". Every gun shows its
## capacity mark and every melee weapon its uses mark (icon + number), opposite the hit badge, inside
## the art window and clear of the badge, the rule chip and the name band, at every size; the
## inspect explains it; the Glossary lists both icons; no "holds X" text is left in the tooltips.
func test_capacity_and_uses_marks() -> void:
	for sz: Vector2i in SIZES:
		tree.root.size = sz
		var tag: String = "%dx%d" % [sz.x, sz.y]
		var m: Control = _main()
		await _settle()
		_street(m, {"screen": "street", "seed": "5", "gun1": "rifle", "stack1": "8,6", "gun2": "carbine", "active": "0",
			"street": "W:shotgun,K:axe,W:launcher,Z5"})
		await _settle()
		await _settle()
		var run: DDRun = game_run()
		for i: int in [0, 1, 2]:
			var cv: DDCardView = _tile(m, i)
			var c: DDCard = run.street[i]
			var role: String = "cap" if c.kind == DDCard.WEAPON else "uses"
			var want: int = bal().weapon_cap(c.wid) if role == "cap" else run.melee_take_uses(c.wid)
			check(cv != null and cv.stat_mark != null, "%s card %d has its %s mark" % [tag, i, role])
			if cv == null or cv.stat_mark == null:
				continue
			eq([str(cv.stat_mark.get("role")), int(cv.stat_mark.get("value"))], [role, want], "%s card %d: %s mark" % [tag, i, role])
			var mr: Rect2 = cv.stat_mark.get_global_rect()
			var win: Control = cv.stat_mark.get_parent()
			check(win.get_global_rect().grow(0.5).encloses(mr), "%s card %d: the mark sits inside the art window" % [tag, i])
			check(not mr.intersects(cv.hit_burst.get_global_rect()), "%s card %d: the mark is clear of the hit badge" % [tag, i])
			if cv.rule_chip != null:
				check(not mr.intersects(cv.rule_chip.get_global_rect()), "%s card %d: the mark is clear of the rule chip" % [tag, i])
			check(mr.get_center().x > win.get_global_rect().get_center().x and mr.get_center().y > win.get_global_rect().get_center().y,
				"%s card %d: the mark is in the corner opposite the hit badge" % [tag, i])
			check(mr.size.y >= 24.0, "%s card %d: the number is big enough (%.0f px)" % [tag, i, mr.size.y])
			check(not str(cv.payload.get("t1", "")).contains("holds") and not str(cv.payload.get("t1", "")).contains(" uses"), "%s card %d: no small 'holds' / 'uses' text: %s" % [tag, i, str(cv.payload.get("t1", ""))])
		# the gun row: each gun's capacity mark in its art band
		for s: int in 2:
			var gv: DDGunView = _tile(m, 200 + s)
			check(gv != null and gv.stat_mark != null and int(gv.stat_mark.get("value")) == run.slot(s).cap, "%s gun %d: capacity mark = %d" % [tag, s + 1, run.slot(s).cap])
			if gv != null and gv.stat_mark != null:
				check(gv.art_band.get_global_rect().grow(0.5).encloses(gv.stat_mark.get_global_rect()), "%s gun %d: the mark sits in the art band" % [tag, s + 1])
		# inspect explains it
		var insp: DDInspect = m.get("_inspect")
		insp.open(_tile(m, 0).payload)
		await _settle()
		var sl: Label = insp.find_child("StatLine", true, false)
		check(sl != null and sl.text.begins_with("Holds %d kills before it pays out" % bal().weapon_cap("shotgun")), "%s inspect explains the capacity: %s" % [tag, sl.text if sl != null else ""])
		insp.close()
		insp.open(_tile(m, 1).payload)
		await _settle()
		sl = insp.find_child("StatLine", true, false)
		check(sl != null and sl.text.contains("each kill uses 1"), "%s inspect explains the uses: %s" % [tag, sl.text if sl != null else ""])
		insp.close()
		# the Glossary's number badges list both marks
		m.call("open_glossary")
		await _settle()
		var cx: Control = m.get("codex")
		var names: Array = []
		for r: Node in cx.find_children("Gl_*", "", true, false):
			names.append(str(r.name))
		check(names.any(func(n: String) -> bool: return n.begins_with("Gl_capacity")) and names.any(func(n: String) -> bool: return n.begins_with("Gl_uses")),
			"%s the Glossary lists the capacity and uses marks" % tag)
		cx.call("close")
		m.queue_free()
		await tree.process_frame
	_cleanup()


func _filler(n: int) -> Array:
	var out: Array = []
	for k: int in n:
		out.append("Z2")
	return out

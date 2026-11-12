# DeadDraw dd-challenge-rack: the gun challenges read where you play (goal / progress line on the
# gun tile, the keep / break verdict of a kill, the rule with an example everywhere), the Wall Rack
# sheet's preview card and BUY buttons, and the Your Patches sheet.
extends "res://tests/dd_test_case.gd"

const Codex: GDScript = preload("res://scripts/ui/dd_codex.gd")

var _paths: Array[String] = []


func _main() -> Control:
	var game: Node = tree.root.get_node_or_null("Game")
	var pp: String = "user://dd_test_chal_%d.json" % Time.get_ticks_usec()
	_paths.append(pp)
	_paths.append(pp + ".run")
	game.set("profile", DDProfile.new(bal(), pp))
	game.set("run_save", DDRunSave.new(pp + ".run"))
	var m: Control = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	tree.root.add_child(m)
	return m


func _done(m: Control) -> void:
	m.queue_free()
	await tree.process_frame
	for p: String in _paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_paths.clear()


func _settle() -> void:
	for k: int in 5:
		await tree.process_frame


func _run() -> DDRun:
	return tree.root.get_node("Game").get("run")


func _go(m: Control, q: Dictionary) -> void:
	m.call("apply_debug", q)
	m.call("_render")
	await _settle()


func test_challenge_status_and_kill_verdict() -> void:
	var r: DDRun = plain_run(filler(8))
	# Countdown on the rifle: 8, 6 so far; the last 3 must step down by 1, so the next must be 5
	gun(r, 0, "rifle", [8, 6])
	eq(r.challenge_state(r.slot(0)), "on_track", "8, 6: on track (6 can start 6-5-4)")
	eq(r.challenge_kill(0, 5), "keeps", "5 keeps Countdown")
	eq(r.challenge_kill(0, 3), "breaks", "3 breaks Countdown")
	eq(r.challenge_next(0)["keep"], [5] as Array[int], "only 5 keeps it")
	gun(r, 0, "rifle", [8, 6, 5])
	eq(r.challenge_kill(0, 4), "meets", "4 fills the rifle and meets Countdown")
	gun(r, 0, "rifle", [8])
	eq(r.challenge_state(r.slot(0)), "open", "the first kill is outside the last 3")
	# Mixed Bag: a repeat breaks it
	gun(r, 1, "pistol", [3, 9])
	eq(r.challenge_kill(1, 3), "breaks", "a second 3 breaks Mixed Bag")
	eq(r.challenge_kill(1, 5), "keeps", "a new number keeps it")
	# Big Game is locked in by the first kill
	gun(r, 1, "twin", [7])
	eq(r.challenge_state(r.slot(1)), "met", "Big Game met by a first kill of 7")
	# Drift on the carbine (within 1 a step): 4, 4, 4 with 2 kills left can't get 3 away
	gun(r, 1, "carbine", [4, 4, 4])
	eq(r.challenge_state(r.slot(1)), "broken", "Drift can't be met any more")
	gun(r, 1, "carbine", [4, 5, 6])
	eq(r.challenge_kill(1, 7), "keeps", "7 is 3 from 4")
	# Mixed Bag and Full Spread are the same check (every kill a different number)
	for st: Array in [[3, 8, 5], [3, 8, 3]]:
		var a: Array[int] = []
		a.assign(st)
		eq(r.challenge_met("pistol", a), r.challenge_met("nailer", a), "Mixed Bag = Full Spread on %s" % str(st))


func test_challenge_line_and_texts() -> void:
	var r: DDRun = plain_run(filler(8))
	gun(r, 0, "rifle", [8, 6])
	var cl: Dictionary = DDPayloads.challenge_line(r, 0)
	eq(str(cl["text"]), "next =5", "the tile line: next =5")
	check(str(cl["hint"]).contains("exactly 5") and str(cl["hint"]).contains("Countdown"), "the hint: %s" % str(cl["hint"]))
	gun(r, 0, "rifle", [8])
	eq(str(DDPayloads.challenge_line(r, 0)["text"]), "end going 6-5-4", "nothing decided: the goal")
	gun(r, 0, "pistol", [3, 9])
	eq(str(DDPayloads.challenge_line(r, 0)["text"]), "next not 3, 9", "Mixed Bag: no repeats")
	gun(r, 0, "pistol", [3, 3])
	eq(str(DDPayloads.challenge_line(r, 0)["text"]), "missed", "missed")
	eq(DDPayloads.keep_tag([1, 2, 3, 4, 5, 9, 10, 11, 12] as Array[int], [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] as Array[int]), "≤5 or ≥9", "two ranges")
	# every challenge: a concrete rule with an example, a short goal, and a Glossary row
	var rows: String = ""
	for sec: Variant in Codex.call("sections", bal()):
		for row: Variant in (sec as Array)[1]:
			rows += str((row as Dictionary)["name"]) + " "
	for id: String in DDText.CHALLENGE_NAMES.keys():
		var t: String = DDText.challenge_text(id, bal())
		check(t.contains("(") and t.contains("pays"), "%s has an example: %s" % [id, t])
		check(DDText.challenge_goal(id, bal()) != "", "%s has a short goal" % id)
		check(rows.contains(DDText.challenge_name(id) + " ("), "%s has a Glossary row" % id)
	check(DDText.challenge_text("mixed_bag", bal()) != DDText.challenge_text("full_spread", bal()), "Full Spread's wording shows its odd / even gun")


func test_gun_tile_challenge_line_and_verdict() -> void:
	for sz: Vector2i in [Vector2i(390, 844), Vector2i(844, 390)]:
		tree.root.size = sz
		var m: Control = _main()
		await _settle()
		await _go(m, {"screen": "street", "seed": "5", "gun1": "rifle", "stack1": "8,6", "gun2": "carbine", "stack2": "4", "active": "0", "street": "Z5,Z9,Z3,Z7,Z2"})
		var gv: DDGunView = (m.get("_gun_views") as Array)[0]
		check(gv.chal_line != null and gv.chal_line.is_visible_in_tree(), "%s: the challenge line is on the gun tile" % str(sz))
		var lab: Label = gv.chal_line.find_child("ChalText", true, false)
		check(lab.text.contains("next =5"), "%s: it says next =5 (%s)" % [str(sz), lab.text])
		check(str(gv.chal_line.payload.get("t2", "")).contains("Countdown"), "%s: its tooltip says the next kill" % str(sz))
		check(gv.chal_line.get_global_rect().end.y <= gv.get_global_rect().end.y + 1, "%s: inside the tile" % str(sz))
		var art: Control = gv.art_band
		check(art.size.y >= 30.0, "%s: the gun art keeps its band (%.0f px)" % [str(sz), art.size.y])
		# a lifted / hovered zombie 5: the rifle's line says it keeps Countdown; the 3 breaks it
		m.call("show_kill_verdicts", 0)
		await _settle()
		check(lab.text.to_lower().contains("5 keeps"), "%s: verdict for 5: %s" % [str(sz), lab.text])
		m.call("show_kill_verdicts", 2)
		await _settle()
		check(lab.text.to_lower().contains("3 breaks"), "%s: verdict for 3: %s" % [str(sz), lab.text])
		m.call("clear_kill_verdicts")
		await _settle()
		check(lab.text.contains("next =5"), "%s: back to the line" % str(sz))
		# the zombie tooltip says it too
		var run: DDRun = _run()
		var zp: Dictionary = DDPayloads.card(run.street[0], run, 0)
		check(str(zp["t2"]).contains("Keeps Countdown"), "zombie tooltip: %s" % str(zp["t2"]))
		check(str(zp["body"]).contains("keeps Countdown"), "zombie zoom body")
		await _done(m)
	tree.root.size = Vector2i(390, 844)


func test_wall_rack_preview_sheet() -> void:
	for sz: Vector2i in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(1440, 900)]:
		tree.root.size = sz
		var m: Control = _main()
		await _settle()
		await _go(m, {"screen": "street", "seed": "5", "gun1": "pistol", "stack1": "3", "gun2": "none", "sheet": "machine0"})
		var sheet: Control = m.find_child("Sheet", true, false)
		check(sheet != null, "%s: rack sheet" % str(sz))
		var card: DDCardView = sheet.find_child("RackCard", true, false)
		check(card != null and card.size.x >= 150.0, "%s: the preview card is the main element" % str(sz))
		check(card.stat_mark != null and card.hit_burst != null, "%s: hit badge and capacity mark" % str(sz))
		check(card.has_art, "%s: painted art" % str(sz))
		check(sheet.find_child("RackChallenge", true, false) != null and sheet.find_child("RackPrice", true, false) != null, "%s: challenge and price" % str(sz))
		var vp: Rect2 = m.get_viewport_rect()
		var r: Rect2 = sheet.get_global_rect()
		check(r.position.y >= -1 and r.end.y <= vp.size.y + 1 and r.end.x <= vp.size.x + 1, "%s: fits (%s)" % [str(sz), str(r)])
		var b1: Button = sheet.find_child("RackBuy1", true, false)
		check(b1 != null and not b1.disabled and b1.text.begins_with("BUY INTO SLOT 1") and b1.text.contains("150 pts"), "%s: BUY with the price" % str(sz))
		# tap the card: its zoom
		card.tapped.emit(card)
		await _settle()
		check((m.get("_inspect") as Control).visible, "%s: tap = inspect" % str(sz))
		(m.get("_inspect") as DDInspect).close()
		# can't pay: dark, "need N more"
		_run().points = 5
		m.call("_render")
		await _settle()
		b1 = m.find_child("RackBuy1", true, false)
		check(b1.disabled and b1.text.contains("need 100 more pts"), "%s: need more (%s)" % [str(sz), b1.text])
		await _done(m)
	tree.root.size = Vector2i(390, 844)


func test_patches_sheet() -> void:
	for sz: Vector2i in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(1440, 900)]:
		tree.root.size = sz
		var m: Control = _main()
		await _settle()
		await _go(m, {"screen": "street", "seed": "5", "patches": "second_wind,loose_grip,field_medic,lockpick,brawler,bounty,trophy_belt"})
		var chip: DDCardView = m.find_child("PatchesChip", true, false)
		check(chip != null, "%s: the Patches row" % str(sz))
		chip.tapped.emit(chip)
		await _settle()
		var sheet: Control = m.find_child("Sheet", true, false)
		check(sheet != null and sheet.find_child("PatchesList", true, false) != null, "%s: a tap opens Your Patches" % str(sz))
		var list: Node = sheet.find_child("PatchesList", true, false)
		eq(list.get_child_count(), 7, "%s: every Patch" % str(sz))
		var sw: Node = sheet.find_child("PatchRow_second_wind", true, false)
		check(sw != null and (sw.find_child("PatchState", true, false) as Label).text == "ready", "%s: Second Wind ready" % str(sz))
		check((sw.find_child("PatchEffect", true, false) as Label).text.contains("0 HP"), "%s: the effect line" % str(sz))
		var vp: Rect2 = m.get_viewport_rect()
		var r: Rect2 = sheet.get_global_rect()
		check(r.end.y <= vp.size.y + 1 and r.position.y >= -1, "%s: fits, the list scrolls (%s)" % [str(sz), str(r)])
		# one icon's tap opens the sheet too; Close closes it
		var close: Button = null
		for b: Variant in sheet.find_children("*", "Button", true, false):
			if (b as Button).text == "Close":
				close = b
		close.pressed.emit()
		await _settle()
		check(m.find_child("PatchesList", true, false) == null, "%s: closed" % str(sz))
		_run().second_wind_used = true
		var icon: DDCardView = m.find_child("Patch_second_wind", true, false)
		if icon != null:
			icon.tapped.emit(icon)
			await _settle()
			var st: Label = m.find_child("PatchRow_second_wind", true, false).find_child("PatchState", true, false)
			eq(st.text, "used", "%s: Second Wind used" % str(sz))
		await _done(m)
	tree.root.size = Vector2i(390, 844)

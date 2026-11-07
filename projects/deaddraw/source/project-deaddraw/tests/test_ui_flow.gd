# Headless UI smoke: the Main scene builds every screen in portrait and landscape, every tile is
# inspectable (has a zoom payload), and a scripted street plays through the buttons' code paths.
extends "res://tests/dd_test_case.gd"


func _views(n: Node, out: Array) -> Array:
	for c: Node in n.get_children():
		if c is DDCardView:
			out.append(c)
		_views(c, out)
	return out


func _buttons(n: Node, out: Array) -> Array:
	for c: Node in n.get_children():
		if c is Button:
			out.append(c)
		_buttons(c, out)
	return out


func _main() -> Control:
	var game: Node = tree.root.get_node_or_null("Game")
	if game != null:
		game.set("profile", DDProfile.new(bal(), "user://dd_test_ui_profile.json"))
	var m: Control = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	tree.root.add_child(m)
	return m


func _all_inspectable(m: Control, where: String) -> void:
	var vs: Array = _views(m, [])
	check(vs.size() > 0, "%s: has tiles" % where)
	for v: Variant in vs:
		check(not (v as DDCardView).payload.is_empty(), "%s: tile '%s' is inspectable" % [where, (v as DDCardView).kind])


func test_screens_portrait_and_landscape() -> void:
	if tree.root.get_node_or_null("Game") == null:
		check(false, "Game autoload missing from the test runner")
		return
	for sz: Vector2i in [Vector2i(390, 844), Vector2i(844, 390)]:
		tree.root.size = sz
		var m: Control = _main()
		await tree.process_frame
		var tag: String = "%dx%d" % [sz.x, sz.y]
		eq(m.call("screen_name"), "TITLE", tag + " title first")
		_all_inspectable(m, tag + " title")
		m.call("_start_run")
		await tree.process_frame
		eq(m.call("screen_name"), "MAP", tag + " map")
		_all_inspectable(m, tag + " map")
		m.set("screen", 2)
		m.call("_render")
		await tree.process_frame
		_all_inspectable(m, tag + " street")
		var run: DDRun = tree.root.get_node("Game").get("run")
		var portrait: bool = sz.y > sz.x
		eq(m.get("portrait"), portrait, tag + " orientation detected")
		# the street grid uses 2 columns in portrait, 4 in landscape
		var grids: Array = []
		for v: Variant in _views(m, []):
			if (v as DDCardView).index >= 0:
				grids.append((v as DDCardView).get_parent())
		check(grids.size() == run.street.size(), tag + " one tile per street card")
		if not grids.is_empty():
			eq((grids[0] as GridContainer).columns, 2 if portrait else 4, tag + " grid columns")
		# select card 0 and press its first enabled option
		m.call("_on_card_tapped", _views(m, []).filter(func(x: DDCardView) -> bool: return x.index == 0)[0])
		await tree.process_frame
		var before: int = run.resolved_count + run.streets_played * 10
		var pressed: bool = false
		for b: Variant in _buttons(m, []):
			var btn: Button = b
			if not btn.disabled and not btn.text.begins_with("Retreat") and btn.text != "Log" and btn.text != "Settings":
				btn.pressed.emit()
				pressed = true
				break
		await tree.process_frame
		check(pressed, tag + " an option button was available")
		check(run.resolved_count + run.streets_played * 10 != before or run.phase != DDRun.Phase.STREET, tag + " the option resolved a card")
		check(str((m.get("last_event") as Dictionary).get("text", "")) != "", tag + " feedback text shown")
		# inspect overlay opens and closes
		var insp: DDInspect = null
		for c: Node in m.get_children():
			if c is DDInspect:
				insp = c
		insp.open(DDPayloads.deck(run))
		check(insp.is_open(), tag + " inspect opens")
		insp.close()
		check(not insp.is_open(), tag + " inspect closes")
		m.queue_free()
		await tree.process_frame
	if FileAccess.file_exists("user://dd_test_ui_profile.json"):
		DirAccess.remove_absolute("user://dd_test_ui_profile.json")


func test_payloads_cover_everything() -> void:
	var r: DDRun = make_run("rosa", ["Z9", "W6", "M3", "B2"] + filler(8))
	for c: DDCard in r.street:
		var p: Dictionary = DDPayloads.card(c, r)
		check(str(p["body"]) != "", "card body " + c.code())
	check(str(DDPayloads.weapon_slot(r)["body"]) != "", "weapon slot")
	check(str(DDPayloads.finale(r.district())["body"]).contains("Shatter"), "finale")
	r.retreat()
	var d: Dictionary = DDPayloads.deck(r)
	eq((d["extra_cards"] as Array).size(), 4, "deck zoom lists the 4 bottom cards face up")
	check(str(DDPayloads.deck_spec(r)["lines"][0][0]).contains("4 at bottom"), "deck counter shows bottom count")
	for p2: String in bal().all_perks():
		check(str(DDPayloads.perk(p2, bal())["body"]) != "", "perk " + p2)
	for s: String in bal().survivor_ids():
		check(str(DDPayloads.survivor(s, bal(), DDProfile.new(bal(), "user://x_unused.json"))["body"]) != "", "survivor " + s)
	check(str(DDPayloads.unlock("survivor:theo", bal(), null)["tag"]).contains("NEW"), "unlock payload")

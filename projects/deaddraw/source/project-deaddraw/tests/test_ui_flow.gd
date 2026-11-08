# Headless UI smoke (v2): the Main scene builds every screen in portrait and landscape, every
# tile is inspectable (has a zoom payload), the v2 street shows the wave track, deck counter,
# Skipped pile, doors, two weapon slots with pips, reserve, points and Reload, and a scripted
# street plays through the buttons' code paths (resolve, reload, skip, door, machine, offer).
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


func _button(m: Node, prefix: String) -> Button:
	for b: Variant in _buttons(m, []):
		if (b as Button).text.begins_with(prefix):
			return b
	return null


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


func _tags(m: Control) -> Array:
	var out: Array = []
	for v: Variant in _views(m, []):
		out.append(str((v as DDCardView).payload.get("tag", "")))
	return out


func _has_tag(m: Control, prefix: String) -> bool:
	for t: Variant in _tags(m):
		if str(t).begins_with(prefix):
			return true
	return false


func _rerender(m: Control) -> void:
	m.call("_render")
	await tree.process_frame


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
		await _rerender(m)
		_all_inspectable(m, tag + " street")
		var run: DDRun = tree.root.get_node("Game").get("run")
		var portrait: bool = sz.y > sz.x
		eq(m.get("portrait"), portrait, tag + " orientation detected")
		# v2 street furniture
		for t: String in ["WAVE", "BOSS", "DECK", "SKIPPED PILE", "POINTS", "RESERVE AMMO", "SLOT 1", "SLOT 2", "DOOR"]:
			check(_has_tag(m, t), "%s street shows %s" % [tag, t])
		var deck_line: String = ""
		for v: Variant in _views(m, []):
			if str((v as DDCardView).payload.get("tag", "")).begins_with("DECK"):
				for l: Label in (v as DDCardView).line_labels:
					deck_line = l.text
		check(deck_line.begins_with("Wave 1 - ") and deck_line.contains("zombie"), tag + " deck counter reads 'Wave 1 - N cards (M zombies)': " + deck_line)
		var sv: DDCardView = m.get("_slot_views")[0]
		check(sv != null and sv.pip_bar != null, tag + " slot 1 shows magazine pips")
		# the street grid uses 2 columns in portrait, 4 in landscape
		var grids: Array = []
		for v: Variant in _views(m, []):
			if (v as DDCardView).index >= 0 and (v as DDCardView).index < 100:
				grids.append((v as DDCardView).get_parent())
		check(grids.size() == run.street.size(), tag + " one tile per street card")
		if not grids.is_empty():
			eq((grids[0] as GridContainer).columns, 2 if portrait else 4, tag + " grid columns")
		# no tile is pushed off the screen
		var vp: Vector2 = m.get_viewport_rect().size
		for v: Variant in _views(m, []):
			var r: Rect2 = (v as DDCardView).get_global_rect()
			check(r.end.x <= vp.x + 1.0 and r.end.y <= vp.y + 1.0, "%s tile '%s' on screen (%s in %s)" % [tag, str((v as DDCardView).payload.get("tag", "")), str(r), str(vp)])
		# scripted street: a gun fight, a reload, then the street ends
		run.setup_street(["Z5", "Z4", "A4", "B2"] + filler(8, "B3"))
		await _rerender(m)
		var zi: int = idx(run, "Z5")
		m.call("_on_card_tapped", _views(m, []).filter(func(x: DDCardView) -> bool: return x.index == zi)[0])
		await tree.process_frame
		var gun_btn: Button = _button(m, "Service Pistol: -")
		check(gun_btn != null and not gun_btn.disabled, tag + " slot 1 option states its result")
		check(gun_btn != null and gun_btn.text.contains("1 round") and gun_btn.text.contains("pts"), tag + " option shows ammo and points")
		check(_button(m, "BARE: -5 HP") != null, tag + " bare option previews the damage")
		if gun_btn != null:
			gun_btn.pressed.emit()
		await tree.process_frame
		await tree.process_frame
		eq(run.cards_resolved, 1, tag + " resolved through the button")
		check(str((m.get("last_event") as Dictionary).get("text", "")) != "", tag + " feedback text shown")
		var rb: Button = _button(m, "RELOAD")
		check(rb != null and rb.text.contains("1 action") and rb.text.contains("drop"), tag + " Reload states cost and result")
		if rb != null:
			rb.pressed.emit()
		await tree.process_frame
		await tree.process_frame
		eq(run.reloads, 1, tag + " reloaded through the button")
		# skip from a fresh street
		run.setup_street(filler(12, "B2"))
		run.fled_last = false
		await _rerender(m)
		var sk: Button = _button(m, "SKIP STREET")
		check(sk != null and not sk.disabled, tag + " Skip button")
		if sk != null:
			sk.pressed.emit()
		await tree.process_frame
		await tree.process_frame
		eq(run.skipped.size(), 4, tag + " skipped through the button")
		check(_button(m, "Skip - you skipped last street") != null, tag + " Skip says why it's off")
		# a door: select it, the button names price and what it unlocks
		run.points = 999
		m.call("_on_room_tapped", 0)
		await tree.process_frame
		var ob: Button = _button(m, "OPEN for")
		check(ob != null and not ob.disabled, tag + " door button with its price")
		if ob != null:
			ob.pressed.emit()
		await tree.process_frame
		await tree.process_frame
		eq(run.opened.size(), 1, tag + " door opened through the button")
		# the machine of that room: Maple Row's Garage is a Wall Rack -> buy -> offer -> slot 2
		m.call("_on_room_tapped", 0)
		await tree.process_frame
		var mb: Button = _button(m, "Buy the")
		check(mb != null and mb.text.contains("PAY"), tag + " machine button with price and result")
		if mb != null:
			mb.pressed.emit()
		await tree.process_frame
		await tree.process_frame
		check(not run.pending_offer.is_empty(), tag + " bought: waiting for a slot")
		var insp: DDInspect = null
		for c: Node in m.get_children():
			if c is DDInspect:
				insp = c
		await tree.process_frame
		check(insp.is_open(), tag + " the result is zoomed")
		insp.close()
		var s2: Button = _button(m, "INTO SLOT 2")
		check(s2 != null, tag + " offer: slot buttons")
		if s2 != null:
			s2.pressed.emit()
		await tree.process_frame
		await tree.process_frame
		check(run.slot(1) != null, tag + " the bought gun is in slot 2")
		# last street banner
		run.setup_street(["B2", "B2", "B2", "B2"])
		await _rerender(m)
		check(_has_tag(m, "LAST STREET OF THE WAVE"), tag + " last-street banner")
		# inspect overlay opens and closes
		insp.open(DDPayloads.skipped_payload(run))
		check(insp.is_open(), tag + " inspect opens")
		insp.close()
		check(not insp.is_open(), tag + " inspect closes")
		m.queue_free()
		await tree.process_frame
	if FileAccess.file_exists("user://dd_test_ui_profile.json"):
		DirAccess.remove_absolute("user://dd_test_ui_profile.json")


func test_safehouse_and_end_screens() -> void:
	if tree.root.get_node_or_null("Game") == null:
		check(false, "Game autoload missing")
		return
	for sz: Vector2i in [Vector2i(390, 844), Vector2i(844, 390)]:
		tree.root.size = sz
		var m: Control = _main()
		await tree.process_frame
		m.call("apply_debug", {"screen": "safehouse", "seed": "3"})
		await _rerender(m)
		eq(m.call("screen_name"), "SAFEHOUSE", "safehouse")
		_all_inspectable(m, "safehouse")
		m.call("apply_debug", {"screen": "end", "seed": "3"})
		await _rerender(m)
		eq(m.call("screen_name"), "END", "end")
		_all_inspectable(m, "end")
		m.call("apply_debug", {"screen": "street", "seed": "4", "boss": "1"})
		await _rerender(m)
		check(_has_tag(m, "BOSS STREET"), "boss street banner")
		m.queue_free()
		await tree.process_frame
	if FileAccess.file_exists("user://dd_test_ui_profile.json"):
		DirAccess.remove_absolute("user://dd_test_ui_profile.json")


func test_payloads_cover_everything() -> void:
	var r: DDRun = make_run("rosa", ["Z9!payday", "W:revolver", "M3", "A4"] + filler(8))
	for c: DDCard in r.street:
		var p: Dictionary = DDPayloads.card(c, r)
		check(str(p["body"]) != "", "card body " + c.code())
	check(str(DDPayloads.card(r.street[idx(r, "Z9!payday")], r)["body"]).contains("CARRIER"), "Carrier explained")
	for s: int in 2:
		check(str(DDPayloads.slot_payload(r, s)["body"]) != "", "slot %d" % s)
	check(str(DDPayloads.finale(r.district())["body"]).contains("Shatter"), "boss")
	for i: int in r.room_count():
		check(str(DDPayloads.room_payload(r, i)["body"]).contains("Machine"), "room %d" % i)
	check(str(DDPayloads.points_payload(r)["body"]) != "", "points")
	check(str(DDPayloads.reserve_payload(r)["body"]) != "", "reserve")
	check(str(DDPayloads.wave_pip_payload(r, 0)["body"]).contains("Wave 1"), "wave pip")
	r.skip()
	var d: Dictionary = DDPayloads.skipped_payload(r)
	eq((d["extra_cards"] as Array).size(), 4, "Skipped pile zoom lists the 4 cards face up")
	check(str(DDPayloads.deck_payload(r)["body"]).contains("Next:"), "deck zoom has the next-wave preview")
	for b: Variant in bal().list("grin_effects"):
		check(str(DDPayloads.buff_payload(str(b), bal())["body"]) != "", "buff " + str(b))
	for p2: String in bal().all_perks():
		check(str(DDPayloads.perk(p2, bal())["body"]) != "", "perk " + p2)
	for s2: String in bal().survivor_ids():
		check(str(DDPayloads.survivor(s2, bal(), DDProfile.new(bal(), "user://x_unused.json"))["body"]) != "", "survivor " + s2)
	check(str(DDPayloads.unlock("survivor:theo", bal(), null)["tag"]).contains("NEW"), "unlock payload")
	check(str(DDPayloads.how_to_play(bal())["body"]).contains("RELOAD"), "how to play is v2")

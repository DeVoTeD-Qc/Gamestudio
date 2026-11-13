# DeadDraw playtest round 2 fixes (dd-r2-fixes), no rule changes: a lethal tap / drop / Run past
# asks once ("This kills you. Sure?"); every damage preview (tooltip, chip, zoom) counts Cover;
# Run past says why it is off and its tooltip doesn't offer it then; leaving the safehouse with
# points asks first; Shatter is explained where you decide (tooltip, gun verdict, log); street
# cards keep their cells after a take; boss badges in words; one word (strength) for weapons.
extends "res://tests/dd_test_case.gd"

var _paths: Array[String] = []
const SIZES: Array[Vector2i] = [Vector2i(390, 844), Vector2i(844, 390), Vector2i(1440, 900), Vector2i(1920, 1080)]


func _main() -> Control:
	var game: Node = tree.root.get_node_or_null("Game")
	var pp: String = "user://dd_test_r2_%d.json" % Time.get_ticks_usec()
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


func _named(m: Control, n: String) -> Control:
	for c: Node in m.find_children(n, "", true, false):
		if c is Control and (c as Control).is_visible_in_tree():
			return c
	return null


func test_lethal_tap_asks_once() -> void:
	for sz: Vector2i in SIZES:
		tree.root.size = sz
		var m: Control = _main()
		await _settle()
		await _go(m, {"screen": "street", "gun1": "rifle", "stack1": "", "gun2": "none", "active": "2", "street": "Z9,Z3,M4,Z6"})
		var run: DDRun = _run()
		run.hp = 4
		m.call("_render")
		await _settle()
		check(bool(run.preview(0, DDRun.MELEE)["dies"]), "%s: the 9 kills you with Bare Hands" % str(sz))
		m.call("tap_street", 0)
		await _settle()
		eq(run.street.size(), 4, "%s: the first tap does nothing to the street" % str(sz))
		eq(run.hp, 4, "%s: no damage yet" % str(sz))
		check(str(m.get("last_block")).begins_with("THIS KILLS YOU"), "%s: it says so (%s)" % [str(sz), str(m.get("last_block"))])
		check(m.find_child("BlockToast", true, false) != null, "%s: in a toast over the card" % str(sz))
		# another action in between resets the ask
		m.call("tap_street", 1)
		await _settle()
		await tree.create_timer(1.2).timeout
		var i9: int = idx(run, "Z9")
		m.call("tap_street", i9)
		await _settle()
		check(run.phase == DDRun.Phase.STREET and idx(run, "Z9") >= 0, "%s: after another action it asks again" % str(sz))
		m.call("tap_street", idx(run, "Z9"))
		await _settle()
		check(run.hp <= 0 or run.phase != DDRun.Phase.STREET, "%s: the second tap goes ahead" % str(sz))
		await _done(m)


func test_lethal_drop_and_safe_taps() -> void:
	tree.root.size = Vector2i(390, 844)
	var m: Control = _main()
	await _settle()
	await _go(m, {"screen": "street", "gun1": "rifle", "stack1": "", "gun2": "none", "active": "2", "street": "Z9,Z3,M4,Z6"})
	var run: DDRun = _run()
	run.hp = 4
	m.call("_render")
	await _settle()
	# a drag of melee onto the 9 asks the same way
	check(bool(m.call("drop_on", {"type": "weapon", "w": DDRun.MELEE}, "zombie0")), "the drop is lit")
	await _settle()
	eq(run.street.size(), 4, "the first drop asks")
	check(str(m.get("confirm_lethal")) != "", "the ask is pending")
	# a safe kill never asks
	run.hp = 20
	m.call("_render")
	await _settle()
	m.call("tap_street", idx(run, "Z3"))
	await _settle()
	eq(run.street.size(), 3, "a safe tap goes ahead at once")
	await _done(m)


func test_lethal_run_past_asks() -> void:
	tree.root.size = Vector2i(1440, 900)
	var m: Control = _main()
	await _settle()
	await _go(m, {"screen": "street", "gun1": "pistol", "stack1": "", "gun2": "none", "active": "0", "street": "Z3"})
	var run: DDRun = _run()
	to_boss(run, [])
	run.hp = 2
	run.cover = 0
	m.call("_render")
	await _settle()
	check(run.can_run_past(), "run past is on")
	m.call("do_run_past")
	await _settle()
	check(run.boss_street and run.hp == 2, "the first press asks (%d HP)" % run.hp)
	check(str(m.get("last_block")).begins_with("THIS KILLS YOU"), "it says so")
	check(str(m.call("run_past_payload", run).get("t2", "")).contains("kills you"), "its tooltip says so")
	m.call("do_run_past")
	await _settle()
	check(run.hp <= 0, "the second press goes ahead")
	await _done(m)


func test_previews_count_cover() -> void:
	# Claire's Bouncer: 9 vs the Crossbow (3) with Cover 3 takes 3 HP, not 6
	var r: DDRun = plain_run([], ["Z9", "Z3", "C2", "Z6"])
	gun(r, 0, "crossbow", [4, 7, 8])
	r.active = 0
	r.cover = 3
	r.hp = 9
	var pr: Dictionary = r.preview(0, 0)
	check(bool(pr["ok"]), "the crossbow takes the 9")
	var t2: String = str(DDPayloads.card(r.street[0], r, 0)["t2"])
	check(t2.contains("-3 HP (Cover 3)") and not t2.contains("-6"), "tooltip: -3 after Cover (%s)" % t2)
	var body: String = str(DDPayloads.card(r.street[0], r, 0)["body"])
	check(body.contains("-3 HP (Cover takes 3)"), "zoom: -3 after Cover (%s)" % body)
	var spec: Dictionary = DDPayloads.street_card_spec(r.street[0], 0, r)
	eq(str(spec["badge"]), "-3", "the chip says -3")
	var hp0: int = r.hp
	r.attack(0, 0)
	eq(hp0 - r.hp, 3, "and the attack takes 3: preview == result")
	# all Cover: no HP lost
	var r2: DDRun = plain_run([], ["Z5", "Z3", "C2", "Z6"])
	r2.active = DDRun.MELEE
	r2.cover = 10
	check(str(DDPayloads.card(r2.street[0], r2, 0)["t2"]).contains("0 HP (Cover 4)"), "melee: 0 HP, Cover takes 4 (%s)" % str(DDPayloads.card(r2.street[0], r2, 0)["t2"]))
	# a lethal preview says it
	var r3: DDRun = plain_run([], ["Z9", "Z3", "C2", "Z6"])
	r3.active = DDRun.MELEE
	r3.hp = 3
	check(str(DDPayloads.card(r3.street[0], r3, 0)["t2"]).contains("KILLS YOU"), "lethal tooltip says KILLS YOU")
	check(str(DDPayloads.street_card_spec(r3.street[0], 0, r3)["badge"]).contains("DIES"), "and the chip says DIES")


func test_run_past_off_says_why() -> void:
	for sz: Vector2i in SIZES:
		tree.root.size = sz
		var m: Control = _main()
		await _settle()
		await _go(m, {"screen": "street", "gun1": "pistol", "stack1": "", "gun2": "none", "active": "0", "street": "Z3"})
		var run: DDRun = _run()
		to_boss(run, ["C2"])
		check(run.boss_street, "%s: boss street" % str(sz))
		m.call("_render")
		await _settle()
		var rp: Button = _named(m, "RunPast") as Button
		check(rp != null and not rp.disabled and rp.text.contains("HP"), "%s: Run past on before the first card" % str(sz))
		run.resolved = 1
		m.call("_render")
		await _settle()
		rp = _named(m, "RunPast") as Button
		check(rp != null and rp.disabled, "%s: off after the first card" % str(sz))
		check(rp != null and not rp.text.contains("-3 HP"), "%s: the button no longer offers it (%s)" % [str(sz), rp.text if rp != null else "-"])
		var pl: Dictionary = m.call("run_past_payload", run)
		check(str(pl["t2"]).begins_with("Boss street: resolve every card"), "%s: its tooltip says why (%s)" % [str(sz), str(pl["t2"])])
		check(not str(pl["t2"]).contains("Skip the boss"), "%s: and doesn't offer it" % str(sz))
		await _done(m)


func test_safehouse_leave_warns() -> void:
	for sz: Vector2i in SIZES:
		tree.root.size = sz
		var m: Control = _main()
		await _settle()
		await _go(m, {"screen": "safehouse", "takepatch": "1", "skipmod": "1", "points": "34"})
		var run: DDRun = _run()
		var lv: Button = _named(m, "ShopLeave") as Button
		check(lv != null and lv.text.contains("340 pts stay here"), "%s: the LEAVE button says what stays (%s)" % [str(sz), lv.text if lv != null else "-"])
		lv.pressed.emit()
		await _settle()
		eq(m.call("screen_name"), "SAFEHOUSE", "%s: leaving with points asks first" % str(sz))
		var t: Label = _named(m, "LeaveConfirmTitle") as Label
		check(t != null and t.text == "340 PTS STAY HERE", "%s: the sheet names the points" % str(sz))
		var spend: Button = _named(m, "LeaveConfirmSpend") as Button
		var go: Button = _named(m, "LeaveConfirmLeave") as Button
		check(spend != null and go != null, "%s: Spend / Leave" % str(sz))
		for b: Button in [spend, go]:
			if b != null:
				var r: Rect2 = b.get_global_rect()
				check(m.get_viewport_rect().encloses(r), "%s: %s on screen" % [str(sz), b.name])
		spend.pressed.emit()
		await _settle()
		check(_named(m, "LeaveConfirmTitle") == null and run.points == 34, "%s: SPEND FIRST goes back to the shop" % str(sz))
		(_named(m, "ShopLeave") as Button).pressed.emit()
		await _settle()
		(_named(m, "LeaveConfirmLeave") as Button).pressed.emit()
		await _settle()
		eq(m.call("screen_name"), "MAP", "%s: LEAVE ANYWAY leaves" % str(sz))
		await _done(m)
	# nothing to lose: no question
	tree.root.size = Vector2i(390, 844)
	var m2: Control = _main()
	await _settle()
	await _go(m2, {"screen": "safehouse", "takepatch": "1", "skipmod": "1", "points": "0"})
	(_named(m2, "ShopLeave") as Button).pressed.emit()
	await _settle()
	eq(m2.call("screen_name"), "MAP", "0 points: LEAVE leaves at once")
	await _done(m2)


func test_street_cards_keep_their_cells() -> void:
	for sz: Vector2i in SIZES:
		tree.root.size = sz
		var m: Control = _main()
		await _settle()
		await _go(m, {"screen": "street", "gun1": "pistol", "stack1": "", "gun2": "none", "active": "2", "street": "Z2,Z3,M4,Z1,Z5,Z6"})
		var run: DDRun = _run()
		var views: Dictionary = m.get("_street_views")
		var before: Dictionary = {}
		for c: DDCard in run.street:
			before[c.get_instance_id()] = (views[c.get_instance_id()] as Control).get_global_rect()
		m.call("tap_street", 0)
		await _settle()
		await tree.create_timer(1.5).timeout
		m.call("_render")
		await _settle()
		views = m.get("_street_views")
		var moved: int = 0
		for c2: DDCard in run.street:
			var id: int = c2.get_instance_id()
			if before.has(id) and views.has(id) and (views[id] as Control).get_global_rect().position.distance_to((before[id] as Rect2).position) > 1.0:
				moved += 1
		eq(moved, 0, "%s: no card moved after the take" % str(sz))
		check(m.find_child("StreetGap0", true, false) != null, "%s: the taken card left a gap" % str(sz))
		await _done(m)


func test_shatter_explained_where_you_decide() -> void:
	var r: DDRun = plain_run([], [])
	gun(r, 0, "pistol", [1, 2])
	to_boss(r, [])
	r.active = 0
	var bi: int = 0
	check(r.street[bi].boss_trait == "shatter", "the Groundskeeper shatters")
	var t2: String = str(DDPayloads.card(r.street[bi], r, bi)["t2"])
	check(t2.contains("Shatter: Pistol destroyed, +"), "the boss tooltip says which gun goes (%s)" % t2)
	var bp: String = str(DDPayloads.boss(r)["t2"])
	check(bp.begins_with("Shatter: the Service Pistol is destroyed (+"), "the boss chip says it (%s)" % bp)
	check(not DDText.trait_text("shatter").contains("full at once"), "no 'full at once' wording")
	var pts: int = DDPayloads.shatter_points(r, bi, 0)
	r.cover = 30
	r.attack(bi, 0)
	var log_text: String = "\n".join(r.log_lines)
	check(log_text.contains("Shatter: the Service Pistol is destroyed (+%d pts, no challenge)." % pts), "the log says it with the points (%d)" % pts)
	check(not log_text.contains("(3/4)") and not log_text.contains("(3/"), "and no socket count for the shatter kill")
	r.active = DDRun.MELEE
	check(DDPayloads.shatter_line(r, 0).contains("melee") or r.street.is_empty(), "melee is safe")


func test_boss_badges_in_words() -> void:
	var b: DDBalance = bal()
	var words: PackedStringArray = []
	for di: int in b.district_count():
		words.append(DDText.boss_words(b.district(di).get("boss", {})))
	check(words.has("strength 9"), "one boss: strength 9 (%s)" % ", ".join(words))
	check(words.has("3 at once, strength 6 each"), "horde in words")
	check(words.has("strength 8, then 10, then 12"), "phases in words")
	tree.root.size = Vector2i(390, 844)
	var m: Control = _main()
	await _settle()
	await _go(m, {"screen": "map"})
	var txt: PackedStringArray = []
	for c: Node in m.find_children("*", "Label", true, false):
		txt.append((c as Label).text)
	var all: String = " | ".join(txt)
	check(not all.contains("6×3") and not all.contains("8-12"), "no 6×3 / 8-12 on the map")
	check(all.contains("3 at once, 6 each") and all.contains("8, then 10, then 12"), "the map says it in words")
	await _done(m)


func test_one_word_for_strength() -> void:
	var b: DDBalance = bal()
	for t: String in [DDText.gun_card_text("rifle", b), DDText.melee_card_text("axe", b), DDText.bare_hands_text(b),
			DDText.patch_text("brawler", b), str(DDPayloads.gun_def("rifle", b)["t1"])]:
		check(t.to_lower().contains("strength") and not t.contains("Hits ") and not t.contains("hits "), "strength, not hits: %s" % t)
	var r: DDRun = plain_run([], ["Z5", "Z3", "C2", "Z6"])
	r.active = DDRun.MELEE
	r.attack(0, DDRun.MELEE)
	var last: String = r.log_lines[r.log_lines.size() - 1]
	check(last.contains("(strength "), "the log says strength (%s)" % last)


func test_bigger_touch_targets() -> void:
	tree.root.size = Vector2i(390, 844)
	var m: Control = _main()
	await _settle()
	await _go(m, {"screen": "street", "gun1": "rifle", "stack1": "7,5", "active": "0", "street": "Z9,Z3,M4,Z6", "open": "1", "points": "12", "hints": "1"})
	var use: Control = _named(m, "Use0")
	check(use != null and use.size.y >= 72.0, "USE is at least 72 layout px tall (%s)" % (str(use.size) if use != null else "-"))
	var ok: Control = _named(m, "HintOk")
	if ok != null:
		check(ok.size.y >= 72.0 and ok.size.x >= 104.0, "Got it is big (%s)" % str(ok.size))
	await _done(m)

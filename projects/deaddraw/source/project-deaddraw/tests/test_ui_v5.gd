# DeadDraw v5 economy pass, the screen side (economy-v5.md): the points chip also shows the score;
# a closed door says what its machine costs and asks before opening when you could not use it this
# wave; the boss chip reads BOSS + the strength badge (not "BOSS 9"); a medkit at full HP asks
# before healing 0; a full kill stack plays the STREAK! band; the Gun Mod step at the safehouse
# (every mod inspectable) and the mod chip on the gun tile.
extends "res://tests/dd_test_case.gd"

const Art: GDScript = preload("res://scripts/ui/dd_art.gd")

var _paths: Array[String] = []


func _main() -> Control:
	var game: Node = tree.root.get_node_or_null("Game")
	var pp: String = "user://dd_test_v5_%d.json" % Time.get_ticks_usec()
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


func _labels(n: Node) -> String:
	var out: PackedStringArray = []
	for c: Node in n.find_children("*", "Label", true, false):
		out.append((c as Label).text)
	return " | ".join(out)


func _go(m: Control, q: Dictionary) -> void:
	m.call("apply_debug", q)
	m.call("_render")
	await _settle()


func test_points_chip_shows_the_score() -> void:
	tree.root.size = Vector2i(390, 844)
	var m: Control = _main()
	await _settle()
	await _go(m, {"screen": "street", "seed": "5", "points": "12"})
	_run().points_earned = 40
	m.call("_render")
	await _settle()
	var pv: DDCardView = m.get("_points_view")
	check(pv != null and _labels(pv).contains("score 400"), "the PTS chip shows the score under the points (%s)" % _labels(pv))
	check(str(pv.payload.get("t1", "")).contains("to spend") and str(pv.payload.get("t1", "")).contains("score 400"), "its tooltip names both")
	await _done(m)


func test_door_shows_use_cost_and_asks_when_short() -> void:
	tree.root.size = Vector2i(390, 844)
	var m: Control = _main()
	await _settle()
	await _go(m, {"screen": "street", "seed": "5", "points": "0"})
	var run: DDRun = _run()
	var ob: Button = m.find_child("Open0", true, false)
	var ul: Label = ob.find_child("UseCost", true, false)
	check(ul != null and ul.text == "+%d to use" % bal().shown(run.machine_min_price(0)), "the plate says what the machine costs")
	check(str(DDPayloads.room_plate(run, 0).get("t2", "")).contains("Door + one use: %d" % bal().shown(run.room_total_cost(0))), "the plate's tooltip gives the total")
	run.points = run.room_cost(0)
	m.call("request_open_room", 0)
	await _settle()
	eq(str(m.get("sheet").get("type", "")), "room_confirm", "door money only: the confirm sheet")
	(m.find_child("RoomConfirmCancel", true, false) as Button).pressed.emit()
	await _settle()
	check(not run.room_open[0] and (m.get("sheet") as Dictionary).is_empty(), "NOT YET keeps it closed")
	run.points = run.room_total_cost(0)
	m.call("request_open_room", 0)
	await _settle()
	check(run.room_open[0], "with door + one use it opens at once")
	await _done(m)


func test_boss_chip_is_a_badge() -> void:
	for sz: Vector2i in [Vector2i(390, 844), Vector2i(844, 390)]:
		tree.root.size = sz
		var m: Control = _main()
		await _settle()
		await _go(m, {"screen": "street", "seed": "5"})
		var bc: Node = m.find_child("BossChip", true, false)
		check(bc != null and bc.find_child("BossStrength", true, false) != null, "%s: the boss chip wears the strength badge" % str(sz))
		check(not _labels(bc).contains("BOSS 9"), "%s: no 'BOSS 9' text" % str(sz))
		check(str((bc as DDCardView).payload.get("t1", "")).contains("strength"), "%s: its tooltip says strength" % str(sz))
		await _done(m)


func test_medkit_at_full_hp_asks_first() -> void:
	tree.root.size = Vector2i(390, 844)
	var m: Control = _main()
	await _settle()
	await _go(m, {"screen": "street", "seed": "5", "street": "M4,Z3,Z2,C2"})
	var run: DDRun = _run()
	run.hp = run.max_hp
	m.call("_render")
	await _settle()
	var n: int = run.street.size()
	m.call("tap_street", 0)
	await _settle()
	eq(run.street.size(), n, "first tap at full HP: nothing is used")
	check(str(m.get("last_block")).contains("Full HP"), "the toast says it heals 0")
	m.call("tap_street", 0)
	await _settle()
	eq(run.street.size(), n - 1, "second tap uses it anyway")
	# below max HP it heals straight away
	await _go(m, {"screen": "street", "seed": "5", "street": "M4,Z3,Z2,C2"})
	run = _run()
	run.hp = run.max_hp - 3
	m.call("_render")
	await _settle()
	m.call("tap_street", 0)
	await _settle()
	eq(run.hp, run.max_hp, "hurt: one tap heals")
	await _done(m)


func test_full_stack_plays_streak() -> void:
	tree.root.size = Vector2i(390, 844)
	var m: Control = _main()
	await _settle()
	await _go(m, {"screen": "street", "seed": "2", "near": "1"})
	m.call("tap_street", 0)
	await _settle()
	var lp: Array = m.get("feedback").get("last_played")
	check(lp.has("streak"), "a full stack plays STREAK! (%s)" % str(lp))
	await _done(m)


func test_gun_mod_chip_and_safehouse_step() -> void:
	for sz: Vector2i in [Vector2i(390, 844), Vector2i(844, 390)]:
		tree.root.size = sz
		var m: Control = _main()
		await _settle()
		await _go(m, {"screen": "street", "seed": "5", "gun1": "rifle", "stack1": "6", "mods": "echo,-"})
		var gv: Node = (m.get("_gun_views") as Array)[0]
		var chip: DDCardView = gv.get("mod_chip")
		check(chip != null and chip.mouse_filter == Control.MOUSE_FILTER_STOP, "%s: the mod chip is on the gun tile" % str(sz))
		check(str(chip.payload.get("t1", "")).contains("Echo Chamber"), "%s: and inspectable" % str(sz))
		# dd-mods-import: the painted badge sits next to the mod's name on the chip
		check(chip.find_child("ModBadge", true, false) != null, "%s: the mod chip shows the Echo Chamber badge" % str(sz))
		check(Art.texture_for(Art.mod_keys("echo")) != null and Art.texture_for(Art.mod_keys("echo", true)) != null, "the badge and its small copy load")
		await _go(m, {"screen": "safehouse", "seed": "5", "takepatch": "1", "points": "20"})
		var run: DDRun = _run()
		check(run.mod_step_open() and m.find_child("ModPanel", true, false) != null, "%s: the Gun Mod step" % str(sz))
		for mid: String in run.mod_offer:
			var cv: DDCardView = m.find_child("Mod_" + mid, true, false)
			check(cv != null and not cv.payload.is_empty(), "%s: mod %s is an inspectable card" % [str(sz), mid])
			check(cv != null and cv.find_child("LeadIcon", true, false) != null, "%s: mod %s card shows its badge" % [str(sz), mid])
			check((cv.payload.get("icon_keys", []) as Array).has("mods_" + mid), "%s: mod %s inspect shows the badge" % [str(sz), mid])
		(m.find_child("SkipMod", true, false) as Button).pressed.emit()
		await _settle()
		check(m.find_child("ShopLeave", true, false) != null, "%s: SKIP goes to the shop" % str(sz))
		await _done(m)

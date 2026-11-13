# shot_r2.gd
# Purpose: Dev tool (dd-r2-fixes, playtest round 2): screenshots of every fix at the window size it
#   is started with: the map's boss badges, a zombie tooltip with Cover, the lethal tap ("This kills
#   you. Sure?"), the boss street (Shatter tooltip, Run past off with its reason), the street after a
#   take (stable cells), the safehouse leave warning, the Glossary's badges, the room plates.
# Usage: xvfb-run -a -s "-screen 0 2000x1200x24" godot --path . --rendering-driver opengl3 \
#          --resolution 390x844 -s res://tests/tools/shot_r2.gd -- <out_dir> <prefix> [only]
# Author: UI/UX Agent (dd-r2-fixes)
extends SceneTree

var _out: String = ""
var _prefix: String = ""
var _only: String = ""
var _m: Control = null


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(_out.path_join(_prefix + name + ".png"))
	print("shot ", _prefix + name, " ", img.get_size())


func _want(key: String) -> bool:
	return _only == "" or _only.split(",").has(key)


func _fresh() -> void:
	if _m != null:
		root.remove_child(_m)
		_m.queue_free()
		await _frames(2)
	var game: Node = root.get_node("Game")
	var pp: String = "user://dd_shot_r2_%d.json" % Time.get_ticks_usec()
	game.set("profile", DDProfile.new(DDBalance.get_default(), pp))
	game.set("run_save", DDRunSave.new(pp + ".run"))
	_m = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_m)
	await _frames(6)


func _street(q: Dictionary) -> void:
	await _fresh()
	_m.call("apply_debug", q)
	_m.call("_render")
	await _frames(8)
	await create_timer(0.4).timeout


func _named(n: String) -> Control:
	for c: Node in _m.find_children(n, "", true, false):
		if c is Control and (c as Control).is_visible_in_tree():
			return c
	return null


func _rclick(c: Control) -> void:
	var at: Vector2 = c.get_global_rect().get_center()
	for down: bool in [true, false]:
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_RIGHT
		e.pressed = down
		e.position = at
		e.global_position = at
		root.push_input(e, true)


func _run_obj() -> Object:
	return root.get_node("Game").get("run")


func _rerender() -> void:
	_m.call("_render")
	await _frames(6)
	await create_timer(0.3).timeout


## The Groundskeeper's street (Shatter boss + a cover card), with the pistol in slot 1.
func _boss_street(hp: int, resolved_one: bool) -> void:
	await _street({"screen": "street", "gun1": "pistol", "stack1": "2", "gun2": "none", "active": "0", "street": "Z3"})
	var r: Object = _run_obj()
	r.set("wave_index", int(r.call("wave_count")) - 1)
	r.call("setup_street", [], ["C2"])
	r.get("street").clear()
	r.call("_start_boss_street")
	r.get("street").append(r.call("as_card", "C2"))
	r.set("budget", 2)
	r.set("hp", hp)
	if resolved_one:
		r.set("resolved", 1)
	await _rerender()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shots"
	_prefix = args[1] if args.size() > 1 else ""
	_only = args[2] if args.size() > 2 and args[2] != "all" else ""
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	if _want("map"):
		await _street({"screen": "map"})
		await _shot("01_map")
	if _want("cover"):
		# Claire's Bouncer: 9 vs the Crossbow (3) with Cover 3: the tooltip must say -3, not -6
		await _street({"screen": "street", "gun1": "crossbow", "stack1": "4,7,8", "gun2": "none", "active": "0", "street": "Z9,Z3,M4,Z6", "inspect": "zombie"})
		var r: Object = _run_obj()
		r.set("cover", 3)
		r.set("hp", 9)
		_m.set("_auto_inspect", DDPayloads.card(r.get("street")[0], r, 0))
		await _rerender()
		await _shot("02_cover_tip")
	if _want("lethal"):
		await _street({"screen": "street", "gun1": "rifle", "stack1": "", "gun2": "none", "active": "2", "street": "Z9,Z3,M4,Z6"})
		_run_obj().set("hp", 4)
		await _rerender()
		_m.call("tap_street", 0)
		await _frames(3)
		await create_timer(0.15).timeout
		await _shot("03_lethal_tap")
	if _want("boss"):
		await _boss_street(5, false)
		_m.set("_auto_inspect", DDPayloads.boss(_run_obj()))
		await _rerender()
		await _shot("04_boss_tip")
		await _boss_street(5, true)
		var rp: Control = _named("RunPast")
		if rp != null:
			_rclick(rp)
			await _frames(6)
		await _shot("05_runpast_off")
	if _want("stable"):
		await _street({"screen": "street", "gun1": "pistol", "stack1": "", "gun2": "none", "active": "2", "street": "Z2,Z3,M4,Z1,Z5,Z6"})
		await _shot("06_stable_before")
		_m.call("tap_street", 0)
		await _frames(4)
		await create_timer(1.6).timeout
		await _shot("07_stable_after")
	if _want("safehouse"):
		await _street({"screen": "safehouse", "takepatch": "1", "skipmod": "1", "points": "34"})
		var lv: Control = _named("ShopLeave")
		if lv != null:
			(lv as Button).pressed.emit()
			await _frames(6)
			await create_timer(0.3).timeout
		await _shot("08_leave_warning")
	if _want("glossary"):
		await _street({"screen": "street", "overlay": "glossary"})
		await create_timer(0.4).timeout
		await _shot("09_glossary")
	if _want("rooms"):
		await _street({"screen": "street", "gun1": "rifle", "stack1": "7,5", "active": "0", "street": "Z9,Z3,M4,Z6", "open": "1", "points": "12", "hints": "1"})
		await _shot("10_rooms")
	if _want("chip"):
		await _street({"screen": "street", "district": "1", "gun1": "rifle", "active": "0", "street": "Z9,Z3,M4,Z6"})
		await _shot("12_horde_chip")
		await _street({"screen": "street", "district": "2", "gun1": "rifle", "active": "0", "street": "Z9,Z3,M4,Z6"})
		await _shot("13_phases_chip")
	if _want("dies"):
		# the boss deal animation with a lethal damage chip on the Holdover
		await _street({"screen": "street", "gun1": "pistol", "stack1": "", "gun2": "none", "active": "2", "lastcards": "1"})
		var r2: Object = _run_obj()
		r2.set("wave_index", int(r2.call("wave_count")) - 1)
		r2.get("pile").clear()
		r2.get("street").clear()
		for code: String in ["Z1", "Z7", "Z1"]:
			r2.get("street").append(r2.call("as_card", code))
		r2.set("resolved", 0)
		r2.set("budget", 2)
		r2.set("hp", 4)
		await _rerender()
		_m.call("tap_street", 0)
		await _frames(2)
		await create_timer(0.9).timeout
		_m.call("tap_street", 1)
		for t: float in [0.25, 0.5, 0.8, 1.2]:
			await create_timer(t).timeout
			await _shot("11_dies_%d" % int(t * 100))
	quit(0)

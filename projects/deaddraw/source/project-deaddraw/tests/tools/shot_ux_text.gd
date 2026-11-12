# shot_ux_text.gd
# Purpose: Dev tool (dd-ux-text): screenshots of every screen a run touches, at the window size it
#   is started with: title, map, street, a zombie tooltip, a tap on a zombie the active gun can't
#   take (shake + toast), the gold OPEN plate's tooltip, Run's tooltip, a machine sheet, the boss
#   street, the Safehouse, the Codex, the Glossary and the end screen.
# Usage: xvfb-run -a -s "-screen 0 2000x1200x24" godot --path . --rendering-driver opengl3 \
#          --resolution 390x844 -s res://tests/tools/shot_ux_text.gd -- <out_dir> <prefix> [only]
# Author: UI/UX Agent (dd-ux-text)
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
	var pp: String = "user://dd_shot_ux_%d.json" % Time.get_ticks_usec()
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


func _right_click(c: Control) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	e.position = c.size * 0.5
	e.global_position = c.get_global_rect().get_center()
	Input.parse_input_event(e)
	var e2: InputEventMouseButton = e.duplicate()
	e2.pressed = false
	Input.parse_input_event(e2)


## A real right click on c (through the viewport, so the Control that gets it is the one on top).
func _rclick(c: Control) -> void:
	var at: Vector2 = c.get_global_rect().get_center()
	for down: bool in [true, false]:
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_RIGHT
		e.pressed = down
		e.position = at
		e.global_position = at
		root.push_input(e, true)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shots"
	_prefix = args[1] if args.size() > 1 else ""
	_only = args[2] if args.size() > 2 and args[2] != "all" else ""
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	if _want("title"):
		await _fresh()
		await create_timer(0.4).timeout
		await _shot("01_title")
	if _want("map"):
		await _street({"screen": "map"})
		await _shot("02_map")
	var base: Dictionary = {"screen": "street", "gun1": "rifle", "stack1": "7,5", "gun2": "nailer", "stack2": "4", "active": "0",
		"street": "Z9,Z3,M4,Z6"}
	if _want("street"):
		await _street(base)
		await _shot("03_street")
	if _want("zombie"):
		var q: Dictionary = base.duplicate()
		q["inspect"] = "zombie"
		await _street(q)
		await _shot("04_zombie_tip")
	if _want("blocked"):
		await _street(base)
		_m.call("tap_street", 0)
		await _frames(3)
		await create_timer(0.12).timeout
		await _shot("05_blocked_tap")
	if _want("plate"):
		var q2: Dictionary = base.duplicate()
		q2["points"] = "40"
		await _street(q2)
		var pl: Control = _named("Open0")
		if pl != null:
			_rclick(pl)
			await _frames(6)
		await _shot("06_plate_tip")
	if _want("run"):
		await _street({"screen": "street", "gun1": "rifle", "stack1": "7,5", "gun2": "nailer", "stack2": "4", "active": "0"})
		var rb: Control = _named("Run")
		if rb != null:
			_rclick(rb)
			await _frames(6)
		await _shot("07_run_tip")
	if _want("machine"):
		var q3: Dictionary = base.duplicate()
		q3["sheet"] = "machine0"
		await _street(q3)
		await _shot("08_machine_sheet")
	if _want("boss"):
		await _street({"screen": "street", "boss": "1", "gun1": "rifle", "active": "0"})
		await _shot("09_boss")
	if _want("safehouse"):
		await _street({"screen": "safehouse"})
		await _shot("10_safehouse")
	if _want("codex"):
		await _street(base)
		_m.call("open_codex")
		await _frames(8)
		await create_timer(0.3).timeout
		await _shot("11_codex")
	if _want("glossary"):
		await _street(base)
		_m.call("open_glossary")
		await _frames(8)
		await create_timer(0.3).timeout
		await _shot("12_glossary")
	if _want("end"):
		await _street({"screen": "end"})
		await create_timer(1.0).timeout
		await _shot("13_end")
	if _want("death"):
		# the real flow: a killing blow on the street, the hold, then the end screen and its fx
		await _street({"screen": "street", "street": "Z11,Z11,Z11,C2", "active": "2"})
		var run: DDRun = root.get_node("Game").get("run")
		run.hp = 2
		print("death: tapping")
		_m.call("tap_street", 0)
		await create_timer(4.0).timeout
		await _shot("14_death_flow")
		print("death: end screen ", _m.call("screen_name"))
		await create_timer(2.0).timeout
	quit(0)

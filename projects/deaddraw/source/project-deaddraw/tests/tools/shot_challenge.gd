# shot_challenge.gd
# Purpose: Dev tool (dd-challenge-rack): screenshots of the gun challenge goal / progress line on
#   the gun tiles, the keep / break verdict while a zombie is lifted, the zombie tooltip, and the
#   Wall Rack sheet (its preview card and BUY buttons, affordable and not).
# Usage: xvfb-run -a -s "-screen 0 2000x1200x24" godot --path . --rendering-driver opengl3 \
#          --resolution 390x844 -s res://tests/tools/shot_challenge.gd -- <out_dir> <prefix>
# Author: UI/UX Agent (dd-challenge-rack)
extends SceneTree

var _out: String = ""
var _prefix: String = ""
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


func _fresh(args: Dictionary) -> void:
	if _m != null:
		root.remove_child(_m)
		_m.queue_free()
		await _frames(2)
	var game: Node = root.get_node("Game")
	var pp: String = "user://dd_shot_chal_%d.json" % Time.get_ticks_usec()
	game.set("profile", DDProfile.new(DDBalance.get_default(), pp))
	game.set("run_save", DDRunSave.new(pp + ".run"))
	_m = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_m)
	await _frames(6)
	_m.call("apply_debug", args)
	_m.call("_render")
	await _frames(8)
	await create_timer(0.5).timeout


func _tile(idx: int) -> DDCardView:
	for c: Node in _m.find_children("*", "", true, false):
		if c is DDCardView and (c as DDCardView).index == idx and (c as Control).is_visible_in_tree():
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


func _inspect(c: Control, name: String) -> void:
	if c != null:
		_rclick(c)
		await _frames(10)
		await create_timer(0.3).timeout
	await _shot(name)
	var ins: Node = _m.get("_inspect")
	if ins != null and ins.has_method("close"):
		ins.call("close")
	await _frames(4)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shots"
	_prefix = args[1] if args.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	await _fresh({"screen": "street", "seed": "5", "gun1": "rifle", "stack1": "8,6", "gun2": "carbine", "stack2": "4",
		"active": "0", "street": "Z5,Z9,Z3,Z7,Z2"})
	await _shot("1_street")
	# lift the zombie 5 (a drag): both gun tiles say whether it keeps their challenge
	var z: DDCardView = _tile(0)
	if z != null and _m.has_method("start_drag"):
		var gp: Vector2 = z.get_global_rect().get_center()
		_m.call("start_drag", z, {"type": "street", "index": 0}, gp)
		await _frames(4)
		var gv: Control = (_m.get("_gun_views") as Array)[0]
		var drag: Node = _m.get("drag")
		drag.call("move", gv.get_global_rect().get_center())
		await _frames(8)
		await _shot("2_drag_zombie")
		drag.call("cancel")
		await _frames(6)
	await _inspect(_tile(0), "3_zombie_tip")
	await _inspect((_m.get("_gun_views") as Array)[0] as Control, "4_gun_inspect")
	# the Wall Rack: affordable, then not
	await _fresh({"screen": "street", "seed": "5", "gun1": "pistol", "stack1": "3", "gun2": "none", "sheet": "machine0"})
	await _shot("5_rack")
	var run: DDRun = root.get_node("Game").get("run")
	run.points = 5
	_m.call("_render")
	await _frames(8)
	await _shot("6_rack_poor")
	# the Patches row: a tap opens every Patch you wear
	await _fresh({"screen": "street", "seed": "5", "gun1": "rifle", "stack1": "8,6",
		"patches": "second_wind,loose_grip,field_medic,lockpick,brawler,bounty,trophy_belt"})
	var chip: Node = _m.find_child("PatchesChip", true, false)
	if chip != null:
		chip.emit_signal("tapped", chip)
	await _frames(10)
	await create_timer(0.4).timeout
	await _shot("7_patches")
	quit(0)

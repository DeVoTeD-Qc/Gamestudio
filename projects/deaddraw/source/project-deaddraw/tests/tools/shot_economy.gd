# shot_economy.gd
# Purpose: Dev tool (dd-economy, economy-v5.md): before / after screenshots of the economy pass:
#   the street HUD (points + score chip, boss chip, door plates), a door's tooltip and the open
#   confirm when you can't use the machine this wave, a medkit tapped at full HP, the STREAK! band
#   on a full kill stack, a gun with a Gun Mod chip, the safehouse Gun Mod step and the shop.
#   Runs on older builds too (unknown debug keys are ignored), so the same script makes "before".
# Usage: xvfb-run -a -s "-screen 0 2000x1200x24" godot --path . --rendering-driver opengl3 \
#          --resolution 390x844 -s res://tests/tools/shot_economy.gd -- <out_dir> <prefix>
# Author: Sr Game Designer Agent (dd-economy)
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


func _fresh() -> void:
	if _m != null:
		root.remove_child(_m)
		_m.queue_free()
		await _frames(2)
	var game: Node = root.get_node("Game")
	var pp: String = "user://dd_shot_econ_%d.json" % Time.get_ticks_usec()
	game.set("profile", DDProfile.new(DDBalance.get_default(), pp))
	game.set("run_save", DDRunSave.new(pp + ".run"))
	_m = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_m)
	await _frames(6)


func _go(q: Dictionary) -> void:
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


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shots"
	_prefix = args[1] if args.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	var base: Dictionary = {"screen": "street", "seed": "5", "gun1": "rifle", "stack1": "7,5", "gun2": "nailer", "stack2": "4",
		"active": "0", "street": "Z9,Z3,M4,Z6", "points": "21"}
	# 1 the street: PTS chip (+ score), boss chip, doors
	await _go(base)
	var run: DDRun = root.get_node("Game").get("run")
	run.points_earned = 64
	_m.call("_render")
	await _frames(6)
	await _shot("1_street_hud")
	# 2 the gold OPEN plate's tooltip (door money only)
	var pl: Control = _named("Open0")
	if pl != null:
		_rclick(pl)
		await _frames(6)
	await _shot("2_door_tip")
	# 3 tap the gold plate with door money only
	await _go(base)
	if _m.has_method("request_open_room"):
		_m.call("request_open_room", 0)
	else:
		_m.call("do_open_room", 0)
	await _frames(6)
	await create_timer(0.3).timeout
	await _shot("3_open_door_only")
	# 4 a medkit at full HP
	await _go(base)
	run = root.get_node("Game").get("run")
	run.hp = run.max_hp
	_m.call("_render")
	await _frames(4)
	var mi: int = 0
	for k: int in run.street.size():
		if run.street[k].kind == DDCard.MEDKIT:
			mi = k
	_m.call("tap_street", mi)
	await _frames(3)
	await create_timer(0.15).timeout
	await _shot("4_medkit_full_hp")
	# 5 a full kill stack
	await _go({"screen": "street", "seed": "2", "near": "1"})
	_m.call("tap_street", 0)
	await create_timer(0.62).timeout
	await _shot("5_full_stack")
	# 6 a gun with a Gun Mod
	await _go({"screen": "street", "seed": "5", "gun1": "rifle", "stack1": "9,7", "gun2": "carbine", "mods": "last_round,echo", "active": "0",
		"street": "Z12,Z3,Z7,Z6"})
	await _shot("6_gun_mods")
	# 7 the safehouse (after the boss Patch) and 8 its shop
	await _go({"screen": "safehouse", "seed": "5", "takepatch": "1", "points": "20"})
	run = root.get_node("Game").get("run")
	if not run.pending_patch.is_empty():
		run.take_patch(str(run.pending_patch["offer"][0]))
		run.points = 20
		_m.call("_render")
		await _frames(6)
	await _shot("7_safehouse")
	if run.has_method("skip_mod"):
		run.skip_mod()
		_m.call("_render")
		await _frames(6)
		await _shot("8_safehouse_shop")
	quit(0)

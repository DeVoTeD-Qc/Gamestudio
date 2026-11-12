# shot_mods.gd
# Purpose: Dev tool (dd-mods-import, art pack 3): screenshots of the painted Gun Mod badges in the
#   game: the gun tiles with a MOD chip (and an empty slot with a mod), the chip's inspect, the
#   safehouse Gun Mod offer cards and an offer card's inspect, and the Glossary row.
# Usage: xvfb-run -a -s "-screen 0 2000x1200x24" godot --path . --rendering-driver opengl3 \
#          --resolution 390x844 -s res://tests/tools/shot_mods.gd -- <out_dir> <prefix>
# Author: Technical Artist Agent (dd-mods-import)
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
	var pp: String = "user://dd_shot_mods_%d.json" % Time.get_ticks_usec()
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
	# 1 two guns with mods; 2 the chip's inspect
	var q: Dictionary = {"screen": "street", "seed": "5", "gun1": "rifle", "stack1": "9,7", "gun2": "carbine", "stack2": "4",
		"mods": "last_round,echo", "active": "0", "street": "Z12,Z3,Z7,Z6"}
	await _go(q)
	await _shot("1_gun_mods")
	var gv: Node = (_m.get("_gun_views") as Array)[1]
	var chip: Control = gv.get("mod_chip")
	if chip != null:
		_rclick(chip)
		await _frames(8)
	await _shot("2_mod_inspect")
	# 3 an empty slot with a mod (short barrel) beside an Open Breech gun
	await _go({"screen": "street", "seed": "5", "gun1": "pistol", "stack1": "3", "mods": "open_breech,short_barrel", "active": "0",
		"street": "Z5,Z3,Z7,Z6"})
	var run: DDRun = root.get_node("Game").get("run")
	if run.slot(1) != null:
		run.slots[1] = null
	_m.call("_render")
	await _frames(6)
	await _shot("3_empty_slot_mod")
	# 4 the safehouse Gun Mod offer; 5 an offer card's inspect
	await _go({"screen": "safehouse", "seed": "5", "takepatch": "1", "points": "20"})
	run = root.get_node("Game").get("run")
	if not run.pending_patch.is_empty():
		run.take_patch(str(run.pending_patch["offer"][0]))
		run.points = 20
		_m.call("_render")
		await _frames(6)
	await _shot("4_safehouse_offer")
	if not run.mod_offer.is_empty():
		var cv: Control = _named("Mod_" + str(run.mod_offer[0]))
		if cv != null:
			_rclick(cv)
			await _frames(8)
	await _shot("5_offer_inspect")
	quit(0)

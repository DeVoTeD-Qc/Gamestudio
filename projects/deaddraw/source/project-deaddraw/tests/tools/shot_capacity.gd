# shot_capacity.gd
# Purpose: Dev tool (dd-capacity): screenshots of the weapon capacity / uses marks: the street with
#   gun and melee cards (and a held melee weapon), the inspect of a street gun card, a melee card,
#   an equipped gun, the Codex (guns, then melee) and the Glossary's weapon rows.
# Usage: xvfb-run -a -s "-screen 0 2000x1200x24" godot --path . --rendering-driver opengl3 \
#          --resolution 390x844 -s res://tests/tools/shot_capacity.gd -- <out_dir> <prefix>
# Author: UI/UX Agent (dd-capacity)
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
	var pp: String = "user://dd_shot_cap_%d.json" % Time.get_ticks_usec()
	game.set("profile", DDProfile.new(DDBalance.get_default(), pp))
	game.set("run_save", DDRunSave.new(pp + ".run"))
	_m = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_m)
	await _frames(6)


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


func _street() -> void:
	await _fresh()
	_m.call("apply_debug", {"screen": "street", "seed": "5", "gun1": "rifle", "stack1": "8,6", "gun2": "carbine", "stack2": "4",
		"active": "0", "street": "W:shotgun,K:axe,W:launcher,Z5"})
	var run: DDRun = root.get_node("Game").get("run")
	run.melee = {"id": "wrench", "power": run.bal.melee_power("wrench"), "uses": 3}
	_m.call("_render")
	await _frames(8)
	await create_timer(0.5).timeout


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
	await _street()
	await _shot("1_street")
	await _inspect(_tile(0), "2_gun_card_inspect")
	await _inspect(_tile(1), "3_melee_card_inspect")
	var gv: Node = (_m.get("_gun_views") as Array)[0]
	await _inspect(gv as Control, "4_gun_slot_inspect")
	await _inspect(_tile(202), "5_melee_held_inspect")
	# the Codex, every entry shown: guns, then melee
	var cx: Node = _m.get("codex")
	_m.call("open_codex")
	cx.call("set_show_all", true)
	cx.call("set_filters", "guns", "", false)
	await _frames(10)
	await _shot("6_codex_guns")
	cx.call("set_filters", "melee", "", false)
	await _frames(10)
	await _shot("7_codex_melee")
	cx.call("close")
	await _frames(4)
	_m.call("open_glossary")
	await _frames(8)
	var row: Control = cx.find_child("Gl_kill_sockets", true, false)
	if row == null:
		row = cx.find_child("Gl_capacity", true, false)
	if row != null:
		var sc: ScrollContainer = null
		var p: Node = row.get_parent()
		while p != null and sc == null:
			if p is ScrollContainer:
				sc = p
			p = p.get_parent()
		if sc != null:
			await _frames(4)
			sc.scroll_vertical = int(row.global_position.y - sc.global_position.y + sc.scroll_vertical - 60.0)
	await _frames(8)
	await _shot("8_glossary_weapons")
	quit(0)

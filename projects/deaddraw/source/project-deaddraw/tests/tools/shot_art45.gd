# shot_art45.gd
# Purpose: Dev tool (dd-art-import45, art packs 4-5): screenshots of the per-value zombies and the layered
#   weapon cards in the game: the street (zombies 1-12 across shots, a gun and a melee card), the gun row
#   and the melee slot, a gun card's inspect, a zombie's inspect, the Wall Rack preview, and the Codex
#   (zombies, guns). Pass a third argument (a manifest path) for the "before" shots: that manifest is used
#   and the weapon layers are off.
# Usage: xvfb-run -a -s "-screen 0 2000x1200x24" godot --path . --rendering-driver opengl3 \
#          --resolution 390x844 -s res://tests/tools/shot_art45.gd -- <out_dir> <prefix> [<before manifest>]
# Author: Technical Artist Agent (dd-art-import45)
extends SceneTree

const Art: GDScript = preload("res://scripts/ui/dd_art.gd")

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
	var pp: String = "user://dd_shot_art45_%d.json" % Time.get_ticks_usec()
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


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shots"
	_prefix = args[1] if args.size() > 1 else ""
	if args.size() > 2:
		Art.set_layers(false)
		Art.use_manifest(args[2])
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	var base: Dictionary = {"screen": "street", "seed": "5", "gun1": "elephant", "stack1": "9", "gun2": "pistol", "active": "0"}
	var q1: Dictionary = base.duplicate()
	q1["street"] = "Z1,Z4,W:lever,Z8,K:axe,Z12"
	await _go(q1)
	await _shot("1_street_a")
	var q2: Dictionary = base.duplicate()
	q2["street"] = "Z2,Z3,Z5,Z6,Z7,Z9"
	await _go(q2)
	await _shot("2_street_b")
	var q3: Dictionary = base.duplicate()
	q3["street"] = "Z10,Z11,W:nailer,K:wrench"
	await _go(q3)
	await _shot("3_street_c")
	# a gun card's inspect, a zombie's inspect
	var run: DDRun = root.get_node("Game").get("run")
	_m.set("_auto_inspect", DDPayloads.card(run.street[2], run, 2))
	_m.call("_render")
	await _frames(10)
	await _shot("4_inspect_gun")
	await _go(q3)
	run = root.get_node("Game").get("run")
	_m.set("_auto_inspect", DDPayloads.card(run.street[0], run, 0))
	_m.call("_render")
	await _frames(10)
	await _shot("5_inspect_zombie")
	# the Wall Rack preview (the first district's Wall Rack room)
	await _go({"screen": "street", "seed": "5"})
	run = root.get_node("Game").get("run")
	var ri: int = -1
	for k: int in run.room_count():
		if str(run.machine(k).get("kind", "")) == "wall":
			ri = k
	if ri >= 0:
		await _go({"screen": "street", "seed": "5", "sheet": "machine%d" % ri})
		await _shot("6_wall_rack")
	# the Codex: zombies, then guns (everything shown)
	await _go({"screen": "title", "seed": "5"})
	_m.call("open_codex")
	await _frames(6)
	var cx: Control = _m.get("codex")
	cx.call("set_show_all", true)
	cx.call("set_filters", "zombies", "any", false)
	await _frames(8)
	await _shot("7_codex_zombies")
	cx.call("set_filters", "guns", "any", false)
	await _frames(8)
	await _shot("8_codex_guns")
	cx.call("set_filters", "melee", "any", false)
	await _frames(8)
	await _shot("9_codex_melee")
	quit(0)

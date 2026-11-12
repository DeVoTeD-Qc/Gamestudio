# shot_gun_tile.gd
# Purpose: Dev tool (dd-gun-tile): screenshots of the gun row / gun column for gun tiles of
#   capacity 2 to 6, empty, mid-stack and one kill from full, with a Gun Mod and the ACTIVE frame. Saves the
#   whole screen and a crop of the gun row ("Guns") per scenario, and prints each gun tile's rect.
# Usage: xvfb-run -a -s "-screen 0 2000x1200x24" godot --path . --rendering-driver opengl3 \
#          --resolution 390x844 -s res://tests/tools/shot_gun_tile.gd -- <out_dir> <prefix>
# Author: UI/UX Agent (dd-gun-tile)
extends SceneTree

var _out: String = ""
var _prefix: String = ""
var _m: Control = null

## [name, debug query, cap override for gun 1, cap override for gun 2] (0 = the gun's own capacity)
const CASES: Array = [
	["a_cap2_cap4", {"gun1": "elephant", "stack1": "9", "gun2": "pistol", "stack2": "3,5", "active": "0", "mods": "-,echo"}, 0, 0],
	["b_cap6_cap3", {"gun1": "lever", "stack1": "2,5,3", "gun2": "twin", "stack2": "", "active": "1"}, 6, 0],
	["c_cap5_cap6", {"gun1": "carbine", "stack1": "4,5,6,7", "gun2": "shotgun", "stack2": "8,4,10,2,9", "active": "0", "mods": "last_round,-"}, 0, 6],
]


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _fresh() -> void:
	if _m != null:
		root.remove_child(_m)
		_m.queue_free()
		await _frames(2)
	var game: Node = root.get_node("Game")
	var pp: String = "user://dd_shot_guntile_%d.json" % Time.get_ticks_usec()
	game.set("profile", DDProfile.new(DDBalance.get_default(), pp))
	game.set("run_save", DDRunSave.new(pp + ".run"))
	_m = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_m)
	await _frames(6)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shots"
	_prefix = args[1] if args.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	for c: Array in CASES:
		await _fresh()
		var q: Dictionary = {"screen": "street", "seed": "5", "street": "Z1,Z4,W:lever,Z8"}
		q.merge(c[1] as Dictionary, true)
		_m.call("apply_debug", q)
		var run: DDRun = root.get_node("Game").get("run")
		for s: int in 2:
			if int(c[2 + s]) > 0 and run.slot(s) != null:
				run.slot(s).cap = int(c[2 + s])
		_m.call("_render")
		await _frames(8)
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.save_png(_out.path_join("%s%s_full.png" % [_prefix, c[0]]))
		var guns: Control = _m.find_child("Guns", true, false)
		if guns != null:
			var r: Rect2i = Rect2i(root.get_final_transform() * guns.get_global_rect().grow(2.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			img.get_region(r).save_png(_out.path_join("%s%s_row.png" % [_prefix, c[0]]))
		for gv: Variant in (_m.get("_gun_views") as Array):
			if gv is Control:
				print("tile ", c[0], " ", (gv as Control).get_global_rect())
	quit(0)

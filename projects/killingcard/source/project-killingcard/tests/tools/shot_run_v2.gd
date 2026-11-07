# shot_run_v2.gd
# Purpose: Dev tool (kc-v2-ui): screenshots of every Run v2 screen (public art only) at the window size
#   it is started with: the run map (path choice, boss plate), a node inspect, the Event, the Shop,
#   the Rest, the Loadout (Operator select with kits and modifiers), the match with Terrain on the
#   columns, the ability button (ready, targeting, used), the match intro (Terrain and the boss).
#   Run v2 views come from the rules when they exist, else the spec's sample views (run_v2_views.gd).
# Usage: xvfb-run -a -s "-screen 0 1280x1024x24" godot --path . --rendering-driver opengl3 \
#          --resolution 844x390 -s res://tests/tools/shot_run_v2.gd -- <out_dir> [prefix] [only]
# Author: UI/UX Agent (kc-v2-ui)
extends SceneTree

const RunV2Views: GDScript = preload("res://scripts/ui/run/run_v2_views.gd")

var _out: String = ""
var _prefix: String = ""
var _only: String = ""


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


func _open(path: String) -> Control:
	var s: Control = (load(path) as PackedScene).instantiate()
	root.add_child(s)
	await _frames(12)
	await create_timer(0.4).timeout
	return s


func _close(s: Control) -> void:
	root.remove_child(s)
	s.queue_free()
	await _frames(2)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shots"
	_prefix = args[1] if args.size() > 1 else ""
	_only = args[2] if args.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	var settings: Node = root.get_node("Settings")
	settings.persist = false
	NewCard.auto_show = false
	var rs: Node = root.get_node("RunState")
	rs.autosave = false
	rs.start_run(4242)
	root.get_node("SceneRouter").dry_run = true
	RunV2Views.preview_map(RunV2Views.sample_map_view(2, 0))
	if _want("map"):
		var m: Control = await _open("res://scenes/run/RunMap.tscn")
		await _shot("01_run_map")
		var v: Control = m.get_map_view()
		v.select("s9l1")
		await _frames(4)
		await _shot("02_run_map_boss_brief")
		m.get_inspector().open(v.node_info(v.map, RunV2Views.node_by_id(v.map, "s3l0")))
		await _frames(6)
		await _shot("03_run_map_inspect_node")
		await _close(m)
	RunV2Views.clear_overrides()
	quit(0)

# shot_da2.gd
# Purpose: Dev tool (kc-da-ui2): screenshots of the screens the art-direction batch 2 touches, public
#   art only, at the window size it is started with: title, Codex, inspector (a unit and a Tactic),
#   run map (v2 briefing map + boss brief), after-action (victory and defeat).
# Usage: xvfb-run -a -s "-screen 0 1600x1000x24" godot --path . --rendering-driver opengl3 \
#          --resolution 844x390 -s res://tests/tools/shot_da2.gd -- <out_dir> [prefix] [only]
#   only: comma list of title,codex,inspector,map,aa (empty = all).
# Author: UI/UX Agent (kc-da-ui2)
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
	await create_timer(0.6).timeout
	return s


func _close(s: Node) -> void:
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
	root.get_node("SceneRouter").dry_run = true
	var rs: Node = root.get_node("RunState")
	rs.autosave = false
	# A collection in progress for the binder: a few cards found in runs (the starter is always owned).
	if OS.get_cmdline_user_args().size() > 3 and OS.get_cmdline_user_args()[3] == "seedfew":
		var prof: Dictionary = RunProfile.add_found_cards(rs.profile(), ["kc_wip_scout", "rifleman", "brawler", "combat_medic", "breacher", "marksman", "flanker"])
		rs.call(&"_save_profile", prof)
	if _want("title") or _want("codex"):
		var title: Control = await _open("res://scenes/Title.tscn")
		if _want("title"):
			await _shot("01_title")
		if _want("codex"):
			title.open_codex()
			await _frames(10)
			await create_timer(0.3).timeout
			await _shot("02_codex")
		await _close(title)
	if _want("inspector"):
		var db: Node = root.get_node("CardDB")
		var m: Control = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
		root.add_child(m)
		await _frames(30)
		await create_timer(1.0).timeout
		var c: Node = m.get_node("%MatchController")
		if c.is_mulligan_open():
			c.keep_hand()
		await _frames(6)
		for pair: Array in [[&"marksman", "03_inspector_unit"], [&"ammo_resupply", "04_inspector_tactic"]]:
			var cd: CardData = db.get_card(pair[0])
			if cd == null:
				continue
			c.open_card_inspector(cd, "player", "")
			await _frames(8)
			await create_timer(0.3).timeout
			await _shot(pair[1])
			m.get_inspector().close()
			await _frames(4)
		await _close(m)
	if _want("map"):
		rs.start_run(4242)
		RunV2Views.preview_map(RunV2Views.sample_map_view(2, 0))
		var rm: Control = await _open("res://scenes/run/RunMap.tscn")
		await _shot("05_run_map")
		var v: Control = rm.get_map_view()
		v.select("s9l1")
		await _frames(4)
		await _shot("06_run_map_boss")
		await _close(rm)
		RunV2Views.clear_overrides()
		rs.abandon_run()
	if _want("aa"):
		for pair: Array in [[&"player", "07_after_action_win"], [&"enemy", "08_after_action_loss"]]:
			rs.start_run(4242)
			rs.begin_run()
			if rs.run.map != null:
				var reach: Array = rs.run.map.reachable()
				for id: StringName in reach:
					if rs.run.map.node(id)["type"] == &"fight" or id == reach[-1]:
						rs.move_to(id)
						break
			var win: bool = pair[0] == &"player"
			rs.record_result(pair[0], {"reason": &"target", "rounds": 6, "player_score": 6 if win else 2, "enemy_score": 3 if win else 6})
			if win:
				# A report as a real match makes it: eliminations, best streak and the MVP from the log.
				var RunFlow: GDScript = load("res://scripts/ui/run/run_flow.gd")
				var rep: Dictionary = RunFlow.report_from_history(rs.run, rs.run.history[-1])
				rep.merge({"player_eliminations": 4, "enemy_eliminations": 2, "best_streak": 3, "tickets_before": 3,
						"mvp": {"card_id": "marksman", "art": "", "operator": false, "kills": 2, "damage": 7}}, true)
				root.get_node("SceneRouter").last_match_report = rep
			var aa: Control = await _open("res://scenes/run/AfterAction.tscn")
			await _shot(pair[1])
			await _close(aa)
			rs.abandon_run()
	quit(0)

# shot_ux_text.gd
# Purpose: Dev tool (kc-ux-text): screenshots of every screen a run touches, at the window size it
#   is started with, public art only: title, starter squad, loadout, run map, the match (hand, after
#   a fight with the log, a card inspector), Supply Drop reward, shop, Codex, glossary,
#   after-action and run end.
# Usage: xvfb-run -a -s "-screen 0 2000x1200x24" godot --path . --rendering-driver opengl3 \
#          --resolution 844x390 -s res://tests/tools/shot_ux_text.gd -- <out_dir> <prefix> [only]
# Author: UI/UX Agent (kc-ux-text)
extends SceneTree

const RunV2Views: GDScript = preload("res://scripts/ui/run/run_v2_views.gd")
const RunFlow: GDScript = preload("res://scripts/ui/run/run_flow.gd")

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
	await create_timer(0.5).timeout
	return s


func _close(s: Node) -> void:
	root.remove_child(s)
	s.queue_free()
	await _frames(2)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shots"
	_prefix = args[1] if args.size() > 1 else ""
	_only = args[2] if args.size() > 2 and args[2] != "all" else ""
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	var settings: Node = root.get_node("Settings")
	settings.persist = false
	NewCard.auto_show = false
	var rs: Node = root.get_node("RunState")
	rs.autosave = false
	var router: Node = root.get_node("SceneRouter")
	router.dry_run = true
	if _want("title"):
		var t: Control = await _open("res://scenes/Title.tscn")
		await _shot("01_title")
		if _want("codex") or _only == "":
			var cx: Control = t.open_codex()
			await _frames(10)
			await _shot("10_codex")
			cx.open_glossary()
			await _frames(10)
			await _shot("11_glossary")
		await _close(t)
	rs.start_run(4242)
	if _want("loadout"):
		var lo: Control = await _open("res://scenes/run/Loadout.tscn")
		var st0: Control = lo.get_starter()
		if st0 != null:
			await _frames(4)
			await _shot("02_starter")
			st0.close()
		await _frames(8)
		await _shot("03_loadout")
		await _close(lo)
	if _want("map"):
		var m: Control = await _open("res://scenes/run/RunMap.tscn")
		await _shot("04_run_map")
		await _close(m)
	if _want("match"):
		await _match()
	if _want("reward"):
		_record(rs, &"player")
		var rep: Dictionary = RunFlow.report_from_history(rs.run, rs.run.history[-1])
		rep.merge({"player_eliminations": 4, "enemy_eliminations": 2, "best_streak": 3,
				"mvp": {"card_id": "marksman", "art": "", "operator": false, "kills": 2, "damage": 7}}, true)
		router.last_match_report = rep
		var aa: Control = await _open("res://scenes/run/AfterAction.tscn")
		await _shot("08_after_action")
		await _close(aa)
		var rw: Control = await _open("res://scenes/run/Reward.tscn")
		await _shot("09_reward")
		await _close(rw)
	if _want("shop"):
		RunV2Views.preview_shop(RunV2Views.sample_shop_view())
		var s: Control = await _open("res://scenes/run/Shop.tscn")
		await _shot("12_shop")
		await _close(s)
		RunV2Views.clear_overrides()
	if _want("end"):
		rs.abandon_run()
		_record(rs, &"player")
		rs.run.tickets = 1
		rs.run.history[-1]["match"] = 1
		rs.run.pending_offers.clear()
		rs.run.phase = rs.run.PHASE_MATCH
		print("end: ", rs.record_result(&"enemy", {"reason": &"target", "rounds": 7, "player_score": 2, "enemy_score": 6}))
		var re: Control = await _open("res://scenes/run/RunEnd.tscn")
		await _shot("13_run_end")
		await _close(re)
	quit(0)


func _match() -> void:
	var m: Control = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await _frames(30)
	await create_timer(1.0).timeout
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		await _shot("05a_mulligan")
		c.keep_hand()
	if m.get_match_intro() != null and m.get_match_intro().visible:
		await _shot("05b_intro")
		m.get_match_intro().close()
		await create_timer(0.6).timeout
	await _frames(6)
	await _shot("05_match_hand")
	# Play the first affordable unit, then READY, so the log has a fight in it.
	var me: RulesSide = c.state.sides[0]
	for rc: RulesCard in me.hand:
		if rc.card.is_unit() and rc.card.cost <= me.supply:
			c.select_card(rc.uid)
			await _frames(4)
			await _shot("05c_selected")
			c.play_at(1)
			break
	await _frames(4)
	c.press_ready()
	for i: int in 60:
		await create_timer(0.25).timeout
		if not c.is_busy():
			break
	c.skip_feedback()
	await create_timer(0.8).timeout
	await _shot("06_match_after_fight")
	var pick_uid: int = me.hand[0].uid if not me.hand.is_empty() else -1
	if pick_uid >= 0:
		c.call(&"_on_card_inspected", pick_uid)
		await _frames(10)
		await _shot("07_inspector")
		var insp: Control = m.get_inspector()
		if insp != null:
			insp.close()
	await _close(m)


func _record(rs: Node, result: StringName) -> void:
	if rs.run == null or rs.run.history.is_empty():
		rs.start_run(4242)
		rs.begin_run()
	if rs.run.map != null:
		var reach: Array = rs.run.map.reachable()
		for id: StringName in reach:
			if rs.run.map.node(id)["type"] == &"fight" or id == reach[-1]:
				rs.move_to(id)
				break
	var win: bool = result == &"player"
	if rs.run.is_over():
		return
	rs.record_result(result, {"reason": &"target", "rounds": 6, "player_score": 6 if win else 2, "enemy_score": 3 if win else 6})

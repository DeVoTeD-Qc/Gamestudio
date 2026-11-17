# shot_feedback.gd
# Purpose: Dev tool (kc-feedback, the studio head's 17 Nov 2026 notes): screenshots of a tip with its
#   arrow, the UAV reveal, the score, the first-run flow and the movement targeting, at the window size
#   given. Public art only (never the git-ignored licensed folder). Written to run on older builds too
#   (every newer API is guarded), so the same tool takes the "before" and "after" shots.
# Usage: xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 844x390 \
#          -s res://tests/tools/shot_feedback.gd -- <out_dir> <prefix>
# Author: Mechanics Developer Agent (kc-feedback)
extends SceneTree

var out_dir: String = "user://shots"
var prefix: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(10)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(prefix + name + ".png")
	img.save_png(path)
	print("shot ", path, " ", img.get_size())


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		prefix = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	var st: Node = root.get_node("Settings")
	st.met_flags = {}
	st.seen_flags = {}
	st.run_profile = {}
	if &"quick_start_done" in st:
		st.quick_start_done = false
	st.tips_enabled = false
	var rs: Node = root.get_node("RunState")
	rs.autosave = false
	var guide: Node = root.get_node("ConceptGuide")
	guide.auto_show = false
	# 1. First run: the title, then START NEW RUN.
	var title: Control = (load("res://scenes/Title.tscn") as PackedScene).instantiate()
	root.add_child(title)
	await _frames(20)
	await _shot("first_run_1_title")
	title.call(&"_start_new_run")
	await _frames(2)
	title.queue_free()
	await _frames(40)
	await _shot("first_run_2_after_start")
	if current_scene != null:
		current_scene.queue_free()
	await _frames(4)
	rs.abandon_run()
	# 2. The board of a quick match.
	var m: Control = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await _frames(30)
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	await _frames(4)
	var state: MatchState = c.state
	state.sides[0].score = 2
	state.sides[1].score = 1
	c.refresh()
	await _shot("score_1_board")
	if m.has_method(&"score_race_scored"):
		m.call(&"score_race_scored", 3, 1)
		await _frames(18)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join(prefix + "score_2_plus_n.png"))
		print("shot score_2_plus_n")
	await _frames(60)
	# kc-feedback-2: the LOG badge's flash after a round (first pulse peak, ~0.3 s in).
	if m.has_method(&"request_log_flash"):
		m.call(&"request_log_flash")
		var lf: Node = m.call(&"get_log_flash")
		var guard: int = 0
		while guard < 240 and not (lf.call(&"is_flashing") and float(m.get_badge(&"score").get(&"flash")) > 0.9):
			guard += 1
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join(prefix + "log_flash.png"))
		print("shot log_flash")
		await _frames(90)
	# 3. A tip with its highlight (and arrow, after).
	var saved_seen: Variant = guide.seen_override
	guide.seen_override = {}
	guide.tips_override = true
	guide.clear_queue()
	c.notice_concepts()
	var id: StringName = guide.show_next()
	print("tip ", id)
	await _frames(20)
	await _shot("tip_1_" + String(id))
	guide.dismiss()
	await _frames(30)
	for i: int in 3:
		var nid: StringName = guide.show_next()
		if nid == &"":
			break
		await _frames(20)
		if nid in [&"supply", &"hand", &"operator"]:
			await _shot("tip_2_" + String(nid))
		guide.dismiss()
		await _frames(30)
	guide.clear_queue()
	guide.tips_override = null
	guide.seen_override = saved_seen
	# 4. UAV: the rival plays a unit in B and A face down; a Recon Drone shows them.
	var foe: RulesSide = state.sides[1]
	foe.plays.clear()
	foe.ready = false
	foe.supply = 9
	for pair: Array in [[&"kc_wip_private_2", 1], [&"kc_wip_private_3", 0]]:
		var rc: RulesCard = RulesCard.new()
		rc.uid = state.new_uid()
		rc.card = root.get_node("CardDB").call(&"get_card", pair[0])
		foe.hand.append(rc)
		state.submit(1, RulesIntent.play_card(rc.uid, pair[1]))
	state.sides[0].flags[DataEnums.EffectKind.REVEAL_DEPLOYMENTS] = state.round_number
	c.refresh()
	await _shot("uav_1_board")
	# Long press on the spotted card: the inspector.
	c.call(&"_on_lane_long_pressed", 1, &"incoming", _spotted_uid(m))
	await _shot("uav_2_inspect")
	m.get_inspector().close()
	# 5. Movement targeting: the Operator in A, selected: the columns it can reach light up.
	foe.plays.clear()
	state.sides[0].flags.erase(DataEnums.EffectKind.REVEAL_DEPLOYMENTS)
	var op: RulesUnit = state.sides[0].operator_unit
	if op != null and not op.is_on_board():
		state.put_in_line(op, 0)
		state.sides[0].operator_can_deploy = false
	c.refresh()
	await _frames(4)
	c.select_operator()
	await _shot("move_1_operator_selected")
	quit()


func _spotted_uid(m: Control) -> int:
	var lane: Node = m.get_board().get_lane(MapData.ZONE_IDS[1])
	for es: Node in lane.get_enemy_slots():
		if es.kind == es.Kind.INCOMING:
			return int(es.slot_uid)
	return -1

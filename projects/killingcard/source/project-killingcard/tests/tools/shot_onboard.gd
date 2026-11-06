# shot_onboard.gd
# Purpose: Dev tool (kc-onboard-ui): phone-size screenshots of the simple first run: the M1 Recruit
#   drop (with the "New: Calling cards" explainer, then without), the M2 "pick 2 of 4" drop, Muster
#   out, and the board (Standard Issue cards, the initiative chip and SCORE flag). Uses the shipped run
#   config on a fresh profile. Needs a display (xvfb-run on Linux).
# Usage: xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 844x390 \
#          -s res://tests/tools/shot_onboard.gd -- <out_dir>
# Author: UI/UX Agent (kc-onboard-ui)
extends SceneTree

var out_dir: String = "user://shots"


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	for i: int in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", out_dir.path_join(name + ".png"), " ", img.get_size())


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	# PUBLIC art only: never the git-ignored licensed folder (screenshots go into the public repo).
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	var st: Node = root.get_node("Settings")
	st.met_flags = {}
	st.seen_flags = {}
	NewCard.auto_show = true
	var rs: Node = root.get_node("RunState")
	rs.autosave = false
	rs.start_run(4242)
	rs.begin_run()
	rs.record_result(&"player")
	var reward: Control = (load("res://scenes/run/Reward.tscn") as PackedScene).instantiate()
	root.add_child(reward)
	await _shot("onboard_m1_new_card")
	if reward.get_new_card().is_open():
		reward.get_new_card().acknowledge()
	await _shot("onboard_m1_recruit_drop")
	# M2: pick 2 of 4.
	rs.choose_offer(0)
	while not rs.current_offer().is_empty():
		rs.skip_offer()
	rs.record_result(&"player")
	reward.show_offer()
	if reward.get_new_card().is_open():
		reward.get_new_card().acknowledge()
	await _shot("onboard_m2_pick_2_of_4")
	rs.choose_offer(0)
	reward.show_offer()
	rs.choose_offer(0)
	reward.show_offer()
	if reward.get_new_card().is_open():
		reward.get_new_card().acknowledge()
	await _shot("onboard_m2_muster_out")
	reward.queue_free()
	rs.abandon_run()
	# The board: the quick match on the Standard Issue starter.
	var m: Control = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for i: int in 30:
		await process_frame
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	var me: RulesSide = c.state.sides[0]
	for rc: RulesCard in me.hand:
		if rc.card.standard_issue and rc.card.cost <= me.supply:
			c.state.submit(0, RulesIntent.play_card(rc.uid, 1))
			break
	c.press_ready()
	for i: int in 20:
		await process_frame
	c.skip_feedback()
	await _shot("onboard_board_initiative")
	quit()

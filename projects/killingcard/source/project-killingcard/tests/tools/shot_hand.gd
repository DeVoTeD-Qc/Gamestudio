# shot_hand.gd
# Purpose: Dev tool (kc-hand-dim): phone-size screenshots of the hand tray and the board (quick match,
#   public art only): the full screen and a 2x crop of the hand tray.
# Usage: xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 844x390 \
#          -s res://tests/tools/shot_hand.gd -- <out_dir> <prefix>
# Author: UI/UX Agent (kc-hand-dim)
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://shots"
	var prefix: String = args[1] if args.size() > 1 else "hand"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	# PUBLIC art only (screenshots go into the public repo).
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	var m: Control = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for i: int in 30:
		await process_frame
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	var me: RulesSide = c.state.sides[0]
	for rc: RulesCard in me.hand:
		if rc.card.is_unit() and rc.card.cost <= me.supply:
			c.state.submit(0, RulesIntent.play_card(rc.uid, 1))
			break
	c.press_ready()
	for i: int in 20:
		await process_frame
	c.skip_feedback()
	for i: int in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(out_dir.path_join(prefix + "_phone.png"))
	var tray: Rect2i = Rect2i(int(img.get_width() * 0.67), 0, img.get_width() - int(img.get_width() * 0.67), int(img.get_height() * 0.8))
	var crop: Image = img.get_region(tray)
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	crop.save_png(out_dir.path_join(prefix + "_tray_2x.png"))
	var board: Image = img.get_region(Rect2i(int(img.get_width() * 0.06), int(img.get_height() * 0.3), int(img.get_width() * 0.62), int(img.get_height() * 0.45)))
	board.resize(board.get_width() * 2, board.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	board.save_png(out_dir.path_join(prefix + "_board_2x.png"))
	print("shots ", out_dir, " ", prefix)
	quit()

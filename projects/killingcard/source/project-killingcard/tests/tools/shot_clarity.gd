# shot_clarity.gd
# Purpose: Dev tool (kc-clarity): plays a live match through the UI controller (Operator, units,
#   READY each round) and saves screenshots of the board after each round (the round recap, the
#   score badge with the target, the column worth tags). Also used to watch the console for errors.
# Usage: xvfb-run -a -s "-screen 0 2000x1200x24" godot --path . --rendering-driver opengl3 \
#          --resolution 844x390 -s res://tests/tools/shot_clarity.gd -- <out_dir> <prefix> [rounds]
# Author: UI/UX Agent (kc-clarity)
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _shot(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name, " ", img.get_size())


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shots"
	var prefix: String = args[1] if args.size() > 1 else ""
	var rounds: int = int(args[2]) if args.size() > 2 else 3
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	root.get_node("Settings").persist = false
	var m: Control = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await _frames(30)
	await create_timer(1.0).timeout
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	if m.get_match_intro() != null and m.get_match_intro().visible:
		m.get_match_intro().close()
		await create_timer(0.6).timeout
	var me: RulesSide = c.state.sides[0]
	for r: int in rounds:
		if c.state.result != &"":
			break
		await _frames(4)
		if me.operator_can_deploy:
			c.select_operator()
			c.play_at(r % 3)
			await _frames(4)
		for i: int in 3:
			for rc: RulesCard in me.hand:
				if rc.card.is_unit() and rc.card.cost <= me.supply:
					c.select_card(rc.uid)
					await _frames(2)
					c.play_at((r + i) % 3)
					await _frames(4)
					break
		await _shot(out, "%sr%d_plan" % [prefix, r + 1])
		c.press_ready()
		for i: int in 80:
			await create_timer(0.25).timeout
			if not c.is_busy():
				break
		await create_timer(0.6).timeout
		await _shot(out, "%sr%d_recap" % [prefix, r + 1])
	quit(0)

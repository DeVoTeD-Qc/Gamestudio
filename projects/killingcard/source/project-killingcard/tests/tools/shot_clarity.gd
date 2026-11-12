# shot_clarity.gd
# Purpose: Dev tool (kc-clarity): plays a live match through the UI controller (Operator, units,
#   READY each round) and saves screenshots of the board after each round (the round recap, the
#   score badge with the target, the column worth tags). Also used to watch the console for errors.
#   Mode "reward": a lost first match, then each reward screen (Salvage, Muster Out, weapon level).
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
	var mode: String = args[2] if args.size() > 2 else "3"
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	root.get_node("Settings").persist = false
	if mode == "reward":
		await _rewards(out, prefix)
		quit(0)
		return
	var rounds: int = int(mode)
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


## A lost match 1 (Salvage, Muster Out, weapon level), each reward screen shot in turn.
func _rewards(out: String, prefix: String) -> void:
	NewCard.auto_show = true
	var rs: Node = root.get_node("RunState")
	rs.autosave = false
	root.get_node("SceneRouter").dry_run = true
	rs.start_run(4242)
	rs.begin_run()
	if rs.run.map != null:
		for id: StringName in rs.run.map.reachable():
			if rs.run.map.node(id)["type"] == &"fight":
				rs.move_to(id)
				break
	rs.note_systems([RevealFlags.MUSTER_OUT, RevealFlags.SALVAGE, RevealFlags.CALLING_CARDS, RevealFlags.KEYWORDS])
	print("record: ", rs.record_result(&"enemy", {"reason": &"target", "rounds": 5, "player_score": 2, "enemy_score": 6}))
	for i: int in 6:
		var offer: Dictionary = rs.current_offer()
		if offer.is_empty():
			break
		var rw: Control = (load("res://scenes/run/Reward.tscn") as PackedScene).instantiate()
		root.add_child(rw)
		await _frames(12)
		await create_timer(0.5).timeout
		await _shot(out, "%sreward%d_%s" % [prefix, i, String(offer.get("kind", ""))])
		if String(offer.get("kind", "")) == "muster_out":
			print("muster marks: ", rw.get(&"muster_marks"))
		root.remove_child(rw)
		rw.queue_free()
		await _frames(2)
		rs.skip_offer()

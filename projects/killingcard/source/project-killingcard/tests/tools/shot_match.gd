# shot_match.gd
# Purpose: Dev tool: opens scenes/Match.tscn (live local match) in a real window and saves a PNG.
# Usage (needs a display, e.g. xvfb-run): godot --path . --resolution 1168x540 -s res://tests/tools/shot_match.gd -- <out.png> [frames] [action]
# Author: Mechanics Developer Agent (kc-board)
extends SceneTree

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shot.png"
	var frames: int = int(args[1]) if args.size() > 1 else 90
	var action: String = args[2] if args.size() > 2 else ""
	var scene: Node = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	root.add_child.call_deferred(scene)
	for i: int in frames:
		await process_frame
	var ctrl: Node = scene.get_node("%MatchController")
	if ctrl.is_mulligan_open():
		ctrl._on_mulligan_confirmed([] as Array[int])
		for i: int in 10:
			await process_frame
	if action == "select" and ctrl.state != null:
		ctrl.select_card(ctrl.state.sides[0].hand[0].uid)
	elif action.begins_with("play"):
		for rc: RulesCard in ctrl.state.sides[0].hand.duplicate():
			if rc.card.card_type == DataEnums.CardType.UNIT:
				ctrl.select_card(rc.uid)
				ctrl._pick_or_play(int(action.substr(4)) if action.length() > 4 else 0, &"", -1)
				break
	for i: int in 40:
		await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()

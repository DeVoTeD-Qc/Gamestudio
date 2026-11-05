# shot_match.gd
# Purpose: Dev tool (kc-board): opens scenes/Match.tscn (live local match) in a real window, runs a
#   short script of actions and saves PNG screenshots. Needs a display (xvfb-run on Linux).
# Usage: godot --path . --resolution 844x390 -s res://tests/tools/shot_match.gd -- <out_prefix> <actions>
#   actions, comma separated: op<z> (place the Operator in column z), unit<z> (first affordable unit
#   card to column z), field<z>, prot<z> (Protector), sel (select the first unit card), ready,
#   wait<n> (frames), shot<name>, inspect (first unit on the board), fast (fast animations).
# Author: Mechanics Developer Agent (kc-board)
extends SceneTree

var ctrl: Node = null
var scene: Node = null


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "user://shot"
	var actions: PackedStringArray = (args[1] if args.size() > 1 else "shotboard").split(",")
	scene = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	root.add_child.call_deferred(scene)
	for i: int in 30:
		await process_frame
	ctrl = scene.get_node("%MatchController")
	if ctrl.is_mulligan_open():
		ctrl._on_mulligan_confirmed([] as Array[int])
		for i: int in 10:
			await process_frame
	for a: String in actions:
		if a.begins_with("op"):
			ctrl.select_operator()
			ctrl.play_at(int(a.substr(2)))
		elif a.begins_with("unit") or a.begins_with("prot") or a.begins_with("field"):
			var z: int = int(a.substr(4 if a.begins_with("unit") or a.begins_with("prot") else 5))
			for rc: RulesCard in ctrl.state.sides[0].hand.duplicate():
				var ok: bool = rc.card.cost <= ctrl.state.sides[0].supply
				if a.begins_with("unit"):
					ok = ok and rc.card.card_type == DataEnums.CardType.UNIT and not rc.card.arrives_front
				elif a.begins_with("prot"):
					ok = ok and rc.card.arrives_front
				else:
					ok = ok and rc.card.card_type == DataEnums.CardType.EQUIPMENT
				if ok:
					ctrl.select_card(rc.uid)
					print("play ", rc.card.id, " -> ", ctrl.play_at(z)["ok"])
					break
		elif a == "sel":
			for rc: RulesCard in ctrl.state.sides[0].hand:
				if rc.card.card_type == DataEnums.CardType.UNIT:
					ctrl.select_card(rc.uid)
					break
		elif a == "ready":
			ctrl.press_ready()
		elif a == "fast":
			root.get_node("Settings").set(&"fast_animations", true)
		elif a.begins_with("wait"):
			for i: int in int(a.substr(4)):
				await process_frame
		elif a == "inspect":
			for z: int in 3:
				var line: Array = ctrl.state.sides[0].lines[z]
				if not line.is_empty():
					ctrl._on_lane_long_pressed(z, &"player", line[0].uid)
					break
		elif a.begins_with("shot"):
			for i: int in 20:
				await process_frame
			var img: Image = root.get_texture().get_image()
			img.save_png("%s_%s.png" % [prefix, a.substr(4)])
			print("saved ", a)
	quit()

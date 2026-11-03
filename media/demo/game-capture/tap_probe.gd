# Scratch-only autoload (f03 screenshots, never in the repo). Passive: it drives nothing. Every
# 0.3 s it prints "PROBE {json}" with the current scene, the CSS-px centre of every visible
# button and, on Match, the hand chips / lane rows / Operator panel and the controller's state,
# so Playwright can tap like a player.
extends Node

func _ready() -> void:
	if OS.has_feature("web"):
		var q: String = str(JavaScriptBridge.eval("location.search", true))
		var i: int = q.find("ts=")
		if i >= 0:
			Engine.time_scale = q.substr(i + 3).to_float()
			print("TIMESCALE ", Engine.time_scale)
	var t: Timer = Timer.new()
	t.wait_time = 0.3
	t.autostart = true
	t.ignore_time_scale = true
	t.timeout.connect(_dump)
	add_child(t)

func _css(vp: Viewport, p: Vector2) -> Array:
	var q: Vector2 = vp.get_screen_transform() * p / DisplayServer.screen_get_scale()
	return [snappedf(q.x, 0.1), snappedf(q.y, 0.1)]

func _dump() -> void:
	var tree: SceneTree = get_tree()
	var scene: Node = tree.current_scene
	if scene == null:
		return
	var vp: Viewport = tree.root
	var out: Dictionary = {"scene": String(scene.name), "buttons": {}, "fps": Engine.get_frames_per_second()}
	for c: Node in scene.find_children("*", "Button", true, false):
		var b: Button = c
		if b.is_visible_in_tree() and not b.disabled:
			out["buttons"][String(b.name) + "|" + b.text.replace("\n", " ")] = _css(vp, b.get_global_rect().get_center())
	if scene.name == &"Match":
		var c: Node = scene.get_node("%MatchController")
		if c.state != null:
			var me: RulesSide = c.state.sides[0]
			out["phase"] = String(MatchState.PHASE_NAMES[c.state.phase])
			out["round"] = c.state.round_number
			out["busy"] = c.is_busy()
			out["mulligan"] = c.is_mulligan_open()
			out["banner"] = c.is_end_banner_open()
			out["pause"] = c.is_pause_menu_open()
			out["ready"] = me.ready
			out["supply"] = me.supply
			out["op_deploy"] = me.operator_can_deploy and not c._has_play(&"place")
			out["plays"] = me.plays.size()
			var hand: Array = []
			for chip: Node in scene.get_hand().get_cards():
				var uid: int = int(chip.get_meta(&"uid", -1))
				var rc: RulesCard = me.find_in_hand(uid)
				if rc == null:
					continue
				var r: Rect2 = (chip as Control).get_global_rect()
				hand.append({"uid": uid, "cost": rc.card.cost, "unit": rc.card.is_unit(), "pos": _css(vp, r.position + Vector2(minf(24.0, r.size.x * 0.3), r.size.y * 0.5))})
			out["hand"] = hand
			var rows: Array = []
			for lane: Node in scene.get_board().get_lanes():
				rows.append(_css(vp, (lane.get_node("%FriendlyRow") as Control).get_global_rect().get_center()))
			out["rows"] = rows
			var opr: Rect2 = scene.get_operator_panel().get_global_rect()
			out["op"] = _css(vp, opr.position + Vector2(30, 20))
			out["center"] = _css(vp, scene.get_board().get_global_rect().get_center())
			out["streak"] = me.streak
			out["tray"] = me.streak_tray.map(func(x): return String(x))
			var en: RulesSide = c.state.sides[1]
			var lanes: Array = []
			var zi: int = 0
			for lane: Node in scene.get_board().get_lanes():
				var er: Control = lane.get_node("%EnemyRow")
				var es: Array = []
				var eslots: Array = lane.get_enemy_slots()
				for i: int in range(en.lines[zi].size()):
					if i < eslots.size():
						es.append({"uid": (en.lines[zi][i] as RulesUnit).uid, "pos": _css(vp, (eslots[i] as Control).get_global_rect().get_center())})
				lanes.append({"enemy_row": _css(vp, er.get_global_rect().get_center()), "enemies": es, "mine": me.lines[zi].size()})
				zi += 1
			out["lanes"] = lanes
	print("PROBE " + JSON.stringify(out))

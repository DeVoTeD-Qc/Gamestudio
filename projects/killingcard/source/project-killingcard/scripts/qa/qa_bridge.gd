# qa_bridge.gd
# Purpose: QA hook for browser smoke tests (kc-board). On a web build opened with ?qa=1 it publishes
#   window.kcQa (JSON, refreshed 4x a second): every visible Button / tap target of the current
#   scene with its text and CSS-pixel rect, and on the match screen the hand (name, id, cost,
#   playable, rect), the columns (rect, your / rival line names, Fields), the phase, round,
#   inspector state and the toast. Playwright clicks those rects instead of guessing pixels.
#   Never active outside ?qa=1; nothing here changes the game.
# Dependencies: JavaScriptBridge (web only). Added by Settings (autoload) when enabled().
# Author: Mechanics Developer Agent (kc-board)
extends Node

const PERIOD: float = 0.25
var _t: float = 0.0


static func enabled() -> bool:
	if not OS.has_feature("web"):
		return false
	var q: Variant = JavaScriptBridge.eval("window.location.search || ''", true)
	return String(q).contains("qa=1")


## ?qa=1&seed=N: the run seed a new run uses (-1 = none), so a smoke test can replay a run.
static func url_seed() -> int:
	if not enabled():
		return -1
	var q: String = String(JavaScriptBridge.eval("window.location.search || ''", true))
	for part: String in q.trim_prefix("?").split("&"):
		if part.begins_with("seed=") and part.substr(5).is_valid_int():
			return int(part.substr(5))
	return -1


func _process(delta: float) -> void:
	_t += delta
	if _t < PERIOD:
		return
	_t = 0.0
	var data: Dictionary = snapshot()
	JavaScriptBridge.eval("window.kcQa = %s;" % JSON.stringify(data), true)


## The published Dictionary (also callable from tests).
func snapshot(scene: Node = null) -> Dictionary:
	if scene == null:
		scene = get_tree().current_scene
	var out: Dictionary = {"scene": String(scene.name) if scene != null else "", "buttons": []}
	var rs: Node = get_node_or_null(^"/root/RunState")
	if rs != null and rs.get(&"run") != null:
		out["run_seed"] = rs.run.get(&"seed_value")
	if scene == null:
		return out
	for n: Node in scene.find_children("*", "Control", true, false):
		var c: Control = n
		if not c.is_visible_in_tree() or not (c is BaseButton or c.is_in_group(&"tap_target")):
			continue
		var text: String = String(c.get("text")) if c is Button else String(c.name)
		if c.has_method(&"get_text") and not c is Button:
			text = "%s %s" % [c.name, c.call(&"get_text")]
		elif c is Button and text.strip_edges().is_empty():
			text = String(c.name)
		(out["buttons"] as Array).append({"text": text.replace("\n", " "), "path": String(scene.get_path_to(c)),
				"disabled": c is BaseButton and (c as BaseButton).disabled, "rect": _css(c)})
	var ctrl: Node = scene.get_node_or_null("%MatchController") if scene.has_node("%MatchController") else null
	if ctrl != null and ctrl.get(&"state") != null:
		out["match"] = _match(scene, ctrl)
	# kc-ui3: an open codex (Title or MENU): what it shows, and the inspector over it.
	for n: Node in scene.find_children("Codex", "Control", true, false):
		var codex: Control = n
		if codex.is_visible_in_tree() and codex.has_method(&"get_tiles"):
			var tiles: Array = []
			for t: Node in codex.get_tiles():
				var e: Dictionary = t.get_meta(&"entry", {})
				tiles.append({"key": String(e.get("key", "")), "name": String(e.get("name", "")), "kind": String(e.get("kind", "")),
						"rect": _css(t)})
			var insp: Control = codex.get_inspector()
			out["codex"] = {"count": String((codex.get(&"_count") as Label).text), "tiles": tiles,
					"type": String(codex.type_filter), "cls": String(codex.class_filter), "all_arts": codex.all_arts,
					"inspector_open": insp.is_open(),
					"inspector_title": String((insp.get_node("%TitleLabel") as Label).text) if insp.is_open() else ""}
	return out


func _match(scene: Node, ctrl: Node) -> Dictionary:
	var st: MatchState = ctrl.state
	var me: RulesSide = st.sides[0]
	var hand: Array = []
	var chips: Array = scene.get_hand().get_cards()
	for i: int in mini(chips.size(), me.hand.size()):
		var rc: RulesCard = me.hand[i]
		hand.append({"name": rc.card.display_name, "id": String(rc.card.id), "cost": rc.card.cost,
				"type": int(rc.card.card_type), "front": rc.card.arrives_front,
				"playable": rc.card.cost <= me.supply, "rect": _css(chips[i]),
				"art": String(st.art_by_uid.get(rc.uid, rc.card.id))})
	var cols: Array = []
	var lanes: Array = scene.get_board().get_lanes()
	for z: int in lanes.size():
		var lane: Control = lanes[z]
		var mine: Array = []
		for u: RulesUnit in me.lines[z]:
			mine.append(u.card.display_name if u.card != null else String(u.source_id))
		var theirs: Array = []
		for u: RulesUnit in st.sides[1].lines[z]:
			theirs.append(u.card.display_name if u.card != null else String(u.source_id))
		var slots: Array = []
		for slot: Node in lane.get_enemy_slots() + lane.get_friendly_slots():
			slots.append({"side": String(slot.side), "row": slot.row, "kind": int(slot.kind), "uid": slot.slot_uid,
					"rect": _css(slot)}.merged(_art_info(slot.get(&"banner"))))
		cols.append({"rect": _css(lane), "your_half": _css(lane.get_node("%FriendlyRow")),
				"objective": _css(lane.get_objective_tile()), "you": mine, "rival": theirs,
				"fields": st.field_view(0)[z], "target": String(lane.target_state), "slots": slots})
	var insp: Control = scene.get_inspector()
	var insp_banner: Variant = insp.call(&"get_banner") if insp.is_open() and insp.has_method(&"get_banner") else null
	var fx: Node = scene.get_fx()
	var skips: Array = (fx.get(&"_skip_called") as Dictionary).keys() if fx != null and fx.get(&"_skip_called") != null else []
	return {"round": st.round_number, "phase": String(MatchState.PHASE_NAMES[st.phase]), "supply": me.supply,
			"busy": ctrl.is_busy(), "mulligan": ctrl.is_mulligan_open(), "result": String(st.result),
			"operator_can_deploy": me.operator_can_deploy,
			"operator": _css(scene.get_operator_handle() if scene.has_method(&"get_operator_handle") else scene.get_operator_panel()),
			"hand": hand, "columns": cols, "inspector_open": insp.is_open(),
			"inspector_title": String((insp.get_node("%TitleLabel") as Label).text) if insp.is_open() else "",
			"toast": scene.get_toast_text(), "fx_skips": skips, "inspector_art": _art_info(insp_banner),
			"mastery_override": BannerArtDB.operator_tier_override,
			"fx_playing": fx != null and fx.is_playing()}.merged(_layout_v2(scene))


## kc-board2: tray state, flyout, mirror, banner / card sizes and the badges' rects.
static func _layout_v2(scene: Node) -> Dictionary:
	if not scene.has_method(&"get_tray"):
		return {}
	var m: Dictionary = scene.get(&"metrics")
	var badges: Dictionary = {}
	for k: StringName in [&"menu", &"score", &"operator", &"streak", &"rival", &"preview", &"deck"]:
		var b: Control = scene.get_badge(k)
		badges[String(k)] = {"rect": _css(b), "text": String(b.call(&"get_text")) if b.has_method(&"get_text") else String(b.get(&"text"))}
	var toasts: Array = []
	for line: Control in scene.get_killfeed_toasts().get_entries():
		toasts.append(_css(line))
	var log_lines: int = scene.get_killfeed().get_entries().size()
	# kc-ui3: the Operator card, the killstreak tiles and the columns' location art.
	var op_card: Dictionary = {}
	var hand: Control = scene.get_hand()
	if hand.has_method(&"get_operator_card") and hand.get_operator_card() != null:
		var oc: Control = hand.get_operator_card()
		op_card = {"rect": _css(oc), "visible": oc.is_visible_in_tree(), "state": String(hand.operator_entry.get("state", "")),
				"status": String(hand.operator_entry.get("status", "")).replace("\n", " "), "selected": hand.operator_selected}
	var ks: Array = []
	if scene.has_method(&"get_killstreak_row"):
		var row: Control = scene.get_killstreak_row()
		for t: Control in row.get_tiles():
			var e: Dictionary = t.get_meta(&"entry", {})
			ks.append({"id": String(e.get("id", "")), "word": row.word_for(e), "ready": row.is_ready(e),
					"selected": StringName(e.get("id", &"")) == row.selected_id, "rect": _css(t), "visible": t.is_visible_in_tree()})
	var backing: Array = []
	for lane: Node in scene.get_board().get_lanes():
		var b: TextureRect = lane.get_backing() if lane.has_method(&"get_backing") else null
		backing.append({"key": String(b.get_meta(&"lane_key", "")) if b != null else "", "alpha": b.self_modulate.a if b != null else 0.0,
				"rect": _css(b) if b != null else []})
	return {"tray": String(scene.get(&"tray_state")), "tray_rect": _css(scene.get_tray()),
			"flyout": String(scene.get(&"flyout_key")), "mirror": bool(scene.get(&"mirror")),
			"banner": [m.get("bw", 0.0), m.get("bh", 0.0)], "card": [m.get("card", Vector2.ZERO).x, m.get("card", Vector2.ZERO).y],
			"hand_tab": _css(scene.get_hand_tab()), "badges": badges, "toasts": toasts, "log_lines": log_lines,
			"operator_card": op_card, "killstreaks": ks, "backing": backing,
			"speed_x2": scene.get_speed_button().button_pressed}


## kc-cod2: which art a BannerView shows (art id, licensed, animated, flipbook playing now).
static func _art_info(banner: Variant) -> Dictionary:
	if not (banner is BannerView):
		return {}
	var b: BannerView = banner
	var art: BannerArt = b.get_banner_art()
	if art == null:
		return {}
	return {"art": String(art.id), "licensed": art.licensed, "animated": art.frame_count > 1,
			"flip": b.is_flipbook_playing(), "focused": b.is_focused()}


## A Control's rect in CSS px of the page (window px / devicePixelRatio).
static func _css(c: Control) -> Array:
	var xf: Transform2D = c.get_viewport().get_screen_transform() * c.get_global_transform_with_canvas()
	var p: Vector2 = xf * Vector2.ZERO
	var e: Vector2 = xf * c.size
	var dpr: float = maxf(1.0, DisplayServer.screen_get_scale())
	return [snappedf(p.x / dpr, 0.1), snappedf(p.y / dpr, 0.1), snappedf((e.x - p.x) / dpr, 0.1), snappedf((e.y - p.y) / dpr, 0.1)]

# qa_bridge.gd
# Purpose: QA hook for browser smoke tests (kc-board). On a web build opened with ?qa=1 it publishes
#   window.kcQa (JSON, refreshed 4x a second): every visible Button / tap target of the current
#   scene with its text and CSS-pixel rect, and on the match screen the hand (name, id, cost,
#   playable, rect), the columns (rect, your / rival line names, Fields), the phase, round,
#   inspector state and the toast. Playwright clicks those rects instead of guessing pixels.
#   Never active outside ?qa=1; nothing here changes the game, except the QA-only commands a smoke
#   test can send through window.kcQaCmd (kc-syn-ui, ?qa=1 only): "win" / "lose" end the current run
#   match at once (SceneRouter.finish_run_match_forced), "stage_synergy" puts Trained cards on your
#   board and in your hand so links, sets and the placement preview can be shot without playing a
#   whole run.
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
	var cmd: Variant = JavaScriptBridge.eval("(function(){var c = window.kcQaCmd || ''; window.kcQaCmd = ''; return c;})()", true)
	if String(cmd) != "":
		run_command(String(cmd))
	var data: Dictionary = snapshot()
	JavaScriptBridge.eval("window.kcQa = %s;" % JSON.stringify(data), true)


## kc-syn-ui QA-only commands (see the header). Returns "" or why nothing happened.
func run_command(cmd: String) -> String:
	var scene: Node = get_tree().current_scene
	var router: Node = get_node_or_null(^"/root/SceneRouter")
	match cmd:
		"win", "lose":
			if router == null or scene == null or not scene.has_node("%MatchController"):
				return "no match"
			router.finish_run_match_forced(&"player" if cmd == "win" else &"enemy",
					{"reason": &"target", "rounds": 4, "player_score": 6 if cmd == "win" else 2, "enemy_score": 2 if cmd == "win" else 6},
					{"best_streak": 2, "player_eliminations": 4, "enemy_eliminations": 2})
			return ""
		"stage_synergy":
			var ctrl: Node = scene.get_node_or_null("%MatchController") if scene != null and scene.has_node("%MatchController") else null
			if ctrl == null or ctrl.get(&"state") == null:
				return "no match"
			var st: MatchState = ctrl.state
			# Point Man (Fireteam, Vanguard) in A1, Marksman (Spotter, Spec Ops) in B1; in hand a Trained
			# Breacher (Guard, Vanguard: Vanguard 2 when it lands) and a Trained Recon Specialist.
			for pair: Array in [[&"point_man", 0], [&"marksman", 1]]:
				var card: CardData = CardDB.get_card(pair[0])
				if card != null and st.projected_occupancy(0, int(pair[1])) < st.config.zone_capacity:
					st.put_in_line(st.create_unit(0, card, -1, SynergyRules.LEVEL_TRAINED), int(pair[1]))
			for id: StringName in [&"breacher", &"recon_specialist"]:
				var c2: CardData = CardDB.get_card(id)
				if c2 != null:
					st.sides[0].hand.push_front(RulesCard.new(st.new_uid(), c2, SynergyRules.LEVEL_TRAINED))
			st.sides[0].supply = maxi(st.sides[0].supply, 6)
			ctrl.refresh()
			return ""
		"stage_fight":
			# kc-fight-ui: column A gets a Pierce carry and a line advance this round: your Gunner (Pierce)
			# at the front, against a rival point man down to 1 Armor with a Point Man behind it.
			var ctrl2: Node = scene.get_node_or_null("%MatchController") if scene != null and scene.has_node("%MatchController") else null
			if ctrl2 == null or ctrl2.get(&"state") == null:
				return "no match"
			var st2: MatchState = ctrl2.state
			var gun: RulesUnit = st2.create_unit(0, CardDB.get_card(&"gunner"), -1, SynergyRules.LEVEL_TRAINED)
			st2.put_in_line(gun, 0)
			st2.sides[0].line(0).erase(gun)
			st2.sides[0].line(0).push_front(gun)
			var back: RulesUnit = st2.create_unit(1, CardDB.get_card(&"point_man"), -1, SynergyRules.LEVEL_RECRUIT)
			st2.put_in_line(back, 0)
			st2.sides[1].line(0).erase(back)
			st2.sides[1].line(0).push_front(back)
			var weak: RulesUnit = st2.create_unit(1, CardDB.get_card(&"rifleman"), -1, SynergyRules.LEVEL_RECRUIT)
			weak.armor = 1
			st2.put_in_line(weak, 0)
			st2.sides[1].line(0).erase(weak)
			st2.sides[1].line(0).push_front(weak)
			ctrl2.refresh()
			return ""
	return "unknown command"


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
	# kc-syn-ui: the reward screen's offer (kind, Retire option / picker, list tiles, deck view).
	# kc-onboard-ui: picks / taken / level of a drop, Muster out marks, the "New:" card (head Z1: the
	# Re-issue / TRAIN AS fields are gone).
	if scene.has_method(&"show_offer") and scene.get(&"offer") != null:
		var off: Dictionary = scene.get(&"offer")
		var rb: Variant = scene.get(&"retire_button")
		var ev: Control = scene.get_engine_view() if scene.has_method(&"get_engine_view") else null
		var nc: Variant = scene.get(&"new_card")
		out["reward"] = {"kind": String(off.get("kind", "")), "on_trait": String(off.get("on_trait", "")),
				"retire": bool(off.get("retire", false)), "retire_mode": bool(scene.get(&"retire_mode")),
				"retire_button": _css(rb) if rb is Control and (rb as Control).is_visible_in_tree() else [],
				"list_tiles": (scene.get(&"list_tiles") as Array).size(),
				"deck_view": ev != null and ev.visible,
				"traits": _strs(off.get("traits", [])), "arts": _strs(off.get("arts", [])),
				"picks": int(off.get("picks", 1)), "taken": (off.get("taken", []) as Array).size(), "level": int(off.get("level", 1)),
				"muster_marks": (scene.get(&"muster_marks") as Dictionary).size() if scene.get(&"muster_marks") != null else 0,
				"new_card": String(nc.flag) if nc is NewCard and (nc as NewCard).is_open() else ""}
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
			var arts: Array = []
			if codex.has_method(&"is_art_panel_open") and codex.is_art_panel_open():
				for a: Node in codex.get_art_tiles():
					var slot: Node = a.find_child("TraitSlot", true, false)
					arts.append({"art": String(a.get_meta(&"art")), "equipped": bool(a.get_meta(&"equipped")), "found": bool(a.get_meta(&"found", true)),
							"trait": String(slot.get_meta(&"trait", "")) if slot != null else "", "rect": _css(a)})
			var gl: Variant = codex.get_gives_label() if codex.has_method(&"get_gives_label") else null
			out["codex_arts"] = {"open": arts.size() > 0, "arts": arts, "gives": String((gl as Label).text) if gl is Label and arts.size() > 0 else "",
					"selected": String(codex.get(&"selected_art")) if arts.size() > 0 else ""}
			out["codex"] = {"count": String((codex.get(&"_count") as Label).text), "tiles": tiles,
					"type": String(codex.type_filter), "cls": String(codex.class_filter), "all_arts": codex.all_arts,
					"inspector_open": insp.is_open(),
					"inspector_title": String((insp.get_node("%TitleLabel") as Label).text) if insp.is_open() else ""}
	# kc-ui4: the STARTING SQUAD panel (Loadout or Codex): Operator tiles and the grouped deck.
	for n: Node in scene.find_children("Starter", "Control", true, false):
		if (n as Control).is_visible_in_tree() and n.has_method(&"get_operator_tiles"):
			var ops: Array = []
			var tiles_d: Dictionary = n.get_operator_tiles()
			for id: Variant in tiles_d:
				ops.append({"id": String(id), "rect": _css(tiles_d[id]), "selected": StringName(id) == n.get(&"picked")})
			out["starter"] = {"operators": ops, "deck_groups": (n.get_deck_tiles() as Array).size(),
					"picked": String(n.get(&"picked"))}
	for n: Node in scene.find_children("Glossary", "Control", true, false):
		if (n as Control).is_visible_in_tree() and n.has_method(&"get_rows"):
			out["glossary"] = {"rows": (n.filtered() as Array).size(), "category": String(n.get(&"category"))}
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
			"fx_playing": fx != null and fx.is_playing(), "fight": _fight(scene, fx)}.merged(_layout_v2(scene))


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
				"mini": bool(oc.get_meta(&"mini", false)), "short": bool(oc.get_meta(&"operator_short", false)),
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
			"operator_card": op_card, "killstreaks": ks, "backing": backing, "syn": _syn(scene),
			"speed_x2": scene.get_speed_button().button_pressed}


## kc-syn-ui: trait rail, link ticks, the placement preview and set callouts.
static func _syn(scene: Node) -> Dictionary:
	if not scene.has_method(&"get_trait_rail"):
		return {}
	var rail: Control = scene.get_trait_rail()
	var chips: Array = []
	for lane: Node in scene.get_board().get_lanes():
		chips.append(String(lane.get_target_chips()) if lane.has_method(&"get_target_chips") else "")
	return {"rail_rect": _css(rail), "rail_player": Array(rail.chip_texts(&"player")), "rail_enemy": Array(rail.chip_texts(&"enemy")),
			"ticks": scene.get_board().get_drawn_ticks().size(), "ghost_ticks": scene.get_board().get_ghost_ticks().size(),
			"chips": chips, "callout": scene.get_last_set_callout(), "callouts_visible": Array(scene.get_set_callouts())}


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
static func _strs(a: Variant) -> Array:
	var out: Array = []
	if a is Array:
		for x: Variant in a:
			out.append(String(x))
	return out


static func _css(c: Control) -> Array:
	var xf: Transform2D = c.get_viewport().get_screen_transform() * c.get_global_transform_with_canvas()
	var p: Vector2 = xf * Vector2.ZERO
	var e: Vector2 = xf * c.size
	var dpr: float = maxf(1.0, DisplayServer.screen_get_scale())
	return [snappedf(p.x / dpr, 0.1), snappedf(p.y / dpr, 0.1), snappedf((e.x - p.x) / dpr, 0.1), snappedf((e.y - p.y) / dpr, 0.1)]


## kc-fight-ui: the step-by-step firefight as it plays: the order strip ("A*>B->C"), the tray header,
## the units outlined as firing / lifted / pipped as fired, the speed and the last event landed.
static func _fight(scene: Node, fx: Node) -> Dictionary:
	var strip: Node = scene.call(&"get_order_strip") if scene.has_method(&"get_order_strip") else null
	var ov: Node = fx.get(&"overlay") if fx != null else null
	return {"strip": String(strip.call(&"describe")) if strip != null and (strip as Control).is_visible_in_tree() else "",
			"header": String((scene.get_node("%StepHeader") as Label).text) if scene.has_node("%StepHeader") else "",
			"shooters": (ov.get(&"shooters") as Dictionary).size() if ov != null else 0,
			"fired": (ov.get(&"fired") as Dictionary).size() if ov != null else 0,
			"lifted": (fx.call(&"lifted_uids") as Array).size() if fx != null and fx.has_method(&"lifted_uids") else 0,
			"last": String(fx.get_meta(&"qa_last", "")) if fx != null else "",
			"seen": (fx.get_meta(&"qa_seen", []) as Array).duplicate() if fx != null else [],
			"glow": (scene.call(&"get_last_glow") as Array).size() if scene.has_method(&"get_last_glow") else 0,
			"speed_x2": scene.get_speed_button().button_pressed if scene.has_method(&"get_speed_button") else false,
			"model_s": float(ctrl_of(scene).get(&"last_playback_model_s")) if ctrl_of(scene) != null else 0.0,
			"played_ms": int(ctrl_of(scene).get(&"last_playback_ms")) if ctrl_of(scene) != null else 0,
			"skipped": bool(ctrl_of(scene).get(&"last_playback_skipped")) if ctrl_of(scene) != null else false,
			"fight_ms": int(ctrl_of(scene).get(&"last_fight_ms")) if ctrl_of(scene) != null else 0,
			"fps": Engine.get_frames_per_second(),
			"caption": String(scene.call(&"get_fight_caption")) if scene.has_method(&"get_fight_caption") else ""}


static func ctrl_of(scene: Node) -> Node:
	return scene.get_node_or_null("%MatchController") if scene != null and scene.has_node("%MatchController") else null

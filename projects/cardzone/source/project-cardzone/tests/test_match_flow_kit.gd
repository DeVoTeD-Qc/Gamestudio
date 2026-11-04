# test_match_flow_kit.gd
# Purpose: Shared helpers for the match flow tests (cz11 test_match_flow.gd, cz12
#   test_match_flow_playback.gd / test_match_flow_ai.gd / test_brace_prompt.gd): the phone-size
#   spawn (844x390 pt @3x + notch insets = 1168x540 logical, content scaling off), real touches
#   (InputEventScreenTouch through emulate_mouse_from_touch), fixtures, and a touch policy that plays
#   a whole match through the real UI. No test_* methods: the runner finds nothing to run here.
# Author: UI/UX Agent (cz11 helpers, moved here and extended in cz12)
extends "res://tests/test_case.gd"

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const ActionText: GDScript = preload("res://scripts/match/action_text.gd")
const MATCH_SCENE: String = "res://scenes/match/Match.tscn"
const PHONE: Dictionary = {"name": "iPhone 844x390 @3x + notch", "pt": Vector2(844, 390), "ratio": 3.0, "insets": Rect2(47, 0, 47, 21)}
const EPS: float = 0.5


## A scripted rival: fires every legal shot first, braces with nothing, else the first legal action.
class Shooter extends RefCounted:
	var kind: String = "Shooter"

	func choose_action(state: MatchState, seat: int) -> Dictionary:
		var legal: Array[Dictionary] = LoadoutRules.legal_actions(state)
		for a: Dictionary in legal:
			if a["type"] == "shoot" and int(a["seat"]) == seat:
				return a
		for a: Dictionary in legal:
			if int(a["seat"]) == seat:
				return a
		return {}


var _saved_root_size: Vector2i
var _saved_scale_mode: int = 0
## cz12: how the touch policy braces: "all" (every eligible card, cz11), "suggested" (the
## suggestion: USE SUGGESTED + BRACE), "alternate" (suggested, then adjusted by a card tap, ...).
var brace_policy: String = "all"
## cz12: taps used on each human Brace ([] per Brace: the number of taps from prompt to BRACE).
var brace_taps: Array[int] = []
## cz12: Braces where the suggestion was used / adjusted.
var brace_used: int = 0
var brace_adjusted: int = 0


## Touch policy for the full match: shoot, loot the best affordable pile, play, move toward the
## rival, then end the turn (holding what may be held).
func _pick(ctrl: Node, legal: Array[Dictionary], n: int) -> Dictionary:
	var by: Dictionary = {}
	for a: Dictionary in legal:
		if not by.has(a["type"]):
			by[a["type"]] = []
		by[a["type"]].append(a)
	for t: String in ["drop", "brace", "shoot", "loot", "attach", "play"]:
		if by.has(t) and (n < 14 or t == "brace" or t == "drop"):
			if t == "brace":
				return _brace_choice(ctrl, by[t])
			return by[t][0]
	if by.has("move") and n < 14:
		var me: Dictionary = ctrl.view()["me"]
		if int(me["search"]) == 0:
			return by["move"][0]
	var ends: Array = by.get("end_turn", [])
	return ends.back() if not ends.is_empty() else legal[0]


## cz12: the Brace the policy wants ({type: brace, cards, via: "suggested" | "cards"}).
func _brace_choice(ctrl: Node, braces: Array) -> Dictionary:
	var suggested: Array = ctrl.brace_suggestion().get("cards", [])
	var all: Dictionary = braces.back()
	match brace_policy:
		"suggested":
			return {"type": "brace", "cards": suggested, "via": "suggested"}
		"alternate":
			if (brace_used + brace_adjusted) % 2 == 0 or (all["cards"] as Array).is_empty():
				return {"type": "brace", "cards": suggested, "via": "suggested"}
			# Adjust: the suggestion with its last card tapped off (or the first eligible card on).
			var adj: Array = suggested.duplicate()
			if not adj.is_empty():
				adj.pop_back()
			else:
				adj.append((all["cards"] as Array)[0])
			return {"type": "brace", "cards": adj, "via": "adjust", "from": suggested}
	return {"type": "brace", "cards": all["cards"], "via": "cards"}


## A Brace through the Brace panel: USE SUGGESTED + BRACE (2 taps), or USE SUGGESTED, a card tap
## to adjust, BRACE, or card taps then BRACE. Records the taps in brace_taps.
func _brace_by_touch(m: Control, a: Dictionary) -> void:
	var taps: int = 0
	var ids: Array = m.get_state()["you"]["next_ids"]
	var via: String = String(a.get("via", "cards"))
	if not m.get_brace_panel().visible:
		failures.append("the Brace panel is not up (mode %s)" % m.mode)
		return
	if via == "suggested" or via == "adjust":
		var use: Button = m.get_brace_button(&"brace_suggested")
		if use != null and not (m.get_state()["brace_prompt"].get("suggested", []) as Array).is_empty():
			await _touch(use)
			taps += 1
		if via == "adjust":
			var from: Array = a.get("from", [])
			for inst: Variant in from:
				if not (a["cards"] as Array).has(inst):
					await _touch_card(m, &"next", ids.find(int(inst)))
					taps += 1
			for inst: Variant in a["cards"]:
				if not from.has(inst):
					await _touch_card(m, &"next", ids.find(int(inst)))
					taps += 1
			brace_adjusted += 1
		else:
			brace_used += 1
	else:
		for inst: Variant in a["cards"]:
			await _touch_card(m, &"next", ids.find(int(inst)))
			taps += 1
	var chosen: Array = m.brace_set.duplicate()
	chosen.sort()
	var want: Array = (a["cards"] as Array).duplicate()
	want.sort()
	if chosen != want:
		failures.append("brace selection %s != wanted %s" % [chosen, want])
	await _touch_brace(m, &"brace")
	taps += 1
	brace_taps.append(taps)


func _touch_brace(m: Control, key: StringName) -> void:
	var b: Button = m.get_brace_button(key)
	if b == null:
		failures.append("Brace panel has no %s (keys %s, notice '%s')" % [key, m.get_brace_panel().get_keys(), m.last_notice])
		return
	await _touch(b)


func _touch_playback(m: Control, key: StringName) -> void:
	var b: Button = m.get_playback_button(key)
	if b == null:
		failures.append("playback panel has no %s button (visible %s)" % [key, m.get_playback_panel().visible])
		return
	await _touch(b)


## Plays the match to its end through the real UI with the touch policy. Returns
## {decisions, kinds (Dictionary of action types done), over (bool)}.
func _play_to_end(m: Control, max_decisions: int = 900) -> Dictionary:
	var ctrl: Node = m.get_controller()
	var seen: Dictionary = {}
	var guard: int = 0
	var turn_actions: int = 0
	var last_round: int = -1
	while ctrl.phase != &"over" and guard < max_decisions:
		# The rival may still be playing back (delays > 0): wait for input to open.
		var wait: int = 0
		while ctrl.busy and wait < 6000:
			wait += 1
			await tree.process_frame
		if ctrl.phase == &"over":
			break
		guard += 1
		var legal: Array[Dictionary] = ctrl.legal()
		if legal.is_empty():
			failures.append("no legal action for the human in phase %s" % ctrl.phase)
			break
		if int(ctrl.view()["round"]) != last_round:
			last_round = int(ctrl.view()["round"])
			turn_actions = 0
		var a: Dictionary = _pick(ctrl, legal, turn_actions)
		turn_actions += 1
		var before: int = ctrl.state.actions.size()
		await _do_by_touch(m, a)
		seen[a["type"]] = true
		if ctrl.state.actions.size() == before and ctrl.phase != &"over":
			failures.append("touch did not apply %s (notice '%s')" % [a, m.last_notice])
			break
	return {"decisions": guard, "kinds": seen, "over": ctrl.phase == &"over"}


func _do_by_touch(m: Control, a: Dictionary) -> void:
	var ctrl: Node = m.get_controller()
	match String(a["type"]):
		"drop":
			await _touch_area(m, StringName(a["area"]))
			await _touch_dock(m, &"drop")
		"brace":
			await _brace_by_touch(m, a)
		"play":
			var i: int = (m.get_state()["you"]["hand_ids"] as Array).find(int(a["card"]))
			await _touch_card(m, &"hand", i)
			var key: StringName = &"play"
			if a.has("adrenaline"):
				key = &"adrenaline_move" if a["adrenaline"] == "move" else &"adrenaline_search"
			await _touch_dock(m, key)
		"move":
			await _touch_area(m, StringName(a["to"]))
			await _touch_dock(m, &"move")
		"loot":
			await _touch_area(m, StringName(ctrl.view()["me"]["area"]))
			await _touch_dock(m, &"loot")
			var key: StringName = StringName("loot_" + str(a["pile"])) if a.has("pile") else &""
			if key == &"":
				for b: Button in m.get_sheet_buttons():
					if String(b.get_meta(&"key")).ends_with("_%d" % int(a["card"])):
						key = b.get_meta(&"key")
			await _touch(m.get_sheet_button(key))
		"shoot":
			var line: Array = m.get_state()["you"]["line"]
			var idx: int = -1
			for i: int in line.size():
				if int(line[i]["id"]) == int(a["weapon"]):
					idx = i
			m.get_line_scroll().ensure_control_visible(m.get_cards(&"line")[idx])
			await tree.process_frame
			await _touch_card(m, &"line", idx)
			await _touch_dock(m, &"fire")
		"attach":
			var att: int = int(a["attachment"])
			var hi: int = (m.get_state()["you"]["hand_ids"] as Array).find(att)
			if hi >= 0:
				await _touch_card(m, &"hand", hi)
			else:
				var line: Array = m.get_state()["you"]["line"]
				for i: int in line.size():
					if int(line[i]["id"]) == att:
						m.get_line_scroll().ensure_control_visible(m.get_cards(&"line")[i])
						await tree.process_frame
						await _touch_card(m, &"line", i)
			await _touch_dock(m, &"attach")
			if m.is_sheet_open():
				await _touch(m.get_sheet_button(StringName("attach_%d" % int(a["weapon"]))))
		"end_turn":
			await _touch(m.get_corner_buttons()[&"end_turn"])
			var ids: Array = m.get_state()["you"]["hand_ids"]
			for inst: Variant in a.get("hold", []):
				await _touch_card(m, &"hand", ids.find(int(inst)))
			await _touch_dock(m, &"end_turn")
		_:
			failures.append("no touch path for %s" % a)


# --- Helpers ----------------------------------------------------------------------------

func _fixture(players: Dictionary) -> MatchState:
	var setup: Dictionary = {"round": 3, "zone_card": 3, "route": "A", "active": players.get("active", "P1"),
			"piles": {"rail_yard": {"crowbar": 3, "red_dot_sight": 3}, "old_town": {"assault_rifle": 2}},
			"players": {"P1": players["P1"], "P2": players["P2"]}}
	var errors: Array = []
	var s: MatchState = MatchState.from_fixture(setup, RulesData.from_card_db(CardDB), {}, errors)
	if not errors.is_empty():
		failures.append("fixture errors: %s" % [errors])
	return s


func _spawn(state: MatchState, opponent: Object = null) -> Control:
	_saved_root_size = tree.root.size
	_saved_scale_mode = tree.root.content_scale_mode
	var px: Vector2 = PHONE["pt"] * PHONE["ratio"]
	var logical: Vector2 = ScreenProfile.logical_size(px, ScreenProfile.base_size(px, PHONE["ratio"]))
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	tree.root.size = Vector2i(logical)
	await tree.process_frame
	MatchStore.clear()
	var m: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
	m.auto_start = false
	var k: float = ScreenProfile.points_per_px(px, PHONE["ratio"])
	var insets: Rect2 = PHONE["insets"]
	m.points_per_px_override = k
	m.safe_area_override = Rect2(insets.position / k, logical - insets.position / k - insets.size / k)
	var ctrl: Node = m.get_node("%MatchController")
	ctrl.event_delay = 0.0
	ctrl.opponent_delay = 0.0
	if opponent != null:
		ctrl.opponent = opponent
	tree.root.add_child(m)
	for i: int in 3:
		await tree.process_frame
	m.start_live(state)
	for i: int in 3:
		await tree.process_frame
	return m


func _despawn(m: Control) -> void:
	MatchStore.clear()
	m.queue_free()
	tree.root.size = _saved_root_size
	tree.root.content_scale_mode = _saved_scale_mode


func _saved_step() -> int:
	var info: Dictionary = MatchStore.saved_info()
	return int(info.get("step", -1)) if info.get("has_match", false) else -1


## A real touch (press + release) at a point inside the control that no later sibling covers.
func _touch(c: Control) -> void:
	if c == null or not c.is_visible_in_tree():
		failures.append("touch on a missing or hidden control (%s)" % c)
		return
	await _touch_at(_exposed_point(c))


func _touch_at(pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		var t: InputEventScreenTouch = InputEventScreenTouch.new()
		t.index = 0
		t.pressed = pressed
		t.position = pos
		Input.parse_input_event(t)
		Input.flush_buffered_events()
	await tree.process_frame


func _exposed_point(c: Control) -> Vector2:
	var r: Rect2 = c.get_global_rect()
	var parent: Node = c.get_parent()
	if c is CzCard and parent != null:
		var i: int = c.get_index()
		if i + 1 < parent.get_child_count():
			var nxt: Control = parent.get_child(i + 1)
			var right: float = minf(r.end.x, nxt.get_global_rect().position.x)
			return Vector2((r.position.x + right) * 0.5, r.get_center().y)
	return r.get_center()


func _touch_card(m: Control, zone: StringName, index: int) -> void:
	var cards: Array[Control] = m.get_cards(zone)
	if index < 0 or index >= cards.size():
		failures.append("no %s card %d (have %d)" % [zone, index, cards.size()])
		return
	await _touch(cards[index])


func _touch_area(m: Control, area: StringName) -> void:
	await _touch(m.get_area_touch(area))


func _touch_dock(m: Control, key: StringName) -> void:
	var b: Button = m.get_dock_button(key)
	if b == null:
		failures.append("dock has no %s (keys %s, title '%s', notice '%s')" % [key, m.get_dock_keys(), m.get_dock_title(), m.last_notice])
		return
	await _touch(b)


func _names(m: Control, zone: StringName) -> Array:
	var out: Array = []
	for c: Control in m.get_cards(zone):
		out.append(CardDB.get_card(c.get_meta(&"card_id")).display_name)
	return out


func _index_of(m: Control, zone: StringName, card_name: String) -> int:
	return _names(m, zone).find(card_name)

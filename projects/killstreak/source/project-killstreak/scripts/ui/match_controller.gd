# match_controller.gd
# Purpose: Thin presenter for the match screen (p09). Child node "MatchController" of
#   scenes/Match.tscn. It owns the MatchState of a local test match (starter deck from
#   CardDB's run config vs squad_rusher on Port Vasel, Zone Control), turns the player's
#   gestures into RulesIntent submits, and redraws the existing p08 scenes from
#   match_snapshot.gd after every change. Engine events are forwarded to EventBus.
#
#   Deploying (core-rules section 2.2), nothing hover-only:
#   - tap a hand card (it is selected), then tap a lane; or drag the card onto a lane
#   - the Operator panel works the same way: place it (Round 1 / respawn) or Rotate it
#   - while something is selected or dragged every lane shows DEPLOY HERE or the reason it
#     can't take it (NEED 3 SUPPLY, ZONE FULL, WAIT ...); a refused play shows a toast with
#     the reason and changes nothing
#   - Flank Route style cards (CHOSEN_FRIENDLY): tap / drop on one of your units, then a lane
#   - long-press (touch) or right-click (mouse) a hand card, a unit or the Operator: inspector
#   - UNDO takes back the last play of this Deploy; READY submits (the enemy passes until the
#     p07 AI plugs in through `enemy_planner`), resolves the round and starts the next one
#   - Esc / right mouse (cancel) clears the selection; R (end_turn) is READY
#
#   The engine stays the authority: check_play() mirrors MatchState.submit()'s checks so the
#   lanes can show reasons before a play, and whatever submit() refuses is shown as is.
# Dependencies: MatchState, RulesIntent, RulesEvent, SideSetup, MatchHooks, ModeRules, CardDB,
#   EventBus, match_snapshot.gd, card_info.gd, match_screen.gd (parent).
# Author: UI/UX Agent (p09)
extends Node

## A play was sent to the engine: intent (RulesIntent Dictionary) and its {ok, reason}.
signal intent_submitted(intent: Dictionary, result: Dictionary)
## The round was resolved after READY (events of Reveal / Firefight / Score).
signal round_resolved(events: Array)

const MatchSnapshot: GDScript = preload("res://scripts/ui/match_snapshot.gd")
const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")
const MockMatchData: GDScript = preload("res://scripts/ui/mock_match_data.gd")
const PLAYER: int = MatchState.PLAYER
const ENEMY: int = MatchState.ENEMY
const ZONE_WORDS: PackedStringArray = ["Left", "Mid", "Right"]
const RANGE_WORDS: PackedStringArray = ["Close", "Mid", "Long"]
const KILLFEED_KEEP: int = 6

## Start a local test match when the scene loads (off: the screen shows its mock snapshot).
@export var autostart: bool = true
@export var seed_value: int = 20261103
@export var enemy_squad_id: StringName = &"squad_rusher"
@export var map_id: StringName = &"port_vasel"
@export var emit_to_event_bus: bool = true

## Called as enemy_planner.call(state) at the start of every Deploy, before the player acts
## (p07 AI: submit the enemy's plays here). Unset = the enemy passes.
var enemy_planner: Callable = Callable()

var state: MatchState = null
var map: MapData = null
## {kind: &"card", uid} or {kind: &"operator"}; empty = nothing selected.
var selection: Dictionary = {}
## Unit picked for a card that needs one (Flank Route), -1 = none yet.
var target_uid: int = -1
var killfeed: Array = []
## Every intent sent to the engine with its result (tests, playtest log).
var intent_log: Array[Dictionary] = []

var _screen: Control = null
var _cursor: int = 0
var _hover_zone: int = -1
var _dragging: bool = false


func _ready() -> void:
	_screen = get_parent() as Control
	if _screen == null:
		return
	if autostart:
		_screen.set(&"use_mock_data", false)
	if _screen.is_node_ready():
		_on_screen_ready()
	else:
		_screen.ready.connect(_on_screen_ready, CONNECT_ONE_SHOT)


func _on_screen_ready() -> void:
	# Deferred: a tap can rebuild the hand, which must not happen inside the chip's own input.
	var d: int = CONNECT_DEFERRED
	var hand: Control = _screen.get_hand()
	hand.card_tapped.connect(_on_card_tapped, d)
	hand.card_inspected.connect(_on_card_inspected, d)
	hand.card_drag_started.connect(_on_card_drag_started, d)
	hand.card_drag_moved.connect(_on_drag_moved, d)
	hand.card_drag_ended.connect(func(_uid: int, pos: Vector2) -> void: _on_drag_ended(pos), d)
	var op: Control = _screen.get_operator_panel()
	op.operator_tapped.connect(_on_operator_tapped, d)
	op.operator_inspected.connect(_on_operator_inspected, d)
	op.operator_drag_started.connect(_on_operator_drag_started, d)
	op.operator_drag_moved.connect(func(pos: Vector2) -> void: _on_drag_moved(-1, pos), d)
	op.operator_drag_ended.connect(_on_drag_ended, d)
	var board: Control = _screen.get_board()
	board.lane_tapped.connect(_on_lane_tapped, d)
	board.lane_long_pressed.connect(_on_lane_long_pressed, d)
	_screen.ready_pressed.connect(press_ready, d)
	_screen.undo_pressed.connect(undo, d)
	if autostart:
		start_local_match(seed_value)


func _unhandled_input(event: InputEvent) -> void:
	if state == null or _screen.get_inspector().is_open():
		return
	if event.is_action_pressed(&"cancel") and not selection.is_empty():
		get_viewport().set_input_as_handled()
		clear_selection()
	elif event.is_action_pressed(&"end_turn"):
		get_viewport().set_input_as_handled()
		press_ready()


# =============================================================================
# Match lifecycle
# =============================================================================

## Starts the local test match from CardDB data. False (and the mock screen) if data is missing.
func start_local_match(p_seed: int = seed_value) -> bool:
	var config: RunConfig = CardDB.get_run_config()
	map = CardDB.get_map(map_id)
	var squad: SquadData = CardDB.get_squad(enemy_squad_id)
	if config == null or map == null or squad == null or config.starter_deck.is_empty():
		push_warning("MatchController: CardDB data missing (run config / %s / %s); showing the mock board" % [map_id, enemy_squad_id])
		_screen.show_snapshot(MockMatchData.round_3_sample())
		return false
	var player: SideSetup = SideSetup.new()
	player.display_name = "You"
	player.deck.assign(config.starter_deck)
	player.primary = config.starter_primary
	player.secondary = config.starter_secondary
	player.lethal = config.starter_lethal
	player.tactical = config.starter_tactical
	player.killstreaks.assign(config.starter_killstreaks)
	var enemy: SideSetup = SideSetup.from_squad(squad)
	var hooks: MatchHooks = MatchHooks.new()
	hooks.mode_rules = ModeRules.create(DataEnums.GameMode.ZONE_CONTROL, config)
	state = MatchState.new(config, map, player, enemy, p_seed, hooks)
	_cursor = 0
	killfeed.clear()
	intent_log.clear()
	selection.clear()
	target_uid = -1
	state.start_match()
	_begin_deploy()
	return true


## READY: the player's plan is locked in, the round resolves and the next Deploy starts.
func press_ready() -> void:
	if state == null or state.phase != MatchState.Phase.DEPLOY or state.sides[PLAYER].ready:
		return
	clear_selection()
	state.set_ready(PLAYER)
	if not state.sides[ENEMY].ready:
		state.set_ready(ENEMY)  # the enemy passes (or already planned in enemy_planner)
	var resolved: Array[Dictionary] = state.resolve_round()
	_flush_events()
	round_resolved.emit(resolved)
	if state.phase == MatchState.Phase.ENDED:
		refresh()
		var result: String = {&"player": "You win the match.", &"enemy": "You lose the match."}.get(state.result, "Draw.")
		_screen.show_toast(result)
		return
	state.begin_round()
	_begin_deploy()


## Takes back the last play of this Deploy.
func undo() -> Dictionary:
	if state == null:
		return {"ok": false, "reason": "no match"}
	var s: RulesSide = state.sides[PLAYER]
	var label: String = MatchSnapshot.play_name(state, s, s.plays.back()) if not s.plays.is_empty() else ""
	var res: Dictionary = state.undo_last(PLAYER)
	if res["ok"]:
		clear_selection()
		_after_change()
		_screen.show_toast("Undid %s." % label)
	else:
		_screen.show_toast(_sentence(res["reason"]))
	return res


func _begin_deploy() -> void:
	if enemy_planner.is_valid():
		enemy_planner.call(state)
	_flush_events()
	if emit_to_event_bus:
		var dots: PackedInt32Array = state.red_dots(PLAYER)
		for z: int in dots.size():
			EventBus.intel_updated.emit(MapData.ZONE_IDS[z], dots[z])
	refresh()
	var s: RulesSide = state.sides[PLAYER]
	if s.operator_can_deploy:
		_screen.show_toast("Round %d: tap your Operator, then a zone." % state.round_number)
	else:
		_screen.show_toast("Round %d: Deploy." % state.round_number)


func refresh() -> void:
	if state == null:
		return
	_screen.show_snapshot(MatchSnapshot.build(state, map, PLAYER, killfeed))
	_show_selection()


func _after_change() -> void:
	_flush_events()
	refresh()


# =============================================================================
# Selection and plays
# =============================================================================

func select_card(uid: int) -> void:
	selection = {"kind": &"card", "uid": uid}
	target_uid = -1
	_show_selection()
	var rc: RulesCard = state.sides[PLAYER].find_in_hand(uid) if state != null else null
	if rc == null:
		return
	if rc.card.cost > state.sides[PLAYER].supply:
		_screen.show_toast(_supply_reason(rc.card))
	elif _unit_target_kind() == &"friendly":
		_screen.show_toast("Pick one of your units to move.")
	elif _unit_target_kind() == &"enemy":
		_screen.show_toast("Pick an enemy unit.")


func select_operator() -> void:
	selection = {"kind": &"operator"}
	target_uid = -1
	_show_selection()


func clear_selection() -> void:
	selection = {}
	target_uid = -1
	_hover_zone = -1
	_show_selection()


## Tries the selected card / Operator in zone z. Returns the engine's {ok, reason} (or the
## presenter's refusal, which never reaches the engine).
func play_at(zone: int) -> Dictionary:
	var check: Dictionary = check_play(zone)
	if not check["ok"]:
		_screen.show_toast(check["reason"])
		_show_selection()
		return check
	var intent: Dictionary = _intent_for(zone)
	var res: Dictionary = state.submit(PLAYER, intent)
	intent_log.append({"intent": intent, "result": res})
	intent_submitted.emit(intent, res)
	if res["ok"]:
		clear_selection()
		_after_change()
	else:
		_screen.show_toast(_sentence(res["reason"]))
		_show_selection()
	return res


## Can the current selection go to zone z? {ok, badge (short, for the lane), reason (sentence)}.
## Mirrors MatchState.submit() (Supply, zone capacity, phase, Operator rules, targets).
func check_play(zone: int) -> Dictionary:
	if state == null:
		return _no("", "No match is running.")
	var s: RulesSide = state.sides[PLAYER]
	if state.phase != MatchState.Phase.DEPLOY:
		return _no("WAIT", "Wrong phase: you can only play cards during Deploy.")
	if s.ready:
		return _no("READY", "You already pressed READY.")
	if not state.is_zone(zone):
		return _no("", "Drop it on a zone.")
	match selection.get("kind", &""):
		&"card":
			return _check_card(zone)
		&"operator":
			return _check_operator(zone)
	return _no("", "Select a card first.")


func _check_card(zone: int) -> Dictionary:
	var s: RulesSide = state.sides[PLAYER]
	var rc: RulesCard = s.find_in_hand(int(selection["uid"]))
	if rc == null:
		return _no("", "That card is not in your hand any more.")
	var card: CardData = rc.card
	if card.cost > s.supply:
		return _no("NEED %d SUPPLY" % card.cost, _supply_reason(card))
	match card.card_type:
		DataEnums.CardType.UNIT:
			if state.projected_occupancy(PLAYER, zone) >= state.config.zone_capacity:
				return _no("ZONE FULL", "Zone full: %s already has %d units." % [ZONE_WORDS[zone], state.config.zone_capacity])
			return _yes("DEPLOY HERE")
		DataEnums.CardType.EQUIPMENT:
			return _yes("PLACE HERE")
	var kind: StringName = _unit_target_kind()
	if kind == &"friendly":
		if target_uid < 0:
			return _no("PICK A UNIT", "Pick one of your units first.")
		var from: int = _friendly_zone(target_uid)
		if from == zone:
			return _no("ALREADY HERE", "That unit is already in this zone.")
		if not state.are_adjacent(from, zone):
			return _no("NOT ADJACENT", "Move only to an adjacent zone.")
		if state.projected_occupancy(PLAYER, zone) >= state.config.zone_capacity:
			return _no("ZONE FULL", "Zone full: %s already has %d units." % [ZONE_WORDS[zone], state.config.zone_capacity])
		return _yes("MOVE HERE")
	if kind == &"enemy":
		if target_uid < 0:
			return _no("PICK AN ENEMY", "Pick an enemy unit first.")
		return _yes("TARGET") if _enemy_zone(target_uid) == zone else _no("", "Pick an enemy unit.")
	var op_zone: int = state.projected_operator_zone(PLAYER)
	for e: EffectData in card.effects:
		if e == null:
			continue
		match e.zone_scope:
			DataEnums.ZoneScope.OPERATOR_OR_ADJACENT:
				if op_zone == MatchState.NO_ZONE:
					return _no("NO OPERATOR", "Your Operator is not on the board.")
				if absi(zone - op_zone) > 1:
					return _no("TOO FAR", "Pick your Operator's zone or one next to it.")
			DataEnums.ZoneScope.OPERATOR_ZONE:
				if op_zone == MatchState.NO_ZONE:
					return _no("NO OPERATOR", "Your Operator is not on the board.")
	return _yes("TARGET ZONE" if card.requires_zone_choice() else "PLAY")


func _check_operator(zone: int) -> Dictionary:
	var s: RulesSide = state.sides[PLAYER]
	if s.operator_unit == null:
		return _no("", "You have no Operator.")
	var full: bool = state.projected_occupancy(PLAYER, zone) >= state.config.zone_capacity
	if s.operator_can_deploy and not _has_play(&"place"):
		if full:
			return _no("ZONE FULL", "Zone full: %s already has %d units." % [ZONE_WORDS[zone], state.config.zone_capacity])
		return _yes("PLACE HERE")
	var from: int = state.projected_operator_zone(PLAYER)
	if from == MatchState.NO_ZONE:
		return _no("", "Your Operator can't be placed now.")
	var allowed: int = s.setup.primary.rotations_per_round if s.setup.primary != null else 1
	if s.rotations_used >= allowed:
		return _no("NO ROTATION", "No Rotations left this round.")
	if zone == from:
		return _no("HERE NOW", "Your Operator is already here.")
	if not state.are_adjacent(from, zone):
		return _no("NOT ADJACENT", "Rotate only to an adjacent zone.")
	if full:
		return _no("ZONE FULL", "Zone full: %s already has %d units." % [ZONE_WORDS[zone], state.config.zone_capacity])
	return _yes("ROTATE HERE")


func _intent_for(zone: int) -> Dictionary:
	if selection.get("kind") == &"operator":
		var s: RulesSide = state.sides[PLAYER]
		if s.operator_can_deploy and not _has_play(&"place"):
			return RulesIntent.place_operator(zone)
		return RulesIntent.rotate(zone)
	var uid: int = int(selection["uid"])
	var card: CardData = state.sides[PLAYER].find_in_hand(uid).card
	match _unit_target_kind():
		&"friendly":
			return RulesIntent.play_card(uid, zone, target_uid, zone)
		&"enemy":
			return RulesIntent.play_card(uid, zone, target_uid)
	if card.card_type != DataEnums.CardType.TACTIC or card.requires_zone_choice():
		return RulesIntent.play_card(uid, zone)
	return RulesIntent.play_card(uid)


## &"friendly" / &"enemy" when the selected card needs a chosen unit, else &"".
func _unit_target_kind() -> StringName:
	if state == null or selection.get("kind") != &"card":
		return &""
	var rc: RulesCard = state.sides[PLAYER].find_in_hand(int(selection["uid"]))
	if rc == null:
		return &""
	for e: EffectData in rc.card.effects:
		if e == null:
			continue
		if e.target == DataEnums.Target.CHOSEN_FRIENDLY:
			return &"friendly"
		if e.target == DataEnums.Target.CHOSEN_ENEMY:
			return &"enemy"
	return &""


## Units that can be picked for the selected card (board units + this Deploy's queued arrivals).
func _target_candidates(kind: StringName) -> Array:
	var out: Array = []
	var side: RulesSide = state.sides[PLAYER if kind == &"friendly" else ENEMY]
	for u: RulesUnit in side.units_on_board():
		out.append(u.uid)
	if kind == &"friendly":
		for p: Dictionary in side.plays:
			if p["kind"] == &"unit":
				out.append((p["card"] as RulesCard).uid)
	return out


func _friendly_zone(uid: int) -> int:
	var u: RulesUnit = state.sides[PLAYER].find_unit(uid)
	if u != null:
		return u.zone
	for p: Dictionary in state.sides[PLAYER].plays:
		if p["kind"] == &"unit" and (p["card"] as RulesCard).uid == uid:
			return int(p["zone"])
	return MatchState.NO_ZONE


func _enemy_zone(uid: int) -> int:
	var u: RulesUnit = state.sides[ENEMY].find_unit(uid)
	return u.zone if u != null else MatchState.NO_ZONE


func _has_play(kind: StringName) -> bool:
	for p: Dictionary in state.sides[PLAYER].plays:
		if p["kind"] == kind:
			return true
	return false


## Lane frames / badges, the selected chip and the pickable units for the current selection.
func _show_selection() -> void:
	if _screen == null or not _screen.is_node_ready():
		return
	var board: Control = _screen.get_board()
	_screen.get_hand().set_selected(int(selection.get("uid", -1)) if selection.get("kind") == &"card" else -1)
	_screen.get_operator_panel().set_selected(selection.get("kind") == &"operator")
	if selection.is_empty() or state == null:
		board.show_targets([])
		board.set_unit_targets([])
		return
	var kind: StringName = _unit_target_kind()
	if kind != &"" and target_uid < 0:
		board.show_targets([])
		board.set_unit_targets(_target_candidates(kind))
		return
	var targets: Array = []
	for z: int in MatchState.ZONE_COUNT:
		var c: Dictionary = check_play(z)
		var lane_state: StringName = &"invalid"
		if c["ok"]:
			lane_state = &"hover" if z == _hover_zone else &"valid"
		targets.append({"state": lane_state, "text": c["badge"]})
	board.show_targets(targets)
	board.set_unit_targets([target_uid] if target_uid >= 0 else [])


# =============================================================================
# Gesture handlers (connected deferred)
# =============================================================================

func _on_card_tapped(uid: int) -> void:
	if state == null:
		return
	if selection.get("kind") == &"card" and int(selection["uid"]) == uid:
		clear_selection()
	else:
		select_card(uid)


func _on_operator_tapped() -> void:
	if state == null:
		return
	if selection.get("kind") == &"operator":
		clear_selection()
	else:
		select_operator()


func _on_lane_tapped(zone: int, slot_side: StringName, uid: int) -> void:
	if state == null or selection.is_empty():
		return
	_pick_or_play(zone, slot_side, uid)


## A tap or drop on lane `zone` (on the unit uid of slot_side, if any).
func _pick_or_play(zone: int, slot_side: StringName, uid: int) -> void:
	var kind: StringName = _unit_target_kind()
	if kind != &"":
		var wanted: StringName = &"player" if kind == &"friendly" else &"enemy"
		var can_pick: bool = slot_side == wanted and _target_candidates(kind).has(uid)
		if target_uid < 0 or (can_pick and not check_play(zone)["ok"]):
			if not can_pick:
				_screen.show_toast("Pick one of your units first." if kind == &"friendly" else "Pick an enemy unit first.")
				return
			target_uid = uid
			if kind == &"enemy":
				play_at(_enemy_zone(uid))
				return
			_show_selection()
			_screen.show_toast("Now tap an adjacent zone.")
			return
	play_at(zone)


func _on_card_drag_started(uid: int, pos: Vector2) -> void:
	if state == null:
		return
	if not (selection.get("kind") == &"card" and int(selection["uid"]) == uid):
		select_card(uid)
	_dragging = true
	var hand: Control = _screen.get_hand()
	var chip: Control = hand.get_card(uid)
	if chip != null:
		_screen.begin_drag_ghost(chip, pos)
	hand.set_dragging(uid)


func _on_operator_drag_started(pos: Vector2) -> void:
	if state == null or state.sides[PLAYER].operator_unit == null:
		return
	select_operator()
	_dragging = true
	# A small chip with the Operator's name, not a copy of the whole panel.
	var chip: PanelContainer = PanelContainer.new()
	chip.theme_type_variation = &"HandCardSelected"
	var label: Label = Label.new()
	label.theme_type_variation = &"UnitName"
	label.text = MatchSnapshot.unit_name(state.sides[PLAYER].operator_unit, state.sides[PLAYER])
	chip.add_child(label)
	_screen.begin_drag_ghost(chip, pos)
	chip.free()


func _on_drag_moved(_uid: int, pos: Vector2) -> void:
	if not _dragging:
		return
	_screen.move_drag_ghost(pos)
	var z: int = _screen.get_board().lane_index_at(pos)
	if z != _hover_zone:
		_hover_zone = z
		_show_selection()


func _on_drag_ended(pos: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	_hover_zone = -1
	_screen.end_drag_ghost()
	_screen.get_hand().set_dragging(-1)
	var board: Control = _screen.get_board()
	var zone: int = board.lane_index_at(pos)
	if zone < 0:
		clear_selection()  # dropped outside the board: cancel
		return
	var slot: Node = board.get_lanes()[zone].slot_at(pos)
	var slot_side: StringName = &""
	var uid: int = -1
	if slot != null and slot.kind == slot.Kind.UNIT:
		slot_side = slot.side
		uid = slot.slot_uid
	_pick_or_play(zone, slot_side, uid)


# =============================================================================
# Inspector
# =============================================================================

func _on_card_inspected(uid: int) -> void:
	if state == null:
		return
	var s: RulesSide = state.sides[PLAYER]
	var rc: RulesCard = s.find_in_hand(uid)
	if rc == null:
		return
	var status: String = "Costs %d Supply, you have %d." % [rc.card.cost, s.supply]
	if rc.card.cost > s.supply:
		status += " Not enough to play it now."
	open_card_inspector(rc.card, "friend", _join(status, _range_hint(rc.card)))


func _on_operator_inspected() -> void:
	if state == null or state.sides[PLAYER].operator_unit == null:
		return
	_open_operator(PLAYER)


func _on_lane_long_pressed(zone: int, slot_side: StringName, uid: int) -> void:
	if state == null or uid < 0:
		return
	var side: int = PLAYER if slot_side == &"player" else ENEMY
	var s: RulesSide = state.sides[side]
	if s.operator_unit != null and s.operator_unit.uid == uid:
		_open_operator(side)
		return
	var u: RulesUnit = s.find_unit(uid)
	if u != null and u.card != null:
		var status: String = "In %s (%s): FP %d, Armor %d/%d." % [ZONE_WORDS[zone], RANGE_WORDS[state.zone_ranges[zone]],
				state.firepower_of(u), u.armor, u.max_armor(state.round_number)]
		open_card_inspector(u.card, "friend" if side == PLAYER else "enemy", status)
		return
	for p: Dictionary in s.plays:
		if p["kind"] == &"unit" and (p["card"] as RulesCard).uid == uid:
			open_card_inspector((p["card"] as RulesCard).card, "friend", "Queued for %s. It arrives at Reveal." % ZONE_WORDS[zone])
			return


func open_card_inspector(card: CardData, side: String, status: String) -> void:
	var type_text: String = String(CardInfo.TYPE_WORDS.get(card.card_type, "card"))
	if card.is_unit() and CardInfo.CLASS_WORDS.get(card.weapon_class, "") != "":
		type_text += " · " + String(CardInfo.CLASS_WORDS[card.weapon_class])
	if card.is_unit():
		type_text += " · FP %d · Armor %d" % [card.firepower, card.armor]
	type_text += " · cost %d" % card.cost
	_screen.get_inspector().open({
		"view": CardInfo.view_dict(card, side), "title": card.display_name, "type": type_text,
		"text": card.text, "keywords": CardInfo.keywords(card), "status": status,
	})


func _open_operator(side: int) -> void:
	var s: RulesSide = state.sides[side]
	var op: RulesUnit = s.operator_unit
	var title: String = MatchSnapshot.unit_name(op, s)
	var where: String = "Off the board."
	if op.is_on_board():
		where = "In %s: FP %d, Armor %d/%d." % [ZONE_WORDS[op.zone], state.firepower_of(op), op.armor, op.max_armor(state.round_number)]
	elif side == PLAYER and s.operator_can_deploy:
		where = "Off the board: tap it, then a zone, to place it."
	var view: Dictionary = CardInfo.operator_view_dict(op, title)
	view["side"] = "friend" if side == PLAYER else "enemy"
	_screen.get_inspector().open({
		"view": view, "title": title, "type": "operator · %s" % String(CardInfo.CLASS_WORDS.get(op.weapon_class, "")),
		"text": String(view["text"]), "keywords": CardInfo.operator_keywords(op), "status": where,
	})


## "Best in Close (Left): +2 FP" for units with a range bonus on this map.
func _range_hint(card: CardData) -> String:
	if not card.is_unit():
		return ""
	var best: int = -1
	var best_bonus: int = 0
	for z: int in MatchState.ZONE_COUNT:
		var b: int = state.config.range_bonus(card.weapon_class, state.zone_ranges[z])
		if b > best_bonus:
			best_bonus = b
			best = z
	if best < 0:
		return ""
	return "Best in %s (%s): +%d FP." % [ZONE_WORDS[best], RANGE_WORDS[state.zone_ranges[best]], best_bonus]


# =============================================================================
# Events -> EventBus, killfeed
# =============================================================================

func _flush_events() -> void:
	if state == null:
		return
	while _cursor < state.events.size():
		var e: Dictionary = state.events[_cursor]
		_cursor += 1
		if e.has("private_to") and e["private_to"] != MatchState.SIDE_NAMES[PLAYER]:
			continue
		if e["type"] == RulesEvent.UNIT_ELIMINATED:
			_add_killfeed(e)
		if emit_to_event_bus:
			_emit(e)


func _add_killfeed(e: Dictionary) -> void:
	var by_side: StringName = e.get("by_side", &"")
	var killer: String = _name_of(int(e.get("by_uid", -1))).to_upper()
	var victim: String = _name_of(int(e.get("victim_uid", -1))).to_upper()
	var text: String = "%s  >  %s" % [killer, victim] if killer != "" else "%s DOWN" % victim
	killfeed.push_front({"text": text, "side": by_side if by_side != &"" else &"enemy"})
	if killfeed.size() > KILLFEED_KEEP:
		killfeed.resize(KILLFEED_KEEP)


## Display name of any uid in the match (board, Operator, discard, hand, deck), or "".
func _name_of(uid: int) -> String:
	if uid < 0:
		return ""
	for s: RulesSide in state.sides:
		if s.operator_unit != null and s.operator_unit.uid == uid:
			return MatchSnapshot.unit_name(s.operator_unit, s)
		var u: RulesUnit = s.find_unit(uid)
		if u != null:
			return MatchSnapshot.unit_name(u, s)
		for pile: Array in [s.discard, s.hand, s.deck]:
			for c: RulesCard in pile:
				if c.uid == uid:
					return c.card.display_name
	return ""


func _emit(e: Dictionary) -> void:
	var t: StringName = e["type"]
	var r: int = int(e.get("round", 0))
	match t:
		RulesEvent.MATCH_STARTED:
			var mode: StringName = state.hooks.mode_rules.mode_name if state.hooks.mode_rules != null else &""
			EventBus.match_started.emit(mode, state.map_id, 0)
		RulesEvent.ROUND_STARTED:
			EventBus.round_started.emit(r)
		RulesEvent.PHASE_CHANGED:
			var phase: StringName = StringName(e.get("phase", ""))
			if phase in [&"briefing", &"deploy", &"reveal", &"firefight", &"score"]:
				EventBus.phase_changed.emit(phase)
		RulesEvent.INITIATIVE:
			EventBus.initiative_changed.emit(StringName(e.get("side", &"")))
		RulesEvent.CARD_DRAWN:
			EventBus.card_drawn.emit(StringName(e.get("card_id", &"")))
		RulesEvent.CARD_PLAYED:
			EventBus.card_deployed.emit(StringName(e.get("side", &"")), StringName(e.get("card_id", &"")), StringName(e.get("zone", &"")))
		RulesEvent.CARD_REVEALED:
			EventBus.card_revealed.emit(StringName(e.get("side", &"")), StringName(e.get("card_id", &"")), StringName(e.get("zone", &"")))
		RulesEvent.SHOT_FIRED:
			EventBus.shot_fired.emit(int(e.get("shooter_uid", -1)), int(e.get("target_uid", -1)), StringName(e.get("zone", &"")))
		RulesEvent.DAMAGE_DEALT:
			EventBus.damage_dealt.emit(int(e.get("target_uid", -1)), int(e.get("amount", 0)), int(e.get("remaining", 0)))
		RulesEvent.UNIT_ELIMINATED:
			EventBus.unit_eliminated.emit(int(e.get("victim_uid", -1)), int(e.get("by_uid", -1)),
					StringName(e.get("zone", &"")), bool(e.get("by_killstreak", false)))
		RulesEvent.OPERATOR_DOWN:
			EventBus.operator_down.emit(StringName(e.get("side", &"")), r)
		RulesEvent.STREAK_CHANGED:
			if e.get("side", &"") == MatchState.SIDE_NAMES[PLAYER]:
				EventBus.streak_changed.emit(int(e.get("streak", 0)))
		RulesEvent.KILLSTREAK_EARNED:
			if e.get("side", &"") == MatchState.SIDE_NAMES[PLAYER]:
				EventBus.killstreak_earned.emit(StringName(e.get("item_id", &"")), r)
		RulesEvent.MODE_SCORED:
			EventBus.score_changed.emit(int(e.get("player_score", 0)), int(e.get("enemy_score", 0)))
		RulesEvent.ROUND_ENDED:
			EventBus.round_ended.emit(r, int(e.get("player_score", 0)), int(e.get("enemy_score", 0)))
		RulesEvent.MATCH_ENDED:
			var result: StringName = {&"player": &"win", &"enemy": &"loss"}.get(state.result, &"draw")
			EventBus.match_ended.emit(result, state.round_number, 0.0)


# =============================================================================
# Helpers
# =============================================================================

func _supply_reason(card: CardData) -> String:
	return "Not enough Supply: %s costs %d, you have %d." % [card.display_name, card.cost, state.sides[PLAYER].supply]


static func _yes(badge: String) -> Dictionary:
	return {"ok": true, "badge": badge, "reason": ""}


static func _no(badge: String, reason: String) -> Dictionary:
	return {"ok": false, "badge": badge, "reason": reason}


static func _sentence(reason: String) -> String:
	if reason.is_empty():
		return reason
	var out: String = reason.left(1).to_upper() + reason.substr(1)
	return out if out.ends_with(".") else out + "."


static func _join(a: String, b: String) -> String:
	return a if b.is_empty() else "%s %s" % [a, b]

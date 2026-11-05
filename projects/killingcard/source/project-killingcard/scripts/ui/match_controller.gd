# match_controller.gd
# Purpose: Thin presenter for the match screen (p09, f02). Child node "MatchController" of
#   scenes/Match.tscn. It owns the MatchState of a local test match (starter deck from
#   CardDB's run config vs squad_rusher on Port Vasel, Zone Control), turns the player's
#   gestures into RulesIntent submits, and redraws the existing p08 scenes from
#   match_snapshot.gd after every change. Engine events are forwarded to EventBus.
#
#   Deploying (core-rules section 2.2), nothing hover-only:
#   - tap a hand card (it is selected), then tap a lane; or drag the card onto a lane
#   - the Operator panel works the same way: place it (Round 1 / respawn) or Rotate it
#   - while something is selected or dragged every column shows PLAY HERE or the reason it
#     can't take it (NEED 3 SUPPLY, COLUMN FULL, WAIT ...); a refused play shows a toast with
#     the reason and changes nothing
#   - Flank Route style cards (CHOSEN_FRIENDLY): tap / drop on one of your units, then a lane
#   - f02 loadout: tap Sidearm / Frag / Flashbang or a killstreak in the tray, then tap what it
#     needs (an enemy unit for the Sidearm, a lane for Frag / Flashbang / Mortar / Sentry);
#     items that need nothing (Recon Drone, Attack Helo) are queued at once. Blocked buttons
#     are disabled and a tap on them toasts why (cooldown, used, not earned, no Operator)
#   - long-press (touch) or right-click (mouse) a hand card, a unit or the Operator: inspector
#   - UNDO takes back the last play of this Deploy; READY locks the plan in, the round resolves
#     and FeedbackDirector (p14) plays it over the pre-resolve board (taps / F fast-forward)
#   - Round 1 starts with the mulligan panel (choose cards to put back, then confirm)
#   - Esc / right mouse (cancel) clears the selection; R (end_turn) is READY
#
#   The engine is the authority (f02): lanes, buttons and refusals come from
#   MatchState.can_submit() / check_use() / legal_targets() and their reason codes, worded by
#   play_text.gd. The enemy is the p07 AI (AiPlayer for the squad, seeded by the match seed),
#   plugged in as `enemy_planner`; it commits before the player's Deploy.
#   p16: gameplay signals go to EventBus (match / round start and end, round_summary,
#   card_deployed, killstreak_earned / _used, ability_used, eliminations, Operator downs).
#
#   f03, the run match (SceneRouter "Run match hand-off", p11): on load the controller asks
#   SceneRouter.take_pending_match(). A MatchState there (made by RunState.create_match() for
#   RunMap's DEPLOY) is played instead of the local test match: map = the run slot's map, the
#   AI plays the slot's squad, match_index = the run's. When the match ends the result banner
#   (MatchEndBanner: VICTORY / DEFEAT / DRAW, score, reason) waits for CONTINUE, which calls
#   SceneRouter.finish_run_match(state) once (it records the result and opens AfterAction).
#   A local match's banner offers BACK TO TITLE instead. MENU opens the pause sheet
#   (PauseMenu): RESUME, FAST ANIMATIONS (Settings), FORFEIT MATCH (asks first; the match ends
#   as a loss with reason &"forfeit" and goes through the same banner / finish path) and
#   QUIT TO TITLE (the run stays saved; Continue opens RunMap and DEPLOY replays this match
#   from the same seed). The tutorial (p15, `tutorial` set on the subclass) keeps its own
#   end card and gets neither the run match nor the banner / pause sheet.
# Dependencies: MatchState, RulesIntent, RulesEvent, SideSetup, MatchHooks, ModeRules, AiPlayer,
#   CardDB, EventBus, match_snapshot.gd, play_text.gd, card_info.gd, match_screen.gd (parent).
# Author: UI/UX Agent (p09), Mechanics Developer Agent (f02)
extends Node

## A play was sent to the engine: intent (RulesIntent Dictionary) and its {ok, code, reason, data}.
signal intent_submitted(intent: Dictionary, result: Dictionary)
## The round was resolved after READY (events of Reveal / Firefight / Score).
signal round_resolved(events: Array)
## The resolved round finished playing (feedback done) and the next Deploy is up (or the match ended).
signal round_presented
## The Round 1 mulligan was decided (put_back empty = kept).
signal mulligan_done(put_back: Array)

const MatchSnapshot: GDScript = preload("res://scripts/ui/match_snapshot.gd")
const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")
const PlayText: GDScript = preload("res://scripts/ui/play_text.gd")
const MockMatchData: GDScript = preload("res://scripts/ui/mock_match_data.gd")
const PLAYER: int = MatchState.PLAYER
const ENEMY: int = MatchState.ENEMY
const ZONE_WORDS: PackedStringArray = ["column A", "column B", "column C"]
const RANGE_WORDS: PackedStringArray = ["Close", "Mid", "Long"]
const KILLFEED_KEEP: int = 6
const SCENE_TITLE: String = "res://scenes/Title.tscn"
## outcome.reason of a forfeited match (MatchEndBanner / AfterAction wording).
const REASON_FORFEIT: StringName = &"forfeit"

## Start a local test match when the scene loads (off: the screen shows its mock snapshot).
@export var autostart: bool = true
@export var seed_value: int = 20261103
@export var enemy_squad_id: StringName = &"squad_rusher"
@export var map_id: StringName = &"port_vasel"
@export var emit_to_event_bus: bool = true
## The enemy is played by the p07 AI (AiPlayer for the squad). Off: it passes.
@export var enemy_ai: bool = true
## Round 1 opens the mulligan panel.
@export var offer_mulligan: bool = true
## Index sent with EventBus.match_started (the run flow sets it).
@export var match_index: int = 0

## Called as enemy_planner.call(state) at the start of every Deploy, before the player acts.
## Default (enemy_ai on): AiPlayer.for_squad(squad).take_turn(state, ENEMY). Set your own to replace it.
var enemy_planner: Callable = Callable()
## The default AI driver (null when enemy_planner was set from outside or enemy_ai is off).
var enemy_ai_player: AiPlayer = null

var state: MatchState = null
var map: MapData = null
## {kind: &"card", uid}, {kind: &"operator"} or {kind: &"item", id}; empty = nothing selected.
var selection: Dictionary = {}
## Unit picked for a play that needs one (Flank Route, Sidearm), -1 = none yet.
var target_uid: int = -1
var killfeed: Array = []
## Every intent sent to the engine with its result (tests, playtest log).
var intent_log: Array[Dictionary] = []

var _screen: Control = null
var _cursor: int = 0
var _hover_zone: int = -1
var _dragging: bool = false
var _busy: bool = false
var _default_planner: bool = false
var _match_started_ms: int = 0
## f03: true while playing the run match handed over by SceneRouter.take_pending_match().
var is_run_match: bool = false
## The player forfeited this match (pause sheet).
var forfeited: bool = false
## The result banner was shown for this match / its button was acted on (finish called once).
var _end_shown: bool = false
var _finished: bool = false


func _ready() -> void:
	_read_mastery_param()
	_screen = get_parent() as Control
	if _screen == null:
		return
	if autostart:
		_screen.set(&"use_mock_data", false)
	if _screen.is_node_ready():
		_on_screen_ready()
	else:
		_screen.ready.connect(_on_screen_ready, CONNECT_ONE_SHOT)


## Pitch dev toggle (kc-cod2): ?mastery=N (1-4) on the web build previews that Operator mastery tier.
static func _read_mastery_param() -> void:
	if not OS.has_feature("web"):
		return
	var q: String = String(JavaScriptBridge.eval("window.location.search || ''", true))
	for part: String in q.trim_prefix("?").split("&"):
		if part.begins_with("mastery=") and part.substr(8).is_valid_int():
			BannerArtDB.operator_tier_override = clampi(int(part.substr(8)), 0, 4)


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
	op.ability_pressed.connect(_on_item_pressed, d)
	op.killstreak_pressed.connect(_on_item_pressed, d)
	var board: Control = _screen.get_board()
	board.lane_tapped.connect(_on_lane_tapped, d)
	board.lane_long_pressed.connect(_on_lane_long_pressed, d)
	_screen.ready_pressed.connect(press_ready, d)
	if _screen.has_signal(&"rail_inspected"):
		_screen.rail_inspected.connect(_on_rail_inspected, d)
	_screen.undo_pressed.connect(undo, d)
	if _screen.has_method(&"get_mulligan_panel"):
		_screen.get_mulligan_panel().confirmed.connect(_on_mulligan_confirmed, d)
	if not _is_tutorial():
		_screen.menu_pressed.connect(open_pause_menu, d)
		var banner: Control = _end_banner()
		if banner != null:
			banner.continue_pressed.connect(continue_after_match, d)
		var pause: Control = _pause_menu()
		if pause != null:
			pause.resume_pressed.connect(close_pause_menu, d)
			pause.fast_animations_toggled.connect(_on_fast_animations_toggled, d)
			pause.forfeit_confirmed.connect(forfeit, d)
			pause.quit_pressed.connect(quit_to_title, d)
	if autostart:
		var run_match: MatchState = _take_run_match()
		if run_match != null:
			start_run_match(run_match)
		else:
			start_local_match(seed_value)


func _unhandled_input(event: InputEvent) -> void:
	if state == null:
		return
	if is_pause_menu_open():
		if event.is_action_pressed(&"cancel"):
			get_viewport().set_input_as_handled()
			_pause_menu().back()
		return
	if is_end_banner_open():
		return
	if _busy:
		# While the round plays: F, or any tap / click, fast-forwards it.
		if event.is_action_pressed(&"fast_forward") or event.is_action_pressed(&"confirm") \
				or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
			get_viewport().set_input_as_handled()
			skip_feedback()
		return
	if _screen.get_inspector().is_open():
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).keycode == KEY_M and (event as InputEventKey).ctrl_pressed \
			and BannerArtDB.has_licensed():
		# Pitch dev toggle: cycle the Operator mastery tier (Base -> Forged -> Priceless -> Interstellar).
		get_viewport().set_input_as_handled()
		BannerArtDB.operator_tier_override = (maxi(1, BannerArtDB.operator_tier_override) % 4) + 1
		refresh()
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
	is_run_match = false
	_play(MatchState.new(config, map, player, enemy, p_seed, hooks), squad)
	return true


## f03: plays the run match m (from SceneRouter.take_pending_match(), not started yet) on the
## run slot's map against its squad. False if m is null.
func start_run_match(m: MatchState) -> bool:
	if m == null:
		return false
	var slot: RunMatchData = null
	var rs: Node = get_node_or_null(^"/root/RunState")
	if rs != null and rs.run != null:
		match_index = rs.run.match_index
		var cfg: RunConfig = rs.run.config
		if cfg != null and match_index >= 0 and match_index < cfg.matches.size():
			slot = cfg.matches[match_index]
	map = slot.map if slot != null and slot.map != null else CardDB.get_map(m.map_id)
	is_run_match = true
	_play(m, slot.squad if slot != null else null)
	return true


## Wires the screen to m (not started), starts it and opens the first Deploy.
func _play(m: MatchState, squad: SquadData) -> void:
	state = m
	# The enemy AI (p07): deterministic, its only randomness is seeded from the match seed.
	if enemy_ai and (_default_planner or not enemy_planner.is_valid()):
		enemy_ai_player = AiPlayer.for_squad(squad) if squad != null else null
		enemy_planner = _ai_turn if enemy_ai_player != null else Callable()
		_default_planner = true
	_cursor = 0
	killfeed.clear()
	intent_log.clear()
	selection.clear()
	target_uid = -1
	_busy = false
	forfeited = false
	_end_shown = false
	_finished = false
	_match_started_ms = Time.get_ticks_msec()
	if PitchDecks.active():
		for s: RulesSide in state.sides:
			s.setup.deck = PitchDecks.apply(s.setup.deck)
	_assign_copy_arts(state)
	state.start_match()
	_begin_deploy()


## kc-cod2: per-copy banner art (display only). With the private licensed art present, every copy
## of a chassis, on both sides, wears a different banner; without it deck_arts stays empty.
static func _assign_copy_arts(m: MatchState) -> void:
	var decks: Array = []
	for s: RulesSide in m.sides:
		var ids: Array = []
		for card: CardData in s.setup.deck:
			ids.append(card.id if card != null else &"")
		decks.append(ids)
	var arts: Array = BannerArtDB.copy_arts(decks)
	for i: int in m.sides.size():
		var setup: SideSetup = m.sides[i].setup
		setup.deck_arts.clear()
		if BannerArtDB.has_licensed():
			setup.deck_arts.assign(arts[i])


func _ai_turn(st: MatchState) -> void:
	enemy_ai_player.take_turn(st, ENEMY)


## True while FeedbackDirector plays a resolved round (input only fast-forwards it).
func is_busy() -> bool:
	return _busy


## Fast-forwards the round's feedback (F key, or a tap while it plays).
func skip_feedback() -> void:
	var fx: Control = _fx()
	if fx != null and fx.is_playing():
		fx.skip()


## READY: the player's plan is locked in, the round resolves, FeedbackDirector plays it over the
## pre-resolve board (switching to the post-Reveal board when the firefight starts), then the
## next Deploy starts. Returns after the feedback has played.
func press_ready() -> void:
	if state == null or _busy or state.phase != MatchState.Phase.DEPLOY or state.sides[PLAYER].ready \
			or is_mulligan_open():
		return
	clear_selection()
	var me: RulesSide = state.sides[PLAYER]
	var supply_unspent: int = me.supply
	var hand_size: int = me.hand.size()
	state.set_ready(PLAYER)
	if not state.sides[ENEMY].ready:
		state.set_ready(ENEMY)  # the enemy passes (or already planned in enemy_planner)
	# The pre-resolve board (deploy closed) stays up while the Reveal plays.
	var before: Dictionary = MatchSnapshot.build(state, map, PLAYER, killfeed)
	before["phase"] = "REVEAL"
	_screen.show_snapshot(before)
	_show_selection()
	var fx: Control = _fx()
	if fx != null and fx.locator != null:
		fx.unit_names = _unit_names()
	# MatchState.resolve_round(), split so the board can show the units that arrived at Reveal
	# when the firefight starts.
	var start: int = state.events.size()
	state.reveal()
	var after_reveal: Dictionary = MatchSnapshot.build(state, map, PLAYER, killfeed)
	after_reveal["phase"] = "FIREFIGHT"
	state.firefight()
	state.score()
	var resolved: Array[Dictionary] = state.events_since(start)
	if emit_to_event_bus:
		EventBus.round_summary.emit(state.round_number, supply_unspent, hand_size)
	_flush_events()
	round_resolved.emit(resolved)
	if fx != null:
		_busy = true
		var on_event: Callable = func(ev: Dictionary) -> void:
			if ev.get("type") == RulesEvent.PHASE_CHANGED and StringName(ev.get("phase", "")) == &"firefight":
				_screen.show_snapshot(after_reveal)
			_board_callout(ev)
		fx.event_started.connect(on_event)
		await fx.play(resolved)
		fx.event_started.disconnect(on_event)
		_busy = false
	if state.phase == MatchState.Phase.ENDED:
		refresh()
		if _is_tutorial():
			var result: String = {&"player": "You win the match.", &"enemy": "You lose the match."}.get(state.result, "Draw.")
			_screen.show_toast(result)
		else:
			_show_match_end()
		round_presented.emit()
		return
	state.begin_round()
	_begin_deploy()
	round_presented.emit()


## kc-board: short on-board callouts for events the board itself can't show (a Field torn down).
func _board_callout(ev: Dictionary) -> void:
	if ev.get("type") != RulesEvent.EQUIPMENT_DESTROYED:
		return
	var z: int = MapData.ZONE_IDS.find(StringName(ev.get("zone", &"")))
	var side: StringName = StringName(ev.get("side", &""))
	var text: String = {RulesEvent.FIELD_GONE_OVERRUN: "FIELD OVERRUN", RulesEvent.FIELD_GONE_DESTROYED: "FIELD DESTROYED",
			RulesEvent.FIELD_GONE_REPLACED: "FIELD REPLACED"}.get(StringName(ev.get("reason", &"")), "")
	if z >= 0 and text != "":
		_screen.get_board().show_callout(z, text, &"enemy" if side == MatchState.SIDE_NAMES[ENEMY] else &"player")


## Takes back the last play of this Deploy.
func undo() -> Dictionary:
	if state == null:
		return {"ok": false, "code": &"no_match", "reason": "no match", "data": {}}
	if _busy:
		skip_feedback()
		return {"ok": false, "code": &"wrong_phase", "reason": "busy", "data": {}}
	var s: RulesSide = state.sides[PLAYER]
	var label: String = MatchSnapshot.play_name(state, s, s.plays.back()) if not s.plays.is_empty() else ""
	var res: Dictionary = state.undo_last(PLAYER)
	if res["ok"]:
		clear_selection()
		_after_change()
		_screen.show_toast("Undid %s." % label)
	else:
		_screen.show_toast(PlayText.describe(res)["reason"])
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
	if offer_mulligan and state.round_number == 1 and state.can_mulligan(PLAYER)["ok"] and _mulligan_panel() != null:
		open_mulligan()
		return
	_deploy_hint()


func _deploy_hint() -> void:
	var s: RulesSide = state.sides[PLAYER]
	if s.operator_can_deploy:
		_screen.show_toast("Round %d: tap your Operator, then a column." % state.round_number)
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


func _fx() -> Control:
	return _screen.get_fx() if _screen != null and _screen.has_method(&"get_fx") else null


func _mulligan_panel() -> Control:
	return _screen.get_mulligan_panel() if _screen != null and _screen.has_method(&"get_mulligan_panel") else null


## uid -> display name of every unit / Operator on the board or queued (killfeed lines).
func _unit_names() -> Dictionary:
	var out: Dictionary = {}
	for s: RulesSide in state.sides:
		if s.operator_unit != null:
			out[s.operator_unit.uid] = MatchSnapshot.unit_name(s.operator_unit, s)
		for u: RulesUnit in s.units_on_board():
			out[u.uid] = MatchSnapshot.unit_name(u, s)
		for p: Dictionary in s.plays:
			if p["kind"] == &"unit":
				out[(p["card"] as RulesCard).uid] = (p["card"] as RulesCard).card.display_name
	return out


# =============================================================================
# f03: run match, result banner, pause sheet
# =============================================================================

func _is_tutorial() -> bool:
	return get(&"tutorial") != null


func _router() -> Node:
	return get_node_or_null(^"/root/SceneRouter")


## The run's pending match, taken once (null: none, or this is the tutorial).
func _take_run_match() -> MatchState:
	var router: Node = _router()
	if router == null or _is_tutorial():
		return null
	return router.take_pending_match()


func _end_banner() -> Control:
	return _screen.get_end_banner() if _screen != null and _screen.has_method(&"get_end_banner") else null


func _pause_menu() -> Control:
	return _screen.get_pause_menu() if _screen != null and _screen.has_method(&"get_pause_menu") else null


func is_end_banner_open() -> bool:
	var b: Control = _end_banner()
	return b != null and b.is_open()


func is_pause_menu_open() -> bool:
	var p: Control = _pause_menu()
	return p != null and p.is_open()


## "MATCH 2 OF 5" for a run match, "" for a local one.
func _match_context() -> String:
	var rs: Node = get_node_or_null(^"/root/RunState")
	if not is_run_match or rs == null or rs.run == null:
		return ""
	return "MATCH %d OF %d" % [match_index + 1, rs.run.match_count()]


## The result banner (once per match). Run match: CONTINUE -> finish_run_match; local: title.
func _show_match_end() -> void:
	if _end_shown or state == null or state.phase != MatchState.Phase.ENDED:
		return
	_end_shown = true
	close_pause_menu()
	var banner: Control = _end_banner()
	if banner == null:
		return
	var outcome: Dictionary = state.hooks.mode_rules.outcome if state.hooks != null and state.hooks.mode_rules != null else {}
	banner.open({
		"result": state.result,
		"player_score": int(outcome.get("player_score", state.sides[PLAYER].score)),
		"enemy_score": int(outcome.get("enemy_score", state.sides[ENEMY].score)),
		"reason": outcome.get("reason", &""),
		"rounds": int(outcome.get("rounds", state.round_number)),
		"context": _match_context(),
		"button": "CONTINUE" if _is_routed_run_match() else "BACK TO TITLE",
	})
	if emit_to_event_bus:
		EventBus.screen_shown.emit(&"match_end")


func _is_routed_run_match() -> bool:
	var router: Node = _router()
	return is_run_match and router != null and router.is_run_match(state)


## CONTINUE on the result banner: a run match is handed back to the run once
## (SceneRouter.finish_run_match records it and opens AfterAction); a local match goes to the title.
func continue_after_match() -> Dictionary:
	if _finished or state == null or state.phase != MatchState.Phase.ENDED:
		return {"ok": false, "reason": "match not over" if not _finished else "already finished"}
	_finished = true
	var router: Node = _router()
	if router == null:
		return {"ok": false, "reason": "no SceneRouter"}
	if _is_routed_run_match():
		var report: Dictionary = router.finish_run_match(state)
		if not report.get("ok", false):
			push_warning("MatchController: finish_run_match failed: %s" % report.get("reason", ""))
		return report
	router.goto_scene(SCENE_TITLE)
	return {"ok": true, "reason": "local match"}


## MENU: the pause sheet (not during the mulligan or after the match has ended).
func open_pause_menu() -> void:
	var pause: Control = _pause_menu()
	if pause == null or state == null or is_end_banner_open() or is_mulligan_open():
		return
	clear_selection()
	if _screen.get_inspector().is_open():
		_screen.get_inspector().close()
	var run_words: bool = _is_routed_run_match()
	var ctx: String = _match_context()
	ctx = "%s · ROUND %d" % [ctx, state.round_number] if ctx != "" else "ROUND %d" % state.round_number
	var settings: Node = get_node_or_null(^"/root/Settings")
	pause.open({
		"context": ctx,
		"hint": "Your run is saved. Quitting replays this match from the start next time." if run_words \
				else "Local test match: quitting ends it.",
		"can_forfeit": state.phase != MatchState.Phase.ENDED,
		"forfeit_hint": "Forfeit this match? It counts as a loss (-1 ticket)." if run_words \
				else "Forfeit this match? It counts as a loss.",
		"fast_animations": settings != null and bool(settings.get(&"fast_animations")),
	})
	if emit_to_event_bus:
		EventBus.screen_shown.emit(&"pause")


func close_pause_menu() -> void:
	var pause: Control = _pause_menu()
	if pause != null and pause.is_open():
		pause.close()


func _on_fast_animations_toggled(on: bool) -> void:
	var settings: Node = get_node_or_null(^"/root/Settings")
	if settings != null:
		settings.set_value(&"fast_animations", on)


## Ends the match now as a loss (pause sheet FORFEIT). The engine has no forfeit intent, so the
## controller closes the MatchState the way MatchState.score() does at a match end: result,
## ModeRules outcome (reason &"forfeit"), phase ENDED and a MATCH_ENDED event (EventBus
## match_ended "loss"). Then the normal result banner / finish path follows.
func forfeit() -> bool:
	if state == null or state.phase == MatchState.Phase.ENDED or _finished:
		return false
	skip_feedback()
	var mr: ModeRules = state.hooks.mode_rules if state.hooks != null else null
	var me: RulesSide = state.sides[PLAYER]
	var foe: RulesSide = state.sides[ENEMY]
	var outcome: Dictionary = {
		"result": ModeRules.RESULT_ENEMY, "winner": ModeRules.RESULT_ENEMY, "is_draw": false,
		"reason": REASON_FORFEIT, "mode": mr.mode_name if mr != null else &"",
		"rounds": int(state.round_number), "overtime": mr.is_overtime(state.round_number) if mr != null else false,
		"player_score": int(me.score), "enemy_score": int(foe.score), "target": mr.target if mr != null else 0,
		"player_eliminations": int(me.eliminations), "enemy_eliminations": int(foe.eliminations),
	}
	if mr != null:
		mr.outcome = outcome
	state.result = ModeRules.RESULT_ENEMY
	state.phase = MatchState.Phase.ENDED
	var details: Dictionary = outcome.duplicate()
	details["forfeit"] = true
	state.emit_event(RulesEvent.PHASE_CHANGED, {"phase": "ended"})
	state.emit_event(RulesEvent.MATCH_ENDED, details)
	forfeited = true
	close_pause_menu()
	_flush_events()
	if not _busy:
		refresh()
		_show_match_end()
	# While a round is still playing, press_ready() shows the banner once it has finished.
	return true


## QUIT TO TITLE: leaves the match unrecorded. A run stays saved in its match phase, so
## Continue opens RunMap and DEPLOY replays this match from the same seed (p10).
func quit_to_title() -> void:
	if _finished:
		return
	_finished = true
	close_pause_menu()
	skip_feedback()
	var router: Node = _router()
	if router == null:
		return
	if _is_routed_run_match():
		router.active_match = null
	router.goto_scene(SCENE_TITLE)


# =============================================================================
# Mulligan (Round 1)
# =============================================================================

func is_mulligan_open() -> bool:
	var panel: Control = _mulligan_panel()
	return panel != null and panel.is_open()


func open_mulligan() -> void:
	var entries: Array = []
	for rc: RulesCard in state.sides[PLAYER].hand:
		entries.append({"uid": rc.uid, "id": rc.card.id, "name": rc.card.display_name, "cost": rc.card.cost,
				"type": {DataEnums.CardType.UNIT: "UNIT", DataEnums.CardType.TACTIC: "TACTIC"}.get(rc.card.card_type, "EQUIP")})
	clear_selection()
	_mulligan_panel().open(entries)
	if EventBus != null and emit_to_event_bus:
		EventBus.screen_shown.emit(&"mulligan")


## Keeps the opening hand (closes the panel without a mulligan).
func keep_hand() -> void:
	var none: Array[int] = []
	_apply_mulligan(none)


## Puts these cards back and redraws (closes the panel). Returns the engine's result.
func mulligan_cards(put_back: Array[int]) -> Dictionary:
	return _apply_mulligan(put_back)


func _on_mulligan_confirmed(put_back: Array[int]) -> void:
	_apply_mulligan(put_back)


func _apply_mulligan(put_back: Array[int]) -> Dictionary:
	var panel: Control = _mulligan_panel()
	if panel != null and panel.is_open():
		panel.close()
	var res: Dictionary = {"ok": true, "code": &"ok", "reason": "", "data": {}}
	if not put_back.is_empty():
		res = state.mulligan(PLAYER, put_back)
		_after_change()
		if res["ok"]:
			_screen.show_toast("Put back %d card%s and drew %d. Round 1: tap your Operator, then a column."
					% [put_back.size(), "" if put_back.size() == 1 else "s", put_back.size()])
		else:
			_screen.show_toast(PlayText.describe(res)["reason"])
	else:
		_deploy_hint()
	mulligan_done.emit(put_back)
	return res


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
		_screen.show_toast(PlayText.describe(state.can_submit(PLAYER, RulesIntent.play_card(uid, 0)),
				{"name": rc.card.display_name})["reason"])
	elif _unit_target_kind() == &"friendly":
		_screen.show_toast("Pick one of your units to move.")
	elif _unit_target_kind() == &"enemy":
		_screen.show_toast("Pick an enemy unit.")


func select_operator() -> void:
	selection = {"kind": &"operator"}
	target_uid = -1
	_show_selection()


## Sidearm / Lethal / Tactical / killstreak button: select it for targeting, or queue it at
## once when it needs no choice. A blocked item only toasts why. Returns the engine's check.
func select_item(item_id: StringName) -> Dictionary:
	if state == null:
		return {"ok": false, "code": &"no_match", "reason": "", "data": {}}
	var item: LoadoutItem = state.find_item(PLAYER, item_id)
	var check: Dictionary = state.check_use(PLAYER, item_id)
	if item == null or not check["ok"]:
		clear_selection()
		_screen.show_toast(PlayText.describe(check, _item_ctx(item))["reason"])
		return check
	var targets: Array[Dictionary] = state.legal_targets(PLAYER, item_id)
	var kind: StringName = state.needs_unit_target(PLAYER, item_id)
	var no_choice: bool = kind == &"" and targets.any(func(t: Dictionary) -> bool: return t["zone"] == MatchState.NO_ZONE)
	if no_choice:
		clear_selection()
		return _submit(RulesIntent.use_item(item_id))
	selection = {"kind": &"item", "id": item_id}
	target_uid = -1
	_show_selection()
	var verb: String = "call in" if item.slot == DataEnums.LoadoutSlot.KILLSTREAK else "use"
	if kind == &"enemy":
		_screen.show_toast("%s: tap an enemy in your Operator's column." % item.display_name)
	else:
		_screen.show_toast("%s: tap a column to %s it." % [item.display_name, verb])
	return check


func clear_selection() -> void:
	selection = {}
	target_uid = -1
	_hover_zone = -1
	_show_selection()


## Tries the selection in zone z. Returns the engine's {ok, code, reason, data} (or the
## presenter's refusal from check_play, which never reaches the engine).
func play_at(zone: int) -> Dictionary:
	var check: Dictionary = check_play(zone)
	if not check["ok"]:
		_screen.show_toast(check["reason"])
		_show_selection()
		return check
	return _submit(_intent_for(zone))


func _submit(intent: Dictionary) -> Dictionary:
	var res: Dictionary = state.submit(PLAYER, intent)
	intent_log.append({"intent": intent, "result": res})
	intent_submitted.emit(intent, res)
	if res["ok"]:
		clear_selection()
		_after_change()
		if intent["type"] == RulesIntent.USE_ITEM:
			var item: LoadoutItem = state.find_item(PLAYER, intent["item_id"])
			var what: String = item.display_name if item != null else "Item"
			var zone: int = int(intent.get("zone", -1))
			_screen.show_toast("%s queued%s. It resolves at Reveal." % [what, " on %s" % ZONE_WORDS[zone] if state.is_zone(zone) else ""])
	else:
		_screen.show_toast(PlayText.describe(res, _ctx())["reason"])
		_show_selection()
	return res


## Can the current selection go to zone z? {ok, badge (short, for the lane), reason (sentence)}.
## Asks the engine (MatchState.can_submit) and words its reason code (play_text.gd).
func check_play(zone: int) -> Dictionary:
	if state == null:
		return _no("", "No match is running.")
	if selection.is_empty():
		return _no("", "Select a card first.")
	if not state.is_zone(zone):
		var phase_check: Dictionary = state.can_submit(PLAYER, {"type": &"probe"})
		if phase_check["code"] in [&"wrong_phase", &"already_ready"]:
			return PlayText.describe(phase_check)
		return _no("", "Drop it on a column.")
	if selection.get("kind") == &"card" and state.sides[PLAYER].find_in_hand(int(selection["uid"])) == null:
		return _no("", "That card is not in your hand any more.")
	var r: Dictionary = state.can_submit(PLAYER, _intent_for(zone))
	if not r["ok"]:
		return PlayText.describe(r, _ctx())
	var kind: StringName = _unit_target_kind()
	if &"dest_full" in r["data"].get("warnings", []):
		return PlayText.describe({"code": &"zone_full", "data": {"zone": zone, "capacity": state.config.zone_capacity}})
	if kind == &"enemy":
		return _yes("TARGET") if _enemy_zone(target_uid) == zone else _no("", "Pick an enemy unit.")
	return _yes(_badge(kind))


func _badge(kind: StringName) -> String:
	match selection.get("kind"):
		&"operator":
			var s: RulesSide = state.sides[PLAYER]
			return "PLACE HERE" if s.operator_can_deploy and not _has_play(&"place") else "ROTATE HERE"
		&"item":
			var item: LoadoutItem = state.find_item(PLAYER, selection["id"])
			if item != null and item.slot == DataEnums.LoadoutSlot.KILLSTREAK:
				return "CALL IN HERE"
			return "THROW HERE" if item != null and item.slot == DataEnums.LoadoutSlot.LETHAL else "TARGET COLUMN"
	var card: CardData = state.sides[PLAYER].find_in_hand(int(selection["uid"])).card
	match card.card_type:
		DataEnums.CardType.UNIT:
			return "PLAY HERE"
		DataEnums.CardType.EQUIPMENT:
			return "PLACE HERE"
	if kind == &"friendly":
		return "MOVE HERE"
	return "TARGET COLUMN" if card.requires_zone_choice() else "PLAY"


## Name / kind of the selection, for play_text.describe().
func _ctx() -> Dictionary:
	match selection.get("kind"):
		&"operator":
			return {"name": "Your Operator", "kind": &"operator"}
		&"item":
			return _item_ctx(state.find_item(PLAYER, selection["id"]))
		&"card":
			var rc: RulesCard = state.sides[PLAYER].find_in_hand(int(selection["uid"]))
			if rc != null:
				return {"name": rc.card.display_name, "kind": &"move" if _unit_target_kind() == &"friendly" else &"card"}
	return {}


func _item_ctx(item: LoadoutItem) -> Dictionary:
	if item == null:
		return {"name": "That item", "kind": &"item"}
	var t: int = StreakTracker.threshold_for(state, PLAYER, item) if item.slot == DataEnums.LoadoutSlot.KILLSTREAK else 0
	return {"name": item.display_name, "kind": &"item", "threshold": t}


func _intent_for(zone: int) -> Dictionary:
	match selection.get("kind"):
		&"operator":
			var s: RulesSide = state.sides[PLAYER]
			if s.operator_can_deploy and not _has_play(&"place"):
				return RulesIntent.place_operator(zone)
			return RulesIntent.rotate(zone)
		&"item":
			if _unit_target_kind() == &"enemy":
				return RulesIntent.use_item(selection["id"], -1, target_uid)
			return RulesIntent.use_item(selection["id"], zone)
	var uid: int = int(selection["uid"])
	var rc: RulesCard = state.sides[PLAYER].find_in_hand(uid)
	match _unit_target_kind():
		&"friendly":
			return RulesIntent.play_card(uid, zone, target_uid, zone)
		&"enemy":
			return RulesIntent.play_card(uid, zone, target_uid)
	if rc == null or rc.card.card_type != DataEnums.CardType.TACTIC or rc.card.requires_zone_choice():
		return RulesIntent.play_card(uid, zone)
	return RulesIntent.play_card(uid)


## What the selection is, in MatchState.legal_targets() terms (card uid / item id / &"operator").
func _what() -> Variant:
	match selection.get("kind"):
		&"card":
			return int(selection["uid"])
		&"item":
			return StringName(selection["id"])
		&"operator":
			return &"operator"
	return null


## &"friendly" / &"enemy" when the selection needs a chosen unit (engine: needs_unit_target).
func _unit_target_kind() -> StringName:
	if state == null or selection.is_empty() or selection.get("kind") == &"operator":
		return &""
	return state.needs_unit_target(PLAYER, _what())


## Units that can be picked for the selection: the engine's legal targets.
func _target_candidates(_kind: StringName = &"") -> Array:
	var out: Array = []
	for t: Dictionary in state.legal_targets(PLAYER, _what()):
		var uid: int = int(t["target_uid"])
		if uid >= 0 and uid not in out:
			out.append(uid)
	return out


func _enemy_zone(uid: int) -> int:
	var u: RulesUnit = state.sides[ENEMY].find_unit(uid)
	return u.zone if u != null else MatchState.NO_ZONE


func _has_play(kind: StringName) -> bool:
	for p: Dictionary in state.sides[PLAYER].plays:
		if p["kind"] == kind:
			return true
	return false


## Lane frames / badges, the selected chip / item and the pickable units for the selection.
func _show_selection() -> void:
	if _screen == null or not _screen.is_node_ready():
		return
	var board: Control = _screen.get_board()
	_screen.get_hand().set_selected(int(selection.get("uid", -1)) if selection.get("kind") == &"card" else -1)
	_screen.get_operator_panel().set_selected(selection.get("kind") == &"operator")
	_screen.get_operator_panel().set_selected_item(StringName(selection.get("id", &"")) if selection.get("kind") == &"item" else &"")
	if selection.is_empty() or state == null:
		board.show_targets([])
		board.set_unit_targets([])
		board.show_ghosts([])
		return
	var kind: StringName = _unit_target_kind()
	if kind != &"" and target_uid < 0:
		board.show_targets([])
		board.show_ghosts([])
		board.set_unit_targets(_target_candidates(kind))
		return
	var targets: Array = []
	for z: int in MatchState.ZONE_COUNT:
		var c: Dictionary = check_play(z)
		var lane_state: StringName = &"invalid"
		if c["ok"]:
			lane_state = &"hover" if z == _hover_zone else &"valid"
		targets.append({"state": lane_state, "text": c["badge"]})
	# kc-board: the selected unit's full banner as a ghost in each valid column's landing slot
	# (row 1 for a Protector, whose badge reads TAKES THE FRONT).
	var ghost: Dictionary = _ghost_entry()
	var ghosts: Array = []
	for z: int in MatchState.ZONE_COUNT:
		var ok: bool = (targets[z] as Dictionary)["state"] != &"invalid" and not ghost.is_empty()
		ghosts.append({"entry": ghost, "front": bool(ghost.get("front_kw", false))} if ok else {})
		if ok and bool(ghost.get("front_kw", false)):
			targets[z]["text"] = "TAKES THE FRONT"
	board.show_targets(targets)
	board.show_ghosts(ghosts)
	board.set_unit_targets([target_uid] if target_uid >= 0 else [])


## Banner entry of the selected unit card / Operator (for the landing ghost), {} for anything else.
func _ghost_entry() -> Dictionary:
	var me: RulesSide = state.sides[PLAYER]
	match selection.get("kind"):
		&"card":
			var rc: RulesCard = me.find_in_hand(int(selection["uid"]))
			if rc == null or not rc.card.is_unit():
				return {}
			var e: Dictionary = {"uid": rc.uid, "name": rc.card.display_name, "fp": rc.card.firepower,
					"armor": rc.card.armor, "armor_max": rc.card.armor,
					"cls": String(CardInfo.CLASS_WORDS.get(rc.card.weapon_class, "")).to_upper(),
					"keywords": CardInfo.icon_keywords(CardInfo.keywords(rc.card))}
			MatchSnapshot._banner_fields(e, rc.card, null, me, state, rc.uid)
			return e
		&"operator":
			var op: RulesUnit = me.operator_unit
			if op == null:
				return {}
			var e2: Dictionary = MatchSnapshot.unit_entry(state, op, me)
			e2["pending"] = false
			return e2
	return {}


# =============================================================================
# Gesture handlers (connected deferred)
# =============================================================================

func _on_card_tapped(uid: int) -> void:
	if state == null or _swallow_tap():
		return
	if selection.get("kind") == &"card" and int(selection["uid"]) == uid:
		clear_selection()
	else:
		select_card(uid)


func _on_operator_tapped() -> void:
	if state == null or _swallow_tap():
		return
	if selection.get("kind") == &"operator":
		clear_selection()
	else:
		select_operator()


func _on_lane_tapped(zone: int, slot_side: StringName, uid: int) -> void:
	if state == null or _swallow_tap() or selection.is_empty():
		return
	_pick_or_play(zone, slot_side, uid)


## A loadout / killstreak button: tap again to deselect.
func _on_item_pressed(item_id: StringName) -> void:
	if state == null or _swallow_tap():
		return
	if selection.get("kind") == &"item" and StringName(selection.get("id", &"")) == item_id:
		clear_selection()
	else:
		select_item(item_id)


## While the round plays a tap only fast-forwards it (true = swallowed).
func _swallow_tap() -> bool:
	if _busy:
		skip_feedback()
		return true
	return is_mulligan_open()


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
			_screen.show_toast("Now tap an adjacent column.")
			return
	play_at(zone)


func _on_card_drag_started(uid: int, pos: Vector2) -> void:
	if state == null or _swallow_tap():
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
	if state == null or _swallow_tap() or state.sides[PLAYER].operator_unit == null:
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
	open_card_inspector(rc.card, "friend", _join(status, _range_hint(rc.card)), {}, -1, uid)


func _on_operator_inspected() -> void:
	if state == null or state.sides[PLAYER].operator_unit == null:
		return
	_open_operator(PLAYER)


func _on_lane_long_pressed(zone: int, slot_side: StringName, uid: int) -> void:
	if state == null:
		return
	match slot_side:
		&"objective":
			_open_objective(zone)
			return
		&"incoming":
			_open_info({"banner_back": true, "title": "Incoming rival play",
					"type": "hidden · %s" % ZONE_WORDS[zone],
					"text": "The rival committed a unit to %s this Deploy. It stays face down until Reveal, then flips and slides in from the top edge to this slot (a Protector slides on to the front)." % ZONE_WORDS[zone],
					"status": "Recon Drone or Callout can spot it before Reveal."})
			return
		&"field_player", &"field_enemy":
			_open_field(zone, PLAYER if slot_side == &"field_player" else ENEMY, uid)
			return
	if uid < 0:
		return
	var side: int = PLAYER if slot_side == &"player" else ENEMY
	var s: RulesSide = state.sides[side]
	if s.operator_unit != null and s.operator_unit.uid == uid:
		_open_operator(side)
		return
	var u: RulesUnit = s.find_unit(uid)
	if u != null and u.card != null:
		var row: int = s.lines[zone].find(u) + 1
		var status: String = "In %s, row %d%s (%s): FP %d, Armor %d/%d." % [ZONE_WORDS[zone], row,
				" (frontline)" if row == 1 else "", RANGE_WORDS[state.zone_ranges[zone]],
				state.firepower_of(u), u.armor, u.max_armor(state.round_number)]
		open_card_inspector(u.card, "friend" if side == PLAYER else "enemy", status, MatchSnapshot.unit_entry(state, u, s), side)
		return
	if u != null:
		# A token without a card (Sentry Turret).
		var e: Dictionary = MatchSnapshot.unit_entry(state, u, s)
		_open_info({"banner": e, "side": side, "title": String(e["name"]), "type": "token · %s" % ZONE_WORDS[zone],
				"text": "FP %d, Armor %d/%d. It does not count for control." % [int(e["fp"]), int(e["armor"]), int(e["armor_max"])],
				"status": ""})
		return
	for p: Dictionary in s.plays:
		if p["kind"] == &"unit" and (p["card"] as RulesCard).uid == uid:
			var card: CardData = (p["card"] as RulesCard).card
			var e3: Dictionary = {"name": card.display_name, "fp": card.firepower, "armor": card.armor, "armor_max": card.armor,
					"cls": String(CardInfo.CLASS_WORDS.get(card.weapon_class, "")).to_upper(), "pending": true,
					"keywords": CardInfo.icon_keywords(CardInfo.keywords(card))}
			MatchSnapshot._banner_fields(e3, card, null, s, state, uid)
			open_card_inspector(card, "friend", "Queued for %s (PLAN). It arrives at Reveal." % ZONE_WORDS[zone], e3, PLAYER)
			return


func open_card_inspector(card: CardData, side: String, status: String, banner: Dictionary = {}, banner_side: int = -1, card_uid: int = -1) -> void:
	var type_text: String = String(CardInfo.TYPE_WORDS.get(card.card_type, "card"))
	if card.is_unit() and CardInfo.CLASS_WORDS.get(card.weapon_class, "") != "":
		type_text += " · " + String(CardInfo.CLASS_WORDS[card.weapon_class])
	if card.is_unit():
		type_text += " · FP %d · Armor %d" % [card.firepower, card.armor]
	type_text += " · cost %d" % card.cost
	var keywords: Array[Dictionary] = CardInfo.keywords(card)
	# Units whose rules text only lists their keywords ("Pick") get the keyword lines instead.
	var names: PackedStringArray = []
	for k: Dictionary in keywords:
		names.append(String(k["name"]).to_lower())
	var text: String = "" if card.text.to_lower().trim_suffix(".") == ", ".join(names) else card.text
	if banner.is_empty():
		banner = {"name": card.display_name, "fp": card.firepower, "armor": card.armor, "armor_max": card.armor,
				"cls": String(CardInfo.CLASS_WORDS.get(card.weapon_class, "")).to_upper(),
				"keywords": CardInfo.icon_keywords(CardInfo.keywords(card))}
		MatchSnapshot._banner_fields(banner, card, null, state.sides[PLAYER], state, card_uid)
	var art: BannerArt = BannerArtDB.get_art(StringName(String(banner.get("banner", card.id))))
	if card.is_field():
		text = _join(text, FIELD_RULE)
	var view: Dictionary = CardInfo.view_dict(card, side)
	if BannerArtDB.is_card_art(art):
		view["licensed_art"] = String(art.id)
		view["name"] = art.title
	_screen.get_inspector().open({
		"view": view, "title": art.title if BannerArtDB.is_card_art(art) else card.display_name,
		"type": (card.display_name + " · " + type_text) if BannerArtDB.is_card_art(art) else type_text,
		"text": text, "keywords": keywords, "status": status,
		"banner": banner, "side": banner_side if banner_side >= 0 else (PLAYER if side == "friend" else ENEMY),
		"art_line": _art_line(art), "is_unit": card.is_unit(),
	})


## Plain-words Overrun rule (the head asked "What is overrun again?"), shown on every Field.
const FIELD_RULE: String = "Overrun: at the end of each round, if the enemy controls this column, this Field is destroyed (hidden traps are exempt)."


## "Art: Marksman (placeholder from Killstreak art) · alternate art 1 of 1" for the inspector.
func _art_line(art: BannerArt) -> String:
	var what: String = art.title if art.title != "" else String(art.id).capitalize()
	if art.licensed:
		# kc-cod2: n of the chassis' (or the Operator weapon's) licensed arts, plus the MW3 credit.
		var pool: Array[StringName] = BannerArtDB.licensed_pool(art.card_id)
		var n: int = maxi(1, pool.find(art.id) + 1)
		return "Banner: %s · %s %d of %d · MW3 calling card (reference art, private pitch)" % [what,
				"mastery tier" if art.mastery_tier > 0 else "art", n, maxi(1, pool.size())]
	return "Banner: %s%s · alternate art 1 of 1" % [what, " (placeholder)" if art.placeholder else ""]


## Inspector for something that is not a card in hand (objective tile, incoming back, rails).
func _open_info(info: Dictionary) -> void:
	var d: Dictionary = info.duplicate()
	d["view"] = {}
	d["side"] = int(info.get("side", PLAYER))
	_screen.get_inspector().open(d)


## Long-press / right-click on a rail box (studio rule: everything can be inspected).
func _on_rail_inspected(key: StringName) -> void:
	if state == null:
		return
	var me: RulesSide = state.sides[PLAYER]
	var foe: RulesSide = state.sides[ENEMY]
	match key:
		&"score":
			var goal: String = String(state.config.get_meta(&"goal_text")) if state.config.has_meta(&"goal_text") else ""
			_open_info({"title": "Score", "type": "round %d · %s" % [state.round_number, String(MatchState.PHASE_NAMES[state.phase]).to_lower()],
					"text": "You %d, rival %d. %s" % [me.score, foe.score, goal], "status": "Each round you score the columns you control."})
		&"deck":
			_open_info({"title": "Your deck", "type": "deck · discard",
					"text": "%d cards left to draw, %d used (discard pile). You draw at the start of each round; the hand holds up to 7." % [me.deck.size(), me.discard.size()],
					"status": ""})
		&"intel":
			var dots: PackedInt32Array = state.red_dots(PLAYER)
			_open_info({"title": "Rival intel", "type": "rival hand · incoming plays",
					"text": "The rival holds %d cards. Hidden plays this Deploy: A %d, B %d, C %d. Each shows on the board as an INCOMING back in the slot where it will land." % [foe.hand.size(), dots[0], dots[1], dots[2]],
					"status": "Recon Drone and Callout reveal what they are."})
		&"supply":
			_open_info({"title": "Supply", "type": "resource",
					"text": "%d of %d Supply left this round. Cards cost Supply to play; it refills (and grows) each round." % [me.supply, state.config.supply_for_round(state.round_number)],
					"status": ""})


func _open_objective(zone: int) -> void:
	var lane: Dictionary = MatchSnapshot.build(state, map, PLAYER, killfeed)["lanes"][zone]
	var control_text: String = {&"player": "You control it", &"enemy": "The rival controls it",
			&"contested": "Contested: both sides have units here", &"empty": "Nobody holds it"}.get(lane["control"], "")
	var lines: PackedStringArray = []
	lines.append("%s. A side controls a column when it has at least one unit there and the other side has none (a Holder breaks a tie)." % control_text)
	lines.append("Column Firepower: yours %d, rival %d. Range: %s (some weapon classes get +FP here)." % [int(lane["fp_player"]), int(lane["fp_enemy"]), String(lane["range"]).capitalize()])
	for key: String in ["player", "enemy"]:
		for f: Dictionary in (lane["fields"] as Dictionary).get(key, []):
			lines.append("%s Field: %s%s." % ["Your" if key == "player" else "Rival", f["name"], " (hidden trap)" if f.get("hidden", false) else ""])
	_open_info({"title": "Objective %s · %s" % [String(lane["label"]), String(lane["name"]).capitalize()],
			"type": "objective · %s" % String(lane["range"]).to_lower(), "text": "\n".join(lines),
			"status": "Row 1 on each side touches the objective: that card is the frontline."})


func _open_field(zone: int, side: int, uid: int) -> void:
	var s: RulesSide = state.sides[side]
	var rc: RulesCard = null
	var risk: bool = false
	for entry: Dictionary in state.fields_in(side, zone, side == PLAYER):
		if (entry["card"] as RulesCard).uid == uid:
			rc = entry["card"]
	for p: Dictionary in s.plays:
		if p["kind"] == &"equipment" and (p["card"] as RulesCard).uid == uid:
			rc = p["card"]
	if rc == null:
		return
	var control: int = state.control_of(zone)
	risk = rc.card.is_visible_field() and control == 1 - side
	var status: String = "On %s's half of objective %s." % ["your" if side == PLAYER else "the rival", MatchSnapshot.ZONE_LABELS[zone]]
	if rc.card.hidden:
		status = "Hidden trap: the rival can't see it. Traps are never overrun."
	elif risk:
		status = "OVERRUN RISK: the %s controls this column now. If it still does at the end of the round, this Field is destroyed." % ("rival" if side == PLAYER else "you")
	status += " Removed by: Overrun, Sabotage, or a newer Field of the same side here."
	open_card_inspector(rc.card, "friend" if side == PLAYER else "enemy", status, {}, side)


func _open_operator(side: int) -> void:
	var s: RulesSide = state.sides[side]
	var op: RulesUnit = s.operator_unit
	var title: String = MatchSnapshot.unit_name(op, s)
	var where: String = "Off the board."
	if op.is_on_board():
		where = "In %s: FP %d, Armor %d/%d." % [ZONE_WORDS[op.zone], state.firepower_of(op), op.armor, op.max_armor(state.round_number)]
	elif side == PLAYER and s.operator_can_deploy:
		where = "Off the board: tap it, then a column, to place it."
	var view: Dictionary = CardInfo.operator_view_dict(op, title)
	view["side"] = "friend" if side == PLAYER else "enemy"
	var op_art: BannerArt = BannerArtDB.get_art(StringName(String(MatchSnapshot.unit_entry(state, op, s)["banner"])))
	if op_art.licensed:
		view["licensed_art"] = String(op_art.id)  # kc-cod3: the mastery card in the card picture too
	_screen.get_inspector().open({
		"view": view, "title": title, "type": "operator · %s" % String(CardInfo.CLASS_WORDS.get(op.weapon_class, "")),
		"text": String(view["text"]), "keywords": CardInfo.operator_keywords(op), "status": where,
		"banner": MatchSnapshot.unit_entry(state, op, s), "side": side,
		"art_line": _art_line(BannerArtDB.get_art(StringName(String(MatchSnapshot.unit_entry(state, op, s)["banner"])))) \
				+ _mastery_line(MatchSnapshot.unit_entry(state, op, s)),
	})


## Operator inspector line: the camo / weapon-mastery tier the banner shows.
static func _mastery_line(e: Dictionary) -> String:
	var tier: int = int(e.get("mastery_tier", 1))
	if not BannerArtDB.has_licensed():
		return " · Camo tier: Base (mastery tiers come later)"
	var name: String = BannerArtDB.MASTERY_TIERS[clampi(tier, 1, 4) - 1]
	return " · Mastery tier %d of 4: %s%s" % [tier, name, " (Base camo)" if tier == 1 else " (dev preview)"]


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
			EventBus.match_started.emit(mode, state.map_id, match_index)
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
		RulesEvent.CARD_REVEALED:
			# p16: a card counts as deployed once it is committed and revealed (UNDO can't take
			# it back any more); both sides, the enemy's hidden Equipment stays private.
			EventBus.card_deployed.emit(StringName(e.get("side", &"")), StringName(e.get("card_id", &"")), StringName(e.get("zone", &"")))
			EventBus.card_revealed.emit(StringName(e.get("side", &"")), StringName(e.get("card_id", &"")), StringName(e.get("zone", &"")))
		RulesEvent.ITEM_REVEALED:
			if e.get("side", &"") == MatchState.SIDE_NAMES[PLAYER]:
				var item_id: StringName = StringName(e.get("item_id", &""))
				var item: LoadoutItem = state.find_item(PLAYER, item_id)
				if item != null and item.slot == DataEnums.LoadoutSlot.KILLSTREAK:
					EventBus.killstreak_used.emit(item_id, r)
				else:
					EventBus.ability_used.emit(item_id, StringName(e.get("zone", &"")))
		RulesEvent.OPERATOR_PLACED:
			if r > 1:
				EventBus.operator_respawned.emit(StringName(e.get("side", &"")))
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
			EventBus.match_ended.emit(result, state.round_number, (Time.get_ticks_msec() - _match_started_ms) / 1000.0)


# =============================================================================
# Helpers
# =============================================================================

static func _yes(badge: String) -> Dictionary:
	return {"ok": true, "badge": badge, "reason": ""}


static func _no(badge: String, reason: String) -> Dictionary:
	return {"ok": false, "badge": badge, "reason": reason}


static func _join(a: String, b: String) -> String:
	return a if b.is_empty() else "%s %s" % [a, b]

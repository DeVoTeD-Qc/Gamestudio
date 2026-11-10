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
#   - f02 loadout: tap a killstreak in the tray, then tap what it needs (a lane for Mortar /
#     Sentry); killstreaks that need nothing (Recon Drone, Attack Helo) are queued at once.
#     Blocked buttons are disabled and a tap on them toasts why (used, not earned, no Operator).
#     kc-loadout-cut: the Sidearm / Frag Grenade / Flashbang buttons are gone.
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
#   card_deployed, killstreak_earned / _used, eliminations, Operator downs).
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
const StatBreakdown: GDScript = preload("res://scripts/ui/stat_breakdown.gd")
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
const FightPlayback: GDScript = preload("res://scripts/ui/fight_playback.gd")
const RunV2Views: GDScript = preload("res://scripts/ui/run/run_v2_views.gd")
const PLAYER: int = MatchState.PLAYER
const ENEMY: int = MatchState.ENEMY
const ZONE_WORDS: PackedStringArray = ["column A", "column B", "column C"]
const KILLFEED_KEEP: int = 6
const SCENE_TITLE: String = "res://scenes/Title.tscn"
## outcome.reason of a forfeited match (MatchEndBanner / AfterAction wording).
const REASON_FORFEIT: StringName = &"forfeit"
## kc-duel-ui: the Duel hand-off (Match.tscn plays a DuelMatch from the Duel hub).
const DuelFlowScript: GDScript = preload("res://scripts/ui/duel/duel_flow.gd")
const PASS_COVER_SCENE: String = "res://scenes/duel/PassCover.tscn"

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
## kc-duel-ui: the side this screen plays and shows (side 0, except in a Pass & Play duel, where it is
## the side whose private Deploy is open) and the other side. Static helpers keep PLAYER / ENEMY.
var me_side: int = MatchState.PLAYER
var foe_side: int = MatchState.ENEMY
## kc-duel-ui: the DuelMatch this screen plays (duel-api.md §6), null outside a duel.
var duel: Object = null
## kc-duel-ui: the Pass & Play cover (scenes/duel/PassCover.tscn), made on first use.
var _cover: Control = null
## kc-duel-ui: the last round's public summary (shown on the cover).
var _last_round_line: String = ""
var map: MapData = null
## {kind: &"card", uid}, {kind: &"operator"} or {kind: &"item", id}; empty = nothing selected.
var selection: Dictionary = {}
## Unit picked for a play that needs one (Flank Route), -1 = none yet.
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
## kc-fight-ui: the board as the firefight playback stands (fight_playback.gd), null between rounds.
var fight_playback: RefCounted = null
## kc-fight-ui: how many times the board was redrawn from the playback board this round (tests).
var fight_refreshes: int = 0
## kc-fight-ui: the last round's playback: the §5 model at x1 (FirefightResolver.playback_seconds of its
## events) and the measured wall-clock time of the whole round's feedback (ms), and whether it was skipped.
var last_playback_model_s: float = 0.0
var last_playback_ms: int = 0
var last_playback_skipped: bool = false
## kc-fight-ui: wall-clock ms of the Firefight part alone (PHASE_CHANGED firefight -> score).
var last_fight_ms: int = 0
var _fight_t0: int = 0


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
	op.killstreak_pressed.connect(_on_item_pressed, d)
	var board: Control = _screen.get_board()
	board.lane_tapped.connect(_on_lane_tapped, d)
	board.lane_long_pressed.connect(_on_lane_long_pressed, d)
	_screen.ready_pressed.connect(press_ready, d)
	if _screen.has_signal(&"rail_inspected"):
		_screen.rail_inspected.connect(_on_rail_inspected, d)
	if _screen.has_signal(&"item_inspected"):
		_screen.item_inspected.connect(open_item_inspector, d)
	if _screen.has_signal(&"trait_inspected"):
		_screen.trait_inspected.connect(open_trait_inspector, d)
	# kc-v2-ui: the Operator ability button.
	if _screen.has_signal(&"ability_pressed"):
		_screen.ability_pressed.connect(func() -> void: use_ability(), d)
		_screen.ability_inspected.connect(open_ability_inspector, d)
	_screen.undo_pressed.connect(undo, d)
	# kc-cards-impl (H1): CANCEL on the docked preview, or a tap on the empty board, cancels.
	if _screen.has_signal(&"dock_cancel_pressed"):
		_screen.dock_cancel_pressed.connect(clear_selection, d)
	if board.has_signal(&"empty_tapped"):
		board.empty_tapped.connect(func() -> void:
			if not selection.is_empty() and not _busy:
				clear_selection(), d)
	if _screen.has_method(&"get_mulligan_panel"):
		_screen.get_mulligan_panel().confirmed.connect(_on_mulligan_confirmed, d)
		if _screen.get_mulligan_panel().has_signal(&"card_inspected"):
			_screen.get_mulligan_panel().card_inspected.connect(_on_card_inspected, d)
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
		var duel_match: Object = DuelFlowScript.take_pending() if not _is_tutorial() else null
		var run_match: MatchState = _take_run_match() if duel_match == null else null
		if duel_match != null:
			start_duel_match(duel_match)
		elif run_match != null:
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
	# kc-syn §11.4: the quick match plays the run's starter as it is.
	player.primary = config.starter_primary
	# kc-ui4: the Operator picked on the starter screen (Settings.operator_primary), when valid.
	var pick: LoadoutItem = _picked_operator(config)
	if pick != null:
		player.primary = pick
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
	# kc-onboard-ui: run matches and the tutorial reveal systems step by step; a quick match and the
	# pitch build show everything (RevealGate).
	RevealGate.active = (is_run_match or _is_tutorial()) and not PitchDecks.active()
	if not tree_exiting.is_connected(_reveal_off):
		tree_exiting.connect(_reveal_off)
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
	if pitch_swaps_apply():
		# kc-syn §11.4: the whole side (its deck), so the pitch shows links and sets. kc-deck-match (the
		# head: "the starting deck shown when we start campaign doesn't match what I draw in game 1"):
		# only the Quick Match showcases the pitch swaps; a run match and the tutorial play the real decks.
		for s: RulesSide in state.sides:
			PitchDecks.apply_setup(s.setup)
	if duel == null:
		_assign_copy_arts(state)  # kc-duel-ui: a duel deck's copies already wear their picked arts
	state.start_match()
	_begin_deploy()


## kc-deck-match: the private pitch's showcase swaps (PitchDecks) apply to this match: the pitch
## build's Quick Match only, never a run match (campaign) or the tutorial, so match 1 draws exactly
## the starter deck the Loadout screen shows.
func pitch_swaps_apply() -> bool:
	return PitchDecks.active() and not is_run_match and not _is_tutorial()


## kc-cod2: per-copy banner art (display only). kc-trait-ui (head): every copy wears ITS OWN art,
## and that art matches the copy's trait (the art gives the trait):
## - a run's player side already carries the copies' arts (RunProgress.player_setup().deck_arts, the
##   art each copy was found with): kept as they are;
## - every other side (rival squads, quick match, tutorial) dresses each copy with an art of its
##   trait (SideSetup.trait_of: the squad's identity): with the private licensed art, the n-th copy
##   of a (chassis, trait) across both sides gets the n-th licensed art of that trait (variety);
##   without it, the home option wears the chassis' default art (&"") and an alternate option our
##   placeholder option art (ArtTraits.default_art: "<chassis>~mastery" ...).
## Codex EQUIP no longer reaches matches (head: the Codex is a viewer). `_equipped` is ignored.
static func _assign_copy_arts(m: MatchState, _equipped: Dictionary = {}) -> void:
	var used: Dictionary = {}
	var licensed: bool = BannerArtDB.has_licensed()
	for i: int in m.sides.size():
		var setup: SideSetup = m.sides[i].setup
		if i == PLAYER and setup.deck_arts.size() == setup.deck.size() and setup.deck_arts.any(func(a: StringName) -> bool: return a != &""):
			continue
		var list: Array[StringName] = []
		var any: bool = false
		for j: int in setup.deck.size():
			var art: StringName = _copy_art(setup.deck[j], setup.trait_of(j), used, licensed)
			any = any or art != &""
			list.append(art)
		setup.deck_arts.clear()
		if any:
			setup.deck_arts.assign(list)


## The art of one copy of `card` whose chosen trait is `chosen` (see _assign_copy_arts).
static func _copy_art(card: CardData, chosen: StringName, used: Dictionary, licensed: bool) -> StringName:
	if card == null:
		return &""
	var t: StringName = card.card_trait
	if card.has_trait_choice() and chosen != SynergyRules.TRAIT_DEFAULT:
		t = chosen if card.can_carry(chosen) else &""
	var pool: Array[StringName] = []
	if licensed:
		var lic: Array[StringName] = BannerArtDB.licensed_pool(card.id)
		for a: StringName in (ArtTraits.arts_with_trait(card, t) if card.has_trait_choice() else lic):
			if a in lic:
				pool.append(a)
	if pool.is_empty():
		return &"" if t == card.card_trait else ArtTraits.default_art(card, t)
	var key: String = "%s@%s" % [card.id, t]
	var n: int = int(used.get(key, 0))
	used[key] = n + 1
	return pool[n % pool.size()]


## kc-ui4: the starter screen's Operator pick (one of RunProgress.operator_options), else null.
static func _picked_operator(config: RunConfig) -> LoadoutItem:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var settings: Node = tree.root.get_node_or_null(^"/root/Settings") if tree != null else null
	var id: String = String(settings.get(&"operator_primary")) if settings != null else ""
	if id == "":
		return null
	for item: LoadoutItem in RunProgress.operator_options(config):
		if String(item.id) == id:
			return item
	return null


func _ai_turn(st: MatchState) -> void:
	enemy_ai_player.take_turn(st, foe_side)


## True while FeedbackDirector plays a resolved round (input only fast-forwards it).
func is_busy() -> bool:
	return _busy


## Fast-forwards the round's feedback (F key, or a tap while it plays).
func skip_feedback() -> void:
	var fx: Control = _fx()
	if fx != null and fx.is_playing():
		last_playback_skipped = true
		fx.skip()


## READY: the player's plan is locked in, the round resolves, FeedbackDirector plays it over the
## pre-resolve board (switching to the post-Reveal board when the firefight starts), then the
## next Deploy starts. Returns after the feedback has played.
func press_ready() -> void:
	if state == null or _busy or state.phase != MatchState.Phase.DEPLOY or state.sides[me_side].ready \
			or is_mulligan_open():
		return
	clear_selection()
	var me: RulesSide = state.sides[me_side]
	var supply_unspent: int = me.supply
	var hand_size: int = me.hand.size()
	if is_hot_seat():
		# kc-duel-ui: this player's Deploy is done; the other one's cover comes up, or (both ready) the
		# DuelMatch emits round_ready and _on_duel_round_ready plays the round.
		_last_supply = supply_unspent
		_last_hand = hand_size
		duel.call(&"finish_deploy", me_side)
		return
	state.set_ready(me_side)
	await _play_round(supply_unspent, hand_size)


## Reveal, Firefight and Score of a round both sides are ready for, played over the board; then the
## next Deploy (or the match end).
func _play_round(supply_unspent: int, hand_size: int) -> void:
	if not state.sides[foe_side].ready:
		state.set_ready(foe_side)  # the enemy passes (or already planned in enemy_planner)
	# The pre-resolve board (deploy closed) stays up while the Reveal plays.
	var before: Dictionary = MatchSnapshot.build(state, map, me_side, killfeed)
	before["phase"] = "REVEAL"
	_screen.show_snapshot(before)
	_show_selection()
	var fx: Control = _fx()
	if fx != null and fx.locator != null:
		fx.unit_names = _unit_names()
	# MatchState.resolve_round(), split so the board can show the units that arrived at Reveal
	# when the firefight starts.
	var start: int = state.events.size()
	# kc-fight-ui: the units already on the board before Reveal (the rival's new cards turn over one
	# by one while the Reveal plays, see _reveal_lanes()).
	var pre_uids: Dictionary = {}
	for s: RulesSide in state.sides:
		for u: RulesUnit in s.units_on_board():
			pre_uids[u.uid] = true
	state.reveal()
	var after_reveal: Dictionary = MatchSnapshot.build(state, map, me_side, killfeed)
	after_reveal["phase"] = "FIREFIGHT"
	# kc-fight-ui: a copy of the board as the firefight starts; the playback applies the events to it
	# as they land, so units leave and lines slide up beat by beat.
	var playback: RefCounted = FightPlayback.start(state, map, me_side) if fx != null else null
	fight_playback = playback
	fight_refreshes = 0
	state.firefight()
	state.score()
	var resolved: Array[Dictionary] = state.events_since(start)
	if emit_to_event_bus:
		EventBus.round_summary.emit(state.round_number, supply_unspent, hand_size)
	_flush_events()
	round_resolved.emit(resolved)
	if fx != null:
		_busy = true
		fx.unit_sides = _unit_sides(playback.state if playback != null else state)
		if _screen.has_method(&"prepare_fight"):
			_screen.prepare_fight(resolved)
		var in_fight: Array = [false]
		var on_event: Callable = func(ev: Dictionary) -> void:
			if ev.get("type") == RulesEvent.PHASE_CHANGED:
				var was_fight: bool = in_fight[0]
				in_fight[0] = StringName(ev.get("phase", "")) == &"firefight"
				if in_fight[0]:
					_fight_t0 = Time.get_ticks_msec()
					_screen.show_snapshot(after_reveal)
				elif was_fight:
					last_fight_ms = Time.get_ticks_msec() - _fight_t0
			_board_callout(ev)
		# kc-fight-ui: each event lands on the playback board; the screen follows it (not while skipping:
		# the final board comes from the live state when the round ends).
		var arrived: Dictionary = {}
		var on_land: Callable = func(ev: Dictionary) -> void:
			if ev.get("type") == RulesEvent.UNIT_ARRIVED and not in_fight[0] and not fx.is_skipping() \
					and _screen.has_method(&"show_lanes"):
				arrived[int(ev.get("uid", -1))] = true
				_screen.show_lanes(_reveal_lanes(after_reveal, pre_uids, arrived, resolved))
				return
			if playback == null or not in_fight[0]:
				return
			if playback.apply(ev) and not fx.is_skipping() and _screen.has_method(&"show_fight_board"):
				fight_refreshes += 1
				_screen.show_fight_board(playback.snapshot())
		fx.event_started.connect(on_event)
		fx.event_landed.connect(on_land)
		last_playback_model_s = FirefightResolver.playback_seconds(resolved)
		last_playback_skipped = false
		last_fight_ms = 0
		var t0: int = Time.get_ticks_msec()
		await fx.play(resolved)
		last_playback_ms = Time.get_ticks_msec() - t0
		fx.event_started.disconnect(on_event)
		fx.event_landed.disconnect(on_land)
		fight_playback = null
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
	_last_round_line = _round_line()
	if is_hot_seat():
		round_presented.emit()
		duel.call(&"round_done")  # the next round's first cover (cover_needed)
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
		_screen.get_board().show_callout(z, text, &"enemy" if side == MatchState.SIDE_NAMES[foe_side] else &"player")


## Takes back the last play of this Deploy.
func undo() -> Dictionary:
	if state == null:
		return {"ok": false, "code": &"no_match", "reason": "no match", "data": {}}
	if _busy:
		skip_feedback()
		return {"ok": false, "code": &"wrong_phase", "reason": "busy", "data": {}}
	var s: RulesSide = state.sides[me_side]
	var label: String = MatchSnapshot.play_name(state, s, s.plays.back()) if not s.plays.is_empty() else ""
	var res: Dictionary = state.undo_last(me_side)
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
		var dots: PackedInt32Array = state.red_dots(me_side)
		for z: int in dots.size():
			EventBus.intel_updated.emit(MapData.ZONE_IDS[z], dots[z])
	var met_now: Array[StringName] = note_board_systems()
	refresh()
	if offer_mulligan and state.round_number == 1 and state.can_mulligan(me_side)["ok"] and _mulligan_panel() != null:
		open_mulligan()
		return
	_deploy_hint()
	if _screen.has_method(&"offer_explainer") and not _is_tutorial():
		_screen.offer_explainer(met_now, "round%d" % state.round_number)


func _reveal_off() -> void:
	RevealGate.active = false


## kc-onboard-ui (§5): the systems this board puts in play are met (RunState.note_systems, from
## RevealFlags.match_triggers after each Reveal / Firefight, plus a killstreak the first time one
## is ready), and at the start of each Deploy one pending "New: X"
## explainer of those shows over the board.
func note_board_systems() -> Array[StringName]:
	var flags: Array[StringName] = RevealFlags.match_triggers(state)
	var me: RulesSide = state.sides[me_side]
	if not me.streak_tray.is_empty():
		flags.append(RevealFlags.KILLSTREAKS)
	var rs: Node = get_node_or_null(^"/root/RunState")
	if rs != null and rs.has_method(&"note_systems"):
		rs.note_systems(flags)
	return flags


func _deploy_hint() -> void:
	var s: RulesSide = state.sides[me_side]
	if s.operator_can_deploy:
		_screen.show_toast("Round %d: tap your Operator (next to READY), then a column." % state.round_number)
	else:
		_screen.show_toast("Round %d: Deploy." % state.round_number)


func refresh() -> void:
	if state == null:
		return
	_screen.show_snapshot(MatchSnapshot.build(state, map, me_side, killfeed))
	_show_selection()


func _after_change() -> void:
	_flush_events()
	refresh()


func _fx() -> Control:
	return _screen.get_fx() if _screen != null and _screen.has_method(&"get_fx") else null


func _mulligan_panel() -> Control:
	return _screen.get_mulligan_panel() if _screen != null and _screen.has_method(&"get_mulligan_panel") else null


## kc-fight-ui (head: make the rival's reveals readable): the post-Reveal columns with only the rival
## units already revealed (or on the board before Reveal); the rest stay face-down INCOMING in their
## column. Your own arrivals show at once.
static func _reveal_lanes(after: Dictionary, pre: Dictionary, arrived: Dictionary, events: Array) -> Array:
	var pending: Dictionary = {}
	for ev: Dictionary in events:
		if ev.get("type") == RulesEvent.PHASE_CHANGED and StringName(ev.get("phase", "")) == &"firefight":
			break
		if ev.get("type") == RulesEvent.UNIT_ARRIVED and StringName(ev.get("side", &"")) == MatchState.SIDE_NAMES[ENEMY] \
				and not arrived.has(int(ev.get("uid", -1))):
			var z: StringName = StringName(ev.get("zone", &""))
			pending[z] = int(pending.get(z, 0)) + 1
	var lanes: Array = (after.get("lanes", []) as Array).duplicate(true)
	for lane: Dictionary in lanes:
		var keep: Array = []
		for e: Dictionary in lane.get("enemy", []):
			var uid: int = int(e.get("uid", -1))
			if pre.has(uid) or arrived.has(uid):
				keep.append(e)
		lane["enemy"] = keep
		lane["incoming"] = int(pending.get(StringName(lane.get("id", &"")), 0))
		lane["revealed"] = []
	return lanes


## kc-fight-ui: uid -> &"player" / &"enemy" of every unit on the board (the playback's shooters).
func _unit_sides(of: MatchState) -> Dictionary:
	var out: Dictionary = {}
	for si: int in of.sides.size():
		for u: RulesUnit in of.sides[si].units_on_board():
			out[u.uid] = MatchState.SIDE_NAMES[si]
	return out


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
	if duel != null:
		# kc-duel-ui: a duel ends on its own result screen (score, reason, records).
		close_pause_menu()
		_finished = true
		if duel.has_method(&"round_done"):
			duel.call(&"round_done")
		DuelFlowScript.finish(duel, _duel_result())
		return
	close_pause_menu()
	var banner: Control = _end_banner()
	if banner == null:
		return
	var outcome: Dictionary = state.hooks.mode_rules.outcome if state.hooks != null and state.hooks.mode_rules != null else {}
	banner.open({
		"result": state.result,
		"player_score": int(outcome.get("player_score", state.sides[me_side].score)),
		"enemy_score": int(outcome.get("enemy_score", state.sides[foe_side].score)),
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
	if duel != null and duel.has_method(&"forfeit"):
		# kc-duel-ui: the side on screen concedes (in Pass & Play, the player whose Deploy is open).
		skip_feedback()
		duel.call(&"forfeit", me_side)
		forfeited = true
		close_pause_menu()
		_flush_events()
		if not _busy:
			refresh()
			_show_match_end()
		return true
	skip_feedback()
	var mr: ModeRules = state.hooks.mode_rules if state.hooks != null else null
	var me: RulesSide = state.sides[me_side]
	var foe: RulesSide = state.sides[foe_side]
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
	if duel != null:
		DuelFlowScript.clear_active()
		router.goto_scene(DuelFlowScript.SCENE_HUB)
		return
	router.goto_scene(SCENE_TITLE)


# =============================================================================
# Mulligan (Round 1)
# =============================================================================

func is_mulligan_open() -> bool:
	var panel: Control = _mulligan_panel()
	return panel != null and panel.is_open()


func open_mulligan() -> void:
	var entries: Array = []
	for rc: RulesCard in state.sides[me_side].hand:
		# kc-ui3: the full card face (CardView), with its own licensed art and title when it has one.
		# kc-cards-impl: the Y2+ face (art, trait, Standard Issue tag).
		var view: Dictionary = card_view_for(rc)
		view.erase("cant_pay")
		var art: BannerArt = BannerArtDB.get_art(StringName(String(state.art_by_uid.get(rc.uid, rc.card.id))))
		# kc-ui4 (head naming): the name stays the card's (chassis) name; the art's name is its subname.
		if BannerArtDB.is_card_art(art):
			view["licensed_art"] = String(art.id)
		elif not art.is_default:
			view["art_id"] = String(art.id)
		# kc-trait-ui (head): no art subname on the mulligan card (the inspector shows it).
		entries.append({"uid": rc.uid, "id": rc.card.id, "name": String(view["name"]), "cost": rc.card.cost, "view": view,
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
		res = state.mulligan(me_side, put_back)
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
	var rc: RulesCard = state.sides[me_side].find_in_hand(uid) if state != null else null
	if rc == null:
		return
	if rc.card.cost > state.sides[me_side].supply:
		_screen.show_toast(PlayText.describe(state.can_submit(me_side, RulesIntent.play_card(uid, 0)),
				{"name": rc.card.display_name})["reason"])
	elif _unit_target_kind() == &"friendly":
		_screen.show_toast("Pick one of your units to move.")
	elif _unit_target_kind() == &"enemy":
		_screen.show_toast("Pick an enemy unit.")


func select_operator() -> void:
	selection = {"kind": &"operator"}
	target_uid = -1
	_show_selection()
	# kc-syn §6.3: placing the Operator costs Supply; say so at once when it can't be paid.
	var s: RulesSide = state.sides[me_side] if state != null else null
	if s != null and s.operator_can_deploy and not _has_play(&"place") and state.operator_cost() > s.supply:
		_screen.show_toast("Not enough Supply: your Operator costs %d, you have %d." % [state.operator_cost(), s.supply])


## Killstreak button: select it for targeting, or queue it at
## once when it needs no choice. A blocked item only toasts why. Returns the engine's check.
func select_item(item_id: StringName) -> Dictionary:
	if state == null:
		return {"ok": false, "code": &"no_match", "reason": "", "data": {}}
	var item: LoadoutItem = state.find_item(me_side, item_id)
	var check: Dictionary = state.check_use(me_side, item_id)
	if item == null or not check["ok"]:
		clear_selection()
		_screen.show_toast(PlayText.describe(check, _item_ctx(item))["reason"])
		return check
	var targets: Array[Dictionary] = state.legal_targets(me_side, item_id)
	var kind: StringName = state.needs_unit_target(me_side, item_id)
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
	var res: Dictionary = state.submit(me_side, intent)
	intent_log.append({"intent": intent, "result": res})
	intent_submitted.emit(intent, res)
	if res["ok"]:
		clear_selection()
		_after_change()
		if intent["type"] == RulesIntent.USE_ITEM:
			var item: LoadoutItem = state.find_item(me_side, intent["item_id"])
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
		var phase_check: Dictionary = state.can_submit(me_side, {"type": &"probe"})
		if phase_check["code"] in [&"wrong_phase", &"already_ready"]:
			return PlayText.describe(phase_check)
		return _no("", "Drop it on a column.")
	if selection.get("kind") == &"card" and state.sides[me_side].find_in_hand(int(selection["uid"])) == null:
		return _no("", "That card is not in your hand any more.")
	var r: Dictionary = state.can_submit(me_side, _intent_for(zone))
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
			var s: RulesSide = state.sides[me_side]
			return "PLACE HERE" if s.operator_can_deploy and not _has_play(&"place") else "ROTATE HERE"
		&"item":
			var item: LoadoutItem = state.find_item(me_side, selection["id"])
			if item != null and item.slot == DataEnums.LoadoutSlot.KILLSTREAK:
				return "CALL IN HERE"
			return "TARGET COLUMN"
	var card: CardData = state.sides[me_side].find_in_hand(int(selection["uid"])).card
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
			return _item_ctx(state.find_item(me_side, selection["id"]))
		&"card":
			var rc: RulesCard = state.sides[me_side].find_in_hand(int(selection["uid"]))
			if rc != null:
				return {"name": rc.card.display_name, "kind": &"move" if _unit_target_kind() == &"friendly" else &"card"}
	return {}


func _item_ctx(item: LoadoutItem) -> Dictionary:
	if item == null:
		return {"name": "That item", "kind": &"item"}
	var t: int = StreakTracker.threshold_for(state, me_side, item) if item.slot == DataEnums.LoadoutSlot.KILLSTREAK else 0
	return {"name": item.display_name, "kind": &"item", "threshold": t}


func _intent_for(zone: int) -> Dictionary:
	match selection.get("kind"):
		&"operator":
			var s: RulesSide = state.sides[me_side]
			if s.operator_can_deploy and not _has_play(&"place"):
				return RulesIntent.place_operator(zone)
			return RulesIntent.rotate(zone)
		&"item":
			if _unit_target_kind() == &"enemy":
				return RulesIntent.use_item(selection["id"], -1, target_uid)
			return RulesIntent.use_item(selection["id"], zone)
	var uid: int = int(selection["uid"])
	var rc: RulesCard = state.sides[me_side].find_in_hand(uid)
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
	return state.needs_unit_target(me_side, _what())


## Units that can be picked for the selection: the engine's legal targets.
func _target_candidates(_kind: StringName = &"") -> Array:
	var out: Array = []
	for t: Dictionary in state.legal_targets(me_side, _what()):
		var uid: int = int(t["target_uid"])
		if uid >= 0 and uid not in out:
			out.append(uid)
	return out


func _enemy_zone(uid: int) -> int:
	var u: RulesUnit = state.sides[foe_side].find_unit(uid)
	return u.zone if u != null else MatchState.NO_ZONE


func _has_play(kind: StringName) -> bool:
	for p: Dictionary in state.sides[me_side].plays:
		if p["kind"] == kind:
			return true
	return false


## Lane frames / badges, the selected chip / item and the pickable units for the selection.
func _show_selection() -> void:
	if _screen == null or not _screen.is_node_ready():
		return
	var board: Control = _screen.get_board()
	_screen.get_hand().set_selected(int(selection.get("uid", -1)) if selection.get("kind") == &"card" else -1)
	if _screen.has_method(&"show_card_dock"):
		_screen.show_card_dock(_dock_view())
	_screen.get_operator_panel().set_selected(selection.get("kind") == &"operator")
	_screen.get_operator_panel().set_selected_item(StringName(selection.get("id", &"")) if selection.get("kind") == &"item" else &"")
	if _screen.has_method(&"show_selection_state"):
		_screen.show_selection_state(selection.get("kind") == &"operator",
				StringName(selection.get("id", &"")) if selection.get("kind") == &"item" else &"")
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
		var entry: Dictionary = ghost
		var chips: String = ""
		if ok:
			# kc-syn-ui (head A): the ghost shows the RESULTING stats in this column (range, auras,
			# links, sets), and the column badge names what the card would switch on.
			var g: Dictionary = _ghost_for_zone(ghost, z)
			entry = g["entry"]
			chips = String(g["chips"])
		ghosts.append({"entry": entry, "front": bool(ghost.get("front_kw", false))} if ok else {})
		if ok and bool(ghost.get("front_kw", false)):
			targets[z]["text"] = "TAKES THE FRONT"
		if ok and chips != "":
			targets[z]["chips"] = chips
	board.show_targets(targets)
	board.show_ghosts(ghosts)
	board.set_unit_targets([target_uid] if target_uid >= 0 else [])


## kc-syn-ui: the landing ghost of the selection in column z: {entry (resulting FP / Cover with
## their trend, keyword pip lit if its link would be on), links (new links: ghost ticks), chips
## (the badge's second line: "VANGUARD 3 ON · +1 FP")}.
func _ghost_for_zone(ghost: Dictionary, z: int) -> Dictionary:
	var out: Dictionary = {"entry": ghost, "links": [], "chips": ""}
	var b: Dictionary = {}
	if selection.get("kind") == &"card":
		b = StatBreakdown.of_ghost(state, me_side, int(selection["uid"]), z)
	elif selection.get("kind") == &"operator" and state.sides[me_side].operator_unit != null \
			and not state.sides[me_side].operator_unit.is_on_board():
		b = StatBreakdown.of_operator_ghost(state, me_side, z)
	if b.is_empty():
		return out
	var e: Dictionary = ghost.duplicate()
	e["fp"] = int(b["fp"]["total"])
	e["fp_base"] = int(b["fp"]["base"])
	e["fp_trend"] = StatBreakdown.trend(b["fp"])
	e["cover"] = int(b["cover"]["total"])
	e["cover_trend"] = StatBreakdown.trend(b["cover"])
	var pv: Dictionary = b.get("preview", {})
	var bits: PackedStringArray = []
	if bool(pv.get("ok", false)):
		var uid: int = int(ghost.get("uid", -1))
		var active: bool = false
		for l: Dictionary in pv.get("links", []):
			if StringName(l["kind"]) == SynergyRules.FIRETEAM:
				active = active or int(l["to_uid"]) == uid
			elif int(l["from_uid"]) == uid:
				active = true
		e["kw_active"] = active
		var t: StringName = StringName(String(ghost.get("trait", "")))
		if t != &"":
			e["trait_tier"] = int((pv["tiers_after"] as Dictionary).get(t, 0))
		for tt: StringName in SynergyRules.TRAITS:
			var before: int = int((pv["tiers_before"] as Dictionary).get(tt, 0))
			var after: int = int((pv["tiers_after"] as Dictionary).get(tt, 0))
			if after > before:
				bits.append("%s %d ON" % [SynergyGlyphs.trait_name(tt).to_upper(), after])
		var syn: Dictionary = pv.get("card", {})
		if int(syn.get("fp", 0)) > 0:
			bits.append("+%d FP" % int(syn["fp"]))
		if int(syn.get("cover", 0)) > 0:
			bits.append("COVER +%d" % int(syn["cover"]))
		# kc-pos-cut: no link part in the preview any more (units no longer link).
	out["entry"] = e
	out["chips"] = " · ".join(bits.slice(0, 2))
	return out


## Banner entry of the selected unit card / Operator (for the landing ghost), {} for anything else.
func _ghost_entry() -> Dictionary:
	var me: RulesSide = state.sides[me_side]
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
			e["kw"] = String(rc.neighbor_keyword())
			e["trait"] = String(rc.card_trait())
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
	if state == null or _swallow_tap():
		return
	# kc-v2-ui: a tap on a Terrain chip with nothing selected says its rule; with a card selected the
	# chip is part of the column (play there).
	if slot_side == &"terrain":
		if selection.is_empty():
			show_terrain_rule(zone)
			return
		slot_side = &"objective"
	if selection.is_empty():
		return
	_pick_or_play(zone, slot_side, uid)


## kc-v2-ui: the column's Terrain rule as a toast ("Smoke · column B: No Pick or Flank here ...").
func show_terrain_rule(zone: int) -> void:
	var t: Dictionary = RunV2Views.terrain_at(RunV2Views.terrain_view(state), zone)
	if t.is_empty():
		return
	_screen.show_toast("%s · column %s: %s Both sides." % [t["name"], MatchSnapshot.ZONE_LABELS[zone], t["text"]])


## kc-v2-ui: the Terrain inspector of a column.
func _open_terrain(zone: int) -> void:
	var t: Dictionary = RunV2Views.terrain_at(RunV2Views.terrain_view(state), zone)
	if t.is_empty():
		_open_objective(zone)
		return
	var info: Dictionary = (load("res://scripts/ui/run/map_v2_view.gd") as GDScript).call(&"terrain_info", t)
	var held: String = String(t.get("held_by", ""))
	if held != "":
		info["status"] = "Held at the start of this round by %s." % ("you" if held == "player" else "the rival")
	_open_info(info)


## kc-v2-ui: the Operator ability button (run-v2-api.md §5): select it like a killstreak (targets,
## preview, Undo); a spent or blocked ability only says why.
func use_ability() -> Dictionary:
	if state == null or _swallow_tap():
		return {"ok": false, "code": &"busy", "reason": "", "data": {}}
	var a: Dictionary = RunV2Views.ability_view(state, me_side)
	if a.is_empty():
		return {"ok": false, "code": &"no_ability", "reason": "", "data": {}}
	if not bool(a.get("ready", false)):
		var why: String = String(a.get("reason", "Used this match"))
		_screen.show_toast("%s: %s." % [a.get("name", "Ability"), why.trim_suffix(".")])
		return {"ok": false, "code": StringName(str(a.get("code", "not_ready"))), "reason": why, "data": {}}
	if selection.get("kind") == &"item" and StringName(selection.get("id", &"")) == a["id"]:
		clear_selection()
		return {"ok": true, "code": &"deselected", "reason": "", "data": {}}
	return select_item(a["id"])


## kc-v2-ui: the ability's inspector (text, targets, once per match).
func open_ability_inspector() -> void:
	var a: Dictionary = RunV2Views.ability_view(state, me_side) if state != null else {}
	var k: Dictionary = RunV2Views.operator_kit_view(state, me_side) if state != null else {}
	if a.is_empty() and k.is_empty():
		return
	var target_words: Dictionary = {&"zone": "Pick a column.", &"enemy": "Pick an enemy unit in your Operator's column.", &"none": "No target."}
	var state_line: String = "Ready: free, once per match." if bool(a.get("ready", false)) else ("Used this match." if bool(a.get("used", false)) else String(a.get("reason", "")))
	_open_info({"title": String(a.get("name", k.get("ability_name", "Ability"))), "type": "operator ability · once per match · 0 supply",
			"text": String(a.get("text", k.get("ability_text", ""))),
			"keywords": [{"name": "Targets", "text": String(target_words.get(StringName(str(a.get("target", "zone"))), ""))},
				{"name": "Passive · %s" % k.get("passive_name", ""), "text": String(k.get("passive_text", ""))},
				{"name": "Once per match", "text": "Free, played in Deploy like a killstreak, with the same preview and UNDO. It isn't a killstreak: it needs no streak and isn't lost when your Operator goes down."}],
			"status": state_line})


## kc-cards-impl (H1): the Y2+ face of the selected hand card for the tray's dock ({} = none).
func _dock_view() -> Dictionary:
	if state == null or selection.get("kind") != &"card":
		return {}
	var rc: RulesCard = state.sides[me_side].find_in_hand(int(selection.get("uid", -1)))
	return card_view_for(rc) if rc != null else {}


## kc-cards-impl: the Y2+ CardView data of a card in your hand (its art, trait, Standard Issue,
## can't pay). kc-ipad-cards: no level, no locked keywords.
func card_view_for(rc: RulesCard) -> Dictionary:
	var view: Dictionary = CardInfo.view_dict(rc.card, "friend")
	var art_id: StringName = StringName(String(state.art_by_uid.get(rc.uid, rc.card.id)))
	view["banner"] = String(art_id)
	var t: StringName = rc.card_trait()
	if t != &"":
		view["trait"] = String(t)
	var e: Dictionary = StandardIssueLook.dress({}, rc.card, art_id)
	if e.has("standard_issue"):
		view["standard_issue"] = e["standard_issue"]
	view["cant_pay"] = rc.card.cost > state.sides[me_side].supply
	return view


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
	if state == null or _swallow_tap() or state.sides[me_side].operator_unit == null:
		return
	select_operator()
	_dragging = true
	# A small chip with the Operator's name, not a copy of the whole panel.
	var chip: PanelContainer = PanelContainer.new()
	chip.theme_type_variation = &"HandCardSelected"
	var label: Label = Label.new()
	label.theme_type_variation = &"UnitName"
	label.text = MatchSnapshot.unit_name(state.sides[me_side].operator_unit, state.sides[me_side])
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
	var s: RulesSide = state.sides[me_side]
	var rc: RulesCard = s.find_in_hand(uid)
	if rc == null:
		return
	var status: String = "Costs %d Supply, you have %d." % [rc.card.cost, s.supply]
	if rc.card.cost > s.supply:
		status += " Not enough to play it now."
	open_card_inspector(rc.card, "friend", status, {}, -1, uid,
			synergy_lines(rc.card, me_side, null, rc.chosen_trait))


func _on_operator_inspected() -> void:
	if state == null or state.sides[me_side].operator_unit == null:
		return
	_open_operator(me_side)


func _on_lane_long_pressed(zone: int, slot_side: StringName, uid: int) -> void:
	if state == null:
		return
	match slot_side:
		&"objective":
			_open_objective(zone)
			return
		&"terrain":
			_open_terrain(zone)
			return
		&"incoming":
			_open_info({"banner_back": true, "title": "Incoming rival play",
					"type": "hidden · %s" % ZONE_WORDS[zone],
					"text": "The rival committed a unit to %s this Deploy. It stays face down until Reveal, then flips and slides in from the top edge to this slot (a Protector slides on to the front)." % ZONE_WORDS[zone],
					"status": "Recon Drone or Callout can spot it before Reveal."})
			return
		&"field_player", &"field_enemy":
			_open_field(zone, me_side if slot_side == &"field_player" else foe_side, uid)
			return
	if uid < 0:
		return
	var side: int = me_side if slot_side == &"player" else foe_side
	var s: RulesSide = state.sides[side]
	if s.operator_unit != null and s.operator_unit.uid == uid:
		_open_operator(side)
		return
	var u: RulesUnit = s.find_unit(uid)
	if u != null and u.card != null:
		var row: int = s.lines[zone].find(u) + 1
		var status: String = "In %s, row %d%s: FP %d, Armor %d/%d." % [ZONE_WORDS[zone], row,
				" (frontline)" if row == 1 else "",
				state.firepower_of(u), u.armor, u.max_armor(state.round_number)]
		open_card_inspector(u.card, "friend" if side == me_side else "enemy", status, MatchSnapshot.unit_entry(state, u, s), side,
				-1, synergy_lines(u.card, side, u, u.chosen_trait))
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
			open_card_inspector(card, "friend", "Queued for %s (PLAN). It arrives at Reveal." % ZONE_WORDS[zone], e3, me_side)
			return


## kc-syn-ui: the inspector's synergy lines for a copy (hand card: u = null; board unit: live):
## where its FP / Cover come from ("FP 4 = 2 base +1 Spotter (Marksman, behind) +1 Vanguard 2"),
## its neighbour keyword (what it uses, whether the link is on, with whom) and its trait (count in
## play, tier texts).
## kc-trait-ui: `chosen` = the copy's own trait (RulesCard / RulesUnit.chosen_trait): two copies of
## one card can carry different traits, so the trait line names this copy's and where it comes from.
func synergy_lines(card: CardData, side: int, u: RulesUnit,
		chosen: StringName = SynergyRules.TRAIT_DEFAULT) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if card == null or state == null:
		return out
	var syn: Dictionary = {}
	if u != null and u.is_on_board():
		var b: Dictionary = StatBreakdown.of_unit(state, u)
		syn = b["syn"]
		out.append({"name": "Firepower now", "text": StatBreakdown.line("FP", b["fp"])})
		if int(b["cover"]["total"]) > 0 or not (b["cover"]["parts"] as Array).is_empty():
			out.append({"name": "Cover now", "text": StatBreakdown.line("Cover", b["cover"])})
		if bool(b["fs"]):
			out.append({"name": "First Shot (set)", "text": "Its trait set gives it First Shot."})
		if int(b["heal"]) > 0:
			out.append({"name": "Undead heal", "text": "At the end of the round it heals %d (never above its max Armor)." % int(b["heal"])})
	var kw: StringName = SynergyRules.keyword_at(card)
	if kw != &"":
		var state_word: String = ""
		if u != null and u.is_on_board():
			var partners: PackedStringArray = []
			for l: Dictionary in state.synergy_side(side)["links"]:
				if StringName(l["kind"]) != kw:
					continue
				if kw == SynergyRules.FIRETEAM and int(l["to_uid"]) == u.uid:
					partners.append(StatBreakdown.name_of(state, int(l["from_uid"])))
				elif kw != SynergyRules.FIRETEAM and int(l["from_uid"]) == u.uid:
					partners.append(StatBreakdown.name_of(state, int(l["to_uid"])))
			state_word = (" Link ON with %s." % ", ".join(partners)) if not partners.is_empty() else " Link idle: nobody stands there now."
		out.append({"name": "%s (neighbour keyword)" % SynergyGlyphs.keyword_name(kw),
				"text": "%s It uses %s.%s" % [String(SynergyRules.KEYWORD_TEXT[kw]), SynergyGlyphs.KEYWORD_USES[kw], state_word]})
	var t: StringName = SynergyRules.trait_at(card, chosen)
	if t == &"" and card.has_trait_choice():
		var tc: StringName = card.card_trait if chosen == SynergyRules.TRAIT_DEFAULT else chosen
		out.append({"name": "Trait: none", "text": "Its art is a plain art: this copy joins no set. Can be: %s." % _options_text(card)})
	if t != &"":
		var sv: Dictionary = state.synergy_side(side)
		var n: int = int((sv["counts"] as Dictionary).get(t, 0))
		var tier: int = int((sv["tiers"] as Dictionary).get(t, 0))
		var doc: bool = state.sides[side].setup.doctrine == t
		var parts: PackedStringArray = ["%d in play%s." % [n, " (Doctrine +1)" if doc else ""]]
		for k: int in [2, 3]:
			parts.append("%d: %s%s." % [k, String(SynergyRules.TIER_TEXT[t][k - 2]), " (ON)" if tier >= k else ""])
		if card.has_trait_choice():
			# art-traits §8: "Trait: Heavy (from the art: Mastery family)".
			parts.insert(0, "From the art: %s family. Can be: %s." % [ArtTraits.FAMILY_NAMES[ArtTraits.family_for_trait(t)], _options_text(card)])
		out.append({"name": "%s (trait)" % SynergyGlyphs.trait_name(t), "text": " ".join(parts)})
	if card.standard_issue:
		# kc-onboard-ui: Standard Issue kit: Muster out / Retire sends it home.
		out.append({"name": "Standard Issue %s" % RunProgress.standard_issue_serial(card),
				"text": "Basic kit: no keyword, no trait. Muster out or Retire sends it home."})
	return out


## "Spec Ops · Heavy": the trait options of a chassis (art-traits §3).
static func _options_text(card: CardData) -> String:
	var names: PackedStringArray = []
	for t: StringName in card.trait_choices():
		names.append(ArtTraits.trait_name(t))
	return " · ".join(names)


func open_card_inspector(card: CardData, side: String, status: String, banner: Dictionary = {}, banner_side: int = -1, card_uid: int = -1,
		extra_lines: Array[Dictionary] = []) -> void:
	var type_text: String = String(CardInfo.TYPE_WORDS.get(card.card_type, "card"))
	# kc-ipad-cards (the head: "leave out the gun type"): the weapon class is never shown.
	if card.is_unit():
		type_text += " · FP %d · Armor %d" % [card.firepower, card.armor]
	type_text += " · cost %d" % card.cost
	var keywords: Array[Dictionary] = CardInfo.keywords(card)
	var printed: Array[Dictionary] = keywords.duplicate()
	keywords.append_array(extra_lines)
	# Units whose rules text only lists their keywords ("Pick") get the keyword lines instead.
	var names: PackedStringArray = []
	for k: Dictionary in printed:
		names.append(String(k["name"]).to_lower())
	var text: String = "" if card.text.to_lower().trim_suffix(".") == ", ".join(names) else card.text
	if banner.is_empty():
		banner = {"name": card.display_name, "fp": card.firepower, "armor": card.armor, "armor_max": card.armor,
				"cls": String(CardInfo.CLASS_WORDS.get(card.weapon_class, "")).to_upper(),
				"keywords": CardInfo.icon_keywords(CardInfo.keywords(card))}
		MatchSnapshot._banner_fields(banner, card, null, state.sides[me_side], state, card_uid)
	var art: BannerArt = BannerArtDB.get_art(StringName(String(banner.get("banner", card.id))))
	if card.is_field():
		text = _join(text, FIELD_RULE)
	var view: Dictionary = CardInfo.view_dict(card, side)
	# kc-ui4 (head naming): the title is the card's name; the art's subname leads the type line.
	if BannerArtDB.is_card_art(art):
		view["licensed_art"] = String(art.id)
	elif not art.is_default:
		view["art_id"] = String(art.id)
	var sub: String = BannerArtDB.subname(art.id)
	if sub != "":
		view["subname"] = sub
	# kc-cards-impl: the Y2+ face shows the copy's art and trait (lit while its set is on).
	view["banner"] = String(art.id)
	for k: String in ["trait", "standard_issue", "armor_max", "fp_trend"]:
		if banner.has(k) and str(banner[k]) != "":
			view[k] = banner[k]
	if banner.has("fp"):
		view["firepower"] = int(banner["fp"])
		view["armor"] = int(banner.get("armor", view.get("armor", 0)))
	view["trait_lit"] = int(banner.get("trait_tier", 0)) >= 2
	_screen.get_inspector().open({
		"view": view, "title": card.display_name,
		"type": ("%s · %s" % [sub, type_text]) if sub != "" else type_text,
		"text": text, "keywords": keywords, "status": status,
		"banner": banner, "side": banner_side if banner_side >= 0 else (me_side if side == "friend" else foe_side),
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
	var alts: Array[StringName] = BannerArtDB.alt_arts(art.card_id)
	# kc-trait-ui: each copy comes with its own art (no EQUIP); the Codex shows every art.
	return "Banner: %s%s · art %d of %d (every art is in the Codex)" % [what, " (placeholder)" if art.placeholder else "",
			maxi(1, alts.find(art.id) + 1), maxi(1, alts.size())]


## Inspector for something that is not a card in hand (objective tile, incoming back, rails).
func _open_info(info: Dictionary) -> void:
	var d: Dictionary = info.duplicate()
	d["view"] = {}
	d["side"] = int(info.get("side", me_side))
	_screen.get_inspector().open(d)


## Long-press / right-click on a rail box (studio rule: everything can be inspected).
func _on_rail_inspected(key: StringName) -> void:
	if state == null:
		return
	var me: RulesSide = state.sides[me_side]
	var foe: RulesSide = state.sides[foe_side]
	match key:
		&"score":
			var goal: String = String(state.config.get_meta(&"goal_text")) if state.config.has_meta(&"goal_text") else ""
			var ini_s: Dictionary = MatchSnapshot.initiative_info(state, me_side)
			_open_info({"title": "Score", "type": "round %d · %s" % [state.round_number, String(MatchState.PHASE_NAMES[state.phase]).to_lower()],
					"text": "You %d, rival %d. %s" % [me.score, foe.score, goal],
					"status": "Each round you score the columns you control. Initiative (the flag): %s %s" % [
						"you go first." if bool(ini_s.get("mine", true)) else "the rival goes first.", String(ini_s.get("reason", ""))]})
		&"deck":
			_open_info({"title": "Your deck", "type": "deck · discard",
					"text": "%d cards left to draw, %d in the discard pile. You draw %d card%s at the start of each round; the hand holds up to %d. When the deck is empty, the discard pile is shuffled into a new deck." % [
							me.deck.size(), me.discard.size(), state.config.draws_per_round, "" if state.config.draws_per_round == 1 else "s", state.config.hand_cap],
					"status": ""})
		&"intel":
			var dots: PackedInt32Array = state.red_dots(me_side)
			_open_info({"title": "Rival intel", "type": "rival hand · incoming plays",
					"text": "The rival holds %d cards. Hidden plays this Deploy: A %d, B %d, C %d. Each shows on the board as an INCOMING back in the slot where it will land." % [foe.hand.size(), dots[0], dots[1], dots[2]],
					"status": "Recon Drone and Callout reveal what they are."})
		&"supply":
			_open_info({"title": "Supply", "type": "resource",
					"text": "%d of %d Supply left this round. Cards cost Supply to play; it refills (and grows) each round." % [me.supply, state.config.supply_for_round(state.round_number)],
					"status": ""})
		# kc-board2: the icon strip's other badges and the tray's controls.
		&"streak":
			var names: PackedStringArray = []
			for item: LoadoutItem in me.setup.killstreaks:
				if item != null:
					names.append("%s at %d" % [item.display_name, StreakTracker.threshold_for(state, me_side, item)])
			_open_info({"title": "Killstreaks", "type": "streak %d" % me.streak,
					"text": "Eliminations build your streak; each killstreak is earned at its threshold (%s) and called in from this badge." % ", ".join(names),
					"status": "The badge glows amber when one is ready."})
		&"menu":
			_open_info({"title": "Menu", "type": "pause", "text": "Pause the match: fast animations, mirror layout (tray on the left), forfeit, quit to title.", "status": ""})
		&"preview":
			_open_info({"title": "Preview", "type": "forecast",
					"text": "Shows the forecast of this round's firefight on the objective tiles, from what you can see (P).", "status": ""})
		&"killfeed":
			_open_info({"title": "Killfeed", "type": "this round",
					"text": "Every elimination of the round, oldest first. Short toasts also show at the top of the board.", "status": ""})
		&"traits":
			_open_info({"title": "Sets (traits)", "type": "trait rail · yours%s" % ("" if _screen.compact else " and the rival's"),
					"text": "Calling cards and Fields share a trait (one trait per card at most) (Vanguard, Spec Ops, Heavy, Undead). With 2 of a trait in play, tier 2 turns on for that trait's units; with 3, tier 3 as well. Each chip shows the count over the next threshold; a lit icon = tier 2, a ring = tier 3. Standard Issue cards have no trait.",
					"status": "Tap the rail for every tier text. Long-press a chip for that trait."})
		&"initiative":
			var ini: Dictionary = MatchSnapshot.initiative_info(state, me_side)
			_open_info({"title": "Initiative", "type": "round %d · %s first" % [state.round_number, "you go" if bool(ini.get("mine", true)) else "the rival goes"],
					"text": "%s %s" % [String(ini.get("reason", "")), String(ini.get("effect", ""))],
					"status": "Initiative goes to the side behind on score; %s. The flag on SCORE shows who has it." % String(MatchSnapshot.TIE_RULE_WORDS.get(ini.get("tie_rule", &"player"), "the tie rule decides a tie"))})
		&"hand_tab":
			_open_info({"title": "Your hand", "type": "%d cards" % me.hand.size(),
					"text": "The hand tray opens on its own in Deploy. Outside Deploy, PEEK shows your cards read-only (NEXT DEPLOY); long-press a card for its rules.", "status": ""})


## kc-syn-ui: one trait's rules from its rail chip (side &"player" / &"enemy").
func open_trait_inspector(side_name: StringName, t: StringName) -> void:
	if state == null:
		return
	var side: int = me_side if side_name == &"player" else foe_side
	var sv: Dictionary = state.synergy_side(side)
	var n: int = int((sv["counts"] as Dictionary).get(t, 0))
	var tier: int = int((sv["tiers"] as Dictionary).get(t, 0))
	var members: PackedStringArray = []
	for u: RulesUnit in state.sides[side].units_on_board():
		if u.synergy_trait == t:
			members.append(StatBreakdown.name_of(state, u.uid))
	var doc: bool = state.sides[side].setup.doctrine == t
	var lines: Array[Dictionary] = []
	for k: int in [2, 3]:
		lines.append({"name": "%s %d%s" % [SynergyGlyphs.trait_name(t), k, " (ON)" if tier >= k else ""], "text": String(SynergyRules.TIER_TEXT[t][k - 2]) + "."})
	_open_info({"title": SynergyGlyphs.trait_name(t), "type": "trait · %s · %d in play" % ["yours" if side == me_side else "rival", n],
			"text": "In play: %s.%s Units and visible Fields count; tactics and hidden traps don't." % [
				", ".join(members) if not members.is_empty() else "only Fields", " Doctrine adds 1 to this count." if doc else ""],
			"keywords": lines, "side": side,
			"status": "Tier 2 is on." if tier == 2 else ("Tiers 2 and 3 are on." if tier >= 3 else "Needs %d in play for tier 2." % SynergyRules.TIER2)})


func _open_objective(zone: int) -> void:
	var lane: Dictionary = MatchSnapshot.build(state, map, me_side, killfeed)["lanes"][zone]
	var control_text: String = {&"player": "You control it", &"enemy": "The rival controls it",
			&"contested": "Even (contested): both sides have units here", &"empty": "Nobody holds it"}.get(lane["control"], "")
	var lines: PackedStringArray = []
	var terr: Dictionary = lane.get("terrain", {})
	if not terr.is_empty():
		lines.append("Terrain · %s: %s (both sides)." % [terr["name"], String(terr["text"]).trim_suffix(".")])
	lines.append("%s. A side controls a column when it has at least one unit there and the other side has none (a Holder breaks a tie)." % control_text)
	lines.append("Column Firepower: yours %d, rival %d." % [int(lane["fp_player"]), int(lane["fp_enemy"])])
	for key: String in ["player", "enemy"]:
		for f: Dictionary in (lane["fields"] as Dictionary).get(key, []):
			lines.append("%s Field: %s%s." % ["Your" if key == "player" else "Rival", f["name"], " (hidden trap)" if f.get("hidden", false) else ""])
	_open_info({"title": "Objective %s · %s" % [String(lane["label"]), String(lane["name"]).capitalize()],
			"type": "objective · column %s" % String(lane["label"]), "text": "\n".join(lines),
			"status": "Row 1 on each side touches the objective: that card is the frontline."})


func _open_field(zone: int, side: int, uid: int) -> void:
	var s: RulesSide = state.sides[side]
	var rc: RulesCard = null
	var risk: bool = false
	for entry: Dictionary in state.fields_in(side, zone, side == me_side):
		if (entry["card"] as RulesCard).uid == uid:
			rc = entry["card"]
	for p: Dictionary in s.plays:
		if p["kind"] == &"equipment" and (p["card"] as RulesCard).uid == uid:
			rc = p["card"]
	if rc == null:
		return
	var control: int = state.control_of(zone)
	risk = rc.card.is_visible_field() and control == 1 - side
	var status: String = "On %s's half of objective %s." % ["your" if side == me_side else "the rival", MatchSnapshot.ZONE_LABELS[zone]]
	if rc.card.hidden:
		status = "Hidden trap: the rival can't see it. Traps are never overrun."
	elif risk:
		status = "OVERRUN RISK: the %s controls this column now. If it still does at the end of the round, this Field is destroyed." % ("rival" if side == me_side else "you")
	status += " Removed by: Overrun, Sabotage, or a newer Field of the same side here."
	open_card_inspector(rc.card, "friend" if side == me_side else "enemy", status, {}, side)


## kc-ui3: a loadout item's rules (long-press on a killstreak tile): its card, threshold, what it does
## and, in plain words, whether you can call it in now.
func open_item_inspector(item_id: StringName) -> void:
	if state == null:
		return
	var item: LoadoutItem = state.find_item(me_side, item_id)
	if item == null:
		return
	var me: RulesSide = state.sides[me_side]
	var is_ks: bool = item.slot == DataEnums.LoadoutSlot.KILLSTREAK
	var threshold: int = StreakTracker.threshold_for(state, me_side, item) if is_ks else 0
	var check: Dictionary = state.check_use(me_side, item_id)
	var status: String = ""
	if check["ok"]:
		status = "Ready: tap its tile, then a target, to call it in." if is_ks else "Ready to use."
	elif is_ks and not me.streak_tray.has(item.id):
		status = "Streak %d of %d: %d more elimination%s to earn it." % [me.streak, threshold, maxi(0, threshold - me.streak),
				"" if threshold - me.streak == 1 else "s"]
	else:
		status = String(PlayText.describe(check, _item_ctx(item))["reason"])
	var icon: String = String({&"recon_drone": "ks_recon_drone", &"mortar_barrage": "ks_mortar", &"sentry_turret": "ks_sentry",
			&"attack_helo": "ks_attack_helo", &"gunship": "ks_gunship"}.get(item.id, ""))
	var view: Dictionary = {"name": item.display_name, "type": "killstreak" if is_ks else "tactic", "threshold": threshold,
			"cost": item.supply_cost, "art_icon": icon, "id": String(item.id), "text": item.text, "side": "friend"}
	var type_text: String = ("killstreak · earned at streak %d" % threshold) if is_ks else "loadout item"
	if item.supply_cost > 0:
		type_text += " · cost %d" % item.supply_cost
	_screen.get_inspector().open({"view": view, "title": item.display_name, "type": type_text, "text": item.text,
			"keywords": [], "status": status, "side": me_side})


func _open_operator(side: int) -> void:
	var s: RulesSide = state.sides[side]
	var op: RulesUnit = s.operator_unit
	var title: String = MatchSnapshot.unit_name(op, s)
	var where: String = "Off the board."
	if op.is_on_board():
		where = "In %s: FP %d, Armor %d/%d." % [ZONE_WORDS[op.zone], state.firepower_of(op), op.armor, op.max_armor(state.round_number)]
	elif side == me_side and s.operator_can_deploy:
		where = "Off the board: tap it, then a column, to place it."
	var cost: int = state.operator_cost()
	var respawn_cost: int = maxi(0, state.config.operator_cost)
	if cost > 0:
		where += " Placing it costs %d Supply (%s)%s." % [cost,
				"every respawn; round 1 is free" if state.config.operator_free_round1 else "round 1 and every respawn",
				", you have %d: not enough now" % s.supply if side == me_side and s.operator_can_deploy and cost > s.supply else ""]
	elif respawn_cost > 0 and state.config.operator_free_round1:
		# kc-econ: round 1's placement is free; say what a respawn will cost.
		where += " Free to place in round 1; a respawn costs %d Supply." % respawn_cost
	var op_lines: Array[Dictionary] = CardInfo.operator_keywords(op)
	# kc-v2-ui: the Operator kit (run-v2.md §7): its passive and its once-per-match ability.
	var kit: Dictionary = RunV2Views.operator_kit_view(state, side)
	if not kit.is_empty() and String(kit.get("passive_name", "")) != "":
		op_lines.append({"name": "P · Passive · %s" % kit["passive_name"], "text": String(kit.get("passive_text", ""))})
	if not kit.is_empty() and String(kit.get("ability_name", "")) != "":
		var ab: Dictionary = RunV2Views.ability_view(state, side)
		var ab_state: String = "ready" if bool(ab.get("ready", false)) else ("used" if bool(ab.get("used", false)) else String(ab.get("reason", "not now")).to_lower())
		op_lines.append({"name": "Ability · %s (once per match, free, %s)" % [kit["ability_name"], ab_state], "text": String(kit.get("ability_text", ""))})
	if not kit.is_empty() and not bool(kit.get("kit_on", true)):
		op_lines.append({"name": "Kit off this fight", "text": "The passive and the ability switch on from your second fight."})
	op_lines.append({"name": "Not from the deck", "text": "Your Operator is always with you: it is never drawn, never discarded, and its card stays pinned at the start of your hand."})
	if op.is_on_board():
		op_lines.append({"name": "Firepower now", "text": StatBreakdown.line("FP", StatBreakdown.of_unit(state, op)["fp"])})
	var view: Dictionary = CardInfo.operator_view_dict(op, title)
	view["side"] = "friend" if side == me_side else "enemy"
	view["cost"] = cost  # kc-loadout-cut: the Supply cost in the card's cost badge, like a deck card
	var op_art: BannerArt = BannerArtDB.get_art(StringName(String(MatchSnapshot.unit_entry(state, op, s)["banner"])))
	if op_art.licensed:
		view["licensed_art"] = String(op_art.id)  # kc-cod3: the mastery card in the card picture too
	_screen.get_inspector().open({
		"view": view, "title": title, "type": "operator",
		"text": String(view["text"]), "keywords": op_lines, "status": where,
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


# =============================================================================
# Events -> EventBus, killfeed
# =============================================================================

func _flush_events() -> void:
	if state == null:
		return
	while _cursor < state.events.size():
		var e: Dictionary = state.events[_cursor]
		_cursor += 1
		if e.has("private_to") and e["private_to"] != MatchState.SIDE_NAMES[me_side]:
			continue
		if e["type"] == RulesEvent.UNIT_ELIMINATED:
			_add_killfeed(e)
		_add_v2_line(e)
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


## kc-v2-ui: Terrain triggers, boss rules and Operator abilities go in the log in words, so the
## player always knows what just happened ("Minefield: Grunt takes 1", "Kestrel: Dig In, column B").
func _add_v2_line(e: Dictionary) -> void:
	var t: String = String(e.get("type", ""))
	var text: String = ""
	var side: StringName = StringName(str(e.get("side", "")))
	match t:
		"deck_reshuffled":
			# kc-econ: the classic deckbuilder reshuffle, said in words (both sides; it is public).
			var n: int = int(e.get("count", 0))
			text = ("Discard shuffled into a new deck (%d cards)" if side == &"player" else "Rival shuffled their discard into a new deck (%d cards)") % n
		"terrain_triggered":
			text = String(e.get("what", ""))
			if text == "":
				var td: Dictionary = RunV2Views.terrain_entry(StringName(str(e.get("terrain", ""))))
				text = "%s: %s" % [td["name"], _name_of(int(e.get("uid", -1)))]
		"boss_rule_triggered":
			text = String(e.get("what", ""))
			if text == "":
				text = "Boss rule: %s" % String(e.get("rule", "")).capitalize()
			side = &"enemy"
		"item_revealed", "item_used":
			if not bool(e.get("ability", false)) or (t == "item_used" and e.has("private_to")):
				return
			if t == "item_used" and side != &"player" and side != &"":
				return
			var item: LoadoutItem = state.find_item(me_side if side != &"enemy" else foe_side, StringName(str(e.get("item_id", ""))))
			var op: String = ""
			var s2: RulesSide = state.sides[me_side if side != &"enemy" else foe_side]
			if s2.operator_unit != null:
				op = MatchSnapshot.unit_name(s2.operator_unit, s2)
			var z: int = int(e.get("zone", -1))
			text = "%s: %s%s" % [op if op != "" else "Operator", item.display_name if item != null else "Ability",
					(", " + ZONE_WORDS[z]) if z >= 0 and z < ZONE_WORDS.size() else ""]
	if text == "":
		return
	killfeed.push_front({"text": text.to_upper(), "side": side if side != &"" else &"player", "kind": StringName(t)})
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
			if e.get("side", &"") == MatchState.SIDE_NAMES[me_side]:
				var item_id: StringName = StringName(e.get("item_id", &""))
				var item: LoadoutItem = state.find_item(me_side, item_id)
				if item != null and item.slot == DataEnums.LoadoutSlot.KILLSTREAK:
					EventBus.killstreak_used.emit(item_id, r)
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
			if e.get("side", &"") == MatchState.SIDE_NAMES[me_side]:
				EventBus.streak_changed.emit(int(e.get("streak", 0)))
		RulesEvent.KILLSTREAK_EARNED:
			if e.get("side", &"") == MatchState.SIDE_NAMES[me_side]:
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



# =============================================================================
# kc-duel-ui: Duel matches (duel-api.md §6)
# =============================================================================

var _last_supply: int = 0
var _last_hand: int = 0


## Plays a DuelMatch (or, without DuelState, a plain MatchState from DuelRules.create_match).
## vs AI: the match's tier AI plans before every Deploy (as a squad AI does). Pass & Play: the
## DuelMatch drives the turns: cover_needed -> the cover -> accept_cover -> deploy_started (the
## screen turns to that side) -> READY = finish_deploy -> round_ready -> the round plays -> round_done.
func start_duel_match(m: Object) -> bool:
	if m == null:
		return false
	is_run_match = false
	if m is MatchState:
		duel = null
		map = CardDB.get_map((m as MatchState).map_id)
		_play(m, null)
		return true
	duel = m
	var st: MatchState = m.get(&"state")
	var cfg: Resource = m.get(&"config")
	map = cfg.get(&"map") if cfg != null and cfg.get(&"map") != null else CardDB.get_map(st.map_id)
	me_side = MatchState.PLAYER
	foe_side = MatchState.ENEMY
	var ai: Object = m.get(&"ai")
	_default_planner = false
	if StringName(str(m.get(&"kind"))) != &"hot_seat" and ai != null:
		enemy_planner = func(s: MatchState) -> void: ai.call(&"take_turn", s, MatchState.ENEMY)
		_play(st, null)
		return true
	# Pass & Play.
	enemy_planner = Callable()
	m.connect(&"cover_needed", _on_duel_cover_needed)
	m.connect(&"deploy_started", _on_duel_deploy_started)
	m.connect(&"round_ready", _on_duel_round_ready)
	state = st
	RevealGate.active = false
	_cursor = 0
	killfeed.clear()
	intent_log.clear()
	selection.clear()
	_busy = false
	_end_shown = false
	_finished = false
	_match_started_ms = Time.get_ticks_msec()
	# Starts the match and raises the first cover (cover_needed).
	m.call(&"start")
	return true


func is_duel() -> bool:
	return duel != null


func is_hot_seat() -> bool:
	return duel != null and StringName(str(duel.get(&"kind"))) == &"hot_seat"


## The cover screen (null outside Pass & Play).
func get_cover() -> Control:
	return _cover


func _on_duel_cover_needed(side: int, player_name: String) -> void:
	clear_selection()
	if _screen.get_inspector().is_open():
		_screen.get_inspector().close()
	if is_mulligan_open():
		_mulligan_panel().close()
	if _cover == null:
		_cover = (load(PASS_COVER_SCENE) as PackedScene).instantiate()
		_screen.add_child(_cover)
		_cover.accepted.connect(func(s: int) -> void: duel.call(&"accept_cover", s))
	var names: Array = duel.get(&"names")
	var other: int = 1 - side
	var other_ready: bool = state.sides[other].ready
	_cover.show_for(side, player_name, {"round": state.round_number, "other_name": String(names[other]),
			"other_orders": state.sides[other].plays.size() if other_ready else -1,
			"last": _last_round_line, "mulligan": state.round_number == 1 and state.can_mulligan(side)["ok"]})


func _on_duel_deploy_started(side: int) -> void:
	me_side = side
	foe_side = 1 - side
	_begin_deploy()


func _on_duel_round_ready() -> void:
	await _play_round(_last_supply, _last_hand)


## The result for DuelFlow when the match has no result() (a plain MatchState).
func _duel_result() -> Dictionary:
	var outcome: Dictionary = state.hooks.mode_rules.outcome if state.hooks != null and state.hooks.mode_rules != null else {}
	var w: int = 0 if state.result == &"player" else (1 if state.result == &"enemy" else -1)
	return {"winner_side": w, "scores": [int(state.sides[0].score), int(state.sides[1].score)], "rounds": state.round_number,
			"reason": outcome.get("reason", &"")}


## "Round 2: Zone Control 3 - 2 (Dana - Alex)": the public line the next cover shows.
func _round_line() -> String:
	var names: Array = duel.get(&"names") if duel != null else ["You", "Rival"]
	return "After round %d: %s %d · %s %d" % [state.round_number, names[0], state.sides[0].score, names[1], state.sides[1].score]

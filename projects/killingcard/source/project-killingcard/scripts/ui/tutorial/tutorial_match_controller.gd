# tutorial_match_controller.gd
# Purpose: MatchController for the tutorial match (p15). TutorialDirector puts this script on
#   Match.tscn's MatchController node before the scene enters the tree, so match_controller.gd
#   stays untouched. With `tutorial` set it plays the TutorialScript's match instead of the
#   local test match:
#   - deterministic: stacked player and enemy draw orders (SideSetup.keep_deck_order), the
#     script's seed, round cap and score target (no overtime), no mulligan
#   - the enemy is scripted: `enemy_planner` commits TutorialScript.enemy_plays for the round
#   - input locks: intent_gate / ready_gate / undo_gate (set by the director) can refuse a play
#     before it reaches the engine; the refusal is toasted and `refused` is emitted
#   - no "Round n: Deploy" hints (the coach card says what to do)
#   Gameplay EventBus signals are off by default (a drill must not count as a run match in the
#   p16 playtest log); the director emits EventBus.tutorial_step instead.
# Dependencies: match_controller.gd, TutorialScript, TutorialEnemyPlay, MatchState, SideSetup,
#   MatchHooks, ModeRules, RulesIntent, CardDB.
# Author: UI/UX Agent (p15)
extends "res://scripts/ui/match_controller.gd"

## A play / READY / UNDO was refused by a gate (reason is what the toast says).
signal refused(reason: String)
## The selection (card, Operator, item) or its highlights changed.
signal selection_changed

var tutorial: TutorialScript = null
## (intent: Dictionary) -> String. "" lets the play through to the engine; else the refusal.
var intent_gate: Callable = Callable()
## () -> String for READY, same contract.
var ready_gate: Callable = Callable()
## () -> String for UNDO, same contract.
var undo_gate: Callable = Callable()


## Builds (not starts) the tutorial's MatchState from CardDB data. Null if data is missing.
static func build_state(script: TutorialScript) -> MatchState:
	var base: RunConfig = CardDB.get_run_config()
	if script == null or base == null or script.squad == null or script.map == null:
		return null
	var config: RunConfig = base.duplicate() as RunConfig
	config.round_cap = script.round_cap
	config.overtime_draw_round = script.round_cap
	config.zone_control_target = script.score_target
	config.firefight_target = script.score_target
	# The score target only keeps the drill from ending early; the score bar shows the round
	# count instead of "FIRST TO 20" (MatchSnapshot reads this meta; p18 bug 003).
	config.set_meta(&"goal_text", "%d-ROUND DRILL" % script.round_cap)
	var player: SideSetup = SideSetup.new()
	player.display_name = "You"
	player.deck.assign(script.player_deck)
	player.keep_deck_order = true
	player.primary = config.starter_primary
	player.secondary = config.starter_secondary
	player.lethal = config.starter_lethal
	player.tactical = config.starter_tactical
	player.killstreaks.assign(script.player_killstreaks if not script.player_killstreaks.is_empty() else config.starter_killstreaks)
	var enemy: SideSetup = SideSetup.from_squad(script.squad)
	if not script.enemy_deck.is_empty():
		enemy.deck.assign(script.enemy_deck)
	enemy.keep_deck_order = true
	var hooks: MatchHooks = MatchHooks.new()
	hooks.mode_rules = ModeRules.create(script.mode, config)
	return MatchState.new(config, script.map, player, enemy, script.seed_value, hooks)


## Commits the script's enemy plays for this round (cards come from the hand, or are pulled
## from the deck if the stacked draw has not reached them). Returns the engine results.
static func play_scripted_enemy(script: TutorialScript, st: MatchState) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var foe: RulesSide = st.sides[MatchState.ENEMY]
	for p: TutorialEnemyPlay in script.plays_for_round(st.round_number):
		var intent: Dictionary = RulesIntent.place_operator(p.zone)
		if p.card != null:
			var rc: RulesCard = _take_card(foe, p.card.id)
			if rc == null:
				push_warning("Tutorial: enemy has no %s for round %d" % [p.card.id, st.round_number])
				continue
			intent = RulesIntent.play_card(rc.uid, p.zone)
		var res: Dictionary = st.submit(MatchState.ENEMY, intent)
		if not res["ok"]:
			push_warning("Tutorial: scripted enemy play refused (round %d): %s" % [st.round_number, res.get("reason", "")])
		results.append(res)
	return results


static func _take_card(side: RulesSide, card_id: StringName) -> RulesCard:
	for rc: RulesCard in side.hand:
		if rc.card.id == card_id:
			return rc
	for i: int in side.deck.size():
		if side.deck[i].card.id == card_id:
			var rc: RulesCard = side.deck[i]
			side.deck.remove_at(i)
			side.hand.append(rc)
			return rc
	return null


func start_local_match(p_seed: int = seed_value) -> bool:
	if tutorial == null:
		return super(p_seed)
	var st: MatchState = build_state(tutorial)
	if st == null:
		push_warning("TutorialMatchController: tutorial data missing; showing the mock board")
		_screen.show_snapshot(MockMatchData.round_3_sample())
		return false
	state = st
	map = tutorial.map
	offer_mulligan = false
	enemy_ai = false
	enemy_ai_player = null
	_default_planner = false
	enemy_planner = func(s: MatchState) -> void: play_scripted_enemy(tutorial, s)
	_cursor = 0
	killfeed.clear()
	intent_log.clear()
	selection.clear()
	target_uid = -1
	_busy = false
	_match_started_ms = Time.get_ticks_msec()
	state.start_match()
	_begin_deploy()
	return true


func _submit(intent: Dictionary) -> Dictionary:
	var why: String = _gate(intent_gate, [intent])
	if why != "":
		return _refuse(why)
	return super(intent)


func press_ready() -> void:
	if state != null and not _busy and state.phase == MatchState.Phase.DEPLOY and not state.sides[PLAYER].ready:
		var why: String = _gate(ready_gate, [])
		if why != "":
			_refuse(why)
			return
	await super()


func undo() -> Dictionary:
	if state != null and not _busy:
		var why: String = _gate(undo_gate, [])
		if why != "":
			return _refuse(why)
	return super()


func _deploy_hint() -> void:
	if tutorial == null:
		super()


func _show_selection() -> void:
	super()
	selection_changed.emit()


func _gate(gate: Callable, args: Array) -> String:
	if not gate.is_valid():
		return ""
	return String(gate.callv(args))


func _refuse(why: String) -> Dictionary:
	if _screen != null:
		_screen.show_toast(why)
	refused.emit(why)
	return {"ok": false, "code": &"tutorial_locked", "reason": why, "data": {}}

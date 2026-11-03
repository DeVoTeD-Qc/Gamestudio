# match_hooks.gd
# Purpose: Extension points of the rules engine. MatchState calls these at fixed
#   moments of the round loop; the defaults implement the p04 baseline. Later tasks
#   subclass (or replace) it instead of editing MatchState:
#   - p05 streaks / killstreaks / abilities / respawn: on_briefing (cooldown ticks),
#     can_use_item / on_item_resolved, on_elimination, on_operator_down,
#     operator_can_deploy (respawn rules), apply_streak (trays, once-per-life).
#   - p06 modes: set `mode_rules` (ModeRules.create(mode, config)); the default
#     initiative_side / score_round / check_match_end / match_end_details delegate
#     to it, so a p05 subclass keeps mode rules as long as it doesn't override those.
#     Without mode_rules the match never ends (p04 sandbox, used by engine tests).
#   Hooks receive the MatchState as `state` (untyped to keep scripts acyclic).
#   p05 is implemented in the defaults below by delegating to StreakTracker and
#   LoadoutRules, so a p06 subclass keeps streaks / loadout rules automatically.
# Dependencies: ModeRules (optional), StreakTracker, LoadoutRules; MatchState passed in.
# Author: Mechanics Developer Agent
class_name MatchHooks
extends RefCounted

## Mode scoring / match end (p06). Null = no mode: no points, never ends.
var mode_rules: ModeRules = null


## Which side resolves first at Reveal. Default (core-rules §2.3): the side behind
## on the scoreboard; ties -> the player.
func initiative_side(state) -> int:
	if mode_rules != null:
		return mode_rules.initiative_side(state)
	var p: int = state.sides[0].score
	var e: int = state.sides[1].score
	return 1 if e < p else 0


## Briefing, after Supply and draws: cooldowns tick, per-round uses reset, Grit arms (p05).
func on_briefing(state, side: int) -> void:
	LoadoutRules.on_briefing(state, side)


## Can `side` use a loadout item this Deploy? Return "" if yes, else the reason.
## Supply is checked by MatchState. p05: cooldowns, uses per round/match, the Streak Tray.
func can_use_item(state, side: int, item: LoadoutItem) -> String:
	return LoadoutRules.can_use_item(state, side, item)


## Same check with a stable reason code, as MatchState.submit() / can_submit() use it:
## {} if the item may be used, else {code, reason, data} (codes: LoadoutRules.check_item).
## Goes through can_use_item(), so a subclass that overrides only that keeps working
## (its own refusals get code &"item_blocked").
func check_item(state, side: int, item: LoadoutItem) -> Dictionary:
	var why: String = can_use_item(state, side, item)
	if why == "":
		return {}
	var known: Dictionary = LoadoutRules.check_item(state, side, item)
	if String(known.get("reason", "")) == why:
		return known
	return {"code": &"item_blocked", "reason": why, "data": {}}


## A loadout item was accepted in Deploy (p05: start cooldown, count the use, take from tray).
func on_item_used(state, side: int, item: LoadoutItem) -> void:
	LoadoutRules.on_item_used(state, side, item)


## A queued loadout item was taken back with undo_last (p05: refund cooldown / uses / tray).
func on_item_undone(state, side: int, item: LoadoutItem) -> void:
	LoadoutRules.on_item_undone(state, side, item)


## A loadout item's ON_PLAY effects resolved at Reveal.
func on_item_resolved(_state, _side: int, _item: LoadoutItem) -> void:
	pass


## Called for every elimination (record = the UNIT_ELIMINATED event). p05: perk
## On Eliminate (Field Salvage).
func on_elimination(state, record: Dictionary) -> void:
	LoadoutRules.on_elimination(state, record)


func on_operator_down(_state, _side: int) -> void:
	pass


## May an off-board Operator be placed this Deploy? Round 1 always; afterwards this
## is the respawn rule (default: respawn every round, full Armor; Detonator: never).
func operator_can_deploy(state, _side: int) -> bool:
	return state.round_number == 1 or state.respawn_enabled


## Score & Streak step, streak part (core-rules §2.5, Rulings part 2 #12): kills and
## bonuses, then thresholds / Streak Tray, then the reset if the Operator went down (p05).
func apply_streak(state, side: int) -> void:
	StreakTracker.apply_streak(state, side)


## Mode scoring at the end of the round (p06: ModeRules). No mode: scores stay as set.
func score_round(state, control: Array) -> void:
	if mode_rules != null:
		mode_rules.score_round(state, control)


## Return &"player", &"enemy" or &"draw" to end the match, &"" to go on (p06: ModeRules).
func check_match_end(state) -> StringName:
	if mode_rules != null:
		return mode_rules.check_match_end(state)
	return &""


## Extra fields for the MATCH_ENDED event (winner, reason, final score...; see ModeRules).
func match_end_details(state) -> Dictionary:
	if mode_rules != null:
		return mode_rules.match_end_details(state)
	return {}

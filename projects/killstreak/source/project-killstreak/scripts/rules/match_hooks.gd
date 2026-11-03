# match_hooks.gd
# Purpose: Extension points of the rules engine. MatchState calls these at fixed
#   moments of the round loop; the defaults implement the p04 baseline. Later tasks
#   subclass (or replace) it instead of editing MatchState:
#   - p05 streaks / killstreaks / abilities / respawn: on_briefing (cooldown ticks),
#     can_use_item / on_item_resolved, on_elimination, on_operator_down,
#     operator_can_deploy (respawn rules), apply_streak (trays, once-per-life).
#   - p06 modes: score_round (Zone Control points / Firefight eliminations) and
#     check_match_end (targets, round cap, overtime, draw).
#   Hooks receive the MatchState as `state` (untyped to keep scripts acyclic).
# Dependencies: none at parse time (MatchState passed in).
# Author: Mechanics Developer Agent
class_name MatchHooks
extends RefCounted


## Which side resolves first at Reveal. Default (core-rules §2.3): the side behind
## on the scoreboard; ties -> the player.
func initiative_side(state) -> int:
	var p: int = state.sides[0].score
	var e: int = state.sides[1].score
	return 1 if e < p else 0


## Briefing, after Supply and draws (p05: Lethal/Tactical cooldowns tick here).
func on_briefing(_state, _side: int) -> void:
	pass


## Can `side` use a loadout item this Deploy? Return "" if yes, else the reason.
## Supply is checked by MatchState. p05 adds cooldowns, uses per round/match and the Streak Tray.
func can_use_item(_state, _side: int, _item: LoadoutItem) -> String:
	return ""


## A loadout item was accepted in Deploy (p05: start cooldown, take from tray).
func on_item_used(_state, _side: int, _item: LoadoutItem) -> void:
	pass


## A queued loadout item was taken back with undo_last (p05: refund cooldown / tray).
func on_item_undone(_state, _side: int, _item: LoadoutItem) -> void:
	pass


## A loadout item's ON_PLAY effects resolved at Reveal.
func on_item_resolved(_state, _side: int, _item: LoadoutItem) -> void:
	pass


## Called for every elimination (record = the UNIT_ELIMINATED event).
func on_elimination(_state, _record: Dictionary) -> void:
	pass


func on_operator_down(_state, _side: int) -> void:
	pass


## May an off-board Operator be placed this Deploy? Round 1 always; afterwards this
## is the respawn rule (default: respawn every round, full Armor; Detonator: never).
func operator_can_deploy(state, _side: int) -> bool:
	return state.round_number == 1 or state.respawn_enabled


## Score & Streak step, streak part (core-rules §2.5). Default: +1 per credited
## elimination this round not made by a killstreak, plus effect bonuses; then, if the
## Operator went down this round, reset to 0. p05 replaces this to fill Streak Trays.
func apply_streak(state, side: int) -> void:
	var s = state.sides[side]
	var gained: int = s.streak_bonus_this_round
	for rec: Dictionary in state.round_eliminations:
		if rec["by_side"] == state.side_name(side) and rec["credit"] and not rec["by_killstreak"]:
			gained += 1
	var before: int = s.streak
	s.streak += gained
	var reset: bool = s.operator_down_this_round
	if reset:
		s.streak = 0
	if gained != 0 or reset:
		state.emit_event(RulesEvent.STREAK_CHANGED, {
			"side": state.side_name(side), "streak": s.streak, "before": before,
			"gained": gained, "reset": reset,
		})


## Mode scoring at the end of the round (p06). Default: none (scores stay as set).
func score_round(_state, _control: Array) -> void:
	pass


## p06: return &"player", &"enemy" or &"draw" to end the match, &"" to go on.
func check_match_end(_state) -> StringName:
	return &""

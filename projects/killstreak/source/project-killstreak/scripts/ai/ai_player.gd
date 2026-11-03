# ai_player.gd
# Purpose: The enemy AI's driver (core-rules §7). Each Deploy it captures an AiView
#   (public information only), lets AiPlanner choose the whole round's plan, and
#   commits it to the match with MatchState.submit() BEFORE the player deploys, so
#   the player's red dots show exactly the AI's committed unit deployments (Ruling 13).
#   The planner never gets the MatchState; this class only passes intents through.
#   Round 1: takes its free mulligan first (plan_mulligan).
#   A plan that starts with a "Resolves immediately" draw (Ammo Resupply) submits the
#   draw, re-captures the view (the AI's own hand changed) and plans the rest.
#
#   Usage (match scene / p10 run flow / sims):
#     var ai := AiPlayer.for_squad(match_data.squad)
#     # each round, after begin_round() and before the player's Deploy:
#     ai.take_turn(match_state, MatchState.ENEMY)   # submits + READY
#
# Dependencies: AiView, AiPlanner, AiPersonality, SquadData (MatchState passed in).
# Author: Mechanics Developer Agent
class_name AiPlayer
extends RefCounted

## Re-plans allowed after immediate draws in one Deploy.
const MAX_REPLANS: int = 3

var personality: AiPersonality = null
var planner: AiPlanner = null
## Intents the last take_turn() committed (accepted by the engine), in order.
var last_intents: Array[Dictionary] = []
## Intents the engine refused in the last turn (should stay empty; tests check it).
var last_rejected: Array[Dictionary] = []
## Planner result of the last turn's final plan (scores, second_best).
var last_plan: Dictionary = {}
## Microseconds the last take_turn() took (capture + plan + submit).
var last_turn_usec: int = 0
## Every turn's duration in microseconds (profiling).
var turn_usecs: Array[int] = []


func _init(p_personality: AiPersonality = null) -> void:
	personality = p_personality if p_personality != null else AiPersonality.new()
	planner = AiPlanner.new(personality)


static func for_squad(squad: SquadData) -> AiPlayer:
	return AiPlayer.new(AiPersonality.from_squad(squad))


## Plays the AI's whole Deploy for this round and sets it READY. Returns the
## committed intents. Call it before the player's Deploy so red dots are complete.
func take_turn(state, side: int, set_ready: bool = true) -> Array[Dictionary]:
	var t0: int = Time.get_ticks_usec()
	last_intents.clear()
	last_rejected.clear()
	mulligan(state, side)
	for i: int in MAX_REPLANS + 1:
		var view: AiView = AiView.capture(state, side)
		last_plan = planner.plan(view)
		for intent: Dictionary in last_plan["intents"]:
			var r: Dictionary = state.submit(side, intent)
			if r["ok"]:
				last_intents.append(intent)
			else:
				var refused: Dictionary = intent.duplicate()
				refused["reason"] = r["reason"]
				last_rejected.append(refused)
		if not last_plan["replan"]:
			break
	if set_ready:
		state.set_ready(side)
	last_turn_usec = Time.get_ticks_usec() - t0
	turn_usecs.append(last_turn_usec)
	return last_intents


## Round 1 free mulligan, if any is left and nothing was played yet.
func mulligan(state, side: int) -> void:
	if int(state.sides[side].mulligans_left) <= 0 or not state.sides[side].plays.is_empty():
		return
	var view: AiView = AiView.capture(state, side)
	var back: Array[int] = planner.plan_mulligan(view)
	if not back.is_empty():
		state.mulligan(side, back)

# cz_ai_arena.gd
# Purpose: Plays whole CardZone matches between two CzAI brains on the real rules engine
#   (LoadoutRules.apply, so every action is checked and logged exactly as in a real match).
#   Used by tests/test_ai*.gd and the balance sweep tool (tests/tools/ai_sweep.gd).
#     CzAiArena.play(content, route, ai_p1, ai_p2, drops := {}) -> Dictionary
#       drops: optional {0: area, 1: area} forcing each seat's drop (the sweep's drop pairs);
#       otherwise each AI picks its own drop (S5: P2 first).
#   Result: {result, winner (-1 draw), cause, rounds, actions, turns, health: [p1, p2],
#     turn_ms: [ms per AI turn, both seats], max_turn_ms, decision_ms_max, illegal (count),
#     state (the final MatchState)}.
#   A turn's time is the sum of the AI's choose_action calls for that seat from its draw to its
#   end_turn (the Brace answers it gives on the other turn are timed as their own "turn").
# Dependencies: CzAI, LoadoutRules, MatchState, RulesData.
# Author: Mechanics Developer Agent
class_name CzAiArena
extends RefCounted

const MAX_ACTIONS: int = 4000


static func play(content: RulesData, route: int, ai_p1: CzAI, ai_p2: CzAI, drops: Dictionary = {}) -> Dictionary:
	var state: MatchState = MatchState.new_match(content, route)
	var ais: Array[CzAI] = [ai_p1, ai_p2]
	var out: Dictionary = {"illegal": 0, "turns": 0, "turn_ms": [], "max_turn_ms": 0.0, "decision_ms_max": 0.0,
			"actions": 0}
	var turn_ms: float = 0.0
	var turn_key: String = ""
	var n: int = 0
	while not state.is_over() and n < MAX_ACTIONS:
		n += 1
		var seat: int = state.deciding_seat()
		var key: String = "%d:%d:%d" % [state.round_number, state.active, 1 if state.pending_brace_seat() == seat and seat != state.active else 0]
		if key != turn_key:
			if turn_key != "":
				_close_turn(out, turn_ms)
			turn_key = key
			turn_ms = 0.0
		var action: Dictionary
		if state.phase == MatchState.PHASE_DROP and drops.has(seat):
			action = {"type": "drop", "seat": seat, "area": String(drops[seat])}
		else:
			action = ais[seat].choose_action(state, seat)
			var ms: float = float(ais[seat].last_stats.get("ms", 0.0))
			turn_ms += ms
			out["decision_ms_max"] = maxf(float(out["decision_ms_max"]), ms)
		var r: ActionResult = LoadoutRules.apply(state, action)
		if not r.ok:
			out["illegal"] = int(out["illegal"]) + 1
			push_warning("AI action rejected (%s): %s" % [r.error, action])
			# Never stall: end the turn (or brace with nothing) instead.
			var fallback: Dictionary = {"type": "end_turn", "seat": seat, "hold": []}
			if state.pending_brace_seat() == seat:
				fallback = {"type": "brace", "seat": seat, "cards": []}
			r = LoadoutRules.apply(state, fallback)
			if not r.ok:
				break
		out["actions"] = int(out["actions"]) + 1
	if turn_key != "":
		_close_turn(out, turn_ms)
	var end: Dictionary = state.match_end
	out["result"] = String(end.get("result", "unfinished"))
	out["winner"] = int(end.get("winner", -1))
	out["cause"] = String(end.get("cause", "unfinished"))
	out["rounds"] = state.round_number
	out["health"] = [state.health_of(MatchState.P1), state.health_of(MatchState.P2)]
	out["state"] = state
	return out


static func _close_turn(out: Dictionary, ms: float) -> void:
	out["turns"] = int(out["turns"]) + 1
	(out["turn_ms"] as Array).append(ms)
	out["max_turn_ms"] = maxf(float(out["max_turn_ms"]), ms)

# warden_ai.gd
# Purpose: Hard rival brain (spec §7 Warden): 2-ply minimax. For each of its moves it assumes the
#   opponent's best reply (in the belief world) and plays the move whose worst case is best.
#   The evaluation adds signature_safety_weight x RivalAI.signature_risk (its Signature captured
#   or open to capture). Alpha-beta: root moves are searched in greedy order (equal ones in
#   seeded random order) and a move's replies stop as soon as it can't beat the best so far. A node cap (placements simulated) bounds the
#   time on a full wall; at the cap the remaining (greedily worse) root moves are skipped.
#   Deterministic: no clocks, ties broken with the seeded RNG.
# Dependencies: RivalAI, WallRules.
# Author: Mechanics Developer Agent
class_name WardenAI
extends RivalAI

## Placements simulated per move at most (root moves + replies; half when a Triptych can score,
## since every score then checks it). Only the first two or three moves of a duel reach it.
## 250 keeps the slowest move under ~35 ms on the dev machine (target: 200 ms on a phone with
## 4x headroom). See documentation/design/balance/balance-log.md for timings.
var max_nodes: int = 250


func brain_name() -> StringName:
	return &"warden"


func _pick(world: WallState, me: int, moves: Array[Dictionary]) -> int:
	var opp: int = WallState.other(me)
	var after: Array[WallState] = []
	var greedy: Array[float] = []
	for m: Dictionary in moves:
		var w: WallState = after_move(world, me, m)
		last_nodes += 1
		after.append(w)
		greedy.append(evaluate(w, me) if w != null else -INF)
	# Greedy order; equal greedy values in a seeded random order (that is the tie-break, since
	# a later root move must be strictly better to replace the best).
	var tiebreak: Array[float] = []
	for i: int in moves.size():
		tiebreak.append(_rng.randf())
	var order: Array = range(moves.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return greedy[a] > greedy[b] or (greedy[a] == greedy[b] and tiebreak[a] < tiebreak[b]))
	var cap: int = max_nodes if world.triptychs.is_empty() else max_nodes / 2
	var best_val: float = -INF
	var best: int = -1
	for i: int in order:
		var w1: WallState = after[i]
		if w1 == null:
			continue
		if last_nodes >= cap and best >= 0:
			break
		var v: float
		if w1.is_game_over() or w1.to_move != opp:
			v = greedy[i]
		else:
			v = _worst_reply(w1, me, opp, best_val)
		if v > best_val + 0.0001:
			best_val = v
			best = i
	return best if best >= 0 else pick_one(best_indices(greedy))


## The opponent's best reply value (lowest evaluation for `me`). Stops early once it is at or
## below `alpha` (this move can't beat the best root move found so far).
func _worst_reply(w1: WallState, me: int, opp: int, alpha: float) -> float:
	var replies: Array[Dictionary] = WallRules.legal_moves(w1)
	if replies.is_empty():
		return evaluate(w1, me)
	_order_replies(w1, me, replies)
	var v: float = INF
	for r: Dictionary in replies:
		var w2: WallState = after_move(w1, opp, r)
		last_nodes += 1
		if w2 == null:
			continue
		v = minf(v, evaluate(w2, me))
		if v <= alpha + 0.0001:
			break
	return v


## Replies next to more of `me`'s face-up cards first (they are the likely captures), so the
## cut-off comes early. Stable for equal keys.
func _order_replies(w1: WallState, me: int, replies: Array[Dictionary]) -> void:
	var exposure: Dictionary = {}
	for slot: StringName in w1.empty_slots():
		var n: int = 0
		for s: StringName in w1.topology.neighbour_slots(slot):
			var pc: PlacedCard = w1.get_card(s)
			if pc != null and pc.controller == me and not pc.face_down:
				n += 2 if pc.signature else 1
		exposure[slot] = n
	var keyed: Array = []
	for i: int in replies.size():
		keyed.append([int(exposure[replies[i]["slot"]]), i, replies[i]])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	for i: int in keyed.size():
		replies[i] = keyed[i][2]

# rival_ai.gd
# Purpose: Base class of the Banner Wall AI rivals (spec §7, plan cc06). Node-free, seeded and
#   deterministic: the same seed and the same states give the same moves.
#     RivalAI.for_rival(rival_data, seed)   factory; picks the brain from rival_data.lookahead_plies
#       0 -> QuartermasterAI (random, best capture with best_capture_chance)
#       1 -> ArchivistAI     (greedy: best immediate result)
#       2 -> WardenAI        (2-ply minimax with alpha-beta, Signature safety, node cap)
#     choose_move(state, player) -> {card: CardData, slot: StringName, copy_from: StringName}
#       One entry of WallRules.legal_moves(state) (the same Dictionary), or {} when there is none.
#       Never changes `state`. Same shape as the duel controller's RivalBrain (cc08), which this extends.
#   Hidden information (RQ-19): the AI never reads the identity of a face-down card it doesn't
#   control, nor which of the opponent's cards are still in hand. It builds a belief world
#   (belief_world) from public information only: the opponent's lineup (public, spec §4.2), its
#   Signature, and the face-up cards. Each hidden face-down card gets a sampled Ambush card from
#   the opponent's unseen cards; the rest of the unseen cards become the opponent's hand.
# Dependencies: RivalBrain (scripts/duel/rival_brain.gd), WallState, WallRules, PlacedCard,
#   WallTopology, RivalData, CardData, DataEnums.
# Author: Mechanics Developer Agent
class_name RivalAI
extends "res://scripts/duel/rival_brain.gd"

## Added to the evaluation for a won (subtracted for a lost) finished duel.
const WIN_BONUS: float = 100.0

## The tuning this brain was built from (null for a bare RivalAI built in tests).
var rival: RivalData
## Chance (0-1) to take the best move instead of a random one (Quartermaster).
var best_capture_chance: float = 1.0
## Extra evaluation weight on keeping the AI's own Signature (Warden).
var signature_safety_weight: float = 0.0
## Search statistics of the last choose_move (for the sim tool and tests).
var last_nodes: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


## The brain for a rival's tuning. `seed_value` makes a duel replay exactly.
static func for_rival(rival_data: RivalData, seed_value: int = 0) -> RivalAI:
	var ai: RivalAI
	var plies: int = rival_data.lookahead_plies if rival_data != null else 1
	match plies:
		0:
			ai = QuartermasterAI.new(seed_value)
		1:
			ai = ArchivistAI.new(seed_value)
		_:
			ai = WardenAI.new(seed_value)
	ai.rival = rival_data
	if rival_data != null:
		ai.best_capture_chance = rival_data.best_capture_chance
		ai.signature_safety_weight = rival_data.signature_safety_weight
	return ai


## Short name for logs ("quartermaster", "archivist", "warden").
func brain_name() -> StringName:
	return &"rival"


## Picks a move for `player` (default: the player to move). Returns {} when it isn't `player`'s
## turn or there is no legal move.
func choose_move(state: WallState, player: int = -1) -> Dictionary:
	last_nodes = 0
	var me: int = state.to_move if player < 0 else player
	if state.is_game_over() or state.to_move != me:
		return {}
	var moves: Array[Dictionary] = WallRules.legal_moves(state)
	if moves.is_empty():
		return {}
	if moves.size() == 1:
		return moves[0]
	var world: WallState = belief_world(state, me, _rng)
	var idx: int = _pick(world, me, moves)
	return moves[clampi(idx, 0, moves.size() - 1)]


## Subclasses: index into `moves` (WallRules.legal_moves of the real state, identical to the
## belief world's own moves for `me`).
func _pick(_world: WallState, _me: int, _moves: Array[Dictionary]) -> int:
	return 0


# --- Hidden information ------------------------------------------------------------

## True for a wall card whose identity `viewer` may not see (RQ-19, PlacedCard.to_dict).
static func is_hidden_from(pc: PlacedCard, viewer: int) -> bool:
	return pc.face_down and pc.controller != viewer


## A copy of `state` that holds only what `viewer` may know. The opponent's hidden face-down
## cards are replaced by Ambush cards sampled (with `rng`) from the opponent's unseen cards, and
## the opponent's hand is the rest of those cards, in lineup order. With no hidden card and an
## unrestricted hand (fixtures) it is a plain copy.
static func belief_world(state: WallState, viewer: int, rng: RandomNumberGenerator) -> WallState:
	var w: WallState = state.copy()
	var opp: int = WallState.other(viewer)
	var hidden: Array[StringName] = []
	for slot: StringName in w.topology.slots:
		var pc: PlacedCard = w.get_card(slot)
		if pc != null and is_hidden_from(pc, viewer):
			hidden.append(slot)
	if w.hand_of(opp) == null:
		# Fixture with an unrestricted hand: no lineup to sample from; keep the board as dealt.
		return w
	# Unseen = the opponent's public lineup minus the cards of that lineup the viewer can see.
	# The lineup is public (spec §4.2); in the state it is the hand plus the lineup's wall cards.
	var unseen: Array[CardData] = public_lineup(state, opp)
	for slot: StringName in w.topology.slots:
		var pc: PlacedCard = w.get_card(slot)
		if pc != null and pc.lineup == opp and not is_hidden_from(pc, viewer):
			_remove_card(unseen, pc.card)
	var opp_hand: Array[CardData] = unseen.duplicate()
	for slot: StringName in hidden:
		var pc: PlacedCard = w.get_card(slot)
		var candidates: Array[CardData] = []
		for c: CardData in opp_hand:
			if c.card_trait() == DataEnums.CardTrait.AMBUSH:
				candidates.append(c)
		if candidates.is_empty():
			candidates = opp_hand.duplicate()
		if candidates.is_empty():
			continue  # Inconsistent fixture: leave the card as it is.
		var pick: CardData = candidates[rng.randi_range(0, candidates.size() - 1)]
		_remove_card(opp_hand, pick)
		pc.card = pick
		pc.active_trait = pick.card_trait()
		pc.signature = w.is_signature_card(opp, pick)
	w.hands[opp] = opp_hand
	return w


## The opponent's lineup as public information: its remaining hand plus its cards on the wall, in
## a fixed order (by card id) so hand order never leaks.
static func public_lineup(state: WallState, player: int) -> Array[CardData]:
	var out: Array[CardData] = []
	var hand: Variant = state.hand_of(player)
	if hand != null:
		for c: CardData in hand:
			out.append(c)
	for slot: StringName in state.topology.slots:
		var pc: PlacedCard = state.get_card(slot)
		if pc != null and pc.lineup == player:
			out.append(pc.card)
	out.sort_custom(func(a: CardData, b: CardData) -> bool: return String(a.id) < String(b.id))
	return out


static func _remove_card(list: Array[CardData], card: CardData) -> void:
	var i: int = list.find(card)
	if i < 0:
		for j: int in list.size():
			if list[j].id == card.id:
				i = j
				break
	if i >= 0:
		list.remove_at(i)


# --- Evaluation ----------------------------------------------------------------------

## The world after `me` plays `move` (springs that follow included). Null if it was rejected.
static func after_move(world: WallState, me: int, move: Dictionary) -> WallState:
	var w: WallState = world.copy()
	var r: PlacementResult = WallRules.place(w, me, move["card"], move["slot"], move["copy_from"])
	return w if r.ok else null


## Position value for `me`: score difference (true board of the belief world), a win bonus on a
## full wall, and the Signature-safety terms when signature_safety_weight > 0.
func evaluate(world: WallState, me: int) -> float:
	var opp: int = WallState.other(me)
	var v: float = float(WallRules.score(world, me) - WallRules.score(world, opp))
	if world.is_game_over():
		var res: Dictionary = WallRules.final_result(world)
		if res["winner"] == me:
			v += WIN_BONUS
		elif res["winner"] == opp:
			v -= WIN_BONUS
		return v
	if signature_safety_weight > 0.0:
		v -= signature_safety_weight * signature_risk(world, me)
	return v


## 0 when `me`'s Signature is safe or not placed; 1 when the opponent holds it; 0.5 when an
## opponent hand card could capture it from an empty neighbour slot (printed value plus the best
## bonus it could get, Veteran ties, Steady checked).
static func signature_risk(world: WallState, me: int) -> float:
	var opp: int = WallState.other(me)
	for slot: StringName in world.cells:
		var pc: PlacedCard = world.cells[slot]
		if pc.lineup != me or not pc.signature:
			continue
		if pc.controller != me:
			return 1.0
		if pc.face_down:
			return 0.0
		return 0.5 if is_threatened(world, slot, opp) else 0.0
	return 0.0


## Could `attacker` capture the face-up card in `slot` from one of its empty neighbours next turn?
static func is_threatened(world: WallState, slot: StringName, attacker: int) -> bool:
	var hand: Variant = world.hand_of(attacker)
	if hand == null:
		return false
	var target: PlacedCard = world.get_card(slot)
	var b: BalanceConfig = world.balance
	for n: Dictionary in world.topology.neighbours(slot):
		var from: StringName = n["slot"]
		if not world.is_empty(from):
			continue
		# n["dir"] is the attacker's direction seen from the target; the attacker faces the other way.
		var def_name: StringName = WallTopology.attack_value_name(n["dir"])
		var atk_name: StringName = WallTopology.defend_value_name(n["dir"])
		var dfn: int = target.value(def_name)
		for c: CardData in hand:
			var t: DataEnums.CardTrait = c.card_trait()
			if target.active_trait == DataEnums.CardTrait.STEADY and c.clearance < target.clearance():
				continue
			var atk: int = printed_value(c, atk_name)
			if t == DataEnums.CardTrait.AMBUSH:
				atk += b.ambush_spring_bonus  # A spring gets no Set Link (RQ-05).
			else:
				atk += b.set_link_bonus + (b.clutch_bonus if t == DataEnums.CardTrait.CLUTCH else 0)
			if atk > dfn or (atk == dfn and t == DataEnums.CardTrait.VETERAN):
				return true
	return false


static func printed_value(c: CardData, name: StringName) -> int:
	match name:
		WallTopology.TOP:
			return c.top
		WallTopology.BOTTOM:
			return c.bottom
	return c.side


## Indices of the best values (ties kept, in move order).
static func best_indices(values: Array[float]) -> Array[int]:
	var out: Array[int] = []
	var best: float = -INF
	for i: int in values.size():
		if values[i] > best + 0.0001:
			best = values[i]
			out = [i]
		elif absf(values[i] - best) <= 0.0001:
			out.append(i)
	return out


## One of `indices`, chosen with the seeded RNG.
func pick_one(indices: Array[int]) -> int:
	return indices[_rng.randi_range(0, indices.size() - 1)]


## Greedy (1-ply) values of every move in the belief world.
func greedy_values(world: WallState, me: int, moves: Array[Dictionary]) -> Array[float]:
	var out: Array[float] = []
	for m: Dictionary in moves:
		var w: WallState = after_move(world, me, m)
		last_nodes += 1
		out.append(evaluate(w, me) if w != null else -INF)
	return out

# wall_rules.gd
# Purpose: The Banner Wall rules engine (spec §4, §10; QA rules-test-cases RQ-01..RQ-20). Static,
#   node-free functions over a WallState:
#     check_place / place / preview   one placement (preview runs the same resolution on a copy)
#     legal_moves / cipher_picks      move generation for the AI and the UI
#     score / scores / is_behind      scoring (spec §4.5), also used by Clutch's behind-check
#     triptychs_scored / final_result end of game: Triptychs and the tie flag
#   Resolution order inside one placement (RQ-06): 1) Cipher copy, 2) bonuses (Set Link, Clutch)
#   read from the board before anything flips, 3) Reclaim, 4) value captures against
#   enemy-controlled face-up neighbours, 5) chain (if on), 6) the turn passes and the next
#   player's springs resolve (or every pending spring, in placement order, when the wall fills).
#   The engine emits nothing: callers replay PlacementResult.events onto EventBus.
# Dependencies: WallState, PlacedCard, PlacementResult, WallTopology, RulesOptions, BalanceConfig,
#   CardData, TriptychData, DataEnums.
# Author: Mechanics Developer Agent
class_name WallRules
extends RefCounted

# Rejection codes (QA "error_codes").
const ERR_GAME_OVER: StringName = &"GAME_OVER"
const ERR_NOT_YOUR_TURN: StringName = &"NOT_YOUR_TURN"
const ERR_INVALID_SLOT: StringName = &"INVALID_SLOT"
const ERR_SLOT_OCCUPIED: StringName = &"SLOT_OCCUPIED"
const ERR_NOT_IN_HAND: StringName = &"NOT_IN_HAND"
const ERR_NO_CARD: StringName = &"NO_CARD"
## A Cipher card with a neighbour must name the card it copies (RQ-03).
const ERR_CIPHER_PICK_REQUIRED: StringName = &"CIPHER_PICK_REQUIRED"
## The named Cipher pick isn't an occupied neighbour.
const ERR_INVALID_CIPHER_PICK: StringName = &"INVALID_CIPHER_PICK"


# --- Placement ------------------------------------------------------------------

## &"" when `player` may place `card` into `slot` (with Cipher pick `copy_from`), else an ERR_ code.
static func check_place(state: WallState, player: int, card: CardData, slot: StringName,
		copy_from: StringName = &"") -> StringName:
	if state.is_game_over():
		return ERR_GAME_OVER
	if player != state.to_move:
		return ERR_NOT_YOUR_TURN
	if not state.topology.is_slot(slot):
		return ERR_INVALID_SLOT
	if not state.is_empty(slot):
		return ERR_SLOT_OCCUPIED
	if card == null:
		return ERR_NO_CARD
	if _hand_index(state, player, card) < 0:
		return ERR_NOT_IN_HAND
	if card.card_trait() == DataEnums.CardTrait.CIPHER:
		var picks: Array[StringName] = cipher_picks(state, slot)
		if picks.is_empty():
			if copy_from != &"":
				return ERR_INVALID_CIPHER_PICK
		elif copy_from == &"":
			return ERR_CIPHER_PICK_REQUIRED
		elif not picks.has(copy_from):
			return ERR_INVALID_CIPHER_PICK
	return &""


## Places the card, resolves it, passes the turn and resolves the springs that follow.
## On rejection the state is untouched and result.ok is false.
## as_signature marks the card as a Signature when the state doesn't know the lineup (fixtures).
static func place(state: WallState, player: int, card: CardData, slot: StringName,
		copy_from: StringName = &"", as_signature: bool = false) -> PlacementResult:
	var err: StringName = check_place(state, player, card, slot, copy_from)
	if err != &"":
		return PlacementResult.rejected(err)
	var r: PlacementResult = _resolve_placement(state, player, card, slot, copy_from, as_signature)
	_pass_turn(state, r)
	_finish(state, r)
	return r


## What place() would do, without changing `state` (spec §11 capture preview). Runs the same
## resolution on a copy. Covers the placed card's own resolution and, if it fills the wall, its
## own immediate spring; never the opponent's pending springs (RQ-20).
static func preview(state: WallState, player: int, card: CardData, slot: StringName,
		copy_from: StringName = &"", as_signature: bool = false) -> PlacementResult:
	var err: StringName = check_place(state, player, card, slot, copy_from)
	if err != &"":
		var rej: PlacementResult = PlacementResult.rejected(err)
		rej.is_preview = true
		return rej
	var s: WallState = state.copy()
	var r: PlacementResult = _resolve_placement(s, player, card, slot, copy_from, as_signature)
	r.is_preview = true
	var placed: PlacedCard = s.get_card(slot)
	if s.is_full() and placed.spring_pending:
		_spring(s, slot, r)
	_finish(s, r)
	return r


## Every legal move for the player to move: [{card, slot, copy_from}]. Empty when the hand is
## unrestricted (fixtures) or the game is over.
static func legal_moves(state: WallState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hand: Variant = state.hand_of(state.to_move)
	if state.is_game_over() or hand == null:
		return out
	var seen: Dictionary = {}
	for card: CardData in hand:
		if seen.has(card):
			continue
		seen[card] = true
		for slot: StringName in state.empty_slots():
			if card.card_trait() == DataEnums.CardTrait.CIPHER:
				var picks: Array[StringName] = cipher_picks(state, slot)
				if picks.is_empty():
					out.append({"card": card, "slot": slot, "copy_from": &""})
				for p: StringName in picks:
					out.append({"card": card, "slot": slot, "copy_from": p})
			else:
				out.append({"card": card, "slot": slot, "copy_from": &""})
	return out


## Slots a Cipher placed in `slot` may copy from: every occupied neighbour, either side,
## face-down included (RQ-03).
static func cipher_picks(state: WallState, slot: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for n: StringName in state.topology.neighbour_slots(slot):
		if not state.is_empty(n):
			out.append(n)
	return out


## The trait a Cipher gets from copying the card in `from_slot` (spec §10, RQ-02).
static func copied_trait(state: WallState, from_slot: StringName) -> DataEnums.CardTrait:
	var target: PlacedCard = state.get_card(from_slot)
	if target == null:
		return DataEnums.CardTrait.NONE
	var t: DataEnums.CardTrait = target.printed_trait() if state.options.cipher_copies_printed_trait else target.active_trait
	return DataEnums.CardTrait.NONE if t == DataEnums.CardTrait.CIPHER else t


# --- Scoring --------------------------------------------------------------------

## Points for `player` (spec §4.5): 1 per controlled card, signature_value per controlled Signature,
## plus triptych_bonus per Triptych scored, plus balance.first_player_bonus ("Tempo", decided
## 2026-11-04) when `player` is the first player. full = the true board (face-down cards counted
## with their identity). full = false is the public score: face-down cards count 1, no Triptychs.
## The Tempo bonus is public and part of the real score, so it counts in both, from the first
## placement on: final_result, the score bar and Clutch's behind-check (is_behind) all include it.
static func score(state: WallState, player: int, full: bool = true) -> int:
	var total: int = state.balance.first_player_bonus if player == state.first_player else 0
	for slot: StringName in state.cells:
		var pc: PlacedCard = state.cells[slot]
		if pc.controller != player:
			continue
		if pc.signature and (full or not pc.face_down):
			total += state.balance.signature_value
		else:
			total += 1
	if full:
		total += state.balance.triptych_bonus * triptychs_scored(state, player).size()
	return total


## [P1, P2] scores.
static func scores(state: WallState) -> Array[int]:
	return [score(state, WallState.P1), score(state, WallState.P2)]


## Clutch's behind-check (spec §10, RQ-09): strictly lower score, before the placement. Includes
## the Tempo bonus (see score), so the second player is behind at 0-2.
static func is_behind(state: WallState, player: int) -> bool:
	var full: bool = state.options.clutch_uses_full_score
	return score(state, player, full) < score(state, WallState.other(player), full)


## Triptych ids `player` scores now (RQ-12): its three cards controlled by `player`, in three
## consecutive slots of one row, any order, from either lineup. Each at most once.
static func triptychs_scored(state: WallState, player: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for t: TriptychData in state.triptychs:
		var want: Array = t.cards.map(func(c: CardData) -> StringName: return c.id)
		want.sort()
		for run: Array in state.topology.runs_of_three:
			var have: Array = []
			for slot: StringName in run:
				var pc: PlacedCard = state.get_card(slot)
				if pc == null or pc.controller != player:
					break
				have.append(pc.card.id)
			if have.size() != 3:
				continue
			have.sort()
			if have == want:
				out.append(t.id)
				break
	return out


## End-of-game result: {score: [P1, P2], winner: P1 / P2 / NO_PLAYER (draw), tie: bool,
## triptychs: [[ids of P1], [ids of P2]]}. Scores include the Tempo bonus. Ties go to the first
## player unless tie_winner is DRAW (the shipped setting since 2026-11-04: winner NO_PLAYER).
static func final_result(state: WallState) -> Dictionary:
	var s: Array[int] = scores(state)
	var winner: int = WallState.NO_PLAYER
	var tie: bool = s[0] == s[1]
	if not tie:
		winner = WallState.P1 if s[0] > s[1] else WallState.P2
	elif state.balance.tie_winner == DataEnums.TieWinner.FIRST_PLAYER:
		winner = state.first_player
	return {
		"score": s, "winner": winner, "tie": tie,
		"triptychs": [triptychs_scored(state, WallState.P1), triptychs_scored(state, WallState.P2)],
	}


# --- Resolution (shared by place and preview) -------------------------------------

static func _resolve_placement(state: WallState, player: int, card: CardData, slot: StringName,
		copy_from: StringName, as_signature: bool) -> PlacementResult:
	var r: PlacementResult = PlacementResult.new()
	r.ok = true
	r.player = player
	r.card = card
	r.slot = slot
	# Bonus inputs are read before the card lands or anything flips (RQ-06 step 2).
	var behind: bool = is_behind(state, player)
	# Take the card from the hand.
	var idx: int = _hand_index(state, player, card)
	var hand: Variant = state.hand_of(player)
	if hand != null and idx >= 0:
		(hand as Array).remove_at(idx)
	var pc: PlacedCard = PlacedCard.create(card, player, player)
	pc.signature = as_signature or state.is_signature_card(player, card)
	pc.order = state.next_order
	state.next_order += 1
	r.signature = pc.signature
	# 1) Cipher copy.
	if pc.printed_trait() == DataEnums.CardTrait.CIPHER:
		pc.active_trait = copied_trait(state, copy_from) if copy_from != &"" else DataEnums.CardTrait.NONE
		r.copy_from = copy_from
	r.active_trait = pc.active_trait
	r.effective_values = pc.printed_values()
	r.events.append({"type": &"placed", "slot": slot, "player": player, "card_id": card.id,
			"face_down": pc.printed_trait() == DataEnums.CardTrait.AMBUSH, "signature": pc.signature})
	if r.copy_from != &"":
		r.events.append({"type": &"cipher_copied", "slot": slot, "player": player, "from": copy_from,
				"trait": r.trait_name()})
	# Ambush (printed or copied): captures nothing now, springs later (spec §4.4, §10).
	if pc.active_trait == DataEnums.CardTrait.AMBUSH:
		pc.face_down = pc.printed_trait() == DataEnums.CardTrait.AMBUSH
		pc.spring_pending = true
		r.face_down = pc.face_down
		state.cells[slot] = pc
		return r
	# 2) Bonuses, from the board before anything flips.
	r.set_link = _has_set_link(state, player, card, slot)
	r.clutch = pc.active_trait == DataEnums.CardTrait.CLUTCH and behind
	var bonus: int = (state.balance.set_link_bonus if r.set_link else 0) + (state.balance.clutch_bonus if r.clutch else 0)
	for k: StringName in r.effective_values.keys():
		r.effective_values[k] += bonus
	state.cells[slot] = pc
	# 3) Reclaim: own-lineup neighbours come back, whatever the values (beats Steady).
	if pc.active_trait == DataEnums.CardTrait.RECLAIM:
		for n: StringName in state.topology.neighbour_slots(slot):
			var other: PlacedCard = state.get_card(n)
			if other != null and other.lineup == player and other.controller != player:
				other.controller = player
				r.reclaimed.append(n)
				r.events.append({"type": &"reclaimed", "slot": n, "player": player, "card_id": other.card.id})
	# 4) Value captures, 5) chain.
	var newly: Array[StringName] = _attack(state, slot, r.effective_values, pc.active_trait,
			pc.clearance(), player, &"placement", r, r.captured)
	_chain(state, newly, r, r.captured)
	return r


## Turn passes; the next player's pending springs resolve (or all of them when the wall is full).
static func _pass_turn(state: WallState, r: PlacementResult) -> void:
	state.placements += 1
	var pending: Array[StringName] = []
	if state.is_full():
		pending = _pending_springs(state, WallState.NO_PLAYER)
	else:
		state.to_move = WallState.other(state.to_move)
		pending = _pending_springs(state, state.to_move)
	for s: StringName in pending:
		_spring(state, s, r)
	if not state.is_full():
		r.events.append({"type": &"turn_started", "slot": &"", "player": state.to_move})


static func _finish(state: WallState, r: PlacementResult) -> void:
	r.score_after = scores(state)
	r.game_over = state.is_full()
	if r.game_over:
		r.events.append({"type": &"game_over", "slot": &"", "player": final_result(state)["winner"]})


## Pending springs owned by `owner` (NO_PLAYER = everyone), in placement order.
static func _pending_springs(state: WallState, owner: int) -> Array[StringName]:
	var list: Array = []
	for slot: StringName in state.cells:
		var pc: PlacedCard = state.cells[slot]
		if pc.spring_pending and (owner == WallState.NO_PLAYER or _spring_owner(state, pc) == owner):
			list.append([pc.order, slot])
	list.sort()
	var out: Array[StringName] = []
	for e: Array in list:
		out.append(e[1])
	return out


static func _spring_owner(state: WallState, pc: PlacedCard) -> int:
	return pc.placed_by if state.options.cancel_spring_if_lost else pc.controller


## One Ambush spring: flips face-up and attacks with printed values + ambush_spring_bonus only
## (no Set Link, Clutch or Veteran; Steady still applies; chains only if chain_captures, RQ-05).
static func _spring(state: WallState, slot: StringName, r: PlacementResult) -> void:
	var pc: PlacedCard = state.get_card(slot)
	if pc == null or not pc.spring_pending:
		return
	pc.spring_pending = false
	if state.options.cancel_spring_if_lost and pc.controller != pc.placed_by:
		r.springs_cancelled.append(slot)
		r.events.append({"type": &"spring_cancelled", "slot": slot, "player": pc.placed_by, "card_id": pc.card.id})
		return
	pc.face_down = false
	r.events.append({"type": &"spring", "slot": slot, "player": pc.controller, "card_id": pc.card.id})
	var values: Dictionary = pc.printed_values()
	for k: StringName in values.keys():
		values[k] += state.balance.ambush_spring_bonus
	var captured: Array[StringName] = []
	var carded_before: int = r.carded.size()
	var newly: Array[StringName] = _attack(state, slot, values, pc.active_trait, pc.clearance(),
			pc.controller, &"spring", r, captured)
	_chain(state, newly, r, captured)
	r.springs.append({"slot": slot, "player": pc.controller, "card_id": pc.card.id,
			"captured": captured, "carded": r.carded.slice(carded_before)})


## `attacker_slot` attacks its enemy-controlled, face-up neighbours. Returns the new captures
## (also appended to `into`). Higher wins; ties only with Veteran; Steady blocks a lower Clearance.
static func _attack(state: WallState, attacker_slot: StringName, values: Dictionary,
		attacker_trait: DataEnums.CardTrait, attacker_clearance: int, attacker: int, via: StringName,
		r: PlacementResult, into: Array[StringName]) -> Array[StringName]:
	var newly: Array[StringName] = []
	for n: Dictionary in state.topology.neighbours(attacker_slot):
		var target_slot: StringName = n["slot"]
		var def: PlacedCard = state.get_card(target_slot)
		if def == null or def.face_down or def.controller == attacker:
			continue
		var dir: WallTopology.Dir = n["dir"]
		var atk: int = values[WallTopology.attack_value_name(dir)]
		var dfn: int = def.value(WallTopology.defend_value_name(dir))
		var wins: bool = atk > dfn or (atk == dfn and attacker_trait == DataEnums.CardTrait.VETERAN)
		if not wins:
			continue
		if def.active_trait == DataEnums.CardTrait.STEADY and attacker_clearance < def.clearance():
			if via == &"placement":
				r.steady_blocked.append(target_slot)
			r.events.append({"type": &"steady_blocked", "slot": target_slot, "player": attacker, "from": attacker_slot})
			continue
		def.controller = attacker
		newly.append(target_slot)
		into.append(target_slot)
		r.events.append({"type": &"captured", "slot": target_slot, "player": attacker, "from": attacker_slot,
				"via": via, "card_id": def.card.id})
		if def.signature and def.lineup != attacker:
			r.carded.append(target_slot)
			r.events.append({"type": &"carded", "slot": target_slot, "player": attacker, "card_id": def.card.id})
	return newly


## Chain captures (spec §9, RQ-13): breadth-first; each newly captured card attacks with printed
## values and its own trait. Off by default.
static func _chain(state: WallState, queue: Array[StringName], r: PlacementResult, into: Array[StringName]) -> void:
	if not state.balance.chain_captures:
		return
	var i: int = 0
	while i < queue.size():
		var s: StringName = queue[i]
		i += 1
		var pc: PlacedCard = state.get_card(s)
		queue.append_array(_attack(state, s, pc.printed_values(), pc.active_trait, pc.clearance(),
				pc.controller, &"chain", r, into))


## Set Link (spec §4.4, RQ-07, RQ-08): the placed card touches a card the placer controls now,
## face-up, of the same set.
static func _has_set_link(state: WallState, player: int, card: CardData, slot: StringName) -> bool:
	if card.card_set == null:
		return false
	if card.card_set.kind == DataEnums.SetKind.SHOWCASE and not state.options.showcase_set_link:
		return false
	for n: StringName in state.topology.neighbour_slots(slot):
		var pc: PlacedCard = state.get_card(n)
		if pc == null or pc.controller != player or pc.face_down or pc.card.card_set == null:
			continue
		if pc.card.card_set.id == card.card_set.id:
			return true
	return false


## Index of `card` in the player's hand; 0 when the hand is unrestricted; -1 when not held.
static func _hand_index(state: WallState, player: int, card: CardData) -> int:
	var hand: Variant = state.hand_of(player)
	if hand == null:
		return 0
	var idx: int = (hand as Array).find(card)
	if idx >= 0:
		return idx
	for i: int in (hand as Array).size():
		if (hand[i] as CardData).id == card.id:
			return i
	return -1

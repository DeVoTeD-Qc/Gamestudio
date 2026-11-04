# dossier_puzzle.gd
# Purpose: One Dossier attempt on the real rules (spec §5.2, plan cc12). Node-free, so the
#   solution tests and the Dossier screen share it:
#     start()/reset()   builds the start board with WallState.from_setup (Retry = reset())
#     check_place()     WallRules.check_place plus "reserved for the rival reply" slots
#     place()           the player's placement through WallRules.place, then the scripted rival
#                       reply for that step (also through WallRules.place), or the turn handed back
#     is_finished()     the player has made max_placements placements (or has no card left)
#     evaluate()        the goal check: {success, reason, score, ...}
#     hint_move()       the next step of the known solution while the player is still on it
#   Player = WallState.P1 (DataEnums.Side.PLAYER), rival = WallState.P2. The player is the first
#   player. A goal that says "win" means a strictly higher full score (a tie is not a clear).
#   Between two player placements with no scripted reply, the turn goes straight back to the
#   player (to_move = P1). No shipped Dossier has a pending player spring at that point; if one
#   ever does, it stays pending (warned) because WallRules has no public "pass" step.
# Dependencies: DossierData, DossierPlacement, WallState, WallRules, PlacementResult, DataEnums,
#   CardData, BalanceConfig (optional), TriptychData (none: Dossiers score no Triptychs).
# Author: Mechanics Developer Agent (cc12)
class_name DossierPuzzle
extends RefCounted

const P1: int = WallState.P1
const P2: int = WallState.P2

## Rejection code for a slot a scripted rival reply will use (shown as reserved on the wall).
const ERR_RESERVED: StringName = &"RESERVED_FOR_RIVAL"

var data: DossierData
var balance: BalanceConfig = null
var state: WallState = null
## Every PlacementResult of this attempt, player and rival, in order.
var results: Array[PlacementResult] = []
## Player placements made: [{card, slot, copy_from, copied_from_rival, copied_trait}].
var moves: Array[Dictionary] = []
## Rival replies made so far.
var replies_made: int = 0


func _init(p_data: DossierData, p_balance: BalanceConfig = null) -> void:
	data = p_data
	balance = p_balance
	reset()


## Retry: back to the start board, full hand, no replies made.
func reset() -> void:
	state = WallState.from_setup(build_setup(data), card_table(data), balance)
	results.clear()
	moves.clear()
	replies_made = 0


## The from_setup Dictionary for this Dossier (board, hands, first player = player).
static func build_setup(d: DossierData) -> Dictionary:
	var board: Array = []
	for p: DossierPlacement in d.board:
		var who: String = _player_key(p.side)
		board.append({"slot": p.slot, "card": p.card.id, "lineup": who, "controller": who,
				"face_down": p.face_down, "signature": p.is_signature})
	var hand: Array = d.player_hand.map(func(c: CardData) -> StringName: return c.id)
	var rival_hand: Array = d.rival_replies.map(func(p: DossierPlacement) -> StringName: return p.card.id)
	var setup: Dictionary = {"first_player": "P1", "to_move": "P1", "board": board,
			"hands": {"P1": hand, "P2": rival_hand}}
	if d.hand_signature != null:
		setup["lineups"] = {"P1": {"cards": hand, "signature": d.hand_signature.id}}
	return setup


## card id -> CardData for every card the Dossier uses.
static func card_table(d: DossierData) -> Dictionary:
	var out: Dictionary = {}
	for p: DossierPlacement in d.board + d.rival_replies + d.solution:
		if p != null and p.card != null:
			out[p.card.id] = p.card
	for c: CardData in d.player_hand:
		out[c.id] = c
	return out


static func _player_key(side: DataEnums.Side) -> String:
	return "P1" if side == DataEnums.Side.PLAYER else "P2"


# --- Play ------------------------------------------------------------------------------

## Slots held for rival replies still to come: {slot: DossierPlacement}.
func reserved_slots() -> Dictionary:
	var out: Dictionary = {}
	for i: int in range(replies_made, data.rival_replies.size()):
		var p: DossierPlacement = data.rival_replies[i]
		if state.is_empty(p.slot):
			out[p.slot] = p
	return out


func player_hand() -> Array[CardData]:
	var out: Array[CardData] = []
	out.assign(state.hand_of(P1))
	return out


func placements_made() -> int:
	return moves.size()


func placements_left() -> int:
	return maxi(data.max_placements - moves.size(), 0)


func is_finished() -> bool:
	return moves.size() >= data.max_placements or player_hand().is_empty() or state.is_game_over()


## &"" when the player may place `card` into `slot` now, else a WallRules.ERR_ code or ERR_RESERVED.
func check_place(card: CardData, slot: StringName, copy_from: StringName = &"") -> StringName:
	if is_finished():
		return WallRules.ERR_GAME_OVER
	if reserved_slots().has(slot):
		return ERR_RESERVED
	return WallRules.check_place(state, P1, card, slot, copy_from)


## Slots where `card` can go now (Cipher slots that still need a pick included).
func valid_slots(card: CardData) -> Array[StringName]:
	var out: Array[StringName] = []
	for s: StringName in state.empty_slots():
		var err: StringName = check_place(card, s)
		if err == &"" or err == WallRules.ERR_CIPHER_PICK_REQUIRED:
			out.append(s)
	return out


## Preview of the player's placement (WallRules.preview), or a rejected result.
func preview(card: CardData, slot: StringName, copy_from: StringName = &"") -> PlacementResult:
	var err: StringName = check_place(card, slot, copy_from)
	if err == ERR_RESERVED:
		var r: PlacementResult = PlacementResult.rejected(err)
		r.is_preview = true
		return r
	return WallRules.preview(state, P1, card, slot, copy_from)


## The player's placement. Returns {ok, error, player: PlacementResult, rival: PlacementResult or null}.
## Use place_player() + play_reply() to pace the reply in the UI.
func place(card: CardData, slot: StringName, copy_from: StringName = &"") -> Dictionary:
	var r: PlacementResult = place_player(card, slot, copy_from)
	if not r.ok:
		return {"ok": false, "error": r.error, "player": r, "rival": null}
	var reply: PlacementResult = play_reply() if has_pending_reply() else null
	if reply == null:
		hand_turn_back()
	return {"ok": true, "error": &"", "player": r, "rival": reply}


## Step 1 of place(): the player's card only (the turn passes to the rival in the engine).
func place_player(card: CardData, slot: StringName, copy_from: StringName = &"") -> PlacementResult:
	var err: StringName = check_place(card, slot, copy_from)
	if err != &"":
		return PlacementResult.rejected(err)
	var copied_from_rival: bool = copy_from != &"" and state.controller_of(copy_from) == P2
	var copied: DataEnums.CardTrait = WallRules.copied_trait(state, copy_from) if copy_from != &"" else DataEnums.CardTrait.NONE
	var r: PlacementResult = WallRules.place(state, P1, card, slot, copy_from)
	if not r.ok:
		return r
	results.append(r)
	moves.append({"card": card, "slot": slot, "copy_from": copy_from,
			"copied_from_rival": copied_from_rival, "copied_trait": copied})
	return r


## A scripted reply is due after the player's latest placement.
func has_pending_reply() -> bool:
	return replies_made < data.rival_replies.size() and replies_made < moves.size() \
			and state.to_move == P2 and not state.is_game_over()


## The next scripted rival reply, through WallRules.place. Null when none is due.
func play_reply() -> PlacementResult:
	if not has_pending_reply():
		return null
	var p: DossierPlacement = data.rival_replies[replies_made]
	replies_made += 1
	var r: PlacementResult = WallRules.place(state, P2, p.card, p.slot, p.copy_from, p.is_signature)
	if not r.ok:
		push_error("DossierPuzzle %s: rival reply %s -> %s rejected (%s)" % [data.id, p.card.id, p.slot, r.error])
		return r
	results.append(r)
	return r


## No reply this step: the player moves again.
func hand_turn_back() -> void:
	if state.is_game_over() or state.to_move == P1:
		return
	state.to_move = P1
	if is_finished():
		return  # the attempt is over: there is no next turn for a spring to start
	for slot: StringName in state.cells:
		var pc: PlacedCard = state.cells[slot]
		if pc.spring_pending and pc.placed_by == P1:
			push_warning("DossierPuzzle %s: spring at %s stays pending (no rival turn to pass)" % [data.id, slot])


## Plays a whole line of player placements ([{card, slot, copy_from}] or DossierPlacements),
## replies included. Stops at the first rejection. Returns the rejection code or &"".
func play_line(line: Array) -> StringName:
	for step: Variant in line:
		var card: CardData
		var slot: StringName
		var copy_from: StringName = &""
		if step is DossierPlacement:
			card = step.card
			slot = step.slot
			copy_from = step.copy_from
		else:
			card = step["card"]
			slot = step["slot"]
			copy_from = step.get("copy_from", &"")
		var out: Dictionary = place(card, slot, copy_from)
		if not out["ok"]:
			return out["error"]
	return &""


# --- Goal --------------------------------------------------------------------------------

## Captures made by the player this attempt (placements and springs).
func player_captures() -> int:
	var n: int = 0
	for r: PlacementResult in results:
		for e: Dictionary in r.events:
			if e["type"] == &"captured" and int(e["player"]) == P1:
				n += 1
	return n


## Most captures one player Ambush spring made this attempt.
func best_spring() -> int:
	var best: int = 0
	for r: PlacementResult in results:
		for s: Dictionary in r.springs:
			if int(s["player"]) == P1:
				best = maxi(best, (s["captured"] as Array).size())
	return best


## The player controls a rival Signature now.
func holds_rival_signature() -> bool:
	for slot: StringName in state.cells:
		var pc: PlacedCard = state.cells[slot]
		if pc.signature and pc.lineup == P2 and pc.controller == P1:
			return true
	return false


## A player Cipher copied a trait from a rival-controlled card.
func copied_rival_trait() -> bool:
	for m: Dictionary in moves:
		if m["copied_from_rival"] and m["copied_trait"] != DataEnums.CardTrait.NONE:
			return true
	return false


func scores() -> Array[int]:
	return WallRules.scores(state)


func is_winning() -> bool:
	var s: Array[int] = scores()
	return s[0] > s[1]


## The goal check. {success: bool, reason: String, score: [P1, P2], captures, spring}.
func evaluate() -> Dictionary:
	var s: Array[int] = scores()
	var win: bool = s[0] > s[1]
	var ok: bool = false
	var reason: String = ""
	match data.goal:
		DataEnums.DossierGoal.CAPTURE_N:
			var n: int = player_captures()
			ok = n >= data.goal_count
			reason = "Captured %d of %d." % [mini(n, 99), data.goal_count]
		DataEnums.DossierGoal.WIN_IN_PLACEMENTS:
			ok = win and moves.size() == data.max_placements
			reason = _score_line(s) if moves.size() == data.max_placements else "Used %d of %d placements." % [moves.size(), data.max_placements]
		DataEnums.DossierGoal.CAPTURE_N_WITH_SPRING:
			var b: int = best_spring()
			ok = b >= data.goal_count
			reason = "Best spring captured %d of %d." % [b, data.goal_count] if b > 0 or _sprang() else "No Ambush sprang."
		DataEnums.DossierGoal.CAPTURE_SIGNATURE_AND_WIN:
			var sig: bool = holds_rival_signature()
			ok = sig and win
			reason = "%s · %s" % ["Their Signature is yours" if sig else "Their Signature is still theirs", _score_line(s)]
		DataEnums.DossierGoal.WIN_BY_COPYING_TRAIT:
			var copied: bool = copied_rival_trait()
			ok = copied and win
			reason = "%s · %s" % ["Copied a rival trait" if copied else "No rival trait copied", _score_line(s)]
	return {"success": ok, "reason": reason, "score": s, "captures": player_captures(),
			"spring": best_spring(), "placements": moves.size()}


func _sprang() -> bool:
	for r: PlacementResult in results:
		for sp: Dictionary in r.springs:
			if int(sp["player"]) == P1:
				return true
	return false


static func _score_line(s: Array[int]) -> String:
	if s[0] > s[1]:
		return "You win %d–%d." % [s[0], s[1]]
	if s[0] == s[1]:
		return "Tied %d–%d: a tie is not a win." % [s[0], s[1]]
	return "You lose %d–%d." % [s[0], s[1]]


## Goal in words, shown on the briefing and during play.
static func goal_text(d: DossierData) -> String:
	match d.goal:
		DataEnums.DossierGoal.CAPTURE_N:
			return "Capture %d rival cards in %d placements." % [d.goal_count, d.max_placements]
		DataEnums.DossierGoal.WIN_IN_PLACEMENTS:
			return "Win using exactly %d placements." % d.max_placements
		DataEnums.DossierGoal.CAPTURE_N_WITH_SPRING:
			return "Capture %d with one Ambush spring." % d.goal_count
		DataEnums.DossierGoal.CAPTURE_SIGNATURE_AND_WIN:
			return "Capture the rival Signature and win."
		DataEnums.DossierGoal.WIN_BY_COPYING_TRAIT:
			return "Win by copying a rival card's trait."
	return ""


## Live progress toward the goal (one short line).
func progress_text() -> String:
	var s: Array[int] = scores()
	match data.goal:
		DataEnums.DossierGoal.CAPTURE_N:
			return "Captured %d/%d" % [player_captures(), data.goal_count]
		DataEnums.DossierGoal.CAPTURE_N_WITH_SPRING:
			return "Spring captures %d/%d" % [best_spring(), data.goal_count]
		DataEnums.DossierGoal.CAPTURE_SIGNATURE_AND_WIN:
			return "Signature %s · %d–%d" % ["taken" if holds_rival_signature() else "not taken", s[0], s[1]]
		DataEnums.DossierGoal.WIN_BY_COPYING_TRAIT:
			return "Trait %s · %d–%d" % ["copied" if copied_rival_trait() else "not copied", s[0], s[1]]
	return "Score %d–%d" % [s[0], s[1]]


# --- Hint ---------------------------------------------------------------------------------

## The next solution step while the player's placements so far match the known solution:
## {card, slot, copy_from, step}. {} when the player has left the solution line (Retry first).
func hint_move() -> Dictionary:
	var i: int = moves.size()
	if i >= data.solution.size():
		return {}
	for k: int in i:
		var sol: DossierPlacement = data.solution[k]
		if moves[k]["card"] != sol.card or moves[k]["slot"] != sol.slot or moves[k]["copy_from"] != sol.copy_from:
			return {}
	var p: DossierPlacement = data.solution[i]
	return {"card": p.card, "slot": p.slot, "copy_from": p.copy_from, "step": i}

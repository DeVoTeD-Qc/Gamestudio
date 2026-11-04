# placement_result.gd
# Purpose: Everything one placement did (or, for a preview, would do): the placed card's own
#   resolution (copied trait, bonuses, effective values, captures, reclaims, "Carded!"), then the
#   Ambush springs that followed when the turn passed, the score and an ordered event list the UI,
#   game feel and PlaytestLog can replay. WallRules.place() and WallRules.preview() both return it.
# Dependencies: CardData, DataEnums, WallState.
# Author: Mechanics Developer Agent
class_name PlacementResult
extends RefCounted

## false = rejected; `error` names why (WallRules.ERR_*) and the state is unchanged.
var ok: bool = false
var error: StringName = &""
## true for WallRules.preview() (the state was not changed).
var is_preview: bool = false

var player: int = WallState.NO_PLAYER
var card: CardData = null
var slot: StringName = &""
var signature: bool = false
## Cipher: the slot copied from (&"" when none).
var copy_from: StringName = &""
## The placed card's trait after a Cipher copy (printed trait otherwise).
var active_trait: DataEnums.CardTrait = DataEnums.CardTrait.NONE
var face_down: bool = false
var set_link: bool = false
var clutch: bool = false
## Values the placed card fought with this placement: {top, side, bottom}.
var effective_values: Dictionary = {}

## Slots captured by the placed card's comparisons (and the chain, when chain_captures is on).
var captured: Array[StringName] = []
## Own-lineup cards taken back by Reclaim (not captures, RQ-10).
var reclaimed: Array[StringName] = []
## Slots where Steady stopped a capture the values would have made (for the preview UI).
var steady_blocked: Array[StringName] = []
## Enemy Signatures taken during this step, by the placement or by the springs after it (RQ-11).
var carded: Array[StringName] = []
## Springs resolved after the placement, in order: [{slot, player, card_id, captured, carded}].
## A preview lists only the placed card's own spring when it fills the wall (RQ-20).
var springs: Array[Dictionary] = []
## Springs cancelled because the placer lost the card first (RQ-04): [slot].
var springs_cancelled: Array[StringName] = []

## [P1 score, P2 score] after the step.
var score_after: Array[int] = [0, 0]
var game_over: bool = false
## Ordered events: {type, slot, player, ...}. Types: placed, cipher_copied, reclaimed, captured
## (via placement / chain / spring), steady_blocked, carded, spring, spring_cancelled, turn_started, game_over.
var events: Array[Dictionary] = []


static func rejected(code: StringName) -> PlacementResult:
	var r: PlacementResult = PlacementResult.new()
	r.ok = false
	r.error = code
	return r


func trait_name() -> StringName:
	return StringName(DataEnums.key_of(DataEnums.CardTrait, active_trait).to_lower())


## Every slot that changes controller this step (placement, chain and springs), in order.
func all_flipped() -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Dictionary in events:
		if e["type"] == &"captured" or e["type"] == &"reclaimed":
			out.append(e["slot"])
	return out


## The placed card's own resolution. preview() and place() agree on this exactly (BW-100).
func placement_part() -> Dictionary:
	var cap: Array = captured.duplicate()
	cap.sort()
	var rec: Array = reclaimed.duplicate()
	rec.sort()
	return {
		"captured": cap, "reclaimed": rec, "set_link": set_link, "clutch": clutch,
		"effective_values": effective_values.duplicate(), "active_trait": trait_name(),
		"face_down": face_down,
	}


func to_dict() -> Dictionary:
	var d: Dictionary = placement_part()
	d.merge({
		"ok": ok, "error": error, "preview": is_preview, "player": player,
		"card": card.id if card != null else &"", "slot": slot, "signature": signature,
		"copy_from": copy_from, "steady_blocked": steady_blocked.duplicate(),
		"carded": carded.duplicate(), "springs": springs.duplicate(true),
		"springs_cancelled": springs_cancelled.duplicate(), "score_after": score_after.duplicate(),
		"game_over": game_over,
	})
	return d

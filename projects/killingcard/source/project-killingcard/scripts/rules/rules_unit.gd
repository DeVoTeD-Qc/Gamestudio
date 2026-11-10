# rules_unit.gd
# Purpose: Runtime state of one unit on the board (a unit card, a summoned token
#   such as the Sentry, or a side's Operator). Holds printed stats, current Armor
#   (damage persists across rounds) and timed modifiers. Derived values that depend
#   on the board (range bonus, auras, passives) are computed by MatchState.
#   Holds no references to zones or sides (indices only), so there are no cycles.
# Dependencies: DataEnums, CardData, EffectData.
# Author: Mechanics Developer Agent
class_name RulesUnit
extends RefCounted

## Never expires (duration_rounds 0 = permanent).
const PERMANENT: int = -1

var uid: int = 0
## 0 = player, 1 = enemy (MatchState.PLAYER / ENEMY).
var side: int = 0
## Source card (null for the Operator).
var card: CardData = null
var is_operator: bool = false
## Card id, or the Primary's id for the Operator (for logs / killfeed).
var source_id: StringName = &""
var weapon_class: DataEnums.WeaponClass = DataEnums.WeaponClass.NONE

var base_firepower: int = 0
## Printed max Armor (plus permanent MODIFY_ARMOR changes).
var base_max_armor: int = 1
## kc-wip-impl (E6): the Operator's kit max Armor; base_max_armor goes back to it when it goes down
## (a permanent +Armor such as the Flag Bearer's does not survive a respawn).
var kit_max_armor: int = 1
## Current Armor. Damage persists across rounds.
var armor: int = 1

# Printed keywords (card or Primary + attachments).
var first_shot: bool = false
var pick: bool = false
var flank: bool = false
var cover: int = 0
var suppress: bool = false
## kc-wip-impl: Suppress N (the Operator: the largest of its parts).
var suppress_amount: int = 2
## kc-wip-impl: Agile (a free order to an adjacent column, once per round) and Beam (its shot hits
## every unit in front of it in its column, friends included).
var agile: bool = false
var beam: bool = false
## kc-fight-impl: damage beyond what the target needs carries to the next enemy behind it.
var pierce: bool = false
var patch: int = 0
var holder: bool = false
var arrives_front: bool = false
var counts_for_control: bool = true
## kc-syn: the synergy this copy carries (empty on the Operator and tokens). kc-no-training: one trait at most.
var neighbor_keyword: StringName = &""
var synergy_trait: StringName = &""
## kc-art-traits: the copy's chosen trait as it came from its RulesCard (kept so the card that goes
## back to the discard pile keeps it; synergy_trait is the resolved value).
var chosen_trait: StringName = SynergyRules.TRAIT_DEFAULT
var grants_elimination_credit: bool = true

## Effects carried by this unit (card effects; Primary + attachment effects for the Operator).
var effects: Array[EffectData] = []

## Zone index (0..2), -1 = off the board.
var zone: int = -1
## Timed modifiers: {kind: EffectKind, amount: int, until_round: int (PERMANENT = never)}.
var mods: Array[Dictionary] = []
## Armor kept when lethal damage would eliminate it (0 = none). Consumed on use (Grit hook).
var survive_lethal: int = 0
## Who dealt the lethal damage: {side, uid, source_id, source_kind}. Empty while alive.
var lethal_source: Dictionary = {}
## Set while the firefight runs: this unit already fired in this firefight.
var fired: bool = false


func is_alive() -> bool:
	return armor > 0


func is_on_board() -> bool:
	return zone >= 0


## Sum of active modifiers of `kind` in round `round_number`.
func mod_total(kind: int, round_number: int) -> int:
	var total: int = 0
	for m: Dictionary in mods:
		if m["kind"] == kind and _active(m, round_number):
			total += int(m["amount"])
	return total


func has_mod(kind: int, round_number: int) -> bool:
	for m: Dictionary in mods:
		if m["kind"] == kind and _active(m, round_number):
			return true
	return false


func add_mod(kind: int, amount: int, until_round: int) -> void:
	mods.append({"kind": kind, "amount": amount, "until_round": until_round})


## Max Armor including timed MODIFY_ARMOR modifiers.
func max_armor(round_number: int) -> int:
	return maxi(1, base_max_armor + mod_total(DataEnums.EffectKind.MODIFY_ARMOR, round_number))


## Drops modifiers that ended with `round_number`; clamps Armor to the new max.
func expire_mods(round_number: int) -> void:
	var kept: Array[Dictionary] = []
	for m: Dictionary in mods:
		if m["until_round"] == PERMANENT or int(m["until_round"]) > round_number:
			kept.append(m)
	mods = kept
	armor = mini(armor, max_armor(round_number + 1))


func damage_taken(round_number: int) -> int:
	return max_armor(round_number) - armor


func _active(m: Dictionary, round_number: int) -> bool:
	return m["until_round"] == PERMANENT or round_number <= int(m["until_round"])

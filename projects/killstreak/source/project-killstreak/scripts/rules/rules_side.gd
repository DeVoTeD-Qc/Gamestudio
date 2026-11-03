# rules_side.gd
# Purpose: Runtime state of one side in a match: deck / hand / discard, Supply,
#   the zone lines (front = index 0 = point man), Equipment in play, the Operator,
#   this round's face-down plays, score, eliminations and streak.
#   Pure data; MatchState applies the rules.
# Dependencies: RulesCard, RulesUnit, SideSetup.
# Author: Mechanics Developer Agent
class_name RulesSide
extends RefCounted

var index: int = 0
var setup: SideSetup = null

var deck: Array[RulesCard] = []    ## deck[0] is the top card.
var hand: Array[RulesCard] = []
var discard: Array[RulesCard] = []

var supply: int = 0
## lines[zone] = Array of RulesUnit, front (point man) first.
var lines: Array = [[], [], []]
## equipment[zone] = Array of {card: RulesCard, round: int} in placement order.
var equipment: Array = [[], [], []]

var operator_unit: RulesUnit = null
## True while the Operator is off the board and may be placed this Deploy.
var operator_can_deploy: bool = false
var rotations_used: int = 0

## This round's plays in play order: {order, kind, card, item, zone, target_uid, dest_zone}.
var plays: Array[Dictionary] = []
var ready: bool = false
var mulligans_left: int = 0
## Arrival buffs (Callout): {zone, effect, source_id, round}; first unit card to arrive takes it.
var arrival_buffs: Array[Dictionary] = []
## Zones whose enemy red dots this side sees in detail: {round: [zone, ...]}.
var intel_reveals: Dictionary = {}
## Side-wide flags set by effects: kind -> until_round (HIDE_FROM_INTEL, REVEAL_DEPLOYMENTS ...).
var flags: Dictionary = {}

## Mode score (Zone Control points or Firefight eliminations); set by the mode rules (p06).
var score: int = 0
## Total credited eliminations this match (Operator downs included).
var eliminations: int = 0
var streak: int = 0
## Streak gained this round from effects (Wren, Comms Relay); counted in the Score step.
var streak_bonus_this_round: int = 0
var operator_down_this_round: bool = false


func line(zone: int) -> Array:
	return lines[zone]


func units_on_board() -> Array[RulesUnit]:
	var out: Array[RulesUnit] = []
	for z: int in 3:
		for u: RulesUnit in lines[z]:
			out.append(u)
	return out


func find_unit(uid: int) -> RulesUnit:
	for z: int in 3:
		for u: RulesUnit in lines[z]:
			if u.uid == uid:
				return u
	return null


func find_in_hand(card_uid: int) -> RulesCard:
	for c: RulesCard in hand:
		if c.uid == card_uid:
			return c
	return null


func has_flag(kind: int, round_number: int) -> bool:
	return flags.has(kind) and (int(flags[kind]) == RulesUnit.PERMANENT or round_number <= int(flags[kind]))

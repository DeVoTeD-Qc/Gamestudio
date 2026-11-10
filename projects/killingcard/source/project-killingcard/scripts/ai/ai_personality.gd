# ai_personality.gd
# Purpose: How one enemy squad thinks (core-rules §7): the four scoring weights
#   (damage dealt, damage taken, zone-control swing, deny the player's streak), the
#   chance of playing the second-best plan, and the personality's positional habits.
#   - RUSHER: prefers zones whose range tag is in `preferred_ranges` (CLOSE), likes
#     pushing units into zones the enemy holds, sends its Operator to the fight.
#   - ANCHOR: "contests Mid" = the centre zone (index 1), whatever its range tag. SquadData
#     has no preferred_zones field (content-log gap 2), so this is mapped here in code:
#     ANCHOR always adds the centre zone to its preferred zones, values control of it
#     more, keeps its Operator there and prefers sturdy units / Holders there.
#   - SNIPER_NEST (post-prototype squad): uses preferred_ranges (LONG) like the Rusher,
#     without the push bonus.
#   Pure data (RefCounted); never sees the match. Built once per match from SquadData.
# Dependencies: DataEnums, SquadData.
# Author: Mechanics Developer Agent
class_name AiPersonality
extends RefCounted

## Index of the centre zone (Left 0, Mid 1, Right 2).
const CENTRE_ZONE: int = 1

var kind: DataEnums.Personality = DataEnums.Personality.RUSHER
var weight_damage_dealt: float = 1.0
var weight_damage_taken: float = 1.0
var weight_zone_control: float = 2.0
var weight_deny_streak: float = 3.0
var second_best_chance: float = 0.1
var preferred_ranges: Array[int] = []

## Bonus per unit deployed into a preferred zone.
var preferred_zone_bonus: float = 0.6
## Bonus per unit deployed into a zone where the enemy already has units (pushing).
var push_bonus: float = 0.0
## Multiplier on zone control of the preferred zones (Anchor holds its ground).
var preferred_control_mult: float = 1.0
## Bonus when the Operator ends its Deploy in a preferred zone.
var operator_home_bonus: float = 0.4
## Extra bonus per Armor point of units deployed into a preferred zone (Anchor).
var sturdy_bonus: float = 0.0
## Value of keeping a card in hand (opportunity cost of playing it), per card.
var card_keep_cost: float = 0.35
## Value of keeping an earned killstreak in the tray at the start of a match; it falls
## to 0 by the round cap (an unused killstreak is worth nothing once the match ends).
var killstreak_keep_cost: float = 0.8


## Personality for a squad. `zone_ranges` = the map's range tag per zone.
static func from_squad(squad: SquadData) -> AiPersonality:
	var p: AiPersonality = for_kind(squad.personality)
	p.weight_damage_dealt = squad.weight_damage_dealt
	p.weight_damage_taken = squad.weight_damage_taken
	p.weight_zone_control = squad.weight_zone_control
	p.weight_deny_streak = squad.weight_deny_streak
	p.second_best_chance = squad.second_best_chance
	p.preferred_ranges.clear()
	for r: int in squad.preferred_ranges:
		p.preferred_ranges.append(r)
	return p


## Defaults for a personality (SquadData defaults for the weights).
static func for_kind(p_kind: int) -> AiPersonality:
	var p: AiPersonality = AiPersonality.new()
	p.kind = p_kind as DataEnums.Personality
	match p_kind:
		DataEnums.Personality.RUSHER:
			p.preferred_ranges = [DataEnums.RangeTag.CLOSE]
			p.preferred_zone_bonus = 1.2
			p.push_bonus = 0.6
			p.operator_home_bonus = 0.3
			p.card_keep_cost = 0.25
		DataEnums.Personality.ANCHOR:
			p.preferred_zone_bonus = 1.0
			p.preferred_control_mult = 1.8
			p.operator_home_bonus = 1.5
			p.sturdy_bonus = 0.1
			p.card_keep_cost = 0.4
		DataEnums.Personality.SNIPER_NEST:
			p.preferred_ranges = [DataEnums.RangeTag.LONG]
			p.operator_home_bonus = 0.6
	return p


## kc-duel-impl (duel-mode.md §4.1): the Duel AI tiers (the duel_sim proxies, now real):
## recruit = the casual personality (2nd-best `second_best` of the time; synergy-blind, set by
## AiPlayer.for_duel_tier); regular = the competent planner, 2nd-best `second_best`, synergy-blind;
## veteran = the competent planner, always its best plan. No positional habits (no squad).
## Recruit's -1 Armor is the side's SideSetup.armor_bonus (DuelConfig.recruit_armor_bonus).
static func for_duel_tier(tier: StringName, second_best: float = -1.0) -> AiPersonality:
	var p: AiPersonality = AiPersonality.new()
	p.preferred_ranges.clear()
	p.preferred_zone_bonus = 0.0
	p.operator_home_bonus = 0.0
	p.second_best_chance = 0.0
	p.weight_damage_dealt = 2.0
	p.weight_damage_taken = 0.5
	p.push_bonus = 0.6
	match tier:
		&"recruit":
			p.weight_damage_dealt = 1.5
			p.weight_damage_taken = 0.8
			p.push_bonus = 0.3
			p.second_best_chance = 0.6
			p.card_keep_cost = 0.6
			p.killstreak_keep_cost = 1.2
			p.weight_deny_streak = 1.0
		&"regular":
			p.second_best_chance = 0.6
	if second_best >= 0.0:
		p.second_best_chance = second_best
	return p


## kc-duel-impl: the Duel tiers whose planner reads trait sets (only the Veteran).
static func duel_tier_synergy_aware(tier: StringName) -> bool:
	return tier not in [&"recruit", &"regular"]


## Zone indices this personality prefers on a map with these range tags.
func preferred_zones(zone_ranges: Array) -> Array[int]:
	var out: Array[int] = []
	for z: int in zone_ranges.size():
		if int(zone_ranges[z]) in preferred_ranges:
			out.append(z)
	if kind == DataEnums.Personality.ANCHOR and CENTRE_ZONE not in out:
		out.append(CENTRE_ZONE)
	return out


func label() -> String:
	return DataEnums.key_of(DataEnums.Personality, kind)

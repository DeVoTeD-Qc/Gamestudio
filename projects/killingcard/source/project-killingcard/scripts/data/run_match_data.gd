# run_match_data.gd
# Purpose: One match slot in a run (embedded in RunConfig.matches, in play order):
#   which squad, mode and map, and Bracket 2 stat scaling.
# Dependencies: DataEnums, SquadData, MapData, CardData, DataValidator.
# Author: Mechanics Developer Agent
class_name RunMatchData
extends Resource

## Bracket number shown on the run map (1, 2 ...). The Rival match uses the last bracket.
@export_range(1, 5) var bracket: int = 1
## The Rival / final match.
@export var is_rival: bool = false
@export var squad: SquadData = null
@export var mode: DataEnums.GameMode = DataEnums.GameMode.ZONE_CONTROL
@export var map: MapData = null
## Added to every enemy unit's Firepower / Armor in this match (Bracket 2 scaling). kc-onboard §4.4
## (head N4): -1 Armor makes a "green squad" (match 1), shown as such on the run map.
@export_range(0, 5) var enemy_firepower_bonus: int = 0
@export_range(-1, 5) var enemy_armor_bonus: int = 0
## kc-onboard §4.4: an authored deck for this slot instead of the squad's own (8-20 cards, shipped 10; empty =
## the squad's deck). The squad keeps its name, AI, loadout and art identity.
@export var enemy_deck: Array[CardData] = []
## kc-onboard §4.1: the crew tag shown on the run map ("Standard Issue crew", "Honors crew" ...).
@export var crew_label: String = ""

@export_group("Boss (kc-v2-impl, run-v2.md §4)")
## Boss id (&"meridian" / &"prime" / &"choir"; &"" = not a boss slot) and its one rule.
@export var boss_id: StringName = &""
## BossRules id: &"reinforcements" / &"dug_in" / &"horde".
@export var boss_rule: StringName = &""
@export var boss_rule_name: String = ""
## "{from}" is replaced by the round the rule starts (RunConfig.meridian_supply_from / choir_from_round;
## BossRules.format_text), so the printed number always matches the rule.
@export_multiline var boss_rule_text: String = ""
## One line of advice for the boss plate's inspect view ("{from}" as above).
@export_multiline var boss_tip: String = ""
## The card the rule uses: Dug In's Field (Mortar Pit), Horde's token (Shambler).
@export var boss_card: CardData = null
## Profile unlock of this boss (RunProfile.BOSS_UNLOCKS keys; &"" = from the start).
@export var unlock: StringName = &""


## kc-onboard §4.1 UI hook: a "green squad" (the enemy plays at reduced Armor).
func is_green_squad() -> bool:
	return enemy_armor_bonus < 0


## The deck the squad plays in this slot (enemy_deck when set, else the squad's deck).
func deck_for_squad() -> Array[CardData]:
	if not enemy_deck.is_empty():
		return enemy_deck
	var out: Array[CardData] = []
	if squad != null:
		out.assign(squad.deck)
	return out


func validate(v: DataValidator, prefix: String) -> void:
	v.check_range(prefix + ".bracket", bracket, 1, 5)
	v.check_ref(prefix + ".squad", squad, SquadData, true)
	v.check_enum(prefix + ".mode", mode, DataEnums.GameMode)
	v.check_ref(prefix + ".map", map, MapData, true)
	v.check_range(prefix + ".enemy_firepower_bonus", enemy_firepower_bonus, 0, 5)
	v.check_range(prefix + ".enemy_armor_bonus", enemy_armor_bonus, -1, 5)
	if not enemy_deck.is_empty() and v.check_ref_array(prefix + ".enemy_deck", enemy_deck, CardData, SquadData.MIN_DECK, SquadData.MAX_DECK):
		for i: int in enemy_deck.size():
			if enemy_deck[i] != null and enemy_deck[i].is_token():
				v.invalid("%s.enemy_deck[%d]" % [prefix, i], "'%s' is a token and can't be in a deck" % enemy_deck[i].id)
	if boss_rule != &"" and boss_rule not in [&"reinforcements", &"dug_in", &"horde"]:
		v.invalid(prefix + ".boss_rule", "unknown boss rule '%s'" % boss_rule)
	if boss_rule in [&"dug_in", &"horde"] and boss_card == null:
		v.missing(prefix + ".boss_card", "%s needs its card (Mortar Pit / Shambler)" % boss_rule)
	if mode == DataEnums.GameMode.DETONATOR:
		v.warn(prefix + ".mode", "Detonator is a stretch goal; the prototype rules engine may not support it")

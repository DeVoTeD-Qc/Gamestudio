# run_modifiers.gd
# Purpose: The five opt-in run modifiers of run-v2.md §5 (picked on the Loadout screen, any combination).
#   Each has a Threat number (the run's total is printed on the map and After-Action) and an unlock
#   (RunProfile). They unlock cosmetics, never power.
#     hardcore   3  Start with 2 tickets; you can never have more than 2.
#     austerity  1  Supply Drops: take 1 card instead of 2.
#     veterans   1  F4 and the elites get +1 Armor.
#     fog        1  No red dots for either side.
#     hot_ground 0  Every fight has one more Terrain (max 2); the boss gets 1.
#   Where each is applied: hardcore RunProgress.max_tickets(); austerity RunProgress._queue_offers;
#   veterans / hot_ground RunMap.generate; fog RunProgress.configure_match (MatchState.fog_of_war).
# Dependencies: none.
# Author: Mechanics Developer Agent (kc-v2-impl)
class_name RunModifiers
extends RefCounted

const HARDCORE: StringName = &"hardcore"
const AUSTERITY: StringName = &"austerity"
const VETERANS: StringName = &"veterans"
const FOG: StringName = &"fog"
const HOT_GROUND: StringName = &"hot_ground"
const ALL: Array[StringName] = [HARDCORE, AUSTERITY, VETERANS, FOG, HOT_GROUND]

## id -> {name, threat, text, unlock (RunProfile unlock id), unlock_text}.
const TABLE: Dictionary = {
	HARDCORE: {"name": "Hardcore", "threat": 3, "text": "Start with 2 tickets; you can never have more than 2.",
			"unlock": &"first_win", "unlock_text": "Win a run"},
	AUSTERITY: {"name": "Austerity", "threat": 1, "text": "Supply Drops: take 1 card instead of 2.",
			"unlock": &"two_operator_wins", "unlock_text": "Win a run with 2 different Operators"},
	VETERANS: {"name": "Veteran Crews", "threat": 1, "text": "F4 and the elites get +1 Armor.",
			"unlock": &"all_bosses_beaten", "unlock_text": "Beat all three bosses"},
	FOG: {"name": "Fog of War", "threat": 1, "text": "No red dots for either side.",
			"unlock": &"hardcore_win", "unlock_text": "Win a run with Hardcore"},
	HOT_GROUND: {"name": "Hot Ground", "threat": 0, "text": "Every fight has one more Terrain (max 2); the boss gets 1.",
			"unlock": &"all_terrains_seen", "unlock_text": "Play on all 10 Terrains"},
}


static func threat_of(ids: Array) -> int:
	var t: int = 0
	for id: Variant in ids:
		t += int(TABLE.get(StringName(id), {}).get("threat", 0))
	return t


static func name_of(id: StringName) -> String:
	return String(TABLE.get(id, {}).get("name", ""))

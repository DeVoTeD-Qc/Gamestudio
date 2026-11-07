# mock_match_data.gd
# Purpose: Placeholder match snapshot for the board/HUD layout (p08) until the rules
#   engine (p04) produces real state. It is the core-rules.md section 6 walkthrough:
#   Zone Control on Port Vasel, Round 3 Deploy, score 1-1, Supply 4, streak 1.
#   The Dictionary shape below is the view contract the match scenes read; p04/p09
#   can map MatchState into it (or replace it) without touching the scenes' layout.
# Dependencies: none (no CardDB; plain Dictionaries only).
# Author: UI/UX Agent
extends RefCounted

## Unit entry: {name, cls, fp, armor, armor_max, operator?: bool}
## Lane entry: {id, label, name, range, control (&"player"|&"enemy"|&"contested"|&"empty"),
##              incoming (red dots), friendly: Array[unit], enemy: Array[unit]}
static func round_3_sample() -> Dictionary:
	return {
		"mode": "ZONE CONTROL",
		"goal": "FIRST TO 6",
		"round": 3,
		"round_cap": 8,
		"phase": "DEPLOY",
		"score_player": 1,
		"score_enemy": 1,
		"enemy_name": "SANDVIPER_07",
		"supply": 4,
		"supply_max": 4,
		"deck_count": 14, "discard_count": 5, "enemy_hand": 5,
		"lanes": [
			{
				"id": &"left", "label": "A", "name": "CONTAINER STACKS",
				"control": &"player", "incoming": 1,
				"friendly": [_unit("Point Man", "SMG", 2, 3, 3)],
				"enemy": [], "fp_player": 2, "fp_enemy": 0,
				"fields": {"player": [{"card_uid": 901, "card_id": &"listening_post", "name": "Listening Post",
						"text": "", "hidden": false, "overrun_risk": false}], "enemy": []},
			},
			{
				"id": &"mid", "label": "B", "name": "CRANE YARD",
				"control": &"contested", "incoming": 0,
				"friendly": [_operator()],
				"enemy": [_unit("Marksman", "SNIPER", 2, 2, 2)], "fp_player": 3, "fp_enemy": 2,
			},
			{
				"id": &"right", "label": "C", "name": "LOADING OFFICES",
				"control": &"enemy", "incoming": 1,
				"friendly": [],
				"enemy": [_unit("Rifleman", "AR", 2, 2, 2), _unit("Gunner", "LMG", 2, 6, 6)], "fp_player": 0, "fp_enemy": 4,
			},
		],
		"operator": {
			"name": "KESTREL AR-7", "cls": "AR", "fp": 3, "armor": 5, "armor_max": 7, "zone": "MID",
		},
		"streak": 1,
		"streak_max": 5,
		"perks": [],
		"perk_slots": 3,
		"killstreaks": [
			{"id": &"recon_drone", "name": "RECON", "threshold": 2, "earned": false},
			{"id": &"mortar_barrage", "name": "MORTAR", "threshold": 3, "earned": false},
			{"id": &"attack_helo", "name": "HELO", "threshold": 5, "earned": false},
		],
		"hand": [
			{"name": "Marksman", "id": &"marksman", "type": "Sniper", "cost": 3, "fp": 2, "armor": 2, "text": "Pick",
					"keywords": [{"id": &"pick"}]},
			{"name": "Combat Medic", "id": &"combat_medic", "type": "AR", "cost": 2, "fp": 1, "armor": 3, "text": "Patch 2",
					"keywords": [{"id": &"patch", "value": 2}]},
			{"name": "Callout", "id": &"callout", "type": "Tactic", "cost": 0, "text": "Reveal red dots in a zone"},
			{"name": "Breacher", "id": &"breacher", "type": "Shotgun", "cost": 3, "fp": 3, "armor": 4, "text": "First Shot",
					"keywords": [{"id": &"first_shot"}]},
			{"name": "Hold the Line", "id": &"hold_the_line", "type": "Tactic", "cost": 2, "text": "Your units here: Cover 1"},
		],
		"killfeed": [
			{"text": "POINT MAN  >  SV RIFLEMAN", "side": &"player"},
			{"text": "SV BREACHER  >  RIFLEMAN", "side": &"enemy"},
		],
	}


static func _unit(unit_name: String, cls: String, fp: int, armor: int, armor_max: int) -> Dictionary:
	return {"name": unit_name, "cls": cls, "fp": fp, "armor": armor, "armor_max": armor_max,
			"banner": unit_name.to_lower().replace(" ", "_")}


static func _operator() -> Dictionary:
	return {"name": "Kestrel AR-7", "cls": "OPERATOR", "fp": 3, "armor": 5, "armor_max": 7, "operator": true,
			"banner": "kestrel_ar7", "camo": "base"}

# card_samples.gd
# Purpose: Placeholder card dictionaries (core-rules.md §3 and §5) for CardView previews and the
#   art-kit tests, until the p02 card Resources land. Not gameplay data: CardDB owns that.
# Author: Technical Artist Agent (p13)
extends RefCounted

const CARDS: Array[Dictionary] = [
	{"name": "Rifleman", "type": "unit", "weapon_class": "ar", "cost": 1, "firepower": 2, "armor": 2},
	{"name": "Point Man", "type": "unit", "weapon_class": "smg", "cost": 2, "firepower": 2, "armor": 3, "keywords": ["first_shot"]},
	{"name": "Combat Medic", "type": "unit", "weapon_class": "ar", "cost": 2, "firepower": 1, "armor": 3, "keywords": [{"id": "patch", "value": 2}]},
	{"name": "Recon Specialist", "type": "unit", "weapon_class": "ar", "cost": 2, "firepower": 1, "armor": 2, "keywords": ["on_deploy"], "text": "Next round, enemy red dots in this zone are revealed."},
	{"name": "Breacher", "type": "unit", "weapon_class": "shotgun", "cost": 3, "firepower": 3, "armor": 4, "keywords": ["first_shot"]},
	{"name": "Marksman", "type": "unit", "weapon_class": "sniper", "cost": 3, "firepower": 2, "armor": 2, "keywords": ["pick"]},
	{"name": "Flanker", "type": "unit", "weapon_class": "smg", "cost": 3, "firepower": 2, "armor": 3, "keywords": ["flank"]},
	{"name": "Shieldman", "type": "unit", "weapon_class": "", "cost": 3, "firepower": 1, "armor": 5, "keywords": [{"id": "cover", "value": 1}], "text": "Always arrives at the front of the line."},
	{"name": "Gunner", "type": "unit", "weapon_class": "lmg", "cost": 4, "firepower": 2, "armor": 6, "keywords": ["suppress"]},
	{"name": "Demolitions Expert", "type": "unit", "weapon_class": "lmg", "cost": 4, "firepower": 2, "armor": 4, "keywords": ["on_down"], "text": "3 damage to the enemy point man here."},
	{"name": "Sgt. Okafor \"Anvil\"", "type": "unit", "weapon_class": "ar", "cost": 5, "firepower": 3, "armor": 6, "elite": true, "keywords": ["holder"], "text": "Your other units here get +1 FP."},
	{"name": "Lt. Halek \"Wren\"", "type": "unit", "weapon_class": "sniper", "cost": 5, "firepower": 4, "armor": 3, "elite": true, "keywords": ["pick"], "text": "Her eliminations give +1 extra streak."},
	{"name": "Callout", "type": "tactic", "cost": 0, "text": "Resolves immediately: reveal red dots in a zone; your next unit there gets +1 FP this round."},
	{"name": "Ammo Resupply", "type": "tactic", "cost": 1, "text": "Resolves immediately: draw 2."},
	{"name": "Flank Route", "type": "tactic", "cost": 1, "text": "Move a friendly unit to an adjacent zone; it gains First Shot this round."},
	{"name": "Suppressing Fire", "type": "tactic", "cost": 2, "text": "Enemy units in a zone get −1 FP this round."},
	{"name": "Hold the Line", "type": "tactic", "cost": 2, "text": "Your units in a zone gain Cover 1 this round."},
	{"name": "Breach and Clear", "type": "tactic", "cost": 3, "text": "2 damage to each enemy unit in a zone (3 if Close)."},
	{"name": "Tripwire Charge", "type": "equipment", "cost": 2, "text": "Hidden in a zone: the next enemy unit to arrive there takes 3 damage."},
	{"name": "Comms Relay", "type": "equipment", "cost": 2, "text": "While you control this zone: streak +1 at end of round."},
	{"name": "Recon Drone", "type": "killstreak", "threshold": 2, "art_icon": "ks_recon_drone", "text": "This round and next: enemy deployments are shown face-up during Deploy, and enemy units lose Cover."},
	{"name": "Mortar Barrage", "type": "killstreak", "threshold": 3, "art_icon": "ks_mortar", "text": "2 damage to each enemy unit in one zone."},
	{"name": "Sentry Turret", "type": "killstreak", "threshold": 4, "art_icon": "ks_sentry", "text": "Place a Sentry (FP 2 / Armor 4, Cover 1) in a zone. It doesn't count for control."},
	{"name": "Attack Helo", "type": "killstreak", "threshold": 5, "art_icon": "ks_attack_helo", "text": "At the start of the next 2 firefights, deal 2 damage to the enemy point man in every zone."},
	{"name": "Gunship", "type": "killstreak", "threshold": 7, "art_icon": "ks_gunship", "text": "3 damage to every enemy unit in all zones."},
	{"name": "Kestrel AR-7", "type": "operator", "weapon_class": "ar", "firepower": 3, "armor": 7, "text": "Operator. Respawns at your next Deploy."},
	{"name": "Wasp-9", "type": "operator", "weapon_class": "smg", "firepower": 2, "armor": 6, "keywords": ["first_shot"], "text": "May Rotate twice per round."},
	{"name": "Longreach .338", "type": "operator", "weapon_class": "sniper", "firepower": 3, "armor": 5, "keywords": ["pick"]},
	# Stress case: three keywords on one card.
	{"name": "Test Dummy", "type": "unit", "weapon_class": "lmg", "cost": 6, "firepower": 10, "armor": 12, "keywords": [{"id": "cover", "value": 2}, "suppress", "holder"], "text": "Stress test: three keywords and two-digit stats."},
]

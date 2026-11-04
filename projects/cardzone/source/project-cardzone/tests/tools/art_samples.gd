# art_samples.gd
# Purpose: Sample card and area dictionaries for the cz16 art kit (tests, contact sheet). Card data
#   proper arrives with cz05 (CardData / CardDB) and cz06 (content); until then this fixture mirrors the
#   loadout-loop spec v0.2 section 11 card list and the section 3 map, in the field names CzCard and
#   CzAreaTile read (see scripts/art/README.md). It is a fixture, not game data.
# Author: Technical Artist Agent (cz16)
extends RefCounted

const CARDS: Array[Dictionary] = [
	{"id": "CZ-001", "name": "P-9 Sidearm", "type": "weapon", "rarity": "starter", "dmg": 1, "rng": 0,
		"effect": "Shoot. DMG 1 · RNG 0"},
	{"id": "CZ-002", "name": "Scavenge", "type": "item", "rarity": "starter", "search": 1, "effect": "Search 1"},
	{"id": "CZ-003", "name": "Dash", "type": "item", "rarity": "starter", "move": 1, "effect": "Move 1"},
	{"id": "CZ-004", "name": "Duck", "type": "item", "rarity": "starter", "brace": 1, "search": 1, "effect": "Search 1"},
	{"id": "CZ-005", "name": "Hit", "type": "hit"},
	{"id": "CZ-006", "name": "Bounty", "type": "bounty"},
	{"id": "CZ-010", "name": "Scrap SMG", "type": "weapon", "rarity": "C", "cost": 3, "dmg": 2, "rng": 0,
		"effect": "Shoot. DMG 2 · RNG 0", "area": "docks"},
	{"id": "CZ-011", "name": "Trail Boots", "type": "item", "rarity": "C", "cost": 2, "move": 2, "effect": "Move 2", "area": "docks"},
	{"id": "CZ-012", "name": "Bandage", "type": "item", "rarity": "C", "cost": 2, "heal": 1, "move": 1, "spent": true,
		"effect": "Heal 1. Move 1. Spent.", "area": "farmstead"},
	{"id": "CZ-013", "name": "Smoke Grenade", "short_name": "Smoke", "type": "item", "rarity": "C", "cost": 2, "brace": 2,
		"move": 2, "effect": "Move 2. If you use its Brace, it is Spent.", "area": "farmstead"},
	{"id": "CZ-014", "name": "Pump Shotgun", "type": "weapon", "rarity": "U", "cost": 4, "dmg": 3, "rng": 0,
		"effect": "Shoot. DMG 3 · RNG 0", "area": "quarry"},
	{"id": "CZ-015", "name": "Frag Grenade", "short_name": "Frag", "type": "item", "rarity": "U", "cost": 3, "spent": true,
		"blast_dmg": 2, "blast_rng": 1, "effect": "Spent. Choose one area within Range 1: resolve a 2-damage shot against each player there (including you). Ignores Cover. Brace and Down apply.",
		"area": "quarry"},
	{"id": "CZ-016", "name": "Hunting Rifle", "short_name": "Hunt Rifle", "type": "weapon", "rarity": "U", "cost": 4,
		"dmg": 2, "rng": 1, "effect": "Shoot. DMG 2 · RNG 1", "area": "radio_hill"},
	{"id": "CZ-017", "name": "Long Scope", "type": "attachment", "rarity": "U", "cost": 3, "attach": {"rng": 1},
		"effect": "Attach: +1 RNG (max RNG 2)", "area": "radio_hill"},
	{"id": "CZ-018", "name": "Medkit", "type": "item", "rarity": "U", "cost": 4, "heal": 2, "effect": "Heal 2", "area": "motel"},
	{"id": "CZ-019", "name": "Plate Vest", "type": "item", "rarity": "U", "cost": 4, "brace": 2, "move": 1, "effect": "Move 1",
		"area": "motel"},
	{"id": "CZ-020", "name": "Crowbar", "type": "item", "rarity": "C", "cost": 2, "search": 2, "effect": "Search 2", "area": "rail_yard"},
	{"id": "CZ-021", "name": "Backpack", "type": "item", "rarity": "U", "cost": 3, "search": 1, "pull": 1,
		"effect": "Search 1. Pull 1.", "area": "rail_yard"},
	{"id": "CZ-022", "name": "Red-dot Sight", "short_name": "Red-dot", "type": "attachment", "rarity": "C", "cost": 2,
		"attach": {"dmg": 1}, "effect": "Attach: +1 DMG", "area": "rail_yard"},
	{"id": "CZ-023", "name": "Assault Rifle", "type": "weapon", "rarity": "R", "cost": 6, "dmg": 3, "rng": 1,
		"effect": "Shoot. DMG 3 · RNG 1", "area": "old_town"},
	{"id": "CZ-024", "name": "Marksman Rifle", "short_name": "Marksman", "type": "weapon", "rarity": "R", "cost": 6,
		"dmg": 2, "rng": 2, "ignores_cover": true, "effect": "Shoot. DMG 2 · RNG 2. Ignores Cover.", "area": "old_town"},
	{"id": "CZ-025", "name": "Extended Mag", "short_name": "Ext. Mag", "type": "attachment", "rarity": "R", "cost": 5,
		"attach": {"extra_shot": true}, "effect": "Attach: this weapon may fire one extra time each turn", "area": "old_town"},
	{"id": "CZ-026", "name": "Suppressor", "type": "attachment", "rarity": "R", "cost": 5, "attach": {"no_brace": true},
		"effect": "Attach: targets can't Brace with cards against this weapon (Down still applies)", "area": "old_town"},
	{"id": "CZ-027", "name": "Recon Drone", "type": "item", "rarity": "R", "cost": 5, "search": 2, "pull": 1,
		"effect": "Search 2. Pull 1.", "area": "old_town"},
	{"id": "CZ-030", "name": "Twin-Drum LMG", "short_name": "Twin LMG", "type": "weapon", "rarity": "E", "cost": 3, "drop": true,
		"dmg": 2, "rng": 1, "fires_twice": true, "effect": "Shoot. DMG 2 · RNG 1. Fires twice each turn.", "area": "quarry"},
	{"id": "CZ-031", "name": "Heavy Plate", "type": "item", "rarity": "E", "cost": 3, "drop": true, "brace": 3, "heal": 1,
		"move": 1, "effect": "Heal 1. Move 1.", "area": "motel"},
	{"id": "CZ-032", "name": "Longshot .50", "type": "weapon", "rarity": "L", "cost": 3, "drop": true, "dmg": 4, "rng": 2,
		"ignores_cover": true, "effect": "Shoot. DMG 4 · RNG 2. Ignores Cover.", "area": "old_town"},
	{"id": "CZ-033", "name": "Phantom Suit", "type": "item", "rarity": "L", "cost": 3, "drop": true, "brace": 4, "move": 2,
		"search": 1, "effect": "Move 2. Search 1.", "area": "motel"},
]

const AREAS: Array[Dictionary] = [
	{"id": "docks", "name": "Docks", "cover": 0, "piles": [{"rarity": "C"}, {"rarity": "C"}]},
	{"id": "farmstead", "name": "Farmstead", "cover": 1, "piles": [{"rarity": "C"}, {"rarity": "C"}]},
	{"id": "quarry", "name": "Quarry", "cover": 1, "piles": [{"rarity": "U"}, {"rarity": "U"}]},
	{"id": "radio_hill", "name": "Radio Hill", "cover": 0, "piles": [{"rarity": "U"}, {"rarity": "U"}]},
	{"id": "motel", "name": "Motel", "cover": 1, "piles": [{"rarity": "U"}, {"rarity": "U"}]},
	{"id": "rail_yard", "name": "Rail Yard", "cover": 0, "piles": [{"rarity": "C"}, {"rarity": "U"}, {"rarity": "C"}]},
	{"id": "old_town", "name": "Old Town", "cover": 1, "core": true,
		"piles": [{"rarity": "R"}, {"rarity": "R"}, {"rarity": "R"}, {"rarity": "R"}, {"rarity": "R"}]},
]


static func card(id: String) -> Dictionary:
	for c: Dictionary in CARDS:
		if c["id"] == id:
			return c
	return {}


static func area(id: String) -> Dictionary:
	for a: Dictionary in AREAS:
		if a["id"] == id:
			return a
	return {}

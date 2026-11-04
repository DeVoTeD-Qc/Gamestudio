# mock_match_data.gd
# Purpose: Mock match state for the cz10 layout (no rules engine yet). Card, area and Zone data
#   copy spec v0.2 §3, §8 and §11 (loadout-loop-spec.md); cz05 / cz06 replace this table with
#   CardDB, and cz07's per-seat view() replaces the states. Only what the viewing seat may see is
#   in a state: the rival's held cards and loadout order are NOT here (§16 private loadouts;
#   prototype-scope.md §4 held_cards_public = false), only their counts.
# State shape (MatchScreen.show_state):
#   {round, zone_index (revealed Zone card, 1-14), route (&"A"|&"B"|&"C"), hand_size,
#    areas: {area_id: {gas: bool, piles: [{card, count}], drop: card_id or &""}},
#    you:   {name, area, health, max_health, bounty, down, hand: [card_id], line: [{card, attached: [card_id]}],
#            held: [card_id], next: [card_id] (top of the loadout down to the last card of the next hand,
#            Hits included), loadout_rest: int (cards below the next hand)},
#    rival: {name, kind, area, health, max_health, bounty, down, loadout_count, held_count, last_line: [card_id]}}
# Dependencies: none.
# Author: UI/UX Agent (cz10)
extends RefCounted

const HIT: StringName = &"cz_005"
const BOUNTY: StringName = &"cz_006"

## Card table (spec §11). rarity S = Starter. short = name that fits a compact card.
const CARDS: Dictionary = {
	&"cz_001": {"name": "P-9 Sidearm", "short": "P-9", "type": &"weapon", "rarity": &"S", "cost": -1, "brace": 0, "dmg": 1, "rng": 0, "text": "Shoot. DMG 1 · RNG 0."},
	&"cz_002": {"name": "Scavenge", "short": "Scavenge", "type": &"item", "rarity": &"S", "cost": -1, "brace": 0, "search": 1, "text": "Search 1."},
	&"cz_003": {"name": "Dash", "short": "Dash", "type": &"item", "rarity": &"S", "cost": -1, "brace": 0, "move": 1, "text": "Move 1."},
	&"cz_004": {"name": "Duck", "short": "Duck", "type": &"item", "rarity": &"S", "cost": -1, "brace": 1, "search": 1, "text": "Search 1. Brace 1: hold it to defend with it."},
	&"cz_005": {"name": "Hit", "short": "Hit", "type": &"hit", "rarity": &"S", "cost": -1, "brace": 0, "text": "Free draw (never takes a hand slot). Adrenaline: play for Move 1 or Search 1. While a Hit is in your next draw you are Down (+1 Brace against every shot). Remove with Patch up or Heal."},
	&"cz_006": {"name": "Bounty", "short": "Bounty", "type": &"bounty", "rarity": &"S", "cost": -1, "brace": 0, "text": "Round start: goes to the player with strictly the most health (tie: set aside). Land a Hit on the holder: heal 1. Final circle: the holder takes 1 extra Hit."},
	&"cz_010": {"name": "Scrap SMG", "short": "Scrap SMG", "type": &"weapon", "rarity": &"C", "cost": 3, "brace": 0, "dmg": 2, "rng": 0, "text": "Shoot. DMG 2 · RNG 0."},
	&"cz_011": {"name": "Trail Boots", "short": "Boots", "type": &"item", "rarity": &"C", "cost": 2, "brace": 0, "move": 2, "text": "Move 2."},
	&"cz_012": {"name": "Bandage", "short": "Bandage", "type": &"item", "rarity": &"C", "cost": 2, "brace": 0, "heal": 1, "move": 1, "text": "Heal 1. Move 1. Spent."},
	&"cz_013": {"name": "Smoke Grenade", "short": "Smoke", "type": &"item", "rarity": &"C", "cost": 2, "brace": 2, "move": 2, "text": "Move 2. If you use its Brace, it is Spent."},
	&"cz_014": {"name": "Pump Shotgun", "short": "Shotgun", "type": &"weapon", "rarity": &"U", "cost": 4, "brace": 0, "dmg": 3, "rng": 0, "text": "Shoot. DMG 3 · RNG 0."},
	&"cz_015": {"name": "Frag Grenade", "short": "Frag", "type": &"item", "rarity": &"U", "cost": 3, "brace": 0, "dmg": 2, "rng": 1, "text": "Spent. Choose one area within Range 1: resolve a 2-damage shot against each player there (including you). Ignores Cover. Brace and Down apply."},
	&"cz_016": {"name": "Hunting Rifle", "short": "Hunt Rifle", "type": &"weapon", "rarity": &"U", "cost": 4, "brace": 0, "dmg": 2, "rng": 1, "text": "Shoot. DMG 2 · RNG 1."},
	&"cz_017": {"name": "Long Scope", "short": "Scope", "type": &"attachment", "rarity": &"U", "cost": 3, "brace": 0, "bonus": "+1 RNG", "text": "Attach: +1 RNG (max RNG 2)."},
	&"cz_018": {"name": "Medkit", "short": "Medkit", "type": &"item", "rarity": &"U", "cost": 4, "brace": 0, "heal": 2, "text": "Heal 2."},
	&"cz_019": {"name": "Plate Vest", "short": "Vest", "type": &"item", "rarity": &"U", "cost": 4, "brace": 2, "move": 1, "text": "Move 1. Brace 2."},
	&"cz_020": {"name": "Crowbar", "short": "Crowbar", "type": &"item", "rarity": &"C", "cost": 2, "brace": 0, "search": 2, "text": "Search 2."},
	&"cz_021": {"name": "Backpack", "short": "Backpack", "type": &"item", "rarity": &"U", "cost": 3, "brace": 0, "search": 1, "pull": 1, "text": "Search 1. Pull 1."},
	&"cz_022": {"name": "Red-dot Sight", "short": "Red-dot", "type": &"attachment", "rarity": &"C", "cost": 2, "brace": 0, "bonus": "+1 DMG", "text": "Attach: +1 DMG."},
	&"cz_023": {"name": "Assault Rifle", "short": "AR", "type": &"weapon", "rarity": &"R", "cost": 6, "brace": 0, "dmg": 3, "rng": 1, "text": "Shoot. DMG 3 · RNG 1."},
	&"cz_024": {"name": "Marksman Rifle", "short": "Marksman", "type": &"weapon", "rarity": &"R", "cost": 6, "brace": 0, "dmg": 2, "rng": 2, "text": "Shoot. DMG 2 · RNG 2. Ignores Cover."},
	&"cz_025": {"name": "Extended Mag", "short": "Ext. Mag", "type": &"attachment", "rarity": &"R", "cost": 5, "brace": 0, "bonus": "+1 shot", "text": "Attach: this weapon may fire one extra time each turn."},
	&"cz_026": {"name": "Suppressor", "short": "Suppressor", "type": &"attachment", "rarity": &"R", "cost": 5, "brace": 0, "bonus": "No Brace", "text": "Attach: targets can't Brace with cards against this weapon (Down still applies)."},
	&"cz_027": {"name": "Recon Drone", "short": "Drone", "type": &"item", "rarity": &"R", "cost": 5, "brace": 0, "search": 2, "pull": 1, "text": "Search 2. Pull 1."},
	&"cz_030": {"name": "Twin-Drum LMG", "short": "LMG", "type": &"weapon", "rarity": &"E", "cost": 3, "brace": 0, "dmg": 2, "rng": 1, "text": "Supply drop (Search 3). Shoot. DMG 2 · RNG 1. Fires twice each turn."},
	&"cz_031": {"name": "Heavy Plate", "short": "Hvy Plate", "type": &"item", "rarity": &"E", "cost": 3, "brace": 3, "heal": 1, "move": 1, "text": "Supply drop (Search 3). Heal 1. Move 1. Brace 3."},
	&"cz_032": {"name": "Longshot .50", "short": "Longshot", "type": &"weapon", "rarity": &"L", "cost": 3, "brace": 0, "dmg": 4, "rng": 2, "text": "Supply drop (Search 3). Shoot. DMG 4 · RNG 2. Ignores Cover."},
	&"cz_033": {"name": "Phantom Suit", "short": "Phantom", "type": &"item", "rarity": &"L", "cost": 3, "brace": 4, "move": 2, "search": 1, "text": "Supply drop (Search 3). Move 2. Search 1. Brace 4."},
}

## Ridge Hollow (spec §3). pos = map slot (ring around the Core). Piles for 2 players.
const AREAS: Array[Dictionary] = [
	{"id": &"docks", "num": "1", "name": "Docks", "cover": 0, "piles": [&"cz_010", &"cz_011"]},
	{"id": &"farmstead", "num": "2", "name": "Farmstead", "cover": 1, "piles": [&"cz_012", &"cz_013"]},
	{"id": &"quarry", "num": "3", "name": "Quarry", "cover": 1, "piles": [&"cz_014", &"cz_015"]},
	{"id": &"radio_hill", "num": "4", "name": "Radio Hill", "cover": 0, "piles": [&"cz_016", &"cz_017"]},
	{"id": &"motel", "num": "5", "name": "Motel", "cover": 1, "piles": [&"cz_018", &"cz_019"]},
	{"id": &"rail_yard", "num": "6", "name": "Rail Yard", "cover": 0, "piles": [&"cz_020", &"cz_021", &"cz_022"]},
	{"id": &"old_town", "num": "C", "name": "Old Town", "cover": 1, "piles": [&"cz_023", &"cz_024", &"cz_025", &"cz_026", &"cz_027"]},
]

## Zone deck (spec §8). kind: calm, drop, gas, gas_drop, final. Per route: {gas: area, drop: area}.
const ZONE: Array[Dictionary] = [
	{"n": 1, "kind": &"calm", "title": "Calm (drop round)"},
	{"n": 2, "kind": &"calm", "title": "Calm"},
	{"n": 3, "kind": &"drop", "title": "Supply drop: Twin-Drum LMG", "card": &"cz_030", "A": {"drop": &"quarry"}, "B": {"drop": &"docks"}, "C": {"drop": &"motel"}},
	{"n": 4, "kind": &"gas", "title": "Gas closes", "A": {"gas": &"docks"}, "B": {"gas": &"radio_hill"}, "C": {"gas": &"farmstead"}},
	{"n": 5, "kind": &"calm", "title": "Calm"},
	{"n": 6, "kind": &"gas_drop", "title": "Gas closes + drop: Heavy Plate", "card": &"cz_031", "A": {"gas": &"farmstead", "drop": &"motel"}, "B": {"gas": &"quarry", "drop": &"rail_yard"}, "C": {"gas": &"rail_yard", "drop": &"radio_hill"}},
	{"n": 7, "kind": &"gas", "title": "Gas closes", "A": {"gas": &"rail_yard"}, "B": {"gas": &"motel"}, "C": {"gas": &"docks"}},
	{"n": 8, "kind": &"drop", "title": "Supply drop: Longshot .50", "card": &"cz_032", "A": {"drop": &"old_town"}, "B": {"drop": &"old_town"}, "C": {"drop": &"old_town"}},
	{"n": 9, "kind": &"gas", "title": "Gas closes", "A": {"gas": &"radio_hill"}, "B": {"gas": &"farmstead"}, "C": {"gas": &"quarry"}},
	{"n": 10, "kind": &"gas_drop", "title": "Gas closes + drop: Phantom Suit", "card": &"cz_033", "A": {"gas": &"quarry", "drop": &"motel"}, "B": {"gas": &"docks", "drop": &"rail_yard"}, "C": {"gas": &"radio_hill", "drop": &"motel"}},
	{"n": 11, "kind": &"gas", "title": "Gas closes", "A": {"gas": &"motel"}, "B": {"gas": &"rail_yard"}, "C": {"gas": &"motel"}},
	{"n": 12, "kind": &"final", "title": "Final circle I: 1 Hit each (Bounty holder +1)"},
	{"n": 13, "kind": &"final", "title": "Final circle II: 2 Hits each (Bounty holder +1)"},
	{"n": 14, "kind": &"final", "title": "Final circle III: 3 Hits each (Bounty holder +1). Game ends."},
]

const KIND_SHORT: Dictionary = {&"calm": "Calm", &"drop": "Drop", &"gas": "Gas", &"gas_drop": "Gas+Drop", &"final": "Final"}


static func card(id: StringName) -> Dictionary:
	var c: Dictionary = CARDS.get(id, {}).duplicate()
	c["id"] = id
	return c


static func all_cards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in CARDS.keys():
		out.append(card(id))
	return out


static func area(id: StringName) -> Dictionary:
	for a: Dictionary in AREAS:
		if a["id"] == id:
			return a
	return {}


static func zone_card(n: int) -> Dictionary:
	return ZONE[clampi(n, 1, ZONE.size()) - 1]


## Areas after Zone cards 1..zone_index on this route: gas and drops.
static func areas_at(zone_index: int, route: StringName, taken: Array = []) -> Dictionary:
	var out: Dictionary = {}
	for a: Dictionary in AREAS:
		var piles: Array = []
		for p: StringName in a["piles"]:
			if not taken.has(p):
				piles.append({"card": p, "count": 3 if a["id"] != &"old_town" else 2})
		out[a["id"]] = {"gas": false, "piles": piles, "drop": &""}
	for i: int in range(1, zone_index + 1):
		var z: Dictionary = zone_card(i)
		var r: Dictionary = z.get(String(route), {})
		if r.has("gas"):
			out[r["gas"]]["gas"] = true
		if r.has("drop") and not taken.has(z["card"]):
			out[r["drop"]]["drop"] = z["card"]
	return out


## Round 1: Standard pack, hand 5, both at full health, no Bounty (tie).
static func start_state() -> Dictionary:
	return {
		"round": 1, "zone_index": 1, "route": &"A", "hand_size": 5,
		"areas": areas_at(1, &"A"),
		"you": {"name": "You", "area": &"rail_yard", "health": 5, "max_health": 5, "bounty": false, "down": false,
			"hand": [&"cz_002", &"cz_002", &"cz_002", &"cz_004", &"cz_003"], "line": [], "held": [],
			"next": [&"cz_003", &"cz_001", &"cz_002", &"cz_004", &"cz_003"], "loadout_rest": 0},
		"rival": {"name": "Rival", "kind": "Rookie", "area": &"quarry", "health": 5, "max_health": 5, "bounty": false,
			"down": false, "loadout_count": 10, "held_count": 0, "last_line": []},
	}


## Round 5: mid-turn. You hold the Bounty; the rival is Down. A Hit came along with your hand.
static func mid_state() -> Dictionary:
	return {
		"round": 5, "zone_index": 5, "route": &"A", "hand_size": 5,
		"areas": areas_at(5, &"A", [&"cz_030"]),
		"you": {"name": "You", "area": &"radio_hill", "health": 4, "max_health": 5, "bounty": true, "down": false,
			"hand": [HIT, &"cz_016", &"cz_002", &"cz_019", &"cz_003", &"cz_004"],
			"line": [{"card": &"cz_020", "attached": []}, {"card": &"cz_003", "attached": []}],
			"held": [&"cz_013", &"cz_004"],
			"next": [&"cz_013", &"cz_004", &"cz_002", &"cz_001", &"cz_003"], "loadout_rest": 4},
		"rival": {"name": "Rival", "kind": "Rookie", "area": &"quarry", "health": 3, "max_health": 5, "bounty": false,
			"down": true, "loadout_count": 13, "held_count": 2, "last_line": [&"cz_030", &"cz_002"]},
	}


## Round 12 (final circle I): a crowded turn. You are Down, 2 Hits came with your hand, a long line.
static func late_state() -> Dictionary:
	return {
		"round": 12, "zone_index": 12, "route": &"A", "hand_size": 5,
		"areas": areas_at(12, &"A", [&"cz_030", &"cz_031", &"cz_032", &"cz_016", &"cz_023"]),
		"you": {"name": "You", "area": &"old_town", "health": 2, "max_health": 5, "bounty": false, "down": true,
			"hand": [HIT, HIT, &"cz_023", &"cz_019", &"cz_027", &"cz_002", &"cz_004"],
			"line": [{"card": &"cz_020", "attached": []}, {"card": &"cz_021", "attached": []},
				{"card": &"cz_016", "attached": [&"cz_022", &"cz_017"]}, {"card": &"cz_003", "attached": []},
				{"card": &"cz_011", "attached": []}, {"card": &"cz_012", "attached": []}],
			"held": [&"cz_031"],
			"next": [HIT, &"cz_031", &"cz_018", &"cz_002", &"cz_003", &"cz_013"], "loadout_rest": 6},
		"rival": {"name": "Rival", "kind": "Veteran", "area": &"old_town", "health": 3, "max_health": 5, "bounty": true,
			"down": false, "loadout_count": 16, "held_count": 2, "last_line": [&"cz_032", &"cz_025"]},
	}

# mock_match_data.gd
# Purpose: Mock per-seat match views for the cz10 layout (no rules engine yet). Every card, area and
#   Zone id is a CardDB id (cz05 / cz06 data: data/cards, data/areas, data/zone), so cz11 can swap
#   these states for cz07's view(state, seat) without touching the screen. Only what the viewing seat
#   may see is here: the rival's held cards and loadout order are NOT in a state (spec §16 private
#   loadouts; prototype-scope.md §4 held_cards_public = false), only their counts.
# View shape (MatchScreen.show_state):
#   {round, zone_index (revealed Zone card, 1-14), route (DataEnums.Route), hand_size,
#    areas: {area_id: {gas: bool, piles: [{card: card_id, count: int}], drop: card_id or &""}},
#    you:   {name, area, health, max_health, bounty, down, hand: [card_id], line: [{card, attached: [card_id]}],
#            held: [card_id], next: [card_id] (top of the loadout down to the last card of the next hand,
#            Hits included), loadout_rest: int (cards below the next hand)},
#    rival: {name, kind, area, health, max_health, bounty, down, loadout_count, held_count, last_line: [card_id]}}
# Dependencies: CardDB autoload (areas, piles, Zone deck, balance), DataEnums.
# Author: UI/UX Agent (cz10)
extends RefCounted

const HIT: StringName = &"hit"


static func _db() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null("CardDB") if loop != null else null


## Areas after Zone cards 1..zone_index on this route: gas and supply drops. taken: card ids no
## longer in their pile or drop (looted).
static func areas_at(zone_index: int, route: DataEnums.Route, taken: Array = []) -> Dictionary:
	var db: Node = _db()
	var out: Dictionary = {}
	var bal: BalanceConfig = db.get_balance()
	for a: AreaData in db.all_areas():
		var piles: Array = []
		for c: CardData in a.piles:
			if not taken.has(c.id):
				piles.append({"card": c.id, "count": bal.pile_size_core if a.tier == DataEnums.AreaTier.CORE else bal.pile_size_outer})
		out[a.id] = {"gas": false, "piles": piles, "drop": &""}
	for z: ZoneCardData in db.zone_deck():
		if z.number > zone_index:
			break
		var closed: AreaData = z.close_for(route)
		if closed != null:
			out[closed.id]["gas"] = true
		var dropped: AreaData = z.drop_area_for(route)
		if dropped != null and z.drop_card != null and not taken.has(z.drop_card.id):
			out[dropped.id]["drop"] = z.drop_card.id
	return out


## Round 1: Standard pack, hand 5, both at full health, no Bounty (tie).
static func start_state() -> Dictionary:
	return {
		"round": 1, "zone_index": 1, "route": DataEnums.Route.A, "hand_size": 5,
		"areas": areas_at(1, DataEnums.Route.A),
		"you": {"name": "You", "area": &"rail_yard", "health": 5, "max_health": 5, "bounty": false, "down": false,
			"hand": [&"scavenge", &"scavenge", &"scavenge", &"duck", &"dash"], "line": [], "held": [],
			"next": [&"dash", &"p9_sidearm", &"scavenge", &"duck", &"dash"], "loadout_rest": 0},
		"rival": {"name": "Rival", "kind": "Rookie", "area": &"quarry", "health": 5, "max_health": 5, "bounty": false,
			"down": false, "loadout_count": 10, "held_count": 0, "last_line": []},
	}


## Round 5: mid-turn. You hold the Bounty; the rival is Down. A Hit came along with your hand.
static func mid_state() -> Dictionary:
	return {
		"round": 5, "zone_index": 5, "route": DataEnums.Route.A, "hand_size": 5,
		"areas": areas_at(5, DataEnums.Route.A, [&"twin_drum_lmg"]),
		"you": {"name": "You", "area": &"radio_hill", "health": 4, "max_health": 5, "bounty": true, "down": false,
			"hand": [HIT, &"hunting_rifle", &"scavenge", &"plate_vest", &"dash", &"duck"],
			"line": [{"card": &"crowbar", "attached": []}, {"card": &"dash", "attached": []}],
			"held": [&"smoke_grenade", &"duck"],
			"next": [&"smoke_grenade", &"duck", &"scavenge", &"p9_sidearm", &"dash"], "loadout_rest": 4},
		"rival": {"name": "Rival", "kind": "Rookie", "area": &"quarry", "health": 3, "max_health": 5, "bounty": false,
			"down": true, "loadout_count": 13, "held_count": 2, "last_line": [&"twin_drum_lmg", &"scavenge"]},
	}


## Round 12 (final circle I): a crowded turn. You are Down, 2 Hits came with your hand, a long line.
static func late_state() -> Dictionary:
	return {
		"round": 12, "zone_index": 12, "route": DataEnums.Route.A, "hand_size": 5,
		"areas": areas_at(12, DataEnums.Route.A, [&"twin_drum_lmg", &"heavy_plate", &"longshot_50", &"hunting_rifle", &"assault_rifle"]),
		"you": {"name": "You", "area": &"old_town", "health": 2, "max_health": 5, "bounty": false, "down": true,
			"hand": [HIT, HIT, &"assault_rifle", &"plate_vest", &"recon_drone", &"scavenge", &"duck"],
			"line": [{"card": &"crowbar", "attached": []}, {"card": &"backpack", "attached": []},
				{"card": &"hunting_rifle", "attached": [&"red_dot_sight", &"long_scope"]}, {"card": &"dash", "attached": []},
				{"card": &"trail_boots", "attached": []}, {"card": &"bandage", "attached": []}],
			"held": [&"heavy_plate"],
			"next": [HIT, &"heavy_plate", &"medkit", &"scavenge", &"dash", &"smoke_grenade"], "loadout_rest": 6},
		"rival": {"name": "Rival", "kind": "Veteran", "area": &"old_town", "health": 3, "max_health": 5, "bounty": true,
			"down": false, "loadout_count": 16, "held_count": 2, "last_line": [&"longshot_50", &"extended_mag"]},
	}


## Every card id a state mentions (tests).
static func card_ids(state: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var you: Dictionary = state["you"]
	for id: StringName in you["hand"] + you["next"] + you["held"]:
		out.append(id)
	for e: Dictionary in you["line"]:
		out.append(e["card"])
		for a: StringName in e["attached"]:
			out.append(a)
	return out

# data_enums.gd
# Pattern adapted from CallingCard scripts/data/data_enums.gd; the enums are new for CardZone.
# Purpose: Shared enums and fixed numbers for every CardZone data Resource
#   (spec loadout-loop-spec.md §3, §6, §8, §16). Values are stored as ints in .tres files,
#   so ONLY APPEND new values at the end of an enum; never reorder or remove, or existing
#   data changes meaning.
# Dependencies: none.
# Author: Mechanics Developer Agent
class_name DataEnums
extends RefCounted

## What a card is (spec §6, §11). HIT is the health card (Adrenaline face), MARKER the shared Bounty.
enum CardType { WEAPON, ATTACHMENT, ITEM, HIT, MARKER }

## Rarity chip (spec §6). NONE = Hit and Bounty. STARTER = the 10 loadout cards (no chip).
enum Rarity { NONE, STARTER, COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

## When a card with the Spent keyword leaves the game (spec R20).
enum SpentMode { NONE, ON_PLAY, ON_BRACE }

## Area tier: picks the pile size (pile_size_outer / pile_size_core) and the rarities expected there.
enum AreaTier { OUTER, CORE }

## Zone deck route (spec §8). The route is chosen in setup (S2).
enum Route { A, B, C }

## Pack rule (spec R50, R51; tunable packing_rule).
enum PackingRule { HOLD_AND_STOW, RACK_SWAP }

## What a Hit played as Adrenaline may give (spec R6; tunable adrenaline_mode).
enum AdrenalineMode { MOVE_OR_SEARCH, MOVE_ONLY }

## Derived Zone card kind (never stored; ZoneCardData.kind()).
enum ZoneKind { CALM, GAS, DROP, GAS_AND_DROP, FINAL_CIRCLE }

## Range on Ridge Hollow: 0 same area, 1 adjacent, 2 anywhere (spec §3). Weapon RNG, Long Scope cap
## and the map's largest distance all use it.
const MAX_RANGE: int = 2
## Starting loadout size (spec §10: 10 cards, never shuffled).
const LOADOUT_SIZE: int = 10
## Areas on the map (spec §3: 6 outer areas plus the Core).
const MAP_AREA_COUNT: int = 7
## Largest Cover an area may print (spec values are 0 and 1; 2 leaves room to tune).
const MAX_COVER: int = 2
## Search cost limit for a loot pile (spec costs are 2-6).
const MAX_COST: int = 9
## Rarities that may sit in loot piles, per AreaTier (spec §3). Outside this is a warning.
const PILE_RARITIES: Dictionary = {
	AreaTier.OUTER: [Rarity.COMMON, Rarity.UNCOMMON],
	AreaTier.CORE: [Rarity.RARE],
}
## Rarity letters for the chip (spec §6). Index = Rarity.
const RARITY_LETTERS: PackedStringArray = ["", "", "C", "U", "R", "E", "L"]
## Route letters. Index = Route.
const ROUTE_LETTERS: PackedStringArray = ["A", "B", "C"]


static func is_loot_rarity(rarity: int) -> bool:
	return rarity >= Rarity.COMMON and rarity <= Rarity.LEGENDARY


static func rarity_letter(rarity: int) -> String:
	if rarity < 0 or rarity >= RARITY_LETTERS.size():
		return "?"
	return RARITY_LETTERS[rarity]


## Enum key for a value, for readable validation messages ("WEAPON" or "<9?>").
static func key_of(enum_dict: Dictionary, value: int) -> String:
	var key: Variant = enum_dict.find_key(value)
	return String(key) if key != null else "<%d?>" % value

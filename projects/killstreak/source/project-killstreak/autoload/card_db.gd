# card_db.gd
# Purpose: CardDB autoload. Loads card, loadout and squad Resources from res://data/
#   and serves lookups by id. Stub for p01; typed loading and validation land in p02.
# Dependencies: none (data classes arrive in p02).
# Author: Mechanics Developer Agent
extends Node

const DATA_ROOT: String = "res://data"

## id -> Resource, filled by load_all() in p02.
var _cards: Dictionary = {}


## Returns the card Resource for id, or null when unknown.
func get_card(id: StringName) -> Resource:
	return _cards.get(id)


## True when a card with this id is loaded.
func has_card(id: StringName) -> bool:
	return _cards.has(id)


## Number of loaded cards.
func card_count() -> int:
	return _cards.size()

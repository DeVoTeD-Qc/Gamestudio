# run_state.gd
# Purpose: RunState autoload. Holds the current run (matches, tickets, deck, loadout)
#   and saves/loads it to user://run_save.json. Stub for p01; flow arrives in p10.
# Dependencies: EventBus.
# Author: Mechanics Developer Agent
extends Node

const SAVE_PATH: String = "user://run_save.json"
## Defaults until run_config.tres exists (p02): 5 matches, 3 tickets.
const DEFAULT_MATCHES: int = 5
const DEFAULT_TICKETS: int = 3

var active: bool = false
var match_index: int = 0
var matches_total: int = DEFAULT_MATCHES
var tickets: int = DEFAULT_TICKETS
var deck: Array[StringName] = []
var killstreak_picks: Array[StringName] = []


## Clears all run data back to defaults.
func reset() -> void:
	active = false
	match_index = 0
	matches_total = DEFAULT_MATCHES
	tickets = DEFAULT_TICKETS
	deck.clear()
	killstreak_picks.clear()


## True when a saved run exists on disk.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

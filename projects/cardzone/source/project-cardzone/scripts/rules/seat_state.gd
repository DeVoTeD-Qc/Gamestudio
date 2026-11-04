# seat_state.gd
# Purpose: One player's part of a CardZone MatchState (spec §16.1 D1-D8): pawn, health stack,
#   loadout (top first), held marks, hand and line (in entry order, D7), this turn's pools and
#   counters. Cards are instance ids (ints) into MatchState.defs. Plain data; the rules live in
#   LoadoutRules. Private to the owner: loadout order and contents, held card identities, hand
#   identities (spec §16.2 P1, P2, P9, P14); MatchView decides what the opponent sees.
# Dependencies: none.
# Author: Mechanics Developer Agent
class_name SeatState
extends RefCounted

## Every serialised field, in a fixed order (to_dict / load_dict / snapshots for undo).
const FIELDS: Array[String] = [
	"area", "health", "loadout", "held", "hand", "line", "move", "search", "fired", "looted",
	"touched", "adrenaline_played", "ditched", "braced", "eliminated",
]

## Area id of the pawn (&"" before the drop).
var area: StringName = &""
## Health stack: Hit instance ids, the last one is the top (D3: health = size).
var health: Array[int] = []
## Loadout, index 0 = top.
var loadout: Array[int] = []
## Instance ids in the loadout that carry a held mark (cleared when drawn or braced, RQ-02).
var held: Array[int] = []
## Hand in hand order (draw order, then Pull order).
var hand: Array[int] = []
## Line, left to right (played and looted cards in entry order).
var line: Array[int] = []
## This turn's pools (R7).
var move: int = 0
var search: int = 0
## Weapon instance id -> shots declared this turn (R12).
var fired: Dictionary = {}
## Cards looted this turn (R9, hold_looted R50).
var looted: Array[int] = []
## Cards attached to or from this turn (a looted card that was attached is not "unused", R50).
var touched: Array[int] = []
var adrenaline_played: int = 0
var ditched: int = 0
## Cards this seat braced with during the current turn (R26: once per card per turn).
var braced: Array[int] = []
var eliminated: bool = false


func health_count() -> int:
	return health.size()


## Resets the per-turn pools and counters (start of any turn, for both seats' brace memory).
func reset_turn() -> void:
	move = 0
	search = 0
	fired = {}
	looted.clear()
	touched.clear()
	adrenaline_played = 0
	ditched = 0
	braced.clear()


func to_dict() -> Dictionary:
	var d: Dictionary = {}
	for f: String in FIELDS:
		var value: Variant = get(f)
		d[f] = value.duplicate(true) if (value is Array or value is Dictionary) else value
	return d


func load_dict(d: Dictionary) -> void:
	for f: String in FIELDS:
		if not d.has(f):
			continue
		var value: Variant = d[f]
		var current: Variant = get(f)
		if current is Array:
			var arr: Array = current
			arr.clear()
			for x: Variant in value:
				arr.append(int(x))
		elif current is Dictionary:
			var copy: Dictionary = {}
			for k: Variant in (value as Dictionary).keys():
				copy[int(k)] = int(value[k])
			set(f, copy)
		elif f == "area":
			area = StringName(value)
		elif f == "eliminated":
			eliminated = bool(value)
		else:
			set(f, int(value))

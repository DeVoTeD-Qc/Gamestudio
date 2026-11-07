# terrain_data.gd
# Purpose: One Terrain (run-v2.md §6; internally a "map Field"): a one-line column rule dealt to a
#   column of a run-map fight. It belongs to neither side, applies to both, can't be shot, Sabotaged,
#   Overrun or replaced, and never counts for traits. The rule itself lives in MatchState / ModeRules
#   (keyed by `id`, see TerrainRules); this resource is the player-facing data.
#   Player-facing name: "Terrain" (head V1), never "Field".
#   One Terrain = one .tres in res://data/terrain/.
# Dependencies: DataValidator.
# Author: Mechanics Developer Agent (kc-v2-impl)
class_name TerrainData
extends Resource

## Unique id = the rule id (TerrainRules.ALL): rooftops, smoke, dust_storm ...
@export var id: StringName = &""
@export var display_name: String = ""
## The one-line rule as printed on the column band.
@export_multiline var text: String = ""
## Inspect view: what it makes you decide / an example (one or two lines).
@export_multiline var detail: String = ""
## Dealt only in Zone Control matches (Hot Zone).
@export var zone_control_only: bool = false
@export var icon: Texture2D = null


func validate(v: DataValidator) -> void:
	v.require_id(id)
	v.require_text("display_name", display_name)
	v.require_text("text", text)
	if id != &"" and id not in TerrainRules.ALL:
		v.invalid("id", "'%s' is not a Terrain rule TerrainRules knows" % id)
	if text.to_lower().contains("field"):
		v.invalid("text", "player-facing Terrain text never says 'Field' (head V1: it is Terrain)")

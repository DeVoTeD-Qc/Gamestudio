# run_match_data.gd
# Purpose: One match slot in a run (embedded in RunConfig.matches, in play order):
#   which squad, mode and map, and Bracket 2 stat scaling.
# Dependencies: DataEnums, SquadData, MapData, DataValidator.
# Author: Mechanics Developer Agent
class_name RunMatchData
extends Resource

## Bracket number shown on the run map (1, 2 ...). The Rival match uses the last bracket.
@export_range(1, 5) var bracket: int = 1
## The Rival / final match.
@export var is_rival: bool = false
@export var squad: SquadData = null
@export var mode: DataEnums.GameMode = DataEnums.GameMode.ZONE_CONTROL
@export var map: MapData = null
## Added to every enemy unit's Firepower / Armor in this match (Bracket 2 scaling).
@export_range(0, 5) var enemy_firepower_bonus: int = 0
@export_range(0, 5) var enemy_armor_bonus: int = 0


func validate(v: DataValidator, prefix: String) -> void:
	v.check_range(prefix + ".bracket", bracket, 1, 5)
	v.check_ref(prefix + ".squad", squad, SquadData, true)
	v.check_enum(prefix + ".mode", mode, DataEnums.GameMode)
	v.check_ref(prefix + ".map", map, MapData, true)
	v.check_range(prefix + ".enemy_firepower_bonus", enemy_firepower_bonus, 0, 5)
	v.check_range(prefix + ".enemy_armor_bonus", enemy_armor_bonus, 0, 5)
	if mode == DataEnums.GameMode.DETONATOR:
		v.warn(prefix + ".mode", "Detonator is a stretch goal; the prototype rules engine may not support it")

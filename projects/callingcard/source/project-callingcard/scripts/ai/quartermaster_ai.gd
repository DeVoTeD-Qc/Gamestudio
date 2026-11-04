# quartermaster_ai.gd
# Purpose: Easy rival brain (spec §7 Quartermaster): with best_capture_chance it takes the best
#   immediate move (the Archivist's greedy pick), otherwise a random legal move. 0 plies.
# Dependencies: RivalAI.
# Author: Mechanics Developer Agent
class_name QuartermasterAI
extends RivalAI


func brain_name() -> StringName:
	return &"quartermaster"


func _pick(world: WallState, me: int, moves: Array[Dictionary]) -> int:
	if _rng.randf() < best_capture_chance:
		return pick_one(best_indices(greedy_values(world, me, moves)))
	return _rng.randi_range(0, moves.size() - 1)

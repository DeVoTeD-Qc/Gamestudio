# archivist_ai.gd
# Purpose: Normal rival brain (spec §7 Archivist): greedy, 1 ply. Plays the move with the best
#   position right after it resolves (score difference, the springs that follow included, a win
#   bonus on the last placement). Ties are broken with the seeded RNG.
# Dependencies: RivalAI.
# Author: Mechanics Developer Agent
class_name ArchivistAI
extends RivalAI


func brain_name() -> StringName:
	return &"archivist"


func _pick(world: WallState, me: int, moves: Array[Dictionary]) -> int:
	return pick_one(best_indices(greedy_values(world, me, moves)))

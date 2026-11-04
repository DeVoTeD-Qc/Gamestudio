# random_rival.gd
# Purpose: Placeholder opponent until cc06's AI lands: a random legal move (WallRules.legal_moves),
#   seeded so a duel replays exactly.
# Dependencies: rival_brain.gd, WallRules.
# Author: UI/UX Agent (cc08)
extends "res://scripts/duel/rival_brain.gd"

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


func choose_move(state: WallState, _player: int) -> Dictionary:
	var moves: Array[Dictionary] = WallRules.legal_moves(state)
	if moves.is_empty():
		return {}
	return moves[_rng.randi_range(0, moves.size() - 1)]

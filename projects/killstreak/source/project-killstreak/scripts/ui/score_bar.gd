# score_bar.gd
# Purpose: Score bar (top-left): YOU score - score ENEMY, the round counter
#   "RD 3/8 · DEPLOY" and the mode line. Side names are spelled out (not color only).
# Dependencies: none.
# Author: UI/UX Agent
extends PanelContainer

@onready var _player: Label = %PlayerScore
@onready var _enemy: Label = %EnemyScore
@onready var _round: Label = %RoundLabel
@onready var _mode: Label = %ModeLabel


func set_score(snapshot: Dictionary) -> void:
	_player.text = str(snapshot.get("score_player", 0))
	_enemy.text = str(snapshot.get("score_enemy", 0))
	_round.text = "RD %d/%d · %s" % [snapshot.get("round", 1), snapshot.get("round_cap", 8),
			snapshot.get("phase", "")]
	_mode.text = "%s · %s" % [snapshot.get("mode", ""), snapshot.get("goal", "")]

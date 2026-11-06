# fight_state.gd
# Purpose: kc-fight PROTOTYPE (sim only): a MatchState whose Firefight uses the activation
#   order picked in tests/tools/fight_order.gd (order = &"now" keeps the shipped resolver).
#   Everything else (Deploy, Reveal, synergy, Score, Overrun, Undead heal) is the shipped engine.
# Dependencies: MatchState, fight_order.gd.
# Author: Sr Game Designer Agent (kc-fight)
extends MatchState

const FightOrder = preload("res://tests/tools/fight_order.gd")


func firefight() -> void:
	if FightOrder.order == &"now":
		super.firefight()
		return
	_set_phase(Phase.FIREFIGHT)
	FightOrder.resolve(self)
	announce_synergy()

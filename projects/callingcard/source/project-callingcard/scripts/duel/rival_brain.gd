# rival_brain.gd
# Purpose: The opponent interface the duel controller talks to (cc08). An AI rival (cc06:
#   Quartermaster / Archivist / Warden) extends this and overrides choose_move().
#   Same shape as cc06's RivalAI (scripts/ai): choose_move(state, player) gets a COPY of the
#   WallState with `player` (the rival) to move and returns one of
#   WallRules.legal_moves(state): {card: CardData, slot: StringName, copy_from: StringName},
#   or {} when it has no move. It must not read the player's hand order (spec §4.2).
#   Swap in the real AI with one line: DuelController.brain_factory = func(rival: RivalData, _seed: int):
#   return RivalAI.for_rival(rival)   (or set it where the duel starts).
# Dependencies: WallState, WallRules.
# Author: UI/UX Agent (cc08)
extends RefCounted


func choose_move(_state: WallState, _player: int) -> Dictionary:
	return {}

# opponent_placeholder.gd
# Purpose: Stand-in opponent for the match controller (cz11) until CzAI (cz09) lands: it takes the
#   first legal action for its seat. Every player action uses up a pool, a card or a shot, so a
#   turn always reaches end_turn; drop picks the first outer area; brace picks the first option
#   (no cards).
# Opponent interface (what CzAI implements; MatchController.opponent holds any object with it):
#   func choose_action(state: MatchState, seat: int) -> Dictionary
#     Called only when `seat` must act (state.deciding_seat() == seat: its drop, its turn, or its
#     Brace). Returns one LoadoutRules action for that seat ({} = no idea: the controller then takes
#     the first legal action). A fair AI reads only LoadoutRules.view(state, seat) and
#     legal_actions(state); `state` is passed so it can call those and preview_shot.
# Dependencies: LoadoutRules, MatchState.
# Author: UI/UX Agent (cz11)
extends RefCounted

## Shown in the rival panel ("RIVAL · PLACEHOLDER").
var kind: String = "Placeholder"


func choose_action(state: MatchState, seat: int) -> Dictionary:
	for a: Dictionary in LoadoutRules.legal_actions(state):
		if int(a.get("seat", -1)) == seat:
			return a
	return {}

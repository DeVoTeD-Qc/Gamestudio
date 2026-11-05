# rules_intent.gd
# Purpose: Builders for the player / AI intents MatchState.submit() accepts during
#   Deploy. An intent is a plain Dictionary so it can be logged, replayed and sent
#   over a network later. Zones are indices 0 = left, 1 = mid, 2 = right.
#   - play_card: a card from hand by its uid. `zone` = where a unit / equipment goes or
#     the zone a tactic targets; `target_uid` = a chosen unit (CHOSEN_ENEMY /
#     CHOSEN_FRIENDLY; may be the card uid of a unit played earlier this Deploy);
#     `dest_zone` = destination of a MOVE_UNIT (Flank Route).
#   - place_operator: place an off-board Operator (Round 1, respawn).
#   - rotate: move the Operator to an adjacent zone (back of the line).
#   - use_item: activate a Secondary / Lethal / Tactical / killstreak by its id.
# Dependencies: none.
# Author: Mechanics Developer Agent
class_name RulesIntent
extends RefCounted

const PLAY_CARD: StringName = &"play_card"
const PLACE_OPERATOR: StringName = &"place_operator"
const ROTATE: StringName = &"rotate"
const USE_ITEM: StringName = &"use_item"


static func play_card(card_uid: int, zone: int = -1, target_uid: int = -1, dest_zone: int = -1) -> Dictionary:
	return {"type": PLAY_CARD, "card_uid": card_uid, "zone": zone, "target_uid": target_uid, "dest_zone": dest_zone}


static func place_operator(zone: int) -> Dictionary:
	return {"type": PLACE_OPERATOR, "zone": zone}


static func rotate(zone: int) -> Dictionary:
	return {"type": ROTATE, "zone": zone}


static func use_item(item_id: StringName, zone: int = -1, target_uid: int = -1, dest_zone: int = -1) -> Dictionary:
	return {"type": USE_ITEM, "item_id": item_id, "zone": zone, "target_uid": target_uid, "dest_zone": dest_zone}

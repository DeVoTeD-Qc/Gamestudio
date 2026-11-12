# play_text.gd
# Purpose: Player-facing text for the rules engine's play-check reason codes (f02). The engine
#   (MatchState.can_submit / check_use / can_mulligan) decides; this only words its answer:
#   a short column badge ("COLUMN FULL"), a sentence for the toast, and a short button state for
#   the Operator panel ("CD 2", "USED"). Unknown codes fall back to the engine's own reason.
# Dependencies: MatchState (zone count only).
# Author: Mechanics Developer Agent (f02)
extends RefCounted

## kc-board: zones are shown as columns A / B / C.
const ZONE_WORDS: PackedStringArray = ["Column A", "Column B", "Column C"]


## {badge, reason} for a refused check. `ctx` names the thing being played:
## {name: String, kind: &"card"|&"item"|&"operator"|&"move", threshold: int}.
static func describe(check: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	var code: StringName = check.get("code", &"")
	var data: Dictionary = check.get("data", {})
	var label: String = String(ctx.get("name", "It"))
	var kind: StringName = ctx.get("kind", &"card")
	match code:
		&"wrong_phase":
			return _t("WAIT", "Wrong phase: play cards in Deploy.")
		&"already_ready":
			return _t("READY", "You already pressed READY.")
		&"not_in_hand":
			return _t("", "That card left your hand.")
		&"not_enough_supply":
			return _t("NEED %d SUPPLY" % int(data.get("cost", 0)),
					"Not enough Supply: %s costs %d, you have %d." % [label, int(data.get("cost", 0)), int(data.get("supply", 0))])
		&"zone_full":
			var z: int = int(data.get("zone", 0))
			return _t("COLUMN FULL", "Column full: %s already has %d units." % [_zone(z), int(data.get("capacity", 4))])
		&"no_zone":
			return _t("", "Drop it on a column.")
		&"operator_not_placed":
			return _t("NO OPERATOR", "Your Operator is not on the board.")
		&"out_of_range":
			return _t("TOO FAR", "Pick your Operator's column or one next to it.")
		&"no_target":
			if data.get("want", &"") == &"friendly":
				return _t("PICK A UNIT", "Pick one of your units first.")
			return _t("PICK AN ENEMY", "Pick an enemy unit first.")
		&"target_out_of_range":
			return _t("OUT OF RANGE", "Pick an enemy in your Operator's column.")
		&"no_legal_target":
			return _t("NO TARGET", "%s has no target in reach." % label)
		&"same_zone":
			if kind == &"operator":
				return _t("HERE NOW", "Your Operator is already here.")
			return _t("ALREADY HERE", "That unit is already in this column.")
		&"not_adjacent":
			if kind == &"operator":
				return _t("NOT ADJACENT", "Rotate only to an adjacent column.")
			return _t("NOT ADJACENT", "Move only to an adjacent column.")
		&"no_rotations_left":
			return _t("NO ROTATION", "No Rotations left this round.")
		&"no_operator":
			return _t("", "You have no Operator.")
		&"cant_place", &"already_placed":
			return _t("", "Your Operator can't deploy now.")
		&"not_in_tray":
			var t: int = int(ctx.get("threshold", 0))
			return _t("LOCKED", "%s is not earned yet: reach a streak of %d." % [label, t] if t > 0 else "%s is not earned yet." % label)
		&"no_uses_left":
			return _t("USED", "%s was already used this %s." % [label, String(data.get("per", &"round"))])
		&"nothing_to_undo":
			return _t("", "Nothing to undo.")
		&"already_resolved":
			return _t("", "Already resolved: it can't be undone.")
		&"already_moved":  # kc-wip-impl Agile
			return _t("MOVED", "%s already moves this round (Agile: once a round)." % label)
		&"not_agile":
			return _t("", "Only an Agile unit can move like this.")
	return _t("", sentence(String(check.get("reason", ""))))


## Short second line of an Operator panel button for an item check (check_use result).
static func button_state(check: Dictionary, item: LoadoutItem, uses_left: int = -1) -> String:
	if check.get("ok", false):
		if item != null and item.slot == DataEnums.LoadoutSlot.KILLSTREAK:
			return "CALL IN"
		if item != null and item.supply_cost > 0:
			return "%d SUPPLY" % item.supply_cost
		return "%d LEFT" % uses_left if uses_left > 0 else "READY"
	var data: Dictionary = check.get("data", {})
	match check.get("code", &""):
		&"no_uses_left":
			return "USED"
		&"not_enough_supply":
			return "NEED %d" % int(data.get("cost", 0))
		&"operator_not_placed":
			return "NO OP"
		&"no_target", &"no_legal_target", &"target_out_of_range", &"out_of_range":
			return "NO TGT"
		&"wrong_phase", &"already_ready":
			return "WAIT"
		&"not_in_tray":
			return "AT %d" % (StreakTracker.MIN_THRESHOLD if item == null else item.streak_threshold)
	return "—"


static func sentence(reason: String) -> String:
	if reason.is_empty():
		return reason
	var out: String = reason.left(1).to_upper() + reason.substr(1)
	return out if out.ends_with(".") else out + "."


static func _zone(z: int) -> String:
	return ZONE_WORDS[z] if z >= 0 and z < ZONE_WORDS.size() else "That column"


static func _t(badge: String, reason: String) -> Dictionary:
	return {"ok": false, "badge": badge, "reason": reason}

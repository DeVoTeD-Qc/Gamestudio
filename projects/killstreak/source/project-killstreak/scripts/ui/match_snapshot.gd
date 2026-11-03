# match_snapshot.gd
# Purpose: Builds the match screen's view snapshot (the Dictionary shape documented in
#   mock_match_data.gd) from a live MatchState, as seen by one side. Read-only: it never
#   changes the state. Additions to the p08 shape (all optional for the scenes):
#   - unit entries: uid, pending (true for this Deploy's queued arrivals, shown as QUEUED)
#   - hand entries: uid, id, playable (cost <= Supply)
#   - can_undo, undo_label (name of the last play), deploy_open (Deploy and not READY yet),
#     result (&"" while running; &"player" / &"enemy" / &"draw" at the end)
#   Enemy face-down plays never leak: the enemy only shows units on the board plus red-dot counts.
# Dependencies: MatchState, RulesSide, RulesUnit, RulesCard, MapData, StreakTracker, LoadoutRules,
#   card_info.gd.
# Author: UI/UX Agent (p09)
extends RefCounted

const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")
const ZONE_LABELS: PackedStringArray = ["LEFT", "MID", "RIGHT"]
const RANGE_LABELS: PackedStringArray = ["CLOSE", "MID", "LONG"]


static func build(state: MatchState, map: MapData, viewer: int = MatchState.PLAYER, killfeed: Array = []) -> Dictionary:
	var me: RulesSide = state.sides[viewer]
	var foe: RulesSide = state.sides[1 - viewer]
	var dots: PackedInt32Array = state.red_dots(viewer)
	var lanes: Array = []
	for z: int in MatchState.ZONE_COUNT:
		var friendly: Array = []
		for u: RulesUnit in me.lines[z]:
			friendly.append(unit_entry(state, u, me))
		friendly.append_array(_queued_arrivals(state, me, z))
		var enemy: Array = []
		for u: RulesUnit in foe.lines[z]:
			enemy.append(unit_entry(state, u, foe))
		lanes.append({
			"id": MapData.ZONE_IDS[z], "label": ZONE_LABELS[z],
			"name": map.zone_names[z] if map != null and z < map.zone_names.size() else ZONE_LABELS[z],
			"range": RANGE_LABELS[state.zone_ranges[z]],
			"control": _control_id(state.control_of(z), viewer),
			"incoming": dots[z] if z < dots.size() else 0,
			"friendly": friendly, "enemy": enemy,
		})
	var hand: Array = []
	for rc: RulesCard in me.hand:
		var c: Dictionary = CardInfo.chip(rc.uid, rc.card)
		c["playable"] = rc.card.cost <= me.supply
		hand.append(c)
	var mode_rules: ModeRules = state.hooks.mode_rules if state.hooks != null else null
	var deploy_open: bool = state.phase == MatchState.Phase.DEPLOY and not me.ready
	var snap: Dictionary = {
		"mode": String(mode_rules.mode_name).replace("_", " ").to_upper() if mode_rules != null else "SANDBOX",
		"goal": "FIRST TO %d" % mode_rules.target if mode_rules != null else "",
		"round": state.round_number,
		"round_cap": mode_rules.round_cap if mode_rules != null else state.config.round_cap,
		"phase": String(MatchState.PHASE_NAMES[state.phase]).to_upper(),
		"score_player": me.score, "score_enemy": foe.score,
		"enemy_name": foe.setup.display_name.to_upper(),
		"supply": me.supply, "supply_max": state.config.supply_for_round(state.round_number),
		"lanes": lanes,
		"operator": _operator_entry(state, me),
		"streak": me.streak,
		"perks": _ids(me.setup.perks), "perk_slots": state.config.perk_slots,
		"abilities": _abilities(state, me),
		"hand": hand,
		"killfeed": killfeed,
		"deploy_open": deploy_open,
		"can_undo": deploy_open and not me.plays.is_empty() and not bool(me.plays.back()["immediate_done"]),
		"undo_label": play_name(state, me, me.plays.back()) if not me.plays.is_empty() else "",
		"result": state.result,
	}
	var ks: Array = []
	var top: int = 0
	for item: LoadoutItem in me.setup.killstreaks:
		var t: int = StreakTracker.threshold_for(state, viewer, item)
		top = maxi(top, t)
		ks.append({"id": item.id, "name": _short(item.display_name), "threshold": t,
				"earned": me.streak_tray.has(item.id)})
	snap["killstreaks"] = ks
	snap["streak_max"] = maxi(top, 5)
	return snap


## {uid, name, cls, fp, armor, armor_max, operator}: FP includes this zone's range bonus.
static func unit_entry(state: MatchState, u: RulesUnit, side: RulesSide) -> Dictionary:
	return {
		"uid": u.uid, "name": unit_name(u, side),
		"cls": "OPERATOR" if u.is_operator else String(CardInfo.CLASS_WORDS.get(u.weapon_class, "")).to_upper(),
		"fp": state.firepower_of(u), "armor": u.armor, "armor_max": u.max_armor(state.round_number),
		"operator": u.is_operator,
	}


static func unit_name(u: RulesUnit, side: RulesSide) -> String:
	if u.card != null:
		return u.card.display_name
	if u.is_operator and side.setup.primary != null:
		return side.setup.primary.display_name
	return String(u.source_id).capitalize()


## Short display name of a queued play (for the UNDO button).
static func play_name(state: MatchState, side: RulesSide, play: Dictionary) -> String:
	match play["kind"]:
		&"place":
			return "Place Operator"
		&"rotate":
			return "Rotate"
		&"item":
			return (play["item"] as LoadoutItem).display_name if play["item"] != null else "Item"
	var rc: RulesCard = play["card"]
	return rc.card.display_name if rc != null else "Play"


## This Deploy's unit arrivals in zone z (unit cards, Operator placement / Rotation), in play order.
static func _queued_arrivals(state: MatchState, side: RulesSide, z: int) -> Array:
	var out: Array = []
	for p: Dictionary in side.plays:
		if int(p["zone"]) != z:
			continue
		var entry: Dictionary = {}
		match p["kind"]:
			&"unit":
				var rc: RulesCard = p["card"]
				entry = {"uid": rc.uid, "name": rc.card.display_name,
						"cls": String(CardInfo.CLASS_WORDS.get(rc.card.weapon_class, "")).to_upper(),
						"fp": rc.card.firepower, "armor": rc.card.armor, "armor_max": rc.card.armor}
			&"place", &"rotate":
				var op: RulesUnit = side.operator_unit
				entry = {"uid": op.uid, "name": unit_name(op, side), "cls": "OPERATOR", "operator": true,
						"fp": op.base_firepower, "armor": op.armor if p["kind"] == &"rotate" else op.base_max_armor,
						"armor_max": op.max_armor(state.round_number)}
		if not entry.is_empty():
			entry["pending"] = true
			out.append(entry)
	return out


static func _operator_entry(state: MatchState, side: RulesSide) -> Dictionary:
	var op: RulesUnit = side.operator_unit
	if op == null:
		return {"name": "NO OPERATOR", "zone": "OFF BOARD"}
	var zone_text: String = "OFF BOARD"
	if op.is_on_board():
		zone_text = ZONE_LABELS[op.zone]
	var planned: int = state.projected_operator_zone(side.index)
	if planned != MatchState.NO_ZONE and planned != op.zone:
		zone_text = "TO " + ZONE_LABELS[planned]
	return {
		"name": unit_name(op, side), "cls": "OPERATOR",
		"fp": state.firepower_of(op) if op.is_on_board() else op.base_firepower,
		"armor": op.armor if op.is_on_board() else op.base_max_armor,
		"armor_max": op.max_armor(state.round_number), "zone": zone_text,
	}


static func _abilities(state: MatchState, side: RulesSide) -> Array:
	var out: Array = []
	for pair: Array in [[&"secondary", side.setup.secondary], [&"lethal", side.setup.lethal], [&"tactical", side.setup.tactical]]:
		var item: LoadoutItem = pair[1]
		if item == null:
			continue
		var cd: int = LoadoutRules.cooldown_left(state, side.index, item)
		var status: String = "CD %d" % cd if cd > 0 else ("%d SUP" % item.supply_cost if item.supply_cost > 0 else "READY")
		out.append({"id": item.id, "name": _short(item.display_name), "state": status})
	return out


static func _control_id(control: int, viewer: int) -> StringName:
	match control:
		MatchState.CONTROL_CONTESTED:
			return &"contested"
		MatchState.CONTROL_EMPTY:
			return &"empty"
	return &"player" if control == viewer else &"enemy"


static func _ids(items: Array[LoadoutItem]) -> Array:
	var out: Array = []
	for it: LoadoutItem in items:
		out.append(it.id)
	return out


## First word, upper case, at most 7 letters ("Recon Drone" -> "RECON").
static func _short(display_name: String) -> String:
	var word: String = display_name.split(" ", false)[0] if not display_name.is_empty() else "?"
	return word.to_upper().left(7)

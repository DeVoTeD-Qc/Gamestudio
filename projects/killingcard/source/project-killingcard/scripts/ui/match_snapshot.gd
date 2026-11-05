# match_snapshot.gd
# Purpose: Builds the match screen's view snapshot (the Dictionary shape documented in
#   mock_match_data.gd) from a live MatchState, as seen by one side. Read-only: it never
#   changes the state. Additions to the p08 shape (all optional for the scenes):
#   - unit entries: uid, pending (true for this Deploy's queued arrivals, tagged PLAN)
#   - hand entries: uid, id, playable (cost <= Supply)
#   - can_undo, undo_label (name of the last play), deploy_open (Deploy and not READY yet),
#     result (&"" while running; &"player" / &"enemy" / &"draw" at the end)
#   f02: abilities / killstreaks entries carry {id, name, state, ready, reason, code, slot,
#     cooldown, uses_left, in_tray, needs_target} from the engine (MatchState.check_use,
#     LoadoutRules, StreakTracker); `ready` false = the button is disabled and `reason` says why.
#   Enemy face-down plays never leak: the enemy only shows units on the board plus red-dot counts.
# Dependencies: MatchState, RulesSide, RulesUnit, RulesCard, MapData, StreakTracker, LoadoutRules,
#   card_info.gd.
# Author: UI/UX Agent (p09)
extends RefCounted

const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")
const PlayText: GDScript = preload("res://scripts/ui/play_text.gd")
## kc-board: the columns are A / B / C (zones Left / Mid / Right).
const ZONE_LABELS: PackedStringArray = ["A", "B", "C"]
const RANGE_LABELS: PackedStringArray = ["CLOSE", "MID", "LONG"]


static func build(state: MatchState, map: MapData, viewer: int = MatchState.PLAYER, killfeed: Array = []) -> Dictionary:
	var me: RulesSide = state.sides[viewer]
	var foe: RulesSide = state.sides[1 - viewer]
	var dots: PackedInt32Array = state.red_dots(viewer)
	var lanes: Array = []
	var fields: Array[Dictionary] = state.field_view(viewer)
	for z: int in MatchState.ZONE_COUNT:
		var friendly: Array = []
		for u: RulesUnit in me.lines[z]:
			friendly.append(unit_entry(state, u, me))
		friendly.append_array(_queued_arrivals(state, me, z))
		var enemy: Array = []
		for u: RulesUnit in foe.lines[z]:
			enemy.append(unit_entry(state, u, foe))
		var fp_me: int = 0
		for u: RulesUnit in me.lines[z]:
			fp_me += state.firepower_of(u)
		var fp_foe: int = 0
		for u: RulesUnit in foe.lines[z]:
			fp_foe += state.firepower_of(u)
		lanes.append({
			"id": MapData.ZONE_IDS[z], "label": ZONE_LABELS[z],
			"name": map.zone_names[z] if map != null and z < map.zone_names.size() else ZONE_LABELS[z],
			"range": RANGE_LABELS[state.zone_ranges[z]],
			"control": _control_id(state.control_of(z), viewer),
			"incoming": dots[z] if z < dots.size() else 0,
			"revealed": revealed_names(state, viewer, z),
			"friendly": friendly, "enemy": enemy,
			"fp_player": fp_me, "fp_enemy": fp_foe,
			"fields": _fields(state, viewer, z, fields),
		})
	var hand: Array = []
	for rc: RulesCard in me.hand:
		var c: Dictionary = CardInfo.chip(rc.uid, rc.card)
		c["playable"] = rc.card.cost <= me.supply
		c["banner"] = String(state.art_by_uid.get(rc.uid, rc.card.id))
		hand.append(c)
	var mode_rules: ModeRules = state.hooks.mode_rules if state.hooks != null else null
	var deploy_open: bool = state.phase == MatchState.Phase.DEPLOY and not me.ready
	var snap: Dictionary = {
		"mode": String(mode_rules.mode_name).replace("_", " ").to_upper() if mode_rules != null else "SANDBOX",
		"goal": String(state.config.get_meta(&"goal_text")) if state.config.has_meta(&"goal_text") \
				else ("FIRST TO %d" % mode_rules.target if mode_rules != null else ""),
		"round": state.round_number,
		"round_cap": mode_rules.round_cap if mode_rules != null else state.config.round_cap,
		"phase": String(MatchState.PHASE_NAMES[state.phase]).to_upper(),
		"score_player": me.score, "score_enemy": foe.score,
		"enemy_name": foe.setup.display_name.to_upper(),
		"supply": me.supply, "supply_max": state.config.supply_for_round(state.round_number),
		"deck_count": me.deck.size(), "discard_count": me.discard.size(), "enemy_hand": foe.hand.size(),
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
		if item == null:
			continue
		var t: int = StreakTracker.threshold_for(state, viewer, item)
		top = maxi(top, t)
		var entry: Dictionary = item_entry(state, viewer, item, {"threshold": t})
		entry["threshold"] = t
		entry["earned"] = me.streak_tray.has(item.id)
		if entry["code"] == &"not_in_tray":
			entry["state"] = "AT %d" % t
		ks.append(entry)
	snap["killstreaks"] = ks
	snap["streak_max"] = maxi(top, 5)
	return snap


## {uid, name, cls, fp, armor, armor_max, operator, keywords, art, banner, bolt, front_kw, elite}:
## FP includes this zone's range bonus. banner = BannerArtDB art id (kc-board).
static func unit_entry(state: MatchState, u: RulesUnit, side: RulesSide) -> Dictionary:
	var e: Dictionary = {
		"uid": u.uid, "name": unit_name(u, side),
		"cls": "OPERATOR" if u.is_operator else String(CardInfo.CLASS_WORDS.get(u.weapon_class, "")).to_upper(),
		"fp": state.firepower_of(u), "armor": u.armor, "armor_max": u.max_armor(state.round_number),
		"operator": u.is_operator, "keywords": CardInfo.icon_keywords(CardInfo.unit_keywords(u)),
		"art": art_key(u, side),
	}
	_banner_fields(e, u.card, u, side, state, u.uid)
	return e


## kc-board banner fields of a unit entry: art id, effect bolt, Protector glyph, Elite frame, camo.
## state + uid (kc-cod2): a copy with its own art (MatchState.art_by_uid) shows that art. The Operator
## wears its primary weapon's mastery card at its tier (Base = tier 1 until the mastery grind exists).
static func _banner_fields(e: Dictionary, card: CardData, u: RulesUnit, side: RulesSide,
		state: MatchState = null, uid: int = -1) -> void:
	var id: StringName = &""
	var op_tier: int = 1
	if card != null:
		id = card.id
	elif u != null and u.is_operator and side.setup.primary != null:
		id = BannerArtDB.operator_art_id(side.setup.primary.id, op_tier)
	elif u != null:
		id = u.source_id
	if state != null and uid >= 0 and state.art_by_uid.has(uid):
		id = state.art_by_uid[uid]
	e["banner"] = String(id)
	e["bolt"] = card != null and not card.effects.is_empty()
	e["front_kw"] = card != null and card.arrives_front
	e["elite"] = card != null and card.is_elite
	if e.get("operator", false):
		# head (kc-polish B3): Base for both sides until the mastery grind exists; the camo band follows
		# the mastery tier (BannerArtDB.operator_tier_override is the pitch's dev preview).
		var tier: int = BannerArtDB.operator_tier_override if BannerArtDB.operator_tier_override > 0 else op_tier
		e["camo"] = String(BannerArtDB.camo_for_tier(tier))
		e["mastery_tier"] = tier


static func art_key_of_card(card: CardData) -> String:
	return String(card.id) if card != null and CardArt.has_card(card.id) else ""


## k-art4: card art key of a unit: its card, the Operator's primary weapon, else its source id
## (a killstreak's Sentry Turret); "" when CardArt has no art for it (the slot keeps its silhouette).
static func art_key(u: RulesUnit, side: RulesSide) -> String:
	var key: StringName = &""
	if u.card != null:
		key = u.card.id
	elif u.is_operator and side.setup.primary != null:
		key = side.setup.primary.id
	else:
		key = u.source_id
	return String(key) if key != &"" and CardArt.has_card(key) else ""


static func unit_name(u: RulesUnit, side: RulesSide) -> String:
	if u.card != null:
		return u.card.display_name
	if u.is_operator and side.setup.primary != null:
		return side.setup.primary.display_name
	return String(u.source_id).capitalize()


## f03: names of the enemy cards behind this zone's red dots when `viewer` revealed them
## (Callout / Recon Specialist for the zone, Recon Drone for all): MatchState.revealed_red_dots
## worded for the board. In play order, one per dot; empty while unrevealed.
static func revealed_names(state: MatchState, viewer: int, zone: int) -> Array:
	var out: Array = []
	var foe: RulesSide = state.sides[1 - viewer]
	for id: StringName in state.revealed_red_dots(viewer, zone):
		if foe.operator_unit != null and id == foe.operator_unit.source_id:
			out.append(unit_name(foe.operator_unit, foe))
			continue
		var card: CardData = CardDB.get_card(id) if CardDB != null else null
		out.append(card.display_name if card != null else String(id).capitalize())
	return out


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
						"fp": rc.card.firepower, "armor": rc.card.armor, "armor_max": rc.card.armor,
						"keywords": CardInfo.icon_keywords(CardInfo.keywords(rc.card)), "art": art_key_of_card(rc.card)}
				_banner_fields(entry, rc.card, null, side, state, rc.uid)
			&"place", &"rotate":
				var op: RulesUnit = side.operator_unit
				entry = {"uid": op.uid, "name": unit_name(op, side), "cls": "OPERATOR", "operator": true,
						"fp": op.base_firepower, "armor": op.armor if p["kind"] == &"rotate" else op.base_max_armor,
						"armor_max": op.max_armor(state.round_number),
						"keywords": CardInfo.icon_keywords(CardInfo.operator_keywords(op)), "art": art_key(op, side)}
				_banner_fields(entry, null, op, side)
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
		zone_text = "%s, ROW %d" % [ZONE_LABELS[op.zone], side.lines[op.zone].find(op) + 1]
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
	for item: LoadoutItem in [side.setup.secondary, side.setup.lethal, side.setup.tactical]:
		if item != null:
			out.append(item_entry(state, side.index, item))
	return out


## Button entry for one activated loadout item, straight from the engine's checks.
static func item_entry(state: MatchState, viewer: int, item: LoadoutItem, ctx: Dictionary = {}) -> Dictionary:
	var check: Dictionary = state.check_use(viewer, item.id)
	var uses_left: int = LoadoutRules.uses_left_this_round(state, viewer, item)
	var match_left: int = LoadoutRules.uses_left_this_match(state, viewer, item)
	if match_left >= 0:
		uses_left = match_left if uses_left < 0 else mini(uses_left, match_left)
	var text_ctx: Dictionary = ctx.duplicate()
	text_ctx["name"] = item.display_name
	text_ctx["kind"] = &"item"
	return {
		"id": item.id, "name": _short(item.display_name), "full_name": item.display_name,
		"slot": item.slot, "ready": bool(check["ok"]), "code": check["code"],
		"state": PlayText.button_state(check, item, uses_left),
		"reason": "" if check["ok"] else String(PlayText.describe(check, text_ctx)["reason"]),
		"cooldown": LoadoutRules.cooldown_left(state, viewer, item), "uses_left": uses_left,
		"in_tray": state.sides[viewer].streak_tray.has(item.id),
		"needs_target": state.needs_unit_target(viewer, item.id),
	}


## kc-board: Fields on the objective tile, per side: MatchState.field_view rows (the viewer's own
## hidden traps included, the other side's never) plus the viewer's Fields queued this Deploy (PLAN).
static func _fields(state: MatchState, viewer: int, z: int, view: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {"player": [], "enemy": []}
	if z < view.size():
		var row: Dictionary = view[z]
		var me_name: StringName = MatchState.SIDE_NAMES[viewer]
		var foe_name: StringName = MatchState.SIDE_NAMES[1 - viewer]
		out["player"] = (row.get(me_name, []) as Array).duplicate()
		out["enemy"] = (row.get(foe_name, []) as Array).duplicate()
	for p: Dictionary in state.sides[viewer].plays:
		if p["kind"] == &"equipment" and int(p["zone"]) == z:
			var rc: RulesCard = p["card"]
			(out["player"] as Array).push_front({"card_uid": rc.uid, "card_id": rc.card.id, "name": rc.card.display_name,
					"text": rc.card.text, "hidden": rc.card.hidden, "pending": true, "overrun_risk": false})
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


## First word, upper case, for the 64 px loadout buttons ("Recon Drone" -> "RECON");
## words over 7 letters keep their first 5 ("Flashbang" -> "FLASH").
static func _short(display_name: String) -> String:
	var word: String = display_name.split(" ", false)[0] if not display_name.is_empty() else "?"
	return word.to_upper() if word.length() <= 7 else word.to_upper().left(5)

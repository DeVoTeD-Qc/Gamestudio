# stat_breakdown.gd
# Purpose: "Where does this number come from" for the board and the inspector (kc-syn-ui, head's
#   note A: show the RESULTING stats, buffed values in their own colour, the base on inspect).
#   Splits a unit's Firepower and Cover into printed base + copy level + loadout + range of its
#   column + effects + auras (Fields, perks, Commander) + neighbour links + trait sets, so that
#   the parts add up to MatchState.firepower_of / cover_of. Also builds the same numbers for a
#   card that is not on the board yet (the landing ghost of a selected hand card, per column),
#   from MatchState.preview_synergy and a throw-away RulesUnit (nothing in the state changes).
#   Read-only: never changes the match.
# Dependencies: MatchState, RulesUnit, RulesCard, SynergyRules, DataEnums, synergy_glyphs.gd.
# Author: UI/UX Agent (kc-syn-ui)
extends RefCounted

const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
const RANGE_WORDS: PackedStringArray = ["close", "mid", "long"]
const LINK_WHERE: Dictionary = {&"spotter": "behind", &"guard": "in front", &"fireteam": "beside", &"overwatch": "beside"}


## {fp: {total, base, parts: [[label, n]]}, cover: {...}, fs: bool, heal: int} of a unit on the board.
static func of_unit(state: MatchState, u: RulesUnit) -> Dictionary:
	return _build(state, u, state.synergy_of(u), u.zone)


## The same for a hand card arriving in `zone` this Deploy (after the queued plays), or {} if it is
## not a unit. Adds preview: MatchState.preview_synergy() result.
static func of_ghost(state: MatchState, side: int, card_uid: int, zone: int) -> Dictionary:
	var rc: RulesCard = state.sides[side].find_in_hand(card_uid)
	if rc == null or not rc.card.is_unit() or not state.is_zone(zone):
		return {}
	var pv: Dictionary = state.preview_synergy(side, card_uid, zone)
	var tmp: RulesUnit = state.create_unit(side, rc.card, rc.uid, rc.level)
	tmp.zone = zone  # read-only probe: never put in a line
	var out: Dictionary = _build(state, tmp, pv.get("card", {}) if bool(pv.get("ok", false)) else {}, zone)
	out["preview"] = pv
	return out


## The Operator as it would arrive in `zone` (placement ghost).
static func of_operator_ghost(state: MatchState, side: int, zone: int) -> Dictionary:
	var op: RulesUnit = state.sides[side].operator_unit
	if op == null:
		return {}
	var was: int = op.zone
	if op.is_on_board():
		return of_unit(state, op)
	op.zone = zone
	var out: Dictionary = _build(state, op, {}, zone)
	op.zone = was
	return out


static func _build(state: MatchState, u: RulesUnit, syn: Dictionary, zone: int) -> Dictionary:
	var fp_parts: Array = []
	var base: int = u.card.firepower if u.card != null else u.base_firepower
	var lv: Dictionary = SynergyRules.level_stats(u.level) if u.card != null else {"fp": 0, "armor": 0}
	if int(lv["fp"]) != 0:
		fp_parts.append([SynergyGlyphs.level_name(u.level), int(lv["fp"])])
	if u.card != null:
		var loadout: int = u.base_firepower - base - int(lv["fp"])
		if loadout != 0:
			fp_parts.append(["loadout", loadout])
	if zone >= 0:
		var rb: int = state.config.range_bonus(u.weapon_class, state.zone_ranges[zone])
		if rb != 0:
			fp_parts.append(["%s range" % RANGE_WORDS[clampi(state.zone_ranges[zone], 0, 2)], rb])
	var mods: int = u.mod_total(DataEnums.EffectKind.MODIFY_FIREPOWER, state.round_number)
	if mods != 0:
		fp_parts.append(["effects", mods])
	if zone >= 0:
		var aura: int = state.passive_total(u, DataEnums.EffectKind.MODIFY_FIREPOWER)
		if aura != 0:
			fp_parts.append(["auras", aura])
	var cov_parts: Array = []
	var cov_base: int = u.cover
	var gcov: int = u.mod_total(DataEnums.EffectKind.GRANT_COVER, state.round_number)
	if gcov != 0:
		cov_parts.append(["effects", gcov])
	if zone >= 0:
		var pcov: int = state.passive_total(u, DataEnums.EffectKind.GRANT_COVER)
		if pcov != 0:
			cov_parts.append(["auras", pcov])
	for l: Dictionary in syn.get("links", []):
		var kind: StringName = StringName(l.get("kind", &""))
		var label: String = "%s (%s, %s)" % [SynergyGlyphs.keyword_name(kind), name_of(state, int(l.get("from_uid", -1))), LINK_WHERE.get(kind, "")]
		match kind:
			SynergyRules.SPOTTER:
				fp_parts.append([label, SynergyRules.SPOTTER_FP])
			SynergyRules.FIRETEAM:
				fp_parts.append(["Fireteam (beside %s)" % name_of(state, int(l.get("from_uid", -1))), SynergyRules.FIRETEAM_FP])
			SynergyRules.GUARD:
				cov_parts.append([label, SynergyRules.GUARD_COVER])
			SynergyRules.OVERWATCH:
				cov_parts.append([label, SynergyRules.OVERWATCH_COVER])
	for st: Array in syn.get("sets", []):
		var t: StringName = StringName(st[0])
		var tier: int = int(st[1])
		var table: Array = SynergyRules.trait_bonus.get(t, [])
		if table.size() < 2:
			continue
		var b: Dictionary = table[0 if tier <= 2 else 1]
		var label2: String = "%s %d" % [SynergyGlyphs.trait_name(t), tier]
		if int(b.get("fp", 0)) != 0:
			fp_parts.append([label2, int(b["fp"])])
		if int(b.get("cover", 0)) != 0:
			cov_parts.append([label2, int(b["cover"])])
	# Totals come from the engine (so they always match the fight); a card not in a line yet adds
	# its previewed link / set bonus on top (the engine can't see it before it lands).
	var in_line: bool = u.is_on_board() and state.sides[u.side].lines[u.zone].has(u)
	var fp_total: int = state.firepower_of(u) if u.zone >= 0 else _sum(base, fp_parts)
	var cov_total: int = state.cover_of(u) if u.zone >= 0 else _sum(cov_base, cov_parts)
	if u.zone >= 0 and not in_line:
		fp_total = maxi(0, fp_total + int(syn.get("fp", 0)))
		var stripped: bool = u.has_mod(DataEnums.EffectKind.REMOVE_COVER, state.round_number) \
				or state.sides[1 - u.side].has_flag(DataEnums.EffectKind.REMOVE_COVER, state.round_number)
		if not stripped:
			cov_total = maxi(0, cov_total + int(syn.get("cover", 0)))
	var removed: bool = cov_total == 0 and _sum(cov_base, cov_parts) > 0
	return {"fp": {"total": fp_total, "base": base, "parts": fp_parts},
			"cover": {"total": cov_total, "base": cov_base, "parts": cov_parts, "removed": removed},
			"fs": bool(syn.get("fs", false)), "heal": int(syn.get("heal", 0)), "syn": syn}


static func _sum(base: int, parts: Array) -> int:
	var n: int = base
	for p: Array in parts:
		n += int(p[1])
	return maxi(0, n)


## "FP 4 = 2 base +1 close range +1 Spotter (Marksman, behind)" (just "FP 2" when unmodified).
static func line(stat: String, d: Dictionary) -> String:
	var parts: Array = d.get("parts", [])
	if parts.is_empty() and not bool(d.get("removed", false)):
		return "%s %d" % [stat, int(d.get("total", 0))]
	var bits: PackedStringArray = ["%d base" % int(d.get("base", 0))]
	for p: Array in parts:
		bits.append("%s%d %s" % ["+" if int(p[1]) >= 0 else "-", absi(int(p[1])), String(p[0])])
	var out: String = "%s %d = %s" % [stat, int(d.get("total", 0)), " ".join(bits)]
	if bool(d.get("removed", false)):
		out += " (removed: Recon Drone / effect)"
	return out


## Delta of the shown value against the printed base: 1 = buffed, -1 = lowered, 0 = plain.
static func trend(d: Dictionary) -> int:
	var diff: int = int(d.get("total", 0)) - int(d.get("base", 0))
	return 1 if diff > 0 else (-1 if diff < 0 else 0)


## Name of any uid in the match (board, hand, queued plays, piles), "a friendly card" if unknown.
static func name_of(state: MatchState, uid: int) -> String:
	for s: RulesSide in state.sides:
		var u: RulesUnit = s.find_unit(uid)
		if u != null:
			if u.card != null:
				return u.card.display_name
			if u.is_operator:
				return "your Operator" if s.index == MatchState.PLAYER else "the rival Operator"
			return String(u.source_id).capitalize()
		if s.operator_unit != null and s.operator_unit.uid == uid:
			return "Operator"
		for p: Dictionary in s.plays:
			if p["card"] != null and (p["card"] as RulesCard).uid == uid:
				return (p["card"] as RulesCard).card.display_name
		for pile: Array in [s.hand, s.discard]:
			for rc: RulesCard in pile:
				if rc.uid == uid:
					return rc.card.display_name
	return "a friendly card"

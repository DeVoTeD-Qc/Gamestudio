# loadout_rules.gd
# Purpose: Rules for the activated loadout (killstreaks) and the Perks (core-rules §3,
#   Ruling 4, Rulings part 2 #13). Stateless and static; state lives in RulesSide
#   (uses_this_round / _match, streak_tray, item_undo, survive_lethal_armed).
#   MatchHooks delegates to it.
#   kc-loadout-cut: the Secondary / Lethal / Tactical items and their cooldowns are gone.
#   - uses_per_round / uses_per_match (0 = unlimited) on items and perks.
#   - Killstreaks: usable only from the Streak Tray; using one takes it out of the tray.
#   - Undo of a queued item gives back its use counts and tray entry.
#   - Perks: Streak Discipline (StreakTracker.threshold_for), Field Salvage (perk
#     ON_ELIMINATE, uses_per_round), Grit (PASSIVE SURVIVE_LETHAL on the Operator,
#     uses_per_match), Objective Focus (END_OF_ROUND, already resolved by MatchState).
#   - Recon Drone's side-wide REMOVE_COVER also covers enemy units that arrive later
#     in its duration (side flag read by MatchState.cover_of).
# Dependencies: DataEnums, EffectData, LoadoutItem, RulesSide, RulesUnit, RulesEvent,
#   EffectResolver, StreakTracker (MatchState passed in).
# Author: Mechanics Developer Agent
class_name LoadoutRules
extends RefCounted

const K := DataEnums.EffectKind
const S := DataEnums.LoadoutSlot

## Field Salvage (content-log choice): it triggers only on eliminations that count for
## the streak, so killstreak kills don't draw. One definition of "you eliminate".
const PERK_ON_ELIMINATE_NEEDS_STREAK_KILL: bool = true


# =============================================================================
# Briefing
# =============================================================================

## Briefing: reset per-round uses, (re)arm survive-lethal perks.
static func on_briefing(state, side: int) -> void:
	var s: RulesSide = state.sides[side]
	s.uses_this_round.clear()
	s.item_undo.clear()
	_update_survive_lethal(state, side)


# =============================================================================
# Activated items
# =============================================================================

## "" if the side may use the item now, else the reason (Supply is checked by MatchState).
static func can_use_item(state, side: int, item: LoadoutItem) -> String:
	return String(check_item(state, side, item).get("reason", ""))


## {} if the side may use the item now, else {code, reason, data} with a stable code:
## not_in_tray (killstreak not earned yet), no_uses_left {per: round|match}.
static func check_item(state, side: int, item: LoadoutItem) -> Dictionary:
	var s: RulesSide = state.sides[side]
	if item.slot == S.KILLSTREAK and item.id not in s.streak_tray:
		return {"code": &"not_in_tray", "reason": "killstreak not earned", "data": {}}
	if item.uses_per_round > 0 and int(s.uses_this_round.get(item.id, 0)) >= item.uses_per_round:
		return {"code": &"no_uses_left", "reason": "already used this round", "data": {"per": &"round"}}
	if item.uses_per_match > 0 and int(s.uses_this_match.get(item.id, 0)) >= item.uses_per_match:
		return {"code": &"no_uses_left", "reason": "already used this match", "data": {"per": &"match"}}
	return {}


## Uses left this round of an item (-1 = unlimited), for the UI.
static func uses_left_this_round(state, side: int, item: LoadoutItem) -> int:
	if item.uses_per_round <= 0:
		return -1
	return maxi(0, item.uses_per_round - int(state.sides[side].uses_this_round.get(item.id, 0)))


## The item was accepted in Deploy: count the use, take it from the tray.
static func on_item_used(state, side: int, item: LoadoutItem) -> void:
	var s: RulesSide = state.sides[side]
	var undo: Dictionary = {"id": item.id, "from_tray": -1}
	_count_use(s, item.id, 1)
	if item.slot == S.KILLSTREAK:
		var at: int = s.streak_tray.find(item.id)
		if at >= 0:
			s.streak_tray.remove_at(at)
			undo["from_tray"] = at
		_register_side_wide_cover_removal(state, side, item)
	s.item_undo.append(undo)


## A queued item was taken back: restore use counts and the tray entry.
static func on_item_undone(state, side: int, item: LoadoutItem) -> void:
	var s: RulesSide = state.sides[side]
	for i: int in range(s.item_undo.size() - 1, -1, -1):
		var undo: Dictionary = s.item_undo[i]
		if undo["id"] != item.id:
			continue
		s.item_undo.remove_at(i)
		_count_use(s, item.id, -1)
		var at: int = int(undo["from_tray"])
		if at >= 0 and item.id not in s.streak_tray:
			s.streak_tray.insert(mini(at, s.streak_tray.size()), item.id)
		return


static func _count_use(s: RulesSide, id: StringName, delta: int) -> void:
	s.uses_this_round[id] = maxi(0, int(s.uses_this_round.get(id, 0)) + delta)
	s.uses_this_match[id] = maxi(0, int(s.uses_this_match.get(id, 0)) + delta)


## Recon Drone: "enemy units lose Cover" for its duration, including enemy units that
## arrive or gain Cover later. Stored as a side flag (MatchState.cover_of reads it).
static func _register_side_wide_cover_removal(state, side: int, item: LoadoutItem) -> void:
	for e: EffectData in item.effects:
		if e != null and e.kind == K.REMOVE_COVER and e.target == DataEnums.Target.ALL_ENEMIES \
				and e.zone_scope == DataEnums.ZoneScope.ALL_ZONES:
			var s: RulesSide = state.sides[side]
			var until: int = EffectResolver.until_round(state, e)
			if not s.flags.has(K.REMOVE_COVER) or int(s.flags[K.REMOVE_COVER]) < until:
				s.flags[K.REMOVE_COVER] = until


# =============================================================================
# Perks
# =============================================================================

## Every elimination: the eliminating side's ON_ELIMINATE perks (Field Salvage).
static func on_elimination(state, rec: Dictionary) -> void:
	if not rec.get("credit", false):
		return  # Rulings part 2 #13: On Eliminate fires only on credited eliminations
	if PERK_ON_ELIMINATE_NEEDS_STREAK_KILL and not StreakTracker.counts_for_streak(state, rec):
		return
	var side: int = 0 if rec["by_side"] == &"player" else 1
	var s: RulesSide = state.sides[side]
	for perk: LoadoutItem in s.setup.perks:
		if perk == null or not _has_trigger(perk, DataEnums.Trigger.ON_ELIMINATE):
			continue
		if perk.uses_per_round > 0 and int(s.uses_this_round.get(perk.id, 0)) >= perk.uses_per_round:
			continue
		if perk.uses_per_match > 0 and int(s.uses_this_match.get(perk.id, 0)) >= perk.uses_per_match:
			continue
		_count_use(s, perk.id, 1)
		state.emit_event(RulesEvent.PERK_TRIGGERED, {"side": rec["by_side"], "item_id": perk.id})
		var ctx: Dictionary = state.make_ctx(side, state.SRC_PERK, perk.id, -1, -1, -1, -1)
		EffectResolver.resolve_triggered(state, perk.effects, DataEnums.Trigger.ON_ELIMINATE, ctx)


## Grit: arms PASSIVE SURVIVE_LETHAL perks on the Operator at each Briefing while uses
## remain. A use is counted at the next Briefing once the armed value is gone
## (MatchState.deal_damage spends it), so it never re-arms within the same round.
static func _update_survive_lethal(state, side: int) -> void:
	var s: RulesSide = state.sides[side]
	var op: RulesUnit = s.operator_unit
	if op == null:
		return
	if s.survive_lethal_armed != &"" and op.survive_lethal <= 0:
		_count_use(s, s.survive_lethal_armed, 1)
		s.uses_this_round.erase(s.survive_lethal_armed)
		s.survive_lethal_armed = &""
	if s.survive_lethal_armed != &"":
		return
	for perk: LoadoutItem in s.setup.perks:
		if perk == null:
			continue
		if perk.uses_per_match > 0 and int(s.uses_this_match.get(perk.id, 0)) >= perk.uses_per_match:
			continue
		for e: EffectData in perk.effects:
			if e != null and e.trigger == DataEnums.Trigger.PASSIVE and e.kind == K.SURVIVE_LETHAL \
					and e.target == DataEnums.Target.OPERATOR:
				op.survive_lethal = maxi(op.survive_lethal, e.amount)
				s.survive_lethal_armed = perk.id
				return


static func _has_trigger(item: LoadoutItem, trigger: int) -> bool:
	for e: EffectData in item.effects:
		if e != null and e.trigger == trigger:
			return true
	return false


## Remaining uses this match of a perk / item (-1 = unlimited), for the UI.
static func uses_left_this_match(state, side: int, item: LoadoutItem) -> int:
	if item.uses_per_match <= 0:
		return -1
	return maxi(0, item.uses_per_match - int(state.sides[side].uses_this_match.get(item.id, 0)))

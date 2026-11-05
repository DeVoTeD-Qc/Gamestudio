# firefight_resolver.gd
# Purpose: The Firefight phase (core-rules §2.4, Rulings 5/6/8), stateless and
#   deterministic (no randomness at all):
#   0. START_OF_FIREFIGHT effects registered earlier (Attack Helo) hit first, in
#      every zone their scope covers, then the dead are removed.
#   For every zone with units from both sides (left -> mid -> right):
#   1. Suppress: each Suppress unit gives the enemy point man -2 FP this round.
#   2. First Shot step, then Main step. In a step all shooters fire at the same time:
#      each side assigns its shots in line order; a shot hits the enemy point man
#      unless the damage already assigned this step kills it, then the next unit in
#      line (Pick: lowest remaining Armor, ties front-most; Flank: back-most). Damage
#      over what a unit needs is wasted. Damage lands at the end of the step, then
#      eliminations and their On Down triggers resolve.
#   3. Patch N: the most damaged other friendly unit in the zone heals N.
# Dependencies: DataEnums, RulesUnit, RulesSide, RulesEvent, EffectResolver (MatchState passed in).
# Author: Mechanics Developer Agent
class_name FirefightResolver
extends RefCounted

## Firepower the enemy point man loses per Suppress unit (core-rules §1).
const SUPPRESS_AMOUNT: int = 2
const STEP_FIRST_SHOT: StringName = &"first_shot"
const STEP_MAIN: StringName = &"main"


static func resolve(state) -> void:
	for f: Dictionary in state.firefight_effects.duplicate():
		if int(f["until_round"]) >= state.round_number:
			EffectResolver.resolve_effect(state, f["effect"], f["ctx"])
	state.process_eliminations()
	for z: int in state.ZONE_COUNT:
		if has_firefight(state, z):
			resolve_zone(state, z)
	for s: RulesSide in state.sides:
		for u: RulesUnit in s.units_on_board():
			u.fired = false


## True when both sides have units in zone z.
static func has_firefight(state, z: int) -> bool:
	return not state.sides[0].line(z).is_empty() and not state.sides[1].line(z).is_empty()


static func resolve_zone(state, z: int) -> void:
	state.emit_event(RulesEvent.FIREFIGHT_STARTED, {"zone": state.zone_name(z)})
	_suppress(state, z)
	_step(state, z, true)
	_step(state, z, false)
	_patch(state, z)


static func _suppress(state, z: int) -> void:
	for si: int in state.side_order():
		for u: RulesUnit in state.sides[si].line(z):
			if not u.suppress:
				continue
			var foe_line: Array = state.sides[1 - si].line(z)
			if foe_line.is_empty():
				continue
			var target: RulesUnit = foe_line[0]
			target.add_mod(DataEnums.EffectKind.MODIFY_FIREPOWER, -SUPPRESS_AMOUNT, state.round_number)
			state.emit_event(RulesEvent.SUPPRESSED, {"side": state.side_name(si), "uid": u.uid,
					"target_uid": target.uid, "amount": SUPPRESS_AMOUNT, "zone": state.zone_name(z)})


static func _step(state, z: int, first_shot_step: bool) -> void:
	var shooters: Array = [[], []]
	var any: bool = false
	for si: int in 2:
		for u: RulesUnit in state.sides[si].line(z):
			if u.is_alive() and not u.fired and (not first_shot_step or state.has_first_shot(u)):
				shooters[si].append(u)
				any = true
	if not any:
		return
	var step: StringName = STEP_FIRST_SHOT if first_shot_step else STEP_MAIN
	state.emit_event(RulesEvent.FIREFIGHT_STEP, {"zone": state.zone_name(z), "step": step})
	# hits[target_uid] = {target, total, killer}; target order = first hit order.
	var hits: Dictionary = {}
	var hit_order: Array[RulesUnit] = []
	for si: int in state.side_order():
		var foe_line: Array = state.sides[1 - si].line(z)
		var assigned: Dictionary = {}
		for u: RulesUnit in shooters[si]:
			u.fired = true
			var fp: int = state.firepower_of(u)
			var target: RulesUnit = pick_target(state, u, foe_line, assigned)
			if target == null:
				state.emit_event(RulesEvent.SHOT_FIRED, {"side": state.side_name(si), "shooter_uid": u.uid,
						"target_uid": -1, "zone": state.zone_name(z), "damage": 0, "step": step})
				continue
			var dmg: int = maxi(0, fp - state.cover_of(target))
			var before: int = int(assigned.get(target.uid, 0))
			assigned[target.uid] = before + dmg
			if not hits.has(target.uid):
				hits[target.uid] = {"target": target, "total": 0, "killer": {}, "first": _source(state, si, u)}
				hit_order.append(target)
			var h: Dictionary = hits[target.uid]
			h["total"] = int(h["total"]) + dmg
			if (h["killer"] as Dictionary).is_empty() and before < target.armor and before + dmg >= target.armor:
				h["killer"] = _source(state, si, u)
			state.emit_event(RulesEvent.SHOT_FIRED, {"side": state.side_name(si), "shooter_uid": u.uid,
					"target_uid": target.uid, "zone": state.zone_name(z), "damage": dmg, "step": step})
	# Damage lands at the end of the step.
	for t: RulesUnit in hit_order:
		var h: Dictionary = hits[t.uid]
		var src: Dictionary = h["killer"]
		if src.is_empty():
			src = h["first"]  # not lethal: credit the first shooter for the damage log
		state.deal_damage(t, int(h["total"]), src, false)
	state.process_eliminations()


static func _source(state, si: int, u: RulesUnit) -> Dictionary:
	return {"side": si, "uid": u.uid, "source_id": u.source_id,
			"source_kind": state.SRC_OPERATOR if u.is_operator else state.SRC_UNIT}


## Target of one shot, given damage already assigned this step (uid -> damage).
## Null when every enemy is already doomed or there is none (the shot is wasted).
static func pick_target(state, shooter: RulesUnit, foe_line: Array, assigned: Dictionary) -> RulesUnit:
	var candidates: Array[RulesUnit] = []
	for u: RulesUnit in foe_line:
		if u.is_alive() and int(assigned.get(u.uid, 0)) < u.armor:
			candidates.append(u)
	if candidates.is_empty():
		return null
	if shooter.pick or shooter.flank:
		var eligible: Array[RulesUnit] = []
		for u: RulesUnit in candidates:
			if not state.is_untargetable_by_pick_flank(u):
				eligible.append(u)
		if not eligible.is_empty():
			if shooter.pick:
				var best: RulesUnit = eligible[0]
				for u: RulesUnit in eligible:
					if u.armor - int(assigned.get(u.uid, 0)) < best.armor - int(assigned.get(best.uid, 0)):
						best = u
				return best
			return eligible.back()
	return candidates[0]


static func _patch(state, z: int) -> void:
	for si: int in state.side_order():
		var line: Array = state.sides[si].line(z)
		for medic: RulesUnit in line:
			if medic.patch <= 0 or not medic.is_alive():
				continue
			var best: RulesUnit = null
			for u: RulesUnit in line:
				if u == medic or not u.is_alive():
					continue
				var missing: int = u.damage_taken(state.round_number)
				if missing > 0 and (best == null or missing > best.damage_taken(state.round_number)):
					best = u
			if best == null:
				continue
			var healed: int = mini(medic.patch, best.damage_taken(state.round_number))
			best.armor += healed
			state.emit_event(RulesEvent.PATCHED, {"side": state.side_name(si), "uid": medic.uid,
					"target_uid": best.uid, "amount": healed, "zone": state.zone_name(z)})

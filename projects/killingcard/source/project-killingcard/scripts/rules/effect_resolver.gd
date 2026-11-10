# effect_resolver.gd
# Purpose: Applies EffectData to a MatchState (stateless, static). One function per
#   concern: which zones (zone_scope), which units (target + target_class), whether it
#   happens (condition), how much (amount + bonus), then the kind itself.
#   Damage never removes units here: units at 0 Armor stay in line until the caller
#   runs MatchState.process_eliminations(), so all effects of one play see the same
#   line (e.g. 2 to the point man and 1 to the unit behind it).
#
#   Kinds implemented in p04: DAMAGE, MODIFY_FIREPOWER, MODIFY_ARMOR, GRANT_COVER,
#   REMOVE_COVER, GRANT_FIRST_SHOT, REMOVE_FIRST_SHOT, UNTARGETABLE_BY_PICK_FLANK, DRAW,
#   REVEAL_RED_DOTS, REVEAL_DEPLOYMENTS / HIDE_FROM_INTEL (side flags), MOVE_UNIT,
#   STREAK_BONUS (counted by MatchHooks.apply_streak), DESTROY_EQUIPMENT, SUMMON_UNIT,
#   SURVIVE_LETHAL, HEAL (kc-field-impl: Aid Station). STREAK_THRESHOLD_MOD only logs an event: p05
#   reads it from the perks when it builds the Streak Tray. COOLDOWN_MOD is retired (kc-loadout-cut).
# Dependencies: DataEnums, EffectData, RulesUnit, RulesSide, RulesEvent (MatchState passed in).
# Author: Mechanics Developer Agent
class_name EffectResolver
extends RefCounted

const K := DataEnums.EffectKind
const T := DataEnums.Target
const Z := DataEnums.ZoneScope
const C := DataEnums.Condition

const _UNIT_MODS: Array[int] = [
	K.MODIFY_FIREPOWER, K.GRANT_COVER, K.REMOVE_COVER, K.GRANT_FIRST_SHOT,
	K.REMOVE_FIRST_SHOT, K.UNTARGETABLE_BY_PICK_FLANK,
]


## Resolves the ON_PLAY effects of a revealed play in list order and registers its
## START_OF_FIREFIGHT effects; then removes whatever died.
static func resolve_play(state, effects: Array[EffectData], ctx: Dictionary) -> void:
	for e: EffectData in effects:
		if e == null:
			continue
		if e.trigger == DataEnums.Trigger.ON_PLAY:
			if e.target == T.NEXT_FRIENDLY_ARRIVING:
				continue  # registered before units arrived (Ruling 7)
			resolve_effect(state, e, ctx)
		elif e.trigger == DataEnums.Trigger.START_OF_FIREFIGHT:
			state.firefight_effects.append({
				"effect": e, "ctx": ctx, "until_round": state.round_number + maxi(1, e.duration_rounds) - 1,
				"from_round": state.round_number,
			})
	state.process_eliminations()


## Resolves the effects with `trigger` in list order (no elimination pass).
static func resolve_triggered(state, effects: Array[EffectData], trigger: int, ctx: Dictionary) -> void:
	for e: EffectData in effects:
		if e != null and e.trigger == trigger:
			resolve_effect(state, e, ctx)


## Resolves one effect. `arrival_now` applies a NEXT_FRIENDLY_ARRIVING effect to
## ctx.override_target instead of registering it.
static func resolve_effect(state, e: EffectData, ctx: Dictionary, arrival_now: bool = false) -> void:
	var side: int = ctx["side"]
	if e.target == T.NEXT_FRIENDLY_ARRIVING and not arrival_now:
		for z: int in scope_zones(state, e, ctx):
			if z >= 0:
				state.sides[side].arrival_buffs.append({"zone": z, "effect": e, "ctx": ctx, "source_id": ctx["source_id"]})
		return
	if e.delay_rounds > 0 and e.kind != K.REVEAL_RED_DOTS and not ctx.get("delayed", false):
		var later: Dictionary = ctx.duplicate()
		later["delayed"] = true
		state.delayed_effects.append({"due_round": state.round_number + e.delay_rounds, "effect": e, "ctx": later})
		return
	var zones: Array[int] = scope_zones(state, e, ctx)
	if zones.is_empty():
		_wasted(state, e, ctx, "no legal zone")
		return
	for z: int in zones:
		if not condition_holds(state, e.condition, side, z):
			continue
		_apply(state, e, ctx, z, amount_for(state, e, side, z))


## Zones the effect looks at; [NO_ZONE] when it is not zone-bound.
static func scope_zones(state, e: EffectData, ctx: Dictionary) -> Array[int]:
	var side: int = ctx["side"]
	var chosen: int = ctx["zone"]
	var op: RulesUnit = state.sides[side].operator_unit
	var op_zone: int = op.zone if op != null else -1
	var out: Array[int] = []
	match e.zone_scope:
		Z.THIS_ZONE:
			var u: RulesUnit = ctx.get("source_unit")
			if u != null and u.is_on_board():
				out.append(u.zone)
			elif state.is_zone(chosen):
				out.append(chosen)
		Z.CHOSEN_ZONE:
			if state.is_zone(chosen):
				out.append(chosen)
		Z.OPERATOR_ZONE:
			if state.is_zone(op_zone):
				out.append(op_zone)
		Z.OPERATOR_OR_ADJACENT:
			if state.is_zone(op_zone) and state.is_zone(chosen) and absi(chosen - op_zone) <= 1:
				out.append(chosen)
		Z.ALL_ZONES:
			out.assign([0, 1, 2])
		_:
			out.append(-1)  # ANY, ADJACENT_ZONE (destination comes from ctx.dest_zone)
	return out


static func condition_holds(state, c: int, side: int, z: int) -> bool:
	match c:
		C.ALWAYS:
			return true
		C.ZONE_IS_CLOSE:
			return z >= 0 and state.zone_ranges[z] == DataEnums.RangeTag.CLOSE
		C.ZONE_IS_MID:
			return z >= 0 and state.zone_ranges[z] == DataEnums.RangeTag.MID
		C.ZONE_IS_LONG:
			return z >= 0 and state.zone_ranges[z] == DataEnums.RangeTag.LONG
		C.YOU_CONTROL_ZONE:
			return z >= 0 and state.control_of(z) == side
		C.YOU_CONTROL_2_PLUS_ZONES:
			return state.zones_controlled(side) >= 2
	return false


## amount, plus bonus_amount when bonus_condition holds in zone z.
static func amount_for(state, e: EffectData, side: int, z: int) -> int:
	var amount: int = e.amount
	if e.bonus_amount != 0 and e.bonus_condition != C.ALWAYS and condition_holds(state, e.bonus_condition, side, z):
		amount += e.bonus_amount
	return amount


## Units hit by the effect in zone z (z < 0: anywhere).
static func targets(state, e: EffectData, ctx: Dictionary, z: int) -> Array[RulesUnit]:
	var side: int = ctx["side"]
	var own: RulesSide = state.sides[side]
	var foe: RulesSide = state.sides[1 - side]
	var found: Array[RulesUnit] = []
	if ctx.has("override_target"):
		found.append(ctx["override_target"])
	else:
		match e.target:
			T.SELF:
				_add_if(found, ctx.get("source_unit"), z)
			T.OPERATOR:
				_add_if(found, own.operator_unit, z)
			T.CHOSEN_ENEMY:
				_add_if(found, foe.find_unit(ctx["target_uid"]), z)
			T.CHOSEN_FRIENDLY:
				_add_if(found, own.find_unit(ctx["target_uid"]), z)
			T.ENEMY_POINT_MAN:
				if z >= 0 and foe.line(z).size() > 0:
					found.append(foe.line(z)[0])
			T.ENEMY_SECOND_IN_LINE:
				if z >= 0 and foe.line(z).size() > 1:
					found.append(foe.line(z)[1])
			T.ALL_ENEMIES:
				found.assign(foe.line(z).duplicate() if z >= 0 else foe.units_on_board())
			T.ALL_FRIENDLIES, T.OTHER_FRIENDLIES:
				found.assign(own.line(z).duplicate() if z >= 0 else own.units_on_board())
				if e.target == T.OTHER_FRIENDLIES:
					found.erase(ctx.get("source_unit"))
			T.ARRIVING_ENEMY:
				_add_if(found, foe.find_unit(int(ctx.get("arriving_uid", -1))), z)
			T.FRIENDLY_POINT_MAN:
				if z >= 0 and own.line(z).size() > 0:
					found.append(own.line(z)[0])
			T.MOST_DAMAGED_FRIENDLY:
				if z >= 0:
					_add_if(found, most_damaged(state, own.line(z)), z)
	if e.target_class != DataEnums.WeaponClass.NONE:
		var of_class: Array = found.filter(func(u: RulesUnit) -> bool: return u.weapon_class == e.target_class)
		found.assign(of_class)
	return found


## Does a PASSIVE effect from `src` (null for a perk) apply to unit u?
static func passive_applies(state, e: EffectData, friendly: bool, src: RulesUnit, u: RulesUnit, _src_zone: int) -> bool:
	var owner: int = u.side if friendly else 1 - u.side
	if not condition_holds(state, e.condition, owner, u.zone):
		return false
	if e.target_class != DataEnums.WeaponClass.NONE and e.target_class != u.weapon_class:
		return false
	if src != null and e.zone_scope in [Z.THIS_ZONE, Z.CHOSEN_ZONE] and src.zone != u.zone:
		return false
	if e.zone_scope == Z.OPERATOR_ZONE:
		var op: RulesUnit = state.sides[owner].operator_unit
		if op == null or op.zone != u.zone:
			return false
	return _passive_target_ok(state, e, friendly, src, u)


## Does a PASSIVE effect of a Field (owned by `field_side`, standing in `field_zone`) apply
## to unit u? A Field's aura covers only its own column (zone_scope THIS_ZONE, validated).
static func field_passive_applies(state, e: EffectData, field_side: int, field_zone: int, u: RulesUnit) -> bool:
	if u.zone != field_zone:
		return false
	if not condition_holds(state, e.condition, field_side, u.zone):
		return false
	if e.target_class != DataEnums.WeaponClass.NONE and e.target_class != u.weapon_class:
		return false
	return _passive_target_ok(state, e, u.side == field_side, null, u)


static func _passive_target_ok(state, e: EffectData, friendly: bool, src: RulesUnit, u: RulesUnit) -> bool:
	var at_front: bool = state.sides[u.side].line(u.zone).find(u) == 0
	if friendly:
		match e.target:
			T.SELF:
				return src == u if src != null else u.is_operator
			T.OPERATOR:
				return u.is_operator
			T.ALL_FRIENDLIES:
				return true
			T.OTHER_FRIENDLIES:
				return src != u
			T.FRIENDLY_POINT_MAN:
				return at_front
		return false
	match e.target:
		T.ALL_ENEMIES:
			return true
		T.ENEMY_POINT_MAN:
			return at_front
	return false


## The unit in `line` with the most lost Armor (ties: front-most), skipping `exclude`;
## null when nobody is hurt. Shared by Patch (FirefightResolver) and HEAL (Aid Station).
static func most_damaged(state, line: Array, exclude: RulesUnit = null) -> RulesUnit:
	var best: RulesUnit = null
	for u: RulesUnit in line:
		if u == exclude or not u.is_alive():
			continue
		var missing: int = u.damage_taken(state.round_number)
		if missing > 0 and (best == null or missing > best.damage_taken(state.round_number)):
			best = u
	return best


static func until_round(state, e: EffectData) -> int:
	return RulesUnit.PERMANENT if e.duration_rounds <= 0 else state.round_number + e.duration_rounds - 1


static func damage_source(ctx: Dictionary) -> Dictionary:
	return {"side": ctx["side"], "uid": ctx["source_uid"], "source_id": ctx["source_id"], "source_kind": ctx["source_kind"]}


static func _apply(state, e: EffectData, ctx: Dictionary, z: int, amount: int) -> void:
	var side: int = ctx["side"]
	var own: RulesSide = state.sides[side]
	var kind: int = e.kind
	if kind == K.DAMAGE:
		var hit: Array[RulesUnit] = targets(state, e, ctx, z)
		if hit.is_empty():
			_wasted(state, e, ctx, "no target")
		for t: RulesUnit in hit:
			state.deal_damage(t, amount, damage_source(ctx))
	elif kind in _UNIT_MODS:
		var stored: int = amount if kind in [K.MODIFY_FIREPOWER, K.GRANT_COVER] else 1
		var hit: Array[RulesUnit] = targets(state, e, ctx, z)
		if hit.is_empty():
			_wasted(state, e, ctx, "no target")
		for t: RulesUnit in hit:
			t.add_mod(kind, stored, until_round(state, e))
			_applied(state, e, ctx, t.uid, stored)
	elif kind == K.MODIFY_ARMOR:
		for t: RulesUnit in targets(state, e, ctx, z):
			if e.duration_rounds <= 0:
				t.base_max_armor = maxi(1, t.base_max_armor + amount)
			else:
				t.add_mod(kind, amount, until_round(state, e))
			if amount > 0:
				t.armor += amount
			t.armor = clampi(t.armor, 1, t.max_armor(state.round_number))
			_applied(state, e, ctx, t.uid, amount)
	elif kind == K.SURVIVE_LETHAL:
		for t: RulesUnit in targets(state, e, ctx, z):
			t.survive_lethal = amount
			_applied(state, e, ctx, t.uid, amount)
	elif kind == K.HEAL:
		var healed_any: bool = false
		for t: RulesUnit in targets(state, e, ctx, z):
			var healed: int = mini(amount, t.damage_taken(state.round_number))
			if healed <= 0:
				continue
			t.armor += healed
			healed_any = true
			_applied(state, e, ctx, t.uid, healed)
			state.emit_event(RulesEvent.UNIT_HEALED, {"side": state.side_name(t.side), "source_id": ctx["source_id"],
					"source_uid": ctx["source_uid"], "target_uid": t.uid, "amount": healed, "remaining": t.armor,
					"zone": state.zone_name(t.zone)})
		if not healed_any:
			_wasted(state, e, ctx, "no damaged unit")
	elif kind == K.DRAW:
		state.draw_cards(side, amount)
		_applied(state, e, ctx, -1, amount)
	elif kind == K.REVEAL_RED_DOTS:
		if z < 0:
			return
		var on_round: int = state.round_number + e.delay_rounds
		var zones: Array = own.intel_reveals.get(on_round, [])
		if z not in zones:
			zones.append(z)
		own.intel_reveals[on_round] = zones
		if e.delay_rounds == 0:
			state.emit_event(RulesEvent.RED_DOTS_REVEALED, {"side": state.side_name(side), "zone": state.zone_name(z),
					"card_ids": state.revealed_red_dots(side, z), "private_to": state.side_name(side)})
	elif kind in [K.REVEAL_DEPLOYMENTS, K.HIDE_FROM_INTEL]:
		own.flags[kind] = until_round(state, e)
		_applied(state, e, ctx, -1, 1)
	elif kind == K.MOVE_UNIT:
		var dest: int = ctx["dest_zone"] if state.is_zone(ctx["dest_zone"]) else ctx["zone"]
		for t: RulesUnit in targets(state, e, ctx, z):
			_move(state, e, ctx, t, dest)
	elif kind == K.STREAK_BONUS:
		own.streak_bonus_this_round += amount
		_applied(state, e, ctx, -1, amount)
	elif kind == K.DESTROY_EQUIPMENT:
		var foe: RulesSide = state.sides[1 - side]
		var zones_hit: Array[int] = [0, 1, 2]
		if z >= 0:
			zones_hit = [z]
		var left: int = amount
		for zz: int in zones_hit:
			while left > 0 and not foe.equipment[zz].is_empty():
				var rc: RulesCard = foe.equipment[zz].pop_front()["card"]
				foe.discard.append(rc)
				left -= 1
				state.emit_event(RulesEvent.EQUIPMENT_DESTROYED, {"side": state.side_name(foe.index),
						"card_uid": rc.uid, "card_id": rc.card.id, "zone": state.zone_name(zz),
						"reason": RulesEvent.FIELD_GONE_DESTROYED})
	elif kind == K.SUMMON_UNIT:
		var at: int = z if z >= 0 else ctx["zone"]
		if not state.is_zone(at) or own.line(at).size() >= state.config.zone_capacity or e.summon_card == null:
			_wasted(state, e, ctx, "zone full")
			return
		var u: RulesUnit = state.create_unit(side, e.summon_card)
		state.put_in_line(u, at, false)
		_applied(state, e, ctx, u.uid, 1)
		state.trigger_traps(side, u)
	else:
		# STREAK_THRESHOLD_MOD, COOLDOWN_MOD: owned by p05 (read from the loadout); log only.
		_applied(state, e, ctx, -1, amount)


static func _move(state, e: EffectData, ctx: Dictionary, t: RulesUnit, dest: int) -> void:
	var own: RulesSide = state.sides[t.side]
	if not t.is_alive() or not state.are_adjacent(t.zone, dest) or own.line(dest).size() >= state.config.zone_capacity:
		_wasted(state, e, ctx, "can't move there")
		return
	var from: int = t.zone
	own.line(from).erase(t)
	state.put_in_line(t, dest)
	state.emit_event(RulesEvent.UNIT_MOVED, {"side": state.side_name(t.side), "uid": t.uid,
			"from_zone": state.zone_name(from), "zone": state.zone_name(dest)})
	state.trigger_traps(t.side, t)


static func _add_if(found: Array[RulesUnit], u: RulesUnit, z: int) -> void:
	if u != null and u.is_on_board() and (z < 0 or u.zone == z):
		found.append(u)


static func _applied(state, e: EffectData, ctx: Dictionary, target_uid: int, amount: int) -> void:
	state.emit_event(RulesEvent.EFFECT_APPLIED, {"side": state.side_name(ctx["side"]), "source_id": ctx["source_id"],
			"kind": DataEnums.key_of(K, e.kind), "target_uid": target_uid, "amount": amount})


static func _wasted(state, e: EffectData, ctx: Dictionary, reason: String) -> void:
	state.emit_event(RulesEvent.EFFECT_WASTED, {"side": state.side_name(ctx["side"]), "source_id": ctx["source_id"],
			"kind": DataEnums.key_of(K, e.kind), "reason": reason})

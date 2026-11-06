# fight_planner.gd
# Purpose: kc-fight PROTOTYPE (sim only): AiPlanner whose firefight estimator (_eval_zone)
#   plays the activation order of tests/tools/fight_order.gd (beats front to back, or the
#   front duel; First Shot pass or exchange; Pierce), so the AI plans for the order it plays
#   under. Everything except step 2 of _eval_zone is the shipped estimator, copied verbatim.
# Dependencies: AiPlanner, fight_order.gd.
# Author: Sr Game Designer Agent (kc-fight)
extends AiPlanner

const FightOrder = preload("res://tests/tools/fight_order.gd")


func _eval_zone(p: AiPlanner.Plan, z: int) -> float:
	if FightOrder.order == &"now":
		return super._eval_zone(p, z)
	var sides: Array = [p.lines[ME][z], p.lines[FOE][z]]
	var n: Array[int] = [(sides[0] as Array).size(), (sides[1] as Array).size()]
	var armor: Array = [[], []]
	var fp: Array = [[], []]
	var cover: Array = [[], []]
	var fs: Array = [[], []]
	var survive: Array = [[], []]
	# Auras: units already on the board include the old auras in their fp.
	var aura_old: int = 0
	var aura_new: int = 0
	for rec: Dictionary in sides[0]:
		if rec["new"]:
			aura_new += int(rec["aura"])
		else:
			aura_old += int(rec["aura"])
	var callout_used: bool = false
	for si: int in 2:
		for rec: Dictionary in sides[si]:
			armor[si].append(int(rec["armor"]))
			survive[si].append(int(rec["survive"]))
			fs[si].append(bool(rec["first_shot"]))
			var f: int = int(rec["fp"])
			var c: int = int(rec["cover"])
			if si == ME:
				f += p.my_fp_buff[z] + aura_new - (int(rec["aura"]) if rec["new"] else 0)
				if rec["new"]:
					f += aura_old
				if rec["card_unit"] and not callout_used and p.callout[z] != 0:
					f += p.callout[z]
					callout_used = true
				if not _view.my_cover_removed:
					c += p.my_cover_buff[z]
			elif p.foe_cover_removed:
				c = 0
			fp[si].append(f)
			cover[si].append(c)
	# Field auras: class / all auras now, frontline auras per step (they follow the line).
	var auras: Array = [_field_aura(_my_fields_after(p, z)), _field_aura(_view.foe_fields[z])]
	var cover_off: Array[bool] = [_view.my_cover_removed, p.foe_cover_removed or _view.foe_cover_removed]
	for si: int in 2:
		var au: Dictionary = auras[si]
		for i: int in n[si]:
			fp[si][i] = int(fp[si][i]) + int(au["all_fp"]) + int(au["class_fp"][_class_of(sides[si][i])])
			if not cover_off[si]:
				cover[si][i] = int(cover[si][i]) + int(au["all_cover"])
	var front_fp: Array[int] = [int(auras[ME]["front_fp"]), int(auras[FOE]["front_fp"])]
	var front_cover: Array[int] = [0 if cover_off[ME] else int(auras[ME]["front_cover"]),
			0 if cover_off[FOE] else int(auras[FOE]["front_cover"])]
	var foe_present_at_start: bool = _any_alive(armor[FOE])
	# 0. Start-of-firefight damage (Attack Helo) on each point man.
	if p.my_ff_damage > 0:
		_hit_point_man(armor[FOE], cover[FOE], survive[FOE], p.my_ff_damage, front_cover[FOE])
	if _view.foe_firefight_damage > 0:
		_hit_point_man(armor[ME], cover[ME], survive[ME], _view.foe_firefight_damage, front_cover[ME])
	if _any_alive(armor[ME]) and _any_alive(armor[FOE]):
		# 1. Suppress.
		for si: int in 2:
			for i: int in n[si]:
				if armor[si][i] > 0 and sides[si][i]["suppress"]:
					var pm: int = _first_alive(armor[1 - si])
					if pm >= 0:
						fp[1 - si][pm] = int(fp[1 - si][pm]) - 2
		# 2. kc-fight: beats in the prototype activation order (fight_order.gd).
		_fight(sides, n, armor, fp, cover, fs, survive, front_fp, front_cover)
		# 3. Patch.
		for si: int in 2:
			for i: int in n[si]:
				var patch: int = int(sides[si][i]["patch"])
				if patch <= 0 or armor[si][i] <= 0:
					continue
				var best: int = -1
				var best_missing: int = 0
				for j: int in n[si]:
					if j == i or armor[si][j] <= 0:
						continue
					var missing: int = int(sides[si][j]["max_armor"]) - int(armor[si][j])
					if missing > best_missing:
						best = j
						best_missing = missing
				if best >= 0:
					armor[si][best] = int(armor[si][best]) + mini(patch, best_missing)
	# 4. END_OF_ROUND Field effects (Score step): Mortar Pit chip, Aid Station heal.
	for si: int in 2:
		var au: Dictionary = auras[si]
		if int(au["eor_damage"]) > 0:
			_hit_point_man(armor[1 - si], cover[1 - si], survive[1 - si], int(au["eor_damage"]), front_cover[1 - si])
		if int(au["eor_heal"]) > 0:
			var best: int = -1
			var best_missing: int = 0
			for j: int in n[si]:
				var missing: int = int(sides[si][j]["max_armor"]) - int(armor[si][j])
				if armor[si][j] > 0 and missing > best_missing:
					best = j
					best_missing = missing
			if best >= 0:
				armor[si][best] = int(armor[si][best]) + mini(int(au["eor_heal"]), best_missing)
	return _zone_value(p, z, sides, armor, foe_present_at_start)


## Step 2 of the estimator in the prototype order. Arrays are indexed by line position.
func _fight(sides: Array, n: Array[int], armor: Array, fp: Array, cover: Array, fs: Array, survive: Array,
		front_fp: Array[int], front_cover: Array[int]) -> void:
	var fired: Array = [[], []]
	for si: int in 2:
		for i: int in n[si]:
			fired[si].append(false)
	var passes: Array = [&"front"] if FightOrder.order == &"front" else \
			([&"fs", &"all"] if FightOrder.fs_mode == &"pass" else [&"all"])
	for pass_kind: StringName in passes:
		var guard: int = 0
		while guard < 24:
			guard += 1
			if not (_any_alive(armor[ME]) and _any_alive(armor[FOE])):
				return
			var shooters: Array = []
			for si: int in 2:
				var pick: int = -1
				if pass_kind == &"front":
					var f: int = _first_alive(armor[si])
					if f >= 0 and not fired[si][f]:
						pick = f
				else:
					for i: int in n[si]:
						if armor[si][i] > 0 and not fired[si][i] and (pass_kind != &"fs" or fs[si][i]):
							pick = i
							break
				if pick >= 0:
					shooters.append([si, pick])
			if shooters.is_empty():
				break
			if pass_kind != &"fs" and FightOrder.fs_mode == &"exchange" and shooters.size() == 2 \
					and bool(fs[0][shooters[0][1]]) != bool(fs[1][shooters[1][1]]):
				var a: Array = shooters[0] if bool(fs[0][shooters[0][1]]) else shooters[1]
				var b: Array = shooters[1] if a == shooters[0] else shooters[0]
				_beat(sides, n, armor, fp, cover, survive, front_fp, front_cover, fired, [a])
				if int(armor[b[0]][b[1]]) > 0:
					_beat(sides, n, armor, fp, cover, survive, front_fp, front_cover, fired, [b])
				continue
			_beat(sides, n, armor, fp, cover, survive, front_fp, front_cover, fired, shooters)


func _beat(sides: Array, n: Array[int], armor: Array, fp: Array, cover: Array, survive: Array,
		front_fp: Array[int], front_cover: Array[int], fired: Array, shooters: Array) -> void:
	var dmg: Array = [[], []]
	for si: int in 2:
		for i: int in n[si]:
			dmg[si].append(0)
	var front: Array[int] = [_first_alive(armor[ME]), _first_alive(armor[FOE])]
	for sh: Array in shooters:
		var si: int = sh[0]
		var i: int = sh[1]
		var o: int = 1 - si
		fired[si][i] = true
		var assigned: Array[int] = []
		assigned.resize(n[o])
		var t: int = _target(sides[si][i], sides[o], armor[o], assigned)
		if t < 0:
			continue
		var shot: int = int(fp[si][i]) + (front_fp[si] if i == front[si] else 0)
		var d: int = maxi(0, maxi(0, shot) - int(cover[o][t]) - (front_cover[o] if t == front[o] else 0))
		dmg[o][t] = int(dmg[o][t]) + d
		if FightOrder.pierce.has(String(sides[si][i].get("id", &""))):
			var left: int = d - int(armor[o][t])
			var j: int = t
			while left > 0 and j + 1 < n[o]:
				j += 1
				if int(armor[o][j]) <= 0:
					continue
				var d2: int = mini(maxi(0, left - int(cover[o][j])), int(armor[o][j]))
				dmg[o][j] = int(dmg[o][j]) + d2
				left -= int(cover[o][j]) + int(armor[o][j])
	var died: Array = [[], []]
	for si: int in 2:
		for i: int in n[si]:
			if int(dmg[si][i]) <= 0 or armor[si][i] <= 0:
				continue
			armor[si][i] = int(armor[si][i]) - int(dmg[si][i])
			if armor[si][i] <= 0:
				if survive[si][i] > 0:
					armor[si][i] = survive[si][i]
					survive[si][i] = 0
				else:
					died[si].append(i)
	for si: int in 2:
		for i: int in died[si]:
			var od: int = int(sides[si][i]["on_down_damage"])
			if od > 0:
				_hit_point_man(armor[1 - si], cover[1 - si], survive[1 - si], od, front_cover[1 - si])

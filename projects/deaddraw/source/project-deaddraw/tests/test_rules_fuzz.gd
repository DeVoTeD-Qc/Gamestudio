# Random legal play over many seeds for every survivor: invariants hold and runs end.
extends "res://tests/dd_test_case.gd"


func _legal_actions(r: DDRun) -> Array:
	var acts: Array = []
	for i: int in r.street.size():
		for ch: String in r.choices_for(i):
			if bool(r.preview(i, ch)["enabled"]):
				acts.append([i, ch])
	if r.can_retreat():
		acts.append([-1, "retreat"])
	if r.can_slip_away():
		acts.append([-2, "slip"])
	return acts


func test_random_play_invariants() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2026
	var ends: Dictionary = {"dead": 0, "won": 0}
	for sid: String in ["rosa", "imani", "theo"]:
		for s: int in 60:
			var r: DDRun = DDRun.new(bal())
			r.start(sid, bal().all_perks(), s)
			var deep: bool = s % 2 == 0   # half the runs get refilled HP to explore all districts
			var steps: int = 0
			var ok: bool = true
			while (r.phase == DDRun.Phase.STREET or r.phase == DDRun.Phase.SAFEHOUSE) and steps < 2000:
				steps += 1
				if r.phase == DDRun.Phase.SAFEHOUSE:
					r.choose_perk(r.perk_offer[rng.randi_range(0, r.perk_offer.size() - 1)] if not r.perk_offer.is_empty() else "")
					continue
				var total: int = r.deck.size() + r.street.size()
				if r.hp > r.max_hp or r.hp <= 0 or r.cover < 0:
					ok = false
				if r.street.is_empty() or r.street.size() > 4 + 3:
					ok = false
				if not r.finale_in and r.street.size() > 4:
					ok = false
				var acts: Array = _legal_actions(r)
				if acts.is_empty():
					ok = false
					break
				var a: Array = acts[rng.randi_range(0, acts.size() - 1)]
				if int(a[0]) == -1:
					r.retreat()
					if r.deck.size() + r.street.size() != total:
						ok = false
				elif int(a[0]) == -2:
					r.slip_away()
				else:
					var before: int = r.street.size() + r.deck.size()
					var ev: Dictionary = r.resolve(int(a[0]), str(a[1]))
					if not bool(ev["ok"]):
						ok = false
					if r.phase == DDRun.Phase.STREET and r.district_index == r.district_index and not bool(ev["district_cleared"]):
						if r.street.size() + r.deck.size() != before - 1 and not r.finale_in:
							ok = false
				# survivors keep their HP back up a bit so we explore all districts
				if deep and r.phase == DDRun.Phase.STREET and r.hp < 16:
					r.max_hp = maxi(r.max_hp, 20)
					r.hp = r.max_hp
			check(ok, "invariants held (%s seed %d)" % [sid, s])
			check(r.phase == DDRun.Phase.DEAD or r.phase == DDRun.Phase.WON, "run ended (%s seed %d, steps %d)" % [sid, s, steps])
			if r.phase == DDRun.Phase.WON:
				ends["won"] += 1
				eq(r.district_scores.size(), 3, "3 scores on a win")
			else:
				ends["dead"] += 1
	check(int(ends["won"]) > 0, "some random runs reach the end: %s" % str(ends))

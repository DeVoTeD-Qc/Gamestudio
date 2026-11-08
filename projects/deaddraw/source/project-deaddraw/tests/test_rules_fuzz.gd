# Random legal play (cards, reloads, skips, doors, machines, offers) over many seeds for every
# survivor: invariants hold and every run ends.
extends "res://tests/dd_test_case.gd"


func _legal_actions(r: DDRun) -> Array:
	var acts: Array = []
	if not r.pending_offer.is_empty():
		for ch: String in [DDRun.EQUIP1, DDRun.EQUIP2, DDRun.SCRAP]:
			if bool(r.offer_preview(ch)["enabled"]):
				acts.append(["offer", ch])
		return acts
	for i: int in r.street.size():
		for ch: String in r.choices_for(i):
			if bool(r.preview(i, ch)["enabled"]):
				acts.append(["card", i, ch])
	for s: int in 2:
		if r.can_reload(s):
			acts.append(["reload", s])
	if r.can_skip():
		acts.append(["skip"])
	if r.can_slip_away():
		acts.append(["slip"])
	for i: int in r.room_count():
		if r.can_open_room(i):
			acts.append(["room", i])
		if r.opened.has(i):
			for o: Dictionary in r.machine_options(i):
				if bool(o["enabled"]):
					acts.append(["machine", i, str(o["id"])])
	return acts


func test_random_play_invariants() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2026
	var ends: Dictionary = {"dead": 0, "won": 0}
	var seen: Dictionary = {}
	for sid: String in ["rosa", "imani", "theo"]:
		for s: int in 30:
			var r: DDRun = DDRun.new(bal())
			r.start(sid, bal().all_perks(), s)
			var deep: bool = s % 2 == 0
			var steps: int = 0
			var ok: bool = true
			var why: String = ""
			while (r.phase == DDRun.Phase.STREET or r.phase == DDRun.Phase.SAFEHOUSE) and steps < 3000:
				steps += 1
				if r.phase == DDRun.Phase.SAFEHOUSE:
					r.choose_perk(r.perk_offer[rng.randi_range(0, r.perk_offer.size() - 1)] if not r.perk_offer.is_empty() else "")
					continue
				if r.hp > r.max_hp or r.hp <= 0 or r.cover < 0 or r.points < 0 or r.reserve < 0 or r.reserve > bal().num("reserve_cap"):
					ok = false
					why = "bad numbers %s" % str(r.summary())
				if r.street.is_empty() or (not r.boss_street and r.street.size() > 4):
					ok = false
					why = "street size %d" % r.street.size()
				for w: Variant in r.slots:
					if w != null and ((w as DDWeapon).ammo < 0 or (w as DDWeapon).ammo > (w as DDWeapon).cap):
						ok = false
						why = "ammo out of range"
				var acts: Array = _legal_actions(r)
				if acts.is_empty():
					ok = false
					why = "no legal action %s" % str(r.summary())
					break
				var a: Array = acts[rng.randi_range(0, acts.size() - 1)]
				# prefer resolving cards so runs move on
				if str(a[0]) != "card" and str(a[0]) != "offer" and rng.randf() < 0.5:
					for b: Variant in acts:
						if str((b as Array)[0]) == "card":
							a = b
							break
				seen[str(a[0])] = true
				var ev: Dictionary
				match str(a[0]):
					"offer":
						ev = r.take_offer(str(a[1]))
					"card":
						ev = r.resolve(int(a[1]), str(a[2]))
					"reload":
						ev = r.reload(int(a[1]))
					"skip":
						ev = r.skip()
					"slip":
						ev = r.slip_away()
					"room":
						ev = r.open_room(int(a[1]))
					"machine":
						ev = r.use_machine(int(a[1]), str(a[2]))
				if not bool(ev.get("ok", false)):
					ok = false
					why = "legal action refused: %s %s" % [str(a), str(ev.get("reason", ""))]
				if deep and r.phase == DDRun.Phase.STREET and r.hp < 12:
					r.hp = r.max_hp
					r.points += 3
			check(ok, "invariants held (%s seed %d): %s" % [sid, s, why])
			check(r.phase == DDRun.Phase.DEAD or r.phase == DDRun.Phase.WON, "run ended (%s seed %d, steps %d)" % [sid, s, steps])
			if r.phase == DDRun.Phase.WON:
				ends["won"] += 1
				eq(r.boss_hp.size(), 3, "3 bosses on a win")
			else:
				ends["dead"] += 1
	check(int(ends["won"]) > 0, "some random runs reach the end: %s" % str(ends))
	for k: String in ["card", "reload", "skip", "room", "machine", "offer"]:
		check(seen.has(k), "fuzz exercised " + k)

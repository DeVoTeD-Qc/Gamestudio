# Random legal play (attacks with every weapon, gun cards, medkits, cover, Run, rooms, machines,
# Patches, Lookout, run-past, safehouses) over many seeds for every survivor: invariants hold and
# every run ends.
extends "res://tests/dd_test_case.gd"


func _step(r: DDRun, rng: RandomNumberGenerator) -> void:
	if r.phase == DDRun.Phase.SAFEHOUSE:
		var off: Array = r.pending_patch.get("offer", [])
		r.leave_safehouse(str(off[rng.randi_range(0, off.size() - 1)]) if not off.is_empty() else "")
		return
	if not r.pending_patch.is_empty():
		var o: Array = r.pending_patch["offer"]
		r.take_patch(str(o[rng.randi_range(0, o.size() - 1)]))
		return
	var roll: float = rng.randf()
	if roll < 0.05 and r.can_run():
		r.run_street()
		return
	if roll < 0.08 and r.can_run_past():
		r.run_past()
		return
	if roll < 0.2:
		for i: int in r.room_count():
			if r.can_open_room(i):
				r.open_room(i)
				return
			var opts: Array[Dictionary] = r.machine_options(i)
			for o2: Dictionary in opts:
				if bool(o2["enabled"]) and rng.randf() < 0.5:
					r.use_machine(i, str(o2["id"]))
					return
	if roll < 0.22 and r.can_bury():
		r.bury_top()
		return
	var tries: int = 0
	while tries < 30:
		tries += 1
		var i: int = rng.randi_range(0, r.street.size() - 1)
		var c: DDCard = r.street[i]
		if c.kind == DDCard.ZOMBIE:
			var w: int = rng.randi_range(0, 2)
			if r.can_attack(i, w):
				r.attack(i, w)
				return
		else:
			var ch: Array[String] = r.choices_for(i)
			var pick: String = ch[rng.randi_range(0, ch.size() - 1)]
			if bool(r.card_preview(i, pick)["ok"]):
				r.resolve(i, pick)
				return
	# fall back: melee anything, else resolve anything
	for i: int in r.street.size():
		if r.can_attack(i, DDRun.MELEE):
			r.attack(i, DDRun.MELEE)
			return
	for i: int in r.street.size():
		var ch2: Array[String] = r.choices_for(i)
		if not ch2.is_empty() and bool(r.card_preview(i, ch2[0])["ok"]):
			r.resolve(i, ch2[0])
			return


func test_random_play_invariants() -> void:
	var ended: int = 0
	var won: int = 0
	var bad: Array[String] = []
	for sv: String in ["rosa", "imani", "theo"]:
		for seed_value: int in 12:
			var r: DDRun = DDRun.new(bal())
			r.start(sv, seed_value * 31 + 7)
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = seed_value + 1000
			var steps: int = 0
			while (r.phase == DDRun.Phase.STREET or r.phase == DDRun.Phase.SAFEHOUSE) and steps < 2000:
				steps += 1
				_step(r, rng)
				if r.hp > r.max_hp:
					bad.append("%s/%d hp over max" % [sv, seed_value])
				if r.points < 0:
					bad.append("%s/%d negative points" % [sv, seed_value])
				if r.phase == DDRun.Phase.STREET and r.street.is_empty():
					bad.append("%s/%d empty street" % [sv, seed_value])
				if r.street.size() > 5:
					bad.append("%s/%d street too big" % [sv, seed_value])
				for g: Variant in r.slots:
					if g != null and (g as DDGun).stack.size() >= (g as DDGun).cap:
						bad.append("%s/%d full stack not collected" % [sv, seed_value])
			if r.phase == DDRun.Phase.DEAD or r.phase == DDRun.Phase.WON:
				ended += 1
			if r.phase == DDRun.Phase.WON:
				won += 1
	eq(ended, 36, "every random run ends")
	eq(bad.slice(0, 5), [] as Array[String], "invariants")
	print("     fuzz: %d / 36 random runs won" % won)

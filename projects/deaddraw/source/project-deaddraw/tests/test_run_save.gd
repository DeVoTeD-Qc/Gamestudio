# dd-save: the mid-run save (save version 4 = v3 "Kill Stacks", its own file). Round trips
# mid-wave, with kill stacks, rooms / machines / Patches, a pending Patch pick, after a Run, on a
# boss street (Patient Zero phases) and at the safehouse; a resumed run plays identically (RNG
# state included); corrupt files are ignored; an old v2 run is discarded safely (with a note on
# the title); the file is cleared when the run ends; the Game session resumes and abandons.
extends "res://tests/dd_test_case.gd"

var _paths: Array[String] = []


func _save() -> DDRunSave:
	var p: String = "user://dd_test_run_%d_%d.json" % [Time.get_ticks_usec(), _paths.size()]
	_paths.append(p)
	return DDRunSave.new(p)


func _cleanup() -> void:
	for p: String in _paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_paths.clear()


## Plays `n` random legal actions (attacks, cards, Run, rooms, machines, Patches, safehouse).
func _play(r: DDRun, rng: RandomNumberGenerator, n: int) -> Array:
	var trace: Array = []
	for k: int in n:
		if r.phase == DDRun.Phase.SAFEHOUSE:
			var off: Array = r.pending_patch.get("offer", [])
			r.leave_safehouse(str(off[0]) if not off.is_empty() else "")
			trace.append("safehouse")
			continue
		if r.phase != DDRun.Phase.STREET:
			break
		var acts: Array = []
		if not r.pending_patch.is_empty():
			acts.append(["patch", str(r.pending_patch["offer"][0])])
		else:
			for i: int in r.street.size():
				if r.street[i].kind == DDCard.ZOMBIE:
					for w: int in 3:
						if r.can_attack(i, w):
							acts.append(["attack", i, w])
				else:
					for ch: String in r.choices_for(i):
						if bool(r.card_preview(i, ch)["ok"]):
							acts.append(["card", i, ch])
			if r.can_run():
				acts.append(["run"])
			for i: int in r.room_count():
				if r.can_open_room(i):
					acts.append(["room", i])
				for o: Dictionary in r.machine_options(i):
					if bool(o["enabled"]):
						acts.append(["machine", i, str(o["id"])])
		if acts.is_empty():
			break
		var a: Array = acts[rng.randi_range(0, acts.size() - 1)]
		var ev: Dictionary
		match str(a[0]):
			"patch":
				ev = r.take_patch(str(a[1]))
			"attack":
				ev = r.attack(int(a[1]), int(a[2]))
			"card":
				ev = r.resolve(int(a[1]), str(a[2]))
			"run":
				ev = r.run_street()
			"room":
				ev = r.open_room(int(a[1]))
			"machine":
				ev = r.use_machine(int(a[1]), str(a[2]))
		trace.append(str(ev.get("text", "")))
		if r.hp < 8 and r.phase == DDRun.Phase.STREET:
			r.hp = r.max_hp
			r.points += 4
	return trace


func _roundtrip(r: DDRun, what: String) -> void:
	var sv: DDRunSave = _save()
	check(sv.save(r, "STREET"), what + ": saved")
	var back: Dictionary = sv.load_run(bal())
	check(not back.is_empty(), what + ": loads")
	if back.is_empty():
		return
	var b: DDRun = back["run"]
	eq(JSON.stringify(b.to_dict()), JSON.stringify(r.to_dict()), what + ": identical state after the round trip")
	# both copies play on identically: same random choices, same shuffles, same results
	var t1: Array = _play(r, _rng(77), 60)
	var t2: Array = _play(b, _rng(77), 60)
	eq(t2, t1, what + ": the resumed run plays identically")
	eq(JSON.stringify(b.to_dict()), JSON.stringify(r.to_dict()), what + ": same state after 60 more actions")


func _rng(s: int) -> RandomNumberGenerator:
	var g: RandomNumberGenerator = RandomNumberGenerator.new()
	g.seed = s
	return g


func test_roundtrip_mid_wave() -> void:
	var r: DDRun = make_run("rosa")
	_play(r, _rng(3), 7)
	_roundtrip(r, "mid wave")
	_cleanup()


func test_roundtrip_stacks_rooms_patches_pending() -> void:
	var r: DDRun = make_run("theo")
	r.points = 999
	r.open_room(0)
	r.open_room(1)
	r.slots[1] = r.make_gun("rifle")
	r.slot(1).stack = [8, 6] as Array[int]
	r.slot(1).honed = true
	r.slot(1).flipped = true
	r.slot(1).rule = "up"
	r.active = 1
	r.cover = 3
	r._add_patch("loose_grip")
	r._add_patch("lookout")
	r.use_machine(1, "press")
	check(not r.pending_patch.is_empty(), "a Patch pick is pending")
	var sv: DDRunSave = _save()
	sv.save(r, "STREET")
	var b: DDRun = sv.load_run(bal())["run"]
	eq(b.slot(1).stack, [8, 6] as Array[int], "stack kept")
	check(b.slot(1).honed and b.slot(1).flipped and b.slot(1).rule == "up", "bench plates kept")
	eq(b.active, 1, "active weapon kept")
	eq(b.room_open, [true, true, false] as Array[bool], "rooms kept")
	check(b.machine_used[1], "machine used this wave kept")
	eq(b.pending_patch["offer"], r.pending_patch["offer"], "pending Patch pick kept")
	_roundtrip(r, "stacks + rooms + pending Patch")
	_cleanup()


func test_roundtrip_after_a_run_and_on_the_boss_street() -> void:
	var r: DDRun = make_run("rosa")
	r.run_street()
	check(r.ran_last, "ran")
	var sv: DDRunSave = _save()
	sv.save(r, "STREET")
	check(sv.load_run(bal())["run"].ran_last, "can't Run twice in a row, even after a reload")
	_roundtrip(r, "after Run")
	var p: DDRun = make_run("imani")
	p.district_index = 2
	p._start_district()
	to_boss(p, ["M5"])
	p.cover = 99
	p.slots[0] = p.make_gun("crossbow")
	p.attack(idx(p, "Z8"), 0)
	eq(p.pz_next, 2, "phase 2 next")
	var sv2: DDRunSave = _save()
	sv2.save(p, "STREET")
	var b: DDRun = sv2.load_run(bal())["run"]
	check(b.boss_street, "boss street kept")
	eq(b.pz_next, 2, "phase kept")
	eq(b.boss_queue.size(), 1, "phase 3 still waiting")
	eq(codes(b.street), codes(p.street), "street kept (phase 2 on it)")
	check(b.street[idx(b, "Z10")].phase == 2, "phase number kept")
	check(sv2.summary(bal()).contains("boss"), "Continue says boss street: " + sv2.summary(bal()))
	_roundtrip(p, "Patient Zero mid-fight")
	_cleanup()


func test_roundtrip_safehouse() -> void:
	var r: DDRun = make_run("rosa")
	clear_district(r)
	var sv: DDRunSave = _save()
	check(sv.save(r, "SAFEHOUSE"), "saved at the safehouse")
	var back: Dictionary = sv.load_run(bal())
	eq(str(back["screen"]), "SAFEHOUSE", "screen kept")
	var b: DDRun = back["run"]
	eq(b.phase, DDRun.Phase.SAFEHOUSE, "phase kept")
	eq(b.pending_patch["offer"], r.pending_patch["offer"], "the free Patch offer kept")
	_roundtrip(r, "safehouse")
	_cleanup()


func test_corrupt_old_and_finished_files_are_ignored() -> void:
	var sv: DDRunSave = _save()
	check(sv.load_run(bal()).is_empty(), "no file: nothing to resume")
	var f: FileAccess = FileAccess.open(sv.path, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	check(sv.load_run(bal()).is_empty(), "corrupt file: nothing, no crash")
	check(not sv.is_old(), "corrupt is not 'old'")
	# a v2 run (save version 3: magazines, Skipped pile) can't continue under the v3 rules
	f = FileAccess.open(sv.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 3, "screen": "STREET", "run": {"survivor_id": "rosa", "hp": 12, "max_hp": 20, "slots": [{"wid": "pistol", "ammo": 3}, null],
		"reserve": 6, "deck": [], "street": [{"k": "Z", "v": 5}], "skipped": [], "phase": 0, "district_index": 0, "rng_state": "1"}}))
	f.close()
	check(sv.load_run(bal()).is_empty(), "v2 run: not resumable")
	eq(sv.summary(bal()), "", "no Continue for it")
	check(sv.is_old(), "recognised as an old run")
	check(sv.discard_old(), "discarded")
	check(not sv.exists(), "file removed")
	# a v3-shaped run without its version marker inside is refused too
	f = FileAccess.open(sv.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": DDRunSave.VERSION, "run": {"survivor_id": "rosa"}}))
	f.close()
	check(sv.load_run(bal()).is_empty(), "unusable run data: nothing")
	var r: DDRun = make_run("rosa")
	r.phase = DDRun.Phase.DEAD
	check(not sv.save(r), "a finished run is not saved")
	check(not sv.exists(), "and clears the file")
	eq(DDRunSave.VERSION, 4, "save version bumped for v3")
	_cleanup()


func test_game_discards_an_old_run_at_startup() -> void:
	var sv: DDRunSave = _save()
	var f: FileAccess = FileAccess.open(sv.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 3, "run": {}}))
	f.close()
	var g: Node = (load("res://autoload/game.gd") as GDScript).new()
	g.set("run_save", sv)
	g.set("bal", bal())
	g.set("profile", DDProfile.new(bal(), "user://dd_test_run_old_profile.json"))
	g.set("discarded_old_run", sv.discard_old())
	check(bool(g.get("discarded_old_run")), "Game notes the discarded run (the title shows it)")
	check(not g.call("has_saved_run"), "no saved run left")
	g.free()
	_cleanup()


func test_game_session_saves_resumes_and_clears() -> void:
	var g: Node = (load("res://autoload/game.gd") as GDScript).new()
	g.set("bal", bal())
	var pr: DDProfile = DDProfile.new(bal(), "user://dd_test_run_profile.json")
	g.set("profile", pr)
	var sv: DDRunSave = _save()
	g.set("run_save", sv)
	g.call("start_run", "imani", 5)
	check(sv.exists(), "a new run is saved right away")
	var r: DDRun = g.get("run")
	r.setup_street(["C2", "C2", "C2", "C2"] + filler(6))
	r.resolve(0, DDRun.USE)
	var want: String = JSON.stringify(r.to_dict())
	g.set("run", null)
	eq(g.call("resume_run"), "MAP", "resumes on the screen it was left on")
	var back: DDRun = g.get("run")
	eq(JSON.stringify(back.to_dict()), want, "same run after every event save")
	back.points = 999
	back.setup_street(filler(12))
	back.open_room(0)
	check(sv.load_run(bal())["run"].room_open[0], "events keep saving the resumed run")
	clear_district(back)
	eq(str(sv.load_run(bal())["screen"]), "SAFEHOUSE", "the safehouse is remembered")
	back.leave_safehouse(str(back.pending_patch["offer"][0]))
	eq(str(sv.load_run(bal())["screen"]), "MAP", "then the map")
	back.setup_street(["Z11", "C2", "C2", "C2"] + filler(4))
	back.hp = 2
	back.cover = 0
	back.patches.erase("second_wind")
	back.attack(0, DDRun.MELEE)
	check(not sv.exists(), "death clears the save")
	g.call("start_run", "rosa", 6)
	g.call("abandon_run")
	check(not sv.exists() and g.get("run") == null, "abandon clears it")
	g.free()
	if FileAccess.file_exists(pr.path):
		DirAccess.remove_absolute(pr.path)
	_cleanup()


func test_title_continue_and_abandon() -> void:
	var game: Node = tree.root.get_node_or_null("Game")
	if game == null:
		check(false, "Game autoload missing")
		return
	var keep_prof: DDProfile = game.get("profile")
	var keep_save: DDRunSave = game.get("run_save")
	game.set("profile", DDProfile.new(bal(), "user://dd_test_run_title_profile.json"))
	var sv: DDRunSave = _save()
	game.set("run_save", sv)
	for sz: Vector2i in [Vector2i(390, 844), Vector2i(844, 390)]:
		tree.root.size = sz
		game.call("start_run", "rosa", 9)
		var r: DDRun = game.get("run")
		r.setup_street(["C2", "C2", "C2", "C2"] + filler(6))
		r.resolve(0, DDRun.USE)
		game.call("save_run", "STREET")
		var hp: int = r.hp
		var m: Control = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
		tree.root.add_child(m)
		await tree.process_frame
		eq(m.call("screen_name"), "TITLE", "title")
		var cont: Button = _button(m, "CONTINUE RUN")
		check(cont != null and cont.text.contains("Rosa") and cont.text.contains("Maple Row, wave 1") and cont.text.contains("HP %d" % hp), "Continue shows survivor, district, wave, HP: %s" % (cont.text if cont != null else "none"))
		check(_button(m, "New run as") != null, "a new run says it replaces the saved one")
		_button(m, "Abandon run").pressed.emit()
		await tree.process_frame
		await tree.process_frame
		check(_button(m, "Abandon this run") != null and _button(m, "No, keep it") != null, "abandon asks first")
		_button(m, "No, keep it").pressed.emit()
		await tree.process_frame
		await tree.process_frame
		check(sv.exists(), "kept")
		_button(m, "CONTINUE RUN").pressed.emit()
		await tree.process_frame
		await tree.process_frame
		eq(m.call("screen_name"), "STREET", "back on the street")
		var rr: DDRun = game.get("run")
		eq(rr.hp, hp, "same HP")
		eq(rr.resolved, 1, "same street, one card in")
		await tree.process_frame
		check(bool(m.call("banner_open")), "a 'run resumed' banner")
		m.call("dismiss_banner")
		check(not bool(m.call("banner_open")), "the banner can be dismissed early")
		m.set("screen", 0)
		m.call("_render")
		await tree.process_frame
		_button(m, "Abandon run").pressed.emit()
		await tree.process_frame
		await tree.process_frame
		_button(m, "Abandon this run").pressed.emit()
		await tree.process_frame
		await tree.process_frame
		check(not sv.exists(), "abandoned")
		check(_button(m, "CONTINUE RUN") == null, "no Continue any more")
		m.queue_free()
		await tree.process_frame
	game.set("profile", keep_prof)
	game.set("run_save", keep_save)
	if FileAccess.file_exists("user://dd_test_run_title_profile.json"):
		DirAccess.remove_absolute("user://dd_test_run_title_profile.json")
	_cleanup()


func _button(n: Node, prefix: String) -> Button:
	for c: Node in n.get_children():
		if c is Button and (c as Button).text.begins_with(prefix):
			return c
		var b: Button = _button(c, prefix)
		if b != null:
			return b
	return null

# dd-save: the mid-run save (save version 3, its own file). Round trips mid-wave, after a reload,
# with skipped cards, machines bought, buffs active and a pending Locker/Wall Rack offer; a resumed
# run plays identically (RNG state included); corrupt / old-version files are ignored; the file
# is cleared when the run ends; the Game session resumes and abandons; the title offers Continue.
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


## Plays `n` random legal actions (cards, reloads, skips, doors, machines, offers, perks).
func _play(r: DDRun, rng: RandomNumberGenerator, n: int) -> Array:
	var trace: Array = []
	for k: int in n:
		if r.phase == DDRun.Phase.SAFEHOUSE:
			r.choose_perk(r.perk_offer[0] if not r.perk_offer.is_empty() else "")
			trace.append("perk")
			continue
		if r.phase != DDRun.Phase.STREET:
			break
		var acts: Array = []
		if not r.pending_offer.is_empty():
			acts.append(["offer", DDRun.EQUIP2])
		else:
			for i: int in r.street.size():
				for ch: String in r.choices_for(i):
					if bool(r.preview(i, ch)["enabled"]):
						acts.append(["card", i, ch])
			for s: int in 2:
				if r.can_reload(s):
					acts.append(["reload", s])
			if r.can_skip():
				acts.append(["skip"])
			for i: int in r.room_count():
				if r.can_open_room(i):
					acts.append(["room", i])
				if r.opened.has(i):
					for o: Dictionary in r.machine_options(i):
						if bool(o["enabled"]):
							acts.append(["machine", i, str(o["id"])])
		if acts.is_empty():
			break
		var a: Array = acts[rng.randi_range(0, acts.size() - 1)]
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
	r.resolve(0, r.choices_for(0)[r.choices_for(0).size() - 1])
	check(r.actions_used == 1, "mid-street")
	_roundtrip(r, "mid wave")
	_cleanup()


func test_roundtrip_after_reload_skip_machines_buffs() -> void:
	var r: DDRun = plain_run(["Z5", "Z4", "B2", "B2"] + filler(8, "M3"))
	r.resolve(idx(r, "Z5"), DDRun.SLOT1)
	r.reload(0)
	_roundtrip(r, "after a reload")
	var s: DDRun = make_run("theo")
	s.skip()
	check(s.skipped.size() == 4, "skipped cards")
	_roundtrip(s, "with skipped cards")
	var m: DDRun = make_run("imani")
	m.points = 999
	m.open_room(0)
	m.open_room(1)
	m.use_machine(0, str(m.machine_options(0)[0]["id"]))
	m.use_machine(1, "grin")
	m.buffs.append("steady_aim")
	m.buffs.append("payday")
	m.free_reload = true
	check(not m.pending_offer.is_empty(), "a Wall Rack gun waiting for a slot")
	_roundtrip(m, "machines bought, buffs active, pending offer")
	_cleanup()


func test_roundtrip_safehouse_and_later_district() -> void:
	var r: DDRun = make_run("rosa")
	r.perks.append("fast_hands")
	clear_district(r)
	eq(r.phase, DDRun.Phase.SAFEHOUSE, "at the safehouse")
	_roundtrip(r, "safehouse")
	var r2: DDRun = make_run("rosa")
	clear_district(r2)
	r2.choose_perk(r2.perk_offer[0])
	to_boss_wave(r2, [], ["B2", "B2", "B2", "B2"], ["Z3", "M4"])
	_roundtrip(r2, "Downtown boss wave with a Skipped pile")
	_cleanup()


func test_corrupt_old_and_finished_files_are_ignored() -> void:
	var sv: DDRunSave = _save()
	check(sv.load_run(bal()).is_empty(), "no file: nothing to resume")
	for junk: String in ["{not json", "[]", JSON.stringify({"version": 2, "run": {}}),
			JSON.stringify({"version": 3, "run": {"survivor_id": "nobody"}}), JSON.stringify({"version": 3, "run": "x"}),
			JSON.stringify({"version": 3, "run": {"survivor_id": "rosa", "hp": 5, "max_hp": 20, "slots": [], "deck": [], "street": [],
				"phase": 0, "district_index": 0, "rng_state": "1"}})]:
		var f: FileAccess = FileAccess.open(sv.path, FileAccess.WRITE)
		f.store_string(junk)
		f.close()
		check(sv.load_run(bal()).is_empty(), "ignored: " + junk.substr(0, 40))
		eq(sv.summary(bal()), "", "no Continue for it")
	var r: DDRun = plain_run(["Z30", "B2", "B2", "B2"] + filler(4))
	check(sv.save(r), "saved")
	check(sv.summary(bal()).contains("Maple Row, wave 1"), "summary: " + sv.summary(bal()))
	r.resolve(0, DDRun.BARE)
	eq(r.phase, DDRun.Phase.DEAD, "dead")
	check(not sv.save(r), "a finished run is not saved")
	check(not sv.exists(), "and the file is cleared")
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
	r.resolve(0, r.choices_for(0)[r.choices_for(0).size() - 1])
	var want: String = JSON.stringify(r.to_dict())
	g.set("run", null)
	eq(g.call("resume_run"), "MAP", "resumes on the screen it was left on")
	var back: DDRun = g.get("run")
	eq(JSON.stringify(back.to_dict()), want, "same run after every event save")
	back.points = 999
	back.setup_street(filler(12))
	back.open_room(0)
	check(sv.load_run(bal())["run"].opened.size() == 1, "events keep saving the resumed run")
	clear_district(back)
	eq(str(sv.load_run(bal())["screen"]), "SAFEHOUSE", "the safehouse is remembered")
	back.choose_perk(back.perk_offer[0])
	eq(str(sv.load_run(bal())["screen"]), "MAP", "then the map")
	back.setup_street(["Z40", "B2", "B2", "B2"] + filler(4))
	back.hp = 2
	back.second_wind = false
	back.resolve(0, DDRun.BARE)
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
		r.resolve(0, r.choices_for(0)[r.choices_for(0).size() - 1])
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
		eq(rr.actions_used, 1, "same street, one action in")
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

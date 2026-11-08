# Meta unlocks and the user:// save.
extends "res://tests/dd_test_case.gd"

var _paths: Array[String] = []


func _prof() -> DDProfile:
	var p: String = "user://dd_test_profile_%d.json" % (Time.get_ticks_usec() + _paths.size())
	_paths.append(p)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
	return DDProfile.new(bal(), p)


func _cleanup() -> void:
	for p: String in _paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func test_fresh_pool_is_starter() -> void:
	var pr: DDProfile = _prof()
	eq(pr.perk_pool(), bal().starter_perks(), "starter pool")
	_cleanup()


func test_maple_unlocks_second_wind_once() -> void:
	var pr: DDProfile = _prof()
	eq(pr.record_district_clear("maple_row"), ["perk:second_wind"] as Array[String], "new unlock")
	check(pr.perk_pool().has("second_wind"), "in the pool")
	eq(pr.record_district_clear("maple_row").size(), 0, "not new the second time")
	_cleanup()


func test_downtown_unlocks_theo() -> void:
	var pr: DDProfile = _prof()
	var fresh: Array[String] = pr.record_district_clear("downtown")
	check(fresh.has("survivor:theo"), "Theo unlocked")
	check(pr.survivor_unlocked("theo"), "available")
	_cleanup()


func test_win_unlocks_tripwire_and_badge() -> void:
	var pr: DDProfile = _prof()
	var fresh: Array[String] = pr.record_run_end("imani", 80, true)
	check(fresh.has("perk:tripwire"), "Tripwire")
	check(fresh.has("badge:imani"), "Survivor's Mark")
	eq(pr.badges("imani"), 1, "badge count")
	eq(pr.badges("rosa"), 0, "only that survivor")
	var again: Array[String] = pr.record_run_end("imani", 50, true)
	check(not again.has("badge:imani") and not again.has("perk:tripwire"), "nothing new on the second win")
	eq(pr.badges("imani"), 2, "marks counted")
	_cleanup()


func test_best_score_per_survivor() -> void:
	var pr: DDProfile = _prof()
	pr.record_run_end("rosa", 30, false)
	pr.record_run_end("rosa", 12, false)
	pr.record_run_end("imani", 44, false)
	eq(pr.best_score("rosa"), 30, "best kept")
	eq(pr.best_score("imani"), 44, "per survivor")
	eq(int(pr.data["runs"]), 3, "runs counted")
	_cleanup()


func test_save_load_roundtrip() -> void:
	var pr: DDProfile = _prof()
	pr.record_district_clear("maple_row")
	pr.record_district_clear("downtown")
	pr.record_run_end("rosa", 77, true)
	check(FileAccess.file_exists(pr.path), "file written to user://")
	var back: DDProfile = DDProfile.new(bal(), pr.path)
	check(back.load_profile(), "loaded")
	check(back.survivor_unlocked("theo"), "Theo persisted")
	check(back.perk_pool().has("second_wind") and back.perk_pool().has("tripwire"), "perks persisted")
	eq(back.best_score("rosa"), 77, "best persisted")
	eq(back.badges("rosa"), 1, "badge persisted")
	check(back.has_cleared("maple_row"), "clears persisted")
	_cleanup()


func test_corrupt_save_falls_back_to_fresh() -> void:
	var pr: DDProfile = _prof()
	var f: FileAccess = FileAccess.open(pr.path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	check(not pr.load_profile(), "load reports failure")
	check(not pr.survivor_unlocked("theo"), "fresh state")
	_cleanup()


func test_game_session_records_unlocks() -> void:
	var g: Node = (load("res://autoload/game.gd") as GDScript).new()
	g.set("bal", bal())
	var pr: DDProfile = _prof()
	g.set("profile", pr)
	g.set("run_save", DDRunSave.new(pr.path + ".run.json"))
	g.call("start_run", "rosa", 3)
	var r: DDRun = g.get("run")
	eq(r.perk_pool, bal().starter_perks(), "run uses the profile pool")
	clear_district(r)
	eq(r.phase, DDRun.Phase.SAFEHOUSE, "cleared Maple Row")
	check((g.get("new_unlocks") as Array).has("perk:second_wind"), "unlock recorded during the run")
	check(pr.has_cleared("maple_row"), "saved")
	r.choose_perk(r.perk_offer[0])
	r.setup_street(["Z30", "Z30", "B2", "B2"] + filler(8))
	r.hp = 3
	r.second_wind = false
	r.resolve(0, DDRun.BARE)
	eq(r.phase, DDRun.Phase.DEAD, "dead")
	eq(pr.best_score("rosa"), r.run_score(), "run end recorded")
	eq(int(pr.data["runs"]), 1, "recorded once")
	g.call("sync_profile")
	eq(int(pr.data["runs"]), 1, "still once")
	g.free()
	_cleanup()


func test_version_1_save_keeps_unlocks() -> void:
	var pr: DDProfile = _prof()
	var f: FileAccess = FileAccess.open(pr.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "cleared": ["maple_row", "downtown"], "unlocked_perks": ["second_wind", "sandbags"],
		"unlocked_survivors": ["theo"], "best": {"rosa": 64}, "badges": {"imani": 1}, "runs": 9, "wins": 1,
		"settings": {"master_volume": 0.4}}))
	f.close()
	check(pr.load_profile(), "v1 save loads")
	eq(int(pr.data["version"]), DDProfile.VERSION, "upgraded to version 2")
	check(DDProfile.VERSION >= 2, "save version bumped")
	check(pr.survivor_unlocked("theo"), "Theo kept")
	check(pr.perk_pool().has("second_wind"), "unlocked perk kept")
	check(not pr.perk_pool().has("sandbags"), "cut v1 perk not offered")
	check(pr.has_cleared("downtown"), "clears kept")
	eq(pr.badges("imani"), 1, "badges kept")
	eq(int(pr.data["runs"]), 9, "runs kept")
	eq(pr.best_score("rosa"), 0, "v2 best starts fresh")
	eq(pr.best_v1("rosa"), 64, "v1 best kept as the old record")
	eq(float(pr.setting("master_volume")), 0.4, "settings kept")
	pr.save()
	var back: DDProfile = DDProfile.new(bal(), pr.path)
	back.load_profile()
	eq(back.best_v1("rosa"), 64, "old record survives a v2 save/load")
	_cleanup()

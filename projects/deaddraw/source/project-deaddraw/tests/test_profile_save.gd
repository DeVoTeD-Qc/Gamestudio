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


func test_maple_row_unlocks_nothing_in_v3() -> void:
	var pr: DDProfile = _prof()
	eq(pr.record_district_clear("maple_row").size(), 0, "v3: Maple Row unlocks nothing (Patches come from the Patch Press)")
	check(pr.has_cleared("maple_row"), "but the clear is recorded")
	_cleanup()


func test_first_run_hints_once() -> void:
	var pr: DDProfile = _prof()
	check(pr.first_run(), "a fresh profile is on its first run")
	check(pr.hint_due("weapon"), "hint due")
	pr.mark_hint("weapon")
	check(not pr.hint_due("weapon"), "each hint once")
	var back: DDProfile = DDProfile.new(bal(), pr.path)
	back.load_profile()
	check(not back.hint_due("weapon"), "seen hints are saved")
	check(back.hint_due("rooms"), "others still due")
	back.record_run_end("rosa", 10, false)
	check(not back.hint_due("rooms"), "no hints after the first run")
	_cleanup()


func test_downtown_unlocks_theo() -> void:
	var pr: DDProfile = _prof()
	var fresh: Array[String] = pr.record_district_clear("downtown")
	check(fresh.has("survivor:theo"), "Theo unlocked")
	check(pr.survivor_unlocked("theo"), "available")
	_cleanup()


func test_win_gives_the_badge() -> void:
	var pr: DDProfile = _prof()
	var fresh: Array[String] = pr.record_run_end("imani", 80, true)
	check(fresh.has("badge:imani"), "Survivor's Mark")
	eq(pr.badges("imani"), 1, "badge count")
	eq(pr.badges("rosa"), 0, "only that survivor")
	var again: Array[String] = pr.record_run_end("imani", 50, true)
	check(not again.has("badge:imani"), "nothing new on the second win")
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
	clear_district(r)
	eq(r.phase, DDRun.Phase.SAFEHOUSE, "cleared Maple Row")
	check(pr.has_cleared("maple_row"), "saved")
	r.leave_safehouse(str(r.pending_patch["offer"][0]))
	clear_district(r)
	check((g.get("new_unlocks") as Array).has("survivor:theo"), "Downtown clear unlocks Theo during the run")
	r.leave_safehouse(str(r.pending_patch["offer"][0]))
	r.setup_street(["Z11", "Z11", "C2", "C2"] + filler(8))
	r.hp = 2
	r.cover = 0
	r.patches.erase("second_wind")
	r.attack(0, DDRun.MELEE)
	eq(r.phase, DDRun.Phase.DEAD, "dead")
	eq(pr.best_score("rosa"), r.run_score(), "run end recorded")
	eq(int(pr.data["runs"]), 1, "recorded once")
	g.call("sync_profile")
	eq(int(pr.data["runs"]), 1, "still once")
	g.free()
	_cleanup()


func test_version_2_save_moves_bests_to_old_record() -> void:
	var pr: DDProfile = _prof()
	var f: FileAccess = FileAccess.open(pr.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "cleared": ["maple_row", "downtown"], "unlocked_survivors": ["theo"],
		"best": {"rosa": 210, "theo": 95}, "best_v1": {"rosa": 64}, "badges": {"imani": 2}, "runs": 14, "wins": 2,
		"settings": {"sfx_volume": 0.3}}))
	f.close()
	check(pr.load_profile(), "v2 save loads")
	eq(int(pr.data["version"]), 3, "upgraded to version 3")
	eq(pr.best_score("rosa"), 0, "v3 bests start at zero")
	eq(pr.best_v2("rosa"), 210, "v2 best kept as the old record")
	eq(pr.best_v2("theo"), 95, "per survivor")
	eq(pr.best_v1("rosa"), 64, "the v1 record is kept too")
	check(pr.survivor_unlocked("theo") and pr.has_cleared("downtown"), "unlocks and clears kept")
	eq(pr.badges("imani"), 2, "badges kept")
	eq(int(pr.data["runs"]), 14, "runs kept")
	eq(float(pr.setting("sfx_volume")), 0.3, "settings kept")
	check(str(DDPayloads.survivor("rosa", bal(), pr)["body"]).contains("Old record (v2 rules): 2100"), "the survivor zoom shows the old record")
	pr.record_run_end("rosa", 30, false)
	eq(pr.best_score("rosa"), 30, "a v3 run sets the v3 best")
	pr.save()
	var back: DDProfile = DDProfile.new(bal(), pr.path)
	back.load_profile()
	eq(back.best_v2("rosa"), 210, "old record survives a v3 save/load")
	eq(back.best_score("rosa"), 30, "v3 best not moved again")
	_cleanup()


func test_version_1_save_keeps_unlocks() -> void:
	var pr: DDProfile = _prof()
	var f: FileAccess = FileAccess.open(pr.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "cleared": ["maple_row", "downtown"], "unlocked_perks": ["second_wind", "sandbags"],
		"unlocked_survivors": ["theo"], "best": {"rosa": 64}, "badges": {"imani": 1}, "runs": 9, "wins": 1,
		"settings": {"master_volume": 0.4}}))
	f.close()
	check(pr.load_profile(), "v1 save loads")
	eq(int(pr.data["version"]), DDProfile.VERSION, "upgraded to the current version")
	eq(DDProfile.VERSION, 3, "save version 3 (v3 Kill Stacks)")
	check(pr.survivor_unlocked("theo"), "Theo kept")
	check(pr.has_cleared("downtown"), "clears kept")
	eq(pr.badges("imani"), 1, "badges kept")
	eq(int(pr.data["runs"]), 9, "runs kept")
	eq(pr.best_score("rosa"), 0, "best starts fresh")
	eq(pr.best_v1("rosa"), 64, "v1 best kept as the old record")
	eq(float(pr.setting("master_volume")), 0.4, "settings kept")
	pr.save()
	var back: DDProfile = DDProfile.new(bal(), pr.path)
	back.load_profile()
	eq(back.best_v1("rosa"), 64, "old record survives a save/load")
	_cleanup()

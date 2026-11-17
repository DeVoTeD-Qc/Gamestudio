# test_save_mirror.gd
# Purpose: kc-ios-save. The run / settings / tutorial saves survive a crash-reload: every save is
#   also mirrored synchronously (SaveMirror, localStorage on the web; a MemoryStore here), reads take
#   the newest usable copy, an unreadable copy is skipped and never deleted, and a deleted save
#   leaves a tombstone so a stale IndexedDB file can't come back. A match in progress is not saved:
#   a reload continues on the run map with that match ready to replay from the same seed.
# Author: Technical Artist Agent (kc-ios-save)
extends "res://tests/test_case.gd"

const TutorialProgress: GDScript = preload("res://scripts/ui/tutorial/tutorial_progress.gd")

var _dir: String = ""
var _mem: SaveMirror.MemoryStore = null


func _begin() -> void:
	_dir = "user://test_save_mirror/s%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_dir)
	_mem = SaveMirror.MemoryStore.new()
	SaveMirror.use_store(_mem)


func _end() -> void:
	SaveMirror.use_store(null)
	for f: String in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(f))
	DirAccess.remove_absolute(_dir)


func _config() -> RunConfig:
	return tree.root.get_node("CardDB").get_run_config()


func _run(seed_value: int) -> RunProgress:
	return RunProgress.create_map_run(_config(), seed_value, {"first_run": true})


func _json(r: RunProgress) -> String:
	return JSON.stringify(r.to_dict())


func _write_raw(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# --- RunSave ---------------------------------------------------------------------------------

func test_run_survives_a_lost_file_through_the_mirror() -> void:
	_begin()
	var path: String = _dir.path_join("run_save.json")
	var r: RunProgress = _run(31)
	assert_eq(RunSave.write(path, r), OK, "write")
	assert_true(_mem.get_item(SaveMirror.key_for(path)) != "", "mirrored in the same call")
	# The IndexedDB sync never happened: the reload finds no file.
	DirAccess.remove_absolute(path)
	assert_true(RunSave.exists(path), "the mirror still offers the run")
	var loaded: Dictionary = RunSave.read(path, _config(), {"map": true})
	assert_eq(loaded["error"], "", "read from the mirror")
	assert_eq(loaded["source"], "mirror", "source")
	assert_not_null(loaded["run"], "run loaded")
	if loaded["run"] != null:
		assert_eq(_json(loaded["run"]), _json(r), "same run")
	_end()


func test_newest_copy_wins() -> void:
	_begin()
	var path: String = _dir.path_join("run_save.json")
	var r: RunProgress = _run(32)
	assert_eq(RunSave.write(path, r), OK, "first save")
	var old_file: String = FileAccess.get_file_as_string(path)
	r.tickets = r.tickets - 1
	assert_eq(RunSave.write(path, r), OK, "second save")
	# The file on disk is the stale one (IndexedDB still had the first save), the mirror is newer.
	_write_raw(path, old_file)
	var loaded: Dictionary = RunSave.read(path, _config(), {"map": true})
	assert_eq(loaded["source"], "mirror", "newer mirror wins over a stale file")
	assert_eq((loaded["run"] as RunProgress).tickets, r.tickets, "the newer tickets")
	# And the other way round: a newer file beats an older mirror.
	var newer: RunProgress = _run(32)
	newer.tickets = 1
	var mirror_text: String = _mem.get_item(SaveMirror.key_for(path))
	assert_eq(RunSave.write(path, newer), OK, "third save")
	_mem.set_item(SaveMirror.key_for(path), mirror_text)
	loaded = RunSave.read(path, _config(), {"map": true})
	assert_eq(loaded["source"], "file", "newer file wins over an older mirror")
	assert_eq((loaded["run"] as RunProgress).tickets, 1, "the file's tickets")
	_end()


func test_unreadable_copy_is_skipped_and_kept() -> void:
	_begin()
	var path: String = _dir.path_join("run_save.json")
	var r: RunProgress = _run(33)
	assert_eq(RunSave.write(path, r), OK, "save")
	var mirror_text: String = _mem.get_item(SaveMirror.key_for(path))
	for bad: String in ["{not json", "", "{\"version\": 1, \"deck\": 5, \"saved_at\": 99999999999}"]:
		_write_raw(path, bad)
		var loaded: Dictionary = RunSave.read(path, _config(), {"map": true})
		assert_not_null(loaded["run"], "a bad file '%s' falls back to the mirror" % bad)
		assert_eq(loaded["source"], "mirror", "from the mirror ('%s')" % bad)
		assert_eq(_mem.get_item(SaveMirror.key_for(path)), mirror_text, "mirror untouched ('%s')" % bad)
		assert_true(FileAccess.file_exists(path), "bad file not deleted by a read ('%s')" % bad)
	# A bad mirror with a good file: the file is used, the mirror is left as it is.
	assert_eq(RunSave.write(path, r), OK, "save again")
	_mem.set_item(SaveMirror.key_for(path), "{garbage")
	var l2: Dictionary = RunSave.read(path, _config(), {"map": true})
	assert_eq(l2["source"], "file", "bad mirror falls back to the file")
	assert_eq(_mem.get_item(SaveMirror.key_for(path)), "{garbage", "bad mirror kept")
	_end()


func test_both_copies_bad_is_an_error_and_quarantine_keeps_them() -> void:
	_begin()
	var path: String = _dir.path_join("run_save.json")
	_write_raw(path, "{not json")
	_mem.set_item(SaveMirror.key_for(path), "{also not json")
	assert_true(RunSave.exists(path), "something is there")
	var loaded: Dictionary = RunSave.read(path, _config())
	assert_true(loaded["run"] == null, "nothing loads")
	assert_false(loaded["missing"], "an error, not a missing save")
	assert_true(loaded["error"] != "", "with a reason")
	RunSave.quarantine(path)
	assert_false(RunSave.exists(path), "moved aside")
	assert_true(FileAccess.file_exists(path + RunSave.CORRUPT_SUFFIX), "file kept as .corrupt")
	assert_eq(_mem.get_item(SaveMirror.key_for(path + RunSave.CORRUPT_SUFFIX)), "{also not json", "mirror kept as .corrupt")
	_end()


func test_delete_leaves_a_tombstone_over_a_stale_file() -> void:
	_begin()
	var path: String = _dir.path_join("run_save.json")
	var r: RunProgress = _run(34)
	assert_eq(RunSave.write(path, r), OK, "save")
	var stale: String = FileAccess.get_file_as_string(path)
	RunSave.delete(path)
	assert_false(RunSave.exists(path), "deleted")
	# The delete never reached IndexedDB: the old file comes back after the reload.
	_write_raw(path, stale)
	assert_false(RunSave.exists(path), "the tombstone hides the stale file")
	assert_true(RunSave.read(path, _config(), {"map": true})["missing"], "reads as no save")
	# A new run after that is a save again.
	assert_eq(RunSave.write(path, _run(35)), OK, "new save")
	assert_true(RunSave.exists(path), "new run offered")
	_end()


func test_without_a_mirror_the_file_alone_still_works() -> void:
	_begin()
	SaveMirror.use_store(null)
	var path: String = _dir.path_join("run_save.json")
	var r: RunProgress = _run(36)
	assert_eq(RunSave.write(path, r), OK, "save")
	var loaded: Dictionary = RunSave.read(path, _config(), {"map": true})
	assert_eq(loaded["source"], "file", "file")
	assert_eq(_json(loaded["run"]), _json(r), "same run")
	RunSave.delete(path)
	assert_false(RunSave.exists(path), "deleted")
	_end()


func test_stamps_increase_within_a_session() -> void:
	var a: float = SaveMirror.stamp()
	var b: float = SaveMirror.stamp()
	assert_true(b > a, "strictly increasing")


# --- RunState: crash-reload ------------------------------------------------------------------

func test_run_state_continues_after_a_crash_reload() -> void:
	_begin()
	var rs: Node = tree.root.get_node("RunState")
	var saved: Dictionary = {"save_path": rs.save_path, "autosave": rs.autosave, "map": rs.get(&"run_map_enabled")}
	rs.save_path = _dir.path_join("run_save.json")
	rs.autosave = true
	rs.set(&"run_map_enabled", true)
	rs.start_run(4242)
	rs.set_killstreaks(rs.run.killstreaks)
	assert_eq(rs.begin_run(), "", "begin")
	var reach: Array = (rs.map_view()["nodes"] as Array).filter(func(n: Dictionary) -> bool: return bool(n.get("reachable", false)))
	assert_true(not reach.is_empty(), "a node to step on")
	if not reach.is_empty():
		assert_eq(rs.move_to(StringName(String(reach[0]["id"]))), "", "step on the first node")
	var m: MatchState = rs.create_match()
	assert_not_null(m, "match deployed")
	if m != null:
		m.start_match()
	var before: String = _json(rs.run)
	var seed_before: int = rs.run.match_seed()
	# Crash mid-match: no frame runs, the IndexedDB file never got the last saves.
	DirAccess.remove_absolute(rs.save_path)
	rs.reset()
	assert_true(rs.has_save(), "Continue is offered after the reload")
	assert_true(rs.continue_run(), "continue")
	assert_eq(_json(rs.run), before, "the run is intact")
	assert_eq(rs.run.match_seed(), seed_before, "the match replays from the same seed")
	var RunFlow: GDScript = load("res://scripts/ui/run/run_flow.gd")
	assert_eq(RunFlow.call(&"scene_for", rs.run), "res://scenes/run/RunMap.tscn", "back on the run map")
	assert_not_null(rs.create_match(), "the same match can be deployed again")
	rs.abandon_run()
	assert_false(rs.has_save(), "abandon: no Continue")
	rs.save_path = saved["save_path"]
	rs.autosave = saved["autosave"]
	rs.set(&"run_map_enabled", saved["map"])
	rs.reset()
	_end()


func test_flush_saves_writes_the_run_now() -> void:
	_begin()
	var rs: Node = tree.root.get_node("RunState")
	var saved: Dictionary = {"save_path": rs.save_path, "autosave": rs.autosave}
	rs.save_path = _dir.path_join("run_save.json")
	rs.autosave = true
	rs.start_run(77)
	_mem.items.clear()
	rs.flush_saves()
	assert_true(_mem.get_item(SaveMirror.key_for(rs.save_path)) != "", "pagehide flush mirrors the run")
	rs.abandon_run()
	rs.save_path = saved["save_path"]
	rs.autosave = saved["autosave"]
	rs.reset()
	_end()


# --- ConfigFile saves (settings / profile, tutorial) -----------------------------------------

func test_settings_profile_survives_a_lost_file() -> void:
	_begin()
	var st: Node = tree.root.get_node("Settings")
	var path: String = _dir.path_join("settings.cfg")
	var old_profile: Dictionary = st.run_profile
	st.run_profile = {"runs_finished": 3, "kc_test": true}
	assert_eq(st.save_to(path), OK, "saved")
	DirAccess.remove_absolute(path)
	st.run_profile = {}
	assert_true(st.load_from(path), "loaded from the mirror")
	assert_eq(st.run_profile.get("runs_finished"), 3, "profile back")
	# A stale file (older) loses to the newer mirror.
	st.run_profile = {"runs_finished": 1}
	assert_eq(st.save_to(path), OK, "older save")
	var stale: String = FileAccess.get_file_as_string(path)
	st.run_profile = {"runs_finished": 2}
	assert_eq(st.save_to(path), OK, "newer save")
	_write_raw(path, stale)
	st.run_profile = {}
	assert_true(st.load_from(path), "loaded")
	assert_eq(st.run_profile.get("runs_finished"), 2, "the newer profile wins")
	# A corrupt mirror never hides a good file.
	_mem.set_item(SaveMirror.key_for(path), "[[[ not a cfg")
	st.run_profile = {}
	assert_true(st.load_from(path), "loaded from the file")
	assert_eq(st.run_profile.get("runs_finished"), 1, "file values")
	st.run_profile = old_profile
	_end()


func test_tutorial_record_survives_a_lost_file() -> void:
	_begin()
	TutorialProgress.use_path(_dir.path_join("tutorial.cfg"))
	assert_true(TutorialProgress.should_offer(), "offered at first")
	TutorialProgress.record(true, 9)
	DirAccess.remove_absolute(_dir.path_join("tutorial.cfg"))
	assert_true(TutorialProgress.is_completed(), "completion kept by the mirror")
	assert_false(TutorialProgress.should_offer(), "not offered again")
	TutorialProgress.reset()
	assert_true(TutorialProgress.should_offer(), "reset clears it (tombstone)")
	TutorialProgress.use_path("")
	_end()

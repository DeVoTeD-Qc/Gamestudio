# test_save.gd
# Purpose: cz08 MatchStore / MatchSaveCodec unit tests: round trip (state, step, undo history,
#   meta, AI level and seed, balance snapshot), the save format, damaged / old / newer /
#   no-longer-replayable saves (never a crash: backed up, clear status, new match possible),
#   temp-file recovery, finished matches, the saved signal and the test-mode guard.
#   Every test uses its own MatchStore instance and file under user://test_save/.
# Dependencies: autoload/match_store.gd, MatchSaveCodec, SaveFile, LoadoutRules, MatchState,
#   tests/test_rules_fixtures.gd.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const Fx: GDScript = preload("res://tests/test_rules_fixtures.gd")
const StoreScript: GDScript = preload("res://autoload/match_store.gd")
var DIR: String = "user://test_save/%d" % OS.get_process_id()  # per test process (cz14: concurrent suites)
const META: Dictionary = {"mode": "ai", "ai_level": "rookie", "ai_seed": 4242, "human_seat": 0}


func _store(file: String) -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	var s: Node = StoreScript.new()
	s.save_path = DIR.path_join(file)
	s.content = Fx.content()
	for p: String in [s.save_path, s.save_path + ".tmp"]:
		SaveFile.remove(p)
	for why: String in ["corrupt", "old", "newer", "mismatch"]:
		SaveFile.remove("%s.%s.bak" % [s.save_path, why])
	return s


## A match a few actions in, mid-turn, with an undo snapshot on the stack.
func _mid_turn_state(content: RulesData = null) -> MatchState:
	var state: MatchState = MatchState.new_match(content if content != null else Fx.content())
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	var guard: int = 0
	while guard < 400:
		guard += 1
		var legal: Array[Dictionary] = LoadoutRules.legal_actions(state)
		var undoable: Array = legal.filter(func(a: Dictionary) -> bool: return String(a["type"]) in LoadoutRules.UNDOABLE)
		if state.round_number >= 2 and not undoable.is_empty():
			LoadoutRules.apply(state, undoable[rng.randi_range(0, undoable.size() - 1)])
			return state
		var a: Dictionary = legal[rng.randi_range(0, legal.size() - 1)]
		if String(a["type"]) == "concede":
			continue
		LoadoutRules.apply(state, a)
		if state.is_over():
			state = MatchState.new_match(state.data)
	return state


func _file_text(p: String) -> String:
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""


func _write_raw(p: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# --- Round trip ----------------------------------------------------------------------

func test_round_trip_resumes_same_state_and_step() -> void:
	var store: Node = _store("round_trip.save")
	var state: MatchState = _mid_turn_state()
	assert_true(state.undo_stack.size() > 0, "fixture is mid-turn with undo history")
	assert_true(store.save(state, META), "save written")
	assert_false(FileAccess.file_exists(store.save_path + ".tmp"), "no temp file left after the rename")
	var other: Node = StoreScript.new()
	other.save_path = store.save_path
	other.content = Fx.content()
	assert_true(other.has_saved_match(), "a fresh store sees the save")
	var info: Dictionary = other.saved_info()
	assert_eq(info["step"], state.actions.size(), "info step")
	assert_eq(info["round"], state.round_number, "info round")
	assert_eq(info["active"], state.active, "info active seat")
	assert_eq(info["ai_level"], "rookie", "AI level saved")
	assert_eq(info["ai_seed"], 4242, "AI seed saved")
	assert_eq(info["tunables_hash"], state.data.balance.tunables_hash(), "tunables hash saved")
	assert_eq(info["meta"], META, "meta saved")
	var got: Dictionary = other.resume()
	assert_false(got.is_empty(), "resume returns the match")
	var back: MatchState = got["state"]
	assert_eq(back.fingerprint(), state.fingerprint(), "same state")
	assert_eq(back.actions.size(), state.actions.size(), "same step")
	assert_eq(back.undo_stack.size(), state.undo_stack.size(), "same undo depth")
	assert_true(back.undo_stack == state.undo_stack, "same undo snapshots")
	assert_eq(got["meta"], META, "meta back")
	# The resumed match keeps playing and undoing like the original.
	var undo_a: ActionResult = LoadoutRules.apply(state, {"type": "undo", "seat": state.active})
	var undo_b: ActionResult = LoadoutRules.apply(back, {"type": "undo", "seat": back.active})
	assert_true(undo_a.ok and undo_b.ok, "undo works after resume")
	assert_eq(back.fingerprint(), state.fingerprint(), "same state after undo")
	store.free()
	other.free()


func test_save_format_header_and_fields() -> void:
	var store: Node = _store("format.save")
	var state: MatchState = _mid_turn_state()
	store.save(state, META)
	var text: String = _file_text(store.save_path)
	var header: String = text.substr(0, text.find("\n"))
	assert_true(header.begins_with("CARDZONE-MATCH-SAVE schema=%d " % MatchSaveCodec.SCHEMA_VERSION), "header: " + header)
	var decoded: Dictionary = MatchSaveCodec.decode(text)
	assert_eq(decoded["status"], MatchSaveCodec.OK, "decodes: %s" % decoded["error"])
	var body: Dictionary = decoded["body"]
	assert_eq(body["schema"], MatchSaveCodec.SCHEMA_VERSION, "schema in body")
	assert_eq(body["balance"], state.data.balance.snapshot(), "balance snapshot")
	assert_eq(body["ai"], {"level": "rookie", "seed": 4242}, "AI level and seed")
	assert_eq((body["actions"] as Array).size(), state.actions.size(), "move list")
	assert_true(body["origin"] == state.origin, "setup (origin)")
	assert_eq(int(body["summary"]["step"]), state.actions.size(), "summary step")
	store.free()


func test_balance_snapshot_is_used_on_resume() -> void:
	var store: Node = _store("balance.save")
	var errors: Array = []
	var tuned: RulesData = Fx.content().with_balance({"hand_size": 4, "hold_limit": 1}, errors)
	assert_true(errors.is_empty(), "overrides apply")
	var state: MatchState = _mid_turn_state(tuned)
	store.save(state, META)
	# The store rebuilds with default content: the saved snapshot must win.
	var got: Dictionary = store.resume()
	assert_false(got.is_empty(), "resumes: %s" % store.last_error())
	if got.is_empty():
		store.free()
		return
	var back: MatchState = got["state"]
	assert_eq(back.data.balance.hand_size, 4, "hand_size from the save")
	assert_eq(back.data.balance.hold_limit, 1, "hold_limit from the save")
	assert_eq(back.fingerprint(), state.fingerprint(), "same state")
	store.free()


func test_saved_signal_and_meta_kept() -> void:
	var store: Node = _store("signal.save")
	var steps: Array[int] = []
	store.saved.connect(func(step: int) -> void: steps.append(step))
	var state: MatchState = _mid_turn_state()
	store.save(state, META)
	store.save(state)  # empty meta keeps the last one
	assert_eq(steps, [state.actions.size(), state.actions.size()] as Array[int], "saved(step) per write")
	assert_eq(store.saved_info()["meta"], META, "meta kept across saves")
	store.free()


func test_finished_match_clears_the_save() -> void:
	var store: Node = _store("finished.save")
	var state: MatchState = _mid_turn_state()
	store.save(state, META)
	assert_true(store.has_saved_match(), "saved mid-match")
	LoadoutRules.apply(state, {"type": "concede", "seat": 0})
	assert_true(state.is_over(), "conceded")
	assert_true(store.save(state, META), "save of a finished match succeeds")
	assert_false(store.has_saved_match(), "nothing to resume after the match ended")
	assert_eq(store.status(), MatchSaveCodec.NONE, "status none")
	store.free()


func test_clear_removes_the_save() -> void:
	var store: Node = _store("clear.save")
	store.save(_mid_turn_state(), META)
	store.clear()
	assert_false(FileAccess.file_exists(store.save_path), "file removed")
	assert_false(store.has_saved_match(), "no match")
	assert_true(store.resume().is_empty(), "resume of nothing is {}")
	store.free()


# --- Bad saves: never crash, back up, clear status, new match possible ----------------------

func _expect_rejected(file: String, text: String, want: StringName, label: String) -> void:
	var store: Node = _store(file)
	_write_raw(store.save_path, text)
	assert_false(store.has_saved_match(), "%s: no resumable match" % label)
	assert_eq(store.status(), want, "%s: status" % label)
	assert_true(store.resume().is_empty(), "%s: resume gives {}" % label)
	var info: Dictionary = store.saved_info()
	assert_false(info["has_match"], "%s: info has_match false" % label)
	assert_true(String(info["text"]).contains("new match"), "%s: player text offers a new match" % label)
	assert_true(String(info["error"]) != "", "%s: error says why" % label)
	var backup: String = "%s.%s.bak" % [store.save_path, want]
	assert_eq(info["backup"], backup, "%s: backup path reported" % label)
	assert_eq(_file_text(backup), text, "%s: bad file kept as backup" % label)
	assert_false(FileAccess.file_exists(store.save_path), "%s: bad save removed" % label)
	# The next launch is clean, and a new match saves normally.
	var again: Node = StoreScript.new()
	again.save_path = store.save_path
	again.content = Fx.content()
	assert_false(again.has_saved_match(), "%s: next launch sees no save" % label)
	assert_eq(again.status(), MatchSaveCodec.NONE, "%s: next launch status none" % label)
	var fresh: MatchState = _mid_turn_state()
	assert_true(again.save(fresh, META), "%s: a new match saves" % label)
	assert_true(again.has_saved_match(), "%s: and is resumable" % label)
	store.free()
	again.free()


func _good_text() -> String:
	return MatchSaveCodec.encode(_mid_turn_state(), META)


func test_corrupt_saves_offer_new_match() -> void:
	var good: String = _good_text()
	var body: String = good.substr(good.find("\n") + 1)
	_expect_rejected("c_empty.save", "", MatchSaveCodec.CORRUPT, "empty file")
	_expect_rejected("c_garbage.save", "this is not a save {[", MatchSaveCodec.CORRUPT, "garbage")
	_expect_rejected("c_trunc.save", good.substr(0, good.length() / 2), MatchSaveCodec.CORRUPT, "truncated")
	var flipped: String = good.substr(0, good.length() - 40) + "9" + good.substr(good.length() - 39)
	_expect_rejected("c_flip.save", flipped, MatchSaveCodec.CORRUPT, "changed byte")
	_expect_rejected("c_noschema.save", "CARDZONE-MATCH-SAVE bytes=3 md5=x\n{}", MatchSaveCodec.CORRUPT, "no schema")
	_expect_rejected("c_headonly.save", "CARDZONE-MATCH-SAVE schema=%d" % MatchSaveCodec.SCHEMA_VERSION,
			MatchSaveCodec.CORRUPT, "header only")
	_expect_rejected("c_notdict.save", MatchSaveCodec.wrap_body("[1, 2, 3]", MatchSaveCodec.SCHEMA_VERSION),
			MatchSaveCodec.CORRUPT, "body not a dictionary")
	_expect_rejected("c_object.save", MatchSaveCodec.wrap_body('{"schema": 1, "x": Object(Node,"name":"x")}',
			MatchSaveCodec.SCHEMA_VERSION), MatchSaveCodec.CORRUPT, "object in body")
	# Well-formed text whose structure is wrong (checksum fixed up so the structure check runs).
	var parsed: Dictionary = str_to_var(body)
	var bad_origin: Dictionary = parsed.duplicate(true)
	bad_origin["origin"]["seats"][0]["health"] = ["hit", "hit"]
	_expect_rejected("c_types.save", MatchSaveCodec.wrap_body(var_to_str(bad_origin), MatchSaveCodec.SCHEMA_VERSION),
			MatchSaveCodec.CORRUPT, "wrong types in origin")
	var bad_action: Dictionary = parsed.duplicate(true)
	(bad_action["actions"] as Array).append({"type": "teleport", "seat": 0})
	_expect_rejected("c_action.save", MatchSaveCodec.wrap_body(var_to_str(bad_action), MatchSaveCodec.SCHEMA_VERSION),
			MatchSaveCodec.CORRUPT, "unknown action type")
	var no_actions: Dictionary = parsed.duplicate(true)
	no_actions.erase("actions")
	_expect_rejected("c_noactions.save", MatchSaveCodec.wrap_body(var_to_str(no_actions), MatchSaveCodec.SCHEMA_VERSION),
			MatchSaveCodec.CORRUPT, "missing move list")
	var binary: PackedByteArray = PackedByteArray([0xff, 0xfe, 0x00, 0x81, 0xc3])
	var store: Node = _store("c_binary.save")
	var f: FileAccess = FileAccess.open(store.save_path, FileAccess.WRITE)
	f.store_buffer(binary)
	f.close()
	assert_false(store.has_saved_match(), "binary junk: no match")
	assert_eq(store.status(), MatchSaveCodec.CORRUPT, "binary junk: corrupt")
	store.free()


func test_old_and_newer_saves_offer_new_match() -> void:
	var good: String = _good_text()
	var body: String = good.substr(good.find("\n") + 1)
	_expect_rejected("o_v0.save", MatchSaveCodec.wrap_body(body, 0), MatchSaveCodec.OLD, "schema 0")
	_expect_rejected("o_engine.save", _mid_turn_state().save_text(), MatchSaveCodec.OLD, "bare engine save_text")
	_expect_rejected("n_v2.save", MatchSaveCodec.wrap_body(body, MatchSaveCodec.SCHEMA_VERSION + 1),
			MatchSaveCodec.NEWER, "newer schema")
	_expect_rejected("n_v99.save", "CARDZONE-MATCH-SAVE schema=99 bytes=1 md5=x\n?", MatchSaveCodec.NEWER,
			"far newer schema, unknown body")


func test_unreplayable_saves_offer_new_match() -> void:
	var good: String = _good_text()
	var parsed: Dictionary = str_to_var(good.substr(good.find("\n") + 1))
	# An illegal move in the list (e.g. the rules changed).
	var illegal: Dictionary = parsed.duplicate(true)
	(illegal["actions"] as Array).append({"type": "move", "seat": 0, "to": "nowhere"})
	_expect_rejected("m_illegal.save", MatchSaveCodec.wrap_body(var_to_str(illegal), MatchSaveCodec.SCHEMA_VERSION),
			MatchSaveCodec.MISMATCH, "illegal move")
	# The replay lands somewhere else than the saved fingerprint (cards changed).
	var moved: Dictionary = parsed.duplicate(true)
	moved["summary"]["fingerprint"] = "0123456789abcdef0123456789abcdef"
	_expect_rejected("m_fp.save", MatchSaveCodec.wrap_body(var_to_str(moved), MatchSaveCodec.SCHEMA_VERSION),
			MatchSaveCodec.MISMATCH, "different end state")
	# A balance value this build no longer allows, an unknown tunable, a wrong hash.
	var bad_value: Dictionary = parsed.duplicate(true)
	bad_value["balance"]["hand_size"] = 99
	_expect_rejected("m_value.save", MatchSaveCodec.wrap_body(var_to_str(bad_value), MatchSaveCodec.SCHEMA_VERSION),
			MatchSaveCodec.MISMATCH, "balance value out of range")
	var unknown: Dictionary = parsed.duplicate(true)
	unknown["balance"]["retired_tunable"] = 3
	_expect_rejected("m_key.save", MatchSaveCodec.wrap_body(var_to_str(unknown), MatchSaveCodec.SCHEMA_VERSION),
			MatchSaveCodec.MISMATCH, "unknown tunable")
	var hash_off: Dictionary = parsed.duplicate(true)
	hash_off["tunables_hash"] = "000000000000"
	_expect_rejected("m_hash.save", MatchSaveCodec.wrap_body(var_to_str(hash_off), MatchSaveCodec.SCHEMA_VERSION),
			MatchSaveCodec.MISMATCH, "tunables hash differs")


# --- Atomic write, temp recovery, test guard -------------------------------------------

func test_complete_temp_file_is_recovered() -> void:
	var store: Node = _store("tmp.save")
	var state: MatchState = _mid_turn_state()
	_write_raw(store.save_path + ".tmp", MatchSaveCodec.encode(state, META))
	assert_true(store.has_saved_match(), "a complete temp file (crash before rename) is used")
	assert_true(FileAccess.file_exists(store.save_path), "and moved into place")
	assert_eq((store.resume()["state"] as MatchState).fingerprint(), state.fingerprint(), "same state")
	var half: Node = _store("tmp_half.save")
	_write_raw(half.save_path + ".tmp", MatchSaveCodec.encode(state, META).substr(0, 300))
	assert_false(half.has_saved_match(), "a half-written temp file is ignored")
	assert_false(FileAccess.file_exists(half.save_path + ".tmp"), "and removed")
	assert_eq(half.status(), MatchSaveCodec.NONE, "status none")
	store.free()
	half.free()


func test_failed_write_keeps_previous_save() -> void:
	var store: Node = _store("keep.save")
	var state: MatchState = _mid_turn_state()
	store.save(state, META)
	var before: String = _file_text(store.save_path)
	# Block the temp path with a directory: the write fails, the old save is untouched.
	DirAccess.make_dir_recursive_absolute(store.save_path + ".tmp")
	LoadoutRules.apply(state, {"type": "undo", "seat": state.active})
	assert_false(store.save(state, META), "write reported as failed")
	assert_eq(_file_text(store.save_path), before, "previous save intact")
	DirAccess.remove_absolute(store.save_path + ".tmp")
	store.free()


func test_test_runs_never_touch_the_real_save() -> void:
	assert_true(StoreScript.is_test_run(), "test runner detected")
	var autoload: Node = tree.root.get_node_or_null("MatchStore")
	assert_not_null(autoload, "MatchStore autoload registered")
	if autoload != null:
		assert_eq(autoload.path(), StoreScript.test_save_path(), "autoload uses the test file")
	var loose: Node = StoreScript.new()
	assert_eq(loose.save_path, StoreScript.DEFAULT_SAVE_PATH, "a new instance defaults to the real path")
	assert_eq(loose.path(), StoreScript.test_save_path(), "but writes the test file under the runner")
	loose.free()


func test_save_counter_orders_copies() -> void:
	var store: Node = _store("seq.save")
	var state: MatchState = _mid_turn_state()
	store.save(state, META)
	var first: Dictionary = MatchSaveCodec.decode(_file_text(store.save_path))
	store.save(state, META)
	var second: Dictionary = MatchSaveCodec.decode(_file_text(store.save_path))
	assert_eq(int(second["seq"]), int(first["seq"]) + 1, "seq goes up by one per save")
	# A new session numbers after the save already on disk (the web mirror compares seq).
	var later: Node = StoreScript.new()
	later.save_path = store.save_path
	later.content = Fx.content()
	later.save(state, META)
	assert_eq(int(MatchSaveCodec.decode(_file_text(store.save_path))["seq"]), int(second["seq"]) + 1,
			"a new session continues the count")
	assert_false(later.call("_mirror_on"), "the localStorage mirror is web-only")
	store.free()
	later.free()

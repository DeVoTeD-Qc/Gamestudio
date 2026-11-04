# test_save_collection.gd
# Purpose: cc09 save and load of the Collection: progress survives a reload (a new instance reads
#   the same user:// file, as after a browser reload), corrupt / old / newer / wrong-typed saves
#   fall back safely, the Lobby Duel saves and resumes through the rules engine's state and is
#   counted when it ends, and "reset demo" goes back to the demo start.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const Fx: GDScript = preload("res://tests/test_collection_fixtures.gd")


func _write(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _without_time(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	out.erase("saved_at")
	if out.get("lobby_duel") is Dictionary:
		out["lobby_duel"].erase("saved_at")
	return out


func test_progress_survives_reload() -> void:
	var fx: RefCounted = Fx.new(tree)
	var c: Node = fx.make("reload")
	fx.play(&"win", &"warden", [], 3)
	fx.play(&"win", &"archivist", [], 2)
	fx.bus().dossier_cleared.emit(&"dossier_carded", 2, 61.5)
	fx.bus().triptych_scored.emit(&"player", &"midnight_run", true)
	c.try_cipher_code([9, 9, 9, 9])
	var ids: Array = fx.loaner_ids()
	c.save_lineup(ids, ids[3])
	var before: Dictionary = _without_time(c.to_save_dict())
	assert_true(FileAccess.file_exists(c.save_path), "save written")
	assert_false(FileAccess.file_exists(c.save_path + ".tmp"), "no temp file left")
	fx.drop(c)
	var again: Node = fx.make("reload", false)
	assert_eq(again.load_status, again.STATUS_LOADED, "loaded")
	assert_eq(_without_time(again.to_save_dict()), before, "same collection after reload")
	assert_true(again.owns(&"city_never_sleeps") and again.owns(&"null_glyph"), "unlocked cards kept")
	assert_eq(again.goal_progress(&"unlock_beat_warden_no_legend")["current"], 1, "Long Watch progress kept")
	assert_eq(again.cipher_attempts(), 1, "cipher attempts kept")
	assert_eq(again.get_saved_lineup_ids()["signature"], ids[3], "Signature kept")
	assert_eq(SaveFile.read_json(again.save_path)["data"]["schema"], float(again.SCHEMA_VERSION), "schema version in the file")
	fx.finish()


func test_corrupt_save_falls_back_to_demo_start() -> void:
	var fx: RefCounted = Fx.new(tree)
	var path: String = Fx.path_for("corrupt")
	fx.make("corrupt")  # clears old files
	fx.finish()
	fx = Fx.new(tree)
	_write(path, "{\"schema\": 1, \"cards\": [\"dead_ai")
	var c: Node = fx.make("corrupt", false)
	assert_eq(c.load_status, c.STATUS_CORRUPT, "corrupt detected")
	assert_true(FileAccess.file_exists("%s.corrupt.json" % path.get_basename()), "corrupt file kept for bug reports")
	assert_eq(c.card_totals()["owned"], fx.db().starting_cards().size(), "demo start")
	assert_eq(SaveFile.read_json(path)["status"], SaveFile.OK_STATUS, "a good save replaced it")
	_write(path, "[1, 2, 3]")
	assert_eq(c.load_save(), c.STATUS_CORRUPT, "non-object JSON is corrupt too")
	fx.finish()


func test_old_and_wrong_typed_saves_load_safely() -> void:
	var fx: RefCounted = Fx.new(tree)
	var path: String = Fx.path_for("old")
	fx.make("old")
	fx.finish()
	fx = Fx.new(tree)
	# Schema 0 (no "schema" field), JSON floats, an unknown card, a stale goal.
	_write(path, JSON.stringify({"cards": ["graveyard_shift", "dead_air", "retired_card"],
			"stats": {"wins": 3.0, "streak": 2.0, "captures": "lots", "rival_wins": {"warden": 1.0}},
			"goals_done": ["unlock_captures_20", "no_such_goal"], "titles": [1, 2], "frames": "x",
			"cipher": {"solved": "yes", "attempts": -4}, "lineup": {"cards": ["mayday"], "signature": "mayday"},
			"lobby_duel": {"state": {"format": 1}}}))
	var c: Node = fx.make("old", false)
	assert_eq(c.load_status, c.STATUS_MIGRATED, "old schema migrated")
	assert_true(c.owns(&"dead_air"), "saved card kept")
	assert_false(c.owns(&"retired_card"), "unknown card dropped")
	assert_true(c.owns(&"mayday"), "starting cards always owned")
	assert_eq(c.stats()["wins"], 3, "float -> int")
	assert_eq(c.stats()["captures"], 0, "wrong type -> 0")
	assert_eq(c.stats()["rival_wins"], {"warden": 1}, "rival wins kept")
	assert_true(c.is_goal_done(&"unlock_captures_20"), "known goal kept")
	assert_false(c.is_goal_done(&"no_such_goal"), "unknown goal dropped")
	assert_true(c.owns(&"city_never_sleeps"), "1 saved Warden win still meets the Beat-the-Warden goal")
	assert_false(c.is_cipher_solved(), "\"yes\" is not a bool")
	assert_eq(c.cipher_attempts(), 0, "negative attempts clamped")
	assert_false(c.has_saved_lineup(), "illegal saved lineup dropped")
	assert_false(c.has_saved_lobby_duel(), "broken Lobby Duel dropped")
	assert_true(c.lobby_duel_dropped, "drop reported")
	assert_eq(SaveFile.read_json(path)["data"]["schema"], float(c.SCHEMA_VERSION), "rewritten at the current schema")
	fx.finish()


func test_newer_schema_is_backed_up_and_read() -> void:
	var fx: RefCounted = Fx.new(tree)
	var path: String = Fx.path_for("newer")
	fx.make("newer")
	fx.finish()
	fx = Fx.new(tree)
	var future: int = 99
	_write(path, JSON.stringify({"schema": future, "cards": ["honor_roll"], "hover_boards": true}))
	var c: Node = fx.make("newer", false)
	assert_eq(c.load_status, c.STATUS_NEWER, "newer detected")
	assert_true(FileAccess.file_exists("%s.v%d.json" % [path.get_basename(), future]), "original backed up")
	assert_true(c.owns(&"honor_roll"), "known fields read")
	fx.finish()


func test_lobby_duel_save_resume_and_finish() -> void:
	var fx: RefCounted = Fx.new(tree)
	var db: Node = fx.db()
	var c: Node = fx.make("lobby")
	var b: BalanceConfig = db.get_balance()
	var rival: RivalData = db.get_rival(&"warden")
	var p1: Array[CardData] = []
	p1.assign(b.loaner_lineup)
	var p2: Array[CardData] = []
	p2.assign(rival.lineup)
	var trips: Array[TriptychData] = []
	trips.assign(db.all_triptychs())
	var state: WallState = WallState.new_match(p1, b.loaner_signature, p2, rival.signature, WallState.P2, b, null, trips)
	fx.start_duel(&"lobby", rival.id, fx.ids(p1), b.loaner_signature.id)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4
	for i: int in 5:
		var moves: Array[Dictionary] = WallRules.legal_moves(state)
		var m: Dictionary = moves[rng.randi_range(0, moves.size() - 1)]
		WallRules.place(state, state.to_move, m["card"], m["slot"], m["copy_from"])
	assert_true(c.save_lobby_duel(state, {"elapsed_s": 75.0}), "saved")
	assert_eq(fx.events_named("lobby_duel_saved"), [["lobby_duel_saved", true]], "lobby_duel_saved(true)")
	# Browser reload.
	fx.drop(c)
	c = fx.make("lobby", false)
	assert_true(c.has_saved_lobby_duel(), "still saved after reload")
	var info: Dictionary = c.saved_lobby_duel_info()
	assert_eq(info["placements"], 5, "info: placements")
	assert_eq(info["rival_id"], rival.id, "info: rival")
	var r: Dictionary = c.resume_lobby_duel()
	assert_false(r.is_empty(), "resumes")
	assert_true(WallStateCodec.same_state(r["state"], state), "same rules state")
	assert_eq(r["elapsed_s"], 75.0, "elapsed time")
	assert_eq(r["lineup"], fx.ids(p1), "lineup")
	assert_eq(r["player"], WallState.P1, "player index")
	# Finish it: the resumed duel counts as a Legend-free Warden win, and the save is cleared.
	var s: WallState = r["state"]
	while not s.is_game_over():
		var moves: Array[Dictionary] = WallRules.legal_moves(s)
		WallRules.place(s, s.to_move, moves[0]["card"], moves[0]["slot"], moves[0]["copy_from"])
	assert_false(c.save_lobby_duel(s), "a finished duel can't be saved")
	fx.bus().duel_resumed.emit(r["age_s"])
	fx.end_duel(&"win")
	assert_false(c.has_saved_lobby_duel(), "cleared when the duel ends")
	assert_eq(c.stats()["rival_wins_no_legend"].get("warden", 0), 1, "counted with the saved lineup")
	assert_true(c.owns(&"city_never_sleeps"), "and unlocks")
	fx.drop(c)
	c = fx.make("lobby", false)
	assert_false(c.has_saved_lobby_duel(), "stays cleared after reload")
	fx.finish()


func test_reset_demo() -> void:
	var fx: RefCounted = Fx.new(tree)
	var c: Node = fx.make("reset")
	fx.play(&"win", &"warden")
	fx.bus().dossier_cleared.emit(&"dossier_clean_copy", 1, 5.0)
	var ids: Array = fx.loaner_ids()
	c.save_lineup(ids, ids[0])
	c.reset_demo()
	assert_eq(c.card_totals()["owned"], fx.db().starting_cards().size(), "back to the demo start")
	assert_true(c.titles().is_empty() and c.stats()["duels"] == 0, "titles and stats cleared")
	assert_false(c.has_saved_lineup(), "lineup cleared")
	assert_eq(fx.events_named("collection_reset").size(), 1, "collection_reset")
	fx.drop(c)
	c = fx.make("reset", false)
	assert_eq(c.card_totals()["owned"], fx.db().starting_cards().size(), "reset is saved")
	fx.finish()

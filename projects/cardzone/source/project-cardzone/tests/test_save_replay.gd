# test_save_replay.gd
# Purpose: cz08 done-when check: 20 saved games replay to the same state. Each game is played
#   from new_match() on the live CardDB content by a seeded random policy over legal_actions()
#   (with undos and the odd concede; the cz09 AI plugs in through test_czai_game once it lands),
#   saving through a MatchStore instance after every action, exactly as the match screen will.
#   At random steps (and always on a Brace step and on the last step before the end) a fresh
#   store resumes from the file and must give the same state fingerprint, step, active seat,
#   pending Brace and undo history. A finished match leaves no save behind.
# Dependencies: autoload/match_store.gd, MatchSaveCodec, LoadoutRules, MatchState, RulesData, CardDB.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const StoreScript: GDScript = preload("res://autoload/match_store.gd")
const GAMES: int = 20
const SEED_BASE: int = 8800
const MAX_ACTIONS: int = 3000
const MAX_PER_TURN: int = 20
const CHECKS_PER_GAME: int = 8
var PATH: String = "user://test_save/%d/replay.save" % OS.get_process_id()  # per test process (cz14: concurrent suites)

var _problems: Array[String] = []
var _stats: Dictionary = {}


func _content() -> RulesData:
	var db: Node = tree.root.get_node_or_null("CardDB")
	if db == null or not db.call("is_valid"):
		return null
	return RulesData.from_card_db(db)


func test_20_saved_games_replay_to_same_state() -> void:
	var content: RulesData = _content()
	assert_not_null(content, "CardDB content loads")
	if content == null:
		return
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	_problems.clear()
	_stats = {"games": 0, "saves": 0, "resumes": 0, "brace_resumes": 0, "undo_resumes": 0, "actions": 0,
			"max_bytes": 0, "save_ms": 0, "resume_ms": 0}
	var started: int = Time.get_ticks_msec()
	for g: int in GAMES:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = SEED_BASE + g
		_play_one(content, g % 3, rng, "game %d (seed %d)" % [g, SEED_BASE + g], Callable())
		if _problems.size() > 10:
			break
	print("     save-replay: %d games, %d actions, %d saves (%d ms), %d resumes (%d on a Brace step, %d with undo history; %d ms), largest save %d bytes, %d ms total" % [
			_stats["games"], _stats["actions"], _stats["saves"], _stats["save_ms"], _stats["resumes"],
			_stats["brace_resumes"], _stats["undo_resumes"], _stats["resume_ms"], _stats["max_bytes"],
			Time.get_ticks_msec() - started])
	assert_true(_problems.is_empty(), "\n".join(_problems))
	assert_eq(_stats["games"], GAMES, "every game finished and checked")
	assert_true(_stats["brace_resumes"] > 0, "some resumes happened on a Brace step")
	assert_true(_stats["undo_resumes"] > 0, "some resumes carried undo history")


## One run with the cz09 AI (CzAI) choosing for both seats, when scripts/ai has it.
func test_czai_game_replays_to_same_state() -> void:
	var ai_script: Script = _find_global_class("CzAI")
	if ai_script == null or not ai_script.can_instantiate():
		print("     save-replay: CzAI %s; AI run skipped" % ("not found" if ai_script == null else "does not compile yet (cz09 in progress)"))
		assert_true(true, "CzAI unavailable: skipped")
		return
	var content: RulesData = _content()
	assert_not_null(content, "CardDB content loads")
	_problems.clear()
	_stats = {"games": 0, "saves": 0, "resumes": 0, "brace_resumes": 0, "undo_resumes": 0, "actions": 0,
			"max_bytes": 0, "save_ms": 0, "resume_ms": 0}
	var chooser: Callable = _czai_chooser(ai_script)
	assert_true(chooser.is_valid(), "CzAI exposes a way to pick an action")
	if not chooser.is_valid():
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED_BASE + 99
	var meta_level: String = "rookie+veteran"
	_play_one(content, 0, rng, "CzAI game (%s)" % meta_level, chooser)
	print("     save-replay (CzAI): %d actions, %d saves, %d resumes" % [_stats["actions"], _stats["saves"], _stats["resumes"]])
	assert_true(_problems.is_empty(), "\n".join(_problems))
	assert_eq(_stats["games"], 1, "the AI game finished and was checked")


func _play_one(content: RulesData, route: int, rng: RandomNumberGenerator, label: String, chooser: Callable) -> void:
	var store: Node = StoreScript.new()
	store.save_path = PATH
	store.content = content
	store.clear()
	var meta: Dictionary = {"mode": "ai", "ai_level": "rookie", "ai_seed": int(rng.seed), "human_seat": 0}
	var state: MatchState = MatchState.new_match(content, route)
	var concede_at: int = rng.randi_range(30, 400) if rng.randf() < 0.1 else -1
	var turn_actions: int = 0
	var last_active: int = -1
	var n: int = 0
	var checks_left: int = CHECKS_PER_GAME
	var brace_checked: bool = false
	var last_good: Dictionary = {}
	while not state.is_over() and n < MAX_ACTIONS:
		n += 1
		if state.active != last_active:
			turn_actions = 0
			last_active = state.active
		var action: Dictionary
		if n == concede_at:
			action = {"type": "concede", "seat": rng.randi_range(0, 1)}
		elif chooser.is_valid():
			action = chooser.call(state)
		else:
			action = _choose(state, LoadoutRules.legal_actions(state), rng, turn_actions)
		if String(action.get("type", "")) in LoadoutRules.UNDOABLE and rng.randf() < 0.08 and not chooser.is_valid():
			LoadoutRules.apply(state, action)
			_save(store, state, meta)
			LoadoutRules.apply(state, {"type": "undo", "seat": state.active})
			_save(store, state, meta)
		var r: ActionResult = LoadoutRules.apply(state, action)
		if not r.ok:
			_problems.append("%s: action %s rejected: %s" % [label, action, r.error])
			store.free()
			return
		_stats["actions"] += 1
		turn_actions += 1
		_save(store, state, meta)
		if state.is_over():
			break
		last_good = {"fp": state.fingerprint(), "step": state.actions.size()}
		var on_brace: bool = state.pending_brace_seat() != MatchState.NO_SEAT
		if (on_brace and not brace_checked) or (checks_left > 0 and rng.randf() < 0.03):
			if on_brace:
				brace_checked = true
			else:
				checks_left -= 1
			if not _check_resume(state, label, n):
				store.free()
				return
	if not state.is_over():
		_problems.append("%s: did not end within %d actions" % [label, MAX_ACTIONS])
		store.free()
		return
	# The final save happened before the match-ending action: it must still resume (checked from
	# the record above), and the finished match must have cleared the file.
	var after: Node = StoreScript.new()
	after.save_path = PATH
	after.content = content
	if after.has_saved_match():
		_problems.append("%s: a finished match left a save behind" % label)
	after.free()
	# Last step before the end: rebuild that state and confirm it resumes exactly.
	var errors: Array = []
	var prev_actions: Array = state.actions.slice(0, state.actions.size() - 1)
	var prev: MatchState = LoadoutRules.replay(state.origin, prev_actions, state.data, errors)
	if errors.is_empty() and not prev.is_over():
		_save(store, prev, meta)
		if not _check_resume(prev, label, n - 1):
			store.free()
			return
	store.clear()
	store.free()
	_stats["games"] += 1


func _save(store: Node, state: MatchState, meta: Dictionary) -> void:
	var t: int = Time.get_ticks_usec()
	if not store.save(state, meta):
		_problems.append("save failed: %s" % store.last_error())
	_stats["save_ms"] += (Time.get_ticks_usec() - t) / 1000
	_stats["saves"] += 1
	if FileAccess.file_exists(PATH):
		_stats["max_bytes"] = maxi(_stats["max_bytes"], FileAccess.get_file_as_string(PATH).length())


func _check_resume(state: MatchState, label: String, n: int) -> bool:
	var t: int = Time.get_ticks_usec()
	var fresh: Node = StoreScript.new()
	fresh.save_path = PATH
	fresh.content = RulesData.from_card_db(tree.root.get_node("CardDB"))
	var got: Dictionary = fresh.resume()
	_stats["resume_ms"] += (Time.get_ticks_usec() - t) / 1000
	_stats["resumes"] += 1
	var where: String = "%s step %d" % [label, n]
	if got.is_empty():
		_problems.append("%s: resume failed (%s: %s)" % [where, fresh.status(), fresh.last_error()])
		fresh.free()
		return false
	var back: MatchState = got["state"]
	var want: Dictionary = MatchSaveCodec.summary_of(state)
	var have: Dictionary = MatchSaveCodec.summary_of(back)
	if want != have:
		_problems.append("%s: resumed %s, saved %s" % [where, have, want])
	elif back.fingerprint() != state.fingerprint() or back.undo_stack != state.undo_stack:
		_problems.append("%s: resumed state differs" % where)
	elif got["meta"] != fresh.saved_info().get("meta", got["meta"]) or int(got["meta"].get("ai_seed", -1)) < 0:
		_problems.append("%s: meta (AI level and seed) not kept: %s" % [where, got["meta"]])
	if state.pending_brace_seat() != MatchState.NO_SEAT:
		_stats["brace_resumes"] += 1
	if not state.undo_stack.is_empty():
		_stats["undo_resumes"] += 1
	# The resumed match must keep going exactly like the original: apply the same next action.
	var legal: Array[Dictionary] = LoadoutRules.legal_actions(state)
	if not legal.is_empty():
		var a: MatchState = state.clone()
		var ra: ActionResult = LoadoutRules.apply(a, legal[0])
		var rb: ActionResult = LoadoutRules.apply(back, legal[0])
		if ra.ok != rb.ok or a.fingerprint() != back.fingerprint() or ra.event_types() != rb.event_types():
			_problems.append("%s: resumed match diverges on the next action %s" % [where, legal[0]])
	fresh.free()
	return true


func _choose(state: MatchState, legal: Array[Dictionary], rng: RandomNumberGenerator, turn_actions: int) -> Dictionary:
	var by_type: Dictionary = {}
	for a: Dictionary in legal:
		var t: String = a["type"]
		if not by_type.has(t):
			by_type[t] = []
		by_type[t].append(a)
	var pick: Callable = func(t: String) -> Dictionary:
		var list: Array = by_type[t]
		return list[rng.randi_range(0, list.size() - 1)]
	if by_type.has("drop"):
		return pick.call("drop")
	if by_type.has("brace"):
		return pick.call("brace")
	if turn_actions < MAX_PER_TURN:
		var order: Array = [["shoot", 0.85], ["frag", 0.4], ["attach", 0.9], ["loot", 0.75], ["patch_up", 0.5],
				["play", 0.85], ["move", 0.35], ["ditch", 0.15]]
		for entry: Array in order:
			if by_type.has(entry[0]) and rng.randf() < float(entry[1]):
				return pick.call(entry[0])
	return pick.call("end_turn")


func _find_global_class(name: String) -> Script:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry["class"]) == name:
			return load(String(entry["path"])) as Script
	return null


## Adapts CzAI (cz09: CzAI.for_level(level, seed).choose_action(state, seat)) to
## "state -> action": Rookie plays P1, Veteran plays P2. Reached through the Script object so this
## file still parses while scripts/ai is being written.
func _czai_chooser(ai_script: Script) -> Callable:
	var ais: Array = [ai_script.call("for_level", &"rookie", SEED_BASE + 1),
			ai_script.call("for_level", &"veteran", SEED_BASE + 2)]
	if ais[0] == null or ais[1] == null:
		return Callable()
	return func(state: MatchState) -> Dictionary:
		var seat: int = state.pending_brace_seat()
		if seat == MatchState.NO_SEAT:
			seat = state.active
		return ais[seat].choose_action(state, seat)

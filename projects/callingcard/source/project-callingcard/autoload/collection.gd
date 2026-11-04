# collection.gd
# Purpose: Collection autoload (cc09). The player's demo collection and its save:
#   owned cards, cosmetic titles and frames, unlock-goal progress (data/unlocks/*.tres), set
#   completion, revealed Triptychs, Dossier clears, the Cipher Lock, the saved lineup + Signature
#   and one saved in-progress Lobby Duel (planning decision 1: save and resume).
#   Progress comes from EventBus (duel_started, duel_lineup_locked, card_captured, carded,
#   triptych_scored, duel_ended, dossier_cleared / dossier_completed); celebrations go out on EventBus
#   (card_unlocked, unlocked, title_earned, frame_earned, set_completed, unlock_progress,
#   unlock_goal_completed, triptych_revealed, cipher_attempted, cipher_solved, collection_changed).
#   Rewards are cosmetic or ownership only: nothing here touches CardData, BalanceConfig or the
#   rules (tests/test_collection.gd checks it).
#   Saves to user://collection.json (IndexedDB on the web) after every change; under the test
#   runner the autoload uses TEST_SAVE_PATH instead, so tests never touch the player's save. The file carries
#   SCHEMA_VERSION; a corrupt file is kept as collection.corrupt.json and the demo starts fresh,
#   an older one is migrated, a newer one is backed up and read field by field.
#   Keep it registered in project.godot in this order:
#   EventBus, Settings, CardDB, Collection, PlaytestLog, SceneRouter.
# Dependencies: EventBus, CardDB, SaveFile, WallStateCodec, LineupRules, data classes.
# Author: Mechanics Developer Agent
extends Node

const SCHEMA_VERSION: int = 1
const DEFAULT_SAVE_PATH: String = "user://collection.json"
## Save used when the headless test runner (res://tests/...) is the main loop, so no test, even one
## that plays a duel through EventBus, ever touches the player's save. Wiped at each test run start.
const TEST_SAVE_PATH: String = "user://test_collection/autoload_collection.json"
const PLAYER: StringName = &"player"
const SOURCE_DOSSIER: StringName = &"dossier"
const SOURCE_LOBBY: StringName = &"lobby"

## Load outcome of the last load_save().
const STATUS_NEW: StringName = &"new"            # no save yet: demo start
const STATUS_LOADED: StringName = &"loaded"
const STATUS_MIGRATED: StringName = &"migrated"  # older schema, upgraded
const STATUS_CORRUPT: StringName = &"corrupt"    # unreadable: backed up, demo start
const STATUS_NEWER: StringName = &"newer"        # newer schema: backed up, known fields read

## Where the save lives. Tests point a separate instance at their own file.
var save_path: String = DEFAULT_SAVE_PATH
## Write the save after every change.
var autosave: bool = true
## React to EventBus signals (tests switch the autoload off while they drive their own instance).
var listening: bool = true
var load_status: StringName = STATUS_NEW
## Set when a saved Lobby Duel couldn't be restored on load (data changed); it was dropped.
var lobby_duel_dropped: bool = false

var _owned: Dictionary = {}       # StringName card id -> true
var _titles: Dictionary = {}      # StringName title id -> String text
var _frames: Dictionary = {}      # StringName frame id -> true
var _goals_done: Dictionary = {}  # StringName goal id -> true
var _sets_done: Dictionary = {}   # StringName set id -> true
var _triptychs: Dictionary = {}   # StringName triptych id -> true
var _dossiers: Dictionary = {}    # StringName dossier id -> {attempts: int, best_s: float}
var _stats: Dictionary = {}       # see _new_stats()
var _cipher: Dictionary = {}      # {solved: bool, attempts: int}
var _lineup: Dictionary = {}      # {} or {cards: Array[StringName], signature: StringName, loaner: bool}
var _lobby_duel: Dictionary = {}  # {} or the saved snapshot (see save_lobby_duel)
## The duel in progress (not saved, except inside a Lobby Duel snapshot).
## {source, rival_id, lineup: Array[StringName], signature, loaner, lineup_known: bool}
var _duel: Dictionary = {}
var _last_progress: Dictionary = {}  # goal id -> last announced current value


func _ready() -> void:
	if is_test_run() and save_path == DEFAULT_SAVE_PATH:
		save_path = TEST_SAVE_PATH
		DirAccess.make_dir_recursive_absolute(TEST_SAVE_PATH.get_base_dir())
		SaveFile.remove(TEST_SAVE_PATH)
	_connect_bus()
	load_save()


## True when the main loop is the headless test runner (a script under res://tests/).
static func is_test_run() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	var script: Script = loop.get_script() if loop != null else null
	return script != null and script.resource_path.begins_with("res://tests/")

# --- Cards ---------------------------------------------------------------------------

func owns(card_id: StringName) -> bool:
	return _owned.has(card_id)


## Owned card ids in album order.
func owned_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for c: CardData in owned_cards():
		out.append(c.id)
	return out


## Owned cards in album order.
func owned_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	var db: Node = _db()
	if db == null:
		return out
	for c: CardData in db.all_cards():
		if _owned.has(c.id):
			out.append(c)
	return out


## {owned: int, total: int} over every card (the album's "13 / 20").
func card_totals() -> Dictionary:
	var db: Node = _db()
	return {"owned": owned_cards().size(), "total": db.card_count() if db != null else 0}

# --- Titles and frames (cosmetic) ----------------------------------------------------

## {title id: display text}. Ids: set_<set id>, <triptych id>, <dossier id>.
func titles() -> Dictionary:
	return _titles.duplicate()


func has_title(title_id: StringName) -> bool:
	return _titles.has(title_id)


func frames() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_frames.keys())
	out.sort()
	return out


func has_frame(frame_id: StringName) -> bool:
	return _frames.has(frame_id)


## Frame id granted by completing a set (the animated set frame on that set's cards).
static func set_frame_id(set_id: StringName) -> StringName:
	return StringName("set_frame_%s" % set_id)


## The earned frame a card shows in the album / on the wall: its set frame once the set is
## complete, else &"" (standard; Showcase cards always draw their premium frame).
func card_frame(card_id: StringName) -> StringName:
	var db: Node = _db()
	var card: CardData = db.get_card(card_id) if db != null else null
	if card == null or card.card_set == null:
		return &""
	var fid: StringName = set_frame_id(card.card_set.id)
	return fid if _frames.has(fid) else &""

# --- Unlock goals ----------------------------------------------------------------------

func is_goal_done(goal_id: StringName) -> bool:
	return _goals_done.has(goal_id)


## {current: int, target: int, done: bool} for an unlock goal ({} when unknown).
## Counts come from the UnlockGoal data (target_count; rival goals: 0 or 1 = once).
func goal_progress(goal_id: StringName) -> Dictionary:
	var db: Node = _db()
	var goal: UnlockGoal = db.get_unlock_goal(goal_id) if db != null else null
	if goal == null:
		return {}
	var target: int = goal.required_count()
	var done: bool = _goals_done.has(goal_id)
	var current: int = target if done else mini(_goal_value(goal), target)
	return {"current": current, "target": target, "done": done}


## The goal that unlocks a card (null for cards that start owned).
func goal_for_card(card_id: StringName) -> UnlockGoal:
	var db: Node = _db()
	var card: CardData = db.get_card(card_id) if db != null else null
	return card.unlock_goal if card != null else null

# --- Sets ----------------------------------------------------------------------------

## {owned: int, total: int, complete: bool} for a set ({} when unknown).
func set_progress(set_id: StringName) -> Dictionary:
	var db: Node = _db()
	if db == null or db.get_set(set_id) == null:
		return {}
	var cards: Array = db.cards_in_set(set_id)
	var owned: int = 0
	for c: CardData in cards:
		if _owned.has(c.id):
			owned += 1
	return {"owned": owned, "total": cards.size(), "complete": _sets_done.has(set_id)}


func is_set_complete(set_id: StringName) -> bool:
	return _sets_done.has(set_id)

# --- Triptychs -------------------------------------------------------------------------

## True once the player has scored this Triptych (the album shows it, not "???").
func has_triptych(triptych_id: StringName) -> bool:
	return _triptychs.has(triptych_id)


func revealed_triptychs() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_triptychs.keys())
	out.sort()
	return out


## Records a Triptych scored by the player. Returns true the first time (reveal + rewards).
func record_triptych(triptych_id: StringName) -> bool:
	if _triptychs.has(triptych_id):
		return false
	var db: Node = _db()
	var t: TriptychData = db.get_triptych(triptych_id) if db != null else null
	if t == null:
		push_warning("Collection: unknown Triptych '%s'" % triptych_id)
		return false
	_triptychs[triptych_id] = true
	EventBus.triptych_revealed.emit(triptych_id)
	_grant_title(t.id, t.reward_title)
	_grant_frame(t.reward_frame)
	_commit()
	return true

# --- Dossiers ----------------------------------------------------------------------------

func is_dossier_cleared(dossier_id: StringName) -> bool:
	return _dossiers.has(dossier_id)


## {attempts: int, best_s: float} of the first clear and best time, or {} when not cleared.
func dossier_record(dossier_id: StringName) -> Dictionary:
	return (_dossiers.get(dossier_id, {}) as Dictionary).duplicate()


func cleared_dossier_count() -> int:
	return _dossiers.size()


## Records a Dossier clear (also called from EventBus.dossier_cleared) and pays its reward:
## reward_card if not owned yet, else reward_title as the fallback (spec §5.2 D1: "card or title");
## reward_title on its own; reward_frame. Rewards are granted on the first clear only.
func record_dossier_clear(dossier_id: StringName, attempts: int = 1, duration_s: float = 0.0) -> void:
	var db: Node = _db()
	var d: DossierData = db.get_dossier(dossier_id) if db != null else null
	if d == null:
		push_warning("Collection: unknown Dossier '%s'" % dossier_id)
		return
	if _dossiers.has(dossier_id):
		var rec: Dictionary = _dossiers[dossier_id]
		if duration_s > 0.0 and (rec["best_s"] <= 0.0 or duration_s < rec["best_s"]):
			rec["best_s"] = duration_s
		_commit()
		return
	_dossiers[dossier_id] = {"attempts": maxi(attempts, 1), "best_s": maxf(duration_s, 0.0)}
	var card_given: bool = false
	if d.reward_card != null and not _owned.has(d.reward_card.id):
		_grant_card(d.reward_card.id, dossier_id)
		card_given = true
	if not card_given and not d.reward_title.strip_edges().is_empty():
		_grant_title(d.id, d.reward_title)
	_grant_frame(d.reward_frame)
	_evaluate_goals()
	_commit()

## Dossier-completion API for cc12 (same as record_dossier_clear). Safe to call more than once.
func complete_dossier(dossier_id: StringName, attempts: int = 1, duration_s: float = 0.0) -> void:
	record_dossier_clear(dossier_id, attempts, duration_s)

# --- Cipher Lock -------------------------------------------------------------------------

func is_cipher_solved() -> bool:
	return bool(_cipher.get("solved", false))


func cipher_attempts() -> int:
	return int(_cipher.get("attempts", 0))


## Number of dials on the lock (length of balance.cipher_code).
func cipher_length() -> int:
	var db: Node = _db()
	return db.get_balance().cipher_code.size() if db != null else 0


## Tries a code (glyph numbers, dial order). The answer is balance.tres cipher_code, never
## hard-coded. Emits cipher_attempted; the right code also completes CIPHER_LOCK goals.
## Trying again after it is solved just answers true/false without changing anything.
func try_cipher_code(code: Array) -> bool:
	var db: Node = _db()
	if db == null:
		return false
	var answer: PackedInt32Array = db.get_balance().cipher_code
	var correct: bool = code.size() == answer.size()
	if correct:
		for i: int in answer.size():
			if SaveFile.to_int(code[i], -1) != answer[i]:
				correct = false
				break
	if is_cipher_solved():
		return correct
	_cipher["attempts"] = cipher_attempts() + 1
	EventBus.cipher_attempted.emit(correct)
	if correct:
		_cipher["solved"] = true
		EventBus.cipher_solved.emit()
		_evaluate_goals()
	_commit()
	return correct

# --- Lineup ------------------------------------------------------------------------------

## Validates (LineupRules, owned cards only) and saves the lineup and its Signature.
## Returns the LineupRules result {valid, errors, messages}; nothing is saved when invalid.
## A loaner lineup skips the ownership check. Emits EventBus.lineup_saved on success.
func save_lineup(card_ids: Array, signature_id: StringName, loaner: bool = false) -> Dictionary:
	var db: Node = _db()
	var cards: Array = []
	for id: Variant in card_ids:
		cards.append(db.get_card(StringName(str(id))) if db != null else null)
	var sig: CardData = db.get_card(signature_id) if db != null else null
	var result: Dictionary = LineupRules.validate(cards, [sig] if sig != null else [],
			null if loaner else owned_ids(), db.get_balance() if db != null else null)
	if not result["valid"]:
		return result
	var ids: Array[StringName] = []
	var clearance: int = 0
	for c: CardData in cards:
		ids.append(c.id)
		clearance += c.clearance
	_lineup = {"cards": ids, "signature": signature_id, "loaner": loaner}
	EventBus.lineup_saved.emit(ids.duplicate(), clearance, signature_id, loaner)
	_commit()
	return result


func has_saved_lineup() -> bool:
	return not _lineup.is_empty()


## {cards: Array[CardData], signature: CardData, loaner: bool}, or {} when none is saved.
func get_saved_lineup() -> Dictionary:
	if _lineup.is_empty():
		return {}
	var db: Node = _db()
	var cards: Array[CardData] = []
	for id: StringName in _lineup["cards"]:
		cards.append(db.get_card(id))
	return {"cards": cards, "signature": db.get_card(_lineup["signature"]), "loaner": _lineup["loaner"]}


## Saved lineup ids: {cards: Array[StringName], signature: StringName, loaner: bool} or {}.
func get_saved_lineup_ids() -> Dictionary:
	return _lineup.duplicate(true)


func clear_lineup() -> void:
	_lineup = {}
	_commit()

# --- Lobby Duel save / resume -----------------------------------------------------------

## Saves the in-progress Lobby Duel ("Save & leave"). state: the rules engine's WallState.
## meta (optional): rival_id, elapsed_s, player (the player's WallState index, default P1),
## and the lineup (lineup, signature, loaner) when duel_lineup_locked wasn't emitted.
## Returns false when the duel is over or can't be encoded.
func save_lobby_duel(state: WallState, meta: Dictionary = {}) -> bool:
	if state == null or state.is_game_over():
		return false
	var lineup: Array = meta.get("lineup", _duel.get("lineup", []))
	_lobby_duel = {
		"saved_at": Time.get_unix_time_from_system(),
		"rival_id": String(meta.get("rival_id", _duel.get("rival_id", &""))),
		"elapsed_s": SaveFile.to_float(meta.get("elapsed_s", 0.0)),
		"player": SaveFile.to_int(meta.get("player", WallState.P1)),
		"lineup": lineup.map(func(id: Variant) -> String: return str(id)),
		"signature": str(meta.get("signature", _duel.get("signature", &""))),
		"loaner": bool(meta.get("loaner", _duel.get("loaner", false))),
		"lineup_known": not lineup.is_empty(),
		"state": WallStateCodec.encode(state),
	}
	EventBus.lobby_duel_saved.emit(true)
	_commit()
	return true


func has_saved_lobby_duel() -> bool:
	return not _lobby_duel.is_empty()


## Summary for the hub's "Resume" button: {rival_id, placements, age_s, elapsed_s} or {}.
func saved_lobby_duel_info() -> Dictionary:
	if _lobby_duel.is_empty():
		return {}
	var st: Dictionary = _lobby_duel["state"]
	return {
		"rival_id": StringName(_lobby_duel["rival_id"]), "placements": SaveFile.to_int(st.get("placements")),
		"age_s": maxf(Time.get_unix_time_from_system() - SaveFile.to_float(_lobby_duel["saved_at"]), 0.0),
		"elapsed_s": SaveFile.to_float(_lobby_duel["elapsed_s"]),
	}


## Restores the saved Lobby Duel and makes it the duel in progress (so its end counts for
## unlocks). Returns {state: WallState, rival_id, player, lineup: Array[StringName], signature,
## loaner, elapsed_s, age_s}, or {} when nothing is saved or it no longer decodes (then it is
## dropped). The save stays until the duel ends (duel_ended) or clear_lobby_duel(), so a reload
## mid-resume still finds it. The caller emits EventBus.duel_resumed(age_s), not duel_started.
func resume_lobby_duel() -> Dictionary:
	if _lobby_duel.is_empty():
		return {}
	var state: WallState = _decode_lobby_state(_lobby_duel)
	if state == null:
		push_warning("Collection: saved Lobby Duel can't be restored (%s); dropped." % WallStateCodec.last_error)
		clear_lobby_duel()
		return {}
	var lineup: Array[StringName] = SaveFile.to_id_list(_lobby_duel["lineup"])
	_duel = {
		"source": SOURCE_LOBBY, "rival_id": StringName(_lobby_duel["rival_id"]),
		"lineup": lineup, "signature": StringName(_lobby_duel["signature"]),
		"loaner": _lobby_duel["loaner"], "lineup_known": _lobby_duel["lineup_known"],
	}
	var info: Dictionary = saved_lobby_duel_info()
	return {
		"state": state, "rival_id": _duel["rival_id"], "player": SaveFile.to_int(_lobby_duel["player"]),
		"lineup": lineup.duplicate(), "signature": _duel["signature"], "loaner": _duel["loaner"],
		"elapsed_s": info["elapsed_s"], "age_s": info["age_s"],
	}


func clear_lobby_duel() -> void:
	if _lobby_duel.is_empty():
		return
	_lobby_duel = {}
	EventBus.lobby_duel_saved.emit(false)
	_commit()

# --- Stats ---------------------------------------------------------------------------------

## Copy of the duel stats: duels, wins, losses, draws, captures, carded, streak, best_streak,
## rival_wins {rival: n}, rival_wins_no_legend {rival: n}.
func stats() -> Dictionary:
	return _stats.duplicate(true)

# --- Save / load ---------------------------------------------------------------------------

## Writes the save. Returns true on success.
func save() -> bool:
	return SaveFile.write_json(save_path, to_save_dict())


## The save file's content (schema SCHEMA_VERSION).
func to_save_dict() -> Dictionary:
	var dossiers: Dictionary = {}
	for id: StringName in _dossiers:
		dossiers[String(id)] = _dossiers[id].duplicate()
	var titles: Dictionary = {}
	for id: StringName in _titles:
		titles[String(id)] = _titles[id]
	return {
		"schema": SCHEMA_VERSION,
		"game": "banner_wall",
		"saved_at": Time.get_unix_time_from_system(),
		"cards": _sorted_keys(_owned),
		"titles": titles,
		"frames": _sorted_keys(_frames),
		"goals_done": _sorted_keys(_goals_done),
		"sets_done": _sorted_keys(_sets_done),
		"triptychs": _sorted_keys(_triptychs),
		"dossiers": dossiers,
		"stats": _stats.duplicate(true),
		"cipher": _cipher.duplicate(),
		"lineup": null if _lineup.is_empty() else {
			"cards": (_lineup["cards"] as Array).map(func(id: StringName) -> String: return String(id)),
			"signature": String(_lineup["signature"]), "loaner": _lineup["loaner"]},
		"lobby_duel": null if _lobby_duel.is_empty() else _lobby_duel.duplicate(true),
	}


## Loads save_path (or starts the demo). Never fails: see load_status for what happened.
func load_save() -> StringName:
	_reset_state()
	_duel = {}
	lobby_duel_dropped = false
	_grant_starting_cards()
	var read: Dictionary = SaveFile.read_json(save_path)
	match read["status"]:
		SaveFile.MISSING:
			load_status = STATUS_NEW
		SaveFile.CORRUPT:
			push_warning("Collection: save %s is unreadable (%s); kept as %s, starting the demo fresh." % [
					save_path, read["error"], _backup_path("corrupt")])
			SaveFile.copy_file(save_path, _backup_path("corrupt"))
			load_status = STATUS_CORRUPT
		_:
			var data: Dictionary = read["data"]
			var schema: int = SaveFile.to_int(data.get("schema"), 0)
			if schema > SCHEMA_VERSION:
				push_warning("Collection: save schema %d is newer than %d; backed up, reading known fields." % [schema, SCHEMA_VERSION])
				SaveFile.copy_file(save_path, _backup_path("v%d" % schema))
				load_status = STATUS_NEWER
			elif schema < SCHEMA_VERSION:
				data = _migrate(data, schema)
				load_status = STATUS_MIGRATED
			else:
				load_status = STATUS_LOADED
			_apply_save(data)
	# Data may have changed since the save: starting cards stay owned, met goals keep their cards.
	_evaluate_goals(false)
	_check_sets(false)
	_prime_progress()
	if load_status in [STATUS_MIGRATED, STATUS_CORRUPT] or lobby_duel_dropped:
		if autosave:
			save()
	EventBus.collection_changed.emit()
	return load_status


## "Reset demo" for testers: back to the demo start, saved Lobby Duel and lineup included.
func reset_demo() -> void:
	_reset_state()
	_duel = {}
	_grant_starting_cards()
	_check_sets(false)
	_prime_progress()
	if autosave:
		save()
	EventBus.collection_reset.emit()
	EventBus.collection_changed.emit()

# --- EventBus handlers ------------------------------------------------------------------------

func _connect_bus() -> void:
	EventBus.duel_started.connect(_on_duel_started)
	EventBus.duel_lineup_locked.connect(_on_duel_lineup_locked)
	EventBus.card_captured.connect(_on_card_captured)
	EventBus.carded.connect(_on_carded)
	EventBus.triptych_scored.connect(_on_triptych_scored)
	EventBus.duel_ended.connect(_on_duel_ended)
	EventBus.dossier_cleared.connect(_on_dossier_cleared)
	EventBus.dossier_completed.connect(_on_dossier_completed)


func _on_duel_started(source: StringName, rival_id: StringName, _first_player: StringName) -> void:
	if not listening:
		return
	_duel = {"source": source, "rival_id": rival_id, "lineup": [],
			"signature": &"", "loaner": false, "lineup_known": false}


func _on_duel_lineup_locked(card_ids: Array, signature_id: StringName, loaner: bool) -> void:
	if not listening:
		return
	if _duel.is_empty():
		_duel = {"source": &"", "rival_id": &""}
	_duel["lineup"] = SaveFile.to_id_list(card_ids)
	_duel["signature"] = signature_id
	_duel["loaner"] = loaner
	_duel["lineup_known"] = true


func _on_card_captured(by_side: StringName, _card_id: StringName, _slot: StringName) -> void:
	if not listening or by_side != PLAYER or _in_dossier():
		return
	_stats["captures"] += 1
	_evaluate_goals()
	_commit()


func _on_carded(by_side: StringName, _card_id: StringName) -> void:
	if not listening or by_side != PLAYER or _in_dossier():
		return
	_stats["carded"] += 1
	_commit()


func _on_triptych_scored(side: StringName, triptych_id: StringName, _first_time: bool) -> void:
	if not listening or side != PLAYER:
		return
	record_triptych(triptych_id)


func _on_duel_ended(result: StringName, _player_score: int, _rival_score: int, _turns: int, _duration_s: float) -> void:
	if not listening:
		return
	if _in_dossier():
		_duel = {}
		return
	_record_duel_result(result, _duel.get("rival_id", &""), _duel_has_no_legend())
	if _duel.get("source", &"") == SOURCE_LOBBY and not _lobby_duel.is_empty():
		_lobby_duel = {}
		EventBus.lobby_duel_saved.emit(false)
	_duel = {}
	_evaluate_goals()
	_commit()


func _on_dossier_cleared(dossier_id: StringName, attempts: int, duration_s: float) -> void:
	if not listening:
		return
	record_dossier_clear(dossier_id, attempts, duration_s)

func _on_dossier_completed(dossier_id: StringName) -> void:
	if not listening:
		return
	complete_dossier(dossier_id)

# --- Progress ----------------------------------------------------------------------------------

## Counts one finished duel (not a Dossier). no_legend: the player's lineup is known and holds
## no Clearance 4 card. Wins against a rival are counted in total, not in a row.
func _record_duel_result(result: StringName, rival_id: StringName, no_legend: bool) -> void:
	_stats["duels"] += 1
	match result:
		&"win":
			_stats["wins"] += 1
			_stats["streak"] += 1
			_stats["best_streak"] = maxi(_stats["best_streak"], _stats["streak"])
			if rival_id != &"":
				var key: String = String(rival_id)
				_stats["rival_wins"][key] = int(_stats["rival_wins"].get(key, 0)) + 1
				if no_legend:
					_stats["rival_wins_no_legend"][key] = int(_stats["rival_wins_no_legend"].get(key, 0)) + 1
		&"loss":
			_stats["losses"] += 1
			_stats["streak"] = 0
		_:
			_stats["draws"] += 1
			_stats["streak"] = 0


## Current value of a goal's counter (not capped).
func _goal_value(goal: UnlockGoal) -> int:
	var rival: String = String(goal.target_id)
	match goal.kind:
		DataEnums.UnlockKind.WIN_STREAK:
			return _stats["streak"]
		DataEnums.UnlockKind.CAPTURES_TOTAL:
			return _stats["captures"]
		DataEnums.UnlockKind.WINS_TOTAL:
			return _stats["wins"]
		DataEnums.UnlockKind.BEAT_RIVAL:
			return int(_stats["rival_wins"].get(rival, 0))
		DataEnums.UnlockKind.BEAT_RIVAL_NO_LEGEND:
			return int(_stats["rival_wins_no_legend"].get(rival, 0))
		DataEnums.UnlockKind.DOSSIER_CLEAR:
			return 1 if _dossiers.has(goal.target_id) else 0
		DataEnums.UnlockKind.CIPHER_LOCK:
			return 1 if is_cipher_solved() else 0
	return 0


## Completes every goal whose counter reached its target and grants its cards. With announce,
## emits unlock_progress for changed counters and the unlock signals.
func _evaluate_goals(announce: bool = true) -> void:
	var db: Node = _db()
	if db == null:
		return
	for goal: UnlockGoal in db.all_unlock_goals():
		var done: bool = _goals_done.has(goal.id)
		if not done:
			var value: int = _goal_value(goal)
			var target: int = goal.required_count()
			if value >= target:
				_goals_done[goal.id] = true
				done = true
				if announce:
					EventBus.unlock_goal_completed.emit(goal.id)
			elif announce and _last_progress.get(goal.id, -1) != value:
				EventBus.unlock_progress.emit(goal.id, value, target)
			_last_progress[goal.id] = value
		if done:
			for card: CardData in db.cards_unlocked_by(goal.id):
				if not _owned.has(card.id):
					_grant_card(card.id, goal.id, announce)


func _prime_progress() -> void:
	_last_progress.clear()
	var db: Node = _db()
	if db == null:
		return
	for goal: UnlockGoal in db.all_unlock_goals():
		_last_progress[goal.id] = _goal_value(goal)


func _grant_card(card_id: StringName, source_id: StringName, announce: bool = true) -> void:
	if _owned.has(card_id):
		return
	_owned[card_id] = true
	if announce:
		EventBus.card_unlocked.emit(card_id, source_id)
		EventBus.unlocked.emit(&"card", card_id)
	_check_sets(announce)


func _grant_title(title_id: StringName, text: String, announce: bool = true) -> void:
	if text.strip_edges().is_empty() or _titles.has(title_id):
		return
	_titles[title_id] = text
	if announce:
		EventBus.title_earned.emit(title_id, text)
		EventBus.unlocked.emit(&"title", title_id)


func _grant_frame(frame_id: StringName, announce: bool = true) -> void:
	if frame_id == &"" or _frames.has(frame_id):
		return
	_frames[frame_id] = true
	if announce:
		EventBus.frame_earned.emit(frame_id)
		EventBus.unlocked.emit(&"frame", frame_id)


## Completes sets the player now fully owns: title (completion_title) + animated set frame.
## Showcase (store) sets are skipped: store cards already wear the premium frame.
func _check_sets(announce: bool) -> void:
	var db: Node = _db()
	if db == null:
		return
	for s: SetData in db.all_sets():
		if _sets_done.has(s.id) or s.kind == DataEnums.SetKind.SHOWCASE:
			continue
		var cards: Array = db.cards_in_set(s.id)
		if cards.is_empty() or cards.any(func(c: CardData) -> bool: return not _owned.has(c.id)):
			continue
		_sets_done[s.id] = true
		if announce:
			EventBus.set_completed.emit(s.id)
		_grant_title(StringName("set_%s" % s.id), s.completion_title, announce)
		_grant_frame(set_frame_id(s.id), announce)


func _grant_starting_cards() -> void:
	var db: Node = _db()
	if db == null:
		return
	for c: CardData in db.starting_cards():
		_owned[c.id] = true

# --- Internals ---------------------------------------------------------------------------------

func _commit() -> void:
	if autosave:
		save()
	EventBus.collection_changed.emit()


func _in_dossier() -> bool:
	return _duel.get("source", &"") == SOURCE_DOSSIER


func _duel_has_no_legend() -> bool:
	if not _duel.get("lineup_known", false):
		return false
	var db: Node = _db()
	for id: StringName in _duel.get("lineup", []):
		var c: CardData = db.get_card(id) if db != null else null
		if c == null or c.is_legend():
			return false
	return true


func _db() -> Node:
	return get_node_or_null("/root/CardDB") if is_inside_tree() else null


func _backup_path(tag: String) -> String:
	return "%s.%s.json" % [save_path.get_basename(), tag]


static func _new_stats() -> Dictionary:
	return {"duels": 0, "wins": 0, "losses": 0, "draws": 0, "captures": 0, "carded": 0,
			"streak": 0, "best_streak": 0, "rival_wins": {}, "rival_wins_no_legend": {}}


func _reset_state() -> void:
	for d: Dictionary in [_owned, _titles, _frames, _goals_done, _sets_done, _triptychs, _dossiers, _last_progress]:
		d.clear()
	_stats = _new_stats()
	_cipher = {"solved": false, "attempts": 0}
	_lineup = {}
	_lobby_duel = {}


static func _sorted_keys(d: Dictionary) -> Array:
	var out: Array = d.keys().map(func(k: Variant) -> String: return String(k))
	out.sort()
	return out


## Upgrades an older save to SCHEMA_VERSION. Schema 0 = no "schema" field (cc01 stub, never
## written in practice): same field names, so the type-checked reader in _apply_save is enough.
## Add one step per future schema bump here.
func _migrate(data: Dictionary, from_schema: int) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	if from_schema < 1:
		d["schema"] = 1
	return d


## Reads a save Dictionary field by field. Anything of the wrong type is ignored; unknown card,
## set, Triptych and Dossier ids are dropped (data renamed); a Lobby Duel that no longer
## decodes is dropped (lobby_duel_dropped).
func _apply_save(data: Dictionary) -> void:
	var db: Node = _db()
	for id: StringName in SaveFile.to_id_list(data.get("cards")):
		if db == null or db.has_card(id):
			_owned[id] = true
	var titles: Dictionary = SaveFile.to_dict(data.get("titles"))
	for k: Variant in titles:
		if titles[k] is String and not String(titles[k]).is_empty():
			_titles[StringName(str(k))] = titles[k]
	for id: StringName in SaveFile.to_id_list(data.get("frames")):
		_frames[id] = true
	for id: StringName in SaveFile.to_id_list(data.get("goals_done")):
		if db == null or db.get_unlock_goal(id) != null:
			_goals_done[id] = true
	for id: StringName in SaveFile.to_id_list(data.get("sets_done")):
		if db == null or db.get_set(id) != null:
			_sets_done[id] = true
	for id: StringName in SaveFile.to_id_list(data.get("triptychs")):
		if db == null or db.get_triptych(id) != null:
			_triptychs[id] = true
	var dossiers: Dictionary = SaveFile.to_dict(data.get("dossiers"))
	for k: Variant in dossiers:
		var id: StringName = StringName(str(k))
		if db != null and db.get_dossier(id) == null:
			continue
		var rec: Dictionary = SaveFile.to_dict(dossiers[k])
		_dossiers[id] = {"attempts": maxi(SaveFile.to_int(rec.get("attempts"), 1), 1),
				"best_s": maxf(SaveFile.to_float(rec.get("best_s")), 0.0)}
	var st: Dictionary = SaveFile.to_dict(data.get("stats"))
	for key: String in ["duels", "wins", "losses", "draws", "captures", "carded", "streak", "best_streak"]:
		_stats[key] = maxi(SaveFile.to_int(st.get(key)), 0)
	for key: String in ["rival_wins", "rival_wins_no_legend"]:
		var src: Dictionary = SaveFile.to_dict(st.get(key))
		for rival: Variant in src:
			var n: int = SaveFile.to_int(src[rival])
			if n > 0:
				_stats[key][str(rival)] = n
	var ci: Dictionary = SaveFile.to_dict(data.get("cipher"))
	_cipher = {"solved": SaveFile.to_bool(ci.get("solved")), "attempts": maxi(SaveFile.to_int(ci.get("attempts")), 0)}
	_apply_lineup(SaveFile.to_dict(data.get("lineup")))
	var ld: Dictionary = SaveFile.to_dict(data.get("lobby_duel"))
	if not ld.is_empty():
		var snap: Dictionary = {
			"saved_at": SaveFile.to_float(ld.get("saved_at")), "rival_id": str(ld.get("rival_id", "")),
			"elapsed_s": maxf(SaveFile.to_float(ld.get("elapsed_s")), 0.0),
			"player": SaveFile.to_int(ld.get("player"), WallState.P1),
			"lineup": SaveFile.to_id_list(ld.get("lineup")).map(func(id: StringName) -> String: return String(id)),
			"signature": str(ld.get("signature", "")), "loaner": SaveFile.to_bool(ld.get("loaner")),
			"lineup_known": SaveFile.to_bool(ld.get("lineup_known")),
			"state": SaveFile.to_dict(ld.get("state")),
		}
		if _decode_lobby_state(snap) != null:
			_lobby_duel = snap
		else:
			push_warning("Collection: saved Lobby Duel no longer loads (%s); dropped." % WallStateCodec.last_error)
			lobby_duel_dropped = true


## Keeps a saved lineup only while it is still legal for the current data and collection
## (a loaner lineup skips the ownership check).
func _apply_lineup(ld: Dictionary) -> void:
	if ld.is_empty():
		return
	var db: Node = _db()
	if db == null:
		return
	var ids: Array[StringName] = SaveFile.to_id_list(ld.get("cards"))
	var loaner: bool = SaveFile.to_bool(ld.get("loaner"))
	var cards: Array = ids.map(func(id: StringName) -> Variant: return db.get_card(id))
	var sig: CardData = db.get_card(StringName(str(ld.get("signature", ""))))
	var owned: Array[StringName] = []
	owned.assign(_owned.keys())
	var check: Dictionary = LineupRules.validate(cards, [sig] if sig != null else [],
			null if loaner else owned, db.get_balance())
	if check["valid"]:
		_lineup = {"cards": ids, "signature": sig.id, "loaner": loaner}


func _decode_lobby_state(snap: Dictionary) -> WallState:
	var db: Node = _db()
	if db == null:
		return null
	var trips: Array[TriptychData] = []
	trips.assign(db.all_triptychs())
	return WallStateCodec.decode(snap.get("state"), Callable(db, "get_card"), db.get_balance(), trips)

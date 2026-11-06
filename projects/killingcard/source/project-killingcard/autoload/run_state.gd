# run_state.gd
# Purpose: RunState autoload. Thin owner of the current run (a RunProgress from
#   scripts/run/, where all the run rules live): starts / continues / ends runs,
#   saves after every change to user://run_save.json so a run survives a browser
#   reload, and announces changes on EventBus. Screens (p11) and the match scene
#   call the methods below and read `run`; they never edit `run` directly.
#
#   Typical flow:
#     RunState.start_run()                       # or continue_run() if has_save()
#     RunState.set_killstreaks([...]); RunState.begin_run()
#     var m := RunState.create_match(hooks)      # then m.start_match() and play it
#     RunState.finish_match(m)                   # tickets, offers, run end
#     while RunState.current_offer(): RunState.choose_offer(i)  # or skip_offer()
#   A reload mid-match restarts that match from the same seed (same draws).
# Dependencies: EventBus, CardDB, RunConfig, RunProgress, RunSave, MatchState, MatchHooks.
# Author: Mechanics Developer Agent
extends Node

## Emitted after every change to the run (start, picks, results, offers, end, reset).
signal run_changed

const SAVE_PATH: String = "user://run_save.json"
const RUN_CONFIG_PATH: String = "res://data/run_config.tres"

## Where the run is saved (tests point this elsewhere).
var save_path: String = SAVE_PATH
## Save after every change.
var autosave: bool = true
var config: RunConfig = null
## The current run, or null.
var run: RunProgress = null
## Set when a save could not be loaded and the run started fresh (for a notice on screen).
var last_load_warning: String = ""

## Read-only views kept from the p01 stub (values come from RunConfig when no run is active).
var active: bool:
	get: return run != null and not run.is_over()
var match_index: int:
	get: return run.match_index if run != null else 0
var matches_total: int:
	get: return _config().match_count()
var tickets: int:
	get: return run.tickets if run != null else _config().tickets
var deck: Array[StringName]:
	get: return run.deck if run != null else _starter_deck_ids()
var killstreak_picks: Array[StringName]:
	get: return run.killstreaks if run != null else _starter_killstreak_ids()

var _session_start_ms: int = 0


func _ready() -> void:
	_config()


# =============================================================================
# Run lifecycle
# =============================================================================

## Starts a new run (replacing any saved one). seed < 0 picks a random seed.
func start_run(seed_value: int = -1) -> RunProgress:
	var s: int = seed_value
	if s < 0 and OS.has_feature("web"):
		# Browser smoke tests replay a run with ?qa=1&seed=N (scripts/qa/qa_bridge.gd).
		s = (load("res://scripts/qa/qa_bridge.gd") as GDScript).call(&"url_seed")
	if s < 0:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.randomize()
		s = rng.randi()
	run = RunProgress.create(_config(), s)
	# kc-ui4: the Operator last picked on the starter screen (Settings.operator_primary) is the default.
	var st: Node = get_node_or_null(^"/root/Settings")
	var pref: String = String(st.get(&"operator_primary")) if st != null else ""
	if pref != "" and pref != String(run.primary):
		run.set_primary(StringName(pref))
	# kc-art-traits: the starter's Recruits wear the Codex EQUIP arts (Settings.equipped_arts).
	run.set_equipped_arts(_equipped_arts())
	_session_start_ms = Time.get_ticks_msec()
	last_load_warning = ""
	_changed()
	EventBus.run_started.emit(s)
	EventBus.tickets_changed.emit(run.tickets)
	return run


## Loads the saved run. A corrupt or incompatible save is moved aside with a
## warning (last_load_warning) and false is returned, so the caller starts fresh.
func continue_run() -> bool:
	var loaded: Dictionary = RunSave.read(save_path, _config())
	if loaded["run"] == null:
		if not loaded["missing"]:
			last_load_warning = "Saved run could not be loaded (%s); starting fresh." % loaded["error"]
			push_warning("RunState: " + last_load_warning)
			RunSave.quarantine(save_path)
		run = null
		run_changed.emit()
		return false
	run = loaded["run"]
	# kc-trait-ui (head): with random copy arts the run ignores Codex EQUIP (set_equipped_arts).
	run.set_equipped_arts(_equipped_arts())
	last_load_warning = ""
	_session_start_ms = Time.get_ticks_msec()
	run_changed.emit()
	EventBus.tickets_changed.emit(run.tickets)
	return true


## Drops the current run and its save.
func abandon_run() -> void:
	run = null
	RunSave.delete(save_path)
	run_changed.emit()


## Clears the in-memory run (the save stays). Used by tests and the title screen.
func reset() -> void:
	run = null
	last_load_warning = ""
	run_changed.emit()


## True when a saved run exists on disk.
func has_save() -> bool:
	return RunSave.exists(save_path)


func save_run() -> Error:
	if run == null:
		return ERR_DOES_NOT_EXIST
	_add_play_time()
	var err: Error = RunSave.write(save_path, run)
	if err != OK:
		push_warning("RunState: could not save the run to %s (%s)" % [save_path, error_string(err)])
	return err


# =============================================================================
# Loadout
# =============================================================================

func set_killstreaks(ids: Array) -> String:
	if run == null:
		return "no run"
	var err: String = run.set_killstreaks(ids)
	if err == "":
		_changed()
	return err


## kc-ui4: the starting Operator (a Primary id from RunProgress.operator_options), loadout only.
func set_primary(id: StringName) -> String:
	if run == null:
		return "no run"
	var err: String = run.set_primary(id)
	if err == "":
		_changed()
	return err


func begin_run() -> String:
	if run == null:
		return "no run"
	var err: String = run.begin()
	if err == "":
		_changed()
	return err


# =============================================================================
# Matches
# =============================================================================

## A MatchState for the current match (not started). See RunProgress.create_match.
func create_match(hooks: MatchHooks = null) -> MatchState:
	if run == null:
		return null
	return run.create_match(hooks)


## Records a finished match. Returns RunProgress.record_result's summary.
func finish_match(m: MatchState) -> Dictionary:
	if run == null:
		return {"ok": false, "reason": "no run"}
	return _after_result(run.record_match(m))


## Records a result without a MatchState (debug / forced results).
func record_result(match_result: StringName, outcome: Dictionary = {}) -> Dictionary:
	if run == null:
		return {"ok": false, "reason": "no run"}
	return _after_result(run.record_result(match_result, outcome))


func _after_result(summary: Dictionary) -> Dictionary:
	if not summary["ok"]:
		return summary
	if summary["ticket_lost"]:
		EventBus.tickets_changed.emit(run.tickets)
	if run.is_over():
		_add_play_time()
		_session_start_ms = 0
	_changed()
	if run.is_over():
		EventBus.run_ended.emit(&"win" if run.is_victory() else &"loss", run.matches_played(), run.play_time_s)
	else:
		_announce_offer()
	return summary


# =============================================================================
# Offers
# =============================================================================

func current_offer() -> Dictionary:
	return run.current_offer() if run != null else {}


## kc-art-traits: `trait_pick` = the trait a Recruit trains into on a Promotion (one of
## run.train_choices(copy)); TRAIT_DEFAULT = its pre-selected art's trait.
func choose_offer(index: int, trait_pick: StringName = SynergyRules.TRAIT_DEFAULT) -> String:
	if run == null:
		return "no run"
	var offer: Dictionary = run.current_offer()
	var err: String = run.choose_offer(index, trait_pick)
	if err == "":
		EventBus.reward_picked.emit(offer["kind"], offer["options"][index])
		_changed()
		_announce_offer()
	return err


## kc-syn §5.4: Retire option `index` of run.retire_options() as the current offer's choice
## (the Supply Drop's 4th option or Regroup). Returns "" or the reason.
func retire_card(index: int, twin_trait: StringName = SynergyRules.TRAIT_DEFAULT) -> String:
	if run == null:
		return "no run"
	var options: Array[Dictionary] = run.retire_options()
	var err: String = run.retire_card(index, twin_trait)
	if err == "":
		EventBus.reward_picked.emit(&"retire", options[index]["id"])
		_changed()
		_announce_offer()
	return err


## kc-art-traits §2.2: Re-issue option `index` of run.reissue_options() into `new_trait` as the
## current offer's choice (the Supply Drop's Re-issue next to Retire, or Regroup). "" or the reason.
func reissue_card(index: int, new_trait: StringName) -> String:
	if run == null:
		return "no run"
	var options: Array[Dictionary] = run.reissue_options()
	var err: String = run.reissue_card(index, new_trait)
	if err == "":
		EventBus.reward_picked.emit(&"reissue", options[index]["id"])
		_changed()
		_announce_offer()
	return err


## kc-art-traits §2.2: free same-trait art swap of deck copy `i` (deck view). "" or the reason.
func set_copy_art(i: int, art: StringName) -> String:
	if run == null:
		return "no run"
	var err: String = run.set_copy_art(i, art)
	if err == "":
		_changed()
	return err


func skip_offer() -> String:
	if run == null:
		return "no run"
	var offer: Dictionary = run.current_offer()
	var err: String = run.skip_offer()
	if err == "":
		EventBus.reward_picked.emit(offer["kind"], &"")
		_changed()
		_announce_offer()
	return err


func _announce_offer() -> void:
	var offer: Dictionary = run.current_offer()
	if not offer.is_empty():
		var ids: Array[StringName] = []
		ids.assign(offer["options"])
		EventBus.reward_offered.emit(offer["kind"], ids)


# =============================================================================
# Internals
# =============================================================================

## Settings.equipped_arts (chassis -> art), {} without the autoload.
func _equipped_arts() -> Dictionary:
	var st: Node = get_node_or_null(^"/root/Settings")
	var eq: Variant = st.get(&"equipped_arts") if st != null else null
	return eq if typeof(eq) == TYPE_DICTIONARY else {}


func _changed() -> void:
	if autosave and run != null:
		save_run()
	# kc-trait-ui: every art a copy of the run wears is FOUND in the Codex (Settings.found_arts).
	var st: Node = get_node_or_null(^"/root/Settings")
	if run != null and st != null and st.has_method(&"mark_found"):
		var arts: Array = []
		for i: int in run.deck.size():
			arts.append(run.art_of(i))
		st.mark_found(arts)
	run_changed.emit()


func _add_play_time() -> void:
	if run == null:
		return
	var now: int = Time.get_ticks_msec()
	if _session_start_ms > 0:
		run.play_time_s += (now - _session_start_ms) / 1000.0
		_session_start_ms = now


func _config() -> RunConfig:
	if config == null:
		var db: Node = get_node_or_null("/root/CardDB")
		if db != null:
			config = db.get_run_config()
		if config == null:
			config = load(RUN_CONFIG_PATH) as RunConfig
	return config


func _starter_deck_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for c: CardData in _config().starter_deck:
		if c != null:
			ids.append(c.id)
	return ids


func _starter_killstreak_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for k: LoadoutItem in _config().starter_killstreaks:
		if k != null:
			ids.append(k.id)
	return ids

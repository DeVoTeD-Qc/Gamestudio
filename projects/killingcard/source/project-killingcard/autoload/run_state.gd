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
## kc-onboard §5: a system the player meets for the first time (RevealFlags id). The UI reveals the
## element and, when RevealFlags.is_explained(flag), queues its one-time "New: X" card
## (pending_explainers() / ack_explainer()).
signal system_met(flag: StringName)
## kc-v2-impl (run-v2-api.md): a move, a node resolved or the map rebuilt.
signal map_changed
## The player stepped on a node (the node row of map_view()).
signal node_entered(node: Dictionary)
## REQ changed (after any change; delta = new - old).
signal req_changed(req: int, delta: int)
## A run ended and unlocked these: [{kind: &"operator"|&"boss"|&"modifier", id, name, text}].
signal unlocked(items: Array[Dictionary])

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
## kc-v2-impl: new runs are Run v2 map runs (when the config has run_map). False = the old 5-match
## ladder (old tests, tools).
var run_map_enabled: bool = true
var _last_req: int = 0

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
	var map_run: bool = run_map_enabled and _config().run_map
	if map_run:
		# kc-v2-impl: the first run is the fixed short map against Meridian_Six; later runs draw the boss
		# from the unlocked ones, never last run's (V3).
		var p: Dictionary = profile()
		var brng: RandomNumberGenerator = RandomNumberGenerator.new()
		brng.seed = RunProgress.derive_seed(s, "boss", 0)
		run = RunProgress.create_map_run(_config(), s, {"first_run": RunProfile.is_first_run(p),
				"boss": RunProfile.pick_boss(p, _config(), brng)})
	else:
		run = RunProgress.create(_config(), s)
	# kc-ui4: the Operator last picked on the starter screen (Settings.operator_primary) is the default.
	var st: Node = get_node_or_null(^"/root/Settings")
	var pref: String = String(st.get(&"operator_primary")) if st != null else ""
	if pref != "" and pref != String(run.primary) and (not map_run or _operator_unlocked(StringName(pref))):
		run.set_primary(StringName(pref))
	_last_req = run.req
	# kc-art-traits: new copies are pre-selected in the Codex EQUIP arts (Settings.equipped_arts).
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
	var loaded: Dictionary = RunSave.read(save_path, _config(), {"map": run_map_enabled and _config().run_map})
	if loaded["run"] == null:
		if not loaded["missing"]:
			last_load_warning = "Saved run could not be loaded (%s); starting fresh." % loaded["error"]
			push_warning("RunState: " + last_load_warning)
			RunSave.quarantine(save_path)
		run = null
		run_changed.emit()
		return false
	run = loaded["run"]
	_last_req = run.req
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
	if run.map != null and not _operator_unlocked(id):
		return "that Operator is locked"
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
		if run.map != null:
			map_changed.emit()
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
	if run.map != null and m != null:
		_save_profile(RunProfile.record_match(profile(), m.terrain, m.boss_id))
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
	if run.map != null:
		map_changed.emit()
	if run.is_over():
		_on_run_ended()
		EventBus.run_ended.emit(&"win" if run.is_victory() else &"loss", run.matches_played(), run.play_time_s)
	else:
		_announce_offer()
	return summary


# =============================================================================
# Offers
# =============================================================================

func current_offer() -> Dictionary:
	return run.current_offer() if run != null else {}


## Takes option `index` of the current offer. Returns "" or the reason.
func choose_offer(index: int) -> String:
	if run == null:
		return "no run"
	var offer: Dictionary = run.current_offer()
	var kind: StringName = offer.get("kind", &"")
	var opts: Array = offer.get("options", [])
	var chosen: StringName = StringName(opts[index]) if index >= 0 and index < opts.size() else &""
	var err: String = run.choose_offer(index)
	if err == "":
		EventBus.reward_picked.emit(kind, chosen)
		_changed()
		_announce_offer()
	return err


## kc-syn §5.4: Retire option `index` of run.retire_options() as the current offer's choice
## (the Supply Drop's 4th option or Regroup). Returns "" or the reason.
func retire_card(index: int) -> String:
	if run == null:
		return "no run"
	var options: Array[Dictionary] = run.retire_options()
	var err: String = run.retire_card(index)
	if err == "":
		EventBus.reward_picked.emit(&"retire", options[index]["id"])
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


## kc-onboard §4.3: sends Standard Issue copies `indices` (deck indices, see
## run.muster_out_options()) home as the current Muster out's choice. "" or the reason.
func muster_out(indices: Array) -> String:
	if run == null:
		return "no run"
	var err: String = run.muster_out(indices)
	if err == "":
		EventBus.reward_picked.emit(RewardOffers.KIND_MUSTER_OUT, &"")
		_changed()
		_announce_offer()
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
# kc-v2-impl: Run v2 (map, events, shop, rest, Operators, modifiers, profile).
# API for the screens: documentation/technical/run-v2-api.md
# =============================================================================

## The between-runs profile (RunProfile, stored in Settings.run_profile).
func profile() -> Dictionary:
	var st: Node = get_node_or_null(^"/root/Settings")
	var p: Variant = st.get(&"run_profile") if st != null else _profile_fallback
	return RunProfile.normalised(p)


func _save_profile(p: Dictionary) -> void:
	var st: Node = get_node_or_null(^"/root/Settings")
	if st != null and st.has_method(&"set_value"):
		st.set_value(&"run_profile", p)
	else:
		_profile_fallback = p


var _profile_fallback: Dictionary = {}


func profile_view() -> Dictionary:
	return profile()


## Every Operator with its kit and lock state (Kestrel, Longreach, Wasp-9, Bastion-60 first).
func operator_choices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p: Dictionary = profile()
	var first: bool = RunProfile.is_first_run(p)
	for item: LoadoutItem in _operator_items():
		var ab: LoadoutItem = item.ability as LoadoutItem
		var unlocked: bool = RunProfile.is_unlocked(p, item.unlock) and (not first or item.unlock == &"")
		var kws: Array[String] = []
		if item.first_shot:
			kws.append("First Shot")
		if item.pick:
			kws.append("Pick")
		if item.flank:
			kws.append("Flank")
		if item.pierce or item.weapon_class == DataEnums.WeaponClass.LMG:
			kws.append("Pierce")
		if item.cover > 0:
			kws.append("Cover %d" % item.cover)
		if item.rotations_per_round > 1:
			kws.append("%d Rotations" % item.rotations_per_round)
		out.append({"id": item.id, "name": item.display_name,
				"weapon": String(DataEnums.key_of(DataEnums.WeaponClass, item.weapon_class)),
				"fp": item.operator_firepower, "armor": item.operator_armor, "keywords": kws,
				"passive_name": item.passive_name, "passive_text": item.passive_text,
				"ability_id": ab.id if ab != null else &"", "ability_name": ab.display_name if ab != null else "",
				"ability_text": ab.text if ab != null else "", "unlocked": unlocked,
				"unlock_text": RunProfile.unlock_text(item.unlock), "unlock": item.unlock,
				"selected": run != null and run.primary == item.id})
	return out


const OPERATOR_ORDER: Array[StringName] = [&"kestrel_ar7", &"longreach_338", &"wasp_9", &"bastion_60"]


func _operator_items() -> Array[LoadoutItem]:
	var items: Array[LoadoutItem] = []
	for item: LoadoutItem in RunProgress.operator_options(_config()):
		if item.ability != null or item.id in OPERATOR_ORDER:
			items.append(item)
	items.sort_custom(func(a: LoadoutItem, b: LoadoutItem) -> bool:
		var ia: int = OPERATOR_ORDER.find(a.id)
		var ib: int = OPERATOR_ORDER.find(b.id)
		return (ia if ia >= 0 else 99) < (ib if ib >= 0 else 99))
	return items


func _operator_unlocked(id: StringName) -> bool:
	for row: Dictionary in operator_choices():
		if row["id"] == id:
			return row["unlocked"]
	return false


func modifier_choices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p: Dictionary = profile()
	for id: StringName in RunModifiers.ALL:
		var t: Dictionary = RunModifiers.TABLE[id]
		out.append({"id": id, "name": t["name"], "threat": t["threat"], "text": t["text"],
				"unlocked": RunProfile.is_unlocked(p, t["unlock"]), "unlock_text": t["unlock_text"],
				"on": run != null and id in run.modifiers})
	return out


func set_modifiers(ids: Array) -> String:
	if run == null:
		return "no run"
	var allowed: Array = []
	for row: Dictionary in modifier_choices():
		if row["unlocked"]:
			allowed.append(row["id"])
	var err: String = run.set_modifiers(ids, allowed)
	if err == "":
		map_changed.emit()
		_changed()
	return err


func map_view() -> Dictionary:
	return run.map_view() if run != null else {}


func current_node() -> Dictionary:
	if run == null or run.map == null or run.map.current == &"":
		return {}
	return run.node_view(run.map.current)


func move_to(node_id: StringName) -> String:
	if run == null:
		return "no run"
	var err: String = run.move_to(node_id)
	if err == "":
		var n: Dictionary = current_node()
		if n.get("type", &"") == RunMap.TYPE_EVENT:
			_save_profile(RunProfile.record_event(profile(), StringName(n["event"]["id"])))
		_changed()
		map_changed.emit()
		node_entered.emit(n)
	return err


func event_view() -> Dictionary:
	return RunEvents.view(run) if run != null else {}


func choose_event(index: int, args: Dictionary = {}) -> Dictionary:
	if run == null:
		return {"ok": false, "reason": "no run", "text": "", "changes": {}}
	var res: Dictionary = RunEvents.choose(run, index, args)
	if res["ok"]:
		if int(res["changes"].get("tickets", 0)) != 0:
			EventBus.tickets_changed.emit(run.tickets)
		_after_node()
	return res


func shop_view() -> Dictionary:
	return RunShop.view(run) if run != null else {}


func shop_buy(slot: int) -> String:
	return _shop_action(func() -> String: return RunShop.buy(run, slot))


func shop_buy_perk(index: int) -> String:
	return _shop_action(func() -> String: return RunShop.buy_perk(run, index))


func shop_muster_out(deck_index: int) -> String:
	return _shop_action(func() -> String: return RunShop.muster_out(run, deck_index))


func shop_discharge(deck_index: int) -> String:
	return _shop_action(func() -> String: return RunShop.discharge(run, deck_index))


func shop_restock() -> String:
	return _shop_action(func() -> String: return RunShop.restock(run))


func _shop_action(action: Callable) -> String:
	if run == null:
		return "no run"
	var err: String = action.call()
	if err == "":
		_changed()
	return err


func leave_node() -> String:
	if run == null:
		return "no run"
	var err: String = run.leave_node()
	if err == "":
		_after_node()
	return err


func rest_view() -> Dictionary:
	return RunShop.rest_view(run) if run != null else {}


func rest_choose(id: StringName, args: Dictionary = {}) -> String:
	if run == null:
		return "no run"
	var t0: int = run.tickets
	var err: String = RunShop.rest_choose(run, id, args)
	if err == "":
		if run.tickets != t0:
			EventBus.tickets_changed.emit(run.tickets)
		_after_node()
	return err


## A node resolved: save, the map changed, the offer it queued (if any), or the run end.
func _after_node() -> void:
	_changed()
	map_changed.emit()
	if run.is_over():
		_on_run_ended()
	else:
		_announce_offer()


## The run just ended: the profile counts it and the unlocks it earned are announced.
func _on_run_ended() -> void:
	if run == null or run.map == null:
		return
	var ops: Array = []
	for item: LoadoutItem in _operator_items():
		ops.append({"id": item.id, "name": item.display_name, "unlock": item.unlock,
				"text": item.passive_name + ": " + item.passive_text})
	var bosses: Array = []
	for b: RunMatchData in _config().bosses:
		if b != null:
			bosses.append({"id": b.boss_id, "name": b.squad.display_name if b.squad != null else "", "unlock": b.unlock,
					"text": b.boss_rule_name + ": " + BossRules.format_text(_config(), b.boss_rule, b.boss_rule_text)})
	var res: Dictionary = RunProfile.record_run_end(profile(), run, ops, bosses)
	_save_profile(res["profile"])
	var items: Array[Dictionary] = []
	items.assign(res["unlocked"])
	if not items.is_empty():
		if items.any(func(i: Dictionary) -> bool: return i["kind"] == &"modifier"):
			note_systems([RevealFlags.MODIFIERS])
		unlocked.emit(items)


# =============================================================================
# Internals
# =============================================================================

## Settings.equipped_arts (chassis -> art), {} without the autoload.
func _equipped_arts() -> Dictionary:
	var st: Node = get_node_or_null(^"/root/Settings")
	var eq: Variant = st.get(&"equipped_arts") if st != null else null
	return eq if typeof(eq) == TYPE_DICTIONARY else {}


# =============================================================================
# kc-onboard §5: progressive reveal (profile flags in Settings, RevealFlags)
# =============================================================================

## Records systems the player meets (RevealFlags ids, e.g. RevealFlags.match_triggers(m) after a
## Reveal, or &"killstreaks" when the first killstreak is earned). Emits system_met for each new one
## and returns them. Without the Settings autoload nothing is stored.
func note_systems(flags: Array) -> Array[StringName]:
	var st: Node = get_node_or_null(^"/root/Settings")
	var added: Array[StringName] = []
	if st == null or not st.has_method(&"meet"):
		return added
	added = st.meet(flags)
	for f: StringName in added:
		system_met.emit(f)
	return added


## True once the player has met `flag` (the UI shows the element; RevealFlags.visible adds "in use now").
func has_met(flag: StringName) -> bool:
	var st: Node = get_node_or_null(^"/root/Settings")
	return st != null and st.has_method(&"has_met") and st.has_met(flag)


## The "New: X" cards still to show, in order (show one per screen; RevealFlags.text_of(flag)).
func pending_explainers() -> Array[StringName]:
	var st: Node = get_node_or_null(^"/root/Settings")
	if st == null or not st.has_method(&"meet"):
		var none: Array[StringName] = []
		return none
	return RevealFlags.pending_explainers(st.met_flags, st.seen_flags)


## The player tapped "Got it" on the "New:" card of `flag`.
func ack_explainer(flag: StringName) -> void:
	var st: Node = get_node_or_null(^"/root/Settings")
	if st != null and st.has_method(&"mark_seen"):
		st.mark_seen(flag)


func _changed() -> void:
	if autosave and run != null:
		save_run()
	if run != null and run.req != _last_req:
		var delta: int = run.req - _last_req
		_last_req = run.req
		req_changed.emit(run.req, delta)
	if run != null:
		note_systems(RevealFlags.run_triggers(run))
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

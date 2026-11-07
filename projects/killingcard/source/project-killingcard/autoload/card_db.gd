# card_db.gd
# Purpose: CardDB autoload. Loads every data Resource under res://data/ (recursively),
#   indexes it by id and validates it. Invalid data fails loudly: every issue is
#   push_error'd and kept in a validation report (get_report()) that tests read.
#   Data classes: CardData, LoadoutItem, SquadData, MapData, RunConfig, TutorialScript (p15)
#   (scripts/data/).
# Dependencies: scripts/data/* (class_name Resources), DataValidator.
# Author: Mechanics Developer Agent
extends Node

## Emitted after every load_all(). ok is false when any validation error was found.
signal data_loaded(ok: bool)

const DATA_ROOT: String = "res://data"
const DEFAULT_RUN_ID: StringName = &"run_default"

## When false, issues are only recorded in the report (tests feeding bad data on purpose).
var report_to_console: bool = true

var _by_id: Dictionary = {}        # String id -> Resource (all kinds)
var _cards: Dictionary = {}        # StringName id -> CardData
var _loadout: Dictionary = {}      # StringName id -> LoadoutItem
var _squads: Dictionary = {}       # StringName id -> SquadData
var _maps: Dictionary = {}         # StringName id -> MapData
var _run_configs: Dictionary = {}  # StringName id -> RunConfig
var _tutorials: Dictionary = {}    # StringName id -> TutorialScript (p15)
var _terrains: Dictionary = {}     # StringName id -> TerrainData (kc-v2-impl)
var _events: Dictionary = {}       # StringName id -> EventData (kc-v2-impl)
var _files: Dictionary = {}        # Resource -> file path it was loaded from
var _issues: Array[Dictionary] = []
var _root: String = DATA_ROOT
var _files_loaded: int = 0


func _ready() -> void:
	load_all()


## Loads and validates all .tres files under root. Returns true when there are no errors.
func load_all(root: String = DATA_ROOT) -> bool:
	_clear()
	_root = root
	var v: DataValidator = DataValidator.new()
	var loaded: Array[Resource] = []

	# Pass 1: load and index (so references can be checked in any order).
	for path: String in _find_data_files(root):
		v.begin(path, "")
		var res: Resource = ResourceLoader.load(path)
		if res == null:
			v.add(DataValidator.LOAD_FAILED, "", "file could not be loaded (syntax error or missing dependency)")
			continue
		_files_loaded += 1
		if not _is_data_class(res):
			v.add(DataValidator.UNKNOWN_TYPE, "", "not a data resource (%s); expected CardData, LoadoutItem, SquadData, MapData, RunConfig or TutorialScript" % res.get_class())
			continue
		var id: String = String(res.get("id"))
		v.begin(path, id)
		if id.is_empty():
			v.missing("id", "id is empty; the file can't be indexed")
			continue
		if _by_id.has(id):
			v.add(DataValidator.DUPLICATE_ID, "id", "id '%s' is already used by %s" % [id, _files[_by_id[id]]])
			continue
		_by_id[id] = res
		_bucket_for(res)[StringName(id)] = res
		_files[res] = path
		loaded.append(res)

	# Pass 2: validate fields and references.
	v.index = _by_id
	var run_config: RunConfig = _run_configs.get(DEFAULT_RUN_ID) as RunConfig
	var perk_slots: int = run_config.perk_slots if run_config != null else 3
	var killstreak_slots: int = run_config.killstreak_slots if run_config != null else 3
	for res: Resource in loaded:
		v.begin(_files[res], String(res.get("id")))
		if res is SquadData:
			(res as SquadData).validate(v, perk_slots, killstreak_slots)
		else:
			res.call("validate", v)

	_issues = v.issues
	if report_to_console:
		for issue: Dictionary in _issues:
			if issue["severity"] == "error":
				push_error("CardDB: " + DataValidator.format_issue(issue))
			else:
				push_warning("CardDB: " + DataValidator.format_issue(issue))
		if not is_valid():
			push_error("CardDB: %d data error(s) under %s; fix them before playing." % [v.error_count(), root])
	var ok: bool = is_valid()
	data_loaded.emit(ok)
	return ok

# --- Lookups -----------------------------------------------------------------------

## Returns the card for id, or null when unknown.
func get_card(id: StringName) -> CardData:
	return _cards.get(id)


## True when a card with this id is loaded.
func has_card(id: StringName) -> bool:
	return _cards.has(id)


## Number of loaded cards.
func card_count() -> int:
	return _cards.size()


func get_loadout_item(id: StringName) -> LoadoutItem:
	return _loadout.get(id)


func get_squad(id: StringName) -> SquadData:
	return _squads.get(id)


func get_map(id: StringName) -> MapData:
	return _maps.get(id)


## The run config with this id (run_default when omitted), or null.
func get_run_config(id: StringName = DEFAULT_RUN_ID) -> RunConfig:
	return _run_configs.get(id)


## The tutorial match script with this id (p15), or null.
func get_tutorial_script(id: StringName = &"tutorial_basic") -> TutorialScript:
	return _tutorials.get(id)


## Any loaded data resource by id.
## kc-v2-impl: a Terrain (map Field) by id, or null.
func get_terrain(id: StringName) -> TerrainData:
	return _terrains.get(id)


## kc-v2-impl: a run-map Event by id, or null.
func get_event(id: StringName) -> EventData:
	return _events.get(id)


func get_resource(id: StringName) -> Resource:
	return _by_id.get(String(id))


func all_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	result.assign(_cards.values())
	return result


func all_squads() -> Array[SquadData]:
	var result: Array[SquadData] = []
	result.assign(_squads.values())
	return result


## Loadout items filling one slot (e.g. every KILLSTREAK).
func loadout_items_by_slot(slot: DataEnums.LoadoutSlot) -> Array[LoadoutItem]:
	var result: Array[LoadoutItem] = []
	for item: LoadoutItem in _loadout.values():
		if item.slot == slot:
			result.append(item)
	return result

# --- Validation report ------------------------------------------------------------

## True when the last load_all() found no errors (warnings are allowed).
func is_valid() -> bool:
	for issue: Dictionary in _issues:
		if issue["severity"] == "error":
			return false
	return true


## Every issue from the last load: {severity, code, file, id, field, message}.
func get_issues() -> Array[Dictionary]:
	return _issues.duplicate()


## Human-readable error lines.
func get_errors() -> PackedStringArray:
	var lines: PackedStringArray = []
	for issue: Dictionary in _issues:
		if issue["severity"] == "error":
			lines.append(DataValidator.format_issue(issue))
	return lines


## True when an error with this code exists (optionally for one id and/or a field prefix).
func has_issue(code: String, id: String = "", field_prefix: String = "") -> bool:
	for issue: Dictionary in _issues:
		if issue["severity"] != "error" or issue["code"] != code:
			continue
		if not id.is_empty() and issue["id"] != id:
			continue
		if not field_prefix.is_empty() and not String(issue["field"]).begins_with(field_prefix):
			continue
		return true
	return false


## Summary for tests, debug overlays and the playtest log.
func get_report() -> Dictionary:
	var error_count: int = 0
	for issue: Dictionary in _issues:
		if issue["severity"] == "error":
			error_count += 1
	return {
		"ok": error_count == 0,
		"root": _root,
		"files_loaded": _files_loaded,
		"errors": error_count,
		"warnings": _issues.size() - error_count,
		"counts": {
			"cards": _cards.size(), "loadout": _loadout.size(), "squads": _squads.size(),
			"maps": _maps.size(), "run_configs": _run_configs.size(), "tutorials": _tutorials.size(),
		},
		"issues": _issues.duplicate(),
	}

# --- Internals ----------------------------------------------------------------------

func _clear() -> void:
	for d: Dictionary in [_by_id, _cards, _loadout, _squads, _maps, _run_configs, _tutorials, _terrains, _events, _files]:
		d.clear()
	_issues = []
	_files_loaded = 0


func _is_data_class(res: Resource) -> bool:
	return res is CardData or res is LoadoutItem or res is SquadData or res is MapData or res is RunConfig \
			or res is TutorialScript or res is TerrainData or res is EventData


func _bucket_for(res: Resource) -> Dictionary:
	if res is CardData:
		return _cards
	if res is LoadoutItem:
		return _loadout
	if res is SquadData:
		return _squads
	if res is MapData:
		return _maps
	if res is RunConfig:
		return _run_configs
	if res is TutorialScript:
		return _tutorials
	if res is TerrainData:
		return _terrains
	if res is EventData:
		return _events
	return {}


## All .tres/.res files under dir, sorted for a stable load order. Exported builds list
## converted resources as "name.tres.remap"; the suffix is dropped so load() still works.
func _find_data_files(dir: String) -> PackedStringArray:
	var result: PackedStringArray = []
	if not DirAccess.dir_exists_absolute(dir):
		return result
	for file: String in DirAccess.get_files_at(dir):
		var name: String = file.trim_suffix(".remap")
		if (name.ends_with(".tres") or name.ends_with(".res")) and not result.has(dir.path_join(name)):
			result.append(dir.path_join(name))
	for sub: String in DirAccess.get_directories_at(dir):
		# data/banners holds display-only BannerArt drop-ins (BannerArtDB), not game data.
		if not sub.begins_with(".") and dir.path_join(sub) != "res://data/banners":
			result.append_array(_find_data_files(dir.path_join(sub)))
	result.sort()
	return result

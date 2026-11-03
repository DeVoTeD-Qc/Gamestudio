# card_db.gd
# Adapted from Killstreak autoload/card_db.gd (two-pass load, issue report and lookups kept;
#   data classes, cross checks and lookups are new for Banner Wall).
# Purpose: CardDB autoload. Loads every data Resource under res://data/ (recursively),
#   indexes it by id and validates it. Invalid data fails loudly: every issue is
#   push_error'd and kept in a validation report (get_report()) that tests read.
#   Pass 1 loads and indexes, pass 2 validates each file (fields and references),
#   pass 3 checks rules that span files (set sizes, album order, cipher glyphs, unique numbers).
#   Data classes (scripts/data/): CardData, SetData, RivalData, TriptychData, DossierData,
#   UnlockGoal, BalanceConfig.
# Dependencies: scripts/data/* (class_name Resources), DataValidator. Keep it registered in
#   project.godot in this order: EventBus, Settings, CardDB, Collection, PlaytestLog, SceneRouter.
# Author: Mechanics Developer Agent
extends Node

## Emitted after every load_all(). ok is false when any validation error was found.
signal data_loaded(ok: bool)

const DATA_ROOT: String = "res://data"

## When false, issues are only recorded in the report (tests feeding bad data on purpose).
var report_to_console: bool = true

var _by_id: Dictionary = {}        # String id -> Resource (all kinds)
var _cards: Dictionary = {}        # StringName id -> CardData
var _sets: Dictionary = {}         # StringName id -> SetData
var _rivals: Dictionary = {}       # StringName id -> RivalData
var _triptychs: Dictionary = {}    # StringName id -> TriptychData
var _dossiers: Dictionary = {}     # StringName id -> DossierData
var _unlocks: Dictionary = {}      # StringName id -> UnlockGoal
var _balances: Dictionary = {}     # StringName id -> BalanceConfig (exactly one: `balance`)
var _files: Dictionary = {}        # Resource -> file path it was loaded from
var _balance: BalanceConfig = null
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
			v.add(DataValidator.UNKNOWN_TYPE, "", "not a data resource (%s); expected CardData, SetData, RivalData, TriptychData, DossierData, UnlockGoal or BalanceConfig" % res.get_class())
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

	# The balance config drives card budgets, lineup rules and slot names, so find it first.
	_balance = _balances.get(BalanceConfig.DEFAULT_ID) as BalanceConfig
	v.begin(root.path_join("balance.tres"), String(BalanceConfig.DEFAULT_ID))
	if _balance == null:
		v.missing("balance", "no BalanceConfig with id 'balance' under %s; checks use default values" % root)
	if _balances.size() > 1:
		v.invalid("balance", "%d BalanceConfig files; keep exactly one (id 'balance')" % _balances.size())
	v.balance = _balance if _balance != null else BalanceConfig.new()

	# Pass 2: validate fields and references, file by file.
	v.index = _by_id
	for res: Resource in loaded:
		v.begin(_files[res], String(res.get("id")))
		res.call("validate", v)

	# Pass 3: rules that span files.
	_cross_check(v)

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


func has_card(id: StringName) -> bool:
	return _cards.has(id)


func card_count() -> int:
	return _cards.size()


## Every card in album order (set number, then album_order).
func all_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	result.assign(_cards.values())
	result.sort_custom(_card_before)
	return result


## Cards of one set in album order.
func cards_in_set(set_id: StringName) -> Array[CardData]:
	var result: Array[CardData] = []
	for card: CardData in all_cards():
		if card.card_set != null and card.card_set.id == set_id:
			result.append(card)
	return result


## Cards the player owns when a new demo save starts.
func starting_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	result.assign(all_cards().filter(func(c: CardData) -> bool: return c.starts_owned))
	return result


## Cards that the goal unlocks.
func cards_unlocked_by(goal_id: StringName) -> Array[CardData]:
	var result: Array[CardData] = []
	result.assign(all_cards().filter(func(c: CardData) -> bool: return c.unlock_goal != null and c.unlock_goal.id == goal_id))
	return result


func get_set(id: StringName) -> SetData:
	return _sets.get(id)


## Sets in album page order.
func all_sets() -> Array[SetData]:
	var result: Array[SetData] = []
	result.assign(_sets.values())
	result.sort_custom(func(a: SetData, b: SetData) -> bool: return a.number < b.number)
	return result


func get_rival(id: StringName) -> RivalData:
	return _rivals.get(id)


## Rivals from Easy to Hard.
func all_rivals() -> Array[RivalData]:
	var result: Array[RivalData] = []
	result.assign(_rivals.values())
	result.sort_custom(func(a: RivalData, b: RivalData) -> bool:
		return a.difficulty < b.difficulty or (a.difficulty == b.difficulty and String(a.id) < String(b.id)))
	return result


func get_triptych(id: StringName) -> TriptychData:
	return _triptychs.get(id)


func all_triptychs() -> Array[TriptychData]:
	var result: Array[TriptychData] = []
	result.assign(_triptychs.values())
	result.sort_custom(func(a: TriptychData, b: TriptychData) -> bool: return String(a.id) < String(b.id))
	return result


func get_dossier(id: StringName) -> DossierData:
	return _dossiers.get(id)


## Dossiers in menu order (D1..D5).
func all_dossiers() -> Array[DossierData]:
	var result: Array[DossierData] = []
	result.assign(_dossiers.values())
	result.sort_custom(func(a: DossierData, b: DossierData) -> bool: return a.number < b.number)
	return result


func get_unlock_goal(id: StringName) -> UnlockGoal:
	return _unlocks.get(id)


func all_unlock_goals() -> Array[UnlockGoal]:
	var result: Array[UnlockGoal] = []
	result.assign(_unlocks.values())
	result.sort_custom(func(a: UnlockGoal, b: UnlockGoal) -> bool: return String(a.id) < String(b.id))
	return result


## The balance config (data/balance.tres). Defaults when the file is missing (an error is reported).
func get_balance() -> BalanceConfig:
	if _balance == null:
		_balance = BalanceConfig.new()
	return _balance


## Any loaded data resource by id.
func get_resource(id: StringName) -> Resource:
	return _by_id.get(String(id))

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


## True when an issue with this code exists (optionally for one id and/or a field prefix).
## Only errors count unless include_warnings is true.
func has_issue(code: String, id: String = "", field_prefix: String = "", include_warnings: bool = false) -> bool:
	for issue: Dictionary in _issues:
		if issue["code"] != code or (issue["severity"] != "error" and not include_warnings):
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
			"cards": _cards.size(), "sets": _sets.size(), "rivals": _rivals.size(),
			"triptychs": _triptychs.size(), "dossiers": _dossiers.size(), "unlocks": _unlocks.size(),
			"balance": _balances.size(),
		},
		"issues": _issues.duplicate(),
	}

# --- Cross-file checks (pass 3) ------------------------------------------------------

func _cross_check(v: DataValidator) -> void:
	var b: BalanceConfig = v.balance
	# Sets: size 2-6, album_order unique within a set, set numbers unique.
	var members: Dictionary = {}  # SetData -> Array[CardData]
	for card: CardData in _cards.values():
		if card.card_set is SetData and _sets.values().has(card.card_set):
			if not members.has(card.card_set):
				members[card.card_set] = []
			members[card.card_set].append(card)
	var set_numbers: Dictionary = {}
	for s: SetData in _sets.values():
		v.begin(_files[s], String(s.id))
		var cards: Array = members.get(s, [])
		if cards.size() > b.set_size_max:
			v.out_of_range("cards", "set has %d cards (max %d)" % [cards.size(), b.set_size_max])
		elif cards.size() < b.set_size_min:
			# A warning while content is being authored (cc03 fills every set).
			v.warn(DataValidator.OUT_OF_RANGE, "cards", "set has %d card(s); a set needs %d-%d" % [cards.size(), b.set_size_min, b.set_size_max])
		var orders: Dictionary = {}
		for c: CardData in cards:
			if orders.has(c.album_order):
				v.invalid("album_order", "'%s' and '%s' share album_order %d" % [orders[c.album_order], c.id, c.album_order])
			orders[c.album_order] = c.id
		if set_numbers.has(s.number):
			v.invalid("number", "set number %d is also used by '%s'" % [s.number, set_numbers[s.number]])
		set_numbers[s.number] = s.id
	# Cipher glyphs: each glyph on at most one card; every glyph in the code appears on a card.
	var glyph_cards: Dictionary = {}  # glyph -> card id
	for card: CardData in all_cards():
		if card.cipher_glyph <= 0:
			continue
		v.begin(_files[card], String(card.id))
		if glyph_cards.has(card.cipher_glyph):
			v.invalid("cipher_glyph", "glyph %d is also on '%s'" % [card.cipher_glyph, glyph_cards[card.cipher_glyph]])
		else:
			glyph_cards[card.cipher_glyph] = card.id
	if _balance != null:
		v.begin(_files[_balance], String(_balance.id))
		var absent: PackedStringArray = []
		for glyph: int in b.cipher_code:
			if not glyph_cards.has(glyph):
				absent.append(str(glyph))
		if not absent.is_empty():
			v.warn(DataValidator.MISSING_FIELD, "cipher_code", "no card carries glyph %s yet (the Cipher Lock can't be solved)" % ", ".join(absent))
	# Dossier numbers unique.
	var dossier_numbers: Dictionary = {}
	for d: DossierData in _dossiers.values():
		v.begin(_files[d], String(d.id))
		if dossier_numbers.has(d.number):
			v.invalid("number", "Dossier number %d is also used by '%s'" % [d.number, dossier_numbers[d.number]])
		dossier_numbers[d.number] = d.id

# --- Internals ----------------------------------------------------------------------

func _clear() -> void:
	for d: Dictionary in [_by_id, _cards, _sets, _rivals, _triptychs, _dossiers, _unlocks, _balances, _files]:
		d.clear()
	_balance = null
	_issues = []
	_files_loaded = 0


func _is_data_class(res: Resource) -> bool:
	return res is CardData or res is SetData or res is RivalData or res is TriptychData \
			or res is DossierData or res is UnlockGoal or res is BalanceConfig


func _bucket_for(res: Resource) -> Dictionary:
	if res is CardData:
		return _cards
	if res is SetData:
		return _sets
	if res is RivalData:
		return _rivals
	if res is TriptychData:
		return _triptychs
	if res is DossierData:
		return _dossiers
	if res is UnlockGoal:
		return _unlocks
	if res is BalanceConfig:
		return _balances
	return {}


func _card_before(a: CardData, b: CardData) -> bool:
	var na: int = a.card_set.number if a.card_set != null else 999
	var nb: int = b.card_set.number if b.card_set != null else 999
	if na != nb:
		return na < nb
	if a.album_order != b.album_order:
		return a.album_order < b.album_order
	return String(a.id) < String(b.id)


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
		if not sub.begins_with("."):
			result.append_array(_find_data_files(dir.path_join(sub)))
	result.sort()
	return result

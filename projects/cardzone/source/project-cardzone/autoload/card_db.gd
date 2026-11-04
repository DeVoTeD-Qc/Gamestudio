# card_db.gd
# Adapted from CallingCard autoload/card_db.gd (3-pass load, issue report and report API kept;
#   data classes, cross checks and lookups are new for CardZone).
# Purpose: CardDB autoload. Loads every data Resource under res://data/ (recursively),
#   indexes it by id and validates it. Invalid data fails loudly: every issue is
#   push_error'd and kept in a validation report (get_report()) that tests read.
#   Pass 1 loads and indexes, pass 2 validates each file (fields and references),
#   pass 3 checks rules that span files (map, Zone routes, start packs, unique codes).
#   Data classes (scripts/data/): CardData, AreaData, ZoneCardData, StartPackData, BalanceConfig.
# Dependencies: scripts/data/* (class_name Resources), DataValidator. Keep it registered in
#   project.godot after Settings and before SceneRouter.
# Author: Mechanics Developer Agent
extends Node

## Emitted after every load_all(). ok is false when any validation error was found.
signal data_loaded(ok: bool)

const DATA_ROOT: String = "res://data"

## When false, issues are only recorded in the report (tests feeding bad data on purpose).
var report_to_console: bool = true

var _by_id: Dictionary = {}        # String id -> Resource (all kinds)
var _cards: Dictionary = {}        # StringName id -> CardData
var _areas: Dictionary = {}        # StringName id -> AreaData
var _zone_cards: Dictionary = {}   # StringName id -> ZoneCardData
var _packs: Dictionary = {}        # StringName id -> StartPackData
var _balances: Dictionary = {}     # StringName id -> BalanceConfig (exactly one: `balance`)
var _files: Dictionary = {}        # Resource -> file path it was loaded from
var _distances: Dictionary = {}    # StringName area id -> {StringName area id: int steps}
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
			v.add(DataValidator.UNKNOWN_TYPE, "", "not a data resource (%s); expected CardData, AreaData, ZoneCardData, StartPackData or BalanceConfig" % res.get_class())
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

	# The balance config drives pile sizes, hand sizes and the hard end, so find it first.
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

# --- Cards -------------------------------------------------------------------------

## Returns the card for id, or null when unknown.
func get_card(id: StringName) -> CardData:
	return _cards.get(id)


func has_card(id: StringName) -> bool:
	return _cards.has(id)


func card_count() -> int:
	return _cards.size()


## Every card in printed order (code CZ-001, CZ-002, ...).
func all_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	result.assign(_cards.values())
	result.sort_custom(func(a: CardData, b: CardData) -> bool:
		return a.code < b.code or (a.code == b.code and String(a.id) < String(b.id)))
	return result


func cards_of_type(type: DataEnums.CardType) -> Array[CardData]:
	var result: Array[CardData] = []
	result.assign(all_cards().filter(func(c: CardData) -> bool: return c.type == type))
	return result


func starter_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	result.assign(all_cards().filter(func(c: CardData) -> bool: return c.is_starter()))
	return result


func supply_drop_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	result.assign(all_cards().filter(func(c: CardData) -> bool: return c.supply_drop))
	return result


## The Hit card (health stacks hold BalanceConfig.health copies). Null when missing.
func hit_card() -> CardData:
	var hits: Array[CardData] = cards_of_type(DataEnums.CardType.HIT)
	return hits[0] if not hits.is_empty() else null


## The shared Bounty card. Null when missing.
func bounty_card() -> CardData:
	var markers: Array[CardData] = cards_of_type(DataEnums.CardType.MARKER)
	return markers[0] if not markers.is_empty() else null

# --- Map -----------------------------------------------------------------------------

func get_area(id: StringName) -> AreaData:
	return _areas.get(id)


## Outer areas by number (1-6), then the Core.
func all_areas() -> Array[AreaData]:
	var result: Array[AreaData] = []
	result.assign(_areas.values())
	result.sort_custom(func(a: AreaData, b: AreaData) -> bool:
		var ka: int = 100 if a.is_core() else a.number
		var kb: int = 100 if b.is_core() else b.number
		return ka < kb or (ka == kb and String(a.id) < String(b.id)))
	return result


func outer_areas() -> Array[AreaData]:
	var result: Array[AreaData] = []
	result.assign(all_areas().filter(func(a: AreaData) -> bool: return not a.is_core()))
	return result


func core_area() -> AreaData:
	for a: AreaData in _areas.values():
		if a.is_core():
			return a
	return null


## Outer area by map number (1-6); 0 returns the Core.
func area_by_number(number: int) -> AreaData:
	for a: AreaData in all_areas():
		if a.number == number:
			return a
	return null


## Areas adjacent to area_id, in all_areas() order.
func neighbours(area_id: StringName) -> Array[AreaData]:
	var area: AreaData = get_area(area_id)
	var result: Array[AreaData] = []
	if area == null:
		return result
	result.assign(all_areas().filter(func(a: AreaData) -> bool: return area.adjacent.has(a.id)))
	return result


## Fewest steps between two areas (0 same area); -1 when either is unknown or unreachable.
func distance(from_id: StringName, to_id: StringName) -> int:
	return int((_distances.get(from_id, {}) as Dictionary).get(to_id, -1))


## The area whose piles hold this card, or null.
func area_with_pile(card_id: StringName) -> AreaData:
	for a: AreaData in all_areas():
		for c: CardData in a.piles:
			if c != null and c.id == card_id:
				return a
	return null

# --- Zone deck, packs, balance ---------------------------------------------------------

func get_zone_card(number: int) -> ZoneCardData:
	for z: ZoneCardData in _zone_cards.values():
		if z.number == number:
			return z
	return null


## The Zone deck in flip order, cards 1 .. BalanceConfig.zone_hard_end_card.
func zone_deck() -> Array[ZoneCardData]:
	var result: Array[ZoneCardData] = []
	var end: int = get_balance().zone_hard_end_card
	result.assign(all_zone_cards().filter(func(z: ZoneCardData) -> bool: return z.number <= end))
	return result


## Every Zone card by number (including any past the hard end).
func all_zone_cards() -> Array[ZoneCardData]:
	var result: Array[ZoneCardData] = []
	result.assign(_zone_cards.values())
	result.sort_custom(func(a: ZoneCardData, b: ZoneCardData) -> bool: return a.number < b.number)
	return result


## The start pack printed for this hand size (the Standard pack serves 4 and 5). Null when none.
func get_start_pack(hand_size: int = -1) -> StartPackData:
	var size: int = hand_size if hand_size > 0 else get_balance().hand_size
	for p: StartPackData in all_start_packs():
		if p.serves(size):
			return p
	return null


func all_start_packs() -> Array[StartPackData]:
	var result: Array[StartPackData] = []
	result.assign(_packs.values())
	result.sort_custom(func(a: StartPackData, b: StartPackData) -> bool: return String(a.id) < String(b.id))
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
	return _lines("error")


## Human-readable warning lines (content still being authored).
func get_warnings() -> PackedStringArray:
	return _lines("warning")


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
	var error_count: int = get_errors().size()
	return {
		"ok": error_count == 0,
		"root": _root,
		"files_loaded": _files_loaded,
		"errors": error_count,
		"warnings": _issues.size() - error_count,
		"counts": {
			"cards": _cards.size(), "areas": _areas.size(), "zone_cards": _zone_cards.size(),
			"packs": _packs.size(), "balance": _balances.size(),
		},
		"issues": _issues.duplicate(),
	}

# --- Cross-file checks (pass 3) ------------------------------------------------------

func _cross_check(v: DataValidator) -> void:
	_check_cards(v)
	_check_map(v)
	_check_zone_deck(v)
	_check_packs(v)


## Unique printed codes; one Hit card and one Bounty; every loot card placed somewhere.
func _check_cards(v: DataValidator) -> void:
	var codes: Dictionary = {}
	for card: CardData in all_cards():
		if card.code.is_empty():
			continue
		v.begin(_files[card], String(card.id))
		if codes.has(card.code):
			v.invalid("code", "code %s is also used by '%s'" % [card.code, codes[card.code]])
		else:
			codes[card.code] = card.id
	for type: int in [DataEnums.CardType.HIT, DataEnums.CardType.MARKER]:
		var found: Array[CardData] = cards_of_type(type)
		var what: String = "Hit" if type == DataEnums.CardType.HIT else "Bounty (MARKER)"
		if found.size() > 1:
			v.begin(_files[found[1]], String(found[1].id))
			v.invalid("type", "only one %s card is allowed ('%s' is the first)" % [what, found[0].id])
		elif found.is_empty() and not _cards.is_empty():
			v.begin(_root.path_join("cards"), "")
			v.warn(DataValidator.MISSING_FIELD, "type", "no %s card yet (cz06 adds it)" % what)
	# Pile placement: a card sits in one area's piles at most.
	var pile_area: Dictionary = {}  # CardData -> AreaData
	for area: AreaData in all_areas():
		v.begin(_files[area], String(area.id))
		for i: int in area.piles.size():
			var card: CardData = area.piles[i]
			if card == null:
				continue
			if pile_area.has(card) and pile_area[card] != area:
				v.invalid("piles[%d]" % i, "'%s' already has a pile in '%s'" % [card.id, pile_area[card].id])
			pile_area[card] = area
	var dropped: Dictionary = {}  # CardData -> true
	for z: ZoneCardData in _zone_cards.values():
		if z.drop_card != null:
			dropped[z.drop_card] = true
	for card: CardData in all_cards():
		if card.is_loot() and not pile_area.has(card) and not dropped.has(card):
			v.begin(_files[card], String(card.id))
			v.warn(DataValidator.MISSING_FIELD, "supply_drop" if card.supply_drop else "rarity",
					"'%s' is never on the map (%s)" % [card.id,
					"no Zone card drops it" if card.supply_drop else "no area has a pile of it"])


## Spec §3: 7 areas, one Core, numbers unique, adjacency mutual, connected, every distance <= RNG 2.
func _check_map(v: DataValidator) -> void:
	_distances.clear()
	var areas: Array[AreaData] = all_areas()
	v.begin(_root.path_join("areas"), "")
	if areas.size() != DataEnums.MAP_AREA_COUNT:
		v.add(DataValidator.MAP_RULE, "areas", "the map has %d areas; Ridge Hollow has %d (6 outer + the Core)"
				% [areas.size(), DataEnums.MAP_AREA_COUNT])
	var cores: Array = areas.filter(func(a: AreaData) -> bool: return a.is_core())
	if cores.size() != 1 and not areas.is_empty():
		v.add(DataValidator.MAP_RULE, "tier", "the map needs exactly one CORE area (found %d)" % cores.size())
	var numbers: Dictionary = {}
	for area: AreaData in areas:
		v.begin(_files[area], String(area.id))
		if not area.is_core():
			if numbers.has(area.number):
				v.invalid("number", "map number %d is also used by '%s'" % [area.number, numbers[area.number]])
			numbers[area.number] = area.id
		for i: int in area.adjacent.size():
			var other: AreaData = _areas.get(area.adjacent[i])
			if other != null and other != area and not other.adjacent.has(area.id):
				v.add(DataValidator.MAP_RULE, "adjacent[%d]" % i,
						"'%s' lists '%s' as adjacent, but '%s' doesn't list '%s' (adjacency must be mutual)"
						% [area.id, other.id, other.id, area.id])
	# Distances by breadth-first search over the listed (known) neighbours.
	for area: AreaData in areas:
		var dist: Dictionary = {area.id: 0}
		var queue: Array[AreaData] = [area]
		while not queue.is_empty():
			var current: AreaData = queue.pop_front()
			for next_id: StringName in current.adjacent:
				var next: AreaData = _areas.get(next_id)
				if next != null and not dist.has(next.id):
					dist[next.id] = dist[current.id] + 1
					queue.append(next)
		_distances[area.id] = dist
	if areas.size() < 2:
		return
	var first: AreaData = areas[0]
	for area: AreaData in areas:
		var d: int = distance(first.id, area.id)
		if d < 0:
			v.begin(_files[area], String(area.id))
			v.add(DataValidator.MAP_RULE, "adjacent", "'%s' can't be reached from '%s' (the map must be connected)" % [area.id, first.id])
	var widest: int = 0
	for a: AreaData in areas:
		for b: AreaData in areas:
			widest = maxi(widest, distance(a.id, b.id))
	if widest > DataEnums.MAX_RANGE:
		v.begin(_root.path_join("areas"), "")
		v.add(DataValidator.MAP_RULE, "adjacent", "two areas are %d steps apart; RNG %d must reach anywhere on the map (spec §3)"
				% [widest, DataEnums.MAX_RANGE])


## Spec §8, R39-R44: numbers 1..N without gaps, final circle last and in order, and per route
## an area closes at most once and a drop never lands in gas.
func _check_zone_deck(v: DataValidator) -> void:
	var deck: Array[ZoneCardData] = all_zone_cards()
	if deck.is_empty():
		if not _by_id.is_empty():
			v.begin(_root.path_join("zone"), "")
			v.warn(DataValidator.MISSING_FIELD, "zone", "no Zone cards yet (cz06 adds zone_01 .. zone_14)")
		return
	var expected: int = 1
	var by_number: Dictionary = {}
	for z: ZoneCardData in deck:
		v.begin(_files[z], String(z.id))
		if by_number.has(z.number):
			v.invalid("number", "Zone card number %d is also used by '%s'" % [z.number, by_number[z.number]])
			continue
		by_number[z.number] = z.id
		if z.number != expected:
			v.add(DataValidator.ROUTE_RULE, "number", "Zone card %d follows card %d; the deck has no gaps" % [z.number, expected - 1])
		expected = z.number + 1
	var b: BalanceConfig = v.balance
	if deck.back().number < b.zone_hard_end_card:
		v.begin(_root.path_join("zone"), "")
		v.warn(DataValidator.MISSING_FIELD, "zone", "the deck ends at card %d but zone_hard_end_card is %d"
				% [deck.back().number, b.zone_hard_end_card])
	# Final circle: steps 1, 2, 3... on consecutive cards, and nothing after them.
	var step: int = 0
	for z: ZoneCardData in deck:
		v.begin(_files[z], String(z.id))
		if z.is_final_circle():
			step += 1
			if z.final_circle_step != step:
				v.add(DataValidator.ROUTE_RULE, "final_circle_step", "final circle step %d where step %d comes next" % [z.final_circle_step, step])
		elif step > 0:
			v.add(DataValidator.ROUTE_RULE, "number", "card %d comes after the final circle began; the final circle ends the deck" % z.number)
	# Routes.
	var drops_seen: Dictionary = {}  # CardData -> zone id
	for z: ZoneCardData in deck:
		if z.drop_card == null:
			continue
		v.begin(_files[z], String(z.id))
		if drops_seen.has(z.drop_card):
			v.add(DataValidator.ROUTE_RULE, "drop_card", "'%s' already drops on '%s'" % [z.drop_card.id, drops_seen[z.drop_card]])
		drops_seen[z.drop_card] = z.id
	for route: DataEnums.Route in ZoneCardData.ROUTES:
		var letter: String = DataEnums.ROUTE_LETTERS[route]
		var closed_by: Dictionary = {}  # AreaData -> zone id
		for z: ZoneCardData in deck:
			v.begin(_files[z], String(z.id))
			var closed: AreaData = z.close_for(route)
			if closed != null:
				if closed_by.has(closed):
					v.add(DataValidator.ROUTE_RULE, "close_" + letter.to_lower(),
							"route %s closes '%s' twice (already on '%s')" % [letter, closed.id, closed_by[closed]])
				else:
					closed_by[closed] = z.id
			var landing: AreaData = z.drop_area_for(route)
			if landing != null and closed_by.has(landing):
				v.add(DataValidator.ROUTE_RULE, "drop_" + letter.to_lower(),
						"route %s drops into '%s', closed by '%s' (gas closes first, R39; nobody could loot it)"
						% [letter, landing.id, closed_by[landing]])


## Spec §16.4: every allowed hand_size has exactly one start pack.
func _check_packs(v: DataValidator) -> void:
	if _by_id.is_empty():
		return
	for size: Variant in BalanceConfig.allowed_values(&"hand_size"):
		var serving: Array[StartPackData] = []
		serving.assign(all_start_packs().filter(func(p: StartPackData) -> bool: return p.serves(size)))
		if serving.is_empty():
			v.begin(_root.path_join("packs"), "")
			v.add(DataValidator.PACK_RULE, "hand_sizes", "no start pack serves hand_size %d" % size)
		elif serving.size() > 1:
			v.begin(_files[serving[1]], String(serving[1].id))
			v.add(DataValidator.PACK_RULE, "hand_sizes", "hand_size %d is already served by '%s'" % [size, serving[0].id])

# --- Internals ----------------------------------------------------------------------

func _clear() -> void:
	for d: Dictionary in [_by_id, _cards, _areas, _zone_cards, _packs, _balances, _files, _distances]:
		d.clear()
	_balance = null
	_issues = []
	_files_loaded = 0


func _lines(severity: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	for issue: Dictionary in _issues:
		if issue["severity"] == severity:
			lines.append(DataValidator.format_issue(issue))
	return lines


func _is_data_class(res: Resource) -> bool:
	return res is CardData or res is AreaData or res is ZoneCardData or res is StartPackData or res is BalanceConfig


func _bucket_for(res: Resource) -> Dictionary:
	if res is CardData:
		return _cards
	if res is AreaData:
		return _areas
	if res is ZoneCardData:
		return _zone_cards
	if res is StartPackData:
		return _packs
	if res is BalanceConfig:
		return _balances
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
		if not sub.begins_with("."):
			result.append_array(_find_data_files(dir.path_join(sub)))
	result.sort()
	return result

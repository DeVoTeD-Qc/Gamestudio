# test_data.gd
# Purpose: p02 data format tests. A complete valid data set (built in code and saved
#   as .tres under user://) loads cleanly; each kind of bad data is rejected with the
#   right issue code in CardDB's validation report; the shipped samples are valid.
#   Uses a fresh CardDB instance per case, so the live autoload is never disturbed.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const CardDBScript: GDScript = preload("res://autoload/card_db.gd")
const TEST_ROOT: String = "user://test_data"

var _case_counter: int = 0

# --- Live project data -----------------------------------------------------------

func test_project_data_is_valid() -> void:
	var db: Node = tree.root.get_node_or_null("CardDB")
	assert_not_null(db, "CardDB autoload")
	if db == null:
		return
	assert_true(db.is_valid(), "res://data has errors:\n" + "\n".join(db.get_errors()))
	assert_true(db.get_report()["files_loaded"] >= 3, "sample files loaded")


func test_sample_cards_match_core_rules() -> void:
	var db: Node = tree.root.get_node("CardDB")
	var rifleman: CardData = db.get_card(&"rifleman")
	assert_not_null(rifleman, "rifleman sample")
	if rifleman != null:
		assert_eq([rifleman.cost, rifleman.firepower, rifleman.armor], [1, 2, 2], "Rifleman 1 / 2/2")
		assert_eq(rifleman.weapon_class, DataEnums.WeaponClass.AR, "Rifleman class")
	var bac: CardData = db.get_card(&"breach_and_clear")
	assert_not_null(bac, "breach_and_clear sample")
	if bac != null:
		assert_eq(bac.card_type, DataEnums.CardType.TACTIC, "B&C type")
		assert_eq(bac.effects[0].amount + bac.effects[0].bonus_amount, 3, "B&C 3 if Close")
		assert_true(bac.requires_zone_choice(), "B&C needs a zone")
	var mortar: LoadoutItem = db.get_loadout_item(&"mortar_barrage")
	assert_not_null(mortar, "mortar sample")
	if mortar != null:
		assert_eq(mortar.streak_threshold, 3, "Mortar threshold")
		assert_eq(db.loadout_items_by_slot(DataEnums.LoadoutSlot.KILLSTREAK).has(mortar), true, "by slot")

# --- Valid set -----------------------------------------------------------------------

func test_valid_set_loads_and_indexes() -> void:
	var data: Dictionary = _valid_set()
	var db: Node = _load_case(data)
	assert_true(db.is_valid(), "valid set has errors:\n" + "\n".join(db.get_errors()))
	var report: Dictionary = db.get_report()
	assert_eq(report["counts"]["cards"], 5, "cards indexed (incl. Sentry token)")
	assert_eq(report["counts"]["loadout"], 8, "loadout items indexed")
	assert_eq(report["counts"]["squads"], 1, "squads")
	assert_eq(report["counts"]["maps"], 1, "maps")
	assert_eq(report["counts"]["run_configs"], 1, "run configs")
	assert_eq(db.get_card(&"rifleman"), db.get_resource(&"rifleman"), "lookup by id")
	var run: RunConfig = db.get_run_config()
	assert_not_null(run, "run_default")
	if run != null:
		assert_eq(run.match_count(), 5, "5 matches per run")
		assert_eq(run.tickets, 3, "3 tickets")
		assert_eq(run.supply_for_round(1), 2, "round 1 supply")
		assert_eq(run.supply_for_round(9), 7, "supply cap")
		assert_eq(run.range_bonus(DataEnums.WeaponClass.SNIPER, DataEnums.RangeTag.LONG), 2, "sniper long")
		assert_eq(run.range_bonus(DataEnums.WeaponClass.SHOTGUN, DataEnums.RangeTag.LONG), -1, "shotgun long")
		assert_eq(run.range_bonus(DataEnums.WeaponClass.NONE, DataEnums.RangeTag.CLOSE), 0, "no class")
		assert_eq(run.matches[0].squad, db.get_squad(&"squad_test"), "match -> squad reference resolves")
	var map: MapData = db.get_map(&"test_map")
	if map != null:
		assert_eq(map.range_of(&"mid"), DataEnums.RangeTag.LONG, "map range_of")
	db.free()

# --- Bad data: each kind must be rejected ----------------------------------------------

func test_rejects_duplicate_id() -> void:
	var data: Dictionary = _valid_set()
	var copy: CardData = data["cards/rifleman"].duplicate()
	data["cards/rifleman_copy"] = copy
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "duplicate id accepted")
	assert_true(db.has_issue(DataValidator.DUPLICATE_ID, "rifleman"), "duplicate_id reported")
	db.free()


func test_rejects_missing_required_fields() -> void:
	var data: Dictionary = _valid_set()
	data["cards/rifleman"].display_name = ""
	data["squads/squad_test"].primary = null
	data["loadout/mortar"].effects.clear()
	var nameless: CardData = _unit(&"", 1, 1, 1)
	data["cards/nameless"] = nameless
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "missing fields accepted")
	assert_true(db.has_issue(DataValidator.MISSING_FIELD, "rifleman", "display_name"), "empty display_name")
	assert_true(db.has_issue(DataValidator.MISSING_FIELD, "squad_test", "primary"), "squad without primary")
	assert_true(db.has_issue(DataValidator.MISSING_FIELD, "mortar_barrage", "effects"), "killstreak without effects")
	assert_true(db.has_issue(DataValidator.MISSING_FIELD, "", "id"), "card without id")
	db.free()


func test_rejects_out_of_range_values() -> void:
	var data: Dictionary = _valid_set()
	data["cards/rifleman"].armor = 0
	data["cards/point_man"].cost = 11
	data["loadout/recon_drone"].streak_threshold = 0
	data["loadout/mortar"].supply_cost = 2
	data["squads/squad_test"].deck.assign([data["cards/rifleman"], data["cards/rifleman"]])
	data["squads/squad_test"].second_best_chance = 1.5
	data["run"].starter_deck.pop_back()
	data["run"].range_bonus_ar = PackedInt32Array([0, 1])
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "out-of-range accepted")
	var R: String = DataValidator.OUT_OF_RANGE
	assert_true(db.has_issue(R, "rifleman", "armor"), "unit armor 0")
	assert_true(db.has_issue(R, "point_man", "cost"), "cost 11")
	assert_true(db.has_issue(R, "recon_drone", "streak_threshold"), "threshold 0")
	assert_true(db.has_issue(R, "mortar_barrage", "supply_cost"), "killstreak with Supply cost")
	assert_true(db.has_issue(R, "squad_test", "deck"), "squad deck of 2")
	assert_true(db.has_issue(R, "squad_test", "second_best_chance"), "chance 1.5")
	assert_true(db.has_issue(R, "run_default", "starter_deck"), "starter deck of 19")
	assert_true(db.has_issue(R, "run_default", "range_bonus_ar"), "range row of 2")
	db.free()


func test_rejects_broken_references() -> void:
	var data: Dictionary = _valid_set()
	# A card saved outside the data folder: it loads, but isn't registered data.
	var stray: CardData = _unit(&"stray_unit", 1, 1, 1)
	_ensure_dir(TEST_ROOT.path_join("outside"))
	_save(stray, TEST_ROOT.path_join("outside/stray_unit.tres"))
	data["squads/squad_test"].deck[0] = stray
	data["run"].matches[1].map = null
	var db: Node = _load_case(data, {"cards/broken_dep.tres": _tres_with_missing_dependency()})
	assert_false(db.is_valid(), "broken refs accepted")
	assert_true(db.has_issue(DataValidator.BROKEN_REFERENCE, "squad_test", "deck[0]"), "unregistered card in deck")
	assert_true(db.has_issue(DataValidator.MISSING_FIELD, "run_default", "matches[1].map"), "match without map")
	assert_true(db.has_issue(DataValidator.LOAD_FAILED), "file with a missing dependency")
	db.free()


func test_rejects_wrong_reference_types() -> void:
	var data: Dictionary = _valid_set()
	data["squads/squad_test"].primary = data["loadout/mortar"]          # killstreak in primary slot
	data["run"].starter_killstreaks[0] = data["loadout/perk"]           # perk in killstreak slot
	data["loadout/kestrel"].attachments.assign([data["loadout/mortar"]])  # killstreak as attachment
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "wrong types accepted")
	assert_true(db.has_issue(DataValidator.WRONG_TYPE, "squad_test", "primary"), "killstreak as primary")
	assert_true(db.has_issue(DataValidator.WRONG_TYPE, "run_default", "starter_killstreaks[0]"), "perk as killstreak")
	assert_true(db.has_issue(DataValidator.INVALID_VALUE, "kestrel_ar7", "attachments[0]"), "killstreak as attachment")
	db.free()


func test_rejects_invalid_values_and_effects() -> void:
	var data: Dictionary = _valid_set()
	data["cards/rifleman"].card_type = 9 as DataEnums.CardType   # not an enum value
	data["cards/point_man"].id = &"Point-Man"                    # bad id format
	var tactic: CardData = data["cards/hold"]
	tactic.firepower = 2                                         # stats on a tactic
	tactic.effects[0].kind = DataEnums.EffectKind.NONE
	data["loadout/mortar"].effects[0].amount = 0                 # DAMAGE 0
	data["loadout/sentry"].effects[0].summon_card = null         # SUMMON without unit
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "invalid values accepted")
	var V: String = DataValidator.INVALID_VALUE
	assert_true(db.has_issue(V, "rifleman", "card_type"), "bad enum value")
	assert_true(db.has_issue(V, "Point-Man", "id"), "bad id format")
	assert_true(db.has_issue(V, "hold_the_line", "firepower"), "tactic with FP")
	assert_true(db.has_issue(DataValidator.MISSING_FIELD, "hold_the_line", "effects[0].kind"), "effect kind NONE")
	assert_true(db.has_issue(DataValidator.OUT_OF_RANGE, "mortar_barrage", "effects[0].amount"), "damage 0")
	assert_true(db.has_issue(DataValidator.MISSING_FIELD, "sentry_turret", "effects[0].summon_card"), "summon without card")
	db.free()


## kc-loadout-cut: the Secondary (2), Lethal (3) and Tactical (4) slots and COOLDOWN_MOD are gone.
func test_rejects_removed_slots_and_cooldown_mod() -> void:
	assert_eq(DataEnums.LoadoutSlot.values(), [0, 1, 5, 6], "Primary, Attachment, Perk, Killstreak keep their numbers")
	var data: Dictionary = _valid_set()
	data["loadout/perk"].slot = 3 as DataEnums.LoadoutSlot          # the old LETHAL
	data["loadout/perk2"].effects[0].kind = DataEnums.EffectKind.COOLDOWN_MOD
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "a removed slot / COOLDOWN_MOD accepted")
	assert_true(db.has_issue(DataValidator.INVALID_VALUE, "streak_discipline", "slot"), "slot 3 (Lethal) rejected")
	assert_true(db.has_issue(DataValidator.INVALID_VALUE, "grit", "effects[0].kind"), "COOLDOWN_MOD rejected")
	db.free()


func test_rejects_unknown_resource_type() -> void:
	var data: Dictionary = _valid_set()
	data["cards/not_a_card"] = Gradient.new()
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "foreign resource accepted")
	assert_true(db.has_issue(DataValidator.UNKNOWN_TYPE), "unknown_type reported")
	db.free()


func test_issue_report_shape() -> void:
	var data: Dictionary = _valid_set()
	data["cards/rifleman"].armor = 0
	var db: Node = _load_case(data)
	var report: Dictionary = db.get_report()
	assert_false(report["ok"], "report ok flag")
	assert_eq(report["errors"], 1, "exactly one error")
	var issue: Dictionary = report["issues"][0]
	for key: String in ["severity", "code", "file", "id", "field", "message"]:
		assert_true(issue.has(key), "issue has %s" % key)
	assert_true(String(issue["file"]).ends_with("rifleman.tres"), "issue names the file")
	assert_eq(db.get_errors().size(), 1, "get_errors lines")
	db.free()

# --- Fixture builders ------------------------------------------------------------------

## A complete, valid data set. Keys are "<folder>/<file>" (saved as <key>.tres).
func _valid_set() -> Dictionary:
	var d: Dictionary = {}
	var rifleman: CardData = _unit(&"rifleman", 1, 2, 2, DataEnums.WeaponClass.AR)
	var point_man: CardData = _unit(&"point_man", 2, 2, 3, DataEnums.WeaponClass.SMG)
	point_man.first_shot = true
	var medic: CardData = _unit(&"combat_medic", 2, 1, 3, DataEnums.WeaponClass.AR)
	medic.patch = 2
	var hold: CardData = CardData.new()
	hold.id = &"hold_the_line"; hold.display_name = "Hold the Line"
	hold.card_type = DataEnums.CardType.TACTIC; hold.cost = 2
	hold.effects = [_effect(DataEnums.EffectKind.GRANT_COVER, 1, DataEnums.Target.ALL_FRIENDLIES, 1)]
	var sentry_unit: CardData = _unit(&"sentry_token", 0, 2, 4, DataEnums.WeaponClass.NONE)
	sentry_unit.cover = 1
	sentry_unit.collectible = false
	sentry_unit.counts_for_control = false
	sentry_unit.grants_elimination_credit = false
	d["cards/rifleman"] = rifleman
	d["cards/point_man"] = point_man
	d["cards/combat_medic"] = medic
	d["cards/hold"] = hold
	d["cards/sentry_token"] = sentry_unit

	var ext_mag: LoadoutItem = _item(&"extended_mag", DataEnums.LoadoutSlot.ATTACHMENT)
	ext_mag.firepower_bonus = 1
	var foregrip: LoadoutItem = _item(&"foregrip", DataEnums.LoadoutSlot.ATTACHMENT)
	foregrip.cover = 1
	var kestrel: LoadoutItem = _item(&"kestrel_ar7", DataEnums.LoadoutSlot.PRIMARY)
	kestrel.weapon_class = DataEnums.WeaponClass.AR
	kestrel.operator_firepower = 3
	kestrel.operator_armor = 7
	kestrel.attachments = [ext_mag, foregrip]
	var recon: LoadoutItem = _item(&"recon_drone", DataEnums.LoadoutSlot.KILLSTREAK)
	recon.streak_threshold = 2
	recon.effects = [_effect(DataEnums.EffectKind.REVEAL_DEPLOYMENTS, 0, DataEnums.Target.OWNER, 2)]
	recon.effects[0].zone_scope = DataEnums.ZoneScope.ALL_ZONES
	var mortar: LoadoutItem = _item(&"mortar_barrage", DataEnums.LoadoutSlot.KILLSTREAK)
	mortar.streak_threshold = 3
	mortar.effects = [_effect(DataEnums.EffectKind.DAMAGE, 2, DataEnums.Target.ALL_ENEMIES)]
	var sentry: LoadoutItem = _item(&"sentry_turret", DataEnums.LoadoutSlot.KILLSTREAK)
	sentry.streak_threshold = 4
	sentry.effects = [_effect(DataEnums.EffectKind.SUMMON_UNIT, 0, DataEnums.Target.OWNER)]
	sentry.effects[0].summon_card = sentry_unit
	var perk: LoadoutItem = _item(&"streak_discipline", DataEnums.LoadoutSlot.PERK)
	perk.effects = [_effect(DataEnums.EffectKind.STREAK_THRESHOLD_MOD, -1, DataEnums.Target.OWNER)]
	perk.effects[0].trigger = DataEnums.Trigger.PASSIVE
	perk.effects[0].zone_scope = DataEnums.ZoneScope.ANY
	var perk2: LoadoutItem = _item(&"grit", DataEnums.LoadoutSlot.PERK)
	perk2.uses_per_match = 1
	perk2.effects = [_effect(DataEnums.EffectKind.SURVIVE_LETHAL, 1, DataEnums.Target.OPERATOR)]
	perk2.effects[0].trigger = DataEnums.Trigger.PASSIVE
	perk2.effects[0].zone_scope = DataEnums.ZoneScope.ANY
	d["loadout/extended_mag"] = ext_mag
	d["loadout/foregrip"] = foregrip
	d["loadout/kestrel"] = kestrel
	d["loadout/recon_drone"] = recon
	d["loadout/mortar"] = mortar
	d["loadout/sentry"] = sentry
	d["loadout/perk"] = perk
	d["loadout/perk2"] = perk2

	var map: MapData = MapData.new()
	map.id = &"test_map"
	map.display_name = "Test Map"
	map.zone_names = PackedStringArray(["West", "Centre", "East"])
	map.zone_ranges = [DataEnums.RangeTag.CLOSE, DataEnums.RangeTag.LONG, DataEnums.RangeTag.MID]
	d["maps/test_map"] = map

	var squad: SquadData = SquadData.new()
	squad.id = &"squad_test"
	squad.display_name = "SandViper_07"
	squad.clan_tag = "DSRT"
	squad.personality = DataEnums.Personality.RUSHER
	squad.deck = _repeat([rifleman, point_man, medic], 15)
	squad.primary = kestrel
	squad.attachments = [ext_mag]
	squad.perks = [perk]
	squad.killstreaks = [recon, mortar]
	squad.preferred_ranges = [DataEnums.RangeTag.CLOSE]
	d["squads/squad_test"] = squad

	var run: RunConfig = RunConfig.new()
	run.display_name = "Prototype run"
	for i: int in 5:
		var m: RunMatchData = RunMatchData.new()
		m.bracket = 1 if i < 2 else 2
		m.is_rival = i == 4
		m.squad = squad
		m.map = map
		m.mode = DataEnums.GameMode.FIREFIGHT if i % 2 == 1 else DataEnums.GameMode.ZONE_CONTROL
		m.enemy_armor_bonus = 1 if m.bracket == 2 else 0
		run.matches.append(m)
	run.starter_deck = _repeat([rifleman, point_man, medic, hold], 20)
	run.starter_primary = kestrel
	run.starter_killstreaks = [recon, mortar, sentry]
	run.killstreak_pool = [recon, mortar, sentry]
	run.perk_pool = [perk, perk2]
	run.reward_pool = [rifleman, point_man, medic, hold]
	d["run"] = run
	return d


func _unit(id: StringName, cost: int, fp: int, ar: int, wc: DataEnums.WeaponClass = DataEnums.WeaponClass.AR) -> CardData:
	var c: CardData = CardData.new()
	c.id = id
	c.display_name = String(id).capitalize()
	c.card_type = DataEnums.CardType.UNIT
	c.cost = cost
	c.firepower = fp
	c.armor = ar
	c.weapon_class = wc
	return c


func _item(id: StringName, slot: DataEnums.LoadoutSlot) -> LoadoutItem:
	var item: LoadoutItem = LoadoutItem.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.slot = slot
	return item


func _effect(kind: DataEnums.EffectKind, amount: int, target: DataEnums.Target, duration: int = 0) -> EffectData:
	var e: EffectData = EffectData.new()
	e.kind = kind
	e.amount = amount
	e.target = target
	e.duration_rounds = duration
	return e


func _repeat(cards: Array, count: int) -> Array[CardData]:
	var result: Array[CardData] = []
	for i: int in count:
		result.append(cards[i % cards.size()])
	return result


## Text of a .tres whose ext_resource points at a file that doesn't exist.
func _tres_with_missing_dependency() -> String:
	return "\n".join([
		'[gd_resource type="Resource" script_class="CardData" load_steps=2 format=3]', "",
		'[ext_resource type="Script" path="res://scripts/data/card_data_missing.gd" id="1_x"]', "",
		"[resource]", 'script = ExtResource("1_x")', 'id = &"broken_dep"', "",
	])

# --- Saving & loading a case -------------------------------------------------------

## Saves `data` (and raw text files) under a fresh user:// folder and loads it with
## a new CardDB instance (not in the tree). Caller frees the returned node.
func _load_case(data: Dictionary, raw_files: Dictionary = {}) -> Node:
	_case_counter += 1
	var root: String = TEST_ROOT.path_join("case_%d_%d" % [Time.get_ticks_usec(), _case_counter])
	# Save leaves first so referencing files get ext_resource paths.
	var order: Array[String] = ["cards/", "loadout/extended_mag", "loadout/foregrip", "loadout/", "maps/", "squads/", "run"]
	var saved: Dictionary = {}
	for prefix: String in order:
		for key: String in data.keys():
			if key.begins_with(prefix) and not saved.has(key):
				saved[key] = true
				var path: String = root.path_join(key + ".tres")
				_ensure_dir(path.get_base_dir())
				_save(data[key], path)
	for rel: String in raw_files.keys():
		var path: String = root.path_join(rel)
		_ensure_dir(path.get_base_dir())
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		f.store_string(raw_files[rel])
		f.close()
	var db: Node = CardDBScript.new()
	db.report_to_console = false
	db.load_all(root)
	_remove_dir(TEST_ROOT)  # files are no longer needed: loaded resources stay cached in memory
	return db


func _remove_dir(dir: String) -> void:
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		_remove_dir(dir.path_join(sub))
	DirAccess.remove_absolute(dir)


## Saves res and gives it that path, so later files reference it as an ext_resource
## (FLAG_CHANGE_PATH does not set the path for user:// files).
func _save(res: Resource, path: String) -> void:
	var err: Error = ResourceSaver.save(res, path)
	if err != OK:
		failures.append("could not save %s (%s)" % [path, error_string(err)])
	res.take_over_path(path)


func _ensure_dir(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)

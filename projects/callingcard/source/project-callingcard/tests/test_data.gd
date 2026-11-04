# test_data.gd
# Pattern adapted from Killstreak tests/test_data.gd (user:// case folders, fresh CardDB per case).
# Purpose: cc02 data format tests. A complete valid data set (built in code and saved as .tres
#   under user://) loads cleanly with no warnings; each kind of bad data is rejected with the
#   right issue code in CardDB's validation report; the shipped samples are valid and match the spec.
#   Uses a fresh CardDB instance per case, so the live autoload is never disturbed.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const CardDBScript: GDScript = preload("res://autoload/card_db.gd")
const TEST_ROOT: String = "user://test_data"
## Save order: referenced files before the files that reference them.
const SAVE_ORDER: Array[String] = ["sets/", "unlocks/", "cards/", "rivals/", "triptychs/", "dossiers/", "balance"]

var _case_counter: int = 0

# --- Live project data -----------------------------------------------------------

func test_project_data_is_valid() -> void:
	var db: Node = tree.root.get_node_or_null("CardDB")
	assert_not_null(db, "CardDB autoload")
	if db == null:
		return
	assert_true(db.is_valid(), "res://data has errors:\n" + "\n".join(db.get_errors()))
	var report: Dictionary = db.get_report()
	assert_true(report["files_loaded"] >= 4, "sample files loaded")
	assert_eq(report["counts"]["balance"], 1, "one balance config")


func test_sample_cards_match_spec() -> void:
	var db: Node = tree.root.get_node("CardDB")
	var gs: CardData = db.get_card(&"graveyard_shift")
	assert_not_null(gs, "graveyard_shift sample")
	if gs != null:
		assert_eq([gs.top, gs.side, gs.bottom, gs.clearance], [5, 4, 4, 1], "Graveyard Shift 5/4/4 C1")
		assert_eq(gs.card_trait(), DataEnums.CardTrait.STEADY, "Challenge -> Steady")
		assert_eq(gs.card_set.id, &"night_shift", "Night Shift")
		assert_eq(gs.cipher_glyph, 1, "glyph on card 1")
	var nr: CardData = db.get_card(&"neon_rain")
	assert_not_null(nr, "neon_rain sample")
	if nr != null:
		assert_eq([nr.top, nr.side, nr.bottom, nr.clearance], [4, 6, 5, 2], "Neon Rain 4/6/5 C2")
		assert_eq(nr.card_trait(), DataEnums.CardTrait.VETERAN, "Mastery -> Veteran")
	var ct: CardData = db.get_card(&"chrome_tiger")
	assert_not_null(ct, "chrome_tiger sample")
	if ct != null:
		assert_true(ct.is_store, "store flag")
		assert_eq(ct.clearance, 1, "store card is Clearance 1")
		assert_eq(ct.card_trait(), DataEnums.CardTrait.NONE, "store card has no trait")
	if nr != null:
		var ui: Dictionary = nr.to_ui_dict()
		assert_eq([ui["id"], ui["set"], ui["origin"], ui["trait"], ui["clearance"]],
				[&"neon_rain", &"night_shift", &"mastery", &"veteran", 2], "UI dictionary (cc07 shape)")
		assert_eq([ui["top"], ui["side"], ui["bottom"], ui["name"]], [4, 6, 5, "Neon Rain"], "UI values")
	if ct != null:
		assert_eq(ct.to_ui_dict()["trait"], &"none", "store card UI trait")
	assert_eq(db.cards_in_set(&"night_shift").map(func(c: CardData) -> StringName: return c.id),
			[&"graveyard_shift", &"neon_rain", &"last_train", &"city_never_sleeps"], "set members in album order")


func test_balance_defaults_match_spec() -> void:
	var b: BalanceConfig = tree.root.get_node("CardDB").get_balance()
	assert_eq(b.wall_rows, PackedInt32Array([3, 4, 3]), "3/4/3 wall")
	assert_eq(b.slot_count(), 10, "10 slots")
	assert_eq(b.slot_ids(), [&"a1", &"a2", &"a3", &"b1", &"b2", &"b3", &"b4", &"c1", &"c2", &"c3"] as Array[StringName], "slot ids")
	assert_eq([b.lineup_size, b.clearance_cap, b.max_legends], [5, 12, 1], "5 cards, cap 12, 1 Legend")
	assert_eq([b.budget_for(1), b.budget_for(2), b.budget_for(3), b.budget_for(4), b.budget_for(5)], [13, 15, 17, 19, -1], "budgets")
	assert_eq([b.set_link_bonus, b.clutch_bonus, b.ambush_spring_bonus], [1, 2, 1], "bonuses")
	assert_eq([b.signature_value, b.triptych_bonus], [2, 1], "Signature x2, Triptych +1")
	# Tempo (cc06 Proposal A, decided 2026-11-04): first player +2, ties are draws.
	assert_eq(b.tie_winner, DataEnums.TieWinner.DRAW, "ties are draws")
	assert_eq(b.first_player_bonus, 2, "Tempo +2 for the first player")
	assert_false(b.chain_captures, "no chain captures")
	assert_eq([b.lobby_wait_min_s, b.lobby_wait_max_s], [60, 150], "lobby wait")


func test_origin_trait_table() -> void:
	var expected: Dictionary = {
		DataEnums.Origin.CHALLENGE: DataEnums.CardTrait.STEADY, DataEnums.Origin.MASTERY: DataEnums.CardTrait.VETERAN,
		DataEnums.Origin.EVENT: DataEnums.CardTrait.AMBUSH, DataEnums.Origin.PRESTIGE: DataEnums.CardTrait.RECLAIM,
		DataEnums.Origin.RANKED: DataEnums.CardTrait.CLUTCH, DataEnums.Origin.SECRET: DataEnums.CardTrait.CIPHER,
		DataEnums.Origin.SHOWCASE: DataEnums.CardTrait.NONE,
	}
	for origin: int in expected.keys():
		assert_eq(DataEnums.trait_for_origin(origin), expected[origin], "trait of %s" % DataEnums.key_of(DataEnums.Origin, origin))
	assert_eq(DataEnums.TRAIT_TEXT.size(), DataEnums.CardTrait.size(), "rule text per trait")
	assert_eq(DataEnums.clearance_name(4), "Legend", "Clearance 4 name")


func test_lineup_problems() -> void:
	var b: BalanceConfig = BalanceConfig.new()
	var d: Dictionary = _valid_set()
	var c: Callable = func(key: String) -> CardData: return d["cards/" + key]
	var legal: Array = [c.call("city_never_sleeps"), c.call("graveyard_shift"), c.call("neon_rain"), c.call("last_train"), c.call("frostbite")]
	assert_eq(b.lineup_problems(legal, c.call("neon_rain")).size(), 0, "legal lineup (Clearance 10, 1 Legend)")
	var short: Array = legal.slice(0, 4)
	assert_eq(b.lineup_problems(short, c.call("neon_rain")).size(), 1, "4 cards")
	var over: Array = [c.call("city_never_sleeps"), c.call("polar_night"), c.call("key_fragment"), c.call("neon_rain"), c.call("last_train")]
	assert_true(" ".join(b.lineup_problems(over, c.call("neon_rain"))).contains("cap is 12"), "Clearance 14 > cap")
	var second_legend: CardData = c.call("polar_night").duplicate()
	second_legend.clearance = 4
	var two_legends: Array = [c.call("city_never_sleeps"), second_legend, c.call("graveyard_shift"), c.call("frostbite"), c.call("chrome_tiger")]
	var problems: String = " ".join(b.lineup_problems(two_legends, c.call("frostbite")))
	assert_true(problems.contains("2 Legends"), "two Legends: " + problems)
	assert_true(" ".join(b.lineup_problems(legal, c.call("polar_night"))).contains("not in the lineup"), "Signature outside lineup")
	assert_true(" ".join(b.lineup_problems(legal, null)).contains("Signature"), "no Signature")
	var dup: Array = [c.call("neon_rain"), c.call("neon_rain"), c.call("graveyard_shift"), c.call("frostbite"), c.call("last_train")]
	assert_true(" ".join(b.lineup_problems(dup, c.call("neon_rain"))).contains("twice"), "duplicate card")
	c.call("neon_rain").signature_eligible = false
	assert_true(" ".join(b.lineup_problems(legal, c.call("neon_rain"))).contains("can't be a Signature"), "ineligible Signature")

# --- Valid set -----------------------------------------------------------------------

func test_valid_set_loads_and_indexes() -> void:
	var db: Node = _load_case(_valid_set())
	assert_true(db.is_valid(), "valid set has errors:\n" + "\n".join(db.get_errors()))
	var report: Dictionary = db.get_report()
	assert_eq(report["warnings"], 0, "valid set has no warnings: %s" % str(report["issues"]))
	assert_eq(report["counts"], {"cards": 10, "sets": 4, "rivals": 1, "triptychs": 1, "dossiers": 1, "unlocks": 4, "balance": 1}, "counts")
	assert_eq(db.get_card(&"neon_rain"), db.get_resource(&"neon_rain"), "lookup by id")
	assert_eq(db.all_sets().map(func(s: SetData) -> StringName: return s.id), [&"night_shift", &"whiteout", &"cipher", &"showcase"], "sets in album order")
	assert_eq(db.all_cards()[0].id, &"graveyard_shift", "first card in album order")
	assert_eq(db.cards_in_set(&"showcase").size(), 2, "showcase members")
	assert_eq(db.starting_cards().size(), 6, "6 cards owned at start")
	assert_eq(db.cards_unlocked_by(&"unlock_beat_warden")[0].id, &"city_never_sleeps", "goal -> card")
	var warden: RivalData = db.get_rival(&"warden")
	assert_not_null(warden, "rival")
	if warden != null:
		assert_eq(warden.total_clearance(), 10, "warden lineup Clearance")
		assert_eq(warden.signature, db.get_card(&"city_never_sleeps"), "rival -> card reference resolves")
	var trip: TriptychData = db.get_triptych(&"midnight_run")
	assert_true(trip != null and trip.has_card(db.get_card(&"last_train")), "triptych cards")
	var dossier: DossierData = db.get_dossier(&"dossier_carded")
	assert_true(dossier != null and dossier.reward_card == db.get_card(&"null_glyph"), "dossier reward")
	assert_eq(db.all_dossiers().size(), 1, "dossiers listed")
	assert_eq(db.get_balance().loaner_signature, db.get_card(&"neon_rain"), "loaner Signature")
	db.free()

# --- Bad data: each kind must be rejected ----------------------------------------------

func test_rejects_stat_total_off_budget() -> void:
	var data: Dictionary = _valid_set()
	data["cards/neon_rain"].side = 7          # 4+7+5 = 16, Clearance 2 needs 15
	data["cards/graveyard_shift"].clearance = 2  # 13, Clearance 2 needs 15
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "off-budget stats accepted")
	assert_true(db.has_issue(DataValidator.BUDGET_MISMATCH, "neon_rain", "clearance"), "16 vs 15")
	assert_true(db.has_issue(DataValidator.BUDGET_MISMATCH, "graveyard_shift", "clearance"), "13 vs 15")
	assert_eq(db.get_errors().size(), 2, "only the two budget errors:\n" + "\n".join(db.get_errors()))
	db.free()


func test_budget_follows_balance_config() -> void:
	var data: Dictionary = _valid_set()
	data["balance"].stat_budgets = PackedInt32Array([14, 16, 18, 20])
	var db: Node = _load_case(data)
	assert_true(db.has_issue(DataValidator.BUDGET_MISMATCH, "frostbite"), "cards checked against the tuned budgets")
	db.free()


func test_rejects_store_card_above_clearance_1() -> void:
	var data: Dictionary = _valid_set()
	var gold: CardData = data["cards/gold_leaf"]
	gold.clearance = 2
	gold.top = 5; gold.side = 5; gold.bottom = 5   # on budget, so only the store rule fires
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "Clearance 2 store card accepted")
	assert_true(db.has_issue(DataValidator.STORE_RULE, "gold_leaf", "clearance"), "store_rule reported")
	assert_eq(db.get_errors().size(), 1, "only the store error:\n" + "\n".join(db.get_errors()))
	db.free()


func test_rejects_store_cards_with_traits_or_outside_showcase() -> void:
	var data: Dictionary = _valid_set()
	data["cards/chrome_tiger"].origin = DataEnums.Origin.MASTERY  # store card with a trait
	data["cards/gold_leaf"].is_store = false                     # Showcase origin, not flagged
	data["cards/frostbite"].card_set = data["sets/showcase"]     # earned card in the store set
	var db: Node = _load_case(data)
	var S: String = DataValidator.STORE_RULE
	assert_true(db.has_issue(S, "chrome_tiger", "origin"), "store card with a trait")
	assert_true(db.has_issue(S, "gold_leaf", "is_store"), "SHOWCASE origin needs the store flag")
	assert_true(db.has_issue(S, "frostbite", "card_set"), "earned card in a SHOWCASE set")
	db.free()


func test_rejects_duplicate_ids_and_numbers() -> void:
	var data: Dictionary = _valid_set()
	data["cards/neon_rain_copy"] = data["cards/neon_rain"].duplicate()
	data["cards/last_train"].album_order = 1          # same as graveyard_shift
	data["cards/neon_rain"].cipher_glyph = 1          # same glyph as graveyard_shift
	data["sets/whiteout"].number = 1                  # same as night_shift
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "duplicates accepted")
	var V: String = DataValidator.INVALID_VALUE
	assert_true(db.has_issue(DataValidator.DUPLICATE_ID, "neon_rain"), "duplicate id")
	assert_true(db.has_issue(V, "night_shift", "album_order"), "duplicate album_order")
	assert_true(db.has_issue(V, "", "cipher_glyph"), "glyph used twice")
	assert_true(db.has_issue(V, "", "number"), "set number used twice")
	db.free()


func test_rejects_missing_required_fields() -> void:
	var data: Dictionary = _valid_set()
	var nr: CardData = data["cards/neon_rain"]
	nr.display_name = ""
	nr.how_earned = ""
	nr.art_key = &""
	data["cards/frostbite"].card_set = null
	data["cards/polar_night"].unlock_goal = null       # locked card with no goal
	data["sets/whiteout"].completion_title = ""
	data["triptychs/midnight_run"].hint = ""
	data["dossiers/dossier_carded"].solution.clear()
	var blank: CardData = CardData.new()               # nothing set at all
	blank.id = &"blank_card"
	data["cards/blank_card"] = blank
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "missing fields accepted")
	var M: String = DataValidator.MISSING_FIELD
	assert_true(db.has_issue(M, "neon_rain", "display_name"), "empty name")
	assert_true(db.has_issue(M, "neon_rain", "how_earned"), "empty how_earned")
	assert_true(db.has_issue(M, "neon_rain", "art_key"), "empty art key")
	assert_true(db.has_issue(M, "frostbite", "card_set"), "card without set")
	assert_true(db.has_issue(M, "polar_night", "unlock_goal"), "locked card without goal")
	assert_true(db.has_issue(M, "whiteout", "completion_title"), "set without title")
	assert_true(db.has_issue(M, "midnight_run", "hint"), "triptych without hint")
	assert_true(db.has_issue(M, "dossier_carded", "solution"), "dossier without solution")
	var R: String = DataValidator.OUT_OF_RANGE
	for field: String in ["top", "side", "bottom", "clearance", "album_order"]:
		assert_true(db.has_issue(R, "blank_card", field), "unset %s caught" % field)
	db.free()


func test_rejects_missing_balance_file() -> void:
	var data: Dictionary = _valid_set()
	data.erase("balance")
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "missing balance.tres accepted")
	assert_true(db.has_issue(DataValidator.MISSING_FIELD, "balance", "balance"), "balance missing reported")
	assert_eq(db.get_balance().lineup_size, 5, "defaults still usable")
	db.free()


func test_rejects_out_of_range_values() -> void:
	var data: Dictionary = _valid_set()
	data["cards/neon_rain"].top = 10
	data["cards/last_train"].clearance = 5
	data["triptychs/midnight_run"].cards.pop_back()
	data["balance"].cipher_code = PackedInt32Array([1, 2, 3])
	data["balance"].lineup_size = 6
	data["unlocks/unlock_win_streak_3"].target_count = 0
	for i: int in 4:  # whiteout grows to 6 + 1 = 7 cards
		var extra: CardData = data["cards/frostbite"].duplicate()
		extra.id = StringName("whiteout_extra_%d" % i)
		extra.album_order = 3 + i
		extra.cipher_glyph = 0
		data["cards/whiteout_extra_%d" % i] = extra
	var seventh: CardData = data["cards/whiteout_extra_0"].duplicate()
	seventh.id = &"whiteout_extra_9"
	seventh.album_order = 9
	data["cards/whiteout_extra_9"] = seventh
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "out-of-range accepted")
	var R: String = DataValidator.OUT_OF_RANGE
	assert_true(db.has_issue(R, "neon_rain", "top"), "top 10")
	assert_true(db.has_issue(R, "last_train", "clearance"), "Clearance 5")
	assert_true(db.has_issue(R, "midnight_run", "cards"), "triptych of 2")
	assert_true(db.has_issue(R, "balance", "cipher_code"), "3-glyph code")
	assert_true(db.has_issue(R, "balance", "lineup_size"), "two lineups of 6 on 10 slots")
	assert_true(db.has_issue(R, "unlock_win_streak_3", "target_count"), "streak of 0")
	assert_true(db.has_issue(R, "whiteout", "cards"), "set of 7 cards")
	db.free()


func test_rejects_illegal_rival_and_loaner_lineups() -> void:
	var data: Dictionary = _valid_set()
	var warden: RivalData = data["rivals/warden"]
	warden.lineup[4] = data["cards/key_fragment"]      # 4+1+2+2+3 = 12: still legal
	warden.lineup[1] = data["cards/polar_night"]       # 4+3+2+2+3 = 14 > 12
	data["balance"].loaner_lineup.pop_back()           # 4 cards
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "illegal lineups accepted")
	assert_true(db.has_issue(DataValidator.LINEUP_RULE, "warden", "lineup"), "rival over the Clearance cap")
	assert_true(db.has_issue(DataValidator.LINEUP_RULE, "balance", "loaner_lineup"), "loaner of 4")
	db.free()


func test_rejects_broken_references() -> void:
	var data: Dictionary = _valid_set()
	# A set saved outside the data folder: it loads, but isn't registered data.
	var stray: SetData = data["sets/whiteout"].duplicate()
	stray.id = &"stray_set"
	_ensure_dir(TEST_ROOT.path_join("outside"))
	_save(stray, TEST_ROOT.path_join("outside/stray_set.tres"))
	data["cards/frostbite"].card_set = stray
	data["unlocks/unlock_beat_warden"].target_id = &"no_such_rival"
	data["unlocks/unlock_dossier_4"].target_id = &"warden"   # a rival where a Dossier is expected
	data["triptychs/midnight_run"].cards[2] = null
	var db: Node = _load_case(data, {"cards/broken_dep.tres": _tres_with_missing_dependency()})
	assert_false(db.is_valid(), "broken refs accepted")
	assert_true(db.has_issue(DataValidator.BROKEN_REFERENCE, "frostbite", "card_set"), "set outside data/")
	assert_true(db.has_issue(DataValidator.BROKEN_REFERENCE, "unlock_beat_warden", "target_id"), "unknown rival id")
	assert_true(db.has_issue(DataValidator.WRONG_TYPE, "unlock_dossier_4", "target_id"), "rival id for a Dossier goal")
	assert_true(db.has_issue(DataValidator.BROKEN_REFERENCE, "midnight_run", "cards[2]"), "empty triptych slot")
	assert_true(db.has_issue(DataValidator.LOAD_FAILED), "file with a missing dependency")
	db.free()


func test_rejects_invalid_values() -> void:
	var data: Dictionary = _valid_set()
	data["cards/neon_rain"].origin = 9 as DataEnums.Origin     # not an enum value
	data["cards/last_train"].id = &"Last-Train"                # bad id format
	data["cards/graveyard_shift"].unlock_goal = data["unlocks/unlock_win_streak_3"]  # owned and locked
	data["cards/chrome_tiger"].cipher_glyph = 3                # glyph on a store card
	data["balance"].wall_rows = PackedInt32Array([3, 3, 3])    # not a brick layout
	data["balance"].stat_budgets = PackedInt32Array([13, 15, 15, 19])
	data["unlocks/unlock_cipher_lock"].target_count = 2        # CIPHER_LOCK has no count
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "invalid values accepted")
	var V: String = DataValidator.INVALID_VALUE
	assert_true(db.has_issue(V, "neon_rain", "origin"), "bad enum")
	assert_true(db.has_issue(V, "Last-Train", "id"), "bad id format")
	assert_true(db.has_issue(V, "graveyard_shift", "unlock_goal"), "owned card with a goal")
	assert_true(db.has_issue(V, "chrome_tiger", "cipher_glyph"), "glyph outside main sets")
	assert_true(db.has_issue(V, "balance", "wall_rows"), "3/3/3 wall")
	assert_true(db.has_issue(V, "balance", "stat_budgets[2]"), "budgets must rise")
	assert_true(db.has_issue(V, "unlock_cipher_lock", "target_count"), "count on CIPHER_LOCK")
	db.free()


func test_rejects_bad_dossiers() -> void:
	var data: Dictionary = _valid_set()
	var d: DossierData = data["dossiers/dossier_carded"]
	d.board[0].slot = &"d9"                                     # not a wall slot
	d.board[0].is_signature = false                             # Signature goal with no rival Signature
	d.board.append(_placement(&"b2", data["cards/frostbite"], DataEnums.Side.RIVAL))
	d.board[1].face_down = true                                 # Steady card face-down
	d.solution.append(_placement(&"b2", data["cards/polar_night"], DataEnums.Side.PLAYER))  # slot taken, card not in hand
	d.reward_card = null                                        # and no title or frame either
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "bad dossier accepted")
	var V: String = DataValidator.INVALID_VALUE
	assert_true(db.has_issue(V, "dossier_carded", "board[0].slot"), "slot d9")
	assert_true(db.has_issue(V, "dossier_carded", "board[1].face_down"), "face-down non-Ambush")
	assert_true(db.has_issue(V, "dossier_carded", "solution[1].slot"), "slot used twice")
	assert_true(db.has_issue(V, "dossier_carded", "solution[1].card"), "solution card not in hand")
	assert_true(db.has_issue(DataValidator.OUT_OF_RANGE, "dossier_carded", "solution"), "more placements than allowed")
	assert_true(db.has_issue(V, "dossier_carded", "goal"), "Signature goal without a rival Signature")
	assert_true(db.has_issue(DataValidator.MISSING_FIELD, "dossier_carded", "reward_card"), "no reward")
	db.free()


func test_rejects_unknown_resource_type() -> void:
	var data: Dictionary = _valid_set()
	data["cards/not_a_card"] = Gradient.new()
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "foreign resource accepted")
	assert_true(db.has_issue(DataValidator.UNKNOWN_TYPE), "unknown_type reported")
	db.free()


func test_warnings_do_not_fail_the_load() -> void:
	var data: Dictionary = _valid_set()
	data.erase("cards/gold_leaf")             # showcase set drops to 1 card
	data["balance"].loaner_lineup.clear()
	data["balance"].loaner_signature = null
	var db: Node = _load_case(data)
	assert_true(db.is_valid(), "warnings only:\n" + "\n".join(db.get_errors()))
	assert_true(db.has_issue(DataValidator.OUT_OF_RANGE, "showcase", "cards", true), "small set warned")
	assert_true(db.has_issue(DataValidator.MISSING_FIELD, "balance", "loaner_lineup", true), "no loaner warned")
	assert_eq(db.get_report()["warnings"], 2, "two warnings")
	db.free()


func test_issue_report_shape() -> void:
	var data: Dictionary = _valid_set()
	data["cards/neon_rain"].side = 7
	var db: Node = _load_case(data)
	var report: Dictionary = db.get_report()
	assert_false(report["ok"], "report ok flag")
	assert_eq(report["errors"], 1, "exactly one error")
	var issue: Dictionary = report["issues"][0]
	for key: String in ["severity", "code", "file", "id", "field", "message"]:
		assert_true(issue.has(key), "issue has %s" % key)
	assert_true(String(issue["file"]).ends_with("neon_rain.tres"), "issue names the file")
	assert_true(String(issue["message"]).contains("needs 15"), "message names the budget")
	assert_eq(db.get_errors().size(), 1, "get_errors lines")
	db.free()

# --- Fixture builders ------------------------------------------------------------------

## A complete, valid data set (spec §6 values). Keys are "<folder>/<file>" (saved as <key>.tres).
func _valid_set() -> Dictionary:
	var d: Dictionary = {}
	var night: SetData = _make_set(&"night_shift", 1, DataEnums.SetKind.STANDARD, "Night Owl")
	var white: SetData = _make_set(&"whiteout", 2, DataEnums.SetKind.STANDARD, "Snowblind")
	var cipher: SetData = _make_set(&"cipher", 5, DataEnums.SetKind.CIPHER, "")
	var show: SetData = _make_set(&"showcase", 6, DataEnums.SetKind.SHOWCASE, "")
	for s: SetData in [night, white, cipher, show]:
		d["sets/" + String(s.id)] = s

	var g_warden: UnlockGoal = _goal(&"unlock_beat_warden", DataEnums.UnlockKind.BEAT_RIVAL, 0, &"warden")
	var g_streak: UnlockGoal = _goal(&"unlock_win_streak_3", DataEnums.UnlockKind.WIN_STREAK, 3, &"")
	var g_d4: UnlockGoal = _goal(&"unlock_dossier_4", DataEnums.UnlockKind.DOSSIER_CLEAR, 0, &"dossier_carded")
	var g_lock: UnlockGoal = _goal(&"unlock_cipher_lock", DataEnums.UnlockKind.CIPHER_LOCK, 0, &"")
	for g: UnlockGoal in [g_warden, g_streak, g_d4, g_lock]:
		d["unlocks/" + String(g.id)] = g

	var O: Dictionary = DataEnums.Origin
	var cards: Array[CardData] = [
		_card(&"graveyard_shift", night, 1, [5, 4, 4], 1, O.CHALLENGE, 1, null),
		_card(&"neon_rain", night, 2, [4, 6, 5], 2, O.MASTERY, 0, null),
		_card(&"last_train", night, 3, [6, 4, 5], 2, O.EVENT, 3, null),
		_card(&"city_never_sleeps", night, 4, [7, 5, 7], 4, O.PRESTIGE, 0, g_warden),
		_card(&"frostbite", white, 1, [3, 6, 4], 1, O.CHALLENGE, 2, null),
		_card(&"polar_night", white, 2, [5, 7, 5], 3, O.RANKED, 4, g_streak),
		_card(&"null_glyph", cipher, 1, [5, 5, 5], 2, O.SECRET, 0, g_d4),
		_card(&"key_fragment", cipher, 2, [6, 5, 6], 3, O.SECRET, 0, g_lock),
		_card(&"chrome_tiger", show, 1, [5, 4, 4], 1, O.SHOWCASE, 0, null),
		_card(&"gold_leaf", show, 2, [4, 5, 4], 1, O.SHOWCASE, 0, null),
	]
	for c: CardData in cards:
		c.is_store = c.origin == DataEnums.Origin.SHOWCASE
		d["cards/" + String(c.id)] = c
	var card: Callable = func(id: String) -> CardData: return d["cards/" + id]

	var warden: RivalData = RivalData.new()
	warden.id = &"warden"
	warden.display_name = "Warden"
	warden.difficulty = DataEnums.Difficulty.HARD
	warden.art_key = &"rival_warden"
	warden.lineup.assign([card.call("city_never_sleeps"), card.call("graveyard_shift"), card.call("neon_rain"),
			card.call("last_train"), card.call("frostbite")])
	warden.signature = card.call("city_never_sleeps")
	warden.lookahead_plies = 2
	warden.signature_safety_weight = 2.0
	d["rivals/warden"] = warden

	var trip: TriptychData = TriptychData.new()
	trip.id = &"midnight_run"
	trip.display_name = "Midnight Run"
	trip.cards.assign([card.call("graveyard_shift"), card.call("neon_rain"), card.call("last_train")])
	trip.hint = "The city's last ride, three stops long."
	trip.reward_title = "Night Owl+"
	trip.panorama_key = &"pano_midnight_run"
	d["triptychs/midnight_run"] = trip

	var dossier: DossierData = DossierData.new()
	dossier.id = &"dossier_carded"
	dossier.number = 4
	dossier.display_name = "Carded"
	dossier.teaches = "Signature, Reclaim"
	var sig: DossierPlacement = _placement(&"a1", card.call("frostbite"), DataEnums.Side.RIVAL)
	sig.is_signature = true
	dossier.board.assign([sig])
	dossier.player_hand.assign([card.call("neon_rain"), card.call("city_never_sleeps")])
	dossier.goal = DataEnums.DossierGoal.CAPTURE_SIGNATURE_AND_WIN
	dossier.max_placements = 1
	dossier.solution.assign([_placement(&"b1", card.call("neon_rain"), DataEnums.Side.PLAYER)])
	dossier.reward_card = card.call("null_glyph")
	d["dossiers/dossier_carded"] = dossier

	var balance: BalanceConfig = BalanceConfig.new()
	balance.loaner_lineup.assign([card.call("graveyard_shift"), card.call("neon_rain"), card.call("last_train"),
			card.call("frostbite"), card.call("chrome_tiger")])
	balance.loaner_signature = card.call("neon_rain")
	d["balance"] = balance
	return d


func _make_set(id: StringName, number: int, kind: DataEnums.SetKind, title: String) -> SetData:
	var s: SetData = SetData.new()
	s.id = id
	s.display_name = String(id).capitalize()
	s.number = number
	s.kind = kind
	s.palette_key = id
	s.completion_title = title
	return s


func _goal(id: StringName, kind: DataEnums.UnlockKind, count: int, target: StringName) -> UnlockGoal:
	var g: UnlockGoal = UnlockGoal.new()
	g.id = id
	g.kind = kind
	g.target_count = count
	g.target_id = target
	g.description = String(id).capitalize()
	return g


func _card(id: StringName, card_set: SetData, order: int, tsb: Array, clearance: int, origin: int,
		glyph: int, goal: UnlockGoal) -> CardData:
	var c: CardData = CardData.new()
	c.id = id
	c.display_name = String(id).capitalize()
	c.card_set = card_set
	c.album_order = order
	c.top = tsb[0]
	c.side = tsb[1]
	c.bottom = tsb[2]
	c.clearance = clearance
	c.origin = origin
	c.cipher_glyph = glyph
	c.how_earned = "Test card"
	c.art_key = id
	c.starts_owned = goal == null
	c.unlock_goal = goal
	return c


func _placement(slot: StringName, card: CardData, side: DataEnums.Side) -> DossierPlacement:
	var p: DossierPlacement = DossierPlacement.new()
	p.slot = slot
	p.card = card
	p.side = side
	return p


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
	var saved: Dictionary = {}
	for prefix: String in SAVE_ORDER:
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

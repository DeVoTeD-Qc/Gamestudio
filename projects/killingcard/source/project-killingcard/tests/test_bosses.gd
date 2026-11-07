# test_bosses.gd
# Purpose: kc-v2-impl bosses (run-v2.md §4): Meridian_Six's Reinforcements, Bulwark Prime's Dug In,
#   The Hollow Choir's Horde (Shamblers), the boss data and boss_view(); the boss rotation (V3).
# Author: Mechanics Developer Agent (kc-v2-impl)
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const E: int = 1


func _shipped() -> RunConfig:
	return load("res://data/run_config.tres") as RunConfig


func _boss_match(rule: StringName, card: CardData = null) -> MatchState:
	var m: MatchState = MatchState.new(null, F.flat_map(), F.setup(), F.setup(), 1, null)
	m.boss_id = &"test"
	m.boss_rule = rule
	m.boss_card = card
	m.boss_rule_name = String(rule).capitalize()
	m.start_match()
	return m


func test_reinforcements_extra_supply_from_round_5() -> void:
	var m: MatchState = _boss_match(BossRules.REINFORCEMENTS)
	assert_eq(_shipped().meridian_supply_from, 5, "shipped: from round 5 (head I2)")
	for r: int in range(1, 7):
		var base: int = m.config.supply_for_round(r)
		var want: int = base + (1 if r >= 5 else 0)
		assert_eq([m.round_number, m.sides[E].supply, m.sides[P].supply], [r, want, base], "round %d" % r)
		m.resolve_round()
		m.begin_round()
	assert_true(F.events_of(m, RulesEvent.BOSS_RULE_TRIGGERED).size() >= 2, "logged each round")
	assert_true(m.boss_view()["active"], "the plate is lit from round 5")
	assert_eq(m.boss_view()["note"], "From round 5", "plate note")


func test_dug_in_pits_in_every_column_and_overrun_tears_one_down() -> void:
	var pit: CardData = load("res://data/cards/mortar_pit.tres")
	var m: MatchState = _boss_match(BossRules.DUG_IN, pit)
	for z: int in 3:
		assert_eq(m.fields_in(E, z).size(), 1, "a pit in column %d" % z)
		assert_eq((m.fields_in(E, z)[0]["card"] as RulesCard).card.id, &"mortar_pit", "a real Mortar Pit")
	F.place(m, P, F.unit("taker", 0, 9), F.LEFT)
	m.resolve_round()
	assert_eq(m.fields_in(E, 0).size(), 0, "Overrun tears it down")
	assert_eq(m.fields_in(E, 1).size(), 1, "the others stand")
	assert_eq(F.events_of(m, RulesEvent.BOSS_RULE_TRIGGERED).size(), 3, "three pits logged")


func test_horde_shamblers_from_round_2_in_the_emptiest_column() -> void:
	var sh: CardData = load("res://data/cards/shambler.tres")
	var m: MatchState = _boss_match(BossRules.HORDE, sh)
	assert_eq(m.sides[E].units_on_board().size(), 0, "none in round 1")
	F.place(m, E, F.unit("x", 0, 5), F.LEFT)
	F.place(m, E, F.unit("y", 0, 5), F.MID)
	m.resolve_round()
	m.begin_round()
	assert_eq(F.line_ids(m, E, F.RIGHT), [&"shambler"] as Array[StringName], "a Shambler joins the emptiest column")
	var s: RulesUnit = m.sides[E].line(F.RIGHT)[0]
	assert_eq([s.base_firepower, s.armor, s.counts_for_control], [1, 2, false], "1/2, doesn't hold ground")
	assert_true(m.is_untargetable_by_pick_flank(s), "Pick and Flank ignore it")
	assert_eq(m.control_of(F.RIGHT), MatchState.CONTROL_EMPTY, "no control")
	# A Marksman in its column shoots past it; killing it counts for the streak.
	F.place(m, P, F.marksman(), F.RIGHT)
	var guard: RulesUnit = F.place(m, E, F.unit("guard", 0, 9), F.RIGHT)
	guard.armor = 5
	m.firefight()
	assert_eq(guard.armor, 3, "Pick skips the Shambler (lowest Armor) for the next eligible unit")
	F.place(m, P, F.unit("brute", 3, 9), F.MID)
	var mid_sh: RulesUnit = m.create_unit(E, sh)
	m.sides[E].lines[1].insert(0, mid_sh)
	mid_sh.zone = 1
	m.firefight()
	assert_false(mid_sh.is_alive(), "Shambler shot")
	assert_true(m.sides[P].eliminations >= 1, "its kill is credited")


## kc-v2-tune: every player-facing boss string reads its round from the config (no hard-coded "round 4").
func test_boss_texts_follow_the_rule_numbers() -> void:
	var cfg: RunConfig = (_shipped()).duplicate(false) as RunConfig
	for from: int in [5, 6]:
		cfg.meridian_supply_from = from
		var r: RunProgress = RunProgress.create_map_run(cfg, 3, {"boss": &"meridian"})
		var bv: Dictionary = r.boss_view()
		var want: String = "round %d" % from
		assert_true(String(bv["rule_text"]).contains(want) and String(bv["tip"]).contains(want), "run boss view says %s" % want)
		assert_eq(int(bv["start_round"]), from, "start_round")
		for k: String in ["rule_text", "tip"]:
			assert_false(String(bv[k]).contains("{"), "no placeholder left")
		var m: MatchState = MatchState.new(cfg, null, F.setup(), F.setup(), 1, null)
		m.boss_rule = BossRules.REINFORCEMENTS
		var b: RunMatchData = cfg.bosses[0]
		m.boss_rule_text = b.boss_rule_text
		m.boss_tip = b.boss_tip
		m.start_match()
		var mv: Dictionary = m.boss_view()
		for k2: String in ["text", "rule_text", "tip", "note"]:
			assert_true(String(mv[k2]).contains(want), "match boss %s says %s" % [k2, want])
	for b2: RunMatchData in _shipped().bosses:
		assert_false(b2.boss_rule_text.contains("round 4") or b2.boss_tip.contains("round 4"), "%s: no hard-coded round" % b2.boss_id)
		assert_true(b2.boss_tip != "", "%s has a tip" % b2.boss_id)
	var choir: Dictionary = RunProgress.create_map_run(_shipped(), 3, {"boss": &"choir"}).boss_view()
	assert_true(String(choir["rule_text"]).begins_with("From round 2,"), "the Choir's round comes from choir_from_round")


func test_boss_data_in_the_config() -> void:
	var cfg: RunConfig = load("res://data/run_config.tres")
	assert_true(cfg.run_map, "the shipped config is a map run")
	assert_eq(cfg.bosses.map(func(b: RunMatchData) -> StringName: return b.boss_id), [&"meridian", &"prime", &"choir"], "three bosses")
	var rules: Array = cfg.bosses.map(func(b: RunMatchData) -> StringName: return b.boss_rule)
	assert_eq(rules, [&"reinforcements", &"dug_in", &"horde"], "one rule each")
	var choir: RunMatchData = cfg.bosses[2]
	assert_eq(choir.squad.identity_trait, &"undead", "the Choir is Undead")
	assert_eq(choir.deck_for_squad().size(), 20, "20-card authored deck")
	assert_eq([cfg.bosses[0].enemy_armor_bonus, cfg.bosses[1].enemy_armor_bonus, choir.enemy_armor_bonus], [1, 1, 2], "boss Armor")
	assert_eq(cfg.bosses[1].mode, DataEnums.GameMode.FIREFIGHT, "Prime plays Firefight")


func test_boss_rotation_never_repeats_and_first_run_is_meridian() -> void:
	var cfg: RunConfig = load("res://data/run_config.tres")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	assert_eq(RunProfile.pick_boss(RunProfile.blank(), cfg, rng), &"meridian", "the first run: Meridian_Six")
	var p: Dictionary = RunProfile.blank()
	p["runs_finished"] = 1
	p["last_boss"] = "meridian"
	for i: int in 20:
		rng.seed = i
		assert_eq(RunProfile.pick_boss(p, cfg, rng), &"prime", "after run 1 only Prime is new (Choir locked, no repeat)")
	p["run_wins"] = 1
	p["last_boss"] = "prime"
	var seen: Dictionary = {}
	for i: int in 40:
		rng.seed = i
		var b: StringName = RunProfile.pick_boss(p, cfg, rng)
		assert_true(b != &"prime", "never the same twice in a row")
		seen[b] = true
	assert_eq(seen.size(), 2, "Meridian and the Choir both come up")

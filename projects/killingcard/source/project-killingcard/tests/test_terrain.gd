# test_terrain.gd
# Purpose: kc-v2-impl Terrain (run-v2.md §6): each of the 10 rules, for both sides; Terrain with Field
#   cards; MatchClone; the AI view; the data and the deal.
# Author: Mechanics Developer Agent (kc-v2-impl)
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const E: int = 1


## A started match with `ter` dealt (3 ids) before start_match.
func _m(ter: Array, player: SideSetup = null, enemy: SideSetup = null, hooks: MatchHooks = null) -> MatchState:
	var m: MatchState = MatchState.new(null, F.flat_map(), player if player != null else F.setup(),
			enemy if enemy != null else F.setup(), 1, hooks)
	for z: int in 3:
		m.terrain[z] = StringName(ter[z])
	m.start_match()
	return m


func test_rooftops_first_shot_for_the_side_holding_it_at_the_start_of_the_round() -> void:
	var m: MatchState = _m([&"", &"rooftops", &""])
	var mine: RulesUnit = F.place(m, P, F.unit("a", 2, 2), F.MID)
	m.begin_round()  # Briefing: the player holds B
	assert_eq(m.held_at_start[1], P, "held at the start of the round")
	var theirs: RulesUnit = F.place(m, E, F.unit("b", 2, 2), F.MID)
	assert_true(m.has_first_shot(mine), "the holder has First Shot on Rooftops")
	assert_false(m.has_first_shot(theirs), "the arriving side does not")
	m.firefight()
	assert_true(mine.is_alive(), "the holder fires first and wins the exchange")
	assert_false(theirs.is_alive(), "the arriving unit dies before firing")
	# Mirror: the enemy holds it.
	var m2: MatchState = _m([&"rooftops", &"", &""])
	var e2: RulesUnit = F.place(m2, E, F.unit("e", 2, 2), F.LEFT)
	m2.begin_round()
	var p2: RulesUnit = F.place(m2, P, F.unit("p", 2, 2), F.LEFT)
	assert_true(m2.has_first_shot(e2) and not m2.has_first_shot(p2), "both sides get it")
	assert_eq(m2.terrain_view()[0]["held_by"], &"enemy", "terrain_view names the holder")


func test_smoke_turns_pick_and_flank_off() -> void:
	var m: MatchState = _m([&"smoke", &"", &""])
	F.place(m, P, F.marksman(), F.LEFT)
	var front: RulesUnit = F.place(m, E, F.unit("front", 0, 5), F.LEFT)
	var weak: RulesUnit = F.place(m, E, F.unit("weak", 0, 1), F.LEFT)
	F.place(m, P, F.marksman(), F.MID)
	var front2: RulesUnit = F.place(m, E, F.unit("front2", 0, 5), F.MID)
	var weak2: RulesUnit = F.place(m, E, F.unit("weak2", 0, 1), F.MID)
	assert_false(m.can_pick(m.sides[P].line(F.LEFT)[0]), "no Pick in Smoke")
	m.firefight()
	assert_eq([front.armor, weak.is_alive()], [3, true], "Smoke: the Marksman hits the front unit")
	assert_eq([front2.armor, weak2.is_alive()], [5, false], "elsewhere Pick works")
	var m2: MatchState = _m([&"smoke", &"", &""])
	F.place(m2, E, F.flanker(), F.LEFT)
	var pf: RulesUnit = F.place(m2, P, F.unit("pf", 0, 5), F.LEFT)
	var pb: RulesUnit = F.place(m2, P, F.unit("pb", 0, 5), F.LEFT)
	m2.firefight()
	assert_eq([pf.armor, pb.armor], [3, 5], "the enemy's Flank is off too")


func test_dust_storm_takes_first_shot_away() -> void:
	var m: MatchState = _m([&"", &"", &"dust_storm"])
	var pm: RulesUnit = F.place(m, P, F.point_man(), F.RIGHT)
	var rf: RulesUnit = F.place(m, E, F.rifleman(), F.RIGHT)
	assert_false(m.has_first_shot(pm), "no First Shot in a Dust Storm")
	m.firefight()
	assert_eq([pm.armor, rf.is_alive()], [1, false], "both fire together")
	var pm2: RulesUnit = F.place(m, E, F.point_man(), F.LEFT)
	assert_true(m.has_first_shot(pm2), "First Shot outside the storm")


func test_breach_point_gives_every_unit_pierce() -> void:
	var m: MatchState = _m([&"breach_point", &"", &""])
	F.place(m, P, F.unit("big", 5, 9), F.LEFT)
	var a: RulesUnit = F.place(m, E, F.unit("a", 0, 2), F.LEFT)
	var b: RulesUnit = F.place(m, E, F.unit("b", 0, 5), F.LEFT)
	assert_true(m.has_pierce(m.sides[P].line(F.LEFT)[0]), "Pierce on Breach Point")
	m.firefight()
	assert_false(a.is_alive(), "front dies")
	assert_eq(b.armor, 2, "3 carries to the next unit")
	assert_false(m.has_pierce(F.place(m, E, F.unit("c", 1, 1), F.MID)), "no Pierce elsewhere")


func test_floodlights_show_red_dots_face_up_to_both_sides() -> void:
	var m: MatchState = _m([&"", &"floodlights", &""], F.setup([F.rifleman(), F.rifleman()]), F.setup([F.rifleman(), F.rifleman()]))
	m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "rifleman"), F.MID))
	m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "rifleman"), F.LEFT))
	m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "rifleman"), F.MID))
	assert_eq(m.revealed_red_dots(P, F.MID), [&"rifleman"] as Array[StringName], "the player sees the floodlit column")
	assert_eq(m.revealed_red_dots(P, F.LEFT).size(), 0, "not the others")
	assert_eq(m.revealed_red_dots(E, F.MID), [&"rifleman"] as Array[StringName], "the enemy too")
	m.fog_of_war = true
	assert_eq(m.revealed_red_dots(P, F.MID).size(), 0, "Fog of War hides it")
	assert_eq(m.red_dots(P), PackedInt32Array([0, 0, 0]), "Fog of War: no red dots")


func test_comms_tower_streak_for_the_holder() -> void:
	var m: MatchState = _m([&"comms_tower", &"", &""])
	F.place(m, P, F.unit("a", 0, 5), F.LEFT)
	F.place(m, E, F.unit("b", 0, 5), F.MID)
	m.reveal()
	m.firefight()
	m.score()
	assert_eq([m.sides[P].streak, m.sides[E].streak], [1, 0], "+1 streak for holding the tower")
	assert_eq(F.events_of(m, RulesEvent.TERRAIN_TRIGGERED).size(), 1, "logged")


func test_supply_cache_supply_next_round() -> void:
	var m: MatchState = _m([&"", &"", &"supply_cache"])
	F.place(m, E, F.unit("b", 0, 5), F.RIGHT)
	m.reveal()
	m.firefight()
	m.score()
	m.begin_round()
	assert_eq(m.sides[E].supply, m.config.supply_for_round(2) + 1, "holder +1 Supply")
	assert_eq(m.sides[P].supply, m.config.supply_for_round(2), "the other side not")
	m.reveal()
	m.firefight()
	m.sides[E].lines[2].clear()
	m.score()
	m.begin_round()
	assert_eq(m.sides[E].supply, m.config.supply_for_round(3), "only after a round you held it")


func test_hot_zone_scores_one_extra_point_in_zone_control() -> void:
	var h: MatchHooks = MatchHooks.new()
	h.mode_rules = ModeRules.create(DataEnums.GameMode.ZONE_CONTROL, RunConfig.new())
	var m: MatchState = _m([&"hot_zone", &"", &""], null, null, h)
	F.place(m, P, F.unit("a", 0, 5), F.LEFT)
	F.place(m, E, F.unit("b", 0, 5), F.MID)
	m.resolve_round()
	assert_eq([m.sides[P].score, m.sides[E].score], [2, 1], "Hot Zone counts double")
	var h2: MatchHooks = MatchHooks.new()
	h2.mode_rules = ModeRules.create(DataEnums.GameMode.FIREFIGHT, RunConfig.new())
	var m2: MatchState = _m([&"hot_zone", &"", &""], null, null, h2)
	F.place(m2, P, F.unit("a", 0, 5), F.LEFT)
	m2.resolve_round()
	assert_eq(m2.sides[P].score, 0, "no extra points in Firefight")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for i: int in 50:
		rng.seed = i
		assert_false(TerrainRules.HOT_ZONE in TerrainRules.deal(rng, 2, DataEnums.GameMode.FIREFIGHT), "never dealt in Firefight")


func test_minefield_hits_the_first_arrival_of_each_side() -> void:
	var deck: Array = [F.unit("one", 0, 3), F.unit("two", 0, 3)]
	var m: MatchState = _m([&"", &"minefield", &""], F.setup(deck), F.setup([F.unit("foe", 0, 3)]))
	m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "one"), F.MID))
	m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "two"), F.MID))
	m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "foe"), F.MID))
	m.reveal()
	var line: Array = m.sides[P].line(F.MID)
	assert_eq([(line[0] as RulesUnit).armor, (line[1] as RulesUnit).armor], [2, 3], "only the first unit takes 1")
	assert_eq((m.sides[E].line(F.MID)[0] as RulesUnit).armor, 2, "the enemy's first too")
	assert_eq(m.sides[E].eliminations + m.sides[P].eliminations, 0, "no credit")
	var tt: Array[Dictionary] = F.events_of(m, RulesEvent.TERRAIN_TRIGGERED)
	assert_eq(tt.size(), 2, "two Minefield triggers")
	assert_true(String(tt[0]["what"]).begins_with("Minefield:"), "log line")


func test_minefield_can_eliminate_without_credit() -> void:
	var m: MatchState = _m([&"minefield", &"", &""], F.setup([F.unit("frail", 0, 1)]))
	m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "frail"), F.LEFT))
	m.reveal()
	assert_eq(m.sides[P].line(F.LEFT).size(), 0, "a 1-Armor unit dies")
	var el: Array[Dictionary] = F.events_of(m, RulesEvent.UNIT_ELIMINATED)
	assert_false(bool(el[0]["credit"]), "Terrain gives no elimination credit")


func test_field_hospital_heals_the_most_damaged_unit_of_each_side() -> void:
	var m: MatchState = _m([&"field_hospital", &"", &""])
	var a: RulesUnit = F.place(m, P, F.unit("a", 0, 5), F.LEFT)
	var b: RulesUnit = F.place(m, P, F.unit("b", 0, 5), F.LEFT)
	var c: RulesUnit = F.place(m, E, F.unit("c", 0, 5), F.LEFT)
	a.armor = 4
	b.armor = 2
	c.armor = 3
	m.score()
	assert_eq([a.armor, b.armor, c.armor], [4, 3, 4], "the most damaged of each side heals 1")
	# Stacking with a Field: Aid Station heals too.
	var m2: MatchState = _m([&"field_hospital", &"", &""])
	var d: RulesUnit = F.place(m2, P, F.unit("d", 0, 6), F.LEFT)
	F.place_field(m2, P, F.aid_station(), F.LEFT)
	d.armor = 2
	m2.score()
	assert_eq(d.armor, 4, "Field Hospital + Aid Station: both heal")


func test_terrain_is_not_a_field_and_survives_overrun() -> void:
	var m: MatchState = _m([&"comms_tower", &"", &""])
	F.place(m, E, F.unit("e", 0, 5), F.LEFT)
	F.place_field(m, P, F.war_standard(), F.LEFT)
	m.score()
	assert_eq(m.sides[P].equipment[0].size(), 0, "the player's Field is overrun")
	assert_eq(m.terrain[0], &"comms_tower", "the Terrain stays")
	assert_eq(m.field_view(P)[0]["player"].size(), 0, "Terrain is not listed as a Field")


func test_clone_copies_terrain_independently() -> void:
	var m: MatchState = _m([&"smoke", &"", &"minefield"])
	m.terrain_supply_next[1] = 1
	var c: MatchState = MatchClone.copy(m)
	assert_eq(c.terrain, m.terrain, "same Terrain")
	assert_eq(c.terrain_supply_next, [0, 1] as Array[int], "Supply Cache carry copied")
	c.terrain[0] = &""
	assert_eq(m.terrain[0], &"smoke", "independent")


func test_ai_view_reads_terrain() -> void:
	var m: MatchState = _m([&"smoke", &"breach_point", &"minefield"], F.setup([F.marksman()]), F.setup([F.marksman()]))
	F.place(m, E, F.marksman(), F.LEFT)
	var v: AiView = AiView.capture(m, E)
	assert_eq(v.terrain, [&"smoke", &"breach_point", &"minefield"] as Array[StringName], "the view carries the Terrain")
	assert_false(bool(v.lines[AiView.ME][0][0]["pick"]), "records: no Pick in Smoke")
	var r: Dictionary = v.record_for_card(F.marksman(), 99, 2)
	assert_eq(int(r["armor"]), 1, "a unit arriving in the Minefield is planned at -1 Armor")
	assert_true(bool(v.record_for_card(F.rifleman(), 98, 1)["pierce"]), "Breach Point: Pierce")


func test_terrain_data_and_deal() -> void:
	assert_eq(TerrainRules.all().size(), 10, "10 Terrains")
	for t: TerrainData in TerrainRules.all():
		assert_false(t.text.to_lower().contains("field"), "%s: player text says Terrain, never Field" % t.id)
		assert_true(t.text != "" and t.display_name != "", "%s has a name and a rule" % t.id)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 30:
		var d: Array[StringName] = TerrainRules.deal(rng, 2, DataEnums.GameMode.ZONE_CONTROL)
		assert_eq(TerrainRules.count_of(d), 2, "two Terrains")
		var ids: Array = d.filter(func(x: StringName) -> bool: return x != &"")
		assert_true(ids[0] != ids[1], "distinct")
	var view: Array[Dictionary] = _m([&"", &"rooftops", &""]).terrain_view()
	assert_eq(view[1]["name"], "Rooftops", "terrain_view row")
	assert_eq(view[1]["active_for"], [&"player", &"enemy"], "applies to both sides")
	assert_eq(view[0]["id"], &"", "no Terrain in A")

# test_killstreak_strikes.gd
# Purpose: kc-ks-seq. Damage killstreaks (Mortar Barrage, Attack Helo, any killstreak with DAMAGE)
#   are queued at Reveal and strike at Firefight step 0, one at a time, before column A; standing
#   strikes from an earlier round first, then this round's in Reveal order. Non-damage killstreaks
#   keep their timing. The KILLSTREAK_RESOLVED log line names the column and every hit. The outcome
#   preview and the AI planner see the strike.
# Author: Game Feel Engineer Agent (kc-ks-seq)
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const E: int = 1


static func _load(id: String) -> LoadoutItem:
	return load("res://data/loadout/%s.tres" % id) as LoadoutItem


func _types(events: Array[Dictionary]) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Dictionary in events:
		out.append(e["type"])
	return out


func test_damage_killstreaks_are_strikes_and_the_others_are_not() -> void:
	assert_true(KillstreakStrikes.is_strike(_load("mortar_barrage")), "Mortar Barrage is a strike")
	assert_true(KillstreakStrikes.is_strike(_load("attack_helo")), "Attack Helo is a strike")
	assert_false(KillstreakStrikes.is_strike(_load("recon_drone")), "Recon Drone is not")
	assert_false(KillstreakStrikes.is_strike(_load("sentry_turret")), "Sentry Turret is not")


func test_mortar_waits_for_the_fight_and_strikes_before_column_a() -> void:
	var m: MatchState = F.new_match()
	F.grant(m, P, _load("mortar_barrage"))
	var op_foe: RulesUnit = F.place(m, E, F.unit("left_foe", 1, 9), F.LEFT)
	F.place(m, P, F.unit("left_me", 1, 9), F.LEFT)
	var a: RulesUnit = F.place(m, E, F.rifleman(), F.RIGHT)
	var b: RulesUnit = F.place(m, E, F.unit("tough", 0, 6), F.RIGHT)
	assert_true(m.submit(P, RulesIntent.use_item(&"mortar_barrage", F.RIGHT))["ok"], "called on Right")
	assert_eq([a.armor, b.armor], [2, 6], "nothing at the call")
	var start: int = m.events.size()
	m.reveal()
	assert_eq([a.armor, b.armor], [2, 6], "nothing at Reveal")
	var queued: Array[Dictionary] = F.events_of(m, RulesEvent.KILLSTREAK_QUEUED)
	assert_eq(queued.size(), 1, "queued once")
	assert_eq([queued[0]["item_id"], queued[0]["zone"], queued[0]["zones"], queued[0]["resolves"]],
			[&"mortar_barrage", &"right", [&"right"], &"firefight"], "queued on Right for the fight")
	m.firefight()
	assert_false(a.is_alive(), "the Rifleman (2 Armor) is down")
	assert_eq(b.armor, 4, "2 to the other unit")
	assert_eq(op_foe.armor <= 9, true, "Left still fought")
	var types: Array[StringName] = _types(m.events_since(start))
	var strike: int = types.find(RulesEvent.KILLSTREAK_STRIKE)
	var done: int = types.find(RulesEvent.KILLSTREAK_RESOLVED)
	var ff: int = types.find(RulesEvent.PHASE_CHANGED, types.find(RulesEvent.KILLSTREAK_QUEUED))
	assert_true(ff >= 0 and ff < strike, "the strike comes after the fight starts")
	assert_true(strike < types.find(RulesEvent.DAMAGE_DEALT, strike), "the strike opens its hits")
	assert_true(types.find(RulesEvent.UNIT_ELIMINATED, strike) < done, "its kill is removed before it ends")
	assert_true(done < types.find(RulesEvent.FIREFIGHT_STARTED), "step 0 ends before column A")
	var res: Dictionary = F.events_of(m, RulesEvent.KILLSTREAK_RESOLVED)[0]
	assert_eq(res["kills"], [a.uid], "the kill is listed")
	assert_eq(String(res["what"]), "Mortar Barrage hit column C: Rifleman −2 (down), tough −2",
			"plain log line: %s" % res["what"])


func test_a_mortar_kill_never_shoots_back() -> void:
	var m: MatchState = F.new_match()
	F.grant(m, P, _load("mortar_barrage"))
	var mine: RulesUnit = F.place(m, P, F.unit("mine", 1, 3), F.MID)
	F.place(m, E, F.unit("glass_cannon", 9, 2), F.MID)
	m.submit(P, RulesIntent.use_item(&"mortar_barrage", F.MID))
	m.reveal()
	m.firefight()
	assert_eq(mine.armor, 3, "the 9 FP unit died at step 0 and never fired")
	assert_eq(F.events_of(m, RulesEvent.FIREFIGHT_STARTED).size(), 0, "no column fight left in Mid")


func test_strike_order_standing_first_then_reveal_order() -> void:
	var m: MatchState = F.new_match()
	F.grant(m, E, _load("attack_helo"))
	F.grant(m, P, _load("mortar_barrage"))
	F.grant(m, E, F.mortar())
	for z: int in 3:
		F.place(m, E, F.unit("e%d" % z, 0, 20), z)
		F.place(m, P, F.unit("p%d" % z, 0, 20), z)
	assert_true(m.submit(E, RulesIntent.use_item(&"attack_helo"))["ok"], "enemy helo, round 1")
	m.resolve_round()
	m.begin_round()
	assert_true(m.submit(P, RulesIntent.use_item(&"mortar_barrage", F.LEFT))["ok"], "player mortar")
	assert_true(m.submit(E, RulesIntent.use_item(&"mortar_barrage", F.RIGHT))["ok"], "enemy mortar")
	var start: int = m.events.size()
	m.reveal()
	var first: StringName = m.side_name(m.initiative)
	m.firefight()
	var strikes: Array = m.events_since(start).filter(func(e: Dictionary) -> bool: return e["type"] == RulesEvent.KILLSTREAK_STRIKE)
	assert_eq(strikes.size(), 3, "three strikes")
	assert_eq([strikes[0]["item_id"], strikes[0]["side"], strikes[0]["pass"], strikes[0]["passes"]],
			[&"attack_helo", &"enemy", 2, 2], "the standing helo (2nd pass) first")
	assert_eq(strikes[1]["side"], first, "then this round's, initiative side first")
	assert_eq(strikes[1]["item_id"], &"mortar_barrage", "a mortar")
	assert_true(strikes[2]["side"] != first, "then the other side")


func test_helo_strikes_each_front_line_and_names_columns() -> void:
	var m: MatchState = F.new_match()
	F.grant(m, P, _load("attack_helo"))
	var l: RulesUnit = F.place(m, E, F.unit("Lefty", 0, 9), F.LEFT)
	var r: RulesUnit = F.place(m, E, F.unit("Righty", 0, 9), F.RIGHT)
	m.submit(P, RulesIntent.use_item(&"attack_helo"))
	m.reveal()
	assert_eq([l.armor, r.armor], [9, 9], "no damage at Reveal")
	var q: Dictionary = F.events_of(m, RulesEvent.KILLSTREAK_QUEUED)[0]
	assert_eq([q["fights"], q["zones"]], [2, [&"left", &"mid", &"right"]], "two fights, every column")
	m.firefight()
	assert_eq([l.armor, r.armor], [7, 7], "2 to each front unit")
	var what: String = F.events_of(m, RulesEvent.KILLSTREAK_RESOLVED)[0]["what"]
	assert_eq(what, "Attack Helo hit every column: Lefty −2 in A, Righty −2 in C", "log: %s" % what)


func test_non_damage_killstreaks_keep_their_timing() -> void:
	var m: MatchState = F.new_match()
	F.grant(m, P, _load("sentry_turret"))
	F.grant(m, P, _load("recon_drone"))
	assert_true(m.submit(P, RulesIntent.use_item(&"recon_drone"))["ok"], "recon")
	assert_true(m.sides[E].has_flag(DataEnums.EffectKind.REVEAL_DEPLOYMENTS, m.round_number) \
			or m.sides[P].has_flag(DataEnums.EffectKind.REVEAL_DEPLOYMENTS, m.round_number), "recon resolves at once")
	assert_true(m.submit(P, RulesIntent.use_item(&"sentry_turret", F.MID))["ok"], "sentry")
	m.reveal()
	assert_eq(F.line_ids(m, P, F.MID), [&"sentry"] as Array[StringName], "the Sentry arrives at Reveal")
	assert_eq(F.events_of(m, RulesEvent.KILLSTREAK_QUEUED).size(), 0, "nothing queued")


func test_strike_kills_give_no_streak() -> void:
	var m: MatchState = F.new_match()
	F.grant(m, P, _load("mortar_barrage"))
	F.place(m, E, F.unit("v", 0, 1), F.RIGHT)
	m.submit(P, RulesIntent.use_item(&"mortar_barrage", F.RIGHT))
	m.resolve_round()
	var rec: Dictionary = F.events_of(m, RulesEvent.UNIT_ELIMINATED)[0]
	assert_eq([rec["by_killstreak"], rec["source_kind"]], [true, &"killstreak"], "a killstreak kill")
	assert_eq(m.sides[P].streak, 0, "no streak for it")


func test_outcome_preview_counts_the_strike() -> void:
	var m: MatchState = F.new_match()
	F.grant(m, P, _load("mortar_barrage"))
	F.place(m, E, F.unit("v", 0, 5), F.RIGHT)
	m.submit(P, RulesIntent.use_item(&"mortar_barrage", F.RIGHT))
	var fc: Dictionary = OutcomeForecast.forecast(m, P)
	assert_true(fc["ok"], "preview")
	assert_eq(int(fc["zones"][2]["dealt"]), 2, "the mortar's 2 is in the preview of Right")


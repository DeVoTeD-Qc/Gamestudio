# test_duel_doctrine.gd
# Purpose: kc-duel-impl (duel-mode.md §12.3, §12.6): the Duel Doctrine "starts the set only" flag
#   (SideSetup.doctrine_starts_only) in SynergyRules, MatchState, the AI view, and that the campaign keeps
#   its own rule (+1 while any member is in play). Plus the Undead set retune (both modes).
# Author: Mechanics Developer Agent (kc-duel-impl)
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const E: int = 1
const L: int = 0
const M: int = 1
const R: int = 2


func _u(id: String, tr: StringName) -> CardData:
	return F.unit(id, 2, 4, DataEnums.WeaponClass.NONE, {"card_trait": tr})


func _lines(n: int, t: StringName) -> Array:
	var lines: Array = [[], [], []]
	for i: int in n:
		(lines[i % 3] as Array).append({"uid": i + 1, "trait": t})
	return lines


func test_trait_counts_flag() -> void:
	for flag: bool in [false, true]:
		assert_eq(int(SynergyRules.trait_counts(_lines(0, &"undead"), [], &"undead", flag).get(&"undead", 0)), 0,
				"no member: nothing (flag %s)" % flag)
		assert_eq(int(SynergyRules.trait_counts(_lines(1, &"undead"), [], &"undead", flag).get(&"undead", 0)), 2,
				"one member counts as two (flag %s)" % flag)
	assert_eq(int(SynergyRules.trait_counts(_lines(2, &"undead"), [], &"undead", true)[&"undead"]), 2, "Duel: 2 stays 2")
	assert_eq(int(SynergyRules.trait_counts(_lines(3, &"undead"), [], &"undead", true)[&"undead"]), 3, "Duel: 3 real")
	assert_eq(int(SynergyRules.trait_counts(_lines(2, &"undead"), [], &"undead", false)[&"undead"]), 3, "campaign: 2 + 1")
	assert_eq(int(SynergyRules.trait_counts(_lines(2, &"undead"), [], &"undead")[&"undead"]), 3, "default = the campaign rule")
	# A Field member counts as the one member too.
	assert_eq(int(SynergyRules.trait_counts(_lines(0, &""), [&"heavy"], &"heavy", true)[&"heavy"]), 2, "a Field starts it")
	var c: Dictionary = SynergyRules.compute(_lines(2, &"heavy"), [], &"heavy", true)
	assert_eq(int(c["tiers"][&"heavy"]), 2, "Duel: 2 Heavy = tier 2, never 3")
	c = SynergyRules.compute(_lines(2, &"heavy"), [], &"heavy", false)
	assert_eq(int(c["tiers"][&"heavy"]), 3, "campaign: 2 Heavy + Doctrine = tier 3")


func test_undead_set_retune() -> void:
	assert_eq(SynergyRules.TRAIT_BONUS[SynergyRules.UNDEAD], [{"heal": 1, "cover": 1}, {"fp": 1}], "§12.6 Undead table")
	assert_eq(SynergyRules.TIER_TEXT[SynergyRules.UNDEAD],
			["Undead get Cover +1 and heal 1 at the end of the round", "Undead get +1 FP"], "§12.6 texts")
	var m: MatchState = F.new_match(F.setup(), F.setup())
	var u1: RulesUnit = F.place(m, P, _u("u1", &"undead"), L)
	F.place(m, P, _u("u2", &"undead"), R)
	assert_eq([m.firepower_of(u1), m.cover_of(u1), int(m.synergy_of(u1)["heal"])], [2, 1, 1], "2-set: Cover 1 + heal 1")
	F.place(m, P, _u("u3", &"undead"), M)
	assert_eq([m.firepower_of(u1), m.cover_of(u1)], [3, 1], "3-set: +1 FP on top (Cover stays from the 2-set)")


func test_match_uses_the_side_flag() -> void:
	var duel: SideSetup = F.setup()
	duel.doctrine = &"vanguard"
	duel.doctrine_starts_only = true
	var camp: SideSetup = F.setup()
	camp.doctrine = &"vanguard"
	var m: MatchState = F.new_match(duel, camp)
	var a1: RulesUnit = F.place(m, P, _u("a1", &"vanguard"), L)
	var b1: RulesUnit = F.place(m, E, _u("b1", &"vanguard"), L)
	assert_eq([m.firepower_of(a1), m.firepower_of(b1)], [3, 3], "one member: both rules turn the 2-set on")
	F.place(m, P, _u("a2", &"vanguard"), M)
	F.place(m, E, _u("b2", &"vanguard"), M)
	assert_eq(int(m.synergy_side(P)["counts"][&"vanguard"]), 2, "Duel side: 2 real = 2")
	assert_eq(int(m.synergy_side(E)["counts"][&"vanguard"]), 3, "campaign side: 2 + 1")
	# The UI preview follows the same flag: a second Vanguard from the hand.
	var hs: SideSetup = F.setup([_u("h1", &"vanguard")])
	hs.doctrine = &"vanguard"
	hs.doctrine_starts_only = true
	var pm: MatchState = F.new_match(hs, F.setup())
	F.place(pm, P, _u("on", &"vanguard"), L)
	var uid: int = pm.sides[P].hand[0].uid
	var pv: Dictionary = pm.preview_synergy(P, uid, M)
	assert_eq([int(pv["counts_before"][&"vanguard"]), int(pv["counts_after"][&"vanguard"])], [2, 2], "Duel preview: 1+1 -> 2, not 3")
	hs.doctrine_starts_only = false
	pm._syn_sig = PackedInt32Array()
	pv = pm.preview_synergy(P, uid, M)
	assert_eq(int(pv["counts_after"][&"vanguard"]), 3, "campaign preview: 2 + 1")
	# The AI values plans with the side's rule.
	var view: AiView = AiView.capture(m, P)
	assert_true(view.my_doctrine_starts_only, "AI view carries the Duel flag")
	assert_false(AiView.capture(m, E).my_doctrine_starts_only, "and not on a campaign side")


func test_campaign_keeps_its_rule_duel_sets_the_flag() -> void:
	assert_false(SideSetup.new().doctrine_starts_only, "default: the campaign rule")
	var squad: SquadData = load("res://data/squads/squad_rusher.tres") as SquadData
	assert_false(SideSetup.from_squad(squad).doctrine_starts_only, "campaign crews: the campaign rule")
	var run: RunProgress = RunProgress.create(load("res://data/run_config.tres") as RunConfig, 7)
	assert_false(run.player_setup().doctrine_starts_only, "the run's player: the campaign rule")
	var dc: DuelConfig = load("res://data/duel/duel_config.tres") as DuelConfig
	var s: SideSetup = DuelRules.side_setup(dc.preset(&"hollow_ranks"), dc)
	assert_true(s.doctrine_starts_only, "Duel: starts only")
	assert_eq(s.doctrine, &"undead", "Hollow Ranks: Undead Doctrine")

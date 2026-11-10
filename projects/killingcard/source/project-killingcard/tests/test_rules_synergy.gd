# test_rules_synergy.gd
# Purpose: kc-syn-impl (synergy-system.md, approved), after kc-pos-cut (§13): the neighbor keywords
#   and range bonuses are retired (no links, no column FP), Cover / First Shot removal, trait sets (units + Fields,
#   tiers 2 / 3, v1.1 numbers), the Undead heal, Doctrine, kc-no-training (no copy levels: every copy
#   plays its full chassis, one trait), the Operator's Supply cost (refusal, payment, undo),
#   SYNERGY_CHANGED, the UI hooks (synergy_view, preview_synergy), MatchClone, the AI view / planner, and the shipped data.
# Author: Mechanics Developer Agent (kc-syn-impl)
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const E: int = 1
const L: int = 0
const M: int = 1
const R: int = 2


func _match(p_deck: Array = [], e_deck: Array = [], config: RunConfig = null) -> MatchState:
	var m: MatchState = F.new_match(F.setup(p_deck), F.setup(e_deck), null, 1, null, config)
	m.sides[P].supply = 7
	m.sides[E].supply = 7
	return m


## Unit with a neighbor keyword and / or trait.
func _u(id: String, fp: int, ar: int, kw: StringName = &"", tr: StringName = &"", extra: Dictionary = {}) -> CardData:
	var props: Dictionary = {"neighbor_keyword": kw, "card_trait": tr}
	props.merge(extra)
	return F.unit(id, fp, ar, DataEnums.WeaponClass.NONE, props)


func _plain(id: String = "plain") -> CardData:
	return F.unit(id, 1, 5)


func _field(id: String, tr: StringName) -> CardData:
	var c: CardData = F.bulwark().duplicate() as CardData
	c.id = StringName(id)
	c.card_trait = tr
	return c


# --- kc-pos-cut (synergy-system.md §13): no neighbor links ------------------------------------

func test_neighbor_keywords_are_retired() -> void:
	# Old Guard / Spotter / Fireteam / Overwatch geometry: none of it gives anything any more.
	var m: MatchState = _match()
	var g: RulesUnit = F.place(m, P, _u("guard", 1, 5, &"guard"), M)
	var behind: RulesUnit = F.place(m, P, _plain("behind"), M)
	var spotter: RulesUnit = F.place(m, P, _u("spotter", 2, 3, &"spotter"), M)
	var a: RulesUnit = F.place(m, P, _u("ft_a", 2, 2, &"fireteam"), L)
	var ow: RulesUnit = F.place(m, P, _u("ow", 2, 2, &"overwatch"), R)
	assert_eq([m.cover_of(g), m.cover_of(behind), m.cover_of(a), m.cover_of(ow)], [0, 0, 0, 0], "no link Cover")
	assert_eq([m.firepower_of(behind), m.firepower_of(spotter), m.firepower_of(a)], [1, 2, 2], "no link FP")
	assert_eq([g.neighbor_keyword, spotter.neighbor_keyword, a.neighbor_keyword], [&"", &"", &""], "units carry no keyword")
	assert_eq((m.synergy_side(P)["links"] as Array).size(), 0, "no links")
	var lines: Array = [[SynergyRules.slot(1, &"guard")], [SynergyRules.slot(2), SynergyRules.slot(3, &"spotter")], []]
	var res: Dictionary = SynergyRules.compute(lines)
	assert_eq([(res["links"] as Array).size(), int(res["zones"][1][0]["fp"]), int(res["zones"][0][0]["cover"])], [0, 0, 0],
			"compute() makes no links even for slots that name a keyword")
	assert_eq(SynergyRules.keyword_at(load("res://data/cards/breacher.tres") as CardData), &"", "keyword_at is empty")


func test_no_range_bonus_by_column() -> void:
	var m: MatchState = _match()
	var sg: RulesUnit = F.place(m, P, F.unit("sg", 3, 4, DataEnums.WeaponClass.SHOTGUN), L)
	var sn: RulesUnit = F.place(m, P, F.unit("sn", 2, 2, DataEnums.WeaponClass.SNIPER), R)
	var ar: RulesUnit = F.place(m, P, F.unit("ar", 2, 2, DataEnums.WeaponClass.AR), M)
	assert_eq([m.firepower_of(sg), m.firepower_of(sn), m.firepower_of(ar)], [3, 2, 2], "printed FP in every column")
	var cfg: RunConfig = load("res://data/run_config.tres") as RunConfig
	for wc: int in [DataEnums.WeaponClass.SMG, DataEnums.WeaponClass.SHOTGUN, DataEnums.WeaponClass.AR, DataEnums.WeaponClass.SNIPER]:
		for rt: int in [DataEnums.RangeTag.CLOSE, DataEnums.RangeTag.MID, DataEnums.RangeTag.LONG]:
			assert_eq(cfg.range_bonus(wc, rt), 0, "range_bonus is retired")


func test_cover_removal_and_blackout_strip_synergy() -> void:
	var m: MatchState = _match()
	var behind: RulesUnit = F.place(m, P, _u("v1", 1, 5, &"", &"vanguard"), M)
	F.place(m, P, _u("v2", 1, 5, &"", &"vanguard"), L)
	F.place(m, P, _u("v3", 1, 5, &"", &"heavy"), R)
	F.place(m, P, _u("h2", 1, 5, &"", &"heavy"), R)
	behind = F.place(m, P, _u("h3", 1, 5, &"", &"heavy"), L)
	assert_eq(m.cover_of(behind), 1, "Heavy set Cover (v2.1: Vanguard has no Cover at 3)")
	m.sides[E].flags[DataEnums.EffectKind.REMOVE_COVER] = m.round_number
	assert_eq(m.cover_of(behind), 0, "Recon Drone-style Cover removal takes set Cover too")
	var m2: MatchState = _match()
	var a: RulesUnit = F.place(m2, P, _u("so_a", 2, 2, &"", &"specops"), L)
	F.place(m2, P, _u("so_b", 2, 2, &"", &"specops"), M)
	F.place(m2, P, _u("so_c", 2, 2, &"", &"specops"), R)
	# v1.5 (kc-specops3): Spec Ops 3 gives Cover +1 (and keeps tier 2's +1 FP), no First Shot.
	assert_eq([m2.firepower_of(a), m2.cover_of(a), m2.has_first_shot(a)], [3, 1, false], "Spec Ops 3: +1 FP, Cover +1, no First Shot")
	m2.sides[E].flags[DataEnums.EffectKind.REMOVE_COVER] = m2.round_number
	assert_eq(m2.cover_of(a), 0, "Cover removal takes the Spec Ops set Cover too")
	# A set-bonus First Shot (none ships; balance what-ifs can add one) is still removed by Blackout.
	var keep: Dictionary = SynergyRules.trait_bonus.duplicate(true)
	SynergyRules.trait_bonus[&"specops"] = [{"fp": 1}, {"fs": true}]
	var m3: MatchState = _match()
	var b3: RulesUnit = F.place(m3, P, _u("so_a", 2, 2, &"", &"specops"), L)
	F.place(m3, P, _u("so_b", 2, 2, &"", &"specops"), M)
	F.place(m3, P, _u("so_c", 2, 2, &"", &"specops"), R)
	var had: bool = m3.has_first_shot(b3)
	b3.add_mod(DataEnums.EffectKind.REMOVE_FIRST_SHOT, 0, m3.round_number)
	var after: bool = m3.has_first_shot(b3)
	SynergyRules.trait_bonus = keep
	assert_eq([had, after], [true, false], "Blackout-style REMOVE_FIRST_SHOT removes a set First Shot")


func test_specops_set_table_and_text_v1_5() -> void:
	assert_eq(SynergyRules.TRAIT_BONUS[&"specops"], [{"fp": 1}, {"cover": 1}], "Spec Ops: 2 = +1 FP, 3 = Cover +1")
	assert_eq(SynergyRules.TIER_TEXT[&"specops"], ["Spec Ops get +1 FP", "Spec Ops get Cover +1"], "player-facing tier texts")
	for t: StringName in SynergyRules.TRAITS:
		for tier: Dictionary in SynergyRules.TRAIT_BONUS[t]:
			assert_false(bool(tier.get("fs", false)), "%s: no set gives First Shot any more" % t)
	assert_eq([SynergyRules.active_tier(&"specops", 2), SynergyRules.active_tier(&"specops", 3)], [2, 3], "both tiers active")


# --- Traits and sets -------------------------------------------------------------------------

func test_vanguard_tiers() -> void:
	var m: MatchState = _match()
	var v1: RulesUnit = F.place(m, P, _u("v1", 2, 3, &"", &"vanguard"), L)
	var plain: RulesUnit = F.place(m, P, _plain("p"), M)
	assert_eq(m.firepower_of(v1), 2, "one Vanguard: no set")
	var v2: RulesUnit = F.place(m, P, _u("v2", 2, 3, &"", &"vanguard"), L)
	assert_eq([m.firepower_of(v1), m.firepower_of(v2), m.cover_of(v1)], [3, 3, 0], "Vanguard 2: +1 FP to every Vanguard, any row (kc-pos-cut)")
	assert_eq(m.firepower_of(plain), 1, "untraited units get nothing")
	var v3: RulesUnit = F.place(m, P, _u("v3", 2, 3, &"", &"vanguard"), R)
	assert_eq([m.cover_of(v1), m.cover_of(v2), m.cover_of(v3), m.cover_of(plain)], [0, 0, 0, 0], "Vanguard 3: no Cover (v2.1, head V6)")
	assert_eq([m.firepower_of(v1), m.firepower_of(v3)], [3, 3], "tier 3 includes tier 2")


func test_specops_heavy_undead_tiers() -> void:
	var m: MatchState = _match()
	var s1: RulesUnit = F.place(m, P, _u("s1", 2, 3, &"", &"specops"), L)
	F.place(m, P, _plain("pad"), M)
	var s2: RulesUnit = F.place(m, P, _u("s2", 2, 3, &"", &"specops"), M)
	assert_eq([m.firepower_of(s1), m.firepower_of(s2)], [3, 3], "Spec Ops 2: +1 FP to every Spec Ops, any row (kc-pos-cut)")
	assert_false(m.has_first_shot(s1), "no First Shot at 2")
	var h: MatchState = _match()
	var h1: RulesUnit = F.place(h, P, _u("h1", 2, 6, &"", &"heavy"), L)
	F.place(h, P, _u("h2", 2, 6, &"", &"heavy"), R)
	assert_eq([h.cover_of(h1), h.firepower_of(h1)], [1, 3], "Heavy 2: Cover +1 and +1 FP (v2.2, kc-econ)")
	assert_eq(int(h.synergy_side(P)["tiers"][&"heavy"]), 2, "tier 2 active")
	F.place(h, P, _u("h3", 2, 6, &"", &"heavy"), R)
	assert_eq([h.cover_of(h1), h.firepower_of(h1)], [1, 4], "Heavy 3: Cover +1 and +2 FP")
	var u: MatchState = _match()
	var u1: RulesUnit = F.place(u, P, _u("u1", 2, 3, &"", &"undead"), L)
	F.place(u, P, _u("u2", 2, 3, &"", &"undead"), R)
	assert_eq(int(u.synergy_of(u1)["heal"]), 1, "Undead 2: heal 1")
	assert_eq([u.firepower_of(u1), u.cover_of(u1)], [2, 1], "Undead 2: Cover +1, no FP (kc-duel-tune §12.3)")
	F.place(u, P, _u("u3", 2, 3, &"", &"undead"), M)
	assert_eq([u.firepower_of(u1), u.cover_of(u1)], [3, 1], "Undead 3: +1 FP (Cover from the 2-set)")


func test_fields_count_for_sets() -> void:
	var m: MatchState = _match()
	var br: RulesUnit = F.place(m, P, _u("breacher", 3, 4, &"guard", &"vanguard"), L)
	assert_eq(m.firepower_of(br), 3, "one Vanguard")
	F.place_field(m, P, _field("bulwark_t", &"vanguard"), R)
	assert_eq(m.firepower_of(br), 4, "Bulwark + Breacher = Vanguard 2 (the Field gets nothing, it has no stats)")
	assert_eq(int(m.synergy_side(P)["counts"][&"vanguard"]), 2, "count includes the Field")
	# kc-no-training: a second copy of a traited chassis counts for its trait and keeps its keywords.
	var m2: MatchState = _match()
	var card: CardData = _u("pm", 2, 3, &"fireteam", &"vanguard")
	card.first_shot = true
	var t1: RulesUnit = F.place(m2, P, card, L)
	var two: RulesUnit = m2.create_unit(P, card)
	m2.put_in_line(two, M)
	assert_eq([two.synergy_trait, two.first_shot], [&"vanguard", true], "every copy: its trait and its keywords")
	assert_eq(int(m2.synergy_side(P)["counts"].get(&"vanguard", 0)), 2, "both count for Vanguard")
	assert_eq([m2.firepower_of(t1), m2.firepower_of(two)], [3, 3], "both get Vanguard 2 (+1 FP); no links (kc-pos-cut)")
	# A Field's trait counts; hidden traps never do.
	var m3: MatchState = _match()
	var lone: RulesUnit = F.place(m3, P, _u("v", 2, 3, &"", &"vanguard"), L)
	var rf: RulesCard = RulesCard.new(m3.new_uid(), _field("bulwark_r", &"vanguard"))
	m3.sides[P].equipment[R].append({"card": rf, "round": 0})
	assert_eq(m3.firepower_of(lone), 3, "a Field counts")


func test_undead_heal_at_end_of_round_capped_and_logged() -> void:
	var m: MatchState = _match()
	var u1: RulesUnit = F.place(m, P, _u("u1", 0, 4, &"", &"undead"), L)
	var u2: RulesUnit = F.place(m, P, _u("u2", 0, 4, &"", &"undead"), R)
	var plain: RulesUnit = F.place(m, P, F.unit("plain", 0, 4), M)
	u1.armor = 2
	plain.armor = 2
	m.score()
	assert_eq([u1.armor, u2.armor, plain.armor], [3, 4, 2], "damaged Undead heal 1, full ones stay at max, others nothing")
	var heals: Array = F.events_of(m, RulesEvent.UNIT_HEALED).filter(func(e: Dictionary) -> bool: return e["source_id"] == &"trait_undead")
	assert_eq(heals.size(), 1, "one UNIT_HEALED from the trait")
	assert_eq([int(heals[0]["target_uid"]), int(heals[0]["amount"])], [u1.uid, 1], "event fields")
	var m2: MatchState = _match()
	var solo: RulesUnit = F.place(m2, P, _u("solo", 0, 4, &"", &"undead"), L)
	solo.armor = 1
	m2.score()
	assert_eq(solo.armor, 1, "one Undead: no heal")


func test_doctrine_adds_one_to_its_trait_while_a_member_is_in_play() -> void:
	var s: SideSetup = F.setup()
	s.doctrine = &"vanguard"
	var m: MatchState = F.new_match(s, F.setup())
	var plain: RulesUnit = F.place(m, P, _plain("p"), M)
	assert_eq(int(m.synergy_side(P)["counts"].get(&"vanguard", 0)), 0, "no member: no count")
	var v: RulesUnit = F.place(m, P, _u("v", 2, 3, &"", &"vanguard"), L)
	assert_eq(m.firepower_of(v), 3, "one Vanguard + Doctrine = tier 2")
	assert_eq(m.firepower_of(plain), 1, "untraited: nothing")
	var foe: RulesUnit = F.place(m, E, _u("fv", 2, 3, &"", &"vanguard"), L)
	assert_eq(m.firepower_of(foe), 2, "Doctrine is per side")


# --- kc-no-training: no copy levels, one trait per copy -------------------------------------

func test_every_copy_plays_its_full_chassis_from_the_deck_to_the_discard() -> void:
	var card: CardData = _u("pm", 2, 3, &"", &"vanguard")
	card.first_shot = true
	var s: SideSetup = F.setup([card, card])
	var m: MatchState = F.new_match(s, F.setup())
	var units: Array[RulesUnit] = []
	for i: int in 2:
		var rc: RulesCard = m.sides[P].hand[i]
		units.append(m.create_unit(P, rc.card, rc.uid, rc.chosen_trait))
	assert_eq(units.map(func(u: RulesUnit) -> Array: return [u.base_firepower, u.base_max_armor, u.first_shot, u.synergy_trait]),
			[[2, 3, true, &"vanguard"], [2, 3, true, &"vanguard"]], "printed stats and keywords on every copy")
	m.put_in_line(units[0], L)
	units[0].armor = 0
	m.process_eliminations()
	assert_eq(m.sides[P].discard.back().card, card, "the copy goes to the discard")
	assert_false("level" in units[0], "RulesUnit has no level")
	assert_false("level" in m.sides[P].discard.back(), "RulesCard has no level")
	assert_false("deck_levels" in s, "SideSetup has no deck_levels")


func test_a_copy_carries_at_most_one_trait() -> void:
	var mk: CardData = load("res://data/cards/marksman.tres") as CardData
	for bad: StringName in [&"specops,heavy", &"specops|heavy", &"specopsheavy", &"heavy specops"]:
		assert_false(SynergyRules.is_single_trait(bad), "'%s' is not one trait" % bad)
		assert_eq(SynergyRules.trait_at(mk, bad), &"", "a combined trait makes the copy plain ('%s')" % bad)
	assert_true(SynergyRules.is_single_trait(&"") and SynergyRules.is_single_trait(&"heavy"), "none or one")
	var m: MatchState = _match()
	var u: RulesUnit = m.create_unit(P, mk, -1, &"heavy")
	assert_eq(typeof(u.synergy_trait), TYPE_STRING_NAME, "one trait value, never a list")
	assert_eq(u.synergy_trait, &"heavy", "the art's trait")
	m.put_in_line(u, L)
	var v: Dictionary = m.synergy_view(P)
	var sets: Array = v["units"][u.uid]["sets"]
	for st: Array in sets:
		assert_eq(st[0], &"heavy", "a unit's set bonuses all come from its one trait")


# --- Operator cost ---------------------------------------------------------------------------

func test_operator_costs_supply_and_undo_refunds_it() -> void:
	var cfg: RunConfig = RunConfig.new()
	assert_eq(cfg.operator_cost, 0, "RunConfig.new() keeps the free Operator")
	cfg.operator_cost = 1
	var m: MatchState = F.new_match(F.setup([], F.kestrel()), F.setup(), null, 1, null, cfg)
	m.sides[P].supply = 0
	var r: Dictionary = m.submit(P, RulesIntent.place_operator(M))
	assert_eq([r["ok"], r["code"], r["data"]], [false, &"not_enough_supply", {"cost": 1, "supply": 0}], "refused without Supply")
	m.sides[P].supply = 2
	assert_true(m.submit(P, RulesIntent.place_operator(M))["ok"], "placed")
	assert_eq(m.sides[P].supply, 1, "paid 1")
	assert_true(m.undo_last(P)["ok"], "undo")
	assert_eq(m.sides[P].supply, 2, "refunded")
	assert_eq(m.check_use(P, &"operator")["ok"], true, "check_use agrees")
	m.sides[P].supply = 0
	assert_eq(m.check_use(P, &"operator")["code"], &"not_enough_supply", "check_use reports the cost")
	var shipped: RunConfig = load("res://data/run_config.tres") as RunConfig
	assert_eq(shipped.operator_cost, 1, "the shipped run: 1 Supply (head S4)")


# --- Events and UI hooks ---------------------------------------------------------------------

func test_synergy_changed_fires_only_on_flips() -> void:
	var quiet: MatchState = _match()
	F.place(quiet, P, _plain("a"), L)
	quiet.reveal()
	assert_eq(F.events_of(quiet, RulesEvent.SYNERGY_CHANGED).size(), 0, "no links, no sets: no event")
	var m: MatchState = _match([_u("v2", 2, 3, &"", &"vanguard"), _plain("filler")])
	F.place(m, P, _u("v1", 2, 3, &"", &"vanguard"), L)
	m.announce_synergy()
	var n0: int = F.events_of(m, RulesEvent.SYNERGY_CHANGED).size()
	m.announce_synergy()
	assert_eq(F.events_of(m, RulesEvent.SYNERGY_CHANGED).size(), n0, "nothing changed: no event")
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "v2"), M))["ok"], "second Vanguard")
	m.reveal()
	var evs: Array[Dictionary] = F.events_of(m, RulesEvent.SYNERGY_CHANGED)
	assert_eq(evs.size(), n0 + 1, "the tier flip is announced once")
	assert_eq([evs.back()["side"], int(evs.back()["sets"][&"vanguard"])], [&"player", 2], "Vanguard 2")


func test_synergy_view_preview_and_clone() -> void:
	var gunner: CardData = _u("gunner", 2, 6, &"overwatch", &"heavy")
	var m: MatchState = _match([gunner])
	var a1: RulesUnit = F.place(m, P, _u("h", 2, 4, &"", &"heavy"), L)
	F.place(m, P, _u("h2", 2, 4, &"", &"heavy"), R)
	var prev: Dictionary = m.preview_synergy(P, F.hand_uid(m, P, "gunner"), M)
	assert_true(prev["ok"], "preview")
	assert_eq(prev["new_links"].size(), 0, "no links (kc-pos-cut)")
	assert_eq([int(prev["tiers_before"].get(&"heavy", 0)), int(prev["tiers_after"][&"heavy"])], [2, 3], "Heavy 2 -> 3")
	assert_eq(int(prev["card"]["cover"]), 1, "the Gunner itself gets Heavy 3 Cover")
	assert_false(m.preview_synergy(P, 9999, M)["ok"], "unknown card")
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "gunner"), M))["ok"], "play it")
	m.reveal()
	var v: Dictionary = m.synergy_view(P)
	assert_eq(v["player"]["rail"].size(), 1, "rail lists traits in play")
	assert_eq([v["player"]["rail"][0]["trait"], v["player"]["rail"][0]["count"], v["player"]["rail"][0]["tier"], v["player"]["rail"][0]["next"]],
			[&"heavy", 3, 3, 0], "rail entry")
	var ua: Dictionary = v["units"][a1.uid]
	assert_eq([ua["cover"], ua["links"].size(), ua["sets"], ua.has("band"), ua.has("level")], [1, 0, [[&"heavy", 2], [&"heavy", 3]], false, false], "unit entry (no level / band)")
	var copy: MatchState = MatchClone.copy(m)
	assert_eq(copy.cover_of(copy.find_unit(a1.uid)), m.cover_of(a1), "the clone reads the same synergy")
	copy.find_unit(a1.uid).armor = 0
	copy.process_eliminations()
	assert_eq(m.cover_of(a1), 1, "the live match is untouched")


# --- AI ----------------------------------------------------------------------------------------

func test_ai_view_records_carry_synergy() -> void:
	var card: CardData = _u("pm", 2, 3, &"fireteam", &"vanguard")
	card.first_shot = true
	var s: SideSetup = F.setup([card, card])
	var m: MatchState = F.new_match(F.setup(), s)
	var cfg_cost: int = m.operator_cost()
	F.place(m, E, card, L)
	F.place(m, E, _plain("mate"), M)
	var v: AiView = AiView.capture(m, E)
	var rec: Dictionary = v.lines[AiView.ME][L][0]
	assert_eq([rec["kw"], rec["trait"], rec["syn_fp"], rec["fp"], rec.has("level")], [&"", &"vanguard", 0, 2, false], "record (no links, one Vanguard, no level)")
	assert_false(v.hand.any(func(h: Dictionary) -> bool: return h.has("level")), "hand entries carry no level")
	assert_eq(v.operator_cost, cfg_cost, "Operator cost in the view")
	var r0: Dictionary = v.record_for_card(card, -5, L)
	var r1: Dictionary = v.record_for_card(card, -6, L, &"vanguard")
	assert_eq([r0["kw"], r0["armor"], r0["fp"], r0["first_shot"], r1["trait"]], [&"", 3, 2, true, &"vanguard"], "record_for_card: the printed chassis")


func test_shipped_starter_squads_and_pool() -> void:
	var cfg: RunConfig = load("res://data/run_config.tres") as RunConfig
	var counts: Dictionary = {}
	for c: CardData in cfg.starter_deck:
		counts[c.id] = int(counts.get(c.id, 0)) + 1
	# kc-onboard §2.1: the Standard Issue starter replaced the kc-syn Recruit starter.
	assert_eq(counts, {&"kc_wip_private_1": 3, &"kc_wip_private_2": 3, &"kc_wip_private_3": 2, &"kc_wip_private_4": 1, &"ammo_resupply": 1}, "Standard Issue starter (kc-wip-impl W2: the Private ladder, 10 cards)")
	assert_false("starter_recruits" in cfg, "kc-no-training: no Recruit starter setting")
	assert_false(cfg.matches.any(func(md: RunMatchData) -> bool: return "enemy_recruits" in md), "kc-no-training: no Recruit squads")
	var pool: Dictionary = {}
	for c: CardData in cfg.reward_pool:
		pool[c.id] = int(pool.get(c.id, 0)) + 1
	assert_eq([pool.get(&"brawler", 0), pool[&"callout"], pool[&"flank_route"], pool[&"suppressing_fire"], pool[&"tripwire_charge"]],
			[2, 2, 2, 2, 2], "Brawler x2 and +1 Callout / Flank Route / Suppressing Fire / Tripwire")
	var es: SideSetup = SideSetup.from_squad(cfg.matches[0].squad, cfg.matches[0])
	assert_eq(es.deck_traits.size(), es.deck.size(), "slot 1 squad: one trait entry per copy")


func test_pitch_setup_keeps_traits_parallel() -> void:
	var cfg: RunConfig = preload("res://tests/legacy_starter.gd").config()  # kc-onboard: a starter of real chassis
	var s: SideSetup = SideSetup.new()
	s.deck = cfg.starter_deck.duplicate()
	s.deck_traits.assign(s.deck.map(func(c: CardData) -> StringName: return c.card_trait))
	var before: Array[StringName] = s.deck_traits.duplicate()
	PitchDecks.apply_setup(s)
	assert_eq(s.deck_traits, before, "inactive: unchanged")
	PitchDecks.forced = true
	PitchDecks.apply_setup(s)
	var swapped: Array[int] = []
	for i: int in s.deck.size():
		if s.deck[i] != cfg.starter_deck[i]:
			swapped.append(i)
	assert_true(not swapped.is_empty(), "the pitch swapped cards in")
	assert_eq(s.deck_traits.size(), s.deck.size(), "traits stay parallel")
	for i: int in s.deck.size():
		assert_eq(s.deck_traits[i], SynergyRules.TRAIT_DEFAULT if i in swapped else before[i], "swapped-in cards take their default trait")
	PitchDecks.forced = false

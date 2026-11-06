# test_rules_synergy.gd
# Purpose: kc-syn-impl (synergy-system.md, approved): neighbor keywords (Guard, Spotter, Fireteam,
#   Overwatch) and their geometry (A-C not adjacent, B the hub, enemies never neighbors, the
#   Operator a neighbor without keywords), live re-linking (eliminations, the Protector slide,
#   Flank Route), stacking caps, Cover / First Shot removal, trait sets (units + Trained Fields,
#   Recruits excluded, tiers 2 / 3, v1.1 numbers), the Undead heal, Doctrine, copy levels
#   (Recruit / Veteran / Elite, through the deck and the discard), the Operator's Supply cost
#   (refusal, payment, undo), SYNERGY_CHANGED, the UI hooks (synergy_view, preview_synergy,
#   card_level), MatchClone, the AI view / planner, and the shipped data.
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


## Unit with a neighbor keyword and / or trait (Trained by default).
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


# --- Geometry and the four keywords ------------------------------------------------------------

func test_guard_covers_the_card_behind_only() -> void:
	var m: MatchState = _match()
	var g: RulesUnit = F.place(m, P, _u("guard", 1, 5, &"guard"), M)
	var behind: RulesUnit = F.place(m, P, _plain("behind"), M)
	var third: RulesUnit = F.place(m, P, _plain("third"), M)
	var beside: RulesUnit = F.place(m, P, _plain("beside"), L)
	assert_eq([m.cover_of(g), m.cover_of(behind), m.cover_of(third), m.cover_of(beside)], [0, 1, 0, 0], "Guard: Cover +1 to the card behind")


func test_spotter_gives_the_card_in_front_one_fp() -> void:
	var m: MatchState = _match()
	var front: RulesUnit = F.place(m, P, _plain("front"), M)
	var spotter: RulesUnit = F.place(m, P, _u("spotter", 2, 3, &"spotter"), M)
	assert_eq([m.firepower_of(front), m.firepower_of(spotter)], [2, 2], "front 1 + 1, the Spotter itself unchanged")
	var lone: RulesUnit = F.place(m, P, _u("lone_spotter", 2, 3, &"spotter"), L)
	assert_eq(m.firepower_of(lone), 2, "a Spotter in row 1 has nobody in front (the objective is not a card)")


func test_fireteam_needs_a_friend_beside_and_caps_at_one() -> void:
	var m: MatchState = _match()
	var a: RulesUnit = F.place(m, P, _u("ft_a", 2, 2, &"fireteam"), L)
	assert_eq(m.firepower_of(a), 2, "alone: no bonus")
	var c: RulesUnit = F.place(m, P, _u("ft_c", 2, 2, &"fireteam"), R)
	assert_eq([m.firepower_of(a), m.firepower_of(c)], [2, 2], "A and C are not adjacent")
	var b: RulesUnit = F.place(m, P, _u("ft_b", 2, 2, &"fireteam"), M)
	assert_eq([m.firepower_of(a), m.firepower_of(b), m.firepower_of(c)], [3, 3, 3], "B is the hub: everyone has a neighbor; B gets +1, not +2")
	var a2: RulesUnit = F.place(m, P, _u("ft_a2", 2, 2, &"fireteam"), L)
	assert_eq(m.firepower_of(a2), 2, "row 2 of A has nobody beside it (B has one card)")


func test_overwatch_covers_both_sides_once() -> void:
	var m: MatchState = _match()
	var la: RulesUnit = F.place(m, P, _plain("la"), L)
	var ow: RulesUnit = F.place(m, P, _u("gunner", 2, 6, &"overwatch"), M)
	var rc: RulesUnit = F.place(m, P, _plain("rc"), R)
	assert_eq([m.cover_of(la), m.cover_of(ow), m.cover_of(rc)], [1, 0, 1], "B's Overwatch covers A1 and C1")
	var m2: MatchState = _match()
	F.place(m2, P, _u("ow_l", 2, 6, &"overwatch"), L)
	var hub: RulesUnit = F.place(m2, P, _plain("hub"), M)
	F.place(m2, P, _u("ow_r", 2, 6, &"overwatch"), R)
	assert_eq(m2.cover_of(hub), 1, "two Overwatch neighbors: still Cover +1")


func test_different_keywords_stack() -> void:
	var m: MatchState = _match()
	F.place(m, P, _u("guard", 1, 5, &"guard"), M)
	F.place(m, P, _plain("pad"), L)
	F.place(m, P, _u("ow", 1, 5, &"overwatch"), L)
	var target: RulesUnit = F.place(m, P, _plain("target"), M)
	assert_eq(m.cover_of(target), 2, "behind a Guard and beside an Overwatch: Cover +2")


func test_enemies_are_never_neighbors_and_the_operator_is_one() -> void:
	var m: MatchState = F.new_match(F.setup([], F.kestrel()), F.setup())
	var ft: RulesUnit = F.place(m, P, _u("ft", 2, 2, &"fireteam"), L)
	F.place(m, E, _u("foe_ow", 1, 5, &"overwatch"), M)
	F.place(m, E, _plain("foe"), L)
	assert_eq([m.firepower_of(ft), m.cover_of(ft)], [2, 0], "enemy cards give no links")
	F.place_operator(m, P, M)
	assert_eq(m.firepower_of(ft), 3, "the Operator beside counts as a friendly card")
	assert_eq(m.sides[P].operator_unit.neighbor_keyword, &"", "the Operator carries no keyword")


func test_links_follow_eliminations_and_moves() -> void:
	var m: MatchState = _match()
	F.place(m, P, _u("guard", 1, 9, &"guard"), M)
	var x: RulesUnit = F.place(m, P, _plain("x"), M)
	var y: RulesUnit = F.place(m, P, _plain("y"), M)
	assert_eq([m.cover_of(x), m.cover_of(y)], [1, 0], "x is behind the Guard")
	x.armor = 0
	m.process_eliminations()
	assert_eq(m.cover_of(y), 1, "y moved up behind the Guard and is covered now")
	# Flank Route: a Fireteam moved next to a friend links at once.
	var m2: MatchState = _match([F.flank_route()])
	var ft: RulesUnit = F.place(m2, P, _u("ft", 2, 2, &"fireteam"), L)
	F.place(m2, P, _plain("r1"), R)
	assert_eq(m2.firepower_of(ft), 2, "A1 has no neighbor (C is not adjacent)")
	var res: Dictionary = m2.submit(P, RulesIntent.play_card(F.hand_uid(m2, P, "flank_route"), L, ft.uid, M))
	assert_true(res["ok"], "Flank Route: %s" % res)
	m2.reveal()
	assert_eq(ft.zone, M, "moved to B")
	assert_eq(m2.firepower_of(ft), 3, "in B1 beside C1: Fireteam on")


func test_protector_slide_makes_a_shield_wall() -> void:
	var prot: CardData = F.shieldman()
	prot.neighbor_keyword = &"guard"
	var m: MatchState = _match([prot])
	var old_front: RulesUnit = F.place(m, P, _plain("old_front"), M)
	assert_eq(m.cover_of(old_front), 0, "no Guard yet")
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "shieldman"), M))["ok"], "Protector")
	m.reveal()
	assert_eq(m.sides[P].line(M)[0].source_id, &"shieldman", "slid to row 1")
	assert_eq(m.cover_of(old_front), 1, "the card it passed is now behind a Guard")


func test_cover_removal_and_blackout_strip_synergy() -> void:
	var m: MatchState = _match()
	F.place(m, P, _u("guard", 1, 5, &"guard"), M)
	var behind: RulesUnit = F.place(m, P, _plain("behind"), M)
	m.sides[E].flags[DataEnums.EffectKind.REMOVE_COVER] = m.round_number
	assert_eq(m.cover_of(behind), 0, "Recon Drone-style Cover removal takes link Cover too")
	var m2: MatchState = _match()
	var a: RulesUnit = F.place(m2, P, _u("so_a", 2, 2, &"", &"specops"), L)
	F.place(m2, P, _u("so_b", 2, 2, &"", &"specops"), M)
	F.place(m2, P, _u("so_c", 2, 2, &"", &"specops"), R)
	assert_true(m2.has_first_shot(a), "Spec Ops 3: First Shot")
	a.add_mod(DataEnums.EffectKind.REMOVE_FIRST_SHOT, 0, m2.round_number)
	assert_false(m2.has_first_shot(a), "Blackout-style REMOVE_FIRST_SHOT removes it")


# --- Traits and sets -------------------------------------------------------------------------

func test_vanguard_tiers() -> void:
	var m: MatchState = _match()
	var v1: RulesUnit = F.place(m, P, _u("v1", 2, 3, &"", &"vanguard"), L)
	var plain: RulesUnit = F.place(m, P, _plain("p"), M)
	assert_eq(m.firepower_of(v1), 2, "one Vanguard: no set")
	var v2: RulesUnit = F.place(m, P, _u("v2", 2, 3, &"", &"vanguard"), L)
	assert_eq([m.firepower_of(v1), m.firepower_of(v2), m.cover_of(v1)], [3, 2, 0], "Vanguard 2: +1 FP in row 1 only")
	assert_eq(m.firepower_of(plain), 1, "untraited units get nothing")
	var v3: RulesUnit = F.place(m, P, _u("v3", 2, 3, &"", &"vanguard"), R)
	assert_eq([m.cover_of(v1), m.cover_of(v2), m.cover_of(v3), m.cover_of(plain)], [1, 1, 1, 0], "Vanguard 3: Cover +1 to every Vanguard")
	assert_eq([m.firepower_of(v1), m.firepower_of(v3)], [3, 3], "tier 3 includes tier 2")


func test_specops_heavy_undead_tiers() -> void:
	var m: MatchState = _match()
	var s1: RulesUnit = F.place(m, P, _u("s1", 2, 3, &"", &"specops"), L)
	F.place(m, P, _plain("pad"), M)
	var s2: RulesUnit = F.place(m, P, _u("s2", 2, 3, &"", &"specops"), M)
	assert_eq([m.firepower_of(s1), m.firepower_of(s2)], [3, 3], "Spec Ops 2: +1 FP to all Spec Ops (v1.1)")
	assert_false(m.has_first_shot(s1), "no First Shot at 2")
	var h: MatchState = _match()
	var h1: RulesUnit = F.place(h, P, _u("h1", 2, 6, &"", &"heavy"), L)
	F.place(h, P, _u("h2", 2, 6, &"", &"heavy"), R)
	assert_eq([h.cover_of(h1), h.firepower_of(h1)], [0, 2], "Heavy 2: no bonus (kc-art-traits §5, head T3)")
	assert_eq(int(h.synergy_side(P)["tiers"][&"heavy"]), 0, "no active tier at 2")
	F.place(h, P, _u("h3", 2, 6, &"", &"heavy"), R)
	assert_eq([h.cover_of(h1), h.firepower_of(h1)], [1, 3], "Heavy 3: Cover +1 and +1 FP")
	var u: MatchState = _match()
	var u1: RulesUnit = F.place(u, P, _u("u1", 2, 3, &"", &"undead"), L)
	F.place(u, P, _u("u2", 2, 3, &"", &"undead"), R)
	assert_eq(int(u.synergy_of(u1)["heal"]), 1, "Undead 2: heal 1")
	assert_eq([u.firepower_of(u1), u.cover_of(u1)], [2, 0], "no FP or Cover at 2")
	F.place(u, P, _u("u3", 2, 3, &"", &"undead"), M)
	assert_eq([u.firepower_of(u1), u.cover_of(u1)], [3, 1], "Undead 3: +1 FP and Cover +1 (head T3)")


func test_fields_count_for_sets_and_recruits_do_not() -> void:
	var m: MatchState = _match()
	var br: RulesUnit = F.place(m, P, _u("breacher", 3, 4, &"guard", &"vanguard"), L)
	assert_eq(m.firepower_of(br), 3, "one Vanguard")
	F.place_field(m, P, _field("bulwark_t", &"vanguard"), R)
	assert_eq(m.firepower_of(br), 4, "Bulwark + Breacher = Vanguard 2 (the Field gets nothing, it has no stats)")
	assert_eq(int(m.synergy_side(P)["counts"][&"vanguard"]), 2, "count includes the Field")
	# kc-onboard (N1): a Recruit copy of a traited chassis counts for its trait but has no keyword.
	var m2: MatchState = _match()
	var card: CardData = _u("pm", 2, 3, &"fireteam", &"vanguard")
	var t1: RulesUnit = F.place(m2, P, card, L)
	var rec: RulesUnit = m2.create_unit(P, card, -1, SynergyRules.LEVEL_RECRUIT)
	m2.put_in_line(rec, M)
	assert_eq([rec.neighbor_keyword, rec.synergy_trait], [&"", &"vanguard"], "a Recruit: its trait, no keyword")
	assert_eq(int(m2.synergy_side(P)["counts"].get(&"vanguard", 0)), 2, "the Recruit counts for Vanguard")
	assert_eq(m2.firepower_of(t1), 4, "the Trained copy links with the Recruit beside it (+1 Fireteam) and Vanguard 2 (+1 front)")
	assert_eq(m2.firepower_of(rec), 3, "the Recruit gets the set bonus but no Fireteam bonus")
	# A Field's trait counts at any level; hidden traps never do.
	var m3: MatchState = _match()
	var lone: RulesUnit = F.place(m3, P, _u("v", 2, 3, &"", &"vanguard"), L)
	var rf: RulesCard = RulesCard.new(m3.new_uid(), _field("bulwark_r", &"vanguard"), SynergyRules.LEVEL_RECRUIT)
	m3.sides[P].equipment[R].append({"card": rf, "round": 0})
	assert_eq(m3.firepower_of(lone), 3, "a Field counts (kc-onboard: the level never removes a trait)")


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
	assert_eq(m.firepower_of(v), 3, "one Trained Vanguard + Doctrine = tier 2")
	assert_eq(m.firepower_of(plain), 1, "untraited: nothing")
	var foe: RulesUnit = F.place(m, E, _u("fv", 2, 3, &"", &"vanguard"), L)
	assert_eq(m.firepower_of(foe), 2, "Doctrine is per side")


# --- Levels ----------------------------------------------------------------------------------

func test_levels_from_the_deck_to_the_board_and_discard() -> void:
	var card: CardData = _u("pm", 2, 3, &"fireteam", &"vanguard")
	var s: SideSetup = F.setup([card, card, card, card])
	s.deck_levels.assign([0, 1, 2, 3])
	var m: MatchState = F.new_match(s, F.setup())
	var levels: Array = m.sides[P].hand.map(func(rc: RulesCard) -> int: return rc.level)
	assert_eq(levels, [0, 1, 2, 3], "RulesCard.level from SideSetup.deck_levels")
	assert_eq(m.card_level(m.sides[P].hand[2].uid), 2, "card_level by uid")
	var units: Array[RulesUnit] = []
	for i: int in 4:
		var rc: RulesCard = m.sides[P].hand[i]
		var u: RulesUnit = m.create_unit(P, rc.card, rc.uid, rc.level)
		units.append(u)
	assert_eq(units.map(func(u: RulesUnit) -> Array: return [u.base_firepower, u.base_max_armor, u.neighbor_keyword]),
			[[2, 3, &""], [2, 3, &"fireteam"], [2, 4, &"fireteam"], [3, 4, &"fireteam"]],
			"Recruit plain, Trained full, Veteran +1 Armor, Elite +1 Armor +1 FP")
	m.put_in_line(units[0], L)
	units[0].armor = 0
	m.process_eliminations()
	assert_eq(m.sides[P].discard.back().level, 0, "a Recruit goes to the discard as a Recruit")
	var none: SideSetup = F.setup([card])
	assert_eq(none.level_of(0), SynergyRules.LEVEL_TRAINED, "no deck_levels = Trained")


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
	assert_eq(prev["new_links"].size(), 2, "two new links: Overwatch on A1 and C1")
	assert_eq([prev["new_links"][0]["kind"], prev["new_links"][0]["to_uid"]], [&"overwatch", a1.uid], "link shape")
	assert_eq([int(prev["tiers_before"].get(&"heavy", 0)), int(prev["tiers_after"][&"heavy"])], [0, 3], "Heavy 2 (no bonus) -> 3")
	assert_eq(int(prev["card"]["cover"]), 1, "the Gunner itself gets Heavy 3 Cover")
	assert_false(m.preview_synergy(P, 9999, M)["ok"], "unknown card")
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "gunner"), M))["ok"], "play it")
	m.reveal()
	var v: Dictionary = m.synergy_view(P)
	assert_eq(v["player"]["rail"].size(), 1, "rail lists traits in play")
	assert_eq([v["player"]["rail"][0]["trait"], v["player"]["rail"][0]["count"], v["player"]["rail"][0]["tier"], v["player"]["rail"][0]["next"]],
			[&"heavy", 3, 3, 0], "rail entry")
	var ua: Dictionary = v["units"][a1.uid]
	assert_eq([ua["cover"], ua["links"].size(), ua["sets"], ua["band"]], [2, 1, [[&"heavy", 3]], &"gilded"], "unit entry")
	var copy: MatchState = MatchClone.copy(m)
	assert_eq(copy.cover_of(copy.find_unit(a1.uid)), m.cover_of(a1), "the clone reads the same synergy")
	copy.find_unit(a1.uid).armor = 0
	copy.process_eliminations()
	assert_eq(m.cover_of(a1), 2, "the live match is untouched")


# --- AI ----------------------------------------------------------------------------------------

func test_ai_view_records_carry_synergy_and_levels() -> void:
	var card: CardData = _u("pm", 2, 3, &"fireteam", &"vanguard")
	var s: SideSetup = F.setup([card, card])
	s.deck_levels.assign([0, 1])
	var m: MatchState = F.new_match(F.setup(), s)
	var cfg_cost: int = m.operator_cost()
	F.place(m, E, card, L)
	F.place(m, E, _plain("mate"), M)
	var v: AiView = AiView.capture(m, E)
	var rec: Dictionary = v.lines[AiView.ME][L][0]
	assert_eq([rec["kw"], rec["trait"], rec["level"], rec["syn_fp"], rec["fp"]], [&"fireteam", &"vanguard", 1, 1, 3], "record")
	assert_eq(v.hand.map(func(h: Dictionary) -> int: return h["level"]), [0, 1], "hand levels")
	assert_eq(v.operator_cost, cfg_cost, "Operator cost in the view")
	var r0: Dictionary = v.record_for_card(card, -5, L, 0)
	var r3: Dictionary = v.record_for_card(card, -6, L, 3)
	assert_eq([r0["kw"], r0["armor"], r3["fp"], r3["armor"]], [&"", 3, 3, 4], "record_for_card applies the level")


func test_aware_planner_deploys_into_a_link() -> void:
	# One Overwatch Gunner in B1; the only card is a Fireteam unit. A and C are both beside B1,
	# so the aware planner puts it in A or C (Fireteam + Overwatch Cover), never behind the Gunner.
	var ft: CardData = _u("ft", 2, 3, &"fireteam", &"", {"cost": 1})
	var picks: Dictionary = {}
	for aware: bool in [true, false]:
		var m: MatchState = _match([], [ft])
		F.place(m, E, _u("gunner", 2, 6, &"overwatch"), M)
		var pers: AiPersonality = AiPersonality.new()
		pers.preferred_zone_bonus = 0.0
		pers.card_keep_cost = 0.0
		var planner: AiPlanner = AiPlanner.new(pers)
		planner.synergy_aware = aware
		var res: Dictionary = planner.plan(AiView.capture(m, E))
		var zone: int = -1
		for it: Dictionary in res["intents"]:
			if it["type"] == RulesIntent.PLAY_CARD:
				zone = int(it["zone"])
		picks[aware] = zone
	assert_true(picks[true] in [L, R], "aware: beside the Gunner (got %d)" % picks[true])


func test_ai_pays_the_operator_cost() -> void:
	var cfg: RunConfig = RunConfig.new()
	cfg.operator_cost = 1
	var cheap: CardData = _plain("cheap")
	var m: MatchState = F.new_match(F.setup(), F.setup([cheap, cheap, cheap], F.kestrel()), null, 3, null, cfg)
	m.sides[E].supply = 1
	var ai: AiPlayer = AiPlayer.new(AiPersonality.new())
	ai.take_turn(m, E)
	assert_eq(ai.last_rejected, [] as Array[Dictionary], "no refused intent")
	assert_true(m.sides[E].supply >= 0, "never overspends")
	var placed: bool = m.sides[E].plays.any(func(p: Dictionary) -> bool: return p["kind"] == &"place")
	var units: int = m.sides[E].plays.filter(func(p: Dictionary) -> bool: return p["kind"] == &"unit").size()
	assert_true(placed != (units > 0) or not placed, "with 1 Supply: the Operator or a 1-drop, not both")


# --- Data --------------------------------------------------------------------------------------

func test_shipped_chassis_keywords_traits_and_numbers() -> void:
	var want: Dictionary = {
		&"rifleman": [&"fireteam", &""], &"point_man": [&"fireteam", &"vanguard"], &"breacher": [&"guard", &"vanguard"],
		&"shieldman": [&"", &"vanguard"], &"flanker": [&"", &"specops"], &"recon_specialist": [&"spotter", &"specops"],
		&"marksman": [&"spotter", &"specops"], &"halek_wren": [&"", &"specops"], &"gunner": [&"overwatch", &"heavy"],
		&"demolitions_expert": [&"", &"heavy"], &"okafor_anvil": [&"", &"heavy"], &"brawler": [&"fireteam", &"undead"],
		&"combat_medic": [&"", &"undead"], &"bulwark": [&"", &"vanguard"], &"sniper_perch": [&"", &"specops"],
		&"mortar_pit": [&"", &"heavy"], &"war_standard": [&"", &"undead"], &"aid_station": [&"", &"undead"],
		&"listening_post": [&"", &""], &"tripwire_charge": [&"", &""], &"comms_relay": [&"", &""], &"sentry": [&"", &""],
		&"callout": [&"", &""],
	}
	for id: StringName in want:
		var c: CardData = load("res://data/cards/%s.tres" % id) as CardData
		assert_eq([c.neighbor_keyword, c.card_trait], want[id], "%s keyword / trait" % id)
	var recon: CardData = load("res://data/cards/recon_specialist.tres") as CardData
	assert_eq([recon.cost, recon.firepower, recon.armor], [2, 2, 3], "Recon Specialist 2/3 (v1.1)")


func test_validator_rejects_bad_synergy_data() -> void:
	var v: DataValidator = DataValidator.new()
	var t: CardData = F.hold_the_line()
	t.neighbor_keyword = &"guard"
	t.card_trait = &"vanguard"
	t.validate(v)
	var u: CardData = F.unit("u", 1, 1, DataEnums.WeaponClass.NONE, {"neighbor_keyword": &"sniping", "card_trait": &"robots"})
	u.validate(v)
	var text: String = str(v.issues)
	assert_true(text.contains("neighbor_keyword") and text.contains("card_trait"), "issues reported: %s" % text)


func test_shipped_starter_squads_and_pool() -> void:
	var cfg: RunConfig = load("res://data/run_config.tres") as RunConfig
	var counts: Dictionary = {}
	for c: CardData in cfg.starter_deck:
		counts[c.id] = int(counts.get(c.id, 0)) + 1
	# kc-onboard §2.1: the Standard Issue starter replaced the kc-syn Recruit starter.
	assert_eq(counts, {&"si_grunt": 5, &"si_trooper": 6, &"si_sergeant": 4, &"si_armored": 3, &"ammo_resupply": 2}, "Standard Issue starter")
	assert_false(cfg.starter_recruits, "no Recruit starter")
	assert_eq(cfg.matches.map(func(md: RunMatchData) -> bool: return md.enemy_recruits), [true, true, true, false, false], "slots 1-3 play Recruits (kc-onboard §4.4)")
	var pool: Dictionary = {}
	for c: CardData in cfg.reward_pool:
		pool[c.id] = int(pool.get(c.id, 0)) + 1
	assert_eq([pool.get(&"brawler", 0), pool[&"callout"], pool[&"flank_route"], pool[&"suppressing_fire"], pool[&"tripwire_charge"]],
			[2, 2, 2, 2, 2], "Brawler x2 and +1 Callout / Flank Route / Suppressing Fire / Tripwire")
	var es: SideSetup = SideSetup.from_squad(cfg.matches[0].squad, cfg.matches[0])
	for i: int in es.deck.size():
		assert_eq(es.level_of(i), 0 if es.deck[i].is_unit() else 1, "slot 1 squad: units are Recruits")
	var es4: SideSetup = SideSetup.from_squad(cfg.matches[3].squad, cfg.matches[3])
	assert_true(es4.deck_levels.is_empty(), "slot 4 squad: Trained")


func test_pitch_setup_keeps_levels_parallel_and_trains() -> void:
	var cfg: RunConfig = preload("res://tests/legacy_starter.gd").config()  # kc-onboard: a starter of real chassis
	var s: SideSetup = SideSetup.new()
	s.deck = cfg.starter_deck.duplicate()
	s.deck_levels = cfg.starter_levels()
	PitchDecks.apply_setup(s)
	assert_eq(s.deck_levels, cfg.starter_levels(), "inactive: unchanged")
	PitchDecks.forced = true
	PitchDecks.apply_setup(s, false)
	var swapped: Array[int] = []
	for i: int in s.deck.size():
		if s.deck[i] != cfg.starter_deck[i]:
			swapped.append(i)
	assert_true(not swapped.is_empty(), "the pitch swapped cards in")
	assert_eq(s.deck_levels.size(), s.deck.size(), "levels stay parallel")
	for i: int in s.deck.size():
		assert_eq(s.deck_levels[i], 1 if i in swapped else 0, "swapped-in cards are Trained, the rest keep their level")
	PitchDecks.apply_setup(s)
	PitchDecks.forced = false
	assert_true(s.deck_levels.all(func(lv: int) -> bool: return lv == 1), "train_all: the pitch plays every copy Trained")

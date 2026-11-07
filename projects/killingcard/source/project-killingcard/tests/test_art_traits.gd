# test_art_traits.gd
# Purpose: kc-art-traits-impl (documentation/design/art-traits.md, head T1-T4 + F1/F2): the trait
#   comes from the copy's art. Rules: per-copy traits (deck_traits -> RulesCard -> unit -> discard),
#   options and plain arts, printed Elites / Fields, two copies counting for different
#   traits, the AI planner keeping them apart, LMG Pierce (units and the Operator). Data: option
#   lists, validator, squad identities. ArtTraits: family / trait of every art id form, licensed
#   manifest family column, a free default art for every option (fairness rule v2). Run: offers
#   with traits and arts (on-trait slot, 60/40), free same-trait art swaps, Codex EQUIP, per-copy
#   trait counts, save round trip and v2 migration, RunState wrappers. kc-no-training: at most one
#   trait per copy (CardData validation, the art map, the save).
# Author: Mechanics Developer Agent (kc-art-traits-impl)
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const E: int = 1
const SEED: int = 4321

## art-traits.md §4 (approved T1).
const OPTIONS: Dictionary = {
	&"rifleman": [&"", &"specops", &"undead"], &"point_man": [&"vanguard", &"undead"],
	&"breacher": [&"vanguard", &"heavy"], &"shieldman": [&"vanguard", &"undead"],
	&"flanker": [&"specops", &"undead"], &"recon_specialist": [&"specops", &"undead"],
	&"marksman": [&"specops", &"heavy"], &"gunner": [&"heavy", &"specops"],
	&"demolitions_expert": [&"heavy", &"undead"], &"brawler": [&"undead", &"specops"],
	&"combat_medic": [&"undead", &"specops"],
}


func _card(id: String) -> CardData:
	return load("res://data/cards/%s.tres" % id) as CardData


## kc-onboard: these tests pin the kc-syn / kc-art-traits mechanics on the old kc-syn starter with
## the onboarding ladder off (tests/legacy_starter.gd); the shipped ladder is test_onboarding.gd's.
func _config(offers: bool = true) -> RunConfig:
	return preload("res://tests/legacy_starter.gd").config(offers)


func _run(offers: bool = true, seed_value: int = SEED) -> RunProgress:
	var r: RunProgress = RunProgress.create(_config(offers), seed_value)
	r.begin()
	return r


## Adds a copy with a trait straight to a run deck (test setup).
func _add(r: RunProgress, id: StringName, t: StringName) -> int:
	r._append_copy(id, t, ArtTraits.default_art(_card(String(id)), t))
	return r.deck.size() - 1


# =============================================================================
# Rules
# =============================================================================

func test_trait_at_options_plain_and_default() -> void:
	var mk: CardData = _card("marksman")
	assert_eq(SynergyRules.trait_at(mk), &"specops", "default = the home trait")
	assert_eq(SynergyRules.trait_at(mk, &"heavy"), &"heavy", "an option")
	assert_eq(SynergyRules.trait_at(mk, &"vanguard"), &"", "not an option: plain")
	assert_eq(SynergyRules.trait_at(mk, &""), &"", "a plain art")
	var rifle: CardData = _card("rifleman")
	assert_eq([SynergyRules.trait_at(rifle), SynergyRules.trait_at(rifle, &"undead")], [&"", &"undead"], "Rifleman: none by default")
	assert_eq(SynergyRules.trait_at(_card("halek_wren"), &"heavy"), &"specops", "the Ace prints Spec Ops")
	assert_eq(SynergyRules.trait_at(_card("okafor_anvil"), &"specops"), &"heavy", "the Commander prints Heavy")
	assert_eq(SynergyRules.trait_at(_card("bulwark"), &"undead"), &"vanguard", "Fields print theirs")
	assert_eq(SynergyRules.trait_at(_card("callout"), &"undead"), &"", "tactics never")


func test_deck_traits_flow_into_cards_units_and_discard() -> void:
	var mk: CardData = _card("marksman")
	var s: SideSetup = F.setup([mk, mk])
	s.deck_traits.assign([&"heavy", SynergyRules.TRAIT_DEFAULT])
	var m: MatchState = F.new_match(s, F.setup())
	var all: Array[RulesCard] = []
	all.append_array(m.sides[P].hand)
	all.append_array(m.sides[P].deck)
	var traits: Array = all.map(func(rc: RulesCard) -> String: return String(rc.card_trait()))
	traits.sort()
	assert_eq(traits, ["heavy", "specops"], "each copy carries its own trait")
	var heavy_rc: RulesCard = all.filter(func(rc: RulesCard) -> bool: return rc.card_trait() == &"heavy")[0]
	var u: RulesUnit = m.create_unit(P, heavy_rc.card, heavy_rc.uid, heavy_rc.chosen_trait)
	m.put_in_line(u, 0)
	assert_eq([u.synergy_trait, u.chosen_trait], [&"heavy", &"heavy"], "the unit keeps it")
	u.armor = 0
	m.process_eliminations()
	var back: RulesCard = m.sides[P].discard.back()
	assert_eq([back.uid, back.card_trait()], [u.uid, &"heavy"], "and so does the card in the discard pile")
	assert_eq(SideSetup.new().trait_of(5), SynergyRules.TRAIT_DEFAULT, "a missing entry = the default")


func test_two_copies_count_for_different_traits() -> void:
	var mk: CardData = _card("marksman")
	var gun: CardData = _card("gunner")
	var m: MatchState = F.new_match()
	m.put_in_line(m.create_unit(P, mk, -1, &"heavy"), 0)
	m.put_in_line(m.create_unit(P, mk, -1, &"specops"), 1)
	m.put_in_line(m.create_unit(P, gun), 2)
	var counts: Dictionary = m.synergy_side(P)["counts"]
	assert_eq([int(counts.get(&"heavy", 0)), int(counts.get(&"specops", 0))], [2, 1], "Marksman Heavy + Gunner = Heavy 2; Spec Ops 1")
	m.put_in_line(m.create_unit(P, _card("breacher"), -1, &"heavy"), 0)
	var tiers: Dictionary = m.synergy_side(P)["tiers"]
	assert_eq(int(tiers[&"heavy"]), 3, "a Heavy Breacher makes the 3-set")
	var rec: RulesUnit = m.create_unit(P, mk, -1, &"heavy")
	assert_eq([rec.synergy_trait, rec.pick], [&"heavy", true], "a Marksman with a Heavy art is Heavy and keeps Pick (kc-no-training)")


func test_ai_planner_keeps_copies_with_different_traits_apart() -> void:
	var mk: CardData = _card("marksman")
	var s: SideSetup = F.setup([mk, mk, mk])
	s.deck_traits.assign([&"heavy", &"specops", &"specops"])
	var m: MatchState = F.new_match(F.setup(), s)
	m.sides[E].hand.append_array(m.sides[E].deck)
	m.sides[E].deck.clear()
	m.sides[E].supply = 10
	var view: AiView = AiView.capture(m, E)
	assert_eq(view.hand.map(func(h: Dictionary) -> StringName: return h["trait"]), [&"heavy", &"specops", &"specops"], "the view carries the copy's trait")
	var planner: AiPlanner = AiPlanner.new()
	planner._begin(view)
	var cands: Array[Dictionary] = planner._candidates(planner._root_plan())
	var units: Array = cands.filter(func(a: Dictionary) -> bool: return a["kind"] == &"unit")
	assert_eq(units.size(), 6, "2 designs (Heavy / Spec Ops Marksman) x 3 zones")
	var rec: Dictionary = view.record_for_card(mk, -1, 0, &"heavy")
	assert_eq(rec["trait"], &"heavy", "the projected record carries it")


func test_every_lmg_has_pierce_including_the_operator() -> void:
	var lmg: CardData = F.unit("lmg_x", 2, 4, DataEnums.WeaponClass.LMG)
	var m: MatchState = F.new_match(F.setup([], F.primary("lmg_gun", 2, 4, DataEnums.WeaponClass.LMG)),
			F.setup([], F.primary("ar_gun", 2, 4, DataEnums.WeaponClass.AR)))
	assert_true(m.create_unit(P, lmg).pierce, "an LMG unit has Pierce without printing it")
	assert_false(m.create_unit(P, F.unit("ar_x", 2, 4, DataEnums.WeaponClass.AR)).pierce, "an AR doesn't")
	assert_true(m.sides[P].operator_unit.pierce, "an Operator with an LMG primary has Pierce (head F2)")
	assert_false(m.sides[E].operator_unit.pierce, "an AR Operator doesn't")
	var view: AiView = AiView.capture(m, P)
	assert_true(view.record_for_card(lmg, -1, 0)["pierce"], "the AI's projection knows it")


func test_set_bonus_numbers_v1_2() -> void:
	assert_eq(SynergyRules.active_tier(&"heavy", 2), 2, "Heavy 2: Cover +1 (v2.1, head V6)")
	assert_eq(SynergyRules.active_tier(&"heavy", 3), 3, "Heavy 3")
	assert_eq(SynergyRules.active_tier(&"vanguard", 2), 2, "others unchanged")
	assert_eq([SynergyRules.next_tier(&"heavy", 0), SynergyRules.next_tier(&"undead", 0), SynergyRules.next_tier(&"undead", 3), SynergyRules.next_tier(&"vanguard", 2)], [2, 2, 0, 0], "next set size (Vanguard: nothing at 3 since v2.1)")
	var lines: Array = [[SynergyRules.slot(1, &"", &"undead")], [SynergyRules.slot(2, &"", &"undead")], [SynergyRules.slot(3, &"", &"undead")]]
	var r: Dictionary = SynergyRules.compute(lines)
	assert_eq([r["zones"][0][0]["fp"], r["zones"][0][0]["cover"], r["zones"][0][0]["heal"]], [1, 1, 1], "Undead 3: +1 FP, Cover +1, heal 1")
	var h2: Dictionary = SynergyRules.compute([[SynergyRules.slot(1, &"", &"heavy")], [SynergyRules.slot(2, &"", &"heavy")], []])
	assert_eq([h2["zones"][0][0]["cover"], h2["zones"][0][0]["sets"], int(h2["tiers"][&"heavy"])], [1, [[&"heavy", 2]], 2], "Heavy 2: Cover +1 (v2.1)")


# =============================================================================
# Data
# =============================================================================

func test_option_lists_match_the_approved_table() -> void:
	for id: StringName in OPTIONS:
		var c: CardData = _card(String(id))
		assert_eq(c.trait_choices(), OPTIONS[id] as Array[StringName], "%s options" % id)
		assert_eq(c.trait_choices()[0], c.card_trait, "%s default first" % id)
	for id: String in ["halek_wren", "okafor_anvil", "bulwark", "sniper_perch", "mortar_pit", "war_standard", "aid_station"]:
		var c: CardData = _card(id)
		assert_eq([c.has_trait_choice(), c.trait_choices().size()], [false, 1], "%s prints its trait" % id)
	for id: String in ["callout", "sentry", "ammo_resupply"]:
		assert_eq(_card(id).trait_choices(), [] as Array[StringName], "%s never has a trait" % id)


func test_validator_rejects_bad_option_lists() -> void:
	var cases: Array = [
		[{"card_trait": &"specops", "trait_options": [&"heavy", &"specops"]}, "default not first"],
		[{"card_trait": &"specops", "trait_options": [&"specops", &"robots"]}, "unknown trait"],
		[{"card_trait": &"specops", "trait_options": [&"specops", &"specops"]}, "duplicate"],
		[{"card_trait": &"specops", "trait_options": [&"specops", &"heavy"], "is_elite": true}, "Elites print theirs"],
	]
	for cs: Array in cases:
		var c: CardData = _card("marksman").duplicate() as CardData
		for k: String in cs[0]:
			var val: Variant = cs[0][k]
			if k == "trait_options":
				var arr: Array[StringName] = []
				arr.assign(val)
				c.trait_options = arr
			else:
				c.set(k, val)
		var v: DataValidator = DataValidator.new()
		c.validate(v)
		assert_true(v.error_count() > 0, cs[1])
	var ok: DataValidator = DataValidator.new()
	_card("rifleman").validate(ok)
	assert_eq(ok.error_count(), 0, "the Rifleman's [none, Spec Ops, Undead] is valid")


## kc-no-training (head: "make sure cards only have 1 trait at most"): CardData and the art map
## reject a second trait; every shipped card and art resolves to at most one trait per copy.
func test_a_card_copy_has_at_most_one_trait() -> void:
	for bad: StringName in [&"vanguard,undead", &"heavy|specops", &"vanguard undead", &"specopsheavy"]:
		var c: CardData = _card("bulwark").duplicate() as CardData
		c.card_trait = bad
		var v: DataValidator = DataValidator.new()
		c.validate(v)
		assert_true(v.issues.any(func(i: Dictionary) -> bool: return str(i).contains("at most one trait")),
				"card_trait '%s' is rejected as two traits" % bad)
	var mk: CardData = _card("marksman").duplicate() as CardData
	var opts: Array[StringName] = [&"specops", &"specops,heavy"]
	mk.trait_options = opts
	var v2: DataValidator = DataValidator.new()
	mk.validate(v2)
	assert_true(v2.issues.any(func(i: Dictionary) -> bool: return str(i).contains("at most one trait")), "a trait option naming two traits is rejected")
	# The art map: one trait per family, one family per trait.
	assert_eq(ArtTraits.validate_map(), [] as Array[String], "the art -> trait map gives one trait per art")
	assert_eq(ArtTraits.single_family("honors|horde"), &"", "a manifest cell naming two families is not a family")
	assert_eq(ArtTraits.single_family(" Mastery "), &"mastery", "one family")
	# Every shipped card: every art a copy can wear gives at most one trait, one of its options.
	for f: String in DirAccess.get_files_at("res://data/cards/"):
		if not f.ends_with(".tres"):
			continue
		var c: CardData = load("res://data/cards/" + f) as CardData
		assert_eq(ArtTraits.card_problems(c), [] as Array[String], "%s: one trait per art" % c.id)
		var dv: DataValidator = DataValidator.new()
		c.validate(dv)
		assert_false(dv.issues.any(func(i: Dictionary) -> bool: return str(i).contains("at most one trait")), "%s: one trait" % c.id)
	# Every copy of the shipped run and squads carries one trait value.
	var cfg: RunConfig = load("res://data/run_config.tres") as RunConfig
	for md: RunMatchData in cfg.matches:
		var s: SideSetup = SideSetup.from_squad(md.squad, md)
		for i: int in s.deck.size():
			var t: StringName = SynergyRules.trait_at(s.deck[i], s.trait_of(i))
			assert_true(SynergyRules.is_single_trait(t), "%s copy %d: one trait (%s)" % [md.squad.id, i, t])
	# The run never stores two traits on a copy.
	var r: RunProgress = _run()
	r._append_copy(&"marksman", &"specops,heavy", &"marksman")
	assert_eq(r.copy_trait(r.deck.size() - 1), &"", "a combined trait is refused (plain copy)")


func test_licensed_family_cell_with_two_families_falls_back_home() -> void:
	var saved_dir: String = BannerArtDB.licensed_dir
	var saved_on: bool = BannerArtDB.licensed_enabled
	var dir: String = "user://kc_one_trait_test/"
	DirAccess.make_dir_recursive_absolute(dir)
	var f: FileAccess = FileAccess.open(dir + "manifest.csv", FileAccess.WRITE)
	f.store_string("file,kind,card,title,id,family\n" + "a.webp,unit,marksman,Dual,kc_t_dual,mastery|honors\n")
	f.close()
	BannerArtDB.licensed_dir = dir
	BannerArtDB.licensed_enabled = true
	var mk: CardData = _card("marksman")
	assert_eq([ArtTraits.family_of(&"kc_t_dual", mk), ArtTraits.trait_of(&"kc_t_dual", mk)], [&"operators", &"specops"],
			"an art naming two families gets the home family: one trait")
	assert_eq(ArtTraits.card_problems(mk), [] as Array[String], "still one trait per art")
	BannerArtDB.licensed_dir = saved_dir
	BannerArtDB.licensed_enabled = saved_on
	DirAccess.remove_absolute(dir + "manifest.csv")
	ArtTraits.clear_cache()


func test_squads_have_a_fixed_art_identity() -> void:
	var expect: Dictionary = {"squad_rusher": &"vanguard", "squad_anchor": &"heavy", "squad_black_meridian": &"specops"}
	for id: String in expect:
		var sq: SquadData = load("res://data/squads/%s.tres" % id) as SquadData
		assert_eq(sq.identity_trait, expect[id], "%s identity" % id)
		var s: SideSetup = SideSetup.from_squad(sq)
		for i: int in s.deck.size():
			var c: CardData = s.deck[i]
			if c.has_trait_choice() and c.can_carry(sq.identity_trait):
				assert_eq(s.trait_of(i), sq.identity_trait, "%s: %s wears the crew's family" % [id, c.id])
	var rival: SideSetup = SideSetup.from_squad(load("res://data/squads/squad_black_meridian.tres") as SquadData)
	var m: MatchState = F.new_match(F.setup(), rival)
	for rc: RulesCard in m.sides[E].deck + m.sides[E].hand:
		if rc.card.id == &"okafor_anvil":
			assert_eq(rc.card_trait(), &"heavy", "the Rival's Commander stays Heavy")
		elif rc.card.id == &"marksman":
			assert_eq(rc.card_trait(), &"specops", "the Rival's Marksman is Spec Ops")
	# The rest go to the trait most of them share.
	var deck: Array[CardData] = [_card("gunner"), _card("point_man"), _card("shieldman"), _card("flanker"), _card("callout")]
	assert_eq(SideSetup.identity_traits(deck, &"heavy"), [&"heavy", &"undead", &"undead", &"undead", SynergyRules.TRAIT_DEFAULT] as Array[StringName],
			"Heavy crew: the Gunner Heavy, the rest Undead (3 can share it)")
	# The Bracket-1 squad is Standard Issue: no traits on the board.
	var md: RunMatchData = (load("res://data/run_config.tres") as RunConfig).matches[0]
	var b1: SideSetup = SideSetup.from_squad(md.squad, md)
	var mb: MatchState = F.new_match(F.setup(), b1)
	assert_true((mb.sides[E].deck + mb.sides[E].hand).all(func(rc: RulesCard) -> bool: return not rc.card.is_unit() or rc.card_trait() == &""), "the Standard Issue crew shows no trait")


# =============================================================================
# ArtTraits
# =============================================================================

func test_family_and_trait_of_every_art_id_form() -> void:
	var mk: CardData = _card("marksman")
	assert_eq([ArtTraits.family_of(&"marksman", mk), ArtTraits.trait_of(&"marksman", mk)], [&"operators", &"specops"], "the chassis id = home option")
	assert_eq(ArtTraits.trait_of(&"", mk), &"specops", "no art = default")
	assert_eq(ArtTraits.trait_of(&"marksman~night", mk), &"specops", "a public look keeps the home trait")
	assert_eq(ArtTraits.trait_of(&"marksman~mastery", mk), &"heavy", "the Mastery option art")
	assert_eq(ArtTraits.trait_of(&"marksman~honors", mk), &"", "an Honors art on a Marksman is plain (Vanguard isn't an option)")
	assert_eq(ArtTraits.trait_of(&"rifleman", _card("rifleman")), &"", "the Rifleman's home is no trait")
	assert_eq(ArtTraits.trait_of(&"rifleman~horde", _card("rifleman")), &"undead", "Rifleman · Undead")
	assert_eq(ArtTraits.trait_of(&"halek_wren~horde", _card("halek_wren")), &"specops", "printed Elite: art is cosmetic")
	assert_eq(ArtTraits.family_for_section("Weapon Mastery / Zombies / Modern Warfare III"), &"mastery", "every mastery ladder is Mastery")
	assert_eq(ArtTraits.family_for_section("Prestige Mastery / Zombies"), &"horde", "prestige zombies = Horde")
	assert_eq(ArtTraits.family_for_section("Ranked Play / Warzone"), &"operators", "Warzone joins Operators")
	assert_eq(ArtTraits.family_for_section("Campaign"), &"standard", "campaign = Standard")
	assert_eq([ArtTraits.subname(&"marksman~mastery"), ArtTraits.subname(&"marksman~night"), ArtTraits.subname(&"marksman")],
			["Field Camo", "Night Ops", ""], "subnames (our own titles)")


func test_every_option_has_a_free_default_art() -> void:
	# Fairness rule v2: each (chassis, trait) option has a default art everyone owns.
	for f: String in DirAccess.get_files_at("res://data/cards/"):
		if not f.ends_with(".tres"):
			continue
		var c: CardData = load("res://data/cards/" + f) as CardData
		if not c.has_trait_choice():
			continue
		var opts: Array[Dictionary] = ArtTraits.options(c)
		assert_eq(opts.map(func(o: Dictionary) -> StringName: return o["trait"]), c.trait_choices() as Array, "%s: one row per option" % c.id)
		for o: Dictionary in opts:
			var art: StringName = o["default_art"]
			assert_eq(ArtTraits.trait_of(art, c), o["trait"], "%s · %s: its default art gives it" % [c.id, o["name"]])
			assert_true(art in (o["arts"] as Array), "%s · %s: listed" % [c.id, o["name"]])
	assert_eq(ArtTraits.default_art(_card("gunner"), &"specops"), &"gunner~operators", "public build: the placeholder option art")
	assert_eq(ArtTraits.default_art(_card("gunner"), &"heavy", &"gunner~dust"), &"gunner~dust", "an equipped art of that option wins")
	assert_eq(ArtTraits.default_art(_card("gunner"), &"specops", &"gunner~dust"), &"gunner~operators", "an equipped art of another option doesn't")
	assert_eq(ArtTraits.options(_card("halek_wren")).size(), 1, "printed: one row")


func test_licensed_manifest_family_column() -> void:
	var saved_dir: String = BannerArtDB.licensed_dir
	var saved_on: bool = BannerArtDB.licensed_enabled
	var dir: String = "user://kc_art_traits_test/"
	DirAccess.make_dir_recursive_absolute(dir)
	var f: FileAccess = FileAccess.open(dir + "manifest.csv", FileAccess.WRITE)
	f.store_string("file,kind,card,title,id,family,trait\n" +
			"a.webp,unit,marksman,Winter,kc_t_winter,operators,specops\n" +
			"b.webp,unit,marksman,Enforcer,kc_t_enforcer,mastery,heavy\n" +
			"c.webp,unit,marksman,Snow,kc_t_snow,honors,\n" +
			"d.webp,unit,marksman,Old,kc_t_old,,\n" +
			"e.webp,operator,kestrel_ar7,MCW,kc_t_mcw,mastery,\n")
	f.close()
	BannerArtDB.licensed_dir = dir
	BannerArtDB.licensed_enabled = true
	var mk: CardData = _card("marksman")
	assert_eq(ArtTraits.licensed_ids(&"marksman"), [&"kc_t_winter", &"kc_t_enforcer", &"kc_t_snow", &"kc_t_old"] as Array[StringName], "the chassis pool, operator rows left out")
	assert_eq([ArtTraits.trait_of(&"kc_t_winter", mk), ArtTraits.trait_of(&"kc_t_enforcer", mk), ArtTraits.trait_of(&"kc_t_snow", mk)],
			[&"specops", &"heavy", &""], "family column -> trait (Honors on a Marksman: plain)")
	assert_eq(ArtTraits.trait_of(&"kc_t_old", mk), &"specops", "an old manifest row without family = the home family")
	assert_eq(ArtTraits.default_art(mk, &"heavy"), &"kc_t_enforcer", "pitch default art of the Heavy option")
	assert_eq(ArtTraits.subname(&"kc_t_enforcer"), "Enforcer", "the licensed title is the subname")
	assert_eq(ArtTraits.default_art(_card("combat_medic"), &"specops"), &"combat_medic~operators", "an option without licensed art falls back to ours")
	BannerArtDB.licensed_enabled = false
	assert_eq(ArtTraits.licensed_ids(&"marksman"), [] as Array[StringName], "switched off: no licensed rows")
	assert_eq(ArtTraits.trait_of(&"kc_t_enforcer", mk), &"specops", "an unknown art falls back to the home family")
	BannerArtDB.licensed_dir = saved_dir
	BannerArtDB.licensed_enabled = saved_on
	DirAccess.remove_absolute(dir + "manifest.csv")
	ArtTraits.clear_cache()


# =============================================================================
# Run layer
# =============================================================================

func test_supply_drop_offers_carry_trait_and_art() -> void:
	var r: RunProgress = _run()
	_add(r, &"gunner", &"heavy")
	r.record_result(&"player")
	var drop: Dictionary = r.current_offer()
	assert_eq(drop["kind"], RewardOffers.KIND_SUPPLY_DROP, "Supply Drop")
	assert_eq([drop["traits"].size(), drop["arts"].size()], [drop["options"].size(), drop["options"].size()], "a trait and an art per card")
	assert_true(drop.get("retire", false) and not drop.get("reissue", false), "Retire; no Re-issue (head Z1)")
	if drop.get("on_trait", &"") == &"heavy":
		assert_eq(drop["traits"][0], &"heavy", "slot 1 in the main trait")
	for k: int in drop["options"].size():
		var c: CardData = r.resource(drop["options"][k]) as CardData
		assert_true(c.trait_choices().is_empty() or c.can_carry(drop["traits"][k]), "an option of that card")
		assert_eq(ArtTraits.trait_of(drop["arts"][k], c), drop["traits"][k] if c.has_trait_choice() else c.card_trait, "the art gives the trait")
	var t: StringName = drop["traits"][0]
	var art: StringName = drop["arts"][0]
	assert_eq(r.choose_offer(0), "", "take it")
	assert_eq([r.deck_traits.back(), r.deck_arts.back()], [t, art], "the copy comes in that trait and art")


func test_supply_drop_alternates_are_about_forty_percent() -> void:
	var r: RunProgress = _run()
	var alt: int = 0
	var total: int = 0
	for n: int in 300:
		var drop: Dictionary = {"options": RewardOffers.supply_drop(r.config, r._rng("t", n))}
		r._dress_drop(drop, &"", r._rng("art", n))
		for k: int in drop["options"].size():
			var c: CardData = r.resource(drop["options"][k]) as CardData
			if c.has_trait_choice():
				total += 1
				if drop["traits"][k] != c.card_trait:
					alt += 1
	var share: float = float(alt) / float(maxi(1, total))
	assert_true(share > 0.32 and share < 0.48, "alternate share %.2f (target 0.40)" % share)


func test_retire_keeps_the_other_copies() -> void:
	var r: RunProgress = _run()
	r.record_result(&"player")
	var list: Array[Dictionary] = r.retire_options()
	var idx: int = list.map(func(o: Dictionary) -> StringName: return o["id"]).find(&"breacher")
	var size0: int = r.deck.size()
	assert_eq(r.retire_card(idx), "", "retire a Breacher")
	var b: int = r.deck.find(&"breacher")
	assert_eq(r.copy_trait(b), &"vanguard", "the other Breacher is untouched")
	assert_eq([r.deck.size(), r.deck_traits.size(), r.deck_arts.size()], [size0 - 1, size0 - 1, size0 - 1], "one card fewer, lists parallel")


func test_same_trait_art_swaps_are_free() -> void:
	var r: RunProgress = _run()
	var g: int = _add(r, &"gunner", &"heavy")
	# kc-trait-ui (head): in a run each copy keeps the art it was found with.
	assert_true(r.set_copy_art(g, &"gunner~night").contains("found with"), "no art swaps in a run")
	assert_true(r.set_copy_art(g, r.art_of(g)) == "", "its own art is fine")
	r.random_copy_arts = false  # the kc-art-traits behaviour (tools)
	assert_eq(r.art_choices(g)["same"].has(&"gunner~night"), true, "same-trait looks are offered")
	assert_eq(r.art_choices(g)["other"], [&"gunner~operators"] as Array[StringName], "other traits greyed")
	assert_eq(r.set_copy_art(g, &"gunner~night"), "", "free swap")
	assert_eq([r.art_of(g), r.copy_trait(g)], [&"gunner~night", &"heavy"], "same trait")
	assert_true(r.set_copy_art(g, &"gunner~operators").contains("keeps the trait"), "never into another trait (head Z1)")
	assert_true(r.set_copy_art(g, &"marksman~night") != "", "not an art of this card")
	var rec: int = r.deck.find(&"marksman")
	assert_true(r.set_copy_art(rec, &"marksman~mastery") != "", "a starter copy can't change its trait through its art either")
	assert_eq(r.set_copy_art(rec, &"marksman~night"), "", "a same-trait look is fine")
	assert_eq([r.trait_choice(rec), r.copy_trait(rec)], [&"specops", &"specops"], "Spec Ops")


func test_codex_equip_dresses_new_copies() -> void:
	var r: RunProgress = _run()
	var before: Array[StringName] = r.deck_arts.duplicate()
	r.set_equipped_arts({"point_man": "point_man~horde"})
	assert_eq([r.equipped_arts, r.deck_arts], [{}, before], "kc-trait-ui (head): Codex EQUIP never reaches a run")
	r.random_copy_arts = false  # the kc-art-traits behaviour (tools)
	r.set_equipped_arts({"point_man": "point_man~horde", "gunner": "gunner~dust", "marksman": "not_an_art"})
	var pm: Array = r.deck_view().filter(func(row: Dictionary) -> bool: return row["id"] == &"point_man")
	assert_true(pm.all(func(row: Dictionary) -> bool: return row["trait"] == &"vanguard" and ArtTraits.trait_of(row["art"], _card("point_man")) == &"vanguard"),
			"head Z1: an equipped art of another trait never changes a copy's trait")
	assert_eq(r._equipped(_card("marksman")), &"", "an unknown art is ignored")
	var drop: Dictionary = {"options": [&"gunner", &"gunner"] as Array[StringName]}
	r._dress_drop(drop, &"heavy", r._rng("eq", 1))
	assert_eq(drop["arts"][0], &"gunner~dust", "a new Heavy Gunner comes in the equipped art")


func test_save_round_trip_and_v2_migration() -> void:
	var r: RunProgress = _run()
	_add(r, &"marksman", &"heavy")
	r.record_result(&"player")
	var d: Dictionary = JSON.parse_string(JSON.stringify(r.to_dict()))
	assert_eq(int(d["version"]), RunProgress.SAVE_VERSION, "current save version (6 since kc-no-training)")
	var back: Dictionary = RunProgress.from_dict(r.config, d)
	assert_eq(back["error"], "", "loads")
	var r2: RunProgress = back["run"]
	assert_eq([r2.deck_traits, r2.deck_arts], [r.deck_traits, r.deck_arts], "traits and arts")
	assert_eq(r2.current_offer()["traits"], r.current_offer()["traits"], "offer traits")
	assert_eq(JSON.stringify(r2.to_dict()), JSON.stringify(r.to_dict()), "identical after a round trip")
	var v2: Dictionary = d.duplicate(true)
	v2["version"] = 2
	v2.erase("deck_traits")
	v2.erase("deck_arts")
	for o: Dictionary in v2["pending_offers"]:
		o.erase("traits")
		o.erase("arts")
	var b2: Dictionary = RunProgress.from_dict(r.config, v2)
	assert_eq(b2["error"], "", "a version 2 save loads")
	var r3: RunProgress = b2["run"]
	var mk: int = r3.deck.rfind(&"marksman")
	assert_eq(r3.copy_trait(mk), &"specops", "v2 copies take their default trait")
	assert_eq(r3.deck_arts.size(), r3.deck.size(), "and an art each")
	assert_true(r3.current_offer().has("traits") and not r3.current_offer().get("reissue", false), "the pending Supply Drop is dressed (no Re-issue: head Z1)")
	var bad: Dictionary = d.duplicate(true)
	bad["deck_traits"][0] = "robots"
	assert_true(RunProgress.from_dict(r.config, bad)["error"] != "", "unknown trait")
	var bad2: Dictionary = d.duplicate(true)
	bad2["deck_arts"] = ["x"]
	assert_true(RunProgress.from_dict(r.config, bad2)["error"] != "", "arts must match the deck")


func test_missing_art_shows_the_default_and_keeps_the_trait() -> void:
	var r: RunProgress = _run()
	var m: int = _add(r, &"marksman", &"heavy")
	r.deck_arts[m] = &"kc_mw3_kvd_enforcer_mastery_gilded"  # a licensed art, folder absent in tests
	assert_eq(r.art_of(m), &"marksman~mastery", "shows the option's default art")
	assert_eq(r.copy_trait(m), &"heavy", "the trait never changes with it")
	var s: SideSetup = r.player_setup()
	assert_eq([s.deck_traits[m], s.deck_arts[m]], [&"heavy", &"marksman~mastery"], "the match gets the copy's trait and art")
	var row: Dictionary = r.deck_view()[m]
	assert_eq([row["trait"], row["trait_choice"], row["subname"], row["trait_options"]],
			[&"heavy", &"heavy", "Field Camo", [&"specops", &"heavy"] as Array[StringName]], "deck view row")
	assert_eq(r.trait_options_of(&"marksman").size(), 2, "trait options hook")


func test_run_state_art_swap() -> void:
	var rs: Node = tree.root.get_node("RunState")
	var saved_path: String = rs.save_path
	var saved_cfg: RunConfig = rs.config
	rs.save_path = "user://test_art_traits_save.json"
	rs.config = _config()
	rs.start_run(SEED)
	rs.begin_run()
	var g: int = _add(rs.run, &"gunner", &"heavy")
	assert_true(rs.set_copy_art(g, &"gunner~flip") != "", "RunState.set_copy_art: no swaps in a run (head)")
	rs.record_result(&"player")
	assert_false(rs.has_method(&"reissue_card"), "RunState.reissue_card is removed")
	assert_eq(rs.run.copy_trait(g), &"heavy", "the trait stays")
	rs.abandon_run()
	rs.save_path = saved_path
	rs.config = saved_cfg


func test_pitch_deck_swaps_keep_traits_parallel() -> void:
	var cfg: RunConfig = load("res://data/run_config.tres") as RunConfig
	var s: SideSetup = SideSetup.new()
	s.deck = cfg.starter_deck.duplicate()
	for c: CardData in s.deck:
		s.deck_traits.append(&"undead" if c.can_carry(&"undead") else SynergyRules.TRAIT_DEFAULT)
	var before: Array[StringName] = s.deck_traits.duplicate()
	PitchDecks.forced = true
	PitchDecks.apply_setup(s)
	PitchDecks.forced = false
	assert_eq(s.deck_traits.size(), s.deck.size(), "traits stay parallel")
	for i: int in s.deck.size():
		var swapped: bool = s.deck[i] != cfg.starter_deck[i]
		assert_eq(s.deck_traits[i], SynergyRules.TRAIT_DEFAULT if swapped else before[i], "a swapped-in card takes its default, the rest keep theirs")


func test_anchor_runs_one_gunner_fewer() -> void:
	# Head F1: the campaign shortfall from LMG Pierce is fixed on the Anchor squad: one Gunner became a
	# Hold the Line (art_traits_sim campaign, slots 2 and 4, kc-art-traits-impl §11.3).
	var sq: SquadData = load("res://data/squads/squad_anchor.tres") as SquadData
	var ids: Array = sq.deck.map(func(c: CardData) -> StringName: return c.id)
	assert_eq([ids.count(&"gunner"), ids.count(&"hold_the_line"), ids.size()], [2, 3, 18], "2 Gunners, 3 Hold the Line, 18 cards")

# test_rules_fields.gd
# Purpose: KillingCard Field cards, full Model B (field-cards.md §2 + head's decisions F1-F3,
#   board task kc-field-impl): Field = CardType.EQUIPMENT; auras read from Fields (column
#   only, either side), the "your frontline unit" target and how it follows the line, the
#   Protector slide, Pick / Flank skipping a Bulwarked front, the HEAL kind (Aid Station),
#   Mortar Pit chip vs Cover, Listening Post intel, one visible Field per side per column
#   (replace across rounds, refuse twice in one Deploy, traps exempt), Overrun (after
#   END_OF_ROUND effects, traps exempt), Sabotage, the field_view() UI hook, validation,
#   the shipped data (8 Fields, exact numbers, reward pool) and the AI (view + planner).
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const E: int = 1
const W := DataEnums.WeaponClass


func _match(p_deck: Array = [], e_deck: Array = []) -> MatchState:
	var m: MatchState = F.new_match(F.setup(p_deck), F.setup(e_deck))
	m.sides[P].supply = 7
	m.sides[E].supply = 7
	return m


func _reasons(m: MatchState) -> Array:
	return F.events_of(m, RulesEvent.EQUIPMENT_DESTROYED).map(func(e: Dictionary) -> StringName: return e["reason"])


# --- Type and naming ------------------------------------------------------------------------

func test_equipment_is_shown_as_field() -> void:
	assert_eq(DataEnums.CARD_TYPE_FIELD, DataEnums.CardType.EQUIPMENT, "Field is an alias of EQUIPMENT (no int changes)")
	assert_eq(DataEnums.type_label(DataEnums.CardType.EQUIPMENT), "Field", "player-facing name")
	assert_eq(DataEnums.type_label(DataEnums.CardType.UNIT), "Unit", "units")
	var b: CardData = F.bulwark()
	assert_true(b.is_field() and b.is_visible_field(), "Bulwark is a visible Field")
	assert_true(F.tripwire().is_field() and not F.tripwire().is_visible_field(), "Tripwire is a hidden Field (trap)")
	assert_eq(b.type_label(), "Field", "CardData.type_label")


# --- Auras from Fields: frontline target ---------------------------------------------------------

func test_bulwark_gives_cover_only_to_your_frontline_unit_in_its_column() -> void:
	var m: MatchState = _match()
	F.place_field(m, P, F.bulwark(), F.MID)
	var front: RulesUnit = F.place(m, P, F.unit("front", 1, 5), F.MID)
	var back: RulesUnit = F.place(m, P, F.unit("back", 1, 5), F.MID)
	var other: RulesUnit = F.place(m, P, F.unit("other", 1, 5), F.LEFT)
	var foe: RulesUnit = F.place(m, E, F.unit("foe", 1, 5), F.MID)
	assert_eq([m.cover_of(front), m.cover_of(back), m.cover_of(other)], [1, 0, 0], "front of its column only")
	assert_eq(m.cover_of(foe), 0, "the enemy front doesn't get my Bulwark")


func test_frontline_aura_follows_the_line_when_the_front_falls() -> void:
	var m: MatchState = _match()
	F.place_field(m, P, F.war_standard(), F.MID)
	var front: RulesUnit = F.place(m, P, F.unit("front", 2, 1), F.MID)
	var second: RulesUnit = F.place(m, P, F.unit("second", 2, 4), F.MID)
	assert_eq([m.firepower_of(front), m.firepower_of(second)], [3, 2], "+1 FP on the front")
	front.armor = 0
	m.process_eliminations()
	assert_eq(m.firepower_of(second), 3, "the new row 1 picks the aura up")


func test_war_standard_buff_passes_to_new_front_between_firefight_steps() -> void:
	# First Shot step kills my front; in the Main step the new front shoots with +1.
	var m: MatchState = _match()
	F.place_field(m, P, F.war_standard(), F.MID)
	F.place(m, P, F.unit("front", 2, 1), F.MID)
	F.place(m, P, F.unit("second", 2, 9), F.MID)
	F.place(m, E, F.unit("sniper", 1, 9, W.NONE, {"first_shot": true}), F.MID)
	var target: RulesUnit = m.sides[E].line(F.MID)[0]
	m.firefight()
	assert_eq(target.armor, 9 - 3, "second (now front) hit for 2 + 1 War Standard")


func test_protector_slides_in_front_and_takes_the_bulwark_cover_2() -> void:
	var protector: CardData = F.shieldman()
	var m: MatchState = _match([protector])
	F.place_field(m, P, F.bulwark(), F.MID)
	var old_front: RulesUnit = F.place(m, P, F.unit("old_front", 1, 5), F.MID)
	assert_eq(m.cover_of(old_front), 1, "front before the Protector arrives")
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "shieldman"), F.MID))["ok"], "Protector")
	m.reveal()
	var p_unit: RulesUnit = m.sides[P].line(F.MID)[0]
	assert_eq(p_unit.source_id, &"shieldman", "slid to row 1")
	assert_eq(m.cover_of(p_unit), 2, "Cover 1 + Bulwark = Cover 2 wall")
	assert_eq(m.cover_of(old_front), 0, "the old front lost the aura")


func test_pick_and_flank_skip_a_bulwarked_front() -> void:
	var m: MatchState = _match()
	F.place_field(m, P, F.bulwark(), F.MID)
	var front: RulesUnit = F.place(m, P, F.unit("front", 0, 6), F.MID)
	var mid: RulesUnit = F.place(m, P, F.unit("mid", 0, 2), F.MID)
	var back: RulesUnit = F.place(m, P, F.unit("back", 0, 3), F.MID)
	F.place(m, E, F.marksman(), F.MID)
	F.place(m, E, F.flanker(), F.MID)
	m.firefight()
	assert_eq(front.armor, 6, "nobody shot the Bulwarked front")
	assert_false(mid.is_alive(), "Pick took the lowest Armor behind it (no Cover there)")
	assert_eq(back.armor, 1, "Flank hit the back-most for its full 2")


func test_mortar_pit_is_cancelled_by_protector_cover_and_by_bulwark() -> void:
	var m: MatchState = _match()
	F.place_field(m, P, F.mortar_pit(), F.LEFT)
	F.place_field(m, P, F.mortar_pit(), F.MID)
	F.place_field(m, E, F.bulwark(), F.MID)
	var prot: RulesUnit = F.place(m, E, F.shieldman(), F.LEFT)
	var bulwarked: RulesUnit = F.place(m, E, F.unit("plain", 0, 5), F.MID)
	F.place(m, P, F.unit("holder", 0, 9), F.LEFT)  # keeps LEFT contested (no Overrun)
	F.place(m, P, F.unit("holder2", 0, 9), F.MID)
	m.score()
	assert_eq(prot.armor, 5, "Protector Cover 1 eats the 1 damage")
	assert_eq(bulwarked.armor, 5, "Bulwark Cover 1 eats it too")


func test_mortar_pit_chips_the_enemy_front_at_end_of_round_with_credit() -> void:
	var m: MatchState = _match()
	F.place_field(m, P, F.mortar_pit(), F.MID)
	var front: RulesUnit = F.place(m, E, F.unit("front", 0, 1), F.MID)
	var back: RulesUnit = F.place(m, E, F.unit("back", 0, 3), F.MID)
	m.score()
	assert_false(front.is_on_board(), "1 damage killed the 1-Armor front")
	assert_eq(back.armor, 3, "only the front is hit")
	assert_eq(m.sides[P].eliminations, 1, "the Field's owner gets the elimination")
	var rec: Dictionary = F.events_of(m, RulesEvent.UNIT_ELIMINATED)[0]
	assert_eq(rec["source_kind"], MatchState.SRC_EQUIPMENT, "source kind = equipment (Field)")


func test_sniper_perch_boosts_only_snipers_and_pick_damage() -> void:
	var m: MatchState = _match()
	F.place_field(m, P, F.sniper_perch(), F.MID)
	var sniper: RulesUnit = F.place(m, P, F.marksman(), F.MID)
	var rifle: RulesUnit = F.place(m, P, F.unit("lmg", 2, 2, W.LMG), F.MID)
	var away: RulesUnit = F.place(m, P, F.marksman(), F.LEFT)
	assert_eq(m.firepower_of(sniper), 3, "Marksman 2 -> 3 (flat map)")
	assert_eq(m.firepower_of(rifle), 2, "not a Sniper")
	assert_eq(m.firepower_of(away), 2, "other column")
	F.place(m, E, F.unit("wall", 0, 9), F.MID)
	var soft: RulesUnit = F.place(m, E, F.unit("soft", 0, 3), F.MID)
	m.firefight()
	assert_false(soft.is_alive(), "Pick with 3 FP kills a 3-Armor back unit")


func test_enemy_aura_fields_only_affect_their_owner() -> void:
	var m: MatchState = _match()
	F.place_field(m, E, F.war_standard(), F.MID)
	var mine: RulesUnit = F.place(m, P, F.unit("mine", 2, 3), F.MID)
	var theirs: RulesUnit = F.place(m, E, F.unit("theirs", 2, 3), F.MID)
	assert_eq([m.firepower_of(mine), m.firepower_of(theirs)], [2, 3], "War Standard buffs its owner's front only")
	assert_eq(m.field_passive_total(theirs, DataEnums.EffectKind.MODIFY_FIREPOWER), 1, "field part of the passives")


func test_field_never_counts_for_control_or_gets_shot() -> void:
	var m: MatchState = _match()
	F.place_field(m, P, F.bulwark(), F.MID)
	assert_eq(m.control_of(F.MID), MatchState.CONTROL_EMPTY, "a Field alone holds nothing")
	F.place(m, E, F.unit("shooter", 5, 5), F.MID)
	m.firefight()
	assert_eq(F.events_of(m, RulesEvent.SHOT_FIRED).size(), 0, "no firefight against a Field")
	assert_eq(m.sides[P].equipment[F.MID].size(), 1, "still standing")


# --- HEAL (Aid Station) -----------------------------------------------------------------

func test_aid_station_heals_most_damaged_unit_by_one_at_end_of_round() -> void:
	var m: MatchState = _match()
	F.place_field(m, P, F.aid_station(), F.MID)
	var a: RulesUnit = F.place(m, P, F.unit("a", 0, 5), F.MID)
	var b: RulesUnit = F.place(m, P, F.unit("b", 0, 5), F.MID)
	var c: RulesUnit = F.place(m, P, F.unit("c", 0, 5), F.MID)
	a.armor = 4
	b.armor = 2
	c.armor = 2
	m.score()
	assert_eq([a.armor, b.armor, c.armor], [4, 3, 2], "most damaged, ties go front-most, heal 1")
	var healed: Dictionary = F.events_of(m, RulesEvent.UNIT_HEALED)[0]
	assert_eq([healed["target_uid"], healed["amount"], healed["source_id"]], [b.uid, 1, &"aid_station"], "UNIT_HEALED event")


func test_aid_station_never_heals_above_max_and_wastes_when_nobody_hurt() -> void:
	var m: MatchState = _match()
	F.place_field(m, P, F.aid_station(), F.MID)
	var a: RulesUnit = F.place(m, P, F.unit("a", 0, 5), F.MID)
	m.score()
	assert_eq(a.armor, 5, "full Armor stays full")
	var wasted: Array = F.events_of(m, RulesEvent.EFFECT_WASTED).filter(func(e: Dictionary) -> bool: return e["source_id"] == &"aid_station")
	assert_eq(wasted.size(), 1, "logged as wasted")


func test_aid_station_counters_pick_across_rounds() -> void:
	# Pick targets the lowest remaining Armor; the heal raises it back between rounds.
	var m: MatchState = _match()
	F.place_field(m, P, F.aid_station(), F.MID)
	F.place(m, P, F.unit("wall", 0, 9), F.MID)
	var soft: RulesUnit = F.place(m, P, F.unit("soft", 0, 4), F.MID)
	F.place(m, E, F.unit("picker", 2, 9, W.SNIPER, {"pick": true}), F.MID)
	m.firefight()
	assert_eq(soft.armor, 2, "picked for 2")
	m.score()
	assert_eq(soft.armor, 3, "healed 1 at end of round")


func test_heal_effect_validation_needs_positive_amount() -> void:
	var v: DataValidator = DataValidator.new()
	F.eff(DataEnums.Trigger.END_OF_ROUND, DataEnums.EffectKind.HEAL, DataEnums.Target.MOST_DAMAGED_FRIENDLY,
			DataEnums.ZoneScope.THIS_ZONE, 0).validate(v, "e")
	assert_true(v.error_count() > 0, "HEAL 0 is rejected")


# --- Listening Post ------------------------------------------------------------------------

func test_listening_post_reveals_next_rounds_red_dots_each_round() -> void:
	var m: MatchState = _match()
	F.place_field(m, P, F.listening_post(), F.RIGHT)
	F.place(m, P, F.unit("holder", 0, 5), F.RIGHT)
	m.score()
	assert_true(F.RIGHT in m.sides[P].intel_reveals.get(m.round_number + 1, []), "next round's red dots in its column")
	m.begin_round()
	m.reveal()
	m.firefight()
	m.score()
	assert_true(F.RIGHT in m.sides[P].intel_reveals.get(m.round_number + 1, []), "and again every round")


# --- One visible Field per side per column ---------------------------------------------------

func test_new_visible_field_replaces_the_standing_one() -> void:
	var m: MatchState = _match([F.war_standard()])
	var old: RulesCard = F.place_field(m, P, F.bulwark(), F.MID)
	F.place(m, P, F.unit("u", 2, 5), F.MID)
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "war_standard"), F.MID))["ok"], "allowed")
	m.reveal()
	var ids: Array = m.sides[P].equipment[F.MID].map(func(e: Dictionary) -> StringName: return e["card"].card.id)
	assert_eq(ids, [&"war_standard"], "one Field: the new one")
	assert_true(old in m.sides[P].discard, "the old one went to the discard")
	assert_eq(_reasons(m), [RulesEvent.FIELD_GONE_REPLACED], "EQUIPMENT_DESTROYED reason replaced")


func test_traps_do_not_count_toward_the_field_limit() -> void:
	var m: MatchState = _match([F.tripwire(), F.bulwark()])
	F.place_field(m, P, F.tripwire(), F.MID)
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "tripwire_charge"), F.MID))["ok"], "second trap ok")
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "bulwark"), F.MID))["ok"], "visible Field next to traps")
	m.reveal()
	assert_eq(m.sides[P].equipment[F.MID].size(), 3, "two traps + Bulwark")
	assert_eq(_reasons(m), [], "nothing replaced")


func test_second_visible_field_in_one_column_in_one_deploy_is_refused() -> void:
	var m: MatchState = _match([F.bulwark(), F.war_standard()])
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "bulwark"), F.MID))["ok"], "first")
	var r: Dictionary = m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "war_standard"), F.MID))
	assert_eq(r["code"], &"field_already_planned", "second refused")
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "war_standard"), F.LEFT))["ok"], "other column fine")
	m.undo_last(P)
	m.undo_last(P)
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "war_standard"), F.MID))["ok"], "free again after undo")


func test_each_side_has_its_own_field_slot() -> void:
	var m: MatchState = _match([F.bulwark()], [F.war_standard()])
	m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "bulwark"), F.MID))
	m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "war_standard"), F.MID))
	m.reveal()
	assert_eq([m.sides[P].equipment[F.MID].size(), m.sides[E].equipment[F.MID].size()], [1, 1], "one each")


# --- Overrun ---------------------------------------------------------------------------------

func test_overrun_tears_down_visible_fields_where_the_enemy_controls() -> void:
	var m: MatchState = _match()
	var lost: RulesCard = F.place_field(m, P, F.bulwark(), F.LEFT)
	F.place_field(m, P, F.war_standard(), F.MID)      # contested: stays
	F.place_field(m, P, F.sniper_perch(), F.RIGHT)    # empty: stays
	F.place_field(m, P, F.tripwire(), F.LEFT)         # trap: exempt
	F.place(m, E, F.unit("e1", 0, 5), F.LEFT)
	F.place(m, E, F.unit("e2", 0, 5), F.MID)
	F.place(m, P, F.unit("p2", 0, 5), F.MID)
	m.score()
	var left: Array = m.sides[P].equipment[F.LEFT].map(func(e: Dictionary) -> StringName: return e["card"].card.id)
	assert_eq(left, [&"tripwire_charge"], "Bulwark overrun, the hidden trap stays")
	assert_true(lost in m.sides[P].discard, "to the discard")
	assert_eq([m.sides[P].equipment[F.MID].size(), m.sides[P].equipment[F.RIGHT].size()], [1, 1], "contested / empty keep theirs")
	var ev: Dictionary = F.events_of(m, RulesEvent.EQUIPMENT_DESTROYED)[0]
	assert_eq([ev["reason"], ev["card_id"], ev["zone"]], [RulesEvent.FIELD_GONE_OVERRUN, &"bulwark", &"left"], "overrun event")


func test_overrun_comes_after_end_of_round_effects_and_reads_control_after_them() -> void:
	# Mortar Pit fires first; it kills the only enemy unit, so the column is no longer the
	# enemy's and the Pit stays. In the other column the Pit fires and then falls.
	var m: MatchState = _match()
	F.place_field(m, P, F.mortar_pit(), F.LEFT)
	F.place_field(m, P, F.mortar_pit(), F.MID)
	var weak: RulesUnit = F.place(m, E, F.unit("weak", 0, 1), F.LEFT)
	var tough: RulesUnit = F.place(m, E, F.unit("tough", 0, 5), F.MID)
	m.score()
	assert_false(weak.is_on_board(), "LEFT Pit killed the last enemy")
	assert_eq(m.sides[P].equipment[F.LEFT].size(), 1, "so it is not overrun")
	assert_eq(tough.armor, 4, "MID Pit still fired this round")
	assert_eq(m.sides[P].equipment[F.MID].size(), 0, "then fell to Overrun")


func test_comms_relay_is_lost_with_the_column() -> void:
	var m: MatchState = _match()
	F.place_field(m, P, F.comms_relay(), F.MID)
	F.place(m, E, F.unit("e", 0, 5), F.MID)
	m.score()
	assert_eq(m.sides[P].equipment[F.MID].size(), 0, "enemy holds MID: Relay torn down")


func test_overrun_applies_to_both_sides() -> void:
	var m: MatchState = _match()
	F.place_field(m, E, F.bulwark(), F.MID)
	F.place(m, P, F.unit("p", 0, 5), F.MID)
	m.score()
	assert_eq(m.sides[E].equipment[F.MID].size(), 0, "enemy Field overrun by my control")


# --- Removal by effects, UI hook ----------------------------------------------------------

func test_sabotage_destroys_a_field_with_reason_destroyed() -> void:
	var m: MatchState = _match([F.sabotage()])
	F.place_field(m, E, F.bulwark(), F.MID)
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "sabotage"), F.MID))["ok"], "Sabotage")
	m.reveal()
	assert_eq(m.sides[E].equipment[F.MID].size(), 0, "gone")
	assert_eq(_reasons(m), [RulesEvent.FIELD_GONE_DESTROYED], "reason destroyed")


func test_field_view_hook_shows_what_the_viewer_may_see() -> void:
	var m: MatchState = _match()
	F.place_field(m, P, F.tripwire(), F.LEFT)
	F.place_field(m, P, F.bulwark(), F.LEFT, 1)
	F.place_field(m, E, F.tripwire(), F.MID)
	F.place_field(m, E, F.war_standard(), F.MID)
	F.place(m, P, F.unit("p", 0, 5), F.MID)  # I control MID: their War Standard is at risk
	var view: Array[Dictionary] = m.field_view(P)
	assert_eq(view.size(), 3, "one row per column")
	assert_eq(view[0]["zone"], &"left", "zone name")
	assert_eq((view[0]["player"] as Array).map(func(e: Dictionary) -> bool: return e["hidden"]), [true, false], "my trap listed (dashed)")
	assert_eq(view[0]["player"][1]["placed_round"], 1, "placement round")
	var theirs: Array = view[1]["enemy"]
	assert_eq(theirs.size(), 1, "their trap is not shown to me")
	assert_eq([theirs[0]["card_id"], theirs[0]["name"], theirs[0]["overrun_risk"]], [&"war_standard", "War_standard".capitalize(), true], "entry")
	var enemy_view: Array[Dictionary] = m.field_view(E)
	assert_eq(enemy_view[1]["enemy"].size(), 2, "the enemy sees its own trap")
	assert_eq(enemy_view[0]["player"].size(), 1, "and not my trap")


func test_clone_keeps_field_auras() -> void:
	var m: MatchState = _match()
	F.place_field(m, P, F.war_standard(), F.MID)
	F.place(m, P, F.unit("u", 2, 5), F.MID)
	var copy: MatchState = MatchClone.copy(m)
	assert_eq(copy.firepower_of(copy.sides[P].line(F.MID)[0]), 3, "the clone reads Field auras too")


# --- Validation ---------------------------------------------------------------------------

func test_field_passive_must_work_in_its_own_column_and_tactics_have_no_passives() -> void:
	var bad: CardData = F.equipment("bad_field", 2, [F.eff(DataEnums.Trigger.PASSIVE, DataEnums.EffectKind.GRANT_COVER,
			DataEnums.Target.FRIENDLY_POINT_MAN, DataEnums.ZoneScope.CHOSEN_ZONE, 1)])
	var v: DataValidator = DataValidator.new()
	bad.validate(v)
	assert_true(v.error_count() > 0, "Field aura with CHOSEN_ZONE rejected")
	var t: CardData = F.tactic("bad_tactic", 1, [F.eff(DataEnums.Trigger.PASSIVE, DataEnums.EffectKind.GRANT_COVER,
			DataEnums.Target.ALL_FRIENDLIES, DataEnums.ZoneScope.CHOSEN_ZONE, 1)])
	var v2: DataValidator = DataValidator.new()
	t.validate(v2)
	assert_true(v2.error_count() > 0, "Tactic PASSIVE rejected")
	var v3: DataValidator = DataValidator.new()
	F.bulwark().validate(v3)
	assert_eq(v3.error_count(), 0, "Bulwark is valid")


# --- Shipped data ---------------------------------------------------------------------------

func test_shipped_field_cards_have_the_designed_numbers() -> void:
	# field-cards.md §4: [cost, trigger, kind, target, amount, extra checks]
	var TR := DataEnums.Trigger
	var K := DataEnums.EffectKind
	var T := DataEnums.Target
	var spec: Dictionary = {
		"tripwire_charge": [2, TR.ON_ENEMY_ARRIVE, K.DAMAGE, T.ARRIVING_ENEMY, 3],
		"comms_relay": [2, TR.END_OF_ROUND, K.STREAK_BONUS, T.OWNER, 1],
		"listening_post": [1, TR.END_OF_ROUND, K.REVEAL_RED_DOTS, T.OWNER, 0],
		"mortar_pit": [3, TR.END_OF_ROUND, K.DAMAGE, T.ENEMY_POINT_MAN, 1],
		"bulwark": [3, TR.PASSIVE, K.GRANT_COVER, T.FRIENDLY_POINT_MAN, 1],
		"war_standard": [3, TR.PASSIVE, K.MODIFY_FIREPOWER, T.FRIENDLY_POINT_MAN, 1],
		"sniper_perch": [2, TR.PASSIVE, K.MODIFY_FIREPOWER, T.ALL_FRIENDLIES, 1],
		"aid_station": [2, TR.END_OF_ROUND, K.HEAL, T.MOST_DAMAGED_FRIENDLY, 1],
	}
	for id: String in spec:
		var c: CardData = load("res://data/cards/%s.tres" % id) as CardData
		assert_not_null(c, id)
		var s: Array = spec[id]
		var e: EffectData = c.effects[0]
		assert_eq([c.card_type, c.cost, c.effects.size(), e.trigger, e.kind, e.target, e.amount, e.zone_scope],
				[DataEnums.CARD_TYPE_FIELD, s[0], 1, s[1], s[2], s[3], s[4], DataEnums.ZoneScope.THIS_ZONE], id)
		var v: DataValidator = DataValidator.new()
		c.validate(v)
		assert_eq(v.error_count(), 0, id + " validates")
		assert_true(c.text.contains("column"), id + " text says column")
	var lp: EffectData = (load("res://data/cards/listening_post.tres") as CardData).effects[0]
	assert_eq(lp.delay_rounds, 1, "Listening Post looks at next round")
	var perch: EffectData = (load("res://data/cards/sniper_perch.tres") as CardData).effects[0]
	assert_eq(perch.target_class, W.SNIPER, "Sniper Perch: Snipers only")
	var trip: CardData = load("res://data/cards/tripwire_charge.tres")
	assert_true(trip.hidden and trip.consumed_on_trigger, "Tripwire is a hidden one-shot trap")
	var relay: EffectData = (load("res://data/cards/comms_relay.tres") as CardData).effects[0]
	assert_eq(relay.condition, DataEnums.Condition.YOU_CONTROL_ZONE, "Relay needs control")


func test_new_fields_enter_through_the_reward_pool_only() -> void:
	var run: RunConfig = load("res://data/run_config.tres") as RunConfig
	var pool: Array = run.reward_pool.map(func(c: CardData) -> StringName: return c.id)
	var starter: Array = run.starter_deck.map(func(c: CardData) -> StringName: return c.id)
	for id: StringName in [&"listening_post", &"mortar_pit", &"bulwark", &"war_standard", &"sniper_perch", &"aid_station"]:
		assert_eq(pool.count(id), 1, "%s once in the reward pool" % id)
		assert_false(id in starter, "%s not in the starter deck" % id)
	# kc-syn §5.1: the plain Recruit starter has no Field; the first Field comes as a reward.
	assert_true(&"tripwire_charge" in pool, "Tripwire is in the reward pool")
	for sq: String in ["squad_rusher", "squad_anchor", "squad_black_meridian"]:
		var squad: SquadData = load("res://data/squads/%s.tres" % sq) as SquadData
		for c: CardData in squad.deck:
			assert_false(c.id in [&"listening_post", &"mortar_pit", &"bulwark", &"war_standard", &"sniper_perch", &"aid_station"],
					"%s: enemy decks unchanged" % sq)


# --- AI -------------------------------------------------------------------------------------

func test_ai_view_lists_fields_and_keeps_field_auras_out_of_unit_records() -> void:
	var m: MatchState = _match()
	F.place_field(m, E, F.war_standard(), F.MID)
	F.place_field(m, E, F.tripwire(), F.LEFT)
	F.place_field(m, P, F.bulwark(), F.MID)
	F.place_field(m, P, F.tripwire(), F.RIGHT)
	var mine: RulesUnit = F.place(m, E, F.unit("mine", 2, 5), F.MID)
	F.place(m, P, F.unit("theirs", 2, 5), F.MID)
	assert_eq(m.firepower_of(mine), 3, "engine applies the aura")
	var v: AiView = AiView.capture(m, E)
	assert_eq(v.lines[AiView.ME][F.MID][0]["fp"], 2, "record without the Field aura (planner re-applies it by position)")
	assert_eq(v.lines[AiView.FOE][F.MID][0]["cover"], 0, "foe record without Bulwark cover")
	assert_eq((v.my_fields[F.MID] as Array).size(), 1, "my Fields")
	assert_eq(v.my_visible_field(F.MID).id, &"war_standard", "my visible Field")
	assert_eq(v.my_visible_field(F.LEFT), null, "a trap is not the visible Field")
	assert_eq((v.foe_fields[F.MID] as Array).size(), 1, "their visible Field")
	assert_eq((v.foe_fields[F.RIGHT] as Array).size(), 0, "their trap stays secret")


func test_ai_plays_an_aura_field_where_its_units_fight() -> void:
	var m: MatchState = _match([], [F.war_standard()])
	m.sides[E].supply = 3
	F.place(m, E, F.unit("mine", 2, 4), F.MID)
	F.place(m, P, F.unit("theirs", 2, 4), F.MID)
	var plan: Dictionary = AiPlanner.new().plan(AiView.capture(m, E))
	var played: Array = (plan["intents"] as Array).filter(func(i: Dictionary) -> bool: return i.get("type") == RulesIntent.PLAY_CARD)
	assert_eq(played.size(), 1, "plays the War Standard")
	assert_eq(int(played[0]["zone"]), F.MID, "in the contested column with its unit")


func test_ai_does_not_replace_a_field_with_a_copy_or_stack_two() -> void:
	var m: MatchState = _match([], [F.bulwark(), F.war_standard()])
	m.sides[E].supply = 7
	F.place_field(m, E, F.bulwark(), F.LEFT)
	F.place_field(m, E, F.bulwark(), F.MID)
	F.place_field(m, E, F.bulwark(), F.RIGHT)
	for z: int in 3:
		F.place(m, E, F.unit("u%d" % z, 2, 4), z)
		F.place(m, P, F.unit("p%d" % z, 2, 4), z)
	var plan: Dictionary = AiPlanner.new().plan(AiView.capture(m, E))
	var cards: Array = (plan["intents"] as Array).filter(func(i: Dictionary) -> bool: return i.get("type") == RulesIntent.PLAY_CARD)
	assert_true(cards.size() <= 1, "at most the War Standard (%d card plays)" % cards.size())
	for intent: Dictionary in cards:
		var rc: RulesCard = m.sides[E].find_in_hand(int(intent["card_uid"]))
		assert_true(rc.card.id != &"bulwark", "never replaces a Bulwark with a Bulwark")
	# Whatever it chose must be legal (one visible Field per column per Deploy).
	for intent: Dictionary in plan["intents"]:
		assert_true(m.submit(E, intent)["ok"], "plan is legal: %s" % [intent])


func test_ai_never_plans_two_visible_fields_in_one_column() -> void:
	var m: MatchState = _match([], [F.bulwark(), F.war_standard(), F.aid_station()])
	m.sides[E].supply = 7
	F.place(m, E, F.unit("u", 2, 4), F.MID)
	F.place(m, P, F.unit("p", 2, 4), F.MID)
	var plan: Dictionary = AiPlanner.new().plan(AiView.capture(m, E))
	var zones: Array = []
	for intent: Dictionary in plan["intents"]:
		if intent.get("type") == RulesIntent.PLAY_CARD:
			assert_false(int(intent["zone"]) in zones, "one Field per column")
			zones.append(int(intent["zone"]))
		assert_true(m.submit(E, intent)["ok"], "legal: %s" % [intent])
	assert_true(zones.size() >= 1, "it plays at least one Field (%s)" % [zones])


func test_ai_estimate_applies_frontline_aura_to_the_new_front() -> void:
	# A Bulwark in front of a 1-Armor unit: the foe's 1 FP shot does nothing, so the AI
	# expects no loss in MID; without the Field it expects to lose the unit.
	var with_field: MatchState = _match()
	F.place_field(with_field, E, F.bulwark(), F.MID)
	F.place(with_field, E, F.unit("mine", 0, 1), F.MID)
	F.place(with_field, P, F.unit("theirs", 1, 9), F.MID)
	var without: MatchState = _match()
	F.place(without, E, F.unit("mine", 0, 1), F.MID)
	F.place(without, P, F.unit("theirs", 1, 9), F.MID)
	var a: AiPlanner = AiPlanner.new()
	var s_with: float = a.plan(AiView.capture(with_field, E))["score"]
	var s_without: float = a.plan(AiView.capture(without, E))["score"]
	assert_true(s_with > s_without, "Bulwark cover is in the estimate (%.2f > %.2f)" % [s_with, s_without])

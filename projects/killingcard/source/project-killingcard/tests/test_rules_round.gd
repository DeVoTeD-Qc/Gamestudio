# test_rules_round.gd
# Purpose: p04 round loop: Briefing (Supply, draws, hand cap, reshuffle, mulligan),
#   Deploy (intents, Supply, zone capacity, Operator placement / Rotation, red dots,
#   immediate effects, undo), Reveal (initiative, arrival order, Shieldman, Callout,
#   tactics / equipment / items in play order), Score (streak baseline, END_OF_ROUND),
#   hooks and determinism.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const E: int = 1


func _deck(n: int, prefix: String = "c") -> Array:
	var out: Array = []
	for i: int in n:
		out.append(F.unit("%s%d" % [prefix, i], 1, 1))
	return out


# --- Briefing ---------------------------------------------------------------------------

func test_round_one_briefing_draws_five_and_gives_two_supply() -> void:
	var m: MatchState = F.new_match(F.setup(_deck(20)), F.setup(_deck(20)))
	assert_eq(m.round_number, 1, "round 1")
	assert_eq(m.phase, MatchState.Phase.DEPLOY, "waiting for Deploy")
	assert_eq(m.sides[P].hand.size(), 5, "opening hand 4 + 1")
	assert_eq(m.sides[P].deck.size(), 15, "deck shrank")
	assert_eq(m.sides[P].supply, 2, "Round 1 gives 2 Supply")


func test_supply_curve_n_plus_one_capped_and_unspent_lost() -> void:
	var m: MatchState = F.new_match(F.setup(_deck(20)))
	var seen: Array[int] = [m.sides[P].supply]
	for r: int in 7:
		m.resolve_round()
		m.begin_round()
		seen.append(m.sides[P].supply)
	assert_eq(seen, [2, 3, 4, 5, 6, 7, 7, 7] as Array[int], "N+1, cap 7, never carried over")


func test_draws_two_per_round_and_burns_over_hand_cap() -> void:
	# core-rules §9: a card drawn with 7 in hand is discarded.
	var m: MatchState = F.new_match(F.setup(_deck(20)))
	m.resolve_round()
	m.begin_round()
	assert_eq(m.sides[P].hand.size(), 7, "5 + 2")
	m.resolve_round()
	m.begin_round()
	assert_eq(m.sides[P].hand.size(), 7, "capped at 7")
	assert_eq(m.sides[P].discard.size(), 2, "both extra draws discarded")
	assert_eq(F.events_of(m, RulesEvent.CARD_BURNED).size(), 2, "shown in the log")


func test_empty_deck_reshuffles_discard() -> void:
	var m: MatchState = F.new_match(F.setup(_deck(6)))
	assert_eq(m.sides[P].deck.size(), 1, "6 - 5")
	var uid: int = m.sides[P].hand[0].uid
	assert_true(m.submit(P, RulesIntent.play_card(uid, F.LEFT))["ok"], "play one")
	F.place(m, E, F.unit("killer", 5, 9), F.LEFT)
	m.resolve_round()
	assert_eq(m.sides[P].discard.size(), 1, "dead unit discarded")
	m.begin_round()
	assert_eq(F.events_of(m, RulesEvent.DECK_RESHUFFLED).size(), 1, "discard shuffled back in")
	assert_eq(m.sides[P].hand.size(), 6, "4 left + 2 drawn")


func test_mulligan_after_drawing_five_once_round_one_only() -> void:
	# Ruling 3: draw 5 first, then put back any number, shuffle in, redraw that many.
	var m: MatchState = F.new_match(F.setup(_deck(20)))
	var back: Array = [m.sides[P].hand[0].uid, m.sides[P].hand[1].uid]
	var r: Dictionary = m.mulligan(P, back)
	assert_true(r["ok"], "mulligan accepted")
	assert_eq(m.sides[P].hand.size(), 5, "still 5 cards")
	assert_eq(m.sides[P].deck.size() + m.sides[P].hand.size(), 20, "no card lost")
	assert_false(m.mulligan(P, [m.sides[P].hand[0].uid])["ok"], "only one free mulligan")
	m.resolve_round()
	m.begin_round()
	assert_false(m.mulligan(P, [])["ok"], "not after Round 1")


# --- Deploy -----------------------------------------------------------------------------

func test_supply_is_spent_and_checked() -> void:
	var m: MatchState = F.new_match(F.setup([F.breacher(), F.rifleman(), F.rifleman()]))
	assert_false(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "breacher"), F.LEFT))["ok"], "3 > 2 Supply")
	var r1: int = m.sides[P].hand[1].uid
	var r2: int = m.sides[P].hand[2].uid
	assert_true(m.submit(P, RulesIntent.play_card(r1, F.LEFT))["ok"], "1 Supply")
	assert_true(m.submit(P, RulesIntent.play_card(r2, F.LEFT))["ok"], "1 Supply")
	assert_eq(m.sides[P].supply, 0, "spent")
	assert_eq(m.sides[P].hand.size(), 1, "cards left the hand")


func test_zone_capacity_four_includes_pending_plays() -> void:
	# core-rules §9: a full zone can't take another card.
	var cards: Array = []
	for i: int in 5:
		cards.append(F.unit("z%d" % i, 1, 1, F.W.NONE, {"cost": 0}))
	var m: MatchState = F.new_match(F.setup(cards))
	F.place(m, P, F.unit("already", 1, 1), F.MID)
	for i: int in 3:
		assert_true(m.submit(P, RulesIntent.play_card(m.sides[P].hand[0].uid, F.MID))["ok"], "slot %d" % (i + 2))
	var r: Dictionary = m.submit(P, RulesIntent.play_card(m.sides[P].hand[0].uid, F.MID))
	assert_false(r["ok"], "5th unit rejected")
	assert_eq(r["reason"], "zone full", "reason for the UI")
	assert_true(m.submit(P, RulesIntent.play_card(m.sides[P].hand[0].uid, F.LEFT))["ok"], "other zone fine")
	assert_eq(m.sides[E].line(F.MID).size(), 0, "capacity is per side")


func test_operator_placement_and_rotation_rules() -> void:
	var m: MatchState = F.new_match(F.setup([], F.kestrel()))
	assert_false(m.submit(P, RulesIntent.rotate(F.MID))["ok"], "can't rotate before placing")
	assert_true(m.submit(P, RulesIntent.place_operator(F.LEFT))["ok"], "free placement in Round 1")
	assert_false(m.submit(P, RulesIntent.place_operator(F.MID))["ok"], "only once")
	m.resolve_round()
	m.begin_round()
	var op: RulesUnit = m.sides[P].operator_unit
	assert_eq(op.zone, F.LEFT, "placed")
	F.place(m, P, F.unit("holder_of_right", 0, 9), F.RIGHT)
	assert_false(m.submit(P, RulesIntent.rotate(F.RIGHT))["ok"], "flanks are not adjacent")
	F.place(m, P, F.unit("first_in_mid", 0, 9), F.MID)
	assert_true(m.submit(P, RulesIntent.rotate(F.MID))["ok"], "Left -> Mid")
	assert_false(m.submit(P, RulesIntent.rotate(F.RIGHT))["ok"], "one Rotation per round")
	m.resolve_round()
	assert_eq(F.line_ids(m, P, F.MID), [&"first_in_mid", &"kestrel_ar7"], "Operator goes to the back of the line")


func test_wasp_rotates_twice() -> void:
	var m: MatchState = F.new_match(F.setup([], F.primary("wasp9", 2, 6, F.W.SMG, {"rotations_per_round": 2, "first_shot": true})))
	F.place_operator(m, P, F.LEFT)
	assert_true(m.submit(P, RulesIntent.rotate(F.MID))["ok"], "first")
	assert_true(m.submit(P, RulesIntent.rotate(F.RIGHT))["ok"], "second, from the projected zone")
	m.resolve_round()
	assert_eq(m.sides[P].operator_unit.zone, F.RIGHT, "ended Right")
	assert_true(m.has_first_shot(m.sides[P].operator_unit), "Primary keyword on the Operator")


func test_red_dots_show_only_unit_deployments() -> void:
	# Ruling 13.
	var e: SideSetup = F.setup([F.rifleman(), F.rifleman(), F.hold_the_line(), F.tripwire()], F.kestrel())
	var m: MatchState = F.new_match(null, e)
	m.sides[E].supply = 10
	for id: String in ["rifleman", "rifleman"]:
		assert_true(m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, id), F.LEFT))["ok"], "unit")
	assert_true(m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "hold_the_line"), F.RIGHT))["ok"], "tactic")
	assert_true(m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "tripwire_charge"), F.RIGHT))["ok"], "equipment")
	assert_true(m.submit(E, RulesIntent.place_operator(F.MID))["ok"], "operator")
	assert_eq(m.red_dots(P), PackedInt32Array([2, 1, 0]), "units + Operator only")
	assert_eq(m.red_dots(E), PackedInt32Array([0, 0, 0]), "player committed nothing")


func test_undo_last_play_refunds() -> void:
	var m: MatchState = F.new_match(F.setup([F.rifleman(), F.ammo_resupply(), F.rifleman(), F.rifleman()]))
	var uid: int = F.hand_uid(m, P, "rifleman")
	m.submit(P, RulesIntent.play_card(uid, F.LEFT))
	assert_true(m.undo_last(P)["ok"], "undo")
	assert_eq([m.sides[P].supply, m.sides[P].hand.size()], [2, 4], "Supply and card back")
	m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "ammo_resupply")))
	assert_false(m.undo_last(P)["ok"], "a resolved draw can't be undone")


func test_ammo_resupply_draws_immediately() -> void:
	var m: MatchState = F.new_match(F.setup([F.ammo_resupply()] + _deck(10)))
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "ammo_resupply")))["ok"], "played")
	assert_eq(m.sides[P].hand.size(), 6, "5 - 1 + 2 during Deploy")


# --- Reveal -----------------------------------------------------------------------------

func test_initiative_behind_side_first_ties_to_player() -> void:
	var p: SideSetup = F.setup([F.suppressing_fire()])
	var e: SideSetup = F.setup([F.suppressing_fire()])
	var m: MatchState = F.new_match(p, e)
	m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "suppressing_fire"), F.MID))
	m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "suppressing_fire"), F.MID))
	m.resolve_round()
	var reveals: Array = F.events_of(m, RulesEvent.CARD_REVEALED).map(func(ev: Dictionary) -> StringName: return ev["side"])
	assert_eq(F.events_of(m, RulesEvent.INITIATIVE)[0]["side"], &"player", "tie -> player")
	assert_eq(reveals, [&"player", &"enemy"], "player resolves first")
	m.begin_round()
	m.sides[P].score = 2
	m.sides[E].score = 1
	m.resolve_round()
	assert_eq(F.events_of(m, RulesEvent.INITIATIVE)[1]["side"], &"enemy", "enemy is behind -> enemy first")


func test_arrivals_in_play_order_and_shieldman_ruling() -> void:
	# Ruling 6: Shieldman goes in front of units already there; two in one Reveal ->
	# play order, so the later one ends up in front.
	var s1: CardData = F.shieldman()
	s1.id = &"shield_a"
	var s2: CardData = F.shieldman()
	s2.id = &"shield_b"
	var m: MatchState = F.new_match(F.setup([F.rifleman(), s1, s2]))
	m.sides[P].supply = 10
	F.place(m, P, F.unit("veteran", 1, 1), F.MID)
	for id: String in ["rifleman", "shield_a", "shield_b"]:
		assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, id), F.MID))["ok"], id)
	m.reveal()
	assert_eq(F.line_ids(m, P, F.MID), [&"shield_b", &"shield_a", &"veteran", &"rifleman"], "later Shieldman in front")


func test_callout_reveals_red_dots_and_buffs_first_unit_card_to_arrive() -> void:
	# Ruling 7: first unit card to arrive in that zone at this Reveal, played before or
	# after the Callout; the Operator doesn't count.
	var p: SideSetup = F.setup([F.callout(), F.rifleman(), F.rifleman()], F.kestrel())
	var e: SideSetup = F.setup([F.breacher()])
	var m: MatchState = F.new_match(p, e, F.map())
	m.sides[E].supply = 5
	m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "breacher"), F.LEFT))
	assert_true(m.submit(P, RulesIntent.place_operator(F.LEFT))["ok"], "Operator first")
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "callout"), F.LEFT))["ok"], "Callout")
	var revealed: Array[Dictionary] = F.events_of(m, RulesEvent.RED_DOTS_REVEALED)
	assert_eq(revealed.size(), 1, "resolves immediately")
	assert_eq(revealed[0]["card_ids"], [&"breacher"] as Array[StringName], "shows the enemy Breacher")
	var r_uid: int = m.sides[P].hand[0].uid
	m.submit(P, RulesIntent.play_card(r_uid, F.LEFT))
	m.submit(P, RulesIntent.play_card(m.sides[P].hand[0].uid, F.LEFT))
	m.reveal()
	var first: RulesUnit = m.sides[P].find_unit(r_uid)
	var second: RulesUnit = m.sides[P].line(F.LEFT)[2]
	assert_eq(m.firepower_of(first), 3, "first unit card: 2 + 1")
	assert_eq(m.firepower_of(second), 2, "only one unit")
	assert_eq(m.firepower_of(m.sides[P].operator_unit), 3, "Operator not buffed (3 + 0 Close)")


func test_callout_is_wasted_if_no_unit_arrives() -> void:
	var m: MatchState = F.new_match(F.setup([F.callout()]))
	m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "callout"), F.RIGHT))
	m.reveal()
	assert_eq(F.events_of(m, RulesEvent.EFFECT_WASTED).size(), 1, "wasted")


func test_recon_specialist_reveals_next_round() -> void:
	var p: SideSetup = F.setup([F.recon_specialist()] + _deck(6))
	var e: SideSetup = F.setup(_deck(8, "e"))
	var m: MatchState = F.new_match(p, e)
	m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "recon_specialist"), F.RIGHT))
	m.resolve_round()
	m.begin_round()
	m.submit(E, RulesIntent.play_card(m.sides[E].hand[0].uid, F.RIGHT))
	m.submit(E, RulesIntent.play_card(m.sides[E].hand[0].uid, F.LEFT))
	assert_eq(m.revealed_red_dots(P, F.RIGHT).size(), 1, "Right revealed this round")
	assert_eq(m.revealed_red_dots(P, F.LEFT).size(), 0, "other zones not")


## kc-abc-labels AB1: Breach and Clear is simply 2 damage to every enemy unit in a column (no Close rule).
func test_breach_and_clear_two_damage_in_any_column() -> void:
	var m: MatchState = F.new_match(F.setup([F.breach_and_clear(), F.breach_and_clear()]), null,
			F.map([F.R.CLOSE, F.R.LONG, F.R.MID]))
	m.sides[P].supply = 6
	var close_a: RulesUnit = F.place(m, E, F.unit("ca", 0, 5), F.LEFT)
	var close_b: RulesUnit = F.place(m, E, F.unit("cb", 0, 5), F.LEFT)
	var mid: RulesUnit = F.place(m, E, F.unit("m", 0, 5), F.RIGHT)
	m.submit(P, RulesIntent.play_card(m.sides[P].hand[0].uid, F.LEFT))
	m.submit(P, RulesIntent.play_card(m.sides[P].hand[0].uid, F.RIGHT))
	m.reveal()
	assert_eq([close_a.armor, close_b.armor, mid.armor], [3, 3, 3], "2 each, in a Close column too")


func test_point_man_and_second_in_line_damage_in_operator_or_adjacent_zone() -> void:
	# kc-loadout-cut: the Frag Grenade's effects on a test-only killstreak (generic effect paths).
	var p: SideSetup = F.setup([], F.kestrel())
	var m: MatchState = F.new_match(p)
	F.grant(m, P, F.point_strike())
	F.place_operator(m, P, F.LEFT)
	var pm: RulesUnit = F.place(m, E, F.marksman(), F.MID)
	var nxt: RulesUnit = F.place(m, E, F.unit("next", 0, 4), F.MID)
	var r: Dictionary = m.submit(P, RulesIntent.use_item(&"point_strike", F.RIGHT))
	assert_false(r["ok"], "Right is not adjacent to Left")
	assert_true(m.submit(P, RulesIntent.use_item(&"point_strike", F.MID))["ok"], "adjacent Mid")
	m.reveal()
	assert_false(pm.is_alive(), "2 to the point man")
	assert_eq(nxt.armor, 3, "1 to the next enemy")
	var rec: Dictionary = F.events_of(m, RulesEvent.UNIT_ELIMINATED)[0]
	assert_eq([rec["source_kind"], rec["by_id"], rec["credit"]], [&"killstreak", &"point_strike", true], "the kill is credited")


func test_timed_minus_two_fp_and_no_first_shot_this_round() -> void:
	# kc-loadout-cut: the old Flashbang's effects on a test-only killstreak.
	var p: SideSetup = F.setup([], F.kestrel())
	var m: MatchState = F.new_match(p)
	F.grant(m, P, F.blind_strike())
	F.place_operator(m, P, F.MID)
	var b: RulesUnit = F.place(m, E, F.breacher(), F.LEFT)
	m.submit(P, RulesIntent.use_item(&"blind_strike", F.LEFT))
	m.reveal()
	assert_eq(m.firepower_of(b), 3 - 2 + 0, "Breacher 3 -2 (Left is Mid range on flat map)")
	assert_false(m.has_first_shot(b), "lost First Shot")
	m.firefight()
	m.score()
	assert_true(m.has_first_shot(b), "back next round")


func test_flank_route_moves_unit_and_grants_first_shot() -> void:
	var m: MatchState = F.new_match(F.setup([F.flank_route()]))
	var u: RulesUnit = F.place(m, P, F.unit("mover", 2, 2), F.LEFT)
	assert_false(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "flank_route"), -1, u.uid, F.RIGHT))["ok"], "not adjacent")
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "flank_route"), -1, u.uid, F.MID))["ok"], "Left -> Mid")
	var enemy: RulesUnit = F.place(m, E, F.unit("e", 9, 2), F.MID)
	m.reveal()
	assert_eq(u.zone, F.MID, "moved")
	assert_true(m.has_first_shot(u), "gained First Shot")
	m.firefight()
	assert_false(enemy.is_alive(), "fired first")
	assert_true(u.is_alive(), "and survived")


func test_tripwire_hits_next_enemy_arrival_and_is_consumed() -> void:
	# Rulings part 2 #2 (overrule): Equipment is armed before step a, so the Tripwire
	# catches the first enemy unit arriving in the same Reveal, and only that one.
	var p: SideSetup = F.setup([F.tripwire()])
	var e: SideSetup = F.setup([F.unit("first", 0, 5), F.unit("second", 0, 5)])
	var m: MatchState = F.new_match(p, e)
	m.sides[E].supply = 5
	m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "tripwire_charge"), F.MID))
	m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "first"), F.MID))
	m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "second"), F.MID))
	m.reveal()
	var placed: Dictionary = F.events_of(m, RulesEvent.EQUIPMENT_PLACED)[0]
	assert_eq(placed.get("private_to", &""), &"player", "Tripwire stays hidden from the enemy")
	var line: Array = m.sides[E].line(F.MID)
	assert_eq([line[0].armor, line[1].armor], [2, 5], "the first arrival this Reveal takes 3, the next none")
	assert_eq(m.sides[P].equipment[F.MID].size(), 0, "consumed")
	assert_eq(m.sides[P].discard[0].card.id, &"tripwire_charge", "to the discard pile")


func test_hold_the_line_cover_lasts_this_round() -> void:
	var m: MatchState = F.new_match(F.setup([F.hold_the_line()]))
	var u: RulesUnit = F.place(m, P, F.unit("u", 0, 9), F.MID)
	m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "hold_the_line"), F.MID))
	m.reveal()
	assert_eq(m.cover_of(u), 1, "Cover 1 this round")
	m.firefight()
	m.score()
	assert_eq(m.cover_of(u), 0, "gone next round")


func test_mortar_eliminations_flagged_killstreak() -> void:
	var p: SideSetup = F.setup()
	p.killstreaks.assign([F.mortar()])
	var m: MatchState = F.new_match(p)
	StreakTracker.grant(m, P, &"mortar_barrage")  # p05: killstreaks come from the Streak Tray
	F.place(m, E, F.rifleman(), F.RIGHT)
	var gunner: RulesUnit = F.place(m, E, F.gunner(), F.RIGHT)
	m.submit(P, RulesIntent.use_item(&"mortar_barrage", F.RIGHT))
	m.resolve_round()
	assert_eq(gunner.armor, 4, "2 to each")
	assert_eq(m.sides[P].eliminations, 1, "elimination counts for the mode")
	assert_eq(m.sides[P].streak, 0, "but not for the streak")


# --- Score / hooks / determinism -----------------------------------------------------------

func test_squad_loss_keeps_streak_operator_down_resets_after_count() -> void:
	var p: SideSetup = F.setup([], F.primary("op", 1, 2))
	var m: MatchState = F.new_match(p)
	F.place(m, P, F.unit("squaddie", 5, 1), F.LEFT)
	F.place(m, E, F.unit("e1", 5, 1), F.LEFT)
	m.sides[P].streak = 1
	m.resolve_round()
	assert_eq(m.sides[P].streak, 2, "squad loss: streak kept, +1 for the kill")
	m.begin_round()
	F.place_operator(m, P, F.MID)
	F.place(m, P, F.unit("killer", 5, 9), F.MID)
	F.place(m, E, F.unit("e2", 5, 1), F.MID)
	m.resolve_round()
	var mine: Array = F.events_of(m, RulesEvent.STREAK_CHANGED).filter(func(ev: Dictionary) -> bool: return ev["side"] == &"player")
	var last: Dictionary = mine.back()
	assert_eq([last["before"], last["gained"], last["reset"], last["streak"]], [2, 1, true, 0], "kill counted, then reset")


func test_comms_relay_streak_while_controlled() -> void:
	var m: MatchState = F.new_match(F.setup([F.comms_relay()]))
	F.place(m, P, F.unit("u", 0, 9), F.RIGHT)
	m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "comms_relay"), F.RIGHT))
	m.resolve_round()
	assert_eq(m.sides[P].streak, 1, "+1 while you control the zone")
	m.begin_round()
	F.place(m, E, F.unit("contest", 0, 99), F.RIGHT)
	m.resolve_round()
	assert_eq(m.sides[P].streak, 1, "no bonus while contested")


func test_operator_respawns_at_full_armor_next_deploy() -> void:
	var m: MatchState = F.new_match(F.setup([], F.kestrel()))
	var op: RulesUnit = F.place_operator(m, P, F.MID)
	F.place(m, E, F.unit("big", 9, 9), F.MID)
	m.resolve_round()
	assert_false(op.is_on_board(), "down")
	m.begin_round()
	assert_true(m.sides[P].operator_can_deploy, "may respawn")
	assert_true(m.submit(P, RulesIntent.place_operator(F.LEFT))["ok"], "any zone")
	m.reveal()
	assert_eq([op.zone, op.armor], [F.LEFT, 7], "full Armor")


func test_enemy_stat_bonus_applies_to_units_and_operator() -> void:
	var e: SideSetup = F.setup([], F.kestrel())
	e.armor_bonus = 1
	var m: MatchState = F.new_match(null, e)
	var u: RulesUnit = F.place(m, E, F.rifleman(), F.LEFT)
	assert_eq([u.armor, m.sides[E].operator_unit.armor], [3, 8], "+1 Armor (Bracket 2)")


class EndAfterTwo extends MatchHooks:
	var calls: int = 0
	func score_round(state, control: Array) -> void:
		calls += 1
		for c: int in control:
			if c == MatchState.PLAYER:
				state.sides[0].score += 1
	func check_match_end(state) -> StringName:
		return &"draw" if state.round_number >= 2 else &""


func test_mode_hooks_score_and_end_match() -> void:
	var hooks: EndAfterTwo = EndAfterTwo.new()
	var m: MatchState = F.new_match(null, null, null, 1, hooks)
	F.place(m, P, F.unit("u", 0, 9), F.LEFT)
	m.resolve_round()
	assert_eq(m.sides[P].score, 1, "hook scored the controlled zone")
	m.begin_round()
	m.resolve_round()
	assert_eq([m.phase, m.result], [MatchState.Phase.ENDED, &"draw"], "hook ended the match")
	m.begin_round()
	assert_eq(m.round_number, 2, "no rounds after the end")
	assert_eq(hooks.calls, 2, "called once per round")


func _scripted_match(seed_value: int) -> MatchState:
	var p: SideSetup = F.setup([F.rifleman(), F.point_man(), F.marksman(), F.breacher(), F.gunner(), F.combat_medic(), F.shieldman(), F.rifleman()], F.kestrel())
	var e: SideSetup = F.setup([F.rifleman(), F.flanker(), F.marksman(), F.breacher(), F.gunner(), F.demolitions(), F.rifleman(), F.point_man()], F.kestrel())
	p.keep_deck_order = false
	e.keep_deck_order = false
	var m: MatchState = MatchState.new(null, F.map(), p, e, seed_value)
	m.start_match()
	for r: int in 4:
		for side: int in 2:
			if r == 0:
				m.submit(side, RulesIntent.place_operator(side + 1))
			for c: RulesCard in m.sides[side].hand.duplicate():
				m.submit(side, RulesIntent.play_card(c.uid, (c.uid + r) % 3))
		m.resolve_round()
		m.begin_round()
	return m


func test_same_seed_replays_exactly() -> void:
	var a: MatchState = _scripted_match(42)
	var b: MatchState = _scripted_match(42)
	assert_true(a.events.size() > 50, "a real match ran")
	assert_eq(var_to_str(a.events), var_to_str(b.events), "identical event streams")
	var c: MatchState = _scripted_match(7)
	assert_true(var_to_str(a.events) != var_to_str(c.events), "another seed plays differently")


func test_engine_touches_no_nodes_or_global_rng() -> void:
	var bus: Node = tree.root.get_node("EventBus")
	var fired: Array = []
	var cb: Callable = func(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void: fired.append(1)
	bus.unit_eliminated.connect(cb)
	seed(123)
	var before: int = randi()
	seed(123)
	_scripted_match(5)
	assert_eq(randi(), before, "global RNG untouched")
	assert_eq(fired.size(), 0, "no EventBus emissions from the engine")
	bus.unit_eliminated.disconnect(cb)

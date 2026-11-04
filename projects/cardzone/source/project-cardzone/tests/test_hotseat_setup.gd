# test_hotseat_setup.gd
# Purpose: cz14 hot-seat in Match setup, by touch on the phone (spec §16.3): HOT-SEAT is selectable;
#   S1 Player 1 is P1 (FIRST TURN greyed, a tap says why, Alternate does not advance); S2 Player 2
#   picks the route (the ROUTE row reads P2 PICKS ROUTE); START opens the match behind the cover
#   "PASS TO PLAYER 2" (Player 2 drops first) with no AI opponent, mode "hotseat" saved after the
#   first action, and the next-match line says so.
# Author: Mechanics Developer Agent (cz14)
extends "res://tests/test_setup_helpers.gd"

const SETUP: String = "res://scenes/setup/MatchSetup.tscn"
const MATCH: String = "res://scenes/match/Match.tscn"


func test_hotseat_by_touch_from_setup_to_the_first_cover() -> void:
	await phone_begin()
	var setup: Control = await spawn(SETUP)
	await touch(setup.get_choice_button("opponent", "hotseat"))
	assert_eq(setup.choices["opponent"], "hotseat", "HOT-SEAT chosen by touch")
	assert_eq(setup.last_notice, "", "no refusal")
	var route_label: Label = setup.get_node("SafeArea/Column/Row_route").get_child(0)
	assert_eq(route_label.text, "P2 PICKS ROUTE", "S2: Player 2 picks the route")
	for v: String in ["me", "opponent", "alternate"]:
		assert_eq(setup.get_choice_button("first", v).theme_type_variation, &"SegNo", "FIRST TURN %s greyed in hot-seat" % v)
	var first_before: String = setup.choices["first"]
	await touch(setup.get_choice_button("first", "opponent"))
	assert_true("Player 1 always takes the first turn" in setup.last_notice, "a tap says why: '%s'" % setup.last_notice)
	assert_eq(setup.choices["first"], first_before, "FIRST TURN unchanged")
	await touch(setup.get_choice_button("route", "C"))
	assert_true("hot-seat, route C (Player 2 picks it)" in setup.get_next_text(), "next line: %s" % setup.get_next_text())
	assert_true("Player 2" in (setup.get_node("SafeArea/Column/AboutLabel") as Label).text, "about text names Player 2")
	check_labels(setup.get_text_labels(), "setup (hot-seat)")
	await touch(setup.get_button(&"start"))
	var m: Control = await follow(setup, MATCH)
	var ctrl: Node = m.get_controller()
	assert_not_null(m.shell, "the shell starts it")
	assert_eq(String(m.shell.start_error), "", "started")
	assert_true(ctrl.hotseat and ctrl.opponent == null, "hot-seat, no AI")
	assert_eq(ctrl.state.route, DataEnums.Route.C, "Player 2's route")
	assert_true(ctrl.is_covered() and ctrl.cover_seat == MatchState.P2, "covered for Player 2, who drops first")
	var cover: Control = m.get_cover()
	cover.arm_ms = 0
	assert_true(cover.is_visible_in_tree(), "the cover is on screen")
	assert_eq(cover.get_texts()["heading"], "PASS TO PLAYER 2", "PASS TO PLAYER 2")
	assert_eq(cover.get_texts()["body"], "Player 1: look away. Player 2 drops first: choose where to land.", "cover words")
	assert_true(cover.get_tap_button().get_global_rect().size.x >= logical().x - 1.0, "the whole screen is the tap target")
	assert_eq(SetupPrefs.get_value("setup", "last_human_seat", null), null, "hot-seat leaves the vs-AI Alternate alone")
	await touch(cover.get_tap_button())
	assert_eq([ctrl.human, ctrl.phase], [MatchState.P2, &"drop"], "Player 2's drop after the tap")
	assert_false(cover.is_visible_in_tree(), "the cover is down")
	assert_true(MatchStore.saved_info().is_empty() or not MatchStore.has_saved_match(), "nothing saved before the first action")
	await phone_end(m)

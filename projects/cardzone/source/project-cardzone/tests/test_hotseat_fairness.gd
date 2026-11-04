# test_hotseat_fairness.gd
# Purpose: cz14 fairness proof for hot-seat (spec §16.2 P1-P20, P18). A fixture gives each seat its
#   own marker cards that the other seat has never seen (Player 1: Medkit, Bandage, Trail Boots in
#   hand, Backpack and Long Scope in the loadout; Player 2: Plate Vest, Heavy Plate, Phantom Suit,
#   Smoke Grenade, Recon Drone, Scrap SMG in the loadout), so any of them on screen at the wrong
#   time is a leak by card id / name. The test walks a turn, a shot, the defender's Brace (behind
#   its own cover), the LOG, a Pack and the next turn by touch, and at every cover and every
#   decision walks EVERY node under the match screen (hidden ones too: CzCard info and card_id
#   meta, Label / Button / RichTextLabel text): no private card of seat B while seat A is on
#   screen, none of either seat while the cover is up. Positive controls prove the walker finds
#   the cards when they are there (the shown seat's own hand, the same walk aimed at the other
#   watcher), and an inspector left open on a private card is wiped when the cover goes up.
# Author: Mechanics Developer Agent (cz14)
extends "res://tests/test_hotseat_kit.gd"

const P1_PRIVATE: Array[StringName] = [&"medkit", &"bandage", &"trail_boots", &"backpack", &"long_scope"]
const P2_PRIVATE: Array[StringName] = [&"plate_vest", &"heavy_plate", &"phantom_suit", &"smoke_grenade", &"recon_drone", &"scrap_smg"]


func _marker_fixture() -> MatchState:
	return _fixture({"active": "P1",
			"P1": {"area": "rail_yard", "health": 5, "line": ["hunting_rifle"], "hand": ["medkit", "bandage", "trail_boots"],
				"loadout": ["backpack", "long_scope", "scavenge", "dash", "duck"]},
			"P2": {"area": "docks", "health": 5,
				"loadout": ["plate_vest", "heavy_plate", "phantom_suit", "smoke_grenade", "recon_drone", "scrap_smg"]}})


## Card names of these ids on screen right now (CzCards and any text).
func _shown(m: Control, ids: Array[StringName]) -> Array:
	var out: Array = []
	var names: Dictionary = {}
	for id: StringName in ids:
		names[CardDB.get_card(id).display_name] = id
	for n: Node in m.find_children("*", "", true, false):
		var text: String = ""
		if n is CzCard:
			text = str((n as CzCard).info.get("name", ""))
		elif n is Label:
			text = (n as Label).text
		elif n is Button:
			text = (n as Button).text
		elif n is RichTextLabel:
			text = (n as RichTextLabel).get_parsed_text()
		for nm: String in names.keys():
			if nm in text and not out.has(names[nm]):
				out.append(names[nm])
	return out


func test_no_private_card_of_the_other_seat_is_ever_in_the_screen_tree() -> void:
	var m: Control = await _spawn_hotseat(_marker_fixture())
	var ctrl: Node = m.get_controller()
	# 1. The match opens behind Player 1's cover: neither seat's cards anywhere.
	assert_true(ctrl.is_covered() and ctrl.cover_seat == MatchState.P1, "opens covered for Player 1")
	assert_eq(_shown(m, P1_PRIVATE + P2_PRIVATE), [], "no marker card under the opening cover")
	assert_true(walk_armed >= 1, "the cover walk had both seats' markers to look for")
	# 2. Player 1's turn: its own hand is there (positive control), Player 2's loadout is not.
	await _tap_cover(m)
	assert_eq(ctrl.human, MatchState.P1, "Player 1 on screen")
	var own: Array = _shown(m, P1_PRIVATE)
	assert_true(own.has(&"medkit") and own.has(&"bandage") and own.has(&"trail_boots"), "Player 1 sees its own hand: %s" % [own])
	assert_eq(_shown(m, P2_PRIVATE), [], "Player 2's cards are nowhere while Player 1 plays")
	# The walker works: aimed at Player 2 as the watcher it finds Player 1's hand.
	var saved_known: Array = known.duplicate(true)
	var before: int = leaks.size()
	ctrl.human = MatchState.P2
	_check_screen(m, "control: Player 1's screen as if Player 2 watched")
	ctrl.human = MatchState.P1
	assert_true(leaks.size() > before, "control: the walk detects private cards when they are on screen (%d hits)" % (leaks.size() - before))
	leaks.resize(before)
	known = saved_known
	_check_screen(m, "Player 1's turn")
	# 3. Player 1 fires the Hunting Rifle: the defender's Brace prompt waits behind its own cover.
	var rifle: int = ctrl.state.seats[0].line[0]
	await _do_by_touch(m, {"type": "shoot", "weapon": rifle, "target": 1})
	assert_true(ctrl.is_covered() and ctrl.cover_seat == MatchState.P2, "the shot passes to Player 2")
	assert_eq(StringName(ctrl.cover_info()["reason"]), &"brace", "the cover is the Brace cover")
	assert_eq(String(m.get_cover().get_texts()["body"]), "Player 1: look away. Player 2: incoming shot. Choose your Brace.", "cover words")
	assert_eq(ctrl.phase, &"cover", "phase cover")
	assert_false(m.get_brace_panel().visible, "no Brace panel under the cover")
	assert_eq(_shown(m, P1_PRIVATE + P2_PRIVATE), [], "no marker card under the Brace cover")
	# 4. Player 2: the Brace prompt with its own next hand; Player 1's hand nowhere, the LOG too.
	await _tap_cover(m)
	assert_eq([ctrl.human, ctrl.phase], [MatchState.P2, &"brace"], "Player 2's Brace step")
	assert_true(m.get_brace_panel().visible, "the Brace panel is up")
	assert_true(_shown(m, P2_PRIVATE).has(&"plate_vest"), "Player 2 sees its own next hand")
	assert_eq(_shown(m, P1_PRIVATE), [], "Player 1's cards are nowhere during Player 2's Brace")
	_check_screen(m, "Player 2's Brace prompt")
	await _touch(m.get_corner_buttons()[&"log"])
	assert_true(m.get_inspector().is_open() and m.get_inspector().get_title_text() == "Match log", "LOG open")
	assert_eq(_shown(m, P1_PRIVATE), [], "Player 2's LOG names none of Player 1's cards")
	_check_screen(m, "Player 2's LOG")
	m.get_inspector().close()
	var sug: Array = ctrl.brace_suggestion().get("cards", [])
	await _brace_by_touch(m, {"type": "brace", "cards": sug, "via": "suggested"})
	assert_true(ctrl.is_covered() and ctrl.cover_seat == MatchState.P1, "the Brace passes back to Player 1")
	# The braced cards are public now (P11: revealed when used), the rest of Player 2's are not.
	var braced: Array = []
	for inst: Variant in sug:
		braced.append(ctrl.state.card_id(int(inst)))
	var rest: Array[StringName] = P2_PRIVATE.filter(func(id: StringName) -> bool: return not braced.has(id))
	assert_true(not braced.is_empty(), "Player 2 braced with %s" % [braced])
	assert_eq(_shown(m, P1_PRIVATE + rest), [], "no unrevealed marker card under the cover after the Brace")
	# 5. Player 1 again.
	await _tap_cover(m)
	assert_eq(_shown(m, rest), [], "Player 2's unbraced cards stay hidden from Player 1 (braced: %s)" % [braced])
	_check_screen(m, "Player 1 after the Brace")
	# 6. Player 1 packs: Player 2's turn draws the markers; Player 1's stowed hand stays hidden.
	await _do_by_touch(m, {"type": "end_turn", "hold": []})
	assert_true(ctrl.is_covered() and ctrl.cover_seat == MatchState.P2, "END TURN passes to Player 2")
	await _tap_cover(m)
	assert_eq([ctrl.human, ctrl.phase], [MatchState.P2, &"act"], "Player 2's turn")
	assert_true(not m.get_cards(&"hand").is_empty(), "Player 2's hand on screen")
	assert_eq(_shown(m, P1_PRIVATE), [], "Player 1's stowed hand and loadout are nowhere")
	_check_screen(m, "Player 2's turn")
	# 7. Leave an inspector open on Player 2's private card and pass: the cover wipes it.
	var secret: StringName = ctrl.state.card_id(ctrl.state.seats[1].hand[0])
	m.inspect_card(CardDB.get_card(secret), "In your hand")
	assert_true(m.get_inspector().is_open(), "inspector open on %s" % secret)
	ctrl.request({"type": "end_turn", "hold": []})
	for i: int in 2:
		await tree.process_frame
	assert_true(ctrl.is_covered() and ctrl.cover_seat == MatchState.P1, "Player 2's END TURN passes to Player 1")
	assert_false(m.get_inspector().is_open(), "the cover closed the inspector")
	assert_eq(_shown(m, P1_PRIVATE + P2_PRIVATE), [], "nothing private left on the screen (inspector, toast, dock)")
	assert_true(m.get_toast_text() == "" and not m.get_dock().visible, "no toast or dock under the cover")
	assert_true(walk_checks >= 8 and walk_armed >= 8, "screen walks: %d (%d armed)" % [walk_checks, walk_armed])
	assert_eq(leaks, [] as Array[String], "no private card of the other seat ever reached the screen")
	_despawn(m)


func test_covered_view_is_the_same_whatever_either_seat_holds() -> void:
	# P18 for the cover itself: two matches that differ only in BOTH seats' private cards give
	# the same covered view (so nothing on the covered screen can depend on them).
	var a: Control = await _spawn_hotseat(_marker_fixture())
	var va: Dictionary = a.get_controller().view()
	_despawn(a)
	var other: MatchState = _fixture({"active": "P1",
			"P1": {"area": "rail_yard", "health": 5, "line": ["hunting_rifle"], "hand": ["scavenge", "dash", "duck"],
				"loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]},
			"P2": {"area": "docks", "health": 5, "loadout": ["duck", "dash", "scavenge", "scavenge", "dash", "duck"]}})
	var b: Control = await _spawn_hotseat(other)
	var vb: Dictionary = b.get_controller().view()
	assert_true(bool(va.get("covered", false)) and bool(vb.get("covered", false)), "both covered")
	assert_eq(JSON.stringify(va), JSON.stringify(vb), "the covered view does not depend on any private card")
	assert_eq(leaks, [] as Array[String], "no leaks")
	_despawn(b)

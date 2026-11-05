# test_clarity.gd
# Purpose: cz-clarity pass (the studio head could not tell what was going on):
#   - card_words.gd: every card says what it gives in plain words; the icon legend;
#   - ActionText.outcome: plain outcome lines with the numbers that changed (loot, shots, Hits, plays);
#   - the next hand is hidden by default, the DECK row peeks at it, the Brace step opens it;
#   - the turn panel says what to do now and keeps the last outcome lines;
#   - inspect everywhere: long press on loot rows, dock buttons, corner buttons, pools and the DECK
#     row opens a plain explanation; the inspector puts "what it gives you" first;
#   - How to play: from HELP (INFO with nothing selected), from the pause menu, and once before the
#     first match (then remembered); the coach texts use the same words.
# All by touch on the phone (844x390 pt @3x, 1168x540 logical).
# Author: UI/UX Agent (cz-clarity)
extends "res://tests/test_setup_helpers.gd"

const MATCH: String = "res://scenes/match/Match.tscn"
const CardWords: GDScript = preload("res://scripts/ui/card_words.gd")
const ActionText: GDScript = preload("res://scripts/match/action_text.gd")
const HowToPlay: GDScript = preload("res://scripts/ui/how_to_play.gd")


## A scripted rival: fires every legal shot first, braces with nothing, else the first legal action.
class Shooter extends RefCounted:
	var kind: String = "Shooter"

	func choose_action(state: MatchState, seat: int) -> Dictionary:
		var legal: Array[Dictionary] = LoadoutRules.legal_actions(state)
		for a: Dictionary in legal:
			if a["type"] == "shoot" and int(a["seat"]) == seat:
				return a
		for a: Dictionary in legal:
			if int(a["seat"]) == seat:
				return a
		return {}


## A rival that plays its guns, fires every shot it can, then ends its turn.
class RifleRival extends RefCounted:
	var kind: String = "Rifle"

	func choose_action(state: MatchState, seat: int) -> Dictionary:
		var legal: Array[Dictionary] = LoadoutRules.legal_actions(state)
		var mine: Array[Dictionary] = legal.filter(func(a: Dictionary) -> bool: return int(a.get("seat", -1)) == seat)
		for a: Dictionary in mine:
			if a["type"] in ["shoot", "drop", "brace"]:
				return a
		for a: Dictionary in mine:
			if a["type"] == "play" and not a.has("adrenaline") and CardDB.get_card(state.card_id(int(a["card"]))).is_weapon():
				return a
		for a: Dictionary in mine:
			if a["type"] == "end_turn" and (a.get("hold", []) as Array).is_empty():
				return a
		return mine[0] if not mine.is_empty() else {}


func _fixture(players: Dictionary) -> MatchState:
	var setup: Dictionary = {"round": 3, "zone_card": 3, "route": "A", "active": players.get("active", "P1"),
			"piles": {"rail_yard": {"crowbar": 3, "red_dot_sight": 3}, "old_town": {"assault_rifle": 2}},
			"players": {"P1": players["P1"], "P2": players["P2"]}}
	var errors: Array = []
	var s: MatchState = MatchState.from_fixture(setup, RulesData.from_card_db(CardDB), {}, errors)
	if not errors.is_empty():
		failures.append("fixture errors: %s" % [errors])
	return s


func _live(state: MatchState, opponent: Object = null) -> Control:
	var m: Control = (load(MATCH) as PackedScene).instantiate()
	m.auto_start = false
	m.safe_area_override = safe_rect()
	m.points_per_px_override = points_per_px()
	var ctrl: Node = m.get_node("%MatchController")
	ctrl.event_delay = 0.0
	ctrl.opponent_delay = 0.0
	ctrl.save_enabled = false
	if opponent != null:
		ctrl.opponent = opponent
	tree.root.add_child(m)
	for i: int in 3:
		await tree.process_frame
	m.start_live(state)
	for i: int in 3:
		await tree.process_frame
	return m


# --- Words ---------------------------------------------------------------------------------------

func test_every_card_says_what_it_gives() -> void:
	for c: CardData in CardDB.all_cards():
		var g: PackedStringArray = CardWords.gives(c)
		assert_true(not g.is_empty(), "%s: plain words" % c.display_name)
		assert_true(CardWords.short(c) != "", "%s: short phrase" % c.display_name)
		for line: String in g:
			assert_false("loadout" in line.to_lower(), "%s: no jargon ('loadout'): %s" % [c.display_name, line])
	var smg: CardData = CardDB.get_card(&"scrap_smg")
	assert_eq(CardWords.short(smg), "a gun: 2 damage, same area only", "SMG short")
	var duck: CardData = CardDB.get_card(&"duck")
	var d: String = " ".join(CardWords.gives(duck))
	assert_true("+1 Search" in d and "blocks 1 damage" in d, "Duck: play or keep: %s" % d)
	assert_true("shield = Brace" in CardWords.icon_legend(duck), "icon legend names the shield")
	assert_true("magnifier = Search" in CardWords.icon_legend(duck), "icon legend names the magnifier")


func test_outcome_lines_name_what_changed() -> void:
	var me: int = 0
	var loot: String = ActionText.outcome({"type": "looted", "seat": 0, "card_id": "scrap_smg", "source": "pile", "area": "docks"}, me)
	assert_true(loot.begins_with("You looted Scrap SMG (a gun: 2 damage, same area only)."), loot)
	var shot: String = ActionText.outcome({"type": "hits_landed", "seat": 0, "count": 3, "health": 2, "source": "shot", "down": true}, me)
	assert_true(shot.begins_with("The rival's shot hit you: -3 health, now 2."), shot)
	assert_true("Down" in shot, "Down explained: %s" % shot)
	var mine: String = ActionText.outcome({"type": "hits_landed", "seat": 1, "count": 1, "health": 4, "source": "shot"}, me)
	assert_eq(mine, "Your shot hit the rival: -1 health, now 4.", "the rival's loss")
	var fired: String = ActionText.outcome({"type": "shot_declared", "seat": 1, "weapon_id": "pump_shotgun", "target": 0, "damage": 3}, me)
	assert_eq(fired, "Rival fired Pump Shotgun at you: 3 damage before you block.", "incoming shot")
	var play: String = ActionText.outcome({"type": "played", "seat": 0, "card_id": "scavenge", "search": 1}, me, {"move": 0, "search": 2})
	assert_eq(play, "You played Scavenge: +1 Search. You have Move 0, Search 2.", "play with pools")
	assert_eq(ActionText.outcome({"type": "turn_started", "seat": 0}, me), "", "turn starts are the indicator's job")
	var ctrl: Node = (load("res://scripts/match/match_controller.gd") as GDScript).new()
	var sum: String = ctrl.summary_of([{"kind": &"move", "event": {"type": "dropped", "seat": 1, "area": "quarry"}}])
	assert_eq(sum, "Rival's turn: dropped into Quarry.", "the drop in the rival summary")
	ctrl.free()
	var gas: String = ActionText.outcome({"type": "gas_hit", "seat": 0, "health": 3}, me)
	assert_eq(gas, "You ended the turn in gas: -1 health, now 3.", "gas")


# --- Next hand, turn panel, feed -----------------------------------------------------------------

func test_next_hand_hidden_by_default_peek_and_brace_open_it() -> void:
	await phone_begin()
	var m: Control = await _live(_fixture({
		"P1": {"area": "rail_yard", "health": 5, "hand": ["scavenge", "duck", "dash"], "loadout": ["plate_vest", "duck", "scavenge", "scavenge", "dash"]},
		"P2": {"area": "docks", "health": 5, "loadout": ["hunting_rifle", "scavenge", "duck", "dash", "scavenge", "dash"]}}), RifleRival.new())
	var strip: Control = m.get_node("%StripCards")
	assert_false(strip.is_visible_in_tree(), "the next hand is hidden on your turn")
	assert_true(m.get_deck_button().is_visible_in_tree(), "the DECK row is there")
	assert_true("TAP TO SEE YOUR NEXT HAND" in m.get_deck_button().text, "DECK row says what a tap does: %s" % m.get_deck_button().text)
	assert_true(m.get_turn_panel().is_visible_in_tree(), "the turn panel shows")
	assert_true(m.get_phase_text().begins_with("YOUR TURN"), "phase: %s" % m.get_phase_text())
	check_buttons([m.get_deck_button()], "deck row")
	await touch(m.get_deck_button())
	assert_true(strip.is_visible_in_tree() and m.get_cards(&"next").size() == 5, "a tap peeks at the next hand")
	assert_true("BLOCKS UP TO 3" in m.get_deck_button().text, "peek header sums the shields: %s" % m.get_deck_button().text)
	await touch(m.get_deck_button())
	assert_false(strip.is_visible_in_tree(), "a second tap hides it")
	# Long press explains the deck.
	await long_press(m.get_deck_button(), 0.6)
	assert_true(m.get_inspector().is_open() and "Your deck" in m.get_inspector().get_title_text(), "DECK row explained")
	m.get_inspector().close()
	# Play a card: the feed says what it gave.
	var hand: Array[Control] = m.get_cards(&"hand")
	await touch(hand[0])
	assert_true("Play it: +1 Search" in m.get_dock_text(), "dock says what the card gives: %s" % m.get_dock_text())
	await touch(m.get_dock_button(&"play"))
	assert_true(m.get_feed().size() >= 1 and m.get_feed()[0].begins_with("You played Scavenge: +1 Search."), "feed: %s" % [m.get_feed()])
	# End the turn: the Shooter fires, the Brace step opens the next hand.
	await touch(m.get_corner_buttons()[&"end_turn"])
	assert_true(m.get_phase_text().begins_with("END OF TURN"), "pack phase named: %s" % m.get_phase_text())
	await touch(m.get_dock_button(&"end_turn"))
	for i: int in 30:
		if m.mode == &"brace":
			break
		await tree.process_frame
	assert_eq(m.mode, &"brace", "the rival shot: Brace step")
	assert_true(strip.is_visible_in_tree(), "the Brace step opens the next hand")
	assert_true(m.get_cards(&"next").size() > 0, "next hand cards to block with")
	await touch(m.get_brace_button(&"brace"))
	for i: int in 30:
		await tree.process_frame
	var feed: String = "\n".join(m.get_feed())
	assert_true("hit you" in feed or "took no damage" in feed or "blocked" in feed or "Rival" in feed, "the rival's turn is in the feed: %s" % feed)
	m.queue_free()
	await phone_end()


# --- Inspect everywhere ----------------------------------------------------------------------------

func test_long_press_explains_buttons_rows_and_loot() -> void:
	await phone_begin()
	var m: Control = await _live(_fixture({
		"P1": {"area": "rail_yard", "health": 5, "hand": ["crowbar", "scavenge", "red_dot_sight"], "line": ["p9_sidearm"],
			"loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]},
		"P2": {"area": "docks", "health": 5, "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]}}))
	var insp: Control = m.get_inspector()
	for key: StringName in [&"undo", &"end_turn", &"log"]:
		await long_press(m.get_corner_buttons()[key], 0.6)
		assert_true(insp.is_open() and insp.get_body_text() != "", "%s explained on long press" % key)
		insp.close()
	await long_press(m.get_pools_label(), 0.6)
	assert_true(insp.is_open() and "MOVE" in insp.get_body_text(), "pools explained")
	insp.close()
	# Hand card: the inspector says what it does now, then what it gives.
	await long_press(m.get_cards(&"hand")[2], 0.6)  # Red-dot Sight: what to do with it now
	assert_true(insp.get_body_text().begins_with("NOW: "), "inspector leads with what to do now: %s" % insp.get_body_text().left(80))
	assert_true("WHAT IT GIVES YOU" in insp.get_body_text(), "then what it gives")
	insp.close()
	# Dock button long press explains it (and does not press it).
	await touch(m.get_cards(&"hand")[0])
	var play: Button = m.get_dock_button(&"play")
	await long_press(play, 0.6)
	assert_true(insp.is_open() and "played row" in insp.get_body_text(), "PLAY explained: %s" % insp.get_body_text())
	assert_eq(m.get_cards(&"hand").size(), 3, "a long press did not play the card")
	insp.close()
	await touch(play)
	# Loot rows: what the card gives on the row, long press opens the card.
	await touch(m.get_area_touch(&"rail_yard"))
	await touch(m.get_dock_button(&"loot"))
	assert_true(m.is_sheet_open(), "loot sheet")
	var row: Button = m.get_sheet_button(&"loot_red_dot_sight")
	assert_not_null(row, "Red-dot row")
	if row != null:
		assert_true("\n" in row.text and "attachment" in row.text.to_lower(), "row says what it is: %s" % row.text)
		await long_press(row, 0.6)
		assert_true(insp.is_open() and insp.get_title_text() == "Red-dot Sight", "row long press opens the card (%s)" % insp.get_title_text())
		assert_true(m.is_sheet_open(), "the sheet stays")
		insp.close()
	# The gun in the played row: the inspector reads the shot.
	m.close_sheet()
	if m.get_dock_button(&"close") != null:
		await touch(m.get_dock_button(&"close"))
	await long_press(m.get_cards(&"line")[0], 0.6)
	assert_eq(insp.get_title_text(), "P-9 Sidearm", "the gun's chip")
	assert_true("NOW:" in insp.get_body_text(), "gun in the played row: what a shot would do now: %s" % insp.get_body_text().left(120))
	insp.close()
	m.queue_free()
	await phone_end()


# --- How to play ---------------------------------------------------------------------------------

func test_how_to_play_help_pause_and_first_match() -> void:
	await phone_begin()
	SetupPrefs.set_value("coach", "how_to_play", false)
	CoachTips.mark_all_seen()
	SetupLaunch.request_new({"opponent": "rookie", "first": "me", "route": "A"})
	var m: Control = await spawn(MATCH)
	var how: Control = m.get_how_to_play()
	assert_true(how.is_open(), "How to play shows before the first match")
	assert_true(m.get_controller().paused, "the match waits")
	assert_eq(how.get_bullet_labels().size(), HowToPlay.BULLETS.size(), "bullets")
	assert_true(HowToPlay.BULLETS.size() >= 5 and HowToPlay.BULLETS.size() <= 7, "5-7 bullets")
	assert_true(how.has_image(), "annotated screenshot")
	check_buttons([how.get_close_button()], "how to play")
	check_labels(how.get_bullet_labels(), "how to play")
	await touch(how.get_close_button())
	assert_false(how.is_open(), "closed")
	assert_false(m.get_controller().paused, "the match goes on")
	assert_true(HowToPlay.is_seen(), "remembered")
	# HELP (INFO with nothing selected) opens it again.
	var info: Button = m.get_node("%InfoButton")
	assert_eq(info.text, "HELP", "INFO is HELP with nothing selected")
	await touch(info)
	assert_true(how.is_open(), "HELP opens How to play")
	await touch(how.get_close_button())
	# The pause menu has it too.
	await touch(m.get_node("%MenuButton"))
	var pm: Control = m.shell.pause_menu
	assert_not_null(pm.get_button(&"how"), "HOW TO PLAY in the pause menu")
	await touch(pm.get_button(&"how"))
	assert_true(how.is_open() and not pm.visible, "pause -> How to play")
	assert_true(m.get_controller().paused, "still paused under it")
	await touch(how.get_close_button())
	assert_false(m.get_controller().paused, "closing it resumes the match")
	m.queue_free()
	await phone_end()
	# A second match on this device: no How to play.
	await phone_begin()
	SetupPrefs.set_value("coach", "how_to_play", true)
	SetupLaunch.request_new({"opponent": "rookie", "first": "me", "route": "A"})
	var m2: Control = await spawn(MATCH)
	assert_false(m2.get_how_to_play().is_open(), "seen: not shown again")
	m2.queue_free()
	await phone_end()


func test_coach_texts_use_the_new_words() -> void:
	for tip: StringName in CoachTips.TIPS:
		var t: String = CoachTips.text(tip, {"hold_limit": 2})["text"]
		assert_false("loadout" in t.to_lower(), "%s tip has no 'loadout': %s" % [tip, t])
		assert_false("top row" in t.to_lower(), "%s tip doesn't point at a hidden row: %s" % [tip, t])

# test_match_flow.gd
# Purpose: cz11 turn flow on the real rules (scripts/match/match_controller.gd behind
#   scenes/match/Match.tscn), driven by TOUCH events only (Input.parse_input_event with
#   InputEventScreenTouch; touch reaches the GUI through the project's emulate_mouse_from_touch),
#   as CallingCard's tests/test_duel_flow.gd does. The screen runs at the root window at phone size
#   (844x390 pt @3x + notch insets = 1168x540 logical, content scaling off) so real touches land.
#   - drop (Core refused in words), play, Adrenaline Move / Search, move, loot (sheet), undo, Pack
#     with Hold toggles, End turn, the next turn drawing the held card first,
#   - shot preview equal to LoadoutRules.preview_shot before FIRE, then the shot; undo refused,
#   - attach (one weapon: direct; two: a sheet), patch up, ditch, Frag throw (aim + area),
#   - the human's Brace prompt (choose cards from the next hand, confirm), against a scripted rival,
#   - concede from MENU, the end sheet, MatchStore saves after every action and clears at the end,
#   - illegal taps explain why (rival's turn, not adjacent, no Search, hold limit, Hit hold,
#     no Brace value, out of range, undo past a shot),
#   - events shown in engine order; delay 0 runs synchronously, a delay paces them,
#   - the selected fan card opens to full width; a line over 6 cards scrolls,
#   - one full match to the end by touch only.
# Author: UI/UX Agent (cz11)
extends "res://tests/test_case.gd"

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const ActionText: GDScript = preload("res://scripts/match/action_text.gd")
const MATCH_SCENE: String = "res://scenes/match/Match.tscn"
const PHONE: Dictionary = {"name": "iPhone 844x390 @3x + notch", "pt": Vector2(844, 390), "ratio": 3.0, "insets": Rect2(47, 0, 47, 21)}
const EPS: float = 0.5


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


var _saved_root_size: Vector2i
var _saved_scale_mode: int = 0


# --- Turn 1 of a new match ---------------------------------------------------------------

func test_new_match_drop_play_move_loot_undo_hold_end_turn() -> void:
	var m: Control = await _spawn(null)
	var ctrl: Node = m.get_controller()
	assert_eq(ctrl.phase, &"drop", "the human drops after the rival (P2 first)")
	assert_eq(m.mode, &"drop", "screen in drop mode")
	assert_true(m.get_dock_title().begins_with("DROP"), "dock asks for a drop: %s" % m.get_dock_title())
	var rival_area: StringName = ctrl.view()["opponent"]["area"]
	assert_true(rival_area != &"", "rival dropped first")
	# The Core is refused in words.
	await _touch_area(m, &"old_town")
	await _touch_dock(m, &"drop")
	assert_true("Core" in m.last_notice, "Core drop refused: '%s'" % m.last_notice)
	assert_eq(String(ctrl.view()["me"]["area"]), "", "still not dropped")
	await _touch_area(m, &"rail_yard")
	await _touch_dock(m, &"drop")
	assert_eq(String(ctrl.view()["me"]["area"]), "rail_yard", "dropped into Rail Yard")
	assert_eq(ctrl.phase, &"act", "turn 1 starts")
	assert_true(_saved_step() == ctrl.state.actions.size(), "saved after the drop (step %d)" % _saved_step())
	var hand: Array = _names(m, &"hand")
	assert_eq(hand, ["Scavenge", "Scavenge", "Scavenge", "Duck", "Dash"], "Standard pack turn 1 hand")
	# Illegal: move with no Move yet.
	await _touch_area(m, &"motel")
	await _touch_dock(m, &"move")
	assert_true("No Move left" in m.last_notice, "move without Move explained: '%s'" % m.last_notice)
	await _touch_dock(m, &"close")
	# Play three Scavenge and the Dash.
	for i: int in 3:
		await _touch_card(m, &"hand", 0)
		assert_true(m.get_dock_keys().has(&"play"), "hand card offers PLAY")
		await _touch_dock(m, &"play")
	await _touch_card(m, &"hand", 1)  # Dash (Duck is index 0 now)
	assert_true("DASH" in m.get_dock_title(), "Dash selected: %s" % m.get_dock_title())
	await _touch_dock(m, &"play")
	var me: Dictionary = ctrl.view()["me"]
	assert_eq([int(me["move"]), int(me["search"])], [1, 3], "pools after the plays")
	assert_eq(m.get_pools_label().text, "MOVE 1\nSEARCH 3", "pools shown on the map corner")
	assert_eq(m.get_cards(&"line").size(), 4, "4 line chips")
	# Not adjacent: Quarry is 2 away from Rail Yard.
	await _touch_area(m, &"quarry")
	await _touch_dock(m, &"move")
	assert_true("2 areas away" in m.last_notice, "far move explained: '%s'" % m.last_notice)
	await _touch_dock(m, &"close")
	# Move to Motel, undo it.
	await _touch_area(m, &"motel")
	await _touch_dock(m, &"move")
	assert_eq(String(ctrl.view()["me"]["area"]), "motel", "moved to Motel")
	await _touch(m.get_corner_buttons()[&"undo"])
	assert_eq(String(ctrl.view()["me"]["area"]), "rail_yard", "UNDO restores Rail Yard")
	assert_eq(int(ctrl.view()["me"]["move"]), 1, "UNDO gives the Move back")
	assert_eq(ctrl.undo_count, 1, "undo counted")
	assert_true(_saved_step() == ctrl.state.actions.size(), "saved after the undo too")
	# Loot from the sheet: Crowbar costs 2.
	await _touch_area(m, &"rail_yard")
	assert_true(m.get_dock_keys().has(&"loot"), "own area offers LOOT")
	await _touch_dock(m, &"loot")
	assert_true(m.is_sheet_open(), "loot sheet opens")
	assert_true(m.get_sheet_title().begins_with("LOOT"), "sheet title %s" % m.get_sheet_title())
	var red_dot: Button = m.get_sheet_button(&"loot_red_dot_sight")
	var crowbar: Button = m.get_sheet_button(&"loot_crowbar")
	assert_not_null(crowbar, "Crowbar pile listed")
	await _touch(crowbar)
	assert_false(m.is_sheet_open(), "sheet closes after the loot")
	assert_eq(int(ctrl.view()["me"]["search"]), 1, "Search 3 - 2")
	assert_eq(String(m.get_cards(&"line").back().card_id), "crowbar", "Crowbar in the line")
	# Not enough Search for the Red Dot Sight (2).
	await _touch_area(m, &"rail_yard")
	await _touch_dock(m, &"loot")
	red_dot = m.get_sheet_button(&"loot_red_dot_sight")
	assert_not_null(red_dot, "Red Dot pile listed")
	await _touch(red_dot)
	assert_true("Not enough Search" in m.get_sheet_text(), "short Search explained in the sheet: '%s'" % m.get_sheet_text())
	await _touch(m.get_node("Sheet").find_child("SheetClose", true, false))
	assert_false(m.is_sheet_open(), "CLOSE closes the sheet")
	# Pack: hold Duck (2 limit), a 3rd card is refused, End turn.
	await _touch(m.get_corner_buttons()[&"end_turn"])
	assert_eq(m.mode, &"pack", "END TURN opens Pack")
	assert_true(m.get_dock_title().begins_with("PACK"), "Pack dock %s" % m.get_dock_title())
	await _touch_card(m, &"hand", 0)
	assert_eq(m.hold_set.size(), 1, "Duck marked to hold")
	assert_true((m.get_cards(&"hand")[0] as CzCard).held, "HOLD tag on the card")
	await _touch_card(m, &"hand", 0)
	assert_eq(m.hold_set.size(), 0, "tap again lets it go")
	await _touch_card(m, &"hand", 0)
	await _touch_dock(m, &"end_turn")
	# The placeholder rival plays its whole turn; round 2 starts with the held Duck on top.
	assert_eq(ctrl.phase, &"act", "back to the human after the rival's turn")
	assert_eq(int(ctrl.view()["round"]), 2, "round 2")
	assert_eq(_names(m, &"hand")[0], "Duck", "held Duck drawn first")
	assert_true(ctrl.log_lines.size() > 10, "events logged (%d)" % ctrl.log_lines.size())
	_despawn(m)


# --- Shot preview -----------------------------------------------------------------------

func test_shot_preview_then_fire_and_no_undo_past_it() -> void:
	var m: Control = await _spawn(_fixture({
		"P1": {"area": "radio_hill", "health": 5, "hand": ["hunting_rifle", "scavenge"], "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]},
		"P2": {"area": "quarry", "health": 4, "loadout": ["duck", "plate_vest", "scavenge", "dash", "scavenge", "dash"]}}))
	var ctrl: Node = m.get_controller()
	await _touch_card(m, &"hand", 0)
	await _touch_dock(m, &"play")
	await _touch_card(m, &"line", 0)
	assert_true(m.get_dock_keys().has(&"fire"), "line weapon offers FIRE")
	var weapon: int = int(ctrl.view()["me"]["line"][0]["id"])
	var p: Dictionary = LoadoutRules.preview_shot(ctrl.state, 0, weapon, 1)
	var text: String = m.get_dock_text()
	var want: String = "DMG %d − Cover %d − Down %d = %d damage" % [int(p["dmg"]), int(p["cover"]), int(p["down"]), int(p["damage"])]
	assert_true(want in text, "preview '%s' shows '%s'" % [text, want])
	assert_true("Quarry" in text and "They may Brace" in text, "preview names the area and the Brace chance")
	assert_eq(int(p["damage"]), 1, "DMG 2 - Cover 1 (Quarry) = 1")
	var health_before: int = int(ctrl.view()["opponent"]["health"])
	await _touch_dock(m, &"fire")
	assert_eq(ctrl.phase, &"act", "back to the human after the rival's (empty) Brace")
	var log: String = "\n".join(ctrl.log_lines)
	assert_true("You fired Hunting Rifle: 1 damage." in log, "shot announced")
	assert_eq(int(ctrl.view()["opponent"]["health"]), health_before - 1, "1 Hit landed")
	# Undo stops at a declared shot.
	await _touch(m.get_corner_buttons()[&"undo"])
	assert_true("declared shot" in m.last_notice, "undo past a shot explained: '%s'" % m.last_notice)
	# A weapon fires once.
	await _touch_card(m, &"line", 0)
	assert_true("FIRED" in (m.get_cards(&"line")[0] as Button).text, "chip marked FIRED")
	await _touch_dock(m, &"fire")
	assert_true("already fired" in m.last_notice, "second shot explained: '%s'" % m.last_notice)
	_despawn(m)


func test_out_of_range_preview_explains() -> void:
	var m: Control = await _spawn(_fixture({
		"P1": {"area": "docks", "health": 5, "line": ["p9_sidearm"], "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]},
		"P2": {"area": "radio_hill", "health": 5, "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]}}))
	await _touch_card(m, &"line", 0)
	assert_true("Out of range" in m.get_dock_text(), "preview says out of range: '%s'" % m.get_dock_text())
	await _touch_dock(m, &"fire")
	assert_true("Out of range" in m.last_notice and "reaches 0" in m.last_notice, "FIRE refused in words: '%s'" % m.last_notice)
	_despawn(m)


# --- Adrenaline, patch up, ditch, attach, Frag ---------------------------------------------

func test_adrenaline_patch_up_and_ditch() -> void:
	var m: Control = await _spawn(_fixture({
		"P1": {"area": "motel", "health": 3, "hand": ["hit", "hit", "scavenge", "scavenge", "dash"], "loadout": ["duck", "dash", "scavenge", "scavenge", "dash", "duck", "p9_sidearm"]},
		"P2": {"area": "docks", "health": 5, "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]}}))
	var ctrl: Node = m.get_controller()
	await _touch_card(m, &"hand", 0)
	assert_eq(m.get_dock_keys(), [&"adrenaline_move", &"adrenaline_search", &"patch_up", &"close"], "a Hit asks Move or Search")
	await _touch_dock(m, &"patch_up")
	assert_true("costs 2, you have 0" in m.last_notice, "patch up without Search explained: '%s'" % m.last_notice)
	await _touch_dock(m, &"adrenaline_move")
	assert_eq(int(ctrl.view()["me"]["move"]), 1, "Adrenaline: Move +1")
	await _touch_card(m, &"hand", 0)
	await _touch_dock(m, &"adrenaline_search")
	assert_eq(int(ctrl.view()["me"]["search"]), 1, "Adrenaline: Search +1")
	for i: int in 2:
		await _touch_card(m, &"hand", 0)
		await _touch_dock(m, &"play")
	assert_eq(int(ctrl.view()["me"]["search"]), 3, "Search 3")
	# Patch up from the Hit chip in the line.
	await _touch_card(m, &"line", 0)
	assert_true(m.get_dock_keys().has(&"patch_up"), "a Hit in the line offers PATCH UP")
	await _touch_dock(m, &"patch_up")
	assert_eq(int(ctrl.view()["me"]["health"]), 4, "patched up 3 -> 4")
	# Ditch the Dash (Search 1).
	await _touch_card(m, &"hand", 0)
	assert_true("DASH" in m.get_dock_title(), "Dash selected")
	await _touch_dock(m, &"ditch")
	assert_eq(int(ctrl.view()["me"]["ditched"]), 1, "ditched")
	assert_eq(int(ctrl.view()["me"]["hand_count"]), 0, "hand empty")
	_despawn(m)


func test_attach_direct_and_by_sheet_and_frag_throw() -> void:
	var m: Control = await _spawn(_fixture({
		"P1": {"area": "farmstead", "health": 5, "hand": ["red_dot_sight", "hunting_rifle", "scrap_smg", "long_scope", "frag_grenade"], "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]},
		"P2": {"area": "quarry", "health": 5, "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]}}))
	var ctrl: Node = m.get_controller()
	# Two weapons: ATTACH… opens a sheet.
	await _touch_card(m, &"hand", 0)
	await _touch_dock(m, &"attach")
	assert_true(m.is_sheet_open() and m.get_sheet_buttons().size() == 2, "attach sheet lists 2 weapons")
	await _touch(m.get_sheet_buttons()[0])
	var rifle: Dictionary = {}
	for c: Dictionary in ctrl.view()["me"]["hand"]:
		if c["card"] == &"hunting_rifle":
			rifle = c
	assert_eq(rifle.get("attachments", []), [&"red_dot_sight"], "Red Dot on the rifle")
	# Play the SMG away: one weapon left in hand, Long Scope attaches directly.
	await _touch_card(m, &"hand", _index_of(m, &"hand", "Scrap SMG"))
	await _touch_dock(m, &"play")
	await _touch_card(m, &"hand", _index_of(m, &"hand", "Long Scope"))
	await _touch_dock(m, &"attach")
	assert_true(m.is_sheet_open(), "still two weapons (hand + line): sheet")
	await _touch(m.get_sheet_button(StringName("attach_%d" % int(rifle["id"]))))
	assert_eq(ctrl.state.attachments_of(int(rifle["id"])).size(), 2, "two attachments on the rifle")
	# Frag: THROW, a far area is refused, the rival's area works.
	await _touch_card(m, &"hand", _index_of(m, &"hand", "Frag Grenade"))
	await _touch_dock(m, &"throw")
	assert_eq(m.mode, &"aim", "aim mode")
	await _touch_area(m, &"motel")
	assert_true("Frag" in m.last_notice and "reaches 1" in m.last_notice, "far throw explained: '%s'" % m.last_notice)
	await _touch_area(m, &"quarry")
	assert_true("You threw a Frag into Quarry." in "\n".join(ctrl.log_lines), "Frag thrown")
	assert_eq(m.mode, &"act", "aim mode ends")
	_despawn(m)


# --- Brace ----------------------------------------------------------------------------------

func test_brace_prompt_choose_and_confirm() -> void:
	var s: MatchState = _fixture({"active": "P2",
		"P1": {"area": "rail_yard", "health": 5, "loadout": ["scavenge", "duck", "plate_vest", "dash", "scavenge", "dash", "duck"]},
		"P2": {"area": "docks", "health": 5, "line": ["pump_shotgun", "hunting_rifle"], "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]}})
	var m: Control = await _spawn(s, Shooter.new())
	var ctrl: Node = m.get_controller()
	assert_eq(ctrl.phase, &"brace", "the rival's shot asks the human to brace")
	assert_eq(m.mode, &"brace", "brace mode")
	var dmg: int = int(ctrl.view()["brace_prompt"]["damage"])
	assert_eq(dmg, 2, "Hunting Rifle DMG 2 into Rail Yard (no Cover); the shotgun (range 0) can't reach")
	assert_true(m.get_dock_title() == "BRACE · %d DAMAGE INCOMING" % dmg, "brace dock %s" % m.get_dock_title())
	# Scavenge (top of the strip) has no Brace value.
	await _touch_card(m, &"next", 0)
	assert_true("no Brace value" in m.last_notice, "Scavenge refused: '%s'" % m.last_notice)
	await _touch(m.get_corner_buttons()[&"end_turn"])
	assert_true("Brace first" in m.last_notice, "END TURN during Brace explained")
	await _touch_card(m, &"next", 1)  # Duck, Brace 1
	await _touch_card(m, &"next", 2)  # Plate Vest, Brace 2
	assert_eq(m.brace_set.size(), 2, "two brace cards chosen")
	assert_true("0 Hits land" in m.get_dock_text(), "dock sums the Brace: '%s'" % m.get_dock_text())
	await _touch_dock(m, &"brace")
	var log: String = "\n".join(ctrl.log_lines)
	assert_true("You braced with Duck, Plate Vest (Brace 3): 0 Hits." in log, "brace announced:\n%s" % log)
	assert_eq(int(ctrl.view()["me"]["health"]), 5, "no Hit landed")
	_despawn(m)


# --- Menu, concede, end, saves --------------------------------------------------------------

func test_concede_from_menu_clears_the_save() -> void:
	var m: Control = await _spawn(null)
	var ctrl: Node = m.get_controller()
	await _touch_area(m, &"docks")
	await _touch_dock(m, &"drop")
	assert_true(MatchStore.has_saved_match(), "a save exists mid-match")
	var info: Dictionary = MatchStore.saved_info()
	assert_eq(int(info["meta"].get("human_seat", -1)), 0, "meta human_seat saved")
	# Resume from the save: the same state.
	var resumed: Dictionary = MatchStore.resume()
	assert_eq((resumed["state"] as MatchState).fingerprint(), ctrl.state.fingerprint(), "the save resumes to the same state")
	await _touch(m.get_node("%MenuButton"))
	assert_eq(m.get_sheet_title(), "MENU", "MENU sheet")
	await _touch(m.get_sheet_button(&"resume"))
	assert_false(m.is_sheet_open(), "RESUME closes it")
	await _touch(m.get_node("%MenuButton"))
	await _touch(m.get_sheet_button(&"concede"))
	assert_eq(m.get_sheet_title(), "CONCEDE?", "concede asks to confirm")
	await _touch(m.get_sheet_button(&"concede_yes"))
	assert_eq(ctrl.phase, &"over", "match over")
	assert_eq(m.get_sheet_title(), "THE RIVAL WINS", "end sheet")
	assert_true("concession" in m.get_sheet_text(), "end text gives the cause")
	assert_false(MatchStore.has_saved_match(), "concede clears the save")
	assert_not_null(m.get_sheet_button(&"new_match"), "NEW MATCH offered")
	_despawn(m)


func test_start_from_a_resumed_match() -> void:
	var m: Control = await _spawn(null)
	var ctrl: Node = m.get_controller()
	await _touch_area(m, &"motel")
	await _touch_dock(m, &"drop")
	await _touch_card(m, &"hand", 0)
	await _touch_dock(m, &"play")
	var print_before: String = ctrl.state.fingerprint()
	var resumed: Dictionary = MatchStore.resume()
	assert_true(ctrl.start_resumed(resumed), "controller starts from MatchStore.resume()")
	assert_eq(ctrl.state.fingerprint(), print_before, "resumed state equals the saved one")
	assert_eq(ctrl.phase, &"act", "resumed at the human's turn")
	await _touch(m.get_corner_buttons()[&"undo"])
	assert_eq(int(ctrl.view()["me"]["search"]), 0, "undo history survives the resume")
	_despawn(m)


# --- Illegal taps, events, pacing ------------------------------------------------------------

func test_rival_turn_taps_explain_and_events_are_paced() -> void:
	var m: Control = await _spawn(_fixture({
		"P1": {"area": "motel", "health": 5, "hand": ["scavenge", "duck"], "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]},
		"P2": {"area": "docks", "health": 5, "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]}}))
	var ctrl: Node = m.get_controller()
	ctrl.event_delay = 0.05
	ctrl.opponent_delay = 0.05
	var shown: Array = []
	ctrl.event_shown.connect(func(text: String, e: Dictionary) -> void: shown.append([Time.get_ticks_msec(), text, e]))
	# Hold a Hit? No: hold limit and Hit rules via the controller.
	await _touch(m.get_corner_buttons()[&"end_turn"])
	await _touch_card(m, &"hand", 0)
	await _touch_card(m, &"hand", 1)
	assert_eq(m.hold_set.size(), 2, "two held")
	await _touch_dock(m, &"end_turn")
	assert_true(ctrl.busy, "events play out over time with a delay")
	assert_eq(ctrl.phase, &"opponent", "rival's turn")
	await _touch_card(m, &"next", 0)
	assert_true("rival's turn" in m.last_notice, "tap during the rival's turn explained: '%s'" % m.last_notice)
	await _touch(m.get_corner_buttons()[&"undo"])
	assert_true(m.last_notice != "", "undo during the rival's turn explained: '%s'" % m.last_notice)
	var guard: int = 0
	while ctrl.busy and guard < 600:
		guard += 1
		await tree.process_frame
	assert_false(ctrl.busy, "the rival's turn finishes")
	assert_true(shown.size() >= 5, "events shown (%d)" % shown.size())
	var gaps: Array = []
	for i: int in range(1, shown.size()):
		gaps.append(int(shown[i][0]) - int(shown[i - 1][0]))
	# SceneTreeTimer counts frame deltas, so one gap can be short; the whole run can't.
	var total: int = 0
	for g: int in gaps:
		total += g
	assert_true(gaps.all(func(g: int) -> bool: return g >= 15) and total >= int(0.8 * 50.0 * gaps.size()),
			"events paced about the delay apart: %s %s" % [gaps, shown.map(func(x: Array) -> String: return x[1])])
	# Order: the shown events are exactly the engine's, filtered, in order.
	var types: Array = shown.map(func(x: Array) -> String: return String(x[2]["type"]))
	assert_true(types.find("packed") < types.find("turn_started"), "packed before the rival's turn_started: %s" % [types])
	assert_true(m.get_toast_text() != "", "the toast shows the latest event")
	_despawn(m)


func test_hold_limit_and_hit_hold_explained() -> void:
	var m: Control = await _spawn(_fixture({
		"P1": {"area": "motel", "health": 4, "hand": ["hit", "scavenge", "duck", "dash"], "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]},
		"P2": {"area": "docks", "health": 5, "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]}}))
	await _touch(m.get_corner_buttons()[&"end_turn"])
	await _touch_card(m, &"hand", 0)
	assert_true("Hit is never held" in m.last_notice, "Hit hold explained: '%s'" % m.last_notice)
	assert_true((m.get_cards(&"hand")[0] as CzCard).dimmed, "the Hit is dimmed at Pack")
	for i: int in [1, 2, 3]:
		await _touch_card(m, &"hand", i)
	assert_eq(m.hold_set.size(), 2, "only 2 held")
	assert_true("at most 2" in m.last_notice, "3rd hold explained: '%s'" % m.last_notice)
	await _touch_dock(m, &"close")
	assert_eq(m.mode, &"act", "BACK leaves Pack")
	_despawn(m)


# --- Layout in the live modes ------------------------------------------------------------

func test_fan_focus_and_line_scroll_and_overlays_fit() -> void:
	var m: Control = await _spawn(_fixture({
		"P1": {"area": "old_town", "health": 5,
			"hand": ["hunting_rifle", "assault_rifle", "marksman_rifle", "recon_drone", "plate_vest", "smoke_grenade", "medkit"],
			"line": ["crowbar", "backpack", "dash", "trail_boots", "bandage", "scavenge", "duck", "scavenge"],
			"loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]},
		"P2": {"area": "docks", "health": 5, "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]}}))
	var safe: Rect2 = m.safe_area_override.grow(EPS)
	# Fan: the selected card opens to its full width.
	var cards: Array[Control] = m.get_cards(&"hand")
	var step_before: float = cards[2].get_global_rect().position.x - cards[1].get_global_rect().position.x
	assert_true(step_before < cards[1].size.x, "a crowded hand overlaps (step %.0f)" % step_before)
	await _touch_card(m, &"hand", 1)
	await tree.process_frame
	cards = m.get_cards(&"hand")
	var open: float = cards[2].get_global_rect().position.x - cards[1].get_global_rect().position.x
	assert_true(open >= cards[1].size.x - 1.0, "selected card fully visible (%.0f >= %.0f)" % [open, cards[1].size.x])
	for i: int in range(1, cards.size()):
		var st: float = cards[i].get_global_rect().position.x - cards[i - 1].get_global_rect().position.x
		assert_true(st >= 64.0 - EPS, "every card keeps >= 64 px exposed (%d: %.0f)" % [i, st])
	assert_true("ASSAULT RIFLE" in m.get_dock_title(), "dock names the selected card in full: %s" % m.get_dock_title())
	# Dock and its buttons inside the safe area, 64 px targets.
	var dock: Rect2 = m.get_dock().get_global_rect()
	assert_true(safe.encloses(dock), "dock %s inside the safe area %s" % [dock, safe])
	for key: StringName in m.get_dock_keys():
		var b: Button = m.get_dock_button(key)
		var r: Rect2 = b.get_global_rect()
		assert_true(minf(r.size.x, r.size.y) >= 64.0 - EPS and dock.grow(EPS).encloses(r), "dock button %s %s" % [key, r])
		assert_true(b.get_minimum_size().x <= r.size.x + EPS, "dock button %s text fits" % key)
	assert_true(m.get_dock().find_child("DockText", true, false).get_visible_line_count() >= 1, "dock text shows")
	# Line > 6: a scroll, header says how many more.
	var scroll: ScrollContainer = m.get_line_scroll()
	assert_true(m.get_node("%LineChips").size.y > scroll.size.y + 1.0, "8 chips overflow the 2 visible rows")
	assert_true("SCROLL FOR 2 MORE" in (m.get_node("%LineHeader") as Label).text, "header: %s" % (m.get_node("%LineHeader") as Label).text)
	# Map corners: on the map, clear of every tile, 64 px.
	var map: CzMap = m.get_map()
	for key: StringName in [&"undo", &"end_turn", &"log"]:
		var b: Button = m.get_corner_buttons()[key]
		var r: Rect2 = b.get_global_rect()
		assert_true(minf(r.size.x, r.size.y) >= 64.0 - EPS, "%s is a 64 px target" % key)
		assert_true(map.get_global_rect().grow(EPS).encloses(r), "%s on the map" % key)
		for t: CzAreaTile in map.tiles():
			assert_false(r.intersects(t.get_global_rect().grow(-EPS)), "%s clear of %s" % [key, t.area_id])
	_despawn(m)


# --- A whole match ----------------------------------------------------------------------

func test_full_match_touch_only() -> void:
	var m: Control = await _spawn(null)
	var ctrl: Node = m.get_controller()
	var seen: Dictionary = {}
	var guard: int = 0
	var turn_actions: int = 0
	var last_round: int = -1
	while ctrl.phase != &"over" and guard < 900:
		guard += 1
		var legal: Array[Dictionary] = ctrl.legal()
		if int(ctrl.view()["round"]) != last_round:
			last_round = int(ctrl.view()["round"])
			turn_actions = 0
		var a: Dictionary = _pick(ctrl, legal, turn_actions)
		turn_actions += 1
		var before: int = ctrl.state.actions.size()
		await _do_by_touch(m, a)
		seen[a["type"]] = true
		if ctrl.state.actions.size() == before and ctrl.phase != &"over":
			failures.append("touch did not apply %s (notice '%s')" % [a, m.last_notice])
			break
	assert_eq(ctrl.phase, &"over", "the match reaches its end by touch (%d decisions)" % guard)
	assert_true(m.get_sheet_title() in ["YOU WIN", "THE RIVAL WINS", "DRAW"], "end sheet: %s" % m.get_sheet_title())
	for t: String in ["drop", "play", "end_turn"]:
		assert_true(seen.has(t), "%s done by touch" % t)
	print("     full match: %d decisions, kinds %s, %s" % [guard, seen.keys(), ActionText.result_text(ctrl.view()["match_end"], 0)])
	assert_false(MatchStore.has_saved_match(), "the end clears the save")
	_despawn(m)


## Touch policy for the full match: shoot, loot the best affordable pile, play, move toward the
## rival, then end the turn (holding what may be held).
func _pick(ctrl: Node, legal: Array[Dictionary], n: int) -> Dictionary:
	var by: Dictionary = {}
	for a: Dictionary in legal:
		if not by.has(a["type"]):
			by[a["type"]] = []
		by[a["type"]].append(a)
	for t: String in ["drop", "brace", "shoot", "loot", "attach", "play"]:
		if by.has(t) and (n < 14 or t == "brace" or t == "drop"):
			if t == "brace":
				return by[t].back()  # every eligible card
			return by[t][0]
	if by.has("move") and n < 14:
		var me: Dictionary = ctrl.view()["me"]
		if int(me["search"]) == 0:
			return by["move"][0]
	var ends: Array = by.get("end_turn", [])
	return ends.back() if not ends.is_empty() else legal[0]


func _do_by_touch(m: Control, a: Dictionary) -> void:
	var ctrl: Node = m.get_controller()
	match String(a["type"]):
		"drop":
			await _touch_area(m, StringName(a["area"]))
			await _touch_dock(m, &"drop")
		"brace":
			var ids: Array = m.get_state()["you"]["next_ids"]
			for inst: Variant in a["cards"]:
				await _touch_card(m, &"next", ids.find(int(inst)))
			await _touch_dock(m, &"brace")
		"play":
			var i: int = (m.get_state()["you"]["hand_ids"] as Array).find(int(a["card"]))
			await _touch_card(m, &"hand", i)
			var key: StringName = &"play"
			if a.has("adrenaline"):
				key = &"adrenaline_move" if a["adrenaline"] == "move" else &"adrenaline_search"
			await _touch_dock(m, key)
		"move":
			await _touch_area(m, StringName(a["to"]))
			await _touch_dock(m, &"move")
		"loot":
			await _touch_area(m, StringName(ctrl.view()["me"]["area"]))
			await _touch_dock(m, &"loot")
			var key: StringName = StringName("loot_" + str(a["pile"])) if a.has("pile") else &""
			if key == &"":
				for b: Button in m.get_sheet_buttons():
					if String(b.get_meta(&"key")).ends_with("_%d" % int(a["card"])):
						key = b.get_meta(&"key")
			await _touch(m.get_sheet_button(key))
		"shoot":
			var line: Array = m.get_state()["you"]["line"]
			var idx: int = -1
			for i: int in line.size():
				if int(line[i]["id"]) == int(a["weapon"]):
					idx = i
			m.get_line_scroll().ensure_control_visible(m.get_cards(&"line")[idx])
			await tree.process_frame
			await _touch_card(m, &"line", idx)
			await _touch_dock(m, &"fire")
		"attach":
			var att: int = int(a["attachment"])
			var hi: int = (m.get_state()["you"]["hand_ids"] as Array).find(att)
			if hi >= 0:
				await _touch_card(m, &"hand", hi)
			else:
				var line: Array = m.get_state()["you"]["line"]
				for i: int in line.size():
					if int(line[i]["id"]) == att:
						m.get_line_scroll().ensure_control_visible(m.get_cards(&"line")[i])
						await tree.process_frame
						await _touch_card(m, &"line", i)
			await _touch_dock(m, &"attach")
			if m.is_sheet_open():
				await _touch(m.get_sheet_button(StringName("attach_%d" % int(a["weapon"]))))
		"end_turn":
			await _touch(m.get_corner_buttons()[&"end_turn"])
			var ids: Array = m.get_state()["you"]["hand_ids"]
			for inst: Variant in a.get("hold", []):
				await _touch_card(m, &"hand", ids.find(int(inst)))
			await _touch_dock(m, &"end_turn")
		_:
			failures.append("no touch path for %s" % a)


# --- Helpers ----------------------------------------------------------------------------

func _fixture(players: Dictionary) -> MatchState:
	var setup: Dictionary = {"round": 3, "zone_card": 3, "route": "A", "active": players.get("active", "P1"),
			"piles": {"rail_yard": {"crowbar": 3, "red_dot_sight": 3}, "old_town": {"assault_rifle": 2}},
			"players": {"P1": players["P1"], "P2": players["P2"]}}
	var errors: Array = []
	var s: MatchState = MatchState.from_fixture(setup, RulesData.from_card_db(CardDB), {}, errors)
	if not errors.is_empty():
		failures.append("fixture errors: %s" % [errors])
	return s


func _spawn(state: MatchState, opponent: Object = null) -> Control:
	_saved_root_size = tree.root.size
	_saved_scale_mode = tree.root.content_scale_mode
	var px: Vector2 = PHONE["pt"] * PHONE["ratio"]
	var logical: Vector2 = ScreenProfile.logical_size(px, ScreenProfile.base_size(px, PHONE["ratio"]))
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	tree.root.size = Vector2i(logical)
	await tree.process_frame
	MatchStore.clear()
	var m: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
	m.auto_start = false
	var k: float = ScreenProfile.points_per_px(px, PHONE["ratio"])
	var insets: Rect2 = PHONE["insets"]
	m.points_per_px_override = k
	m.safe_area_override = Rect2(insets.position / k, logical - insets.position / k - insets.size / k)
	var ctrl: Node = m.get_node("%MatchController")
	ctrl.event_delay = 0.0
	ctrl.opponent_delay = 0.0
	if opponent != null:
		ctrl.opponent = opponent
	tree.root.add_child(m)
	for i: int in 3:
		await tree.process_frame
	m.start_live(state)
	for i: int in 3:
		await tree.process_frame
	return m


func _despawn(m: Control) -> void:
	MatchStore.clear()
	m.queue_free()
	tree.root.size = _saved_root_size
	tree.root.content_scale_mode = _saved_scale_mode


func _saved_step() -> int:
	var info: Dictionary = MatchStore.saved_info()
	return int(info.get("step", -1)) if info.get("has_match", false) else -1


## A real touch (press + release) at a point inside the control that no later sibling covers.
func _touch(c: Control) -> void:
	if c == null or not c.is_visible_in_tree():
		failures.append("touch on a missing or hidden control (%s)" % c)
		return
	await _touch_at(_exposed_point(c))


func _touch_at(pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		var t: InputEventScreenTouch = InputEventScreenTouch.new()
		t.index = 0
		t.pressed = pressed
		t.position = pos
		Input.parse_input_event(t)
		Input.flush_buffered_events()
	await tree.process_frame


func _exposed_point(c: Control) -> Vector2:
	var r: Rect2 = c.get_global_rect()
	var parent: Node = c.get_parent()
	if c is CzCard and parent != null:
		var i: int = c.get_index()
		if i + 1 < parent.get_child_count():
			var nxt: Control = parent.get_child(i + 1)
			var right: float = minf(r.end.x, nxt.get_global_rect().position.x)
			return Vector2((r.position.x + right) * 0.5, r.get_center().y)
	return r.get_center()


func _touch_card(m: Control, zone: StringName, index: int) -> void:
	var cards: Array[Control] = m.get_cards(zone)
	if index < 0 or index >= cards.size():
		failures.append("no %s card %d (have %d)" % [zone, index, cards.size()])
		return
	await _touch(cards[index])


func _touch_area(m: Control, area: StringName) -> void:
	await _touch(m.get_area_touch(area))


func _touch_dock(m: Control, key: StringName) -> void:
	var b: Button = m.get_dock_button(key)
	if b == null:
		failures.append("dock has no %s (keys %s, title '%s', notice '%s')" % [key, m.get_dock_keys(), m.get_dock_title(), m.last_notice])
		return
	await _touch(b)


func _names(m: Control, zone: StringName) -> Array:
	var out: Array = []
	for c: Control in m.get_cards(zone):
		out.append(CardDB.get_card(c.get_meta(&"card_id")).display_name)
	return out


func _index_of(m: Control, zone: StringName, card_name: String) -> int:
	return _names(m, zone).find(card_name)

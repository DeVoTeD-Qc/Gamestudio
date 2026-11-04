# test_hub.gd
# Purpose: cc13 hub (scenes/Hub.tscn) and routing:
#   - every hub button routes where it should (SceneRouter dry run), rival buttons hand the saved
#     lineup to DuelController.set_next_duel, Dossiers opens the list,
#   - CONTINUE shows only while Collection holds a saved Lobby Duel,
#   - the progress line reads Collection (cards x / 20, sets, Dossiers),
#   - the Title's buttons go to the hub and the Lobby Duel; after the hub, "back to the Title"
#     resolves to the hub,
#   - the saved Signature reaches the duel (duel_setup.gd) when the lineup is the saved one,
#   - layout at 844x390 (notch) and 1280x720: 44 pt / 64 px targets, 11 pt text, safe area,
#   - generic wording: no franchise / brand / mode names in any cc13 scene or script.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const Fx: GDScript = preload("res://tests/test_collection_fixtures.gd")
const Lx: GDScript = preload("res://tests/test_lobby_fixtures.gd")
const HUB_SCENE: String = "res://scenes/Hub.tscn"
const DuelControllerScript: GDScript = preload("res://scripts/duel/duel_controller.gd")
const DossierControllerScript: GDScript = preload("res://scripts/dossier/dossier_controller.gd")
const LobbyDuelScript: GDScript = preload("res://scripts/lobby/lobby_duel.gd")
const DuelSetup: GDScript = preload("res://scripts/duel/duel_setup.gd")

## cc13 files checked for brand words (Title.tscn / title.gd carry the required legal disclaimer,
## which must name the brand it disclaims, so they are not in this list).
const OWNED_FILES: Array[String] = [
	"res://scenes/Hub.tscn", "res://scenes/LobbyDuel.tscn", "res://scenes/LobbyMatchStarting.tscn",
	"res://scripts/hub/hub.gd", "res://scripts/hub/hub_ui.gd", "res://scripts/lobby/lobby_duel.gd",
	"res://scripts/lobby/lobby_match_starting.gd", "res://autoload/scene_router.gd",
	"res://scripts/duel/duel_setup.gd", "res://tests/test_lobby_duel.gd", "res://tests/test_lobby_fixtures.gd",
]
## Case-insensitive phrases, plus the abbreviation checked case-sensitively as a whole word.
const DENYLIST: Array[String] = ["call of duty", "activision", "warzone", "black ops", "modern warfare",
		"treyarch", "infinity ward", "multiplayer", "battle royale", "ranked play", "prestige"]


func _hub(fx: RefCounted, col: Node, lx: RefCounted, screen: Dictionary = Lx.PHONE) -> Control:
	var hub: Control = (load(HUB_SCENE) as PackedScene).instantiate()
	hub.collection = col
	return await lx.spawn(hub, screen)


func test_hub_routes() -> void:
	var fx: RefCounted = Fx.new(tree)
	var lx: RefCounted = Lx.new(tree)
	var col: Node = fx.make("hub_routes")
	var hub: Control = await _hub(fx, col, lx)
	var router: Node = lx.router()
	assert_true(router.hub_entered, "entering the hub is remembered")
	var cases: Array = [[&"lineup", router.SCENE_LINEUP], [&"dossier", router.SCENE_DOSSIER], [&"lobby", router.SCENE_LOBBY]]
	if ResourceLoader.exists(router.SCENE_ALBUM):
		cases.append([&"album", router.SCENE_ALBUM])
	for c: Array in cases:
		router.last_requested = ""
		var b: Button = hub.get_button(c[0])
		assert_true(b != null and not b.disabled, "%s button enabled" % c[0])
		b.pressed.emit()
		assert_eq(router.last_requested, c[1], "%s routes" % c[0])
	assert_eq(LobbyDuelScript.next_mode, LobbyDuelScript.MODE_WAIT, "FIND A MATCH opens the wait")
	DossierControllerScript.set_next_dossier(&"d3")
	router.last_requested = ""
	hub.get_button(&"dossier").pressed.emit()
	assert_eq(DossierControllerScript.next_dossier_id, &"", "Dossiers opens the list")
	# Rival buttons: one per rival, each hands its id (and the loaner: nothing saved) to the duel.
	var rivals: Array[Dictionary] = DuelSetup.rivals()
	assert_eq(rivals.size(), 3, "three rivals")
	for r: Dictionary in rivals:
		router.last_requested = ""
		var b: Button = hub.get_rival_button(r["id"])
		assert_not_null(b, "button for %s" % r["name"])
		if b == null:
			continue
		b.pressed.emit()
		assert_eq(router.last_requested, router.SCENE_DUEL, "%s routes to the duel" % r["name"])
		assert_eq(DuelControllerScript.next_rival_id, r["id"], "%s chosen" % r["name"])
		assert_eq(DuelControllerScript.next_player_lineup, [], "no saved lineup -> loaner")
	# A saved lineup goes with the rival choice.
	var ids: Array = fx.loaner_ids()
	col.save_lineup(ids, ids[1], true)
	hub.get_rival_button(&"warden").pressed.emit()
	assert_eq(DuelControllerScript.next_player_lineup, ids, "saved lineup handed to the duel")
	DuelControllerScript.set_next_duel(&"", [])
	await lx.finish()
	fx.finish()


func test_album_button_follows_the_scene() -> void:
	var fx: RefCounted = Fx.new(tree)
	var lx: RefCounted = Lx.new(tree)
	var hub: Control = await _hub(fx, fx.make("hub_album"), lx)
	var b: Button = hub.get_button(&"album")
	var exists: bool = ResourceLoader.exists("res://scenes/Album.tscn")
	assert_eq(b.disabled, not exists, "ALBUM enabled exactly when scenes/Album.tscn exists")
	await lx.finish()
	fx.finish()


func test_continue_only_with_a_saved_lobby_duel() -> void:
	var fx: RefCounted = Fx.new(tree)
	var lx: RefCounted = Lx.new(tree)
	var col: Node = fx.make("hub_continue")
	var hub: Control = await _hub(fx, col, lx)
	assert_false(hub.continue_visible(), "no save: no CONTINUE")
	var router: Node = lx.router()
	router.last_requested = ""
	hub.continue_lobby_duel()
	assert_eq(router.last_requested, "", "CONTINUE without a save goes nowhere")
	# Save a duel in progress: the button appears at once (lobby_duel_saved).
	var state: WallState = _mid_state(3)
	assert_true(col.save_lobby_duel(state, {"rival_id": &"archivist", "lineup": fx.loaner_ids(),
			"signature": fx.loaner_ids()[0]}), "saved")
	await lx.frames(1)
	assert_true(hub.continue_visible(), "save: CONTINUE shown")
	var info: Label = hub.find_child("ContinueInfo", true, false)
	assert_true(info.text.contains("Archivist") and info.text.contains("3 of 10"), "saved duel described: %s" % info.text)
	hub.get_button(&"continue").pressed.emit()
	assert_eq(router.last_requested, router.SCENE_LOBBY, "CONTINUE opens the Lobby Duel")
	assert_eq(LobbyDuelScript.next_mode, LobbyDuelScript.MODE_RESUME, "in resume mode")
	LobbyDuelScript.set_mode(LobbyDuelScript.MODE_WAIT)
	col.clear_lobby_duel()
	await lx.frames(1)
	assert_false(hub.continue_visible(), "cleared: CONTINUE gone")
	await lx.finish()
	fx.finish()


func test_progress_line_reads_the_collection() -> void:
	var fx: RefCounted = Fx.new(tree)
	var lx: RefCounted = Lx.new(tree)
	var col: Node = fx.make("hub_progress")
	var hub: Control = await _hub(fx, col, lx)
	var p: Dictionary = hub.progress()
	assert_eq(p["cards_owned"], fx.db().starting_cards().size(), "demo start cards")
	assert_eq(p["cards_total"], 20, "20 cards")
	assert_eq(p["dossiers_total"], fx.db().all_dossiers().size(), "Dossier total from data")
	var label: Label = hub.find_child("ProgressLabel", true, false)
	assert_true(label.text.contains("Cards %d / 20" % p["cards_owned"]), "line: %s" % label.text)
	var d: DossierData = fx.db().all_dossiers()[0]
	col.record_dossier_clear(d.id, 1, 30.0)
	await lx.frames(1)
	assert_eq(hub.progress()["dossiers_cleared"], 1, "a cleared Dossier counts")
	assert_true(label.text.contains("Dossiers 1 / "), "line refreshed: %s" % label.text)
	await lx.finish()
	fx.finish()


func test_title_routes_to_hub_and_lobby() -> void:
	var lx: RefCounted = Lx.new(tree)
	var router: Node = lx.router()
	var title: Control = (load("res://scenes/Title.tscn") as PackedScene).instantiate()
	await lx.spawn(title, Lx.DESKTOP)
	(title.get_node("%StartButton") as Button).pressed.emit()
	assert_eq(router.last_requested, router.SCENE_HUB, "ENTER THE WALL opens the hub")
	(title.get_node("%LobbyButton") as Button).pressed.emit()
	assert_eq(router.last_requested, router.SCENE_LOBBY, "FIND A MATCH opens the Lobby Duel")
	var was: bool = router.hub_entered
	router.hub_entered = false
	assert_eq(router.resolve(router.SCENE_TITLE), router.SCENE_TITLE, "cold start: the Title")
	router.hub_entered = true
	assert_eq(router.resolve(router.SCENE_TITLE), router.SCENE_HUB, "after the hub: back lands on the hub")
	assert_eq(router.resolve(router.SCENE_DUEL), router.SCENE_DUEL, "other scenes unchanged")
	router.hub_entered = was
	for route: StringName in [&"hub", &"duel", &"lineup", &"dossier", &"lobby", &"match_starting", &"title"]:
		assert_true(router.has_route(route), "route %s has a scene" % route)
	await lx.finish()


func test_saved_signature_reaches_the_duel() -> void:
	var fx: RefCounted = Fx.new(tree)
	var auto: Node = tree.root.get_node("Collection")
	var before: Dictionary = auto.get_saved_lineup_ids()
	var was_autosave: bool = auto.autosave
	auto.autosave = false
	var ids: Array = fx.loaner_ids()
	var cards: Array[CardData] = []
	for id: StringName in ids:
		cards.append(fx.db().get_card(id))
	var default_sig: CardData = DuelSetup.default_signature(cards)
	var pick: StringName = &""
	for c: CardData in cards:
		if c != default_sig and c.signature_eligible:
			pick = c.id
	assert_true(pick != &"", "a non-default Signature exists in the loaner lineup")
	assert_true(auto.save_lineup(ids, pick, true)["valid"], "lineup saved with its Signature")
	var p: Dictionary = DuelSetup.player_lineup(ids)
	assert_eq((p["signature"] as CardData).id, pick, "saved Signature used for the saved lineup")
	var reversed: Array = ids.duplicate()
	reversed.reverse()
	assert_eq((DuelSetup.player_lineup(reversed)["signature"] as CardData).id, pick, "order doesn't matter")
	# A different lineup falls back to the default rule.
	var other: Array = ids.duplicate()
	var spare: StringName = &""
	for c: CardData in fx.db().starting_cards():
		if not ids.has(c.id) and c.clearance == fx.db().get_card(ids[0]).clearance:
			spare = c.id
	if spare != &"":
		other[0] = spare
		var q: Dictionary = DuelSetup.player_lineup(other)
		assert_true((q["signature"] as CardData).id != pick or not other.has(pick), "other lineup: default Signature rule")
	# The duel controller picks it up through set_next_duel.
	var lx: RefCounted = Lx.new(tree)
	DuelControllerScript.set_next_duel(&"archivist", ids)
	var duel: Control = (load("res://scenes/Duel.tscn") as PackedScene).instantiate()
	var ctrl: Node = duel.get_node("%DuelController")
	ctrl.event_delay = 0.0
	ctrl.rival_delay = 0.0
	await lx.spawn(duel, Lx.DESKTOP)
	assert_eq(ctrl.player_signature.id, pick, "duel setup preselects the saved Signature")
	DuelControllerScript.set_next_duel(&"", [])
	await lx.finish()
	if before.is_empty():
		auto.clear_lineup()
	else:
		auto.save_lineup(before["cards"], before["signature"], before["loaner"])
	auto.autosave = was_autosave
	fx.finish()


func test_hub_layout_phone_and_desktop() -> void:
	for screen: Dictionary in Lx.SCREENS:
		for with_save: bool in [false, true]:
			var fx: RefCounted = Fx.new(tree)
			var lx: RefCounted = Lx.new(tree)
			var col: Node = fx.make("hub_layout")
			if with_save:
				col.save_lineup(fx.loaner_ids(), fx.loaner_ids()[0], true)
				col.save_lobby_duel(_mid_state(4), {"rival_id": &"quartermaster", "lineup": fx.loaner_ids(),
						"signature": fx.loaner_ids()[0]})
			var hub: Control = await _hub(fx, col, lx, screen)
			assert_eq(hub.continue_visible(), with_save, "%s CONTINUE visibility" % screen["name"])
			var fails: Array[String] = lx.layout_failures(hub, hub.get_key_controls(), screen)
			assert_true(fails.is_empty(), "%s (save %s): %s" % [screen["name"], with_save, "; ".join(fails)])
			await lx.finish()
			fx.finish()


func test_generic_wording_in_cc13_files() -> void:
	var abbrev: RegEx = RegEx.create_from_string("\\bCoD\\b")
	for path: String in OWNED_FILES:
		var text: String = FileAccess.get_file_as_string(path)
		assert_true(text != "", "%s readable" % path)
		var lower: String = text.to_lower()
		for word: String in DENYLIST:
			# The list itself lives in this file only; the others must not contain the words.
			assert_false(lower.contains(word), "%s contains '%s'" % [path, word])
		assert_true(abbrev.search(text) == null, "%s contains the abbreviation" % path)
	# This file holds the denylist itself, so it is not scanned; check the screens' live text too.
	var lx: RefCounted = Lx.new(tree)
	var fx: RefCounted = Fx.new(tree)
	var hub: Control = await _hub(fx, fx.make("hub_words"), lx, Lx.DESKTOP)
	var all_text: String = ""
	for n: Node in hub.find_children("*", "", true, false):
		if n is Label or n is Button:
			all_text += " " + String(n.text)
	for word: String in DENYLIST:
		assert_false(all_text.to_lower().contains(word), "hub shows '%s'" % word)
	assert_true(abbrev.search(all_text) == null, "hub shows the abbreviation")
	await lx.finish()
	fx.finish()

# --- Helpers ------------------------------------------------------------------------------------

## A loaner-vs-Archivist WallState with `placements` legal moves played (first legal move each).
static func _mid_state(placements: int) -> WallState:
	var b: BalanceConfig = DuelSetup.balance()
	var mine: Array[CardData] = []
	mine.assign(b.loaner_lineup)
	var rival: Dictionary = DuelSetup.rivals()[1]
	var theirs: Array[CardData] = []
	theirs.assign(rival["lineup"])
	var s: WallState = WallState.new_match(mine, b.loaner_signature if b.loaner_signature != null else mine[0],
			theirs, rival["signature"], WallState.P1, b, null, DuelSetup.triptychs())
	for i: int in placements:
		var m: Dictionary = WallRules.legal_moves(s)[0]
		WallRules.place(s, s.to_move, m["card"], m["slot"], m["copy_from"])
	return s

# test_lobby_duel.gd
# Purpose: cc13 Lobby Duel (scenes/LobbyDuel.tscn, scripts/lobby/lobby_duel.gd):
#   - full flow: wait -> quick duel -> match found mid-duel -> SAVE & LEAVE -> "Match starting"
#     -> simulated reload (a new Collection instance reads the same save file) -> hub CONTINUE ->
#     resume (duel_resumed, no duel_started) -> finish; the result counts in Collection and the
#     save is cleared,
#   - KEEP PLAYING continues the same duel; the end then offers JOIN MATCH,
#   - a resumed duel that ends in a DRAW (ties are draws) counts as a draw and clears the save,
#   - match found with no duel on screen goes straight to "Match starting",
#   - MENU during a lobby duel offers SAVE & LEAVE,
#   - layout of the wait screen, the banner over a duel and "Match starting" at 844x390 + notch and
#     1280x720 (44 pt / 64 px targets, 11 pt text, safe area).
# The SceneRouter runs dry (no scene changes); each test uses its own Collection save file.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const Fx: GDScript = preload("res://tests/test_collection_fixtures.gd")
const Lx: GDScript = preload("res://tests/test_lobby_fixtures.gd")
const LobbyDuelScript: GDScript = preload("res://scripts/lobby/lobby_duel.gd")
const MatchStartingScript: GDScript = preload("res://scripts/lobby/lobby_match_starting.gd")
const DuelControllerScript: GDScript = preload("res://scripts/duel/duel_controller.gd")
const DuelSetup: GDScript = preload("res://scripts/duel/duel_setup.gd")
const HubUi: GDScript = preload("res://scripts/hub/hub_ui.gd")
const LOBBY_SCENE: String = "res://scenes/LobbyDuel.tscn"
const HUB_SCENE: String = "res://scenes/Hub.tscn"
const WAIT_S: float = 90.0

var _bus_events: Array = []


func _lobby(col: Node, lx: RefCounted, mode: StringName, screen: Dictionary = Lx.PHONE, seed_value: int = 4242) -> Control:
	LobbyDuelScript.set_mode(mode)
	LobbyDuelScript.set_wait_override(WAIT_S)
	var lobby: Control = (load(LOBBY_SCENE) as PackedScene).instantiate()
	lobby.collection = col
	lobby.duel_event_delay = 0.0
	lobby.duel_rival_delay = 0.0
	lobby.duel_seed = seed_value
	lobby.found_delay_s = 0.0
	return await lx.spawn(lobby, screen)


## Starts the quick duel from the wait screen and presses BEGIN.
func _quick(lobby: Control, lx: RefCounted) -> Control:
	(lobby.find_child("QuickDuelButton", true, false) as Button).pressed.emit()
	await lx.frames(2)
	await lx.begin(lobby.duel)
	return lobby.duel


func _listen() -> void:
	_bus_events.clear()
	EventBus.duel_started.connect(_on_started)
	EventBus.duel_resumed.connect(_on_resumed)
	EventBus.lobby_match_found.connect(_on_found)
	EventBus.lobby_wait_started.connect(_on_wait)
	EventBus.duel_ended.connect(_on_ended)


func _unlisten() -> void:
	EventBus.duel_started.disconnect(_on_started)
	EventBus.duel_resumed.disconnect(_on_resumed)
	EventBus.lobby_match_found.disconnect(_on_found)
	EventBus.lobby_wait_started.disconnect(_on_wait)
	EventBus.duel_ended.disconnect(_on_ended)


func _on_started(source: StringName, _r: StringName, _f: StringName) -> void:
	_bus_events.append([&"started", source])


func _on_resumed(age_s: float) -> void:
	_bus_events.append([&"resumed", age_s])


func _on_found(choice: StringName) -> void:
	_bus_events.append([&"found", choice])


func _on_wait(wait_s: float) -> void:
	_bus_events.append([&"wait", wait_s])


func _on_ended(result: StringName, _p: int, _r: int, _t: int, _d: float) -> void:
	_bus_events.append([&"ended", result])


func _count(kind: StringName) -> int:
	return _bus_events.filter(func(e: Array) -> bool: return e[0] == kind).size()


# --- Full flow -------------------------------------------------------------------------------

func test_full_lobby_duel_save_reload_resume_finish() -> void:
	var fx: RefCounted = Fx.new(tree)
	var lx: RefCounted = Lx.new(tree)
	var router: Node = lx.router()
	_listen()
	var col: Node = fx.make("lobby_flow")
	var ids: Array = fx.loaner_ids()
	var sig: StringName = ids[2]
	assert_true(col.save_lineup(ids, sig, true)["valid"], "lineup + Signature saved")
	var lobby: Control = await _lobby(col, lx, &"wait")
	assert_eq(lobby.phase, &"waiting", "waiting")
	assert_true(lobby.searching, "searching")
	assert_eq(lobby.wait_s, WAIT_S, "wait length")
	assert_eq(_count(&"wait"), 1, "lobby_wait_started logged")
	assert_true((lobby.find_child("WaitScreen", true, false) as Control).visible, "wait screen shown")
	assert_true((lobby.find_child("WaitTitle", true, false) as Label).text.begins_with("FINDING MATCH"), "generic title")
	lobby.advance(12.0)
	assert_eq((lobby.find_child("WaitClock", true, false) as Label).text, "Searching  0:12", "timer shown")
	var duel: Control = await _quick(lobby, lx)
	var ctrl: Node = lobby.controller()
	assert_not_null(ctrl, "duel on screen")
	assert_false((lobby.find_child("WaitScreen", true, false) as Control).visible, "wait screen hidden")
	assert_eq(ctrl.source, &"lobby", "source lobby")
	assert_true(LobbyDuelScript.QUICK_RIVALS.has(ctrl.rival["id"]), "easy / normal rival: %s" % ctrl.rival["id"])
	assert_eq(ctrl.player_signature.id, sig, "saved Signature used")
	assert_eq(_bus_events.filter(func(e: Array) -> bool: return e[0] == &"started" and e[1] == &"lobby").size(), 1, "duel_started(lobby)")
	await lx.play_until(duel, 4)
	assert_true(lobby.searching, "still searching mid-duel")
	lobby.advance(WAIT_S)
	assert_eq(lobby.phase, &"found", "match found")
	assert_true(lobby.banner_visible(), "banner shown")
	assert_true((lobby.find_child("KeepPlayingButton", true, false) as Button).visible, "KEEP PLAYING offered")
	assert_true((lobby.find_child("SaveLeaveButton", true, false) as Button).visible, "SAVE & LEAVE offered")
	assert_eq((lobby.find_child("BannerTitle", true, false) as Label).text, "MATCH FOUND", "banner title")
	assert_true((lobby.find_child("BannerBody", true, false) as Label).text.contains("Your match is ready"), "banner body")
	assert_eq(duel.get_overlay().kind(), &"", "banner is not a modal: no overlay")
	var placed: int = ctrl.state.placements
	var rival_before: StringName = ctrl.rival["id"]
	var snapshot: Dictionary = WallStateCodec.encode(ctrl.state)
	(lobby.find_child("SaveLeaveButton", true, false) as Button).pressed.emit()
	assert_true(col.has_saved_lobby_duel(), "duel saved")
	assert_eq(router.last_requested, router.SCENE_MATCH_STARTING, "to 'Match starting'")
	assert_eq(_bus_events.filter(func(e: Array) -> bool: return e[0] == &"found" and e[1] == &"save").size(), 1, "lobby_match_found(save)")
	assert_eq(ctrl.phase, &"gone", "duel stopped")
	await lx.despawn()
	# "Match starting" placeholder goes back to the hub.
	var ms: Control = (load("res://scenes/LobbyMatchStarting.tscn") as PackedScene).instantiate()
	await lx.spawn(ms, Lx.PHONE)
	assert_eq((ms.find_child("StartingTitle", true, false) as Label).text, "MATCH STARTING...", "placeholder title")
	(ms.find_child("BackButton", true, false) as Button).pressed.emit()
	assert_eq(router.last_requested, router.SCENE_HUB, "then back to the hub")
	await lx.despawn()

	# Simulated reload: a new Collection reads the same file.
	fx.drop(col)
	var col2: Node = fx.make("lobby_flow", false)
	assert_true(col2.has_saved_lobby_duel(), "save survives the reload")
	assert_eq(col2.saved_lobby_duel_info()["placements"], placed, "same placements")
	var hub: Control = (load(HUB_SCENE) as PackedScene).instantiate()
	hub.collection = col2
	await lx.spawn(hub, Lx.PHONE)
	assert_true(hub.continue_visible(), "hub offers CONTINUE")
	hub.get_button(&"continue").pressed.emit()
	assert_eq(router.last_requested, router.SCENE_LOBBY, "CONTINUE -> Lobby Duel")
	await lx.despawn()
	_bus_events.clear()
	# The lobby reads next_mode (set by CONTINUE).
	var lobby2: Control = (load(LOBBY_SCENE) as PackedScene).instantiate()
	lobby2.collection = col2
	lobby2.duel_event_delay = 0.0
	lobby2.duel_rival_delay = 0.0
	lobby2.duel_seed = 77
	await lx.spawn(lobby2, Lx.PHONE)
	var ctrl2: Node = lobby2.controller()
	assert_not_null(ctrl2, "resumed duel on screen")
	assert_eq(lobby2.mode, LobbyDuelScript.MODE_RESUME, "resume mode")
	assert_false(lobby2.searching, "no matchmaking on resume")
	assert_eq(_count(&"resumed"), 1, "duel_resumed emitted")
	assert_eq(_count(&"started"), 0, "duel_started not emitted on resume")
	assert_eq(ctrl2.player_signature.id, sig, "Signature restored")
	assert_eq(ctrl2.rival["id"], rival_before, "same rival")
	assert_true(ctrl2.state.placements >= placed, "continues from the saved wall")
	for cell: Dictionary in snapshot["cells"]:
		assert_true(ctrl2.state.cells.has(StringName(cell["slot"])), "saved card at %s still there" % cell["slot"])
	await lx.play_to_end(lobby2.duel)
	assert_eq(ctrl2.phase, &"over", "resumed duel finishes")
	assert_eq(_count(&"ended"), 1, "one duel_ended")
	var st: Dictionary = col2.stats()
	assert_eq(st["duels"], 1, "the result counts in Collection")
	assert_eq(int(st["wins"]) + int(st["losses"]) + int(st["draws"]), 1, "as a win, loss or draw")
	assert_false(col2.has_saved_lobby_duel(), "save cleared at the end")
	await lx.finish()
	_unlisten()
	fx.finish()


func test_keep_playing_continues_the_duel() -> void:
	var fx: RefCounted = Fx.new(tree)
	var lx: RefCounted = Lx.new(tree)
	var router: Node = lx.router()
	_listen()
	var col: Node = fx.make("lobby_keep")
	var lobby: Control = await _lobby(col, lx, &"wait", Lx.DESKTOP, 99)
	var duel: Control = await _quick(lobby, lx)
	var ctrl: Node = lobby.controller()
	await lx.play_until(duel, 3)
	lobby.advance(WAIT_S)
	assert_true(lobby.banner_visible(), "banner shown")
	var at: int = ctrl.state.placements
	(lobby.find_child("KeepPlayingButton", true, false) as Button).pressed.emit()
	assert_false(lobby.banner_visible(), "banner dismissed")
	assert_true(lobby.kept_playing, "kept playing")
	assert_eq(_bus_events.filter(func(e: Array) -> bool: return e[0] == &"found" and e[1] == &"keep").size(), 1, "lobby_match_found(keep)")
	assert_eq(lobby.controller(), ctrl, "same duel")
	assert_true(await lx.play_move(duel) or ctrl.phase != &"player", "next move accepted")
	assert_true(ctrl.state.placements > at, "the duel goes on")
	await lx.play_to_end(duel)
	assert_eq(ctrl.phase, &"over", "duel finishes")
	assert_false(col.has_saved_lobby_duel(), "nothing saved")
	assert_eq(col.stats()["duels"], 1, "counted once")
	assert_true(lobby.banner_visible(), "banner back after the end")
	var join: Button = lobby.find_child("JoinMatchButton", true, false)
	assert_true(join.visible, "JOIN MATCH offered")
	assert_false((lobby.find_child("SaveLeaveButton", true, false) as Button).visible, "nothing left to save")
	var word: StringName = HubUi.result_word(ctrl.last_result)
	assert_true((lobby.find_child("BannerBody", true, false) as Label).text.begins_with(HubUi.result_words(word)), "result in the banner")
	join.pressed.emit()
	assert_eq(router.last_requested, router.SCENE_MATCH_STARTING, "JOIN MATCH -> Match starting")
	await lx.finish()
	_unlisten()
	fx.finish()


func test_resumed_duel_ending_in_a_draw() -> void:
	var b: BalanceConfig = DuelSetup.balance()
	var was_tie: int = b.tie_winner
	b.tie_winner = DataEnums.TieWinner.DRAW
	var found: Dictionary = _find_draw_position()
	assert_false(found.is_empty(), "a position one move from a draw exists")
	if found.is_empty():
		b.tie_winner = was_tie
		return
	var fx: RefCounted = Fx.new(tree)
	var lx: RefCounted = Lx.new(tree)
	_listen()
	var col: Node = fx.make("lobby_draw")
	var rival_id: StringName = found["rival_id"]
	assert_true(col.save_lobby_duel(found["state"], {"rival_id": rival_id, "lineup": found["lineup"],
			"signature": found["signature"], "elapsed_s": 75.0}), "position saved")
	fx.drop(col)
	var col2: Node = fx.make("lobby_draw", false)
	LobbyDuelScript.set_mode(LobbyDuelScript.MODE_RESUME)
	var lobby: Control = (load(LOBBY_SCENE) as PackedScene).instantiate()
	lobby.collection = col2
	lobby.duel_event_delay = 0.0
	lobby.duel_rival_delay = 0.0
	await lx.spawn(lobby, Lx.PHONE)
	var ctrl: Node = lobby.controller()
	assert_eq(ctrl.phase, &"player", "player to make the last placement")
	assert_true(ctrl.elapsed_s() >= 75.0, "saved duel time carried over")
	var m: Dictionary = found["move"]
	var card: CardData = null
	for c: CardData in ctrl.state.hands[WallState.P1]:
		if c.id == (m["card"] as CardData).id:
			card = c
	assert_not_null(card, "last card in hand")
	await lx.play_exact(lobby.duel, {"card": card, "slot": m["slot"], "copy_from": m["copy_from"]})
	assert_eq(ctrl.phase, &"over", "duel over")
	assert_eq(ctrl.last_result["winner"], WallState.NO_PLAYER, "tie is a draw")
	assert_eq(_bus_events.filter(func(e: Array) -> bool: return e[0] == &"ended" and e[1] == &"draw").size(), 1, "duel_ended(draw)")
	assert_eq((lobby.duel.get_overlay().get_node("%OverlayTitle") as Label).text, "DRAW", "end screen says DRAW")
	assert_eq(col2.stats()["draws"], 1, "draw counted in Collection")
	assert_eq(col2.stats()["duels"], 1, "one duel")
	assert_false(col2.has_saved_lobby_duel(), "draw clears the save")
	assert_false(lobby.banner_visible(), "no match banner on a resumed duel")
	assert_eq(HubUi.result_words(&"draw"), "The quick duel was a draw.", "draw wording")
	await lx.finish()
	_unlisten()
	b.tie_winner = was_tie
	fx.finish()


func test_match_found_while_waiting_goes_to_match() -> void:
	var fx: RefCounted = Fx.new(tree)
	var lx: RefCounted = Lx.new(tree)
	var router: Node = lx.router()
	var lobby: Control = await _lobby(fx.make("lobby_wait_only"), lx, &"wait", Lx.DESKTOP)
	lobby.advance(WAIT_S)
	await lx.frames(2)
	assert_eq((lobby.find_child("WaitTitle", true, false) as Label).text, "MATCH FOUND", "match found shown")
	assert_eq(router.last_requested, router.SCENE_MATCH_STARTING, "straight to Match starting")
	await lx.despawn()
	router.last_requested = ""
	lobby = await _lobby(fx.make("lobby_cancel"), lx, &"wait", Lx.DESKTOP)
	(lobby.find_child("CancelButton", true, false) as Button).pressed.emit()
	assert_eq(router.last_requested, router.SCENE_HUB, "CANCEL back to the hub")
	assert_false(lobby.searching, "search stopped")
	await lx.finish()
	fx.finish()


func test_menu_offers_save_and_leave() -> void:
	var fx: RefCounted = Fx.new(tree)
	var lx: RefCounted = Lx.new(tree)
	var router: Node = lx.router()
	var col: Node = fx.make("lobby_menu")
	var lobby: Control = await _lobby(col, lx, &"wait", Lx.PHONE, 5)
	var duel: Control = await _quick(lobby, lx)
	await lx.play_until(duel, 2)
	(duel.get_node("%MenuButton") as Button).pressed.emit()
	var overlay: Control = duel.get_overlay()
	assert_eq(overlay.kind(), &"lobby_leave", "lobby leave prompt")
	assert_not_null(overlay.get_button(&"save_leave"), "SAVE & LEAVE")
	overlay.get_button(&"stay").pressed.emit()
	assert_eq(overlay.kind(), &"", "KEEP PLAYING closes it")
	(duel.get_node("%MenuButton") as Button).pressed.emit()
	overlay.get_button(&"save_leave").pressed.emit()
	assert_true(col.has_saved_lobby_duel(), "saved from the menu")
	assert_eq(router.last_requested, router.SCENE_HUB, "before the match is found: back to the hub")
	await lx.finish()
	fx.finish()


func test_nothing_to_resume_is_explained() -> void:
	var fx: RefCounted = Fx.new(tree)
	var lx: RefCounted = Lx.new(tree)
	var lobby: Control = await _lobby(fx.make("lobby_none"), lx, &"resume", Lx.DESKTOP)
	assert_eq(lobby.controller(), null, "no duel")
	assert_eq((lobby.find_child("WaitTitle", true, false) as Label).text, "NOTHING TO CONTINUE", "explained")
	await lx.finish()
	fx.finish()


# --- Layout ------------------------------------------------------------------------------------

func test_lobby_layout_phone_and_desktop() -> void:
	for screen: Dictionary in Lx.SCREENS:
		var fx: RefCounted = Fx.new(tree)
		var lx: RefCounted = Lx.new(tree)
		var lobby: Control = await _lobby(fx.make("lobby_layout"), lx, &"wait", screen)
		var keys: Dictionary = lobby.get_key_controls()
		var wait_keys: Dictionary = {}
		for k: String in ["WaitTitle", "WaitClock", "WaitHint", "QuickDuelButton", "CancelButton"]:
			wait_keys[k] = keys[k]
		var fails: Array[String] = lx.layout_failures(lobby, wait_keys, screen)
		assert_true(fails.is_empty(), "wait screen: %s" % "; ".join(fails))
		var duel: Control = await _quick(lobby, lx)
		await lx.play_until(duel, 2)
		lobby.advance(WAIT_S)
		await lx.frames(2)
		var banner_keys: Dictionary = {"MatchBanner": keys["MatchBanner"], "KeepPlayingButton": keys["KeepPlayingButton"],
				"SaveLeaveButton": keys["SaveLeaveButton"], "BannerTitle": lobby.find_child("BannerTitle", true, false),
				"BannerBody": lobby.find_child("BannerBody", true, false)}
		fails = lx.layout_failures(lobby, banner_keys, screen)
		assert_true(fails.is_empty(), "banner: %s" % "; ".join(fails))
		# The banner leaves the wall, hand, PLACE and MENU free (non-blocking).
		var banner_rect: Rect2 = (keys["MatchBanner"] as Control).get_global_rect()
		for name: String in ["Wall", "Hand", "PlaceButton", "MenuButton"]:
			var c: Control = duel.get_key_controls()[name]
			assert_false(banner_rect.intersects(c.get_global_rect().grow(-1.0)), "%s: banner %s clear of %s %s" % [screen["name"], banner_rect, name, c.get_global_rect()])
		await lx.despawn()
		var ms: Control = (load("res://scenes/LobbyMatchStarting.tscn") as PackedScene).instantiate()
		await lx.spawn(ms, screen)
		fails = lx.layout_failures(ms, ms.get_key_controls(), screen)
		assert_true(fails.is_empty(), "match starting: %s" % "; ".join(fails))
		await lx.finish()
		fx.finish()


# --- Helpers -------------------------------------------------------------------------------------

## Random playouts (loaner vs a quick rival) until a position where the player's last placement
## gives a tie. {state, move, rival_id, lineup, signature} or {}.
func _find_draw_position() -> Dictionary:
	var b: BalanceConfig = DuelSetup.balance()
	var mine: Array[CardData] = []
	mine.assign(b.loaner_lineup)
	var my_sig: CardData = DuelSetup.player_lineup([])["signature"]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for r: Dictionary in DuelSetup.rivals():
		if not LobbyDuelScript.QUICK_RIVALS.has(r["id"]):
			continue
		var theirs: Array[CardData] = []
		theirs.assign(r["lineup"])
		for attempt: int in 400:
			rng.seed = attempt + 1
			var first: int = WallState.P2  # the player then makes the 10th (last) placement
			var s: WallState = WallState.new_match(mine, my_sig, theirs, r["signature"], first, b, null, DuelSetup.triptychs())
			while s.placements < 9:
				var moves: Array[Dictionary] = WallRules.legal_moves(s)
				var m: Dictionary = moves[rng.randi_range(0, moves.size() - 1)]
				WallRules.place(s, s.to_move, m["card"], m["slot"], m["copy_from"])
			if s.to_move != WallState.P1:
				continue
			for m: Dictionary in WallRules.legal_moves(s):
				var t: WallState = s.copy()
				WallRules.place(t, WallState.P1, m["card"], m["slot"], m["copy_from"])
				if t.is_game_over() and WallRules.final_result(t)["winner"] == WallState.NO_PLAYER:
					return {"state": s, "move": m, "rival_id": r["id"], "signature": my_sig.id,
							"lineup": mine.map(func(c: CardData) -> StringName: return c.id)}
	return {}

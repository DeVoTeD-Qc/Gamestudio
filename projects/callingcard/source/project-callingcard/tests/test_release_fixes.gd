# test_release_fixes.gd
# Purpose: Regression tests for the cc17 release-check bugs fixed in cc19
#   (documentation/qa/release-check.md):
#     BUG-02 a touch drag over the lineup grid scrolls it and adds nothing; tap = add and hold =
#            inspect still work; album cards and duel hand cards behave the same way,
#     BUG-03 the Web preset packs assets/fonts/OFL-Barlow.txt,
#     BUG-04 PLAY AGAIN after a resumed Lobby Duel is a rival duel (source rival, normal MENU),
#     BUG-05 a resumed Lobby Duel logs its real rival (duel_resumed and duel_end),
#     BUG-07 the album's "New card" toast clears the Cipher dials, their captions and the reward card,
#     BUG-08 the Match found banner leaves both scores, the wall, hand, PLACE and MENU visible,
#     BUG-09 phones: the album tab strip shows arrows that reach every tab,
#     BUG-10 Dossiers have no Tempo bonus (no tag, not counted) and all 5 solutions still clear,
#   plus the web shell's loading bar and disclaimer. (The how_earned wording stays as is: studio
#   head decision, cc19.)
# Author: UI/UX Agent (cc19)
extends "res://tests/test_case.gd"

const LineupFx: GDScript = preload("res://tests/test_lineup_fixtures.gd")
const AlbumFx: GDScript = preload("res://tests/test_album_fixtures.gd")
const Lx: GDScript = preload("res://tests/test_lobby_fixtures.gd")
const Fx: GDScript = preload("res://tests/test_collection_fixtures.gd")
const LobbyDuelScript: GDScript = preload("res://scripts/lobby/lobby_duel.gd")
const DossierControllerScript: GDScript = preload("res://scripts/dossier/dossier_controller.gd")
const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const LOBBY_SCENE: String = "res://scenes/LobbyDuel.tscn"
const DOSSIER_SCENE: String = "res://scenes/Dossier.tscn"
const IPHONE_SE: Dictionary = {"name": "iPhone SE 667x375 @2x", "pt": Vector2(667, 375), "ratio": 2.0}
const ANDROID: Dictionary = {"name": "Android 640x360 @2x", "pt": Vector2(640, 360), "ratio": 2.0}
const IPHONE_13: Dictionary = {"name": "iPhone 844x390 @3x + notch", "pt": Vector2(844, 390), "ratio": 3.0,
		"insets": Rect2(47, 0, 47, 21)}
const DESKTOP: Dictionary = {"name": "desktop 1280x720", "pt": Vector2(1280, 720), "ratio": 1.0}


# --- Input helpers ---------------------------------------------------------------------------

## A touch drag as the web build delivers it (emulate_mouse_from_touch): left press, moves with
## the button held, release. Touch scrolling in ScrollContainer needs a touchscreen, so the test
## turns on Input's touch emulation for the drag (what DisplayServer reports on a phone).
func _drag(viewport: SubViewport, from: Vector2, delta: Vector2, steps: int = 10) -> void:
	var was: bool = Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.position = from
	down.global_position = from
	viewport.push_input(down, true)
	var pos: Vector2 = from
	for i: int in steps:
		var mm := InputEventMouseMotion.new()
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		mm.relative = delta / steps
		pos += delta / steps
		mm.position = pos
		mm.global_position = pos
		viewport.push_input(mm, true)
		await tree.process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	viewport.push_input(up, true)
	await tree.process_frame
	await tree.process_frame
	Input.emulate_touch_from_mouse = was


## A press held for `seconds` at one point, then released.
func _hold(viewport: SubViewport, at: Vector2, seconds: float) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.position = at
	down.global_position = at
	viewport.push_input(down, true)
	await tree.create_timer(seconds).timeout
	var up: InputEventMouseButton = down.duplicate()
	up.pressed = false
	up.button_mask = 0
	viewport.push_input(up, true)
	await tree.process_frame
	await tree.process_frame


# --- BUG-02 ------------------------------------------------------------------------------------

func test_bug02_touch_drag_scrolls_lineup_grid_without_adding() -> void:
	for s: Dictionary in [IPHONE_SE, LineupFx.PHONE]:
		var lf: RefCounted = LineupFx.new(tree)
		var builder: Control = await lf.spawn(s, "release_lineup_drag")
		builder.tap_clear()
		await lf.frames(2)
		var scroll: ScrollContainer = builder.get_node("%CollectionScroll")
		var first: Button = builder.get_collection_buttons()[0]
		assert_eq(first.mouse_filter, Control.MOUSE_FILTER_PASS, "%s: grid cards pass drags to the list" % s["name"])
		assert_true(scroll.get_v_scroll_bar().max_value > scroll.size.y + 1.0, "%s: the grid needs scrolling" % s["name"])
		var lineup_before: Array = builder.get_lineup_ids().duplicate()
		var scroll_rect: Rect2 = scroll.get_global_rect()
		var at: Vector2 = first.get_global_rect().get_center()
		at.y = minf(at.y, scroll_rect.end.y - 8.0)
		await _drag(lf.viewport, at, Vector2(0, -160))
		assert_true(scroll.scroll_vertical > 40, "%s: swipe up over the cards scrolls the list (%d)" % [s["name"], scroll.scroll_vertical])
		assert_eq(builder.get_lineup_ids(), lineup_before, "%s: the swipe added no card" % s["name"])
		assert_false(builder.get_inspector().is_open(), "%s: the swipe opened no inspector" % s["name"])
		# Tap still adds, hold still inspects.
		var c: Button = builder.get_collection_buttons()[0]
		await lf.tap(c)
		assert_eq(builder.get_lineup_ids().size(), lineup_before.size() + 1, "%s: a tap adds the card" % s["name"])
		var c2: Button = builder.get_collection_buttons()[1]
		scroll.ensure_control_visible(c2)
		await lf.frames(2)
		var n: int = builder.get_lineup_ids().size()
		await _hold(lf.viewport, c2.get_global_rect().get_center(), 0.55)
		assert_true(builder.get_inspector().is_open(), "%s: a hold inspects" % s["name"])
		assert_eq(builder.get_lineup_ids().size(), n, "%s: the hold adds nothing" % s["name"])
		lf.finish()
		await tree.process_frame


func test_bug02_album_and_hand_cards_ignore_a_drag() -> void:
	# Album: a vertical swipe over a card hanger scrolls the page and opens no inspector.
	var fx: RefCounted = AlbumFx.new(tree)
	var setup: Array = await fx.spawn(IPHONE_SE, fx.make_collection("release_drag"), &"night_shift")
	var album: Control = setup[1]
	var page_scroll: ScrollContainer = album.get_node("%PageScroll")
	var hanger_button: Button = album.get_page().find_children("CardButton", "Button", true, false)[0]
	assert_eq(hanger_button.mouse_filter, Control.MOUSE_FILTER_PASS, "album cards pass drags")
	await _drag(setup[0], hanger_button.get_global_rect().get_center(), Vector2(0, -120))
	assert_true(page_scroll.scroll_vertical > 20, "album page scrolls on a swipe (%d)" % page_scroll.scroll_vertical)
	assert_false(album.get_inspector().is_open(), "album swipe opens no inspector")
	fx.finish()
	# Duel hand: hand cards pass drags too, and a drag that starts on a card does not pick it.
	var lx: RefCounted = Lx.new(tree)
	var col_fx: RefCounted = Fx.new(tree)
	LobbyDuelScript.set_mode(LobbyDuelScript.MODE_WAIT)
	LobbyDuelScript.set_wait_override(9999.0)
	var lobby: Control = (load(LOBBY_SCENE) as PackedScene).instantiate()
	lobby.collection = col_fx.make("release_hand_drag")
	lobby.duel_event_delay = 0.0
	lobby.duel_rival_delay = 0.0
	lobby.duel_seed = 11
	await lx.spawn(lobby, Lx.PHONE)
	(lobby.find_child("QuickDuelButton", true, false) as Button).pressed.emit()
	await lx.frames(2)
	await lx.begin(lobby.duel)
	var guard: int = 0
	while lobby.controller().phase != &"player" and guard < 60:
		guard += 1
		await lx.frames(1)
	var hand: Control = lobby.duel.get_hand()
	var card: Button = hand.get_card_buttons()[0]
	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_PASS, "hand cards pass drags")
	await _drag(lx.viewport, card.get_global_rect().get_center(), Vector2(-120, 0))
	assert_eq(hand.picked_id, &"", "a drag over a hand card does not pick it")
	card = hand.get_card_buttons()[0]
	card.pressed.emit()
	await lx.frames(1)
	assert_true(hand.picked_id != &"", "a tap still picks")
	LobbyDuelScript.set_wait_override(0.0)
	await lx.finish()
	col_fx.finish()


# --- BUG-03 ------------------------------------------------------------------------------------

func test_bug03_web_preset_packs_the_font_licence() -> void:
	assert_true(FileAccess.file_exists("res://assets/fonts/OFL-Barlow.txt"), "licence file in the project")
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "export_presets.cfg loads")
	var include: String = str(cfg.get_value("preset.0", "include_filter", ""))
	var matched: bool = false
	for f: String in include.split(",", false):
		matched = matched or "assets/fonts/OFL-Barlow.txt".matchn(f.strip_edges()) \
				or "res://assets/fonts/OFL-Barlow.txt".matchn(f.strip_edges())
	assert_true(matched, "include_filter packs the licence: '%s'" % include)
	var exclude: String = str(cfg.get_value("preset.0", "exclude_filter", ""))
	for f: String in exclude.split(",", false):
		assert_false("assets/fonts/OFL-Barlow.txt".matchn(f.strip_edges()), "exclude_filter '%s' drops the licence" % f)


# --- BUG-04 / BUG-05 -------------------------------------------------------------------------------

var _started: Array = []


func _on_started(source: StringName, rival_id: StringName, _first: StringName) -> void:
	_started.append([source, rival_id])


func test_bug04_05_resumed_lobby_duel_rival_and_play_again() -> void:
	var plog: Node = tree.root.get_node("PlaytestLog")
	var saved_plog: Dictionary = {"log_path": plog.log_path, "enabled": plog.enabled}
	DirAccess.make_dir_recursive_absolute("user://test_playtest")
	plog.log_path = "user://test_playtest/release_fixes.jsonl"
	plog.delete_log()
	plog.enabled = true
	plog.new_session()
	var fx: RefCounted = Fx.new(tree)
	var lx: RefCounted = Lx.new(tree)
	# A Lobby Duel against the Archivist, saved after a few placements, then resumed.
	var col: Node = fx.make("release_resume")
	LobbyDuelScript.set_mode(LobbyDuelScript.MODE_WAIT)
	LobbyDuelScript.set_wait_override(9999.0)
	var lobby: Control = (load(LOBBY_SCENE) as PackedScene).instantiate()
	lobby.collection = col
	lobby.duel_event_delay = 0.0
	lobby.duel_rival_delay = 0.0
	lobby.duel_seed = 1  # QUICK_RIVALS[1 % 2] = archivist
	await lx.spawn(lobby, Lx.PHONE)
	(lobby.find_child("QuickDuelButton", true, false) as Button).pressed.emit()
	await lx.frames(2)
	await lx.begin(lobby.duel)
	await lx.play_until(lobby.duel, 2)
	var rival_id: StringName = lobby.controller().rival["id"]
	assert_eq(rival_id, &"archivist", "quick duel against the Archivist")
	assert_true(lobby.save_and_leave(false), "saved")
	await lx.despawn()
	LobbyDuelScript.set_wait_override(0.0)
	LobbyDuelScript.set_mode(LobbyDuelScript.MODE_RESUME)
	lobby = (load(LOBBY_SCENE) as PackedScene).instantiate()
	lobby.collection = col
	lobby.duel_event_delay = 0.0
	lobby.duel_rival_delay = 0.0
	await lx.spawn(lobby, Lx.PHONE)
	assert_eq(lobby.phase, &"resumed", "resumed")
	await lx.play_to_end(lobby.duel)
	var ctrl: Node = lobby.controller()
	assert_eq(ctrl.phase, &"over", "resumed duel finished")
	plog.flush()
	var entries: Array = plog.read_entries()
	var resumed: Array = entries.filter(func(e: Dictionary) -> bool: return e.get("event") == "duel_resumed")
	var ended: Array = entries.filter(func(e: Dictionary) -> bool: return e.get("event") == "duel_end")
	assert_eq(resumed.size(), 1, "one duel_resumed logged")
	assert_eq(ended.size(), 1, "one duel_end (the resumed duel's)")
	if not resumed.is_empty():
		assert_eq(str(resumed[0].get("rival")), "archivist", "BUG-05: duel_resumed names the rival")
		assert_true(plog.validate_entry(resumed[0]).is_empty(), "duel_resumed matches the schema: %s" % [plog.validate_entry(resumed[0])])
	if not ended.is_empty():
		var last: Dictionary = ended[ended.size() - 1]
		assert_eq(str(last.get("rival")), "archivist", "BUG-05: duel_end names the rival")
		assert_true(bool(last.get("resumed")), "duel_end resumed")
	# BUG-04: PLAY AGAIN -> START DUEL -> BEGIN is an ordinary rival duel.
	_started.clear()
	EventBus.duel_started.connect(_on_started)
	lobby.duel.get_overlay().get_button(&"again").pressed.emit()
	await lx.frames(2)
	var start: Button = lobby.duel.get_overlay().get_button(&"start")
	assert_not_null(start, "setup panel open")
	if start != null:
		start.pressed.emit()
	await lx.begin(lobby.duel)
	EventBus.duel_started.disconnect(_on_started)
	assert_eq(_started.size(), 1, "one duel_started")
	if not _started.is_empty():
		assert_eq(_started[0][0], &"rival", "BUG-04: the replay's source is rival")
	assert_eq(ctrl.source, &"rival", "controller source rival")
	assert_false(ctrl.menu_override.is_valid(), "no Lobby MENU override")
	var guard: int = 0
	while ctrl.phase != &"player" and guard < 60:
		guard += 1
		await lx.frames(1)
	lobby.duel.menu_requested.emit()
	await lx.frames(1)
	assert_eq(lobby.duel.get_overlay().kind(), &"leave", "BUG-04: MENU opens the normal leave prompt")
	assert_true(lobby.duel.get_overlay().get_button(&"save_leave") == null, "BUG-04: no SAVE & LEAVE")
	plog.flush()
	entries = plog.read_entries()
	var starts: Array = entries.filter(func(e: Dictionary) -> bool: return e.get("event") == "duel_start")
	assert_true(not starts.is_empty() and str(starts[starts.size() - 1].get("source")) == "rival",
			"BUG-04: duel_start logged with source rival")
	await lx.finish()
	fx.finish()
	plog.enabled = saved_plog["enabled"]
	plog.delete_log()
	plog.log_path = saved_plog["log_path"]
	plog.new_session()


func test_bug04_replay_while_still_waiting_stays_a_lobby_duel() -> void:
	var fx: RefCounted = Fx.new(tree)
	var lx: RefCounted = Lx.new(tree)
	LobbyDuelScript.set_mode(LobbyDuelScript.MODE_WAIT)
	LobbyDuelScript.set_wait_override(9999.0)
	var lobby: Control = (load(LOBBY_SCENE) as PackedScene).instantiate()
	lobby.collection = fx.make("release_replay_wait")
	lobby.duel_event_delay = 0.0
	lobby.duel_rival_delay = 0.0
	lobby.duel_seed = 3
	await lx.spawn(lobby, Lx.PHONE)
	(lobby.find_child("QuickDuelButton", true, false) as Button).pressed.emit()
	await lx.frames(2)
	await lx.begin(lobby.duel)
	await lx.play_to_end(lobby.duel)
	assert_eq(lobby.phase, &"playing", "still waiting for the match")
	lobby.duel.get_overlay().get_button(&"again").pressed.emit()
	await lx.frames(2)
	assert_eq(lobby.controller().source, &"lobby", "a replay during the wait is still a Lobby Duel")
	assert_true(lobby.controller().menu_override.is_valid(), "and keeps SAVE & LEAVE")
	LobbyDuelScript.set_wait_override(0.0)
	await lx.finish()
	fx.finish()


# --- BUG-07 ------------------------------------------------------------------------------------

func test_bug07_new_card_toast_clears_dials_and_reward() -> void:
	for screen: Dictionary in [AlbumFx.PHONE, AlbumFx.PHONE_SMALL, AlbumFx.DESKTOP, ANDROID]:
		var fx: RefCounted = AlbumFx.new(tree)
		var coll: Node = fx.make_collection("release_toast")
		var setup: Array = await fx.spawn(screen, coll, &"cipher_lock")
		var album: Control = setup[1]
		var lock: PanelContainer = album.get_cipher_lock()
		lock.set_code([4, 3, 1, 2])
		lock.get_try_button().pressed.emit()
		await fx.settle(4)
		assert_eq(album.get_toast_text(), "New card: Key Fragment", "%s: toast shown" % screen["name"])
		var toast: Rect2 = (album.get_node("%Toast") as Control).get_global_rect()
		var blockers: Array[Control] = [lock.get_reward_card(), album.get_node("%Page"), album.get_node("%BackButton"),
				album.get_node("%CardCount"), album.get_node("%TabScroll")]
		for d: Node in lock.get_dials():
			blockers.append(d as Control)
		for c: Control in blockers:
			if c != null and c.is_visible_in_tree():
				assert_false(toast.intersects(c.get_global_rect().grow(-1.0)), "%s: toast %s clear of %s %s" % [screen["name"], toast, c.name, c.get_global_rect()])
		var title: Label = album.get_node("%AlbumTitle")
		assert_true(toast.position.x >= title.get_global_rect().position.x + title.get_minimum_size().x, "%s: toast clear of ALBUM" % screen["name"])
		var vp: Rect2 = Rect2(Vector2.ZERO, Vector2((setup[0] as SubViewport).size))
		assert_true(vp.encloses(toast), "%s: toast on screen" % screen["name"])
		fx.finish()


# --- BUG-08 ------------------------------------------------------------------------------------

func test_bug08_match_banner_leaves_scores_visible() -> void:
	for screen: Dictionary in [IPHONE_SE, IPHONE_13, DESKTOP, ANDROID]:
		var fx: RefCounted = Fx.new(tree)
		var lx: RefCounted = Lx.new(tree)
		LobbyDuelScript.set_mode(LobbyDuelScript.MODE_WAIT)
		LobbyDuelScript.set_wait_override(30.0)
		var lobby: Control = (load(LOBBY_SCENE) as PackedScene).instantiate()
		lobby.collection = fx.make("release_banner")
		lobby.duel_event_delay = 0.0
		lobby.duel_rival_delay = 0.0
		lobby.duel_seed = 4242
		lobby.found_delay_s = 0.0
		await lx.spawn(lobby, screen)
		(lobby.find_child("QuickDuelButton", true, false) as Button).pressed.emit()
		await lx.frames(2)
		await lx.begin(lobby.duel)
		await lx.play_until(lobby.duel, 2)
		lobby.advance(30.0)
		await lx.frames(3)
		assert_true(lobby.banner_visible(), "%s: banner shown" % screen["name"])
		var keys: Dictionary = lobby.get_key_controls()
		var pieces: Array[Control] = [keys["MatchBanner"], keys["MatchBannerActions"]]
		var duel: Control = lobby.duel
		var dk: Dictionary = duel.get_key_controls()
		var clear_of: Dictionary = {"Wall": dk["Wall"], "Hand": dk["Hand"], "PlaceButton": dk["PlaceButton"],
				"MenuButton": dk["MenuButton"], "PlayerScore": duel.get_counters()[0].get_score_label(),
				"RivalScore": duel.get_counters()[1].get_score_label()}
		for p: Control in pieces:
			var r: Rect2 = p.get_global_rect()
			for n: String in clear_of:
				var c: Control = clear_of[n]
				assert_false(r.intersects(c.get_global_rect().grow(-1.0)), "%s: %s %s clear of %s %s" % [screen["name"], p.name, r, n, c.get_global_rect()])
		var fails: Array[String] = lx.layout_failures(lobby, {"MatchBanner": keys["MatchBanner"],
				"MatchBannerActions": keys["MatchBannerActions"], "KeepPlayingButton": keys["KeepPlayingButton"],
				"SaveLeaveButton": keys["SaveLeaveButton"], "BannerTitle": lobby.find_child("BannerTitle", true, false),
				"BannerBody": lobby.find_child("BannerBody", true, false)}, screen)
		# (640x360 sits under the game's 405 pt design floor: its pt-size checks fail for every screen.)
		if screen != ANDROID:
			assert_true(fails.is_empty(), "%s banner layout: %s" % [screen["name"], "; ".join(fails)])
		for p: Control in pieces:
			assert_true(p.size.y <= (dk["TurnPanel"] as Control).size.y + 0.5, "%s: %s is one top-bar high (%s)" % [screen["name"], p.name, p.size])
		# Both counters still show their numbers (visible, not under an opaque piece).
		for counter: Control in duel.get_counters():
			assert_true(counter.get_score_label().is_visible_in_tree(), "%s: score visible" % screen["name"])
		LobbyDuelScript.set_wait_override(0.0)
		await lx.finish()
		fx.finish()


# --- BUG-09 ------------------------------------------------------------------------------------

func test_bug09_album_tab_arrows_reach_every_tab() -> void:
	for screen: Dictionary in [AlbumFx.PHONE, AlbumFx.PHONE_SMALL, ANDROID]:
		var fx: RefCounted = AlbumFx.new(tree)
		var setup: Array = await fx.spawn(screen, fx.make_collection("release_tabs"))
		var album: Control = setup[1]
		var arrows: Array = album.get_tab_arrows()
		var strip: ScrollContainer = album.get_node("%TabScroll")
		var vp: Rect2 = Rect2(Vector2.ZERO, Vector2((setup[0] as SubViewport).size))
		assert_true(arrows[0].is_visible_in_tree() and arrows[1].is_visible_in_tree(), "%s: tab arrows shown" % screen["name"])
		for a: Button in arrows:
			assert_true(vp.encloses(a.get_global_rect()), "%s: arrow %s on screen" % [screen["name"], a.name])
			assert_true(a.size.x >= 64.0 - 0.5 and a.size.y >= 64.0 - 0.5, "%s: arrow %s is a 64 px target" % [screen["name"], a.name])
		assert_true(arrows[0].disabled, "%s: left arrow dimmed at the start" % screen["name"])
		assert_false(arrows[1].disabled, "%s: right arrow live" % screen["name"])
		# Press the right arrow until the end: the Cipher Lock tab is then fully in view.
		for i: int in 6:
			if arrows[1].disabled:
				break
			arrows[1].pressed.emit()
			await tree.create_timer(0.3).timeout
		var tab: Button = album.get_tab(&"cipher_lock")
		assert_true(strip.get_global_rect().grow(0.5).encloses(tab.get_global_rect()), "%s: Cipher Lock tab reached with the arrow (%s in %s)" % [screen["name"], tab.get_global_rect(), strip.get_global_rect()])
		assert_true(arrows[1].disabled, "%s: right arrow dimmed at the end" % screen["name"])
		assert_false(arrows[0].disabled, "%s: left arrow live" % screen["name"])
		# Opening a page scrolls its tab into view.
		album.show_page(&"whiteout")
		await fx.settle(3)
		assert_true(strip.get_global_rect().grow(0.5).encloses(album.get_tab(&"whiteout").get_global_rect()), "%s: selected tab in view" % screen["name"])
		fx.finish()
	# Desktop: the tabs fit, so no arrows.
	var dfx: RefCounted = AlbumFx.new(tree)
	var dsetup: Array = await dfx.spawn(AlbumFx.DESKTOP, dfx.make_collection("release_tabs_desk"))
	var darrows: Array = dsetup[1].get_tab_arrows()
	var tabs_w: float = (dsetup[1].get_node("%Tabs") as Control).get_combined_minimum_size().x
	var fits: bool = tabs_w <= (dsetup[1].get_node("%TabScroll") as Control).size.x + 1.0
	assert_eq(darrows[1].visible, not fits, "desktop: arrows only when the tabs overflow")
	dfx.finish()


# --- BUG-10 ------------------------------------------------------------------------------------

func test_bug10_dossier_has_no_tempo() -> void:
	var balance: BalanceConfig = tree.root.get_node("CardDB").get_balance()
	assert_true(balance.first_player_bonus > 0, "duels keep their Tempo bonus (%d)" % balance.first_player_bonus)
	for d: DossierData in DossierControllerScript.load_dossiers():
		var p: DossierPuzzle = DossierPuzzle.new(d, balance)
		assert_eq(p.state.balance.first_player_bonus, 0, "%s: no Tempo in the puzzle" % d.id)
		assert_eq(p.play_line(d.solution), &"", "%s solution legal on the game balance" % d.id)
		var r: Dictionary = p.evaluate()
		assert_true(r["success"], "%s solution still clears its goal (%s)" % [d.id, r["reason"]])
	assert_true(balance.first_player_bonus > 0, "the shared balance is untouched")
	# The screen: no TEMPO tag on D1.
	var cfx: RefCounted = Fx.new(tree)
	var col: Node = cfx.make("release_dossier")
	var saved_size: Vector2i = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.disable_3d = true
	tree.root.add_child(viewport)
	DossierControllerScript.set_next_dossier(&"dossier_first_contact")
	var screen: Control = (load(DOSSIER_SCENE) as PackedScene).instantiate()
	var ctrl: Node = screen.get_node("%DuelController")
	ctrl.event_delay = 0.0
	ctrl.rival_delay = 0.0
	ctrl.collection = col
	viewport.add_child(screen)
	for i: int in 4:
		await tree.process_frame
	DossierControllerScript.set_next_dossier(&"")
	for c: Control in screen.get_counters():
		assert_false(c.get_tempo_label().visible, "no TEMPO tag in a Dossier")
	assert_eq(int(ctrl.ui_state().get("first_player_bonus", -1)), 0, "ui state sends bonus 0")
	viewport.queue_free()
	await tree.process_frame
	tree.root.size = saved_size
	cfx.finish()


# --- Web shell -----------------------------------------------------------------------------

func test_web_shell_has_progress_bar_and_disclaimer() -> void:
	var html: String = FileAccess.get_file_as_string("res://web/shell.html")
	assert_true(html.contains("role=\"progressbar\""), "accessible progress bar")
	assert_true(html.contains("id=\"bw-pct\""), "percentage readout")
	assert_true(html.contains("Unofficial concept demo. Not affiliated with Activision or Call of Duty."), "disclaimer while loading")
	assert_true(html.contains("$GODOT_CONFIG") and html.contains("$GODOT_URL"), "Godot placeholders kept")

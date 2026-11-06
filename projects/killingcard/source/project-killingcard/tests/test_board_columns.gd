# test_board_columns.gd
# Purpose: kc-board (board-and-cards-ux.md, approved): the vertical 3-column board, 4:1 banners,
#   the BannerArt data path, option A hand cards, landing ghosts, Protector slide, tap snapping,
#   Field chips with the Overrun warning, the inspector's 512x128 banner and the QA bridge.
#   Layout numbers are board-layout-v2.md's (kc-board2): phone 844x390 -> canvas 1168x540, banners
#   228x57, strip 6..68, columns at x 76 / 318 / 560, tray 800..1162 with 104x130 hand cards; 16:9
#   (canvas 960x540) 208x52; desktop 1440x900 -> canvas 1280x800, banners 304x76, columns at
#   86 / 410 / 734, tray 1050..1274 with 108x136 cards. Plus the tray's OPEN / CLOSED / PEEK states
#   by phase, the mirror layout, the strip badges and their flyouts, and the killfeed toasts + log.
# Author: Mechanics Developer Agent (kc-board, kc-board2)
extends "res://tests/test_case.gd"

const BoardLayout: GDScript = preload("res://tests/test_board_layout.gd")
const BoardMetrics: GDScript = preload("res://scripts/ui/board_metrics.gd")
const MockMatchData: GDScript = preload("res://scripts/ui/mock_match_data.gd")
const QaBridge: GDScript = preload("res://scripts/qa/qa_bridge.gd")
const MatchSnapshot: GDScript = preload("res://scripts/ui/match_snapshot.gd")
const DESKTOP_1440: Dictionary = {"name": "desktop 1440x900", "pt": Vector2(1440, 900), "ratio": 1.0}
const EPS: float = 0.6


func test_metrics_match_the_spec() -> void:
	# Phone: safe area = canvas minus the 6 px side margins; canvas x = area x + 6.
	var m: Dictionary = BoardMetrics.compute(Vector2(1168 - 12, 540), true)
	var bx: float = (m["board"] as Rect2).position.x + 6.0
	var by: float = (m["board"] as Rect2).position.y
	assert_eq([m["bw"], m["bh"]], [228.0, 57.0], "phone banner 228x57 (v1: 176x44)")
	assert_eq([(m["strip"] as Rect2).position.x + 6.0, (m["strip"] as Rect2).size.x], [6.0, 62.0], "strip 6..68")
	assert_eq(bx, 76.0, "phone column A at x 76")
	assert_eq(float(m["col_x"][1]) + bx, 318.0, "column B at 318")
	assert_eq(float(m["col_x"][2]) + bx, 560.0, "column C at 560")
	assert_eq([(m["tray"] as Rect2).position.x + 6.0, (m["tray"] as Rect2).end.x + 6.0], [800.0, 1162.0], "tray 800..1162")
	assert_eq(m["obj_h"], 52.0, "phone objective tile 52 px")
	assert_eq(BoardMetrics.row_y(m, &"enemy", 3) + by, 4.0, "rival back row at y 4")
	assert_eq(BoardMetrics.row_y(m, &"enemy", 0) + by, 184.0, "rival front row at y 184")
	assert_eq(BoardMetrics.objective_y(m) + by, 244.0, "objective at y 244")
	assert_eq(BoardMetrics.row_y(m, &"player", 0) + by, 299.0, "your front row at y 299")
	assert_eq(BoardMetrics.row_y(m, &"player", 3) + by + 57.0, 536.0, "your back row ends at y 536")
	assert_eq([m["card"], m["hand_cols"]], [Vector2(177, 73), 2], "phone hand: 2 columns of 177x73 banner cards (kc-ui4)")
	assert_true(bool(m["ks_inline"]), "phone: the killstreak tiles share the Supply row")
	assert_eq([(m["ks"] as Rect2).size, (m["supply"] as Rect2).size.x], [Vector2(194, 64), 160.0], "phone killstreak tiles 3x62 + Supply 160")
	var grid: Rect2 = m["grid"]
	assert_eq([grid.position.x + 800.0, grid.position.y + 4.0], [800.0, 76.0], "hand grid at x 800, y 76")
	var badges: Array[Rect2] = BoardMetrics.badge_rects(m)
	assert_eq(badges.map(func(r: Rect2) -> float: return r.position.y + 4.0), [4.0, 73.0, 142.0, 211.0, 280.0, 349.0, 472.0], "badge rows")
	assert_eq(badges[0].size, Vector2(62, 64), "badge 62x64")
	# 16:9 phone (canvas 960x540): the tray needs room, so the banners shrink to 208x52 (1.40x v1).
	var w: Dictionary = BoardMetrics.compute(Vector2(960 - 12, 540), true)
	assert_eq([w["bw"], w["bh"]], [208.0, 52.0], "16:9 banner 208x52")
	assert_eq((w["tray"] as Rect2).size.x, 214.0, "16:9 tray 214 wide")
	assert_false(bool(w["ks_inline"]), "16:9: the killstreak tiles get their own row")
	assert_eq([w["card"], w["hand_cols"]], [Vector2(103, 72), 2], "16:9: a 2-column hand of banner cards")
	# Desktop 1440x900 (canvas 1280x800).
	var d: Dictionary = BoardMetrics.compute(Vector2(1280 - 12, 800), false)
	var dx: float = (d["board"] as Rect2).position.x + 6.0
	assert_eq([d["bw"], d["bh"]], [304.0, 76.0], "desktop banner 304x76 (v1: 256x64)")
	assert_eq([dx, float(d["col_x"][1]) + dx, float(d["col_x"][2]) + dx], [86.0, 410.0, 734.0], "desktop columns")
	assert_eq(BoardMetrics.row_y(d, &"enemy", 3) + (d["board"] as Rect2).position.y, 24.0, "desktop rival back row at y 24")
	assert_eq(BoardMetrics.row_y(d, &"player", 0) + (d["board"] as Rect2).position.y, 454.0, "desktop front row at y 454")
	assert_eq(d["obj_h"], 96.0, "desktop objective tile 96 px")
	assert_eq([(d["tray"] as Rect2).position.x + 6.0, (d["tray"] as Rect2).size.x], [1050.0, 224.0], "desktop tray 1050..1274")
	assert_eq([d["card"], d["hand_cols"]], [Vector2(224, 64), 1], "desktop hand: one column of 224x64 banner cards (kc-ui4)")
	assert_eq([(d["ks"] as Rect2).position.y, (d["ks"] as Rect2).size], [54.0, Vector2(224, 64)], "desktop killstreak row under the Supply row")
	# Mirror: the tray on the left, the strip on the right, the same board.
	var mm: Dictionary = BoardMetrics.compute(Vector2(1156, 540), true, true)
	assert_eq((mm["tray"] as Rect2).position.x, 0.0, "mirrored tray at the left edge")
	assert_eq((mm["strip"] as Rect2).end.x, 1156.0, "mirrored strip at the right edge")
	assert_eq([mm["bw"], (mm["board"] as Rect2).size.x], [228.0, 712.0], "mirrored board unchanged")
	assert_eq((mm["board"] as Rect2).position.x, 1156.0 - (m["board"] as Rect2).end.x, "board mirrored")
	# Narrow safe area (notch): banners keep 4:1 and the tray keeps its minimum.
	var n: Dictionary = BoardMetrics.compute(Vector2(900, 540), true)
	assert_true(is_equal_approx(n["bw"], n["bh"] * 4.0), "4:1 kept")
	assert_true((n["tray"] as Rect2).size.x >= 210.0 - EPS, "tray minimum kept")


func test_board_numbers_readable() -> void:
	# Badges / numbers / plates (v2 phone 28/20/22, desktop 34/24/26), >= 14 pt numbers on the phone.
	var p: Dictionary = BannerView.metrics(57.0)
	assert_eq([p["badge"], p["number"], p["plate"]], [28.0, 20.0, 22.0], "phone banner metrics")
	var d: Dictionary = BannerView.metrics(76.0)
	assert_eq([d["badge"], d["number"], d["plate"]], [34.0, 24.0, 26.0], "desktop banner metrics")
	var k: float = BoardLayout.points_per_px(BoardLayout.PHONE)
	assert_true(float(p["number"]) * k >= 14.0, "phone stat numbers %.1f pt" % (float(p["number"]) * k))
	# Slot tap pitch 60 px = 43 pt (v1: 47 px = 34 pt).
	var m: Dictionary = BoardMetrics.compute(Vector2(1156, 540), true)
	assert_true((m["bh"] + m["row_gap"]) * k >= 43.0, "slot pitch %.1f pt" % ((m["bh"] + m["row_gap"]) * k))


func test_live_layout_columns_and_rows() -> void:
	for screen: Dictionary in [BoardLayout.PHONE, DESKTOP_1440]:
		var layout: RefCounted = BoardLayout.new()
		layout.set("tree", tree)
		var setup: Array = await layout._spawn(screen)
		var vp: SubViewport = setup[0]
		var m: Control = setup[1]
		var label: String = screen["name"]
		var lanes: Array[Node] = m.get_board().get_lanes()
		var want_bh: float = 57.0 if m.compact else 76.0
		for z: int in 3:
			var lane: Node = lanes[z]
			var tile: Rect2 = (lane.get_objective_tile() as Control).get_global_rect()
			assert_true(absf(tile.size.x - want_bh * 4.0) < EPS and absf(tile.size.y - (52.0 if m.compact else 96.0)) < EPS, "%s objective tile %s" % [label, tile.size])
			for i: int in 4:
				var fr: Rect2 = (lane.get_friendly_slots()[i] as Control).get_global_rect()
				var er: Rect2 = (lane.get_enemy_slots()[i] as Control).get_global_rect()
				assert_true(absf(fr.size.y - want_bh) < EPS and absf(fr.size.x - want_bh * 4.0) < EPS, "%s 4:1 banner slot %s" % [label, fr.size])
				assert_true(fr.position.y >= tile.end.y - EPS, "%s your rows below the objective" % label)
				assert_true(er.end.y <= tile.position.y + EPS, "%s rival rows above it" % label)
				if i > 0:
					var prev: Rect2 = (lane.get_friendly_slots()[i - 1] as Control).get_global_rect()
					assert_true(fr.position.y > prev.position.y, "%s your row %d further from the objective" % [label, i + 1])
					var eprev: Rect2 = (lane.get_enemy_slots()[i - 1] as Control).get_global_rect()
					assert_true(er.position.y < eprev.position.y, "%s rival row %d further up" % [label, i + 1])
		# Hand cards (option A) in the tray to the right of the board, art window on top.
		var hand: Control = m.get_hand()
		assert_true(hand.get_global_rect().position.x >= m.get_board().get_global_rect().end.x - EPS, "%s hand right of the board" % label)
		var card: Control = hand.get_cards()[0]
		var want: Vector2 = Vector2(177, 73) if m.compact else Vector2(224, 64)  # kc-ui4 banner cards
		assert_true(card.size.distance_to(want) < 1.0, "%s hand card %s" % [label, card.size])
		print("     [%s] banner %s, objective %s, hand card %s, tray %s" % [label, (lanes[0].get_friendly_slots()[0] as Control).size,
				(lanes[0].get_objective_tile() as Control).size, card.size, m.get_tray().get_global_rect()])
		layout._despawn(vp)
		await tree.process_frame


## kc-board2 §4.1: the tray is OPEN in Deploy, CLOSED (step header, killfeed log, HAND · n PEEK tab,
## SPEED) once READY is pressed, PEEK opens it read-only and closes on the next step; the board never
## moves or resizes.
func test_tray_open_close_by_phase() -> void:
	var layout: RefCounted = BoardLayout.new()
	layout.set("tree", tree)
	var setup: Array = await layout._spawn(BoardLayout.PHONE)
	var vp: SubViewport = setup[0]
	var m: Control = setup[1]
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	await tree.process_frame
	var board_rect: Rect2 = m.get_board().get_global_rect()
	assert_eq(m.tray_state, &"open", "Deploy: tray open")
	assert_true(m.get_hand().is_visible_in_tree() and m.get_ready_button().is_visible_in_tree(), "hand and READY shown")
	assert_false(m.get_hand_tab().is_visible_in_tree(), "no PEEK tab in Deploy")
	var states: Array[StringName] = []
	m.tray_state_changed.connect(func(st: StringName) -> void: states.append(st))
	var seen_closed: Array = [false]
	c.round_resolved.connect(func(_ev: Array) -> void:
		seen_closed[0] = m.tray_state == &"closed" and m.get_hand_tab().is_visible_in_tree() \
				and m.get_speed_button().is_visible_in_tree() and not m.get_hand().is_visible_in_tree() \
				and m.get_killfeed().is_visible_in_tree())
	# READY: CLOSED while the round plays (checked when the engine's events arrive), then the next
	# Deploy opens it again.
	await c.press_ready()
	await tree.process_frame
	assert_true(seen_closed[0], "READY closes the tray: tab, SPEED and the killfeed log, no hand")
	assert_eq(m.tray_state, &"open", "next Deploy: the tray opens on its own")
	assert_true(states.size() >= 2 and states[0] == &"closed" and states.back() == &"open", "states %s" % [states])
	assert_true(m.get_board().get_global_rect() == board_rect, "the board never moved or resized")
	# Outside Deploy (a Reveal / Firefight snapshot): CLOSED, then PEEK (read-only) from the tab.
	var hand_n: int = c.state.sides[0].hand.size()
	var snap: Dictionary = MatchSnapshot.build(c.state, c.map, 0, [])
	snap["deploy_open"] = false
	snap["phase"] = "REVEAL"
	m.show_snapshot(snap)
	await tree.process_frame
	assert_eq(m.tray_state, &"closed", "outside Deploy the tray is closed")
	assert_true(m.get_hand_tab().text.begins_with("HAND · %d" % hand_n), "tab: %s" % m.get_hand_tab().text)
	assert_true(m.get_hand_tab().text.contains("PEEK"), "tab offers PEEK")
	assert_false(m.get_ready_button().is_visible_in_tree(), "no READY while closed")
	m.get_hand_tab().pressed.emit()
	assert_eq(m.tray_state, &"peek", "tab opens a PEEK")
	assert_true(m.get_hand().read_only and m.get_hand().is_visible_in_tree(), "PEEK shows the hand read-only")
	var chip: Control = m.get_hand().get_cards()[0]
	var tag: Control = chip.find_child("NextTag", true, false)
	assert_true(tag != null and tag.visible, "cards tagged NEXT DEPLOY")
	var insp: Array = []
	m.get_hand().card_inspected.connect(func(uid: int) -> void: insp.append(uid))
	m.get_hand().card_tapped.connect(func(uid: int) -> void: insp.append(-uid))
	(chip.get_meta(&"gesture") as RefCounted).tapped.emit(Vector2.ZERO)
	assert_eq(insp, [int(chip.get_meta(&"uid"))], "a tap in PEEK inspects, never plays")
	m.get_inspector().close()
	m.get_node("%PeekCatcher").gui_input.emit(_press())
	assert_eq(m.tray_state, &"closed", "a tap outside closes the PEEK")
	# A PEEK closes when the next step starts; the next Deploy opens the tray.
	m.set_tray_state(&"peek")
	snap["phase"] = "FIREFIGHT"
	m.show_snapshot(snap)
	await tree.process_frame
	assert_eq(m.tray_state, &"closed", "a new step closes the PEEK")
	c.refresh()
	await tree.process_frame
	assert_eq(m.tray_state, &"open", "Deploy opens it")
	layout._despawn(vp)
	await tree.process_frame


## Settings.mirror_layout: tray left, strip right; the board stays the same size; the selected card
## shifts toward the board (right when mirrored); the pause menu toggles it.
func test_mirror_layout_setting() -> void:
	var layout: RefCounted = BoardLayout.new()
	layout.set("tree", tree)
	var setup: Array = await layout._spawn(BoardLayout.PHONE, MockMatchData.round_3_sample())
	var vp: SubViewport = setup[0]
	var m: Control = setup[1]
	var board_size: Vector2 = m.get_board().size
	assert_false(m.mirror, "mirror off by default")
	assert_true(m.get_tray().get_global_rect().position.x > m.get_board().get_global_rect().end.x, "tray right of the board")
	var pause: Control = m.get_pause_menu()
	pause.open({})
	var button: Button = pause.get_mirror_button()
	assert_eq(button.text, "MIRROR LAYOUT: OFF", "pause menu offers the mirror setting")
	button.button_pressed = true
	await tree.process_frame
	await tree.process_frame
	assert_true(bool(Settings.mirror_layout), "Settings.mirror_layout on")
	assert_true(m.mirror, "screen follows the setting")
	assert_eq(button.text, "MIRROR LAYOUT: ON", "button says ON")
	pause.close()
	var tray: Rect2 = m.get_tray().get_global_rect()
	var board: Rect2 = m.get_board().get_global_rect()
	var strip: Rect2 = m.get_badge(&"menu").get_global_rect()
	assert_true(tray.end.x < board.position.x, "mirrored: tray left of the board (%s / %s)" % [tray, board])
	assert_true(strip.position.x > board.end.x, "mirrored: strip right of the board")
	assert_eq(m.get_board().size, board_size, "board size unchanged")
	assert_eq(m.get_hand().board_side, 1.0, "selected card shifts right, toward the board")
	m.open_flyout(&"score")
	await tree.process_frame
	await tree.process_frame
	assert_true(m.get_node("%FlyoutPanel").get_global_rect().end.x <= strip.position.x + EPS, "flyout opens toward the board")
	m.close_flyout()
	Settings.set_value(&"mirror_layout", false)
	await tree.process_frame
	assert_false(m.mirror, "mirror off again")
	assert_true(m.get_tray().get_global_rect().position.x > m.get_board().get_global_rect().end.x, "tray back on the right")
	layout._despawn(vp)
	await tree.process_frame


## The icon strip: every badge shows its key value, tap opens its flyout next to it, long-press /
## right-click opens its rules (studio rule); the killfeed shows as toasts over the board and a
## log in the tray.
func test_strip_badges_flyouts_and_killfeed_toasts() -> void:
	var layout: RefCounted = BoardLayout.new()
	layout.set("tree", tree)
	var setup: Array = await layout._spawn(BoardLayout.PHONE)
	var vp: SubViewport = setup[0]
	var m: Control = setup[1]
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	await tree.process_frame
	var st: MatchState = c.state
	# kc-fight-ui: on the phone RIVAL folds into SCORE (third line: the rival's hand count).
	assert_eq(m.get_badge(&"score").get_text(), "R%d %d-%d %d" % [st.round_number, st.sides[0].score, st.sides[1].score,
			st.sides[1].hand.size()], "SCORE badge (with the rival hand)")
	assert_false(m.get_node("%RivalBadge").visible, "no separate RIVAL badge on the phone")
	assert_eq(m.get_badge(&"deck").get_text(), str(st.sides[0].deck.size()), "DECK badge: deck count")
	assert_eq(m.get_badge(&"operator").get_text(), "DEPLOY", "OPERATOR badge says DEPLOY in Round 1")
	assert_false(m.get_badge(&"operator").hot, "kc-ui3: the badge is info only (the hand's Operator card glows)")
	var flyouts: Dictionary = {&"score": "%ScoreBar", &"deck": "%DeckBox", &"streak": "%OperatorPanel"}
	for key: StringName in flyouts:
		m.get_badge(key).tapped.emit()
		await tree.process_frame
		await tree.process_frame
		assert_eq(m.flyout_key, key, "%s badge opens its flyout" % key)
		var body: Control = m.get_node(flyouts[key])
		assert_true(body.is_visible_in_tree(), "%s flyout shows %s" % [key, flyouts[key]])
		var panel: Rect2 = m.get_node("%FlyoutPanel").get_global_rect()
		assert_true(Rect2(Vector2.ZERO, Vector2(vp.size)).grow(EPS).encloses(panel), "%s flyout on screen %s" % [key, panel])
		assert_true(panel.position.x >= m.get_badge(key).get_global_rect().end.x, "%s flyout beside the strip" % key)
	assert_eq(m.get_operator_panel().get_buttons().size(), 6, "STREAK flyout: 6 tiles")
	assert_true((m.get_operator_panel().get_buttons()[0] as Control).is_visible_in_tree(), "tiles visible")
	m.get_badge(&"score").tapped.emit()
	await tree.process_frame
	assert_true(m.get_node("%Minimap").is_visible_in_tree(), "the SCORE flyout also shows the rival intel")
	m.get_node("%FlyoutScrim").gui_input.emit(_press())
	assert_false(m.is_flyout_open(), "a tap outside closes the flyout")
	# Long-press / right-click: rules for every badge, the supply row and the killfeed log.
	var insp: Control = m.get_inspector()
	for key: StringName in [&"score", &"streak", &"deck"]:
		m.get_badge(key).inspected.emit()
		await tree.process_frame
		assert_true(insp.is_open(), "%s badge inspectable" % key)
		insp.close()
	for key: StringName in [&"menu", &"preview"]:
		var right := InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT
		right.pressed = true
		m.get_badge(key).gui_input.emit(right)
		await tree.process_frame
		assert_true(insp.is_open(), "%s button inspectable by right-click" % key)
		insp.close()
	m.get_badge(&"operator").inspected.emit()
	await tree.process_frame
	assert_true(insp.is_open(), "OPERATOR badge inspects the Operator")
	insp.close()
	# kc-ui3: the OPERATOR badge is info only: a tap opens its flyout, never selects.
	m.get_badge(&"operator").tapped.emit()
	await tree.process_frame
	await tree.process_frame
	assert_eq(m.flyout_key, &"operator", "OPERATOR badge tap opens its flyout")
	assert_true(c.selection.is_empty(), "and selects nothing")
	m.close_flyout()
	# Killfeed: a push shows a toast over the board's top centre AND a line in the tray log.
	var toasts: Control = m.get_killfeed_toasts()
	toasts.push({"attacker": "Demolitions Expert", "attacker_side": &"player", "victim": "Kestrel AR-7",
			"victim_side": &"enemy", "icon": &"class_lmg", "zone": &"left"})
	await tree.process_frame
	assert_eq(toasts.get_entries().size(), 1, "one toast")
	assert_eq(m.get_killfeed().get_entries().size(), 1, "copied to the tray log")
	var tr: Rect2 = toasts.get_global_rect()
	var br: Rect2 = m.get_board().get_global_rect()
	assert_true(br.encloses(tr) and tr.position.y - br.position.y < 10.0, "toasts at the top of the board %s" % tr)
	assert_eq(toasts.mouse_filter, Control.MOUSE_FILTER_IGNORE, "toasts take no input")
	for i: int in 3:
		toasts.push({"attacker": "Breacher", "attacker_side": &"enemy", "victim": "Point Man", "victim_side": &"player"})
	await tree.process_frame
	assert_eq(toasts.get_entries().size(), 2, "at most 2 toasts")
	assert_eq(m.get_killfeed().get_entries().size(), 4, "the log keeps every line")
	assert_true(absf(float(toasts.get_entries()[0].life) - 2.5) < 0.6, "toast life ~2.5 s (%s)" % toasts.get_entries()[0].life)
	layout._despawn(vp)
	await tree.process_frame


static func _press() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


func test_banner_art_path_and_crops() -> void:
	var was_enabled: bool = BannerArtDB.licensed_enabled
	BannerArtDB.licensed_enabled = false  # a dev machine may have the private licensed folder
	BannerArtDB.clear_cache()
	# Killstreak card art placeholder: 4:1 band and 2:3 column of the same master.
	var art: BannerArt = BannerArtDB.get_art(&"marksman")
	assert_true(art.placeholder and art.texture != null, "placeholder from card art")
	var b: Texture2D = BannerArtDB.banner_texture(&"marksman")
	var p: Texture2D = BannerArtDB.portrait_texture(&"marksman")
	assert_true(absf(float(b.get_width()) / b.get_height() - 4.0) < 0.05, "banner 4:1 (%s)" % b.get_size())
	assert_true(absf(float(p.get_width()) / p.get_height() - 2.0 / 3.0) < 0.02, "portrait 2:3 (%s)" % p.get_size())
	# Crop centres move the regions, clamped inside the image.
	var img: Vector2 = Vector2(1536, 1024)
	assert_eq(BannerArt.band_rect(img, 0.47), Rect2(0, 289, 1536, 384), "art direction default band")
	assert_eq(BannerArt.band_rect(img, 0.0).position.y, 0.0, "band clamped at the top")
	assert_eq(BannerArt.column_rect(img, 0.5), Rect2(427, 0, 683, 1024), "hand column 683x1024")
	# A card with no art at all still gets a distinct generated banner.
	var g1: BannerArt = BannerArtDB.get_art(&"war_standard")
	var g2: BannerArt = BannerArtDB.get_art(&"aid_station")
	assert_true(g1.placeholder and g1.texture != null and g2.texture != null, "generated placeholders")
	assert_true(g1.texture.get_image().get_pixel(10, 10) != g2.texture.get_image().get_pixel(10, 10), "distinct per id")
	# Drop-in: a BannerArt in data/banners/<id>.tres wins over the placeholder.
	var drop := BannerArt.new()
	drop.id = &"kc_test_drop"
	drop.texture = ImageTexture.create_from_image(Image.create(1152, 768, false, Image.FORMAT_RGB8))
	drop.banner_y = 0.4
	var path: String = "res://data/banners/kc_test_drop.tres"
	DirAccess.make_dir_recursive_absolute("res://data/banners")
	assert_eq(ResourceSaver.save(drop, path), OK, "save drop-in banner")
	BannerArtDB.clear_cache()
	var got: BannerArt = BannerArtDB.get_art(&"kc_test_drop")
	assert_false(got.placeholder, "drop-in art used")
	assert_eq(BannerArtDB.banner_texture(&"kc_test_drop").get_size(), Vector2(1152, 288), "1152x288 band of a 1152x768 master")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if DirAccess.get_files_at("res://data/banners").is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://data/banners"))
	BannerArtDB.licensed_enabled = was_enabled
	BannerArtDB.clear_cache()


## kc-cod hook: an optional licensed folder with a manifest is used when present, ignored when not.
func test_licensed_manifest_optional() -> void:
	var saved: String = BannerArtDB.licensed_dir
	var was_enabled: bool = BannerArtDB.licensed_enabled
	BannerArtDB.licensed_enabled = true
	BannerArtDB.licensed_dir = "user://kc_licensed_test/"
	BannerArtDB.clear_cache()
	assert_true(BannerArtDB.licensed_rows().is_empty(), "no folder: no rows")
	assert_true(BannerArtDB.get_art(&"rifleman").placeholder, "no folder: placeholder")
	DirAccess.make_dir_recursive_absolute(BannerArtDB.licensed_dir)
	var img: Image = Image.create(300, 200, false, Image.FORMAT_RGB8)
	img.fill(Color(0.2, 0.4, 0.6))
	img.save_png(BannerArtDB.licensed_dir + "card_a.png")
	var f: FileAccess = FileAccess.open(BannerArtDB.licensed_dir + "manifest.csv", FileAccess.WRITE)
	f.store_line("file,kind,chassis,title")
	f.store_line("card_a.png,unit,rifleman,Test Card")
	f.close()
	BannerArtDB.clear_cache()
	var art: BannerArt = BannerArtDB.get_art(&"rifleman")
	assert_false(art.placeholder, "manifest art used")
	assert_eq(art.title, "Test Card", "title from the manifest")
	assert_eq(BannerArtDB.banner_texture(&"rifleman").get_size(), Vector2(300, 75), "4:1 band of the licensed image")
	assert_true(BannerArtDB.get_art(&"marksman").placeholder, "chassis not in the manifest keep placeholders")
	for file: String in DirAccess.get_files_at(BannerArtDB.licensed_dir):
		DirAccess.remove_absolute(BannerArtDB.licensed_dir + file)
	DirAccess.remove_absolute(BannerArtDB.licensed_dir)
	BannerArtDB.licensed_dir = saved
	BannerArtDB.licensed_enabled = was_enabled
	BannerArtDB.clear_cache()


## kc-cod2: the pitch-set manifest (ids, frame sheets, Operator mastery ladder) drives per-copy art,
## the Operator's mastery banner and camo, the hand strip and the focus-only flipbook. Uses a scratch
## folder with generated images (no licensed art in tests).
func test_pitch_set_per_copy_art_mastery_and_flipbook() -> void:
	var saved: String = BannerArtDB.licensed_dir
	var was_enabled: bool = BannerArtDB.licensed_enabled
	BannerArtDB.licensed_enabled = true
	BannerArtDB.licensed_dir = "user://kc_pitch_test/"
	DirAccess.make_dir_recursive_absolute(BannerArtDB.licensed_dir)
	var colors: Dictionary = {"r1": Color.RED, "r2": Color.GREEN, "m1": Color.BLUE, "g1": Color.GOLD, "g2": Color.SILVER}
	for key: String in colors:
		var img: Image = Image.create(64, 16, false, Image.FORMAT_RGB8)
		img.fill(colors[key])
		img.save_png(BannerArtDB.licensed_dir + key + ".png")
	var sheet: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)  # 4 frames of 64x16
	for i: int in 4:
		sheet.fill_rect(Rect2i(0, i * 16, 64, 16), Color(i / 4.0, 0, 0))
	sheet.save_png(BannerArtDB.licensed_dir + "r2_frames.png")
	var f: FileAccess = FileAccess.open(BannerArtDB.licensed_dir + "manifest.csv", FileAccess.WRITE)
	f.store_line("file,kind,card,title,id,animated,frames_file,frames,frame_ms,mastery_family,tier_rank")
	f.store_line("r1.png,unit,rifleman,Rifle One,kc_t_r1,no,,,,,")
	f.store_line("r2.png,unit,rifleman,Rifle Two,kc_t_r2,yes,r2_frames.png,4,50,,")
	f.store_line("m1.png,unit,marksman,Mark One,kc_t_m1,no,,,,,")
	f.store_line("g1.png,operator,kestrel_ar7,MCW Gilded,kc_t_g1,no,,,,wm_mcw,1")
	f.store_line("g2.png,operator,kestrel_ar7,MCW Forged,kc_t_g2,no,,,,wm_mcw,2")
	f.close()
	BannerArtDB.clear_cache()
	assert_true(BannerArtDB.has_licensed(), "pitch manifest loaded")
	assert_eq(BannerArtDB.licensed_pool(&"rifleman"), [&"kc_t_r1", &"kc_t_r2"] as Array[StringName], "rifleman pool in order")
	# Per-copy art: copies of a chassis cycle through the pool, across both sides.
	var arts: Array = BannerArtDB.copy_arts([[&"rifleman", &"rifleman", &"marksman", &"callout"], [&"rifleman"]])
	assert_eq(arts[0], [&"kc_t_r1", &"kc_t_r2", &"kc_t_m1", &""], "player copies get different arts")
	assert_eq(arts[1], [&"kc_t_r1"], "rival copies continue the cycle (wraps)")
	var art: BannerArt = BannerArtDB.get_art(&"kc_t_r2")
	assert_true(art.licensed and not art.placeholder, "art reachable by its own id")
	assert_eq(art.frame_count, 4, "frame sheet rows")
	assert_not_null(BannerArtDB.frames_texture(art), "frame sheet loads")
	# Licensed art: the hand "portrait" is the whole 4:1 strip, not a 2:3 column.
	var p: Texture2D = BannerArtDB.portrait_texture(&"kc_t_r1")
	assert_true(absf(float(p.get_width()) / p.get_height() - 4.0) < 0.05, "hand shows the strip (%s)" % p.get_size())
	# Operator mastery ladder: Base = tier 1, the dev override previews higher tiers.
	assert_eq(BannerArtDB.operator_art_id(&"kestrel_ar7", 1), &"kc_t_g1", "Base = first mastery tier")
	assert_eq(BannerArtDB.camo_for_tier(1), &"base", "tier 1 wears the Base camo")
	BannerArtDB.operator_tier_override = 2
	assert_eq(BannerArtDB.operator_art_id(&"kestrel_ar7", 1), &"kc_t_g2", "dev toggle shows tier 2")
	assert_eq(BannerArtDB.camo_for_tier(1), &"forged", "camo follows the tier")
	BannerArtDB.operator_tier_override = 4
	assert_eq(BannerArtDB.operator_art_id(&"kestrel_ar7", 1), &"kc_t_g2", "clamped to the ladder")
	BannerArtDB.operator_tier_override = 0
	assert_eq(BannerArtDB.operator_art_id(&"wasp_9", 1), &"wasp_9", "no ladder: weapon id")
	# MatchState keeps the copy's art by uid (display only; clones carry it).
	var setup := SideSetup.new()
	var rifle: CardData = CardDB.get_card(&"rifleman")
	if rifle != null:
		setup.deck.assign([rifle, rifle])
		setup.deck_arts.assign([&"kc_t_r1", &"kc_t_r2"])
		setup.keep_deck_order = true
		var m := MatchState.new(null, null, setup, SideSetup.new(), 7)
		m.start_match()
		var uids: Array = m.art_by_uid.keys()
		assert_eq(uids.size(), 2, "both copies mapped")
		assert_eq(MatchClone.copy(m).art_by_uid, m.art_by_uid, "clone keeps the art map")
	# The calling card's own title is the card name; the Operator's mastery card is not.
	assert_eq(BannerArtDB.art_title(&"kc_t_r2"), "Rifle Two", "art title as card name")
	assert_eq(BannerArtDB.art_title(&"kc_t_g1"), "", "Operator keeps its weapon name")
	# kc-cod3: the inspector's card picture (CardView) shows the copy's licensed art.
	var cv: Control = (load("res://scenes/match/CardView.tscn") as PackedScene).instantiate()
	tree.root.add_child(cv)
	await tree.process_frame
	var vd: Dictionary = (load("res://scripts/ui/card_info.gd") as GDScript).view_dict(CardDB.get_card(&"rifleman"), "friend")
	vd["licensed_art"] = "kc_t_r1"
	cv.set_card_data(vd)
	assert_eq((cv.get_node("%ArtIcon") as TextureRect).texture, BannerArtDB.banner_texture(&"kc_t_r1"), "card picture shows the licensed art")
	cv.queue_free()
	# BannerView: flipbook only while focused, still art otherwise; safety net needs licensed art.
	var view := BannerView.new()
	view.size = Vector2(256, 64)
	tree.root.add_child(view)
	view.show_unit({"name": "Rifleman", "cls": "AR", "fp": 2, "armor": 2, "banner": "kc_t_r2"}, &"player", true)
	assert_false(view.is_flipbook_playing(), "still until focused")
	view.set_focus(true)
	assert_true(view.is_flipbook_playing(), "focus plays the frame sheet")
	view.set_focus(false)
	assert_false(view.is_flipbook_playing(), "unfocus stops it")
	assert_eq(view.get_node("Art").texture, BannerArtDB.banner_texture(&"kc_t_r2"), "back to the still")
	view.show_unit({"name": "Rifleman", "cls": "AR", "fp": 2, "armor": 2, "banner": "kc_t_r1"}, &"player", true)
	view.set_focus(true)
	assert_false(view.is_flipbook_playing(), "still art shimmers instead")
	assert_true(view.is_focused(), "but is focused")
	view.queue_free()
	for file: String in DirAccess.get_files_at(BannerArtDB.licensed_dir):
		DirAccess.remove_absolute(BannerArtDB.licensed_dir + file)
	DirAccess.remove_absolute(BannerArtDB.licensed_dir)
	BannerArtDB.licensed_dir = saved
	BannerArtDB.licensed_enabled = was_enabled
	BannerArtDB.clear_cache()


## kc-cod2: the private pitch build's deck swaps (Units, Tactics and Fields all shown, new chassis in),
## off by default so the public game and every other test keep the real decks.
func test_pitch_decks_swaps_only_when_active() -> void:
	var cfg: RunConfig = load("res://data/run_config.tres")
	var starter: Array[CardData] = cfg.starter_deck
	assert_false(PitchDecks.active(), "off outside the pitch export")
	assert_eq(PitchDecks.apply(starter), starter, "inactive: unchanged")
	PitchDecks.forced = true
	var deck: Array[CardData] = PitchDecks.apply(starter)
	PitchDecks.forced = false
	assert_eq(deck.size(), starter.size(), "same deck size")
	assert_eq(cfg.starter_deck, starter, "the source deck is not modified")
	var ids: Array = deck.map(func(c: CardData) -> StringName: return c.id)
	for id: StringName in [&"brawler", &"war_standard", &"listening_post", &"smoke_screen", &"blackout", &"sabotage"]:
		assert_true(ids.has(id), "pitch deck has %s" % id)
	assert_eq(_kinds(deck), [10, 7, 3], "starter pitch deck: 10 units / 7 tactics / 3 Fields")
	# AI squads lean on units the same way, never with Sniper Perch / Aid Station.
	PitchDecks.forced = true
	for f: String in ["squad_anchor", "squad_black_meridian", "squad_rusher"]:
		var sq: SquadData = load("res://data/squads/%s.tres" % f)
		var d: Array[CardData] = PitchDecks.apply(sq.deck)
		var k: Array = _kinds(d)
		assert_eq(k[0], PitchDecks.unit_target(d.size()), "%s units" % f)
		assert_eq(k[2], 3, "%s Fields" % f)
		assert_true(k[1] >= 5, "%s tactics (%d)" % [f, k[1]])
		var dids: Array = d.map(func(c: CardData) -> StringName: return c.id)
		assert_false(dids.has(&"sniper_perch") or dids.has(&"aid_station"), "%s: no Sniper Perch / Aid Station" % f)
		assert_true(dids.has(&"brawler") and dids.has(&"smoke_screen"), "%s shows the new chassis" % f)
	var with_perch: Array[CardData] = starter.duplicate()
	with_perch[0] = CardDB.get_card(&"sniper_perch")
	assert_false(PitchDecks.apply(with_perch).has(CardDB.get_card(&"sniper_perch")), "Sniper Perch swapped out")
	PitchDecks.forced = false
	for id: StringName in [&"brawler", &"smoke_screen", &"blackout", &"sabotage"]:
		var c: CardData = CardDB.get_card(id)
		assert_not_null(c, "%s is in data/cards" % id)


static func _kinds(deck: Array[CardData]) -> Array:
	var k: Array = [0, 0, 0]
	for c: CardData in deck:
		k[c.card_type] += 1
	return k


func test_ghost_protector_slide_and_snap() -> void:
	var layout: RefCounted = BoardLayout.new()
	layout.set("tree", tree)
	var setup: Array = await layout._spawn(BoardLayout.PHONE)
	var vp: SubViewport = setup[0]
	var m: Control = setup[1]
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	await tree.process_frame
	var st: MatchState = c.state
	var me: RulesSide = st.sides[0]
	# Two units already in column A, then a Protector selected: its ghost is in row 1.
	var lane: Node = m.get_board().get_lanes()[0]
	var a: RulesUnit = st.create_unit(0, CardDB.get_card(&"rifleman"))
	st.put_in_line(a, 0)
	var b: RulesUnit = st.create_unit(0, CardDB.get_card(&"gunner"))
	st.put_in_line(b, 0)
	var prot := RulesCard.new(st.new_uid(), CardDB.get_card(&"shieldman"))
	me.hand.append(prot)
	me.supply = 10
	c.refresh()
	await tree.create_timer(1.5).timeout  # the two new units finish entering
	c.select_card(prot.uid)
	await tree.process_frame
	var ghost: BannerView = lane.get_ghost()
	assert_not_null(ghost, "landing ghost shown")
	if ghost != null:
		assert_eq(ghost.position.y, BoardMetrics.row_y(lane.metrics, &"player", 0), "Protector ghost in row 1")
	assert_eq(lane.target_text, "TAKES THE FRONT", "Protector badge")
	await tree.create_timer(0.4).timeout
	assert_true(lane.is_ghost_shift(), "your cards preview their shift back (B1)")
	assert_true(lane.get_friendly_slots()[0].banner.position.y > 10.0, "front card moved out from under the ghost")
	# A normal unit's ghost goes to the first free row.
	var rif := RulesCard.new(st.new_uid(), CardDB.get_card(&"rifleman"))
	me.hand.append(rif)
	c.refresh()
	c.select_card(rif.uid)
	await tree.process_frame
	ghost = lane.get_ghost()
	assert_true(ghost != null and is_equal_approx(ghost.position.y, BoardMetrics.row_y(lane.metrics, &"player", 2)), "unit ghost in row 3")
	c.clear_selection()
	await tree.process_frame
	assert_false(lane.is_ghost_shift(), "shift undone when the selection clears")
	await tree.create_timer(0.3).timeout
	# Play the Protector: it lands in row 1 (PLAN); its banner starts away from row 1 and slides.
	c.select_card(prot.uid)
	var res: Dictionary = c.play_at(0)
	assert_true(res["ok"], "Protector planned")
	await tree.process_frame
	# The PLAN entry is the queued arrival behind the line; at Reveal the engine puts it in front.
	st.set_ready(0)
	st.set_ready(1)
	st.reveal()
	c.refresh()
	await tree.process_frame
	var front: Node = lane.get_friendly_slots()[0]
	assert_eq(front.slot_uid, prot.uid, "Protector is the frontline after Reveal")
	assert_true(front.banner.position.y > 1.0, "Protector banner still sliding toward row 1 (%s)" % front.banner.position)
	assert_true(lane.get_friendly_slots()[1].banner.position.y < -1.0, "passed card shifts back later (starts at its old row)")
	await tree.create_timer(2.0).timeout
	assert_true(absf(front.banner.position.y) < 0.5, "settled in row 1")
	# Tap snapping: with enemy units offered as targets, a tap on an empty spot of the rival half
	# picks the nearest target in that half.
	var foe: RulesUnit = st.create_unit(1, CardDB.get_card(&"rifleman"))
	st.put_in_line(foe, 0)
	c.refresh()
	await tree.process_frame
	lane.set_unit_targets([foe.uid])
	var empty_slot: Control = lane.get_enemy_slots()[3]
	var hit: Array = lane._slot_hit(empty_slot.get_global_rect().get_center())
	assert_eq(hit, [&"enemy", foe.uid], "tap snaps to the nearest target in the half")
	var hit2: Array = lane._slot_hit(empty_slot.get_global_rect().get_center(), true)
	assert_eq(hit2[1], -1, "inspect never snaps")
	lane.set_unit_targets([])
	layout._despawn(vp)
	await tree.process_frame


func test_fields_on_the_objective_tile_and_overrun() -> void:
	var layout: RefCounted = BoardLayout.new()
	layout.set("tree", tree)
	var setup: Array = await layout._spawn(BoardLayout.PHONE)
	var vp: SubViewport = setup[0]
	var m: Control = setup[1]
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	await tree.process_frame
	var st: MatchState = c.state
	# A visible Field of yours in column B, the rival holding B: Overrun risk.
	var field := RulesCard.new(st.new_uid(), CardDB.get_card(&"listening_post"))
	st.sides[0].equipment[1].append({"card": field, "round": st.round_number})
	var foe: RulesUnit = st.create_unit(1, CardDB.get_card(&"rifleman"))
	st.put_in_line(foe, 1)
	c.refresh()
	await tree.process_frame
	var lane: Node = m.get_board().get_lanes()[1]
	var tile: Control = lane.get_objective_tile()
	var mine: Array = tile.fields.get("player", [])
	assert_eq(mine.size(), 1, "your Field is on your half of the tile")
	assert_true(bool(mine[0].get("overrun_risk", false)), "overrun risk flagged")
	assert_true(tile.is_processing(), "the OVERRUN tab pulses")
	await tree.process_frame
	# Long-press the chip: the inspector names the Field and explains Overrun in plain words.
	var chip: Array = tile._chip_rects[0] if not tile._chip_rects.is_empty() else []
	assert_false(chip.is_empty(), "chip drawn")
	if not chip.is_empty():
		var at: Vector2 = tile.get_global_transform() * (chip[0] as Rect2).get_center()
		var hit: Array = lane._slot_hit(at, true)
		assert_eq(hit, [&"field_player", field.uid], "chip hit")
		c._on_lane_long_pressed(1, hit[0], hit[1])
		await tree.process_frame
		var insp: Control = m.get_inspector()
		assert_true(insp.is_open(), "field inspector")
		var rules: String = (insp.get_node("%RulesLabel") as Label).text
		assert_true(rules.contains("Overrun: at the end of each round, if the enemy controls this column, this Field is destroyed (hidden traps are exempt)."), "Overrun in plain words: %s" % rules)
		assert_true((insp.get_node("%StatusLabel") as Label).text.contains("OVERRUN RISK"), "status warns")
		insp.close()
	# Objective tile and incoming backs are inspectable too.
	c._on_lane_long_pressed(1, &"objective", -1)
	assert_true(m.get_inspector().is_open(), "objective inspector")
	m.get_inspector().close()
	# The FIELD OVERRUN callout when the engine tears it down.
	c._board_callout({"type": RulesEvent.EQUIPMENT_DESTROYED, "zone": &"mid", "side": &"player", "reason": RulesEvent.FIELD_GONE_OVERRUN})
	var texts: Array = lane.get_node("%FxLayer").find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	assert_true(texts.has("FIELD OVERRUN"), "on-board callout %s" % [texts])
	layout._despawn(vp)
	await tree.process_frame


func test_inspector_shows_the_512_banner_and_rails_inspect() -> void:
	var layout: RefCounted = BoardLayout.new()
	layout.set("tree", tree)
	var setup: Array = await layout._spawn(BoardLayout.PHONE)
	var vp: SubViewport = setup[0]
	var m: Control = setup[1]
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	await tree.process_frame
	var rc: RulesCard = c.state.sides[0].hand[0]
	c._on_card_inspected(rc.uid)
	await tree.process_frame
	var insp: Control = m.get_inspector()
	var banner: BannerView = insp.get_banner()
	assert_not_null(banner, "inspector banner")
	if banner != null:
		assert_eq(banner.size, Vector2(512, 128), "512x128 banner")
		assert_true(banner.has_art(), "banner art")
		assert_true(banner.is_focused(), "animated while focused")
		assert_true(Rect2(Vector2.ZERO, Vector2(vp.size)).encloses(banner.get_global_rect()), "on screen")
	insp.close()
	if banner != null:
		assert_false(banner.is_focused(), "stops when closed")
	for key: StringName in [&"score", &"deck", &"intel", &"supply", &"streak", &"menu", &"preview", &"killfeed", &"hand_tab"]:
		m.rail_inspected.emit(key)
		await tree.process_frame
		assert_true(insp.is_open(), "rail box %s inspectable" % key)
		insp.close()
	layout._despawn(vp)
	await tree.process_frame


func test_qa_bridge_snapshot() -> void:
	var layout: RefCounted = BoardLayout.new()
	layout.set("tree", tree)
	var setup: Array = await layout._spawn(BoardLayout.PHONE)
	var vp: SubViewport = setup[0]
	var bridge: Node = QaBridge.new()
	tree.root.add_child(bridge)
	var d: Dictionary = bridge.snapshot(setup[1])
	assert_true((d["buttons"] as Array).size() > 10, "buttons listed")
	assert_true(d.has("match"), "match block")
	if d.has("match"):
		assert_eq((d["match"]["columns"] as Array).size(), 3, "3 columns")
		assert_true((d["match"]["hand"] as Array).size() > 0, "hand listed")
	bridge.queue_free()
	layout._despawn(vp)
	await tree.process_frame

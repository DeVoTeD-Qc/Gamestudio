# test_ui3.gd
# Purpose: kc-ui3 (the head's pitch-build notes): the Operator card at the start of the hand tray
#   (deploy from it; PLAN / ON BOARD / DOWN states), the killstreak tiles at the top of the tray
#   (charge, READY glow + one-time toast, tap = use, long-press = rules), the CODEX (MENU and Title;
#   filters, alternate arts, tap = inspector, phone tap sizes), the columns' location art backing,
#   the two-row desktop killfeed log, and the Settings save (mirror, SPEED x2).
#   Runs with or without the git-ignored licensed art folder.
# Author: UI/UX Agent (kc-ui3)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const MatchScreen: GDScript = preload("res://scripts/ui/match_screen.gd")
const CodexView: GDScript = preload("res://scripts/ui/codex/codex_view.gd")
const QaBridge: GDScript = preload("res://scripts/qa/qa_bridge.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"
const TITLE_SCENE: String = "res://scenes/Title.tscn"
const EPS: float = 0.6

var _saved_root_size: Vector2i = Vector2i.ZERO


# =============================================================================
# Operator card
# =============================================================================

func test_operator_card_entry_states() -> void:
	var op: Dictionary = {"name": "Kestrel AR-7", "fp": 3, "armor": 7, "armor_max": 7, "zone": "OFF BOARD",
			"on_board": false, "zone_label": "", "row": 0, "planned_zone": "", "respawns": true}
	var e: Dictionary = MatchScreen.operator_card_entry({"operator": op, "operator_can_deploy": true, "deploy_open": true})
	assert_eq([e["state"], e["status"], e["active"]], [&"deploy", "DEPLOY", true], "can deploy: DEPLOY, tap selects")
	var planned: Dictionary = op.duplicate()
	planned["planned_zone"] = "B"
	e = MatchScreen.operator_card_entry({"operator": planned, "deploy_open": true})
	# kc-loadout-clean: placed (or on the board) = DEPLOYED: the card is the ability button.
	assert_eq([e["state"], e["status"]], [&"deployed", "DEPLOYED · B"], "placed this Deploy: DEPLOYED · B")
	var board: Dictionary = op.duplicate()
	board.merge({"on_board": true, "zone_label": "A", "row": 2, "zone": "A, ROW 2"}, true)
	e = MatchScreen.operator_card_entry({"operator": board, "deploy_open": true})
	assert_eq([e["state"], e["status"], e["active"]], [&"deployed", "DEPLOYED · A", true], "on the board: tap = the ability")
	e = MatchScreen.operator_card_entry({"operator": board, "deploy_open": false})
	assert_false(e["active"], "outside Deploy a tap only inspects")
	e = MatchScreen.operator_card_entry({"operator": op, "deploy_open": true})
	assert_eq([e["state"], e["status"], e["active"]], [&"down", "DOWN\nNEXT ROUND", false], "down: respawns next round")
	var no_respawn: Dictionary = op.duplicate()
	no_respawn["respawns"] = false
	e = MatchScreen.operator_card_entry({"operator": no_respawn, "deploy_open": true})
	assert_eq(e["status"], "DOWN\nNO RESPAWN", "Detonator: no respawn")
	assert_true(MatchScreen.operator_card_entry({"operator": {"name": "NO OPERATOR"}}).is_empty(), "no Operator: no card")


func test_operator_card_deploys_from_the_hand() -> void:
	for screen: Dictionary in [Layout.PHONE, Layout.DESKTOP]:
		var s: Array = await _spawn(screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var c: Node = s[2]
		var label: String = screen["name"]
		var hand: Control = m.get_hand()
		var card: Control = hand.get_operator_card()
		assert_not_null(card, "%s Operator card in the tray" % label)
		if card == null:
			_despawn(vp)
			continue
		assert_true(card.is_visible_in_tree(), "%s it shows in Deploy" % label)
		assert_eq(m.get_operator_handle(), card, "%s the card is the Operator's handle" % label)
		assert_eq(hand.get_cards().size(), c.state.sides[0].hand.size(), "%s get_cards() lists hand cards only" % label)
		# kc-layout-a (L3): the Operator card is the hand grid's first card, above UNDO / READY.
		assert_true(card.get_global_rect().end.y <= m.get_ready_button().get_global_rect().position.y + EPS, "%s above READY" % label)
		assert_true(m.get_tray().get_global_rect().grow(EPS).encloses(card.get_global_rect()), "%s inside the tray" % label)
		assert_eq(String(hand.operator_entry["status"]), "DEPLOY", "%s Round 1: DEPLOY" % label)
		assert_true((card.get_node("Glow") as Control).visible, "%s and it glows" % label)
		assert_false(m.get_badge(&"operator").hot, "%s the strip badge does not compete (info only)" % label)
		# Tap it, then a column: the Operator is placed (as from any hand card).
		await _tap(vp, card.get_global_rect().get_center())
		assert_eq(c.selection.get("kind"), &"operator", "%s tap selects the Operator" % label)
		assert_true(hand.operator_selected, "%s the card shows as selected" % label)
		assert_eq(m.get_board().get_lanes()[1].target_text, "PLACE HERE", "%s columns offer the placement" % label)
		await _tap(vp, (m.get_board().get_lanes()[1].get_node("%FriendlyRow") as Control).get_global_rect().get_center())
		assert_eq(c.state.projected_operator_zone(0), 1, "%s placed in B" % label)
		await _frames(2)
		card = hand.get_operator_card()
		assert_eq(String(hand.operator_entry["status"]), "DEPLOYED · B", "%s the card reads DEPLOYED · B" % label)
		assert_false((card.get_node("Glow") as Control).visible, "%s no glow once placed" % label)
		# Long-press / right-click = the Operator's rules.
		_mouse(vp, card.get_global_rect().get_center(), true, MOUSE_BUTTON_RIGHT)
		await _frames(2)
		_mouse(vp, card.get_global_rect().get_center(), false, MOUSE_BUTTON_RIGHT)
		await _frames(2)
		assert_true(m.get_inspector().is_open(), "%s right-click inspects the Operator" % label)
		m.get_inspector().close()
		# Next round: the card reads ON BOARD with its column and row.
		await c.press_ready()
		await _until_presented(c)
		var op: RulesUnit = c.state.sides[0].operator_unit
		if op.is_on_board():
			assert_eq(String(hand.operator_entry["state"]), "deployed", "%s on the board next round" % label)
			assert_true(String(hand.operator_entry["status"]).begins_with("DEPLOYED · B"), "%s DEPLOYED · B (%s)" % [label, hand.operator_entry["status"]])
		else:
			assert_eq(String(hand.operator_entry["state"]), "deploy", "%s down in Round 1: respawns now" % label)
		var qa: Dictionary = _qa(vp, m)
		assert_false((qa["match"]["operator_card"] as Dictionary).is_empty(), "%s QA bridge reports the card" % label)
		# kc-loadout-cut: the card's Supply cost is the cost hex text (the run config's operator_cost);
		# the mini card on the board has no cost to show.
		var qa_op: Dictionary = qa["match"]["operator_card"]
		var want_cost: String = str(c.state.operator_cost()) if c.state.operator_cost() > 0 and not bool(qa_op.get("mini", false)) else ""
		assert_eq(String((qa["match"]["operator_card"] as Dictionary).get("cost", "?")), want_cost, "%s QA bridge: cost hex" % label)
		_despawn(vp)
		await tree.process_frame


# =============================================================================
# Killstreak tiles
# =============================================================================

func test_killstreak_tiles_charge_glow_use_and_rules() -> void:
	for screen: Dictionary in [Layout.PHONE, Layout.DESKTOP]:
		var s: Array = await _spawn(screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var c: Node = s[2]
		var label: String = screen["name"]
		var row: Control = m.get_killstreak_row()
		var me: RulesSide = c.state.sides[0]
		var tiles: Array[Control] = row.get_tiles()
		assert_eq(tiles.size(), me.setup.killstreaks.size(), "%s one tile per killstreak" % label)
		var k: float = Layout.points_per_px(screen)
		# kc-layout-a (L4): the sockets are in the icon strip, under STREAK.
		var strip_r: Rect2 = m.get_badge(&"streak").get_parent().get_global_rect().grow(EPS)
		for t: Control in tiles:
			assert_true(t.is_visible_in_tree(), "%s %s always visible" % [label, t.name])
			assert_true(t.size.y * k >= 44.0 - EPS and t.size.x * k >= 44.0 - EPS, "%s %s is 44 pt+ (%s)" % [label, t.name, t.size])
			assert_true(strip_r.encloses(t.get_global_rect()), "%s %s inside the icon strip" % [label, t.name])
			assert_false(t.get_global_rect().intersects(m.get_hand().get_global_rect().grow(-1.0)) and m.get_hand().get_cards().size() > 0 \
					and t.get_global_rect().intersects((m.get_hand().get_cards()[0] as Control).get_global_rect()), "%s %s clear of the cards" % [label, t.name])
		var first: Dictionary = tiles[0].get_meta(&"entry")
		var id: StringName = StringName(first["id"])
		assert_eq(row.word_for(first), "0/%d" % int(first["threshold"]), "%s charging: 0/%d" % [label, int(first["threshold"])])
		# Earn it (test-only state change), as the Score step would.
		me.streak = int(first["threshold"])
		if not me.streak_tray.has(id):
			me.streak_tray.append(id)
		c.refresh()
		await _frames(2)
		first = row.get_tile(id).get_meta(&"entry")
		if bool(first.get("ready", false)):
			assert_eq(row.word_for(first), "READY", "%s READY" % label)
			assert_true(row.is_ready(first), "%s the tile glows" % label)
			assert_true(m.get_toast_text().contains("ready"), "%s one-time toast: %s" % [label, m.get_toast_text()])
			m.show_toast("x")
			c.refresh()
			await _frames(2)
			assert_eq(m.get_toast_text(), "x", "%s the ready toast shows only once" % label)
			# Tap = use (select it for its target, or call it in at once).
			await _tap(vp, row.get_tile(id).get_global_rect().get_center())
			var used: bool = c.selection.get("kind") == &"item" or me.plays.any(func(p: Dictionary) -> bool: return p["kind"] == &"item")
			assert_true(used, "%s tap uses the killstreak" % label)
			if c.selection.get("kind") == &"item":
				assert_eq(row.selected_id, id, "%s the tile shows it is being targeted" % label)
			c.clear_selection()
		else:
			assert_true(row.word_for(first) != "READY", "%s blocked: says why (%s)" % [label, row.word_for(first)])
		# Long-press / right-click = its rules.
		row.get_tile(id).get_meta(&"gesture").long_pressed.emit(Vector2.ZERO)
		await _frames(3)
		assert_true(m.get_inspector().is_open(), "%s long-press opens its rules" % label)
		assert_eq(String((m.get_inspector().get_node("%TitleLabel") as Label).text), String(c.state.find_item(0, id).display_name), "%s inspector names it" % label)
		m.get_inspector().close()
		_despawn(vp)
		await tree.process_frame


## kc-ks-seq: a called Mortar marks its column INCOMING, its tile says AT FIGHT, and the chip opens
## its rules with when it resolves and where.
func test_called_strike_is_marked_and_inspectable_on_the_phone() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var st: MatchState = c.state
	if st.find_item(0, &"mortar_barrage") == null:
		st.sides[0].setup.killstreaks.append(load("res://data/loadout/mortar_barrage.tres"))
	StreakTracker.grant(st, 0, &"mortar_barrage")
	c.refresh()
	await _frames(2)
	c.select_item(&"mortar_barrage")
	assert_true(c.play_at(1)["ok"], "Mortar called on column B")
	await _frames(4)
	var ks: Control = m.get_fx().ks
	assert_true(ks.banner.visible, "its compact banner shows")
	assert_eq(ks.last_banner.get("mode"), &"called", "CALLED IN")
	assert_eq(ks.pending_keys(), ["player:mortar_barrage:mid"], "INCOMING on column B")
	var tile: Control = m.get_killstreak_row().get_tile(&"mortar_barrage")
	assert_eq(m.get_killstreak_row().word_for(tile.get_meta(&"entry")), "AT FIGHT", "the tile says when it lands")
	var chip: Control = (ks.markers.values()[0] as Control).get(&"chip")
	assert_true(chip.is_visible_in_tree() and chip.get_global_rect().has_area(), "the chip is on the board")
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	chip.gui_input.emit(right)
	await _frames(3)
	assert_true(m.get_inspector().is_open(), "right click opens its rules")
	var status: String = IconText.plain(m.get_inspector().get_node("%StatusLabel"))  # kc-text: an IconText label
	assert_true(status.contains("start of the fight") and status.contains("column B"), "when and where: %s" % status)
	m.get_inspector().close()
	c.undo()
	await _frames(2)
	assert_eq(ks.pending_keys(), [], "UNDO takes the marker away")
	_despawn(vp)
	await tree.process_frame


# =============================================================================
# Codex
# =============================================================================

func test_codex_entries_and_filters() -> void:
	var base: Array[Dictionary] = CodexView.build_entries(false)
	var cards: int = 0
	for card: CardData in CardDB.all_cards():
		if card.collectible:
			cards += 1
	var ks: int = CardDB.loadout_items_by_slot(DataEnums.LoadoutSlot.KILLSTREAK).size()
	assert_eq(base.size(), cards + ks, "one entry per collectible card + per killstreak")
	assert_true(ks >= 3, "killstreaks listed (%d)" % ks)
	# kc-ui4: one tile per unique card; its alternate arts are listed in the entry (ART panel).
	var ids: Dictionary = {}
	for e: Dictionary in base:
		ids[e["id"]] = true
		assert_true((e["arts"] as Array).size() >= 1, "%s lists its arts" % e["id"])
	assert_eq(ids.size(), base.size(), "one entry per unique card")
	var setup: Array = await _spawn_title(Layout.PHONE)
	var vp: SubViewport = setup[0]
	var title: Control = setup[1]
	var cb: Button = title.get_codex_button()
	assert_true(cb != null and cb.is_visible_in_tree(), "Title has a CODEX button")
	await _tap(vp, cb.get_global_rect().get_center())
	await _frames(3)
	var codex: Control = title.get_codex()
	assert_not_null(codex, "CODEX opens the codex")
	if codex == null:
		_despawn(vp)
		return
	assert_true(codex.compact, "phone profile")
	var k: float = Layout.points_per_px(Layout.PHONE)
	var screen_r: Rect2 = Rect2(Vector2.ZERO, Vector2(vp.size)).grow(EPS)
	# kc-deck-match: no weapon-class chips on screen (the head: "leave out the gun type").
	assert_true(codex.get_class_button(&"sniper") == null, "no weapon-class filter chip")
	assert_true(codex.get_type_button(&"tactic").has_meta(&"type_icon") and codex.get_type_button(&"field").has_meta(&"type_icon"),
			"TACTICS / FIELDS chips carry their type icons")
	for b: Button in [codex.get_back_button(), codex.get_type_button(&"killstreak"), codex.get_type_button(&"tactic"),
			codex.get_type_button(&"field"), codex.get_chassis_picker(), codex.get_starter_button()]:
		assert_true(minf(b.size.x, b.size.y) * k >= 44.0 - EPS, "%s is 44 pt+ (%s)" % [b.name, b.size])
	for b: Button in [codex.get_back_button(), codex.get_chassis_picker()]:
		assert_true(screen_r.encloses(b.get_global_rect()), "%s on screen %s / %s" % [b.name, b.get_global_rect(), screen_r])
	assert_eq(codex.get_tiles().size(), codex.filtered().size(), "a tile per entry")
	var first: Control = codex.get_tiles()[0]
	assert_true(first.size.y * k >= 44.0 and screen_r.encloses(first.get_global_rect()), "tiles are big enough and on screen")
	# Type filter.
	await _tap(vp, codex.get_type_button(&"killstreak").get_global_rect().get_center())
	await _frames(2)
	assert_eq(codex.get_tiles().size(), ks, "KILLSTREAKS shows the killstreaks")
	# Class filter (API only now; switches to units).
	codex.set_class_filter(&"sniper")
	await _frames(2)
	assert_eq(codex.type_filter, &"unit", "a class implies units")
	for t: Node in codex.get_tiles():
		var e: Dictionary = t.get_meta(&"entry")
		assert_eq([e["kind"], e["cls"]], [&"unit", &"sniper"], "sniper filter: %s" % e["name"])
	assert_true(codex.get_tiles().size() > 0, "there are sniper units")
	# Chassis filter: one chassis (all its arts).
	var chassis: StringName = StringName((codex.get_tiles()[0] as Node).get_meta(&"entry")["id"])
	codex.set_chassis_filter(chassis)
	await _frames(2)
	for t: Node in codex.get_tiles():
		assert_eq(StringName(t.get_meta(&"entry")["id"]), chassis, "chassis filter")
	codex.clear_filters()
	await _frames(2)
	assert_eq(codex.get_tiles().size(), codex.filtered().size(), "cleared")
	# kc-ui4: tap a card = its ART panel; long-press / right-click = the inspector.
	var tile: Control = codex.get_tiles()[0]
	await _tap(vp, tile.get_global_rect().get_center())
	await _frames(2)
	assert_true(codex.is_art_panel_open(), "tap opens the ART panel")
	codex.close_arts()
	await _frames(2)
	tile = codex.get_tiles()[0]
	codex.open_entry(tile.get_meta(&"entry"))
	await _frames(2)
	assert_true(codex.get_inspector().is_open(), "inspect opens the inspector")
	assert_eq(String((codex.get_inspector().get_node("%TitleLabel") as Label).text), String(tile.get_meta(&"entry")["name"]), "inspector title = tile name")
	var qa: Dictionary = _qa(vp, title)
	assert_true(qa.has("codex") and bool(qa["codex"]["inspector_open"]), "QA bridge reports the codex")
	codex.get_inspector().close()
	codex.get_back_button().pressed.emit()
	await _frames(2)
	assert_true(title.get_codex() == null, "BACK closes it")
	_despawn(vp)
	await tree.process_frame


func test_codex_from_menu_and_every_entry_inspects() -> void:
	var s: Array = await _spawn(Layout.DESKTOP)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	c.open_pause_menu()
	await _frames(2)
	var pause: Control = m.get_pause_menu()
	var cb: Button = pause.get_codex_button()
	assert_true(cb.is_visible_in_tree(), "MENU sheet has CODEX")
	await _tap(vp, cb.get_global_rect().get_center())
	await _frames(3)
	var codex: Control = pause.get_codex()
	assert_not_null(codex, "CODEX opens over the match")
	if codex != null:
		assert_false(codex.compact, "desktop profile")
		for e: Dictionary in codex.filtered():
			codex.open_entry(e)
			assert_true(codex.get_inspector().is_open(), "%s inspects" % e["key"])
			codex.get_inspector().close()
		codex.close()
		await _frames(2)
		assert_true(pause.is_open() and pause.get_codex() == null, "closing returns to the MENU sheet")
	c.close_pause_menu()
	_despawn(vp)
	await tree.process_frame


func test_codex_phone_menu_sheet_fits() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	c.open_pause_menu()
	await _frames(3)
	var pause: Control = m.get_pause_menu()
	var screen_r: Rect2 = Rect2(Vector2.ZERO, Vector2(vp.size)).grow(EPS)
	for b: Button in [pause.get_resume_button(), pause.get_codex_button(), pause.get_quit_button()]:
		assert_true(screen_r.encloses(b.get_global_rect()), "%s on screen %s" % [b.name, b.get_global_rect()])
	assert_false(pause.get_resume_button().get_global_rect().intersects(pause.get_codex_button().get_global_rect()), "RESUME and CODEX side by side")
	c.close_pause_menu()
	_despawn(vp)
	await tree.process_frame


# =============================================================================
# Zone backing, killfeed log, settings
# =============================================================================

func test_columns_show_location_art() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var keys: Array = []
	for lane: Node in m.get_board().get_lanes():
		var b: TextureRect = lane.get_backing()
		assert_not_null(b, "%s has location art" % lane.name)
		if b == null:
			continue
		keys.append(b.get_meta(&"lane_key"))
		assert_true(b.self_modulate.a <= 0.4, "subtle (alpha %.2f)" % b.self_modulate.a)
		assert_true(b.self_modulate.r < 0.8, "darkened")
		assert_eq(b.get_index(), 0, "behind every slot")
		assert_true(b.get_global_rect().grow(EPS).encloses((lane.get_friendly_slots()[3] as Control).get_global_rect()), "covers the column")
		assert_false(String(b.texture.resource_path).contains("licensed"), "public art only")
	assert_eq(keys.size(), 3, "three columns")
	assert_true(keys[0] != keys[1] and keys[1] != keys[2], "each column its own location %s" % [keys])
	_despawn(vp)
	await tree.process_frame


func test_desktop_killfeed_log_wraps_names_to_two_rows() -> void:
	for screen: Dictionary in [Layout.DESKTOP, Layout.PHONE]:
		var s: Array = await _spawn(screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var feed: Control = m.get_killfeed()
		assert_eq(feed.two_line, not m.compact, "%s two rows only on the narrow desktop tray" % screen["name"])
		m.set_tray_state(MatchScreen.TRAY_CLOSED)
		await _frames(2)
		var line: Control = feed.push({"attacker": "Demolitions Expert", "attacker_side": &"player", "victim": "Kestrel AR-7",
				"victim_side": &"enemy", "icon": &"class_lmg", "zone": &"left"})
		await _frames(3)
		var names: PackedStringArray = []
		for l: Node in line.find_children("*", "Label", true, false):
			if (l as Label).theme_type_variation in [&"KillfeedFriend", &"KillfeedEnemy"]:
				names.append((l as Label).text)
		if feed.two_line:
			assert_eq(line.size.y, 44.0, "two rows of 22 px")
			assert_eq(names, PackedStringArray(["DEMOLITIONS EX", "KESTREL AR-7"]), "names keep 14 letters, not 8")
		var r: Rect2 = m.get_killfeed_rect().grow(EPS)
		assert_true(r.encloses(line.get_global_rect()), "%s the line fits the log" % screen["name"])
		_despawn(vp)
		await tree.process_frame


func test_settings_save_mirror_and_speed() -> void:
	var path: String = "user://kc_ui3_settings_test.cfg"
	var was: Array = [Settings.mirror_layout, Settings.speed_x2, Settings.fast_animations]
	Settings.mirror_layout = true
	Settings.speed_x2 = true
	Settings.fast_animations = false
	assert_eq(Settings.save_to(path), OK, "saved")
	Settings.mirror_layout = false
	Settings.speed_x2 = false
	assert_true(Settings.load_from(path), "loaded")
	assert_eq([Settings.mirror_layout, Settings.speed_x2], [true, true], "mirror and SPEED x2 come back")
	assert_false(Settings.load_from("user://kc_ui3_missing.cfg"), "a missing file keeps the values")
	assert_eq([Settings.mirror_layout, Settings.speed_x2], [true, true], "unchanged")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# The match screen's SPEED toggle starts from the setting and writes it back.
	Settings.mirror_layout = false
	var was_chosen: bool = Settings.speed_chosen
	Settings.speed_chosen = true  # kc-fight-ui: a speed picked with the toggle (else x1 by default)
	var s: Array = await _spawn(Layout.DESKTOP)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	assert_true(m.get_speed_button().button_pressed, "SPEED x2 restored on a new match")
	assert_eq(m.get_speed_button().text, "SPEED x2", "and labelled")
	m.get_speed_button().button_pressed = false
	assert_false(Settings.speed_x2, "toggling it updates the setting")
	_despawn(vp)
	await tree.process_frame
	Settings.mirror_layout = was[0]
	Settings.speed_x2 = was[1]
	Settings.speed_chosen = was_chosen
	Settings.fast_animations = was[2]


# =============================================================================
# Mulligan: full cards
# =============================================================================

func test_mulligan_shows_full_cards_and_inspects() -> void:
	for screen: Dictionary in [Layout.PHONE, Layout.DESKTOP]:
		var s: Array = await _spawn(screen, false)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var c: Node = s[2]
		var label: String = screen["name"]
		assert_true(c.is_mulligan_open(), "%s Round 1 mulligan" % label)
		var panel: Control = m.get_mulligan_panel()
		var buttons: Array[Node] = panel.get_card_buttons()
		var me: RulesSide = c.state.sides[0]
		assert_eq(buttons.size(), me.hand.size(), "%s one card per hand card" % label)
		var screen_r: Rect2 = Rect2(Vector2.ZERO, Vector2(vp.size)).grow(EPS)
		var k: float = Layout.points_per_px(screen)
		for i: int in buttons.size():
			var b: Control = buttons[i]
			assert_true(panel.has_full_card(b), "%s full card face" % label)
			var view: CardView = b.get_meta(&"card_view")
			assert_eq(String(view.data.get("id", "")), String(me.hand[i].card.id), "%s card %d is %s" % [label, i, me.hand[i].card.id])
			assert_eq(String(view.data.get("text", "")), me.hand[i].card.text, "%s with its rules text" % label)
			assert_true(screen_r.encloses(b.get_global_rect()), "%s on screen %s" % [label, b.get_global_rect()])
			assert_true(b.get_global_rect().grow(EPS).encloses(view.get_global_rect()), "%s the card face sits inside its toggle" % label)
			# Readable: the card is at least ~0.65x of the 250x350 face (name >= 11 pt on a phone).
			assert_true(view.scale.x >= 0.8 - 0.001, "%s card scale %.2f (>= the inspector's 0.8x)" % [label, view.scale.x])
			var name_pt: float = view.get_min_effective_font_size(PackedStringArray(["NameLabel", "CostLabel", "FirepowerLabel", "ArmorLabel"])) * k
			assert_true(name_pt >= 11.0 - 0.01, "%s name / cost / stats %.1f pt" % [label, name_pt])
			if i > 0:
				assert_false(b.get_global_rect().intersects((buttons[i - 1] as Control).get_global_rect()), "%s cards don't overlap" % label)
		for b: Button in [panel.get_keep_button(), panel.get_confirm_button()]:
			assert_true(screen_r.encloses(b.get_global_rect()) and b.size.y * k >= 44.0 - EPS, "%s %s on screen, 44 pt+" % [label, b.name])
		# Right-click (desktop) / long-press = the inspector, not a toggle.
		var first: Button = buttons[0]
		_mouse(vp, first.get_global_rect().get_center(), true, MOUSE_BUTTON_RIGHT)
		await _frames(1)
		_mouse(vp, first.get_global_rect().get_center(), false, MOUSE_BUTTON_RIGHT)
		await _frames(3)
		assert_true(m.get_inspector().is_open(), "%s right-click inspects the card" % label)
		assert_false(first.button_pressed, "%s and does not mark it" % label)
		m.get_inspector().close()
		await _frames(1)
		# Tap marks it (PUT BACK).
		await _tap(vp, first.get_global_rect().get_center())
		assert_true(first.button_pressed and (first.get_node("PutBack") as Control).visible, "%s tap marks PUT BACK" % label)
		c.keep_hand()
		_despawn(vp)
		await tree.process_frame


# =============================================================================
# Name: KillingCard everywhere a player can read it
# =============================================================================

## Phrases that use "Killstreak" as the GAME's name (the killstreak mechanic keeps its word: ids like
## "killstreak" and slot labels like "Killstreak" are fine; the old all-caps wordmark is not).
const GAME_NAME_PATTERNS: PackedStringArray = [
	"^\\s*KILLSTREAK\\s*$",
	"(?i)kill<span>streak",
	"(?i)\\b(test|play|playing|welcome to|about|of)\\s+killstreak\\b(?!s)",
	"(?i)\\bkillstreak\\s+(needs|plays|playtest|web|is a|prototype|\\(working title\\)|·\\s*tactical|- tactical)",
]


func test_the_game_is_called_killingcard() -> void:
	assert_eq(String(ProjectSettings.get_setting("application/config/name")), "KillingCard", "project name")
	assert_false(String(ProjectSettings.get_setting("application/config/description")).to_lower().contains("killstreak"), "project description")
	# The web shell (loading screen, rotate notice, page title): no Killstreak in any visible text.
	var html: String = FileAccess.get_file_as_string("res://web/shell.html")
	assert_true(html.contains("<title>KillingCard</title>"), "page title KillingCard (the artifact's title)")
	var body: String = html.substr(html.find("<body"))
	var visible: String = RegEx.create_from_string("(?s)<script.*?</script>|<style.*?</style>|<!--.*?-->|<[^>]+>").sub(body, " ", true)
	assert_false(visible.to_lower().contains("killstreak"), "web shell text never says Killstreak")
	assert_true(RegEx.create_from_string("(?i)killing\\s*<span>\\s*card").search(html) != null, "loading screen wordmark KillingCard")
	# Every string in scenes and scripts: no game-name use of Killstreak.
	var regs: Array[RegEx] = []
	for pat: String in GAME_NAME_PATTERNS:
		regs.append(RegEx.create_from_string(pat))
	var literal: RegEx = RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	var bad: PackedStringArray = []
	for path: String in _files("res://scenes", ["tscn"]) + _files("res://scripts", ["gd"]) + _files("res://autoload", ["gd"]):
		var text: String = FileAccess.get_file_as_string(path)
		for m: RegExMatch in literal.search_all(text):
			var str_val: String = m.get_string(1)
			for r: RegEx in regs:
				if r.search(str_val) != null:
					bad.append("%s: \"%s\"" % [path, str_val])
	assert_eq(bad, PackedStringArray(), "player-facing strings still naming the game Killstreak")
	var title: PackedScene = load(TITLE_SCENE)
	var t: Node = title.instantiate()
	assert_eq(String((t.find_child("TitleLabel", true, false) as Label).text), "KILLINGCARD", "title wordmark")
	t.free()


func _files(dir: String, exts: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.get_extension() in exts:
			out.append(dir.path_join(f))
	for sub: String in d.get_directories():
		out.append_array(_files(dir.path_join(sub), exts))
	return out


# =============================================================================
# Helpers
# =============================================================================

func _spawn(screen: Dictionary, keep_hand: bool = true) -> Array:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(Layout.logical_size(screen))
	vp.disable_3d = true
	vp.handle_input_locally = true
	tree.root.add_child(vp)
	var m: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
	vp.add_child(m)
	await _frames(4)
	var c: Node = m.get_node("%MatchController")
	assert_not_null(c.state, "%s live match started" % screen["name"])
	if keep_hand and c.is_mulligan_open():
		c.keep_hand()
		await _frames(2)
	return [vp, m, c]


func _spawn_title(screen: Dictionary) -> Array:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(Layout.logical_size(screen))
	vp.disable_3d = true
	vp.handle_input_locally = true
	tree.root.add_child(vp)
	var t: Control = (load(TITLE_SCENE) as PackedScene).instantiate()
	vp.add_child(t)
	await _frames(4)
	return [vp, t]


## The QA bridge's snapshot (the bridge must be in the tree to look up the autoloads).
func _qa(vp: SubViewport, scene: Node) -> Dictionary:
	var bridge: Node = QaBridge.new()
	bridge.set_process(false)
	vp.add_child(bridge)
	var out: Dictionary = bridge.snapshot(scene)
	bridge.queue_free()
	return out


func _despawn(vp: SubViewport) -> void:
	vp.queue_free()
	tree.root.size = _saved_root_size


func _until_presented(c: Node, max_s: float = 30.0) -> void:
	var t0: int = Time.get_ticks_msec()
	while c.is_busy() and Time.get_ticks_msec() - t0 < int(max_s * 1000.0):
		await _frames(1)
	await _frames(2)


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _mouse(vp: SubViewport, pos: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	vp.push_input(e)


func _tap(vp: SubViewport, pos: Vector2) -> void:
	_mouse(vp, pos, true)
	await _frames(1)
	_mouse(vp, pos, false)
	await _frames(3)

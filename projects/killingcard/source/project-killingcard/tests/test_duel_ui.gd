# test_duel_ui.gd
# Purpose: kc-duel-ui (duel-mode.md §4-§7, duel-api.md). The Duel screens on the REAL DuelState (no
#   silent fallback): the adapter reads DuelState's presets / heroes / validator; a deck is built in
#   the builder by taps, validated by the rules, saved in the profile and started vs AI; Match.tscn plays
#   the DuelMatch; Pass & Play raises the cover between the two private Deploys. Layout checks run at
#   phone landscape (844x390), phone portrait (390x844) and iPad (1180x820): every tile inspectable,
#   tap targets >= 44 pt, red lines block PLAY, "what just happened" lines after every action.
# Author: UI/UX Agent (kc-duel-ui)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const DuelViews: GDScript = preload("res://scripts/ui/duel/duel_views.gd")
const DuelFlow: GDScript = preload("res://scripts/ui/duel/duel_flow.gd")
const PORTRAIT: Dictionary = {"name": "iPhone 390x844 portrait", "pt": Vector2(390, 844), "ratio": 3.0}
const IPAD: Dictionary = {"name": "iPad 1180x820", "pt": Vector2(1180, 820), "ratio": 2.0}
const OPEN_IDS: Array[StringName] = [&"rifleman", &"brawler", &"point_man", &"shieldman", &"gunner", &"marksman",
		&"ammo_resupply", &"flank_route", &"blackout", &"hold_the_line"]

var _vp: SubViewport = null
var _saved: Dictionary = {}


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _screens() -> Array[Dictionary]:
	return [Layout.PHONE, PORTRAIT, IPAD]


func _begin() -> void:
	var st: Node = tree.root.get_node("Settings")
	var router: Node = tree.root.get_node("SceneRouter")
	_saved = {"profile": st.run_profile.duplicate(true), "persist": st.persist, "dry": router.dry_run}
	st.persist = false
	st.run_profile = RunProfile.blank()
	router.dry_run = true
	DuelViews.reset_local()
	DuelViews.set_local_saves(false)
	DuelViews.set_use_rules(true)


func _end() -> void:
	_close()
	var st: Node = tree.root.get_node("Settings")
	st.run_profile = _saved["profile"]
	st.persist = _saved["persist"]
	tree.root.get_node("SceneRouter").dry_run = _saved["dry"]
	DuelFlow.set_dry_run(false)
	DuelFlow.set_setup({})
	DuelViews.reset_local()
	var ds: Node = tree.root.get_node_or_null("DuelState")
	if ds != null:
		ds.set(&"current", null)


func _open(path: String, screen: Dictionary) -> Control:
	_close()
	_vp = SubViewport.new()
	_vp.size = Vector2i(Layout.logical_size(screen))
	_vp.disable_3d = true
	_vp.handle_input_locally = true
	tree.root.add_child(_vp)
	var node: Control = (load(path) as PackedScene).instantiate()
	_vp.add_child(node)
	await _frames(8)
	return node


func _close() -> void:
	if _vp != null:
		_vp.free()
		_vp = null


## Points per logical px on this screen (tap targets: 64 px ~ 46 pt).
func _pt(screen: Dictionary) -> float:
	return ScreenProfile.points_per_px(screen["pt"] * float(screen["ratio"]), screen["ratio"])


func _deck(ids: Array[StringName] = OPEN_IDS, hero: StringName = &"kestrel_ar7") -> Dictionary:
	var d: Dictionary = DuelViews.new_deck(hero)
	for id: StringName in ids:
		d["picks"].append(DuelViews.make_pick(id))
	return d


# =============================================================================
# The adapter reads the real rules
# =============================================================================

func test_views_read_duel_state_not_the_fallback() -> void:
	_begin()
	assert_not_null(DuelViews.state(), "DuelState autoload is there and used")
	var ids: Array = DuelViews.presets().map(func(d: Dictionary) -> String: return String(d["id"]))
	assert_eq(ids, ["spearhead", "overwatch", "iron_wall", "hollow_ranks"], "the rules' preset ids")
	for d: Dictionary in DuelViews.presets():
		assert_eq(DuelViews.pick_ids(d).size(), 10, "%s has 10 picks" % d["name"])
		assert_true(bool(DuelViews.validate(d)["ok"]), "%s is legal (a loaner)" % d["name"])
		assert_true(String(d["plan"]) != "", "%s has its plan line" % d["name"])
	assert_eq(DuelViews.heroes().size(), 4, "4 heroes")
	for h: Dictionary in DuelViews.heroes():
		var item: LoadoutItem = load("res://data/loadout/%s.tres" % h["id"])
		assert_eq([h["fp"], h["armor"]], [item.operator_firepower, item.operator_armor], "D4: %s shows the shared numbers" % h["name"])
		assert_true(bool(h["unlocked"]), "D3: %s always playable" % h["name"])
	# The rules' validator, its codes and its fix filters.
	var r: Dictionary = DuelViews.validate(_deck(OPEN_IDS.slice(0, 4)))
	assert_false(bool(r["ok"]), "4 picks is not a deck")
	var codes: Array = r["errors"].map(func(e: Dictionary) -> StringName: return e["code"])
	assert_true(&"picks_short" in codes and &"unit_min" in codes, "rules codes: %s" % [codes])
	var unit_line: Dictionary = r["errors"].filter(func(e: Dictionary) -> bool: return e["code"] == &"unit_min")[0]
	assert_eq(unit_line["fix"].get("kind"), &"unit", "fix_filter type -> the grid's kind filter")
	# A Field nobody found is locked for your own deck (D3) but not in a preset.
	var c: CardData = DuelViews.card(&"mortar_pit")
	assert_false(DuelViews.is_owned(c), "a fresh profile hasn't found Mortar Pit")
	var with_field: Dictionary = _deck()
	with_field["picks"][9] = DuelViews.make_pick(&"mortar_pit")
	var codes2: Array = DuelViews.validate(with_field)["errors"].map(func(e: Dictionary) -> StringName: return e["code"])
	assert_true(&"locked_card" in codes2, "locked card is a red line: %s" % [codes2])
	# The adapter's deck <-> rules conversion keeps arts (and so traits).
	var d: Dictionary = _deck()
	d["picks"][0] = DuelViews.make_pick(&"rifleman", &"undead")
	var back: Dictionary = DuelViews.from_rules(DuelViews.to_deck(d).to_dict())
	assert_eq(DuelViews.trait_of(back["picks"][0]), &"undead", "a pick's art survives to_rules / from_rules")
	_end()


# =============================================================================
# The real flow: build by taps -> validate -> save -> start vs AI -> Match.tscn plays it
# =============================================================================

func test_build_save_and_start_vs_ai_on_duel_state() -> void:
	_begin()
	DuelFlow.set_edit_deck(DuelViews.new_deck(&"wasp_9"))
	var b: Control = await _open(DuelFlow.SCENE_BUILDER, Layout.PHONE)
	assert_eq(b.get_counter().text, "0/10 PICKS", "empty deck")
	assert_true(bool(b.get_play_button().get_meta(&"blocked")), "PLAY blocked while empty")
	assert_true(b.get_play_button().text.contains("PICK 10 MORE"), "PLAY names the first red line: %s" % b.get_play_button().text)
	for id: StringName in OPEN_IDS:
		var t: Button = b.get_tile(id)
		assert_not_null(t, "tile for %s" % id)
		var r: Dictionary = b.tap_card(id)
		assert_true(bool(r["ok"]), "tap adds %s" % id)
	await _frames(2)
	assert_eq(b.get_counter().text, "10/10 PICKS", "10 picks")
	assert_true(b.last_feedback().contains("10/10"), "what just happened: %s" % b.last_feedback())
	assert_eq(String(b.get_tile(&"rifleman").get_meta(&"state")), "picked", "a picked tile says IN DECK")
	var r11: Dictionary = b.add_card(&"breacher")
	assert_false(bool(r11["ok"]), "an 11th pick is refused")
	assert_true(String(r11["text"]).contains("10/10"), "...and says why: %s" % r11["text"])
	assert_false(bool(b.get_play_button().get_meta(&"blocked")), "a legal deck can PLAY")
	var copies: int = 0
	for n: int in DuelViews.curve(b.deck):
		copies += n
	assert_eq(copies, 20, "the curve counts 20 copies")
	var sv: Dictionary = b.save()
	assert_true(bool(sv["ok"]), "saved: %s" % sv)
	var ds: Node = tree.root.get_node("DuelState")
	var saved: Array = ds.decks()
	assert_eq(saved.size(), 1, "DuelState holds the deck")
	assert_eq(String(saved[0]["hero_id"]), "wasp_9", "with its hero")
	assert_true(bool(saved[0]["ok"]), "and the rules call it READY")
	# PLAY -> the hub's VS AI setup with this deck.
	var pr: Dictionary = b.play()
	assert_true(bool(pr["ok"]), "PLAY with a legal deck")
	var hub: Control = await _open(DuelFlow.SCENE_HUB, Layout.PHONE)
	await _frames(4)
	var sheet: Dictionary = hub.get_sheet()
	assert_false(sheet.is_empty(), "PLAY opens the VS AI setup")
	hub.opponent_id = "iron_wall"
	hub.tier = &"recruit"
	var st: Dictionary = hub.start_vs_ai()
	assert_true(bool(st["ok"]), "vs AI starts: %s" % st)
	var m: Object = DuelFlow.pending
	assert_not_null(m, "a match is waiting")
	assert_true(m is DuelMatch, "it is DuelState's DuelMatch, not a fallback")
	assert_eq(StringName(m.get(&"kind")), &"ai", "vs AI")
	assert_eq(m.get(&"decks")[1].id, &"iron_wall", "against the chosen preset")
	assert_eq(tree.root.get_node("SceneRouter").last_requested, DuelFlow.SCENE_MATCH, "opens the match screen")
	# Match.tscn takes it and plays round 1 vs the tier AI.
	var screen: Control = await _open("res://scenes/Match.tscn", Layout.PHONE)
	await _frames(6)
	var c: Node = screen.get_node("MatchController")
	assert_true(c.is_duel(), "the controller plays the duel")
	assert_eq(c.state, m.get(&"state"), "the DuelMatch's MatchState")
	assert_eq(c.state.phase, MatchState.Phase.DEPLOY, "round 1 Deploy is open")
	if c.is_mulligan_open():
		c.keep_hand()
		await _frames(2)
	await c.press_ready()
	await _frames(2)
	assert_true(c.state.round_number >= 2 or c.state.phase == MatchState.Phase.ENDED, "round 1 resolved")
	# Forfeit: the duel ends on its own result screen with the rules' record.
	c.forfeit()
	await _frames(4)
	assert_eq(tree.root.get_node("SceneRouter").last_requested, DuelFlow.SCENE_RESULT, "a duel ends on the result screen")
	assert_eq(int(DuelFlow.last_result["result"]["winner_side"]), 1, "a forfeit is a loss")
	var rec: Dictionary = ds.records()
	assert_eq(int(rec["heroes"].get(&"wasp_9", rec["heroes"].get("wasp_9", {})).get("l", 0)), 1, "DuelState recorded the loss")
	var res: Control = await _open(DuelFlow.SCENE_RESULT, Layout.PHONE)
	assert_eq(res.get_headline(), "DEFEAT", "the result says so")
	_end()


# =============================================================================
# Pass & Play: the cover between the two private Deploys
# =============================================================================

func test_pass_and_play_cover_hides_hands_and_alternates() -> void:
	_begin()
	var hub: Control = await _open(DuelFlow.SCENE_HUB, PORTRAIT)
	hub.open_hot_seat()
	hub.seat_names[0] = "Alex"
	hub.seat_names[1] = "Dana"
	var r: Dictionary = hub.start_hot_seat()
	assert_true(bool(r["ok"]), "hot seat starts: %s" % r)
	assert_true(DuelFlow.pending is DuelMatch, "a DuelState DuelMatch")
	var screen: Control = await _open("res://scenes/Match.tscn", PORTRAIT)
	await _frames(6)
	var c: Node = screen.get_node("MatchController")
	assert_true(c.is_hot_seat(), "Pass & Play")
	var cover: Control = c.get_cover()
	assert_not_null(cover, "a cover before the first Deploy")
	assert_true(cover.visible, "cover up")
	var dm: Object = c.duel
	var first: int = int(dm.get(&"cover_side"))
	var first_name: String = String(dm.get(&"names")[first])
	assert_eq(cover.get_title_text(), "PASS TO %s" % first_name.to_upper(), "names the player")
	# The cover covers the whole screen with an opaque layer (no hand can show through).
	var opaque: ColorRect = cover.get_node("Opaque")
	assert_eq(opaque.color.a, 1.0, "opaque")
	assert_eq(cover.get_global_rect().size, screen.get_global_rect().size, "full screen")
	assert_true(cover.get_index() == cover.get_parent().get_child_count() - 1, "on top")
	assert_true(cover.get_button().size.y * _pt(PORTRAIT) >= 44.0, "the reveal button is a 44 pt target")
	cover.accept()
	await _frames(4)
	assert_false(cover.visible, "tapped through")
	assert_eq(c.me_side, first, "the screen turned to that player")
	if c.is_mulligan_open():
		c.keep_hand()
		await _frames(2)
	await c.press_ready()
	await _frames(4)
	var second: int = 1 - first
	assert_true(cover.visible, "the other player's cover comes up after READY")
	assert_eq(int(dm.get(&"cover_side")), second, "for the other side")
	assert_true((cover.find_child("CoverInfo", true, false) as Label).text.contains("order"), "says the first player's orders are placed (hidden)")
	cover.accept()
	await _frames(4)
	assert_eq(c.me_side, second, "now the second player's view")
	if c.is_mulligan_open():
		c.keep_hand()
		await _frames(2)
	await c.press_ready()
	await _frames(6)
	assert_eq(c.state.round_number, 2, "both ready: round 1 played")
	assert_true(cover.visible, "round 2 starts behind a cover")
	assert_eq(int(dm.get(&"cover_side")), second, "the first deployer alternates")
	assert_true(String(cover.find_child("CoverLast", true, false).text).contains("After round 1"), "the cover says what happened")
	_end()


# =============================================================================
# Layout on the three screens
# =============================================================================

func test_builder_layout_and_inspect_on_three_screens() -> void:
	_begin()
	for screen: Dictionary in _screens():
		var d: Dictionary = _deck(OPEN_IDS.slice(0, 7))
		d["picks"].append(DuelViews.make_pick(&"halek_wren"))
		DuelFlow.set_edit_deck(d)
		var b: Control = await _open(DuelFlow.SCENE_BUILDER, screen)
		await _frames(4)
		var tag: String = screen["name"]
		var vr: Rect2 = Rect2(Vector2.ZERO, Vector2(_vp.size))
		assert_eq(b.get_counter().text, "8/10 PICKS", "%s: counter" % tag)
		assert_true(vr.encloses(b.get_play_button().get_global_rect().grow(-1)), "%s: PLAY on screen" % tag)
		assert_true(vr.encloses(b.get_counter().get_global_rect().grow(-1)), "%s: counter on screen" % tag)
		assert_true(b.get_play_button().size.y * _pt(screen) >= 44.0, "%s: PLAY >= 44 pt" % tag)
		var tiles: Array[Node] = b.get_tiles()
		assert_true(tiles.size() >= 20, "%s: the pool (%d tiles)" % [tag, tiles.size()])
		for t: Node in tiles:
			assert_true((t as Control).has_meta(&"gesture"), "%s: %s is inspectable" % [tag, t.name])
		var lines: Array[Node] = b.get_rule_lines()
		assert_true(lines.size() >= 1, "%s: rule lines" % tag)
		assert_eq(StringName(lines[0].get_meta(&"level")), &"error", "%s: a red line first (2 picks to go)" % tag)
		# Long press = the card; the curve bar and hero strip too.
		b.inspect_card(&"halek_wren")
		await _frames(3)
		assert_true(b.inspector().is_open(), "%s: card inspector" % tag)
		b.inspector().close()
		assert_true(b.get_curve().get_bar(0).get_meta(&"inspectable", false), "%s: curve bars inspectable" % tag)
		assert_true(b.get_hero_strip().get_meta(&"inspectable", false), "%s: hero inspectable" % tag)
		assert_true(b.get_doctrine_strip().get_meta(&"inspectable", false), "%s: Doctrine inspectable" % tag)
		# Pickers open over the screen.
		var hp: Dictionary = b.open_hero_picker()
		await _frames(2)
		assert_eq(hp["body"].get_node("HeroGrid").get_child_count(), 4, "%s: 4 heroes" % tag)
		hp["root"].free()
		var dp: Dictionary = b.open_doctrine_picker()
		await _frames(2)
		assert_eq(dp["body"].get_child_count(), 5, "%s: 4 traits + none" % tag)
		dp["root"].free()
		b.set_doctrine(&"vanguard")
		assert_true(b.last_feedback().contains("Vanguard"), "%s: Doctrine change said" % tag)
		# Remove + UNDO.
		b.remove_card(&"rifleman")
		assert_true(b.last_feedback().begins_with("Removed Rifleman"), "%s: removal said" % tag)
		assert_true(b.get_snack_undo().visible, "%s: UNDO offered" % tag)
		b.undo_remove()
		assert_true(DuelViews.has_pick(b.deck, &"rifleman"), "%s: UNDO puts it back" % tag)
		# A rule-line fix filters the grid.
		b.apply_fix({"kind": &"tactic"})
		for t: Node in b.get_tiles():
			assert_eq(DuelViews.kind_of(DuelViews.card(t.get_meta(&"card"))), &"tactic", "%s: fix -> tactics only" % tag)
		b.clear_filters()
		b.set_search("rif")
		assert_eq(b.get_tiles().size(), 1, "%s: search" % tag)
	_end()


func test_hub_tiles_sheets_and_result_on_three_screens() -> void:
	_begin()
	var ds: Node = tree.root.get_node("DuelState")
	var dd: DuelDeck = DuelViews.to_deck(_deck())
	dd.display_name = "Test deck"
	ds.save_deck(dd)
	for screen: Dictionary in _screens():
		var tag: String = screen["name"]
		DuelFlow.set_hub_tab("mine")
		var hub: Control = await _open(DuelFlow.SCENE_HUB, screen)
		var vr: Rect2 = Rect2(Vector2.ZERO, Vector2(_vp.size))
		assert_true(vr.encloses(hub.get_vs_ai_button().get_global_rect().grow(-1)), "%s: VS AI on screen" % tag)
		assert_true(vr.encloses(hub.get_hot_seat_button().get_global_rect().grow(-1)), "%s: PASS & PLAY on screen" % tag)
		assert_eq(hub.get_tiles().size(), 2, "%s: 1 deck + NEW DECK" % tag)
		var tile: Control = hub.get_tiles()[0]
		assert_true(tile.get_meta(&"inspectable", false), "%s: deck tile inspectable" % tag)
		assert_not_null(tile.find_child("StatusChip", true, false), "%s: READY chip" % tag)
		hub.set_tab("presets")
		assert_eq(hub.get_tiles().size(), 4, "%s: 4 presets" % tag)
		var s: Dictionary = hub.open_vs_ai()
		await _frames(2)
		assert_eq(s["body"].get_node("Opponents").get_child_count(), 5, "%s: 4 presets + Random" % tag)
		assert_eq(s["body"].get_node("Tiers").get_child_count(), 3, "%s: 3 tiers" % tag)
		var cp: Dictionary = hub.copy_deck(DuelViews.preset("iron_wall"))
		assert_true(bool(cp["ok"]), "%s: copy a preset" % tag)
		assert_true(hub.status_text().contains("Iron Wall"), "%s: copy said" % tag)
		DuelViews.delete_deck(String(cp["id"]))
	DuelFlow.set_setup({"mode": DuelFlow.MODE_HOT_SEAT, "decks": [_deck(), DuelViews.preset("spearhead")], "names": ["Alex", "Dana"]})
	DuelFlow.set_last_result({"result": {"kind": &"hot_seat", "winner_side": 1, "scores": [3, 6], "rounds": 7, "reason": &"target",
			"names": ["Alex", "Dana"]}, "records": {"hot_seat_games": 2}, "new_cosmetics": []})
	for screen: Dictionary in _screens():
		var res: Control = await _open(DuelFlow.SCENE_RESULT, screen)
		assert_eq(res.get_headline(), "DANA WINS", "%s: hot seat headline" % screen["name"])
		var acts: Node = res.find_child("Actions", true, false)
		for bt: Node in acts.get_children():
			assert_true(Rect2(Vector2.ZERO, Vector2(_vp.size)).encloses((bt as Control).get_global_rect().grow(-1)), "%s: %s on screen" % [screen["name"], bt.name])
	_end()


func test_title_has_duel_next_to_the_campaign() -> void:
	_begin()
	var t: Control = await _open("res://scenes/Title.tscn", Layout.PHONE)
	var b: Button = t.get_duel_button()
	assert_not_null(b, "DUEL button")
	assert_eq(b.get_parent(), t.get_node("%StartButton").get_parent(), "beside START NEW RUN (the campaign)")
	b.pressed.emit()
	assert_eq(tree.root.get_node("SceneRouter").last_requested, DuelFlow.SCENE_HUB, "opens the hub")
	_end()

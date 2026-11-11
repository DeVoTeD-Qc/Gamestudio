# test_onboard_ui.gd
# Purpose: kc-onboard-ui, the "simple first run" on screen (onboarding-progression.md §2.2, §3, §5,
#   §8 steps 5-6; head W1 / Z1 / Z2 / Z3):
#   - Standard Issue cards: the plain frame, the serial plate "SI-0n" in the abilities slot (red on
#     the rival's side), an empty trait socket, the stencil font on the name only;
#   - kc-ipad-cards (kc-no-training): no Recruit, no locked keywords, level badge or camo band;
#   - W1: board banners show the cost but not the name; hand cards keep cost + name;
#   - the initiative chip and the SCORE flag: who goes first this round, and why (behind / tie),
#     inspectable by long press / right click; the rule itself is read, never changed;
#   - progressive reveal: the trait rail and link ticks hide until met or in use; the Engine part
#     of the deck view waits for its reveal flag;
#   - the "New: X" explainer: shown once for a met system, GOT IT marks it seen, RESET TIPS (MENU)
#     clears the profile; long press / right click says what it is;
#   - the tutorial and TrainingBot_01 play Standard Issue cards;
#   - the new kit slots fall back to code drawing while the art is missing.
#   The profile's reveal flags and RevealGate / NewCard statics are saved and restored per test.
# Author: UI/UX Agent (kc-onboard-ui)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const MatchSnapshot: GDScript = preload("res://scripts/ui/match_snapshot.gd")
const EnginePanel: GDScript = preload("res://scripts/ui/run/engine_panel.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"

var _saved: Dictionary = {}
var _saved_root_size: Vector2i = Vector2i.ZERO


func _save_profile() -> void:
	var st: Node = tree.root.get_node("Settings")
	_saved = {"met": st.met_flags.duplicate(), "seen": st.seen_flags.duplicate(), "gate": RevealGate.active,
			"auto": NewCard.auto_show}
	st.met_flags = {}
	st.seen_flags = {}


func _restore_profile() -> void:
	var st: Node = tree.root.get_node("Settings")
	st.met_flags = _saved["met"]
	st.seen_flags = _saved["seen"]
	RevealGate.active = _saved["gate"]
	NewCard.auto_show = _saved["auto"]


func _card(id: StringName) -> CardData:
	return tree.root.get_node("CardDB").get_card(id)


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _spawn(screen: Dictionary) -> Array:
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
	if c.is_mulligan_open():
		c.keep_hand()
		await _frames(2)
	return [vp, m, c]


func _despawn(vp: SubViewport) -> void:
	vp.queue_free()
	tree.root.size = _saved_root_size
	Engine.time_scale = 1.0


func _right_click(vp: SubViewport, ctl: Control) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	e.position = ctl.get_global_rect().get_center()
	e.global_position = e.position
	vp.push_input(e)
	await _frames(2)
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_RIGHT
	u.pressed = false
	u.position = e.position
	u.global_position = e.position
	vp.push_input(u)
	await _frames(2)


# =============================================================================
# 1. Standard Issue look (frame, serial plate, stencil name) and the Recruit ladder
# =============================================================================

func test_standard_issue_card_look_and_serial_plate() -> void:
	_save_profile()
	var trooper: CardData = _card(&"si_trooper")
	var e: Dictionary = BannerCard.entry_for_card(trooper, &"si_trooper")
	assert_true(StandardIssueLook.is_si(e), "a Standard Issue entry")
	assert_eq(String(e.get("serial", "")), "SI-02", "serial by cost (Trooper costs 2)")
	assert_eq(String(e.get("band", "")), "", "no camo band on Standard Issue")
	assert_true(bool(e.get("reserve_trait", false)) and String(e.get("trait", "")) == "", "the trait socket stays empty")
	var card: PanelContainer = BannerCard.build(e, Vector2(228, 73), 57.0)
	tree.root.add_child(card)
	await _frames(2)
	# kc-cards-impl (the head's C1+ / Y2+): no serial plate on cards; the Standard Issue frame and the
	# STANDARD ISSUE tag say it; the name is in the one title style (no stencil).
	var bv: BannerView = BannerCard.banner_of(card)
	var a: Dictionary = bv.anatomy_now()
	for ab: Array in a["abilities"]:
		assert_false(ab[0] is Array and ab[0][0] == &"serial", "no serial plate on the card")
	assert_true(a.has("trait"), "an empty trait socket bottom-left")
	var name_l: Label = card.find_child("NameLabel", true, false)
	assert_eq(name_l.get_theme_font(&"font"), CardLook.TITLE_FONT, "Standard Issue name in the title style")
	assert_eq(name_l.text, "TROOPER", "name in capitals")
	card.queue_free()
	# A calling card never uses the stencil font.
	var bk: CardData = _card(&"breacher")
	var card2: PanelContainer = BannerCard.build(BannerCard.entry_for_card(bk, &"breacher"), Vector2(228, 73), 57.0)
	tree.root.add_child(card2)
	await _frames(1)
	assert_true((card2.find_child("NameLabel", true, false) as Label).get_theme_font(&"font") != StandardIssueLook.stencil(), "calling card: normal font")
	card2.queue_free()
	# The starter's Ammo Resupply wears a Standard Issue art and frame (but it is not a Standard Issue unit).
	var ammo: Dictionary = BannerCard.entry_for_card(_card(&"ammo_resupply"), &"si_ammo_resupply")
	assert_true(StandardIssueLook.is_si(ammo), "the starter's Ammo Resupply has the Standard Issue frame")
	# CardView (mulligan / Supply Drop / inspector face).
	var view: Control = (load("res://scenes/match/CardView.tscn") as PackedScene).instantiate()
	tree.root.add_child(view)
	view.set_card_data({"name": "Grunt", "type": "unit", "cost": 1, "firepower": 2, "armor": 2, "keywords": [],
			"standard_issue": true, "serial": "SI-01"})
	await _frames(1)
	assert_eq((view.get_node("%NameLabel") as Label).get_theme_font(&"font"), CardLook.TITLE_FONT, "CardView: the title style")
	assert_true((view.get_node("%TypeLabel") as Label).text.contains("STANDARD ISSUE"), "CardView: STANDARD ISSUE tag")
	view.queue_free()
	_restore_profile()


func test_no_training_on_any_card() -> void:
	# kc-ipad-cards (kc-no-training): every copy has its keywords; no lock, Trains line, level or band.
	_save_profile()
	RevealGate.active = true
	var bk: CardData = _card(&"breacher")
	var e: Dictionary = BannerCard.entry_for_card(bk, &"breacher")
	for k: String in ["locked", "trains", "level", "level_badge", "band"]:
		assert_false(e.has(k), "no %s key on a card entry" % k)
	assert_false(BannerView.ability_kinds(e).is_empty(), "the Breacher's keywords show from the start")
	assert_true(String(e.get("trait", "")) != "", "a calling card keeps its trait")
	var a: Dictionary = BannerView.anatomy(Vector2(228, 57), BannerView.metrics(57.0), e)
	assert_false(a.has("level") or a.has("class"), "no level coin, no weapon pill")
	for ab: Array in a["abilities"]:
		assert_false(ab[0] is Array and ab[0][0] == &"locked", "no padlocked socket")
	var cv: CardView = (load("res://scenes/match/CardView.tscn") as PackedScene).instantiate()
	tree.root.add_child(cv)
	cv.set_card_data(CardView.view_for_card(bk))
	await _frames(1)
	for l: Dictionary in cv.get_text_lines():
		assert_false(bool(l["locked"]) or String(l["name"]) == "Trains:", "no locked line")
	cv.queue_free()
	_restore_profile()


# =============================================================================
# 2. The board (W1), the initiative chip and the reveal
# =============================================================================

func test_board_banners_cost_without_name_and_si_hand_cards() -> void:
	_save_profile()
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var board: Control = m.get_board()
	for lane: Node in board.find_children("*", "Control", true, false):
		if lane.has_method(&"get_friendly_slots"):
			for slot: Node in lane.get_friendly_slots() + lane.get_enemy_slots():
				assert_false((slot.get(&"banner") as BannerView).show_name, "board banner %s: no name (W1)" % slot.name)
	assert_true((board.get(&"_zoom") as BannerView).show_name, "the hover zoom keeps the name")
	# The quick match plays the Standard Issue starter: hand cards with the frame, serial and stencil name.
	var si_cards: int = 0
	for card: Node in m.get_hand().get_cards():
		var bv: BannerView = BannerCard.banner_of(card)
		if bv != null and StandardIssueLook.is_si(bv.entry):
			si_cards += 1
			var nl: Label = card.find_child("NameLabel", true, false)
			assert_true(nl.visible and nl.text != "", "hand card keeps its name")
			assert_eq(nl.get_theme_font(&"font"), CardLook.TITLE_FONT, "a Standard Issue hand card's name in the title style (kc-cards-impl)")
	assert_true(si_cards >= 3, "the starter hand is Standard Issue (%d)" % si_cards)
	# Play one: on the board it has the cost but no name, and a serial plate.
	var me: RulesSide = c.state.sides[0]
	var uid: int = -1
	afford_a_unit(c, 0, func(rc: RulesCard) -> bool: return rc.card.standard_issue)
	await _frames(2)
	for rc: RulesCard in me.hand:
		if rc.card.standard_issue and rc.card.cost <= me.supply:
			uid = rc.uid
			break
	assert_true(uid >= 0, "a playable Standard Issue card")
	assert_true(c.state.submit(0, RulesIntent.play_card(uid, 1))["ok"], "play it to B")
	c.press_ready()
	await _frames(2)
	c.skip_feedback()
	await _frames(4)
	var found: bool = false
	var snap: Dictionary = MatchSnapshot.build(c.state, c.map, 0)
	for lane: Dictionary in snap["lanes"]:
		for u: Dictionary in lane["friendly"]:
			if StandardIssueLook.is_si(u):
				found = true
				assert_true(String(u.get("serial", "")).begins_with("SI-"), "board entry has its serial")
				assert_true(str(u.get("cost", "")) != "", "board entry keeps the cost")
	assert_true(found, "a Standard Issue unit on the board")
	_despawn(vp)
	await tree.process_frame
	_restore_profile()


func test_initiative_chip_says_who_goes_first_and_why() -> void:
	_save_profile()
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var st: MatchState = c.state
	var info: Dictionary = MatchSnapshot.initiative_info(st, 0)
	var rule_side: int = int(st.hooks.initiative_side(st))
	assert_eq(info["side"], &"player" if rule_side == 0 else &"enemy", "the chip follows the rule's pick (not changed)")
	assert_eq(info["why"], &"tie", "0-0 in round 1: the tie rule decides")
	assert_true(String(info["reason"]).begins_with("Tied 0-0"), "reason in words: %s" % info["reason"])
	var chip: InitiativeChip = m.get_initiative_chip()
	assert_true(chip.is_visible_in_tree(), "the chip shows on the phone strip while no trait is in play")
	assert_true(chip.get_text().contains("1ST") and chip.get_text().contains(String(info["short"])), "chip text %s" % chip.get_text())
	assert_true(m.get_key_controls().has("initiative"), "the chip is a key control")
	var k: float = Layout.points_per_px(Layout.PHONE) if Layout.has_method(&"points_per_px") else 0.7226
	assert_true(minf(chip.size.x, chip.size.y) * k >= 44.0 - 0.01, "chip tap target %s" % chip.size)
	var score: Control = m.get_badge(&"score")
	var row0: Array = score.lines[0]
	assert_true(row0.size() >= 2 and (row0[0] as Array).size() > 2 and StringName(row0[0][2]) in [&"flag", &"flag_rival"], "SCORE badge leads with the initiative flag")
	# Behind on score goes first (read the rule; never change it).
	st.sides[1].score = 3
	var info2: Dictionary = MatchSnapshot.initiative_info(st, 0)
	assert_eq(info2["side"], &"player", "you're behind 0-3: you go first")
	assert_eq(info2["why"], &"behind", "why = behind")
	assert_true(String(info2["reason"]).contains("behind 0-3"), "reason: %s" % info2["reason"])
	st.sides[1].score = 0
	st.sides[0].score = 2
	assert_eq(MatchSnapshot.initiative_info(st, 0)["side"], &"enemy", "rival behind 0-2: it goes first")
	st.sides[0].score = 0
	c.refresh()
	await _frames(2)
	# Studio rule: right click / long press opens the reason and what it does.
	await _right_click(vp, chip)
	var insp: Control = m.get_inspector()
	assert_true(insp.is_open(), "right click opens the initiative inspector")
	var text: String = "\n".join(insp.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text))
	assert_true(text.contains("Initiative") and text.contains("first"), "inspector says who goes first and why")
	insp.close()
	_despawn(vp)
	await tree.process_frame
	_restore_profile()


func test_reveal_hides_unmet_systems_until_in_use() -> void:
	_save_profile()
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	RevealGate.active = true
	var rv: Dictionary = MatchSnapshot.reveal_info(c.state)
	var traited: bool = RevealFlags.TRAIT_RAIL in (rv["now"] as Array)
	assert_eq(bool(rv["trait_rail"]), traited, "trait rail: shown only while a traited unit is in play (fresh profile)")
	assert_false(rv.has("bands"), "kc-ipad-cards: no camo bands (no training)")
	# A snapshot with sets but the rail not revealed: the rail stays hidden, the chip holds the slot.
	var snap: Dictionary = MatchSnapshot.build(c.state, c.map, 0)
	snap["synergy"] = {"player": {"rail": [{"trait": &"vanguard", "name": "Vanguard", "count": 2, "next": 3, "tier": 2}], "links": [], "tiers": {}},
			"enemy": {"rail": [], "links": [], "tiers": {}}}
	snap["reveal"] = {"trait_rail": false, "links": false}
	m.show_snapshot(snap)
	await _frames(2)
	assert_false(m.get_trait_rail().is_visible_in_tree(), "unmet trait rail hidden")
	assert_true(m.get_initiative_chip().is_visible_in_tree(), "initiative chip in its place")
	snap["reveal"] = {"trait_rail": true, "links": true}
	m.show_snapshot(snap)
	await _frames(2)
	assert_true(m.get_trait_rail().is_visible_in_tree(), "revealed rail shows")
	assert_false(m.get_initiative_chip().is_visible_in_tree(), "phone: the rail takes the slot, SCORE keeps the flag")
	# The Engine part of the deck view waits for its reveal flag.
	var rs: Node = tree.root.get_node("RunState")
	var saved_cfg: RunConfig = rs.config
	rs.config = null
	var r: RunProgress = RunProgress.create(rs._config(), 77)
	var panel: Control = EnginePanel.new()
	tree.root.add_child(panel)
	panel.open(r)
	await _frames(1)
	var texts: String = "\n".join(panel.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text))
	assert_false(texts.contains("ENGINE"), "no Engine section before it is met")
	assert_true(texts.contains("Standard Issue: 9 of 10"), "the deck view counts the Standard Issue cards: %s" % texts.substr(0, 120))
	assert_true(panel.find_child("SerialPlate", true, false) == null, "kc-ui-hooks: the retired serial plate is gone from the deck rows")
	tree.root.get_node("Settings").met_flags = {"engine_panel": true}
	panel.open(r)
	await _frames(1)
	texts = "\n".join(panel.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text))
	assert_true(texts.contains("ENGINE"), "Engine section once met")
	panel.queue_free()
	rs.config = saved_cfg
	_despawn(vp)
	await tree.process_frame
	_restore_profile()


# =============================================================================
# 3. "New: X" explainers and RESET TIPS
# =============================================================================

func test_new_card_shows_once_and_reset_tips() -> void:
	_save_profile()
	NewCard.auto_show = true
	var st: Node = tree.root.get_node("Settings")
	var rs: Node = tree.root.get_node("RunState")
	var host := Control.new()
	host.size = Vector2(1168, 540)
	tree.root.add_child(host)
	var nc := NewCard.new()
	host.add_child(nc)
	await _frames(1)
	assert_eq(nc.offer([RevealFlags.MUSTER_OUT], "s1"), &"", "nothing met yet: no explainer")
	rs.note_systems([RevealFlags.MUSTER_OUT, RevealFlags.KILLSTREAKS])
	assert_eq(nc.offer([RevealFlags.CALLING_CARDS], "s1"), &"", "only explainers relevant to this screen")
	assert_eq(nc.offer([RevealFlags.MUSTER_OUT], "s2"), RevealFlags.MUSTER_OUT, "met + relevant: shown")
	await _frames(2)
	assert_true(nc.is_open(), "the card is open")
	var title: Label = nc.find_child("TitleLabel", true, false)
	assert_eq(title.text, "NEW: MUSTER OUT", "title from RevealFlags.TEXTS")
	var text: Label = nc.find_child("TextLabel", true, false)
	assert_true(text.text.contains("quartermaster"), "one sentence: %s" % text.text)
	var ok: Button = nc.get_got_it_button()
	assert_true(ok.size.y >= 64.0 * 0.99, "GOT IT is a full tap target")
	assert_true(Rect2(Vector2.ZERO, host.size).encloses(nc.get_card().get_global_rect()), "card on screen at phone size (%s in %s, nc %s)" % [nc.get_card().get_global_rect(), host.size, nc.size])
	nc.inspect()
	assert_true((nc.find_child("AboutLabel", true, false) as Label).visible, "long press / right click: what this card is")
	ok.pressed.emit()
	assert_false(nc.is_open(), "GOT IT closes it")
	assert_true(st.is_seen(RevealFlags.MUSTER_OUT), "GOT IT marks it seen")
	assert_eq(nc.offer([RevealFlags.MUSTER_OUT], "s3"), &"", "never twice")
	# A keyword tip falls back to the card's own rules line.
	assert_true(String(NewCard.text_for(&"kw_first_shot").get("text", "")).contains("first"), "keyword tip text from the card rules")
	host.queue_free()
	# RESET TIPS in MENU clears the profile.
	var pm: Control = (load("res://scenes/match/PauseMenu.tscn") as PackedScene).instantiate()
	tree.root.add_child(pm)
	await _frames(1)
	var b: Button = pm.get_reset_tips_button()
	assert_true(b != null and b.text == "RESET TIPS", "MENU has RESET TIPS")
	b.pressed.emit()
	assert_true(st.met_flags.is_empty() and st.seen_flags.is_empty(), "RESET TIPS clears met and seen")
	pm.queue_free()
	_restore_profile()


# =============================================================================
# 4. Tutorial and TrainingBot on Standard Issue; kit slots fall back
# =============================================================================

func test_tutorial_and_training_bot_play_standard_issue() -> void:
	var t: TutorialScript = tree.root.get_node("CardDB").get_tutorial_script()
	for c: CardData in t.player_deck:
		assert_true(c.standard_issue or c.id == &"ammo_resupply", "tutorial deck: %s is Standard Issue" % c.id)
	for c: CardData in t.enemy_deck:
		assert_true(c.standard_issue, "scripted enemy deck: %s is Standard Issue" % c.id)
	for p: TutorialEnemyPlay in t.enemy_plays:
		assert_true(p.card.standard_issue, "scripted enemy play: %s" % p.card.id)
	var counts: Dictionary = {}
	for c: CardData in t.squad.deck:
		counts[c.id] = int(counts.get(c.id, 0)) + 1
	assert_eq(counts, {&"si_grunt": 8, &"si_trooper": 3, &"si_sergeant": 2, &"si_armored": 2}, "TrainingBot_01: 8 Grunts, 3 Troopers, 2 Sergeants, 2 Armored Troopers")
	var texts: String = "\n".join(t.steps.map(func(s: TutorialStep) -> String: return s.text))
	assert_false(texts.contains("First Shot"), "First Shot is not taught in the drill any more (its own tip teaches it)")
	# kc-econ: round 2 has 2 Supply, so the beat-order step uses Private II (2/3) against a Grunt.
	# kc-da-ui: the drill's hand is the starter's Privates (the training bot keeps Grunts / Troopers).
	assert_true(texts.contains("Private II") and texts.contains("steps up"), "steps 8-10 teach the beat order")
	for c: CardData in t.player_deck:
		assert_true(c.id == &"ammo_resupply" or String(c.id).begins_with("kc_wip_private_"), "tutorial hand: %s is a Private" % c.id)


func test_kit_slots_fall_back_to_code_drawing() -> void:
	var saved: PackedStringArray = UiKit.piece_dirs
	UiKit.piece_dirs = PackedStringArray(["res://does/not/exist/"])
	UiKit.clear_cache()
	for id: StringName in UiKit.ONBOARD_PIECES:
		if not String(id).begins_with("ico_"):
			assert_true(UiKit.piece(id) == null, "%s missing -> null" % id)
	# Every fallback draws without the kit.
	var ci := Control.new()
	ci.size = Vector2(228, 57)
	tree.root.add_child(ci)
	var drawn: Array = [false]
	ci.draw.connect(func() -> void:
		StandardIssueLook.draw_frame(ci, Rect2(Vector2.ZERO, ci.size))
		StandardIssueLook.draw_serial_plate(ci, Rect2(150, 4, 70, 22), "SI-04", true)
		StandardIssueLook.draw_empty_socket(ci, Rect2(6, 30, 22, 22))
		NewCard.draw_example(ci, Rect2(0, 0, 228, 57), RevealFlags.MUSTER_OUT, false)
		drawn[0] = true)
	ci.queue_redraw()
	await _frames(2)
	assert_true(drawn[0], "code fallbacks drew")
	ci.queue_free()
	# kc-da-import1: si_grunt now wears the Private I painting from data/banners, not a kit piece.
	assert_false(BannerArtDB.get_art(&"si_grunt").source_note.begins_with("Standard Issue art (kit piece"), "no kc_b_si_grunt piece: the data/banners art stays")
	UiKit.piece_dirs = saved
	UiKit.clear_cache()


# =============================================================================
# 5. kc-hand-dim: hand / board art dimmed behind the rows, the inspector at full strength
# =============================================================================

## kc-cards-impl retired kc-hand-dim (the head's C1+: "full calling-card art, uncropped and undimmed"):
## hand and board art at full strength. kc-da-ui (art direction v1 #5): an unplayable card is never
## dimmed either: its cost hex goes grey (cant_pay) and it sits HandArea.DROP_PX lower.
func test_hand_and_board_art_full_strength() -> void:
	_save_profile()
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var checked: int = 0
	for card: Node in m.get_hand().get_cards():
		var bv: BannerView = BannerCard.banner_of(card)
		if bv == null or not bv.has_art():
			continue
		var mod: Color = bv.get_art_modulate()
		checked += 1
		assert_true(mod.r > 0.99, "hand art at full strength (%.2f)" % mod.r)
		assert_true(is_equal_approx((card as Control).modulate.a, 1.0), "the card never fades")
		if card.get_meta(&"playable", true) == false:
			assert_true(bool(bv.entry.get("cant_pay", false)), "an unplayable card shows the grey cost hex")
	assert_true(checked >= 3, "checked %d hand cards" % checked)
	for lane: Node in m.get_board().find_children("*", "Control", true, false):
		if lane.has_method(&"get_friendly_slots"):
			for slot: Node in lane.get_friendly_slots() + lane.get_enemy_slots():
				var bm: Color = (slot.get(&"banner") as BannerView).get_art_modulate()
				assert_true(bm.r > 0.99, "board banner: full-strength art (%.2f)" % bm.r)
	# The inspector's big banner shows the art at full strength.
	var me: RulesSide = c.state.sides[0]
	c._on_card_inspected(me.hand[0].uid)
	await _frames(2)
	var big: BannerView = m.get_inspector().get_banner()
	if big != null:
		assert_false(big.readability, "inspector banner: no scrim")
		assert_true(big.get_art_modulate().r > 0.99, "inspector art at full strength")
	m.get_inspector().close()
	_despawn(vp)
	await tree.process_frame
	_restore_profile()

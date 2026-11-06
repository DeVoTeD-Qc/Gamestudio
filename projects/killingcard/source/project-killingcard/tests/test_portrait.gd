# test_portrait.gd
# Purpose: kc-portrait (the head: "the default one on PC and landscape should have the cards in the
#   hand on the side", fan cards at the bottom for iPhone portrait). Checks:
#   - the screen profile gives a portrait canvas (390x844 pt -> 540x1168, 0.72 pt per px);
#   - the layout switches live on rotate / resize without losing the match state, and back;
#   - portrait hand: tap a fan card (raised into the preview well, PLAY HERE), place it, cancel it
#     (the card again, CANCEL, the empty board);
#   - no overlap between the top bars, the board, the well, the Operator / UNDO / READY and the fan at
#     390x844, 360x780 and 430x932; fan steps >= 44 pt; everything on screen;
#   - landscape unchanged (the side tray, X1 cards);
#   - the run screens players hit in portrait (title, loadout, run map, reward, Codex, the pause menu)
#     keep every button and label on screen.
# Author: UI/UX Agent (kc-portrait)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const BoardMetrics: GDScript = preload("res://scripts/ui/board_metrics.gd")
const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"
const EPS: float = 0.6
const PORTRAIT: Dictionary = {"name": "iPhone 390x844 @3x portrait", "pt": Vector2(390, 844), "ratio": 3.0}
const PORTRAIT_SMALL: Dictionary = {"name": "Android 360x780 @3x portrait", "pt": Vector2(360, 780), "ratio": 3.0}
const PORTRAIT_MAX: Dictionary = {"name": "iPhone Pro Max 430x932 @3x portrait", "pt": Vector2(430, 932), "ratio": 3.0}

var _saved_root_size: Vector2i = Vector2i.ZERO


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
	await _frames(2)
	return [vp, m, c]


func _despawn(vp: SubViewport) -> void:
	vp.queue_free()
	tree.root.size = _saved_root_size


func _mouse(vp: SubViewport, pos: Vector2, pressed: bool) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	vp.push_input(e)


func _tap(vp: SubViewport, pos: Vector2) -> void:
	_mouse(vp, pos, true)
	await _frames(1)
	_mouse(vp, pos, false)
	await _frames(3)


func test_screen_profile_portrait_canvas() -> void:
	assert_eq(Layout.logical_size(PORTRAIT), Vector2(540, 1168), "390x844 portrait: canvas 540x1168")
	assert_true(absf(Layout.points_per_px(PORTRAIT) - 0.722) < 0.01, "0.72 pt per px (%.3f)" % Layout.points_per_px(PORTRAIT))
	for screen: Dictionary in [PORTRAIT_SMALL, PORTRAIT_MAX]:
		var l: Vector2 = Layout.logical_size(screen)
		assert_true(l.y > l.x and l.x >= 540.0 - EPS, "%s: a portrait canvas %s" % [screen["name"], l])
		assert_true(Layout.points_per_px(screen) >= 0.66, "%s: readable (%.3f pt/px)" % [screen["name"], Layout.points_per_px(screen)])
	# Landscape unchanged.
	assert_eq(Layout.logical_size(Layout.PHONE), Vector2(1168, 540), "landscape phone unchanged")
	assert_eq(Layout.logical_size(Layout.DESKTOP), Vector2(1280, 720), "desktop unchanged")
	assert_false(bool(BoardMetrics.compute(Vector2(1156, 540), true).get("portrait", false)), "landscape metrics stay landscape")
	assert_true(bool(BoardMetrics.compute(Vector2(540, 1168), true).get("portrait", false)), "a tall area is portrait")


func test_layout_switches_live_without_losing_the_match() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	assert_false(m.portrait, "landscape at start")
	assert_false(m.get_hand().fan, "the side tray: X1 cards")
	var me: RulesSide = c.state.sides[0]
	var rc0: RulesCard = null
	for rc: RulesCard in me.hand:
		if rc.card.is_unit() and rc.card.cost <= me.supply:
			rc0 = rc
			break
	if rc0 != null:
		c.state.submit(0, RulesIntent.play_card(rc0.uid, 1))
		c.refresh()
	var plays: int = me.plays.size()
	var hand_n: int = me.hand.size()
	var round_n: int = c.state.round_number
	vp.size = Vector2i(Layout.logical_size(PORTRAIT))
	await _frames(6)
	assert_true(m.portrait, "rotated: portrait")
	assert_true(bool(m.metrics.get("portrait", false)), "portrait metrics")
	assert_true(m.get_hand().fan, "the fan hand")
	assert_true(m.get_hand().get_cards().size() > 0 and m.get_hand().get_cards()[0] is CardView, "fan cards are Y2+ cards")
	assert_eq([me.plays.size(), me.hand.size(), c.state.round_number], [plays, hand_n, round_n], "the match state is untouched")
	vp.size = Vector2i(Layout.logical_size(Layout.PHONE))
	await _frames(6)
	assert_false(m.portrait, "back to landscape")
	assert_false(m.get_hand().fan, "the side tray again")
	assert_eq(me.plays.size(), plays, "still the same plays")
	_despawn(vp)
	await tree.process_frame


func test_portrait_hand_select_place_cancel() -> void:
	var s: Array = await _spawn(PORTRAIT)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var hand: Control = m.get_hand()
	assert_true(m.portrait and hand.fan, "portrait fan")
	assert_not_null(m.get_preview_well(), "the empty preview well shows")
	var me: RulesSide = c.state.sides[0]
	var rc0: RulesCard = null
	for rc: RulesCard in me.hand:
		if rc.card.is_unit() and rc.card.cost <= me.supply:
			rc0 = rc
			break
	assert_not_null(rc0, "a playable unit")
	if rc0 == null:
		_despawn(vp)
		return
	var chip: Control = hand.get_card(rc0.uid)
	hand.reveal_card(rc0.uid)
	await _frames(1)
	var strip: Rect2 = Rect2(chip.get_global_rect().position, Vector2(hand.fan_step * 0.8, 40))
	await _tap(vp, strip.get_center())
	await _frames(2)
	assert_eq(c.selection.get("uid", -1), rc0.uid, "tap selects")
	var dock: Control = m.get_card_dock()
	assert_not_null(dock, "raised into the well")
	if dock != null:
		var well: Rect2 = (m.metrics["well"] as Rect2)
		well.position += m.get_tray().get_global_rect().position
		assert_true(well.grow(1.0).encloses(dock.get_global_rect()), "the raised card sits in the well")
	var target: Label = null
	for lane: Node in m.get_board().get_lanes():
		if lane.get_play_here() != null:
			target = lane.get_play_here()
	assert_not_null(target, "PLAY HERE")
	# Cancel: the card again.
	await _tap(vp, Rect2(chip.get_global_rect().position, Vector2(hand.fan_step * 0.8, 40)).get_center())
	await _frames(2)
	assert_true(c.selection.is_empty(), "tap again cancels")
	# CANCEL.
	c.select_card(rc0.uid)
	await _frames(2)
	await _tap(vp, m.get_dock_cancel_button().get_global_rect().get_center())
	await _frames(2)
	assert_true(c.selection.is_empty(), "CANCEL cancels")
	# The empty board.
	c.select_card(rc0.uid)
	await _frames(2)
	m.get_board().empty_tapped.emit()
	await _frames(2)
	assert_true(c.selection.is_empty(), "the empty board cancels")
	# Place.
	c.select_card(rc0.uid)
	await _frames(2)
	for lane: Node in m.get_board().get_lanes():
		if lane.get_play_here() != null:
			target = lane.get_play_here()
			break
	await _tap(vp, target.get_global_rect().get_center())
	await _frames(3)
	var placed: bool = false
	for p: Dictionary in me.plays:
		placed = placed or (p.get("card") != null and (p["card"] as RulesCard).uid == rc0.uid)
	assert_true(placed, "PLAY HERE places it")
	# A swipe scrolls the fan (when it is wider than the screen).
	if hand.fan_scroll_max() > 0.0:
		hand.scroll_fan(-40.0)
		assert_true(hand.fan_scroll > 0.0, "the fan scrolls")
	_despawn(vp)
	await tree.process_frame


func test_portrait_regions_do_not_overlap() -> void:
	for screen: Dictionary in [PORTRAIT, PORTRAIT_SMALL, PORTRAIT_MAX]:
		var s: Array = await _spawn(screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var label: String = screen["name"]
		var k: float = Layout.points_per_px(screen)
		var view: Rect2 = Rect2(Vector2.ZERO, Vector2(vp.size)).grow(EPS)
		var tray: Rect2 = m.get_tray().get_global_rect()
		var well: Rect2 = Rect2(tray.position + (m.metrics["well"] as Rect2).position, (m.metrics["well"] as Rect2).size)
		var regions: Dictionary = {
			"strip": m.get_badge(&"deck").get_parent().get_global_rect(),
			"board": m.get_board().get_global_rect(),
			"well": well,
			"operator": m.get_hand().get_operator_card().get_global_rect(),
			"undo": m.get_undo_button().get_global_rect(),
			"ready": m.get_ready_button().get_global_rect(),
			"fan": m.get_hand().get_global_rect(),
		}
		var keys: Array = regions.keys()
		for i: int in keys.size():
			var a: Rect2 = regions[keys[i]]
			assert_true(view.encloses(a), "%s: %s on screen %s" % [label, keys[i], a])
			for j: int in range(i + 1, keys.size()):
				var b: Rect2 = regions[keys[j]]
				assert_false(a.grow(-1.0).intersects(b.grow(-1.0)), "%s: %s / %s overlap (%s / %s)" % [label, keys[i], keys[j], a, b])
		var bw: float = float(m.metrics["bw"])
		assert_true(bw >= 160.0 and absf(bw / float(m.metrics["bh"]) - 4.0) < 0.01, "%s: 4:1 banners %sx%s" % [label, bw, m.metrics["bh"]])
		assert_true(m.get_hand().fan_step * k >= 44.0 - 0.1, "%s: fan steps %.0f px = %.1f pt" % [label, m.get_hand().fan_step, m.get_hand().fan_step * k])
		for b: Control in [m.get_undo_button(), m.get_ready_button()]:
			assert_true(minf(b.size.x, b.size.y) * k >= 44.0 - 0.1, "%s: %s 44 pt+" % [label, b.name])
		for chip: Node in m.get_hand().get_cards():
			assert_true((chip as Control).get_global_rect().end.y <= view.end.y, "%s: fan cards on screen vertically" % label)
		_despawn(vp)
		await tree.process_frame


func test_landscape_keeps_the_side_tray() -> void:
	for screen: Dictionary in [Layout.PHONE, Layout.DESKTOP]:
		var s: Array = await _spawn(screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		assert_false(m.portrait, "%s: landscape" % screen["name"])
		assert_false(m.get_hand().fan, "%s: X1 cards" % screen["name"])
		assert_true(m.get_hand().get_global_rect().position.x > m.get_board().get_global_rect().end.x - EPS, "%s: the hand beside the board" % screen["name"])
		assert_true(m.get_preview_well() == null, "%s: no preview well" % screen["name"])
		_despawn(vp)
		await tree.process_frame


## Every visible button / label of a screen inside the viewport (scrolling content excepted).
func _check_on_screen(root_ctl: Control, vp: SubViewport, label: String) -> void:
	var view: Rect2 = Rect2(Vector2.ZERO, Vector2(vp.size)).grow(1.0)
	var bad: PackedStringArray = []
	for n: Node in root_ctl.find_children("*", "Control", true, false):
		var ctl: Control = n
		if not ctl.is_visible_in_tree() or not (ctl is Button or ctl is Label):
			continue
		var p: Node = ctl.get_parent()
		var scrolled: bool = false
		while p != null and p != root_ctl:
			if p is ScrollContainer:
				scrolled = true
				break
			p = p.get_parent()
		if scrolled:
			continue
		if not view.encloses(ctl.get_global_rect()):
			bad.append("%s %s" % [ctl.name, ctl.get_global_rect()])
	assert_true(bad.is_empty(), "%s: off screen: %s" % [label, ", ".join(bad.slice(0, 6))])


func test_run_screens_fit_in_portrait() -> void:
	var rs: Node = tree.root.get_node("RunState")
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	rs.start_run(4242)
	for path: String in ["res://scenes/Title.tscn", "res://scenes/run/Loadout.tscn", "res://scenes/run/RunMap.tscn"]:
		var vp: SubViewport = SubViewport.new()
		vp.size = Vector2i(Layout.logical_size(PORTRAIT))
		vp.disable_3d = true
		tree.root.add_child(vp)
		var node: Control = (load(path) as PackedScene).instantiate()
		vp.add_child(node)
		await _frames(6)
		_check_on_screen(node, vp, path.get_file())
		if path.ends_with("Title.tscn"):
			node.open_codex()
			await _frames(4)
			_check_on_screen(node.get_codex(), vp, "Codex")
		if path.ends_with("Loadout.tscn"):
			rs.begin_run()
		vp.queue_free()
		await _frames(2)
	rs.record_result(&"player", {"reason": &"target", "rounds": 6, "player_score": 6, "enemy_score": 3})
	var vp2: SubViewport = SubViewport.new()
	vp2.size = Vector2i(Layout.logical_size(PORTRAIT))
	vp2.disable_3d = true
	tree.root.add_child(vp2)
	var reward: Control = (load("res://scenes/run/Reward.tscn") as PackedScene).instantiate()
	vp2.add_child(reward)
	await _frames(8)
	_check_on_screen(reward, vp2, "Reward")
	assert_true(reward.portrait, "the reward screen knows it is portrait")
	for t: Control in reward.tiles:
		assert_true(t.size.x <= vp2.size.x * 0.5 + 1.0, "two Supply Drop cards per row (%s)" % t.size)
	vp2.queue_free()
	rs.abandon_run()
	await _frames(2)
	# The match's pause menu and mulligan in portrait.
	var s: Array = await _spawn(PORTRAIT)
	var vp3: SubViewport = s[0]
	var c: Node = s[2]
	c.open_pause_menu()
	await _frames(3)
	_check_on_screen(s[1].get_node("%PauseMenu") if s[1].has_node("%PauseMenu") else s[1], vp3, "Pause menu")
	_despawn(vp3)
	tree.root.size = _saved_root_size
	await tree.process_frame


# =============================================================================
# kc-portrait review: no Y2+ title or lore line is cut in portrait
# =============================================================================

## Every visible CardView under `root_ctl`: its whole name fits its title slot, its lore line fits
## the text box. Returns the problems found.
func _cut_cards(root_ctl: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	var nodes: Array[Node] = root_ctl.find_children("*", "Control", true, false)
	nodes.push_front(root_ctl)
	for n: Node in nodes:
		if not (n is CardView) or not (n as CardView).is_visible_in_tree():
			continue
		var cv: CardView = n
		var nl: Label = cv.find_child("NameLabel", true, false)
		var need: float = CardLook.TITLE_FONT.get_string_size(nl.text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, CardLook.TITLE_PX).x
		if need > nl.size.x + 0.5:
			out.append("%s: name needs %.0f px, has %.0f (card %.0f)" % [nl.text, need, nl.size.x, cv.get_card_width()])
		var lore: String = cv.get_lore_text()
		if lore != "":
			var box: Rect2 = cv.regions()["text"]
			var para := TextParagraph.new()
			para.add_string(lore, CardLook.LORE_FONT, 16)
			para.width = box.size.x - 12.0
			var h: float = para.get_line_count() * (CardLook.LORE_FONT.get_height(16) - 3.0)
			if para.get_line_count() > 3 or h > box.size.y - 4.0:
				out.append("%s: lore %d lines in %.0f px" % [nl.text, para.get_line_count(), box.size.y])
	return out


func _cut_labels(root_ctl: Node, names: Array[String]) -> PackedStringArray:
	var out: PackedStringArray = []
	for n: Node in root_ctl.find_children("*", "Label", true, false):
		var l: Label = n
		if not l.is_visible_in_tree() or not (String(l.name) in names):
			continue
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
			var need: float = l.get_theme_font(&"font").get_string_size(l.text.to_upper() if l.uppercase else l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size(&"font_size")).x
			if need > l.size.x + 0.5:
				out.append("%s: '%s' cut" % [l.name, l.text])
	return out


func test_portrait_cards_show_whole_names_and_lore() -> void:
	var rs: Node = tree.root.get_node("RunState")
	for screen: Dictionary in [PORTRAIT, PORTRAIT_SMALL]:
		var label: String = screen["name"]
		_saved_root_size = tree.root.size
		tree.root.size = Vector2i(1280, 720)
		rs.start_run(4242)
		var vp: SubViewport = SubViewport.new()
		vp.size = Vector2i(Layout.logical_size(screen))
		vp.disable_3d = true
		tree.root.add_child(vp)
		# Loadout > OPERATOR & DECK (the starter squad).
		var lo: Control = (load("res://scenes/run/Loadout.tscn") as PackedScene).instantiate()
		vp.add_child(lo)
		await _frames(4)
		lo.open_starter()
		await _frames(6)
		var sp: Control = lo.get_starter()
		var cut: PackedStringArray = _cut_cards(sp)
		cut.append_array(_cut_labels(sp, ["OperatorLine"]))
		assert_true(cut.is_empty(), "%s starter squad: %s" % [label, ", ".join(cut)])
		assert_true(sp.find_children("*", "CardView", true, false).size() >= 6, "%s: the starter's Y2+ cards were checked" % label)
		# A 124 px card (the old portrait size) would cut names: the check catches it.
		var probe: CardView = (load("res://scenes/match/CardView.tscn") as PackedScene).instantiate()
		vp.add_child(probe)
		probe.set_card_data(CardView.view_for_card(CardDB.get_card(&"demolitions_expert")))
		probe.set_card_width(124)
		await tree.process_frame
		assert_false(_cut_cards(probe).is_empty(), "%s: the check sees a cut name" % label)
		probe.free()
		lo.queue_free()
		await _frames(2)
		rs.begin_run()
		# Codex.
		var title: Control = (load("res://scenes/Title.tscn") as PackedScene).instantiate()
		vp.add_child(title)
		await _frames(4)
		title.open_codex()
		await _frames(6)
		cut = _cut_cards(title.get_codex())
		assert_true(cut.is_empty(), "%s Codex: %s" % [label, ", ".join(cut)])
		title.queue_free()
		await _frames(2)
		# Supply Drop.
		rs.record_result(&"player", {"reason": &"target", "rounds": 6, "player_score": 6, "enemy_score": 3})
		var reward: Control = (load("res://scenes/run/Reward.tscn") as PackedScene).instantiate()
		vp.add_child(reward)
		await _frames(8)
		cut = _cut_cards(reward)
		assert_true(cut.is_empty(), "%s Supply Drop: %s" % [label, ", ".join(cut)])
		reward.queue_free()
		await _frames(2)
		rs.abandon_run()
		vp.queue_free()
		tree.root.size = _saved_root_size
		await _frames(2)
		# Muster out / Salvage use the same CardView widths: every chassis at the list width.
		var mw: float = 172.0
		for cd: CardData in (CardDB.get("_cards") as Dictionary).values():
			var v: CardView = (load("res://scenes/match/CardView.tscn") as PackedScene).instantiate()
			tree.root.add_child(v)
			v.set_card_data(CardView.view_for_card(cd))
			v.set_card_width(mw)
			await tree.process_frame
			cut = _cut_cards(v)
			assert_true(cut.is_empty(), "%s at %.0f px: %s" % [cd.id, mw, ", ".join(cut)])
			v.free()
		# The match: mulligan and the hand fan.
		var s: Array = await _spawn_no_keep(screen)
		var mvp: SubViewport = s[0]
		var m: Control = s[1]
		var c: Node = s[2]
		if c.is_mulligan_open():
			cut = _cut_cards(m.get_mulligan_panel())
			assert_true(cut.is_empty(), "%s mulligan: %s" % [label, ", ".join(cut)])
			c.keep_hand()
			await _frames(3)
		cut = _cut_cards(m.get_hand())
		assert_true(cut.is_empty(), "%s hand fan: %s" % [label, ", ".join(cut)])
		_despawn(mvp)
		await tree.process_frame


func _spawn_no_keep(screen: Dictionary) -> Array:
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
	await _frames(6)
	return [vp, m, m.get_node("%MatchController")]

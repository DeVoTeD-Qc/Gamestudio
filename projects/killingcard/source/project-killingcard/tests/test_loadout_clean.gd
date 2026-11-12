# test_loadout_clean.gd
# Purpose: kc-loadout-clean (the head: "the operator power makes the ready button and undo too small",
#   "too much info in this screen", "the deck view should show the calling card properly", drag to
#   move, the Operator card as the ability button, no rival hand count):
#   - Loadout: a summary only (Operator line, boss line, unlocked modifiers + an "n LOCKED" chip);
#     killstreak tiles carry name, streak cost and one sentence; every detail is one inspect away.
#   - Deck view: card faces in a grid, the Operator first, count badges, no scroll for 10 cards.
#   - Battle: the MOVE chip and the drag of a movable unit; the deployed Operator card is the ability
#     button; READY / UNDO own the bottom row; no rival hand count.
# Author: UI/UX Agent (kc-loadout-clean)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const RunV2Views: GDScript = preload("res://scripts/ui/run/run_v2_views.gd")
const EnginePanel: GDScript = preload("res://scripts/ui/run/engine_panel.gd")
const IPAD: Dictionary = {"name": "iPad 1180x820", "pt": Vector2(1180, 820), "ratio": 2.0}

var _saved_root_size: Vector2i = Vector2i.ZERO
var _saved: Dictionary = {}


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _begin() -> void:
	var rs: Node = tree.root.get_node("RunState")
	var router: Node = tree.root.get_node("SceneRouter")
	_saved = {"autosave": rs.autosave, "dry_run": router.dry_run, "size": tree.root.size}
	rs.autosave = false
	router.dry_run = true
	rs.start_run(4242)
	RunV2Views.clear_overrides()
	tree.root.size = Vector2i(1280, 720)


func _end() -> void:
	RunV2Views.clear_overrides()
	tree.root.get_node("RunState").autosave = _saved["autosave"]
	tree.root.get_node("SceneRouter").dry_run = _saved["dry_run"]
	tree.root.size = _saved["size"]


func _viewport(screen: Dictionary) -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(Layout.logical_size(screen))
	vp.disable_3d = true
	vp.handle_input_locally = true
	tree.root.add_child(vp)
	return vp


func _texts(n: Node) -> String:
	var out: PackedStringArray = []
	for l: Node in n.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree():
			out.append((l as Label).text)
	for b: Node in n.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree():
			out.append((b as Button).text)
	return "\n".join(out)


func test_loadout_shows_only_what_the_pick_needs() -> void:
	_begin()
	for screen: Dictionary in [Layout.PHONE, IPAD]:
		var vp: SubViewport = _viewport(screen)
		var lo: Control = (load("res://scenes/run/Loadout.tscn") as PackedScene).instantiate()
		vp.add_child(lo)
		await _frames(6)
		if lo.get_starter() != null:
			lo.get_starter().close()
		await _frames(4)
		var label: String = screen["name"]
		var text: String = _texts(lo)
		# Gone: the deck list, the passive line, the long locked-modifier tiles, repeated wording.
		for gone: String in ["3× Private", "Quartermaster", "LOCKED · WIN A RUN", "TAP TO DROP", "THIS RUN'S BOSS", "STARTER KIT"]:
			assert_false(text.contains(gone), "%s: the loadout no longer shows '%s'" % [label, gone])
		for kept: String in ["Kestrel AR-7", "10 cards", "OPERATOR & DECK", "BEGIN RUN", "BACK"]:
			assert_true(text.contains(kept), "%s: the loadout shows '%s'" % [label, kept])
		# Killstreak tiles: name, STREAK n, one sentence; long press = the full rules.
		var recon: Control = lo.get_node("%Body").find_child("Killstreak_recon_drone", true, false)
		assert_not_null(recon, "%s: Recon Drone tile" % label)
		assert_eq((recon.find_child("StreakCost", true, false) as Label).text, "STREAK 2", "%s: the streak cost on the tile" % label)
		var eff: String = (recon.find_child("Effect", true, false) as Label).text
		assert_eq(eff.count(". "), 0, "%s: the effect is one sentence (%s)" % [label, eff])
		assert_true(recon.has_meta(&"inspectable"), "%s: the killstreak tile is inspectable" % label)
		# The boss: one line, inspectable.
		var boss: Control = lo.find_child("LoadoutBoss", true, false)
		if boss != null:
			assert_true(boss.has_meta(&"inspectable"), "%s: the boss line is inspectable" % label)
			assert_true(boss.get_combined_minimum_size().y <= 80.0, "%s: the boss is one line (%.0f px)" % [label, boss.get_combined_minimum_size().y])
		# The locked modifiers sit behind a chip that lists them all.
		var mods: Array = RunV2Views.modifier_options(tree.root.get_node("RunState").run)
		var locked: int = mods.filter(func(m: Dictionary) -> bool: return bool(m.get("locked", false))).size()
		if locked > 0:
			var chip: Button = lo.get_locked_chip()
			assert_not_null(chip, "%s: the n LOCKED chip" % label)
			assert_eq(chip.text, "%d LOCKED" % locked, "%s: it counts them" % label)
			var ins: Control = lo.open_locked_modifiers()
			await _frames(2)
			assert_true(ins.is_open(), "%s: the chip opens the full list" % label)
			ins.close()
		# The Operator line inspects to its rules.
		var op: Control = lo.find_child("OperatorSummary", true, false)
		assert_true(op != null and op.has_meta(&"inspectable"), "%s: the Operator line is inspectable" % label)
		vp.queue_free()
		await _frames(2)
	_end()


func test_deck_view_shows_card_faces_without_scrolling() -> void:
	_begin()
	var r: RunProgress = tree.root.get_node("RunState").run
	for screen: Dictionary in [Layout.PHONE, IPAD, Layout.DESKTOP]:
		var vp: SubViewport = _viewport(screen)
		var host := Control.new()
		host.size = Vector2(vp.size)
		vp.add_child(host)
		var panel: Control = EnginePanel.new()
		host.add_child(panel)
		await _frames(1)
		panel.open(r)
		await _frames(6)
		var label: String = screen["name"]
		var grid: GridContainer = panel.find_child("CardGrid", true, false) as GridContainer
		assert_not_null(grid, "%s: the deck is a card grid" % label)
		var tiles: Array = grid.get_children()
		assert_true(String((tiles[0] as Node).name).begins_with("Operator_"), "%s: the Operator comes first" % label)
		for t: Node in tiles:
			assert_not_null(t.get_node_or_null(^"Card"), "%s: %s is a card face" % [label, t.name])
			assert_true(t.has_meta(&"inspectable"), "%s: %s is inspectable" % [label, t.name])
		var counted: int = 0
		for t: Node in tiles.slice(1):
			var badge: Label = t.find_child("CountBadge", true, false) as Label
			assert_not_null(badge, "%s: %s has a count badge" % [label, t.name])
			counted += int(badge.text.trim_prefix("x"))
		assert_eq(counted, r.deck.size(), "%s: the badges add up to the deck" % label)
		var scroll: ScrollContainer = panel.find_child("Scroll", true, false) as ScrollContainer
		var bar: VScrollBar = scroll.get_v_scroll_bar()
		assert_true(bar.max_value <= bar.page + 1.0, "%s: a 10-card deck needs no scrolling (%.0f > %.0f)" % [label, bar.max_value, bar.page])
		var chip: Button = panel.find_child("StandardIssueChip", true, false) as Button
		assert_true(chip.visible and chip.text.length() <= 26, "%s: Standard Issue is a short chip (%s)" % [label, chip.text])
		chip.pressed.emit()
		await _frames(2)
		assert_true(panel.get_node("Inspector").is_open(), "%s: the chip explains itself" % label)
		panel.close()
		(tiles[1] as Control).gui_input.emit(_right_click())
		await _frames(2)
		assert_true(panel.get_node("Inspector").is_open(), "%s: right click on a card opens its rules" % label)
		vp.queue_free()
		await _frames(2)
	_end()


func _right_click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	return e


func _spawn_match(screen: Dictionary) -> Array:
	var vp: SubViewport = _viewport(screen)
	var m: Control = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	vp.add_child(m)
	await _frames(4)
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
		await _frames(2)
	if m.get_match_intro() != null:
		m.get_match_intro().close()
	return [vp, m, c]


func test_move_chip_and_drag_to_move() -> void:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	var s: Array = await _spawn_match(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var st: MatchState = c.state
	var runner_card: CardData = tree.root.get_node("CardDB").get_card(&"kc_wip_runner")
	if runner_card == null:
		assert_true(true, "no Agile card in this build")
		vp.queue_free()
		tree.root.size = _saved_root_size
		return
	var runner: RulesUnit = st.create_unit(0, runner_card)
	st.put_in_line(runner, 0)
	var grunt: RulesUnit = st.create_unit(0, tree.root.get_node("CardDB").get_card(&"marksman"))
	st.put_in_line(grunt, 2)
	c.refresh()
	await _frames(3)
	var lanes: Array = m.get_board().get_lanes()
	var slot0: Node = lanes[0].get_friendly_slots()[0]
	assert_true(slot0.movable and slot0.move_chip.visible, "the Agile unit shows the MOVE chip")
	var slot2: Node = lanes[2].get_friendly_slots()[0]
	assert_false(slot2.move_chip.visible, "a unit that can't move has no chip")
	# Drag it onto column B: the column lights, the drop orders the move.
	var over: Vector2 = (lanes[1] as Control).get_global_rect().get_center()
	c._on_unit_drag_started(0, runner.uid, (lanes[0] as Control).get_global_rect().get_center())
	c._on_drag_moved(-1, over)
	await _frames(2)
	assert_eq(StringName(c.selection.get("kind", &"")), &"agile", "a drag on the chip unit selects its move")
	assert_eq(lanes[1].target_state, &"hover", "the column under the finger lights up")
	c._on_drag_ended(over)
	await _frames(2)
	assert_true(st.sides[0].plays.any(func(p: Dictionary) -> bool: return p["kind"] == &"agile" and int(p["zone"]) == 1), "the drop orders the move")
	assert_false(lanes[0].get_friendly_slots()[0].move_chip.visible, "moved once this round: the chip goes")
	# A drop off the board snaps back (no order).
	c.undo()
	await _frames(2)
	c._on_unit_drag_started(0, runner.uid, (lanes[0] as Control).get_global_rect().get_center())
	c._on_drag_ended(Vector2(-50, -50))
	await _frames(2)
	assert_false(st.sides[0].plays.any(func(p: Dictionary) -> bool: return p["kind"] == &"agile"), "a drop off the board snaps back")
	assert_true(c.selection.is_empty(), "and clears the selection")
	# The Operator on the board shows the chip; a tap on it selects its Rotate (tap-then-tap fallback).
	st.put_in_line(st.sides[0].operator_unit, 1)
	st.sides[0].operator_can_deploy = false
	c.refresh()
	await _frames(3)
	var op_slot: Node = null
	for sl: Node in lanes[1].get_friendly_slots():
		if sl.slot_uid == st.sides[0].operator_unit.uid:
			op_slot = sl
	assert_true(op_slot != null and op_slot.move_chip.visible, "the Operator on the board shows the MOVE chip")
	c._on_lane_tapped(1, &"player", st.sides[0].operator_unit.uid)
	await _frames(2)
	assert_eq(StringName(c.selection.get("kind", &"")), &"operator", "a tap on it selects its move")
	c.clear_selection()
	vp.queue_free()
	tree.root.size = _saved_root_size
	await _frames(2)


func test_deployed_operator_card_is_the_ability_button() -> void:
	if not ResourceLoader.exists("res://data/loadout/ab_dig_in.tres"):
		assert_true(true, "kc-v2-impl data not in this build")
		return
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	for screen: Dictionary in [Layout.PHONE, IPAD, Layout.DESKTOP]:
		var s: Array = await _spawn_match(screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var c: Node = s[2]
		var st: MatchState = c.state
		var label: String = screen["name"]
		st.sides[0].kit_on = true
		st.sides[0].ability = load("res://data/loadout/ab_dig_in.tres")
		c.refresh()
		await _frames(2)
		var card: Control = m.get_hand().get_operator_card()
		assert_false(bool(card.get_meta(&"deployed", false)), "%s: before deploying, the normal card" % label)
		# Deploy it by a drag from the hand onto column B.
		var over: Vector2 = (m.get_board().get_lanes()[1] as Control).get_global_rect().get_center()
		c._on_operator_drag_started(card.get_global_rect().get_center())
		c._on_drag_moved(-1, over)
		c._on_drag_ended(over)
		await _frames(3)
		assert_true(c.operator_deployed(), "%s: the drag deploys the Operator" % label)
		card = m.get_hand().get_operator_card()
		assert_not_null(card, "%s: the Operator card stays in the hand" % label)
		assert_true(bool(card.get_meta(&"deployed", false)), "%s: marked DEPLOYED" % label)
		var status: Label = card.find_child("OperatorStatus", true, false) as Label
		assert_true(status.text.begins_with("DEPLOYED"), "%s: it says DEPLOYED (%s)" % [label, status.text])
		assert_true(m.get_ability_button().is_visible_in_tree(), "%s: the ability disc shows on it" % label)
		# Tap = the ability; long press = its rules.
		c._on_operator_tapped()
		await _frames(2)
		assert_eq(StringName(c.selection.get("kind", &"")), &"item", "%s: a tap picks the ability" % label)
		c.clear_selection()
		c._on_operator_inspected()
		await _frames(2)
		assert_true(m.get_inspector().is_open(), "%s: a long press explains the ability" % label)
		m.get_inspector().close()
		# READY / UNDO own the bottom row; READY is the clear primary.
		var k: float = Layout.points_per_px(screen)
		var undo_r: Rect2 = m.get_undo_button().get_global_rect()
		var ready_r: Rect2 = m.get_ready_button().get_global_rect()
		assert_true(undo_r.size.y * k >= 44.0 - 0.5 and undo_r.size.x * k >= 44.0 - 0.5, "%s: UNDO >= 44 pt" % label)
		assert_true(ready_r.size.y * k >= 44.0 - 0.5, "%s: READY >= 44 pt tall" % label)
		assert_true(ready_r.size.x >= 2.0 * undo_r.size.x, "%s: READY is the primary" % label)
		assert_true(m.get_ready_button().get_minimum_size().x <= ready_r.size.x + 1.0, "%s: READY's label fits" % label)
		# Undo the placement: the card is the deploy card again.
		c.undo()
		await _frames(3)
		assert_false(bool(m.get_hand().get_operator_card().get_meta(&"deployed", false)), "%s: undone, the card is back to normal" % label)
		# No rival hand count anywhere.
		assert_false(m.get_node("%RivalBadge").visible, "%s: no RIVAL hand badge" % label)
		assert_false(m.get_node("%Minimap").get_node("%RivalHand").visible, "%s: no hand count in the intel" % label)
		vp.queue_free()
		await _frames(2)
	tree.root.size = _saved_root_size

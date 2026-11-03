# test_board_layout.gd
# Purpose: p08 layout checks for scenes/Match.tscn. The match screen is laid out in
#   a SubViewport at the logical size the project's stretch settings produce for a
#   given window (canvas_items + expand, 1280x720 base), then:
#   - every key control is on screen and key controls don't overlap each other,
#   - the three lanes sit side by side inside the board without overlapping,
#   - the layout's minimum size fits (nothing is pushed off screen),
#   - every tap target (Buttons + nodes in group "tap_target") is >= 64x64 px.
# Headless note: the headless root window is 64x64, which makes the 1280x720
#   canvas_items stretch set a tiny font oversampling and roughly doubles every
#   font's line height. _spawn() sizes the root to the base resolution while a
#   test runs (and restores it), so text metrics match a real window.
# Author: UI/UX Agent
extends "res://tests/test_case.gd"

const MATCH_SCENE: String = "res://scenes/Match.tscn"
const MIN_TAP: float = 64.0
const EPS: float = 0.5


func test_match_scene_instantiates() -> void:
	var scene: PackedScene = load(MATCH_SCENE) as PackedScene
	assert_not_null(scene, "Match.tscn did not load")
	if scene == null:
		return
	var node: Node = scene.instantiate()
	assert_not_null(node, "Match.tscn did not instantiate")
	assert_eq(node.name, &"Match", "root name")
	for unique: String in ["%Board", "%Minimap", "%ScoreBar", "%OperatorPanel", "%HandArea",
			"%SupplyCounter", "%ReadyButton", "%KillfeedSlot"]:
		assert_not_null(node.get_node_or_null(unique), "Match lacks %s" % unique)
	node.free()


func test_logical_size_rule() -> void:
	assert_eq(logical_size(Vector2(1280, 720)), Vector2(1280, 720), "desktop base")
	assert_eq(logical_size(Vector2(844, 390)), Vector2(1558, 720), "phone landscape")


func test_layout_desktop_1280x720() -> void:
	await _check_layout(Vector2(1280, 720))


func test_layout_phone_844x390() -> void:
	await _check_layout(Vector2(844, 390))


func test_layout_tablet_1024x768() -> void:
	await _check_layout(Vector2(1024, 768))


func test_mock_content_shown() -> void:
	var setup: Array = await _spawn(Vector2(1280, 720))
	var viewport: SubViewport = setup[0]
	var match_node: Control = setup[1]
	var lanes: Array[Node] = match_node.get_board().get_lanes()
	assert_eq(lanes.size(), 3, "three lanes")
	var zones: Array[StringName] = []
	for lane: Node in lanes:
		zones.append(lane.zone_id)
		assert_eq(lane.get_enemy_slots().size(), 4, "%s enemy slots" % lane.zone_id)
		assert_eq(lane.get_friendly_slots().size(), 4, "%s friendly slots" % lane.zone_id)
	assert_eq(zones, [&"left", &"mid", &"right"] as Array[StringName], "lane order")
	# Right lane: Rifleman, Gunner, then 1 incoming red dot, then empty.
	var right: Array[Node] = lanes[2].get_enemy_slots()
	assert_eq(right[0].kind, right[0].Kind.UNIT, "right enemy point man")
	assert_eq(right[2].kind, right[2].Kind.INCOMING, "right incoming contact")
	assert_eq(right[3].kind, right[3].Kind.EMPTY, "right empty slot")
	assert_eq(match_node.get_node("%HandArea").get_cards().size(), 5, "hand cards")
	_despawn(viewport)


func _despawn(viewport: SubViewport) -> void:
	viewport.queue_free()
	tree.root.size = _saved_root_size


## Logical canvas size for a window, per canvas_items + expand with a 1280x720 base.
static func logical_size(window: Vector2) -> Vector2:
	var scale: float = minf(window.x / 1280.0, window.y / 720.0)
	return (window / scale).floor()


var _saved_root_size: Vector2i = Vector2i.ZERO


func _spawn(window: Vector2) -> Array:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(logical_size(window))
	viewport.disable_3d = true
	tree.root.add_child(viewport)
	var match_node: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
	viewport.add_child(match_node)
	for i: int in 4:
		await tree.process_frame
	return [viewport, match_node]


func _check_layout(window: Vector2) -> void:
	var setup: Array = await _spawn(window)
	var viewport: SubViewport = setup[0]
	var match_node: Control = setup[1]
	var label: String = "%dx%d" % [int(window.x), int(window.y)]
	var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(EPS)

	assert_eq(match_node.size, Vector2(viewport.size), "%s Match fills the viewport" % label)
	var layout: Control = match_node.get_node("%SafeArea")
	var needed: Vector2 = layout.get_combined_minimum_size()
	assert_true(needed.x <= viewport.size.x + EPS and needed.y <= viewport.size.y + EPS,
			"%s layout needs %s but screen is %s" % [label, needed, viewport.size])

	var keys: Dictionary = match_node.get_key_controls()
	var names: Array = keys.keys()
	for key: String in names:
		var c: Control = keys[key]
		var r: Rect2 = c.get_global_rect()
		assert_true(c.is_visible_in_tree() and r.size.x > 1.0 and r.size.y > 1.0,
				"%s %s not visible (%s)" % [label, key, r])
		assert_true(screen.encloses(r), "%s %s off screen: %s" % [label, key, r])
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			var a: Rect2 = (keys[names[i]] as Control).get_global_rect().grow(-EPS)
			var b: Rect2 = (keys[names[j]] as Control).get_global_rect().grow(-EPS)
			assert_false(a.intersects(b), "%s %s overlaps %s (%s / %s)" % [label, names[i], names[j], a, b])

	var board_rect: Rect2 = match_node.get_board().get_global_rect().grow(EPS)
	var lanes: Array[Node] = match_node.get_board().get_lanes()
	for i: int in lanes.size():
		var lane_rect: Rect2 = (lanes[i] as Control).get_global_rect()
		assert_true(board_rect.encloses(lane_rect), "%s lane %d outside board" % [label, i])
		if i > 0:
			var prev: Rect2 = (lanes[i - 1] as Control).get_global_rect()
			assert_true(lane_rect.position.x >= prev.end.x - EPS, "%s lanes %d/%d overlap" % [label, i - 1, i])

	# Tap targets: everything in group "tap_target" plus every Button.
	var targets: Array[Control] = []
	for n: Node in tree.get_nodes_in_group(&"tap_target"):
		if match_node.is_ancestor_of(n) and n is Control:
			targets.append(n)
	for n: Node in match_node.find_children("*", "Button", true, false):
		if not targets.has(n):
			targets.append(n)
	assert_true(targets.size() >= 30, "%s expected >= 30 tap targets, got %d" % [label, targets.size()])
	for c: Control in targets:
		if not c.is_visible_in_tree():
			continue
		var r: Rect2 = c.get_global_rect()
		assert_true(r.size.x >= MIN_TAP and r.size.y >= MIN_TAP,
				"%s tap target %s is %s (< %d px)" % [label, match_node.get_path_to(c), r.size, MIN_TAP])
		assert_true(screen.encloses(r), "%s tap target %s off screen" % [label, match_node.get_path_to(c)])

	# Contents stay inside their panels (no spill into neighbours).
	var hand_rect: Rect2 = match_node.get_node("%HandArea").get_global_rect().grow(EPS)
	for card: Node in match_node.get_node("%HandArea").get_cards():
		assert_true(hand_rect.encloses((card as Control).get_global_rect()), "%s hand card spills" % label)
	var op_rect: Rect2 = match_node.get_node("%OperatorPanel").get_global_rect().grow(EPS)
	for b: Node in match_node.get_node("%OperatorPanel").get_buttons():
		assert_true(op_rect.encloses((b as Control).get_global_rect()), "%s operator button spills" % label)
	_despawn(viewport)

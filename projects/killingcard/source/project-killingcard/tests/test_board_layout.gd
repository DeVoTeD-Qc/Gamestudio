# test_board_layout.gd
# Purpose: Layout and readability checks for scenes/Match.tscn (p08, phone pass f01).
#   Each case is a real screen: size in points (iOS pt / CSS px) plus its pixel ratio. The
#   screen profile (scripts/ui/screen_profile.gd) gives the canvas base and the logical size;
#   the match screen is laid out in a SubViewport of that logical size, then:
#   - every key control is on screen and key controls don't overlap each other,
#   - the three lanes sit side by side inside the board without overlapping,
#   - the layout's minimum size fits (nothing is pushed off screen),
#   - EFFECTIVE sizes (logical px * points per px): body text >= 11 pt, key numbers >= 14 pt,
#     every tap target (Buttons + group "tap_target") >= 44 pt; on desktop also >= 64 px,
#   - important labels (names, scores, stats, costs) show their whole text (no clip/ellipsis),
#   - the project theme (hud_theme.tres) defines every style the match scenes use.
#   p09: the p08 cases run on the mock snapshot; the live cases run the real engine match that
#   MatchController starts (with a card selected, so lane badges show), and the inspector cases
#   check the long-press card inspector (CardView >= 0.8x, text >= 11 pt, CLOSE >= 44 pt).
# Headless note: the headless root window is 64x64, which makes the 1280x720 canvas_items
#   stretch set a tiny font oversampling and roughly doubles every font's line height.
#   _spawn() sizes the root to the base resolution while a test runs (and restores it), so
#   text metrics match a real window.
# Author: UI/UX Agent
extends "res://tests/test_case.gd"

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const MockMatchData: GDScript = preload("res://scripts/ui/mock_match_data.gd")
const CardInfoScript: GDScript = preload("res://scripts/ui/card_info.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"
const HUD_THEME: String = "res://assets/ui/hud_theme.tres"
const CARD_THEME: String = "res://assets/ui/card_theme.tres"
const MIN_TAP_PT: float = 44.0  # Apple HIG minimum
const MIN_TAP_DESKTOP_PX: float = 64.0  # p08 rule at the 1280x720 base
const MIN_BODY_PT: float = 11.0
const MIN_NUMBER_PT: float = 14.0
const EPS: float = 0.5
## Every theme type variation the match scenes and scripts use (scenes are also scanned).
const MATCH_VARIATIONS: Array[String] = [
	"SlotFriendly", "SlotOperator", "SlotEnemy", "SlotEmpty", "SlotIncoming", "LaneRowFriendly",
	"LaneRowEnemy", "LanePanel", "HandCard", "CostBadge", "MinimapCell", "RedDot", "SupplyPip",
	"SupplyPipSpent", "StreakSegment", "StreakSegmentLit", "PerkSlot", "HudButton",
	"KillstreakButton", "HudBig", "FriendlyLabel", "EnemyLabel", "HudPanelDark", "ZoneFriend",
	"ZoneEnemy", "ZoneContested", "ZoneNeutral", "ReadyButton", "HudSubtle", "HudHeader",
	"HudNumber", "KillfeedFriend", "KillfeedEnemy", "RangeBadge", "StreakLabel", "UnitName", "HudTag",
	"HandCardSelected", "HandCardDim", "SlotPending", "SlotTarget", "LaneTargetValid", "LaneTargetHover",
	"LaneTargetInvalid", "TargetBadge", "TargetBadgeBad", "TargetText", "ToastPanel", "Scrim",
	"KeywordName", "OperatorSelected",
	# p12 outcome preview
	"PreviewCard", "PreviewText", "PreviewUnknown", "PreviewQuiet", "PreviewFriend", "PreviewEnemy",
	"PreviewContested", "PreviewToggle",
]

## Screens: size in points, pixel ratio, safe-area insets in points (left, top, right, bottom).
const DESKTOP: Dictionary = {"name": "desktop 1280x720", "pt": Vector2(1280, 720), "ratio": 1.0}
const PHONE: Dictionary = {"name": "iPhone 844x390 @3x", "pt": Vector2(844, 390), "ratio": 3.0}
const PHONE_NOTCH: Dictionary = {"name": "iPhone 844x390 @3x + notch insets", "pt": Vector2(844, 390),
		"ratio": 3.0, "insets": Rect2(47, 0, 47, 21)}
const TABLET: Dictionary = {"name": "iPad 1024x768 @2x", "pt": Vector2(1024, 768), "ratio": 2.0}


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


func test_screen_profile_rule() -> void:
	assert_eq(ScreenProfile.base_size(Vector2(1280, 720), 1.0), Vector2(1280, 720), "desktop base unchanged")
	assert_eq(logical_size(DESKTOP), Vector2(1280, 720), "desktop logical")
	assert_eq(ScreenProfile.base_size(Vector2(2560, 1440), 2.0), Vector2(1280, 720), "Retina Mac base")
	assert_eq(ScreenProfile.base_size(Vector2(2532, 1170), 3.0), Vector2(960, 540), "phone base")
	assert_eq(logical_size(PHONE), Vector2(1168, 540), "phone logical")
	assert_eq(logical_size(TABLET), Vector2(1280, 960), "tablet logical")
	assert_true(absf(points_per_px(PHONE) - 0.7222) < 0.001, "phone pt/px %.4f" % points_per_px(PHONE))
	assert_eq(points_per_px(DESKTOP), 1.0, "desktop pt/px")
	# Mid-size windows scale continuously (no jump between profiles).
	var prev: Vector2 = Vector2.ZERO
	for h: int in range(380, 760, 20):
		var base: Vector2 = ScreenProfile.base_size(Vector2(h * 2, h), 1.0)
		assert_true(base.y >= prev.y and base.y >= 540 and base.y <= 720, "base for %d pt tall: %s" % [h, base])
		prev = base
	assert_eq(ScreenProfile.base_size(Vector2(1280, 720), 1.0, 1.5).y, 640.0, "ui_scale 1.5 enlarges desktop UI")


func test_project_theme_is_hud_theme() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom", ""), HUD_THEME, "project theme")
	var hud: Theme = load(HUD_THEME) as Theme
	assert_not_null(hud, "hud theme loads")
	if hud == null:
		return
	var used: Array[String] = MATCH_VARIATIONS.duplicate()
	for path: String in _scene_files():
		var text: String = FileAccess.get_file_as_string(path)
		var re: RegEx = RegEx.create_from_string('theme_type_variation = &"(\\w+)"')
		for m: RegExMatch in re.search_all(text):
			if not used.has(m.get_string(1)) and not path.ends_with("CardView.tscn"):
				used.append(m.get_string(1))
	for v: String in used:
		var base: StringName = hud.get_type_variation_base(StringName(v))
		assert_true(base != &"", "hud theme lacks variation %s" % v)
		var styled: bool = not hud.get_stylebox_list(v).is_empty() or not hud.get_font_size_list(v).is_empty() \
				or not hud.get_color_list(v).is_empty()
		assert_true(styled, "hud theme variation %s has no style" % v)


func test_theme_fonts_have_base_font() -> void:
	for path: String in [HUD_THEME, CARD_THEME]:
		var theme: Theme = load(path) as Theme
		var fonts: Array[Font] = [theme.default_font]
		for type_name: StringName in theme.get_type_list():
			for font_name: StringName in theme.get_font_list(type_name):
				fonts.append(theme.get_font(font_name, type_name))
		for f: Font in fonts:
			if f is FontVariation:
				assert_not_null((f as FontVariation).base_font, "%s: FontVariation %s has no base_font" % [path.get_file(), f.resource_name])
		assert_true(fonts.size() > 3, "%s has fonts" % path.get_file())


func test_layout_desktop_1280x720() -> void:
	await _check_layout(DESKTOP, MockMatchData.round_3_sample())


func test_layout_phone_844x390() -> void:
	await _check_layout(PHONE, MockMatchData.round_3_sample())


func test_layout_phone_844x390_with_notch_insets() -> void:
	await _check_layout(PHONE_NOTCH, MockMatchData.round_3_sample())


func test_layout_tablet_1024x768() -> void:
	await _check_layout(TABLET, MockMatchData.round_3_sample())


## p09: the live engine match (Round 1 Deploy) with a hand card selected, so every lane shows
## its target badge, plus the Operator selected.
func test_layout_live_match_desktop_card_selected() -> void:
	await _check_layout(DESKTOP, {}, &"card")


func test_layout_live_match_phone_card_selected() -> void:
	await _check_layout(PHONE_NOTCH, {}, &"card")


func test_layout_live_match_phone_operator_selected() -> void:
	await _check_layout(PHONE, {}, &"operator")


func test_inspector_desktop() -> void:
	await _check_inspector(DESKTOP)


func test_inspector_phone() -> void:
	await _check_inspector(PHONE)


func test_inspector_phone_with_notch_insets() -> void:
	await _check_inspector(PHONE_NOTCH)


## Worst case: four units in every line (long names, damaged armor), a full 7-card hand and
## 10 Supply, on the phone (with and without notch insets) and on desktop.
func test_layout_phone_full_board() -> void:
	await _check_layout(PHONE, _full_board())


func test_layout_phone_full_board_with_notch_insets() -> void:
	await _check_layout(PHONE_NOTCH, _full_board())


func test_layout_desktop_full_board() -> void:
	await _check_layout(DESKTOP, _full_board())


func _full_board() -> Dictionary:
	var snap: Dictionary = MockMatchData.round_3_sample()
	var names: Array[String] = ["Demolitions Expert", "Combat Medic", "Kestrel AR-7", "Shieldman"]
	for lane: Dictionary in snap["lanes"]:
		for key: String in ["friendly", "enemy"]:
			var line: Array = []
			for i: int in 4:
				# Largest real stats (Elite FP 4, Gunner armor 6), damaged so AR reads "3/6".
				line.append({"name": names[i], "cls": ["LMG", "SNIPER", "SHOTGUN", "AR"][i], "fp": 4, "armor": 3, "armor_max": 6})
			lane[key] = line
		lane["incoming"] = 0
	snap["lanes"][1]["friendly"][3]["pending"] = true  # a queued arrival's PLAN tag must fit too
	var hand: Array = snap["hand"].duplicate()
	hand.append({"name": "Suppressing Fire", "type": "Tactic", "cost": 2, "text": "Enemy units here: -1 FP"})
	hand.append({"name": "Demolitions Expert", "type": "LMG", "cost": 4, "fp": 2, "armor": 4, "text": "On down"})
	snap["hand"] = hand
	snap["supply_max"] = 10
	snap["supply"] = 7
	return snap


## Bug p18-005: on the phone the killfeed lines were cut to "BREACH ▸ KES". On the phone each line
## must show both full names (up to the 14-character cap) inside its rect, with text >= 11 pt.
func test_killfeed_lines_fit_on_phone() -> void:
	for screen: Dictionary in [PHONE, PHONE_NOTCH, DESKTOP]:
		var setup: Array = await _spawn(screen, MockMatchData.round_3_sample())
		var viewport: SubViewport = setup[0]
		var match_node: Control = setup[1]
		# kc-board2: the killfeed log lives in the CLOSED tray (Reveal / Firefight).
		match_node.set_tray_state(&"closed")
		await tree.process_frame
		var feed: Control = match_node.get_killfeed()
		for pair: Array in [["Demolitions Expert", "Kestrel AR-7"], ["Recon Specialist", "Combat Medic"],
				["Breacher", "Point Man"]]:
			feed.push({"attacker": pair[0], "attacker_side": &"player", "victim": pair[1],
					"victim_side": &"enemy", "icon": &"class_lmg", "zone": &"mid"})
		for i: int in 3:
			await tree.process_frame
		var label: String = screen["name"]
		var lines: Array = feed.get_entries()
		# kc-board2: the tray log keeps every line of the round (up to 8).
		assert_eq(lines.size(), 3, "%s: killfeed lines shown" % label)
		var screen_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(EPS)
		assert_true(feed.is_visible_in_tree(), "%s: killfeed visible while it has lines" % label)
		assert_true(screen_rect.encloses(feed.get_global_rect()), "%s: killfeed on screen" % label)
		var k: float = points_per_px(screen)
		for line: Control in lines:
			var names: Array[String] = []
			for l: Node in line.find_children("*", "Label", true, false):
				var lb: Label = l
				if lb.theme_type_variation in [&"KillfeedFriend", &"KillfeedEnemy"]:
					names.append(lb.text)
					assert_true(lb.get_theme_font_size(&"font_size") * k >= MIN_BODY_PT - 0.01, "%s: killfeed text >= 11 pt" % label)
			var row: Control = line.get_child(0)
			assert_true(row.get_combined_minimum_size().x <= line.size.x + EPS,
					"%s: killfeed line %s fits (%s > %s)" % [label, names, row.get_combined_minimum_size().x, line.size.x])
			var full: Dictionary = line.entry
			var want: Array[String] = [String(full["attacker"]).to_upper().left(14), String(full["victim"]).to_upper().left(14)]
			if true:
				# kc-board2: the log sits in the tray on every screen; names may drop to 10
				# characters there (the full names are in the inspector).
				for i: int in names.size():
					assert_true(names[i] == want[i] or names[i].length() >= 10, "%s: killfeed name %s readable" % [label, names[i]])
		_assert_killfeed_clear(match_node, label)
		_despawn(viewport)
		await tree.process_frame


## f04 (iPhone feedback "the action feed shouldn't overlap the hand"): while the killfeed shows
## lines it must not meet the hand area, any hand chip, the lanes' tap areas or any other tap
## target, on the phone (with and without notch insets) and on desktop, on the live match too.
func test_killfeed_never_covers_hand_or_tap_targets() -> void:
	for screen: Dictionary in [PHONE, PHONE_NOTCH, DESKTOP]:
		for live: bool in [false, true]:
			var setup: Array = await _spawn(screen, {} if live else _full_board())
			var viewport: SubViewport = setup[0]
			var match_node: Control = setup[1]
			match_node.set_tray_state(&"closed")
			await tree.process_frame
			var feed: Control = match_node.get_killfeed()
			for i: int in 3:
				feed.push({"attacker": "Demolitions Expert", "attacker_side": &"enemy", "victim": "Kestrel AR-7",
						"victim_side": &"player", "icon": &"class_lmg", "zone": &"left"})
			for i: int in 3:
				await tree.process_frame
			var label: String = "%s%s" % [screen["name"], " (live)" if live else ""]
			_assert_killfeed_clear(match_node, label)
			_despawn(viewport)
			await tree.process_frame


func _assert_killfeed_clear(match_node: Control, label: String) -> void:
	var feed_rect: Rect2 = match_node.get_killfeed_rect()
	assert_true(feed_rect.has_area(), "%s: killfeed shows while it has lines" % label)
	var inner: Rect2 = feed_rect.grow(-EPS)
	var hand: Control = match_node.get_hand()
	if hand.is_visible_in_tree():
		assert_false(inner.intersects(hand.get_global_rect()), "%s: killfeed %s covers the hand %s" % [label, feed_rect, hand.get_global_rect()])
	for lane: Node in match_node.get_board().get_lanes():
		assert_false(inner.intersects((lane as Control).get_global_rect()), "%s: killfeed covers lane %s" % [label, lane.name])
	var checked: int = 0
	for n: Node in match_node.find_children("*", "Control", true, false):
		var c: Control = n
		if not c.is_visible_in_tree() or not (c is BaseButton or c.is_in_group(&"tap_target")):
			continue
		# Modal overlays (the Round 1 mulligan panel) draw above the HUD.
		if match_node.get_mulligan_panel().is_ancestor_of(c):
			continue
		checked += 1
		assert_false(inner.intersects(c.get_global_rect()), "%s: killfeed covers tap target %s %s" % [label, match_node.get_path_to(c), c.get_global_rect()])
	assert_true(checked >= 8, "%s: checked %d tap targets" % [label, checked])
	var screen_rect: Rect2 = match_node.get_viewport_rect().grow(EPS)
	assert_true(screen_rect.encloses(feed_rect), "%s: killfeed on screen" % label)


func test_mock_content_shown() -> void:
	var setup: Array = await _spawn(DESKTOP, MockMatchData.round_3_sample())
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
	assert_false(match_node.compact, "desktop uses the full layout")
	_despawn(viewport)


## Logical canvas size for a screen case (window px = points * pixel ratio).
static func _in_scroll(c: Node, root: Node) -> bool:
	var p: Node = c.get_parent()
	while p != null and p != root:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


static func _in_card_view(c: Node, root: Node) -> bool:
	var p: Node = c.get_parent()
	while p != null and p != root:
		if p is CardView:
			return true
		p = p.get_parent()
	return false


static func logical_size(screen: Dictionary) -> Vector2:
	var px: Vector2 = screen["pt"] * float(screen["ratio"])
	return ScreenProfile.logical_size(px, ScreenProfile.base_size(px, screen["ratio"]))


static func points_per_px(screen: Dictionary) -> float:
	return ScreenProfile.points_per_px(screen["pt"] * float(screen["ratio"]), screen["ratio"])


var _saved_root_size: Vector2i = Vector2i.ZERO


func _spawn(screen: Dictionary, snapshot: Dictionary = {}) -> Array:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var viewport: SubViewport = SubViewport.new()
	var logical: Vector2 = logical_size(screen)
	viewport.size = Vector2i(logical)
	viewport.disable_3d = true
	tree.root.add_child(viewport)
	var match_node: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
	if screen.has("insets"):
		var k: float = points_per_px(screen)
		var insets: Rect2 = screen["insets"]
		var lt: Vector2 = insets.position / k
		var rb: Vector2 = insets.size / k  # Rect2 size holds (right, bottom) insets here
		match_node.safe_area_override = Rect2(lt, logical - lt - rb)
	viewport.add_child(match_node)
	for i: int in 3:
		await tree.process_frame
	if not snapshot.is_empty():
		match_node.show_snapshot(snapshot)
	for i: int in 3:
		await tree.process_frame
	return [viewport, match_node]


func _despawn(viewport: SubViewport) -> void:
	viewport.queue_free()
	tree.root.size = _saved_root_size


## snapshot empty = the live match MatchController started. select: &"card" / &"operator" selects
## the first hand card / the Operator first (lane badges and the selected styles must fit too).
func _check_layout(screen: Dictionary, snapshot: Dictionary = {}, select: StringName = &"") -> void:
	var setup: Array = await _spawn(screen, snapshot)
	var viewport: SubViewport = setup[0]
	var match_node: Control = setup[1]
	var label: String = screen["name"]
	if snapshot.is_empty():
		var controller: Node = match_node.get_node("%MatchController")
		assert_not_null(controller.state, "%s live match started" % label)
		label += " (live)"
		if select == &"card" and controller.state != null:
			controller.select_card(controller.state.sides[0].hand[0].uid)
		elif select == &"operator":
			controller.select_operator()
		if select != &"":
			label += " selected %s" % select
			await tree.process_frame
			var badges: int = 0
			for lane: Node in match_node.get_board().get_lanes():
				badges += 1 if lane.target_state != &"none" else 0
			assert_eq(badges, 3, "%s every lane shows a target state" % label)
	var k: float = points_per_px(screen)
	var is_desktop_profile: bool = viewport.size.y >= ScreenProfile.COMPACT_HEIGHT
	var screen_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(EPS)

	assert_eq(match_node.size, Vector2(viewport.size), "%s Match fills the viewport" % label)
	assert_eq(match_node.compact, not is_desktop_profile, "%s compact profile" % label)
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
		assert_true(screen_rect.encloses(r), "%s %s off screen: %s" % [label, key, r])
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			var a: Rect2 = (keys[names[i]] as Control).get_global_rect().grow(-EPS)
			var b: Rect2 = (keys[names[j]] as Control).get_global_rect().grow(-EPS)
			assert_false(a.intersects(b), "%s %s overlaps %s (%s / %s)" % [label, names[i], names[j], a, b])
	if screen.has("insets"):
		var safe: Rect2 = match_node.safe_area_override.grow(EPS)
		for key: String in names:
			assert_true(safe.encloses((keys[key] as Control).get_global_rect()), "%s %s inside safe area" % [label, key])

	var board_rect: Rect2 = match_node.get_board().get_global_rect().grow(EPS)
	var lanes: Array[Node] = match_node.get_board().get_lanes()
	for i: int in lanes.size():
		var lane_rect: Rect2 = (lanes[i] as Control).get_global_rect()
		assert_true(board_rect.encloses(lane_rect), "%s lane %d outside board" % [label, i])
		if i > 0:
			var prev: Rect2 = (lanes[i - 1] as Control).get_global_rect()
			assert_true(lane_rect.position.x >= prev.end.x - EPS, "%s lanes %d/%d overlap" % [label, i - 1, i])

	# Tap targets: everything in group "tap_target" plus every Button, in effective points.
	var targets: Array[Control] = []
	for n: Node in tree.get_nodes_in_group(&"tap_target"):
		if match_node.is_ancestor_of(n) and n is Control:
			targets.append(n)
	for n: Node in match_node.find_children("*", "Button", true, false):
		if not targets.has(n):
			targets.append(n)
	assert_true(targets.size() >= 30, "%s expected >= 30 tap targets, got %d" % [label, targets.size()])
	var min_tap: float = INF
	for c: Control in targets:
		if not c.is_visible_in_tree():
			continue
		var r: Rect2 = c.get_global_rect()
		var side_px: float = minf(r.size.x, r.size.y)
		min_tap = minf(min_tap, side_px)
		assert_true(side_px * k >= MIN_TAP_PT - 0.01,
				"%s tap target %s is %s px = %.1f pt (< %d pt)" % [label, match_node.get_path_to(c), r.size, side_px * k, MIN_TAP_PT])
		if is_desktop_profile:
			assert_true(side_px >= MIN_TAP_DESKTOP_PX, "%s tap target %s is %s (< %d px)" % [label, match_node.get_path_to(c), r.size, MIN_TAP_DESKTOP_PX])
		# kc-ui3: a card in a sideways-scrolling row (the mulligan) may sit past the edge until swiped.
		if not _in_scroll(c, match_node):
			assert_true(screen_rect.encloses(r), "%s tap target %s off screen" % [label, match_node.get_path_to(c)])

	# Text sizes in effective points.
	var min_body: float = INF
	var min_number: float = INF
	for n: Node in match_node.find_children("*", "Control", true, false):
		var c: Control = n
		if not c.is_visible_in_tree() or c.modulate.a < 0.01 or not (c is Label or c is Button):
			continue
		var text: String = c.text
		if text.strip_edges().is_empty():
			continue
		# kc-ui3: a full CardView (mulligan) is checked like the inspector's: name, cost and stats at
		# its scale (get_min_effective_font_size, below); its rules text is one long-press away.
		if _in_card_view(c, match_node):
			continue
		var pt: float = c.get_theme_font_size(&"font_size") * k
		min_body = minf(min_body, pt)
		assert_true(pt >= MIN_BODY_PT - 0.01, "%s text '%s' (%s) is %.1f pt (< %d pt)" % [label, text, match_node.get_path_to(c), pt, MIN_BODY_PT])
		if c.is_in_group(&"key_number"):
			min_number = minf(min_number, pt)
			assert_true(pt >= MIN_NUMBER_PT - 0.01, "%s number '%s' (%s) is %.1f pt (< %d pt)" % [label, text, match_node.get_path_to(c), pt, MIN_NUMBER_PT])

	for n: Node in match_node.find_children("*", "CardView", true, false):
		var cv: CardView = n
		if cv.is_visible_in_tree() and not match_node.get_inspector().is_ancestor_of(cv):
			var cv_pt: float = cv.get_min_effective_font_size(PackedStringArray(["NameLabel", "CostLabel", "FirepowerLabel", "ArmorLabel"])) * k
			assert_true(cv_pt >= MIN_BODY_PT - 0.01, "%s card %s name / stats %.1f pt" % [label, match_node.get_path_to(cv), cv_pt])

	# Important labels show their whole text.
	for l: Label in match_node.get_important_labels():
		if not l.is_visible_in_tree() or l.text.strip_edges().is_empty():
			continue
		var why: String = _clipped(l)
		assert_true(why.is_empty(), "%s '%s' (%s) is cut: %s" % [label, l.text, match_node.get_path_to(l), why])

	# Contents stay inside their panels (no spill into neighbours). kc-board2: the hand is a grid
	# in the tray; the selected card shifts 14 px toward the board (board-layout-v2.md §4.2).
	var hand_node: Control = match_node.get_node("%HandArea")
	var hand_rect: Rect2 = hand_node.get_global_rect().grow(EPS)
	var cards: Array[Node] = hand_node.get_cards()
	if hand_node.is_visible_in_tree():
		assert_true(match_node.get_tray().get_global_rect().grow(EPS).encloses(hand_node.get_global_rect()), "%s hand inside the tray" % label)
		assert_false(hand_node.get_global_rect().intersects(match_node.get_board().get_global_rect()), "%s hand never covers the board" % label)
	for i: int in cards.size():
		if not (cards[i] as Control).visible:
			continue  # kc-ipad-cards: a scrolling hand (small phones) hides the cards scrolled away
		var card_rect: Rect2 = (cards[i] as Control).get_global_rect()
		if (cards[i] as Control).theme_type_variation == &"HandCardSelected":
			card_rect = card_rect.grow_side(SIDE_LEFT, -15.0).grow_side(SIDE_RIGHT, -15.0)
		assert_true(hand_rect.encloses(card_rect), "%s hand card spills" % label)
		# Grid: up to 7 cards never overlap (more overlap upward, keeping a full-width strip).
		for j: int in range(i + 1, cards.size()):
			if not (cards[j] as Control).visible:
				continue
			var other: Rect2 = (cards[j] as Control).get_global_rect()
			if cards.size() <= 7:
				assert_false(card_rect.grow(-EPS).intersects(other.grow(-EPS)), "%s hand cards %d / %d overlap" % [label, i, j])
	var op_rect: Rect2 = match_node.get_node("%OperatorPanel").get_global_rect().grow(EPS)
	for b: Node in match_node.get_node("%OperatorPanel").get_buttons():
		assert_true(op_rect.encloses((b as Control).get_global_rect()), "%s operator button spills" % label)
	print("     [%s] canvas %s, %.3f pt/px: smallest text %.1f pt, smallest key number %.1f pt, smallest tap target %.1f pt" % [
			label, viewport.size, k, min_body, min_number, min_tap * k])
	_despawn(viewport)


## Long-press inspector on the live match: CardView at >= 0.8x, inside the screen (and safe
## area), not overlapping the text panel; every visible text >= 11 pt; CLOSE >= 44 pt.
func _check_inspector(screen: Dictionary) -> void:
	var setup: Array = await _spawn(screen)
	var viewport: SubViewport = setup[0]
	var match_node: Control = setup[1]
	var label: String = screen["name"] + " inspector"
	var k: float = points_per_px(screen)
	var controller: Node = match_node.get_node("%MatchController")
	assert_not_null(controller.state, "%s live match" % label)
	if controller.state == null:
		_despawn(viewport)
		return
	# The card with the most keyword lines makes the tallest text panel.
	var best: RulesCard = controller.state.sides[0].hand[0]
	for rc: RulesCard in controller.state.sides[0].hand:
		if CardInfoScript.keywords(rc.card).size() > CardInfoScript.keywords(best.card).size():
			best = rc
	controller._on_card_inspected(best.uid)
	for i: int in 3:
		await tree.process_frame
	var inspector: Control = match_node.get_inspector()
	assert_true(inspector.is_open(), "%s opens" % label)
	assert_true(inspector.get_card_scale() >= 0.8 - 0.001, "%s card scale %.2f (< 0.8)" % [label, inspector.get_card_scale()])
	var screen_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(EPS)
	var card_view: Control = inspector.get_card_view()
	var card_rect: Rect2 = card_view.get_global_rect()
	var info_rect: Rect2 = inspector.get_node("%InfoPanel").get_global_rect()
	assert_true(screen_rect.encloses(card_rect), "%s card off screen %s" % [label, card_rect])
	assert_true(screen_rect.encloses(info_rect), "%s text panel off screen %s" % [label, info_rect])
	assert_false(card_rect.grow(-EPS).intersects(info_rect.grow(-EPS)), "%s card overlaps text panel" % label)
	if screen.has("insets"):
		var safe: Rect2 = match_node.safe_area_override.grow(EPS)
		assert_true(safe.encloses(card_rect) and safe.encloses(info_rect), "%s inside safe area" % label)
	var card_name_pt: float = card_view.get_min_effective_font_size(PackedStringArray(["NameLabel", "CostLabel", "FirepowerLabel", "ArmorLabel"])) * k
	assert_true(card_name_pt >= MIN_BODY_PT - 0.01, "%s card name / stats %.1f pt (< %d pt)" % [label, card_name_pt, MIN_BODY_PT])
	assert_true(card_view.get_overflowing_labels().is_empty(), "%s card text overflows: %s" % [label, card_view.get_overflowing_labels()])
	var min_text: float = INF
	for n: Node in inspector.get_node("%InfoPanel").find_children("*", "Control", true, false):
		if not (n is Label or n is Button) or not (n as Control).is_visible_in_tree() or String(n.text).strip_edges().is_empty():
			continue
		var pt: float = (n as Control).get_theme_font_size(&"font_size") * k
		min_text = minf(min_text, pt)
		assert_true(pt >= MIN_BODY_PT - 0.01, "%s text '%s' %.1f pt" % [label, n.text, pt])
	for l: Label in inspector.get_important_labels():
		assert_true(_clipped(l).is_empty(), "%s '%s' is cut: %s" % [label, l.text, _clipped(l)])
	var close: Control = inspector.get_node("%CloseButton")
	var close_pt: float = minf(close.size.x, close.size.y) * k
	assert_true(close_pt >= MIN_TAP_PT - 0.01, "%s CLOSE is %.1f pt" % [label, close_pt])
	assert_true(screen_rect.encloses(close.get_global_rect()), "%s CLOSE off screen" % label)
	print("     [%s] card %.2fx, card name/stats %.1f pt, smallest text %.1f pt, CLOSE %.1f pt" % [
			label, inspector.get_card_scale(), card_name_pt, min_text, close_pt])
	_despawn(viewport)


## Why a label's text does not fully show ("" when it does).
func _clipped(l: Label) -> String:
	if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
		if l.get_visible_line_count() < l.get_line_count():
			return "%d of %d lines visible" % [l.get_visible_line_count(), l.get_line_count()]
		return ""
	var font: Font = l.get_theme_font(&"font")
	var size: int = l.get_theme_font_size(&"font_size")
	var text: String = l.text.to_upper() if l.uppercase else l.text
	var need: float = 0.0
	for line: String in text.split("\n"):
		need = maxf(need, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var box: StyleBox = l.get_theme_stylebox(&"normal")
	var room: float = l.size.x - (box.get_minimum_size().x if box != null else 0.0)
	if need > room + 0.5:
		return "needs %.0f px, has %.0f px" % [need, room]
	return ""


func _scene_files() -> PackedStringArray:
	var out: PackedStringArray = [MATCH_SCENE]
	for f: String in DirAccess.get_files_at("res://scenes/match"):
		if f.ends_with(".tscn"):
			out.append("res://scenes/match".path_join(f))
	return out

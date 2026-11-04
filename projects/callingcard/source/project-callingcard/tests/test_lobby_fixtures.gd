# test_lobby_fixtures.gd
# Purpose: Shared helpers for the cc13 hub and Lobby Duel tests (no test methods, so the runner
#   skips it): screens in a SubViewport sized like a real device (ScreenProfile, as in
#   tests/test_duel_layout.gd), duel driving through the duel screen's own signals, layout checks
#   (on screen, inside the safe area, no overlap, 44 pt / 64 px targets, 11 pt text) and a
#   router in dry-run mode so no test changes the runner's scene.
# Author: Mechanics Developer Agent
extends RefCounted

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const MIN_TAP_PT: float = 44.0
const MIN_TAP_PX: float = 64.0
const MIN_TEXT_PT: float = 11.0
const EPS: float = 0.5

const DESKTOP: Dictionary = {"name": "desktop 1280x720", "pt": Vector2(1280, 720), "ratio": 1.0}
const PHONE: Dictionary = {"name": "phone 844x390 @3x + notch", "pt": Vector2(844, 390), "ratio": 3.0,
		"insets": Rect2(47, 0, 47, 21)}
const SCREENS: Array[Dictionary] = [DESKTOP, PHONE]

var tree: SceneTree
var viewport: SubViewport = null
var _saved_root_size: Vector2i
var _router_was_dry: bool = false


func _init(p_tree: SceneTree) -> void:
	tree = p_tree
	var router: Node = tree.root.get_node("SceneRouter")
	_router_was_dry = router.dry_run
	router.dry_run = true
	router.last_requested = ""


static func logical_size(screen: Dictionary) -> Vector2:
	var px: Vector2 = screen["pt"] * float(screen["ratio"])
	return ScreenProfile.logical_size(px, ScreenProfile.base_size(px, screen["ratio"]))


static func points_per_px(screen: Dictionary) -> float:
	return ScreenProfile.points_per_px(screen["pt"] * float(screen["ratio"]), screen["ratio"])


## Safe rect in logical px for the screen's notch insets (empty when it has none).
static func safe_rect(screen: Dictionary) -> Rect2:
	if not screen.has("insets"):
		return Rect2()
	var logical: Vector2 = logical_size(screen)
	var k: float = points_per_px(screen)
	var insets: Rect2 = screen["insets"]
	return Rect2(insets.position / k, logical - insets.position / k - insets.size / k)


func router() -> Node:
	return tree.root.get_node("SceneRouter")


## Adds node (not yet in the tree) to a SubViewport the size of screen; waits a few frames.
func spawn(node: Control, screen: Dictionary = PHONE) -> Control:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	viewport = SubViewport.new()
	viewport.size = Vector2i(logical_size(screen))
	viewport.disable_3d = true
	tree.root.add_child(viewport)
	if "safe_area_override" in node:
		node.safe_area_override = safe_rect(screen)
	viewport.add_child(node)
	await frames(4)
	return node


func frames(n: int = 2) -> void:
	for i: int in n:
		await tree.process_frame


func despawn() -> void:
	if viewport != null:
		viewport.queue_free()
		viewport = null
		tree.root.size = _saved_root_size
	await tree.process_frame


func finish() -> void:
	await despawn()
	router().dry_run = _router_was_dry


# --- Duel driving ----------------------------------------------------------------------------

## Plays one legal player move through the duel screen's signals. Returns false when it isn't
## the player's turn.
func play_move(duel: Control, pick: int = 0) -> bool:
	var ctrl: Node = duel.get_node("%DuelController")
	if ctrl.phase != &"player":
		return false
	var moves: Array[Dictionary] = WallRules.legal_moves(ctrl.state)
	var m: Dictionary = moves[clampi(pick, 0, moves.size() - 1)]
	return await play_exact(duel, m)


## Plays this move ({card, slot, copy_from}) through the screen's signals.
func play_exact(duel: Control, m: Dictionary) -> bool:
	var ctrl: Node = duel.get_node("%DuelController")
	var card: CardData = m["card"]
	duel.card_picked.emit(card.id)
	duel.slot_chosen.emit(m["slot"])
	if m.get("copy_from", &"") != &"":
		duel.target_tapped.emit(m["copy_from"])
	var before: int = ctrl.state.placements
	duel.place_confirmed.emit(card.id, m["slot"])
	await frames(2)
	return ctrl.state.placements > before


## Plays player moves until `placements` cards are on the wall (or the duel ends).
func play_until(duel: Control, placements: int) -> void:
	var ctrl: Node = duel.get_node("%DuelController")
	var guard: int = 0
	while ctrl.state != null and ctrl.state.placements < placements and ctrl.phase != &"over" and guard < 80:
		guard += 1
		if not await play_move(duel):
			await frames(1)


func play_to_end(duel: Control) -> void:
	await play_until(duel, 99)


## Presses BEGIN on the coin flip once it is open.
func begin(duel: Control) -> void:
	var guard: int = 0
	while duel.get_overlay().kind() != &"coin" and guard < 10:
		guard += 1
		await frames(1)
	var b: Button = duel.get_overlay().get_button(&"begin")
	if b != null:
		b.pressed.emit()
	await frames(2)

# --- Layout -----------------------------------------------------------------------------------

## Failures (Array[String]) for the visible controls: on screen, inside the safe area, tap targets,
## text size, whole text shown, and no overlap between leaf controls (not containers of others).
func layout_failures(root: Control, controls: Dictionary, screen: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var k: float = points_per_px(screen)
	var logical: Vector2 = logical_size(screen)
	var safe: Rect2 = safe_rect(screen)
	if not safe.has_area():
		safe = Rect2(Vector2.ZERO, logical)
	safe = safe.grow(EPS)
	var leaves: Array[Control] = []
	for key: String in controls:
		var c: Control = controls[key]
		if c == null or not c.is_visible_in_tree():
			continue
		var r: Rect2 = c.get_global_rect()
		if not safe.encloses(r):
			out.append("%s %s: %s outside the safe area %s" % [screen["name"], key, r, safe])
		if c is BaseButton:
			if minf(r.size.x, r.size.y) < MIN_TAP_PX - EPS or minf(r.size.x, r.size.y) * k < MIN_TAP_PT - 0.01:
				out.append("%s %s: tap target %s < 64 px / 44 pt (k %.3f)" % [screen["name"], key, r.size, k])
		if c is Label or c is Button:
			var fs: int = c.get_theme_font_size(&"font_size")
			if fs * k < MIN_TEXT_PT - 0.01:
				out.append("%s %s: text %d px = %.1f pt < 11 pt" % [screen["name"], key, fs, fs * k])
		if c is Label and (c as Label).autowrap_mode == TextServer.AUTOWRAP_OFF and (c as Label).text != "":
			var need: float = (c as Label).get_minimum_size().x
			if need > r.size.x + 1.0:
				out.append("%s %s: text '%s' clipped (%.0f > %.0f)" % [screen["name"], key, c.text, need, r.size.x])
		if c is Button and not c.clip_text:
			var need_b: float = (c as Button).get_minimum_size().x
			if need_b > r.size.x + 1.0:
				out.append("%s %s: button text clipped" % [screen["name"], key])
		var is_container: bool = false
		for o: Variant in controls.values():
			if o != c and o != null and c.is_ancestor_of(o):
				is_container = true
		if not is_container:
			leaves.append(c)
	for i: int in leaves.size():
		for j: int in range(i + 1, leaves.size()):
			var a: Rect2 = leaves[i].get_global_rect().grow(-EPS)
			var b: Rect2 = leaves[j].get_global_rect().grow(-EPS)
			if a.intersects(b):
				out.append("%s %s overlaps %s" % [screen["name"], leaves[i].name, leaves[j].name])
	# Everything a player reads must be at least 11 pt, not only the key controls.
	for n: Node in root.find_children("*", "Label", true, false):
		var l: Label = n
		if l.is_visible_in_tree() and l.text != "" and l.get_theme_font_size(&"font_size") * k < MIN_TEXT_PT - 0.01:
			out.append("%s label %s: %.1f pt" % [screen["name"], l.name, l.get_theme_font_size(&"font_size") * k])
	for n: Node in root.find_children("*", "Button", true, false):
		var bt: Button = n
		if bt.is_visible_in_tree():
			var sz: Vector2 = bt.get_global_rect().size
			if minf(sz.x, sz.y) * k < MIN_TAP_PT - 0.01:
				out.append("%s button %s: %s < 44 pt" % [screen["name"], bt.name, sz])
	return out

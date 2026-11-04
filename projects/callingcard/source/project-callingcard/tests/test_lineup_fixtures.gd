# test_lineup_fixtures.gd
# Purpose: Shared helpers for the cc10 lineup builder tests (no test methods, so the runner skips
#   it). Spawns scenes/LineupBuilder.tscn in a SubViewport the size of a real screen's logical
#   canvas (ScreenProfile, as tests/test_duel_layout.gd does), on its own Collection instance and
#   save file (tests/test_collection_fixtures.gd), so the player's save and the Collection
#   autoload are never touched. tap() sends a real press + release through the viewport's input,
#   so "one tap" means one touch, not a method call.
# Author: UI/UX Agent (cc10)
extends RefCounted

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const CollectionFx: GDScript = preload("res://tests/test_collection_fixtures.gd")
const BUILDER_SCENE: String = "res://scenes/LineupBuilder.tscn"

## Screens: size in points, pixel ratio, safe-area insets in points (left, top, right, bottom).
const DESKTOP: Dictionary = {"name": "desktop 1280x720", "pt": Vector2(1280, 720), "ratio": 1.0}
const PHONE: Dictionary = {"name": "iPhone 844x390 @3x", "pt": Vector2(844, 390), "ratio": 3.0}
const PHONE_NOTCH: Dictionary = {"name": "iPhone 844x390 @3x + notch insets", "pt": Vector2(844, 390),
		"ratio": 3.0, "insets": Rect2(47, 0, 47, 21)}
const PHONE_SE: Dictionary = {"name": "iPhone SE 667x375 @2x", "pt": Vector2(667, 375), "ratio": 2.0}
const SCREENS: Array[Dictionary] = [DESKTOP, PHONE, PHONE_NOTCH, PHONE_SE]

## A legal lineup from the starting collection: Clearance 1+3+2+2+2 = 10.
const VALID_IDS: Array[StringName] = [&"chrome_tiger", &"snow_blind", &"glacier", &"neon_rain", &"mayday"]

var tree: SceneTree
var fx: RefCounted
var viewport: SubViewport
var builder: Control
var collection: Node
var screen: Dictionary
var taps: int = 0
var _saved_root_size: Vector2i
var _router_dry_run: bool = false


func _init(p_tree: SceneTree) -> void:
	tree = p_tree
	fx = CollectionFx.new(tree)


static func logical_size(s: Dictionary) -> Vector2:
	var px: Vector2 = s["pt"] * float(s["ratio"])
	return ScreenProfile.logical_size(px, ScreenProfile.base_size(px, s["ratio"]))


static func points_per_px(s: Dictionary) -> float:
	return ScreenProfile.points_per_px(s["pt"] * float(s["ratio"]), s["ratio"])


## Spawns the builder. owned: card ids the collection owns (null = the starting cards).
## saved: {cards, signature, loaner} saved in the collection before the builder opens.
func spawn(s: Dictionary, save_name: String, owned: Variant = null, saved: Dictionary = {}) -> Control:
	screen = s
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	var router: Node = tree.root.get_node("SceneRouter")
	_router_dry_run = router.dry_run
	router.dry_run = true
	await tree.process_frame
	collection = fx.make(save_name)
	collection.autosave = false
	if owned != null:
		collection._owned.clear()
		for id: Variant in owned:
			collection._owned[StringName(str(id))] = true
	if not saved.is_empty():
		var r: Dictionary = collection.save_lineup(saved["cards"], saved["signature"], saved.get("loaner", false))
		assert(r["valid"], "fixture saved lineup must be legal")
	viewport = SubViewport.new()
	var logical: Vector2 = logical_size(s)
	viewport.size = Vector2i(logical)
	viewport.disable_3d = true
	viewport.gui_disable_input = false
	tree.root.add_child(viewport)
	builder = (load(BUILDER_SCENE) as PackedScene).instantiate()
	builder.collection = collection
	if s.has("insets"):
		var k: float = points_per_px(s)
		var insets: Rect2 = s["insets"]
		var lt: Vector2 = insets.position / k
		var rb: Vector2 = insets.size / k  # Rect2 size holds (right, bottom) insets here
		builder.safe_area_override = Rect2(lt, logical - lt - rb)
	viewport.add_child(builder)
	await frames(4)
	return builder


func finish() -> void:
	if viewport != null:
		viewport.queue_free()
		viewport = null
	tree.root.size = _saved_root_size
	tree.root.get_node("SceneRouter").dry_run = _router_dry_run
	fx.finish()


func frames(n: int = 2) -> void:
	for i: int in n:
		await tree.process_frame


func safe_rect() -> Rect2:
	if builder.safe_area_override.has_area():
		return builder.safe_area_override.grow(0.5)
	return Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(0.5)


## One real tap (left press + release at the control's centre) through the viewport input.
## Collection cards are scrolled into view first, as a player would.
func tap(c: Control) -> void:
	var scroll: ScrollContainer = builder.get_node("%CollectionScroll")
	if scroll.is_ancestor_of(c):
		scroll.ensure_control_visible(c)
		await frames(2)
	var pos: Vector2 = c.get_global_rect().get_center()
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.position = pos
	down.global_position = pos
	viewport.push_input(down, true)
	var up: InputEventMouseButton = down.duplicate()
	up.pressed = false
	up.button_mask = 0
	viewport.push_input(up, true)
	taps += 1
	await frames(2)


func tap_card(id: StringName) -> void:
	await tap(builder.get_collection_button(id))


func tap_row(i: int) -> void:
	await tap(builder.get_row(i).get_card_button())


func tap_signature(i: int) -> void:
	await tap(builder.get_row(i).get_signature_toggle())


func tap_named(unique: String) -> void:
	await tap(builder.get_node(unique))


func ids(list: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for v: Variant in list:
		out.append(StringName(str(v)))
	return out

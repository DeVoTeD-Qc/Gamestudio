# test_album_fixtures.gd
# Purpose: Shared helpers for the cc11 Album / Cipher Lock tests (no test methods, so the runner
#   skips it). Screens as in cc07's test_duel_layout.gd (points, pixel ratio, notch insets ->
#   ScreenProfile logical canvas, laid out in a SubViewport). Each album gets its own Collection
#   instance on its own save (cc09's test_collection_fixtures.gd), so tests never touch the
#   Collection autoload's state or the player's save. Call finish() at the end of every test.
# Author: UI/UX Agent (cc11)
extends RefCounted

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const CollectionFixtures: GDScript = preload("res://tests/test_collection_fixtures.gd")
const ALBUM_SCENE: String = "res://scenes/Album.tscn"
const MIN_TAP_PT: float = 44.0
const MIN_TAP_PX: float = 64.0
const MIN_BODY_PT: float = 11.0
const EPS: float = 0.5

const DESKTOP: Dictionary = {"name": "desktop 1280x720", "pt": Vector2(1280, 720), "ratio": 1.0}
const PHONE: Dictionary = {"name": "iPhone 844x390 @3x", "pt": Vector2(844, 390), "ratio": 3.0}
const PHONE_NOTCH: Dictionary = {"name": "iPhone 844x390 @3x + notch insets", "pt": Vector2(844, 390),
		"ratio": 3.0, "insets": Rect2(47, 0, 47, 21)}
const PHONE_SMALL: Dictionary = {"name": "iPhone SE 667x375 @2x", "pt": Vector2(667, 375), "ratio": 2.0}
const SCREENS: Array[Dictionary] = [DESKTOP, PHONE, PHONE_NOTCH, PHONE_SMALL]

var tree: SceneTree
var coll_fx: RefCounted
var _saved_root_size: Vector2i
var _viewports: Array[SubViewport] = []


func _init(p_tree: SceneTree) -> void:
	tree = p_tree
	coll_fx = CollectionFixtures.new(tree)
	_saved_root_size = tree.root.size


static func logical_size(screen: Dictionary) -> Vector2:
	var px: Vector2 = screen["pt"] * float(screen["ratio"])
	return ScreenProfile.logical_size(px, ScreenProfile.base_size(px, screen["ratio"]))


static func points_per_px(screen: Dictionary) -> float:
	return ScreenProfile.points_per_px(screen["pt"] * float(screen["ratio"]), screen["ratio"])


## A fresh demo-start Collection instance (its own save file, autosave off).
func make_collection(name: String) -> Node:
	var c: Node = coll_fx.make("album_" + name)
	c.autosave = false
	return c


## Album in a SubViewport sized to the screen's logical canvas. Returns [viewport, album].
func spawn(screen: Dictionary, collection: Node, page: StringName = &"") -> Array:
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var viewport := SubViewport.new()
	var logical: Vector2 = logical_size(screen)
	viewport.size = Vector2i(logical)
	viewport.disable_3d = true
	tree.root.add_child(viewport)
	_viewports.append(viewport)
	var album: Control = (load(ALBUM_SCENE) as PackedScene).instantiate()
	album.collection = collection
	if screen.has("insets"):
		var k: float = points_per_px(screen)
		var insets: Rect2 = screen["insets"]
		var lt: Vector2 = insets.position / k
		var rb: Vector2 = insets.size / k  # Rect2 size holds (right, bottom) insets here
		album.safe_area_override = Rect2(lt, logical - lt - rb)
	viewport.add_child(album)
	if page != &"":
		album.show_page(page)
	await settle()
	return [viewport, album]


func settle(frames: int = 4) -> void:
	for i: int in frames:
		await tree.process_frame


func safe_rect(album: Control, viewport: SubViewport) -> Rect2:
	if album.safe_area_override.has_area():
		return album.safe_area_override.grow(EPS)
	return Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(EPS)


func despawn(viewport: SubViewport) -> void:
	_viewports.erase(viewport)
	if is_instance_valid(viewport):
		viewport.get_parent().remove_child(viewport)
		viewport.free()


func finish() -> void:
	for v: SubViewport in _viewports:
		if is_instance_valid(v):
			v.get_parent().remove_child(v)
			v.free()
	_viewports.clear()
	tree.root.size = _saved_root_size
	coll_fx.finish()


## Why a label's text does not fully show ("" when it does). Same rule as cc07's layout test.
static func clipped(l: Label) -> String:
	if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
		if l.get_visible_line_count() < l.get_line_count():
			return "%d of %d lines visible" % [l.get_visible_line_count(), l.get_line_count()]
		return ""
	var font: Font = l.get_theme_font(&"font")
	var fsize: int = l.get_theme_font_size(&"font_size")
	var text: String = l.text.to_upper() if l.uppercase else l.text
	var need: float = 0.0
	for line: String in text.split("\n"):
		need = maxf(need, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x)
	var box: StyleBox = l.get_theme_stylebox(&"normal")
	var room: float = l.size.x - (box.get_minimum_size().x if box != null else 0.0)
	if need > room + 0.5:
		return "needs %.0f px, has %.0f px" % [need, room]
	if l.size.y + 0.5 < font.get_height(fsize):
		return "needs %.0f px tall, has %.0f px" % [font.get_height(fsize), l.size.y]
	return ""


## A tap on a button (what a click / touch release does; cc07's tests do the same).
static func tap(b: BaseButton) -> void:
	b.pressed.emit()

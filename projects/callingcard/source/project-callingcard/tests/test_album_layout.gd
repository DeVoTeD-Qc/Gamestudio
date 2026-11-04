# test_album_layout.gd
# Purpose: Layout, readability and touch checks for the Album (cc11): scenes/Album.tscn with its
#   set pages, Triptych page, Cipher Lock, the shared CardInspector and the Triptych reveal, on
#   desktop 1280x720, iPhone 844x390 @3x (with and without notch insets) and iPhone SE 667x375 @2x.
#   Every page of every screen:
#   - header controls visible, inside the safe area and not overlapping; the page fits sideways,
#   - every tap target (Buttons + group "tap_target") >= 64 logical px and >= 44 pt,
#   - every visible text >= 11 pt and never cut (wrapped labels show all lines),
#   - cards are 4:1 and two columns fit where there is room,
#   - inspector (all 20 cards, owned or silhouette) and the Triptych reveal fit the safe area,
#   - nothing is hover-only (no tooltips; hover style == normal on hangers and tabs).
# Author: UI/UX Agent (cc11)
extends "res://tests/test_case.gd"

const Fx: GDScript = preload("res://tests/test_album_fixtures.gd")
const AlbumTheme: GDScript = preload("res://scripts/ui/album_theme.gd")


func test_album_scene_instantiates() -> void:
	var scene: PackedScene = load(Fx.ALBUM_SCENE) as PackedScene
	assert_not_null(scene, "Album.tscn loads")
	if scene == null:
		return
	var node: Node = scene.instantiate()
	for unique: String in ["%SafeArea", "%BackButton", "%CardCount", "%TabScroll", "%Tabs", "%Page", "%PageScroll",
			"%PageHost", "%Toast", "%CardInspector", "%TriptychReveal"]:
		assert_not_null(node.get_node_or_null(unique), "Album lacks %s" % unique)
	node.free()
	for path: String in _scene_files():
		assert_not_null(load(path), "%s loads" % path)


func test_theme_defines_every_variation() -> void:
	var t: Theme = AlbumTheme.build()
	var used: Array[StringName] = []
	var re: RegEx = RegEx.create_from_string('theme_type_variation = &"(\\w+)"')
	var files: PackedStringArray = _scene_files()
	for f: String in DirAccess.get_files_at("res://scripts/ui"):
		if (f.begins_with("album_") or f.begins_with("cipher_")) and f.ends_with(".gd"):
			files.append("res://scripts/ui".path_join(f))
	for path: String in files:
		for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(path)):
			used.append(StringName(m.get_string(1)))
	assert_true(used.size() > 15, "found the variations the album uses (%d)" % used.size())
	for v: StringName in used:
		assert_true(AlbumTheme.USED.has(v), "AlbumTheme.USED lists %s" % v)
	for v: StringName in AlbumTheme.USED:
		assert_eq(t.get_type_variation_base(v), AlbumTheme.USED[v], "theme variation %s" % v)
		var styled: bool = not t.get_stylebox_list(v).is_empty() or not t.get_font_size_list(v).is_empty() \
				or not t.get_color_list(v).is_empty()
		assert_true(styled, "theme variation %s has a style" % v)
	var wall: Theme = load("res://assets/themes/wall_theme.tres") as Theme
	assert_eq(t.get_stylebox(&"panel", &"AlbumPage"), wall.get_stylebox(&"panel", &"AlbumPage"), "AlbumPage is cc14's velvet page")


func test_layout_desktop() -> void:
	await _check_screen(Fx.DESKTOP)


func test_layout_phone() -> void:
	await _check_screen(Fx.PHONE)


func test_layout_phone_with_notch_insets() -> void:
	await _check_screen(Fx.PHONE_NOTCH)


func test_layout_iphone_se() -> void:
	await _check_screen(Fx.PHONE_SMALL)


func test_inspector_fits_every_card() -> void:
	var fx: RefCounted = Fx.new(tree)
	var coll: Node = fx.make_collection("inspector")
	for screen: Dictionary in Fx.SCREENS:
		var setup: Array = await fx.spawn(screen, coll)
		var viewport: SubViewport = setup[0]
		var album: Control = setup[1]
		var k: float = Fx.points_per_px(screen)
		var safe: Rect2 = fx.safe_rect(album, viewport)
		var inspector: Control = album.get_inspector()
		for c: CardData in CardDB.all_cards():
			album.inspect_card(c.id)
			await fx.settle(2)
			var label: String = "%s inspector %s" % [screen["name"], c.display_name]
			assert_true(inspector.is_open(), "%s opens" % label)
			assert_true(safe.encloses(inspector.get_panel().get_global_rect()), "%s panel %s inside safe area %s" % [label, inspector.get_panel().get_global_rect(), safe])
			assert_eq(inspector.get_card_view().locked, not coll.owns(c.id), "%s silhouette when not owned" % label)
			for l: Label in inspector.get_important_labels():
				assert_true(Fx.clipped(l).is_empty(), "%s '%s' is cut: %s" % [label, l.text, Fx.clipped(l)])
				if l.is_visible_in_tree() and l.text.strip_edges() != "":
					var pt: float = l.get_theme_font_size(&"font_size") * k
					assert_true(pt >= Fx.MIN_BODY_PT - 0.01, "%s text '%s' %.1f pt" % [label, l.text, pt])
			var close: Control = inspector.get_node("%CloseButton")
			assert_true(minf(close.size.x, close.size.y) * k >= Fx.MIN_TAP_PT - 0.01, "%s CLOSE %s" % [label, close.size])
			inspector.close()
		fx.despawn(viewport)
	fx.finish()


func test_triptych_reveal_fits_every_screen() -> void:
	var fx: RefCounted = Fx.new(tree)
	var coll: Node = fx.make_collection("reveal_fit")
	for screen: Dictionary in Fx.SCREENS:
		var setup: Array = await fx.spawn(screen, coll, &"triptychs")
		var viewport: SubViewport = setup[0]
		var album: Control = setup[1]
		var k: float = Fx.points_per_px(screen)
		var safe: Rect2 = fx.safe_rect(album, viewport)
		for t: TriptychData in CardDB.all_triptychs():
			album.play_triptych_reveal(t.id)
			var reveal: Control = album.get_reveal()
			reveal.finish()
			await fx.settle(2)
			var label: String = "%s reveal %s" % [screen["name"], t.id]
			assert_true(reveal.is_open(), "%s open" % label)
			assert_true(safe.encloses(reveal.get_panel().get_global_rect()), "%s panel %s inside safe area %s" % [label, reveal.get_panel().get_global_rect(), safe])
			var pano: CardArt = reveal.get_panorama()
			assert_true(absf(pano.size.x / pano.size.y - 12.0) < 0.2, "%s panorama is 12:1 (%s)" % [label, pano.size])
			for l: Label in reveal.get_labels():
				assert_true(Fx.clipped(l).is_empty(), "%s '%s' is cut" % [label, l.text])
				assert_true(l.get_theme_font_size(&"font_size") * k >= Fx.MIN_BODY_PT - 0.01, "%s '%s' >= 11 pt" % [label, l.text])
			var cont: Button = reveal.get_continue_button()
			assert_true(minf(cont.size.x, cont.size.y) >= Fx.MIN_TAP_PX - Fx.EPS, "%s CONTINUE %s" % [label, cont.size])
			reveal.close()
		fx.despawn(viewport)
	fx.finish()


func test_nothing_is_hover_only() -> void:
	var fx: RefCounted = Fx.new(tree)
	var coll: Node = fx.make_collection("hover")
	var setup: Array = await fx.spawn(Fx.PHONE, coll)
	var album: Control = setup[1]
	for page: StringName in album.page_ids():
		album.show_page(page)
		await fx.settle(2)
		var tips: Array[String] = []
		for n: Node in album.find_children("*", "Control", true, false):
			if (n as Control).tooltip_text != "":
				tips.append(String(album.get_path_to(n)))
		assert_true(tips.is_empty(), "%s: no tooltips (hover-only info): %s" % [page, tips])
	var t: Theme = album.theme
	for v: StringName in [&"AlbumHanger", &"AlbumTab"]:
		assert_eq(t.get_stylebox(&"hover", v), t.get_stylebox(&"normal", v), "%s hover == normal" % v)
	fx.finish()


# --- Helpers -------------------------------------------------------------------------------

func _check_screen(screen: Dictionary) -> void:
	var fx: RefCounted = Fx.new(tree)
	var coll: Node = fx.make_collection("layout")
	var setup: Array = await fx.spawn(screen, coll)
	var viewport: SubViewport = setup[0]
	var album: Control = setup[1]
	var k: float = Fx.points_per_px(screen)
	var safe: Rect2 = fx.safe_rect(album, viewport)
	var screen_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(Fx.EPS)
	assert_eq(album.compact, viewport.size.y < Fx.ScreenProfile.COMPACT_HEIGHT, "%s compact flag" % screen["name"])
	var min_tap: float = INF
	var min_text: float = INF
	for page: StringName in album.page_ids():
		album.show_page(page)
		await fx.settle(3)
		var label: String = "%s page %s" % [screen["name"], page]
		var needed: Vector2 = album.get_node("%SafeArea").get_combined_minimum_size()
		assert_true(needed.x <= viewport.size.x + Fx.EPS and needed.y <= viewport.size.y + Fx.EPS,
				"%s layout needs %s but screen is %s" % [label, needed, viewport.size])
		var keys: Dictionary = album.get_key_controls()
		var names: Array = keys.keys()
		for key: String in names:
			var c: Control = keys[key]
			var r: Rect2 = c.get_global_rect()
			assert_true(c.is_visible_in_tree() and r.size.x > 1.0 and r.size.y > 1.0, "%s %s not visible (%s)" % [label, key, r])
			assert_true(safe.encloses(r), "%s %s outside the safe area: %s vs %s" % [label, key, r, safe])
		for i: int in names.size():
			for j: int in range(i + 1, names.size()):
				var a: Rect2 = (keys[names[i]] as Control).get_global_rect().grow(-Fx.EPS)
				var b: Rect2 = (keys[names[j]] as Control).get_global_rect().grow(-Fx.EPS)
				assert_false(a.intersects(b), "%s %s overlaps %s" % [label, names[i], names[j]])
		# The page never scrolls sideways: its content fits the page width.
		var scroll: ScrollContainer = album.get_node("%PageScroll")
		var content: Control = album.get_page()
		assert_true(content.get_combined_minimum_size().x <= scroll.size.x + Fx.EPS,
				"%s page content %s wider than the page %s" % [label, content.get_combined_minimum_size(), scroll.size])
		var page_rect: Rect2 = scroll.get_global_rect().grow(Fx.EPS)
		# Tap targets.
		var targets: Array[Control] = []
		for n: Node in tree.get_nodes_in_group(&"tap_target"):
			if album.is_ancestor_of(n) and n is Control:
				targets.append(n)
		for n: Node in album.find_children("*", "Button", true, false):
			if not targets.has(n):
				targets.append(n)
		var checked: int = 0
		for c: Control in targets:
			if not c.is_visible_in_tree():
				continue
			checked += 1
			var r: Rect2 = c.get_global_rect()
			var side: float = minf(r.size.x, r.size.y)
			min_tap = minf(min_tap, side * k)
			assert_true(side >= Fx.MIN_TAP_PX - Fx.EPS, "%s tap target %s is %s (< 64 px)" % [label, album.get_path_to(c), r.size])
			assert_true(side * k >= Fx.MIN_TAP_PT - 0.01, "%s tap target %s = %.1f pt (< 44 pt)" % [label, album.get_path_to(c), side * k])
			if scroll.is_ancestor_of(c):
				assert_true(r.position.x >= page_rect.position.x and r.end.x <= page_rect.end.x, "%s %s spills sideways out of the page" % [label, album.get_path_to(c)])
			elif not album.get_node("%TabScroll").is_ancestor_of(c):
				assert_true(screen_rect.encloses(r), "%s tap target %s off screen" % [label, album.get_path_to(c)])
		assert_true(checked >= 9, "%s has its tabs, BACK and page targets (%d)" % [label, checked])
		# Text: >= 11 pt, never cut.
		for n: Node in album.find_children("*", "Control", true, false):
			var c: Control = n
			if not c.is_visible_in_tree() or not (c is Label or c is Button):
				continue
			if String(c.text).strip_edges().is_empty():
				continue
			var pt: float = c.get_theme_font_size(&"font_size") * k
			min_text = minf(min_text, pt)
			assert_true(pt >= Fx.MIN_BODY_PT - 0.01, "%s text '%s' (%s) is %.1f pt" % [label, c.text, album.get_path_to(c), pt])
			if c is Label and not (album.get_inspector().is_ancestor_of(c) or album.get_reveal().is_ancestor_of(c)):
				var why: String = Fx.clipped(c)
				assert_true(why.is_empty(), "%s '%s' (%s) is cut: %s" % [label, c.text, album.get_path_to(c), why])
		# Cards on set pages: 4:1, inside the page width, columns as planned.
		if content.has_method("get_hangers"):
			var xs: Dictionary = {}
			for h: Node in content.get_hangers():
				var cv: BannerCard = h.get_card_view()
				assert_true(absf(cv.size.x / cv.size.y - 4.0) < 0.05, "%s card %s is 4:1 (%s)" % [label, cv.card_id, cv.size])
				assert_true(cv.size.y * k >= Fx.MIN_TAP_PT, "%s card %s tall enough to tap" % [label, cv.card_id])
				xs[roundi(cv.get_global_rect().position.x)] = true
			assert_eq(xs.size(), mini(album.columns, content.get_hangers().size()), "%s columns" % label)
	print("     [%s] canvas %s, %.3f pt/px, card %d px, %d columns: smallest text %.1f pt, smallest tap %.1f pt" % [
			screen["name"], viewport.size, k, album.card_w, album.columns, min_text, min_tap])
	fx.finish()


func _scene_files() -> PackedStringArray:
	var out: PackedStringArray = [Fx.ALBUM_SCENE]
	for f: String in DirAccess.get_files_at("res://scenes/album"):
		if f.ends_with(".tscn"):
			out.append("res://scenes/album".path_join(f))
	return out

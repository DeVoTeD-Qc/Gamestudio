# card_sheet.gd: renders art-kit review sheets as PNG (cc14). Needs a real display (not --headless):
#   xvfb-run -a -s "-screen 0 2600x1300x24" godot --path . --rendering-driver opengl3 \
#       --resolution 2532x1170 -s res://tests/tools/card_sheet.gd -- --page=board --out=/abs/path.png
# The window is an 844x390 pt phone at @3x (2532x1170 px) and the canvas base is set the way
# scripts/ui/screen_profile.gd sets it on that phone (960x540 -> 1168x540 logical), so the sheet
# shows exactly what a phone shows. Pages: board, album, extras (icons + Triptych panoramas).
# Author: Technical Artist Agent (cc14)
extends SceneTree

const Samples: GDScript = preload("res://tests/tools/art_samples.gd")
const CARD_SCENE: PackedScene = preload("res://scenes/card/BannerCard.tscn")
const THEME_PATH: String = "res://assets/themes/wall_theme.tres"

var _page: String = "board"
var _out: String = ""
var _ui: Control


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--page="):
			_page = arg.trim_prefix("--page=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_run.call_deferred()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(960, 540)
	await process_frame
	var settings: Node = root.get_node_or_null("Settings")
	if settings != null:
		settings.set_process(false)
		if root.size_changed.is_connected(settings._apply_screen_profile):
			root.size_changed.disconnect(settings._apply_screen_profile)
	root.content_scale_size = Vector2i(960, 540)
	_ui = Control.new()
	_ui.theme = load(THEME_PATH)
	root.add_child(_ui)
	_ui.size = root.get_visible_rect().size
	var bg := ColorRect.new()
	bg.color = ArtKit.WALL
	bg.size = _ui.size
	_ui.add_child(bg)
	match _page:
		"album":
			_album()
		"extras":
			_extras()
		_:
			_board()
	for i: int in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if _out != "":
		img.save_png(_out)
	print("sheet %s %s -> %s" % [_page, img.get_size(), _out])
	quit()


func _label(text: String, pos: Vector2, variation: StringName = &"Caption") -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	l.text = text
	l.position = pos
	_ui.add_child(l)
	return l


func _card(data: Dictionary, rect: Rect2, setup: Callable = Callable()) -> BannerCard:
	var c: BannerCard = CARD_SCENE.instantiate()
	_ui.add_child(c)
	c.position = rect.position
	c.size = rect.size
	c.configure(data)
	if setup.is_valid():
		setup.call(c)
	return c


## All 20 cards at board size (256x64) with the board states: owners, Signature, Ambush back,
## highlight, capture preview, Set Link boost.
func _board() -> void:
	_label("BOARD SIZE 256x64 · 20 demo cards · teal = you (solid tab) · coral = rival (notched tab)", Vector2(24, 8))
	var cards: Array = Samples.CARDS
	for i: int in cards.size():
		var col: int = i % 4
		var row: int = i / 4
		var r := Rect2(Vector2(24 + col * 284, 44 + row * 96), Vector2(256, 64))
		var d: Dictionary = cards[i]
		_card(d, r, func(c: BannerCard) -> void:
			c.side = &"player" if (row + col) % 2 == 0 else &"rival"
			if i == 1:
				c.signature = true
			if i == 2:
				c.face_down = true
			if i == 5:
				c.highlighted = true
			if i == 8:
				c.preview_flip = true
			if i == 9:
				c.boost = Vector3i(1, 1, 1)
			if i == 13:
				c.signature = true)
	_label("2: Signature · 3: Ambush face-down · 6: selected · 9: would flip · 10: Set Link +1 · Legends glow · Showcase = chrome/gold", Vector2(24, 510))


## Album size: every frame treatment large (Clearance 1-4, Showcase chrome + gold, set complete,
## locked silhouette).
func _album() -> void:
	var by_id: Dictionary = {}
	for d: Dictionary in Samples.CARDS:
		by_id[d["id"]] = d
	var picks: Array = [
		["graveyard_shift", "ISSUE (C1) · glyph 1 hidden in art", {}],
		["neon_rain", "MERIT (C2) · SET COMPLETE edge light", {"set_complete": true}],
		["snow_blind", "DISTINCTION (C3) · brass, slow glint", {}],
		["city_never_sleeps", "LEGEND (C4) · enamel + gold inlay, glow", {"signature": true}],
		["chrome_tiger", "SHOWCASE chrome · Clearance 1 · no trait", {}],
		["long_watch", "LOCKED · album silhouette", {"locked": true}],
	]
	for i: int in picks.size():
		var col: int = i % 2
		var row: int = i / 2
		var r := Rect2(Vector2(24 + col * 572, 34 + row * 170), Vector2(536, 134))
		var p: Array = picks[i]
		var opts: Dictionary = p[2]
		_label(p[1], r.position - Vector2(0, 26))
		_card(by_id[StringName(p[0])], r, func(c: BannerCard) -> void:
			for k: String in opts:
				c.set(k, opts[k]))


func _extras() -> void:
	_label("TRIPTYCH PANORAMAS (1536x128 source, shown 1100x92)", Vector2(24, 6))
	var y: float = 34.0
	for t: StringName in CardArt.TRIPTYCHS:
		var a := CardArt.new()
		a.triptych = t
		a.material = CardArt.grain_material()
		a.position = Vector2(24, y)
		a.size = Vector2(1104, 92)
		_ui.add_child(a)
		_label(String(t).to_upper().replace("_", " "), Vector2(32, y + 64), &"Caption")
		y += 104.0
	_label("ICONS: traits · cipher glyphs · sets · utility (shown 40 px)", Vector2(24, y + 4))
	var names: Array = ArtIcons.names()
	names.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var x: float = 24.0
	y += 36.0
	for n: StringName in names:
		var tr := TextureRect.new()
		tr.texture = ArtIcons.get_icon(n, 40.0 * 2.17)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(x, y)
		tr.size = Vector2(40, 40)
		tr.modulate = ArtKit.SIGNATURE if String(n).begins_with("cipher") else ArtKit.TEXT
		_ui.add_child(tr)
		var l := _label(String(n).replace("capture_", "").replace("trait_", "").replace("set_", "").replace("_", " "), Vector2(x - 20, y + 44), &"Caption")
		l.custom_minimum_size = Vector2(80, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		x += 92.0
		if x > 1120.0:
			x = 24.0
			y += 76.0

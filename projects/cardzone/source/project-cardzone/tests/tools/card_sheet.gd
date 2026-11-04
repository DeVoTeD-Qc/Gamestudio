# card_sheet.gd: renders the cz16 art-kit contact sheets as PNG. Needs a real display (not --headless):
#   xvfb-run -a -s "-screen 0 3000x2200x24" godot --path . --rendering-driver opengl3 \
#       -s res://tests/tools/card_sheet.gd -- --page=compact --out=/abs/path.png [--grey=/abs/grey.png]
# Every page is drawn at the iPhone 844x390 landscape scale: one logical px = 0.722 pt and 2.168 physical
# px (scripts/ui/screen_profile.gd), so cards and tiles appear at the exact pixel size a phone shows;
# the window is just larger than a phone so a whole set fits on one sheet.
# Pages: compact (all sample cards + states), inspector (full cards), board (area tiles open / gassed,
#   the map, icons, silhouettes, rarity chips).
# Adapted from CallingCard tests/tools/card_sheet.gd.
# Author: Technical Artist Agent (cz16)
extends SceneTree

const Samples: GDScript = preload("res://tests/tools/art_samples.gd")
const CARD_SCENE: PackedScene = preload("res://scenes/card/CzCard.tscn")
const THEME_PATH: String = "res://assets/themes/cardzone_theme.tres"
## Physical px per logical px on the 844x390 @3x phone (2532 / 1168).
const PHONE_STRETCH: float = 2.168
const LOGICAL: Dictionary = {"compact": Vector2(1240, 860), "inspector": Vector2(1300, 940), "board": Vector2(1300, 1010)}

var _page: String = "compact"
var _out: String = ""
var _grey: String = ""
var _ui: Control


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--page="):
			_page = arg.trim_prefix("--page=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--grey="):
			_grey = arg.trim_prefix("--grey=")
	_run.call_deferred()


func _run() -> void:
	var logical: Vector2 = LOGICAL.get(_page, LOGICAL["compact"])
	var settings: Node = root.get_node_or_null("Settings")
	if settings != null and root.size_changed.is_connected(settings._apply_screen_profile):
		root.size_changed.disconnect(settings._apply_screen_profile)
	root.size = Vector2i((logical * PHONE_STRETCH).round())
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(logical)
	await process_frame
	await process_frame
	_ui = Control.new()
	_ui.theme = load(THEME_PATH)
	root.add_child(_ui)
	_ui.size = root.get_visible_rect().size
	var bg := ColorRect.new()
	bg.color = CzArtKit.ZONE_VIOLET
	bg.size = _ui.size
	_ui.add_child(bg)
	match _page:
		"inspector":
			_inspector()
		"board":
			_board()
		_:
			_compact()
	for i: int in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if _out != "":
		img.save_png(_out)
	if _grey != "":
		var g: Image = img.duplicate()
		for y: int in g.get_height():
			for x: int in g.get_width():
				var c: Color = g.get_pixel(x, y)
				var l: float = c.get_luminance()
				g.set_pixel(x, y, Color(l, l, l))
		g.save_png(_grey)
	print("sheet %s %s -> %s" % [_page, img.get_size(), _out])
	quit()


func _label(text: String, pos: Vector2, variation: StringName = &"Caption", width: float = 0.0) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	l.text = text
	l.position = pos
	if width > 0.0:
		l.custom_minimum_size = Vector2(width, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ui.add_child(l)
	return l


func _card(data: Dictionary, rect: Rect2, setup: Callable = Callable()) -> CzCard:
	var c: CzCard = CARD_SCENE.instantiate()
	_ui.add_child(c)
	c.position = rect.position
	c.size = rect.size
	c.configure(data)
	if setup.is_valid():
		setup.call(c)
	return c


## Every sample card at the phone's compact size (84x118 pt = 117x164 px), plus the card states.
func _compact() -> void:
	var sz: Vector2 = CzArtKit.compact_px(CzArtKit.PHONE_PT_PER_PX)
	_label("CZ16 · COMPACT CARDS 84x118 pt (%dx%d px at the 844x390 phone scale) · all 27 player cards + Hit + Bounty" % [sz.x, sz.y],
			Vector2(20, 6), &"Subheading")
	var cards: Array = Samples.CARDS
	var cols: int = 9
	for i: int in cards.size():
		var col: int = i % cols
		var row: int = i / cols
		var pos := Vector2(22 + col * (sz.x + 18), 52 + row * (sz.y + 40))
		var d: Dictionary = cards[i]
		_card(d, Rect2(pos, sz))
		_label(str(d["id"]), pos + Vector2(0, sz.y + 3), &"Mono", sz.x)
	# States row.
	var y: float = 52 + 3 * (sz.y + 40)
	var x: float = 22 + 2 * (sz.x + 18)
	_label("STATES →", Vector2(x - 100, y + sz.y * 0.4), &"Subheading")
	var states: Array = [
		["CZ-004", "HELD (Hold on)", func(c: CzCard) -> void: c.held = true],
		["CZ-023", "+2 ATTACHMENTS", func(c: CzCard) -> void: c.attachments = ["+1 DMG", "+1 RNG"]],
		["CZ-014", "SELECTED", func(c: CzCard) -> void: c.selected = true],
		["CZ-019", "DOWN BADGE", func(c: CzCard) -> void: c.down = true],
		["CZ-010", "CARD BACK", func(c: CzCard) -> void: c.face_down = true],
		["CZ-027", "DIMMED (can't afford)", func(c: CzCard) -> void: c.dimmed = true],
	]
	for i: int in states.size():
		var s: Array = states[i]
		var pos := Vector2(x + i * (sz.x + 18), y)
		_card(Samples.card(s[0]), Rect2(pos, sz), s[2])
		var extra: float = 34.0 if s[0] == "CZ-023" else 0.0
		_label(s[1], pos + Vector2(-8, sz.y + 4 + extra), &"Caption", sz.x + 16)


## Inspector cards (220x308 pt) for each type and rarity tier.
func _inspector() -> void:
	var sz: Vector2 = CzArtKit.full_px(CzArtKit.PHONE_PT_PER_PX)
	_label("CZ16 · INSPECTOR CARDS 220x308 pt (%dx%d px at the phone scale) · Epic / Legendary carry the rarity glint" % [sz.x, sz.y],
			Vector2(20, 4), &"Subheading")
	var ids: Array = ["CZ-014", "CZ-030", "CZ-032", "CZ-025", "CZ-033", "CZ-005", "CZ-006", "CZ-004"]
	var cols: int = 4
	var sc: float = 0.7
	var shown: Vector2 = (sz * sc).floor()
	for i: int in ids.size():
		var col: int = i % cols
		var row: int = i / cols
		var pos := Vector2(30 + col * (shown.x + 26) + (0 if row == 0 else 0), 44 + row * (shown.y + 16))
		# Inspector cards are drawn at 70 % here so eight fit; the legibility test checks them at full size.
		var c: CzCard = _card(Samples.card(ids[i]), Rect2(pos, shown))
		c.layout_mode_override = "full"
	_label("Shown at 70 % so eight fit on one sheet.", Vector2(30, 44 + 2 * (shown.y + 16) - 8), &"Caption")
	# One at true phone size on the right.
	var big: CzCard = _card(Samples.card("CZ-032"), Rect2(Vector2(30 + 4 * (shown.x + 26), 44), sz))
	big.layout_mode_override = "full"
	_label("LONGSHOT .50 at 100 % (phone size)", Vector2(30 + 4 * (shown.x + 26), 50 + sz.y), &"Caption", sz.x)


## Area tiles (open / gassed), the map, icons, silhouettes and rarity chips.
func _board() -> void:
	var k: float = 1.0 / CzArtKit.PHONE_PT_PER_PX
	_label("CZ16 · AREA TILES 120x64 pt (Core 136x76) · open / gassed · pawns: player = chevron, AI = square",
			Vector2(20, 4), &"Subheading")
	var y: float = 40.0
	var x: float = 20.0
	var areas: Array = Samples.AREAS
	for i: int in areas.size():
		var a: Dictionary = areas[i]
		for gassed: bool in [false, true]:
			var t := CzAreaTile.new()
			t.configure(a)
			t.size = (t.design_pt() * k).ceil()
			t.position = Vector2(x, y)
			t.gassed = gassed
			if i == 3:
				t.pawns = [&"player", &"ai"]
			elif i == 0 and gassed:
				t.pawns = [&"player"]
			elif i == 6:
				t.pawns = [&"ai"]
			_ui.add_child(t)
			x += t.size.x + 14.0
		x += 18.0
		if i % 2 == 1 or i == areas.size() - 1:
			x = 20.0
			y += 120.0
	# Map, right side.
	var map := CzMap.new()
	map.position = Vector2(760, 40)
	map.size = Vector2(520, 310)
	_ui.add_child(map)
	map.configure(areas)
	map.set_state({"gassed": [&"docks", &"radio_hill"], "pawns": {&"quarry": [&"player"], &"old_town": [&"ai"]}, "selected": &"quarry"})
	_label("MAP (Ridge Hollow) shown at 520x310 px · route A after Zone 4: Docks gassed; Radio Hill gassed as a second example",
			Vector2(760, 352), &"Caption", 520)
	# Rarity chips, greyscale-ready.
	var cy: float = 560.0
	_label("RARITY C / U / R / E / L · letter + lightness ladder (chip 20x22 pt) · Starter = dashed empty chip", Vector2(20, cy - 30), &"Caption")
	var chip := _Chips.new()
	chip.position = Vector2(20, cy)
	chip.size = Vector2(700, 60)
	_ui.add_child(chip)
	# Icons.
	var iy: float = 400.0
	_label("ICONS (stencil, 24 pt grid) shown at 24 pt", Vector2(760, iy), &"Caption")
	var names: Array = CzIcons.icon_names()
	var ix: float = 760.0
	iy += 28.0
	var ipx: float = 24.0 * k
	for n: StringName in names:
		var tr := TextureRect.new()
		tr.texture = CzIcons.get_icon(n, ipx * PHONE_STRETCH)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(ix, iy)
		tr.size = Vector2(ipx, ipx)
		tr.modulate = CzArtKit.GAS_LIME if n == &"gas" else CzArtKit.PAPER
		tr.tooltip_text = String(n)
		_ui.add_child(tr)
		ix += ipx + 9.0
		if ix > 1270.0:
			ix = 760.0
			iy += ipx + 10.0
	# Silhouettes.
	var sy: float = 660.0
	_label("GEAR SILHOUETTES (generic, fictional; side view facing right)", Vector2(20, sy), &"Caption")
	sy += 26.0
	var sx: float = 20.0
	for n: StringName in CzIcons.silhouette_names():
		var bgp := ColorRect.new()
		bgp.color = CzArtKit.DUNE
		bgp.position = Vector2(sx, sy)
		bgp.size = Vector2(96, 40)
		_ui.add_child(bgp)
		var tr2 := TextureRect.new()
		tr2.texture = CzIcons.silhouette(n, 96.0 * PHONE_STRETCH)
		tr2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr2.position = Vector2(sx, sy)
		tr2.size = Vector2(96, 40)
		tr2.modulate = CzArtKit.BASALT
		_ui.add_child(tr2)
		var l := _label(String(n).replace("_", " ").to_upper(), Vector2(sx - 6, sy + 41), &"Mono", 108)
		l.add_theme_font_size_override("font_size", 12)
		sx += 112.0
		if sx > 700.0:
			sx = 20.0
			sy += 70.0


class _Chips:
	extends Control

	func _draw() -> void:
		var k: float = 1.0 / CzArtKit.PHONE_PT_PER_PX
		var x: float = 0.0
		var font: Font = CzArtKit.font_display()
		for key: Variant in [&"C", &"U", &"R", &"E", &"L", &""]:
			var r := Rect2(Vector2(x, 0), Vector2(20, 22) * k)
			var rar: Dictionary = CzArtKit.rarity(key)
			if rar.is_empty():
				CzArtKit.draw_tag(self, r, 5.0 * k, Color(0, 0, 0, 0), CzArtKit.PAPER, 1.5 * k, true, 3.0 * k)
			else:
				CzArtKit.draw_tag(self, r, 5.0 * k, rar["color"], CzArtKit.INK, 1.5 * k)
				var px: int = int(ceilf(13.0 * k))
				var w: float = font.get_string_size(rar["letter"], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
				draw_string(font, Vector2(r.get_center().x - w * 0.5, r.get_center().y + px * 0.36), rar["letter"], HORIZONTAL_ALIGNMENT_LEFT, -1, px, rar["text"])
				for t: int in int(rar["ticks"]):
					draw_rect(Rect2(Vector2(x + 34 + t * 9, 14), Vector2(6, 5)), CzArtKit.PAPER)
				draw_string(font, Vector2(x + 34, 40), rar["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, CzArtKit.PAPER)
			x += 110.0

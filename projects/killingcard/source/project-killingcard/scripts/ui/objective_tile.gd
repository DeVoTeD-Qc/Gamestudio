# objective_tile.gd
# Purpose: The objective tile in the middle of a column (board-and-cards-ux.md §3.2, field-cards.md
#   model B), laid out sideways since kc-board2 (board-layout-v2.md §4.6; phone 228x52, desktop
#   304x96). kc-abc-labels (the head: "Remove them; just A / B / C" and "remove the firepower total
#   on locations ... just keep the location letter and leave more space for field card"): no range
#   word, no Firepower totals. Left: the column letter in its control mark (yours: teal circle, rival:
#   red diamond, even: grey dashed square, open: grey ring). The rest of the tile is the Field chips,
#   big, with the Field's name (the rival's on the top half, yours on the bottom half; phone about
#   170x21, desktop 222x43). With no Field the control word (YOURS / RIVAL / EVEN / OPEN) fills it.
#   The column inspector (long press / right click) still gives both sides' Firepower and the rest.
#   A Field chip is a slice of the Field's banner art with a stake glyph. Your hidden trap shows as a dashed chip (the rival never
#   sees yours, you never see theirs). A queued Field shows PLAN. A Field the enemy controls the
#   column of (field_view overrun_risk) gets a pulsing red OVERRUN tab: it is torn down at the end
#   of the round unless the column changes hands.
#   Display only: the column asks field_at() / has_point() for long-press inspection.
# Dependencies: BannerArtDB, BannerView (number metrics), hud_theme.tres colours.
# Author: Mechanics Developer Agent (kc-board)
extends Control

const INK: Color = Color(0.05, 0.06, 0.07, 1.0)

## &"player" / &"enemy" / &"contested" / &"empty"
var control: StringName = &"empty"
var letter: String = "A"
var fp_player: int = 0
var fp_enemy: int = 0
## {player: [field entry], enemy: [field entry]} (MatchState.field_view rows + queued plays).
var fields: Dictionary = {}
var compact: bool = false
var _chip_rects: Array = []   # [[Rect2, side, entry]]
var _pulse: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## lane: the snapshot lane dictionary.
func set_tile(lane: Dictionary) -> void:
	control = lane.get("control", &"empty")
	letter = String(lane.get("label", "A"))
	fp_player = int(lane.get("fp_player", 0))
	fp_enemy = int(lane.get("fp_enemy", 0))
	fields = lane.get("fields", {})
	var risk: bool = false
	for s: String in ["player", "enemy"]:
		for f: Dictionary in fields.get(s, []):
			risk = risk or bool(f.get("overrun_risk", false))
	set_process(risk)
	queue_redraw()


func _process(_delta: float) -> void:
	_pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
	queue_redraw()


## [side (&"player"/&"enemy"), field entry] of the Field chip under a local point, or [].
func field_at(local: Vector2) -> Array:
	for c: Array in _chip_rects:
		if (c[0] as Rect2).grow(2.0).has_point(local):
			return [c[1], c[2]]
	return []


func _col(name: StringName) -> Color:
	return get_theme_color(name, &"Hud")


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(r, Color("#232A31"))
	draw_rect(r, Color("#3A444D"), false, 1.0)
	var h: float = size.y
	# kc-abc-labels (the head: "remove the firepower total on locations ... just keep the location
	# letter and leave more space for field card"): left, the column letter in its control mark (yours:
	# teal circle, rival: red diamond, even: grey dashed square, open: grey ring); the rest of the tile
	# holds the Field chips, big (the rival's on the top half, yours on the bottom half). With no
	# Field here, the control word (YOURS / RIVAL / EVEN / OPEN) fills that space instead.
	var word_font: Font = get_theme_font(&"font", &"HudHeader")
	var pad: float = 6.0
	var mm: float = mark_size()
	var mark_r: float = mm * 0.5
	var c: Vector2 = Vector2(pad + mark_r, h * 0.5)
	match control:
		&"player":
			draw_circle(c, mark_r, Color("#14524D"))
			draw_arc(c, mark_r, 0, TAU, 32, _col(&"friend"), 2.5)
		&"enemy":
			var e: float = mark_r * 0.98
			var pts: PackedVector2Array = [c + Vector2(0, -e), c + Vector2(e, 0), c + Vector2(0, e), c + Vector2(-e, 0)]
			draw_colored_polygon(pts, Color("#5A1A1C"))
			pts.append(pts[0])
			draw_polyline(pts, _col(&"enemy"), 2.5)
		&"contested":
			var sq: Rect2 = Rect2(c - Vector2(mark_r, mark_r) * 0.82, Vector2(mark_r, mark_r) * 1.64)
			draw_rect(sq, Color("#2E3439"))
			BannerView._dashed_rect(self, sq, Color("#B9C2C9"), 2.0)
		_:
			draw_arc(c, mark_r - 1.0, 0, TAU, 32, Color("#59636C"), 2.0)
	var lfs: int = int(roundf(mm * 0.55))
	var lsz: Vector2 = word_font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs)
	draw_string(word_font, Vector2(c.x - lsz.x * 0.5, c.y + (word_font.get_ascent(lfs) - word_font.get_descent(lfs)) * 0.5), letter,
			HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color.WHITE)
	_chip_rects.clear()
	var area: Rect2 = field_area()
	var top_fields: Array = fields.get("enemy", [])
	var bottom_fields: Array = fields.get("player", [])
	if top_fields.is_empty() and bottom_fields.is_empty():
		# No Field: the control word, big, centred on the tile's height.
		var word: String = control_word()
		var wc: Color = {&"player": _col(&"friend"), &"enemy": _col(&"enemy")}.get(control, Color("#B9C2C9"))
		var wfs: int = control_font_size()
		while wfs > 14 and word_font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, wfs).x > area.size.x:
			wfs -= 1
		_word(word_font, wfs, word, Rect2(area.position.x, (h - wfs - 2.0) * 0.5, area.size.x, wfs + 2.0), wc)
		return
	var half: float = floorf((area.size.y - 3.0) * 0.5)
	if not top_fields.is_empty():
		_chip(Rect2(area.position.x, area.position.y, area.size.x, half), &"enemy", top_fields[0])
	if not bottom_fields.is_empty():
		_chip(Rect2(area.position.x, area.end.y - half, area.size.x, half), &"player", bottom_fields[0])


## kc-abc-labels: the letter mark's size (phone 52 px tile: 40; desktop 96: 64).
func mark_size() -> float:
	return minf(roundf(size.y * 0.76), 64.0)


## kc-abc-labels: where the Field chips go (tile-local): everything right of the letter mark.
func field_area() -> Rect2:
	var x: float = 6.0 + mark_size() + (8.0 if compact else 12.0)
	return Rect2(x, 3.0, maxf(0.0, size.x - x - 4.0), maxf(0.0, size.y - 6.0))


## kc-abc-labels: the control word's size (phone 20 px, desktop 26 px) before it steps down to fit.
func control_font_size() -> int:
	return 20 if compact else 26


## The control word (tests; shown when no Field is on the tile): YOURS / RIVAL / EVEN / OPEN.
func control_word() -> String:
	return {&"player": "YOURS", &"enemy": "RIVAL", &"contested": "EVEN"}.get(control, "OPEN")


## The Field chip rects drawn now (tests): [[Rect2, side, entry]].
func chip_rects() -> Array:
	return _chip_rects


func _word(font: Font, fs: int, text: String, rr: Rect2, c: Color) -> void:
	if text.is_empty():
		return
	var x: float = rr.position.x
	draw_string(font, Vector2(x, rr.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5), text,
			HORIZONTAL_ALIGNMENT_LEFT, rr.size.x, fs, c)


## A Field chip: art slice + stake glyph (left) + bolt (right); dashed if hidden; PLAN / OVERRUN tabs.
func _chip(rr: Rect2, side: StringName, f: Dictionary) -> void:
	_chip_rects.append([rr, side, f])
	var side_c: Color = _col(&"friend") if side == &"player" else _col(&"enemy")
	var tex: Texture2D = BannerArtDB.banner_texture(StringName(String(f.get("banner", f.get("card_id", "")))), {"type": "field"})
	var hidden: bool = bool(f.get("hidden", false))
	draw_rect(rr, Color("#1C2228"))
	if tex != null and not hidden:
		draw_texture_rect(tex, rr, false, Color(1, 1, 1, 0.9 if not f.get("pending", false) else 0.6))
	var g: float = rr.size.y
	# kc-deck-match: the Field type icon (a planted flag; ico_type_field when the kit has it), side-coloured.
	var gp: Rect2 = Rect2(rr.position, Vector2(g, g))
	draw_rect(gp, Color(INK, 0.85))
	CardLook.draw_type_icon(self, gp.grow(-g * 0.12), &"field", side_c)
	if hidden:
		BannerView._dashed_rect(self, rr, Color("#B9C2C9"), 1.5)
		_tag(Rect2(gp.end.x + 2.0, rr.position.y, rr.size.x - g - 2.0, rr.size.y), "TRAP", Color("#B9C2C9"), Color(0, 0, 0, 0))
	else:
		draw_rect(rr, side_c, false, 1.5)
		# kc-abc-labels: the Field's name on the (now bigger) chip, title style with a dark outline.
		var nm: String = String(f.get("name", "")).to_upper()
		if nm != "" and not bool(f.get("pending", false)) and not bool(f.get("overrun_risk", false)):
			var tf: Font = CardLook.TITLE_FONT
			var tfs: int = clampi(int(rr.size.y * 0.7), 12, 18)
			var room: float = rr.size.x - g - 8.0
			var txt: String = BannerView.fit_text(nm, tf, tfs, room)
			var base: Vector2 = Vector2(gp.end.x + 4.0, rr.get_center().y + (tf.get_ascent(tfs) - tf.get_descent(tfs)) * 0.5)
			draw_string_outline(tf, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, 4, INK)
			draw_string(tf, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color("#F2F5F7"))
	if bool(f.get("pending", false)):
		_tag(Rect2(gp.end.x + 2.0, rr.position.y, rr.size.x - g - 2.0, rr.size.y), "PLAN", INK, _col(&"accent"))
	elif bool(f.get("overrun_risk", false)):
		var red: Color = _col(&"enemy")
		draw_rect(rr.grow(1.0), Color(red, 0.5 + 0.5 * _pulse), false, 2.5)
		_tag(Rect2(gp.end.x + 2.0, rr.position.y, rr.size.x - g - 2.0, rr.size.y), "OVERRUN", Color.WHITE, Color(red, 0.75 + 0.25 * _pulse))


func _tag(rr: Rect2, text: String, fg: Color, bg: Color) -> void:
	var font: Font = get_theme_font(&"font", &"HudHeader")
	var fs: int = clampi(int(rr.size.y) - 1, 12, 16)
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	while fs > 12 and sz.x + 6.0 > rr.size.x:
		fs -= 1
		sz = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var box: Rect2 = Rect2(rr.get_center() - Vector2(sz.x * 0.5 + 3.0, rr.size.y * 0.5), Vector2(sz.x + 6.0, rr.size.y))
	if bg.a > 0.0:
		draw_rect(box, bg)
	draw_string(font, Vector2(box.position.x + 3.0, box.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)

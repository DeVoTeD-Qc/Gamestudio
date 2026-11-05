# objective_tile.gd
# Purpose: The objective tile in the middle of a column (board-and-cards-ux.md §3.2, field-cards.md
#   model B). Left: rival column Firepower (top) and yours (bottom). Centre: the column letter in a
#   control mark (yours: teal circle, rival: red diamond, contested: grey dashed square, open: grey
#   ring). Right: the range word (top half) and the control word (bottom half).
#   Fields sit on their owner's half of the tile: a 4:1 chip of the Field's banner art with a stake
#   glyph, replacing that half's word. Your hidden trap shows as a dashed chip (the rival never
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
var range_word: String = ""
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
	range_word = String(lane.get("range", ""))
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
	var m: Dictionary = BannerView.metrics(h * 0.82)
	var fs: int = maxi(16, int(m["number"]))
	var font: Font = get_theme_font(&"font", &"HudNumber")
	var word_font: Font = get_theme_font(&"font", &"HudHeader")
	# Column Firepower: rival top-left, yours bottom-left (crosshair ring + number).
	var pad: float = 6.0 if compact else 10.0
	_fp_line(font, fs, Vector2(pad, h * 0.25), fp_enemy, _col(&"enemy"))
	_fp_line(font, fs, Vector2(pad, h * 0.75), fp_player, _col(&"friend"))
	# Control mark with the letter.
	var mark_r: float = h * 0.36
	var cx: float = size.x * (0.36 if compact else 0.4)
	var c: Vector2 = Vector2(cx, h * 0.5)
	match control:
		&"player":
			draw_circle(c, mark_r, Color("#14524D"))
			draw_arc(c, mark_r, 0, TAU, 32, _col(&"friend"), 2.5)
		&"enemy":
			var pts: PackedVector2Array = [c + Vector2(0, -mark_r * 1.12), c + Vector2(mark_r * 1.12, 0), c + Vector2(0, mark_r * 1.12), c + Vector2(-mark_r * 1.12, 0)]
			draw_colored_polygon(pts, Color("#5A1A1C"))
			pts.append(pts[0])
			draw_polyline(pts, _col(&"enemy"), 2.5)
		&"contested":
			var sq: Rect2 = Rect2(c - Vector2(mark_r, mark_r) * 0.9, Vector2(mark_r, mark_r) * 1.8)
			draw_rect(sq, Color("#2E3439"))
			BannerView._dashed_rect(self, sq, Color("#B9C2C9"), 2.0)
		_:
			draw_arc(c, mark_r, 0, TAU, 32, Color("#59636C"), 2.0)
	var lfs: int = int(fs * 1.35)
	var lsz: Vector2 = word_font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs)
	draw_string(word_font, Vector2(c.x - lsz.x * 0.5, c.y + (word_font.get_ascent(lfs) - word_font.get_descent(lfs)) * 0.5), letter,
			HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color.WHITE)
	# Right region: Field chips on their owner's half, else range (top) / control word (bottom).
	_chip_rects.clear()
	var rx: float = c.x + mark_r * 1.25 + 4.0
	var rw: float = size.x - rx - 4.0
	var half: float = h * 0.5
	var chip_h: float = minf(half - 4.0, rw / 4.0)
	var top_fields: Array = fields.get("enemy", [])
	var bottom_fields: Array = fields.get("player", [])
	var wfs: int = 16 if compact else 18
	if top_fields.is_empty():
		_word(word_font, wfs, range_word, Rect2(rx, 0, rw, half), Color("#9AA5AE"))
	else:
		_chip(Rect2(rx, half - chip_h - 2.0, rw, chip_h), &"enemy", top_fields[0])
	if bottom_fields.is_empty():
		var word: String = {&"player": "YOURS", &"enemy": "RIVAL", &"contested": "CONTESTED"}.get(control, "OPEN")
		var wc: Color = {&"player": _col(&"friend"), &"enemy": _col(&"enemy")}.get(control, Color("#B9C2C9"))
		_word(word_font, wfs, word, Rect2(rx, half, rw, half), wc)
	else:
		_chip(Rect2(rx, half + 2.0, rw, chip_h), &"player", bottom_fields[0])


func _fp_line(font: Font, fs: int, at: Vector2, value: int, c: Color) -> void:
	var rad: float = fs * 0.32
	var ctr: Vector2 = at + Vector2(rad, 0)
	draw_arc(ctr, rad, 0, TAU, 16, c, 2.0)
	draw_circle(ctr, 1.5, c)
	draw_string(font, Vector2(ctr.x + rad + 4.0, at.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5), str(value),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _word(font: Font, fs: int, text: String, rr: Rect2, c: Color) -> void:
	if text.is_empty():
		return
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var x: float = rr.position.x + maxf(0.0, (rr.size.x - sz.x) * 0.5)
	draw_string(font, Vector2(x, rr.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5), text,
			HORIZONTAL_ALIGNMENT_LEFT, rr.size.x, fs, c)


## A Field chip: art slice + stake glyph (left) + bolt (right); dashed if hidden; PLAN / OVERRUN tabs.
func _chip(rr: Rect2, side: StringName, f: Dictionary) -> void:
	_chip_rects.append([rr, side, f])
	var side_c: Color = _col(&"friend") if side == &"player" else _col(&"enemy")
	var tex: Texture2D = BannerArtDB.banner_texture(StringName(String(f.get("card_id", ""))), {"type": "field"})
	var hidden: bool = bool(f.get("hidden", false))
	draw_rect(rr, Color("#1C2228"))
	if tex != null and not hidden:
		draw_texture_rect(tex, rr, false, Color(1, 1, 1, 0.9 if not f.get("pending", false) else 0.6))
	var g: float = rr.size.y
	# Stake / pylon glyph of our own (never a flag): a post with two cross bars.
	var gp: Rect2 = Rect2(rr.position, Vector2(g, g))
	draw_rect(gp, Color(INK, 0.85))
	var x: float = gp.get_center().x
	draw_line(Vector2(x, gp.position.y + g * 0.15), Vector2(x, gp.end.y - g * 0.12), side_c, 2.0)
	draw_line(Vector2(x - g * 0.28, gp.position.y + g * 0.35), Vector2(x + g * 0.28, gp.position.y + g * 0.35), side_c, 2.0)
	draw_line(Vector2(x - g * 0.2, gp.position.y + g * 0.6), Vector2(x + g * 0.2, gp.position.y + g * 0.6), side_c, 2.0)
	if hidden:
		BannerView._dashed_rect(self, rr, Color("#B9C2C9"), 1.5)
		_tag(Rect2(gp.end.x + 2.0, rr.position.y, rr.size.x - g - 2.0, rr.size.y), "TRAP", Color("#B9C2C9"), Color(0, 0, 0, 0))
	else:
		draw_rect(rr, side_c, false, 1.5)
	if bool(f.get("pending", false)):
		_tag(Rect2(gp.end.x + 2.0, rr.position.y, rr.size.x - g - 2.0, rr.size.y), "PLAN", INK, _col(&"accent"))
	elif bool(f.get("overrun_risk", false)):
		var red: Color = _col(&"enemy")
		draw_rect(rr.grow(1.0), Color(red, 0.5 + 0.5 * _pulse), false, 2.5)
		_tag(Rect2(gp.end.x + 2.0, rr.position.y, rr.size.x - g - 2.0, rr.size.y), "OVERRUN", Color.WHITE, Color(red, 0.75 + 0.25 * _pulse))


func _tag(rr: Rect2, text: String, fg: Color, bg: Color) -> void:
	var font: Font = get_theme_font(&"font", &"HudHeader")
	var fs: int = clampi(int(rr.size.y) - 2, 11, 16)
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var box: Rect2 = Rect2(rr.get_center() - Vector2(sz.x * 0.5 + 3.0, rr.size.y * 0.5), Vector2(sz.x + 6.0, rr.size.y))
	if bg.a > 0.0:
		draw_rect(box, bg)
	draw_string(font, Vector2(box.position.x + 3.0, box.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)

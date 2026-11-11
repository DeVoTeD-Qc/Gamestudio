# dd_marks.gd
# Purpose: dd-ux-v4: small vector marks drawn with Control._draw (no image assets), shared by the
#   street, the gun tiles, the Glossary and the Codex:
#   - NumBadge (dd-polish5): THE number badge on every card number, one circle shape. The role
#     picks the colours only: zombie (blood fill, tier-coloured ring: its attack AND toughness),
#     weapon (yellow fill: the hit of a gun / melee weapon / Bare Hands), item (ink fill, ring in the
#     kind's accent: heal, cover...). StrengthMark / HitBurst are the zombie / weapon presets.
#   - Padlock: closed / open padlock icon for the room price plate.
#   - Socket: an empty kill socket (dashed) or the next one (gold dashed + what it accepts).
#   - WaveNumeral: the big blood-red wave number on the wave door (slams in on a new wave).
#   - RuleChip (dd-ui6): a weapon rule icon (the same SVG glyph as the gun row, Glossary, Codex)
#     with a verdict: yes = full colour + a green tick, no = dimmed + a red strike, or plain.
#   dd-art2-import: NumBadge and Socket draw the painted UI kit (dd_skin.gd) when its image exists.
# Dependencies: DDUi. Loaded with preload() (no class_name, so no class-cache rescan).
# Author: UI/UX Agent (dd-ux-v4)
extends RefCounted

const Kit = preload("res://scripts/ui/dd_skin.gd")
const INK: Color = Color("151214")
const BONE: Color = Color("ece6d6")
const BURST_YELLOW: Color = Color("f2c14e")
const BLOOD: Color = Color("c8322a")
## Tier colours (Shambler, Lurcher, Bruiser, Hulk): bone, amber, orange, red.
const TIER_COLORS: Array[Color] = [Color("bdb5a0"), Color("d99a3c"), Color("e8793a"), Color("e2574c")]
const TIER_NAMES: Array[String] = ["Shambler", "Lurcher", "Bruiser", "Hulk"]
## dd-polish5: every card number uses the same circle badge (NumBadge); the fang / burst shapes are gone.
const BADGE_SHAPE: String = "circle"
const STRENGTH_VARIANT: String = BADGE_SHAPE
const ZOMBIE_FILL: Color = Color("5c1b19")
const WEAPON_FILL: Color = Color("f2c14e")


static func tier_of(n: int) -> int:
	return Mark.tier_of(n)


# ================================================================ shared base
class Mark:
	extends Control

	static func tier_of(n: int) -> int:
		if n <= 3:
			return 0
		if n <= 6:
			return 1
		if n <= 9:
			return 2
		return 3


	static func _font() -> Font:
		return ThemeDB.fallback_font


	## Draws text centred on c with an ink outline.
	static func draw_num(ci: CanvasItem, text: String, c: Vector2, fs: int, col: Color, outline: Color = Color(0, 0, 0, 0), ow: int = 0) -> void:
		var f: Font = _font()
		var sz: Vector2 = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos: Vector2 = Vector2(c.x - sz.x * 0.5, c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
		if ow > 0:
			ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ow, outline)
		ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


	static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
		var out: PackedVector2Array = pts.duplicate()
		out.append(pts[0])
		return out


# ================================================================ the number badge
## dd-polish5 (head: "all numbers on all cards had that simple circle"): ONE badge for every card
## number. A circle (a pill when the text is wider than 2 digits), an ink hairline outside, a
## coloured ring, a fill, the number centred in a Label. The role only picks the colours:
##   "zombie": blood-red fill, ring in the tier colour (Shambler bone, Lurcher amber, Bruiser
##             orange, Hulk red), bone number. The number is its attack AND its toughness.
##   "weapon": yellow fill, ink ring, ink number (guns, melee weapons, Bare Hands): the hit.
##   "item":   ink fill, ring in the card kind's accent (medkit green, cover gold...), bone number.
## Feedback / tests read `value` and `num_label`.
class NumBadge:
	extends Mark
	var value: int = 0
	var role: String = "item"
	var ring: Color = BONE
	var fill: Color = INK
	var text_color: Color = BONE
	var text: String = ""
	var num_label: Label = null
	## kept for older callers / tests: the badge shape in use
	var variant: String = BADGE_SHAPE

	func _init(v: int = 0, r: String = "item", ring_col: Color = BONE, txt: String = "") -> void:
		value = v
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		text = txt if txt != "" else str(v)
		set_role(r, ring_col)
		num_label = Label.new()
		num_label.name = "Num"
		num_label.text = text
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		num_label.add_theme_color_override("font_color", text_color)
		add_child(num_label)
		resized.connect(fit)

	## A badge sized before it entered the tree measured its label without the theme: refit.
	func _notification(what: int) -> void:
		if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_THEME_CHANGED:
			fit.call_deferred()

	func set_role(r: String, ring_col: Color = BONE) -> void:
		role = r
		var c: Dictionary = colors(r, value, ring_col)
		ring = c["ring"]
		fill = c["fill"]
		text_color = c["text"]
		if num_label != null:
			num_label.add_theme_color_override("font_color", text_color)
		queue_redraw()

	## {ring, fill, text} for a role (see the class comment).
	static func colors(r: String, v: int, ring_col: Color = BONE) -> Dictionary:
		match r:
			"zombie":
				return {"ring": TIER_COLORS[Mark.tier_of(v)], "fill": ZOMBIE_FILL, "text": BONE}
			"weapon":
				return {"ring": INK, "fill": WEAPON_FILL, "text": INK}
		return {"ring": ring_col, "fill": INK, "text": BONE}

	## The number's font size for a badge of height d (the same rule everywhere).
	static func font_for(d: float, txt: String) -> int:
		return maxi(8, int(d * (0.58 if txt.length() <= 2 else 0.42)))

	func fit() -> void:
		var d: float = minf(size.x, size.y)
		if d <= 2.0 or num_label == null:
			return
		num_label.add_theme_font_size_override("font_size", font_for(d, text))
		# centred by hand (not anchored): a label taller than a small badge would grow past it
		var ls: Vector2 = num_label.get_combined_minimum_size()
		num_label.size = Vector2(maxf(ls.x, size.x), ls.y)
		num_label.position = (size - num_label.size) * 0.5
		queue_redraw()

	## The width a badge of height d needs for its text (a circle up to 2 digits, then a pill).
	func width_for(d: float) -> float:
		var f: Font = num_label.get_theme_font("font") if num_label != null else _font()
		var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_for(d, text)).x
		return maxf(d, tw + d * 0.45)

	## dd-art2-import: the painted badge for this role (null: draw the vector circle).
	func painted_file(pill: bool) -> String:
		var key: String = "neutral"
		match role:
			"weapon":
				key = "hit"
			"zombie":
				key = "zombie" if pill else "zombie_t%d" % (Mark.tier_of(value) + 1)
			_:
				if not pill:
					if ring.is_equal_approx(Color("6fd08a")) or (ring.g > ring.r * 1.15 and ring.g > ring.b * 1.2):
						key = "heal"
					elif ring.r > 0.8 and ring.g > 0.6 and ring.b < 0.45:
						key = "cover"
		return ("dd_pill_" if pill else "dd_badge_") + key

	func _draw() -> void:
		var h: float = size.y
		var w: float = size.x
		var d: float = minf(w, h)
		if d <= 4.0:
			return
		var pill: bool = w > h + 0.5
		var file: String = painted_file(pill)
		if pill:
			var st: StyleBox = Kit.box(file, 0.0)
			if st != null:
				draw_style_box(st, Rect2(Vector2.ZERO, size))
				return
		else:
			var t: Texture2D = Kit.tex(file)
			if t != null:
				draw_texture_rect(t, Rect2((size - Vector2(d, d)) * 0.5, Vector2(d, d)), false)
				return
		var rw: float = clampf(d * 0.075, 2.0, 5.0)
		var hair: float = maxf(1.0, d * 0.03)
		_shape(Vector2(w, h), 0.0, Color(INK, 0.9))
		_shape(Vector2(w, h), hair, ring)
		_shape(Vector2(w, h), hair + rw, fill)

	## A circle (w == h) or a pill, inset by `inset` px.
	func _shape(sz: Vector2, inset: float, col: Color) -> void:
		var r: float = minf(sz.x, sz.y) * 0.5 - inset
		if r <= 0.0:
			return
		var c: Vector2 = sz * 0.5
		if sz.x <= sz.y + 0.5:
			draw_circle(c, r, col, true, -1.0, true)
			return
		var half: float = sz.x * 0.5 - sz.y * 0.5
		draw_rect(Rect2(c.x - half, c.y - r, half * 2.0, r * 2.0), col)
		draw_circle(c - Vector2(half, 0), r, col, true, -1.0, true)
		draw_circle(c + Vector2(half, 0), r, col, true, -1.0, true)


## A zombie's strength badge (its attack and its toughness).
class StrengthMark:
	extends NumBadge

	func _init(v: int = 1, _unused: String = "") -> void:
		super(v, "zombie")


## A weapon's hit badge (guns, melee weapons, Bare Hands).
class HitBurst:
	extends NumBadge

	func _init(v: int = 2) -> void:
		super(v, "weapon")


# ================================================================ padlock
class Padlock:
	extends Mark
	var open: bool = false
	var color: Color = BONE

	func _init(is_open: bool = false, col: Color = BONE) -> void:
		open = is_open
		color = col
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var h: float = size.y
		var w: float = minf(size.x, h * 0.9)
		var x: float = (size.x - w) * 0.5
		var body: Rect2 = Rect2(x, h * 0.48, w, h * 0.52)
		var sw: float = maxf(2.0, w * 0.16)
		var sc: Vector2 = Vector2(x + w * 0.5, h * 0.45)
		var sr: float = w * 0.3
		if open:
			# the shackle lifted out of the body, its right leg free
			var up: float = h * 0.16
			draw_arc(sc - Vector2(0, up), sr, PI, TAU, 16, color, sw, true)
			draw_line(sc + Vector2(-sr, -up), sc + Vector2(-sr, h * 0.05), color, sw)
			draw_line(sc + Vector2(sr, -up), sc + Vector2(sr, -up + h * 0.08), color, sw)
		else:
			draw_arc(sc, sr, PI, TAU, 16, color, sw, true)
			draw_line(sc + Vector2(-sr, 0), sc + Vector2(-sr, h * 0.05), color, sw)
			draw_line(sc + Vector2(sr, 0), sc + Vector2(sr, h * 0.05), color, sw)
		draw_rect(body, color)
		draw_circle(body.get_center() - Vector2(0, h * 0.04), maxf(1.5, w * 0.1), INK)


# ================================================================ kill socket (empty / next)
class Socket:
	extends Mark
	var next_text: String = ""
	var is_next: bool = false

	func _init(nxt: bool = false, txt: String = "") -> void:
		is_next = nxt
		next_text = txt
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var st: StyleBox = Kit.box("dd_socket_next" if is_next else "dd_socket_empty", 0.0)
		if st != null:
			draw_style_box(st, Rect2(Vector2.ZERO, size))
			if is_next:
				# the painted dashes are thin at 56 px: a soft gold wash says "next" from across the room
				var inset: float = minf(size.x, size.y) * 0.16
				draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0), Color(BURST_YELLOW, 0.14))
				draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0), Color(BURST_YELLOW, 0.55), false, 1.5)
			if is_next and next_text != "":
				_draw_next_text()
			return
		var r: Rect2 = Rect2(Vector2(1.5, 1.5), size - Vector2(3, 3))
		draw_rect(r, Color(0, 0, 0, 0.28))
		var col: Color = BURST_YELLOW if is_next else Color("4f5b62")
		var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for k: int in 4:
			draw_dashed_line(corners[k], corners[(k + 1) % 4], col, 2.0, 5.0)
		if is_next and next_text != "":
			_draw_next_text()

	func _draw_next_text() -> void:
		var fs: int = int(clampf(minf(size.x * 0.34, size.y * 0.3), 11.0, 24.0))
		while fs > 9 and _font().get_string_size(next_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 6.0:
			fs -= 1
		draw_num(self, next_text, size * 0.5, fs, BURST_YELLOW, Color(INK, 0.9), 3)


# ================================================================ rule chip (dd-ui6)
## The active gun's rule icon on a street card, with the verdict for that card. `state`: 1 = the
## gun can take it (full colour, green tick disc bottom-right), 0 = it can't (icon dimmed to 40%,
## red strike corner to corner), -1 = plain icon (a gun card's own rule). Tick vs strike is a shape
## difference, so the verdict reads without colour too.
class RuleChip:
	extends Mark
	const YES: Color = Color("4caf6a")
	const NO: Color = Color("e2574c")
	var tex: Texture2D = null
	var state: int = -1

	func _init(t: Texture2D = null, st: int = -1) -> void:
		tex = t
		state = st
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var d: float = minf(size.x, size.y)
		if d <= 4.0:
			return
		var r: Rect2 = Rect2((size - Vector2(d, d)) * 0.5, Vector2(d, d))
		if tex != null:
			draw_texture_rect(tex, r, false, Color(0.4, 0.4, 0.4, 0.9) if state == 0 else Color.WHITE)
		else:
			draw_circle(r.get_center(), d * 0.5, INK, true, -1.0, true)
		var lw: float = maxf(2.0, d * 0.1)
		if state == 0:
			var a: Vector2 = r.position + Vector2(d * 0.2, d * 0.2)
			var b: Vector2 = r.end - Vector2(d * 0.2, d * 0.2)
			draw_line(a, b, INK, lw + 3.0, true)
			draw_line(a, b, NO, lw, true)
		elif state == 1:
			var tr: float = d * 0.22
			var c: Vector2 = r.end - Vector2(tr, tr) + Vector2(1, 1)
			draw_circle(c, tr + 1.5, INK, true, -1.0, true)
			draw_circle(c, tr, YES, true, -1.0, true)
			var pts: PackedVector2Array = [c + Vector2(-tr * 0.5, 0), c + Vector2(-tr * 0.12, tr * 0.4), c + Vector2(tr * 0.55, -tr * 0.45)]
			draw_polyline(pts, INK, maxf(1.5, tr * 0.32), true)


# ================================================================ the big wave numeral
class WaveNumeral:
	extends Mark
	var text: String = "1"
	var font_px: int = 64

	func _init(t: String = "1") -> void:
		text = t
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var fs: int = int(minf(size.y * 0.95, size.x * (0.9 if text.length() <= 1 else 0.55)))
		if fs < 8:
			return
		font_px = fs
		draw_num(self, text, size * 0.5 + Vector2(0, 2), fs, Color("e8463b"), Color(0, 0, 0, 0.95), maxi(4, fs / 9))

# mastery_bands.gd
# Purpose: kc-ui-bands. The level bands (Operator mastery tiers and card copy levels) as ORIGINAL finishes
#   drawn in code, no blob camo (the head's answer B1 (a)): Base (the kit's band_base when shipped, else a
#   plain olive drab with a fine twill), Gold Leaf (beaten gold-leaf flakes laid over the Base), Machined
#   (brushed steel with a bevel), Prism (cut crystal facets) and Starfield (a deep night sky with stars).
#   The old ids (gilded / forged / priceless / interstellar, the names of a shooter franchise's mastery
#   camos) are retired: migrate_id() / migrate() turn them into the new ones wherever a saved profile,
#   a run save or a view still carries them.
#   Every primitive is a polygon clipped to the target shape (a rect, or any convex polygon such as the
#   Operator badge's disc), so the bands draw the same on a strip, a swatch or a round badge.
# Usage: MasteryBands.draw(ci, rect, &"prism")
#        MasteryBands.draw(ci, rect, id, MasteryBands.disc(center, radius))
#        MasteryBands.info(&"machined")   # {title, type, text, status} for the inspector
# Dependencies: ui_kit.gd (band_base, optional)
# Author: UI/UX Agent (kc-ui-bands)
class_name MasteryBands
extends RefCounted

const BASE: StringName = &"base"
const GOLD_LEAF: StringName = &"gold_leaf"
const MACHINED: StringName = &"machined"
const PRISM: StringName = &"prism"
const STARFIELD: StringName = &"starfield"
const IDS: Array[StringName] = [BASE, GOLD_LEAF, MACHINED, PRISM, STARFIELD]
const NAMES: Dictionary = {
	BASE: "Base", GOLD_LEAF: "Gold Leaf", MACHINED: "Machined", PRISM: "Prism", STARFIELD: "Starfield",
}
## Retired ids (and the old "gold" swatch) -> the new ones. Saved data is migrated through this.
const LEGACY: Dictionary = {
	&"gilded": GOLD_LEAF, &"forged": MACHINED, &"priceless": PRISM, &"interstellar": STARFIELD, &"gold": GOLD_LEAF,
}
## Operator mastery tiers 1-4: their names and the band each one shows. Tier 1 shows the Base band
## (head, kc-polish B3: Base for both sides until the mastery grind exists).
const TIER_NAMES: PackedStringArray = ["Gold Leaf", "Machined", "Prism", "Starfield"]
const TIER_BANDS: Array[StringName] = [BASE, MACHINED, PRISM, STARFIELD]
## Card copy levels -> band (Recruit: none).
const COPY_BANDS: Dictionary = {&"trained": GOLD_LEAF, &"veteran": MACHINED, &"elite": PRISM}
## How each band is earned, in plain words (the inspector line).
const EARN: Dictionary = {
	BASE: "Every Operator starts with the Base band.",
	GOLD_LEAF: "A Trained copy of a card wears Gold Leaf. Operators: mastery tier 1 (it shows the Base band until the mastery grind arrives).",
	MACHINED: "A Veteran copy of a card wears Machined steel. Operators: mastery tier 2.",
	PRISM: "An Elite copy of a card wears Prism. Operators: mastery tier 3.",
	STARFIELD: "Operators only: mastery tier 4, the top tier.",
}
## Keys whose string values hold a band id in saved dictionaries.
const BAND_KEYS: PackedStringArray = ["band", "camo", "mastery_band", "level_band"]

const OLIVE: Color = Color("#4B5A3A")
const OLIVE_DARK: Color = Color("#3A4630")


## The current id for a band id (an old id becomes its new one; unknown ids pass through).
static func migrate_id(id: Variant) -> StringName:
	var s: StringName = StringName(String(id).to_lower()) if id != null else &""
	return LEGACY.get(s, StringName(String(id)) if id != null else &"")


## Rewrites old band ids in a saved Dictionary / Array (recursively, only under BAND_KEYS), in place.
## Returns how many values changed.
static func migrate(data: Variant) -> int:
	var n: int = 0
	if data is Dictionary:
		var d: Dictionary = data
		for k: Variant in d.keys():
			var v: Variant = d[k]
			if typeof(k) in [TYPE_STRING, TYPE_STRING_NAME] and String(k) in BAND_KEYS and typeof(v) in [TYPE_STRING, TYPE_STRING_NAME]:
				var nv: StringName = migrate_id(v)
				if String(nv) != String(v):
					d[k] = String(nv) if typeof(v) == TYPE_STRING else nv
					n += 1
			elif v is Dictionary or v is Array:
				n += migrate(v)
	elif data is Array:
		for v: Variant in data:
			if v is Dictionary or v is Array:
				n += migrate(v)
	return n


static func display_name(id: StringName) -> String:
	return String(NAMES.get(migrate_id(id), String(id).capitalize()))


## Inspector info for a band: name and how it is earned.
static func info(id: StringName) -> Dictionary:
	var b: StringName = migrate_id(id)
	return {"title": "%s band" % display_name(b), "type": "level band", "text": String(EARN.get(b, "")),
			"status": "An original finish drawn by the game.", "band": b}


## Mastery tier (1-4) -> band id.
static func band_for_tier(tier: int) -> StringName:
	return TIER_BANDS[clampi(tier, 1, TIER_BANDS.size()) - 1]


static func tier_name(tier: int) -> String:
	return TIER_NAMES[clampi(tier, 1, TIER_NAMES.size()) - 1]


## A convex polygon approximating a disc (for round badges).
static func disc(center: Vector2, radius: float, steps: int = 28) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for i: int in steps:
		out.append(center + Vector2.from_angle(TAU * i / steps) * radius)
	return out


static func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## Draws the band `id` over rect, clipped to `clip` (default: the rect). Returns false for an unknown id.
static func draw(ci: CanvasItem, rect: Rect2, id: StringName, clip: PackedVector2Array = PackedVector2Array(), alpha: float = 1.0) -> bool:
	var b: StringName = migrate_id(id)
	if ci == null or not b in IDS or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	var cl: PackedVector2Array = clip if clip.size() >= 3 else _rect_poly(rect)
	var p: _Painter = _Painter.new(ci, cl, alpha)
	match b:
		BASE:
			_base(p, rect)
		GOLD_LEAF:
			_base(p, rect)
			_gold_leaf(p, rect)
		MACHINED:
			_machined(p, rect)
		PRISM:
			_prism(p, rect)
		STARFIELD:
			_starfield(p, rect)
	return true


## Clipped polygon painter.
class _Painter:
	var ci: CanvasItem
	var clip: PackedVector2Array
	var alpha: float

	func _init(c: CanvasItem, cl: PackedVector2Array, a: float) -> void:
		ci = c
		clip = cl
		alpha = a

	func poly(pts: PackedVector2Array, col: Color) -> void:
		for part: PackedVector2Array in Geometry2D.intersect_polygons(pts, clip):
			if part.size() >= 3:
				ci.draw_colored_polygon(part, Color(col, col.a * alpha))

	func rect(r: Rect2, col: Color) -> void:
		poly(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), col)

	func line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
		var n: Vector2 = (b - a).orthogonal().normalized() * w * 0.5
		poly(PackedVector2Array([a + n, b + n, b - n, a - n]), col)


## Base: the kit's band_base (a seamless strip for a band, the swatch for a square), else olive drab
## with a fine diagonal twill. The kit image only fills plain rects (it can't be clipped to a disc).
static func _base(p: _Painter, r: Rect2) -> void:
	var square_clip: bool = p.clip.size() == 4
	if square_clip and p.alpha >= 1.0:
		var strip: bool = r.size.x >= r.size.y * 3.0
		var id: StringName = &"band_base_strip" if strip else &"band_base"
		var tex: Texture2D = UiKit.piece(id)
		if tex != null:
			UiKit.draw_tiled(p.ci, id, r, Color.WHITE, (r.size.y / tex.get_size().y) if strip else maxf(r.size.x, r.size.y) / tex.get_size().x)
			return
	p.rect(r, OLIVE)
	var step: float = maxf(3.0, r.size.y * 0.12)
	var x: float = r.position.x - r.size.y
	while x < r.end.x:
		p.line(Vector2(x, r.end.y), Vector2(x + r.size.y, r.position.y), OLIVE_DARK, maxf(1.0, step * 0.35))
		x += step


## Gold Leaf: square flakes of beaten gold, each a slightly turned quad of its own shade, laid edge to
## edge over the Base with hairline gaps (the base shows through as the leaf's seams).
static func _gold_leaf(p: _Painter, r: Rect2) -> void:
	var golds: Array[Color] = [Color("#C9A227"), Color("#E3BE4A"), Color("#B48E1E"), Color("#F3D36B"), Color("#D6AE34")]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7331
	var cell: float = maxf(6.0, minf(r.size.x, r.size.y) * 0.42)
	var y: float = r.position.y - cell * 0.25
	while y < r.end.y:
		var x: float = r.position.x - cell * 0.25
		while x < r.end.x:
			var c: Vector2 = Vector2(x + cell * 0.5, y + cell * 0.5)
			var ang: float = rng.randf_range(-0.12, 0.12)
			var h: float = cell * 0.5 * rng.randf_range(0.93, 1.0)
			var q: PackedVector2Array = []
			for k: int in 4:
				q.append(c + Vector2(-h if k in [0, 3] else h, -h if k < 2 else h).rotated(ang))
			p.poly(q, golds[rng.randi() % golds.size()])
			# A soft highlight on the top edge of each flake.
			p.line(q[0], q[1], Color("#FFF1B8", 0.35), maxf(1.0, cell * 0.06))
			x += cell * 0.97
		y += cell * 0.97


## Machined: brushed steel (fine horizontal grain), a bright bevel on top and a dark one at the bottom.
static func _machined(p: _Painter, r: Rect2) -> void:
	p.rect(r, Color("#8E979F"))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	var y: float = r.position.y
	while y < r.end.y:
		var light: bool = rng.randf() < 0.5
		p.rect(Rect2(r.position.x, y, r.size.x, 1.0), Color("#B8C0C7" if light else "#727B83", rng.randf_range(0.25, 0.6)))
		y += rng.randf_range(1.0, 2.2)
	var bevel: float = maxf(1.5, r.size.y * 0.14)
	p.rect(Rect2(r.position, Vector2(r.size.x, bevel)), Color("#E4E9ED", 0.55))
	p.rect(Rect2(r.position.x, r.end.y - bevel, r.size.x, bevel), Color("#3E454B", 0.55))
	# Two tool marks: thin darker lines a third of the way in.
	for f: float in [0.33, 0.66]:
		var x: float = r.position.x + r.size.x * f
		p.line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color("#5D656C", 0.5), 1.0)


## Prism: cut crystal, a grid of triangular facets in cool blues and violets with light edges.
static func _prism(p: _Painter, r: Rect2) -> void:
	var cols: Array[Color] = [Color("#3E8EDE"), Color("#1B3F78"), Color("#9FE3FF"), Color("#6C7BE8"), Color("#2B5FB0"), Color("#C6EEFF")]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9001
	var cell: float = maxf(6.0, minf(r.size.x, r.size.y) * 0.5)
	var y: float = r.position.y
	var row: int = 0
	while y < r.end.y:
		var off: float = cell * 0.5 if row % 2 == 1 else 0.0
		var x: float = r.position.x - cell + off
		while x < r.end.x:
			var a: Vector2 = Vector2(x, y + cell)
			var b: Vector2 = Vector2(x + cell * 0.5, y)
			var c: Vector2 = Vector2(x + cell, y + cell)
			var d: Vector2 = Vector2(x + cell * 1.5, y)
			for tri: PackedVector2Array in [PackedVector2Array([a, b, c]), PackedVector2Array([b, d, c])]:
				p.poly(tri, cols[rng.randi() % cols.size()])
				p.line(tri[0], tri[1], Color("#E6FAFF", 0.45), 1.0)
			x += cell
		y += cell
		row += 1


## Starfield: a deep night sky (indigo to violet), small stars of mixed brightness and a few bright
## four-point glints.
static func _starfield(p: _Painter, r: Rect2) -> void:
	var bands: int = 6
	for i: int in bands:
		var t: float = float(i) / (bands - 1)
		p.rect(Rect2(r.position.x, r.position.y + r.size.y * i / bands, r.size.x, r.size.y / bands + 0.5),
				Color("#120A2E").lerp(Color("#3A1C6E"), t))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 314159
	var count: int = clampi(int(r.size.x * r.size.y / 40.0), 6, 400)
	for i: int in count:
		var c: Vector2 = r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		var s: float = rng.randf_range(0.5, 1.2)
		p.poly(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]),
				Color(Color("#FFFFFF") if rng.randf() < 0.7 else Color("#FFD6F2"), rng.randf_range(0.45, 1.0)))
	var glints: int = clampi(int(r.size.x / 40.0), 1, 6)
	for i: int in glints:
		var c: Vector2 = r.position + Vector2(rng.randf_range(0.1, 0.9) * r.size.x, rng.randf_range(0.2, 0.8) * r.size.y)
		var l: float = minf(r.size.y * 0.3, 7.0)
		var w: float = maxf(0.6, l * 0.18)
		p.poly(PackedVector2Array([c + Vector2(0, -l), c + Vector2(w, 0), c + Vector2(0, l), c + Vector2(-w, 0)]), Color("#FFF4FF"))
		p.poly(PackedVector2Array([c + Vector2(-l, 0), c + Vector2(0, -w), c + Vector2(l, 0), c + Vector2(0, w)]), Color("#FFF4FF"))

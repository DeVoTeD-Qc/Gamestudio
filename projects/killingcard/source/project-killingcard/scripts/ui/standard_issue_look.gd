# standard_issue_look.gd
# Purpose: kc-onboard-ui (onboarding-progression.md §2.2, §3; head W1 / Z2): how the "simple first
#   run" pieces look on every card form, in one place:
#     - the Standard Issue frame: plain matte grey-green, low contrast, no foil, no camo band, three
#       flat screws (kit piece frm_standard_issue when it lands, else drawn here);
#     - the serial plate "SI-01" .. "SI-04" in the top-right abilities slot (frm_serial_plate; red on
#       an enemy Standard Issue squad), lettered in the stencil font;
#     - the stencil font (Stardos Stencil Bold, OFL, assets/fonts/OFL-StardosStencil.txt): ONLY for a
#       Standard Issue card's name and its serial plate;
#     - locked keyword sockets on a Recruit calling card ("Trains: First Shot · Guard": the keyword
#       glyph greyed in frm_socket_locked with the ico_ui_lock padlock), the empty socket
#       (frm_socket_empty) and the copy level badge (R / T / V / E plate).
#   Every kit piece goes through UiKit.piece() / UiKit.draw_piece() with a code-drawn fallback, so
#   the screens work before the art arrives.
#   Entry keys (BannerView / BannerCard / CardView): standard_issue (bool), serial ("SI-02"),
#   locked (["First Shot", "Guard"]), trains ("Trains: First Shot · Guard"), level (0..3).
# Dependencies: UiKit, SynergyRules, SynergyGlyphs, RunProgress (serial), ArtTraits.
# Author: UI/UX Agent (kc-onboard-ui)
class_name StandardIssueLook
extends RefCounted

const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
const STENCIL: FontFile = preload("res://assets/fonts/StardosStencil-Bold.ttf")
## The Standard Issue palette: matte olive / grey-green, deliberately low contrast and no glow, so
## the first calling card visibly pops next to it.
const FRAME: Color = Color("#5E6B5A")
const FRAME_DARK: Color = Color("#353D33")
const SCREW: Color = Color("#7F8A79")
const NAME: Color = Color("#DDE3D3")
const PLATE: Color = Color("#9AA394")
const PLATE_EDGE: Color = Color("#4D5649")
const PLATE_TEXT: Color = Color("#1E241C")
## Enemy Standard Issue squads: the same plate, painted red (the art is the same).
const ENEMY_PLATE: Color = Color("#B0484A")
const LOCKED: Color = Color("#7E8890")
const INK: Color = Color(0.05, 0.06, 0.07, 1.0)
## Level letters of the copy level badge (Recruit, Trained, Veteran, Elite).
const LEVEL_LETTERS: Array[String] = ["R", "T", "V", "E"]


## The stencil font (Standard Issue name and serial plate only).
static func stencil() -> Font:
	return STENCIL


## True for an entry of a Standard Issue card (frame, serial plate, stencil name).
static func is_si(e: Dictionary) -> bool:
	return bool(e.get("standard_issue", false))


## Fills the Standard Issue keys of a card entry: standard_issue, serial; for a Recruit calling card
## (level 0 with locked keywords) `locked` + `trains`, and its printed keyword glyphs / effect bolt /
## Protector move to `locked` (a Recruit has none of its rules text yet). `art` = the copy's art (the
## starter's Ammo Resupply wears a Standard Issue art and frame too).
## `board`: a board banner (only a Recruit gets the level badge there; the camo band shows the rest).
## Off the board every calling-card copy gets the badge once Promotion is met (RevealGate).
static func dress(e: Dictionary, card: CardData, level: int, art: StringName = &"", board: bool = false) -> Dictionary:
	if card == null:
		return e
	var si: bool = card.standard_issue or (art != &"" and ArtTraits.is_standard_issue_art(art, card))
	if si:
		e["standard_issue"] = true
		e["serial"] = RunProgress.standard_issue_serial(card)
		e.erase("band")
	var locked: Array[String] = SynergyRules.locked_keywords(card, level)
	if not locked.is_empty():
		e["locked"] = locked
		e["trains"] = SynergyRules.trains_text(card, level)
		e["keywords"] = []
		e["bolt"] = false
		e["front_kw"] = false
		e["kw"] = ""
	if card.is_unit() and not si:
		e["level"] = level
		e["level_badge"] = not locked.is_empty() or (not board and level >= SynergyRules.LEVEL_TRAINED
				and card.has_trait_choice() and RevealGate.shown(RevealFlags.PROMOTION))
	if si and card.is_unit():
		e["reserve_trait"] = true
	# The camo band arrives with the first Promotion (§5.2; RevealGate shows it all outside a run).
	if String(e.get("band", "")) != "" and not RevealGate.shown(RevealFlags.PROMOTION):
		e["band"] = ""
	return e


# =============================================================================
# Drawing (any CanvasItem's draw callback)
# =============================================================================

## The Standard Issue frame around rect r (frm_standard_issue, else a matte grey-green border with
## three flat screws; the top-left stays plain for the cost plate).
static func draw_frame(ci: CanvasItem, r: Rect2, dim: float = 1.0) -> void:
	if UiKit.draw_piece(ci, &"frm_standard_issue", r, Color(1, 1, 1, dim)):
		return
	var w: float = 3.0 if r.size.y < 100.0 else 5.0
	var inner: Rect2 = r.grow(-w * 0.5)
	ci.draw_rect(inner, Color(FRAME, dim), false, w)
	ci.draw_rect(r.grow(-w - 0.5), Color(FRAME_DARK, 0.9 * dim), false, 1.0)
	var s: float = maxf(1.5, r.size.y * 0.035)
	for p: Vector2 in [Vector2(r.end.x - w - s - 1.0, r.position.y + w + s + 1.0), Vector2(r.end.x - w - s - 1.0, r.end.y - w - s - 1.0),
			Vector2(r.position.x + w + s + 1.0, r.end.y - w - s - 1.0)]:
		ci.draw_circle(p, s, Color(SCREW, dim))
		ci.draw_line(p - Vector2(s * 0.7, 0), p + Vector2(s * 0.7, 0), Color(FRAME_DARK, dim), 1.0)


## The serial plate ("SI-02") in rect r: frm_serial_plate (tinted red on an enemy squad), else a flat
## stamped steel tag with two rivets; the serial in the stencil font.
static func draw_serial_plate(ci: CanvasItem, r: Rect2, text: String, enemy: bool = false) -> void:
	var base: Color = ENEMY_PLATE if enemy else PLATE
	if not UiKit.draw_piece(ci, &"frm_serial_plate", r, ENEMY_PLATE if enemy else Color.WHITE):
		ci.draw_rect(r, base)
		ci.draw_rect(r, PLATE_EDGE if not enemy else base.darkened(0.45), false, 1.0)
		var rr: float = maxf(1.2, r.size.y * 0.09)
		for x: float in [r.position.x + rr * 2.2, r.end.x - rr * 2.2]:
			ci.draw_circle(Vector2(x, r.get_center().y), rr, base.darkened(0.35))
	if text == "":
		return
	var font: Font = STENCIL
	var fs: int = maxi(11, int(r.size.y * 0.66))
	var room: float = r.size.x - r.size.y * 0.5
	while fs > 9 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos: Vector2 = Vector2(r.get_center().x - sz.x * 0.5, r.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#FBEAEA") if enemy else PLATE_TEXT)


## Width a serial plate wants at plate height h ("SI-02" in the stencil font, plus the rivets).
static func serial_width(text: String, h: float) -> float:
	var fs: int = maxi(11, int(h * 0.66))
	return ceilf(STENCIL.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + h * 0.7)


## A padlock in rect r (ico_ui_lock, else drawn: shackle arc over a body).
static func draw_lock(ci: CanvasItem, r: Rect2, c: Color = LOCKED) -> void:
	if UiKit.draw_icon(ci, &"ui_lock", r, c):
		return
	var bw: float = r.size.x * 0.72
	var bh: float = r.size.y * 0.5
	var body: Rect2 = Rect2(r.position.x + (r.size.x - bw) * 0.5, r.end.y - bh, bw, bh)
	var rad: float = bw * 0.32
	ci.draw_arc(Vector2(body.get_center().x, body.position.y), rad, PI, TAU, 12, c, maxf(1.5, r.size.x * 0.14))
	ci.draw_rect(body, c)
	ci.draw_circle(body.get_center(), maxf(1.0, bw * 0.1), INK)


## A locked keyword socket: frm_socket_locked (else a grey rim with the padlock on its bottom-right
## corner) and the keyword's glyph inside, greyed to 45%.
static func draw_locked_socket(ci: CanvasItem, r: Rect2, icon: Texture2D = null) -> void:
	ci.draw_rect(r, Color(INK, 0.8))
	if icon != null:
		ci.draw_texture_rect(icon, r.grow(-r.size.x * 0.16), false, Color(LOCKED, 0.45))
	if not UiKit.draw_piece(ci, &"frm_socket_locked", r, Color(LOCKED, 0.9)):
		ci.draw_rect(r, Color(LOCKED, 0.7), false, 1.0)
		var ls: float = r.size.x * 0.46
		draw_lock(ci, Rect2(r.end.x - ls - 1.0, r.end.y - ls - 1.0, ls, ls), Color("#C2C9CF"))


## An empty trait / weapon socket (frm_socket_empty, else a dashed grey rim).
static func draw_empty_socket(ci: CanvasItem, r: Rect2) -> void:
	if UiKit.draw_piece(ci, &"frm_socket_empty", r, Color(LOCKED, 0.6)):
		return
	var pts: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i: int in 4:
		ci.draw_dashed_line(pts[i], pts[i + 1], Color(LOCKED, 0.6), 1.0, 3.0)


## The copy level badge: a small plate with R / T / V / E, rimmed in the level's band colour
## (a Recruit: plain grey rim; the letter in the HudNumber font).
static func draw_level_badge(ci: CanvasItem, r: Rect2, level: int, font: Font) -> void:
	var lv: int = clampi(level, 0, 3)
	var band: StringName = SynergyRules.LEVEL_BANDS[lv]
	ci.draw_rect(r, Color(INK, 0.85))
	var rim: Color = Color("#B9C2C9") if band == &"" else (SynergyGlyphs.BANDS[band][2] as Color)
	ci.draw_rect(r, rim, false, 1.5)
	if font == null:
		return
	var t: String = LEVEL_LETTERS[lv]
	var fs: int = maxi(10, int(r.size.y * 0.72))
	var sz: Vector2 = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	ci.draw_string(font, Vector2(r.get_center().x - sz.x * 0.5, r.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5),
			t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, rim)


## Plain words for the level badge's tooltip / inspector line.
static func level_text(level: int) -> String:
	match clampi(level, 0, 3):
		0:
			return "Recruit: trait on, keywords locked until it trains (Promotion)."
		1:
			return "Trained: trait and keywords on."
		2:
			return "Veteran: Trained, +1 Armor."
	return "Elite: Trained, +1 Armor and +1 FP."


## Keyword id of a player-facing locked keyword name ("First Shot" -> &"first_shot", "Cover 1" ->
## &"cover", "Guard" -> &"guard", "Front line" -> &"arrives_front", "Aura" -> &"aura").
static func keyword_id(name: String) -> StringName:
	var base: String = name.strip_edges()
	for prefix: String in ["Cover", "Patch"]:
		if base.begins_with(prefix):
			base = prefix
	if base == "Front line":
		return &"arrives_front"
	return StringName(base.to_snake_case())


## A locked keyword (by its name) in socket r: the keyword's glyph greyed under the padlock.
static func draw_locked_keyword(ci: CanvasItem, r: Rect2, name: String) -> void:
	var id: StringName = keyword_id(name)
	var icon: Texture2D = IconSheet.get_keyword_icon(id) if IconSheet.KEYWORD_ICONS.has(id) else null
	draw_locked_socket(ci, r, icon)
	if icon == null:
		var g: Rect2 = r.grow(-r.size.x * 0.18)
		if SynergyGlyphs.KEYWORD_NAMES.has(id):
			SynergyGlyphs.draw_keyword_icon(ci, g, id, Color(LOCKED, 0.5))
		elif id == &"pierce":
			SynergyGlyphs.draw_pierce_icon(ci, g, Color(LOCKED, 0.5))
		elif id == &"arrives_front":
			ci.draw_polyline(PackedVector2Array([g.position + Vector2(g.size.x * 0.2, g.size.y * 0.65),
					g.position + Vector2(g.size.x * 0.5, g.size.y * 0.3), g.position + Vector2(g.size.x * 0.8, g.size.y * 0.65)]), Color(LOCKED, 0.5), 2.0)
		else:
			ci.draw_circle(g.get_center(), g.size.x * 0.22, Color(LOCKED, 0.5))

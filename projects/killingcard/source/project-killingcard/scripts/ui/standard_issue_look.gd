# standard_issue_look.gd
# Purpose: kc-onboard-ui (onboarding-progression.md §2.2, §3; head W1 / Z2): how the "simple first
#   run" pieces look on every card form, in one place:
#     - the Standard Issue frame: plain matte grey-green, low contrast, no foil, no camo band, three
#       flat screws (kit piece frm_standard_issue when it lands, else drawn here);
#     - the serial plate "SI-01" .. "SI-04" in the top-right abilities slot (frm_serial_plate; red on
#       an enemy Standard Issue squad), lettered in the stencil font;
#     - the stencil font (Stardos Stencil Bold, OFL, assets/fonts/OFL-StardosStencil.txt): ONLY for a
#       Standard Issue card's name and its serial plate;
#     - the empty socket (frm_socket_empty) of a Standard Issue card's trait slot.
#   kc-ipad-cards (kc-no-training): copy levels, the level coin / badge, "Trains:" lines and locked
#   keyword sockets are gone (every copy has its keywords from the start).
#   Every kit piece goes through UiKit.piece() / UiKit.draw_piece() with a code-drawn fallback, so
#   the screens work before the art arrives.
#   Entry keys (BannerView / BannerCard / CardView): standard_issue (bool), serial ("SI-02").
# Dependencies: UiKit, SynergyGlyphs, RunProgress (serial), ArtTraits.
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


## The stencil font (Standard Issue name and serial plate only).
static func stencil() -> Font:
	return STENCIL


## True for an entry of a Standard Issue card (frame, serial plate, stencil name).
static func is_si(e: Dictionary) -> bool:
	return bool(e.get("standard_issue", false))


## Fills the Standard Issue keys of a card entry: standard_issue, serial, reserve_trait. `art` = the
## copy's art (the starter's Ammo Resupply wears a Standard Issue art and frame too). `board` is kept
## for callers. kc-ipad-cards: no level, band, locked or trains keys any more (kc-no-training).
static func dress(e: Dictionary, card: CardData, art: StringName = &"", _board: bool = false) -> Dictionary:
	if card == null:
		return e
	var si: bool = card.standard_issue or (art != &"" and ArtTraits.is_standard_issue_art(art, card))
	if si:
		e["standard_issue"] = true
		e["serial"] = RunProgress.standard_issue_serial(card)
	for k: String in ["band", "level", "level_badge", "locked", "trains"]:
		e.erase(k)
	if si and card.is_unit():
		e["reserve_trait"] = true
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
	var font: Font = CardLook.sharp_font(STENCIL, CardLook.text_os_of(ci))
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


## An empty trait / weapon socket (frm_socket_empty, else a dashed grey rim).
static func draw_empty_socket(ci: CanvasItem, r: Rect2) -> void:
	if UiKit.draw_piece(ci, &"frm_socket_empty", r, Color(LOCKED, 0.6)):
		return
	var pts: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i: int in 4:
		ci.draw_dashed_line(pts[i], pts[i + 1], Color(LOCKED, 0.6), 1.0, 3.0)

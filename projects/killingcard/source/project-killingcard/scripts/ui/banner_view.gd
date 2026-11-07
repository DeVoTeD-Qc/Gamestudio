# banner_view.gd
# Purpose: Draws one 4:1 calling-card banner (board-and-cards-ux.md §3.2-3.3).
#   kc-cards-impl: the head's C1+ board card (documentation/ux/card-design-options.html): the full
#   calling-card art, uncropped and undimmed, with only what you need at rest:
#     bottom-centre abilities, as big as the stats (kc-ipad-cards; ABILITIES_BOTTOM, else top-right)
#     bottom-right the FP reticle ring (team colour: teal yours, red the rival's; green when buffed)
#                  and the Armor ballistic plate (grey both sides, amber when damaged, the number left)
#     bottom-left  the trait chip (one at most), as big as the stats, 45% faint, lit with a glow while
#                  its set bonus is on
#   Peek (desktop hover / touch hold, `peek`; always for hand cards, `full_info`; or Settings > Cards >
#   "Always show all card info", `show_all`): the cost hex, top-left (no level coin, no weapon).
#   Damaged: a thin amber bottom edge plus the corner crack. No spine, no
#   bands, no serial plate. The synergy rail's highlight (`syn_focus`) shows the trait on every card,
#   glows the matching cards and darkens the rest. See anatomy(); pieces drawn by CardLook.
#   Kept: PLAN tag (your queued card), frontline keyline, Operator brass keyline, Elite keyline,
#   Standard Issue frame, INCOMING back (rival hidden play), landing ghost (50%, dashed), target
#   reticle; focus / placement plays the banner_shimmer shader on the art (one animated banner at a
#   time: BannerView.focus_owner); an animated licensed art plays its frame sheet while focused.
#   The layout works with any 4:1 art (the pitch build swaps in its own art at runtime).
# Dependencies: BannerArtDB, IconSheet, CardLook, hud_theme.tres colours (Hud: friend, enemy, accent).
#   kc-ui-hooks: the rail highlight asks the UI kit for fx_glow_rail first (keylines = fallback); the
#   crack, badges and Pick glyph go through CardLook, which asks the kit.
# Author: Mechanics Developer Agent (kc-board); C1+: UI/UX Agent (kc-cards-impl)
class_name BannerView
extends Control

enum Mode { EMPTY, UNIT, INCOMING, GHOST }

const SHIMMER: Shader = preload("res://assets/shaders/banner_shimmer.gdshader")
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
const CLASS_ICONS: Dictionary = {
	"SMG": &"class_smg", "SHOTGUN": &"class_shotgun", "AR": &"class_ar", "SNIPER": &"class_sniper",
	"LMG": &"class_lmg", "OPERATOR": &"type_operator",
}
## kc-cards-impl: kept for callers; the board no longer dims back rows (full-strength art).
const BACK_ROW_TINT: Color = Color(1.0, 1.0, 1.0, 1.0)
## kc-ui-hooks: the UI kit glow of the rail highlight (prompt pack §7.4b).
const RAIL_GLOW_PIECE: StringName = &"fx_glow_rail"
## Art brightness of a card that does not match the synergy rail's highlighted trait.
const SYN_DIM: float = 0.45
const BRASS: Color = Color("#C9A227")
const BRASS_DARK: Color = Color("#5A4512")
const STEEL: Color = Color("#3A444D")
const INK: Color = Color(0.05, 0.06, 0.07, 1.0)
const DAMAGED: Color = Color("#F2A33A")
## Camo tiers of the Operator's mastery band (pattern differs per tier, not only colour).
const CAMO: Dictionary = {
	&"base": [Color("#4B5A3A"), Color("#2F3A25"), Color("#7A8A5A")],
	&"gold": [Color("#C9A227"), Color("#7A5E12"), Color("#F3D36B")],
	# kc-cod2 weapon-mastery tiers 2-4 (tier 1 Gilded = the Base camo, head B3).
	&"forged": [Color("#D9DEE3"), Color("#8E979F"), Color("#FFFFFF")],
	&"priceless": [Color("#3E8EDE"), Color("#1B3F78"), Color("#9FE3FF")],
	&"interstellar": [Color("#7B3FC4"), Color("#1A0F3A"), Color("#FF7AD9")],
}
## The one banner animating right now (focus / placement), so a new focus stops the old one.
static var focus_owner: WeakRef = null

var mode: Mode = Mode.EMPTY
## &"player" / &"enemy": whose banner (decides the inner edge and badge shapes).
var side: StringName = &"player"
## Unit entry (match_snapshot.gd unit_entry): name, cls, fp, armor, armor_max, operator, keywords,
## bolt, banner, pending, elite, camo.
var entry: Dictionary = {}
var is_front: bool = false
var is_target: bool = false
## Kept for callers: kc-cards-impl draws every row at full brightness.
var dim_back: bool = true
## INCOMING: the revealed name behind the back (Recon / Callout), "" = unknown.
var revealed: String = ""
## kc-ui4: the card's name (the chassis) and, under it, the art's subname (licensed calling-card
## title or our variant name) drawn between the FP and Armor badges. Off for the inspector's big
## banner (its title says it).
var show_name: bool = true
## kc-ui4: px kept free at the top-left for a hand / codex card's cost hex (the plate row starts
## after it).
var lead: float = 0.0:
	set(value):
		lead = value
		if _overlay != null:
			_overlay.queue_redraw()
## kc-hand-dim, retired by kc-cards-impl (the C1+ art is never dimmed): kept as a no-op flag.
var readability: bool = false
## Kept for callers (0: the art at full strength).
const ART_DIM: float = 0.0
## kc-readability: hand cards (X1) boost the cost hex and draw FP / Armor themselves (bigger, across
## the banner and the name plate).
var cost_scale: float = 1.0
var draw_stats: bool = true
## Ability icon size override (px; 0 = 20 x k). Hand cards use a smaller row so FP / Armor fit under it.
var ability_px: float = 0.0
## Kept for callers (kc-ipad-cards: the level coin and weapon pill are gone).
var peek_extras: bool = true
## kc-ipad-cards: hand cards (BannerCard) draw the cost, trait and kind word themselves.
var draw_peek: bool = true:
	set(value):
		draw_peek = value
		if _overlay != null:
			_overlay.queue_redraw()
var show_trait: bool = true:
	set(value):
		show_trait = value
		if _overlay != null:
			_overlay.queue_redraw()
## Narrow hand cards (16:9 phones) leave the abilities to the docked preview (FP / Armor take the room).
var show_abilities: bool = true:
	set(value):
		show_abilities = value
		if _overlay != null:
			_overlay.queue_redraw()
## kc-cards-impl: hovered (desktop) / held (touch): shows the cost hex.
var peek: bool = false:
	set(value):
		if peek != value:
			peek = value
			if _overlay != null:
				_overlay.queue_redraw()
## Hand / list cards: the peek group always shows (the hand is where you decide what to play).
var full_info: bool = false:
	set(value):
		full_info = value
		if _overlay != null:
			_overlay.queue_redraw()
## Settings > Cards > "Always show all card info" (Settings.show_all_card_info; set by the Settings
## autoload, every banner reads it when it draws: call refresh_all() after a change).
static var show_all: bool = false
## The synergy rail's highlighted trait (&"" = none): the matching cards glow, the rest darken.
var syn_focus: StringName = &"":
	set(value):
		if syn_focus != value:
			syn_focus = value
			if _art != null:
				_refresh()
## kc-ui4: badge / plate sizes follow this height instead of the banner's own (hand cards are
## taller than 4:1 but keep the board's icon sizes). 0 = the banner's height.
var metric_h: float = 0.0
var _art: TextureRect
var _overlay: Control
var _shimmer_until: float = -1.0
var _pulse: float = 0.0
## The shown art (null for INCOMING / EMPTY) and its flipbook while focused.
var _banner_art: BannerArt = null
var _still: Texture2D = null
var _flip: AtlasTexture = null
var _flip_t0: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_art = TextureRect.new()
	_art.name = "Art"
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)
	for c: Control in [_art, _overlay]:
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_overlay.queue_redraw)
	add_to_group(&"card_banners")


## Redraws every banner (after Settings > Cards > "Always show all card info" changes).
static func refresh_all(tree: SceneTree) -> void:
	if tree != null:
		tree.call_group(&"card_banners", &"queue_redraw_all")


func queue_redraw_all() -> void:
	_overlay.queue_redraw()


## Shows a unit (or a queued unit / the Operator). unit_side: &"player" / &"enemy".
func show_unit(unit: Dictionary, unit_side: StringName, front: bool) -> void:
	mode = Mode.UNIT
	entry = unit
	side = unit_side
	is_front = front
	revealed = ""
	_set_art(StringName(String(unit.get("banner", unit.get("art", "")))), unit)
	_refresh()


## A rival's hidden play in its landing slot (face-down banner back).
func show_incoming(revealed_name: String = "") -> void:
	mode = Mode.INCOMING
	entry = {}
	side = &"enemy"
	is_front = false
	revealed = revealed_name
	_clear_art()
	_refresh()


## Landing preview of the selected card: its full banner at 50%, dashed outline.
func show_ghost(unit: Dictionary, unit_side: StringName = &"player") -> void:
	mode = Mode.GHOST
	entry = unit
	side = unit_side
	is_front = false
	_set_art(StringName(String(unit.get("banner", ""))), unit)
	_refresh()


func show_empty() -> void:
	mode = Mode.EMPTY
	entry = {}
	is_front = false
	_clear_art()
	_refresh()


func _clear_art() -> void:
	_flip = null
	_banner_art = null
	_still = null
	_art.texture = null


func set_target(value: bool) -> void:
	if is_target != value:
		is_target = value
		_overlay.queue_redraw()


## Plays the shimmer (animated banner) for `seconds` (<= 0: until set_focus(false)).
func set_focus(on: bool, seconds: float = 0.0) -> void:
	if on:
		if focus_owner != null:
			var prev: BannerView = focus_owner.get_ref() as BannerView
			if prev != null and prev != self:
				prev.set_focus(false)
		focus_owner = weakref(self)
		if not _start_flipbook():
			var mat := ShaderMaterial.new()
			mat.shader = SHIMMER
			mat.set_shader_parameter(&"start_time", Time.get_ticks_msec() / 1000.0)
			_art.material = mat
		_shimmer_until = Time.get_ticks_msec() / 1000.0 + seconds if seconds > 0.0 else INF
		set_process(true)
	else:
		_art.material = null
		_stop_flipbook()
		_shimmer_until = -1.0
		set_process(mode == Mode.INCOMING)


func is_focused() -> bool:
	return _art.material != null or _flip != null


## True while an animated (frame sheet) art plays.
func is_flipbook_playing() -> bool:
	return _flip != null


## The BannerArt shown (null when none).
func get_banner_art() -> BannerArt:
	return _banner_art


func _start_flipbook() -> bool:
	if _banner_art == null or mode not in [Mode.UNIT, Mode.GHOST]:
		return false
	var sheet: Texture2D = BannerArtDB.frames_texture(_banner_art)
	if sheet == null:
		return false
	var cell_h: float = sheet.get_height() / float(_banner_art.frame_count)
	_flip = AtlasTexture.new()
	_flip.atlas = sheet
	_flip.filter_clip = true
	_flip.region = Rect2(0, 0, sheet.get_width(), cell_h)
	_flip_t0 = Time.get_ticks_msec() / 1000.0
	_art.texture = _flip
	return true


func _stop_flipbook() -> void:
	if _flip != null:
		_flip = null
		_art.texture = _still


func _step_flipbook() -> void:
	var n: int = _banner_art.frame_count
	var i: int = int((Time.get_ticks_msec() / 1000.0 - _flip_t0) * 1000.0 / float(_banner_art.frame_ms)) % n
	var cell_h: float = _flip.atlas.get_height() / float(n)
	var r: Rect2 = Rect2(0, i * cell_h, _flip.atlas.get_width(), cell_h)
	if r != _flip.region:
		_flip.region = r


func has_art() -> bool:
	return _art.texture != null


## Badge / number / plate sizes for a banner height h (v2 phone 57: 28/20/22, desktop 76: 34/24/26).
static func metrics(h: float) -> Dictionary:
	# kc-board2 (board-layout-v2.md §2.1): phone 57 px -> 28 / 20 / 22, desktop 76 px -> 34 / 24 / 26.
	var badge: float = roundf(h * 6.0 / 19.0 + 10.0)
	return {
		"badge": badge, "number": roundf(badge * 0.72), "plate": roundf(h * 4.0 / 19.0 + 10.0),
		"spine": 0.0, "pad": maxf(2.0, roundf(h * 0.04)),
		# kc-cards-impl: the C1+ scale (1.0 = the phone's 57 px banner).
		"k": h / 57.0,
	}


func _process(_delta: float) -> void:
	if _shimmer_until > 0.0 and Time.get_ticks_msec() / 1000.0 > _shimmer_until:
		set_focus(false)
	elif _flip != null:
		_step_flipbook()
	if mode == Mode.INCOMING:
		_pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
		_overlay.queue_redraw()


func _set_art(art_id: StringName, unit: Dictionary) -> void:
	var hint: Dictionary = {"cls": unit.get("cls", ""), "type": unit.get("type", "unit")}
	var prev: BannerArt = _banner_art
	var flip: AtlasTexture = _flip
	_flip = null
	_banner_art = BannerArtDB.get_art(art_id, hint) if art_id != &"" else null
	_still = BannerArtDB.banner_texture(art_id, hint) if art_id != &"" else null
	_art.texture = _still
	if flip != null:
		if prev == _banner_art:
			_flip = flip  # same art re-shown by a refresh: keep the loop running
			_art.texture = _flip
		elif not _start_flipbook():
			set_focus(false)
	# Rival figures face the other way (the art is mirrored, never recoloured).
	_art.flip_h = side == &"enemy"


func _refresh() -> void:
	var tint: Color = Color.WHITE
	# kc-cards-impl (C1+): the calling card at full strength on every row (no back-row dim, no
	# readability dim); a ghost / your PLAN card is see-through, a non-matching card under a rail
	# highlight is darkened.
	if mode == Mode.GHOST or bool(entry.get("pending", false)):
		tint.a = 0.55 if mode == Mode.GHOST else 0.85
	if syn_focus != &"" and mode == Mode.UNIT and not _matches_focus():
		tint = Color(tint.r * SYN_DIM, tint.g * SYN_DIM, tint.b * SYN_DIM, tint.a)
	_art.self_modulate = tint
	_art.visible = mode in [Mode.UNIT, Mode.GHOST]
	set_process(mode == Mode.INCOMING or _shimmer_until > 0.0)
	_overlay.queue_redraw()
	queue_redraw()


func _col(name: StringName) -> Color:
	return get_theme_color(name, &"Hud")


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	match mode:
		Mode.EMPTY:
			return
		Mode.INCOMING:
			_draw_incoming_back(r)
		_:
			draw_rect(r, Color("#1C2228"))


func _draw_incoming_back(r: Rect2) -> void:
	draw_rect(r, Color("#2A1416"))
	var red: Color = _col(&"enemy")
	var step: float = maxf(10.0, size.y * 0.32)
	var x: float = -size.y
	while x < size.x:
		draw_colored_polygon(PackedVector2Array([Vector2(x, size.y), Vector2(x + step * 0.5, size.y),
				Vector2(x + step * 0.5 + size.y, 0), Vector2(x + size.y, 0)]), Color(red, 0.18))
		x += step


## True while the cost hex shows: hovered or held (peek), a hand card (full_info),
## or Settings > Cards > "Always show all card info" (show_all).
func is_peeking() -> bool:
	return peek or full_info or show_all


## The synergy rail's highlight: this card has the focused trait.
func _matches_focus() -> bool:
	return syn_focus != &"" and StringName(String(entry.get("trait", ""))) == syn_focus


## The traits this card shows bottom-left (one today; the Operator shows its dog tag instead).
func trait_list() -> Array[StringName]:
	var out: Array[StringName] = []
	if String(entry.get("trait", "")) != "":
		out.append(StringName(String(entry["trait"])))
	return out


## Whether a trait chip is lit (its set bonus is on: tier 2+).
func trait_lit() -> bool:
	return int(entry.get("trait_tier", 0)) >= 2


## kc-readability: the soft dark backings drawn on this banner now (tests): one per badge group.
var backing_rects: Array[Rect2] = []


func _backing(o: Control, r: Rect2, radius: float = 3.0) -> void:
	backing_rects.append(r)
	CardLook.draw_chip(o, r, radius)


func _draw_overlay() -> void:
	backing_rects.clear()
	var o: Control = _overlay
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	if mode == Mode.EMPTY:
		return
	var mine: bool = side == &"player"
	var side_c: Color = _col(&"friend") if mine else _col(&"enemy")
	var m: Dictionary = _metrics_now()
	if mode == Mode.INCOMING:
		_draw_incoming_text(o, r, m)
		o.draw_rect(r.grow(-1), Color(_col(&"enemy"), 0.9), false, 2.0)
		return
	var op: bool = bool(entry.get("operator", false))
	var pending: bool = bool(entry.get("pending", false))
	var k: float = m["k"]
	# kc-cards-impl (C1+): no spine, no bands, no scrim; frames are a thin keyline only.
	if op:
		o.draw_rect(r.grow(-1.0), BRASS, false, 2.0)
	elif bool(entry.get("elite", false)):
		o.draw_rect(r.grow(-1.0), BRASS, false, 1.5)
	elif StandardIssueLook.is_si(entry):
		StandardIssueLook.draw_frame(o, r, 0.85 if mode == Mode.GHOST else 1.0)
	var an: Dictionary = anatomy(size, m, entry, lead if lead > 0.0 else -1.0)
	var armor: int = int(entry.get("armor", 0))
	var damaged: bool = entry.has("fp") and armor < int(entry.get("armor_max", armor))
	# Damaged: the corner crack (under the peek group) and a thin amber bottom edge.
	if damaged:
		CardLook.draw_crack(o, Vector2(3, 3) * k, 22.0 * k)
	# kc-ipad-cards: abilities (bottom-centre, or top-right), as big as the stats, on one dark plate.
	var abil: Array = an["abilities"] if show_abilities else []
	if not abil.is_empty():
		var grp: Rect2 = abil[0][1]
		for ab: Array in abil:
			grp = grp.merge(ab[1])
		_backing(o, grp.grow(2.0 * k), 3.0 * k)
	for ab: Array in abil:
		CardLook.draw_ability(o, ab[1], ab[0], _col(&"accent"), mine, bool(entry.get("kw_active", false)), side_c)
	# Bottom-right (always): the FP reticle (team colour) and the Armor plate (grey; amber when damaged).
	# kc-readability: hand cards (X1) draw these bigger across the banner and the name plate.
	if entry.has("fp") and draw_stats:
		var fp_rect: Rect2 = an["fp"]
		var ar_rect: Rect2 = an["armor"]
		var cov: Rect2 = an.get("cover", Rect2())
		var chip_l: float = cov.position.x if cov.size.x > 0.0 else fp_rect.position.x
		_backing(o, Rect2(Vector2(chip_l - 2.0 * k, minf(fp_rect.position.y, ar_rect.position.y) - 1.0 * k),
				Vector2(ar_rect.end.x - chip_l + 4.0 * k, maxf(fp_rect.size.y, ar_rect.size.y) + 2.0 * k)), 4.0 * k)
		CardLook.draw_reticle(o, fp_rect, int(entry.get("fp", 0)), side, int(entry.get("fp_trend", 0)))
		CardLook.draw_armor(o, ar_rect, armor, damaged)
		if cov.size.x > 0.0:
			_draw_cover_chip(o, cov, int(entry.get("cover", 0)), int(entry.get("cover_trend", 0)), m)
	# Bottom-left: traits, 45% faint at rest, lit with a glow while their set bonus is on; under a rail
	# highlight every card shows its trait at full and the matching cards ring it. The Operator: its dog tag.
	if an.has("trait") and show_trait:
		# kc-readability: a soft dark backing behind the trait chip too.
		if op or not trait_list().is_empty():
			_backing(o, (an["trait"] as Rect2).grow(2.0 * k), 3.0 * k)
		if op:
			_draw_dog_tag(o, an["trait"])
		else:
			var lit: bool = trait_lit()
			for t: StringName in trait_list():
				var focus: bool = syn_focus != &"" and t == syn_focus
				CardLook.draw_trait(o, an["trait"], t, lit, focus, 1.0 if syn_focus != &"" else -1.0)
	# Top-left (peek): the cost hex on a soft dark backing (kc-ipad-cards: no level coin, no weapon).
	if is_peeking() and draw_peek:
		var grp: Rect2 = an["cost"]
		if grp.has_area():
			_backing(o, grp.grow(2.0 * k), 5.0 * k)
		if lead <= 0.0 and (an["cost"] as Rect2).size.x > 0.0:
			CardLook.draw_cost(o, an["cost"], str(entry.get("cost", "")), bool(entry.get("cant_pay", false)))
	if not entry.has("fp") and show_trait:
		_draw_kind_word(o, an)
	if show_name and mode in [Mode.UNIT, Mode.GHOST] and (an["name"] as Rect2).size.x > 0.0:
		_draw_names(o, an)
	# The rail highlight: matching cards glow in the trait's colour; the rest are darkened.
	if syn_focus != &"" and mode == Mode.UNIT:
		if _matches_focus():
			var tc: Color = SynergyGlyphs.trait_color(syn_focus)
			# kc-ui-hooks: the painted glow (fx_glow_rail, white luma, tinted per trait); else two keylines.
			if not UiKit.draw_piece(o, RAIL_GLOW_PIECE, r.grow(8.0 * k), tc):
				o.draw_rect(r.grow(-1.5), tc, false, 3.0)
				o.draw_rect(r.grow(-4.0), Color(tc, 0.35), false, 3.0)
		else:
			o.draw_rect(r, Color(0, 0, 0, 0.35))
	if pending:
		_draw_tag(o, "PLAN", _col(&"accent"), mine, m)
		_dashed_rect(o, r.grow(-1.0), _col(&"accent"), 2.0)
	elif is_front:
		o.draw_rect(r.grow(-1.0), Color(side_c, 0.85), false, 1.5)
	if mode == Mode.GHOST:
		_dashed_rect(o, r.grow(-1.0), _col(&"text"), 2.0)
	# The damaged bottom edge over the frontline keyline (so it always reads).
	if damaged:
		CardLook.draw_damage_edge(o, r, maxf(2.0, 2.0 * k))
	if is_target:
		_draw_reticle(o, r)


## kc-cards-impl: the C1+ card anatomy (the head's pick, documentation/ux/card-design-options.html).
## Sizes follow k = banner height / 57 (the phone board banner).
## kc-ipad-cards (the head: "make sure ability icons and trait are big too along with the stats. Maybe
## Ability should be bottom centered?"): the trait chip and the ability icons are as big as the FP
## reticle (30k), each group on its own dark backing plate; no level coin, no weapon pill:
##   top-left      (peek) cost hex 24k
##   bottom-left   (always) the trait chip 30k (one trait at most); the Operator: its dog tag
##   bottom-centre (ABILITIES_BOTTOM, the default) abilities 30k between the trait and the stats,
##                 shrunk to fit; else top-right (the kc-cards-impl spot), right to left from the corner
##   bottom-right  (always) FP reticle 30k, then the Armor plate 29k x 30k at the corner (Cover chip left)
## Keys: cost, abilities [[kind, rect]], trait, fp, armor, cover, name (empty: the board card has no
## name), sub / mid (a statless card's kind word), plate_y, band (0), k.
static func anatomy(sz: Vector2, m: Dictionary, e: Dictionary, lead_px: float = -1.0) -> Dictionary:
	var op: bool = bool(e.get("operator", false))
	var k: float = m["k"]
	var out: Dictionary = {"plate_y": roundf(4.0 * k), "band": 0.0, "k": k}
	var gap: float = maxf(1.0, roundf(2.0 * k))
	# Bottom-right: Armor at the corner, FP left of it.
	# kc-readability: FP reticle 30 / Armor plate 29x30 at k = 1: 20 px digits.
	var aw: float = roundf(29.0 * k)
	var ah: float = roundf(30.0 * k)
	var fs: float = roundf(30.0 * k)
	var bottom: float = sz.y - roundf(2.0 * k)
	var armor: Rect2 = Rect2(sz.x - roundf(4.0 * k) - aw, bottom - ah, aw, ah)
	var fp: Rect2 = Rect2(armor.position.x - gap - fs, bottom - fs, fs, fs)
	out["armor"] = armor
	out["fp"] = fp
	var stat_x: float = fp.position.x if e.has("fp") else sz.x - roundf(4.0 * k)
	if e.has("fp") and int(e.get("cover", 0)) > 0:
		var cv: float = roundf(20.0 * k)
		out["cover"] = Rect2(fp.position.x - gap - cv, fp.position.y + (fs - cv) * 0.5, cv, cv)
		stat_x = (out["cover"] as Rect2).position.x
	# Bottom-left: the trait chip (or the Operator's dog tag), as big as the FP reticle.
	var ts: float = fs
	var tx: float = roundf(4.0 * k)
	if op or String(e.get("trait", "")) != "" or bool(e.get("reserve_trait", false)):
		out["trait"] = Rect2(tx, bottom - ts, ts, ts)
		tx += ts + gap
	# Top-left peek group: the cost hex (kept above the bottom row's trait chip).
	var x: float = roundf(4.0 * k)
	var y: float = roundf(2.0 * k)
	var cs: float = roundf(24.0 * k * float(m.get("cost_scale", 1.0)))
	if out.has("trait"):
		cs = minf(cs, maxf(8.0, bottom - ts - y - 1.0))
	var has_cost: bool = str(e.get("cost", "")) != "" and not op
	if lead_px > 0.0:
		out["cost"] = Rect2(x, y, lead_px - 2.0, cs)
	elif has_cost:
		out["cost"] = Rect2(x, y, cs, cs)
	else:
		out["cost"] = Rect2()
	# Abilities: as big as the stats (ability_px overrides), bottom-centre or top-right.
	var kw: float = float(m["ability_px"]) if m.has("ability_px") else fs
	var kinds: Array = ability_kinds(e)
	var kws: Array = []
	var n: int = kinds.size()
	if bool(m.get("abilities_bottom", ABILITIES_BOTTOM)):
		var left: float = tx + gap
		var right: float = stat_x - 2.0 * gap
		var room: float = maxf(0.0, right - left)
		if n > 0 and n * kw + (n - 1) * gap > room:
			kw = floorf(maxf(8.0, (room - (n - 1) * gap) / n))
		var total: float = n * kw + maxf(0, n - 1) * gap
		var kx0: float = left + maxf(0.0, (room - total) * 0.5)
		for i: int in n:
			kws.append([kinds[i], Rect2(kx0 + i * (kw + gap), bottom - kw, kw, kw)])
	else:
		var kx: float = sz.x - roundf(4.0 * k) - kw
		var ky: float = roundf(2.0 * k)
		for kind: Variant in kinds:
			kws.append([kind, Rect2(kx, ky, kw, kw)])
			kx -= kw + gap
	out["abilities"] = kws
	out["name"] = Rect2()
	out["sub"] = Rect2(tx + 2.0, sz.y - roundf(3.0 * k) - fs, maxf(0.0, stat_x - tx - 6.0), fs)
	var mid_top: float = cs + roundf(4.0 * k)
	out["mid"] = Rect2(roundf(4.0 * k), mid_top, sz.x - roundf(8.0 * k), maxf(0.0, sz.y - roundf(3.0 * k) - fs - mid_top))
	return out


## kc-ipad-cards: ability icons bottom-centre (true, the recommendation) or top-right (false: the
## kc-cards-impl spot). A static switch so screenshots can compare the two.
static var ABILITIES_BOTTOM: bool = true


## The ability plates of an entry in order: [&"protector"?, keyword icon ids (max 2, 1 with a bolt),
## &"bolt"?, [&"kw", keyword]?]. The Operator shows its keywords too.
## kc-cards-impl: no serial plate on cards (the Standard Issue frame says it; the inspector names it).
## kc-ipad-cards: no locked (Recruit) keywords any more (kc-no-training).
static func ability_kinds(e: Dictionary) -> Array:
	var icons: Array = []
	for kw: Dictionary in e.get("keywords", []):
		var id: StringName = StringName(kw.get("id", &""))
		var key: StringName = IconSheet.KEYWORD_ICONS.get(id, &"")
		if key != &"" and IconSheet.has_icon(key):
			icons.append(key)
		elif id == &"pierce":
			icons.append(&"pierce")  # kc-fight-ui: drawn glyph (no sheet icon)
	if bool(e.get("front_kw", false)):
		icons.push_front(&"protector")
	var bolt: bool = bool(e.get("bolt", false)) or icons.size() > 2
	var out: Array = icons.slice(0, 1 if bolt else 2)
	if bolt:
		out.append(&"bolt_more" if icons.size() > 2 else &"bolt")
	if String(e.get("kw", "")) != "":
		out.append([&"kw", StringName(String(e["kw"]))])
	return out


## Kept for callers: the plate row's y / first x and the FP / Armor rects (anatomy()).
static func layout(sz: Vector2, m: Dictionary, op: bool = false, _level_band: float = 0.0, lead_px: float = 0.0) -> Dictionary:
	var e: Dictionary = {"operator": op, "fp": 0}
	var a: Dictionary = anatomy(sz, m, e, lead_px if lead_px > 0.0 else -1.0)
	return {"plate_y": a["plate_y"], "left_x": roundf(4.0 * float(m["k"])) + maxf(0.0, lead_px), "fp": a["fp"], "armor": a["armor"]}


## The FP and Armor badge rects of this banner as drawn now (tests, FX anchors).
func stat_rects() -> Dictionary:
	var a: Dictionary = anatomy_now()
	return {"fp": a["fp"], "armor": a["armor"]}


## Every slot of this banner as drawn now (tests: cost, class, trait, abilities, sub...).
func anatomy_now() -> Dictionary:
	return anatomy(size, _metrics_now(), entry, lead if lead > 0.0 else -1.0)


func _metrics_now() -> Dictionary:
	var m: Dictionary = metrics(minf(size.y, metric_h) if metric_h > 0.0 else size.y)
	m["cost_scale"] = cost_scale
	if ability_px > 0.0:
		m["ability_px"] = ability_px
	return m


## Name sizes for a banner height (phone 57: 16 / 16; desktop 76: 18 / 16).
static func name_sizes(h: float) -> Vector2i:
	return Vector2i(clampi(int(roundf(h * 0.24)), 16, 18), 16)


## The hover zoom's name (show_name): the card's chassis name in the title style, bottom-centre
## between the trait and the stats.
func _draw_names(o: Control, a: Dictionary) -> void:
	var nm: String = String(entry.get("name", "")).replace("★", "").strip_edges().to_upper()
	var nr: Rect2 = a["name"]
	if nm == "" or nr.size.x < 16.0:
		return
	var font: Font = CardLook.TITLE_FONT
	var nfs: int = CardLook.TITLE_PX
	nm = fit_text(nm, font, nfs, nr.size.x)
	var base: Vector2 = Vector2(nr.position.x, nr.position.y + (nr.size.y + font.get_ascent(nfs) - font.get_descent(nfs)) * 0.5)
	o.draw_string_outline(font, base, nm, HORIZONTAL_ALIGNMENT_LEFT, nr.size.x, nfs, 4, INK)
	o.draw_string(font, base, nm, HORIZONTAL_ALIGNMENT_LEFT, nr.size.x, nfs, CardLook.TITLE_COLOR)


## A statless card's kind word ("TACTIC" / "FIELD"), bottom-centre.
func _draw_kind_word(o: Control, a: Dictionary) -> void:
	var sub: String = String(entry.get("kind_word", ""))
	var sr: Rect2 = a["sub"]
	if sub == "" or sr.size.x < 24.0:
		return
	var font: Font = CardLook.TITLE_FONT
	var fs: int = 16
	var sb: Vector2 = Vector2(sr.position.x, sr.position.y + (sr.size.y + font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
	o.draw_string_outline(font, sb, sub, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, fs, 3, INK)
	o.draw_string(font, sb, sub, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, fs, Color("#B9C2C9"))


## `text` cut to `width` at font size `fs`, ending in "…" when cut.
static func fit_text(text: String, font: Font, fs: int, width: float, ellipsis: String = "…") -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width:
		return text
	var t: String = text
	while t.length() > 1 and font.get_string_size(t + ellipsis, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + ellipsis


## The art's colour multiplier now (tests: full-strength art; darkened under a rail highlight).
func get_art_modulate() -> Color:
	return _art.self_modulate


func _draw_incoming_text(o: Control, r: Rect2, m: Dictionary) -> void:
	var font: Font = get_theme_font(&"font", &"HudHeader")
	var fs: int = int(m["number"])
	var text: String = ("SPOTTED: " + revealed.to_upper()) if revealed != "" else "INCOMING"
	var dot_r: float = fs * 0.3
	var room: float = size.x - dot_r * 2.0 - 16.0
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room and revealed != "":
		text = revealed.to_upper()
	var w: float = minf(room, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var total: float = w + dot_r * 2.0 + 6.0
	var x: float = (size.x - total) * 0.5
	var cy: float = size.y * 0.5
	o.draw_circle(Vector2(x + dot_r, cy), dot_r * (0.8 + 0.3 * _pulse), Color(_col(&"enemy"), 0.6 + 0.4 * _pulse))
	o.draw_string(font, Vector2(x + dot_r * 2.0 + 6.0, cy + font.get_ascent(fs) * 0.5 - 1.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, room, fs, Color("#F1D9D9"))


func _draw_cover_chip(o: Control, rr: Rect2, value: int, trend: int, m: Dictionary) -> void:
	o.draw_rect(rr, Color(INK, 0.86))
	var c: Color = SynergyGlyphs.UP if trend > 0 else Color("#B9C2C9")
	o.draw_rect(rr, c, false, 1.5)
	var tex: Texture2D = IconSheet.get_icon(&"kw_cover") if IconSheet.has_icon(&"kw_cover") else null
	if tex != null:
		o.draw_texture_rect(tex, Rect2(rr.position + Vector2(1, 1), rr.size * 0.55), false, c)
	var font: Font = get_theme_font(&"font", &"HudNumber")
	var fs: int = maxi(11, int(rr.size.y * 0.62))
	var txt: String = str(value)
	var sz: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos: Vector2 = Vector2(rr.end.x - sz.x - 2.0, rr.end.y - font.get_descent(fs) - 1.0)
	o.draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, INK)
	o.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


func _draw_dog_tag(o: Control, rr: Rect2) -> void:
	var tag: Rect2 = Rect2(rr.position + Vector2(rr.size.x * 0.12, 0), Vector2(rr.size.x * 0.76, rr.size.y))
	o.draw_rect(tag, Color("#1B1608"))
	o.draw_rect(tag, BRASS, false, 1.5)
	o.draw_circle(tag.position + Vector2(tag.size.x * 0.5, tag.size.y * 0.2), tag.size.x * 0.1, BRASS)
	for i: int in 3:
		var y: float = tag.position.y + tag.size.y * (0.45 + i * 0.16)
		o.draw_line(Vector2(tag.position.x + 3, y), Vector2(tag.end.x - 3, y), Color(BRASS, 0.8), 1.0)


func _draw_tag(o: Control, text: String, c: Color, mine: bool, m: Dictionary) -> void:
	var font: Font = get_theme_font(&"font", &"HudHeader")
	var fs: int = maxi(11, int(m["number"]) - 4)
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var rr: Rect2 = Rect2(Vector2((size.x - sz.x) * 0.5 - 4.0, 0.0), Vector2(sz.x + 8.0, fs + 2.0))
	o.draw_rect(rr, c)
	o.draw_string(font, Vector2(rr.position.x + 4.0, rr.position.y + font.get_ascent(fs)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)


func _draw_reticle(o: Control, r: Rect2) -> void:
	var c: Color = _col(&"enemy") if side == &"enemy" else _col(&"friend")
	var rr: Rect2 = r.grow(-2.0)
	o.draw_rect(rr, c, false, 2.0)
	var l: float = minf(14.0, rr.size.y * 0.35)
	for corner: Vector2 in [rr.position, Vector2(rr.end.x, rr.position.y), rr.end, Vector2(rr.position.x, rr.end.y)]:
		var sx: float = 1.0 if corner.x == rr.position.x else -1.0
		var sy: float = 1.0 if corner.y == rr.position.y else -1.0
		o.draw_polyline(PackedVector2Array([corner + Vector2(0, sy * l), corner, corner + Vector2(sx * l, 0)]), c, 4.0)
	var ctr: Vector2 = rr.get_center()
	var rad: float = rr.size.y * 0.28
	o.draw_arc(ctr, rad, 0, TAU, 28, c, 2.0)
	o.draw_line(ctr - Vector2(rad * 1.5, 0), ctr - Vector2(rad * 0.5, 0), c, 2.0)
	o.draw_line(ctr + Vector2(rad * 0.5, 0), ctr + Vector2(rad * 1.5, 0), c, 2.0)


## A filled 5-point star (Elite mark).
static func draw_star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts: PackedVector2Array = []
	for i: int in 10:
		var a: float = -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	ci.draw_colored_polygon(pts, col)


static func _dashed_rect(o: Control, rr: Rect2, c: Color, w: float) -> void:
	var pts: Array[Vector2] = [rr.position, Vector2(rr.end.x, rr.position.y), rr.end, Vector2(rr.position.x, rr.end.y), rr.position]
	for i: int in 4:
		o.draw_dashed_line(pts[i], pts[i + 1], c, w, 6.0)

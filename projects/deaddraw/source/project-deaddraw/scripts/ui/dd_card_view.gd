# dd_card_view.gd
# Purpose: One tappable, inspectable card tile (street cards, weapon slot, deck counter, finale,
#   perks, survivors, unlocks). Left click / tap emits `tapped`; right click or a long press
#   (touch is emulated as the left mouse button) emits `inspected` with the zoom payload.
#   dd-feel: spec "art" (a Texture2D from dd_art.gd) shows the card art. Full tiles use the art
#   direction's frame (ART_LAYOUT "frame": the art fills the window, the number sits in an ink badge
#   in the art's quiet top-left corner, kind + name + preview in an ink name bar); compact tiles
#   put the art behind a scrim. Map nodes ("bg_art") show the district banner with a small finale
#   card. Without art the tile looks exactly as before. big_label / line_labels / art_rect are
#   exposed for the feedback animations.
# Dependencies: DDUi.
# Author: Mechanics Developer Agent
#   dd-polish5: every number sits in the same circle badge (dd_marks.gd NumBadge): spec "strength"
#   (a zombie: blood fill, tier ring), spec "hit" (a weapon: yellow fill), else the kind's accent.
class_name DDCardView
extends PanelContainer

const Marks: GDScript = preload("res://scripts/ui/dd_marks.gd")
const ArtFit: GDScript = preload("res://scripts/ui/dd_art.gd")

signal tapped(view: DDCardView)
signal inspected(payload: Dictionary)

const LONG_PRESS_MS: int = 450
const MOVE_CANCEL_PX: float = 28.0

## Zoom payload: {kind, tag, title, big, body}. See DDInspect.open().
var payload: Dictionary = {}
var kind: String = "D"
var index: int = -1

var _pressing: bool = false
var _long_fired: bool = false
var _press_ms: int = 0
var _press_pos: Vector2 = Vector2.ZERO
var _box: VBoxContainer
var _selected: bool = false
var _dim: bool = false
## dd-feel: nodes the feedback animations touch (null / empty when the spec has none).
var big_label: Label = null
var line_labels: Array[Label] = []
var art_rect: TextureRect = null
var has_art: bool = false
var _frame: bool = false
var _art_dim: bool = false
var _badge_panel: Control = null
var _corner_chip: Control = null
var _row: bool = false
## dd-art-fit: a street zombie the active gun can take (a rim and glow in the gun's yellow).
var _lit: bool = false
## dd-ui6: the rule chip under the number badge (street guns: the gun's own rule; dd-art-fit: no
## longer on zombies, which are lit / dark instead). Its own tile, so right click / long press on it explains it.
var rule_chip: DDCardView = null
## v2: the magazine pip bar (spec "pips": [rounds, magazine]), null when the tile has none.
var pip_bar: Pips = null
## dd-ux-v4: the strength mark / hit burst drawn on the art window (null when the tile has none).
var strength_mark: Control = null
var hit_burst: Control = null


## v2: a row of magazine pips: filled = rounds left, hollow = spent. Wraps into a second row
## when the magazine is long (Belt-fed MG).
class Pips:
	extends Control
	var filled: int = 0
	var total: int = 0
	var color: Color = Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _get_minimum_size() -> Vector2:
		return Vector2(0, 16 if total <= 12 else 30)

	func _draw() -> void:
		if total <= 0:
			return
		var per_row: int = total if total <= 12 else ceili(total / 2.0)
		var w: float = clampf((size.x - 4.0) / per_row - 3.0, 4.0, 14.0)
		var h: float = 12.0
		var row_w: float = per_row * (w + 3.0)
		for k: int in total:
			var rr: int = int(k / float(per_row))
			var cc: int = k % per_row
			var r: Rect2 = Rect2((size.x - row_w) * 0.5 + cc * (w + 3.0), 2.0 + rr * (h + 2.0), w, h)
			if k < filled:
				draw_rect(r, color)
			else:
				draw_rect(r, Color(color, 0.8), false, 1.5)

## dd-feel: how a non-compact tile with art is laid out. "frame" = art direction section 4 (number
## badge over full art, name bar below); anything else = the plain tile with the art behind a scrim.
const ART_LAYOUT: String = "frame"
const INK: Color = Color("151214")
const BONE: Color = Color("ece6d6")


## spec keys: kind, tag (top-left small), badge (top-right), badge_art (small icon before the badge,
## v2 Retrofit plate), pips ([rounds, magazine], v2 guns), big, title, lines: [[text, color]...],
## big_size, compact, selected, dim, payload.
## dd-feel art keys: art (Texture2D), art_fit ("cover" | "contain" for icons), art_dim (darken the
## art window to 45% while the number stays bright: the rules block part of the card's use, e.g. a
## zombie the weapon can't hit or a medkit that won't heal), holdover (corner tab), bg_art (Texture2D banner behind
## a "district" tile, which then shows `art` as a small finale card with the number badge).
func setup(spec: Dictionary) -> DDCardView:
	kind = str(spec.get("kind", "D"))
	payload = spec.get("payload", {})
	_selected = bool(spec.get("selected", false))
	_dim = bool(spec.get("dim", false))
	_art_dim = bool(spec.get("art_dim", false))
	_lit = bool(spec.get("lit", false))
	_row = bool(spec.get("row", false))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var compact: bool = bool(spec.get("compact", false))
	var art: Variant = spec.get("art", null)
	has_art = art is Texture2D
	if spec.get("bg_art", null) is Texture2D:
		has_art = true
		_frame = true
		_build_district(spec)
	elif bool(spec.get("row", false)):
		_build_row(spec, art if has_art else null)
	elif has_art and float(spec.get("art_side", 0.0)) > 0.0:
		_build_side(spec, art)
	elif has_art and not compact and ART_LAYOUT == "frame":
		_frame = true
		_build_framed(spec, art)
	else:
		_build_plain(spec, art if has_art else null, compact)
	_apply_style()
	DDUi.ignore_mouse(self)
	if rule_chip != null:
		rule_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = ""
	return self


## The original tile: tag row, big number, title, lines. With art (compact tiles): the art fills
## the tile under a scrim in the type colour and the text gets a dark outline.
func _build_plain(spec: Dictionary, art: Variant, compact: bool) -> void:
	if art != null:
		_add_art(self, art, "cover")
		var scrim: ColorRect = ColorRect.new()
		scrim.color = Color(DDUi.card_bg(kind), float(spec.get("art_tint", 0.55)))
		add_child(scrim)
	_box = DDUi.vbox(2 if compact else 4)
	add_child(_box)
	var top: HBoxContainer = DDUi.hbox(4)
	_box.add_child(top)
	var tag: String = str(spec.get("tag", ""))
	var tl: Label = DDUi.label(tag, DDUi.FONT_S - (2 if compact else 0), DDUi.accent(kind))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.clip_text = true
	top.add_child(tl)
	_add_badge(top, spec)
	var big: String = str(spec.get("big", ""))
	if big != "":
		var bl: Label = DDUi.label(big, int(spec.get("big_size", DDUi.BIG_NUMBER)), DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		bl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if art != null:
			_outline(bl, 12)
		big_label = bl
		_box.add_child(bl)
	var title: String = str(spec.get("title", ""))
	if title != "":
		var tsz: int = DDUi.FONT_M - (6 if compact else 0)
		var tt: Label = DDUi.label(title, tsz, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER, not bool(spec.get("title_fit", false)))
		if bool(spec.get("title_fit", false)):
			# dd-ux-clean: one line that shrinks to fit (boss names in a narrow column)
			tt.clip_text = true
			tt.custom_minimum_size = Vector2(10, 0)
			tt.resized.connect(func() -> void: fit_label(tt, tsz, 8))
		if art != null:
			_outline(tt, 6)
		_box.add_child(tt)
	_add_lines(_box, spec, art != null)


## v2 strip tile ("row": true): the big number on the left, tag / title / pips / lines stacked on
## the right. Used for the HUD (points, deck, Skipped pile, reserve, weapon slots, doors, waves) so
## the phone screen keeps room for the street. With art: the art sits behind a scrim.
func _build_row(spec: Dictionary, art: Variant) -> void:
	if art != null:
		_add_art(self, art, "cover")
		var scrim: ColorRect = ColorRect.new()
		scrim.color = Color(DDUi.card_bg(kind), float(spec.get("art_tint", 0.72)))
		add_child(scrim)
	var h: HBoxContainer = DDUi.hbox(8)
	add_child(h)
	_box = DDUi.vbox(0)
	var big: String = str(spec.get("big", ""))
	if big != "":
		var bl: Label = DDUi.label(big, int(spec.get("big_size", 30)), DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if art != null:
			_outline(bl, 8)
		big_label = bl
		h.add_child(bl)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(_box)
	var top: HBoxContainer = DDUi.hbox(4)
	_box.add_child(top)
	var tag: String = str(spec.get("tag", ""))
	if tag != "":
		var tl: Label = DDUi.label(tag, DDUi.FONT_S - 5, DDUi.accent(kind))
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.clip_text = true
		tl.resized.connect(func() -> void: fit_label(tl, DDUi.FONT_S - 5, 10))
		if art != null:
			_outline(tl, 5)
		top.add_child(tl)
	_add_badge(top, spec)
	var title: String = str(spec.get("title", ""))
	if title != "":
		var tsz: int = int(spec.get("title_size", DDUi.FONT_S - 1))
		var tt: Label = DDUi.label(title, tsz, DDUi.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
		tt.clip_text = true
		# dd-ux-clean: long names shrink to fit the strip instead of being cut
		tt.resized.connect(func() -> void: fit_label(tt, tsz, 11))
		if art != null:
			_outline(tt, 5)
		_box.add_child(tt)
	_add_lines(_box, spec, art != null, HORIZONTAL_ALIGNMENT_LEFT)


## dd-art-fit: a list row with the art as a square on the left (spec "art_side" = its side, px) and
## tag / title / lines on the right. Small square art (Patches) shows big enough to read in a row
## that stays short.
func _build_side(spec: Dictionary, art: Texture2D) -> void:
	var h: HBoxContainer = DDUi.hbox(10)
	add_child(h)
	var side: float = float(spec.get("art_side", 56.0))
	var tr: TextureRect = TextureRect.new()
	tr.name = "SideArt"
	tr.texture = art
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(side, side)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tr)
	art_rect = tr
	_box = DDUi.vbox(2)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(_box)
	var top: HBoxContainer = DDUi.hbox(6)
	_box.add_child(top)
	var tag: String = str(spec.get("tag", ""))
	if tag != "":
		var kl: Label = DDUi.label(tag.to_upper(), DDUi.FONT_S - 5, DDUi.accent(kind))
		kl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		top.add_child(kl)
	var title: String = str(spec.get("title", ""))
	if title != "":
		var tt: Label = DDUi.label(title, DDUi.FONT_S, BONE)
		tt.clip_text = true
		tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(tt)
		tt.resized.connect(func() -> void: fit_label(tt, DDUi.FONT_S, 10))
	_add_lines(_box, spec, false, HORIZONTAL_ALIGNMENT_LEFT)


## Art direction section 4: the art fills the window, the number sits in an ink badge in the art's
## quiet top-left corner, kind + name + preview live in an ink name bar under the art.
func _build_framed(spec: Dictionary, art: Texture2D) -> void:
	_box = DDUi.vbox(0)
	add_child(_box)
	var window: Control = Control.new()
	window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	window.custom_minimum_size = Vector2(0, 40)
	window.clip_contents = true
	_box.add_child(window)
	# dd-ux-clean2: big tiles (the boss street's two cards) scale their text with them
	var ts: float = float(spec.get("text_scale", 1.0))
	var fit: String = str(spec.get("art_fit", "cover"))
	if fit == "contain":
		var under: ColorRect = ColorRect.new()
		under.color = DDUi.card_bg(kind)
		under.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		window.add_child(under)
	var tr: TextureRect = _add_art(window, art, fit)
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if bool(spec.get("art_dim", false)):
		tr.self_modulate = Color(0.45, 0.45, 0.45)
	var big: String = str(spec.get("big", ""))
	if spec.has("strength") or spec.has("hit") or big != "":
		# dd-polish5: one circle badge for every card number (zombie strength, weapon hit, item
		# value); only its colours differ (dd_marks.gd NumBadge)
		_badge_panel = _number_badge(big, spec)
		window.add_child(_badge_panel)
		# dd-ux-clean2: the art window can settle after the tile (tall tiles); refit then too
		window.resized.connect(func() -> void: _fit_badge.call_deferred())
	var rc: Variant = spec.get("rule_chip", null)
	if rc is Dictionary and _badge_panel != null:
		_add_rule_chip(window, rc)
	var badge: String = str(spec.get("badge", ""))
	if badge != "" or bool(spec.get("holdover", false)):
		var bcol: Color = Color(spec.get("badge_color", DDUi.WARN)) if badge != "" else DDUi.TEXT
		var chip: PanelContainer = DDUi.tag(badge if badge != "" else "HOLDOVER", tag_color(bcol), roundi(int(spec.get("badge_size", DDUi.FONT_S - 5)) * ts), bcol)
		window.add_child(chip)
		window.resized.connect(func() -> void:
			if is_instance_valid(chip):
				chip.size = chip.get_combined_minimum_size()
				chip.position = Vector2(window.size.x - chip.size.x - 4.0, 4.0))
		_corner_chip = chip
	var bar: PanelContainer = DDUi.panel(INK, 5)
	var bst: StyleBoxFlat = DDUi.box(INK, Color(0, 0, 0, 0), 0, 0, 5)
	bst.corner_radius_bottom_left = 10
	bst.corner_radius_bottom_right = 10
	bar.add_theme_stylebox_override("panel", bst)
	# dd-art2-import: the painted name strip (ink tape with bolts) when it exists
	var pst: StyleBox = DDUi.Kit.box("dd_bar_name", 5.0)
	if pst != null:
		pst.content_margin_left = 8.0
		pst.content_margin_right = 8.0
		bar.add_theme_stylebox_override("panel", pst)
	_box.add_child(bar)
	var bv: VBoxContainer = DDUi.vbox(0)
	bar.add_child(bv)
	var name_row: HBoxContainer = DDUi.hbox(6)
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_child(name_row)
	var tag: String = str(spec.get("tag", ""))
	if tag != "":
		var kl: Label = DDUi.label(tag.to_upper(), roundi((DDUi.FONT_S - 5) * ts), DDUi.accent(kind))
		kl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		name_row.add_child(kl)
	var title: String = str(spec.get("title", ""))
	if title != "":
		var tsz: int = roundi(DDUi.FONT_S * ts)
		var tt: Label = DDUi.label(title, tsz, BONE)
		tt.clip_text = true
		tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if tag == "" else HORIZONTAL_ALIGNMENT_LEFT
		name_row.add_child(tt)
		# v3: long names on narrow cards shrink to fit instead of being cut ("Shambler")
		tt.resized.connect(func() -> void: fit_label(tt, tsz, 10))
	_add_lines(bv, spec, false)


## Map node: the district banner as the background, a small finale card (art + number badge) on
## the left, the text on the right.
func _build_district(spec: Dictionary) -> void:
	_add_art(self, spec["bg_art"], "cover")
	var scrim: ColorRect = ColorRect.new()
	# dd-art-import: the painted banners are busier than the old flat ones; a darker scrim keeps the names readable
	scrim.color = Color(INK, 0.58)
	add_child(scrim)
	var h: HBoxContainer = DDUi.hbox(10)
	add_child(h)
	var art: Variant = spec.get("art", null)
	if art is Texture2D:
		var mini: PanelContainer = PanelContainer.new()
		var st: StyleBoxFlat = DDUi.box(DDUi.card_bg(kind), DDUi.accent(kind), 3, 10, 0)
		mini.add_theme_stylebox_override("panel", st)
		if DDUi.Kit.rim(mini, DDUi.accent(kind), false, true) != null:
			mini.add_theme_stylebox_override("panel", DDUi.Kit.card_body(DDUi.card_bg(kind), 0.0, 10.0))
		mini.custom_minimum_size = Vector2(108, 0)
		h.add_child(mini)
		var window: Control = Control.new()
		window.clip_contents = true
		mini.add_child(window)
		var tr: TextureRect = _add_art(window, art, "cover")
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var big: String = str(spec.get("big", ""))
		if big != "":
			_badge_panel = _number_badge(big, spec)
			window.add_child(_badge_panel)
	_box = DDUi.vbox(2)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_box)
	var top: HBoxContainer = DDUi.hbox(4)
	_box.add_child(top)
	# dd-polish: long district names ("St. Agnes Hospital") wrap instead of being cut off
	var tl: Label = DDUi.label(str(spec.get("tag", "")), DDUi.FONT_S, DDUi.accent(kind), HORIZONTAL_ALIGNMENT_LEFT, true)
	_outline(tl, 6)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tl)
	_add_badge(top, spec)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(spacer)
	var tt: Label = DDUi.label(str(spec.get("title", "")), DDUi.FONT_M, BONE, HORIZONTAL_ALIGNMENT_LEFT, true)
	_outline(tt, 6)
	_box.add_child(tt)
	# dd-polish5: wrap between words only ("Groundskeepe / r" at 1440x900): shrink until the
	# longest word fits the line
	tl.resized.connect(func() -> void: fit_words(tl, DDUi.FONT_S, 11))
	tt.resized.connect(func() -> void: fit_words(tt, DDUi.FONT_M, 12))
	_add_lines(_box, spec, true, HORIZONTAL_ALIGNMENT_LEFT)


## dd-ui6: the rule chip: a small tile (kind "W", index -1, so finders of street cards skip it)
## holding a Marks.RuleChip. A tap on it is a tap on the card; inspect explains the verdict.
func _add_rule_chip(window: Control, rc: Dictionary) -> void:
	var holder: DDCardView = DDCardView.new()
	holder.kind = "W"
	holder.name = "RuleChip"
	holder.payload = rc.get("payload", {})
	holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var mark: Control = Marks.RuleChip.new(rc.get("tex", null), int(rc.get("state", -1)))
	mark.name = "Glyph"
	holder.add_child(mark)
	holder.set_meta(&"state", int(rc.get("state", -1)))
	holder.tapped.connect(func(_v: DDCardView) -> void: tapped.emit(self))
	holder.inspected.connect(func(p: Dictionary) -> void: inspected.emit(p))
	window.add_child(holder)
	rule_chip = holder


func _add_art(parent: Control, tex: Texture2D, fit: String) -> TextureRect:
	# dd-art-fit: cover art crops around the painting's subject (the manifest's focus box)
	var tr: TextureRect = ArtFit.cover_rect(tex) if fit != "contain" else TextureRect.new()
	if fit == "contain":
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2.ZERO
	parent.add_child(tr)
	if art_rect == null:
		art_rect = tr
	return tr


func _add_badge(row: HBoxContainer, spec: Dictionary) -> void:
	var ba: Variant = spec.get("badge_art", null)
	if ba is Texture2D:
		var tr: TextureRect = TextureRect.new()
		tr.texture = ba
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(26, 26)
		row.add_child(tr)
	var badge: String = str(spec.get("badge", ""))
	var col: Color = Color(spec.get("badge_color", DDUi.WARN))
	if badge == "" and bool(spec.get("holdover", false)):
		badge = "HOLDOVER"
		col = DDUi.TEXT_DIM
	if badge != "":
		var bp: PanelContainer = DDUi.tag(badge, tag_color(col), DDUi.FONT_S - 3, col)
		bp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bp)


func _add_lines(parent: Container, spec: Dictionary, outline: bool, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var pips: Variant = spec.get("pips", null)
	if pips is Array and (pips as Array).size() == 2:
		var bar: Pips = Pips.new()
		bar.filled = int(pips[0])
		bar.total = int(pips[1])
		bar.color = DDUi.accent(kind)
		pip_bar = bar
		parent.add_child(bar)
	var ts: float = float(spec.get("text_scale", 1.0))
	for ln: Variant in spec.get("lines", []):
		var arr: Array = ln
		var l: Label = DDUi.label(str(arr[0]), roundi((int(arr[2]) if arr.size() > 2 else DDUi.FONT_S) * ts), arr[1] if arr.size() > 1 else DDUi.TEXT_DIM, align, true)
		if outline:
			_outline(l, 6)
		line_labels.append(l)
		parent.add_child(l)


## Ink disc (a pill for long numbers like "9/11") with a 3 px type-accent ring and bone numerals.
## Sized to ~30% of the tile width in _fit_badge().
## dd-polish5: the card's number badge (dd_marks.gd NumBadge): spec "strength" = a zombie (blood
## fill, tier ring), spec "hit" = a weapon (yellow fill), else the kind's accent ring on ink.
func _number_badge(text: String, spec: Dictionary = {}) -> Control:
	var b: Control = null
	if spec.has("strength"):
		b = Marks.NumBadge.new(int(spec["strength"]), "zombie", Marks.BONE, text)
		strength_mark = b
	elif spec.has("hit"):
		b = Marks.HitBurst.new(int(spec["hit"]))
		hit_burst = b
	else:
		b = Marks.NumBadge.new(int(text) if text.is_valid_int() else 0, "item", DDUi.accent(kind), text)
	b.name = "NumBadge"
	b.position = Vector2(6, 6)
	big_label = b.get("num_label")
	return b


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _badge_panel != null:
		_fit_badge.call_deferred()


func _fit_badge() -> void:
	if _badge_panel == null or not is_instance_valid(_badge_panel):
		return
	var host: Control = _badge_panel.get_parent() as Control
	var d: float = clampf(size.x * 0.3, 34.0, 96.0)
	if host != null and host.size.y > 0.0:
		d = minf(d, maxf(30.0, host.size.y - 12.0))
	if host != null and host.size.x > 0.0 and host != _box:
		d = minf(d, host.size.x * 0.5)
	var w: float = float(_badge_panel.call("width_for", d))
	if host != null and host.size.x > 0.0 and w > host.size.x - 12.0:
		# a long number (a boss's "6×3") shrinks to fit its window
		d = maxf(20.0, d * (host.size.x - 12.0) / w)
		w = float(_badge_panel.call("width_for", d))
	_badge_panel.custom_minimum_size = Vector2(w, d)
	_badge_panel.size = Vector2(w, d)
	_badge_panel.position = Vector2(6, 6)
	_badge_panel.pivot_offset = _badge_panel.size * 0.5
	if rule_chip != null and is_instance_valid(rule_chip):
		# dd-ui6: the rule chip sits under the number badge (beside it when the window is short)
		var c: float = clampf(d * 0.62, 26.0, 48.0)
		var hy: float = host.size.y if host != null else size.y
		if 6.0 + d + 4.0 + c <= hy - 4.0:
			rule_chip.position = Vector2(6.0 + (w - c) * 0.5, 6.0 + d + 4.0)
		else:
			rule_chip.position = Vector2(6.0 + w + 4.0, 6.0 + (d - c) * 0.5)
		rule_chip.size = Vector2(c, c)
		var g: Control = rule_chip.get_node_or_null(^"Glyph")
		if g != null:
			g.position = Vector2.ZERO
			g.size = Vector2(c, c)


## Shrinks a wrapping label's font (down to `min_size`) until its longest word fits one line.
static func fit_words(l: Label, base: int, min_size: int) -> void:
	if l == null or not is_instance_valid(l) or l.size.x <= 0.0:
		return
	var font: Font = l.get_theme_font("font")
	var fs: int = base
	var words: PackedStringArray = l.text.split(" ", false)
	var widest: Callable = func(sz: int) -> float:
		var m: float = 0.0
		for wd: String in words:
			m = maxf(m, font.get_string_size(wd, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x)
		return m
	while fs > min_size and float(widest.call(fs)) > l.size.x - 2.0:
		fs -= 1
	if l.get_theme_font_size("font_size") != fs:
		l.add_theme_font_size_override("font_size", fs)


## Shrinks a one-line label's font (down to `min_size`) until its text fits its width.
static func fit_label(l: Label, base: int, min_size: int) -> void:
	if l == null or not is_instance_valid(l) or l.size.x <= 0.0:
		return
	l.set_meta(&"fit_base", base)
	var font: Font = l.get_theme_font("font")
	var fs: int = base
	while fs > min_size and font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > l.size.x:
		fs -= 1
	if l.get_theme_font_size("font_size") != fs:
		l.add_theme_font_size_override("font_size", fs)


func _outline(l: Label, px: int) -> void:
	l.add_theme_constant_override("outline_size", px)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.04, 0.92))


## dd-art2-import: the painted tag colour for an old chip colour (red damage, yellow notes, bone ACTIVE...).
static func tag_color(c: Color) -> String:
	if c.r > 0.75 and c.g < 0.5:
		return "red"
	if c.r > 0.6 and c.b < 0.5 and c.g > 0.5:
		return "yellow"
	if c.b > c.g and c.r > c.g:
		return "boss"
	return "bone"


func set_selected(v: bool) -> void:
	_selected = v
	_apply_style()


func _apply_style() -> void:
	var bg: Color = DDUi.card_bg(kind)
	if _art_dim and not has_art:
		bg = bg.darkened(0.45)
	var border: Color = DDUi.SELECT if _selected else DDUi.accent(kind)
	var pad: int = 10 if not _frame else 3
	if _row:
		pad = 6
	var st: StyleBoxFlat = DDUi.box(bg, border, 5 if _selected else (3 if _frame else 2), 14 if not _frame else 12, pad)
	if _selected:
		st.shadow_color = Color(DDUi.SELECT, 0.35)
		st.shadow_size = 10
	elif _lit:
		st.border_color = DDUi.WARN
		st.set_border_width_all(3)
		st.shadow_color = Color(DDUi.WARN, 0.32)
		st.shadow_size = 7
	# dd-art2-import: the painted rim (tinted to the type, gold when selected) over the content; the
	# flat box keeps only the body colour (and the selected / lit glow)
	var rim_tint: Color = DDUi.SELECT if (_lit and not _selected) else DDUi.accent(kind).lightened(0.3)
	if DDUi.Kit.rim(self, rim_tint, _selected, _row) != null:
		st.border_color = Color(0, 0, 0, 0)
		st.set_border_width_all(0)
		st.expand_margin_left = -2.0
		st.expand_margin_right = -2.0
		st.expand_margin_top = -2.0
		st.expand_margin_bottom = -2.0
	add_theme_stylebox_override("panel", st)
	modulate = Color(1, 1, 1, 0.55) if _dim else Color(1, 1, 1, 1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_pressing = false
			_open_inspect()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_long_fired = false
				_press_ms = Time.get_ticks_msec()
				_press_pos = mb.position
				set_process(true)
			else:
				if _pressing and not _long_fired:
					tapped.emit(self)
				_pressing = false
				set_process(false)
			accept_event()
	elif event is InputEventMouseMotion and _pressing:
		if (event as InputEventMouseMotion).position.distance_to(_press_pos) > MOVE_CANCEL_PX:
			_pressing = false


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	if _pressing and not _long_fired and Time.get_ticks_msec() - _press_ms >= LONG_PRESS_MS:
		_long_fired = true
		_pressing = false
		set_process(false)
		_open_inspect()


func _open_inspect() -> void:
	if not payload.is_empty():
		inspected.emit(payload)

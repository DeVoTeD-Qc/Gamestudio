# hand_area.gd
# Purpose: The hand (kc-board, board-and-cards-ux.md §3.4, option A approved). kc-board2
#   (board-layout-v2.md): a grid in the side tray (phone 3 columns of 104x130, desktop 2 of 108x136;
#   BoardMetrics), filled left to right, top to bottom, newest last; past the grid's rows the rows
#   overlap upward. The selected card shifts 14 px toward the board (a rise would cover the card
#   above). read_only (the tray's PEEK outside Deploy): a tap inspects instead of selecting, no drag.
#   Each card: an art window on top (the art's 2:3 hand column, BannerArtDB.portrait_texture, cropped
#   to fill), the cost hex over its top-left corner, the chassis name on one line (ellipsis: the full
#   name is one long-press away), and a bottom row: units show Firepower, up to 2 keyword glyphs and
#   Armor; tactics show TACTIC and a bolt; Fields show FIELD and a stake. Phone cards are 78x98,
#   desktop 108x140 (BoardMetrics), 7 fit side by side; more overlap so the row never widens.
#   A card you can't afford is greyed. The selected card animates its art (shimmer).
#   kc-cod2: licensed MW3 art (private pitch only) shows its whole 4:1 strip instead of the 2:3 crop.
#   Input (p09): each card runs a PressGesture: tap = select, drag = drag to a column,
#   long-press / right-click = inspect. The hand only reports gestures with the card's rules uid;
#   match_controller.gd decides what they mean.
#   kc-ui3 (head: "we still need to see our operator card close to hand since we can deploy it"): the
#   OPERATOR card sits first in the grid (set_operator). While it can deploy it is a full card with an
#   amber glow and a DEPLOY tag (tap = select, drag = drag to a column, as any card); placed this
#   Deploy it reads PLAN · B; on the board it dims to a status card ("ON BOARD" / "B · ROW 2", tap =
#   select to Rotate); down it reads "DOWN" / "BACK NEXT ROUND". Long-press = the Operator's rules.
#   It reports operator_* signals; get_cards() never includes it (hand cards only).
# Dependencies: hud_theme.tres variations (HandCard, HandCardSelected, HandCardDim, UnitName,
#   HudNumber, HudTag), press_gesture.gd, cost_hex.gd, icon_sheet.gd, BannerArtDB.
# Author: UI/UX Agent (p08-f04), Mechanics Developer Agent (kc-board: option A cards)
extends PanelContainer

signal card_tapped(uid: int)
signal card_inspected(uid: int)
signal card_drag_started(uid: int, pos: Vector2)
signal card_drag_moved(uid: int, pos: Vector2)
signal card_drag_ended(uid: int, pos: Vector2)
## kc-ui3: the Operator card at the start of the tray.
signal operator_tapped
signal operator_inspected
signal operator_drag_started(pos: Vector2)
signal operator_drag_moved(pos: Vector2)
signal operator_drag_ended(pos: Vector2)

const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
const MiniIcons: GDScript = preload("res://scripts/ui/mini_icons.gd")
const CostHex: GDScript = preload("res://scripts/ui/cost_hex.gd")

## Desktop / phone card size (board-and-cards-ux.md §3.4); set_card_size() follows BoardMetrics.
const CARD_SIZE: Vector2 = Vector2(108, 140)
const CARD_SIZE_COMPACT: Vector2 = Vector2(78, 98)
const CARD_GAP: int = 8
const SHIMMER: Shader = preload("res://assets/shaders/banner_shimmer.gdshader")
## kc-board2 §4.2: the selected card shifts this far toward the board.
const SELECTED_SHIFT: float = 14.0
## f04 icon sizes and cost hex (pointy-top, as on CardView).
const ICON_PX: float = 20.0
const ICON_PX_COMPACT: float = 18.0
const HEX_SIZE: Vector2 = Vector2(28, 32)
const HEX_SIZE_COMPACT: Vector2 = Vector2(24, 28)
const HAND_CAP: int = 7
## k-art4: plate behind FP / Armor over the art.
static var STAT_PLATE: StyleBoxFlat = ArtUnderlay.plate()

var compact: bool = false
var _card_size_override: Vector2 = Vector2.ZERO
var _gap: float = CARD_GAP
var _cards_data: Array = []
## Grid columns (BoardMetrics hand_cols) and the side the board is on (-1 left, +1 right).
var columns: int = 3
var board_side: float = -1.0
## PEEK: cards can be inspected, not played (tap = inspect, no drag).
var read_only: bool = false
## Rules uid of the selected card, -1 = none.
var selected_uid: int = -1
## uid of the card being dragged (its chip is hidden while the ghost follows the pointer).
var dragging_uid: int = -1
## kc-ui3: the Operator card's entry ({} = no Operator card): {name, fp, armor, armor_max, banner,
## state (&"deploy" / &"planned" / &"board" / &"down" / &"none"), status (tag text), keywords, active}.
var operator_entry: Dictionary = {}
var operator_selected: bool = false
var _op_chip: Control = null
## Uid meta of the Operator chip (never a rules card uid).
const OPERATOR_UID: int = -2
const AMBER: Color = Color(0.961, 0.722, 0.239)

@onready var _caption: Label = %CaptionLabel
@onready var _row: Control = %CardRow


func _ready() -> void:
	# kc-board: the cards sit straight under the board (no panel behind the row).
	add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	_caption.visible = false
	_row.resized.connect(_fit_cards)


func set_compact(value: bool) -> void:
	_caption.visible = false
	if value == compact:
		return
	compact = value
	set_hand(_cards_data)


## Card size, gap and grid columns from BoardMetrics; board_dir -1: the board is to the left.
func set_card_size(card: Vector2, gap: float, cols: int = columns, board_dir: float = board_side) -> void:
	_caption.visible = false
	if card == _card_size_override and gap == _gap and cols == columns and board_dir == board_side:
		return
	var rebuild: bool = card != _card_size_override
	_card_size_override = card
	_gap = gap
	columns = maxi(1, cols)
	board_side = board_dir
	if rebuild:
		set_hand(_cards_data)
	else:
		_fit_cards()


func set_read_only(value: bool) -> void:
	read_only = value
	for chip: Node in get_cards():
		var tag: Control = chip.find_child("NextTag", true, false) as Control
		if tag != null:
			tag.visible = value


## cards: Array of {name, type, cost, fp?, armor?, text, card_type?, weapon_class?, keywords?, elite?}
## (card_info.gd chip()).
func set_hand(cards: Array) -> void:
	_cards_data = cards
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_op_chip = null
	if not operator_entry.is_empty():
		_op_chip = _make_operator_card(operator_entry)
		_row.add_child(_op_chip)
	for card: Dictionary in cards:
		var chip: Control = _make_card(card)
		_wire(chip, int(card.get("uid", -1)))
		_row.add_child(chip)
	_apply_styles()
	_caption.text = "HAND %d/%d" % [cards.size(), HAND_CAP]
	_fit_cards.call_deferred()


func get_cards() -> Array[Node]:
	var out: Array[Node] = _row.get_children()
	if _op_chip != null:
		out.erase(_op_chip)
	return out


## kc-ui3: stores the Operator card's entry (shown first from the next set_hand(); {} = none).
func set_operator(entry: Dictionary) -> void:
	operator_entry = entry


## The Operator card at the start of the tray, or null.
func get_operator_card() -> Control:
	return _op_chip


## The Operator is selected (it takes the selected style and shifts toward the board).
func set_operator_selected(on: bool) -> void:
	if on == operator_selected:
		return
	operator_selected = on
	_apply_styles()
	_fit_cards()


## The chip showing the card with this rules uid, or null.
func get_card(uid: int) -> Control:
	for chip: Node in get_cards():
		if int(chip.get_meta(&"uid", -1)) == uid:
			return chip
	return null


func set_selected(uid: int) -> void:
	var changed: bool = uid != selected_uid
	selected_uid = uid
	_apply_styles()
	if changed:
		_fit_cards()


## Hides the chip being dragged (-1 shows all again).
func set_dragging(uid: int) -> void:
	dragging_uid = uid
	_apply_styles()


func _apply_styles() -> void:
	_style_operator()
	for chip: Node in get_cards():
		var uid: int = int(chip.get_meta(&"uid", -1))
		var playable: bool = bool(chip.get_meta(&"playable", true))
		var variation: StringName = &"HandCard" if playable else &"HandCardDim"
		if uid == selected_uid and uid >= 0:
			variation = &"HandCardSelected"
		(chip as Control).theme_type_variation = variation
		# Unaffordable chips fade so the playable ones stand out; the dragged one fades more.
		var alpha: float = 1.0 if playable or uid == selected_uid else 0.55
		(chip as Control).modulate.a = 0.35 if uid == dragging_uid and uid >= 0 else alpha
		# Can't afford it: greyscale-ish, 60% brightness (§3.4).
		(chip as Control).self_modulate = Color.WHITE
		var art: TextureRect = chip.find_child("Art", true, false) as TextureRect
		if art != null:
			art.self_modulate = Color(0.6, 0.6, 0.6) if not playable and uid != selected_uid else Color.WHITE
			var on: bool = uid == selected_uid and uid >= 0
			if on and art.material == null:
				var mat := ShaderMaterial.new()
				mat.shader = SHIMMER
				mat.set_shader_parameter(&"start_time", Time.get_ticks_msec() / 1000.0)
				art.material = mat
			elif not on:
				art.material = null


func _wire(chip: Control, uid: int) -> void:
	chip.set_meta(&"uid", uid)
	var g: RefCounted = PressGesture.new(chip)
	chip.set_meta(&"gesture", g)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.gui_input.connect(func(e: InputEvent) -> void:
		if g.handle(e):
			chip.accept_event())
	g.tapped.connect(func(_p: Vector2) -> void:
		if read_only:
			card_inspected.emit(uid)
		else:
			card_tapped.emit(uid))
	g.long_pressed.connect(func(_p: Vector2) -> void: card_inspected.emit(uid))
	g.drag_started.connect(func(p: Vector2) -> void:
		if not read_only:
			card_drag_started.emit(uid, p))
	g.drag_moved.connect(func(p: Vector2) -> void:
		if not read_only:
			card_drag_moved.emit(uid, p))
	g.drag_ended.connect(func(p: Vector2) -> void:
		if not read_only:
			card_drag_ended.emit(uid, p))


## Labels whose whole text must stay visible (cost, name, stats; the rules line may trim).
func get_important_labels() -> Array[Label]:
	var out: Array[Label] = []
	for card: Node in _row.get_children():
		for label: Node in card.find_children("*", "Label", true, false):
			if label.has_meta(&"important"):
				out.append(label)
	return out


func _card_size() -> Vector2:
	if _card_size_override != Vector2.ZERO:
		return _card_size_override
	return CARD_SIZE_COMPACT if compact else CARD_SIZE


func _fit_cards() -> void:
	var cards: Array[Node] = _row.get_children()
	var n: int = cards.size()
	var card_size: Vector2 = _card_size()
	_row.custom_minimum_size = Vector2(card_size.x, card_size.y)
	if n == 0:
		return
	var cols: int = maxi(1, columns)
	var rows: int = ceili(float(n) / cols)
	var pitch_x: float = card_size.x + _gap
	var pitch_y: float = card_size.y + _gap
	if rows > 1:
		# More cards than the grid holds: the rows overlap upward (the step shrinks).
		pitch_y = minf(pitch_y, (_row.size.y - card_size.y) / (rows - 1))
	var grid_w: float = card_size.x + pitch_x * (cols - 1)
	var x0: float = maxf(0.0, (_row.size.x - grid_w) * 0.5)
	for i: int in n:
		var c: Control = cards[i]
		c.size = card_size
		var x: float = x0 + (i % cols) * pitch_x
		# kc-board2 §4.2: the selected card shifts 14 px toward the board.
		if (int(c.get_meta(&"uid", -1)) == selected_uid and selected_uid >= 0) or (c == _op_chip and operator_selected):
			x += SELECTED_SHIFT * board_side
		c.position = Vector2(roundf(x), roundf((i / cols) * pitch_y))


func _make_card(card: Dictionary) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"HandCard"
	panel.custom_minimum_size = _card_size()
	panel.add_to_group(&"tap_target")
	panel.set_meta(&"playable", bool(card.get("playable", true)))
	panel.tooltip_text = String(card.get("name", ""))
	var ctype: String = MiniIcons.card_type(card)
	# The face ignores the panel's content margins: it is placed over the whole card (fit below).
	var face: Control = Control.new()
	face.name = "Face"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.clip_contents = true
	panel.add_child(face)
	var big: bool = _card_size().x >= 100.0
	var art_h: float = roundf(_card_size().y * (82.0 / 140.0 if big else 56.0 / 98.0))
	var art := TextureRect.new()
	art.name = "Art"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_id: StringName = StringName(String(card.get("banner", card.get("id", ""))))
	art.texture = BannerArtDB.portrait_texture(art_id, {"cls": card.get("type", ""), "type": ctype}) if art_id != &"" else null
	# kc-cod2: licensed art (private pitch) is a 4:1 strip with no room for a 2:3 crop, so the card
	# shows the WHOLE strip at the bottom of its art window over a dimmed, cover-cropped copy of it.
	var strip: bool = art_id != &"" and BannerArtDB.get_art(art_id).licensed and art.texture != null
	if strip:
		var back := TextureRect.new()
		back.name = "ArtBack"
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.texture = art.texture
		back.self_modulate = Color(0.42, 0.42, 0.45, 1.0)
		face.add_child(back)
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.set_meta(&"strip", back)
	face.add_child(art)
	var hex: Control = CostHex.new()
	hex.custom_minimum_size = HEX_SIZE if big else HEX_SIZE_COMPACT
	hex.size = hex.custom_minimum_size
	hex.label.add_theme_font_size_override(&"font_size", 20 if big else 16)
	hex.set_text(str(card.get("cost", 0)))
	hex.label.set_meta(&"important", true)
	face.add_child(hex)
	if bool(card.get("elite", false)):
		# Elite (Commander / Ace): gold star over the art's top-right corner.
		var star: Control = Control.new()
		star.name = "EliteStar"
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.custom_minimum_size = Vector2(18, 18) if not big else Vector2(22, 22)
		star.size = star.custom_minimum_size
		star.draw.connect(func() -> void:
			star.draw_circle(star.size * 0.5, star.size.x * 0.5, Color(0.05, 0.06, 0.07, 0.85))
			BannerView.draw_star(star, star.size * 0.5, star.size.x * 0.4, get_theme_color(&"elite", &"Hud")))
		face.add_child(star)
		panel.sort_children.connect(func() -> void: star.position = Vector2(face.size.x - star.size.x - 2.0, 2.0))
	var next_tag: Label = _label("NEXT DEPLOY", &"HudTag", false)
	next_tag.name = "NextTag"
	next_tag.add_theme_font_size_override(&"font_size", 16)
	next_tag.visible = read_only
	var tag_box := StyleBoxFlat.new()
	tag_box.bg_color = Color(0.05, 0.06, 0.07, 0.85)
	tag_box.set_content_margin_all(2)
	next_tag.add_theme_stylebox_override(&"normal", tag_box)
	next_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_tag.clip_text = true
	var title: Label = _label(String(card.get("name", "")), &"UnitName", false)
	title.name = "NameLabel"
	title.add_theme_font_size_override(&"font_size", 16)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	face.add_child(title)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.name = "Bottom"
	bottom.add_theme_constant_override(&"separation", 2)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(bottom)
	var text_color: Color = get_theme_color(&"text", &"Hud")
	var accent: Color = get_theme_color(&"accent", &"Hud")
	var icon_px: float = 16.0 if big else 14.0
	if card.has("fp"):
		bottom.add_child(MiniIcons.icon(&"stat_firepower", icon_px, text_color))
		bottom.add_child(_number(str(card.get("fp", 0)), big))
		var mid: HBoxContainer = MiniIcons.keyword_row((card.get("keywords", []) as Array).slice(0, 2), icon_px, accent, false)
		for c: Node in mid.get_children():
			if c is Label:
				(c as Label).add_theme_font_size_override(&"font_size", 16)
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.alignment = BoxContainer.ALIGNMENT_CENTER
		bottom.add_child(mid)
		bottom.add_child(MiniIcons.icon(&"stat_armor", icon_px, text_color))
		bottom.add_child(_number(str(card.get("armor", 0)), big))
	else:
		var word: Label = _label("FIELD" if ctype == "equipment" else "TACTIC", &"HudTag", false)
		word.add_theme_color_override(&"font_color", accent)
		word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom.add_child(word)
		var glyph: Control = Control.new()
		glyph.custom_minimum_size = Vector2(icon_px, icon_px)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.draw.connect(_draw_type_glyph.bind(glyph, ctype == "equipment", accent))
		bottom.add_child(glyph)
	face.add_child(next_tag)
	panel.sort_children.connect(func() -> void:
		next_tag.size = Vector2(face.size.x, next_tag.get_combined_minimum_size().y)
		next_tag.position = Vector2(0, art_h * 0.5 - next_tag.size.y * 0.5))
	panel.sort_children.connect(_fit_face.bind(panel, face, art, hex, title, bottom, art_h))
	return panel


# =============================================================================
# kc-ui3: the Operator card
# =============================================================================

func _make_operator_card(op: Dictionary) -> Control:
	var state: StringName = StringName(String(op.get("state", "none")))
	var card: Dictionary = {"name": op.get("name", "Operator"), "type": "OPERATOR", "cost": 0,
			"fp": op.get("fp", 0), "armor": op.get("armor", 0), "keywords": op.get("keywords", []),
			"banner": op.get("banner", ""), "id": op.get("banner", ""), "playable": true}
	var panel: Control = _make_card(card)
	panel.name = "OperatorCard"
	panel.set_meta(&"uid", OPERATOR_UID)
	panel.set_meta(&"operator", true)
	panel.tooltip_text = "Your Operator: %s" % String(op.get("name", ""))
	var next_tag: Node = panel.find_child("NextTag", true, false)
	if next_tag != null:
		(next_tag as Control).visible = false
	# No cost: the hex reads OP.
	for hex: Node in panel.find_children("*", "", true, false):
		if hex is CostHex:
			(hex as CostHex).set_text("OP")
			(hex as CostHex).label.add_theme_font_size_override(&"font_size", 16)
	var armor_text: String = "%d/%d" % [int(op.get("armor", 0)), int(op.get("armor_max", op.get("armor", 0)))]
	var bottom: Node = panel.find_child("Bottom", true, false)
	if bottom != null and bottom.get_child_count() > 0:
		var last: Node = bottom.get_child(bottom.get_child_count() - 1)
		if last is Label:
			(last as Label).text = armor_text
	# Status plate over the art: DEPLOY / PLAN · B / ON BOARD + B · ROW 2 / DOWN + BACK NEXT ROUND.
	var status: Label = _label(String(op.get("status", "")), &"HudTag", true)
	status.name = "OperatorStatus"
	status.add_theme_font_size_override(&"font_size", 16)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.05, 0.06, 0.07, 0.86)
	plate.set_content_margin_all(2)
	if state == &"deploy":
		plate.bg_color = AMBER
		status.add_theme_color_override(&"font_color", Color(0.07, 0.08, 0.1))
	elif state == &"down":
		status.add_theme_color_override(&"font_color", get_theme_color(&"enemy", &"Hud"))
	else:
		status.add_theme_color_override(&"font_color", get_theme_color(&"friend", &"Hud"))
	status.add_theme_stylebox_override(&"normal", plate)
	status.visible = status.text != ""
	var face: Control = panel.get_node("Face")
	face.add_child(status)
	# Under the OP hex and the name (they stay readable), over the art.
	var art_node: Node = face.get_node_or_null("Art")
	if art_node != null:
		face.move_child(status, art_node.get_index() + 1)
	panel.sort_children.connect(func() -> void:
		var h: float = status.get_combined_minimum_size().y
		status.size = Vector2(face.size.x, h)
		var art: Control = face.get_node_or_null("Art")
		var art_bottom: float = art.position.y + art.size.y if art != null else face.size.y * 0.5
		status.position = Vector2(0, maxf(0.0, art_bottom - h)))
	# Amber glow while it can deploy (the head: "highlight what you can do now").
	var glow: Control = Control.new()
	glow.name = "Glow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.visible = state == &"deploy"
	panel.add_child(glow)
	glow.draw.connect(func() -> void:
		glow.draw_rect(Rect2(Vector2(-3, -3), glow.size + Vector2(6, 6)), Color(AMBER, 0.95), false, 3.0)
		glow.draw_rect(Rect2(Vector2(-6, -6), glow.size + Vector2(12, 12)), Color(AMBER, 0.35), false, 3.0))
	panel.sort_children.connect(func() -> void:
		glow.position = Vector2.ZERO
		glow.size = panel.size
		glow.queue_redraw())
	if glow.visible and not _reduced_motion():
		var tw: Tween = glow.create_tween().set_loops()
		tw.tween_property(glow, "modulate:a", 0.45, 0.7).set_trans(Tween.TRANS_SINE)
		tw.tween_property(glow, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	_wire_operator(panel, bool(op.get("active", false)), bool(op.get("draggable", false)))
	return panel


func _wire_operator(chip: Control, active: bool, draggable: bool) -> void:
	var g: RefCounted = PressGesture.new(chip)
	g.drag_enabled = draggable
	chip.set_meta(&"gesture", g)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.gui_input.connect(func(e: InputEvent) -> void:
		if g.handle(e):
			chip.accept_event())
	g.tapped.connect(func(_p: Vector2) -> void:
		if read_only or not active:
			operator_inspected.emit()
		else:
			operator_tapped.emit())
	g.long_pressed.connect(func(_p: Vector2) -> void: operator_inspected.emit())
	g.drag_started.connect(func(p: Vector2) -> void:
		if not read_only:
			operator_drag_started.emit(p))
	g.drag_moved.connect(func(p: Vector2) -> void:
		if not read_only:
			operator_drag_moved.emit(p))
	g.drag_ended.connect(func(p: Vector2) -> void:
		if not read_only:
			operator_drag_ended.emit(p))


## Selected = the selected card style; off the board and unable to act (down) = dimmed.
func _style_operator() -> void:
	if _op_chip == null:
		return
	var state: StringName = StringName(String(operator_entry.get("state", "none")))
	_op_chip.theme_type_variation = &"HandCardSelected" if operator_selected else &"HandCard"
	_op_chip.modulate.a = 1.0
	var art: TextureRect = _op_chip.find_child("Art", true, false) as TextureRect
	if art != null:
		# On the board / down: the card dims (it is a status card now); deployable: full colour.
		var dim: bool = state == &"board" or state == &"down" or state == &"planned"
		art.self_modulate = Color(0.45, 0.45, 0.48) if dim and not operator_selected else Color.WHITE


func _reduced_motion() -> bool:
	var settings: Node = get_node_or_null(^"/root/Settings")
	return settings != null and bool(settings.get(&"reduced_motion"))


func _number(text: String, big: bool) -> Label:
	var v: Label = _label(text, &"HudNumber", true)
	v.add_theme_font_size_override(&"font_size", 18 if big else 16)
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return v


## The face covers the card inside its border: art window on top, name, then the stat row.
func _fit_face(panel: PanelContainer, face: Control, art: Control, hex: Control, title: Control, bottom: Control, art_h: float) -> void:
	var sb: StyleBox = panel.get_theme_stylebox(&"panel")
	var inset: float = 2.0
	if sb is StyleBoxFlat:
		inset = float((sb as StyleBoxFlat).border_width_left)
	face.position = Vector2(inset, inset)
	face.size = panel.size - Vector2(inset, inset) * 2.0
	art.position = Vector2.ZERO
	art.size = Vector2(face.size.x, art_h - inset)
	if art.has_meta(&"strip"):
		var back: Control = art.get_meta(&"strip")
		back.position = Vector2.ZERO
		back.size = art.size
		var strip_h: float = roundf(face.size.x / BannerArt.BANNER_RATIO)
		art.position = Vector2(0.0, art.size.y - strip_h)
		art.size = Vector2(face.size.x, strip_h)
	hex.position = Vector2(2, 2)
	var pad: float = 4.0
	var bottom_h: float = bottom.get_combined_minimum_size().y
	bottom.position = Vector2(pad, face.size.y - bottom_h - 1.0)
	bottom.size = Vector2(face.size.x - pad * 2.0, bottom_h)
	var title_h: float = title.get_combined_minimum_size().y
	var free_top: float = art.position.y + art.size.y
	title.position = Vector2(pad, free_top + maxf(0.0, (bottom.position.y - free_top - title_h) * 0.5))
	title.size = Vector2(face.size.x - pad * 2.0, title_h)


## Bolt (tactic) or stake (Field) glyph in the hand card's bottom row.
func _draw_type_glyph(c: Control, field: bool, col: Color) -> void:
	var s: float = c.size.x
	if field:
		c.draw_line(Vector2(s * 0.5, s * 0.1), Vector2(s * 0.5, s * 0.95), col, 2.0)
		c.draw_line(Vector2(s * 0.2, s * 0.35), Vector2(s * 0.8, s * 0.35), col, 2.0)
		c.draw_line(Vector2(s * 0.28, s * 0.6), Vector2(s * 0.72, s * 0.6), col, 2.0)
	else:
		c.draw_colored_polygon(PackedVector2Array([Vector2(s * 0.58, 0), Vector2(s * 0.2, s * 0.56), Vector2(s * 0.46, s * 0.56),
				Vector2(s * 0.36, s), Vector2(s * 0.8, s * 0.42), Vector2(s * 0.54, s * 0.42)]), col)


func _label(text: String, variation: StringName, important: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if important:
		label.set_meta(&"important", true)
	return label

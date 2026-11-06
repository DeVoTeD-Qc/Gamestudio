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
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
const BRASS: Color = Color("#C9A227")
const BRASS_DARK: Color = Color("#3A2D0B")

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
## kc-ui4: the board's banner height; hand banner cards use its badge / plate sizes.
var _metric_h: float = 0.0
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
## metric_h (kc-ui4): the board's banner height (the cards' icon sizes); 0 keeps the current one.
func set_card_size(card: Vector2, gap: float, cols: int = columns, board_dir: float = board_side, metric_h: float = 0.0) -> void:
	_caption.visible = false
	var mh: float = metric_h if metric_h > 0.0 else _metric_h
	if card == _card_size_override and gap == _gap and cols == columns and board_dir == board_side and mh == _metric_h:
		return
	var rebuild: bool = card != _card_size_override or mh != _metric_h
	_metric_h = mh
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
		# kc-syn-ui (head): on the board the Operator card folds to a half-height mini card.
		var on_board: bool = StringName(String(operator_entry.get("state", ""))) == &"board"
		_op_chip = _make_operator_mini(operator_entry) if on_board else _make_operator_card(operator_entry)
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
	# kc-syn-ui: the mini Operator card is half a card tall; the cards under it in the first column
	# move up by the half it frees, so that column holds more before the rows start to overlap.
	var mini: bool = _op_chip != null and bool(_op_chip.get_meta(&"mini", false))
	var mini_h: float = mini_height()
	var lift: float = (card_size.y - mini_h) if mini else 0.0
	if mini and rows > 1:
		var pitch_y0: float = minf(card_size.y + _gap, (_row.size.y - card_size.y + lift) / (rows - 1))
		pitch_y = minf(card_size.y + _gap, maxf(pitch_y, pitch_y0))
	for i: int in n:
		var c: Control = cards[i]
		c.size = card_size if not (mini and c == _op_chip) else Vector2(card_size.x, mini_h)
		var x: float = x0 + (i % cols) * pitch_x
		# kc-board2 §4.2: the selected card shifts 14 px toward the board.
		if (int(c.get_meta(&"uid", -1)) == selected_uid and selected_uid >= 0) or (c == _op_chip and operator_selected):
			x += SELECTED_SHIFT * board_side
		var y: float = (i / cols) * pitch_y
		if mini and i % cols == 0 and i > 0:
			y -= lift
		c.position = Vector2(roundf(x), roundf(y))


## Height of the mini Operator card: half a hand card, at least 64 px (a 44 pt tap target on the
## phone, 64 px on desktop; three 16 px lines fit). kc-ui4: banner cards are already short, so below
## 128 px the status card keeps the card's height.
func mini_height() -> float:
	var h: float = _card_size().y
	return h if h < 128.0 else maxf(64.0, roundf(h * 0.5))


func _make_card(card: Dictionary) -> Control:
	# kc-ui4 (head: hand cards "closer to their form on the board"): the board's banner (same art band,
	# plate row, FP bottom-left / Armor bottom-right, keyword / trait icons, level band) with the cost
	# hex and the name (chassis) over the art's subname. Rules text is one long-press away.
	var ctype: String = MiniIcons.card_type(card)
	var entry: Dictionary = banner_entry(card)
	var metric: float = _metric_h if _metric_h > 0.0 else _card_size().y
	var panel: PanelContainer = BannerCard.build(entry, _card_size(), metric)
	panel.add_to_group(&"tap_target")
	panel.set_meta(&"playable", bool(card.get("playable", true)))
	panel.set_meta(&"ctype", ctype)
	panel.tooltip_text = String(card.get("name", "")) + ((" · %s" % String(card["subname"])) if String(card.get("subname", "")) != "" else "")
	var face: Control = panel.get_node("Face")
	_add_synergy_overlay(panel, face, card)
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
	face.add_child(next_tag)
	panel.sort_children.connect(func() -> void:
		next_tag.size = Vector2(face.size.x, next_tag.get_combined_minimum_size().y)
		next_tag.position = Vector2(0, face.size.y * 0.5 - next_tag.size.y * 0.5))
	return panel


## kc-ui4: the board banner entry of a hand chip (card_info.gd chip() + match_snapshot hand fields).
static func banner_entry(card: Dictionary) -> Dictionary:
	var ctype: String = MiniIcons.card_type(card)
	var e: Dictionary = {"name": card.get("name", ""), "cost": card.get("cost", 0),
			"cls": String(card.get("weapon_class", "")).to_upper(), "keywords": card.get("keywords", []),
			"elite": bool(card.get("elite", false)), "bolt": bool(card.get("bolt", false)),
			"front_kw": bool(card.get("front_kw", false)),
			"banner": String(card.get("banner", card.get("id", "")))}
	# kc-onboard-ui: the Standard Issue / Recruit keys (StandardIssueLook.dress in match_snapshot).
	for k: String in ["subname", "trait", "kw", "band", "fp_trend", "cover", "armor_max", "operator", "camo",
			"standard_issue", "serial", "locked", "trains", "level", "level_badge", "reserve_trait"]:
		if card.has(k) and str(card[k]) != "":
			e[k] = card[k]
	if card.has("fp"):
		e["fp"] = card["fp"]
		e["armor"] = card.get("armor", 0)
	else:
		e["kind_word"] = "FIELD" if ctype == "equipment" else "TACTIC"
	if String(card.get("kw", "")) != "":
		e["kw_active"] = true
	return e


## The BannerView of a hand card (null for the mini Operator card).
func get_banner(chip: Node) -> BannerView:
	return BannerCard.banner_of(chip)


## kc-syn-ui / kc-ui4: the trait icon, keyword pip and level band are on the banner itself; this adds
## the dot when playing the card this round would switch a set tier on (completes_tier).
func _add_synergy_overlay(panel: Control, face: Control, card: Dictionary) -> void:
	var t: StringName = StringName(String(card.get("trait", "")))
	var kw: StringName = StringName(String(card.get("kw", "")))
	var band: StringName = StringName(String(card.get("band", "")))
	var completes: String = String(card.get("completes_tier", ""))
	if t == &"" and kw == &"" and band == &"" and completes == "":
		return
	var syn: Control = Control.new()
	syn.name = "Synergy"
	syn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	syn.set_meta(&"trait", t)
	syn.set_meta(&"kw", kw)
	syn.set_meta(&"band", band)
	syn.set_meta(&"completes_tier", completes)
	face.add_child(syn)
	syn.draw.connect(func() -> void:
		if completes != "":
			var mm: Dictionary = BannerView.metrics(minf(syn.size.y, _metric_h if _metric_h > 0.0 else syn.size.y))
			SynergyGlyphs.draw_dot(syn, Vector2(syn.size.x * 0.5, mm["pad"] + mm["plate"] * 0.5 + 4.0), 5.0, SynergyGlyphs.trait_color(t)))
	panel.sort_children.connect(func() -> void:
		syn.position = Vector2.ZERO
		syn.size = face.size
		syn.queue_redraw())
	if completes != "":
		panel.tooltip_text = "%s · playing it now turns %s on" % [panel.tooltip_text, completes]


# =============================================================================
# kc-ui3: the Operator card
# =============================================================================

func _make_operator_card(op: Dictionary) -> Control:
	var state: StringName = StringName(String(op.get("state", "none")))
	var cost0: int = int(op.get("cost", 0))
	var short0: bool = state == &"deploy" and not bool(op.get("can_afford", true))
	var status0: String = ("NEED %d SUPPLY" % cost0) if short0 else String(op.get("status", "")).replace("\n", " · ")
	# kc-ui4: the status (DEPLOY / PLAN · B / DOWN · NEXT ROUND) is the line under the name, where a
	# deck card shows its art's subname, so it never covers the name or the badges.
	var card: Dictionary = {"name": op.get("name", "Operator"), "type": "OPERATOR", "cost": "", "subname": status0,
			"fp": op.get("fp", 0), "armor": op.get("armor", 0), "armor_max": op.get("armor_max", op.get("armor", 0)),
			"keywords": op.get("keywords", []), "operator": true, "camo": op.get("camo", "base"),
			"banner": op.get("banner", ""), "id": op.get("banner", ""), "playable": true}
	var panel: Control = _make_card(card)
	panel.name = "OperatorCard"
	panel.set_meta(&"uid", OPERATOR_UID)
	panel.set_meta(&"operator", true)
	panel.tooltip_text = "Your Operator: %s" % String(op.get("name", ""))
	var next_tag: Node = panel.find_child("NextTag", true, false)
	if next_tag != null:
		(next_tag as Control).visible = false
	# kc-syn-ui (head B): not a deck card. No cost hex: a brass dog-tag plate with its Supply cost
	# ("1 SUPPLY"; red when you can't pay it), a brass frame with cut corners (operator_frame()).
	for hex: Node in panel.find_children("*", "", true, false):
		if hex is CostHex:
			(hex as CostHex).visible = false
	var cost: int = int(op.get("cost", 0))
	var short: bool = state == &"deploy" and not bool(op.get("can_afford", true))
	var plate_l: Label = _label("%d SUPPLY" % cost if cost > 0 else "OPERATOR", &"HudTag", true)
	plate_l.name = "OperatorPlate"
	plate_l.add_theme_font_size_override(&"font_size", 16)
	plate_l.add_theme_color_override(&"font_color", Color.WHITE if short else Color(0.07, 0.08, 0.1))
	var tag_sb := StyleBoxFlat.new()
	tag_sb.bg_color = get_theme_color(&"enemy", &"Hud") if short else BRASS
	tag_sb.set_corner_radius_all(6)
	tag_sb.set_content_margin_all(2)
	tag_sb.content_margin_left = 6
	tag_sb.content_margin_right = 6
	plate_l.add_theme_stylebox_override(&"normal", tag_sb)
	var face0: Control = panel.get_node("Face")
	face0.add_child(plate_l)
	var obv: BannerView = BannerCard.banner_of(panel)
	panel.sort_children.connect(func() -> void:
		plate_l.size = plate_l.get_combined_minimum_size()
		var mm: Dictionary = BannerView.metrics(minf(face0.size.y, _metric_h if _metric_h > 0.0 else face0.size.y))
		var an: Dictionary = BannerView.anatomy(face0.size, mm, obv.entry, plate_l.size.x + 4.0)
		plate_l.position = Vector2((an["cost"] as Rect2).position.x, (an["cost"] as Rect2).position.y + ((an["cost"] as Rect2).size.y - plate_l.size.y) * 0.5)
		# kc-ui4: the Supply plate takes the cost slot (top-left). The plate row is too short for the
		# weapon's name, so on the Operator card the name takes the subname slot and the status
		# (DEPLOY / PLAN · B) the top centre (when it fits; the tooltip and the red plate say it too).
		var want: float = plate_l.size.x + 4.0
		if obv != null and absf(obv.lead - want) > 0.5:
			obv.lead = want
			obv.queue_redraw()
			panel.queue_sort()
		var tl: Label = face0.find_child("NameLabel", false, false) as Label
		var stl: Label = face0.find_child("OperatorStatus", false, false) as Label
		if tl == null or stl == null:
			return
		var th: float = tl.get_combined_minimum_size().y
		var mid: Rect2 = an["mid"]
		var sr: Rect2 = mid if mid.size.y >= th - 4.0 else an["sub"]
		tl.position = Vector2(sr.position.x, sr.position.y + (sr.size.y - th) * 0.5)
		tl.size = Vector2(maxf(8.0, sr.size.x), th)
		var nr: Rect2 = an["name"]
		var need: Vector2 = stl.get_combined_minimum_size()
		stl.visible = stl.text != "" and need.x <= nr.size.x
		stl.size = need
		stl.position = Vector2(nr.position.x + (nr.size.x - need.x) * 0.5, nr.position.y + (nr.size.y - need.y) * 0.5))
	if short:
		op = op.duplicate()
		op["status"] = "NEED %d SUPPLY" % cost
	panel.set_meta(&"operator_short", short)
	_apply_operator_frame(panel)
	# Status line (BannerCard's SubLabel): DEPLOY / PLAN · B / DOWN · NEXT ROUND / NEED 1 SUPPLY.
	var status: Label = panel.find_child("SubLabel", true, false) as Label
	status.name = "OperatorStatus"
	status.set_meta(&"important", true)
	status.clip_text = false
	status.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	status.tooltip_text = status.text
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.05, 0.06, 0.07, 0.86)
	plate.set_corner_radius_all(4)
	plate.content_margin_left = 4
	plate.content_margin_right = 4
	if state == &"deploy":
		plate.bg_color = AMBER
		status.add_theme_color_override(&"font_color", Color(0.07, 0.08, 0.1))
	if state == &"deploy" and bool(panel.get_meta(&"operator_short", false)):
		plate.bg_color = Color(0.05, 0.06, 0.07, 0.9)
		status.add_theme_color_override(&"font_color", get_theme_color(&"enemy", &"Hud"))
	elif state == &"down":
		status.add_theme_color_override(&"font_color", get_theme_color(&"enemy", &"Hud"))
	elif state != &"deploy":
		status.add_theme_color_override(&"font_color", get_theme_color(&"friend", &"Hud"))
	status.add_theme_stylebox_override(&"normal", plate)
	status.visible = status.text != ""
	# Amber glow while it can deploy (the head: "highlight what you can do now").
	var glow: Control = Control.new()
	glow.name = "Glow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.visible = state == &"deploy" and not bool(panel.get_meta(&"operator_short", false))
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


## The Operator's own frame (head B): brass border, dark brass fill, cut (rounded) corners like a
## dog tag; teal border while selected. Never the deck cards' HandCard style.
func _apply_operator_frame(panel: Control) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BRASS_DARK
	sb.border_color = get_theme_color(&"friend", &"Hud") if operator_selected else BRASS
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.corner_detail = 2
	sb.set_content_margin_all(3)
	panel.add_theme_stylebox_override(&"panel", sb)


## kc-syn-ui (head): the half-height Operator card while it is on the board: brass dog-tag frame,
## its art dimmed behind, where it stands ("ON BOARD" / "B · ROW 2") and FP / Armor. Tap selects it
## to Rotate (in Deploy), long-press = its rules.
func _make_operator_mini(op: Dictionary) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "OperatorCard"
	panel.set_meta(&"uid", OPERATOR_UID)
	panel.set_meta(&"operator", true)
	panel.set_meta(&"mini", true)
	panel.add_to_group(&"tap_target")
	panel.tooltip_text = "Your Operator: %s (on the board)" % String(op.get("name", ""))
	var face: Control = Control.new()
	face.name = "Face"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.clip_contents = true
	panel.add_child(face)
	var art := TextureRect.new()
	art.name = "Art"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_id: StringName = StringName(String(op.get("banner", "")))
	art.texture = BannerArtDB.banner_texture(art_id, {"cls": "OPERATOR", "type": "unit"}) if art_id != &"" else null
	art.self_modulate = Color(0.38, 0.38, 0.4)
	face.add_child(art)
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "MiniColumn"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", -2)
	face.add_child(col)
	var where: String = String(op.get("zone_label", ""))
	var top: Label = _label("ON BOARD", &"HudTag", true)
	top.name = "OperatorStatus"
	top.add_theme_font_size_override(&"font_size", 16)
	top.add_theme_color_override(&"font_color", BRASS)
	col.add_child(top)
	var pos_l: Label = _label("%s · ROW %d" % [where, int(op.get("row", 1))] if where != "" else "", &"HudTag", true)
	pos_l.name = "OperatorWhere"
	pos_l.add_theme_font_size_override(&"font_size", 16)
	pos_l.add_theme_color_override(&"font_color", get_theme_color(&"friend", &"Hud"))
	col.add_child(pos_l)
	var stats: HBoxContainer = HBoxContainer.new()
	stats.name = "Bottom"
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_theme_constant_override(&"separation", 2)
	var text_color: Color = get_theme_color(&"text", &"Hud")
	stats.add_child(MiniIcons.icon(&"stat_firepower", 14.0, text_color))
	stats.add_child(_number(str(int(op.get("fp", 0))), false))
	var sp: Control = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_child(sp)
	stats.add_child(MiniIcons.icon(&"stat_armor", 14.0, text_color))
	stats.add_child(_number("%d/%d" % [int(op.get("armor", 0)), int(op.get("armor_max", op.get("armor", 0)))], false))
	col.add_child(stats)
	panel.sort_children.connect(func() -> void:
		var inset: float = 3.0
		face.position = Vector2(inset, inset)
		face.size = panel.size - Vector2(inset, inset) * 2.0
		art.position = Vector2.ZERO
		art.size = face.size
		col.position = Vector2(4, 0)
		col.size = Vector2(face.size.x - 8.0, face.size.y))
	_apply_operator_frame(panel)
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
	_apply_operator_frame(_op_chip)
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


func _label(text: String, variation: StringName, important: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if important:
		label.set_meta(&"important", true)
	return label

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
const BoardMetrics: GDScript = preload("res://scripts/ui/board_metrics.gd")
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
## kc-ui-hooks: the UI kit frame of the O2 Operator card (prompt pack §7.4b).
const OPERATOR_FRAME_PIECE: StringName = &"frm_y2_operator"
var _op_chip: Control = null
## kc-cards-impl (H1 + O2): the card grid's rect and the Operator card's rect (HandArea-local; the
## HandArea covers the grid and the Operator row under it). Empty = the whole row.
var _grid_rect: Rect2 = Rect2()
var _op_rect: Rect2 = Rect2()
## kc-cards-impl (H1): the selected card lifts this far.
const SELECTED_LIFT: float = 6.0
## kc-portrait: the hand is a swipeable fan of Y2+ cards (CardView) along the bottom.
var fan: bool = false
## Px between fanned cards (>= 61 px: 44 pt), and the fan's scroll (0 = the first card at the left).
var fan_step: float = 68.0
var fan_scroll: float = 0.0
const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/match/CardView.tscn")
## Uid meta of the Operator chip (never a rules card uid).
const OPERATOR_UID: int = -2
const AMBER: Color = Color(0.961, 0.722, 0.239)
## kc-ipad-cards: the grid re-fits the X1 cards to the hand's count (BoardMetrics.hand_fit): the
## size, columns, and on small 16:9 phones a scrolling single column (hand_scroll = the first row
## shown; a vertical swipe or the mouse wheel scrolls, a sideways drag still places the card).
var hand_fit: Dictionary = {}
var hand_scroll: int = 0
var _more_up: Label = null
var _more_down: Label = null

@onready var _caption: Label = %CaptionLabel
@onready var _row: Control = %CardRow


func _ready() -> void:
	# kc-board: the cards sit straight under the board (no panel behind the row).
	add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	_caption.visible = false
	_row.resized.connect(_fit_cards)
	# kc-ipad-cards: "n MORE" hints of a scrolling hand (small phones).
	for up: bool in [true, false]:
		var l := Label.new()
		l.name = "MoreUp" if up else "MoreDown"
		l.theme_type_variation = &"HudTag"
		l.add_theme_font_size_override(&"font_size", 16)
		l.add_theme_color_override(&"font_color", AMBER)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.05, 0.055, 0.88)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		l.add_theme_stylebox_override(&"normal", sb)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.z_index = 5
		# Out of the PanelContainer's layout (it would stretch the hint over the whole hand).
		l.top_level = true
		l.visible = false
		l.tooltip_text = "More hand cards: swipe the hand up or down (or use the mouse wheel)"
		add_child(l)
		if up:
			_more_up = l
		else:
			_more_down = l


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


## kc-cards-impl: the grid's rect and the Operator card's rect (HandArea-local).
func set_grid_rect(grid: Rect2, op_rect: Rect2) -> void:
	if grid == _grid_rect and op_rect == _op_rect:
		return
	var rebuild: bool = op_rect.size != _op_rect.size
	_grid_rect = grid
	_op_rect = op_rect
	if rebuild and not operator_entry.is_empty():
		set_hand(_cards_data)
	else:
		_fit_cards()


func get_grid_rect() -> Rect2:
	return _grid_rect


## kc-portrait: the fan hand on / off (rebuilds the cards).
func set_fan(on: bool) -> void:
	if on == fan:
		return
	fan = on
	fan_scroll = 0.0
	set_hand(_cards_data)


## The most the fan can scroll (0 when every card fits).
func fan_scroll_max() -> float:
	var n: int = get_cards().size()
	var grid: Rect2 = _grid_rect if _grid_rect.size != Vector2.ZERO else Rect2(Vector2.ZERO, _row.size)
	return maxf(0.0, (n - 1) * fan_step + _card_size().x - grid.size.x)


## Scrolls the fan by dx px (a swipe), clamped.
func scroll_fan(dx: float) -> void:
	fan_scroll = clampf(fan_scroll - dx, 0.0, fan_scroll_max())
	_fit_cards()


## Scrolls the fan so this card's strip is fully visible.
func reveal_card(uid: int) -> void:
	var cards: Array[Node] = get_cards()
	for i: int in cards.size():
		if int(cards[i].get_meta(&"uid", -1)) == uid:
			var grid: Rect2 = _grid_rect if _grid_rect.size != Vector2.ZERO else Rect2(Vector2.ZERO, _row.size)
			var x: float = i * fan_step
			if x - fan_scroll < 0.0:
				fan_scroll = x
			elif x + fan_step - fan_scroll > grid.size.x:
				fan_scroll = minf(fan_scroll_max(), x + fan_step - grid.size.x)
			_fit_cards()


func set_read_only(value: bool) -> void:
	read_only = value
	if _op_chip != null:
		_op_chip.visible = not value  # PEEK: the tray's tab and SPEED take the Operator row
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
		# kc-cards-impl (O2): the Operator card sits bottom-left of the tray, next to UNDO / READY,
		# in every state (Deploy / On board / Down / Need supply).
		_op_chip = _make_operator_card(operator_entry)
		_op_chip.visible = not read_only
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
		if fan and uid >= 0:
			reveal_card(uid)
		elif is_scrolling() and uid >= 0:
			_reveal_in_grid(uid)


## kc-ipad-cards: scrolls a scrolling hand so this card shows.
func _reveal_in_grid(uid: int) -> void:
	var cards: Array[Node] = get_cards()
	var cols: int = maxi(1, int(hand_fit.get("cols", 1)))
	var vis_rows: int = maxi(1, int(hand_fit.get("visible", 1)) / cols)
	for i: int in cards.size():
		if int(cards[i].get_meta(&"uid", -1)) == uid:
			var row: int = i / cols
			if row < hand_scroll:
				hand_scroll = row
			elif row >= hand_scroll + vis_rows:
				hand_scroll = row - vis_rows + 1
			_fit_cards()
			return


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
		if chip is CardView:
			# kc-portrait: the fan's Y2+ card marks the selection with its amber frame.
			var cv: CardView = chip
			var on: bool = uid == selected_uid and uid >= 0
			if bool(cv.data.get("marked", false)) != on:
				var d: Dictionary = cv.data.duplicate()
				d["marked"] = on
				cv.set_card_data(d)
		else:
			(chip as Control).theme_type_variation = variation
		# Unaffordable chips fade so the playable ones stand out; the dragged one fades more.
		var alpha: float = 1.0 if playable or uid == selected_uid else 0.55
		(chip as Control).modulate.a = 0.35 if uid == dragging_uid and uid >= 0 else alpha
		# Can't afford it: greyscale-ish, 60% brightness (§3.4).
		(chip as Control).self_modulate = Color.WHITE
		var art: TextureRect = chip.find_child("Art", true, false) as TextureRect
		if art != null:
			# kc-hand-dim: the art is always ~22% darker (BannerView.ART_DIM) so the icons read; can't
			# afford it: darker still (0.6 of that), and the chip fades (alpha 0.55), so it stays distinct.
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
	var last: Array = [Vector2.ZERO]
	# kc-ipad-cards: on a scrolling hand a drag is undecided until it moves: mostly vertical = scroll
	# the hand; else it places the card as usual. mode: 0 placing, 1 undecided, 2 scrolling.
	var mode: Array = [0, Vector2.ZERO, 0.0]
	g.drag_started.connect(func(p: Vector2) -> void:
		if fan:
			last[0] = p  # kc-portrait: a swipe on the fan scrolls it (place with a tap instead)
		elif is_scrolling():
			mode[0] = 1
			mode[1] = p
			mode[2] = 0.0
		elif not read_only:
			mode[0] = 0
			card_drag_started.emit(uid, p))
	g.drag_moved.connect(func(p: Vector2) -> void:
		if fan:
			scroll_fan(p.x - (last[0] as Vector2).x)
			last[0] = p
			return
		if int(mode[0]) == 1:
			var d: Vector2 = p - (mode[1] as Vector2)
			if d.length() < 6.0:
				return
			if absf(d.y) > absf(d.x):
				mode[0] = 2
				mode[1] = p
			elif read_only:
				mode[0] = 3
				return
			else:
				mode[0] = 0
				card_drag_started.emit(uid, mode[1])
		if int(mode[0]) == 2:
			var step: float = float((hand_fit.get("card", Vector2(0, 60)) as Vector2).y) * 0.6
			var dy: float = p.y - (mode[1] as Vector2).y
			if absf(dy) >= step:
				scroll_hand(-1 if dy > 0.0 else 1)
				mode[1] = p
		elif int(mode[0]) == 0 and not read_only:
			card_drag_moved.emit(uid, p))
	g.drag_ended.connect(func(p: Vector2) -> void:
		var m: int = int(mode[0])
		mode[0] = 0
		if not fan and not read_only and m == 0:
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
	var cards: Array[Node] = get_cards()
	var n: int = cards.size()
	var card_size: Vector2 = _card_size()
	_row.custom_minimum_size = Vector2(card_size.x, card_size.y)
	var grid: Rect2 = _grid_rect if _grid_rect.size != Vector2.ZERO else Rect2(Vector2.ZERO, _row.size)
	if _op_chip != null:
		var orr: Rect2 = _op_rect if _op_rect.size != Vector2.ZERO else Rect2(Vector2(0, grid.end.y + _gap), Vector2(grid.size.x, 120))
		_op_chip.position = orr.position + Vector2(0, -SELECTED_LIFT if operator_selected else 0.0)
		_op_chip.size = orr.size
	if n == 0:
		return
	if fan:
		# kc-portrait: one overlapping row (each card shows fan_step px; the last one whole), scrolled
		# by a swipe; the selected card rises above the others (the raised face is in the well).
		fan_scroll = clampf(fan_scroll, 0.0, fan_scroll_max())
		for i: int in n:
			var c: Control = cards[i]
			c.size = card_size
			var sel: bool = int(c.get_meta(&"uid", -1)) == selected_uid and selected_uid >= 0
			c.position = Vector2(roundf(grid.position.x + i * fan_step - fan_scroll), roundf(grid.position.y + (0.0 if sel else 10.0)))
			c.z_index = 10 if sel else 0
		return
	var cols: int = maxi(1, columns)
	var scroll: bool = false
	var first: int = 0
	var shown: int = n
	if _grid_rect.size != Vector2.ZERO:
		# kc-ipad-cards: size the cards for this many (the tray fills on iPad / desktop; columns and
		# height follow the count).
		var min_h: float = BoardMetrics.X1_MIN_H if compact else BoardMetrics.X1_MIN_H_DESKTOP
		hand_fit = BoardMetrics.hand_fit(_grid_rect.size, n, _gap, min_h)
		card_size = hand_fit["card"]
		cols = int(hand_fit["cols"])
		scroll = bool(hand_fit["scroll"])
		if scroll:
			shown = int(hand_fit["visible"])
			var max_first_row: int = ceili(float(n - shown) / cols)
			hand_scroll = clampi(hand_scroll, 0, max_first_row)
			first = hand_scroll * cols
		else:
			hand_scroll = 0
	var rows: int = ceili(float(shown) / cols)
	var pitch_x: float = card_size.x + _gap
	var pitch_y: float = card_size.y + _gap
	# The top SELECTED_LIFT px stay free for the selected card's lift.
	grid = Rect2(grid.position + Vector2(0, SELECTED_LIFT), grid.size - Vector2(0, SELECTED_LIFT))
	if rows > 1 and not scroll:
		# More cards than the grid holds: the rows overlap upward (the step shrinks).
		pitch_y = minf(pitch_y, (grid.size.y - card_size.y) / (rows - 1))
	var grid_w: float = card_size.x + pitch_x * (cols - 1)
	var x0: float = grid.position.x + maxf(0.0, (grid.size.x - grid_w) * 0.5)
	for i: int in n:
		var c: Control = cards[i]
		var j: int = i - first
		c.visible = j >= 0 and j < shown
		c.custom_minimum_size = card_size
		c.size = card_size
		var x: float = x0 + (j % cols) * pitch_x
		var y: float = grid.position.y + (j / cols) * pitch_y
		# kc-cards-impl (H1): the selected card lifts.
		if int(c.get_meta(&"uid", -1)) == selected_uid and selected_uid >= 0:
			y -= SELECTED_LIFT
		c.position = Vector2(roundf(x), roundf(y))
	_place_more_hints(scroll, first, shown, n, grid)


## kc-ipad-cards: "▲ n MORE" / "▼ n MORE" over the top / bottom edge of a scrolling hand.
func _place_more_hints(scroll: bool, first: int, shown: int, n: int, grid: Rect2) -> void:
	if _more_up == null:
		return
	var above: int = first
	var below: int = maxi(0, n - first - shown)
	_more_up.visible = scroll and above > 0
	_more_down.visible = scroll and below > 0
	_more_up.text = "▲ %d MORE" % above
	_more_down.text = "▼ %d MORE" % below
	for l: Label in [_more_up, _more_down]:
		l.size = l.get_combined_minimum_size()
	var o: Vector2 = _row.global_position
	_more_up.global_position = o + Vector2(grid.position.x + (grid.size.x - _more_up.size.x) * 0.5, grid.position.y - 4.0)
	var last_bottom: float = grid.position.y
	for c: Node in get_cards():
		if (c as Control).visible:
			last_bottom = maxf(last_bottom, (c as Control).position.y + (c as Control).size.y)
	# Under the last card shown when the grid has room left, else over that card's bottom edge.
	var y: float = minf(last_bottom + 2.0, grid.end.y - _more_down.size.y)
	_more_down.global_position = o + Vector2(grid.position.x + (grid.size.x - _more_down.size.x) * 0.5, y)


## kc-ipad-cards: scrolls a scrolling hand by `rows` rows (no-op otherwise).
func scroll_hand(rows: int) -> void:
	if not bool(hand_fit.get("scroll", false)):
		return
	hand_scroll = maxi(0, hand_scroll + rows)
	_fit_cards()


## True when the hand shows fewer cards than it holds (a vertical swipe scrolls it).
func is_scrolling() -> bool:
	return bool(hand_fit.get("scroll", false)) and not fan


func _gui_input(event: InputEvent) -> void:
	if is_scrolling() and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var b: MouseButton = (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_DOWN or b == MOUSE_BUTTON_WHEEL_UP:
			scroll_hand(1 if b == MOUSE_BUTTON_WHEEL_DOWN else -1)
			accept_event()


## Height of the mini Operator card: half a hand card, at least 64 px (a 44 pt tap target on the
## phone, 64 px on desktop; three 16 px lines fit). kc-ui4: banner cards are already short, so below
## 128 px the status card keeps the card's height.
func mini_height() -> float:
	var h: float = _card_size().y
	return h if h < 128.0 else maxf(64.0, roundf(h * 0.5))


func _make_card(card: Dictionary) -> Control:
	if fan:
		return _make_fan_card(card)
	return _make_banner_card(card)


## kc-portrait: a hand card in the fan: the Y2+ card (CardView), the mulligan / Codex form.
func _make_fan_card(card: Dictionary) -> Control:
	var cv: CardView = CARD_VIEW_SCENE.instantiate() as CardView
	cv.set_card_data(fan_view(card))
	cv.set_card_width(_card_size().x)
	cv.add_to_group(&"tap_target")
	cv.set_meta(&"playable", bool(card.get("playable", true)))
	cv.set_meta(&"ctype", MiniIcons.card_type(card))
	cv.set_meta(&"fan_card", true)
	cv.tooltip_text = String(card.get("name", ""))
	cv.ready.connect(func() -> void:
		for n: Node in cv.find_children("*", "Control", true, false):
			(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE)
	return cv


## The Y2+ data of a hand chip (card_info.gd chip() + the snapshot's hand fields).
static func fan_view(card: Dictionary) -> Dictionary:
	var ctype: String = MiniIcons.card_type(card)
	var v: Dictionary = {"name": card.get("name", ""), "type": {"equipment": "equipment", "tactic": "tactic"}.get(ctype, "unit"),
			"weapon_class": String(card.get("weapon_class", "")).to_lower(), "cost": int(card.get("cost", 0)),
			"firepower": int(card.get("fp", 0)), "armor": int(card.get("armor", 0)), "text": String(card.get("text", "")),
			"id": String(card.get("id", "")), "banner": String(card.get("banner", card.get("id", ""))), "side": "friend"}
	var kws: Array = []
	for k: Dictionary in card.get("keywords", []):
		kws.append({"id": String(k.get("id", "")), "value": int(k.get("value", 0))})
	v["keywords"] = kws
	for k: String in ["trait", "standard_issue", "elite"]:
		if card.has(k) and str(card[k]) != "":
			v[k] = card[k]
	v["cant_pay"] = not bool(card.get("playable", true))
	return v


func _make_banner_card(card: Dictionary) -> Control:
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
	# kc-onboard-ui: the Standard Issue keys (StandardIssueLook.dress in match_snapshot).
	for k: String in ["subname", "trait", "kw", "fp_trend", "cover", "armor_max", "operator", "camo",
			"standard_issue", "serial", "reserve_trait"]:
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

## kc-cards-impl (the head's O2): the Operator card at the bottom-left of the tray, next to UNDO over
## READY: the art on top (dimmed on the board, grey when down), the cost in the standard hex (red
## when you can't pay), the OPERATOR tag, its abilities top-right, FP / Armor bottom-right of the art,
## a state chip on the art (DEPLOY / PLAN · B / ON BOARD · B1 / DOWN), then its name in the title
## style and its ability line. Tap = select (Deploy / Rotate), drag = drag to a column, long press =
## its rules.
func _make_operator_card(op: Dictionary) -> Control:
	var state: StringName = StringName(String(op.get("state", "none")))
	var cost: int = int(op.get("cost", 0))
	var short: bool = state == &"deploy" and not bool(op.get("can_afford", true))
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "OperatorCard"
	panel.set_meta(&"uid", OPERATOR_UID)
	panel.set_meta(&"operator", true)
	panel.set_meta(&"operator_short", short)
	panel.set_meta(&"state", state)
	panel.set_meta(&"cost", cost)
	panel.add_to_group(&"tap_target")
	panel.tooltip_text = "Your Operator: %s" % String(op.get("name", ""))
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
	face.add_child(art)
	var status_text: String = ""
	var status_col: Color = get_theme_color(&"text", &"Hud")
	match state:
		&"deploy":
			status_text = "NEED %d SUPPLY" % cost if short else "DEPLOY"
			status_col = get_theme_color(&"enemy", &"Hud") if short else AMBER
		&"planned":
			status_text = String(op.get("status", "PLAN")).replace("\n", " · ")
			status_col = AMBER
		&"board":
			var where: String = String(op.get("zone_label", ""))
			status_text = "ON BOARD · %s%d" % [where, int(op.get("row", 1))] if where != "" else "ON BOARD"
			status_col = Color("#D8DEE3")
		&"down":
			status_text = "DOWN"
			status_col = get_theme_color(&"enemy", &"Hud")
		_:
			status_text = String(op.get("status", "")).replace("\n", " · ")
	var status: Label = _label(status_text, &"HudTag", true)
	status.name = "OperatorStatus"
	status.add_theme_font_override(&"font", CardLook.TITLE_FONT)
	status.add_theme_font_size_override(&"font_size", 16)
	status.add_theme_color_override(&"font_color", status_col)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.04, 0.05, 0.055, 0.9)
	plate.border_color = status_col
	plate.set_border_width_all(1)
	plate.content_margin_left = 6
	plate.content_margin_right = 6
	status.add_theme_stylebox_override(&"normal", plate)
	status.visible = status_text != ""
	status.tooltip_text = status_text
	face.add_child(status)
	var title: Label = CardLook.title_label(String(op.get("name", "Operator")))
	title.name = "NameLabel"
	title.set_meta(&"important", true)
	face.add_child(title)
	var names: PackedStringArray = []
	for kw: Dictionary in op.get("keywords", []):
		var nm: String = String(kw.get("name", ""))
		if nm != "":
			names.append(nm)
	var ability: Label = CardLook.rule_label(", ".join(names) if not names.is_empty() else "Respawns at your next Deploy if it goes down.")
	ability.name = "AbilityLine"
	ability.clip_text = true
	ability.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	face.add_child(ability)
	# The drawn layer: cost hex, OPERATOR tag, abilities, FP / Armor.
	var ink: Control = Control.new()
	ink.name = "Ink"
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(ink)
	face.move_child(status, -1)
	var entry: Dictionary = {"keywords": op.get("keywords", []), "operator": true}
	var fp: int = int(op.get("fp", 0))
	var armor: int = 0 if state == &"down" else int(op.get("armor", 0))
	var armor_max: int = int(op.get("armor_max", op.get("armor", 0)))
	ink.draw.connect(func() -> void:
		var ah: float = art.size.y
		var x: float = 5.0
		if cost > 0:
			CardLook.draw_chip(ink, Rect2(x - 2, 3, 30, 30), 5.0)
			CardLook.draw_cost(ink, Rect2(x, 5, 26, 26), str(cost), short)
			x += 30.0
		var narrow: bool = ink.size.x < 150.0
		var tag: Rect2 = Rect2(x, 7, 58.0 if narrow else 70.0, 18)
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Color(0.04, 0.05, 0.055, 0.86)
		tsb.border_color = BRASS
		tsb.set_border_width_all(1)
		tsb.set_corner_radius_all(9)
		ink.draw_style_box(tsb, tag)
		var f: Font = CardLook.TITLE_FONT
		var tfs: int = 12 if narrow else 14
		var tw: float = f.get_string_size("OPERATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
		ink.draw_string(f, Vector2(tag.position.x + (tag.size.x - tw) * 0.5, tag.position.y + 13.0 + (tfs - 12) * 0.5), "OPERATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color("#F3D36B"))
		var kinds: Array = BannerView.ability_kinds(entry)
		var kx: float = ink.size.x - 4.0 - 20.0
		for k: Variant in kinds:
			if kx < tag.end.x + 2.0:
				break
			if k is StringName and IconSheet.has_icon(k):
				ink.draw_rect(Rect2(kx, 5, 20, 20), Color(0.04, 0.05, 0.055, 0.86))
				if k == &"kw_pick":
					CardLook.draw_pick_icon(ink, Rect2(kx + 2, 7, 16, 16), AMBER)
				else:
					ink.draw_texture_rect(IconSheet.get_icon(k), Rect2(kx + 2, 7, 16, 16), false, AMBER)
				kx -= 22.0
		# kc-readability: FP / Armor as big as on the hand cards.
		var ar: Rect2 = Rect2(ink.size.x - 4.0 - 31.0, ah - 34.0, 31, 32)
		var fr: Rect2 = Rect2(ar.position.x - 3.0 - 32.0, ah - 34.0, 32, 32)
		CardLook.draw_chip(ink, Rect2(fr.position - Vector2(3, 2), Vector2(ar.end.x - fr.position.x + 6.0, 36)), 6.0)
		CardLook.draw_reticle(ink, fr, fp, &"player", 0)
		CardLook.draw_armor(ink, ar, armor, armor < armor_max))
	panel.sort_children.connect(func() -> void:
		var inset: float = 3.0
		face.position = Vector2(inset, inset)
		face.size = panel.size - Vector2(inset, inset) * 2.0
		var ah: float = roundf(face.size.y * 0.5)
		art.position = Vector2.ZERO
		art.size = Vector2(face.size.x, ah)
		ink.position = Vector2.ZERO
		ink.size = face.size
		var need: Vector2 = status.get_combined_minimum_size()
		status.size = Vector2(minf(need.x, face.size.x - 8.0), need.y)
		status.position = Vector2((face.size.x - status.size.x) * 0.5, maxf(28.0, ah * 0.5 - need.y * 0.5))
		var ty: float = ah + 2.0
		title.position = Vector2(6, ty)
		title.size = Vector2(face.size.x - 12.0, 22)
		ability.position = Vector2(6, ty + 22.0)
		ability.size = Vector2(face.size.x - 12.0, maxf(18.0, face.size.y - ty - 24.0))
		ability.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ink.queue_redraw())
	_apply_operator_frame(panel, true)
	# Amber glow while it can deploy (the head: "highlight what you can do now").
	var glow: Control = Control.new()
	glow.name = "Glow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.visible = state == &"deploy" and not short
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
func _apply_operator_frame(panel: Control, kit: bool = false) -> void:
	# kc-ui-hooks: the painted Y2+ Operator frame (frm_y2_operator, a scaled 9-slice drawn by the panel
	# itself; StyleBoxTexture can't scale its rims) when the kit has it; teal keyline while selected.
	# kit = the O2 tray card only (the on-board mini keeps the drawn dog tag).
	if kit and UiKit.has_piece(OPERATOR_FRAME_PIECE):
		var empty := StyleBoxEmpty.new()
		empty.set_content_margin_all(3)
		panel.add_theme_stylebox_override(&"panel", empty)
		panel.set_meta(&"kit_frame", OPERATOR_FRAME_PIECE)
		if not panel.has_meta(&"kit_frame_drawn"):
			panel.set_meta(&"kit_frame_drawn", true)
			panel.draw.connect(func() -> void:
				UiKit.draw_piece(panel, OPERATOR_FRAME_PIECE, Rect2(Vector2.ZERO, panel.size))
				if operator_selected:
					panel.draw_rect(Rect2(Vector2.ZERO, panel.size).grow(-1.0), get_theme_color(&"friend", &"Hud"), false, 2.0))
		panel.queue_redraw()
		return
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
	_apply_operator_frame(_op_chip, not bool(_op_chip.get_meta(&"mini", false)))
	_op_chip.modulate.a = 1.0
	var art: TextureRect = _op_chip.find_child("Art", true, false) as TextureRect
	if art != null:
		# On the board / down: the card dims (it is a status card now); deployable: full colour.
		var dim: bool = state == &"board" or state == &"down" or state == &"planned"
		art.self_modulate = Color(0.45, 0.45, 0.48) if dim and not operator_selected else Color.WHITE
		if state == &"down":
			art.self_modulate = Color(0.3, 0.3, 0.32)


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

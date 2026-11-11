# mulligan_panel.gd
# Purpose: Round 1 mulligan step (f02, core-rules Ruling 3). A modal panel over the board:
#   one toggle per card in the opening hand (tap = put it back), KEEP HAND, and REDRAW n.
#   It only collects the choice and emits `confirmed(put_back_uids)`; MatchController calls
#   MatchState.mulligan(). Phone sizes: every text >= 16 px and every tap target >= 64 px tall
#   (11.6 pt / 46 pt at the iPhone's 0.722 pt per px, README "Phone readability").
#   kc-ui3 (head: "the mulligan screen must show the cards in their full form"): each card is the
#   full CardView (art, name, cost, stats, rules text; a licensed calling card shows its art and
#   title), as big as the screen allows (phone: about 0.84x for 5 cards, never under the inspector's
#   0.8x; more cards scroll sideways), inside its toggle; a card
#   marked to go back dims under a PUT BACK plate. Long-press / right-click = the card inspector
#   (card_inspected; the controller opens it), without toggling the card.
# Scene: res://scenes/match/MulliganPanel.tscn (full-rect, hidden until open()).
# Dependencies: hud_theme.tres variations (Scrim, HudPanelDark, HudHeader, HudSubtle, HudButton,
#   KillstreakButton).
# Author: Mechanics Developer Agent (f02)
extends Control

## The player decided: card uids to put back (empty = keep the hand).
signal confirmed(put_back: Array[int])
## Long-press / right-click on a card (its rules uid).
signal card_inspected(uid: int)

const CARD_VIEW: PackedScene = preload("res://scenes/match/CardView.tscn")
const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
## kc-cards-impl: the Y2+ card is laid out at its own width (CardView.set_card_width): 172..220 px
## (the mock-up's mulligan card is 196), never scaled.
const VIEW_BASE: Vector2 = CardView.BASE_SIZE
const MIN_W: float = 172.0
const MAX_W: float = 220.0
const MAX_SCALE: float = 1.0
const MIN_FIT: float = 0.84
const CARD_PAD: float = 4.0
## Height the title, hint, actions and margins take (phone / desktop).
const CHROME_H: float = 170.0
const CHROME_H_DESKTOP: float = 220.0
## The card row scrolls sideways when the cards don't fit at a readable size (phone: the rules text
## stays >= 11 pt, so 4 of 5 cards show and a swipe brings the last one).
var _scroll: ScrollContainer = null

const CARD_SIZE: Vector2 = Vector2(150, 88)
const CARD_SIZE_COMPACT: Vector2 = Vector2(150, 72)
## k-art4: fill alpha of a card button over its art (the ArtUnderlay scrim does the rest).
const ART_FILL_ALPHA: float = 0.35

var compact: bool = false
var _picked: Array[int] = []

@onready var _cards: GridContainer = %Cards
@onready var _keep: Button = %KeepButton
@onready var _confirm: Button = %ConfirmButton
@onready var _hint: Label = %HintLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_keep.pressed.connect(func() -> void:
		var none: Array[int] = []
		_finish(none))
	_confirm.pressed.connect(func() -> void: _finish(_picked.duplicate()))


## Shows the hand: entries {uid, id?, name, cost, type, view?} (type: "UNIT", "TACTIC", "EQUIP";
## view = the CardView Dictionary, CardInfo.view_dict() plus licensed_art; without it a minimal face).
func open(hand: Array) -> void:
	_picked.clear()
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	var n: int = maxi(1, hand.size())
	_cards.columns = n
	_ensure_scroll()
	var cw: float = card_width(n)
	var s: float = cw
	var view_size: Vector2 = CardView.size_for(cw)
	var sep: float = float(_cards.get_theme_constant(&"h_separation"))
	var total_w: float = n * (view_size.x + CARD_PAD * 2.0) + (n - 1) * sep
	var area: Vector2 = size if size.x > 0.0 else get_viewport_rect().size
	var room_w: float = area.x - 36.0
	_scroll.custom_minimum_size = Vector2(minf(total_w, room_w), view_size.y + CARD_PAD * 2.0 + (12.0 if total_w > room_w else 0.0))
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if total_w > room_w else ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_horizontal = 0
	_hint.text = ("Tap a card to put it back (free, once) · long-press for its rules" if total_w <= room_w
			else "Tap a card to put it back (free, once) · long-press for its rules · swipe for more")
	for entry: Dictionary in hand:
		var b: Button = Button.new()
		var uid: int = int(entry.get("uid", -1))
		b.toggle_mode = true
		b.theme_type_variation = &"HudButton"
		b.custom_minimum_size = view_size + Vector2(CARD_PAD, CARD_PAD) * 2.0
		b.set_meta(&"uid", uid)
		b.set_meta(&"name", String(entry.get("name", "?")))
		b.tooltip_text = "%s · tap to put it back" % entry.get("name", "?")
		b.add_to_group(&"tap_target")
		b.toggled.connect(func(on: bool) -> void: _toggle(b, uid, on))
		_cards.add_child(b)
		_add_card_view(b, entry, s)
		_wire_inspect(b, uid)
	_update_confirm()
	show()


## CardView scale for n cards: all of them across the panel when that keeps the card at >= MIN_FIT
## (the inspector's own floor: name, cost and stats >= 11 pt on a phone), at most as tall as the panel
## allows and MAX_SCALE. Below MIN_FIT the cards stay at MIN_FIT and the row scrolls sideways.
func card_scale(_n: int) -> float:
	return 1.0


## kc-cards-impl: the Y2+ card width for n cards: all across the panel between MIN_W and MAX_W (and
## no taller than the panel allows); below MIN_W the row scrolls sideways.
func card_width(n: int) -> float:
	var area: Vector2 = size if size.x > 0.0 else get_viewport_rect().size
	var room_h: float = area.y - (CHROME_H if compact else CHROME_H_DESKTOP) - CARD_PAD * 2.0 - 12.0
	var room_w: float = area.x - 36.0 - (n - 1) * float(_cards.get_theme_constant(&"h_separation"))
	var w: float = floorf(room_w / n - CARD_PAD * 2.0)
	while w > MIN_W and CardView.height_for(w) > room_h:
		w -= 4.0
	return clampf(w, MIN_W, MAX_W)


## The card grid lives in a sideways ScrollContainer (made once, keeps %Cards resolvable).
func _ensure_scroll() -> void:
	if _scroll != null:
		return
	var col: Node = _cards.get_parent()
	var at: int = _cards.get_index()
	_scroll = ScrollContainer.new()
	_scroll.name = "CardScroll"
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.remove_child(_cards)
	col.add_child(_scroll)
	col.move_child(_scroll, at)
	_scroll.add_child(_cards)
	_cards.owner = self
	_cards.unique_name_in_owner = true
	(col as BoxContainer).add_theme_constant_override(&"separation", 6)


## Scrolls the row so this card is fully visible (tests, keyboard focus).
func reveal_card(b: Control) -> void:
	if _scroll != null:
		_scroll.ensure_control_visible(b)


func get_card_scroll() -> ScrollContainer:
	return _scroll


## The full card face inside its toggle, plus the PUT BACK plate (hidden until marked).
func _add_card_view(b: Button, entry: Dictionary, cw: float) -> void:
	var view: Dictionary = entry.get("view", {})
	if view.is_empty():
		view = {"id": String(entry.get("id", "")), "name": entry.get("name", "?"), "cost": int(entry.get("cost", 0)),
				"type": {"UNIT": "unit", "TACTIC": "tactic"}.get(String(entry.get("type", "")), "equipment"), "side": "friend"}
	var card: Control = CARD_VIEW.instantiate()
	card.name = "CardView"
	b.add_child(card)
	card.pivot_offset = Vector2.ZERO  # CardView scales about its centre by default
	card.position = Vector2(CARD_PAD, CARD_PAD)
	card.set_card_data(view)
	card.set_card_width(cw)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c: Node in card.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate: Label = Label.new()
	plate.name = "PutBack"
	plate.text = "PUT BACK"
	plate.theme_type_variation = &"HudHeader"
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.07, 0.9)
	sb.border_color = Color(0.36, 0.84, 0.93)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(6)
	plate.add_theme_stylebox_override(&"normal", sb)
	plate.add_theme_color_override(&"font_color", Color(0.36, 0.84, 0.93))
	plate.visible = false
	b.add_child(plate)
	var fit: Callable = func() -> void:
		var h: float = plate.get_combined_minimum_size().y
		plate.position = Vector2(0, (b.size.y - h) * 0.5)
		plate.size = Vector2(b.size.x, h)
	b.resized.connect(fit)
	fit.call_deferred()
	b.set_meta(&"card_view", card)


## Long-press (touch) or right-click opens the card's rules; the press then never toggles the card.
func _wire_inspect(b: Button, uid: int) -> void:
	var state: Dictionary = {"id": 0, "fired": false, "was": false, "ms": 0}
	b.gui_input.connect(func(e: InputEvent) -> void:
		if not e is InputEventMouseButton:
			return
		var mb: InputEventMouseButton = e
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			b.accept_event()
			card_inspected.emit(uid)
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			state["id"] = int(state["id"]) + 1
			state["fired"] = false
			state["was"] = b.button_pressed
			state["ms"] = Time.get_ticks_msec()
			var my_id: int = state["id"]
			get_tree().create_timer(PressGesture.LONG_PRESS_S).timeout.connect(func() -> void:
				if int(state["id"]) == my_id and is_instance_valid(b) and b.get_global_rect().has_point(b.get_global_mouse_position()) \
						and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
					state["fired"] = true
					card_inspected.emit(uid))
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			state["id"] = int(state["id"]) + 1
			# A slow frame can delay the timer: a press held that long is a long-press all the same.
			if not bool(state["fired"]) and Time.get_ticks_msec() - int(state["ms"]) >= int(PressGesture.LONG_PRESS_S * 1000.0) \
					and b.get_global_rect().has_point(b.get_global_mouse_position()):
				state["fired"] = true
				card_inspected.emit(uid)
			if bool(state["fired"]):
				state["fired"] = false
				b.accept_event()
				b.set_pressed_no_signal(bool(state["was"])))


func close() -> void:
	hide()


func is_open() -> bool:
	return visible


func set_compact(value: bool) -> void:
	compact = value
	_keep.custom_minimum_size = Vector2(200, 64)
	_confirm.custom_minimum_size = Vector2(200, 64)


func get_card_buttons() -> Array[Node]:
	return _cards.get_children()


func get_keep_button() -> Button:
	return _keep


func get_confirm_button() -> Button:
	return _confirm


## Uids currently marked to put back.
func get_picked() -> Array[int]:
	return _picked.duplicate()


## Labels whose whole text must stay visible (tests / QA).
func get_important_labels() -> Array[Label]:
	return [%TitleLabel, _hint]


func _toggle(b: Button, uid: int, on: bool) -> void:
	if on and uid not in _picked:
		_picked.append(uid)
	elif not on:
		_picked.erase(uid)
	# Marked cards switch to the cyan KillstreakButton frame, drop 4 px and show PUT BACK (kc-da-ui:
	# the art is never dimmed to show a state).
	b.theme_type_variation = &"KillstreakButton" if on else &"HudButton"
	var card: Control = b.get_meta(&"card_view", null)
	if card != null:
		card.modulate = Color.WHITE
		if not card.has_meta(&"rest_y"):
			card.set_meta(&"rest_y", card.position.y)
		card.position.y = float(card.get_meta(&"rest_y")) + (4.0 if on else 0.0)
	var plate: Control = b.get_node_or_null("PutBack")
	if plate != null:
		plate.visible = on
	_update_confirm()


## True when the card shows its full face (kc-ui3 tests).
func has_full_card(b: Node) -> bool:
	return b.has_meta(&"card_view")


## k-art4: card art behind a card button. The art and its scrim draw behind the button
## (show_behind_parent), and the button's own styles get a see-through fill, so its frame, text
## and pressed / put-back colours stay on top. No art key: the plain button.
func _set_art(b: Button, key: StringName) -> void:
	if key == &"" or not ArtUnderlay.enabled or not CardArt.has_card(key):
		return
	var art := ArtUnderlay.new()
	art.show_behind_parent = true
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(art)
	art.set_art(key, ArtUnderlay.SCRIM_BUTTON)
	b.set_meta(&"art", true)
	b.add_theme_color_override(&"font_outline_color", Color(ArtUnderlay.SLATE, 0.9))
	b.add_theme_constant_override(&"outline_size", 4)
	_style_over_art(b)


## Re-applies the see-through copies of the current variation's styles (after a toggle).
func _style_over_art(b: Button) -> void:
	if not b.has_meta(&"art"):
		return
	for st: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		b.remove_theme_stylebox_override(st)
	for st: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var base: StyleBox = b.get_theme_stylebox(st)
		if base is StyleBoxFlat:
			var sb: StyleBoxFlat = (base as StyleBoxFlat).duplicate()
			sb.bg_color.a = minf(sb.bg_color.a, ART_FILL_ALPHA)
			b.add_theme_stylebox_override(st, sb)


func _update_confirm() -> void:
	_confirm.disabled = _picked.is_empty()
	_confirm.text = "REDRAW %d" % _picked.size()


func _finish(put_back: Array[int]) -> void:
	hide()
	confirmed.emit(put_back)

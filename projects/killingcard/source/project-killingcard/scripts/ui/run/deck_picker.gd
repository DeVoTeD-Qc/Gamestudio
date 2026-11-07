# deck_picker.gd
# Purpose: Pick cards from your deck (kc-v2-ui): the shop's Muster out (Standard Issue cards, 2 REQ
#   each) and Discharge (any other card, 3 REQ), the Rest's Drill (send 2 home). A modal sheet over the
#   screen: a title that says the rule ("Pick up to 2 · the deck never goes under 15"), the cards as
#   tiles (tap = mark / unmark, a marked tile reads GOING HOME with a dark veil and an amber frame:
#   shape and words, not colour only), and a confirm button that prices the choice ("SEND 2 HOME ·
#   4 REQ"). Long press / right click on a tile = the full card. CANCEL closes with nothing done.
# Usage: picker.open(title, rule, candidates [{index, card_id}], max, price_each, verb, have_req)
#        picker.confirmed.connect(func(indices: Array) -> void: ...)
# Dependencies: codex_view.gd (make_card_view), CardInspector.tscn, run_screen.gd builders, CardDB.
# Author: UI/UX Agent (kc-v2-ui)
extends Control

signal confirmed(indices: Array)
signal cancelled

const CodexView: GDScript = preload("res://scripts/ui/codex/codex_view.gd")
const RunScreen: GDScript = preload("res://scripts/ui/run/run_screen.gd")
const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")

var max_pick: int = 2
var price_each: int = 0
var have_req: int = -1
var verb: String = "SEND"
var marked: Array[int] = []
var _tiles: Dictionary = {}   # deck index -> Button
var _grid: GridContainer = null
var _confirm: Button = null
var _rule: Label = null
var _title: Label = null
var _inspector: Control = null
var compact: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim: ColorRect = ColorRect.new()
	scrim.color = Color(0.03, 0.04, 0.05, 0.96)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(k, 16)
	add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	margin.add_child(col)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 12)
	col.add_child(head)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	_title = RunScreen.make_label("", &"TileName", true)
	titles.add_child(_title)
	_rule = RunScreen.make_label("", &"HudSubtle", true)
	titles.add_child(_rule)
	var cancel: Button = RunScreen.make_button("CANCEL", &"HudButton", 130)
	cancel.name = "CancelButton"
	cancel.pressed.connect(func() -> void:
		hide()
		cancelled.emit())
	head.add_child(cancel)
	_confirm = RunScreen.make_button("", &"ReadyButton", 220)
	_confirm.name = "PickConfirm"
	_confirm.pressed.connect(func() -> void:
		if marked.is_empty():
			return
		var out: Array = marked.duplicate()
		hide()
		confirmed.emit(out))
	head.add_child(_confirm)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_grid = GridContainer.new()
	_grid.name = "PickGrid"
	_grid.add_theme_constant_override(&"h_separation", 8)
	_grid.add_theme_constant_override(&"v_separation", 8)
	scroll.add_child(_grid)
	_inspector = (load("res://scenes/match/CardInspector.tscn") as PackedScene).instantiate()
	add_child(_inspector)
	_inspector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inspector.hide()
	hide()


## candidates: [{index (deck index), card_id}]; max_pick 0 = any number.
func open(title: String, rule: String, candidates: Array, p_max: int, p_price_each: int, p_verb: String, p_have_req: int = -1) -> void:
	max_pick = p_max
	price_each = p_price_each
	verb = p_verb
	have_req = p_have_req
	marked.clear()
	_title.text = title
	_rule.text = rule
	for c: Node in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_tiles.clear()
	var vr: Vector2 = get_viewport_rect().size
	var tall: bool = vr.y > vr.x
	var w: float = 150.0 if (compact or tall) else 176.0
	_grid.columns = maxi(2, int((vr.x - 40.0) / (w + 8.0)))
	if tall:
		w = floorf((vr.x - 32.0 - 8.0 * 2.0) / 3.0)
		_grid.columns = 3
	var db: Node = get_tree().root.get_node_or_null("CardDB")
	for cand: Dictionary in candidates:
		var id: StringName = StringName(str(cand.get("card_id", "")))
		var card: CardData = db.get_card(id) if db != null else null
		if card == null:
			continue
		var idx: int = int(cand.get("index", -1))
		var b: Button = Button.new()
		b.name = "Pick_%d" % idx
		b.flat = true
		b.toggle_mode = true
		b.add_to_group(&"tap_target")
		var vd: Dictionary = CardInfo.view_dict(card)
		vd["banner"] = String(card.id)
		if card.standard_issue:
			vd["standard_issue"] = true
		var cv: Control = CodexView.make_card_view(vd, w)
		var csz: Vector2 = CardView.size_for(w)
		cv.size = csz
		b.custom_minimum_size = csz + Vector2(0, 26)
		b.add_child(cv)
		var tag: Label = RunScreen.make_label("TAP TO MARK", &"HudTag")
		tag.name = "Tag"
		tag.position = Vector2(4, csz.y + 2)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tag)
		var veil: ColorRect = ColorRect.new()
		veil.name = "Veil"
		veil.color = Color(0, 0, 0, 0.55)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		veil.size = csz
		veil.visible = false
		b.add_child(veil)
		b.pressed.connect(func() -> void: toggle(idx))
		RunScreen.wire_inspect_button(b, func() -> void: _inspector.open(RunScreen.card_inspect_info(card)))
		b.draw.connect(func() -> void:
			if marked.has(idx):
				b.draw_rect(Rect2(Vector2.ZERO, csz).grow(-1.0), Color("#FFB020"), false, 3.0))
		_grid.add_child(b)
		_tiles[idx] = b
	_refresh()
	show()


func toggle(idx: int) -> void:
	if marked.has(idx):
		marked.erase(idx)
	elif max_pick <= 0 or marked.size() < max_pick:
		if have_req >= 0 and price_each > 0 and (marked.size() + 1) * price_each > have_req:
			_rule.text = "Not enough REQ: %d each, you have %d." % [price_each, have_req]
			_refresh()
			return
		marked.append(idx)
	_refresh()


func get_tile(idx: int) -> Button:
	return _tiles.get(idx)


func get_confirm() -> Button:
	return _confirm


func _refresh() -> void:
	for idx: int in _tiles:
		var b: Button = _tiles[idx]
		var on: bool = marked.has(idx)
		b.set_pressed_no_signal(on)
		(b.get_node("Tag") as Label).text = "GOING HOME" if on else "TAP TO MARK"
		(b.get_node("Veil") as ColorRect).visible = on
		b.queue_redraw()
	var n: int = marked.size()
	_confirm.disabled = n == 0
	_confirm.text = "%s %d HOME" % [verb, n] if price_each <= 0 else "%s %d · %d REQ" % [verb, n, n * price_each]
	if n == 0:
		_confirm.text = "MARK A CARD"

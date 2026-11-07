# rest_screen.gd
# Purpose: The Rest step of a Run v2 map (scenes/run/Rest.tscn; run-v2.md §2.2, §9 "Rest"; kc-v2-ui).
#   Pick one of three, each a big tile with its pictogram and its exact result: +1 TICKET (max 3;
#   greyed with "TICKETS FULL" at 3), DRILL (send 2 cards of your choice home; the deck picker opens,
#   never under the floor) and FIELD-STRIP (a weapon level now: the reward screen's weapon level pick
#   opens next). A tap picks; CONFIRM commits (DRILL confirms from the picker). Then the screen says
#   what happened ("+1 ticket: 2 -> 3.") and CONTINUE goes on. Long press / right click: the full text.
# Dependencies: run_screen.gd, run_v2_views.gd, run_glyphs.gd, deck_picker.gd.
# Author: UI/UX Agent (kc-v2-ui)
extends "res://scripts/ui/run/run_screen.gd"

const RunV2Views: GDScript = preload("res://scripts/ui/run/run_v2_views.gd")
const RunGlyphs: GDScript = preload("res://scripts/ui/run/run_glyphs.gd")
const DeckPicker: GDScript = preload("res://scripts/ui/run/deck_picker.gd")

var options: Array = []
var picked: int = -1
var done: bool = false
var _tiles: Array[Button] = []
var _confirm: Button = null
var _row: BoxContainer = null
var _picker: Control = null
var _tickets_box: HBoxContainer = null
var _tickets_holder: HBoxContainer = null

@onready var _header: BoxContainer = %Header
@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _body: MarginContainer = %Body


func screen_id() -> StringName:
	return &"rest"


func _build() -> void:
	options = RunV2Views.rest_options(run())
	_title.text = "REST"
	_subtitle.text = "Make camp. Pick one."
	_tickets_holder = HBoxContainer.new()
	_tickets_holder.name = "HeaderChips"
	_tickets_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.add_child(_tickets_holder)
	_set_tickets()
	_confirm = make_button("CONFIRM", &"ReadyButton", 200)
	_confirm.name = "ConfirmButton"
	_confirm.disabled = true
	_confirm.pressed.connect(confirm)
	_header.add_child(_confirm)
	_row = BoxContainer.new()
	_row.name = "RestRow"
	_row.add_theme_constant_override(&"separation", 12)
	portrait_boxes.append(_row)
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_row)
	for i: int in options.size():
		var t: Button = _tile(options[i], i)
		_row.add_child(t)
		_tiles.append(t)
	_picker = DeckPicker.new()
	_picker.name = "DeckPicker"
	add_child(_picker)
	_picker.confirmed.connect(func(indices: Array) -> void: _commit(indices))
	if not _tiles.is_empty():
		_tiles[0].grab_focus.call_deferred()


func _set_tickets() -> void:
	clear(_tickets_holder)
	var m: Dictionary = RunV2Views.map_view(run())
	var tl: int = int(m.get("tickets", run().tickets if run() != null else 3))
	var tm: int = int(m.get("tickets_max", run().config.tickets if run() != null else 3))
	_tickets_box = make_tickets(tl, tm)
	_tickets_box.name = "Tickets"
	_tickets_holder.add_child(_tickets_box)
	_tickets_holder.add_child(make_label("%d/%d" % [tl, tm], &"HudNumber"))


func _tile(o: Dictionary, i: int) -> Button:
	var t: PickTile = make_tile()
	t.name = "Rest_%s" % String(o.get("id", i))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.min_height = 120.0
	var g: Control = RunGlyphs.make(&"node", &"rest", RunGlyphs.node_tint(&"rest"), 40.0)
	match StringName(str(o.get("id", ""))):
		&"ticket":
			g = _ticket_glyph()
		&"drill":
			g = RunGlyphs.make(&"node", &"shop", RunGlyphs.node_tint(&"shop"), 40.0)
		&"field_strip":
			g = RunGlyphs.make(&"node", &"fight", RunGlyphs.node_tint(&"fight"), 40.0)
	t.content.add_child(g)
	t.add_line(String(o.get("title", "")).to_upper(), &"TileName")
	t.add_line(String(o.get("result", "")), &"", true)
	t.add_spacer()
	var ok: bool = bool(o.get("ok", true))
	t.add_status("TAP TO PICK" if ok else String(o.get("reason", "Not possible now.")).to_upper())
	t.disabled = not ok
	t.pressed.connect(func() -> void: pick(i))
	wire_inspect_button(t, func() -> void: inspector().open({"title": String(o.get("title", "")).capitalize(), "type": "rest",
			"text": String(o.get("result", "")), "status": "" if ok else String(o.get("reason", ""))}))
	return t


func _ticket_glyph() -> Control:
	var p: Panel = Panel.new()
	p.theme_type_variation = &"TicketPip"
	p.custom_minimum_size = Vector2(26, 38)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func get_tiles() -> Array[Button]:
	return _tiles


func get_confirm_button() -> Button:
	return _confirm


func get_picker() -> Control:
	return _picker


func pick(i: int) -> void:
	if done:
		return
	picked = i
	for k: int in _tiles.size():
		(_tiles[k] as PickTile).set_selected(k == i, "PICKED", "TAP TO PICK")
	_confirm.disabled = false
	_confirm.text = "PICK 2 CARDS" if StringName(str(options[i].get("id", ""))) == &"drill" else "CONFIRM"


## CONFIRM: DRILL opens the deck picker first; the others commit at once.
func confirm() -> String:
	if done:
		if RunV2Views.override_rest.is_empty():
			goto(RunFlow.scene_for(run()))
		return ""
	if picked < 0:
		return "Pick one first."
	if StringName(str(options[picked].get("id", ""))) == &"drill":
		var r: RunProgress = run()
		var cands: Array = RunV2Views.drill_rows(r)
		if cands.is_empty() and r != null:
			for i: int in r.deck.size():
				cands.append({"index": i, "card_id": r.deck[i]})
		var floor_n: int = r.config.deck_floor if r != null else 15
		var room: int = maxi(0, (r.deck.size() if r != null else 0) - floor_n)
		_picker.compact = compact
		_picker.open("DRILL · SEND 2 HOME", "Mark up to %d cards to send home (the deck never goes under %d)." % [mini(2, room), floor_n],
				cands, mini(2, room), 0, "SEND")
		return ""
	return _commit([])


func _commit(indices: Array) -> String:
	var o: Dictionary = options[picked]
	var r: RunProgress = run()
	var t0: int = r.tickets if r != null else 0
	var deck0: int = r.deck.size() if r != null else 0
	var args: Array = [StringName(str(o.get("id", "")))]
	if not indices.is_empty():
		args.append({"deck_indices": indices})
	var res: Dictionary = RunV2Views.act_result(r, &"rest_choose", args)
	if not bool(res["ok"]):
		show_feedback(String(res["reason"]), &"")
		return String(res["reason"])
	done = true
	var line: String = String(res.get("text", ""))
	if line == "":
		line = "%s: %s" % [String(o.get("title", "")).capitalize(), String(o.get("result", ""))]
	if r != null and r.tickets != t0:
		line += "  Tickets %d -> %d." % [t0, r.tickets]
		_set_tickets()
		punch(_tickets_holder)
	if r != null and r.deck.size() != deck0 and RunV2Views.override_rest.is_empty():
		line += "  Deck %d -> %d." % [deck0, r.deck.size()]
	if not indices.is_empty() and not RunV2Views.override_rest.is_empty():
		line = "Drill: %d cards sent home. Deck %d -> %d." % [indices.size(), deck0, deck0 - indices.size()]
	show_feedback(line, &"reward")
	for t: Button in _tiles:
		t.disabled = true
	_confirm.disabled = false
	_confirm.text = "CONTINUE"
	return ""


func _apply_compact() -> void:
	if _confirm != null:
		_confirm.custom_minimum_size.y = button_height()
	for t: Button in _tiles:
		(t as PickTile).min_height = 96.0 if compact else 140.0

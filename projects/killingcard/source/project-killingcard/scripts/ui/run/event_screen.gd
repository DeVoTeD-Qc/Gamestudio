# event_screen.gd
# Purpose: The Event step of a Run v2 map (scenes/run/Event.tscn; run-v2.md §3, §9 "Event"; kc-v2-ui).
#   One card: the radio pictogram, the event's title and its two lines of scene, then 2-3 option
#   tiles. Each tile says exactly what it does ("+3 REQ.", "Lose 1 ticket: 50%."), its cost in red
#   when it has one, and its odds when it has any. Tap a tile = pick it (PICKED); CONFIRM commits it.
#   An option that can't be taken now (not enough REQ) is greyed and says why. Long press / right
#   click on a tile = its full text, or the full card it would add.
#   After CONFIRM the screen says what happened, with the numbers that changed ("+3 REQ: 7 -> 10"),
#   and CONTINUE goes on (the map, or the reward screen when the rules opened a pick).
#   Landscape: the scene card left, the options right. Portrait: stacked, options full width.
# Dependencies: run_screen.gd, run_v2_views.gd, run_glyphs.gd, RunFlow, CardInspector.tscn.
# Author: UI/UX Agent (kc-v2-ui)
extends "res://scripts/ui/run/run_screen.gd"

const RunV2Views: GDScript = preload("res://scripts/ui/run/run_v2_views.gd")
const RunGlyphs: GDScript = preload("res://scripts/ui/run/run_glyphs.gd")

var event: Dictionary = {}
var picked: int = -1
var done: bool = false
## The option's extra choice (run-v2-api.md §4 needs): {"deck_index": i} or {"terrain": id}.
var choice_args: Dictionary = {}
var _picker: Control = null
var _sub: VBoxContainer = null
var _tiles: Array[Button] = []
var _confirm: Button = null
var _row: BoxContainer = null
var _req_chip: Control = null
var _tickets_box: Control = null

@onready var _header: BoxContainer = %Header
@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _body: MarginContainer = %Body
@onready var _layout: VBoxContainer = %Layout


func screen_id() -> StringName:
	return &"event"


func _build() -> void:
	var r: RunProgress = run()
	event = RunV2Views.event_view(r)
	_title.text = "EVENT"
	_subtitle.text = "Pick one. Every result is printed on its button."
	var chips: HBoxContainer = HBoxContainer.new()
	chips.name = "HeaderChips"
	chips.add_theme_constant_override(&"separation", 12)
	chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.add_child(chips)
	var m: Dictionary = RunV2Views.map_view(r)
	var tl: int = int(m.get("tickets", r.tickets if r != null else 3))
	var tm: int = int(m.get("tickets_max", r.config.tickets if r != null else 3))
	_tickets_box = make_tickets(tl, tm)
	_tickets_box.name = "Tickets"
	chips.add_child(_tickets_box)
	_req_chip = make_req_chip(RunV2Views.req(r))
	chips.add_child(_req_chip)
	_confirm = make_button("CONFIRM", &"ReadyButton", 200)
	_confirm.name = "ConfirmButton"
	_confirm.disabled = true
	_confirm.pressed.connect(confirm)
	_header.add_child(_confirm)
	_row = BoxContainer.new()
	_row.name = "EventRow"
	_row.add_theme_constant_override(&"separation", 16)
	portrait_boxes.append(_row)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_row)
	# The scene card.
	var card: PanelContainer = PanelContainer.new()
	card.name = "SceneCard"
	card.theme_type_variation = &"HudPanelDark"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 0.8
	_row.add_child(card)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	card.add_child(col)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 10)
	head.add_child(RunGlyphs.make(&"node", &"event", RunGlyphs.node_tint(&"event"), 48.0))
	var name_l: Label = make_label(String(event.get("title", "Event")).to_upper(), &"TileName", true)
	name_l.name = "EventTitle"
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	col.add_child(head)
	var scene_l: Label = make_label(String(event.get("scene", "")), &"", true)
	scene_l.name = "SceneText"
	col.add_child(scene_l)
	col.add_child(make_label("An event never costs a ticket without saying so. Odds are always printed.", &"HudSubtle", true))
	# The options.
	var opts: VBoxContainer = VBoxContainer.new()
	opts.name = "Options"
	opts.add_theme_constant_override(&"separation", 8)
	opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(opts)
	var options: Array = event.get("options", [])
	for i: int in options.size():
		var t: Button = _option_tile(options[i], i)
		opts.add_child(t)
		_tiles.append(t)
	if event.is_empty():
		_subtitle.text = "No event here."
		_confirm.text = "CONTINUE"
		_confirm.disabled = false
		done = true
	_sub = VBoxContainer.new()
	_sub.name = "SubChoices"
	_sub.add_theme_constant_override(&"separation", 6)
	opts.add_child(_sub)
	_picker = load("res://scripts/ui/run/deck_picker.gd").new()
	_picker.name = "DeckPicker"
	add_child(_picker)
	_picker.confirmed.connect(func(indices: Array) -> void:
		if indices.is_empty():
			return
		choice_args = {"deck_index": int(indices[0])}
		var row: Dictionary = _row_for(int(indices[0]))
		(_tiles[picked] as PickTile).set_selected(true, "PICKED: %s" % String(row.get("name", "card")).to_upper())
		_confirm.disabled = false)
	if not _tiles.is_empty():
		_tiles[0].grab_focus.call_deferred()


func _row_for(deck_index: int) -> Dictionary:
	for r: Dictionary in event["options"][picked].get("choices", []):
		if int(r.get("index", -1)) == deck_index:
			return r
	return {}


func _option_tile(o: Dictionary, i: int) -> Button:
	var t: PickTile = make_tile()
	t.name = "Option%d" % i
	t.min_height = 64.0
	t.add_line(String(o.get("label", "")).to_upper(), &"TileName")
	t.add_line(String(o.get("result", "")), &"", true)
	var costs: PackedStringArray = []
	if int(o.get("cost_req", 0)) > 0:
		costs.append("Costs %d REQ" % int(o["cost_req"]))
	if int(o.get("cost_ticket", 0)) > 0:
		costs.append("Costs %d ticket" % int(o["cost_ticket"]))
	if String(o.get("odds", "")) != "":
		costs.append(String(o["odds"]))
	if not costs.is_empty():
		t.add_line(" · ".join(costs), &"EnemyLabel", true)
	var ok: bool = bool(o.get("ok", true))
	t.add_status("TAP TO PICK" if ok else String(o.get("reason", "Not possible now.")).to_upper())
	t.disabled = not ok
	t.pressed.connect(func() -> void: pick(i))
	wire_inspect_button(t, func() -> void: _inspect_option(o))
	return t


func _inspect_option(o: Dictionary) -> void:
	var cards: Array = o.get("cards", [])
	if not cards.is_empty():
		var card: CardData = card_by_id(StringName(str(cards[0])))
		if card != null:
			inspector().open(card_inspect_info(card, "%s: %s" % [String(o.get("label", "")).capitalize(), String(o.get("result", ""))]))
			return
	inspector().open({"title": String(o.get("label", "")).capitalize(), "type": "event option",
			"text": String(o.get("result", "")), "status": String(o.get("odds", ""))})


func get_option_tiles() -> Array[Button]:
	return _tiles


func get_confirm_button() -> Button:
	return _confirm


## Picks option i (tap again on another to change it). Nothing happens until CONFIRM.
func pick(i: int) -> void:
	if done:
		return
	picked = i
	choice_args = {}
	for k: int in _tiles.size():
		(_tiles[k] as PickTile).set_selected(k == i, "PICKED", "TAP TO PICK")
	clear(_sub)
	var o: Dictionary = event["options"][i]
	var needs: StringName = StringName(str(o.get("needs", "")))
	_confirm.text = "CONFIRM"
	_confirm.disabled = needs != &""
	match needs:
		&"deck_card", &"calling_card":
			var rows: Array = (o.get("choices", []) as Array).map(func(r: Dictionary) -> Dictionary:
				return {"index": int(r.get("index", -1)), "card_id": StringName(str(r.get("id", "")))})
			_picker.compact = compact
			_picker.open(String(o.get("label", "")).to_upper(), "Pick the card: %s" % String(o.get("result", "")), rows, 1, 0, "PICK")
			(_tiles[i] as PickTile).set_selected(true, "PICK A CARD")
		&"terrain":
			_sub.add_child(make_label("PICK THE GROUND FOR YOUR NEXT FIGHT", &"HudTag"))
			for t: Variant in o.get("choices", []):
				var td: Dictionary = RunV2Views.terrain_entry(t)
				var tile: PickTile = make_tile()
				tile.name = "Terrain_%s" % td["id"]
				tile.add_line(String(td["name"]).to_upper(), &"HudAccent")
				tile.add_line(String(td["text"]), &"", true)
				tile.pressed.connect(func() -> void:
					choice_args = {"terrain": td["id"]}
					for c: Node in _sub.get_children():
						if c is PickTile:
							(c as PickTile).set_selected(c == tile)
					_confirm.disabled = false)
				_sub.add_child(tile)


## CONFIRM: the rules apply the option (event_choose); the screen says what happened. CONTINUE then
## leaves. Returns "" or the refusal.
func confirm() -> String:
	if done:
		_leave()
		return ""
	if picked < 0:
		return "Pick an option first."
	var o: Dictionary = event["options"][picked]
	var before_req: int = RunV2Views.req(run())
	var args: Array = [int(o.get("index", picked))]
	if not choice_args.is_empty():
		args.append(choice_args)
	var res: Dictionary = RunV2Views.act_result(run(), &"choose_event", args)
	if not bool(res["ok"]):
		show_feedback(String(res["reason"]), &"")
		return String(res["reason"])
	done = true
	var after_req: int = RunV2Views.req(run())
	var what: String = String(res.get("text", ""))
	if what == "":
		what = String(o.get("result", ""))
	var line: String = "%s: %s" % [String(o.get("label", "")).capitalize(), what]
	if after_req != before_req:
		line += "  REQ %d -> %d." % [before_req, after_req]
		_set_req(after_req)
	show_feedback(line, &"reward")
	for t: Button in _tiles:
		t.disabled = true
	_confirm.text = "CONTINUE"
	_confirm.grab_focus.call_deferred()
	return ""


func _set_req(v: int) -> void:
	var l: Label = _req_chip.find_child("ReqValue", true, false) as Label
	if l != null:
		l.text = str(v)
	punch(_req_chip)


func _leave() -> void:
	if not RunV2Views.override_event.is_empty():
		return
	goto(RunFlow.scene_for(run()))


func _apply_compact() -> void:
	if _confirm != null:
		_confirm.custom_minimum_size.y = button_height()

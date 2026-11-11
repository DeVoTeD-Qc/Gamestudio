# shop_screen.gd
# Purpose: The Shop step of a Run v2 map (scenes/run/Shop.tscn; run-v2.md §2.3, §9 "Shop"; kc-v2-ui).
#   Spend Requisition (REQ). Left (top in portrait): the 3 cards on offer, each a full card with its
#   price on its BUY button ("BUY · 4 REQ"; "NEED 4 REQ" when you can't pay; "SOLD" once bought).
#   Right (under them in portrait): the services, each a tile with its price: MUSTER OUT a Standard
#   Issue card (2 REQ each; studio head: 2 REQ), DISCHARGE any other card (3), a PERK (6, 1 of 2) and
#   RESTOCK the 3 cards (1). Muster out / Discharge open the deck picker. The deck never goes under
#   its floor (15): the tiles say so and stop there.
#   Every buy says what happened with the numbers ("Bought Marksman: REQ 7 -> 3. Deck 20 -> 21.") and
#   punches the REQ chip. Long press / right click: every card zooms, every tile explains itself.
#   DONE leaves (the map). No tickets for sale.
# Dependencies: run_screen.gd, run_v2_views.gd, deck_picker.gd, codex_view.gd (make_card_view), CardDB.
# Author: UI/UX Agent (kc-v2-ui)
extends "res://scripts/ui/run/run_screen.gd"

const RunV2Views: GDScript = preload("res://scripts/ui/run/run_v2_views.gd")
const CodexView: GDScript = preload("res://scripts/ui/codex/codex_view.gd")
const DeckPicker: GDScript = preload("res://scripts/ui/run/deck_picker.gd")

const KIND_WORDS: Dictionary = {&"unit": "UNIT", &"tactic": "TACTIC", &"field": "FIELD", &"elite": "ELITE ★"}

var shop: Dictionary = {}
var _done: Button = null
var _req_chip: Control = null
var _cards_row: HBoxContainer = null
var _services: VBoxContainer = null
var _row: BoxContainer = null
var _buy_buttons: Array[Button] = []
var _service_tiles: Dictionary = {}
var _picker: Control = null

@onready var _header: BoxContainer = %Header
@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _body: MarginContainer = %Body
@onready var _layout: VBoxContainer = %Layout


func screen_id() -> StringName:
	return &"shop"


func _build() -> void:
	shop = RunV2Views.shop_view(run())
	_title.text = "SHOP"
	_subtitle.text = "Spend REQ. Long-press any card to zoom."
	_req_chip = make_req_chip(int(shop.get("req", RunV2Views.req(run()))))
	_header.add_child(_req_chip)
	wire_inspect_control(_req_chip, func() -> void: inspector().open({"title": "Requisition (REQ)", "type": "currency",
			"text": "Earned, never bought: win a fight +3, an elite +5, a loss +1, events +1 to +3. The shop never sells tickets.",
			"status": "You have %d REQ." % int(shop.get("req", 0))}))
	_done = make_button("DONE", &"ReadyButton", 160)
	_done.name = "DoneButton"
	_done.pressed.connect(leave)
	_header.add_child(_done)
	_row = BoxContainer.new()
	_row.name = "ShopRow"
	_row.add_theme_constant_override(&"separation", 16)
	portrait_boxes.append(_row)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ShopScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_row)
	_cards_row = HBoxContainer.new()
	_cards_row.name = "Cards"
	_cards_row.add_theme_constant_override(&"separation", 10)
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_child(_cards_row)
	_services = VBoxContainer.new()
	_services.name = "Services"
	_services.add_theme_constant_override(&"separation", 8)
	_services.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(_services)
	_picker = DeckPicker.new()
	_picker.name = "DeckPicker"
	add_child(_picker)
	_fill()
	_done.grab_focus.call_deferred()


func _apply_compact() -> void:
	if _done != null:
		_done.custom_minimum_size.y = button_height()
	if _picker != null:
		_picker.compact = compact
	if _cards_row != null and is_node_ready():
		_fill()


func _apply_portrait() -> void:
	super()
	if _cards_row != null:
		_fill()


func _card_w() -> float:
	if portrait:
		return clampf(floorf((get_viewport_rect().size.x - 72.0) / 3.0), 132.0, 196.0)
	return 172.0 if compact else 210.0


func _fill() -> void:
	clear(_cards_row)
	clear(_services)
	_buy_buttons.clear()
	_service_tiles.clear()
	var req: int = int(shop.get("req", 0))
	var w: float = _card_w()
	for c: Dictionary in shop.get("cards", []):
		_cards_row.add_child(_offer(c, req, w))
	var deck_n: int = int(shop.get("deck_size", run().deck.size() if run() != null else 0))
	var floor_n: int = int(shop.get("floor", run().config.deck_floor if run() != null else 15))
	var room: int = maxi(0, deck_n - floor_n)
	var mp: int = int(shop.get("muster_price", 2))
	var dp: int = int(shop.get("discharge_price", 3))
	var rp: int = int(shop.get("restock_price", 1))
	_service(&"muster", "MUSTER OUT · %d REQ EACH" % mp,
			"Send Standard Issue cards home, any number. Deck %d, never under %d." % [deck_n, floor_n],
			bool(shop.get("muster_can", true)) and req >= mp and room > 0 and not _muster_candidates().is_empty(),
			_why(&"muster", "NEED %d REQ" % mp if req < mp else ("DECK AT ITS FLOOR (%d)" % floor_n if room <= 0 else "PICK CARDS")),
			_open_muster)
	_service(&"discharge", "DISCHARGE · %d REQ" % dp, "Remove any other card from your deck for good (never under %d)." % floor_n,
			bool(shop.get("discharge_can", true)) and req >= dp and room > 0,
			_why(&"discharge", "NEED %d REQ" % dp if req < dp else ("DECK AT ITS FLOOR (%d)" % floor_n if room <= 0 else "PICK A CARD")),
			_open_discharge)
	for pk: Dictionary in shop.get("perks", []):
		var pp: int = int(pk.get("price", 6))
		var pidx: int = int(pk.get("index", 0))
		var can_p: bool = bool(pk.get("can_buy", true)) and req >= pp and not bool(pk.get("sold", false))
		var why_p: String = String(pk.get("reason", "")).to_upper()
		if why_p == "" or req < pp:
			why_p = "SOLD" if bool(pk.get("sold", false)) else ("NEED %d REQ" % pp if req < pp else "BUY")
		_service(StringName("perk_%d" % pidx), "PERK: %s · %d REQ" % [String(pk.get("name", "")).to_upper(), pp], String(pk.get("text", "")),
				can_p, "BUY" if can_p else why_p, func() -> void: buy_perk(pidx))
	_service(&"restock", "RESTOCK · %d REQ" % rp, "Replace the 3 cards on offer with 3 new ones from your rung.",
			bool(shop.get("restock_can", true)) and req >= rp, _why(&"restock", "NEED %d REQ" % rp if req < rp else "RESTOCK"), restock)


## The rules' reason for a service when it is closed (upper case), else the screen's own words.
func _why(key: StringName, own: String) -> String:
	var can: bool = bool(shop.get("%s_can" % key, true))
	var r: String = String(shop.get("%s_reason" % key, ""))
	return r.to_upper() if not can and r != "" else own


func _offer(c: Dictionary, req: int, w: float) -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	var idx: int = int(c.get("index", 0))
	col.name = "Offer%d" % idx
	col.add_theme_constant_override(&"separation", 6)
	var card: CardData = card_by_id(StringName(str(c.get("card_id", ""))))
	var price: int = int(c.get("price", 0))
	var kind: String = String(KIND_WORDS.get(StringName(str(c.get("kind", "unit"))), "CARD"))
	var holder: Button = Button.new()
	holder.name = "CardButton"
	holder.flat = true
	holder.add_to_group(&"tap_target")
	if card != null:
		var vd: Dictionary = CardInfoV2.view_dict(card)
		vd["banner"] = String(card.id)
		# kc-da-ui (#5): sold or out of reach: a grey cost hex and a 4 px drop; the art stays full colour.
		var out: bool = bool(c.get("sold", false)) or req < price or not bool(c.get("can_buy", true))
		if out:
			vd["cant_pay"] = true
		var cv: Control = CodexView.make_card_view(vd, w)
		cv.size = CardView.size_for(w)
		cv.position.y = 4.0 if out else 0.0
		holder.custom_minimum_size = CardView.size_for(w)
		holder.add_child(cv)
		var info: Callable = func() -> void: inspector().open(card_inspect_info(card, "%s · %d REQ" % [kind.capitalize(), price]))
		holder.pressed.connect(info)
		wire_inspect_button(holder, info)
	col.add_child(holder)
	# kc-da-ui (#6): DONE is the Shop's one amber button; BUY is steel (its price is on it).
	var b: Button = make_button("", &"HudButton", w)
	b.name = "Buy%d" % idx
	if bool(c.get("sold", false)):
		b.text = "SOLD"
		b.disabled = true
	elif req < price or not bool(c.get("can_buy", true)):
		b.text = "NEED %d REQ" % price if req < price else String(c.get("reason", "CAN'T BUY")).to_upper()
		b.disabled = true
	else:
		b.text = "BUY · %d REQ" % price
	b.custom_minimum_size = Vector2(w, button_height())
	if w < 190.0:
		# Portrait: three cards across; the price stays whole at 18 px.
		b.add_theme_font_size_override(&"font_size", 18)
	b.clip_text = true
	b.pressed.connect(func() -> void: buy(idx))
	wire_inspect_button(b, func() -> void: inspector().open({"title": "Buy %s" % (card.display_name if card != null else "card"),
			"type": "%s · %d REQ" % [kind.to_lower(), price], "text": "Adds the card to your deck for %d REQ (you have %d)." % [price, req], "status": ""}))
	col.add_child(b)
	_buy_buttons.append(b)
	return col


func _service(key: StringName, title: String, text: String, ok: bool, state: String, on_tap: Callable) -> void:
	var t: PickTile = make_tile()
	t.name = "Service_%s" % key
	t.min_height = 64.0
	t.add_line(title, &"TileName")
	t.add_line(text, &"HudSubtle", true)
	t.add_status(state)
	t.disabled = not ok
	t.pressed.connect(on_tap)
	wire_inspect_button(t, func() -> void: inspector().open({"title": title.capitalize(), "type": "shop", "text": text, "status": state.capitalize()}))
	_services.add_child(t)
	_service_tiles[key] = t


func get_buy_buttons() -> Array[Button]:
	return _buy_buttons


func get_service_tile(key: StringName) -> Button:
	return _service_tiles.get(key)


func get_picker() -> Control:
	return _picker


func get_done_button() -> Button:
	return _done


# =============================================================================
# Actions (the rules apply them; the screen refreshes from shop_view and says what happened)
# =============================================================================

func buy(idx: int) -> String:
	var c: Dictionary = {}
	for e: Dictionary in shop.get("cards", []):
		if int(e.get("index", -1)) == idx:
			c = e
	if c.is_empty():
		return "No such card."
	var card: CardData = card_by_id(StringName(str(c.get("card_id", ""))))
	var name: String = card.display_name if card != null else "card"
	return _do(&"shop_buy", [idx], "Bought %s" % name, int(c.get("price", 0)), 1, func() -> void: c["sold"] = true)


func buy_perk(index: int) -> String:
	for pk: Dictionary in shop.get("perks", []):
		if int(pk.get("index", -1)) == index:
			return _do(&"shop_buy_perk", [index], "Bought the Perk %s" % String(pk.get("name", "")),
					int(pk.get("price", 6)), 0, func() -> void: pk["sold"] = true)
	return "No such Perk."


func restock() -> String:
	return _do(&"shop_restock", [], "Restocked: 3 new cards", int(shop.get("restock_price", 1)), 0, func() -> void: pass)


## The rules take one deck index per call (shop_muster_out / shop_discharge): highest first, so the
## indices left stay valid.
func muster(indices: Array) -> String:
	return _do_each(&"shop_muster_out", indices, "Mustered out %d Standard Issue card%s" % [indices.size(), "" if indices.size() == 1 else "s"],
			int(shop.get("muster_price", 2)) * indices.size(), -indices.size(), func() -> void: pass)


func discharge(indices: Array) -> String:
	return _do_each(&"shop_discharge", indices, "Discharged %d card%s" % [indices.size(), "" if indices.size() == 1 else "s"],
			int(shop.get("discharge_price", 3)) * indices.size(), -indices.size(), func() -> void: pass)


func _do_each(method: StringName, indices: Array, what: String, price: int, deck_delta: int, preview_apply: Callable) -> String:
	var sorted: Array = indices.duplicate()
	sorted.sort()
	sorted.reverse()
	var calls: Array = []
	for i: Variant in sorted:
		calls.append([method, [int(i)]])
	return _do_calls(calls, what, price, deck_delta, preview_apply)


## Runs one shop action and reports it: "<what>: REQ 7 -> 3. Deck 20 -> 21."
func _do(method: StringName, args: Array, what: String, price: int, deck_delta: int, preview_apply: Callable) -> String:
	return _do_calls([[method, args]], what, price, deck_delta, preview_apply)


func _do_calls(calls: Array, what: String, price: int, deck_delta: int, preview_apply: Callable) -> String:
	var preview: bool = not RunV2Views.override_shop.is_empty()
	var req0: int = int(shop.get("req", 0))
	var deck0: int = int(shop.get("deck_size", run().deck.size() if run() != null else 0))
	for call: Array in calls:
		var res: Dictionary = RunV2Views.act_result(run(), call[0], call[1])
		if not bool(res["ok"]):
			if not preview:
				shop = RunV2Views.shop_view(run())
				_fill()
			show_feedback(String(res["reason"]), &"")
			return String(res["reason"])
	if preview:
		preview_apply.call()
		shop["req"] = req0 - price
		shop["deck_size"] = deck0 + deck_delta
	else:
		shop = RunV2Views.shop_view(run())
	var req1: int = int(shop.get("req", req0 - price))
	var deck1: int = int(shop.get("deck_size", deck0 + deck_delta))
	var line: String = "%s: REQ %d -> %d." % [what, req0, req1]
	if deck1 != deck0:
		line += " Deck %d -> %d." % [deck0, deck1]
	_fill()
	var l: Label = _req_chip.find_child("ReqValue", true, false) as Label
	if l != null:
		l.text = str(req1)
	punch(_req_chip)
	show_feedback(line, &"supply")
	return ""


func _muster_candidates() -> Array:
	if shop.has("muster_candidates"):
		return shop["muster_candidates"]
	var out: Array = []
	var r: RunProgress = run()
	if r == null:
		return out
	for i: int in r.deck.size():
		var card: CardData = r.resource(r.deck[i]) as CardData
		if card != null and card.standard_issue:
			out.append({"index": i, "card_id": r.deck[i]})
	return out


func _discharge_candidates() -> Array:
	if shop.has("discharge_candidates"):
		return shop["discharge_candidates"]
	var out: Array = []
	var r: RunProgress = run()
	if r == null:
		return out
	for i: int in r.deck.size():
		var card: CardData = r.resource(r.deck[i]) as CardData
		if card != null and not card.standard_issue:
			out.append({"index": i, "card_id": r.deck[i]})
	return out


func _room() -> int:
	return maxi(0, int(shop.get("deck_size", 0)) - int(shop.get("floor", 15)))


func _open_muster() -> void:
	var mp: int = int(shop.get("muster_price", 2))
	_picker.open("MUSTER OUT · %d REQ EACH" % mp, "Mark the Standard Issue cards to send home. Up to %d (the deck never goes under %d)." % [_room(), int(shop.get("floor", 15))],
			_muster_candidates(), _room(), mp, "SEND", int(shop.get("req", 0)))
	_rewire(muster)


func _open_discharge() -> void:
	var dp: int = int(shop.get("discharge_price", 3))
	_picker.open("DISCHARGE · %d REQ EACH" % dp, "Mark a card to remove for good (the deck never goes under %d)." % int(shop.get("floor", 15)),
			_discharge_candidates(), mini(_room(), 1), dp, "REMOVE", int(shop.get("req", 0)))
	_rewire(discharge)


func _rewire(cb: Callable) -> void:
	for c: Dictionary in _picker.confirmed.get_connections():
		_picker.confirmed.disconnect(c["callable"])
	_picker.confirmed.connect(func(indices: Array) -> void: cb.call(indices))


## DONE: the rules close the shop (leave_node), then the map.
func leave() -> void:
	RunV2Views.act(run(), &"leave_node", [])
	if not RunV2Views.override_shop.is_empty():
		return
	goto(RunFlow.scene_for(run()))

# lineup_builder.gd
# Purpose: Lineup builder screen (cc10, spec §4.2, RQ-15 / RQ-16). The player picks 5 cards from
#   the collection, marks one Signature and saves; DUEL takes the lineup into a duel.
#   Layout (landscape, every size from 1280x720 down to an iPhone SE's 960x540 logical canvas):
#     left : BACK · CLEARANCE meter x/12 | status panel (headline, reasons in words, notice,
#            loaner offer) | the collection grid (scrolls; owned cards first, unowned locked)
#     right: LINEUP n/5 · LEGEND n/1 · CLEAR | 5 rows [card][SIGNATURE] | SAVE · DUEL
#   Every action is one tap:
#     tap an owned card            -> add it (or take it out when it is already in)
#     tap a card in the lineup     -> take it out
#     tap SIGNATURE on a row       -> mark it (only one; the old mark moves) / tap again to unmark
#     tap USE LOANER (when offered)-> the loaner lineup from data/balance.tres, ready to duel
#     tap CLEAR / SAVE / DUEL / BACK
#     hold (or right-click) a card -> the card inspector; a locked card says how to earn it
#   Rules come from LineupRules.validate (codes) and LineupRules.should_offer_loaner; every code
#   is shown in plain words (lineup_messages.gd). Nothing here re-implements a rule: the meter and
#   the Legend counter are read-outs, the verdict is always LineupRules'.
#   Over-cap and second-Legend picks are allowed so the player sees why they don't work (the
#   meter turns red and says OVER, the reason names the cards); only a 6th card is refused, with
#   a notice saying what to do instead.
#   Saving goes through Collection.save_lineup (which validates again and emits
#   EventBus.lineup_saved itself). DUEL saves, then DuelController.set_next_duel(rival, cards)
#   and routes to Duel.tscn.
# Hooks (tests, other screens): collection / card_db (default: the autoloads), safe_area_override,
#   set_lineup(ids, signature_id, loaner), tap_* methods, get_* accessors, signals below.
# Dependencies: Collection, CardDB, EventBus, SceneRouter, LineupRules, DuelController
#   (scripts/duel/duel_controller.gd), lineup_messages.gd, lineup_row.gd, tap_hold_button.gd,
#   duel_theme.gd (cc07: wall_theme.tres + button variations), BannerCard and CardInspector.
# Author: UI/UX Agent (cc10)
extends Control

signal lineup_changed
signal lineup_saved_ok(card_ids: Array, signature_id: StringName, loaner: bool)
signal duel_requested(cards: Array)
signal back_requested

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const DuelTheme: GDScript = preload("res://scripts/ui/duel_theme.gd")
const LineupMessages: GDScript = preload("res://scripts/ui/lineup_messages.gd")
const TapHoldButton: GDScript = preload("res://scripts/ui/tap_hold_button.gd")
const DuelControllerScript: GDScript = preload("res://scripts/duel/duel_controller.gd")
const RowScene: PackedScene = preload("res://scenes/lineup/LineupRow.tscn")
const BannerCardScene: PackedScene = preload("res://scenes/card/BannerCard.tscn")
const DUEL_SCENE: String = "res://scenes/Duel.tscn"

const BASE_MARGIN: Vector2 = Vector2(32, 18)
const BASE_MARGIN_COMPACT: Vector2 = Vector2(16, 10)
const GRID_GAP: int = 10
## Room kept for the collection's vertical scroll bar.
const SCROLLBAR_W: float = 16.0
const MIN_TAP: float = 64.0
## Narrowest collection card (a little under 4:1 at 64 px tall; the lineup rows stay 4:1).
const MIN_GRID_W: float = 232.0
## Name line under each collection card.
const NAME_H: float = 24.0

## Safe area in logical px (tests / previews). Empty = read DisplayServer on phones.
var safe_area_override: Rect2 = Rect2()
## The Collection to read and save to (null = the /root/Collection autoload).
var collection: Node = null
## Card database (null = the /root/CardDB autoload).
var card_db: Node = null
var compact: bool = false
var card_size: Vector2 = Vector2(288, 72)
var grid_card_size: Vector2 = Vector2(288, 72)

var _balance: BalanceConfig
var _all: Array[CardData] = []
var _owned: Dictionary = {}           # StringName id -> true
var _cards: Array[CardData] = []       # the lineup, in slot order
var _signature: CardData = null
var _loaner: bool = false
var _loaner_offered: bool = false
var _notice: String = ""
var _result: Dictionary = {}
var _reasons: PackedStringArray = []
var _rows: Array[Node] = []
var _grid_buttons: Dictionary = {}     # StringName id -> Button

@onready var _safe_area: MarginContainer = %SafeArea
@onready var _body: HBoxContainer = %Body
@onready var _left: VBoxContainer = %LeftColumn
@onready var _right: VBoxContainer = %RightColumn
@onready var _back: Button = %BackButton
@onready var _meter: ProgressBar = %ClearanceMeter
@onready var _meter_value: Label = %ClearanceValue
@onready var _meter_title: Label = %MeterTitle
@onready var _panel: PanelContainer = %MessagePanel
@onready var _status_scroll: ScrollContainer = %MessageScroll
@onready var _status_column: VBoxContainer = %MessageColumn
@onready var _headline: Label = %Headline
@onready var _reasons_label: Label = %Reasons
@onready var _notice_label: Label = %Notice
@onready var _loaner_row: HBoxContainer = %LoanerRow
@onready var _loaner_text: Label = %LoanerText
@onready var _loaner_button: Button = %LoanerButton
@onready var _hint: Label = %CollectionHint
@onready var _scroll: ScrollContainer = %CollectionScroll
@onready var _grid: GridContainer = %CollectionGrid
@onready var _lineup_title: Label = %LineupTitle
@onready var _legend: Label = %LegendLabel
@onready var _clear: Button = %ClearButton
@onready var _rows_box: VBoxContainer = %LineupRows
@onready var _save: Button = %SaveButton
@onready var _duel: Button = %DuelButton
@onready var _inspector: Control = %CardInspector

var _meter_fill_over: StyleBoxFlat


func _ready() -> void:
	theme = DuelTheme.build()
	_meter_fill_over = StyleBoxFlat.new()
	_meter_fill_over.bg_color = ArtKit.RIVAL
	_meter_fill_over.set_corner_radius_all(6)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_status_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_status_column.minimum_size_changed.connect(_queue_fit_status)
	_left.resized.connect(_queue_fit_status)
	_back.pressed.connect(tap_back)
	_clear.pressed.connect(tap_clear)
	_save.pressed.connect(tap_save)
	_duel.pressed.connect(tap_duel)
	_loaner_button.pressed.connect(tap_loaner)
	for i: int in _lineup_size():
		var row: Node = RowScene.instantiate()
		row.name = "Row%d" % (i + 1)
		row.index = i
		_rows_box.add_child(row)
		row.card_tapped.connect(tap_lineup_slot)
		row.signature_tapped.connect(tap_signature)
		row.inspect_requested.connect(func(idx: int) -> void:
			if idx < _cards.size():
				inspect_card(_cards[idx]))
		_rows.append(row)
	get_viewport().size_changed.connect(_relayout)
	reload()
	_relayout()
	EventBus.screen_shown.emit(&"lineup")


## Re-reads the cards, the collection and the saved lineup (call after collection or data changes).
func reload() -> void:
	var db: Node = _db()
	_balance = db.get_balance() if db != null and db.get_balance() != null else BalanceConfig.new()
	_all.clear()
	if db != null:
		_all.assign(db.all_cards())
	_owned.clear()
	var col: Node = _collection()
	if col != null:
		for id: StringName in col.owned_ids():
			_owned[id] = true
	var owned_cards: Array = _all.filter(func(c: CardData) -> bool: return _owned.has(c.id))
	_loaner_offered = _balance.loaner_lineup.size() == _balance.lineup_size \
			and LineupRules.should_offer_loaner(owned_cards, _balance)
	_cards.clear()
	_signature = null
	_loaner = false
	_notice = ""
	_status_peak = 0.0
	_hint_dropped = false
	if col != null and col.has_saved_lineup():
		var saved: Dictionary = col.get_saved_lineup_ids()
		_set_lineup_internal(saved.get("cards", []), StringName(str(saved.get("signature", ""))), bool(saved.get("loaner", false)))
	_build_grid()
	_refresh()


# --- Public actions (each is what one tap does) ---------------------------------------------

## Tap on a collection card: add it, or take it out when it is already in the lineup.
func tap_collection_card(card_id: StringName) -> void:
	var c: CardData = _card(card_id)
	if c == null:
		return
	_notice = ""
	if not _owned.has(c.id) and not _in_lineup(c):
		_notice = "You don't own %s yet.%s" % [c.display_name, _how_to_earn(c)]
		_refresh()
		return
	var at: int = _index_of(c)
	if at >= 0:
		_remove_at(at)
		return
	if _cards.size() >= _lineup_size():
		_notice = "Your lineup is full (%d cards). Tap a card in your lineup to take it out first." % _lineup_size()
		_refresh()
		return
	_leave_loaner()
	_cards.append(c)
	if _cards.size() == 1 and _signature == null and c.signature_eligible:
		_signature = c
		_notice = "%s is your Signature for now (it counts double). Tap SIGNATURE on another card to move it." % c.display_name
	_changed()


## Tap on lineup slot `index`: take that card out (an empty slot only explains itself).
func tap_lineup_slot(index: int) -> void:
	if index < 0 or index >= _cards.size():
		_notice = "This slot is empty. Tap one of your cards on the left to add it."
		_refresh()
		return
	_remove_at(index)


## Tap on SIGNATURE in row `index`: mark that card (the mark moves), or unmark it.
func tap_signature(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	var c: CardData = _cards[index]
	if _signature == c:
		_signature = null
		_notice = "%s is no longer your Signature." % c.display_name
	else:
		_signature = c
		_notice = "%s is your Signature: it counts double." % c.display_name \
				if c.signature_eligible else ""
	_changed()


## Tap on USE LOANER: the loaner lineup and its Signature (spec §4.2, RQ-16).
func tap_loaner() -> void:
	if _balance.loaner_lineup.size() != _balance.lineup_size:
		return
	_cards.assign(_balance.loaner_lineup)
	_signature = _balance.loaner_signature
	_loaner = true
	_notice = "Loaner lineup in. Tap DUEL to play with it, or tap your own cards to build a lineup."
	_changed()


func tap_clear() -> void:
	_cards.clear()
	_signature = null
	_loaner = false
	_notice = "Lineup cleared."
	_changed()


## SAVE: Collection validates again and saves; returns the LineupRules result.
func tap_save() -> Dictionary:
	var col: Node = _collection()
	if col == null:
		return {}
	var ids: Array = _ids()
	var sig: StringName = _signature.id if _signature != null else &""
	var result: Dictionary = col.save_lineup(ids, sig, _loaner)
	if result.get("valid", false):
		_notice = "Lineup saved."
		lineup_saved_ok.emit(ids, sig, _loaner)
	else:
		_notice = "Not saved: fix the points above first."
	_refresh()
	return result


## DUEL: saves the lineup, hands it to the duel controller and opens the duel.
func tap_duel() -> bool:
	if not _result.get("valid", false):
		_notice = "Not ready to duel yet: fix the points above first."
		_refresh()
		return false
	var result: Dictionary = tap_save()
	if not result.get("valid", false):
		return false
	var lineup: Array = _cards.duplicate()
	DuelControllerScript.set_next_duel(DuelControllerScript.next_rival_id, lineup)
	duel_requested.emit(lineup)
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router != null:
		router.goto_scene(DUEL_SCENE)
	return true


func tap_back() -> void:
	back_requested.emit()
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router != null:
		router.goto_scene(router.SCENE_TITLE)


## Hold / right-click on a card: the inspector (a locked card only says how to earn it).
func inspect_card(c: CardData) -> void:
	if c == null:
		return
	var owned: bool = _owned.has(c.id)
	EventBus.card_inspected.emit(c.id, owned)
	if not owned and not (_loaner and _in_lineup(c)):
		_notice = "%s is locked.%s" % [c.display_name, _how_to_earn(c)]
		_refresh()
		return
	_inspector.open_card(c.to_ui_dict(), {"owner": &"player", "signature": c == _signature, "where": "lineup"})


## Replaces the lineup (restoring a save, other screens, tests). Unknown ids are dropped;
## duplicates and unowned cards are kept so their reasons show.
func set_lineup(card_ids: Array, signature_id: StringName = &"", loaner: bool = false) -> void:
	_set_lineup_internal(card_ids, signature_id, loaner)
	_notice = ""
	_changed()


# --- Read-outs --------------------------------------------------------------------------------

func get_lineup_ids() -> Array[StringName]:
	return _ids()


func get_signature_id() -> StringName:
	return _signature.id if _signature != null else &""


func is_loaner() -> bool:
	return _loaner


func is_loaner_offered() -> bool:
	return _loaner_offered


## LineupRules.validate result for the current lineup, plus "reasons" (the words shown).
func get_result() -> Dictionary:
	var r: Dictionary = _result.duplicate()
	r["reasons"] = _reasons
	return r


func get_clearance() -> int:
	return LineupMessages.total_clearance(_cards)


func get_headline_text() -> String:
	return _headline.text


func get_reasons_text() -> String:
	return _reasons_label.text


func get_notice_text() -> String:
	return _notice_label.text if _notice_label.visible else ""


func get_collection_button(card_id: StringName) -> Button:
	return _grid_buttons.get(card_id)


func get_collection_buttons() -> Array[Node]:
	return _grid.get_children()


func get_row(index: int) -> Node:
	return _rows[index]


func get_rows() -> Array[Node]:
	return _rows


func get_inspector() -> Control:
	return _inspector


func get_meter() -> ProgressBar:
	return _meter


## Controls that must be on screen, inside the safe area and not overlap (tests).
func get_key_controls() -> Dictionary:
	var keys: Dictionary = {"back": _back, "meter": _meter, "meter_value": _meter_value, "status": _panel,
			"collection": _scroll, "lineup_title": _lineup_title, "legend": _legend, "clear": _clear,
			"save": _save, "duel": _duel}
	for i: int in _rows.size():
		keys["row%d_card" % (i + 1)] = _rows[i].get_card_button()
		keys["row%d_signature" % (i + 1)] = _rows[i].get_signature_toggle()
	return keys


## Labels whose whole text must show (tests).
func get_important_labels() -> Array[Label]:
	return [_meter_title, _meter_value, _headline, _reasons_label, _notice_label, _loaner_text,
			_lineup_title, _legend]


# --- Internals --------------------------------------------------------------------------------

func _collection() -> Node:
	if collection != null:
		return collection
	return get_node_or_null("/root/Collection")


func _db() -> Node:
	if card_db != null:
		return card_db
	return get_node_or_null("/root/CardDB")


func _lineup_size() -> int:
	return _balance.lineup_size if _balance != null else 5


func _card(id: StringName) -> CardData:
	for c: CardData in _all:
		if c.id == id:
			return c
	var db: Node = _db()
	return db.get_card(id) if db != null else null


func _ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for c: CardData in _cards:
		out.append(c.id)
	return out


func _in_lineup(c: CardData) -> bool:
	return _index_of(c) >= 0


func _index_of(c: CardData) -> int:
	for i: int in _cards.size():
		if _cards[i].id == c.id:
			return i
	return -1


func _how_to_earn(c: CardData) -> String:
	var col: Node = _collection()
	var goal: UnlockGoal = col.goal_for_card(c.id) if col != null and col.has_method("goal_for_card") else null
	if goal != null and goal.description != "":
		return " To earn it: %s." % goal.description.trim_suffix(".")
	return ""


func _set_lineup_internal(card_ids: Array, signature_id: StringName, loaner: bool) -> void:
	_cards.clear()
	for id: Variant in card_ids:
		var c: CardData = _card(StringName(str(id)))
		if c != null:
			_cards.append(c)
	_signature = _card(signature_id) if signature_id != &"" else null
	_loaner = loaner


func _remove_at(index: int) -> void:
	var c: CardData = _cards[index]
	_leave_loaner()
	_cards.remove_at(index)
	if _signature != null and _signature.id == c.id and not _in_lineup(c):
		_signature = null
		_notice = "Took %s out. It was your Signature: tap SIGNATURE on another card." % c.display_name
	else:
		_notice = "Took %s out." % c.display_name
	_changed()


## Editing the loaner's cards makes it the player's own lineup (ownership is checked again).
func _leave_loaner() -> void:
	if _loaner:
		_loaner = false
		_notice = "You changed the loaner lineup, so it's your own lineup now: only cards you own count."


func _changed() -> void:
	_refresh()
	lineup_changed.emit()


func _validate() -> void:
	var sigs: Array = [_signature] if _signature != null else []
	var owned_ids: Variant = null if _loaner else _owned.keys()
	_result = LineupRules.validate(_cards, sigs, owned_ids, _balance)
	_reasons = LineupMessages.reasons(_result, _cards, sigs, owned_ids, _balance)


func _is_saved() -> bool:
	var col: Node = _collection()
	if col == null or not col.has_saved_lineup():
		return false
	var saved: Dictionary = col.get_saved_lineup_ids()
	return str(Array(saved.get("cards", []))) == str(Array(_ids())) \
			and StringName(str(saved.get("signature", ""))) == get_signature_id() \
			and bool(saved.get("loaner", false)) == _loaner


func _refresh() -> void:
	if not is_node_ready():
		return
	_validate()
	var valid: bool = _result.get("valid", false)
	var lineup_n: int = _lineup_size()
	var total: int = get_clearance()
	var cap: int = _balance.clearance_cap
	# Clearance meter: amber up to the cap; red and "OVER" past it (never colour alone).
	_meter.max_value = cap
	_meter.value = mini(total, cap)
	var over: bool = total > cap
	if over:
		_meter.add_theme_stylebox_override(&"fill", _meter_fill_over)
		_meter_value.add_theme_color_override(&"font_color", ArtKit.RIVAL)
	else:
		_meter.remove_theme_stylebox_override(&"fill")
		_meter_value.remove_theme_color_override(&"font_color")
	_meter_value.text = "%d/%d" % [total, cap]
	_meter_title.text = "CLEARANCE OVER" if over else "CLEARANCE"
	# Legend counter.
	var legends: int = LineupMessages.legend_count(_cards)
	_legend.text = "%s %d/%d" % ["LEGENDS" if legends > 1 else "LEGEND", legends, _balance.max_legends]
	if legends > _balance.max_legends:
		_legend.add_theme_color_override(&"font_color", ArtKit.RIVAL)
	else:
		_legend.remove_theme_color_override(&"font_color")
	_lineup_title.text = "%s %d/%d" % ["LOANER" if _loaner else "LINEUP", _cards.size(), lineup_n]
	# Status panel.
	if valid:
		var saved: bool = _is_saved()
		_headline.text = "SAVED · READY TO DUEL" if saved else "READY TO DUEL"
		_headline.remove_theme_color_override(&"font_color")
		_reasons_label.text = "Clearance %d of %d · Signature: %s (counts double).%s" % [total, cap,
				_signature.display_name, "" if saved else " Tap SAVE to keep it, or DUEL to play."]
	else:
		var n: int = _reasons.size()
		_headline.text = "PICK %d CARDS" % lineup_n if _cards.is_empty() \
				else "NOT READY · %d %s TO FIX" % [n, "THING" if n == 1 else "THINGS"]
		_headline.add_theme_color_override(&"font_color", ArtKit.TEXT)
		var lines: PackedStringArray = []
		for r: String in _reasons:
			lines.append("• " + r)
		_reasons_label.text = "\n".join(lines)
	_notice_label.text = _notice
	_notice_label.visible = _notice != ""
	_loaner_row.visible = _loaner_offered
	_loaner_button.disabled = _loaner
	_loaner_button.text = "LOANER IN" if _loaner else "USE LOANER"
	_loaner_text.text = "You're playing the loaner lineup. Tap your own cards to build one." if _loaner \
			else "Your cards can't make a legal lineup yet. Borrow the loaner lineup to play now."
	_save.disabled = not valid
	_duel.disabled = not valid
	_clear.disabled = _cards.is_empty()
	# Rows.
	for i: int in _rows.size():
		var c: CardData = _cards[i] if i < _cards.size() else null
		_rows[i].show_card(c, c != null and c == _signature)
	# Grid: in-lineup cards are outlined, dimmed and named "IN LINEUP · ...".
	for id: StringName in _grid_buttons:
		var b: Button = _grid_buttons[id]
		var c: CardData = _card(id)
		var inside: bool = _in_lineup(c)
		var cv: BannerCard = b.get_node("Card")
		cv.highlighted = inside
		cv.modulate = Color(1, 1, 1, 0.55) if inside else Color.WHITE
		cv.signature = c == _signature
		# The name line says IN LINEUP (words, not just the outline), so the art and pips stay clear.
		var nl: Label = b.get_node("Name")
		nl.text = ("IN LINEUP · %s" % c.display_name) if inside \
				else (c.display_name if _owned.has(c.id) else "%s · locked" % c.display_name)
		if inside:
			nl.add_theme_color_override(&"font_color", ArtKit.AMBER)
		else:
			nl.remove_theme_color_override(&"font_color")


func _build_grid() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_grid_buttons.clear()
	# Owned cards first (album order), then the locked ones.
	var order: Array[CardData] = []
	for c: CardData in _all:
		if _owned.has(c.id):
			order.append(c)
	for c: CardData in _all:
		if not _owned.has(c.id):
			order.append(c)
	for c: CardData in order:
		var b: Button = TapHoldButton.new()
		b.name = "Card_%s" % c.id
		b.theme_type_variation = &"HandCard"
		b.custom_minimum_size = grid_card_size + Vector2(0, NAME_H)
		b.add_to_group(&"tap_target")
		var cv: BannerCard = BannerCardScene.instantiate()
		cv.name = "Card"
		cv.custom_minimum_size = Vector2.ZERO
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cv)
		cv.configure(c)
		cv.locked = not _owned.has(c.id)
		# Board-size cards draw no name (cc14: names from 112 px tall), so the name sits under it.
		var name_label: Label = Label.new()
		name_label.name = "Name"
		name_label.text = c.display_name if _owned.has(c.id) else "%s · locked" % c.display_name
		name_label.theme_type_variation = &"Caption"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(name_label)
		var id: StringName = c.id
		b.tapped.connect(func() -> void: tap_collection_card(id))
		b.inspect_requested.connect(func() -> void: inspect_card(_card(id)))
		_grid.add_child(b)
		_grid_buttons[id] = b
	_place_card_parts()


func _place_card_parts() -> void:
	for b: Node in _grid.get_children():
		var cv: Control = b.get_node("Card")
		cv.position = Vector2.ZERO
		cv.size = grid_card_size
		var nl: Control = b.get_node("Name")
		nl.position = Vector2(0, grid_card_size.y)
		nl.size = Vector2(grid_card_size.x, NAME_H)


# --- Layout -----------------------------------------------------------------------------------

var _fit_queued: bool = false
## Tallest the status text has been on this screen: the panel never shrinks back, so the
## collection grid below it doesn't jump under the player's finger between taps.
var _status_peak: float = 0.0
var _hint_dropped: bool = false


func _queue_fit_status() -> void:
	if not _fit_queued:
		_fit_queued = true
		_fit_status.call_deferred()


## The status panel grows with its text, but always leaves one full row of the collection in
## view. When space runs short the "YOUR CARDS" hint goes first; only past that does the status
## text scroll (no reachable lineup gets there on a 960x540 phone canvas; tests check it).
func _fit_status() -> void:
	_fit_queued = false
	if not is_inside_tree():
		return
	# Autowrap labels report their height for their current width: wait until the column has its
	# final width, or a one-frame narrow layout would read as a tall panel (and stick, see peak).
	var vbar: VScrollBar = _status_scroll.get_v_scroll_bar()
	var want_w: float = _status_scroll.size.x - (vbar.size.x if vbar.visible else 0.0)
	var settled: bool = _status_scroll.size.x >= 32.0 and absf(_status_column.size.x - want_w) <= 1.0
	for ch: Node in _status_column.get_children():
		if (ch as Control).visible and absf((ch as Control).size.x - _status_column.size.x) > 1.0:
			settled = false  # a label just shown is still 1 px wide (one word per line)
	if not settled:
		_fit_queued = true
		get_tree().process_frame.connect(_fit_status, CONNECT_ONE_SHOT)
		return
	var font_h: float = _reasons_label.get_theme_font(&"font").get_height(_reasons_label.get_theme_font_size(&"font_size"))
	var baseline: float = _headline.get_combined_minimum_size().y + 3.0 * font_h \
			+ _status_column.get_theme_constant(&"separation")
	var need: float = maxf(_status_column.get_combined_minimum_size().y, maxf(baseline, _status_peak))
	var sep: float = float(_left.get_theme_constant(&"separation"))
	var panel_pad: float = _panel.get_theme_stylebox(&"panel").get_minimum_size().y
	var header_h: float = (%Header as Control).get_combined_minimum_size().y
	var hint_h: float = _hint.get_combined_minimum_size().y + sep
	var room: float = _left.size.y - header_h - sep - panel_pad - sep - grid_card_size.y - NAME_H - 2.0
	var show_hint: bool = not _hint_dropped and need <= room - hint_h
	_hint_dropped = not show_hint
	_hint.visible = show_hint
	if show_hint:
		room -= hint_h
	var h: float = minf(need, maxf(room, 0.0))
	_status_peak = maxf(_status_peak, h)
	if not is_equal_approx(_status_scroll.custom_minimum_size.y, h):
		_status_scroll.custom_minimum_size.y = h


## True when the status text needs scrolling to be read in full (tests).
func status_scrolls() -> bool:
	return _status_column.get_combined_minimum_size().y > _status_scroll.custom_minimum_size.y + 0.5


## Top of the collection view in this control's coordinates (tests: the grid must not jump).
func collection_top() -> float:
	return _scroll.get_global_rect().position.y


func _relayout() -> void:
	if not is_node_ready():
		return
	var logical: Vector2 = get_viewport_rect().size
	compact = logical.y < ScreenProfile.COMPACT_HEIGHT
	var margin_lt: Vector2 = BASE_MARGIN_COMPACT if compact else BASE_MARGIN
	var margin_rb: Vector2 = margin_lt
	var on_phone: bool = OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")
	if on_phone or safe_area_override.has_area():
		var window: Vector2 = Vector2(DisplayServer.window_get_size())
		var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
		if safe_area_override.has_area():
			window = logical
			safe = safe_area_override
		if window.x > 0.0 and window.y > 0.0 and safe.size.x > 0.0:
			var to_canvas: Vector2 = logical / window
			margin_lt = margin_lt.max(safe.position * to_canvas)
			margin_rb = margin_rb.max((window - safe.end) * to_canvas)
	_safe_area.add_theme_constant_override(&"margin_left", int(ceilf(margin_lt.x)))
	_safe_area.add_theme_constant_override(&"margin_top", int(ceilf(margin_lt.y)))
	_safe_area.add_theme_constant_override(&"margin_right", int(ceilf(margin_rb.x)))
	_safe_area.add_theme_constant_override(&"margin_bottom", int(ceilf(margin_rb.y)))
	_inspector.set_safe_margins(margin_lt, margin_rb)
	_inspector.compact = compact

	var avail_w: float = logical.x - ceilf(margin_lt.x) - ceilf(margin_rb.x)
	var gap: int = 6 if compact else 8
	card_size = Vector2(256, 64) if compact else Vector2(288, 72)
	var toggle_w: float = 112.0 if compact else 136.0
	for row: Node in _rows:
		row.set_sizes(card_size, toggle_w, 16 if compact else 18)
		row.add_theme_constant_override(&"separation", gap)
	_rows_box.add_theme_constant_override(&"separation", gap)
	_right.add_theme_constant_override(&"separation", gap)
	_left.add_theme_constant_override(&"separation", gap)
	var right_w: float = card_size.x + gap + toggle_w
	_right.custom_minimum_size.x = right_w
	var body_sep: int = _body.get_theme_constant(&"separation")
	var left_w: float = avail_w - right_w - body_sep
	var inner: float = left_w - SCROLLBAR_W
	# As many columns as fit at >= MIN_GRID_W (about 3.6:1 at 64 px), so less scrolling.
	var cols: int = maxi(1, int(floorf((inner + GRID_GAP) / (MIN_GRID_W + GRID_GAP))))
	var gw: float = minf(card_size.x, floorf((inner - GRID_GAP * (cols - 1)) / cols))
	grid_card_size = Vector2(gw, maxf(MIN_TAP, roundf(gw / 4.0)))
	_grid.columns = cols
	for b: Node in _grid.get_children():
		(b as Control).custom_minimum_size = grid_card_size + Vector2(0, NAME_H)
	_place_card_parts()
	_queue_fit_status()
	_hint.text = "YOUR CARDS · tap to add or take out · hold for details" if not compact \
			else "YOUR CARDS · tap to add · hold for details"
	_refresh()

# reward_screen.gd
# Purpose: Reward offers between matches (p11, scenes/run/Reward.tscn). Shows RunState's current
#   offer and resolves it with one tap, then the next offer (same screen) or the run map:
#   - Supply Drop (after a win): RunConfig.supply_drop_choices cards as CardView (fed by
#     card_info.view_dict) with a readable rules line under each. Tap a card to add it to the
#     deck. DETAILS opens the card inspector (full rules and keywords) without choosing.
#   - Weapon level: attachments for the Primary (stat changes, keywords, rules text).
#   - Perk offer: Perks you don't own (slots used / total in the subtitle).
#   SKIP declines any offer. Each offer announces EventBus.screen_shown(&"reward_<kind>").
#   Phone: cards scale 0.8-1.3x to the room left (>= 0.8x keeps name / cost / stats >= 11 pt).
# Dependencies: run_screen.gd, pick_tile.gd, CardView.tscn, CardInspector.tscn, card_info.gd,
#   RunState, RunFlow, RewardOffers.
# Author: UI/UX Agent (p11)
extends "res://scripts/ui/run/run_screen.gd"

const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")
const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/match/CardView.tscn")
const INSPECTOR_SCENE: PackedScene = preload("res://scenes/match/CardInspector.tscn")
const MIN_CARD_SCALE: float = 0.8
const MAX_CARD_SCALE: float = 1.3
const KIND_TITLES: Dictionary = {
	RewardOffers.KIND_SUPPLY_DROP: "SUPPLY DROP",
	RewardOffers.KIND_ATTACHMENT: "WEAPON LEVEL",
	RewardOffers.KIND_PERK: "PERK OFFER",
}

## The offer on screen ({kind, match, options}); {} when none.
var offer: Dictionary = {}
## Option tiles in offer order (PickTile).
var tiles: Array[PickTile] = []
var detail_buttons: Array[Button] = []
## CardView per Supply Drop option.
var card_views: Array[Control] = []

var _skip_button: Button = null
var _options: HBoxContainer = null
var _inspector: Control = null
var _card_holders: Array[Control] = []
var _rules_labels: Array[Label] = []

@onready var _header: HBoxContainer = %Header
@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _body: MarginContainer = %Body


func screen_id() -> StringName:
	return StringName("reward_" + String(offer.get("kind", "none")))


func _build() -> void:
	_skip_button = make_button("SKIP", &"HudButton", 140)
	_skip_button.name = "SkipButton"
	_skip_button.pressed.connect(skip)
	_header.add_child(_skip_button)
	var center: CenterContainer = CenterContainer.new()
	_body.add_child(center)
	_options = HBoxContainer.new()
	_options.name = "Options"
	_options.add_theme_constant_override(&"separation", 16)
	center.add_child(_options)
	_inspector = INSPECTOR_SCENE.instantiate()
	add_child(_inspector)
	resized.connect(_fit_cards)
	show_offer()


func _apply_compact() -> void:
	if _skip_button != null:
		_skip_button.custom_minimum_size.y = button_height()
	_fit_cards()


## Rebuilds the options for RunState's current offer.
func show_offer() -> void:
	var r: RunProgress = run()
	offer = r.current_offer() if r != null else {}
	clear(_options)
	tiles.clear()
	detail_buttons.clear()
	card_views.clear()
	_card_holders.clear()
	_rules_labels.clear()
	if offer.is_empty():
		_title.text = "NO REWARD"
		_subtitle.text = ""
		_skip_button.text = "CONTINUE"
		return
	var kind: StringName = offer["kind"]
	var pending: int = r.pending_offers.size()
	_title.text = String(KIND_TITLES.get(kind, "REWARD"))
	if pending > 1:
		_title.text += "  ·  1 OF %d REWARDS" % pending
	_skip_button.text = "SKIP"
	match kind:
		RewardOffers.KIND_SUPPLY_DROP:
			_subtitle.text = "Tap a card to add it to your deck (%d cards now)." % r.deck.size()
		RewardOffers.KIND_ATTACHMENT:
			var primary: String = RunFlow.names_of(r, [r.primary], "your weapon")
			_subtitle.text = "%s levelled up to level %d. Tap an attachment to fit it. Fitted: %s." % [
					primary, r.weapon_level + 1, RunFlow.names_of(r, r.attachments)]
		RewardOffers.KIND_PERK:
			_subtitle.text = "Tap a Perk to take it. Perk slots: %d of %d used (%s)." % [
					r.perks.size(), r.config.perk_slots, RunFlow.names_of(r, r.perks)]
	var options: Array = offer["options"]
	for i: int in options.size():
		var res: Resource = r.resource(StringName(options[i]))
		var tile: PickTile = _card_tile(res as CardData) if res is CardData else _item_tile(res as LoadoutItem)
		tile.name = "Option%d" % i
		tile.pressed.connect(choose.bind(i))
		_options.add_child(tile)
		tiles.append(tile)
	_fit_cards()
	# Keyboard / controller start on the first option; on touch screens a focus frame on one
	# option would read as "already picked".
	if not tiles.is_empty() and not DisplayServer.is_touchscreen_available():
		tiles[0].grab_focus.call_deferred()
	var bus: Node = RunFlow.event_bus()
	if bus != null and is_node_ready():
		bus.screen_shown.emit(screen_id())


## Takes option i of the current offer (one tap). Returns "" or RunState's reason.
func choose(i: int) -> String:
	var err: String = RunFlow.run_state().choose_offer(i)
	if err == "":
		# Deferred: the tapped tile is still inside its own pressed signal.
		_next.call_deferred()
	return err


## SKIP: declines the current offer. Returns "" or RunState's reason.
func skip() -> String:
	if offer.is_empty():
		goto(RunFlow.scene_for(run()))
		return ""
	var err: String = RunFlow.run_state().skip_offer()
	if err == "":
		_next.call_deferred()
	return err


func open_details(i: int) -> void:
	var r: RunProgress = run()
	var card: CardData = r.resource(StringName(offer["options"][i])) as CardData
	if card == null:
		return
	_inspector.open({
		"view": CardInfo.view_dict(card), "title": card.display_name, "type": CardInfo.type_line(card),
		"text": card.text, "keywords": CardInfo.keywords(card),
		"status": "Supply Drop: close this, then tap the card to add it to your deck.",
	})


func get_inspector() -> Control:
	return _inspector


func _next() -> void:
	var r: RunProgress = run()
	if r != null and r.phase == RunProgress.PHASE_REWARDS:
		show_offer()
	else:
		goto(RunFlow.scene_for(r))


func _card_tile(card: CardData) -> PickTile:
	var tile: PickTile = make_tile()
	var holder: Control = Control.new()
	holder.name = "CardHolder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.content.add_child(holder)
	var view: Control = CARD_VIEW_SCENE.instantiate()
	holder.add_child(view)
	view.set_card_data(CardInfo.view_dict(card))
	_ignore_mouse(view)
	var rules: String = card.text
	if rules == "":
		var kws: Array[Dictionary] = CardInfo.keywords(card)
		rules = "%s: %s" % [kws[0]["name"], kws[0]["text"]] if not kws.is_empty() else CardInfo.type_line(card)
	var label: Label = tile.add_line(rules)
	label.name = "RulesLabel"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	tile.content.add_child(row)
	var take: Label = make_label("TAP TO TAKE", &"HudAccent")
	take.mouse_filter = Control.MOUSE_FILTER_IGNORE
	take.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	take.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(take)
	var details: Button = make_button("DETAILS", &"HudButton", 110)
	details.name = "DetailsButton"
	details.pressed.connect(open_details.bind(card_views.size()))
	row.add_child(details)
	detail_buttons.append(details)
	card_views.append(view)
	_card_holders.append(holder)
	_rules_labels.append(label)
	return tile


func _item_tile(item: LoadoutItem) -> PickTile:
	var tile: PickTile = make_tile()
	tile.custom_minimum_size.x = 360
	tile.min_height = 260
	var r: RunProgress = run()
	tile.add_line(item.display_name.to_upper(), &"TileName")
	var tag: String = String(RunFlow.SLOT_WORDS.get(item.slot, "")).to_upper()
	if item.slot == DataEnums.LoadoutSlot.ATTACHMENT:
		tag += "  ·  FOR " + RunFlow.names_of(r, [r.primary], "").to_upper()
	tile.add_line(tag, &"HudTag", false)
	var effect: String = RunFlow.item_effect_line(item)
	if effect != "":
		tile.add_line(effect, &"FriendlyLabel")
	# Short texts ("+1 FP.") only repeat the stat line.
	if item.text != "" and (effect == "" or item.text.length() > 16):
		tile.add_line(item.text)
	tile.add_spacer()
	tile.add_status("TAP TO TAKE")
	return tile


func _safe_area_changed() -> void:
	_fit_cards()


## Card scale for the Supply Drop: as big as the body allows, 0.8x-1.3x.
func _fit_cards() -> void:
	if card_views.is_empty() or _body == null or _body.size.y <= 0.0:
		return
	# Room left for the card: body minus the tile's margins and gaps, the rules lines and the
	# TAP TO TAKE / DETAILS row. Three rules lines when the card still gets 0.8x, else two.
	var label: Label = _rules_labels[0]
	var line_h: float = label.get_line_height() + label.get_theme_constant(&"line_spacing")
	var row_h: float = button_height()
	# From the screen, not _body.size: an oversized card would have grown the body already.
	var room: Vector2 = size - Vector2(
			_safe_area.get_theme_constant(&"margin_left") + _safe_area.get_theme_constant(&"margin_right"),
			_safe_area.get_theme_constant(&"margin_top") + _safe_area.get_theme_constant(&"margin_bottom")
			+ _header.get_combined_minimum_size().y + %Layout.get_theme_constant(&"separation"))
	var max_lines: int = 3
	var by_h: float = (room.y - (28.0 + line_h * max_lines + row_h)) / CardView.BASE_SIZE.y
	if by_h < MIN_CARD_SCALE:
		max_lines = 2
		by_h = (room.y - (28.0 + line_h * max_lines + row_h)) / CardView.BASE_SIZE.y
	var n: int = card_views.size()
	var by_w: float = (room.x - 16.0 * (n - 1) - 28.0 * n) / (CardView.BASE_SIZE.x * n)
	var s: float = clampf(minf(by_h, by_w), MIN_CARD_SCALE, MAX_CARD_SCALE)
	for i: int in n:
		var view: Control = card_views[i]
		view.pivot_offset = Vector2.ZERO  # CardView pivots on its centre; scale from the corner
		view.scale = Vector2(s, s)
		view.position = Vector2.ZERO
		_card_holders[i].custom_minimum_size = CardView.BASE_SIZE * s
		_rules_labels[i].custom_minimum_size.x = CardView.BASE_SIZE.x * s
		_rules_labels[i].max_lines_visible = max_lines
		detail_buttons[i].custom_minimum_size.y = row_h
	for tile: PickTile in tiles:
		tile.custom_minimum_size.x = CardView.BASE_SIZE.x * s + 28.0


## Card scale in use (tests).
func get_card_scale() -> float:
	return card_views[0].scale.x if not card_views.is_empty() else 0.0


static func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_mouse(child)

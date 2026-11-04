# match_screen.gd
# Purpose: CardZone match screen layout (cz10), phone landscape first, on a mock per-seat view.
#   Layout (anchors + containers; this script only sizes things from the room the screen has):
#     top bar:  MENU · YOU (health, Bounty, Down) · ZONE TRACK (round, Zone n/14, route, next cards) ·
#               RIVAL (health, Down, Bounty, loadout count, held count; held cards never shown) · INFO
#     left:     Ridge Hollow map (cz16 CzMap, >= 416 px wide so every tile is >= 64 px / 44 pt),
#               under it your LINE (cards played this turn, in order) as chips
#     right:    NEXT HAND = the loadout strip: the top of your loadout down to your next hand, as
#               full-size cards (held cards outlined + HOLD, Hits on top marked Down), with a header
#               that sums Brace and counts the cards below · your HAND (default 5 + free Hits).
#   Cards are cz16 CzCard at the art direction's compact size (84x118 pt, larger on desktop), fanned
#   when space is short with >= 64 px / 44 pt of each card exposed.
#   Pattern adapted from CallingCard scripts/ui/duel_screen.gd (cc07): safe-area margins from
#   DisplayServer (or safe_area_override in tests / previews), compact flag below 640 px height,
#   get_key_controls() / get_important_labels() for the layout tests, the inspector as an overlay.
# State: show_state(Dictionary) with the per-seat view shape in mock_match_data.gd; every id is a
#   CardDB id. cz11 replaces the mock with cz07's view(state, seat). card_lookup turns an id into a
#   CardData (default: CardDB.get_card).
# Signals for cz11: card_tapped(zone, index, card_id), area_tapped(area_id), menu_requested,
#   card_inspected(card_id, zone). With mock_interactions = true a tap only selects; INFO inspects it.
# Dependencies: EventBus, SceneRouter (MENU in mock mode), CardDB, Settings, screen_profile.gd,
#   match_theme.gd, mock_match_data.gd, fan_row.gd, line_chip.gd, zone_track.gd, player_panel.gd,
#   card_inspector.gd, cz16 CzCard / CzMap / CzAreaTile.
# Author: UI/UX Agent (cz10)
extends Control

signal card_tapped(zone: StringName, index: int, card_id: StringName)
signal area_tapped(area_id: StringName)
signal menu_requested
signal card_inspected(card_id: StringName, zone: StringName)

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const MatchTheme: GDScript = preload("res://scripts/ui/match_theme.gd")
const MockMatchData: GDScript = preload("res://scripts/ui/mock_match_data.gd")
const LineChip: GDScript = preload("res://scripts/ui/line_chip.gd")
const TapHoldButton: GDScript = preload("res://scripts/ui/tap_hold_button.gd")
const CARD_SCENE: PackedScene = preload("res://scenes/card/CzCard.tscn")

const BASE_MARGIN: Vector2 = Vector2(32, 18)
const BASE_MARGIN_COMPACT: Vector2 = Vector2(16, 10)
const MIN_TAP_PX: float = 64.0
const MAX_CARD_H: float = 210.0
## Map width floor: a 64 pt ring tile is then >= 64 px tall (>= 44 pt on every target screen).
const MIN_MAP_W: float = 416.0
const LINE_COLUMNS: int = 3
const LINE_ROWS: int = 2
## Room above the strip for cz16's HOLD tag (drawn above a held card's top edge), in card pt.
const HOLD_TAG_PT: float = 10.0
const HAND_CAPACITY: int = 7
const STRIP_CAPACITY: int = 6
const ROUTE_LETTER: String = "ABC"

## Safe area in logical px (tests / previews). Empty = read DisplayServer on phones.
var safe_area_override: Rect2 = Rect2()
## Points per logical px (tests). 0 = from the real window via ScreenProfile.
var points_per_px_override: float = 0.0
var mock_interactions: bool = true
var card_lookup: Callable = func(id: StringName) -> CardData: return CardDB.get_card(id)
var compact: bool = false
var points_per_px: float = 1.0
var card_px: Vector2 = Vector2(117, 164)

var _state: Dictionary = {}
var _selected: Control = null
var _selected_area: StringName = &""
var _sep: int = 8

@onready var _safe_area: MarginContainer = %SafeArea
@onready var _column: VBoxContainer = %Column
@onready var _top_bar: HBoxContainer = %TopBar
@onready var _menu: Button = %MenuButton
@onready var _you: Button = %YouPanel
@onready var _zone: Button = %ZoneTrack
@onready var _rival: Button = %RivalPanel
@onready var _info: Button = %InfoButton
@onready var _body: HBoxContainer = %Body
@onready var _left: VBoxContainer = %LeftColumn
@onready var _map: CzMap = %MapView
@onready var _line_header: Label = %LineHeader
@onready var _line: GridContainer = %LineChips
@onready var _right: VBoxContainer = %RightColumn
@onready var _strip_header: Label = %StripHeader
@onready var _strip: Container = %StripCards
@onready var _hand: Container = %HandCards
@onready var _inspector: Control = %CardInspector


func _ready() -> void:
	theme = MatchTheme.build()
	_menu.pressed.connect(_on_menu)
	_info.pressed.connect(_on_info)
	_you.side = &"you"
	_rival.side = &"rival"
	for p: Button in [_you, _rival]:
		var side: StringName = p.side
		p.tapped.connect(func() -> void: inspect_player(side))
		p.inspect_requested.connect(func() -> void: inspect_player(side))
	_zone.tapped.connect(inspect_zone)
	_zone.inspect_requested.connect(inspect_zone)
	_strip.capacity = STRIP_CAPACITY
	_hand.capacity = HAND_CAPACITY
	_strip.valign = 1.0
	_hand.valign = 1.0  # the hand hugs the bottom edge (thumb reach)
	_line.columns = LINE_COLUMNS
	get_viewport().size_changed.connect(_relayout)
	EventBus.round_started.connect(_on_round_started)
	if _state.is_empty():
		_state = MockMatchData.mid_state()
	_relayout()
	EventBus.screen_shown.emit(&"match")
	print("Match: ready")


# --- State ---------------------------------------------------------------------

func show_state(state: Dictionary) -> void:
	_state = state.duplicate(true)
	if is_node_ready():
		_render()


func get_state() -> Dictionary:
	return _state


func _render() -> void:
	if _state.is_empty() or not is_node_ready():
		return
	_selected = null
	var you: Dictionary = _state["you"]
	var rival: Dictionary = _state["rival"]
	_you.setup(&"you", you)
	_rival.setup(&"rival", rival)
	_zone.setup(int(_state["zone_index"]), int(_state["route"]), int(_state["round"]))
	_zone.set_short_title(compact)
	_render_map()
	_render_line(you["line"])
	# Strip: top of the loadout = next hand (armour). Held cards are the first non-Hit cards.
	var held: Array = you["held"]
	var held_left: Array = held.duplicate()
	var non_hit: int = 0
	var brace: int = 0
	_clear(_strip)
	var next: Array = you["next"]
	for i: int in next.size():
		var c: CardData = card_lookup.call(next[i])
		var is_hit: bool = c.is_hit()
		var is_held: bool = not is_hit and non_hit < held.size() and held_left.has(c.id)
		if is_held:
			held_left.erase(c.id)
		if not is_hit:
			non_hit += 1
		brace += c.brace
		_add_card(_strip, c, &"next", i, is_held, is_hit)
	_strip_header.text = "NEXT HAND = ARMOUR · BRACE %d · %d HELD · +%d BELOW" % [brace, held.size(), int(you["loadout_rest"])]
	_clear(_hand)
	var hand: Array = you["hand"]
	for i: int in hand.size():
		_add_card(_hand, card_lookup.call(hand[i]), &"hand", i, false, false)
	_refresh_buttons()


func _render_map() -> void:
	var areas: Array = []
	var gassed: Array = []
	for a: AreaData in CardDB.all_areas():
		var st: Dictionary = _state["areas"].get(a.id, {})
		var piles: Array = []
		for p: Dictionary in st.get("piles", []):
			piles.append({"rarity": card_lookup.call(p["card"]).rarity_letter(), "count": int(p["count"])})
		if st.get("drop", &"") != &"":
			piles.append({"rarity": card_lookup.call(st["drop"]).rarity_letter(), "drop": true})
		areas.append({"id": a.id, "name": a.display_name, "cover": a.cover,
				"core": a.tier == DataEnums.AreaTier.CORE, "piles": piles})
		if st.get("gas", false):
			gassed.append(a.id)
	_map.configure(areas)
	var pawns: Dictionary = {}
	pawns[_state["you"]["area"]] = [&"player"]
	var r_area: StringName = _state["rival"]["area"]
	pawns[r_area] = (pawns.get(r_area, []) as Array) + [&"ai"]
	_map.set_state({"gassed": gassed, "pawns": pawns, "selected": _selected_area})
	# A touch layer on each tile: tap = select (cz11: move / loot), long-press / right-click = inspect.
	for t: CzAreaTile in _map.tiles():
		var b: Button = TapHoldButton.new()
		b.name = "Touch"
		b.theme_type_variation = &"TileButton"
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_to_group(&"tap_target")
		var id: StringName = t.area_id
		b.tapped.connect(func() -> void: _on_area_tapped(id))
		b.inspect_requested.connect(func() -> void: inspect_area(id))
		t.add_child(b)


func _render_line(entries: Array) -> void:
	_clear(_line)
	for i: int in entries.size():
		var e: Dictionary = entries[i]
		var att: Array[CardData] = []
		for a: StringName in e.get("attached", []):
			att.append(card_lookup.call(a))
		var chip: Button = LineChip.new()
		chip.setup(card_lookup.call(e["card"]), att, i)
		chip.custom_minimum_size = Vector2(0, MIN_TAP_PX)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.tapped.connect(func() -> void: _on_card_tapped(chip, &"line", chip.index, chip.card_id))
		chip.inspect_requested.connect(func() -> void: _inspect_line_chip(chip))
		_line.add_child(chip)
	_line_header.text = ("LINE · %d PLAYED THIS TURN" % entries.size()) if not entries.is_empty() else "LINE · NOTHING PLAYED YET"


func _add_card(row: Container, c: CardData, zone: StringName, i: int, held: bool, down: bool) -> void:
	var card: CzCard = CARD_SCENE.instantiate()
	card.layout_mode_override = "compact"
	card.configure(c)
	card.held = held
	card.down = down
	card.set_meta(&"zone", zone)
	card.set_meta(&"index", i)
	card.set_meta(&"card_id", c.id)
	card.add_to_group(&"tap_target")
	card.tapped.connect(func(cc: CzCard) -> void: _on_card_tapped(cc, zone, i, c.id))
	card.inspect_requested.connect(func(cc: CzCard) -> void: _inspect_card_view(cc))
	row.add_child(card)


func _clear(row: Node) -> void:
	for c: Node in row.get_children():
		row.remove_child(c)
		c.queue_free()


func _refresh_buttons() -> void:
	_info.disabled = _selected == null and _selected_area == &""


# --- Layout --------------------------------------------------------------------

func _relayout() -> void:
	var logical: Vector2 = get_viewport_rect().size
	compact = logical.y < ScreenProfile.COMPACT_HEIGHT
	points_per_px = points_per_px_override
	if points_per_px <= 0.0:
		var window: Vector2 = Vector2(DisplayServer.window_get_size())
		points_per_px = ScreenProfile.points_per_px(window, ScreenProfile.screen_scale(), Settings.ui_scale) \
				if window.x > 1.0 and DisplayServer.get_name() != "headless" else 1.0
	var margins: Array[Vector2] = safe_margins(logical)
	var lt: Vector2 = margins[0]
	var rb: Vector2 = margins[1]
	_safe_area.add_theme_constant_override(&"margin_left", int(lt.x))
	_safe_area.add_theme_constant_override(&"margin_top", int(lt.y))
	_safe_area.add_theme_constant_override(&"margin_right", int(rb.x))
	_safe_area.add_theme_constant_override(&"margin_bottom", int(rb.y))
	_inspector.set_safe_margins(lt, rb)
	var inner: Vector2 = logical - Vector2(int(lt.x) + int(rb.x), int(lt.y) + int(rb.y))
	_inspector.set_layout(inner, points_per_px, compact)

	_sep = 6 if compact else 12
	for box: BoxContainer in [_column, _top_bar, _body, _left, _right]:
		box.add_theme_constant_override(&"separation", _sep)
	_line.add_theme_constant_override(&"h_separation", _sep)
	_line.add_theme_constant_override(&"v_separation", _sep)
	var top_h: float = 72.0 if compact else 84.0
	var tap: float = maxf(MIN_TAP_PX, ceilf(CzArtKit.TAP_PT / points_per_px))
	for b: Button in [_menu, _info]:
		b.custom_minimum_size = Vector2(maxf(88.0, tap), top_h)
	_you.base_width = 150.0 if compact else 180.0
	_rival.base_width = 280.0 if compact else 330.0
	_you.custom_minimum_size = Vector2(_you.base_width, top_h)
	_rival.custom_minimum_size = Vector2(_rival.base_width, top_h)
	_zone.custom_minimum_size = Vector2(0.0, top_h)

	# Left: map (scaled to its width) + line chips. Right: strip + hand at the art card size.
	var body_h: float = inner.y - top_h - _sep
	var map_w: float = clampf(floorf(inner.x * 0.38), MIN_MAP_W, 560.0)
	var map_h: float = floorf(map_w * CzMap.DESIGN_PT.y / CzMap.DESIGN_PT.x)
	_left.custom_minimum_size = Vector2(map_w, 0)
	_map.custom_minimum_size = Vector2(map_w, map_h)
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_line.custom_minimum_size = Vector2(map_w, LINE_ROWS * MIN_TAP_PX + (LINE_ROWS - 1) * _sep)
	var art: Vector2 = CzArtKit.compact_px(points_per_px).ceil()
	var header_h: float = _strip_header.get_combined_minimum_size().y
	# Height: two rows plus the header and the HOLD tag room (10 pt of a card of height h).
	var fit_h: float = floorf((body_h - header_h - 2.0 * _sep) / (2.0 + HOLD_TAG_PT / CzArtKit.COMPACT_PT.y))
	# Width: the right column must hold a full hand fanned at the minimum exposed strip.
	var right_w: float = inner.x - map_w - _sep
	var fit_w_h: float = floorf((right_w - (HAND_CAPACITY - 1) * tap) * CzArtKit.COMPACT_PT.y / CzArtKit.COMPACT_PT.x)
	var h: float = clampf(minf(fit_h, fit_w_h), art.y, maxf(art.y, MAX_CARD_H))
	var hold_room: float = ceilf(HOLD_TAG_PT * h / CzArtKit.COMPACT_PT.y)
	card_px = Vector2(ceilf(h * CzArtKit.COMPACT_PT.x / CzArtKit.COMPACT_PT.y), h)
	for row: Container in [_strip, _hand]:
		row.card_size = card_px
		row.gap = 8.0
		row.min_step = tap
	_strip.custom_minimum_size.y = card_px.y + hold_room
	_render()


## Margins (left-top, right-bottom) in logical px: base margins, grown to the notch insets.
func safe_margins(logical: Vector2) -> Array[Vector2]:
	var lt: Vector2 = BASE_MARGIN_COMPACT if compact else BASE_MARGIN
	var rb: Vector2 = lt
	var on_phone: bool = OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")
	if on_phone or safe_area_override.has_area():
		var window: Vector2 = Vector2(DisplayServer.window_get_size())
		var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
		if safe_area_override.has_area():
			window = logical
			safe = safe_area_override
		if window.x > 0.0 and window.y > 0.0 and safe.size.x > 0.0:
			var to_canvas: Vector2 = logical / window
			lt = lt.max(safe.position * to_canvas)
			rb = rb.max((window - safe.end) * to_canvas)
	return [lt.ceil(), rb.ceil()]


# --- Accessors for tests and cz11 ------------------------------------------------

## Controls that must be on screen, inside the safe area and not overlap (tests).
func get_key_controls() -> Dictionary:
	return {"MenuButton": _menu, "YouPanel": _you, "ZoneTrack": _zone, "RivalPanel": _rival,
			"InfoButton": _info, "MapView": _map, "LineChips": _line, "StripCards": _strip, "HandCards": _hand}


func get_rows() -> Dictionary:
	return {&"line": _line, &"next": _strip, &"hand": _hand}


func get_cards(zone: StringName) -> Array[Control]:
	var out: Array[Control] = []
	for c: Node in (get_rows()[zone] as Control).get_children():
		if not c.is_queued_for_deletion():
			out.append(c)
	return out


func get_map() -> CzMap:
	return _map


func get_area_touch(area_id: StringName) -> Button:
	var t: CzAreaTile = _map.tile(area_id)
	return t.get_node_or_null("Touch") as Button if t != null else null


func get_inspector() -> Control:
	return _inspector


func get_zone_track() -> Button:
	return _zone


func get_player_panels() -> Array[Button]:
	return [_you, _rival]


func get_selected() -> Control:
	return _selected


func get_selected_area() -> StringName:
	return _selected_area


## Labels whose whole text must show (tests).
func get_important_labels() -> Array[Label]:
	var out: Array[Label] = []
	out.append_array(_you.get_labels())
	out.append_array(_rival.get_labels())
	out.append(_zone.get_title_label())
	out.append_array(_zone.get_chip_labels())
	out.append(_strip_header)
	out.append(_line_header)
	return out


# --- Inspector ----------------------------------------------------------------------

func _inspect_card_view(cc: CzCard) -> void:
	var zone: StringName = cc.get_meta(&"zone", &"")
	var i: int = cc.get_meta(&"index", 0)
	var where: String = {&"hand": "In your hand",
			&"next": "Top of your loadout, card %d: part of your next hand (armour)" % (i + 1)}.get(zone, "")
	if cc.held:
		where = "Held: on top of your loadout, in your next hand; Brace with it until then"
	elif cc.down:
		where = "A Hit on top of your loadout: you are Down (+1 Brace per shot) until you draw it"
	var id: StringName = cc.get_meta(&"card_id", &"")
	inspect_card(card_lookup.call(id), where)
	card_inspected.emit(id, zone)


func _inspect_line_chip(chip: Button) -> void:
	_inspector.open_card(chip.card, {"where": "In your line (played this turn, position %d)" % (chip.index + 1), "attached": chip.attached})
	card_inspected.emit(chip.card_id, &"line")


func inspect_card(c: CardData, where: String = "") -> void:
	_inspector.open_card(c, {"where": where})


func inspect_area(area_id: StringName) -> void:
	var a: AreaData = CardDB.get_area(area_id)
	var st: Dictionary = _state.get("areas", {}).get(area_id, {})
	var lines: PackedStringArray = []
	lines.append("Cover %d: shots from another area deal %d less." % [a.cover, a.cover] if a.cover > 0 else "No Cover.")
	if st.get("gas", false):
		lines.append("GAS: closed by the Zone. Its piles can't be looted. Ending your turn here costs 1 Hit.")
	lines.append("Loot piles:")
	for p: Dictionary in st.get("piles", []):
		var c: CardData = card_lookup.call(p["card"])
		lines.append("  %s (%s, Search %d) x%d" % [c.display_name, c.rarity_letter(), c.cost, int(p["count"])])
	if st.get("drop", &"") != &"":
		lines.append("Supply drop: %s (Search %d)" % [card_lookup.call(st["drop"]).display_name, CzCardArt.drop_cost()])
	var who: PackedStringArray = []
	if _state.get("you", {}).get("area", &"") == area_id:
		who.append("you (light disc, chevron)")
	if _state.get("rival", {}).get("area", &"") == area_id:
		who.append("the rival (dark disc, square)")
	if not who.is_empty():
		lines.append("Here: %s." % " and ".join(who))
	var core: bool = a.tier == DataEnums.AreaTier.CORE
	_inspector.open_info(a.display_name + (" (Core)" if core else ""),
			"Area %s · %s" % ["C" if core else str(a.number), "Gassed" if st.get("gas", false) else "Open"], "\n".join(lines))


func inspect_zone() -> void:
	var route: int = int(_state.get("route", DataEnums.Route.A))
	var now: int = int(_state.get("zone_index", 1))
	var lines: PackedStringArray = []
	for z: ZoneCardData in CardDB.zone_deck():
		var extra: String = z.route_text(route)
		if z.has_drop():
			extra += " (%s)" % z.drop_card.display_name
		var mark: String = "NOW  " if z.number == now else ("done " if z.number < now else "")
		lines.append("%s%d. %s%s" % [mark, z.number, z.display_name, ("  ·  " + extra) if extra != "–" else ""])
	_inspector.open_info("Zone deck · route %s" % ROUTE_LETTER[clampi(route, 0, 2)],
			"Round %d. The deck is public: one card per round." % int(_state.get("round", 1)), "\n".join(lines))


func inspect_player(which: StringName) -> void:
	var d: Dictionary = _state.get(String(which), {})
	var lines: PackedStringArray = []
	lines.append("Health %d of %d. Each Hit moves one card from the health stack to the top of the loadout." % [int(d.get("health", 0)), int(d.get("max_health", 5))])
	lines.append("DOWN +1: a Hit is in the next draw, so every shot after the first deals 1 less." if d.get("down", false) else "Not Down.")
	lines.append("BOUNTY: holds the Bounty (most health). Whoever lands a Hit on them heals 1; in the final circle they take 1 extra Hit." if d.get("bounty", false) else "No Bounty.")
	if which == &"rival":
		lines.append("Loadout: %d cards. The order is private." % int(d.get("loadout_count", 0)))
		lines.append("Held: %d cards on top of their loadout. Which cards is hidden (prototype rule), but they can Brace with them." % int(d.get("held_count", 0)))
		var last: PackedStringArray = []
		for id: StringName in d.get("last_line", []):
			last.append(card_lookup.call(id).display_name)
		lines.append("Last turn's line: %s." % (", ".join(last) if not last.is_empty() else "nothing"))
	else:
		var next: PackedStringArray = []
		for id: StringName in d.get("next", []):
			var c: CardData = card_lookup.call(id)
			next.append(c.display_name + (" (Brace %d)" % c.brace if c.brace > 0 else ""))
		lines.append("Next hand (top of your loadout): %s. +%d cards below." % [", ".join(next), int(d.get("loadout_rest", 0))])
	var title: String = "You" if which == &"you" else "Rival (%s)" % d.get("kind", "AI")
	var area: AreaData = CardDB.get_area(d.get("area", &""))
	_inspector.open_info(title, "Area: %s" % (area.display_name if area != null else "?"), "\n".join(lines))


# --- Input --------------------------------------------------------------------------

func _on_card_tapped(view: Control, zone: StringName, index: int, card_id: StringName) -> void:
	card_tapped.emit(zone, index, card_id)
	if mock_interactions:
		_select(view)


func _on_area_tapped(area_id: StringName) -> void:
	area_tapped.emit(area_id)
	if not mock_interactions:
		return
	_select(null)
	_selected_area = &"" if _selected_area == area_id else area_id
	_map.set_state({"selected": _selected_area})
	_refresh_buttons()


func _select(c: Control) -> void:
	if _selected != null and is_instance_valid(_selected):
		_selected.selected = false
	_selected = null if (_selected == c or c == null) else c
	if _selected != null:
		_selected.selected = true
		_selected_area = &""
		_map.set_state({"selected": &""})
	_refresh_buttons()


func _on_info() -> void:
	if _selected != null and is_instance_valid(_selected):
		if _selected is CzCard:
			_inspect_card_view(_selected)
		else:
			_inspect_line_chip(_selected)
	elif _selected_area != &"":
		inspect_area(_selected_area)


func _on_menu() -> void:
	menu_requested.emit()
	if mock_interactions:
		SceneRouter.goto_route(&"title")


func _on_round_started(round_index: int) -> void:
	if _state.is_empty():
		return
	_state["round"] = round_index
	_zone.setup(int(_state["zone_index"]), int(_state["route"]), round_index)
	_zone.set_short_title(compact)

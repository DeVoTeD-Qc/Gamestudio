# match_screen.gd
# Purpose: CardZone match screen layout (cz10), phone landscape first, on mock state only.
#   Layout (anchors + containers; this script only sizes things from the room the screen has):
#     top bar:  MENU · YOU (health, Bounty, Down) · ZONE TRACK (round, 14 steps, next cards) ·
#               RIVAL (health, Down, Bounty, loadout count, held count; held cards hidden) · INFO
#     left:     Ridge Hollow map, 7 area tiles (open / gassed, Cover, loot, drops, both pawns)
#     right:    LINE row (cards played this turn, in order) ·
#               NEXT HAND row = the loadout strip: the top of your loadout down to your next
#               hand, outlined as armour (held cards tagged HOLD, Hits tagged DOWN +1), with the
#               caption tile summing its Brace and counting the cards below ·
#               HAND (default 5 cards; free Hits come on top).
#   Pattern adapted from CallingCard scripts/ui/duel_screen.gd (cc07): safe-area margins from
#   DisplayServer (or safe_area_override in tests / previews), compact flag below 640 px height,
#   get_key_controls() / get_important_labels() for the layout tests, inspector as an overlay.
#   Sizes (logical px; pt = px * points_per_px):
#     hand card >= 84x118 pt (art-direction.md §3), line / strip cards >= 84 px wide and >= 64 px,
#     every tap target >= 64 px and >= 44 pt, text >= 16 px (>= 11 pt), key numbers >= 24 px.
# State: show_state(Dictionary) with the shape in mock_match_data.gd. cz11 replaces the mock with
#   the per-seat view() of cz07's engine; card_lookup turns a card id into a card Dictionary
#   (default: the mock table; cz05's CardDB later).
# Signals for cz11: card_tapped(zone, index, card_id), area_tapped(area_id), menu_requested.
#   With mock_interactions = true a tap only selects (outline) and INFO inspects the selection.
# Dependencies: EventBus, SceneRouter (MENU in mock mode), screen_profile.gd, match_theme.gd,
#   mock_match_data.gd, match_card_button.gd, area_tile.gd, fan_row.gd, map_view.gd,
#   zone_track.gd, player_panel.gd, card_inspector.gd.
# Author: UI/UX Agent (cz10)
extends Control

signal card_tapped(zone: StringName, index: int, card_id: StringName)
signal area_tapped(area_id: StringName)
signal menu_requested
signal card_inspected(card_id: StringName, zone: StringName)

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const MatchTheme: GDScript = preload("res://scripts/ui/match_theme.gd")
const MockMatchData: GDScript = preload("res://scripts/ui/mock_match_data.gd")
const CardButton: GDScript = preload("res://scripts/ui/match_card_button.gd")
const AreaTileScript: GDScript = preload("res://scripts/ui/area_tile.gd")

const BASE_MARGIN: Vector2 = Vector2(32, 18)
const BASE_MARGIN_COMPACT: Vector2 = Vector2(16, 10)
const CARD_PT: Vector2 = Vector2(84, 118)
const MIN_TAP_PX: float = 64.0
const MIN_MINI: Vector2 = Vector2(84, 112)
const MAX_HAND_H: float = 210.0
const MAX_MINI_H: float = 150.0
const CAPTION_W: float = 104.0
const PAWN_PT: float = 28.0
## Rows must hold this many cards without an exposed strip below 64 px.
const HAND_CAPACITY: int = 7
const ROW_CAPACITY: int = 6

## Safe area in logical px (tests / previews). Empty = read DisplayServer on phones.
var safe_area_override: Rect2 = Rect2()
## Points per logical px (tests). 0 = from the real window via ScreenProfile.
var points_per_px_override: float = 0.0
var mock_interactions: bool = true
var card_lookup: Callable = MockMatchData.card
var compact: bool = false
var points_per_px: float = 1.0
var hand_card: Vector2 = Vector2(120, 168)
var mini_card: Vector2 = Vector2(84, 118)

var _state: Dictionary = {}
var _selected: Control = null

@onready var _safe_area: MarginContainer = %SafeArea
@onready var _column: VBoxContainer = %Column
@onready var _top_bar: HBoxContainer = %TopBar
@onready var _menu: Button = %MenuButton
@onready var _you: Button = %YouPanel
@onready var _zone: Button = %ZoneTrack
@onready var _rival: Button = %RivalPanel
@onready var _info: Button = %InfoButton
@onready var _body: HBoxContainer = %Body
@onready var _map_panel: PanelContainer = %MapPanel
@onready var _map: Container = %MapView
@onready var _right: VBoxContainer = %RightColumn
@onready var _line_caption: Button = %LineCaption
@onready var _line: Container = %LineCards
@onready var _strip_caption: Button = %StripCaption
@onready var _strip: Container = %StripCards
@onready var _hand: Container = %HandCards
@onready var _inspector: Control = %CardInspector


func _ready() -> void:
	theme = MatchTheme.build()
	for a: Dictionary in MockMatchData.AREAS:
		var tile: Button = AreaTileScript.new()
		tile.name = String(a["id"])
		tile.tapped.connect(_on_area_tapped.bind(tile))
		tile.inspect_requested.connect(inspect_area.bind(a["id"]))
		_map.add_child(tile)
	_menu.pressed.connect(_on_menu)
	_info.pressed.connect(_on_info)
	_you.setup(&"you", {})
	_rival.setup(&"rival", {})
	for p: Button in [_you, _rival]:
		p.tapped.connect(inspect_player.bind(p.side))
		p.inspect_requested.connect(inspect_player.bind(p.side))
	_zone.tapped.connect(inspect_zone)
	_zone.inspect_requested.connect(inspect_zone)
	_line_caption.tapped.connect(inspect_line)
	_line_caption.inspect_requested.connect(inspect_line)
	_strip_caption.tapped.connect(inspect_loadout)
	_strip_caption.inspect_requested.connect(inspect_loadout)
	_line.capacity = ROW_CAPACITY
	_strip.capacity = ROW_CAPACITY
	_hand.capacity = HAND_CAPACITY
	_hand.valign = 1.0  # the hand hugs the bottom edge (thumb reach)
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
	if is_inside_tree():
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
	_zone.setup(int(_state["zone_index"]), _state["route"], int(_state["round"]))
	_zone.set_short_title(compact)
	for tile: Node in _map.get_children():
		var id: StringName = StringName(tile.name)
		tile.setup(MockMatchData.area(id), _state["areas"].get(id, {}), you["area"] == id, rival["area"] == id)
	# Line: cards in play order (attachments ride on their weapon).
	var line_cards: Array = []
	for entry: Dictionary in you["line"]:
		var c: Dictionary = card_lookup.call(entry["card"])
		var names: PackedStringArray = []
		for a: StringName in entry.get("attached", []):
			names.append(String(card_lookup.call(a).get("name", "")))
		c["attached"] = Array(names)
		line_cards.append(c)
	_fill(_line, line_cards, &"line", &"mini", [], false)
	# Strip: top of the loadout = next hand (armour). Held cards are tagged.
	var next_cards: Array = []
	for id: StringName in you["next"]:
		next_cards.append(card_lookup.call(id))
	_fill(_strip, next_cards, &"next", &"mini", you["held"], true)
	var hand_cards: Array = []
	for id: StringName in you["hand"]:
		hand_cards.append(card_lookup.call(id))
	_fill(_hand, hand_cards, &"hand", &"hand", [], false)
	var brace: int = 0
	for c: Dictionary in next_cards:
		brace += int(c.get("brace", 0))
	_strip_caption.text = "NEXT HAND\nBRACE %d\n+%d below" % [brace, int(you["loadout_rest"])]
	_line_caption.text = "LINE\n%d played" % line_cards.size()
	_refresh_buttons()


func _fill(row: Container, cards: Array, zone: StringName, size_class: StringName, held: Array, armour: bool) -> void:
	for c: Node in row.get_children():
		row.remove_child(c)
		c.queue_free()
	# Held cards are the first non-Hit cards on top of the loadout.
	var held_left: Array = held.duplicate()
	var non_hit: int = 0
	for i: int in cards.size():
		var c: Dictionary = cards[i]
		var b: Button = CardButton.new()
		var is_hit: bool = c.get("type", &"") == &"hit"
		var is_held: bool = not is_hit and non_hit < held.size() and held_left.has(c["id"])
		if is_held:
			held_left.erase(c["id"])
		if not is_hit:
			non_hit += 1
		b.setup(c, zone, i, size_class, is_held, armour)
		b.tapped.connect(_on_card_tapped.bind(b))
		b.inspect_requested.connect(_inspect_button.bind(b))
		row.add_child(b)


func _refresh_buttons() -> void:
	_info.disabled = _selected == null


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

	var sep: int = 8 if compact else 12
	_column.add_theme_constant_override(&"separation", sep)
	_top_bar.add_theme_constant_override(&"separation", sep)
	_body.add_theme_constant_override(&"separation", sep)
	_right.add_theme_constant_override(&"separation", sep)
	for row: Node in [%LineRow, %StripRow]:
		(row as HBoxContainer).add_theme_constant_override(&"separation", sep)
	var top_h: float = 72.0 if compact else 84.0
	var tap: float = maxf(MIN_TAP_PX, ceilf(44.0 / points_per_px))
	_menu.custom_minimum_size = Vector2(maxf(88.0, tap), top_h)
	_info.custom_minimum_size = Vector2(maxf(88.0, tap), top_h)
	_you.base_width = 150.0 if compact else 180.0
	_rival.base_width = 280.0 if compact else 330.0
	_you.custom_minimum_size = Vector2(_you.base_width, top_h)
	_rival.custom_minimum_size = Vector2(_rival.base_width, top_h)
	_zone.custom_minimum_size = Vector2(0.0, top_h)

	# Body: map on the left, rows on the right.
	var body_h: float = inner.y - top_h - sep
	var art_hand: Vector2 = (CARD_PT / points_per_px).ceil()
	var hand_h: float = clampf(body_h - 2.0 * sep - 2.0 * MAX_MINI_H, art_hand.y, MAX_HAND_H)
	hand_card = Vector2(roundf(hand_h * CARD_PT.x / CARD_PT.y), hand_h)
	var mini_h: float = clampf(floorf((body_h - hand_h - 2.0 * sep) / 2.0), MIN_MINI.y, MAX_MINI_H)
	var map_w: float = clampf(floorf(inner.x * (0.41 if compact else 0.38)), 3.0 * 96.0 + 2.0 * 8.0 + 20.0, 560.0)
	# Mini width: card-like ratio, but narrow enough that a 5-card next hand fits without overlap
	# when the row allows it (never below 84 px).
	var fan_w: float = inner.x - map_w - sep - CAPTION_W - sep
	mini_card = Vector2(clampf(minf(roundf(mini_h * 0.76), floorf((fan_w - 4.0 * 6.0) / 5.0)), MIN_MINI.x, 112.0), mini_h)
	_map_panel.custom_minimum_size = Vector2(map_w, 0)
	_map.gap = 6.0 if compact else 10.0
	for tile: Node in _map.get_children():
		tile.pawn_d = maxf(ceilf(PAWN_PT / points_per_px), 28.0 if compact else 40.0)
	_line_caption.custom_minimum_size = Vector2(CAPTION_W, mini_h)
	_strip_caption.custom_minimum_size = Vector2(CAPTION_W, mini_h)
	for row: Container in [_line, _strip]:
		row.card_size = mini_card
		row.gap = 6.0
		row.min_step = tap
	_hand.card_size = hand_card
	_hand.gap = 8.0
	_hand.min_step = tap
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
			"InfoButton": _info, "MapPanel": _map_panel, "LineRow": %LineRow, "StripRow": %StripRow,
			"HandCards": _hand}


func get_rows() -> Dictionary:
	return {&"line": _line, &"next": _strip, &"hand": _hand}


func get_card_buttons(zone: StringName) -> Array[Button]:
	var out: Array[Button] = []
	for c: Node in (get_rows()[zone] as Container).get_children():
		if not c.is_queued_for_deletion():
			out.append(c)
	return out


func get_area_tiles() -> Array[Button]:
	var out: Array[Button] = []
	for c: Node in _map.get_children():
		out.append(c)
	return out


func get_map() -> Container:
	return _map


func get_inspector() -> Control:
	return _inspector


func get_zone_track() -> Button:
	return _zone


func get_player_panels() -> Array[Button]:
	return [_you, _rival]


func get_selected() -> Control:
	return _selected


## Labels whose whole text must show (tests).
func get_important_labels() -> Array[Label]:
	var out: Array[Label] = []
	out.append_array(_you.get_labels())
	out.append_array(_rival.get_labels())
	out.append(_zone.get_title_label())
	out.append_array(_zone.get_chip_labels())
	for t: Node in _map.get_children():
		out.append_array(t.get_labels())
	return out


# --- Inspector ----------------------------------------------------------------------

func _inspect_button(b: Button) -> void:
	var where: String = {&"hand": "In your hand", &"line": "In your line (played this turn, position %d)" % (b.index + 1),
			&"next": "Top of your loadout, card %d: part of your next hand (armour)" % (b.index + 1)}.get(b.zone, "")
	if b.held:
		where = "Held: on top of your loadout, in your next hand, Brace with it until then"
	inspect_card(b.card, where)
	card_inspected.emit(b.card_id, b.zone)


func inspect_card(c: Dictionary, where: String = "") -> void:
	_inspector.open_card(c, {"where": where})


func inspect_area(area_id: StringName) -> void:
	var a: Dictionary = MockMatchData.area(area_id)
	var st: Dictionary = _state.get("areas", {}).get(area_id, {})
	var lines: PackedStringArray = []
	lines.append("Cover %d: shots from another area deal %d less." % [int(a["cover"]), int(a["cover"])] if int(a["cover"]) > 0 else "No Cover.")
	if st.get("gas", false):
		lines.append("GAS: closed by the Zone. Its piles can't be looted. Ending your turn here costs 1 Hit.")
	lines.append("Loot piles:")
	for p: Dictionary in st.get("piles", []):
		var c: Dictionary = card_lookup.call(p["card"])
		lines.append("  %s (%s, Search %d) x%d" % [c.get("name", ""), String(c.get("rarity", "")), int(c.get("cost", 0)), int(p["count"])])
	if st.get("drop", &"") != &"":
		lines.append("Supply drop: %s (Search 3)" % card_lookup.call(st["drop"]).get("name", ""))
	var who: PackedStringArray = []
	if _state.get("you", {}).get("area", &"") == area_id:
		who.append("you (light disc, chevron)")
	if _state.get("rival", {}).get("area", &"") == area_id:
		who.append("the rival (dark disc, square)")
	if not who.is_empty():
		lines.append("Here: %s." % " and ".join(who))
	var title: String = String(a["name"]) + (" (Core)" if area_id == &"old_town" else "")
	_inspector.open_info(title, "Area %s · %s" % [a["num"], "Gassed" if st.get("gas", false) else "Open"], "\n".join(lines))


func inspect_zone() -> void:
	var route: StringName = _state.get("route", &"A")
	var now: int = int(_state.get("zone_index", 1))
	var lines: PackedStringArray = []
	for z: Dictionary in MockMatchData.ZONE:
		var r: Dictionary = z.get(String(route), {})
		var extra: PackedStringArray = []
		if r.has("gas"):
			extra.append("gas: %s" % MockMatchData.area(r["gas"])["name"])
		if r.has("drop"):
			extra.append("drop: %s" % MockMatchData.area(r["drop"])["name"])
		var mark: String = "NOW  " if z["n"] == now else ("done " if z["n"] < now else "")
		lines.append("%s%d. %s%s" % [mark, z["n"], z["title"], (" (%s)" % ", ".join(extra)) if not extra.is_empty() else ""])
	_inspector.open_info("Zone deck · route %s" % String(route), "Round %d. The deck is public: one card per round." % int(_state.get("round", 1)), "\n".join(lines))


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
			last.append(String(card_lookup.call(id).get("name", "")))
		lines.append("Last turn's line: %s." % (", ".join(last) if not last.is_empty() else "nothing"))
	var title: String = "You" if which == &"you" else "Rival (%s)" % d.get("kind", "AI")
	_inspector.open_info(title, "Area: %s" % MockMatchData.area(d.get("area", &"")).get("name", "?"), "\n".join(lines))


func inspect_line() -> void:
	var names: PackedStringArray = []
	for b: Button in get_card_buttons(&"line"):
		names.append("%d. %s" % [b.index + 1, b.card.get("name", "")])
	_inspector.open_info("Your line", "Cards played or looted this turn, in order",
			("\n".join(names) if not names.is_empty() else "Nothing played yet.") + "\n\nAt the end of your turn the line goes under your loadout in this order (Stow).")


func inspect_loadout() -> void:
	var you: Dictionary = _state.get("you", {})
	var names: PackedStringArray = []
	var brace: int = 0
	for b: Button in get_card_buttons(&"next"):
		brace += int(b.card.get("brace", 0))
		names.append("%d. %s%s%s" % [b.index + 1, b.card.get("name", ""), " (HOLD)" if b.held else "",
				" · Brace %d" % int(b.card["brace"]) if int(b.card.get("brace", 0)) > 0 else ""])
	_inspector.open_info("Next hand = armour", "Top of your loadout. Brace %d available if you are shot." % brace,
			"\n".join(names) + "\n\n+%d more cards below. Hits on top come along free and make you Down; Brace cards you use go to the bottom." % int(you.get("loadout_rest", 0)))


# --- Input --------------------------------------------------------------------------

func _on_card_tapped(b: Button) -> void:
	card_tapped.emit(b.zone, b.index, b.card_id)
	if not mock_interactions:
		return
	_select(b)


func _on_area_tapped(tile: Button) -> void:
	area_tapped.emit(tile.area_id)
	if mock_interactions:
		_select(tile)


func _select(c: Control) -> void:
	if _selected != null and is_instance_valid(_selected):
		_selected.selected = false
	_selected = null if _selected == c else c
	if _selected != null:
		_selected.selected = true
	_refresh_buttons()


func _on_info() -> void:
	if _selected == null or not is_instance_valid(_selected):
		return
	if _selected is CardButton:
		_inspect_button(_selected)
	elif _selected is AreaTileScript:
		inspect_area(_selected.area_id)


func _on_menu() -> void:
	menu_requested.emit()
	if mock_interactions:
		SceneRouter.goto_route(&"title")


func _on_round_started(round_index: int) -> void:
	if _state.is_empty():
		return
	_state["round"] = round_index
	_zone.setup(int(_state["zone_index"]), _state["route"], round_index)
	_zone.set_short_title(compact)

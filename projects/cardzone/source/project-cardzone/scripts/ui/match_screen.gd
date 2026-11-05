# match_screen.gd
# Purpose: CardZone match screen (cz10 layout, cz11 turn flow), phone landscape first.
#   Layout (anchors + containers; this script only sizes things from the room the screen has):
#     top bar:  MENU · YOU (health, Bounty, Down) · ZONE TRACK (round, Zone n/14, route, next cards) ·
#               RIVAL (health, Down, Bounty, loadout count, held count; held cards never shown) · INFO
#     left:     Ridge Hollow map (cz16 CzMap, >= 416 px wide so every tile is >= 64 px / 44 pt) with
#               four controls in its sea corners (cz11): your MOVE / SEARCH pools (top left), LOG (top
#               right), UNDO (bottom left), END TURN (bottom right); under it your LINE (cards played
#               this turn, in order) as chips, 3 per row, 2 rows visible, scrolling past 6 (cz11).
#     right:    NEXT HAND = the loadout strip: the top of your loadout down to your next hand, as
#               full-size cards (held cards outlined + HOLD, Hits on top marked Down), with a header
#               that sums Brace and counts the cards below · your HAND (default 5 + free Hits).
#     overlays: the ACTION DOCK over the line area (what the selected card / area can do, the shot
#               preview, Pack / Hold, Brace, drop), a TOAST over the strip header (each engine event,
#               in order), a modal SHEET (loot list, attach target, MENU, concede, match end), and
#               the inspector.
#   Cards are cz16 CzCard at the art direction's compact size (84x118 pt, larger on desktop), fanned
#   when space is short with >= 64 px / 44 pt of each card exposed; the selected card opens to its
#   full width (cz11, from the cz10 review: names were cut in the fan).
#   Pattern adapted from CallingCard scripts/ui/duel_screen.gd (cc07): safe-area margins from
#   DisplayServer (or safe_area_override in tests / previews), compact flag below 640 px height,
#   tablet flag from 800 px height (cz19b BUG-09: iPad 1180x820 is 1280x889 logical; the map, cards,
#   line and Brace panel grow into the extra height instead of leaving it empty),
#   get_key_controls() / get_important_labels() for the layout tests, the inspector as an overlay.
# Modes: show_state(mock) before the screen enters the tree = the cz10 mock layout (no engine).
#   Otherwise the screen is LIVE: %MatchController (scripts/match/match_controller.gd) runs a real
#   match and the screen renders view_adapter.to_screen(view(state, human)) after every action.
#   auto_start = false lets a test call start_live(state) itself.
# Live input (touch first; every refusal is explained in words in the dock or the toast):
#   tap a hand card -> PLAY / MOVE +1 / SEARCH +1 (a Hit: Adrenaline) / PATCH UP / ATTACH… / DITCH /
#   THROW (Frag, then tap an area); tap a line weapon -> the shot preview, then FIRE; tap an area ->
#   MOVE HERE, or LOOT… in your own area (a sheet of piles, drops, crate cards); UNDO; END TURN ->
#   Pack (tap hand cards to Hold, END TURN again); Brace -> tap armour cards in the strip, BRACE;
#   MENU -> RESUME / CONCEDE / LEAVE.
#   cz12: the Brace prompt and the rival's playback use the hand area (your hand is empty then):
#   BRACE PANEL (brace_panel.gd: the damage sum, live Hits, the suggested brace and why;
#   USE SUGGESTED + BRACE = 2 taps, or tap next-hand cards to adjust, then BRACE; the suggested
#   cards carry a SUGGESTED tag under them) and PLAYBACK PANEL (playback_panel.gd: the rival's
#   steps one at a time, FAST and SKIP); shots / moves / loots are marked on the map
#   (tracer_layer.gd, a placeholder for cz17). After a skipped or instant rival turn the toast
#   sums it up in one line.
#   cz13: when the match comes from the Title / Match setup (a SetupLaunch request), `shell`
#   (pause_match_shell.gd) starts it and replaces the MENU and end sheets with the pause menu and
#   the end screen, and runs the first-match coach.
#   cz14 hot-seat: the controller raises a full-screen cover (cover_screen.gd) at every seat change;
#   hotseat_cover_reset() clears every seat-private node under it and the screen renders the
#   controller's covered view until the tap reveals the next seat's own view.
# Signals: card_tapped(zone, index, card_id), area_tapped(area_id), menu_requested,
#   card_inspected(card_id, zone), notice_shown(text), option_pressed(key).
# Dependencies: EventBus, SceneRouter, CardDB, Settings, screen_profile.gd, match_theme.gd,
#   mock_match_data.gd, fan_row.gd, line_chip.gd, zone_track.gd, player_panel.gd, card_inspector.gd,
#   cz16 CzCard / CzMap / CzAreaTile, scripts/match (controller, view adapter, action text).
# Author: UI/UX Agent (cz10, cz11, cz12)
extends Control

signal card_tapped(zone: StringName, index: int, card_id: StringName)
signal area_tapped(area_id: StringName)
signal menu_requested
signal card_inspected(card_id: StringName, zone: StringName)
signal notice_shown(text: String)
signal option_pressed(key: StringName)

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const MatchTheme: GDScript = preload("res://scripts/ui/match_theme.gd")
const MockMatchData: GDScript = preload("res://scripts/ui/mock_match_data.gd")
const LineChip: GDScript = preload("res://scripts/ui/line_chip.gd")
const TapHoldButton: GDScript = preload("res://scripts/ui/tap_hold_button.gd")
const ViewAdapter: GDScript = preload("res://scripts/match/view_adapter.gd")
const ActionText: GDScript = preload("res://scripts/match/action_text.gd")
const SetupLaunch: GDScript = preload("res://scripts/ui/setup_launch.gd")
const MatchShell: GDScript = preload("res://scripts/ui/pause_match_shell.gd")
const BracePanel: GDScript = preload("res://scripts/ui/brace_panel.gd")
const PlaybackPanel: GDScript = preload("res://scripts/ui/playback_panel.gd")
const TracerLayer: GDScript = preload("res://scripts/ui/tracer_layer.gd")
const CoverScreen: GDScript = preload("res://scripts/match/cover_screen.gd")
const CARD_SCENE: PackedScene = preload("res://scenes/card/CzCard.tscn")
const CardWords: GDScript = preload("res://scripts/ui/card_words.gd")
const HowToPlay: GDScript = preload("res://scripts/ui/how_to_play.gd")
## cz-clarity: lines kept in the "what just happened" feed (newest first).
const FEED_LINES: int = 5

const BASE_MARGIN: Vector2 = Vector2(32, 18)
const BASE_MARGIN_COMPACT: Vector2 = Vector2(16, 10)
const MIN_TAP_PX: float = 64.0
const MAX_CARD_H: float = 210.0
## Map width floor: a 64 pt ring tile is then >= 64 px tall (>= 44 pt on every target screen).
const MIN_MAP_W: float = 416.0
const LINE_COLUMNS: int = 3
const LINE_ROWS: int = 2
## Tablet (logical height >= TABLET_HEIGHT): larger cards, a wider map, a 3-row line and a larger
## Brace panel text (cz19b BUG-09).
const TABLET_HEIGHT: float = 800.0
## Cards stay about 5 across without a deep fan: the iPad is no wider than the desktop (1280 px).
const TABLET_MAX_CARD_H: float = 240.0
const TABLET_MAP_SHARE: float = 0.42
const TABLET_MAX_MAP_W: float = 640.0
const TABLET_LINE_ROWS: int = 3
const TABLET_CHIP_H: float = 90.0
## Room above the strip for cz16's HOLD tag (drawn above a held card's top edge), in card pt.
const HOLD_TAG_PT: float = 10.0
const HAND_CAPACITY: int = 7
const STRIP_CAPACITY: int = 6
const ROUTE_LETTER: String = "ABC"
## The map's four sea corners (design pt, CzMap.DESIGN_PT 416 x 248): free of tiles.
const CORNER_TL: Rect2 = Rect2(0, 0, 78, 92)
const CORNER_TR: Rect2 = Rect2(338, 0, 78, 92)
const CORNER_BL: Rect2 = Rect2(0, 156, 78, 92)
const CORNER_BR: Rect2 = Rect2(338, 156, 78, 92)
## Seconds a toast stays up after the last event.
const TOAST_TIME: float = 2.6
## Seconds the one-line summary of a skipped / instant rival turn stays up.
const SUMMARY_TIME: float = 5.0
## Height of the SUGGESTED tag under a strip card (logical px).
const TAG_H: float = 24.0

## Safe area in logical px (tests / previews). Empty = read DisplayServer on phones.
var safe_area_override: Rect2 = Rect2()
## Points per logical px (tests). 0 = from the real window via ScreenProfile.
var points_per_px_override: float = 0.0
var mock_interactions: bool = true
## Live mode starts a new match by itself on _ready unless false (tests call start_live).
var auto_start: bool = true
var card_lookup: Callable = func(id: StringName) -> CardData: return CardDB.get_card(id)
var compact: bool = false
## cz19b: tall screens (tablets) use the extra height.
var tablet: bool = false
var points_per_px: float = 1.0
var card_px: Vector2 = Vector2(117, 164)

## Live-mode input state.
var live: bool = false
## &"act", &"pack", &"aim", &"drop", &"brace", &"opponent", &"over".
var mode: StringName = &"act"
## The selection in act / drop mode: {zone: &"hand"|&"line"|&"next"|&"area", id: inst or area id}.
var sel: Dictionary = {}
## Cards marked to Hold at Pack (instance ids, in tap order).
var hold_set: Array[int] = []
## Cards chosen to Brace (instance ids, in tap order).
var brace_set: Array[int] = []
## The Frag being aimed (aim mode).
var aim_card: int = 0
var last_notice: String = ""

var _state: Dictionary = {}
var _selected: Control = null
var _selected_area: StringName = &""
var _sep: int = 8
var _controller: Node = null
## cz13 MatchShell (pause menu, end screen, coach) when the match came from the Title / Match setup.
var shell: Control = null
var _line_entries: Array = []
var _line_is_rival: bool = false
var _dock_options: Array[Dictionary] = []
var _sheet_options: Array[Dictionary] = []

# Overlays built in code (cz11).
var _dock: PanelContainer
var _dock_title: Label
var _dock_text: Label
var _dock_buttons: HBoxContainer
var _toast: PanelContainer
var _toast_label: Label
var _toast_timer: Timer
var _sheet: Control
var _sheet_panel: PanelContainer
var _sheet_title: Label
var _sheet_text: Label
var _sheet_list: VBoxContainer
var _sheet_scroll: ScrollContainer
var _sheet_close: Button
var _pools: Label
var _log_button: Button
var _undo_button: Button
var _end_button: Button
# cz12 overlays.
var _brace_panel: PanelContainer
var _playback: PanelContainer
var _tracer: Control
var _tags: Control
## cz14: the hot-seat cover (scenes/match/CoverScreen.tscn), above every overlay while up.
var _cover: Control
# cz-clarity: the next hand is hidden by default (the head found it overwhelming); the DECK row
# peeks at it on demand, and the Brace step shows it (you block with it). The freed room holds the
# turn panel: what to do now (phase) and what just happened (outcome feed).
## The player asked to see the next hand (DECK row tap). Cleared at the start of each own turn.
var peek_next: bool = false
var feed_lines: PackedStringArray = []
var _deck_button: Button
var _turn_panel: PanelContainer
var _phase_title: Label
var _phase_text: Label
var _feed: VBoxContainer
var _pools_button: Button
var _how: Control

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
@onready var _line_scroll: ScrollContainer = %LineScroll
@onready var _line: GridContainer = %LineChips
@onready var _right: VBoxContainer = %RightColumn
@onready var _strip_header: Label = %StripHeader
@onready var _strip: Container = %StripCards
@onready var _hand: Container = %HandCards
@onready var _inspector: Control = %CardInspector


func _ready() -> void:
	theme = MatchTheme.build()
	_controller = get_node_or_null("%MatchController")
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
	_line_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_build_overlays()
	_build_clarity()
	if SetupLaunch.has_pending() and _controller != null:
		shell = MatchShell.attach(self)  # cz13: started from the Title / Match setup
	if _controller != null:
		_cover = CoverScreen.attach(self, _controller)  # cz14: hot-seat pass-the-device cover (hidden)
	get_viewport().size_changed.connect(_relayout)
	EventBus.round_started.connect(_on_round_started)
	var mock: bool = not _state.is_empty()
	if not mock and auto_start and _controller != null:
		start_live.call_deferred()
	elif not mock and _controller == null:
		_state = MockMatchData.mid_state()
	_relayout()
	EventBus.screen_shown.emit(&"match")
	print("Match: ready")


# --- Live match -------------------------------------------------------------------

## Starts a real match on %MatchController: a new one (state == null) or the given state.
func start_live(state: MatchState = null) -> void:
	if _controller == null:
		push_error("MatchScreen: no MatchController")
		return
	if not live:
		live = true
		mock_interactions = false
		_controller.view_changed.connect(_on_view_changed)
		_controller.phase_changed.connect(_on_phase_changed)
		_controller.event_shown.connect(_on_event_shown)
		_controller.notice.connect(show_notice)
		_controller.playback_step.connect(_on_playback_step)
		_controller.playback_finished.connect(_on_playback_finished)
	_clear_input()
	mode = &"act"
	if state == null:
		if shell != null:
			shell.begin(_controller)  # cz13: the setup choices, or the saved match
		else:
			_controller.start_new()
	else:
		_controller.start_from(state)


func get_controller() -> Node:
	return _controller


## cz14 hot-seat: the pass-the-device cover (null without a controller).
func get_cover() -> Control:
	return _cover


## cz14 hot-seat: called as the cover goes up. Clears everything one seat may know and the other
## may not: selection, hold / brace choices, the dock, sheet, toast, inspector, Brace and playback
## panels (texts included), SUGGESTED tags; then renders the controller's covered view (no hand,
## next hand or held cards).
func hotseat_cover_reset() -> void:
	_clear_input()
	close_sheet()
	if _sheet != null:
		_sheet_title.text = ""
		_sheet_text.text = ""
		_sheet_options = []
		_clear(_sheet_list)
	if _inspector != null:
		_inspector.open_info("", "", "")
		_inspector.get_card_view().configure({})
		_inspector.close()
	if _toast != null:
		_toast_timer.stop()
		_toast_label.text = ""
		_toast.visible = false
	if _dock != null:
		_dock_title.text = ""
		_dock_text.text = ""
		_dock_options = []
		_clear(_dock_buttons)
		_dock.visible = false
	if _brace_panel != null:
		_brace_panel.show_prompt({})
		_brace_panel.visible = false
	if _playback != null:
		_playback.begin("")
		_playback.visible = false
	if _tags != null:
		_clear(_tags)
	feed_lines.clear()  # cz-clarity: "You ..." lines belong to the seat that just left
	_refresh_feed()
	peek_next = false
	if _how != null:
		_how.close()
	last_notice = ""
	if live and _controller != null and _controller.state != null:
		_on_view_changed(_controller.view())


func _on_view_changed(v: Dictionary) -> void:
	_state = ViewAdapter.to_screen(v, _controller.opponent_kind(), _controller.rival_last_line)
	var you: Dictionary = _state["you"]
	var hand_ids: Array = you["hand_ids"]
	hold_set.assign(hold_set.filter(func(i: int) -> bool: return hand_ids.has(i) or _line_has(you, i)))
	if not sel.is_empty() and sel["zone"] != &"area" and _inst_index(sel["zone"], int(sel["id"])) < 0:
		sel = {}
	_render()


func _on_phase_changed(p: StringName) -> void:
	var was: StringName = mode
	match p:
		&"drop":
			mode = &"drop"
		&"brace":
			mode = &"brace"
			if was != &"brace":
				brace_set.clear()
		&"opponent":
			mode = &"opponent"
		&"over":
			mode = &"over"
		&"cover":
			mode = &"cover"  # cz14: hot-seat cover up: no input, nothing seat-private
			brace_set.clear()
		_:
			if was != &"pack" and was != &"aim":
				mode = &"act"
	if mode != was:
		if mode == &"act" and was in [&"opponent", &"drop", &"brace", &"cover"]:
			peek_next = false  # cz-clarity: each turn starts with the next hand tucked away
		if mode != &"pack":
			hold_set.clear()
		sel = {}
		aim_card = 0
	if is_node_ready():
		_render()
	if mode == &"over":
		_show_end()


func _on_event_shown(text: String, e: Dictionary) -> void:
	# cz-clarity: each event becomes a plain outcome line in the turn panel's feed; the toast only
	# carries it while the feed is hidden (next hand open, Brace step, Pack).
	var me: int = int(_state.get("me", 0))
	var ctx: Dictionary = {}
	if int(e.get("seat", -1)) == me and _state.has("you") and mode != &"opponent":
		ctx = {"move": int(_state["you"].get("move", 0)), "search": int(_state["you"].get("search", 0))}
	var line: String = ActionText.outcome(e, me, ctx)
	add_feed_line(line)
	if _turn_panel == null or not _turn_panel.visible:
		_show_toast(line if line != "" else text)


func _clear_input() -> void:
	sel = {}
	hold_set.clear()
	brace_set.clear()
	aim_card = 0


## Shows why something can't be done (dock text when the dock is up, else the toast).
func show_notice(text: String) -> void:
	last_notice = text
	notice_shown.emit(text)
	if _dock != null and _dock.visible:
		_dock_text.text = text
	else:
		_show_toast(text)


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
	_you.live_mode = live
	_rival.live_mode = live
	_you.setup(&"you", you)
	_rival.show_counts = not live
	_rival.setup(&"rival", rival)
	_zone.setup(int(_state["zone_index"]), int(_state["route"]), int(_state["round"]))
	_zone.set_short_title(compact)
	_render_map()
	_line_is_rival = live and (mode == &"opponent" or (mode == &"brace" and int(_state.get("active", 0)) != int(_state.get("me", 0))))
	_render_line(rival.get("line", []) if _line_is_rival else you["line"])
	# Strip: top of the loadout = next hand (armour). Held cards are the first non-Hit cards.
	var held: Array = you["held"]
	var held_ids: Array = you.get("held_ids", [])
	var next_ids: Array = you.get("next_ids", [])
	var held_left: Array = held.duplicate()
	var non_hit: int = 0
	var brace: int = 0
	_clear(_strip)
	var next: Array = you["next"]
	for i: int in next.size():
		var c: CardData = card_lookup.call(next[i])
		var is_hit: bool = c.is_hit()
		var is_held: bool = false
		if not next_ids.is_empty():
			is_held = held_ids.has(int(next_ids[i]))
		else:
			is_held = not is_hit and non_hit < held.size() and held_left.has(c.id)
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
	_apply_marks()
	_refresh_buttons()
	_refresh_live()
	_refresh_clarity()


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
		for cid: StringName in st.get("crate", []):
			piles.append({"rarity": card_lookup.call(cid).rarity_letter(), "crate": true})
		areas.append({"id": a.id, "name": a.display_name, "cover": a.cover,
				"core": a.tier == DataEnums.AreaTier.CORE, "piles": piles})
		if st.get("gas", false):
			gassed.append(a.id)
	_map.configure(areas)
	if _tracer != null and _tracer.get_parent() == _map:
		_map.move_child(_tracer, -1)  # over the tiles
	var pawns: Dictionary = {}
	var y_area: StringName = _state["you"]["area"]
	var r_area: StringName = _state["rival"]["area"]
	if y_area != &"":
		pawns[y_area] = [&"player"]
	if r_area != &"":
		pawns[r_area] = (pawns.get(r_area, []) as Array) + [&"ai"]
	var selected: StringName = _selected_area
	if live:
		selected = StringName(sel["id"]) if sel.get("zone", &"") == &"area" else &""
	_map.set_state({"gassed": gassed, "pawns": pawns, "selected": selected})
	# A touch layer on each tile: tap = select (move / loot / drop / throw), long-press / right-click = inspect.
	for t: CzAreaTile in _map.tiles():
		var b: Button = TapHoldButton.new()
		b.name = "Touch"
		b.theme_type_variation = &"TileButton"
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_to_group(&"tap_target")
		var id: StringName = t.area_id
		b.tapped.connect(func() -> void: _on_area_tapped(id), CONNECT_DEFERRED)  # the tap re-renders the map
		b.inspect_requested.connect(func() -> void: inspect_area(id))
		t.add_child(b)


func _render_line(entries: Array) -> void:
	_clear(_line)
	_line_entries = entries
	var fired: Dictionary = _state["you"].get("fired", {}) if not _line_is_rival else {}
	for i: int in entries.size():
		var e: Dictionary = entries[i]
		var att: Array[CardData] = []
		for a: StringName in e.get("attached", []):
			att.append(card_lookup.call(a))
		var chip: Button = LineChip.new()
		chip.setup(card_lookup.call(e["card"]), att, i)
		if e.has("id") and int(fired.get(int(e["id"]), 0)) > 0:
			chip.text += " · FIRED"
		chip.custom_minimum_size = Vector2(0, _chip_h())
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.mouse_filter = Control.MOUSE_FILTER_PASS  # a drag scrolls the line (> 6 cards)
		chip.tapped.connect(func() -> void: _on_card_tapped(chip, &"line", chip.index, chip.card_id), CONNECT_DEFERRED)
		chip.inspect_requested.connect(func() -> void: _inspect_line_chip(chip))
		_line.add_child(chip)
	# cz-clarity: plain names ("line" was jargon): what was played or looted this turn.
	var who: String = "RIVAL PLAYED" if _line_is_rival else "PLAYED THIS TURN"
	var more: int = entries.size() - LINE_COLUMNS * _line_rows()
	if entries.is_empty():
		_line_header.text = "RIVAL PLAYED · NOTHING YET" if _line_is_rival else "PLAYED THIS TURN · NOTHING YET"
	elif more > 0:
		_line_header.text = "%s · %d · SCROLL FOR %d MORE" % [who, entries.size(), more]
	else:
		_line_header.text = "%s · %d" % [who, entries.size()]
	if more > 0 and is_inside_tree():
		_scroll_line_to_end.call_deferred()


func _chip_h() -> float:
	return TABLET_CHIP_H if tablet else MIN_TAP_PX


func _line_rows() -> int:
	return TABLET_LINE_ROWS if tablet else LINE_ROWS


## Brace panel text scale: 1 on phones and 16:9 desktops, up to 1.25 on tablets.
func _panel_scale() -> float:
	return clampf(get_viewport_rect().size.y / ScreenProfile.DESIGN_SIZE.y, 1.0, 1.25) if tablet else 1.0


func _scroll_line_to_end() -> void:
	if is_instance_valid(_line_scroll):
		_line_scroll.scroll_vertical = int(_line.size.y)


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
	card.tapped.connect(func(cc: CzCard) -> void: _on_card_tapped(cc, zone, i, c.id), CONNECT_DEFERRED)
	card.inspect_requested.connect(func(cc: CzCard) -> void: _inspect_card_view(cc))
	row.add_child(card)


func _clear(row: Node) -> void:
	for c: Node in row.get_children():
		row.remove_child(c)
		c.queue_free()


func _refresh_buttons() -> void:
	if live:
		# cz-clarity: INFO reads the selection; with nothing selected it is HELP (how to play).
		_info.disabled = false
		_info.text = "HELP" if sel.is_empty() else "INFO"
		return
	_info.disabled = _selected == null and _selected_area == &"" and (not live or sel.is_empty())


# --- Layout --------------------------------------------------------------------

func _relayout() -> void:
	var logical: Vector2 = get_viewport_rect().size
	compact = logical.y < ScreenProfile.COMPACT_HEIGHT
	tablet = logical.y >= TABLET_HEIGHT
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
	if tablet:
		map_w = clampf(floorf(inner.x * TABLET_MAP_SHARE), MIN_MAP_W, TABLET_MAX_MAP_W)
	var map_h: float = floorf(map_w * CzMap.DESIGN_PT.y / CzMap.DESIGN_PT.x)
	_left.custom_minimum_size = Vector2(map_w, 0)
	_map.custom_minimum_size = Vector2(map_w, map_h)
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rows: int = _line_rows()
	_line_scroll.custom_minimum_size = Vector2(map_w, rows * _chip_h() + (rows - 1) * _sep)
	var art: Vector2 = CzArtKit.compact_px(points_per_px).ceil()
	# cz-clarity: the DECK row (a 44 pt tap target) takes the strip header's place in a live match.
	var header_h: float = maxf(_strip_header.get_combined_minimum_size().y, tap)
	# Height: two rows plus the header and the HOLD tag room (10 pt of a card of height h).
	var fit_h: float = floorf((body_h - header_h - 2.0 * _sep) / (2.0 + HOLD_TAG_PT / CzArtKit.COMPACT_PT.y))
	# Width: the right column must hold a full hand fanned at the minimum exposed strip.
	var right_w: float = inner.x - map_w - _sep
	var fit_w_h: float = floorf((right_w - (HAND_CAPACITY - 1) * tap) * CzArtKit.COMPACT_PT.y / CzArtKit.COMPACT_PT.x)
	# cz-clarity: a normal hand (hand_size cards) sits side by side, so no card hides another's numbers.
	var hand_n: int = int(_state.get("hand_size", 5)) if not _state.is_empty() else 5
	var fit_row_h: float = floorf((right_w - 24.0 - (hand_n - 1) * 8.0) / float(hand_n) * CzArtKit.COMPACT_PT.y / CzArtKit.COMPACT_PT.x)
	var h: float = clampf(minf(minf(fit_h, fit_w_h), fit_row_h), art.y, maxf(art.y, TABLET_MAX_CARD_H if tablet else MAX_CARD_H))
	var hold_room: float = ceilf(HOLD_TAG_PT * h / CzArtKit.COMPACT_PT.y)
	card_px = Vector2(ceilf(h * CzArtKit.COMPACT_PT.x / CzArtKit.COMPACT_PT.y), h)
	for row: Container in [_strip, _hand]:
		row.card_size = card_px
		row.gap = 8.0
		row.min_step = tap
	_strip.custom_minimum_size.y = card_px.y + hold_room
	if _deck_button != null:
		_deck_button.custom_minimum_size = Vector2(0, tap)
	for b: Button in [_undo_button, _end_button, _log_button]:
		b.custom_minimum_size = Vector2(tap, tap)
	_render()
	_place_overlays.call_deferred()


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


# --- Overlays (cz11) -----------------------------------------------------------------

func _build_overlays() -> void:
	# Map corners: pools, LOG, UNDO, END TURN (children of the map, in its sea corners).
	_pools = Label.new()
	_pools.name = "Pools"
	_pools.theme_type_variation = &"PoolTag"
	_pools.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pools.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.add_child(_pools)
	_log_button = _corner_button("LogButton", "LOG", _on_log)
	_undo_button = _corner_button("UndoButton", "UNDO", _on_undo)
	_end_button = _corner_button("EndTurnButton", "END\nTURN", _on_end_turn)

	# Action dock over the line area.
	_dock = PanelContainer.new()
	_dock.name = "ActionDock"
	_dock.theme_type_variation = &"DockPanel"
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	_dock.visible = false
	add_child(_dock)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(col)
	_dock_title = Label.new()
	_dock_title.name = "DockTitle"
	_dock_title.theme_type_variation = &"CaptionStrong"
	_dock_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_dock_title.clip_text = true
	col.add_child(_dock_title)
	_dock_text = Label.new()
	_dock_text.name = "DockText"
	_dock_text.theme_type_variation = &"Caption"
	_dock_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dock_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_dock_text.max_lines_visible = 2
	col.add_child(_dock_text)
	_dock_buttons = HBoxContainer.new()
	_dock_buttons.name = "DockButtons"
	_dock_buttons.add_theme_constant_override(&"separation", 6)
	_dock_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_dock_buttons)

	# Toast over the strip header.
	_toast = PanelContainer.new()
	_toast.name = "Toast"
	_toast.theme_type_variation = &"ToastPanel"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	add_child(_toast)
	_toast_label = Label.new()
	_toast_label.name = "ToastText"
	_toast_label.theme_type_variation = &"ToastText"
	_toast_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_toast_label.clip_text = true
	_toast.add_child(_toast_label)
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(func() -> void: _toast.visible = false)
	add_child(_toast_timer)

	# Modal sheet (loot, attach, MENU, concede, match end).
	_sheet = Control.new()
	_sheet.name = "Sheet"
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.visible = false
	add_child(_sheet)
	var scrim: ColorRect = ColorRect.new()
	scrim.color = Color(0.05, 0.02, 0.08, 0.8)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(scrim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(center)
	_sheet_panel = PanelContainer.new()
	_sheet_panel.theme_type_variation = &"InspectorPanel"
	center.add_child(_sheet_panel)
	var scol: VBoxContainer = VBoxContainer.new()
	scol.add_theme_constant_override(&"separation", 8)
	_sheet_panel.add_child(scol)
	_sheet_title = Label.new()
	_sheet_title.name = "SheetTitle"
	_sheet_title.theme_type_variation = &"InspectorTitle"
	scol.add_child(_sheet_title)
	_sheet_text = Label.new()
	_sheet_text.name = "SheetText"
	_sheet_text.theme_type_variation = &"InspectorBody"
	_sheet_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scol.add_child(_sheet_text)
	_sheet_scroll = ScrollContainer.new()
	_sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scol.add_child(_sheet_scroll)
	_sheet_list = VBoxContainer.new()
	_sheet_list.name = "SheetList"
	_sheet_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_list.add_theme_constant_override(&"separation", 6)
	_sheet_scroll.add_child(_sheet_list)
	_sheet_close = Button.new()
	_sheet_close.name = "SheetClose"
	_sheet_close.theme_type_variation = &"TopButton"
	_sheet_close.text = "CLOSE"
	_sheet_close.custom_minimum_size = Vector2(0, MIN_TAP_PX)
	_sheet_close.pressed.connect(close_sheet)
	scol.add_child(_sheet_close)
	# cz12: Brace prompt and rival playback over the hand area, SUGGESTED tags, map tracers.
	_brace_panel = BracePanel.new()
	_brace_panel.option.connect(_on_brace_option)
	add_child(_brace_panel)
	_playback = PlaybackPanel.new()
	_playback.option.connect(_on_playback_option)
	add_child(_playback)
	_tags = Control.new()
	_tags.name = "BraceTags"
	_tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tags)
	_tracer = TracerLayer.new()
	_map.add_child(_tracer)
	# The inspector stays on top of every overlay.
	for n: Node in [_dock, _brace_panel, _playback, _tags, _toast, _sheet]:
		move_child(n, _inspector.get_index())


func _corner_button(node_name: String, label: String, handler: Callable) -> Button:
	var b: Button = TapHoldButton.new()  # cz-clarity: long press / right click explains it
	b.name = node_name
	b.theme_type_variation = &"CornerButton"
	b.text = label
	b.focus_mode = Control.FOCUS_ALL
	b.tapped.connect(handler)
	var key: StringName = StringName(node_name)
	b.inspect_requested.connect(func() -> void: explain_control(key))
	_map.add_child(b)
	return b


# --- cz-clarity: deck row, turn panel, feed, explanations ------------------------------------------

func _build_clarity() -> void:
	# DECK row (top of the right column): tap = peek at / hide the next hand; hold = what it is.
	_deck_button = TapHoldButton.new()
	_deck_button.name = "DeckButton"
	_deck_button.theme_type_variation = &"DeckButton"
	_deck_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_deck_button.clip_text = true
	_deck_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_deck_button.add_to_group(&"tap_target")
	_deck_button.tapped.connect(_on_deck_tapped)
	_deck_button.inspect_requested.connect(func() -> void: explain_control(&"DeckButton"))
	_right.add_child(_deck_button)
	_right.move_child(_deck_button, 0)
	# Turn panel, between the next-hand strip and the hand.
	_turn_panel = PanelContainer.new()
	_turn_panel.name = "TurnPanel"
	_turn_panel.theme_type_variation = &"TurnPanel"
	_turn_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_turn_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_turn_panel.clip_contents = true
	_right.add_child(_turn_panel)
	_right.move_child(_turn_panel, _hand.get_index())
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_panel.add_child(col)
	_phase_title = Label.new()
	_phase_title.name = "PhaseTitle"
	_phase_title.theme_type_variation = &"PhaseTitle"
	_phase_title.clip_text = true
	_phase_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_phase_title)
	_phase_text = Label.new()
	_phase_text.name = "PhaseText"
	_phase_text.theme_type_variation = &"Caption"
	_phase_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phase_text.max_lines_visible = 2
	_phase_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_phase_text.custom_minimum_size = Vector2(80, 44)  # two lines; an autowrap label has no height of its own
	_phase_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_phase_text)
	_feed = VBoxContainer.new()
	_feed.name = "Feed"
	_feed.add_theme_constant_override(&"separation", 0)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_feed)
	for i: int in FEED_LINES:
		var l: Label = Label.new()
		l.name = "Feed_%d" % i
		l.theme_type_variation = &"FeedNew" if i == 0 else &"FeedOld"
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_feed.add_child(l)
	_turn_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			_on_log())
	_turn_panel.visible = false
	_deck_button.visible = false
	# MOVE / SEARCH pools: a touch layer under the label explains them.
	_pools_button = TapHoldButton.new()
	_pools_button.name = "PoolsButton"
	_pools_button.theme_type_variation = &"TileButton"
	_pools_button.focus_mode = Control.FOCUS_NONE
	_pools_button.tapped.connect(func() -> void: explain_control(&"Pools"))
	_pools_button.inspect_requested.connect(func() -> void: explain_control(&"Pools"))
	_map.add_child(_pools_button)
	_map.move_child(_pools_button, _pools.get_index())
	# How to play (cz-clarity): INFO with nothing selected, the pause menu, and before the first match.
	_how = HowToPlay.new()
	_how.name = "HowToPlay"
	add_child(_how)
	move_child(_how, _inspector.get_index())
	_how.closed.connect(_on_how_closed)


## True when the next-hand strip is on screen: the mock layout, a peek, and the Brace step.
func is_next_shown() -> bool:
	return not live or peek_next or mode == &"brace"


func get_deck_button() -> Button:
	return _deck_button


func get_turn_panel() -> PanelContainer:
	return _turn_panel


func get_phase_text() -> String:
	return (_phase_title.text + " · " + _phase_text.text) if _turn_panel != null and _turn_panel.visible else ""


## The outcome feed, newest first.
func get_feed() -> PackedStringArray:
	return feed_lines


func get_how_to_play() -> Control:
	return _how


## Opens How to play; the match waits (controller paused) until it closes. first: before the first match.
func show_how_to_play(first: bool = false) -> void:
	if _how == null:
		return
	if live and _controller != null and not _how.is_open():
		_controller.set("paused", true)
		if shell != null:
			shell.coach.enabled = false
	_how.open(first)


func _on_how_closed() -> void:
	if shell != null:
		if shell.is_paused():
			return
		shell.coach.enabled = true
		shell.coach.check.call_deferred()
		if shell.coach.is_showing():
			return
	if live and _controller != null:
		_controller.set("paused", false)


func _on_deck_tapped() -> void:
	option_pressed.emit(&"deck")
	if not live:
		return
	if mode == &"brace":
		show_notice("Your next hand stays open while you choose what blocks the shot.")
		return
	peek_next = not peek_next
	_render()


## Adds an outcome line to the feed (newest first).
func add_feed_line(text: String) -> void:
	if text == "":
		return
	feed_lines.insert(0, text)
	if feed_lines.size() > FEED_LINES:
		feed_lines.resize(FEED_LINES)
	_refresh_feed()


func _refresh_feed() -> void:
	if _feed == null:
		return
	var labels: Array[Node] = _feed.get_children()
	for i: int in labels.size():
		(labels[i] as Label).text = feed_lines[i] if i < feed_lines.size() else ""


## The deck row and the turn panel for the current mode (live only).
func _refresh_clarity() -> void:
	if _deck_button == null:
		return
	var shown: bool = is_next_shown()
	var was: bool = _turn_panel.visible
	var was_strip: bool = _strip.visible
	_strip.visible = shown
	_strip_header.visible = shown and not live
	_deck_button.visible = live and _state.has("you") and mode != &"brace"  # the Brace panel says it all then
	_turn_panel.visible = live and not shown and mode != &"cover"
	_hand.size_flags_vertical = Control.SIZE_SHRINK_END if _turn_panel.visible else Control.SIZE_EXPAND_FILL
	if (was != _turn_panel.visible or was_strip != _strip.visible) and is_inside_tree():
		_place_overlays.call_deferred()  # the hand moved: Brace / playback panels follow it
	if not live or not _state.has("you"):
		return
	var you: Dictionary = _state["you"]
	var next: Array = you.get("next", [])
	var brace: int = 0
	var hits: int = 0
	for id: Variant in next:
		var c: CardData = card_lookup.call(StringName(str(id)))
		if c != null:
			brace += c.brace
			hits += 1 if c.is_hit() else 0
	var total: int = next.size() + int(you.get("loadout_rest", 0))
	var hit_note: String = (" · %d HIT ON TOP: DOWN" % hits) if hits > 0 else ""
	if mode == &"brace":
		_deck_button.text = "YOUR NEXT HAND · TAP CARDS TO BLOCK (UP TO %d)%s" % [brace, hit_note]
	elif shown:
		_deck_button.text = "YOUR NEXT HAND · BLOCKS UP TO %d · %d KEPT · TAP TO HIDE%s" % [brace, (you.get("held", []) as Array).size(), hit_note]
	else:
		_deck_button.text = "DECK · %d CARD%s · TAP TO SEE YOUR NEXT HAND%s" % [total, "" if total == 1 else "S", hit_note]
	var phase: Array = phase_words()
	_phase_title.text = phase[0]
	_phase_text.text = phase[1]
	_refresh_feed()


## [title, what to do] for the turn indicator in the current mode.
func phase_words() -> Array:
	var you: Dictionary = _state.get("you", {})
	match mode:
		&"drop":
			return ["DROP IN", "Tap an outer area on the map, then DROP HERE. The rival can land there too."]
		&"pack":
			return ["END OF TURN · KEEP UP TO %d" % (_controller.hold_limit() if _controller != null else 2),
					"Tap hand cards to keep them for next turn, then END TURN. BACK returns to your turn."]
		&"aim":
			return ["THROW", "Tap an area on the map in range, or CANCEL."]
		&"opponent":
			return ["RIVAL'S TURN", "Watch what they do. Your next hand blocks their shots."]
		&"over":
			return ["MATCH OVER", "MENU for a new match."]
		&"brace":
			return ["YOU'RE BEING SHOT", "Pick cards in your next hand to block, then confirm."]
	var hand_n: int = (you.get("hand", []) as Array).size()
	var todo: String = "Tap a card to PLAY it for Move and Search. Tap an area to move or loot. Tap a gun in your played row to FIRE."
	if hand_n == 0:
		todo = "No cards left in hand. Move, loot or fire if you can, then END TURN."
	return ["YOUR TURN · MOVE %d · SEARCH %d" % [int(you.get("move", 0)), int(you.get("search", 0))], todo + " END TURN when done."]


## Long press / right click on a screen control: what it is and what it does (cz-clarity).
func explain_control(key: StringName) -> void:
	var lim: int = _controller.hold_limit() if _controller != null and live else 2
	match key:
		&"DeckButton":
			var you: Dictionary = _state.get("you", {})
			var next: PackedStringArray = []
			for id: Variant in you.get("next", []):
				var c: CardData = card_lookup.call(StringName(str(id)))
				if c != null:
					next.append(c.display_name + (" (blocks %d)" % c.brace if c.brace > 0 else ""))
			_inspector.open_info("Your deck", "Your cards come round in a loop: nothing is shuffled",
					("You draw your hand from the top of your deck. Cards you play or loot go under it, in the order you used them, so they come back later. " +
					"At END TURN you may keep up to %d hand cards on top: they start your next hand.\n\n" +
					"Your NEXT HAND (the top cards) is your armour: when the rival shoots you, cards with a shield there can block damage, then go to the bottom.\n\n" +
					"Next hand now: %s.\nTap the DECK row to show or hide it.") % [lim, ", ".join(next) if not next.is_empty() else "nothing"])
		&"Pools":
			_inspector.open_info("Move and Search", "This turn's points; unused points are lost at END TURN",
					"MOVE: spend 1 to step to a neighbouring area (tap it on the map, then MOVE HERE).\n" +
					"SEARCH: spend it to loot a card in your area (tap your area, then LOOT): the cost is the number on the card's dark disc.\n" +
					"Get them by playing cards: Dash and Trail Boots give Move; Scavenge, Duck and Crowbar give Search. A Hit in your hand can be played for +1 of either.")
		&"LogButton":
			_inspector.open_info("LOG", "Everything that happened this match", "Tap LOG to read every event of the match, newest first.")
		&"UndoButton":
			_inspector.open_info("UNDO", "Take back your last action", "Takes back your last action this turn (a play, a move, a loot). It can't go back past a shot you fired or the start of your turn.")
		&"EndTurnButton":
			_inspector.open_info("END TURN", "Finish your turn in two taps",
					("First tap: choose up to %d hand cards to keep for next turn (they stay on top of your deck). Everything else goes under your deck. " +
					"Second tap: the turn ends and the rival plays. If you end a turn in gas you lose 1 health.") % lim)
		_:
			var help: String = _option_help(key)
			if help != "":
				_inspector.open_info(String(key).capitalize().to_upper(), "What this button does", help)


## Plain words for a dock / sheet option key.
func _option_help(key: StringName) -> String:
	var k: String = String(key)
	match key:
		&"play":
			return "Puts the card into your played row and gives its Move or Search now. Guns are played so they can fire."
		&"adrenaline_move", &"adrenaline_search":
			return "Plays this Hit for +1 Move or +1 Search this turn (Adrenaline)."
		&"patch_up":
			return "Spend 2 Search to put a Hit from your hand or played row back on your health (+1 health)."
		&"ditch":
			return "Spend 1 Search to remove a Starter card from your deck for good, so your better cards come round sooner."
		&"throw":
			return "Throw the grenade: then tap an area in range. Everyone there takes its damage, you too."
		&"attach":
			return "Fix this attachment to a gun in your hand or played row. It stays on the gun."
		&"fire":
			return "Shoot the rival with this gun. Damage minus the rival's Cover (if you're in another area) minus Down; they may block with cards."
		&"move":
			return "Spend 1 Move to step into this neighbouring area."
		&"loot":
			return "Spend Search to take a card from a pile in your area. It goes into your played row (a gun can fire right away) and joins your deck."
		&"drop":
			return "Land here to start the match. Outer areas only."
		&"end_turn":
			return "End your turn, keeping the cards you picked on top of your deck."
		&"close":
			return "Close this without doing anything."
	if k.begins_with("loot_") or k.begins_with("attach_"):
		return "Tap to take it. Long press shows the card."
	return ""


func _inspect_option_card(o: Dictionary) -> void:
	var cid: StringName = StringName(str(o.get("card_id", "")))
	if cid != &"" and card_lookup.call(cid) != null:
		inspect_card(card_lookup.call(cid), String(o.get("where", "")))
	else:
		explain_control(StringName(o["key"]))


## Places the corner controls in the map's sea corners, the dock over the line area and the toast
## over the strip header. Runs after every layout pass.
func _place_overlays() -> void:
	if not is_inside_tree():
		return
	var k: float = _map.px_per_pt()
	var o: Vector2 = (_map.size - CzMap.DESIGN_PT * k) * 0.5
	var pairs: Array = [[_pools, CORNER_TL], [_log_button, CORNER_TR], [_undo_button, CORNER_BL], [_end_button, CORNER_BR]]
	var tap: float = maxf(MIN_TAP_PX, ceilf(CzArtKit.TAP_PT / points_per_px))
	for p: Array in pairs:
		var c: Control = p[0]
		var r: Rect2 = p[1]
		var area: Rect2 = Rect2(o + r.position * k, r.size * k)
		var side: float = maxf(tap, minf(area.size.x, area.size.y) - 8.0)
		var s: Vector2 = Vector2(side, side)
		if c == _pools:
			s = Vector2(area.size.x - 4.0, minf(area.size.y - 8.0, side))
		c.size = s
		c.position = (area.get_center() - s * 0.5).floor()
		if c == _pools and _pools_button != null:
			_pools_button.size = s  # cz-clarity: the touch layer under MOVE / SEARCH
			_pools_button.position = c.position
	# Dock: from the line header to the bottom of the left column.
	var top_left: Vector2 = _line_header.global_position - global_position
	var bottom: float = (_left.global_position.y - global_position.y) + _left.size.y
	_dock.position = top_left
	_dock.size = Vector2(_left.size.x, maxf(0.0, bottom - top_left.y))
	var line_h: float = _dock_text.get_line_height() if _dock_text.get_line_count() > 0 else 20.0
	var title_h: float = _dock_title.get_combined_minimum_size().y
	var room: float = _dock.size.y - 16.0 - 8.0 - title_h - tap
	_dock_text.max_lines_visible = clampi(int(floorf(room / maxf(1.0, line_h))), 1, 4)
	for b: Node in _dock_buttons.get_children():
		(b as Control).custom_minimum_size = Vector2(tap, tap)
	# Toast: over the strip header (live: the DECK row), the width of the right column.
	var anchor: Control = _deck_button if _deck_button != null and _deck_button.visible else _strip_header
	var th: Vector2 = anchor.global_position - global_position
	_toast.position = th
	_toast.size = Vector2(_right.size.x, maxf(anchor.size.y, _toast.get_combined_minimum_size().y))
	_sheet_panel.custom_minimum_size.x = minf(620.0, size.x - 48.0)
	_sheet_scroll.custom_minimum_size.y = minf(5.0 * (tap + 6.0), size.y - 260.0)
	# cz12: Brace / playback panels over the hand area, below the SUGGESTED tags.
	var top: float = (_hand.global_position.y - global_position.y) + TAG_H + 2.0
	var right_end: float = (_right.global_position.y - global_position.y) + _right.size.y
	for p: Control in [_brace_panel, _playback]:
		var ptop: float = top
		if p == _playback and _turn_panel != null and _turn_panel.visible:
			ptop = _turn_panel.global_position.y - global_position.y  # cz-clarity: the rival's steps replace the turn panel
		p.position = Vector2(_right.global_position.x - global_position.x, ptop)
		p.size = Vector2(_right.size.x, maxf(0.0, right_end - ptop))
	# cz19b BUG-09: the Brace panel is only as tall as its content (no big empty plate on tablets).
	_brace_panel.set_area(Rect2(_brace_panel.position, _brace_panel.size))
	_playback.set_tap(tap)
	_place_tags()


func _show_toast(text: String, seconds: float = TOAST_TIME) -> void:
	if _toast == null:
		return
	_toast_label.text = text
	_toast.visible = true
	if is_inside_tree():
		_toast_timer.start(seconds)


func get_toast_text() -> String:
	return _toast_label.text if _toast != null and _toast.visible else ""


# --- Live: dock ------------------------------------------------------------------------

func _refresh_live() -> void:
	if not live or _controller == null or _controller.state == null:
		return
	var you: Dictionary = _state["you"]
	_pools.text = "MOVE %d\nSEARCH %d" % [int(you.get("move", 0)), int(you.get("search", 0))]
	_end_button.text = "END\nTURN"
	_refresh_dock()
	_refresh_brace()
	_refresh_playback()


func _refresh_dock() -> void:
	var title: String = ""
	var text: String = ""
	var opts: Array[Dictionary] = []
	var close_label: String = "CLOSE"
	var show: bool = true
	var you: Dictionary = _state["you"]
	match mode:
		&"drop":
			var rival_area: StringName = _state["rival"]["area"]
			var dropped: String = ("The rival dropped into %s. " % ActionText.area_name(rival_area)) if rival_area != &"" else ""
			title = "DROP · CHOOSE WHERE TO LAND"
			text = dropped + "Tap an outer area (1-6) to drop in; not the Core."
			close_label = ""
			if sel.get("zone", &"") == &"area":
				title = _area_title(StringName(sel["id"]))
				text = dropped + _area_summary(StringName(sel["id"]))
				opts = _controller.area_options(StringName(sel["id"]))
				close_label = "CLOSE"
		&"brace":
			show = false  # cz12: the Brace panel over the hand area
		&"pack":
			var limit: int = _controller.hold_limit()
			var names: PackedStringArray = []
			for inst: int in hold_set:
				names.append(_controller.card(inst).display_name)
			title = "PACK · HOLDING %d OF %d" % [names.size(), limit]
			if names.is_empty():
				text = "Tap hand cards to hold them on top of your loadout (your next hand); the rest goes under."
			else:
				text = "Holding %s. Tap a hand card to hold it or let it go." % ", ".join(names)
			var gas: Array = _gas_areas()
			if gas.has(you["area"]):
				text = "You're in gas: ending here costs 1 Hit. " + text
			opts = [{"key": &"end_turn", "label": "END TURN", "action": {"type": "end_turn", "hold": hold_set.duplicate()},
					"reason": _controller.hold_reason(hold_set)}]
			close_label = "BACK"
		&"aim":
			var c: CardData = _controller.card(aim_card)
			title = "THROW %s" % c.display_name.to_upper()
			text = "Tap an area within %d of you. Everyone there takes %d damage before Cover, you too." % [maxi(c.blast_rng, 0), c.blast_dmg]
			close_label = "CANCEL"
		&"act":
			if sel.is_empty():
				show = false
			else:
				var zone: StringName = sel["zone"]
				if zone == &"area":
					var area: StringName = StringName(sel["id"])
					title = _area_title(area)
					text = _area_summary(area)
					opts = _controller.area_options(area)
				else:
					var inst: int = int(sel["id"])
					var c: CardData = _controller.card(inst)
					title = "%s · %s" % [c.display_name.to_upper(), LineChip.stat_line(c)] if LineChip.stat_line(c) != "" else c.display_name.to_upper()
					match zone:
						&"hand":
							opts = _controller.hand_options(inst)
							text = _hand_hint(c)
						&"line":
							opts = _controller.line_options(inst)
							text = _shot_text(inst) if c.is_weapon() else "Played this turn (line position %d)." % (_inst_index(&"line", inst) + 1)
						&"next":
							text = ("In your next hand: if you're shot before your turn it can block %d." % c.brace) if c.brace > 0 else \
									"In your next hand: you draw it next turn. No shield, so it can't block."
		_:
			show = false
	_dock.visible = show
	if not show:
		_dock_options = []
		return
	_dock_title.text = title
	_dock_text.text = text
	_set_dock_options(opts, close_label)


func _set_dock_options(opts: Array[Dictionary], close_label: String) -> void:
	_clear(_dock_buttons)
	_dock_options = opts.duplicate()
	if close_label != "":
		_dock_options.append({"key": &"close", "label": close_label, "action": {}, "reason": ""})
	var tap: float = maxf(MIN_TAP_PX, ceilf(CzArtKit.TAP_PT / points_per_px))
	for o: Dictionary in _dock_options:
		var b: Button = TapHoldButton.new()  # cz-clarity: long press / right click explains the button
		b.name = "Dock_%s" % String(o["key"])
		b.text = o["label"]
		b.theme_type_variation = &"DockButtonOff" if o["reason"] != "" else &"DockButton"
		b.custom_minimum_size = Vector2(tap, tap)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta(&"key", o["key"])
		var opt: Dictionary = o
		b.tapped.connect(func() -> void: _on_option(opt), CONNECT_DEFERRED)  # it rebuilds the dock
		b.inspect_requested.connect(func() -> void: explain_control(StringName(opt["key"])))
		_dock_buttons.add_child(b)


func _on_option(o: Dictionary) -> void:
	var key: StringName = o["key"]
	option_pressed.emit(key)
	if o["reason"] != "":
		show_notice(o["reason"])
		return
	match key:
		&"close":
			if mode == &"pack" or mode == &"aim":
				mode = &"act"
				hold_set.clear()
				aim_card = 0
			sel = {}
			_render()
			return
		&"throw":
			aim_card = int(sel["id"])
			mode = &"aim"
			sel = {}
			_render()
			return
		&"attach":
			var att: int = int(sel["id"])
			var targets: Array[Dictionary] = _controller.attach_targets(att)
			var legal: Array = targets.filter(func(t: Dictionary) -> bool: return t["reason"] == "")
			if legal.size() == 1:
				_submit(legal[0]["action"])
			else:
				open_sheet("ATTACH %s" % _controller.card(att).display_name.to_upper(), "Choose the gun. Long-press a row to read it.", targets)
			return
		&"loot":
			var area: String = ActionText.area_name(_state["you"]["area"])
			open_sheet("LOOT · %s" % area.to_upper(), "You have Search %d. The card goes into your played row and joins your deck. Long-press a row to read the card." % int(_state["you"]["search"]),
					_controller.loot_options())
			return
	_submit(o["action"])


## Sends one action to the controller. On a refusal the selection stays and the reason shows.
func _submit(action: Dictionary) -> bool:
	var why: String = _controller.why_not(action)
	if why != "":
		show_notice(why)
		return false
	var t: String = String(action.get("type", ""))
	sel = {}
	aim_card = 0
	if t == "end_turn":
		hold_set.clear()
	if t == "brace":
		brace_set.clear()
	if mode == &"pack" or mode == &"aim":
		mode = &"act"
	close_sheet()
	_controller.request(action)
	if is_node_ready():
		_render()
	return true


func _hand_hint(c: CardData) -> String:
	if c.is_hit():
		return "A Hit: play it for +1 Move or +1 Search, or PATCH UP (2 Search) to get the health back."
	if c.blast_dmg > 0:
		return "Throw it into an area up to %d away: %d damage to everyone there." % [maxi(c.blast_rng, 0), c.blast_dmg]
	if c.is_weapon():
		return "A gun: %d damage, %s. PLAY it, then tap it in your played row to FIRE." % [c.dmg, CardWords.range_words(c.rng)]
	if c.is_attachment():
		return "Attach it to a gun in your hand or played row: %s." % CardWords.short(c).trim_prefix("a gun attachment: ")
	# cz-clarity: what it gives, in words (was the card text again: "Search 1").
	return " ".join(CardWords.gives(c))


func _shot_text(weapon: int) -> String:
	var p: Dictionary = _controller.shot_preview(weapon)
	if p["reason"] != "":
		return p["reason"]
	var where: String = ActionText.area_name(_state["rival"]["area"])
	var s: String = "Rival in %s, %d away (range %d). DMG %d − Cover %d − Down %d = %d damage. " % [
			where, int(p["dist"]), int(p["range"]), int(p["dmg"]), int(p["cover"]), int(p["down"]), int(p["damage"])]
	if p["suppressed"]:
		s += "Suppressor: they can't Brace."
	elif int(p["damage"]) <= 0:
		s += "0 damage: firing still uses this weapon's shot."
	else:
		s += "They may Brace."
	return s


func _area_title(area: StringName) -> String:
	var a: AreaData = CardDB.get_area(area)
	var core: bool = a.tier == DataEnums.AreaTier.CORE
	return "%s · %s · COVER %d%s" % [a.display_name.to_upper(), "CORE" if core else "AREA %d" % a.number, a.cover,
			" · GAS" if _gas_areas().has(area) else ""]


func _area_summary(area: StringName) -> String:
	var st: Dictionary = _state["areas"].get(area, {})
	var parts: PackedStringArray = []
	for p: Dictionary in st.get("piles", []):
		var c: CardData = card_lookup.call(p["card"])
		parts.append("%s (Search %d) x%d" % [c.display_name, c.cost, int(p["count"])])
	if st.get("drop", &"") != &"":
		parts.append("drop: %s" % card_lookup.call(st["drop"]).display_name)
	var here: String = "Loot: " + (", ".join(parts) if not parts.is_empty() else "nothing") + "."
	if live and mode != &"drop" and _controller.state != null:
		var me: StringName = _state["you"]["area"]
		if area != me:
			var d: int = _controller.state.data.distance(me, area)
			here = "%d area%s away. " % [d, "" if d == 1 else "s"] + here
	if st.get("gas", false):
		here = "Gas: ending a turn here costs 1 Hit. " + here
	return here


func _gas_areas() -> Array:
	var out: Array = []
	for id: Variant in _state.get("areas", {}).keys():
		if _state["areas"][id].get("gas", false):
			out.append(id)
	return out


# --- Live: Brace prompt (cz12) ------------------------------------------------------------

func _refresh_brace() -> void:
	if _brace_panel == null:
		return
	var on: bool = live and mode == &"brace" and _state.has("brace_prompt") and _controller != null
	if not on:
		_brace_panel.visible = false
		_place_tags.call_deferred()
		return
	var bp: Dictionary = _state["brace_prompt"]
	var sug: Dictionary = bp.get("suggestion", {})
	var suggested: Array = bp.get("suggested", [])
	var eligible: Array = bp.get("eligible", [])
	var pv: Dictionary = _controller.brace_preview(brace_set)
	var src: Dictionary = bp.get("source", {})
	var dmg: int = int(bp.get("damage", 0))
	var title: String = ""
	if String(src.get("kind", "shot")) == "frag":
		title = "INCOMING · FRAG IN %s" % ActionText.area_name(src.get("area", "")).to_upper()
	else:
		title = "INCOMING · %s FROM %s" % [ActionText.card_name(src.get("card", "")).to_upper(),
				ActionText.area_name(src.get("from", "")).to_upper()]
	var sum: String = "DMG %d − Cover %d − Down %d = %d damage" % [int(bp.get("dmg", dmg)), int(bp.get("cover", 0)),
			int(bp.get("down", 0)), dmg]
	var hits: int = int(pv.get("hits", dmg))
	var result: String = ""
	if bool(pv.get("eliminated", false)):
		result = "YOU TAKE %d HIT%s · YOU'RE OUT" % [hits, "" if hits == 1 else "S"]
	elif hits == 0:
		result = "0 HITS · HEALTH %d" % int(pv.get("health", 0))
	else:
		result = "YOU TAKE %d HIT%s · HEALTH %d %s %d" % [hits, "" if hits == 1 else "S", int(pv.get("health", 0)), MatchTheme.ARROW, int(pv.get("health_after", 0))]
	var line: String = ""
	var chosen_is_suggested: bool = not brace_set.is_empty() and _same_set(brace_set, suggested)
	var comes: String = _comes_up_text(pv.get("comes_up", []))
	if eligible.is_empty():
		line = String(sug.get("reason", ""))
	elif brace_set.is_empty():
		line = "SUGGESTED: %s %s %s. %s" % [_names(suggested), MatchTheme.ARROW, _hits_word(int(sug.get("hits", 0))), String(sug.get("reason", ""))]
	elif chosen_is_suggested:
		line = "Suggested brace chosen. " + comes
	else:
		line = "Your choice: %s (Brace %d). Suggested: %s %s %s. %s" % [_names(brace_set), int(pv.get("total", 0)),
				_names(suggested), MatchTheme.ARROW, _hits_word(int(sug.get("hits", 0))), comes]
	var buttons: Array = []
	if not eligible.is_empty():
		if chosen_is_suggested:
			buttons.append({"key": &"brace_clear", "label": "CLEAR"})
		else:
			buttons.append({"key": &"brace_suggested", "label": "USE SUGGESTED", "off": suggested.is_empty()})
	var confirm: String = "TAKE %d HIT%s" % [hits, "" if hits == 1 else "S"] if brace_set.is_empty() else \
			"BRACE · %d HIT%s" % [hits, "" if hits == 1 else "S"]
	buttons.append({"key": &"brace", "label": confirm})
	var tap: float = maxf(MIN_TAP_PX, ceilf(CzArtKit.TAP_PT / points_per_px))
	_brace_panel.show_prompt({"title": title, "sum": sum, "result": result, "line": line.strip_edges(),
			"buttons": buttons, "tap": tap, "scale": _panel_scale()})
	_place_tags.call_deferred()


func _on_brace_option(key: StringName) -> void:
	option_pressed.emit(key)
	if mode != &"brace":
		return
	match key:
		&"brace_suggested":
			var suggested: Array = _state.get("brace_prompt", {}).get("suggested", [])
			brace_set.clear()
			for x: Variant in suggested:
				brace_set.append(int(x))
			_apply_marks()
			_refresh_brace()
		&"brace_clear":
			brace_set.clear()
			_apply_marks()
			_refresh_brace()
		&"brace":
			_submit({"type": "brace", "cards": brace_set.duplicate()})


## SUGGESTED tags under the suggested next-hand cards while the Brace prompt is open.
func _place_tags() -> void:
	if _tags == null or not is_inside_tree():
		return
	for c: Node in _tags.get_children():
		_tags.remove_child(c)
		c.queue_free()
	if not (live and mode == &"brace" and _brace_panel.visible):
		return
	var suggested: Array = _state.get("brace_prompt", {}).get("suggested", [])
	var cards: Array[Control] = get_cards(&"next")
	for i: int in cards.size():
		if not suggested.has(_inst_for(&"next", i)):
			continue
		var r: Rect2 = cards[i].get_global_rect()
		var w: float = r.size.x
		if i + 1 < cards.size():
			w = minf(w, cards[i + 1].get_global_rect().position.x - r.position.x - 2.0)
		var l: Label = Label.new()
		l.name = "Suggested_%d" % i
		l.text = "SUGGESTED"
		l.theme_type_variation = &"TagChipNow"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.clip_text = true
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.position = Vector2(r.position.x, r.end.y + 2.0) - global_position
		l.size = Vector2(w, TAG_H)
		_tags.add_child(l)


func _same_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for x: Variant in a:
		if not b.has(x):
			return false
	return true


func _names(insts: Array) -> String:
	if insts.is_empty():
		return "no brace"
	var out: PackedStringArray = []
	for x: Variant in insts:
		var c: CardData = _controller.card(int(x))
		out.append("%s (%d)" % [c.display_name, c.brace] if c != null else "?")
	return " + ".join(out)


func _hits_word(n: int) -> String:
	return "%d Hit%s" % [n, "" if n == 1 else "s"]


func _comes_up_text(ids: Array) -> String:
	if ids.is_empty():
		return ""
	var out: PackedStringArray = []
	for id: Variant in ids:
		out.append(ActionText.card_name(id))
	return "%s come%s up into your next hand instead." % [", ".join(out), "s" if ids.size() == 1 else ""]


# --- Live: rival playback (cz12) -----------------------------------------------------------

func _refresh_playback() -> void:
	if _playback == null:
		return
	var you: Dictionary = _state.get("you", {})
	var on: bool = live and mode == &"opponent" and (you.get("hand", []) as Array).is_empty()
	_playback.visible = on
	if on and _controller != null:
		_playback.set_fast(bool(_controller.playback_fast))
		_playback.set_title("RIVAL'S TURN · %s · STEP %d" % [_controller.opponent_kind().to_upper(), maxi(1, int(_playback.step_count))])


func _on_playback_step(step: Dictionary) -> void:
	if _tracer != null and StringName(step.get("to", &"")) != &"":
		_tracer.show_step(step, maxf(float(step.get("duration", 0.0)), 0.6))
	if not bool(step.get("rival", false)) or _playback == null:
		return
	if step["type"] == "turn_started" or (step["type"] == "dropped" and _playback.step_count == 0):
		_playback.begin("")
	_playback.add_step(String(step["text"]))
	_refresh_playback()


func _on_playback_finished(summary: String, _steps: Array, skipped: bool) -> void:
	if skipped and summary != "" and mode != &"brace":  # a Brace step has its own panel
		_show_toast(summary, SUMMARY_TIME)
	add_feed_line(summary)  # cz-clarity: the rival's whole turn in one line, on top of the feed


func _on_playback_option(key: StringName) -> void:
	option_pressed.emit(key)
	if _controller == null:
		return
	match key:
		&"fast":
			_controller.fast_forward()
			_playback.set_fast(bool(_controller.playback_fast))
		&"skip":
			_controller.skip_playback()


# --- Live: sheet ----------------------------------------------------------------------

## A modal list of options (each a 64 px row). Illegal options say why when tapped.
func open_sheet(title: String, text: String, opts: Array[Dictionary], close_label: String = "CLOSE") -> void:
	_sheet_title.text = title
	_sheet_text.text = text
	_sheet_text.visible = text != ""
	_clear(_sheet_list)
	_sheet_options = opts.duplicate()
	var tap: float = maxf(MIN_TAP_PX, ceilf(CzArtKit.TAP_PT / points_per_px))
	for o: Dictionary in opts:
		var b: Button = TapHoldButton.new()  # cz-clarity: long press / right click shows the card
		b.name = "Sheet_%s" % String(o["key"])
		b.text = o["label"]
		b.theme_type_variation = &"DockButtonOff" if o["reason"] != "" else &"DockButton"
		b.custom_minimum_size = Vector2(0, tap)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.set_meta(&"key", o["key"])
		var opt: Dictionary = o
		b.tapped.connect(func() -> void: _on_sheet_option(opt), CONNECT_DEFERRED)
		b.inspect_requested.connect(func() -> void: _inspect_option_card(opt))
		_sheet_list.add_child(b)
	_sheet_close.text = close_label
	_sheet_close.visible = close_label != ""
	_sheet_close.custom_minimum_size = Vector2(0, tap)
	_sheet.visible = true
	_place_overlays()


func close_sheet() -> void:
	if _sheet != null:
		_sheet.visible = false


func is_sheet_open() -> bool:
	return _sheet != null and _sheet.visible


func _on_sheet_option(o: Dictionary) -> void:
	var key: StringName = o["key"]
	option_pressed.emit(key)
	if o["reason"] != "":
		_sheet_text.text = o["reason"]
		_sheet_text.visible = true
		last_notice = o["reason"]
		notice_shown.emit(o["reason"])
		return
	match key:
		&"resume":
			close_sheet()
		&"concede":
			open_sheet("CONCEDE?", "The rival wins this match.", [
					{"key": &"concede_yes", "label": "CONCEDE", "action": {}, "reason": ""},
					{"key": &"resume", "label": "KEEP PLAYING", "action": {}, "reason": ""}], "")
		&"concede_yes":
			close_sheet()
			_controller.request({"type": "concede"})
		&"leave", &"title":
			close_sheet()
			SceneRouter.goto_route(&"title")
		&"new_match":
			close_sheet()
			start_live()
		_:
			_submit(o["action"])


func _show_end() -> void:
	if shell != null:
		shell.show_end()
		return
	var v: Dictionary = _controller.view()
	var me: int = int(v.get("seat", 0))
	var r: Dictionary = v.get("match_end", {})
	var title: String = "DRAW"
	if String(r.get("result", "")) == "win":
		title = "YOU WIN" if int(r.get("winner", -1)) == me else "THE RIVAL WINS"
	var text: String = ActionText.result_text(r, me) + " Round %d. Health: you %d, rival %d." % [int(v["round"]),
			int(v["me"]["health"]), int(v["opponent"]["health"])]
	open_sheet(title, text, [{"key": &"new_match", "label": "NEW MATCH", "action": {}, "reason": ""},
			{"key": &"title", "label": "TITLE", "action": {}, "reason": ""}], "CLOSE")


# --- Live: taps -------------------------------------------------------------------------

func _inst_for(zone: StringName, index: int) -> int:
	var you: Dictionary = _state.get("you", {})
	match zone:
		&"hand":
			var ids: Array = you.get("hand_ids", [])
			return int(ids[index]) if index < ids.size() else 0
		&"next":
			var ids: Array = you.get("next_ids", [])
			return int(ids[index]) if index < ids.size() else 0
		&"line":
			return int(_line_entries[index].get("id", 0)) if index < _line_entries.size() else 0
	return 0


func _inst_index(zone: StringName, inst: int) -> int:
	var you: Dictionary = _state.get("you", {})
	match zone:
		&"hand":
			return (you.get("hand_ids", []) as Array).find(inst)
		&"next":
			return (you.get("next_ids", []) as Array).find(inst)
		&"line":
			for i: int in _line_entries.size():
				if int(_line_entries[i].get("id", 0)) == inst:
					return i
	return -1


func _line_has(you: Dictionary, inst: int) -> bool:
	for e: Dictionary in you.get("line", []):
		if int(e.get("id", 0)) == inst:
			return true
	return false


func _live_card_tap(view: Control, zone: StringName, index: int) -> void:
	var inst: int = _inst_for(zone, index)
	match mode:
		&"opponent":
			show_notice("It's the rival's turn. Long-press any card to read it.")
		&"over":
			_show_end()
		&"drop":
			show_notice("Pick your drop area first: tap an outer area on the map.")
		&"aim":
			show_notice("Tap an area on the map to throw, or CANCEL.")
		&"brace":
			if zone != &"next":
				show_notice("Brace first: tap armour cards in your next hand (the top row), then BRACE.")
				return
			_toggle_brace(inst)
		&"pack":
			if zone == &"line" and _line_is_rival:
				return
			if zone == &"next":
				show_notice("Packing: tap cards in your hand to hold them, then END TURN.")
				return
			_toggle_hold(inst)
		_:
			if _line_is_rival and zone == &"line":
				show_notice("That's the rival's line. Long-press a card to read it.")
				return
			if sel.get("zone", &"") == zone and int(sel.get("id", 0)) == inst:
				sel = {}
			else:
				sel = {"zone": zone, "id": inst}
			_apply_marks()
			_refresh_buttons()
			_refresh_dock()
			_map.set_state({"selected": &""})


func _toggle_hold(inst: int) -> void:
	if hold_set.has(inst):
		hold_set.erase(inst)
	else:
		var next: Array = hold_set.duplicate()
		next.append(inst)
		var why: String = _controller.hold_reason(next)
		if why != "":
			show_notice(why)
			return
		hold_set.append(inst)
	_apply_marks()
	_refresh_dock()


func _toggle_brace(inst: int) -> void:
	var bp: Dictionary = _state.get("brace_prompt", {})
	var eligible: Array = bp.get("eligible", [])
	if brace_set.has(inst):
		brace_set.erase(inst)
	elif eligible.has(inst):
		brace_set.append(inst)
	else:
		var c: CardData = _controller.card(inst)
		if c.is_hit():
			show_notice("A Hit can't brace.")
		elif (_state["you"].get("braced", []) as Array).has(inst):
			show_notice("%s already braced this turn." % c.display_name)
		elif c.brace <= 0:
			show_notice("%s has no Brace value." % c.display_name)
		else:
			show_notice("%s isn't in your next hand." % c.display_name)
		return
	_apply_marks()
	_refresh_brace()


## Card marks for the live modes: selection (with the fan opened at it), Hold, Brace, dimming.
func _apply_marks() -> void:
	if not live:
		return
	var holdable: Array = []
	if mode == &"pack":
		holdable = _controller.holdable()
	var eligible: Array = _state.get("brace_prompt", {}).get("eligible", [])
	_hand.focus_index = -1
	_strip.focus_index = -1
	for zone: StringName in [&"hand", &"next"]:
		var row: Container = _hand if zone == &"hand" else _strip
		var cards: Array[Control] = get_cards(zone)
		for i: int in cards.size():
			var cv: CzCard = cards[i]
			var inst: int = _inst_for(zone, i)
			var picked: bool = sel.get("zone", &"") == zone and int(sel.get("id", 0)) == inst
			cv.selected = picked or (mode == &"brace" and zone == &"next" and brace_set.has(inst))
			if picked:
				row.focus_index = i
			if zone == &"hand":
				cv.held = mode == &"pack" and hold_set.has(inst)
				cv.dimmed = mode == &"pack" and not holdable.has(inst)
			else:
				cv.dimmed = mode == &"brace" and not eligible.has(inst)
	for chip: Node in _line.get_children():
		var inst: int = _inst_for(&"line", (chip as Button).get("index"))
		chip.set("selected", not _line_is_rival and sel.get("zone", &"") == &"line" and int(sel.get("id", 0)) == inst)


func _on_undo() -> void:
	option_pressed.emit(&"undo")
	if not live:
		return
	if mode == &"pack" or mode == &"aim":
		mode = &"act"
		hold_set.clear()
		aim_card = 0
	var why: String = _controller.why_not({"type": "undo"})
	if why != "":
		show_notice(why)
		return
	sel = {}
	_controller.request({"type": "undo"})
	_render()


func _on_end_turn() -> void:
	option_pressed.emit(&"end_turn")
	if not live:
		return
	match mode:
		&"pack":
			var a: Dictionary = {"type": "end_turn", "hold": hold_set.duplicate()}
			var why: String = _controller.hold_reason(hold_set)
			if why != "":
				show_notice(why)
				return
			_submit(a)
		&"act", &"aim":
			var why: String = _controller.why_not({"type": "end_turn", "hold": []})
			if why != "":
				show_notice(why)
				return
			mode = &"pack"
			sel = {}
			aim_card = 0
			hold_set.clear()
			_render()
		&"brace":
			show_notice("Brace first: tap armour cards in your next hand (the top row), then BRACE.")
		&"drop":
			show_notice("Pick your drop area first: tap an outer area on the map.")
		&"opponent":
			show_notice("It's the rival's turn.")


func _on_log() -> void:
	var lines: PackedStringArray = _controller.log_lines if live else PackedStringArray()
	var tail: PackedStringArray = lines.slice(maxi(0, lines.size() - 40))
	tail.reverse()
	_inspector.open_info("Match log", "Newest first", "\n".join(tail) if not tail.is_empty() else "Nothing yet.")


# --- Accessors for tests and cz11 ------------------------------------------------

## Controls that must be on screen, inside the safe area and not overlap (tests).
func get_key_controls() -> Dictionary:
	return {"MenuButton": _menu, "YouPanel": _you, "ZoneTrack": _zone, "RivalPanel": _rival,
			"InfoButton": _info, "MapView": _map, "LineChips": _line_scroll, "StripCards": _strip, "HandCards": _hand}


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


func get_dock() -> PanelContainer:
	return _dock


func get_dock_title() -> String:
	return _dock_title.text if _dock.visible else ""


func get_dock_text() -> String:
	return _dock_text.text if _dock.visible else ""


## A dock button by option key (&"play", &"fire", &"close"…), or null.
func get_dock_button(key: StringName) -> Button:
	if not _dock.visible:
		return null
	for b: Node in _dock_buttons.get_children():
		if b.get_meta(&"key", &"") == key and not b.is_queued_for_deletion():
			return b
	return null


func get_dock_keys() -> Array[StringName]:
	var out: Array[StringName] = []
	for o: Dictionary in _dock_options:
		out.append(o["key"])
	return out


## cz12: the Brace prompt / playback panels and their buttons (null when hidden).
func get_brace_panel() -> PanelContainer:
	return _brace_panel


func get_brace_button(key: StringName) -> Button:
	return _brace_panel.get_button(key) if _brace_panel != null else null


func get_playback_panel() -> PanelContainer:
	return _playback


func get_playback_button(key: StringName) -> Button:
	return _playback.get_button(key) if _playback != null else null


func get_tracer() -> Control:
	return _tracer


func get_brace_tags() -> Array[Label]:
	var out: Array[Label] = []
	if _tags != null:
		for c: Node in _tags.get_children():
			if not c.is_queued_for_deletion():
				out.append(c)
	return out


func get_sheet_button(key: StringName) -> Button:
	if not is_sheet_open():
		return null
	for b: Node in _sheet_list.get_children():
		if b.get_meta(&"key", &"") == key and not b.is_queued_for_deletion():
			return b
	return null


func get_sheet_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for b: Node in _sheet_list.get_children():
		if not b.is_queued_for_deletion():
			out.append(b)
	return out


func get_sheet_title() -> String:
	return _sheet_title.text if is_sheet_open() else ""


func get_sheet_text() -> String:
	return _sheet_text.text if is_sheet_open() else ""


func get_corner_buttons() -> Dictionary:
	return {&"undo": _undo_button, &"end_turn": _end_button, &"log": _log_button}


func get_pools_label() -> Label:
	return _pools


func get_line_scroll() -> ScrollContainer:
	return _line_scroll


## Labels whose whole text must show (tests).
func get_important_labels() -> Array[Label]:
	var out: Array[Label] = []
	out.append_array(_you.get_labels())
	out.append_array(_rival.get_labels())
	out.append(_zone.get_title_label())
	out.append_array(_zone.get_chip_labels())
	out.append(_strip_header)
	out.append(_line_header)
	out.append(_pools)
	return out


# --- Inspector ----------------------------------------------------------------------

func _inspect_card_view(cc: CzCard) -> void:
	var zone: StringName = cc.get_meta(&"zone", &"")
	var i: int = cc.get_meta(&"index", 0)
	var where: String = {&"hand": "In your hand",
			&"next": "In your next hand (card %d from the top of your deck)" % (i + 1)}.get(zone, "")
	if cc.held and zone == &"next":
		where = "Kept from last turn: on top of your deck, in your next hand"
	elif cc.down:
		where = "A Hit on top of your deck: you are Down (shots at you deal 1 less) until you draw it"
	var id: StringName = cc.get_meta(&"card_id", &"")
	var c: CardData = card_lookup.call(id)
	var now: String = ""
	if live and c != null:
		if zone == &"hand" and (c.is_hit() or c.is_weapon() or c.is_attachment() or c.blast_dmg > 0):
			now = "NOW: " + _hand_hint(c)  # plain cards: WHAT IT GIVES YOU already says it
		elif zone == &"next" and c.brace > 0:
			now = "NOW: if the rival shoots you before your turn, it can block %d damage." % c.brace
	_inspector.open_card(c, {"where": where, "now": now})
	card_inspected.emit(id, zone)


func _inspect_line_chip(chip: Button) -> void:
	var whose: String = "In the rival's line" if _line_is_rival else "In your line"
	var now: String = ""
	if live and not _line_is_rival and chip.card != null and chip.card.is_weapon():
		var inst: int = _inst_for(&"line", chip.index)
		now = "NOW: " + _shot_text(inst) if inst != 0 and _controller != null and _controller.state != null and mode == &"act" else ""
	_inspector.open_card(chip.card, {"where": "%s (played this turn, position %d)" % [whose, chip.index + 1], "attached": chip.attached, "now": now})
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
		lines.append("  %s (%s, Search %d) x%d: %s" % [c.display_name, c.rarity_letter(), c.cost, int(p["count"]), CardWords.short(c)])
	if st.get("drop", &"") != &"":
		var dc: CardData = card_lookup.call(st["drop"])
		lines.append("Supply drop: %s (Search %d): %s" % [dc.display_name, CzCardArt.drop_cost(), CardWords.short(dc)])
	var crate: Array = st.get("crate", [])
	if not crate.is_empty():
		var names: PackedStringArray = []
		for cid: StringName in crate:
			names.append(card_lookup.call(cid).display_name)
		lines.append("Crate: %s" % ", ".join(names))
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
	lines.insert(0, "One Zone card flips at the start of each round. GAS closes an area: its loot is gone and ending a turn there costs 1 health. A SUPPLY DROP is strong loot (Search %d). The FINAL CIRCLE hits everyone; after round %d the healthiest player wins.\n" % [CzCardArt.drop_cost(), CardDB.zone_deck().size()])
	_inspector.open_info("Zone deck · route %s" % ROUTE_LETTER[clampi(route, 0, 2)],
			"Round %d. The deck is public: one card per round." % int(_state.get("round", 1)), "\n".join(lines))


func inspect_player(which: StringName) -> void:
	var d: Dictionary = _state.get(String(which), {})
	var lines: PackedStringArray = []
	lines.append("Health %d of %d. Each Hit takes 1 health and puts a Hit card on top of the deck." % [int(d.get("health", 0)), int(d.get("max_health", 5))])
	if int(d.get("health", 0)) <= 0:
		lines.append("At 0 health the next Hit puts this player out. PATCH UP (2 Search) or a Heal card gives health back from Hits in hand or played row.")
	lines.append("DOWN: a Hit sits in the next hand, so every shot at them deals 1 less." if d.get("down", false) else "Not Down.")
	lines.append("BOUNTY: holds the Bounty (most health). Whoever lands a Hit on them heals 1; in the final circle they take 1 extra Hit." if d.get("bounty", false) else "No Bounty.")
	if which == &"rival":
		lines.append("Deck: %d cards. The order is private." % int(d.get("loadout_count", 0)))
		lines.append("Kept from last turn: %d card%s on top of their deck. Which cards is hidden, but they can block with them." % [int(d.get("held_count", 0)), "" if int(d.get("held_count", 0)) == 1 else "s"])
		var last: PackedStringArray = []
		for id: StringName in d.get("last_line", []):
			last.append(card_lookup.call(id).display_name)
		lines.append("Last turn's line: %s." % (", ".join(last) if not last.is_empty() else "nothing"))
	else:
		var next: PackedStringArray = []
		for id: StringName in d.get("next", []):
			var c: CardData = card_lookup.call(id)
			next.append(c.display_name + (" (Brace %d)" % c.brace if c.brace > 0 else ""))
		lines.append("Your next hand (top of your deck): %s. +%d cards below. Tap the DECK row to see it." % [", ".join(next), int(d.get("loadout_rest", 0))])
	var title: String = "You" if which == &"you" else "Rival (%s)" % d.get("kind", "AI")
	var area: AreaData = CardDB.get_area(d.get("area", &""))
	_inspector.open_info(title, "Area: %s" % (area.display_name if area != null else "not dropped yet"), "\n".join(lines))


# --- Input --------------------------------------------------------------------------

func _on_card_tapped(view: Control, zone: StringName, index: int, card_id: StringName) -> void:
	card_tapped.emit(zone, index, card_id)
	if mock_interactions:
		_select(view)
		return
	if live:
		_live_card_tap(view, zone, index)


func _on_area_tapped(area_id: StringName) -> void:
	area_tapped.emit(area_id)
	if live:
		match mode:
			&"opponent":
				show_notice("It's the rival's turn. Long-press an area to read it.")
			&"over":
				_show_end()
			&"brace":
				show_notice("Brace first: tap armour cards in your next hand (the top row), then BRACE.")
			&"pack":
				show_notice("Packing: tap hand cards to hold, then END TURN; BACK returns to your turn.")
			&"aim":
				_submit({"type": "frag", "card": aim_card, "area": String(area_id)})
			_:
				sel = {} if (sel.get("zone", &"") == &"area" and sel.get("id", &"") == area_id) else {"zone": &"area", "id": area_id}
				_map.set_state({"selected": StringName(sel["id"]) if not sel.is_empty() else &""})
				_apply_marks()
				_refresh_buttons()
				_refresh_dock()
		return
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
	if live and sel.is_empty():
		show_how_to_play()
		return
	if live and not sel.is_empty():
		var zone: StringName = sel["zone"]
		if zone == &"area":
			inspect_area(StringName(sel["id"]))
			return
		var i: int = _inst_index(zone, int(sel["id"]))
		var cards: Array[Control] = get_cards(zone)
		if i >= 0 and i < cards.size():
			if zone == &"line":
				_inspect_line_chip(cards[i])
			else:
				_inspect_card_view(cards[i])
		return
	if _selected != null and is_instance_valid(_selected):
		if _selected is CzCard:
			_inspect_card_view(_selected)
		else:
			_inspect_line_chip(_selected)
	elif _selected_area != &"":
		inspect_area(_selected_area)


func _on_menu() -> void:
	menu_requested.emit()
	if live and shell != null:
		shell.open_pause()
		return
	if live:
		var over: bool = mode == &"over"
		var opts: Array[Dictionary] = [{"key": &"resume", "label": "RESUME", "action": {}, "reason": ""}]
		if not over:
			opts.append({"key": &"concede", "label": "CONCEDE…", "action": {}, "reason": ""})
		else:
			opts.append({"key": &"new_match", "label": "NEW MATCH", "action": {}, "reason": ""})
		opts.append({"key": &"leave", "label": "LEAVE TO TITLE (this match is not saved yet)", "action": {}, "reason": ""})
		open_sheet("MENU", "", opts, "")
		return
	if mock_interactions:
		SceneRouter.goto_route(&"title")


func _on_round_started(round_index: int) -> void:
	if _state.is_empty() or live:
		return
	_state["round"] = round_index
	_zone.setup(int(_state["zone_index"]), int(_state["route"]), round_index)
	_zone.set_short_title(compact)

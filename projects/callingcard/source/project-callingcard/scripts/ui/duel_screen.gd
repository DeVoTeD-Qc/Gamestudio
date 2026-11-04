# duel_screen.gd
# Purpose: Duel screen layout (cc07): score bar (two lacquer counters with Signature ribbons and
#   the turn banner), the 3-4-3 brick wall, the hand, INFO and PLACE buttons, and the card
#   inspector. Layout is anchors + containers; this script only sizes the bricks from the room
#   the screen has and applies notch-safe margins.
#   Sizes (logical px; ScreenProfile keeps 1 px >= 0.72 pt):
#     1280x720 desktop   -> bricks 288x72, hand 3 + 2 rows.
#     1168x540 phone     -> bricks 270x68 (246x64 with notch insets), hand 3 + 2.
#   Every tap target >= 64 px; text >= 16 px; values and scores >= 24 px.
# State: show_state(Dictionary) with the shape documented in mock_duel_data.gd. The screen also
#   listens to EventBus (card_placed, card_captured, ambush_sprung, carded, score_changed,
#   turn_started, duel_started) and updates that state, so cc05/cc08 can drive it by signals.
# Hooks for cc08 (duel flow): set mock_interactions = false and listen to card_picked,
#   slot_chosen, place_confirmed, menu_requested; call set_valid_slots(), set_pending(), and
#   show_state(). card_lookup turns a card id into a UI card Dictionary (default: mock table;
#   cc08 swaps in CardDB). With mock_interactions = true (no controller yet) PLACE emits
#   EventBus.card_placed / turn_started itself with no captures (no rules here).
# Art (cc14): cards are BannerCard (scenes/card/BannerCard.tscn) inside the slot / hand buttons;
#   theme = assets/themes/wall_theme.tres + duel-only variations (duel_theme.gd).
# Dependencies: EventBus, SceneRouter (mock MENU only), wall/hand/counter/inspector scenes,
#   screen_profile.gd, duel_theme.gd, mock_duel_data.gd, BannerCard (cc14).
# Author: UI/UX Agent (cc07)
extends Control

signal card_picked(card_id: StringName)
signal slot_chosen(slot_id: StringName)
signal place_confirmed(card_id: StringName, slot_id: StringName)
signal menu_requested
## cc08: a slot listed in pick_targets was tapped (e.g. the card a Cipher copies).
signal target_tapped(slot_id: StringName)

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const DuelTheme: GDScript = preload("res://scripts/ui/duel_theme.gd")
const MockDuelData: GDScript = preload("res://scripts/ui/mock_duel_data.gd")

const BASE_MARGIN: Vector2 = Vector2(32, 18)
const BASE_MARGIN_COMPACT: Vector2 = Vector2(16, 10)
const MAX_BRICK: Vector2 = Vector2(288, 72)
const MIN_BRICK_H: float = 64.0
const WALL_GAP: Vector2 = Vector2(10, 10)
const HAND_HEADER_H: float = 31.0

## Safe area in logical px (tests / previews). Empty = read DisplayServer on phones.
var safe_area_override: Rect2 = Rect2()
## True until a duel controller (cc08) takes over the input flow.
var mock_interactions: bool = true
var card_lookup: Callable = MockDuelData.card
var compact: bool = false
var hand_strip: bool = false

var _state: Dictionary = {}
var _picked: StringName = &""
var _pending_slot: StringName = &""
var _valid_slots: Array = []
## cc08: slot -> Vector2 direction of the capture-preview arrow on that card.
var _preview: Dictionary = {}
var _pending_boost: Vector3i = Vector3i.ZERO
## cc08: occupied slots whose tap means "this one" (target_tapped) instead of "inspect".
var pick_targets: Array = []
## cc08 (mock_interactions = false): PLACE is enabled only when the controller says so.
var place_ready: bool = false

@onready var _safe_area: MarginContainer = %SafeArea
@onready var _column: VBoxContainer = %Column
@onready var _menu: Button = %MenuButton
@onready var _player_counter: PanelContainer = %PlayerCounter
@onready var _rival_counter: PanelContainer = %RivalCounter
@onready var _turn_panel: PanelContainer = %TurnPanel
@onready var _turn_title: Label = %TurnTitle
@onready var _turn_sub: Label = %TurnSub
@onready var _wall: PanelContainer = %Wall
@onready var _hand: VBoxContainer = %Hand
@onready var _info: Button = %InfoButton
@onready var _place: Button = %PlaceButton
@onready var _inspector: Control = %CardInspector
var _toast_serial: int = 0


func _ready() -> void:
	theme = pick_theme()
	get_viewport().size_changed.connect(_relayout)
	_menu.pressed.connect(_on_menu)
	_info.pressed.connect(_on_info)
	_place.pressed.connect(_on_place)
	_hand.card_picked.connect(_on_hand_picked)
	_hand.card_unpicked.connect(_on_hand_unpicked)
	_hand.card_inspect_requested.connect(func(id: StringName) -> void: inspect_card(id, {"owner": &"player", "where": "hand"}))
	_wall.slot_tapped.connect(_on_slot_tapped)
	_wall.slot_inspect_requested.connect(inspect_slot)
	EventBus.duel_started.connect(_on_duel_started)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.card_placed.connect(_on_card_placed)
	EventBus.card_captured.connect(_on_card_captured)
	EventBus.ambush_sprung.connect(_on_ambush_sprung)
	EventBus.carded.connect(_on_carded)
	EventBus.score_changed.connect(_on_score_changed)
	_relayout()
	# A DuelController child (cc08) drives the screen; without one the screen shows mock data.
	if _state.is_empty() and mock_interactions:
		show_state(MockDuelData.mid_state())
	EventBus.screen_shown.emit(&"duel")


## cc14's wall_theme.tres plus the duel-only variations (scripts/ui/duel_theme.gd).
static func pick_theme() -> Theme:
	return DuelTheme.build()


## Brick size for a wall that may use avail_w logical px (inside the wall panel).
static func brick_size_for(avail_w: float) -> Vector2:
	var w: float = floorf(minf((avail_w - 3.0 * WALL_GAP.x) / 4.0, MAX_BRICK.x))
	return Vector2(w, maxf(MIN_BRICK_H, roundf(w / 4.0)))


# --- State ---------------------------------------------------------------------

func show_state(state: Dictionary) -> void:
	_state = state.duplicate(true)
	_render()


func get_state() -> Dictionary:
	return _state


## cc08: amber glow on these empty slots (legal drops for the picked card).
func set_valid_slots(slot_ids: Array) -> void:
	_valid_slots = slot_ids.duplicate()
	for s: Node in _wall.get_slots():
		s.target_state = &"valid" if _valid_slots.has(s.slot_id) else &"none"


## cc08: the slot the picked card would go to (shows the card there and enables PLACE).
func set_pending(slot_id: StringName) -> void:
	_pending_slot = slot_id
	_render_wall()
	_refresh_buttons()


## cc08: capture preview. flips: {slot: Vector2 arrow direction}; boost: the pending card's
## placement bonus (effective - printed values: Set Link, Clutch), shown in amber.
func set_preview(flips: Dictionary, boost: Vector3i = Vector3i.ZERO) -> void:
	_preview = flips.duplicate()
	_pending_boost = boost
	_render_wall()


func get_preview() -> Dictionary:
	return _preview


func get_picked() -> StringName:
	return _picked


func get_pending() -> StringName:
	return _pending_slot


## Drops the picked card, the pending slot, glows and preview.
func clear_pick() -> void:
	_hand.picked_id = &""
	_picked = &""
	_pending_slot = &""
	_preview.clear()
	_pending_boost = Vector3i.ZERO
	pick_targets = []
	place_ready = false
	set_valid_slots([])
	_render()


## Centre of a brick in the wall's coordinates (preview arrow directions).
func slot_center(slot_id: StringName) -> Vector2:
	var s: Control = _wall.get_slot(slot_id)
	return s.position + s.size * 0.5 if s != null else Vector2.ZERO


## cc08: one card changes controller without an EventBus signal (Reclaim).
func set_slot_owner(slot_id: StringName, side: StringName) -> void:
	if _state.get("wall", {}).has(slot_id):
		_state["wall"][slot_id]["owner"] = side
		_render_wall()


## Short message in the hand header ("Pick a card first", the preview summary). It replaces the
## tap hint for `seconds` (0 = until the next message) and never covers the wall.
func show_toast(text: String, seconds: float = 2.6) -> void:
	_hand.show_status(text)
	_toast_serial += 1
	var serial: int = _toast_serial
	if is_inside_tree() and seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
		if serial == _toast_serial and is_instance_valid(_hand):
			_hand.clear_status()


func get_toast_text() -> String:
	return _hand.get_status()


func get_overlay() -> Control:
	return %DuelOverlay


func _render() -> void:
	if not is_node_ready() or _state.is_empty():
		return
	var p: Dictionary = _state.get("player", {})
	var r: Dictionary = _state.get("rival", {})
	_player_counter.show_counter(_counter_data(p, &"player"))
	_rival_counter.show_counter(_counter_data(r, &"rival"))
	var wall: Dictionary = _state.get("wall", {})
	if wall.size() >= MockDuelData.SLOTS.size():
		_turn_title.text = "WALL FULL"
	elif _state.get("turn_side", &"player") == &"player":
		_turn_title.text = "YOUR TURN"
	else:
		_turn_title.text = "%s'S TURN" % String(r.get("name", "Rival")).to_upper()
	_turn_sub.text = "Turn %d of %d" % [mini(int(_state.get("turn_index", 1)), int(_state.get("turns_total", 10))), int(_state.get("turns_total", 10))]
	var hand: Array = []
	for id: StringName in p.get("hand", []):
		hand.append(card_lookup.call(id))
	_hand.show_hand(hand, p.get("signature_id", &""))
	if _picked != &"" and not (p.get("hand", []) as Array).has(_picked):
		_picked = &""
		_pending_slot = &""
	_render_wall()
	_refresh_buttons()


func _render_wall() -> void:
	var entries: Dictionary = {}
	var wall: Dictionary = _state.get("wall", {})
	var sigs: Array = [_state.get("player", {}).get("signature_id", &""), _state.get("rival", {}).get("signature_id", &"")]
	for slot_id: StringName in wall:
		var e: Dictionary = wall[slot_id]
		entries[slot_id] = {"card": card_lookup.call(e.get("card_id", &"")), "owner": e.get("owner", &""),
				"face_down": e.get("face_down", false), "signature": e.get("signature", sigs.has(e.get("card_id", &""))),
				"preview": _preview.has(slot_id), "preview_dir": _preview.get(slot_id, Vector2.RIGHT),
				"target": pick_targets.has(slot_id)}
	if _pending_slot != &"" and _picked != &"" and not wall.has(_pending_slot):
		entries[_pending_slot] = {"card": card_lookup.call(_picked), "owner": &"player", "face_down": false,
				"signature": _picked == _state.get("player", {}).get("signature_id", &""), "pending": true,
				"boost": _pending_boost}
	_wall.show_wall(entries)
	_apply_reserved()


func _counter_data(side: Dictionary, side_name: StringName) -> Dictionary:
	var sig: Dictionary = card_lookup.call(side.get("signature_id", &""))
	return {"name": side.get("name", ""), "score": side.get("score", 0), "hand_count": (side.get("hand", []) as Array).size(),
			"signature_name": sig.get("name", ""), "signature_carded_by": side.get("signature_carded_by", &""),
			"tempo_bonus": _tempo_bonus() if _state.get("first_player", &"") == side_name else 0}


## cc06 Tempo: the first player's head start, shown as a tag on their counter (the score already
## includes it). state["first_player_bonus"] if the controller sends it, else the balance data.
func _tempo_bonus() -> int:
	if _state.has("first_player_bonus"):
		return int(_state["first_player_bonus"])
	var db: Node = get_node_or_null(^"/root/CardDB")
	var b: BalanceConfig = db.get_balance() if db != null else null
	return b.first_player_bonus if b != null else 0


func _refresh_buttons() -> void:
	_info.disabled = _picked == &""
	_place.disabled = _picked == &"" or _pending_slot == &"" or (not mock_interactions and not place_ready)


# --- Dossier hooks (cc12) -----------------------------------------------------------
# A DossierController drives this screen the way DuelController does, plus three additions:
# empty slots reserved for a scripted rival reply, extra action buttons, and a goal line.

## Empty slots shown as taken: {slot_id: caption}. The slot keeps reporting taps (slot_chosen),
## so the controller can say why it is reserved.
var reserved_slots: Dictionary = {}
var _goal_label: Label = null


func set_reserved_slots(slots: Dictionary) -> void:
	reserved_slots = slots.duplicate()
	_apply_reserved()


func _apply_reserved() -> void:
	if not is_node_ready():
		return
	for s: Node in _wall.get_slots():
		var label: Label = s.get_node_or_null("%SlotIdLabel")
		if label == null:
			continue
		var id: String = String(s.slot_id).to_upper()
		if reserved_slots.has(s.slot_id) and s.is_empty():
			label.text = "%s · %s" % [id, reserved_slots[s.slot_id]]
			label.add_theme_color_override(&"font_color", ArtKit.RIVAL)
			s.set_meta(&"reserved", true)
		elif s.has_meta(&"reserved"):
			label.text = id
			label.remove_theme_color_override(&"font_color")
			s.remove_meta(&"reserved")


## The button column left of the hand (INFO) or right of it (PLACE), for extra buttons.
func get_action_column(right: bool) -> VBoxContainer:
	return (_place if right else _info).get_parent() as VBoxContainer


## A goal line under the hand cards ("" hides it).
func set_goal_text(text: String) -> void:
	if _goal_label == null:
		_goal_label = Label.new()
		_goal_label.name = "GoalLabel"
		_goal_label.theme_type_variation = &"InspectorHeading"
		_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_goal_label.clip_text = true
		_goal_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_hand.add_child(_goal_label)
	_goal_label.text = text
	_goal_label.visible = text != ""


func get_goal_label() -> Label:
	return _goal_label


# --- Layout --------------------------------------------------------------------

func _relayout() -> void:
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
	_safe_area.add_theme_constant_override(&"margin_left", int(margin_lt.x))
	_safe_area.add_theme_constant_override(&"margin_top", int(margin_lt.y))
	_safe_area.add_theme_constant_override(&"margin_right", int(margin_rb.x))
	_safe_area.add_theme_constant_override(&"margin_bottom", int(margin_rb.y))
	_inspector.set_safe_margins(margin_lt, margin_rb)
	%DuelOverlay.set_safe_margins(margin_lt, margin_rb)
	_inspector.compact = compact

	var sep: int = 8 if compact else 12
	_column.add_theme_constant_override(&"separation", sep)
	_turn_panel.custom_minimum_size.x = 196 if compact else 240
	_info.custom_minimum_size = Vector2(96 if compact else 120, 64)
	_place.custom_minimum_size = Vector2(120 if compact else 150, 64)

	var inner_w: float = logical.x - int(margin_lt.x) - int(margin_rb.x)
	# Wall panel padding from the theme (placeholder or cc14), both sides together.
	var chrome: Vector2 = _wall.get_theme_stylebox(&"panel").get_minimum_size()
	var brick: Vector2 = brick_size_for(inner_w - chrome.x)
	_wall.set_brick_size(brick, WALL_GAP)

	# Hand: rows for a full lineup (5) so the wall does not jump as the hand empties.
	var hand_w: float = inner_w - _info.custom_minimum_size.x - _place.custom_minimum_size.x - 2.0 * sep
	_hand.card_size = brick
	var rows: int = _hand.rows_for(hand_w, MockDuelData.PLAYER_LINEUP.size())
	var fixed_h: float = int(margin_lt.y) + int(margin_rb.y) + 64.0 + 2.0 * sep + brick.y * 3.0 + WALL_GAP.y * 2.0 + chrome.y
	var room: float = logical.y - fixed_h
	hand_strip = hand_height(brick.y, rows) + 4.0 > room
	# +4: slack for half-pixel centering so the last row never pokes out of the hand.
	var hand_h: float = hand_height(brick.y, 1 if hand_strip else rows) + 4.0
	if hand_strip:
		hand_h += 12.0  # scrollbar
	_hand.custom_minimum_size.y = hand_h
	_hand.set_layout(brick, hand_strip, compact)
	_render()


## Height of the hand block (header + rows of cards).
static func hand_height(card_h: float, rows: int) -> float:
	return HAND_HEADER_H + rows * card_h + maxf(rows - 1, 0) * 10.0


## Controls that must be on screen, inside the safe area and not overlap (tests).
func get_key_controls() -> Dictionary:
	return {"MenuButton": _menu, "PlayerCounter": _player_counter, "TurnPanel": _turn_panel,
			"RivalCounter": _rival_counter, "Wall": _wall, "Hand": _hand, "InfoButton": _info, "PlaceButton": _place}


func get_wall() -> PanelContainer:
	return _wall


func get_hand() -> VBoxContainer:
	return _hand


func get_inspector() -> Control:
	return _inspector


func get_counters() -> Array[Control]:
	return [_player_counter, _rival_counter]


## Labels whose whole text must show (tests).
func get_important_labels() -> Array[Label]:
	var out: Array[Label] = [_turn_title, _turn_sub]
	out.append_array(_player_counter.get_important_labels())
	out.append_array(_rival_counter.get_important_labels())
	return out


# --- Inspector -----------------------------------------------------------------

func inspect_card(card_id: StringName, context: Dictionary = {}) -> void:
	var c: Dictionary = card_lookup.call(card_id)
	if c.is_empty():
		return
	var ctx: Dictionary = context.duplicate()
	var sigs: Array = [_state.get("player", {}).get("signature_id", &""), _state.get("rival", {}).get("signature_id", &"")]
	ctx["signature"] = sigs.has(card_id)
	_inspector.open_card(c, ctx)
	var lineup: Array = _state.get("player", {}).get("lineup", [])
	EventBus.card_inspected.emit(card_id, lineup.has(card_id))


func inspect_slot(slot_id: StringName) -> void:
	var e: Dictionary = _state.get("wall", {}).get(slot_id, {})
	if e.is_empty():
		return
	inspect_card(e.get("card_id", &""), {"owner": e.get("owner", &""), "face_down": e.get("face_down", false), "where": "wall"})


# --- Input ---------------------------------------------------------------------

func _on_hand_picked(card_id: StringName) -> void:
	_picked = card_id
	_pending_slot = &""
	card_picked.emit(card_id)
	if mock_interactions:
		var empty: Array = []
		for id: StringName in MockDuelData.SLOTS:
			if not _state.get("wall", {}).has(id):
				empty.append(id)
		set_valid_slots(empty)
	_render_wall()
	_refresh_buttons()


func _on_hand_unpicked() -> void:
	_picked = &""
	_pending_slot = &""
	set_valid_slots([])
	_render_wall()
	_refresh_buttons()


func _on_slot_tapped(slot_id: StringName) -> void:
	if pick_targets.has(slot_id):
		target_tapped.emit(slot_id)
		return
	var occupied: bool = _state.get("wall", {}).has(slot_id)
	if occupied:
		inspect_slot(slot_id)
		return
	if _picked == &"" and mock_interactions:
		return
	# With a controller every empty-slot tap is reported (it explains "pick a card first").
	slot_chosen.emit(slot_id)
	if mock_interactions:
		set_pending(slot_id)


func _on_place() -> void:
	if _picked == &"" or _pending_slot == &"" or (not mock_interactions and not place_ready):
		return
	var card_id: StringName = _picked
	var slot_id: StringName = _pending_slot
	place_confirmed.emit(card_id, slot_id)
	if mock_interactions:
		_picked = &""
		_pending_slot = &""
		set_valid_slots([])
		_hand.picked_id = &""
		EventBus.card_placed.emit(&"player", card_id, slot_id, [])
		var next: int = int(_state.get("turn_index", 1)) + 1
		EventBus.turn_started.emit(&"rival", next)


func _on_info() -> void:
	if _picked != &"":
		inspect_card(_picked, {"owner": &"player", "where": "hand"})


func _on_menu() -> void:
	menu_requested.emit()
	if mock_interactions:
		SceneRouter.goto_scene(SceneRouter.SCENE_TITLE)


# --- EventBus ------------------------------------------------------------------

func _on_duel_started(_source: StringName, _rival_id: StringName, first_player: StringName) -> void:
	_state["first_player"] = first_player
	_state["turn_side"] = first_player
	_state["turn_index"] = 1
	_render()


func _on_turn_started(side: StringName, turn_index: int) -> void:
	_state["turn_side"] = side
	_state["turn_index"] = turn_index
	_render()


func _on_card_placed(side: StringName, card_id: StringName, slot: StringName, _captures: Array) -> void:
	if not _state.has("wall"):
		return
	var c: Dictionary = card_lookup.call(card_id)
	_state["wall"][slot] = {"card_id": card_id, "owner": side, "face_down": c.get("trait", &"") == &"ambush"}
	var hand: Array = _state.get(String(side), {}).get("hand", [])
	hand.erase(card_id)
	_render()


func _on_card_captured(by_side: StringName, _card_id: StringName, slot: StringName) -> void:
	if _state.get("wall", {}).has(slot):
		_state["wall"][slot]["owner"] = by_side
		_render_wall()


func _on_ambush_sprung(_side: StringName, _card_id: StringName, slot: StringName) -> void:
	if _state.get("wall", {}).has(slot):
		_state["wall"][slot]["face_down"] = false
		_render_wall()


func _on_carded(by_side: StringName, card_id: StringName) -> void:
	for side: String in ["player", "rival"]:
		if _state.get(side, {}).get("signature_id", &"") == card_id:
			_state[side]["signature_carded_by"] = by_side
	_render()


func _on_score_changed(player_score: int, rival_score: int) -> void:
	if not _state.has("player"):
		return
	_state["player"]["score"] = player_score
	_state["rival"]["score"] = rival_score
	_render()

# duel_controller.gd
# Purpose: Runs one Banner Wall duel on the real rules (cc05) behind the cc07 duel screen (cc08).
#   Flow:  SETUP (pick a rival + your Signature) -> COIN (coin flip shown, BEGIN)
#          -> turns: PLAYER (tap card -> tap slot [-> tap the card a Cipher copies] -> preview -> PLACE)
#                    RIVAL  (rival brain picks a legal move after a short pause)
#          -> OVER (end screen: result, score, Signatures, Triptychs, cosmetic rewards line).
#   Every placement goes through WallRules: check_place rejects illegal moves (shown as a toast
#   in words), preview() drives the amber arrows on the cards that would flip, place() resolves,
#   and PlacementResult.events are replayed onto EventBus in order, paced by event_delay so
#   game feel (cc15) can hang animations on them. After each step the screen re-syncs from
#   WallState, so the view always ends on the engine's truth.
#   Player = WallState.P1, rival = WallState.P2. Scores shown during play are the PUBLIC score
#   (a face-down card counts 1, no Triptychs); the end screen uses the full score.
# Hooks: autostart (tests of the bare layout turn it off), next_rival_id / next_player_lineup
#   (hub cc13 / lineup builder cc10 set them before routing here), brain_factory (cc06 AI:
#   func(rival: RivalData, seed: int) -> object with choose_move(state, player) -> Dictionary).
# Dependencies: WallRules, WallState, PlacementResult, EventBus, Settings, SceneRouter,
#   duel_setup.gd, random_rival.gd, DuelScreen (parent), DuelOverlay, BannerCard.
# Author: UI/UX Agent (cc08)
extends Node

signal phase_changed(phase: StringName)
signal duel_finished(result: Dictionary)

const DuelSetup: GDScript = preload("res://scripts/duel/duel_setup.gd")
const RandomRival: GDScript = preload("res://scripts/duel/random_rival.gd")
const TapHoldButton: GDScript = preload("res://scripts/ui/tap_hold_button.gd")
const BannerCardScene: PackedScene = preload("res://scenes/card/BannerCard.tscn")

const P1: int = WallState.P1
const P2: int = WallState.P2
const DIFFICULTY_NAMES: Array[String] = ["Easy", "Normal", "Hard"]

## Off: the screen stays on its cc07 mock data (layout tests).
static var autostart: bool = true
## Set by the hub before routing to the duel (&"" = first rival / last choice).
static var next_rival_id: StringName = &""
## Set by the lineup builder (CardData or ids); empty = loaner lineup.
static var next_player_lineup: Array = []
## cc06: func(rival: RivalData, seed: int) -> brain with choose_move(state, player). Null = random.
static var brain_factory: Callable = Callable()

## Static setters (a const script reference can't assign static vars directly).
static func set_autostart(v: bool) -> void:
	autostart = v


static func set_next_duel(rival_id: StringName, lineup: Array = []) -> void:
	next_rival_id = rival_id
	next_player_lineup = lineup.duplicate()


## 0 = random seed per duel. Same seed = same coin flip and rival moves.
@export var seed_value: int = 0
## Pause between replayed events and before a rival move (seconds). Tests set 0.
@export var event_delay: float = 0.22
@export var rival_delay: float = 0.7
@export var source: StringName = &"rival"

var phase: StringName = &"idle"
var state: WallState = null
var rivals: Array[Dictionary] = []
var rival: Dictionary = {}
var player_lineup: Array[CardData] = []
var player_signature: CardData = null
var last_result: Dictionary = {}
var brain: Object = null

var _screen: Control = null
var _overlay: Control = null
var _card: CardData = null
var _slot: StringName = &""
var _copy_from: StringName = &""
var _cipher_picks: Array[StringName] = []
var _started_ms: int = 0
var _seed: int = 0


func _ready() -> void:
	if not autostart:
		return
	_screen = get_parent()
	_screen.mock_interactions = false
	_screen.card_lookup = ui_card
	_screen.card_picked.connect(_on_card_picked)
	_screen.slot_chosen.connect(_on_slot_chosen)
	_screen.target_tapped.connect(_on_target_tapped)
	_screen.place_confirmed.connect(_on_place_confirmed)
	_screen.menu_requested.connect(_on_menu)
	_overlay = _screen.get_node("%DuelOverlay")
	_overlay.button_pressed.connect(_on_overlay_button)
	open_setup.call_deferred()


func _exit_tree() -> void:
	phase = &"gone"


# --- Setup and coin flip -----------------------------------------------------------

func open_setup() -> void:
	if _screen == null:
		return
	if not _screen.get_hand().card_unpicked.is_connected(_clear_selection):
		_screen.get_hand().card_unpicked.connect(_clear_selection)
	rivals = DuelSetup.rivals()
	if rival.is_empty():
		rival = rivals[0]
		for r: Dictionary in rivals:
			if r["id"] == next_rival_id:
				rival = r
	if player_lineup.is_empty():
		var p: Dictionary = DuelSetup.player_lineup(next_player_lineup)
		player_lineup.assign(p["lineup"])
		player_signature = p["signature"]
	state = null
	_set_phase(&"setup")
	_screen.clear_pick()
	_screen.show_state(_preview_ui())
	_overlay.open(&"setup", "CHOOSE YOUR DUEL", "", [
		{"id": &"menu", "text": "MENU"}, {"id": &"start", "text": "START DUEL", "primary": true}])
	_fill_setup()


func select_rival(rival_id: StringName) -> void:
	for r: Dictionary in rivals:
		if r["id"] == rival_id:
			rival = r
	_screen.show_state(_preview_ui())
	_fill_setup()


func select_signature(card: CardData) -> bool:
	if card == null or not player_lineup.has(card) or not card.signature_eligible:
		_screen.show_toast("%s can't be your Signature." % (card.display_name if card != null else "That card"))
		return false
	player_signature = card
	_screen.show_state(_preview_ui())
	_fill_setup()
	return true


## Starts the duel with the chosen rival and Signature; shows the coin flip.
func start_duel() -> void:
	_seed = seed_value if seed_value != 0 else randi()
	var first: int = WallState.coin_flip(_seed)
	var rl: Array[CardData] = []
	rl.assign(rival["lineup"])
	state = WallState.new_match(player_lineup, player_signature, rl, rival["signature"], first,
			DuelSetup.balance(), null, DuelSetup.triptychs())
	if brain_factory.is_valid():
		brain = brain_factory.call(rival.get("data"), _seed)
	if brain == null:
		brain = RandomRival.new(_seed)
	_started_ms = Time.get_ticks_msec()
	_set_phase(&"coin")
	_screen.show_state(ui_state())
	var you_first: bool = first == P1
	_overlay.open(&"coin", "COIN FLIP: %s" % ("HEADS" if you_first else "TAILS"),
			("You place first." if you_first else "%s places first." % rival["name"])
			+ " A tied score goes to the first player; the second player gets the last placement.",
			[{"id": &"begin", "text": "BEGIN", "primary": true}])


func begin() -> void:
	_overlay.close()
	EventBus.duel_started.emit(source, rival["id"], _side(state.first_player))
	EventBus.turn_started.emit(_side(state.to_move), 1)
	_next_turn()


# --- Turns ---------------------------------------------------------------------------

func _next_turn() -> void:
	if phase == &"gone":
		return
	_screen.show_state(ui_state())
	if state.is_game_over():
		_end()
	elif state.to_move == P1:
		_set_phase(&"player")
	else:
		_set_phase(&"rival")
		if rival_delay > 0.0:
			await get_tree().create_timer(_paced(rival_delay)).timeout
			if phase != &"rival":
				return
		_rival_move()


func _rival_move() -> void:
	var mv: Dictionary = brain.choose_move(state.copy(), P2) if brain != null else {}
	var r: PlacementResult = null
	if not mv.is_empty():
		r = WallRules.place(state, P2, mv["card"], mv["slot"], mv.get("copy_from", &""))
	if r == null or not r.ok:
		push_warning("DuelController: rival move rejected (%s); playing a random legal move" % (r.error if r != null else "none"))
		var moves: Array[Dictionary] = WallRules.legal_moves(state)
		var m: Dictionary = moves[0]
		r = WallRules.place(state, P2, m["card"], m["slot"], m["copy_from"])
	await _replay(r)
	_next_turn()


func _on_card_picked(card_id: StringName) -> void:
	if phase != &"player":
		_screen.clear_pick()
		_screen.show_toast(_wait_text())
		return
	_card = _hand_card(card_id)
	_slot = &""
	_copy_from = &""
	_cipher_picks.clear()
	_screen.pick_targets = []
	_screen.set_preview({})
	_screen.place_ready = false
	var valid: Array = []
	for s: StringName in state.empty_slots():
		var err: StringName = WallRules.check_place(state, P1, _card, s)
		if err == &"" or err == WallRules.ERR_CIPHER_PICK_REQUIRED:
			valid.append(s)
	_screen.set_valid_slots(valid)


func _clear_selection() -> void:
	_card = null
	_slot = &""
	_copy_from = &""
	_cipher_picks.clear()
	if _screen != null:
		_screen.pick_targets = []
		_screen.set_preview({})
		_screen.place_ready = false


## Tap on an empty slot.
func _on_slot_chosen(slot: StringName) -> void:
	if phase != &"player":
		_screen.show_toast(_wait_text())
		return
	if _card == null:
		_screen.show_toast("Pick a card from your hand first.")
		return
	var err: StringName = WallRules.check_place(state, P1, _card, slot)
	if err == WallRules.ERR_CIPHER_PICK_REQUIRED:
		_slot = slot
		_copy_from = &""
		_cipher_picks = WallRules.cipher_picks(state, slot)
		_screen.pick_targets = _cipher_picks.duplicate()
		_screen.place_ready = false
		_screen.set_preview({})
		_screen.set_pending(slot)
		_screen.show_toast("Cipher: tap the card whose trait %s copies." % _card.display_name, 3.0)
		return
	if err != &"":
		_screen.show_toast(error_text(err))
		return
	_slot = slot
	_copy_from = &""
	_cipher_picks.clear()
	_screen.pick_targets = []
	_show_preview()


## Tap on a highlighted card while a Cipher pick is open.
func _on_target_tapped(slot: StringName) -> void:
	if phase != &"player" or _card == null or _slot == &"":
		return
	var err: StringName = WallRules.check_place(state, P1, _card, _slot, slot)
	if err != &"":
		_screen.show_toast(error_text(err))
		return
	_copy_from = slot
	_screen.pick_targets = []
	var t: String = String(DataEnums.key_of(DataEnums.CardTrait, WallRules.copied_trait(state, slot))).capitalize()
	_screen.show_toast("%s copies %s." % [_card.display_name, "no trait" if t == "None" else t])
	_show_preview()


## Preview arrows on every card the placement would flip, then PLACE is enabled.
func _show_preview() -> PlacementResult:
	var r: PlacementResult = WallRules.preview(state, P1, _card, _slot, _copy_from)
	if not r.ok:
		_screen.show_toast(error_text(r.error))
		_screen.place_ready = false
		return r
	var flips: Dictionary = {}
	var from: Vector2 = _screen.slot_center(_slot)
	for s: StringName in r.all_flipped():
		flips[s] = (_screen.slot_center(s) - from).normalized()
	var ev: Dictionary = r.effective_values
	var boost: Vector3i = Vector3i(int(ev.get(&"top", _card.top)) - _card.top, int(ev.get(&"side", _card.side)) - _card.side,
			int(ev.get(&"bottom", _card.bottom)) - _card.bottom)
	_screen.place_ready = true
	_screen.set_pending(_slot)
	_screen.set_preview(flips, boost)
	_screen.show_toast(preview_text(r), 2.6)
	return r


func _on_place_confirmed(card_id: StringName, slot: StringName) -> void:
	if phase != &"player" or _card == null or _card.id != card_id or slot != _slot:
		return
	var r: PlacementResult = WallRules.place(state, P1, _card, _slot, _copy_from)
	if not r.ok:
		_screen.show_toast(error_text(r.error))
		return
	_set_phase(&"resolving")
	_screen.clear_pick()
	_clear_selection()
	await _replay(r)
	_next_turn()


# --- Event replay ------------------------------------------------------------------------

## Replays one placement's events onto EventBus, in order, paced by event_delay.
func _replay(r: PlacementResult) -> void:
	for e: Dictionary in r.events:
		if phase == &"gone":
			return
		var side: StringName = _side(int(e.get("player", -1)))
		match e["type"]:
			&"placed":
				EventBus.card_placed.emit(side, e["card_id"], e["slot"], r.captured.duplicate())
			&"captured":
				EventBus.card_captured.emit(side, e["card_id"], e["slot"])
			&"reclaimed":
				_screen.set_slot_owner(e["slot"], side)
			&"spring":
				EventBus.ambush_sprung.emit(side, e["card_id"], e["slot"])
			&"carded":
				EventBus.carded.emit(side, e["card_id"])
			&"turn_started":
				EventBus.turn_started.emit(side, state.placements + 1)
			&"cipher_copied":
				pass
			_:
				pass
		if event_delay > 0.0 and e["type"] in [&"placed", &"captured", &"reclaimed", &"spring", &"carded"]:
			await get_tree().create_timer(_paced(event_delay)).timeout
	var pub: Array[int] = [WallRules.score(state, P1, state.is_game_over()), WallRules.score(state, P2, state.is_game_over())]
	EventBus.score_changed.emit(pub[0], pub[1])


# --- End -----------------------------------------------------------------------------------

func _end() -> void:
	_set_phase(&"over")
	last_result = WallRules.final_result(state)
	var s: Array = last_result["score"]
	var winner: int = last_result["winner"]
	var word: StringName = &"draw" if winner == WallState.NO_PLAYER else (&"win" if winner == P1 else &"loss")
	var duration: float = (Time.get_ticks_msec() - _started_ms) / 1000.0
	for side: int in [P1, P2]:
		for tid: StringName in (last_result["triptychs"] as Array)[side]:
			EventBus.triptych_scored.emit(_side(side), tid, true)
	EventBus.duel_ended.emit(word, s[0], s[1], state.placements, duration)
	_screen.show_state(ui_state())
	var title: String = {&"win": "YOU WIN", &"loss": "%s WINS" % String(rival["name"]).to_upper(), &"draw": "DRAW"}[word]
	_overlay.open(&"end", title, "", [{"id": &"menu", "text": "MENU"}, {"id": &"again", "text": "PLAY AGAIN", "primary": true}])
	_fill_end(word)
	duel_finished.emit(last_result)


func _fill_end(word: StringName) -> void:
	var box: VBoxContainer = _overlay.get_content()
	var s: Array = last_result["score"]
	var score: Label = _label("%d  –  %d" % [s[0], s[1]], &"InspectorValue", HORIZONTAL_ALIGNMENT_CENTER)
	score.name = "EndScore"
	box.add_child(score)
	box.add_child(_label("You  ·  %s" % rival["name"], &"Caption", HORIZONTAL_ALIGNMENT_CENTER))
	if last_result["tie"]:
		box.add_child(_label("Tied score: the first player (%s) takes it." % ("you" if state.first_player == P1 else rival["name"]),
				&"InspectorBody", HORIZONTAL_ALIGNMENT_CENTER))
	var ui: Dictionary = ui_state()
	box.add_child(_label("Signatures (count double): yours %s · theirs %s" % [
			_sig_word(ui["player"]["signature_carded_by"]), _sig_word(ui["rival"]["signature_carded_by"])],
			&"InspectorBody", HORIZONTAL_ALIGNMENT_CENTER))
	var trips: Array = []
	for side: int in [P1, P2]:
		for tid: StringName in (last_result["triptychs"] as Array)[side]:
			trips.append("%s (+%d, %s)" % [_triptych_name(tid), state.balance.triptych_bonus, "you" if side == P1 else rival["name"]])
	var tl: Label = _label("Triptychs: %s" % (", ".join(trips) if not trips.is_empty() else "none scored"), &"InspectorBody", HORIZONTAL_ALIGNMENT_CENTER)
	tl.name = "EndTriptychs"
	box.add_child(tl)
	var rewards: Label = _label("Rewards (cosmetic only): titles, frames and unlock progress arrive with the Collection.",
			&"Caption", HORIZONTAL_ALIGNMENT_CENTER)
	rewards.name = "EndRewards"
	rewards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rewards.custom_minimum_size.x = 560
	box.add_child(rewards)


# --- Overlay buttons and menu -------------------------------------------------------------

func _on_overlay_button(id: StringName) -> void:
	match id:
		&"start":
			start_duel()
		&"begin":
			begin()
		&"again":
			_overlay.close()
			open_setup()  # same rival and Signature preselected
		&"menu", &"leave":
			_overlay.close()
			phase = &"gone"
			SceneRouter.goto_scene(SceneRouter.SCENE_TITLE)
		&"stay":
			_overlay.close()
			_set_phase(_resume_phase)


var _resume_phase: StringName = &""


func _on_menu() -> void:
	if phase in [&"setup", &"over", &"coin"]:
		_on_overlay_button(&"menu")
		return
	_resume_phase = phase if phase != &"resolving" else &"player"
	_overlay.open(&"leave", "LEAVE THIS DUEL?", "The duel is not saved.", [
		{"id": &"leave", "text": "LEAVE"}, {"id": &"stay", "text": "KEEP PLAYING", "primary": true}])


# --- Setup panel ---------------------------------------------------------------------------

func _fill_setup() -> void:
	var box: VBoxContainer = _overlay.get_content()
	for c: Node in box.get_children():
		c.name = "%s_old" % c.name
		(c as CanvasItem).hide()
		c.queue_free()
	box.add_child(_label("RIVAL", &"InspectorHeading"))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for r: Dictionary in rivals:
		var b: Button = Button.new()
		b.name = "Rival_%s" % r["id"]
		b.text = "%s · %s" % [String(r["name"]).to_upper(), DIFFICULTY_NAMES[clampi(int(r["difficulty"]), 0, 2)]]
		b.custom_minimum_size = Vector2(0, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.theme_type_variation = &"PrimaryButton" if r["id"] == rival["id"] else &"ActionButton"
		var id: StringName = r["id"]
		b.pressed.connect(func() -> void: select_rival(id))
		row.add_child(b)
	box.add_child(row)
	box.add_child(_label("YOUR SIGNATURE counts double. Tap a card to choose it, hold for details. Rival's: %s" %
			(rival["signature"] as CardData).display_name, &"InspectorHeading"))
	var flow: HFlowContainer = HFlowContainer.new()
	flow.name = "LineupCards"
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override(&"h_separation", 10)
	flow.add_theme_constant_override(&"v_separation", 10)
	var size_px: Vector2 = _screen.get_hand().card_size
	flow.custom_minimum_size.x = size_px.x * 3 + 20
	for c: CardData in player_lineup:
		var b: Button = TapHoldButton.new()
		b.name = "Lineup_%s" % c.id
		b.custom_minimum_size = size_px
		b.theme_type_variation = &"HandCard"
		b.add_to_group(&"tap_target")
		var card: BannerCard = BannerCardScene.instantiate()
		card.name = "Card"
		card.custom_minimum_size = Vector2.ZERO
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(card)
		card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.configure(c)
		card.side = &"player"
		card.signature = c == player_signature
		card.highlighted = c == player_signature
		b.tapped.connect(func() -> void: select_signature(c))
		b.inspect_requested.connect(func() -> void: _screen.inspect_card(c.id, {"owner": &"player", "where": "hand"}))
		flow.add_child(b)
	box.add_child(flow)


# --- UI state ---------------------------------------------------------------------------------

## The screen's state Dictionary (mock_duel_data.gd shape) from the WallState.
func ui_state() -> Dictionary:
	if state == null:
		return _preview_ui()
	var over: bool = state.is_game_over()
	var wall: Dictionary = {}
	for slot: StringName in state.cells:
		var pc: PlacedCard = state.cells[slot]
		wall[slot] = {"card_id": pc.card.id, "owner": _side(pc.controller), "face_down": pc.face_down, "signature": pc.signature}
	return {
		"first_player": _side(state.first_player), "turn_side": _side(state.to_move),
		"turn_index": state.placements + 1, "turns_total": state.topology.slot_count(),
		"rival_name": rival["name"],
		"player": _side_ui(P1, "You", over), "rival": _side_ui(P2, rival["name"], over), "wall": wall,
	}


func _side_ui(p: int, display: String, over: bool) -> Dictionary:
	var sig: CardData = state.signature_cards[p]
	var carded_by: StringName = &""
	for slot: StringName in state.cells:
		var pc: PlacedCard = state.cells[slot]
		if pc.signature and pc.lineup == p and pc.controller != p:
			carded_by = _side(pc.controller)
	var hand: Array = []
	for c: CardData in state.hands[p]:
		hand.append(c.id)
	var lineup: Array = (player_lineup if p == P1 else rival["lineup"] as Array).map(func(c: CardData) -> StringName: return c.id)
	return {"name": display, "score": WallRules.score(state, p, over), "signature_id": sig.id if sig != null else &"",
			"signature_carded_by": carded_by, "hand": hand, "lineup": lineup}


func _preview_ui() -> Dictionary:
	var ids: Array = player_lineup.map(func(c: CardData) -> StringName: return c.id)
	var rids: Array = (rival.get("lineup", []) as Array).map(func(c: CardData) -> StringName: return c.id)
	return {
		"first_player": &"player", "turn_side": &"player", "turn_index": 1, "turns_total": 10,
		"rival_name": rival.get("name", "Rival"),
		"player": {"name": "You", "score": 0, "signature_id": player_signature.id if player_signature != null else &"",
				"signature_carded_by": &"", "hand": ids, "lineup": ids},
		"rival": {"name": rival.get("name", "Rival"), "score": 0,
				"signature_id": (rival["signature"] as CardData).id if rival.has("signature") else &"",
				"signature_carded_by": &"", "hand": rids, "lineup": rids},
		"wall": {},
	}


## UI card Dictionary for an id (CardDB, mock fallback).
func ui_card(card_id: StringName) -> Dictionary:
	var c: CardData = DuelSetup.get_card(card_id)
	return c.to_ui_dict() if c != null else {}


# --- Words ------------------------------------------------------------------------------------

static func error_text(code: StringName) -> String:
	match code:
		WallRules.ERR_GAME_OVER:
			return "The wall is full: the duel is over."
		WallRules.ERR_NOT_YOUR_TURN:
			return "Not your turn yet."
		WallRules.ERR_INVALID_SLOT:
			return "That isn't a slot on the wall."
		WallRules.ERR_SLOT_OCCUPIED:
			return "That slot is taken. Pick an empty brick."
		WallRules.ERR_NOT_IN_HAND:
			return "That card isn't in your hand."
		WallRules.ERR_NO_CARD:
			return "Pick a card from your hand first."
		WallRules.ERR_CIPHER_PICK_REQUIRED:
			return "Cipher: tap the card whose trait it copies."
		WallRules.ERR_INVALID_CIPHER_PICK:
			return "A Cipher can only copy a card next to it."
	return "That move isn't allowed (%s)." % code


func preview_text(r: PlacementResult) -> String:
	if r.face_down:
		return "Face-down Ambush: flips at the start of your next turn."
	var parts: Array[String] = []
	var n: int = r.captured.size()
	parts.append("Captures %d" % n if n > 0 else "No captures here")
	if not r.reclaimed.is_empty():
		parts.append("takes back %d" % r.reclaimed.size())
	if r.set_link:
		parts.append("Set Link +%d" % state.balance.set_link_bonus)
	if r.clutch:
		parts.append("Clutch +%d" % state.balance.clutch_bonus)
	if not r.carded.is_empty():
		parts.append("CARDED!")
	if not r.steady_blocked.is_empty():
		parts.append("Steady holds %d" % r.steady_blocked.size())
	return " · ".join(parts)


func _wait_text() -> String:
	match phase:
		&"rival", &"resolving":
			return "%s is playing. You can still hold a card to inspect it." % rival.get("name", "The rival")
		&"over":
			return "The duel is over."
	return "Not your turn yet."


func _sig_word(carded_by: StringName) -> String:
	if carded_by == &"":
		return "held"
	return "CARDED by %s" % ("you" if carded_by == &"player" else rival["name"])


func _triptych_name(id: StringName) -> String:
	for t: TriptychData in state.triptychs:
		if t.id == id:
			return t.display_name
	return String(id).capitalize()


# --- Helpers ---------------------------------------------------------------------------------

func _hand_card(card_id: StringName) -> CardData:
	for c: CardData in state.hands[P1]:
		if c.id == card_id:
			return c
	return null


func _side(p: int) -> StringName:
	return &"player" if p == P1 else (&"rival" if p == P2 else &"")


func _paced(seconds: float) -> float:
	var s: Node = get_node_or_null("/root/Settings")
	return seconds * (0.4 if s != null and s.fast_animations else 1.0)


func _set_phase(p: StringName) -> void:
	phase = p
	phase_changed.emit(p)


func _label(text: String, variation: StringName, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	return l

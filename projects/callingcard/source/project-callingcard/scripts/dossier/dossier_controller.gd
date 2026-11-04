# dossier_controller.gd
# Purpose: Runs the five Dossier puzzles (spec §5.2, plan cc12) on the cc07/cc08 duel screen.
#   scenes/Dossier.tscn inherits scenes/Duel.tscn and swaps the DuelController node's script for
#   this one, so the wall, hand, preview arrows, Cipher pick, inspector and overlay are the duel's.
#   Flow:  LIST (pick a Dossier) -> BRIEFING (rules + goal + reward, START)
#          -> PLAYER (tap card -> tap slot [-> tap the card a Cipher copies] -> preview -> PLACE)
#          -> RIVAL (a scripted reply, through WallRules.place, after a short pause) -> PLAYER ...
#          -> RESULT (goal check: CLEARED / NOT YET, reason, score, reward; RETRY / NEXT / DOSSIERS).
#   During play: the goal and live progress sit under the hand; slots held for a scripted rival
#   reply show "RESERVED" in rival red and refuse placements; HINT shows the text hint, a second
#   tap picks the card of the next solution step and lights its slot; RETRY resets the start board.
#   On a clear the reward is paid through DossierRewards (Collection.complete_dossier), once per
#   visit; Collection itself grants on the first clear only.
#   EventBus: dossier_started (once per visit), duel_started(&"dossier", id, &"player") per attempt
#   (Collection skips duel stats for that source), the placement events, duel_ended per attempt.
# Hooks: autostart (tests), next_dossier_id (hub cc13 sets it before routing to Dossier.tscn;
#   &"" opens the list), collection (tests inject their own Collection instance).
# Dependencies: DossierPuzzle, DossierRewards, DossierData, WallRules, WallState, PlacementResult,
#   CardDB, EventBus, SceneRouter, Settings, DuelScreen (parent, cc12 hooks), DuelOverlay,
#   duel_controller.gd (error words only).
# Author: Mechanics Developer Agent (cc12)
extends Node

signal phase_changed(phase: StringName)
signal dossier_finished(dossier_id: StringName, result: Dictionary)

const DuelControllerScript: GDScript = preload("res://scripts/duel/duel_controller.gd")
const DOSSIER_DIR: String = "res://data/dossiers"
const P1: int = WallState.P1
const P2: int = WallState.P2
const RIVAL_NAME: String = "Rival"

## Off: nothing starts (tests that build the screen themselves).
static var autostart: bool = true
## Set by the hub before routing here (&"" = open the Dossier list).
static var next_dossier_id: StringName = &""


static func set_autostart(v: bool) -> void:
	autostart = v


static func set_next_dossier(dossier_id: StringName) -> void:
	next_dossier_id = dossier_id


@export var event_delay: float = 0.22
@export var rival_delay: float = 0.7
## Seconds the text hint stays in the hand header.
@export var hint_seconds: float = 6.0

## Collection node that receives the payout (null = the Collection autoload).
var collection: Node = null
var phase: StringName = &"idle"
var dossiers: Array[DossierData] = []
var dossier: DossierData = null
var puzzle: DossierPuzzle = null
## Attempts this visit (START and each RETRY count one).
var attempts: int = 0
## 0 = no hint used, 1 = text shown, 2 = first move shown.
var hint_level: int = 0
var last_result: Dictionary = {}
## Paid this visit (a replayed clear never pays twice).
var paid: bool = false
## How the last payout went: DossierRewards.VIA_COLLECTION / VIA_EVENT_BUS, or &"".
var paid_via: StringName = &""

var _screen: Control = null
var _overlay: Control = null
var _hint_button: Button = null
var _retry_button: Button = null
var _card: CardData = null
var _slot: StringName = &""
var _copy_from: StringName = &""
var _started_ms: int = 0
var _resume_phase: StringName = &""


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
	dossiers = load_dossiers()
	# The screen's @onready nodes (hand, action columns) exist once its own _ready has run.
	_open_first.call_deferred()


func _exit_tree() -> void:
	phase = &"gone"


func _open_first() -> void:
	_screen.get_hand().card_unpicked.connect(_clear_selection)
	_add_buttons()
	if next_dossier_id != &"" and find_dossier(next_dossier_id) != null:
		open_briefing(next_dossier_id)
	else:
		open_list()


## All Dossiers in menu order (CardDB when loaded, else the data folder).
static func load_dossiers() -> Array[DossierData]:
	var out: Array[DossierData] = []
	var loop: MainLoop = Engine.get_main_loop()
	var db: Node = (loop as SceneTree).root.get_node_or_null("CardDB") if loop is SceneTree else null
	if db != null and db.has_method(&"all_dossiers"):
		out.assign(db.call(&"all_dossiers"))
	if out.is_empty():
		for f: String in DirAccess.get_files_at(DOSSIER_DIR):
			var path: String = DOSSIER_DIR.path_join(f.trim_suffix(".remap"))
			if path.ends_with(".tres"):
				var d: DossierData = load(path) as DossierData
				if d != null:
					out.append(d)
	out.sort_custom(func(a: DossierData, b: DossierData) -> bool: return a.number < b.number)
	return out


func find_dossier(dossier_id: StringName) -> DossierData:
	for d: DossierData in dossiers:
		if d.id == dossier_id:
			return d
	return null


func _add_buttons() -> void:
	_hint_button = _action_button("HintButton", "HINT")
	_hint_button.pressed.connect(show_hint)
	_screen.get_action_column(false).add_child(_hint_button)
	_retry_button = _action_button("RetryButton", "RETRY")
	_retry_button.pressed.connect(retry)
	var right: VBoxContainer = _screen.get_action_column(true)
	right.add_child(_retry_button)
	right.move_child(_retry_button, 0)
	_refresh_buttons()


func _action_button(node_name: String, text: String) -> Button:
	var b: Button = Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.theme_type_variation = &"ActionButton"
	b.add_to_group(&"tap_target")
	return b


func get_hint_button() -> Button:
	return _hint_button


func get_retry_button() -> Button:
	return _retry_button


# --- List and briefing ------------------------------------------------------------------

func open_list() -> void:
	_set_phase(&"list")
	_screen.set_goal_text("")
	_overlay.open(&"dossier_list", "DOSSIERS", "Five puzzles with a fixed wall and a fixed hand. Each teaches one rule.",
			[{"id": &"menu", "text": "MENU"}])
	var box: VBoxContainer = _overlay.get_content()
	for d: DossierData in dossiers:
		var b: Button = Button.new()
		b.name = "Dossier_%s" % d.id
		var done: bool = _is_cleared(d.id)
		b.text = "D%d · %s · %s%s" % [d.number, d.display_name.to_upper(), d.teaches, "  ✓ CLEARED" if done else ""]
		b.custom_minimum_size = Vector2(560, 64)
		b.theme_type_variation = &"ActionButton"
		var id: StringName = d.id
		b.pressed.connect(func() -> void: open_briefing(id))
		box.add_child(b)


func open_briefing(dossier_id: StringName) -> void:
	var d: DossierData = find_dossier(dossier_id)
	if d == null:
		open_list()
		return
	if dossier != d:
		dossier = d
		attempts = 0
		hint_level = 0
		paid = false
		paid_via = &""
		EventBus.dossier_started.emit(d.id)
	puzzle = DossierPuzzle.new(d, _balance())
	_set_phase(&"briefing")
	_sync()
	_overlay.open(&"briefing", "D%d · %s" % [d.number, d.display_name.to_upper()], d.briefing,
			[{"id": &"list", "text": "DOSSIERS"}, {"id": &"start", "text": "START", "primary": true}])
	var box: VBoxContainer = _overlay.get_content()
	var goal: Label = _label("GOAL: %s" % DossierPuzzle.goal_text(d), &"InspectorHeading", HORIZONTAL_ALIGNMENT_CENTER)
	goal.name = "BriefingGoal"
	box.add_child(goal)
	var rewards: PackedStringArray = DossierRewards.reward_lines(d, collection)
	var rl: Label = _label("Reward: %s" % (" · ".join(rewards) if not rewards.is_empty() else "already earned"),
			&"Caption", HORIZONTAL_ALIGNMENT_CENTER)
	rl.name = "BriefingReward"
	box.add_child(rl)


## START (or RETRY): a fresh attempt on the start board.
func start() -> void:
	if dossier == null:
		return
	_overlay.close()
	puzzle.reset()
	attempts += 1
	last_result = {}
	_started_ms = Time.get_ticks_msec()
	_screen.clear_pick()
	_clear_selection()
	EventBus.duel_started.emit(&"dossier", dossier.id, &"player")
	_set_phase(&"player")
	_sync()
	EventBus.turn_started.emit(&"player", 1)


## RETRY: back to the start board (from play or the result panel).
func retry() -> void:
	if dossier == null or phase in [&"list", &"briefing", &"resolving", &"rival", &"gone"]:
		return
	start()
	_screen.show_toast("Back to the start board.", 2.0)


# --- Hint ---------------------------------------------------------------------------------

## First tap: the Dossier's text hint. Later taps: pick the card of the next solution step and
## light its slot (only while the player's placements still follow the known solution).
func show_hint() -> void:
	if phase != &"player" or puzzle == null:
		return
	hint_level = mini(hint_level + 1, 2)
	if hint_level == 1:
		_screen.show_toast("Hint: %s" % dossier.hint, hint_seconds)
		_refresh_buttons()
		return
	var mv: Dictionary = puzzle.hint_move()
	if mv.is_empty():
		_screen.show_toast("Off the known line. Tap RETRY, then HINT.", hint_seconds)
		return
	var card: CardData = mv["card"]
	_screen.get_hand().pick(card.id)  # -> _on_card_picked
	_screen.set_valid_slots([mv["slot"]])
	var copy: String = ""
	if mv["copy_from"] != &"":
		copy = ", copying %s" % String(mv["copy_from"]).to_upper()
	_screen.show_toast("Move %d: %s into %s%s." % [int(mv["step"]) + 1, card.display_name,
			String(mv["slot"]).to_upper(), copy], hint_seconds)


# --- Player input -------------------------------------------------------------------------

func _on_card_picked(card_id: StringName) -> void:
	if phase != &"player":
		_screen.clear_pick()
		_screen.show_toast(_wait_text())
		return
	_card = _hand_card(card_id)
	_slot = &""
	_copy_from = &""
	_screen.pick_targets = []
	_screen.set_preview({})
	_screen.place_ready = false
	if _card != null:
		_screen.set_valid_slots(puzzle.valid_slots(_card))


func _clear_selection() -> void:
	_card = null
	_slot = &""
	_copy_from = &""
	if _screen != null:
		_screen.pick_targets = []
		_screen.set_preview({})
		_screen.place_ready = false


func _on_slot_chosen(slot: StringName) -> void:
	if phase != &"player":
		_screen.show_toast(_wait_text())
		return
	if puzzle.reserved_slots().has(slot):
		_screen.show_toast(error_text(DossierPuzzle.ERR_RESERVED))
		return
	if _card == null:
		_screen.show_toast("Pick a card from your hand first.")
		return
	var err: StringName = puzzle.check_place(_card, slot)
	if err == WallRules.ERR_CIPHER_PICK_REQUIRED:
		_slot = slot
		_copy_from = &""
		_screen.pick_targets = WallRules.cipher_picks(puzzle.state, slot)
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
	_screen.pick_targets = []
	_show_preview()


func _on_target_tapped(slot: StringName) -> void:
	if phase != &"player" or _card == null or _slot == &"":
		return
	var err: StringName = puzzle.check_place(_card, _slot, slot)
	if err != &"":
		_screen.show_toast(error_text(err))
		return
	_copy_from = slot
	_screen.pick_targets = []
	var t: String = String(DataEnums.key_of(DataEnums.CardTrait, WallRules.copied_trait(puzzle.state, slot))).capitalize()
	_screen.show_toast("%s copies %s." % [_card.display_name, "no trait" if t == "None" else t])
	_show_preview()


func _show_preview() -> PlacementResult:
	var r: PlacementResult = puzzle.preview(_card, _slot, _copy_from)
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
	var r: PlacementResult = puzzle.place_player(_card, _slot, _copy_from)
	if not r.ok:
		_screen.show_toast(error_text(r.error))
		return
	_set_phase(&"resolving")
	_screen.clear_pick()
	_clear_selection()
	await _replay(r)
	if phase == &"gone":
		return
	if puzzle.has_pending_reply():
		_set_phase(&"rival")
		_sync()
		if rival_delay > 0.0:
			await get_tree().create_timer(_paced(rival_delay)).timeout
			if phase != &"rival":
				return
		var reply: PlacementResult = puzzle.play_reply()
		if reply != null and reply.ok:
			await _replay(reply)
			if phase == &"gone":
				return
	else:
		puzzle.hand_turn_back()
		if not puzzle.is_finished():
			EventBus.turn_started.emit(&"player", puzzle.placements_made() + 1)
	_next_step()


func _next_step() -> void:
	if puzzle.is_finished():
		_end()
		return
	_set_phase(&"player")
	_sync()


# --- Event replay -------------------------------------------------------------------------

## Replays one placement's events onto EventBus (same mapping as DuelController).
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
				EventBus.card_reclaimed.emit(side, e["card_id"], e["slot"])
				_screen.set_slot_owner(e["slot"], side)
			&"spring":
				EventBus.ambush_sprung.emit(side, e["card_id"], e["slot"])
			&"carded":
				EventBus.carded.emit(side, e["card_id"])
			&"turn_started":
				EventBus.turn_started.emit(side, puzzle.placements_made() + 1)
		if event_delay > 0.0 and e["type"] in [&"placed", &"captured", &"reclaimed", &"spring", &"carded"]:
			await get_tree().create_timer(_paced(event_delay)).timeout
	var s: Array[int] = puzzle.scores()
	EventBus.score_changed.emit(s[0], s[1])
	_sync()


# --- Result ---------------------------------------------------------------------------------

func _end() -> void:
	_set_phase(&"result")
	last_result = puzzle.evaluate()
	var ok: bool = last_result["success"]
	var s: Array = last_result["score"]
	var duration: float = (Time.get_ticks_msec() - _started_ms) / 1000.0
	EventBus.duel_ended.emit(&"win" if ok else &"loss", s[0], s[1], puzzle.placements_made(), duration)
	var rewards: PackedStringArray = DossierRewards.reward_lines(dossier, collection)
	if ok and not paid:
		paid = true
		paid_via = DossierRewards.pay(dossier, attempts, duration, collection)
	_sync()
	var buttons: Array = [{"id": &"list", "text": "DOSSIERS"}]
	var next: DossierData = _next_dossier()
	if ok and next != null:
		buttons.append({"id": &"retry", "text": "RETRY"})
		buttons.append({"id": &"next", "text": "NEXT: D%d" % next.number, "primary": true})
	else:
		buttons.append({"id": &"retry", "text": "RETRY", "primary": true})
	_overlay.open(&"dossier_result", "DOSSIER CLEARED" if ok else "NOT YET", "", buttons)
	var box: VBoxContainer = _overlay.get_content()
	var reason: Label = _label(last_result["reason"], &"InspectorHeading", HORIZONTAL_ALIGNMENT_CENTER)
	reason.name = "ResultReason"
	box.add_child(reason)
	var score: Label = _label("%d  –  %d" % [s[0], s[1]], &"InspectorValue", HORIZONTAL_ALIGNMENT_CENTER)
	score.name = "ResultScore"
	box.add_child(score)
	box.add_child(_label("GOAL: %s" % DossierPuzzle.goal_text(dossier), &"Caption", HORIZONTAL_ALIGNMENT_CENTER))
	var rt: String
	if ok:
		rt = "Reward: %s" % " · ".join(rewards) if not rewards.is_empty() else "Cleared before: no new reward."
	else:
		rt = "Tap RETRY to reset the wall. HINT helps." if hint_level < 2 else "Tap RETRY to reset the wall."
	var rl: Label = _label(rt, &"InspectorBody", HORIZONTAL_ALIGNMENT_CENTER)
	rl.name = "ResultReward"
	box.add_child(rl)
	dossier_finished.emit(dossier.id, last_result)


func _next_dossier() -> DossierData:
	var i: int = dossiers.find(dossier)
	return dossiers[i + 1] if i >= 0 and i + 1 < dossiers.size() else null


# --- Overlay and menu -------------------------------------------------------------------------

func _on_overlay_button(id: StringName) -> void:
	match id:
		&"start":
			start()
		&"retry":
			_overlay.close()
			retry()
		&"next":
			var n: DossierData = _next_dossier()
			_overlay.close()
			if n != null:
				open_briefing(n.id)
		&"list":
			_overlay.close()
			open_list()
		&"menu", &"leave":
			_overlay.close()
			phase = &"gone"
			SceneRouter.goto_scene(SceneRouter.SCENE_TITLE)
		&"stay":
			_overlay.close()
			_set_phase(_resume_phase)


func _on_menu() -> void:
	if phase in [&"list", &"idle"]:
		_on_overlay_button(&"menu")
		return
	if phase in [&"briefing", &"result"]:
		_overlay.close()
		open_list()
		return
	_resume_phase = phase if phase != &"resolving" else &"player"
	_overlay.open(&"leave", "LEAVE THIS DOSSIER?", "Progress on this attempt is not kept.", [
		{"id": &"list", "text": "DOSSIERS"}, {"id": &"leave", "text": "MENU"},
		{"id": &"stay", "text": "KEEP PLAYING", "primary": true}])


# --- UI state ----------------------------------------------------------------------------------

## Pushes the puzzle state to the screen: wall, hand, scores, reserved slots, goal line, buttons.
func _sync() -> void:
	if _screen == null or puzzle == null:
		return
	_screen.show_state(ui_state())
	var reserved: Dictionary = {}
	for slot: StringName in puzzle.reserved_slots():
		reserved[slot] = "RESERVED"
	_screen.set_reserved_slots(reserved)
	if phase in [&"player", &"resolving", &"rival", &"result"]:
		_screen.set_goal_text("GOAL: %s  ·  %s" % [DossierPuzzle.goal_text(dossier), puzzle.progress_text()])
	else:
		_screen.set_goal_text("")
	_refresh_buttons()


func _refresh_buttons() -> void:
	if _hint_button != null:
		_hint_button.disabled = phase != &"player"
		_hint_button.text = "HINT" if hint_level == 0 else "HINT 2"
	if _retry_button != null:
		_retry_button.disabled = not (phase in [&"player", &"result"]) or (puzzle != null and puzzle.placements_made() == 0 and phase == &"player")


## The screen's state Dictionary (mock_duel_data.gd shape).
func ui_state() -> Dictionary:
	var st: WallState = puzzle.state
	var wall: Dictionary = {}
	for slot: StringName in st.cells:
		var pc: PlacedCard = st.cells[slot]
		wall[slot] = {"card_id": pc.card.id, "owner": _side(pc.controller), "face_down": pc.face_down, "signature": pc.signature}
	var turn: StringName = &"player" if st.to_move == P1 or phase != &"rival" else &"rival"
	var s: Array[int] = puzzle.scores()
	var hand: Array = puzzle.player_hand().map(func(c: CardData) -> StringName: return c.id)
	var rival_left: Array = []
	for i: int in range(puzzle.replies_made, dossier.rival_replies.size()):
		rival_left.append(dossier.rival_replies[i].card.id)
	return {
		"first_player": &"player", "turn_side": turn,
		"turn_index": mini(puzzle.placements_made() + 1, dossier.max_placements), "turns_total": dossier.max_placements,
		"rival_name": RIVAL_NAME,
		"player": {"name": "You", "score": s[0], "signature_id": _signature_id(DataEnums.Side.PLAYER),
				"signature_carded_by": _carded_by(P1), "hand": hand, "lineup": hand},
		"rival": {"name": RIVAL_NAME, "score": s[1], "signature_id": _signature_id(DataEnums.Side.RIVAL),
				"signature_carded_by": _carded_by(P2), "hand": rival_left, "lineup": rival_left},
		"wall": wall,
	}


func _signature_id(side: DataEnums.Side) -> StringName:
	if side == DataEnums.Side.PLAYER and dossier.hand_signature != null:
		return dossier.hand_signature.id
	for p: DossierPlacement in dossier.board + dossier.rival_replies:
		if p.side == side and p.is_signature:
			return p.card.id
	return &""


func _carded_by(p: int) -> StringName:
	for slot: StringName in puzzle.state.cells:
		var pc: PlacedCard = puzzle.state.cells[slot]
		if pc.signature and pc.lineup == p and pc.controller != p:
			return _side(pc.controller)
	return &""


## UI card Dictionary for an id (CardDB first, then the Dossier's own cards).
func ui_card(card_id: StringName) -> Dictionary:
	var db: Node = get_node_or_null("/root/CardDB")
	var c: CardData = db.call(&"get_card", card_id) if db != null else null
	if c == null and dossier != null:
		c = DossierPuzzle.card_table(dossier).get(card_id, null)
	return c.to_ui_dict() if c != null else {}


# --- Words ------------------------------------------------------------------------------------

static func error_text(code: StringName) -> String:
	if code == DossierPuzzle.ERR_RESERVED:
		return "Reserved: the rival plays there next. Pick another brick."
	if code == WallRules.ERR_GAME_OVER:
		return "No placements left. Tap RETRY to try again."
	return DuelControllerScript.error_text(code)


func preview_text(r: PlacementResult) -> String:
	if r.face_down:
		return "Face-down Ambush: flips at the start of your next turn."
	var parts: Array[String] = []
	var n: int = r.captured.size()
	parts.append("Captures %d" % n if n > 0 else "No captures here")
	if not r.reclaimed.is_empty():
		parts.append("takes back %d" % r.reclaimed.size())
	if r.set_link:
		parts.append("Set Link +%d" % puzzle.state.balance.set_link_bonus)
	if r.clutch:
		parts.append("Clutch +%d" % puzzle.state.balance.clutch_bonus)
	if not r.carded.is_empty():
		parts.append("CARDED!")
	if not r.steady_blocked.is_empty():
		parts.append("Steady holds %d" % r.steady_blocked.size())
	return " · ".join(parts)


func _wait_text() -> String:
	match phase:
		&"rival", &"resolving":
			return "The rival is replying. You can still hold a card to inspect it."
		&"result":
			return "Tap RETRY to play this Dossier again."
	return "Not your turn yet."


# --- Helpers ----------------------------------------------------------------------------------

func _hand_card(card_id: StringName) -> CardData:
	for c: CardData in puzzle.player_hand():
		if c.id == card_id:
			return c
	return null


func _is_cleared(dossier_id: StringName) -> bool:
	var col: Node = collection if collection != null else get_node_or_null("/root/Collection")
	return col != null and col.has_method(&"is_dossier_cleared") and col.call(&"is_dossier_cleared", dossier_id)


func _balance() -> BalanceConfig:
	var db: Node = get_node_or_null("/root/CardDB")
	return db.call(&"get_balance") if db != null and db.has_method(&"get_balance") else null


func _side(p: int) -> StringName:
	return &"player" if p == P1 else (&"rival" if p == P2 else &"")


func _paced(seconds: float) -> float:
	var s: Node = get_node_or_null("/root/Settings")
	return seconds * (0.4 if s != null and s.fast_animations else 1.0)


func _set_phase(p: StringName) -> void:
	phase = p
	phase_changed.emit(p)
	_refresh_buttons()


func _label(text: String, variation: StringName, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 560
	return l

# tutorial_director.gd
# Purpose: Root of scenes/tutorial/Tutorial.tscn (p15): a scripted, skippable first match that
#   teaches deploying, the firefight, the streak and calling in the Recon Drone.
#   It instances the real scenes/Match.tscn, swaps its MatchController script for
#   tutorial_match_controller.gd before it enters the tree (deterministic TutorialScript match,
#   scripted enemy), then walks TutorialScript.steps:
#   - each step: EventBus.tutorial_step(index) (p16 logger), the coach card (CoachOverlay),
#     an amber frame on the highlight target, and, if lock_input, a dimmed screen where only the
#     taught action works (taps elsewhere are blocked; other plays / READY / UNDO are refused by
#     the controller's gates with a short toast)
#   - play_card / place_operator steps frame the hand card / Operator first, then the lane once
#     it is selected (tap-tap and drag both work: both stay tappable)
#   - forced earn: a step's grant_killstreak puts that killstreak in the Streak Tray
#   - "{intel}" in a step's text lists the enemy cards the Recon Drone revealed
#   - SKIP TUTORIAL (tap twice) or DONE after the last step records TutorialProgress and goes to
#     exit_scene (Title); REPLAY reloads the tutorial.
# Dependencies: Match.tscn, tutorial_match_controller.gd, coach_overlay.gd, tutorial_progress.gd,
#   TutorialScript, TutorialStep, MatchState, RulesIntent, StreakTracker, CardDB, EventBus,
#   SceneRouter.
# Author: UI/UX Agent (p15)
extends Control

## A step started (0-based position in TutorialScript.steps).
signal step_started(position: int, step: TutorialStep)
## The tutorial ended: completed = played to the end, false = skipped.
signal finished(completed: bool)

const MATCH_SCENE: PackedScene = preload("res://scenes/Match.tscn")
const TutorialController: GDScript = preload("res://scripts/ui/tutorial/tutorial_match_controller.gd")
const TutorialProgress: GDScript = preload("res://scripts/ui/tutorial/tutorial_progress.gd")
const SCENE_TUTORIAL: String = "res://scenes/tutorial/Tutorial.tscn"
const ZONE_WORDS: PackedStringArray = ["Left", "Mid", "Right"]
const LOCK_HINT: String = "Follow the highlight, or tap SKIP TUTORIAL."

@export var tutorial_id: StringName = &"tutorial_basic"
## Where SKIP / DONE go (SceneRouter path).
@export var exit_scene: String = "res://scenes/Title.tscn"
## Tests: an explicit script instead of CardDB's.
var tutorial: TutorialScript = null

var match_screen: Control = null
var controller: Node = null
## 0-based position in tutorial.steps (-1 before the first, steps.size() when done).
var position_index: int = -1
## Indices sent with EventBus.tutorial_step, in order (tests, QA).
var emitted_steps: PackedInt32Array = []
var _ended: bool = false

@onready var _slot: Control = %MatchSlot
@onready var _coach: Control = %CoachOverlay


func _ready() -> void:
	if tutorial == null:
		tutorial = CardDB.get_tutorial_script(tutorial_id)
	if tutorial == null:
		push_error("Tutorial: no TutorialScript '%s' in CardDB" % tutorial_id)
		return
	match_screen = MATCH_SCENE.instantiate() as Control
	controller = match_screen.get_node("MatchController")
	controller.set_script(TutorialController)
	controller.tutorial = tutorial
	controller.emit_to_event_bus = false
	controller.intent_gate = _gate_intent
	controller.ready_gate = _gate_ready
	controller.undo_gate = _gate_undo
	_slot.add_child(match_screen)
	controller.intent_submitted.connect(_on_intent_submitted)
	controller.round_resolved.connect(_on_round_resolved)
	controller.round_presented.connect(_on_round_presented)
	controller.selection_changed.connect(_refresh_spotlight)
	if match_screen.has_signal(&"flyout_changed"):
		match_screen.flyout_changed.connect(func(_k: StringName) -> void: _refresh_spotlight())
	_coach.next_pressed.connect(_on_next)
	_coach.skip_confirmed.connect(skip)
	_coach.done_pressed.connect(_exit.bind(true))
	_coach.replay_pressed.connect(replay)
	_coach.blocked_tap.connect(func(_p: Vector2) -> void: match_screen.show_toast(LOCK_HINT))
	if EventBus != null:
		EventBus.screen_shown.emit(&"tutorial")
	if controller.state == null:
		push_error("Tutorial: the match did not start")
		return
	_go_to(0)


func _process(_delta: float) -> void:
	if controller == null or controller.state == null or _ended:
		return
	_coach.compact = bool(match_screen.get(&"compact"))
	_refresh_spotlight()


# =============================================================================
# Steps
# =============================================================================

func current_step() -> TutorialStep:
	if tutorial == null or position_index < 0 or position_index >= tutorial.steps.size():
		return null
	return tutorial.steps[position_index]


func is_finished() -> bool:
	return _ended


func _go_to(i: int) -> void:
	position_index = i
	var st: TutorialStep = current_step()
	if st == null:
		_show_end()
		return
	var state: MatchState = controller.state
	if st.grant_killstreak != &"" and st.grant_killstreak not in state.sides[MatchState.PLAYER].streak_tray:
		StreakTracker.grant(state, MatchState.PLAYER, st.grant_killstreak)
		controller.refresh()
	emitted_steps.append(st.index)
	if EventBus != null:
		EventBus.tutorial_step.emit(st.index)
	_coach.show_step(st.title, _text_for(st), st.index, tutorial.steps.size(), st.advance_on == &"next")
	_refresh_spotlight()
	step_started.emit(i, st)
	# A step whose action already happened (e.g. the match ended during the last watch).
	if st.advance_on == &"match_end" and state.phase == MatchState.Phase.ENDED and not controller.is_busy():
		_advance()


func _advance() -> void:
	_go_to(position_index + 1)


func _on_next() -> void:
	var st: TutorialStep = current_step()
	if st != null and st.advance_on == &"next":
		_advance()


func _on_intent_submitted(intent: Dictionary, result: Dictionary) -> void:
	var st: TutorialStep = current_step()
	if st == null or not result.get("ok", false):
		return
	if _intent_matches(st, intent):
		_advance()


func _on_round_resolved(_events: Array) -> void:
	var st: TutorialStep = current_step()
	if st != null and st.advance_on == &"ready":
		_advance()


func _on_round_presented() -> void:
	var st: TutorialStep = current_step()
	if st == null:
		return
	var ended: bool = controller.state.phase == MatchState.Phase.ENDED
	if st.advance_on == &"round_end" or (st.advance_on == &"match_end" and ended):
		_advance()
	elif ended:
		# The match ended before the script expected it: jump to the last step.
		_go_to(tutorial.steps.size() - 1)


## Does this accepted intent complete the step?
func _intent_matches(st: TutorialStep, intent: Dictionary) -> bool:
	match st.advance_on:
		&"place_operator":
			return intent.get("type") == RulesIntent.PLACE_OPERATOR and int(intent.get("zone", -1)) == st.zone
		&"play_card":
			return intent.get("type") == RulesIntent.PLAY_CARD and int(intent.get("zone", -1)) == st.zone \
					and _played_card_id(intent) == st.card_id
		&"use_item":
			return intent.get("type") == RulesIntent.USE_ITEM and StringName(intent.get("item_id", &"")) == st.item_id
	return false


## Card id of a play_card intent (the card has left the hand by now: look in the plays).
func _played_card_id(intent: Dictionary) -> StringName:
	var uid: int = int(intent.get("card_uid", -1))
	var me: RulesSide = controller.state.sides[MatchState.PLAYER]
	var rc: RulesCard = me.find_in_hand(uid)
	if rc != null:
		return rc.card.id
	for p: Dictionary in me.plays:
		var card: RulesCard = p.get("card") as RulesCard
		if card != null and card.uid == uid:
			return card.card.id
	return &""


func _text_for(st: TutorialStep) -> String:
	return st.text.replace("{intel}", intel_text())


## "Combat Medic and Rifleman to Mid" from the zones the player sees face-up (Recon Drone).
func intel_text() -> String:
	var parts: PackedStringArray = []
	for z: int in MatchState.ZONE_COUNT:
		var names: PackedStringArray = []
		for id: StringName in controller.state.revealed_red_dots(MatchState.PLAYER, z):
			var card: CardData = CardDB.get_card(id)
			names.append(card.display_name if card != null else "their Operator")
		if not names.is_empty():
			var who: String = names[0] if names.size() == 1 else "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]
			parts.append("%s to %s" % [who, ZONE_WORDS[z]])
	return "; ".join(parts) if not parts.is_empty() else "no enemy cards seen yet"


# =============================================================================
# Input locks (controller gates)
# =============================================================================

func _locked() -> bool:
	var st: TutorialStep = current_step()
	return st != null and st.lock_input


func _gate_intent(intent: Dictionary) -> String:
	if _ended:
		return ""
	var st: TutorialStep = current_step()
	if st == null or not st.lock_input:
		return ""
	if st.advance_on in [&"place_operator", &"play_card", &"use_item"]:
		if intent.get("type") == RulesIntent.PLAY_CARD:
			var rc: RulesCard = controller.state.sides[MatchState.PLAYER].find_in_hand(int(intent.get("card_uid", -1)))
			if st.advance_on == &"play_card" and rc != null and rc.card.id == st.card_id \
					and int(intent.get("zone", -1)) == st.zone:
				return ""
		elif _intent_matches(st, intent):
			return ""
		if st.zone >= 0:
			return "Not there: use %s." % ZONE_WORDS[st.zone]
	return LOCK_HINT


func _gate_ready() -> String:
	var st: TutorialStep = current_step()
	if _ended or st == null or not st.lock_input or st.advance_on == &"ready":
		return ""
	return "Not yet. " + LOCK_HINT


func _gate_undo() -> String:
	return "" if not _locked() else LOCK_HINT


# =============================================================================
# Spotlight
# =============================================================================

## Global rects of the step's highlight: [framed rects, tappable rects].
func spotlight_rects() -> Array:
	var st: TutorialStep = current_step()
	var frames: Array[Rect2] = []
	var holes: Array[Rect2] = []
	if st == null or controller == null or controller.state == null:
		return [frames, holes]
	var hl: StringName = st.resolved_highlight()
	var sel: Dictionary = controller.selection
	var lane_rect: Rect2 = _lane_rect(st.zone)
	match hl:
		&"operator":
			# kc-ui3: the Operator card at the start of the hand tray is its handle.
			var handle: Control = match_screen.get_operator_panel()
			if not handle.is_visible_in_tree() and match_screen.has_method(&"get_operator_handle"):
				handle = match_screen.get_operator_handle()
			var op: Rect2 = handle.get_global_rect()
			holes.append(op)
			if st.advance_on == &"place_operator" and st.zone >= 0:
				holes.append(lane_rect)
				frames.append(lane_rect if sel.get("kind") == &"operator" else op)
			else:
				frames.append(op)
		&"hand_card":
			var chip: Control = _chip_for(st.card_id)
			var chip_rect: Rect2 = _chip_visible_rect(chip) if chip != null else Rect2()
			if chip != null:
				holes.append(chip_rect)
			if st.zone >= 0:
				holes.append(lane_rect)
			var picked: bool = sel.get("kind") == &"card" and chip != null and int(sel.get("uid", -1)) == int(chip.get_meta(&"uid", -2))
			if picked or chip == null:
				if st.zone >= 0:
					frames.append(lane_rect)
			else:
				frames.append(chip_rect)
		&"lane":
			if st.zone >= 0:
				frames.append(lane_rect)
				holes.append(lane_rect)
		&"enemy_row":
			if st.zone >= 0:
				var row: Control = match_screen.get_board().get_lanes()[st.zone].get_node("%EnemyRow")
				frames.append(row.get_global_rect())
				holes.append(row.get_global_rect())
		&"ready":
			var r: Rect2 = match_screen.get_ready_button().get_global_rect()
			frames.append(r)
			holes.append(r)
		&"killstreak":
			var b: Button = match_screen.get_operator_panel().get_item_button(st.item_id)
			# kc-ui3: a killstreak's tile at the top of the tray is its handle.
			var tile: Control = match_screen.get_killstreak_tile(st.item_id) if match_screen.has_method(&"get_killstreak_tile") else null
			if tile != null and tile.is_visible_in_tree():
				frames.append(tile.get_global_rect())
				holes.append(tile.get_global_rect())
			elif b != null and not b.is_visible_in_tree() and match_screen.has_method(&"get_badge"):
				# kc-board2: the tiles live in the STREAK flyout; point at its badge first.
				var badge: Rect2 = match_screen.get_badge(&"streak").get_global_rect()
				frames.append(badge)
				holes.append(badge)
			elif b != null:
				frames.append(b.get_global_rect())
				holes.append(b.get_global_rect())
		&"streak":
			var arc: Control = match_screen.get_operator_panel().get_streak_arc()
			if arc != null and not arc.is_visible_in_tree() and match_screen.has_method(&"get_badge"):
				frames.append(match_screen.get_badge(&"streak").get_global_rect())
			elif arc != null:
				frames.append(arc.get_global_rect())
		&"minimap", &"score":
			var key: String = "minimap" if hl == &"minimap" else "score_bar"
			var c: Control = match_screen.get_key_controls()[key]
			frames.append(c.get_global_rect())
	return [frames, holes]


func _refresh_spotlight() -> void:
	if _coach == null or controller == null or controller.state == null or _ended:
		return
	var st: TutorialStep = current_step()
	var rects: Array = spotlight_rects()
	var busy: bool = controller.is_busy()
	var lock: bool = st != null and st.lock_input and not busy and not match_screen.get_inspector().is_open()
	var frames: Array[Rect2] = rects[0]
	var holes: Array[Rect2] = rects[1]
	if busy:
		frames = []
	_coach.set_spotlight(frames, holes, lock)


func _lane_rect(zone: int) -> Rect2:
	if zone < 0:
		return Rect2()
	return (match_screen.get_board().get_lanes()[zone] as Control).get_global_rect()


## The hand chip of the first card with this id.
func _chip_for(card_id: StringName) -> Control:
	for rc: RulesCard in controller.state.sides[MatchState.PLAYER].hand:
		if rc.card.id == card_id:
			var chip: Control = match_screen.get_hand().get_card(rc.uid)
			if chip != null:
				chip.set_meta(&"uid", rc.uid)
				return chip
	return null


## The part of a hand chip not covered by the next chip (overlapped hands).
func _chip_visible_rect(chip: Control) -> Rect2:
	var r: Rect2 = chip.get_global_rect()
	var cards: Array[Node] = match_screen.get_hand().get_cards()
	var i: int = cards.find(chip)
	if i >= 0 and i + 1 < cards.size():
		r.size.x = minf(r.size.x, (cards[i + 1] as Control).get_global_rect().position.x - r.position.x)
	return r


# =============================================================================
# End, skip, replay
# =============================================================================

func _show_end() -> void:
	_ended = true
	var result: StringName = controller.state.result
	var line: String = {
		&"player": "You won the drill.",
		&"enemy": "The bot won this time.",
		&"draw": "A draw.",
	}.get(result, "")
	_coach.show_end("DRILL COMPLETE",
			"%s Deploy, fight, build a streak, call it in. That's the loop." % line if line != "" \
			else "Deploy, fight, build a streak, call it in. That's the loop.")


## Ends the tutorial early (SKIP TUTORIAL, tapped twice).
func skip() -> void:
	_exit(false)


func replay() -> void:
	_route(SCENE_TUTORIAL)


func _exit(completed: bool) -> void:
	_ended = true
	var st: TutorialStep = current_step()
	var last: int = st.index if st != null else (tutorial.steps.size() if tutorial != null else 0)
	TutorialProgress.record(completed, last)
	finished.emit(completed)
	_route(exit_scene)


func _route(path: String) -> void:
	var router: Node = get_node_or_null(^"/root/SceneRouter")
	if router != null:
		router.goto_scene(path)
	else:
		get_tree().change_scene_to_file(path)

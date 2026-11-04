# lobby_duel.gd
# Purpose: The Lobby Duel entry point (cc13, plan decision 1: same rules, save and resume).
#   MODE_WAIT  : a generic "Finding match..." screen runs a simulated wait (balance
#                lobby_wait_min_s..max_s, random per visit). "Play a quick duel while you wait" opens
#                scenes/Duel.tscn inside this screen (DuelController entry &"quick", source &"lobby")
#                with the saved lineup (loaner if none) against Quartermaster or Archivist.
#                When the wait ends mid-duel a non-blocking banner offers KEEP PLAYING / SAVE & LEAVE.
#                Save & leave -> Collection.save_lobby_duel(state, meta) -> "Match starting..." -> hub.
#                If the wait ends with no duel on screen it goes straight to "Match starting...".
#   MODE_RESUME: the hub's Continue button. Collection.resume_lobby_duel() restores the duel
#                context (so its end counts for unlocks), EventBus.duel_resumed(age_s) is emitted
#                (not duel_started) and DuelController.resume_duel() continues on the saved WallState.
#   During play MENU offers SAVE & LEAVE / KEEP PLAYING instead of "leave unsaved".
#   A finished duel (win, loss or draw) clears the save (Collection, on duel_ended).
#   Wording is generic on purpose: no franchise, mode or brand names anywhere in this flow.
# Signals out (EventBus): lobby_wait_started(wait_s), lobby_match_found(&"keep" | &"save"),
#   duel_resumed(age_s), screen_shown(&"lobby").
# Dependencies: Collection, CardDB, EventBus, SceneRouter, DuelController (scenes/Duel.tscn),
#   duel_setup.gd, hub_ui.gd.
# Author: Mechanics Developer Agent
extends Control

signal match_found
## The player left for the match (saved: a duel was saved for later).
signal left_lobby(saved: bool)

const DuelControllerScript: GDScript = preload("res://scripts/duel/duel_controller.gd")
const DuelSetup: GDScript = preload("res://scripts/duel/duel_setup.gd")
const DuelTheme: GDScript = preload("res://scripts/ui/duel_theme.gd")
const HubUi: GDScript = preload("res://scripts/hub/hub_ui.gd")
const DUEL_SCENE_PATH: String = "res://scenes/Duel.tscn"

const MODE_WAIT: StringName = &"wait"
const MODE_RESUME: StringName = &"resume"
## Duel source for EventBus.duel_started and Collection (Collection.SOURCE_LOBBY).
const SOURCE_LOBBY: StringName = &"lobby"
## Rivals a quick duel picks from (the easy and normal ones: the duel should be quick).
const QUICK_RIVALS: Array[StringName] = [&"quartermaster", &"archivist"]

## Set by the hub / Title before routing here; consumed on _ready (back to MODE_WAIT).
static var next_mode: StringName = MODE_WAIT
## > 0: the simulated wait in seconds instead of a random one (tests, previews).
static var wait_override_s: float = 0.0


static func set_mode(mode: StringName) -> void:
	next_mode = mode


static func set_wait_override(seconds: float) -> void:
	wait_override_s = seconds


## Tests / previews: the duel's pacing (< 0 keeps the scene's own) and seed (0 = random).
var duel_event_delay: float = -1.0
var duel_rival_delay: float = -1.0
var duel_seed: int = 0
## Pause on "Match found" before "Match starting..." when no duel is on screen.
var found_delay_s: float = 1.2
## Safe area in logical px (tests / previews). Empty = the device's.
var safe_area_override: Rect2 = Rect2()
## The Collection to save to and resume from (tests pass their own instance).
var collection: Node = null

var mode: StringName = MODE_WAIT
## waiting -> playing -> found -> leaving; resumed for MODE_RESUME.
var phase: StringName = &"idle"
var wait_s: float = 0.0
var waited_s: float = 0.0
var searching: bool = false
var duel: Control = null
var rival_id: StringName = &""
## The player chose KEEP PLAYING on the banner.
var kept_playing: bool = false

var _wait_margin: MarginContainer
var _wait_title: Label
var _wait_clock: Label
var _wait_hint: Label
var _quick_button: Button
var _cancel_button: Button
var _duel_host: Control
var _banner_margin: MarginContainer
var _banner: PanelContainer
var _banner_title: Label
var _banner_body: Label
var _keep_button: Button
var _save_button: Button
var _join_button: Button


func _ready() -> void:
	theme = DuelTheme.build()
	if collection == null:
		collection = get_node_or_null("/root/Collection")
	_build()
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	mode = next_mode
	next_mode = MODE_WAIT
	EventBus.screen_shown.emit(&"lobby")
	if mode == MODE_RESUME:
		_start_resume()
	else:
		_start_wait()


func _process(delta: float) -> void:
	if searching:
		advance(delta)


# --- Waiting ----------------------------------------------------------------------------

func _start_wait() -> void:
	phase = &"waiting"
	var b: BalanceConfig = DuelSetup.balance()
	wait_s = wait_override_s if wait_override_s > 0.0 else float(randi_range(b.lobby_wait_min_s, maxi(b.lobby_wait_max_s, b.lobby_wait_min_s)))
	waited_s = 0.0
	searching = true
	_wait_margin.show()
	_update_clock()
	EventBus.lobby_wait_started.emit(wait_s)


## Moves the simulated wait on by seconds (tests call it instead of waiting).
func advance(seconds: float) -> void:
	if not searching:
		return
	waited_s += seconds
	_update_clock()
	if waited_s >= wait_s:
		_on_match_found()


func _update_clock() -> void:
	if _wait_clock != null:
		_wait_clock.text = "Searching  %s" % HubUi.clock(waited_s)


func cancel_search() -> void:
	searching = false
	phase = &"leaving"
	_route(&"hub")


# --- Quick duel ---------------------------------------------------------------------------

## "Play a quick duel while you wait": the saved lineup (loaner if none) vs an easy / normal rival.
func start_quick_duel() -> void:
	if duel != null:
		return
	var ids: Array = []
	if collection != null and collection.has_saved_lineup():
		ids = (collection.get_saved_lineup_ids().get("cards", []) as Array).duplicate()
	var choices: Array[StringName] = []
	for r: Dictionary in DuelSetup.rivals():
		if QUICK_RIVALS.has(r["id"]):
			choices.append(r["id"])
	rival_id = choices[(duel_seed if duel_seed != 0 else randi()) % choices.size()] if not choices.is_empty() else &""
	DuelControllerScript.set_next_duel(rival_id, ids)
	_spawn_duel(&"quick", {})
	phase = &"playing"


func _spawn_duel(entry: StringName, resume: Dictionary) -> void:
	duel = (load(DUEL_SCENE_PATH) as PackedScene).instantiate()
	var ctrl: Node = duel.get_node("%DuelController")
	ctrl.entry = entry
	ctrl.resume_data = resume
	ctrl.source = SOURCE_LOBBY
	ctrl.seed_value = duel_seed
	if duel_event_delay >= 0.0:
		ctrl.event_delay = duel_event_delay
	if duel_rival_delay >= 0.0:
		ctrl.rival_delay = duel_rival_delay
	ctrl.menu_override = _on_duel_menu
	ctrl.duel_finished.connect(_on_duel_finished)
	duel.safe_area_override = safe_area_override
	_wait_margin.hide()
	_duel_host.add_child(duel)
	duel.get_overlay().button_pressed.connect(_on_overlay_button)


func controller() -> Node:
	return duel.get_node("%DuelController") if duel != null else null


# --- Match found ---------------------------------------------------------------------------

func _on_match_found() -> void:
	searching = false
	phase = &"found"
	match_found.emit()
	var ctrl: Node = controller()
	if ctrl == null:
		_wait_title.text = "MATCH FOUND"
		_wait_hint.text = "Your match is ready."
		_quick_button.disabled = true
		if found_delay_s > 0.0:
			await get_tree().create_timer(found_delay_s).timeout
		_go_to_match(false)
		return
	if ctrl.phase == &"over":
		_show_banner(&"ready", HubUi.result_words(HubUi.result_word(ctrl.last_result)))
	else:
		_show_banner(&"choice", "Your match is ready. Keep playing, or save this duel and finish it later.")


func _show_banner(kind: StringName, body: String) -> void:
	_banner_title.text = "MATCH FOUND"
	_banner_body.text = body if kind == &"choice" else "%s Your match is ready." % body
	_keep_button.visible = kind == &"choice"
	_save_button.visible = kind == &"choice"
	_join_button.visible = kind == &"ready"
	_banner_margin.show()


func banner_visible() -> bool:
	return _banner_margin.visible


func get_banner() -> PanelContainer:
	return _banner


## Banner: KEEP PLAYING. The duel never stopped; the banner just goes away.
func keep_playing() -> void:
	kept_playing = true
	_banner_margin.hide()
	EventBus.lobby_match_found.emit(&"keep")


## Banner or MENU: SAVE & LEAVE. Saves the duel in progress (if any) and leaves: to "Match
## starting..." once the match was found, else back to the hub. Returns true when a duel was saved.
func save_and_leave(from_banner: bool = true) -> bool:
	var ctrl: Node = controller()
	var saved: bool = false
	if ctrl != null and ctrl.state != null and not ctrl.state.is_game_over() and collection != null:
		saved = collection.save_lobby_duel(ctrl.state, _save_meta(ctrl))
	if from_banner:
		EventBus.lobby_match_found.emit(&"save")
	if ctrl != null:
		ctrl.phase = &"gone"  # stops a pending rival move
	searching = false
	_banner_margin.hide()
	left_lobby.emit(saved)
	if phase == &"found":
		_go_to_match(saved)
	else:
		phase = &"leaving"
		_route(&"hub")
	return saved


func _save_meta(ctrl: Node) -> Dictionary:
	var sig: CardData = ctrl.player_signature
	return {
		"rival_id": ctrl.rival.get("id", rival_id), "elapsed_s": ctrl.elapsed_s(), "player": WallState.P1,
		"lineup": (ctrl.player_lineup as Array).map(func(c: CardData) -> StringName: return c.id),
		"signature": sig.id if sig != null else &"", "loaner": bool(ctrl.get("_loaner")),
	}


## Banner after the quick duel ended: JOIN MATCH.
func join_match() -> void:
	_banner_margin.hide()
	_go_to_match(false)


func _go_to_match(_saved: bool) -> void:
	phase = &"leaving"
	_route(&"match_starting")


func _on_duel_finished(result: Dictionary) -> void:
	if phase == &"found" and mode == MODE_WAIT:
		_show_banner(&"ready", HubUi.result_words(HubUi.result_word(result)))


# --- Resume --------------------------------------------------------------------------------

func _start_resume() -> void:
	var data: Dictionary = collection.resume_lobby_duel() if collection != null else {}
	if data.is_empty():
		_wait_title.text = "NOTHING TO CONTINUE"
		_wait_hint.text = "That saved duel can't be continued."
		_wait_clock.text = ""
		_quick_button.hide()
		_cancel_button.text = "BACK"
		_wait_margin.show()
		phase = &"idle"
		return
	phase = &"resumed"
	rival_id = data.get("rival_id", &"")
	EventBus.duel_resumed.emit(float(data.get("age_s", 0.0)))
	_spawn_duel(&"resume", data)


# --- MENU during play -------------------------------------------------------------------------

func _on_duel_menu() -> void:
	duel.get_overlay().open(&"lobby_leave", "LEAVE THIS DUEL?",
			"Save & leave keeps it: continue it later from the menu.", [
			{"id": &"save_leave", "text": "SAVE & LEAVE"}, {"id": &"stay", "text": "KEEP PLAYING", "primary": true}])


func _on_overlay_button(id: StringName) -> void:
	if id == &"save_leave":
		duel.get_overlay().close()
		save_and_leave(false)


# --- Routing ---------------------------------------------------------------------------------

func _route(route: StringName) -> void:
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router != null:
		router.goto_route(route)


# --- Layout ------------------------------------------------------------------------------------

func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.0784, 0.0863, 0.106)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_duel_host = Control.new()
	_duel_host.name = "DuelHost"
	_duel_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_duel_host)
	_duel_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_wait_margin = MarginContainer.new()
	_wait_margin.name = "WaitScreen"
	add_child(_wait_margin)
	_wait_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	_wait_margin.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "WaitPanel"
	panel.theme_type_variation = &"InspectorPanel"
	center.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "WaitColumn"
	col.add_theme_constant_override(&"separation", 12)
	panel.add_child(col)
	_wait_title = HubUi.label("WaitTitle", "FINDING MATCH...", &"InspectorName", HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_wait_title)
	_wait_clock = HubUi.label("WaitClock", "", &"InspectorValue", HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_wait_clock)
	var bar: ProgressBar = ProgressBar.new()
	bar.name = "WaitBar"
	bar.indeterminate = true
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(420, 12)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bar)
	_wait_hint = HubUi.label("WaitHint", "Play a quick duel while you wait.", &"InspectorBody", HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_wait_hint)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "WaitButtons"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 16)
	col.add_child(row)
	_cancel_button = HubUi.button("CancelButton", "CANCEL", &"ActionButton", Vector2(180, 64))
	_cancel_button.pressed.connect(cancel_search)
	row.add_child(_cancel_button)
	_quick_button = HubUi.button("QuickDuelButton", "PLAY A QUICK DUEL", &"PrimaryButton", Vector2(300, 64))
	_quick_button.pressed.connect(start_quick_duel)
	row.add_child(_quick_button)
	_wait_margin.hide()

	_banner_margin = MarginContainer.new()
	_banner_margin.name = "BannerLayer"
	_banner_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner_margin)
	_banner_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bcol: VBoxContainer = VBoxContainer.new()
	bcol.name = "BannerColumn"
	bcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_margin.add_child(bcol)
	_banner = PanelContainer.new()
	_banner.name = "MatchBanner"
	_banner.theme_type_variation = &"InspectorPanel"
	_banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_STOP
	bcol.add_child(_banner)
	var brow: HBoxContainer = HBoxContainer.new()
	brow.name = "BannerRow"
	brow.add_theme_constant_override(&"separation", 16)
	_banner.add_child(brow)
	var text_col: VBoxContainer = VBoxContainer.new()
	text_col.name = "BannerText"
	text_col.add_theme_constant_override(&"separation", 0)
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(text_col)
	_banner_title = HubUi.label("BannerTitle", "MATCH FOUND", &"InspectorName")
	text_col.add_child(_banner_title)
	_banner_body = HubUi.label("BannerBody", "", &"Caption")
	_banner_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_body.custom_minimum_size.x = 300
	text_col.add_child(_banner_body)
	_save_button = HubUi.button("SaveLeaveButton", "SAVE & LEAVE", &"ActionButton", Vector2(200, 64))
	_save_button.pressed.connect(save_and_leave)
	brow.add_child(_save_button)
	_keep_button = HubUi.button("KeepPlayingButton", "KEEP PLAYING", &"PrimaryButton", Vector2(200, 64))
	_keep_button.pressed.connect(keep_playing)
	brow.add_child(_keep_button)
	_join_button = HubUi.button("JoinMatchButton", "JOIN MATCH", &"PrimaryButton", Vector2(200, 64))
	_join_button.pressed.connect(join_match)
	brow.add_child(_join_button)
	_banner_margin.hide()


func _relayout() -> void:
	var m: Array[Vector2] = HubUi.safe_margins(self, safe_area_override)
	HubUi.apply_margins(_wait_margin, m[0], m[1])
	HubUi.apply_margins(_banner_margin, m[0], m[1])
	var compact: bool = HubUi.is_compact(self)
	_banner_body.custom_minimum_size.x = 260 if compact else 360
	for b: Button in [_save_button, _keep_button, _join_button]:
		b.custom_minimum_size.x = 180 if compact else 200


## Controls a layout test checks (visible ones only matter).
func get_key_controls() -> Dictionary:
	return {"WaitTitle": _wait_title, "WaitClock": _wait_clock, "WaitHint": _wait_hint,
			"QuickDuelButton": _quick_button, "CancelButton": _cancel_button, "MatchBanner": _banner,
			"KeepPlayingButton": _keep_button, "SaveLeaveButton": _save_button, "JoinMatchButton": _join_button}

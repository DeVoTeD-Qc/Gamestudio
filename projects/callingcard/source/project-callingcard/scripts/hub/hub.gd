# hub.gd
# Purpose: The Banner Wall hub (cc13, menu entry point). Routes to:
#   - DUEL A RIVAL: one button per rival (DuelController.set_next_duel(rival, saved lineup ids);
#     duel_setup.gd then uses the Signature saved with that lineup), loaner when none is saved,
#   - LINEUP (cc10 builder), ALBUM (cc11; disabled until scenes/Album.tscn exists),
#     DOSSIERS (DossierController.set_next_dossier(&"") opens the list), FIND A MATCH (Lobby Duel),
#   - CONTINUE (only while Collection.has_saved_lobby_duel()): resumes the saved Lobby Duel.
#   Shows a progress line from Collection: cards owned x / 20, sets complete, Dossiers cleared.
#   Entering the hub sets SceneRouter.hub_entered, so other screens' "back to the Title" lands here.
# Dependencies: Collection, CardDB, EventBus, SceneRouter, DuelController, DossierController,
#   lobby_duel.gd, duel_setup.gd, hub_ui.gd.
# Author: Mechanics Developer Agent
extends Control

const DuelControllerScript: GDScript = preload("res://scripts/duel/duel_controller.gd")
const DossierControllerScript: GDScript = preload("res://scripts/dossier/dossier_controller.gd")
const LobbyDuelScript: GDScript = preload("res://scripts/lobby/lobby_duel.gd")
const DuelSetup: GDScript = preload("res://scripts/duel/duel_setup.gd")
const DuelTheme: GDScript = preload("res://scripts/ui/duel_theme.gd")
const HubUi: GDScript = preload("res://scripts/hub/hub_ui.gd")
const DIFFICULTY_NAMES: Array[String] = ["Easy", "Normal", "Hard"]

## Safe area in logical px (tests / previews). Empty = the device's.
var safe_area_override: Rect2 = Rect2()
## The Collection shown and resumed from (tests pass their own instance).
var collection: Node = null

var _margin: MarginContainer
var _column: VBoxContainer
var _title: Label
var _progress: Label
var _continue_panel: PanelContainer
var _continue_info: Label
var _continue_button: Button
var _rival_row: HBoxContainer
var _lineup_line: Label
var _buttons: Dictionary = {}  # route id -> Button


func _ready() -> void:
	theme = DuelTheme.build()
	if collection == null:
		collection = get_node_or_null("/root/Collection")
	_build()
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	refresh()
	EventBus.collection_changed.connect(refresh)
	EventBus.lobby_duel_saved.connect(_on_lobby_saved)
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router != null:
		router.hub_entered = true
	EventBus.screen_shown.emit(&"hub")


# --- State ------------------------------------------------------------------------------

## Re-reads Collection: progress line, Continue button, lineup line.
func refresh() -> void:
	var p: Dictionary = progress()
	_progress.text = "Cards %d / %d  ·  Sets %d / %d  ·  Dossiers %d / %d" % [
			p["cards_owned"], p["cards_total"], p["sets_complete"], p["sets_total"], p["dossiers_cleared"], p["dossiers_total"]]
	var has_save: bool = collection != null and collection.has_saved_lobby_duel()
	_continue_panel.visible = has_save
	if has_save:
		var info: Dictionary = collection.saved_lobby_duel_info()
		_continue_info.text = "Quick duel vs %s  ·  %d of 10 placed  ·  saved %s" % [
				HubUi.rival_name(info.get("rival_id", &"")), int(info.get("placements", 0)), HubUi.age_words(float(info.get("age_s", 0.0)))]
	var lineup: Dictionary = collection.get_saved_lineup() if collection != null else {}
	if lineup.is_empty():
		_lineup_line.text = "Lineup: loaner. Build your own in LINEUP."
	else:
		var sig: CardData = lineup.get("signature")
		_lineup_line.text = "Lineup: saved  ·  Signature: %s" % (sig.display_name if sig != null else "none")


## {cards_owned, cards_total, sets_complete, sets_total, dossiers_cleared, dossiers_total}.
func progress() -> Dictionary:
	var db: Node = get_node_or_null("/root/CardDB")
	var out: Dictionary = {"cards_owned": 0, "cards_total": 20, "sets_complete": 0, "sets_total": 0,
			"dossiers_cleared": 0, "dossiers_total": 0}
	if db != null:
		out["cards_total"] = db.card_count()
		out["sets_total"] = db.all_sets().size()
		out["dossiers_total"] = db.all_dossiers().size()
	if collection != null:
		out["cards_owned"] = int(collection.card_totals()["owned"])
		out["dossiers_cleared"] = collection.cleared_dossier_count()
		if db != null:
			for s: SetData in db.all_sets():
				if collection.is_set_complete(s.id):
					out["sets_complete"] += 1
	return out


func continue_visible() -> bool:
	return _continue_panel.visible


func get_button(route: StringName) -> Button:
	return _buttons.get(route)


func get_rival_button(rival_id: StringName) -> Button:
	return _rival_row.get_node_or_null("Rival_%s" % rival_id)


func _on_lobby_saved(_saved: bool) -> void:
	refresh()

# --- Routes -------------------------------------------------------------------------------

## DUEL A RIVAL: the saved lineup (ids; the duel uses its saved Signature) or the loaner.
func duel_rival(rival_id: StringName) -> void:
	var ids: Array = []
	if collection != null and collection.has_saved_lineup():
		ids = (collection.get_saved_lineup_ids().get("cards", []) as Array).duplicate()
	DuelControllerScript.set_next_duel(rival_id, ids)
	_go(&"duel")


func open_lineup() -> void:
	_go(&"lineup")


func open_album() -> void:
	if _router_has(&"album"):
		_go(&"album")


func open_dossiers() -> void:
	DossierControllerScript.set_next_dossier(&"")
	_go(&"dossier")


func find_match() -> void:
	LobbyDuelScript.set_mode(LobbyDuelScript.MODE_WAIT)
	_go(&"lobby")


func continue_lobby_duel() -> void:
	if collection == null or not collection.has_saved_lobby_duel():
		refresh()
		return
	LobbyDuelScript.set_mode(LobbyDuelScript.MODE_RESUME)
	_go(&"lobby")


func _go(route: StringName) -> void:
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router != null:
		router.goto_route(route)


func _router_has(route: StringName) -> bool:
	var router: Node = get_node_or_null("/root/SceneRouter")
	return router != null and router.has_route(route)

# --- Layout --------------------------------------------------------------------------------

func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.0784, 0.0863, 0.106)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin = MarginContainer.new()
	_margin.name = "SafeArea"
	add_child(_margin)
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_margin.add_child(_column)

	var header: HBoxContainer = HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override(&"separation", 16)
	_column.add_child(header)
	_title = HubUi.label("HubTitle", "BANNER WALL", &"InspectorName")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_title)
	_progress = HubUi.label("ProgressLabel", "", &"InspectorBody", HORIZONTAL_ALIGNMENT_RIGHT)
	_progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_progress)

	_continue_panel = PanelContainer.new()
	_continue_panel.name = "ContinuePanel"
	_continue_panel.theme_type_variation = &"InspectorPanel"
	_column.add_child(_continue_panel)
	var crow: HBoxContainer = HBoxContainer.new()
	crow.name = "ContinueRow"
	crow.add_theme_constant_override(&"separation", 16)
	_continue_panel.add_child(crow)
	var ctext: VBoxContainer = VBoxContainer.new()
	ctext.name = "ContinueText"
	ctext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctext.alignment = BoxContainer.ALIGNMENT_CENTER
	ctext.add_theme_constant_override(&"separation", 0)
	crow.add_child(ctext)
	ctext.add_child(HubUi.label("ContinueHeading", "SAVED QUICK DUEL", &"InspectorHeading"))
	_continue_info = HubUi.label("ContinueInfo", "", &"Caption")
	_continue_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ctext.add_child(_continue_info)
	_continue_button = HubUi.button("ContinueButton", "CONTINUE", &"PrimaryButton", Vector2(220, 64))
	_continue_button.pressed.connect(continue_lobby_duel)
	crow.add_child(_continue_button)
	_buttons[&"continue"] = _continue_button

	_column.add_child(HubUi.label("RivalHeading", "DUEL A RIVAL", &"InspectorHeading"))
	_rival_row = HBoxContainer.new()
	_rival_row.name = "RivalRow"
	_rival_row.add_theme_constant_override(&"separation", 12)
	_column.add_child(_rival_row)
	for r: Dictionary in DuelSetup.rivals():
		var b: Button = HubUi.button("Rival_%s" % r["id"], "%s · %s" % [String(r["name"]).to_upper(),
				DIFFICULTY_NAMES[clampi(int(r["difficulty"]), 0, 2)]], &"ActionButton")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: StringName = r["id"]
		b.pressed.connect(func() -> void: duel_rival(id))
		_rival_row.add_child(b)
	_lineup_line = HubUi.label("LineupLine", "", &"Caption")
	_column.add_child(_lineup_line)

	_column.add_child(HubUi.label("MoreHeading", "YOUR WALL", &"InspectorHeading"))
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "RouteRow"
	row.add_theme_constant_override(&"separation", 12)
	_column.add_child(row)
	var specs: Array = [
		[&"lobby", "LobbyButton", "FIND A MATCH", &"PrimaryButton", find_match],
		[&"lineup", "LineupButton", "LINEUP", &"ActionButton", open_lineup],
		[&"album", "AlbumButton", "ALBUM", &"ActionButton", open_album],
		[&"dossier", "DossierButton", "DOSSIERS", &"ActionButton", open_dossiers],
	]
	for s: Array in specs:
		var b: Button = HubUi.button(s[1], s[2], s[3])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(s[4])
		row.add_child(b)
		_buttons[s[0]] = b
	var album_ready: bool = _router_has(&"album")
	_buttons[&"album"].disabled = not album_ready
	if not album_ready:
		_buttons[&"album"].text = "ALBUM (SOON)"
	for route: StringName in [&"lineup", &"dossier", &"lobby"]:
		_buttons[route].disabled = not _router_has(route)


func _relayout() -> void:
	var m: Array[Vector2] = HubUi.safe_margins(self, safe_area_override)
	HubUi.apply_margins(_margin, m[0], m[1])
	_column.add_theme_constant_override(&"separation", 8 if HubUi.is_compact(self) else 16)


## Controls a layout test checks: on screen, inside the safe area, no overlap.
func get_key_controls() -> Dictionary:
	var out: Dictionary = {"HubTitle": _title, "ProgressLabel": _progress, "LineupLine": _lineup_line}
	if _continue_panel.visible:
		out["ContinueButton"] = _continue_button
		out["ContinueInfo"] = _continue_info
	for b: Node in _rival_row.get_children():
		out[b.name] = b
	for route: StringName in [&"lobby", &"lineup", &"album", &"dossier"]:
		out[_buttons[route].name] = _buttons[route]
	return out

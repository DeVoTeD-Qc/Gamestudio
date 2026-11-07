# run_map.gd
# Purpose: Run map (p11, scenes/run/RunMap.tscn). The run's matches left to right (prototype:
#   Bracket 1 x2, Bracket 2 x2, Rival), each with squad, mode and goal, map, bracket bonus and its
#   state in words (WON 6-3 / LOST -1 TICKET / DRAW / NEXT / UPCOMING), plus Reinforcement Tickets
#   left and the current loadout. k-art3: each card shows its mode's painted image (CardArt.mode_texture). DEPLOY starts the next match: it emits
#   EventBus.next_match_requested (p16) and SceneRouter.start_run_match() creates the MatchState
#   (RunState.create_match) and opens Match.tscn with it (hand-off: autoload/scene_router.gd).
# Dependencies: run_screen.gd, RunState, SceneRouter, EventBus, RunFlow.
# Author: UI/UX Agent (p11)
extends "res://scripts/ui/run/run_screen.gd"

const RunV2Views: GDScript = preload("res://scripts/ui/run/run_v2_views.gd")
const MapV2View: GDScript = preload("res://scripts/ui/run/map_v2_view.gd")
const INSPECTOR_SCENE: PackedScene = preload("res://scenes/match/CardInspector.tscn")

## kc-v2-ui: a node was stepped on (tests, previews: with a preview override nothing routes).
signal node_chosen(id: String)

## Hooks passed to RunState.create_match (null = plain MatchHooks).
var match_hooks: MatchHooks = null

var _deploy_button: Button = null
var _quit_button: Button = null
var _nodes: Array[PanelContainer] = []
var _tickets_label: Label = null
var _tickets_row: HBoxContainer = null
var _loadout_label: Label = null

@onready var _header: BoxContainer = %Header
@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _body: MarginContainer = %Body
@onready var _layout: VBoxContainer = %Layout


func screen_id() -> StringName:
	return &"run_map"


func _build() -> void:
	var r: RunProgress = run()
	# kc-v2-ui: a run with the v2 map (RunProgress.map_view, or a preview) gets the lanes-and-steps map.
	if RunV2Views.is_v2(r):
		_build_v2(r)
		return
	# Tickets block in the header: TICKETS, tags, n / total.
	var tickets: VBoxContainer = VBoxContainer.new()
	tickets.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tickets.add_theme_constant_override(&"separation", 2)
	var t_title: Label = make_label("REINFORCEMENT TICKETS", &"HudTag")
	t_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tickets.add_child(t_title)
	var t_row: HBoxContainer = HBoxContainer.new()
	t_row.alignment = BoxContainer.ALIGNMENT_CENTER
	t_row.add_theme_constant_override(&"separation", 10)
	tickets.add_child(t_row)
	_tickets_row = make_tickets(r.tickets if r != null else 0, r.config.tickets if r != null else 3)
	t_row.add_child(_tickets_row)
	_tickets_label = make_label("", &"HudNumber")
	t_row.add_child(_tickets_label)
	_header.add_child(tickets)
	_deploy_button = make_button("DEPLOY", &"ReadyButton", 200)
	_deploy_button.name = "DeployButton"
	_deploy_button.pressed.connect(deploy)
	_header.add_child(_deploy_button)
	# Match cards.
	var row: BoxContainer = BoxContainer.new()  # kc-portrait: turns vertical in portrait
	row.name = "Matches"
	row.add_theme_constant_override(&"separation", 8)
	# kc-portrait: the match cards stack as rows, in a scroll (landscape: one row, no scroll needed).
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "MatchesScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(row)
	portrait_boxes.append(row)
	if r != null:
		for i: int in r.config.matches.size():
			var node: PanelContainer = _match_node(r, i)
			row.add_child(node)
			_nodes.append(node)
	# Footer: loadout summary and SAVE & QUIT.
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 16)
	footer.name = "Footer"
	_layout.add_child(footer)
	_loadout_label = make_label("", &"HudSubtle", true)
	_loadout_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loadout_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_loadout_label)
	# kc-syn-ui: DECK opens the deck view (levels, traits, the Engine panel).
	var deck_b: Button = make_button("DECK", &"HudButton", 120)
	deck_b.name = "DeckButton"
	_deck_view = load("res://scripts/ui/run/engine_panel.gd").new()
	_deck_view.name = "EngineView"
	add_child(_deck_view)
	deck_b.pressed.connect(func() -> void: _deck_view.open(run()))
	footer.add_child(deck_b)
	_deck_button = deck_b
	_quit_button = make_button("SAVE & QUIT", &"HudButton", 170)
	_quit_button.name = "QuitButton"
	_quit_button.pressed.connect(func() -> void: goto(RunFlow.SCENE_TITLE))
	footer.add_child(_quit_button)
	_refresh_text(r)
	_deploy_button.grab_focus.call_deferred()


var _deck_view: Control = null
var _deck_button: Button = null


func get_engine_view() -> Control:
	return _deck_view


func _apply_compact() -> void:
	for b: Button in [_deploy_button, _quit_button, _deck_button]:
		if b != null:
			b.custom_minimum_size.y = button_height()
	if _layout != null:
		_layout.add_theme_constant_override(&"separation", 8 if compact else 12)


# =============================================================================
# kc-v2-ui: the Run v2 map (run-v2.md §2, §9)
# =============================================================================

var _v2: Control = null
var _map_v2: Dictionary = {}
var _inspector: Control = null
var _req_chip: Control = null
var _threat_chip: Control = null


func _build_v2(r: RunProgress) -> void:
	_map_v2 = RunV2Views.map_view(r)
	var m: Dictionary = _map_v2
	_title.text = "RUN MAP  ·  STEP %d OF %d" % [mini(int(m.get("step", 0)) + 1, int(m["steps"])), int(m["steps"])]
	_subtitle.text = "Pick your next step on a lit path. Long-press or right-click any node for the full brief."
	# Header: tickets, REQ, Threat (when a modifier is on), in one row (portrait: under the title).
	var chips: HBoxContainer = HBoxContainer.new()
	chips.name = "HeaderChips"
	chips.add_theme_constant_override(&"separation", 12)
	chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.add_child(chips)
	var tickets: VBoxContainer = VBoxContainer.new()
	tickets.name = "Tickets"
	tickets.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tickets.add_theme_constant_override(&"separation", 2)
	var t_title: Label = make_label("TICKETS", &"HudTag")
	t_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tickets.add_child(t_title)
	var t_row: HBoxContainer = HBoxContainer.new()
	t_row.alignment = BoxContainer.ALIGNMENT_CENTER
	t_row.add_theme_constant_override(&"separation", 8)
	tickets.add_child(t_row)
	var tl: int = int(m.get("tickets", r.tickets if r != null else 3))
	var tm: int = int(m.get("tickets_max", r.config.tickets if r != null else 3))
	_tickets_row = make_tickets(tl, tm)
	t_row.add_child(_tickets_row)
	_tickets_label = make_label("%d/%d" % [tl, tm], &"HudNumber")
	t_row.add_child(_tickets_label)
	chips.add_child(tickets)
	wire_inspect_control(tickets, func() -> void: _inspector.open({"title": "Reinforcement Tickets", "type": "run",
			"text": "A lost fight costs 1 ticket. The run ends at 0. Rests and two events give tickets back (max %d). The shop never sells them." % tm,
			"status": "You have %d of %d." % [tl, tm]}))
	_req_chip = make_req_chip(int(m.get("req", 0)))
	chips.add_child(_req_chip)
	wire_inspect_control(_req_chip, func() -> void: _inspector.open({"title": "Requisition (REQ)", "type": "currency",
			"text": "Earned, never bought: win a fight +3, win an elite +5, lose a fight +1 (with the Salvage), events +1 to +3. Spent in shops.",
			"status": "You have %d REQ." % int(m.get("req", 0))}))
	var mods: Array = m.get("modifiers", [])
	var names: PackedStringArray = []
	for md: Dictionary in mods:
		if bool(md.get("on", true)):
			names.append(String(md.get("name", "")))
	if not names.is_empty():
		_threat_chip = make_threat_chip(int(m.get("threat", RunV2Views.threat_of(mods))), names)
		chips.add_child(_threat_chip)
		wire_inspect_control(_threat_chip, func() -> void: _inspector.open(modifiers_info(mods)))
	# Body: the map and the node brief.
	_v2 = MapV2View.new()
	_body.add_child(_v2)
	_v2.node_chosen.connect(choose_node)
	_v2.inspect_requested.connect(func(info: Dictionary) -> void:
		if not info.is_empty():
			_inspector.open(info))
	# Footer: deck summary, DECK, SAVE & QUIT.
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 16)
	footer.name = "Footer"
	_layout.add_child(footer)
	_loadout_label = make_label("", &"HudSubtle", true)
	_loadout_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loadout_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_loadout_label)
	if r != null:
		_loadout_label.text = "Deck %d cards  ·  %s" % [r.deck.size(), RunFlow.names_of(r, [r.primary], "")]
	var deck_b: Button = make_button("DECK", &"HudButton", 120)
	deck_b.name = "DeckButton"
	_deck_view = load("res://scripts/ui/run/engine_panel.gd").new()
	_deck_view.name = "EngineView"
	add_child(_deck_view)
	deck_b.pressed.connect(func() -> void:
		if run() != null:
			_deck_view.open(run()))
	footer.add_child(deck_b)
	_deck_button = deck_b
	_quit_button = make_button("SAVE & QUIT", &"HudButton", 170)
	_quit_button.name = "QuitButton"
	_quit_button.pressed.connect(func() -> void: goto(RunFlow.SCENE_TITLE))
	footer.add_child(_quit_button)
	_inspector = INSPECTOR_SCENE.instantiate()
	add_child(_inspector)
	_inspector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inspector.hide()
	_refresh_v2()


func _refresh_v2() -> void:
	if _v2 == null:
		return
	var keep: String = _v2.selected_id
	_v2.selected_id = keep
	_v2.setup(_map_v2, portrait, compact)
	_v2.get_go_button().grab_focus.call_deferred()


func _apply_portrait() -> void:
	super()
	if _v2 != null:
		_refresh_v2()


func get_map_view() -> Control:
	return _v2


func get_inspector() -> Control:
	return _inspector


## Steps on node `id` (it must be reachable): the rules record the choice (move_to), then the
## screen for the node opens (RunState.move_to, run-v2-api.md §3): a fight / elite / boss deploys, an event / shop / rest opens its screen.
func choose_node(id: String) -> String:
	var n: Dictionary = RunV2Views.node_by_id(_map_v2, id)
	if n.is_empty() or not bool(n.get("reachable", false)):
		return "Not on your path."
	var err: String = RunV2Views.act(run(), &"move_to", [StringName(id)])
	if err != "":
		return err
	node_chosen.emit(id)
	if not RunV2Views.override_map.is_empty():
		return ""
	match n["type"]:
		&"fight", &"elite", &"boss":
			deploy()
		&"event":
			goto(RunFlow.SCENE_EVENT)
		&"shop":
			goto(RunFlow.SCENE_SHOP)
		&"rest":
			goto(RunFlow.SCENE_REST)
	return ""


static func modifiers_info(mods: Array) -> Dictionary:
	var kws: Array[Dictionary] = []
	for md: Dictionary in mods:
		if bool(md.get("on", true)):
			kws.append({"name": "%s · Threat %d" % [md.get("name", ""), int(md.get("threat", 0))], "text": String(md.get("text", ""))})
	return {"title": "Run modifiers", "type": "threat %d" % RunV2Views.threat_of(mods), "text": "Picked on the Loadout screen before the run. Winning at a Threat level unlocks cosmetics, never power.",
			"keywords": kws, "status": ""}


## DEPLOY: start the next match. Returns the MatchState handed to Match.tscn (null if none).
func deploy() -> MatchState:
	var r: RunProgress = run()
	if r == null or r.phase != RunProgress.PHASE_MATCH:
		return null
	_deploy_button.disabled = true
	var bus: Node = RunFlow.event_bus()
	if bus != null:
		bus.next_match_requested.emit()
	var m: MatchState = RunFlow.router().start_run_match(match_hooks)
	if m == null:
		_deploy_button.disabled = false
	return m


## The card of match i (for tests).
func get_match_node(i: int) -> PanelContainer:
	return _nodes[i]


func _refresh_text(r: RunProgress) -> void:
	if r == null:
		_subtitle.text = "No run"
		_deploy_button.disabled = true
		return
	var md: RunMatchData = r.current_match()
	_title.text = "DEPLOYMENT  ·  MATCH %d OF %d" % [mini(r.match_number(), r.match_count()), r.match_count()]
	if md != null:
		_subtitle.text = "Next: %s vs %s, %s" % [RunFlow.mode_word(md.mode), RunFlow.squad_word(md),
				RunFlow.bracket_word(md, r.match_index == r.match_count() - 1).capitalize()]
	_tickets_label.text = "%d/%d" % [r.tickets, r.config.tickets]
	_deploy_button.disabled = r.phase != RunProgress.PHASE_MATCH
	var primary: String = RunFlow.names_of(r, [r.primary], "")
	var atts: String = RunFlow.names_of(r, r.attachments, "")
	if atts != "":
		primary += " + " + atts
	_loadout_label.text = "Deck %d cards  ·  %s  ·  Perks: %s  ·  Killstreaks: %s" % [
			r.deck.size(), primary, RunFlow.names_of(r, r.perks), RunFlow.names_of(r, r.killstreaks)]


## Run map mode image key (k-art3: assets/sprites/cards/runmap_mode_<key>.webp).
func _mode_key(md: RunMatchData, rival: bool) -> StringName:
	if rival:
		return &"rival"
	match md.mode:
		DataEnums.GameMode.FIREFIGHT:
			return &"firefight"
		DataEnums.GameMode.DETONATOR:
			return &"detonator"
	return &"zone_control"


## Fallback illustration per match card (no mode image): the mode's tactic card art; the Rival
## gets the gunship.
func _mode_art(md: RunMatchData, rival: bool) -> StringName:
	if rival:
		return &"gunship"
	match md.mode:
		DataEnums.GameMode.FIREFIGHT:
			return &"suppressing_fire"
		DataEnums.GameMode.DETONATOR:
			return &"tripwire_charge"
	return &"hold_the_line"


func _match_node(r: RunProgress, i: int) -> PanelContainer:
	var md: RunMatchData = r.config.matches[i]
	var is_last: bool = i == r.config.matches.size() - 1
	var rival: bool = md.is_rival or is_last
	var played: Dictionary = {}
	for h: Dictionary in r.history:
		if int(h["match"]) == i + 1:
			played = h
	var is_next: bool = played.is_empty() and i == r.match_index and not r.is_over()
	var node: PanelContainer = PanelContainer.new()
	node.name = "Match%d" % (i + 1)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_stretch_ratio = 1.0
	if is_next:
		node.theme_type_variation = &"RunNodeNext"
	elif not played.is_empty():
		node.theme_type_variation = &"RunNodeDone"
	elif rival:
		node.theme_type_variation = &"RunNodeRival"
	else:
		node.theme_type_variation = &"RunNode"
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	node.add_child(col)
	col.add_child(make_label("MATCH %d" % (i + 1), &"HudTag"))
	col.add_child(make_label(RunFlow.bracket_word(md, is_last), &"EnemyLabel" if rival else &"HudAccent"))
	var squad: Label = make_label(RunFlow.squad_word(md), &"UnitName", true)
	col.add_child(squad)
	col.add_child(make_label(RunFlow.mode_word(md.mode), &"", true))
	col.add_child(make_label(RunFlow.mode_goal(r.config, md.mode), &"HudSubtle", true))
	col.add_child(make_label(md.map.display_name if md.map != null else "", &"HudSubtle", true))
	col.add_child(make_label(RunFlow.bonus_word(md), &"HudSubtle", true))
	# v01: a mission-brief illustration for the mode fills the card's free space (no minimum
	# size, so it never pushes the layout; it shrinks away on short screens).
	var art := TextureRect.new()
	art.name = "Art"
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = CardArt.mode_texture(_mode_key(md, rival), _mode_art(md, rival), 2.0)
	art.modulate = Color(1, 1, 1, 0.45 if not played.is_empty() else (1.0 if is_next else 0.75))
	col.add_child(art)
	var status: Label = make_label("", &"HudHeader", true)
	status.name = "Status"
	if not played.is_empty():
		var res: StringName = StringName(str(played["result"]))
		status.text = RunFlow.result_word(res)
		if res != &"draw" or int(played["player_score"]) + int(played["enemy_score"]) > 0:
			status.text += "  %d-%d" % [int(played["player_score"]), int(played["enemy_score"])]
		if bool(played.get("ticket_lost", false)):
			status.text += "\n-1 TICKET"
		status.theme_type_variation = {&"player": &"FriendlyLabel", &"enemy": &"EnemyLabel"}.get(res, &"HudHeader")
	elif is_next:
		status.text = "NEXT"
		status.theme_type_variation = &"HudAccent"
	else:
		status.text = "UPCOMING"
		status.theme_type_variation = &"HudTag"
	col.add_child(status)
	return node

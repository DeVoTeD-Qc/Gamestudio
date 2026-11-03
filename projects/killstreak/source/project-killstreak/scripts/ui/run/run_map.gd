# run_map.gd
# Purpose: Run map (p11, scenes/run/RunMap.tscn). The run's matches left to right (prototype:
#   Bracket 1 x2, Bracket 2 x2, Rival), each with squad, mode and goal, map, bracket bonus and its
#   state in words (WON 6-3 / LOST -1 TICKET / DRAW / NEXT / UPCOMING), plus Reinforcement Tickets
#   left and the current loadout. DEPLOY starts the next match: it emits
#   EventBus.next_match_requested (p16) and SceneRouter.start_run_match() creates the MatchState
#   (RunState.create_match) and opens Match.tscn with it (hand-off: autoload/scene_router.gd).
# Dependencies: run_screen.gd, RunState, SceneRouter, EventBus, RunFlow.
# Author: UI/UX Agent (p11)
extends "res://scripts/ui/run/run_screen.gd"

## Hooks passed to RunState.create_match (null = plain MatchHooks).
var match_hooks: MatchHooks = null

var _deploy_button: Button = null
var _quit_button: Button = null
var _nodes: Array[PanelContainer] = []
var _tickets_label: Label = null
var _tickets_row: HBoxContainer = null
var _loadout_label: Label = null

@onready var _header: HBoxContainer = %Header
@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _body: MarginContainer = %Body
@onready var _layout: VBoxContainer = %Layout


func screen_id() -> StringName:
	return &"run_map"


func _build() -> void:
	var r: RunProgress = run()
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
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Matches"
	row.add_theme_constant_override(&"separation", 8)
	_body.add_child(row)
	if r != null:
		for i: int in r.config.matches.size():
			var node: PanelContainer = _match_node(r, i)
			row.add_child(node)
			_nodes.append(node)
	# Footer: loadout summary and SAVE & QUIT.
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 16)
	_layout.add_child(footer)
	_loadout_label = make_label("", &"HudSubtle", true)
	_loadout_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loadout_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_loadout_label)
	_quit_button = make_button("SAVE & QUIT", &"HudButton", 170)
	_quit_button.name = "QuitButton"
	_quit_button.pressed.connect(func() -> void: goto(RunFlow.SCENE_TITLE))
	footer.add_child(_quit_button)
	_refresh_text(r)
	_deploy_button.grab_focus.call_deferred()


func _apply_compact() -> void:
	for b: Button in [_deploy_button, _quit_button]:
		if b != null:
			b.custom_minimum_size.y = button_height()
	if _layout != null:
		_layout.add_theme_constant_override(&"separation", 8 if compact else 12)


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
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
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

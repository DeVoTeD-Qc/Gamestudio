# run_end.gd
# Purpose: Run end (p11, scenes/run/RunEnd.tscn). Win or defeat in words and shape, why the run
#   ended, a summary (record, tickets left, deck size, attachments, perks, killstreaks, play time)
#   and one row per match (opponent, mode, result, score). The ended run's save is dropped when the
#   player leaves. While playtest logging is on and the end survey isn't done, the button goes to
#   the end survey first (p16 wiring: EndSurvey -> Title); otherwise NEW RUN starts the next run
#   straight away and TITLE goes back.
# Dependencies: run_screen.gd, RunFlow, RunState, PlaytestLog.
# Author: UI/UX Agent (p11)
extends "res://scripts/ui/run/run_screen.gd"

var _new_run_button: Button = null
var _title_button: Button = null
var _result_label: Label = null

@onready var _header: BoxContainer = %Header
@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _body: MarginContainer = %Body


## kc-ui-wire2: painted backdrop (assets/ui/backgrounds/bg_after_action.webp) under the run-screen scrim.
func backdrop_key() -> StringName:
	return &"after_action"


func screen_id() -> StringName:
	return &"run_end"


func _build() -> void:
	var r: RunProgress = run()
	var survey: bool = RunFlow.scene_after_run_end() == RunFlow.SCENE_END_SURVEY
	_title_button = make_button("TITLE", &"HudButton", 130)
	_title_button.name = "TitleButton"
	_title_button.pressed.connect(to_title)
	_new_run_button = make_button("PLAYTEST SURVEY" if survey else "NEW RUN", &"ReadyButton", 240)
	_new_run_button.name = "NewRunButton"
	_new_run_button.pressed.connect(new_run)
	_title_button.visible = not survey
	_header.add_child(_title_button)
	_header.add_child(_new_run_button)
	var row: BoxContainer = BoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	_body.add_child(row)
	# kc-ux-text: in portrait the summary sits over the match table (it ran off the screen).
	portrait_boxes.append(row)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.8
	left.add_theme_constant_override(&"separation", 6)
	row.add_child(left)
	_result_label = make_label("", &"ResultDraw")
	_result_label.name = "ResultLabel"
	left.add_child(_result_label)
	var reason: Label = make_label("", &"", true)
	reason.name = "ReasonLabel"
	left.add_child(reason)
	var summary: Label = make_label("", &"HudSubtle", true)
	summary.name = "SummaryLabel"
	left.add_child(summary)
	var table_panel: PanelContainer = PanelContainer.new()
	table_panel.theme_type_variation = &"HudPanelDark"
	table_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(table_panel)
	var table: GridContainer = GridContainer.new()
	table.name = "History"
	table.columns = 4
	table.add_theme_constant_override(&"h_separation", 14)
	table.add_theme_constant_override(&"v_separation", 4)
	table_panel.add_child(table)
	if r == null or not r.is_over():
		_result_label.text = "NO RUN"
		return
	var won: bool = r.is_victory()
	_title.text = "RUN COMPLETE" if won else "RUN OVER"
	_subtitle.text = "%d of %d matches played  ·  %s" % [r.matches_played(), r.match_count(), RunFlow.time_word(r.play_time_s)]
	_result_label.text = "VICTORY" if won else "DEFEAT"
	_result_label.theme_type_variation = &"ResultWin" if won else &"ResultLoss"
	reason.text = String(RunFlow.END_WORDS.get(r.end_reason, ""))
	# kc-ux-text: the record and what you ended with; an empty list is left out (no "None").
	var lines: PackedStringArray = ["Record %d won, %d lost, %d drawn" % [r.count_results(&"player"),
			r.count_results(&"enemy"), r.count_results(&"draw")],
			"Tickets left %d of %d  ·  Deck %d cards" % [r.tickets, r.config.tickets, r.deck.size()]]
	for pair: Array in [["Attachments", r.attachments], ["Perks", r.perks], ["Killstreaks", r.killstreaks]]:
		if not (pair[1] as Array).is_empty():
			lines.append("%s: %s" % [pair[0], RunFlow.names_of(r, pair[1])])
	summary.text = "\n".join(lines)
	for head: String in ["MATCH", "OPPONENT", "MODE", "RESULT"]:
		table.add_child(make_label(head, &"HudTag"))
	for h: Dictionary in r.history:
		var n: int = int(h["match"])
		var md: RunMatchData = r.config.matches[n - 1] if n >= 1 and n <= r.match_count() else null
		table.add_child(make_label(("%d  RIVAL" % n) if h["rival"] else str(n), &"HudNumber"))
		table.add_child(make_label(RunFlow.squad_word(md), &"UnitName"))
		table.add_child(make_label(RunFlow.mode_word(md.mode) if md != null else str(h["mode"]), &""))
		var res: StringName = StringName(str(h["result"]))
		var res_label: Label = make_label("%s %d-%d" % [RunFlow.result_word(res), int(h["player_score"]), int(h["enemy_score"])],
				{&"player": &"FriendlyLabel", &"enemy": &"EnemyLabel"}.get(res, &"HudHeader"))
		table.add_child(res_label)
	_new_run_button.grab_focus.call_deferred()


func _apply_compact() -> void:
	for b: Button in [_new_run_button, _title_button]:
		if b != null:
			b.custom_minimum_size.y = button_height()


## NEW RUN (or PLAYTEST SURVEY first while the end survey is due).
func new_run() -> void:
	var next: String = RunFlow.scene_after_run_end()
	var rs: Node = RunFlow.run_state()
	rs.abandon_run()
	if next == RunFlow.SCENE_END_SURVEY:
		goto(next)
		return
	rs.start_run()
	goto(RunFlow.SCENE_LOADOUT)


func to_title() -> void:
	RunFlow.run_state().abandon_run()
	goto(RunFlow.SCENE_TITLE)

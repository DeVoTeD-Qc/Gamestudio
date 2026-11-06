# after_action.gd
# Purpose: After-Action report (p11, scenes/run/AfterAction.tscn), shown after every run match.
#   Result in words and shape (VICTORY / DEFEAT / DRAW), why it ended, opponent and map, then
#   rounds, score vs the mode target, eliminations, best streak and the ticket change (tags plus
#   "2/3", "-1 (was 3)"). The report comes from SceneRouter.last_match_report (RunFlow.record_match) or,
#   after a reload, from the run's last history entry. CONTINUE names where it goes: the first
#   reward offer, the run map, or the run summary when the run is over.
# Dependencies: run_screen.gd, RunFlow, RunState, SceneRouter.
# Author: UI/UX Agent (p11)
extends "res://scripts/ui/run/run_screen.gd"

const REASON_WORDS: Dictionary = {
	"target": "Reached the target score.",
	"round_cap": "Most points after the last round.",
	"overtime": "Decided in overtime.",
	"overtime_draw": "Still tied after overtime.",
	"forfeit": "You forfeited the match.",
}
const OFFER_WORDS: Dictionary = {
	RewardOffers.KIND_SUPPLY_DROP: "SUPPLY DROP",
	RewardOffers.KIND_ATTACHMENT: "WEAPON LEVEL",
	RewardOffers.KIND_PERK: "PERK OFFER",
	RewardOffers.KIND_DOCTRINE: "DOCTRINE",
	RewardOffers.KIND_PROMOTION: "PROMOTION",
	RewardOffers.KIND_REGROUP: "REGROUP",
}
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
## Honor Roll entries shown before "+ n more".
const HONOR_SHOWN: int = 5

var report: Dictionary = {}

var _continue_button: Button = null
var _stats: HBoxContainer = null
var _result_label: Label = null

@onready var _header: HBoxContainer = %Header
@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _body: MarginContainer = %Body
@onready var _layout: VBoxContainer = %Layout


func screen_id() -> StringName:
	return &"after_action"


func _build() -> void:
	report = RunFlow.current_report()
	var r: RunProgress = run()
	var center: CenterContainer = CenterContainer.new()
	_body.add_child(center)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	center.add_child(col)
	_result_label = make_label("", &"ResultDraw")
	_result_label.name = "ResultLabel"
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_result_label)
	var why: Label = make_label("", &"HudSubtle")
	why.name = "ReasonLabel"
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(why)
	_stats = HBoxContainer.new()
	_stats.name = "Stats"
	_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	_stats.add_theme_constant_override(&"separation", 10)
	col.add_child(_stats)
	_continue_button = make_button("CONTINUE", &"ReadyButton", 320)
	_continue_button.name = "ContinueButton"
	_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue_button.pressed.connect(continue_on)
	col.add_child(_continue_button)
	if report.is_empty() or r == null:
		_result_label.text = "NO REPORT"
		_continue_button.text = "TITLE"
		return
	var res: StringName = report["result"]
	_result_label.text = {&"player": "VICTORY", &"enemy": "DEFEAT"}.get(res, "DRAW")
	_result_label.theme_type_variation = {&"player": &"ResultWin", &"enemy": &"ResultLoss"}.get(res, &"ResultDraw")
	why.text = String(REASON_WORDS.get(String(report["reason"]), ""))
	if why.text == "":
		why.hide()
	var tag: String = "RIVAL" if report["rival"] else "BRACKET %d" % int(report["bracket"])
	_title.text = "AFTER-ACTION  ·  MATCH %d OF %d  ·  %s" % [int(report["match"]), int(report["matches_total"]), tag]
	_subtitle.text = "%s vs %s  ·  %s" % [report["mode"], report["squad"], report["map"]]
	_stat("ROUNDS", str(report["rounds"]))
	var score: String = "%d-%d" % [int(report["player_score"]), int(report["enemy_score"])]
	_stat("SCORE", score, "target %d" % int(report["target"]) if int(report["target"]) > 0 else "")
	_stat("ELIMINATIONS", _num(report["player_eliminations"]) + "-" + _num(report["enemy_eliminations"]), "you - enemy")
	_stat("BEST STREAK", _num(report["best_streak"]))
	_tickets_stat(int(report["tickets_before"]), int(report["tickets_after"]), r.config.tickets)
	_honor_roll(col, r)
	_continue_button.text = continue_text()


func _apply_compact() -> void:
	if _continue_button != null:
		_continue_button.custom_minimum_size.y = button_height()


## Where CONTINUE goes, in words.
func continue_text() -> String:
	var r: RunProgress = run()
	if r == null:
		return "TITLE"
	if r.is_over():
		return "RUN SUMMARY"
	var offer: Dictionary = r.current_offer()
	if not offer.is_empty():
		return "CONTINUE: " + String(OFFER_WORDS.get(offer["kind"], "REWARD"))
	return "CONTINUE: RUN MAP"


func continue_on() -> void:
	goto(RunFlow.scene_for(run()))


func _num(v: Variant) -> String:
	return "—" if int(v) < 0 else str(int(v))


func _stat_box(title: String) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"HudPanelDark"
	panel.custom_minimum_size.x = 150
	_stats.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	panel.add_child(box)
	var t: Label = make_label(title, &"HudTag")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	return box


func _stat(title: String, value: String, note: String = "") -> void:
	var box: VBoxContainer = _stat_box(title)
	box.get_parent().name = "Stat" + title.replace(" ", "").capitalize()
	var v: Label = make_label(value, &"StatValue")
	v.name = "Value"
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(v)
	if note != "":
		var n: Label = make_label(note, &"HudSubtle")
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(n)


func _tickets_stat(before: int, after: int, total: int) -> void:
	var box: VBoxContainer = _stat_box("TICKETS")
	box.get_parent().name = "StatTickets"
	var v: Label = make_label("%d/%d" % [after, total], &"StatValue")
	v.name = "Value"
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(v)
	box.add_child(make_tickets(after, total, Vector2(14, 20)))
	var n: Label = make_label("-%d (was %d)" % [before - after, before] if before > after else "no change", &"HudSubtle")
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(n)


## kc-syn-ui: the Honor Roll album page (cosmetic): every card retired this run, with its level,
## the match it left after and whether it trained its twin. Long-press shows the full list.
func _honor_roll(col: VBoxContainer, r: RunProgress) -> void:
	if r.honor_roll.is_empty():
		return
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "HonorRoll"
	box.add_theme_constant_override(&"separation", 4)
	col.add_child(box)
	col.move_child(box, _continue_button.get_index())
	var head: Label = make_label("HONOR ROLL  ·  %d RETIRED" % r.honor_roll.size(), &"HudTag")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var row: HFlowContainer = HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"h_separation", 8)
	row.add_theme_constant_override(&"v_separation", 4)
	box.add_child(row)
	var start: int = maxi(0, r.honor_roll.size() - HONOR_SHOWN)
	for i: int in range(start, r.honor_roll.size()):
		var h: Dictionary = r.honor_roll[i]
		var card: CardData = r.resource(StringName(h["id"])) as CardData
		var p: PanelContainer = PanelContainer.new()
		p.theme_type_variation = &"HudPanelDark"
		var hb: HBoxContainer = HBoxContainer.new()
		hb.add_theme_constant_override(&"separation", 6)
		p.add_child(hb)
		var sw: Control = Control.new()
		sw.custom_minimum_size = Vector2(14, 24)
		var band: StringName = SynergyGlyphs.band_of(int(h["level"]))
		sw.draw.connect(func() -> void:
			if band == &"":
				sw.draw_rect(Rect2(Vector2.ZERO, sw.size), Color("#2A3036"))
			else:
				SynergyGlyphs.draw_band(sw, Rect2(Vector2.ZERO, sw.size), band))
		hb.add_child(sw)
		var words: String = "%s · after M%d%s" % [card.display_name if card != null else String(h["id"]), maxi(1, int(h["match"])),
				" · twin trained" if bool(h.get("trained_twin", false)) else ""]
		hb.add_child(make_label(words))
		row.add_child(p)
	if start > 0:
		row.add_child(make_label("+ %d more" % start, &"HudSubtle"))

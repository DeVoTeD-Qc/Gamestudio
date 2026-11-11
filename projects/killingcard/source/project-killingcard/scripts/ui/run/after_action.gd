# after_action.gd
# Purpose: After-Action report (p11, scenes/run/AfterAction.tscn), shown after every run match.
#   Result in words and shape (VICTORY / DEFEAT / DRAW), why it ended, opponent and map, then
#   rounds, score vs the mode target, eliminations, best streak and the ticket change (tags plus
#   "2/3", "-1 (was 3)"). The report comes from SceneRouter.last_match_report (RunFlow.record_match) or,
#   after a reload, from the run's last history entry. CONTINUE names where it goes: the first
#   reward offer, the run map, or the run summary when the run is over.
#   kc-da-ui2 (art direction #9): a debrief sheet on orders paper: VICTORY / DEFEAT / DRAW as a
#   rotated stencil stamp (lands with a short scale-in; fades only with Reduced motion), the stats
#   the report really knows as a typed list (no "---" rows), and the MVP card large with its band
#   (RunFlow.mvp from the match log; after a reload, your Operator, labelled as such).
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
	RewardOffers.KIND_REGROUP: "REGROUP",
}
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
## Honor Roll entries shown before "+ n more".
const HONOR_SHOWN: int = 5
const PaperSheet: GDScript = preload("res://scripts/ui/paper_sheet.gd")
const CodexView: GDScript = preload("res://scripts/ui/codex/codex_view.gd")
const STAMP_ANGLE: float = -7.0
## MVP card width (desktop / phone landscape).
const MVP_W: float = 360.0
const MVP_W_COMPACT: float = 236.0

var report: Dictionary = {}

var _continue_button: Button = null
var _stats: VBoxContainer = null
var _result_label: Label = null
var _sheet: PanelContainer = null
var _sheet_row: BoxContainer = null
var _mvp_card: Control = null

@onready var _header: BoxContainer = %Header
@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _body: MarginContainer = %Body
@onready var _layout: VBoxContainer = %Layout


## kc-ui-wire2: painted backdrop (assets/ui/backgrounds/bg_after_action.webp) under the run-screen scrim.
func backdrop_key() -> StringName:
	return &"after_action"


func screen_id() -> StringName:
	return &"after_action"


func _build() -> void:
	report = RunFlow.current_report()
	var r: RunProgress = run()
	var center: CenterContainer = CenterContainer.new()
	_body.add_child(center)
	# kc-da-ui2 (#9): the debrief sheet: orders paper with the result stamped on it, the real stats
	# typed as a list (unknown ones are left out, never "---"), the MVP card large with its band,
	# and the one amber button.
	_sheet = PanelContainer.new()
	_sheet.name = "Debrief"
	PaperSheet.apply(_sheet, 16.0, 6)
	center.add_child(_sheet)
	_sheet_row = BoxContainer.new()
	_sheet_row.name = "SheetRow"
	_sheet_row.add_theme_constant_override(&"separation", 22)
	_sheet.add_child(_sheet_row)
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "Orders"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 6)
	_sheet_row.add_child(col)
	# The stamp turns, so it sits in a plain Control (containers reset rotation and scale).
	var stamp_holder: Control = Control.new()
	stamp_holder.name = "StampHolder"
	stamp_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stamp_holder)
	_result_label = make_label("", &"")
	_result_label.name = "ResultLabel"
	stamp_holder.add_child(_result_label)
	_result_label.resized.connect(func() -> void:
		# Room for the turned corners: about sin(7 deg) of the width, top and bottom.
		var lift: float = ceilf(_result_label.size.x * 0.07)
		stamp_holder.custom_minimum_size = _result_label.size + Vector2(8, 6 + lift * 2.0)
		_result_label.position = Vector2(4, 3 + lift))
	var why: Label = PaperSheet.ink(make_label("", &"HudSubtle"), PaperSheet.INK_MUTED)
	why.name = "ReasonLabel"
	col.add_child(why)
	_stats = VBoxContainer.new()
	_stats.name = "Stats"
	_stats.add_theme_constant_override(&"separation", 2)
	col.add_child(_stats)
	_continue_button = make_button("CONTINUE", &"ReadyButton", 300)
	_continue_button.name = "ContinueButton"
	_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_continue_button.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	_continue_button.pressed.connect(continue_on)
	col.add_child(_continue_button)
	if report.is_empty() or r == null:
		_stamp(&"")
		_result_label.text = "NO REPORT"
		_continue_button.text = "TITLE"
		return
	var res: StringName = report["result"]
	_stamp(res)
	why.text = String(REASON_WORDS.get(String(report["reason"]), ""))
	if res == &"enemy" and String(report["reason"]) == "target":
		why.text = "The rival reached the target score."
	if why.text == "":
		why.hide()
	var tag: String = "RIVAL" if report["rival"] else "BRACKET %d" % int(report["bracket"])
	_title.text = "AFTER-ACTION  ·  MATCH %d OF %d  ·  %s" % [int(report["match"]), int(report["matches_total"]), tag]
	_subtitle.text = "%s vs %s  ·  %s" % [report["mode"], report["squad"], report["map"]]
	var score: String = "%d-%d" % [int(report["player_score"]), int(report["enemy_score"])]
	_stat("SCORE", score, "target %d" % int(report["target"]) if int(report["target"]) > 0 else "")
	_stat("ROUNDS", str(report["rounds"]))
	# Real stats only: a stat the report does not know (-1, e.g. after a reload) is left out.
	if int(report["player_eliminations"]) >= 0 and int(report["enemy_eliminations"]) >= 0:
		_stat("ELIMINATIONS", "%d-%d" % [int(report["player_eliminations"]), int(report["enemy_eliminations"])], "you - enemy")
	if int(report["best_streak"]) > 0:
		_stat("BEST STREAK", str(int(report["best_streak"])))
	# kc-v2-ui: the Requisition this fight earned, and the run's REQ now.
	if int(report.get("req_gained", -1)) >= 0:
		_stat("REQ", "+%d" % int(report["req_gained"]), "now %d" % int(r.get("req")) if &"req" in r else "")
	if bool(report.get("elite", false)):
		_title.text += "  ·  ELITE"
	_tickets_stat(int(report["tickets_before"]), int(report["tickets_after"]), r.config.tickets)
	_honor_roll(col, r)
	_mvp_column(r)
	_continue_button.text = continue_text()
	_land_stamp()


## The VICTORY / DEFEAT / DRAW stamp: a Label in Stardos Stencil, deep side ink, double rule,
## rotated like a rubber stamp (art-direction.md §3, §11 after-action).
func _stamp(res: StringName) -> void:
	var word: String = {&"player": "VICTORY", &"enemy": "DEFEAT"}.get(res, "DRAW")
	var ink_c: Color = {&"player": PaperSheet.STAMP_WIN, &"enemy": PaperSheet.STAMP_LOSS}.get(res, PaperSheet.STAMP_DRAW)
	_result_label.text = word
	_result_label.theme_type_variation = {&"player": &"ResultWin", &"enemy": &"ResultLoss"}.get(res, &"ResultDraw")
	_result_label.set_meta(&"stamp", true)
	_result_label.add_theme_font_override(&"font", PaperSheet.stencil_font())
	_result_label.add_theme_font_size_override(&"font_size", 34 if compact else 56)
	PaperSheet.ink(_result_label, Color(ink_c, 0.92))
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color(ink_c, 0.92)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	_result_label.add_theme_stylebox_override(&"normal", sb)
	_result_label.size = _result_label.get_combined_minimum_size()
	_result_label.rotation_degrees = STAMP_ANGLE
	_result_label.tooltip_text = "Match result: %s" % word.capitalize()
	if not _result_label.draw.is_connected(_draw_stamp_rule):
		_result_label.draw.connect(_draw_stamp_rule)
	if not _result_label.resized.is_connected(_center_stamp_pivot):
		_result_label.resized.connect(_center_stamp_pivot)


func _draw_stamp_rule() -> void:
	var c: Color = _result_label.get_theme_color(&"font_color")
	_result_label.draw_rect(Rect2(Vector2.ZERO, _result_label.size).grow(-8.0), Color(c, c.a * 0.8), false, 1.5)


func _center_stamp_pivot() -> void:
	_result_label.pivot_offset = _result_label.size * 0.5


## The stamp lands: scale 1.35 -> 1 with a fade (ease-out-back, 0.25 s); Fast animations halve it;
## Reduced motion fades only.
func _land_stamp() -> void:
	var st: Node = get_tree().root.get_node_or_null("Settings") if is_inside_tree() else null
	var reduced: bool = st != null and bool(st.get("reduced_motion"))
	var fast: bool = st != null and bool(st.get("fast_animations"))
	var t: float = 0.12 if fast else 0.25
	_result_label.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_result_label, ^"modulate:a", 1.0, t)
	if not reduced:
		_result_label.scale = Vector2(1.35, 1.35)
		tw.tween_property(_result_label, ^"scale", Vector2.ONE, t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## kc-da-ui2: the MVP card large, with its band under it. MVP = your unit that did the most this
## match (RunFlow.mvp); when the report has no match log (a reload), the column shows your Operator
## and says so. Long press / right click opens the inspector.
func _mvp_column(r: RunProgress) -> void:
	var mvp: Dictionary = report.get("mvp", {})
	var view: Dictionary = {}
	var info: Dictionary = {}
	var band: StringName = MasteryBands.BASE
	var head: String = "MVP"
	var line: String = ""
	if not mvp.is_empty():
		if bool(mvp.get("operator", false)):
			var item: LoadoutItem = r.resource(StringName(String(mvp["card_id"]))) as LoadoutItem
			if item != null:
				view = _operator_view(item)
				info = _operator_info(item)
				band = BannerArtDB.camo_for_tier(1)
		else:
			var card: CardData = card_by_id(StringName(String(mvp["card_id"])))
			if card != null:
				var art: StringName = StringName(String(mvp.get("art", "")))
				view = CardView.view_for_card(card, art if art != &"" else card.id)
				info = card_inspect_info(card)
		var bits: PackedStringArray = []
		if int(mvp.get("kills", 0)) > 0:
			bits.append("%d KILL%s" % [int(mvp["kills"]), "" if int(mvp["kills"]) == 1 else "S"])
		if int(mvp.get("damage", 0)) > 0:
			bits.append("%d DAMAGE" % int(mvp["damage"]))
		line = "  ·  ".join(bits)
	if view.is_empty() and r.primary != &"":
		var op: LoadoutItem = r.resource(r.primary) as LoadoutItem
		if op != null:
			view = _operator_view(op)
			info = _operator_info(op)
			band = BannerArtDB.camo_for_tier(1)
			head = "YOUR OPERATOR"
	if view.is_empty():
		return
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Mvp"
	box.add_theme_constant_override(&"separation", 4)
	_sheet_row.add_child(box)
	var h: Label = PaperSheet.ink(make_label(head, &"HudTag"), PaperSheet.INK_BRASS)
	h.name = "MvpLabel"
	h.add_theme_font_override(&"font", PaperSheet.head_font())
	h.add_theme_font_size_override(&"font_size", 18)
	box.add_child(h)
	_mvp_card = CodexView.make_card_view(view, MVP_W_COMPACT if compact else MVP_W)
	var holder: Control = Control.new()
	holder.name = "MvpCard"
	holder.custom_minimum_size = CardView.size_for(MVP_W_COMPACT if compact else MVP_W)
	holder.tooltip_text = "%s: long press or right click for the full card" % String(view.get("name", ""))
	holder.add_child(_mvp_card)
	box.add_child(holder)
	if not info.is_empty():
		wire_inspect_control(holder, func() -> void: inspector().open(info))
	var strip: Control = Control.new()
	strip.name = "Band"
	strip.custom_minimum_size = Vector2(_mvp_card.size.x, 12)
	strip.set_meta(&"band", band)
	strip.tooltip_text = "%s band" % MasteryBands.display_name(band)
	strip.draw.connect(func() -> void:
		MasteryBands.draw(strip, Rect2(Vector2.ZERO, strip.size), band)
		strip.draw_rect(Rect2(Vector2.ZERO, strip.size), PaperSheet.KHAKI, false, 1.0))
	wire_inspect_control(strip, func() -> void: inspector().open(MasteryBands.info(band)))
	box.add_child(strip)
	var bl: Label = PaperSheet.ink(make_label(("%s BAND" % MasteryBands.display_name(band).to_upper()) + (("  ·  " + line) if line != "" else "")), PaperSheet.INK_MUTED)
	bl.name = "MvpLine"
	bl.add_theme_font_override(&"font", PaperSheet.mono_font())
	bl.add_theme_font_size_override(&"font_size", 16)
	box.add_child(bl)


func _operator_view(item: LoadoutItem) -> Dictionary:
	return {"name": item.display_name, "type": "operator", "firepower": item.operator_firepower,
			"armor": item.operator_armor, "banner": String(BannerArtDB.operator_art_id(item.id, 1)),
			"text": "Your Operator: respawns if it goes down.", "side": "friend"}


func _operator_info(item: LoadoutItem) -> Dictionary:
	var view: Dictionary = _operator_view(item)
	return {"view": view, "title": item.display_name, "type": "operator · FP %d · Armor %d" % [item.operator_firepower, item.operator_armor],
			"text": item.text, "is_unit": true, "status": ""}


func get_mvp_card() -> Control:
	return _mvp_card


func get_sheet() -> PanelContainer:
	return _sheet


func _apply_compact() -> void:
	if _continue_button != null:
		_continue_button.custom_minimum_size.y = button_height()
	# kc-da-ui2: the stamp and the MVP card follow the profile; portrait stacks the sheet.
	if _result_label != null:
		_result_label.add_theme_font_size_override(&"font_size", 34 if compact else 56)
		_result_label.size = _result_label.get_combined_minimum_size()
	if _sheet_row != null:
		_sheet_row.vertical = portrait
	if _mvp_card != null:
		var w: float = MVP_W_COMPACT if compact else MVP_W
		_mvp_card.set_card_width(w)
		var holder: Control = _mvp_card.get_parent() as Control
		holder.custom_minimum_size = CardView.size_for(w)
		var strip: Control = holder.get_parent().get_node_or_null(^"Band") as Control
		if strip != null:
			strip.custom_minimum_size.x = w


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


## One typed line of the debrief: NAME (mono, muted) · value (bold ink) · note (muted).
func _stat_row(title: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Stat" + title.replace(" ", "").capitalize()
	row.add_theme_constant_override(&"separation", 10)
	row.tooltip_text = title.capitalize()
	_stats.add_child(row)
	var t: Label = PaperSheet.ink(make_label(title), PaperSheet.INK_MUTED)
	t.name = "Name"
	t.add_theme_font_override(&"font", PaperSheet.mono_font())
	t.add_theme_font_size_override(&"font_size", 16)
	t.custom_minimum_size.x = 118
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(t)
	return row


func _stat(title: String, value: String, note: String = "") -> void:
	var row: HBoxContainer = _stat_row(title)
	var v: Label = PaperSheet.ink(make_label(value, &"StatValue"))
	v.name = "Value"
	v.add_theme_font_size_override(&"font_size", 20)
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(v)
	if note != "":
		var n: Label = PaperSheet.ink(make_label(note, &"HudSubtle"), PaperSheet.INK_MUTED)
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(n)


func _tickets_stat(before: int, after: int, total: int) -> void:
	var row: HBoxContainer = _stat_row("TICKETS")
	var v: Label = PaperSheet.ink(make_label("%d/%d" % [after, total], &"StatValue"))
	v.name = "Value"
	v.add_theme_font_size_override(&"font_size", 20)
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(v)
	var pips: HBoxContainer = make_tickets(after, total, Vector2(12, 18))
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pips)
	var n: Label = PaperSheet.ink(make_label("-%d (was %d)" % [before - after, before] if before > after else "no change", &"HudSubtle"),
			PaperSheet.STAMP_LOSS if before > after else PaperSheet.INK_MUTED)
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(n)


## kc-syn-ui: the Honor Roll album page (cosmetic): every card retired this run, with its trait
## and the match it left after. Long-press shows the full list. kc-ipad-cards: no level swatch.
func _honor_roll(col: VBoxContainer, r: RunProgress) -> void:
	if r.honor_roll.is_empty():
		return
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "HonorRoll"
	box.add_theme_constant_override(&"separation", 4)
	col.add_child(box)
	col.move_child(box, _continue_button.get_index())
	var head: Label = PaperSheet.ink(make_label("HONOR ROLL  ·  %d RETIRED" % r.honor_roll.size(), &"HudTag"), PaperSheet.INK_BRASS)
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
		var tr: StringName = StringName(String(h.get("trait", "")))
		sw.draw.connect(func() -> void:
			sw.draw_rect(Rect2(Vector2.ZERO, sw.size), SynergyGlyphs.trait_color(tr) if tr != &"" else Color("#2A3036")))
		hb.add_child(sw)
		var words: String = "%s · after M%d" % [card.display_name if card != null else String(h["id"]), maxi(1, int(h["match"]))]
		hb.add_child(make_label(words))
		row.add_child(p)
	if start > 0:
		row.add_child(make_label("+ %d more" % start, &"HudSubtle"))

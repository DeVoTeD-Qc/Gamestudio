# duel_result.gd
# Purpose: kc-duel-ui. The duel result screen (scenes/duel/DuelResult.tscn, duel-mode.md §7, duel-api.md
#   §6.2 / §7): what happened and what it counted for.
#   - VICTORY / DEFEAT / DRAW vs AI ("DANA WINS" in Pass & Play), with a tick / cross / dash mark, the
#     Zone Control score, the reason and the rounds.
#   - Both sides: deck name and hero (hold / right click: the deck list or the hero kit).
#   - Records: your hero's record, your record vs that preset at that tier, Pass & Play games; anything
#     new ("Duelist frame: Bastion-60") in its own panel.
#   - REMATCH (same decks, new seed) · EDIT DECK (your own saved deck) · DUEL HUB · TITLE.
# Dependencies: run_screen.gd, duel_views.gd, duel_widgets.gd, duel_flow.gd, match_end_banner.gd (reasons).
# Author: UI/UX Agent (kc-duel-ui)
extends "res://scripts/ui/run/run_screen.gd"

const DuelViews: GDScript = preload("res://scripts/ui/duel/duel_views.gd")
const W: GDScript = preload("res://scripts/ui/duel/duel_widgets.gd")
const DuelFlow: GDScript = preload("res://scripts/ui/duel/duel_flow.gd")
const MatchEndBanner: GDScript = preload("res://scripts/ui/match_end_banner.gd")

var _built_portrait: int = -1
var _headline: Label = null


func screen_id() -> StringName:
	return &"duel_result"


func _apply_compact() -> void:
	var want: int = 1 if portrait else 0
	if want != _built_portrait:
		_built_portrait = want
		_rebuild()


func get_headline() -> String:
	return _headline.text if _headline != null else ""


func result() -> Dictionary:
	return DuelFlow.last_result.get("result", {})


func _rebuild() -> void:
	var layout: VBoxContainer = %Layout
	clear(layout)
	var res: Dictionary = result()
	var setup: Dictionary = DuelFlow.last_result.get("setup", DuelFlow.setup)
	var hot: bool = StringName(str(setup.get("mode", ""))) == DuelFlow.MODE_HOT_SEAT or StringName(str(res.get("kind", ""))) == &"hot_seat"
	var names: Array = res.get("names", setup.get("names", ["You", "AI"]))
	var winner: int = int(res.get("winner_side", -1))
	var scores: Array = res.get("scores", [0, 0])
	var word: String = "DRAW"
	var mark: StringName = &"minus"
	var tone: Color = W.FOG
	if hot:
		if winner >= 0:
			word = "%s WINS" % String(names[winner]).to_upper()
			mark = &"tick"
			tone = W.FOG  # kc-da-ui2: no amber labels
	elif winner == 0:
		word = "VICTORY"
		mark = &"tick"
		tone = W.GREEN
	elif winner == 1:
		word = "DEFEAT"
		mark = &"cross"
		tone = W.RED
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var body: VBoxContainer = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 10)
	scroll.add_child(body)
	var head: HBoxContainer = HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override(&"separation", 12)
	body.add_child(head)
	head.add_child(W.Mark.new(mark, tone, 44))
	_headline = W.label(word, &"TitleWordmark", 48 if compact else 64, tone)
	_headline.name = "Headline"
	head.add_child(_headline)
	var why: String = String(MatchEndBanner.REASON_WORDS.get(StringName(str(res.get("reason", ""))), ""))
	var line: String = "Zone Control %d – %d · %d rounds%s" % [int(scores[0]), int(scores[1]), int(res.get("rounds", 0)),
			(" · " + why) if why != "" else ""]
	if not hot and setup.has("tier"):
		line += " · %s" % String(DuelViews.TIER_NAMES.get(StringName(str(setup["tier"])), "")).capitalize()
	var sl: Label = W.label(line, &"HudHeader", 20, W.FOG, true)
	sl.name = "ScoreLine"
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(sl)
	# The two sides.
	var sides: BoxContainer = BoxContainer.new()
	sides.vertical = portrait
	sides.add_theme_constant_override(&"separation", 10)
	body.add_child(sides)
	var decks: Array = setup.get("decks", [])
	for i: int in 2:
		var d: Dictionary = decks[i] if i < decks.size() and decks[i] is Dictionary else {}
		sides.add_child(_side_panel(i, String(names[i]) if i < names.size() else "", d, i == winner, int(scores[i]) if i < scores.size() else 0))
	# Records and anything new.
	var rec_p: PanelContainer = W.panel(Color("#141A1F"), W.PANEL_RIM, 10.0)
	rec_p.name = "Records"
	body.add_child(rec_p)
	var rc: VBoxContainer = VBoxContainer.new()
	rc.add_theme_constant_override(&"separation", 4)
	rec_p.add_child(rc)
	rc.add_child(W.label("RECORDS · Duel gives records and cosmetics only", &"HudTag", 16, W.MUTED))
	var recs: Dictionary = DuelFlow.last_result.get("records", DuelViews.records())
	if hot:
		rc.add_child(W.label("Pass & Play games on this device: %d" % int(recs.get("hot_seat_games", 0)), &"", 17))
	else:
		var hero_id: StringName = StringName(str((decks[0] as Dictionary).get("hero", ""))) if decks.size() > 0 else &""
		var h: Dictionary = DuelViews.hero(hero_id)
		var hr: Dictionary = (recs.get("heroes", {}) as Dictionary).get(hero_id, (recs.get("heroes", {}) as Dictionary).get(String(hero_id), {}))
		if not h.is_empty():
			rc.add_child(W.label("%s: %s" % [h["name"], DuelViews.record_text(hr)], &"", 17))
		var opp: String = String(setup.get("opponent_id", ""))
		var by_tier: Dictionary = (recs.get("vs_ai", {}) as Dictionary).get(opp, {})
		var tier: StringName = StringName(str(setup.get("tier", "")))
		var tr: Dictionary = by_tier.get(tier, by_tier.get(String(tier), {}))
		if opp != "" and opp != "random":
			rc.add_child(W.label("You vs %s on %s: %s" % [DuelViews.preset(opp).get("name", opp), String(DuelViews.TIER_NAMES.get(tier, "")).capitalize(), DuelViews.record_text(tr)], &"", 17))
	for c: Dictionary in DuelFlow.last_result.get("new_cosmetics", []):
		var np: PanelContainer = W.panel(W.STEEL_BG, W.PANEL_RIM, 8.0)  # kc-da-ui2: steel, not amber
		np.name = "NewCosmetic"
		var nr: HBoxContainer = HBoxContainer.new()
		nr.add_theme_constant_override(&"separation", 8)
		np.add_child(nr)
		nr.add_child(W.label("NEW", &"HudTag", 16, W.FOG))
		nr.add_child(W.label("%s · %s" % [c.get("name", ""), c.get("text", "")], &"", 17, W.FOG, true))
		(nr.get_child(1) as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(np)
	# Actions.
	var acts: GridContainer = GridContainer.new()
	acts.name = "Actions"
	acts.columns = 2 if portrait else 4
	acts.add_theme_constant_override(&"h_separation", 8)
	acts.add_theme_constant_override(&"v_separation", 8)
	layout.add_child(acts)
	var again: Button = _act("REMATCH", &"ReadyButton", acts)
	again.name = "RematchButton"
	again.tooltip_text = "The same decks and difficulty, a new shuffle"
	again.pressed.connect(func() -> void:
		var r: Dictionary = DuelFlow.rematch()
		if not bool(r["ok"]):
			show_feedback(String(r["text"]), &""))
	var own: Dictionary = decks[0] if decks.size() > 0 and decks[0] is Dictionary else {}
	if not hot and not own.is_empty() and not bool(own.get("preset", false)):
		var ed: Button = _act("EDIT DECK", &"HudButton", acts)
		ed.name = "EditDeckButton"
		ed.pressed.connect(func() -> void:
			var saved: Dictionary = DuelViews.saved_deck(String(own.get("id", "")))
			DuelFlow.open_builder(saved if not saved.is_empty() else own, DuelFlow.SCENE_HUB))
	var hub: Button = _act("DUEL HUB", &"HudButton", acts)
	hub.name = "HubButton"
	hub.pressed.connect(func() -> void: goto(DuelFlow.SCENE_HUB))
	var title: Button = _act("TITLE", &"HudButton", acts)
	title.name = "TitleButton"
	title.pressed.connect(func() -> void: goto(DuelFlow.SCENE_TITLE))
	again.grab_focus.call_deferred()


func _act(text: String, variation: StringName, parent: Control) -> Button:
	var b: Button = make_button(text, variation, 0)
	b.add_to_group(&"tap_target")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	parent.add_child(b)
	return b


func _side_panel(i: int, who: String, d: Dictionary, won: bool, score: int) -> PanelContainer:
	var p: PanelContainer = W.panel(Color("#161C21"), W.FOG if won else W.PANEL_RIM, 10.0)  # kc-da-ui2: steel white, not amber
	p.name = "Side%d" % i
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	p.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	col.add_child(top)
	var nm: Label = W.label(who.to_upper(), &"TileName", 22)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	top.add_child(W.label("%d PTS" % score, &"HudNumber", 22, W.FOG if won else W.MUTED))
	col.add_child(W.label("Deck: %s" % d.get("name", "?"), &"", 17))
	var h: Dictionary = DuelViews.hero(StringName(str(d.get("hero", ""))))
	if not h.is_empty():
		col.add_child(W.label("Hero: %s · FP %d / Armor %d" % [h["name"], h["fp"], h["armor"]], &"HudSubtle", 16))
	if won:
		col.add_child(W.status_chip("WON", true))
	wire_inspect_control(p, func() -> void:
		if not h.is_empty():
			inspector().open(W.hero_info(h, "%s's hero in this duel (deck %s)." % [who, d.get("name", "?")])), true)
	p.tooltip_text = "%s · tap / hold: the hero" % who
	return p

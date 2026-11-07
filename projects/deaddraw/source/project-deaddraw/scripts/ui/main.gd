# main.gd
# Purpose: The whole DeadDraw prototype UI: title (survivor pick), city map, street, safehouse
#   and run-end screens. Rebuilt from the run state after every action, laid out for portrait
#   (2x2 street) or landscape (1x4 street) from the viewport aspect. Rules live in DDRun; this
#   script only renders state, previews outcomes and calls the run's public methods.
#   dd-feel: before each action it snapshots the street (card rects, HP, weapon); after the
#   rebuild scripts/fx/dd_feedback.gd animates from the old picture to the new one (deal, flip,
#   resolve feedback, retreat, holdover, finale, death). Card art from the manifest
#   (scripts/ui/dd_art.gd) is put on tiles via spec "art_keys". Settings overlay: dd_settings_panel.gd.
# Dependencies: Game (autoload), DDRun, DDPayloads, DDCardView, DDInspect, DDUi, DDText,
#   scripts/fx/dd_feedback.gd, scripts/fx/dd_sfx.gd, scripts/ui/dd_art.gd, scripts/ui/dd_settings_panel.gd.
# Author: Mechanics Developer Agent (feel pass: Game Feel Engineer Agent)
extends Control

const Feedback: GDScript = preload("res://scripts/fx/dd_feedback.gd")
const Sfx: GDScript = preload("res://scripts/fx/dd_sfx.gd")
const Art: GDScript = preload("res://scripts/ui/dd_art.gd")
const SettingsPanel: GDScript = preload("res://scripts/ui/dd_settings_panel.gd")

enum Screen { TITLE, MAP, STREET, SAFEHOUSE, END }

const MARGIN: int = 16
const SEP: int = 10

var screen: Screen = Screen.TITLE
var selected: int = -1
var chosen_survivor: String = "rosa"
var chosen_perk: String = ""
var portrait: bool = true
var busy: bool = false
var last_event: Dictionary = {}
var safehouse_info: Dictionary = {}

var _content: MarginContainer
var _fx: Control
var _inspect: DDInspect
var _hp_anchor: Control = null
var _weapon_anchor: Control = null
var _auto_inspect: Dictionary = {}
## dd-feel
var feedback: Node
var settings_panel: Control
var _pending_fx: Dictionary = {}
var _screen_fx: String = ""
var _street_views: Dictionary = {}   # card instance id -> DDCardView
var _street_specs: Dictionary = {}   # card instance id -> tile spec
var _street_cards: Dictionary = {}   # card instance id -> DDCard
var _street_order: Array = []
var _deck_anchor: Control = null
var _finale_anchor: Control = null
var _cover_anchor: Control = null
var _hp_box: Control = null
var _hp_label: Label = null
var _hp_bar: ProgressBar = null
var _screen_title: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = DDUi.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_content = MarginContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		_content.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(_content)
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)
	_inspect = DDInspect.new()
	add_child(_inspect)
	settings_panel = SettingsPanel.new()
	settings_panel.name = "Settings"
	add_child(settings_panel)
	feedback = Feedback.new()
	feedback.name = "Feedback"
	add_child(feedback)
	feedback.setup(_fx, _content)
	_sync_feel()
	Game.settings_changed.connect(func(_k: String, _v: Variant) -> void: _sync_feel())
	if OS.has_feature("web"):
		_inspect.opened.connect(_publish_state)
		_inspect.closed.connect(_publish_state)
		settings_panel.opened.connect(_publish_state)
		settings_panel.closed.connect(_publish_state)
	var saved: String = Game.survivor_id
	chosen_survivor = saved if Game.profile.survivor_unlocked(saved) else "rosa"
	get_viewport().size_changed.connect(_render)
	_apply_smoke_query()
	_render()


# ================================================================ rendering
func _sync_feel() -> void:
	feedback.reduce = Game.reduce_motion()
	feedback.shake_on = Game.screen_shake()


func open_settings() -> void:
	settings_panel.open()


func _render() -> void:
	for c: Node in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	feedback.clear()
	_hp_anchor = null
	_weapon_anchor = null
	_deck_anchor = null
	_finale_anchor = null
	_cover_anchor = null
	_hp_box = null
	_hp_label = null
	_hp_bar = null
	_screen_title = null
	_street_views = {}
	_street_specs = {}
	_street_cards = {}
	_street_order = []
	var vp: Vector2 = get_viewport_rect().size
	portrait = vp.y >= vp.x
	match screen:
		Screen.TITLE:
			_build_title()
		Screen.MAP:
			_build_map()
		Screen.STREET:
			_build_street()
		Screen.SAFEHOUSE:
			_build_safehouse()
		Screen.END:
			_build_end()
	if not _pending_fx.is_empty() or _screen_fx != "":
		var pend: Dictionary = _pending_fx
		var sfx: String = _screen_fx
		_pending_fx = {}
		_screen_fx = ""
		_play_fx.call_deferred(pend, sfx)
	if not _auto_inspect.is_empty():
		var p: Dictionary = _auto_inspect
		_auto_inspect = {}
		_inspect.open.call_deferred(p)
	if OS.has_feature("web"):
		_publish_state.call_deferred()


var _render_queued: bool = false
var _perk_popped: String = ""


## Re-render at the end of the frame: handlers run inside a Button's signal, and freeing the
## pressed Button synchronously makes the engine complain.
func _queue_render() -> void:
	if _render_queued:
		return
	_render_queued = true
	(func() -> void:
		_render_queued = false
		_render()).call_deferred()


## dd-feel: the feedback for the last action, once the new layout has settled.
func _play_fx(pend: Dictionary, screen_fx: String) -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_sync_feel()
	if not pend.is_empty() and screen == Screen.STREET:
		feedback.play(pend, _fx_context())
	match screen_fx:
		"end_won":
			Sfx.cue(&"win")
			feedback.title_slam(_screen_title, true)
		"end_dead":
			feedback.title_slam(_screen_title, false)
		"safehouse":
			feedback.title_slam(_screen_title, true)
		"map":
			if _finale_anchor != null:
				feedback._pop(_finale_anchor, 1.05, DDUi.accent("F"))


func _fx_context() -> Dictionary:
	var run: DDRun = Game.run
	return {"street": _street_views, "specs": _street_specs, "cards": _street_cards, "order": _street_order,
		"deck": _deck_anchor, "weapon": _weapon_anchor, "finale": _finale_anchor, "cover": _cover_anchor,
		"hp_panel": _hp_anchor, "hp_box": _hp_box, "hp_label": _hp_label, "hp_bar": _hp_bar,
		"hp": run.hp if run != null else 0, "max_hp": run.max_hp if run != null else 0}


## dd-feel: what the street looks like right before an action (for the feedback animations).
func _snapshot() -> Dictionary:
	var run: DDRun = Game.run
	var rects: Dictionary = {}
	for id: Variant in _street_views:
		var v: DDCardView = _street_views[id]
		if is_instance_valid(v) and v.is_inside_tree():
			rects[id] = v.get_global_rect()
	return {"rects": rects, "specs": _street_specs.duplicate(), "hp": run.hp, "cover": run.cover,
		"weapon": run.weapon, "notch": run.notch,
		"deck_rect": _deck_anchor.get_global_rect() if _deck_anchor != null and is_instance_valid(_deck_anchor) else Rect2()}


func _view(spec: Dictionary, min_size: Vector2 = Vector2.ZERO) -> DDCardView:
	var v: DDCardView = DDCardView.new()
	if spec.has("art_keys"):
		var tex: Texture2D = Art.texture_for(spec["art_keys"])
		if tex != null:
			spec["art"] = tex
			if spec.get("payload", null) is Dictionary and not (spec["payload"] as Dictionary).is_empty():
				spec["payload"]["art"] = tex
	v.setup(spec)
	v.custom_minimum_size = min_size
	v.inspected.connect(_on_inspect)
	return v


func _on_inspect(payload: Dictionary) -> void:
	_inspect.open(payload)


func _scroll(child: Control) -> ScrollContainer:
	var s: ScrollContainer = ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


# ---------------------------------------------------------------- title
func _build_title() -> void:
	var v: VBoxContainer = DDUi.vbox(14 if portrait else 8)
	_content.add_child(_scroll(v))
	var t: Label = DDUi.label("DEADDRAW", 64 if portrait else 40, DDUi.accent("Z"), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(t)
	if portrait:
		v.add_child(DDUi.label("Every street deals four cards. You deal with three.\nThe fourth is waiting for you on the next one.", DDUi.FONT_M, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
		v.add_child(DDUi.label("Pick a survivor  (long press / right click to read)", DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	else:
		# landscape: one line of text so the Start row stays clear of the bottom edge
		v.add_child(DDUi.label("Every street deals four cards. You deal with three. Pick a survivor (long press / right click to read).", DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	var row: HBoxContainer = DDUi.hbox(SEP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var vp: Vector2 = get_viewport_rect().size
	var w: float = minf(230.0, (vp.x - MARGIN * 2 - SEP * 2) / 3.0)
	# landscape: what is left after the title, the text line and the Start row (+ a bottom gap)
	var card_h: float = 220.0 if portrait else clampf(vp.y - MARGIN * 2 - 52.0 - 30.0 - DDUi.TAP_MIN - 8.0 * 3 - 12.0, 120.0, 230.0)
	for sid: String in Game.bal.survivor_ids():
		var unlocked: bool = Game.profile.survivor_unlocked(sid)
		var s: Dictionary = Game.bal.survivor(sid)
		var lines: Array = [[str(s.get("role", "")), DDUi.TEXT_DIM, DDUi.FONT_S],
			[DDText.passive_name(str(s.get("passive", ""))), DDUi.accent("S"), DDUi.FONT_S]]
		if unlocked:
			lines.append(["Best %d" % Game.profile.best_score(sid), DDUi.TEXT, DDUi.FONT_S])
		else:
			lines.append([DDPayloads.unlock_hint(Game.profile.unlock_milestone_for("survivor:" + sid), Game.bal).capitalize() + " to unlock", DDUi.WARN, DDUi.FONT_S])
		var marks: int = Game.profile.badges(sid)
		var spec: Dictionary = {"kind": "S", "tag": "%d HP" % Game.bal.survivor_max_hp(sid),
			"badge": ("MARK x%d" % marks) if marks > 0 else ("LOCKED" if not unlocked else ""),
			"badge_color": DDUi.GOOD if marks > 0 else DDUi.TEXT_DIM,
			"big": sid.substr(0, 1).to_upper(), "big_size": 56,
			"title": str(s.get("name", sid)), "lines": lines, "selected": sid == chosen_survivor,
			"dim": not unlocked, "payload": DDPayloads.survivor(sid, Game.bal, Game.profile),
			"art_keys": Art.survivor_keys(sid)}
		var cv: DDCardView = _view(spec, Vector2(w, card_h))
		cv.tapped.connect(func(_x: DDCardView) -> void:
			if unlocked:
				if chosen_survivor != sid:
					Sfx.cue(&"flip")
				chosen_survivor = sid
				_queue_render()
			else:
				_inspect.open(DDPayloads.survivor(sid, Game.bal, Game.profile)))
		row.add_child(cv)
	var go: Button = DDUi.button("Start run as %s" % str(Game.bal.survivor(chosen_survivor).get("name", "")), Color("7a2d27"), DDUi.FONT_L)
	go.custom_minimum_size = Vector2(0, 88 if portrait else DDUi.TAP_MIN)
	go.pressed.connect(_start_run)
	var h: HBoxContainer = DDUi.hbox(SEP)
	if portrait:
		v.add_child(go)
	else:
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.size_flags_stretch_ratio = 2.0
		h.add_child(go)
	v.add_child(h)
	var how: Button = DDUi.button("How to play")
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	how.pressed.connect(func() -> void: _inspect.open(DDPayloads.how_to_play(Game.bal)))
	h.add_child(how)
	var pool: Array[String] = Game.profile.perk_pool()
	var pb: Button = DDUi.button("Perk pool %d/%d" % [pool.size(), Game.bal.all_perks().size()])
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.pressed.connect(_show_pool)
	h.add_child(pb)
	h.add_child(_settings_button())


func _settings_button(small: bool = false) -> Button:
	var b: Button = DDUi.button("Settings", DDUi.PANEL if small else DDUi.PANEL_HI, DDUi.FONT_S if small else DDUi.FONT_M)
	b.name = "SettingsButton"
	if small:
		b.custom_minimum_size = Vector2(120, 56)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.size_flags_vertical = Control.SIZE_SHRINK_END
	else:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(open_settings)
	return b


func _show_pool() -> void:
	var lines: PackedStringArray = []
	for p: String in Game.bal.all_perks():
		if Game.profile.perk_unlocked(p):
			lines.append("%s: %s" % [DDText.perk_name(p), DDText.perk_text(p, Game.bal)])
		else:
			lines.append("LOCKED %s (%s)" % [DDText.perk_name(p), DDPayloads.unlock_hint(Game.profile.unlock_milestone_for("perk:" + p), Game.bal)])
	_inspect.open({"kind": "P", "tag": "PERK POOL", "title": "Safehouse perks", "body": "\n".join(lines)})


func _start_run() -> void:
	Game.start_run(chosen_survivor)
	selected = -1
	last_event = {}
	screen = Screen.MAP
	_queue_render()


# ---------------------------------------------------------------- map
func _build_map() -> void:
	var run: DDRun = Game.run
	var v: VBoxContainer = DDUi.vbox(12)
	_content.add_child(_scroll(v))
	v.add_child(DDUi.label("THE CITY", DDUi.FONT_XL if portrait else DDUi.FONT_L, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(DDUi.label("District %d of %d. Each Finale is face up: plan for it." % [run.district_index + 1, Game.bal.district_count()], DDUi.FONT_M, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	var path: BoxContainer = BoxContainer.new()
	path.vertical = portrait
	path.add_theme_constant_override("separation", SEP)
	path.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(path)
	var vp: Vector2 = get_viewport_rect().size
	for di: int in Game.bal.district_count():
		var d: Dictionary = Game.bal.district(di)
		var status: String = "CLEARED" if di < run.district_index else ("NEXT" if di == run.district_index else "")
		var spec: Dictionary = DDPayloads.finale_spec(d, false, status)
		spec["tag"] = "%d  %s" % [di + 1, str(d.get("name", "")).to_upper()]
		spec["selected"] = di == run.district_index
		spec["dim"] = di < run.district_index
		var banner: Texture2D = Art.texture_for(Art.district_keys(d))
		if banner != null:
			spec["bg_art"] = banner
		spec["art_keys"] = Art.finale_keys(d)
		var size: Vector2 = Vector2(vp.x - MARGIN * 2, 150) if portrait else Vector2(minf(300.0, (vp.x - MARGIN * 2 - SEP * 2) / 3.0), 170)
		var dv: DDCardView = _view(spec, size)
		if di == run.district_index:
			_finale_anchor = dv
		path.add_child(dv)
	var bottom: BoxContainer = BoxContainer.new()
	bottom.vertical = portrait
	bottom.add_theme_constant_override("separation", SEP)
	v.add_child(bottom)
	var st: Control = _status_line(run)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(st)
	var go: Button = DDUi.button("Enter %s" % str(run.district().get("name", "")), Color("7a2d27"), DDUi.FONT_L)
	go.custom_minimum_size = Vector2(0, 88)
	go.pressed.connect(func() -> void:
		screen = Screen.STREET
		selected = -1
		_pending_fx = {"type": "deal", "snap": {}, "ev": {}}
		_queue_render())
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(go)
	var sb: Button = _settings_button(true)
	sb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(sb)


func _status_line(run: DDRun) -> Control:
	var h: HFlowContainer = HFlowContainer.new()
	h.add_theme_constant_override("h_separation", SEP)
	h.add_theme_constant_override("v_separation", SEP)
	h.alignment = FlowContainer.ALIGNMENT_CENTER
	var s: Dictionary = Game.bal.survivor(run.survivor_id)
	h.add_child(_view({"kind": "S", "tag": "SURVIVOR", "title": str(s.get("name", "")), "lines": [["HP %d / %d" % [run.hp, run.max_hp], DDUi.GOOD, DDUi.FONT_M]], "compact": true,
		"payload": DDPayloads.survivor(run.survivor_id, Game.bal, Game.profile)}, Vector2(190, 0)))
	h.add_child(_view(_weapon_spec(run), Vector2(170, 0)))
	for p: String in run.perks:
		h.add_child(_view(DDPayloads.perk_spec(p, Game.bal, true), Vector2(150, 0)))
	return h


func _weapon_spec(run: DDRun) -> Dictionary:
	var ws: Dictionary = DDPayloads.weapon_slot_spec(run)
	if run.weapon > 0:
		ws["art_keys"] = Art.card_keys(DDCard.make(DDCard.WEAPON, run.weapon))
	return ws


# ---------------------------------------------------------------- street
func _build_street() -> void:
	var run: DDRun = Game.run
	var vp: Vector2 = get_viewport_rect().size
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2 if portrait else 4
	grid.add_theme_constant_override("h_separation", SEP)
	grid.add_theme_constant_override("v_separation", SEP)
	var side_w: float = clampf(vp.x * 0.27, 260.0, 340.0)
	var card_w: float
	var card_h: float
	if portrait:
		card_w = (vp.x - MARGIN * 2 - SEP) / 2.0
		card_h = clampf((vp.y - 770.0) / 2.0, 180.0, card_w * 1.3)
	else:
		card_w = (vp.x - MARGIN * 2 - side_w - SEP - SEP * 3) / 4.0
		card_h = clampf(vp.y - MARGIN * 2 - 290.0, 170.0, card_w * 1.4)
	for i: int in run.street.size():
		var c: DDCard = run.street[i]
		var spec: Dictionary = DDPayloads.street_card_spec(c, i, run, i == selected)
		spec["art_keys"] = Art.card_keys(c, str(run.district().get("id", "")))
		spec["holdover"] = c.holdover and str(spec.get("badge", "")) == "HOLDOVER"
		if spec["holdover"]:
			spec["badge"] = ""
		var cv: DDCardView = _view(spec, Vector2(card_w, card_h))
		cv.index = i
		cv.tapped.connect(_on_card_tapped)
		grid.add_child(cv)
		var cid: int = c.get_instance_id()
		_street_views[cid] = cv
		_street_specs[cid] = spec
		_street_cards[cid] = c
		_street_order.append(cid)
	var actions: Control = _build_actions(run)
	var log_box: Control = _build_log(run)
	var hp_box: Control = _build_hp(run)
	var info: HBoxContainer = DDUi.hbox(SEP)
	var big_s: int = 44 if portrait else 30
	var ws: Dictionary = _weapon_spec(run)
	ws["big_size"] = big_s
	var wv: DDCardView = _view(ws)
	wv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_anchor = wv
	info.add_child(wv)
	var ds: Dictionary = DDPayloads.deck_spec(run)
	ds["big_size"] = big_s
	ds["art_keys"] = Art.back_keys()
	ds["art_tint"] = 0.82   # dd-polish: the card back is busy; the count must read
	var dv: DDCardView = _view(ds)
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_anchor = dv
	info.add_child(dv)
	var fs: Dictionary = DDPayloads.finale_spec(run.district())
	fs["big_size"] = big_s
	fs["art_keys"] = Art.finale_keys(run.district())
	var fv: DDCardView = _view(fs)
	fv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_finale_anchor = fv
	info.add_child(fv)
	var perks: HFlowContainer = HFlowContainer.new()
	perks.add_theme_constant_override("h_separation", 6)
	perks.add_theme_constant_override("v_separation", 6)
	for p: String in run.perks:
		perks.add_child(_view(DDPayloads.perk_spec(p, Game.bal, true)))
	var where: Label = DDUi.label("%s  -  street %d%s" % [str(run.district().get("name", "")), run.streets_played + 1, "  -  FINALE" if run.finale_in else ""], DDUi.FONT_S, DDUi.TEXT_DIM)
	if portrait:
		var v: VBoxContainer = DDUi.vbox(SEP)
		_content.add_child(v)
		v.add_child(hp_box)
		v.add_child(where)
		v.add_child(info)
		if run.perks.size() > 0:
			v.add_child(perks)
		var gc: CenterContainer = CenterContainer.new()
		gc.add_child(grid)
		v.add_child(gc)
		v.add_child(actions)
		log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(log_box)
	else:
		var h: HBoxContainer = DDUi.hbox(SEP)
		_content.add_child(h)
		var side: VBoxContainer = DDUi.vbox(SEP)
		side.custom_minimum_size = Vector2(side_w, 0)
		h.add_child(side)
		side.add_child(hp_box)
		side.add_child(where)
		var info2: GridContainer = GridContainer.new()
		info2.columns = 2
		info2.add_theme_constant_override("h_separation", SEP)
		info2.add_theme_constant_override("v_separation", SEP)
		for c: Node in info.get_children():
			info.remove_child(c)
			info2.add_child(c)
		info.queue_free()
		side.add_child(info2)
		if run.perks.size() > 0:
			side.add_child(perks)
		var main: VBoxContainer = DDUi.vbox(SEP)
		main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(main)
		main.add_child(grid)
		main.add_child(actions)
		log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		main.add_child(log_box)


func _build_hp(run: DDRun) -> Control:
	var h: HBoxContainer = DDUi.hbox(SEP)
	var sv: DDCardView = _view({"kind": "S", "tag": run.survivor_id.to_upper(),
		"title": DDText.passive_name(run.passive), "compact": true,
		"payload": DDPayloads.survivor(run.survivor_id, Game.bal, Game.profile)}, Vector2(120, 0))
	h.add_child(sv)
	var hp_panel: PanelContainer = DDUi.panel(DDUi.PANEL, 10)
	hp_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hv: VBoxContainer = DDUi.vbox(4)
	hp_panel.add_child(hv)
	var col: Color = DDUi.GOOD if run.hp * 2 > run.max_hp else (DDUi.WARN if run.hp * 4 > run.max_hp else DDUi.BAD)
	_hp_label = DDUi.label("HP  %d / %d" % [run.hp, run.max_hp], DDUi.FONT_L, col)
	hv.add_child(_hp_label)
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = run.max_hp
	bar.value = run.hp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.add_theme_stylebox_override("background", DDUi.box(Color("0d0f10"), Color(0, 0, 0, 0), 0, 6, 0))
	bar.add_theme_stylebox_override("fill", DDUi.box(col, Color(0, 0, 0, 0), 0, 6, 0))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hv.add_child(bar)
	_hp_bar = bar
	h.add_child(hp_panel)
	_hp_anchor = hp_panel
	_hp_box = h
	if run.cover > 0:
		var cov: DDCardView = _view({"kind": "B", "tag": "COVER", "big": str(run.cover), "big_size": 36, "compact": true,
			"payload": DDPayloads.cover(run)}, Vector2(84, 0))
		_cover_anchor = cov
		h.add_child(cov)
	return h


func _build_actions(run: DDRun) -> Control:
	var p: PanelContainer = DDUi.panel(DDUi.PANEL, 10)
	var v: VBoxContainer = DDUi.vbox(8)
	p.add_child(v)
	var left: int = run.cards_left_to_resolve()
	var prompt: String
	if selected >= 0 and selected < run.street.size():
		prompt = "%s %d: choose how to resolve it." % [DDText.card_name(run.street[selected]), run.street[selected].value]
	elif run.finale_in:
		prompt = "FINALE: resolve every card (%d left). Tap a card." % left
	elif run.resolved_count == 0:
		prompt = "Search: tap a card to resolve (%d to go)%s." % [left, ", or Retreat" if run.can_retreat() else ""]
	else:
		prompt = "Keep going: %d more card%s this street." % [left, "" if left == 1 else "s"]
	v.add_child(DDUi.label(prompt, DDUi.FONT_M, DDUi.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	var row: HBoxContainer = DDUi.hbox(SEP)
	v.add_child(row)
	if selected >= 0 and selected < run.street.size():
		for ch: String in run.choices_for(selected):
			var pr: Dictionary = run.preview(selected, ch)
			var b: Button = DDUi.button(_choice_label(run, run.street[selected], ch, pr), _choice_color(ch, pr))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.disabled = not bool(pr["enabled"]) or busy
			var idx: int = selected
			b.pressed.connect(func() -> void: _do_resolve(idx, ch))
			row.add_child(b)
	else:
		var rb: Button
		if run.can_slip_away():
			rb = DDUi.button("Slip Away: send the other %d back" % run.street.size(), Color("3c3550"))
			rb.pressed.connect(_do_slip)
		else:
			var why: String = run.retreat_block_reason()
			rb = DDUi.button("Retreat (cards to the bottom)" if why == "" else "Retreat - not available, %s" % why, Color("3c3550"))
			rb.disabled = why != "" or busy
			rb.pressed.connect(_do_retreat)
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rb)
	return p


func _choice_label(run: DDRun, c: DDCard, ch: String, pr: Dictionary) -> String:
	match ch:
		DDRun.BARE:
			return "Bare-handed: -%d HP%s" % [int(pr["hp_loss"]), _fate(pr)]
		DDRun.WEAPON:
			if run.weapon == 0:
				return "Weapon: you have none"
			if not bool(pr["enabled"]):
				return "%s: %s" % [DDText.weapon_name(run.weapon), str(pr["reason"])]
			var tail: String = "weapon breaks (Shatter)" if bool(pr["breaks"]) else "notch becomes %d" % int(pr["notch_after"])
			return "%s: -%d HP%s (%s)" % [DDText.weapon_name(run.weapon), int(pr["hp_loss"]), _fate(pr), tail]
		DDRun.EQUIP:
			return "Equip %s (%d)" % [DDText.weapon_name(c.value), c.value] + ("\nreplaces %s" % DDText.weapon_name(run.weapon) if run.weapon > 0 else "")
		DDRun.SCRAP:
			return "Scrap it" + ("\nkeep %s" % DDText.weapon_name(run.weapon) if run.weapon > 0 else "")
		DDRun.USE:
			if c.kind == DDCard.MEDKIT:
				if bool(pr["wasted"]):
					return "Use: won't heal"
				if int(pr["heal"]) <= 0:
					return "Use: you're at full HP,\nthis medkit heals nothing"
				return "Use: +%d HP" % int(pr["heal"])
			return "Take cover: +%d" % int(pr["cover_gain"])
	return ch


func _fate(pr: Dictionary) -> String:
	if bool(pr["dies"]):
		return "  YOU DIE"
	if bool(pr["second_wind"]):
		return " (Second Wind)"
	if int(pr["absorbed"]) > 0:
		return " (Cover %d)" % int(pr["absorbed"])
	return ""


func _choice_color(ch: String, pr: Dictionary) -> Color:
	if bool(pr.get("dies", false)):
		return Color("6b1f1a")
	if ch == DDRun.USE and str(pr.get("kind", "")) == DDCard.MEDKIT and (bool(pr.get("wasted", false)) or int(pr.get("heal", 0)) <= 0):
		return Color("5a4a1f")
	match ch:
		DDRun.WEAPON:
			return Color("1f4a63")
		DDRun.EQUIP:
			return Color("1f4a63")
		DDRun.BARE:
			return Color("5a2a26")
		DDRun.USE:
			return Color("245236")
	return DDUi.PANEL_HI


func _build_log(run: DDRun) -> Control:
	var p: PanelContainer = DDUi.panel(Color("111416"), 10)
	var v: VBoxContainer = DDUi.vbox(4)
	p.add_child(v)
	var n: int = run.log_lines.size()
	var main_text: String = str(last_event.get("text", "")) if not last_event.is_empty() else (run.log_lines[n - 1] if n > 0 else "")
	var col: Color = DDUi.TEXT
	var d: int = int(last_event.get("hp_delta", 0))
	if d < 0:
		col = DDUi.BAD
	elif d > 0:
		col = DDUi.GOOD
	v.add_child(DDUi.label(main_text, DDUi.FONT_M, col, HORIZONTAL_ALIGNMENT_LEFT, true))
	# what else happened (holdover, new street, finale) since the main line
	var extra: PackedStringArray = []
	var start: int = int(last_event.get("_log_from", n))
	for k: int in range(start, n):
		if run.log_lines[k] != main_text:
			extra.append(run.log_lines[k])
	if not extra.is_empty():
		v.add_child(DDUi.label(" ".join(extra), DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true))
	var btn: Button = DDUi.button("Log", DDUi.PANEL, DDUi.FONT_S)
	btn.custom_minimum_size = Vector2(120, 56)
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	btn.size_flags_vertical = Control.SIZE_SHRINK_END
	btn.pressed.connect(func() -> void:
		var lines: Array[String] = run.log_lines.slice(maxi(0, n - 14))
		_inspect.open({"kind": "D", "tag": "WHAT HAPPENED", "title": "Recent events", "body": "\n".join(lines)}))
	var brow: HBoxContainer = DDUi.hbox(SEP)
	brow.alignment = BoxContainer.ALIGNMENT_END
	brow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	brow.add_child(_settings_button(true))
	brow.add_child(btn)
	v.add_child(brow)
	return p


func _on_card_tapped(v: DDCardView) -> void:
	if busy:
		return
	selected = -1 if selected == v.index else v.index
	Sfx.cue(&"button", 0.8 if selected >= 0 else 0.7)
	_queue_render()


func _do_resolve(i: int, ch: String) -> void:
	if busy:
		return
	var run: DDRun = Game.run
	var from: int = run.log_lines.size()
	var wn: Array = [run.weapon, run.notch]
	var snap: Dictionary = _snapshot()
	var ev: Dictionary = run.resolve(i, ch)
	if not bool(ev.get("ok", false)):
		return
	ev["_log_from"] = from
	ev["_wn"] = wn
	last_event = ev
	selected = -1
	_pending_fx = {"type": "resolve", "ev": ev, "snap": snap}
	_after_event(ev)


func _do_retreat() -> void:
	var run: DDRun = Game.run
	var from: int = run.log_lines.size()
	var snap: Dictionary = _snapshot()
	var ev: Dictionary = run.retreat()
	if bool(ev.get("ok", false)):
		ev["_log_from"] = from
		last_event = ev
		selected = -1
		_pending_fx = {"type": "retreat", "ev": ev, "snap": snap}
		_after_event(ev)


func _do_slip() -> void:
	var run: DDRun = Game.run
	var from: int = run.log_lines.size()
	var snap: Dictionary = _snapshot()
	var ev: Dictionary = run.slip_away()
	if bool(ev.get("ok", false)):
		ev["_log_from"] = from
		last_event = ev
		selected = -1
		_pending_fx = {"type": "retreat", "ev": ev, "snap": snap}
		_after_event(ev)


func _after_event(ev: Dictionary) -> void:
	var run: DDRun = Game.run
	if run.phase == DDRun.Phase.DEAD or run.phase == DDRun.Phase.WON or run.phase == DDRun.Phase.SAFEHOUSE:
		busy = true
		_queue_render()
		_float_hp(int(ev.get("hp_delta", 0)))
		# the death / clear moment plays on the street first (input is held only for this beat)
		await get_tree().create_timer(0.9).timeout
		busy = false
		if run.phase == DDRun.Phase.SAFEHOUSE:
			safehouse_info = {"district": str(Game.bal.district(run.district_index).get("name", "")),
				"score": run.district_scores[run.district_scores.size() - 1]}
			chosen_perk = ""
			screen = Screen.SAFEHOUSE
			_screen_fx = "safehouse"
		else:
			screen = Screen.END
			_screen_fx = "end_won" if run.phase == DDRun.Phase.WON else "end_dead"
			if not Game.new_unlocks.is_empty():
				_auto_inspect = DDPayloads.unlock(Game.new_unlocks[0], Game.bal, Game.profile)
		_queue_render()
		return
	_queue_render()
	_float_hp(int(ev.get("hp_delta", 0)))


func _float_hp(delta: int) -> void:
	if delta == 0 or _hp_anchor == null:
		return
	await get_tree().process_frame
	if _hp_anchor == null or not is_instance_valid(_hp_anchor):
		return
	var l: Label = DDUi.label(("%+d HP" % delta), 44, DDUi.GOOD if delta > 0 else DDUi.BAD)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_fx.add_child(l)
	var r: Rect2 = _hp_anchor.get_global_rect()
	l.position = Vector2(r.position.x + r.size.x * 0.5 - 60, r.end.y - 10)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 60, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


# ---------------------------------------------------------------- safehouse
func _build_safehouse() -> void:
	var run: DDRun = Game.run
	var v: VBoxContainer = DDUi.vbox(12)
	_content.add_child(_scroll(v))
	var head: Label = DDUi.label("%s CLEARED" % str(safehouse_info.get("district", "")).to_upper(), DDUi.FONT_XL, DDUi.GOOD, HORIZONTAL_ALIGNMENT_CENTER, true)
	_screen_title = head
	v.add_child(head)
	v.add_child(DDUi.label("District score %d  -  run score %d" % [int(safehouse_info.get("score", 0)), run.run_score()], DDUi.FONT_M, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(DDUi.label("SAFEHOUSE: you rest and heal up to %d HP. Now HP %d / %d. You keep your %s%s." % [
		run.safehouse_healed(), run.hp, run.max_hp, DDText.weapon_name(run.weapon).to_lower() if run.weapon > 0 else "bare hands",
		(" (" + DDText.notch_tag(run.notch, run.passive) + ")") if run.weapon > 0 else ""], DDUi.FONT_M, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	if run.perk_offer.is_empty():
		v.add_child(DDUi.label("No perks left to offer.", DDUi.FONT_M, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		v.add_child(DDUi.label("Pick 1 perk for the rest of the run (long press / right click to zoom)", DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	var box: BoxContainer = BoxContainer.new()
	box.vertical = portrait
	box.add_theme_constant_override("separation", SEP)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(box)
	var vp: Vector2 = get_viewport_rect().size
	for pid: String in run.perk_offer:
		var size: Vector2 = Vector2(vp.x - MARGIN * 2, 130) if portrait else Vector2(minf(320.0, (vp.x - MARGIN * 2 - SEP * 2) / 3.0), 220)
		var ps: Dictionary = DDPayloads.perk_spec(pid, Game.bal, false, pid == chosen_perk)
		ps["art_keys"] = Art.perk_keys(pid)
		ps["art_fit"] = "contain"
		var cv: DDCardView = _view(ps, size)
		if pid == chosen_perk and _screen_fx == "" and _pending_fx.is_empty() and _perk_popped != pid:
			_perk_popped = pid
			(func() -> void:
				await get_tree().process_frame
				if is_instance_valid(cv):
					feedback._pop(cv, 1.06, DDUi.accent("P"))).call()
		cv.tapped.connect(func(_x: DDCardView) -> void:
			if chosen_perk != pid:
				Sfx.cue(&"flip", 1.1)
			chosen_perk = pid
			_queue_render())
		box.add_child(cv)
	var label: String = "Continue" if run.perk_offer.is_empty() else ("Take %s" % DDText.perk_name(chosen_perk) if chosen_perk != "" else "Tap a perk to choose it")
	var go: Button = DDUi.button(label, Color("245236"), DDUi.FONT_L)
	go.custom_minimum_size = Vector2(0, 88)
	go.disabled = chosen_perk == "" and not run.perk_offer.is_empty()
	go.pressed.connect(func() -> void:
		var from: int = run.log_lines.size()
		var ev: Dictionary = run.choose_perk(chosen_perk)
		if bool(ev.get("ok", false)):
			ev["_log_from"] = from
			last_event = ev
			if chosen_perk != "":
				Sfx.cue(&"perk")
			_perk_popped = ""
			screen = Screen.MAP
			_screen_fx = "map"
			_queue_render())
	v.add_child(go)


# ---------------------------------------------------------------- end
func _build_end() -> void:
	var run: DDRun = Game.run
	var won: bool = run.phase == DDRun.Phase.WON
	var v: VBoxContainer = DDUi.vbox(12)
	_content.add_child(_scroll(v))
	var head: Label = DDUi.label("YOU MADE IT OUT" if won else "OVERRUN", 56, DDUi.GOOD if won else DDUi.BAD, HORIZONTAL_ALIGNMENT_CENTER)
	_screen_title = head
	v.add_child(head)
	var s: Dictionary = Game.bal.survivor(run.survivor_id)
	var where: String = "%s escaped the city." % str(s.get("name", "")) if won else "%s fell in %s." % [str(s.get("name", "")), str(run.district().get("name", ""))]
	v.add_child(DDUi.label(where, DDUi.FONT_M, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	if not won and not last_event.is_empty():
		v.add_child(DDUi.label("Last card: " + str(last_event.get("text", "")), DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	var sc: PanelContainer = DDUi.panel(DDUi.PANEL, 14)
	var sv: VBoxContainer = DDUi.vbox(4)
	sc.add_child(sv)
	for di: int in run.district_scores.size():
		sv.add_child(DDUi.label("%s: %d" % [str(Game.bal.district(di).get("name", "")), run.district_scores[di]], DDUi.FONT_M, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	sv.add_child(DDUi.label("RUN SCORE %d" % run.run_score(), DDUi.FONT_XL, DDUi.WARN, HORIZONTAL_ALIGNMENT_CENTER))
	sv.add_child(DDUi.label("Best with %s: %d   -   %d streets, %d retreats" % [run.survivor_id.capitalize(), Game.profile.best_score(run.survivor_id), run.streets_played, run.retreats], DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(sc)
	if not Game.new_unlocks.is_empty():
		v.add_child(DDUi.label("NEW UNLOCKS (long press / right click to zoom)", DDUi.FONT_M, DDUi.GOOD, HORIZONTAL_ALIGNMENT_CENTER, true))
		var row: HFlowContainer = HFlowContainer.new()
		row.alignment = FlowContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("h_separation", SEP)
		v.add_child(row)
		for key: String in Game.new_unlocks:
			var p: Dictionary = DDPayloads.unlock(key, Game.bal, Game.profile)
			var cv: DDCardView = _view({"kind": p["kind"], "tag": "NEW", "badge": "NEW", "badge_color": DDUi.GOOD, "title": "New: " + str(p["title"]),
				"big": str(p.get("big", "")), "big_size": 40, "payload": p}, Vector2(200, 160))
			cv.tapped.connect(func(_x: DDCardView) -> void: _inspect.open(p))
			row.add_child(cv)
	var h: HBoxContainer = DDUi.hbox(SEP)
	v.add_child(h)
	var again: Button = DDUi.button("Run again", Color("7a2d27"), DDUi.FONT_L)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.custom_minimum_size = Vector2(0, 88)
	again.pressed.connect(func() -> void:
		chosen_survivor = run.survivor_id
		_start_run())
	h.add_child(again)
	var title: Button = DDUi.button("Survivors", DDUi.PANEL_HI, DDUi.FONT_L)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.custom_minimum_size = Vector2(0, 88)
	title.pressed.connect(func() -> void:
		screen = Screen.TITLE
		_queue_render())
	h.add_child(title)


# ================================================================ test / smoke hooks
## Web only: ?screen=street&seed=5&select=0 jumps to a screen with a seeded run (QA screenshots);
## &notch=3[&weapon=6] gives the run a notched weapon.
func _apply_smoke_query() -> void:
	if not OS.has_feature("web"):
		return
	var q: String = str(JavaScriptBridge.eval("window.location.search", true))
	if q == "" or q == "null":
		return
	var args: Dictionary = {}
	for part: String in q.trim_prefix("?").split("&"):
		var kv: PackedStringArray = part.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	if not args.has("screen"):
		return
	var sid: String = str(args.get("survivor", "rosa"))
	Game.start_run(sid, int(args.get("seed", "7")))
	match str(args["screen"]):
		"map":
			screen = Screen.MAP
		"street":
			screen = Screen.STREET
			selected = int(args.get("select", "-1"))
		"safehouse":
			Game.run.setup_street(["M2", "M2", "M2", "M2"])
			for k: int in 4:
				Game.run.resolve(0, DDRun.USE)
			Game.run.resolve(0, DDRun.BARE)
			safehouse_info = {"district": "Maple Row", "score": Game.run.district_scores[0]}
			screen = Screen.SAFEHOUSE
		"end":
			Game.run.setup_street(["Z14", "Z14", "B2", "B2", "B2", "B2", "B2", "B2"])
			Game.run.resolve(0, DDRun.BARE)
			last_event = Game.run.resolve(0, DDRun.BARE)
			Game.sync_profile()
			screen = Screen.END
	if args.has("notch"):
		# dd-polish QA: ?screen=street&notch=3 -> a notched weapon, so stronger zombies show darkened
		Game.run.weapon = int(args.get("weapon", "6"))
		Game.run.notch = int(args["notch"])
	if args.has("inspect"):
		var what: String = str(args["inspect"])
		if what == "deck":
			_auto_inspect = DDPayloads.deck(Game.run)
		elif what == "weapon":
			_auto_inspect = DDPayloads.weapon_slot(Game.run)
		elif what == "finale":
			_auto_inspect = DDPayloads.finale(Game.run.district())


## Web only: exposes window.ddState (screen, hp, tappable rects in CSS px) for browser smoke tests.
func _publish_state() -> void:
	await get_tree().process_frame
	var xf: Transform2D = get_viewport().get_final_transform()
	var dpr: float = float(JavaScriptBridge.eval("window.devicePixelRatio || 1", true))
	var items: Array = []
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		if (n is Button or n is DDCardView) and (n as Control).is_visible_in_tree() and not n.has_meta(&"ghost"):
			var r: Rect2 = (n as Control).get_global_rect()
			var p0: Vector2 = xf * r.position / dpr
			var p1: Vector2 = xf * r.end / dpr
			var e: Dictionary = {"x": p0.x, "y": p0.y, "w": p1.x - p0.x, "h": p1.y - p0.y}
			if n is Button:
				e["type"] = "button"
				e["text"] = (n as Button).text
				e["disabled"] = (n as Button).disabled
			else:
				e["type"] = "card"
				e["kind"] = (n as DDCardView).kind
				e["index"] = (n as DDCardView).index
				e["title"] = str((n as DDCardView).payload.get("title", ""))
			items.append(e)
	var st: Dictionary = {"screen": screen_name(), "portrait": portrait, "items": items,
		"inspect": _inspect.is_open(), "settings": settings_panel.is_open(), "fx": feedback.last_played}
	if Game.run != null:
		st["hp"] = Game.run.hp
		st["phase"] = DDRun.Phase.keys()[Game.run.phase]
		st["log"] = str(last_event.get("text", ""))
		st["street"] = Game.run.street.size()
		st["resolved"] = Game.run.resolved_count
	JavaScriptBridge.eval("window.ddState = " + JSON.stringify(st) + ";", true)

## Used by the headless UI smoke test and the browser smoke test: what is on screen now.
func screen_name() -> String:
	return Screen.keys()[screen]

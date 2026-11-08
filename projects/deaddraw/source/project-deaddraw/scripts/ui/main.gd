# main.gd
# Purpose: The whole DeadDraw v2 UI: title (survivor pick), city map, street, safehouse and run-end
#   screens. Rebuilt from the run state after every action, laid out for portrait (2x2 street) or
#   landscape (1x4 street, status + doors on the left, weapons on the right) from the viewport
#   aspect. Rules live in DDRun; this script only renders state, previews outcomes and calls the
#   run's public methods. v2 street (core-rules-v2.md section 6): wave track + boss, points, HP /
#   Cover / Jawbreaker badges, deck counter "Wave 2 - 7 cards (4 zombies)", Skipped pile, doors
#   (price + what they unlock) and machines (price + result), the last-street banner with the
#   next-wave preview, 2 weapon slots with magazine pips, notch tags and Reload buttons (cost and
#   result), reserve ammo, Skip. Every tile opens a zoom on right click / long press; every
#   button states its result before the tap; the log line, HP / points floats, the wave banner and
#   machine-result zooms show what just happened.
#   dd-feel: before each action it snapshots the street (card rects, HP, notch); after the
#   rebuild scripts/fx/dd_feedback.gd animates from the old picture to the new one. Card art from
#   the manifest (scripts/ui/dd_art.gd); anything without art keeps the plain tile.
# Dependencies: Game (autoload), DDRun, DDWeapon, DDPayloads, DDCardView, DDInspect, DDUi, DDText,
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
var selected_room: int = -1
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
var _pending_banner: Dictionary = {}
var _street_views: Dictionary = {}   # card instance id -> DDCardView
var _street_specs: Dictionary = {}   # card instance id -> tile spec
var _street_cards: Dictionary = {}   # card instance id -> DDCard
var _street_order: Array = []
var _deck_anchor: Control = null
var _skipped_anchor: Control = null
var _finale_anchor: Control = null
var _cover_anchor: Control = null
var _points_anchor: Control = null
var _reserve_anchor: Control = null
var _slot_views: Array = [null, null]
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
	_skipped_anchor = null
	_finale_anchor = null
	_cover_anchor = null
	_points_anchor = null
	_reserve_anchor = null
	_slot_views = [null, null]
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
	if not _pending_fx.is_empty() or _screen_fx != "" or not _pending_banner.is_empty():
		var pend: Dictionary = _pending_fx
		var sfx: String = _screen_fx
		var ban: Dictionary = _pending_banner
		_pending_fx = {}
		_screen_fx = ""
		_pending_banner = {}
		_play_fx.call_deferred(pend, sfx, ban)
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
func _play_fx(pend: Dictionary, screen_fx: String, banner: Dictionary = {}) -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_sync_feel()
	if not pend.is_empty() and screen == Screen.STREET:
		feedback.play(pend, _fx_context(pend))
	if not banner.is_empty() and screen == Screen.STREET:
		_show_banner(str(banner.get("text", "")), banner.get("color", DDUi.TEXT), str(banner.get("sub", "")))
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


func _fx_context(pend: Dictionary = {}) -> Dictionary:
	var run: DDRun = Game.run
	var ev: Dictionary = pend.get("ev", {})
	var s: int = int(ev.get("slot", -1))
	var wv: Control = _slot_views[s] if s >= 0 and s < 2 else _slot_views[0]
	var deck: Control = _skipped_anchor if str(pend.get("type", "")) == "retreat" else _deck_anchor
	return {"street": _street_views, "specs": _street_specs, "cards": _street_cards, "order": _street_order,
		"deck": deck, "weapon": wv, "finale": _finale_anchor, "cover": _cover_anchor, "reserve": _reserve_anchor,
		"hp_panel": _hp_anchor, "hp_box": _hp_box, "hp_label": _hp_label, "hp_bar": _hp_bar,
		"hp": run.hp if run != null else 0, "max_hp": run.max_hp if run != null else 0}


## dd-feel: what the street looks like right before an action (for the feedback animations).
func _snapshot(slot: int = -1) -> Dictionary:
	var run: DDRun = Game.run
	var rects: Dictionary = {}
	for id: Variant in _street_views:
		var v: DDCardView = _street_views[id]
		if is_instance_valid(v) and v.is_inside_tree():
			rects[id] = v.get_global_rect()
	var w: DDWeapon = run.slot(slot) if slot >= 0 else null
	return {"rects": rects, "specs": _street_specs.duplicate(), "hp": run.hp, "cover": run.cover,
		"notch": w.notch if w != null else DDRun.NO_NOTCH,
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
		v.add_child(DDUi.label("Hold out across a fallen city, one wave at a time.\nEvery street deals four cards; you get three actions.", DDUi.FONT_M, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
		v.add_child(DDUi.label("Pick a survivor  (long press / right click to read)", DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	else:
		# landscape: one line of text so the Start row stays clear of the bottom edge
		v.add_child(DDUi.label("Hold out one wave at a time: four cards a street, three actions. Pick a survivor (long press / right click to read).", DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
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
			lines.append(["Best %d" % Game.bal.shown(Game.profile.best_score(sid)), DDUi.TEXT, DDUi.FONT_S])
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
	selected_room = -1
	last_event = {}
	screen = Screen.MAP
	_queue_render()


# ---------------------------------------------------------------- map
func _build_map() -> void:
	var run: DDRun = Game.run
	var v: VBoxContainer = DDUi.vbox(12)
	_content.add_child(_scroll(v))
	v.add_child(DDUi.label("THE CITY", DDUi.FONT_XL if portrait else DDUi.FONT_L, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(DDUi.label("District %d of %d: 3 waves, then its boss (face up: plan for it)." % [run.district_index + 1, Game.bal.district_count()], DDUi.FONT_M, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
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
		selected_room = -1
		_pending_fx = {"type": "deal", "snap": {}, "ev": {}}
		_pending_banner = {"text": "WAVE 1 - %s" % DDText.zombie_summary(Game.bal.wave_zombies(run.district_index, 0)), "color": DDUi.TEXT,
			"sub": str(run.district().get("name", ""))}
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
	for i: int in 2:
		h.add_child(_view(_slot_spec(run, i), Vector2(170, 0)))
	h.add_child(_view(DDPayloads.reserve_spec(run), Vector2(100, 0)))
	h.add_child(_view(DDPayloads.points_spec(run), Vector2(110, 0)))
	for p: String in run.perks:
		h.add_child(_view(DDPayloads.perk_spec(p, Game.bal, true), Vector2(150, 0)))
	return h


func _slot_spec(run: DDRun, i: int) -> Dictionary:
	var ws: Dictionary = DDPayloads.slot_spec(run, i)
	var w: DDWeapon = run.slot(i)
	if w != null:
		ws["art_keys"] = Art.weapon_keys(w.wid, w.name)
		if w.upgraded:
			var plate: Texture2D = Art.texture_for(Art.badge_keys("retrofit"))
			if plate != null:
				ws["badge_art"] = plate
	return ws


# ---------------------------------------------------------------- street
func _build_street() -> void:
	var run: DDRun = Game.run
	var vp: Vector2 = get_viewport_rect().size
	var did: String = str(run.district().get("id", ""))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2 if portrait else 4
	grid.add_theme_constant_override("h_separation", SEP)
	grid.add_theme_constant_override("v_separation", SEP)
	var left_w: float = clampf(vp.x * 0.24, 250.0, 320.0)
	var right_w: float = clampf(vp.x * 0.24, 250.0, 320.0)
	var banner_on: bool = run.is_last_street() or run.boss_street or run.last_lap
	var n: int = maxi(1, run.street.size())
	var card_w: float
	var card_h: float
	if portrait:
		card_w = (vp.x - MARGIN * 2 - SEP) / 2.0
		var fixed: float = 700.0 + (52.0 if banner_on else 0.0)
		var rows: int = ceili(n / 2.0)
		card_h = clampf((vp.y - fixed) / maxf(2.0, float(rows)), 150.0, card_w * 1.25)
	else:
		var cols: int = maxi(4, n) if n > 4 else 4
		grid.columns = cols
		card_w = (vp.x - MARGIN * 2 - left_w - right_w - SEP * 2 - SEP * (cols - 1)) / float(cols)
		card_h = clampf(vp.y - MARGIN * 2 - 250.0 - (48.0 if banner_on else 0.0), 150.0, card_w * 1.45)
	for i: int in run.street.size():
		var c: DDCard = run.street[i]
		var spec: Dictionary = DDPayloads.street_card_spec(c, i, run, i == selected)
		spec["art_keys"] = Art.card_keys(c, did)
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
	var pts: DDCardView = _view(DDPayloads.points_spec(run), Vector2(118 if portrait else 0, 0))
	_points_anchor = pts
	var wave_row: HBoxContainer = _build_wave_track(run)
	var deck_row: HBoxContainer = DDUi.hbox(SEP)
	var ds: Dictionary = DDPayloads.deck_spec(run)
	ds["art_keys"] = Art.back_keys()
	ds["art_tint"] = 0.82
	var dv: DDCardView = _view(ds)
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.size_flags_stretch_ratio = 2.0
	_deck_anchor = dv
	deck_row.add_child(dv)
	var sv: DDCardView = _view(DDPayloads.skipped_spec(run))
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skipped_anchor = sv
	deck_row.add_child(sv)
	var doors: Control = _build_doors(run)
	var weapons: Control = _build_weapons(run)
	var banner: Control = null
	if banner_on:
		banner = _view(DDPayloads.next_spec(run))
	if portrait:
		var v: VBoxContainer = DDUi.vbox(8)
		_content.add_child(v)
		var top: HBoxContainer = DDUi.hbox(SEP)
		hp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(hp_box)
		top.add_child(pts)
		v.add_child(top)
		var mid: HBoxContainer = DDUi.hbox(SEP)
		wave_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.add_child(wave_row)
		deck_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		deck_row.size_flags_stretch_ratio = 1.4
		mid.add_child(deck_row)
		v.add_child(mid)
		v.add_child(doors)
		if banner != null:
			v.add_child(banner)
		var gc: CenterContainer = CenterContainer.new()
		gc.add_child(grid)
		v.add_child(gc)
		v.add_child(actions)
		v.add_child(weapons)
		log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(log_box)
	else:
		var h: HBoxContainer = DDUi.hbox(SEP)
		_content.add_child(h)
		var side: VBoxContainer = DDUi.vbox(8)
		side.custom_minimum_size = Vector2(left_w, 0)
		h.add_child(side)
		side.add_child(hp_box)
		var r2: HBoxContainer = DDUi.hbox(8)
		pts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r2.add_child(pts)
		side.add_child(r2)
		side.add_child(wave_row)
		side.add_child(deck_row)
		doors.size_flags_vertical = Control.SIZE_EXPAND_FILL
		side.add_child(doors)
		var main: VBoxContainer = DDUi.vbox(8)
		main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(main)
		if banner != null:
			main.add_child(banner)
		main.add_child(grid)
		main.add_child(actions)
		log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		main.add_child(log_box)
		weapons.custom_minimum_size = Vector2(right_w, 0)
		h.add_child(weapons)


func _build_hp(run: DDRun) -> Control:
	var h: HBoxContainer = DDUi.hbox(8)
	var sv: DDCardView = _view({"kind": "S", "tag": run.survivor_id.to_upper(),
		"title": DDText.passive_name(run.passive), "compact": true,
		"payload": DDPayloads.survivor(run.survivor_id, Game.bal, Game.profile),
		"art_keys": Art.survivor_keys(run.survivor_id)}, Vector2(96 if portrait else 88, 0))
	h.add_child(sv)
	var hp_panel: PanelContainer = DDUi.panel(DDUi.PANEL, 8)
	hp_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hv: VBoxContainer = DDUi.vbox(4)
	hp_panel.add_child(hv)
	var col: Color = DDUi.GOOD if run.hp * 2 > run.max_hp else (DDUi.WARN if run.hp * 4 > run.max_hp else DDUi.BAD)
	_hp_label = DDUi.label("HP %d / %d" % [run.hp, run.max_hp], DDUi.FONT_M, col)
	hv.add_child(_hp_label)
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = run.max_hp
	bar.value = run.hp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.add_theme_stylebox_override("background", DDUi.box(Color("0d0f10"), Color(0, 0, 0, 0), 0, 6, 0))
	bar.add_theme_stylebox_override("fill", DDUi.box(col, Color(0, 0, 0, 0), 0, 6, 0))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hv.add_child(bar)
	_hp_bar = bar
	h.add_child(hp_panel)
	_hp_anchor = hp_panel
	_hp_box = h
	if run.cover > 0:
		var cov: DDCardView = _view({"kind": "B", "tag": "COVER", "big": str(run.cover), "big_size": 28, "compact": true,
			"payload": DDPayloads.cover(run)}, Vector2(72, 0))
		_cover_anchor = cov
		h.add_child(cov)
	return h


## Wave track: the district's waves as pips (current lit) plus the face-up boss card.
func _build_wave_track(run: DDRun) -> HBoxContainer:
	var h: HBoxContainer = DDUi.hbox(6)
	for w: int in run.wave_count():
		var pv: DDCardView = _view(DDPayloads.wave_pip_spec(run, w))
		pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(pv)
	var fs: Dictionary = DDPayloads.finale_spec(run.district())
	fs["art_keys"] = Art.finale_keys(run.district())
	var fv: DDCardView = _view(fs)
	fv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fv.size_flags_stretch_ratio = 1.6
	_finale_anchor = fv
	h.add_child(fv)
	return h


## Doors / machines strip (+ this wave's Jawbreaker badges and perks).
func _build_doors(run: DDRun) -> Control:
	var box: Container
	if portrait:
		var hb: HBoxContainer = DDUi.hbox(8)
		box = hb
	else:
		box = DDUi.vbox(6)
	var did: String = str(run.district().get("id", ""))
	for i: int in run.room_count():
		var rs: Dictionary = DDPayloads.room_spec(run, i, i == selected_room)
		var r: Dictionary = run.room(i)
		if run.room_status(i) == "open":
			rs["art_keys"] = Art.machine_keys(r.get("machine", {}))
		else:
			rs["art_keys"] = Art.room_keys(did, str(r.get("name", "")))
		var rv: DDCardView = _view(rs)
		rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rv.index = 100 + i
		rv.tapped.connect(func(_x: DDCardView) -> void: _on_room_tapped(i))
		box.add_child(rv)
	var extra: HFlowContainer = HFlowContainer.new()
	extra.add_theme_constant_override("h_separation", 6)
	extra.add_theme_constant_override("v_separation", 6)
	for b: String in run.buffs:
		var bs: Dictionary = DDPayloads.buff_spec(b, Game.bal)
		bs["art_keys"] = Art.drop_keys("payday") if b == "payday" else Art.jawbreaker_keys(b)
		extra.add_child(_view(bs))
	for p: String in run.perks:
		var ps: Dictionary = DDPayloads.perk_spec(p, Game.bal, true)
		extra.add_child(_view(ps))
	if extra.get_child_count() == 0:
		extra.queue_free()
		return box
	var wrap: BoxContainer = BoxContainer.new()
	wrap.vertical = true
	wrap.add_theme_constant_override("separation", 6)
	wrap.add_child(box)
	wrap.add_child(extra)
	return wrap


## The two weapon slots (magazine pips, notch tag) with their Reload buttons, and the reserve.
func _build_weapons(run: DDRun) -> Control:
	var outer: BoxContainer = BoxContainer.new()
	outer.vertical = not portrait
	outer.add_theme_constant_override("separation", SEP)
	for i: int in 2:
		var col: VBoxContainer = DDUi.vbox(6)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sv: DDCardView = _view(_slot_spec(run, i))
		sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sv.index = 200 + i
		sv.tapped.connect(func(_x: DDCardView) -> void: _inspect.open(DDPayloads.slot_payload(run, i)))
		_slot_views[i] = sv
		col.add_child(sv)
		var w: DDWeapon = run.slot(i)
		if w != null and w.is_gun():
			var rp: Dictionary = run.reload_preview(i)
			if bool(rp["useful"]):
				var b: Button = DDUi.button(_reload_label(rp), Color("1f4a63"), DDUi.FONT_S)
				b.custom_minimum_size = Vector2(0, 64)
				b.disabled = not bool(rp["enabled"]) or busy
				b.pressed.connect(func() -> void: _do_reload(i))
				col.add_child(b)
		outer.add_child(col)
	var rs: DDCardView = _view(DDPayloads.reserve_spec(run), Vector2(96 if portrait else 0, 0))
	_reserve_anchor = rs
	outer.add_child(rs)
	_weapon_anchor = _slot_views[0]
	return outer


func _reload_label(rp: Dictionary) -> String:
	var cost: String = ("free: %s" % str(rp["free_why"])) if int(rp["cost"]) == 0 else "1 action"
	if not bool(rp["enabled"]):
		return "Reload - %s" % str(rp["reason"])
	return "RELOAD (%s)\ndrop %d, load %d" % [cost, int(rp["drop"]), int(rp["load"])]


func _build_actions(run: DDRun) -> Control:
	var p: PanelContainer = DDUi.panel(DDUi.PANEL, 8)
	var v: VBoxContainer = DDUi.vbox(6)
	p.add_child(v)
	var head: HBoxContainer = DDUi.hbox(8)
	v.add_child(head)
	var prompt: String
	if not run.pending_offer.is_empty():
		var w: DDWeapon = run.pending_offer["weapon"]
		prompt = "%s: %s - where does it go?" % ["Lucky Locker" if str(run.pending_offer["source"]) == "locker" else "Wall Rack", DDText.weapon_stats(w, run)]
	elif selected >= 0 and selected < run.street.size():
		prompt = "%s %d: choose how to resolve it." % [DDText.card_name(run.street[selected], run.bal), run.street[selected].value]
	elif selected_room >= 0:
		var r: Dictionary = run.room(selected_room)
		prompt = "%s - %s" % [str(r.get("name", "")), DDText.machine_name(str((r.get("machine", {}) as Dictionary).get("kind", "")))]
	elif run.boss_street:
		prompt = "BOSS STREET: resolve every card (%d left). Reloads are free." % run.street.size()
	elif run.actions_used == 0:
		prompt = "Tap a card to resolve it, or a door / machine (free, between streets)."
	else:
		prompt = "Keep going: %d more action%s this street." % [run.actions_left(), "" if run.actions_left() == 1 else "s"]
	var pl: Label = DDUi.label(prompt, DDUi.FONT_S, DDUi.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(pl)
	if not run.boss_street:
		head.add_child(_action_pips(run))
	var row: HBoxContainer = DDUi.hbox(8)
	v.add_child(row)
	if not run.pending_offer.is_empty():
		var w2: DDWeapon = run.pending_offer["weapon"]
		var ws: Dictionary = {"kind": "W", "tag": "NEW", "big": "P%d" % w2.power, "big_size": 26, "title": w2.name, "compact": true,
			"lines": [[("mag %d" % w2.cap) if w2.is_gun() else "melee", DDUi.TEXT_DIM, DDUi.FONT_S]],
			"payload": DDPayloads.weapon_payload(w2, run, "NEW WEAPON"), "art_keys": Art.weapon_keys(w2.wid, w2.name)}
		row.add_child(_view(ws, Vector2(110, 0)))
		for ch: String in [DDRun.EQUIP1, DDRun.EQUIP2, DDRun.SCRAP]:
			var op: Dictionary = run.offer_preview(ch)
			if ch == DDRun.SCRAP and not bool(op["enabled"]):
				continue
			var b: Button = DDUi.button(_offer_label(run, ch, op), Color("1f4a63") if ch != DDRun.SCRAP else DDUi.PANEL_HI, DDUi.FONT_S)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.disabled = not bool(op["enabled"]) or busy
			b.pressed.connect(func() -> void: _do_offer(ch))
			row.add_child(b)
	elif selected >= 0 and selected < run.street.size():
		for ch: String in run.choices_for(selected):
			var pr: Dictionary = run.preview(selected, ch)
			var b2: Button = DDUi.button(_choice_label(run, run.street[selected], ch, pr), _choice_color(ch, pr), DDUi.FONT_S)
			b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b2.disabled = not bool(pr["enabled"]) or busy
			var idx: int = selected
			b2.pressed.connect(func() -> void: _do_resolve(idx, ch))
			row.add_child(b2)
	elif selected_room >= 0:
		_room_buttons(run, selected_room, row)
	else:
		var rb: Button
		if run.can_slip_away():
			rb = DDUi.button("SLIP AWAY: skip the other %d (back next wave)" % run.street.size(), Color("3c3550"), DDUi.FONT_S)
			rb.pressed.connect(_do_slip)
		else:
			var why: String = run.skip_block_reason()
			rb = DDUi.button("SKIP STREET: the %d cards come back next wave" % run.street.size() if why == "" else "Skip - %s" % why, Color("3c3550"), DDUi.FONT_S)
			rb.disabled = why != "" or busy
			rb.pressed.connect(_do_skip)
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rb)
	return p


## "(o)(o)( )": actions used / left this street.
func _action_pips(run: DDRun) -> Control:
	var h: HBoxContainer = DDUi.hbox(4)
	h.add_child(DDUi.label("ACTIONS", DDUi.FONT_S - 4, DDUi.TEXT_DIM))
	for k: int in run.budget:
		var dot: PanelContainer = PanelContainer.new()
		var used: bool = k < run.actions_used
		dot.add_theme_stylebox_override("panel", DDUi.box(DDUi.TEXT_DIM if used else DDUi.GOOD, DDUi.TEXT, 1, 9, 0))
		dot.custom_minimum_size = Vector2(18, 18)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(dot)
	return h


func _room_buttons(run: DDRun, i: int, row: HBoxContainer) -> void:
	var st: String = run.room_status(i)
	var r: Dictionary = run.room(i)
	if st != "open":
		var why: String = run.room_block_reason(i)
		var mk: String = DDText.machine_name(str((r.get("machine", {}) as Dictionary).get("kind", "")))
		var t: String = "OPEN for %d: +%d loot into the deck now, %s, restock 1/wave" % [Game.bal.shown(int(r.get("cost", 0))), (r.get("pack", []) as Array).size(), mk]
		var b: Button = DDUi.button(t if why == "" else "Open %s - %s" % [str(r.get("name", "")), why], Color("245236"), DDUi.FONT_S)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = why != "" or busy
		b.pressed.connect(func() -> void: _do_open_room(i))
		row.add_child(b)
		return
	for o: Dictionary in run.machine_options(i):
		var label: String = "%s - PAY %d\n%s" % [str(o["label"]), Game.bal.shown(int(o["price"])), str(o["result"])]
		if not bool(o["enabled"]):
			label = "%s - %s" % [str(o["label"]), str(o["reason"])]
		var b2: Button = DDUi.button(label, Color("5a4023"), DDUi.FONT_S)
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.disabled = not bool(o["enabled"]) or busy
		var oid: String = str(o["id"])
		b2.pressed.connect(func() -> void: _do_machine(i, oid))
		row.add_child(b2)


func _offer_label(run: DDRun, ch: String, op: Dictionary) -> String:
	if ch == DDRun.SCRAP:
		return "LEAVE IT +%d" % Game.bal.shown(int(op["points"]))
	var s: int = 0 if ch == DDRun.EQUIP1 else 1
	var t: String = "INTO SLOT %d" % (s + 1)
	if str(op["replaces"]) != "":
		t += "\nscrap %s +%d" % [str(op["replaces"]), Game.bal.shown(int(op["points"]))]
	return t


func _choice_label(run: DDRun, c: DDCard, ch: String, pr: Dictionary) -> String:
	match ch:
		DDRun.BARE:
			return "BARE: -%d HP%s\n+%d pts up close" % [int(pr["hp_loss"]), _fate(pr), Game.bal.shown(int(pr["points"]))]
		DDRun.SLOT1, DDRun.SLOT2:
			var s: int = 0 if ch == DDRun.SLOT1 else 1
			var w: DDWeapon = run.slot(s)
			if w == null:
				return "Slot %d: empty" % (s + 1)
			if not bool(pr["enabled"]):
				return "%s: %s" % [w.display_name(), str(pr["reason"])]
			var tail: String = "weapon breaks (Shatter)" if bool(pr["breaks"]) else "notch %d" % int(pr["notch_after"])
			var use: String = "1 round, " if w.is_gun() else ""
			return "%s: -%d HP%s\n%s%s, +%d pts" % [w.display_name(), int(pr["hp_loss"]), _fate(pr), use, tail, Game.bal.shown(int(pr["points"]))]
		DDRun.EQUIP1, DDRun.EQUIP2:
			var s2: int = 0 if ch == DDRun.EQUIP1 else 1
			var t: String = "INTO SLOT %d" % (s2 + 1)
			if str(pr["replaces"]) != "":
				t += "\nscrap %s +%d" % [str(pr["replaces"]), Game.bal.shown(int(pr["points"]))]
			return t
		DDRun.SCRAP:
			return "SCRAP +%d" % Game.bal.shown(int(pr["points"]))
		DDRun.USE:
			match c.kind:
				DDCard.MEDKIT:
					if bool(pr["wasted"]):
						return "Use: won't heal"
					if int(pr["heal"]) <= 0:
						return "Use: you're at full HP,\nthis medkit heals nothing"
					return "Use: +%d HP" % int(pr["heal"])
				DDCard.AMMO:
					return "Take: +%d reserve ammo" % int(pr["ammo_gain"])
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
		DDRun.SLOT1, DDRun.SLOT2, DDRun.EQUIP1, DDRun.EQUIP2:
			return Color("1f4a63")
		DDRun.BARE:
			return Color("5a2a26")
		DDRun.USE:
			return Color("245236")
	return DDUi.PANEL_HI


func _build_log(run: DDRun) -> Control:
	var p: PanelContainer = DDUi.panel(Color("111416"), 8)
	var h: HBoxContainer = DDUi.hbox(8)
	p.add_child(h)
	var v: VBoxContainer = DDUi.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var n: int = run.log_lines.size()
	var main_text: String = str(last_event.get("text", "")) if not last_event.is_empty() else (run.log_lines[n - 1] if n > 0 else "")
	var col: Color = DDUi.TEXT
	var d: int = int(last_event.get("hp_delta", 0))
	if d < 0:
		col = DDUi.BAD
	elif d > 0:
		col = DDUi.GOOD
	v.add_child(DDUi.label("> " + main_text, DDUi.FONT_S, col, HORIZONTAL_ALIGNMENT_LEFT, true))
	# what else happened (drop, holdover, wave change, boss) since the main line
	var extra: PackedStringArray = []
	for t: Variant in last_event.get("notes", []):
		if str(t) != main_text:
			extra.append(str(t))
	if not extra.is_empty():
		v.add_child(DDUi.label(" ".join(extra), DDUi.FONT_S - 3, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true))
	var bv: VBoxContainer = DDUi.vbox(6)
	h.add_child(bv)
	var btn: Button = DDUi.button("Log", DDUi.PANEL, DDUi.FONT_S)
	btn.custom_minimum_size = Vector2(96, 56)
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	btn.pressed.connect(func() -> void:
		var lines: Array[String] = run.log_lines.slice(maxi(0, n - 14))
		_inspect.open({"kind": "D", "tag": "WHAT HAPPENED", "title": "Recent events", "body": "\n".join(lines)}))
	bv.add_child(btn)
	var sb: Button = _settings_button(true)
	sb.custom_minimum_size = Vector2(96, 56)
	bv.add_child(sb)
	return p


func _on_card_tapped(v: DDCardView) -> void:
	if busy:
		return
	selected = -1 if selected == v.index else v.index
	selected_room = -1
	Sfx.cue(&"button", 0.8 if selected >= 0 else 0.7)
	_queue_render()


func _on_room_tapped(i: int) -> void:
	if busy:
		return
	selected_room = -1 if selected_room == i else i
	selected = -1
	Sfx.cue(&"button", 0.85)
	_queue_render()


func _begin_action() -> int:
	return Game.run.log_lines.size()


func _finish(ev: Dictionary, fx: Dictionary) -> void:
	if not bool(ev.get("ok", false)):
		return
	last_event = ev
	selected = -1
	if str(ev.get("kind", "")) != "room" and str(ev.get("kind", "")) != "machine":
		selected_room = -1
	_pending_fx = fx
	_after_event(ev)


func _do_resolve(i: int, ch: String) -> void:
	if busy:
		return
	var run: DDRun = Game.run
	var s: int = 0 if ch == DDRun.SLOT1 else (1 if ch == DDRun.SLOT2 else -1)
	var snap: Dictionary = _snapshot(s)
	var ev: Dictionary = run.resolve(i, ch)
	_finish(ev, {"type": "resolve", "ev": ev, "snap": snap})


func _do_reload(s: int) -> void:
	if busy:
		return
	var run: DDRun = Game.run
	var ev: Dictionary = run.reload(s)
	if bool(ev.get("ok", false)):
		Sfx.cue(&"equip", 0.85)
		(func() -> void:
			await get_tree().process_frame
			await get_tree().process_frame
			if _slot_views[s] != null and is_instance_valid(_slot_views[s]):
				feedback._pop(_slot_views[s], 1.12, DDUi.accent("W"))).call()
	_finish(ev, {"type": "deal", "ev": ev, "snap": _snapshot()})


func _do_skip() -> void:
	if busy:
		return
	var snap: Dictionary = _snapshot()
	var ev: Dictionary = Game.run.skip()
	_finish(ev, {"type": "retreat", "ev": ev, "snap": snap})


func _do_slip() -> void:
	if busy:
		return
	var snap: Dictionary = _snapshot()
	var ev: Dictionary = Game.run.slip_away()
	_finish(ev, {"type": "retreat", "ev": ev, "snap": snap})


func _do_open_room(i: int) -> void:
	if busy:
		return
	var snap: Dictionary = _snapshot()
	var ev: Dictionary = Game.run.open_room(i)
	if bool(ev.get("ok", false)):
		Sfx.cue(&"clear", 1.2)
		selected_room = i
	_finish(ev, {"type": "deal", "ev": ev, "snap": snap})


func _do_machine(i: int, oid: String) -> void:
	if busy:
		return
	var run: DDRun = Game.run
	var ev: Dictionary = run.use_machine(i, oid)
	if not bool(ev.get("ok", false)):
		return
	Sfx.cue(&"perk")
	selected_room = -1
	_auto_inspect = _result_payload(run, ev)
	_finish(ev, {})


func _do_offer(ch: String) -> void:
	if busy:
		return
	var ev: Dictionary = Game.run.take_offer(ch)
	if bool(ev.get("ok", false)):
		Sfx.cue(&"equip" if ch != DDRun.SCRAP else &"scrap")
	_finish(ev, {})


## The zoomed "You got" card after a machine use (the result is never hidden).
func _result_payload(run: DDRun, ev: Dictionary) -> Dictionary:
	var res: Dictionary = ev.get("result", {})
	var p: Dictionary
	if res.has("effect"):
		var e: String = str(res["effect"])
		p = {"kind": "J", "tag": "GRIN MACHINE - YOU GOT", "title": DDText.buff_name(e), "big": "",
			"body": "%s: %s%s" % [DDText.buff_name(e), DDText.buff_text(e, run.bal), "" if e == "sugar_rush" else " The badge sits next to your HP; long press it any time."]}
		var tex: Texture2D = Art.texture_for(Art.jawbreaker_keys(e))
		if tex != null:
			p["art"] = tex
	else:
		var w: DDWeapon = res.get("weapon")
		var tag: String = {"locker": "LUCKY LOCKER - YOU GOT", "retrofit": "RETROFIT BENCH", "wallrack": "WALL RACK"}.get(str(res.get("machine", "")), "YOU GOT")
		p = DDPayloads.weapon_payload(w, run, tag)
		p["body"] = str(ev.get("text", "")) + "\n" + str(p["body"])
		var tex2: Texture2D = Art.texture_for(Art.weapon_keys(w.wid, w.name))
		if tex2 != null:
			p["art"] = tex2
	return p


func _after_event(ev: Dictionary) -> void:
	var run: DDRun = Game.run
	if ev.has("wave_changed"):
		var info: Dictionary = ev["wave_changed"]
		var t: String = "WAVE %d - %s" % [int(info["wave"]) + 1, DDText.zombie_summary(info["zombies"])]
		if int(info["skipped"]) > 0:
			t += " + %d skipped" % int(info["skipped"])
		if int(info["restock"]) > 0:
			t += " + %d restock" % int(info["restock"])
		_pending_banner = {"text": t, "color": DDUi.TEXT, "sub": "Wave cleared: +%d points%s" % [Game.bal.shown(int(info.get("bonus", 0))), "  -  BOSS WAVE" if bool(info["boss_wave"]) else ""]}
		Sfx.cue(&"clear", 0.9)
	elif bool(ev.get("last_lap", false)):
		_pending_banner = {"text": "LAST LAP", "color": DDUi.WARN, "sub": "The skipped cards come back once. No skipping."}
	elif bool(ev.get("boss_street", false)):
		_pending_banner = {"text": "BOSS: " + str(run.finale().get("name", "")), "color": DDUi.accent("F"), "sub": "Resolve every card. Reloads are free."}
	elif str(ev.get("drop", "")) != "":
		_pending_banner = {"text": "CARRIER DROP: " + DDText.drop_name(str(ev["drop"])).to_upper(), "color": DDUi.accent("X"), "sub": DDText.drop_text(str(ev["drop"]), run.bal).capitalize()}
	if run.phase == DDRun.Phase.DEAD or run.phase == DDRun.Phase.WON or run.phase == DDRun.Phase.SAFEHOUSE:
		busy = true
		_pending_banner = {}
		_queue_render()
		_float_hp(int(ev.get("hp_delta", 0)))
		_float_points(int(ev.get("points_delta", 0)))
		# the death / clear moment plays on the street first (input is held only for this beat)
		await get_tree().create_timer(0.9).timeout
		busy = false
		if run.phase == DDRun.Phase.SAFEHOUSE:
			safehouse_info = {"district": str(Game.bal.district(run.district_index).get("name", "")),
				"hp_score": run.boss_hp[run.boss_hp.size() - 1] if not run.boss_hp.is_empty() else 0}
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
	_float_points(int(ev.get("points_delta", 0)))


func _float_hp(delta: int) -> void:
	if delta == 0:
		return
	await get_tree().process_frame
	_float_text("%+d HP" % delta, DDUi.GOOD if delta > 0 else DDUi.BAD, _hp_anchor)


func _float_points(delta: int) -> void:
	if delta == 0:
		return
	await get_tree().process_frame
	_float_text("%+d pts" % Game.bal.shown(delta), DDUi.accent("X") if delta > 0 else DDUi.WARN, _points_anchor)


func _float_text(t: String, col: Color, anchor: Control) -> void:
	if anchor == null or not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return
	var l: Label = DDUi.label(t, 36, col)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_fx.add_child(l)
	var r: Rect2 = anchor.get_global_rect()
	l.position = Vector2(clampf(r.position.x + r.size.x * 0.5 - 50, 0.0, get_viewport_rect().size.x - 140.0), r.end.y - 10)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 56, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


## Full-width banner (wave change, last lap, boss, Carrier drop): ~1.6 s, never blocks input.
var last_banner: String = ""


func _show_banner(text: String, col: Color, sub: String) -> void:
	last_banner = text
	var vp: Vector2 = get_viewport_rect().size
	var p: PanelContainer = DDUi.panel(Color(0.05, 0.06, 0.06, 0.92), 14, col, 3)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v: VBoxContainer = DDUi.vbox(2)
	p.add_child(v)
	v.add_child(DDUi.label(text, DDUi.FONT_L, col, HORIZONTAL_ALIGNMENT_CENTER, true))
	if sub != "":
		v.add_child(DDUi.label(sub, DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	DDUi.ignore_mouse(p)
	_fx.add_child(p)
	p.size = Vector2(vp.x - 40.0, 0)
	p.custom_minimum_size = Vector2(vp.x - 40.0, 0)
	p.position = Vector2(20.0, vp.y * 0.3)
	p.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.3 if not Game.reduce_motion() else 1.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


# ---------------------------------------------------------------- safehouse
func _build_safehouse() -> void:
	var run: DDRun = Game.run
	var v: VBoxContainer = DDUi.vbox(12)
	_content.add_child(_scroll(v))
	var head: Label = DDUi.label("%s CLEARED" % str(safehouse_info.get("district", "")).to_upper(), DDUi.FONT_XL, DDUi.GOOD, HORIZONTAL_ALIGNMENT_CENTER, true)
	_screen_title = head
	v.add_child(head)
	v.add_child(DDUi.label("HP left at the boss: +%d score  -  run score %d  -  points %d" % [Game.bal.shown(int(safehouse_info.get("hp_score", 0))), Game.bal.shown(run.run_score()), Game.bal.shown(run.points)], DDUi.FONT_M, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(DDUi.label("SAFEHOUSE: you rest and heal up to %d HP. Now HP %d / %d. You keep both weapons, your %d reserve ammo and your points." % [
		run.safehouse_healed(), run.hp, run.max_hp, run.reserve], DDUi.FONT_M, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	var kit: HFlowContainer = HFlowContainer.new()
	kit.alignment = FlowContainer.ALIGNMENT_CENTER
	kit.add_theme_constant_override("h_separation", SEP)
	for i: int in 2:
		kit.add_child(_view(_slot_spec(run, i), Vector2(180, 0)))
	kit.add_child(_view(DDPayloads.reserve_spec(run), Vector2(100, 0)))
	v.add_child(kit)
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
		var size: Vector2 = Vector2(vp.x - MARGIN * 2, 120) if portrait else Vector2(minf(320.0, (vp.x - MARGIN * 2 - SEP * 2) / 3.0), 200)
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
		var ev: Dictionary = run.choose_perk(chosen_perk)
		if bool(ev.get("ok", false)):
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
	var where: String = "%s escaped the city." % str(s.get("name", "")) if won else "%s fell in %s, wave %d." % [str(s.get("name", "")), str(run.district().get("name", "")), run.wave_index + 1]
	v.add_child(DDUi.label(where, DDUi.FONT_M, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	if not won and not last_event.is_empty():
		v.add_child(DDUi.label("Last card: " + str(last_event.get("text", "")), DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	var sc: PanelContainer = DDUi.panel(DDUi.PANEL, 14)
	var sv: VBoxContainer = DDUi.vbox(4)
	sc.add_child(sv)
	sv.add_child(DDUi.label("Points earned: %d" % Game.bal.shown(run.points_earned), DDUi.FONT_M, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	for di: int in run.boss_hp.size():
		sv.add_child(DDUi.label("%s boss: %d HP left, +%d" % [str(Game.bal.district(di).get("name", "")), run.boss_hp[di], Game.bal.shown(run.boss_hp[di])], DDUi.FONT_M, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	sv.add_child(DDUi.label("RUN SCORE %d" % Game.bal.shown(run.run_score()), DDUi.FONT_XL, DDUi.WARN, HORIZONTAL_ALIGNMENT_CENTER))
	sv.add_child(DDUi.label("Best with %s: %d   -   %d streets, %d skips, %d reloads, %d kills" % [run.survivor_id.capitalize(), Game.bal.shown(Game.profile.best_score(run.survivor_id)), run.streets_played, run.skips, run.reloads, run.kills], DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
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
## Web only (QA screenshots): ?screen=street&seed=5&select=0 jumps to a screen with a seeded run.
## Street extras: &points=40 (sim units), &open=2 (rooms opened), &slot2=machete, &notch=3 (slot 1),
## &ammo=1 (slot 1 rounds), &laststreet=1, &boss=1, &offer=locker, &room=0 (select a door),
## &buff=steady_aim, &skip=1, &inspect=deck|skipped|slot1|slot2|points|reserve|boss|room0|wave.
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
	if args.has("screen"):
		apply_debug(args)


## Shared by the web smoke query and the headless UI tests.
func apply_debug(args: Dictionary) -> void:
	var sid: String = str(args.get("survivor", "rosa"))
	Game.start_run(sid, int(args.get("seed", "7")))
	var run: DDRun = Game.run
	match str(args.get("screen", "street")):
		"map":
			screen = Screen.MAP
		"street":
			screen = Screen.STREET
			selected = int(args.get("select", "-1"))
		"safehouse":
			run.hp = run.max_hp
			run.wave_index = run.wave_count() - 1
			run.setup_street([], [])
			run.cover = 50
			run.resolve(0, DDRun.BARE)
			safehouse_info = {"district": "Maple Row", "hp_score": run.boss_hp[0] if not run.boss_hp.is_empty() else 0}
			screen = Screen.SAFEHOUSE
		"end":
			run.setup_street(["Z30", "Z30", "B2", "B2", "B2", "B2", "B2", "B2"])
			run.resolve(0, DDRun.BARE)
			last_event = run.resolve(0, DDRun.BARE)
			Game.sync_profile()
			screen = Screen.END
	if screen != Screen.STREET:
		return
	if args.has("points"):
		run.points = int(args["points"])
	for k: int in int(args.get("open", "0")):
		run.points += int(run.room(k).get("cost", 0))
		run.open_room(k)
	if args.has("slot2"):
		run.slots[1] = run.make_weapon(str(args["slot2"]))
	if args.has("notch") and run.slot(0) != null:
		run.slot(0).notch = int(args["notch"])
	if args.has("ammo") and run.slot(0) != null:
		run.slot(0).ammo = int(args["ammo"])
	if args.has("buff"):
		run.buffs.append(str(args["buff"]))
	if args.has("skip"):
		run.skip()
	if args.has("laststreet"):
		run.deck.clear()
	if args.has("boss"):
		run.wave_index = run.wave_count() - 1
		run.skipped.clear()
		run.setup_street([], ["M4"])
	if args.has("offer"):
		var i: int = -1
		for k: int in run.room_count():
			if str(run.machine(k).get("kind", "")) == "wallrack":
				i = k
		if i >= 0:
			if not run.opened.has(i):
				for k: int in i + 1:
					if not run.opened.has(k):
						run.points += int(run.room(k).get("cost", 0))
						run.open_room(k)
			run.points += 99
			for o: Dictionary in run.machine_options(i):
				if bool(o["enabled"]):
					run.use_machine(i, str(o["id"]))
					break
	if args.has("room"):
		selected_room = int(args["room"])
	if args.has("inspect"):
		var what: String = str(args["inspect"])
		match what:
			"deck":
				_auto_inspect = DDPayloads.deck_payload(run)
			"skipped":
				_auto_inspect = DDPayloads.skipped_payload(run)
			"slot1":
				_auto_inspect = DDPayloads.slot_payload(run, 0)
			"slot2":
				_auto_inspect = DDPayloads.slot_payload(run, 1)
			"points":
				_auto_inspect = DDPayloads.points_payload(run)
			"reserve":
				_auto_inspect = DDPayloads.reserve_payload(run)
			"boss":
				_auto_inspect = DDPayloads.finale(run.district())
			"wave":
				_auto_inspect = DDPayloads.wave_pip_payload(run, run.wave_index)
			_:
				if what.begins_with("room"):
					_auto_inspect = DDPayloads.room_payload(run, int(what.trim_prefix("room")))


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
				e["tag"] = str((n as DDCardView).payload.get("tag", ""))
			items.append(e)
	var st: Dictionary = {"screen": screen_name(), "portrait": portrait, "items": items,
		"inspect": _inspect.is_open(), "settings": settings_panel.is_open(), "fx": feedback.last_played,
		"banner": last_banner, "vw": get_viewport_rect().size.x, "vh": get_viewport_rect().size.y}
	if Game.run != null:
		var run: DDRun = Game.run
		st["hp"] = run.hp
		st["phase"] = DDRun.Phase.keys()[run.phase]
		st["log"] = str(last_event.get("text", ""))
		st["street"] = run.street.size()
		st["resolved"] = run.cards_resolved + run.streets_played * 10
		st["actions"] = run.actions_used
		st["wave"] = run.wave_index + 1
		st["deck"] = run.deck.size()
		st["skipped"] = run.skipped.size()
		st["points"] = Game.bal.shown(run.points)
		st["reserve"] = run.reserve
		st["opened"] = run.opened.size()
		st["pending"] = not run.pending_offer.is_empty()
		var ammo: Array = []
		for w: Variant in run.slots:
			ammo.append((w as DDWeapon).ammo if w != null else -1)
		st["ammo"] = ammo
	JavaScriptBridge.eval("window.ddState = " + JSON.stringify(st) + ";", true)


## Used by the headless UI smoke test and the browser smoke test: what is on screen now.
func screen_name() -> String:
	return Screen.keys()[screen]

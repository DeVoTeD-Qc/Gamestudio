# main.gd
# Purpose: The whole DeadDraw v3 ("Kill Stacks") UI: title (survivor pick), city map, street,
#   safehouse and run-end screens. Rebuilt from the run state after every action, laid out for
#   phone portrait or landscape from the viewport aspect. Rules live in DDRun; this script only
#   renders state, previews outcomes and calls the run's public methods.
#   The street (studio head's layout): WAVE decks on the LEFT (W1-W3 + the face-up boss), the
#   mixed DRAW PILE top middle, 3 ROOM decks on the RIGHT each with its price and an OPEN button
#   (lit whenever you can pay; opened rooms show their machine's USE button). The street's 4 cards
#   in the middle; the 2 equipped GUN cards at the bottom (stats + rule on the left, the kill stack
#   on the right, each zombie's number visible) plus the MELEE tile. Active weapon: tap a gun /
#   melee once, then every tap on a zombie attacks with it; each zombie shows the damage you'd
#   take ("-2") or LOCK with the rule's reason before the tap. Gun cards on the street open a
#   3-button sheet (slot 1 / slot 2 / scrap); machines open a sheet with every service, price and
#   result; a Patch choice is a sheet you must answer. HP / Cover / points / Patch chips on top,
#   Run (or Run past / NO ESCAPE) next to the prompt, the log line says what just happened, and
#   first-run hints (K5) teach the flow. Everything opens a zoom on right click / long press.
#   dd-feel: before each action it snapshots the street and the stacks; after the rebuild
#   scripts/fx/dd_feedback.gd animates kills onto stacks, collects, challenge stamps, wave / room
#   shuffle-ins, Run and the deal. Card art from the manifest (scripts/ui/dd_art.gd), else plain.
# Dependencies: Game (autoload), DDRun, DDGun, DDPayloads, DDCardView, DDGunView, DDInspect, DDUi,
#   DDText, scripts/fx/dd_feedback.gd, scripts/fx/dd_sfx.gd, scripts/ui/dd_art.gd,
#   scripts/ui/dd_settings_panel.gd.
# Author: Mechanics Developer Agent (feel primitives: Game Feel Engineer Agent)
extends Control

const Feedback: GDScript = preload("res://scripts/fx/dd_feedback.gd")
const Sfx: GDScript = preload("res://scripts/fx/dd_sfx.gd")
const Art: GDScript = preload("res://scripts/ui/dd_art.gd")
const SettingsPanel: GDScript = preload("res://scripts/ui/dd_settings_panel.gd")

enum Screen { TITLE, MAP, STREET, SAFEHOUSE, END }

const MARGIN: int = 16
const SEP: int = 8
## Indices DDCardView tiles carry (tests and the web smoke find tiles by them).
const IDX_ROOM: int = 100
const IDX_GUN: int = 200
const IDX_MELEE: int = 202
const IDX_WAVE: int = 300
const IDX_PILE: int = 400
const IDX_BOSS: int = 410
const IDX_POINTS: int = 420
const IDX_STACK: int = 500

var screen: Screen = Screen.TITLE
var chosen_survivor: String = "rosa"
var chosen_patch: String = ""
var portrait: bool = true
var busy: bool = false
var last_event: Dictionary = {}
## The open sheet: {} or {"type": "gun", "index": i} / {"type": "machine", "room": i}.
var sheet: Dictionary = {}
## K5: the first-run hint on screen ("" = none); hints off for debug / smoke screens.
var hint_id: String = ""
var hints_enabled: bool = true
var last_block: String = ""

var _content: MarginContainer
var _sheet_root: Control
var _fx: Control
var _inspect: DDInspect
var feedback: Node
var settings_panel: Control
var _auto_inspect: Dictionary = {}
var _pending_fx: Dictionary = {}
var _screen_fx: String = ""
var _pending_banner: Dictionary = {}
var _street_views: Dictionary = {}
var _street_specs: Dictionary = {}
var _street_cards: Dictionary = {}
var _street_order: Array = []
var _gun_views: Array = [null, null]
var _wave_views: Array = []
var _room_views: Array = []
var _melee_view: DDCardView = null
var _pile_view: DDCardView = null
var _boss_view: DDCardView = null
var _points_view: DDCardView = null
var _cover_view: DDCardView = null
var _hp_anchor: Control = null
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
	_sheet_root = Control.new()
	_sheet_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet_root)
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


func _sync_feel() -> void:
	feedback.reduce = Game.reduce_motion()
	feedback.shake_on = Game.screen_shake()


func open_settings() -> void:
	settings_panel.open()


# ================================================================ rendering
func _render() -> void:
	for c: Node in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	for c2: Node in _sheet_root.get_children():
		_sheet_root.remove_child(c2)
		c2.queue_free()
	feedback.clear()
	_street_views = {}
	_street_specs = {}
	_street_cards = {}
	_street_order = []
	_gun_views = [null, null]
	_wave_views = []
	_room_views = []
	_melee_view = null
	_pile_view = null
	_boss_view = null
	_points_view = null
	_cover_view = null
	_hp_anchor = null
	_hp_box = null
	_hp_label = null
	_hp_bar = null
	_screen_title = null
	var vp: Vector2 = get_viewport_rect().size
	portrait = vp.y >= vp.x
	match screen:
		Screen.TITLE:
			_build_title()
		Screen.MAP:
			_build_map()
		Screen.STREET:
			_build_street()
			_build_sheet()
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


## Re-render at the end of the frame (handlers run inside a Button's signal).
func _queue_render() -> void:
	if _render_queued:
		return
	_render_queued = true
	(func() -> void:
		_render_queued = false
		_render()).call_deferred()


func _play_fx(pend: Dictionary, screen_fx: String, banner: Dictionary = {}) -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_sync_feel()
	if not pend.is_empty() and screen == Screen.STREET:
		feedback.play(pend, _fx_context())
	if not banner.is_empty() and screen == Screen.STREET:
		var d: float = float(banner.get("delay", 0.0))
		if d > 0.0:
			await get_tree().create_timer(d).timeout
		_show_banner(str(banner.get("text", "")), banner.get("color", DDUi.TEXT), str(banner.get("sub", "")))
	match screen_fx:
		"end_won":
			Sfx.cue(&"win")
			feedback.title_slam(_screen_title, true)
		"end_dead":
			feedback.title_slam(_screen_title, false)
		"safehouse":
			feedback.title_slam(_screen_title, true)


func _fx_context() -> Dictionary:
	var run: DDRun = Game.run
	return {"street": _street_views, "specs": _street_specs, "cards": _street_cards, "order": _street_order,
		"pile": _pile_view, "boss": _boss_view, "guns": _gun_views, "melee": _melee_view, "waves": _wave_views,
		"rooms": _room_views, "open_rooms": run.room_open.duplicate() if run != null else [], "points": _points_view,
		"cover": _cover_view, "hp_panel": _hp_anchor, "hp_box": _hp_box, "hp_label": _hp_label, "hp_bar": _hp_bar,
		"hp": run.hp if run != null else 0, "max_hp": run.max_hp if run != null else 0, "finale": _boss_view}


## What the board looks like right before an action (for the feedback animations).
func _snapshot() -> Dictionary:
	var run: DDRun = Game.run
	var rects: Dictionary = {}
	for id: Variant in _street_views:
		var v: DDCardView = _street_views[id]
		if is_instance_valid(v) and v.is_inside_tree():
			rects[id] = v.get_global_rect()
	var stack_rects: Array = [[], []]
	var next_rects: Array = [Rect2(), Rect2()]
	var gun_rects: Array = [Rect2(), Rect2()]
	for s: int in 2:
		var gv: DDGunView = _gun_views[s]
		if gv != null and is_instance_valid(gv) and gv.is_inside_tree():
			gun_rects[s] = gv.get_global_rect()
			next_rects[s] = gv.next_rect()
			for mc: DDCardView in gv.stack_cards:
				(stack_rects[s] as Array).append(Rect2(mc.get_global_rect().position, mc.size))
	return {"rects": rects, "specs": _street_specs.duplicate(), "hp": run.hp, "cover": run.cover, "points": run.points,
		"stack_rects": stack_rects, "next_rect": next_rects, "gun_rects": gun_rects}


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


func _settings_button(small: bool = false) -> Button:
	var b: Button = DDUi.button("Settings", DDUi.PANEL if small else DDUi.PANEL_HI, DDUi.FONT_S if small else DDUi.FONT_M)
	b.name = "SettingsButton"
	if small:
		b.custom_minimum_size = Vector2(96, 56)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
	else:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(open_settings)
	return b


# ---------------------------------------------------------------- title
var _confirm_abandon: bool = false
var _old_note_shown: bool = false


func _build_title() -> void:
	var v: VBoxContainer = DDUi.vbox(14 if portrait else 8)
	_content.add_child(_scroll(v))
	v.add_child(DDUi.label("DEADDRAW", 64 if portrait else 40, DDUi.accent("Z"), HORIZONTAL_ALIGNMENT_CENTER))
	var sub: String = "KILL STACKS: shoot zombies in the order your gun's rule allows, fill its stack, get paid, open the next room."
	v.add_child(DDUi.label(sub + ("  Pick a survivor (long press / right click to read)." if not portrait else ""), DDUi.FONT_M if portrait else DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	if portrait:
		v.add_child(DDUi.label("Pick a survivor  (long press / right click to read)", DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	if Game.discarded_old_run and not _old_note_shown:
		var note: PanelContainer = DDUi.panel(Color("3a2a12"), 10, DDUi.WARN, 2)
		note.add_child(DDUi.label("DeadDraw has new rules (Kill Stacks). Your saved run from the old rules can't continue and was put away. Your unlocks and best scores are kept.", DDUi.FONT_S, DDUi.WARN, HORIZONTAL_ALIGNMENT_CENTER, true))
		note.name = "OldRunNote"
		v.add_child(note)
	var saved: String = Game.run_save.summary(Game.bal) if Game.run_save != null else ""
	if saved != "":
		v.add_child(_continue_row(saved))
	var row: HBoxContainer = DDUi.hbox(SEP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var vp: Vector2 = get_viewport_rect().size
	var w: float = minf(230.0, (vp.x - MARGIN * 2 - SEP * 2) / 3.0)
	var card_h: float = 220.0 if portrait else clampf(vp.y - MARGIN * 2 - 52.0 - 30.0 - DDUi.TAP_MIN - 8.0 * 3 - 12.0 - (80.0 if saved != "" else 0.0) - (50.0 if Game.discarded_old_run else 0.0), 110.0, 230.0)
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
			"badge_color": DDUi.GOOD if marks > 0 else DDUi.TEXT_DIM, "big": sid.substr(0, 1).to_upper(), "big_size": 56,
			"title": str(s.get("name", sid)), "lines": lines, "selected": sid == chosen_survivor, "dim": not unlocked,
			"payload": DDPayloads.survivor(sid, Game.bal, Game.profile), "art_keys": Art.survivor_keys(sid)}
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
	var go: Button = DDUi.button(("Start run as %s" if saved == "" else "New run as %s (replaces the saved run)") % str(Game.bal.survivor(chosen_survivor).get("name", "")), Color("7a2d27"), DDUi.FONT_L if saved == "" else DDUi.FONT_M)
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
	h.add_child(_settings_button())


func _continue_row(summary: String) -> Control:
	var h: HBoxContainer = DDUi.hbox(SEP)
	if _confirm_abandon:
		var yes: Button = DDUi.button("Abandon this run for good?\nYes, abandon it", Color("6b1f1a"), DDUi.FONT_S)
		yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		yes.pressed.connect(func() -> void:
			Game.abandon_run()
			_confirm_abandon = false
			_queue_render())
		h.add_child(yes)
		var no: Button = DDUi.button("No, keep it", DDUi.PANEL_HI, DDUi.FONT_M)
		no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		no.pressed.connect(func() -> void:
			_confirm_abandon = false
			_queue_render())
		h.add_child(no)
		return h
	var c: Button = DDUi.button("CONTINUE RUN\n" + summary, Color("245236"), DDUi.FONT_S)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = 3.0
	c.pressed.connect(continue_run)
	h.add_child(c)
	var a: Button = DDUi.button("Abandon run", DDUi.PANEL_HI, DDUi.FONT_S)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.pressed.connect(func() -> void:
		_confirm_abandon = true
		_queue_render())
	h.add_child(a)
	return h


## dd-save: resume the saved run on the screen it was left on.
func continue_run() -> void:
	var where: String = Game.resume_run()
	if where == "":
		_queue_render()
		return
	var run: DDRun = Game.run
	last_event = {}
	sheet = {}
	_confirm_abandon = false
	_old_note_shown = true
	match where:
		"SAFEHOUSE":
			screen = Screen.SAFEHOUSE
		"MAP":
			screen = Screen.MAP
		_:
			screen = Screen.STREET
			_pending_fx = {"type": "deal", "snap": {}, "ev": {}}
			_pending_banner = {"text": "RUN RESUMED", "color": DDUi.GOOD, "sub": "%s - %s" % [str(run.district().get("name", "")),
				"boss street" if run.boss_street else "wave %d" % (run.wave_index + 1)]}
	Sfx.cue(&"flip")
	_queue_render()


func _start_run() -> void:
	_confirm_abandon = false
	_old_note_shown = true
	Game.start_run(chosen_survivor)
	last_event = {}
	sheet = {}
	hints_enabled = true
	screen = Screen.MAP
	_queue_render()


# ---------------------------------------------------------------- map
func _build_map() -> void:
	var run: DDRun = Game.run
	var v: VBoxContainer = DDUi.vbox(12)
	_content.add_child(_scroll(v))
	v.add_child(DDUi.label("THE CITY", DDUi.FONT_XL if portrait else DDUi.FONT_L, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(DDUi.label("District %d of %d: 3 wave decks, 3 rooms, then the face-up boss." % [run.district_index + 1, Game.bal.district_count()], DDUi.FONT_M, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	var path: BoxContainer = BoxContainer.new()
	path.vertical = portrait
	path.add_theme_constant_override("separation", SEP)
	path.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(path)
	var vp: Vector2 = get_viewport_rect().size
	for di: int in Game.bal.district_count():
		var d: Dictionary = Game.bal.district(di)
		var b: Dictionary = d.get("boss", {})
		var status: String = "CLEARED" if di < run.district_index else ("NEXT" if di == run.district_index else "")
		var spec: Dictionary = {"kind": "F", "tag": "%d  %s" % [di + 1, str(d.get("name", "")).to_upper()], "badge": status,
			"badge_color": DDUi.GOOD if status == "CLEARED" else DDUi.WARN, "big": DDText.boss_summary(b), "big_size": 30,
			"title": "Boss: %s" % str(b.get("name", "")), "lines": [[DDText.trait_text(str(b.get("trait", ""))), DDUi.TEXT_DIM, DDUi.FONT_S - 2]],
			"selected": di == run.district_index, "dim": di < run.district_index,
			"payload": {"kind": "F", "tag": str(d.get("name", "")).to_upper(), "title": str(b.get("name", "")), "big": DDText.boss_summary(b),
				"body": "%s\nWaves: %s.\nRooms: %s." % [DDText.trait_text(str(b.get("trait", ""))), " | ".join(PackedStringArray([0, 1, 2].map(func(w: int) -> String: return DDText.zombie_list(Game.bal.wave_zombies(di, w))))),
					", ".join(PackedStringArray((d.get("rooms", []) as Array).map(func(r: Variant) -> String: return "%s %d" % [str((r as Dictionary).get("name", "")), Game.bal.shown(int((r as Dictionary).get("cost", 0)))])))]}}
		var banner: Texture2D = Art.texture_for(Art.district_keys(d))
		if banner != null:
			spec["bg_art"] = banner
		spec["art_keys"] = Art.finale_keys(d)
		var size: Vector2 = Vector2(vp.x - MARGIN * 2, 150) if portrait else Vector2(minf(320.0, (vp.x - MARGIN * 2 - SEP * 2) / 3.0), 170)
		path.add_child(_view(spec, size))
	var bottom: BoxContainer = BoxContainer.new()
	bottom.vertical = portrait
	bottom.add_theme_constant_override("separation", SEP)
	v.add_child(bottom)
	var st: HFlowContainer = HFlowContainer.new()
	st.add_theme_constant_override("h_separation", SEP)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s: Dictionary = Game.bal.survivor(run.survivor_id)
	st.add_child(_view({"kind": "S", "tag": "SURVIVOR", "title": str(s.get("name", "")), "compact": true,
		"lines": [["HP %d / %d" % [run.hp, run.max_hp], DDUi.GOOD, DDUi.FONT_M]], "payload": DDPayloads.survivor(run.survivor_id, Game.bal, Game.profile)}, Vector2(190, 0)))
	st.add_child(_view(_points_spec(run), Vector2(120, 0)))
	for p: String in run.patches:
		st.add_child(_patch_chip(p))
	bottom.add_child(st)
	var go: Button = DDUi.button("Enter %s" % str(run.district().get("name", "")), Color("7a2d27"), DDUi.FONT_L)
	go.custom_minimum_size = Vector2(0, 88)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(enter_district)
	bottom.add_child(go)
	var sb: Button = _settings_button(true)
	sb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(sb)


func enter_district() -> void:
	var run: DDRun = Game.run
	screen = Screen.STREET
	Game.save_run("STREET")
	sheet = {}
	_pending_fx = {"type": "deal", "snap": {}, "ev": {"waves": [{"wave": 0, "cards": 10, "restock": 0}]}}
	_pending_banner = {"text": "%s - WAVE 1" % str(run.district().get("name", "")).to_upper(), "color": DDUi.TEXT,
		"sub": "Wave 1 (%s) and the Entrance shuffle into the pile" % DDText.zombie_summary(Game.bal.wave_zombies(run.district_index, 0))}
	_queue_render()


# ---------------------------------------------------------------- street
func _points_spec(run: DDRun) -> Dictionary:
	return {"kind": "X", "tag": "POINTS", "big": str(Game.bal.shown(run.points)), "big_size": 26, "row": true, "payload": DDPayloads.points(run)}


func _patch_chip(p: String) -> DDCardView:
	var ps: Dictionary = DDPayloads.patch_spec(p, Game.bal, true)
	ps["art_keys"] = Art.patch_keys(p)
	ps["art_tint"] = 0.55
	return _view(ps, Vector2(104, 36))


func _build_street() -> void:
	var run: DDRun = Game.run
	var vp: Vector2 = get_viewport_rect().size
	var W: float = vp.x - MARGIN * 2
	var H: float = vp.y - MARGIN * 2
	hint_id = _due_hint(run)
	var top: Control = _build_top(run)
	var left: Control = _build_waves(run)
	var rooms: Control = _build_rooms(run)
	var pile: Control = _build_pile(run)
	var actions: Control = _build_actions(run)
	var hint: Control = _build_hint(run) if hint_id != "" else null
	var n: int = maxi(4, run.street.size())
	if portrait:
		var lw: float = clampf(W * 0.27, 130.0, 210.0)
		var rw: float = clampf(W * 0.38, 180.0, 300.0)
		var mini: Vector2 = Vector2(clampf(56.0 + (H - 900.0) / 8.0, 52.0, 80.0), 0)
		mini.y = mini.x * 1.3
		var gun_h: float = mini.y + mini.y * 0.32 * 4 + 16.0
		var guns: Control = _build_guns(run, true, mini, gun_h)
		var bottom: Control = _build_bottom(run, true)
		var fixed: float = 62.0 + 236.0 + 64.0 + gun_h + 64.0 + SEP * 6 + (44.0 if not run.patches.is_empty() else 0.0) + (64.0 if hint != null else 0.0)
		var card_w: float = (W - SEP * (n - 1)) / n
		var card_h: float = clampf(H - fixed, 120.0, card_w * 1.45)
		var v: VBoxContainer = DDUi.vbox(SEP)
		_content.add_child(v)
		v.add_child(top)
		if not run.patches.is_empty():
			v.add_child(_patch_row(run))
		var board: HBoxContainer = DDUi.hbox(SEP)
		left.custom_minimum_size = Vector2(lw, 0)
		board.add_child(left)
		pile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		board.add_child(pile)
		rooms.custom_minimum_size = Vector2(rw, 0)
		board.add_child(rooms)
		v.add_child(board)
		if hint != null:
			v.add_child(hint)
		v.add_child(_build_street_row(run, card_w, card_h))
		v.add_child(actions)
		v.add_child(guns)
		bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(bottom)
	else:
		var lw2: float = clampf(W * 0.15, 140.0, 200.0)
		var rw2: float = clampf(W * 0.19, 170.0, 240.0)
		var mid_w: float = W - lw2 - rw2 - SEP * 2
		var mini2: Vector2 = Vector2(clampf(H * 0.085, 40.0, 56.0), 0)
		mini2.y = mini2.x * 1.3
		var gun_h2: float = maxf(mini2.y + 16.0, 126.0)
		var guns2: Control = _build_guns(run, false, mini2, gun_h2)
		var fixed2: float = 60.0 + 64.0 + gun_h2 + SEP * 3 + (64.0 if hint != null else 0.0)
		var card_w2: float = (mid_w - SEP * (n - 1)) / n
		# a conservative minimum; the row expands into whatever height is left (text can wrap)
		var card_h2: float = clampf(H - fixed2 - 36.0, 100.0, card_w2 * 1.3)
		var h: HBoxContainer = DDUi.hbox(SEP)
		_content.add_child(h)
		left.custom_minimum_size = Vector2(lw2, 0)
		h.add_child(left)
		var mid: VBoxContainer = DDUi.vbox(SEP)
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(mid)
		var tr: HBoxContainer = DDUi.hbox(SEP)
		top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tr.add_child(top)
		pile.custom_minimum_size = Vector2(clampf(mid_w * 0.28, 150.0, 220.0), 0)
		tr.add_child(pile)
		mid.add_child(tr)
		if hint != null:
			mid.add_child(hint)
		var srow: Control = _build_street_row(run, card_w2, card_h2)
		srow.size_flags_vertical = Control.SIZE_EXPAND_FILL
		mid.add_child(srow)
		mid.add_child(actions)
		mid.add_child(guns2)
		var right: VBoxContainer = DDUi.vbox(SEP)
		right.custom_minimum_size = Vector2(rw2, 0)
		right.add_child(rooms)
		var lk2: Control = _build_lookout(run)
		if lk2 != null:
			right.add_child(lk2)
		if not run.patches.is_empty():
			right.add_child(_patch_row(run))
		right.add_child(_build_log(run))
		h.add_child(right)


## HP / Cover / points (+ survivor chip, settings).
func _build_top(run: DDRun) -> Control:
	var h: HBoxContainer = DDUi.hbox(6)
	_hp_box = h
	var sp: Dictionary = DDPayloads.survivor(run.survivor_id, Game.bal, Game.profile)
	h.add_child(_view({"kind": "S", "tag": run.survivor_id.to_upper(), "title": DDText.passive_name(run.passive), "compact": true, "row": true,
		"title_size": DDUi.FONT_S - 6, "payload": sp, "art_keys": Art.survivor_keys(run.survivor_id)}, Vector2(84, 0)))
	var hp_panel: PanelContainer = DDUi.panel(DDUi.PANEL, 6)
	hp_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hp_panel.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			_inspect.open(DDPayloads.hp(run)))
	var hv: VBoxContainer = DDUi.vbox(2)
	hp_panel.add_child(hv)
	var col: Color = DDUi.GOOD if run.hp * 2 > run.max_hp else (DDUi.WARN if run.hp * 4 > run.max_hp else DDUi.BAD)
	_hp_label = DDUi.label("HP %d / %d" % [run.hp, run.max_hp], DDUi.FONT_M - 2, col)
	hv.add_child(_hp_label)
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = run.max_hp
	bar.value = run.hp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.add_theme_stylebox_override("background", DDUi.box(Color("0d0f10"), Color(0, 0, 0, 0), 0, 6, 0))
	bar.add_theme_stylebox_override("fill", DDUi.box(col, Color(0, 0, 0, 0), 0, 6, 0))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hv.add_child(bar)
	_hp_bar = bar
	DDUi.ignore_mouse(hp_panel)
	h.add_child(hp_panel)
	_hp_anchor = hp_panel
	var cov: DDCardView = _view({"kind": "C", "tag": "COVER", "big": str(run.cover), "big_size": 22, "row": true, "dim": run.cover == 0,
		"payload": DDPayloads.cover(run)}, Vector2(84, 0))
	_cover_view = cov
	h.add_child(cov)
	var pv: DDCardView = _view(_points_spec(run), Vector2(112, 0))
	pv.index = IDX_POINTS
	_points_view = pv
	h.add_child(pv)
	var sb: Button = _settings_button(true)
	sb.text = "Menu"
	sb.custom_minimum_size = Vector2(72, 56)
	h.add_child(sb)
	return h


func _patch_row(run: DDRun) -> Control:
	var f: HFlowContainer = HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	for p: String in run.patches:
		f.add_child(_patch_chip(p))
	return f


## LEFT: the wave decks (W1-W3) and the face-up boss.
func _build_waves(run: DDRun) -> Control:
	var v: VBoxContainer = DDUi.vbox(6)
	v.add_child(DDUi.label("WAVES", DDUi.FONT_S - 4, DDUi.TEXT_DIM))
	for w: int in run.wave_count():
		var ws: Dictionary = DDPayloads.wave_spec(run, w)
		ws["art_keys"] = Art.deck_back_keys("wave")
		ws["art_tint"] = 0.75
		var wv: DDCardView = _view(ws, Vector2(0, 48))
		wv.index = IDX_WAVE + w
		_wave_views.append(wv)
		v.add_child(wv)
	var bs: Dictionary = DDPayloads.boss_spec(run)
	bs["art_keys"] = Art.finale_keys(run.district())
	bs["art_tint"] = 0.6
	var bv: DDCardView = _view(bs, Vector2(0, 64))
	bv.index = IDX_BOSS
	bv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_boss_view = bv
	v.add_child(bv)
	return v


## MIDDLE (top): the mixed draw pile (+ Lookout's top card).
func _build_pile(run: DDRun) -> Control:
	var v: VBoxContainer = DDUi.vbox(6)
	if portrait:
		v.add_child(DDUi.label(str(run.district().get("name", "")).to_upper(), DDUi.FONT_S - 4, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	var ps: Dictionary = DDPayloads.pile_spec(run)
	ps["art_keys"] = Art.deck_back_keys("pile")
	ps["art_tint"] = 0.7
	if not portrait:
		ps["title"] = "%s - %d zombies" % [str(run.district().get("name", "")), run.pile_zombies()]
	var pv: DDCardView = _view(ps, Vector2(0, 92 if portrait else 56))
	pv.index = IDX_PILE
	pv.size_flags_vertical = Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_FILL
	_pile_view = pv
	v.add_child(pv)
	if portrait:
		var lk: Control = _build_lookout(run)
		if lk != null:
			v.add_child(lk)
	return v


## Lookout Patch: the pile's top card + BURY (once per street).
func _build_lookout(run: DDRun) -> Control:
	var lc: DDCard = run.lookout_card()
	if lc != null:
		var row: HBoxContainer = DDUi.hbox(4)
		row.add_child(_view({"kind": lc.kind, "tag": "TOP", "big": str(lc.value) if lc.kind != DDCard.WEAPON else "", "big_size": 20, "row": true,
			"title": DDText.card_name(lc, Game.bal), "title_size": DDUi.FONT_S - 7, "payload": DDPayloads.card(lc, run)}, Vector2(80, 40)))
		var bb: Button = DDUi.button("BURY" if run.can_bury() else "buried", DDUi.PANEL_HI, DDUi.FONT_S - 4)
		bb.name = "BuryButton"
		bb.custom_minimum_size = Vector2(64, 44)
		bb.disabled = not run.can_bury() or busy
		bb.tooltip_text = "Lookout: send the top card to the bottom (once per street)"
		bb.pressed.connect(do_bury)
		row.add_child(bb)
		return row
	return null


## RIGHT: the 3 room decks, each with its price and OPEN (or its machine's USE).
func _build_rooms(run: DDRun) -> Control:
	var v: VBoxContainer = DDUi.vbox(6)
	v.add_child(DDUi.label("ROOMS", DDUi.FONT_S - 4, DDUi.TEXT_DIM))
	var did: String = str(run.district().get("id", ""))
	for i: int in run.room_count():
		var box: BoxContainer = BoxContainer.new()
		box.vertical = false
		box.add_theme_constant_override("separation", 4)
		var rs: Dictionary = DDPayloads.room_spec(run, i)
		var r: Dictionary = run.room(i)
		rs["art_keys"] = Art.machine_keys(run.machine(i)) if run.room_open[i] else Art.room_keys(did, str(r.get("name", "")))
		rs["art_tint"] = 0.6
		var rv: DDCardView = _view(rs, Vector2(0, 60))
		rv.index = IDX_ROOM + i
		rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_room_views.append(rv)
		box.add_child(rv)
		var b: Button
		if not run.room_open[i]:
			var afford: bool = run.can_open_room(i)
			b = DDUi.button("OPEN\n%d" % Game.bal.shown(run.room_cost(i)), Color("7a5a1d") if afford else DDUi.PANEL, DDUi.FONT_S - 4)
			b.name = "Open%d" % i
			b.disabled = not afford or busy
			b.pressed.connect(func() -> void: do_open_room(i))
		else:
			var used: bool = run.machine_used[i]
			b = DDUi.button("USE" if not used else "used", Color("3d4f2a") if not used else DDUi.PANEL, DDUi.FONT_S - 4)
			b.name = "Use%d" % i
			b.disabled = used or busy or not run.pending_patch.is_empty()
			b.pressed.connect(func() -> void: open_machine(i))
		b.custom_minimum_size = Vector2(66, 60)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		box.add_child(b)
		v.add_child(box)
	return v


func _build_street_row(run: DDRun, card_w: float, card_h: float) -> Control:
	var h: HBoxContainer = DDUi.hbox(SEP)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var did: String = str(run.district().get("id", ""))
	for i: int in run.street.size():
		var c: DDCard = run.street[i]
		var spec: Dictionary = DDPayloads.street_card_spec(c, i, run)
		spec["art_keys"] = Art.card_keys(c, did)
		var cv: DDCardView = _view(spec, Vector2(card_w, card_h))
		cv.index = i
		cv.tapped.connect(_on_card_tapped)
		h.add_child(cv)
		var cid: int = c.get_instance_id()
		_street_views[cid] = cv
		_street_specs[cid] = spec
		_street_cards[cid] = c
		_street_order.append(cid)
	return h


## The prompt (what to do / what the active weapon does), resolve pips, Run / Run past.
func _build_actions(run: DDRun) -> Control:
	var h: HBoxContainer = DDUi.hbox(SEP)
	var p: PanelContainer = DDUi.panel(DDUi.PANEL, 6)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pv: VBoxContainer = DDUi.vbox(0)
	p.add_child(pv)
	var act: String = "MELEE (Crowbar)" if run.active == DDRun.MELEE else (run.slot(run.active).name.to_upper() if run.slot(run.active) != null else "-")
	var prompt: String
	if run.boss_street:
		prompt = "BOSS STREET: resolve every card (%d left). Active: %s." % [run.cards_left_to_resolve(), act]
	elif run.resolved == 0:
		prompt = "Active: %s - tap a zombie to attack. Resolve %d of %d." % [act, run.budget, run.street.size()]
	else:
		prompt = "Active: %s. %d more to resolve this street." % [act, run.cards_left_to_resolve()]
	var pl: Label = DDUi.label(prompt, DDUi.FONT_S - 3, DDUi.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	pv.add_child(pl)
	if not run.boss_street:
		pv.add_child(_resolve_pips(run))
	if portrait:
		pv.add_child(DDUi.label(last_block if last_block != "" else str(last_event.get("text", "")), DDUi.FONT_S - 6, DDUi.WARN if last_block != "" else DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true))
	h.add_child(p)
	if run.boss_street and run.is_final_district():
		var ne: PanelContainer = DDUi.panel(Color("3b1414"), 8, DDUi.BAD, 3)
		var tex: Texture2D = Art.texture_for(Art.badge_keys("no_escape"))
		var nh: HBoxContainer = DDUi.hbox(4)
		ne.add_child(nh)
		if tex != null:
			var tr: TextureRect = TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(32, 32)
			nh.add_child(tr)
		nh.add_child(DDUi.label("NO ESCAPE", DDUi.FONT_S, DDUi.BAD))
		ne.name = "NoEscape"
		h.add_child(ne)
	elif run.boss_street:
		var rp: Button = DDUi.button("RUN PAST\n-%d HP, no reward" % Game.bal.num("boss_runpast_damage"), Color("5a2a1a"), DDUi.FONT_S - 5)
		rp.name = "RunPast"
		rp.custom_minimum_size = Vector2(130, 56)
		rp.disabled = not run.can_run_past() or busy
		rp.pressed.connect(do_run_past)
		h.add_child(rp)
	else:
		var why: String = run.run_block_reason()
		var cost: int = run.run_cost()
		var rb: Button = DDUi.button(("RUN  -%d HP" % cost if cost > 0 else "RUN  free") + ("\n" + why if why != "" else "\nshuffle back"), Color("5a2a1a") if why == "" else DDUi.PANEL, DDUi.FONT_S - 5)
		rb.name = "Run"
		rb.custom_minimum_size = Vector2(130, 56)
		rb.disabled = why != "" or busy
		rb.pressed.connect(do_run)
		h.add_child(rb)
	return h


## The street's resolve pips: one dot per card you may resolve, filled as you resolve them.
func _resolve_pips(run: DDRun) -> Control:
	var h: HBoxContainer = DDUi.hbox(5)
	h.name = "ResolvePips"
	h.add_child(DDUi.label("resolves", DDUi.FONT_S - 6, DDUi.TEXT_DIM))
	for k: int in run.budget:
		var done: bool = k < run.resolved
		var dot: Panel = Panel.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_theme_stylebox_override("panel", DDUi.box(DDUi.SELECT if done else Color(0, 0, 0, 0), DDUi.SELECT if done else DDUi.TEXT_DIM, 2, 7, 0))
		dot.set_meta(&"filled", done)
		h.add_child(dot)
	return h


## BOTTOM: the two gun cards (kill stacks) (+ the melee tile in landscape).
func _build_guns(run: DDRun, vertical: bool, mini: Vector2, gun_h: float) -> Control:
	var h: HBoxContainer = DDUi.hbox(SEP)
	for s: int in 2:
		var spec: Dictionary = DDPayloads.gun_spec(run, s)
		spec["fan_vertical"] = vertical
		spec["mini"] = mini
		var gv: DDGunView = DDGunView.new()
		gv.setup_gun(spec)
		gv.custom_minimum_size = Vector2(0, gun_h)
		gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gv.index = IDX_GUN + s
		gv.inspected.connect(_on_inspect)
		gv.tapped.connect(func(_v: DDCardView) -> void: tap_weapon(s))
		for k: int in gv.stack_cards.size():
			gv.stack_cards[k].index = IDX_STACK + s * 10 + k
		_gun_views[s] = gv
		h.add_child(gv)
	if not portrait:
		var mv: DDCardView = _melee_tile(run)
		mv.custom_minimum_size = Vector2(118, gun_h)
		h.add_child(mv)
	return h


func _melee_tile(run: DDRun) -> DDCardView:
	var on: bool = run.active == DDRun.MELEE
	var mv: DDCardView = _view({"kind": "K", "tag": "MELEE", "badge": "ACTIVE" if on else "", "badge_color": DDUi.SELECT,
		"big": "P%d" % run.melee_power(), "big_size": 24, "title": "Crowbar", "lines": [["no rule, 0 pts", DDUi.TEXT_DIM, DDUi.FONT_S - 6]],
		"selected": on, "compact": true, "payload": DDPayloads.melee(run), "art_keys": Art.weapon_keys("crowbar", "Crowbar"), "art_tint": 0.7})
	mv.index = IDX_MELEE
	mv.tapped.connect(func(_v: DDCardView) -> void: tap_weapon(DDRun.MELEE))
	_melee_view = mv
	return mv


## Portrait: the melee tile + the log line.
func _build_bottom(run: DDRun, _p: bool) -> Control:
	var h: HBoxContainer = DDUi.hbox(SEP)
	var mv: DDCardView = _melee_tile(run)
	mv.custom_minimum_size = Vector2(190, 64)
	mv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(mv)
	var log_box: Control = _build_log(run)
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(log_box)
	return h


func _build_log(run: DDRun) -> Control:
	var p: PanelContainer = DDUi.panel(Color("181c1e"), 6)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v: VBoxContainer = DDUi.vbox(0)
	p.add_child(v)
	var lines: Array[String] = run.log_lines.slice(maxi(0, run.log_lines.size() - (2 if portrait else 5)))
	for k: int in lines.size():
		v.add_child(DDUi.label(lines[k], DDUi.FONT_S - 6, DDUi.TEXT if k == lines.size() - 1 else DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true))
	p.name = "Log"
	return p


# ---------------------------------------------------------------- first-run hints (K5)
func _due_hint(run: DDRun) -> String:
	if not hints_enabled or Game.profile == null or not Game.profile.first_run() or run.phase != DDRun.Phase.STREET:
		return ""
	var order: Array[String] = ["weapon"]
	if run.active != DDRun.MELEE and run.slot(run.active) != null:
		order.append("rule_" + run.slot(run.active).wid)
	for s: int in 2:
		if run.slot(s) != null and run.slot(s).kills_left() == 1:
			order.append("finish")
	if int(run.stats.get("challenges", 0)) > 0:
		order.append("challenge")
	if int(run.stats.get("gun_kills", 0)) > 0:
		order.append("points")
	for i: int in run.room_count():
		if run.can_open_room(i):
			order.append("rooms")
	for h: String in order:
		if Game.profile.hint_due(h):
			return h
	return ""


func _build_hint(run: DDRun) -> Control:
	var p: PanelContainer = DDUi.panel(Color("1d2b3a"), 6, DDUi.accent("W"), 2)
	p.name = "Hint"
	var h: HBoxContainer = DDUi.hbox(6)
	p.add_child(h)
	h.add_child(DDUi.label("TIP", DDUi.FONT_S - 4, DDUi.accent("W")))
	var l: Label = DDUi.label(DDText.hint_text(hint_id, run.bal), DDUi.FONT_S - 4, DDUi.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var ok: Button = DDUi.button("Got it", DDUi.PANEL_HI, DDUi.FONT_S - 4)
	ok.name = "HintOk"
	ok.custom_minimum_size = Vector2(80, 48)
	ok.pressed.connect(dismiss_hint)
	h.add_child(ok)
	return p


func dismiss_hint() -> void:
	if hint_id != "":
		Game.profile.mark_hint(hint_id)
		hint_id = ""
	_queue_render()


# ---------------------------------------------------------------- sheets (gun card, machines, Patch pick)
func _build_sheet() -> void:
	var run: DDRun = Game.run
	if run == null:
		return
	var kind: String = ""
	if not run.pending_patch.is_empty():
		kind = "patch"
	elif not sheet.is_empty():
		kind = str(sheet.get("type", ""))
	if kind == "":
		return
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	if kind != "patch":
		dim.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				close_sheet())
	_sheet_root.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet_root.add_child(center)
	var vp: Vector2 = get_viewport_rect().size
	var panel: PanelContainer = DDUi.panel(DDUi.PANEL, 14, DDUi.SELECT, 2)
	panel.name = "Sheet"
	panel.custom_minimum_size = Vector2(minf(vp.x - 32.0, 620.0 if portrait else 900.0), 0)
	center.add_child(panel)
	var v: VBoxContainer = DDUi.vbox(8)
	panel.add_child(v)
	match kind:
		"gun":
			_gun_sheet(run, v, int(sheet.get("index", 0)))
		"machine":
			_machine_sheet(run, v, int(sheet.get("room", 0)))
		"patch":
			_patch_sheet(run, v)


func _sheet_button(text: String, enabled: bool, color: Color, cb: Callable) -> Button:
	var b: Button = DDUi.button(text, color if enabled else DDUi.PANEL, DDUi.FONT_S - 2)
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


func _gun_sheet(run: DDRun, v: VBoxContainer, i: int) -> void:
	if i < 0 or i >= run.street.size() or run.street[i].kind != DDCard.WEAPON:
		sheet = {}
		return
	var c: DDCard = run.street[i]
	var top: BoxContainer = BoxContainer.new()
	top.vertical = portrait
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var gp: Dictionary = DDPayloads.gun_def(c.wid, Game.bal, "NEW GUN", run.steady())
	top.add_child(_view({"kind": "W", "tag": "GUN", "big": "P%d" % Game.bal.weapon_power(c.wid), "big_size": 30, "title": Game.bal.weapon_name(c.wid),
		"compact": true, "payload": gp, "art_keys": Art.weapon_keys(c.wid, Game.bal.weapon_name(c.wid))}, Vector2(170, 130)))
	var txt: Label = DDUi.label(DDText.gun_card_text(c.wid, Game.bal, run.steady()), DDUi.FONT_S - 3, DDUi.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.custom_minimum_size = Vector2(240, 0)
	top.add_child(txt)
	var row: BoxContainer = BoxContainer.new()
	row.vertical = portrait
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for s: int in 2:
		var pv: Dictionary = run.card_preview(i, DDRun.EQUIP1 if s == 0 else DDRun.EQUIP2)
		var g: DDGun = run.slot(s)
		var label: String = "INTO SLOT %d" % (s + 1)
		if g != null:
			label += "\nreplaces %s%s" % [g.name, (" (stack %s discarded)" % DDText.zombie_list(g.stack)) if not g.stack.is_empty() else ""]
		else:
			label += "\n(empty)"
		row.add_child(_sheet_button(label, bool(pv["ok"]), Color("1f4a63"), func() -> void: do_resolve(i, DDRun.EQUIP1 if s == 0 else DDRun.EQUIP2)))
	var ps: Dictionary = run.card_preview(i, DDRun.SCRAP)
	row.add_child(_sheet_button("SCRAP +%d" % Game.bal.shown(int(ps.get("points", 0))), bool(ps["ok"]), Color("5a4a1d"), func() -> void: do_resolve(i, DDRun.SCRAP)))
	v.add_child(_sheet_button("Cancel", true, DDUi.PANEL_HI, close_sheet))


func _machine_sheet(run: DDRun, v: VBoxContainer, i: int) -> void:
	var m: Dictionary = run.machine(i)
	var kind: String = str(m.get("kind", ""))
	var head: HBoxContainer = DDUi.hbox(10)
	v.add_child(head)
	var tex: Texture2D = Art.texture_for(Art.machine_keys(m))
	if tex != null:
		var tr: TextureRect = TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(96, 72)
		head.add_child(tr)
	var hv: VBoxContainer = DDUi.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	hv.add_child(DDUi.label(DDText.machine_name(kind).to_upper() + " - " + str(run.room(i).get("name", "")), DDUi.FONT_M, DDUi.accent("K")))
	hv.add_child(DDUi.label("Once per wave. You have %d points." % Game.bal.shown(run.points), DDUi.FONT_S - 3, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3 if kind == "bench" else (2 if kind == "wall" else 1)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for o: Dictionary in run.machine_options(i):
		var t: String = "%s - %d" % [str(o["label"]), Game.bal.shown(int(o["price"]))]
		var res: String = str(o["result"]) if bool(o["enabled"]) else str(o["reason"])
		var b: Button = _sheet_button(t + ("\n" + res if res != "" else ""), bool(o["enabled"]) and not busy, Color("3d4f2a"), func() -> void: do_machine(i, str(o["id"])))
		b.add_theme_font_size_override("font_size", DDUi.FONT_S - 5)
		b.custom_minimum_size = Vector2(0, 84)
		grid.add_child(b)
	if kind == "wall":
		v.add_child(DDUi.label(DDText.gun_card_text(str(m.get("wid", "")), Game.bal, run.steady()), DDUi.FONT_S - 4, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true))
	v.add_child(_sheet_button("Close", true, DDUi.PANEL_HI, close_sheet))


func _patch_sheet(run: DDRun, v: VBoxContainer) -> void:
	var src: String = str(run.pending_patch.get("source", ""))
	v.add_child(DDUi.label("PATCH PRESS: pick 1 Patch (permanent for the run)" if src == "press" else "PICK A PATCH", DDUi.FONT_M, DDUi.accent("P"), HORIZONTAL_ALIGNMENT_CENTER, true))
	var row: BoxContainer = BoxContainer.new()
	row.vertical = portrait
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for p: Variant in run.pending_patch.get("offer", []):
		var pid: String = str(p)
		var spec: Dictionary = DDPayloads.patch_spec(pid, Game.bal, false)
		spec["art_keys"] = Art.patch_keys(pid)
		spec["art_fit"] = "contain"
		var cv: DDCardView = _view(spec, Vector2(0, 110 if portrait else 200))
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.tapped.connect(func(_x: DDCardView) -> void: do_take_patch(pid))
		row.add_child(cv)
		var b: Button = _sheet_button("TAKE %s" % DDText.patch_name(pid).to_upper(), not busy, Color("2f2f5a"), func() -> void: do_take_patch(pid))
		b.custom_minimum_size = Vector2(0, 56)
		if portrait:
			row.add_child(b)
	if not portrait:
		var brow: HBoxContainer = DDUi.hbox(8)
		v.add_child(brow)
		for p2: Variant in run.pending_patch.get("offer", []):
			var pid2: String = str(p2)
			brow.add_child(_sheet_button("TAKE %s" % DDText.patch_name(pid2).to_upper(), not busy, Color("2f2f5a"), func() -> void: do_take_patch(pid2)))


func close_sheet() -> void:
	sheet = {}
	_queue_render()


# ================================================================ input -> rules
func _on_card_tapped(v: DDCardView) -> void:
	tap_street(v.index)


## A tap on street card i: zombies are attacked with the active weapon; medkit / cover are used;
## a gun card opens the 3-button sheet.
func tap_street(i: int) -> void:
	var run: DDRun = Game.run
	if busy or run == null or i < 0 or i >= run.street.size() or not run.pending_patch.is_empty():
		return
	var c: DDCard = run.street[i]
	match c.kind:
		DDCard.ZOMBIE:
			var pr: Dictionary = run.preview(i, run.active)
			if not bool(pr["ok"]):
				last_block = "Can't: %s. Tap another weapon below, or melee." % str(pr["reason"])
				Sfx.cue(&"warn")
				var cv: DDCardView = _street_views.get(c.get_instance_id())
				if cv != null:
					feedback._wobble(cv)
					feedback._pulse(cv, Color(1.6, 0.6, 0.6))
				for s: int in 2:
					if s == run.active and _gun_views[s] != null:
						feedback._pulse(_gun_views[s], Color(1.6, 1.4, 0.6))
				_queue_render()
				return
			var snap: Dictionary = _snapshot()
			var ev: Dictionary = run.attack(i)
			_finish(ev, {"type": "attack", "ev": ev, "snap": snap})
		DDCard.WEAPON:
			sheet = {"type": "gun", "index": i}
			Sfx.cue(&"button", 0.9)
			_queue_render()
		_:
			do_resolve(i, DDRun.USE)


func tap_weapon(w: int) -> void:
	var run: DDRun = Game.run
	if busy or run == null:
		return
	if w != DDRun.MELEE and run.slot(w) == null:
		_inspect.open(DDPayloads.gun(run, w))
		return
	if run.active != w:
		run.set_active(w)
		Sfx.cue(&"equip", 1.2)
		Game.save_run()
	last_block = ""
	_queue_render()


func do_resolve(i: int, choice: String) -> void:
	if busy:
		return
	var run: DDRun = Game.run
	var snap: Dictionary = _snapshot()
	sheet = {}
	var ev: Dictionary = run.resolve(i, choice)
	_finish(ev, {"type": "card", "ev": ev, "snap": snap})


func do_run() -> void:
	if busy:
		return
	var snap: Dictionary = _snapshot()
	var ev: Dictionary = Game.run.run_street()
	_finish(ev, {"type": "run", "ev": ev, "snap": snap})


func do_run_past() -> void:
	if busy:
		return
	var ev: Dictionary = Game.run.run_past()
	_finish(ev, {"type": "run", "ev": ev, "snap": _snapshot()})


func do_bury() -> void:
	if busy:
		return
	var ev: Dictionary = Game.run.bury_top()
	if bool(ev.get("ok", false)):
		Sfx.cue(&"flip", 0.8)
	_finish(ev, {})


func do_open_room(i: int) -> void:
	if busy:
		return
	var snap: Dictionary = _snapshot()
	var ev: Dictionary = Game.run.open_room(i)
	if bool(ev.get("ok", false)):
		_pending_banner = {"text": "%s OPEN" % str(Game.run.room(i).get("name", "")).to_upper(), "color": DDUi.accent("K"),
			"sub": "3 cards shuffle into the pile. The %s is on: tap USE." % DDText.machine_name(str(Game.run.machine(i).get("kind", ""))), "delay": 0.5}
	_finish(ev, {"type": "room", "ev": ev, "snap": snap})


func open_machine(i: int) -> void:
	if busy:
		return
	sheet = {"type": "machine", "room": i}
	Sfx.cue(&"button", 0.9)
	_queue_render()


func do_machine(i: int, oid: String) -> void:
	if busy:
		return
	var run: DDRun = Game.run
	var snap: Dictionary = _snapshot()
	var ev: Dictionary = run.use_machine(i, oid)
	if not bool(ev.get("ok", false)):
		return
	sheet = {}
	var res: Dictionary = ev.get("result", {})
	if res.has("gun"):
		var g: DDGun = res["gun"]
		var s: int = int(res.get("slot", 0))
		var p: Dictionary = DDPayloads.gun(run, s)
		p["tag"] = "%s - RESULT" % DDText.machine_name(str(res.get("machine", ""))).to_upper()
		p["body"] = str(ev.get("text", "")) + "\n\n" + str(p["body"])
		var tex: Texture2D = Art.texture_for(Art.weapon_keys(g.wid, g.name))
		if tex != null:
			p["art"] = tex
		_auto_inspect = p
	_finish(ev, {"type": "machine", "ev": ev, "snap": snap})


func do_take_patch(id: String) -> void:
	if busy:
		return
	var ev: Dictionary = Game.run.take_patch(id)
	if bool(ev.get("ok", false)):
		Sfx.cue(&"perk")
		var p: Dictionary = DDPayloads.patch(id, Game.bal)
		p["tag"] = "PATCH SEWN ON"
		var tex: Texture2D = Art.texture_for(Art.patch_keys(id))
		if tex != null:
			p["art"] = tex
		_auto_inspect = p
	_finish(ev, {})


func _finish(ev: Dictionary, fx: Dictionary) -> void:
	if not bool(ev.get("ok", false)):
		last_block = str(ev.get("reason", ""))
		_queue_render()
		return
	last_event = ev
	last_block = ""
	# a hint is learned once the player acts with it on screen (or taps Got it)
	if hint_id != "":
		Game.profile.mark_hint(hint_id)
	_pending_fx = fx
	_after_event(ev)


func _after_event(ev: Dictionary) -> void:
	var run: DDRun = Game.run
	var waves: Array = ev.get("waves", [])
	if not waves.is_empty():
		var info: Dictionary = waves[waves.size() - 1]
		_pending_banner = {"text": "WAVE %d - %d cards, zombies %s" % [int(info["wave"]) + 1, int(info.get("cards", 0)), DDText.zombie_range(info.get("zombies", []))],
			"color": DDUi.TEXT, "sub": "The pile ran dry: the next wave deck shuffles in%s." % ((" + %d restock from opened rooms" % int(info["restock"])) if int(info.get("restock", 0)) > 0 else ""), "delay": 0.2}
		Sfx.cue(&"clear", 0.9)
	if bool(ev.get("boss_street", false)):
		var b: Dictionary = run.boss_def()
		_pending_banner = {"text": ("%s - NO ESCAPE" if run.is_final_district() else "BOSS: %s") % str(b.get("name", "")).to_upper(),
			"color": DDUi.BAD if run.is_final_district() else DDUi.accent("F"), "sub": DDText.trait_text(str(b.get("trait", ""))), "delay": 0.3}
	for info2: Variant in ev.get("collects", []):
		if bool((info2 as Dictionary).get("challenge", false)):
			Sfx.cue(&"perk")
	if run.phase == DDRun.Phase.DEAD or run.phase == DDRun.Phase.WON or run.phase == DDRun.Phase.SAFEHOUSE:
		busy = true
		_pending_banner = {}
		_queue_render()
		var hold: float = 0.9
		for info3: Variant in ev.get("collects", []):
			hold = maxf(hold, 1.6 if bool((info3 as Dictionary).get("challenge", false)) else 1.2)
		await get_tree().create_timer(hold).timeout
		busy = false
		if run.phase == DDRun.Phase.SAFEHOUSE:
			screen = Screen.SAFEHOUSE
			chosen_patch = ""
			_screen_fx = "safehouse"
			Game.save_run("SAFEHOUSE")
		else:
			screen = Screen.END
			_screen_fx = "end_won" if run.phase == DDRun.Phase.WON else "end_dead"
			if not Game.new_unlocks.is_empty():
				_auto_inspect = DDPayloads.unlock(Game.new_unlocks[0], Game.bal, Game.profile)
		_queue_render()
		return
	_queue_render()


# ---------------------------------------------------------------- banner
var last_banner: String = ""
var _banner: Control = null


func banner_open() -> bool:
	return _banner != null and is_instance_valid(_banner) and not _banner.is_queued_for_deletion()


func dismiss_banner() -> void:
	if banner_open():
		_banner.queue_free()
	_banner = null
	if OS.has_feature("web"):
		_publish_state.call_deferred()


func _show_banner(text: String, col: Color, sub: String) -> void:
	last_banner = text
	var vp: Vector2 = get_viewport_rect().size
	if _banner != null and is_instance_valid(_banner):
		_banner.queue_free()
	var p: PanelContainer = DDUi.panel(Color(0.05, 0.06, 0.06, 0.92), 14, col, 3)
	_banner = p
	var v: VBoxContainer = DDUi.vbox(2)
	p.add_child(v)
	var lw: float = minf(vp.x - 40.0, 900.0) - 34.0
	var l1: Label = DDUi.label(text, DDUi.FONT_L, col, HORIZONTAL_ALIGNMENT_CENTER, true)
	l1.custom_minimum_size = Vector2(lw, 0)
	v.add_child(l1)
	if sub != "":
		var l2: Label = DDUi.label(sub, DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true)
		l2.custom_minimum_size = Vector2(lw, 0)
		v.add_child(l2)
	DDUi.ignore_mouse(p)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and is_instance_valid(p):
			p.accept_event()
			dismiss_banner())
	_fx.add_child(p)
	p.size = p.get_combined_minimum_size()
	p.position = Vector2((vp.x - p.size.x) * 0.5, vp.y * 0.3)
	p.modulate.a = 0.0
	var tw: Tween = p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.5 if not Game.reduce_motion() else 1.7)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


# ---------------------------------------------------------------- safehouse
func _build_safehouse() -> void:
	var run: DDRun = Game.run
	var v: VBoxContainer = DDUi.vbox(10 if portrait else 6)
	_content.add_child(_scroll(v))
	var last: Dictionary = run.boss_results[run.boss_results.size() - 1] if not run.boss_results.is_empty() else {}
	var dname: String = str(Game.bal.district(run.district_index).get("name", ""))
	var head: Label = DDUi.label(("%s CLEARED" if not bool(last.get("ran_past", false)) else "YOU RAN PAST %s") % (dname.to_upper() if not bool(last.get("ran_past", false)) else str(last.get("name", "")).to_upper()), DDUi.FONT_XL if portrait else DDUi.FONT_L, DDUi.GOOD, HORIZONTAL_ALIGNMENT_CENTER, true)
	_screen_title = head
	v.add_child(head)
	v.add_child(DDUi.label("SAFEHOUSE: you rest, +%d HP when you head out (HP now %d / %d). Guns, points and Patches carry on; rooms and the pile reset. Points %d." % [run.safehouse_heal(), run.hp, run.max_hp, Game.bal.shown(run.points)], DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	var kit: HBoxContainer = DDUi.hbox(SEP)
	v.add_child(kit)
	for s: int in 2:
		var spec: Dictionary = DDPayloads.gun_spec(run, s)
		spec["fan_vertical"] = false
		spec["mini"] = Vector2(40, 52)
		var gv: DDGunView = DDGunView.new()
		gv.setup_gun(spec)
		gv.custom_minimum_size = Vector2(0, 110)
		gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gv.inspected.connect(_on_inspect)
		kit.add_child(gv)
	if not run.patches.is_empty():
		v.add_child(_patch_row(run))
	var offer: Array = run.pending_patch.get("offer", [])
	if not offer.is_empty():
		v.add_child(DDUi.label("BOSS REWARD: pick 1 free Patch (long press to read)", DDUi.FONT_M, DDUi.accent("P"), HORIZONTAL_ALIGNMENT_CENTER, true))
		var box: BoxContainer = BoxContainer.new()
		box.vertical = portrait
		box.add_theme_constant_override("separation", SEP)
		v.add_child(box)
		for p: Variant in offer:
			var pid: String = str(p)
			var ps: Dictionary = DDPayloads.patch_spec(pid, Game.bal, false)
			ps["selected"] = pid == chosen_patch
			ps["art_keys"] = Art.patch_keys(pid)
			ps["art_fit"] = "contain"
			var cv: DDCardView = _view(ps, Vector2(0, 104 if portrait else 150))
			cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cv.tapped.connect(func(_x: DDCardView) -> void:
				if chosen_patch != pid:
					Sfx.cue(&"flip", 1.1)
				chosen_patch = pid
				_queue_render())
			box.add_child(cv)
	var nxt: String = str(Game.bal.district(run.district_index + 1).get("name", ""))
	var label: String = ("Head to %s (+%d HP)" % [nxt, run.safehouse_heal()]) if offer.is_empty() or chosen_patch != "" else "Tap a Patch to choose it"
	if not offer.is_empty() and chosen_patch != "":
		label = "Take %s, head to %s (+%d HP)" % [DDText.patch_name(chosen_patch), nxt, run.safehouse_heal()]
	var go: Button = DDUi.button(label, Color("245236"), DDUi.FONT_M)
	go.name = "LeaveSafehouse"
	go.custom_minimum_size = Vector2(0, 80 if portrait else DDUi.TAP_MIN)
	go.disabled = not offer.is_empty() and chosen_patch == ""
	go.pressed.connect(leave_safehouse)
	v.add_child(go)


func leave_safehouse() -> void:
	var run: DDRun = Game.run
	var ev: Dictionary = run.leave_safehouse(chosen_patch)
	if bool(ev.get("ok", false)):
		last_event = ev
		if chosen_patch != "":
			Sfx.cue(&"perk")
		chosen_patch = ""
		screen = Screen.MAP
		Game.save_run("MAP")
		_queue_render()


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
	var where: String = "%s escaped the city." % str(s.get("name", "")) if won else "%s fell in %s%s." % [str(s.get("name", "")), str(run.district().get("name", "")),
		" at the boss" if run.boss_street else ", wave %d" % (run.wave_index + 1)]
	v.add_child(DDUi.label(where, DDUi.FONT_M, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	if not won and not last_event.is_empty():
		v.add_child(DDUi.label("Last: " + str(last_event.get("text", "")), DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	var sc: PanelContainer = DDUi.panel(DDUi.PANEL, 14)
	var sv: VBoxContainer = DDUi.vbox(4)
	sc.add_child(sv)
	sv.add_child(DDUi.label("Points earned: %d" % Game.bal.shown(run.points_earned), DDUi.FONT_M, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	if won:
		sv.add_child(DDUi.label("HP left: %d  (+%d)" % [run.hp, Game.bal.shown(run.hp * Game.bal.rule("score_hp_mult"))], DDUi.FONT_M, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	sv.add_child(DDUi.label("RUN SCORE %d" % Game.bal.shown(run.run_score()), DDUi.FONT_XL, DDUi.WARN, HORIZONTAL_ALIGNMENT_CENTER))
	var st: Dictionary = run.stats
	sv.add_child(DDUi.label("Best with %s: %d   -   %d kills, %d guns finished, %d challenges, %d rooms, %d runs" % [run.survivor_id.capitalize(),
		Game.bal.shown(Game.profile.best_score(run.survivor_id)), int(st.get("kills", 0)), int(st.get("finished", 0)), int(st.get("challenges", 0)),
		int(st.get("rooms", 0)), int(st.get("runs", 0))], DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(sc)
	if not Game.new_unlocks.is_empty():
		v.add_child(DDUi.label("NEW UNLOCKS (long press / right click to zoom)", DDUi.FONT_M, DDUi.GOOD, HORIZONTAL_ALIGNMENT_CENTER, true))
		var row: HFlowContainer = HFlowContainer.new()
		row.alignment = FlowContainer.ALIGNMENT_CENTER
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
## Web only (QA screenshots): ?screen=street&seed=5 jumps to a screen with a seeded run.
## Street extras: &points=40 (sim units), &open=2 (rooms opened), &gun1=rifle &gun2=crossbow,
## &stack1=5,4 &stack2=..., &active=0|1|2, &patches=lookout,brawler, &district=0..2, &boss=1,
## &wave=1, &sheet=gun|machine0..2|patch, &inspect=pile|wave0|room0|gun1|gun2|stack|boss|melee|points,
## &hints=1 (first-run hints on), &near=1 (gun 1 one kill from finishing, a legal zombie dealt),
## &lastcards=1 (the pile runs dry after this street: wave 2 shuffles in).
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
			args[kv[0]] = kv[1].uri_decode()
	if args.has("screen"):
		apply_debug(args)


func _ints_arg(s: String) -> Array[int]:
	var out: Array[int] = []
	for p: String in s.split(","):
		if p.strip_edges() != "":
			out.append(int(p))
	return out


## Shared by the web smoke query and the headless UI tests.
func apply_debug(args: Dictionary) -> void:
	var sid: String = str(args.get("survivor", "rosa"))
	Game.start_run(sid, int(args.get("seed", "7")))
	var run: DDRun = Game.run
	hints_enabled = str(args.get("hints", "0")) == "1"
	sheet = {}
	if args.has("district"):
		run.district_index = clampi(int(args["district"]), 0, Game.bal.district_count() - 1)
		run._start_district()
	match str(args.get("screen", "street")):
		"map":
			screen = Screen.MAP
		"street":
			screen = Screen.STREET
		"safehouse":
			run.hp = run.max_hp
			run.wave_index = run.wave_count() - 1
			run.setup_street([], [])
			run.cover = 50
			for k: int in 3:
				if run.phase == DDRun.Phase.STREET and not run.street.is_empty():
					run.attack(0, DDRun.MELEE)
			screen = Screen.SAFEHOUSE
		"end":
			run.setup_street(["Z11", "Z11", "C2", "C2", "C2", "C2"])
			run.hp = 2
			run.set_active(DDRun.MELEE)
			last_event = run.attack(0)
			Game.sync_profile()
			screen = Screen.END
	if screen != Screen.STREET:
		return
	if args.has("points"):
		run.points = int(args["points"])
	for k: int in int(args.get("open", "0")):
		run.points += run.room_cost(k)
		run.open_room(k)
	for s: int in 2:
		var key: String = "gun%d" % (s + 1)
		if args.has(key):
			run.slots[s] = run.make_gun(str(args[key])) if str(args[key]) != "none" else null
		var sk: String = "stack%d" % (s + 1)
		if args.has(sk) and run.slot(s) != null:
			run.slot(s).stack = _ints_arg(str(args[sk]))
	if args.has("patches"):
		for p: String in str(args["patches"]).split(","):
			if p != "" and not run.patches.has(p):
				run._add_patch(p)
	if args.has("wave"):
		run.wave_index = clampi(int(args["wave"]), 0, run.wave_count() - 1)
	if args.has("near") and run.slot(0) != null:
		var g: DDGun = run.slot(0)
		g.stack.clear()
		var zs: Array[int] = [5, 4, 3, 2, 1]
		if g.rule == "up":
			zs = [2, 3, 4, 5, 6]
		for k: int in g.cap - 1:
			g.stack.append(zs[k])
		var nz: int = 1 if g.rule != "up" else 7
		if g.rule == "any":
			nz = 6
		run.setup_street(["Z%d" % nz, "M4", "Z3", "C2", "Z5", "Z6", "Z2", "M3"])
		run.active = 0
	if args.has("lastcards"):
		# one card left in the pile after this street: the third resolve shuffles wave 2 in
		run.setup_street(["Z1", "Z2", "Z1", "Z3", "Z2"])
		run.active = DDRun.MELEE
	if args.has("boss"):
		run.wave_index = run.wave_count() - 1
		run.setup_street([], ["C2"])
	if args.has("active"):
		run.set_active(int(args["active"]))
	if args.has("sheet"):
		var sh: String = str(args["sheet"])
		if sh == "gun":
			run.setup_street(["W:rifle", "Z5", "M4", "Z3", "Z2", "C2"])
			sheet = {"type": "gun", "index": 0}
		elif sh.begins_with("machine"):
			var ri: int = int(sh.trim_prefix("machine"))
			if not run.room_open[ri]:
				run.points += run.room_cost(ri)
				run.open_room(ri)
			run.points += 60
			sheet = {"type": "machine", "room": ri}
		elif sh == "patch":
			var ri2: int = -1
			for k: int in run.room_count():
				if str(run.machine(k).get("kind", "")) == "patch":
					ri2 = k
			if not run.room_open[ri2]:
				run.points += run.room_cost(ri2)
				run.open_room(ri2)
			run.points += run.bal.patch_price(run.patches.size())
			run.use_machine(ri2, "press")
	if args.has("inspect"):
		var what: String = str(args["inspect"])
		match what:
			"pile":
				_auto_inspect = DDPayloads.pile(run)
			"gun1":
				_auto_inspect = DDPayloads.gun(run, 0)
			"gun2":
				_auto_inspect = DDPayloads.gun(run, 1)
			"stack":
				if run.slot(0) != null and not run.slot(0).stack.is_empty():
					_auto_inspect = DDPayloads.stack_card(run, 0, 0)
			"boss":
				_auto_inspect = DDPayloads.boss(run)
			"melee":
				_auto_inspect = DDPayloads.melee(run)
			"points":
				_auto_inspect = DDPayloads.points(run)
			"zombie":
				for k: int in run.street.size():
					if run.street[k].kind == DDCard.ZOMBIE:
						_auto_inspect = DDPayloads.card(run.street[k], run, k)
						break
			_:
				if what.begins_with("wave"):
					_auto_inspect = DDPayloads.wave(run, int(what.trim_prefix("wave")))
				elif what.begins_with("room"):
					_auto_inspect = DDPayloads.room(run, int(what.trim_prefix("room")))


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
				e["name"] = str((n as Button).name)
				e["disabled"] = (n as Button).disabled
			else:
				e["type"] = "card"
				e["kind"] = (n as DDCardView).kind
				e["index"] = (n as DDCardView).index
				e["title"] = str((n as DDCardView).payload.get("title", ""))
				e["tag"] = str((n as DDCardView).payload.get("tag", ""))
			items.append(e)
	var st: Dictionary = {"screen": screen_name(), "portrait": portrait, "items": items, "inspect": _inspect.is_open(),
		"settings": settings_panel.is_open(), "fx": feedback.last_played, "banner": last_banner, "banner_open": banner_open(),
		"banner_rect": _css_rect(_banner, xf, dpr) if banner_open() else {}, "saved": Game.has_saved_run(), "hint": hint_id,
		"sheet": str(sheet.get("type", "")) if Game.run == null or Game.run.pending_patch.is_empty() else "patch", "block": last_block,
		"vw": get_viewport_rect().size.x, "vh": get_viewport_rect().size.y}
	if Game.run != null:
		var run: DDRun = Game.run
		st["hp"] = run.hp
		st["phase"] = DDRun.Phase.keys()[run.phase]
		st["log"] = str(last_event.get("text", ""))
		st["street"] = run.street.size()
		st["resolved"] = run.resolved + int(run.stats.get("streets", 0)) * 10
		st["wave"] = run.wave_index + 1
		st["pile"] = run.pile.size()
		st["points"] = Game.bal.shown(run.points)
		st["opened"] = run.room_open.count(true)
		st["active"] = run.active
		st["boss_street"] = run.boss_street
		st["finished"] = int(run.stats.get("finished", 0))
		var stacks: Array = []
		for g: Variant in run.slots:
			stacks.append((g as DDGun).stack.duplicate() if g != null else null)
		st["stacks"] = stacks
	JavaScriptBridge.eval("window.ddState = " + JSON.stringify(st) + ";", true)


func _css_rect(c: Control, xf: Transform2D, dpr: float) -> Dictionary:
	var r: Rect2 = c.get_global_rect()
	var p0: Vector2 = xf * r.position / dpr
	var p1: Vector2 = xf * r.end / dpr
	return {"x": p0.x, "y": p0.y, "w": p1.x - p0.x, "h": p1.y - p0.y}


func screen_name() -> String:
	return Screen.keys()[screen]

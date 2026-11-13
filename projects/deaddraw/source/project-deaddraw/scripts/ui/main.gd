# main.gd
# Purpose: The whole DeadDraw v3 ("Kill Stacks") UI: title (survivor pick), city map, street,
#   safehouse and run-end screens. Rebuilt from the run state after every action, laid out for
#   phone portrait or landscape from the viewport aspect. Rules live in DDRun; this script only
#   renders state, previews outcomes and calls the run's public methods.
#   The street (dd-ux-clean, the studio head's layout simplified): one focus per moment - the
#   street cards (biggest, with the damage chip) and the weapon you hit them with. Quieter around
#   them: the HUD (HP with Cover, points, one Patches chip, Menu), the WAVES as one stack (decks to
#   come + the next threat; the zoom lists them) with the boss under it on the LEFT, the mixed
#   PILE top middle, the 3 ROOMS on the RIGHT with the price on the OPEN button ("OPEN · 210 pts",
#   or "need 90 more"), the prompt bar (resolve pips, what to do now, what just happened; tap it
#   for the history), Run, and at the BOTTOM the 2 GUN cards (power, kills, rule icon + short label,
#   challenge reward, the kill stack) + MELEE. Portrait and landscape reflow the same pieces.
#   Active weapon: tap a gun / melee once, then every tap on a zombie attacks with it; each zombie
#   shows the damage you'd take ("-2") or LOCK with the reason before the tap. Gun cards on the
#   street open a slot 1 / slot 2 / scrap sheet; machines open a sheet with every service and
#   price; a Patch choice is a sheet you must answer. First-run hints (K5) are one short line.
#   Everything opens a zoom on right click / long press.
#   dd-feel: before each action it snapshots the street and the stacks; after the rebuild
#   scripts/fx/dd_feedback.gd animates kills onto stacks, collects, challenge stamps, wave / room
#   shuffle-ins, Run and the deal. Card art from the manifest (scripts/ui/dd_art.gd), else plain.
# Dependencies: Game (autoload), DDRun, DDGun, DDPayloads, DDCardView, DDGunView, DDInspect, DDUi,
#   DDText, scripts/fx/dd_feedback.gd, scripts/fx/dd_sfx.gd, scripts/ui/dd_art.gd,
#   scripts/ui/dd_settings_panel.gd.
# Author: Mechanics Developer Agent (feel primitives: Game Feel Engineer Agent; dd-ux-clean: UI/UX Agent)
extends Control

const Feedback: GDScript = preload("res://scripts/fx/dd_feedback.gd")
const Sfx: GDScript = preload("res://scripts/fx/dd_sfx.gd")
const Art: GDScript = preload("res://scripts/ui/dd_art.gd")
const SettingsPanel: GDScript = preload("res://scripts/ui/dd_settings_panel.gd")
const StackBox: GDScript = preload("res://scripts/ui/dd_stack_box.gd")
const Marks: GDScript = preload("res://scripts/ui/dd_marks.gd")
const Codex: GDScript = preload("res://scripts/ui/dd_codex.gd")

enum Screen { TITLE, MAP, STREET, SAFEHOUSE, END }

const MARGIN: int = 16
const SEP: int = 8
## dd-ux-clean: fixed heights of the street's quiet rows (HUD, prompt bar, first-run tip).
## 64 logical px = 44 CSS px on a 390 px wide phone (the 560 px base scales by 0.7): every button
## on the street is at least that tall.
const HUD_H: float = 64.0
const ACT_H: float = 64.0
const HINT_H: float = 64.0
## dd-ux-v4: the slim strip between the street and the guns (pile, what just happened, pips).
const STRIP_H: float = 56.0
const TAP: float = 64.0
## Room for rounding and wrapped text, so the bottom row never leaves the screen.
const SLACK: float = 12.0
## Indices DDCardView tiles carry (tests and the web smoke find tiles by them).
const IDX_ROOM: int = 100
const IDX_GUN: int = 200
const IDX_MELEE: int = 202
const IDX_WAVE: int = 300
const IDX_PILE: int = 400
const IDX_BOSS: int = 410
const IDX_POINTS: int = 420
const IDX_STACK: int = 500
## dd-ux-clean2 (U1): the logical base (the shorter side of the screen in logical px). Phones keep
## the 560 px base from project.godot (shorter side up to PHONE_CSS CSS px, so 64 logical px stays
## 44 CSS px). On bigger screens the street gets a bigger base, so a 1440x900 window lays it out on
## 1216x760 logical px instead of 896x560 (more room, text at its full size, no names shrunk to
## fit). The other screens keep the 560 base everywhere.
const BASE: int = 560
const PHONE_CSS: float = 600.0
const BASE_GROWTH: float = 0.667
## dd-ux-equip: the HUD's Patch icons (40 logical px = 28 CSS px on a phone) and the HP panel's
## narrowest width next to them.
const PATCH_ICON: float = 40.0
const HP_MIN_W: float = 112.0

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
var _backdrop: TextureRect
var _backdrop_scrim: ColorRect
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
var _fitting: bool = false
## dd-ux-v4: the Codex / Glossary overlay, and which rooms were affordable at the last render (a
## room that becomes affordable gets the two-ring pulse once).
var codex: Control = null
## dd-ux-equip: the street's drag and drop (scripts/ui/dd_drag.gd).
var drag: DDDrag = null
var _was_ready: Array = []
var _was_ready_run: Object = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = DDUi.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# dd-art-import: the painted title art behind the title screen (under a scrim so the text reads)
	_backdrop = TextureRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.visible = false
	add_child(_backdrop)
	_backdrop_scrim = ColorRect.new()
	_backdrop_scrim.color = Color(DDUi.BG, 0.6)
	_backdrop_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_scrim.visible = false
	add_child(_backdrop_scrim)
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
	# dd-ux-equip: the drag layer (the lifted card and the drop-target glows) over everything on the street
	drag = DDDrag.new()
	add_child(drag)
	drag.hover_changed.connect(func(h: String) -> void: _drag_verdicts(drag.info, h))
	drag.drag_finished.connect(func(_t: Dictionary) -> void: clear_kill_verdicts())
	codex = Codex.new()
	codex.name = "Codex"
	add_child(codex)
	codex.inspect_requested.connect(func(p: Dictionary) -> void: _inspect.open(p))
	_inspect = DDInspect.new()
	add_child(_inspect)
	settings_panel = SettingsPanel.new()
	settings_panel.name = "Settings"
	add_child(settings_panel)
	settings_panel.codex_requested.connect(open_codex)
	settings_panel.help_requested.connect(open_glossary)
	feedback = Feedback.new()
	feedback.name = "Feedback"
	add_child(feedback)
	feedback.setup(_fx, _content)
	_sync_feel()
	Game.settings_changed.connect(func(k: String, _v: Variant) -> void:
		_sync_feel()
		if k == "ui_skin":
			# dd-ui-clean: rebuild the screen in the new skin (the Settings panel rebuilds itself)
			_render())
	if OS.has_feature("web"):
		_inspect.opened.connect(_publish_state)
		_inspect.closed.connect(_publish_state)
		settings_panel.opened.connect(_publish_state)
		settings_panel.closed.connect(_publish_state)
		codex.opened.connect(_publish_state)
		codex.closed.connect(_publish_state)
		codex.scrolled.connect(_publish_state)
	var saved: String = Game.survivor_id
	chosen_survivor = saved if Game.profile.survivor_unlocked(saved) else "rosa"
	get_viewport().size_changed.connect(_render)
	_fit_base()
	_apply_smoke_query()
	_render()


func _sync_feel() -> void:
	feedback.reduce = Game.reduce_motion()
	feedback.shake_on = Game.screen_shake()


func open_settings() -> void:
	settings_panel.open()


## dd-ux-v4: the Glossary (every icon, one line each) and the Codex (every card; filters; met).
func open_glossary() -> void:
	if settings_panel.is_open():
		settings_panel.close()
	codex.open_glossary(Game.bal)


func open_codex() -> void:
	if settings_panel.is_open():
		settings_panel.close()
	codex.open_codex(Game.bal, Game.profile)


# ================================================================ base size (U1)
## The logical base for a screen whose shorter side is css_short CSS px: 560 on phones, growing by
## two thirds of every CSS px past 600 (900 -> 760, 1080 -> 880).
static func base_for(css_short: float) -> int:
	if css_short <= PHONE_CSS:
		return BASE
	return int(round(BASE + (css_short - PHONE_CSS) * BASE_GROWTH))


## CSS px per physical px (the browser's devicePixelRatio on the web, the OS scale elsewhere).
func _css_ratio() -> float:
	if OS.has_feature("web"):
		return maxf(0.5, float(JavaScriptBridge.eval("window.devicePixelRatio || 1", true)))
	return maxf(0.5, DisplayServer.screen_get_scale())


## Sets the window's content scale base for its current size and screen. Returns true when it changed.
func _fit_base() -> bool:
	var win: Window = get_window()
	if win == null:
		return false
	var ws: Vector2 = Vector2(win.size)
	if ws.x <= 0.0 or ws.y <= 0.0:
		return false
	# the street is where the room matters; title, map, safehouse and end keep the 560 base on
	# every screen (they are laid out for it and look the same as before)
	var l: int = base_for(minf(ws.x, ws.y) / _css_ratio()) if screen == Screen.STREET else BASE
	if win.content_scale_size == Vector2i(l, l):
		return false
	_fitting = true
	win.content_scale_size = Vector2i(l, l)
	_fitting = false
	return true


# ================================================================ rendering
## dd-art-import: the full-screen painted backdrop (title screen) or none.
func _set_backdrop(tex: Texture2D) -> void:
	_backdrop.texture = tex
	_backdrop.visible = tex != null
	_backdrop_scrim.visible = tex != null


func _render() -> void:
	if _fitting:
		return
	_fit_base()
	if drag != null:
		drag.cancel()
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
	# dd-ux-clean: after a rotation the content box can keep the old screen's (larger) size;
	# snap it back to the screen so the new layout reflows instead of overflowing
	_content.position = Vector2.ZERO
	_content.size = vp
	_set_backdrop(Art.texture_for(["title_portrait", "title_landscape"] if portrait else ["title_landscape", "title_portrait"]) if screen == Screen.TITLE else null)
	match screen:
		Screen.TITLE:
			_build_title()
		Screen.MAP:
			_build_map()
		Screen.STREET:
			_build_street()
			_build_sheet()
			if Game.profile != null and Game.run != null:
				Game.profile.codex_meet(Codex.keys_met_by(Game.run))
			_room_pulses.call_deferred()
		Screen.SAFEHOUSE:
			_build_safehouse()
		Screen.END:
			_build_end()
	if screen in [Screen.MAP, Screen.SAFEHOUSE, Screen.END] and str(sheet.get("type", "")) in ["patches", "leave_confirm"]:
		_build_sheet()
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
		# v4: a swapped-out gun pays its Salvage: "+N" over that slot
		DDV4Hooks.play_salvage(feedback, _gun_views, pend.get("ev", {}), Game.bal)
	if not banner.is_empty() and screen == Screen.STREET:
		_banner_seq += 1
		var seq: int = _banner_seq
		var d: float = float(banner.get("delay", 0.0))
		if d > 0.0:
			await get_tree().create_timer(d).timeout
		# a newer banner was asked for while this one waited: it wins
		if seq != _banner_seq or not is_inside_tree() or screen != Screen.STREET:
			return
		if banner.has("wave"):
			_wave_banner(int(banner["wave"]), str(banner.get("sub", "")))
		else:
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
	var plates: Array = [{}, {}]
	for s: int in 2:
		var gv: DDGunView = _gun_views[s]
		if gv != null and is_instance_valid(gv) and gv.is_inside_tree():
			gun_rects[s] = gv.get_global_rect()
			if gv.plate != null and is_instance_valid(gv.plate):
				var pi: Dictionary = (gv.plate.get_meta(&"info", {}) as Dictionary).duplicate()
				pi["rect"] = gv.plate.get_global_rect()
				plates[s] = pi
			next_rects[s] = gv.next_rect()
			for mc: DDCardView in gv.stack_cards:
				(stack_rects[s] as Array).append(Rect2(mc.get_global_rect().position, mc.size))
	return {"rects": rects, "specs": _street_specs.duplicate(), "hp": run.hp, "cover": run.cover, "points": run.points,
		"stack_rects": stack_rects, "next_rect": next_rects, "gun_rects": gun_rects, "plates": plates}


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
	# dd-ux-clean: short screens sit in the middle of the screen instead of hugging the top
	if child is BoxContainer:
		(child as BoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
		child.custom_minimum_size = Vector2(0, get_viewport_rect().size.y - MARGIN * 2)
	s.add_child(child)
	# dd-ux-equip: drag / two-finger scroll on touch (taps and long presses still work)
	DDTouchScroll.attach(s)
	return s


func _settings_button(small: bool = false) -> Button:
	var b: Button = DDUi.button("Settings", DDUi.PANEL if small else DDUi.PANEL_HI, DDUi.FONT_S if small else DDUi.FONT_M)
	b.name = "SettingsButton"
	if small:
		b.custom_minimum_size = Vector2(96, TAP)
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
	# dd-ux-clean: one line of pitch, one line of instruction
	v.add_child(DDUi.label("Kill zombies in each gun's order. Fill the gun. Get paid.", DDUi.FONT_M if portrait else DDUi.FONT_S, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(DDUi.label("Pick a survivor (long press to read)", DDUi.FONT_S - 2, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	if Game.discarded_old_run and not _old_note_shown:
		var note: PanelContainer = DDUi.panel(Color("3a2a12"), 10, DDUi.WARN, 2)
		note.add_child(DDUi.label("New rules: your old saved run can't continue. Unlocks and best scores are kept.", DDUi.FONT_S, DDUi.WARN, HORIZONTAL_ALIGNMENT_CENTER, true))
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
	var card_h: float = 260.0 if portrait else clampf(vp.y - MARGIN * 2 - 52.0 - 30.0 - 24.0 - DDUi.TAP_MIN - 8.0 * 4 - 12.0 - (80.0 if saved != "" else 0.0) - (50.0 if Game.discarded_old_run else 0.0), 110.0, 250.0)
	for sid: String in Game.bal.survivor_ids():
		var unlocked: bool = Game.profile.survivor_unlocked(sid)
		var s: Dictionary = Game.bal.survivor(sid)
		var lines: Array = [[DDText.passive_name(str(s.get("passive", ""))), DDUi.accent("S"), DDUi.FONT_S]]
		if unlocked:
			if Game.profile.best_score(sid) > 0:
				lines.append(["Best %d" % Game.bal.shown(Game.profile.best_score(sid)), DDUi.TEXT_DIM, DDUi.FONT_S - 2])
		else:
			lines.append([DDPayloads.unlock_hint(Game.profile.unlock_milestone_for("survivor:" + sid), Game.bal).capitalize() + " to unlock", DDUi.WARN, DDUi.FONT_S - 2])
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
	var go: Button = DDUi.button(("Start run as %s" if saved == "" else "New run as %s (ends the saved one)") % str(Game.bal.survivor(chosen_survivor).get("name", "")), Color("7a2d27"), DDUi.FONT_L if saved == "" else DDUi.FONT_M)
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
	how.name = "HowToPlay"
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	how.pressed.connect(open_glossary)
	h.add_child(how)
	# dd-ux-v4: the Codex, from the title (and the Menu)
	var cx: Button = DDUi.button("Codex")
	cx.name = "CodexButton"
	cx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cx.pressed.connect(open_codex)
	h.add_child(cx)
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
	v.add_child(DDUi.label("District %d of %d" % [run.district_index + 1, Game.bal.district_count()], DDUi.FONT_M, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
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
			"title": "Boss: %s" % str(b.get("name", "")),
			"selected": di == run.district_index, "dim": di < run.district_index,
			"payload": {"kind": "F", "tag": str(d.get("name", "")).to_upper(), "title": str(b.get("name", "")), "big": str(int((b.get("zombies", [9]) as Array)[0])),
				"body": DDText.boss_words(b).capitalize().substr(0, 1) + DDText.boss_words(b).substr(1) + ".\n%s\nWaves: %s.\nRooms: %s." % [DDText.trait_text(str(b.get("trait", ""))), " | ".join(PackedStringArray([0, 1, 2].map(func(w: int) -> String: return DDText.zombie_list(Game.bal.wave_zombies(di, w))))),
					", ".join(PackedStringArray((d.get("rooms", []) as Array).map(func(r: Variant) -> String: return "%s %d" % [str((r as Dictionary).get("name", "")), Game.bal.shown(int((r as Dictionary).get("cost", 0)))])))],
				"t1": "%s · boss %s (%s)" % [str(d.get("name", "")), str(b.get("name", "")), DDText.boss_words(b)],
				"t2": "3 waves, then the boss. %s" % ("You are here." if di == run.district_index else ("Cleared." if di < run.district_index else "Ahead."))}}
		# r2 (playtest: "6×3" and "8-12" read as guesses): the badge is the first strength, like every
		# zombie's; the line under the boss's name says the rest in words ("3 at once, strength 6 each")
		var bz: Array = b.get("zombies", [9])
		spec["strength"] = int(bz[0])
		spec["big"] = str(int(bz[0]))
		spec["lines"] = [[DDText.boss_words_short(b), DDUi.TEXT, DDUi.FONT_S - 2]]
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
	# dd-ux-clean: one tile for the survivor (HP, points); one chip for the Patches
	var s: Dictionary = Game.bal.survivor(run.survivor_id)
	st.add_child(_view({"kind": "S", "tag": str(s.get("name", "")).to_upper(), "title": "HP %d / %d  ·  %d pts" % [run.hp, run.max_hp, Game.bal.shown(run.points)],
		"row": true, "title_size": DDUi.FONT_S, "payload": DDPayloads.hp(run)}, Vector2(220, 64)))
	if not run.patches.is_empty():
		# dd-ux-equip: the Patches you wear, as their painted icons
		st.add_child(_patch_row(run, 52.0, vp.x - MARGIN * 2 - 228.0))
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
	# dd-ux-v4: the district's first wave gets the WAVE banner too
	_pending_banner = {"text": "WAVE 1", "wave": 1, "color": DDUi.TEXT,
		"sub": "%s · zombies %s" % [str(run.district().get("name", "")), DDText.zombie_range(Game.bal.wave_zombies(run.district_index, 0))]}
	_queue_render()


# ---------------------------------------------------------------- street
func _points_spec(run: DDRun) -> Dictionary:
	# v5 (playtest: "I first thought points were just score"): the chip shows what you can spend
	# and, under it, the run score (every point earned; spending never lowers it)
	return {"kind": "X", "tag": "PTS", "big": str(Game.bal.shown(run.points)), "big_size": 26, "row": true, "payload": DDPayloads.points(run),
		"lines": [[DDText.score_text(run.points_earned, Game.bal).to_lower(), DDUi.TEXT_DIM, DDUi.FONT_S - 7]]}


## dd-ux-clean: a tile whose content main.gd builds itself (HP panel, the prompt bar): it keeps
## DDCardView's tap / long press / right click, so it is inspectable like everything else.
func _custom_tile(kind: String, payload: Dictionary, bg: Color = Color(0, 0, 0, 0)) -> DDCardView:
	var v: DDCardView = DDCardView.new()
	v.setup({"kind": kind, "payload": payload, "row": true})
	for c: Node in v.get_children():
		v.remove_child(c)
		c.queue_free()
	if bg.a > 0.0:
		v.add_theme_stylebox_override("panel", DDUi.box(bg, DDUi.accent(kind).darkened(0.3), 2, 12, 6))
		# dd-art2-import: the painted chip rim over the tile
		if DDUi.Kit.rim(v, DDUi.accent(kind).darkened(0.3), false, true) != null:
			v.add_theme_stylebox_override("panel", DDUi.Kit.card_body(bg, 6.0))
	else:
		v.set_selected(false)
	v.inspected.connect(_on_inspect)
	return v


func _stacked(v: Control, n: int, kind: String) -> Control:
	return (StackBox.new() as Container).call("setup", v, n, kind)


## dd-ux-v4 street (the head's M1 a: direction B, the Door row). One focus per moment: the street
## cards (biggest, the strength mark and the damage chip on each) and the weapon you hit them with.
## Around them, quieter:
## - the HUD: HP (+ Cover), points, one Patches chip, ? (Help / Glossary), Menu;
## - the DOOR ROW: the wave door (the big wave number, "+N" waves waiting, the boss under it) and
##   the three room doors, each with its padlock price plate (locked + progress bar, gold OPEN,
##   USE, used). Everything that feeds the pile, side by side, the same size;
## - the STRIP between the street and the guns: the draw pile (where cards are dealt from), one
##   "what just happened" line (tap it for the history) and the resolve pips. The old prompt band
##   is gone (head's note on M1), so the street sits right above the guns;
## - the GUN ROW: the two guns (hit burst, rule, kill sockets, reward) and a narrow column with
##   two small buttons: MELEE (Bare Hands or the melee weapon you hold, with its use pips) and RUN.
## Portrait: HUD / doors / street (2x2 when tall enough) / strip / guns + [melee, run].
## Landscape: [doors as a column] | [HUD / street / strip] | [gun 1 / gun 2 / melee + run].
## Same pieces, reflowed, never shrunk below a 44 CSS px tap target.
func _build_street() -> void:
	var run: DDRun = Game.run
	var vp: Vector2 = get_viewport_rect().size
	var W: float = vp.x - MARGIN * 2
	var H: float = vp.y - MARGIN * 2
	hint_id = _due_hint(run)
	var hud: Control = _build_top(run)
	var hint: Control = _build_hint(run) if hint_id != "" else null
	# dd-ui-clean (head: "the tip showing makes all row cards move and resize"): the hint floats over
	# the strip as a toast (_float_hint) and takes no layout space
	var hint_h: float = 0.0
	var strip_h: float = TAP if run.lookout_card() != null else STRIP_H
	var slots: Array[int] = street_slots(run)
	var n: int = maxi(4, slots.size())
	# dd-ux-clean2 (U2): a boss street holds 2 cards (the boss + a phase / cover card); they take
	# the street's whole width (portrait) or grow to the street's height (landscape)
	var duel: bool = run.boss_street and run.street.size() <= 2 and slots.size() <= 2
	if duel:
		n = 2
	if portrait:
		# dd-ui6 (head: more room for the gun art, a little less for the street cards): 196 -> 284
		var gun_h: float = 284.0
		var door_h: float = clampf(H * 0.165, 150.0, 200.0)
		var fixed: float = HUD_H + door_h + hint_h + strip_h + gun_h + SEP * 4 + SLACK
		var avail: float = H - fixed
		var cols: int = n
		var card_w: float = (W - SEP * (n - 1)) / n
		var card_h: float = clampf(avail, 120.0, card_w * (1.65 if duel else 1.5))
		if n == 4 and avail >= 2.0 * 170.0 + SEP:
			cols = 2
			card_w = (W - SEP) / 2.0
			card_h = minf((avail - SEP) / 2.0, card_w * 1.25)
		var v: VBoxContainer = DDUi.vbox(SEP)
		_content.add_child(v)
		v.add_child(hud)
		var doors: Control = _build_doors(run, false)
		doors.custom_minimum_size = Vector2(0, door_h)
		v.add_child(doors)
		var srow: Control = _build_street_row(run, card_w, card_h, cols)
		srow.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(srow)
		var strip: Control = _build_strip(run, strip_h)
		v.add_child(strip)
		v.add_child(_build_guns(run, true, gun_h, W))
		if hint != null:
			_float_hint(hint, strip)
	else:
		var tall: bool = H >= 600.0
		var lw: float = clampf(W * 0.14, 150.0, 210.0)
		var rw: float = clampf(W * 0.27, 290.0, 440.0)
		var mid_w: float = W - lw - rw - SEP * 2
		var street_h: float = H - HUD_H - hint_h - strip_h - SEP * 2 - SLACK
		# one row of 4, or a 2x2 grid when that gives bigger cards (tall desktop windows)
		var card_w2: float = (mid_w - SEP * (n - 1)) / n
		var card_h2: float = clampf(street_h, 110.0, card_w2 * (1.4 if not tall else 1.65))
		var cols2: int = n
		if n == 4:
			var gw: float = (mid_w - SEP) / 2.0
			var gh: float = minf((street_h - SEP) / 2.0, gw * 1.1)
			if gw * gh > card_w2 * card_h2 * 1.15 and gh >= 150.0:
				cols2 = 2
				card_w2 = gw
				card_h2 = gh
		if duel:
			card_w2 = minf(card_w2, card_h2 * 1.15)
		var h: HBoxContainer = DDUi.hbox(SEP)
		_content.add_child(h)
		var doors2: Control = _build_doors(run, true)
		doors2.custom_minimum_size = Vector2(lw, 0)
		h.add_child(doors2)
		var mid: VBoxContainer = DDUi.vbox(SEP)
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(mid)
		hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.add_child(hud)
		var srow2: Control = _build_street_row(run, card_w2, card_h2, cols2)
		srow2.size_flags_vertical = Control.SIZE_EXPAND_FILL
		mid.add_child(srow2)
		var strip2: Control = _build_strip(run, strip_h)
		mid.add_child(strip2)
		if hint != null:
			_float_hint(hint, strip2)
		var guns: Control = _build_guns(run, false, H, rw)
		guns.custom_minimum_size = Vector2(rw, 0)
		h.add_child(guns)


## HUD: HP (+ Cover when you have some), points, one Patches chip, ? (Help / Glossary), Menu. The
## survivor's passive is in the HP tooltip; each stat appears once.
func _build_top(run: DDRun) -> Control:
	var h: HBoxContainer = DDUi.hbox(6)
	h.custom_minimum_size = Vector2(0, HUD_H)
	_hp_box = h
	var col: Color = DDUi.GOOD if run.hp * 2 > run.max_hp else (DDUi.WARN if run.hp * 4 > run.max_hp else DDUi.BAD)
	var hp_tile: DDCardView = _custom_tile("S", DDPayloads.hp(run), DDUi.PANEL)
	hp_tile.name = "HpPanel"
	hp_tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hv: VBoxContainer = DDUi.vbox(2)
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_tile.add_child(hv)
	_hp_label = DDUi.label("HP %d / %d" % [run.hp, run.max_hp], DDUi.FONT_M - 2, col)
	hv.add_child(_hp_label)
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = run.max_hp
	bar.value = run.hp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	# dd-art2-import: painted gauge (sunk track; green / amber / red enamel fill by HP)
	bar.add_theme_stylebox_override("background", DDUi.bar_style("dd_bar_track", Color("0d0f10")))
	var fill_file: String = "dd_bar_fill_green" if col == DDUi.GOOD else ("dd_bar_fill_amber" if col == DDUi.WARN else "dd_bar_fill_red")
	bar.add_theme_stylebox_override("fill", DDUi.bar_style(fill_file, col))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hv.add_child(bar)
	_hp_bar = bar
	h.add_child(hp_tile)
	_hp_anchor = hp_tile
	if run.cover > 0:
		var cov: DDCardView = _view({"kind": "C", "tag": "COVER", "big": str(run.cover), "big_size": 22, "row": true,
			"payload": DDPayloads.cover(run)}, Vector2(84, 0))
		_cover_view = cov
		h.add_child(cov)
	var pv: DDCardView = _view(_points_spec(run), Vector2(108, 0))
	pv.index = IDX_POINTS
	_points_view = pv
	h.add_child(pv)
	if not run.patches.is_empty():
		# dd-ux-equip (head: "show their icons visually"): the painted Patch icons in a compact row;
		# the HP panel keeps at least HP_MIN_W, the row takes what is left (+N when more don't fit)
		var hud_w: float = get_viewport_rect().size.x - MARGIN * 2
		if not portrait:
			hud_w -= clampf(hud_w * 0.14, 150.0, 210.0) + clampf(hud_w * 0.27, 290.0, 440.0) + SEP * 2
		var budget: float = hud_w - HP_MIN_W - 108.0 - (90.0 if run.cover > 0 else 0.0) - 64.0 - 72.0 - 6.0 * 5
		h.add_child(_patch_row(run, PATCH_ICON, budget))
	h.get_child(0).custom_minimum_size.x = HP_MIN_W
	h.add_child(_help_button())
	var sb: Button = _settings_button(true)
	sb.text = "Menu"
	sb.custom_minimum_size = Vector2(72, HUD_H)
	h.add_child(sb)
	return h


## dd-ux-equip: the Patches as a row of their painted icons, `icon` px square, at most `max_w` px
## wide (the last place becomes "+N" when they don't all fit). The row is the PatchesChip: a tap
## (or long press on its edge) opens the list of every Patch with its rule; each icon is its own
## tile, so right click / long press on it gives that Patch's name and rule (a tap opens it too).
func _patch_row(run: DDRun, icon: float, max_w: float) -> DDCardView:
	var pp: Dictionary = DDPayloads.patches(run)
	var row: DDCardView = _custom_tile("P", pp, DDUi.PANEL)
	row.name = "PatchesChip"
	# dd-challenge-rack (head: "Clicking the patch icons should show me all my patches and
	# effects"): a tap anywhere on the row opens Your Patches; long press an icon = that Patch
	row.tapped.connect(func(_v: DDCardView) -> void: open_patches_sheet())
	var h: HBoxContainer = DDUi.hbox(4)
	h.name = "PatchIcons"
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var n: int = run.patches.size()
	var fit: int = maxi(1, int(floor((max_w - 12.0 + 4.0) / (icon + 4.0))))
	var shown_n: int = n if n <= fit else maxi(1, fit - 1)
	for k: int in shown_n:
		var pid: String = run.patches[k]
		h.add_child(_patch_icon(pid, icon))
	if shown_n < n:
		var more: Label = DDUi.label("+%d" % (n - shown_n), DDUi.FONT_S - 2, DDUi.accent("P"), HORIZONTAL_ALIGNMENT_CENTER)
		more.name = "MorePatches"
		more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		more.custom_minimum_size = Vector2(icon, icon)
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(more)
	# a slim rim: the icons fill the HUD's height without growing it
	var pst: StyleBox = row.get_theme_stylebox("panel")
	if pst != null:
		pst = pst.duplicate()
		pst.content_margin_top = 3.0
		pst.content_margin_bottom = 3.0
		pst.content_margin_left = 6.0
		pst.content_margin_right = 6.0
		row.add_theme_stylebox_override("panel", pst)
	row.size_flags_vertical = Control.SIZE_FILL
	return row


## One Patch icon: the painted patch (or its initial when the art is missing), inspectable.
func _patch_icon(pid: String, icon: float) -> DDCardView:
	var p: Dictionary = DDPayloads.patch(pid, Game.bal)
	var tex: Texture2D = Art.texture_for(Art.patch_keys(pid))
	if tex != null:
		p["art"] = tex
	var ic: DDCardView = _custom_tile("P", p)
	ic.name = "Patch_" + pid
	var rim: Node = ic.get_node_or_null(^"PaintedRim")
	if rim != null:
		ic.remove_child(rim)
		rim.queue_free()
	ic.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	ic.custom_minimum_size = Vector2(icon, icon)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if tex != null:
		var tr: TextureRect = TextureRect.new()
		tr.name = "Icon"
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(icon, icon)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.add_child(tr)
		ic.art_rect = tr
	else:
		var l: Label = DDUi.label(DDText.patch_name(pid).left(1), DDUi.FONT_M, DDUi.accent("P"), HORIZONTAL_ALIGNMENT_CENTER)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.add_child(l)
	ic.tapped.connect(func(_v: DDCardView) -> void: open_patches_sheet())
	return ic


## dd-challenge-rack: the Your Patches sheet (every Patch you wear: icon, name, effect, state).
func open_patches_sheet() -> void:
	if Game.run == null or Game.run.patches.is_empty() or busy:
		return
	sheet = {"type": "patches"}
	Sfx.cue(&"button", 0.9)
	_queue_render()


func _patches_list_sheet(run: DDRun, v: VBoxContainer) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var head: HBoxContainer = DDUi.hbox(8)
	v.add_child(head)
	var t: Label = DDUi.label("YOUR PATCHES · %d" % run.patches.size(), DDUi.FONT_M, DDUi.accent("P"))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(DDUi.label("for the whole run", DDUi.FONT_S - 4, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT))
	var sc: ScrollContainer = ScrollContainer.new()
	sc.name = "PatchesScroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rows_h: float = run.patches.size() * 78.0
	sc.custom_minimum_size = Vector2(0, minf(rows_h, maxf(120.0, vp.y - 64.0 - 28.0 - 64.0 - 60.0 - 40.0)))
	v.add_child(sc)
	var list: VBoxContainer = DDUi.vbox(6)
	list.name = "PatchesList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for pid: String in run.patches:
		list.add_child(_patch_list_row(run, pid))
	v.add_child(_sheet_button("Close", true, DDUi.PANEL_HI, close_sheet))


## One row of Your Patches: icon | NAME (+ state) over its full effect. Long press = its zoom.
func _patch_list_row(run: DDRun, pid: String) -> DDCardView:
	var p: Dictionary = DDPayloads.patch(pid, Game.bal)
	var tex: Texture2D = Art.texture_for(Art.patch_keys(pid))
	if tex != null:
		p["art"] = tex
	var r: DDCardView = _custom_tile("P", p, DDUi.PANEL_HI)
	r.name = "PatchRow_" + pid
	r.custom_minimum_size = Vector2(0, 72)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.tapped.connect(func(_v: DDCardView) -> void: _inspect.open(p))
	var h: HBoxContainer = DDUi.hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(h)
	if tex != null:
		var tr: TextureRect = TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(56, 56)
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tr)
	var col: VBoxContainer = DDUi.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(col)
	var top: HBoxContainer = DDUi.hbox(8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	top.add_child(DDUi.label(DDText.patch_name(pid).to_upper(), DDUi.FONT_S - 2, DDUi.accent("P")))
	var st: Array = DDPayloads.patch_state(run, pid)
	if not st.is_empty():
		var sl: Label = DDUi.label(str(st[0]), DDUi.FONT_S - 4, DDUi.GOOD if bool(st[1]) else DDUi.TEXT_DIM)
		sl.name = "PatchState"
		top.add_child(sl)
	var el: Label = DDUi.label(DDText.patch_text(pid, Game.bal), DDUi.FONT_S - 4, DDUi.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	el.name = "PatchEffect"
	col.add_child(el)
	DDUi.ignore_mouse(h)
	return r


## dd-ux-v4: the "?" (Help / Glossary). Right click / long press says what it is.
func _help_button() -> Button:
	var b: Button = DDUi.button("?", Color("1f3a4f"), DDUi.FONT_L)
	b.name = "HelpButton"
	b.custom_minimum_size = Vector2(64, HUD_H)
	b.autowrap_mode = TextServer.AUTOWRAP_OFF
	if not b.has_meta(&"painted"):
		b.add_theme_stylebox_override("normal", DDUi.box(Color("1f3a4f"), DDUi.accent("W"), 2, 12, 8))
	b.pressed.connect(func() -> void:
		if not _was_long(b):
			open_glossary())
	_inspectable_button(b, {"kind": "W", "title": "Help", "t1": "Help · Glossary", "t2": "Every icon in the game, one line each."})
	return b


## dd-ux-v4: buttons open their 2-line tooltip on right click and on long press too (a tap still
## presses them). The long press is timed by the button itself.
func _inspectable_button(b: Button, payload: Dictionary) -> void:
	b.set_meta(&"tip", payload)
	# the long-press timer is the button's child: it dies with the button (no stale callback)
	var t: Timer = Timer.new()
	t.one_shot = true
	t.wait_time = DDCardView.LONG_PRESS_MS / 1000.0
	b.add_child(t)
	t.timeout.connect(func() -> void:
		if bool(b.get_meta(&"held", false)) and not bool(b.get_meta(&"long", false)):
			b.set_meta(&"long", true)
			_inspect.open(payload))
	b.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			if e.is_pressed():
				_inspect.open(payload)
				b.accept_event()
			return
		var left: bool = (e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch
		if not left:
			return
		if e.is_pressed():
			if not bool(b.get_meta(&"held", false)):
				b.set_meta(&"held", true)
				b.set_meta(&"long", false)
				b.set_meta(&"press_ms", Time.get_ticks_msec())
				t.start()
		elif bool(b.get_meta(&"held", false)):
			# release: a hold that the timer missed still counts (checked before "pressed" fires)
			b.set_meta(&"held", false)
			t.stop()
			if not bool(b.get_meta(&"long", false)) and Time.get_ticks_msec() - int(b.get_meta(&"press_ms", 0)) >= DDCardView.LONG_PRESS_MS:
				b.set_meta(&"long", true)
				_inspect.open(payload))
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE


## True (once) when the last press on b was a long press that opened its tooltip.
func _was_long(b: Button) -> bool:
	if bool(b.get_meta(&"long", false)):
		b.set_meta(&"long", false)
		return true
	return false


# ---------------------------------------------------------------- the door row
## The wave door and the three room doors: one row (portrait) or one column (landscape), equal size.
func _build_doors(run: DDRun, column: bool) -> Control:
	var box: BoxContainer = BoxContainer.new()
	box.vertical = column
	box.add_theme_constant_override("separation", SEP)
	box.name = "Doors"
	var wd: DDCardView = _wave_door(run, column)
	wd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wd.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(wd)
	for i: int in run.room_count():
		var rd: DDCardView = _room_door(run, i, column)
		rd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rd.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(rd)
	return box


## A door tile: the art fills it (under a scrim), children are laid over it by anchors.
func _door_tile(kind: String, payload: Dictionary, art_keys: Array, tint: float, border: Color) -> DDCardView:
	var v: DDCardView = DDCardView.new()
	v.setup({"kind": kind, "payload": payload, "row": true})
	for c: Node in v.get_children():
		v.remove_child(c)
		c.queue_free()
	var st: StyleBoxFlat = DDUi.box(DDUi.card_bg(kind), border, 3, 12, 0)
	v.add_theme_stylebox_override("panel", st)
	# dd-art2-import: the painted rim in the door's colour over the art
	if DDUi.Kit.rim(v, border, false, false) != null:
		v.add_theme_stylebox_override("panel", DDUi.Kit.card_body(DDUi.card_bg(kind), 0.0))
	var window: Control = Control.new()
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(window)
	var tex: Texture2D = Art.texture_for(art_keys)
	if tex != null:
		var tr: TextureRect = Art.cover_rect(tex)
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		window.add_child(tr)
		v.art_rect = tr
		v.has_art = true
	var scrim: ColorRect = ColorRect.new()
	scrim.color = Color(DDUi.card_bg(kind), tint)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(scrim)
	v.inspected.connect(_on_inspect)
	v.set_meta(&"window", window)
	return v


func _anchored_label(parent: Control, text: String, size: int, col: Color, preset: Control.LayoutPreset, margin: float = 6.0) -> Label:
	var l: Label = DDUi.label(text, size, col, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.04, 0.92))
	parent.add_child(l)
	l.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, int(margin))
	if preset == Control.PRESET_TOP_WIDE or preset == Control.PRESET_BOTTOM_WIDE:
		l.clip_text = true
	return l


## The wave door: WAVE + "+N" waiting on top, the big current wave number in the middle, the boss
## (a chip of its own: inspect it for the boss tooltip) at the bottom. Tap: the waves tooltip.
func _wave_door(run: DDRun, column: bool) -> DDCardView:
	var p: Dictionary = DDPayloads.waves(run)
	var wv: DDCardView = _door_tile("D", p, Art.deck_back_keys("wave"), 0.55, DDUi.BAD.darkened(0.25))
	wv.index = IDX_WAVE
	wv.name = "WaveDoor"
	wv.tapped.connect(func(_x: DDCardView) -> void: _inspect.open(DDPayloads.waves(Game.run)))
	var window: Control = wv.get_meta(&"window")
	var n: int = DDPayloads.waves_waiting(run)
	var top: Label = _anchored_label(window, "WAVE" + ("  +%d" % n if n > 0 else ""), DDUi.FONT_S - 3, DDUi.TEXT, Control.PRESET_TOP_WIDE, 4)
	top.name = "WaveTop"
	var num: Control = Marks.WaveNumeral.new("B" if run.boss_street else str(mini(run.wave_index + 1, run.wave_count())))
	num.name = "WaveNumeral"
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.offset_top = 22
	num.offset_bottom = -40 if not column else -34
	num.offset_left = 4
	num.offset_right = -4
	window.add_child(num)
	wv.set_meta(&"numeral", num)
	wv.big_label = top
	# the boss: its own inspectable chip under the number
	var bs: Dictionary = DDPayloads.boss_spec(run)
	var b: Dictionary = run.boss_def()
	var zs: Array = b.get("zombies", [9])
	var bv: DDCardView = DDCardView.new()
	bv.setup({"kind": "F", "payload": DDPayloads.boss(run), "row": true})
	for c: Node in bv.get_children():
		bv.remove_child(c)
		c.queue_free()
	bv.add_theme_stylebox_override("panel", DDUi.box(Color(DDUi.card_bg("F"), 0.92), DDUi.accent("F"), 2, 8, 2))
	# dd-art2-import: the painted BOSS tag (purple plate, bone words)
	var boss_tag: StyleBox = DDUi.Kit.box("dd_tag_boss", 2.0)
	if boss_tag != null:
		boss_tag.content_margin_left = 10.0
		boss_tag.content_margin_right = 10.0
		bv.add_theme_stylebox_override("panel", boss_tag)
	bv.index = IDX_BOSS
	bv.name = "BossChip"
	# v5 (playtest: "BOSS 9: is 9 its strength or a countdown?"): the word BOSS, then the boss's
	# strength in the same red badge every zombie wears (Horde: one badge + "x3"; Phases: one badge
	# per phase). The chip's tooltip spells it out ("strength 9").
	var brow: HBoxContainer = DDUi.hbox(3)
	brow.name = "BossBadgeRow"
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(brow)
	var bl: Label = DDUi.label("BOSS", DDUi.FONT_S - 3, DDUi.accent("F") if boss_tag == null else DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	bl.name = "BossWord"
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brow.add_child(bl)
	var horde: bool = zs.size() > 1 and str(b.get("trait", "")) != "phases"
	var sm: Control = Marks.StrengthMark.new(int(zs[0]))
	sm.name = "BossStrength"
	sm.custom_minimum_size = Vector2(22, 22)
	sm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brow.add_child(sm)
	if zs.size() > 1:
		# r2: words, not "x3" / "->12" (the tooltip says it in full: "3 at once, strength 6 each")
		# (the narrow portrait door: "×3"; its tooltip spells it out)
		var more: Label = DDUi.label((("%d at once" if column else "×%d") % zs.size()) if horde else ("to %d" % int(zs[zs.size() - 1])), DDUi.FONT_S - 6, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		more.name = "BossMore"
		more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		brow.add_child(more)
	bv.clip_contents = true
	bv.tapped.connect(func(_x: DDCardView) -> void: _inspect.open(DDPayloads.boss(Game.run)))
	bv.inspected.connect(_on_inspect)
	# inside the art window (a plain Control), so the anchors hold
	window.add_child(bv)
	bv.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bv.offset_left = 4
	bv.offset_right = -4
	bv.offset_top = -34 if not column else -30
	bv.offset_bottom = -4
	bv.set_meta(&"spec", bs)
	_boss_view = bv
	# every wave deck animates from the one door (feedback looks waves up by index)
	for w: int in run.wave_count():
		_wave_views.append(wv)
	return wv


## A room door: the room art (the machine's once open), its name at the bottom, and the padlock
## price plate on the image: locked (dark, price, a progress bar), gold OPEN (tap it to open),
## green USE, grey "used".
func _room_door(run: DDRun, i: int, column: bool) -> DDCardView:
	var did: String = str(run.district().get("id", ""))
	var r: Dictionary = run.room(i)
	var open: bool = run.room_open[i]
	var afford: bool = not open and run.can_open_room(i)
	var keys: Array = Art.machine_keys(run.machine(i)) if open else Art.room_keys(did, str(r.get("name", "")))
	var usable: bool = open and not run.machine_used[i] and run.points >= run.machine_min_price(i)
	var border: Color = DDUi.WARN if afford else (DDUi.GOOD.darkened(0.2) if usable else Color("4a5358"))
	var rv: DDCardView = _door_tile("Q" if open else "R", DDPayloads.room(run, i), keys, 0.25 if (afford or open) else 0.45, border)
	rv.index = IDX_ROOM + i
	rv.name = "Room%d" % i
	rv.tapped.connect(func(_x: DDCardView) -> void: _inspect.open(DDPayloads.room(Game.run, i)))
	_room_views.append(rv)
	var window: Control = rv.get_meta(&"window")
	var mk: String = str(run.machine(i).get("kind", ""))
	var place: String = str(r.get("name", "")).to_upper()
	var nm: Label = _anchored_label(window, DDText.machine_name(mk) if open else place, DDUi.FONT_S - (4 if column else 3), DDUi.TEXT, Control.PRESET_BOTTOM_WIDE, 3)
	nm.name = "RoomName"
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rv.resized.connect(func() -> void: DDCardView.fit_label(nm, DDUi.FONT_S - (4 if column else 3), 10))
	rv.add_child(_room_plate(run, i))
	return rv


## The padlock plate: a Button laid on the room art (centred, a little above the middle).
func _room_plate(run: DDRun, i: int) -> Control:
	var price: int = Game.bal.shown(run.room_cost(i))
	var open: bool = run.room_open[i]
	var used: bool = open and run.machine_used[i]
	var afford: bool = not open and run.can_open_room(i)
	# an open machine you can't pay for yet: no green USE, a dark plate with its price instead
	var use_cost: int = run.machine_min_price(i) if open else 0
	var poor: bool = open and not used and run.points < use_cost
	var b: Button = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var holder: CenterContainer = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.offset_bottom = -26
	holder.add_child(b)
	var inner: VBoxContainer = DDUi.vbox(2)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(inner)
	var row: HBoxContainer = DDUi.hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(row)
	var col: Color
	var bg: Color
	var edge: Color
	if open:
		b.name = "Use%d" % i
		if poor:
			b.text = "%d pts · need %d more" % [Game.bal.shown(use_cost), maxi(0, Game.bal.shown(use_cost) - Game.bal.shown(run.points))]
			col = DDUi.TEXT
			bg = Color(0.055, 0.047, 0.047, 0.9)
			edge = Color("8a7a52")
		else:
			b.text = "USE" if not used else "used"
			col = DDUi.BG if not used else DDUi.TEXT_DIM
			bg = DDUi.GOOD if not used else Color(0.06, 0.05, 0.05, 0.85)
			edge = Color("c9f5d4") if not used else Color("555555")
		b.disabled = used or poor or busy or not run.pending_patch.is_empty()
		b.pressed.connect(func() -> void:
			if not _was_long(b):
				open_machine(i))
	else:
		b.name = "Open%d" % i
		b.text = ("%d pts · OPEN" % price) if afford else ("%d pts · need %d more" % [price, maxi(0, price - Game.bal.shown(run.points))])
		col = DDUi.BG if afford else DDUi.TEXT
		bg = DDUi.WARN if afford else Color(0.055, 0.047, 0.047, 0.9)
		edge = DDUi.SELECT if afford else Color("8a7a52")
		b.disabled = not afford or busy
		b.pressed.connect(func() -> void:
			if not _was_long(b):
				request_open_room(i))
		var lock: Control = Marks.Padlock.new(afford, col)
		lock.custom_minimum_size = Vector2(16, 20)
		lock.name = "Padlock"
		row.add_child(lock)
	# the plate draws its own words; the Button text is kept for tests / the web smoke (hidden)
	b.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	b.add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0))
	b.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	b.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	b.add_theme_font_size_override("font_size", 1)
	var main_txt: String = (str(Game.bal.shown(use_cost)) if poor else ("USE" if not used else "used")) if open else str(price)
	if poor:
		var plock: Control = Marks.Padlock.new(false, col)
		plock.custom_minimum_size = Vector2(16, 20)
		plock.name = "Padlock"
		row.add_child(plock)
	var ml: Label = DDUi.label(main_txt, DDUi.FONT_M - (0 if not used else 6), col, HORIZONTAL_ALIGNMENT_CENTER)
	row.add_child(ml)
	if afford:
		inner.add_child(DDUi.label("OPEN", DDUi.FONT_S - 4, DDUi.BG, HORIZONTAL_ALIGNMENT_CENTER))
	if not open:
		# v5: what using the machine inside costs, under the door price ("+150 to use"); r2: bigger
		var ul: Label = DDUi.label("+%d to use" % Game.bal.shown(run.machine_min_price(i)), DDUi.FONT_S - 4, DDUi.BG if afford else DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		ul.name = "UseCost"
		inner.add_child(ul)
	if not open and not afford:
		# how close you are: a thin gold bar
		var pg: ProgressBar = ProgressBar.new()
		pg.show_percentage = false
		pg.min_value = 0
		pg.max_value = price
		pg.value = mini(price, Game.bal.shown(run.points))
		pg.custom_minimum_size = Vector2(0, 5)
		pg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pg.add_theme_stylebox_override("background", DDUi.bar_style("dd_bar_track", Color("3a3328"), 2))
		pg.add_theme_stylebox_override("fill", DDUi.bar_style("dd_bar_fill_gold", DDUi.WARN, 2))
		if DDUi.Kit.tex("dd_bar_track") != null:
			pg.custom_minimum_size = Vector2(0, 8)
		pg.name = "Progress"
		inner.add_child(pg)
	var sb: StyleBoxFlat = DDUi.box(bg, edge, 2, 10, 6)
	for st: String in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb if st != "hover" else DDUi.box(bg.lightened(0.1), edge, 2, 10, 6))
	# dd-art2-import: the painted door plates (gold afford, dark iron locked, green USE, used)
	DDUi.Kit.skin_plate(b, "dd_plate_door_" + (("used" if used else ("locked" if poor else "use")) if open else ("afford" if afford else "locked")), 6.0)
	# r2 (accessibility): USE / OPEN plates at least 72 layout px tall (>= 44 CSS px on a phone)
	b.custom_minimum_size = Vector2(maxf(104.0, ml.get_combined_minimum_size().x + 44.0), DDUi.TAP_MIN + (22.0 if not open else 0.0))
	# dd-ux-text (playtest): the plate has its own tooltip on right click / long press (the gold
	# OPEN plate showed an empty one): the price and what is inside
	_inspectable_button(b, DDPayloads.room_plate(run, i))
	if b.disabled:
		# a locked / used plate: the door under it gets the taps (tooltip) and the long press
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if afford:
		b.set_meta(&"ready", true)
	return holder


# ---------------------------------------------------------------- street, strip
## r2 (playtest: "the street refills under the cursor, so one click opened the wrong card"): every
## street card keeps the grid cell it was dealt into. A taken card leaves a gap; a new card (a
## boss phase, the next deal) fills the first gap. Returns cell -> street index (-1 = a gap).
var _cell_of: Dictionary = {}
var _cell_count: int = 0


## True when some card in `keep` already had its cell last time (the same street, not a new deal).
func _cell_kept(keep: Dictionary) -> bool:
	for cid: Variant in keep.keys():
		if _cell_of.has(cid):
			return true
	return false


func street_slots(run: DDRun) -> Array[int]:
	var cells: Array[int] = []
	if run == null:
		return cells
	var keep: Dictionary = {}
	var used: Dictionary = {}
	for i: int in run.street.size():
		var cid: int = run.street[i].get_instance_id()
		if _cell_of.has(cid) and not used.has(int(_cell_of[cid])):
			keep[cid] = int(_cell_of[cid])
			used[int(_cell_of[cid])] = true
	for i2: int in run.street.size():
		var cid2: int = run.street[i2].get_instance_id()
		if keep.has(cid2):
			continue
		var cell: int = 0
		while used.has(cell):
			cell += 1
		keep[cid2] = cell
		used[cell] = true
	var count: int = run.street.size()
	for k: Variant in used.keys():
		count = maxi(count, int(k) + 1)
	# the row keeps its width while cards are taken (gaps on the right too); a fresh street, where
	# no card kept its cell, starts over at its own size
	if not keep.is_empty() and run.street.size() > 0:
		count = maxi(count, _cell_count if _cell_kept(keep) else 0)
	cells.resize(count)
	cells.fill(-1)
	for i3: int in run.street.size():
		cells[int(keep[run.street[i3].get_instance_id()])] = i3
	_cell_of = keep
	_cell_count = count
	return cells


func _build_street_row(run: DDRun, card_w: float, card_h: float, cols: int = 99) -> Control:
	var cells: Array[int] = street_slots(run)
	var g: GridContainer = GridContainer.new()
	g.name = "StreetGrid"
	g.columns = mini(cols, maxi(1, cells.size()))
	g.add_theme_constant_override("h_separation", SEP)
	g.add_theme_constant_override("v_separation", SEP)
	var wrap: CenterContainer = CenterContainer.new()
	wrap.add_child(g)
	var did: String = str(run.district().get("id", ""))
	for cell: int in cells.size():
		var i: int = cells[cell]
		if i < 0:
			# the gap a taken card left: the same size, so nothing else moves
			var gap: Control = Control.new()
			gap.name = "StreetGap%d" % cell
			gap.custom_minimum_size = Vector2(card_w, card_h)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			g.add_child(gap)
			continue
		var c: DDCard = run.street[i]
		var spec: Dictionary = DDPayloads.street_card_spec(c, i, run)
		if not spec.has("art_keys"):
			spec["art_keys"] = Art.card_keys(c, did)
		if card_w < 160.0:
			spec["badge_size"] = DDUi.FONT_S - 4
		elif run.boss_street and run.street.size() <= 2:
			# dd-ux-clean2 (U2): the boss street's two big cards get bigger words too
			spec["text_scale"] = clampf(minf(card_w / 200.0, card_h / 280.0), 1.0, 1.4)
		var cv: DDCardView = _view(spec, Vector2(card_w, card_h))
		cv.index = i
		cv.tapped.connect(_on_card_tapped)
		_drag_source(cv, {"type": "street", "index": i})
		if c.kind == DDCard.ZOMBIE:
			# dd-challenge-rack: hovering a zombie (desktop) shows on each gun tile whether that
			# kill keeps or breaks its challenge
			cv.mouse_entered.connect(func() -> void: show_kill_verdicts(i))
			cv.mouse_exited.connect(func() -> void: clear_kill_verdicts())
		g.add_child(cv)
		var cid: int = c.get_instance_id()
		_street_views[cid] = cv
		_street_specs[cid] = spec
		_street_cards[cid] = c
		_street_order.append(cid)
	return wrap


## The strip between the street and the guns: the draw pile (cards are dealt from right here),
## the one "what just happened" line (tap or long press it for the history), the resolve pips,
## and Lookout's top card when you have it.
func _build_strip(run: DDRun, strip_h: float) -> Control:
	var h: HBoxContainer = DDUi.hbox(SEP)
	h.custom_minimum_size = Vector2(0, strip_h)
	h.name = "Strip"
	var ps: Dictionary = DDPayloads.pile_spec(run)
	ps["art_keys"] = Art.deck_back_keys("pile")
	ps["art_tint"] = 0.72
	ps["big_size"] = 24
	ps["title"] = "PILE"
	ps.erase("tag")
	ps["title_size"] = DDUi.FONT_S - 3
	var layers: int = mini(3, ceili(run.pile.size() / 6.0))
	var pv: DDCardView = _view(ps, Vector2(112, strip_h - 4.0 * layers))
	pv.index = IDX_PILE
	pv.name = "Pile"
	pv.tapped.connect(func(_x: DDCardView) -> void: _inspect.open(DDPayloads.pile(Game.run)))
	_pile_view = pv
	h.add_child(_stacked(pv, layers, "D"))
	var lk: Control = _build_lookout(run)
	if lk != null:
		h.add_child(lk)
	var p: DDCardView = _custom_tile("D", DDPayloads.history(run), DDUi.PANEL)
	p.name = "Log"
	# dd-art2-import: the event log sits on the painted HUD strip
	var log_st: StyleBox = DDUi.painted("hud", 6)
	if log_st != null:
		var old_rim: Node = p.get_node_or_null(^"PaintedRim")
		if old_rim != null:
			p.remove_child(old_rim)
			old_rim.queue_free()
		p.add_theme_stylebox_override("panel", log_st)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.tapped.connect(func(_v: DDCardView) -> void: _inspect.open(DDPayloads.history(Game.run)))
	var row: HBoxContainer = DDUi.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var said: String = last_block if last_block != "" else str(last_event.get("text", ""))
	if said == "" and not run.log_lines.is_empty():
		said = run.log_lines[run.log_lines.size() - 1]
	if run.boss_street:
		var bl: String = "Boss: resolve every card (%d left)." % run.cards_left_to_resolve()
		said = bl if said.begins_with("Boss:") or said == "" else bl + " " + said
	var ll: Label = DDUi.label(said, DDUi.FONT_S - 4, DDUi.WARN if last_block != "" else DDUi.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	ll.name = "LastLine"
	ll.max_lines_visible = 2
	ll.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ll.custom_minimum_size = Vector2(10, 0)
	ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ll.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(ll)
	if not run.boss_street:
		row.add_child(_resolve_pips(run))
	h.add_child(p)
	return h


## Lookout Patch: the pile's top card + BURY (once per street), next to the pile.
func _build_lookout(run: DDRun) -> Control:
	var lc: DDCard = run.lookout_card()
	if lc == null:
		return null
	var row: HBoxContainer = DDUi.hbox(4)
	var tv: DDCardView = _view({"kind": lc.kind, "tag": "TOP", "big": str(lc.value) if lc.kind != DDCard.WEAPON else "", "big_size": 20, "row": true,
		"payload": DDPayloads.card(lc, run)}, Vector2(64, TAP))
	row.add_child(tv)
	var bb: Button = DDUi.button("BURY" if run.can_bury() else "buried", DDUi.PANEL_HI, DDUi.FONT_S - 4)
	bb.name = "BuryButton"
	bb.custom_minimum_size = Vector2(72, TAP)
	bb.disabled = not run.can_bury() or busy
	bb.pressed.connect(do_bury)
	_inspectable_button(bb, {"kind": "P", "t1": "Bury · Lookout", "t2": "Send the top card to the bottom of the pile, once a street."})
	row.add_child(bb)
	return row


## The street's resolve pips: one dot per card you may resolve, filled as you resolve them.
func _resolve_pips(run: DDRun) -> Control:
	var h: HBoxContainer = DDUi.hbox(4)
	h.name = "ResolvePips"
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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


# ---------------------------------------------------------------- guns, melee, run
## The gun row: the two gun tiles and a narrow column with two small buttons, MELEE and RUN
## (head's note on M1). Portrait: one row. Landscape: a column (gun 1, gun 2, [melee | run]).
func _build_guns(run: DDRun, row: bool, gun_h: float, width: float) -> Control:
	var box: BoxContainer = BoxContainer.new()
	box.vertical = not row
	box.add_theme_constant_override("separation", SEP)
	box.name = "Guns"
	if row:
		box.custom_minimum_size = Vector2(0, gun_h)
	var small_w: float = 112.0
	# dd-ui6: the socket row and the Full set plate have fixed heights; the art band takes the rest
	# (portrait: gun_h is the row; landscape: gun_h is the column, two guns over melee / run)
	var tile_h: float = gun_h if row else (gun_h - maxf(TAP, 80.0) - SEP * 2) / 2.0
	var sock_h: float = 62.0 if row else clampf(tile_h * 0.26, 50.0, 92.0)
	var plate_h: float = 36.0 if tile_h < 260.0 or row else 38.0
	for s: int in 2:
		var spec: Dictionary = DDPayloads.gun_spec(run, s)
		spec["socket_h_max"] = sock_h
		spec["plate_h"] = plate_h
		spec["chal_h"] = 22.0
		# landscape: the challenge line sits beside a compact Full set plate (the art keeps its band)
		spec["chal_inline"] = not row
		# dd-gun-tile: a short tile (landscape phone) runs the kill column its full height; a taller one
		# (desktop) keeps the plate + challenge row the tile's full width under the art and the column
		spec["kill_col_full"] = not row and tile_h < 260.0
		var gv: DDGunView = DDGunView.new()
		gv.setup_gun(spec)
		gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gv.size_flags_vertical = Control.SIZE_EXPAND_FILL
		gv.index = IDX_GUN + s
		gv.inspected.connect(_on_inspect)
		gv.tapped.connect(func(_v: DDCardView) -> void: tap_weapon(s))
		if run.slot(s) != null:
			_drag_source(gv, {"type": "weapon", "w": s})
		for k: int in gv.stack_cards.size():
			gv.stack_cards[k].index = IDX_STACK + s * 10 + k
		_gun_views[s] = gv
		box.add_child(gv)
	var small: BoxContainer = BoxContainer.new()
	small.vertical = row
	small.add_theme_constant_override("separation", SEP)
	if row:
		small.custom_minimum_size = Vector2(small_w, 0)
	else:
		small.custom_minimum_size = Vector2(0, maxf(TAP, 80.0))
	var mv: DDCardView = _melee_tile(run)
	mv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	small.add_child(mv)
	var rb: Control = _run_button(run)
	rb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	small.add_child(rb)
	box.add_child(small)
	return box


## MELEE as a small button (v4: DDV4Hooks.melee_spec): the yellow hit badge, MELEE / ACTIVE, the uses
## mark (dd-capacity: icon + uses left) or "no pts" for bare hands, and the name (Bare Hands or the weapon). The
## tile is a DDCardView: tap = make it active, right click / long press = its tooltip.
func _melee_tile(run: DDRun) -> DDCardView:
	var ms: Dictionary = DDV4Hooks.melee_spec(run)
	var on: bool = bool(ms.get("active", false))
	var mv: DDCardView = _custom_tile("K", DDPayloads.melee(run), DDUi.card_bg("K"))
	mv.set_selected(on)
	mv.add_theme_stylebox_override("panel", DDUi.box(DDUi.card_bg("K"), DDUi.SELECT if on else DDUi.accent("K"), 4 if on else 2, 12, 4))
	if mv.get_node_or_null(^"PaintedRim") != null:
		var mb: StyleBoxFlat = DDUi.Kit.card_body(DDUi.card_bg("K"), 4.0)
		if on:
			mb.shadow_color = Color(DDUi.SELECT, 0.35)
			mb.shadow_size = 10
		mv.add_theme_stylebox_override("panel", mb)
	mv.index = IDX_MELEE
	mv.name = "Melee"
	mv.custom_minimum_size = Vector2(0, TAP)
	var tex: Texture2D = Art.texture_for(ms.get("art_keys", []))
	if tex != null:
		# dd-polish5: the art sits faint on the right, away from the text
		var tr: TextureRect = TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.self_modulate = Color(1, 1, 1, 0.16)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mv.add_child(tr)
		mv.art_rect = tr
	# dd-polish5 (head: "a visual bug when we select a melee weapon"): the old one-row button
	# (burst | tag / name / pips) was wider than the button on phones, so the burst slid over the
	# border and the text. Now two rows that always fit: [hit badge | MELEE or ACTIVE + uses], then
	# the weapon's name on its own full-width line (shrinks to fit, never clipped mid-word).
	var col: VBoxContainer = DDUi.vbox(2)
	col.name = "MeleeBox"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.add_child(col)
	var tag: Label = DDUi.label("ACTIVE" if on else "MELEE", DDUi.FONT_S - 6, DDUi.SELECT if on else DDUi.accent("K"))
	tag.name = "MeleeTag"
	tag.clip_text = true
	tag.custom_minimum_size = Vector2(10, 0)
	# dd-capacity: a melee weapon shows its uses as the uses mark (icon + number) beside the hit
	# badge, the same pair as on its card. Portrait (a narrow button): MELEE / [hit | uses] / name;
	# landscape: [hit | MELEE | uses] / name.
	var bare: bool = bool(ms.get("bare", true))
	if portrait:
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(tag)
	var h: HBoxContainer = DDUi.hbox(5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(h)
	var burst: Control = Marks.HitBurst.new(int(ms.get("power", run.melee_power())))
	burst.name = "HitBurst"
	burst.custom_minimum_size = Vector2(30, 30)
	burst.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(burst)
	mv.hit_burst = burst
	if not portrait:
		var tv: VBoxContainer = DDUi.vbox(1)
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(tv)
		tv.add_child(tag)
		if bare:
			tv.add_child(_melee_no_pts(mv))
	elif bare:
		h.add_child(_melee_no_pts(mv))
	if not bare:
		var um: Control = Marks.StatMark.new(int(ms.get("uses", 0)), "uses")
		um.name = "UsesMark"
		um.custom_minimum_size = Vector2(float(um.call("width_for", 30.0)), 30.0)
		um.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(um)
		mv.stat_mark = um
	var nl: Label = DDUi.label(str(ms.get("name", "")), DDUi.FONT_S - 3, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	nl.clip_text = true
	nl.custom_minimum_size = Vector2(10, 0)
	nl.name = "MeleeName"
	nl.add_theme_constant_override("outline_size", 4)
	nl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	nl.resized.connect(func() -> void: DDCardView.fit_label(nl, DDUi.FONT_S - 3, 9))
	col.add_child(nl)
	mv.tapped.connect(func(_v: DDCardView) -> void: tap_weapon(DDRun.MELEE))
	_drag_source(mv, {"type": "weapon", "w": DDRun.MELEE})
	_melee_view = mv
	return mv


## Bare Hands' "no pts" under / beside the hit badge on the melee button.
func _melee_no_pts(mv: DDCardView) -> Label:
	var pl: Label = DDUi.label("no pts", DDUi.FONT_S - 6, DDUi.TEXT_DIM)
	pl.name = "MeleeUses"
	pl.clip_text = true
	pl.custom_minimum_size = Vector2(10, 0)
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mv.big_label = pl
	return pl


## RUN (or RUN PAST / NO ESCAPE on a boss street) as a small button beside melee.
func _run_button(run: DDRun) -> Control:
	if run.boss_street and run.is_final_district():
		var ne: PanelContainer = DDUi.panel(Color("3b1414"), 6, DDUi.BAD, 3)
		ne.name = "NoEscape"
		ne.custom_minimum_size = Vector2(0, TAP)
		var nl: Label = DDUi.label("NO\nESCAPE", DDUi.FONT_S - 5, DDUi.BAD, HORIZONTAL_ALIGNMENT_CENTER)
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ne.add_child(nl)
		# dd-art2-import: the painted red tag (ink words) centred in the slot, not stretched to its height
		if DDUi.Kit.tex("dd_tag_red") != null:
			ne.remove_child(nl)
			nl.queue_free()
			ne.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			var nt: PanelContainer = DDUi.tag("NO\nESCAPE", "red", DDUi.FONT_S - 5, DDUi.BAD)
			var nts: StyleBox = nt.get_theme_stylebox("panel")
			nts.content_margin_left = 12.0
			nts.content_margin_right = 12.0
			nts.content_margin_top = 4.0
			nts.content_margin_bottom = 4.0
			nt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ne.add_child(nt)
		return ne
	if run.boss_street:
		# r2 (playtest: "greyed out with no reason, and the tooltip still offered it"): when it is
		# off, the button and its tooltip say why, and the tooltip doesn't offer it
		var rp_dmg: int = Game.bal.num("boss_runpast_damage")
		var rp_why: String = run.run_past_block_reason()
		var rp_off: bool = rp_why != ""
		var rp: Button = DDUi.button("RUN PAST\n-%d HP" % rp_dmg if not rp_off else "RUN PAST\nfight on", Color("5a2a1a") if not rp_off else DDUi.PANEL,
			DDUi.FONT_S - 4 if not rp_off else DDUi.FONT_S - 5)
		rp.name = "RunPast"
		rp.autowrap_mode = TextServer.AUTOWRAP_OFF
		rp.custom_minimum_size = Vector2(0, TAP)
		rp.disabled = rp_off or busy
		rp.pressed.connect(func() -> void:
			if not _was_long(rp):
				do_run_past())
		_inspectable_button(rp, run_past_payload(run))
		return rp
	var why: String = run.run_block_reason()
	var cost: int = run.run_cost()
	var short_why: String = {"you ran last street": "not twice", "only before your first card": "too late",
		"nothing on the street": "no cards", "the pile is empty": "pile empty", "not enough HP": "low HP"}.get(why, "blocked" if why != "" else "")
	# dd-ux-text (playtest): the cost is the second line, as big as RUN (the reason when it is off)
	var rb: Button = DDUi.button(("RUN\n-%d HP" % cost if cost > 0 else "RUN\nfree") if why == "" else ("RUN\n" + short_why), Color("5a2a1a") if why == "" else DDUi.PANEL,
		DDUi.FONT_S - 2 if why == "" else DDUi.FONT_S - 5)
	rb.name = "Run"
	rb.autowrap_mode = TextServer.AUTOWRAP_OFF
	rb.custom_minimum_size = Vector2(0, TAP)
	rb.disabled = why != "" or busy
	rb.pressed.connect(func() -> void:
		if not _was_long(rb):
			do_run())
	var rpl: Dictionary = DDV4Hooks.run_payload(run)
	if why != "":
		rpl["t2"] = "Not now: %s." % why
	_inspectable_button(rb, rpl)
	return rb


## r2: Run past's tooltip. Off: the reason, and no offer ("Boss street: resolve every card").
func run_past_payload(run: DDRun) -> Dictionary:
	var dmg: int = Game.bal.num("boss_runpast_damage")
	var why: String = run.run_past_block_reason()
	if why == "":
		var lethal: bool = run.hp + run.cover - dmg <= 0
		return {"kind": "F", "tag": "RUN PAST", "title": "Run past", "big": "-%d" % dmg,
			"body": "Before your first card on the boss street: take %d damage and skip the boss. No reward, no free Patch.%s" % [dmg, "\nTHIS KILLS YOU." if lethal else ""],
			"t1": "Run past · -%d HP" % dmg, "t2": "Skip the boss: no reward, no free Patch." + (" This kills you." if lethal else "")}
	var t2: String = "Boss street: resolve every card. Run past works only before your first card." if why == "you already started the fight" else "Not now: %s." % why
	return {"kind": "F", "tag": "RUN PAST · OFF", "title": "Run past is off", "big": "",
		"body": t2, "t1": "Run past · off (you started the fight)" if why == "you already started the fight" else "Run past · off", "t2": t2}


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
	var p: PanelContainer = DDUi.skin_panel(DDUi.panel(Color("1d2b3a"), 6, DDUi.accent("W"), 2), "hud", 12)
	p.name = "Hint"
	p.custom_minimum_size = Vector2(0, HINT_H)
	var h: HBoxContainer = DDUi.hbox(6)
	p.add_child(h)
	h.add_child(DDUi.label("TIP", DDUi.FONT_S - 4, DDUi.accent("W")))
	var l: Label = DDUi.label(DDText.hint_text(hint_id, run.bal), DDUi.FONT_S - 4, DDUi.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	# r2 (accessibility): a bigger Got it (>= 44 CSS px on a phone)
	var ok: Button = DDUi.button("Got it", DDUi.PANEL_HI, DDUi.FONT_S - 1)
	ok.name = "HintOk"
	ok.custom_minimum_size = Vector2(104, DDUi.TAP_MIN)
	ok.pressed.connect(dismiss_hint)
	h.add_child(ok)
	return p


## dd-ui-clean: the hint as a floating toast over the strip's event-log line, same width, centred on
## it, with a drop shadow. It lives on the sheet layer, so nothing in the street moves or resizes when it
## comes or goes; only the toast catches taps (Got it), everything around it still reaches the cards.
func _float_hint(hint: Control, strip: Control) -> void:
	# over the event-log line only: the draw pile next to it stays tappable / inspectable
	var log_node: Control = strip.find_child("Log", true, false) as Control
	var anchor: Control = log_node if log_node != null else strip
	var toast: PanelContainer = PanelContainer.new()
	toast.name = "Hint"
	var sh: StyleBoxFlat = StyleBoxFlat.new()
	sh.bg_color = Color(0, 0, 0, 0)
	sh.shadow_color = Color(0, 0, 0, 0.55)
	sh.shadow_size = 12
	sh.shadow_offset = Vector2(0, 4)
	sh.set_corner_radius_all(DDUi.Kit.radius(10.0))
	toast.add_theme_stylebox_override("panel", sh)
	toast.mouse_filter = Control.MOUSE_FILTER_STOP
	hint.name = "HintPanel"
	toast.add_child(hint)
	_sheet_root.add_child(toast)
	var place: Callable = func() -> void:
		if not is_instance_valid(toast) or not is_instance_valid(anchor) or not anchor.is_inside_tree():
			return
		var r: Rect2 = anchor.get_global_rect()
		var h: float = maxf(HINT_H, toast.get_combined_minimum_size().y)
		var vp: Vector2 = get_viewport_rect().size
		# centred on the log line; a taller (wrapped) tip grows upward, never down onto the gun row
		var y: float = clampf(minf(r.position.y + (r.size.y - h) * 0.5, r.end.y - h), 0.0, maxf(0.0, vp.y - h))
		toast.global_position = Vector2(r.position.x, y)
		toast.size = Vector2(r.size.x, h)
	anchor.item_rect_changed.connect(place)
	toast.minimum_size_changed.connect(place)
	place.call_deferred()


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
	if str(sheet.get("type", "")) in ["patches", "leave_confirm"]:
		kind = str(sheet["type"])
	elif not run.pending_patch.is_empty():
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
	var panel: PanelContainer = DDUi.skin_panel(DDUi.panel(DDUi.PANEL, 14, DDUi.SELECT, 2), "modal", 22)
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
		"melee":
			_melee_sheet(run, v, int(sheet.get("index", 0)))
		"room_confirm":
			_room_confirm_sheet(run, v, int(sheet.get("room", 0)))
		"patches":
			_patches_list_sheet(run, v)
		"leave_confirm":
			_leave_confirm_sheet(run, v)


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
	top.add_child(_view({"kind": "W", "tag": "GUN", "hit": Game.bal.weapon_power(c.wid), "cap": Game.bal.weapon_cap(c.wid), "title": Game.bal.weapon_name(c.wid), "payload": gp, "art_keys": Art.weapon_keys(c.wid, Game.bal.weapon_name(c.wid))}, Vector2(170, 130)))
	# dd-ux-clean: three plain lines; the card's zoom has the full text
	var rw: Array = Game.bal.weapon_reward(c.wid)
	var txt: Label = DDUi.label("Strength %d · %d kills fill it\nEach kill: %s\nChallenge: %s -> %s" % [Game.bal.weapon_power(c.wid), Game.bal.weapon_cap(c.wid),
		DDText.rule_short(Game.bal.weapon_rule(c.wid), run.steady()), DDText.challenge_name(Game.bal.weapon_challenge(c.wid)), DDText.reward_short(str(rw[0]), int(rw[1]), Game.bal)],
		DDUi.FONT_S - 1, DDUi.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
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
		var label: String = DDV4Hooks.equip_label(run, i, s)
		row.add_child(_sheet_button(label, bool(pv["ok"]), Color("1f4a63"), func() -> void: do_resolve(i, DDRun.EQUIP1 if s == 0 else DDRun.EQUIP2)))
	var ps: Dictionary = run.card_preview(i, DDRun.SCRAP)
	row.add_child(_sheet_button("SCRAP\n+%d pts" % Game.bal.shown(int(ps.get("points", 0))), bool(ps["ok"]), Color("5a4a1d"), func() -> void: do_resolve(i, DDRun.SCRAP)))
	v.add_child(_sheet_button("Cancel", true, DDUi.PANEL_HI, close_sheet))


## v4: the melee weapon card sheet: the card, its two lines, TAKE / SCRAP (DDV4Hooks.melee_choices).
func _melee_sheet(run: DDRun, v: VBoxContainer, i: int) -> void:
	if i < 0 or i >= run.street.size() or run.street[i].kind != DDCard.MELEE:
		sheet = {}
		return
	var c: DDCard = run.street[i]
	var top: BoxContainer = BoxContainer.new()
	top.vertical = portrait
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var mp: Dictionary = DDPayloads.card(c, run, i)
	top.add_child(_view({"kind": "K", "tag": "MELEE", "hit": Game.bal.melee_power(c.wid), "uses": run.melee_take_uses(c.wid), "title": Game.bal.melee_name(c.wid),
		"payload": mp, "art_keys": DDV4Hooks.melee_art_keys(c.wid, Game.bal.melee_name(c.wid))}, Vector2(170, 130)))
	var txt: Label = DDUi.label("%s\n%s" % [str(mp.get("t1", "")), str(mp.get("t2", ""))], DDUi.FONT_S - 1, DDUi.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.custom_minimum_size = Vector2(240, 0)
	top.add_child(txt)
	var row: BoxContainer = BoxContainer.new()
	row.vertical = portrait
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for ch: Dictionary in DDV4Hooks.melee_choices(run, i):
		var choice: String = str(ch["choice"])
		var lab: String = str(ch["label"]) if bool(ch["enabled"]) else "%s\n%s" % [str(ch["label"]).split("\n")[0], str(ch["reason"])]
		var b: Button = _sheet_button(lab, bool(ch["enabled"]) and not busy, Color("5a3d1d") if choice == DDRun.TAKE else Color("5a4a1d"), func() -> void: do_resolve(i, choice))
		b.name = "Melee_" + choice
		row.add_child(b)
	v.add_child(_sheet_button("Cancel", true, DDUi.PANEL_HI, close_sheet))


func _machine_sheet(run: DDRun, v: VBoxContainer, i: int) -> void:
	var m: Dictionary = run.machine(i)
	var kind: String = str(m.get("kind", ""))
	if kind == "wall":
		_rack_sheet(run, v, i)
		return
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
	hv.add_child(DDUi.label(DDText.machine_name(kind).to_upper() + " - " + str(run.room(i).get("name", "")), DDUi.FONT_M, DDUi.accent("Q")))
	hv.add_child(DDUi.label("Once per wave · you have %d pts" % Game.bal.shown(run.points), DDUi.FONT_S - 2, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true))
	var grid: GridContainer = GridContainer.new()
	grid.columns = (3 if not portrait else 2) if kind == "bench" else (2 if kind == "wall" else 1)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for o: Dictionary in run.machine_options(i):
		var t: String = "%s · %d pts" % [str(o["label"]), Game.bal.shown(int(o["price"]))]
		var res: String = str(o["result"]) if bool(o["enabled"]) else str(o["reason"])
		var b: Button = _sheet_button(t + ("\n" + res if res != "" else ""), bool(o["enabled"]) and not busy, Color("3d4f2a"), func() -> void: do_machine(i, str(o["id"])))
		b.add_theme_font_size_override("font_size", DDUi.FONT_S - 4)
		b.custom_minimum_size = Vector2(0, 84)
		grid.add_child(b)
	v.add_child(_sheet_button("Close", true, DDUi.PANEL_HI, close_sheet))


## dd-challenge-rack (head: "The wall rack should show a nice preview of the weapon when we want to
## buy it"): the Wall Rack sheet. Each gun for sale is a preview card like a street gun card (its art,
## hit badge, capacity mark, rule), with its rule, challenge + reward and price beside it; tap the
## card = its full zoom. Then one BUY button per slot with the price (dark with "need N more pts"
## when you can't pay). Portrait: card | details, the BUY buttons under them. Landscape: card |
## details | [BUY 1, BUY 2, Close]. More than one gun would sit in a swipe row.
func _rack_sheet(run: DDRun, v: VBoxContainer, i: int) -> void:
	var m: Dictionary = run.machine(i)
	var wid: String = str(m.get("wid", ""))
	var price: int = Game.bal.weapon_price(wid)
	var vp: Vector2 = get_viewport_rect().size
	var short: bool = vp.y < 640.0
	var title: HBoxContainer = DDUi.hbox(8)
	title.name = "RackHead"
	v.add_child(title)
	var tl: Label = DDUi.label("WALL RACK - " + str(run.room(i).get("name", "")), DDUi.FONT_M if not short else DDUi.FONT_S, DDUi.accent("Q"))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	var have: Label = DDUi.label("you have %d pts" % Game.bal.shown(run.points), DDUi.FONT_S - 3, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	have.name = "RackHave"
	have.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(have)
	var offers: Array[String] = []
	if wid != "":
		offers.append(wid)
	var opts: Array = run.machine_options(i)
	var offer_box: BoxContainer = BoxContainer.new()
	offer_box.vertical = false
	offer_box.add_theme_constant_override("separation", 10)
	if offers.size() > 1:
		# more guns than fit: a swipe row
		var sc: ScrollContainer = ScrollContainer.new()
		sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.custom_minimum_size = Vector2(0, 220)
		sc.add_child(offer_box)
		v.add_child(sc)
	else:
		v.add_child(offer_box)
	for w: String in offers:
		offer_box.add_child(_rack_offer(run, w, price, vp, short))
	var buys: Array[Button] = []
	for o: Dictionary in opts:
		var ok: bool = bool(o["enabled"]) and not busy
		var why: String = str(o["reason"])
		if run.points < int(o["price"]) and (why == "" or why.begins_with("need")):
			why = "need %d more pts" % Game.bal.shown(int(o["price"]) - run.points)
		var t: String = "%s · %d pts\n%s" % [str(o["label"]), Game.bal.shown(int(o["price"])), str(o["result"]) if bool(o["enabled"]) else why]
		var b: Button = _sheet_button(t, ok, Color("3d4f2a"), func() -> void: do_machine(i, str(o["id"])))
		b.name = "RackBuy" + str(o["id"]).trim_prefix("slot")
		b.add_theme_font_size_override("font_size", DDUi.FONT_S - 4)
		b.custom_minimum_size = Vector2(0, 72 if not short else 64)
		if not ok:
			b.add_theme_color_override("font_disabled_color", DDUi.WARN)
		buys.append(b)
	var close: Button = _sheet_button("Close", true, DDUi.PANEL_HI, close_sheet)
	if portrait:
		var row: HBoxContainer = DDUi.hbox(8)
		row.name = "RackBuys"
		v.add_child(row)
		for b2: Button in buys:
			row.add_child(b2)
		v.add_child(close)
	else:
		var col: VBoxContainer = DDUi.vbox(6)
		col.name = "RackBuys"
		col.custom_minimum_size = Vector2(250, 0)
		for b3: Button in buys:
			col.add_child(b3)
		col.add_child(close)
		if offer_box.get_child_count() > 0:
			offer_box.get_child(0).add_child(col)
		else:
			v.add_child(col)


## One Wall Rack offer: the preview card and its details (rule, challenge + goal, price).
func _rack_offer(run: DDRun, wid: String, price: int, vp: Vector2, short: bool) -> Control:
	var b: DDBalance = Game.bal
	var rosa: bool = run.steady()
	var box: HBoxContainer = DDUi.hbox(10)
	box.name = "RackOffer"
	var gp: Dictionary = DDPayloads.gun_def(wid, b, "WALL RACK · %d PTS" % b.shown(price), rosa)
	var spec: Dictionary = {"kind": "W", "tag": "", "hit": b.weapon_power(wid), "cap": b.weapon_cap(wid), "title": b.weapon_name(wid),
		"lines": [[DDText.rule_tag(b.weapon_rule(wid), rosa), DDUi.accent("W"), DDUi.FONT_S - 3]], "rule_chip": DDPayloads.weapon_rule_chip(wid, b, rosa),
		"payload": gp, "art_keys": Art.weapon_keys(wid, b.weapon_name(wid)), "selected": true}
	var cw: float = 200.0
	var ch: float = 270.0 if not short else 240.0
	var cv: DDCardView = _view(spec, Vector2(cw, ch))
	cv.name = "RackCard"
	cv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cv.tapped.connect(func(_x: DDCardView) -> void: _on_inspect(gp))
	box.add_child(cv)
	var d: VBoxContainer = DDUi.vbox(4)
	d.name = "RackDetails"
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.alignment = BoxContainer.ALIGNMENT_CENTER
	# the details column gets the width the card and (landscape) the BUY column leave
	var inner: float = minf(vp.x - 32.0, 620.0 if portrait else 900.0) - 28.0
	d.custom_minimum_size = Vector2(maxf(120.0, minf(360.0, inner - cw - 10.0 - (0.0 if portrait else 260.0))), 0)
	box.add_child(d)
	var fs: int = DDUi.FONT_S - 3
	d.add_child(DDUi.label("Strength %d · %d kills fill it (+%d)" % [b.weapon_power(wid), b.weapon_cap(wid), b.shown(b.num("finish_bonus"))], fs, DDUi.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	d.add_child(_icon_line(Art.rule_keys(b.weapon_rule(wid)), "Each kill: %s" % DDText.rule_short(b.weapon_rule(wid), rosa), fs, DDUi.WARN))
	var cid: String = b.weapon_challenge(wid)
	if cid != "":
		var rw: Array = b.weapon_reward(wid)
		var cl: Control = _icon_line(Art.badge_keys("challenge_open"), "%s -> %s" % [DDText.challenge_name(cid).to_upper(), DDText.reward_short(str(rw[0]), int(rw[1]), b)], fs, DDUi.GOOD)
		cl.name = "RackChallenge"
		d.add_child(cl)
		var gl: Label = DDUi.label(DDText.challenge_goal(cid, b).substr(0, 1).to_upper() + DDText.challenge_goal(cid, b).substr(1), fs - 1, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
		gl.name = "RackGoal"
		d.add_child(gl)
	var pr: PanelContainer = DDUi.tag("%d PTS" % b.shown(price), "bone", DDUi.FONT_S - 1, DDUi.accent("X") if run.points >= price else DDUi.TEXT_DIM)
	pr.name = "RackPrice"
	pr.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	d.add_child(pr)
	if run.points < price:
		var nl: Label = DDUi.label("need %d more" % b.shown(price - run.points), fs - 1, DDUi.WARN)
		nl.name = "RackNeed"
		d.add_child(nl)
	return box


func _icon_line(keys: Array, text: String, fs: int, col: Color) -> HBoxContainer:
	var h: HBoxContainer = DDUi.hbox(4)
	var tex: Texture2D = Art.texture_for(keys)
	if tex != null:
		var tr: TextureRect = TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(fs + 4, fs + 4)
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(tr)
	var l: Label = DDUi.label(text, fs, col, HORIZONTAL_ALIGNMENT_LEFT, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h


func _patch_sheet(run: DDRun, v: VBoxContainer) -> void:
	var src: String = str(run.pending_patch.get("source", ""))
	v.add_child(DDUi.label("Pick 1 Patch · for the whole run" if src == "press" else "PICK A PATCH", DDUi.FONT_M, DDUi.accent("P"), HORIZONTAL_ALIGNMENT_CENTER, true))
	var row: BoxContainer = BoxContainer.new()
	row.vertical = portrait
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for p: Variant in run.pending_patch.get("offer", []):
		var pid: String = str(p)
		var spec: Dictionary = DDPayloads.patch_spec(pid, Game.bal, false)
		spec["art_keys"] = Art.patch_keys(pid)
		spec["art_fit"] = "contain"
		if portrait:
			spec["art_side"] = 88.0
		var cv: DDCardView = _view(spec, Vector2(0, 96 if portrait else 200))
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.tapped.connect(func(_x: DDCardView) -> void: do_take_patch(pid))
		row.add_child(cv)
		var b: Button = _sheet_button("TAKE %s" % DDText.patch_name(pid).to_upper(), not busy, Color("2f2f5a"), func() -> void: do_take_patch(pid))
		b.custom_minimum_size = Vector2(0, TAP)
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
				blocked_tap(i, str(pr["reason"]))
				return
			# r2 (playtest: "I died to the boss in one tap on 7 HP; nothing stopped me"): a kill that
			# would end the run asks once: the card shakes red and says so; the same tap (or drop)
			# again within a few seconds goes ahead
			if bool(pr["dies"]):
				var who: String = "Melee" if run.active == DDRun.MELEE else run.slot(run.active).name
				if not lethal_gate("attack:%d:%d" % [c.get_instance_id(), run.active],
						"THIS KILLS YOU: %s takes %d HP, you have %d. Sure? Do it again to go ahead." % [who, int(pr["hp_loss"]), run.hp],
						_street_views.get(c.get_instance_id())):
					return
			var snap: Dictionary = _snapshot()
			var ev: Dictionary = run.attack(i)
			_finish(ev, {"type": "attack", "ev": ev, "snap": snap})
		DDCard.WEAPON:
			# dd-ux-equip (head): a free slot takes the gun straight away (it flies in); with both
			# slots full the sheet asks: into slot 1 / into slot 2 (each says what it replaces), scrap
			var free: int = auto_slot(i)
			if free >= 0:
				do_resolve(i, DDRun.EQUIP1 if free == 0 else DDRun.EQUIP2)
				return
			sheet = {"type": "gun", "index": i}
			Sfx.cue(&"button", 0.9)
			_queue_render()
		DDCard.MELEE:
			# v4: a melee weapon card: TAKE it (melee slot) or SCRAP it. dd-ux-equip: with Bare
			# Hands there is nothing to replace, so a tap takes it
			if not run.has_melee_weapon() and bool(run.card_preview(i, DDRun.TAKE).get("ok", false)):
				do_resolve(i, DDRun.TAKE)
				return
			sheet = {"type": "melee", "index": i}
			Sfx.cue(&"button", 0.9)
			_queue_render()
		DDCard.MEDKIT:
			# v5 (playtest: "a First Aid Kit taken at full HP heals 0 and is gone"): at full HP a tap
			# asks first; a second tap within the toast uses it anyway (it still spends a resolve)
			var pv: Dictionary = run.card_preview(i, DDRun.USE)
			if bool(pv.get("ok", false)) and int(pv.get("heal", 0)) <= 0 and int(pv.get("cover", 0)) <= 0:
				if _confirm_heal != c.get_instance_id():
					_confirm_heal = c.get_instance_id()
					Sfx.cue(&"warn")
					var cv: DDCardView = _street_views.get(c.get_instance_id())
					last_block = "Full HP: this heals 0. Tap again to use it anyway."
					_toast(last_block, cv)
					if OS.has_feature("web"):
						_publish_state()
					return
			_confirm_heal = 0
			do_resolve(i, DDRun.USE)
		_:
			do_resolve(i, DDRun.USE)


## dd-ux-text (playtest): a tap on a zombie the active weapon can't take answers at once: the card
## shakes, the active gun pulses, and a one-line toast over the card says why, in the same words
## as the card's LOCK line ("Rifle: needs 5 or lower"). No re-render, so the shake is seen.
func blocked_tap(i: int, reason: String) -> void:
	var run: DDRun = Game.run
	var c: DDCard = run.street[i]
	var who: String = "Melee" if run.active == DDRun.MELEE else (run.slot(run.active).name if run.slot(run.active) != null else "Empty slot")
	last_block = "%s: %s" % [who, reason]
	Sfx.cue(&"warn")
	var cv: DDCardView = _street_views.get(c.get_instance_id())
	if cv != null and is_instance_valid(cv):
		_shake(cv)
		feedback._pulse(cv, Color(1.6, 0.6, 0.6))
	if run.active != DDRun.MELEE and _gun_views[run.active] != null and is_instance_valid(_gun_views[run.active]):
		feedback._pulse(_gun_views[run.active], Color(1.6, 1.4, 0.6))
	_toast(last_block, cv)
	var ll: Label = _content.find_child("LastLine", true, false) as Label
	if ll != null:
		ll.text = last_block
		ll.add_theme_color_override("font_color", DDUi.WARN)
	if OS.has_feature("web"):
		_publish_state()


## A short horizontal shake (none with reduce motion: the toast and the pulse still say it).
func _shake(c: Control) -> void:
	if Game.reduce_motion() or c == null:
		return
	var x0: float = c.position.x
	var tw: Tween = c.create_tween()
	for d: float in [9.0, -8.0, 6.0, -4.0, 2.0, 0.0]:
		tw.tween_property(c, "position:x", x0 + d, 0.045)


var _toast_node: Control = null
## v5: the medkit (instance id) that asked "full HP: tap again" (0 = none).
var _confirm_heal: int = 0
## r2: the lethal action that asked "This kills you. Sure?" ("" = none) and when (msec).
var confirm_lethal: String = ""
var _confirm_lethal_at: int = 0
const LETHAL_CONFIRM_MS: int = 5000


## r2: the "This kills you. Sure?" gate. The first time an action `key` would end the run, the
## anchor shakes and flashes red, a toast says so (and the event line), and it returns false; the
## same action again within LETHAL_CONFIRM_MS returns true (go ahead). Any other action resets it.
func lethal_gate(key: String, text: String, anchor: Control = null) -> bool:
	var now: int = Time.get_ticks_msec()
	if confirm_lethal == key and now - _confirm_lethal_at <= LETHAL_CONFIRM_MS:
		confirm_lethal = ""
		return true
	confirm_lethal = key
	_confirm_lethal_at = now
	last_block = text
	Sfx.cue(&"warn")
	if anchor != null and is_instance_valid(anchor):
		_shake(anchor)
		feedback._pulse(anchor, Color(1.9, 0.35, 0.35))
	_toast(text, anchor, 3.6, DDUi.BAD)
	var ll: Label = _content.find_child("LastLine", true, false) as Label
	if ll != null:
		ll.text = text
		ll.add_theme_color_override("font_color", DDUi.BAD)
	if OS.has_feature("web"):
		_publish_state()
	return false


## dd-ux-text: a one-line toast over `anchor` (or mid-screen), gone after 1.8 s; it never takes taps.
func _toast(text: String, anchor: Control = null, hold: float = 1.8, edge: Color = DDUi.WARN) -> void:
	if _toast_node != null and is_instance_valid(_toast_node):
		_toast_node.queue_free()
	var t: PanelContainer = DDUi.panel(Color(0.09, 0.06, 0.05, 0.94), 10, edge, 3 if edge != DDUi.WARN else 2)
	t.name = "BlockToast"
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = DDUi.label(text, DDUi.FONT_S - 3, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	l.name = "ToastText"
	t.add_child(l)
	_sheet_root.add_child(t)
	_toast_node = t
	var vp: Vector2 = get_viewport_rect().size
	var w: float = minf(vp.x - 24.0, 460.0)
	if anchor != null and is_instance_valid(anchor):
		w = minf(w, maxf(anchor.size.x + 40.0, 260.0))
	l.custom_minimum_size = Vector2(w - 24.0, 0)
	t.custom_minimum_size = Vector2(w, 0)
	t.size = t.get_combined_minimum_size()
	var place: Callable = func() -> void:
		if not is_instance_valid(t):
			return
		t.size = t.get_combined_minimum_size()
		var h: float = t.size.y
		var ctr: Vector2 = anchor.get_global_rect().get_center() if anchor != null and is_instance_valid(anchor) else vp * 0.5
		t.global_position = Vector2(clampf(ctr.x - w * 0.5, 12.0, vp.x - w - 12.0), clampf(ctr.y - h * 0.5, 12.0, vp.y - h - 12.0))
	place.call_deferred()
	var tw: Tween = t.create_tween()
	t.modulate.a = 0.0
	tw.tween_property(t, "modulate:a", 1.0, 0.12)
	tw.tween_interval(hold)
	tw.tween_property(t, "modulate:a", 0.0, 0.3)
	tw.tween_callback(t.queue_free)


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


## dd-ux-equip: the gun slot a tap on street gun card i equips straight away (the first empty
## slot the gun may go into), or -1 when both slots hold a gun (then the sheet asks).
func auto_slot(i: int) -> int:
	var run: DDRun = Game.run
	if run == null or i < 0 or i >= run.street.size() or run.street[i].kind != DDCard.WEAPON:
		return -1
	for s: int in 2:
		if run.slot(s) == null and bool(run.card_preview(i, DDRun.EQUIP1 if s == 0 else DDRun.EQUIP2).get("ok", false)):
			return s
	return -1


# ---------------------------------------------------------------- drag and drop (dd-ux-equip)
## One model (scripts/ui/dd_drag.gd): lift a tile (10 px of movement), lit targets take it, dark
## ones and empty space snap it back. Sources and their targets:
## - a street gun card -> gun slot 1 / 2 (replacing pays the salvage, as the sheet does) or SCRAP;
## - a street melee weapon -> the melee button (TAKE) or SCRAP;
## - a medkit / cover card -> the HP panel (use it);
## - a gun / melee button -> a zombie (attack it with that weapon; it becomes the active one);
## - a zombie -> a gun / melee button (the same attack).
## The SCRAP zone exists only while a gun / melee card is lifted: it covers the pile strip.
var _scrap_zone: Control = null


func _drag_source(v: DDCardView, src: Dictionary) -> void:
	v.drag_enabled = true
	v.set_meta(&"drag_src", src)
	v.drag_started.connect(func(view: DDCardView, gp: Vector2) -> void: start_drag(view, src, gp))
	v.drag_moved.connect(func(_view: DDCardView, gp: Vector2) -> void:
		if drag != null:
			drag.move(gp))
	v.drag_released.connect(func(_view: DDCardView, gp: Vector2) -> void: end_drag(gp))


## The drop targets for a drag source ({type: "street", index} or {type: "weapon", w}):
## [{name, control, ok, reason, act}] (DDDrag's target shape). Names: slot1, slot2, scrap, melee,
## hp, gun0, gun1, zombie<i>.
func drag_targets(src: Dictionary) -> Array[Dictionary]:
	var run: DDRun = Game.run
	var out: Array[Dictionary] = []
	if run == null or screen != Screen.STREET:
		return out
	if str(src.get("type", "")) == "weapon":
		var w: int = int(src.get("w", 0))
		for i: int in run.street.size():
			var zc: DDCard = run.street[i]
			if zc.kind != DDCard.ZOMBIE:
				continue
			var pr: Dictionary = run.preview(i, w)
			out.append({"name": "zombie%d" % i, "control": _street_views.get(zc.get_instance_id()), "ok": bool(pr["ok"]), "reason": str(pr.get("reason", "")),
				"act": func() -> void: drag_attack(w, i)})
		return out
	var idx: int = int(src.get("index", -1))
	if idx < 0 or idx >= run.street.size():
		return out
	var c: DDCard = run.street[idx]
	match c.kind:
		DDCard.ZOMBIE:
			for s: int in 2:
				if run.slot(s) == null:
					continue
				var pz: Dictionary = run.preview(idx, s)
				out.append({"name": "gun%d" % s, "control": _gun_views[s], "ok": bool(pz["ok"]), "reason": str(pz.get("reason", "")),
					"act": func() -> void: drag_attack(s, idx)})
			var pm: Dictionary = run.preview(idx, DDRun.MELEE)
			out.append({"name": "melee", "control": _melee_view, "ok": bool(pm["ok"]), "reason": str(pm.get("reason", "")),
				"act": func() -> void: drag_attack(DDRun.MELEE, idx)})
		DDCard.WEAPON:
			for s2: int in 2:
				var ch: String = DDRun.EQUIP1 if s2 == 0 else DDRun.EQUIP2
				var pe: Dictionary = card_preview_safe(idx, ch)
				out.append({"name": "slot%d" % (s2 + 1), "control": _gun_views[s2], "ok": bool(pe["ok"]), "reason": str(pe.get("reason", "")),
					"act": func() -> void: do_resolve(idx, ch)})
			out.append(_scrap_target(idx))
		DDCard.MELEE:
			var pt: Dictionary = card_preview_safe(idx, DDRun.TAKE)
			out.append({"name": "melee", "control": _melee_view, "ok": bool(pt["ok"]), "reason": str(pt.get("reason", "")),
				"act": func() -> void: do_resolve(idx, DDRun.TAKE)})
			out.append(_scrap_target(idx))
		_:
			var pu: Dictionary = card_preview_safe(idx, DDRun.USE)
			out.append({"name": "hp", "control": _hp_anchor, "ok": bool(pu["ok"]), "reason": str(pu.get("reason", "")),
				"act": func() -> void: do_resolve(idx, DDRun.USE)})
	return out


func card_preview_safe(i: int, choice: String) -> Dictionary:
	var pv: Dictionary = Game.run.card_preview(i, choice)
	if busy:
		pv["ok"] = false
	return pv


func _scrap_target(idx: int) -> Dictionary:
	var ps: Dictionary = card_preview_safe(idx, DDRun.SCRAP)
	return {"name": "scrap", "control": _scrap_zone, "ok": bool(ps["ok"]), "reason": str(ps.get("reason", "")),
		"points": int(ps.get("points", 0)), "act": func() -> void: do_resolve(idx, DDRun.SCRAP)}


## The SCRAP drop zone over the pile strip ("SCRAP · +N pts"), for the drag of card idx.
func _make_scrap_zone(idx: int) -> Control:
	var strip: Control = _content.find_child("Strip", true, false)
	if strip == null:
		return null
	var pts: int = int(Game.run.card_preview(idx, DDRun.SCRAP).get("points", 0))
	var z: PanelContainer = PanelContainer.new()
	z.name = "ScrapZone"
	var zst: StyleBoxFlat = DDUi.box(Color("2a2410"), DDUi.accent("X"), 3, 12, 8)
	zst.border_blend = false
	z.add_theme_stylebox_override("panel", zst)
	var l: Label = DDUi.label("SCRAP here  ·  +%d pts" % Game.bal.shown(pts), DDUi.FONT_S, DDUi.accent("X"), HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	z.add_child(l)
	var r: Rect2 = strip.get_global_rect()
	z.position = r.position
	z.size = r.size
	z.custom_minimum_size = r.size
	return z


func start_drag(view: DDCardView, src: Dictionary, gp: Vector2) -> void:
	var run: DDRun = Game.run
	if drag == null or busy or run == null or screen != Screen.STREET or not run.pending_patch.is_empty() or not sheet.is_empty():
		return
	if str(src.get("type", "")) == "weapon" and int(src.get("w", 0)) != DDRun.MELEE and run.slot(int(src["w"])) == null:
		return
	var extras: Array[Control] = []
	_scrap_zone = null
	var idx: int = int(src.get("index", -1))
	if str(src.get("type", "")) == "street" and idx >= 0 and idx < run.street.size() and run.street[idx].kind in [DDCard.WEAPON, DDCard.MELEE]:
		_scrap_zone = _make_scrap_zone(idx)
		if _scrap_zone != null:
			extras.append(_scrap_zone)
	drag.reduce = Game.reduce_motion()
	Sfx.cue(&"flip", 1.2)
	drag.begin(view, _drag_ghost(view, src), drag_targets(src), gp, src, extras)
	_drag_verdicts(src, drag.hovered)
	if OS.has_feature("web"):
		_publish_state.call_deferred()


## The lifted copy: a street card is copied as it is; a gun / melee button lifts a small card of
## its weapon (the big gun tile would cover the street).
func _drag_ghost(view: DDCardView, src: Dictionary) -> Control:
	var run: DDRun = Game.run
	if str(src.get("type", "")) == "street":
		var idx: int = int(src.get("index", -1))
		if idx >= 0 and idx < run.street.size():
			var spec: Variant = _street_specs.get(run.street[idx].get_instance_id())
			if spec is Dictionary:
				return _view((spec as Dictionary).duplicate(true), view.size)
		return null
	var w: int = int(src.get("w", 0))
	if w == DDRun.MELEE:
		var ms: Dictionary = DDV4Hooks.melee_spec(run)
		var gs: Dictionary = {"kind": "K", "tag": "MELEE", "hit": run.melee_power(), "title": str(ms.get("name", "")), "art_keys": ms.get("art_keys", [])}
		if not bool(ms.get("bare", true)):
			gs["uses"] = run.melee_uses()
		return _view(gs, Vector2(120, 150))
	var g: DDGun = run.slot(w)
	if g == null:
		return null
	return _view({"kind": "W", "tag": "GUN", "hit": g.power, "cap": g.cap, "title": g.name, "art_keys": Art.weapon_keys(g.wid, g.name)}, Vector2(120, 150))


func end_drag(gp: Vector2) -> void:
	if drag == null or not drag.is_active():
		return
	var t: Dictionary = drag.release(gp)
	_scrap_zone = null
	if OS.has_feature("web"):
		_publish_state.call_deferred()
	if not t.is_empty() and not bool(t.get("ok", false)):
		# a dark target: say why, right where the board says what happened
		Sfx.cue(&"warn")
		var ll: Label = _content.find_child("LastLine", true, false)
		if ll != null and str(t.get("reason", "")) != "":
			ll.text = "Can't: %s." % str(t["reason"])
			ll.add_theme_color_override("font_color", DDUi.WARN)


## dd-challenge-rack: the keep / break verdict of killing street zombie i, on each gun tile whose
## gun can take it (a gun that can't, or has no challenge left, keeps its normal line).
func show_kill_verdicts(i: int, only_slot: int = -1) -> void:
	var run: DDRun = Game.run
	if run == null or i < 0 or i >= run.street.size() or run.street[i].kind != DDCard.ZOMBIE or not sheet.is_empty():
		return
	var z: int = run.street[i].value
	for s: int in 2:
		var gv: DDGunView = _gun_views[s] as DDGunView if s < _gun_views.size() else null
		if gv == null or not is_instance_valid(gv):
			continue
		var vd: String = ""
		if (only_slot < 0 or only_slot == s) and run.slot(s) != null and bool(run.preview(i, s).get("ok", false)):
			vd = run.challenge_kill(s, z)
		gv.set_verdict(vd, z)


func clear_kill_verdicts() -> void:
	for gv: Variant in _gun_views:
		if gv is DDGunView and is_instance_valid(gv):
			(gv as DDGunView).set_verdict("")


## While dragging: a lifted zombie shows its verdict on both guns; a gun lifted over a zombie shows
## that zombie's verdict on the lifted gun.
func _drag_verdicts(src: Dictionary, hovered: String) -> void:
	if str(src.get("type", "")) == "street":
		var idx: int = int(src.get("index", -1))
		var run: DDRun = Game.run
		if run != null and idx >= 0 and idx < run.street.size() and run.street[idx].kind == DDCard.ZOMBIE:
			show_kill_verdicts(idx)
			return
	elif str(src.get("type", "")) == "weapon" and int(src.get("w", 0)) != DDRun.MELEE and hovered.begins_with("zombie"):
		show_kill_verdicts(int(hovered.trim_prefix("zombie")), int(src["w"]))
		return
	clear_kill_verdicts()


## Drop helper (tests, the web smoke): runs the drop of src on the target called `target_name`;
## false when there is no such target or it is dark.
func drop_on(src: Dictionary, target_name: String) -> bool:
	for t: Dictionary in drag_targets(src):
		if str(t["name"]) == target_name:
			if not bool(t["ok"]):
				return false
			(t["act"] as Callable).call()
			return true
	return false


## A drag of weapon w onto zombie i: w becomes the active weapon, then it attacks (the same as a
## tap on the weapon, then a tap on the zombie).
func drag_attack(w: int, i: int) -> void:
	var run: DDRun = Game.run
	if busy or run == null:
		return
	if run.active != w and bool(run.set_active(w).get("ok", false)):
		Game.save_run()
	tap_street(i)


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
	var run: DDRun = Game.run
	if run != null and run.hp + run.cover - run.run_cost() <= 0 and not lethal_gate("run",
			"THIS KILLS YOU: Run costs %d HP, you have %d. Sure? Tap RUN again to go ahead." % [run.run_cost(), run.hp], _content.find_child("Run", true, false) as Control):
		return
	var snap: Dictionary = _snapshot()
	var ev: Dictionary = Game.run.run_street()
	_finish(ev, {"type": "run", "ev": ev, "snap": snap})


func do_run_past() -> void:
	if busy:
		return
	var run: DDRun = Game.run
	var dmg: int = Game.bal.num("boss_runpast_damage")
	if run != null and run.hp + run.cover - dmg <= 0 and not (run.has_patch("second_wind") and not run.second_wind_used) and not lethal_gate("run_past",
			"THIS KILLS YOU: Run past costs %d HP, you have %d. Sure? Tap RUN PAST again to go ahead." % [dmg, run.hp], _content.find_child("RunPast", true, false) as Control):
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
		_pending_banner = {"text": "%s OPEN" % str(Game.run.room(i).get("name", "")).to_upper(), "color": DDUi.accent("Q"),
			"sub": "Tap USE for the %s" % DDText.machine_name(str(Game.run.machine(i).get("kind", ""))), "delay": 1.5}
	_finish(ev, {"type": "room", "ev": ev, "snap": snap})


## v5 (playtest: "I spent 210 on the Garage and its Wall Rack wanted another 150 I didn't have"):
## the OPEN plate opens at once when you can also use the machine this wave; otherwise a short
## sheet shows the door, what is inside and what you'll have left, and asks first.
func request_open_room(i: int) -> void:
	if busy:
		return
	if Game.run.room_machine_short(i):
		sheet = {"type": "room_confirm", "room": i}
		Sfx.cue(&"button", 0.9)
		_queue_render()
		return
	do_open_room(i)


func _room_confirm_sheet(run: DDRun, v: VBoxContainer, i: int) -> void:
	var r: Dictionary = run.room(i)
	var m: Dictionary = run.machine(i)
	var b: DDBalance = Game.bal
	var price: int = b.shown(run.room_cost(i))
	var left: int = b.shown(run.points) - price
	v.add_child(DDUi.label("OPEN %s · %d pts" % [str(r.get("name", "")).to_upper(), price], DDUi.FONT_M, DDUi.accent("R"), HORIZONTAL_ALIGNMENT_CENTER, true))
	var lines: PackedStringArray = []
	lines.append("Inside: %s, and the %s." % [DDPayloads._pack_short(run, i), DDText.machine_name(str(m.get("kind", "")))])
	lines.append("The %s costs %s. After opening you'll have %d: not enough to use it this wave." % [DDText.machine_name(str(m.get("kind", ""))),
		DDPayloads.machine_use_text(run, i), left])
	lines.append("Door + one use: %d." % b.shown(run.room_total_cost(i)))
	var body: Label = DDUi.label("\n".join(lines), DDUi.FONT_S - 2, DDUi.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	body.name = "RoomConfirmText"
	v.add_child(body)
	var row: HBoxContainer = DDUi.hbox(8)
	v.add_child(row)
	var ok: Button = _sheet_button("OPEN FOR %d" % price, not busy, Color("6b5a1e"), func() -> void:
		sheet = {}
		do_open_room(i))
	ok.name = "RoomConfirmOpen"
	row.add_child(ok)
	var no: Button = _sheet_button("NOT YET", true, DDUi.PANEL_HI, close_sheet)
	no.name = "RoomConfirmCancel"
	row.add_child(no)


## r2: "340 pts stay here: spend first?" What you can still buy, then SPEND FIRST / LEAVE ANYWAY.
func _leave_confirm_sheet(run: DDRun, v: VBoxContainer) -> void:
	var b: DDBalance = Game.bal
	var lost: int = b.shown(int(run.shop_state().get("left_behind", 0)))
	var t: Label = DDUi.label("%d PTS STAY HERE" % lost, DDUi.FONT_L, DDUi.WARN, HORIZONTAL_ALIGNMENT_CENTER, true)
	t.name = "LeaveConfirmTitle"
	v.add_child(t)
	var can: PackedStringArray = []
	if run.shop_patch_block_reason() == "":
		can.append("a Patch (%d pts)" % b.shown(run.shop_patch_price()))
	if run.supplies_max() > 0:
		can.append("up to +%d HP (%d pts each)" % [run.supplies_max(), b.shown(run.supplies_rate())])
	var lines: PackedStringArray = ["Points don't come with you to the next district. Your score keeps them."]
	lines.append(("You can still buy %s." % " or ".join(can)) if not can.is_empty() else "Nothing here costs that little: leaving loses them anyway.")
	var body: Label = DDUi.label("\n".join(lines), DDUi.FONT_S, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	body.name = "LeaveConfirmText"
	v.add_child(body)
	var row: HBoxContainer = DDUi.hbox(8)
	v.add_child(row)
	var spend: Button = _sheet_button("SPEND FIRST", true, Color("245236"), close_sheet)
	spend.name = "LeaveConfirmSpend"
	spend.custom_minimum_size = Vector2(0, DDUi.TAP_MIN)
	row.add_child(spend)
	var go: Button = _sheet_button("LEAVE ANYWAY\n(lose %d pts)" % lost, true, Color("5a2a1a"), confirm_leave)
	go.name = "LeaveConfirmLeave"
	go.custom_minimum_size = Vector2(0, DDUi.TAP_MIN)
	row.add_child(go)


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
		p["t2"] = str(ev.get("text", ""))
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
	confirm_lethal = ""
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
		_pending_banner = {"text": "WAVE %d" % [int(info["wave"]) + 1], "color": DDUi.TEXT, "wave": int(info["wave"]) + 1,
			"sub": "%d cards · zombies %s" % [int(info.get("cards", 0)) + int(info.get("restock", 0)), DDText.zombie_range(info.get("zombies", []))], "delay": 0.0}
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
## dd-ux-v4 (head's M5 a): a banner lasts BANNER_S seconds and a tap anywhere skips it.
const BANNER_S: float = 1.8
var last_banner: String = ""
var _banner: Control = null
var _banner_layer: Control = null
var _banner_tween: Tween = null
var _banner_seq: int = 0


func banner_open() -> bool:
	return _banner != null and is_instance_valid(_banner) and not _banner.is_queued_for_deletion()


func dismiss_banner() -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = null
	if _banner_layer != null and is_instance_valid(_banner_layer):
		_banner_layer.queue_free()
	_banner_layer = null
	_banner = null
	# the wave numeral lands on its final value even when the banner was skipped
	for wv: Variant in _wave_views:
		if wv != null and is_instance_valid(wv) and (wv as Node).has_meta(&"numeral"):
			var num: Control = (wv as Node).get_meta(&"numeral")
			if is_instance_valid(num):
				_stop_numeral(num)
				if num.has_meta(&"final_text"):
					num.set("text", str(num.get_meta(&"final_text")))
					num.remove_meta(&"final_text")
					num.queue_redraw()
				num.scale = Vector2.ONE
				num.position.y = 0.0
				num.modulate.a = 1.0
				num.offset_top = 22
	if OS.has_feature("web"):
		_publish_state.call_deferred()


func _stop_numeral(num: Control) -> void:
	var nt: Variant = num.get_meta(&"tween") if num.has_meta(&"tween") else null
	if nt is Tween and (nt as Tween).is_valid():
		(nt as Tween).kill()
	num.scale = Vector2.ONE
	num.modulate.a = 1.0
	num.offset_top = 22


## Hides the banner at once (the layer stays until the finger lifts).
func _skip_banner_visuals(layer: Control) -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = null
	for c: Node in layer.get_children():
		(c as CanvasItem).visible = false
	layer.set_meta(&"skipped", true)
	_banner = null
	for wv: Variant in _wave_views:
		if wv != null and is_instance_valid(wv) and (wv as Node).has_meta(&"numeral"):
			var num: Control = (wv as Node).get_meta(&"numeral")
			if is_instance_valid(num):
				_stop_numeral(num)
			if is_instance_valid(num) and num.has_meta(&"final_text"):
				num.set("text", str(num.get_meta(&"final_text")))
				num.remove_meta(&"final_text")
				num.queue_redraw()
				num.scale = Vector2.ONE
				num.modulate.a = 1.0
				num.offset_top = 22
	# safety: free it shortly even if the release never arrives
	var lid: int = layer.get_instance_id()
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if _banner_layer != null and is_instance_valid(_banner_layer) and _banner_layer.get_instance_id() == lid:
			dismiss_banner())
	if OS.has_feature("web"):
		_publish_state.call_deferred()


## A full-screen layer that catches the tap that skips the banner.
func _banner_catcher() -> Control:
	dismiss_banner()
	var layer: Control = Control.new()
	layer.name = "BannerLayer"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	# the tap that skips the banner is eaten whole: the press hides it, the release frees the
	# layer, so the release never lands on a street card underneath
	layer.gui_input.connect(func(e: InputEvent) -> void:
		if not (e is InputEventMouseButton or e is InputEventScreenTouch):
			return
		layer.accept_event()
		if e.is_pressed():
			_skip_banner_visuals(layer)
		else:
			dismiss_banner())
	_fx.add_child(layer)
	_banner_layer = layer
	return layer


func _show_banner(text: String, col: Color, sub: String) -> void:
	last_banner = text
	var vp: Vector2 = get_viewport_rect().size
	var layer: Control = _banner_catcher()
	var p: PanelContainer = DDUi.panel(Color(0.05, 0.06, 0.06, 0.92), 14, col, 3)
	p.name = "Banner"
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
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(p)
	p.size = p.get_combined_minimum_size()
	p.position = Vector2((vp.x - p.size.x) * 0.5, vp.y * 0.3)
	p.modulate.a = 0.0
	var tw: Tween = layer.create_tween()
	_banner_tween = tw
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(BANNER_S - 0.45)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(dismiss_banner)


## Storyboard 3, the WAVE banner: 0.0 s a red edge pulse; 0.1 s the wave door's old number falls
## away; 0.4 s the new one slams in and the banner sweeps across; it holds and fades by 2.2 s
## (1.8 s on screen). A tap anywhere skips it. Reduce motion: no sweep, slam or fall, only fades.
func _wave_banner(n: int, sub: String) -> void:
	last_banner = "WAVE %d" % n
	var vp: Vector2 = get_viewport_rect().size
	var rm: bool = Game.reduce_motion()
	var layer: Control = _banner_catcher()
	# the red edge pulse
	var vig: Panel = Panel.new()
	vig.name = "EdgePulse"
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vs: StyleBoxFlat = StyleBoxFlat.new()
	vs.draw_center = false
	vs.border_color = Color(Marks.BLOOD, 0.75)
	vs.set_border_width_all(int(minf(vp.x, vp.y) * 0.06))
	vs.border_blend = true
	vig.add_theme_stylebox_override("panel", vs)
	vig.modulate.a = 0.0
	layer.add_child(vig)
	# the banner strip: the big numeral + WAVE n + one line
	var p: PanelContainer = DDUi.panel(Color(0.05, 0.03, 0.03, 0.94), 12, Marks.BLOOD, 3)
	p.name = "Banner"
	_banner = p
	var h: HBoxContainer = DDUi.hbox(16)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)
	var big: Control = Marks.WaveNumeral.new(str(n))
	big.custom_minimum_size = Vector2(88, 96)
	h.add_child(big)
	var tv: VBoxContainer = DDUi.vbox(0)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(tv)
	tv.add_child(DDUi.label("WAVE %d" % n, DDUi.FONT_XL, DDUi.TEXT))
	if sub != "":
		tv.add_child(DDUi.label(sub, DDUi.FONT_S, DDUi.TEXT_DIM))
	tv.add_child(DDUi.label("tap to skip", DDUi.FONT_S - 6, Color(DDUi.TEXT_DIM, 0.7)))
	DDUi.ignore_mouse(p)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(p)
	p.custom_minimum_size = Vector2(vp.x, 0)
	p.size = p.get_combined_minimum_size()
	var y: float = vp.y * 0.32
	p.position = Vector2(0, y)
	p.modulate.a = 0.0
	# the wave door's numeral
	var num: Control = null
	for wv: Variant in _wave_views:
		if wv != null and is_instance_valid(wv) and (wv as Node).has_meta(&"numeral"):
			num = (wv as Node).get_meta(&"numeral")
			break
	var tw: Tween = layer.create_tween()
	_banner_tween = tw
	tw.set_parallel(true)
	tw.tween_property(vig, "modulate:a", 1.0, 0.25)
	tw.tween_property(vig, "modulate:a", 0.0, 0.75).set_delay(0.25)
	if num != null and not rm:
		num.set_meta(&"final_text", str(n))
		num.set("text", str(maxi(1, n - 1)))
		num.queue_redraw()
		num.pivot_offset = num.size * 0.5
		# the numeral's own tween: it dies with the door if the board is rebuilt meanwhile
		var nt: Tween = num.create_tween()
		num.set_meta(&"tween", nt)
		nt.set_parallel(true)
		nt.tween_property(num, "offset_top", 22.0 + 16.0, 0.3).set_delay(0.1)
		nt.tween_property(num, "modulate:a", 0.0, 0.3).set_delay(0.1)
		nt.tween_callback(num.set.bind("text", str(n))).set_delay(0.4)
		nt.tween_callback(num.queue_redraw).set_delay(0.4)
		nt.tween_callback(num.set.bind("offset_top", 22.0)).set_delay(0.4)
		nt.tween_callback(num.set.bind("scale", Vector2(2.4, 2.4))).set_delay(0.4)
		nt.tween_callback(num.remove_meta.bind(&"final_text")).set_delay(0.4)
		nt.tween_property(num, "scale", Vector2.ONE, 0.3).set_delay(0.41).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		nt.tween_property(num, "modulate:a", 1.0, 0.2).set_delay(0.41)
	if rm:
		tw.tween_property(p, "modulate:a", 1.0, 0.2).set_delay(0.4)
	else:
		p.position.x = -vp.x
		p.modulate.a = 1.0
		tw.tween_property(p, "position:x", 0.0, 0.32).set_delay(0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 0.0, 0.36).set_delay(0.4 + BANNER_S - 0.36)
	tw.chain().tween_callback(dismiss_banner)
	Sfx.cue(&"clear", 0.8)


## Storyboard 4: a room that just became affordable rings twice (two gold rings grow off the door);
## while a room is affordable its plate glows slowly (2 s). Reduce motion: one brightness pulse,
## no rings, no glow loop.
func _room_pulses() -> void:
	var run: DDRun = Game.run
	if run == null or screen != Screen.STREET:
		return
	if _was_ready_run != run:
		_was_ready_run = run
		_was_ready = []
	var now: Array = []
	for i: int in _room_views.size():
		var rv: DDCardView = _room_views[i]
		var ready: bool = i < run.room_count() and not run.room_open[i] and run.can_open_room(i)
		now.append(ready)
		if not ready or not is_instance_valid(rv):
			continue
		var plate: Control = rv.find_child("Open%d" % i, true, false)
		var fresh: bool = i >= _was_ready.size() or not bool(_was_ready[i])
		if Game.reduce_motion():
			if fresh:
				feedback._pulse(rv, Color(1.4, 1.3, 0.8))
			continue
		if fresh and not _was_ready.is_empty():
			for k: int in 2:
				_ring(rv, 0.8 + 0.45 * k)
			feedback._mark("room_ready")
		if plate != null:
			var gl: Tween = plate.create_tween().set_loops()
			gl.tween_property(plate, "self_modulate", Color(1.3, 1.25, 1.1), 1.0).set_trans(Tween.TRANS_SINE)
			gl.tween_property(plate, "self_modulate", Color.WHITE, 1.0).set_trans(Tween.TRANS_SINE)
	_was_ready = now


func _ring(target: Control, delay: float) -> void:
	var r: Rect2 = target.get_global_rect()
	var ring: Panel = Panel.new()
	ring.name = "ReadyRing"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_theme_stylebox_override("panel", DDUi.box(Color(0, 0, 0, 0), DDUi.WARN, 4, 14, 0))
	ring.position = r.position - _fx.global_position
	ring.size = r.size
	ring.pivot_offset = r.size * 0.5
	ring.modulate.a = 0.0
	_fx.add_child(ring)
	var tw: Tween = ring.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(ring, "modulate:a", 1.0, 0.01)
	tw.tween_property(ring, "scale", Vector2(1.35, 1.35), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.6)
	tw.tween_callback(ring.queue_free)


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
	# dd-ux-clean: one plain line, then your kit as small inspectable tiles, then the choices.
	# v4: points don't come along; the Safehouse Shop is where they are spent.
	v.add_child(DDUi.label("+%d HP when you leave. Guns, Gun Mods and Patches come with you." % run.safehouse_heal(), DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))

	var kit: HFlowContainer = HFlowContainer.new()
	kit.alignment = FlowContainer.ALIGNMENT_CENTER
	kit.add_theme_constant_override("h_separation", SEP)
	kit.add_theme_constant_override("v_separation", SEP)
	v.add_child(kit)
	kit.add_child(_view({"kind": "S", "tag": "HP", "big": "%d/%d" % [run.hp, run.max_hp], "big_size": 22, "row": true, "payload": DDPayloads.hp(run)}, Vector2(120, 56)))
	kit.add_child(_view(_points_spec(run), Vector2(120, 56)))
	for s: int in 2:
		var g: DDGun = run.slot(s)
		kit.add_child(_view({"kind": "W", "tag": "GUN %d" % (s + 1), "title": g.name if g != null else "empty", "row": true, "title_size": DDUi.FONT_S - 2,
			"lines": [["%d/%d kills" % [g.stack.size(), g.cap], DDUi.TEXT_DIM, DDUi.FONT_S - 5]] if g != null else [], "payload": DDPayloads.gun(run, s)}, Vector2(170, 56)))
	if not run.patches.is_empty():
		var pp: Dictionary = DDPayloads.patches(run)
		var pc: DDCardView = _view({"kind": "P", "tag": "PATCHES", "big": str(run.patches.size()), "big_size": 22, "row": true, "payload": pp}, Vector2(110, 56))
		pc.tapped.connect(func(_v: DDCardView) -> void: _inspect.open(pp))
		kit.add_child(pc)
	var offer: Array = run.pending_patch.get("offer", [])
	if not offer.is_empty():
		# v4: the boss Patch is sewn on with the tap (the shop opens after it)
		v.add_child(DDUi.label("Boss reward: tap a free Patch", DDUi.FONT_M, DDUi.accent("P"), HORIZONTAL_ALIGNMENT_CENTER, true))
		var box: BoxContainer = BoxContainer.new()
		box.vertical = portrait
		box.add_theme_constant_override("separation", SEP)
		v.add_child(box)
		for p: Variant in offer:
			var pid: String = str(p)
			var ps: Dictionary = DDPayloads.patch_spec(pid, Game.bal, false)
			ps["art_keys"] = Art.patch_keys(pid)
			ps["art_fit"] = "contain"
			if portrait:
				# dd-art-fit: the Patch as a square beside its text (it was a ~20 px strip); 80 layout px
				# is ~55 CSS px on a 390 px phone
				ps["art_side"] = 80.0
			var cv: DDCardView = _view(ps, Vector2(0, 88 if portrait else 150))
			cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cv.name = "BossPatch_" + pid
			cv.tapped.connect(func(_x: DDCardView) -> void: take_boss_patch(pid))
			box.add_child(cv)
	# v5: the safehouse is three short steps: the boss Patch, a Gun Mod (fit 1 or skip), the shop
	if run.mod_step_open():
		v.add_child(_mod_panel(run))
	elif bool(run.shop_state().get("enabled", false)):
		var shop: DDShopPanel = DDShopPanel.new()
		shop.setup(run, portrait)
		shop.changed.connect(func(_ev: Dictionary) -> void:
			Sfx.cue(&"perk")
			Game.save_run("SAFEHOUSE")
			_queue_render())
		shop.inspect_requested.connect(func(pl: Dictionary) -> void: _inspect.open(pl))
		shop.leave_requested.connect(leave_safehouse)
		v.add_child(shop)
	elif offer.is_empty():
		var nxt: String = str(Game.bal.district(run.district_index + 1).get("name", ""))
		var go: Button = DDUi.button("%s · to %s (+%d HP)" % [DDText.leave_text(int(run.shop_state().get("left_behind", 0)), Game.bal), nxt, run.safehouse_heal()], Color("245236"), DDUi.FONT_M)
		go.name = "LeaveSafehouse"
		go.custom_minimum_size = Vector2(0, 80 if portrait else DDUi.TAP_MIN)
		go.pressed.connect(leave_safehouse)
		v.add_child(go)


## v5: the safehouse's Gun Mods (economy-v5.md): 2 offered, fit 1 (free) to gun slot 1 or 2.
## Each mod is a card (tap / right click / long press = its zoom) with a FIT button per slot that
## says what is in the slot now (and if Short Barrel would finish that gun at once).
func _mod_panel(run: DDRun) -> Control:
	var box: VBoxContainer = DDUi.vbox(6)
	box.name = "ModPanel"
	var price: int = run.mod_price()
	var head: HBoxContainer = DDUi.hbox(8)
	box.add_child(head)
	var hl: Label = DDUi.label(("GUN MOD · fit 1 to a slot, free" if price <= 0 else "GUN MOD · fit 1 to a slot for %d pts (you have %d)" % [Game.bal.shown(price), Game.bal.shown(run.points)]),
		DDUi.FONT_S, DDUi.accent("W"), HORIZONTAL_ALIGNMENT_LEFT, true)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	var skip: Button = _sheet_button("SKIP", not busy, DDUi.PANEL_HI, skip_mod)
	skip.name = "SkipMod"
	skip.size_flags_horizontal = Control.SIZE_FILL
	skip.custom_minimum_size = Vector2(96, 48)
	head.add_child(skip)
	if portrait:
		box.add_child(DDUi.label("Every gun you put in that slot gets it, for the rest of the run.", DDUi.FONT_S - 4, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	var row: BoxContainer = BoxContainer.new()
	row.vertical = portrait
	row.add_theme_constant_override("separation", SEP)
	box.add_child(row)
	for m: String in run.mod_offer:
		var col: VBoxContainer = DDUi.vbox(4)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var mp: Dictionary = DDPayloads.mod(m)
		var cv: DDCardView = _view({"kind": "W", "tag": "GUN MOD", "title": DDText.mod_name(m), "row": true, "title_size": DDUi.FONT_S,
			"lines": [[DDText.mod_text(m), DDUi.TEXT, DDUi.FONT_S - 5]], "payload": mp,
			"lead_icon": Art.texture_for(Art.mod_keys(m, true)), "lead_px": 48.0}, Vector2(0, 64 if portrait else 56))
		cv.name = "Mod_" + m
		cv.tapped.connect(func(_x: DDCardView) -> void: _inspect.open(mp))
		col.add_child(cv)
		var brow: HBoxContainer = DDUi.hbox(6)
		col.add_child(brow)
		for s: int in 2:
			var pv: Dictionary = run.mod_preview(m, s)
			var g: DDGun = run.slot(s)
			var what: String = g.name if g != null else "empty"
			if str(pv.get("replaces", "")) != "":
				what += " · replaces " + DDText.mod_name(str(pv["replaces"]))
			if bool(pv.get("finishes", false)):
				what += " · FULL now"
			var bt: Button = _sheet_button("FIT TO SLOT %d\n%s" % [s + 1, what if bool(pv["ok"]) else str(pv["reason"])], bool(pv["ok"]) and not busy, Color("2f4a5a"),
				func() -> void: pass)
			bt.name = "Fit_%s_%d" % [m, s + 1]
			bt.pressed.connect(func() -> void:
				if not _was_long(bt):
					fit_mod(m, s))
			bt.add_theme_font_size_override("font_size", DDUi.FONT_S - 5)
			bt.custom_minimum_size = Vector2(0, 52)
			bt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_inspectable_button(bt, mp)
			brow.add_child(bt)
	return box


func skip_mod() -> void:
	if bool(Game.run.skip_mod().get("ok", false)):
		Game.save_run("SAFEHOUSE")
	_queue_render()


func fit_mod(m: String, s: int) -> void:
	var ev: Dictionary = Game.run.fit_mod(m, s)
	if bool(ev.get("ok", false)):
		Sfx.cue(&"perk")
		last_event = ev
		Game.save_run("SAFEHOUSE")
		var cs: Array = ev.get("collects", [])
		_toast("%s fitted to slot %d%s" % [DDText.mod_name(m), s + 1, (": the %s is full, +%d" % [str((cs[0] as Dictionary).get("name", "")),
			Game.bal.shown(int((cs[0] as Dictionary).get("points", 0)))]) if not cs.is_empty() else "."])
	_queue_render()


## v4: the boss reward Patch is sewn on when tapped; then the Safehouse Shop opens.
func take_boss_patch(pid: String) -> void:
	var ev: Dictionary = Game.run.take_patch(pid)
	if bool(ev.get("ok", false)):
		Sfx.cue(&"perk")
		chosen_patch = ""
		Game.save_run("SAFEHOUSE")
	_queue_render()


## r2 (playtest: "the Safehouse took my points"): leaving with points that stay behind asks first,
## on a sheet: SPEND FIRST (back to the shop) or LEAVE ANYWAY. With nothing to lose it leaves.
func leave_safehouse() -> void:
	var run: DDRun = Game.run
	if run == null:
		return
	if int(run.shop_state().get("left_behind", 0)) > 0 and str(sheet.get("type", "")) != "leave_confirm":
		sheet = {"type": "leave_confirm"}
		Sfx.cue(&"warn")
		_queue_render()
		return
	confirm_leave()


## Leaves the safehouse now (LEAVE ANYWAY on the warning sheet, or nothing stays behind).
func confirm_leave() -> void:
	var run: DDRun = Game.run
	sheet = {}
	var ev: Dictionary = run.leave_safehouse("")
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
	var sc: PanelContainer = DDUi.skin_panel(DDUi.panel(DDUi.PANEL, 14), "modal", 22)
	var sv: VBoxContainer = DDUi.vbox(4)
	sc.add_child(sv)
	sv.add_child(DDUi.label("Points earned: %d" % Game.bal.shown(run.points_earned), DDUi.FONT_M, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	if won:
		sv.add_child(DDUi.label("HP left: %d  (+%d)" % [run.hp, Game.bal.shown(run.hp * Game.bal.rule("score_hp_mult"))], DDUi.FONT_M, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	sv.add_child(DDUi.label("RUN SCORE %d" % Game.bal.shown(run.run_score()), DDUi.FONT_XL, DDUi.WARN, HORIZONTAL_ALIGNMENT_CENTER))
	var st: Dictionary = run.stats
	sv.add_child(DDUi.label("Best %d  ·  %d kill%s  ·  %d gun%s filled  ·  %d room%s" % [Game.bal.shown(Game.profile.best_score(run.survivor_id)),
		int(st.get("kills", 0)), "" if int(st.get("kills", 0)) == 1 else "s", int(st.get("finished", 0)), "" if int(st.get("finished", 0)) == 1 else "s",
		int(st.get("rooms", 0)), "" if int(st.get("rooms", 0)) == 1 else "s"], DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(sc)
	if not run.patches.is_empty():
		# dd-ux-equip: the run's Patches as their painted icons (each one inspectable)
		v.add_child(DDUi.label("Patches worn", DDUi.FONT_S, DDUi.accent("P"), HORIZONTAL_ALIGNMENT_CENTER))
		var pcc: CenterContainer = CenterContainer.new()
		pcc.add_child(_patch_row(run, 60.0, get_viewport_rect().size.x - MARGIN * 2))
		v.add_child(pcc)
	if not Game.new_unlocks.is_empty():
		v.add_child(DDUi.label("New unlocks", DDUi.FONT_M, DDUi.GOOD, HORIZONTAL_ALIGNMENT_CENTER, true))
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
## &overlay=codex|glossary|banner (dd-ux-v4), &skin=a|b|c|old (dd-ui-clean),
## &hints=1 (first-run hints on), &near=1 (gun 1 one kill from finishing, a legal zombie dealt),
## &lastcards=1 (the pile runs dry after this street: wave 2 shuffles in),
## &street=K:wrench,Z3,M4 (dd-polish5: deal exactly these cards).
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
	# dd-ui-clean: &skin=a|b|c (or old) shows that UI skin for this visit (the saved setting is kept)
	if args.has("skin"):
		DDUi.Kit.set_skin(str(args["skin"]))
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
			# v5 QA: &takepatch=1 takes the boss Patch (the Gun Mod step shows), &points=N
			if str(args.get("takepatch", "0")) == "1" and not run.pending_patch.is_empty():
				run.take_patch(str(run.pending_patch["offer"][0]))
			if args.has("points"):
				run.points = int(args["points"])
			if str(args.get("skipmod", "0")) == "1":
				run.skip_mod()
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
	if args.has("mods"):
		# v5 QA: &mods=last_round,echo puts Gun Mods on slots 1 and 2 ("-" = none)
		var ms: PackedStringArray = str(args["mods"]).split(",")
		for s2: int in mini(2, ms.size()):
			run.slot_mods[s2] = "" if ms[s2] == "-" else ms[s2]
			if run.slot(s2) != null:
				run.slot(s2).cap = DDRun.mod_cap(Game.bal.weapon_cap(run.slot(s2).wid), run.slot_mods[s2])
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
	if args.has("street"):
		# dd-polish5: &street=K:wrench,Z3,M4,C2 deals exactly these cards (QA: melee equip flow)
		var codes: Array[String] = []
		for c: String in str(args["street"]).split(","):
			if c != "":
				codes.append(c)
		run.setup_street(codes)
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
		elif sh == "roomconfirm":
			# v5: exactly the door's price, not enough for its machine: the confirm sheet
			run.points = run.room_cost(0)
			sheet = {"type": "room_confirm", "room": 0}
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
	if args.has("overlay"):
		# dd-ux-v4: &overlay=codex | glossary | banner (the WAVE 2 banner)
		match str(args["overlay"]):
			"codex":
				open_codex.call_deferred()
			"glossary":
				open_glossary.call_deferred()
			"banner":
				_pending_banner = {"text": "WAVE 2", "wave": 2, "sub": "9 cards · zombies 2-7", "delay": 0.0}
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
			"plate1", "plate2":
				var ps: int = 0 if what == "plate1" else 1
				if run.slot(ps) != null:
					_auto_inspect = DDPayloads.full_plate(run, ps)
			_:
				if what.begins_with("wave"):
					_auto_inspect = DDPayloads.waves(run)
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
		"overlay": str(codex.get("mode")) if codex.is_open() else "", "tip": _inspect.last_lines if _inspect.is_open() else [],
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
		# dd-ux-equip: what is in each slot, the melee weapon, the drag in progress, the Codex scroll
		st["guns"] = run.slots.map(func(g: Variant) -> String: return (g as DDGun).wid if g != null else "")
		st["melee"] = str(run.melee.get("id", "")) if run.has_melee_weapon() else ""
	st["drag"] = drag.is_active() if drag != null else false
	st["drag_hover"] = drag.hovered if drag != null else ""
	var csc: Node = codex.find_child("Scroll", true, false) if codex.is_open() else null
	st["codex_scroll"] = (csc as ScrollContainer).scroll_vertical if csc is ScrollContainer else -1
	JavaScriptBridge.eval("window.ddState = " + JSON.stringify(st) + ";", true)


func _css_rect(c: Control, xf: Transform2D, dpr: float) -> Dictionary:
	var r: Rect2 = c.get_global_rect()
	var p0: Vector2 = xf * r.position / dpr
	var p1: Vector2 = xf * r.end / dpr
	return {"x": p0.x, "y": p0.y, "w": p1.x - p0.x, "h": p1.y - p0.y}


func screen_name() -> String:
	return Screen.keys()[screen]

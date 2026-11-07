# main.gd
# Purpose: The whole DeadDraw prototype UI: title (survivor pick), city map, street, safehouse
#   and run-end screens. Rebuilt from the run state after every action, laid out for portrait
#   (2x2 street) or landscape (1x4 street) from the viewport aspect. Rules live in DDRun; this
#   script only renders state, previews outcomes and calls the run's public methods.
# Dependencies: Game (autoload), DDRun, DDPayloads, DDCardView, DDInspect, DDUi, DDText.
# Author: Mechanics Developer Agent
extends Control

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
	if OS.has_feature("web"):
		_inspect.opened.connect(_publish_state)
		_inspect.closed.connect(_publish_state)
	var saved: String = Game.survivor_id
	chosen_survivor = saved if Game.profile.survivor_unlocked(saved) else "rosa"
	get_viewport().size_changed.connect(_render)
	_apply_smoke_query()
	_render()


# ================================================================ rendering
func _render() -> void:
	for c: Node in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_hp_anchor = null
	_weapon_anchor = null
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
	if not _auto_inspect.is_empty():
		var p: Dictionary = _auto_inspect
		_auto_inspect = {}
		_inspect.open.call_deferred(p)
	if OS.has_feature("web"):
		_publish_state.call_deferred()


var _render_queued: bool = false


## Re-render at the end of the frame: handlers run inside a Button's signal, and freeing the
## pressed Button synchronously makes the engine complain.
func _queue_render() -> void:
	if _render_queued:
		return
	_render_queued = true
	(func() -> void:
		_render_queued = false
		_render()).call_deferred()


func _view(spec: Dictionary, min_size: Vector2 = Vector2.ZERO) -> DDCardView:
	var v: DDCardView = DDCardView.new()
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
	var v: VBoxContainer = DDUi.vbox(14)
	_content.add_child(_scroll(v))
	var t: Label = DDUi.label("DEADDRAW", 64 if portrait else 44, DDUi.accent("Z"), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(t)
	v.add_child(DDUi.label("Every street deals four cards. You deal with three.%sThe fourth is waiting for you on the next one." % ("\n" if portrait else " "), DDUi.FONT_M if portrait else DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(DDUi.label("Pick a survivor  (long press / right click to read)", DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	var row: HBoxContainer = DDUi.hbox(SEP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var vp: Vector2 = get_viewport_rect().size
	var w: float = minf(230.0, (vp.x - MARGIN * 2 - SEP * 2) / 3.0)
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
			"dim": not unlocked, "payload": DDPayloads.survivor(sid, Game.bal, Game.profile)}
		var cv: DDCardView = _view(spec, Vector2(w, 220 if portrait else 176))
		cv.tapped.connect(func(_x: DDCardView) -> void:
			if unlocked:
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
		var size: Vector2 = Vector2(vp.x - MARGIN * 2, 150) if portrait else Vector2(minf(300.0, (vp.x - MARGIN * 2 - SEP * 2) / 3.0), 170)
		path.add_child(_view(spec, size))
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
		_queue_render())
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(go)


func _status_line(run: DDRun) -> Control:
	var h: HFlowContainer = HFlowContainer.new()
	h.add_theme_constant_override("h_separation", SEP)
	h.add_theme_constant_override("v_separation", SEP)
	h.alignment = FlowContainer.ALIGNMENT_CENTER
	var s: Dictionary = Game.bal.survivor(run.survivor_id)
	h.add_child(_view({"kind": "S", "tag": "SURVIVOR", "title": str(s.get("name", "")), "lines": [["HP %d / %d" % [run.hp, run.max_hp], DDUi.GOOD, DDUi.FONT_M]], "compact": true,
		"payload": DDPayloads.survivor(run.survivor_id, Game.bal, Game.profile)}, Vector2(190, 0)))
	h.add_child(_view(DDPayloads.weapon_slot_spec(run), Vector2(170, 0)))
	for p: String in run.perks:
		h.add_child(_view(DDPayloads.perk_spec(p, Game.bal, true), Vector2(150, 0)))
	return h


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
		var cv: DDCardView = _view(DDPayloads.street_card_spec(run.street[i], i, run, i == selected), Vector2(card_w, card_h))
		cv.index = i
		cv.tapped.connect(_on_card_tapped)
		grid.add_child(cv)
	var actions: Control = _build_actions(run)
	var log_box: Control = _build_log(run)
	var hp_box: Control = _build_hp(run)
	var info: HBoxContainer = DDUi.hbox(SEP)
	var big_s: int = 44 if portrait else 30
	var ws: Dictionary = DDPayloads.weapon_slot_spec(run)
	ws["big_size"] = big_s
	var wv: DDCardView = _view(ws)
	wv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_anchor = wv
	info.add_child(wv)
	var ds: Dictionary = DDPayloads.deck_spec(run)
	ds["big_size"] = big_s
	var dv: DDCardView = _view(ds)
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(dv)
	var fs: Dictionary = DDPayloads.finale_spec(run.district())
	fs["big_size"] = big_s
	var fv: DDCardView = _view(fs)
	fv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	hv.add_child(DDUi.label("HP  %d / %d" % [run.hp, run.max_hp], DDUi.FONT_L, col))
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
	h.add_child(hp_panel)
	_hp_anchor = hp_panel
	if run.cover > 0:
		h.add_child(_view({"kind": "B", "tag": "COVER", "big": str(run.cover), "big_size": 36, "compact": true,
			"payload": DDPayloads.cover(run)}, Vector2(84, 0)))
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
				return "Use: won't heal" if bool(pr["wasted"]) else "Use: +%d HP" % int(pr["heal"])
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
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.size_flags_vertical = Control.SIZE_SHRINK_END
	btn.pressed.connect(func() -> void:
		var lines: Array[String] = run.log_lines.slice(maxi(0, n - 14))
		_inspect.open({"kind": "D", "tag": "WHAT HAPPENED", "title": "Recent events", "body": "\n".join(lines)}))
	v.add_child(btn)
	return p


func _on_card_tapped(v: DDCardView) -> void:
	if busy:
		return
	selected = -1 if selected == v.index else v.index
	_queue_render()


func _do_resolve(i: int, ch: String) -> void:
	if busy:
		return
	var run: DDRun = Game.run
	var from: int = run.log_lines.size()
	var wn: Array = [run.weapon, run.notch]
	var ev: Dictionary = run.resolve(i, ch)
	if not bool(ev.get("ok", false)):
		return
	ev["_log_from"] = from
	ev["_wn"] = wn
	last_event = ev
	selected = -1
	_after_event(ev)


func _do_retreat() -> void:
	var run: DDRun = Game.run
	var from: int = run.log_lines.size()
	var ev: Dictionary = run.retreat()
	if bool(ev.get("ok", false)):
		ev["_log_from"] = from
		last_event = ev
		selected = -1
		_after_event(ev)


func _do_slip() -> void:
	var run: DDRun = Game.run
	var from: int = run.log_lines.size()
	var ev: Dictionary = run.slip_away()
	if bool(ev.get("ok", false)):
		ev["_log_from"] = from
		last_event = ev
		selected = -1
		_after_event(ev)


func _after_event(ev: Dictionary) -> void:
	var run: DDRun = Game.run
	var weapon_changed: bool = ev.has("_wn") and ev["_wn"] != [run.weapon, run.notch]
	if run.phase == DDRun.Phase.DEAD or run.phase == DDRun.Phase.WON or run.phase == DDRun.Phase.SAFEHOUSE:
		busy = true
		_queue_render()
		_float_hp(int(ev.get("hp_delta", 0)))
		await get_tree().create_timer(1.1).timeout
		busy = false
		if run.phase == DDRun.Phase.SAFEHOUSE:
			safehouse_info = {"district": str(Game.bal.district(run.district_index).get("name", "")),
				"score": run.district_scores[run.district_scores.size() - 1]}
			chosen_perk = ""
			screen = Screen.SAFEHOUSE
		else:
			screen = Screen.END
			if not Game.new_unlocks.is_empty():
				_auto_inspect = DDPayloads.unlock(Game.new_unlocks[0], Game.bal, Game.profile)
		_queue_render()
		return
	_queue_render()
	_float_hp(int(ev.get("hp_delta", 0)))
	if weapon_changed:
		_pulse()


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


func _pulse() -> void:
	await get_tree().process_frame
	var c: Control = _weapon_anchor
	if c == null or not is_instance_valid(c):
		return
	c.modulate = Color(1.6, 1.6, 1.6)
	var tw: Tween = create_tween()
	tw.tween_property(c, "modulate", Color(1, 1, 1), 0.5)


# ---------------------------------------------------------------- safehouse
func _build_safehouse() -> void:
	var run: DDRun = Game.run
	var v: VBoxContainer = DDUi.vbox(12)
	_content.add_child(_scroll(v))
	v.add_child(DDUi.label("%s CLEARED" % str(safehouse_info.get("district", "")).to_upper(), DDUi.FONT_XL, DDUi.GOOD, HORIZONTAL_ALIGNMENT_CENTER, true))
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
		var cv: DDCardView = _view(DDPayloads.perk_spec(pid, Game.bal, false, pid == chosen_perk), size)
		cv.tapped.connect(func(_x: DDCardView) -> void:
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
			screen = Screen.MAP
			_queue_render())
	v.add_child(go)


# ---------------------------------------------------------------- end
func _build_end() -> void:
	var run: DDRun = Game.run
	var won: bool = run.phase == DDRun.Phase.WON
	var v: VBoxContainer = DDUi.vbox(12)
	_content.add_child(_scroll(v))
	v.add_child(DDUi.label("YOU MADE IT OUT" if won else "OVERRUN", 56, DDUi.GOOD if won else DDUi.BAD, HORIZONTAL_ALIGNMENT_CENTER))
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
## Web only: ?screen=street&seed=5&select=0 jumps to a screen with a seeded run (QA screenshots).
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
		if (n is Button or n is DDCardView) and (n as Control).is_visible_in_tree():
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
		"inspect": _inspect.is_open()}
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

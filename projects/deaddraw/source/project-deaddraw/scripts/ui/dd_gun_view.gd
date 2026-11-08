# dd_gun_view.gd
# Purpose: v3 gun card at the bottom of the street: the gun's stats, rule and challenge on the
#   LEFT, its KILL STACK on the right like a board game: every killed zombie is a small card laid
#   over the one before, offset so each number (top-left) stays visible, so the stack visibly
#   grows (fanned downward in portrait, sideways in landscape). A faint outline marks where the next
#   kill lands. The ACTIVE gun has a bright frame. Tap = make it active; long press / right click
#   = the gun's zoom; each stack card has its own zoom. Empty slots say how to fill them.
#   Feedback reads `stack_cards` (the mini cards in kill order) and `next_rect()`.
# Dependencies: DDCardView, DDUi, scripts/ui/dd_art.gd.
# Author: Mechanics Developer Agent
class_name DDGunView
extends DDCardView

const Art: GDScript = preload("res://scripts/ui/dd_art.gd")

## The mini cards of the stack, in kill order (index 0 = first kill).
var stack_cards: Array[DDCardView] = []
var stack_area: Control = null
var vertical_fan: bool = true
var _next_outline: Panel = null
var _cap: int = 0
var _mini: Vector2 = Vector2(64, 84)


## spec: DDPayloads.gun_spec() + "fan_vertical" (bool), "stack_w" (px), "mini" (Vector2).
func setup_gun(spec: Dictionary) -> DDGunView:
	kind = "W"
	payload = spec.get("payload", {})
	_selected = bool(spec.get("active", false))
	mouse_filter = Control.MOUSE_FILTER_STOP
	vertical_fan = bool(spec.get("fan_vertical", true))
	_mini = spec.get("mini", _mini)
	_frame = false
	_row = true
	if bool(spec.get("empty", false)):
		var v: VBoxContainer = DDUi.vbox(2)
		add_child(v)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(DDUi.label("GUN %d - EMPTY" % (int(spec.get("slot", 0)) + 1), DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(DDUi.label("tap a gun card on the street to equip one", DDUi.FONT_S - 4, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
		_apply_style()
		DDUi.ignore_mouse(self)
		return self
	var tex: Texture2D = Art.texture_for(Art.weapon_keys(str(spec.get("wid", "")), str(spec.get("name", ""))))
	if tex != null:
		has_art = true
		var tr: TextureRect = _add_art(self, tex, "cover")
		tr.self_modulate = Color(1, 1, 1, 0.9)
		var scrim: ColorRect = ColorRect.new()
		scrim.color = Color(DDUi.card_bg("W"), 0.8)
		add_child(scrim)
	var h: HBoxContainer = DDUi.hbox(6)
	add_child(h)
	var left: VBoxContainer = DDUi.vbox(1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	_box = left
	var head: HBoxContainer = DDUi.hbox(4)
	left.add_child(head)
	var nl: Label = _one_line(DDUi.label("%d %s" % [int(spec.get("slot", 0)) + 1, str(spec.get("name", "")).to_upper()], DDUi.FONT_S - 3, DDUi.accent("W")))
	_outline(nl, 4)
	head.add_child(nl)
	if _selected:
		var chip: PanelContainer = DDUi.panel(DDUi.SELECT, 2)
		chip.add_child(DDUi.label("ACTIVE", DDUi.FONT_S - 7, DDUi.BG))
		head.add_child(chip)
	var plates: String = ("  HONED" if bool(spec.get("honed", false)) else "") + ("  FLIPPED" if bool(spec.get("flipped", false)) else "")
	var pl: Label = _one_line(DDUi.label("P%d   %d/%d kills%s" % [int(spec.get("power", 0)), (spec.get("stack", []) as Array).size(), int(spec.get("cap", 0)), plates], DDUi.FONT_S - 2, DDUi.TEXT))
	_outline(pl, 4)
	big_label = pl
	left.add_child(pl)
	var rr: HBoxContainer = DDUi.hbox(4)
	left.add_child(rr)
	var rtex: Texture2D = Art.texture_for(Art.rule_keys(str(spec.get("rule", ""))))
	if rtex != null:
		var ri: TextureRect = TextureRect.new()
		ri.texture = rtex
		ri.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ri.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ri.custom_minimum_size = Vector2(24, 24)
		rr.add_child(ri)
	var rl: Label = DDUi.label(str(spec.get("rule_text", "")), DDUi.FONT_S - 4, DDUi.WARN, HORIZONTAL_ALIGNMENT_LEFT, true)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rl.max_lines_visible = 2
	rl.custom_minimum_size = Vector2(0, 30)
	rl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_outline(rl, 4)
	rr.add_child(rl)
	line_labels.append(rl)
	var cr: HBoxContainer = DDUi.hbox(4)
	left.add_child(cr)
	var cs: String = str(spec.get("challenge_state", "open"))
	var btex: Texture2D = Art.texture_for(Art.badge_keys("challenge" if cs == "met" else "challenge_open"))
	if btex != null:
		var bi: TextureRect = TextureRect.new()
		bi.texture = btex
		bi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bi.custom_minimum_size = Vector2(22, 22)
		if cs == "broken":
			bi.self_modulate = Color(0.5, 0.5, 0.5, 0.6)
		cr.add_child(bi)
	var word: String = {"met": "MET", "on_track": "on track", "broken": "missed", "open": ""}.get(cs, "")
	var col: Color = {"met": DDUi.GOOD, "on_track": DDUi.accent("X"), "broken": DDUi.TEXT_DIM}.get(cs, DDUi.TEXT)
	var cl: Label = _one_line(DDUi.label("%s %s%s" % [str(spec.get("challenge", "")), str(spec.get("reward", "")), (" - " + word) if word != "" else ""], DDUi.FONT_S - 5, col))
	_outline(cl, 4)
	cr.add_child(cl)
	line_labels.append(cl)
	var tk: Label = _one_line(DDUi.label("takes: %s" % str(spec.get("can_take", "")), DDUi.FONT_S - 6, DDUi.TEXT_DIM))
	_outline(tk, 4)
	left.add_child(tk)
	# the kill stack
	stack_area = Control.new()
	stack_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack_area.clip_contents = false
	_cap = int(spec.get("cap", 4))
	var n_slots: int = maxi(_cap, (spec.get("stack", []) as Array).size() + 1)
	var step: Vector2 = _step()
	stack_area.custom_minimum_size = Vector2(_mini.x + step.x * (n_slots - 1), _mini.y + step.y * (n_slots - 1))
	h.add_child(stack_area)
	DDUi.ignore_mouse(left)
	var st: Array = spec.get("stack", [])
	var pls: Array = spec.get("stack_payloads", [])
	_next_outline = Panel.new()
	_next_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_outline.add_theme_stylebox_override("panel", DDUi.box(Color(0, 0, 0, 0.25), Color(DDUi.TEXT_DIM, 0.6), 2, 8, 0))
	_next_outline.size = _mini
	_next_outline.visible = int(spec.get("left", 0)) > 0
	stack_area.add_child(_next_outline)
	var nl2: Label = DDUi.label("next", DDUi.FONT_S - 6, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	nl2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nl2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_next_outline.add_child(nl2)
	for k: int in st.size():
		var mc: DDCardView = _make_mini(int(st[k]), pls[k] if k < pls.size() else {})
		stack_area.add_child(mc)
		stack_cards.append(mc)
	_layout_stack()
	_apply_style()
	return self


func _one_line(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(10, 0)
	return l


## Offset between two stack cards: enough to keep the previous card's number visible.
func _step() -> Vector2:
	return Vector2(0, _mini.y * 0.32) if vertical_fan else Vector2(_mini.x * 0.4, 0)


func _layout_stack() -> void:
	var step: Vector2 = _step()
	var n_slots: int = maxi(_cap, stack_cards.size() + 1)
	# each new kill is laid over the one before, offset down (portrait) or right (landscape), so
	# the strip with every earlier number stays visible; tree order draws later kills on top
	for k: int in stack_cards.size():
		stack_cards[k].position = step * k
		stack_cards[k].size = _mini
	if _next_outline != null:
		_next_outline.position = step * stack_cards.size()


## Global rect where the next kill would land.
func next_rect() -> Rect2:
	if _next_outline == null:
		return get_global_rect()
	return Rect2(_next_outline.get_global_rect().position, _mini)


func _make_mini(z: int, pl: Dictionary) -> DDCardView:
	var mc: DDCardView = DDCardView.new()
	mc.kind = "Z"
	mc.payload = pl
	mc.mouse_filter = Control.MOUSE_FILTER_STOP
	mc.custom_minimum_size = _mini
	mc.add_theme_stylebox_override("panel", DDUi.box(DDUi.card_bg("Z"), DDUi.accent("Z"), 2, 8, 0))
	var c: DDCard = DDCard.make(DDCard.ZOMBIE, z)
	var tex: Texture2D = Art.texture_for(Art.card_keys(c))
	if tex != null:
		var tr: TextureRect = TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mc.add_child(tr)
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_child(holder)
	var badge: PanelContainer = DDUi.panel(Color("151214"), 2, DDUi.accent("Z"), 2)
	badge.position = Vector2(2, 2)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = DDUi.label(str(z), maxi(14, int(_mini.x * 0.3)), DDUi.TEXT)
	badge.add_child(l)
	holder.add_child(badge)
	mc.big_label = l
	mc.tapped.connect(func(_v: DDCardView) -> void: tapped.emit(self))
	mc.inspected.connect(func(p: Dictionary) -> void: inspected.emit(p))
	return mc

# dd_gun_view.gd
# Purpose: the gun tile in the street's gun row. dd-ux-v4 (head's points 4, 5, 6): the hit badge
#   (dd-polish5: the yellow circle with the gun's hit number, replacing "P4") and the name on top; the rule as icon + short label;
#   then the KILL SOCKETS, one per kill the gun holds, so capacity reads at a glance: filled sockets
#   show the zombie's art and number (each is inspectable), the next socket shows what it accepts
#   ("<6", ">4", "any"), the rest are dashed; then the challenge reward. The ACTIVE gun has a bright
#   frame and an ACTIVE chip. Tap = make it active; long press / right click = its 2-line tooltip.
#   Feedback reads `stack_cards` (the filled sockets in kill order) and `next_rect()`.
# Dependencies: DDCardView, DDUi, scripts/ui/dd_art.gd, scripts/ui/dd_marks.gd.
# Author: Mechanics Developer Agent (dd-ux-v4 sockets: UI/UX Agent)
class_name DDGunView
extends DDCardView

const Art: GDScript = preload("res://scripts/ui/dd_art.gd")

## The filled sockets, in kill order (index 0 = first kill).
var stack_cards: Array[DDCardView] = []
var stack_area: Control = null
var vertical_fan: bool = false
var _sockets: Array[Control] = []
var _next_socket: Control = null
var _cap: int = 0
var _mini: Vector2 = Vector2(40, 64)
var _socket_h_max: float = 92.0


## spec: DDPayloads.gun_spec() + "socket_h_max" (px).
func setup_gun(spec: Dictionary) -> DDGunView:
	kind = "W"
	payload = spec.get("payload", {})
	_selected = bool(spec.get("active", false))
	mouse_filter = Control.MOUSE_FILTER_STOP
	_socket_h_max = float(spec.get("socket_h_max", 92.0))
	_frame = false
	_row = true
	if bool(spec.get("empty", false)):
		var v: VBoxContainer = DDUi.vbox(2)
		add_child(v)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(DDUi.label("GUN %d · EMPTY" % (int(spec.get("slot", 0)) + 1), DDUi.FONT_S - 2, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(DDUi.label("equip a gun from the street", DDUi.FONT_S - 5, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
		_apply_style()
		DDUi.ignore_mouse(self)
		return self
	var tex: Texture2D = Art.texture_for(Art.weapon_keys(str(spec.get("wid", "")), str(spec.get("name", ""))))
	if tex != null:
		has_art = true
		var tr: TextureRect = _add_art(self, tex, "cover")
		tr.self_modulate = Color(1, 1, 1, 0.9)
		var scrim: ColorRect = ColorRect.new()
		scrim.color = Color(DDUi.card_bg("W"), 0.82)
		add_child(scrim)
	var v2: VBoxContainer = DDUi.vbox(3)
	add_child(v2)
	_box = v2
	# head: hit burst + name (+ ACTIVE)
	var head: HBoxContainer = DDUi.hbox(6)
	v2.add_child(head)
	var burst: Control = Marks.HitBurst.new(int(spec.get("power", 0)))
	burst.custom_minimum_size = Vector2(38, 38)
	burst.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	burst.name = "HitBurst"
	head.add_child(burst)
	hit_burst = burst
	var nv: VBoxContainer = DDUi.vbox(0)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(nv)
	var plates: String = (" · HONED" if bool(spec.get("honed", false)) else "") + (" · FLIPPED" if bool(spec.get("flipped", false)) else "")
	var nl: Label = _one_line(DDUi.label(str(spec.get("name", "")).to_upper() + plates, DDUi.FONT_S - 3, DDUi.accent("W")))
	nl.resized.connect(func() -> void: fit_label(nl, DDUi.FONT_S - 3, 10))
	_outline(nl, 4)
	nv.add_child(nl)
	var kl: Label = _one_line(DDUi.label("%d of %d kills" % [(spec.get("stack", []) as Array).size(), int(spec.get("cap", 0))], DDUi.FONT_S - 6, DDUi.TEXT_DIM))
	_outline(kl, 4)
	big_label = kl
	nv.add_child(kl)
	if _selected:
		var chip: PanelContainer = DDUi.panel(DDUi.SELECT, 3)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(DDUi.label("ACTIVE", DDUi.FONT_S - 7, DDUi.BG))
		head.add_child(chip)
	# rule: icon + short label
	var rr: HBoxContainer = DDUi.hbox(5)
	v2.add_child(rr)
	var rtex: Texture2D = Art.texture_for(Art.rule_keys(str(spec.get("rule", ""))))
	if rtex != null:
		var ri: TextureRect = TextureRect.new()
		ri.texture = rtex
		ri.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ri.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ri.custom_minimum_size = Vector2(22, 22)
		rr.add_child(ri)
	var rl: Label = _one_line(DDUi.label(str(spec.get("rule_text", "")), DDUi.FONT_S - 5, DDUi.WARN))
	rl.resized.connect(func() -> void: fit_label(rl, DDUi.FONT_S - 5, 10))
	_outline(rl, 4)
	rr.add_child(rl)
	line_labels.append(rl)
	# the kill sockets
	_cap = int(spec.get("cap", 4))
	var st: Array = spec.get("stack", [])
	var pls: Array = spec.get("stack_payloads", [])
	stack_area = Control.new()
	stack_area.name = "Sockets"
	stack_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack_area.custom_minimum_size = Vector2(0, 44)
	v2.add_child(stack_area)
	var n_slots: int = maxi(_cap, st.size())
	for k: int in n_slots:
		if k < st.size():
			var mc: DDCardView = _make_mini(int(st[k]), pls[k] if k < pls.size() else {})
			stack_area.add_child(mc)
			stack_cards.append(mc)
			_sockets.append(mc)
		else:
			var nxt: bool = k == st.size() and int(spec.get("left", 0)) > 0
			var sk: Control = Marks.Socket.new(nxt, str(spec.get("accept", "")) if nxt else "")
			sk.name = "NextSocket" if nxt else "Socket%d" % k
			stack_area.add_child(sk)
			_sockets.append(sk)
			if nxt:
				_next_socket = sk
	stack_area.resized.connect(_layout_sockets)
	# the challenge reward
	var cr: HBoxContainer = DDUi.hbox(5)
	v2.add_child(cr)
	var cs: String = str(spec.get("challenge_state", "open"))
	var btex: Texture2D = Art.texture_for(Art.badge_keys("challenge" if cs == "met" else "challenge_open"))
	if btex != null:
		var bi: TextureRect = TextureRect.new()
		bi.texture = btex
		bi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bi.custom_minimum_size = Vector2(18, 18)
		if cs == "broken":
			bi.self_modulate = Color(0.5, 0.5, 0.5, 0.6)
		cr.add_child(bi)
	var word: String = {"met": "met", "on_track": "on track", "broken": "missed", "open": ""}.get(cs, "")
	var col: Color = {"met": DDUi.GOOD, "on_track": DDUi.accent("X"), "broken": DDUi.TEXT_DIM}.get(cs, DDUi.TEXT_DIM)
	var cl: Label = _one_line(DDUi.label("Full +%s · %s%s" % [str(spec.get("finish_shown", "")), str(spec.get("reward", "")), (" · " + word) if word != "" else ""], DDUi.FONT_S - 6, col))
	cl.resized.connect(func() -> void: fit_label(cl, DDUi.FONT_S - 6, 10))
	_outline(cl, 4)
	cr.add_child(cl)
	line_labels.append(cl)
	DDUi.ignore_mouse(v2)
	for mc2: DDCardView in stack_cards:
		mc2.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_style()
	return self


func _one_line(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(10, 0)
	return l


## Sockets share the row: as tall as it allows (up to socket_h_max), 0.62 as wide as tall, never
## wider than the row / capacity.
func _layout_sockets() -> void:
	if stack_area == null or _sockets.is_empty():
		return
	var n: int = _sockets.size()
	var gap: float = 4.0
	var h: float = minf(stack_area.size.y, _socket_h_max)
	var w: float = minf(h * 0.62, (stack_area.size.x - gap * (n - 1)) / n)
	w = maxf(w, 16.0)
	h = minf(h, w / 0.5)
	_mini = Vector2(w, h)
	var x: float = 0.0
	for c: Control in _sockets:
		c.custom_minimum_size = Vector2.ZERO
		c.position = Vector2(x, (stack_area.size.y - h) * 0.5)
		c.size = _mini
		x += w + gap
		if c is DDCardView:
			var badge: Control = c.get_meta(&"badge", null)
			if badge != null:
				var bd: float = clampf(minf(w * 0.7, h * 0.45), 16.0, 34.0)
				badge.position = Vector2(2, 2)
				badge.size = Vector2(bd, bd)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN or what == NOTIFICATION_RESIZED:
		_layout_sockets.call_deferred()


## Global rect where the next kill would land (the next socket).
func next_rect() -> Rect2:
	if _next_socket == null or not is_instance_valid(_next_socket):
		return get_global_rect()
	return Rect2(_next_socket.get_global_rect().position, _mini)


func _make_mini(z: int, pl: Dictionary) -> DDCardView:
	var mc: DDCardView = DDCardView.new()
	mc.kind = "Z"
	mc.payload = pl
	mc.mouse_filter = Control.MOUSE_FILTER_STOP
	mc.clip_contents = true
	mc.add_theme_stylebox_override("panel", DDUi.box(DDUi.card_bg("Z"), Marks.TIER_COLORS[Marks.tier_of(z)], 2, 6, 0))
	var c: DDCard = DDCard.make(DDCard.ZOMBIE, z)
	var tex: Texture2D = Art.texture_for(Art.card_keys(c))
	if tex != null:
		var tr: TextureRect = TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.self_modulate = Color(1, 1, 1, 0.8)
		mc.add_child(tr)
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_child(holder)
	# dd-polish5: the same zombie badge as on the street (blood fill, tier ring)
	var zb: Control = Marks.StrengthMark.new(z)
	zb.name = "NumBadge"
	zb.position = Vector2(2, 2)
	zb.size = Vector2(22, 22)
	holder.add_child(zb)
	mc.set_meta(&"badge", zb)
	mc.strength_mark = zb
	mc.big_label = zb.get("num_label")
	mc.tapped.connect(func(_v: DDCardView) -> void: tapped.emit(self))
	mc.inspected.connect(func(p: Dictionary) -> void: inspected.emit(p))
	return mc

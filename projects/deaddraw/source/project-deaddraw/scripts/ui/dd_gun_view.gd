# dd_gun_view.gd
# Purpose: the gun tile in the street's gun row. dd-ux-v4 (head's points 4, 5, 6): the hit badge
#   (dd-polish5: the yellow circle with the gun's hit number, replacing "P4") and the name on top; the rule as icon + short label;
#   then the KILL SOCKETS, one per kill the gun holds, so capacity reads at a glance: filled sockets
#   show the zombie's art and number (each is inspectable), the next socket shows what it accepts
#   ("<6", ">4", "any"), the rest are dashed; then the challenge reward. The ACTIVE gun has a bright
#   frame and an ACTIVE chip. Tap = make it active; long press / right click = its 2-line tooltip.
#   dd-ui6: [hit badge | NAME over rule icon + rule], a clear ART BAND (the gun art, no scrim; the
#   ACTIVE chip in its corner), the socket row (centred), and the Full set plate (gold cup + FULL +50,
#   challenge medal + reward; its own tooltip). One kill to go: the plate's rim glows, the cup pulses.
#   dd-capacity: the capacity mark (dd_marks.gd StatMark) in the art band's bottom-right corner.
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
## dd-ui6: the clear art band and the Full set plate (feedback lights a copy of the plate).
var art_band: Control = null
var plate: DDCardView = null
## v5: the Gun Mod chip (null when the slot has no mod).
var mod_chip: DDCardView = null


## spec: DDPayloads.gun_spec() + "socket_h_max" (the socket row's height, px) + "plate_h".
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
		if str(spec.get("mod", "")) != "":
			# dd-mods-import: the painted badge beside the text (the text alone when there is no badge)
			var mrow: HBoxContainer = DDUi.hbox(4)
			mrow.name = "ModRow"
			mrow.alignment = BoxContainer.ALIGNMENT_CENTER
			var mb: TextureRect = Art.mod_badge(str(spec["mod"]), 24.0)
			if mb != null:
				mrow.add_child(mb)
			mrow.add_child(DDUi.label(DDText.mod_chip(str(spec["mod"])), DDUi.FONT_S - 6, DDUi.accent("W"), HORIZONTAL_ALIGNMENT_CENTER))
			v.add_child(mrow)
		_apply_style()
		DDUi.ignore_mouse(self)
		return self
	# dd-ui6 (head: "I liked it when we could see our equipped gun image better"): the art gets its
	# own clear band (no scrim, nothing laid over the gun); the name and rule sit above it, the kill
	# sockets and the Full set plate below it.
	var v2: VBoxContainer = DDUi.vbox(4)
	add_child(v2)
	_box = v2
	# head: hit badge | name over [rule icon + short rule]
	var head: HBoxContainer = DDUi.hbox(6)
	head.name = "Head"
	v2.add_child(head)
	var burst: Control = Marks.HitBurst.new(int(spec.get("power", 0)))
	burst.custom_minimum_size = Vector2(36, 36)
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
	nl.name = "GunName"
	nl.resized.connect(func() -> void: fit_label(nl, DDUi.FONT_S - 3, 11))
	nv.add_child(nl)
	var rr: HBoxContainer = DDUi.hbox(4)
	rr.name = "RuleRow"
	nv.add_child(rr)
	var rtex: Texture2D = Art.texture_for(Art.rule_keys(str(spec.get("rule", ""))))
	if rtex != null:
		var ri: TextureRect = TextureRect.new()
		ri.name = "RuleIcon"
		ri.texture = rtex
		ri.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ri.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ri.custom_minimum_size = Vector2(20, 20)
		rr.add_child(ri)
	var rl: Label = _one_line(DDUi.label(str(spec.get("rule_text", "")), DDUi.FONT_S - 5, DDUi.WARN))
	rl.resized.connect(func() -> void: fit_label(rl, DDUi.FONT_S - 5, 10))
	rr.add_child(rl)
	line_labels.append(rl)
	# the art band
	var band: Control = Control.new()
	band.name = "ArtBand"
	band.clip_contents = true
	band.size_flags_vertical = Control.SIZE_EXPAND_FILL
	band.custom_minimum_size = Vector2(0, 30)
	v2.add_child(band)
	art_band = band
	var tex: Texture2D = Art.texture_for(Art.weapon_keys(str(spec.get("wid", "")), str(spec.get("name", ""))))
	if tex != null:
		has_art = true
		var tr: TextureRect = _add_art(band, tex, "cover")
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _selected:
		var chip: PanelContainer = DDUi.tag("ACTIVE", "bone", DDUi.FONT_S - 7, DDUi.SELECT)
		chip.name = "ActiveChip"
		band.add_child(chip)
		band.resized.connect(func() -> void:
			if is_instance_valid(chip):
				chip.size = chip.get_combined_minimum_size()
				chip.position = Vector2(band.size.x - chip.size.x - 3.0, 3.0))
	# dd-capacity: the capacity mark (stacked sockets + the kills it holds) in the art band's
	# bottom-right corner, opposite the hit badge, as on the street card
	var cm: Control = Marks.StatMark.new(int(spec.get("cap", 4)), "cap")
	cm.name = "CapMark"
	band.add_child(cm)
	stat_mark = cm
	band.resized.connect(func() -> void:
		if is_instance_valid(cm):
			var ch: float = clampf(band.size.y * 0.5, 24.0, 36.0)
			cm.size = Vector2(float(cm.call("width_for", ch)), ch)
			cm.position = band.size - cm.size - Vector2(3.0, 3.0))
	# v5: the slot's Gun Mod as a chip in the art band's bottom-left corner (its own tooltip)
	if str(spec.get("mod", "")) != "":
		var mc0: DDCardView = DDCardView.new()
		mc0.setup({"kind": "W", "payload": spec.get("mod_payload", {}), "row": true})
		for ch: Node in mc0.get_children():
			mc0.remove_child(ch)
			ch.queue_free()
		mc0.name = "ModChip"
		mc0.add_theme_stylebox_override("panel", DDUi.box(Color(0.08, 0.12, 0.15, 0.92), DDUi.accent("W"), 2, 8, 2))
		var ml: Label = DDUi.label(DDText.mod_chip(str(spec["mod"])), DDUi.FONT_S - 8, DDUi.accent("W"), HORIZONTAL_ALIGNMENT_CENTER)
		ml.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# dd-mods-import: the painted badge (about 22 px) in front of the name; text only without it
		var mb2: TextureRect = Art.mod_badge(str(spec["mod"]), 22.0)
		if mb2 != null:
			var mh: HBoxContainer = DDUi.hbox(3)
			mh.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mh.add_child(mb2)
			mh.add_child(ml)
			mc0.add_child(mh)
		else:
			mc0.add_child(ml)
		band.add_child(mc0)
		mc0.inspected.connect(func(p: Dictionary) -> void: inspected.emit(p))
		mc0.tapped.connect(func(_v: DDCardView) -> void: tapped.emit(self))
		band.resized.connect(func() -> void:
			if is_instance_valid(mc0):
				mc0.size = mc0.get_combined_minimum_size()
				mc0.position = Vector2(3.0, band.size.y - mc0.size.y - 3.0))
		mod_chip = mc0
	# the kill sockets (a fixed-height row, centred)
	_cap = int(spec.get("cap", 4))
	var st: Array = spec.get("stack", [])
	var pls: Array = spec.get("stack_payloads", [])
	stack_area = Control.new()
	stack_area.name = "Sockets"
	stack_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack_area.custom_minimum_size = Vector2(0, _socket_h_max)
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
	# the Full set plate (the completion bonus + the challenge reward)
	var left: int = int(spec.get("left", 0))
	plate = make_plate(str(spec.get("finish_shown", "")), str(spec.get("reward", "")), str(spec.get("challenge_state", "open")),
		"lit" if left <= 0 else ("near" if left == 1 else "open"), float(spec.get("plate_h", 34.0)))
	plate.payload = spec.get("plate_payload", {})
	plate.set_meta(&"info", {"finish": str(spec.get("finish_shown", "")), "reward": str(spec.get("reward", "")),
		"cs": str(spec.get("challenge_state", "open")), "h": float(spec.get("plate_h", 34.0))})
	v2.add_child(plate)
	DDUi.ignore_mouse(v2)
	for mc2: DDCardView in stack_cards:
		mc2.mouse_filter = Control.MOUSE_FILTER_STOP
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	if mod_chip != null:
		mod_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	plate.tapped.connect(func(_v: DDCardView) -> void: tapped.emit(self))
	plate.inspected.connect(func(p: Dictionary) -> void: inspected.emit(p))
	_apply_style()
	if left == 1:
		_pulse_plate.call_deferred()
	return self


## dd-ui6 (head: "the completion bonus needs to be more clear"): the Full set plate. The gold
## cup (badges/full_set.svg: a cup holding 4 filled kill sockets, also in the Glossary and the
## tooltips) + "FULL +50" in gold, then the challenge reward + its medal, coloured by its state
## (met / on track gold-green, open dim, missed struck through). `mode`: "open" (dark plate,
## gold rim), "near" (one kill to go: brighter rim, the cup pulses), "lit" (gold plate, ink text:
## every socket filled; the finish animation shows it).
static func make_plate(finish: String, reward: String, cs: String, mode: String, h: float = 34.0) -> DDCardView:
	var p: DDCardView = DDCardView.new()
	p.kind = "W"
	p.name = "FullPlate"
	p.set_meta(&"mode", mode)
	var lit: bool = mode == "lit"
	var gold: Color = DDUi.accent("X")
	var bg: Color = gold if lit else Color("2a2208")
	var rim: Color = gold if mode != "open" else Color(gold, 0.55)
	var stb: StyleBoxFlat = DDUi.box(bg, rim, 2 if mode == "open" else 3, 8, 0)
	stb.content_margin_left = 4
	stb.content_margin_right = 8
	if mode == "near":
		stb.shadow_color = Color(gold, 0.35)
		stb.shadow_size = 6
	p.add_theme_stylebox_override("panel", stb)
	# dd-art2-import: the painted Full set plate (open / near with its glow / lit gold)
	var pst: StyleBox = DDUi.Kit.box("dd_plate_fullset_" + mode, 0.0)
	if pst != null:
		pst.content_margin_left = maxf(6.0, h * 0.3)
		pst.content_margin_right = maxf(8.0, h * 0.38)
		pst.content_margin_top = 1.0
		pst.content_margin_bottom = 1.0
		p.add_theme_stylebox_override("panel", pst)
	p.custom_minimum_size = Vector2(0, h)
	var row: HBoxContainer = DDUi.hbox(4)
	p.add_child(row)
	var cup: TextureRect = TextureRect.new()
	cup.name = "Cup"
	cup.texture = Art.texture_for(Art.badge_keys("full_set"))
	cup.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cup.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cup.custom_minimum_size = Vector2(h - 4.0, h - 4.0)
	cup.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cup)
	var fs: int = clampi(int(h * 0.52), 13, 20)
	var fl: Label = DDUi.label("FULL +%s" % finish, fs, DDUi.BG if lit else gold)
	fl.name = "FullLabel"
	fl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not lit:
		fl.add_theme_constant_override("outline_size", 3)
		fl.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.04, 0.9))
	row.add_child(fl)
	# a narrow plate (phone gun row) drops the word: the cup already says "full set"
	p.resized.connect(func() -> void:
		if is_instance_valid(fl):
			fl.text = ("FULL +%s" if p.size.x >= 230.0 or reward == "" else "+%s") % finish)
	if reward != "":
		var good: bool = cs == "met" or cs == "on_track"
		var col: Color = {"met": DDUi.GOOD, "on_track": DDUi.GOOD, "broken": DDUi.TEXT_DIM}.get(cs, DDUi.TEXT)
		if lit:
			col = DDUi.BG
		# the reward takes the rest of the plate, right-aligned against the challenge medal
		var rl: Label = DDUi.label(reward, fs - 1, col, HORIZONTAL_ALIGNMENT_RIGHT)
		rl.name = "RewardLabel"
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rl.clip_text = true
		rl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		rl.custom_minimum_size = Vector2(10, 0)
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rl.resized.connect(func() -> void: fit_label(rl, fs - 1, 11))
		if cs == "broken":
			rl.add_child(_Strike.new())
		row.add_child(rl)
		var mt: TextureRect = TextureRect.new()
		mt.name = "Medal"
		mt.texture = Art.texture_for(Art.badge_keys("challenge" if good else "challenge_open"))
		mt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mt.custom_minimum_size = Vector2(h * 0.62, h * 0.62)
		mt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if cs == "broken":
			mt.self_modulate = Color(0.55, 0.55, 0.55, 0.7)
		row.add_child(mt)
	DDUi.ignore_mouse(p)
	return p


## A line through a missed challenge's reward.
class _Strike:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		# over the text only (the label is right-aligned and wider than its text)
		var l: Label = get_parent() as Label
		var tw: float = size.x
		if l != null:
			tw = minf(size.x, l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x)
		draw_line(Vector2(size.x - tw, size.y * 0.55), Vector2(size.x, size.y * 0.55), DDUi.TEXT_DIM, 2.0)


## One kill to go: the cup breathes (not with reduce motion).
func _pulse_plate() -> void:
	if plate == null or not is_instance_valid(plate) or not is_inside_tree():
		return
	var g: Node = get_node_or_null(^"/root/Game")
	if g != null and g.has_method(&"reduce_motion") and bool(g.call(&"reduce_motion")):
		return
	var cup: Control = plate.find_child("Cup", true, false)
	if cup == null:
		return
	cup.pivot_offset = cup.size * 0.5
	var tw: Tween = cup.create_tween().set_loops()
	tw.tween_property(cup, "scale", Vector2(1.15, 1.15), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cup, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


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
	var x: float = maxf(0.0, (stack_area.size.x - (w * n + gap * (n - 1))) * 0.5)
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
	# dd-art2-import: the painted chip rim in the tier colour
	if DDUi.Kit.rim(mc, Marks.TIER_COLORS[Marks.tier_of(z)], false, true) != null:
		mc.add_theme_stylebox_override("panel", DDUi.Kit.card_body(DDUi.card_bg("Z"), 0.0, 6.0))
	var c: DDCard = DDCard.make(DDCard.ZOMBIE, z)
	var tex: Texture2D = Art.texture_for(Art.card_keys(c))
	if tex != null:
		var tr: TextureRect = Art.cover_rect(tex)
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

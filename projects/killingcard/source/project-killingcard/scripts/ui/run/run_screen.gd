# run_screen.gd
# Purpose: Base for the run screens (Title, Loadout, RunMap, AfterAction, Reward, RunEnd; p11).
#   Owns what they share: the compact (phone) profile below ScreenProfile.COMPACT_HEIGHT logical
#   px, safe-area margins for notched phones (same rule as match_screen.gd), the PlaytestLog
#   screen announcement and small builders for theme-styled Labels / Buttons / tiles.
#   Phone rules (README "Phone readability"): text >= 16 px and tap targets >= 64 px at the
#   540 px phone base, i.e. >= 11.6 pt and >= 46 pt on an 844x390 iPhone.
#   k-art3: backdrop_key() picks a painted backdrop (bg_run; Reward: bg_supply_drop) under a scrim.
#   Subclasses override _build() (once, from _ready), _apply_compact() (when the profile
#   changes) and screen_id(). Styling comes from hud_theme.tres variations only.
# Scene contract: the root Control has a %SafeArea MarginContainer filling the screen.
# Dependencies: screen_profile.gd, run_flow.gd, pick_tile.gd, EventBus, RunState, SceneRouter.
# Author: UI/UX Agent (p11)
extends Control

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const RunFlow: GDScript = preload("res://scripts/ui/run/run_flow.gd")
const PickTile: GDScript = preload("res://scripts/ui/run/pick_tile.gd")
## kc-v2-ui: card_info.gd under its own name (reward_screen.gd declares CardInfo itself).
const CardInfoV2: GDScript = preload("res://scripts/ui/card_info.gd")

const BASE_MARGIN: Vector2 = Vector2(32, 24)
const BASE_MARGIN_COMPACT: Vector2 = Vector2(16, 10)
## Height of main buttons (px): 64 on the phone = 46 pt at 0.72 pt per px.
const BUTTON_H: float = 72.0
const BUTTON_H_COMPACT: float = 64.0
## Slate-black scrim over a painted backdrop: text sits straight on it, so keep it heavy.
const BACKDROP_SCRIM: Color = Color(0.0705882, 0.0862745, 0.101961, 0.72)

## True while the phone layout is active (logical height < ScreenProfile.COMPACT_HEIGHT).
var compact: bool = false
## Safe rect in canvas px; tests set it to simulate a notched phone. Empty = read the display.
var safe_area_override: Rect2 = Rect2():
	set(value):
		safe_area_override = value
		if is_node_ready():
			_apply_safe_area()

var _profile_set: bool = false
## kc-portrait: the screen is taller than wide (iPhone portrait). The header stacks its title over a
## row of its buttons, and the boxes in portrait_boxes turn vertical (subclasses register them).
var portrait: bool = false
var portrait_boxes: Array[BoxContainer] = []
var _header_buttons: HBoxContainer = null

@onready var _safe_area: MarginContainer = %SafeArea


func _ready() -> void:
	# kc-onboard-ui: run screens reveal systems step by step (RevealGate; back to "show all" on exit).
	RevealGate.active = true
	tree_exiting.connect(func() -> void: RevealGate.active = false)
	_add_backdrop()
	_build()
	resized.connect(_on_resized)
	get_viewport().size_changed.connect(_apply_safe_area)
	_on_resized()
	var id: StringName = screen_id()
	var bus: Node = RunFlow.event_bus()
	if id != &"" and bus != null:
		bus.screen_shown.emit(id)


## Builds the screen from the run (called once from _ready).
func _build() -> void:
	pass


## Re-applies sizes for the current profile (compact or not).
func _apply_compact() -> void:
	pass


## k-art3: painted backdrop of this screen (assets/ui/backgrounds/bg_<key>.webp); &"" = none.
## Without the image the screen keeps its plain tactical backdrop.
func backdrop_key() -> StringName:
	return &"run"


## Puts the painted backdrop and its scrim right above the scene's Background, under the UI.
func _add_backdrop() -> void:
	var key: StringName = backdrop_key()
	var tex: Texture2D = CardArt.backdrop_texture(key) if key != &"" else null
	if tex == null:
		return
	var art: TextureRect = TextureRect.new()
	art.name = "BackdropArt"
	art.texture = tex
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var scrim: ColorRect = ColorRect.new()
	scrim.name = "BackdropScrim"
	scrim.color = BACKDROP_SCRIM
	var at: int = 0
	var bg: Node = get_node_or_null(^"Background")
	if bg != null:
		at = bg.get_index() + 1
	for c: Control in [art, scrim]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(c)
		move_child(c, at)
		at += 1


## Name announced to PlaytestLog (EventBus.screen_shown).
func screen_id() -> StringName:
	return &""


func button_height() -> float:
	return BUTTON_H_COMPACT if compact else BUTTON_H


func run() -> RunProgress:
	var rs: Node = RunFlow.run_state()
	return rs.run if rs != null else null


func goto(path: String) -> void:
	RunFlow.goto(path)


func _on_resized() -> void:
	var tall: bool = size.x > 0.0 and size.y > size.x
	var want: bool = (size.y > 0.0 and size.y < ScreenProfile.COMPACT_HEIGHT) or tall
	var turned: bool = tall != portrait
	if want != compact or not _profile_set or turned:
		compact = want
		portrait = tall
		_profile_set = true
		if turned:
			_apply_portrait()
		_apply_compact()
	_apply_safe_area()


## kc-portrait: reflows the shared parts for portrait / landscape; subclasses add their own after
## calling super.
func _apply_portrait() -> void:
	for b: BoxContainer in portrait_boxes:
		if is_instance_valid(b):
			b.vertical = portrait
	var header: BoxContainer = get_node_or_null(^"%Header") as BoxContainer
	if header == null:
		return
	if portrait:
		header.vertical = true
		if _header_buttons == null:
			_header_buttons = HBoxContainer.new()
			_header_buttons.name = "HeaderButtons"
			_header_buttons.add_theme_constant_override(&"separation", 8)
		if _header_buttons.get_parent() == null:
			header.add_child(_header_buttons)
		for c: Node in header.get_children():
			if c is Button:
				c.set_meta(&"header_index", c.get_index())
				c.set_meta(&"header_flags", (c as Button).size_flags_horizontal)
				c.set_meta(&"header_min_w", (c as Button).custom_minimum_size.x)
				(c as Button).custom_minimum_size.x = 0.0
				(c as Button).clip_text = true
				header.remove_child(c)
				_header_buttons.add_child(c)
				(c as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		header.vertical = false
		if _header_buttons != null and _header_buttons.get_parent() == header:
			var moved: Array[Node] = _header_buttons.get_children()
			for c: Node in moved:
				_header_buttons.remove_child(c)
				header.add_child(c)
				header.move_child(c, mini(int(c.get_meta(&"header_index", header.get_child_count() - 1)), header.get_child_count() - 1))
				(c as Button).size_flags_horizontal = int(c.get_meta(&"header_flags", Control.SIZE_FILL))
				(c as Button).custom_minimum_size.x = float(c.get_meta(&"header_min_w", 0.0))
				(c as Button).clip_text = false
			header.remove_child(_header_buttons)


func _apply_safe_area() -> void:
	if _safe_area == null:
		return
	var margin_lt: Vector2 = BASE_MARGIN_COMPACT if compact else BASE_MARGIN
	var margin_rb: Vector2 = margin_lt
	var on_phone: bool = OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")
	if on_phone or safe_area_override.has_area():
		var window: Vector2 = Vector2(DisplayServer.window_get_size())
		var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
		if safe_area_override.has_area():
			window = get_viewport_rect().size
			safe = safe_area_override
		if window.x > 0.0 and window.y > 0.0 and safe.size.x > 0.0:
			var to_canvas: Vector2 = get_viewport_rect().size / window
			margin_lt = margin_lt.max(safe.position * to_canvas)
			margin_rb = margin_rb.max((window - safe.end) * to_canvas)
	_safe_area.add_theme_constant_override(&"margin_left", int(margin_lt.x))
	_safe_area.add_theme_constant_override(&"margin_top", int(margin_lt.y))
	_safe_area.add_theme_constant_override(&"margin_right", int(margin_rb.x))
	_safe_area.add_theme_constant_override(&"margin_bottom", int(margin_rb.y))
	_safe_area_changed()


## Called after the safe-area margins change (screens that size content to the room left).
func _safe_area_changed() -> void:
	pass


# =============================================================================
# Builders
# =============================================================================

static func make_label(text: String, variation: StringName = &"", wrap: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func make_button(text: String, variation: StringName = &"HudButton", min_w: float = 160.0) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(min_w, BUTTON_H_COMPACT)
	b.focus_mode = Control.FOCUS_ALL
	return b


static func make_tile() -> PickTile:
	return PickTile.new()


## "pick exactly 3" -> "Pick exactly 3."
static func sentence(text: String) -> String:
	if text == "":
		return ""
	var s: String = text[0].to_upper() + text.substr(1)
	return s if s.ends_with(".") else s + "."


static func clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


## kc-v2-ui: the stencil "REQ 7" chip (Requisition, run-v2.md §2.3), next to the tickets on the map,
## the shop and the reward screens. Long press / right click: what REQ is and how it is earned.
static func make_req_chip(amount: int) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.name = "ReqChip"
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("#2B2618")
	sb.border_color = Color("#C2A878")
	sb.set_border_width_all(2)
	sb.set_content_margin_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	p.add_theme_stylebox_override(&"panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.set_meta(&"inspectable", true)
	p.tooltip_text = "Requisition: earned in fights (+3, elites +5, a loss +1) and events; spent in shops."
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var tag: Label = make_label("REQ", &"HudTag")
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tag)
	var n: Label = make_label(str(amount), &"HudNumber")
	n.name = "ReqValue"
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_theme_color_override(&"font_color", Color("#E8D3A4"))
	row.add_child(n)
	return p


## kc-v2-ui: "THREAT 2" chip for the run's modifiers (hidden by the caller when none is on).
static func make_threat_chip(threat: int, mod_names: PackedStringArray) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.name = "ThreatChip"
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("#2A1416")
	sb.border_color = Color("#E5383B")
	sb.set_border_width_all(2)
	sb.set_content_margin_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	p.add_theme_stylebox_override(&"panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.set_meta(&"inspectable", true)
	p.tooltip_text = "Modifiers: %s" % ", ".join(mod_names)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var tag: Label = make_label("THREAT", &"HudTag")
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tag)
	var n: Label = make_label(str(threat), &"HudNumber")
	n.name = "ThreatValue"
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_theme_color_override(&"font_color", Color("#FF8A8C"))
	row.add_child(n)
	return p


## kc-v2-ui: long press / right click on any Control (not a Button) calls on_inspect; a tap too when
## tap_inspects (chips and plates that do nothing else).
static func wire_inspect_control(c: Control, on_inspect: Callable, tap_inspects: bool = true) -> void:
	var g: RefCounted = (load("res://scripts/ui/press_gesture.gd") as GDScript).new(c)
	g.drag_enabled = false
	g.long_pressed.connect(func(_p: Vector2) -> void: on_inspect.call())
	if tap_inspects:
		g.tapped.connect(func(_p: Vector2) -> void: on_inspect.call())
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.set_meta(&"inspectable", true)
	c.set_meta(&"gesture", g)
	c.gui_input.connect(func(e: InputEvent) -> void:
		if g.handle(e):
			c.accept_event())


## kc-v2-ui: long press (touch) or right click on a Button calls on_inspect instead of pressing it
## (same rule as reward_screen.gd _wire_inspect).
static func wire_inspect_button(b: BaseButton, on_inspect: Callable) -> void:
	var st: Dictionary = {"id": 0, "fired": false}
	b.gui_input.connect(func(e: InputEvent) -> void:
		if not e is InputEventMouseButton:
			return
		var mb: InputEventMouseButton = e
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			b.accept_event()
			on_inspect.call()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			st["id"] = int(st["id"]) + 1
			st["fired"] = false
			var my_id: int = st["id"]
			b.get_tree().create_timer(0.4).timeout.connect(func() -> void:
				if is_instance_valid(b) and int(st["id"]) == my_id and b.is_inside_tree() \
						and b.get_global_rect().has_point(b.get_global_mouse_position()):
					st["fired"] = true
					on_inspect.call())
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			st["id"] = int(st["id"]) + 1
			if bool(st["fired"]):
				st["fired"] = false
				b.accept_event())
	b.set_meta(&"inspectable", true)


# =============================================================================
# kc-v2-ui: shared by the Event / Shop / Rest screens
# =============================================================================

var _v2_inspector: Control = null
var _v2_feedback: PanelContainer = null
var _v2_feedback_label: Label = null


## The screen's card inspector (made on first use, over everything).
func inspector() -> Control:
	if _v2_inspector == null:
		_v2_inspector = (load("res://scenes/match/CardInspector.tscn") as PackedScene).instantiate()
		_v2_inspector.name = "Inspector"
		add_child(_v2_inspector)
		_v2_inspector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_v2_inspector.hide()
	return _v2_inspector


## A card by id: the run's resource, else the CardDB autoload.
func card_by_id(id: StringName) -> CardData:
	var r: RunProgress = run()
	var res: Resource = r.resource(id) if r != null else null
	if res is CardData:
		return res
	var db: Node = get_tree().root.get_node_or_null("CardDB") if is_inside_tree() else null
	return db.get_card(id) as CardData if db != null else null


## CardInspector info for a card (full card, banner, keywords).
static func card_inspect_info(card: CardData, status: String = "") -> Dictionary:
	if card == null:
		return {}
	var vd: Dictionary = CardInfoV2.view_dict(card)
	vd["banner"] = String(card.id)
	return {"view": vd, "title": card.display_name, "type": CardInfoV2.type_line(card), "banner": BannerCard.entry_for_card(card),
			"is_unit": card.is_unit(), "text": card.text, "keywords": CardInfoV2.keywords(card), "status": status}


## "What just happened" line (studio rule): a panel at the bottom of the layout that names the
## result with the numbers that changed. It flashes on every new line and plays a cue.
func show_feedback(text: String, cue: StringName = &"reward") -> void:
	if _v2_feedback == null:
		_v2_feedback = PanelContainer.new()
		_v2_feedback.name = "Feedback"
		_v2_feedback.theme_type_variation = &"ToastPanel"
		_v2_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_v2_feedback_label = make_label("", &"HudHeader", true)
		_v2_feedback_label.name = "FeedbackText"
		_v2_feedback.add_child(_v2_feedback_label)
		var layout: Node = get_node_or_null(^"%Layout")
		if layout != null:
			layout.add_child(_v2_feedback)
	_v2_feedback_label.text = text
	_v2_feedback.show()
	_v2_feedback.modulate = Color(1.6, 1.5, 1.1, 1.0)
	if is_inside_tree():
		var tw: Tween = create_tween()
		tw.tween_property(_v2_feedback, "modulate", Color.WHITE, 0.35)
	if cue != &"":
		(load("res://scripts/fx/sfx_bank.gd") as GDScript).call(&"cue", cue)


func feedback_text() -> String:
	return _v2_feedback_label.text if _v2_feedback_label != null and _v2_feedback.visible else ""


## A quick scale punch on a chip whose number changed (REQ, tickets). Colour stays.
func punch(c: Control) -> void:
	if c == null or not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	var tw: Tween = create_tween()
	tw.tween_property(c, "scale", Vector2(1.15, 1.15), 0.08)
	tw.tween_property(c, "scale", Vector2.ONE, 0.16)


## Ticket tags: filled for tickets left, hollow for spent ones (shape, not colour only).
static func make_tickets(left: int, total: int, pip: Vector2 = Vector2(18, 26)) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i: int in total:
		var p: Panel = Panel.new()
		p.theme_type_variation = &"TicketPip" if i < left else &"TicketPipSpent"
		p.custom_minimum_size = pip
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(p)
	return row

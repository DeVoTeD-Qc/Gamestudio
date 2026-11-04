# album_triptych_reveal.gd
# Purpose: The Triptych panorama reveal (cc11, spec 5 "revealed with a panoramic merged art strip
#   and a title", art-direction 6 "three cards slide together and merge into one panorama for
#   1.5 s"). Full-screen overlay: the three BannerCards slide together, the 12:1 CardArt panorama
#   (cc14, triptych = id) fades in over them, then the name and the title earned appear.
#   Settings.fast_animations runs it at 0.4x; Settings.reduced_motion drops the slide (fade only).
#   A tap during the animation skips to the end; CONTINUE, a tap on the backdrop or Esc closes.
# Dependencies: BannerCard / CardArt (cc14), TriptychData, Settings (optional), album_theme.gd.
# Author: UI/UX Agent (cc11)
extends Control

signal closed

const BANNER_SCENE: PackedScene = preload("res://scenes/card/BannerCard.tscn")
const SLIDE_S: float = 0.6
const MERGE_S: float = 0.5
const TITLE_S: float = 0.4
const SPREAD: float = 0.05  # gap between the cards before they slide together (x panorama width)

var triptych: TriptychData = null
var compact: bool = false
var pano_w: float = 960.0

var _scrim: ColorRect
var _margin: MarginContainer
var _panel: PanelContainer
var _stage: Control
var _cards: Array[BannerCard] = []
var _pano: CardArt
var _kicker: Label
var _title: Label
var _reward: Label
var _names: Label
var _continue: Button
var _tween: Tween = null
var _finished: bool = true


func _init() -> void:
	name = "TriptychReveal"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.color = Color(0.03, 0.035, 0.045, 0.88)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.gui_input.connect(_on_backdrop_input)
	add_child(_scrim)
	_margin = MarginContainer.new()
	_margin.name = "SafeMargin"
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "RevealPanel"
	_panel.theme_type_variation = &"InspectorPanel"
	center.add_child(_panel)
	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override(&"separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(col)
	_kicker = _label(col, "Kicker", "TRIPTYCH FOUND", &"Subheading")
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.gui_input.connect(_on_backdrop_input)
	col.add_child(_stage)
	for i: int in 3:
		var c: BannerCard = BANNER_SCENE.instantiate()
		c.name = "Card%d" % (i + 1)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(c)
		_cards.append(c)
	_pano = CardArt.new()
	_pano.name = "Panorama"
	_pano.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pano.clip_contents = true
	_stage.add_child(_pano)
	_title = _label(col, "RevealTitle", "", &"RevealTitle")
	_names = _label(col, "Cards", "", &"Body")
	_reward = _label(col, "RewardLine", "", &"InspectorHeading")
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	_continue = Button.new()
	_continue.name = "ContinueButton"
	_continue.theme_type_variation = &"PrimaryButton"
	_continue.text = "CONTINUE"
	_continue.custom_minimum_size = Vector2(220, 64)
	_continue.pressed.connect(close)
	buttons.add_child(_continue)


func _ready() -> void:
	_pano.material = CardArt.grain_material()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"cancel"):
		close()
		get_viewport().set_input_as_handled()


## Keeps the panel clear of notches (logical px, from the album's safe area).
func set_safe_margins(lt: Vector2, rb: Vector2) -> void:
	_margin.add_theme_constant_override(&"margin_left", int(lt.x))
	_margin.add_theme_constant_override(&"margin_top", int(lt.y))
	_margin.add_theme_constant_override(&"margin_right", int(rb.x))
	_margin.add_theme_constant_override(&"margin_bottom", int(rb.y))


## Plays the reveal for t. width: panorama width in logical px.
func play(t: TriptychData, width: float) -> void:
	triptych = t
	pano_w = roundf(width / 3.0) * 3.0
	var h: float = roundf(pano_w / 12.0)
	var cw: float = pano_w / 3.0
	var gap: float = roundf(pano_w * SPREAD)
	_stage.custom_minimum_size = Vector2(pano_w, h)
	for i: int in 3:
		var c: BannerCard = _cards[i]
		if i < t.cards.size():
			c.configure(t.cards[i])
		c.side = &""
		c.size = Vector2(cw, h)
		c.custom_minimum_size = Vector2(cw, h)
		c.modulate.a = 1.0
		c.visible = true
	_pano.triptych = t.id
	_pano.position = Vector2.ZERO
	_pano.size = Vector2(pano_w, h)
	_pano.modulate.a = 0.0
	_title.text = t.display_name.to_upper()
	var names: PackedStringArray = []
	for c: CardData in t.cards:
		names.append(c.display_name)
	_names.text = " + ".join(names)
	_reward.text = "TITLE EARNED · %s" % t.reward_title.to_upper() if t.reward_title != "" else "PANORAMA UNLOCKED"
	for l: Label in [_title, _names, _reward]:
		l.modulate.a = 0.0
	visible = true
	_finished = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var k: float = _speed()
	var reduced: bool = _reduced_motion()
	for i: int in 3:
		var joined: float = cw * i
		_cards[i].position = Vector2(joined if reduced else joined + (i - 1) * gap, 0)
	if not is_inside_tree():
		finish()
		return
	_tween = create_tween()
	if not reduced:
		_tween.set_parallel(true)
		for i: int in 3:
			_tween.tween_property(_cards[i], "position:x", cw * i, SLIDE_S * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.set_parallel(false)
	_tween.tween_property(_pano, "modulate:a", 1.0, MERGE_S * k)
	_tween.set_parallel(true)
	for c: BannerCard in _cards:
		_tween.tween_property(c, "modulate:a", 0.0, MERGE_S * k * 0.6)
	_tween.set_parallel(false)
	for l: Label in [_title, _names, _reward]:
		_tween.tween_property(l, "modulate:a", 1.0, TITLE_S * k / 3.0)
	_tween.tween_callback(func() -> void: _finished = true)
	(func() -> void:
		if is_instance_valid(_continue) and _continue.is_inside_tree():
			_continue.grab_focus()).call_deferred()


## Jumps to the end state (merged panorama, title shown).
func finish() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	for i: int in 3:
		_cards[i].position = Vector2(pano_w / 3.0 * i, 0)
		_cards[i].modulate.a = 0.0
	_pano.modulate.a = 1.0
	for l: Label in [_title, _names, _reward]:
		l.modulate.a = 1.0
	_finished = true


func close() -> void:
	if not visible:
		return
	finish()
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func is_finished() -> bool:
	return _finished


func get_panorama() -> CardArt:
	return _pano


func get_panel() -> PanelContainer:
	return _panel


func get_stage_cards() -> Array[BannerCard]:
	return _cards


func get_labels() -> Array[Label]:
	return [_kicker, _title, _names, _reward]


func get_continue_button() -> Button:
	return _continue


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if not _finished:
			finish()
		elif event.is_action(&"cancel") or (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			close()


func _label(parent: Control, n: String, text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.name = n
	l.theme_type_variation = variation
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _reduced_motion() -> bool:
	var s: Node = get_node_or_null("/root/Settings") if is_inside_tree() else null
	return s != null and bool(s.get("reduced_motion"))


func _speed() -> float:
	var s: Node = get_node_or_null("/root/Settings") if is_inside_tree() else null
	return 0.4 if s != null and bool(s.get("fast_animations")) else 1.0

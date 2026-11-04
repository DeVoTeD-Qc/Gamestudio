# coach_overlay.gd
# Pattern adapted from Killstreak scripts/ui/tutorial/coach_overlay.gd (p15): a coach card over
#   the real match UI with GOT IT / SKIP, text >= 16 px, buttons >= 64 px. CardZone needs no
#   scripted drill, so there is no spotlight or step script: the overlay watches the live match
#   and shows each first-match tip (coach_tips.gd) the first time its concept comes up.
# Scene: scenes/coach/CoachTip.tscn (root = this script; the card is built in _ready).
# Behaviour: watch(screen, controller) listens to the controller's view_changed / phase_changed
#   and the screen's option_pressed (END TURN opens Pack). When a tip is due it dims the screen,
#   holds the match loop (controller.paused) and shows the card: TIP title, text, GOT IT, and
#   SKIP ALL TIPS (marks every tip seen). Every shown tip is remembered (CoachTips), so it never
#   shows again until the player resets the tips in Settings. EventBus.coach_step(tip, skipped).
# Dependencies: coach_tips.gd, setup_ui.gd, EventBus, CardDB.
# Author: UI/UX Agent (cz13)
extends Control

const CoachTips: GDScript = preload("res://scripts/ui/coach_tips.gd")
const SetupUI: GDScript = preload("res://scripts/ui/setup_ui.gd")

signal tip_shown(tip: StringName)
signal tip_closed(tip: StringName, skipped_all: bool)

const CARD_WIDTH: float = 600.0

## False while the pause menu or the end screen is up (the shell sets it).
var enabled: bool = true
## The tip on screen (&"" = none).
var current: StringName = &""

var _screen: Control = null
var _ctrl: Node = null
var _queue: Array[StringName] = []
var _dim: ColorRect
var _card: PanelContainer
var _title: Label
var _count: Label
var _body: Label
var _ok: Button
var _skip: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim = SetupUI.dim_layer(0.55)
	add_child(_dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = PanelContainer.new()
	_card.name = "CoachCard"
	_card.theme_type_variation = &"ShellPanel"
	center.add_child(_card)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	_card.add_child(col)
	var head: HBoxContainer = HBoxContainer.new()
	col.add_child(head)
	_title = SetupUI.label("", &"ShellHeading")
	_title.name = "TipTitle"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_count = SetupUI.label("", &"ShellTag")
	_count.name = "TipCount"
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count)
	_body = SetupUI.label("", &"ShellBody", true)
	_body.name = "TipBody"
	col.add_child(_body)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(row)
	_skip = SetupUI.button("SKIP ALL TIPS", &"Button")
	_skip.name = "SkipTipsButton"
	_skip.pressed.connect(_on_skip)
	row.add_child(_skip)
	_ok = SetupUI.button("GOT IT", &"DockButton")
	_ok.name = "GotItButton"
	_ok.pressed.connect(_on_ok)
	row.add_child(_ok)
	_hide_card()
	resized.connect(_fit)


## Starts watching a live match screen and its MatchController.
func watch(screen: Control, ctrl: Node) -> void:
	_screen = screen
	_ctrl = ctrl
	ctrl.connect(&"view_changed", func(_v: Dictionary) -> void: check.call_deferred())
	ctrl.connect(&"phase_changed", func(_p: StringName) -> void: check.call_deferred())
	if screen.has_signal(&"option_pressed"):
		screen.connect(&"option_pressed", func(_k: StringName) -> void: check.call_deferred())


func is_showing() -> bool:
	return current != &""


## Looks for due tips now (also called by the shell when an overlay closes).
func check() -> void:
	if not is_inside_tree() or _ctrl == null or _ctrl.get("state") == null:
		return
	var v: Dictionary = _ctrl.call("view")
	var mode: StringName = _screen.get("mode") if _screen != null else &"act"
	for t: StringName in CoachTips.due(v, mode, _hand_has_hit(v)):
		if not _queue.has(t) and t != current:
			_queue.append(t)
	if current == &"" and enabled and not _queue.is_empty():
		_show(_queue.pop_front())


func get_ok_button() -> Button:
	return _ok


func get_skip_button() -> Button:
	return _skip


func get_body_text() -> String:
	return _body.text


func get_title_text() -> String:
	return _title.text


func get_text_labels() -> Array[Label]:
	return [_title, _count, _body]


func _show(tip: StringName) -> void:
	current = tip
	CoachTips.mark_seen(tip)  # remembered as soon as it is shown: a reload never repeats it
	var t: Dictionary = CoachTips.text(tip, _rules())
	_title.text = "TIP · " + String(t["title"])
	_count.text = "%d / %d" % [CoachTips.seen_count(), CoachTips.TIPS.size()]
	_body.text = t["text"]
	_dim.visible = true
	_card.visible = true
	_fit()
	if _ctrl != null:
		_ctrl.set("paused", true)
	_ok.grab_focus.call_deferred()
	EventBus.coach_step.emit(tip, false)
	tip_shown.emit(tip)


func _on_ok() -> void:
	var tip: StringName = current
	_hide_card()
	tip_closed.emit(tip, false)
	check.call_deferred()


func _on_skip() -> void:
	var tip: StringName = current
	CoachTips.mark_all_seen()
	_queue.clear()
	_hide_card()
	EventBus.coach_step.emit(tip, true)
	tip_closed.emit(tip, true)


func _hide_card() -> void:
	current = &""
	if _dim != null:
		_dim.visible = false
		_card.visible = false
	if _ctrl != null:
		_ctrl.set("paused", false)


func _fit() -> void:
	if _card == null:
		return
	var w: float = minf(CARD_WIDTH, size.x - 48.0)
	_card.custom_minimum_size.x = w
	_body.custom_minimum_size.x = w - 48.0


func _rules() -> Dictionary:
	var out: Dictionary = {"me_down": false}
	var s: MatchState = _ctrl.get("state")
	if s != null:
		var b: BalanceConfig = s.data.balance
		out["hold_limit"] = b.hold_limit
		out["down_value"] = b.down_value
		out["move_only"] = b.adrenaline_mode == DataEnums.AdrenalineMode.MOVE_ONLY
		out["me_down"] = bool(_ctrl.call("view")["me"].get("down", false))
	return out


func _hand_has_hit(v: Dictionary) -> bool:
	var s: MatchState = _ctrl.get("state")
	if s == null or v.is_empty():
		return false
	for c: Dictionary in v["me"].get("hand", []):
		if StringName(str(c.get("card", ""))) == s.data.hit_id:
			return true
	return false

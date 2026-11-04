# cipher_lock.gd
# Purpose: The album's Cipher Lock (cc11, spec 5, content cc03 follow-up). A brass 4-dial
#   mechanism: the riddle (the Cipher set tagline: "Cold comes first, then the old guard. Night
#   falls third; the signal fires last.") names the sets in order; each main set hides one glyph
#   in one card's art; the player sets the dials and presses TRY CODE.
#   The answer lives only in data (balance.tres cipher_code) and is checked by
#   Collection.try_cipher_code(), which also emits EventBus.cipher_attempted / cipher_solved and
#   unlocks Key Fragment (this screen never emits those). The dials start on glyph 1 on every dial:
#   never the answer, never 1-2-3-4 (initial_code()).
#   Wrong code: the dials shake (no shake with reduced motion), feedback names the attempt.
#   Right code: the glyphs light teal, the lock reports open and the reward card is shown.
#   Once solved (also after a reload) the dials rest on the code, locked.
# Dependencies: cipher_dial.gd, scenes/card/BannerCard.tscn, CardDB, Collection API, Settings.
# Author: UI/UX Agent (cc11)
extends PanelContainer

signal attempted(correct: bool)

const Dial: GDScript = preload("res://scripts/ui/cipher_dial.gd")
const BANNER_SCENE: PackedScene = preload("res://scenes/card/BannerCard.tscn")
const OPEN_COLOR: Color = Color("#3FE0C5")
const WRONG_COLOR: Color = Color("#F2705A")
const HELP_TEXT: String = "Each of the four main sets hides one glyph in the art of one of its cards. Set the dials in the riddle's order."

var collection: Node = null
var compact: bool = false

var _dials: Array = []
var _riddle: Label
var _help: Label
var _feedback: Label
var _try: Button
var _reward_holder: Control
var _reward: BannerCard = null
var _dial_row: HBoxContainer
var _shake: Tween = null


func _init() -> void:
	theme_type_variation = &"CipherPanel"
	name = "CipherLock"


## Builds the lock for a collection (the Collection autoload or a test instance).
func setup(coll: Node, is_compact: bool) -> void:
	collection = coll
	compact = is_compact
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	_dials.clear()
	_reward = null
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override(&"separation", 18 if compact else 28)
	add_child(row)
	var left := VBoxContainer.new()
	left.name = "Left"
	left.add_theme_constant_override(&"separation", 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var title := Label.new()
	title.name = "LockTitle"
	title.theme_type_variation = &"Subheading"
	title.text = "CIPHER LOCK"
	left.add_child(title)
	_riddle = _wrap_label(left, "Riddle", "“%s”" % riddle_text(), &"Handwritten")
	_help = _wrap_label(left, "Help", HELP_TEXT, &"Caption")
	_try = Button.new()
	_try.name = "TryButton"
	_try.theme_type_variation = &"PrimaryButton"
	_try.text = "TRY CODE"
	_try.custom_minimum_size = Vector2(200, 64)
	_try.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_try.pressed.connect(try_current_code)
	left.add_child(_try)
	_feedback = _wrap_label(left, "Feedback", "", &"Body")
	_reward_holder = HBoxContainer.new()
	_reward_holder.name = "Reward"
	left.add_child(_reward_holder)

	_dial_row = HBoxContainer.new()
	_dial_row.name = "Dials"
	_dial_row.add_theme_constant_override(&"separation", 10 if compact else 14)
	_dial_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_dial_row)
	var n: int = maxi(collection.cipher_length(), 1)
	var start: Array[int] = initial_code(answer(), n)
	for i: int in n:
		var d: VBoxContainer = Dial.new()
		d.setup(i, glyph_count(), start[i])
		d.set_face_size(84.0 if compact else 104.0)
		d.value_changed.connect(_on_dial_changed)
		_dial_row.add_child(d)
		_dials.append(d)
	sync()


## The riddle: the Cipher set's tagline (content cc03 follow-up 1).
static func riddle_text() -> String:
	var db: Node = _db()
	if db != null:
		for s: SetData in db.all_sets():
			if s.kind == DataEnums.SetKind.CIPHER:
				return s.tagline
	return ""


static func answer() -> PackedInt32Array:
	var db: Node = _db()
	return db.get_balance().cipher_code if db != null else PackedInt32Array()


## Number of glyphs a dial cycles through (the highest glyph any card carries; 4 in the demo).
static func glyph_count() -> int:
	var db: Node = _db()
	var most: int = 0
	if db != null:
		for c: CardData in db.all_cards():
			most = maxi(most, c.cipher_glyph)
	return maxi(most, 4)


## Where the dials start: glyph 1 on every dial unless that is the answer; never the answer and
## never the ascending 1-2-3-... order (the old, guessable code).
static func initial_code(ans: PackedInt32Array, n: int) -> Array[int]:
	var candidates: Array = []
	for g: int in range(1, 5):
		var same: Array[int] = []
		for i: int in n:
			same.append(g)
		candidates.append(same)
	for cand: Array in candidates:
		var typed: Array[int] = []
		typed.assign(cand)
		if not _matches(typed, ans) and not _is_ascending(typed):
			return typed
	var fallback: Array[int] = []
	for i: int in n:
		fallback.append(n - i)
	return fallback


## The cards an opened lock unlocks (goals of kind CIPHER_LOCK): Key Fragment in the demo.
static func reward_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	var db: Node = _db()
	if db == null:
		return out
	for g: UnlockGoal in db.all_unlock_goals():
		if g.kind == DataEnums.UnlockKind.CIPHER_LOCK:
			out.append_array(db.cards_unlocked_by(g.id))
	return out


func current_code() -> Array[int]:
	var out: Array[int] = []
	for d: VBoxContainer in _dials:
		out.append(d.value)
	return out


## Sets the dials (tests, keyboard helpers). Values are glyph numbers.
func set_code(code: Array) -> void:
	for i: int in mini(code.size(), _dials.size()):
		_dials[i].set_value(int(code[i]), false)
	_feedback.text = "" if not collection.is_cipher_solved() else _feedback.text


## Tries the dials' code through Collection (which emits the EventBus signals).
func try_current_code() -> bool:
	if collection == null or collection.is_cipher_solved():
		return true
	var ok: bool = collection.try_cipher_code(current_code())
	if ok:
		_show_open(true)
	else:
		_feedback.text = "The lock holds. Check the riddle and the glyph in each card's art. (Attempt %d)" % collection.cipher_attempts()
		_feedback.add_theme_color_override(&"font_color", WRONG_COLOR.lightened(0.2))
		_shake_dials()
	attempted.emit(ok)
	return ok


## Matches the view to the collection (solved after a reload, attempts so far).
func sync() -> void:
	if collection == null:
		return
	if collection.is_cipher_solved():
		_show_open(false)
	else:
		for d: VBoxContainer in _dials:
			d.set_locked(false)
			d.flash(Color.WHITE)
		_try.visible = true


func is_solved_view() -> bool:
	return not _try.visible


func get_dials() -> Array:
	return _dials


func get_try_button() -> Button:
	return _try


func get_feedback() -> Label:
	return _feedback


func get_reward_card() -> BannerCard:
	return _reward


func get_labels() -> Array[Label]:
	return [_riddle, _help, _feedback]


func _show_open(fresh: bool) -> void:
	var ans: PackedInt32Array = answer()
	for i: int in _dials.size():
		if i < ans.size() and not fresh:
			_dials[i].set_value(ans[i], false)
		_dials[i].set_locked(true)
		_dials[i].flash(OPEN_COLOR)
	_try.visible = false
	var rewards: Array[CardData] = reward_cards()
	var names: PackedStringArray = []
	for c: CardData in rewards:
		names.append(c.display_name)
	var reward_name: String = ", ".join(names) if not names.is_empty() else "the reward"
	_feedback.remove_theme_color_override(&"font_color")
	if fresh:
		_feedback.text = "Click. The lock opens: %s is yours." % reward_name
	else:
		_feedback.text = "Opened in %d %s. %s is yours." % [collection.cipher_attempts(),
				"try" if collection.cipher_attempts() == 1 else "tries", reward_name]
	if _reward == null and not rewards.is_empty():
		_reward = BANNER_SCENE.instantiate()
		_reward.name = "RewardCard"
		_reward.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var w: float = 360.0 if compact else 448.0
		_reward.custom_minimum_size = Vector2(w, w / 4.0)
		_reward_holder.add_child(_reward)
		_reward.configure(rewards[0])
		_reward.side = &""
		_reward.locked = not collection.owns(rewards[0].id)
		if fresh and is_inside_tree() and not _reduced_motion():
			_reward.modulate.a = 0.0
			var tw: Tween = create_tween()
			tw.tween_property(_reward, "modulate:a", 1.0, 0.45 * _speed())
			_reward.highlighted = true
			tw.tween_callback(func() -> void:
				if is_instance_valid(_reward):
					_reward.highlighted = false).set_delay(1.2 * _speed())


func _on_dial_changed(_index: int, _value: int) -> void:
	if not collection.is_cipher_solved():
		_feedback.text = ""
		for d: VBoxContainer in _dials:
			d.flash(Color.WHITE)


func _shake_dials() -> void:
	for d: VBoxContainer in _dials:
		d.flash(WRONG_COLOR)
	if not is_inside_tree() or _reduced_motion():
		return
	if _shake != null and _shake.is_valid():
		_shake.kill()
	# Shake the row's contents through a per-dial offset (the row itself is laid out by its parent).
	_shake = create_tween()
	var amp: float = 10.0
	var prev: float = 0.0
	for step: float in [amp, -amp, amp * 0.6, -amp * 0.6, 0.0]:
		_shake.tween_method(_set_shake, prev, step, 0.05 * _speed())
		prev = step


func _set_shake(x: float) -> void:
	for d: VBoxContainer in _dials:
		d.get_face().position.x = x


func _wrap_label(parent: Control, n: String, text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.name = n
	l.theme_type_variation = variation
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _reduced_motion() -> bool:
	var s: Node = Engine.get_main_loop().root.get_node_or_null("Settings") if Engine.get_main_loop() is SceneTree else null
	return s != null and bool(s.get("reduced_motion"))


func _speed() -> float:
	var s: Node = Engine.get_main_loop().root.get_node_or_null("Settings") if Engine.get_main_loop() is SceneTree else null
	return 0.4 if s != null and bool(s.get("fast_animations")) else 1.0


static func _db() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("CardDB") if loop is SceneTree else null


static func _matches(code: Array[int], ans: PackedInt32Array) -> bool:
	if code.size() != ans.size():
		return false
	for i: int in code.size():
		if code[i] != ans[i]:
			return false
	return true


static func _is_ascending(code: Array[int]) -> bool:
	for i: int in code.size():
		if code[i] != i + 1:
			return false
	return true

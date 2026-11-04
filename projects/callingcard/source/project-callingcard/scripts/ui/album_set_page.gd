# album_set_page.gd
# Purpose: One album page per set (cc11, spec section 5): set glyph, name, "3 / 4 cards", the
#   completion reward (title + animated set frame) or "Complete" once earned, the set tagline in
#   the handwritten face (on the Cipher page it is the Cipher Lock riddle), then the cards hung
#   salon-style in album order (album_card_hanger.gd: owned cards and goal-bearing silhouettes).
#   The Cipher page links to the Cipher Lock; the Showcase page states the anti-pay-to-win rule.
# Dependencies: album_card_hanger.gd, CardDB (sets / cards), the Collection API (cc09), ArtIcons.
# Author: UI/UX Agent (cc11)
extends VBoxContainer

signal inspect_requested(card_id: StringName)
signal cipher_lock_requested

const Hanger: GDScript = preload("res://scripts/ui/album_card_hanger.gd")

var set_data: SetData = null
var _hangers: Dictionary = {}  # card id -> hanger
var _progress_label: Label = null
var _reward_label: Label = null


## Builds the page. card_w: card width in logical px; cols: hanger columns.
func build(s: SetData, cards: Array, collection: Node, card_w: float, cols: int) -> void:
	set_data = s
	name = "SetPage_%s" % s.id
	add_theme_constant_override(&"separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override(&"separation", 14)
	add_child(header)
	var icon := TextureRect.new()
	icon.name = "SetIcon"
	icon.texture = ArtIcons.set_icon(s.id, 48.0 * 3.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(48, 48)
	icon.modulate = ArtKit.set_palette(s.id)["edge"]
	header.add_child(icon)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override(&"separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	var title := Label.new()
	title.name = "SetName"
	title.theme_type_variation = &"Subheading"
	title.text = s.display_name.to_upper()
	titles.add_child(title)
	var p: Dictionary = collection.set_progress(s.id)
	_progress_label = Label.new()
	_progress_label.name = "SetProgress"
	_progress_label.theme_type_variation = &"Body"
	_progress_label.text = progress_line(p)
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(_progress_label)
	_reward_label = Label.new()
	_reward_label.name = "SetReward"
	_reward_label.theme_type_variation = &"Caption"
	_reward_label.text = reward_line(s, p)
	_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward_label.visible = _reward_label.text != ""
	titles.add_child(_reward_label)
	if s.kind == DataEnums.SetKind.CIPHER:
		var lock := Button.new()
		lock.name = "CipherLockButton"
		lock.theme_type_variation = &"ActionButton"
		lock.text = "CIPHER LOCK"
		lock.custom_minimum_size = Vector2(170, 64)
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lock.pressed.connect(func() -> void: cipher_lock_requested.emit())
		header.add_child(lock)

	if s.tagline.strip_edges() != "":
		var tag := Label.new()
		tag.name = "Tagline"
		tag.theme_type_variation = &"Handwritten"
		tag.text = "“%s”" % s.tagline if s.kind == DataEnums.SetKind.CIPHER else s.tagline
		tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(tag)

	var grid := GridContainer.new()
	grid.name = "Cards"
	grid.columns = maxi(cols, 1)
	grid.add_theme_constant_override(&"h_separation", 24)
	grid.add_theme_constant_override(&"v_separation", 20)
	add_child(grid)
	for c: CardData in cards:
		var h: VBoxContainer = Hanger.new()
		h.setup(c, collection, card_w)
		h.inspect_requested.connect(func(id: StringName) -> void: inspect_requested.emit(id))
		h.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		grid.add_child(h)
		_hangers[c.id] = h


static func progress_line(p: Dictionary) -> String:
	if p.is_empty():
		return ""
	var line: String = "%d / %d cards" % [int(p["owned"]), int(p["total"])]
	if bool(p.get("complete", false)):
		line += " · Complete"
	return line


## What completing the set grants (cosmetic only), or what it granted.
static func reward_line(s: SetData, p: Dictionary) -> String:
	if s.kind == DataEnums.SetKind.SHOWCASE or s.completion_title.strip_edges() == "":
		return ""
	if bool(p.get("complete", false)):
		return "Earned: title “%s” and the animated set frame." % s.completion_title
	return "Complete the set: title “%s” and an animated set frame." % s.completion_title


func get_hanger(card_id: StringName) -> VBoxContainer:
	return _hangers.get(card_id, null)


func get_hangers() -> Array:
	return _hangers.values()


func get_progress_label() -> Label:
	return _progress_label


## Pulses every card's edge light (set completed while the page is open).
func celebrate_all() -> void:
	for h: VBoxContainer in _hangers.values():
		h.celebrate()

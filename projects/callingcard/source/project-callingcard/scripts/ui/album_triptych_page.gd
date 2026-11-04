# album_triptych_page.gd
# Purpose: The Triptychs page (cc11, spec 5 / 5.1, art-direction section 5). Hidden 3-card
#   combinations: an unrevealed one shows three joined empty frames with "???" and its cryptic
#   hint in the handwritten face; a revealed one shows the 12:1 merged panorama (cc14 CardArt with
#   triptych = id), its name, its three cards and the title it gave. Tapping a revealed Triptych
#   replays the panorama reveal (signal replay_requested); unrevealed slots are not buttons.
# Dependencies: CardArt (cc14), CardDB triptychs, the Collection API (has_triptych).
# Author: UI/UX Agent (cc11)
extends VBoxContainer

signal replay_requested(triptych_id: StringName)

const TapHoldButton: GDScript = preload("res://scripts/ui/tap_hold_button.gd")
const HIDDEN_TEXT: String = "???"

var _slots: Dictionary = {}  # triptych id -> slot root (VBoxContainer)


## pano_w: width of the 12:1 strip in logical px.
func build(triptychs: Array, collection: Node, pano_w: float) -> void:
	name = "TriptychPage"
	add_theme_constant_override(&"separation", 14)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var found: int = 0
	for t: TriptychData in triptychs:
		if collection.has_triptych(t.id):
			found += 1
	var title := Label.new()
	title.name = "TriptychTitle"
	title.theme_type_variation = &"Subheading"
	title.text = "TRIPTYCHS"
	add_child(title)
	var count := Label.new()
	count.name = "TriptychCount"
	count.theme_type_variation = &"Body"
	count.text = "%d / %d found. Hidden three-card combinations: line the right three of your cards up in one row of the wall." % [found, triptychs.size()]
	count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(count)
	var pano_h: float = roundf(pano_w / 12.0)
	for t: TriptychData in triptychs:
		var slot := VBoxContainer.new()
		slot.name = "Triptych_%s" % t.id
		slot.add_theme_constant_override(&"separation", 4)
		add_child(slot)
		_slots[t.id] = slot
		if collection.has_triptych(t.id):
			var btn: Button = TapHoldButton.new()
			btn.name = "PanoramaButton"
			btn.theme_type_variation = &"AlbumHanger"
			btn.custom_minimum_size = Vector2(pano_w, maxf(pano_h, 64.0))
			btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			btn.mouse_filter = Control.MOUSE_FILTER_PASS
			btn.add_to_group(&"tap_target")
			var id: StringName = t.id
			btn.tapped.connect(func() -> void: replay_requested.emit(id))
			btn.inspect_requested.connect(func() -> void: replay_requested.emit(id))
			slot.add_child(btn)
			var frame := PanelContainer.new()
			frame.theme_type_variation = &"TriptychFrame"
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			btn.add_child(frame)
			var art := CardArt.new()
			art.name = "Panorama"
			art.triptych = t.id
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art.material = CardArt.grain_material()
			art.clip_contents = true
			frame.add_child(art)
			_label(slot, "Name", t.display_name.to_upper(), &"Subheading")
			_label(slot, "Cards", _card_names(t), &"Body")
			_label(slot, "Reward", "Title earned: “%s” · tap to replay the reveal" % t.reward_title, &"Caption")
		else:
			var row := HBoxContainer.new()
			row.name = "HiddenFrames"
			row.add_theme_constant_override(&"separation", 0)
			slot.add_child(row)
			for i: int in TriptychData.CARD_COUNT:
				var frame := PanelContainer.new()
				frame.name = "Frame%d" % (i + 1)
				frame.theme_type_variation = &"TriptychFrame"
				frame.custom_minimum_size = Vector2(roundf(pano_w / 3.0), maxf(pano_h, 64.0))
				row.add_child(frame)
				var q := Label.new()
				q.theme_type_variation = &"Heading"
				q.text = HIDDEN_TEXT
				q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				q.modulate = Color(1, 1, 1, 0.55)
				frame.add_child(q)
			_label(slot, "Hint", "“%s”" % t.hint, &"Handwritten")
			_label(slot, "Reward", "Reward: a title and this panorama.", &"Caption")


static func _card_names(t: TriptychData) -> String:
	var names: PackedStringArray = []
	for c: CardData in t.cards:
		names.append(c.display_name)
	return " + ".join(names)


func get_slot(triptych_id: StringName) -> VBoxContainer:
	return _slots.get(triptych_id, null)


func is_revealed_slot(triptych_id: StringName) -> bool:
	var s: VBoxContainer = get_slot(triptych_id)
	return s != null and s.get_node_or_null("PanoramaButton") != null


func _label(parent: Control, n: String, text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.name = n
	l.theme_type_variation = variation
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

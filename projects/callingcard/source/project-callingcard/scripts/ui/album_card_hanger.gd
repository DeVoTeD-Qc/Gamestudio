# album_card_hanger.gd
# Purpose: One card "hung" on an album page (cc11, spec section 5, art-direction section 5).
#   Owned: the BannerCard (set-complete edge light when its set is complete; Showcase cards draw
#   their premium chrome / gold frame), its name, and "Clearance n · Name · Trait".
#   Not owned: the embossed silhouette (BannerCard.locked keeps values, Clearance pips and the
#   trait icon visible) plus the unlock goal and its progress ("Unlock: Win 3 duels in a row",
#   bar + "1 / 3"). Nothing is hover-only: tap, long-press, right-click or the inspect key on the
#   card opens the CardInspector with the same facts (signal inspect_requested).
# Usage: var h = AlbumCardHanger.new(); h.setup(card_data, Collection, 480.0); page.add_child(h)
# Dependencies: scenes/card/BannerCard.tscn (cc14), scripts/ui/tap_hold_button.gd (cc07), ArtIcons,
#   CardData / UnlockGoal (cc02), the Collection API (cc09).
# Author: UI/UX Agent (cc11)
extends VBoxContainer

signal inspect_requested(card_id: StringName)

const TapHoldButton: GDScript = preload("res://scripts/ui/tap_hold_button.gd")
const BANNER_SCENE: PackedScene = preload("res://scenes/card/BannerCard.tscn")
const CLEARANCE_NAMES: Array[String] = ["", "Issue", "Merit", "Distinction", "Legend"]

var card: CardData = null
var owned: bool = false
var set_complete: bool = false
## Text lines shown under the card (tests read them).
var info_text: String = ""
var goal_text: String = ""
var progress: Dictionary = {}

var _button: Button = null
var _view: BannerCard = null
var _name: Label = null
var _info: Label = null
var _goal: Label = null
var _bar: ProgressBar = null
var _count: Label = null


## Builds the hanger for one card at card_w logical px wide (4:1 card).
func setup(c: CardData, collection: Node, card_w: float) -> void:
	card = c
	owned = collection.owns(c.id)
	set_complete = owned and c.card_set != null and collection.is_set_complete(c.card_set.id)
	name = "Hanger_%s" % c.id
	add_theme_constant_override(&"separation", 4)
	custom_minimum_size.x = card_w
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_button = TapHoldButton.new()
	_button.name = "CardButton"
	_button.theme_type_variation = &"AlbumHanger"
	_button.custom_minimum_size = Vector2(card_w, roundf(card_w / 4.0))
	_button.mouse_filter = Control.MOUSE_FILTER_PASS  # lets the page scroll on a touch drag
	_button.add_to_group(&"tap_target")
	_button.tapped.connect(_request)
	_button.inspect_requested.connect(_request)
	add_child(_button)
	_view = BANNER_SCENE.instantiate()
	_view.name = "Card"
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_button.add_child(_view)
	_view.configure(c)
	_view.side = &""
	_view.locked = not owned
	_view.set_complete = set_complete

	var row := HBoxContainer.new()
	row.name = "NameRow"
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var trait_id: StringName = trait_key(c)
	var icon_tex: Texture2D = ArtIcons.trait_icon(trait_id, 24.0 * 3.0) if trait_id != &"none" else ArtIcons.set_icon(&"showcase", 72.0)
	if icon_tex != null:
		var icon := TextureRect.new()
		icon.name = "TraitIcon"
		icon.texture = icon_tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(24, 24)
		icon.modulate = ArtKit.TEXT if owned else ArtKit.TEXT_DIM
		row.add_child(icon)
	_name = Label.new()
	_name.name = "NameLabel"
	_name.theme_type_variation = &"Body"
	_name.text = c.display_name if owned else "%s  (not owned)" % c.display_name
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_name)

	info_text = info_line(c, set_complete)
	_info = _caption("InfoLabel", info_text, &"Caption")

	if not owned:
		var goal: UnlockGoal = collection.goal_for_card(c.id)
		if goal != null:
			goal_text = "Unlock: %s" % goal.description
			progress = collection.goal_progress(goal.id)
		else:
			goal_text = "Unlock: %s" % c.how_earned
		_goal = _caption("GoalLabel", goal_text, &"GoalLabel")
		if not progress.is_empty():
			var prow := HBoxContainer.new()
			prow.name = "ProgressRow"
			prow.add_theme_constant_override(&"separation", 10)
			prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(prow)
			_bar = ProgressBar.new()
			_bar.name = "GoalBar"
			_bar.show_percentage = false
			_bar.min_value = 0
			_bar.max_value = maxi(int(progress["target"]), 1)
			_bar.value = int(progress["current"])
			_bar.custom_minimum_size = Vector2(0, 14)
			_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			prow.add_child(_bar)
			_count = Label.new()
			_count.name = "ProgressLabel"
			_count.theme_type_variation = &"Body"
			_count.text = progress_text(progress)
			prow.add_child(_count)


## "Clearance 2 · Merit · Veteran"; Showcase: "Showcase frame · Clearance 1 · No trait".
static func info_line(c: CardData, complete: bool = false) -> String:
	var cl: int = clampi(c.clearance, 1, 4)
	if c.is_store or (c.card_set != null and c.card_set.id == &"showcase"):
		return "Showcase frame · Clearance %d · No trait" % cl
	var tk: StringName = trait_key(c)
	var t: String = "No trait" if tk == &"none" else String(tk).capitalize()
	var line: String = "Clearance %d · %s · %s" % [cl, CLEARANCE_NAMES[cl], t]
	if complete:
		line += " · Set frame"
	return line


static func progress_text(p: Dictionary) -> String:
	return "%d / %d" % [int(p.get("current", 0)), int(p.get("target", 1))]


static func trait_key(c: CardData) -> StringName:
	return StringName(DataEnums.key_of(DataEnums.CardTrait, c.card_trait()).to_lower())


func get_button() -> Button:
	return _button


func get_card_view() -> BannerCard:
	return _view


func get_labels() -> Array[Label]:
	var out: Array[Label] = [_name, _info]
	for l: Label in [_goal, _count]:
		if l != null:
			out.append(l)
	return out


func get_progress_bar() -> ProgressBar:
	return _bar


## Short celebration on this card (new card, set complete): edge-light pulse + amber outline.
func celebrate(seconds: float = 1.6) -> void:
	if _view == null:
		return
	_view.highlighted = true
	_view.pulse()
	if is_inside_tree():
		get_tree().create_timer(seconds).timeout.connect(func() -> void:
			if is_instance_valid(_view):
				_view.highlighted = false)


func _caption(n: String, text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.name = n
	l.theme_type_variation = variation
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _request() -> void:
	inspect_requested.emit(card.id)

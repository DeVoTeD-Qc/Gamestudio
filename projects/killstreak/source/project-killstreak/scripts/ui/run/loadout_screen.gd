# loadout_screen.gd
# Purpose: Loadout pick (p11, scenes/run/Loadout.tscn). Shows the starter kit (Primary,
#   Secondary, Lethal, Tactical, the 20-card deck) and the killstreak pool as tiles. Tap a tile to
#   pick it, tap a picked one to drop it; exactly RunConfig.killstreak_slots must be picked before
#   BEGIN RUN works (the starter three are pre-picked). BEGIN RUN calls RunState.set_killstreaks()
#   and begin_run(), then opens the run map.
# Dependencies: run_screen.gd, pick_tile.gd, RunState, RunFlow.
# Author: UI/UX Agent (p11)
extends "res://scripts/ui/run/run_screen.gd"

## Killstreak ids picked so far, in pick order.
var picked: Array[StringName] = []

var _tiles: Dictionary = {}  # id -> PickTile
var _begin_button: Button = null
var _back_button: Button = null
var _kit_panel: PanelContainer = null
var _grid: GridContainer = null
var _error: Label = null

@onready var _header: HBoxContainer = %Header
@onready var _subtitle: Label = %SubtitleLabel
@onready var _body: MarginContainer = %Body


func screen_id() -> StringName:
	return &"loadout"


func _build() -> void:
	var r: RunProgress = run()
	_back_button = make_button("BACK", &"HudButton", 120)
	_back_button.pressed.connect(_on_back)
	_header.add_child(_back_button)
	_header.move_child(_back_button, 0)
	_begin_button = make_button("BEGIN RUN", &"ReadyButton", 220)
	_begin_button.pressed.connect(begin)
	_header.add_child(_begin_button)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	_body.add_child(row)
	# Starter kit (scrolls if a long rules text doesn't fit a short screen).
	_kit_panel = PanelContainer.new()
	_kit_panel.theme_type_variation = &"HudPanelDark"
	_kit_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kit_panel.size_flags_stretch_ratio = 0.8
	row.add_child(_kit_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_kit_panel.add_child(scroll)
	var kit: VBoxContainer = VBoxContainer.new()
	kit.name = "Kit"
	kit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kit.add_theme_constant_override(&"separation", 6)
	scroll.add_child(kit)
	kit.add_child(make_label("STARTER KIT", &"HudAccent"))
	if r != null:
		for slot: String in ["primary", "secondary", "lethal", "tactical"]:
			var item: LoadoutItem = r.resource(r.get(slot)) as LoadoutItem
			if item == null:
				continue
			var line: String = "%s  ·  %s" % [String(RunFlow.SLOT_WORDS.get(item.slot, slot)).to_upper(), item.display_name]
			kit.add_child(make_label(line, &"UnitName", true))
			# Primary: class and Operator stats. Others: their rules text (it already names cost
			# and cooldown), the stat line only when there is no text.
			var detail: String = item.text
			if item.slot == DataEnums.LoadoutSlot.PRIMARY or detail == "":
				detail = RunFlow.item_effect_line(item)
			if detail != "":
				kit.add_child(make_label(detail, &"HudSubtle", true))
		kit.add_child(make_label("DECK  ·  %d cards" % r.deck.size(), &"UnitName"))
		kit.add_child(make_label(RunFlow.deck_summary(r), &"HudSubtle", true))
	# Killstreak pool.
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 8)
	row.add_child(right)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override(&"h_separation", 10)
	_grid.add_theme_constant_override(&"v_separation", 10)
	right.add_child(_grid)
	_error = make_label("", &"HudAccent", true)
	_error.hide()
	right.add_child(_error)
	if r != null:
		picked = r.killstreaks.duplicate()
		for item: LoadoutItem in r.config.killstreak_pool:
			if item == null:
				continue
			var tile: PickTile = make_tile()
			tile.name = "Killstreak_%s" % item.id
			tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
			tile.add_line(item.display_name.to_upper(), &"TileName")
			tile.add_line("STREAK %d" % item.streak_threshold, &"StreakLabel", false)
			tile.add_line(item.text)
			# k-art4: the killstreak's card art as a band in the tile's free space (it shrinks
			# away on short screens and never grows the tile); no art: the old spacer.
			if CardArt.has_card(item.id):
				var band := TextureRect.new()
				band.name = "Art"
				band.texture = CardArt.card_texture(item.id, 2.0)
				band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				band.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				band.size_flags_vertical = Control.SIZE_EXPAND_FILL
				band.mouse_filter = Control.MOUSE_FILTER_IGNORE
				band.clip_contents = true
				tile.content.add_child(band)
			else:
				tile.add_spacer()
			tile.add_status("TAP TO PICK")
			tile.pressed.connect(toggle.bind(item.id))
			_grid.add_child(tile)
			_tiles[item.id] = tile
	_refresh()


func _apply_compact() -> void:
	for b: Button in [_begin_button, _back_button]:
		if b != null:
			b.custom_minimum_size.y = button_height()


## Picks or drops a killstreak (one tap). Returns false when it can't be picked (all slots full).
func toggle(id: StringName) -> bool:
	var slots: int = _slots()
	_error.hide()
	if id in picked:
		picked.erase(id)
	elif picked.size() < slots:
		picked.append(id)
	else:
		_error.text = "All %d slots are full. Tap a picked killstreak to drop it first." % slots
		_error.show()
		_refresh()
		return false
	_refresh()
	return true


## BEGIN RUN: stores the picks and opens the run map. Returns "" or the reason it can't.
func begin() -> String:
	var rs: Node = RunFlow.run_state()
	var err: String = rs.set_killstreaks(picked)
	if err == "":
		err = rs.begin_run()
	if err != "":
		_error.text = sentence(err)
		_error.show()
		return err
	goto(RunFlow.SCENE_RUN_MAP)
	return ""


func _on_back() -> void:
	goto(RunFlow.SCENE_TITLE)


func _slots() -> int:
	var r: RunProgress = run()
	return r.config.killstreak_slots if r != null else 3


func _refresh() -> void:
	var slots: int = _slots()
	for id: StringName in _tiles:
		var tile: PickTile = _tiles[id]
		tile.set_selected(id in picked, "PICKED  ·  TAP TO DROP", "TAP TO PICK")
	_subtitle.text = "Pick %d killstreaks  ·  %d of %d picked" % [slots, picked.size(), slots]
	_begin_button.disabled = picked.size() != slots

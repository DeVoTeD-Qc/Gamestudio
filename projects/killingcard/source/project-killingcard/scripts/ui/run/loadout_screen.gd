# loadout_screen.gd
# Purpose: Loadout pick (p11, scenes/run/Loadout.tscn). Shows the starter kit (the Operator's
#   Primary, the 10-card deck) and the killstreak pool as tiles (kc-loadout-cut: no Secondary /
#   Lethal / Tactical rows any more). Tap a tile to pick it, tap a picked one to drop it; exactly RunConfig.killstreak_slots must be picked before
#   BEGIN RUN works (the starter three are pre-picked). BEGIN RUN calls RunState.set_killstreaks()
#   and begin_run(), then opens the run map.
#   kc-ui4: the screen opens on the STARTING SQUAD panel (starter_panel.gd: pick the Operator, see
#   the starter deck grouped with counts); NEXT: KILLSTREAKS closes it, OPERATOR & DECK on the kit
#   panel reopens it.
# Dependencies: run_screen.gd, pick_tile.gd, RunState, RunFlow.
# Author: UI/UX Agent (p11)
extends "res://scripts/ui/run/run_screen.gd"

const RunV2Views: GDScript = preload("res://scripts/ui/run/run_v2_views.gd")
const RunGlyphs: GDScript = preload("res://scripts/ui/run/run_glyphs.gd")

## Killstreak ids picked so far, in pick order.
var picked: Array[StringName] = []

var _tiles: Dictionary = {}  # id -> PickTile
var _begin_button: Button = null
var _back_button: Button = null
var _kit_panel: PanelContainer = null
var _grid: GridContainer = null
var _error: Label = null
var _starter: Control = null
var _squad_button: Button = null
var _kit: VBoxContainer = null

@onready var _header: BoxContainer = %Header
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
	var row: BoxContainer = BoxContainer.new()  # kc-portrait: turns vertical in portrait
	row.add_theme_constant_override(&"separation", 16)
	_body.add_child(row)
	portrait_boxes.append(row)  # kc-portrait: the starter kit over the killstreak pool
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
	_kit = kit
	_squad_button = make_button("OPERATOR & DECK", &"HudButton", 200)
	_squad_button.name = "SquadButton"
	_squad_button.tooltip_text = "Pick your starting Operator and see the starter deck"
	_squad_button.pressed.connect(open_starter)
	_fill_kit()
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
			if ArtUnderlay.enabled and CardArt.has_card(item.id):
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
	if r != null:
		open_starter.call_deferred()


## The kit list (rebuilt when the Operator changes).
func _fill_kit() -> void:
	var r: RunProgress = run()
	for c: Node in _kit.get_children():
		if c != _squad_button:
			_kit.remove_child(c)
			c.queue_free()
	if _squad_button.get_parent() == null:
		_kit.add_child(_squad_button)
	var kit: VBoxContainer = _kit
	kit.add_child(make_label("STARTER KIT", &"HudAccent"))
	kit.move_child(_squad_button, kit.get_child_count() - 1)
	if r != null:
		var item: LoadoutItem = r.resource(r.primary) as LoadoutItem
		if item != null:
			var line: String = "%s  ·  %s" % [String(RunFlow.SLOT_WORDS.get(item.slot, "primary")).to_upper(), item.display_name]
			kit.add_child(make_label(line, &"UnitName", true))
			# The Primary's class and Operator stats.
			var detail: String = RunFlow.item_effect_line(item)
			if detail != "":
				kit.add_child(make_label(detail, &"HudSubtle", true))
			# kc-v2-ui: the Operator's passive and once-per-match ability.
			var k: Dictionary = RunV2Views.operator_kit(item.id, r)
			if not k.is_empty():
				var pl: Label = make_label("P · %s: %s" % [k.get("passive_name", ""), k.get("passive_text", "")], &"", true)
				pl.name = "KitPassive"
				kit.add_child(pl)
				var al: Label = make_label("1x · %s: %s" % [k.get("ability_name", ""), k.get("ability_text", "")], &"HudAccent", true)
				al.name = "KitAbility"
				kit.add_child(al)
		kit.add_child(make_label("DECK  ·  %d cards" % r.deck.size(), &"UnitName"))
		kit.add_child(make_label(RunFlow.deck_summary(r), &"HudSubtle", true))
	_kit.move_child(_squad_button, _kit.get_child_count() - 1)
	_fill_v2(kit, r)


# =============================================================================
# kc-v2-ui: the run's boss (shown before you pick your Operator) and the modifiers with Threat
# =============================================================================

var _mod_tiles: Dictionary = {}
var _threat_label: Label = null


func _fill_v2(kit: VBoxContainer, r: RunProgress) -> void:
	_mod_tiles.clear()
	var bv: Variant = r.call(&"boss_view") if r != null and r.has_method(&"boss_view") else null
	if bv is Dictionary and not (bv as Dictionary).is_empty():
		var b: Dictionary = RunV2Views.boss_entry(bv)
		var plate: PanelContainer = PanelContainer.new()
		plate.name = "LoadoutBoss"
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color("#2A1416")
		sb.border_color = Color("#E5383B")
		sb.set_border_width_all(2)
		sb.set_content_margin_all(8)
		plate.add_theme_stylebox_override(&"panel", sb)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(row)
		row.add_child(RunGlyphs.make(&"node", &"boss", Color("#E5383B"), 36.0))
		var col: VBoxContainer = VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(col)
		for pair: Array in [["THIS RUN'S BOSS · %s" % String(b.get("name", "")).to_upper(), &"EnemyLabel"],
				["%s: %s" % [b.get("rule_name", ""), b.get("rule_text", "")], &""]]:
			var l: Label = make_label(pair[0], pair[1], true)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(l)
		wire_inspect_control(plate, func() -> void: inspector().open((load("res://scripts/ui/run/map_v2_view.gd") as GDScript).call(&"boss_info", b)))
		kit.add_child(plate)
	var mods: Array = RunV2Views.modifier_options(r)
	if mods.is_empty() or mods.all(func(m: Dictionary) -> bool: return bool(m.get("locked", false))) and RunV2Views.operator_choices(r).is_empty():
		return
	_threat_label = make_label("", &"HudAccent")
	_threat_label.name = "ThreatLabel"
	kit.add_child(_threat_label)
	for m: Dictionary in mods:
		var t: PickTile = make_tile()
		var id: StringName = StringName(str(m.get("id", "")))
		t.name = "Mod_%s" % id
		t.min_height = 64.0
		t.add_line("%s · THREAT %d" % [String(m.get("name", "")).to_upper(), int(m.get("threat", 0))], &"TileName")
		t.add_line(String(m.get("text", "")), &"", true)
		var locked: bool = bool(m.get("locked", false))
		if locked:
			t.add_status("LOCKED · %s" % String(m.get("unlock", "")).to_upper())
			t.disabled = true
		else:
			t.add_status("TAP TO ADD")
			t.set_selected(bool(m.get("on", false)), "ON · TAP TO REMOVE", "TAP TO ADD")
		t.pressed.connect(func() -> void: toggle_modifier(id))
		wire_inspect_button(t, func() -> void: inspector().open({"title": String(m.get("name", "")), "type": "modifier · threat %d" % int(m.get("threat", 0)),
				"text": String(m.get("text", "")), "status": ("Locked: %s" % m.get("unlock", "")) if locked else "Optional. Winning at a Threat level unlocks cosmetics, never power."}))
		kit.add_child(t)
		_mod_tiles[id] = t
	_threat_label.text = "MODIFIERS · THREAT %d" % RunV2Views.threat_of(mods)


## kc-v2-ui: adds / removes a run modifier (RunState.set_modifiers). Returns "" or the refusal.
func toggle_modifier(id: StringName) -> String:
	var on: Array = []
	for m: Dictionary in RunV2Views.modifier_options(run()):
		if bool(m.get("on", false)):
			on.append(StringName(str(m["id"])))
	if on.has(id):
		on.erase(id)
	else:
		on.append(id)
	var err: String = RunV2Views.act(run(), &"set_modifiers", [on])
	if err != "":
		_error.text = sentence(err)
		_error.show()
		return err
	_fill_kit()
	return ""


func get_modifier_tile(id: StringName) -> Button:
	return _mod_tiles.get(id)


## kc-ui4: the STARTING SQUAD panel over the screen (Operator pick + starter deck).
func open_starter() -> Control:
	if _starter != null:
		return _starter
	var script: GDScript = load("res://scripts/ui/run/starter_panel.gd") as GDScript
	_starter = script.new()
	_starter.name = "Starter"
	add_child(_starter)
	_starter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_starter.call(&"setup", run(), compact, "NEXT: KILLSTREAKS")
	_starter.connect(&"operator_picked", func(_id: StringName) -> void: _fill_kit())
	_starter.connect(&"closed", func() -> void:
		if _starter != null:
			_starter.queue_free()
			_starter = null)
	return _starter


func get_starter() -> Control:
	return _starter


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

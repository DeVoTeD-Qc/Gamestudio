# loadout_screen.gd
# Purpose: Loadout pick (p11, scenes/run/Loadout.tscn). Shows the starter kit (the Operator's
#   Primary, the 10-card deck) and the killstreak pool as tiles (kc-loadout-cut: no Secondary /
#   Lethal / Tactical rows any more). Tap a tile to pick it, tap a picked one to drop it; exactly RunConfig.killstreak_slots must be picked before
#   BEGIN RUN works (the starter three are pre-picked). BEGIN RUN calls RunState.set_killstreaks()
#   and begin_run(), then opens the run map.
#   kc-loadout-clean (head: "too much info in this screen"): the left column is a summary only: the
#   Operator (name + one line; long press = its rules, OPERATOR & DECK = pick it / see the deck),
#   the boss as one line (inspect), the modifiers you can add and an "n LOCKED" chip for the rest.
#   Killstreak tiles: art, name, streak cost, the effect's first sentence (long press = full rules).
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


## kc-ui-wire2: painted backdrop (assets/ui/backgrounds/bg_loadout.webp) under the run-screen scrim.
func backdrop_key() -> StringName:
	return &"loadout"


func screen_id() -> StringName:
	return &"loadout"


func _build() -> void:
	var r: RunProgress = run()
	# kc-loadout-clean: BACK is a plain secondary button at the left; BEGIN RUN the one amber
	# primary at the right (the subtitle says what it still needs).
	_back_button = make_button("BACK", &"HudButton", 120)
	_back_button.tooltip_text = "Back to the title screen"
	_back_button.pressed.connect(_on_back)
	_header.add_child(_back_button)
	_header.move_child(_back_button, 0)
	_begin_button = make_button("BEGIN RUN", &"ReadyButton", 220)
	_begin_button.pressed.connect(begin)
	_header.add_child(_begin_button)
	var row: BoxContainer = BoxContainer.new()  # kc-portrait: turns vertical in portrait
	row.add_theme_constant_override(&"separation", 16)
	_body.add_child(row)
	portrait_boxes.append(row)  # kc-portrait: the kit summary over the killstreak pool
	# kc-loadout-clean (head: "too much info in this screen"): the left column is a short summary
	# (Operator, boss, modifiers); every detail is one inspect or OPERATOR & DECK away.
	_kit_panel = PanelContainer.new()
	_kit_panel.theme_type_variation = &"HudPanelDark"
	_kit_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kit_panel.size_flags_stretch_ratio = 0.55
	# The panel hugs its (short) content; it scrolls only when a small screen can't fit it.
	_kit_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_kit_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "KitScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_kit_panel.add_child(scroll)
	var kit: VBoxContainer = VBoxContainer.new()
	kit.name = "Kit"
	kit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kit.add_theme_constant_override(&"separation", 8)
	scroll.add_child(kit)
	_kit = kit
	var fit: Callable = func() -> void:
		var room: float = maxf(120.0, _body.size.y - 16.0) if _body.size.y > 0.0 else 600.0
		scroll.custom_minimum_size.y = minf(kit.get_combined_minimum_size().y, room)
	kit.minimum_size_changed.connect(fit)
	_body.resized.connect(fit)
	_squad_button = make_button("OPERATOR & DECK", &"HudButton", 200)
	_squad_button.name = "SquadButton"
	_squad_button.tooltip_text = "Pick your starting Operator and see the starter deck"
	_squad_button.pressed.connect(open_starter)
	_fill_kit()
	# Killstreak pool: art, name, streak cost and a one-line effect (long press: the full rules).
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 8)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
			var tile: PickTile = _killstreak_tile(item)
			tile.pressed.connect(toggle.bind(item.id))
			_grid.add_child(tile)
			_tiles[item.id] = tile
	_refresh()
	if r != null:
		open_starter.call_deferred()


## kc-loadout-clean: a killstreak pick: NAME + STREAK n on one row, the effect's first sentence, the
## art, PICKED / TAP TO PICK. Long press / right click = the full rules.
func _killstreak_tile(item: LoadoutItem) -> PickTile:
	var tile: PickTile = make_tile()
	tile.name = "Killstreak_%s" % item.id
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile.tooltip_text = "%s (streak %d): %s" % [item.display_name, item.streak_threshold, item.text]
	var head: BoxContainer = BoxContainer.new()  # kc-portrait: STREAK n under the name
	head.name = "Head"
	head.vertical = portrait
	portrait_boxes.append(head)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override(&"separation", 8)
	tile.content.add_child(head)
	var nm: Label = make_label(item.display_name.to_upper(), &"TileName")
	nm.name = "Name"
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(nm)
	var cost: Label = make_label("STREAK %d" % item.streak_threshold, &"StreakLabel")
	cost.name = "StreakCost"
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(cost)
	var effect: Label = tile.add_line(one_line(item.text))
	effect.name = "Effect"
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
	wire_inspect_button(tile, func() -> void: inspector().open({"title": item.display_name, "type": "killstreak · streak %d" % item.streak_threshold,
			"text": item.text, "status": "Picked for this run." if item.id in picked else "Tap the tile to pick it (%d slots)." % _slots()}))
	return tile


## The first sentence of a rules text (the tile's one-line effect; the inspector has the rest).
static func one_line(text: String) -> String:
	var t: String = text.strip_edges().replace("\n", " ")
	var i: int = t.find(". ")
	return t.substr(0, i + 1) if i > 0 else t


## kc-loadout-clean: the left column: the Operator (name + one line; inspect or OPERATOR & DECK
## for the rest), the boss as one line, and the modifiers you can add (the locked ones behind a chip).
func _fill_kit() -> void:
	var r: RunProgress = run()
	for c: Node in _kit.get_children():
		if c != _squad_button:
			_kit.remove_child(c)
			c.queue_free()
	if _squad_button.get_parent() != null:
		_squad_button.get_parent().remove_child(_squad_button)
	var kit: VBoxContainer = _kit
	kit.add_child(_section("YOUR OPERATOR"))
	var op_row: HBoxContainer = HBoxContainer.new()
	op_row.name = "OperatorRow"
	op_row.add_theme_constant_override(&"separation", 10)
	kit.add_child(op_row)
	var info: VBoxContainer = VBoxContainer.new()
	info.name = "OperatorSummary"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", 0)
	info.custom_minimum_size.y = button_height()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	op_row.add_child(info)
	op_row.add_child(_squad_button)
	_squad_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if r != null:
		var item: LoadoutItem = r.resource(r.primary) as LoadoutItem
		if item != null:
			var name_l: Label = make_label(item.display_name, &"UnitName")
			name_l.name = "OperatorName"
			name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			info.add_child(name_l)
			var k: Dictionary = RunV2Views.operator_kit(item.id, r)
			var bits: PackedStringArray = []
			if not k.is_empty():
				bits.append("1x %s" % k.get("ability_name", ""))
			bits.append("%d cards" % r.deck.size())
			var line: Label = make_label("  ·  ".join(bits), &"HudSubtle")
			line.name = "OperatorLine"
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.clip_text = true
			line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			info.add_child(line)
			info.tooltip_text = "%s: %s. Long-press for the details." % [item.display_name, RunFlow.item_effect_line(item)]
			wire_inspect_control(info, func() -> void: inspector().open(_operator_info(item)))
	_fill_v2(kit, r)


func _section(text: String) -> Label:
	var l: Label = make_label(text, &"HudAccent")
	l.name = "Section_%s" % text.replace(" ", "_")
	return l


## The Operator's inspector (what STARTING SQUAD shows for it: stats, passive, ability, cost).
func _operator_info(item: LoadoutItem) -> Dictionary:
	var sp: Control = (load("res://scripts/ui/run/starter_panel.gd") as GDScript).new()
	sp.set(&"run", run())
	sp.set(&"_config", run().config if run() != null else null)
	sp.set(&"picked", item.id)
	var info: Dictionary = sp.call(&"operator_info", item)
	sp.free()
	info["status"] = "Your Operator for this run. OPERATOR & DECK: change it, see the starter deck."
	return info


# =============================================================================
# kc-v2-ui: the run's boss and the modifiers with Threat (kc-loadout-clean: one line for the boss,
# the locked modifiers behind an "n LOCKED" chip)
# =============================================================================

var _mod_tiles: Dictionary = {}
var _threat_label: Label = null
var _locked_chip: Button = null


func _fill_v2(kit: VBoxContainer, r: RunProgress) -> void:
	_mod_tiles.clear()
	_locked_chip = null
	var bv: Variant = r.call(&"boss_view") if r != null and r.has_method(&"boss_view") else null
	if bv is Dictionary and not (bv as Dictionary).is_empty():
		var b: Dictionary = RunV2Views.boss_entry(bv)
		var plate: PanelContainer = PanelContainer.new()
		plate.name = "LoadoutBoss"
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color("#2A1416")
		sb.border_color = Color("#E5383B")
		sb.set_border_width_all(1)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		plate.add_theme_stylebox_override(&"panel", sb)
		plate.custom_minimum_size.y = button_height()
		plate.tooltip_text = "Boss · %s: %s: %s" % [b.get("name", ""), b.get("rule_name", ""), b.get("rule_text", "")]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(row)
		var glyph: Control = RunGlyphs.make(&"node", &"boss", Color("#E5383B"), 28.0)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
		var l: Label = make_label("BOSS · %s · %s" % [String(b.get("name", "")).to_upper(), b.get("rule_name", "")], &"EnemyLabel")
		l.name = "BossLine"
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(l)
		wire_inspect_control(plate, func() -> void: inspector().open((load("res://scripts/ui/run/map_v2_view.gd") as GDScript).call(&"boss_info", b)))
		kit.add_child(plate)
	var mods: Array = RunV2Views.modifier_options(r)
	if mods.is_empty() or mods.all(func(m: Dictionary) -> bool: return bool(m.get("locked", false))) and RunV2Views.operator_choices(r).is_empty():
		return
	var head: HBoxContainer = HBoxContainer.new()
	head.name = "ModifierHead"
	head.add_theme_constant_override(&"separation", 8)
	kit.add_child(head)
	_threat_label = make_label("", &"HudAccent")
	_threat_label.name = "ThreatLabel"
	_threat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_threat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_threat_label)
	var locked: Array = mods.filter(func(m: Dictionary) -> bool: return bool(m.get("locked", false)))
	if not locked.is_empty():
		_locked_chip = make_button("%d LOCKED" % locked.size(), &"HudButton", 120)
		_locked_chip.name = "LockedModifiers"
		_locked_chip.tooltip_text = "The modifiers you have not unlocked yet, and how to unlock them"
		_locked_chip.pressed.connect(open_locked_modifiers)
		head.add_child(_locked_chip)
	for m: Dictionary in mods:
		if bool(m.get("locked", false)):
			continue
		var t: PickTile = make_tile()
		var id: StringName = StringName(str(m.get("id", "")))
		t.name = "Mod_%s" % id
		t.min_height = 64.0
		t.add_line("%s · THREAT %d" % [String(m.get("name", "")).to_upper(), int(m.get("threat", 0))], &"TileName")
		t.add_line(String(m.get("text", "")), &"", true)
		t.add_status("TAP TO ADD")
		t.set_selected(bool(m.get("on", false)), "ON · TAP TO REMOVE", "TAP TO ADD")
		t.pressed.connect(func() -> void: toggle_modifier(id))
		wire_inspect_button(t, func() -> void: inspector().open({"title": String(m.get("name", "")), "type": "modifier · threat %d" % int(m.get("threat", 0)),
				"text": String(m.get("text", "")), "status": "Optional. Winning at a Threat level unlocks cosmetics, never power."}))
		kit.add_child(t)
		_mod_tiles[id] = t
	_threat_label.text = "MODIFIERS · THREAT %d" % RunV2Views.threat_of(mods)
	if _mod_tiles.is_empty():
		var none: Label = make_label("None unlocked yet. Win runs to unlock them.", &"HudSubtle", true)
		none.name = "NoModifiers"
		kit.add_child(none)


## kc-loadout-clean: every modifier with its rule and how to unlock it (the "n LOCKED" chip).
func open_locked_modifiers() -> Control:
	var rows: Array = []
	for m: Dictionary in RunV2Views.modifier_options(run()):
		var locked: bool = bool(m.get("locked", false))
		rows.append({"name": "%s · Threat %d%s" % [m.get("name", ""), int(m.get("threat", 0)), "" if not locked else " · locked"],
				"text": "%s%s" % [m.get("text", ""), (" Unlock: %s." % String(m.get("unlock", "")).trim_suffix(".")) if locked else ""]})
	var ins: Control = inspector()
	ins.open({"title": "Modifiers", "type": "optional · they add Threat", "text": "Modifiers make a run harder. Winning at a Threat level unlocks cosmetics, never power.",
			"keywords": rows, "status": "Win runs to unlock the locked ones."})
	return ins


func get_locked_chip() -> Button:
	return _locked_chip


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
		tile.set_selected(id in picked, "PICKED", "TAP TO PICK")
	# kc-loadout-clean: the subtitle says what BEGIN RUN still needs (tap a picked tile to drop it).
	if picked.size() == slots:
		_subtitle.text = "%d of %d killstreaks picked  ·  tap one to swap it" % [picked.size(), slots]
	else:
		_subtitle.text = "Pick %d killstreaks  ·  %d of %d picked" % [slots, picked.size(), slots]
	_begin_button.disabled = picked.size() != slots

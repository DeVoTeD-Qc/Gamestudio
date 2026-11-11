# deck_builder.gd
# Purpose: kc-duel-ui. The Duel deck builder (scenes/duel/DeckBuilder.tscn, duel-mode.md §6.2-§6.5 and the
#   head's decisions): 10 picks, every tap adds the card x2, at least 5 units, at most 1 Elite, at most
#   3 Fields, a hero (the Operator, its own slot) and a Doctrine trait.
#   Phone landscape / iPad / desktop: the filterable card grid on the left, a fixed deck panel on the
#   right (hero strip, Doctrine strip, the composition line, the mana curve, the rule lines, the 10
#   deck rows, SAVE and PLAY). Phone portrait: hero + Doctrine on top, the grid, and a deck tray at
#   the bottom (curve, counts, the first rule line, SAVE / PLAY) that opens into the deck list.
#   - Grid tile = the card as it looks in the game (CardView) and a band under it: "+ ADD ×2",
#     "×2 IN DECK" (amber frame + tick), "LOCKED" (veil + lock: "Find it in a campaign run") -
#     shape and words, never colour alone. Tap = add / remove; long press / right click = the card.
#   - Filters: type chips (ALL / UNITS / TACTICS / FIELDS with counts), cost (ANY 1 2 3 4 5+), trait,
#     keyword, a name search and a LOCKED on/off chip. A curve bar or a rule line filters too.
#   - The counter "8/10 PICKS" punches on every change and a "+2" / "−2" chip flies to it; a
#     snackbar says what just happened ("Added Gunner ×2 · 8/10 picks") with UNDO after a removal;
#     an 11th pick shakes the tile and says "10/10: remove a pick first".
#   - Red rule lines block PLAY (the button names the first one); amber lines are advice; a green
#     line says READY. Tap a line = the grid shows the cards that fix it.
#   - BACK with changes asks SAVE / DISCARD / CANCEL. A preset can't be edited: it opens as a copy.
# Dependencies: run_screen.gd (base), duel_views.gd, duel_widgets.gd, duel_flow.gd, codex_view.gd
#   (make_card_view), CardView, CardInspector.tscn, ArtTraits, SynergyGlyphs.
# Author: UI/UX Agent (kc-duel-ui)
extends "res://scripts/ui/run/run_screen.gd"

signal deck_changed

const DuelViews: GDScript = preload("res://scripts/ui/duel/duel_views.gd")
const W: GDScript = preload("res://scripts/ui/duel/duel_widgets.gd")
const DuelFlow: GDScript = preload("res://scripts/ui/duel/duel_flow.gd")
const CodexView: GDScript = preload("res://scripts/ui/codex/codex_view.gd")
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")

const KINDS: Array[StringName] = [&"all", &"unit", &"tactic", &"field"]
const KIND_WORDS: Dictionary = {&"all": "ALL", &"unit": "UNITS", &"tactic": "TACTICS", &"field": "FIELDS"}
const KEYWORDS: Array[StringName] = [&"first_shot", &"pick", &"flank", &"cover", &"pierce", &"patch", &"suppress"]
const BAND_H: float = 30.0
## kc-da-ui: how far a locked card drops (its art stays full colour).
const LOCK_DROP: float = 4.0
const SNACK_S: float = 5.0

## The deck being edited (DuelViews deck shape) and what it was when the screen opened / last saved.
var deck: Dictionary = {}
var _saved_copy: Dictionary = {}
## Filters.
var kind_filter: StringName = &"all"
var cost_filter: int = 0          # 0 = any, 1..5 (5 = 5+, 1 = 1 or less)
var cost_min: int = 0             # rule-line fixes ("cost 4+")
var elite_only: bool = false      # rule-line fix (too many Elites)
var trait_filter: StringName = &"" # &"" any, &"none", or a trait
var keyword_filter: StringName = &""
var search_text: String = ""
var show_locked: bool = true
## Last removal (UNDO): {pick, index}.
var _undo: Dictionary = {}

var _pool: Array[Dictionary] = []
var _tiles: Dictionary = {}       # card id -> Button
var _grid: GridContainer = null
var _grid_scroll: ScrollContainer = null
var _empty: Control = null
var _counter: Label = null
var _name_button: Button = null
var _hero_holder: Control = null
var _doctrine_holder: Control = null
var _curve: Control = null
var _comp: Label = null
var _rules_box: VBoxContainer = null
var _list_box: VBoxContainer = null
var _list_wrap: Control = null
var _tray_toggle: Button = null
var _save_button: Button = null
var _play_button: Button = null
var _kind_buttons: Dictionary = {}
var _cost_buttons: Dictionary = {}
var _trait_button: OptionButton = null
var _keyword_button: OptionButton = null
var _locked_button: Button = null
var _search: LineEdit = null
var _snack: PanelContainer = null
var _snack_label: Label = null
var _snack_undo: Button = null
var _snack_id: int = 0
var _confirm: Dictionary = {}
var _tray_open: bool = false
var _tile_w: float = 132.0
var _last_text: String = ""
var _built_portrait: int = -1


func screen_id() -> StringName:
	return &"duel_builder"


## The player picked the Doctrine (None included) themselves: no automatic choice any more.
var _doctrine_touched: bool = false


func backdrop_key() -> StringName:
	return &""


func _build() -> void:
	var d: Dictionary = DuelFlow.edit_deck
	if bool(d.get("preset", false)):
		d = DuelViews.copy_of(d)
	deck = d.duplicate(true) if not d.is_empty() else DuelViews.new_deck()
	if not deck.has("picks"):
		deck["picks"] = []
	_saved_copy = deck.duplicate(true) if String(deck.get("id", "")) != "" else {}
	_pool = DuelViews.pool()


## Called by the base on every profile change (and once at start): the layout follows the screen.
func _apply_compact() -> void:
	var want: int = 1 if portrait else 0
	if want != _built_portrait or _grid == null:
		_built_portrait = want
		_rebuild()
	else:
		_fit_grid()


func _safe_area_changed() -> void:
	_fit_grid.call_deferred()


# =============================================================================
# Public API (tests, other screens)
# =============================================================================

func get_tile(id: StringName) -> Button:
	return _tiles.get(id)


func get_tiles() -> Array[Node]:
	return _grid.get_children() if _grid != null else []


func get_counter() -> Label:
	return _counter


func get_play_button() -> Button:
	return _play_button


func get_save_button() -> Button:
	return _save_button


func get_curve() -> Control:
	return _curve


func get_rule_lines() -> Array[Node]:
	return _rules_box.get_children() if _rules_box != null else []


func get_deck_rows() -> Array[Node]:
	return _list_box.get_children() if _list_box != null else []


func get_hero_strip() -> Button:
	return _hero_holder.get_node_or_null(^"HeroStrip") as Button if _hero_holder != null else null


func get_doctrine_strip() -> Button:
	return _doctrine_holder.get_node_or_null(^"DoctrineStrip") as Button if _doctrine_holder != null else null


func get_kind_button(k: StringName) -> Button:
	return _kind_buttons.get(k)


func get_cost_button(c: int) -> Button:
	return _cost_buttons.get(c)


func get_search() -> LineEdit:
	return _search


func get_snack_text() -> String:
	return _snack_label.text if _snack != null and _snack.visible else ""


func get_snack_undo() -> Button:
	return _snack_undo


func get_tray_toggle() -> Button:
	return _tray_toggle


func is_tray_open() -> bool:
	return _tray_open


func is_dirty() -> bool:
	return _strip(deck) != _strip(_saved_copy) if not _saved_copy.is_empty() else not (deck.get("picks", []) as Array).is_empty() or String(deck.get("name", "")) != ""


func get_confirm() -> Dictionary:
	return _confirm if not _confirm.is_empty() and is_instance_valid(_confirm.get("root")) else {}


static func _strip(d: Dictionary) -> Dictionary:
	return {"name": d.get("name", ""), "hero": d.get("hero", &""), "doctrine": d.get("doctrine", &""), "picks": d.get("picks", [])}


# =============================================================================
# Picks
# =============================================================================

## Tap on a tile: adds the card x2, or removes it when it is in the deck. {ok, text}.
func tap_card(id: StringName) -> Dictionary:
	var c: CardData = DuelViews.card(id)
	if c == null:
		return {"ok": false, "text": ""}
	if DuelViews.has_pick(deck, id):
		return remove_card(id)
	return add_card(id)


func add_card(id: StringName, t: StringName = &"") -> Dictionary:
	var c: CardData = DuelViews.card(id)
	if c == null:
		return {"ok": false, "text": ""}
	if not DuelViews.is_owned(c):
		var msg: String = "%s is locked: find it in a campaign run." % c.display_name
		_refuse(id, msg)
		return {"ok": false, "text": msg}
	var n: int = DuelViews.pick_ids(deck).size()
	if n >= DuelViews.MAX_PICKS:
		var full: String = "%d/%d: remove a pick first." % [n, DuelViews.MAX_PICKS]
		_refuse(id, full)
		return {"ok": false, "text": full}
	(deck["picks"] as Array).append(DuelViews.make_pick(id, t))
	_undo = {}
	var now: int = n + 1
	var extra: String = ""
	var r: Dictionary = DuelViews.validate(deck)
	for e: Dictionary in r["errors"]:
		if StringName(e["code"]) in [&"elite_max", &"field_max", &"elite_over", &"fields_over"]:
			extra = " · " + String(e["text"])
	var text: String = "Added %s ×2 · %d/%d picks%s" % [c.display_name, now, DuelViews.MAX_PICKS, extra]
	_changed(text, false, id, 2)
	SfxBankScript.cue(&"card_land")
	return {"ok": true, "text": text}


func remove_card(id: StringName) -> Dictionary:
	var picks: Array = deck["picks"]
	for i: int in picks.size():
		if StringName(str(picks[i]["card"])) == id:
			_undo = {"pick": (picks[i] as Dictionary).duplicate(), "index": i}
			picks.remove_at(i)
			var c: CardData = DuelViews.card(id)
			var text: String = "Removed %s ×2 · %d/%d picks" % [c.display_name if c != null else String(id), picks.size(), DuelViews.MAX_PICKS]
			_changed(text, true, id, -2)
			SfxBankScript.cue(&"click")
			return {"ok": true, "text": text}
	return {"ok": false, "text": ""}


## UNDO on the snackbar: puts the last removed pick back where it was.
func undo_remove() -> bool:
	if _undo.is_empty():
		return false
	var p: Dictionary = _undo["pick"]
	var picks: Array = deck["picks"]
	picks.insert(mini(int(_undo["index"]), picks.size()), p)
	_undo = {}
	var c: CardData = DuelViews.card(StringName(str(p["card"])))
	_changed("Put back %s ×2 · %d/%d picks" % [c.display_name if c != null else "", picks.size(), DuelViews.MAX_PICKS], false, StringName(str(p["card"])), 2)
	return true


## The art (and so the trait) of a pick's two copies.
func set_pick_trait(id: StringName, t: StringName) -> void:
	for p: Dictionary in deck["picks"]:
		if StringName(str(p["card"])) == id:
			p["art"] = DuelViews.art_for(DuelViews.card(id), t)
	var c: CardData = DuelViews.card(id)
	_changed("%s ×2 now wear %s art: both copies are %s" % [c.display_name, ArtTraits.trait_name(t), ArtTraits.trait_name(t)], false)


func set_hero(id: StringName) -> Dictionary:
	var h: Dictionary = DuelViews.hero(id)
	if h.is_empty():
		return {"ok": false, "text": ""}
	if not bool(h["unlocked"]):
		var msg: String = "%s is locked: %s" % [h["name"], h["unlock_text"]]
		_snackbar(msg, false)
		return {"ok": false, "text": msg}
	deck["hero"] = id
	_changed("Hero: %s (%s)" % [h["name"], h["passive_name"]], false)
	return {"ok": true, "text": ""}


func set_doctrine(t: StringName) -> void:
	_doctrine_touched = true
	deck["doctrine"] = t
	_changed("Doctrine: %s" % (SynergyGlyphs.trait_name(t) if t != &"" else "none"), false)


## kc-duel-impl (§12.3): a new deck's Doctrine follows its most-picked trait once that trait has the
## picks a Doctrine needs, until the player picks one (None included) themselves.
func _auto_doctrine() -> void:
	if _doctrine_touched or String(deck.get("id", "")) != "" or StringName(str(deck.get("doctrine", ""))) != &"":
		return
	var main: StringName = DuelViews.main_trait(deck)
	if main != &"" and DuelViews.picks_wearing(deck, main) >= maxi(1, DuelViews.doctrine_min()):
		deck["doctrine"] = main


func set_deck_name(n: String) -> void:
	deck["name"] = DuelViews.clip_name(n)
	_changed("Renamed: %s" % deck_name(), false)


func deck_name() -> String:
	var n: String = String(deck.get("name", ""))
	return n if n != "" else DuelViews.default_name(deck)


## SAVE: works at any time, also for an unfinished deck. {ok, text}.
func save() -> Dictionary:
	if String(deck.get("name", "")) == "":
		deck["name"] = DuelViews.default_name(deck)
	var r: Dictionary = DuelViews.save_deck(deck)
	if bool(r.get("ok", false)):
		deck["id"] = String(r.get("id", deck.get("id", "")))
		_saved_copy = deck.duplicate(true)
		var chip: Dictionary = DuelViews.status_chip(deck)
		_snackbar("Saved %s · %s" % [deck_name(), String(chip["text"]).to_lower()], false)
		SfxBankScript.cue(&"reward")
	else:
		_snackbar(String(r.get("text", "Could not save.")), false)
	_refresh_panel()
	return r


## PLAY: only with a legal deck; opens the hub's VS AI setup with this deck. {ok, text}.
func play() -> Dictionary:
	var r: Dictionary = DuelViews.validate(deck)
	if not bool(r["ok"]):
		var t: String = String(r["errors"][0]["text"])
		_snackbar(t, false)
		_shake(_play_button)
		return {"ok": false, "text": t}
	save()
	DuelFlow.set_edit_deck(deck)
	DuelFlow.set_hub_tab("play:" + String(deck.get("id", "")))
	goto(DuelFlow.SCENE_HUB)
	return {"ok": true, "text": ""}


## BACK: with changes, asks SAVE / DISCARD / CANCEL first.
func back() -> void:
	if is_dirty():
		_ask_leave()
		return
	goto(DuelFlow.builder_return)


# =============================================================================
# Filters
# =============================================================================

func set_kind_filter(k: StringName) -> void:
	kind_filter = k
	_refill()


func set_cost_filter(c: int) -> void:
	cost_filter = c if c != cost_filter else 0
	cost_min = 0
	_refill()


func set_trait_filter(t: StringName) -> void:
	trait_filter = t
	_refill()


func set_keyword_filter(k: StringName) -> void:
	keyword_filter = k
	_refill()


func set_search(text: String) -> void:
	search_text = text
	if _search != null and _search.text != text:
		_search.text = text
	_refill()


func set_show_locked(on: bool) -> void:
	show_locked = on
	_refill()


func clear_filters() -> void:
	kind_filter = &"all"
	cost_filter = 0
	cost_min = 0
	elite_only = false
	trait_filter = &""
	keyword_filter = &""
	search_text = ""
	if _search != null:
		_search.text = ""
	_refill()


## A rule line's fix: {kind?, cost_max?, cost_min?, elite?, hero?, doctrine?} (duel-api.md §2 fix_filter).
## hero / doctrine open their picker instead of filtering the grid.
func apply_fix(fix: Dictionary) -> void:
	if bool(fix.get("hero", false)):
		open_hero_picker()
		return
	if bool(fix.get("doctrine", false)):
		open_doctrine_picker()
		return
	clear_filters()
	elite_only = bool(fix.get("elite", false))
	if fix.has("kind"):
		kind_filter = StringName(str(fix["kind"]))
	if fix.has("cost_max"):
		cost_filter = clampi(int(fix["cost_max"]), 1, 5)
	if fix.has("cost_min"):
		cost_min = int(fix["cost_min"])
	_refill()


func passes(e: Dictionary) -> bool:
	if kind_filter != &"all" and e["kind"] != kind_filter:
		return false
	var cost: int = int(e["cost"])
	if cost_filter > 0 and DuelViews.cost_bucket(cost) != cost_filter:
		return false
	if cost_min > 0 and cost < cost_min:
		return false
	if elite_only and not bool(e["elite"]):
		return false
	if trait_filter == &"none" and not (e["traits"] as Array).is_empty():
		return false
	if trait_filter != &"" and trait_filter != &"none" and not (trait_filter in (e["traits"] as Array)):
		return false
	if keyword_filter != &"" and not (String(keyword_filter) in (e["keywords"] as PackedStringArray)):
		return false
	if search_text.strip_edges() != "" and not String(e["name"]).to_lower().contains(search_text.strip_edges().to_lower()):
		return false
	if not show_locked and not bool(e["owned"]):
		return false
	return true


func filtered() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _pool:
		if passes(e):
			out.append(e)
	return out


# =============================================================================
# Building
# =============================================================================

func _rebuild() -> void:
	var layout: VBoxContainer = %Layout
	clear(layout)
	_tiles.clear()
	_kind_buttons.clear()
	_cost_buttons.clear()
	_snack = null
	layout.add_theme_constant_override(&"separation", 6 if compact else 10)
	layout.add_child(_top_bar())
	if portrait:
		var strips: HBoxContainer = HBoxContainer.new()
		strips.add_theme_constant_override(&"separation", 6)
		_hero_holder = _holder("HeroHolder")
		_doctrine_holder = _holder("DoctrineHolder")
		strips.add_child(_hero_holder)
		strips.add_child(_doctrine_holder)
		layout.add_child(strips)
		layout.add_child(_filters())
		layout.add_child(_grid_area())
		layout.add_child(_tray())
	else:
		var body: HBoxContainer = HBoxContainer.new()
		body.name = "Body"
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override(&"separation", 10)
		layout.add_child(body)
		var left: VBoxContainer = VBoxContainer.new()
		left.name = "Left"
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_theme_constant_override(&"separation", 6)
		body.add_child(left)
		left.add_child(_filters())
		left.add_child(_grid_area())
		body.add_child(_side_panel())
	_build_snackbar()
	_refill()
	_refresh_panel()
	_fit_grid.call_deferred()


func _holder(n: String) -> Control:
	var h: VBoxContainer = VBoxContainer.new()
	h.name = n
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h


func _top_bar() -> HBoxContainer:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.name = "TopBar"
	bar.add_theme_constant_override(&"separation", 8)
	var back_b: Button = make_button("BACK", &"HudButton", 96 if portrait else 120)
	back_b.name = "BackButton"
	back_b.add_to_group(&"tap_target")
	back_b.tooltip_text = "Back to the Duel hub (asks first if you have changes)"
	back_b.pressed.connect(back)
	bar.add_child(back_b)
	_name_button = make_button("", &"HudButton", 0)
	_name_button.name = "NameButton"
	_name_button.add_to_group(&"tap_target")
	_name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_button.clip_text = true
	_name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_button.tooltip_text = "Tap to rename the deck (up to 20 letters)"
	_name_button.pressed.connect(open_rename)
	bar.add_child(_name_button)
	var cp: PanelContainer = W.panel(Color("#1E262D"), W.PANEL_RIM, 4.0)
	cp.name = "CounterPanel"
	cp.custom_minimum_size = Vector2(150 if portrait else 176, 0)
	_counter = W.label("0/10 PICKS", &"HudNumber", 26 if not compact else 22, W.FOG)
	_counter.name = "PickCounter"
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cp.add_child(_counter)
	wire_inspect_control(cp, func() -> void: inspector().open({"title": "Picks", "type": "%s" % _counter.text,
			"text": "A Duel deck is exactly 10 picks. Every pick puts 2 copies in the deck, so the deck is always 20 cards. You can pick each card once.",
			"keywords": [], "status": "At least 5 unit picks · at most 1 Elite ★ · at most 3 Fields."}), true)
	bar.add_child(cp)
	return bar


func _filters() -> Control:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "FilterScroll"
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = W.TAP + 4.0
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Filters"
	row.add_theme_constant_override(&"separation", 6)
	scroll.add_child(row)
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = "Search name"
	_search.custom_minimum_size = Vector2(170 if not portrait else 150, W.TAP)
	_search.clear_button_enabled = true
	_search.add_theme_font_size_override(&"font_size", 18)
	_search.text = search_text
	_search.text_changed.connect(func(t: String) -> void:
		search_text = t
		_refill())
	row.add_child(_search)
	for k: StringName in KINDS:
		var b: Button = _chip(String(KIND_WORDS[k]))
		b.name = "Kind_%s" % k
		b.pressed.connect(set_kind_filter.bind(k))
		_kind_buttons[k] = b
		row.add_child(b)
	row.add_child(_sep())
	for c: int in [0, 1, 2, 3, 4, 5]:
		var b: Button = _chip("ANY" if c == 0 else DuelViews.CURVE_LABELS[c - 1])
		b.name = "Cost_%d" % c
		b.tooltip_text = "Any cost" if c == 0 else "Cost %s" % DuelViews.CURVE_LABELS[c - 1]
		b.pressed.connect(func() -> void:
			if c == 0:
				cost_filter = 0
				cost_min = 0
				_refill()
			else:
				set_cost_filter(c))
		_cost_buttons[c] = b
		row.add_child(b)
	row.add_child(_sep())
	_trait_button = OptionButton.new()
	_trait_button.name = "TraitFilter"
	_trait_button.theme_type_variation = &"HudButton"
	_trait_button.custom_minimum_size = Vector2(150, W.TAP)
	_trait_button.add_to_group(&"tap_target")
	_trait_button.add_item("ANY TRAIT")
	_trait_button.set_item_metadata(0, &"")
	for t: StringName in SynergyRules.TRAITS:
		_trait_button.add_item(SynergyGlyphs.trait_name(t).to_upper())
		_trait_button.set_item_metadata(_trait_button.item_count - 1, t)
	_trait_button.add_item("NO TRAIT")
	_trait_button.set_item_metadata(_trait_button.item_count - 1, &"none")
	_trait_button.item_selected.connect(func(i: int) -> void: set_trait_filter(StringName(_trait_button.get_item_metadata(i))))
	_popup_size(_trait_button)
	row.add_child(_trait_button)
	_keyword_button = OptionButton.new()
	_keyword_button.name = "KeywordFilter"
	_keyword_button.theme_type_variation = &"HudButton"
	_keyword_button.custom_minimum_size = Vector2(160, W.TAP)
	_keyword_button.add_to_group(&"tap_target")
	_keyword_button.add_item("ANY KEYWORD")
	_keyword_button.set_item_metadata(0, &"")
	for k: StringName in KEYWORDS:
		_keyword_button.add_item(SynergyGlyphs.keyword_name(k).to_upper())
		_keyword_button.set_item_metadata(_keyword_button.item_count - 1, k)
	_keyword_button.item_selected.connect(func(i: int) -> void: set_keyword_filter(StringName(_keyword_button.get_item_metadata(i))))
	_popup_size(_keyword_button)
	row.add_child(_keyword_button)
	_locked_button = _chip("LOCKED: SHOWN")
	_locked_button.name = "LockedToggle"
	_locked_button.tooltip_text = "Show or hide the cards you haven't found in a campaign run yet"
	_locked_button.pressed.connect(func() -> void: set_show_locked(not show_locked))
	row.add_child(_locked_button)
	return scroll


func _popup_size(o: OptionButton) -> void:
	var popup: PopupMenu = o.get_popup()
	popup.add_theme_font_size_override(&"font_size", 22)
	popup.add_theme_constant_override(&"v_separation", 30)


func _sep() -> Control:
	var s: VSeparator = VSeparator.new()
	s.custom_minimum_size.x = 6
	return s


func _chip(text: String) -> Button:
	var b: Button = make_button(text, &"HudButton", 64)
	b.toggle_mode = true
	b.add_to_group(&"tap_target")
	b.custom_minimum_size = Vector2(64, W.TAP)
	return b


func _grid_area() -> Control:
	var wrap: VBoxContainer = VBoxContainer.new()
	wrap.name = "GridArea"
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.name = "GridScroll"
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(_grid_scroll)
	_grid = GridContainer.new()
	_grid.name = "CardGrid"
	_grid.add_theme_constant_override(&"h_separation", 8)
	_grid.add_theme_constant_override(&"v_separation", 8)
	_grid_scroll.add_child(_grid)
	_grid_scroll.resized.connect(_fit_grid)
	var empty: VBoxContainer = VBoxContainer.new()
	empty.name = "Empty"
	empty.alignment = BoxContainer.ALIGNMENT_CENTER
	empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	empty.visible = false
	empty.add_child(W.label("No card matches these filters.", &"HudSubtle", 18))
	var clr: Button = make_button("CLEAR FILTERS", &"HudButton", 220)
	clr.name = "ClearFilters"
	clr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	clr.pressed.connect(clear_filters)
	empty.add_child(clr)
	wrap.add_child(empty)
	_empty = empty
	return wrap


## Landscape / desktop: the fixed deck panel on the right.
func _side_panel() -> Control:
	var p: PanelContainer = W.panel(Color("#12171C"), W.PANEL_RIM, 8.0)
	p.name = "DeckPanel"
	var vr: Vector2 = get_viewport_rect().size
	p.custom_minimum_size.x = clampf(vr.x * 0.3, 330.0, 420.0)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	p.add_child(col)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "PanelScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override(&"separation", 6)
	scroll.add_child(inner)
	_hero_holder = _holder("HeroHolder")
	inner.add_child(_hero_holder)
	_doctrine_holder = _holder("DoctrineHolder")
	inner.add_child(_doctrine_holder)
	_comp = W.label("", &"HudSubtle", 16, Color(0, 0, 0, 0), true)
	_comp.name = "Composition"
	inner.add_child(_comp)
	_curve = W.CurveChart.new(92.0 if compact else 110.0)
	_curve.name = "Curve"
	_wire_curve()
	inner.add_child(_curve)
	_rules_box = VBoxContainer.new()
	_rules_box.name = "RuleLines"
	_rules_box.add_theme_constant_override(&"separation", 4)
	inner.add_child(_rules_box)
	inner.add_child(W.label("DECK LIST · 10 PICKS ×2", &"HudTag", 16, W.FOG))
	_list_box = VBoxContainer.new()
	_list_box.name = "DeckList"
	_list_box.add_theme_constant_override(&"separation", 4)
	inner.add_child(_list_box)
	col.add_child(_buttons())
	return p


## Portrait: the deck tray at the bottom (opens into the deck list).
func _tray() -> Control:
	var p: PanelContainer = W.panel(Color("#12171C"), W.PANEL_RIM, 8.0)
	p.name = "DeckTray"
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	p.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 8)
	col.add_child(top)
	_curve = W.CurveChart.new(84.0)
	_curve.name = "Curve"
	_curve.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wire_curve()
	top.add_child(_curve)
	_tray_toggle = make_button("DECK LIST", &"HudButton", 150)
	_tray_toggle.name = "TrayToggle"
	_tray_toggle.add_to_group(&"tap_target")
	_tray_toggle.tooltip_text = "Open the 10-row deck list"
	_tray_toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tray_toggle.pressed.connect(func() -> void: set_tray_open(not _tray_open))
	top.add_child(_tray_toggle)
	_comp = W.label("", &"HudSubtle", 16, Color(0, 0, 0, 0), true)
	_comp.name = "Composition"
	col.add_child(_comp)
	var list_scroll: ScrollContainer = ScrollContainer.new()
	list_scroll.name = "TrayList"
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.custom_minimum_size.y = minf(get_viewport_rect().size.y * 0.42, 10 * (W.ROW_H + 4.0))
	list_scroll.visible = _tray_open
	col.add_child(list_scroll)
	_list_wrap = list_scroll
	_list_box = VBoxContainer.new()
	_list_box.name = "DeckList"
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override(&"separation", 4)
	list_scroll.add_child(_list_box)
	_rules_box = VBoxContainer.new()
	_rules_box.name = "RuleLines"
	_rules_box.add_theme_constant_override(&"separation", 4)
	col.add_child(_rules_box)
	col.add_child(_buttons())
	return p


func set_tray_open(on: bool) -> void:
	_tray_open = on
	if _list_wrap != null:
		_list_wrap.visible = on
	if _tray_toggle != null:
		_tray_toggle.text = "HIDE LIST" if on else "DECK LIST"
	_refresh_panel()


func _buttons() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Buttons"
	row.add_theme_constant_override(&"separation", 8)
	_save_button = make_button("SAVE", &"HudButton", 110)
	_save_button.name = "SaveButton"
	_save_button.add_to_group(&"tap_target")
	_save_button.tooltip_text = "Save the deck (an unfinished deck can be saved too)"
	_save_button.pressed.connect(func() -> void: save())
	row.add_child(_save_button)
	_play_button = make_button("PLAY", &"ReadyButton", 0)
	_play_button.name = "PlayButton"
	_play_button.add_to_group(&"tap_target")
	_play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_button.clip_text = true
	_play_button.pressed.connect(func() -> void: play())
	row.add_child(_play_button)
	return row


func _wire_curve() -> void:
	_curve.bar_tapped.connect(func(i: int) -> void:
		set_cost_filter(i + 1)
		_snackbar("Showing cost %s cards" % DuelViews.CURVE_LABELS[i] if cost_filter > 0 else "Showing every cost", false))
	_curve.bar_inspected.connect(func(i: int) -> void: inspector().open(W.curve_info(DuelViews.curve(deck), i)))


# =============================================================================
# Grid
# =============================================================================

func _fit_grid() -> void:
	if _grid == null or _grid_scroll == null:
		return
	var room: float = _grid_scroll.size.x - 14.0
	if room <= 0.0:
		return
	var want: float = 164.0 if not compact else (150.0 if portrait else 132.0)
	var cols: int = maxi(2, int(floorf((room + 8.0) / (want + 8.0))))
	if portrait:
		cols = 3
	var w: float = floorf((room - 8.0 * (cols - 1)) / cols)
	w = clampf(w, 120.0, 200.0)
	_grid.columns = cols
	if absf(w - _tile_w) > 1.0:
		_tile_w = w
		_refill()


func _refill() -> void:
	if _grid == null:
		return
	for k: StringName in _kind_buttons:
		var n: int = 0
		for e: Dictionary in _pool:
			if k == &"all" or e["kind"] == k:
				n += 1
		(_kind_buttons[k] as Button).text = "%s · %d" % [KIND_WORDS[k], n]
		(_kind_buttons[k] as Button).set_pressed_no_signal(k == kind_filter)
	for c: int in _cost_buttons:
		(_cost_buttons[c] as Button).set_pressed_no_signal(c == cost_filter and cost_min == 0)
	if cost_min > 0 and _cost_buttons.has(0):
		(_cost_buttons[0] as Button).text = "%d+" % cost_min
	elif _cost_buttons.has(0):
		(_cost_buttons[0] as Button).text = "ANY"
	if _trait_button != null:
		for i: int in _trait_button.item_count:
			if StringName(_trait_button.get_item_metadata(i)) == trait_filter:
				_trait_button.select(i)
	if _keyword_button != null:
		for i: int in _keyword_button.item_count:
			if StringName(_keyword_button.get_item_metadata(i)) == keyword_filter:
				_keyword_button.select(i)
	if _locked_button != null:
		_locked_button.text = "LOCKED: SHOWN" if show_locked else "LOCKED: HIDDEN"
		_locked_button.set_pressed_no_signal(not show_locked)
	for c: Node in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_tiles.clear()
	var list: Array[Dictionary] = filtered()
	for e: Dictionary in list:
		var t: Button = _make_tile(e)
		_grid.add_child(t)
		_tiles[e["id"]] = t
	_empty.visible = list.is_empty()
	_grid_scroll.visible = not list.is_empty()
	if _curve != null:
		_curve.selected = cost_filter - 1 if cost_min == 0 else -1
		_curve.queue_redraw()


func _make_tile(e: Dictionary) -> Button:
	var c: CardData = e["card"]
	var id: StringName = e["id"]
	var b: Button = Button.new()
	b.name = "Tile_%s" % id
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_to_group(&"tap_target")
	b.set_meta(&"card", id)
	var csz: Vector2 = CardView.size_for(_tile_w)
	b.custom_minimum_size = csz + Vector2(0, BAND_H + 2.0)
	var pick: Dictionary = {}
	for p: Dictionary in deck["picks"]:
		if StringName(str(p["card"])) == id:
			pick = p
	var art: StringName = StringName(str(pick.get("art", ""))) if not pick.is_empty() else &""
	var owned: bool = bool(e["owned"])
	var picked: bool = not pick.is_empty()
	# kc-da-ui (art direction v1 #5): a locked card keeps its art in full colour: a grey cost hex,
	# the card drops LOCK_DROP px, and the band below says LOCKED with a lock mark.
	var view: Dictionary = CardView.view_for_card(c, art)
	if not owned:
		view["cant_pay"] = true
	var cv: CardView = CodexView.make_card_view(view, _tile_w)
	cv.size = csz
	cv.position.y = 0.0 if owned else LOCK_DROP
	b.add_child(cv)
	var band: PanelContainer = PanelContainer.new()
	band.name = "Band"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.position = Vector2(0, csz.y + 2.0)
	band.size = Vector2(csz.x, BAND_H)
	# kc-da-ui: picks are "you" (teal), not amber; amber is the one PLAY button.
	var bg: Color = W.TEAL if picked else W.STEEL_BG
	band.add_theme_stylebox_override(&"panel", W.flat(bg, Color(0, 0, 0, 0), 0, 4, 2))
	b.add_child(band)
	var brow: HBoxContainer = HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brow.add_theme_constant_override(&"separation", 4)
	band.add_child(brow)
	var word: String = ""
	if picked:
		brow.add_child(W.Mark.new(&"tick", W.INK, 16))
		word = "×2 IN DECK"
	elif not owned:
		brow.add_child(W.Mark.new(&"lock", W.STEEL_BAR, 16))
		word = "LOCKED"
	else:
		brow.add_child(W.Mark.new(&"plus", W.FOG, 14))
		word = "ADD ×2"
	var bl: Label = W.label(word, &"HudTag", 16, W.INK if picked else (W.STEEL_BAR.lightened(0.3) if not owned else W.FOG))
	bl.name = "BandText"
	brow.add_child(bl)
	b.set_meta(&"state", &"picked" if picked else (&"locked" if not owned else &"open"))
	if picked or not owned:
		b.draw.connect(func() -> void:
			if picked:
				b.draw_rect(Rect2(Vector2.ZERO, csz + Vector2(0, BAND_H + 2.0)).grow(-1.0), W.TEAL, false, 3.0))
	b.tooltip_text = "%s · %s · hold / right click: the full card" % [c.display_name,
			"tap: remove both copies" if picked else ("Find it in a campaign run" if not owned else "tap: add 2 copies")]
	var g: RefCounted = PressGesture.new(b)
	g.drag_enabled = false
	b.set_meta(&"gesture", g)
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if g.handle(ev):
			b.accept_event())
	g.tapped.connect(func(_p: Vector2) -> void: tap_card.call_deferred(id))
	g.long_pressed.connect(func(_p: Vector2) -> void: inspect_card(id))
	b.pressed.connect(func() -> void:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not g.pressed:
			tap_card.call_deferred(id))
	return b


func inspect_card(id: StringName) -> void:
	var c: CardData = DuelViews.card(id)
	if c == null:
		return
	var art: StringName = &""
	var status: String = ""
	for p: Dictionary in deck["picks"]:
		if StringName(str(p["card"])) == id:
			art = StringName(str(p["art"]))
			status = "IN YOUR DECK ×2"
	inspector().open(W.card_info(c, art, status))


# =============================================================================
# The deck panel
# =============================================================================

func _refresh_panel() -> void:
	if _counter == null:
		return
	var n: int = DuelViews.pick_ids(deck).size()
	_counter.text = "%d/%d PICKS" % [n, DuelViews.MAX_PICKS]
	_counter.add_theme_color_override(&"font_color", W.GREEN if n == DuelViews.MAX_PICKS else W.FOG)
	_name_button.text = "%s  ·  RENAME" % deck_name()
	# Hero and Doctrine.
	for holder: Control in [_hero_holder, _doctrine_holder]:
		if holder != null:
			clear(holder)
	var h: Dictionary = DuelViews.hero(StringName(str(deck.get("hero", ""))))
	_hero_holder.add_child(W.hero_strip(h, open_hero_picker, func() -> void: inspector().open(W.hero_info(h)), compact))
	_doctrine_holder.add_child(_doctrine_strip())
	# Composition, curve, rules.
	var comp: Dictionary = DuelViews.composition(deck)
	var tparts: PackedStringArray = []
	for t: StringName in comp["traits"]:
		tparts.append("%s %d" % [SynergyGlyphs.trait_name(t), comp["traits"][t]])
	_comp.text = "Units %d · Tactics %d · Fields %d%s" % [comp["units"], comp["tactics"], comp["fields"],
			(" · " + " · ".join(tparts)) if not tparts.is_empty() else ""]
	_curve.set_counts(DuelViews.curve(deck))
	clear(_rules_box)
	var r: Dictionary = DuelViews.validate(deck)
	var lines: Array = []
	for e: Dictionary in r["errors"]:
		lines.append([e, &"error"])
	for e: Dictionary in r["warnings"]:
		lines.append([e, &"warning"])
	if bool(r["ok"]):
		lines.push_front([{"text": String(r["ready_text"]), "fix": {}}, &"ok"])
	var shown: int = 0
	for pair: Array in lines:
		# Portrait tray: the first two lines while the list is closed (the rest are one tap away).
		if portrait and not _tray_open and shown >= 2:
			break
		var e: Dictionary = pair[0]
		var line: Button = W.rule_line(String(e["text"]), pair[1])
		line.name = "Rule_%d" % shown
		var fix: Dictionary = e.get("fix", {})
		line.pressed.connect(func() -> void:
			if e.has("card"):
				inspect_card(StringName(str(e["card"])))
			elif not fix.is_empty():
				apply_fix(fix)
				if not (fix.has("hero") or fix.has("doctrine")):
					_snackbar("Showing the cards that fix it: %s" % String(e["text"]), false))
		_rules_box.add_child(line)
		shown += 1
	if portrait and not _tray_open and lines.size() > shown:
		_rules_box.add_child(W.label("+%d more in the deck list" % (lines.size() - shown), &"HudSubtle", 16))
	# PLAY names the first red rule while it is blocked.
	_play_button.disabled = false
	if bool(r["ok"]):
		_play_button.text = "PLAY"
		_play_button.tooltip_text = "Play this deck"
		_play_button.modulate = Color.WHITE
	else:
		_play_button.text = "PLAY · %s" % String(r["errors"][0]["text"]).get_slice(" (", 0).to_upper()
		_play_button.tooltip_text = "Blocked: %s" % r["errors"][0]["text"]
		_play_button.modulate = Color(1, 1, 1, 0.55)
	_play_button.set_meta(&"blocked", not bool(r["ok"]))
	# Deck list.
	clear(_list_box)
	var picks: Array = deck["picks"]
	var sorted: Array = picks.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: CardData = DuelViews.card(StringName(str(a["card"])))
		var cb: CardData = DuelViews.card(StringName(str(b["card"])))
		if ca == null or cb == null:
			return false
		return ca.cost < cb.cost if ca.cost != cb.cost else ca.display_name < cb.display_name)
	for p: Dictionary in sorted:
		_list_box.add_child(W.deck_row(p, inspect_card, func(id: StringName) -> void: remove_card(id), open_trait_picker))
	for i: int in maxi(0, DuelViews.MAX_PICKS - picks.size()):
		_list_box.add_child(W.deck_row({}, Callable(), Callable()))
	deck_changed.emit()


func _doctrine_strip() -> Button:
	var t: StringName = StringName(str(deck.get("doctrine", "")))
	var b: Button = Button.new()
	b.name = "DoctrineStrip"
	b.theme_type_variation = &"PickTile"
	b.focus_mode = Control.FOCUS_ALL
	b.add_to_group(&"tap_target")
	b.custom_minimum_size = Vector2(0, 64)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)
	b.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	var tag: Label = W.label("DOCTRINE", &"HudTag", 16, W.MUTED)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tag)
	row.add_child(W.TraitPlate.new(t, 28))
	var nm: Label = W.label(SynergyGlyphs.trait_name(t) if t != &"" else ("None · tap to pick" if DuelViews.doctrine_optional() else "Pick a trait"), &"UnitName", 18, W.FOG if t != &"" else (W.AMBER if DuelViews.doctrine_optional() else W.RED))
	nm.name = "DoctrineName"
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.clip_text = true
	row.add_child(nm)
	b.tooltip_text = "Doctrine: +1 to one trait's count · tap: choose · hold / right click: the rule"
	b.pressed.connect(open_doctrine_picker)
	wire_inspect_button(b, func() -> void: inspector().open({"title": "Doctrine · %s" % (SynergyGlyphs.trait_name(t) if t != &"" else "none"),
			"type": "Deck trait", "text": DuelViews.doctrine_text(t), "keywords": [], "status": "Tap the strip to choose your deck's Doctrine."}))
	return b


# =============================================================================
# Pickers and sheets
# =============================================================================

## The hero picker: the 4 heroes as tiles (body, passive, ability, "Plays like", the unlock line).
func open_hero_picker() -> Dictionary:
	var s: Dictionary = W.sheet(self, "PICK A HERO · it waits in its own slot from round 1")
	s["root"].name = "HeroPicker"
	var body: VBoxContainer = s["body"]
	var grid: GridContainer = GridContainer.new()
	grid.name = "HeroGrid"
	grid.columns = 1 if portrait else 2
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	body.add_child(grid)
	for h: Dictionary in DuelViews.heroes():
		grid.add_child(_hero_tile(h, s))
	return s


func _hero_tile(h: Dictionary, s: Dictionary) -> Button:
	var b: Button = Button.new()
	b.name = "Hero_%s" % h["id"]
	b.theme_type_variation = &"PickTileSelected" if StringName(str(deck.get("hero", ""))) == h["id"] else &"PickTile"
	b.focus_mode = Control.FOCUS_ALL
	b.add_to_group(&"tap_target")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 2)
	b.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 10
	col.offset_top = 8
	col.offset_right = -10
	col.offset_bottom = -8
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var nm: Label = W.label("%s · FP %d / Armor %d" % [h["name"], h["fp"], h["armor"]], &"TileName", 20)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	if StringName(str(deck.get("hero", ""))) == h["id"]:
		head.add_child(W.status_chip("SELECTED", true))
	elif not bool(h["unlocked"]):
		var lk: HBoxContainer = HBoxContainer.new()
		lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lk.add_child(W.Mark.new(&"lock", W.RED, 18))
		lk.add_child(W.label("LOCKED", &"HudTag", 16, W.RED))
		head.add_child(lk)
	col.add_child(W.label(String(h["plays_like"]), &"HudAccent", 16))
	col.add_child(W.label("P · %s: %s" % [h["passive_name"], h["passive_text"]], &"", 16, Color(0, 0, 0, 0), true))
	col.add_child(W.label("1× · %s: %s" % [h["ability_name"], h["ability_text"]], &"", 16, Color(0, 0, 0, 0), true))
	if not bool(h["unlocked"]):
		col.add_child(W.label("Unlock: %s Presets and the AI can always use it." % h["unlock_text"], &"HudSubtle", 16, W.RED.lightened(0.3), true))
	col.minimum_size_changed.connect(func() -> void: b.custom_minimum_size.y = col.get_combined_minimum_size().y + 16.0)
	b.custom_minimum_size.y = 150
	b.pressed.connect(func() -> void:
		var r: Dictionary = set_hero(h["id"])
		if bool(r["ok"]):
			s["root"].queue_free()
		else:
			inspector().open(W.hero_info(h, String(r["text"]))))
	wire_inspect_button(b, func() -> void: inspector().open(W.hero_info(h)))
	b.tooltip_text = "%s · tap: pick · hold / right click: the full kit" % h["name"]
	return b


## The Doctrine picker: 4 traits, each with its rule (from the rules) and the deck's copies of it.
func open_doctrine_picker() -> Dictionary:
	var s: Dictionary = W.sheet(self, "PICK YOUR DOCTRINE · it starts one trait's set")
	var need: int = DuelViews.doctrine_min()
	s["root"].name = "DoctrinePicker"
	var body: VBoxContainer = s["body"]
	var comp: Dictionary = DuelViews.composition(deck)
	var main: StringName = DuelViews.main_trait(deck)
	var choices: Array[Dictionary] = DuelViews.doctrines()
	if DuelViews.doctrine_optional():
		choices.append({"id": &"", "name": "No Doctrine", "text": DuelViews.doctrine_text(&"")})
	for d: Dictionary in choices:
		var t: StringName = d["id"]
		var b: Button = Button.new()
		b.name = "Doctrine_%s" % (t if t != &"" else &"none")
		b.theme_type_variation = &"PickTileSelected" if StringName(str(deck.get("doctrine", ""))) == t else &"PickTile"
		b.focus_mode = Control.FOCUS_ALL
		b.add_to_group(&"tap_target")
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override(&"separation", 10)
		b.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10
		row.offset_right = -10
		row.offset_top = 6
		row.offset_bottom = -6
		row.add_child(W.TraitPlate.new(t, 40))
		var col: VBoxContainer = VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var copies: int = int(comp["traits"].get(t, 0))
		var wearing: int = copies / DuelViews.COPIES
		# kc-duel-impl (§12.3): a Doctrine needs `need` picks wearing its trait; under that it can't be picked.
		var short: bool = t != &"" and need > 0 and wearing < need
		b.disabled = short and StringName(str(deck.get("doctrine", ""))) != t
		col.add_child(W.label("%s · %d copies in your deck%s%s" % [d["name"], copies, " · your main trait" if t == main and copies > 0 else "",
				" · needs %d picks (%d/%d)" % [need, wearing, need] if short else ""], &"TileName", 18))
		col.add_child(W.label(String(d["text"]), &"", 16, Color(0, 0, 0, 0), true))
		col.minimum_size_changed.connect(func() -> void: b.custom_minimum_size.y = col.get_combined_minimum_size().y + 14.0)
		b.custom_minimum_size.y = 96
		b.pressed.connect(func() -> void:
			set_doctrine(t)
			s["root"].queue_free())
		wire_inspect_button(b, func() -> void: inspector().open({"title": "Doctrine · %s" % d["name"], "type": "Deck trait",
				"text": String(d["text"]), "keywords": [], "status": ""}))
		body.add_child(b)
	return s


## The art picker of a pick (and so its trait): the options, both copies take it.
func open_trait_picker(id: StringName) -> Dictionary:
	var c: CardData = DuelViews.card(id)
	if c == null or not c.has_trait_choice():
		return {}
	var s: Dictionary = W.sheet(self, "%s ×2 · CHOOSE THE ART (it gives the trait)" % c.display_name.to_upper())
	s["root"].name = "TraitPicker"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	s["body"].add_child(row)
	var now: StringName = &""
	for p: Dictionary in deck["picks"]:
		if StringName(str(p["card"])) == id:
			now = DuelViews.trait_of(p)
	var w: float = 150.0 if compact else 176.0
	if portrait:
		w = floorf((get_viewport_rect().size.x - 80.0) / maxf(1.0, c.trait_choices().size()))
	for t: StringName in c.trait_choices():
		var b: Button = Button.new()
		b.name = "Trait_%s" % t
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.add_to_group(&"tap_target")
		var cv: CardView = CodexView.make_card_view(CardView.view_for_card(c, DuelViews.art_for(c, t)), w)
		var csz: Vector2 = CardView.size_for(w)
		cv.size = csz
		b.add_child(cv)
		var l: Label = W.label(("%s · CHOSEN" if t == now else "%s") % ArtTraits.trait_name(t).to_upper(), &"HudTag", 16, W.TEAL if t == now else W.FOG)
		l.position = Vector2(4, csz.y + 4)
		b.add_child(l)
		b.custom_minimum_size = csz + Vector2(0, 30)
		b.pressed.connect(func() -> void:
			set_pick_trait(id, t)
			s["root"].queue_free())
		wire_inspect_button(b, func() -> void: inspector().open(W.card_info(c, DuelViews.art_for(c, t))))
		row.add_child(b)
	return s


func open_rename() -> Dictionary:
	var s: Dictionary = W.sheet(self, "RENAME THE DECK", "CANCEL", 620.0)
	s["root"].name = "Rename"
	var edit: LineEdit = LineEdit.new()
	edit.name = "NameEdit"
	edit.max_length = DuelViews.NAME_MAX
	edit.text = deck_name()
	edit.custom_minimum_size = Vector2(0, W.TAP)
	edit.add_theme_font_size_override(&"font_size", 22)
	s["body"].add_child(edit)
	s["body"].add_child(W.label("Up to %d letters." % DuelViews.NAME_MAX, &"HudSubtle", 16))
	var ok: Button = make_button("RENAME", &"ReadyButton", 200)
	ok.name = "RenameOk"
	ok.pressed.connect(func() -> void:
		set_deck_name(edit.text)
		s["root"].queue_free())
	edit.text_submitted.connect(func(_t: String) -> void: ok.pressed.emit())
	s["body"].add_child(ok)
	edit.grab_focus.call_deferred()
	return s


func _ask_leave() -> void:
	var s: Dictionary = W.sheet(self, "Save changes to %s?" % deck_name(), "CANCEL", 620.0)
	s["root"].name = "LeaveConfirm"
	_confirm = s
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	s["body"].add_child(row)
	var sv: Button = make_button("SAVE", &"ReadyButton", 160)
	sv.name = "LeaveSave"
	sv.pressed.connect(func() -> void:
		var r: Dictionary = save()
		if bool(r.get("ok", false)):
			goto(DuelFlow.builder_return))
	row.add_child(sv)
	var dc: Button = make_button("DISCARD", &"HudButton", 160)
	dc.name = "LeaveDiscard"
	dc.pressed.connect(func() -> void: goto(DuelFlow.builder_return))
	row.add_child(dc)


# =============================================================================
# Feedback (what just happened)
# =============================================================================

func _changed(text: String, can_undo: bool, id: StringName = &"", delta: int = 0) -> void:
	_auto_doctrine()
	_refill()
	_refresh_panel()
	_snackbar(text, can_undo)
	if delta != 0 and id != &"":
		_fly(id, delta)
	punch(_counter.get_parent() as Control)


func _refuse(id: StringName, text: String) -> void:
	_snackbar(text, false)
	_shake(get_tile(id))
	SfxBankScript.cue(&"block")


func _build_snackbar() -> void:
	_snack = PanelContainer.new()
	_snack.name = "Snackbar"
	_snack.theme_type_variation = &"ToastPanel"
	_snack.mouse_filter = Control.MOUSE_FILTER_STOP
	_snack.visible = false
	add_child(_snack)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	_snack.add_child(row)
	_snack_label = W.label("", &"HudHeader", 18, Color(0, 0, 0, 0), true)
	_snack_label.name = "SnackText"
	_snack_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_snack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_snack_label)
	_snack_undo = make_button("UNDO", &"HudButton", 110)
	_snack_undo.name = "UndoButton"
	_snack_undo.add_to_group(&"tap_target")
	_snack_undo.pressed.connect(func() -> void: undo_remove())
	row.add_child(_snack_undo)


func _snackbar(text: String, can_undo: bool) -> void:
	_last_text = text
	if _snack == null:
		return
	_snack_label.text = text
	_snack_undo.visible = can_undo
	_snack.show()
	_place_snack()
	_place_snack.call_deferred()
	_snack.modulate = Color(1.5, 1.4, 1.1, 1.0)
	if is_inside_tree():
		var tw: Tween = create_tween()
		tw.tween_property(_snack, "modulate", Color.WHITE, 0.3)
		_snack_id += 1
		var my_id: int = _snack_id
		get_tree().create_timer(SNACK_S).timeout.connect(func() -> void:
			if is_instance_valid(_snack) and my_id == _snack_id:
				_snack.hide()
				_undo = {})


## Bottom of the grid (landscape) or just above PLAY (portrait), never wider than the grid area.
func _place_snack() -> void:
	if _snack == null or not _snack.visible:
		return
	var origin: Vector2 = get_global_rect().position
	var area: Rect2 = Rect2(Vector2(16, 0), Vector2(size.x - 32.0, size.y - 16.0))
	if not portrait and _grid_scroll != null and _grid_scroll.is_inside_tree() and _grid_scroll.size.x > 100.0:
		area = Rect2(_grid_scroll.get_global_rect().position - origin, _grid_scroll.size)
	var bottom: float = area.end.y - 8.0
	if portrait and _play_button != null and _play_button.is_inside_tree() and _play_button.size.y > 0.0:
		bottom = _play_button.get_global_rect().position.y - origin.y - 8.0
	var w: float = minf(area.size.x, 640.0)
	_snack_label.custom_minimum_size.x = maxf(120.0, w - (140.0 if _snack_undo.visible else 30.0))
	_snack.size = Vector2.ZERO
	_snack.reset_size()
	_snack.size.x = w
	_snack.position = Vector2(area.position.x, bottom - _snack.size.y)


## The last "what just happened" line (also while the snackbar is hidden).
func last_feedback() -> String:
	return _last_text


## "+2" / "−2" flies from the tile to the counter (juice; skipped with reduced motion).
func _fly(id: StringName, delta: int) -> void:
	var st: Node = get_node_or_null(^"/root/Settings")
	if st != null and bool(st.get(&"reduced_motion")):
		return
	var t: Button = get_tile(id)
	if t == null or not t.is_inside_tree() or _counter == null or not _counter.is_inside_tree():
		return
	var chip: Label = W.label("+2" if delta > 0 else "−2", &"HudNumber", 26, W.TEAL if delta > 0 else W.RED)  # kc-da-ui2: picks are teal, never amber
	chip.name = "FlyChip"
	add_child(chip)
	var origin: Vector2 = get_global_rect().position
	chip.position = t.get_global_rect().get_center() - origin
	var dest: Vector2 = _counter.get_global_rect().get_center() - origin
	var tw: Tween = create_tween()
	tw.tween_property(chip, "position", dest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(chip, "modulate:a", 0.2, 0.35)
	tw.tween_callback(chip.queue_free)


func _shake(c: Control) -> void:
	if c == null or not c.is_inside_tree():
		return
	var x: float = c.position.x
	var tw: Tween = create_tween()
	for dx: float in [8.0, -8.0, 5.0, -3.0, 0.0]:
		tw.tween_property(c, "position:x", x + dx, 0.04)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not _has_sheet():
		get_viewport().set_input_as_handled()
		back()


func _has_sheet() -> bool:
	for c: Node in get_children():
		if c.name.begins_with("Sheet") or c is Control and c.get_child_count() > 0 and String(c.name) in ["HeroPicker", "DoctrinePicker", "TraitPicker", "Rename", "LeaveConfirm"]:
			return true
	var insp: Control = _v2_inspector
	return insp != null and insp.visible


const SfxBankScript: GDScript = preload("res://scripts/fx/sfx_bank.gd")
const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")


## The inspector always opens over the sheets (hero / Doctrine / art pickers).
func inspector() -> Control:
	var insp: Control = super()
	move_child(insp, get_child_count() - 1)
	return insp

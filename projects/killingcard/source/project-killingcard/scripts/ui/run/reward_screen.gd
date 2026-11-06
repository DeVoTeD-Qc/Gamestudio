# reward_screen.gd
# Purpose: Reward offers between matches (p11, scenes/run/Reward.tscn). Shows RunState's current
#   offer and resolves it with one tap, then the next offer (same screen) or the run map:
#   - Supply Drop (after a win): RunConfig.supply_drop_choices cards as CardView (fed by
#     card_info.view_dict) with a readable rules line under each. Tap a card to add it to the
#     deck. DETAILS opens the card inspector (full rules and keywords) without choosing.
#   - Weapon level: attachments for the Primary (stat changes, keywords, rules text).
#   - Perk offer: Perks you don't own (slots used / total in the subtitle).
#   SKIP declines any offer. Each offer announces EventBus.screen_shown(&"reward_<kind>").
#   kc-trait-ui (art-traits.md §2.2, the head's 2026-11-06 direction): every Supply Drop card is a
#   concrete copy: "MARKSMAN · [icon] HEAVY" over its own art, "HEAVY 3 > 4", the on-trait slot
#   marked (the art's subname is in DETAILS only). Next to RETIRE: RE-ISSUE (also on Regroup, header
#   button): pick a Trained copy, then another of its trait options (preview: now -> after, counts),
#   it comes with a RANDOM art of that trait. Promotion of a Recruit and twin training (Retire a
#   Recruit with a twin) open the TRAIN AS picker (run.train_choices): one tile per trait option
#   with its icon, the pre-selected one marked, "Heavy 2 > 3: bonus ON", "you'll get a random Heavy
#   art"; the tap commits (RunState.choose_offer(i, trait) / retire_card(i, twin_trait)).
#   Phone: cards scale 0.8-1.3x to the room left (>= 0.8x keeps name / cost / stats >= 11 pt).
# Dependencies: run_screen.gd, pick_tile.gd, CardView.tscn, CardInspector.tscn, card_info.gd,
#   RunState, RunFlow, RewardOffers.
# Author: UI/UX Agent (p11)
extends "res://scripts/ui/run/run_screen.gd"

const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")
const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/match/CardView.tscn")
const INSPECTOR_SCENE: PackedScene = preload("res://scenes/match/CardInspector.tscn")
const MIN_CARD_SCALE: float = 0.8
const MAX_CARD_SCALE: float = 1.3
## Perk patch texture width (px) on a Perk offer tile.
const PERK_PATCH_PX: int = 320
const KIND_TITLES: Dictionary = {
	RewardOffers.KIND_SUPPLY_DROP: "SUPPLY DROP",
	RewardOffers.KIND_ATTACHMENT: "WEAPON LEVEL",
	RewardOffers.KIND_PERK: "PERK OFFER",
	RewardOffers.KIND_DOCTRINE: "DOCTRINE",
	RewardOffers.KIND_PROMOTION: "PROMOTION",
	RewardOffers.KIND_REGROUP: "REGROUP",
}
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
const EnginePanel: GDScript = preload("res://scripts/ui/run/engine_panel.gd")
## kc-syn-ui: width of the Supply Drop's 4th tile (Retire a card).
const RETIRE_TILE_W: float = 210.0

## The offer on screen ({kind, match, options}); {} when none.
var offer: Dictionary = {}
## Option tiles in offer order (PickTile).
var tiles: Array[PickTile] = []
var detail_buttons: Array[Button] = []
## CardView per Supply Drop option.
var card_views: Array[Control] = []

var _skip_button: Button = null
var _options: HBoxContainer = null
var _inspector: Control = null
var _card_holders: Array[Control] = []
var _rules_labels: Array[Label] = []
## kc-syn-ui: the Supply Drop's 4th option (null when the offer has none), the list tiles of a
## Promotion / Retire pick (option order = the RunProgress list), the Retire picker state and the
## deck view.
var retire_tile: PickTile = null
var list_tiles: Array[PickTile] = []
var retire_mode: bool = false
var _list_scroll: ScrollContainer = null
var _list_grid: GridContainer = null
var _center: CenterContainer = null
var _deck_button: Button = null
var _engine: Control = null
var _trait_lines: bool = false
## kc-trait-ui: the Supply Drop's Re-issue option tile (null when the offer has none), the Re-issue
## flow (reissue_mode; reissue_row = the picked reissue_options() row, -1 = pick a copy), the TRAIN
## AS picker (train_pick = {kind: &"promote" / &"twin", option, copy, id}; {} = closed) and its
## tiles (pick_tiles, in run.train_choices / reissue options order).
var reissue_tile: PickTile = null
var reissue_mode: bool = false
var reissue_row: int = -1
var train_pick: Dictionary = {}
var pick_tiles: Array[PickTile] = []
var _reissue_button: Button = null

@onready var _header: HBoxContainer = %Header
@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _body: MarginContainer = %Body


func backdrop_key() -> StringName:
	return &"supply_drop"


func screen_id() -> StringName:
	return StringName("reward_" + String(offer.get("kind", "none")))


func _build() -> void:
	_skip_button = make_button("SKIP", &"HudButton", 140)
	_skip_button.name = "SkipButton"
	_skip_button.pressed.connect(skip)
	_header.add_child(_skip_button)
	# kc-syn-ui: DECK opens the deck view (Engine panel) from any offer.
	_deck_button = make_button("DECK", &"HudButton", 120)
	_deck_button.name = "DeckButton"
	_deck_button.pressed.connect(open_deck)
	_header.add_child(_deck_button)
	_header.move_child(_deck_button, _skip_button.get_index())
	# kc-trait-ui: Regroup's Re-issue (the Supply Drop has a tile next to Retire instead).
	_reissue_button = make_button("RE-ISSUE", &"HudButton", 150)
	_reissue_button.name = "ReissueButton"
	_reissue_button.tooltip_text = "Change one Trained card to another of its traits (instead of retiring one)"
	_reissue_button.pressed.connect(open_reissue)
	_header.add_child(_reissue_button)
	_header.move_child(_reissue_button, _deck_button.get_index())
	var center: CenterContainer = CenterContainer.new()
	_center = center
	_body.add_child(center)
	_options = HBoxContainer.new()
	_options.name = "Options"
	_options.add_theme_constant_override(&"separation", 16)
	center.add_child(_options)
	_list_scroll = ScrollContainer.new()
	_list_scroll.name = "ListScroll"
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.visible = false
	_body.add_child(_list_scroll)
	_list_grid = GridContainer.new()
	_list_grid.name = "ListGrid"
	_list_grid.columns = 3
	_list_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_grid.add_theme_constant_override(&"h_separation", 12)
	_list_grid.add_theme_constant_override(&"v_separation", 10)
	_list_scroll.add_child(_list_grid)
	_header.resized.connect(_fit_cards)
	_engine = EnginePanel.new()
	_engine.name = "EngineView"
	add_child(_engine)
	_engine.row_inspected.connect(_inspect_card_id)
	_inspector = INSPECTOR_SCENE.instantiate()
	add_child(_inspector)
	resized.connect(_fit_cards)
	resized.connect(_fit_list)
	show_offer()


func _apply_compact() -> void:
	if _skip_button != null:
		_skip_button.custom_minimum_size.y = button_height()
	_fit_cards()
	_fit_list()


## Rebuilds the options for RunState's current offer.
func show_offer() -> void:
	var r: RunProgress = run()
	offer = r.current_offer() if r != null else {}
	clear(_options)
	tiles.clear()
	detail_buttons.clear()
	card_views.clear()
	_card_holders.clear()
	_rules_labels.clear()
	retire_tile = null
	reissue_tile = null
	list_tiles.clear()
	pick_tiles.clear()
	clear(_list_grid)
	_trait_lines = false
	_center.visible = true
	_list_scroll.visible = false
	if _reissue_button != null:
		_reissue_button.visible = false
	if offer.is_empty():
		_title.text = "NO REWARD"
		_subtitle.text = ""
		_skip_button.text = "CONTINUE"
		return
	var kind: StringName = offer["kind"]
	var pending: int = r.pending_offers.size()
	_title.text = String(KIND_TITLES.get(kind, "REWARD"))
	if pending > 1:
		_title.text += "  ·  1 OF %d REWARDS" % pending
	_skip_button.text = "SKIP"
	match kind:
		RewardOffers.KIND_SUPPLY_DROP:
			_subtitle.text = "Tap a card to add it to your deck (%d cards now)." % r.deck.size()
		RewardOffers.KIND_ATTACHMENT:
			var primary: String = RunFlow.names_of(r, [r.primary], "your weapon")
			_subtitle.text = "%s levelled up to level %d. Tap an attachment to fit it. Fitted: %s." % [
					primary, r.weapon_level + 1, RunFlow.names_of(r, r.attachments)]
		RewardOffers.KIND_PERK:
			_subtitle.text = "Tap a Perk to take it. Perk slots: %d of %d used (%s)." % [
					r.perks.size(), r.config.perk_slots, RunFlow.names_of(r, r.perks)]
		RewardOffers.KIND_DOCTRINE:
			_subtitle.text = "Pick a trait: its sets count +1 for the rest of the run."
		RewardOffers.KIND_PROMOTION:
			_subtitle.text = "Tap a card to promote one copy by one level."
		RewardOffers.KIND_REGROUP:
			_subtitle.text = "After a loss: retire one card for free (deck %d, floor %d)." % [r.deck.size(), r.config.deck_floor]
	_skip_button.text = "SKIP"
	if not train_pick.is_empty():
		_build_train_picker(r)
		_announce()
		return
	if reissue_mode:
		_build_reissue(r)
		_announce()
		return
	if kind == RewardOffers.KIND_REGROUP and bool(offer.get("reissue", false)):
		_reissue_button.visible = true
	if retire_mode or kind == RewardOffers.KIND_REGROUP:
		_build_retire_list(r, kind == RewardOffers.KIND_SUPPLY_DROP)
		_announce()
		return
	if kind == RewardOffers.KIND_PROMOTION:
		_build_promotion_list(r)
		_announce()
		return
	var options: Array = offer["options"]
	for i: int in options.size():
		if kind == RewardOffers.KIND_DOCTRINE:
			var dt: PickTile = _doctrine_tile(r, StringName(options[i]))
			dt.name = "Option%d" % i
			dt.pressed.connect(choose.bind(i))
			_options.add_child(dt)
			tiles.append(dt)
			continue
		var res: Resource = r.resource(StringName(options[i]))
		var tile: PickTile = _card_tile(res as CardData, offer_art(r, i) if kind == RewardOffers.KIND_SUPPLY_DROP else &"") if res is CardData else _item_tile(res as LoadoutItem)
		tile.name = "Option%d" % i
		tile.pressed.connect(choose.bind(i))
		_options.add_child(tile)
		tiles.append(tile)
	if kind == RewardOffers.KIND_SUPPLY_DROP:
		_mark_trait_lines(r)
		if bool(offer.get("retire", false)) or bool(offer.get("reissue", false)):
			# kc-trait-ui: Retire and Re-issue share the 4th column (two half-height tiles).
			var pivot := VBoxContainer.new()
			pivot.name = "PivotColumn"
			pivot.add_theme_constant_override(&"separation", 8)
			_options.add_child(pivot)
			if bool(offer.get("retire", false)):
				retire_tile = _retire_option_tile(r)
				retire_tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
				pivot.add_child(retire_tile)
			if bool(offer.get("reissue", false)):
				reissue_tile = _reissue_option_tile(r)
				reissue_tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
				pivot.add_child(reissue_tile)
	_fit_cards()
	# Keyboard / controller start on the first option; on touch screens a focus frame on one
	# option would read as "already picked".
	if not tiles.is_empty() and not DisplayServer.is_touchscreen_available():
		tiles[0].grab_focus.call_deferred()
	_announce()


func _announce() -> void:
	var bus: Node = RunFlow.event_bus()
	if bus != null and is_node_ready():
		bus.screen_shown.emit(screen_id())


# =============================================================================
# kc-syn-ui: Doctrine, Promotion, Retire / Regroup, on-trait slot, deck view
# =============================================================================

## DECK: the deck view with the Engine panel.
func open_deck() -> void:
	_engine.open(run())


func get_engine_view() -> Control:
	return _engine


func _inspect_card_id(id: StringName, level: int) -> void:
	var card: CardData = run().resource(id) as CardData
	if card == null:
		return
	_inspector.open({"view": CardInfo.view_dict(card), "title": card.display_name, "type": CardInfo.type_line(card),
			"text": card.text, "keywords": CardInfo.keywords(card) + _syn_lines(card, level), "status": "Copy level: %s." % SynergyGlyphs.level_name(level)})


## Keyword / trait lines for the inspector (what this copy has at `level`).
func _syn_lines(card: CardData, level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var kw: StringName = card.neighbor_keyword
	if kw != &"":
		out.append({"name": "%s (neighbour keyword)%s" % [SynergyGlyphs.keyword_name(kw), "" if level >= 1 else ": once Trained"],
				"text": String(SynergyRules.KEYWORD_TEXT[kw])})
	var t: StringName = card.card_trait
	if t != &"":
		out.append({"name": "%s (trait)%s" % [SynergyGlyphs.trait_name(t), "" if level >= 1 else ": once Trained"],
				"text": "2 in play: %s. 3 in play: %s." % [SynergyRules.TIER_TEXT[t][0], SynergyRules.TIER_TEXT[t][1]]})
	return out


## kc-trait-ui: the trait Supply Drop option `i` comes with (its art's: offer["traits"][i]).
func offer_trait(r: RunProgress, i: int) -> StringName:
	var card: CardData = r.resource(StringName(offer["options"][i])) as CardData
	var traits: Array = offer.get("traits", [])
	if card == null:
		return &""
	return StringName(traits[i]) if i < traits.size() else card.card_trait


## kc-trait-ui: the art Supply Drop option `i` comes with (offer["arts"][i]; the card id if none).
func offer_art(r: RunProgress, i: int) -> StringName:
	var arts: Array = offer.get("arts", [])
	return StringName(arts[i]) if i < arts.size() and StringName(arts[i]) != &"" else StringName(offer["options"][i])


## Supply Drop: each option is a concrete copy: a head line "MARKSMAN · [icon] HEAVY" and what it does
## to your engine ("HEAVY 3 > 4"); slot 1 on your main trait is marked ON-TRAIT. The art's subname is
## in DETAILS (head: no subname on cards).
func _mark_trait_lines(r: RunProgress) -> void:
	var counts: Dictionary = r.trait_counts()
	var on_trait: StringName = StringName(offer.get("on_trait", &""))
	for i: int in tiles.size():
		var card: CardData = r.resource(StringName(offer["options"][i])) as CardData
		if card == null or not card.is_unit():
			continue
		var t: StringName = offer_trait(r, i)
		var line2: String = ""
		if t != &"":
			line2 = count_text(t, int(counts.get(t, 0)), int(counts.get(t, 0)) + 1, true)
		elif card.has_trait_choice():
			line2 = "NO TRAIT (plain art)"
		if line2 == "":
			continue
		var on: bool = i == 0 and on_trait != &"" and t == on_trait
		if on:
			line2 = "ON-TRAIT · " + line2
			tiles[i].set_meta(&"on_trait", true)
		tiles[i].set_meta(&"trait", t)
		# One line (the CardView under it names the card): [icon] ON-TRAIT · HEAVY 3 > 4: BONUS ON.
		var head: Control = _trait_head(line2.to_upper(), "", t, on)
		head.tooltip_text = "%s · %s" % [card.display_name, line2]
		head.name = "TraitLine"
		tiles[i].content.add_child(head)
		tiles[i].content.move_child(head, 0)
		_trait_lines = true


## "Heavy 2 > 3: bonus ON" / "Vanguard 0 > 1 (bonus at 2)" / "Heavy 3 > 4 (full set)" for a trait
## count going from `from` to `to` Trained copies in the deck. `short` (Supply Drop tiles): only
## "Heavy 2 > 3", plus ": bonus ON" / ": bonus OFF" when a bonus switches.
static func count_text(t: StringName, from: int, to: int, short: bool = false) -> String:
	if t == &"":
		return "No trait: joins no set"
	var name: String = ArtTraits.trait_name(t)
	var tf: int = SynergyRules.active_tier(t, from)
	var tt: int = SynergyRules.active_tier(t, to)
	if tt > tf:
		return "%s %d > %d: bonus ON" % [name, from, to]
	if tt < tf:
		return "%s %d > %d: bonus OFF" % [name, from, to]
	if short or to < from:
		return "%s %d > %d" % [name, from, to]
	var nxt: int = SynergyRules.next_tier(t, tt)
	return ("%s %d > %d (%sbonus at %d)" % [name, from, to, "" if tt == 0 else "next ", nxt]) if nxt > 0 else "%s %d > %d (full set)" % [name, from, to]


## A tile head: [trait plate] over two lines (name · trait, the count change), tinted by the trait.
func _trait_head(line1: String, line2: String, t: StringName, on: bool = false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := Control.new()
	icon.name = "TraitIcon"
	icon.custom_minimum_size = Vector2(22, 22)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_meta(&"trait", t)
	icon.draw.connect(func() -> void:
		var rr: Rect2 = Rect2(Vector2.ZERO, icon.size)
		if t != &"":
			SynergyGlyphs.draw_trait_plate(icon, rr, t, on, false)
		else:
			BannerView._dashed_rect(icon, rr.grow(-1.0), Color(1, 1, 1, 0.45), 1.0))
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var l1: Label = make_label(line1, &"HudTag")
	l1.name = "NameTrait"
	l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l1.clip_text = true
	l1.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(l1)
	if line2 == "" and t != &"":
		l1.add_theme_color_override(&"font_color", SynergyGlyphs.trait_color(t))
	if line2 != "":
		var l2: Label = make_label(line2.to_upper(), &"HudTag")
		l2.name = "CountLine"
		l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l2.clip_text = true
		l2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l2.add_theme_color_override(&"font_color", SynergyGlyphs.trait_color(t) if t != &"" else Color("#B9C2C9"))
		col.add_child(l2)
	return row


## The Supply Drop's 4th option: Retire a card instead of taking one (greyed at the floor).
func _retire_option_tile(r: RunProgress) -> PickTile:
	var tile: PickTile = make_tile()
	tile.name = "RetireOption"
	tile.custom_minimum_size.x = RETIRE_TILE_W
	tile.min_height = 96 if bool(offer.get("reissue", false)) else 200
	tile.add_line("RETIRE", &"TileName")
	tile.add_line("INSTEAD OF A CARD", &"HudTag", false)
	var ok: bool = r.can_retire()
	var why: Label = tile.add_line("Remove one card for good (deck %d > %d). A Recruit's twin trains for free." % [r.deck.size(), r.deck.size() - 1] if ok \
			else "Your deck is at the %d-card floor: nothing can be retired." % r.config.deck_floor)
	why.name = "RetireText"
	tile.add_spacer()
	tile.add_status("TAP TO PICK A CARD" if ok else "AT THE FLOOR")
	tile.disabled = not ok
	tile.pressed.connect(open_retire_picker)
	return tile


## kc-trait-ui: the Supply Drop's Re-issue option (under Retire): change a Trained copy's trait.
func _reissue_option_tile(r: RunProgress) -> PickTile:
	var tile: PickTile = make_tile()
	tile.name = "ReissueOption"
	tile.custom_minimum_size.x = RETIRE_TILE_W
	tile.min_height = 96
	tile.add_line("RE-ISSUE", &"TileName")
	tile.add_line("INSTEAD OF A CARD", &"HudTag", false)
	var n: int = r.reissue_options().size()
	tile.add_line("Switch one Trained card to another trait (a random art of it)." if n > 0 \
			else "No Trained card with another trait option yet.")
	tile.add_spacer()
	tile.add_status("TAP TO PICK A CARD" if n > 0 else "NOTHING TO RE-ISSUE")
	tile.disabled = n == 0
	tile.pressed.connect(open_reissue)
	return tile


## RE-ISSUE (Supply Drop tile / Regroup header button): the copies you can re-issue.
func open_reissue() -> void:
	var r: RunProgress = run()
	if r == null or not bool(offer.get("reissue", false)):
		return
	reissue_mode = true
	reissue_row = -1
	show_offer()


## Re-issue step 1 (pick a copy) or step 2 (pick its new trait, with the now -> after preview).
func _build_reissue(r: RunProgress) -> void:
	_center.visible = false
	_list_scroll.visible = true
	_skip_button.text = "BACK"
	var rows: Array[Dictionary] = r.reissue_options()
	var counts: Dictionary = r.trait_counts()
	if reissue_row < 0 or reissue_row >= rows.size():
		reissue_row = -1
		_title.text = "RE-ISSUE A CARD"
		_subtitle.text = "Pick a Trained card to switch to another trait. It keeps its level and gets a random art of the new trait. BACK: the offer."
		if rows.is_empty():
			var t0: PickTile = make_tile()
			t0.add_line("NOTHING TO RE-ISSUE", &"TileName")
			t0.add_line("Only Trained copies of cards with two or more trait options can be re-issued (Recruits pick when they train).")
			t0.disabled = true
			_list_grid.add_child(t0)
		for i: int in rows.size():
			var row: Dictionary = rows[i]
			var card: CardData = r.resource(row["id"]) as CardData
			var tile: PickTile = make_tile()
			tile.name = "Reissue%d" % i
			tile.min_height = 96
			var t: StringName = StringName(row["trait"])
			tile.content.add_child(_trait_head("%s · %s" % [card.display_name.to_upper(), ArtTraits.trait_name(t).to_upper()],
					"%s · %s now" % [SynergyGlyphs.level_name(int(row["level"])), ArtTraits.trait_name(t)], t, false))
			var names: PackedStringArray = []
			for o: Dictionary in row["options"]:
				names.append(String(o["name"]))
			tile.add_line("Can become: %s." % " or ".join(names))
			_add_band_strip(tile, int(row["level"]), -1)
			tile.pressed.connect(func() -> void:
				reissue_row = i
				show_offer())
			_list_grid.add_child(tile)
			list_tiles.append(tile)
		_fit_list()
		return
	var row2: Dictionary = rows[reissue_row]
	var card2: CardData = r.resource(row2["id"]) as CardData
	var now_t: StringName = StringName(row2["trait"])
	_title.text = "RE-ISSUE %s" % card2.display_name.to_upper()
	_subtitle.text = "Pick its new trait. It keeps its level (%s); the art decides the trait, so it gets a random art of the new trait. BACK: the cards." % \
			SynergyGlyphs.level_name(int(row2["level"]))
	# NOW: the copy as it is.
	var now_tile: PickTile = make_tile()
	now_tile.name = "ReissueNow"
	now_tile.min_height = 96
	now_tile.disabled = true
	now_tile.add_line("NOW", &"HudTag", false)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(200, 64)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	now_tile.content.add_child(holder)
	var prev: PanelContainer = BannerCard.build(BannerCard.entry_for_card(card2, StringName(row2["art"]), int(row2["level"]), now_t), Vector2(200, 64), 57.0)
	prev.name = "NowCard"
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(prev)
	prev.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	now_tile.content.add_child(_trait_head(ArtTraits.trait_name(now_t).to_upper(), "", now_t, false))
	_list_grid.add_child(now_tile)
	for o: Dictionary in row2["options"]:
		var t2: StringName = StringName(o["trait"])
		var tile2: PickTile = make_tile()
		tile2.name = "ReissueAs_%s" % (String(t2) if t2 != &"" else "plain")
		tile2.min_height = 96
		tile2.set_meta(&"trait", t2)
		var lose: String = count_text(now_t, int(counts.get(now_t, 0)), maxi(0, int(counts.get(now_t, 0)) - 1)) if now_t != &"" else ""
		var gain: String = count_text(t2, int(counts.get(t2, 0)), int(counts.get(t2, 0)) + 1)
		tile2.content.add_child(_trait_head("RE-ISSUE AS %s" % ArtTraits.trait_name(t2).to_upper(), gain, t2, false))
		if lose != "":
			var ll: Label = tile2.add_line(lose.to_upper(), &"HudTag", false)
			ll.name = "LoseLine"
		var rl: Label = tile2.add_line("You'll get a random %s art." % ArtTraits.trait_name(t2) if t2 != &"" else "You'll get a random plain art.", &"FriendlyLabel")
		rl.name = "RandomArtLine"
		tile2.add_spacer()
		tile2.add_status("TAP TO RE-ISSUE")
		tile2.pressed.connect(reissue.bind(reissue_row, t2))
		_list_grid.add_child(tile2)
		pick_tiles.append(tile2)
	_fit_list()


## Re-issue row `row` of RunProgress.reissue_options() as `t`. Returns "" or RunState's reason.
func reissue(row: int, t: StringName) -> String:
	var err: String = RunFlow.run_state().reissue_card(row, t)
	if err == "":
		reissue_mode = false
		reissue_row = -1
		_next.call_deferred()
	return err


## kc-trait-ui: TRAIN AS: one tile per trait option of the copy (run.train_choices), the
## pre-selected one marked, the count change and "you'll get a random X art".
func _build_train_picker(r: RunProgress) -> void:
	_center.visible = false
	_list_scroll.visible = true
	_skip_button.text = "BACK"
	var card: CardData = r.resource(StringName(train_pick["id"])) as CardData
	var twin: bool = train_pick["kind"] == &"twin"
	_title.text = ("TWIN TRAINS AS" if twin else "TRAIN AS") + " · " + card.display_name.to_upper()
	_subtitle.text = ("Retiring the Recruit trains its twin. " if twin else "Recruit > Trained. ") + \
			"Pick its trait: the art decides it, so it gets a random art of that trait. BACK: the list."
	var choices: Array[Dictionary] = r.train_choices(int(train_pick["copy"]))
	for c: Dictionary in choices:
		var t: StringName = StringName(c["trait"])
		var tile: PickTile = make_tile()
		tile.name = "TrainAs_%s" % (String(t) if t != &"" else "plain")
		tile.min_height = 120
		tile.set_meta(&"trait", t)
		tile.set_meta(&"preselected", bool(c["preselected"]))
		tile.content.add_child(_trait_head(ArtTraits.trait_name(t).to_upper(), count_text(t, int(c["count_from"]), int(c["count_to"])), t, bool(c["preselected"])))
		if bool(c["preselected"]):
			var pl: Label = tile.add_line("PRE-SELECTED (its art)", &"HudAccent", false)
			pl.name = "PreselectedLine"
		if t != &"":
			var tb: Array = SynergyRules.TIER_TEXT.get(t, ["", ""])
			tile.add_line("2: %s. 3: %s." % [tb[0], tb[1]])
		var rl: Label = tile.add_line(("You'll get a random %s art." % ArtTraits.trait_name(t) if t != &"" else "You'll get a random plain art.") \
				if bool(c.get("random", false)) else "Keeps its art (it already gives this).", &"FriendlyLabel")
		rl.name = "RandomArtLine"
		tile.add_spacer()
		tile.add_status("TAP TO TRAIN")
		tile.pressed.connect(train_as.bind(t))
		_list_grid.add_child(tile)
		pick_tiles.append(tile)
	_fit_list()


## Commits the TRAIN AS pick: Promotion -> choose_offer(option, t); twin -> retire_card(option, t).
func train_as(t: StringName) -> String:
	if train_pick.is_empty():
		return "no training open"
	var err: String = ""
	if train_pick["kind"] == &"twin":
		err = RunFlow.run_state().retire_card(int(train_pick["option"]), t)
	else:
		err = RunFlow.run_state().choose_offer(int(train_pick["option"]), t)
	if err == "":
		train_pick = {}
		retire_mode = false
		_next.call_deferred()
	return err


## A Promotion tile: a Recruit with more than one trait option opens TRAIN AS; others promote now.
func _on_promote(i: int) -> void:
	var r: RunProgress = run()
	var opts: Array[Dictionary] = r.promotion_options()
	if i < opts.size() and bool(opts[i]["trains"]) and (r.resource(opts[i]["id"]) as CardData).trait_choices().size() > 1:
		train_pick = {"kind": &"promote", "option": i, "copy": int(opts[i]["index"]), "id": opts[i]["id"]}
		show_offer()
		return
	choose(i)


## A Retire tile: a Recruit whose twin will train (and can pick a trait) opens TRAIN AS for the twin.
func _on_retire(i: int) -> void:
	var r: RunProgress = run()
	var opts: Array[Dictionary] = r.retire_options()
	if i < opts.size() and int(opts[i]["twin_index"]) >= 0:
		var card: CardData = r.resource(opts[i]["id"]) as CardData
		if card != null and card.trait_choices().size() > 1:
			train_pick = {"kind": &"twin", "option": i, "copy": int(opts[i]["twin_index"]), "id": opts[i]["id"]}
			show_offer()
			return
	retire(i)


## Supply Drop > RETIRE: the list of cards to retire (BACK returns to the three cards).
func open_retire_picker() -> void:
	var r: RunProgress = run()
	if r == null or not r.can_retire():
		return
	retire_mode = true
	show_offer()


## Retire list (Supply Drop 4th option or Regroup): one tile per design and level, Recruits
## first, with what retiring it does (twin training, Honor Roll).
func _build_retire_list(r: RunProgress, from_drop: bool) -> void:
	_center.visible = false
	_list_scroll.visible = true
	_title.text = "RETIRE A CARD" if from_drop else _title.text
	if from_drop:
		_subtitle.text = "Pick the card to retire (deck %d, floor %d). BACK: the cards." % [r.deck.size(), r.config.deck_floor]
		_skip_button.text = "BACK"
	var opts: Array[Dictionary] = r.retire_options()
	if opts.is_empty():
		var t0: PickTile = make_tile()
		t0.add_line("AT THE FLOOR", &"TileName")
		t0.add_line("Your deck is at %d cards, the floor. Nothing can be retired." % r.config.deck_floor)
		t0.disabled = true
		_list_grid.add_child(t0)
		_fit_list()
		return
	for i: int in opts.size():
		var o: Dictionary = opts[i]
		var card: CardData = r.resource(o["id"]) as CardData
		var tile: PickTile = make_tile()
		tile.name = "Retire%d" % i
		tile.min_height = 96
		tile.add_line(card.display_name.to_upper() if card != null else String(o["id"]), &"TileName")
		var lv: int = int(o["level"])
		var tag: String = "%s · COST %d" % [SynergyGlyphs.level_name(lv).to_upper() if (card != null and (card.card_trait != &"" or card.neighbor_keyword != &"")) or lv >= 2 else "PLAIN", int(o["cost"])]
		if StringName(o["trait"]) != &"":
			tag += " · " + SynergyGlyphs.trait_name(o["trait"]).to_upper()
		tile.add_line(tag, &"HudTag", false)
		if int(o["twin_index"]) >= 0:
			var gains: PackedStringArray = []
			if card.neighbor_keyword != &"":
				gains.append(SynergyGlyphs.keyword_name(card.neighbor_keyword))
			if card.trait_choices().size() > 1:
				gains.append("a trait you pick next")
			elif card.card_trait != &"":
				gains.append(SynergyGlyphs.trait_name(card.card_trait))
			var tw: Label = tile.add_line("TWIN TRAINED: %s > GILDED (gains %s)" % [card.display_name, " and ".join(gains)], &"FriendlyLabel")
			tw.name = "TwinLine"
		else:
			tile.add_line("Removed from the deck (Honor Roll).")
		_add_band_strip(tile, lv, 1 if int(o["twin_index"]) >= 0 else -1)
		tile.pressed.connect(_on_retire.bind(i))
		_list_grid.add_child(tile)
		list_tiles.append(tile)
	_fit_list()


## Retire option i of RunProgress.retire_options(). Returns "" or RunState's reason.
func retire(i: int) -> String:
	var err: String = RunFlow.run_state().retire_card(i)
	if err == "":
		retire_mode = false
		_next.call_deferred()
	return err


## Promotion: one tile per design and level below Elite: the band now > next, and what it gains.
func _build_promotion_list(r: RunProgress) -> void:
	_center.visible = false
	_list_scroll.visible = true
	var options: Array = offer["options"]
	var levels: Array = offer.get("levels", [])
	for i: int in options.size():
		var card: CardData = r.resource(StringName(options[i])) as CardData
		var lv: int = int(levels[i]) if i < levels.size() else 1
		var tile: PickTile = make_tile()
		tile.name = "Promote%d" % i
		tile.min_height = 96
		tile.add_line(card.display_name.to_upper() if card != null else String(options[i]), &"TileName")
		tile.add_line("%s > %s · %s" % [SynergyGlyphs.level_name(lv).to_upper(), SynergyGlyphs.level_name(lv + 1).to_upper(),
				String(SynergyGlyphs.BAND_NAMES.get(SynergyGlyphs.band_of(lv + 1), "")).to_upper()], &"HudTag", false)
		var gain: String = ""
		match lv + 1:
			SynergyRules.LEVEL_TRAINED:
				var bits: PackedStringArray = []
				if card.neighbor_keyword != &"":
					bits.append(SynergyGlyphs.keyword_name(card.neighbor_keyword))
				if card.trait_choices().size() > 1:
					bits.append("a trait (pick next: %s)" % " / ".join(PackedStringArray(card.trait_choices().map(func(x: StringName) -> String: return ArtTraits.trait_name(x)))))
				elif card.card_trait != &"":
					bits.append(SynergyGlyphs.trait_name(card.card_trait))
				gain = "Gains %s." % " and ".join(bits) if not bits.is_empty() else "Trained."
			SynergyRules.LEVEL_VETERAN:
				gain = "+1 Armor (%d > %d)." % [card.armor, card.armor + 1] if card.is_unit() else "+1 Armor."
			SynergyRules.LEVEL_ELITE:
				gain = "+1 FP (%d > %d)." % [card.firepower, card.firepower + 1] if card.is_unit() else "+1 FP."
		var gl: Label = tile.add_line(gain, &"FriendlyLabel")
		gl.name = "GainLine"
		_add_band_strip(tile, lv, lv + 1)
		tile.pressed.connect(_on_promote.bind(i))
		_list_grid.add_child(tile)
		list_tiles.append(tile)
	_fit_list()


## A strip of camo swatches on a tile: the level now, and (to >= 0) the level it becomes.
func _add_band_strip(tile: PickTile, from_lv: int, to_lv: int) -> void:
	var strip := Control.new()
	strip.name = "Bands"
	strip.custom_minimum_size = Vector2(0, 12)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.draw.connect(func() -> void:
		var w: float = 70.0
		_swatch(strip, Rect2(0, 2, w, 8), SynergyGlyphs.band_of(from_lv))
		if to_lv >= 0:
			strip.draw_line(Vector2(w + 6, 6), Vector2(w + 22, 6), Color("#C8D0D6"), 2.0)
			strip.draw_colored_polygon(PackedVector2Array([Vector2(w + 28, 6), Vector2(w + 20, 1), Vector2(w + 20, 11)]), Color("#C8D0D6"))
			_swatch(strip, Rect2(w + 34, 2, w, 8), SynergyGlyphs.band_of(to_lv)))
	tile.content.add_child(strip)


static func _swatch(ci: CanvasItem, r: Rect2, band: StringName) -> void:
	if band == &"":
		ci.draw_rect(r, Color("#2A3036"))
		ci.draw_rect(r, Color("#8A949C"), false, 1.0)
	else:
		SynergyGlyphs.draw_band(ci, r, band)


## Doctrine: a trait emblem, its tier texts and how many Trained cards of it the deck has.
func _doctrine_tile(r: RunProgress, t: StringName) -> PickTile:
	var tile: PickTile = make_tile()
	tile.custom_minimum_size.x = 380
	tile.min_height = 280
	var emblem := Control.new()
	emblem.name = "Emblem"
	emblem.custom_minimum_size = Vector2(0, 72)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.draw.connect(func() -> void:
		var s: float = 68.0
		var rr: Rect2 = Rect2((emblem.size.x - s) * 0.5, 2, s, s)
		emblem.draw_circle(rr.get_center(), s * 0.52, Color(0.05, 0.06, 0.07))
		emblem.draw_arc(rr.get_center(), s * 0.5, 0, TAU, 40, SynergyGlyphs.trait_color(t), 3.0)
		SynergyGlyphs.draw_trait_icon(emblem, rr.grow(-14), t, SynergyGlyphs.trait_color(t)))
	tile.content.add_child(emblem)
	var name_l: Label = tile.add_line(SynergyGlyphs.trait_name(t).to_upper() + " DOCTRINE", &"TileName")
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var n: int = int(r.trait_counts().get(t, 0))
	tile.add_line("Your deck: %d Trained %s card%s." % [n, SynergyGlyphs.trait_name(t), "" if n == 1 else "s"], &"HudTag", false)
	tile.add_line("Its sets count +1 all run. 2: %s. 3: %s." % [SynergyRules.TIER_TEXT[t][0], SynergyRules.TIER_TEXT[t][1]])
	tile.add_spacer()
	tile.add_status("TAP TO PICK")
	return tile


func _fit_list() -> void:
	if _list_grid == null:
		return
	# From the screen, not _body.size (the tiles would hold the body at its old width).
	var w: float = maxf(300.0, size.x - _safe_area.get_theme_constant(&"margin_left") - _safe_area.get_theme_constant(&"margin_right") - 24.0)
	var cols: int = 3 if w >= 900.0 else 2
	_list_grid.columns = cols
	var tile_w: float = floorf((w - 12.0 * (cols - 1) - 8.0) / cols)
	for c: Node in _list_grid.get_children():
		(c as Control).custom_minimum_size.x = tile_w
	_list_scroll.custom_minimum_size = Vector2(0, 0)


## Takes option i of the current offer (one tap). Returns "" or RunState's reason.
func choose(i: int) -> String:
	var err: String = RunFlow.run_state().choose_offer(i)
	if err == "":
		# Deferred: the tapped tile is still inside its own pressed signal.
		_next.call_deferred()
	return err


## SKIP: declines the current offer. Returns "" or RunState's reason.
func skip() -> String:
	if not train_pick.is_empty():
		train_pick = {}
		show_offer()
		return ""
	if reissue_mode:
		if reissue_row >= 0:
			reissue_row = -1
		else:
			reissue_mode = false
		show_offer()
		return ""
	if retire_mode:
		retire_mode = false
		show_offer()
		return ""
	if offer.is_empty():
		goto(RunFlow.scene_for(run()))
		return ""
	var err: String = RunFlow.run_state().skip_offer()
	if err == "":
		_next.call_deferred()
	return err


func open_details(i: int) -> void:
	var r: RunProgress = run()
	var card: CardData = r.resource(StringName(offer["options"][i])) as CardData
	if card == null:
		return
	var art: StringName = offer_art(r, i) if offer["kind"] == RewardOffers.KIND_SUPPLY_DROP else card.id
	var t: StringName = offer_trait(r, i) if offer["kind"] == RewardOffers.KIND_SUPPLY_DROP else card.card_trait
	var vd: Dictionary = CardInfo.view_dict(card)
	var sub: String = BannerArtDB.subname(art)
	var ba: BannerArt = BannerArtDB.get_art(art)
	if BannerArtDB.is_card_art(ba):
		vd["licensed_art"] = String(art)
	elif not ba.is_default:
		vd["art_id"] = String(art)
	if sub != "":
		vd["subname"] = sub
	var lines: Array[Dictionary] = CardInfo.keywords(card)
	if card.is_unit() and card.has_trait_choice():
		# The more-info view: the art's name and the trait it gives this copy (art-traits §8).
		lines.push_front({"name": "Trait: %s" % ArtTraits.trait_name(t),
				"text": "From the art%s (%s family). This copy comes with it; the art decides the trait. Can be: %s." % [
					(" \"%s\"" % sub) if sub != "" else "", ArtTraits.FAMILY_NAMES[ArtTraits.family_of(art, card)],
					" · ".join(PackedStringArray(card.trait_choices().map(func(x: StringName) -> String: return ArtTraits.trait_name(x)))) ]})
	_inspector.open({
		"view": vd, "title": card.display_name, "type": ("%s · %s" % [sub.to_upper(), CardInfo.type_line(card)]) if sub != "" else CardInfo.type_line(card),
		"text": card.text, "keywords": lines,
		"status": "Supply Drop: close this, then tap the card to add it to your deck.",
	})


func get_inspector() -> Control:
	return _inspector


func _next() -> void:
	train_pick = {}
	reissue_mode = false
	reissue_row = -1
	var r: RunProgress = run()
	if r != null and r.phase == RunProgress.PHASE_REWARDS:
		show_offer()
	else:
		goto(RunFlow.scene_for(r))


## kc-trait-ui: `art` = the art this copy comes with (CardView shows it; its name is in DETAILS).
func _card_tile(card: CardData, art: StringName = &"") -> PickTile:
	var tile: PickTile = make_tile()
	var holder: Control = Control.new()
	holder.name = "CardHolder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.content.add_child(holder)
	var view: Control = CARD_VIEW_SCENE.instantiate()
	holder.add_child(view)
	var vd: Dictionary = CardInfo.view_dict(card)
	if art != &"" and art != card.id:
		var ba: BannerArt = BannerArtDB.get_art(art)
		if BannerArtDB.is_card_art(ba):
			vd["licensed_art"] = String(art)
		elif not ba.is_default:
			vd["art_id"] = String(art)
	view.set_card_data(vd)
	_ignore_mouse(view)
	var rules: String = card.text
	if rules == "":
		var kws: Array[Dictionary] = CardInfo.keywords(card)
		rules = "%s: %s" % [kws[0]["name"], kws[0]["text"]] if not kws.is_empty() else CardInfo.type_line(card)
	var label: Label = tile.add_line(rules)
	label.name = "RulesLabel"
	label.set_meta(&"full_text", rules)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	tile.content.add_child(row)
	var take: Label = make_label("TAP TO TAKE", &"HudAccent")
	take.mouse_filter = Control.MOUSE_FILTER_IGNORE
	take.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	take.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(take)
	var details: Button = make_button("DETAILS", &"HudButton", 110)
	details.name = "DetailsButton"
	details.pressed.connect(open_details.bind(card_views.size()))
	row.add_child(details)
	detail_buttons.append(details)
	card_views.append(view)
	_card_holders.append(holder)
	_rules_labels.append(label)
	return tile


func _item_tile(item: LoadoutItem) -> PickTile:
	var tile: PickTile = make_tile()
	tile.custom_minimum_size.x = 360
	tile.min_height = 260
	var r: RunProgress = run()
	tile.add_line(item.display_name.to_upper(), &"TileName")
	var tag: String = String(RunFlow.SLOT_WORDS.get(item.slot, "")).to_upper()
	if item.slot == DataEnums.LoadoutSlot.ATTACHMENT:
		tag += "  ·  FOR " + RunFlow.names_of(r, [r.primary], "").to_upper()
	tile.add_line(tag, &"HudTag", false)
	var effect: String = RunFlow.item_effect_line(item)
	if effect != "":
		tile.add_line(effect, &"FriendlyLabel")
	# Short texts ("+1 FP.") only repeat the stat line.
	if item.text != "" and (effect == "" or item.text.length() > 16):
		tile.add_line(item.text)
	# k-art3: a Perk shows its patch in the tile's free space (it shrinks, never grows the tile).
	var patch: TextureRect = CardArt.perk_patch(item.id, PERK_PATCH_PX) \
			if item.slot == DataEnums.LoadoutSlot.PERK else null
	if patch != null:
		patch.size_flags_vertical = Control.SIZE_EXPAND_FILL
		patch.custom_minimum_size = Vector2(0, 48)
		tile.content.add_child(patch)
	else:
		tile.add_spacer()
	tile.add_status("TAP TO TAKE")
	return tile


func _safe_area_changed() -> void:
	_fit_cards()
	_fit_list()


## Card scale for the Supply Drop: as big as the body allows, 0.8x-1.3x.
func _fit_cards() -> void:
	if card_views.is_empty() or _body == null or _body.size.y <= 0.0:
		return
	# Room left for the card: body minus the tile's margins and gaps, the rules lines and the
	# TAP TO TAKE / DETAILS row. Three rules lines when the card still gets 0.8x, else two.
	var label: Label = _rules_labels[0]
	var line_h: float = label.get_line_height() + label.get_theme_constant(&"line_spacing")
	var row_h: float = button_height()
	# From the screen, not _body.size: an oversized card would have grown the body already.
	var room: Vector2 = size - Vector2(
			_safe_area.get_theme_constant(&"margin_left") + _safe_area.get_theme_constant(&"margin_right"),
			_safe_area.get_theme_constant(&"margin_top") + _safe_area.get_theme_constant(&"margin_bottom")
			+ maxf(_header.size.y, button_height()) + %Layout.get_theme_constant(&"separation"))
	var max_lines: int = 3
	var extra_h: float = (maxf(line_h, 22.0) + 4.0) if _trait_lines else 0.0
	var by_h: float = (room.y - (28.0 + extra_h + line_h * max_lines + row_h)) / CardView.BASE_SIZE.y
	while by_h < MIN_CARD_SCALE and max_lines > 1:
		# kc-syn-ui: the trait line ("VANGUARD 3 > 4") can cost a rules line on the phone; DETAILS has it all.
		max_lines -= 1
		by_h = (room.y - (28.0 + extra_h + line_h * max_lines + row_h)) / CardView.BASE_SIZE.y
	var n: int = card_views.size()
	var extra_w: float = (RETIRE_TILE_W + 16.0) if retire_tile != null else 0.0
	var by_w: float = (room.x - extra_w - 16.0 * (n - 1) - 28.0 * n) / (CardView.BASE_SIZE.x * n)
	var s: float = clampf(minf(by_h, by_w), MIN_CARD_SCALE, MAX_CARD_SCALE)
	for i: int in n:
		var view: Control = card_views[i]
		view.pivot_offset = Vector2.ZERO  # CardView pivots on its centre; scale from the corner
		view.scale = Vector2(s, s)
		view.position = Vector2.ZERO
		_card_holders[i].custom_minimum_size = CardView.BASE_SIZE * s
		_rules_labels[i].custom_minimum_size.x = CardView.BASE_SIZE.x * s
		_fit_rules(_rules_labels[i], CardView.BASE_SIZE.x * s, max_lines)
		# Same height for every rules block, so the TAKE / DETAILS rows line up.
		_rules_labels[i].custom_minimum_size.y = ceilf(line_h * max_lines)
		detail_buttons[i].custom_minimum_size.y = row_h
	for tile: PickTile in tiles:
		tile.custom_minimum_size.x = CardView.BASE_SIZE.x * s + 28.0


## Cuts the rules line to max_lines at this width, ending a cut text in "..." (DETAILS has it all).
## Label's own ellipsis can't be used: with autowrap it shrinks the label to one line's height.
func _fit_rules(label: Label, width: float, max_lines: int) -> void:
	var full: String = label.get_meta(&"full_text", label.text)
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	var words: PackedStringArray = full.split(" ")
	var text: String = full
	while words.size() > 1 and _line_count(text, font, font_size, width) > max_lines:
		words.remove_at(words.size() - 1)
		text = " ".join(words).trim_suffix(",").trim_suffix(";").trim_suffix(":") + "..."
	label.text = text
	label.max_lines_visible = max_lines


static func _line_count(text: String, font: Font, font_size: int, width: float) -> int:
	var para: TextParagraph = TextParagraph.new()
	para.add_string(text, font, font_size)
	para.width = width
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	return para.get_line_count()


## Card scale in use (tests).
func get_card_scale() -> float:
	return card_views[0].scale.x if not card_views.is_empty() else 0.0


static func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_mouse(child)

# reward_screen.gd
# Purpose: Reward offers between matches (p11, scenes/run/Reward.tscn). Shows RunState's current
#   offer and resolves it with one tap, then the next offer (same screen) or the run map:
#   - Supply Drop (after a win) / Salvage (after a loss, kc-onboard §4.3): the offered cards as
#     CardView with a readable rules line under each. Tap a card to add it to the deck. A drop can
#     ask for more than one card ("PICK 2 OF 4": offer `picks`; a taken card leaves the row and is
#     listed in the subtitle; the drop stays until its picks are used or SKIP). DETAILS (or a long
#     press / right-click on the card) opens the inspector without choosing.
#     kc-ipad-cards (kc-no-training): no Recruit cards, no "Trains:" line, no level badge.
#   - Muster out (kc-onboard §4.3): every Standard Issue copy as a tile (its Standard Issue banner,
#     serial plate, cost and stats); the most expensive are pre-selected (GOING HOME), tap to keep
#     one or send another, up to the offer's count; the deck never goes under the floor. SEND n HOME
#     commits (RunState.muster_out), KEEP ALL skips.
#   - Weapon level: attachments for the Primary. Perk offer: Perks you don't own.
#   - Doctrine / Regroup (kc-syn; only from older configs / saves). Promotion is gone (kc-no-training).
#   RETIRE (header, "instead of a card", only once Retire is met: RevealGate) opens the Retire list.
#   One "New: X" explainer per offer (NewCard) when the offer brings a system for the first time.
#   SKIP declines any offer. Each offer announces EventBus.screen_shown(&"reward_<kind>").
#   kc-onboard-ui (head Z1): the TRAIN AS picker, Re-issue (tile, header button, flow) and the
#   twin-training path are gone: a card keeps the trait of the art it was found with.
#   Phone: cards scale 0.8-1.3x to the room left (>= 0.8x keeps name / cost / stats >= 11 pt);
#   4 cards fit across the 844x390 canvas at 0.8x now that Retire moved to the header.
# Dependencies: run_screen.gd, pick_tile.gd, CardView.tscn, CardInspector.tscn, card_info.gd,
#   RunState, RunFlow, RewardOffers, RevealGate, RevealFlags, NewCard, StandardIssueLook, BannerCard.
# Author: UI/UX Agent (p11; kc-onboard-ui)
extends "res://scripts/ui/run/run_screen.gd"

const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")
const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/match/CardView.tscn")
const INSPECTOR_SCENE: PackedScene = preload("res://scenes/match/CardInspector.tscn")
const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
const MIN_CARD_SCALE: float = 0.8
const MAX_CARD_SCALE: float = 1.3
## Perk patch texture width (px) on a Perk offer tile.
const PERK_PATCH_PX: int = 320
const KIND_TITLES: Dictionary = {
	RewardOffers.KIND_SUPPLY_DROP: "SUPPLY DROP",
	RewardOffers.KIND_SALVAGE: "SALVAGE",
	RewardOffers.KIND_MUSTER_OUT: "MUSTER OUT",
	RewardOffers.KIND_ATTACHMENT: "WEAPON LEVEL",
	RewardOffers.KIND_PERK: "PERK OFFER",
	RewardOffers.KIND_DOCTRINE: "DOCTRINE",
	RewardOffers.KIND_REGROUP: "REGROUP",
}
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
const EnginePanel: GDScript = preload("res://scripts/ui/run/engine_panel.gd")
## Banner size of a Muster out tile (keeps the board's 57 px icon metrics).
const MUSTER_BANNER_H: float = 57.0
## kc-cards-impl: Muster out / list cards are Y2+ cards this wide.
const MUSTER_CARD_W: float = 172.0
## kc-cards-impl: the Supply Drop / Salvage Y2+ card width range (the mock-up's reward card is 212).
const MIN_CARD_W: float = 172.0
const MAX_CARD_W: float = 240.0

## The offer on screen ({kind, match, options}); {} when none.
var offer: Dictionary = {}
## Option tiles in offer order (PickTile).
var tiles: Array[PickTile] = []
var detail_buttons: Array[Button] = []
## CardView per Supply Drop / Salvage option.
var card_views: Array[Control] = []
## kc-onboard-ui: RETIRE in the header (hidden when the offer has none or Retire isn't met yet).
var retire_button: Button = null
## The list tiles of a Retire / Muster out pick (option order = the RunProgress list).
var list_tiles: Array[PickTile] = []
var retire_mode: bool = false
## kc-onboard-ui Muster out: deck index -> true for the copies marked GOING HOME, and the commit button.
var muster_marks: Dictionary = {}
var send_button: Button = null
## The "New: X" explainer over this screen.
var new_card: NewCard = null

var _skip_button: Button = null
var _options: GridContainer = null
var _inspector: Control = null
var _card_holders: Array[Control] = []
var _rules_labels: Array[Label] = []
var _list_scroll: ScrollContainer = null
var _list_grid: GridContainer = null
var _center: CenterContainer = null
var _deck_button: Button = null
var _engine: Control = null
var _trait_lines: bool = false

@onready var _header: BoxContainer = %Header
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
	_deck_button.tooltip_text = "Your deck: every card and its trait"
	_deck_button.pressed.connect(open_deck)
	_header.add_child(_deck_button)
	_header.move_child(_deck_button, _skip_button.get_index())
	# kc-onboard-ui: Retire "under More" (§5.2): a header button, so the 4 cards of a drop fit the phone.
	retire_button = make_button("MUSTER OUT", &"HudButton", 150)
	retire_button.name = "RetireButton"
	retire_button.tooltip_text = "Remove a card from your deck instead"
	retire_button.pressed.connect(open_retire_picker)
	_header.add_child(retire_button)
	_header.move_child(retire_button, _deck_button.get_index())
	send_button = make_button("MUSTER OUT", &"HudButton", 200)
	send_button.name = "SendHomeButton"
	send_button.tooltip_text = "Muster out the marked Standard Issue cards"
	send_button.pressed.connect(confirm_muster_out)
	_header.add_child(send_button)
	for b: Button in [_skip_button, _deck_button, retire_button, send_button]:
		_wire_inspect(b, _inspect_header.bind(b))
	var center: CenterContainer = CenterContainer.new()
	_center = center
	# kc-portrait: the options sit in a vertical scroll (two per row in portrait; one row in landscape).
	var opt_scroll: ScrollContainer = ScrollContainer.new()
	opt_scroll.name = "OptionsScroll"
	opt_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(opt_scroll)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	opt_scroll.add_child(center)
	_options = GridContainer.new()
	_options.name = "Options"
	_options.columns = 4
	_options.add_theme_constant_override(&"h_separation", 16)
	_options.add_theme_constant_override(&"v_separation", 12)
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
	_body.resized.connect(_fit_cards)  # kc-portrait: the body settles after the header reflows
	_engine = EnginePanel.new()
	_engine.name = "EngineView"
	add_child(_engine)
	_engine.row_inspected.connect(_inspect_card_id)
	_inspector = INSPECTOR_SCENE.instantiate()
	add_child(_inspector)
	new_card = NewCard.new()
	add_child(new_card)
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
	var prev_key: String = "%s|%s" % [offer.get("kind", ""), offer.get("match", 0)]
	offer = r.current_offer() if r != null else {}
	clear(_options)
	tiles.clear()
	detail_buttons.clear()
	card_views.clear()
	_card_holders.clear()
	_rules_labels.clear()
	list_tiles.clear()
	clear(_list_grid)
	_trait_lines = false
	_center.visible = true
	_center.get_parent().visible = true
	_list_scroll.visible = false
	retire_button.visible = false
	send_button.visible = false
	if offer.is_empty():
		_title.text = "NO REWARD"
		_subtitle.text = ""
		_skip_button.text = "CONTINUE"
		return
	var key: String = "%s|%s" % [offer.get("kind", ""), offer.get("match", 0)]
	if key != prev_key:
		muster_marks.clear()
	var kind: StringName = offer["kind"]
	var pending: int = r.pending_offers.size()
	_title.text = String(KIND_TITLES.get(kind, "REWARD"))
	# kc-v2-ui: an elite win's drop is an Elite Cache (run-v2-api.md §7: offer.elite_cache).
	if bool(offer.get("elite_cache", false)):
		_title.text = "ELITE CACHE"
	var picks: int = int(offer.get("picks", 1))
	var taken: Array = offer.get("taken", [])
	if kind in RewardOffers.CARD_DROPS and picks + taken.size() > 1:
		# kc-onboard: "SUPPLY DROP · PICK 2 OF 4" (taken cards leave the row).
		_title.text += "  ·  PICK %d OF %d" % [picks + taken.size(), (offer["options"] as Array).size() + taken.size()]
	elif pending > 1:
		_title.text += "  ·  1 OF %d REWARDS" % pending
	_skip_button.text = "SKIP"
	match kind:
		RewardOffers.KIND_SUPPLY_DROP, RewardOffers.KIND_SALVAGE:
			_subtitle.text = _drop_subtitle(r)
		RewardOffers.KIND_ATTACHMENT:
			var primary: String = RunFlow.names_of(r, [r.primary], "your weapon")
			_subtitle.text = "%s levelled up to level %d. Tap an attachment to fit it. Fitted: %s." % [
					primary, r.weapon_level + 1, RunFlow.names_of(r, r.attachments)]
		RewardOffers.KIND_PERK:
			_subtitle.text = "Take a Perk. Slots used: %d of %d (%s)." % [
					r.perks.size(), r.config.perk_slots, RunFlow.names_of(r, r.perks)]
		RewardOffers.KIND_DOCTRINE:
			_subtitle.text = "Pick a trait: its sets count +1 for the rest of the run."
		RewardOffers.KIND_REGROUP:
			_subtitle.text = "Lost: muster out one card for free (deck %d, min %d)." % [r.deck.size(), r.config.deck_floor]
	if kind in RewardOffers.CARD_DROPS and bool(offer.get("retire", false)) and RevealGate.shown(RevealFlags.RETIRE) and not retire_mode:
		retire_button.visible = true
		retire_button.disabled = not r.can_retire()
		retire_button.text = "MUSTER OUT" if r.can_retire() else "AT FLOOR"
	if kind == RewardOffers.KIND_MUSTER_OUT:
		_build_muster_out(r)
		_after_build(key)
		return
	if retire_mode or kind == RewardOffers.KIND_REGROUP:
		_build_retire_list(r, kind != RewardOffers.KIND_REGROUP)
		_after_build(key)
		return
	var options: Array = offer["options"]
	var drop: bool = kind in RewardOffers.CARD_DROPS
	for i: int in options.size():
		if kind == RewardOffers.KIND_DOCTRINE:
			var dt: PickTile = _doctrine_tile(r, StringName(options[i]))
			dt.name = "Option%d" % i
			dt.pressed.connect(choose.bind(i))
			_options.add_child(dt)
			tiles.append(dt)
			continue
		var res: Resource = r.resource(StringName(options[i]))
		var tile: PickTile = _card_tile(res as CardData, offer_art(r, i) if drop else &"") if res is CardData else _item_tile(res as LoadoutItem)
		tile.name = "Option%d" % i
		tile.pressed.connect(choose.bind(i))
		if res is CardData:
			_wire_inspect(tile, open_details.bind(i))
		else:
			_wire_inspect(tile, _inspect_item.bind(res as LoadoutItem))
		_options.add_child(tile)
		tiles.append(tile)
	if drop:
		_mark_trait_lines(r)
	_fit_cards()
	# Keyboard / controller start on the first option; on touch screens a focus frame on one
	# option would read as "already picked".
	if not tiles.is_empty() and not DisplayServer.is_touchscreen_available():
		tiles[0].grab_focus.call_deferred()
	# kc-juice: a new offer's cards fade in one after the other (reward_reveal_fx.gd).
	if key != prev_key:
		(load("res://scripts/fx/reward_reveal_fx.gd") as GDScript).call(&"reveal", tiles)
	_after_build(key)


func _after_build(key: String) -> void:
	_announce()
	var r: RunProgress = run()
	if new_card != null and r != null:
		new_card.offer(RevealFlags.run_triggers(r), key)


## "Tap 2 cards to add them to your deck (12 cards now). Taken: Breacher." (Salvage: "After a loss
## you still salvage a card.").
func _drop_subtitle(r: RunProgress) -> String:
	var picks: int = int(offer.get("picks", 1))
	var taken: Array = offer.get("taken", [])
	var head: String = "Lost, but you salvage a card. " if offer["kind"] == RewardOffers.KIND_SALVAGE else ""
	var what: String = ""
	if taken.is_empty():
		what = "Take a card for your deck" if picks <= 1 else "Take %d cards for your deck" % picks
	else:
		what = "Take 1 more" if picks <= 1 else "Take %d more" % picks
	var s: String = "%s%s (deck %d)." % [head, what, r.deck.size()]
	if not taken.is_empty():
		var names: PackedStringArray = []
		for t: Dictionary in taken:
			var c: CardData = r.resource(StringName(t.get("id", ""))) as CardData
			names.append(c.display_name if c != null else String(t.get("id", "")))
		s += " Taken: %s." % ", ".join(names)
	if r.config.muster_out_after(int(offer.get("match", 0))):
		s += " Then Muster out."
	return s


func _announce() -> void:
	var bus: Node = RunFlow.event_bus()
	if bus != null and is_node_ready():
		bus.screen_shown.emit(screen_id())


# =============================================================================
# Inspect (studio rule: every tile and button opens a tooltip or zoom on long press / right click)
# =============================================================================

## A long press (touch) or right click on a Button calls on_inspect instead of pressing it.
func _wire_inspect(b: BaseButton, on_inspect: Callable) -> void:
	var st: Dictionary = {"id": 0, "fired": false}
	b.gui_input.connect(func(e: InputEvent) -> void:
		if not e is InputEventMouseButton:
			return
		var mb: InputEventMouseButton = e
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			b.accept_event()
			on_inspect.call()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			st["id"] = int(st["id"]) + 1
			st["fired"] = false
			var my_id: int = st["id"]
			var wb: WeakRef = weakref(b)  # kc-clarity: no "Lambda capture ... was freed" when b goes first
			get_tree().create_timer(PressGesture.LONG_PRESS_S).timeout.connect(func() -> void:
				var bb: Control = wb.get_ref() as Control
				if bb != null and int(st["id"]) == my_id and bb.is_inside_tree() \
						and bb.get_global_rect().has_point(bb.get_global_mouse_position()):
					st["fired"] = true
					on_inspect.call())
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			st["id"] = int(st["id"]) + 1
			if bool(st["fired"]):
				# The hold opened the inspector: swallow the release so the tile doesn't press.
				st["fired"] = false
				b.accept_event())
	b.set_meta(&"inspectable", true)


func _inspect_header(b: Button) -> void:
	var floor_n: int = run().config.deck_floor if run() != null else 8
	var texts: Dictionary = {
		"SkipButton": ["Skip", "Take nothing from this offer. On Muster out: every Standard Issue card stays."],
		"DeckButton": ["Deck", "Your deck: every card, its copies and their traits."],
		"RetireButton": ["Muster out", "Instead of a card, take one out of your deck for good (Honor Roll). Deck minimum: %d." % floor_n],
		"SendHomeButton": ["Muster out", "Takes the cards marked MUSTER OUT out of your deck. Deck minimum: %d." % floor_n],
	}
	var t: Array = texts.get(String(b.name), [b.text.capitalize(), b.tooltip_text])
	_inspector.open({"title": String(t[0]), "type": "button", "text": String(t[1]), "status": ""})


func _inspect_item(item: LoadoutItem) -> void:
	if item == null:
		return
	_inspector.open({"title": item.display_name, "type": String(RunFlow.SLOT_WORDS.get(item.slot, "item")),
			"text": item.text, "status": RunFlow.item_effect_line(item)})


# =============================================================================
# kc-syn-ui: Doctrine, Retire / Regroup, on-trait slot, deck view
# =============================================================================

## DECK: the deck view with the Engine panel.
func open_deck() -> void:
	_engine.open(run())


func get_engine_view() -> Control:
	return _engine


func _inspect_card_id(id: StringName) -> void:
	var card: CardData = run().resource(id) as CardData
	if card == null:
		return
	_inspector.open({"view": _view_dict(card), "title": card.display_name, "type": CardInfo.type_line(card),
			"banner": BannerCard.entry_for_card(card), "is_unit": card.is_unit(),
			"text": card.text, "keywords": CardInfo.keywords(card) + _syn_lines(card), "status": _si_status(card)})


## "Standard Issue SI-02: ..." (inspector; "" for any other card).
static func _si_status(card: CardData) -> String:
	if card.standard_issue:
		return "Standard Issue %s: no trait. Muster out takes it out of your deck." % RunProgress.standard_issue_serial(card)
	return ""


## CardView dictionary of a copy wearing `art` (its trait; the Standard Issue look).
static func _view_dict(card: CardData, art: StringName = &"") -> Dictionary:
	var vd: Dictionary = CardInfo.view_dict(card)
	if card.standard_issue or (art != &"" and ArtTraits.is_standard_issue_art(art, card)):
		vd["standard_issue"] = true
		vd["serial"] = RunProgress.standard_issue_serial(card)
	# kc-cards-impl (Y2+): the copy's 4:1 art and trait.
	vd["banner"] = String(art if art != &"" else card.id)
	var t: StringName = SynergyRules.trait_at(card, ArtTraits.trait_of(art, card) if art != &"" and card.has_trait_choice() else SynergyRules.TRAIT_DEFAULT)
	if t != &"":
		vd["trait"] = String(t)
	return vd


## Keyword / trait lines for the inspector.
func _syn_lines(card: CardData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var kw: StringName = card.neighbor_keyword
	if kw != &"":
		out.append({"name": "%s (neighbour keyword)" % SynergyGlyphs.keyword_name(kw),
				"text": String(SynergyRules.KEYWORD_TEXT[kw])})
	var t: StringName = card.card_trait
	if t != &"" and not card.standard_issue:
		out.append({"name": "%s (trait)" % SynergyGlyphs.trait_name(t),
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


## Supply Drop: each option is a concrete copy: a head line "[icon] ON-TRAIT · HEAVY 3 > 4" and what it
## does to your engine; slot 1 on your main trait is marked ON-TRAIT.
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
		var head: Control = _trait_head(line2.to_upper(), "", t, on)
		head.tooltip_text = "%s · %s" % [card.display_name, line2]
		head.name = "TraitLine"
		tiles[i].content.add_child(head)
		tiles[i].content.move_child(head, 0)
		_trait_lines = true


## "Heavy 2 > 3: bonus ON" / "Vanguard 0 > 1 (bonus at 2)" / "Heavy 3 > 4 (full set)" for a trait
## count going from `from` to `to` copies in the deck. `short` (Supply Drop tiles): only
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
			StandardIssueLook.draw_empty_socket(icon, rr.grow(-1)))
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


## Supply Drop > RETIRE: the list of cards to retire (BACK returns to the cards).
func open_retire_picker() -> void:
	var r: RunProgress = run()
	if r == null or not r.can_retire():
		return
	retire_mode = true
	show_offer()


## Retire list (Supply Drop / Salvage RETIRE, or Regroup): one tile per design and trait,
## Standard Issue first, with its cost and trait.
func _build_retire_list(r: RunProgress, from_drop: bool) -> void:
	_center.visible = false
	_center.get_parent().visible = false
	_list_scroll.visible = true
	_title.text = "MUSTER OUT A CARD" if from_drop else _title.text
	if from_drop:
		_subtitle.text = "Pick a card to muster out instead (deck %d, min %d)." % [r.deck.size(), r.config.deck_floor]
		_skip_button.text = "BACK"
	var opts: Array[Dictionary] = r.retire_options()
	if opts.is_empty():
		var t0: PickTile = make_tile()
		t0.add_line("AT THE FLOOR", &"TileName")
		t0.add_line("Deck at its minimum (%d): nothing can be mustered out." % r.config.deck_floor)
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
		var si: bool = card != null and card.standard_issue
		var nm: Label = tile.add_line(card.display_name.to_upper() if card != null else String(o["id"]), &"TileName")
		if si:
			nm.add_theme_font_override(&"font", CardLook.TITLE_FONT)  # kc-cards-impl: one title style
		var tag: String = ("STANDARD ISSUE %s · COST %d" % [RunProgress.standard_issue_serial(card), int(o["cost"])]) if si else \
				("COST %d" % int(o["cost"]))
		if StringName(o["trait"]) != &"":
			tag += " · " + SynergyGlyphs.trait_name(o["trait"]).to_upper()
		tile.add_line(tag, &"HudTag", false)
		tile.add_line("Removed from the deck (Honor Roll).")
		tile.pressed.connect(retire.bind(i))
		if card != null:
			_wire_inspect(tile, _inspect_card_id.bind(card.id))
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


# =============================================================================
# kc-onboard-ui: Muster out
# =============================================================================

## How many Standard Issue cards this Muster out may send home (RunProgress.muster_out_count).
func muster_count() -> int:
	var r: RunProgress = run()
	return r.muster_out_count() if r != null else 0


## Muster out: one tile per Standard Issue copy (most expensive first), the pre-selection marked
## GOING HOME; tap toggles (up to the count); SEND n HOME commits, KEEP ALL skips.
func _build_muster_out(r: RunProgress) -> void:
	_center.visible = false
	_center.get_parent().visible = false
	_list_scroll.visible = true
	var rows: Array[Dictionary] = r.muster_out_options()
	var n: int = muster_count()
	if muster_marks.is_empty():
		for row: Dictionary in rows:
			if bool(row["preselected"]):
				muster_marks[int(row["index"])] = true
	_skip_button.text = "KEEP ALL"
	send_button.visible = true
	for row: Dictionary in rows:
		var idx: int = int(row["index"])
		var card: CardData = r.resource(row["id"]) as CardData
		var tile: PickTile = make_tile()
		tile.name = "Muster%d" % idx
		tile.set_meta(&"index", idx)
		tile.set_meta(&"serial", String(row["serial"]))
		var holder := Control.new()
		holder.name = "CardHolder"
		# kc-cards-impl: the Y2+ card (172 px, the Codex size).
		holder.custom_minimum_size = CardView.size_for(MUSTER_CARD_W)
		holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.content.add_child(holder)
		var bc: CardView = CARD_VIEW_SCENE.instantiate() as CardView
		bc.name = "Card"
		holder.add_child(bc)
		bc.set_card_data(_view_dict(card, StringName(row["art"])))
		bc.set_card_width(MUSTER_CARD_W)
		_ignore_mouse(bc)
		var st: Label = tile.add_status("")
		st.name = "MusterStatus"
		tile.pressed.connect(toggle_muster.bind(idx))
		_wire_inspect(tile, _inspect_muster.bind(idx))
		_list_grid.add_child(tile)
		list_tiles.append(tile)
	_refresh_muster(r, n)
	_fit_list()


func _refresh_muster(r: RunProgress, n: int, note: String = "") -> void:
	var marked: int = muster_marks.size()
	for t: PickTile in list_tiles:
		var on: bool = muster_marks.has(int(t.get_meta(&"index", -1)))
		t.set_selected(on, "MUSTER OUT", "STAYS")
	send_button.text = ("MUSTER OUT %d" % marked) if marked > 0 else "MUSTER OUT NONE"
	_subtitle.text = note if note != "" else \
			"Muster out up to %d of your %d Standard Issue cards: deck %d > %d (min %d). Tap a card to mark or keep it." % [
				n, r.standard_issue_count(), r.deck.size(), r.deck.size() - marked, r.config.deck_floor]


## Tap on a Muster out tile: mark / unmark that copy (never more than the count). Returns "" or why not.
func toggle_muster(idx: int) -> String:
	var r: RunProgress = run()
	if r == null:
		return "no run"
	var n: int = muster_count()
	if muster_marks.has(idx):
		muster_marks.erase(idx)
	elif muster_marks.size() >= n:
		_refresh_muster(r, n, "Only %d can go home: keep a marked card first." % n)
		return "full"
	else:
		muster_marks[idx] = true
	_refresh_muster(r, n)
	return ""


## SEND n HOME: RunState.muster_out(marked deck indices). Returns "" or RunState's reason.
func confirm_muster_out() -> String:
	var idx: Array = muster_marks.keys()
	var err: String = RunFlow.run_state().muster_out(idx)
	if err == "":
		muster_marks.clear()
		_next.call_deferred()
	return err


func _inspect_muster(idx: int) -> void:
	var r: RunProgress = run()
	if r == null or idx < 0 or idx >= r.deck.size():
		return
	var card: CardData = r.resource(r.deck[idx]) as CardData
	_inspector.open({"view": _view_dict(card, r.art_of(idx)), "banner": BannerCard.entry_for_card(card, r.art_of(idx)),
			"title": card.display_name, "type": "Standard Issue %s · %s" % [RunProgress.standard_issue_serial(card), CardInfo.type_line(card)],
			"text": "Basic kit: %d Supply, %d FP, %d Armor. No keyword, no trait." % [card.cost, card.firepower, card.armor],
			"status": "Marked: leaves your deck on MUSTER OUT." if muster_marks.has(idx) else "Stays in your deck."})


## Doctrine: a trait emblem, its tier texts and how many cards of it the deck has.
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
	_wire_inspect(tile, func() -> void:
		_inspector.open({"title": SynergyGlyphs.trait_name(t) + " Doctrine", "type": "trait",
				"text": "Its sets count +1 for the rest of the run. 2 in play: %s. 3 in play: %s." % [SynergyRules.TIER_TEXT[t][0], SynergyRules.TIER_TEXT[t][1]], "status": ""}))
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


## SKIP (KEEP ALL on Muster out; BACK in the Retire list): declines the current offer. Returns ""
## or RunState's reason.
func skip() -> String:
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
	if i < 0 or i >= (offer.get("options", []) as Array).size():
		return
	var card: CardData = r.resource(StringName(offer["options"][i])) as CardData
	if card == null:
		return
	var drop: bool = offer["kind"] in RewardOffers.CARD_DROPS
	var art: StringName = offer_art(r, i) if drop else card.id
	var t: StringName = offer_trait(r, i) if drop else card.card_trait
	var vd: Dictionary = _view_dict(card, art)
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
				"text": "From the art%s (%s family). This copy comes with it; the art decides the trait." % [
					(" \"%s\"" % sub) if sub != "" else "", ArtTraits.FAMILY_NAMES[ArtTraits.family_of(art, card)]]})
	var text: String = card.text
	var status: String = "%s: close this, then tap the card to add it to your deck." % String(KIND_TITLES.get(offer["kind"], "SUPPLY DROP")).capitalize()
	_inspector.open({
		"view": vd, "title": card.display_name, "type": ("%s · %s" % [sub.to_upper(), CardInfo.type_line(card)]) if sub != "" else CardInfo.type_line(card),
		"text": text, "keywords": lines, "status": status,
	})


func get_inspector() -> Control:
	return _inspector


func get_new_card() -> NewCard:
	return new_card


func _next() -> void:
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
	var vd: Dictionary = _view_dict(card, art)
	if art != &"" and art != card.id:
		var ba: BannerArt = BannerArtDB.get_art(art)
		if BannerArtDB.is_card_art(ba):
			vd["licensed_art"] = String(art)
		elif not ba.is_default:
			vd["art_id"] = String(art)
	view.set_card_data(vd)
	_ignore_mouse(view)
	# kc-ux-text: what the card does, not its keyword name again (the face shows "Flank" already):
	# the keyword's rule ("Flank: Shoots the back-most enemy."), else the card's text.
	var rules: String = CardInfo.rule_line(card).replace("\n", " ")
	if rules == "":
		rules = "No ability: %d FP, %d Armor." % [card.firepower, card.armor] if card.is_unit() else CardInfo.type_line(card)
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
	_wire_inspect(details, open_details.bind(card_views.size()))
	row.add_child(details)
	detail_buttons.append(details)
	card_views.append(view)
	_card_holders.append(holder)
	_rules_labels.append(label)
	return tile


func _item_tile(item: LoadoutItem) -> PickTile:
	var tile: PickTile = make_tile()
	# kc-clarity (playtest v28: the weapon-level screen ran off the left edge on a phone, "EVELLED
	# UP"): two 360 px tiles are wider than a portrait phone; they share the width instead.
	var vw: float = get_viewport_rect().size.x if is_inside_tree() else 1280.0
	tile.custom_minimum_size.x = clampf((vw - 48.0) * 0.5 - 12.0, 150.0, 360.0)
	tile.min_height = 260
	var r: RunProgress = run()
	tile.add_line(item.display_name.to_upper(), &"TileName")
	var tag: String = String(RunFlow.SLOT_WORDS.get(item.slot, "")).to_upper()
	if item.slot == DataEnums.LoadoutSlot.ATTACHMENT:
		tag += "  ·  FOR " + RunFlow.names_of(r, [r.primary], "").to_upper()
	tile.add_line(tag, &"HudTag", tile.custom_minimum_size.x < 300.0)
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
	# kc-cards-impl: the Y2+ card at its own width (never scaled): card height = w / 4 + 153.
	var room_card_h: float = room.y - (28.0 + extra_h + line_h * max_lines + row_h)
	var by_h: float = (room_card_h - (CardView.height_for(8.0) - 0.0)) * 4.0 + 8.0
	while by_h < MIN_CARD_W and max_lines > 1:
		# kc-syn-ui: the trait line ("VANGUARD 3 > 4") can cost a rules line on the phone; DETAILS has it all.
		max_lines -= 1
		room_card_h = room.y - (28.0 + extra_h + line_h * max_lines + row_h)
		by_h = (room_card_h - CardView.height_for(8.0)) * 4.0 + 8.0
	var n: int = card_views.size()
	# kc-portrait: two cards per row (the options scroll); the height is no limit there.
	var per_row: int = mini(n, 2) if portrait else maxi(1, n)
	_options.columns = maxi(1, per_row)
	if portrait:
		by_h = MAX_CARD_W
	var gap: float = 16.0
	var by_w: float = (room.x - gap * (per_row - 1) - 28.0 * per_row) / per_row
	if by_w < MIN_CARD_W and per_row > 1:
		gap = clampf((room.x - 28.0 * per_row - MIN_CARD_W * per_row) / (per_row - 1), 6.0, 16.0)
		by_w = (room.x - gap * (per_row - 1) - 28.0 * per_row) / per_row
	_options.add_theme_constant_override(&"h_separation", int(gap))
	var cw: float = clampf(floorf(minf(by_h, by_w)), MIN_CARD_W, MAX_CARD_W)
	for i: int in n:
		var view: Control = card_views[i]
		view.pivot_offset = Vector2.ZERO
		view.scale = Vector2.ONE
		view.position = Vector2.ZERO
		(view as CardView).set_card_width(cw)
		_card_holders[i].custom_minimum_size = CardView.size_for(cw)
		var lw: float = cw - float(_rules_labels[i].get_meta(&"lock_w", 0.0))
		_rules_labels[i].custom_minimum_size.x = lw
		_fit_rules(_rules_labels[i], lw, max_lines)
		# Same height for every rules block, so the TAKE / DETAILS rows line up.
		_rules_labels[i].custom_minimum_size.y = ceilf(line_h * max_lines)
		detail_buttons[i].custom_minimum_size.y = row_h
	for tile: PickTile in tiles:
		tile.custom_minimum_size.x = cw + 28.0


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
		text = " ".join(words).trim_suffix(",").trim_suffix(";").trim_suffix(":").trim_suffix("·").strip_edges() + "..."
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


## The Y2+ card width in use (tests).
func get_card_width() -> float:
	return (card_views[0] as CardView).get_card_width() if not card_views.is_empty() else 0.0


static func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_mouse(child)

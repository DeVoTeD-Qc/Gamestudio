# match_screen.gd
# Purpose: Match screen, layout v2 (kc-board2, board-layout-v2.md, approved). Landscape only:
#   - the ICON STRIP (left; right when mirrored): MENU, SCORE, OPERATOR, STREAK, RIVAL, PREVIEW and
#     DECK at the bottom. Each badge shows its key value; tap opens its flyout (ScoreBar, the
#     Operator panel's info or its killstreak tiles, the rival intel, deck counts), long-press /
#     right-click opens the rules (rail_inspected). While the Operator can deploy, the OPERATOR badge
#     is the Operator's handle (tap = select, drag = drag to a column) and glows.
#   - the BOARD at full height (3 columns x 4 rows per side; banners 228x57 on an 844x390 phone,
#     304x76 on a 1440x900 desktop). It never moves or resizes.
#   - the HAND TRAY (right; left when mirrored): the Supply row, then the hand grid and UNDO / READY
#     (OPEN, Deploy), or the firefight step header, the killfeed log, the HAND · n PEEK tab and
#     SPEED x2 (CLOSED: Reveal, Firefight, Score). PEEK shows the hand read-only outside Deploy.
#   - killfeed TOASTS at the top centre of the board (2 at most, 2.5 s, no input) + the tray log.
#   Settings.mirror_layout swaps the strip and the tray (left-handed players).
#   kc-ui3: the Operator is a card at the start of the hand grid (deploy it like any card; on the
#   board it reads ON BOARD / B · ROW 2, down it reads DOWN / NEXT ROUND); the OPERATOR badge is info
#   only (tap = its flyout). The KILLSTREAK tiles sit at the top of the tray (killstreak_row.gd):
#   always visible with their charge, amber glow + a one-time toast when one is ready, tap = use,
#   long-press = rules (item_inspected).
#   Filled from a snapshot Dictionary. No game rules here: match_controller.gd (child node
#   MatchController) owns the MatchState, turns input into intents and calls show_snapshot();
#   with autostart off (tests) the screen shows mock_match_data.gd.
#
# Look: the project theme (assets/ui/hud_theme.tres). Below COMPACT_HEIGHT (640) logical px the
#   compact (phone) profile is used.
# Dependencies: scenes in scenes/match/, screen_profile.gd, board_metrics.gd, strip_badge.gd,
#   mock_match_data.gd, Settings (mirror_layout).
# Author: UI/UX Agent (p08), Mechanics Developer Agent (kc-board layout, kc-board2 layout v2)
extends Control

signal ready_pressed
signal menu_pressed
signal undo_pressed
## kc-portrait: the layout switched (rotate / resize); the match state is untouched.
signal portrait_changed(on: bool)
## kc-cards-impl (H1): CANCEL on the docked card preview.
signal dock_cancel_pressed
## After every show_snapshot() (p12: the outcome preview recomputes on it).
signal snapshot_shown(snapshot: Dictionary)
## Long-press / right-click on a strip badge or tray box: &"score", &"deck", &"intel", &"supply",
## &"streak", &"menu", &"preview", &"killfeed", &"hand_tab".
signal rail_inspected(key: StringName)
## The hand tray changed state (TRAY_OPEN / TRAY_CLOSED / TRAY_PEEK).
signal tray_state_changed(state: StringName)
## A strip flyout opened (its key) or closed (&"").
signal flyout_changed(key: StringName)
## kc-ui3: long-press / right-click on a killstreak tile (its loadout item id).
signal item_inspected(item_id: StringName)
## kc-v2-ui: the Operator ability button was tapped / long-pressed (right-clicked).
signal ability_pressed
signal ability_inspected
## kc-syn-ui: long-press / right-click on a trait rail chip (&"player" / &"enemy", trait id).
signal trait_inspected(side: StringName, trait_id: StringName)

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const BoardFxLocator: GDScript = preload("res://scripts/fx/board_fx_locator.gd")
const MockMatchData: GDScript = preload("res://scripts/ui/mock_match_data.gd")
const BoardMetrics: GDScript = preload("res://scripts/ui/board_metrics.gd")
const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
const KillfeedEntry: GDScript = preload("res://scripts/fx/killfeed_entry.gd")
const KillstreakRow: GDScript = preload("res://scripts/ui/killstreak_row.gd")
const TraitRail: GDScript = preload("res://scripts/ui/trait_rail.gd")
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
const AbilityButton: GDScript = preload("res://scripts/ui/ability_button.gd")
const MatchIntro: GDScript = preload("res://scripts/ui/match_intro.gd")
const BossPlate: GDScript = preload("res://scripts/ui/boss_plate.gd")
const OrderStrip: GDScript = preload("res://scripts/fx/order_strip.gd")
const TutorialProgress: GDScript = preload("res://scripts/ui/tutorial/tutorial_progress.gd")
const HandGlowFx: GDScript = preload("res://scripts/fx/hand_glow_fx.gd")
## kc-syn-ui: a set callout stays this long before it folds into the rail.
const SET_CALLOUT_S: float = 1.2
const TRAY_OPEN: StringName = &"open"
const TRAY_CLOSED: StringName = &"closed"
const TRAY_PEEK: StringName = &"peek"
## Side margins only: the strip and the tray keep their own top / bottom pads (BoardMetrics).
const BASE_MARGIN: Vector2 = Vector2(6, 0)
const BASE_MARGIN_COMPACT: Vector2 = Vector2(6, 0)
const TOAST_SECONDS: float = 2.2
## Killfeed toasts: 2.5 s (feed_life 4 s x 0.625), 2 at most; the tray log keeps up to 8 lines.
const KILL_TOAST_LIFE: float = 0.625
const KILL_TOAST_LINES: int = 2
const LOG_LINES: int = 8
const TRAY_FADE: float = 0.2
const FLYOUT_W: float = 360.0
const FLYOUT_W_DESKTOP: float = 380.0
const ZONE_LETTERS: Dictionary = {&"left": "A", &"mid": "B", &"right": "C"}

## Fill the screen with the mock snapshot on _ready (off once p04 drives the match).
@export var use_mock_data: bool = true

@onready var _safe_area: MarginContainer = %SafeArea
@onready var _layout: Control = %Layout
@onready var _strip: Control = %IconStrip
@onready var _menu_button: Button = %MenuButton
@onready var _preview_button: Button = %PreviewButton
@onready var _score_badge: Control = %ScoreBadge
@onready var _operator_badge: Control = %OperatorBadge
@onready var _streak_badge: Control = %StreakBadge
@onready var _rival_badge: Control = %RivalBadge
@onready var _deck_badge: Control = %DeckBadge
@onready var _board: Control = %Board
@onready var _toasts: Control = %KillfeedToasts
@onready var _peek_catcher: Control = %PeekCatcher
@onready var _tray: Control = %HandTray
@onready var _supply_box: PanelContainer = %SupplyCounter
@onready var _supply_value: Label = %SupplyValue
@onready var _supply_pips: HBoxContainer = %SupplyPips
@onready var _hand: Control = %HandArea
@onready var _feed_box: VBoxContainer = %FeedBox
@onready var _step_header: Label = %StepHeader
@onready var _killfeed: VBoxContainer = %KillfeedSlot
@onready var _killfeed_fx: Control = %Killfeed
@onready var _hand_tab: Button = %HandTab
@onready var _undo_button: Button = %UndoButton
@onready var _ready_button: Button = %ReadyButton
@onready var _speed_button: Button = %SpeedButton
@onready var _flyout: Control = %Flyout
@onready var _flyout_scrim: ColorRect = %FlyoutScrim
@onready var _flyout_panel: PanelContainer = %FlyoutPanel
@onready var _flyout_title: Label = %FlyoutTitle
@onready var _flyout_hint: Label = %FlyoutHint
@onready var _score_bar: Control = %ScoreBar
@onready var _operator_panel: Control = %OperatorPanel
@onready var _minimap: Control = %Minimap
@onready var _deck_box: PanelContainer = %DeckBox
@onready var _deck_value: Label = %DeckValue
@onready var _used_value: Label = %UsedValue
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel
@onready var _drag_layer: Control = %DragLayer
@onready var _inspector: Control = %Inspector
@onready var _fx: Control = %FeedbackDirector
@onready var _mulligan: Control = %MulliganPanel
@onready var _preview: Control = %OutcomePreview
@onready var _end_banner: Control = %MatchEndBanner
@onready var _pause_menu: Control = %PauseMenu

## True while the phone layout is active (logical height < ScreenProfile.COMPACT_HEIGHT).
var compact: bool = false
## kc-portrait: the portrait layout is on (the screen is taller than wide).
var portrait: bool = false
## Safe rect in canvas px (inside get_viewport_rect()); tests set it to simulate a notched
## phone. Empty = read DisplayServer.get_display_safe_area() on mobile.
var safe_area_override: Rect2 = Rect2()
## Mirror layout (tray left, strip right); follows Settings.mirror_layout unless a test sets it.
var mirror: bool = false
var _profile_set: bool = false
var _ghost: Control = null
var _toast_id: int = 0
## BoardMetrics of the current layout.
var metrics: Dictionary = {}
var _gestures: Array = []
var tray_state: StringName = TRAY_OPEN
var _deploy_open: bool = true
var _phase: String = ""
var _hand_count: int = 0
## Which flyout is open (&"" = none): &"score", &"operator", &"streak", &"rival", &"deck".
var flyout_key: StringName = &""
var _operator_can_deploy: bool = false
var _flyout_dragging: bool = false
var _streak_callout_shown: bool = false
## kc-ui3: the killstreak tiles at the top of the tray, and the killstreaks already announced ready.
var _ks_row: Control = null
var _ks_announced: Dictionary = {}
var _supply_stacked: bool = false
## kc-juice: the Supply shown last ([supply, supply_max]), to burst the hexes just spent.
var _last_supply: Vector2i = Vector2i(-1, -1)
## kc-juice: pip indices burst by the last _set_supply() (tests).
var last_supply_spent: Array[int] = []
const SupplySpendFx: GDScript = preload("res://scripts/fx/supply_spend_fx.gd")
const SfxBankScript: GDScript = preload("res://scripts/fx/sfx_bank.gd")
var _supply_stack: VBoxContainer = null
## kc-syn-ui: the trait rail (icon strip), the SETS flyout body, the last known tiers per side
## (set callouts fire when a tier switches on / off) and the callouts on screen.
var _trait_rail: Control = null
## kc-onboard-ui: the initiative chip, the "New: X" explainer, and the progressive reveal of this board
## (match_snapshot.reveal_info: trait rail / links / bands shown?).
var _initiative: InitiativeChip = null
var _new_card: NewCard = null
var _reveal: Dictionary = {}
var _rail_area: Rect2 = Rect2()
var _sets_box: VBoxContainer = null
var _syn_tiers: Dictionary = {&"player": {}, &"enemy": {}}
var _syn_doctrine: Dictionary = {&"player": &"", &"enemy": &""}
var _syn_snapshot: Dictionary = {}
var _set_callouts: Dictionary = {}
var _last_callout_text: String = ""
## kc-fight-ui: the A -> B -> C order strip under the tray header while the round plays.
var _order_strip: Control = null
## kc-fight-ui (head, kc-syn-ui answers): the round whose Deploy already glowed its set-completing cards.
var _glow_round: int = -1
var _last_glow: Array[int] = []
var _fight_caption: Label = null


func _ready() -> void:
	# p14 combat feedback: the director finds unit slots by uid on the board; the score and streak
	# anchors are the strip badges (their flyouts are usually closed).
	_fx.locator = BoardFxLocator.new(_board)
	_fx.locator.anchors[&"score"] = _score_badge
	_fx.locator.anchors[&"streak"] = _streak_badge
	_fx.streak_arc = _operator_panel.get_streak_arc()
	# Killfeed: the director pushes toasts (over the board); each push is copied to the tray log.
	_toasts.centered = true
	_toasts.line_cap = KILL_TOAST_LINES
	_toasts.life_scale = KILL_TOAST_LIFE
	_toasts.mirror = _killfeed_fx
	_killfeed_fx.persistent = true
	_killfeed_fx.left_aligned = true
	_killfeed_fx.line_cap = LOG_LINES
	_fx.killfeed = _toasts
	if _fx.has_signal(&"event_started"):
		_fx.event_started.connect(_on_fx_event)
	if _fx.has_signal(&"sequence_started"):
		_fx.sequence_started.connect(func(_n: int) -> void: _apply_speed(true))
	if _fx.has_signal(&"sequence_finished"):
		_fx.sequence_finished.connect(func() -> void:
			_apply_speed(false)
			if _order_strip != null:
				_order_strip.finish())
	_order_strip = OrderStrip.new()
	_order_strip.name = "OrderStrip"
	_feed_box.add_child(_order_strip)
	_feed_box.move_child(_order_strip, _step_header.get_index() + 1)
	_order_strip.visible = false
	# kc-fight-ui (head): one plain line per shot of the beat, under the strip.
	_fight_caption = Label.new()
	_fight_caption.name = "FightCaption"
	_fight_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fight_caption.add_theme_font_override(&"font", preload("res://assets/fonts/Barlow-Medium.ttf"))
	_fight_caption.add_theme_font_size_override(&"font_size", 17)
	_fight_caption.add_theme_color_override(&"font_color", Color("#F2F5F7"))
	_fight_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed_box.add_child(_fight_caption)
	_feed_box.move_child(_fight_caption, _order_strip.get_index() + 1)
	_fight_caption.visible = false
	if _fx.has_signal(&"caption_changed"):
		_fx.caption_changed.connect(_on_fight_caption)
	tree_exiting.connect(func() -> void: Engine.time_scale = 1.0)
	var settings: Node = get_node_or_null(^"/root/Settings")
	if settings != null:
		mirror = bool(settings.get(&"mirror_layout"))
		settings.settings_changed.connect(_on_settings_changed)
	_ks_row = KillstreakRow.new()
	_ks_row.name = "KillstreakRow"
	_tray.add_child(_ks_row)
	_tray.move_child(_ks_row, _supply_box.get_index() + 1)
	_setup_v2()
	# kc-onboard-ui: who holds initiative this round (and why), above the trait rail.
	_initiative = InitiativeChip.new()
	_strip.add_child(_initiative)
	_initiative.tapped.connect(func() -> void:
		close_flyout()
		rail_inspected.emit(&"initiative"))
	_initiative.inspected.connect(func() -> void:
		close_flyout()
		rail_inspected.emit(&"initiative"))
	_new_card = NewCard.new()
	add_child(_new_card)
	_trait_rail = TraitRail.new()
	_trait_rail.name = "TraitRail"
	_strip.add_child(_trait_rail)
	_trait_rail.tapped.connect(func() -> void: toggle_flyout(&"traits"))
	# kc-cards-impl: the rail highlight shows that trait on every board card.
	_trait_rail.focus_changed.connect(func(t: StringName) -> void: get_board().set_syn_focus(t))
	_trait_rail.inspected.connect(func() -> void:
		close_flyout()
		rail_inspected.emit(&"traits"))
	_trait_rail.chip_inspected.connect(func(side: StringName, t: StringName) -> void:
		close_flyout()
		trait_inspected.emit(side, t))
	_update_profile()
	resized.connect(_update_profile)
	_layout.resized.connect(_layout_regions)
	_setup_strip()
	_setup_tray()
	_setup_flyout()
	get_viewport().size_changed.connect(_apply_safe_area)
	_ready_button.pressed.connect(func() -> void: ready_pressed.emit())
	_menu_button.pressed.connect(func() -> void:
		close_flyout()
		menu_pressed.emit())
	_undo_button.pressed.connect(func() -> void: undo_pressed.emit())
	_add_glyph(_undo_button, &"undo")
	# kc-readability: the Supply count in the cards' number face, bigger.
	_supply_value.add_theme_font_override(&"font", CardLook.NUM_FONT)
	_supply_value.add_theme_font_size_override(&"font_size", 22)
	_supply_value.add_theme_constant_override(&"outline_size", CardLook.NUM_OUTLINE)
	_supply_value.add_theme_color_override(&"font_outline_color", CardLook.INK)
	# kc-cards-impl (O2): READY / UNDO fit the narrow column next to the Operator card.
	_ready_button.clip_text = true
	# kc-ui-wire2: READY draws the kit's btn_primary plate through the ReadyButton theme slot. btn_ready
	# is not used: its hazard stripes take 51 px of a ~105 px phone button and cover the word READY.
	_undo_button.clip_text = true
	_undo_button.tooltip_text = "Undo the last play"
	_setup_dock()
	if use_mock_data:
		show_snapshot(MockMatchData.round_3_sample())


## Renders a full match snapshot (shape: mock_match_data.gd).
func show_snapshot(snapshot: Dictionary) -> void:
	_score_bar.set_score(snapshot)
	_minimap.set_intel(snapshot.get("lanes", []))
	_board.set_lanes(snapshot.get("lanes", []))
	_operator_panel.set_operator(snapshot)
	_minimap.set_rival_hand(int(snapshot.get("enemy_hand", 0)))
	_deck_value.text = str(int(snapshot.get("deck_count", 0)))
	_used_value.text = str(int(snapshot.get("discard_count", 0)))
	_hand.set_operator(operator_card_entry(snapshot))
	_hand.set_hand(snapshot.get("hand", []))
	_ks_row.set_killstreaks(snapshot.get("killstreaks", []), int(snapshot.get("streak", 0)))
	_set_supply(int(snapshot.get("supply", 0)), int(snapshot.get("supply_max", 0)))
	_set_actions(snapshot)
	_set_badges(snapshot)
	_reveal = snapshot.get("reveal", {})
	if _initiative != null:
		_initiative.set_info(snapshot.get("initiative", {}))
	_set_synergy(snapshot.get("synergy", {}))
	_follow_phase(snapshot)
	_set_v2(snapshot)
	snapshot_shown.emit(snapshot)


func get_hand() -> Control:
	return _hand


func get_operator_panel() -> Control:
	return _operator_panel


## The Operator's handle (QA, tests, the tutorial): kc-ui3 the Operator card in the hand tray (the
## OPERATOR badge when the tray hides the hand).
func get_operator_handle() -> Control:
	var card: Control = _hand.get_operator_card()
	return card if card != null and card.is_visible_in_tree() else _operator_badge


## kc-ui3: the killstreak tiles at the top of the tray.
func get_killstreak_row() -> Control:
	return _ks_row


## The tile of one killstreak (loadout item id), or null.
func get_killstreak_tile(item_id: StringName) -> Control:
	return _ks_row.get_tile(item_id) if _ks_row != null else null


## kc-ui3: shows what is selected outside the hand cards: the Operator card and the killstreak tile
## being targeted (match_controller.gd _show_selection()).
func show_selection_state(operator_selected: bool, item_id: StringName) -> void:
	_hand.set_operator_selected(operator_selected)
	_ks_row.set_selected(item_id)
	_selected_item = item_id
	_refresh_ability()


## kc-ui3: the hand tray's Operator card from a snapshot ({} = no Operator). state: &"deploy" (it can
## be placed now), &"planned" (placed this Deploy), &"board", &"down" (off the board, not placeable),
## &"none"; status = the words on the card; active = a tap selects it (else a tap inspects).
static func operator_card_entry(snapshot: Dictionary) -> Dictionary:
	var op: Dictionary = snapshot.get("operator", {})
	if op.is_empty() or String(op.get("name", "")) in ["", "NO OPERATOR"]:
		return {}
	var open: bool = bool(snapshot.get("deploy_open", false)) and StringName(snapshot.get("result", &"")) == &""
	var e: Dictionary = op.duplicate()
	var on_board: bool = bool(op.get("on_board", String(op.get("zone", "OFF BOARD")) != "OFF BOARD"))
	var planned: String = String(op.get("planned_zone", ""))
	if bool(snapshot.get("operator_can_deploy", false)):
		e["state"] = &"deploy"
		e["status"] = "DEPLOY"
	elif planned != "":
		e["state"] = &"planned"
		e["status"] = "PLAN · %s" % planned
	elif on_board:
		e["state"] = &"board"
		var where: String = String(op.get("zone_label", ""))
		e["status"] = "ON BOARD\n%s · ROW %d" % [where, int(op.get("row", 1))] if where != "" else "ON BOARD"
	else:
		e["state"] = &"down"
		e["status"] = "DOWN\n%s" % ("NEXT ROUND" if bool(op.get("respawns", true)) else "NO RESPAWN")
	# Tap selects it in Deploy (place, or Rotate from the board); otherwise a tap shows its rules.
	e["active"] = open and e["state"] != &"down"
	e["draggable"] = e["active"]
	return e


## Strip badge by key: &"menu", &"score", &"operator", &"streak", &"rival", &"preview", &"deck".
func get_badge(key: StringName) -> Control:
	if key == &"rival" and rival_in_score():
		return _score_badge
	return {&"menu": _menu_button, &"score": _score_badge, &"operator": _operator_badge, &"streak": _streak_badge,
			&"rival": _rival_badge, &"preview": _preview_button, &"deck": _deck_badge, &"traits": _trait_rail}.get(key, null)


## kc-fight-ui: the phone strip has no RIVAL badge; SCORE carries the rival's hand count and intel.
func rival_in_score() -> bool:
	return compact


## kc-syn-ui: the trait rail in the icon strip.
func get_trait_rail() -> Control:
	return _trait_rail


## Set callouts on screen now (tests / QA): their texts.
func get_set_callouts() -> PackedStringArray:
	var out: PackedStringArray = []
	for k: Variant in _set_callouts:
		var c: Variant = _set_callouts[k]
		if is_instance_valid(c) and (c as Control).visible:
			out.append(String(((c as Control).get_child(0) as Label).text))
	return out


## The last set callout text shown (stays after it faded; tests / QA).
func get_last_set_callout() -> String:
	return _last_callout_text


## Links, rail and tiers from a snapshot's synergy block (kc-syn-ui).
func _set_synergy(syn: Dictionary) -> void:
	if syn.is_empty():
		_trait_rail.set_rails([], [], not compact)
		return
	_syn_snapshot = syn
	var me: Dictionary = syn.get("player", {})
	var foe: Dictionary = syn.get("enemy", {})
	# kc-onboard-ui: the trait rail appears once met, or while something in play uses it.
	# (kc-pos-cut: no link ticks any more.)
	var rail_on: bool = bool(_reveal.get("trait_rail", true))
	_trait_rail.set_rails(me.get("rail", []) if rail_on else [], foe.get("rail", []) if rail_on else [], not compact)
	_trait_rail.set_meta(&"revealed", rail_on)
	_layout_strip_extras()
	for pair: Array in [[&"player", me], [&"enemy", foe]]:
		_syn_tiers[pair[0]] = (pair[1].get("tiers", {}) as Dictionary).duplicate()
		_syn_doctrine[pair[0]] = StringName(pair[1].get("doctrine", &""))
	if flyout_key == &"traits":
		_fill_sets_box()


## A SYNERGY_CHANGED event while the round plays: update the rail and the ticks, and call out each
## tier that switched on ("UNDEAD 2: Undead heal 1 at the end of the round") or off (crack tick).
func on_synergy_event(ev: Dictionary) -> void:
	var side: StringName = StringName(ev.get("side", &"player"))
	var counts: Dictionary = ev.get("counts", {})
	var sets: Dictionary = ev.get("sets", {})
	var rail: Array = []
	for t: StringName in SynergyRules.TRAITS:
		var n: int = int(counts.get(t, 0))
		if n <= 0:
			continue
		var tier: int = int(sets.get(t, 0))
		rail.append({"trait": t, "name": SynergyGlyphs.trait_name(t), "count": n, "tier": tier,
				"next": SynergyRules.TIER2 if tier < 2 else (SynergyRules.TIER3 if tier < 3 else 0),
				"doctrine": t == _syn_doctrine.get(side, &"")})
	var rails: Dictionary = _trait_rail.rails.duplicate(true)
	rails[side] = rail
	_trait_rail.set_rails(rails[&"player"], rails[&"enemy"], not compact)
	var before: Dictionary = _syn_tiers.get(side, {})
	var best_on: Array = []
	for t: StringName in SynergyRules.TRAITS:
		var was: int = int(before.get(t, 0))
		var now: int = int(sets.get(t, 0))
		if now > was and now >= 2:
			best_on = [t, now]
		elif now < was:
			_trait_rail.crack(side, t)
			if best_on.is_empty():
				show_set_callout(side, "%s %d OFF" % [SynergyGlyphs.trait_name(t).to_upper(), was], false)
	if not best_on.is_empty():
		var t2: StringName = best_on[0]
		show_set_callout(side, "%s %d: %s" % [SynergyGlyphs.trait_name(t2).to_upper(), int(best_on[1]),
				String(SynergyRules.TIER_TEXT[t2][0 if int(best_on[1]) <= 2 else 1])], true)
	_syn_tiers[side] = sets.duplicate()


## Set callout beside the trait rail (one per side at a time; ~1.2 s, then it folds into the rail).
func show_set_callout(side: StringName, text: String, on: bool) -> void:
	# (Variant: a callout that already folded away is a freed instance; a typed var would refuse it.)
	var old: Variant = _set_callouts.get(side, null)
	if is_instance_valid(old):
		(old as Node).queue_free()
	var panel := PanelContainer.new()
	panel.name = "SetCallout_%s" % side
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.theme_type_variation = &"TargetBadgeBad" if side == &"enemy" else &"TargetBadge"
	var l := Label.new()
	l.theme_type_variation = &"TargetText"
	l.text = text if on else text
	if not on:
		l.add_theme_color_override(&"font_color", Color("#C8D0D6"))
	panel.add_child(l)
	add_child(panel)
	panel.reset_size()
	_last_callout_text = text
	_set_callouts[side] = panel
	# Beside the rail, over the board's outer edge; the rival's sits higher (its rail is on top).
	var rr: Rect2 = _trait_rail.get_global_rect()
	var board_r: Rect2 = _board.get_global_rect()
	var x: float = rr.end.x + 6.0 if not mirror else rr.position.x - 6.0 - panel.size.x
	var y: float = rr.position.y + (rr.size.y - panel.size.y) * 0.5
	if side == &"enemy":
		y = board_r.position.y + board_r.size.y * 0.28
	elif not compact:
		y = rr.end.y - panel.size.y
	panel.position = Vector2(clampf(x, 0.0, maxf(0.0, size.x - panel.size.x)), clampf(y, 0.0, maxf(0.0, size.y - panel.size.y)))
	if _reduced_motion():
		panel.modulate.a = 1.0
	else:
		panel.modulate.a = 0.0
		panel.scale = Vector2(0.9, 0.9)
	var tw: Tween = panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(SET_CALLOUT_S)
	# Folds into the rail: shrinks toward it and fades.
	tw.tween_property(panel, "position", Vector2(rr.position.x, rr.get_center().y), 0.25)
	tw.parallel().tween_property(panel, "scale", Vector2(0.3, 0.3), 0.25)
	tw.parallel().tween_property(panel, "modulate:a", 0.0, 0.25)
	tw.tween_callback(panel.queue_free)


## SETS flyout: both sides' traits in play, their tier texts and what the next threshold gives.
func _fill_sets_box() -> void:
	if _sets_box == null:
		return
	for c: Node in _sets_box.get_children():
		_sets_box.remove_child(c)
		c.queue_free()
	var rails: Dictionary = _trait_rail.rails
	for side: StringName in [&"player", &"enemy"]:
		var head := Label.new()
		head.theme_type_variation = &"KeywordName"
		head.text = "YOUR SETS" if side == &"player" else "RIVAL SETS"
		head.add_theme_color_override(&"font_color", get_theme_color(&"friend" if side == &"player" else &"enemy", &"Hud"))
		_sets_box.add_child(head)
		var list: Array = rails.get(side, [])
		if list.is_empty():
			_sets_box.add_child(_flyout_line("No traits in play. Units and Fields with the same trait count together: 2 in play turn tier 2 on, 3 turn tier 3 on."))
		for e: Dictionary in list:
			var t: StringName = StringName(e["trait"])
			var tier: int = int(e.get("tier", 0))
			var bits: PackedStringArray = ["%s %d in play%s" % [SynergyGlyphs.trait_name(t), int(e["count"]), " (Doctrine +1)" if bool(e.get("doctrine", false)) else ""]]
			if tier >= 2:
				bits.append("ON: " + SynergyGlyphs.tier_line(t, tier))
			if int(e.get("next", 0)) > 0:
				bits.append("at %d: %s" % [int(e["next"]), String(SynergyRules.TIER_TEXT[t][0 if int(e["next"]) <= 2 else 1])])
			_sets_box.add_child(_flyout_line(". ".join(bits) + "."))


func _flyout_line(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = (FLYOUT_W if compact else FLYOUT_W_DESKTOP) - 24.0
	return l


func get_inspector() -> Control:
	return _inspector


## p14 FeedbackDirector (plays the engine's events after READY).
func get_fx() -> Control:
	return _fx


## f02 Round 1 mulligan panel.
func get_mulligan_panel() -> Control:
	return _mulligan


## p12 outcome preview overlay (scenes/match/OutcomePreview.tscn) and its strip toggle.
func get_preview() -> Control:
	return _preview


func get_preview_button() -> Button:
	return _preview_button


## f03 match result banner (scenes/match/MatchEndBanner.tscn).
func get_end_banner() -> Control:
	return _end_banner


## f03 pause sheet opened by MENU (scenes/match/PauseMenu.tscn).
func get_pause_menu() -> Control:
	return _pause_menu


func get_menu_button() -> Button:
	return _menu_button


func get_undo_button() -> Button:
	return _undo_button


func get_ready_button() -> Button:
	return _ready_button


func get_hand_tab() -> Button:
	return _hand_tab


func get_speed_button() -> Button:
	return _speed_button


func get_tray() -> Control:
	return _tray


## Short message over the board (refusal reasons, hints). Hides itself after TOAST_SECONDS.
func show_toast(text: String) -> void:
	_toast_id += 1
	var my_id: int = _toast_id
	_toast_label.text = text
	_toast.show()
	_toast.reset_size()
	# Centred over the board (not the whole screen: the tray is beside it).
	var board_r: Rect2 = _board.get_global_rect()
	var cx: float = board_r.get_center().x if board_r.has_area() else size.x * 0.5
	_toast.position.x = clampf(cx - _toast.size.x * 0.5, 0.0, maxf(0.0, size.x - _toast.size.x))
	# kc-cards-impl: at the board's bottom edge (your back row), never over the objective row; the
	# killfeed toasts keep the top edge.
	if board_r.has_area():
		_toast.global_position.y = board_r.end.y - _toast.size.y - 4.0
	get_tree().create_timer(TOAST_SECONDS).timeout.connect(func() -> void:
		if my_id == _toast_id:
			_toast.hide())


func get_toast_text() -> String:
	return _toast_label.text if _toast.visible else ""


## A copy of `source` (a hand chip, or the Operator handle) that follows the pointer.
func begin_drag_ghost(source: Control, pos: Vector2) -> void:
	end_drag_ghost()
	var ghost: Control = source.duplicate(0) as Control
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for n: Node in ghost.find_children("*", "Control", true, false):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.modulate = Color(1, 1, 1, 0.9)
	ghost.size = source.size
	_drag_layer.add_child(ghost)
	_ghost = ghost
	move_drag_ghost(pos)


func move_drag_ghost(pos: Vector2) -> void:
	if _ghost != null:
		# Centred on the finger, a little above it so the finger doesn't hide the card.
		_ghost.position = pos - Vector2(_ghost.size.x * 0.5, _ghost.size.y * 0.8)


func end_drag_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null


func has_drag_ghost() -> bool:
	return _ghost != null


func _set_actions(snapshot: Dictionary) -> void:
	var open: bool = bool(snapshot.get("deploy_open", true))
	_ready_button.disabled = not open
	var result: StringName = snapshot.get("result", &"")
	if result != &"":
		_ready_button.text = {&"player": "WON", &"enemy": "LOST"}.get(result, "DRAW")
	else:
		_ready_button.text = "READY" if open else "WAIT"
	fit_button_text(_ready_button)
	_undo_button.disabled = not bool(snapshot.get("can_undo", false))
	var label: String = String(snapshot.get("undo_label", ""))
	# kc-cards-impl (O2): UNDO is an icon (a curved back arrow) over READY; the tooltip names the play.
	_undo_button.text = ""
	_undo_button.tooltip_text = "Undo %s" % label if not label.is_empty() else ""


## The controls that must stay on screen and never overlap (used by tests and QA). The tray's
## controls depend on its state (OPEN: hand, UNDO, READY; otherwise the log, the tab, SPEED).
func get_key_controls() -> Dictionary:
	var out: Dictionary = {
		"menu": _menu_button, "score_bar": _score_badge, "operator_panel": _operator_badge,
		"streak": _streak_badge, "minimap": _rival_badge, "preview": _preview_button, "deck": _deck_badge,
		"board": _board, "supply": _supply_box,
	}
	if rival_in_score():
		# kc-fight-ui: the phone's SCORE badge carries the rival hand; the trait rail takes the slot.
		out.erase("minimap")
		# kc-onboard-ui: the slot holds the initiative chip until a trait is in play, then the rail.
		if _initiative != null and _initiative.visible:
			out["initiative"] = _initiative
		if _trait_rail.visible or not out.has("initiative"):
			out["traits"] = _trait_rail
	elif _initiative != null and _initiative.visible:
		out["initiative"] = _initiative
	if tray_state == TRAY_OPEN:
		out.merge({"hand": _hand, "undo": _undo_button, "ready": _ready_button})
		if not _ks_row.get_tiles().is_empty():
			out["killstreaks"] = _ks_row
	else:
		out.merge({"hand_tab": _hand_tab, "speed": _speed_button})
		if tray_state == TRAY_PEEK:
			out["hand"] = _hand
		else:
			out["killfeed"] = _feed_box
	return out


func get_board() -> Control:
	return _board


## Labels whose whole text must stay on screen (no clipping or ellipsis), for tests and QA.
func get_important_labels() -> Array[Label]:
	var out: Array[Label] = [_supply_value, _deck_value, _used_value]
	out.append_array(_score_bar.get_important_labels())
	out.append_array(_minimap.get_important_labels())
	for lane: Node in _board.get_lanes():
		out.append_array(lane.get_important_labels())
	out.append_array(_operator_panel.get_important_labels())
	out.append_array(_hand.get_important_labels())
	return out


## Switches between the desktop and compact (phone) layout from the logical height.
func _update_profile() -> void:
	# kc-portrait: a tall screen uses the portrait layout (phone sizes, top bars, the fan hand).
	var tall: bool = size.x > 0.0 and BoardMetrics.is_portrait(size)
	var want: bool = (size.y > 0.0 and size.y < ScreenProfile.COMPACT_HEIGHT) or tall
	if want == compact and tall == portrait and _profile_set:
		return
	_profile_set = true
	var turned: bool = tall != portrait
	portrait = tall
	compact = want
	if turned:
		close_flyout()
		_hand.set_fan(portrait)
		portrait_changed.emit(portrait)
	_board.set_compact(compact)
	_operator_panel.set_compact(compact)
	_hand.set_compact(compact)
	_minimap.set_compact(compact)
	_mulligan.set_compact(compact)
	_end_banner.set_compact(compact)
	_pause_menu.set_compact(compact)
	# kc-ui3: the desktop tray (224 px) wraps each log line to two rows instead of cutting names.
	_killfeed_fx.two_line = not compact
	_supply_pips.add_theme_constant_override(&"separation", 3)
	_apply_safe_area()
	_layout_regions.call_deferred()


## Mirror layout on / off (Settings.mirror_layout, or a test).
func set_mirror(value: bool) -> void:
	if value == mirror:
		return
	mirror = value
	close_flyout()
	_layout_regions()


func _on_settings_changed() -> void:
	var settings: Node = get_node_or_null(^"/root/Settings")
	if settings != null:
		set_mirror(bool(settings.get(&"mirror_layout")))


## Places the strip, the board and the tray from BoardMetrics (board-layout-v2.md §2).
func _layout_regions() -> void:
	var area: Vector2 = _layout.size
	if area.x <= 0.0 or area.y <= 0.0:
		return
	metrics = BoardMetrics.compute(area, compact, mirror)
	var board_rect: Rect2 = metrics["board"]
	_board.position = board_rect.position
	_board.size = board_rect.size
	_board.set_metrics(metrics)
	# Icon strip.
	var strip: Rect2 = metrics["strip"]
	_strip.position = strip.position
	_strip.size = strip.size
	var rects: Array[Rect2] = BoardMetrics.badge_rects(metrics)
	var badges: Array[Control] = [_menu_button, _score_badge, _operator_badge, _streak_badge, _rival_badge, _preview_button, _deck_badge]
	# kc-fight-ui (head, kc-syn-ui answers): on the phone RIVAL folds into SCORE (its hand count is the
	# SCORE badge's third line, its intel is in the SCORE flyout); PREVIEW moves up into its slot, so
	# the trait rail gets a whole badge slot more (>= 44 pt).
	var merged: bool = rival_in_score()
	_rival_badge.visible = not merged
	for i: int in badges.size():
		var ri: int = i
		if merged and badges[i] == _preview_button:
			ri = 4
		badges[i].position = rects[ri].position
		badges[i].size = rects[ri].size
		badges[i].custom_minimum_size = rects[ri].size
		badges[i].queue_redraw()
	# kc-syn-ui: the trait rail fills the strip between PREVIEW and DECK.
	var rail_r: Rect2 = BoardMetrics.rail_rect(metrics)
	if merged and not bool(metrics.get("portrait", false)):
		var top: float = rects[4].end.y + float(metrics["badge_gap"])
		rail_r = Rect2(0, top, rail_r.size.x, maxf(0.0, rects[6].position.y - float(metrics["badge_gap"]) - top))
	_rail_area = rail_r
	_layout_strip_extras()
	_trait_rail.set_rails(_trait_rail.rails.get(&"player", []), _trait_rail.rails.get(&"enemy", []), not compact)
	# Killfeed toasts: top centre of the board, over the rival's back row.
	var tw: float = minf(board_rect.size.x - 16.0, 460.0)
	_toasts.position = Vector2(board_rect.position.x + (board_rect.size.x - tw) * 0.5, board_rect.position.y + 4.0)
	_toasts.size = Vector2(tw, KillfeedEntry.ROW_HEIGHT * KILL_TOAST_LINES + 2.0)
	# Tray.
	var tray: Rect2 = metrics["tray"]
	_tray.position = tray.position
	_tray.size = tray.size
	_peek_catcher.position = Vector2.ZERO
	_peek_catcher.size = area
	_layout_tray()


## kc-onboard-ui: the initiative chip takes the top of the rail's area (one badge slot: phone 62x64,
## desktop 68x64); the trait rail fills the rest. On the phone the rail's area holds one of them: the
## chip while no trait is in play / revealed (M1), the rail after (the SCORE flag keeps initiative).
func _layout_strip_extras() -> void:
	var r: Rect2 = _rail_area
	if _initiative == null or r.size.y <= 0.0:
		return
	var ch: float = float(metrics.get("badge_h", 64.0))
	var gap: float = float(metrics.get("badge_gap", 5.0))
	var in_use: bool = not (_trait_rail.rails.get(&"player", []) as Array).is_empty() or not (_trait_rail.rails.get(&"enemy", []) as Array).is_empty()
	var rail_on: bool = bool(_trait_rail.get_meta(&"revealed", true)) and in_use
	_initiative.position = r.position
	_initiative.size = Vector2(r.size.x, minf(ch, r.size.y))
	# The phone strip has no room for both (the head's kc-fight-ui answer gives the rail a full badge
	# slot): once the rail is in use the SCORE badge's flag carries initiative (tap SCORE for why).
	_initiative.visible = not _initiative.info.is_empty() and (r.size.y >= 2.0 * ch + gap or not rail_on)
	var top: float = r.position.y + (ch + gap if _initiative.visible else 0.0)
	_trait_rail.position = Vector2(r.position.x, top)
	_trait_rail.size = Vector2(r.size.x, maxf(0.0, r.end.y - top))
	_trait_rail.visible = _trait_rail.size.y >= 30.0 and bool(_trait_rail.get_meta(&"revealed", true))
	_initiative.queue_redraw()


## The initiative chip (tests, QA).
func get_initiative_chip() -> InitiativeChip:
	return _initiative


## The "New: X" explainer (tests, QA).
func get_new_card() -> NewCard:
	return _new_card


## Shows the first pending "New:" explainer among `relevant` (one per round: key "round<n>").
func offer_explainer(relevant: Array, key: String) -> StringName:
	return _new_card.offer(relevant, key) if _new_card != null else &""


func _layout_tray() -> void:
	if metrics.is_empty():
		return
	var w: float = _tray.size.x
	var h: float = _tray.size.y
	var btn_h: float = metrics["btn_h"]
	var tab_h: float = metrics["tab_h"]
	_set_supply_stacked(bool(metrics.get("ks_inline", false)))
	_place(_supply_box, metrics.get("supply", Rect2(0, 0, w, metrics["supply_h"])))
	_place(_ks_row, metrics.get("ks", Rect2()))
	_fit_pips()
	# kc-cards-impl (H1 + O2): the HandArea covers the card grid and the Operator row under it; the
	# Operator card sits bottom-left, UNDO (icon) over READY bottom-right.
	var hr: Rect2 = metrics["hand_rect"]
	# kc-portrait: the fan hand (Y2+ cards) in portrait, the X1 grid otherwise.
	_hand.fan_step = float(metrics.get("fan_step", 68.0))
	_hand.set_fan(bool(metrics.get("fan", false)))
	_place(_hand, hr)
	var grid: Rect2 = metrics["grid"]
	_hand.set_grid_rect(Rect2(grid.position - hr.position, grid.size), Rect2((metrics["op_card"] as Rect2).position - hr.position, (metrics["op_card"] as Rect2).size))
	_hand.set_card_size(metrics["card"], metrics["card_gap"], int(metrics["hand_cols"]), 1.0 if mirror else -1.0, float(metrics["bh"]))
	_place(_undo_button, metrics["undo"])
	_place(_ready_button, metrics["ready"])
	fit_button_text(_ready_button)
	_layout_dock()
	_layout_ability()
	_place(_speed_button, Rect2(0, h - btn_h, w, btn_h))
	var tab_y: float = h - btn_h - 8.0 - tab_h
	_place(_hand_tab, Rect2(0, tab_y, w, tab_h))
	var feed_top: float = float(metrics["supply_h"]) + 8.0
	_place(_feed_box, Rect2(0, feed_top, w, maxf(0.0, tab_y - 8.0 - feed_top)))


# =============================================================================
# kc-cards-impl (H1): the selected card's Y2+ preview docked over the top of the tray
# =============================================================================

const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/match/CardView.tscn")
var _dock: Control = null
var _dock_card: CardView = null
var _dock_cancel: Button = null
var _dock_hint: Label = null


func _setup_dock() -> void:
	_dock = Panel.new()
	_dock.name = "CardDock"
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.055, 0.94)
	sb.border_color = Color("#FFB020")
	sb.border_width_bottom = 2
	_dock.add_theme_stylebox_override(&"panel", sb)
	_dock.visible = false
	_dock.tooltip_text = "The selected card: tap it (or CANCEL) to put it back; long press for its rules"
	# The dock IS the selected card: a tap on it = "tap the card again" (cancel); long press = rules.
	var g: RefCounted = PressGesture.new(_dock)
	g.drag_enabled = false
	_dock.gui_input.connect(func(e: InputEvent) -> void:
		if g.handle(e):
			_dock.accept_event())
	g.tapped.connect(func(_p: Vector2) -> void: dock_cancel_pressed.emit())
	g.long_pressed.connect(func(_p: Vector2) -> void:
		var uid: int = int(_hand.selected_uid)
		if uid >= 0:
			_hand.card_inspected.emit(uid))
	_tray.add_child(_dock)
	_dock_card = CARD_VIEW_SCENE.instantiate() as CardView
	_dock_card.name = "DockCard"
	_dock_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(_dock_card)
	_dock_cancel = Button.new()
	_dock_cancel.name = "DockCancel"
	_dock_cancel.text = "CANCEL"
	_dock_cancel.theme_type_variation = &"HudButton"
	_dock_cancel.tooltip_text = "Put the card back (or tap it again, or the empty board)"
	_dock_cancel.focus_mode = Control.FOCUS_ALL
	_dock_cancel.add_to_group(&"tap_target")
	_dock_cancel.pressed.connect(func() -> void: dock_cancel_pressed.emit())
	_dock.add_child(_dock_cancel)
	_dock_hint = Label.new()
	_dock_hint.name = "DockHint"
	_dock_hint.text = "TAP A\nPLAY HERE\nSLOT"
	_dock_hint.theme_type_variation = &"HudTag"
	_dock_hint.add_theme_font_size_override(&"font_size", 16)
	_dock_hint.add_theme_color_override(&"font_color", Color("#FFB020"))
	_dock_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(_dock_hint)


## Shows the selected card's Y2+ face over the top of the tray (view = CardView data; {} hides it).
func show_card_dock(view: Dictionary) -> void:
	if _dock == null:
		return
	if view.is_empty():
		_dock.visible = false
		return
	_dock_card.set_card_data(view)
	_dock.visible = true
	_layout_dock()
	_tray.move_child(_dock, -1)


## kc-portrait: the empty preview well ("TAP A CARD TO RAISE IT"), shown while nothing is raised.
var _well: Panel = null


func _layout_well() -> void:
	var on: bool = bool(metrics.get("portrait", false))
	if _well == null:
		if not on:
			return
		_well = Panel.new()
		_well.name = "PreviewWell"
		_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.05, 0.055, 0.5)
		sb.border_color = Color(0.85, 0.87, 0.89, 0.18)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(8)
		_well.add_theme_stylebox_override(&"panel", sb)
		var hint := Label.new()
		hint.name = "WellHint"
		hint.text = "TAP A CARD\nTO RAISE IT"
		hint.theme_type_variation = &"HudTag"
		hint.add_theme_font_size_override(&"font_size", 16)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_well.add_child(hint)
		hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_tray.add_child(_well)
		_tray.move_child(_well, 0)
	_well.visible = on and _hand.visible and not _hand.read_only
	if on:
		_place(_well, metrics["well"])


func get_preview_well() -> Control:
	return _well if _well != null and _well.visible else null


func get_card_dock() -> Control:
	return _dock if _dock != null and _dock.visible else null


func get_dock_card() -> CardView:
	return _dock_card


func get_dock_cancel_button() -> Button:
	return _dock_cancel


func _layout_dock() -> void:
	if _dock == null or metrics.is_empty():
		return
	_layout_well()
	if bool(metrics.get("portrait", false)):
		# kc-portrait: the raised card fills the preview well (left of the Operator), CANCEL under it.
		var wr: Rect2 = metrics["well"]
		var cw: float = minf(wr.size.x - 12.0, CardView.size_for(wr.size.x).x)
		while cw > 140.0 and CardView.height_for(cw) + 6.0 + 8.0 + 64.0 + 6.0 > wr.size.y:
			cw -= 4.0
		_dock_card.set_card_width(cw)
		_dock.position = wr.position
		_dock.size = wr.size
		_dock_card.position = Vector2((wr.size.x - cw) * 0.5, 6.0)
		_dock_cancel.position = Vector2(6.0, minf(wr.size.y - 70.0, 6.0 + _dock_card.size.y + 8.0))
		_dock_cancel.size = Vector2(wr.size.x - 12.0, 64.0)
		_dock_hint.visible = false
		return
	var w: float = _tray.size.x
	var wide: bool = w >= 330.0
	var cancel_w: float = 92.0 if wide else w - 12.0
	var card_w: float = minf(250.0, w - 12.0 - (cancel_w + 8.0 if wide else 0.0))
	_dock_card.set_card_width(card_w)
	var card_h: float = _dock_card.size.y
	var h: float = 6.0 + card_h + 8.0 + (0.0 if wide else 64.0 + 8.0)
	_dock.position = Vector2(0, 0)
	_dock.size = Vector2(w, h)
	_dock_card.position = Vector2(6, 6)
	if wide:
		_dock_cancel.position = Vector2(6.0 + card_w + 8.0, 6.0)
		_dock_cancel.size = Vector2(w - card_w - 20.0, 64.0)
		_dock_hint.visible = true
		_dock_hint.position = Vector2(_dock_cancel.position.x, 78.0)
		_dock_hint.size = Vector2(_dock_cancel.size.x, 80.0)
	else:
		_dock_cancel.position = Vector2(6.0, 6.0 + card_h + 8.0)
		_dock_cancel.size = Vector2(cancel_w, 64.0)
		_dock_hint.visible = false


func _place(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size


## kc-ipad-cards (the head's iPad shot: READY read "READ"): the button's text at its theme size, or
## smaller (down to 16 px) so the whole word fits inside its content box. Never clipped.
static func fit_button_text(b: Button) -> void:
	if b == null or b.size.x <= 0.0:
		return
	b.remove_theme_font_size_override(&"font_size")
	var fs: int = b.get_theme_font_size(&"font_size")
	var font: Font = b.get_theme_font(&"font")
	var sb: StyleBox = b.get_theme_stylebox(&"normal")
	var room: float = b.size.x - (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb != null else 0.0) - 4.0
	var size_now: int = fs
	while size_now > 16 and font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_now).x > room:
		size_now -= 1
	if size_now != fs:
		b.add_theme_font_size_override(&"font_size", size_now)


# =============================================================================
# Icon strip and flyouts
# =============================================================================

func _setup_strip() -> void:
	for pair: Array in [[_score_badge, &"score"], [_streak_badge, &"streak"], [_rival_badge, &"rival"], [_deck_badge, &"deck"]]:
		var b: Control = pair[0]
		var key: StringName = pair[1]
		b.tapped.connect(func() -> void: toggle_flyout(key))
		b.inspected.connect(func() -> void:
			close_flyout()
			rail_inspected.emit({&"rival": &"intel"}.get(key, key)))
	# OPERATOR: the Operator's handle while it can deploy, else its flyout.
	# kc-ui3: the OPERATOR badge is info only (tap = its flyout); the Operator deploys from its card
	# at the start of the hand tray, which forwards to the Operator panel's signals (the controller's).
	_operator_badge.tapped.connect(func() -> void: toggle_flyout(&"operator"))
	_operator_badge.inspected.connect(func() -> void:
		close_flyout()
		_operator_panel.operator_inspected.emit())
	_hand.operator_tapped.connect(func() -> void:
		close_flyout()
		_operator_panel.operator_tapped.emit())
	_hand.operator_inspected.connect(func() -> void: _operator_panel.operator_inspected.emit())
	_hand.operator_drag_started.connect(func(p: Vector2) -> void: _operator_panel.operator_drag_started.emit(p))
	_hand.operator_drag_moved.connect(func(p: Vector2) -> void: _operator_panel.operator_drag_moved.emit(p))
	_hand.operator_drag_ended.connect(func(p: Vector2) -> void: _operator_panel.operator_drag_ended.emit(p))
	# MENU and PREVIEW are real buttons; right-click / long-press opens their rules.
	_wire_button_inspect(_menu_button, &"menu")
	_wire_button_inspect(_preview_button, &"preview")
	_preview_button.set_meta(&"badge", true)
	_preview_button.pressed.connect(close_flyout)
	_add_glyph(_menu_button, &"menu")
	_add_glyph(_preview_button, &"eye")


## A long-press (touch) or right-click on a Button opens its rules instead of pressing it.
func _wire_button_inspect(b: Button, key: StringName) -> void:
	var state: Dictionary = {"id": 0, "fired": false}
	b.gui_input.connect(func(e: InputEvent) -> void:
		if not e is InputEventMouseButton:
			return
		var mb: InputEventMouseButton = e
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			b.accept_event()
			rail_inspected.emit(key)
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			state["id"] = int(state["id"]) + 1
			state["fired"] = false
			var my_id: int = state["id"]
			get_tree().create_timer(PressGesture.LONG_PRESS_S).timeout.connect(func() -> void:
				if int(state["id"]) == my_id and _is_held(b):
					state["fired"] = true
					rail_inspected.emit(key))
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			state["id"] = int(state["id"]) + 1
			if bool(state["fired"]):
				# The hold opened the rules: swallow the release so the button doesn't press.
				state["fired"] = false
				b.accept_event()
				if b.toggle_mode:
					b.set_pressed_no_signal(b.button_pressed))


func _is_held(b: Button) -> bool:
	return b.is_hovered() or b.get_global_rect().has_point(b.get_global_mouse_position())


## Small glyphs drawn on the MENU (three bars) and PREVIEW (an eye over ON / OFF) buttons.
func _add_glyph(b: Button, kind: StringName) -> void:
	var g: Control = Control.new()
	g.name = "Glyph"
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(g)
	g.draw.connect(func() -> void:
		var c: Color = b.get_theme_color(&"font_color")
		var s: float = 24.0
		# kc-ui-wire2: the kit's menu / undo / eye icons (ui_menu, ui_undo, ui_eye; ui_eye_off while
		# PREVIEW is off) in the same spot and colour; the drawn glyphs below are the fallback.
		var kit_id: StringName = {&"undo": &"ui_undo", &"menu": &"ui_menu"}.get(kind, &"ui_eye")
		if kind == &"eye" and b.toggle_mode and not b.button_pressed:
			kit_id = &"ui_eye_off"
		var kit_s: float = 26.0 if kind == &"undo" else s
		var kit_o: Vector2 = Vector2((b.size.x - kit_s) * 0.5, (b.size.y - kit_s) * 0.5 if kind != &"eye" else 6.0)
		if UiKit.draw_icon(g, kit_id, Rect2(kit_o, Vector2(kit_s, kit_s)), c if not b.disabled else Color(c, 0.4)):
			return
		var o: Vector2 = Vector2((b.size.x - s) * 0.5, (b.size.y - s) * 0.5 if kind == &"menu" else 6.0)
		if kind == &"undo":
			# A curved back arrow (UNDO is an icon over READY, kc-cards-impl O2).
			var k2: float = 26.0 / 24.0
			var u0: Vector2 = Vector2((b.size.x - 26.0) * 0.5, (b.size.y - 26.0) * 0.5)
			var col: Color = c if not b.disabled else Color(c, 0.4)
			g.draw_polyline(PackedVector2Array([u0 + Vector2(9, 14) * k2, u0 + Vector2(4, 9) * k2, u0 + Vector2(9, 4) * k2]), col, 2.6, true)
			var arc: PackedVector2Array = [u0 + Vector2(4, 9) * k2, u0 + Vector2(14, 9) * k2]
			for i: int in 13:
				var t: float = -PI * 0.5 + PI * i / 12.0
				arc.append(u0 + (Vector2(14, 15) + Vector2(cos(t), sin(t)) * 6.0) * k2)
			arc.append(u0 + Vector2(11, 21) * k2)
			g.draw_polyline(arc, col, 2.6, true)
			return
		if kind == &"menu":
			for i: int in 3:
				var y: float = o.y + 5.0 + i * 7.0
				g.draw_line(Vector2(o.x + 2.0, y), Vector2(o.x + s - 2.0, y), c, 2.6)
		else:
			var ctr: Vector2 = o + Vector2(s * 0.5, s * 0.5)
			var pts: PackedVector2Array = []
			for i: int in 25:
				var t: float = PI * i / 24.0
				pts.append(ctr + Vector2(-cos(t) * s * 0.48, -sin(t) * s * 0.3))
			for i: int in 25:
				var t: float = PI * i / 24.0
				pts.append(ctr + Vector2(cos(t) * s * 0.48, sin(t) * s * 0.3))
			g.draw_polyline(pts, c, 2.0)
			g.draw_circle(ctr, s * 0.14, c))
	b.resized.connect(func() -> void:
		g.size = b.size
		g.queue_redraw())
	b.toggled.connect(func(_on: bool) -> void: g.queue_redraw())


func _setup_flyout() -> void:
	_operator_panel.set_section(&"operator")
	_flyout_scrim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_flyout_scrim.accept_event()
			close_flyout())
	_operator_panel.killstreak_pressed.connect(func(_id: StringName) -> void: close_flyout.call_deferred())
	_operator_panel.operator_tapped.connect(func() -> void: close_flyout.call_deferred())
	_operator_panel.operator_inspected.connect(close_flyout)
	# Dragging the Operator out of its flyout: the flyout fades but keeps the gesture alive.
	_operator_panel.operator_drag_started.connect(func(_p: Vector2) -> void:
		if flyout_key != &"":
			_flyout_dragging = true
			_flyout.modulate.a = 0.0
			_flyout_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE)
	_operator_panel.operator_drag_ended.connect(func(_p: Vector2) -> void:
		if _flyout_dragging:
			close_flyout.call_deferred())
	for box: Array in [[_score_bar, &"score"], [_deck_box, &"deck"], [_minimap, &"intel"]]:
		_wire_box(box[0], box[1])


func toggle_flyout(key: StringName) -> void:
	if flyout_key == key:
		close_flyout()
	else:
		open_flyout(key)


## Opens a badge's flyout next to it: &"score", &"operator", &"streak", &"rival", &"deck".
func open_flyout(key: StringName) -> void:
	var badge: Control = get_badge(key)
	if badge == null:
		return
	flyout_key = key
	_flyout_dragging = false
	_flyout.modulate.a = 1.0
	_flyout_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	var merged: bool = rival_in_score() and key in [&"score", &"rival"]
	_score_bar.visible = key == &"score" or merged
	_operator_panel.visible = key == &"operator" or key == &"streak"
	if _operator_panel.visible:
		_operator_panel.set_section(key)
	_minimap.visible = key == &"rival" or merged
	_deck_box.visible = key == &"deck"
	if _sets_box == null:
		_sets_box = VBoxContainer.new()
		_sets_box.name = "SetsBox"
		_sets_box.add_theme_constant_override(&"separation", 6)
		_flyout_hint.get_parent().add_child(_sets_box)
		_flyout_hint.get_parent().move_child(_sets_box, _flyout_hint.get_index())
	_sets_box.visible = key == &"traits"
	if key == &"traits":
		_fill_sets_box()
	_flyout_title.text = {&"score": "SCORE", &"operator": "OPERATOR", &"streak": "KILLSTREAKS", &"rival": "RIVAL HAND",
			&"deck": "DECK", &"traits": "SETS"}[key]
	if merged:
		_flyout_title.text = "SCORE · RIVAL HAND"
	_flyout_hint.text = {
		&"operator": "Tap the Operator here to select it, then a column · long-press for rules",
		&"streak": "Tap a ready streak to arm it · long-press for rules",
	}.get(key, "Long-press for the rules · tap outside to close")
	var w: float = FLYOUT_W if compact else FLYOUT_W_DESKTOP
	_flyout_hint.custom_minimum_size.x = w - 24.0
	_flyout.show()
	_flyout_panel.reset_size()
	_flyout_panel.size.x = maxf(w, _flyout_panel.get_combined_minimum_size().x)
	_place_flyout.call_deferred(badge)


func _place_flyout(badge: Control) -> void:
	if not _flyout.visible:
		return
	_flyout_panel.reset_size()
	var w: float = maxf(FLYOUT_W if compact else FLYOUT_W_DESKTOP, _flyout_panel.size.x)
	_flyout_panel.size.x = w
	var br: Rect2 = badge.get_global_rect()
	var local: Rect2 = Rect2(_flyout.get_global_transform().affine_inverse() * br.position, br.size)
	var x: float = local.end.x + 8.0 if not mirror else local.position.x - 8.0 - w
	var y: float = clampf(local.position.y, 4.0, maxf(4.0, _flyout.size.y - _flyout_panel.size.y - 4.0))
	_flyout_panel.position = Vector2(clampf(x, 0.0, maxf(0.0, _flyout.size.x - w)), y)
	flyout_changed.emit(flyout_key)


func close_flyout() -> void:
	var was: StringName = flyout_key
	flyout_key = &""
	_flyout_dragging = false
	if _flyout != null:
		_flyout.hide()
		_flyout.modulate.a = 1.0
	if was != &"":
		flyout_changed.emit(&"")


func is_flyout_open() -> bool:
	return _flyout.visible and flyout_key != &""


func _set_badges(snapshot: Dictionary) -> void:
	var text_c: Color = get_theme_color(&"text", &"Hud")
	var muted: Color = Color("#9AA5AE")
	var friend: Color = get_theme_color(&"friend", &"Hud")
	var enemy: Color = get_theme_color(&"enemy", &"Hud")
	# kc-onboard-ui: the initiative flag (holder's colour and shape) leads the round line.
	var ini: Dictionary = snapshot.get("initiative", {})
	var round_row: Array = [["R%d" % int(snapshot.get("round", 1)), muted]]
	if not ini.is_empty():
		var mine_i: bool = bool(ini.get("mine", true))
		round_row.push_front(["", friend if mine_i else enemy, &"flag" if mine_i else &"flag_rival"])
	var score_rows: Array = [round_row,
			[[str(int(snapshot.get("score_player", 0))), friend], ["-", muted], [str(int(snapshot.get("score_enemy", 0))), enemy]]]
	if rival_in_score():
		# kc-fight-ui: the rival's hand (a red card glyph + count) as the third line.
		score_rows.append([["", Color("#ff8a8d"), &"cards_rival"], [str(int(snapshot.get("enemy_hand", 0))), Color("#ffb3b5")]])
	_score_badge.font_size = 18 if rival_in_score() else 20
	_score_badge.set_value(score_rows)
	var op: Dictionary = snapshot.get("operator", {})
	_operator_can_deploy = bool(snapshot.get("operator_can_deploy", false))
	var op_text: String = "OFF"
	if _operator_can_deploy:
		op_text = "DEPLOY"
	elif op.has("armor") and String(op.get("zone", "OFF BOARD")) != "OFF BOARD":
		op_text = "%d/%d" % [int(op.get("armor", 0)), int(op.get("armor_max", 0))]
	_operator_badge.font_size = 20
	_operator_badge.set_value([[[op_text, text_c]]], false)
	_operator_badge.set_drag_enabled(false)
	var ready_ks: bool = false
	for ks: Dictionary in snapshot.get("killstreaks", []):
		ready_ks = ready_ks or (bool(ks.get("earned", false)) and bool(ks.get("ready", false)))
	_streak_badge.set_value([[[str(int(snapshot.get("streak", 0))), text_c]]], ready_ks)
	# kc-ui3: a one-time toast when each killstreak first becomes ready (its tile glows in the tray).
	if bool(snapshot.get("deploy_open", false)):
		for ks: Dictionary in snapshot.get("killstreaks", []):
			var id: StringName = StringName(ks.get("id", &""))
			if KillstreakRow.is_ready(ks) and not _ks_announced.has(id):
				_ks_announced[id] = true
				_streak_callout_shown = true
				show_toast.call_deferred("%s ready: tap it at the top of your hand" % String(ks.get("full_name", ks.get("name", "A killstreak"))))
	_rival_badge.set_value([[[str(int(snapshot.get("enemy_hand", 0))), Color("#ffb3b5")]]])
	_deck_badge.set_value([[[str(int(snapshot.get("deck_count", 0))), text_c]]])


## Long-press / right-click on a flyout or tray box opens its explanation (studio rule).
func _wire_box(box: Control, key: StringName) -> void:
	var g: RefCounted = PressGesture.new(box)
	g.drag_enabled = false
	_gestures.append(g)
	if box.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.gui_input.connect(func(e: InputEvent) -> void:
		if g.handle(e):
			box.accept_event())
	g.long_pressed.connect(func(_p: Vector2) -> void:
		close_flyout()
		rail_inspected.emit(key))


# =============================================================================
# Hand tray
# =============================================================================

func _setup_tray() -> void:
	_wire_box(_supply_box, &"supply")
	# kc-ui3: killstreak tiles: tap = use (the controller selects / calls it in), long-press = rules.
	_ks_row.killstreak_tapped.connect(func(id: StringName) -> void:
		close_flyout()
		_operator_panel.killstreak_pressed.emit(id))
	_ks_row.killstreak_inspected.connect(func(id: StringName) -> void:
		close_flyout()
		item_inspected.emit(id))
	_feed_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_wire_box(_feed_box, &"killfeed")
	_hand_tab.pressed.connect(func() -> void:
		set_tray_state(TRAY_CLOSED if tray_state == TRAY_PEEK else TRAY_PEEK))
	_wire_button_inspect(_hand_tab, &"hand_tab")
	_peek_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_peek_catcher.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_peek_catcher.accept_event()
			set_tray_state(TRAY_CLOSED))
	_speed_button.toggled.connect(func(on: bool) -> void:
		_speed_button.text = "SPEED x2" if on else "SPEED x1"
		var st: Node = get_node_or_null(^"/root/Settings")
		if st != null:
			# kc-fight-ui: the player's own choice now overrides the x1 / x2 default.
			if "speed_chosen" in st and not bool(st.get(&"speed_chosen")):
				st.set_value(&"speed_chosen", true)
			if bool(st.get(&"speed_x2")) != on:
				st.set_value(&"speed_x2", on)
		_apply_speed(_fx.is_playing() if _fx.has_method(&"is_playing") else false))
	# kc-ui3: SPEED x2 is kept between sessions (Settings.speed_x2). kc-fight-ui: until the player
	# picks a speed with this toggle, it starts at x1 (default_speed_x2).
	var fast: bool = playback_speed_x2()
	_speed_button.set_pressed_no_signal(fast)
	_speed_button.text = "SPEED x2" if fast else "SPEED x1"
	_apply_tray_state(false)


## OPEN at the start of Deploy, CLOSED when READY is pressed (Reveal, Firefight, Score); a PEEK
## closes when the next step starts.
func _follow_phase(snapshot: Dictionary) -> void:
	var open: bool = bool(snapshot.get("deploy_open", true)) and StringName(snapshot.get("result", &"")) == &""
	var phase: String = String(snapshot.get("phase", ""))
	var cards: int = (snapshot.get("hand", []) as Array).size()
	_hand_count = cards
	if open:
		set_tray_state(TRAY_OPEN)
	elif tray_state == TRAY_OPEN or (tray_state == TRAY_PEEK and phase != _phase):
		set_tray_state(TRAY_CLOSED)
	if not open and (phase != _phase or _deploy_open):
		_step_header.text = phase if phase != "" else "FIREFIGHT"
	if open and not _deploy_open:
		_killfeed_fx.clear()
	if open and int(snapshot.get("round", 1)) != _glow_round:
		_glow_round = int(snapshot.get("round", 1))
		glow_set_cards.call_deferred(snapshot.get("hand", []))
	_deploy_open = open
	_phase = phase
	_update_tab_text()


## kc-fight-ui (head, kc-syn-ui answers): at the start of Deploy, the hand cards that would switch a
## trait bonus on this round (match_snapshot `completes_tier`) glow briefly in their trait's colour.
## Returns the uids that glow (tests, QA).
func glow_set_cards(hand: Array) -> Array[int]:
	var out: Array[int] = []
	if _fx == null or not is_inside_tree():
		return out
	for c: Dictionary in hand:
		if String(c.get("completes_tier", "")) == "":
			continue
		var card: Control = _hand.get_card(int(c.get("uid", -1))) if _hand.has_method(&"get_card") else null
		if card == null:
			continue
		var g: Control = HandGlowFx.new()
		g.target = card
		g.color = SynergyGlyphs.trait_color(StringName(String(c.get("trait", ""))))
		g.add_to_group(&"fx_transient")
		_fx.add_child(g)
		g.play(_fx.get_timing() if _fx.has_method(&"get_timing") else null)
		out.append(int(c.get("uid", -1)))
	_last_glow = out
	return out


## The hand cards that glowed at the start of this Deploy (tests, QA).
func get_last_glow() -> Array[int]:
	return _last_glow


func set_tray_state(value: StringName) -> void:
	if value == tray_state:
		return
	tray_state = value
	_apply_tray_state(true)
	tray_state_changed.emit(value)


func _apply_tray_state(animate: bool) -> void:
	var open: bool = tray_state == TRAY_OPEN
	var peek: bool = tray_state == TRAY_PEEK
	_hand.visible = open or peek
	_hand.set_read_only(peek)
	if _well != null:
		_layout_well()
	_undo_button.visible = open
	_ready_button.visible = open
	_feed_box.visible = tray_state == TRAY_CLOSED
	_hand_tab.visible = not open
	_speed_button.visible = not open
	if _dock != null and not open:
		_dock.visible = false
	_peek_catcher.visible = peek
	_sync_ability_visible()
	_update_tab_text()
	if animate and not _reduced_motion():
		# 200 ms cross-fade, plus a 160 ms slide on the cards (board-layout-v2.md §4.1).
		for c: Control in [_hand, _feed_box]:
			if c.visible:
				c.modulate.a = 0.0
				var tw: Tween = c.create_tween()
				tw.tween_property(c, "modulate:a", 1.0, TRAY_FADE)
		if _hand.visible and not metrics.is_empty():
			var to_x: float = (metrics["hand_rect"] as Rect2).position.x
			_hand.position.x = to_x + (-24.0 if mirror else 24.0)
			_hand.create_tween().tween_property(_hand, "position:x", to_x, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _update_tab_text() -> void:
	_hand_tab.text = "HAND · %d   %s" % [_hand_count, "CLOSE" if tray_state == TRAY_PEEK else "PEEK"]


func _reduced_motion() -> bool:
	var settings: Node = get_node_or_null(^"/root/Settings")
	return settings != null and bool(settings.get(&"reduced_motion"))


## SPEED x2: the round's feedback plays at double speed while it runs.
func _apply_speed(playing: bool) -> void:
	Engine.time_scale = 2.0 if playing and _speed_button.button_pressed else 1.0


## kc-fight-ui: the playback speed. The player's own pick with the SPEED toggle wins
## (Settings.speed_chosen + speed_x2). Otherwise x1: the head (2026-11-06) wants x1 everywhere for
## now, so the resolver's "x2 after the tutorial" default (O4) is off until he says otherwise
## (FOLLOW_TUTORIAL_DEFAULT). An older save's SPEED x2 without a pick made with this toggle is ignored.
const FOLLOW_TUTORIAL_DEFAULT: bool = false


static func default_speed_x2(speed_x2: bool, speed_chosen: bool, tutorial_done: bool) -> bool:
	if speed_chosen:
		return speed_x2
	if FOLLOW_TUTORIAL_DEFAULT:
		return FirefightResolver.default_playback_speed(tutorial_done) >= 2.0
	return false


func playback_speed_x2() -> bool:
	var st: Node = get_node_or_null(^"/root/Settings")
	if st == null:
		return default_speed_x2(false, false, false)
	var chosen: bool = "speed_chosen" in st and bool(st.get(&"speed_chosen"))
	return default_speed_x2(bool(st.get(&"speed_x2")), chosen, _tutorial_done(st))


## The tutorial record (user://tutorial.cfg); headless test runs (Settings not persisting) read it as
## not done, so a dev machine's record never changes what the tests see.
static func _tutorial_done(st: Node) -> bool:
	if st == null or not bool(st.get(&"persist")):
		return false
	return TutorialProgress.is_completed()


## kc-fight-ui: the round is about to play. The order strip greys the columns with no fight.
func prepare_fight(events: Array) -> void:
	var zones: Array = []
	for ev: Dictionary in events:
		if ev.get("type") == RulesEvent.FIREFIGHT_STARTED:
			zones.append(StringName(ev.get("zone", &"")))
	if _order_strip != null:
		_order_strip.begin(zones)
		_order_strip.visible = true


## kc-fight-ui: the board as the firefight playback stands (fight_playback.gd snapshot): the columns
## (the dead leave, the line slides up), and the links and trait rail of that board, with the set
## callouts / cracks of what switched on or off.
func show_fight_board(snapshot: Dictionary) -> void:
	_board.set_lanes(snapshot.get("lanes", []))
	var syn: Dictionary = snapshot.get("synergy", {})
	for side: String in ["player", "enemy"]:
		var block: Dictionary = syn.get(side, {})
		if block.is_empty():
			continue
		on_synergy_event({"side": StringName(side), "counts": block.get("counts", {}), "sets": block.get("tiers", {}),
				"links": block.get("links", [])})


func _on_fight_caption(lines: Array) -> void:
	if _fight_caption == null:
		return
	var text: String = "\n".join(PackedStringArray(lines))
	_fight_caption.text = text
	_fight_caption.visible = text != ""


## The caption under the order strip (tests, QA).
func get_fight_caption() -> String:
	return _fight_caption.text if _fight_caption != null and _fight_caption.visible else ""


## kc-fight-ui: the columns only (the Reveal turns the rival's cards over one at a time).
func show_lanes(lanes: Array) -> void:
	_board.set_lanes(lanes)


func get_order_strip() -> Control:
	return _order_strip


## The tray header names the firefight beat as it plays (FIREFIGHT · B · BEAT 2 · FIRST SHOT), and
## the order strip lights the column being fought.
func _on_fx_event(ev: Dictionary) -> void:
	var t: StringName = ev.get("type", &"")
	_v2_fx_line(ev)
	var letter: String = ZONE_LETTERS.get(StringName(ev.get("zone", &"")), "")
	if t == RulesEvent.FIREFIGHT_STARTED:
		_step_header.text = "FIREFIGHT · %s" % letter
		if _order_strip != null:
			_order_strip.set_active(StringName(ev.get("zone", &"")))
	elif t == RulesEvent.FIREFIGHT_BEAT:
		var tag: String = {1: " · FIRST SHOT", 2: " · REPLY"}.get(int(ev.get("exchange", 0)), "")
		_step_header.text = "FIREFIGHT · %s · BEAT %d%s" % [letter, int(ev.get("beat", 1)), tag]
	elif t == RulesEvent.FIREFIGHT_COLUMN_ENDED:
		if _order_strip != null:
			_order_strip.set_done(StringName(ev.get("zone", &"")))
	elif t == RulesEvent.FIREFIGHT_STEP:
		var step: String = {&"first_shot": "FIRST SHOT", &"main": "MAIN STEP"}.get(StringName(ev.get("step", &"")), "")
		_step_header.text = "FIREFIGHT · %s · %s" % [letter, step]
	elif t == RulesEvent.SYNERGY_CHANGED:
		on_synergy_event(ev)
	elif t == RulesEvent.PHASE_CHANGED:
		var ph: String = String(ev.get("phase", "")).to_upper()
		if ph != "" and ph != "FIREFIGHT":
			_step_header.text = ph
			if _order_strip != null and ph != "REVEAL":
				_order_strip.finish()


## The killfeed log in the tray (tests: lines must fit it).
func get_killfeed() -> Control:
	return _killfeed_fx


## The killfeed toasts over the board.
func get_killfeed_toasts() -> Control:
	return _toasts


## Where the killfeed log draws, in global (canvas) coordinates.
func get_killfeed_rect() -> Rect2:
	return _killfeed_fx.get_global_rect()


## Supply pips: as wide as the tray's Supply row allows for the current Supply (6..14 px).
func _pip_size() -> Vector2:
	var n: int = maxi(1, _supply_pips.get_child_count())
	var box_w: float = _supply_box.size.x if _supply_box != null and _supply_box.size.x > 0.0 else 300.0
	# kc-ui3: stacked (pips under SUPPLY 3/4) the pips get the whole row; in one row, what the words leave.
	var room: float = box_w - (28.0 if _supply_stacked else 150.0)
	# kc-readability: the pips are cost hexes (the cards' Supply icon), up to 18 px; the row keeps its
	# old height (18 / 20) so the Supply box does not grow into the killstreak row or the hand.
	var h: float = 18.0 if compact else 20.0
	var w: float = clampf(floorf(room / n) - 3.0, 10.0, h - 2.0)
	return Vector2(w, h)


func _set_supply(supply: int, supply_max: int) -> void:
	_supply_value.text = "%d/%d" % [supply, supply_max]
	for child: Node in _supply_pips.get_children():
		_supply_pips.remove_child(child)
		child.queue_free()
	for i: int in supply_max:
		var pip: Panel = Panel.new()
		var full: bool = i < supply
		pip.theme_type_variation = &"SupplyPip" if full else &"SupplyPipSpent"
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# kc-readability (the head: "the supply count at top should use same iconography as supply cost
		# of cards"): each pip is the cards' cost hex, amber while available, an empty outline when spent.
		pip.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
		pip.set_meta(&"hex", true)
		pip.draw.connect(func() -> void: _draw_supply_hex(pip, full))
		_supply_pips.add_child(pip)
	_fit_pips()
	_supply_spend_fx(supply, supply_max)


## kc-juice: a play spent Supply (same max, fewer left): each hex just spent bursts and fades over its
## now-empty pip (supply_spend_fx.gd) with a "supply" tick, higher for each hex.
func _supply_spend_fx(supply: int, supply_max: int) -> void:
	last_supply_spent.clear()
	var was: Vector2i = _last_supply
	_last_supply = Vector2i(supply, supply_max)
	if was.y != supply_max or supply >= was.x or not is_inside_tree():
		return
	for i: int in range(supply, mini(was.x, _supply_pips.get_child_count())):
		var pip: Control = _supply_pips.get_child(i) as Control
		var fx: Control = SupplySpendFx.new()
		pip.add_child(fx)
		fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fx.play()
		last_supply_spent.append(i)
	SfxBankScript.cue(&"supply", 1.0 + 0.05 * float(last_supply_spent.size() - 1))


func _draw_supply_hex(pip: Control, full: bool) -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, pip.size)
	if full:
		CardLook.draw_cost(pip, r, "")
		return
	var c: Vector2 = r.get_center()
	var rad: float = minf(r.size.x, r.size.y * 1.1) * 0.5 - 1.0
	var pts: PackedVector2Array = []
	for i: int in 7:
		pts.append(c + Vector2.from_angle(PI / 6.0 + i * PI / 3.0) * rad)
	pip.draw_colored_polygon(pts.slice(0, 6), Color(0.04, 0.05, 0.055, 0.9))
	pip.draw_polyline(pts, Color(CardLook.AMBER, 0.55), 1.5, true)


## kc-ui3: when the killstreak tiles share the Supply row (phone), the pips go under SUPPLY 3/4.
func _set_supply_stacked(on: bool) -> void:
	if on == _supply_stacked:
		return
	_supply_stacked = on
	var row: HBoxContainer = _supply_pips.get_parent() as HBoxContainer if not on else _supply_value.get_parent() as HBoxContainer
	if on:
		if _supply_stack == null:
			_supply_stack = VBoxContainer.new()
			_supply_stack.name = "SupplyStack"
			_supply_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_supply_stack.alignment = BoxContainer.ALIGNMENT_CENTER
			_supply_stack.add_theme_constant_override(&"separation", 2)  # kc-readability: the taller number face
		_supply_box.remove_child(row)
		_supply_box.add_child(_supply_stack)
		_supply_stack.add_child(row)
		row.remove_child(_supply_pips)
		_supply_stack.add_child(_supply_pips)
		_supply_pips.size_flags_horizontal = Control.SIZE_FILL
	else:
		_supply_stack.remove_child(_supply_pips)
		row = _supply_stack.get_child(0) as HBoxContainer
		row.add_child(_supply_pips)
		row.move_child(_supply_pips, 1)
		_supply_pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_supply_stack.remove_child(row)
		_supply_box.remove_child(_supply_stack)
		_supply_box.add_child(row)
	# Stacked: SUPPLY on the left, the value on the right of the top line.
	var caption: Control = row.get_child(0) as Control
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL if on else Control.SIZE_FILL


func _fit_pips() -> void:
	for pip: Node in _supply_pips.get_children():
		(pip as Control).custom_minimum_size = _pip_size()


## Keeps the HUD clear of phone notches / home indicator (Xogot on iPhone, mobile web).
func _apply_safe_area() -> void:
	var margin_lt: Vector2 = BASE_MARGIN_COMPACT if compact else BASE_MARGIN
	var margin_rb: Vector2 = margin_lt
	var on_phone: bool = OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")
	if on_phone or safe_area_override.has_area():
		var window: Vector2 = Vector2(DisplayServer.window_get_size())
		var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
		if safe_area_override.has_area():
			window = get_viewport_rect().size
			safe = safe_area_override
		if window.x > 0.0 and window.y > 0.0 and safe.size.x > 0.0:
			var to_canvas: Vector2 = get_viewport_rect().size / window
			margin_lt = margin_lt.max(safe.position * to_canvas)
			margin_rb = margin_rb.max((window - safe.end) * to_canvas)
	_safe_area.add_theme_constant_override(&"margin_left", int(margin_lt.x))
	_safe_area.add_theme_constant_override(&"margin_top", int(margin_lt.y))
	_safe_area.add_theme_constant_override(&"margin_right", int(margin_rb.x))
	_safe_area.add_theme_constant_override(&"margin_bottom", int(margin_rb.y))
	_inspector.set_safe_margins(margin_lt, margin_rb)


# =============================================================================
# kc-v2-ui: the Operator ability button, the boss plate, the match intro, Terrain / boss / ability
# lines in the killfeed (run-v2.md §6, §7.1, §9)
# =============================================================================

var _ability: Control = null
var _boss_plate: Control = null
var _intro: Control = null
var _intro_shown: bool = false
var _selected_item: StringName = &""
var _last_ability: Dictionary = {}
var _ability_planned: bool = false
var _last_lanes: Array = []
## The run node of this match (RunState.current_node(), for the intro heading); tests may set it.
var intro_node: Dictionary = {}


func _setup_v2() -> void:
	_ability = AbilityButton.new()
	_tray.add_child(_ability)
	_ability.pressed.connect(func() -> void:
		close_flyout()
		ability_pressed.emit())
	_ability.inspected.connect(func() -> void:
		close_flyout()
		ability_inspected.emit())
	_boss_plate = BossPlate.new()
	_boss_plate.name = "BossPlate"
	_layout.add_child(_boss_plate)
	_boss_plate.inspected.connect(func() -> void:
		close_flyout()
		_inspector.open((load("res://scripts/ui/run/map_v2_view.gd") as GDScript).call(&"boss_info", _boss_plate.boss)))
	_boss_plate.tapped.connect(func() -> void:
		show_toast("Boss rule · %s: %s" % [_boss_plate.boss.get("rule_name", ""), _boss_plate.boss.get("rule_text", "")]))
	_intro = MatchIntro.new()
	add_child(_intro)
	move_child(_intro, _inspector.get_index())
	_intro.inspect_requested.connect(func(info: Dictionary) -> void: _inspector.open(info))


func get_ability_button() -> Control:
	return _ability


func get_boss_plate() -> Control:
	return _boss_plate


func get_match_intro() -> Control:
	return _intro


func _set_v2(snapshot: Dictionary) -> void:
	_last_ability = snapshot.get("ability", {})
	_last_lanes = snapshot.get("lanes", [])
	_ability_planned = bool(snapshot.get("ability_planned", false))
	_refresh_ability()
	var boss: Dictionary = snapshot.get("boss", {})
	_boss_plate.set_boss((load("res://scripts/ui/run/run_v2_views.gd") as GDScript).call(&"boss_entry", boss) if not boss.is_empty() else {})
	_layout_boss_plate.call_deferred()
	var terrain: Array = snapshot.get("terrain", [])
	if not _intro_shown and int(snapshot.get("round", 1)) <= 1 and MatchIntro.wanted(terrain, boss, intro_node):
		_intro_shown = true
		var node: Dictionary = intro_node
		if node.is_empty():
			var rs: Node = get_node_or_null(^"/root/RunState")
			if rs != null and rs.has_method(&"current_node"):
				var cn: Variant = rs.call(&"current_node")
				if cn is Dictionary and not (cn as Dictionary).is_empty():
					var views: GDScript = load("res://scripts/ui/run/run_v2_views.gd") as GDScript
					var m: Dictionary = views.call(&"normalise_map", {"current": cn.get("id", &""), "nodes": [cn]})
					node = (m["nodes"] as Array)[0]
		_intro.compact = compact
		_intro.open(terrain, boss, node, String(snapshot.get("mode", "")).capitalize())


func _refresh_ability() -> void:
	if _ability == null:
		return
	var aiming: bool = not _last_ability.is_empty() and _selected_item != &"" and _selected_item == StringName(str(_last_ability.get("id", "")))
	_ability.set_ability(_last_ability, aiming, _ability_planned)
	_sync_ability_visible()


func _sync_ability_visible() -> void:
	if _ability == null:
		return
	var card: Control = _hand.get_operator_card()
	_ability.visible = _ability.state != AbilityButton.State.NONE and tray_state == TRAY_OPEN \
			and card != null and card.is_visible_in_tree()


## The button sits on the Operator card's bottom-right corner (over the end of its name / lore row:
## the cost, the art's badges and the FP / Armor stay clear).
func _layout_ability() -> void:
	if _ability == null or metrics.is_empty() or not metrics.has("op_card"):
		return
	var op: Rect2 = metrics["op_card"]
	var s: float = AbilityButton.SIZE_PX
	_ability.size = Vector2(s, s)
	_ability.position = Vector2(op.end.x - s - 2.0, op.end.y - s - 2.0)
	_sync_ability_visible.call_deferred()
	_layout_boss_plate.call_deferred()


## The boss plate sits on an EMPTY rival back-row slot (row 4): column A's if free, else B's, else C's,
## so it never covers a card. With all three back rows full it shrinks to a skull tab at the board's
## top-left corner.
func _layout_boss_plate() -> void:
	if _boss_plate == null or not _boss_plate.visible:
		return
	var lr: Rect2 = _layout.get_global_rect()
	_boss_plate.compact = compact
	var lanes: Array = _board.get_lanes()
	for z: int in lanes.size():
		var data: Dictionary = _last_lanes[z] if z < _last_lanes.size() else {}
		var used: int = (data.get("enemy", []) as Array).size() + (1 if int(data.get("incoming", 0)) > 0 else 0)
		var slots: Array = lanes[z].get_enemy_slots()
		if used < slots.size() and slots.size() >= 4:
			var r: Rect2 = (slots[slots.size() - 1] as Control).get_global_rect()
			_boss_plate.tab = false
			_boss_plate.position = r.position - lr.position
			_boss_plate.size = r.size
			_boss_plate.queue_redraw()
			return
	var br: Rect2 = _board.get_global_rect()
	_boss_plate.tab = true
	_boss_plate.size = Vector2(56, 56)
	_boss_plate.position = br.position - lr.position + Vector2(2, 2)
	_boss_plate.queue_redraw()


## Terrain triggers, boss rules and abilities as killfeed lines (toast over the board + the tray log).
func _v2_fx_line(ev: Dictionary) -> void:
	var t: String = String(ev.get("type", ""))
	var data: Dictionary = {}
	match t:
		"terrain_triggered":
			var views: GDScript = load("res://scripts/ui/run/run_v2_views.gd") as GDScript
			var td: Dictionary = views.call(&"terrain_entry", StringName(str(ev.get("terrain", ""))))
			var what: String = String(ev.get("what", ""))
			var rest: String = what.trim_prefix(String(td["name"]) + ":").strip_edges() if what != "" else ""
			data = {"attacker": String(td["name"]).to_upper(), "attacker_side": StringName(str(ev.get("side", "player"))),
					"victim": rest.to_upper(), "victim_side": StringName(str(ev.get("side", "player"))), "icon": &""}
		"boss_rule_triggered":
			var what2: String = String(ev.get("what", "Boss rule"))
			var parts: PackedStringArray = what2.split(":", true, 1)
			data = {"attacker": parts[0].to_upper(), "attacker_side": &"enemy",
					"victim": parts[1].strip_edges().to_upper() if parts.size() > 1 else "", "victim_side": &"enemy", "icon": &""}
		"item_revealed":
			if not bool(ev.get("ability", false)):
				return
			var side: StringName = StringName(str(ev.get("side", "player")))
			var name: String = String(_last_ability.get("name", "ABILITY")) if side == &"player" else "ABILITY"
			var zl: String = String(ZONE_LETTERS.get(StringName(str(ev.get("zone", ""))), ""))
			data = {"attacker": String(_last_ability.get("operator_name", "OPERATOR")).to_upper() if side == &"player" else "RIVAL",
					"attacker_side": side, "victim": ("%s · %s" % [name, zl] if zl != "" else name).to_upper(), "victim_side": side, "icon": &""}
			if side == &"player" and _ability != null:
				_ability.celebrate()
	if data.is_empty() or _toasts == null:
		return
	_toasts.push(data)

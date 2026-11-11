# title.gd
# Purpose: Title screen (p11). CONTINUE RUN (only when a save exists) loads it and opens the screen
#   for its phase; if the save can't be loaded, RunState moves it aside and the notice shows
#   RunState.last_load_warning. START NEW RUN starts a fresh run and opens the Loadout; with a
#   save on disk it first asks to replace it (REPLACE / KEEP IT), so one stray tap never loses a run.
#   TUTORIAL opens the p15 drill (scenes/tutorial/Tutorial.tscn). First launch (the drill was
#   never completed or skipped, and no run is saved) also shows "New here? Play the 3-minute
#   drill." with PLAY DRILL / NOT NOW; NOT NOW records a skip so it is not offered again.
#   v01: Port Vasel key art (card_art.gd) behind a left-hand menu column, with a dark scrim.
#   kc-ui3: CODEX (beside TUTORIAL) opens the card codex over the title (codex_view.gd).
#   kc-da-ui (art direction v1 #6): ONE amber button: PLAY DRILL while the drill is offered, else
#   CONTINUE RUN when a run is saved, else START NEW RUN; every other button is steel. The drill
#   invite sits in a steel frame (red is for danger, never a friendly offer).
#   kc-da-ui2 (art direction #7, "opening the case: your best card on top"): the title lockup
#   (title_wordmark.gd: stencil KILLING + CARD on a card-cut plate) and, on the right, the player's
#   equipped Operator (Settings.operator_primary, else the starter's) as a large Y2+ card with its
#   band; long press / right click (or a tap) opens the inspector. Still exactly one amber button.
# Dependencies: run_screen.gd, RunState, SceneRouter (via RunFlow), tutorial_progress.gd, card_art.gd.
# Author: Mechanics Developer Agent (placeholder); run flow: UI/UX Agent (p11)
extends "res://scripts/ui/run/run_screen.gd"

const TutorialProgress: GDScript = preload("res://scripts/ui/tutorial/tutorial_progress.gd")
const SCENE_TUTORIAL: String = "res://scenes/tutorial/Tutorial.tscn"
const CodexView: GDScript = preload("res://scripts/ui/codex/codex_view.gd")
var _codex_button: Button = null
## kc-duel-ui: DUEL (beside the campaign's START NEW RUN) opens the Duel hub.
const SCENE_DUEL_HUB: String = "res://scenes/duel/DuelHub.tscn"
var _duel_button: Button = null
var _codex: Control = null

var _key_art_scale: float = 0.0
const TitleWordmark: GDScript = preload("res://scripts/ui/title_wordmark.gd")
const CodexViewScript: GDScript = preload("res://scripts/ui/codex/codex_view.gd")
## kc-da-ui2: the Operator showcase card width (desktop / phone landscape).
const SHOWCASE_W: float = 400.0
const SHOWCASE_W_COMPACT: float = 280.0
const BRASS: Color = Color("#C9A227")
var _wordmark_art: Control = null
var _showcase: VBoxContainer = null
var _showcase_card: CardView = null
var _showcase_item: LoadoutItem = null

@onready var _key_art: TextureRect = %KeyArt
@onready var _column: VBoxContainer = %Column
@onready var _wordmark: Label = %TitleLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _start_button: Button = %StartButton
@onready var _confirm_panel: PanelContainer = %ConfirmPanel
@onready var _replace_button: Button = %ReplaceButton
@onready var _keep_button: Button = %KeepButton
@onready var _warning_panel: PanelContainer = %WarningPanel
@onready var _warning_label: Label = %WarningLabel
@onready var _tutorial_button: Button = %TutorialButton
@onready var _offer_panel: PanelContainer = %OfferPanel
@onready var _play_drill_button: Button = %PlayDrillButton
@onready var _not_now_button: Button = %NotNowButton


## The Title has its own key art (and scrim) in the scene.
func backdrop_key() -> StringName:
	return &""


func screen_id() -> StringName:
	return &"title"


func _build() -> void:
	# Marker line for the web load-time check (qa/performance-logs/web-load.md).
	print("Title: ready")
	_continue_button.pressed.connect(_on_continue_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_replace_button.pressed.connect(_start_new_run)
	_keep_button.pressed.connect(_hide_confirm)
	_tutorial_button.pressed.connect(open_tutorial)
	_play_drill_button.pressed.connect(open_tutorial)
	_not_now_button.pressed.connect(_on_not_now_pressed)
	_codex_button = Button.new()
	_codex_button.name = "CodexButton"
	_codex_button.text = "CODEX"
	_codex_button.theme_type_variation = &"HudButton"
	_codex_button.tooltip_text = "Browse every card and killstreak"
	_codex_button.custom_minimum_size = Vector2(0, _tutorial_button.custom_minimum_size.y)
	_codex_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_button.focus_mode = Control.FOCUS_ALL
	_codex_button.add_to_group(&"tap_target")
	# TUTORIAL and CODEX share a row (the phone column has no room for another one).
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "TutorialRow"
	row.add_theme_constant_override(&"separation", 10)
	var at: int = _tutorial_button.get_index()
	_column.remove_child(_tutorial_button)
	_column.add_child(row)
	_column.move_child(row, at)
	row.add_child(_tutorial_button)
	_tutorial_button.owner = self  # keeps %TutorialButton resolvable after the move
	_tutorial_button.unique_name_in_owner = true
	_tutorial_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tutorial_button.custom_minimum_size.x = 0
	row.add_child(_codex_button)
	_codex_button.pressed.connect(open_codex)
	# kc-ui-wire2: the kit's menu icons on the title buttons (no icon without the kit).
	UiKit.set_button_icon(_codex_button, &"ui_codex", 24.0)
	UiKit.set_button_icon(_tutorial_button, &"ui_tutorial", 24.0)
	UiKit.set_button_icon(_continue_button, &"ui_continue", 24.0)
	# kc-duel-ui: DUEL sits beside the campaign's START NEW RUN.
	_duel_button = Button.new()
	_duel_button.name = "DuelButton"
	_duel_button.text = "DUEL"
	_duel_button.theme_type_variation = &"HudButton"
	_duel_button.tooltip_text = "Build a 10-pick deck, pick a hero, play one battle (vs AI or Pass & Play)"
	_duel_button.custom_minimum_size = Vector2(0, _start_button.custom_minimum_size.y)
	_duel_button.focus_mode = Control.FOCUS_ALL
	_duel_button.add_to_group(&"tap_target")
	# START NEW RUN (the campaign) and DUEL share a row, like TUTORIAL and CODEX (the phone column has
	# no room for another row when the replace-save confirm is open).
	var mode_row: HBoxContainer = HBoxContainer.new()
	mode_row.name = "ModeRow"
	mode_row.add_theme_constant_override(&"separation", 10)
	var start_at: int = _start_button.get_index()
	_column.remove_child(_start_button)
	_column.add_child(mode_row)
	_column.move_child(mode_row, start_at)
	mode_row.add_child(_start_button)
	_start_button.owner = self  # keeps %StartButton resolvable after the move
	_start_button.unique_name_in_owner = true
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_button.size_flags_stretch_ratio = 1.4
	_start_button.custom_minimum_size.x = 0
	_duel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_child(_duel_button)
	_duel_button.pressed.connect(open_duel)
	resized.connect(_update_key_art)
	_update_key_art()
	_offer_panel.add_theme_stylebox_override(&"panel", steel_frame())
	_wordmark_art = TitleWordmark.attach(_wordmark)
	_build_showcase()
	resized.connect(_fit_showcase)
	refresh()


## kc-da-ui2: the Operator the player has equipped (the starter screen's pick), else the starter's.
func equipped_operator() -> LoadoutItem:
	var db: Node = get_tree().root.get_node_or_null(^"/root/CardDB") if is_inside_tree() else null
	var st: Node = get_tree().root.get_node_or_null(^"/root/Settings") if is_inside_tree() else null
	var pref: String = String(st.get(&"operator_primary")) if st != null else ""
	if db != null and pref != "" and db.has_method(&"get_loadout_item"):
		var it: Resource = db.get_loadout_item(StringName(pref))
		if it is LoadoutItem:
			return it
	var rs: Node = RunFlow.run_state()
	var cfg: RunConfig = rs.call(&"_config") as RunConfig if rs != null and rs.has_method(&"_config") else null
	return cfg.starter_primary if cfg != null else null


## The showcase: "YOUR OPERATOR" in brass, the Operator's Y2+ card large, its band strip.
func _build_showcase() -> void:
	_showcase_item = equipped_operator()
	if _showcase_item == null:
		return
	var center: Container = _column.get_parent() as Container
	var spacer: Control = Control.new()
	spacer.name = "ShowcaseGap"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(spacer)
	_showcase = VBoxContainer.new()
	_showcase.name = "Showcase"
	_showcase.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_showcase.add_theme_constant_override(&"separation", 6)
	center.add_child(_showcase)
	var right: Control = Control.new()
	right.name = "ShowcaseRight"
	right.custom_minimum_size = Vector2(24, 0)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(right)
	var cap: Label = make_label("YOUR OPERATOR", &"HudTag")
	cap.name = "ShowcaseLabel"
	cap.add_theme_color_override(&"font_color", BRASS)
	_showcase.add_child(cap)
	var item: LoadoutItem = _showcase_item
	var view: Dictionary = {"name": item.display_name, "type": "operator", "firepower": item.operator_firepower,
			"armor": item.operator_armor, "banner": String(BannerArtDB.operator_art_id(item.id, 1)),
			"text": item.text if item.text != "" else "Your Operator: respawns if it goes down.", "side": "friend"}
	_showcase_card = CodexViewScript.make_card_view(view, SHOWCASE_W)
	var holder: Control = Control.new()
	holder.name = "ShowcaseCard"
	holder.tooltip_text = "%s, your Operator: long press or right click for its rules" % item.display_name
	holder.add_child(_showcase_card)
	_showcase.add_child(holder)
	wire_inspect_control(holder, open_showcase_inspector)
	var band: StringName = BannerArtDB.camo_for_tier(1)
	var strip: Control = Control.new()
	strip.name = "Band"
	strip.custom_minimum_size = Vector2(0, 10)
	strip.set_meta(&"band", band)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.draw.connect(func() -> void:
		MasteryBands.draw(strip, Rect2(Vector2.ZERO, strip.size), band)
		strip.draw_rect(Rect2(Vector2.ZERO, strip.size), Color("#4A535B"), false, 1.0))
	_showcase.add_child(strip)
	var line: Label = make_label("%s BAND" % MasteryBands.display_name(band).to_upper(), &"HudSubtle")
	line.name = "BandLabel"
	_showcase.add_child(line)
	# Captions over the painting sit on a dark socket (art direction §5.6), never straight on the art.
	for l: Label in [cap, line]:
		var sock: StyleBoxFlat = StyleBoxFlat.new()
		sock.bg_color = Color("#12161A", 0.88)
		sock.set_corner_radius_all(2)
		sock.content_margin_left = 6
		sock.content_margin_right = 6
		l.add_theme_stylebox_override(&"normal", sock)
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_fit_showcase()


func open_showcase_inspector() -> void:
	if _showcase_item == null or _showcase_card == null:
		return
	var item: LoadoutItem = _showcase_item
	inspector().open({"view": _showcase_card.data.duplicate(), "title": item.display_name,
			"type": "operator · FP %d · Armor %d" % [item.operator_firepower, item.operator_armor],
			"text": item.text, "is_unit": true, "status": "Your equipped Operator: it leads every run and Duel you start. Change it on the starter screen (Codex > STARTER)."})


func get_showcase_card() -> Control:
	return _showcase_card if _showcase != null and _showcase.visible else null


## Card width by profile; the showcase folds away when the column and the card would not fit side by side.
func _fit_showcase() -> void:
	if _showcase == null or _showcase_card == null:
		return
	var w: float = SHOWCASE_W_COMPACT if compact else SHOWCASE_W
	var room_h: float = size.y - 80.0
	while w > 200.0 and CardView.height_for(w) + 56.0 > room_h:
		w -= 20.0
	# Width left beside the column (left gap, a 24 px gutter, the right gap, the safe margins).
	var fit_w: float = size.x - (_column.get_combined_minimum_size().x + 40.0 + 24.0 + 24.0 + 40.0)
	w = minf(w, floorf(fit_w))
	_showcase.visible = w >= 200.0 and size.x > size.y
	w = maxf(w, 200.0)
	_showcase_card.set_card_width(w)
	var holder: Control = _showcase_card.get_parent() as Control
	holder.custom_minimum_size = CardView.size_for(w)
	var gap: Node = _showcase.get_parent().get_node_or_null(^"ShowcaseGap")
	if gap != null:
		(gap as Control).visible = _showcase.visible


## kc-da-ui: the drill invite's frame: a gunmetal plate with a steel rim (art direction §4).
static func steel_frame() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#232A31", 0.94)
	sb.border_color = Color("#4A535B")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(10)
	return sb


## kc-da-ui: the one amber (primary) button of the title in its current state.
func primary_button() -> Button:
	if _offer_panel.visible:
		return _play_drill_button
	if _continue_button.visible:
		return _continue_button
	return _start_button


func _apply_primary() -> void:
	var primary: Button = primary_button()
	for b: Button in [_continue_button, _start_button, _play_drill_button]:
		b.theme_type_variation = &"ReadyButton" if b == primary else &"HudButton"


## Rasterises the key art for the screen size (capped at 2x the 1280x720 source).
func _update_key_art() -> void:
	var cover: float = maxf(size.x / CardArt.Data.KEY_ART_SIZE.x, size.y / CardArt.Data.KEY_ART_SIZE.y)
	var s: float = CardArt.bucket(minf(CardArt.screen_scale(self) * cover, 2.0))
	if is_equal_approx(s, _key_art_scale):
		return
	_key_art_scale = s
	_key_art.texture = CardArt.key_art_texture(s)


## Re-reads the save state (tests call it after changing the save).
func refresh() -> void:
	var rs: Node = RunFlow.run_state()
	_continue_button.visible = rs != null and rs.has_save()
	_confirm_panel.hide()
	_show_warning(rs.last_load_warning if rs != null else "")
	_offer_panel.visible = TutorialProgress.should_offer() and not (rs != null and rs.has_save())
	_apply_primary()
	if _offer_panel.visible:
		_play_drill_button.grab_focus.call_deferred()
	elif _continue_button.visible:
		_continue_button.grab_focus.call_deferred()
	else:
		_start_button.grab_focus.call_deferred()


func _apply_compact() -> void:
	var h: float = button_height()
	_continue_button.custom_minimum_size.y = h
	_start_button.custom_minimum_size.y = h
	_tutorial_button.custom_minimum_size.y = h
	if _duel_button != null:
		_duel_button.custom_minimum_size.y = h
	if _codex_button != null:
		_codex_button.custom_minimum_size.y = h
	_column.add_theme_constant_override(&"separation", 10 if compact else 14)
	_wordmark.add_theme_font_size_override(&"font_size", 64 if compact else 84)
	if _wordmark_art != null:
		_wordmark_art.call(&"set_size_from", _wordmark)
	_fit_showcase()


func _on_continue_pressed() -> void:
	var rs: Node = RunFlow.run_state()
	if rs.continue_run():
		goto(RunFlow.scene_for(rs.run))
		return
	_continue_button.hide()
	_apply_primary()
	_show_warning(rs.last_load_warning if rs.last_load_warning != "" else "No saved run was found.")
	_start_button.grab_focus()


func _on_start_pressed() -> void:
	var rs: Node = RunFlow.run_state()
	if rs.has_save() and not _confirm_panel.visible:
		_confirm_panel.show()
		_keep_button.grab_focus()
		return
	_start_new_run()


func _start_new_run() -> void:
	var rs: Node = RunFlow.run_state()
	rs.start_run()
	goto(RunFlow.SCENE_LOADOUT)


func _hide_confirm() -> void:
	_confirm_panel.hide()
	_start_button.grab_focus()


func _show_warning(text: String) -> void:
	_warning_label.text = text
	_warning_panel.visible = text != ""


## kc-ui3: CODEX opens the card codex over the title.
func open_codex() -> Control:
	if _codex != null and is_instance_valid(_codex):
		return _codex
	_codex = CodexView.open_over(self)
	_codex.closed.connect(func() -> void:
		_codex = null
		_codex_button.grab_focus())
	return _codex


func get_codex() -> Control:
	return _codex if _codex != null and is_instance_valid(_codex) else null


func get_codex_button() -> Button:
	return _codex_button


## kc-duel-ui: DUEL opens the Duel hub.
func open_duel() -> void:
	goto(SCENE_DUEL_HUB)


func get_duel_button() -> Button:
	return _duel_button


## TUTORIAL / PLAY DRILL: opens the p15 drill.
func open_tutorial() -> void:
	goto(SCENE_TUTORIAL)


## True while the first-launch drill offer is on screen.
func is_offering_tutorial() -> bool:
	return _offer_panel.visible


func _on_not_now_pressed() -> void:
	TutorialProgress.record(false, 0)
	_offer_panel.hide()
	_apply_primary()
	_start_button.grab_focus()

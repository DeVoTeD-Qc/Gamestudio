# album_screen.gd
# Purpose: The Album screen (cc11, spec 5 and 8 step 1, art-direction 5): a velvet portfolio with
#   one page per set (album_set_page.gd: owned cards, silhouettes with unlock goal + progress,
#   Clearance and trait), the Triptychs page (album_triptych_page.gd: "???" + hints, revealed
#   panoramas) and the Cipher Lock (cipher_lock.gd). Header: BACK, "13 / 20 cards", titles.
#   Every card opens the shared CardInspector (cc07) with a tap, long-press, right-click or the
#   inspect key; a locked card's inspector keeps the silhouette and shows the goal and progress.
#   Celebrations come from EventBus (Collection emits them): card_unlocked (toast + the new card
#   lights up), set_completed (toast + set frames pulse), triptych_revealed (panorama reveal),
#   cipher_solved (handled by the lock). collection_changed refreshes the pages.
#   Layout follows cc07's duel screen: ScreenProfile canvas, safe-area margins (notches), compact
#   layout below 640 logical px, tap targets >= 64 px (44 pt), text >= 16 px (11 pt).
# Usage: SceneRouter.goto_scene("res://scenes/Album.tscn"). Tests may set `collection` (a
#   Collection instance) and `safe_area_override` before adding it to the tree.
# Dependencies: Collection, CardDB, EventBus, SceneRouter, Settings (optional), album_theme.gd,
#   album_set_page.gd, album_triptych_page.gd, album_triptych_reveal.gd, cipher_lock.gd,
#   scenes/duel/CardInspector.tscn (cc07), screen_profile.gd.
# Author: UI/UX Agent (cc11)
extends Control

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const AlbumTheme: GDScript = preload("res://scripts/ui/album_theme.gd")
const SetPage: GDScript = preload("res://scripts/ui/album_set_page.gd")
const TriptychPage: GDScript = preload("res://scripts/ui/album_triptych_page.gd")
const SCENE_PATH: String = "res://scenes/Album.tscn"
const PAGE_TRIPTYCHS: StringName = &"triptychs"
const PAGE_CIPHER: StringName = &"cipher_lock"
const BASE_MARGIN: Vector2 = Vector2(32, 18)
const BASE_MARGIN_COMPACT: Vector2 = Vector2(16, 10)
const MAX_CARD_W: float = 512.0
const MIN_TWO_COL_CARD_W: float = 400.0
const GRID_GAP: float = 24.0
const SCROLLBAR_W: float = 14.0

## Collection to show (defaults to the Collection autoload).
var collection: Node = null
## Tests: a safe area in logical px (as cc07's DuelScreen).
var safe_area_override: Rect2 = Rect2()
var compact: bool = false
var current_page: StringName = &""
var card_w: float = MAX_CARD_W
var columns: int = 2
var pano_w: float = 1080.0

var _tabs: Dictionary = {}       # page id -> Button
var _page_node: Control = null
var _cipher_lock: PanelContainer = null
var _reveal_queue: Array[StringName] = []
var _refresh_queued: bool = false
var _pending_celebrate: Dictionary = {}  # card id -> true (light up after the next rebuild)
var _toast_serial: int = 0

@onready var _safe_area: MarginContainer = %SafeArea
@onready var _column: VBoxContainer = %Column
@onready var _back: Button = %BackButton
@onready var _count: Label = %CardCount
@onready var _titles: Label = %TitlesLabel
@onready var _tab_scroll: ScrollContainer = %TabScroll
@onready var _tab_row: HBoxContainer = %Tabs
@onready var _page_panel: PanelContainer = %Page
@onready var _page_scroll: ScrollContainer = %PageScroll
@onready var _page_host: VBoxContainer = %PageHost
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel
@onready var _inspector: Control = %CardInspector
@onready var _reveal: Control = %TriptychReveal


func _ready() -> void:
	theme = AlbumTheme.build()
	if collection == null:
		collection = get_node_or_null("/root/Collection")
	_toast.visible = false
	_back.pressed.connect(_on_back)
	_build_tabs()
	_cipher_lock = (load("res://scenes/album/CipherLock.tscn") as PackedScene).instantiate()
	_reveal.closed.connect(_on_reveal_closed)
	get_viewport().size_changed.connect(_relayout)
	EventBus.collection_changed.connect(_queue_refresh)
	EventBus.collection_reset.connect(_queue_refresh)
	EventBus.card_unlocked.connect(_on_card_unlocked)
	EventBus.set_completed.connect(_on_set_completed)
	EventBus.triptych_revealed.connect(_on_triptych_revealed)
	EventBus.cipher_solved.connect(_on_cipher_solved)
	_relayout()
	show_page(_first_page())
	EventBus.screen_shown.emit(&"album")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _cipher_lock != null and is_instance_valid(_cipher_lock) \
			and not _cipher_lock.is_inside_tree():
		_cipher_lock.free()


## Page ids in tab order: every set (album order), then Triptychs and the Cipher Lock.
func page_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for s: SetData in CardDB.all_sets():
		out.append(s.id)
	out.append(PAGE_TRIPTYCHS)
	out.append(PAGE_CIPHER)
	return out


## Opens a page by id (a set id, &"triptychs" or &"cipher_lock").
func show_page(page_id: StringName) -> void:
	if not page_ids().has(page_id):
		return
	var changed: bool = page_id != current_page
	current_page = page_id
	for id: StringName in _tabs:
		(_tabs[id] as Button).set_pressed_no_signal(id == page_id)
	_rebuild_page()
	if changed:
		_page_scroll.scroll_vertical = 0
		EventBus.album_opened.emit(page_id)
		var tab: Button = _tabs.get(page_id)
		if tab != null and tab.is_inside_tree():
			(func() -> void:
				if is_instance_valid(tab) and tab.is_inside_tree():
					_tab_scroll.ensure_control_visible(tab)).call_deferred()


## Refreshes counts, tab labels and the current page from the collection.
func refresh() -> void:
	_refresh_queued = false
	if not is_inside_tree():
		return
	_update_header()
	_rebuild_page()


func get_page() -> Control:
	return _page_node


func get_cipher_lock() -> PanelContainer:
	return _cipher_lock


func get_inspector() -> Control:
	return _inspector


func get_reveal() -> Control:
	return _reveal


func get_tab(page_id: StringName) -> Button:
	return _tabs.get(page_id)


func get_toast_text() -> String:
	return _toast_label.text if _toast.visible else ""


## Controls that must stay on screen, inside the safe area and apart (tests).
func get_key_controls() -> Dictionary:
	return {"back": _back, "count": _count, "tabs": _tab_scroll, "page": _page_panel}


func get_important_labels() -> Array[Label]:
	return [_count, _titles, %AlbumTitle]


## Opens the inspector for a card (owned or not).
func inspect_card(card_id: StringName) -> void:
	var c: CardData = CardDB.get_card(card_id)
	if c == null:
		return
	var owned: bool = collection.owns(card_id)
	var d: Dictionary = c.to_ui_dict()
	if not owned:
		var goal: UnlockGoal = collection.goal_for_card(card_id)
		var line: String = ""
		if goal != null:
			var p: Dictionary = collection.goal_progress(goal.id)
			line = "Not owned yet. Unlock in this demo: %s (%d / %d)." % [goal.description, int(p.get("current", 0)), int(p.get("target", 1))]
		else:
			line = "Not owned yet."
		if c.how_earned != "":
			line += "\nIn the live game: %s." % c.how_earned.trim_suffix(".")
		d["earned"] = line
	_inspector.open_card(d, {})
	_inspector.get_card_view().locked = not owned
	_inspector.get_card_view().set_complete = owned and c.card_set != null and collection.is_set_complete(c.card_set.id)
	EventBus.card_inspected.emit(card_id, owned)


## Plays the panorama reveal for a Triptych (queued behind one already showing).
func play_triptych_reveal(triptych_id: StringName) -> void:
	var t: TriptychData = CardDB.get_triptych(triptych_id)
	if t == null:
		return
	if _reveal.is_open():
		if not _reveal_queue.has(triptych_id):
			_reveal_queue.append(triptych_id)
		return
	_inspector.close()
	_reveal.play(t, minf(pano_w, 1080.0))


func show_toast(text: String, seconds: float = 3.0) -> void:
	_toast_serial += 1
	var serial: int = _toast_serial
	_toast_label.text = text
	_toast.visible = true
	if is_inside_tree():
		get_tree().create_timer(seconds).timeout.connect(func() -> void:
			if serial == _toast_serial and is_instance_valid(_toast):
				_toast.visible = false)


# --- Layout ------------------------------------------------------------------------------

func _relayout() -> void:
	var logical: Vector2 = get_viewport_rect().size
	compact = logical.y < ScreenProfile.COMPACT_HEIGHT
	var margin_lt: Vector2 = BASE_MARGIN_COMPACT if compact else BASE_MARGIN
	var margin_rb: Vector2 = margin_lt
	var on_phone: bool = OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")
	if on_phone or safe_area_override.has_area():
		var window: Vector2 = Vector2(DisplayServer.window_get_size())
		var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
		if safe_area_override.has_area():
			window = logical
			safe = safe_area_override
		if window.x > 0.0 and window.y > 0.0 and safe.size.x > 0.0:
			var to_canvas: Vector2 = logical / window
			margin_lt = margin_lt.max(safe.position * to_canvas)
			margin_rb = margin_rb.max((window - safe.end) * to_canvas)
	margin_lt = margin_lt.ceil()
	margin_rb = margin_rb.ceil()
	_safe_area.add_theme_constant_override(&"margin_left", int(margin_lt.x))
	_safe_area.add_theme_constant_override(&"margin_top", int(margin_lt.y))
	_safe_area.add_theme_constant_override(&"margin_right", int(margin_rb.x))
	_safe_area.add_theme_constant_override(&"margin_bottom", int(margin_rb.y))
	_inspector.set_safe_margins(margin_lt, margin_rb)
	_inspector.compact = compact
	_reveal.set_safe_margins(margin_lt, margin_rb)
	_column.add_theme_constant_override(&"separation", 8 if compact else 12)

	var inner_w: float = logical.x - margin_lt.x - margin_rb.x
	var chrome: Vector2 = _page_panel.get_theme_stylebox(&"panel").get_minimum_size()
	var avail: float = floorf(inner_w - chrome.x - SCROLLBAR_W)
	columns = 2 if avail >= 2.0 * MIN_TWO_COL_CARD_W + GRID_GAP else 1
	card_w = floorf(minf(MAX_CARD_W, (avail - GRID_GAP * (columns - 1)) / columns))
	card_w = floorf(card_w / 4.0) * 4.0
	pano_w = floorf(minf(avail, 1080.0) / 12.0) * 12.0
	# Tabs: one row; if they do not fit the strip scrolls sideways and gets room for its bar.
	var tabs_w: float = _tab_row.get_combined_minimum_size().x
	_tab_scroll.custom_minimum_size.y = 64.0 if tabs_w <= inner_w else 64.0 + SCROLLBAR_W
	if current_page != &"":
		_rebuild_page()


func _build_tabs() -> void:
	for c: Node in _tab_row.get_children():
		c.queue_free()
	_tabs.clear()
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for id: StringName in page_ids():
		var b := Button.new()
		b.name = "Tab_%s" % id
		b.theme_type_variation = &"AlbumTab"
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(64, 64)
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.expand_icon = false
		var icon_set: StringName = &"cipher" if id == PAGE_CIPHER else id
		var tex: Texture2D = ArtIcons.cipher_glyph(1, 72.0) if id == PAGE_CIPHER else ArtIcons.set_icon(icon_set, 72.0)
		if id == PAGE_TRIPTYCHS:
			tex = null
		if tex != null:
			b.icon = _scaled_icon(tex, 24)
		var page_id: StringName = id
		b.pressed.connect(func() -> void: show_page(page_id))
		_tab_row.add_child(b)
		_tabs[id] = b
	_update_header()


func _scaled_icon(tex: Texture2D, px: int) -> Texture2D:
	var img: Image = tex.get_image()
	if img == null:
		return tex
	img = img.duplicate()
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


func _update_header() -> void:
	if collection == null:
		return
	var totals: Dictionary = collection.card_totals()
	_count.text = "%d / %d" % [int(totals["owned"]), int(totals["total"])]
	var n_titles: int = (collection.titles() as Dictionary).size()
	_titles.text = "cards · %d %s" % [n_titles, "title" if n_titles == 1 else "titles"]
	for id: StringName in _tabs:
		var b: Button = _tabs[id]
		b.text = _tab_text(id)


func _tab_text(id: StringName) -> String:
	match id:
		PAGE_TRIPTYCHS:
			return "Triptychs %d/%d" % [collection.revealed_triptychs().size(), CardDB.all_triptychs().size()]
		PAGE_CIPHER:
			return "Cipher Lock (open)" if collection.is_cipher_solved() else "Cipher Lock"
	var s: SetData = CardDB.get_set(id)
	var p: Dictionary = collection.set_progress(id)
	if s == null or p.is_empty():
		return String(id)
	return "%s %d/%d" % [s.display_name, int(p["owned"]), int(p["total"])]


func _first_page() -> StringName:
	var ids: Array[StringName] = page_ids()
	return ids[0] if not ids.is_empty() else &""


func _rebuild_page() -> void:
	if collection == null or current_page == &"":
		return
	var scroll: int = _page_scroll.scroll_vertical
	if _page_node != null:
		_page_host.remove_child(_page_node)
		if _page_node != _cipher_lock:
			_page_node.queue_free()
		_page_node = null
	if current_page == PAGE_CIPHER:
		if _cipher_lock.collection != collection or _cipher_lock.compact != compact:
			_cipher_lock.setup(collection, compact)
		else:
			_cipher_lock.sync()
		_page_node = _cipher_lock
	elif current_page == PAGE_TRIPTYCHS:
		var tp: VBoxContainer = TriptychPage.new()
		tp.build(CardDB.all_triptychs(), collection, pano_w)
		tp.replay_requested.connect(play_triptych_reveal)
		_page_node = tp
	else:
		var sp: VBoxContainer = SetPage.new()
		sp.build(CardDB.get_set(current_page), CardDB.cards_in_set(current_page), collection, card_w, columns)
		sp.inspect_requested.connect(inspect_card)
		sp.cipher_lock_requested.connect(func() -> void: show_page(PAGE_CIPHER))
		_page_node = sp
	_page_host.add_child(_page_node)
	_page_scroll.scroll_vertical = scroll
	if not _pending_celebrate.is_empty() and _page_node.has_method("get_hanger"):
		for id: StringName in _pending_celebrate.keys():
			var h: Node = _page_node.get_hanger(id)
			if h != null:
				h.celebrate()
				_pending_celebrate.erase(id)


func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	refresh.call_deferred()


# --- Celebrations (EventBus, emitted by Collection) ---------------------------------------

func _on_card_unlocked(card_id: StringName, _source_id: StringName) -> void:
	var c: CardData = CardDB.get_card(card_id)
	if c == null:
		return
	show_toast("New card: %s" % c.display_name)
	_pending_celebrate[card_id] = true
	_queue_refresh()


func _on_set_completed(set_id: StringName) -> void:
	var s: SetData = CardDB.get_set(set_id)
	if s == null:
		return
	var line: String = "Set complete: %s" % s.display_name
	if s.completion_title != "":
		line += " · title “%s” + animated set frame" % s.completion_title
	show_toast(line, 3.6)
	for c: CardData in CardDB.cards_in_set(set_id):
		_pending_celebrate[c.id] = true
	_queue_refresh()


func _on_triptych_revealed(triptych_id: StringName) -> void:
	play_triptych_reveal(triptych_id)
	_queue_refresh()


func _on_cipher_solved() -> void:
	_queue_refresh()


func _on_reveal_closed() -> void:
	if not _reveal_queue.is_empty():
		play_triptych_reveal(_reveal_queue.pop_front())


func _on_back() -> void:
	if _reveal.is_open():
		_reveal.close()
		return
	if _inspector.is_open():
		_inspector.close()
		return
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router != null:
		router.goto_scene(router.SCENE_TITLE)

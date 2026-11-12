# unit_slot.gd
# Purpose: One row slot in a board column (kc-board, board-and-cards-ux.md §3.2): a 4:1 banner
#   position on one side of the objective. index 0 = row 1 = the frontline (touching the objective).
#   Shows a unit banner (BannerView), a rival INCOMING back in its landing slot, or an empty slot
#   (dashed outline). Display only: the column (lane.gd) handles input and asks slot_uid / kind
#   which unit was hit, and animates the banner child (banner.position) for placement, the
#   Protector slide and the advance; the slot rect itself never moves (FX locator, hit tests).
# Dependencies: banner_view.gd.
# Author: Mechanics Developer Agent (kc-board), after the p09 UnitSlot (UI/UX Agent)
extends Control

enum Kind { EMPTY, UNIT, INCOMING }

## &"player" or &"enemy" (EventBus convention).
var side: StringName = &"player"
var kind: Kind = Kind.EMPTY
var compact: bool = false
## Rules uid of the unit shown (-1 when empty / incoming). Queued arrivals carry their card uid.
var slot_uid: int = -1
var pending: bool = false
var is_target: bool = false
## Row index from the objective (0 = frontline).
var row: int = 0
## INCOMING slot: name of the revealed card behind the back ("" = not revealed, f03).
var revealed: String = ""
## The unit entry shown (match_snapshot.gd unit_entry), {} when none.
var entry: Dictionary = {}
var banner: BannerView
## kc-loadout-clean: the MOVE chip (four-way arrow) on a unit that can be dragged to another column.
var move_chip: Control = null
## True while this slot's unit can move (snapshot "movable").
var movable: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner = BannerView.new()
	banner.name = "Banner"
	# kc-onboard-ui (head W1): board banners show the cost but not the name (hand, Codex and the
	# inspector keep cost + name; the hover zoom names it).
	banner.show_name = false
	banner.readability = true  # kc-hand-dim: the same dimmed art as the hand cards
	add_child(banner)
	move_chip = Control.new()
	move_chip.name = "MoveChip"
	move_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_chip.visible = false
	move_chip.draw.connect(func() -> void:
		var SynergyGlyphs: GDScript = load("res://scripts/ui/synergy_glyphs.gd")
		SynergyGlyphs.draw_move_chip(move_chip, Rect2(Vector2.ZERO, move_chip.size), Color("#2EC4B6")))
	banner.add_child(move_chip)
	resized.connect(_fit)


func _fit() -> void:
	banner.size = size
	_place_move_chip()
	queue_redraw()


## Top-right corner of the banner, a third of its height (18..30 px).
func _place_move_chip() -> void:
	var d: float = clampf(roundf(size.y * 0.42), 18.0, 30.0)
	move_chip.size = Vector2(d, d)
	move_chip.position = Vector2(size.x - d - 3.0, 3.0)
	move_chip.queue_redraw()


func set_compact(value: bool) -> void:
	compact = value


## unit: snapshot unit entry. is_point: first in line (row 1, the frontline).
func show_unit(unit: Dictionary, unit_side: StringName, is_point: bool) -> void:
	side = unit_side
	kind = Kind.UNIT
	revealed = ""
	entry = unit
	slot_uid = int(unit.get("uid", -1))
	pending = bool(unit.get("pending", false))
	banner.show_unit(unit, unit_side, is_point)
	movable = unit_side == &"player" and bool(unit.get("movable", false)) and not pending
	move_chip.visible = movable
	if movable:
		_place_move_chip()
		banner.move_child(move_chip, -1)
	queue_redraw()


## A committed but hidden rival unit, shown face-down where it will land (f03: with revealed_name
## Recon Drone / Callout showed the card, and the back says SPOTTED).
func show_incoming(revealed_name: String = "") -> void:
	side = &"enemy"
	movable = false
	move_chip.visible = false
	kind = Kind.INCOMING
	slot_uid = -1
	pending = false
	entry = {}
	revealed = revealed_name
	banner.show_incoming(revealed_name)
	queue_redraw()


func show_empty(slot_side: StringName) -> void:
	side = slot_side
	movable = false
	move_chip.visible = false
	kind = Kind.EMPTY
	revealed = ""
	slot_uid = -1
	pending = false
	entry = {}
	banner.show_empty()
	queue_redraw()


## Frames the unit as a pickable target (reticle).
func set_target(value: bool) -> void:
	is_target = value
	banner.set_target(value)


func has_art() -> bool:
	return kind == Kind.UNIT and banner.has_art()


## Board banners draw their text (numbers 16 px on the phone); no Labels to check here.
func get_important_labels() -> Array[Label]:
	return []


const EMPTY_PIECE: StringName = &"tile_slot_empty"
const EMPTY_ALPHA: float = 0.45


## Empty slot: a faint dashed outline so the 4 rows read as slots.
func _draw() -> void:
	if kind != Kind.EMPTY:
		return
	# kc-ui-wire2: the kit's empty slot backer (tile_slot_empty), faint so the cards stay the loudest
	# thing on the board; else the dashed outline.
	if UiKit.draw_piece(self, EMPTY_PIECE, Rect2(Vector2.ZERO, size), Color(1, 1, 1, EMPTY_ALPHA)):
		return
	var c: Color = Color(get_theme_color(&"text_dim", &"Hud"), 0.22)
	BannerView._dashed_rect(self, Rect2(Vector2.ZERO, size).grow(-1.0), c, 1.0)


## kc-text: hover tooltips show each concept's icon inline (IconText), like every other text.
func _make_custom_tooltip(for_text: String) -> Object:
	return IconText.tooltip(for_text)

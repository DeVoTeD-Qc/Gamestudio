# set_data.gd
# Purpose: A card set = one album page (spec §3 "Set", §5 set completion). Cards point at their
#   set (CardData.card_set); the set never lists its cards, so files don't reference each other
#   in a loop. CardDB.cards_in_set() returns the members.
#   One set = one .tres in res://data/sets/.
# Dependencies: DataEnums, DataValidator.
# Author: Mechanics Developer Agent
class_name SetData
extends Resource

@export_group("Identity")
## Unique id, lowercase snake_case (e.g. night_shift).
@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: DataEnums.SetKind = DataEnums.SetKind.STANDARD
## Album page order, 1 = first page. Unique across sets. Also the "set numbering" that hints the Cipher Lock order.
@export_range(1, 20) var number: int = 0

@export_group("Look")
## Palette / art key the art kit uses for this set's duotone posters (art-direction §4).
@export var palette_key: StringName = &""
## One-line theme for the album page header.
@export var tagline: String = ""

@export_group("Completion reward (cosmetic only)")
## Title granted for owning every card of the set (e.g. "Night Owl"). Required for STANDARD sets.
@export var completion_title: String = ""


func validate(v: DataValidator) -> void:
	v.require_id(id)
	v.require_text("display_name", display_name)
	v.check_enum("kind", kind, DataEnums.SetKind)
	v.check_range("number", number, 1, 20)
	v.check_line("tagline", tagline, 80)
	v.check_line("completion_title", completion_title, 32)
	if String(palette_key).is_empty():
		v.missing("palette_key", "palette_key is empty (the art kit needs it)")
	if kind == DataEnums.SetKind.STANDARD and completion_title.strip_edges().is_empty():
		v.missing("completion_title", "a standard set needs a completion title")

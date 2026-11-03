# wall_palette.gd
# Purpose: Banner Wall UI colors from art direction §4 (one place, so cc14's theme and the
#   placeholder theme agree). Ownership is never shown by color alone: see card_view.gd (tabs).
# Dependencies: none.
# Author: UI/UX Agent (cc07)
extends RefCounted

const WALL_BG: Color = Color("#14161B")
const MORTAR: Color = Color("#23262E")
const TEXT: Color = Color("#ECE8DF")
## Dimmed text; 7.4:1 on WALL_BG.
const TEXT_DIM: Color = Color("#B4AFA4")
const PLAYER: Color = Color("#3EC6C1")
const RIVAL: Color = Color("#F2705A")
const AMBER: Color = Color("#F5B63F")
const SIGNATURE: Color = Color("#E9D8A6")
const ENAMEL: Color = Color("#0E1014")

## Poster duotones per set (art direction §4): [dark/primary, light/secondary].
const SET_COLORS: Dictionary = {
	&"night_shift": [Color("#C2408A"), Color("#47B8D6")],
	&"whiteout": [Color("#4E6475"), Color("#CFE3EE")],
	&"signal_fire": [Color("#1D2A44"), Color("#E0452E")],
	&"old_guard": [Color("#5A1F24"), Color("#B98A3E")],
	&"cipher": [Color("#0B0B0D"), Color("#3FE0C5")],
	&"showcase": [Color("#2A2D33"), Color("#D9D4C7")],
}


static func owner_color(owner: StringName) -> Color:
	match owner:
		&"player":
			return PLAYER
		&"rival":
			return RIVAL
	return TEXT_DIM


static func set_colors(set_id: StringName) -> Array:
	return SET_COLORS.get(set_id, [MORTAR, TEXT_DIM])

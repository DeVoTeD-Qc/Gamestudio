# board_metrics.gd
# Purpose: The board grid of board-layout-v2.md (kc-board2, approved) as numbers. The board takes the
#   full height; an icon strip sits on one side and the hand tray on the other (strip left / tray
#   right, swapped by the "mirror layout" setting):
#     bh = floor((H - 2*pad_y - 2*mid_gap - obj_h - 6*row_gap) / 8),   bw = 4 * bh
#     tray_w = W - strip_w - side_gap - board_w - tray_gap
#   If the tray would get narrower than tray_min, the banners shrink (keeping 4:1) until it fits.
#   Phone 844x390 (canvas 1168x540, safe area 1156x540): banners 228x57, strip 6..68, columns
#     76 / 318 / 560, tray 800..1162, hand cards 104x130 in a 3x3 grid.
#   16:9 phone (canvas 960x540): banners 208x52, tray 214 wide, a 2-column hand.
#   Desktop 1440x900 (canvas 1280x800): banners 304x76, columns 86 / 410 / 734, tray 1050..1274,
#     hand cards 108x136 in a 2x4 grid.
# Usage: var m: Dictionary = BoardMetrics.compute(Vector2(1156, 540), true)   # pure, tested
# Author: Mechanics Developer Agent (kc-board, kc-board2)
extends RefCounted

const COLUMNS: int = 3
const ROWS: int = 4
## The hand grid is sized for this many cards (run_config.hand_cap; more overlap upward).
const HAND_SLOTS: int = 7
## Hand cards keep about the option A proportions (104x130).
const CARD_RATIO: float = 0.8
const PHONE: Dictionary = {"pad_y": 4.0, "row_gap": 3.0, "mid_gap": 3.0, "obj_h": 52.0, "gutter": 14.0,
		"strip_w": 62.0, "badge_h": 64.0, "badge_gap": 5.0, "side_gap": 8.0, "tray_gap": 12.0, "tray_min": 210.0,
		"tray_pad": 4.0, "card_max": Vector2(104, 130), "card_gap": 8.0, "supply_h": 48.0, "btn_h": 64.0, "tab_h": 64.0}
const DESKTOP: Dictionary = {"pad_y": 12.0, "row_gap": 6.0, "mid_gap": 6.0, "obj_h": 96.0, "gutter": 20.0,
		"strip_w": 68.0, "badge_h": 64.0, "badge_gap": 8.0, "side_gap": 12.0, "tray_gap": 12.0, "tray_min": 224.0,
		"tray_pad": 12.0, "card_max": Vector2(108, 136), "card_gap": 8.0, "supply_h": 48.0, "btn_h": 72.0, "tab_h": 64.0}


## area: the safe-area size the match screen lays out in. mirror: tray left, strip right.
## Returns {bh, bw, ...PHONE/DESKTOP values, compact, mirror, board: Rect2, strip: Rect2, tray: Rect2,
## col_x: [x of A, B, C] (board-local), half_h, card: Vector2, hand_cols, grid: Rect2 (tray-local)}.
## Rects are area-local.
static func compute(area: Vector2, compact: bool, mirror: bool = false) -> Dictionary:
	var p: Dictionary = (PHONE if compact else DESKTOP).duplicate()
	var fixed_h: float = 2.0 * p["pad_y"] + 2.0 * p["mid_gap"] + p["obj_h"] + 6.0 * p["row_gap"]
	var bh: float = floorf((area.y - fixed_h) / 8.0)
	# Width left for the board once the strip and the tray's minimum are taken.
	var max_board: float = area.x - p["strip_w"] - p["side_gap"] - p["tray_gap"] - p["tray_min"]
	var max_bw: float = floorf((max_board - (COLUMNS - 1) * p["gutter"]) / COLUMNS)
	if bh * 4.0 > max_bw:
		bh = floorf(max_bw / 4.0)
	bh = maxf(bh, 24.0)
	var bw: float = bh * 4.0
	var board_w: float = COLUMNS * bw + (COLUMNS - 1) * p["gutter"]
	var half_h: float = ROWS * bh + (ROWS - 1) * p["row_gap"]
	var board_h: float = 2.0 * half_h + 2.0 * p["mid_gap"] + p["obj_h"]
	var top: float = floorf((area.y - board_h) * 0.5)
	var strip_x: float = 0.0
	var board_x: float = p["strip_w"] + p["side_gap"]
	var tray_x: float = board_x + board_w + p["tray_gap"]
	var tray_w: float = area.x - tray_x
	var pad: float = p["tray_pad"]
	var strip: Rect2 = Rect2(strip_x, pad, p["strip_w"], area.y - 2.0 * pad)
	var board: Rect2 = Rect2(board_x, top, board_w, board_h)
	var tray: Rect2 = Rect2(tray_x, pad, tray_w, area.y - 2.0 * pad)
	if mirror:
		strip.position.x = area.x - strip.end.x
		board.position.x = area.x - board.end.x
		tray.position.x = area.x - tray.end.x
	p["compact"] = compact
	p["mirror"] = mirror
	p["bh"] = bh
	p["bw"] = bw
	p["half_h"] = half_h
	p["board"] = board
	p["strip"] = strip
	p["tray"] = tray
	p["col_x"] = [0.0, bw + p["gutter"], 2.0 * (bw + p["gutter"])]
	_hand_grid(p, tray.size)
	return p


## The hand grid inside the tray: between the Supply row and the UNDO / READY row. Picks 3 or 2
## columns, whichever gives the larger card (cards up to card_max, HAND_SLOTS cards without overlap).
static func _hand_grid(p: Dictionary, tray: Vector2) -> void:
	var gap: float = p["card_gap"]
	var grid_top: float = p["supply_h"] + 8.0
	var grid_h: float = tray.y - grid_top - p["btn_h"] - 6.0
	var cmax: Vector2 = p["card_max"]
	var best: Vector2 = Vector2.ZERO
	var best_cols: int = 2
	for cols: int in [3, 2]:
		var rows: int = ceili(float(HAND_SLOTS) / cols)
		var h: float = minf(cmax.y, floorf((grid_h - (rows - 1) * gap) / rows))
		var w: float = minf(cmax.x, minf(floorf(h * CARD_RATIO), floorf((tray.x - (cols - 1) * gap) / cols)))
		h = minf(h, roundf(w * 1.26))
		if w * h > best.x * best.y:
			best = Vector2(w, h)
			best_cols = cols
	var grid_w: float = best_cols * best.x + (best_cols - 1) * gap
	p["card"] = best
	p["hand_cols"] = best_cols
	p["grid"] = Rect2(floorf((tray.x - grid_w) * 0.5), grid_top, grid_w, grid_h)


## Column-local y of a row slot. side &"enemy": row 0 (front) is nearest the objective (above it).
static func row_y(m: Dictionary, side: StringName, row: int) -> float:
	var pitch: float = m["bh"] + m["row_gap"]
	if side == &"enemy":
		return (ROWS - 1 - row) * pitch
	return m["half_h"] + 2.0 * m["mid_gap"] + m["obj_h"] + row * pitch


static func objective_y(m: Dictionary) -> float:
	return m["half_h"] + m["mid_gap"]


## Badge rects of the icon strip (strip-local): MENU, SCORE, OPERATOR, STREAK, RIVAL, PREVIEW from
## the top, DECK at the bottom (board-layout-v2.md §2.1).
static func badge_rects(m: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var strip: Rect2 = m["strip"]
	var h: float = m["badge_h"]
	for i: int in 6:
		out.append(Rect2(0, i * (h + m["badge_gap"]), strip.size.x, h))
	out.append(Rect2(0, strip.size.y - h, strip.size.x, h))
	return out

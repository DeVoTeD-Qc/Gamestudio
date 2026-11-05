# board_metrics.gd
# Purpose: The board grid of board-and-cards-ux.md §2 as numbers: banner size from the height,
#   3 columns x (4 rival rows + objective + 4 own rows), the hand row under them, and the rails.
#     bh = (H - top - 2*mid_gap - obj_h - hand_gap - hand_h - 2*3*row_gap) / 8,   bw = 4 * bh
#   Phone 844x390 (canvas 1168x540): banners 176x44, columns 300..868, hand 442..540.
#   Desktop 1440x900 (canvas 1280x800): banners 256x64, columns 232..1048, hand 660..800.
#   bw shrinks (keeping 4:1) when the rails would get narrower than RAIL_MIN (notches, 4:3).
# Usage: var m: Dictionary = BoardMetrics.compute(Vector2(1168, 540), true)   # pure, tested
# Author: Mechanics Developer Agent (kc-board)
extends RefCounted

const COLUMNS: int = 3
const ROWS: int = 4
## [top, row_gap, mid_gap, obj_h, hand_gap, hand_h, gutter, hand card w, rail gap, rail_min]
const PHONE: Dictionary = {"top": 4.0, "row_gap": 3.0, "mid_gap": 4.0, "obj_h": 54.0, "hand_gap": 6.0,
		"hand_h": 98.0, "gutter": 20.0, "card_w": 78.0, "card_gap": 4.0, "rail_gap": 12.0, "rail_min": 204.0}
const DESKTOP: Dictionary = {"top": 12.0, "row_gap": 5.0, "mid_gap": 8.0, "obj_h": 80.0, "hand_gap": 10.0,
		"hand_h": 140.0, "gutter": 24.0, "card_w": 108.0, "card_gap": 8.0, "rail_gap": 18.0, "rail_min": 196.0}


## area: the safe-area size the match screen lays out in (rails + board + hand).
## Returns {bh, bw, ...PHONE/DESKTOP values, board: Rect2, hand: Rect2, left: Rect2, right: Rect2,
## col_x: [x of A, B, C] (board-local), half_h, card: Vector2}. Rects are area-local.
static func compute(area: Vector2, compact: bool) -> Dictionary:
	var p: Dictionary = (PHONE if compact else DESKTOP).duplicate()
	var fixed: float = p["top"] + 2.0 * p["mid_gap"] + p["obj_h"] + p["hand_gap"] + p["hand_h"] + 6.0 * p["row_gap"]
	var bh: float = floorf((area.y - fixed) / 8.0)
	var bw: float = bh * 4.0
	# Keep both rails at least rail_min wide.
	var max_board: float = area.x - 2.0 * (p["rail_min"] + p["rail_gap"])
	var max_bw: float = floorf((max_board - 2.0 * p["gutter"]) / COLUMNS)
	if bw > max_bw:
		bw = floorf(max_bw / 4.0) * 4.0
		bh = bw / 4.0
	bh = maxf(bh, 24.0)
	bw = bh * 4.0
	var board_w: float = COLUMNS * bw + (COLUMNS - 1) * p["gutter"]
	var half_h: float = ROWS * bh + (ROWS - 1) * p["row_gap"]
	var board_h: float = 2.0 * half_h + 2.0 * p["mid_gap"] + p["obj_h"]
	var used_h: float = p["top"] + board_h + p["hand_gap"] + p["hand_h"]
	var top: float = p["top"] + maxf(0.0, (area.y - used_h) * 0.5)
	var x0: float = floorf((area.x - board_w) * 0.5)
	p["bh"] = bh
	p["bw"] = bw
	p["half_h"] = half_h
	p["board"] = Rect2(x0, top, board_w, board_h)
	p["hand"] = Rect2(x0, top + board_h + p["hand_gap"], board_w, p["hand_h"])
	p["left"] = Rect2(0, 0, x0 - p["rail_gap"], area.y)
	p["right"] = Rect2(x0 + board_w + p["rail_gap"], 0, area.x - (x0 + board_w + p["rail_gap"]), area.y)
	p["col_x"] = [0.0, bw + p["gutter"], 2.0 * (bw + p["gutter"])]
	p["card"] = Vector2(p["card_w"], p["hand_h"])
	return p


## Column-local y of a row slot. side &"enemy": row 0 (front) is nearest the objective (above it).
static func row_y(m: Dictionary, side: StringName, row: int) -> float:
	var pitch: float = m["bh"] + m["row_gap"]
	if side == &"enemy":
		return (ROWS - 1 - row) * pitch
	return m["half_h"] + 2.0 * m["mid_gap"] + m["obj_h"] + row * pitch


static func objective_y(m: Dictionary) -> float:
	return m["half_h"] + m["mid_gap"]

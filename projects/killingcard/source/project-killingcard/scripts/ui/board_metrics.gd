# board_metrics.gd
# Purpose: The board grid of board-layout-v2.md (kc-board2, approved) as numbers. The board takes the
#   full height; an icon strip sits on one side and the hand tray on the other (strip left / tray
#   right, swapped by the "mirror layout" setting):
#     bh = floor((H - 2*pad_y - 2*mid_gap - obj_h - 6*row_gap) / 8),   bw = 4 * bh
#     tray_w = W - strip_w - side_gap - board_w - tray_gap
#   If the tray would get narrower than tray_min, the banners shrink (keeping 4:1) until it fits.
#   Phone 844x390 (canvas 1168x540, safe area 1156x540): banners 228x57, strip 6..68, columns
#     76 / 318 / 560, tray 800..1162 (kc-ui3: the Supply row grows to 64 px to hold the 3 killstreak
#     tiles; the Operator card takes the grid's first cell). kc-ui4: hand cards are banner cards,
#     2 columns of 177x73.
#   16:9 phone (canvas 960x540): banners 208x52, tray 214 wide, killstreaks in their own row, a
#     2-column hand of 103x78 banner cards (name in the middle band).
#   Desktop 1440x900 (canvas 1280x800): banners 304x76, columns 86 / 410 / 734, tray 1050..1274,
#     hand cards 224x64 banner cards in one column.
# Usage: var m: Dictionary = BoardMetrics.compute(Vector2(1156, 540), true)   # pure, tested
# Author: Mechanics Developer Agent (kc-board, kc-board2)
extends RefCounted

const COLUMNS: int = 3
const ROWS: int = 4
## The hand grid is sized for this many cards (run_config.hand_cap 7 + the Operator card, kc-ui3;
## more overlap upward).
const HAND_SLOTS: int = 8
## kc-ui3: killstreak tiles at the top of the tray (3 per loadout). On a wide tray (phone 844x390)
## they share the Supply row, which grows to ks_h; on a narrow one (desktop, 16:9 phone) they get
## their own row under it.
const KS_SLOTS: int = 3
const KS_GAP: float = 4.0
## Supply text + pips need this much of a shared row.
const SUPPLY_MIN_W: float = 150.0
## kc-ui4: hand cards are banners: at least this tall (plate row + stat row) and wide, and at most
## this square (width / height) in wide / narrow cells.
const CARD_MIN_H: float = 64.0
const CARD_MIN_W: float = 96.0
const CARD_RATIO_WIDE: float = 2.4
const CARD_RATIO_MIN: float = 1.3
const PHONE: Dictionary = {"pad_y": 4.0, "row_gap": 3.0, "mid_gap": 3.0, "obj_h": 52.0, "gutter": 14.0,
		"strip_w": 62.0, "badge_h": 64.0, "badge_gap": 5.0, "side_gap": 8.0, "tray_gap": 12.0, "tray_min": 210.0,
		"tray_pad": 4.0, "card_max": Vector2(104, 130), "card_gap": 8.0, "supply_h": 48.0, "btn_h": 64.0, "tab_h": 64.0,
		"ks_h": 64.0, "ks_w": 62.0}
const DESKTOP: Dictionary = {"pad_y": 12.0, "row_gap": 6.0, "mid_gap": 6.0, "obj_h": 96.0, "gutter": 20.0,
		"strip_w": 68.0, "badge_h": 64.0, "badge_gap": 8.0, "side_gap": 12.0, "tray_gap": 12.0, "tray_min": 224.0,
		"tray_pad": 12.0, "card_max": Vector2(108, 136), "card_gap": 8.0, "supply_h": 48.0, "btn_h": 72.0, "tab_h": 64.0,
		"ks_h": 64.0, "ks_w": 62.0}


## area: the safe-area size the match screen lays out in. mirror: tray left, strip right.
## Returns {bh, bw, ...PHONE/DESKTOP values, compact, mirror, board: Rect2, strip: Rect2, tray: Rect2,
## col_x: [x of A, B, C] (board-local), half_h, card: Vector2, hand_cols, grid: Rect2 (tray-local),
## supply: Rect2, ks: Rect2 (killstreak tiles), ks_inline: bool (tray-local; supply_h = the top block)}.
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
	_ks_rows(p, tray.size)
	_hand_grid(p, tray.size)
	return p


## kc-ui3: the Supply row and the killstreak tiles. supply_h becomes the height of the whole top block.
static func _ks_rows(p: Dictionary, tray: Vector2) -> void:
	var ks_w: float = KS_SLOTS * p["ks_w"] + (KS_SLOTS - 1) * KS_GAP
	var inline: bool = tray.x >= ks_w + 8.0 + SUPPLY_MIN_W
	p["ks_inline"] = inline
	if inline:
		p["supply"] = Rect2(0, 0, tray.x - ks_w - 8.0, p["ks_h"])
		p["ks"] = Rect2(tray.x - ks_w, 0, ks_w, p["ks_h"])
		p["supply_h"] = p["ks_h"]
	else:
		p["supply"] = Rect2(0, 0, tray.x, p["supply_h"])
		p["ks"] = Rect2(0, p["supply_h"] + 6.0, tray.x, p["ks_h"])
		p["supply_h"] = p["supply_h"] + 6.0 + p["ks_h"]


## The hand grid inside the tray: between the Supply row and the UNDO / READY row. kc-ui4 (head:
## hand cards "closer to their form on the board"): the cards are banners, so the grid picks 1, 2 or
## 3 columns, whichever gives the larger card that still holds the banner's plate row and stat row
## (h >= CARD_MIN_H) and is no squarer than CARD_RATIO_MIN (wide cells: CARD_RATIO_WIDE, the
## licensed 4:1 art keeps most of its width). HAND_SLOTS cards fit without overlap.
static func _hand_grid(p: Dictionary, tray: Vector2) -> void:
	var gap: float = p["card_gap"]
	var grid_top: float = p["supply_h"] + 8.0
	var grid_h: float = tray.y - grid_top - p["btn_h"] - 6.0
	var best: Vector2 = Vector2.ZERO
	var best_cols: int = 2
	for cols: int in [1, 2, 3]:
		var rows: int = ceili(float(HAND_SLOTS) / cols)
		var w: float = floorf((tray.x - (cols - 1) * gap) / cols)
		var h: float = floorf((grid_h - (rows - 1) * gap) / rows)
		var ratio: float = CARD_RATIO_WIDE if w >= 150.0 else CARD_RATIO_MIN
		if w < CARD_MIN_W or h < CARD_MIN_H:
			continue
		h = clampf(floorf(minf(p["bh"] * 1.4, w / ratio)), CARD_MIN_H, h)
		if w * h > best.x * best.y:
			best = Vector2(w, h)
			best_cols = cols
	if best == Vector2.ZERO:
		best = Vector2(floorf((tray.x - gap) / 2.0), CARD_MIN_H)
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


## kc-syn-ui: the trait rail's rect (strip-local) between the PREVIEW badge and DECK.
static func rail_rect(m: Dictionary) -> Rect2:
	var rects: Array[Rect2] = badge_rects(m)
	var gap: float = m["badge_gap"]
	var top: float = rects[5].end.y + gap
	var bottom: float = rects[6].position.y - gap
	return Rect2(0, top, (m["strip"] as Rect2).size.x, maxf(0.0, bottom - top))

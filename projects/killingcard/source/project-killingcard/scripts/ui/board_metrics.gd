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
#     2 columns (kc-ipad-cards: their height follows the hand's count, hand_fit()).
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
	# kc-portrait: a tall screen (height > width) gets the portrait layout.
	if is_portrait(area):
		return compute_portrait(area)
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


## kc-cards-impl (the head's H1 + O2): the hand grid holds X1 cards (the C1+ banner plus a
## name plate, X1_PLATE_H) between the Supply row and the Operator row. The Operator row at the
## bottom: the Operator card on the left, UNDO (icon) stacked over READY on the right (each
## btn_h tall, >= 44 pt); kc-ipad-cards: a narrow desktop / iPad tray stacks it (op_stacked).
## kc-ipad-cards: the grid spans the tray; card / hand_cols are hand_fit() for a 7-card hand and
## HandArea re-fits them to the real count. Keys: card, hand_cols, hand_min_h, grid (the cards'
## rect), hand_rect (the HandArea's rect = the grid; the Operator card is placed below it, in the
## Operator row), op_card, undo, ready, op_h, op_stacked (tray-local).
const X1_PLATE_H: float = 26.0
const X1_MIN_W: float = 80.0
## X1 cards are at least this tall (a 44 pt tap target on the smallest phone, the SE at 0.695 pt/px):
## narrow cards grow their plate. Desktop (1 pt/px) needs 44 px; its 1-column cards are taller anyway.
const X1_MIN_H: float = 64.0
const X1_MIN_H_DESKTOP: float = 48.0


## The X1 hand card's size at width w (the banner at 4:1 plus the name plate, >= min_h).
static func x1_size(w: float, min_h: float = X1_MIN_H) -> Vector2:
	return Vector2(w, maxf(min_h, roundf(w / 4.0) + X1_PLATE_H))


static func _hand_grid(p: Dictionary, tray: Vector2) -> void:
	var gap: float = p["card_gap"]
	var btn_h: float = p["btn_h"]
	var compact: bool = bool(p.get("compact", true))
	# kc-ipad-cards (the head's iPad playtest: "fix the hand not using the entire space", READY read
	# "READ"): a narrow, tall tray (desktop / iPad sizes, < STACK_TRAY_W wide) stacks the Operator row:
	# the Operator card across the tray, then UNDO (icon) beside a wide READY. A wide tray (the phone)
	# keeps the Operator card beside UNDO over READY.
	var stacked: bool = not compact and tray.x < STACK_TRAY_W
	var op_card_h: float = clampf(roundf(tray.x * 0.55), 110.0, 150.0)
	var op_h: float = (op_card_h + 6.0 + btn_h) if stacked else (2.0 * btn_h + 6.0)
	var grid_top: float = p["supply_h"] + 8.0
	var grid_h: float = tray.y - grid_top - op_h - 8.0
	var min_h: float = X1_MIN_H if compact else X1_MIN_H_DESKTOP
	# The grid fills the tray's width; HandArea re-fits the cards to the hand's count (hand_fit()).
	var fit: Dictionary = hand_fit(Vector2(tray.x, grid_h), HAND_SLOTS - 1, gap, min_h)
	p["card"] = fit["card"]
	p["hand_cols"] = fit["cols"]
	p["hand_min_h"] = min_h
	p["grid"] = Rect2(0, grid_top, tray.x, grid_h)
	p["op_h"] = op_h
	p["op_stacked"] = stacked
	p["hand_rect"] = p["grid"]
	if stacked:
		var uw: float = clampf(roundf(tray.x * 0.3), 64.0, 96.0)
		p["op_card"] = Rect2(0, tray.y - op_h, tray.x, op_card_h)
		p["undo"] = Rect2(0, tray.y - btn_h, uw, btn_h)
		p["ready"] = Rect2(uw + 6.0, tray.y - btn_h, tray.x - uw - 6.0, btn_h)
		return
	var bcol: float = 140.0 if compact else 132.0
	bcol = minf(bcol, floorf(tray.x * 0.52))
	p["op_card"] = Rect2(0, tray.y - op_h, tray.x - bcol - 8.0, op_h)
	p["undo"] = Rect2(tray.x - bcol, tray.y - op_h, bcol, btn_h)
	p["ready"] = Rect2(tray.x - bcol, tray.y - btn_h, bcol, btn_h)


## kc-ipad-cards: trays narrower than this (desktop / iPad: 224 px) stack the Operator row.
const STACK_TRAY_W: float = 300.0
## The hand never sizes its cards for fewer than this many (one or two cards stay a sensible size).
const HAND_FIT_MIN_N: int = 4


## kc-ipad-cards: the X1 card size and columns for `n` hand cards in a grid of size `grid`: the
## layout whose cards get the biggest badges (BannerCard.badge_px) wins, then the one covering more of
## the grid. Cards are as tall as the rows allow (the banner up to 2.4:1), so the hand fills the tray.
## When no layout reaches READABLE_PX badges (13 pt on the smallest phone), the hand SCROLLS: one
## column (two when wide enough) of readable cards, `visible` of them at a time.
## Returns {card: Vector2, cols: int, scroll: bool, visible: int, s: float}.
static func hand_fit(grid: Vector2, n: int, gap: float, min_h: float) -> Dictionary:
	var count: int = maxi(n, HAND_FIT_MIN_N)
	var room: float = grid.y - 6.0  # the selected card's lift (HandArea.SELECTED_LIFT)
	var best: Dictionary = {}
	for cols: int in [1, 2, 3]:
		var w: float = floorf((grid.x - (cols - 1) * gap) / cols)
		if w < X1_MIN_W:
			continue
		var rows: int = ceili(float(count) / cols)
		var h: float = floorf((room - (rows - 1) * gap) / rows)
		h = minf(h, x1_max_h(w))
		if h < maxf(min_h, x1_min_h(w)):
			continue
		var c: Vector2 = Vector2(w, h)
		var s: float = BannerCard.badge_px(c)
		var score: float = BannerCard.fit_score(c)
		var cover: float = minf(1.0, float(mini(n, rows * cols)) * w * h / maxf(1.0, grid.x * room))
		if best.is_empty() or score > float(best["score"]) + 0.5 or (absf(score - float(best["score"])) <= 0.5 and cover > float(best["cover"])):
			best = {"card": c, "cols": cols, "scroll": false, "visible": n, "s": s, "cover": cover, "score": score}
	if not best.is_empty() and float(best["score"]) >= BannerCard.READABLE_PX:
		return best
	# Scroll: the shortest card that reaches READABLE_PX, in the widest column(s) that allow it.
	for cols: int in [2, 1]:
		var w2: float = floorf((grid.x - (cols - 1) * gap) / cols)
		if w2 < X1_MIN_W:
			continue
		var h2: float = maxf(min_h, x1_min_h(w2))
		while h2 <= x1_max_h(w2) and BannerCard.fit_score(Vector2(w2, h2)) < BannerCard.READABLE_PX:
			h2 += 1.0
		if h2 > x1_max_h(w2) or h2 > room:
			continue
		var per_col: int = maxi(1, int(floorf((room + gap) / (h2 + gap))))
		var vis: int = per_col * cols
		if vis >= n:
			return {"card": Vector2(w2, h2), "cols": cols, "scroll": false, "visible": n, "s": BannerCard.badge_px(Vector2(w2, h2)), "cover": 0.0}
		return {"card": Vector2(w2, h2), "cols": cols, "scroll": true, "visible": vis, "s": BannerCard.badge_px(Vector2(w2, h2)), "cover": 0.0}
	if best.is_empty():
		var w3: float = floorf((grid.x - gap) / 2.0)
		return {"card": x1_size(w3, min_h), "cols": 2, "scroll": false, "visible": n, "s": BannerCard.badge_px(x1_size(w3, min_h)), "cover": 0.0}
	return best


## The shortest an X1 card of width w gets (its banner at most 6:1: still a banner, not a strip).
static func x1_min_h(w: float) -> float:
	return ceilf((w - 4.0) / BannerCard.BANNER_MIN_RATIO + BannerCard.PLATE_H + 4.0)


## The tallest an X1 card of width w gets (its banner at most 2.4:1, plus the name plate and inset).
static func x1_max_h(w: float) -> float:
	return floorf((w - 4.0) / BannerCard.BANNER_MAX_RATIO + BannerCard.PLATE_H + 4.0)


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
	if bool(m.get("portrait", false)):
		# kc-portrait: the strip is a top bar: the 7 badges in one row (MENU ... DECK).
		var gap: float = m["badge_gap"]
		var bw: float = floorf((strip.size.x - 6.0 * gap) / 7.0)
		for i: int in 7:
			out.append(Rect2(i * (bw + gap), 0, bw, h))
		return out
	for i: int in 6:
		out.append(Rect2(0, i * (h + m["badge_gap"]), strip.size.x, h))
	out.append(Rect2(0, strip.size.y - h, strip.size.x, h))
	return out


## kc-syn-ui: the trait rail's rect (strip-local) between the PREVIEW badge and DECK.
static func rail_rect(m: Dictionary) -> Rect2:
	if bool(m.get("portrait", false)):
		var top0: float = float(m["badge_h"]) + float(m["badge_gap"])
		return Rect2(0, top0, (m["strip"] as Rect2).size.x, maxf(0.0, (m["strip"] as Rect2).size.y - top0))
	var rects: Array[Rect2] = badge_rects(m)
	var gap: float = m["badge_gap"]
	var top: float = rects[5].end.y + gap
	var bottom: float = rects[6].position.y - gap
	return Rect2(0, top, (m["strip"] as Rect2).size.x, maxf(0.0, bottom - top))


# =============================================================================
# kc-portrait: the iPhone portrait layout (the head: "investigate the fan cards at the bottom for the
# portrait version"; landscape and PC keep the side tray). From the L1 portrait mock-up
# (card-design-options.html, Layout v3): top bars (the 7 badges, then the sets rail), the board
# stacked under them (3 columns, 4:1 banners ~169x42 on a 540 px wide canvas), then the tray: the
# Supply / killstreak row, the preview well (left) with the Operator and UNDO / READY (right), and a
# swipeable fan of Y2+ hand cards at the bottom.
# =============================================================================

## Fan card width and the step between cards: 68 px = 44 pt down to a 360 pt wide phone (0.667 pt/px).
const FAN_CARD_W: float = 176.0
const FAN_STEP: float = 68.0
## Button height in portrait (44 pt on a 360 pt wide phone).
const PORTRAIT_BTN_H: float = 68.0
const PORTRAIT_GUTTER: float = 8.0
const PORTRAIT_PAD: float = 8.0
const PORTRAIT_RIGHT_W: float = 216.0


static func is_portrait(area: Vector2) -> bool:
	return area.y > area.x


## Same keys as compute() plus portrait (true), fan (true), well (tray-local Rect2), fan_step.
static func compute_portrait(area: Vector2) -> Dictionary:
	var p: Dictionary = PHONE.duplicate()
	p["portrait"] = true
	p["fan"] = true
	p["btn_h"] = PORTRAIT_BTN_H
	p["compact"] = true
	p["mirror"] = false
	var pad: float = PORTRAIT_PAD
	p["gutter"] = PORTRAIT_GUTTER
	var w: float = area.x - 2.0 * pad
	var rail_h: float = 52.0
	var strip: Rect2 = Rect2(pad, 6.0, w, p["badge_h"] + p["badge_gap"] + rail_h)
	var bh: float = floorf((w - 2.0 * PORTRAIT_GUTTER) / 3.0 / 4.0)
	var bw: float = bh * 4.0
	var board_w: float = COLUMNS * bw + (COLUMNS - 1) * PORTRAIT_GUTTER
	var half_h: float = ROWS * bh + (ROWS - 1) * p["row_gap"]
	var board_h: float = 2.0 * half_h + 2.0 * p["mid_gap"] + p["obj_h"]
	var board: Rect2 = Rect2(floorf((area.x - board_w) * 0.5), strip.end.y + 8.0, board_w, board_h)
	var tray: Rect2 = Rect2(pad, board.end.y + 8.0, w, maxf(0.0, area.y - board.end.y - 8.0 - 4.0))
	p["bh"] = bh
	p["bw"] = bw
	p["half_h"] = half_h
	p["board"] = board
	p["strip"] = strip
	p["tray"] = tray
	p["col_x"] = [0.0, bw + PORTRAIT_GUTTER, 2.0 * (bw + PORTRAIT_GUTTER)]
	_ks_rows(p, tray.size)
	var card: Vector2 = Vector2(FAN_CARD_W, CardView.height_for(FAN_CARD_W))
	var fan_y: float = tray.size.y - card.y - 10.0
	var fan: Rect2 = Rect2(0, fan_y, tray.size.x, card.y + 10.0)
	p["card"] = card
	p["hand_cols"] = HAND_SLOTS
	p["fan_step"] = FAN_STEP
	p["grid"] = fan
	p["hand_rect"] = fan
	var y0: float = float(p["supply_h"]) + 8.0
	var y1: float = fan_y - 8.0
	var mid_h: float = maxf(0.0, y1 - y0)
	var rx: float = tray.size.x - PORTRAIT_RIGHT_W
	var btn_h: float = p["btn_h"]
	p["op_h"] = mid_h
	p["well"] = Rect2(0, y0, rx - 8.0, mid_h)
	p["op_card"] = Rect2(rx, y0, PORTRAIT_RIGHT_W, maxf(btn_h, mid_h - btn_h - 8.0))
	p["undo"] = Rect2(rx, y1 - btn_h, 70.0, btn_h)
	p["ready"] = Rect2(rx + 78.0, y1 - btn_h, PORTRAIT_RIGHT_W - 78.0, btn_h)
	return p

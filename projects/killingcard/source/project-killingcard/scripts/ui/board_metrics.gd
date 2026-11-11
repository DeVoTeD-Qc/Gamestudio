# board_metrics.gd
# Purpose: The board grid of board-layout-v2.md (kc-board2, approved) as numbers. The board takes the
#   full height; an icon strip sits on one side and the hand tray on the other (strip left / tray
#   right, swapped by the "mirror layout" setting):
#     bh = floor((H - 2*pad_y - 2*mid_gap - obj_h - 6*row_gap) / 8),   bw = 4 * bh
#     tray_w = W - strip_w - side_gap - board_w - tray_gap
#   If the tray would get narrower than tray_min, the banners shrink (keeping 4:1) until it fits.
#   kc-layout-a (ux-layout-v2.html direction A, the head's L1-L5): the TRAY is sized first (phone
#   tray_min 346 px = 250 pt: 7 cards + the Operator in a 2-column grid that never scrolls); the board
#   takes the rest. The killstreak sockets sit in the strip under STREAK; landscape drops the OPERATOR
#   badge (the Operator card is the hand grid's first card); the phone's sets rail moves to the tray's
#   top row beside the Supply box. Faces: full / mid (rule lines) where there is room, compact at 6-7.
#   Phone 844x390 (canvas 1168x540, safe area 1156x540): banners 228x57 (unchanged), tray 362 wide,
#     7 cards: 177x90 compact cards; 4 cards: 177x127 full faces.
#   Safari 750x390 (canvas 1038x540): banners 192x48, tray 352. 16:9 phone (canvas 960x540): banners
#     164x41, tray 346, 169x90 cards.
#   Desktop 1440x900 (canvas 1280x800): banners 304x76, tray 224 (one column; 7 cards: 224x72).
#   Portrait: the same grid under the board (no fan, no preview well).
# Usage: var m: Dictionary = BoardMetrics.compute(Vector2(1156, 540), true)   # pure, tested
# Author: Mechanics Developer Agent (kc-board, kc-board2), UI/UX Agent (kc-layout-a)
extends RefCounted

const COLUMNS: int = 3
const ROWS: int = 4
## The hand grid is sized for this many cards (run_config.hand_cap 7 + the Operator card; kc-layout-a:
## it never scrolls or overlaps).
const HAND_SLOTS: int = 8
## Killstreak sockets per loadout (kc-layout-a: in the icon strip, ks_rect()).
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
		"strip_w": 62.0, "badge_h": 61.0, "badge_gap": 2.0, "side_gap": 8.0, "tray_gap": 12.0, "tray_min": 346.0,
		"tray_pad": 4.0, "card_max": Vector2(104, 130), "card_gap": 8.0, "supply_h": 48.0, "btn_h": 64.0, "tab_h": 64.0,
		"ks_h": 64.0, "ks_w": 62.0, "menu_h": 61.0, "ks_v_h": 61.0}
const DESKTOP: Dictionary = {"pad_y": 12.0, "row_gap": 6.0, "mid_gap": 6.0, "obj_h": 96.0, "gutter": 20.0,
		"strip_w": 68.0, "badge_h": 64.0, "badge_gap": 4.0, "side_gap": 12.0, "tray_gap": 12.0, "tray_min": 224.0,
		"tray_pad": 12.0, "card_max": Vector2(108, 136), "card_gap": 8.0, "supply_h": 48.0, "btn_h": 72.0, "tab_h": 64.0,
		"ks_h": 64.0, "ks_w": 62.0, "menu_h": 64.0, "ks_v_h": 64.0}


## area: the safe-area size the match screen lays out in. mirror: tray left, strip right.
## Returns {bh, bw, ...PHONE/DESKTOP values, compact, mirror, board: Rect2, strip: Rect2, tray: Rect2,
## col_x: [x of A, B, C] (board-local), half_h, card: Vector2, hand_cols, face, grid: Rect2 (tray-local),
## supply: Rect2, ks: Rect2 (the killstreak sockets, STRIP-local since kc-layout-a), ks_in_strip,
## ks_vertical, undo, ready (tray-local)}. Rects are area-local.
## kc-layout-a (the head's L1: direction A): the TRAY is sized first. It gets tray_min (phone 346 px =
## 250 pt: a 2-column grid of 7 cards plus the Operator, never scrolling); the board takes what is left
## and its banners shrink (4:1) on narrow phones (750 / 667), never the hand.
static func compute(area: Vector2, compact: bool, mirror: bool = false) -> Dictionary:
	# kc-portrait: a tall screen (height > width) gets the portrait layout.
	if is_portrait(area):
		return compute_portrait(area)
	var p: Dictionary = (PHONE if compact else DESKTOP).duplicate()
	var fixed_h: float = 2.0 * p["pad_y"] + 2.0 * p["mid_gap"] + p["obj_h"] + 6.0 * p["row_gap"]
	var bh: float = floorf((area.y - fixed_h) / 8.0)
	# Width left for the board once the strip and the tray's guaranteed width are taken.
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


## kc-layout-a (the head's L4): the killstreak sockets live in the icon strip, under the STREAK
## counter (landscape: 3 stacked sockets, ks_v_h tall; portrait: at the right end of the rail row).
## The tray's top row is the Supply box alone (supply_h). p["ks"] is STRIP-local.
static func _ks_rows(p: Dictionary, tray: Vector2) -> void:
	p["ks_inline"] = false
	p["ks_in_strip"] = true
	p["supply"] = Rect2(0, 0, tray.x, p["supply_h"])
	# kc-layout-a: landscape drops the OPERATOR badge (the Operator card is the hand's first card and
	# the sockets took its killstreak buttons), so every strip badge keeps its 44 pt / 64 px target.
	p["op_badge"] = bool(p.get("portrait", false))
	p["ks"] = ks_rect(p)
	p["ks_vertical"] = not bool(p.get("portrait", false))
	# The phone strip has no room left for the sets rail: it sits in the tray's top row, right of the
	# Supply box (tray-local rail_tray); desktop keeps it in the strip.
	if bool(p.get("compact", false)) and not bool(p.get("portrait", false)):
		# The row is a 44 pt target (the rail's initiative chip and set chips are tappable).
		p["supply_h"] = maxf(float(p["supply_h"]), float(p["badge_h"]))
		var rw: float = floorf(tray.x * 0.36)
		p["supply"] = Rect2(0, 0, tray.x - rw - 6.0, p["supply_h"])
		p["rail_tray"] = Rect2(tray.x - rw, 0, rw, p["supply_h"])


## The killstreak sockets' block (strip-local).
static func ks_rect(m: Dictionary) -> Rect2:
	var strip: Rect2 = m["strip"]
	if bool(m.get("portrait", false)):
		var w: float = KS_SLOTS * KS_PORTRAIT_W + (KS_SLOTS - 1) * KS_GAP
		var top0: float = float(m["badge_h"]) + float(m["badge_gap"])
		return Rect2(strip.size.x - w, top0, w, maxf(0.0, strip.size.y - top0))
	var gap: float = m["badge_gap"]
	var above: float = 3.0 if bool(m.get("op_badge", true)) else 2.0
	var y: float = float(m["menu_h"]) + gap + above * (float(m["badge_h"]) + gap)
	return Rect2(0, y, strip.size.x, KS_SLOTS * float(m["ks_v_h"]) + (KS_SLOTS - 1) * minf(gap, 2.0))


## kc-layout-a (the head's L1 + L3): the tray is the Supply box on top, the hand grid, and UNDO
## (icon) + READY sharing the bottom row. The Operator is the hand grid's FIRST card (HandArea), the
## same size as the others, marked by its brass frame and OPERATOR tab. The grid is sized for
## HAND_SLOTS (7 cards + the Operator) and HandArea re-fits it to the real count (hand_fit()): it never
## scrolls and cards never overlap. Keys: card, hand_cols, face, hand_min_h, grid (= hand_rect),
## op_card (the grid's first cell for a full hand; HandArea places the real one), undo, ready.
static func _hand_grid(p: Dictionary, tray: Vector2) -> void:
	var gap: float = p["card_gap"]
	var btn_h: float = p["btn_h"]
	var compact: bool = bool(p.get("compact", true))
	var grid_top: float = p["supply_h"] + 8.0
	var grid_h: float = maxf(0.0, tray.y - grid_top - btn_h - 8.0)
	var min_h: float = X1_MIN_H if compact else X1_MIN_H_DESKTOP
	var fit: Dictionary = hand_fit(Vector2(tray.x, grid_h), HAND_SLOTS, gap, min_h, HAND_SLOTS - 1)
	p["card"] = fit["card"]
	p["hand_cols"] = fit["cols"]
	p["face"] = fit["face"]
	p["hand_min_h"] = min_h
	p["grid"] = Rect2(0, grid_top, tray.x, grid_h)
	p["hand_rect"] = p["grid"]
	p["op_h"] = 0.0
	p["op_stacked"] = false
	p["op_card"] = Rect2(Vector2(0, grid_top + 6.0), fit["card"])
	var uw: float = clampf(roundf(tray.x * 0.26), 64.0, 96.0)
	p["undo"] = Rect2(0, tray.y - btn_h, uw, btn_h)
	p["ready"] = Rect2(uw + 6.0, tray.y - btn_h, tray.x - uw - 6.0, btn_h)


const X1_PLATE_H: float = 26.0
const X1_MIN_W: float = 80.0
## X1 cards are at least this tall (a 44 pt tap target on the smallest phone, the SE at 0.695 pt/px).
## Desktop (1 pt/px) needs 44 px.
const X1_MIN_H: float = 64.0
const X1_MIN_H_DESKTOP: float = 48.0


## The X1 hand card's size at width w (the banner at 4:1 plus the name plate, >= min_h).
static func x1_size(w: float, min_h: float = X1_MIN_H) -> Vector2:
	return Vector2(w, maxf(min_h, roundf(w / 4.0) + X1_PLATE_H))


## Kept for callers: trays narrower than this used to stack the Operator row (kc-ipad-cards).
const STACK_TRAY_W: float = 300.0
## The hand never sizes its cards for fewer than this many (one or two cards stay a sensible size).
const HAND_FIT_MIN_N: int = 4
## kc-layout-a (the head's L2): a hand card's rule line (mid face: 1 line, full face: 2 lines), under
## its name plate. At 6-7 hand cards the face is compact (name, cost, art, FP, Armor; the rule is a
## long press away).
const RULE_LINE_H: float = 20.0
const COMPACT_FROM: int = 6
const FACE_COMPACT: StringName = &"compact"
const FACE_MID: StringName = &"mid"
const FACE_FULL: StringName = &"full"


## Rule lines of a face (compact 0, mid 1, full 2).
static func rule_lines(face: StringName) -> int:
	return {FACE_MID: 1, FACE_FULL: 2}.get(face, 0)


## kc-layout-a: the face a hand card of size `card` shows with `hand_cards` cards in hand.
static func face_for(card: Vector2, hand_cards: int) -> StringName:
	if hand_cards >= COMPACT_FROM:
		return FACE_COMPACT
	var w: float = card.x - 4.0
	if card.y >= roundf(w / 3.4) + BannerCard.PLATE_H + 4.0 + 2.0 * RULE_LINE_H:
		return FACE_FULL
	if card.y >= roundf(w / 5.0) + BannerCard.PLATE_H + 4.0 + RULE_LINE_H:
		return FACE_MID
	return FACE_COMPACT


## kc-layout-a (the head's L1 + L2): the card size, columns and face for `n` items (hand cards plus
## the Operator card) in a grid of size `grid`. The layout whose cards get the biggest badges
## (BannerCard.fit_score) plus a bonus for a richer face wins, then the one covering more of the
## grid. The hand NEVER scrolls and cards never overlap: when no layout reaches the comfortable
## minimum, the rows share the room anyway (compact faces). hand_cards (-1 = n) picks the face rule
## (compact from COMPACT_FROM cards). Returns {card: Vector2, cols, face, rule_lines, scroll (always
## false), visible (= n), s}.
static func hand_fit(grid: Vector2, n: int, gap: float, min_h: float, hand_cards: int = -1) -> Dictionary:
	var count: int = maxi(n, HAND_FIT_MIN_N)
	var cards_n: int = hand_cards if hand_cards >= 0 else n
	var room: float = grid.y - 6.0  # the selected card's lift (HandArea.SELECTED_LIFT)
	var best: Dictionary = {}
	for cols: int in [1, 2, 3]:
		var w: float = floorf((grid.x - (cols - 1) * gap) / cols)
		if w < X1_MIN_W:
			continue
		var rows: int = ceili(float(count) / cols)
		var h: float = floorf((room - (rows - 1) * gap) / rows)
		h = minf(h, x1_max_h(w) + 2.0 * RULE_LINE_H)
		if h < maxf(min_h, x1_min_h(w)):
			continue
		var face: StringName = face_for(Vector2(w, h), cards_n)
		h = minf(h, x1_max_h(w) + rule_lines(face) * RULE_LINE_H)
		var c: Vector2 = Vector2(w, h)
		var core: Vector2 = Vector2(w, h - rule_lines(face) * RULE_LINE_H)
		var score: float = BannerCard.fit_score(core) + {FACE_MID: 3.0, FACE_FULL: 5.0}.get(face, 0.0)
		var cover: float = minf(1.0, float(mini(n, rows * cols)) * w * h / maxf(1.0, grid.x * room))
		if best.is_empty() or score > float(best["score"]) + 0.5 or (absf(score - float(best["score"])) <= 0.5 and cover > float(best["cover"])):
			best = {"card": c, "cols": cols, "scroll": false, "visible": n, "s": BannerCard.badge_px(core), "cover": cover,
					"score": score, "face": face, "rule_lines": rule_lines(face)}
	if not best.is_empty():
		return best
	# Too tight for the comfortable minimum: still no scroll, no overlap. The column count whose cards
	# get the most area (compact faces); the rows share the room.
	var fb: Dictionary = {}
	for cols2: int in [1, 2, 3]:
		var w2: float = floorf((grid.x - (cols2 - 1) * gap) / cols2)
		if w2 < X1_MIN_W * 0.8:
			continue
		var rows2: int = ceili(float(count) / cols2)
		var h2: float = maxf(24.0, floorf((room - (rows2 - 1) * gap) / rows2))
		h2 = minf(h2, x1_max_h(w2))
		if fb.is_empty() or w2 * h2 > (fb["card"] as Vector2).x * (fb["card"] as Vector2).y:
			fb = {"card": Vector2(w2, h2), "cols": cols2}
	if fb.is_empty():
		fb = {"card": Vector2(maxf(24.0, grid.x), maxf(24.0, floorf((room - (count - 1) * gap) / count))), "cols": 1}
	var c2: Vector2 = fb["card"]
	return {"card": c2, "cols": fb["cols"], "scroll": false, "visible": n, "s": BannerCard.badge_px(c2), "cover": 0.0,
			"score": 0.0, "face": FACE_COMPACT, "rule_lines": 0}


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
## the top, DECK at the bottom (board-layout-v2.md §2.1). kc-layout-a: the killstreak sockets
## (ks_rect) sit between STREAK and RIVAL; MENU is menu_h tall; in landscape OPERATOR gets a 0-high
## rect (op_badge false: hidden).
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
	var g: float = m["badge_gap"]
	var y: float = 0.0
	for i: int in 6:
		if i == 4:
			y = ks_rect(m).end.y + g
		var bh: float = float(m.get("menu_h", h)) if i == 0 else h
		if i == 2 and not bool(m.get("op_badge", true)):
			out.append(Rect2(0, y, strip.size.x, 0.0))  # kc-layout-a: no OPERATOR badge in landscape
			continue
		out.append(Rect2(0, y, strip.size.x, bh))
		y += bh + g
	out.append(Rect2(0, strip.size.y - h, strip.size.x, h))
	return out


## kc-syn-ui: the trait rail's rect (strip-local) between the PREVIEW badge and DECK (portrait: the
## row under the badges, left of the killstreak sockets).
static func rail_rect(m: Dictionary) -> Rect2:
	if bool(m.get("portrait", false)):
		var top0: float = float(m["badge_h"]) + float(m["badge_gap"])
		var ks: Rect2 = ks_rect(m)
		return Rect2(0, top0, maxf(0.0, ks.position.x - 8.0), maxf(0.0, (m["strip"] as Rect2).size.y - top0))
	var rects: Array[Rect2] = badge_rects(m)
	var gap: float = m["badge_gap"]
	var top: float = rects[5].end.y + gap
	var bottom: float = rects[6].position.y - gap
	return Rect2(0, top, (m["strip"] as Rect2).size.x, maxf(0.0, bottom - top))


# =============================================================================
# kc-portrait: the iPhone portrait layout. From the L1 portrait mock-up (card-design-options.html,
# Layout v3): top bars (the 7 badges, then the sets rail with the killstreak sockets at its right
# end, kc-layout-a), the board stacked under them (3 columns, 4:1 banners ~169x42 on a 540 px wide
# canvas), then the tray. kc-layout-a (ux-layout-v2.html, direction A portrait): no fan and no
# preview well any more: the Supply box, the same 2-column hand grid as landscape (the Operator
# first, never scrolling, never overlapping), and UNDO + READY on the bottom row.
# =============================================================================

## Kept for callers (the kc-portrait fan, replaced by the grid in kc-layout-a).
const FAN_CARD_W: float = 176.0
const FAN_STEP: float = 68.0
## Button height in portrait (44 pt on a 360 pt wide phone).
const PORTRAIT_BTN_H: float = 68.0
const PORTRAIT_GUTTER: float = 8.0
const PORTRAIT_PAD: float = 8.0
const PORTRAIT_RIGHT_W: float = 216.0
## kc-layout-a: a killstreak socket's width in the portrait rail row.
const KS_PORTRAIT_W: float = 64.0


static func is_portrait(area: Vector2) -> bool:
	return area.y > area.x


## Same keys as compute() plus portrait (true), fan (false since kc-layout-a).
static func compute_portrait(area: Vector2) -> Dictionary:
	var p: Dictionary = PHONE.duplicate()
	p["portrait"] = true
	p["fan"] = false
	p["badge_h"] = 64.0
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
	_hand_grid(p, tray.size)
	return p

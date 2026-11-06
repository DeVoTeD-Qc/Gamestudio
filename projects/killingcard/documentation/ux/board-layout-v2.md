# KillingCard: Board Layout v2 (full-height board)

*Owner: UI/UX Agent. Board task: kc-ux2. Status: proposal for the head's review (2026-11-05).*
*Input: the head's playtest note ("the cards are very small... use as much vertical space as possible to show the board with the 3 columns"), `board-and-cards-ux.md` (v1, with the kc-board and kc-polish notes), the build screenshots `qa/screenshots/board/*.webp`.*
*Mock-up: `documentation/ux/mockup/index.html`, toolbar **Layout: Layout v2** (or `?layout=v2`). Screenshots: `documentation/ux/mockup/shots/v2-*.png` (Playwright, device scale factor 1, true device size).*

Every px value is a **Godot logical px**, as in v1: the phone 844x390 is a 1168x540 canvas (1 px = 0.7226 pt), and desktop 1440x900 is 1280x800 (1 px = 1.125 physical px).

---

## 0. Summary

1. **The board takes the full height.** On a landscape phone the banner size depends only on the height (4:1 banners, 8 rows plus the objective). v1 spent 98 px of the 540 on the hand row and 14 px on the gaps around it. v2 gives that height to the rows, so **phone banners grow from 176x44 to 228x57: 1.68x the area** (127x32 pt to 165x41 pt). The target was 1.4x.
2. **The hand moves to a side tray** on the right. Taller banners make the board wider (3x228 + gutters = 712 px), and the hand fits in the width that is left. The tray is **open during Deploy** (auto-opens) and **closes to a slim `HAND · n  PEEK` tab** during Reveal and the Firefight. In the freed space it shows the firefight step and a killfeed log. **The board never resizes or gets covered by the hand.** Hand cards also get bigger: 104x130 instead of 78x98 (1.77x).
3. **The rails become a 62 px icon strip on the left**: MENU, SCORE, OPERATOR, KILLSTREAKS, RIVAL HAND, PREVIEW, DECK. Each badge shows its key value. Tap opens a flyout; long-press or right-click opens the rules. SUPPLY, UNDO and READY live in the tray. The killfeed becomes **transient toasts** at the top of the board, plus a log in the closed tray.
4. **The objective tile is shorter and laid out sideways** (228x52 instead of 176x66). Left to right: FP pair, control mark, range and control words, Field chips.
5. **Side effect: the phone tap pitch is now 60 px (43 pt)**, almost the 44 pt minimum (v1: 34 pt). Badge numbers go from 16 to 20 px.
6. **Desktop gets the same layout**: banners go from 256x64 to 304x76 (1.41x).
7. **Portrait was evaluated and is not recommended.** On a 390 pt-wide screen, three 4:1 columns are limited by the width, so the best fit is 168x42: smaller than today (0.91x) and 0.54x of v2 landscape. Stacking the columns vertically is worse still (§5). **Recommendation: stay landscape-only.**

| Banner | v1 (today) | v2 | Area |
|---|---|---|---|
| Phone 844x390 | 176x44 px (127x32 pt) | **228x57 px (165x41 pt)** | **1.68x** |
| Phone 16:9 (canvas 960x540) | 176x44 (v1 did not change by aspect) | 208x52 | 1.40x |
| Desktop 1440x900 | 256x64 px (288x72 phys.) | **304x76 px (342x86 phys.)** | **1.41x** |
| Portrait 390x844 (evaluated) | n/a | 168x42 px (121x30 pt) | 0.91x (rejected) |

Screenshots, before and after: `shots/v2-phone-before-v1.png` (v1 in the mock-up) and `qa/screenshots/board/phone-r3-deploy.webp` (the build), compared with `shots/v2-phone-deploy.png`.

---

## 1. Options considered

| Option | Phone banner | Verdict |
|---|---|---|
| v1: hand row at the bottom, two ~270 px rails | 176x44 | baseline |
| Hand as a **bottom drawer** over the board (opens in Deploy) | 228x57 when closed | **Rejected.** When open, the drawer covers your rows 3 and 4, which hold the landing slots and ghosts you need while deploying. Covering the board in exactly the phase where you aim cards defeats the point. |
| Rails collapsed, **hand row kept at the bottom** | 176x44 (unchanged) | **Rejected.** On landscape the height is the limit. Narrower rails only add width, which 4:1 banners can't use without more height. |
| **Hand in a side tray + rails as an icon strip** (chosen) | **228x57** | The height goes to the board. The width it frees (once the columns are wider) holds the tray. Nothing covers the board. |
| Chosen + objective tile **overlaid** between the fronts (no own row) | ~232x58 (+1 px per row) | **Rejected.** It gains 2% for a tile that must still show FP, control, range and two Field chips (a head decision). A 52 px row is the better trade. |
| **Portrait**, 3 columns side by side | 168x42 | **Rejected** (§5). |
| Portrait, the columns stacked vertically | ≤160x40 | **Rejected** (§5). |

The general rule is `bh = floor((H − top − bottom − 2·midGap − objH − 6·rowGap) / 8)` and `bw = 4·bh`. The tray gets whatever width is left: `trayW = W − strip − board − gaps`. If a screen is too narrow for a 3-column tray, the tray drops to 2 columns, and only then do banners shrink (§2.3).

---

## 2. Layout v2: exact numbers

### 2.1 Phone 844x390 (canvas 1168x540): the main target
| Element | x | y | Size (px) | pt |
|---|---|---|---|---|
| **Icon strip** | 6..68 | | 62 wide | 45 |
| Badges MENU, SCORE, OPERATOR, STREAK, RIVAL, PREVIEW | 6..68 | 4, 73, 142, 211, 280, 349 | 62x64 each, 5 px gap | 45x46 |
| Badge DECK (bottom) | 6..68 | 472..536 | 62x64 | |
| **Columns A / B / C** | 76..304 / 318..546 / 560..788 | | 228 wide, 14 px gutters | 165 |
| Rival rows 4 (back), 3, 2, 1 (front) | | 4..61, 64..121, 124..181, 184..241 | **228x57**, 3 px row gap | **165x41** |
| Objective tile | | 244..296 | 228x52 | 165x38 |
| Your rows 1 (front), 2, 3, 4 (back) | | 299..356, 359..416, 419..476, 479..536 | 228x57 | 165x41 |
| **Tray** | 800..1162 | 4..536 | 362 wide | 262 |
| Supply row | 800..1162 | 4..52 | 362x48 | |
| Hand grid, 3x3 (Deploy) | cards at x 817 / 929 / 1041 | 60 / 198 / 336 (to 466) | **104x130 cards**, 8 px gap | 75x94 |
| UNDO / READY | 800..909 / 917..1162 | 472..536 | 109x64 / 245x64 | 79x46 / 177x46 |
| *Firefight*: tray header and killfeed log | 800..1162 | from 60 | 16 px lines | |
| *Firefight*: `HAND · n  PEEK ▲` tab | 800..1162 | 416..464 | 362x48 | |
| *Firefight*: SPEED x2 (in place of UNDO / READY) | 800..1162 | 472..536 | 362x64 | |

Vertical budget: 4 + 4x57 + 3x3 (rival) + 3 + 52 + 3 + 237 (yours) + 4 = **540**. Horizontal: 6 + 62 + 8 + 712 + 12 + 362 + 6 = **1168**.

Banner contents scale up with the banner:

| | v1 phone | v2 phone |
|---|---|---|
| FP / Armor badge, number | 22 px badge, 16 px number (11.6 pt, at the floor) | **28 px badge, 20 px number (14.5 pt)** |
| Keyword / class / dog-tag plates | 18 px | 22 px |
| `FRONT` tab | 40x11 | 48x13 |
| Slot tap pitch | 47 px (34 pt): below 44 pt | **60 px (43 pt)**: at the minimum (snapping stays as a safety net) |
| Hand card | 78x98, art window 78x56 | **104x130, art window 104x76** (1.81x art), cost hex 26x30 with an 18 px number, name 16 px (~9 characters), stats 18 px |

The hand grid has 9 slots, and the hand cap is 7 (`run_config.hand_cap`, settable up to 10). With 10 cards the third row overlaps upward (the step shrinks), just as v1's row compressed horizontally.

### 2.2 Desktop 1440x900 (canvas 1280x800)
| Element | x | y | Size (px) |
|---|---|---|---|
| Icon strip | 6..74 | badges at 12, 84, 156, 228, 300, 372; DECK 724..788 | 68x64 |
| Columns A / B / C | 86..390 / 410..714 / 734..1038 | | 304 wide, 20 px gutters |
| Rival rows 4..1 | | 24..100, 106..182, 188..264, 270..346 | **304x76**, 6 px gap |
| Objective tile | | 352..448 | 304x96 |
| Your rows 1..4 | | 454..530, 536..612, 618..694, 700..776 | 304x76 |
| Tray | 1050..1274 | 12..788 | 224 wide |
| Supply row | | 12..60 | 224x48 |
| Hand grid, 2x4 | 1050 / 1166 | 68, 212, 356, 500 (to 636) | 108x136 cards (v1: 108x140) |
| UNDO / READY | 1050..1117 / 1125..1274 | 716..788 | 67x72 / 149x72 |
| Badges / numbers / plates | | | 34 / 24 / 26 px |
| Hover zoom | | | 608 px wide (2x, as in v1) |

On desktop the width is the limit: the tray needs 2 card columns. 24 px of height is spare at the top and bottom. Desktop players can use the hover peek, which now appears to the left of the tray, level with the hovered card.

### 2.3 Other aspect ratios
- **16:9 phones (canvas 960x540):** strip 6..68, board 76..728 (208x52 banners, 12 px gutters), tray 740..954. The hand is a 2-column grid of 78x97 cards (v1 size), 4 rows. Banners are still 1.40x v1.
- **Wider phones (20:9 and up):** the banners stay 228x57 (height-limited), and the extra width widens the gaps around the tray.
- **Tablets (4:3, canvas 960x720):** the board is height-limited again, at 208x52 if the width runs out first. Tablets are out of scope, as in v1.

---

## 3. What moved where, and how to reach it

| v1 element (rail) | v2 home | How you reach it |
|---|---|---|
| Score box (round, phase, score, mode) | **SCORE badge** (strip 2): `R3` over `1-2` in side colours | Always visible. Tap: score sheet (mode, first-to, round history). Long-press: mode rules. |
| Operator panel (name, FP / AR, streak, perks, position) | **OPERATOR badge** (strip 3): camo swatch plus current Armor (`5/7`), or the respawn countdown when downed | Tap: flyout with name, FP / AR chips, position ("On board: A, row 2"), camo tier and perks (`shots/v2-phone-operator-flyout.png`). The Operator is still found on the board by its brass frame. |
| Killstreak buttons (P-12, FRAG, FLASH, RECON, MORTAR, ATTACK) | **STREAK badge** (strip 4): streak count. **Glows amber when a killstreak is ready**, with a one-time callout. | Tap: flyout with the 6 tiles at 61 px each (`v2-phone-killstreak-flyout.png`). Tapping a ready tile arms it and closes the flyout. Long-press a tile: its rules. |
| Rival hand count, per-column intel, archetype tags | **RIVAL badge** (strip 5): card count | Tap: flyout with the count, planned per column, and the archetype tags. The per-column plans are on the board anyway (INCOMING backs). |
| PREVIEW toggle | **PREVIEW badge** (strip 6): eye icon plus ON / OFF | Tap toggles it; the forecast still draws on the objective tiles. |
| Deck / Used | **DECK badge** (strip bottom): deck count | Tap: deck and used counts. |
| MENU | **MENU badge** (strip top) | Unchanged behaviour. |
| UNDO | Tray, bottom left (109x64) | Deploy only. |
| READY | Tray, bottom right (**245x64**, 177x46 pt) | Deploy only. In the Firefight the slot becomes SPEED x2. |
| Supply | Tray top row: 5 pips plus `4/5` | Always visible. Long-press: rules. |
| Killfeed (right rail) | **Toasts** at the top centre of the board, over the rival back row: 16 px, 2.5 s, at most 2 stacked, no input. **Plus a log** in the closed tray during the Firefight. | Toasts are automatic. Tapping a log line highlights both cards on the board. |
| Hand row | **Tray**, a 3x3 grid on the phone (2x4 on desktop) | Opens on its own in Deploy. Otherwise, tap the `HAND · n PEEK` tab. |
| Firefight step labels (FIRST SHOT / MAIN) | Unchanged (column top edge, per kc-polish), and repeated in the tray header | |
| Tutorial callouts | Unchanged (over the objective row) | |

The strip badges all follow one rule: **tap shows a flyout** next to the badge (light scrim; tap anywhere to close), and **long-press or right-click shows the rules**, as the studio UX rule requires. No information is hover-only or hidden without a visible badge value.

---

## 4. Interaction changes

1. **Tray states.**
   - **Open:** opens on its own at the start of Deploy.
   - **Closed:** closes on its own when READY is pressed or the Deploy timer ends. It stays closed through Reveal, the Firefight and Score & Streak, and shows the step header, the killfeed log and the `HAND · n PEEK ▲` tab.
   - **Peek:** tap the tab outside Deploy to open the tray read-only. Cards can be inspected but not played, and are tagged `NEXT DEPLOY`. It closes on a tap outside or when the next step starts.
   - The tray swaps its content in place (a 200 ms cross-fade, plus a 160 ms slide on the cards). **The board never moves or resizes**, so no layout shift happens mid-firefight.
2. **Selecting a hand card:** the card **shifts 14 px toward the board** and gets the teal outline and animation. This replaces v1's 14% rise, because in a grid a rise would cover the card above. Valid columns, ghosts, `PLAY HERE` and `TAKES THE FRONT` work as in v1 (`v2-phone-selected.png`, `v2-phone-selected-protector.png`).
3. **Playing:** tap the card, then tap a column (the main path). Dragging still works, but the drag is longer (about 500 px to column A), so tap-tap is the taught path.
4. **Placement animation:** the hand card morphs from the tray **into the back-row slot** of its column, at scale 1.04, and then slides to the landing slot as in v1 §5. In v1 the card entered just outside the back row, but in v2 the back row touches the screen edge. Protector: unchanged (lands, then slides to row 1). The rival's cards still enter from the top edge.
5. **Desktop hover peek:** the full-banner peek of a hovered hand card appears **left of the tray**, level with the card. In v1 it appeared above the card.
6. **Objective tile (sideways layout):** rival FP over your FP | control mark (40 px; circle, diamond or dashed square) | range word over control word (16 px) | Field chips (rival chip top-right, yours bottom-right, 70x22, 16 px). **`CONTESTED` becomes `EVEN`**, because 9 characters don't fit at the 16 px floor and the mark's shape already encodes control. Long-press: objective rules, as before.
7. **Inspector and hover zoom:** unchanged (512x128 inspector banner on the phone; desktop hover zoom at 608 px, which is 2x the new banner).
8. **Unit targeting:** the snapping and chooser from v1 §4.5 stay. With a 43 pt pitch the chooser should rarely appear.

---

## 5. Portrait evaluation (390x844)

With Godot's base 540x960 and expand, portrait is a **540x1168** canvas (1 px = 0.7222 pt).
- **3 columns side by side** (the board as it is, rotated screen): the width now limits the columns. `bw = (540 − 2·10 − 2·8) / 3 = 168`, so banners are **168x42**: 0.91x v1 and 0.54x v2 landscape. The board uses only 412 px of the 1168 height. Most of the screen goes to the hand and buttons, which is the opposite of the goal (`shots/v2-portrait-eval.png`). The objective tile (168 px wide) cannot fit FP, mark, words and Field chips at the 16 px floor.
- **Columns stacked vertically** (A on top of B on top of C, each with 9 rows): that is 24 banner rows plus 3 tiles in about 1100 px, so `bh` is about 40 and `bw` about 160. The three objectives are also no longer side by side, which breaks the "read all 3 fronts at once" scan.
- **The board turned 90°** (the columns become horizontal lanes): the 4:1 banners would have to sit side by side, 8 per lane, so each would be about 60 px wide. Unworkable without rotating the art.

**Recommendation: landscape only**, as Killstreak. 4:1 art and 3 side-by-side columns are a landscape format. Portrait would need a different card format (for example 2:1 banners), which would reopen the art direction.

---

## 6. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Things behind badges are less discoverable (killstreaks, Operator details) | Each badge shows its live value. STREAK glows amber with a one-time "Killstreak ready" callout when one is usable. The first match's tutorial taps each badge once. The Operator is always visible on the board. |
| Killfeed toasts cover the rival back row for 2.5 s | They take no input, sit at 92% opacity and stack at most 2. The tray log keeps the full history. Option: anchor each toast over the column where the kill happened, so it covers only that column's empty back slot. |
| The hand is on the right, which is less comfortable for left-handed players | A settings toggle mirrors the layout (tray left, strip right). The board itself is symmetric. |
| Long drag to column A | Tap-tap is the main input. Dragging still snaps to the nearest column. |
| A grid hand reads less like a "hand" than a fanned row | The order runs left to right, top to bottom, with newly drawn cards last. If playtests miss the fan, the 3x3 grid can become an overlapping vertical fan in the same box at no layout cost. |
| 16:9 phones get smaller gains (208x52, hand at v1 size) | Still 1.40x, which meets the target. The formula in §1 and §2.3 is the one to implement, not fixed px. |
| Implementation touches many scenes (`board_metrics.gd`, `Match.tscn` rails, `hand_area.gd`, `match_screen.gd`, `test_board_columns.gd` metrics) and collides with the private pitch build in progress | Implement after the pitch build lands, as one task. `board_metrics.gd` gets the §1 formula, plus new `IconStrip`, `HandTray` (OPEN / CLOSED / PEEK, driven by the phase signals) and `KillfeedToast` scenes. The rules layer and the banner, lane and objective internals stay, except for the tile's sideways layout. |
| The `PLAN` tag overlaps the FP badge's corner on the phone (also true in v1) | Move `PLAN` to the inner-edge centre (beside the `FRONT` tab position) when implementing. |

---

## 7. Mock-up guide (v2)
Toolbar: **Layout** (v1 / Layout v2), **Screen** (phone / desktop / portrait eval), **Phase** (Deploy: tray open / Firefight: tray closed), and the v2 demos (Operator badge, Killstreak badge, Killfeed toast) alongside the v1 demos, which all work in v2. URL: `?layout=v2&size=phone|desktop|portrait&phase=deploy|firefight&state=selected|placement|protector|focus|hover|flyout|killfeed&which=op|streak&pick=1&chrome=0`.

| Screenshot (`mockup/shots/`) | Shows |
|---|---|
| `v2-phone-before-v1.png` | v1 in the mock-up at the same size, for comparison |
| `v2-phone-deploy.png` | v2 phone in Deploy: strip, full-height board, open tray |
| `v2-phone-selected.png`, `v2-phone-selected-protector.png` | Selection: the card shifts toward the board, ghosts, `TAKES THE FRONT` |
| `v2-phone-placement-mid.png`, `v2-phone-protector-slide.png` | Placement from the tray, and the Protector slide |
| `v2-phone-firefight.png` | Tray closed (step, killfeed log, HAND tab, SPEED x2), killfeed toasts, Pick tracer |
| `v2-phone-operator-flyout.png`, `v2-phone-killstreak-flyout.png` | Strip badge flyouts |
| `v2-phone-focus-zoom.png` | Inspector (unchanged) over v2 |
| `v2-desktop-deploy.png`, `v2-desktop-selected.png`, `v2-desktop-firefight.png`, `v2-desktop-hover-zoom.png` | Desktop v2 |
| `v2-portrait-eval.png` | The portrait evaluation (rejected): 168x42 banners |

---

## 8. Questions for the head
1. **Tray in the Firefight:** (a) it closes on its own to the `HAND · n PEEK` tab and shows the killfeed log. **Recommended.** (b) It stays open with the cards dimmed.
2. **Killfeed:** (a) toasts at the top of the board plus the log in the tray. **Recommended.** (b) Log in the tray only, with nothing over the board.
3. **Handedness:** (a) the tray on the right, with a "mirror layout" setting for left-handed players. **Recommended.** (b) Always on the right.

---

## Implementation notes (kc-board2, Mechanics Developer, 2026-11-05)
Built in `source/project-killingcard` to the head's answers: the tray closes to `HAND · n PEEK` in the Firefight and shows the killfeed log; killfeed = toasts over the board + the tray log; tray on the right with a **MIRROR LAYOUT** setting; landscape only. Everything else from kc-board / kc-polish is unchanged (3 columns x 4 rows, Protector slide and B1 shift preview, PLAN / INCOMING, Fields + Overrun on the objective tile, inspect everywhere, hand option A / 4:1 strip for licensed art).

**Measured in the public web build** (Playwright, device scale factor 1, `?qa=1&seed=101` and `303`): phone 844x390: banners **228x57** logical (164.8x41.2 CSS px), hand cards 104x130, tray 362 wide (800..1162); desktop 1440x900: banners **304x76** (342x85.5 CSS px), hand cards 108x136, tray 224 wide (1050..1274); hover zoom 608 px. Headless tests also check 16:9 (208x52, 2-column hand) and the notched phone.

| Piece | Where |
|---|---|
| §1 / §2 numbers: banner size from the height, tray minimum, strip, badge rows, hand grid (3 or 2 columns, whichever card is larger), mirror | `scripts/ui/board_metrics.gd` (`compute(area, compact, mirror)`, `badge_rects()`) |
| Icon strip badges (glyph + live value, amber glow; tap / long-press / right-click) | `scripts/ui/strip_badge.gd`; MENU and PREVIEW stay real Buttons (eye glyph over ON / OFF) |
| Flyouts: SCORE (ScoreBar), OPERATOR (Operator panel info), STREAK (streak meter + the 6 tiles), RIVAL (intel), DECK; light scrim, tap outside closes, a tile tap closes it | `scenes/Match.tscn` `%Flyout`, `match_screen.gd` `open_flyout()`, `operator_panel.gd` `set_section()` |
| Hand tray OPEN / CLOSED / PEEK by phase (200 ms cross-fade + 160 ms card slide; the board never moves), step header, SPEED x2 | `match_screen.gd` (`set_tray_state`, `_follow_phase`), `hand_area.gd` (grid, read-only PEEK with `NEXT DEPLOY`, 14 px shift toward the board) |
| Killfeed toasts (2 max, 2.5 s, no input, top centre of the board) + persistent tray log | `scripts/fx/killfeed.gd` (`mirror`, `persistent`, `line_cap`, `centered`, `left_aligned`) |
| Objective tile sideways (FP pair, 40 / 64 px mark, range over control word, chips 70x22 / 96x28; `EVEN` replaces `CONTESTED`) | `scripts/ui/objective_tile.gd` |
| Banner badge / number / plate 28/20/22 (phone) and 34/24/26 (desktop), FRONT tab 48x13 / 64x15 | `banner_view.gd` `metrics()`, `lane.gd` |
| Placement enters at the back-row slot (yours); rival still from past the top edge | `lane.gd` `_enter()` |
| Mirror setting | `Settings.mirror_layout`, MENU > `MIRROR LAYOUT: ON/OFF` (`pause_menu.gd`) |
| QA bridge: tray state, flyout, mirror, banner / card size, badge rects and values, toasts, log lines | `scripts/qa/qa_bridge.gd` |

**Decisions the spec left open.**
- **Operator placement:** while the Operator can deploy (Round 1, after a respawn, not yet planned), the OPERATOR badge reads `DEPLOY`, glows and *is* the Operator's handle (tap = select, drag = drag to a column). Otherwise tap opens its flyout, where tapping the panel selects it (Rotate). The tutorial's spotlight follows the badge / flyout.
- **SPEED x2** doubles `Engine.time_scale` while the round's feedback plays (reset when it ends and when the screen closes). The toggle stays on between rounds.
- A one-time toast "Killstreak ready: tap the STREAK badge" the first time a killstreak is ready in Deploy.

**Deviations.** The `HAND · n PEEK` tab is **64 px** tall, not 48 (48 px is 35 pt on the phone, below the 44 pt tap rule the layout tests enforce). UNDO no longer names the play on its face (its tooltip and the toast after undoing do). Supply pips narrow to fit 10 Supply in the tray. On the 224 px desktop tray the killfeed log shortens names to 8-10 characters (the inspector has the full names).

**Not built yet.** Tapping a log line to highlight both cards; the desktop hover peek of a hand card (left of the tray; v1 never had one either); the first match's tutorial tapping each badge once; per-column toast anchoring (the §6 option). The mirror setting is not saved between sessions (Settings has no persistence yet).

**QA.** `tests/test_board_columns.gd`: v2 metrics (phone / 16:9 / desktop / mirror / notch), banner numbers, live columns and tray, `test_tray_open_close_by_phase`, `test_mirror_layout_setting`, `test_strip_badges_flyouts_and_killfeed_toasts`; `test_board_layout.gd` checks the tray grid, the log in the closed tray, and every key control (badges included) at 44 pt+. 378 tests pass with and without `assets/licensed`. Screenshots (public art, WebP): `qa/screenshots/board-v2/`.

---

## Implementation notes (kc-ui3, UI/UX Agent, 2026-11-05)
The head's notes on the private pitch build: "we still need to see our operator card close to hand since we can deploy it. Maybe killstreaks need their icons visible and get highlighted when ready. We'll need a codex view. ... the backing of zones to play to be subtle art of the location." Plus: the game is called **KillingCard** everywhere, and the mulligan shows full cards. Rules unchanged.

| Piece | What | Where |
|---|---|---|
| **Operator card** | First cell of the hand grid, same size as a hand card, `OP` hex. Can deploy: amber glow + `DEPLOY` plate; tap = select, drag = drag to a column (as any card). Placed this Deploy: `PLAN · B`. On the board: dimmed art + `ON BOARD / B · ROW 2` (tap = select to Rotate). Down: `DOWN / NEXT ROUND` (or `NO RESPAWN`), tap = rules. Long-press / right-click = the Operator's rules. The strip's OPERATOR badge is info only now (tap = its flyout, no glow, no drag). | `hand_area.gd` (`set_operator`, `get_operator_card`), `match_screen.gd` `operator_card_entry()`, `match_snapshot.gd` (operator entry: `on_board`, `zone_label`, `row`, `planned_zone`, `respawns`, `banner`) |
| **Killstreak tiles** | Always visible at the top of the tray: icon in a charge ring that fills with the streak, a word under it (`1/3`, `READY`, `USED`...). Ready: amber frame + pulse, and a one-time toast per killstreak ("Recon Drone ready: tap it at the top of your hand"). Tap = use (select its target or queue it), long-press = its rules (threshold, what it does, why it can't be used now). The STREAK flyout still holds the sidearm / lethal / tactical. | `killstreak_row.gd`, `match_screen.gd` (`item_inspected`), `match_controller.gd` `open_item_inspector()` |
| Tray numbers | Phone (wide tray): the 3 tiles share the Supply row, which grows to 64 px (SUPPLY 3/4 over the pips); hand cards **99x124** (was 104x130). Desktop / 16:9 (narrow tray): tiles get their own 64 px row under Supply; desktop cards unchanged (108x136); 16:9 phone 3 columns of 66x83. Hand grid sized for 8 (7 cards + the Operator). | `board_metrics.gd` (`ks`, `supply`, `ks_inline`, `HAND_SLOTS` 8) |
| **Codex** | MENU (CODEX beside RESUME) and Title (CODEX beside TUTORIAL). Filters: ALL / UNITS / TACTICS / FIELDS / KILLSTREAKS, ANY CLASS / AR / SMG / SHOTGUN / SNIPER / LMG, a chassis picker; pitch build: ARTS: ALL shows every licensed alternate art as its own tile (calling-card title, chassis under it). Tap = the match's card inspector. All controls 64 px+ (44 pt on the phone). | `scripts/ui/codex/codex_view.gd` |
| **Zone backing** | Each column shows its location (containers / cranes / offices, the project's own lane art) behind the slots at 34% opacity, darkened. | `lane.gd` (`Backing`, `get_backing()`) |
| Killfeed log | Desktop tray: each line takes two rows (ATTACKER over VICTIM), names keep 14 letters. Phone keeps one row. | `killfeed.gd` / `killfeed_entry.gd` `two_line` |
| Settings save | MIRROR LAYOUT, SPEED x2 and FAST ANIMATIONS are saved to `user://settings.cfg` and restored at start (not in headless tests). | `autoload/settings.gd` |
| **Mulligan** | Each card is the full CardView (art, cost, name, stats, keywords, rules text; licensed art + title in the pitch), at least 0.84x (5 cards fit across an 844x390 phone; more scroll sideways). PUT BACK plate on marked cards. Long-press / right-click = the inspector (does not toggle). | `mulligan_panel.gd` |
| **Name** | KillingCard: page `<title>`, loading screen wordmark, rotate notice, consent ("Help us test KillingCard"), Title wordmark, project description, playtest summary. Internal ids / file names unchanged. Test: `test_the_game_is_called_killingcard`. | `web/shell.html`, `Consent.tscn`, `Title.tscn`, `project.godot` |

**Deviations / open.** Phone hand cards shrink 5% to fit the killstreak tiles. On a phone the full mulligan card's rules line is about 8 pt (name, cost and stats are 11 pt+, as in the inspector's 0.8x floor); the long-press inspector has the full text. The `PLAN · B` Operator card is still tappable (the controller refuses a second placement with its usual reason).

**QA.** `tests/test_ui3.gd` (11 tests: Operator card states and deploy-by-tap, killstreak tiles, codex filters / inspector / MENU / phone sizes, location art, 2-row log, settings save, full-card mulligan, KillingCard naming); layout tests check CardViews by their effective (scaled) name / stats size. 389 tests pass with and without `assets/licensed`. Screenshots (public art, WebP): `qa/screenshots/ui3/`.

---

## Implementation notes (kc-syn-ui, UI/UX Agent, 2026-11-06)
The synergy layer on screen (`../design/synergy-system.md` §9, hooks §11.3, open items §11.4), plus the head's notes A (show the RESULTING stats, buffs coloured, base on inspect) and B (the Operator card is its own, static card), and the kc-ui3 answer (half-height Operator card while it is on the board). Rules unchanged; no file in `scripts/rules` was edited.

| Piece | What | Where |
|---|---|---|
| **Banner synergy** | Keyword pip (outer edge, left of the effect glyphs; its arrow points at the neighbours it uses: Guard ▼, Spotter ▲, Fireteam / Overwatch ◄►; lit while its link is on, grey idle). Trait icon (outer-left after the class pip; a shape per trait: chevrons, mask, gear, hand; lit at tier 2, white ring at tier 3). Copy-level camo band on the outer edge (Recruit plain, Trained Gilded, Veteran Forged, Elite Priceless). Recruits show none of it. | `banner_view.gd`, `synergy_glyphs.gd` |
| **Resulting stats (head A)** | Every banner shows FP after range, effects, auras, links, sets and level; buffed = green number + ▲ marker, lowered = red + ▼ (shape and colour). Cover now (printed + effects + links + sets) is a chip left of the Armor badge. The inspector lists the sum: "FP 5 = 3 base +1 close range +1 Spotter (Marksman, behind)", the keyword (what it uses, link ON with whom / idle), the trait (count, both tier texts, which are ON) and the level. | `stat_breakdown.gd`, `match_snapshot.gd` (`_unit_synergy`), `match_controller.gd` (`synergy_lines`) |
| **Link ticks** | One short glowing tick per active link, in the owner's colour: a vertical bar across the row gap (Guard, Spotter; Guard at 36% of the width, Spotter at 64%), a horizontal bar across the column gutter (Fireteam at 40% of the height, Overwatch at 60%). Drawn from the banners' live positions, so they follow the slide / advance; refreshed from each `SYNERGY_CHANGED` while the round plays (ready for a step-by-step firefight). | `board.gd` (`LinkLayer`, `set_links`, `get_drawn_ticks`) |
| **Placement preview** | While a unit card (or the Operator) is selected, each valid column's ghost shows the card as it would land there (resulting FP / Cover with trend colours, keyword pip lit if its link would be on, trait tier), dashed amber ghost ticks for the links it would make, and a green chip under PLAY HERE: "VANGUARD 2 ON · +1 FP", "COVER +1", "LINKS 1". Computed from `MatchState.preview_synergy` plus a throw-away unit (nothing in the state changes); the test plays the card and checks the board matches. | `match_controller.gd` (`_ghost_for_zone`), `lane.gd` (`SynergyChips`), `stat_breakdown.gd` (`of_ghost`) |
| **Trait rail** | In the icon strip between PREVIEW and DECK: one chip per trait in play, "2/3" (count over the next threshold; just "3" at the top tier), lit / ring by tier, a white notch for the Doctrine trait, a red crack for 2 s when a set switches off. Desktop shows both sides (RIVAL above, YOU below); the phone shows yours (both are in the flyout). Tap = SETS flyout (both sides, every tier text, what the next threshold gives); long-press a chip = that trait (members in play, tiers); elsewhere = the rail's rules. | `trait_rail.gd`, `match_screen.gd`, `board_metrics.gd` (`rail_rect`) |
| **Set callouts** | When a tier switches on during the round: "VANGUARD 2: Vanguard in row 1 get +1 FP" beside the rail for 1.2 s, then it folds into the rail; switched off: "VANGUARD 2 OFF" + crack. One per side at a time. The FX director gives each `SYNERGY_CHANGED` half a popup beat. | `match_screen.gd` (`on_synergy_event`, `show_set_callout`), `feedback_director.gd` |
| **Undead heal** | `UNIT_HEALED` from `trait_undead`: a green "+1" on the unit and an "UNDEAD HEAL" tag (Aid Station heals show the teal +n). | `feedback_director.gd` |
| **Hand cards** | Trained cards carry the trait icon and keyword pip next to the cost hex, the level's camo band under the art, and a dot (trait tint) when playing it this round would switch a set tier on (tooltip names it). | `hand_area.gd` (`_add_synergy_overlay`), `match_snapshot.gd` (`_hand_synergy`) |
| **Operator card (head B)** | Its own frame: brass border on a dark brass fill with rounded dog-tag corners (teal border when selected), pinned first in the tray, no cost hex: a brass plate "1 SUPPLY". Can't pay: red plate, "NEED 1 SUPPLY" status, no glow, and selecting it toasts "Not enough Supply: your Operator costs 1, you have 0." The inspector says it is never drawn or discarded and what placing costs. | `hand_area.gd`, `match_controller.gd` |
| **Mini Operator card** | While the Operator is on the board the card folds to half height (min 64 px = 44 pt on the phone): "ON BOARD", "C · ROW 1", FP and Armor over its dimmed art. The cards under it in the first column move up by the half it frees. Tap = select (Rotate), long-press = rules. | `hand_area.gd` (`_make_operator_mini`, `mini_height`) |
| **Supply Drop** | Every traited option says what it does to the engine ("VANGUARD 3 > 4"; slot 1 marked "ON-TRAIT ·" when it is on the main trait), and a 4th tile **RETIRE · instead of a card** (greyed "AT THE FLOOR" at 15 cards) opens the Retire picker: one tile per design and level, Recruits first, cost and trait, and the twin preview "TWIN TRAINED: Point Man > GILDED (gains Fireteam and Vanguard)" with a plain > Gilded band strip. BACK returns to the cards. | `reward_screen.gd` |
| **Regroup** | After a loss: the same picker as the only reward ("After a loss: retire one card for free"). | `reward_screen.gd` |
| **Doctrine** | After match 1: two emblem tiles (trait icon in a ring), your Trained count of it, both tier texts, "its sets count +1 all run". | `reward_screen.gd` (`_doctrine_tile`) |
| **Promotion** | One tile per design and level: "RECRUIT > TRAINED · GILDED" + what it gains ("Gains Guard and Vanguard.", "+1 Armor (4 > 5).", "+1 FP (3 > 4).") + band now > next. | `reward_screen.gd` |
| **Deck view / Engine panel** | DECK on the reward screens and the run map: trait counters (icon, count, DOCTRINE / MAIN tags), Trained keyword counts, Recruits waiting to be trained, Doctrine, main trait, deck size over the floor; then one row per design with its copies by level (camo swatches) and its trait / keyword glyphs (dimmed while only Recruits). Long-press a row = the card's rules. | `scripts/ui/run/engine_panel.gd` |
| **Honor Roll** | After-Action page: every retired card (band, "after M2", "twin trained"), last 5 + "+ n more". | `after_action.gd` |
| `synergy_offers` | **On** in `data/run_config.tres` (the only data change). The classic offer-schedule tests pin it off on a copy; a new test checks the shipped schedule (Doctrine after M1, Promotion after M2 / M4, Regroup after a loss). | `run_config.tres`, `tests/test_run_flow.gd` |
| §11.4 hooks | Quick match: `player.deck_levels = config.starter_levels()` (plain Recruits); the tutorial drill plays its scripted deck at the starter's level (from `starter_levels()`); the match controller calls `PitchDecks.apply_setup(setup)` (pitch decks Trained). | `match_controller.gd`, `tutorial_match_controller.gd` |
| Inspector fix | The rules, keyword and status lines scroll inside the text panel when they would make it taller than the room under the banner (the Protector was 1 px too tall; synergy lines add more). Title, type and CLOSE always show. The layout is fixed, the test is unchanged. | `card_inspector.gd` |
| QA | `?qa=1` only: kcQa reports `match.syn` (rail chips, tick / ghost tick counts, column chips, callouts), `operator_card.mini / short`, and `reward` (kind, on_trait, Retire tile / picker, list tiles, deck view). QA-only commands through `window.kcQaCmd`: `win` / `lose` (end the run match), `stage_synergy` (Trained cards on the board and in hand). | `qa_bridge.gd` |

**Deviations / open.** The trait rail on the phone is 62x49 px (45x35 pt): the strip has no more height between PREVIEW and DECK, so it is a glanceable read-out with a tap target below 44 pt (the SETS flyout and the chips' long-press have it all). The font has no arrow glyphs, so offers write "3 > 4" (the band strips draw a real arrow). With the mini Operator card the first column of the hand sits half a card higher than the others (the freed half is used, not left empty). The mini card on licensed (bright) art is readable but busier than on the public art.

**QA.** `tests/test_syn_ui.gd` (5 tests: links / rail / resulting stats / inspector breakdown / callouts on phone and desktop; the placement preview matches the board after Reveal; the Operator card's plate, NEED SUPPLY and mini states; the quick match on the Recruit starter; the Undead heal feedback); `test_run_screens` walks Supply Drop + Retire picker, Doctrine, Promotion and Regroup on both screens; `test_run_flow` checks the shipped schedule. 430 tests pass with and without `assets/licensed`. Browser smoke (`?qa=1&seed=101`, 844x390 and 1440x900, public and pitch builds): links, rail, a set callout, Supply Drop with Retire, Doctrine, Promotion, deck view, Honor Roll, Regroup, the Operator mini card; no console errors. Screenshots (public art, WebP): `qa/screenshots/syn-ui/`.

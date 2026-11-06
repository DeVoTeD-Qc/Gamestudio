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
| Killstreak buttons (RECON, MORTAR, ATTACK; P-12 / FRAG / FLASH removed in kc-loadout-cut) | **STREAK badge** (strip 4): streak count. **Glows amber when a killstreak is ready**, with a one-time callout. | Tap: flyout with the killstreak tiles (3 since kc-loadout-cut) at 61 px each (`v2-phone-killstreak-flyout.png`). Tapping a ready tile arms it and closes the flyout. Long-press a tile: its rules. |
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

---

## Implementation notes (kc-ui4, UI/UX Agent, 2026-11-06)
The head: "the cards in hand and on the codex should be closer to their form on the board ... more info by hover / long touch / right click. ... see all unique cards in codex and then select them to see alternate art and equip the alternate art I want ... if I get that card it uses the art I selected ... see the starting deck and maybe choose a starting operator/gun ... attack and health icons at the same place for both my cards and opponent cards." Lead additions: the card name is always the chassis, the art's title is a SUBNAME under it; room for alternate arts that give traits (coming); a GLOSSARY. No file in `scripts/rules`, `scripts/ai` or `data` was edited.

| Piece | What | Where |
|---|---|---|
| **Card anatomy (the head), every form, both sides** | **Cost top-left** (hex), then the class pip and Elite star; **trait top-right** (the Operator: dog tag); the **name top-centre**; **abilities bottom-left** (Protector, up to 2 keyword glyphs or the effect bolt, the neighbor keyword pip); **FP and Armor side by side bottom-right, each a plate with its number inside** (FP: teal circle / red diamond; Armor: shield, amber when damaged; green up / red down on the number), Cover chip left of them; the **subname** in the middle band when the card is tall enough, else bottom-centre. Camo / level band on the top edge. Side identity: spine pattern, FP plate shape, colours, mirrored rival art. One rule (`BannerView.anatomy()`) for board banners (now with cost and name), ghosts, hover zoom, hand, codex, starter list and the inspector banner; the full CardView (inspector / mulligan) moves FP + Armor to the bottom-right with the number inside too. Icons come through `IconSheet.get_icon()`, which asks `UiKit` first (one kit id per concept); the stat plates are drawn in code until the artist's number-plate art lands. | `banner_view.gd` (`anatomy()`, `ability_kinds()`, `stat_rects()`, `anatomy_now()`), `card_view.gd`, `match_snapshot.gd` (cost on board entries) |
| **Banner hand cards** | Each hand card IS the board banner (BannerCard: BannerView + cost hex top-left + NameLabel / SubLabel), with the board's badge sizes (`metric_h` = the board's banner height). Grid: phone 2 columns of **177x73**, desktop 1 column of **224x64**, 16:9 phone 2 columns of 103x72 (name in the middle band). Rules text and the breakdown: long-press / right-click (tooltip on hover). The Operator keeps its brass card: its "1 SUPPLY" plate takes the cost slot, its status (DEPLOY / PLAN · B) the top centre (hidden when it does not fit; the tooltip and the red plate say it), and the weapon's name the subname slot. | `banner_card.gd`, `hand_area.gd`, `board_metrics.gd` (`_hand_grid`, CARD_MIN_H 64) |
| **Naming** | The name is always the chassis ("Rifleman"); the art's name is the subname ("NIGHT OPS", or a licensed calling-card title) under it, on board banners, hand, codex, mulligan (CardView type line), inspector (type line), hover zoom. | `match_snapshot.gd` (`subname`), `BannerArtDB.subname()`, `card_view.gd`, `match_controller.gd`, `board.gd` |
| **Codex: unique cards + ART panel** | One tile per card (the board banner). Tap = ART panel: big preview, every alternate art (licensed pool in the pitch; our variants STANDARD / NIGHT OPS / SANDSTORM / FLIPSIDE in the public build), a trait slot per art (dashed until arts carry traits; the manifest's `trait` column fills it, and EQUIP then reads "EQUIP · GIVES UNDEAD"), EQUIP / EQUIPPED, USE VARIETY, RULES. Long-press / right-click a tile = the inspector. EQUIPPED: amber frame + "· EQUIPPED" after the subname. | `codex/codex_view.gd`, `BannerArtDB.alt_arts() / _variant() / art_trait()` |
| **Equip in gameplay** | `Settings.equipped_arts` (chassis -> art id, saved in `user://settings.cfg`). The match gives every copy YOU play of that chassis the equipped art (overrides the per-copy variety; un-equipped cards keep it); the rival is unchanged. | `autoload/settings.gd`, `match_controller.gd` `_assign_copy_arts()` |
| **Starting squad** | Loadout opens on STARTING SQUAD: the Operators you can start with (every Primary weapon; brass banner, mastery card in the pitch, class / FP / Armor / what it does, SELECTED), and the plain Recruit starter grouped by card with x-counts. Tap = pick, long-press = rules. NEXT: KILLSTREAKS goes on; OPERATOR & DECK on the kit panel reopens it. Also from the Codex (STARTER; sets the default only). The pick is the run's Primary (`RunProgress.set_primary`, loadout phase only, saved with the run) and the default for the next run and the quick match (`Settings.operator_primary`). Default = the config's starter Primary. The AI side is unchanged. | `run/starter_panel.gd`, `run/loadout_screen.gd`, `scripts/run/run_progress.gd` (`operator_options`, `set_primary`, index), `autoload/run_state.gd` |
| **Glossary** | Codex GLOSSARY, MENU > GLOSSARY, and a "?" on every keyword line of the inspector (opens at that entry). Categories ALL / KEYWORDS / SYNERGY / STATS & BOARD + search. Every card keyword (from `CardInfo.KEYWORD_RULES`, Pierce included), Field / Overrun, the 4 neighbor keywords with a mini neighbour diagram, the 4 traits with both tier texts, the 4 levels with their bands, Doctrine, link ticks, set callouts, the green / red stat colours, FP / Armor / Cover / Supply, range, objective, control, Operator, killstreak, incoming. Texts come only from `CardInfo.KEYWORD_RULES`, `CardInfo.GLOSSARY_EXTRA` (new) and `SynergyRules`. | `codex/glossary.gd`, `card_info.gd` (`GLOSSARY_EXTRA`), `card_inspector.gd`, `pause_menu.gd` |
| QA | `kcQa.codex_arts` (art tiles, equipped, selected), `kcQa.starter` (Operator tiles, groups, picked), `kcQa.glossary`. | `qa_bridge.gd` |

**Deviations / open.** The full CardView keeps its keyword row and rules text in the middle (it is the detail view) and has no trait slot (the inspector's banner above it shows the trait). The public build's alternate arts are regrades of the chassis' placeholder (night / sand / mirrored), clearly placeholders. Board banners now also print the cost and the name (the same as the hand card). Hand cards are wide banners, so the licensed 4:1 art is cropped less than in the old 2:3 window but more than on the board (about 2.4:1 on the phone). The tray's mini Operator card keeps the card's height (banner cards are short already).

**QA.** `tests/test_ui4.gd` (6 tests: identical FP / Armor rects for both sides on 4 banner sizes and the live board, hand banner badges and chassis name; codex ART panel -> EQUIP -> saved and reloaded -> every Rifleman copy in a match wears it, the rival and other cards don't; the starter panel groups the deck, the Operator pick reaches the run, the save, the match and the next run / quick match, the rival unchanged, no change after the run began; the codex STARTER button; every keyword / neighbor keyword / trait in the data has a glossary entry and icon; the glossary from MENU and the inspector "?"). Updated: board metrics, hand art 4:1, codex tap = ART panel, loadout opens on the starter panel, the tutorial's chip rect for a grid. Browser smoke (`?qa=1&seed=101`, 844x390 and 1440x900, public and pitch). Screenshots (public art, WebP): `qa/screenshots/ui4/`.

---

## Implementation notes (kc-fight-ui, UI/UX Agent, 2026-11-06)
The step-by-step firefight is described in `../design/firefight-order.md` §10.4. Layout changes here:

| Piece | What | Where |
|---|---|---|
| **Phone strip: RIVAL folds into SCORE** (head's kc-syn-ui answer) | On the phone the SCORE badge has three lines: `R1`, `0-0` and the rival's hand (a small red card glyph + count). Its flyout is "SCORE · RIVAL HAND" (score bar + the rival intel). PREVIEW moves up into RIVAL's slot, so the trait rail gets a whole badge slot more: 62x118 px (45x85 pt, was 62x49). Desktop keeps the RIVAL badge. | `match_screen.gd` (`rival_in_score`, `_layout_regions`, `_set_badges`, `open_flyout`), `strip_badge.gd` (inline glyph) |
| **Tray during the round** | Under the header: the A > B > C order strip (34 px), then the shot caption (17 px, wraps to 2-5 lines), then the killfeed log. | `match_screen.gd`, `scripts/fx/order_strip.gd` |
| **Deploy glow** (head's kc-syn-ui answer) | At the start of each Deploy, every hand card that would switch a trait bonus on this round glows twice in its trait's colour (1.6 s, white inner line; reduced motion: one steady frame). | `scripts/fx/hand_glow_fx.gd`, `match_screen.gd` (`glow_set_cards`) |
| **Pierce glyph** | An arrow through a chevron, pointing down the enemy column, drawn (no sheet icon): banner effect slot, Codex glossary. | `synergy_glyphs.gd` (`draw_pierce_icon`), `banner_view.gd`, `codex/glossary.gd`, `card_info.gd` |

---

## Implementation notes (kc-trait-ui, UI/UX Agent, 2026-11-06)
Art-traits UI (`../design/art-traits.md` §8, §11.2) with the head's 2026-11-06 change of direction folded in: (A) a new card anatomy, (B) in a run every copy keeps the art it was found with (no art choice, no Codex EQUIP), (C) Re-issue and the trait choice at training stay, but hand out a random art of the chosen trait. No file in `scripts/rules`, `scripts/ai` or `data` was edited; `scripts/run/run_progress.gd` got the small B/C switch (below).

| Piece | What | Where |
|---|---|---|
| **Card anatomy v3 (head)** | Every banner form, both sides, one rule (`BannerView.anatomy()`): **top-left** cost + the card NAME next to it (Elite star between), **top-right** abilities / keywords (right-aligned from the corner), **bottom-left** trait (Operator: dog tag) + weapon-type pip, **bottom-right** FP + Armor number plates (Cover chip left). The art's **subname is not on cards** any more (board, hand, Codex tiles, mulligan): it is in the inspector / DETAILS / the Codex ART panel's info line. Long names shrink to 13 px, then end in "…". The Operator card keeps its status line. | `banner_view.gd`, `banner_card.gd`, `match_controller.gd` (mulligan) |
| **Per-copy art + trait in matches** | `_assign_copy_arts` keeps a run's copies' own arts (`player_setup().deck_arts`); every other side (rival squads, quick match, tutorial) wears an art **of each copy's trait** (`SideSetup.trait_of`; licensed pool of that trait with variety, else the default / our option placeholder). The inspector's trait line uses the copy's `chosen_trait`: "From the art: Mastery family. Can be: Spec Ops · Heavy." Banner entries derive the trait from the art (`BannerCard.entry_for_card(card, art, level, chosen)`). | `match_controller.gd`, `banner_card.gd` |
| **Random copy arts (B, C)** | `RunProgress.random_copy_arts` (default on): starter copies, Supply Drop cards, training into another trait and Re-issue each draw a random art of the copy's trait (`_random_art`, RNG stream `copy_art`, `art_draws` saved); `set_copy_art` refuses another art; `set_equipped_arts` is ignored. `train_choices` rows say `random`. Off = the kc-art-traits behaviour (tools/tests). | `scripts/run/run_progress.gd`, `autoload/run_state.gd` |
| **Supply Drop** | Each card is a concrete copy: its own art on the card, one head line `[trait icon] ON-TRAIT · HEAVY 3 > 4` (": bonus ON" when it switches a set on). DETAILS (more-info) names the art and "Trait: Heavy, from the art "…" (Mastery family). Can be: …". | `run/reward_screen.gd` |
| **Re-issue** | A tile under RETIRE on the Supply Drop, a RE-ISSUE header button on Regroup. Step 1: Trained copies with another option ("MARKSMAN · SPEC OPS", "Can become: Heavy"). Step 2: NOW (the copy's banner) + one tile per other trait ("RE-ISSUE AS HEAVY", "Heavy 2 > 3: bonus ON", "Spec Ops 3 > 2", "You'll get a random Heavy art."). Tap commits (`RunState.reissue_card`). BACK steps back. | `run/reward_screen.gd` |
| **TRAIN AS** | Promotion of a Recruit with options, and a twin training (Retire a Recruit with a twin): one tile per option from `run.train_choices(i)`: trait plate + name, "Vanguard 0 > 1 (bonus at 2)", both tier texts, PRE-SELECTED (its art), "You'll get a random Undead art" / "Keeps its art". Tap commits (`choose_offer(i, trait)` / `retire_card(i, twin_trait)`). | `run/reward_screen.gd` |
| **Deck view** | Per design row: the copies' traits in words ("Spec Ops 1 · trains as Heavy 2", "plain") and one trait plate per trait (lit = Trained). No art picker (head B). | `run/engine_panel.gd` |
| **Codex = viewer** | No EQUIP / USE VARIETY. ART panel: arts grouped by the trait they give (default option first), each tile's bottom-left trait slot filled from `ArtTraits.trait_of` (dashed = no trait), "GIVES HEAVY" / "NO TRAIT" / "PRINTED TRAIT" chip, "Can be: Spec Ops (5) · Heavy (2)", FOUND marks (`Settings.found_arts`, filled by RunState from every run copy's art; unfound tiles dimmed, "NOT FOUND YET"). | `codex/codex_view.gd`, `autoload/settings.gd`, `autoload/run_state.gd` |
| **Public option placeholders** | `<chassis>~honors|operators|mastery|horde` render in `BannerArtDB._option_variant`: the chassis art with the family tint (`ArtTraits.OPTION_VARIANTS`), a family treatment across the band (gold rules / black tape / camo blotches / drips) and the family emblem roundel (`option_emblem`: laurel, tape, camo, rot). `alt_arts()` = `ArtTraits.arts_for(card)`, `subname()` and `art_trait()` know them. | `art/banner_art_db.gd` |
| QA | `tests/test_trait_ui.gd` (4), `test_run_screens.gd::test_trait_ui_reward_flows` (offers, Re-issue, TRAIN AS, twin, deck view on phone and desktop), `test_ui4.gd` (anatomy v3, Codex viewer); updated `test_art_traits.gd` (no swaps / no EQUIP in runs). `kcQa.reward` adds traits / arts / reissue / train_pick / pick_tiles; `kcQa.codex_arts` adds trait / found / gives. Screenshots (public, WebP): `qa/screenshots/trait-ui/`. | `tests/`, `qa_bridge.gd` |

**Deviations / open.** The full CardView (inspector / mulligan / Supply Drop face) keeps its own layout (cost + name top, FP + Armor bottom-right) and has no trait slot; the Supply Drop puts the trait icon in the head line over it. `Settings.equipped_arts` and `equip_art()` stay for old saves but nothing reads them. The starter's copies now wear random arts of their default trait (variety; same seed = same arts).

---

## Implementation notes (kc-onboard-ui, UI/UX Agent, 2026-11-06)
The "simple first run" on screen (`../design/onboarding-progression.md` §2.2, §3, §5, §8 steps 5–6; hooks from kc-onboard-impl, commit 6d17ea1), plus the head's answers W1 (board banners: cost, no name), Z1 (no trait change after a card is found), Z2 (one standard starter art), Z3 (Codex keeps NOT FOUND YET), the tutorial switch, and initiative on screen. No file in `scripts/rules`, `scripts/run`, `scripts/ai`, `data/cards` or `data/run_config.tres` was edited; no rules hook was added.

| Piece | What | Where |
|---|---|---|
| **Standard Issue look** | Every Standard Issue card (and the starter's Ammo Resupply in its SI art): a plain matte grey-green frame (`#5E6B5A`, low contrast, three flat screws, no camo band, no foil), the **serial plate** `SI-01`…`SI-04` in the top-right abilities slot (red plate on an enemy Standard Issue squad), an empty trait socket bottom-left. The name of a Standard Issue card (hand, Codex, Muster out, deck view, CardView) is set in **Stardos Stencil Bold** (OFL, `assets/fonts/StardosStencil-Bold.ttf` + `OFL-StardosStencil.txt`), capitals, low contrast; the stencil font is used for nothing else (name + serial plate only). It has no "…" glyph, so cut names end in ".". | `scripts/ui/standard_issue_look.gd` (`StandardIssueLook`: `dress()`, `draw_frame`, `draw_serial_plate`, `draw_empty_socket`), `banner_view.gd`, `banner_card.gd`, `card_view.gd`, `hand_area.gd`, `match_snapshot.gd` |
| **Recruit ladder on cards** | A Recruit calling card keeps its trait; its keywords are **locked**: greyed sockets with a padlock (`frm_socket_locked` + `ico_ui_lock`, else drawn) top-right, at most 2 (the neighbor keyword last), and an **R level badge** bottom-left (R / T / V / E plate rimmed in the level's band colour). Supply Drop tiles of Recruits replace the rules line with the greyed "[padlock] RECRUIT · TRAINS: FIRST SHOT · GUARD" line; the CardView's keyword row is greyed behind a padlock. Off the board, a Trained+ copy gets its badge once Promotion is met; on the board only Recruits get one (the camo band shows the rest). Inspector: "Level: Recruit … locked until it trains (Promotion). Trains: …"; the Standard Issue inspector line says it never trains. | `standard_issue_look.gd`, `banner_view.gd` (`anatomy()` keys `level`, abilities `[&"locked", name]` / `[&"serial", text]`), `run/reward_screen.gd` (`_trains_line`, `_level_badge`), `card_view.gd`, `match_controller.gd` (`synergy_lines`) |
| **W1** | Board banners (slots, landing ghost, fade-out copies) draw the cost but **no name**; the hover zoom, hand cards, Codex and the inspector keep cost + name. | `unit_slot.gd`, `lane.gd` |
| **Pick 2 of 4** | Title "SUPPLY DROP · PICK 2 OF 4"; a taken card leaves the row, the subtitle lists "Taken: …", the drop stays until both picks are used (or SKIP). **Retire moved to a RETIRE header button** ("under More", §5.2) and shows only once Retire is met (the first drop from M2), so **4 cards fit the phone at 0.8x** (the gap tightens to ≥ 6 px when needed): 4 × 228 + 3 × 16 = 960 px of the ~1038 px safe width. `test_run_screens.gd` now runs on the **shipped config** (no more `tests/legacy_starter.gd` there). | `run/reward_screen.gd` |
| **Salvage** | After a loss: "SALVAGE", "After a loss you still salvage a card. Tap a card…", the same card tiles (2 cards, pick 1); Muster out follows from M2. | `run/reward_screen.gd` |
| **Muster out** | One tile per Standard Issue copy (its SI banner + serial, most expensive first); the pre-selection (`muster_out_options().preselected`) is marked **GOING HOME**, the rest **STAYS**; tap toggles, never past the count ("Only 3 can go home this time: tap a marked card first to keep it."); the subtitle shows "up to 3 of your 18 go home, deck 23 > 20 (floor 15)". **SEND n HOME** commits (`RunState.muster_out(indices)`), **KEEP ALL** skips. Long-press a tile: the card, its serial, whether it goes home. | `run/reward_screen.gd` (`_build_muster_out`, `toggle_muster`, `confirm_muster_out`) |
| **Z1 removals** | Gone: the TRAIN AS picker, the Re-issue tile / header button / flow, the twin-training path and preview, the qa_bridge `reissue*` / `train_pick` / `pick_tiles` fields, the deck view's "trains as …" words (now "Heavy 1 (Recruit)"). Promotion tiles say "Unlocks First Shot and Guard." and train at once. | `run/reward_screen.gd`, `run/engine_panel.gd`, `scripts/qa/qa_bridge.gd` |
| **Progressive reveal** | `RevealGate.shown(flag, now)` = `RevealFlags.visible(flag, Settings.met_flags, now)` while `RevealGate.active` (run screens, run matches, the tutorial); the quick match and the pitch build show everything. Hidden until met (or in use now on either side): the **trait rail**, **link ticks** and the link part of the placement preview, the **camo bands** and Trained level badges (Promotion), the **Engine** part of the deck view (first Promotion; before it the deck view is the card list plus "Standard Issue: 18 of 20 cards"), **RETIRE** (first drop from M2). The match controller feeds `RunState.note_systems()` at every Deploy with `RevealFlags.match_triggers()` plus `lethal` / `tactical` (first time ready) and `killstreaks` (one earned). | `scripts/ui/reveal_gate.gd`, `match_snapshot.gd` (`reveal_info`), `match_screen.gd`, `match_controller.gd` (`note_board_systems`, `_ghost_for_zone`), `run/run_screen.gd`, `run/engine_panel.gd`, `standard_issue_look.gd` |
| **"New: X" explainers** | A half-screen card (`pnl_new_card` / `pnl_new_inset`, else drawn): the system's icon, "NEW: MUSTER OUT", one sentence (`RevealFlags.text_of`; keyword tips use the card's own rules line), a mini example (SI banner vs a calling card with "2/3", locked → lit keyword, SI-04 → HOME, 4 cards with 2 picked, plain → Gilded band…), **GOT IT** (64 px; a tap outside also counts) → `RunState.ack_explainer`. At most one per screen: one per reward offer (relevant = `run_triggers`), one per Deploy on the board (relevant = this board's triggers; not in the tutorial, which coaches itself). Long-press / right-click: what the card is. **MENU > RESET TIPS** (beside MIRROR LAYOUT) calls `Settings.reset_tips()`. `NewCard.auto_show` is off in headless runs so screen tests tap through; `test_onboard_ui` switches it on. | `scripts/ui/new_card.gd`, `run/reward_screen.gd`, `match_screen.gd`, `pause_menu.gd` |
| **Initiative** | Who goes first this round and why, always visible: a **flag** (holder's colour; the rival's has a hazard notch) leads the SCORE badge's round line on every layout, and an **initiative chip** (1ST / YOU or RIVAL / BEHIND or TIE; one badge slot, 62x64 phone) sits above the trait rail. On the phone the slot holds the chip until a trait is in play, then the rail (the head's kc-fight-ui answer keeps the rail a full badge slot); desktop shows both. Tap or long-press / right-click the chip: "Initiative · round 2 · you go first", the reason ("You're behind 2-4: the side behind on score goes first." / "Tied 0-0: ties go to you.") and what it does (arrivals, effects and each beat's shots first). SCORE's inspector repeats it. Read-only: during Deploy `hooks.initiative_side(state)` (the side the rules will pick at Reveal), after Reveal `state.initiative`; the tie words follow `ModeRules.tiebreak` when it exists (read with `get()`, so a tuning change can't break the UI). The rule is untouched. | `scripts/ui/initiative_chip.gd`, `match_snapshot.gd` (`initiative_info`, `TIE_RULE_WORDS`), `match_screen.gd`, `strip_badge.gd` (flag glyph), `match_controller.gd` (inspector `&"initiative"`) |
| **Tutorial (head approved)** | The drill deck and TrainingBot_01 are Standard Issue: player Grunt / Trooper / Sergeant (+ Armored Trooper, Ammo Resupply), TrainingBot 8 Grunts, 3 Troopers, 2 Sergeants, 2 Armored Troopers; scripted enemy plays mapped (R2 a Trooper at Right). Step 4 "Tap Grunt, then tap Left", steps 8–10 teach the beat order with `si_sergeant` ("Sergeant hits for 3 … Front cards trade shots; when one falls, the card behind steps up."). First Shot is no longer taught there (its keyword tip does it). Same outcomes: streak 1 in R1, Recon Drone in R2, the drill is won. | `data/tutorial/tutorial_script.tres`, `data/squads/squad_tutorial.tres`, `tests/test_tutorial.gd` |
| **Kit slots** | `UiKit.piece(id)` / `draw_piece()` look up `frm_standard_issue`, `frm_serial_plate`, `frm_socket_empty`, `frm_socket_locked`, `ico_ui_lock`, `pnl_new_card`, `pnl_new_inset` (9-slice margins from the prompt pack) in `assets/ui/kit/{frames,panels,plates,icons,arts}/` and `assets/sprites/banners/`; `kc_b_si_<card>` replaces the placeholder of a Standard Issue art (`BannerArtDB._apply_si_art`). Every slot has a code-drawn fallback today. | `ui_kit.gd`, `art/banner_art_db.gd` |

**Inspectable (studio rule).** Every new element: reward tiles (card → DETAILS view; Muster out, Retire, Promotion tiles → the card; Doctrine → the trait) and the header buttons (SKIP / DECK / RETIRE / SEND HOME) open the inspector on long-press / right-click; the initiative chip and SCORE flag; the New card; level badges and the Trains line carry tooltips and are in the card inspector; deck-view rows (SI rows with the serial plate) long-press to their rules.

**Deviations / open.** On the phone the initiative chip and the trait rail share one slot (SCORE's flag carries initiative while the rail is up). The New card is modal over its screen, but forgiving: a tap anywhere outside it counts as GOT IT, so it never costs more than one tap. `NewCard.auto_show` is false in headless runs. Hand cards don't show the "Trains:" words (no room on a 177x73 banner); the locked sockets + R badge are the cue and the long-press inspector has the words.

**QA.** `tests/test_onboard_ui.gd` (8 tests: SI frame / serial / stencil name on banner, hand and CardView; Recruit locked keywords, Trains line, level badge, bands waiting for Promotion; W1 on the live board with SI hand cards; the initiative chip, SCORE flag, behind / tie reasons and the right-click inspector; reveal hiding the rail / Engine panel; the New card once + GOT IT + RESET TIPS; tutorial / TrainingBot on Standard Issue; kit fallbacks). `tests/test_run_screens.gd` re-pointed at the shipped config (M1 Recruit drop, M2 pick 2 of 4 with RETIRE, Muster out toggle + SEND, M3 Salvage + Muster out, Promotion "Unlocks", all at 844x390 with notch insets and 1280x720). Updated: `test_tutorial.gd` (SI decks), `test_fight_ui.gd` (the phone slot holds the chip or the rail), `test_ui4.gd` (SI names are capitals). **527 tests pass** (was 519). Screenshots (public art, 844x390, WebP): `qa/screenshots/onboard-ui/` (M1 drop with and without "New: Calling cards", M2 pick 2 of 4, Muster out, the board with the initiative chip); tool `tests/tools/shot_onboard.gd` (xvfb-run, opengl3; licensed art off).

---

## Implementation notes (kc-hand-dim, UI/UX Agent, 2026-11-06)
The head: "When we see art in card hand, we need to dim down the image so that we can better read all icons and the card name."

| Piece | What | Where |
|---|---|---|
| **Readability scrim** | `BannerView.readability`: the art is darkened 22% (`ART_DIM`) and two black gradients sit under the icon rows: the top row (cost, name, abilities / serial plate) solid at 78% over the first 45% of a 52%-high band, then fading out; the bottom row (trait, weapon pip, level badge, FP / Armor plates) solid at 82% over a 58%-high band, fading the same way. The middle of the art stays bright, so the image still reads. | `banner_view.gd` (`_draw_readability_scrim`, `get_art_modulate`) |
| Where | **On:** hand cards (including the Operator card), Codex tiles, the starter list, Muster out tiles (everything built by `BannerCard.build`), board banners, the landing ghost and fade-out copies: the same look everywhere. **Off (full-strength art):** the inspector's big banner, the board's hover zoom, the Codex ART panel preview. | `banner_card.gd`, `unit_slot.gd`, `lane.gd`, `codex/codex_view.gd` |
| States | Hand art is 0.78 when playable and 0.47 when you can't afford it (and that chip still fades to 55%). The Operator card is the same, with 0.35 when it is on the board or down. Greyed / locked sockets and the R badge are unchanged. Standard Issue names are a little lighter (`#DDE3D3`) so the stencil reads on the scrim. | `hand_area.gd`, `standard_issue_look.gd` |

**QA.** `test_onboard_ui.gd::test_hand_and_board_art_dimmed_inspector_full_strength` checks: hand art about 20% darker; unplayable cards darker still; board banners use the same treatment; the hover zoom and the inspector are at full strength. 529 tests pass. Before / after (public art, 844x390, plus 2x crops of the tray and the board) are in `qa/screenshots/hand-dim/`. The tool is `tests/tools/shot_hand.gd` (run it with xvfb-run and opengl3; licensed art is off).

## Implementation notes (kc-cards-impl, UI/UX Agent, 2026-11-06)
The head: "Let's implement my pick with latest version updated, directly in the game." The picks are on `documentation/ux/card-design-options.html`: **C1+** on the board, **Y2+** (with the **T1** Tactic frame) everywhere else, **H1** hand with the **O2** Operator card.

| Piece | What | Where |
|---|---|---|
| **Shared drawing** | `CardLook`: FP reticle ring (teal yours / red the rival's, green number when buffed), Armor ballistic plate (grey on both sides, amber when damaged, the number left), trait chip (45% faint, lit with a glow while its set is on, white ring under a rail highlight), level coin (R grey, T / V / E brass), weapon pill, cost hex (red when you can't pay), damage crack + bottom edge, the new Pick glyph, and the one title style (`title_label`: Barlow Condensed Bold 16 px, UPPERCASE, `#F2F5F7`). Barlow Condensed Bold and its OFL licence are in `assets/fonts/`. | `scripts/ui/card_look.gd` |
| **C1+ board card** | Full art, never dimmed or cropped (kc-hand-dim's scrim and back-row dim retired; `readability` / `ART_DIM` kept as no-ops). At rest: abilities top-right (21 px at k = 1, with Recruit padlocks), FP reticle 26 + Armor plate 25 bottom-right, traits 20 bottom-left. Peek (desktop hover, touch hold while the finger is down; the hover zoom; hand cards; Settings): cost hex 20 then level coin 17 then weapon pill 18, top-left. Damaged: amber bottom edge + corner crack. No spine, no camo / level band, no serial plate, no name on the board. Sizes scale with k = banner height / 57. Kept: PLAN tag, frontline keyline, ghost, target reticle, INCOMING, Operator / Elite keylines, the Standard Issue frame. | `banner_view.gd` (`anatomy`, `is_peeking`, `peek`, `full_info`, `show_all`, `syn_focus`), `lane.gd` (`set_peek`), `board.gd` |
| **Setting** | MENU > `ALL CARD INFO: ON/OFF` (beside FAST ANIMATIONS) = Settings > Cards > "Always show all card info" (`Settings.show_all_card_info`, saved; mirrored into `BannerView.show_all`). | `autoload/settings.gd`, `pause_menu.gd` |
| **Rail highlight** | Hover a SETS chip (or keyboard focus, arrows to step, Esc to clear), or tap it to pin it (tap again to unpin; a tap away from the chips still opens the flyout): every card shows its trait at full, the matching cards glow in the trait colour, the rest dim to 45%. | `trait_rail.gd` (`focus_changed`, `pin`), `match_screen.gd`, `board.gd` / `lane.gd` (`set_syn_focus`) |
| **X1 hand card** | The C1+ banner at 4:1 with everything shown + a 26 px name plate in the title style. `BoardMetrics.x1_size`: phone 2 columns of 177x70 (8 fit), desktop 1 column of 144x62 (7 fit), at least 64 px tall on phones (44 pt on the SE). | `banner_card.gd`, `board_metrics.gd` (`_hand_grid`) |
| **H1** | Tap a card: it lifts 6 px, its Y2+ card docks over the top of the tray with CANCEL (and "TAP A PLAY HERE SLOT"), and each legal landing slot shows the ghost with **PLAY HERE · A/B/C**. Tap a slot to place (drag still works). Cancel: the card again, the docked card itself, CANCEL, or the empty board (`Board.empty_tapped`). Long press = the inspector (also on the docked card). | `match_screen.gd` (`show_card_dock`), `match_controller.gd` (`card_view_for`, `_dock_view`), `lane.gd` (`get_play_here`), `hand_area.gd` |
| **O2 Operator** | Bottom-left of the tray in every state; UNDO (a curved-arrow icon) stacked over READY on the right (each 64 / 72 px tall). The card: art on top, the cost in the standard hex (red = need supply), OPERATOR tag, abilities, FP / Armor, a state chip (DEPLOY / PLAN · B / ON BOARD · B1 / DOWN / NEED n SUPPLY), the name and its ability line. Hidden while the tray PEEKs (the tab and SPEED take the row). The old half-height mini card is gone. | `hand_area.gd` (`_make_operator_card`, `set_grid_rect`), `board_metrics.gd` (`op_card`, `undo`, `ready`) |
| **Y2+ / T1** | `CardView` is now the Y2+ card, laid out at its own width (`set_card_width`, `height_for` = (W - 8) / 4 + 155), never scaled: title bar (cost + name), 4:1 art with nothing over it, type line (OPERATOR / STANDARD ISSUE / TACTIC / FIELD / STREAK tag, weapon, level coin), text box (keyword icon + bold name + short rule, a Recruit's greyed "Trains: ...", the effect text; a text that only repeats the keywords is dropped), stats bar (traits left, FP / Armor right). Tactics: the T1 orders frame (khaki paper, 18 px chevron-cut top-right corner), no stats bar, a bigger text box. `not_found` veils the art with NOT FOUND YET; `count` shows "x5". Used by the mulligan (172..220 px), Supply Drop / Salvage (172..240), Muster out (172), the starter / deck list and the Operator pick (172 / 196), the Codex grid and its art tiles (172 / 196, NOT FOUND YET on arts not found), the inspector (220..330) and the hand dock (up to 250). | `card_view.gd`, `CardView.tscn`, `mulligan_panel.gd`, `run/reward_screen.gd`, `run/starter_panel.gd`, `codex/codex_view.gd`, `card_inspector.gd` |
| **Titles** | The stencil font is retired from titles (Standard Issue names, the Retire list, the deck view rows): one title style everywhere. | `reward_screen.gd`, `engine_panel.gd`, `banner_card.gd` |
| **Pick icon** | A shield with a down arrow ("the lowest Armor"), never a crosshair. `IconSheet.get_icon(&"kw_pick")` returns the UI kit's `kw_pick_v2` when the artist ships it, else the built-in glyph; the glossary, inspector, cards and the board all read it from there. | `icon_sheet.gd`, `card_look.gd` |
| **Glossary / New:** | New entries: Card at rest / peek, Damaged, Card frames, Trait chip, Sets rail highlight; FP / Armor describe the reticle and plate; "Level band" became "Level coin". "New: Traits" mentions the rail tap; "New: Promotion" shows R > T coins; "New: Muster out" lost its serial plate. | `codex/glossary.gd`, `card_info.gd` (GLOSSARY_EXTRA), `run/reveal_flags.gd` (texts only), `new_card.gd` |

**Helpers outside the UI folders (read-only, reported):** `scripts/qa/qa_bridge.gd` reads the Operator card's cost from its meta; `scripts/run/reveal_flags.gd` text strings for two explainers. No rules or balance changes.

**QA.** New `tests/test_cards_v2.gd` (at rest vs peek, the setting, faint vs lit traits, no spine / serial, the damaged plate and team reticle, the rail highlight, H1 select / place / cancel on phone and desktop, X1 fit and the O2 row, Operator states, Y2+ / T1 frames, NOT FOUND YET, the Trains line, the single title style, the Pick icon). Updated: `test_art_kit`, `test_board_columns`, `test_onboard_ui`, `test_syn_ui`, `test_ui3`, `test_ui4`, `test_ui_kit`, `test_run_screens`, `test_card_art_views`. Screenshots (844x390, public art only): `qa/screenshots/cards-v2/` (board at rest, peek, rail highlight, H1 with PLAY HERE, mulligan, Supply Drop, Codex, a Tactic in T1). Tool: `tests/tools/shot_cards.gd`.

**Follow-up (coordinator review).** The mulligan now uses the same Y2+ data as the dock (`MatchController.card_view_for`), so Standard Issue cards show their STANDARD ISSUE tag and text; a unit with no weapon or tag reads UNIT. The text box releases its width when a card is laid out narrower. FRONT tabs now sit inside the objective tile's top / bottom margin, clear of the banners and the tile's labels (desktop: the FRONT word in the 26 px margin; phone: a 5 px side-coloured bar). The move toast ("Round 1: tap your Operator (bottom-left of your hand) ...") sits at the board's bottom edge, never over the objective row; killfeed toasts keep the top edge. The board screenshots in `qa/screenshots/cards-v2/` were taken mid-slide before; the tool now waits for the slides to finish. 536 tests pass.


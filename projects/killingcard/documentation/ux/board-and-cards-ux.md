# KillingCard: Board and Cards UX (vertical columns, banner cards)

*Owner: UI/UX Agent. Board task: kc-ux. Status: proposal for the head's review (2026-11-05).*
*Inputs: `documentation/reference/README.md` and `head-board-reference.webp` (layout idea only, no art taken), Killstreak's match UI (`source/project-killingcard/scripts/ui/`: `screen_profile.gd`, `lane.gd`, `unit_slot.gd`, `hand_area.gd`, `press_gesture.gd`, `card_inspector.gd`), `documentation/design/card-system.md` (sr-game-designer) and `documentation/art/banner-art-direction.md` (sr-game-artist).*

Mock-up: `documentation/ux/mockup/index.html` (one self-contained file, CSS/SVG placeholder art). Screenshots: `documentation/ux/mockup/shots/` (Playwright, device scale factor 1, true device size).

---

## 0. Summary

1. **The board: 3 columns (A / B / C) with the objective row in the middle.** Cards stack outward from the objective. Row 1 touches the objective and holds the **frontline** card. Your rows sit below the objective, the rival's above it, and the hand runs along the bottom. Units enter at the outer edge (the bottom for you, the top for the rival) and slide toward the objective.
2. **The frontline is obvious in 4 ways:** position (it touches the objective), a side-coloured outline, a `FRONT` tab bridging it to the objective, and full brightness while back rows are dimmed to 74%.
3. **Banner ratio: 4:1.** The art team's master is 1536x1024 (3:2). The 4:1 band (1536x384) gives the banner, and a 2:3 column gives the hand art. On the board, banners keep 4:1 at every size.
4. **Hand: I recommend option A** (a portrait-ish crop from the art's 2:3 column, centred on `portrait_x`). On the phone, option B's stripe is 23 px tall (17 pt), less than half the board banner's height, so it helps recognition less than A does. Both options are in the mock-up (toggle) and on a comparison sheet.
5. **Phone at 844x390: 3 rows per side gives 208x52 px banners (150x38 pt).** 4 rows per side gives 176x44 px (127x32 pt). With 4 rows, stat numbers drop to the 11.6 pt minimum and tap pitch drops to 34 pt. The UX recommendation is **3 rows** (Q1). Both layouts are fully specified below and toggle in the mock-up.
6. **Animated banners play only while focused** (desktop hover, touch long-press or right-click inspector, the selected hand card) **or during the placement animation** (about 0.9 s). Only one plays at a time. At rest, every banner shows its poster frame.

---

## 1. Coordinate system and readability minimums

Godot already maps every screen to a logical canvas (`screen_profile.gd`). The px values in this document are **Godot logical px**, so they can go straight into scenes.

| Device | Window | Godot base | Logical canvas | 1 logical px = | Compact profile |
|---|---|---|---|---|---|
| iPhone landscape | 844x390 pt (dpr 3) | 960x540 | **1168x540** | **0.7226 pt** | yes (height < 640) |
| Desktop | 1440x900 (dpr 1) | 1280x720 | **1280x800** | **1.125 physical px** | no |

Minimums (phone pt in brackets; they extend the existing Killstreak rules):

| Element | Minimum | Used here (3-row phone) |
|---|---|---|
| Body text, names, rules | 16 px (11.6 pt) | 16 px |
| Stat numbers (FP, Armor, cost) | 18 px bold (13 pt) | 18 px on a 26 px badge (19 pt) |
| Icon glyphs (keywords, effect ⚡, class pip) | 18 px glyph (13 pt) on a 20 px plate | 20 px plate |
| Buttons (READY, UNDO, MENU) | 61 px (44 pt) tall | 64 / 44+ px |
| Board tap targets (slot pitch) | 56 px (40 pt), see §6.6 | 56 px |
| Hand card | 88x110 px (64x80 pt) | 92x116 px |

---

## 2. Layout grid

Notation: `x0..x1` / `y0..y1` are logical px edges. Slots are numbered from the objective: row 1 = frontline, row 3 (or 4) = back. In the mock-up the rails (score, Operator, deck, supply, READY) are placeholders that keep Killstreak's content. Only their boxes are specified here.

### 2.1 Phone 844x390, 3 rows per side (recommended), canvas 1168x540
| Element | x | y | Size (px) | Size on the phone (pt) |
|---|---|---|---|---|
| Column A / B / C (banner area) | 252..460 / 480..688 / 708..916 | | 208 wide, 20 px gutters | 150 wide |
| Rival row 3 (back), 2, 1 (front) | | 6..58, 62..114, 118..170 | 208x52 banners, 4 px row gap | 150x38 |
| Objective row | | 176..240 | 208x64 tiles | 150x46 |
| Your row 1 (front), 2, 3 (back) | | 246..298, 302..354, 358..410 | 208x52 | 150x38 |
| Hand row | 252..916 | 418..534 | 92x116 cards, 4 px gap (7 cards fit with about 3 px gaps) | 66x84 |
| Left rail (score, Operator; deck at the bottom) | 12..234 | 6..534 | 222 wide | 160 wide |
| Right rail (UNDO, MENU, rival hand; supply, READY at the bottom) | 934..1156 | 6..534 | 222 wide, READY 222x64 | 160x46 |

The vertical budget is 6 + 164 + 6 + 64 + 6 + 164 + 8 + 116 + 6 = 540. Nothing is left over, so another row means smaller banners.

### 2.2 Phone 844x390, 4 rows per side (Killstreak capacity)
| Element | x | y | Size (px) | pt |
|---|---|---|---|---|
| Columns A / B / C | 300..476 / 496..672 / 692..868 | | 176 wide, 20 gutters | 127 |
| Rival rows 4, 3, 2, 1 | | 4..48, 51..95, 98..142, 145..189 | 176x44, 3 gap | 127x32 |
| Objective row | | 193..247 | 176x54 | 127x39 |
| Your rows 1..4 | | 251..295, 298..342, 345..389, 392..436 | 176x44 | 127x32 |
| Hand row | 300..868 | 442..540 | 78x98 cards | 56x71 |
| Badges / numbers / glyphs | | | 22 / 16 / 18 px | 16 / **11.6** / 13 pt |
| Rails | 12..270 and 886..1156 | | | |

Trade-off: the 4-row phone layout is legible, but only at the minimums. Banners lose 26% of their area, numbers sit at the 11.6 pt floor, slot pitch is 47 px (34 pt), and hand names fit about 6 characters before the ellipsis.

### 2.3 Desktop 1440x900, 3 rows, canvas 1280x800
| Element | x | y | Size (px) | Physical px |
|---|---|---|---|---|
| Columns A / B / C | 184..472 / 496..784 / 808..1096 | | 288 wide, 24 gutters | 324 |
| Rival rows 3, 2, 1 | | 12..84, 90..162, 168..240 | 288x72, 6 gap | 324x81 |
| Objective row | | 248..336 | 288x88 | 324x99 |
| Your rows 1, 2, 3 | | 344..416, 422..494, 500..572 | 288x72 | 324x81 |
| Hand row | 184..1096 | 584..784 | 144x192 cards (7 cards overlap by 16 px) | 162x216 |
| Badges / numbers / glyphs | | | 32 / 22 / 26 px | 36 / 25 / 29 |
| Rails | 12..166 and 1114..1268 | | | |

### 2.4 Desktop 1440x900, 4 rows
Columns 232..488 / 512..768 / 792..1048 (256x64 banners, 5 px gap). Rival rows 4..1: 12..76, 81..145, 150..214, 219..283. Objective row: 291..371 (80 tall). Your rows 1..4: 379..443, 448..512, 517..581, 586..650. Hand: 660..800 with 108x140 cards. Badges 28 px, numbers 20 px.

### 2.5 Other sizes
- Banner size follows from the height: `bh = (H - top - 2*midGap - objH - handGap - handH - margin - 2*(rows-1)*rowGap) / (2*rows)`, and `bw = 4*bh`. Columns centre horizontally. Rails take whatever width is left. Below about 200 px of rail width, the rails stack their boxes vertically.
- The canvas width depends on the aspect. A 19.5:9 phone gets 1168 logical px of width, but the board only needs about 664, so wider phones gain rail space, not banner size. Height is what limits the board.
- Portrait phones are out of scope (landscape only, as in Killstreak).

---

## 3. Card anatomy

### 3.1 Banner format
- **Board ratio: 4:1** (the classic 512x128 calling card). The reference board's banners measure about 280x70 px, also 4:1.
- **Source:** per the art direction doc, the artist generates at 1536x1024. The **banner** is the 4:1 band (1536x384, centred at `banner_y`). The **hand** art comes from the 2:3 column (683x1024, centred at `portrait_x`). Their intersection (683x384) is the "core", which holds the head and the weapon.
- Off-ratio art (3.5:1 to 4.5:1) is cropped to fill 4:1 by the import step, never letterboxed.

### 3.2 Board banner (your card; the rival's is mirrored top to bottom)
```
            objective is ABOVE your card
   ┌───┬─────────────────────────────────────┬───┐
   │FP │                                     │AR │  <- inner edge (faces the objective)
   │ 3 │      art: centre 70% stays clean    │ 4 │
   │cls│                                     │ ⚡│  <- outer edge
   └───┴─────────────────────────────────────┴───┘
   ^ 5 px side spine (teal chevrons = yours, red hazard = rival)
```
| Slot | Content | Phone 3-row | Desktop 3-row |
|---|---|---|---|
| Spine (left edge) | Side colour plus pattern (chevron or hazard), so it reads without colour | 5 px | 7 px |
| Inner-left | **Firepower**, effective in this column. Yours: teal circle. Rival: red diamond (a shape cue for colour-blind players). | 26 px badge, 18 px number | 32 / 22 |
| Inner-right | **Armor**, current. Grey shield, amber when damaged. | 26x28, 18 px | 32x34, 22 |
| Outer-left | Weapon-class pip (rifle, SMG, sniper...) | 20 px plate | 26 |
| Outer-right | Effect: up to 2 keyword glyphs (Pick, Cover, Protector...) or ⚡ for triggered or aura text. More than 2: ⚡ plus a dot. | 20 px plates | 26 |
| `FRONT` tab | Only on row 1. A side-coloured tab outside the inner edge that touches the objective tile. | 44x12, 9 px caps | 60x14 |
| Frontline frame | 2 px side-colour outline plus shadow. Back rows: brightness 74%, saturation 80%. | | |
| `PLAN` tag | Your card planned this Deploy (top-left, over the art) | 11 px caps | |
| Animation dot | Debug only in the mock-up (red dot = animating). Not shipped. | | |

- Icons sit only in the **left and right ~15% columns**, so the centre of the art stays clean. The front cards' FP numbers face each other across the objective ("my 3 vs their 2").
- No card name on the board. Players recognise the art. The name and rules are in the inspector, and on desktop hover.
- Skull glyphs are reserved for eliminations (killfeed, streak), never used as a stat.
- **Objective tile:** a column letter in a control mark (yours = teal circle, rival = red diamond, contested = grey dashed square). Rival column firepower is shown at the top-left, yours at the bottom-left, and the control word at the right (`YOURS` / `RIVAL` / `CONTESTED`). Equipment chips go on the owner's side of the tile. Long-press or right-click opens the objective's rules.
- **Incoming rival unit:** a face-down banner back (red hazard, pulsing red dot, `INCOMING`) shown **in the slot where it will land** (the back of their line). This replaces Killstreak's minimap red dots, and it replaces card-system.md's separate staging strip (see §6.1 and Q2).

### 3.3 Hand card, option A: crop on a normal-ish card (recommended)
| | Phone 3-row | Phone 4-row | Desktop 3-row |
|---|---|---|---|
| Card | 92x116 | 78x98 | 144x192 |
| Art window (top, full width) | 92x70 | 78x56 | 144x118 |
| Cost hex (top-left, over the art) | 24x28, 16 px number | 22x26 | 30x34, 20 px |
| Name (1 line, ellipsis) | 16 px | 16 px | 18 px |
| Bottom row | FP, keyword glyphs, Armor (16 px icons, 18 px numbers). Tactics: `TACTIC` plus ⚡. | 14 / 16 | 20 / 22 |

- The art window is a crop of the 2:3 column at `portrait_x`. At about 1.3:1, it shows the core plus a bit above and below, so the figure reads larger than on the banner. With the 4:1 placeholder art in the mock-up, A shows 33% of the banner width at 0.55x source scale (phone).
- A dimmed card (can't afford it) is greyscale at 60% brightness. Tapping it shows the reason as a toast.

### 3.4 Hand card, option B: vertical card with the full banner as a stripe
Same footprint. Top: cost hex plus name. Then a **full-width 4:1 stripe**: 92x23 px on the phone (66x17 pt), or 144x36 on desktop. Below it: the type line or the first rules words, then the stats. The card's background is a blurred, darkened enlargement of the same art.

### 3.5 Comparison and recommendation
| | A: crop | B: stripe |
|---|---|---|
| Art size (phone) | 92x70 px, 0.55x source | 92x23 px, 0.18x source |
| Matches the board banner | Partly: the same subject, bigger | Fully: the same composition, but 2.3x smaller than the board banner |
| Recognising "which card is this" at a glance | Strong for units (face and weapon). Weaker for wide-composition tactics. | Weak on the phone: too small to read detail |
| Room for rules text | None (the inspector has it) | 2 to 3 short lines on desktop, about 2 on the phone |
| Placement morph into the banner | The art window un-crops into the band (the subject stays in place) | The stripe grows to banner size |
| Needs per-art data | `portrait_x` (already in the art pipeline) | none |

**Recommendation: A on both phone and desktop.** On the phone, art size is what makes a card recognisable, and A has 3x the area of B's stripe. The full composition is never more than one gesture away: the landing-slot ghost shows the full banner as soon as a unit is selected, desktop hover shows a full-banner peek above the card, and long-press opens the zoomed banner. B is reasonable on desktop only. Mixing the two would teach two card faces, so I would not.

### 3.6 Focused and zoomed card
| State | Trigger | Shows |
|---|---|---|
| **Hover zoom** (desktop only) | Mouse over a banner for more than 120 ms | The banner scales in place to 512 px wide (x1.78), anchored away from the screen edges and growing over the objective side. Name and type tag underneath. Animated. No scrim. Ends on mouse-out. |
| **Inspector** (everyone) | Long-press 400 ms (touch), right-click (mouse), or the Inspect key | Scrim plus a panel: the banner at **512x128 logical** (370x92 pt on the phone, 576x144 physical on desktop) with large stat badges, chassis name (24 px) and art title, type, cost, side, stat chips with words, full rules and keyword lines, and "alternate art n of m". Animated. Closes on a tap anywhere or Esc. Same component as Killstreak's `card_inspector.gd`. |
| **Selected** | Tap a hand card | Card raised 14% of its height, teal outline, animated. Valid columns framed. Ghost in the landing slot. |

Studio rule: everything is inspectable. Banners, hand cards, incoming backs, objective tiles and the rail boxes all open the inspector on long-press or right-click. Nothing is hover-only: hover is a desktop shortcut for what long-press does.

### 3.7 Animated banners
- **Focus** means exactly one of: the desktop hover zoom, the open inspector, or the selected hand card. On touch there is no hover, so focus = long-press or selection.
- An animated banner loops **only** while it has focus, or during its own placement animation (about 0.9 s, one pass, from lift to settle). After that it returns to its **poster frame** (an artist-chosen still).
- **At most one banner animates at a time.** A new focus stops the previous one. The placement animation has priority. When several cards reveal together, each one animates only during its own slide.
- At rest, animated arts look exactly like static ones on the board. The "foil" sheen that card-system.md suggests for idle animated arts should be at most a 1 s frame glint every 8 s or more, and off when reduced motion is on. Otherwise the board stops being calm.
- Godot: a `SpriteFrames` / `AnimatedTexture` (art direction T3) or a shader tier (T1/T2), paused through `speed_scale = 0` or `paused = true`, never freed, so resuming has no hitch.

---

## 4. Interaction flows

Input works as in Killstreak (`press_gesture.gd`): tap = select or play, drag past 10 px = drag, long-press 400 ms or right-click = inspect. Mouse and touch behave the same.

### 4.1 Play a unit into a column (Deploy)
1. **Tap** a hand card. It is selected and animated. Valid columns get a teal frame with `PLAY HERE`. Invalid columns are dimmed with a reason (`COLUMN FULL`, `NEED 3 SUPPLY`; Killstreak's `lane.set_target`).
2. A **ghost** of the full banner (50% opacity, dashed outline) appears in each valid column's landing slot, which is the first free row counted from the objective.
3. **Tap a column**, or **drag** the card onto it. The whole player half of the column is the drop target (208x164 px, 150x118 pt).
4. The card runs the placement animation (§5.1) into its landing slot and gets a `PLAN` tag. UNDO takes it back to the hand.
5. Tap the selected card again, or tap empty space, to cancel.

### 4.2 Reveal
Your `PLAN` cards lose the tag and play a short settle (badges pop and the art animates for one pass). Rival `INCOMING` backs flip and their cards slide in from the **top** screen edge to their slot (§5.1, mirrored). Order follows Killstreak's reveal order, with 120 ms between cards and at most 2.5 s per Reveal in total.

### 4.3 Advance
When a card is eliminated, it flashes desaturated and fades (500 ms). At the end of the firefight step, every card behind it slides one row toward the objective (320 ms, 60 ms stagger). The new frontline gets its outline, its `FRONT` tab and a 300 ms pop.

### 4.4 Protector
- **Selected:** the ghost appears in **row 1**, and the column label reads `TAKES THE FRONT`.
- **Played:** the card enters at the outer edge and lands at the back, pauses 160 ms, then slides past every friendly card to row 1 (320 ms) while the cards it passed shift back one row. The first time a Protector is played, a callout reads "Protector slides to the front".
- **Rival Protector:** its `INCOMING` back stays at the back (its identity is hidden). On Reveal it flips and slides to the front, so the reveal itself shows the surprise. "Slides to the top" in the head's brief now means **toward the objective**, on both sides.

### 4.5 Targeting (tactics and abilities)
- **Column-target tactic:** valid columns are labelled `TARGET THIS COLUMN`. While you drag, or while a column is under the selection, the cards the tactic would hit get a red reticle frame (for example, Red Ledger frames the rival's front card).
- **Unit-target effect:** valid units get reticle frames and everything else dims to 50%. Tap a unit. The hit area is the whole slot pitch. A tap in a column's half snaps to the nearest valid target in that half, and a drag snaps on release.
- **Pick (firefight):** the shot draws as a tracer **outside the column** (curving through the gutter) from the shooter to the lowest-Armor target. The target gets a reticle. The skipped frontline gets a dashed white outline. The first time, a callout reads `PICK: lowest Armor (n)`. Ties go to the card nearest the objective.
- **Flank** uses the same tracer, aimed at the outermost card.

### 4.6 Inspect
Long-press or right-click anything (§3.6). On desktop, hovering does the same as a quick look. The hand keeps its position while the inspector is open.

---

## 5. Animation spec

### 5.1 Placement (your card; the rival's mirrors from the top edge)
| t (ms) | Step | Easing |
|---|---|---|
| 0..220 | Lift and morph: from the hand card's art window (A) or stripe (B) to a banner at the column's **outer edge** (just outside the back row), scale 1.04. The art animation starts. | cubic-bezier(.3,.7,.3,1) |
| 220..(400 to 610) | Slide toward the objective into the landing slot, taking 180 ms plus 70 ms per empty row it passes. Lands at scale 1.0 with a slight overshoot. | cubic-bezier(.2,.9,.25,1.12) |
| +380..+660 | Stat badges and glyphs pop in (scale 0 to 1, 280 ms) | back-out |
| about 900 | The art returns to its poster frame | |
| (Protector) +160 | Slide to row 1; the cards it passed shift back | 320 ms, same easing |

- "Fast animations" (settings) halves every duration. Reduced motion replaces the slides with 150 ms cross-fades and turns the art loop off.
- Godot: `create_tween()` on each banner's `position` and `size`, inside a plain `Control` column (not a `VBoxContainer`, because containers fight tweens). Drive it from `UNIT_ARRIVED`'s `index`, which the rules already emit.

---

## 6. Assumptions, coordination and deviations

1. **No separate staging strip.** card-system.md §4.2 adds a staging strip at the outer edge of each column. On the phone that strip costs a whole row of height (about 52 px). Instead, your planned card sits in its landing slot with a `PLAN` tag, and a rival's planned unit shows as an `INCOMING` back in its landing slot. You get the same information without the extra row. Q2 asks the head.
2. **Rows: 3 vs 4.** The design doc keeps 4 (Killstreak capacity; 3 would need a balance re-run). This layout supports both. Both are specified in §2, and the mock-up toggles them (Rows: 3 / 4). The UX preference is 3, for phone legibility (Q1).
3. **Icon positions** follow card-system.md §3.4 and the lead's note: FP and Armor on the inner edge. The effect glyph and class pip sit in the left and right ~15% columns on the outer edge rather than in the inner centre, because the inner centre is where figures' heads are.
4. **Hand art source:** option A uses the artist's 2:3 column (banner-art-direction.md §3), cropped to about 1.3:1. The mock-up's placeholder art is 4:1 only, so it crops the banner itself. Real art will show more of the figure.
5. **Display name** on cards and in the hand is the chassis name (card-system.md §2.1). The mock-up uses invented placeholder names.
6. **The 4:1 board banner cannot fit a full hand row.** 7 full banners on desktop would need 2016 px. That's another reason the hand uses A.
7. **Hit areas:** on the 3-row phone layout, the board slot pitch is 40 pt, under Apple's 44 pt. It's acceptable because playing a card targets a whole column half (118 pt). Single-unit targeting gets tap snapping and drag-release snapping (§4.5). On the 4-row phone layout the pitch is 34 pt, so snapping is required there.

---

## 7. Mock-up guide

Open `documentation/ux/mockup/index.html` in any browser. The toolbar switches Screen (phone / desktop), Rows (3 / 4) and Hand (A / B), and runs the demos: select, play into A, Protector slide, rival plays, front dies and the column advances, Pick shot, focus/zoom, and the A-vs-B sheet. Interactions: tap or drag a hand card onto a column, long-press or right-click anything, hover on desktop. URL parameters (`?chrome=0&size=phone&rows=3&hand=A&state=selected|focus|pick|placement|protector|rival|advance|hover|compare`) reproduce each screenshot.

| Screenshot (`mockup/shots/`) | Shows |
|---|---|
| `phone-board-handA.png`, `phone-board-handB.png` | 3-row phone board, hand A / B |
| `phone-4rows-handA.png` | 4-row phone board |
| `phone-selected-handA.png`, `phone-selected-protector.png` | Selection: valid columns, landing ghosts, `TAKES THE FRONT` |
| `phone-placement-mid.png` | Placement animation, mid-slide from the outer edge (3x slow) |
| `phone-protector-slide.png` | Protector after sliding to row 1 (`PLAN` tag) |
| `phone-rival-reveal.png` | Rival card entering from the top edge |
| `phone-focus-zoom.png`, `desktop-focus-zoom.png` | Inspector with the 512x128 banner |
| `phone-pick.png`, `desktop-pick.png` | Pick tracer skipping the frontline |
| `phone-hand-compare.png`, `desktop-hand-compare.png` | A vs B at true size and enlarged, with the crop window on the source |
| `desktop-board-handA.png`, `desktop-board-handB.png`, `desktop-4rows-handA.png` | Desktop boards |
| `desktop-hover-zoom.png` | Desktop hover zoom in place |

---

## 8. Questions for the head
1. **Rows per side:** (a) 3 rows: 208x52 banners on the phone, 13 pt numbers; needs the balance re-run that card-system.md mentions. **Recommended for the phone.** (b) 4 rows: 176x44 banners at the minimum legible size; no balance change. (c) 4 rows on desktop, 3 on the phone: not recommended, because rules would differ by device.
2. **Rival plans:** (a) an `INCOMING` back in its landing slot, with no staging strip. **Recommended:** it saves a row on the phone. (b) A separate staging strip at each column's outer edge (card-system.md §4.2).
3. **Hand card:** (a) option A, a crop from the 2:3 column. **Recommended.** (b) Option B, the full banner as a stripe. (c) A on the phone, B on desktop.

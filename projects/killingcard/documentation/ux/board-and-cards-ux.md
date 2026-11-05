# KillingCard: Board and Cards UX (vertical columns, banner cards)

*Owner: UI/UX Agent. Board task: kc-ux. Status: proposal for the head's review (2026-11-05).*
*Inputs: `documentation/reference/README.md` and `head-board-reference.webp` (layout idea only; no art taken), Killstreak's match UI (`source/project-killingcard/scripts/ui/`: `screen_profile.gd`, `lane.gd`, `unit_slot.gd`, `hand_area.gd`, `press_gesture.gd`, `card_inspector.gd`), `documentation/design/card-system.md` including the head's decisions of 2026-11-05 (4 rows per side; the Operator is a deployable unit with unit art only), and `documentation/art/banner-art-direction.md`.*

Mock-up: `documentation/ux/mockup/index.html` (one self-contained file, CSS/SVG placeholder art). Screenshots: `documentation/ux/mockup/shots/` (Playwright, device scale factor 1, true device size).

---

## 0. Summary

1. **3 columns (A / B / C), with the objective row in the middle.** Each side has **4 rows** (the head's decision). Row 1 touches the objective and is the **frontline**. Your rows are below the objective and the rival's are above it. The hand runs along the bottom. Units enter at the outer edge (the bottom for you, the top for the rival) and slide toward the objective.
2. **The frontline is obvious in 4 ways:** it touches the objective, it has a side-coloured outline, a `FRONT` tab links it to the objective, and it is the only card at full brightness (back rows are at 74%).
3. **Banner ratio: 4:1** (the classic 512x128). Art masters are 1536x1024 (3:2): the 4:1 band gives the banner, and a 2:3 column gives the hand art.
4. **Phone 844x390: banners are 176x44 px (127x32 pt), 3 columns x 4 rows per side, plus a 7-card hand.** Stat numbers hit the 11.6 pt text floor exactly. Desktop 1440x900: banners are 256x64 px (288x72 physical px).
5. **Hand: I recommend option A** (a portrait-ish crop from the art's 2:3 column, centred on `portrait_x`). On the phone, option B's stripe would be 20 px tall (14 pt): too small to recognise. Both options are in the mock-up (toggle) and on a comparison sheet.
6. **Animated banners play only while focused** (desktop hover, long-press or right-click inspector, the selected hand card) **or during the ~0.9 s placement animation**. At most one plays at a time.
7. **The Operator** (your equipped calling card, a deployable unit) gets a **mastery frame**: a brass border, a camo band on the outer edge whose pattern is the camo tier, and a dog-tag plate in place of the effect glyph. This is the hook for the weapon-mastery / camo-grind idea.

---

## 1. Coordinate system and readability minimums

Godot already maps every screen to a logical canvas (`screen_profile.gd`). Every px value in this document is in **Godot logical px**, so it can go straight into scenes.

| Device | Window | Godot base | Logical canvas | 1 logical px = | Compact profile |
|---|---|---|---|---|---|
| iPhone landscape | 844x390 pt (dpr 3) | 960x540 | **1168x540** | **0.7226 pt** | yes (height < 640) |
| Desktop | 1440x900 (dpr 1) | 1280x720 | **1280x800** | **1.125 physical px** | no |

Minimums on the phone (pt in brackets; they extend Killstreak's rules) and what this layout uses:

| Element | Minimum | Phone, 4 rows | Status |
|---|---|---|---|
| Body text, names, rules | 16 px (11.6 pt) | 16 px | meets |
| Stat numbers (FP, Armor, cost) | 16 px bold (11.6 pt) | 16 px on a 22 px badge (16 pt) | meets the floor exactly |
| Icon plates (keywords, ⚡, class pip, Operator tag) | 18 px (13 pt) | 18 px plate, 14 px glyph (10 pt) | plate meets; the glyph is small, so glyphs must differ by shape and the inspector names them |
| Buttons (READY, UNDO, MENU) | 61 px (44 pt) | 64 px / 44+ px | meets |
| Board tap pitch (one slot) | 61 px (44 pt) | 47 px (34 pt) | **below**: needs tap snapping (§4.5) |
| Column drop target (playing a card) | 61 px | 176x185 px (127x134 pt) | meets |
| Hand card | 78x98 px (56x71 pt) | 78x98 px | meets |

Desktop has no constraint. Everything there is at least 1.27x the phone size in logical px.

---

## 2. Layout grid (final: 4 rows per side)

Notation: `x0..x1` / `y0..y1` are logical px edges. Rows are numbered from the objective: row 1 = frontline, row 4 = back. The rails (score, Operator status, deck, supply, READY) keep Killstreak's content. Only their boxes are specified here.

### 2.1 Phone 844x390, canvas 1168x540
| Element | x | y | Size (px) | On the phone (pt) |
|---|---|---|---|---|
| Columns A / B / C | 300..476 / 496..672 / 692..868 | | 176 wide, 20 px gutters | 127 wide |
| Rival rows 4 (back), 3, 2, 1 (front) | | 4..48, 51..95, 98..142, 145..189 | 176x44 banners, 3 px row gap | 127x32 |
| Objective row | | 193..247 | 176x54 tiles | 127x39 |
| Your rows 1 (front), 2, 3, 4 (back) | | 251..295, 298..342, 345..389, 392..436 | 176x44 | 127x32 |
| Hand row | 300..868 | 442..540 | 78x98 cards, 4 px gap (7 cards fit with ~0 gap) | 56x71 |
| Left rail (score, Operator status; deck at the bottom) | 12..270 | | 258 wide | 186 |
| Right rail (UNDO, MENU, rival hand; supply, READY at the bottom) | 886..1156 | | 270 wide, READY 270x64 | 195x46 |
| Banner badges / numbers / plates | | | 22 / 16 / 18 px | 16 / 11.6 / 13 |

Vertical budget: 4 + 185 + 4 + 54 + 4 + 185 + 6 + 98 = 540. Nothing is left over.

### 2.2 Desktop 1440x900, canvas 1280x800
| Element | x | y | Size (px) | Physical px |
|---|---|---|---|---|
| Columns A / B / C | 232..488 / 512..768 / 792..1048 | | 256 wide, 24 px gutters | 288 |
| Rival rows 4..1 | | 12..76, 81..145, 150..214, 219..283 | 256x64, 5 px gap | 288x72 |
| Objective row | | 291..371 | 256x80 | 288x90 |
| Your rows 1..4 | | 379..443, 448..512, 517..581, 586..650 | 256x64 | 288x72 |
| Hand row | 232..1048 | 660..800 | 108x140 cards, 8 px gap (7 fit) | 122x158 |
| Rails | 12..214 and 1066..1268 | | | |
| Badges / numbers / plates | | | 28 / 20 / 22 px | 31 / 22.5 / 25 |

### 2.3 Other sizes, and the dropped 3-row variant
- Banner size follows from the height: `bh = (H - top - 2*midGap - objH - handGap - handH - 2*3*rowGap) / 8`, and `bw = 4*bh`. Columns centre horizontally. On a landscape phone, height is the only limit: wider phones gain rail space, not banner size.
- Portrait phones are out of scope (landscape only, as in Killstreak).
- *3 rows per side (dropped by the head's decision):* on the phone it would have given 208x52 banners (150x38 pt) and 18 px numbers. It is still viewable as a reference with `?rows=3` in the mock-up (`shots/phone-3rows-reference.png`, `desktop-3rows-reference.png`).

---

## 3. Card anatomy

### 3.1 Banner format
- **Board ratio: 4:1.** The reference board's banners measure ~280x70 px, also 4:1. Masters are 1536x1024 (3:2), per the art direction doc §3. The **banner** is the 4:1 band (1536x384) at `banner_y`, and the **hand art** comes from the 2:3 column (683x1024) at `portrait_x`.
- Off-ratio art (3.5:1 to 4.5:1) is cropped to fill 4:1 at import, never letterboxed.
- Badges cover the left and right **~15% columns**, so the subject must live in the centre 70%. The Operator's camo band also covers the outer 6 px strip.

### 3.2 Board banner (your card; the rival's is mirrored top to bottom)
```
            objective is ABOVE your card
   ┌───┬─────────────────────────────────────┬───┐
   │FP │                                     │AR │  <- inner edge (faces the objective)
   │ 3 │       art: centre 70% stays clean    │ 4 │
   │cls│                                     │ ⚡│  <- outer edge
   └───┴─────────────────────────────────────┴───┘
   ^ side spine (teal chevrons = yours, red hazard stripes = rival)
```
| Slot | Content | Phone | Desktop |
|---|---|---|---|
| Spine (left edge) | Side colour plus a pattern (colour-blind safe, as in Killstreak's CardView) | 4 px | 6 px |
| Inner-left | **Firepower**, effective in this column. Yours: teal circle. Rival: red diamond. | 22 px badge, 16 px number | 28 / 20 |
| Inner-right | **Armor**, current. Grey shield; amber when damaged. | 22x24, 16 px | 28x30, 20 |
| Outer-left | Weapon-class pip | 18 px plate | 22 |
| Outer-right | Effect: up to 2 keyword glyphs, or ⚡ for triggered or aura text (more than 2: ⚡ plus a dot). The Operator shows its dog-tag plate here. | 18 px plates | 22 |
| `FRONT` tab | Row 1 only: a side-coloured tab outside the inner edge, touching the objective tile | 40x11 | 60x14 |
| Frontline frame | 2 px side-colour outline plus shadow. Back rows: brightness 74%, saturation 80%. | | |
| `PLAN` tag | Your card planned this Deploy | 11 px caps | |

- The front cards' FP numbers face each other across the objective ("my 3 vs their 2").
- No card name on the board. Players recognise the art. The chassis name and rules are in the inspector (and in the hover tag on desktop).
- Skull glyphs are reserved for eliminations, never used as a stat.
- **Objective tile:** the column letter in a control mark (yours: teal circle; rival: red diamond; contested: grey dashed square). Rival column firepower at the top-left, yours at the bottom-left, and the control word (`YOURS` / `RIVAL` / `CONTESTED`) at the right. Equipment chips go on the owner's side of the tile. Long-press or right-click shows the objective's rules.
- **Incoming rival unit:** a face-down banner back (red hazard stripes, pulsing red dot, `INCOMING`) shown **in the slot where it will land** (the back of their line). It replaces Killstreak's minimap red dots and card-system.md's separate staging strip (§6.1, Q1).

### 3.3 Operator banner (your calling card on the board)
The Operator is a deployable unit with stronger stats and unit art only. It's the card players see every game, so its frame is the one special frame on the board:

| Element | Look | Purpose |
|---|---|---|
| Mastery frame | 3 px brass inner border with a dark keyline and a soft brass glow. It sits inside the banner, so it never changes the slot size. | Reads as "this is me" next to plain cards. Stacks with the frontline outline. |
| Camo band | A 6 px pattern strip on the **outer edge** (the edge away from the objective) | The **camo tier** of the mastery grind: e.g. Base, Bronze, Silver, Gold, then patterned camos. The band carries the tier, and the art stays the player's banner. In the mock-up it's a gold digital camo. |
| Dog-tag plate | In the outer-right slot (where an effect glyph would go), brass on dark | The Operator's identity. The callsign text is in the inspector and the rail (too small for the banner on the phone). |
| Glint | The camo band's thin highlight sweeps only while the Operator has focus or is being placed (same rule as animated art) | No idle motion on the board. |
| Left rail | `Kestrel OPERATOR`, its position ("On board: A, row 2"), and the camo tier. On respawn: the countdown. Its swatch shows the camo pattern. | Find the Operator without scanning the board. |
| Rival Operator | Same frame on the rival's banner | Its elimination is the "you got carded" moment (card-system.md §5). |

- **Future camo variants:** alternate art tiers of the same Operator change the art, and the tier changes the band. Both live in the frame, so no layout change is needed.
- Mastery tiers should differ in pattern as well as colour (colour-blind players).

### 3.4 Hand card, option A: crop on a normal-ish card (recommended)
| | Phone | Desktop |
|---|---|---|
| Card | 78x98 | 108x140 |
| Art window (top, full width) | 78x56 (~1.4:1) | 108x82 |
| Cost hex (top-left, over the art) | 22x26, 15 px number | 30x34, 20 px |
| Name (1 line, ellipsis; ~6 characters on the phone, ~11 on desktop) | 16 px | 16 px |
| Bottom row | FP, keyword glyphs and Armor (14 px icons, 16 px numbers). Tactics: `TACTIC` plus ⚡. | 16 / 18 |

- The art window is a crop of the 2:3 column at `portrait_x`. It shows the art direction doc's "core" plus a little above and below, so the figure reads larger than on the banner. The mock-up's placeholder art is 4:1 only, so it crops the banner itself.
- A dimmed card (can't afford it) is greyscale at 60% brightness. Tapping it shows the reason as a toast.
- The truncated name is acceptable: the decision needs the art, cost and stats, and the full name is one long-press away.

### 3.5 Hand card, option B: a vertical card with the full banner as a stripe
Same footprint. At the top: cost hex plus name. Below that, a **full-width 4:1 stripe** (78x20 px = 56x14 pt on the phone; 108x27 on desktop). Then the type line or the first rules words, then the stats. The background is a blurred, darkened enlargement of the art.

### 3.6 Comparison and recommendation
| | A: crop | B: stripe |
|---|---|---|
| Art on the phone | 78x56 px | 78x20 px, about half the board banner's height |
| "Which card is this?" at a glance | Strong for units (face and weapon); weaker for wide-composition tactics | Weak on the phone: no detail is readable at 14 pt tall |
| Matches the board banner | The same subject, larger | The same composition, smaller |
| Rules text room | None (the inspector has it) | About 2 short lines |
| Placement morph | The art window un-crops into the band (the subject stays in place) | The stripe grows into the banner |
| Per-art data | `portrait_x` (already in the art pipeline) | none |

**Recommendation: A on both phone and desktop.** Art area is what makes a card recognisable on the phone, and A has 2.8x the art area of B. The full composition is always one step away: selecting a unit shows its full banner as a ghost in the landing slot, desktop hover shows a full-banner peek above the card, and long-press opens the zoomed banner. One card face on every device teaches faster than two. A full-banner hand doesn't fit either: 7 board-size banners need 1792 px.

### 3.7 Focused and zoomed card
| State | Trigger | Shows |
|---|---|---|
| **Hover zoom** (desktop) | Mouse over a banner for more than 120 ms | The banner scales in place to 512 px wide (x2.0), anchored away from screen edges and growing over the objective side. A name and type tag sits under it. Animated. No scrim. |
| **Inspector** (everyone) | Long-press 400 ms (touch), right-click (mouse), or the Inspect key | Scrim plus a panel: the banner at **512x128 logical** (370x92 pt on the phone; 576x144 on desktop) with large badges; chassis name (24 px) and art title; type, cost and side; stat chips with words; full rules and keyword lines; "alternate art n of m". The Operator also shows its camo tier. Closes on a tap anywhere or Esc. Same role as Killstreak's `card_inspector.gd`. |
| **Selected** | Tap a hand card | The card rises by 14% of its height, gets a teal outline and animates. Valid columns get a frame. A ghost appears in the landing slot. |

Studio rule: everything can be inspected. Banners, hand cards, incoming backs, objective tiles and rail boxes all open the inspector on long-press or right-click. Nothing is hover-only.

### 3.8 Animated banners
- **Focus** means exactly one of: the desktop hover zoom, the open inspector, or the selected hand card. On touch there is no hover, so focus means long-press or selection.
- An animated banner loops **only** while focused, or during its own placement animation (~0.9 s, one pass from lift to settle). Then it returns to its **poster frame**, a still chosen by the artist.
- **At most one banner animates at a time.** A new focus stops the previous one, and placement has priority. When cards reveal together, each animates only during its own slide.
- At rest, animated arts look exactly like static ones. If the "foil" idle sheen from card-system.md is kept, it should be at most one 1 s glint every 8 s or longer, and off under reduced motion.
- Godot: use `SpriteFrames` / `AnimatedTexture` or the shader tiers from the art direction doc. Pause playback (`speed_scale = 0`) rather than freeing it, so resuming doesn't hitch.

---

## 4. Interaction flows

Input works as in Killstreak (`press_gesture.gd`): tap = select or play; drag past 10 px = drag; long-press 400 ms or right-click = inspect. Mouse and touch behave the same.

### 4.1 Play a unit into a column (Deploy)
1. **Tap** a hand card. It is selected and animates. Valid columns get a teal frame with `PLAY HERE`. Invalid ones dim with a reason (`COLUMN FULL`, `NEED 3 SUPPLY`; Killstreak's `lane.set_target`).
2. A **ghost** of the full banner (50% opacity, dashed outline) appears in each valid column's landing slot: the first free row counted from the objective.
3. **Tap the column** (anywhere in your half, banners included) or **drag** the card onto it.
4. The card plays the placement animation (§5) into its slot and gets a `PLAN` tag. UNDO takes it back.
5. To cancel, tap the selected card again or tap empty space.

### 4.2 Reveal
Your `PLAN` cards lose the tag and play a short settle (badges pop, one pass of the art animation). Rival `INCOMING` backs flip, and those cards slide in from the **top** screen edge to their slots. Cards reveal in Killstreak's order, 120 ms apart, with a cap of 2.5 s per Reveal.

### 4.3 Advance
An eliminated card flashes desaturated and fades (500 ms). At the end of the firefight step, every card behind it slides one row toward the objective (320 ms, 60 ms stagger). The new frontline gets its outline, its `FRONT` tab and a 300 ms pop.

### 4.4 Protector
- **Selected:** the ghost appears in **row 1**, and the column label reads `TAKES THE FRONT`.
- **Played:** it enters at the outer edge and lands at the back. After a 160 ms pause it slides past every friendly card to row 1 (320 ms), and the cards it passed shift back one row. The first time, a callout reads "Protector slides to the front".
- **Rival Protector:** the incoming back stays at the back, since its identity is hidden. On Reveal it flips and slides to the front.
- In the head's words "to the top", *top* now means **toward the objective**, on both sides.

### 4.5 Targeting (tactics and abilities)
- **Column-target tactic:** valid columns are labelled `TARGET THIS COLUMN`. While you drag or hover over one, the cards the tactic would hit get a red reticle frame.
- **Unit-target effect:** valid units get reticle frames and the rest dim to 50%. Because the slot pitch on the phone is only 34 pt, a tap anywhere in a column half **snaps to the nearest valid target** in that half, and a drag snaps on release. If two targets are within 1 slot of the tap, a small chooser shows both banners at 2x.
- **Pick (firefight):** the tracer runs **outside the column** (through the gutter) from the shooter to the lowest-Armor target. The target gets a reticle, and the skipped frontline gets a dashed outline. The first time, a callout reads `PICK: lowest Armor (n)`. Ties go to the card nearest the objective.
- **Flank:** the same tracer, aimed at the outermost card.

---

## 5. Placement animation spec (yours; the rival's mirrors it from the top edge)
| t (ms) | Step | Easing |
|---|---|---|
| 0..220 | Lift and morph from the hand card's art window (A) or stripe (B) into a banner at the column's **outer edge**, at scale 1.04. The art animation starts. | cubic-bezier(.3,.7,.3,1) |
| 220..~600 | Slide toward the objective into the landing slot: 180 ms + 70 ms per empty row passed, with a slight overshoot | cubic-bezier(.2,.9,.25,1.12) |
| +380..+660 | Badges and glyphs pop in (scale 0 to 1, 280 ms) | back-out |
| ~900 | Art returns to its poster frame | |
| (Protector) +160 | Slides to row 1; the cards it passed shift back | 320 ms |

- "Fast animations" halves all times. Reduced motion uses 150 ms cross-fades instead and turns the art loop off.
- Godot: `create_tween()` on each banner's `position` and `size`, inside a plain `Control` column (not a `VBoxContainer`, which fights tweens). Drive it from `UNIT_ARRIVED`'s `index`, which the rules already emit.

---

## 6. Assumptions, coordination and deviations
1. **No separate staging strip.** card-system.md §4.2 has one at each column's outer edge. On the phone it would cost ~44 px (a whole row) that the 4-row layout doesn't have. Instead, your planned card sits in its landing slot with a `PLAN` tag, and a rival's planned unit shows as an `INCOMING` back in its landing slot. The information is the same, and no row is spent. (Q1)
2. **Icon positions** follow card-system.md §3.4 and the lead's note: FP and Armor on the inner edge, and the effect glyph and class pip in the left and right ~15% columns on the outer edge. The inner centre stays free because that's where the figures' heads are.
3. **Hand art source:** option A uses the artist's 2:3 column. The mock-up's placeholders are 4:1, so they crop the banner.
4. **Display names** are chassis names (card-system.md §2.1). The mock-up's names are placeholders.
5. **Phone tap pitch** (34 pt) is below 44 pt. Playing a card targets a 127x134 pt column half. Unit targeting relies on snapping and the chooser (§4.5).
6. **Operator frame:** the callsign text stays off the phone banner because it's too small there. The dog tag stands in for it, and the callsign appears in the inspector and the rail.

---

## 7. Mock-up guide
Open `documentation/ux/mockup/index.html`. The toolbar switches Screen (phone / desktop) and Hand (A / B), and runs these demos: select a card, play into A, Protector slide, rival plays, front dies and the column advances, Pick shot, focus/zoom, and the A-vs-B sheet. Interactions: tap or drag a hand card onto a column, long-press or right-click anything, hover on desktop. URL parameters (`?chrome=0&size=phone&hand=A&state=selected|focus|pick|placement|protector|rival|advance|hover|compare&card=<id>&side=you|rival`, plus `rows=3` for the dropped variant) reproduce every screenshot.

| Screenshot (`mockup/shots/`) | Shows |
|---|---|
| `phone-board-handA.png`, `phone-board-handB.png` | Phone board (4 rows, Operator in A row 2), hand A / B |
| `phone-selected-handA.png`, `phone-selected-protector.png` | Selection: valid columns, landing ghosts, `TAKES THE FRONT` |
| `phone-placement-mid.png` | Placement animation mid-slide from the outer edge (3x slow) |
| `phone-protector-slide.png` | Protector after sliding to row 1 (`PLAN` tag) |
| `phone-rival-reveal.png` | Rival card entering from the top edge |
| `phone-focus-zoom.png`, `phone-operator-focus.png`, `desktop-focus-zoom.png` | Inspector with the 512x128 banner (rival unit, your Operator, Protector) |
| `phone-pick.png`, `desktop-pick.png` | Pick tracer skipping the frontline |
| `phone-hand-compare.png`, `desktop-hand-compare.png` | A vs B at true size and enlarged, with A's crop window |
| `desktop-board-handA.png`, `desktop-board-handB.png` | Desktop board |
| `desktop-hover-zoom.png` | Desktop hover zoom in place |
| `phone-3rows-reference.png`, `desktop-3rows-reference.png` | The dropped 3-row variant, for reference only |

---

## 8. Questions for the head
1. **Rival plans and your plays:** (a) show them **in their landing slot**: your card face-up with `PLAN`, the rival's as an `INCOMING` back. No staging strip. **Recommended**, because a staging strip doesn't fit on the phone with 4 rows. (b) A staging strip at each column's outer edge (card-system.md §4.2). This shrinks the phone banners to about 160x40.
2. **Hand card:** (a) option A, a crop from the 2:3 column. **Recommended.** (b) Option B, the full banner as a stripe. (c) A on the phone, B on desktop.
3. **Operator mastery frame:** (a) a brass frame plus a camo band on the outer edge, whose pattern is the mastery tier. **Recommended:** it's visible on the board at phone size, and the art stays the player's own. (b) Camo applied over the whole banner art (a stronger look, but it hides the art). (c) Frame only, with camo shown in the inspector and profile only.

---

## Implementation notes (kc-board, Mechanics Developer, 2026-11-05)
Built in `source/project-killingcard` to the head's decisions (3 columns x 4 rows per side, entry from the outside, frontline next to the objective, Protector slides to row 1, PLAN / INCOMING in the landing slot with no staging strip, hand option A, Operator brass frame + camo band, animation only on focus / placement). The rules layer is unchanged.

| Piece | Where |
|---|---|
| Grid numbers (§2): banner size from the height, columns, hand row, rails | `scripts/ui/board_metrics.gd` (phone 176x44 at x 300/496/692; desktop 256x64 at 232/512/792) |
| Column: rival rows 4..1, objective tile, your rows 1..4; targets, landing ghost, tap snapping, motion | `scripts/ui/lane.gd`, `scenes/match/Lane.tscn` |
| Banner (4:1, icon slots, spine, frontline, PLAN, Operator frame, INCOMING back, reticle, shimmer) | `scripts/ui/banner_view.gd`, `assets/shaders/banner_shimmer.gdshader` |
| Objective tile + Field chips (model B, OVERRUN tab when `overrun_risk`) | `scripts/ui/objective_tile.gd` |
| Hand option A (2:3 crop, cost hex, one-line name, stat row) | `scripts/ui/hand_area.gd` |
| Rails (score, Operator + loadout, deck / used; UNDO, MENU, PREVIEW, rival hand + intel, killfeed, Supply, READY) | `scenes/Match.tscn`, `scripts/ui/match_screen.gd` |
| Inspector: 512x128 banner above the card, generic info mode (objective, INCOMING back, rail boxes, Fields with the plain-words Overrun rule) | `scripts/ui/card_inspector.gd`, `match_controller.gd` |
| Pick / Flank tracer down the gutter + one-time callout; FIELD OVERRUN / DESTROYED / REPLACED callouts | `scripts/fx/feedback_director.gd`, `match_controller._board_callout` |
| Desktop hover zoom (512 px, 120 ms) | `scripts/ui/board.gd` |

**BannerArt data path.** `scripts/data/banner_art.gd` (`BannerArt`: master texture or `image_path`, `banner_y`, `portrait_x`, tags, licence fields) and `scripts/ui/art/banner_art_db.gd` (`BannerArtDB.banner_texture(id)` / `portrait_texture(id)`, AtlasTexture crops of one master). Lookup: `res://data/banners/<art_id>.tres` (drop the head's banners here) → optional git-ignored `res://assets/licensed/mw3/manifest.csv` (columns `file, kind, chassis|card, banner_y?, portrait_x?, title?`; kc-cod) → placeholder cut from Killstreak's card art with per-card crop centres → generated gradient + silhouette (new chassis such as the Fields). Art id = card id (Operator: its primary weapon).

**Deviations.** Card art never rises 14% when selected (the hand row has no spare height; the selected card gets the amber frame and the shimmer instead). Card names on the board and in the hand are still Killstreak's (`Shieldman`, not `Protector`: data renames belong to the rules/data task). Column objective words: `YOURS / RIVAL / CONTESTED / OPEN`; the range word sits on the tile's top-right and gives way to a rival Field chip. The forecast (PREVIEW) cards now stack 4 lines over the objective tile. The killfeed lives in the right rail on every screen (names may shorten to 10 characters there).

**QA.** `tests/test_board_columns.gd` (metrics vs this spec, rows and order, crops, drop-in and licensed paths, ghost / Protector slide / snapping, Fields + Overrun, inspector banner, QA bridge). Web builds opened with `?qa=1` publish `window.kcQa` (`scripts/qa/qa_bridge.gd`) so Playwright clicks real rects. Dev screenshots: `tests/tools/shot_match.gd` (xvfb).

**kc-polish (head's answers, 2026-11-05).**
- B1: while a Protector is selected, your cards in each valid column preview their shift back one row, so its row-1 ghost never covers your front card.
- B2: the objective tile is taller (phone 66 px, desktop 92 px; the space comes from tighter row, mid and hand gaps, so banners stay 176x44 / 256x64). It has three bands: the rival Field chip on top, then the range and control words, then your Field chip at the bottom. Firefight step labels (FIRST SHOT / MAIN) now show at the column's top edge, not over the tile.
- B3: the Operator camo is Base for both sides.
- Display names: Shieldman is now Protector, and the two elites are Commander and Ace. Their ids are unchanged. The ★ is drawn as a gold star plate on the banner and the hand card, because the UI fonts have no ★ glyph.
- The selected hand card rises 14%.
- QA: `?qa=1&seed=N` replays a run seed.

**kc-board2 (2026-11-05):** the screen layout (§2, hand row, rails, killfeed) is replaced by layout v2: see `board-layout-v2.md` and its implementation notes. The card, banner, column and interaction rules here still apply.

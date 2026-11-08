# Calling Card Tiles, Part 3: banners + emblems

*Board task `cct-emblems` · project `cctiles` · Sr Game Designer · 2026-11-08*
*Follows [Part 1](concepts.md) and [Part 2](concepts-depth.md). The head's idea: "Make a better tile-laying game by mixing calling cards with emblems. With only calling cards it often leaves dead squares because of their 4:1 ratio, but emblems could be triggers in the middle. Maybe 2x2?" Original art only. Call of Duty is named as inspiration, nothing more.*

**TL;DR**
- **The head is right about dead cells.** On an 8×8 board, random banner play jams with **21% of the board dead** (13.7 of 64 cells), and 99.7% of games strand at least one cell. Careful play still leaves 5.6%. On a 7×7 or 9×9 board, a perfect fill is impossible whatever you do.
- **2×2 is the right emblem size, but not as a filler.** A loose 2×2 barely helps: dead cells go from 21% to 17%. The pockets a banner leaves behind are mostly slivers 1 cell wide, and a square can't fit into those. What the 2×2 does well is be a **hub**: it has 8 border cells, art you can read on a phone, the same area as a banner, and it makes 6×6 and 10×10 boards fillable (a "pinwheel").
- **One rule fixes the dead cells: the patch.** An emblem can also be *pinned over any enclosed gap of 1–4 cells*. With it, dead cells fall from **17% to 2%** in random play and to **0%** in careful play. It also gives players a choice: use the emblem as a hub, or spend it as a patch.
- **Mix:** about **10 banners to 6 emblems** on an 8×8 board (64 cells, an even number of emblems; the parity rule below explains why that matters). Use 12:4 if banners must dominate.
- **Prototype: Rally Point.** It is a tile-laying game where emblems score the banners around them once they are surrounded, with a solo daily and a 2-player mode.
  - It showed the best skill signal of any game we have tested: a 1-ply planner beats a greedy player **89–96%** of the time.
  - Mirror matches are balanced: 49% / 42.5%, with 8.5% ties.
  - A turn offers about 40 placements, of which about 7 actually lead to different results.
- **The emblem upgrade also helps Banner Front.** The HQ becomes your emblem, modules become 2×2 emblems, and the patch rule applies. I recommend writing this into its spec rather than building a separate prototype.

> **Terms.** A **banner** is a 1×4 calling-card tile. An **emblem** is a 2×2 square badge tile. A **dead cell** is an empty cell that no remaining piece can ever cover. A **patch** is an emblem pinned over a small enclosed gap. The per-cell symbols that Part 1 called "emblems" (◆●▲✚) are renamed **marks** here to avoid a clash.

---

## 1. The geometry problem

### 1.1 Why 1×4 pieces strand cells

**Theorem (de Bruijn / Klarner).** Banners can tile an a×b rectangle perfectly **only if 4 divides a or b**. The colouring below gives the idea of the proof.

Colour each cell with `(row + column) mod 4`. Every banner, whether it lies horizontally or vertically, covers **exactly one cell of each colour**. A board can therefore be perfectly filled only if all four colours are equally common. On a 6×6 board they are not:

```
6x6, colour = (r+c) mod 4        counts: A 9, B 10, C 9, D 8
  A  B  C  D  A  B
  B  C  D  A  B  C
  C  D  A  B  C  D
  D  A  B  C  D  A
  A  B  C  D  A  B
  B  C  D  A  B  C
```

36 cells is 9 banners' worth, but the colours can never balance. A second colouring, `(row − column) mod 4`, gives the matching restriction in the other direction.

**What a 2×2 emblem does to the colours.** An emblem covers colours c, c+1, c+1 and c+2: one colour twice and two others once. That uneven coverage lets it repair an uneven board.
- On a 6×6, one emblem whose top-left cell has colour A leaves 8 of each colour, and the board becomes fillable.
- Both colourings together predict where that emblem may sit. The search agrees: **only 5 positions** work, the centre and the four corners.

```
Where ONE emblem can sit on 6x6 (top-left corner):
  E . . . E
  . . . . .
  . . E . .
  . . . . .
  E . . . E
```

**The parity lock.** This result surprised me, and it matters for level design. On any board that banners plus 2×2 emblems can fill, **the number of emblems has a fixed parity**. The exact search in `tools/tiling.py` found:

| Board | Banners only | Fewest 1×1 needed | 2×2 counts that allow a perfect fill |
|---|---|---|---|
| 8×8, 4×n, 8×9, 8×10 | yes | 0 | **0, 2, 4, 6** (even only) |
| 6×6, 6×10, 10×10 | no | 4 | **1, 3, 5** (odd only) |
| 5×5, 7×7, 9×9 | no | 1 | none: an odd side needs a 1×1 (the centre) |
| 6×7, 6×9, 7×10 | no | 2 | none |

- **8×8 with a single emblem can never be filled perfectly.** Emblems on 8×8 must come in pairs.
- 6×6 and 10×10 *need* an odd number of emblems. **The emblem in the middle is exactly what makes those boards work**, which is a nice confirmation of the head's instinct.
- Swapping one emblem for one banner always breaks a perfect fill. Players never need to know this, but every puzzle and setup layout has to respect it, so layouts must be checked by the solver.

**The pinwheel.** One centre emblem turns 6×6 and 10×10 into a pinwheel. The four arms are rectangles (2×4 on a 6×6, 4×6 on a 10×10) that banners fill cleanly. A 6×6 has only 2 tilings around its centre emblem. A 10×10 has **1,018**.

```
6x6 pinwheel (< = > horizontal banner, ^ | v vertical banner, E emblem)
  <  =  =  >  ^  ^
  <  =  =  >  |  |
  ^  ^  E  E  |  |
  |  |  E  E  v  v
  |  |  <  =  =  >
  v  v  <  =  =  >
```

### 1.2 How often random play strands cells

`tools/deadcells.py` simulates a hand of 3 pieces with free placement anywhere until nothing fits. It ran 300 games per row; the "tidy" rows used 75, except the 10×10 rows in section C, which used 37.
- The "random" player picks any legal placement.
- The "tidy" player picks the placement that leaves the fewest dead cells.

| Board, pieces | Random: dead cells | Tidy: dead cells | Tidy: perfect boards |
|---|---|---|---|
| 8×8, banners only | **13.7 (21%)** | 3.6 (5.6%) | 39% |
| 7×7, banners only | 10.9 (22%) | 7.6 (16%) | 0% (theorem) |
| 10×10, banners only | 19.3 (19%) | 8.1 (8%) | 0% (theorem) |
| 8×8, 25% 2×2 emblems (loose) | 11.1 (17%) | 5.0 (7.8%) | 17% |
| 8×8, 25% 1×2 pieces | 4.2 (6.6%) | 2.4 (3.8%) | 15% |
| 8×8, 25% 1×1 pieces | 0 | 0 | 100%, but **31 turns instead of 13** |
| **8×8, 25% 2×2 emblems + patch rule** (`patch.py`) | **1.4 (2.1%)** | **0.1 (0.1%)** | 98% |
| Gravity wall (Running Bond), banners only | 5.6 (8.7%) | 1.9 (3.0%) | 75% |
| Gravity wall, 25% 2×2 + patch rule | 0.4 (0.6%) | 0 | 100% |

What the dead pockets look like (8×8, banners only, random play, share of all dead cells):

| Bent sliver (L or S shape) | Pocket containing a 2×2 | 1×2 sliver | 1×3 sliver | Single cell |
|---|---|---|---|---|
| 29% | 25% | 19% | 14% | 12% |

**What this means:**
1. **Dead cells are partly a skill test.** A tidy player strands a quarter as many cells as a random one. That is a dial worth keeping, as long as the cost of a dead cell is visible.
2. **A loose 2×2 is a poor filler.** Three quarters of the dead cells sit in slivers 1 cell wide.
3. **A 1×1 fills everything but kills the pace.** It adds about 18 low-value "plug" turns per board.
4. **The patch rule is the cure.** Pinning an emblem over any enclosed gap of 1–4 cells covers every pocket shape above. It costs the emblem's hub value, so there is a real price to pay.

**A typical jam, drawn.** This is random play on 8×8 with banners only, ending with 12 dead cells (·):
```
  ·  ^  ^  <  =  =  >  ·
  ^  |  |  <  =  =  >  ·
  |  |  |  <  =  =  >  ^
  |  v  v  <  =  =  >  |
  v  <  =  =  >  ·  ^  |
  ·  ·  <  =  =  >  |  v
  <  =  =  >  ·  ·  |  ·
  <  =  =  >  ·  ·  v  ·
```
- The bottom-centre 2×2 pocket (rows 7–8, columns 5–6) could take a 2×2 emblem.
- The 1×2 pocket at the top right and the scattered single cells could not. The patch rule would cover them all: the 2×2 pocket as a hub or a patch, and each small gap as a patch.

### 1.3 Pre-placed emblems as anchors

`tools/anchors.py` fixes emblems on the board before play starts, then plays banners only:

| Layout | Can banners fill the rest? | Random dead | Tidy dead | Tidy perfect |
|---|---|---|---|---|
| 6×6, 1 centre emblem | yes (2 tilings) | 22% | 7% | 46% |
| 10×10, 1 centre emblem | yes (1,018 tilings) | 21% | 7% | 14% |
| 8×8, 4-emblem centre block | yes (2 tilings) | 24% | 5% | **66%** |
| 8×8, 1 centre emblem | **no** (parity) | 25% | 10% | 0% |
| 8×8, 2 emblems on a diagonal | **no** | 27% | 15% | 0% |
| 8×8, 4 emblems spread out | **no** | 43% | 33% | 0% |

Pre-placing emblems does not reduce random stranding by itself. A careless position can **double** it, as the spread-out layout shows. Anchors are good for *structure* (where the action is), but every layout has to pass the solver.

---

## 2. Emblem sizes and roles

| | **1×1** | **1×2** | **2×2** |
|---|---|---|---|
| As a **filler** | Perfect: never a dead cell. But it roughly doubles the turns and adds about 18 dull "plug" turns a game | Good: dead cells 17% → 6.6% | Poor alone (21% → 17%). **Excellent with the patch rule** (→ 2%) |
| As a **trigger** ("fires when surrounded") | 4 neighbours, so it closes almost by accident. There is no tension | 6 border cells, a weak hub | **8 border cells, 2 per side.** You can close it with 2–4 banners: a real "last piece" moment |
| As a **scoring centre** | Small: at most 4 contacts | Medium | **Large: up to 8 contacts.** A long side touching it scores 2 cells and an end scores 1, so rotation matters |
| As a **connector** between banners | Joins up to 4 banners | Up to 6 | **Up to 8**, across 4 rows and 4 columns: it ties two crossing lanes together |
| Art and readability | 48pt on phone, which is a cramped icon | A 2:1 shape that is neither a banner nor a badge, and no collection art exists for it | **96pt on an 8×8 phone board.** A real badge you can read, and the "emblem" fantasy |
| Board maths | Breaks the "everything is 4 cells" area count | Breaks it | **Area 4 = one banner.** The scores, deck sizes and board sizes all stay simple |
| What it breaks | Pace, and visual noise | The visual language | Parity: emblem counts must be even on 8×8 and odd on 6×6 / 10×10. Easy for us, invisible to players |
| Fit with CoD's real player card (an emblem beside a calling card) | Exact: on the player card the emblem is as tall as the banner | – | Stylised: a large badge |

**Recommendation: use a 2×2 emblem, with the patch rule.**
- The 2×2 is the only size that is both a satisfying hub and a readable badge. It solves rhythm, because closing an emblem is a beat, and it multiplies decisions, because hub against patch and side against end are both real choices.
- The patch rule solves the dead cells the 2×2 can't fill.
- The 1×1 is better kept as **cosmetic**: your emblem shown at the end of your banner in the inspect view, the way a player card looks.

**Mix ratio.** In Rally Point's solo and versus simulations (smart player), 16 tiles fill an 8×8:

| Banners : emblems | Solo score | Empty at end | Distinct outcomes per turn | Notes |
|---|---|---|---|---|
| 16 : 0 | −10.8 | 17% | 3.2 | nothing to aim at |
| 14 : 2 | 4.6 | 12% | 5.3 | few beats |
| 12 : 4 | 14.7 | 11% | 7.7 | banners dominate; versus has about 10% ties |
| **10 : 6** | 23.8 | 9% | **10.8** | **recommended**: the most decisions while banners stay the majority |
| 8 : 8 | 34.9 | 6% | 13.2 | emblems crowd out the calling cards |

The recommendation is **10:6**, roughly 5 banners for every 3 emblems. If the head wants calling cards to stay clearly the star, use **12:4 (3:1)**. On 10×10 boards use an odd number of emblems (3 or 5).

---

## 3. Four designs

### A. Rally Point: hub tile-laying (solo daily and 2 players)

**Hook:** "Lay your calling cards around emblems. When an emblem is surrounded, it rallies, and every banner touching it scores."

**Components:**
- An 8×8 board.
- A stack of 16 tiles: **10 banners and 6 emblems** (12 and 4 in solo).
- Every tile has one of 4 **suits** (original colours and shapes). In 2-player, the banners you place carry your colour frame.

**Turn:** take 1 of the 3 face-up tiles and place it.
- **Banner:** any 4 empty cells in a line, horizontal or vertical.
- **Emblem:** either a **hub** (any empty 2×2) or a **patch** (pinned over any enclosed gap of 1–4 cells). A patch never rallies, but its cells count as filled.

**Rally:** when every on-board cell around a hub is filled (8 cells, 2 per side; the board edge counts as filled), it fires.
- Each border cell covered by a banner gives that banner's owner **1 point**, or **2** if the banner's suit matches the emblem.
- A long side flush with the emblem scores 2 cells; an end scores 1.
- **2-player:** whoever completes the rally gets **+1**.
- The rally animation is the beat: every touching banner flashes and its points pop on each segment.

**End:** the stack is empty, or nothing fits after one market refresh.
- Each un-rallied hub scores its current contacts at face value (no suit bonus, no +1).
- **Solo:** +5 for a perfect board, −1 per empty cell.
- **2-player:** the most points wins. A tie goes to the player with more rallies completed.

**Worked example (2-player).** Lower case is P1, upper case is P2. ◆ and ● are suits. The ◆ emblem `E` sits at rows 3–4, columns 3–4 (1-based). Two cells, `?`, are still open on its right.

```
      1   2   3   4   5   6   7   8
 1    .   .   .   .   .   .   .   .
 2   a◆  a◆  a◆  a◆   .   .   .   .      a = P1 banner, suit ◆ (covers 2 of E's top cells)
 3    .  B●  [E◆  E◆]  ?   .   .   .      B = P2 banner, suit ●, vertical (2 of E's left cells)
 4    .  B●  [E◆  E◆]  ?   .   .   .
 5    .  B●  C◆  C◆  C◆  C◆   .   .      C = P2 banner, suit ◆ (2 of E's bottom cells)
 6    .  B●   .   .   .   .   .   .
```

It is P1's turn, and P1 holds a ◆ banner.
- **Option 1: close it.** Stand the banner vertical in column 5, rows 1–4. That covers both `?` cells and E rallies.
  - P1 scores a (2 × 2 = 4) + the new banner (2 × 2 = 4) + closer (+1) = **9**.
  - P2 scores B (2 × 1 = 2) + C (2 × 2 = 4) = **6**. Net +3 for P1.
- **Option 2: half-close.** Lay the banner horizontal in row 3, columns 5–8. That covers one `?` for 2 points pending and opens a new lane on the right.
  - But P2 can then close E with any piece in row 4, for +1 and their own 6.
- **Option 3: wait.** Build a second ◆ hub elsewhere, and hope P2 is forced to close E later.

Closing an emblem always feeds your opponent too. That makes "who closes, and when" the heart of the game, much like completing features in classic tile-laying games, but the hub geometry here is our own.

**Depth sources:**
- Hub against patch: every emblem is a scoring centre or a hole-fixer.
- Side-on against end-on: a long side scores 2 cells on one emblem; end-on scores 1 but keeps the other end free to reach a second emblem.
- Suit matching.
- Closing tempo.
- Hate-placing: covering an opponent's open contact with a mismatched suit.
- Dead cells: they block rallies, so a stranded cell beside a hub kills its rally unless someone patches it.

**Simulation (`tools/rally.py`).**

| Setup | Result |
|---|---|
| Solo 12:4: random / greedy / smart | **−8 / 7 / 17** points |
| Solo 12:4 with end-of-game scoring: random / greedy / smart | −1 / 10 / 20 points. The perfect-board rate for the smart player is 9–19% (an aspiration) |
| Versus 12:4, without end-of-game scoring | **43–53% ties**. Too few rallies, so the end-of-game rule is required |
| **Versus 10:6 + end scoring, smart vs greedy** | **96% and 89%** wins, as first and as second player |
| Greedy vs random | 51% / 42% / 7% ties. Immediate points barely matter; planning does |
| **Smart mirror** | **49% / 42.5% / 8.5% ties**. Balanced, with a slight first-seat edge to watch |
| Decision density | 38–42 legal placements per turn and 6.6 distinct outcomes (smart evaluation). The best option beats the median by 1.2 points per turn |
| Dead cells at the end, smart mirror | 8.6%, with emblems used as patches about once a game |

- "Smart" is a 1-ply player: immediate points, minus new dead cells, plus a value for the open contacts it owns around hubs not yet rallied.
- Games ran 100–200 per row.

**Phone fit: excellent.**
- An 8×8 board at 48pt cells, with emblems at 96pt and the 3-tile market under the board in portrait (beside it in landscape).
- Long press on an emblem previews its rally: who gets what if it closed now.
- **Session:** 16 placements, about 5–7 minutes.

### B. Pinwheel: daily logic puzzle (emblems are the goals)

**Hook:** "Fill the board with banners. Each emblem tells you how many banners touch it and how many point at it."

**Components:**
- A **10×10** board with one centre goal emblem on weekdays, or 3 emblems at solver-checked positions on weekends.
- 2–4 **givens**: pre-placed, greyed-out banners.
- A tray of exactly enough banners: 20 or 21. Every banner has the same geometry and is skinned with your cards.

**Clue:** each emblem shows **Touch** (how many different banners touch it) and **Point** (how many meet it end-on).

**Turn:** lay banners anywhere. Undo is free. Cells that can no longer be covered **glow red at once**, so the dead-cell geometry teaches itself.

**Win:** every cell is filled and every clue is exact. The generator guarantees the solution is unique. Stars are awarded for solving without hints and under the par time.

**Worked example.** Centre emblem, clue **Touch 7 · Point 5**. The 4 givens (computed by `tools/pinwheel.py`):

```
  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·
  ·  ·  ·  ·  ·  ·  ^  ·  ·  ·
  ^  ·  ·  ·  ·  ·  |  ·  ·  ·
  |  ·  ·  ·  ·  ·  |  ·  ·  ·
  |  ·  ·  ·  E  E  v  ·  ·  ·        E = goal emblem (Touch 7, Point 5)
  v  ·  ·  ·  E  E  ·  ·  ·  ·
  ^  ·  ·  ·  ·  ·  <  =  =  >
  |  ·  ·  ·  ·  ·  ·  ·  ·  ·
  |  ·  ·  ·  ·  ·  ·  ·  ·  ·
  v  ·  ·  ·  ·  ·  ·  ·  ·  ·
```

These clues and givens allow exactly one solution:

```
  <  =  =  >  ^  ^  <  =  =  >
  <  =  =  >  |  |  ^  ^  ^  ^
  ^  ^  ^  ^  |  |  |  |  |  |
  |  |  |  |  v  v  |  |  |  |
  |  |  |  |  E  E  v  v  v  v
  v  v  v  v  E  E  <  =  =  >
  ^  ^  ^  ^  ^  ^  <  =  =  >
  |  |  |  |  |  |  <  =  =  >
  |  |  |  |  |  |  <  =  =  >
  v  v  v  v  v  v  <  =  =  >
```

- Solving starts from the clue. "Point 5" means five banners meet E end-on, so most of E's border must be banner ends, and the player tests that against the givens. A human-style grader (see the next step below) will rate how hard each daily is.

**Simulation (`tools/pinwheel.py`).**

| Layout | Tilings | Clues alone unique? | Givens for a unique puzzle | Banners the player places |
|---|---|---|---|---|
| 6×6, centre emblem | 2 | no | 1.0 | 7 (too small: a tutorial puzzle only) |
| 8×8, 2 emblems on the left edge | 27 | 17.5% | 1.4 | 12.6 |
| **10×10, centre emblem** | **1,018** | 0% (median 368 tilings left) | **3.4** | **20.6** |
| 10×10, 3 emblems | 52–123 | 0–7.5% | 1.3–1.9 | about 20 |

**Depth sources:**
- Counting clues against geometry: Point forces orientation and Touch limits how many banners can crowd the emblem.
- Pinwheel arms and colouring parity, which experienced players learn to see.

**Next step:** a difficulty grader (a human-style deduction solver) to sort the dailies. The tiling enumerator already runs in milliseconds.

**Phone fit:** good. A 10×10 board at 39pt cells is the maximum. Placing banners by drag-and-snap with a ghost preview works; a zoomed view is optional.
**Session:** 3–6 minutes.

**Collection hook:** the goal emblem is **the day's prize**. Solve the puzzle to earn that emblem (original art). This gives the game its own chase.

### C. Banner Front: HQ and Modules (a Neuroshima-style battle)

Changes to Part 2's Banner Front:
- **Board:** 8×8 (was 8×7).
- **HQ:** each player's HQ is a **2×2 emblem**, *your* emblem, centred on your back row. It has 10 HP (the first player has 11), a Blade on all 8 segments, and initiative 0.
  - It replaces the 1×4 Command banner. A square HQ reads as "home" at a glance, and it gives the enemy 8 segments to aim at instead of 10.
- **Modules:** 3 of the 20 tiles in the deck become **2×2 module emblems**.
  - **Relay:** friendly banners touching it get +1 initiative.
  - **Armoury:** Guns on friendly banners touching it deal +1 damage.
  - **Bulwark:** friendly segments touching it ignore Guns.
  - Modules have 2 HP and no attack.
  - Buffing adjacent units with a module is a genre convention. The square hub with 8 contacts is our twist.
- **Patch:** a module may be pinned over an enclosed gap of 1–4 cells. It then has 1 HP but keeps its buff.
- **Battle trigger:** "board full" now means that neither a banner nor a module fits anywhere.

**Worked example (the bottom of the board, P1's side):**

```
       1   2   3   4   5   6   7   8
 5     .   .  R→  R→  R→  R→   .   .      R = Rifles, Guns on its upper long side
 6     .  [A   A]  .   .   .   .   .      A = Armoury module (touches R's cell in column 3)
 7     .  [A   A] [H   H]  .   .   .      H = your HQ emblem
 8     .   .   .  [H   H]  .   .   .
```

- The Armoury touches both the Rifles and the HQ. The Rifles now fire four 2-damage shots up their lanes.
- The enemy's best answer is a Lancer whose Heavy Gun (2 damage, initiative 3) points at the Armoury. The Armoury has 2 HP, so the Lancer kills it before the Rifles fire at initiative 2, and the buff never lands.
- Modules become the targets players fight over, which is exactly how the genre gets its depth.

**Simulation (`tools/front_geo.py`).** Geometry and pacing only; the battle balance still needs the `front.py` port.

| HQ layout, 8×8 | Banner-only tilings | Dead at board-full (random) | With 15% modules + patch |
|---|---|---|---|
| Centred on back rows | 1 | **35%** | **2.8%** |
| Off-centre | 0 | 25% | 1.7% |
| Corners | 0 | 22% | 1.8% |

- Without patches, about a third of the board can be dead when the board-full battle fires. That makes the battle trigger feel random.
- With patches, board-full means *actually full*. That makes the board-fill timing (Part 2's depth source 5) a skill decision rather than luck.

**Phone fit:** as in Part 2. HQ and module icons get 96pt badges, which helps readability. **Collection hook:** your emblem is your HQ, so your identity sits on the board.

### D. Keystone Wall: the Running Bond fix

Part 1's gravity wall, with emblems added as **keystones**.

**Components:**
- An 8×8 wall.
- 16 tiles: 12 banners (cells carry the ◆●▲✚ marks) and 4 keystones, each showing one mark.

**Turn:** as in Part 1.
- A keystone needs at least one of its bottom cells supported.
- **Patch:** a keystone may instead be pinned over an enclosed hole of 1–4 cells, such as a gap under an overhang. This replaces Part 1's odd "mason's insert" rule.

**Lock (the trigger):** a keystone **locks** when both cells above it and its left and right neighbours are filled (a wall edge counts as filled).
- On locking, it scores 1 per touching banner cell, or 2 if that cell's mark matches the keystone.
- The usual Part 1 scores still apply.

**Worked example:**

```
          1    2    3    4    5    6    7
 row 4    ✚    .    .    .    .    .    .
 row 3    ◆    ?    ?    ?    ?    .    .      the next banner goes across columns 2–5
 row 2    ●   [K◆   K◆]  ◆    ●    ▲    ▲      row 2, columns 4–7: one banner
 row 1    ▲   [K◆   K◆]  ▲    ▲    ●    ✚      row 1, columns 4–7: one banner
```
*Column 1 is one vertical banner (▲●◆✚ from the floor up). K is a keystone with mark ◆.*

- Lay `◆◆●▲` at 0° across row 3, columns 2–5. It covers both cells above K, both sides are already filled, so **K locks**.
- Its score, one touching cell at a time:
  - left ▲ and ● score 1 + 1;
  - right ▲ scores 1 and ◆ scores 2;
  - above, ◆ and ◆ score 2 + 2.
  - That is **9 points** from one placement.
- The alternative is to hold K open for a banner with more ◆ marks: the same "now or later" tension as Part 1, but now with a visible target.

**Simulation (`tools/patch.py`, gravity section):**

| Gravity 8×8 | Dead cells (random) | Dead cells (tidy) | Full walls (random / tidy) |
|---|---|---|---|
| Banners only | 8.7% | 3.0% | 29% / 75% |
| 25% keystones, no patch | 8.3% | 4.3% | 16% / 32% |
| 25% keystones + patch | **0.6%** | **0%** | **94% / 100%** |

- **Decision density:** 9–11 placements per turn. Gravity narrows the choices, and that suits a calm solitaire.
- **Phone fit:** excellent. It is the simplest of the four.
- **Verdict:** a **rules patch for Running Bond**, not a new game.

---

## 4. Collection hook: emblems and calling cards together

In Call of Duty a player's identity is an **emblem plus a calling card**. Our game can make that pair the centre of collecting.

| Hook | What it is | Power? |
|---|---|---|
| **Player Card loadout** | You pick 1 emblem and 1 calling card as your identity. The emblem is your HQ (Banner Front) and the face of your hubs (Rally Point). The card is your featured banner. Opponents long-press to inspect both | Cosmetic |
| **Pairings** | Original-art emblem and banner pairs designed for each other. When a paired banner touches its emblem as it rallies, a unique animation plays and a "Pairing" stamp goes into your Pairing Book. The book shows silhouettes with unlock hints | Objective only |
| **Emblem orders** (sets) | Emblems come in themed orders of 4, and an order is tied to a banner series. Complete the order and the series to unlock a board theme and frame | Cosmetic |
| **Emblem ranks** | An emblem gains a star each time it rallies or locks (1 to 5 stars, shown on its frame). "Rally with 20 different emblems" rewards breadth | Cosmetic |
| **Daily prize emblem** (Pinwheel) | Solve the day's puzzle to earn its goal emblem. This is a chase that is earned *in this game* | Cosmetic |
| **Rally mosaic** | A finished Rally Point board is a mosaic of your banners around your emblems, and you can share it as an image | Cosmetic |
| **CoD loop (hypothetical link)** | "Unlock an emblem in CoD → it becomes a hub face here. If you also own the matching calling card, its Pairing slot lights up." The set screen shows "Order of the Wolf: 2 of 4 emblems, 3 of 5 banners" | — |

**Why emblems make collecting more exciting than banners alone:**
- **A second axis.** "I have this card but not its emblem" makes a gap that is easy to read, and gaps are what drive collecting.
- **Pairings turn two collections into combos.** Each new unlock can complete something you already own.
- **The emblem is the hero of every rally.** The square badge at 96pt gets the big animation, so a newly unlocked emblem is *seen*.

**Fairness:**
- An emblem's gameplay (its suit, its module type) comes from a balanced neutral table that is hashed from its ID, as in Part 1.
- Ranked play uses neutral sets, and your collection only skins them.
- A casual mode could let orders pick balanced sidegrade module sets. That is breadth, not power.

---

## 5. Simulation summary

| Design | Board | Dead cells (typical play) | Placements per turn | Skill signal | Session |
|---|---|---|---|---|---|
| Banners only (baseline) | 8×8 | 21% random / 5.6% tidy | 27–29 | tidy play quarters the dead cells | — |
| **A. Rally Point** | 8×8 | 8.6% (smart mirror; some is end-of-stack) | **38–42 (about 7 that differ)** | **smart beats greedy 89–96%** | 5–7 min |
| B. Pinwheel | 10×10 | 0 by design (dead cells = mistakes, shown red) | dozens; the uniqueness generator works | logic puzzle; grader still needed | 3–6 min |
| C. Banner Front HQ | 8×8 | 35% → **2.8%** with patch | as Part 2 | Part 2's battle results still apply | 8–10 min |
| D. Keystone Wall | 8×8 gravity | 8.7% → **0.6%** with patch | 9–11 | as Part 1 | 8–10 min |

**How to run the tools** (standard library only, from `studio/concepts/calling-card-tiles/tools/`):
- `python3 tiling.py`: exact tileability and the parity lock (about 1 minute).
- `python3 deadcells.py 300`: stranding rates (about 30 seconds).
- `python3 anchors.py 300`: pocket shapes and anchor layouts.
- `python3 patch.py 300`: the patch rule, free and gravity boards.
- `python3 rally.py 200`: Rally Point solo and versus (about 1 minute).
- `python3 pinwheel.py 40`: puzzle layouts, uniqueness and givens.
- `python3 front_geo.py 300`: Banner Front HQ geometry.
- `python3 draw.py`: the ASCII diagrams in this document.

The AIs are random, greedy or 1-ply heuristics, so the numbers are directional.

---

## 6. Recommendation

**Prototype Rally Point next.**
- It is the head's "better tile-laying game", built directly around his idea: the emblems sit in the middle as triggers.
- It has the strongest skill signal we have measured.
- Its rules fit on one card.
- One ruleset gives both a solo daily (a seeded stack, shared by everyone) and a 2-player game.
- Its AI is cheap: the 1-ply "smart" player is about 40 evaluations per turn in GDScript.

**Alongside it:**
- Write **emblem HQ, modules and the patch rule into the Banner Front spec**. This is a spec change, not a new prototype.
- Keep **Pinwheel** as the daily-puzzle mode. It reuses the board and the tiling solver.
- Fold **Keystone Wall** into Running Bond as its rules fix.

**1-week Godot 4.4.1 prototype (Rally Point):**

| Day | Content |
|---|---|
| 1 | `RallyBoard.tscn`: an 8×8 `Control` grid that adapts to portrait and landscape. `tile_def.tres` resources for kind, suit and art. `board_state.gd` tracks cells to piece ids, with typed arrays. |
| 2 | Placement: a market of 3, drag or tap to place, rotate by button, R key or two-finger twist. A ghost preview. Hub or patch is chosen automatically by where an emblem is dropped. Dead cells glow red. |
| 3 | `rally_resolver.gd`: rally detection, per-segment score popups, the rally animation as a signal-driven tween, end-of-game scoring. |
| 4 | Right-click / long-press inspect on every tile. For a banner: the upright card, suit and series. For an emblem: a rally preview ("if it closed now: you +6, them +4"). A score breakdown panel. |
| 5 | A 2-player hot-seat mode and a smart AI on a worker thread (random, greedy and smart difficulties). A seeded solo daily. |
| 6 | Collection mock: an original-art starter set (24 banners, 8 emblems in 2 orders), a Pairing Book with silhouettes, and the fake unlock feed from Part 1. |
| 7 | Web export, an iPhone portrait and landscape pass, a PC pass, QA, and a balance log (a CSV of seat, score, rallies, patches and dead cells). |

---

## 7. Questions for the studio head (recommended option first)

1. **What do we prototype next?**
   - **(a) Rally Point (recommended).** The hub tile-laying game, with a solo daily and 2 players.
   - (b) Banner Front with the emblem upgrade.
   - (c) Pinwheel daily puzzle.
2. **Emblem size and the hole rule:**
   - **(a) 2×2 emblems with the patch rule (recommended).**
   - (b) 2×2 emblems with no patch; dead cells just cost points.
   - (c) Add 1×1 "pins" as a separate filler piece.
3. **Mix on an 8×8 board:**
   - **(a) 10 banners : 6 emblems (recommended).** The most decisions.
   - (b) 12 : 4, so calling cards clearly dominate.
   - (c) 8 : 8.
4. **How much may collected emblems affect play?**
   - **(a) Art, Pairings and ranks only. Gameplay comes from a neutral table (recommended).**
   - (b) In casual and solo modes, emblem orders unlock balanced sidegrade module sets.
   - (c) Collected emblems carry unique abilities everywhere. This is not recommended, because it is pay-to-win.

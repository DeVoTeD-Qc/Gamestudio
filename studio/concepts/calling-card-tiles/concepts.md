# Calling Card Tiles: concept exploration

*Board task `cct-ideas` · project `cctiles` · Sr Game Designer · 2026-11-06*
*A side exploration, separate from KillingCard. It borrows only the 4:1 banner shape. None of KillingCard's rules are reused, and every concept works with original 4:1 art.*

**TL;DR.** I recommend **Running Bond** for the first prototype. It is a 10-minute wall-building solitaire: you lay calling-card tiles in a brick bond, and your collection becomes the wall. Of the seven concepts it has the strongest collection pull, and it is the "tiling game" the head asked for. It plays upright in portrait and in landscape, and its daily variant is cheap to add. **Pivot** is a rotation-based daily puzzle, and **Crosswise** is a versus game where Landscape plays against Portrait. Both simulated well. They are the natural second and third modes of the same app, and all three share one collection.

---

## 1. The shape itself: what a 4:1 tile affords

**Footprint and rotation.** On a unit grid a calling card covers **1×4** cells. That is the straight tetromino, a "bar". Rotating it 90° gives a 4×1 footprint. A rotation of 180° leaves the footprint unchanged but reverses the order of the cells. So when the four cells carry different symbols, all **four** rotations (0/90/180/270) are distinct moves. When they don't, only two are.

**Edges.** Each tile has 2 long sides of 4 segments and 2 short ends of 1 segment: **10 edge segments** in all. That number is a rich hook:
- In a **stack bond** (tiles directly on top of each other), a horizontal tile touches 1 tile above, 1 below and 2 at its ends: 4 neighbours.
- In a **running bond** (each course offset by half a tile, 2 cells), it touches 2 above, 2 below and 2 at its ends: 6 neighbours. Every joint is bridged, so information or effects spread through the wall.
- A **vertical** tile set into a wall of horizontal courses crosses 4 courses on each side. It can touch up to 8 tiles along its long sides plus 2 at its ends: 10 neighbours, one per segment.
- **Insight:** rotation changes a tile's *connectivity*. A horizontal tile is a quiet brick with few neighbours. A vertical tile is a *hub* that ties four courses together. Rotation is therefore a real strategic decision, not just a fitting problem.

**Packing.** These are tiling facts that work as design dials:
- An a×b rectangle can be tiled perfectly by 1×4 bars **only if 4 divides a or b**. This is a known tiling theorem.
  - So 8×8 and 8×9 boards *can* be filled perfectly, and 7×7 and 9×9 *never* can.
  - A daily solitaire wants a fillable board, with "perfect wall" as an aspiration. A versus game wants an unfillable one, so leftover space is the contested resource.
- A 4×4 square has exactly **two** tilings: four rows or four columns. Four cards stacked make a **1:1 picture**. Four cards side by side, rotated, make the same square read the other way.
- **Stacking and overlap.** A tile may overhang a gap only if part of it is supported, which is brick physics. Overlap (one card partly covering another) is possible but hurts readability. I use it nowhere except the real-time idea.
- **Half-offset bonds.** The 2-cell offset is the natural "good brick" rule and is easy to explain: "never put a joint on top of a joint".

**Reading art across tiles.**
- Two horizontal tiles end to end make an 8:1 strip, and four make a 16:1 panorama.
- Original art can be authored as **panorama sets**: 2–4 cards whose edges continue into one picture. Lining them up is a visible, satisfying reward with no explanation needed.
- Calling cards from an existing collection don't line up, so the generic version is the **series**: cards from the same challenge series placed in a line light up as a set.
- Vertical tiles show their art sideways. That is fine on the board, and the **inspect** view (right click / long press) always shows the card upright and full size. This complies with the studio UX rule.

**Device orientation as a mechanic or mode.**
- **Layout only (baseline).** Portrait puts the board on top and the hand or market below. Landscape puts the board on the left and the hand on the right. The rules don't change, which is safe for an iPhone player who rotates mid-game.
- **Board shape as mode.** A tall board (portrait) favours vertical play and a wide board (landscape) favours horizontal play. The simulations below show that board shape is a strong balance lever.
- **The phone as a lens.** If the board stays fixed while the phone turns, tiles of the other orientation now read upright. Crosswise uses this so that each player reads their own banners upright.
- **Gravity follows the phone.** A real-time stacking game can make "down" the real down. It must also offer an on-screen rotate button, because iOS orientation lock is common and players are on PC too.
- **Phone-size check.** An iPhone in portrait is about 390pt wide. An 8-column board gives 48pt cells and 192×48pt tiles, which are comfortably tappable. Ten columns (39pt cells) is the practical maximum.

---

## 2. The collection pillar (applies to every concept)

**Goal:** a big collection of calling cards should feel *exciting* here, so that players get excited about unlocking new ones in Call of Duty. A bigger collection must never be *pay-to-win*.

### 2.1 What a bigger collection gives

| Lever | What it is | Power? |
|---|---|---|
| **Tile variety** | Every owned card is a tile skin and a slot in your personal deck or pool, so more cards mean more varied walls, puzzles and boards. | None. Gameplay values come from a fixed, balanced pattern table (see 2.3). |
| **Series sets** | Cards from the same in-game challenge series (e.g. a 5-card mastery series) form a *set*. Placing set members in a line or block completes **set objectives**: stars, badges, a set frame. | Objective-only. It is never in ranked versus. |
| **Rarity tiers** | Animated or premium cards become **foil tiles**: an animated board tile, a special inspect view, a foil counter on your profile. | Cosmetic. |
| **Panorama sets** | Original-art sets designed to line up into one picture. Some are earned *here*, which gives this game its own chase. | Cosmetic and objective. |
| **Daily "your cards" puzzle** | The daily layout is the same for everyone. Its pieces are skinned with *your* cards, and a bonus objective names one of your series. | Optional bonus stars. |
| **Mastery / prestige tracks** | Each card levels up when used (Bronze → Gold frame), and so does each series. "Played 100 tiles from 40 different cards" badges reward breadth, not depth of spending. | Cosmetic. |
| **Cosmetic flex** | Your **Wall of Fame** (a finished Running Bond wall) is shareable. In versus, opponents can long-press your banners to inspect them. | Cosmetic. |

### 2.2 The loop with Call of Duty (hypothetical account link)

```
Unlock a calling card in CoD (challenge, mastery, battle pass, event)
  → it appears here as a new tile, the next time the hypothetical account link syncs
  → it opens a new set objective, mastery track or daily bonus
  → the set screen shows "2 of 5: Sniper Mastery". The missing cards are silhouettes with their CoD unlock hint
  → the player goes back to CoD with a concrete reason to chase that card
```

Concrete hooks per concept are listed in each concept below, under "Collection pull".

### 2.3 Fairness

- **Starter set without any link.** 48 original-art cards: 12 series of 4, including 3 panorama sets. They cover every gameplay pattern. A player who never links has the whole game.
- **Gameplay is decoupled from art.**
  - A tile's gameplay pattern (its emblems, in Running Bond) is assigned by a deterministic hash of the card ID into a **balanced table of 16 patterns**, each equally common.
  - So 500 owned cards give *variety* and *set goals*, never better tiles. A starter player has every pattern in the game.
- **Competitive modes use a neutral pool.** In Crosswise and any ranked or leaderboard mode, both players' gameplay comes from the same neutral set. Your collection only *skins* your side.
  - The daily leaderboard ranks the base score only. Set and series bonus stars appear on a separate, personal track.
- **Matchmaking** never looks at collection size, only at skill rating (Crosswise).

### 2.4 Pitch framing for Activision (hypothetical; nothing here claims a real partnership or API)

> "Players already earn thousands of calling cards in Call of Duty, but most of them sit unseen in a menu. *Calling Card Tiles* is a short-session puzzle and tactics game where every calling card a player owns becomes a playable tile. Completing a challenge series lights up a set, and finishing a wall of cards is something to show off. That turns the calling-card grind into visible goals, without selling power. The game drives players back into Call of Duty to finish their series, and it stands on its own with original art for anyone who hasn't linked."

**What is speculative:**
- whether calling-card ownership data is accessible at all (no public API is assumed);
- the right to render CoD calling-card art in a separate app;
- account linking, for example via an Activision account;
- brand and age-rating rules for the art;
- whether series metadata (which card belongs to which challenge series) can be exposed;
- whether animated cards can be rendered in Godot at tile size, which may need a static fallback.

Until there is an agreement, every prototype uses **only original art**, and the link is mocked with a fake "unlock feed".

---

## 3. Seven concepts

> **Trademark caution (applies to all).** Each concept uses genre conventions only: falling blocks, sliding puzzles, polyomino placement, deck-building, patience games. None should copy a specific game's rules, names, board layouts, piece sets or trade dress. I name the closest references so we know what to steer away from, not what to copy.

### 3.1 Running Bond: tile-laying solitaire with a daily variant
- **Hook:** "Build a wall out of your calling cards. Bridge every joint, match the emblems, and finish the course."
- **Core loop:**
  - Pick one of 3 tiles from the market.
  - Rotate it (4 ways) and lay it in an 8×8 wall built under gravity.
  - Score emblem contacts, bonds over joints and completed courses.
  - Repeat 16 times.
- **Rotation and orientation:**
  - Horizontal tiles are cheap bricks; vertical tiles are hubs touching up to 10 neighbours, but they leave tall gaps.
  - A 180° rotation reverses the emblem order.
  - The wall itself never rotates, so it reads the same in portrait and landscape.
- **Win:** a score with Bronze/Silver/Gold thresholds and a +10 "perfect wall" bonus. The daily variant uses the same deck for everyone.
- **Session:** 8–10 minutes.
- **The "aha":** a vertical tile dropped into a gap ties four courses together and scores 5+ contacts at once. And the realisation that greedy scoring leaves holes, so the perfect wall needs planning.
- **Risks:**
  - It can feel like "Tetris without falling". The answer is a slower, planned feel with no line clears.
  - Score math must stay legible: show score popups per edge.
- **Originality:** medium-high. Brick-bond physics plus 10-segment emblem contacts plus collection-as-wall is a fresh combination.
- **References (steer away from):** polyomino puzzle-placement games (block-placement phone puzzles, Patchwork-style quilting), Carcassonne-style edge matching. No grid clears, no tetromino set and no quilt buttons from those.
- **Collection pull: very high.**
  - The finished wall *is* a gallery of your cards (the Wall of Fame).
  - Series objectives ("3 Sniper Mastery cards in one course: +4 stars") point straight at CoD unlocks.
  - Foil tiles shimmer, and panorama sets line up across a course.

### 3.2 Pivot: daily rotation puzzle
- **Hook:** "Swing the banners. Get your card to the exit."
- **Core loop:**
  - A 7×7 board holds about 6 bars.
  - Move any bar: slide 1 cell along its length, or **swing it 90° around either end**. A swing sweeps a quarter-disc wedge, which must be empty.
  - Get the key bar (your featured card) onto the exit cell. Par is the solver's optimum.
- **Rotation and orientation:** the whole puzzle is rotation. The board is square, so it fits portrait and landscape identically.
- **Win:** reach the exit, with stars for par, par+3 and any solve.
- **Session:** 2–5 minutes per daily puzzle.
- **The "aha":** "I have to swing *that* bar out of the way, which frees the corner, which lets mine swing round."
- **Risks:**
  - Puzzles need a generator plus a solver. The solver exists (see 4.2), but quality filtering takes time.
  - The wedge rule must be shown clearly: a preview on press, plus the inspect view.
- **Originality:** medium. Sliding-block puzzles are a classic genre; swing-around-the-end with a swept wedge is the twist.
- **References:** sliding-block traffic puzzles. **Avoid** their red-car-to-exit framing and the 6×6 car and truck set.
- **Collection pull: medium.**
  - The key bar and all bars are skinned from your collection.
  - Weekly "series week": that week's dailies feature one series, and owning the series unlocks a bonus 4th star puzzle (extra puzzle, not an easier one).

### 3.3 Crosswise: versus, Landscape vs Portrait
- **Hook:** "One of you can only lay banners across, the other only down. Hold the phone your way."
- **Core loop:**
  - On a 9-row × 8-column board with 11 star cells, players alternate placing bars in their own orientation (turn order 1-2-2-2…).
  - Covering stars scores. A player who can't place is out, and the other player keeps going.
  - Most stars wins.
- **Rotation and orientation:**
  - Your orientation *is* your side.
  - In pass-and-play, the Portrait player holds the phone upright and the Landscape player turns it sideways, so each reads their own banners upright.
  - Board shape is the balance lever: wide boards favour Landscape and tall ones Portrait.
- **Win:** the most stars. A tie goes to the last player to place.
- **Session:** 5–8 minutes.
- **The "aha":** "One down-bar there kills three of their across-moves." It is a pure territory game, learned in 30 seconds.
- **Risks:**
  - It is solvable-feeling at small sizes.
  - First-player advantage needs tuning (see 4.3).
  - A good AI is needed for solo play.
- **Originality:** medium. It is related to classic public-domain combinatorial placement games, here with long bars, star scoring and the orientation-as-identity hook.
- **References:** combinatorial placement games, territory games. **Avoid** Blokus-style corner-touch rules and coloured polyomino sets.
- **Collection pull: medium-low.**
  - Gameplay is a neutral pool, so the pull is pure flex: your banners are on the board for the opponent to inspect, and your card's mastery frame shows on it.

### 3.4 Broadside: tactics
- **Hook:** "Every calling card is a warship 4 cells long. Fire from the long sides, ram with a swing."
- **Core loop:**
  - Each side has 4 bars on a 10×10 sea.
  - Each turn, each bar takes 2 actions:
    - Advance: slide 1 along its length.
    - Swing: pivot 90° about an end. Enemies in the wedge are rammed.
    - Fire: a broadside from a long side hits up to 3 cells out, and a bow shot from an end hits a line of 5.
  - Damage marks edge segments: **10 hit locations per tile**. End segments are weak points that take double damage.
- **Rotation and orientation:** facing is everything. Your broadside is long but you show the enemy a long, hittable side; turning end-on is safe but your fire is weak.
- **Win:** sink the enemy flagship, or 3 ships.
- **Session:** 15–20 minutes.
- **The "aha":** "Swing to ram and *end* the turn showing them only your 1-segment bow."
- **Risks:** heavier rules, an AI cost, and the longest session.
- **Originality:** medium-high. Facing-based tactics on bar units is uncommon.
- **References:** grid tactics (Into the Breach-like readability), age-of-sail facing games. **Avoid** hidden-grid guessing in the Battleship style.
- **Collection pull: medium.** Your fleet is skinned from your cards, and series fleets get a cosmetic flag. Unit types come from the neutral table.

### 3.5 Banner Keep: deck-building roguelite
- **Hook:** "Your deck is your calling cards. Their edges are sockets. Place them so the effects chain."
- **Core loop:**
  - Draw 5 and place 3 on a 6×6 keep. Each card has a **long-side effect** (triggers its neighbours along its sides) and an **end effect** (triggers the tile at its tip).
  - Then resolve chains to generate Guard and Power against the wave's threat.
  - Win the fight, draft a new card, and move on a branching map.
- **Rotation and orientation:** rotation decides *which* neighbours a card triggers. The best turns rotate one card to chain the whole board.
- **Win:** clear 3 acts, with roughly 12 fights.
- **Session:** 25–40 minutes per run, with 5-minute fights.
- **The "aha":** "Rotate the Spark card vertical and its end effect fires the Doubler, which fires everything."
- **Risks:**
  - The genre is crowded, so it needs a lot of content and balance work.
  - Steer clear of KillingCard's lanes and columns.
- **Originality:** medium. Geometry-as-combo-engine deckbuilders exist, but the socketed 10-edge banner is a fresh form.
- **References:** Slay-the-Spire-like run structure. Use the genre conventions only: map, draft, relics renamed and redesigned.
- **Collection pull: high.**
  - Your collection seeds the draft pool's *skins* and unlocks **series relics** (cosmetic-plus-objective).
  - It is *not* power. The draft pool of effects is the same for everyone, so this needs careful handling.

### 3.6 Tilt Stack: real-time stacking
- **Hook:** "Banners fall wherever *down* is, and down is wherever you turn your phone."
- **Core loop:**
  - Banners fall into a 8×12 well.
  - Rotate a banner in flight.
  - Three banners of the same series touching along their long sides **cash in** and vanish. There is no line clear.
  - Every 30 seconds (or on a rotate button) gravity turns 90°, and everything loose slides.
- **Rotation and orientation:** device orientation drives gravity, with a button fallback. Piece rotation is a must.
- **Win:** survive or score in a 3-minute round.
- **Session:** 3 minutes.
- **The "aha":** setting up a stack that cashes in *after* the gravity turn.
- **Risks:**
  - The falling-block **trademark risk is highest** here: no line clears, no tetromino set, no well proportions or terms from that game.
  - Orientation lock, and motion fatigue on phones.
- **Originality:** medium.
- **References:** falling-block puzzles, match-3.
- **Collection pull: medium.** Series matching uses your cards, and more series means more varied colours of series, not power. That is not obviously exciting.

### 3.7 Panorama Patience: solitaire
- **Hook:** "Deal the strips. Rebuild the pictures."
- **Core loop:**
  - Four 1:1 pictures are each cut into 4 strips (4 stacked banners = a square), giving 16 strips dealt into a 4-column tableau, some of them sideways.
  - Move strips to build each picture top to bottom. Turning a sideways strip upright costs one of 3 tokens.
- **Rotation and orientation:** sideways strips are blocked until they are turned. In portrait a picture is a square column, and in landscape there are 4 squares in a row.
- **Win:** complete all 4 pictures.
- **Session:** 5–8 minutes.
- **The "aha":** the moment a picture snaps together.
- **Risks:**
  - It is thin as a game (only 4 ranks per suit) and close to classic patience.
  - It needs art authored as cut squares, so it **can't use existing calling cards** directly.
- **Originality:** low-medium.
- **References:** classic patience games (Klondike-style). Avoid their layout and foundation rules.
- **Collection pull: low for existing cards, high for original panorama sets.** It works better as a reward *inside* Running Bond than as a game of its own.

---

## 4. Paper prototypes of the top 3

The scripts are in `/tmp/claude-0/-home-user/d4346a6d-2ad8-5e6f-975d-207e362015dd/scratchpad/cct/` (`bond.py`, `pivot.py`, `pivot2.py`, `crosswise.py`, `cw2.py`, `cw3.py`). The AIs are simple, either random or 1-ply greedy, so the numbers are directional, not tuned.

### 4.1 Running Bond: rules for a 10-minute playable

**Components:**
- An 8×8 wall grid. Row 1 is the floor.
- A deck of 24 tiles. Each tile has 4 cells, and each cell shows one of 4 emblems: ◆ Diamond, ● Disc, ▲ Peak, ✚ Cross. The shapes are original, and colour plus shape makes them colourblind-safe.
- Each tile also has a **series tag** and art.
- 1 objective card per game.

**Setup:** shuffle the deck, reveal 3 tiles as the market, and reveal 1 objective.

**Turn:**
1. Take one market tile.
2. Choose a rotation:
   - 0° or 180° places it horizontal. 180° reverses the emblem order.
   - 90° or 270° places it vertical. 270° reverses the emblem order.
3. Place it on empty cells inside the wall:
   - **Horizontal:** at least 2 of its 4 cells must sit on the floor or directly on a tile.
   - **Vertical:** its bottom cell must sit on the floor or on a tile.
   - Placing into a covered slot under an overhang is allowed: "mason's insert".
4. Score immediately:
   - **Match:** +1 for each of its edge segments that touches the *same emblem* on another tile. A tile has 10 segments, so 0–10 per tile.
   - **Bond:** +2 if a horizontal tile rests on 2 or more different tiles, so that it bridges a joint.
   - **Course:** +3 for each row this tile completes.
5. Refill the market from the deck.

**End:**
- The game ends after 16 tiles, or when no market tile fits. If nothing fits, refresh the market once first.
- Final scoring:
  - **Perfect wall** (all 64 cells filled): +10.
  - −1 per empty cell that has a tile somewhere above it (a hole).
  - Score the objective. Example: "Two tiles of the same series end to end in one course: +4."
- Medals: Bronze 40, Silver 55, Gold 70.

**Simulation (200 games per row):**

| Emblem kinds | Random player | Greedy player | Perfect walls (random / greedy) |
|---|---|---|---|
| 3 | 35 avg (max 55) | 52 avg (max 74) | 29% / 13% |
| 4 | 32 avg (max 51) | 47 avg (max 66) | 35% / 14% |
| 5 | 28 avg (max 48) | 41 avg (max 61) | 33% / 9% |

**A worked turn (in my head).**
- The floor course is two horizontal tiles: `◆◆●▲ | ▲●●✚`.
- The market offers `●▲▲✚`, `▲▲✚●` and `✚◆◆●`.
- Option 1: lay `●▲▲✚` at 0° on row 2, columns 3–6, above `●▲▲●`.
  - It bridges the joint between columns 4 and 5: Bond +2.
  - It makes 3 same-emblem contacts below (● on ●, ▲ on ▲, ▲ on ▲): +3.
  - Total +5. Its `✚` end now faces column 7, which is ready for a `✚` neighbour.
- Option 2: stand `▲▲✚●` vertical at column 8 on top of the `✚`.
  - It scores +0 now (its bottom ▲ sits on a `✚`), but it becomes a hub: it spans rows 2–5, so up to 4 later tiles in column 7 can each touch it, which is up to +4 more over the game.
- The interesting decision: a sure +5 now against a hub for later. **That is the game.**

**What's interesting:**
- **Greedy scoring halves the perfect-wall rate** (35% to 14%). Point-grabbing leaves holes, so there is a real tension between scoring now and finishing clean, which the +10 / −1 hole rule makes visible.
- 4 emblem kinds is the sweet spot: enough matches to feel rewarding, and enough misses for choices to matter.
- The 180° reversal genuinely matters, because it often flips a +0 into a +2.

**What's broken or needs work:**
- The greedy average is 47 with 4 emblems, so the Gold threshold of 70 is only reachable with planning. That is good, but it needs a smarter-AI check.
- The "mason's insert" rule (placing under an overhang) is physically odd. Test whether players accept it, or require top access instead, which creates more holes.
- Score must be shown *per edge* as it happens: numbers popping on each touching segment. Otherwise players won't understand why they got +5.
- The market of 3 sometimes has no fitting tile late in the game, about 1 game in 8 ending early. The refresh-once rule addresses this.

### 4.2 Pivot: rules for a 10-minute playable (a 3-puzzle pack)

**Components:**
- A 7×7 board with one marked exit cell on the edge.
- About 6 bars. One of them is the gold **key bar**.

**Moves** (one bar per move, any bar):
- **Slide:** 1 cell along the bar's length, into empty cells.
- **Swing:** rotate 90° clockwise or anticlockwise about *either end cell*.
  - The bar sweeps a quarter-disc **wedge**: the 13 cells of the 4×4 quadrant whose centres lie within 3.5 cells of the pivot.
  - The wedge must be empty and inside the board.
  - Pressing a bar previews all its legal swings and their wedges, which satisfies the inspect rule.

**Goal:** any cell of the key bar covers the exit cell. Stars for solving at par (the solver's optimum), at par+3, and for any solve.

**Simulation (BFS solver on random layouts, exit in a corner):**

| Variant | Solvable | Optimal moves (mean / max) |
|---|---|---|
| 6×6, swings only, 3–5 bars | 1–2% | 1 / 1 |
| 7×7, swings only, 4 bars | 8% | 4 / 8 |
| 7×7, swing checks destination only (no wedge), 6 bars, slides on | 85% | 4.5 / 7 |
| **7×7, wedge + slides, 6 bars** | **55%** | **10.8 / 25** (9 of 40 at 12 or more) |
| 6×6, wedge + slides, 5 bars | 23% | 8.0 / 31 |

**What's interesting:**
- **The wedge is the game.** Without it, puzzles are trivial (max 7 moves). With it, there is real depth: 25-move optimal solutions show up on random boards, and filtering for 12 or more yields hard dailies.
- Generation plus solving takes well under a second per layout, so dailies can be generated and verified offline.

**What's broken:**
- **Swings-only is broken.** A swing moves a bar 3 cells, so reachable positions are sparse and almost nothing is solvable. Slides are required.
- The wedge (13 cells) is big on a small board. 7×7 is the minimum size, and 8×8 is worth testing on phone.
- The wedge shape must be taught in the first puzzle. The quarter circle is intuitive once it's shown and impossible to guess before.

### 4.3 Crosswise: rules for a 10-minute playable (best of 3)

**Components:**
- A 9-row × 8-column board, with 11 star cells in a fixed, mirrored pattern for each daily or match.
- Landscape places horizontal bars and Portrait places vertical bars.

**Turn order:** Landscape places 1 bar, then each player places **2** per turn: L, PP, LL, PP…

**Rules:**
- A bar covers 4 empty cells in your orientation.
- Each star it covers scores 1.
- If you can't place, you're out, and the opponent continues until they're stuck too.

**Win:** the most stars. A tie goes to the player who placed last.

**Simulation:**

| Setup | Result |
|---|---|
| 8×8, last-to-move-wins (no stars), greedy vs greedy | **Second player wins 100%**: the 8×8 fills perfectly (16 bars). Broken. |
| 7×10 (wide) vs 10×7 (tall), last-to-move-wins, greedy | Wide board: Landscape wins 100%. Tall board: Portrait wins 100%. |
| 9×9, stars, alternating 1-1 | First player wins 72% |
| 8×8 / 9×9, stars, 1-2-2 | First player wins 60% / 65% |
| **9 rows × 8 cols, stars, 1-2-2** | **50% / 50%** (80 games) |

**What's interesting:**
- The board shape is a powerful and *legible* balance lever: a tall board helps Portrait. Combining 1-2-2 with a slightly tall board balanced the greedy AI.
- That gives the device-orientation fantasy a real rule meaning: in an unranked "home turf" mode, the board takes the shape of whoever holds the phone.

**What's broken:**
- Normal play (last move wins) on fillable boards is decided by parity. Star scoring is required.
- The results come from a 1-ply greedy AI and are noisy. For example, the 10×8 board gave Landscape 70%, which contradicts the shape intuition. Balance needs a proper search AI (MCTS) before anything is called fair.
- With no hidden information and no randomness after setup, it may be solvable at 8×8. Randomised star layouts per match are needed.

---

## 5. Comparison and recommendation

Scores are 1–5 (5 is best). "Proto cost" is 5 when the prototype is cheapest.

| Concept | Genre | Rotation matters | Orientation hook | Fun / aha | Session | Collection pull | Proto cost | Trademark risk | Total |
|---|---|---|---|---|---|---|---|---|---|
| **Running Bond** | tile-laying solitaire + daily | 5 | 3 | 4 | 10 min | **5** | 5 | low | **22** |
| Pivot | daily puzzle | 5 | 2 | 4 | 3 min | 3 | 4 (needs generator) | med | 18 |
| Crosswise | versus | 4 | **5** | 3 | 6 min | 2 | 4 (needs AI) | low | 18 |
| Banner Keep | deck-building roguelite | 4 | 2 | 4 | 30 min | 4 | 2 | med | 16 |
| Broadside | tactics | 5 | 2 | 4 | 18 min | 3 | 2 | low | 16 |
| Tilt Stack | real-time | 3 | 4 | 3 | 3 min | 3 | 3 | **high** | 16 |
| Panorama Patience | solitaire | 2 | 3 | 2 | 6 min | 3 (orig. art only) | 4 | med | 14 |

(Total = rotation + orientation + fun + collection + proto cost.)

**Recommendation: prototype Running Bond first.**
- It is the tiling game the head asked for, and its rules fit on one card.
- The simulation shows real tension between scoring and a clean wall.
- It has the strongest collection pull: the finished wall is literally your collection on display, and series objectives point straight at CoD unlocks.
- It plays the same in portrait and landscape on iPhone and on PC.
- It is the cheapest to build, because it needs no AI and no puzzle generator.

The collection requirement moved Running Bond clearly ahead. Before that, it was tied with Pivot.

Pivot and Crosswise are kept as the **daily** and **versus** modes of the same app. They share the tile renderer, the inspect view and the collection.

### What a 1-week Godot 4.4.1 prototype contains (Running Bond)

| Day | Content |
|---|---|
| 1 | `Wall.tscn` (an 8×8 grid in a `Control`, layout-responsive for portrait and landscape), `tile.gd` (4 emblems, series and rotation as typed data), and `tile_data.tres` resources. 24 original placeholder tiles: 6 series × 4, flat-colour 512×128 banners. |
| 2 | Placement: drag or tap a market tile, rotate with a button, the R key or a two-finger twist, and see a ghost preview with legal or illegal tint. Support rules and the mason's insert. |
| 3 | Scoring with per-edge popups: match, bond, course, holes, perfect wall. A score breakdown panel. |
| 4 | Inspect on right click / long press: the card upright and full size, its emblems, its series, its set progress, and "why this scored". Market refresh and end screen with medals. |
| 5 | Objective cards (3 types). A daily seed (same deck for everyone), with the score stored locally. |
| 6 | A **mock collection link**: a fake "unlock feed" button grants a new card, the set screen shows silhouettes plus unlock hints, and set objectives fire. Foil shader for 2 "animated" tiles. |
| 7 | Web export with an iPhone portrait and landscape test pass, a PC test, a QA pass and a balance log (CSV of placements and scores per game). |

**Out of scope:** real CoD data, online play, Pivot and Crosswise modes, and final art.

---

## 6. Questions for the head (recommended option first)

1. **Which concept do we prototype first?**
   - **(a) Running Bond (recommended).** The tiling solitaire with the strongest collection pull.
   - (b) Pivot daily puzzle.
   - (c) Crosswise versus.
   - (d) Banner Keep roguelite. The biggest scope.
2. **Which orientation leads the design?**
   - **(a) Portrait-first phone layout, landscape and PC fully supported (recommended).**
   - (b) Landscape-first.
   - (c) Orientation as a gameplay mode from day one (Crosswise "home turf", Tilt Stack gravity).
3. **How do we represent the collection link in the prototype?**
   - **(a) A mock unlock feed with original art and fake series (recommended).** It tests the excitement loop with no legal exposure.
   - (b) Let the head import his own 4:1 images as tiles, for a personal test only and not published.
   - (c) No collection features until the core is proven fun.

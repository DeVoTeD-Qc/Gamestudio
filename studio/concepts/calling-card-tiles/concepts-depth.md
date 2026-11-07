# Calling Card Tiles, Part 2: deeper concepts

*Board task `cct-depth` · project `cctiles` · Sr Game Designer · 2026-11-07*
*This follows [Part 1 (`concepts.md`)](concepts.md). The head asked for "something like Neuroshima Hex or Might and Magic: Clash of Heroes or Puzzle Quest: a little more depth even with simple rules".*

**TL;DR.**
- **Banner Front** is a tile-placement battle. Calling-card units have weapons and shields on specific edges, and initiative steps decide who strikes first. It is the deepest idea per rule we have:
  - a 1-ply lookahead AI beats a greedy one clearly;
  - an AI limited to 2 of the 4 rotations wins only about 20%, so rotation is load-bearing;
  - a whole game is about 7 turns each, 8–10 minutes.
- I recommend it **instead of Running Bond as the first prototype**. Running Bond stays as the later daily solitaire mode.
- **Muster** is formation-puzzle combat. It shows an even stronger skill signal (a turn planner wins 75% against a greedy AI), but it runs long and needed a stalemate fix. It is the strong second.

> **Originality rules (all concepts).** I take genre mechanics only. None of these concepts copies any existing game's name, factions, unit list, board shape, icons, terminology or art. Each concept lists what is *borrowed as a genre convention* and what is *new*. Names here are working titles.

---

## A. Banner Front: tile-placement battle (the Neuroshima Hex family)

**Hook:** "Every calling card is a squad four cells long. Guns on one side, a shield on the other. Lay them down, turn them right, and let initiative decide who fires first."

### Rules (one page, 2-minute teach)

**Board and Command.**
- The board is **8 wide × 7 deep**, a square grid. You sit at the bottom, and the opponent sits at the top.
- Each player starts with a **Command banner**: a 1×4 tile in the middle of their back row.
- Command has 10 HP (the first player has 11) and a Blade on every edge, and it strikes at initiative 0.

**Your deck.** 20 tiles, identical for both players in ranked:

| Tile | Copies | Initiative | HP | Edges |
|---|---|---|---|---|
| **Rifles** | 5 | 2 | 1 | a Gun on all 4 cells of one long side |
| **Lancer** | 3 | 3 | 1 | a Heavy Gun (2 damage) on one end, and a Shield on the other end |
| **Brawlers** | 3 | 2 | 1 | Blades on both long sides |
| **Bastion** | 3 | 1 | 2 | Shields on one long side and both ends, and Blades on the other long side |
| **Scouts** | 3 | 3 | 1 | Blades on both ends, and Guns on the 2 middle cells of one long side |
| **Battle order** | 3 | — | — | an instant: a battle happens now |

**Your turn.**
- Draw up to 3 tiles, **play 2 and discard 1**. The first player plays 2 on their first turn too.
- **Place a unit** on any 4 empty cells in a straight line, in any of its **4 rotations**. Placed units never move.

**When a battle happens.**
- When someone plays a Battle order.
- When the board has no empty 4-cell line left anywhere.
- Once more after both decks run out (the final battle).

**Battle.**
- Resolve the initiative steps **3 → 2 → 1 → 0**. All units with the current number strike *at the same time*.
- Damage lands at the end of the step, and destroyed tiles leave before the next step. So a fast unit can kill a slow one before it ever strikes.

**Edge icons.** Each tile has 10 edge segments: 4 per long side and 1 per end.

| Icon | What it does |
|---|---|
| **Gun** | Fires straight out from that segment and hits the first tile in the line. A friendly tile blocks the shot. |
| **Heavy Gun** | A Gun that deals 2 damage. |
| **Blade** | Hits the enemy tile touching that segment. |
| **Shield** | Stops Guns arriving at *that* segment. Blades ignore Shields. |

- **One hit per target:** each attacker hits each enemy tile at most once per step, using its best hit.
- So a long side *spreads* its damage over up to 4 different targets, and an end *concentrates* it.

**Win.** Destroy the enemy Command. Otherwise, the player whose Command has more HP after the final battle wins. A tie goes to the side with more total unit HP left.

### Where the depth comes from

1. **Tempo against exposure.**
   - Hold or play your Battle order?
   - A board-fill battle comes *after* the other player's reply.
   - A Battle order cashes in your advantage now, before they can answer.
2. **Facing.**
   - A long side gives coverage (4 lines of fire), but it also shows the enemy a 4-segment target.
   - End-on is a small, shielded profile, but it has only one line of fire.
   - Every placement trades these off.
3. **Initiative races.**
   - Scouts at 3 kill Rifles at 2 before they shoot.
   - A Bastion at 1 survives on 2 HP and Shields, and then blades whatever is touching it.
   - Ordering threats across the steps is the core skill.
4. **Lines and blocking.**
   - Your own tiles block your own Guns.
   - A vertical tile spans 4 rows, so it cuts four enemy lines of fire at once and opens four of yours.
5. **Board-fill timing.** The board fills in about 3 rounds. Taking the last free 4-cell line triggers the battle on your terms, and leaving one open keeps it off.
6. **The discard.** Every turn you give up one of 3 tiles.

### How the 4:1 shape and rotation matter

- 10 edges with asymmetric icons give **4 genuinely different rotations**.
- Long against short sides gives spread against focus, and big target against small profile.
- A 1×4 crosses 4 lanes, so one vertical placement changes the fire geometry of four rows.
- The simulation confirms this: restricting an AI to 2 of the 4 rotations drops its win rate from about 50% to **19–20%** (150 games per seat).

### Borrowed against new

- **Borrowed (genre conventions):**
  - draw 3, play 2, discard 1;
  - placing tiles on a shared board;
  - units that never move;
  - initiative-stepped simultaneous battles;
  - a battle trigger tile, a board-full trigger and a final battle;
  - an HQ-style base.
- **New:**
  - 1×4 units on a *square* grid;
  - 10-segment edge icons;
  - the once-per-target rule, which makes spread against focus a real choice;
  - friendly line blocking across lanes;
  - 4-way rotation on asymmetric bars.
- **Avoided:** hex boards, faction names and armies, the reference game's unit roster and icon set, its terminology for tile types, and its trade dress.

### Collection pillar

- **Your calling cards skin your units.** You choose which of your cards represents each tile type; one card can be the art for your Rifles, another for your Lancer.
- **Your Command banner is your favourite card** and is displayed big. Opponents can long-press it to inspect it.
- **Series sets** unlock *army banners*: matching frames and a card-back for the whole army, plus a win-streak counter for that set.
- **Foil (animated) cards** animate on the board when their unit strikes.
- **Mastery:** each card levels up from the battles it fights in. "Win with 10 different Command banners" rewards breadth.
- **Fairness:**
  - The gameplay tiles come from the neutral 20-tile deck for everyone, and ranked uses only that deck.
  - A casual "commander" mode can let a series set choose *which neutral deck variant* you play. All variants are balanced against each other, so this is breadth, not power.
- **CoD loop example:** "Finish the sniper-mastery challenge series in CoD → its 5 cards become a matching army banner here, plus a 'Marksman' deck-variant skin." The set screen shows 3 of 5 as silhouettes with their CoD unlock hint.

### Session length, solo AI and risks

- **Session:** about 13–14 turns in total (around 7 each) and 6–7 battles, so **8–10 minutes**.
- **Solo AI:**
  - The greedy AI (simulate a battle for every placement) is cheap: about 300 placements per tile.
  - A 1-ply reply search is about 4× greedy. Both are feasible in GDScript on a worker thread.
  - Difficulty levels come for free: random, greedy, then lookahead.
- **Risks:**
  - Readability of 10 icons per tile on a phone. Each segment needs a bold icon, and inspect must show a big, upright card with its icons explained.
  - A "battle preview" overlay (arrows for every shot, in initiative order) is essential, and it doubles as the tutorial.
  - First-move balance (solved in the simulation; see below).
  - The family it comes from is well known, so the originality bar is real.

### Simulation results

The script is `front.py`. The opponent-reply lookahead plays each candidate against the opponent's best answer from a sampled hand.

| Matchup | Result |
|---|---|
| greedy vs random (100 games per seat) | greedy wins **100%** |
| greedy mirror, first player plays only 1 tile on turn 1 (200 games) | second player wins **63%** (30% / 8% ties). Broken. |
| greedy mirror, first player plays 2 tiles on turn 1 (200 games) | 41% first / 51% second / 9% ties |
| **greedy mirror, 2 tiles on turn 1 + first Command 11 HP (300 games)** | **48% / 45% / 6% ties**: balanced |
| **lookahead vs greedy**, 2 tiles on turn 1 (100 games per seat) | lookahead wins **52%–42%** as first player and **57%–31%** as second player. Overall **55% against 37%**, where the mirror baseline is about 46% each. |
| lookahead vs greedy, original 1-tile start | 43%–47% as first player (the greedy baseline there is 30%) and 77%–20% as second player (baseline 63%) |
| greedy (4 rotations) vs greedy limited to 2 rotations | the limited AI wins **19–20%** |

- **Interesting:**
  - Skill shows at every level: greedy beats random 100%, and lookahead adds about 10–15 points over greedy.
  - Rotation is load-bearing.
  - The game is short and bursty.
- **Broken or needs work:**
  - The reacting seat had an edge, fixed by a 2-tile first turn and +1 HP on the first player's Command.
  - Ties run 6–9%, so the tiebreak rule above is needed.
  - Command having a Blade on all 10 segments may be strong. Test Command with Blades on its long sides only.
  - The simulation has no move or push tiles. The genre usually has them, and adding one "Shift" tile is a later depth lever.

---

## B. Muster: formation-puzzle combat (the Clash of Heroes family)

**Hook:** "Line up your troops into charges and walls. Your calling-card elite turns the battle: stand it up as a lance, or lay it down as a bulwark."

### Rules (one page)

**Your side.**
- Each player has their own **6 columns × 6 deep** grid. The front row faces the enemy, and column *i* faces enemy column *i*.
- Pieces close up toward the front.
- **Troops** are 1×1 pieces in 3 colours (original emblems). You start with 16, laid out so that no formations exist yet.

**3 actions per turn.** Choose from:
- **Move:** take the back troop of a column and put it at the back of another column.
- **Remove:** delete any troop. The pieces behind it close up.
- **Call:** refill your troops to 16.
- **Deploy elite:** see below.

**Formations** check after every action:
- **3 same-colour troops stacked in a column** become a **Charge**: power 3, fires at the start of your 2nd turn from now. It moves to the front, behind any walls.
- **3 same-colour troops side by side** (same depth, adjacent columns) become **Walls** with 2 HP each, moved to the front.
  - A column holds only **one** wall. Another wall there adds to its HP, up to a maximum of 4.

**Elites: your calling cards, 2 per battle.**
- **Lance (vertical):** it fills 4 cells at the back of one column. When a troop *of its colour* lands directly behind it, it becomes a **power 8 Charge** that fires in 3 turns.
- **Bulwark (horizontal):** it immediately places walls with 3 HP each across the front of 4 adjacent columns.

**Chains.** A Remove that causes a formation, or any action that makes 2 or more formations, gives **+1 action**.

**Firing.** When a Charge's timer runs out, it attacks down the facing enemy column:
- enemy walls absorb damage up to their HP;
- enemy Charges *clash* (both lose power);
- idle troops are jumped over;
- what remains hits the enemy **hero (12 HP)**.

**Win:** reduce the enemy hero to 0. At the turn cap, the player with more hero HP wins.

### Where the depth comes from

1. **Attack against defence.** Each formation is either a Charge or a Wall, and the same troops can't be both.
2. **Timing.**
   - Charges fire later, so you build them where the enemy *will* be weak when they land.
   - You also read the enemy's countdowns and wall the right columns.
3. **Chains.** Removals that cause formations are free actions. Planning a 3-action turn that becomes 5 actions is the "aha".
4. **Elite rotation.** A Lance is slow, needs setting up and hits hard in one column. A Bulwark is instant and wide. The choice is where your calling card matters most.
5. **Call timing.** Refilling costs an action and the new troops arrive at random, but sometimes they are exactly what you need.

### How the 4:1 shape and rotation matter

The elite is the 4:1 card. Standing it up makes it a 4-deep spear in one column; laying it down makes a 4-wide shield.

In the simulation, the planner AI split its elites **1:1 between Lance and Bulwark**, while the greedy AI chose Bulwark **3:1**. The rotation decision is live, and better players lean into the Lance.

### Borrowed against new

- **Borrowed:**
  - separate per-player column grids;
  - vertical formations that attack after a countdown;
  - horizontal formations that make walls;
  - removal chains granting extra actions;
  - reinforcement calls;
  - an action budget per turn.
- **New:**
  - the 1×4 elite with a rotation choice;
  - the lance being triggered by a matching troop behind it;
  - one wall per column with stacking HP;
  - charges jumping over idle troops.
- **Avoided:** factions, hero classes, unit names and tiers, the reference game's linking and fusing terms, its board dimensions and its art style.

### Collection pillar

- **Elites are your calling cards.** You bring 2 per battle, and the elite rules are neutral; the card is the skin.
- **Troop colours take on series emblems.** Owning a full series unlocks that series as a troop theme.
- **Foil elites** get an animated charge-up.
- **Mastery** per elite card.
- **Ranked:** the neutral elite pair, with your cards as skins only.
- **CoD loop example:** "Unlock a new calling card in a CoD event → it becomes an elite skin with a one-week 'event elite' challenge here: 5 wins as a Lance."

### Session length, solo AI and risks

- **Session:** about 35 player turns (around 17 each). **That is too long, about 15–20 minutes.** It needs shortening (see the simulation).
- **Solo AI:** the greedy AI is cheap. The turn planner (beam 8 over the 3-plus-bonus actions) is heavier but fine. Both seats are natural for solo play.
- **Risks:**
  - Long fights.
  - It is the closest of the four to its reference family. The formation rules are genre, but players will make the comparison.
  - Lots of small pieces on a phone. The 6×6 grid at 48pt cells needs about 300pt per side, so the two sides must be stacked in portrait, and side by side in landscape (which fits better).

### Simulation results

The script is `muster.py`. Hero is 12 HP, with a 40-turn cap.

| Matchup | Result |
|---|---|
| greedy vs random (50 games) | greedy wins **100%**, in 13 turns |
| greedy mirror (200 games) | first 50.5% / second 44.5% / ties 5%: **balanced** |
| **planner vs greedy** (24 games per seat) | planner wins **19–4** as first player and **17–6** as second player: **75% against 21%** |
| version 1: walls stacking freely, idle troops absorbing damage | **100% stalemates**: 0 hero damage in 40 turns. Broken. |
| version 2: one wall per column (max 4 HP), charges jump idle troops | the results above |

- **Interesting:**
  - It has the strongest depth signal of everything we simulated: a planning player crushes a myopic one.
  - First-move balance is fine out of the box.
- **Broken:**
  - The first draft stalemated, and the fix is above.
  - About half the games still reach the turn cap.
  - **Call is a third of all actions**: refilling is too attractive, a near-pass.
  - **Fixes to test:** hero at 10 HP; Charges gain +1 power for each turn they wait; Call ends your turn.

---

## C. Spell Rail: match battle with abilities (the Puzzle Quest family)

**Hook:** "A shared match board, and your calling cards are mounted on its edge. Match next to *your* banners to charge them, and next to theirs to deny them."

### Rules (one page)

**The board.**
- A shared **8×8 grid** holds 4 mana emblems plus a Strike emblem.
- Swap two adjacent emblems to make a line of 3 or more. The matched emblems clear and new ones fall in.
- You gain mana of the matched colour, and each Strike in a match deals 1 damage.

**The rail.**
- The board's border has **8 rail slots**, each 4 cells long: 2 per edge.
- Before the battle, each player mounts their **4 ability cards** (calling cards) on 4 of the slots, taking turns.
- **Top and bottom rails hold cards horizontally, and left and right rails hold them vertically.** That is the rotation choice.

**Charging.**
- Any match that clears a cell in the 4 border cells next to a card adds **charge** to that card, *whoever* made the match.
- A card's ability can be cast when its charge **and** its mana cost are both met.

**Abilities** come from a neutral pool. Examples:

| Ability | Effect |
|---|---|
| **Sweep** | clear the full row or column the card borders |
| **Convert** | turn every emblem of one colour into another |
| **Drain** | steal 3 mana |
| **Bulwark** | the next 4 damage is ignored |

**Turns.**
- One swap per turn.
- A match of 4 or more, or a chain cascade, gives an extra turn (genre convention).
- Casting an ability uses your turn.

**Win:** hero HP 30 reaches 0.

**Progression (solo campaign).** Hero levels unlock rail slots 5 and 6, mana capacity and new neutral abilities. Your cards are the skins.

### Where the depth comes from

1. **Denial.** Every match also shapes the board the opponent sees next. Setting up their cascade is a blunder.
2. **Rail geography.**
   - Each match charges whoever's cards border it.
   - Matching near your rail feeds you, and matching near theirs feeds them.
   - Mounting order is a mini-draft.
3. **Mana against charge.** Some casts need both, so you plan colour income against position.
4. **Extra-turn chains.** Lines of 4 and cascades give tempo.

### How the 4:1 shape and rotation matter

- A card on the rail borders exactly 4 cells, the card's own length.
- A horizontal mount reads row matches and a vertical mount reads column matches.
- **Sweep** clears *its* line, so the slot decides what it can destroy.

This is a lighter use of the shape than A or B. The 4:1 card is mostly the *ability object*, not a board piece.

### Borrowed against new

- **Borrowed:** a shared swap-to-match grid, mana colours, a damage emblem, ability casting with mana costs, extra turns on big matches, RPG levelling.
- **New:** ability cards mounted on 4-cell rail slots that gain charge from adjacent matches; slot drafting; rail orientation.
- **Avoided:** the reference game's classes, spells, world, gem names and UI layout.

### Collection pillar (the strongest of the four)

- Your calling cards *are* your spellbook's faces.
- A **series set mounted together** (all 4 rails) gives a cosmetic aura and a set-mastery track.
- **The campaign** has "bounty" fights that ask for a card from a series you own, to give the collection a *purpose*. Every bounty has a starter-set alternative.
- **Ranked:** a neutral spell list with cosmetic faces.
- **CoD loop example:** "Unlock a calling card in a CoD event → it becomes a new spell face, and a bounty here asks you to win with it mounted."

### Session length, solo AI and risks

- **Session:** 6–10 minutes per fight. The campaign is endless.
- **Solo AI:** greedy match-picking is easy. Good denial play needs 2-ply search, which is still cheap on an 8×8 board.
- **Risks:**
  - Swap-match genre fatigue.
  - Board luck (cascades).
  - The 4:1 hook is the weakest of the four.
  - Not simulated this round: it ranked third on depth and on 4:1 fit.

---

## D. Hybrid: Banner Front Campaign (tile battle with a roguelite army draft)

**Hook:** "Banner Front's battles, strung into a solo campaign where your army deck grows between fights."

**Rules delta:**
- Start with a 12-tile neutral army.
- After each won battle, draft 1 of 3 new tiles. These are neutral types, including new ones: Shift (move a unit 1 cell), Mortar (an arcing Gun that ignores the first tile), Medic.
- Remove a tile at camps.
- Enemy commanders have one special rule each, for example "its Guns ignore Shields on ends".
- A run is 8 battles.

**Depth:** deck-shaping (what your army can do) on top of Banner Front's tactical tensions, plus enemy rules that ask for different facings.

**4:1:** the same as Banner Front. New tile types add icons on new segment layouts.

**Collection pillar:**
- Unlocked calling cards become the faces of drafted tiles.
- **Series sets unlock *starting army themes*.** These are different 12-tile neutral starts, balanced against each other: breadth, not power.
- Run history is a gallery of the cards that carried you.

**Session:** 40–60 minutes per run, or 8 minutes per battle with save between battles.

**Risks:** content load (enemy rules, new tiles). It comes *after* Banner Front versus is proven.

**Verdict:** the best long-term shape. The **solo story for Banner Front**, not the first prototype.

---

## Comparison (with Running Bond from Part 1)

| | **Banner Front** | Muster | Spell Rail | Front Campaign | Running Bond (Part 1) |
|---|---|---|---|---|---|
| Depth signal (simulated) | lookahead +10–15 pts over greedy; rotation limit drops wins to 20% | planner 75% vs greedy | not simulated | inherits A | greedy beats random; perfect walls 35%→14% (a tension, but solitaire) |
| Rules fit on one page | yes | yes | yes | A + 1 paragraph | yes (simplest) |
| 4:1 and rotation fit | **5**: edges, 4 rotations, lanes | 4: the elite's rotation choice | 2–3: rail mounts | 5 | 5 |
| First-player balance | fixed (48/45) | fine (50/45) | unknown | — | n/a |
| Session | **8–10 min** | 15–20 min (too long yet) | 6–10 min | 40–60 min run | 8–10 min |
| Solo AI needed | yes, but cheap (greedy and 1-ply proven) | yes, cheap | yes, cheap | yes | none |
| Collection pull | 4 (unit skins, Command banner, army sets) | 3 (elites, troop themes) | **5** (spellbook, bounties) | 4–5 (army themes) | **5** (wall gallery, series objectives) |
| Phone readability | medium (10 icons per tile; needs the preview overlay) | medium (many small pieces) | high | medium | high |
| Originality vs reference | medium-high | medium (closest to its family) | medium | medium-high | medium-high |
| 1-week prototype cost | medium | medium | medium | high | **low** |

**Recommendation: switch the first prototype to Banner Front.**
- It answers the head's "more depth with simple rules" most directly: a one-page ruleset, 8–10 minute games, and simulated evidence that skill and rotation matter.
- It keeps the strongest 4:1 identity of all the concepts.
- Its AI is already proven cheap, and the same AI gives difficulty levels.
- Running Bond remains the best *daily solitaire* and the lowest-cost build, so it becomes a later mode sharing the tile renderer and collection.
- Muster is the backup if the head prefers separate per-player grids.

### What a 1-week Godot 4.4.1 prototype of Banner Front contains

| Day | Content |
|---|---|
| 1 | Scenes and data: `Board.tscn` (an 8×7 `Control` grid, portrait- and landscape-responsive), `unit_def.tres` resources (initiative, HP, 10 segment icons), `tile.gd` (rotation, cells and segments as typed arrays). |
| 2 | Placement: hand of 3, drag or tap to place, rotate by button, R key or two-finger twist, a ghost preview, the discard. |
| 3 | `battle_resolver.gd`, a port of `front.py`: initiative steps, Guns, Blades, Shields, once-per-target. A **battle preview overlay** (shot arrows grouped by initiative step) that plays as an animation when a battle happens. |
| 4 | AI on a worker thread: random, greedy and lookahead difficulties. Turn flow, Battle orders, the board-full trigger and the final battle. |
| 5 | Inspect on right click / long press: the big upright card, its segment icons explained, initiative, HP, and "what this unit will hit" highlighted. A one-screen tutorial. |
| 6 | Collection mock: original-art starter set, "assign art to unit type", an army-banner set screen, and a fake unlock feed (same as Part 1). Local pass-and-play. |
| 7 | Web export with iPhone portrait and landscape tests and PC; QA; a balance log (CSV of win, seat, turns, battles and unit damage). |

---

## Questions for the head (recommended option first)

1. **First prototype:**
   - **(a) Banner Front (recommended).** The most depth per rule, and proven in simulation.
   - (b) Running Bond, as planned in Part 1. Cheapest, solitaire.
   - (c) Muster. The formation combat, but long sessions until it is tuned.
2. **First play mode for Banner Front:**
   - **(a) Solo against an AI with 3 difficulty levels, plus local pass-and-play (recommended).**
   - (b) Online versus. Needs a backend.
   - (c) The roguelite campaign (D) from the start.
3. **Complexity budget for version 1:**
   - **(a) 5 unit types, 4 edge icons, no move or push tiles (recommended).** The simulated version.
   - (b) Add Shift and Push tiles from day one.
   - (c) Asymmetric armies (different decks per side).

---

*The simulation scripts are in `/tmp/claude-0/-home-user/d4346a6d-2ad8-5e6f-975d-207e362015dd/scratchpad/cct/` (`front.py`, `muster.py`, `mdbg.py`, `mstat.py`). The environment knobs are `FIRST_N`, `HQ0` (front) and `HERO`, `WALLCAP`, `TROOPBLOCK` (muster). Run them with `python3 -I`.*

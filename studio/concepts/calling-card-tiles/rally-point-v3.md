# Rally Point v3: Front Line

*Board task `cct-rally-v3` · project `cctiles` · Sr Game Designer · 2026-11-08*
*Follows [Rally Point v2](rally-point-v2.md) (stacks, keywords, chassis + art), [Part 3: banners + emblems](emblems.md) (dead cells, emblem sizes, the patch rule) and [Part 2](concepts-depth.md) (the Puzzle Quest / Clash of Heroes / Neuroshima families). Simulator: [`tools/rally_v3.py`](tools/rally_v3.py), derived from `rally_v2.py`; v1 (`rally.py`) and v2 (`rally_v2.py`) are unchanged. All names, classes, orders and rewards here are original. Call of Duty is named only as the inspiration.*

The studio head rates Rally Point as one of our 3 best pitch candidates and asked two things:
- *"Would Rally Point be better if the emblems were 1 by 1 squares? Maybe we need both types of square to make sure filling the grid is fun."*
- *"I would like to see features reminiscent of Call of Duty ... putting some assault cards and emblems together triggers an attack ... defensive cover ... Take inspiration from Puzzle Quest, where different gems give different things you acquire, and then you can trigger attack or defense or other effects ... It's a tiling and puzzle game mostly, but I want military effects coming into play."*

**TL;DR**
- **Both sizes, with different jobs.** The 2×2 emblem stays as the **Objective**: the hub that rallies. A new 1×1 emblem, the **Insignia**, is a small "gem": it fills any single cell, scores like a piece of banner, and pays double materiel when the objective next to it rallies. 1×1 *hubs* are a bad idea: they leave 11–13 cells empty (17–20% of the board) and almost never allow a full board. The patch rule stays. Mixing in 2 insignia raises full boards from 37% to 29–47%, rallies from 4.2 to up to 4.8, and distinct choices per turn from 6.5 to 7.2.
- **The military layer comes out of the rallies, like mana out of matches.** The four suits become four **classes**: Assault ◆, Recon ●, Engineer ▲, Support ✚. When an objective rallies, every tile touching it gives its owner 1 **materiel** of its class: Ammo, Intel, Works or Supply. At 3, a meter fires an **order** at the end of your turn: **Strike** (Attack 2: destroy an enemy banner that is not in cover, or push the Front), **Spot** (your next Strike +1 and ignores cover and Armor, plus Front +1), **Fortify** (+2 Armor, win back ground) or **Resupply** (draw a tile, +1 point, Front +1).
- **Cover is geometry.** A banner touching one of its owner's Engineer tiles, or its owner's Bunker, is in cover. Strikes can't destroy it unless the attacker has spotted first. Assault and Recon together get through cover.
- **Killstreaks.** Closing a rally or firing an order adds 1 to your **streak**, and an enemy Strike that lands resets it. At **3**: Spotter Drone (see their hand, +1 Intel). At **5**: Supply Drop (draw 1 and place it now). At **7**: Fire Mission (Front +2 through Armor and destroy an exposed banner).
- **Win condition: points, with a sudden-death Front.** The most points still wins. A 13-step **Front** sits between the two players; pushing it all the way to the enemy end is a **Breakthrough** and wins on the spot. It happens in about **8–9%** of games, enough to threaten, rarely enough that the puzzle stays the game.
- **Sim headline (`rally_v3.py`, smart AIs, final rules):**
  - Seats balance at **46.7% / 52.2%** with "P2 starts with 1" (48.2% / 50.6% in a second run); with no compensation, P1 wins 53%.
  - A planner beats a greedy player **97%** of the time.
  - About **6 orders** fire per game, including about **1.6 Strikes**. Only **0.5 tiles** get destroyed per game, and a player loses 2 or more in only **10%** of games. The mid-game leader loses **35%** of the time, so comebacks happen.
  - A turn has about **66** legal placements, with **6.0** distinct outcomes, and the best beats the median by **3.2 points** (v2: 2.8).
  - A game is about **19.5 placements**, which is **5–7 minutes**.
  - The four starter stacks land between **47.2% and 53.8%**.
- **The honest caveat.** Our AIs play the military layer no better when they understand it than when they ignore it (about 50%). Today the layer *amplifies* good tiling rather than adding a second skill. That matches "a tiling and puzzle game mostly", but the Front decisions need human playtests (section 8.4).

> **Terms.** A **banner** is a 1×4 calling-card tile. An **objective** is a 2×2 emblem placed as a hub (v2 called it a hub). An **insignia** is a 1×1 emblem tile. A **contact** is any banner or insignia cell on an objective's border. A **rally** is an objective firing when its border is full. **Materiel** is the class resource a rally pays. An **order** is what a full meter fires. The **Front** is the tug-of-war track. A **streak** is your killstreak count. A **class** is what v2 called a suit.

---

## 1. Emblem sizes: 1×1, 2×2, or both?

### 1.1 What was compared

`python3 -I rally_v3.py 30 sizes` re-shapes the four starter stacks (section 6) into each frame below. Every frame plays the full v3 rules, smart against smart, from both seats, with 240 games per row; the "v2 rules" column comes from the same run with the military layer off and v2 drills on. Each stack is always 12 tiles, and **that bounds the game at 24 placements**. This is why the 1×1 no longer blows a board up from 13 to 31 turns, as it did in Part 3's open-supply study.

| Frame (per 12-tile stack) | Placements | Empty cells at end | Full boards | Rallies | 1-cell "plug" turns | Options / distinct / best−median | Smart vs greedy | Orders fired |
|---|---|---|---|---|---|---|---|---|
| **A. 2×2 only** (v2: 8 banners, 4 objectives), patch rule | 16.9 | 3.6 | 37% | 4.2 | 0.4 | 63 / 6.5 / 3.6 | 90% | 4.4 |
| A′. 2×2 only, no patch rule | 14.7 | 7.3 | 4% | 3.0 | 0.2 | 70 / 6.4 / 3.2 | 91% | 2.9 |
| **B. 1×1 hubs only**, 4-cell ring (8 banners, 4 hubs) | 20.2 | 10.7 | 0% | 6.3 | 0.2 | 87 / 6.4 / 4.3 | 94% | 7.1 |
| B′. 1×1 hubs only, 8-cell ring (the diagonals count) | 20.6 | 12.9 | 0% | 5.8 | 0.4 | 84 / **10.1** / **5.4** | 98% | 6.3 |
| C. 2×2 + 1×1 hubs (8 banners, 2 + 2) | 18.9 | 7.4 | 5% | 4.6 | 0.3 | 71 / 8.3 / 4.0 | 93% | 5.0 |
| **D. 2×2 + 1×1 insignia** (7 banners, 3 objectives, 2 insignia), patch rule | 19.5 | 3.5 | 29% | 3.7 | 4.1 | 68 / 6.0 / 3.2 | 96% | 5.9 |
| **D4. same, 4 objectives** (6 banners, 4 objectives, 2 insignia) | 20.2 | **2.7** | **47%** | **4.8** | 4.0 | 64 / 7.2 / 4.0 | 95% | **7.3** |
| D′. 2×2 + insignia, no patch rule | 18.1 | 6.0 | 10% | 3.6 | 4.0 | 72 / 6.1 / 3.8 | 97% | 5.6 |
| E. 2×2 + 1×2 "tags" instead of insignia | 18.7 | 3.7 | 23% | 3.7 | 4.2 | 74 / 5.8 / 3.3 | 100% | 5.7 |
| F. 2×2 + 4 insignia (6 banners, 2 objectives) | 21.2 | 5.8 | 11% | 3.0 | 7.8 | 70 / 4.6 / 3.1 | 96% | 6.2 |
| C+D. 2×2 + 1×1 hubs + insignia (6 / 2 / 2 / 2) | 21.4 | 9.4 | 3% | 5.6 | 4.0 | 79 / 9.6 / 5.2 | 98% | 8.5 |

The pure-tiling run (v2 rules, no military layer, 320 games per row) shows the same ranking: A leaves 3.6 cells empty and B 9.5–11.8, D 3.2, D′ 6.1 and E 3.6.

### 1.2 What it means

1. **1×1 as the only emblem fails the head's goal of a fun grid fill.** A 1×1 hub does not fill gaps: it *needs* its ring filled, so it adds a new hole to finish rather than closing one. Boards end with 11–13 empty cells and are never full.
   - The 4-cell ring also closes almost by accident: 6.3 rallies a game, with the weakest skill signal of the lot.
   - The 8-cell ring (diagonals count) is the most decision-dense frame we have measured: 10 distinct outcomes a turn and a 5.4-point spread. It is a good puzzle in its own right, but it is a *different* game, with more empty board and more counting than a phone can show cleanly. We park it for the solo daily (section 9, question 1).
2. **The head's instinct, "both types of square", is right, but the 1×1 should be a filler, not a hub.** The insignia (D) is the version that works:
   - It fills a single cell no banner can reach, which is the most common dead pocket the patch rule had to cover.
   - It gives the grid fill a *second* tempo: 4 small "plug" moves a game in which you finish someone's objective with a tiny tile.
   - It is the natural "gem" of the military layer (section 3).
   - It is also the most authentic size: on the real-world player card, the emblem is a square as tall as the calling card (Part 3 §2). The 2×2 objective is the big badge; the insignia is the small one.
3. **Keep the patch rule.** Without it, the insignia alone leaves 6.0 empty cells (D′) against 3.5 with it. Insignia handle singles; patches handle 2–4 cell pockets.
4. **Cap insignia at 2.** With 4 (F), plug turns double to 7.8 a game and the distinct outcomes per turn drop to 4.6. Small tiles are fun as a spice and dull as a diet.
5. **1×2 tags add nothing the insignia doesn't** (E): the same dead cells, fewer distinct choices, and a 2:1 shape that is neither a banner nor a badge, so there is no collection art for it.
6. **Four objectives beat three** (D4 against D): 47% full boards, 4.8 rallies and 7.3 orders a game, at the cost of a sixth of the calling cards. That is a deck-building choice, so the stack rule allows both (section 2).

**Recommendation: 2×2 objectives + up to 2 1×1 insignia, patch rule kept.** Starter stacks run 7 banners, 3 objectives and 2 insignia; stack builders may go to 6 / 4 / 2.

---

## 2. Rules (one page)

**You bring** a stack of **12 tiles**:
- **6–7 banners** (1×4 calling cards), **3–4 objectives** (2×2 emblems) and **at most 2 insignia** (1×1 emblems).
- **At most 2 classes.** At most 2 copies of a chassis (alt arts count as copies); 1 of a legendary.

**Setup:** shuffle, draw 3. Random first player. **The second player starts with 1 point.** The Front starts at the centre.

**Your turn:**
1. **Place one tile from your hand.**
   - **Banner:** any 4 empty cells in a straight line.
   - **Objective:** any empty 2×2, or **pinned as a patch** over an enclosed gap of 1–4 cells (it then never rallies).
   - **Insignia:** any single empty cell.
2. **Deploy:** resolve the tile's Deploy text, if it has any.
3. **Rallies:** every objective whose border is now full fires, oldest first.
4. **Orders:** each of your meters that holds 3 or more spends 3 and fires once, in the order Fortify, Spot, Strike, Resupply.
5. **Refill** your hand to 3.

**If nothing fits:** Redeploy (bottom 1 tile, draw 1) and pass.

**Rally** (8 border cells, 2 per side; the board edge counts as filled):
- Each contact cell scores **1** for its owner, **2** if it **matches** (same class, or the card says it matches).
- The **closer** gets **+1**, plus **+1 per Charge** on the objective.
- The objective's **owner** gets its **Command** (+2 standard).
- **Materiel:** every banner touching it gives its owner **1** materiel of the banner's class; an insignia gives **2**; the objective gives its owner **1** of its own class. Keywords can add more.

**Orders** (the meters sit beside your player card; each one glows when it will fire):

| Class | Materiel | Order at 3 | Effect |
|---|---|---|---|
| Assault ◆ | Ammo | **Strike** | **Attack 2:** destroy one enemy banner or insignia that is **not in cover** (its cells empty again), **or** push the Front 2 toward the enemy. Enemy Armor soaks Front pushes 1 for 1. |
| Recon ● | Intel | **Spot** | Front +1. +1 Charge on every open objective you touch. Your **next Strike is +1 and ignores cover and Armor**. You see the opponent's hand until your next turn ends. |
| Engineer ▲ | Works | **Fortify** | **+2 Armor** (max 4). If the Front leans toward you, win back 1 step. Unused Armor scores 1 point each at the end. |
| Support ✚ | Supply | **Resupply** | Draw 1 tile, +1 point, Front +1. |

**Cover:** a banner or insignia is **in cover** while it touches another tile of its owner's that is Engineer class, or an objective of its owner's with the Bunker rule. The Engineer tile itself is exposed unless it touches another Engineer tile. A Strike picks its target from what is exposed; the default (hit the exposed tile worth the most on open objectives, otherwise the Front) is pre-selected, and one tap changes it.

**The Front:** a track of 13 steps, centre 0, 6 steps to each player's end. Reaching the enemy end is a **Breakthrough: you win at once.** Otherwise the Front scores nothing at the end; it is the threat, not a points track.

**Streak:**
- **+1** for each rally you close and each order you fire. An **enemy Strike that lands** (destroys a tile or moves the Front) **resets it to 0**.
- **3 · Spotter Drone:** +1 Intel, and you see the opponent's hand until your next turn ends.
- **5 · Supply Drop:** draw 1 and place one more tile now.
- **7 · Fire Mission:** Front +2, ignoring Armor, and destroy one exposed enemy banner.

**End:** board full, or both players pass in a row, or a Breakthrough.
- Un-rallied objectives score their contacts at 1 per cell (Dig-in banners keep their match).
- Unused Armor scores 1 each; then "End:" texts.
- Most points wins; on a tie, more rallies closed.

**Inspect (long press / right click), always available:**
- **Objective:** border progress, Charges, and the **"if it closed now" preview**, now extended: *you +9, them +4, you gain 4 Ammo and 2 Intel, Spot and Strike will fire*.
- **Meters:** what each order does and what it would hit right now (the Strike's default target is outlined on the board).
- **Any tile:** whether it is in cover and why (the covering tile is outlined).
- **The Front:** both players' Armor and how many steps to a Breakthrough.

**What v3 removes from v2:** the four suit drills (Strike closer +2, Signal relay, Ridge keep, Supply draw). Their jobs move into the orders: the closing bonus became Breach and the streak, Signal's Charges became Spot, Ridge's patience became Fortify and Armor, and Supply's draw became Resupply. Net rules weight stays about the same; turns stay one placement plus automatic orders.

---

## 3. The military layer

### 3.1 Why it is built this way

| The head's idea | v3 answer |
|---|---|
| "Different gems give different things you acquire" | Rallies pay **materiel by class**. Insignia are the literal gems: small, cheap, double materiel. Where you put a banner decides what you earn, exactly like choosing which colour to match. |
| "Then you can trigger attack or defense or other effects" | Four **orders**: attack (Strike), defence (Fortify), intel (Spot) and logistics (Resupply). They fire on their own at 3, so a turn is still one placement. |
| "Putting some assault cards and emblems together triggers an attack" | Assault banners plus an Assault objective plus an Ammo Cache around one rally fill the Ammo meter in one go. See combo 2. |
| "Defensive cover that blocks attacks or protects a hub" | **Cover from geometry** (Engineer tiles and Bunkers protect what they touch) and **Armor** from Fortify (soaks Front pushes). See combo 3. |
| "Killstreak-style escalation" | The **streak** with 3 / 5 / 7 rewards; an enemy hit resets it, as in the source genre. |
| "Damage to their HP or their emblems, deny cells, suppress" | Strikes destroy exposed tiles, which **reopens cells** and removes contacts from open objectives (denial). Jam (an epic Recon card) suppresses a banner's text and materiel. Objectives are never destroyed: rallied history stays on the board. |
| "It's a tiling and puzzle game mostly" | Points still win. Every military effect is triggered by a rally, so the puzzle decides when the war happens. |

### 3.2 Win condition: why points plus a sudden-death Front

Three options were simulated or reasoned through:
- **(a) Points, with a Breakthrough Front (chosen).** The puzzle stays the main way to win, and the Front is a visible threat that ends about **8–9%** of games. Every class can move it: Strike 2, Spot 1 and Resupply 1 push it; Fortify soaks and wins ground back.
- **(b) Points, with the Front also scoring at the end (1 point per step).** Tested first: it made Assault stacks the clear best (two Assault stacks averaged 58% and 66%, the others 36–40%). Front points stack on top of tile destruction. Dropping end scoring and letting every class move the Front closed the gap to 47–54%.
- **(c) Opponent HP only (a Puzzle Quest-style race).** Rejected: rallies feed *both* players, so an HP race turns every rally into a mutual hit and erases the "who closes" tension that makes the game. It also makes defensive stacks unplayable.

Sweep (`rally_v3.py 100 tune`, before the final balance rules): with Strike 2 and a threshold of 3, a 6-step Front gives Breakthrough in 12% of games and a 5-step Front 15%. Strike 3 gives 27% and threshold 2 gives 25%, which is too swingy. Threshold 4 drops to 3.5% and 1.3 Strikes a game, which is too quiet.

### 3.3 Interaction without frustration

- **Strikes are rare and visible.** About 1.6 Strikes a game, and every meter shows when it will fire, so the target sees it coming one turn ahead and can move into cover, or Fortify.
- **Losing tiles is uncommon.** Most Strikes go to the Front (1.2 of 1.6). Destroyed tiles average 0.5 a game, and a player loses 2 or more in only 10% of games.
- **Destruction is also a gift.** It reopens 4 cells, and the next placement into them is often the victim's.
- **Never touched:** rallied objectives, points already scored, or the hand. The "if it closed now" preview stays exact, because orders fire only at the end of a turn and only at a full meter.
- **Comebacks:** the player leading at mid-game loses 35% of the time, and the streak reset means a leader on a run is the natural target.

---

## 4. Combos, drawn

Lower case is Player 1, upper case is Player 2. `[ ]` marks objectives. `✱` is the tile being placed. Classes: ◆ Assault, ● Recon, ▲ Engineer, ✚ Support.

### Combo 1: Spot, then Strike (Recon + Assault)

```
      1    2    3    4    5    6    7    8
 1   [A◆   A◆]  s●   s●   s●   s●   W▲    .      A = P1 Assault Post (objective, top-left corner)
 2   [A◆   A◆]  ✱●    ·  [B▲   B▲]  W▲    .      s = P1 Spotter (Recon banner, Rally: +1 Intel)
 3    p◆   p◆   p◆   p◆  [B▲   B▲]  W▲    .      p = P1 Point Man (Assault, Breach +3)
 4    .    .    M✚   M✚   M✚   M✚   W▲    .      ✱ = P1 Flare (Recon insignia), placed now
                                                 B = P2 Engineer Post   W = P2 Sandbag Line (Engineer)
                                                 M = P2 Medic Line (Support): in cover, it touches W
```
P1 starts the turn with 2 Ammo and 1 Intel. P2 has no Armor. B is 7 of 8: only the enclosed cell `·` at row 2, column 4 is open, and P2 is waiting to plug it for about 9 points.

- **P1 places the Flare in the last gap beside A.** A's top and left are off the board, so its 4 on-board border cells are now full, and it **rallies**:
  - s scores 1 (no match), the Flare 1, p 2 cells × 2 = 4; closer +1; Command +2. **P1 +9.**
  - Materiel: Spotter 1 + 1, Flare 2, Point Man 1 Ammo, the Assault Post 1 Ammo. **Intel 1 → 5, Ammo 2 → 4.**
- **End of turn, orders fire:**
  - **Spot** (Intel 5 → 2): Front +1 toward P2; B gets a Charge (P1 touches it); P1's next Strike is +1 and ignores cover.
  - **Strike** (Ammo 4 → 1): Attack 3, ignoring cover. A real choice:
    - **Destroy M.** It is in cover, but Spot ignores cover. P2 loses 2 contacts on B, and B drops to 5 of 8 with 4 cells open again: P2's 9-point plug is gone.
    - **Or push the Front 3**, to +4 of 6, two steps from a Breakthrough, and make P2 spend the next turns defending.
- **Streak:** the rally, Spot and Strike make 3, so **Spotter Drone**: +1 Intel (3, so Spot fires again next turn) and P1 sees P2's hand. P2 was hit, so P2's streak resets.
- **Why it is a combo:** Recon alone can't destroy and Assault alone can't reach covered tiles. Recon and Assault around one Assault Post, finished by a 1×1 insignia, can.

### Combo 2: Fire team at the wire (Assault + Support, double close)

```
      1    2    3    4    5    6    7    8
 3   V▲   u◆    .   X▲   y◆    .    .    .      C = P1 Assault Post    D = P1 Supply Depot (both on the bottom edge)
 4   V▲   u◆   r◆   X▲   y◆    .    .    .      r = P1 Rifle Team (Assault, Rally: +1 Ammo), vertical
 5   V▲   u◆   r◆   X▲   y◆   w✚    .    .      u = P1 Point Man (Assault)   y = P1 Liaison A>S (Assault, matches ✚)
 6   V▲   u◆   r◆   X▲   y◆   w✚    .    .      w = P1 Medic Line (Support, Rally: +1 Supply)
 7  [C◆   C◆]  r◆  [D✚   D✚]  w✚    .    .      V = P2 Dug-In (Engineer)   X = P2 Long Watch (Engineer)
 8  [C◆   C◆]  ✱◆  [D✚   D✚]  w✚    .    .      ✱ = P1 Ammo Cache (Assault insignia), placed now
```
Row 8, column 3 is a single enclosed cell that is on the border of both objectives. No banner fits it. P1 drops the **Ammo Cache** there and **both objectives rally** (C first, it is older).

- **C rallies:** V 1 (P2), u 1 × 2, r 1 × 2, ✱ 1 × 2, closer +1, Command +2. **P1 +9, P2 +1.** Ammo: u 1, r 2, ✱ 2, C 1 = **6 Ammo**.
- **D rallies:** X 1 (P2), y 1 × 2 (its Liaison matches ✚), r 1, ✱ 1, w 2 × 2, closer +1, Command +2. **P1 +11, P2 +1.** Materiel: y, r and ✱ make 5 Ammo; w and D make 3 Supply.
- **One placement: P1 +20, P2 +2, 11 Ammo, 3 Supply.**
- **Orders:** each meter fires once a turn and keeps the rest, so this one setup is a **barrage**: Strike now (11 → 8), Strike next turn (8 → 5) and the turn after (5 → 2). **Resupply** fires too: draw 1, +1 point, Front +1.
- **Streak:** 2 rallies, a Strike and a Resupply make 4; the next turn's Strike makes 5, so a **Supply Drop**: an extra tile, placed at once.
- **The counter:** P2 sees the 8 Ammo left in P1's meter. P2's Engineer stack can Fortify (Armor soaks the pushes) and slide its banners against V and X so they are in cover.

### Combo 3: Dig in (Engineer + Support defence)

```
      1    2    3    4    5    6    7    8
 1    ·    ·   [K▲   K▲]  S▲   S▲   S▲   S▲      K = P2 Bunker (Engineer objective: P2 tiles touching it are in cover)
 2    ·    ·   [K▲   K▲]  M✚   M✚   M✚   M✚      S = P2 Sandbag Line (Engineer)   M = P2 Medic Line (Support)
 3    .    .   L▲   L▲   L▲   L▲    .    .      L = P2 Long Watch (Engineer)
```
P2 has fired Fortify twice: **Armor 4**. P1's Ammo meter is full.

- **Every P2 tile is in cover:** S, M and L all touch the Bunker, and M also touches the Sandbag Line.
- **P1's Strike has no legal tile target.** It goes to the Front, and Armor soaks both steps (4 → 2). Nothing lands, and P2's streak survives.
- **P1's real options:**
  - Spot first: a spotted Strike ignores cover and Armor.
  - Hold the Fire Mission for a 7-streak.
  - Or out-tile P2: K's left side (column 2, rows 1–2) is open, and P1 can leave it there, since closing K now would pay P2 about 8 points.
- **Why it matters:** defence is something you *build* on the board, and it has a clear counter (Recon). It is never a wall you can't answer.

---

## 5. Collection fit

### 5.1 New tile types in the chassis + art system

Nothing about v2's content system changes: a **chassis** is gameplay (template, numbers, class, rarity), an **art** is a picture, and any number of arts share a chassis.

| Type | Shape | Art slot | Launch chassis | Notes |
|---|---|---|---|---|
| Banner (calling card) | 1×4 | wide banner art, as in v2 | 32 from v2 + **6 new**: 4 commons "Rally: +1 \<materiel\>" (Rifle Team, Spotter, Sandbag Line, Medic Line) and 2 rares (Breaching Charge: Deploy, destroy a touching exposed enemy insignia; Forward Observer: Spot costs 2 while this is on the board) | v2 suits are renamed to classes; v2 card texts are unchanged |
| Objective (big emblem) | 2×2 | badge art at 96pt | 17 from v2 (the Command and rule numbers re-tuned, drills removed) + **2 new**: Bunker (R, Command 1, cover) and Armory (E, Assault: each Assault contact gives +1 Ammo) | "Hub" is renamed "objective" in the UI |
| **Insignia (small emblem)** | **1×1** | **the small square emblem, the most faithful player-card element** | **4 commons** (Ammo Cache, Flare, Sandbags, Supply Crate: 2 materiel of their class) **+ 4 rares** (Claymore: Deploy, the next enemy banner placed touching it is destroyed if exposed; Smoke: tiles touching it are in cover this round; Medal: +2 points if it touches two objectives; Dog Tags: +1 streak when an objective it touches rallies) | Insignia are where linked or event **emblems** land as alt arts |

- **Launch total:** 38 banners, 19 objectives and 8 insignia make **65 chassis**, from 36 templates. With the v2 art ratios (6 per common, 4 per rare, 3 per epic, 2 per legendary) that is about **300 arts**.
- **Per season:** keep v2's pace (+12 chassis, +90 arts), and set aside **2 insignia chassis and about 20 insignia arts** a season: small emblems are cheap to draw and the most "collectible" looking item.
- **Killstreak loadouts (later, not launch).** The 3 / 5 / 7 rewards are fixed at launch. From season 2, a player could choose one reward per tier from unlocked options (for example tier 5: Supply Drop *or* "Sentry: place a free Sandbags insignia"). That is a strong and familiar collection hook, but every option must sit in the power band (question 4).

### 5.2 Stacks

- **Personal stacks:** 12 tiles = **6–7 banners, 3–4 objectives, up to 2 insignia**, at most 2 classes. Insignia count toward the 2-copy limit like any chassis.
- Your featured **calling card** and **featured emblem** still show on your side; your featured insignia now appears on your meter panel.
- **Starter stacks** (commons, owned on day 1; the starter Bunker is the one rare given free):

| Stack | Classes | Banners (7) | Objectives (3) | Insignia (2) | How it plays |
|---|---|---|---|---|---|
| **T1 Spearhead** | ◆ ● | Point Man ×2, Shock Line, Liaison A>R, Wireman, Spotter ×2 | Assault Post ×2, Recon Post | Ammo Cache, Flare | Spot then Strike. Teaches combo 1. |
| **T2 Hold the Line** | ▲ ✚ | Dug-In ×2, Long Watch ×2, Sandbag Line, Field Kit, Quartermaster | Engineer Post, Bunker, Supply Depot | Sandbags, Supply Crate | Cover, Armor, the long game. Teaches combo 3. |
| **T3 Relay Net** | ● ▲ | Wireman, Liaison R>E ×2, Long Watch ×2, Dug-In, Spotter | Recon Post, Engineer Post ×2 | Flare, Sandbags | Charges, links, spotted defence. |
| **T4 Shock and Supply** | ◆ ✚ | Point Man ×2, Shock Line, Liaison A>S, Medic Line, Field Kit, Quartermaster | Assault Post ×2, Supply Depot | Ammo Cache, Supply Crate | Double closes and barrages. Teaches combo 2. |

### 5.3 Fairness model (unchanged)

"Own the function, not the power" stands. All commons on day 1, rares and above by play, every chassis in one power band, no stat upgrades. Insignia and military keywords join the same `power` test as v2 (2 copies swapped into a plain stack, median ±6) before they ship.

---

## 6. Simulation (`tools/rally_v3.py`)

Standard library only. `python3 -I rally_v3.py 100` runs seat, skill, stacks, military and density. `sizes` (section 1) and `tune` (section 3.2) are slow and must be named. The AIs are v2's:
- **random**, **greedy** (best immediate points, plus Front steps), and **smart** (immediate points, an estimate of every open objective, exposure, and now materiel, Armor, streak, the Front and the risk of exposed tiles);
- **milblind**: smart, but it values only the tiling, not the military state (the rules still apply);
- **textblind**: smart, evaluating as if cards had no text.

### 6.1 Seat balance

Smart mirror, each starter stack against itself, 1,200 games per row:

| Compensation | P1 | P2 | Ties | Points / game | Placements |
|---|---|---|---|---|---|
| none | 53.0% | 45.8% | 1.2% | 53.1 | 19.5 |
| **P2 starts with 1** | **46.7%** | **52.2%** | 1.2% | 53.5 | 19.5 |
| P2 starts with 2 | 46.7% | 52.3% | 1.0% | 54.1 | 19.3 |
| P1 starts with 1 | 58.6% | 39.9% | 1.5% | 53.4 | 19.5 |

- The military layer did not move the parity edge: P1 wins about 53% uncompensated, as in v2.
- The v2 komi of 1 point brings it to 46.7% / 52.2% here and 48.2% / 50.6% in a second 1,200-game run (before the last T4 tweak). Both are within about 2 standard errors of even.
- Keep the komi at 1 and log seats from the first playtests; humans will sit somewhere other than our AI on parity anyway.

### 6.2 Skill

Random stack pairs, both seats, 200 games per row:

| A vs B | A wins | B wins | Ties |
|---|---|---|---|
| greedy vs random | 72.5% | 25.8% | 1.8% |
| **smart vs greedy** | **96.8%** | 3.0% | 0.2% |
| smart vs milblind | 46.0% | 52.2% | 1.8% |
| smart vs smart with the simple Strike target rule | 47.8% | 50.8% | 1.5% |
| smart vs textblind | 48.8% | 50.2% | 1.0% |

- **Planning still dominates:** 97% against greedy, as in v2.
- **Knowing the military state adds nothing measurable** for a 1-ply AI (41–50% across 7 weight settings in a separate 300-game sweep). The military payoff follows from good tiling: the player who sets up good rallies also gets the materiel. The default Strike target ("the exposed tile worth most on open objectives, otherwise the Front") was as good as a lookahead target picker, so pre-selecting it is safe.
- **Card text is worth less than in v2** (49% against 56%), because the drills it used to plan around are gone.
- What this means for design is in section 8.4.

### 6.3 Starter stacks

Round robin, smart mirror, P2 +1, 240 games per pairing (row stack's win %):

| | T1 | T2 | T3 | T4 | **Average** |
|---|---|---|---|---|---|
| **T1 Spearhead** | – | 51.9 | 50.0 | 50.6 | **50.8** |
| **T2 Hold the Line** | 48.1 | – | 46.9 | 46.7 | **47.2** |
| **T3 Relay Net** | 50.0 | 53.1 | – | 41.2 | **48.1** |
| **T4 Shock and Supply** | 49.4 | 53.3 | 58.8 | – | **53.8** |

- **Spread 6.6 points** (47.2 to 53.8), within the brief's ±5 of 50. The worst pairing is T3 against T4 at 41.2%.
- **What it took:**
  - The Front stopped scoring at the end (two Assault stacks had averaged 58% and 66%).
  - Spot and Resupply each move the Front 1, and Fortify wins ground back, so every class can fight.
  - Rifle Team ("+1 Ammo") is strong: two copies made T4 a 60% stack, so the starter carries none and the card is flagged for the power test.
- Before balancing, the same four stacks with *no* military layer ranged from 41.7% to 55.7%: card choice, not the war, drives most of the spread.

### 6.4 How often the military fires

Smart mirror, random starter pairs, 800 games, per game (final rules and stacks):

| Event | Per game |
|---|---|
| Rallies | 3.7 |
| Materiel earned (both players) | 18.3 |
| Orders fired: Fortify / Spot / Strike / Resupply | 1.6 / 1.6 / 1.6 / 1.0 (**5.9 in all**) |
| Strikes to the Front / that destroyed a tile / fully soaked by Armor | 1.2 / 0.4 / 0.2 |
| Tiles destroyed, including Fire Missions | 0.5 |
| Armor points soaked | 1.2 |
| Streak 3 / 5 / 7 reached | 1.7 / 0.9 / 0.25 |
| Streaks of 2+ broken by a hit | 0.8 |
| Breakthrough wins | **8.5% of games** (7.2% in an earlier run) |
| A player lost 2+ tiles | 9.8% of games |
| Mid-game leader went on to lose | 35% |
| Lead changes per game | 1.3 |
| Final distance of the Front from centre | 1.8 steps |

- **Something military happens about every 3 placements**, and almost every game has at least one Spotter Drone; nearly every other game has a Supply Drop.
- **Fire Missions are a rare high point** (about 1 game in 5), as a 7-streak should be.
- **Breakthrough is a real but rare ending.** It shapes play, because players watch the Front, without replacing the puzzle.

### 6.5 Decision density and length

- **66.2** legal (tile, placement) pairs a turn, **6.0** distinct outcomes, best minus median **3.2 points** (v2: 58, 6.4, 2.8; an earlier v3 run gave 68.4, 6.3, 3.55). Orders make good and bad placements further apart.
- **19.5 placements a game** (v2: 17). The two insignia add about 2 quick placements; orders are automatic. At 15–20 seconds a turn plus about 3 seconds per order animation, that is **5½–7 minutes**, inside the 5–8 minute target.

### 6.6 Caveats

- The AIs are 1-ply heuristics. They can't see a barrage coming two turns ahead, so they probably under-use cover and the Front.
- Jam, Breaching Charge, Forward Observer, Armory and the rare insignia (Claymore, Smoke, Medal, Dog Tags) are not in the starter stacks and were not simulated; Jam and Breaching Charge exist in the sim library only. They join the v2 `power` test in the next pass.
- The size study re-shapes the starters mechanically (adding a plain banner, an extra base objective, and so on). It compares frames; it does not tune them.

---

## 7. Godot 4.4.1 notes (delta to v2)

- **Data:**
  - `ChassisDef` gains `shape: StringName` (`&"1x4"`, `&"2x2"`, `&"1x1"`) and `klass` (Assault, Recon, Engineer, Support).
  - Insignia are `ChassisDef` resources with `kind = CONTACT`, `shape = &"1x1"`.
- **Rules:**
  - `rally_rules.gd` keeps the board.
  - A new `front_line.gd` (a plain `RefCounted` owned by the match, not an autoload) holds the meters, Armor, the Front and the streaks.
  - Signals: `materiel_gained(player, klass, n)`, `order_fired(player, order, target)`, `streak_reward(player, tier)` and `breakthrough(player)`. The UI tweens off those, as in v2.
- **Preview:** the "if it closed now" preview runs the resolver *and* the end-of-turn orders on a cloned state, as `choose()` does in the sim, so it can show "Spot and Strike will fire".
- **Cover:** `is_in_cover(tile) -> bool` is a pure function of the board, so the inspect view can outline the covering tile.

---

## 8. Recommendation

1. **Ship both emblem sizes:** 2×2 objectives (hubs) and up to 2 1×1 insignia (fillers and gems), with the patch rule kept. No 1×1 hubs in versus play.
2. **Ship the Front Line military layer:** class materiel from rallies, four auto-firing orders, cover from Engineer geometry, a 3 / 5 / 7 streak, and a points win with a sudden-death Breakthrough.
3. **Starter stacks at 7 / 3 / 2**, builders allowed 6–7 / 3–4 / 0–2.
4. **Next pass:**
   - Put the military chassis through the v2 `power` test.
   - Prototype the "hold an order" option (a meter may wait, up to 6) in the demo, and see whether humans find timing decisions the AI can't. That is the most likely way to turn the military layer from an amplifier into a skill of its own.
   - Update `rally-point-v2-demo.html` into a v3 demo that scripts combo 1 and combo 2.

---

## 9. Questions for the studio head (recommended option first)

1. **Emblem sizes:**
   - **(a) 2×2 objectives + up to 2 1×1 insignia, patch rule kept (recommended).** The fewest dead cells, the most full boards, and the insignia is the faithful small emblem.
   - (b) 2×2 only, as in v2. Simplest, but no small-emblem collection item and no gem for the military layer.
   - (c) 1×1 hubs with an 8-cell ring as a separate **solo daily** puzzle. The most decision-dense frame we measured, but it leaves 20% of the board empty in versus play.
2. **Win condition:**
   - **(a) Points, with a Breakthrough Front that ends about 8–9% of games (recommended).**
   - (b) Points only; the military only moves points and tiles. Calmer, but there is no "we're being overrun" moment.
   - (c) HP race. Rejected in testing: rallies feed both players, so it erases the closing tension.
3. **How do orders fire?**
   - **(a) Automatically at 3, at the end of your turn (recommended for launch).** Turns stay one placement; the meters telegraph what is coming.
   - (b) You choose when to fire, and meters hold up to 6. More skill and timing, but a second decision every turn. Prototype it before choosing.
   - (c) You spend materiel on a menu of orders (full Puzzle Quest). The deepest, but the slowest turns and the most reading.
4. **Killstreak rewards:**
   - **(a) Fixed 3 / 5 / 7 at launch, a loadout of choices from season 2 (recommended).**
   - (b) A loadout from launch. A strong hook, but more to balance before launch.
   - (c) No streaks: the orders only.
5. **How harsh can attacks be?**
   - **(a) Strikes destroy only exposed banners and insignia; objectives and scored points are never touched (recommended).** 0.5 tiles destroyed a game, and cover is the counter.
   - (b) Strikes may also destroy open objectives. More dramatic, but it erases a player's setup and breaks the preview of future rallies.
   - (c) No destruction: Strikes only move the Front. The gentlest, but the "airstrike clears tiles" fantasy is lost.

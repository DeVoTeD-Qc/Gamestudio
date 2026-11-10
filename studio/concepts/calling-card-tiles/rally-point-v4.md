# Rally Point v4: Holding Orders, and the Simplest Rally Point

*Board task `cct-rally-hold` · project `cctiles` · Sr Game Designer · 2026-11-10*
*Follows [Rally Point v3](rally-point-v3.md) (Front Line), [v2](rally-point-v2.md) and [Part 3: emblems](emblems.md). Simulator: [`tools/rally_v4.py`](tools/rally_v4.py), derived from `rally_v3.py`; v1–v3 are unchanged, and v4 on its default settings reproduces v3 game for game (checked against `rally_v3.py`'s skill table, same seed). All names here are original. Call of Duty is named only as the inspiration.*

The head approved R1–R5 (v2), F1–F5 (v3) and E1–E4 (emblems). The launch rules are therefore: orders fire automatically at 3, fixed 3/5/7 streaks, Strikes destroy only exposed tiles, and points plus a Breakthrough Front. v3 §6.2 left one problem open: **an AI that understands the military layer does no better than one that ignores it.** This pass tests the v3 §8.4 idea (hold an order) and five other small tweaks. It also answers the head's comment after the v3 demo: *"I'm still very confused on the gameplay."*

**TL;DR**
- **"Hold an order" adds no skill.** Meters hold up to 6 and you choose when each one fires. A rule-based timing AI scores **49.6%** against a fire-at-3 AI, and a search-based one **49.7%**. An AI that holds *at random* scores **48.8%**, so even bad timing costs nothing. It adds a fire-or-hold decision on 28% of turns for no measurable gain. **Recommendation: don't ship it**, either for launch or as an option.
- **The orders matter, but their timing doesn't.** A player who never fires an order wins only **33%**. Fire-at-3 already collects that value, so the choice of *when* is nearly empty.
- **None of the six tweaks reaches 55%.** We tested Double Time, Suppression, Called Shot, Overwatch, Fire First (with and without holding) and combinations. The best was hold + Fire First at **52.4%** over 2,000 games (+2.4, just past 2 standard errors). That is too small to justify a second decision every turn.
- **The head's confusion is the bigger finding, and the sims back it.** Removing the cover rule changes nothing we can measure. Removing the four classes (one Ammo meter instead) costs 1.6 points of the planner's winning margin. The Front *lowers* that margin (16.8 with it, 19.0 without), because it adds swing. Most of the v3 rule weight buys drama, not decisions.
- **A Basic Rally Point fits in 5 lines** (section 6): the tiling puzzle plus one military rule, the Strike from a single Ammo meter. Against v3, Basic keeps the planning gap: smart beats greedy **97.4%** against 97.2%, with margins of +14.3 and +16.8. It has nearly the same decision density (65.8 options, 5.8 distinct outcomes; v3 67.9 and 6.1) and the same length (20.0 placements; v3 19.3). The best move beats the median by 2.0 points against v3's 3.5: v3's extra rules mostly widen the gap between good and bad moves. Everything else becomes a layer that players unlock.
- **Power test on the military chassis:** 16 of 17 military chassis sit inside the band. The **Bunker is too weak (−10.9)**. One non-military card, **Shock Line, is too strong (+10.3)**. Fixes: Bunker to Command 2 (−1.4) and Shock Line to "Breach +2" (+2.2). Both then sit in the band.
- **Correction to v3:** v3 §6.3's starter spread (47.2–53.8) does not reproduce. `rally_v3.py`, unchanged, now gives **40.8–61.4** at 300 games a pairing (T4 too strong, T3 too weak). The two fixes above narrow it to **45.7–54.4**.

> **Terms**, as in v3. A **banner** is a 1×4 tile, an **objective** a 2×2 emblem that rallies, and an **insignia** a 1×1 emblem. **Materiel** is what a rally pays into a **meter**, and a full meter fires an **order**. **Fire-at-3** is the v3 launch rule. A **timing AI** decides when to fire.

---

## 1. What was tested

### 1.1 The hold variant (`CFG hold=True`)

- A meter no longer fires by itself. It **holds up to 6**, and materiel past 6 is lost.
- At the end of your turn, you choose which meters at 3 or more fire. Each fires at most once, in v3's order: Fortify, Spot, Strike, Resupply.
- Materiel still in a meter at the end of the game scores nothing.

### 1.2 The AIs

Every AI places tiles with v3's `smart` evaluator. They differ only in how they fire orders.

| AI | Firing |
|---|---|
| `smart` | Fires every ready meter at 3, as in v3. This is the **fire-at-3 AI**. |
| `timer` | Rule-based timing: holds a Strike until a target is worth 2.5 or more, Spot is ready or already active, or the push would land unsoaked. Fires Spot only to pair it with a Strike, and never fires Spot again while one is waiting. Fortifies only when Armor would not be wasted or an enemy Strike is coming. Always fires before a meter would overflow and in the last 2 turns. |
| `plan` | Search-based timing: tries every subset of ready meters and keeps the best by v3's evaluator. Held materiel above 3 is worth 0.35 each, and nothing in the last turns. With Fire First, it also searches firing *before* placing, together with every Strike target. |
| `rhold` | Holds each ready meter at random half the time. A deliberately bad timer. |
| `nofire` | Never fires. It shows how much the orders are worth at all. |
| `aimer` | For auto Fire First: chooses the Strike target together with the placement that follows. |
| `milblind` | v3's smart AI, valuing only the tiling. |

### 1.3 The tweaks

| Tweak | Rule |
|---|---|
| **Double Time** | A meter at 6 may fire its order twice in one turn. |
| **Suppression 2** | A Strike that lands drains 2 from the victim's fullest meter, so holding has a risk. |
| **Called Shot** | An unspotted Strike can only destroy a tile that was already exposed when your last turn ended. The victim always gets one turn to take cover. |
| **Overwatch** | While you hold 3 or more Works, the next enemy Strike is cancelled and spends them. Holding Fortify becomes a shield. |
| **Fire First** | Held orders may fire *before* your placement. A Strike can open 4 cells that you then fill yourself. |
| **Fire First (auto)** | No holding. Meters that are full at the start of your turn fire then, before you place. The opponent sees them coming for a full turn. |

---

## 2. Results: timing skill

Random starter pairs, both seats, **800 games per cell** (2 standard errors is about ±3.5). Hold + Fire First and auto Fire First were re-run at 1,200 games. The table shows A's score against B, with ties counted as half.

| Rules | timer v smart | plan v smart | rhold v smart | nofire v smart | timer v plan | smart v milblind |
|---|---|---|---|---|---|---|
| v3 launch (fire at 3) | – | – | – | – | – | 49.1 |
| **hold (cap 6)** | **49.6** | **49.7** | **48.8** | **33.4** | 46.9 | 46.2 |
| hold + Double Time | 52.3 | 50.3 | 52.4 | 33.9 | 49.6 | 45.9 |
| hold + Suppression 2 | 46.4 | 50.4 | 47.1 | 32.6 | 50.8 | 50.2 |
| hold + Called Shot | 51.4 | 48.9 | 45.9 | 31.2 | 48.4 | 47.8 |
| hold + Overwatch | 47.4 | 50.8 | 49.2 | 34.6 | 46.9 | 45.2 |
| hold + Double Time + Suppression 2 | 53.5 | 51.3 | 48.0 | 34.3 | 48.6 | 47.8 |
| **hold + Fire First** (2 runs, 2,000 games) | **52.5** | **52.4** | 47.9 | 30.2 | 49.0 | 48.7 |
| hold + Fire First + Overwatch | 50.3 | 50.7 | 46.2 | 34.6 | 49.8 | 43.8 |
| Called Shot (fire at 3) | – | – | – | – | – | 46.1 |
| Suppression 2 (fire at 3) | – | – | – | – | – | 45.0 |
| **Fire First (auto)**, 1,200 games | – | 50.0 | – | – | – | 48.9 |
| | | *aimer v smart: 51.3* | | | | |

What it shows:
1. **No timing AI reaches 55%** under any rule set. Most cells sit within 2 standard errors of 50.
2. **Timing mistakes are free.** Random holding (`rhold`) scores 46–52%. A rule that rewards skill should punish the coin-flipper, and none of these do.
3. **The orders themselves are worth a lot.** Never firing loses about two games in three (30–35%). Fire-at-3 already gets nearly all of that value, because orders are good almost whenever they are ready. Strikes go mostly to the Front, Resupply always helps, and Spot persists until it is used.
4. **Fire First is the only tweak with a trace of skill**, about +2.5 for both timing AIs over 2,000 games. The edge comes from striking a tile and then filling its 4 cells yourself. Auto Fire First, which keeps only the joint choice of target and placement, gives +1.3, which is noise. A +2.5 edge from a 1-ply search could grow with humans, but it costs a second decision on about a quarter of turns.
5. **Knowing the military state still doesn't help our AI.** The tiling-only evaluator (`milblind`) beats `smart` 50–56% under every rule set, Basic included. The v3 military weights are slightly worse than ignoring the layer. A better evaluator might find more, but it agrees with the head's own line: *"It's a tiling and puzzle game mostly."*

**Ablation** (`python3 -I rally_v4.py 400 ablate`, 800 games per row) turns each timer rule off in turn. With all rules on, the timer scores 50.2%. Turning off the Strike, Spot, Fortify or overflow rule leaves it at 49.1–49.8%. Only one rule matters: **"fire everything before the game ends"**. Without it, the timer drops to **45.0%**. So the only lesson holding teaches is "don't get caught holding". That is a trap to avoid, not a skill to master.

---

## 3. Seat balance, length, density and stacks

Mirror of the best AI for each rule set: `smart` for fire at 3, `timer` for hold, `plan` for hold + Fire First, `aimer` for auto Fire First.

### 3.1 Seat balance (each starter against itself, 1,200 games)

| Rules | P1 / P2, no compensation | P1 / P2, P2 starts with 1 |
|---|---|---|
| v3 launch | 51.3 / 47.8 | 47.2 / 50.7 |
| hold | 55.9 / 42.6 | 49.0 / 49.5 |
| hold + Fire First | 54.8 / 43.9 | 49.7 / 49.4 |
| Fire First (auto) | 55.7 / 43.7 | 49.0 / 49.8 |

The 1-point komi keeps every variant inside 2 standard errors of even.

### 3.2 Length and military events (300 games per row)

| Rules | Placements | Orders F / S / St / R | Tiles lost | Breakthrough | Materiel lost to the cap | Fire-or-hold choices a game |
|---|---|---|---|---|---|---|
| v3 launch | 19.4 | 1.6 / 1.6 / 1.7 / 1.0 | 0.53 | 9.7% | 0 | 0 |
| hold | 19.2 | 1.6 / 1.5 / 1.6 / 0.9 | 0.48 | 8.0% | 0.6 | 5.5 |
| hold + Fire First | 19.5 | 1.5 / 1.7 / 1.7 / 0.9 | 0.70 | 9.3% | 0.4 | 5.2 (0.5 fired before placing) |
| Fire First (auto) | 19.9 | 1.7 / 1.7 / 1.8 / 1.0 | 0.92 | 6.0% | 0 | 0 |
| hold + Double Time | 19.2 | 1.5 / 1.6 / 1.7 / 0.9 | 0.42 | 13.3% | 0.5 | 5.1 |
| hold + Suppression 2 | 19.2 | 1.6 / 1.4 / 1.3 / 0.9 | 0.41 | 10.3% | 0.4 | 5.1 |
| hold + Called Shot | 19.2 | 1.7 / 1.3 / 1.5 / 1.0 | 0.42 | 9.0% | 0.6 | 5.6 |
| hold + Overwatch | 19.5 | 1.7 / 1.5 / 1.7 / 1.0 | 0.59 | 7.7% | 0.6 | 5.6 |

- Game length does not change: about 19.5 placements, or 5–7 minutes.
- Holding adds a decision on **5–6 turns a game (26–29% of turns)**, with 1.2 ready meters on each. The timer holds only about 1 meter in 5, which is another sign that holding rarely pays.

### 3.3 Decision density (placement choice, 300 games)

| Rules | Options a turn | Distinct outcomes | Best minus median |
|---|---|---|---|
| v3 launch | 67.7 | 6.2 | 3.54 |
| hold | 66.9 | 6.2 | 3.24 |
| hold + Fire First | 67.4 | 6.2 | 3.48 |
| Fire First (auto) | 66.8 | 6.3 | 2.52 |

Holding does not make placements matter more. Auto Fire First makes them matter *less* (2.52), because the orders that a placement sets up fire a turn later.

### 3.4 Starter stacks (round robin, P2 starts with 1, 300 games a pairing)

| Rules | T1 | T2 | T3 | T4 | Spread | Worst pairing |
|---|---|---|---|---|---|---|
| v3 launch rules (`rally_v4.py`) | 47.4 | 48.7 | 45.2 | **58.8** | 13.6 | 39.0 |
| `rally_v3.py`, unchanged, re-run | 51.3 | 46.5 | **40.8** | **61.4** | 20.6 | 34.7 |
| hold | 47.6 | 48.6 | 43.2 | 60.7 | 17.4 | 35.7 |
| hold + Fire First | 54.3 | 42.8 | 41.7 | 61.1 | 19.4 | 34.5 |
| Fire First (auto) | 57.2 | 43.3 | 41.3 | 58.2 | 16.9 | 36.8 |
| **v3 launch + the power fixes** (Bunker Command 2, Shock Line Breach +2) | 45.7 | 52.3 | 47.6 | 54.4 | **8.8** | 43.5 |

- **v3's 6.6-point spread was optimistic.** At 120 games a pairing it was within noise, and the larger runs show T4 Shock and Supply clearly ahead.
- None of the timing variants helps; Fire First makes the spread wider.
- The two power-band fixes (section 5) bring it to 8.8. That is the version to ship, and the 3.4 runs should be repeated after the next stack pass.

---

## 4. Verdict on "hold an order"

**Does it add skill?** No. 49.6% and 49.7% for two different timing AIs, and the coin-flip AI does as well.

**What does it cost?**
- One more decision on about 28% of turns.
- A new end-of-game trap: materiel that was never fired scores nothing.
- An overflow rule (cap 6).
- In the UI, an "arm or hold" toggle on four meters, next to a tile hand that already carries most of the reading.

**The head's confusion makes this an easy call.** Hold adds confusion and no measurable skill, so it should not ship, even as an option. If we want a timing decision later, Fire First is the only candidate with a signal (+2.5). It belongs in an advanced layer and in a human playtest, not in the launch rules. The same is true in Basic: with hold, the timing AIs score 48.5% and 51.6%.

---

## 5. The power test on the military chassis

v2's method, adapted to the v3 stacks:
- The plain stack is 4 + 3 plain banners, 2 + 1 standard objectives and the two classes' common insignia.
- **2 copies** of each chassis replace plain banners, or for an objective the standard objectives, or for a rare insignia the common insignia. A common insignia is tested against a plain banner slot, which is the stack builder's real choice.
- Smart mirror, launch rules, 500 games per chassis (2 SE about ±4.5).
- The band is the median ±6. The median is **+2.3**, so the band runs from −3.7 to +8.3.
- v3 §5.1's untested chassis are now simulated too: Forward Observer, Armory, Claymore, Smoke, Medal and Dog Tags.

| Chassis | Class / rarity | Power | In band? |
|---|---|---|---|
| Sandbag Line (Rally: +1 Works) | Engineer C | +5.6 | yes |
| Claymore (insignia) | Assault R | +5.4 | yes |
| Rifle Team (Rally: +1 Ammo) | Assault C | +4.6 | yes |
| Supply Crate (insignia) | Support C | +3.3 | yes |
| Ammo Cache (insignia) | Assault C | +2.8 | yes |
| Armory (objective) | Assault E | +2.8 | yes |
| Medal (insignia) | Support R | +2.5 | yes |
| Sandbags (insignia) | Engineer C | +2.3 | yes |
| Medic Line (Rally: +1 Supply) | Support C | +1.9 | yes |
| Smoke (insignia) | Engineer R | +1.6 | yes |
| Forward Observer | Recon R | +1.2 | yes |
| Breaching Charge | Assault R | +0.2 | yes |
| Flare (insignia) | Recon C | −0.4 | yes |
| Jammer | Recon E | −1.0 | yes |
| Spotter (Rally: +1 Intel) | Recon C | −2.1 | yes |
| Dog Tags (insignia) | Recon R | −2.8 | yes |
| **Bunker** (objective) | Engineer R | **−10.9** | **no, too weak** |

Non-military chassis from the same run, for reference: **Shock Line +10.3 (out)**, Liaison E>S +7.5, Liaison A>R +6.5, Quartermaster −4.3 (just out); the rest sit in the band.

- **Bunker:** Command 1 is too low a price for cover, and in our sims cover is worth almost nothing (section 6.2). With **Command 2** it tests at **−1.4**. Apply that.
- **Shock Line:** Pioneer (+1 per objective touched on placement) is free points. As **"Breach +2"** it tests at **+2.2**. Apply that. T1 and T4 both carry it, and the fix takes most of T4's lead.
- **Recon is the weakest class** (Spotter −2.1, Dog Tags −2.8, Flare −0.4, Jammer −1.0). That is inside the band, but watch it.
- **Insignia are a fair slot.** A common insignia in place of a plain banner tests at −0.4 to +3.3, so the 2-insignia cap is a style rule, not a power rule.

---

## 6. The simplest Rally Point

The head watched the v3 demo and said: *"I'm still very confused on the gameplay."* We treat that as the key finding of this pass. v3 asks a new player to hold four shapes, a rally trigger, contact scoring, a patch rule, four materiels, four orders, cover, Armor, a Front and three streak tiers before they understand why they placed a tile. The sims say most of that does not create decisions.

### 6.1 The core loop in 5 lines (the Basic ruleset)

> 1. **On your turn, place one tile from your hand of 3 on empty squares:** a banner (1×4), an objective (2×2) or an insignia (1×1). An objective may also cover a closed-in gap of 1–4 squares, but then it never rallies.
> 2. **An objective rallies the moment all 8 squares around it are filled.** The board edge counts as filled.
> 3. **When it rallies, every square of a tile touching it scores 1 for that tile's owner, or 2 if the tile's colour matches the objective.** Whoever closed it scores 1 more.
> 4. **Each rally also gives you 1 Ammo for every one of your tiles touching it. At 5 Ammo you Strike:** remove an enemy tile that touches an open objective. If there is none, score 1.
> 5. **When the board is full or no one can place, the most points wins.** The second player starts with 1 point.

That is the whole Basic game, with no card text, no Command, no end scoring, one meter and one order. The simulator runs exactly this ruleset as `BASIC (the 5 lines)` (`python3 -I rally_v4.py 400 rules r=22`).

**Line 4 is the one military rule.** Of the military rules, it is the one closest to the head's brief: *"putting cards together triggers an attack"*. It is also the only order whose result a new player can see: a tile disappears, and the squares it leaves open are a new puzzle. Its target rule ("touches an open objective") also teaches the idea of "exposed" without a cover rule.

### 6.2 Every v3 rule, ranked by what it adds against what it costs to learn

**Adds** is measured where we could, by removing the rule from v3 and seeing what changes (smart mirror plus smart against greedy, 600 games per row; `rules r=7..16`). In v3, the planner's margin over greedy is **+16.8**, the best move beats the median by **3.47**, and **23.5%** of boards end full.

**Learn cost** runs from 1 (one number on a familiar idea) to 5 (a new system with exceptions), judged on the nouns, numbers and exceptions a player must hold.

| # | Rule | What it adds in the sims | Learn cost | Where it goes |
|---|---|---|---|---|
| 1 | Place one tile on empty squares; three shapes | It is the game | 1 | **Basic** |
| 2 | An objective rallies when its border is full; the edge counts | It is the game | 1 | **Basic** |
| 3 | Contact squares score 1, or **2 if matched** | Without the match bonus, the margin falls 16.8 → **12.4**, the largest skill loss of any rule | 1 | **Basic** |
| 4 | **Patch rule** | Without it, full boards fall 23.5% → **7.8%** and empty cells rise 4.1 → 6.3. In Basic the margin falls 14.3 → 10.8 | 2 | **Basic** |
| 5 | Closer +1 | Seat balance: without it, P1 wins 55.5% even with the komi | 1 | **Basic** |
| 6 | Komi (P2 starts with 1) | P1 wins 51–55% without it | 1 | **Basic** |
| 7 | Insignia (1×1) | Dead cells 3.6 → 3.5 and 4 quick "plug" turns a game (v3 §1); the small emblem for the collection | 1 | **Basic** (it is one of the three shapes) |
| 8 | Redeploy and pass when nothing fits | Needed for the rules to work, rare in play | 1 | Basic, handled by the UI |
| 9 | One Ammo meter and Strike at 5 (Basic's version of the military) | Over tiling only, the best move beats the median by 1.69 → **2.00**, the margin rises 13.7 → 14.3, and tiles get removed (1.0 a game) | 2 | **Basic** |
| 10 | Command (+2 to the objective's owner) | Margin 16.8 → 15.6 without it; in Basic, adding it gives +0.7 | 1 | Layer 2 (printed on objectives) |
| 11 | End scoring for objectives that never rallied | In Basic, adding it gives +1.7 margin; it is an end-of-game exception | 2 | Layer 2 |
| 12 | Card text (keywords) | Margin 16.8 → 16.3 without it, distinct outcomes 6.1 → 5.8. Small for skill, large for the collection | 3 | Layer 2 |
| 13 | Four classes, four meters, four orders (Spot, Fortify, Resupply join Strike) | With one meter instead, the margin is 15.2 against 16.8, the spread 3.25 against 3.47, and 1.77 tiles are lost a game against 0.5 | 4 | Layer 3 |
| 14 | The Front and Breakthrough (with Armor soaking pushes, and unused Armor scoring) | Without it, the margin *rises* 16.8 → 19.0 and the spread falls 3.47 → 2.68. It adds swing and the "overrun" moment; 9% of games end by Breakthrough | 4 | Layer 4 |
| 15 | Killstreaks 3 / 5 / 7 (Spotter Drone, Supply Drop, Fire Mission) | Without them, the spread falls 3.47 → 2.79 and Breakthroughs 9.0% → 3.7%. Drama and comebacks rather than decisions | 3 | Layer 5 |
| 16 | **Cover** (Engineer tiles and Bunkers protect what they touch) | Nothing measurable: margin 16.7, spread 3.35, 0.61 tiles lost instead of 0.48 | 4 | Layer 4 at most. Cut candidate (question 3) |
| 17 | Hold an order (not in v3) | Nothing (section 4) | 3 | Don't ship |

**The pattern:** rules 1–9 carry the puzzle and most of the skill. Rules 13–16 add spectacle and spread but little skill, and cost the most to learn. That is the right shape for a *layer* system: the fantasy grows as the player does, without front-loading the reading.

### 6.3 Basic against v3 in the simulator

800 games per row (smart mirror; smart against greedy; greedy against random). `rally_v4.py 400 rules`.

| Ruleset | Smart v greedy (margin) | Greedy v random | Options / distinct / best − median | Placements | Full boards | Tiles lost | Strikes or orders | P1 with komi / without |
|---|---|---|---|---|---|---|---|---|
| **v3 launch** (all layers) | 97.2% (+16.8) | 69.1% | 67.9 / 6.1 / 3.47 | 19.3 | 27.9% | 0.49 | 5.8 orders | 49.2 / 55.1 |
| **BASIC (the 5 lines)** | **97.4% (+14.3)** | 72.9% | **65.8 / 5.8 / 2.00** | **20.0** | 23.5% | 0.98 | 1.8 Strikes | 47.0 / 52.5 |
| Basic, no Strike (tiling tutorial) | 98.1% (+13.7) | 72.4% | 67.3 / 5.7 / 1.69 | 19.1 | 31.9% | 0 | 0 | 47.0 / 52.2 |
| Basic, Strike at 4 | 96.2% (+15.1) | 70.0% | 65.5 / 5.9 / 2.08 | 20.4 | 23.4% | 1.40 | 2.6 | 52.1 / 54.8 |
| Basic, Strike at 6 | 96.7% (+14.0) | 71.2% | 66.3 / 5.9 / 1.95 | 19.7 | 26.2% | 0.67 | 1.4 | 51.9 / 49.2 |
| Basic + Command | 96.6% (+15.0) | 72.4% | 66.3 / 6.0 / 2.28 | 19.9 | 23.6% | 0.95 | 1.7 | 51.0 / 52.1 |
| Basic + end scoring | 98.2% (+16.0) | 61.7% | 66.2 / 6.0 / 2.06 | 20.0 | 26.1% | 1.00 | 1.8 | 49.4 / 54.2 |
| Basic, no patch rule | 89.3% (+10.8) | 64.4% | 71.2 / 5.9 / 2.10 | 18.3 | 5.1% | 0.89 | 1.5 | 43.1 / 51.1 |
| Basic + hold (cap 10, twice the Strike cost) | timer 48.5%, plan 51.6% against fire at 5 | | | | | | | |
| *An earlier Basic draft with v3's Ammo rates (insignia 2, objective owner +1, Strike at 3), 600 games* | 97.4% (+19.6) | 67.6% | 64.9 / 6.3 / 2.58 | 22.0 | 12.3% | **3.62** | 5.5 | 51.0 / – |

**Reading the table:**
- **Skill gap: the same.** The planner beats greedy 97% in both. Its margin is 2.5 points lower in Basic (+14.3 against +16.8), but higher than tiling alone (+13.7). Greedy beats random by a little more in Basic: obvious good moves stay obvious.
- **Decision density: nearly the same.** There are about 66 legal moves a turn and about 6 that really differ. What v3 adds is *spread*: the best move beats the median by 3.5 points instead of 2.0. The extra 1.5 points come from orders that fire *because of* a placement. Mistakes cost more in v3, but players don't get more real choices.
- **Length: the same.** 20.0 placements against 19.3, so 5–7 minutes.
- **Strike tuning:** at 5, Basic removes about 1 tile a game, against 0.5 in v3. With v3's Ammo rates, a Strike at 3 removed 3.6 tiles a game, which would be miserable, and it emptied the board (12% full). At 4 there are 1.4 removals and the seats tilt; at 6 there are 0.7 and the Strike is barely felt. **5 is the pick.**
- **Seats:** with the 1-point komi, P1 wins 47.0%. Without it, P1 wins 52.5%. Both are about 1.5 standard errors from even, so keep the komi for consistency with the later layers, and log seats in playtests.
- **Military knowledge** (smart against milblind) is 45.1% in Basic, as in v3. The Strike is a consequence of good tiling, not a separate plan, and that is fine for a first ruleset.

### 6.4 The layer ladder (for the tutorial)

Each layer adds **one idea**, keeps every earlier rule, and unlocks after a fixed number of games (or with a skip toggle in Settings). The UI shows only the meters and markers of unlocked layers.

| Layer | Name | Adds | New things on screen | Unlock |
|---|---|---|---|---|
| **0** | **Tiles** (tutorial) | Lines 1, 2, 3 and 5: place, rally, score, win | Board, hand of 3, objective border counter (e.g. "6/8"), the "if it closed now" preview | Start |
| **1** | **Basic** | Line 4: Ammo and the Strike | One Ammo meter (5 pips) and the Strike target outline | After the tutorial |
| **2** | **Cards** | Card text (Breach, Charge, Liaison and so on), Command on objectives, end scoring of objectives that never rallied; personal stacks | Keyword icons on tiles, long-press card text | After 3 games |
| **3** | **Classes** | Ammo becomes four meters (Ammo, Intel, Works, Supply) firing at 3: Strike, Spot, Fortify (Armor scores at the end), Resupply | Four meters, Armor pips | After 6 games |
| **4** | **Front Line** | The Front and Breakthrough; Armor soaks pushes; Strikes may push the Front; cover (if kept: question 3) | The Front track | After 10 games |
| **5** | **Streaks** | 3 Spotter Drone, 5 Supply Drop, 7 Fire Mission | Streak counter and reward pop-ups | After 15 games |

Layer 5 is the full v3 launch ruleset that the head approved. Ranked and competitive play use layer 5. Casual and friend matches let the host pick a layer.

**For the UI/UX agent building the tutorial (layer 0 → 1), one beat per step, scripted board:**
1. "Place a banner." Only empty 1×4 slots glow.
2. "Place an objective." Show its 8-square border with a counter, "0/8".
3. "Fill the border." The player places the closing tile; the rally scores square by square, with matched squares flashing ×2 and the closer's +1.
4. "Use the edge." An objective on the board edge needs only 4 or 6 squares.
5. "Plug a gap." An insignia fills a 1-square hole and closes an objective.
6. "Patch a gap." An objective covers a 3-square pocket and is greyed "never rallies".
7. *(Layer 1)* "Rallies give Ammo." The meter fills; at 5 the Strike fires and removes an enemy tile from an open objective; the open squares glow as a chance.
8. "Win." The board fills and the totals compare. P2's starting point is shown from turn 1.

Every element in these steps keeps the studio's inspect rule: long press (touch) or right click (desktop) on any tile, objective or meter opens its zoomed view, and the objective's view shows the "if it closed now" preview.

---

## 7. Recommendation

1. **Don't ship "hold an order"**, either for launch or as an option. It adds no measurable skill (49.6–49.7%, with a random holder at 48.8%) and costs a decision on 28% of turns. Keep orders firing automatically at 3, as approved.
2. **Accept that the military layer amplifies the tiling rather than adding a second skill**, and design around that instead of fighting it. It is the right shape for "a tiling and puzzle game mostly". Its job is fantasy, readable consequences and comebacks, so it should arrive in layers.
3. **Ship the Basic ruleset (section 6.1) as the first thing a player learns**, and unlock layers 2–5 over the first ~15 games. The 5 lines are the tutorial script and the rules card.
4. **Apply the two power fixes:** Bunker Command 2 and Shock Line "Breach +2". The starter spread falls from 13.6–20.6 points to 8.8. Correct v3 §6.3's published spread.
5. **Park Fire First** (+2.5 for timing AIs) for a human playtest of layer 5 players. It is the only timing rule with a signal.
6. **Next pass:** re-tune the AI's military weights (the tiling-only AI beats it 54%), re-run the stack round robin with the fixes at 600 games a pairing, and build the layer 0–1 tutorial from section 6.4.

---

## 8. Godot 4.4.1 notes (delta to v3)

- **`RulesetDef` resource** (`ruleset_basic.tres` and so on): booleans for `card_text`, `command`, `end_scoring`, `classes`, `front`, `cover`, `streaks`, plus `strike_threshold: int` (5 in Basic, 3 from layer 3). `rally_rules.gd` and `front_line.gd` read it; nothing is hard-coded per layer. The sim's `CFG` keys map 1:1 to these fields.
- **Layer unlocks** live in the profile save (`games_played`, `layer_unlocked`), not in the ruleset. An autoload `Progression` emits `layer_unlocked(layer: int)` for the UI.
- **The UI hides what the ruleset turns off.** For example, `FrontTrack.visible = ruleset.front`. The Basic HUD is the board, the hand, the score and one Ammo meter.
- **No hold UI** is needed. If Fire First is playtested later, it is an `order_armed(player, order)` signal plus a pre-placement step in the turn state machine.

---

## 9. Questions for the studio head (recommended option first)

1. **How do new players meet Rally Point?**
   - **(a) Basic first (the 5 lines), with layers 2–5 unlocking over the first ~15 games; ranked play uses the full rules (recommended).** It answers "I'm confused" directly, and the sims show Basic keeps the puzzle's skill and length.
   - (b) The full v3 rules from game 1, with a longer tutorial. Nothing to unlock, but it is the version that confused you.
   - (c) Ship only Basic plus card text at launch, and add the military layers as season content. The simplest launch, but the Call of Duty-inspired fantasy arrives late.
2. **"Hold an order":**
   - **(a) Don't ship it; orders keep firing automatically at 3 (recommended).** No measurable skill, and a decision on 28% of turns.
   - (b) Playtest only the Fire First version (hold, and fire before or after placing) with experienced players. It is the only variant with a small edge (+2.5).
   - (c) Ship hold as an option for private matches.
3. **The cover rule** (approved in v3 as "Strikes destroy only exposed tiles"):
   - **(a) Simplify it: a Strike may remove only a tile that touches an open objective (Basic's rule), and protection comes from cards (Bunker, Smoke) and Armor (recommended).** In the sims, removing cover changed nothing measurable, and it is the rule that most needs explaining.
   - (b) Keep Engineer cover, but only from layer 4 (Front Line).
   - (c) Keep cover as v3 has it, in every layer from 3 up.

---

*Reproduce:* from `tools/`, run `python3 -I rally_v4.py 400 hold v=0,1,2,3,4,5,6,7,8,9,10,11` (timing table), `150 seat stacks length density v=0,1,8,11`, `250 power`, `300 rules` (ladder and ablation; `r=22..29` for Basic) and `400 hold v=12` (Basic + hold) and `400 ablate`. Each section accepts `seed=N`; the seeds used here are in the commit message. Runs take 3–15 minutes each on one core.

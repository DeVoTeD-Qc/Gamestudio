# Feature Specification: Banner Wall

*Mid Game Designer (performed by the Master Orchestrator in role) · 2026-11-03 · Phase: Design · Status: **approved 2026-11-03** (starting values in §4 and §9 confirmed for playtesting; Cipher Lock in; rewards cosmetic only; see `../../DESIGN_REVIEW.md` Decisions)*
*Recommended concept A from `../vision.md`, with a slice of concept B (album, sets, Triptychs). All card names and art briefs are original. The prototype is a standalone concept demo, not a mod or recreation of Call of Duty.*

## 1. Overview
**Banner Wall** is a 1v1 placement duel, about 3 minutes long, where calling cards are the pieces. Players take turns placing 5 cards each onto a 10-slot **brick-wall board**. A placed card captures adjacent enemy cards when its facing value is higher. At the end, the player who controls the most of the wall wins. A card's power comes from **how it was earned**, so a player's hardest-won cards are their best pieces.

**Rules in one breath:** *Three numbers per card. Place a card; any enemy neighbor whose facing number is lower turns to your color. Most cards wins. Your Signature counts double.*

## 2. User stories
- As a CoD player, I want my hardest calling cards to be my strongest pieces, so the grind behind them means something.
- As a collector, I want to see which cards I'm missing and why they'd help my lineup, so I have a reason to chase them.
- As a player waiting in matchmaking, I want a duel that fits in a few minutes, so downtime becomes fun.
- As a puzzle fan, I want handcrafted puzzles and hidden combinations, so there are secrets to find.
- As a newcomer, I want a fair match even with a small collection, so I'm not crushed by veterans.
- As a player who buys bundles, I want my store cards to look special, without anyone saying I paid to win.

## 3. The card

| Attribute | Values | Notes |
|---|---|---|
| **Top / Side / Bottom** | 1–9 each | Top faces the cards above, Side faces the left and right neighbors, Bottom faces the cards below |
| **Clearance** (rarity and power tier) | 1 Issue · 2 Merit · 3 Distinction · 4 Legend | The stat budget (Top + Side + Bottom) is **13 / 15 / 17 / 19** |
| **Origin** (how it was earned) | Challenge, Mastery, Event, Prestige, Ranked, Secret, Showcase (store) | Sets the card's **trait** (see 4.4) |
| **Set** | A themed series of 2–6 cards | Same-set neighbors get **Set Link** |
| **Signature flag** | Lineup-level choice | One per lineup |
| **Frame** | Standard, set-complete (animated border), Showcase (premium animated) | Cosmetic only |

**Anti-pay-to-win rule (binding):** Showcase (store/bundle) cards are always **Clearance 1 with no trait**. Battle-pass cards (live game only) are Clearance 1–2 with no trait. Store cards get the flashiest *frames*, never more power.

**Live-game stat formula (pitch, not built in the prototype):** Clearance = f(origin, difficulty tier). For example, an easy challenge is 1, a hard challenge is 3, top mastery is 4, prestige is 3–4, and ranked rewards are 2–4 by rank tier. The budget is split across Top/Side/Bottom by a per-set **shape** (e.g. one set leans "tall", another "wide") plus small seeded variance. Designers hand-tune only Clearance 4 cards. Hundreds of existing cards can get stats automatically.

## 4. Rules

### 4.1 Board: "the wall"
Ten wide slots in three offset rows, like brickwork:

```
   [ a1 ][ a2 ][ a3 ]          row A: 3 bricks
[ b1 ][ b2 ][ b3 ][ b4 ]       row B: 4 bricks, offset by half a brick
   [ c1 ][ c2 ][ c3 ]          row C: 3 bricks
```

Adjacency:
- **Side neighbors:** the bricks to the left and right in the same row.
- **Above / below:** each brick in row A touches the two row-B bricks under it (a1 touches b1 and b2; a2 touches b2 and b3; a3 touches b3 and b4). Row C works the same way from below.
- The middle bricks b2 and b3 have **6 neighbors**; corner bricks have 3. Placement matters.

### 4.2 Lineup (pre-match tactical choice)
- Pick **5 cards** from your collection. The total **Clearance must be 12 or less**, with **at most one Legend** (Clearance 4).
- Mark **one** as your **Signature**. It counts **double** for whoever controls it at the end.
- The lineup is visible to both players before the match (like checking someone's loadout). Hand order is not.
- New players get a **loaner lineup** if their collection can't make a full 5.

### 4.3 Turn flow
1. A coin flip picks the first player. Players alternate placements, one card per turn, until all 10 slots are full (5 cards each).
2. **On placement**, compare the placed card with each **adjacent enemy card**:
   - against a card **above**: placed **Top** vs that card's **Bottom**
   - against a card **below**: placed **Bottom** vs that card's **Top**
   - against a **side** card: placed **Side** vs that card's **Side**
   - **Higher wins**: that enemy card is captured (turns to your color). **Ties do nothing** unless a trait says otherwise.
3. Placement bonuses (**Set Link**, **Clutch**) apply only to the placed card's comparisons on that turn. Defending values never change.
4. There are no chain captures in the base rules (this is a tuning option, see 9).

### 4.4 Traits (one per origin)

| Origin | Trait | Rule text (as shown on the card) |
|---|---|---|
| Challenge | **Steady** | Can't be captured by a card with lower Clearance. |
| Mastery | **Veteran** | Also captures on ties. |
| Event | **Ambush** | Placed face-down: it captures nothing and can't be captured. At the start of your next turn it flips face-up and captures with +1 to all values. If the wall fills first, it flips before scoring. |
| Prestige | **Reclaim** | On placement, takes back every adjacent card from your own lineup, whatever the values. |
| Ranked | **Clutch** | If you're behind on score when you place it, +2 to all values for this placement. |
| Secret | **Cipher** | On placement, copies the trait of one adjacent card (your pick). |
| Showcase (store) | none | Premium animated frame. Clearance 1. |

**Set Link (all cards):** if the placed card touches at least one of **your own** cards from the **same set**, it gets +1 to all values for this placement.

### 4.5 Scoring and the Signature
- 1 point per card you control at the end. Each **Signature** you control counts **2**, including the enemy's if you captured it.
- **Triptych bonus:** +1 if three of your cards that form a hidden **Triptych** (see 5) sit in three consecutive slots of one row.
- **Ties go to the first player.** The second player gets the last placement, so the tie-break offsets it. This is a tuning flag.
- Capturing an enemy Signature plays the **"Carded!"** moment: their banner shatters into your color, with a callout sting. This is the social flex.

### 4.6 Worked example
You place **Neon Rain** (T4 S6 B5, Mastery/Veteran, Night Shift) into **b2**. Its neighbors are a1 and a2 above, c1 and c2 below, and b1 and b3 at the sides.
- c1 already holds your own **Graveyard Shift** (Night Shift), so **Set Link** applies: for this placement Neon Rain fights as **T5 S7 B6**.
- a1 is an enemy **Glacier** (B6). Top 5 vs Bottom 6: no capture. *(With 5 vs 5 it would capture, because Veteran wins ties.)*
- b3 is an enemy **Mayday** (S5). Side 7 vs 5: **captured**.
- c2 is an enemy **Frostbite** (T3, Steady, Clearance 1). Bottom 6 vs 3, and Neon Rain's Clearance 2 isn't lower, so Steady doesn't protect it: **captured**.
- a2 and b1 are empty. Result: 2 captures.

## 5. Collection layer (the album slice from concept B)
- **Album:** one page per set, with silhouettes for unowned cards. Each silhouette shows **how to earn it** and its **Clearance and trait**, so players see what they're chasing and why.
- **Set completion:** owning a full set grants a **title** (e.g. "Night Owl") and an **animated set frame** on all that set's cards.
- **Triptychs:** hidden 3-card combinations. Their album slots show "???" plus a cryptic hint. The first time you score one in a duel, it is revealed with a panoramic merged art strip and a title.
- **Cipher glyphs:** four cards (one per main set) carry a small original glyph in their art. The album's **Cipher Lock** takes a 4-glyph code. The right order (hinted by set numbering) unlocks **Key Fragment**.
- **Dossiers:** five handcrafted puzzles with a fixed board and a fixed hand. Each teaches one rule and pays out a card or a title.

### 5.1 Demo Triptychs
| Triptych | Cards | Hint shown | Reward |
|---|---|---|---|
| Midnight Run | Graveyard Shift + Neon Rain + Last Train | "The city's last ride, three stops long." | Title *Night Owl+*, panorama |
| Cold Signal | Frostbite + Mayday + Dead Air | "Someone's calling from the ice." | Title *Ice Radio*, panorama |
| Open Book | Null Glyph + Key Fragment + Honor Roll | "Old honor, new code." | Title *Codebreaker*, panorama, gold Cipher frames |

### 5.2 Demo Dossiers
| # | Name | Teaches | Goal | Reward |
|---|---|---|---|---|
| D1 | First Contact | Capture, facing values | Capture 3 cards in 2 placements | Mayday (if not owned) or title |
| D2 | Same Page | Set Link | Win using exactly 2 placements | Service Ribbon frame |
| D3 | Lights Out | Ambush timing | Capture 2 with one Ambush spring | Flare Up gold frame |
| D4 | Carded | Signature, Reclaim | Capture the enemy Signature and win | **Null Glyph** |
| D5 | Clean Copy | Cipher | Win by copying an enemy trait | Title *Copycat* |

## 6. Sample card list (20 original cards)

Values are **T / S / B**. Starting ownership is for the demo only (see 7).

| # | Card | Set | Origin | Clr | T / S / B | Trait | How it's earned (live game, original flavor) | Demo start | Art brief (original) |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Graveyard Shift | Night Shift | Challenge | 1 | 5 / 4 / 4 | Steady | Win 10 matches on night maps | Owned | Empty bus stop under a flickering sign, sodium orange |
| 2 | Neon Rain | Night Shift | Mastery | 2 | 4 / 6 / 5 | Veteran | Reach tier 2 mastery on any SMG | Owned | Rain streaks over magenta/cyan signage, wet asphalt |
| 3 | Last Train | Night Shift | Event | 2 | 6 / 4 / 5 | Ambush | Night-event reward | Owned | Subway car lights receding into a tunnel |
| 4 | City Never Sleeps | Night Shift | Prestige | 4 | 7 / 5 / 7 | Reclaim | Reach prestige 3 | Locked: beat the Hard rival | Skyline panorama, every window lit, gold trim |
| 5 | Frostbite | Whiteout | Challenge | 1 | 3 / 6 / 4 | Steady | 25 eliminations on snow maps | Owned | Ice crystals creeping over a glove |
| 6 | Snow Blind | Whiteout | Event | 3 | 6 / 5 / 6 | Ambush | Winter event reward | Owned | Pure-white field, one silhouette, flare glow |
| 7 | Polar Night | Whiteout | Ranked | 3 | 5 / 7 / 5 | Clutch | Reach the 3rd ranked tier | Locked: win 3 duels in a row | Aurora over a dark ridge |
| 8 | Glacier | Whiteout | Mastery | 2 | 7 / 2 / 6 | Veteran | Tier 2 mastery on any sniper rifle | Owned | Cracked blue ice wall, vertical strata |
| 9 | Mayday | Signal Fire | Challenge | 2 | 5 / 5 / 5 | Steady | Revive 50 squadmates | Owned | Distress flare arcing over dark water |
| 10 | Flare Up | Signal Fire | Event | 1 | 6 / 3 / 4 | Ambush | Summer event reward | Owned | Burst of red flares, film-grain |
| 11 | Dead Air | Signal Fire | Mastery | 3 | 4 / 8 / 5 | Veteran | Top mastery on any marksman rifle | Locked: capture 20 cards total | Old radio, needle at silence, static bands |
| 12 | Open Channel | Signal Fire | Ranked | 2 | 4 / 5 / 6 | Clutch | Win 10 ranked matches | Owned | Antenna tower with pulsing rings |
| 13 | Brass Tacks | Old Guard | Challenge | 3 | 6 / 6 / 5 | Steady | 100 eliminations without dying across matches | Owned | Brass tacks pinning a torn map |
| 14 | Service Ribbon | Old Guard | Mastery | 1 | 4 / 5 / 4 | Veteran | Level any weapon to max | Owned | Striped ribbon bar on felt |
| 15 | Long Watch | Old Guard | Ranked | 4 | 6 / 7 / 6 | Clutch | Finish a ranked season at the top tier | Locked: beat the Hard rival with no Legend in your lineup | Lone lighthouse beam across fog |
| 16 | Honor Roll | Old Guard | Prestige | 3 | 5 / 6 / 6 | Reclaim | Reach prestige 1 | Locked: win 5 duels | Engraved plaque wall, names blurred to abstract lines |
| 17 | Null Glyph | Cipher | Secret | 2 | 5 / 5 / 5 | Cipher | Hidden challenge (secret) | Locked: Dossier D4 | Black field, one glowing unknown symbol |
| 18 | Key Fragment | Cipher | Secret | 3 | 6 / 5 / 6 | Cipher | Solve the Cipher Lock | Locked: Cipher Lock | Broken key, edges glowing teal, glyph etched |
| 19 | Chrome Tiger | Showcase | Store | 1 | 5 / 4 / 4 | none | Store bundle (simulated, free in demo) | Owned | Chrome tiger head, animated reflections |
| 20 | Gold Leaf | Showcase | Store | 1 | 4 / 5 / 4 | none | Store bundle (simulated, free in demo) | Owned | Gilded leaf pattern, animated shimmer |

Budget check: every card's T + S + B equals its Clearance budget (13 / 15 / 17 / 19). Cipher glyphs appear on cards 1, 5, 9 and 13.

## 7. Demo collection and unlocks
- The player starts with **13 of 20** cards (Owned above). The other 7 are locked, with their unlock goal shown in the album.
- In the live game, these would be earned in the shooter. The demo simulates "earning" with duel goals so the chase loop can be tested.
- **Rival AI** (3 levels): **Quartermaster** (Easy: random legal move, takes the best capture 50% of the time), **Archivist** (Normal: greedy, maximizes immediate points), **Warden** (Hard: 2-ply lookahead, values Signature safety). Each rival has a fixed themed lineup within the same Clearance cap.

## 8. Sample session walkthrough (demo, ~12 minutes)
1. **Title → Album (0:00).** "13 / 20 cards." Night Shift is 3/4. The silhouette for *City Never Sleeps* reads "Legend · Reclaim · Unlock: beat Warden". A Triptych slot shows "???" and *"The city's last ride, three stops long."*
2. **Dossier D1, First Contact (0:30).** A fixed hand of 2. The player learns that Top faces up and Side faces sideways, and captures 3. A "Carded!" sting demo plays.
3. **Lineup (2:00).** The player builds Graveyard Shift (1), Neon Rain (2), Last Train (2), Snow Blind (3) and Mayday (2): Clearance 10/12. They notice the cap leaves room for a Legend they don't own yet. They mark **Snow Blind** as Signature.
4. **Duel vs Archivist (3:00).** The player opens in a corner (a1) to protect against side attacks. Archivist takes b2 (6 neighbors). The player plays **Last Train** face-down next to two enemy cards (Ambush). Next turn it springs with +1 and takes both. Mid-game they're behind 3–4, Archivist plays **Polar Night** (Clutch +2) and captures their Signature: "Carded!" The player answers with **Neon Rain** into b3 with Set Link off Graveyard Shift and recaptures. Final: 7–5 win (Signature double).
5. **Result (6:00).** Progress toward "win 3 in a row" (Polar Night) is 1/3. Toast: "Graveyard Shift + Neon Rain + Last Train were *almost* in a row..." This nudges toward the Triptych.
6. **Two more duels (6:30–11:00).** The player arranges the three Night Shift cards in row C, scores **Midnight Run** (+1, panorama reveal, new title) and unlocks **Polar Night**. They return to the album, add Polar Night to the lineup, and see that *City Never Sleeps* would complete Night Shift. The chase is on.
7. **Survey (11:30).** Intent-to-collect and fairness questions.

## 9. Balancing parameters (tunable in a data file)
| Parameter | Default | Range to test |
|---|---|---|
| Lineup size | 5 | 4–5 |
| Clearance cap | 12 | 10–14 |
| Stat budgets (C1/C2/C3/C4) | 13/15/17/19 | ±1 |
| Set Link bonus | +1 | +1 / +2 |
| Clutch bonus | +2 | +1 / +2 |
| Ambush spring bonus | +1 | 0 / +1 |
| Signature value | 2 | 2–3 |
| Tie winner | First player | First / draw |
| Chain captures | Off | On (captured cards re-check their neighbors) |
| Triptych bonus | +1 | 0 / +1 |

## 10. Edge cases
- **Ambush on the last placement:** it springs immediately before scoring.
- **Ambush next to Ambush:** springs resolve in placement order. A face-down card can't be captured, even by a springing card.
- **Cipher copying Ambush:** Cipher is already face-up, so it doesn't hide. It springs on your next turn with +1 (it captures nothing on placement).
- **Cipher copying Cipher, or with no neighbors:** no trait.
- **Steady vs Reclaim:** **Reclaim beats Steady.** Reclaim only ever retakes your own cards, so this stays readable.
- **Clutch "behind" check:** current score *before* placement, with Signatures counted double.
- **Lineup can't reach 5:** offer the loaner lineup.
- **Both Signatures captured by the same player:** both count double for them.

## 11. Acceptance criteria (for the prototype)
- [ ] Board adjacency matches 4.1 (including b1/b4 having one card above and one below).
- [ ] Captures compare the correct facing values; ties don't capture except with Veteran.
- [ ] All 6 traits and Set Link behave per 4.4 and the edge cases in 10.
- [ ] The lineup builder enforces 5 cards, Clearance ≤ 12, ≤ 1 Legend and exactly 1 Signature.
- [ ] Scoring counts Signatures double, adds Triptych bonuses and resolves ties per the flag.
- [ ] The album shows owned/locked cards, unlock goals, set progress, Triptych hints and the Cipher Lock.
- [ ] 5 Dossiers are solvable. 3 AI levels are playable, and a duel takes under 4 minutes median.
- [ ] A placement preview shows which cards would flip before you confirm (works with touch, no hover-only information).

# CardZone: Loadout Loop (Detailed Spec v0.1)

*Mid Game Designer · 2026-11-04 · Board task `cz-spec` · Phase: design · Source: concept A in `design/concepts.md`*
*All numbers are **starting values for paper playtests**. Names, map and cards are original. Gear names are generic military terms.*

## 1. Summary
2–4 players (plus a solo outline) drop into **Ridge Hollow**, a map of 7 area cards. Each player starts with a **10-card loadout** that is **never shuffled**: you draw the top 4 cards, use them, and **pack** them back at the bottom in the order you choose. You loot weapons, attachments and items from the area you stand in. The **Zone deck** (12 cards in a fixed order) closes areas with gas and announces supply drops. Shots are resolved without dice: **Damage − Cover − Brace**, and the hits that get through land **on top of the target's loadout**, jamming their next hand. **The last player standing wins.**

**Design pillars**
1. **No luck, all nerve:** every outcome follows from visible state and choices.
2. **Pack for the fight:** the order of your loadout is your plan, and it's public.
3. **Loot is a place and a time:** what you find depends on where you drop and when the drops land.
4. **The zone always wins:** the game ends within 17 rounds, no matter what.

## 2. Components and bookkeeping
| Component | Count | Notes |
|---|---|---|
| Area cards (large, double-sided: open / gas) | 7 | 6 outer areas plus the Core |
| Zone cards | 12 | Numbered 1–12, with routes A/B/C printed on each |
| Starter cards | 40 | 10 per player (4 kinds) |
| Hit cards | 20 | 5 per player (your health stack) |
| Loot cards | 71 | 13 outer piles × 4, 5 Core piles × 3, 4 supply drops |
| Player pawns | 4 | 1 per player |
| First-player marker | 1 | It also shows who flips the Zone card |
| Reference cards | 4 | Turn summary and keywords |
| **Total** | **~150 cards + 5 tokens** | No dice, no dials, no counters |

**Tracked state, all visible:** pawn position, your health stack (count ≤ 5), the order of your loadout, which area cards are flipped to gas, the Zone deck position, and the loot piles. **Within your turn**, Move and Search are summed from the cards you played, spent, and then lost. No per-player counters persist between turns.

## 3. Map: Ridge Hollow
```
          [1 Docks]      [2 Farmstead]
   [6 Rail Yard]    [CORE: Old Town]    [3 Quarry]
          [5 Motel]      [4 Radio Hill]
```
- **Adjacency:** each outer area is adjacent to its two ring neighbours (1–2–3–4–5–6–1) and to the **Core**. The Core is adjacent to all six.
- **Distance** = the fewest steps between two areas, so the maximum is 2. **Range 0** = same area, **1** = adjacent, **2** = anywhere on this map.
- **Cover:** a shot fired **from another area** at a target in an area with Cover 1 deals 1 less damage. Shots within the same area ignore Cover.

| # | Area | Cover | Loot piles (rarity, cost) |
|---|---|---|---|
| 1 | Docks | 0 | Scrap SMG (C, 3) · Trail Boots (C, 2) |
| 2 | Farmstead | 1 | Bandage (C, 2) · Smoke Grenade (C, 2) |
| 3 | Quarry | 1 | Pump Shotgun (U, 4) · Frag Grenade (U, 3) |
| 4 | Radio Hill | 0 | Hunting Rifle (U, 4) · Long Scope (U, 3) |
| 5 | Motel | 1 | Medkit (U, 4) · Plate Vest (U, 4) |
| 6 | Rail Yard | 0 | Crowbar (C, 2) · Backpack (U, 3) · Red-dot Sight (C, 2) |
| C | Old Town (Core) | 1 | Assault Rifle (R, 6) · Marksman Rifle (R, 6) · Extended Mag (R, 5) · Suppressor (R, 5) · Recon Drone (R, 5) |

**Pile sizes:** outer piles have 3 cards (2 players) or 4 (3–4 players). Core piles have 2 or 3. Unused copies stay in the box.

## 4. Setup (about 5 minutes)
1. Lay out the map as shown, open side up. Place the loot piles face up on their areas (the setup sheet on the back of the rulebook shows this).
2. Put the 4 supply-drop cards (Twin-Drum LMG, Heavy Plate, Longshot .50, Phantom Suit) next to the Zone deck.
3. Stack the Zone deck in number order (1 on top). **The deck is public:** anyone may look through it at any time.
4. Choose the first player (by agreement; on the web, the host). The **last** player in turn order chooses the **route** (A, B or C).
5. Each player takes the 10 starter cards and arranges them **in any order** as a face-down stack: your **loadout**. Each player also takes 5 Hit cards as a face-up **health stack** and a pawn.
6. **Drop:** in **reverse** turn order, each player puts their pawn on any outer area. Several players may drop into the same area (a hot drop). This also offsets the first player's advantage.

## 5. Turn structure
**Round start (first player only):** reveal the next Zone card and resolve the line for the chosen route (§8).

On your turn:
1. **Draw:** take the top 4 cards of your loadout into your hand. If fewer remain, take them all.
2. **Act:** do any of the following, in any order, as often as you can:
   - **Play** a card from your hand to your play area and gain its effects. Move and Search add to this turn's pools.
   - **Move:** spend 1 Move per step to an adjacent area. You may pass through gas.
   - **Loot:** in your current area (open, not gas), spend Search equal to a pile's cost and take its top card into your play area. A supply drop costs **Search 3**. A card from a **crate** costs **Search 1**.
   - **Shoot:** each weapon in your play area may fire **once** this turn (§7).
   - **Attach:** tuck an attachment under a weapon when both are in your hand or play area (§6).
   - **Patch up:** spend Search 2 to return 1 Hit from your hand to your health stack.
   - **Ditch:** once per turn, spend Search 1 to remove a **Starter** card in your hand from the game. Your loadout can't go below 6 non-Hit cards.
3. **Gas check:** if your pawn is in a gas area, take 1 Hit (no Brace).
4. **Pack:** put every card from your hand and play area (played, unplayed, looted, and any Hits you drew) at the **bottom** of your loadout, **in any order you choose**. **Quick pack** (the default, and the web's one-click option): keep them in the order they were played, then the unplayed cards, then the loot.

Play then passes to the left. When play returns to the first player, a new round starts.

## 6. Card anatomy (poker size, 63 × 88 mm)
```
┌───────────────────────────────┐
│ (4)  ◆U          [WEAPON icon]│  cost · rarity gem + letter · type
│ PUMP SHOTGUN                  │  name
│ ┌───────────────────────────┐ │
│ │          art              │ │
│ └───────────────────────────┘ │
│ ▣ BRACE —      DMG 3 · RNG 0  │  brace shield (left) · weapon stat bar
│ Shoot.                        │  effect text (keywords in bold)
│                               │
│ CZ-014           ▼ attach ▼   │  card id (for sorting) · attach notch
└───────────────────────────────┘
```
- **Cost** (top left): the Search needed to loot it. **Rarity:** a coloured gem plus a letter (C grey, U green, R blue, E purple, L gold), readable in black-and-white print.
- **Brace shield** (left edge): this card's Brace value. It is printed so it can be read when the top 4 cards of a loadout are fanned.
- **Weapon stat bar:** DMG (damage) and RNG (range).
- **Attachments** print their bonus in a **bottom strip**. When an attachment is tucked under a weapon, only the strip shows ("+1 DMG"). A weapon holds at most **2 attachments, of different names**, and they move with it as **one card** (no dilution). If the weapon leaves the game, its attachments go with it.

**Keywords (8):** **Move N** · **Search N** · **Shoot** · **Brace N** · **Heal N** (return up to N Hits from your hand to your health stack) · **Pull N** (draw the next N cards of your loadout now) · **Spent** (after use, remove this card from the game) · **Attach**.

## 7. Shooting
1. **Declare:** choose a weapon in your play area that hasn't fired this turn, and a target player within its RNG (distance ≤ RNG).
2. **Damage** = DMG + attachment bonuses, then **− target area's Cover** if you are in a different area (unless the weapon ignores Cover).
3. **Brace:** the target may reveal any cards with a Brace value from **the top 4 cards of their loadout** (their next hand), and move them to the **bottom** of their loadout in any order. Subtract the total Brace. (A *Suppressor* prevents this step.)
4. **Hits:** for each remaining point of damage (minimum 0), the target moves 1 Hit from their health stack to the **top** of their loadout. Their next hand will hold those Hits: they are **suppressed**.
5. **Elimination:** if the target must take a Hit and their health stack is empty, they are **eliminated**. They form a **crate**: every card in their loadout, hand and play area except Starters and Hits is placed face up in their area. The shooter may immediately take **1 card from the crate for free**. Other crate cards cost Search 1 each for anyone standing there. Hits go back to the box.

**Open information:** anyone may look through any loadout at any time (recommended; see Decision Q3). A player is never forced to reveal *why* they packed a certain way, only the order.

**Example:** Ana (Radio Hill) fires a Hunting Rifle with a Red-dot (2 + 1 = 3) at Ben in the Quarry (adjacent, Cover 1): 3 − 1 = **2**. Ben's top 4 are *Plate Vest (Brace 2), Scavenge, Dash, Scavenge*. He braces with the Vest (it moves to the bottom), so 2 − 2 = **0 hits**. His next hand is now *Scavenge, Dash, Scavenge* plus his 5th card. If Ana had a Suppressor attached, Ben would have taken 2 Hits on top, and his next hand would be *Hit, Hit, Plate Vest, Scavenge*.

## 8. Gas and the Zone deck (route A / B / C)
| # | Zone card | Route A | Route B | Route C |
|---|---|---|---|---|
| 1 | **Calm** (drop round) | – | – | – |
| 2 | **Calm** | – | – | – |
| 3 | **Supply drop:** Twin-Drum LMG | Quarry | Docks | Motel |
| 4 | **Gas closes** | Docks | Radio Hill | Farmstead |
| 5 | **Calm** | – | – | – |
| 6 | **Gas closes** + **drop:** Heavy Plate | close Farmstead · drop Motel | close Quarry · drop Rail Yard | close Rail Yard · drop Radio Hill |
| 7 | **Gas closes** | Rail Yard | Motel | Docks |
| 8 | **Supply drop:** Longshot .50 | Core | Core | Core |
| 9 | **Gas closes** | Radio Hill | Farmstead | Quarry |
| 10 | **Gas closes** + **drop:** Phantom Suit | close Quarry · drop Motel | close Docks · drop Rail Yard | close Radio Hill · drop Motel |
| 11 | **Gas closes** | Motel | Rail Yard | Motel |
| 12 | **Final circle:** at the start of this and every later round, each player takes 1 Hit (in turn order, no Brace). | | | |

- **Gas closes X:** flip area X to its gas side. Its piles can no longer be looted (crates in it too). Ending your turn there costs 1 Hit at the gas check.
- **Supply drop:** place that single card face up on the named area. It costs Search 3 to loot.
- The game lasts at most 12 + 5 = **17 rounds**, because health is 5 and the final circle deals 1 Hit per round.

## 9. Win condition
- **The last player standing wins.**
- If all remaining players are eliminated at the same moment (final circle or a grenade), the player with **more non-Hit cards in their loadout** wins. If still tied, they share the win.
- *(Variant for 3–4 players, Decision Q5: placement points. 1st 5, 2nd 3, 3rd 1, plus 1 per elimination. Play 2 games.)*

## 10. Starting loadout (10 cards)
| Card | Copies | Type | Brace | Effect |
|---|---|---|---|---|
| **P-9 Sidearm** | 1 | Weapon (Starter) | – | Shoot. DMG 1 · RNG 0 |
| **Scavenge** | 4 | Item (Starter) | – | Search 1 |
| **Dash** | 3 | Item (Starter) | – | Move 1 |
| **Duck** | 2 | Item (Starter) | 1 | Search 1 |

Per pass through the loadout: Search 6, Move 3, Brace 2, one weak gun. An average hand gives **≈ 2.4 Search and 1.2 Move**. A packed opening hand (3 Scavenge + Duck) reaches **Search 4**, enough for any Uncommon.

## 11. Card list (27 cards: 4 starters, the Hit card, 22 loot cards)
| ID | Name | Type | Rarity | Cost | Brace | Effect | Where |
|---|---|---|---|---|---|---|---|
| CZ-001 | P-9 Sidearm | Weapon | Starter | – | – | Shoot. DMG 1 · RNG 0 | Starter |
| CZ-002 | Scavenge | Item | Starter | – | – | Search 1 | Starter |
| CZ-003 | Dash | Item | Starter | – | – | Move 1 | Starter |
| CZ-004 | Duck | Item | Starter | – | 1 | Search 1 | Starter |
| CZ-005 | Hit | Hit | – | – | – | No effect. Remove it with Patch up or Heal. | Health stack |
| CZ-010 | Scrap SMG | Weapon | C | 3 | – | Shoot. DMG 2 · RNG 0 | Docks |
| CZ-011 | Trail Boots | Item | C | 2 | – | Move 2 | Docks |
| CZ-012 | Bandage | Item | C | 2 | – | Heal 1. Move 1. **Spent.** | Farmstead |
| CZ-013 | Smoke Grenade | Item | C | 2 | 2 | Move 2. If you use its Brace, it is **Spent**. | Farmstead |
| CZ-014 | Pump Shotgun | Weapon | U | 4 | – | Shoot. DMG 3 · RNG 0 | Quarry |
| CZ-015 | Frag Grenade | Item | U | 3 | – | **Spent.** Deal 2 damage to each player in one area within Range 1 (including you). Ignores Cover. | Quarry |
| CZ-016 | Hunting Rifle | Weapon | U | 4 | – | Shoot. DMG 2 · RNG 1 | Radio Hill |
| CZ-017 | Long Scope | Attachment | U | 3 | – | Attach: **+1 RNG** (max RNG 2) | Radio Hill |
| CZ-018 | Medkit | Item | U | 4 | – | Heal 2 | Motel |
| CZ-019 | Plate Vest | Item | U | 4 | 2 | Move 1 | Motel |
| CZ-020 | Crowbar | Item | C | 2 | – | Search 2 | Rail Yard |
| CZ-021 | Backpack | Item | U | 3 | – | Search 1. Pull 1. | Rail Yard |
| CZ-022 | Red-dot Sight | Attachment | C | 2 | – | Attach: **+1 DMG** | Rail Yard |
| CZ-023 | Assault Rifle | Weapon | R | 6 | – | Shoot. DMG 3 · RNG 1 | Core |
| CZ-024 | Marksman Rifle | Weapon | R | 6 | – | Shoot. DMG 2 · RNG 2. Ignores Cover. | Core |
| CZ-025 | Extended Mag | Attachment | R | 5 | – | Attach: this weapon may fire **one extra time** each turn | Core |
| CZ-026 | Suppressor | Attachment | R | 5 | – | Attach: targets **can't Brace** against this weapon | Core |
| CZ-027 | Recon Drone | Item | R | 5 | – | Search 2. Pull 1. | Core |
| CZ-030 | Twin-Drum LMG | Weapon | E | drop (3) | – | Shoot. DMG 2 · RNG 1. Fires **twice** each turn. | Supply drop (round 3) |
| CZ-031 | Heavy Plate | Item | E | drop (3) | 3 | Heal 1. Move 1. | Supply drop (round 6) |
| CZ-032 | Longshot .50 | Weapon | L | drop (3) | – | Shoot. DMG 4 · RNG 2. Ignores Cover. | Supply drop (round 8) |
| CZ-033 | Phantom Suit | Item | L | drop (3) | 4 | Move 2. Search 1. | Supply drop (round 10) |

**Attachments with no weapon:** an attachment you can't tuck yet goes into your loadout as a loose card (no play effect). Tuck it on a later turn when it and a weapon are in your hand or play area together.

## 12. Balance notes and tuning knobs
- **Search curve:** starter hands ≈ 2.4. With 1 Crowbar ≈ 3.2. With a Backpack and a Crowbar the Core's Rares (5–6) come within reach around **rounds 5–7**, as the gas begins to push inward.
- **Kill speed:** health 5. A Rare rifle with a Red-dot deals 4 at the same range, and an Extended Mag allows a second shot. A full-gear player can eliminate a target with no Brace in one turn **from about round 8**. Brace (Plate Vest 2, Smoke 2, Heavy Plate 3, Phantom Suit 4) is the counter, at the cost of a slot in your next hand.
- **Dilution vs thinning:** Ditch (Search 1) and Spent items thin the loadout. Hits, loose attachments and over-looting thicken it. The minimum is 6 non-Hit cards.
- **Knobs to test first:** health (4/5/6), hand size (4/5), supply-drop cost (3/4), Cover value, crate price (1/free), and whether Ditch is once per turn or unlimited.
- **Telemetry for the web build** (later, data-scientist): round of the first and last elimination, rounds survived per drop area, loot taken per pile, damage vs Brace per shot, time per Pack step, and how often Quick pack is used.

## 13. Web build notes (Godot 4.4.1, for later phases)
- **Pure rules engine:** the game state is a plain data object, and a move list replays the game exactly (no RNG anywhere). Undo is free within a turn, before any shot is resolved.
- **Packing UI:** the loadout is a horizontal strip, and you drag cards to order them. Quick pack is a single button. The top 4 are highlighted as "next hand / armour".
- **Brace prompt:** shooting pauses for the defender's choice (async: a 24 h timer, then auto-brace with the highest values).
- **AI:** deterministic search over a small action space. Scripted Raiders for solo play.

## 14. Solo mode (outline, to detail after paper tests)
Three **Raider** cards (DMG/RNG, health 2–3 shown by Hit cards placed on them) and a **Warden** (health 6) in the Core. At the end of each round every Raider moves 1 step toward you and shoots if you are in range (fixed priority, printed on the card). You win by surviving to the final circle and eliminating the Warden. Bookkeeping: a few Hit cards on enemy cards, and still no dice.

## 15. Open questions for design (→ DESIGN_REVIEW)
Open vs closed loadouts, player elimination vs placement, health 5, hand size 4, rarity names, theme tone (gritty vs stylised), and paper vs web prototype first.

# CardZone: Loadout Loop (Detailed Spec v0.2)

*Sr Game Designer · 2026-11-04 · Board task `cz-spec2` (from the studio head's review of `cz-review`) · Phase: design*
*Revises v0.1 by the Mid Game Designer (`cz-spec`, commit d5a926e; v0.1 stays in git history). Worked examples: `loadout-loop-sims.md`. Sim script: `projects/cardzone/tools/loadout_sim.py`.*
*All numbers are **starting values for paper playtests**. Names, map and cards are original. Gear names are generic military terms.*
*§16 (added 2026-11-04, board task `cz01`): **prototype rules for the 1v1 web build** (private loadouts, setup, undo, engine rulings, tunables). In the prototype, §16 overrides §1–§15 where they differ; the paper rules are unchanged.*

## v0.1 → v0.2 changes (read this first)

The studio head approved concept A with two worries: **packing in order will slow the game down with analysis paralysis**, and **shots that make you draw fewer cards take away the victim's agency and snowball**. Both were real in v0.1. Here is how v0.2 fixes them, in plain words.

### Worry 1: "Packing in order will cause slow down and analysis paralysis."
**v0.1 problem:** at the end of every turn you put 4–6 cards back **in any order you like**. That is 24 to 720 possible orders, and with perfect information a careful player tries to plan their next two or three hands. Quick pack existed, but the best play was still to think hard.

**v0.2 fix, "Hold and Stow":** you no longer choose an order.
- **Stow:** the cards you played or looted go under your loadout **in the order you used them**. You lay them out left to right as you play, then slide the row under the stack. No thinking needed.
- **Hold:** you may keep **up to 2** unplayed cards on top of your loadout. They will be in your next hand, and they are your armour until then.
- That's the whole packing decision: **"which 0–2 leftover cards do I keep?"** It's usually 1–4 options, and about **5 seconds** at the table (v0.1's goal was under 30 s).
- Sequencing still matters a little. What you play first comes back first, and holding a Plate Vest keeps your guard up. But you never plan a whole loop.

### Worry 2: "Shooting causing the other player to draw less cards… losing agency… snowball."
**v0.1 problem:** each Hit was a dead card on top of your loadout and took one of your 4 hand slots. Three Hits meant a 1-card turn: you couldn't run, loot or shoot back, so you got shot again. In our sims the victim of an early ambush had **0–2 usable cards** for several turns and was out by **round 3–6**.

**v0.2 fix: damage costs health and options, never your turn.**
1. **Your hand is always 4 real cards.** Hits still land **on top of your loadout** (the hook stays: damage goes into your deck, and everyone sees it), but Hits are **free draws**. You draw until you hold 4 non-Hit cards, so Hits come *on top of* your hand.
2. **A Hit is playable: Adrenaline.** Play it for **Move 1 or Search 1**: you scramble for cover or grab what you can. Getting shot hurts (you are one step closer to elimination), but your next turn is never empty. It is usually a little *bigger*.
3. **Down (fewer gains from focus-fire):** while a Hit sits in your next draw, you get **+1 Brace against every shot**, and no card moves. The first shot of a round lands in full, and every later shot (a second shooter, an Extended Mag, an LMG's second burst) loses 1 point. The Hit cards show this, so nobody tracks anything.
4. **Bounty (catch-up for whoever is behind):** one shared **Bounty card** goes to the player with **strictly the most health** at the start of each round. Whoever lands a Hit on the Bounty holder **heals 1**. In the final circle the holder takes 1 extra Hit. Being behind becomes a reason to attack the leader, not a reason to hide.
5. **What damage still costs:** health (the road to elimination), and **Brace burns your armour**. Cards you brace with go to the bottom, so you lose them for a loop. That's the "suppression" now: shooting someone forces them to spend the best cards of their next hand, but they still get a full turn.

**Sim check** (scripted bots, `loadout-loop-sims.md`): in 2-player and 3-player games where one player is hit 2–3 times by round 3, the victim had **at least 4 usable cards on every turn** in v0.2 (v0.1: as few as 0–1). They lasted to **round 7–12** (v0.1: round 3–6). In two of the four "victim" games they **led on health later** or **outlived a player who was never ambushed**. No player was eliminated before **round 7** in v0.2. In v0.1 the earliest was round 3.

### Everything else that changed
| Area | v0.1 | v0.2 |
|---|---|---|
| Pack step | Any order (Quick pack optional) | **Hold up to 2, Stow the rest in play order** (§5.4) |
| Setup order | Free 10-card order | Free, or the printed **Standard pack** (§4) |
| Hit card (CZ-005) | Dead card, takes a hand slot | **Free draw; Adrenaline: Move 1 or Search 1** |
| Draw / Pull | Top 4 cards / next N cards | 4 **non-Hit** cards / N **non-Hit** cards; Hits come along free |
| Brace window | Top 4 cards | Your **next hand**: the top 4 non-Hit cards (held cards included) |
| Down | – | +1 Brace per shot while a Hit is in your next draw |
| Bounty (CZ-006) | – | New shared card: catch-up heal + final-circle pressure |
| Heal / Patch up | From your hand | From your **hand or play area** (so you can use Adrenaline, then patch it) |
| Frag Grenade | Flat 2 damage | Resolved as a shot on each player (Brace and Down apply) |
| Suppressor | No Brace | No Brace **with cards**; Down still applies |
| Final circle | 1 Hit every round, no end cap | **14-card Zone deck**: final circle I/II/III = 1/2/3 Hits; hard end after card 14 |
| Max length | "17 rounds" (Heal could stretch it) | **14 rounds, guaranteed** |
| Components | ~154 cards | ~157 cards (+2 Zone, +1 Bounty) |

---

## 1. Summary
2–4 players (plus a solo outline) drop into **Ridge Hollow**, a map of 7 area cards. Each player starts with a **10-card loadout** that is **never shuffled**. You draw 4 cards, use them, **stow** what you used under your loadout in the order you used it, and may **hold** up to 2 cards on top for next turn. You loot weapons, attachments and items from the area you stand in. The **Zone deck** (14 cards in a fixed order) closes areas with gas and announces supply drops. Shots are resolved without dice: **Damage − Cover − Brace**. The Hits that get through land **on top of the target's loadout**. They cost health and burn armour, but they never shrink the target's hand. **The last player standing wins.**

**Design pillars**
1. **No luck, all nerve:** every outcome follows from visible state and choices.
2. **Your next hand is your armour:** your loadout is public, you defend with the cards you're about to draw, and damage lands right there.
3. **Fast hands, short thinks:** every turn is a full turn, and packing is a 5-second habit, not a puzzle.
4. **Loot is a place and a time:** what you find depends on where you drop and when the drops land.
5. **The zone always wins:** the game ends by round 14, no matter what.

## 2. Components and bookkeeping
| Component | Count | Notes |
|---|---|---|
| Area cards (large, double-sided: open / gas) | 7 | 6 outer areas plus the Core |
| Zone cards | 14 | Numbered 1–14, with routes A/B/C printed on each |
| Starter cards | 40 | 10 per player (4 kinds) |
| Hit cards | 20 | 5 per player (your health stack). Face: *Adrenaline* |
| Bounty card | 1 | Shared, double as a reference for Down |
| Loot cards | 71 | 13 outer piles × 4, 5 Core piles × 3, 4 supply drops |
| Player pawns | 4 | 1 per player |
| First-player marker | 1 | It also shows who flips the Zone card |
| Reference cards | 4 | Turn summary, Standard pack, keywords |
| **Total** | **~157 cards + 5 tokens** | No dice, no dials, no counters |

**Tracked state, all visible:** pawn position, your health stack (count ≤ 5), the order of your loadout, which area cards are flipped to gas, the Zone deck position, the loot piles, and who holds the Bounty card. **Within your turn**, Move and Search are summed from the cards you played, spent, and then lost. No per-player counters persist between turns. The Bounty can change hands only at round start, with a glance at the health stacks (each ≤ 5 cards).

## 3. Map: Ridge Hollow (unchanged)
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
3. Stack the Zone deck in number order (1 on top). **The deck is public:** anyone may look through it at any time. Put the **Bounty card** beside it.
4. Choose the first player (by agreement; on the web, the host). The **last** player in turn order chooses the **route** (A, B or C).
5. Each player takes the 10 starter cards and stacks them face down as their **loadout**, either in the **Standard pack** order printed on the reference card or in any order they like. Each player also takes 5 Hit cards as a face-up **health stack** and a pawn.
   - **Standard pack (top → bottom):** Scavenge, Scavenge, Scavenge, Duck · Dash, Dash, P-9 Sidearm, Scavenge · Duck, Dash. Turn 1 gives Search 4 (any Uncommon), turn 2 gives Move 2 plus a gun, and turn 3 starts the loop again with a Duck to hold.
6. **Drop:** in **reverse** turn order, each player puts their pawn on any outer area. Several players may drop into the same area (a hot drop). This also offsets the first player's advantage.

## 5. Turn structure
**Round start (first player only):** (1) give the **Bounty** to the player with strictly the most cards in their health stack. If several players tie for the most, set it aside. (2) Reveal the next Zone card and resolve the line for the chosen route (§8).

On your turn:
1. **Draw:** take cards from the top of your loadout until you hold **4 non-Hit cards** (or the loadout runs out). **Hits you meet on the way come along free:** they never take a hand slot.
2. **Act:** do any of the following, in any order, as often as you can:
   - **Play** a card from your hand to your **line** (your play area, a left-to-right row) and gain its effects. Move and Search add to this turn's pools. A **Hit** is played for **Adrenaline: Move 1 or Search 1**.
   - **Move:** spend 1 Move per step to an adjacent area. You may pass through gas.
   - **Loot:** in your current area (open, not gas), spend Search equal to a pile's cost and take its top card into your line. A supply drop costs **Search 3**. A card from a **crate** costs **Search 1**.
   - **Shoot:** each weapon in your line may fire **once** this turn (§7). A weapon you just looted may fire straight away.
   - **Attach:** tuck an attachment under a weapon when both are in your hand or line (§6).
   - **Patch up:** spend Search 2 to return 1 Hit from your hand or line to your health stack.
   - **Ditch:** once per turn, spend Search 1 to remove a **Starter** card in your hand from the game. Your loadout can't go below 6 non-Hit cards.
3. **Gas check:** if your pawn is in a gas area, take 1 Hit (no Brace, no Down).
4. **Pack (Hold and Stow):**
   - **Hold:** choose **up to 2** non-Hit cards still in your hand and put them face up **on top** of your loadout. They're the start of your next hand, and you can Brace with them until then.
   - **Stow:** slide your **line** under your loadout **in the order the cards entered it** (left to right: played and looted alike). Then put the rest of your hand under that, in any order. *(Default: as they sit in your hand. It rarely matters.)*

Play then passes to the left. When play returns to the first player, a new round starts.

**Why Hold and Stow (and not the alternatives):** see §5.1.

### 5.1 Packing rules considered
| Option | Rule | Decisions per pack | Seconds per pack (est.) | Keeps the hook? | Verdict |
|---|---|---|---|---|---|
| v0.1 free order | Any order for 4–6 cards | 24–720 orders, evaluated over future hands | 15–45 s (AP-prone) | Yes | **Replaced** |
| A. Play order + 1 Rack | All cards return in play order, then you may move **one** card to any slot among them | ~5 cards × ~5 slots ≈ 25 | 8–15 s | Yes, but the armour plan is still a puzzle | Backup if Hold feels too thin |
| B. Fixed slots by type | Weapons first, then items, then Brace cards (printed order) | 0 | 3 s | **No:** nobody can pack for a fight, and everyone's loop looks the same | Rejected |
| **C. Hold and Stow (chosen)** | Hold ≤ 2 unplayed cards on top; stow the line in play order | Usually 1–4 options, at most 11 (hold 0, 1 or 2 of 4 cards) | **≈ 5 s** | **Yes, and stronger:** "keep my armour up" is now a visible, one-line choice | **Chosen** |

**Estimated turn at a table (v0.2):** Draw 3 s · Act 20–40 s · each shot incl. the defender's Brace choice 10–15 s · Pack ≈ 5 s → **typically 35–60 s**. A 2-player game of 10–12 rounds is **≈ 15–25 min of play plus 5 min setup**. That fits the 40-minute target from `concepts.md`.

**Where deliberate sequencing still lives (meaningful but small):**
- **Play vs Hold:** a Duck is Search 1 now, *or* Brace 1 until your next turn. A Plate Vest is Move 1 now, *or* Brace 2. This is the main tension of the game, and it's a choice about 1–2 cards.
- **Play order = return order:** what you lead with comes back first. Players who care can play the Crowbar first, and players who don't lose very little.
- **The hold limit of 2** stops a stall where you draw the same 4 cards forever, and it caps standing armour.

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
- **Cost** (top left): the Search needed to loot it. **Rarity:** a coloured chip that always carries its **letter**: **C** Common, slate `#3F4552` · **U** Uncommon, deep teal `#0F7A70` · **R** Rare, signal blue `#4C8AF2` · **E** Epic, flare amber `#FFB070` · **L** Legendary, beacon yellow `#FFEE80`. Full cards (and the inspector) add **1–5 ticks** under the chip. Each step up is lighter, so rarity reads in greyscale and black-and-white print (darker = commoner). Starter cards have no chip. *(Changed 2026-11-04 by the art direction, `cz15`, `../../art/style-guides/art-direction.md` §2: the old grey/green/blue/purple/gold set clashed with the map, where green reads as gas and purple as the safe zone. Green and violet are never used for rarity.)*
- **Brace shield** (left edge): this card's Brace value. It is printed so it can be read when a loadout's top cards are fanned. **Held cards sit face up**, so their shields are visible across the table.
- **Weapon stat bar:** DMG (damage) and RNG (range).
- **Attachments** print their bonus in a **bottom strip**. When an attachment is tucked under a weapon, only the strip shows ("+1 DMG"). A weapon holds at most **2 attachments, of different names**, and they move with it as **one card** (no dilution). If the weapon leaves the game, its attachments go with it.
- **Hit card:** the face shows a red Hit band and the **Adrenaline** line ("Play: Move 1 or Search 1"), plus the reminder "Free draw · Down: +1 Brace while in your next draw".

**Keywords (9):** **Move N** · **Search N** · **Shoot** · **Brace N** · **Heal N** (return up to N Hits from your hand or line to your health stack) · **Pull N** (draw N more non-Hit cards now; Hits come along free) · **Spent** (after use, remove this card from the game) · **Attach** · **Down** (§7).

## 7. Shooting
1. **Declare:** choose a weapon in your line that hasn't fired this turn, and a target player within its RNG (distance ≤ RNG).
2. **Damage** = DMG + attachment bonuses, then **− target area's Cover** if you are in a different area (unless the weapon ignores Cover).
3. **Down:** if any Hit card is in the target's **next draw** (the cards they would draw next turn: their held cards and Hits on top, down to the 4th non-Hit card), subtract **1**. Nothing moves. *(A Suppressor does not stop this.)*
4. **Brace:** the target may reveal any cards with a Brace value from **their next hand** (the top 4 non-Hit cards of their loadout, held cards included) and move them to the **bottom** of their loadout, in any order. Subtract the total Brace. (A *Suppressor* prevents this step.)
5. **Hits:** for each remaining point of damage (minimum 0), the target moves 1 Hit from their health stack to the **top** of their loadout.
6. **Bounty claim:** if the target held the Bounty and took at least 1 Hit, the shooter **heals 1** (from their hand or line).
7. **Elimination:** if the target must take a Hit and their health stack is empty, they are **eliminated**. They form a **crate**: every card in their loadout, hand and line except Starters and Hits is placed face up in their area. The shooter may immediately take **1 card from the crate for free**. Other crate cards cost Search 1 each for anyone standing there. Hits go back to the box.

**Open information:** anyone may look through any loadout at any time (recommended; DESIGN_REVIEW Q3). *(Prototype: loadouts are **private**; see §16.2.)* A player is never forced to reveal *why* they hold a card, only the cards.

**What a shot does now, in one line:** it takes health, it can force the target to **burn the armour in their next hand**, and it marks them Down. It **never** shrinks their next hand.

**Example:** Ana (Radio Hill) fires a Hunting Rifle with a Red-dot (2 + 1 = 3) at Ben in the Quarry (adjacent, Cover 1): 3 − 1 = **2**. Ben held a **Plate Vest** last turn, so his next hand is *Plate Vest (Brace 2), Scavenge, Dash, Scavenge*. He braces with the Vest (it goes to the bottom), so 2 − 2 = **0 Hits**. His next hand is *Scavenge, Dash, Scavenge* plus the next card down: still 4 cards, but no armour and no Move 1 from the Vest. That's the suppression.
If Ana's rifle had a Suppressor, Ben could not brace: **2 Hits** land on top. On his turn he draws *Hit, Hit* **plus** *Plate Vest, Scavenge, Dash, Scavenge*. That's 6 cards, two of them Adrenaline (say Move 2 to break line of sight, or Search 2 to Patch up once). Until then he is **Down**: Cid's follow-up shot that round deals 1 less.

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
| 12 | **Final circle I:** each player takes **1** Hit (in turn order, no Brace, no Down). The Bounty holder takes 1 more. | | | |
| 13 | **Final circle II:** as above, **2** Hits each. | | | |
| 14 | **Final circle III:** as above, **3** Hits each. **The game ends after this round:** the survivor with the most health wins. If tied, the one with more non-Hit cards in their loadout wins. If still tied, they share the win. | | | |

- **Gas closes X:** flip area X to its gas side. Its piles can no longer be looted (crates in it too). Ending your turn there costs 1 Hit at the gas check.
- **Supply drop:** place that single card face up on the named area. It costs Search 3 to loot.
- **Max length: 14 rounds**, guaranteed by card 14. (v0.1 claimed 17, but healing could stretch it.) The escalating final circle (1 + 2 + 3 = 6 Hits > 5 health) usually ends it in round 13 or 14.

## 9. Win condition
- **The last player standing wins**, or the healthiest survivor when Zone card 14 ends the game.
- If all remaining players are eliminated at the same moment (final circle or a grenade), the player with **more non-Hit cards in their loadout** wins. If still tied, they share the win.
- *(Variant for 3–4 players, DESIGN_REVIEW Q2: placement points. 1st 5, 2nd 3, 3rd 1, plus 1 per elimination. Play 2 games.)*

## 10. Starting loadout (10 cards, unchanged numbers)
| Card | Copies | Type | Brace | Effect | v0.2 role |
|---|---|---|---|---|---|
| **P-9 Sidearm** | 1 | Weapon (Starter) | – | Shoot. DMG 1 · RNG 0 | Weak, but it lets a hurt player claim the Bounty at close range |
| **Scavenge** | 4 | Item (Starter) | – | Search 1 | The usual Ditch target |
| **Dash** | 3 | Item (Starter) | – | Move 1 | – |
| **Duck** | 2 | Item (Starter) | 1 | Search 1 | **The first Hold decision:** Search now, or Brace 1 until your next turn |

Per pass through the loadout: Search 6, Move 3, Brace 2, one weak gun. An average hand gives **≈ 2.4 Search and 1.2 Move**. The Standard pack's opening hand (3 Scavenge + Duck) reaches **Search 4**, enough for any Uncommon. Each Hit you carry adds **+1 Move or Search** on the turn you draw it.

## 11. Card list (27 player cards + the Bounty)
*Changed in v0.2: CZ-005 Hit, CZ-015 Frag Grenade, CZ-026 Suppressor (wording), and the new shared CZ-006 Bounty. Every other number is unchanged on purpose, so paper tests isolate the two rule changes.*

| ID | Name | Type | Rarity | Cost | Brace | Effect | Where |
|---|---|---|---|---|---|---|---|
| CZ-001 | P-9 Sidearm | Weapon | Starter | – | – | Shoot. DMG 1 · RNG 0 | Starter |
| CZ-002 | Scavenge | Item | Starter | – | – | Search 1 | Starter |
| CZ-003 | Dash | Item | Starter | – | – | Move 1 | Starter |
| CZ-004 | Duck | Item | Starter | – | 1 | Search 1 | Starter |
| CZ-005 | **Hit** *(v0.2)* | Hit | – | – | – | **Free draw** (never takes a hand slot). **Adrenaline:** play for Move 1 or Search 1. While in your next draw you are **Down** (+1 Brace per shot). Remove with Patch up or Heal. | Health stack |
| CZ-006 | **Bounty** *(new, shared)* | Marker card | – | – | – | Round start: goes to the player with strictly the most health (tie: set aside). Land a Hit on the holder: **heal 1**. Final circle: the holder takes 1 extra Hit. | Beside the Zone deck |
| CZ-010 | Scrap SMG | Weapon | C | 3 | – | Shoot. DMG 2 · RNG 0 | Docks |
| CZ-011 | Trail Boots | Item | C | 2 | – | Move 2 | Docks |
| CZ-012 | Bandage | Item | C | 2 | – | Heal 1. Move 1. **Spent.** | Farmstead |
| CZ-013 | Smoke Grenade | Item | C | 2 | 2 | Move 2. If you use its Brace, it is **Spent**. | Farmstead |
| CZ-014 | Pump Shotgun | Weapon | U | 4 | – | Shoot. DMG 3 · RNG 0 | Quarry |
| CZ-015 | **Frag Grenade** *(v0.2)* | Item | U | 3 | – | **Spent.** Choose one area within Range 1: resolve a **2-damage shot** against each player there (including you). Ignores Cover. Brace and Down apply. | Quarry |
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
| CZ-026 | **Suppressor** *(v0.2 wording)* | Attachment | R | 5 | – | Attach: targets **can't Brace with cards** against this weapon (Down still applies) | Core |
| CZ-027 | Recon Drone | Item | R | 5 | – | Search 2. Pull 1. | Core |
| CZ-030 | Twin-Drum LMG | Weapon | E | drop (3) | – | Shoot. DMG 2 · RNG 1. Fires **twice** each turn. | Supply drop (round 3) |
| CZ-031 | Heavy Plate | Item | E | drop (3) | 3 | Heal 1. Move 1. | Supply drop (round 6) |
| CZ-032 | Longshot .50 | Weapon | L | drop (3) | – | Shoot. DMG 4 · RNG 2. Ignores Cover. | Supply drop (round 8) |
| CZ-033 | Phantom Suit | Item | L | drop (3) | 4 | Move 2. Search 1. | Supply drop (round 10) |

**Attachments with no weapon:** an attachment you can't tuck yet is a loose card (no play effect). Stow it as usual, and tuck it on a later turn when it and a weapon are in your hand or line together.

## 12. Balance notes and tuning knobs
- **Search curve:** starter hands ≈ 2.4. With 1 Crowbar ≈ 3.2. With a Backpack and a Crowbar the Core's Rares (5–6) come within reach around **rounds 5–7**, as the gas begins to push inward. Adrenaline adds a little Search to hurt players. That is deliberate catch-up.
- **Kill speed:** health 5. An Assault Rifle with a Red-dot and an Extended Mag deals 4, then 4 − 1 (Down) = 3, so a full-gear player can still eliminate an unbraced target in one turn **from about round 8**. A single 4-damage shot no longer cripples the target's next turn.
- **Focus-fire math (Down):** two shooters dealing 3 each to an unbraced target: v0.1 = 6 Hits (eliminated, and the target's next hand was dead anyway); v0.2 = 3 + 2 = 5 Hits. That's still lethal from full health if both commit, so ganging up is still a real threat, but it is one point less effective per extra shot.
- **Twin-Drum LMG** loses about 1 Hit per turn to Down (2 + 1). Watch whether it still feels Epic. Knob: DMG 2 → 3 on the second burst only.
- **Dilution vs thinning:** Ditch (Search 1) and Spent items thin the loadout. Loose attachments and over-looting thicken it. **Hits no longer dilute** (free draws). The minimum is 6 non-Hit cards.
- **Bounty:** the only "leader" test is "who has strictly the most health at round start". In the sims, the heal on claim mattered more than the final-circle clause.
- **Knobs to test first:** hold limit (2 / 1), Adrenaline (Move 1 or Search 1 / Move 1 only / max 2 per turn), Down (+1 flat / off), Bounty (heal 1 / heal 1 + Pull 1 / off), health (4/5/6), supply-drop cost (3/4), crate price (1/free), and whether Ditch is once per turn or unlimited.
- **Telemetry for the web build** (later, data-scientist): seconds per Pack step, how often players hold 0/1/2 cards and what they hold, Adrenaline used as Move vs Search, how often Down and the Bounty changed a shot's outcome, comeback rate (players at ≤ 3 health in round 4 who finish in the top half), round of the first and last elimination, rounds survived per drop area, loot taken per pile, damage vs Brace per shot.

## 13. Web build notes (Godot 4.4.1, for later phases)
- **Pure rules engine:** the game state is a plain data object, and a move list replays the game exactly (no RNG anywhere). Undo is free within a turn, before any shot is resolved.
- **Packing UI:** there is no reordering any more. The line fills left to right as you play. At Pack, unplayed cards get a **Hold** toggle (max 2), and *End turn* stows everything. The top of the loadout strip is highlighted as "next hand / armour". Held cards show face up with their Brace shields, and Hits show a **Down** badge.
- **Brace prompt:** shooting pauses for the defender's choice (async: a 24 h timer, then auto-brace with the fewest cards that stop the most damage). Down is applied automatically.
- **Bounty:** a badge on the holder's portrait, recalculated at round start.
- **AI:** deterministic search over a small action space (the hold choice is ≤ 11 options). Scripted Raiders for solo play. `tools/loadout_sim.py` is a rough reference for the bot heuristics, not engine code.

## 14. Solo mode (outline, to detail after paper tests)
Three **Raider** cards (DMG/RNG, health 2–3 shown by Hit cards placed on them) and a **Warden** (health 6) in the Core. At the end of each round every Raider moves 1 step toward you and shoots if you are in range (fixed priority, printed on the card). Raiders respect Down and your Brace. You win by surviving to the final circle and eliminating the Warden. Bookkeeping: a few Hit cards on enemy cards, and still no dice. (Adrenaline and Hold apply to you as normal. The Bounty is not used in solo.)

## 15. Open questions for design (→ DESIGN_REVIEW "v0.2 follow-ups")
Hold limit 2 vs 1; may freshly looted cards be held; Adrenaline strength and a per-turn cap; Down as a flat +1; Bounty test (most health) and whether its final-circle clause stays; the passive "camper" who avoids fights; the escalating final circle and the 14-round hard end; plus the v0.1 items still open in cz-q (open loadouts, elimination vs placement, health 5, rarity names, tone, paper vs web first).

---

## 16. Prototype rules (1v1)

*Sr Game Designer · 2026-11-04 · Board task `cz01` · Phase: plan. Reviewed by the Mid Game Designer (log in §16.9).*
*Scope: the private 1v1 web prototype (`../../production/prototype-scope.md`, `prototype-milestone-plan.md` §3). **In the prototype, §16 wins wherever it differs from §1–§15.** The paper rules above are unchanged. QA (`cz04`) writes test cases straight from this section: every rule has an ID (D, S, P, U, R) to cite.*

### 16.0 Decisions this section applies
| Decision | Source | Effect here |
|---|---|---|
| Loadouts are **private**; **held cards are hidden** from the opponent; health, loadout size and the Hits in the next draw (Down) stay public | Q3, plan default approved by the head | §16.2. `held_cards_public` = false. |
| **Zone deck = v0.2's 14 cards** (final circle 1/2/3 on cards 12–14, hard end after card 14), not the 12 in the Q6 wording | F6, plan default approved by the head | R43–R44. `zone_hard_end_card` = 14. |
| **Hand size 5** by default, 4 allowed | Q6 ("maybe 5"), plan §2 sim | Every "4" in §5 and §7 reads as `hand_size`. |
| 1v1 only, last player standing | Q2, Q5 | Any elimination ends the match. |
| F1–F8 at their v0.2 defaults, each one a switch | F1–F8 | §16.8 tunables table. |
| **Supply drops cost Search 4** (was 3) | Sr Game Designer, from the `cz02` sweep (`../balance-log.md` entry 1) | §16.4a. `supply_drop_cost` = 4, plus a new switch `supply_drop_ready_delay` (0, off). |

### 16.1 Terms (used by every rule below)
- **D1 Your cards:** your loadout, hand and line. Your health stack and the Bounty are not "cards" for any count.
- **D2 Card count:** a weapon with its tucked attachments counts as **1 card** for every count and slot: hand size, draw, next hand, Hold limit, loadout count, `min_loadout`, tiebreaks.
- **D3 Health:** the number of Hit cards in your health stack (0 to `health`). Hits in your loadout, hand or line are not health.
- **D4 Next draw:** start at the top of a player's loadout and take cards until `hand_size` non-Hit cards have been taken or the loadout ends. The next draw is all of those cards, including every Hit met on the way, wherever it sits. It is recomputed after every change to the loadout.
- **D5 Next hand:** the non-Hit cards in the next draw. This is the Brace window (§7 step 4).
- **D6 Down:** a player is Down while their next draw holds at least 1 Hit (and `down_enabled` is true).
- **D7 Hand order:** the order cards entered your hand (draw order, then Pull order). **Line order:** the order cards entered your line (played or looted). Both are deterministic, and the engine uses them wherever a rule says "in order".
- **D8 Seats:** the first player (P1) and the second player (P2). A round is P1's turn, then P2's.

### 16.2 Information model (private loadouts)
Your own cards are always fully visible to you. The table says what the **opponent** sees. "View" is what `view(state, seat)` returns for that seat; the UI, the AI (`AiView`) and hot-seat use only the view.

| # | Information | Owner | Opponent | Switch (default) |
|---|---|---|---|---|
| P1 | Loadout order and contents | Yes | **No** | – (fixed by Q3) |
| P2 | Held cards: **which cards** | Yes | **No** | `held_cards_public` (**false**) |
| P3 | Held cards: **how many** (0 to `hold_limit`) | Yes | Yes | – |
| P4 | **Hits in the next draw** (count, D4) | Yes | **Yes** (the Down badge with a number) | `hits_on_top_public` (**true**) |
| P5 | **Down** yes/no (D6) | Yes | **Yes, always** | – (damage depends on it) |
| P6 | Loadout size (card count, D2, Hits included) | Yes | Yes | `loadout_count_public` (**true**) |
| P7 | Health (D3) | Yes | Yes | – |
| P8 | Hand during your turn: number of cards | Yes | Yes | – |
| P9 | Hand during your turn: which cards | Yes | **No** (Hits in hand: count shown when `hits_on_top_public` is true) | – |
| P10 | Line (played and looted cards, tucked attachments, which weapons fired) | Yes | Yes | – |
| P11 | Cards used to Brace | Yes | Yes, revealed when used; their new place (bottom) is known | – |
| P12 | Ditched cards, Spent cards | Yes | Yes (they leave the game face up) | – |
| P13 | Bounty holder, pawns, gas, piles (card and count), supply drops, crates, the whole Zone deck and the route | Yes | Yes | – |
| P14 | Unheld hand cards that you stow at Pack | Yes | No (only that they went under) | – |

- **P15 `held_cards_public` = true** shows the identities of held cards (spec v0.2's face-up hold). The rest of the loadout stays private either way.
- **P16 `hits_on_top_public` = false** hides the number but still shows Down yes/no (P5), because the shooter's damage depends on it.
- **P17 `loadout_count_public` = false** hides P6. The tiebreaks still use the true count, and the end screen reveals it.
- **P18 Memory:** a player (and the AI) may remember every public event of the match (loot, plays, Brace reveals, hold counts). Nobody may read a private field. **Fairness test:** for any two states that differ only in seat B's private fields, `view(state, A)` must be identical.
- **P19 Shot preview** (shooter): shows damage after Cover and Down and the text "they may Brace". It never shows or uses the target's next hand unless `held_cards_public` is true, and then only the held cards.
- **P20 Brace prompt** (defender): shows the damage after Cover and Down, and the defender's own next hand.

### 16.3 1v1 setup and drop order
1. **S1 First player:** chosen in match setup: *Me*, *Opponent* or *Alternate* (swap from the last match on this device; the first match ever: the human is P1). In hot-seat, Player 1 is P1.
2. **S2 Route:** vs the AI, the **human picks** A, B or C, or *Pick for me* (A, B, C in rotation per match on this device, starting with A). In hot-seat, P2 picks (as §4 step 4). The AI never chooses a route.
3. **S3 Map:** 7 areas open. Outer piles 3 cards (`pile_size_outer`), Core piles 2 (`pile_size_core`). The 4 supply drops are set aside. The Zone deck is cards 1 to `zone_hard_end_card` in number order. The Bounty is set aside.
4. **S4 Players:** both loadouts in the **Standard pack** order (§16.4), `health` Hits in each health stack, no hand, no line.
5. **S5 Drop, in reverse turn order:** **P2 drops first**, then P1, who sees P2's pawn. Only outer areas (1–6), never the Core. Both may pick the same area (hot drop). The AI's drop is a pure function of (route, its seat, the human's drop if already placed, AI level), with no randomness (rule in `cz09`).
6. **S6 Round 1:** round start (R39): the Bounty stays aside (5 vs 5), Zone card 1 (Calm). P1 takes the first turn.
7. **S7** No turn timer, vs the AI or in hot-seat.

### 16.4 Standard pack for a 4-card and a 5-card hand
**Hand-5 Standard pack (top → bottom): Scavenge, Scavenge, Scavenge, Duck, Dash · Dash, P-9 Sidearm, Scavenge, Duck, Dash.**
**Hand-4 Standard pack: the same 10 cards in the same order** (§4: *Scavenge ×3, Duck · Dash, Dash, P-9, Scavenge · Duck, Dash*). One reference card serves both hand sizes, so `cz06` ships a single `StartPackData`.

**Why the hand-5 order is the hand-4 order** (`cz02` ran hand 5 on this order, so this decision was checked rather than assumed). I re-ran the `cz02` sweep (hand 5, hold 2, all 36 drop pairs × routes A/B/C, the bots from `tools/loadout_sim.py`; scratch patch, the tool is unchanged) with three other splits of the same 10 cards:

| Order, hand 5 (turn 1 · turn 2) | Drop cost | First player wins A / B / C (pooled) | Both out in final circle | Median last round | Earliest elimination |
|---|---|---|---|---|---|
| **Standard: S S S Du Da · Da P S Du Da** | **4** | **19 / 19 / 18 (51%)** | **6/108** | **9 / 9 / 8** | **6** |
| S S S Du Da · Da P S Da Du | 4 | 13 / 18 / 20 (47%) | 8/108 | 9 / 8 / 8 | 6 |
| S S Du Da P · S S Du Da Da (gun on turn 1) | 4 | 26 / 24 / 23 (67%) | 17/108 | 11 / 9 / 10 | **5** |
| S S S S Du · Da Da Da P Du (all Search first) | 4 | 13 / 17 / 14 (40%) | 18/108 | 12 / 11 / 12.5 | 6 |
| Standard | 3 | 19 / 30 / 32 (75%) | 7/108 | 10 / 9 / 9 | 6 |

The Standard order is the only one with a fair first-player rate **and** < 10% zone-decided duels. A gun on turn 1 brings eliminations forward to round 5. All-Search-first starves Move, so the zone decides 17% of duels. The second row is within noise of the Standard (about ±9 points pooled) and has no advantage that would justify a second printed order.

| Hand | Turn 1 hand | Turn 1 offers | Turn 2 hand (if turn 1 held nothing) | Turn 2 offers |
|---|---|---|---|---|
| 4 | Scavenge ×3, Duck | Search 4 (any outer Uncommon), or Search 3 and hold Duck (Brace 1) | Dash, Dash, P-9, Scavenge | Move 2, a gun, Search 1 |
| **5** | Scavenge ×3, Duck, Dash | Search 4 **and Move 1** (step to a neighbour, then loot), or hold Duck: Search 3, Move 1, Brace 1 | Dash, P-9, Scavenge, Duck, Dash | Move 2 (reach any area), a gun, Search 2 (a 2-cost Common), or hold Duck |

- **Hand 5 confirmed, unchanged order.** Turn 1's Move 1 softens a bad drop, but turn 1 can still never buy a Rare: moving to the Core leaves Search 4, and Core cards cost 5–6. With hand 5 the 10 starters loop in exactly 2 turns; turn 3 starts with the held cards, then turn 1's line in play order.
- **Holding on turn 1** changes turn 2. Example (hand 5): hold Duck on turn 1 → turn 2 hand is Duck, Dash, P-9, Scavenge, Duck.
- A custom starting order is out of scope (`standard_pack` = true only).

### 16.4a Supply-drop cost: Search 4 (decision)
**Problem (`cz02`, `../balance-log.md` entry 1):** at hand 5, almost every round-3 hand has Move 1 + Search 3, so the first player to act in round 3 takes the Twin-Drum LMG. On routes B and C that is P1 in 30–31 of 36 games, and P1 wins 83–89%.

| Option | First player wins A / B / C (pooled) | Both out | Median | Earliest elim. | Cost to build | Verdict |
|---|---|---|---|---|---|---|
| **Drop cost 3 → 4** (`supply_drop_cost`) | 19 / 19 / 18 (**51%**) | 6/108 | 9 / 9 / 8 | **6** | none (already a tunable) | **Chosen: default** |
| Drops lootable from the round after they land, cost 3 (`supply_drop_ready_delay` = 1) | 20 / 19 / 21 (55%) | 6/108 | 9.5 / 9 / 9 | **4** (breaks the round-6 gate) | one field and one check | **Kept as a switch, off** |
| Move the B/C round-3 drop | not simulated | – | – | – | a content change to 2 routes | Rejected: it treats one card, not the turn-order race, and the race returns with every later drop |

*(The delay row is my scratch run of the same sweep; the cost-4 row reproduces the Mid Designer's numbers exactly.)*
- **Why cost 4:** it fixes the cause (being first in turn order is no longer enough; you also need a strong hand or a looted Search card), it keeps every gate (no elimination before round 6, double knockouts at 6%), and it is a data change.
- **What to watch:** medians drop to 8–9, so route C (8) sits just under the 9–12 band. The playtest's match-length KPI decides whether that matters. Later drops (Heavy Plate, Longshot, Phantom Suit) also cost 4, which suits their Epic/Legendary rarity.
- **Hand 4 caveat:** at hand 4, cost 4 pushes zone-decided duels to 38% (cost 3: 26%). **When the dev panel switches `hand_size` to 4, set `supply_drop_cost` to 3** (the panel should offer both together; note for `cz13`).
- **R10a `supply_drop_ready_delay` = 1:** a supply drop can't be looted in the round it lands; it becomes lootable at the start of the next round. At 0 (default) it can be looted the turn it lands.

### 16.5 Actions and the undo boundary
- **U1 Actions:** a match is its setup plus a list of actions. Player actions: `play(card, adrenaline: move|search)`, `move(to)`, `loot(source)`, `shoot(weapon, target)`, `frag(area)` (playing a Frag), `attach(attachment, weapon)`, `patch_up`, `ditch(card)`, `end_turn(hold_ids | rack_move)`. Defender action: `brace(card_ids in order)`. Draw, the gas check and round start are automatic and are not actions.
- **U2 Undo** removes the active player's **last action** of the current turn and restores the exact state before it. Undone actions are **deleted from the saved action list**; a replay never contains them. No limit on the number of undos.
- **U3 Boundary: you can't undo past**
  - the start of your turn (the draw is fixed);
  - a **declared shot** (`shoot` or `frag`): declaring it commits it and every action before it, because the defender then chooses and may reveal hidden cards;
  - `end_turn`, a confirmed `brace`, or an elimination (the match is over).
- **U4 Looting can be undone** until the next shot. *Changed from the plan's proposal (undo stops at loot):* in 1v1 a loot reveals nothing (piles, drops and crates are face up, and the opponent is not acting), and a mis-tapped loot is the commonest phone mistake.
- **U5 Hold toggles are not actions.** Only `end_turn(hold_ids)` is, so holds can be changed freely until End turn.
- **U6** The AI never undoes. Each undo is logged (`turn_end.undo_count`).

### 16.6 Rulings
#### Draw and Pull
- **R1 Draw:** at the start of your turn, take your whole next draw (D4) into your hand. Hits come along free and never count toward `hand_size`.
- **R2 Short loadout:** with fewer than `hand_size` non-Hit cards in your loadout, you draw all of it. No penalty, no refill, no reshuffle.
- **R3 Pull N:** take cards from the top of your loadout until N more non-Hit cards have been taken or the loadout ends; every Hit met comes along free. Pulled cards go to the end of your hand order. Pull may take your hand above `hand_size`. *Example: loadout top Hit, Hit, Duck: Pull 1 takes all three.*
- **R4** After a Pull your next draw is recomputed from what is now on top (it matters for a Frag on yourself, R33).
- **R5** A Hit is never held, never ditched and never counts toward `hand_size`, the Hold limit or `min_loadout`.

#### Play, Adrenaline, Loot, Attach
- **R6 Play** moves a card from your hand to the end of your line and gives its effects at once. A Hit must be played as Adrenaline, naming **Move 1** or **Search 1** (`adrenaline_mode` = `move_only`: Move 1 only). With `adrenaline_cap_per_turn` = 2, a third Adrenaline play in one turn is illegal (the Hit stays in hand); 0 means no cap.
- **R7 Pools:** Move and Search start each turn at 0, grow with plays, shrink with actions, and are lost at the end of the turn. An action you can't pay for is illegal (pools never go negative).
- **R8** A weapon fires only from your line. Playing it gives no Move or Search; it just puts it in the line.
- **R9 Loot puts the card at the end of your line without playing it.** A looted item gives **no** Move, Search, Heal or Pull this turn and can't be used this turn (a looted Frag can't be thrown). A looted weapon may fire this turn. A looted attachment may be attached this turn. A looted card's Brace counts only once it is in your next hand.
- **R10 Loot** only in your current area and only while it is open. Cost: the pile's printed cost, `supply_drop_cost` for a drop (default **4**, §16.4a; with `supply_drop_ready_delay` = 1, not in the round it lands, R10a), `crate_cost` per crate card. An empty pile can't be looted.
- **R11 Attach** an attachment in your hand or line to a weapon in your hand or line, for free. It is permanent. A weapon carries at most 2 attachments with different names; anything else is illegal. The pair is one card (D2) and sits where the weapon sits (hand, line position, or later the loadout).
- **R12 Fire limit:** 1 per turn, the Twin-Drum LMG 2, +1 with an Extended Mag. The limit is checked when a shot is declared, so attaching an Extended Mag to a weapon that has already fired once lets it fire once more this turn. An attachment never changes a shot that has already resolved.
- **R13 Long Scope:** +1 RNG, at most RNG 2 (no effect on a Marksman Rifle or a Longshot .50).
- **R14** A loose attachment may be played to the line (no effect) or left in hand. Either way it stows normally.

#### Heal, Patch up, Ditch, Spent
- **R15 Heal N** returns up to N Hits **from your line, then your hand** (last line Hit first, then last hand Hit first) to your health stack. Hits in your loadout can never be healed. Health never exceeds `health`.
- **R16** Playing a Heal card with no Hit in your line or hand is legal. It heals 0, still gives its other effects, and a Bandage is still Spent.
- **R17** When a Hit you played as Adrenaline is healed, you keep the Move or Search it gave.
- **R18 Patch up:** spend Search 2 to heal 1 (R15 order). It is legal only with at least 1 Hit in your line or hand. No per-turn limit.
- **R19 Ditch:** up to `ditch_per_turn` times a turn, spend Search 1 to remove a **Starter in your hand** (not in your line) from the game, face up. It is legal only if your non-Hit card count (D1, D2) after the ditch is ≥ `min_loadout`. A P-9 carrying an attachment can't be ditched.
- **R20 Spent:** the card is removed from the game as soon as its effect resolves and never stows. Bandage: on play. Frag: after it resolves. Smoke Grenade: only when it is used to Brace (played for Move 2, it stays).

#### Shooting, Down, Brace
- **R21 Declare:** a weapon in your line with a shot left (R12), at the opponent, at distance ≤ RNG. You may shoot from or into gas. You can't target yourself with a weapon.
- **R22 Cover:** subtract the target area's Cover if the shooter is in a different area and the weapon does not ignore Cover. **Gas areas keep their Cover.** With `bounty_holder_loses_cover` = true, Cover counts as 0 for shots at the Bounty holder.
- **R23 Down:** if the target is Down (D6) when the shot is declared, subtract `down_value` once for that shot. A Suppressor does not stop Down.
- **R24 Damage before Brace** = DMG + attachment bonuses − Cover − Down, minimum 0. The defender sees this number before choosing. **At 0 there is no Brace step** (no prompt, no cards move).
- **R25 Brace:** the defender picks any set of cards with a Brace value from their next hand (none is allowed, and over-bracing is allowed). They go to the bottom of the loadout in the chosen order (a Smoke Grenade is removed instead, R20). Hits = max(0, damage − Brace total).
- **R26 One Brace per card per turn:** a card that braced can't brace again in the same turn, even if a short loadout brings it back into the next hand.
- **R27 Suppressor:** the target can't brace with cards (no Brace step); Down still applies.
- **R28 Between shots** the next draw is recomputed: Hits from an earlier shot sit on top (the target is now Down), braced cards are gone, and new cards may enter the window.
- **R29 Hits:** for each Hit, move 1 Hit from the health stack to the **top** of the loadout. If a Hit must be taken and the health stack is empty, the target is eliminated (R45).
- **R30 Short Brace window:** if the loadout holds fewer than `hand_size` non-Hit cards, the next hand is all of them.

#### Frag Grenade
- **R31** A Frag is played from your hand (not usable the turn it is looted, R9). Choose any area at distance ≤ 1 from yours (open or gas). An area with no players is a legal, wasted throw (still Spent).
- **R32** Resolve a 2-damage shot against each player in that area: Cover ignored, Down and Brace apply, R24–R30 as for a shot.
- **R33 Frag on yourself:** if you are in that area you are a target. Your next draw is the top of your loadout as it is now (not your hand or line), and you may brace from it.
- **R34 Order:** the opponent's damage and Brace first, then yours; then all Hits land together; then the Bounty claim (R37); then eliminations, which are simultaneous (R47).
- **R35** You never claim the Bounty from Hits on yourself.

#### Bounty
- **R36** At round start the Bounty goes to the player with **strictly more health** (D3); on a tie it is set aside. The holder keeps it until the next round start, even if they stop being the healthiest.
- **R37 Claim:** each shot (or Frag resolution against the holder) that puts ≥ 1 Hit on the holder heals the shooter `bounty_heal` (R15 order; 0 if there is nothing to heal). It's once per shot, so an LMG's two bursts can claim twice. An eliminated shooter does not claim.
- **R38 Final circle:** the holder takes `bounty_final_circle_extra` more Hits.

#### Gas and the Zone deck
- **R39 Round start**, in order: (1) the Bounty (R36); (2) flip the next Zone card; (3) gas closes, then the supply drop lands, then the final-circle Hits; (4) P1's turn.
- **R40 Gas check** after Act, before Pack: a pawn in gas takes 1 Hit on top of the loadout. No Brace, no Down, no Bounty claim. Hold then puts the held cards **above** that Hit, which stays in the next draw (the player is Down).
- **R41** A gas or final-circle Hit with an empty health stack eliminates that player. There is no shooter and no free crate pick.
- **R42** You may move through gas and stay there. You can't loot in gas, including a drop or crate that is there (it stays, unlootable).
- **R43 Final circle:** Zone card k (k = 12, 13, 14) deals `final_circle_hits[k − 12]` Hits to each player (if the list is shorter, its last value repeats), to both players at once, plus R38. No Brace, no Down. The Hits go on top of the loadout.
- **R44 Hard end:** the Zone deck is cards 1 to `zone_hard_end_card` (default 14). The match ends **after both turns** of the round in which that card was flipped.

#### Elimination and the end of the match
- **R45 Elimination** happens when a player must take a Hit with an empty health stack. In 1v1 **the match ends at once**; the rest of that shot's Hits are ignored, and no further actions happen.
- **R46 Crate:** the engine still forms it as in §7 (non-Starter, non-Hit cards, each weapon with its attachments as 1 card, face up in the area; `crate_free_picks` for a shooter, `crate_cost` per card). In 1v1 nobody acts on it. It is built and tested for 3–4 players.
- **R47 Both eliminated at once** (one final-circle card or one Frag): the player with **more non-Hit cards** (D1, D2: loadout + hand + line) wins. If tied, the match is a **draw**.
- **R48 Hard end winner:** more health (D3); if tied, more non-Hit cards (as R47); if still tied, a **draw**.
- **R49 Concede** (pause menu): allowed any time; the opponent wins (`match_end.cause` = `concede`).

#### Pack
- **R50 Hold and Stow** (`end_turn(hold_ids)`): hold up to `hold_limit` non-Hit cards from your hand. With `hold_looted` = true you may also hold cards looted this turn that are still in your line and unused (not fired, nothing attached to or from them). The new loadout, top → bottom, is: **held cards** (hand order, then line order) · **the rest of the loadout** · **the line** (line order, minus held and Spent cards) · **the unheld hand** (hand order, Hits included).
- **R51 Rack swap** (`packing_rule` = `rack_swap`): no Hold. The return row is the line (line order) then the rest of the hand (hand order); you may move **one** card of that row to any position in it (`end_turn(rack_move)`, or none). The row goes under the loadout.
- **R52** Hits left in your hand at Pack are stowed with the unheld hand; they can't be held.

### 16.7 Edge-case index (for QA)
| Plan edge case | Ruling |
|---|---|
| Pull through Hits | R3, R4 |
| Brace when the next hand is short | R26, R30 |
| Frag on yourself | R33–R35 |
| Heal from the line | R15–R17 |
| Gas Hit at 0 health | R41 |
| Simultaneous final-circle elimination and tiebreak | R43, R47, R48 |
| Looted cards (effects, hold) | R9, R50 |
| Attachments (count, fire limit, ditch) | D2, R11–R13, R19 |
| Down after an earlier shot or the gas check | R28, R40 |
| Bounty claims per shot | R37 |

### 16.8 Tunables (`data/balance.tres`)
Keys, defaults, allowed values and sources match `prototype-scope.md` §4 one for one. (§4 was updated in the same change for the §16.4a supply-drop decision: the `supply_drop_cost` default 3 → 4, and the new `supply_drop_ready_delay` row.) Each is switchable without code, covered by a test, and on the hidden dev panel.

| Key | Default | Allowed | Source | Rules |
|---|---|---|---|---|
| `hand_size` | **5** | 4, 5 | Q6 (head: "maybe 5"), sim re-check in plan §2 | D4, R1–R3, §16.4 |
| `health` | 5 | 4–6 | Q6 | D3, S4, R15 |
| `packing_rule` | `hold_and_stow` | `hold_and_stow`, `rack_swap` | F1 (backup rule) | R50, R51 |
| `hold_limit` | 2 | 1, 2 | F1 | R50, P3 |
| `hold_looted` | false | true / false | F8 | R50 |
| `adrenaline_mode` | `move_or_search` | `move_or_search`, `move_only` | F2 | R6 |
| `adrenaline_cap_per_turn` | 0 (no cap) | 0, 2 | F2 | R6 |
| `down_enabled` / `down_value` | true / 1 | on/off, 1 | F3 | D6, R23 |
| `bounty_heal` | 1 | 0, 1 | F4 | R37 |
| `bounty_final_circle_extra` | 1 | 0, 1 | F4 | R38 |
| `bounty_holder_loses_cover` | false | true / false | F5 | R22 |
| `final_circle_hits` | [1, 2, 3] | any list | F6 | R43 |
| `zone_hard_end_card` | 14 | 12–14 | F6 (Q6 said 12; v0.2 uses 14) | S3, R44 |
| `standard_pack` | true | true (custom start is out of scope) | F7 | S4, §16.4 |
| `held_cards_public` | **false** | true / false | Q3 (spec v0.2 had them public) | P2, P15, P19 |
| `hits_on_top_public` | true | true / false | Q3 (Down must be known to the shooter) | P4, P9, P16 |
| `loadout_count_public` | true | true / false | Q3 | P6, P17 |
| `supply_drop_cost` / `crate_cost` / `crate_free_picks` | **4** / 1 / 1 | 3–4 / 0–1 / 0–1 | spec §12; drop cost 3 → 4 per cz02 sweep, §16.4a | R10, R46 |
| `supply_drop_ready_delay` | 0 | 0, 1 | cz02 alternative, §16.4a (switch, off) | R10a |
| `ditch_per_turn` / `min_loadout` | 1 / 6 | 1–unlimited / 6 | spec §5, §12 | R19 (unlimited is stored as 0) |
| `pile_size_outer` / `pile_size_core` | 3 / 2 | 2–4 | spec §3 (2 players) | S3 |
| `ai_think_budget_ms` | 300 | 100–1000 | plan DoD 5 | (AI only) |

- **`hits_on_top_public`** keeps the scope's name, but it means the Hits in the **next draw** (D4), which also counts a stowed Hit that has cycled back up.
- **`zone_hard_end_card` below 14** shortens the deck: 13 ends after final circle II, 12 after final circle I. Gas cards are never dropped.

### 16.9 Mid Game Designer review (logged 2026-11-04)
*Review pass in the Mid Game Designer's voice, done by the Sr Game Designer because the Mid Designer couldn't be spawned for this task. Each point was fixed in the text above before sign-off.*

| # | Mid Designer's note | Resolution |
|---|---|---|
| 1 | "'Hits on top' isn't true once a played Hit is stowed and cycles back up. Which Hits does the badge count?" | D4 and D6 define the next draw. The badge counts every Hit in it (P4), and the table note explains the key name. |
| 2 | "Heal and the Bounty claim must be deterministic for replay: which Hit comes back?" | R15: line first, then hand, last first. R37 uses the same order. |
| 3 | "With a short loadout, a braced card goes to the bottom and is back in the window. Can it brace the LMG's second burst?" | No: R26 (once per card per turn). |
| 4 | "The plan said undo stops at loot. You changed it, so say why." | U4 gives the reason. Shots stay the hard boundary (U3). |
| 5 | "The scope says `ditch_per_turn` 1–unlimited. How does `balance.tres` store unlimited?" | As 0, like `adrenaline_cap_per_turn` (table, R19). |
| 6 | "`final_circle_hits` is 'any list'. What happens with 2 or 4 entries, or a hard end at 12?" | R43 (the last value repeats) and R44, with a table note. |
| 7 | "§9 tiebreaks on cards 'in their loadout'. During a Frag the thrower still has a hand and line, so that would punish them." | R47 counts loadout + hand + line. At round start that equals the loadout, so §9 is unchanged for the final circle. |
| 8 | "§4 has the last player choose the route. In setup the UI lets the human pick." | S2: vs the AI the human picks, and hot-seat follows §4. The AI never picks a route, which keeps the `cz09` drop rule one function. |
| 9 | "A looted Crowbar: does it give Search 2 on the turn you loot it? The spec only says weapons fire at once." | R9: no. Looting isn't playing. This matches `tools/loadout_sim.py`. |
| 10 | "The gas Hit lands on top, then you Hold. Is the gas-hit player Down for the opponent's turn?" | Yes: R40 (held cards go above the Hit, and it stays in the next draw). This matches the sim's pack order. |
| 11 | "Does a weapon with attachments count as 1 or 3 for `min_loadout` and the tiebreak?" | 1 everywhere (D2). A P-9 with attachments can't be ditched (R19). |
| 12 | "Check §16.8 against the scope table." | The same rows, defaults, allowed values and sources as scope §4, which was updated with this change for the drop decision (row 13); a Rules column is added. |
| 13 | "My cz02 proposal: `supply_drop_cost` 3 → 4. And cz02 ran hand 5 on the hand-4 pack order. Is that the right hand-5 order?" | Accepted as the default (§16.4a). The two alternatives were checked: the drop delay is kept as a switch, off, because it allows round-4 eliminations; moving the B/C drop is rejected. The hand-5 order was re-run against three other splits and is confirmed (§16.4), so cz02's numbers stand. A hand-4 caveat was added for the dev panel. |
| 14 | "Art direction (cz15) changed the rarity colours. Does §6 still say grey/green/purple?" | §6 now has the cz15 set: slate, teal, blue, amber, yellow, with letters and 1–5 ticks. |

**Verdict:** approved for `cz04` (QA cases) and `cz05`/`cz06` (data). There's no open design blocker. Watch three things in the playtest: fully braced shots ≤ 35% (hidden held cards, P2); the hand-5 first-turn Move 1 (§16.4) against the round-6 earliest-elimination gate; and match length on route C with drops at cost 4 (sim median 8). `cz09` re-runs the balance sweep with Veteran bots on these defaults.

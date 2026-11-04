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
- **Cost** (top left): the Search needed to loot it. **Rarity:** a coloured gem plus a letter (C grey, U green, R blue, E purple, L gold), readable in black-and-white print.
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

# Rally Point v2: bring your own stack

*Board task `cct-rally-v2` · project `cctiles` · Sr Game Designer · 2026-11-08*
*Follows [Part 3: banners + emblems](emblems.md) (§A Rally Point, the patch rule, §4 collection hook) and the [scripted demo](rally-point-demo.html). Simulator: [`tools/rally_v2.py`](tools/rally_v2.py) (v1 stays in `tools/rally.py`). All names, suits and art direction here are original. Call of Duty is named only as the inspiration for "calling card + emblem" identity.*

The studio head found v1 too thin: *"Where do the emblems and calling cards come from? Both players have a hand? What are the effects of the different symbols? How does one thing boost another?"* and set the direction: *"allow them to build a stack to bring into the game that will be shuffled ... support hundreds of cards and emblems. It's okay to have duplicate alt art but we also need nice variety."*

**TL;DR**
- **Where tiles come from:** each player brings a **12-tile stack** built from their collection (8 or 7 banners, 4 or 5 emblems, at most 2 suits, at most 2 copies of a card, 1 of a legendary), shuffles it and keeps a **private hand of 3**. There is no shared market. The board is the same 8×8. About 17 of the 24 tiles get placed, so every game shows a different slice of your stack.
- **What the symbols do:** the four suits become factions with one-line **drills** that fire when a hub of that suit rallies. ◆ **Strike**: the closer takes +2. ● **Signal**: passes a Charge to linked hubs. ▲ **Ridge**: never wasted, keeps its match bonus at the end. ✚ **Supply**: its owner draws a tile. The v1 rule "matching suit scores 2 per cell" stays as the base.
- **How one thing boosts another:** banners carry one keyword each (Breach, Charge, Relay, Flank, Dig in, Scout and others), and emblems carry a rally rule (Outpost, Bounty, Twin crest, Field Hospital and others). Charges are the glue: Signal tiles put Charges on hubs, and Strike tiles cash them by closing. Every effect is short enough to read in a long-press.
- **Content that scales:** a card's gameplay is a **chassis** (a template, its numbers, a suit and a rarity). Its pictures are **arts**, and any number of arts can share one chassis. Launch has **49 chassis** and **232 arts**. Each season adds about 12 chassis and 90 arts, which gives **97 chassis and about 590 arts after 4 seasons**. Linked calling cards from outside the game become alt arts of existing chassis, so hundreds of cards never mean hundreds of rules.
- **Fair collection:** rarity means variety and complexity, not strength. Every chassis is tuned into one power band by simulation, all commons are owned from day 1, and stats never upgrade. A tuned starter stack wins **49.1%** of its games against curated stacks full of rares and legendaries.
- **Sim headline (`rally_v2.py`, smart AIs):**
  - A planner beats a greedy player **93%** of the time.
  - Reading the card text is worth **56%** against an otherwise equal player who ignores it.
  - A coherent stack beats a random legal pile **56%** of the time.
  - Seats balance at **51.8% / 46.6% (1.6% ties)** with "P2 starts with 1 point".
  - A turn has about **58** legal placements and **6–7** that lead to different results.
  - A game is about **17 placements** (8–9 each, 5–7 minutes on a phone).

> **Terms.** A **banner** is a 1×4 calling-card tile. An **emblem** is a 2×2 badge tile. A **hub** is an emblem placed on the board as a scoring centre, and a **patch** is an emblem pinned over a small gap. A **rally** is a hub firing when its border is full. A **stack** is the 12 tiles a player brings. A **chassis** is a card's gameplay function, and an **art** is one picture of it. A **Charge** is a token on a hub, worth +1 to whoever closes it.

---

## 1. What changed and why

| The head's question | v1 answer | v2 answer |
|---|---|---|
| Where do emblems and calling cards come from? | One shared, neutral, random 16-tile stack | **Your own 12-tile stack**, built from your collection and shuffled. The tiles you place are yours: your banners score for you, and your emblems pay *you* their Command. |
| Do both players have a hand? | No: 3 face-up shared tiles | **Yes: a private hand of 3**, refilled at the end of your turn. Your opponent sees how many tiles you hold and your two suits, not the tiles themselves. |
| What do the symbols do? | Matching suit doubles the points, nothing more | Matching still doubles. Each suit also has a **drill** (one line) and a play style, and every card adds one keyword. |
| How does one thing boost another? | It doesn't | Charges flow from Signal to Strike, Liaisons make two suits score together, Relay banners link two hubs, Field Hospitals turn holes into rallies, and Ridge plays the long game. See section 5. |
| How do we support hundreds of cards? | The collection is cosmetic only | Chassis × art. A few dozen functions, hundreds of pictures (section 8). |

What stays from v1: the 8×8 board, banners and 2×2 emblems, the patch rule, the rally beat ("a hub fires when its border is full and everyone touching it scores"), closing tempo as the core tension, and end scoring for hubs that never rallied.

---

## 2. Rules (one page)

**You bring:** a stack of **12 tiles**.
- **4 or 5 emblems**; the rest are banners. The sim found that a 6th emblem is a trap: every emblem you place is a scoring spot for your opponent too, and 6-emblem stacks won only 37%.
- **At most 2 suits.** Most cards have one suit. A Twin-crest emblem shows two suits and needs both in your stack.
- **At most 2 copies of a chassis.** Different arts of the same chassis count as copies, so you can run two different pictures of Point Man. **Legendary: 1 copy.**
- **Preset stacks:** the game ships 3 starter stacks, and you can save up to 10 of your own. Your **featured calling card** and **featured emblem** (your player card) appear on your side of the board and on the tile backs, as in Part 3 §4.

**Setup:** shuffle your stack and draw 3. Choose the first player at random. **The second player starts with 1 point** (section 10.1 explains why, and why it is a dial).

**Your turn:**
1. **Place one tile from your hand.**
   - **Banner:** on any 4 empty cells in a straight line, horizontal or vertical.
   - **Emblem as a hub:** on any empty 2×2.
   - **Emblem as a patch:** pinned over any *enclosed* gap of 1–4 empty cells. A patch counts as filled and never rallies, unless the emblem is a Field Hospital.
2. **Deploy:** resolve the placed tile's "Deploy" text, if it has any.
3. **Rallies:** every hub whose border is now full fires, oldest hub first.
4. **Refill** your hand to 3. Tiles you drew during the turn may leave you holding 4; you then simply don't draw.

**If nothing in your hand fits:** **Redeploy.** Put one tile from your hand on the bottom of your stack, draw one, and pass.

**Rally:** a hub fires when all the on-board cells around it are filled. That is 8 cells, 2 per side, and the board edge counts as filled. When it fires:
- Every **banner cell touching it** scores **1 point** for that banner's owner, or **2** if the banner **matches** the hub. A banner matches when its suit is the hub's suit, or when its text says it matches.
- The player who **closed** it (filled the last cell) gets **+1**, plus **+1 per Charge** on the hub.
- The hub's **owner** gets its **Command** value (+2 for a standard hub).
- Then the hub's **suit drill** happens (section 3).
- Banner texts that say "Rally:" trigger for each banner touching it.

**End:** the game ends when the board is full, or when both players pass in a row.
- Every hub that never rallied scores its banner contacts at **1 per cell**. There is no closer bonus and no Command. Ridge hubs and Dig-in banners keep the 2 for a match.
- Then "End:" texts score.
- The most points wins. On a tie, the player who closed more rallies wins.

**Session:** about 17 placements, 8–9 per player. At 15–25 seconds a turn, that is **5–7 minutes**.

**Inspect (long press / right click), always available:**
- **Banner:** the upright card art, name, suit, keyword with its full reminder text, rarity and series.
- **Hub:** its suit drill and rally rule, its border progress (6 of 8), its Charges, and a **"if it closed now" preview** (you +7, them +4, closer +3).
- **Your stack:** the tiles left in it, in list order, not in draw order.
- **Opponent:** their 2 suits, their hand count, their stack count, and the emblems and banners they have already played.

---

## 3. The four suits

Every hub shows its drill as one line under its badge. The suit glyphs are the same as in v1, so the demo still reads.

| Suit | Colour, glyph | Drill: when a hub of this suit rallies... | Play style | Keywords that cluster here |
|---|---|---|---|---|
| **Strike** | crimson ◆ | **...the closer gets +2 instead of +1.** | Tempo and closing. Hold the last piece. | Breach, Pioneer, Echo, Jam, Bounty, Outpost |
| **Signal** | amber ● | **...every open hub that shares a banner with it gets 1 Charge.** | Chains and set-ups. Build Charges, then cash them. | Charge, Relay, Uplink, Signal Fire, Beacon |
| **Ridge** | green ▲ | **...nothing extra; but if it never rallies, its contacts keep the match bonus at the end.** | Patience and end-game. Ridge points are never wasted. | Dig in, Flank, Steady, Muster, Rearguard, Citadel, Bastion |
| **Supply** | blue ✚ | **...its owner draws 1 tile.** | Flexibility. Patches, filtering and odd shapes, at the cost of raw points. | Scout, Field kit, Medevac, Reinforce, Airdrop, Field Hospital |

**Why drills and not suit "powers":** a drill fires only at the beat players already watch, the rally. It is one line long and depends only on the hub, so a player can predict it from the board. The +2 for a match from v1 remains the main suit effect, and drills sit on top of it.

**Suit pairs** give 10 identities: 4 mono-suit stacks and 6 pairs. Strike/Signal is "charge and cash", Ridge/Supply is "hold the line", Signal/Ridge is "relay net", and so on.

---

## 4. Keywords (the whole rules surface)

Every card has **one keyword**. A legendary may have two. Every keyword is printed with its reminder text, so a long-press is enough to learn the game.

**Banner keywords**

| Keyword | Text on the card | Trigger |
|---|---|---|
| **Breach +N** | If this banner closes a rally, +N. | rally (as closer) |
| **Pioneer** | Deploy: +1 for each hub this touches. | placement |
| **Ally ●** (Liaison) | Also matches ● hubs. | always |
| **Echo +N** | Rally: +N if two or more hubs rally from the same placement. | rally |
| **Jam** | Deploy: an opponent banner this touches loses its text. | placement |
| **Charge** | Deploy: put 1 Charge on each open hub this touches. | placement |
| **Relay** | If this touches two or more hubs, it matches all of them. | always |
| **Uplink** | Rally: you also score that hub's Charges. | rally |
| **Signal Fire N** | Rally: every other open hub this touches gets N Charges. | rally |
| **Dig in** | If a hub this touches never rallies, this banner keeps its match bonus there at the end. | end |
| **Flank +N** | Rally: +N if this lies along a whole side of the hub. | rally |
| **Steady +N** | End: +N. | end |
| **Muster** | Rally: +2 if two other banners of yours touch that hub. | rally |
| **Rearguard N** | End: +N for each hub this touches that never rallied. | end |
| **Scout** | Deploy: draw 1, then put 1 tile from your hand on the bottom of your stack. | placement |
| **Field kit** | May be pinned as a patch. | placement |
| **Medevac N** | Deploy: +N for each patch this touches. | placement |
| **Reinforce** | Rally: draw 1. | rally |
| **Airdrop** | May be placed on any 4 connected empty cells. | placement |
| **Unmarked** | Never matches: always scores 1 per cell. (This is the price on Supply's flexible cards.) | always |

**Emblem rules** (each emblem has a Command value and, at most, one rule)

| Rule | Text | Trigger |
|---|---|---|
| **Command N** | When this rallies, its owner gets +N. | rally |
| **Outpost** | Rallies when 6 of its 8 border cells are filled. Later contacts don't score. | rally |
| **Bounty N** | The closer gets +N instead of +1 (or +2). | rally |
| **Twin crest ▲** | Also matches ▲ banners. | always |
| **Bastion N** | When this rallies, its owner gets +N for each of its sides on the board edge. | rally |
| **Beacon N** | When this rallies, every open hub within 1 cell of it gets N Charges. | rally |
| **Rally Hall** | All of its owner's banners match it. | always |
| **Field Hospital** | May be pinned as a patch. It then rallies at once, scoring every banner around the gap. | placement |
| **Citadel** | Rallies twice: at 6 filled border cells (1 per cell) and again at 8 (full rally). | rally |
| **Crossroads** | Matches every banner. | always |

**Charges.** A Charge is a small token on a hub, shown as pips on its badge. Charges pay **+1 each to whoever closes the hub**, which might be your opponent. That is the whole risk/reward of Signal: you build the pot, and whoever closes takes it.

**Rules hygiene:**
- Effects never trigger other placements, except Blitz Order's one extra placement.
- Rallies resolve one at a time, oldest hub first.
- Charges never cause a rally.
- So a turn can never loop, and the "if it closed now" preview is always exact.

---

## 5. How one thing boosts another

```
             Charge (Wireman), Beacon, Signal drill, Signal Fire
  SIGNAL  ─────────────── puts Charges on hubs ───────────────▶  pot grows
     │                                                             │
     │ Relay / Liaison: one banner scores on two hubs              │ whoever closes takes it
     ▼                                                             ▼
  RIDGE  ◀── Dig in / Rearguard: open hubs are not wasted ──  STRIKE: Breach, Bounty, +2 closer drill
     │                                                             │
     │ Flank / Muster: own the sides of a hub                      │ Echo: close two at once
     ▼                                                             ▼
  SUPPLY: Field kit, Field Hospital: patch the last hole ──▶ a patch can close two hubs in one move
```

**Combo families (the stack-building layer):**
1. **Charge and cash** (Signal + Strike). Wireman and Beacon load hubs with Charges, and Point Man, Bounty Mark and the Strike drill turn closing into a big payout. The risk is that your opponent closes first, so you load hubs that only *you* can finish, for example one whose last gap only a patch can fill and you hold the emblem.
2. **Double close** (Relay Line, Overrun, Field kit, Field Hospital). A single placement that fills the last cell of two hubs triggers Echo, and a Signal hub's drill can drop a fresh Charge on its neighbour *during the same placement*.
3. **Hold the line** (Ridge). Dig in, Rearguard and the Ridge drill make un-rallied hubs worth almost as much as rallied ones. Your opponent can't deny you by refusing to close.
4. **Two-suit scoring** (Liaisons, Twin crests, Rally Hall, Crossroads). These are the glue that makes a 2-suit stack score 2 per cell more often. They are the most-used effect in the sim, at about 7 off-suit matches a game.
5. **Flex and filter** (Supply). Scout, Airdrop and Field kit trade points for shape and choice, and Supply hubs refill your hand when they rally.

**Worked example: a patch that fires two hubs.** Both hubs sit on the top edge, so their top border is off the board.
```
      1    2    3    4    5    6    7    8
 1   a▲  [A●   A●]   ?   [B◆   B◆]  d◆    .      A = P1's Signal Post (● hub, Command 2)
 2   a▲  [A●   A●]   ?   [B◆   B◆]  d◆    .      B = P2's Strike Point (◆ hub, Command 2)
 3   a▲   b●   b●   b●    b●   c◆   d◆    .      b = P1 Wireman (●), placed earlier: 1 Charge on A and on B
 4   a▲    .    .    .     .   c◆   d◆    .      a = P2 Holdfast (▲)   c = P2 Point Man (◆)
 5    .    .    .    .     .   c◆    .    .      d = P2 Liaison ◆>● (◆, also matches ●)
 6    .    .    .    .     .   c◆    .    .
```
- The two `?` cells form an enclosed 2-cell gap. No banner fits it, so only a patch can fill it, and filling it closes **both** hubs.
- P1 holds a Supply Cache emblem and pins it there as a patch.
- **A rallies first** (it is older):
  - b scores 2 cells × 2 = P1 +4, and a scores 2 × 1 = P2 +2.
  - P1 closed it: +1, plus 1 Charge = +2.
  - Command: P1 +2.
  - **Signal drill:** B shares banner b with A, so B gets a second Charge.
- **B rallies:**
  - d scores 2 × 2 = P2 +4, c scores 1 × 2 = P2 +2, and b scores 1 × 1 = P1 +1.
  - P1 closed it: the Strike drill gives +2, plus 2 Charges = +4.
  - Command: P2 +2.
- **Net: P1 +13, P2 +10.** If P1 waits, P2 can patch the gap next turn and take both closer bonuses and both pots, for a swing of about 12.
- The Wireman's Charge, the Signal relay, the Strike drill and the patch rule each did something. That is "one thing boosting another", in one placement anyone can preview.

---

## 6. The chassis catalogue (49 functions at launch)

Rarity: **C** common (owned by everyone from day 1), **R** rare, **E** epic, **L** legendary. The ID column matches `tools/rally_v2.py`. "Power" is the simulated win-rate change when 2 copies (1 of a legendary) replace plain tiles in a test stack (section 10.4). The band target is the median ±6.

**Banners (1×4), 32 functions (28 in the sim)**

| ID | Name | Suit | Rar | Text | Power |
|---|---|---|---|---|---|
| b01 | Point Man | ◆ | C | Breach +3 | +6.3 |
| b02 | Shock Line | ◆ | C | Pioneer | +6.9 |
| b03–b05 | Liaison ◆>● / ◆>▲ / ◆>✚ | ◆ | C | Ally (the named suit) | +6.7 / +3.6 / +3.9 |
| b06 | Overrun | ◆ | R | Echo +3 | +3.9 |
| b07 | Suppressor | ◆ | E | Jam (a counter card: worth more against text-heavy stacks) | +2.5 |
| b08 | Blitz Order | ◆ | L | Breach +1. If this closes a rally, place another tile now. | +0.6 |
| b09 | Wireman | ● | C | Charge | -2.8 |
| b10–b11 | Liaison ●>◆ / ●>▲ | ● | C | Ally | +3.2 / +1.1 |
| b12 | Relay Line | ● | R | Relay. Echo +2 | +3.6 |
| b13 | Uplink | ● | E | Uplink | +3.6 |
| b14 | Signal Fire | ● | L | Signal Fire 2. Uplink | +4.2 |
| b15 | Dug-In | ▲ | C | Dig in. Steady +1 | **+8.2** (flag) |
| b16 | Long Watch | ▲ | C | Flank +1 | +5.8 |
| b17 | Holdfast | ▲ | C | Steady +1 | **+7.7** (flag) |
| b18 | Liaison ▲>✚ | ▲ | C | Ally ✚ | -3.2 |
| b19 | Overwatch | ▲ | R | Muster | +0.3 |
| b20 | Rearguard | ▲ | E | Rearguard 2 | +2.2 |
| b21 | Bulwark Line | ▲ | L | Flank +1. Dig in | +4.1 |
| b22 | Quartermaster | ✚ | C | Scout. Unmarked | -4.3 |
| b23 | Field Kit | ✚ | C | Field kit. Steady +1 | +5.0 |
| b24 | Liaison ✚>● | ✚ | C | Ally ● | +1.1 |
| b25 | Medevac | ✚ | R | Medevac 2 | -1.7 |
| b26 | Reinforcements | ✚ | E | Reinforce | -2.3 |
| b27 | Airdrop | ✚ | L | Airdrop. Unmarked | -3.6 |
| b28 | Liaison ▲>● | ▲ | C | Ally ● | +1.2 |
| — | Liaison ●>✚, ▲>◆, ✚>◆, ✚>▲ | | C | Ally: the other 4 of the 12-card Liaison family (not in the sim library, same template) | — |

**Emblems (2×2), 17 functions**

| ID | Name | Suit | Rar | Command | Rule | Power |
|---|---|---|---|---|---|---|
| e01 | Strike Point | ◆ | C | 2 | (standard hub) | baseline |
| e02 | Signal Post | ● | C | 2 | (standard hub) | baseline |
| e03 | Ridge Camp | ▲ | C | 2 | (standard hub) | baseline |
| e04 | Supply Cache | ✚ | C | 2 | (standard hub) | baseline |
| e05 | Forward Post | ◆ | C | 0 | Outpost | -4.4 |
| e06 | Lookout | ▲ | C | 0 | Outpost | -3.8 |
| e17 | Listening Post | ● | C | 0 | Outpost | **-6.1** (flag) |
| e07 | Bounty Mark | ◆ | R | 1 | Bounty 4 | +1.1 |
| e08 | Contested Ground | ● | R | 2 | Bounty 3 | +0.7 |
| e09 | Switchback | ●▲ | R | 2 | Twin crest ▲ | +4.1 |
| e10 | Surgeon's Crest | ◆✚ | R | 2 | Twin crest ✚ | -3.7 |
| e11 | Bastion | ▲ | R | 1 | Bastion 2 | +1.6 |
| e14 | Field Hospital | ✚ | R | 1 | Field Hospital | **+8.4** (flag) |
| e12 | Beacon | ● | E | 1 | Beacon 2 | **-5.8** (flag) |
| e13 | Rally Hall | ◆ | E | 0 | Rally Hall | **-6.4** (flag) |
| e15 | Iron Citadel | ▲ | L | 0 | Citadel | +1.9 |
| e16 | Crossroads | ✚ | L | 1 | Crossroads | -0.7 |

**Count:** 27 commons (12 Liaisons, 8 other banners, 7 emblems), 10 rares, 6 epics and 6 legendaries make **49 functions**.

**What the tuning changed** (the first sim pass had chassis from −6 to +16 points of win rate):
- Holdfast went from Steady +2 to +1; one point of end scoring is worth about 4 points of win rate.
- Long Watch went from Flank +2 to +1.
- Overwatch went from "+1 per other banner of yours" to "+2 if two others touch".
- Rearguard became "+2 per hub this touches that never rallied" (it was +3 for being boxed in).
- Iron Citadel's first rally now pays 1 per cell.
- Quartermaster and Airdrop became **Unmarked**: flexibility costs points, and that is Supply's identity.
- Outposts dropped to Command 0, Bounty hubs and Twin crests rose to Command 1–2, and Beacon to 2 Charges.
- Triage Tent (patch bonus) was rebuilt as Field Hospital (a patch that rallies).
- Suppressor lost its suit-kill, and now only removes text.

---

## 7. Stacks

**Three starter stacks** (commons only; every new player owns all three on day 1):

| Stack | Suits | Banners (8 or 7) | Emblems (4 or 5) | How it plays |
|---|---|---|---|---|
| **S1 Spearhead** | ◆ ● | Point Man ×2, Shock Line ×2, Liaison ◆>● ×1, Wireman ×2 | Strike Point ×2, Forward Post ×1, Signal Post ×2 | Tempo. Charge a hub with Wireman, then close it with Point Man on a Strike hub: +2 drill, +3 Breach, plus the Charges. Teaches closing. |
| **S2 Hold the Line** | ▲ ✚ | Dug-In ×2, Long Watch ×2, Holdfast ×1, Quartermaster ×1, Field Kit ×1 | Ridge Camp ×2, Lookout ×1, Supply Cache ×2 | Patient. Lie flush along hub sides and never fear an un-closed hub; Supply hubs refill your hand. Teaches end scoring and patches. |
| **S3 Relay Net** | ● ▲ | Wireman ×1, Liaison ●>▲ ×2, Long Watch ×2, Holdfast ×1, Dug-In ×2 | Signal Post ×2, Ridge Camp ×2 | Chains. Few hubs and many banners; Signal hubs pass Charges along shared banners, Liaisons score on both suits, and Ridge keeps the open hubs worth something. Teaches linking hubs. |

**Three curated stacks** (rares, epics and legendaries; these are the "I've been collecting" decks the sim tests against):

| Stack | Suits | Banners | Emblems | Idea |
|---|---|---|---|---|
| **C1 Blitz** | ◆ ● | Point Man ×2, Overrun, Suppressor, Blitz Order, Relay Line, Shock Line | Bounty Mark, Beacon, Rally Hall, Strike Point, Forward Post | Double closes and Bounty swings |
| **C2 Fortress** | ▲ ✚ | Overwatch ×2, Bulwark Line, Rearguard, Medevac, Field Kit, Reinforcements | Bastion ×2, Iron Citadel, Field Hospital, Supply Cache | Edge hubs and the long game |
| **C3 Signal Web** | ● ▲ | Relay Line ×2, Uplink, Signal Fire, Wireman, Overwatch ×2 | Beacon, Switchback ×2, Signal Post, Lookout | Charges everywhere, cashed by Uplink |

---

## 8. A content system for hundreds of cards

### 8.1 Chassis × art

```
 ART  (picture, title, series, source: original | linked calling card | event)
   └──▶ CHASSIS  (gameplay: kind, suit, rarity, template + numbers)
            └──▶ TEMPLATE  (one keyword or emblem rule: code + reminder text)
```
- **Template:** the rule, written once in code. Launch has **20 banner keywords and 10 emblem rules**.
- **Chassis:** a template with its numbers, suit and rarity. "Breach +3, ◆, common" is Point Man. "Breach +1 + Blitz, ◆, legendary" is Blitz Order.
- **Art:** any number of pictures per chassis. Two different Point Man arts are the same card in play, which is why the copy limit counts chassis, not arts. The inspect view shows the chassis text and the art's own title and series.
- **Duplicates and alt arts:** owning 9 arts of Point Man still means 2 copies in a stack, but you choose *which* 2 pictures. Alt arts are pure flex, and a player can't tell from the board alone how rare your art is (a small foil corner can show it).

### 8.2 The maths

**Launch:**

| Rarity | Chassis | Arts per chassis | Arts |
|---|---|---|---|
| Common | 27 | 6 | 162 |
| Rare | 10 | 4 | 40 |
| Epic | 6 | 3 | 18 |
| Legendary | 6 | 2 (base + prestige) | 12 |
| **Total** | **49** | | **232** |

- **Unique functions:** 49 chassis built from 30 templates.
- **Possible stacks:** with ~22 chassis available to a typical suit pair and 2 copies each, there are tens of millions of legal stacks, of which perhaps a few dozen are good. That is the healthy shape.
- **Functional variety a player sees:** each game places about 17 of 24 tiles from two stacks, so about 10–14 different chassis appear per game.

**Per season (about 10 weeks):**
- **+1 template** (one new keyword or emblem rule, e.g. "Ambush", "Convoy").
- **+12 chassis:** 6 banners and 4 emblems on old and new templates, plus 2 legendaries.
- **+90 arts:** about 40 for the new chassis, and 50 alt arts for existing chassis, including event and series art.

| | Launch | Season 1 | Season 2 | Season 3 | Season 4 |
|---|---|---|---|---|---|
| Templates | 30 | 31 | 32 | 33 | 34 |
| Chassis (functions) | 49 | 61 | 73 | 85 | **97** |
| Arts | 232 | 322 | 412 | 502 | **592** |
| Plus linked calling cards (hypothetical) | — | +100s | +100s | +100s | +100s |

**Linked calling cards (the "hundreds" lever).** If the hypothetical account link ever exists (Part 1 §2.4 lists what is speculative), each imported calling card becomes an **alt art of an existing banner chassis**. The mapping is a table keyed on the card's series, for example "a sniper-mastery series maps to Long Watch". Unmapped cards fall back to a hash into the 27 commons. A thousand imported cards therefore add zero rules and zero balance risk, and every one of them is playable on day 1. Emblems from the link work the same way: they become arts of the 17 emblem chassis.

**Why this many chassis and no more:**
- 49 functions in 30 templates means a new player learns about 10 words to read every common.
- The 6 legendaries and 6 epics are the "build-around" cards that make collecting matter.
- 12 new chassis a season is enough to change the best stacks without making older cards obsolete. No rotation is needed for the first 4 seasons; at about 100 chassis, consider a "Standard" rotation for ranked only.

### 8.3 Rarity, mastery, upgrades

- **Rarity = complexity and novelty, not power.**
  - Commons are one simple keyword.
  - Rares are conditional or two-sided (Bounty pays whoever closes).
  - Epics change how you plan (Uplink, Rally Hall).
  - Legendaries bend a rule (an extra placement, any shape, a second rally).
  - All of them sit in one power band (section 10.4).
- **No stat upgrades, ever.** A level-50 Point Man has Breach +3, like a fresh one.
- **Mastery (per chassis):** placing a chassis earns stars (1–5).
  - Stars unlock that chassis' alt-art frames and a mastery title.
  - At 3 stars they unlock the chassis' **variant**: a sidegrade on the same template and the same power budget. For example "Point Man, Recon variant: Breach +2, Pioneer". A variant counts as the same chassis for the copy limit.
  - So play time widens your choices, never your power.
- **Breadth rewards** (Part 3's "rally with 20 different emblems") stay, now with gameplay meaning: they push players to try other stacks.
- **Pairings** (Part 3 §4) stay cosmetic. A paired banner touching its emblem plays a unique rally animation.

### 8.4 How the collection feeds gameplay fairly

The old E4 recommendation was to keep the collection out of gameplay. The head wants it to feed gameplay. The proposal is **"own the function, not the power"**:
1. **Day 1:** every player owns **all 27 commons at 2 copies**, plus the 3 starter stacks. Any common stack anyone can build, a new player can build.
2. **Rares and above unlock through play:**
   - the season track;
   - daily Pinwheel prize emblems (Part 3 §3B);
   - missions such as "rally 10 Signal hubs";
   - linked calling cards, if the link exists.
   - You "own" a function as soon as you own any one art of it, and you get its second copy from duplicates or from Salvage.
3. **Duplicate protection:** a third copy of a chassis you already own twice becomes an alt art if one is missing, or else **Salvage** (crafting currency).
   - Salvage buys any chassis you have seen played against you.
   - A pity timer guarantees a new function at least every 10 unlocks.
4. **Every chassis in one power band**, checked by simulation before release and by live win rates after (section 10.4).
5. **Modes:**
   - **Casual** and **Ranked** use your own stacks. Matchmaking uses skill rating only.
   - The first 10 games are against AI and new players.
   - **Field Test** (rotating weekly event) lends everyone the full library, so you can try a legendary before you chase it.
   - The **solo daily** keeps v1's seeded shared stack, so the leaderboard is pure skill.

---

## 9. Implementation notes (Godot 4.4.1)

- **Data:**
  - `chassis_def.gd` (`class_name ChassisDef extends Resource`): `id: StringName`, `kind`, `suit`, `rarity`, `template: StringName`, `params: Dictionary`, `command: int`.
  - `art_def.gd`: `id`, `chassis_id`, `texture`, `title`, `series`, `source`.
  - `stack_def.gd`: `Array[StringName]` of art ids, validated by `stack_rules.gd`.
  - Saved as `snake_case.tres`.
- **Rules:**
  - `rally_rules.gd` owns the board state. Templates are small scripts in `templates/`, e.g. `breach.gd`, each implementing only the hooks it needs: `on_deploy(ctx)`, `on_rally(ctx)`, `on_end(ctx)`, `matches(banner, hub) -> bool`.
  - The resolver emits signals (`rally_fired(hub, payouts)`, `charge_added(hub)`), and the UI tweens off those signals.
  - New seasons add template scripts and `.tres` files, not rules code.
- **Inspect:** the reminder text is generated from the template and its params, so it can never drift from the code. The "if it closed now" preview runs the resolver on a cloned state, as `rally_v2.py` does.
- **AI:** the sim's "smart" player is about 60 evaluations per turn on a cloned state. It is cheap enough for a phone if it runs on a worker thread.
- **Delta to the Part 3 prototype week:**
  - Day 3 grows: templates and Charges.
  - Day 6 becomes: a stack builder with the 3 starters, 49 chassis with placeholder original art, mastery stars and the Salvage mock.

---

## 10. Simulation (`tools/rally_v2.py`)

Standard library only. Run `python3 -I rally_v2.py 100` for all sections, or name some: `seat`, `skill`, `stacks`, `synergy`, `density`. `power` is slow and not in `all`.

The AIs:
- **random:** any legal placement.
- **greedy:** the best immediate net points.
- **smart:** immediate points, plus an estimate for every open hub (contacts × chance to rally, Ridge and Dig-in end value), minus exposure (a hub the opponent can close next turn costs its closer bonus and Charges), plus small values for draws and extra placements.
- **text-blind:** the smart player, but it evaluates every placement as if all cards were plain v1 tiles, with no keywords and no drills. The real rules still apply.

All results are from games between two stacks; every pairing is played from both seats.

### 10.1 First-player edge

Smart mirror, the same stack on both sides, all 6 stacks, 1,200 games per row:

| AI style | Compensation | P1 wins | P2 wins | Ties | Points per game | Placements |
|---|---|---|---|---|---|---|
| hub-wary (default) | none | 54.2% | 44.8% | 0.9% | 67.9 | 17.0 |
| hub-wary | **P2 starts with 1** | **51.8%** | **46.6%** | 1.6% | 68.1 | 17.1 |
| hub-wary | P2 starts with 2 | 47.0% | 52.5% | 0.5% | 70.0 | 17.0 |
| hub-wary | P1 starts with 2 | 61.7% | 37.6% | 0.8% | 69.6 | 17.0 |
| hub-wary | centre Rally Point + P2 starts with 2 | 52.9% | 46.1% | 1.0% | 70.3 | 15.5 |
| hub-eager | none | 38.7% | 60.4% | 0.9% | 75.5 | 16.7 |
| hub-eager | P2 starts with 1 | 35.3% | 63.8% | 0.9% | 76.4 | 16.6 |
| hub-eager | P1 starts with 2 | 46.3% | 52.5% | 1.2% | 78.1 | 16.7 |

A separate 600-game check of "P2 starts with 1" gave 50.7% / 48.5%.

- **The edge is a parity effect, like the endgame of Dots and Boxes.** It comes from who makes the last placements and who is forced to open a hub. Its sign depends on play style.
  - A **hub-wary** player (the default smart AI) gives the first player about a 54–56% edge.
  - A **hub-eager** player, one that values its own Command and opens hubs early, flips it: the *second* player wins about 60%.
  - Humans will sit somewhere in between, and will learn parity.
- **Recommendation:**
  - Ship **"the second player starts with 1 point"** as a visible **komi** (a "Rally Flag" token on the scoreboard).
  - Log seat results from the first playtests, and adjust the komi between 0 and 2.
  - The tie-break "more rallies closed" stays.
- **Rejected:** a neutral centre Rally Point pre-placed on the board. It is thematic, but it shifts the edge to P1 by changing the placement parity, and it still needs a komi.
- **Board fill:** about **17 placements** per game, with **1.7 cells** left empty at the end (2.7%). The patch rule still does its job with personal stacks.

### 10.2 Skill and combos

600 games per row, random pairs of the 6 stacks, both seats:

| A vs B | A wins | B wins | Ties |
|---|---|---|---|
| greedy vs random | 72.3% | 26.7% | 1.0% |
| **smart vs greedy** | **93.3%** | 6.3% | 0.3% |
| **smart vs text-blind** | **56.2%** | 43.0% | 0.8% |
| blind (reads only immediate text) vs text-blind | 52.0% | 46.8% | 1.2% |

An earlier 500-game run with the same AI weights gave smart vs greedy 95.3% and smart vs text-blind 57.6%.

- **Planning dominates.** A smart player beats a greedy one about 93–95% of the time, which is the strongest skill signal we have measured, as in v1. Greedy beats random about 72%.
- **The card text matters, but less than the geometry.** A smart player who reads the text beats an equal player who ignores it **56%** of the time. Knowing only the *immediate* effects is worth nothing (blind vs text-blind is about 50%). The value comes from planning around Charges, Ridge end value and two-suit matching.
  - A tuning note: an AI that over-valued its own Command (+2 for its own hub) *lost* to the text-blind player. "My emblem pays me" tempts players into opening hubs too early. That is a real lesson for tutorials and for the inspect preview, which shows *both* sides' payouts.
- **Stack building matters.** Each named stack against a random legal stack of the same size:

| Stack | Wins against a random legal stack (200 games) |
|---|---|
| S1 Spearhead | 62.5% |
| S2 Hold the Line | 56.8% |
| S3 Relay Net | 57.2% |
| C1 Blitz | 53.8% |
| C2 Fortress | 58.5% |
| C3 Signal Web | 49.2% |

- On average a built stack wins **56%** against a random pile of the same cards, so stack building is a real skill, but a modest one. A newcomer's random deck is not hopeless.
- Signal Web's 49% says its Charges help the opponent about as often as they help it. It is the first candidate for a closer card.

### 10.3 Starter against curated stacks

Smart mirror round robin, 400 games per pairing (both seats), with "P2 starts with 1". The table shows the row stack's win %:

| | S1 | S2 | S3 | C1 | C2 | C3 | **Average** |
|---|---|---|---|---|---|---|---|
| **S1 Spearhead** | – | 49.6 | 50.9 | 55.8 | 49.4 | 49.8 | **51.1** |
| **S2 Hold the Line** | 50.4 | – | 53.4 | 46.2 | 42.1 | 50.2 | **48.5** |
| **S3 Relay Net** | 49.1 | 46.6 | – | 54.2 | 45.8 | 48.5 | **48.9** |
| **C1 Blitz** | 44.2 | 53.8 | 45.8 | – | 46.1 | 48.6 | **47.7** |
| **C2 Fortress** | 50.6 | 57.9 | 54.2 | 53.9 | – | 49.9 | **53.3** |
| **C3 Signal Web** | 50.2 | 49.8 | 51.5 | 51.4 | 50.1 | – | **50.6** |

- **The starter stacks hold up:** across all starter-vs-curated pairings, starters win **49.1%**, which is within the brief's ±5 points.
- **The spread** between the best and worst stack is **5.6 (47.7% to 53.3%; the worst single pairing is 42.1%, S2 against C2)** points of win rate.
- **What it took:**
  - Cap emblems at 4–5 per stack. 6-emblem stacks won about 37%, because every hub you place is a scoring spot for both players.
  - Tune the three outliers by hand. Relay Net moved to 8 banners and 4 hubs, and Blitz swapped a Bounty Mark for a Forward Post and a Shock Line.
- **Ability triggers per game:** off-suit matches 6.8, Charges cashed 2.3, Signal relays 1.5, Flank 1.0, Supply draws 0.8, Pioneer 0.6, Charge 0.5, Reinforce 0.4, Echo 0.3, Muster 0.3, Uplink 0.25, Breach 0.2, Beacon 0.2, Bastion 0.2, Citadel 0.2, Scout 0.2, Field Hospital rallies 0.2, Bounty 0.16, Signal Fire 0.12, Jam 0.09, Blitz 0.05. Medevac never fired in these stacks, because patches are usually placed after the banners around them; it needs a redesign, e.g. "Rally: +1 for each patch touching that hub".

### 10.4 Chassis power band

Each chassis' power is its win-rate change when 2 copies (1 for a legendary) replace plain banners, or standard hubs, in a plain 2-suit test stack. The test plays smart mirrors, 500 games per chassis, so the standard error is about ±2.2 points.

Final run: 41 chassis, 500 games each. The median is **+1.6** and the band is median ±6, i.e. −4.4 to +7.6.
- **35 of 41 chassis sit inside the band.** Before tuning, the spread was −6 to +16.
- **Six fall just outside**, all within about one standard error of the edge, and are flagged for the next pass:
  - Field Hospital +8.4, Dug-In +8.2 and Holdfast +7.7 are high. Steady +1 is cheap points: about 4 points of win rate per point.
  - Beacon −5.8, Listening Post −6.1 and Rally Hall −6.4 are low.
- **Proposed fixes for that pass:**
  - Dug-In loses Steady.
  - Holdfast becomes "End: +1 if it touches a hub".
  - Field Hospital drops to Command 0.
  - Beacon and Listening Post go to Command 1.
  - Rally Hall goes to Command 1.
- The full sorted list is printed by `python3 -I rally_v2.py 250 power`.

- The aim is not "equal to plain": a typical keyword *should* beat a blank tile. The aim is that **every chassis sits in one band around the median**.
- **Counter cards** like Suppressor test low against plain stacks, because there is no text to jam, and are worth more in the real meta. Live data must judge those.

### 10.5 Decision density

Smart mirror, mixed stacks, 150 games: **58.2** legal (tile, placement) options per turn, **6.4** distinct outcome values (rounded to 0.1 point), and the best option beats the median by **2.82 points**. With the earlier, hub-eager AI weights the same measure gave 67.7 options, 8.0 distinct and 3.02 points. v1 had 38–42 options, 6.6 distinct and 1.2 points.

- A typical turn offers about **60 legal (tile, placement) pairs**, about 3× v1, because you choose among 3 tiles in hand.
- About **6–8 of them** lead to genuinely different results.
- The best move beats the median by about **2.8–3.0 points**. That is a lot: the average winning margin is about 8.

### 10.6 Caveats

- The AIs are 1-ply heuristics. The parity result in particular needs human playtests.
- "Power" is measured against a plain test stack, not the live meta.
- Scout is modelled with a simple bottom-a-tile rule. Jam picks the opponent banner with the most text and contacts.
- The 4 Liaisons and the mastery variants not in the sim library use templates the sim already covers.

---

## 11. Questions for the studio head (recommended option first)

1. **How much may the collection affect play?**
   - **(a) Own the function, not the power (recommended).** All commons from day 1, rares and above by play, every chassis in one power band, no stat upgrades, and a weekly Field Test that lends the full library.
   - (b) Gameplay-neutral as in Part 3: everyone has every function, and the collection is art only. It is the safest, but there is no deck-building chase.
   - (c) Power progression (upgrades and levels). Not recommended: it is pay-to-win, and starters stop being competitive.
2. **Stack size and hand:**
   - **(a) 12 tiles, 4–5 emblems, a hand of 3 (recommended).** About 17 placements and 5–7 minutes; you see 9–11 of your 12 tiles.
   - (b) 10 tiles, a hand of 2. Faster to build, but fewer options per turn and less of your collection on show.
   - (c) 15 tiles, a hand of 3. More variety per game, but 4–6 tiles never appear, so the deck feels random.
3. **Suit rule for stacks:**
   - **(a) At most 2 suits (recommended).** 10 clear identities, and Liaisons and Twin crests become the glue.
   - (b) Any suits. Freer, but stacks blur into "best cards of every suit" and suit identity fades.
   - (c) 1 main suit plus up to 3 "splash" tiles. More nuance, but harder to explain.
4. **First-player fairness:**
   - **(a) The second player starts with 1 point, tuned from playtest logs (recommended).**
   - (b) A neutral centre Rally Point pre-placed, plus a 2-point komi. More theme, but more setup.
   - (c) No compensation. The sim shows a 54–60% edge for one side, depending on play style.
5. **How interactive should cards be?**
   - **(a) Mostly self-focused keywords plus a few counters like Jam, at epic rarity (recommended).** Players read their own cards; the interaction comes from the shared hubs.
   - (b) No direct interaction at all.
   - (c) A "tactics" class of cards that move or remove opponent tiles. It adds depth, but it breaks the "if it closed now" preview and adds long-press reading on the opponent's turn.

# CardZone: Market Scan

*Market Analyst · 2026-11-04 · Board task `cz-market` · Phase: design*

**Scope.** Digital and tabletop deckbuilders, with a focus on deterministic designs (no shuffle), and on combat or warzone deckbuilders, so we can check the originality of CardZone's concepts. This is a desk scan from studio knowledge of published games. It names **genre patterns**, not a clone target. Games are named only as market context. None of their names, rules text, art or branding goes into CardZone. We did not run a paid data pull: sizes are qualitative, and every "we found no precedent" claim must be checked again before we use it in external material (see Risks).

**Studio head's brief (2026-11-04).** CardZone is a **battle-royale warzone deckbuilder**. You start with a 10-card **loadout** (the deck), loot weapons, items and attachments of different rarities, and fight to survive while a **gas** zone pushes the game forward. It must have **no random effects** and **minimal bookkeeping**, it must play the same on the web and on a table, and it needs **one original innovation**.

---

## 1. The genre at a glance

| Segment | What it looks like | What matters for us |
|---|---|---|
| **Tabletop deckbuilders, shuffle family** | The classic loop: start with a weak deck, buy from a supply, shuffle the discard pile, draw 5. Many variants add a map (dungeon crawl, area control), a market row, or hybrids with worker placement. | This is the "improve your deck" fantasy everybody knows. Its best-known complaint is **shuffle variance**: dead draws, a lucky hand early, "I lost to the shuffle". |
| **Tabletop, deterministic or hand-cycle family** | Your whole deck is your hand. You play cards to a discard row, then spend a turn taking them all back (a reclaim, rest or tribune action). Also: decks that are never shuffled (you choose the order of your discards), and rondel games (a wheel of actions where moving further costs more). | **Proof that deckbuilding works without a shuffle.** These games are praised for depth and fairness. Their criticisms are dryness, AP (analysis paralysis) and weak "discovery". |
| **Digital roguelike deckbuilders** | Single-player runs: build a deck while fighting a series of enemies, with relics and branching maps. The biggest commercial segment of deckbuilding today, from several multi-million sellers. Poker-hand and slot-machine variants are recent breakout hits. | Players love **visible enemy intent** (you see what the enemy will do next turn, then plan around it). That is deterministic information inside a random game, and it maps directly to a visible gas clock. |
| **Digital adaptations of tabletop deckbuilders** | Official apps, plus browser platforms that host tabletop games for real-time and async play. | **Web plus async is a proven channel for tabletop strategy.** A game with no hidden draws needs no anti-cheat for card order and is easy to replay, spectate and undo. |
| **Battle royale (video games, genre context)** | Drop into a map, loot gear by rarity colour, attach mods to weapons, fight, and a shrinking zone forces encounters. The last player or squad standing wins. | The fantasy the head wants: **drop choice, loot rush, gear upgrades, zone pressure, final circle.** The visual vocabulary (rarity tiers in grey/green/blue/purple/gold, a zone timer) is a genre convention, not anyone's IP. |
| **Combat and skirmish deckbuilders (tabletop)** | Deckbuilding plus a map with units or squads. Combat usually uses dice or a random draw to resolve hits. Damage is often modelled as **junk cards added to your deck** (wounds, stress or curses). | The closest neighbours to CardZone. **Almost all of them resolve combat with dice or a random draw**, so deterministic shooting is a clear gap. |

**Verdict: GO** for a design-first project. Deckbuilding is a well-known, evergreen tabletop mechanic, and the battle-royale fantasy is one of the most recognised in games. Physical battle-royale board games exist but are a small niche, and they mostly use dice. **No mainstream product combines deterministic deckbuilding with a battle-royale map.** That is our position.

---

## 2. Deterministic patterns we can use (and their trade-offs)

| Pattern | How it removes luck | Strengths | Weaknesses | Use in CardZone |
|---|---|---|---|---|
| **Fixed-order deck ("loop")** | The deck is never shuffled. Draw from the top, put used cards on the bottom **in an order you choose**. | It keeps the real deckbuilding tension: a bigger deck means your best cards come back less often, so thinning matters. Planning feels like "packing your bag". | Perfect information can cause AP (players solving the whole cycle). Players need a fast default order. | **Core of the recommended concept** (loadout = loop). |
| **Hand-cycle / reclaim** | All cards are in your hand. Played cards go to a spent row, and a reset action takes them back. | Very easy to teach. Zero hidden information. The timing of the reset is a real decision. | A bigger deck does not dilute anything, it only adds options, so "improving the deck" feels weaker and there is no reason to thin. | Concept B (reload). |
| **Rondel** | Actions sit on a wheel, and you move a marker around it. Moving further costs resources. | Elegant, deterministic, shows tempo on the table. | Needs a board, and the action menu is fixed. | Concept C (the map is a rondel that shrinks). |
| **Open supply piles (static market)** | Every buyable card is in a face-up pile, so all of them are always available. | No setup randomness, zero discovery luck, clear strategy. | No discovery: it feels like a shop, not loot. | Inside each map area (loot gated by location). |
| **Market row / conveyor** | A face-up row of cards. Cards slide along and get cheaper or drop out, and new ones enter from a deck. | Shared contention, a sense of time passing. | A deterministic version needs a **pre-sorted deck** (setup cost), and if a shuffle is used it is random. | Concept D (the conveyor is the gas clock). |
| **Telegraphed events** | Upcoming events are visible ahead of time (a fixed event track or deck). | Turns "random events" into planning. Very strong in digital tactics games. | Less surprise on repeat plays, so it needs several printed routes. | **Gas and supply drops** in every concept. |
| **Draft / bidding at setup** | Players choose the variable setup (map, drop areas, piles) in turn order. | Variety without randomness. | Takes setup time, and new players need presets. | Drop order and route choice. |

**Seating, tie-breaks and first-player advantage** are the hidden costs of a deterministic game. Every concept needs a fixed tie-break and first-player compensation (for example, the last player picks first at setup).

---

## 3. What players praise and reject

**Praise:** "I lost because of my choices, not the shuffle." Big-turn engine moments. Thinning your deck down to a lean killer core. Seeing enemy intent in advance and outplaying it. Async web play with friends.

**Reject:** Long setup and teardown. Fiddly upkeep (many tokens, many counters, health dials per unit). Player elimination early in a long game. Kingmaking in 3–4 player games. "Multiplayer solitaire" where players never interact.

**Implications for a physical battle-royale deckbuilder:**
1. **Health must not be a dial.** Use cards (damage as junk cards) so state lives in the deck.
2. **The gas clock must be a deck or a single marker.** One flip per round, nothing else.
3. **Elimination must happen late.** The gas has to bring the end quickly once players start dying, or eliminated players need something to do.
4. **Interaction must be strong.** Shooting is the interaction, so it has to happen often, with a reason to engage (loot from the person you eliminate).

---

## 4. Loot without randomness: what the market teaches

Battle royale looting is exciting because of **discovery** (what's in that building?) and **rarity** (gold!). Tabletop games usually get discovery from a shuffled deck. Our deterministic options:

| Option | Discovery feel | Determinism | Setup | Contention | Note |
|---|---|---|---|---|---|
| Static market (identical piles, available anywhere) | Low | Full | Fastest | Low | Feels like a shop. |
| **Location-gated static piles** (each area has its own piles; rarer gear sits nearer the centre) | Medium: "where do I drop for a shotgun?" | Full | Fast | **High**: players race to the same areas | Turns the battle-royale **drop choice** into strategy. |
| Shared face-up row, refilled from a fixed sequence | Medium | Full if the sequence is printed | Sorting at setup | High | Contention is good, sorting is the cost. |
| Revealed fixed loot order (conveyor) | Low–medium (you see it coming) | Full | Sorting at setup | Medium | Doubles as a clock. |
| Sealed caches (face-down, in a fixed printed order) | **High** on first plays, low after you memorise them | Deterministic, but **hidden information** | Sorting at setup | Medium | Not random, but it breaks "open information" and rewards memory. |
| Supply drops on a telegraphed clock | **High** (a single gold card lands, and everyone sees it coming) | Full | None | **Very high** | A natural battle-royale beat that draws players together. |
| Crates from eliminated players | High (whatever they built) | Full | None | High | Rewards fighting. |

**Recommendation to design:** combine **location-gated piles**, **telegraphed supply drops** and **crates from eliminated players**. That gives discovery through space and time instead of through chance.

---

## 5. Originality check (concepts from `design/concepts.md`)

| Concept | Claimed innovation | Nearest precedents (pattern) | Our assessment |
|---|---|---|---|
| **A. Loadout Loop** | **Your next hand is your armour.** The deck is never shuffled, so the top 4 cards of your loadout are public knowledge. When shot, you defend by **burning cards from your known next hand** (Brace), and every hit you take lands **on top** of your loadout as a dead card that jams your next turn. | No-shuffle decks with player-chosen discard order exist. Damage-as-junk-cards exists (added to the hand or the discard pile). Reaction cards from hand exist. | **High.** The individual parts have precedent, but we found no published deckbuilder where the **known top of the deck is both the defence budget and where damage lands**. Defence and offence trade off on the same visible cards. Verify before making an external claim. |
| **B. Reload** | **Reclaim = reload, with an exposure window.** Your whole loadout is in hand. Taking cards back is a reload turn, and everyone can see when your weapons are spent. | Hand-cycle and reclaim games exist, as do rest actions that recover cards. | **Low–medium.** The mechanic is known. The theming (reloading means you are visibly exposed) is fresh but thin. |
| **C. Shrinking Ring** | **The rondel shrinks.** The map is a wheel of action areas, and the gas removes areas from the wheel, so your movement and loot options contract together. | Rondels are well known. Removing board areas over time is common in survival games. | **Medium–high.** We found no rondel whose spaces are removed by a clock. Strong, but it pulls the design toward a board game with a deck attached. |
| **D. Supply Line** | **The market is the clock.** A face-up conveyor of loot advances every round. When it runs out, the final circle starts. Positions are seats around the table. | Conveyor markets that slide and discard exist, and so does "game ends when the deck runs out". | **Low–medium.** Very lean, but the closest to existing patterns. |

**Conclusion:** Concept A has the strongest and most defensible innovation, and it ties directly to the "shooting" fantasy. Concept C is a strong second innovation and can be kept as a map variant.

---

## 6. Audience and channel

- **Primary:** core strategy players (18–40) who like tabletop deckbuilders and know battle-royale video games. They value skill expression and short sessions.
- **Secondary:** battle-royale video game players curious about tabletop, and print-and-play hobbyists.
- **Web first:** async and real-time play in the browser, with a free print-and-play PDF as the funnel to the physical game. A deterministic game makes **move logs, replays, undo and spectating** almost free to build.
- **Monetisation:** not in scope for the design phase (`project-config.json`: not applicable). Natural options later: a premium physical edition plus map and route expansions, or a free web game with paid cosmetics. Never sell power.

## 7. Risks

| Risk | Level | Mitigation |
|---|---|---|
| AP from perfect information | High | A default "pack in play order" rule, a hand size of 4, a turn timer on the web, and short rounds. |
| Player elimination in 3–4 player games | High | The gas makes the end fast after the first elimination. Decision for the head: last-player-standing vs placement points vs redeploy (see DESIGN_REVIEW). |
| Solvability / repetitive openings | Medium | Several maps and gas routes, a drop draft, and player interaction. |
| "Dry" feel without luck | Medium | Supply drops, crates and a strong theme deliver the loot rush. |
| Originality claim fails a deeper check | Medium | Run a focused prior-art search (rules databases, forums) before any external claim. |
| Physical component cost | Low–medium | About 150 cards, a few pawns and no dice. Fits a small box or a print-and-play PDF. |
| IP proximity to battle-royale video games | Medium | Generic military gear names, an original map and setting, no logos, weapon names or skins from existing games. Rarity colours are a genre convention, and each tier also gets a letter (C/U/R/E/L) for colour-blind and print use. |

## 8. Next steps for the Producer
1. Sr Designer: four concepts, each naming its innovation (`design/concepts.md`).
2. Mid Designer: detailed spec of the recommended concept (`design/mechanics/loadout-loop-spec.md`).
3. Before the prototype: a paper playtest with print-and-play sheets, then a Godot web rules engine (no RNG, so replays are deterministic).

# CardZone: Concepts

*Sr Game Designer · 2026-11-04 · Board task `cz-concepts` · Phase: design*
*Inputs: the head's concept (10-card start, physical-playable, no random effects), the head's battle-royale brief (loot, weapons, items, attachments, rarity, gas, looting and shooting, one original innovation), and `research/market-scan.md`.*

## Hard rules every concept follows
1. **Start with a 10-card loadout** (your deck), and grow it by looting.
2. **No random effects:** no shuffles, no dice, no random draws. If an order matters, it is chosen by a player, printed on a card, or visible to everyone.
3. **Minimal bookkeeping:** state lives in cards on the table. We count every token and tracker (target: **at most one per player plus one shared**).
4. **Web and print:** every rule resolves by hand. The web version adds a UI, AI and async play, but no hidden rules.
5. **Battle-royale fantasy:** drop, loot, upgrade, shoot, and a gas zone that forces the end.

## Shared building blocks (used by all concepts)
- **Card types:** **Weapons** (shoot: Damage and Range), **Attachments** (tuck under a weapon to upgrade it; the weapon and its attachments count as **one card** in your loadout, so they do not dilute it), and **Items** (move, search, heal, armour, grenades). **Starter** cards are weak basics. **Hit** cards are damage.
- **Rarity:** Common, Uncommon, Rare, Epic and Legendary (grey, green, blue, purple, gold, plus the letters C/U/R/E/L). Rarity sets the loot cost **and where the card can be found** (rarer cards nearer the centre or in supply drops).
- **Health as cards:** each player has a **health stack** of 5 Hit cards in front of them. When you take damage, move Hit cards from your health stack into your loadout, where they are dead cards. Healing moves them back. You are eliminated when you must take a Hit and your health stack is empty. **Health is visible and needs no dial.**
- **Shooting without dice:** damage = the weapon's Damage + attachments − the target's protection. Everything in that sum is visible.

## How loot can feel like discovery without luck (options and trade-offs)
| Option | How it works | Discovery | Bookkeeping / setup | Main trade-off |
|---|---|---|---|---|
| 1. Static market | Identical face-up piles, lootable anywhere | Low | None | Feels like a shop, no reason to move |
| 2. **Area-gated piles** | Each map area has its own 2–3 piles. Commons are on the edge, rares at the centre. | Medium | Place piles per a setup sheet | **The drop choice becomes strategy.** Players collide over the good areas. |
| 3. Shared face-up row | One row refilled from a fixed sequence | Medium | Pre-sorted deck | Contention is good, but the sorting is a chore |
| 4. Revealed fixed order (conveyor) | The next N loot cards are visible and arrive in order | Low–medium | Pre-sorted deck | Plannable, and doubles as a clock |
| 5. Sealed caches | Face-down stacks in a printed order | High (first plays) | Pre-sorted, hidden info | Breaks open information, and memory beats skill |
| 6. **Supply drops** | The gas clock announces gold loot landing in an area in round N | High | None (on the clock cards) | Telegraphed, so it draws players into fights |
| 7. **Crates** | An eliminated player's looted cards stay in their area | High | None | Rewards fighting, can snowball |

**Studio recommendation: 2 + 6 + 7.** Discovery comes through **space** (where you drop), **time** (when drops land) and **conflict** (whom you eliminate), never through chance.

---

## Concept A: Loadout Loop (recommended)

**Pitch:** *"Pack your bag, drop in, and live with the order you packed."* Your loadout is a deck that is **never shuffled**. You draw the top 4 cards, use them, and pack them back at the bottom **in any order you like**. Everyone can see what is on top of your loadout, and **so can the people shooting at you.**

**Loadout and draw (deterministic):** draw the top 4. When you **Pack** at the end of your turn, used, unused and looted cards go to the bottom in an order you choose (default: the order you played them). A bigger loadout means each card comes back less often, so thinning and dilution still matter, just like a shuffled deckbuilder but with no luck.

**Map and loot:** 7 area cards: 6 outer areas in a ring around a central Core. Each outer area has 2 **Common/Uncommon** piles, and the Core has the **Rare** piles. Players **drop** into an outer area of their choice (in reverse turn order). **Supply drops** (Epic and Legendary, one copy each) land where the gas clock says. Eliminated players leave a **crate**.

**Gas:** the **Zone deck** has 12 cards in a fixed, printed order, and anyone may look through it at any time. The first player flips one at the start of each round: *Calm*, *Supply drop: X lands at Y*, *Gas closes area Z* (flip that area card to its gas side), and finally *Final circle* (everyone takes 1 Hit every round). Each card lists 3 routes (A/B/C), and the route is chosen at setup. That gives variety with no randomness.

**Shooting:** play a weapon to shoot one player within its Range (0 = same area, 1 = adjacent, 2 = two areas away). Damage = weapon + attachments − Cover (Cover only applies to shots from another area). **The innovation:** the defender may **Brace**. They reveal cards with a Brace value from **their next hand (the top 4 of their loadout)** and move them to the bottom, which reduces the damage. The damage that gets through becomes Hit cards **placed on top of their loadout**, so their next hand is jammed ("suppressed").

**Original innovation: "Your next hand is your armour."** In a deterministic loop, the top 4 cards are public. They are both your defence budget and the place where damage lands. You pack armour high to survive, and that armour is dead weight when you draw it. Shooting someone doesn't just hurt them, it **ruins their next turn**.

**Bookkeeping:** 1 pawn per player and 1 first-player marker. Health stacks, the Zone deck and the gas state are cards. Move and Search points are added up within your turn and then lost, so nothing is tracked. **Tokens: players + 1.**

**Web / print:** print about 150 cards, 4 pawns and 1 marker. On the web, the loadout is shown as a strip of thumbnails (perfect for a "packing" UI), with deterministic undo, async play and replays. **Players:** 2–4 (plus solo against scripted Raiders). **Session:** 30–40 min for 2 players, 50–60 min for 4.

**Risks:** AP when packing (mitigation: a default order and a hand of 4). Player elimination (decision for the head). A 4-damage shot can jam a whole hand (tuning).

---

## Concept B: Reload

**Pitch:** *"Every card you own is in your hand. Spend them, and you're empty, and everyone can see it."*

**Loadout and draw:** there is no draw. Your whole loadout is your hand. Each turn you play up to 3 cards to your **spent row** (face up). Instead of playing, you may **Reload**: take back all spent cards, plus +1 Move. Looted cards go to your spent row, so you only have them after your next reload.

**Loot:** a **shared Drop Line** of 5 face-up cards, priced by slot (cost 1–5). It is refilled in printed order from a pre-sorted loot deck, and rarity rises as the deck goes on.

**Gas:** a single **gas marker** on a 10-step track, advanced each round. At the end of your turn, if the Move you played that turn is less than the gas level, take 1 Hit (**outrun the gas**). There is no map: position is abstract.

**Shooting:** weapons in your **spent row cannot fire**. Shoot any player with Damage − Armour (armour items in their *hand*, revealed when shot). Hits go to the target's spent row and come back with every reload until healed.

**Original innovation: "Reload is the reset, and it shows."** The deck-reset action is a literal reload, and everyone sees when you are empty, which creates ambush windows. *Precedent check: reclaim/rest mechanics are well known, so the innovation is mostly theming.*

**Bookkeeping:** 1 gas marker and 1 first-player marker. **Tokens: 2 in total.**
**Web / print:** the simplest to print (no map). **Players:** 2–5. **Session:** 25–45 min.
**Risks:** a bigger loadout doesn't dilute anything, so "improving the deck" feels weak and there is no reason to thin. Little sense of place.

---

## Concept C: Shrinking Ring

**Pitch:** *"The map is a wheel, and the gas eats it."*

**Map = rondel:** 8 area cards form a ring. Pawns move **clockwise only**: 1–2 steps are free, and each extra step costs a card from your hand. Each area is an action space as well as a loot spot (*Armoury: loot a weapon*, *Clinic: heal*, *Overwatch: +1 Range this turn*, *Cache: loot an item*).

**Loadout and draw:** the same deterministic loop as A (draw 4, pack in any order).

**Gas:** the Zone deck tells you which area card to **remove from the ring**. The wheel gets shorter, pawns get closer, and fights become unavoidable. When 3 areas are left, the final circle starts.

**Shooting:** Range is counted in ring steps, so the same area or the next one along. Damage − Cover (printed on the area). Hits go to the bottom of your loadout (simpler than A).

**Original innovation: "The shrinking rondel."** A rondel whose spaces are removed by a clock, so your action menu and the battlefield contract together. *Precedent check: we found no rondel that shrinks.*

**Bookkeeping:** 1 pawn per player and 1 first-player marker. **Tokens: players + 1.**
**Web / print:** needs 8 large area cards. On the web, the ring is a great animation. **Players:** 2–4. **Session:** 40–60 min.
**Risks:** the rondel's fixed menu may overpower deckbuilding. Moving clockwise only makes chasing feel artificial.

---

## Concept D: Supply Line

**Pitch:** *"The plane flies over once. Loot what it drops before the zone closes."*

**Loot = clock:** a **face-up conveyor** of 6 loot cards (the flight path), refilled from a **pre-sorted Flight deck** in printed order (Commons first, Legendaries last). At the end of each round, the card at the far end burns (it is removed) and everything slides one slot, so it gets cheaper. **When the Flight deck runs out, the final circle starts.**

**Loadout and draw:** a deterministic loop (as in A).

**Position = seats:** you can shoot your left and right neighbours (Range 1). Scopes extend that to players two seats away (Range 2). No map.

**Shooting:** Damage − Brace (from your hand). Hits go to the top of your loadout.

**Original innovation: "The market is the gas."** One conveyor is both the loot and the game clock. *Precedent check: conveyor markets and "game ends when the deck runs out" are both known, so the combination is new but modest.*

**Bookkeeping:** 1 first-player marker. **Tokens: 1 in total.**
**Web / print:** the leanest of all four. **Players:** 3–5 (seats need neighbours, so it is weak at 2). **Session:** 25–40 min.
**Risks:** seat-based range feels abstract (no drop, no map). Sorting the Flight deck at setup and teardown.

---

## Comparison
| | A. Loadout Loop | B. Reload | C. Shrinking Ring | D. Supply Line |
|---|---|---|---|---|
| Battle-royale feel (drop, loot, zone) | **5** | 2 | 4 | 3 |
| Deckbuilding depth (dilution, thinning) | **5** | 2 | 4 | 4 |
| Shooting feel | **5** | 3 | 3 | 3 |
| Innovation strength | **High** | Low–med | Med–high | Low–med |
| Tokens / trackers | players + 1 | 2 | players + 1 | **1** |
| Setup time | ~5 min | **~2 min** | ~5 min | ~5 min (sorting) |
| Players | 2–4 (+ solo) | 2–5 | 2–4 | 3–5 |
| Session | 30–60 min | 25–45 | 40–60 | 25–40 |
| Web fit | **Excellent** (packing UI) | Good | Excellent (ring) | Good |
| Print fit | Good | **Excellent** | Good | Good |

## Recommendation
**Concept A: Loadout Loop**, using the area-gated loot, supply drops and crates. It answers every line of the brief: a 10-card loadout that grows, weapons, items and attachments with rarity, a gas clock that is a deck (no tracker), dice-free shooting that feels like suppression, and the strongest original idea ("your next hand is your armour"). **Keep C's shrinking ring as a future map variant** and B as the fallback if paper tests show packing AP is too high.

**Handoff → Mid Game Designer:** a detailed spec of A (turn, card anatomy, starting loadout, map and loot, gas, combat, win, and 20–30 cards with numbers). **Validation:** a 2-player paper game finishes in 40 min or less, nobody is eliminated before round 6, and a full packing step takes under 30 s on average.

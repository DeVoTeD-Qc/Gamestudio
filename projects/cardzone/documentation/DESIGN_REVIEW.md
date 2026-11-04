# CardZone: Design Review (for approval)

*Master Orchestrator · 2026-11-04 · Phase: design · Status: **awaiting the studio head's decisions** (board task `cz-q`)*
*All names, cards, map and rules are original. Other games are named only as market context in the research doc. Gear uses generic military terms, and rarity colours are a genre convention.*

## Deliverables
| Deliverable | File | Board task |
|---|---|---|
| Market scan (deckbuilders, deterministic designs, originality check) | `documentation/research/market-scan.md` | `cz-market` |
| Four concepts, with loot-without-luck options | `documentation/design/concepts.md` | `cz-concepts` |
| Detailed spec of the recommended concept (27 cards) | `documentation/design/mechanics/loadout-loop-spec.md` | `cz-spec` |
| This review | `documentation/DESIGN_REVIEW.md` | `cz-review` |

## The brief
**Original concept:** a deckbuilder that starts with a 10-card deck, is playable as a physical game, has minimal state upkeep and no random effects.
**Direction update:** a **battle-royale warzone**. The deck is your **loadout**. You **loot** weapons, items and attachments with **rarity**, fight to survive, and a **gas** zone keeps the game moving. It must have a good feel of looting and shooting, and **one original innovation**.

## Market in one paragraph
Deckbuilding is evergreen on the table and booming as digital roguelikes. Its best-known complaint is **shuffle luck**. Deterministic designs (never-shuffled decks, reclaim-your-hand, rondels) prove the genre works without a shuffle, but they are rarely themed around combat. Combat deckbuilders almost all **resolve shots with dice or random draws**, and physical battle-royale games are a small, dice-driven niche. **Gap: a deterministic, battle-royale deckbuilder that plays the same on the web and on a table.** Verdict: **GO**. The main risks are AP from perfect information, player elimination, and an originality claim we still need to verify in depth.

## How each concept answers the brief
| Brief item | A. Loadout Loop (rec.) | B. Reload | C. Shrinking Ring | D. Supply Line |
|---|---|---|---|---|
| 10-card start, grows | Loadout that is never shuffled; pack it in your chosen order | Whole loadout in hand | Never-shuffled loop | Never-shuffled loop |
| No randomness | Chosen order, public Zone deck | Nothing hidden | Chosen order, public Zone deck | Printed flight order |
| Bookkeeping | 1 pawn each + 1 marker | 1 gas marker + 1 marker | 1 pawn each + 1 marker | 1 marker |
| Loot feel | Areas (drop choice) + supply drops + crates | Shared drop line | Areas on a wheel | A conveyor that passes once |
| Weapons / items / attachments / rarity | All; attachments tuck under weapons; 5 tiers | All | All | All |
| Gas | Zone deck closes areas, then the final circle | Gas track: outrun it with Move | Zone deck removes wheel spaces | The conveyor running out = final circle |
| Shooting | DMG − Cover − Brace from **your next hand**; hits land on top | Only weapons not yet spent can fire | Ring range, Cover | Seat range |
| **Innovation** | **"Your next hand is your armour"** (high) | Reload = reset + exposure (low–med) | Shrinking rondel (med–high) | Market = clock (low–med) |
| Players / session | 2–4 (+ solo), 30–60 min | 2–5, 25–45 | 2–4, 40–60 | 3–5, 25–40 |

## Recommendation: Concept A, Loadout Loop
**How it plays:** drop into one of 6 outer areas around the Core. Each turn, draw the top 4 cards of your never-shuffled loadout. Spend Move and Search to move, loot from your area's piles, and shoot. Then **pack** your cards back at the bottom in any order. Rarer loot sits nearer the centre, and the public **Zone deck** closes areas and drops Epic and Legendary gear on a known schedule. The last player standing wins. The game lasts at most 17 rounds.

**The innovation:** with no shuffle, the top 4 cards of everyone's loadout are public. When shot, you **Brace** by burning cards from that known next hand, and the damage that gets through lands **on top** as Hit cards, which jam your next turn. **Packing becomes armour planning, and shooting becomes suppression.** We found no published deckbuilder that does this, but we will verify this more deeply before making any external claim.

**What stays simple at the table:** about 150 cards, 4 pawns and 1 marker. Health is a stack of 5 Hit cards in front of you, the gas is the Zone deck, and attachments tuck under weapons (one card). No dice, dials or counters.

## Key risks
**AP while packing** → Quick pack by default, hand of 4, web turn timer. **Player elimination** → the end is fast (final circle), crates reward the eliminator, placement-points variant (Q2). **Snowballing** (kills give loot) → only 1 free crate card, Cover, Brace. **Repetitive openings** → 3 routes, the drop draft, and more maps later. **Originality** → a deeper prior-art check before any external material.

## Decisions needed (short questions; also on the board as task `cz-q`)
1. **Concept:** go with **A, Loadout Loop**, as recommended? Or C (Shrinking Ring), B (Reload) or D (Supply Line)?
2. **Elimination:** last player standing, with a placement-points variant for 3–4 players (recommended)? Last standing only? Or redeploy, with no elimination?
3. **Open loadouts:** may anyone look through any loadout at any time (recommended), only the top 4, or nobody else's?
4. **Loot model:** area piles + supply drops + crates (recommended)? Add face-down sealed caches for more discovery (hidden info and setup sorting)? Or a shared market row?
5. **Player count:** 2–4 plus a solo mode against scripted Raiders (recommended), 2–4 only, or stretch to 5–6?
6. **Starting values:** health 5, hand of 4, a 7-area map and a 12-card Zone deck (max 17 rounds). OK as the values for paper tests?
7. **Rarity:** 5 tiers, Common to Legendary (recommended), or 3 tiers (simpler print)?
8. **Tone and setting:** a grounded, fictional near-future island (recommended), a stylised arcade look, or decide with the art direction?
9. **Next step:** a paper playtest (print-and-play) first, then the Godot web prototype (recommended), or go straight to the web prototype?
10. **Backlog:** keep C's shrinking ring as a future map variant (recommended), or drop it?

## After approval
Producer plans: (1) a print-and-play sheet and 3–5 paper sessions (2 and 4 players) with a timing log, (2) a balance pass on §12 of the spec, (3) art direction (Sr Game Artist), then (4) a Godot 4.4.1 web prototype with a pure rules engine, packing UI, async play and AI.

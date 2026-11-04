# Warbuilder vs CardZone: Comparison

*Sr Game Designer (run by the Master Orchestrator) · 2026-11-04 · Board task `wb-compare` (part of `wb-assess`)*
*Sources: CardZone `documentation/DESIGN_REVIEW.md` and `documentation/design/mechanics/loadout-loop-spec.md` (v0.2 with §16 prototype rules). Warbuilder: the engine, the build and our playtests. **CardZone was not changed.***

## 1. At a glance
| | **Warbuilder** (imported, playable) | **CardZone** (studio original, in design/prototype) |
|---|---|---|
| Fantasy | Battle-royale duel: loot, shoot, outlast the gas | Battle-royale deckbuilder: loot, shoot, outlast the gas |
| Players | 2 (vs AI or pass-and-play) | 2–4 (+ solo outline). The web prototype is 1v1. |
| Deck | 10-card start, **shuffled**, draw 5 | 10-card start, **never shuffled**: draw 4, hold up to 2, stow in play order |
| Randomness | Yes: shuffles, and shots resolve by revealing your own deck | **None**: shots are Damage − Cover − Brace |
| Health | 30 points | 5 Hit cards that go into your deck when you are hit |
| Defense | Armor (dig-in), cover, Reaction cards in hand | Cover, **Brace** from your public next hand, Down, Bounty |
| Map | 1-D row of 6; gas on one side, new ground on the other (a conveyor) | 7 areas (ring of 6 plus the Core); a public Zone deck closes areas |
| Game end | HP 0. In practice the gas never closes (final circle in 0% of sim games). | HP 0, or a **hard end after Zone card 14**, with escalating final-circle Hits |
| Loot | Location stacks, top card only, cycle; Buy Station; supply crates | Area piles; supply drops on a known schedule; crates from eliminated players |
| Rarity | 5 for guns (grey to gold) + 3 chevrons for cards | 5 tiers with letters and lightness (works in greyscale) |
| Engine | HTML5/vanilla JS (studio exception) | Godot 4.4.1 |
| State | Polished, playable, AI, print-and-play generator | Spec v0.2, sims, web prototype work under way |

## 2. Overlap (the portfolio risk)
They are the **same pitch**: "battle-royale deckbuilder, 10-card start, loot with rarity, gas, playable on the web and on paper". If both ship as is, they compete for the same player and the same store page wording. They do differ in **feel**, though, and that is what we should lean on:
- **Warbuilder = the luck-and-nerve duel.** Flip cards to shoot, push your luck on loot, 1v1, 20 minutes.
- **CardZone = the perfect-information tactics game.** No luck, public loadouts, 2–4 players, armour planning.

**Recommendation:** keep both, and **position them apart on purpose**: player count, luck vs no luck, tone and title. Don't let their names, card names or art drift toward each other. For example, CardZone already has "Recon Drone" and "Dash", so Warbuilder's renames should avoid those (see the IP check).

## 3. What each does better
**Warbuilder does better**
1. **Shooting feel.** Revealing cards and counting Hit Markers is a dramatic moment, and it ties deckbuilding to aim. CardZone's shot is a subtraction.
2. **It exists and it's polished.** It has a full UI, a phone layout, a competent AI and a fire report. CardZone can learn from its UI patterns: the shot preview, the fire report with the revealed cards, "Play all", the end-turn Armor preview, and press-and-hold tooltips.
3. **A paper/web single source of truth.** `gen.js` builds the print-and-play from the live engine data. CardZone should copy this pipeline idea for its PnP.
4. **A headless engine plus AI** in one file. Thousands of matches per minute make balance work fast. The CardZone prototype should keep its rules engine as pure and as Node/CLI-runnable as this one.

**CardZone does better**
1. **A real closing zone with a guaranteed end.** The public Zone deck closes areas on a known schedule, the final circle escalates (1/2/3 Hits), and the game hard-ends after card 14. Warbuilder's gas never closes. This is the most valuable idea to port.
2. **Catch-up by design.** The Bounty (heal 1 for hitting the healthiest player) and Down (+1 Brace while hurt) are explicit, cheap, readable rules.
3. **Bookkeeping discipline.** "No dice, dials or counters." Health is a stack of cards, and per-turn pools vanish. Warbuilder's five per-turn resources are its biggest print-and-play cost.
4. **Rarity readable in greyscale**, with letters on the chip. It avoids green and violet, which read as gas and the safe zone.
5. **Drop choice** (reverse turn order) as the first decision.
6. **Originality hygiene.** Generic gear names and an explicit originality line in the docs.

## 4. Ideas worth porting
**From CardZone into Warbuilder** (proposals for the head; nothing changed yet)
| Idea | How it would look in Warbuilder | Value |
|---|---|---|
| Hard end + escalating final circle | A fixed number of new-ground cards (e.g. 6), then the gas closes from both ends. Final-circle damage 3 → 4 → 5, and the match ends at round 12 (most health wins) | High: fixes the empty gas |
| Public zone schedule | Show "gas in 2 rounds" on each location, and print the phase on the location backs (the PnP already does this) | Medium |
| Drop draft | The second player picks a Start location first, then the first player | Medium |
| Bounty-style catch-up | Hitting the player with more health gives +1 Intel (cheap, no healing) | Low–Medium: comebacks are already 41% |
| Greyscale-readable rarity with letters | One rarity scale for cards and guns | Medium (clarity, print) |

**From Warbuilder into CardZone** (ideas only; CardZone decisions belong to its own board)
| Idea | Fit with CardZone's "no random effects" rule |
|---|---|
| Fire report / shot preview UI (exact numbers before you commit) | Fits perfectly: CardZone's numbers are exact, so the preview can be too |
| Dig-in: unused Move becomes defense | Fits: a deterministic, one-line rule (unused Move → Brace 1 on your held cards?) |
| Location bonus "every turn you stay" | Fits: gives areas identity without randomness |
| Top-card-only loot stacks with a paid cycle | Fits if the piles are face up (they are) |
| Engine-driven PnP generator and a headless AI sim harness | Fits: a pipeline idea, not a rule |
| Revealing cards to shoot | **Does not fit** (it's random). Keep it as Warbuilder's signature. |

## 5. Bottom line
Warbuilder is the **better-feeling game today**, and CardZone is the **better-structured design**. Warbuilder should borrow CardZone's **zone schedule and hard end**. CardZone should borrow Warbuilder's **UI patterns and its paper-from-engine pipeline**. The studio should market them as **two different games**: a luck duel and a perfect-information multiplayer game.

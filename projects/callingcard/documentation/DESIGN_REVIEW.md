# CallingCard: Design Review (for approval)

*Master Orchestrator · 2026-11-03 · Phase: Planning · Status: **approved 2026-11-03** (decisions below; prototype plan in `production/prototype-milestone-plan.md`)*
*Unofficial design pitch about a feature of Call of Duty (Activision). We describe CoD's calling cards only as context. All card names, art direction and mock-ups are original. A prototype would be a **standalone concept demo with original placeholder art**, not a mod or recreation of Call of Duty.*

## Decisions (approved 2026-11-03)
The studio head approved the design and answered all 10 questions. They are **closed** and binding for the prototype plan (`production/prototype-milestone-plan.md`, tasks in `production/prototype-tasks.json`).

| # | Topic | Decision |
|---|---|---|
| 1 | Concept | **Banner Wall (A) with the album slice of B**, as recommended. |
| 2 | Core bet | **Harder-earned cards are stronger** (Clearance from how a card was earned). |
| 3 | Store cards | Store and bundle cards are **always the lowest tier (Clearance 1) with no trait, but get premium frames**. |
| 4 | Where it lives | **Both:** a short mini-game during **matchmaking** and a **separate menu mode**. The demo presents both entry points: a *Lobby Duel* (quick duel during a simulated matchmaking wait, can be saved and resumed) and the full *Banner Wall* menu (album, lineup, rivals, Dossiers). |
| 5 | Rewards | **Cosmetics only** (titles, frames, mode-exclusive cards). No shooter XP or shooter-usable rewards. |
| 6 | Shooter-side features | **Signature Trio (C) and Bounty (D) go to the backlog** for now. The pitch stays on the side mode. |
| 7 | Starting rules | **Approved as starting values:** 10-slot 3-4-3 wall, 5 cards each, Clearance cap 12, Signatures count double. |
| 8 | Puzzles | **Include the Cipher Lock** alongside the 5 Dossiers. |
| 9 | Audience | **Internal only for now.** The one-page summary and the demo capture video go to the backlog. |
| 10 | Load target | **Under 10 s with a loading screen** for the Godot web build (replaces "< 3 s"). |

**IP framing (unchanged):** unofficial pitch; original placeholder art only; the demo is a standalone concept, with no Activision assets or names in the game UI beyond generic terms (e.g. "calling card", "matchmaking", "prestige").

## The problem
CoD players unlock calling cards constantly, from challenges, camo mastery, events, prestige, ranked play, battle passes and bundles (est. several hundred per title). Each card is a wide banner, you can equip **one**, and it's seen briefly in lobbies and killcams. Hard-won cards and filler cards feel the same, and the collection itself does nothing.

## One-line pitch
**"Every card you earned is a piece you can play."** In **Banner Wall**, calling cards are the pieces of a 3-minute duel, and **the harder a card was to earn, the stronger it plays**. Sets, hidden combinations and puzzles turn the pile into an album worth completing. Nothing touches shooter balance.

## What other games teach (market analysis, figures are estimates)
Collections gain value through **(1) multi-slot showcases** (Apex badges, Valorant titles), **(2) completion meta** (Destiny seals and gilded titles, sticker albums), **(3) collection-powered minigames** (Gwent, Triple Triad, Marvel Snap's variant chase), and **(4) proof of skill** (Apex trackers). CoD players respond to prestige, the killcam flex and challenge grinds. They reject pay-to-win and anything that touches ranked integrity. **Verdict: GO** for the pitch and a small web demo.

## Concepts compared
| Concept | Axis | Fun | Collector pull | Integrity risk | Cost | Web demo? |
|---|---|---|---|---|---|---|
| **A. Banner Wall**: side-mode duel with cards as pieces | Mode + tactics + puzzles | 4 | 5 | Very low | M–L | **Yes** |
| B. The Album: sets, hidden Triptychs, cipher glyphs | Puzzles / meta | 2 | 5 | None | S–M | Partly |
| C. Signature Trio: 3 slots (banner, killcam stamp, squad card) | Light tactical / show | 2 | 4 | Low–med | S | Weakly |
| D. Bounty: shooter mode where dropped tags are calling cards | Mode | 4 | 4 | Medium | M | No |
| E. Card Contracts: an equipped card arms a themed match challenge | Tactical planning | 3 | 4 | Low | S–M | No |

## Recommendation: prototype A, with a slice of B built in
**How Banner Wall plays:** each player brings a **lineup of 5 cards** (Clearance cap 12, one marked **Signature**). Players alternate placing them on a **10-slot brick-wall board**. Each card has three values: **Top / Side / Bottom**. Place a card, and any adjacent enemy card with a lower facing value turns to your color. The most cards wins, and Signatures count double ("Carded!" when you take theirs).
- **Origin becomes a trait:** Challenge cards are *Steady*, Mastery *Veteran*, Event *Ambush*, Prestige *Reclaim*, Ranked *Clutch*, and Secret *Cipher*. **Store cards are always the lowest tier with no trait**, but they get the flashiest frames.
- **Sets** give a Set Link bonus. **Triptychs** (three hidden card combos in a row) score a bonus and unlock panorama art and titles. **Dossiers** are handcrafted puzzles that pay out secret cards.

## How it serves CoD players
- **Grinders:** a mastery or prestige card finally *does* something, so the grind gets a second payoff.
- **Collectors:** the album shows what you're missing and *why it would help*. Sets and titles give completion goals.
- **Competitive players:** the shooter and ranked stay untouched. The duel has its own skill (placement reads, lineup building under a cap).
- **Everyone:** it fills matchmaking downtime, and the Signature "Carded!" moment carries over the existing killcam flex.

## Key risks
**Pay-to-win perception** → the binding "earned, not bought" rule. **Veterans crushing newcomers** → Clearance cap, loaner lineups, and fixed-hand puzzles. **Balancing hundreds of real cards** → stats from a metadata formula, with only Legends hand-tuned. **Similarity to existing card minigames** → the brick topology, 3-value banners and origin traits differ, and we acknowledge the genre openly. **IP** → original everything, plus a disclaimer.

## Prototype scope (est. ~7 days after approval)
Godot 4.4.1 single-threaded web build: the full duel rules with all traits, 20 original cards (4 sets + Cipher + Showcase), a lineup builder, 3 AI rivals, an album with unlock goals, 3 Triptychs and a Cipher Lock, 5 Dossiers, procedural placeholder art, a capture preview, and a playtest survey with a local telemetry log. **Not included:** PvP, shooter gameplay, store, accounts, concepts C/D/E. The demo answers one question: *does "harder earned = stronger piece" make players want to collect?*

## Original questions (closed, kept for reference)
1. **Concept:** approve **Banner Wall** (A, with the album slice of B) as the concept to prototype? Or would you rather go cheaper (B + C only: album, sets and a 3-slot showcase, no new mode)?
2. **Core bet:** should earn difficulty make a card **stronger** in Banner Wall (recommended, since that's what gives grinding value)? Or should all cards be equal in power, with only traits differing (fairer, but weaker collector pull)?
3. **Store cards:** accept "store and bundle cards are always the lowest tier with no trait, but get premium frames"? Or should store cards be unusable in the mode?
4. **Where it lives (pitch framing):** a lobby/matchmaking mini-game, a separate menu mode, or a companion app first?
5. **Rewards:** should Banner Wall pay out **only cosmetics** (titles, frames, mode-exclusive cards; recommended), or also shooter XP or calling cards usable in the shooter?
6. **Tactical axis in the shooter:** should the pitch also include **Signature Trio** (C) as a phase-2 feature, and **Bounty** (D) as a later limited-time mode? Or keep the pitch to the side mode only?
7. **Rules:** are the 10-slot 3-4-3 wall, 5 cards each, a Clearance cap of 12 and Signatures counting double OK as starting values for playtesting?
8. **Puzzles in the demo:** include the community-style **Cipher Lock** (glyphs hidden in card art), or keep puzzles to the 5 Dossiers to save time?
9. **Audience for the output:** is this pitch for internal discussion only, or should we also prepare external pitch material (a one-page summary and a short capture video of the demo)?
10. **Load target:** accept "under 10 s with a loading screen" for the Godot web build (as in Killstreak) instead of the default "< 3 s"?

**Detailed docs:** `design/gdd.md` · `design/vision.md` · `design/mechanics/banner-wall-spec.md` · `art/style-guides/art-direction.md` · `production/prototype-scope.md` · `../resources/market-research/market-analysis.md`

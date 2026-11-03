# CallingCard: Prototype Scope and Open Questions

*Producer (performed by the Master Orchestrator in role) · 2026-11-03 · Phase: Design*

> **Update 2026-11-03 (head's decisions, see `../DESIGN_REVIEW.md`):** approved. Additions: both entry points (a *Lobby Duel* during a simulated matchmaking wait, plus the full menu mode); rewards are cosmetic only; Cipher Lock stays in; load target under 10 s with a loading screen; internal audience only. Signature Trio, Bounty, the one-page summary and the demo video are backlog. The detailed plan that supersedes sections 3 and 7 is `prototype-milestone-plan.md`.

> **What this prototype is:** a **standalone concept demo** of the "Banner Wall" idea. It uses original cards, names and placeholder art. It is **not** a mod, a fan recreation, or a use of any Call of Duty assets. Its job is to let the studio head (and possibly a pitch audience) *feel* how calling cards gain value.

## 1. Market review check
Market analysis: **GO** for the pitch and a small web demo (`resources/market-research/market-analysis.md`). The market-driven requirements are an anti-pay-to-win rule that is **visible in the demo**, short sessions, and a collection chase that can be measured.

## 2. Prototype goal (one question)
**"Does making hard-earned cards stronger pieces in a side mode make players want to collect them?"**
The success metrics are in `design/vision.md` §8 (intent-to-collect at least 70%, album pull at least 50%, median duel under 4 min, fairness at least 70%).

## 3. In scope (est. 5–7 working days after approval)
| # | Item | Est. days |
|---|---|---|
| 1 | Data layer: 20 cards and 4 sets plus Cipher/Showcase as `.tres` resources; tuning values in one `balance.tres` | 0.5 |
| 2 | Board: 10-slot brick wall, adjacency, capture resolution, all 6 traits plus Set Link, Signature, Triptych scoring | 1.5 |
| 3 | Duel flow: coin flip, turns, capture preview, end screen, "Carded!" moment | 1 |
| 4 | Lineup builder with Clearance cap, Legend limit and Signature pick | 0.5 |
| 5 | AI: Quartermaster / Archivist / Warden (random, greedy, 2-ply) | 0.75 |
| 6 | Album: set pages, silhouettes with unlock goals, Triptych hints, Cipher Lock; local save | 1 |
| 7 | 5 Dossier puzzles | 0.5 |
| 8 | Placeholder art: procedural duotone cards, frames, icons | 0.5 |
| 9 | In-demo survey link plus local telemetry log (duel length, album opens, lineup choices), exportable as JSON | 0.25 |
| 10 | Godot 4.4.1 web export (GL Compatibility, single-threaded), private link | 0.25 |
| 11 | Two entry points: Banner Wall menu hub and Lobby Duel (simulated matchmaking wait, save and resume) | 0.75 |
| | **Total** | **~7.5 days** of build work (single-builder view; the milestone plan's ≈ 15.75 agent-days also counts tests, QA, art, game feel and the playtest, run in parallel over 7 working days) |

## 4. Out of scope
PvP (live or async), any shooter gameplay, accounts, store or monetization, a real stat formula over real CoD cards, more than 20 cards, painted art, audio beyond placeholder stings, concepts C/D/E (Signature Trio and Bounty are in the backlog; Contracts is out), external pitch material (one-page summary, demo video: backlog), and localization.

## 5. Technical notes
- Godot 4.4.1, GDScript, GL Compatibility renderer, single-threaded web export (no SharedArrayBuffer headers needed).
- Scenes: `Main.tscn`, `Album.tscn`, `LineupBuilder.tscn`, `Duel.tscn`, `Dossier.tscn`. Autoloads: `Collection` (owned cards, unlocks, save) and `Telemetry`.
- Rules live in a pure-logic `wall_rules.gd`, separate from UI, so they can be unit-tested headlessly. This is required because trait interactions are the main bug risk.
- Input: mouse and touch, landscape, scaling down to phone size. No hover-only information.
- Load target: under 10 s with a loading screen (studio precedent).

## 6. Risks
| Risk | Mitigation |
|---|---|
| Trait interactions buggy or unclear | Pure-logic rules module plus unit tests for every edge case in spec §10; capture preview |
| Duel is "solved" (first-player or corner dominance) | Balance flags in `balance.tres`; quick AI-vs-AI simulation of 1,000 games to check win rates (target: first player 45–55%) |
| "Too much like an existing card minigame" | Brick topology, 3-value banners and origin traits; acknowledge the genre openly in the pitch |
| Demo misread as an official product | Title-screen disclaimer: "Unofficial concept demo. Not affiliated with Activision or Call of Duty." Original names only. |
| Scope creep (PvP, more cards) | Feature freeze at this list |

## 7. Milestones (proposed)
- **Design approval:** the head answers the DESIGN_REVIEW questions (target 2026-11-10, the Concept milestone).
- **Day 1–3:** rules, data, duel vs AI (playable greybox).
- **Day 4–5:** lineup, album, Dossiers, placeholder art.
- **Day 6–7:** web build, QA pass, 5 or more playtesters, report.

## 8. Open questions for the head
Closed on 2026-11-03. See the Decisions table in `documentation/DESIGN_REVIEW.md`.

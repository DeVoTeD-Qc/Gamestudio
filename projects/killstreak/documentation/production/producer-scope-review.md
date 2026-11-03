# Killstreak — Producer Scope Review (Design Phase)

*Author: Producer Agent · 2026-11-03 · Inputs: market-analysis.md, vision.md, core-rules.md, art-direction.md, playtest-metrics-plan.md*

## Market integration
Market verdict: **conditional GO** for a single-player roguelite (PvP deferred). Scope is aligned: no servers, no accounts, no monetization.

## Design phase status (rapid timeline)
| Milestone | Date | Status |
|---|---|---|
| Concept Complete (concept, pillars, audience) | 2026-11-05 | ✅ Delivered early (vision.md, market-analysis.md) |
| Design Documentation (GDD, art guide, technical assessment) | 2026-11-08 | ✅ Approved by the user 2026-11-03 (DESIGN_REVIEW.md, Decisions) |

## Proposed web prototype scope (starts only after approval)
**IN (vertical slice, ~5–7 working days for one dev pipeline):**
- 1 map (Port Vasel), 2 modes (Zone Control, Firefight)
- Full round loop: Briefing / Deploy / Reveal / Firefight / Score, plus the streak meter and Operator down/respawn
- 20 starter cards + 6 reward cards; 1 Primary (Kestrel AR-7) with 4 attachments; Sidearm; Frag + Flashbang; 4 Perks; 4 Killstreaks
- AI with 2 personalities (Rusher, Anchor); 3 enemy squads
- Run: 7 matches (Bracket 1 ×3, Bracket 2 ×3, Rival), 3 tickets, ~30–45 min (decision 7), Supply Drop rewards, weapon level-ups. No Armory shop.
- Scripted tutorial match, outcome-preview overlay, killfeed, hit markers, XP pop-ups
- Playtest event log + download button; placeholder art in the final layout
- Godot 4.4.1 web export, single-threaded, Compatibility renderer, hosted on itch.io (private link)

- **Mouse + touch input and a layout that scales to phone-size landscape screens** (decision 9: Steam and mobile later)
- Loading screen; load target < 10 s (decision 10)

**OUT (post-prototype):** Detonator mode, extra Primaries, the Armory shop, meta-progression/Player Rank, Threat Levels, second map, final art, voice audio, async "Mirror Squad" PvP, portrait layout, native mobile/Steam builds and store integration.

## Rough build plan (post-approval)
| Day | Work |
|---|---|
| 1 | Data model (cards as `.tres` resources), board/zone scenes, deal/draw/supply |
| 2 | Reveal + firefight resolver (deterministic, unit-testable), scoring, modes |
| 3 | Streak meter, killstreaks, Lethal/Tactical, Operator respawn |
| 4 | AI personalities, red-dot intel, mini-run flow + rewards |
| 5 | Tutorial, feedback/juice, playtest logger, web export |
| 6–7 | Internal playtest, balance pass, fixes, share the link |

## Risks
| Risk | P | I | Mitigation |
|---|---|---|---|
| Scope creep (more modes/cards) | High | High | Feature freeze = the IN list above |
| Firefight rules are confusing | Med | High | Outcome preview + tutorial; test with the Shooter segment first |
| AI too weak or too strong | Med | Med | Tunable weights; scripted squads for bracket 1 |
| Web build size/load time | High | Low | Target approved: < 10 s with a loading screen (decision 10); keep assets < 5 MB |
| IP/trademark | Med | High | Name review checklist before any public build; trademark search on "Killstreak" and the preferred candidate "Deckstreak" |

## Decisions
All 10 questions were answered on 2026-11-03; see "Decisions (approved 2026-11-03)" in `../DESIGN_REVIEW.md`. The detailed build plan is `prototype-milestone-plan.md`.

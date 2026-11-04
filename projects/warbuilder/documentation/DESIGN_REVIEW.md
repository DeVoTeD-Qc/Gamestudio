# Warbuilder: Design Review and Improvement Plan (for approval)

*Master Orchestrator · 2026-11-04 · Phase: import → assessment · Board task `wb-review` (part of `wb-assess`) · Status: **awaiting the studio head's decisions** (board task `wb-q`)*
*Project: snapshot of DeVoTeD-Qc/wardeckbuilder at `374cc63`, in-game title "Warzone Deckbuilder". Engine exception: HTML5/vanilla JS. **The game source is unchanged** until you approve a plan.*

## Deliverables
| Deliverable | File | Board task | Role |
|---|---|---|---|
| Headless playtest and QA report (4 UI matches, 14,000+ engine matches, load timing, PnP check) | `documentation/qa/playtest-report.md` | `wb-playtest` | QA Agent |
| Design review: core loop, fun, weaknesses, rules clarity, print-and-play | `documentation/design/design-review-core.md` | `wb-design` | Sr Game Designer |
| Comparison with CardZone | `documentation/design/cardzone-comparison.md` | `wb-compare` | Sr Game Designer |
| IP and originality check, safe naming | `documentation/research/ip-originality-check.md` | `wb-ip` | Market Analyst |
| Tech review: code, build pipeline, test harness, build size | `documentation/technical/tech-review.md` | `wb-tech` | Mechanics Developer |
| AI-vs-AI simulator (harness prototype) | `qa/tools/ai_sim.js` | `wb-tech` | Mechanics Developer |
| Screenshots | `qa/screenshots/wb-assess-*.png` | `wb-playtest` | QA Agent |

## Verdict in one paragraph
Warbuilder is a **polished, playable 1v1 deckbuilder with one great idea**: you shoot by **revealing cards from your own deck and counting Hit Markers**, so building your deck *is* building your aim. The game is fair (the first player wins 50.5%), well paced (9.4 rounds, about 20 minutes), has healthy comebacks (41%), a competent AI, no crashes in 14,000+ simulated games, and no errors in 4 UI matches at phone and desktop sizes. Its problems are fixable: **(1) the name and about 20 terms borrow from a famous shooter franchise; (2) the battle royale is missing, because the gas never closes (0.6% of damage, final circle in 0% of games); (3) shots hit 83% of the time, so the big reveal rarely surprises; (4) the 4 MB build takes 4 s to load on 4G and 22 s on 3G; (5) there are no tests, and the build has a manual step.** None of these needs a rewrite.

## Top findings
1. **Rename first.** "Warzone" is the lead word of the title in the same genre and theme as *Call of Duty: Warzone*. **All 12** (unused but shipped) loadout perk names copy that franchise's perk names exactly. "Buy Station", Heartbeat Sensor, Munitions Box, UAV, Tac Sprint and others match its terms. The art itself is clean: no logos or branding, and the guns are unnamed generic patterns. → IP check §2–§5.
2. **The gas is a conveyor, not a circle.** One location leaves and one arrives each round, so 6 locations remain at the end of a match, and the 12-card new-ground deck outlasts every match. → Design review §4.1. Port CardZone's **hard end and escalating final circle**.
3. **Low shot tension.** A competent shooter hits 83% (the AI fires only on good odds). Our naive bot hit 46%, and the main FIRE button doesn't show the odds. → Design review §4.2, playtest B10.
4. **Combos don't change decisions.** An AI that ignores combos when buying wins exactly as often. Close-range guns win only 32–44% of matches. → Playtest §4.
5. **The build is 4.09 MB, and 83% of it is base64 art.** Re-encoding the card art saves about 2 MB (measured), and minifying saves more. Target: about 1.2–1.5 MB and under 2 s on 4G. → Tech review §5.
6. **Pipeline and code health.** `build.py` output lacks the doctype and viewport (they were added by hand to the shipped file). `faces.json` must be generated first. `topdf.py` has hard-coded paths. There are 74 `TUNE` switches with many dead rule modes, a stale 1,786-line `index_v21.html`, and no tests. The good news: the engine is pure, seeded and already runs in Node. → Tech review §1–§4.
7. **Misleading in-game text.** Phase changes announce a gas speed-up and a perk draft that don't happen. Tier-1 loot is labelled "Uncommon" next to "Common" guns. → Playtest B1, B5.
8. **Portfolio overlap with CardZone.** It's the same pitch ("BR deckbuilder, 10-card start, gas, paper and web"). Position them apart on purpose: **Warbuilder = the luck-and-nerve 1v1 duel; CardZone = the deterministic 2–4 player tactics game.** → Comparison §2.

## Improvement plan (prioritised)

### Quick wins (about 1 week, small risk, mostly no rules change)
| # | Item | Owner | Done when |
|---|---|---|---|
| Q1 | **Rename**: title (per decision D1) in the UI, `<title>`, PnP header, footer and PDF name, and README. Rename the flagged terms (Buy Station → Quartermaster, Heartbeat Sensor → Pulse Scanner, Munitions Box → Ordnance Crate, UAV → Eye in the Sky, Tac Sprint → Hustle, Slide Cancel → Slide In, Deployable Cover → Pop-up Barrier, Overwatch → High Ground, "Judge" → Verdict). **Delete the perk system.** | Market Analyst + Mechanics Dev | `grep -i warzone` and the list in IP §3 return nothing player-facing |
| Q2 | **Test harness** layers 1–3 and 6 (`node:test`) + `ai_sim.js` as the balance report; `npm test` in the project | Mechanics Dev + QA | Tests green on the current rules |
| Q3 | **One-command build** in Node (`shell.html` with the doctype and viewport; retire `index_v21.html` and `build.py`; relative paths for the PDF) | Mechanics Dev | `npm run build` reproduces the shipped file with no hand step |
| Q4 | **Art re-encode + minify** | Technical Artist + Mechanics Dev | Build ≤ 1.5 MB, load < 2 s on 4G, art checked in light and dark |
| Q5 | **Text fixes**: phase log (B1), one rarity word for tier-1 (B5), odds % on the main FIRE button (B10) | UI/UX + Mechanics Dev | Verified in a UI smoke run |
| Q6 | **Layout polish**: upright, readable gun cards on loot stacks (phone), no truncated location names, use the empty band on desktop (B8, B9) | UI/UX | Screenshots at 844 × 390 and 1440 × 900 |

### Medium (2–4 weeks, rules changes, each with a balance report before and after)
| # | Item | Target |
|---|---|---|
| M1 | **Real closing circle**: fewer new-ground cards, the gas closing from both ends in the late game, escalating final-circle damage and a **hard end** (e.g. round 12: most health wins) | Final circle in ≥ 50% of matches · gas 10–20% of damage · no match past round 13 |
| M2 | **Shot odds**: first ladder step +1, or fewer Hit Markers on cheap cards; make the big hit reachable | Typical first shot 60–70% · big hits 30–40% of hits |
| M3 | **Close-range guns**: distance-0 shots ignore cover and Armor, or +1 shot | Every gun class wins 42–58% |
| M4 | **Combos: deepen or delete** (decision D5) | If kept: a combo-aware AI wins ≥ 55% against a combo-blind one |
| M5 | **Freeze the ruleset**: a written rules doc as the single source of truth; delete the dead `TUNE` modes; readable code with lint | ≤ 20 live switches, tests green |
| M6 | **AI difficulty** (Easy / Normal / Hard) from existing knobs (`aiFireMin`, scoring weights) | A new player can win on Easy |
| M7 | **Print-and-play**: player mat for resources, a fixed map that closes from both ends, loot pre-packed by phase, two-page rules | Setup ≤ 5 min in a paper test |
| M8 | **Save/resume and shareable seeds** (`localStorage`, seed field) | Reload mid-match keeps the game |

### Big bets (pick at most one after the medium items)
| # | Bet | Why | Cost |
|---|---|---|---|
| X1 | **Drop draft + richer map** (choose where to land; a map that isn't one row) | Brings back the battle-royale opening | Medium–high: map and AI changes |
| X2 | **3–4 players** (hotseat first) | Battle royale with more than two people. But it collides with CardZone's lane (decision D7). | High: engine, AI, UI |
| X3 | **Online async 1v1** (shared state; the engine is already JSON and deterministic) | Play with friends without sitting together | High |
| X4 | **Solo challenge mode** (daily seed, score attack vs AI) | Replay value; easy with seeded games | Medium |

## Decisions for the head (short questions; also on the board as task `wb-q`)
1. **D1. Title:** drop "Warzone" now? **Warbuilder** as the working title (recommended), **Last Circle**, **Hot Drop**, or keep it (not recommended)?
2. **D2. Borrowed names:** rename the flagged cards and the Buy Station, and **delete the unused perk set** (recommended)? Or rename only the perks?
3. **D3. Art rights:** how was the card and gun art made (AI tool, artist, stock), and do we have commercial rights? (We'll record it. No change needed if the rights are clear.)
4. **D4. Gas:** make the circle really close, with a hard end (recommended)? Or keep today's conveyor?
5. **D5. Combos:** deepen them so they drive drafting, or remove them to simplify the cards (recommended: test both in the sim, then decide)?
6. **D6. Shot odds:** lower the typical hit chance to about 60–70% (recommended), or keep about 80%?
7. **D7. Positioning vs CardZone:** keep both, with Warbuilder as the 1v1 luck duel and CardZone as the deterministic 2–4 player game (recommended)? Or merge ideas, or pause one?
8. **D8. Build format:** must the game stay a **single HTML file** (artifact + itch), or may we ship a zip with separate images for a faster first load?
9. **D9. Source of truth:** keep developing here and copy builds to `wardeckbuilder` for itch releases (recommended)? Or move the source back to `wardeckbuilder`?
10. **D10. First step:** start with the **quick-wins sprint (Q1–Q6)**, before any rules change (recommended)?

## After approval
The Producer turns the approved items into board tasks. Order: Q2 → Q3 → Q1 → Q4 → Q5/Q6. Then M1 and M2, each with a sim balance report (before and after) and a UI smoke run. Each change gets a fresh playable artifact build for the head to try.

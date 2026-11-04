# Warbuilder: Headless Playtest and QA Report

*QA Agent (run by the Master Orchestrator) · 2026-11-04 · Board task `wb-playtest` (part of `wb-assess`)*
*Build tested: `source/project-warbuilder/build/index.html` (snapshot of DeVoTeD-Qc/wardeckbuilder at `374cc63`, 4,090,739 bytes). Nothing in the game source was changed.*

## 1. What we ran

| Run | How | Size |
|---|---|---|
| UI matches vs the AI | Headless Chromium (Playwright). A scripted player clicked the real buttons: Play all, buy the top of its stack, Fire while possible, Move toward the rival, Buy Station, End turn. | 4 full matches: 2 at phone landscape (844 × 390, touch, 2×), 2 at desktop (1440 × 900) |
| Engine matches, AI vs AI | Node running `engine.js` directly (it already exports a CommonJS API) | 14,000+ matches across a baseline and 7 strategy variants. No crash, no stuck game. |
| Load and render timing | Chromium with CDP network throttling, served over local HTTP | Unthrottled, 4G (9 Mbps, 85 ms) and Fast 3G (1.6 Mbps, 150 ms) |
| Print-and-play | Ran `pnp/gen.js` in a scratch copy and rendered `pnp.html` to PDF | 27 Letter pages, 16 MB PDF |

The engine simulator is saved as `projects/warbuilder/qa/tools/ai_sim.js` (`node projects/warbuilder/qa/tools/ai_sim.js 2000`). It also checks that every card instance is in exactly one place and that no resource goes negative. It found no failures in 1,000 seeded games.

Screenshots are in `projects/warbuilder/qa/screenshots/` (`wb-assess-*.png`).

## 2. UI matches (phone and desktop)

| Match | Size | Rounds | Real time | Our player | Rival AI | Result |
|---|---|---|---|---|---|---|
| 1 | Phone | 10 | 81 s | 9/17 hits, 27 damage | 15/16 hits, 29 damage | AI wins |
| 2 | Phone | 13 | 83 s | 7/14 hits, 11 damage | 12/15 hits, 30 damage | AI wins |
| 3 | Desktop | 14 | 103 s | 4/18 hits, 13 damage | 13/13 hits, 30 damage | AI wins |
| 4 | Desktop | 12 | 93 s | 9/14 hits, 20 damage | 8/10 hits, 36 damage | AI wins |

*Real time includes skipping the rival's animations. A human match is closer to 15–20 minutes, which fits the "~20 min" on the title screen.*

- **No JavaScript errors** and no console errors in any match, at either size.
- **No page scroll** at 844 × 390 or 1440 × 900. The layout fits the screen as designed.
- **The AI is competent.** It won 4 of 4 against a naive "fire whenever you can" player. It hit 48 of its 54 shots (89%) because it only fires when the odds are good. Our bot hit 29 of 63 (46%). Knowing *when* to fire is the main skill, and the AI has it.

## 3. Bugs and defects

| # | Severity | Where | What happens | Evidence |
|---|---|---|---|---|
| B1 | Medium (misleading text) | `engine.js` line 738 | At each phase change the log says "**the gas speeds up to 1 location per round. Both operators draft a new perk.**" The gas rate is 1 in every phase (`phaseGas: [1, 1, 1]`), so it never speeds up. Perks are switched off (`TUNE.perks: false`), so nobody drafts anything. | Seed 7 log, rounds 4 and 8 |
| B2 | High (design, see the design review) | Gas / circle | **The circle never shrinks in practice.** At the end of a match there are still **6.0 safe locations** on average and **3.6 new-ground cards** left. The final circle was reached in **0 of 2,000** games. Gas causes **0.6%** of all damage, and only **8.6%** of games have any gas damage at all. The rules screen and the print-and-play describe a final circle that never happens. | `ai_sim.js`, 1,000–2,000 games |
| B3 | Low | `engine.js` lines 187–219 | The code supports "hot" centre start locations (`centre`, `hotBonus`), but no Start location in `LOCSET` is marked `centre`. That code path never runs. | Code read |
| B4 | Low (code health) | `engine.js` line 9 and line 245 | `TUNE` declares `perks` twice, and `burnScore` declares `T005` twice (4, then 6). JavaScript silently keeps the last value. The header says "7 locations", but there are 6. A comment says "v7 LITE: no combos", but combos are on. | Code read |
| B5 | Medium (confusing) | Loot stacks vs guns | Two rarity vocabularies. Location stacks of tier-1 loot say **"Uncommon"**, but the Start guns in them are **"Common"**. Tactical cards use chevrons (› ›› ›››), while guns use colours (grey to gold). | `wb-assess-phone-02-turn1.png` |
| B6 | Medium (pipeline) | `build.py` | `build.py` does not produce the shipped file. The shipped `build/index.html` has a `<!doctype html>`, a viewport meta tag, a dark background style and `</head><body>` added by hand. `build.py`'s own output has **no doctype** (quirks mode) and **no viewport tag** (wrong scaling on phones). It also needs `pnp/faces.json`, which is not in the repo. Generating it takes `ASSETS=1 node pnp/gen.js` and then `python3 pnp/faces_export.py`. Apart from the wrapper, the rebuilt file is byte-identical to the shipped one. | Rebuilt in a scratch copy |
| B7 | Low (pipeline) | `pnp/topdf.py` | It uses hard-coded paths (`/home/claude/wzdb6/...`) and needs Python Playwright. It does not run from this repo. | Code read |
| B8 | Low (UX) | Board, phone | The guns shown face up on loot stacks are drawn **sideways** (rotated 90°). Their stats are unreadable at phone size. Location names are cut off ("Supply De…", "Concrete …"). | `wb-assess-phone-02-turn1.png`, `wb-assess-phone-07-midgame.png` |
| B9 | Low (UX) | Board, desktop | At 1440 × 900 the location row sits in the middle, with a wide empty band above it. The hand and gun panel are pushed to the bottom edge. | `wb-assess-desktop-03-played.png` |
| B10 | Low (UX) | Fire button | The main FIRE button says only "long shot" or nothing. The exact hit % appears in the fire report, and on some layouts in a tray button. New players fire at bad odds, as our bot did (46% hits against the AI's 89%). | `wb-assess-desktop-03-played.png` |
| B11 | Low (dead weight) | Build | The 12 perk card faces (`perk_*`) and about 40 perk UI references ship in the build, but perks are switched off. | `grep perk_ build/index.html` |

## 4. Balance and pacing (engine, AI vs AI)

Baseline: 2,000 seeded games, both players run by the built-in AI.

| Metric | Value | Read |
|---|---|---|
| First-player win rate | 50.5% | Fair. The alternating lead (`alternateFirst`) works. |
| Seat (player 0 vs 1) | 47.6–48.2% for player 1 | Fair (within noise). |
| Match length | 9.4 rounds on average (≈ 18 turns). 90% end between rounds 7 and 12. | Good length for a 20-minute duel. |
| Hit rate per shot | **83%** | High. When the AI fires, it almost always hits. A miss is rare, and that lowers the tension of a shot. |
| Big hits (second ladder step) | 23% of hits | Fine. |
| Damage per match | 47 (both players), winner ends on 14.7 / 30 health | — |
| Comebacks | **41%** of matches with a health leader at round 5 were won by the player behind | Healthy. No runaway leader. |
| Gas share of damage | **0.6%** | The gas is not a threat (see B2). |
| Cards bought per player | 7.8, plus 2.2 guns, 1.9 cards scrapped | — |

**Strategy tests** (player 1 forced into a strategy; 1,500 games each):

| Player 1 strategy | Player 1 win rate |
|---|---|
| Normal AI (baseline) | 47.6% |
| Never buys tactical cards (guns and Buy Station only) | **0.6%** |
| Buys cards of one role only (whichever comes first) | 23.3% |
| Assault only / Recon only / Support only / Engineer only | 14.9% / 24.1% / 18.3% / 25.7% |
| Ignores combos when choosing what to buy | **47.5%** (no difference) |

- **Deckbuilding matters a lot.** A player who doesn't build loses almost every game. Mixing roles beats any single role.
- **Combo-aware buying adds nothing.** An AI that ignores combo boxes when buying does as well as one that chases them. The combo boxes fire anyway (about 3 per player per match) because a mixed deck triggers them by accident. They are bonus text, not a strategy.

**Gun held at the end of the match** (win rate; this is correlation, not cause):

| Gun | Win % | Gun | Win % |
|---|---|---|---|
| Longbow (sniper) | 58–64 | Breacher (shotgun) | 43–44 |
| Raider (burst) | 57–59 | Viper (SMG) | 38–44 |
| Sapper (launcher) | 53–58 | Combat Knife | **32–38** |
| Bastion (LMG) / Magnum / Sentinel / Ranger | 48–58 | Sidearm (never upgraded) | 45–52 |

Close-range guns (knife, SMG, shotgun) win noticeably less. Long-range guns can fire from more of the row, and a range-0 gun needs both players on one tile.

## 5. Performance and load

| Condition | Page loaded | Start button ready |
|---|---|---|
| Local file, no network | 0.6–0.9 s | 0.8 s |
| 4G (9 Mbps, 85 ms) | **4.2 s** | 4.2 s |
| Fast 3G (1.6 Mbps, 150 ms) | **21.9 s** | 21.9 s |

- **The project target is under 3 s** (`project-config.json`). The 4 MB single file misses it on 4G and is far off on slower mobile networks. Gzip only gets it to 2.7 MB, because most of the file is already-compressed images in base64.
- **Size breakdown:** card art 2.88 MB (40 base64 WebP images), gun art 0.34 MB, location art 0.19 MB, card-face HTML 0.22 MB, and code and styles (engine, UI, CSS, icons) about 0.45 MB. **83% of the file is images.**
- **Runtime is fine:** 624 DOM nodes in a match, an 11 MB JS heap, and 22 ms for a full re-render on desktop Chromium. A full re-render is above one 60 fps frame (16 ms), so expect some jank on low-end phones during animations. We didn't see it at desktop speed.
- The page also loads three Google Fonts families (plus Inter) from fonts.googleapis.com. Offline, or on a blocked network, the game falls back to system fonts.

## 6. Print-and-play check
- `gen.js` runs cleanly from the live engine data: **151 cards on 14 card pages, plus guns, 18 locations, backs and references: 27 Letter pages.**
- The rules page is one dense page (see `wb-assess-pnp-01-rules.png`). It matches the digital rules, including the final-circle text that the game never reaches (B2).
- The PDF step (`topdf.py`) can't run here as written (B7). We made the PDF with Node Playwright instead.

## 7. Recommended QA follow-ups
1. Turn `ai_sim.js` into the rules test harness described in `documentation/technical/tech-review.md`, and run it on every change.
2. Fix B1 and B11 with the quick wins. Fix B2 with the gas redesign (design review §4).
3. Add a Playwright smoke test: load the build, play one match with skip, and fail on any console error. The build already exposes `window.WZ` (`G`, `ui`, `render`) for this.
4. Re-measure load time after the art is compressed. The goal is under 3 s on 4G.

# Warbuilder: Tech Review (Code, Build Pipeline, Tests, Build Size)

*Mechanics Developer (run by the Master Orchestrator) · 2026-11-04 · Board task `wb-tech` (part of `wb-assess`)*
*Engine exception: HTML5 / vanilla JavaScript (ES2020), not Godot (see `project-config.json`). No game source was changed for this review.*

## 1. Code structure
| File | Lines | Role | Notes |
|---|---|---|---|
| `src/engine.js` | 917 | Rules, data tables, seeded RNG, AI | Pure functions over a plain state object, exported as CommonJS **and** as `window.WD`. It runs in Node unchanged. |
| `src/ui.js` | 1,179 | Rendering, input, animations, AI-turn replay | String templates → `innerHTML`, a single delegated click handler on `data-act`, and a `window.WZ` hook (`G`, `ui`, `render`). |
| `src/style.css` | 2,355 | Layout (iPad-landscape console, phone fallback), light/dark theme | Uses CSS variables. Rarity and role colours are defined here. |
| `src/index_v21.html` | 1,786 | **Only its `<head>` is used** by `build.py` | The other ~1,700 lines are a stale v2.1 engine and UI inline. They're dead and confusing. |
| `src/symbols.html` | 25 | SVG icon sprite | — |
| `src/build.py` | 34 | Inlines CSS, sprite, art (base64), faces, engine and UI into one HTML file | See §3 |
| `src/pnp/gen.js` | 442 | Builds `pnp.html` (print-and-play) from the live engine data. `ASSETS=1` also writes `assets.html` (card faces for the web build). | Strong idea: paper and web share one data source |
| `src/pnp/faces_export.py` | 21 | `assets.html` → `faces.json` (scoped CSS, sprite and one HTML string per face) | — |
| `src/pnp/topdf.py` | 10 | `pnp.html` → PDF via Python Playwright | Hard-coded `/home/claude/wzdb6/...` paths |

**Strengths**
- **The engine is separated from the UI and is deterministic.** It uses a seeded mulberry32 RNG (`s.seed`), every action is `fn(state, player, …) → {ok, err}`, and the state is JSON-serialisable. This makes headless tests, replays and save/load easy. The UI already uses that for the AI turn: it runs `aiTurn` on the real state, records a state snapshot per log line (`s._rec`), and replays them as animation frames.
- **The AI lives in the engine**, so balance simulation needs no browser: about 4 ms per full match in Node.
- **Single-file output** works as an itch.io HTML5 upload and as a Claude artifact, with no server.

**Weaknesses**
- **74 `TUNE` switches**, with 134 `TUNE.` reads in the engine. Many select whole rule variants that are off (`ammo`, `slots`, `squad`, `allies`, `mastery`, `perks`, `punch`, `multiMove`, `distMode` ×5, `fuelBurns`, `bankIntel`, crate search, workbench burning …). Dead branches are untested, and they make the live rules hard to read. Two duplicate object keys (`TUNE.perks`, `burnScore.T005`) are silently accepted.
- **Very long lines.** 33 lines in `engine.js` and 93 in `ui.js` are over 300 characters, many of them whole functions on one line. Code review and diffs are hard, and `git blame` is useless.
- **No lint, no formatter, no tests, no `package.json`.**
- **Full re-render** of the screen on each change: 22 ms on desktop Chromium. That's OK, but it will be slower on low-end phones.
- **Magic numbers in the AI** (scores like `40 + cost`, `14 + cost*3`, `-9`, `*1.5`) with no notes. Tuning the AI is guesswork without the sim.

## 2. Determinism and save state
- `newGame({seed})` is reproducible, but the UI always seeds from `Date.now()`, so a player can't replay or share a seed. A "seed" field (or a daily seed) costs very little.
- The UI keeps no saved match. Because the state is JSON, `localStorage` save/resume (wrapped in try/catch) is a small change.

## 3. Build pipeline (as found)
Today, rebuilding the shipped file takes these steps:
```
cd src/pnp && ASSETS=1 node gen.js        # writes pnp.html and assets.html
python3 faces_export.py                    # writes faces.json
cd .. && python3 build.py                  # writes src/index.html
# then, by hand: add <!doctype html>, viewport and theme-color meta, a background style, </head><body> and </body></html>
cp index.html ../build/index.html
```
- We ran this in a scratch copy. **Apart from the hand-added wrapper, the output is byte-identical to the shipped `build/index.html`.** So the source matches the build, which is good news.
- **Gaps:** the manual wrapper step isn't written down anywhere. Without it the file renders in quirks mode with no mobile viewport. `faces.json` and `assets.html` are generated but are neither committed nor ignored. Two languages (Node and Python) and Python Playwright are needed for the PDF. `topdf.py` has hard-coded paths. `index_v21.html` serves only as a head template.
- **Release:** the original repo publishes to itch.io with butler when `build/index.html` changes (`.github-original/workflows/itch.yml`, kept for reference). In the studio repo, a release means copying the build back to `wardeckbuilder`.

**Proposed pipeline** (one command, no hand steps):
```
projects/warbuilder/source/project-warbuilder/
  package.json        "scripts": { "build": "node tools/build.mjs", "pnp": "node tools/pnp.mjs", "test": "node --test test/" }
  src/shell.html      the real head (doctype, viewport, fonts) + body skeleton; replaces index_v21.html
  tools/build.mjs     gen faces in memory → inline → minify → write build/index.html (port of build.py + faces_export.py)
  tools/pnp.mjs       gen.js → pnp.html → PDF with Node Playwright (relative paths)
```
Everything is in Node, with no Python step and no generated files in `src/`. The print-and-play generator keeps working (the project's development rule).

## 4. Proposed rules test harness
A prototype is already in the repo: `projects/warbuilder/qa/tools/ai_sim.js` runs N seeded AI-vs-AI matches in Node. It checks card conservation and non-negative resources, and reports balance numbers. Proposed structure, using **Node's built-in `node:test`** (no dependencies):

| Layer | What | Example checks | Runtime |
|---|---|---|---|
| 1. Rule unit tests | A small `scenario()` helper: `newGame({seed})`, then set hands, positions, guns and resources directly on the state, call one action, and assert on the result | A shot reveals exactly Precision cards. Hit Markers vs ladder steps. Cover −1 except at distance 0. Armor, then Reaction, then minimum 1 damage. Recoil lowers Precision. Band range refusal. Move cost and one move per turn. Buying next door costs +1. Cycle costs 1 Intel or 1 Move. Scrap stops at 6 cards. Dig-in is capped at 2. Draw 6 at ≤ 10 health. Gas damage 3 + depth − 1, then pushed back. Final circle escalation. | < 1 s |
| 2. Invariants (property tests) | 500–2,000 seeded AI matches | No exceptions. Every match ends. Every card instance is in exactly one zone. No negative resources. Health only changes through hits, gas or the final circle. Loot decks never duplicate an item. | 2–8 s |
| 3. Golden replays | A seed plus a list of actions → a hash of the final state, stored in `test/golden/` | Catches any unintended rules change. Regenerate on purpose with `UPDATE_GOLDEN=1`. | < 1 s |
| 4. Balance report (non-blocking) | `ai_sim.js` output compared with bands | First-player win rate 45–55%. Average rounds 8–12. Hit rate. Gas share of damage. Win rate per gun 40–60%. Prints a warning, doesn't fail. | 5–10 s |
| 5. UI smoke (Playwright) | Load `build/index.html` at 844 × 390 and 1440 × 900, play one match via `window.WZ` and the buttons | No console errors. No horizontal scroll. Game over is reached. | 60–120 s, run on demand |
| 6. PnP consistency | Run `gen.js`, then compare its component counts with the engine data (151 cards, 30 guns, 18 locations) | The paper and web builds can't drift | < 2 s |

Layers 1–4 and 6 go into `npm test` for the project. If the studio's root `npm test` should cover imported projects, it can call `npm --prefix projects/warbuilder/source/project-warbuilder test` (to agree with the head; the root currently tests the studio itself). **Write the tests before the TUNE cleanup**, so that deleting dead modes is provably safe.

## 5. Making the build smaller
Current file: **4,090,739 bytes** (2.70 MB gzipped). 83% of it is base64 images.

| Step | Saving (measured or estimated) | Effort | Notes |
|---|---|---|---|
| **Re-encode card art**: flatten the alpha onto the card's background colour (or use lossy alpha), cap at 400 px wide, WebP q50 | **Measured: 2.16 MB → 0.66 MB** binary (−69%). In base64, about **−2.0 MB** on the file | Small | The art is shown at about 150–300 px. Its RGBA lossless alpha is most of the weight. Check visually on both themes. |
| Same for guns and locations | −0.15 to −0.25 MB (est.) | Small | Already small (8–13 KB each) |
| Drop dead weight: the 12 perk faces, the stale engine comments, unused UI branches | −0.05 to −0.1 MB (est.) | Small | Comes with the TUNE cleanup |
| Minify JS and CSS (esbuild or terser) | ~−0.2 MB of the ~0.45 MB code and styles (est.) | Small | Keep the source readable. Minify only in `build`. |
| Self-host fonts as WOFF2 subsets, or use system fonts | Removes 4 external requests and the dependency on fonts.googleapis.com | Small–Medium | Offline and blocked networks get the right look |
| **Optional:** ship images as separate files (zip upload on itch) and lazy-load the card art | The first screen loads in < 1 MB, and the art streams in | Medium | Breaks the single-file artifact; needs the head's decision |

**Expected result with the small steps only:** about **1.2–1.5 MB** single file. That's roughly **1.5–2 s on 4G** (now 4.2 s) and **6–8 s on Fast 3G** (now 21.9 s). These are estimates; we'll re-measure with the playtest script after the change.

## 6. Recommended tech order
1. Write down the live ruleset, then add the harness (layers 1–3 and 6), with `ai_sim.js` as layer 4.
2. One-command build in Node, with the wrapper in `shell.html`. Retire `index_v21.html` and `build.py`.
3. Art re-encode and minify (−2.5 MB).
4. Delete the dead `TUNE` modes and the perk system, break the 300-character lines into readable functions, and add ESLint and Prettier. Do all of this with the tests green.
5. Then rules changes (gas, odds, guns), each with a balance report before and after.

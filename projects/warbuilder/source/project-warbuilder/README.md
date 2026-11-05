# Warzone Deckbuilder (working title)

- `build/index.html` — the playable HTML5 game. Pushing a change to this file uploads it to itch.io automatically.
- `src/` — rules engine, UI, styles, art and the print-and-play generator used to make the build.
- `tools/` — build, print-and-play and balance-report scripts (Node only, no dependencies). `test/` — the rules test harness.
- `.github/workflows/itch.yml` — the upload job (uses itch.io's official `butler` tool).

## Commands (Node 20+, run in this folder)
| Command | What it does |
|---|---|
| `npm run build` | Writes `build/index.html`: `src/shell.html` with the CSS, icon sprite, engine, UI, art (base64) and card faces inlined. |
| `npm test` | Rules unit tests, seeded determinism + golden replays, full-match invariants, AI-vs-AI smoke, print-and-play consistency, build smoke (`node:test`). `WB_MATCHES=2000 npm test` for more invariant matches. |
| `npm run test:update-golden` | Re-records `test/golden/replays.json` after an intended rules or AI change. |
| `npm run sim` | Balance report: `qa/tools/ai_sim.js` (2000 AI matches) against the target bands. Warns, never fails. `npm run sim -- 500 recon` passes arguments through. |
| `npm run pnp` / `npm run pnp:pdf` | Print-and-play sheet `src/pnp/pnp.html`, and the PDF next to it (needs Playwright and Chromium, found in this project or the global npm root). |

## Setup (once)
1. Settings → Secrets and variables → Actions → **Secrets**: `BUTLER_API_KEY` = your itch.io API key (itch.io → Settings → API keys → Generate new API key).
2. Same page → **Variables**: `ITCH_USER` = your itch.io username, `ITCH_GAME` = your game's URL slug (the part after `itch.io/` in the game page address).
3. Actions tab → "Publish to itch.io" → Run workflow, to test.

The first push creates an `html5` channel on itch.io. On the game's edit page, tick "This file will be played in the browser" for it once.

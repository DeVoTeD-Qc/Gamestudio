# BUG p18-002: The web load-time check never finishes on a first launch

| | |
|---|---|
| Severity | **minor** (QA tooling, not player-facing) |
| Status | **FIXED** (p18, QA Agent) |
| Area | `qa/performance-logs/tools/measure.js`, `scripts/survey/consent_screen.gd` |
| Agent responsible | Technical Artist (p17 tooling) / Data Scientist (p16 consent) |
| Screenshot | none |

## Steps
1. Export the web build and serve it with `serve_gz.py`.
2. Run the p17 tool: `RUNS=1 PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node measure.js`.

## Expected
Each cold load reports the time until the first playable screen appears.

## Actual
`titleMs: null` for every run. The tool waits for the console line `Title: ready`. Since p16, Boot opens the playtest Consent screen on a first launch, and a cold load in a fresh browser profile is always a first launch, so the Title never appears and the tool times out after 60 s. The 6.0 s figure in `web-load.md` was measured before the consent screen existed.

## Fix
`consent_screen.gd` prints `Consent: ready` in `_ready()`. `measure.js` accepts either marker, reports which one it saw (`firstScreen`), and takes `URL` and `SHOTS` from the environment, so a re-measure does not overwrite the p17 screenshots. Re-measured: see `qa/test-plans/p18-report.md`.

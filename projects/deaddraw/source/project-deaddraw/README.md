# DeadDraw - Godot 4.4.1 prototype

Zombie solo card-crawl roguelite. Rules: `projects/deaddraw/documentation/design/core-rules.md`;
reference implementation and numbers: `projects/deaddraw/tools/sim_deaddraw.py` (`CONFIG`).

## Layout
- `data/balance.json` - every tunable number, mirroring the sim's `CONFIG`. To retune, paste the new
  `CONFIG` values (or the whole Python dict: `True`/`False`, `#` comments and trailing commas are
  accepted). `extra_rules` holds numbers the sim hard-codes outside `CONFIG`; missing keys fall
  back to the sim's values. `tests/test_balance.gd` fails if this file drifts from the sim.
- `scripts/rules/` - pure rules, no nodes: `dd_run.gd` (DDRun, the whole run state machine),
  `dd_card.gd`, `dd_balance.gd` (loader), `dd_text.gd` (names and rules text).
- `scripts/meta/dd_profile.gd` - meta unlocks, best scores, badges, saved to `user://deaddraw_profile.json`.
- `autoload/game.gd` (`Game`) - owns the profile and current run, records clears / run ends.
- `scripts/ui/` - `main.gd` (all screens, portrait 2x2 / landscape 1x4), `dd_card_view.gd`
  (tap, right click and long press), `dd_inspect.gd` (zoomed card), `dd_payloads.gd` (rules text
  for every inspectable thing), `dd_ui.gd` (palette and StyleBoxes).

## Commands
```bash
godot --headless --path . -s res://tests/run_tests.gd            # all tests
godot --headless --path . -s res://tests/run_tests.gd -- --only=retreat
../../tools/package_artifact_build.sh <godot> <out-dir>          # single-threaded web build for an artifact
node ../../tools/smoke_web.js http://localhost:8765/index.html <shots-dir>   # browser smoke (Playwright)
```
On the Web build, `?screen=map|street|safehouse|end&seed=N&survivor=id&select=0&inspect=deck`
jumps to a screen for QA screenshots, and `window.ddState` exposes the tappable rects.

# DeadDraw - Godot 4.4.1 prototype (v3 "Kill Stacks")

Zombie solo card-crawl roguelite. Rules: `projects/deaddraw/documentation/design/core-rules-v3.md`;
reference implementation and numbers: `projects/deaddraw/tools/sim_deaddraw_v3.py` (`CONFIG`).

## Layout
- `data/balance.json` - every tunable number, generated from the v3 sim's `CONFIG` by
  `projects/deaddraw/tools/regen_balance.py` (edit the sim, then re-run it). The loader also takes a
  pasted Python dict (`True`/`False`, tuples, `#` comments, trailing commas). `extra_rules` holds
  display-only survivor info and meta unlocks. `tests/test_balance.gd` fails if the file drifts
  from the sim.
- `scripts/rules/` - pure rules, no nodes: `dd_run.gd` (DDRun: board, waves, rooms, machines, kill
  stacks, bosses, save data), `dd_gun.gd` (a gun and its stack), `dd_card.gd`, `dd_balance.gd`
  (loader), `dd_text.gd` (names, rules text, first-run hints).
- `scripts/meta/` - `dd_profile.gd` (unlocks, best scores, badges, settings, first-run hints seen),
  `dd_run_save.gd` (mid-run save, version 4; older v2 runs are discarded with a note on the title).
- `autoload/game.gd` (`Game`) - owns the profile, the current run and the save.
- `scripts/ui/` - `main.gd` (every screen; the street: wave decks left, pile top middle, rooms right,
  street, gun cards + melee bottom; sheets; hints), `dd_gun_view.gd` (gun card with its kill stack),
  `dd_card_view.gd` (tap, right click and long press), `dd_inspect.gd` (zoom), `dd_payloads.gd`
  (tile specs and zoom text), `dd_art.gd` (art manifest with fallback), `dd_ui.gd`.
- `scripts/fx/` - `dd_feedback.gd` (kill onto stack, collect, challenge stamp, shuffle-ins, Run,
  deal), `dd_sfx.gd` + `dd_sfx_synth.gd` (sounds).

## Commands
```bash
godot --headless --path . -s res://tests/run_tests.gd            # all tests
godot --headless --path . -s res://tests/run_tests.gd -- --only=rules_guns
../../tools/package_artifact_build.sh <godot> <out-dir>          # single-threaded web build for an artifact
node ../../tools/smoke_web.js http://localhost:8765/index.html <shots-dir>   # browser smoke (Playwright)
```
On the Web build, `?screen=map|street|safehouse|end&seed=N&survivor=id` jumps to a screen for QA
screenshots (street extras: `points`, `open`, `gun1/gun2`, `stack1/stack2`, `active`, `patches`,
`district`, `boss`, `sheet=gun|machine0..2|patch`, `near`, `lastcards`, `hints`, `inspect=...`; see
`main.gd` `apply_debug()`), and `window.ddState` exposes the tappable rects.

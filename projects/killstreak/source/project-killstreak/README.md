# Killstreak (working title): Godot project

Web prototype of a tactical card roguelite. **Godot 4.4.1, GDScript only, Compatibility renderer.**
It has no GDExtensions, plugins or C#, so it runs in Godot on desktop and in Xogot (Godot for iOS).

Plan and structure: `../../documentation/production/prototype-milestone-plan.md` (§5 layout, §6 web settings).

## Open the project
- **Desktop Godot 4.4.1:** Project Manager → Import → select this folder's `project.godot`.
- **Xogot (iPhone/iPad):** copy or sync this folder (`project-killstreak/`) into Xogot's projects
  location, for example through the Files app or iCloud Drive, then open it in Xogot. Play in landscape.
- Main scene: `res://scenes/Boot.tscn`. It shows "Loading..." and routes to `Title.tscn` through `SceneRouter`.

## Layout
```
project.godot        Compatibility renderer, 1280x720 base, canvas_items / expand, input actions
export_presets.cfg   "Web" preset (single-threaded, VRAM compression desktop + mobile)
autoload/            EventBus, Settings, CardDB, RunState, PlaytestLog, SceneRouter
scripts/data|rules|ai|ui/
scenes/  scenes/match/
data/cards|loadout|squads/
assets/fonts|ui|sprites|audio/
tests/               run_tests.gd (runner), test_case.gd (asserts), test_*.gd
```
Autoload order matters: EventBus loads first so every other singleton can connect to it in `_ready()`.

## Input actions
`confirm` (Enter, Space), `cancel` (Esc, right mouse), `inspect` (I), `end_turn` (R),
`toggle_preview` (P) and `fast_forward` (F). Touch works through "emulate mouse from touch" (on).
Gameplay code handles taps, drags and long-press (400 ms) itself, and nothing is hover-only.

## Run the tests (headless)
```bash
cd projects/killstreak/source/project-killstreak
godot --headless --path . --import                   # first time / after adding assets
godot --headless --path . -s res://tests/run_tests.gd
```
The runner finds `tests/test_*.gd`, runs every `test_*` method, prints `PASS`/`FAIL` per test and a
summary, and exits with code 1 on any failure. Autoloads are live during tests (`tree.root.get_node("EventBus")`).
New test files use `extends "res://tests/test_case.gd"`. Every test method must make at least one
assertion, because a method that records none is treated as failed (that is how script errors are caught).

## Export for web
Needs the Godot 4.4.1 export templates (Editor → Manage Export Templates, or files in
`~/.local/share/godot/export_templates/4.4.1.stable/`).
```bash
godot --headless --path . --export-release Web ../../builds/web/index.html
```
The output goes to `projects/killstreak/builds/web/`, which git ignores. The build is single-threaded,
so it needs no cross-origin isolation headers and works on itch.io and iOS Safari. `tests/` is
excluded from the export. To try it locally, serve the folder over HTTP
(`python3 -m http.server -d ../../builds/web 8000`), because opening `index.html` as a file does not work.
For itch.io, zip the contents of `builds/web/` with `index.html` at the zip root.

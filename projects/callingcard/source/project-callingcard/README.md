# CallingCard: "Banner Wall" concept demo (Godot project)

Web prototype of Banner Wall, a card duel where calling cards are the pieces.
**Godot 4.4.1, GDScript only, Compatibility renderer.** No GDExtensions, plugins or C#.
Unofficial concept demo, not affiliated with Activision or Call of Duty. Original names and placeholder art only.

Plan and structure: `../../documentation/production/prototype-milestone-plan.md` (section 6 layout, section 7 web and phone rules).
Infrastructure adapted from Killstreak (`projects/killstreak/source/project-killstreak/`). Each copied file says so in its header.

## Open the project
Desktop Godot 4.4.1: Project Manager → Import → this folder's `project.godot`.
Main scene: `res://scenes/Boot.tscn` ("Loading...") routes to `Title.tscn` through `SceneRouter`.

## Layout
```
project.godot        Compatibility, 1280x720 base, canvas_items / expand, input (confirm, cancel, inspect)
export_presets.cfg   "Web" preset (single-threaded, VRAM compression desktop + mobile, custom shell)
web/shell.html       loading screen: progress bar, error notice, rotate-to-landscape prompt, disclaimer
autoload/            EventBus, Settings, CardDB*, Collection*, PlaytestLog*, SceneRouter  (*stubs: cc02, cc09, cc16)
scripts/ui/          screen_profile.gd (phone readability), boot.gd, title.gd
scripts/data|rules|ai|art/   (cc02, cc05, cc06, cc14)
scenes/              Boot.tscn, Title.tscn (placeholder), Duel.tscn (cc07 layout on mock data); duel/, album/
data/                cards, sets, rivals, triptychs, dossiers (cc02/cc03)
tests/               run_tests.gd (runner), test_case.gd (asserts), test_*.gd
```
Autoload order matters: EventBus first (others connect to it in `_ready()`), SceneRouter last.
EventBus already declares the duel, album and Lobby Duel signals so UI can build on mock state.

## Phone readability
The `Settings` autoload applies `scripts/ui/screen_profile.gd` at startup and on every resize (unchanged from
Killstreak f01): desktop 1280x720 stays 1280x720; an 844x390 phone in landscape gets a 960x540 base
(1168x540 canvas, 0.722 pt per logical px). `Settings.is_compact()` is true below 640 logical px tall.
Rules: tap targets ≥ 64 logical px, text ≥ 16 px, key numbers ≥ 24 px, nothing hover-only.

## Run the tests (headless)
```bash
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd        # add -- --only=<substring> to filter
```
New test files use `extends "res://tests/test_case.gd"`; every `test_*` method must assert at least once.

## Export for web
```bash
godot --headless --path . --export-release Web ../../builds/web/index.html
```
Single-threaded, so no cross-origin isolation headers are needed. Serve over HTTP to try it
(`python3 -m http.server -d ../../builds/web 8000`). `tests/`, `qa/`, `web/`, `*.md` are excluded from the pck.
`scripts/ui/title.gd` prints `Title: ready` (load-time marker); the shell records `window.bwLoadTimes`.

### Package as a private claude.ai artifact
```bash
../../tools/package_artifact_build.sh <godot-binary> <out-dir>
```
It exports from a clean copy, gzips the engine to `engine.gz.wasm`, renames the pck to `game.pck.wasm` and adds a
fetch shim to `index.html`. Publish `index.html`, `index.js`, `engine.gz.wasm`, `game.pck.wasm`, the two worklet
`.js` files and the `.png` icons.

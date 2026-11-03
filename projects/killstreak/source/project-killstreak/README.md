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
scripts/data|rules|run|ai|ui/   (run/ = run flow logic behind the RunState autoload, p10)
scenes/  scenes/match/
data/cards|loadout|squads/
assets/fonts|ui|sprites|audio/
tests/               run_tests.gd (runner), test_case.gd (asserts), test_*.gd
```
Autoload order matters: EventBus loads first so every other singleton can connect to it in `_ready()`.

## Phone readability (screen profile, f01)
The iPhone is the main test device. With a fixed 720 px tall canvas, an 844x390 pt phone in
landscape drew the whole UI at 0.54x: 16 px text came out at 8.7 pt and 64 px tap targets at 35 pt.

**Chosen approach: a smaller canvas base on short screens, plus a compact match layout.**
`project.godot` still says 1280x720, `canvas_items` + `expand`. At startup and on every resize the
`Settings` autoload calls `scripts/ui/screen_profile.gd`, which sets the root's `content_scale_size`:
```
points   = window px / DisplayServer.screen_get_scale()   # devicePixelRatio on web, UIScreen scale on iOS
base_h   = clamp(height the 16:9 box gets in points / (0.75 * Settings.ui_scale), 540, 720)
base     = (base_h * 16/9, base_h)
```
- Desktop 1280x720 (and any screen 540 pt tall or more): base 1280x720, so nothing changes there.
- iPhone 844x390: base 960x540, giving a 1168x540 canvas at 0.722 pt per px.
- Windows between those heights scale smoothly, with no jump between them.

Below 640 logical px of height, `Match.tscn` switches to its **compact** profile: 64 px bars and
buttons, tighter spacing, unit slots without the class word (the class icon stays), smaller hand
chips without the "HAND n/7" caption, and narrower Operator and Supply columns.

Why this approach: a content scale factor alone would just overflow a layout that was designed
for 720 px. A separate phone UI would mean two layouts to maintain. Lowering the base keeps one
layout with a well-defined floor. Every text size is at least 16 px and every key number at least
20 px, so once one px is at least 0.72 pt, phones meet the targets.

Effective sizes at 844x390, checked by `tests/test_board_layout.gd`:

| | before (p08) | now |
|---|---|---|
| smallest text | 7.6-8.7 pt | 11.6 pt |
| smallest key number | 8.7 pt | 14.4 pt |
| smallest tap target | 34.7 pt | 46.2 pt (44.8 pt for an overlapped 7-card hand with notch insets) |

Notes:
- In Safari with its toolbars showing, the page is shorter than 390 pt, so the canvas stays at
  540 px tall and scales a little lower. A home-screen web app or Xogot runs at full height.
- The hand uses compact HandCard chips, not CardView. A CardView at the ~0.4x a hand slot allows
  would show its name at about 7 pt on the phone. CardView belongs in the long-press inspector (p09)
  at 0.8x or larger.

## Playing a match (hand input, p09)
`scenes/Match.tscn` runs a local test match against the real rules engine: its `MatchController`
child (`scripts/ui/match_controller.gd`) owns a `MatchState` (starter deck from the run config vs
`squad_rusher` on Port Vasel, Zone Control), turns gestures into `RulesIntent` submits, redraws the
scenes from `scripts/ui/match_snapshot.gd` and forwards engine events to `EventBus`. The enemy passes
until the AI plugs in through `MatchController.enemy_planner` (p07). Set `autostart` off to get the
p08 mock board instead.
- **Deploy:** tap a hand card, then tap a lane, or drag the card onto a lane. The Operator panel works
  the same way (place it in Round 1 or after a respawn, or Rotate it). Flank Route: tap one of your
  units, then a lane.
- While something is selected or dragged, every lane shows **DEPLOY HERE** (or PLACE / ROTATE / MOVE
  HERE) or why it can't take it (**NEED 3 SUPPLY**, **ZONE FULL**, **WAIT**...). A refused play shows a
  short toast and never reaches the engine. Unaffordable cards are faded in the hand.
- **Inspect:** long-press (touch, 400 ms) or right-click a hand card, a unit or the Operator. The
  inspector shows CardView at 0.8-1.4x, the full rules text, one line per keyword and the cost status.
- **UNDO** takes back the last play of this Deploy (above READY on desktop, next to MENU on the phone).
  **READY** (or R) resolves the round. Esc / right mouse clears the selection.
- Tests: `tests/test_hand_input.gd` drives all of this with InputEvents at 1280x720 and 844x390 @3x.

## Theme and fonts
`assets/ui/hud_theme.tres` is the project theme (`gui/theme/custom`). It styles every
`theme_type_variation` the scenes use, and nothing is styled in code. Both themes are generated by
`tests/tools/build_themes.gd`. The bundled OFL fonts named in the art direction are in
`assets/fonts/` (Barlow Medium for body, Barlow Condensed SemiBold for headings, Share Tech Mono
for numbers), with their licences next to them. Every FontVariation has an explicit `base_font`,
so line heights no longer depend on which theme happens to be global.

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
To test with gzip and the correct wasm MIME type, as itch.io serves it, use
`python3 ../../qa/performance-logs/tools/serve_gz.py ../../builds/web 8060` instead.

The loading screen is the custom HTML shell in `web/shell.html`, which the Web preset uses through
`html/custom_html_shell`. It shows a progress bar driven by Godot's `onProgress`, a status line, an
error notice when WebGL2 or WebAssembly is missing, and a "rotate to landscape" prompt on portrait phones.
It uses no external fonts or CDNs. Edit it like any HTML file, but keep the `$GODOT_*` placeholders.
The export filter excludes `tests/`, `qa/` and `web/` from the pck. Load-time results are in
`../../qa/performance-logs/web-load.md`. `scripts/ui/title.gd` prints `Title: ready`, which is the
marker the load-time check waits for.

### Package for itch.io
1. Export as shown above into `builds/web/`.
2. Zip the **contents** of the folder, so that `index.html` sits at the zip root and not inside a subfolder:
   `cd ../../builds/web && zip -r ../killstreak-web.zip . -x '*.import'`.
   The zip is about 9.8 MB, which is far under itch.io's 500 MB limit for HTML games.
3. On itch.io: Kind of project → **HTML**, upload the zip, tick **This file will be played in the browser**.
   Set the viewport to 1280×720 and turn on **Mobile friendly** with landscape orientation, plus the **Fullscreen button**.
   Leave **SharedArrayBuffer support** off. This build is single-threaded (`variant/thread_support=false`),
   so it needs no cross-origin isolation (COOP/COEP) headers. Leaving the option off also avoids the
   iOS Safari and third-party embed problems that it causes.
4. Keep the page private or restricted (draft or password) for playtests.

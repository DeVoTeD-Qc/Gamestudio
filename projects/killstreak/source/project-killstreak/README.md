# Killstreak (working title): Godot project

Web prototype of a tactical card roguelite. **Godot 4.4.1, GDScript only, Compatibility renderer.**
It has no GDExtensions, plugins or C#, so it runs in Godot on desktop and in Xogot (Godot for iOS).

Plan and structure: `../../documentation/production/prototype-milestone-plan.md` (§5 layout, §6 web settings).

## Open the project
- **Desktop Godot 4.4.1:** Project Manager → Import → select this folder's `project.godot`.
- **Xogot (iPhone/iPad):** copy or sync this folder (`project-killstreak/`) into Xogot's projects
  location, for example through the Files app or iCloud Drive, then open it in Xogot. Play in landscape.
- Main scene: `res://scenes/Boot.tscn`. It shows "Loading..." and routes to `Title.tscn` through `SceneRouter`
  (to the playtest consent screen first while it is unanswered, except in headless runs).

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
scenes from `scripts/ui/match_snapshot.gd` and forwards engine events to `EventBus`. The enemy is
played by the AI (`AiPlayer`, p07) through `MatchController.enemy_planner`; it commits its plan before
you deploy (set `enemy_ai = false` to make it pass). Plays are validated by the engine's `can_submit` /
`legal_targets` (reason codes mapped to text in `scripts/ui/play_text.gd`). Round 1 opens a mulligan
panel. Item and killstreak buttons: tap the button, then a lane or enemy (Recon Drone and Attack Helo
queue on one tap). READY plays the round with the p14 combat feedback; tap or press F to fast-forward.
Set `autostart` off to get the p08 mock board instead.
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
- **Run match (f03):** opened from RunMap's DEPLOY, `MatchController` plays the MatchState from
  `SceneRouter.take_pending_match()` (the run slot's map and squad, AI, mulligan, FX, preview) instead of
  the local test match. When it ends, a **result banner** (VICTORY / DEFEAT / DRAW, score, why, round)
  waits for **CONTINUE**, which calls `SceneRouter.finish_run_match()` once and opens AfterAction. The
  local test match's banner offers **BACK TO TITLE**.
- **MENU** opens the pause sheet: RESUME, FAST ANIMATIONS (Settings), FORFEIT MATCH (asks first; ends the
  match as a loss with reason `forfeit` through the same banner / finish path) and QUIT TO TITLE (the run
  stays saved; Continue opens RunMap and DEPLOY replays the match from the same seed). Esc closes it.
- **Spotted red dots:** when Recon Drone / Callout / Recon Specialist reveal enemy deployments
  (`MatchState.revealed_red_dots`), the INCOMING slots show the card names (tag SPOTTED) and the minimap
  cell lists them in place of the dots.
- Tests: `tests/test_match_run_flow.gd` plays a run through the real match screen by taps (match played
  to the end, forfeit, quit and continue), plus the Title drill offer and spotted red dots.

## Outcome preview (p12)
**PREVIEW** (top bar, next to MENU) or **P** (`toggle_preview`) puts a cyan forecast card over each
lane header during your Deploy:
```
DEAL 5 · TAKE 3          ENDS YOURS
KILLS 2 · LOST 1         +2 UNKNOWN
```
The numbers come from the real rules engine: `OutcomeForecast.forecast(state)`
(`scripts/rules/outcome_forecast.gd`) copies the match with `MatchClone.copy()`
(`scripts/rules/match_clone.gd`), runs Reveal + Firefight on the copy and counts damage, eliminations
and the zone owner at the start of Score. The live match is never touched. The forecast uses **only what
you can see**: your queued plays, your own Equipment and the board. The enemy's face-down plays and
its hidden Equipment are removed from the copy. Its red dots are never simulated, so the card says
**+N UNKNOWN** (or **NO RED DOTS**). Face-down enemy tactics and items leave no dot, so treat the card as a
forecast, not a promise. It updates on every play and UNDO, hides while the round plays and under the
mulligan panel, and every toggle emits `EventBus.preview_toggled(enabled)`. The overlay ignores the
mouse, so taps reach the lanes underneath. Tests: `tests/test_outcome_forecast.gd` (the forecast equals
the real `resolve_round()` exactly when the enemy has no hidden plays; purity; fairness) and
`tests/test_outcome_preview.gd` (toggle, live updates, 13 pt text and a 46 pt toggle at 844x390 @3x).

## Run flow screens (p11)
Boot → (Consent → PreSurvey, once, p16) → **Title** → **Loadout** → **RunMap** → Match → **AfterAction** →
**Reward** ×N → RunMap … → after the Rival or at 0 tickets → AfterAction → **RunEnd** → (EndSurvey) → Title.
Scenes are in `scenes/run/` (Title stays `scenes/Title.tscn`), scripts in `scripts/ui/run/`:
`run_screen.gd` (shared base: compact profile, notch-safe margins, builders), `run_flow.gd` (which screen
comes next from the run's phase, After-Action report, run words), `pick_tile.gd` (one-tap choice tile).
- **Title:** TUTORIAL opens the p15 drill; on first launch (drill never completed or skipped, no saved
  run) "New here? Play the 3-minute drill." offers PLAY DRILL / NOT NOW (NOT NOW records a skip).
  CONTINUE RUN only when a save exists; it opens the screen for the save's phase. A save that
  can't be loaded shows `RunState.last_load_warning`. START NEW RUN asks before replacing a saved run.
- **Loadout:** starter kit plus the killstreak pool; tap to pick or drop, BEGIN RUN needs exactly
  `killstreak_slots`.
- **RunMap:** the 5 matches with squad, mode and goal, map, bracket bonus and WON / LOST / DRAW / NEXT;
  tickets as tags plus "2/3". DEPLOY emits `EventBus.next_match_requested` and starts the match.
- **AfterAction:** result, reason, rounds, score vs target, eliminations, best streak, ticket change.
- **Reward:** Supply Drop (CardView 0.8-1.3x with a readable rules line; tap the card to take it,
  DETAILS opens the inspector), weapon level (attachments) and Perk offer, each one tap; SKIP declines.
- **RunEnd:** victory or defeat with the reason, record, loadout and one row per match.
- Every screen announces `EventBus.screen_shown` (reward screens per offer: `reward_supply_drop` …).

**Match hand-off** (`autoload/scene_router.gd`): RunMap calls `SceneRouter.start_run_match()`, which makes
the MatchState with `RunState.create_match()` and opens `Match.tscn`. Match.tscn calls
`SceneRouter.take_pending_match()` on load (null = no run match: play the local test match), starts that
match, and once it has ended calls `SceneRouter.finish_run_match(m)`, which records it on the run and
opens AfterAction. `finish_run_match_forced(result, outcome, stats)` does the same without a match
(debug, tests). `SceneRouter.dry_run` makes routes record-only for tests.

Tests: `tests/test_run_screens.gd` taps through the whole run (every offer type, continue from a save,
corrupt save, defeat, survey routing) at 1280x720 and 844x390 @3x with notch insets, checking text
≥ 11 pt and taps ≥ 44 pt. Screenshots: `../../qa/screenshots/p11-*.png`.

## Tutorial match (p15)
`scenes/tutorial/Tutorial.tscn` is a scripted, skippable first match: four short rounds against
`squad_tutorial` that teach deploying, the firefight, the streak and calling in the Recon Drone
(about 2-3 minutes; the test estimates 140 s with reading time). The script is data:
`data/tutorial/tutorial_script.tres` (`TutorialScript`, see `data/README.md`).
- `scripts/ui/tutorial/tutorial_director.gd` (scene root) instances the real `Match.tscn`, puts
  `tutorial_match_controller.gd` (a subclass of `match_controller.gd`) on its MatchController before it
  enters the tree, and walks the steps. The match is deterministic: stacked draws, scripted enemy plays
  through `enemy_planner`, no mulligan, the match ends at round 4.
- `coach_overlay.gd` draws the coach card, the amber highlight frame and, on locked steps, dims the rest
  and blocks taps outside the highlight. The controller's gates also refuse any other play, READY or UNDO
  with a short toast. Hand card steps frame the card, then the lane once it is selected; tap-tap and drag
  both work. The long-press inspector still opens (the lock lifts while it is open).
- SKIP TUTORIAL (tap twice) is on every coach card. DONE / SKIP go to the Title; REPLAY restarts.
  `scripts/ui/tutorial/tutorial_progress.gd` stores completed / skipped in `user://tutorial.cfg`.
- Each step emits `EventBus.tutorial_step(index)`. The tutorial's gameplay signals are **not** sent to
  EventBus, so a drill never counts as a run match in the playtest log.
- Coach text is 16-20 px (11.6-14.4 pt on an 844x390 phone) and its buttons are 64 px tall (46 pt).
- Known gap: the board itself doesn't show the cards behind red dots revealed by the Recon Drone or
  Callout (only the coach text names them, through `MatchState.revealed_red_dots`).

**Title integration (owned by p11, not wired yet).** Add a "TUTORIAL" button that calls
`SceneRouter.goto_scene("res://scenes/tutorial/Tutorial.tscn")` (a `SCENE_TUTORIAL` constant in SceneRouter
is suggested). On first launch, offer it automatically:
```gdscript
const TutorialProgress := preload("res://scripts/ui/tutorial/tutorial_progress.gd")
if TutorialProgress.should_offer() and not RunState.has_save():
    # show "New here? Play the 3-minute drill" with PLAY DRILL / NOT NOW
```
NOT NOW should call `TutorialProgress.record(false, 0)` so the offer doesn't come back.
The tutorial returns to `TutorialDirector.exit_scene` (the Title by default).
Tests: `tests/test_tutorial.gd` (whole drill by simulated taps on phone and desktop, the skip path,
locks, phone sizes). Screenshots: `../../qa/screenshots/p15-*.png`.

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

# CardZone - Godot 4.4.1 project (prototype)

Web-first prototype. Renderer **Compatibility** (WebGL 2), 1280x720 base, `canvas_items` + `expand`,
landscape. Set up in cz03 from CallingCard (see
`documentation/production/prototype-milestone-plan.md`, sections 5 and 9).

## Layout
- `autoload/` - EventBus (signal contract), Settings (+ screen profile), SceneRouter
- `scenes/` - `Boot.tscn` (main scene) -> `Title.tscn` (placeholder)
- `scripts/ui/` - `boot.gd`, `title.gd`, `screen_profile.gd`
- `scripts/{data,rules,ai,save,art,fx}/`, `data/`, `assets/` - empty, filled by later tasks
- `tests/` - headless runner, `test_case.gd` base, `test_smoke.gd`
- `web/shell.html` - custom web shell (loading bar, rotate prompt, "Prototype build" line)
- `export_presets.cfg` - "Web", single-threaded, includes `assets/fonts/*.txt` (OFL licences)

## Commands
```bash
godot --headless --path . --import                       # first run / after adding assets
godot --headless --path . -s res://tests/run_tests.gd    # tests; exit code 0 = green
godot --headless --path . -s res://tests/run_tests.gd -- --only=smoke
../../tools/package_artifact_build.sh <godot-binary> <out-dir>   # web build for a claude.ai artifact
```
Publish from `<out-dir>`: `index.html`, `index.js`, `engine.gz.wasm`, `game.pck.wasm`, the two
`index.audio*.worklet.js` files and the `.png` icons (not `index.wasm` / `index.pck`).

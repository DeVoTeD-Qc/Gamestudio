# Imported project

Snapshot of https://github.com/DeVoTeD-Qc/wardeckbuilder at commit `374cc63` (2026-11-04).

- Engine: HTML5 / vanilla JavaScript (studio exception to the Godot default, chosen by the studio head).
- `build/index.html` is the playable single-file build; `src/` holds the rules engine (`engine.js`), UI (`ui.js`), styles, art (`webart/`) and the print-and-play generator (`pnp/`). `npm run build` (tools/build.js) assembles the build from `src/shell.html`; see README.md for all commands.
- The original itch.io publish workflow is kept for reference in `.github-original/workflows/itch.yml`; it does not run from this repo. To release, copy `build/index.html` back to the wardeckbuilder repo (its push publishes to itch.io).

# Warzone Deckbuilder (working title)

- `build/index.html` — the playable HTML5 game. Pushing a change to this file uploads it to itch.io automatically.
- `src/` — rules engine, UI, styles, art and the print-and-play generator used to make the build.
- `.github/workflows/itch.yml` — the upload job (uses itch.io's official `butler` tool).

## Setup (once)
1. Settings → Secrets and variables → Actions → **Secrets**: `BUTLER_API_KEY` = your itch.io API key (itch.io → Settings → API keys → Generate new API key).
2. Same page → **Variables**: `ITCH_USER` = your itch.io username, `ITCH_GAME` = your game's URL slug (the part after `itch.io/` in the game page address).
3. Actions tab → "Publish to itch.io" → Run workflow, to test.

The first push creates an `html5` channel on itch.io. On the game's edit page, tick "This file will be played in the browser" for it once.

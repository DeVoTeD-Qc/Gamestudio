# assets/incoming: raw image drop folder

This folder holds images generated from the prompt pack
(`projects/killstreak/documentation/art/image-prompt-pack.md`) before anyone has cropped,
checked or imported them. Nothing in the game loads from here.

## Dropping images
- Upload the image exactly as ChatGPT gave it: full size, uncropped, PNG.
- Use the file name from the prompt pack: lowercase, underscores, `.png`, for example
  `card_rifleman.png`, `lane_cranes.png`, `title_key_art.png`, `perk_grit.png`.
- A second try at the same slot gets `_v2`, `_v3`: `card_marksman_v2.png`.
- Flat folder, no subfolders.
- If you can't rename on the phone, attach the images in the Studio Floor chat instead and
  list the names in upload order. The Technical Artist will name and commit them.

## Name prefixes
| Prefix | What it is | Ships as |
|---|---|---|
| `card_<card id>` | Card art window (ids match `scripts/ui/art/card_art_data.gd` CARDS) | 888x544 |
| `lane_<containers, cranes, offices>` | Port Vasel board lane backdrop | 800x720 |
| `title_key_art` | Title screen background | 1536x864 |
| `runmap_mode_<mode>` | Run map match card art | 888x544 |
| `bg_<screen>`, `fx_<effect>` | Full-screen backdrops | 1536x864 |
| `card_back` | Face-down card back | 500x700 |
| `perk_<perk id>` | Round morale patch for a perk | 512x512 |

## For the Technical Artist
- Check each image against the reject checklist in the prompt pack (section 4) before using it.
- Crop and resize as the pack says. Move the result to its final folder (`assets/sprites/cards/`,
  `assets/sprites/board/`, `assets/ui/backgrounds/`, `assets/ui/perks/`) and delete it from here.
- Raw drops here must never ship. Add a `.gdignore` here (or exclude `assets/incoming/*` in the
  export preset) before the first image lands, so Godot neither imports nor exports them.
- The procedural SVG art in `CardArt` stays as the fallback for any slot that has no approved image.

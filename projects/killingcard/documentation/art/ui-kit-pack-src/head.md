# KillingCard: UI kit image prompt pack v1

*Author: Sr Game Artist Agent · 2026-11-06 · Board task kc-ui-art · Target: Godot 4.4.1 web (Compatibility), phone landscape 844x390 first, desktop 1440x900*
*For: the studio head (generates in ChatGPT on the phone) and the Technical Artist (cuts, keys, imports).*
*Companion file: `ui-kit-manifest.csv` (one row per image: id, file, category, size, transparency, 9-slice margins, states, where used, priority, final folder).*

**{TOTAL} images: P1 {P1}, P2 {P2}, P3 {P3}.** This pack covers the UI kit around the card art: every icon, button backer, panel, background, and every part needed to build the card frames. The card art itself is not in this pack: the private pitch uses licensed calling cards, the public build uses the banner pack (`banner-art-direction.md`). **Everything here is original**: no logos, brands, franchise insignia, real weapon trademarks, and no text baked in. The game draws every word and number.

What the UI draws today (survey, 2026-11-06): almost all of it is drawn in code. `icon_sheet.svg` holds 34 white line icons (placeholder), `hud_theme.tres` and `card_theme.tres` use flat StyleBoxes, and `banner_view.gd`, `synergy_glyphs.gd`, `strip_badge.gd`, `objective_tile.gd`, `killstreak_row.gd`, `hand_area.gd` and `board.gd` draw badges, plates, bands, ticks and glyphs with `draw_*` calls. The only bitmaps are the Killstreak-era paintings (`title_key_art`, `bg_run`, `bg_supply_drop`, `fx_callin_tablet`, 4 perk patches, 3 square lane backdrops, card art). This pack replaces the code drawing with images where an image looks better, and **keeps the code drawing as the fallback** for every slot.

## 0. Count


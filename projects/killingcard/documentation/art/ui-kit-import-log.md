# UI kit import log

*Technical Artist. One section per batch from `ui-kit-prompt-pack.md`. Newest first.*

## How to import batch N (any batch, kc-ui-hooks)

One pass, from the repo root. The manifest (`ui-kit-manifest.csv`) is the source of truth: file name, kind, ship size and final folder. The game looks in the same folders (`UiKit.ICON_DIR`, `UiKit.PIECE_DIRS`: `frames/`, `fx/`, `panels/`, `plates/`, `icons/`, `arts/`, and since batch 2 `buttons/`, `tiles/`, `bands/`), and `tests/test_ui_kit_hooks.gd` fails if the two ever disagree.

1. **Drop** the raw PNGs exactly as ChatGPT gave them into a folder outside the repo (or `source/project-killingcard/assets/incoming/batch<N>/`), named as the manifest `filename` (a retry is `<name>_v2.png`; the highest `_vN` wins). `incoming/` has a `.gdignore`, so Godot never imports or exports it, but it is **not git-ignored** (`git check-ignore` says no): never `git add` it, and prefer a scratch folder for big drops (batch 2 ran straight from one).
2. **Check** each image against the pack's reject checklist (§4); for 9-slice pieces, the corner detail must sit inside the manifest margins.
3. **Dry run:** `python3 -I tools/ui_kit_icons.py --manifest documentation/art/ui-kit-manifest.csv source/project-killingcard/assets/incoming/batch<N> source/project-killingcard --dry-run`. Every file should say `SHIP`; a `SKIP ... not in the manifest` is a misnamed file, `RETIRED slot` is expected for retired ids.
4. **Process:** the same command without `--dry-run`. Icons get the 256 master + 128/64/48/32 exports; `fx_glow_rail`, `fx_crack_damage` and the white parts (rings, pips, nodes, arrows) are luma (white + alpha); frames, plates, buttons, panels and tiles keep real alpha or have the magenta keyed, and 9-slice pieces keep their corners (`nine_resize`: scaled to cover, corners copied, edges stretched or squeezed); `add` glows keep RGB on black; backgrounds become 1536x864 WebP q85, column backdrops 512x1216 WebP; bands a 512 swatch + 512x32 strip; `tex_orders_paper` is made seamless. WebPs keep the project's `importer="keep"` `.import` (the game decodes them itself, `CardArt.bitmap`).
5. **Import:** from `source/project-killingcard`: `godot --headless --path . --import`, then `python3 -I ../../tools/ui_kit_icons.py --post-import .` (mipmaps on for icons), then `godot --headless --path . --import` again.
6. **Test:** `godot --headless --path . -s res://tests/run_tests.gd` (all pass, with or without the new images), then the screenshots: `xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1168x540 -s res://tests/tools/shot_cards.gd -- <out>` and look at the hooks the batch fills.
7. **Clean up and log:** delete the raw drop folder (raw files never ship), add a section here (what shipped, rejects, style notes for the next batch), and commit the PNGs together with their `.import` files.

Nothing in the code needs to change for a batch: every v2 slot below already asks the kit first and keeps its code drawing as the fallback.

## kc-ui-hooks: v2 slots wired (2026-11-06)

**Hooks** (prompt pack §7.4b; all fall back to the current code drawing, so the game looks the same until a file lands):

| Slot | Where | Drawn as |
|---|---|---|
| `kw_pick_v2` (icons/) | `CardLook.draw_pick_icon`, so the board Pick ability, the O2 tray card and the Y2+ text box all get it | tinted like the code glyph |
| `frm_y2_unit`, `frm_y2_operator`, `frm_y2_standard_issue`, `frm_t1_orders` (frames/) | `CardView._draw()` (`frame_piece()`), and `hand_area._apply_operator_frame` for the O2 tray card | 9-slice at 0.5 scale, replacing the outline polygons and the khaki band; a marked / Elite / killstreak card keeps a 1.5 px keyline in its state colour over the rim; the O2 card keeps a teal keyline while selected |
| `tex_orders_paper` (frames/) | `CardView._draw()`, Tactics only | tiled at 0.5 scale under the title, 60% alpha |
| `fx_glow_rail` (fx/) | `BannerView` rail highlight | 9-slice over `r.grow(8k)`, tinted the trait colour |
| `fx_crack_damage` (fx/) | `CardLook.draw_crack` | a dark copy 1 px larger, then amber `#F2A33A` |
| `plate_fp_reticle` (frames/) | `CardLook.draw_reticle` | modulated teal `#2EC4B6` / red `#FF5A5D`; the number (green when buffed) still draws on top in code |
| `plate_armor_ballistic` (frames/) | `CardLook.draw_armor` | as is; amber `#F2A33A` when damaged, number `#FFC067` on top |
| `coin_level` (frames/) | `CardLook.draw_level_coin` | as is for R; brass `#F3D36B` for T / V / E; the letter on top |

**UiKit changes:** `draw_piece(ci, id, rect, tint, scale = -1)` now draws its own 9-slice (`draw_nine`, nine `draw_texture_rect_region` calls) with the rims at `PIECE_SCALE` (0.5 for the 2x kit, `DEFAULT_PIECE_SCALE` otherwise), so a 24 px ship margin is a 12 px rim; it no longer touches the caller's `draw_set_transform`. `draw_tiled()` for tiles. `fx/` added to `PIECE_DIRS`. `PIECE_MARGINS`: `frm_standard_issue` 16 on every side (the notch is gone), the four Y2+ / T1 frames and `fx_glow_rail` from the manifest. Tests can stand in a dummy image with `UiKit.piece_overrides` / `icon_overrides` and read `UiKit.draw_log`.

**Removed:** `ico_kw_pick.png` and its exports and `.import` files (retired, nothing loaded it); the serial plate and the stencil-coloured name in the deck / Muster list (`run/engine_panel.gd`).

**Checked:** 546 tests pass (10 new in `tests/test_ui_kit_hooks.gd`). Card screenshots (`tests/tools/shot_cards.gd`, public art) before and after are pixel-identical for the reward, Codex and T1 screens; the match screens differ only inside their run-to-run animation noise (the pulsing Operator glow, fading ghosts), which two runs of the old code show too. A dry batch with stand-in images went through the importer, `--import` and the game end to end (every hook drew its image), then was removed.

## Batch 1: P1 icons (kc-ui-import, 2026-11-06)

**In:** `ico_stat_firepower`, `ico_stat_armor`, `ico_stat_cover`, `ico_stat_supply`, `ico_stat_deck`, `ico_stat_intel`, `ico_streak`, `ico_score`, `ico_kw_first_shot`, `ico_kw_pick`. 1254x1254 RGB, white on black, all 10 accepted (no regenerations).

**Processing** (`tools/ui_kit_icons.py`, pack §7.2 `luma`): brightness to alpha with levels 8%..92%, RGB pure white, trimmed to the glyph, centred on a square with 8% padding. Shipped to `source/project-killingcard/assets/ui/kit/icons/`: a 256 px master `ico_<id>.png` plus exports in `128/`, `64/`, `48/` and `32/`. Import: lossless, mipmaps on, `fix_alpha_border` on. About 130 KB of PNG for the 10 icons at all five sizes. The raw drops are not committed (`assets/incoming/README.md`: delete after processing).

**Why exports rather than one 128 px atlas (deviation from §7.3):** canvas items draw with the project's default plain Linear filter, so mipmaps are never sampled and a 128 px cell drawn at 22 px aliases. `UiKit` picks the smallest export at or above the real on-screen size instead (`UiKit.draw_icon` measures it; the `IconSheet` callers get the 48 px export, which covers 22-34 px logical at x1-1.6 phone scale). Once all P1/P2 icons are in, pack each size into its own atlas (`kit_icons_32.png` and so on) to cut file count. The 256 and 128 sizes can then be left out of the web build if it gets tight (they serve only large menu or reward icons).

**Code:** `scripts/ui/ui_kit.gd` (`UiKit`): `icon(id, px)`, `has(id)`, `has_kit(id)`, `kit_texture(id, px)`, `draw_icon(ci, id, rect, tint)` (returns false so the caller keeps its drawn glyph), `tint(side, state)` with the §2.2 tokens, and the aliases `intel_contact > stat_intel`, `supply > stat_supply`, `kw_cover > stat_cover`, `type_equipment > type_field` and `elite > elite_star`. `IconSheet.get_icon()` and `has_icon()` ask UiKit first, so every existing sheet caller shows the kit image without being edited: the FP and Armor icons on the full card, inspector and hand cards, the First Shot and Pick pips on banners, the keyword row, the Cover chip, the glossary, the killfeed and the call-in. `strip_badge.gd` asks UiKit for its STREAK, DECK (`stat_deck`) and RIVAL (`stat_intel`) glyphs and keeps its drawn glyph as the fallback.

**Not wired yet:** `score` and `stat_supply` load through UiKit, but nothing in the game draws a Score or Supply pictogram today (the SCORE badge has no glyph, the Supply row is text plus pips). Adding them changes those layouts, so it is left to the UI owner.

**Tests:** `tests/test_ui_kit.gd` checks the 10 ids at every export size, the aliases, the IconSheet hook, the fallback to the sheet or to null with the kit folder missing, and that the strip badge draws either way. The full suite passes with the kit and with `assets/ui/kit` and `assets/licensed` both removed.

**Screens:** `qa/screenshots/ui-kit/` (public art, phone 844x390 at 2x): deploy, round 2, the Marksman inspector (Pick, FP, Armor), and a contact sheet at 22 / 32 / 48 px on dark and light backgrounds.

### Style feedback for batch 2+

1. **Stroke weight at 22-32 px.** Most of the set reads well. These details are below the floor and turn into grey smudges at 32 px and below:
   - the speed lines on **First Shot**;
   - the corner-bracket mark inside **Pick**'s quadrant (it becomes noise; a plain solid square would read);
   - the thin curved arrow on **Cover**;
   - the inner rim gap on **Armor** at 22 px.

   For batch 2+, ask for **strokes and gaps of at least 1/10 of the canvas** instead of 1/12, and **no detail smaller than 1/8 of the canvas**. Suggested change to the icon tail: "Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels."
2. **Keep silhouettes compact.** Icons are trimmed to their longest side, so wide, flat glyphs (First Shot, Streak, Cover) come out visibly smaller than round ones (Firepower, Intel) in the same 22 px slot. Ask for a "compact, roughly square silhouette that fills about 70% of the canvas in both width and height". This matters for Flank, Pierce and Suppress in batch 2, which are naturally long arrows or bullets.
3. **Keep the shapes apart.** Pick (quartered reticle) and Firepower (broken ring with a dot) are still told apart at 32 px by the cross versus the gaps. Keep the rest of the keywords off circles and reticles. Intel's radar quarter-circle sits close to the motif the old range icons used, so when `range_close / mid / long` are generated (batch 27), use a different motif (bars or chevrons, for example).
4. **What worked:** the flat pure-black background keyed perfectly, with no halo or checkerboard. Line weight is consistent across the set, the 45-degree chamfers are on-style, and nothing has text or marks. Keep the same chat and style block for batch 2.

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

## kc-ui-bands: level bands drawn in code (2026-11-10)

The head answered B1 (a): the four level bands are **original finishes drawn in code** (`scripts/ui/mastery_bands.gd`), not images: **Gold Leaf** (beaten gold-leaf flakes over the Base), **Machined** (brushed steel with a bevel), **Prism** (cut crystal facets) and **Starfield** (a night sky with stars); no blob camo. Base stays the kit's `band_base` (a plain olive twill without it). The old ids (the names of a shooter franchise's mastery camos) are retired everywhere in code, data, tests and these docs: `gilded > gold_leaf`, `forged > machined`, `priceless > prism`, `interstellar > starfield` (the manifest slots are now `band_gold_leaf` ... `band_starfield`, status "retired (kc-ui-bands): drawn in code"). Saved profiles migrate on load (`RunProfile.normalised` > `MasteryBands.migrate`). The OPERATOR strip badge shows the band on its disc; its long press / right click opens the Operator inspector, which names the band and says how it is earned. The `mw3-*` documents describe the licensed pitch set's real card titles and are left as they are.

## Batch 2: the full prompt pack, 201 images (kc-ui-import2, 2026-11-10)

**In:** the studio head's complete drop, 201 PNGs (P1 97, P2 84, P3 20), checksum-verified against its `ASSET_INDEX.csv`. It was generated from the pack before v2 settled, so it holds 19 retired slots and 5 v1 slots that are no longer in the manifest (`frm_cost_hex`, `frm_badge_fp_you`, `frm_badge_fp_rival`, `frm_badge_armor`, `frm_chip_cover`), and none of the 11 v2 slots (`kw_pick_v2`, the Y2+ / T1 frames, `tex_orders_paper`, `fx_glow_rail`, `fx_crack_damage`, the painted reticle / plate / coin): those hooks still draw their code fallback. The raw files were processed from a scratch folder and never entered the repo.

**Result:** 160 shipped (151 new or changed images; the 9 batch-1 icons in the drop are the same images and re-export byte for byte), **17 not shipped** (12 rejects, 5 where the current art reads better), 24 skipped (19 retired, 5 not in the manifest). Manifest `status` is now `imported (batch 2)` or `rejected (batch 2): regenerate`, with the reason in `notes`.

### Rejected (regenerate; reasons also in the manifest notes)

| Slot | Why |
|---|---|
| `ico_kw_guard` | A plain shield. The prompt says "not a shield" (the shield is Armor, and `kw_pick_v2` is a shield with an arrow). |
| `ico_kw_spotter` | An eye. The prompt says "not an eye" (the eye is the PREVIEW toggle, `ico_ui_eye`, which shipped). |
| `ico_kw_overwatch` | A reticle with side arrows. The prompt asks for a visor slit and forbids circles, rings and reticles; it reads as the FP reticle. |
| `ico_kw_aura` | Concentric broken rings and a dot. The prompt asks for a square with four radiating bars and forbids circles; it reads as the FP reticle. |
| `band_gold_leaf`, `band_machined`, `band_prism`, `band_starfield` | **IP.** Gold / white-steel / blue-crystal / violet-nebula blob camo that reads as a copy of a shooter franchise's mastery camos (the internal ids are already those camo names). The repo is public and §6.1 bans copied camo patterns. If the swatches are still wanted, ask for a non-camo look (brushed gold leaf, machined steel, faceted crystal, a star field) with no blob pattern. `band_base` (generic olive woodland blobs) shipped. |
| `btn_primary_pressed`, `btn_secondary_pressed` | A different plate from the normal one (inset rim, chamfers on all four corners): the button would change shape when pressed. The code pressed state (x0.85, 1-2 px down, pack §2.6) is better until a matching pair is generated in one chat. |
| `btn_ready_pressed` | Same, and its left hazard stripes sit in the stretched middle and smear. |
| `pnl_hand_tab` | A grip mark in the middle of the top edge: it smears when the 9-slice stretches. |

**Kept the current art** (they pass the checklist but read worse in the game than what it shows today): `ico_ks_attack_helo` (thin rotor and tail boom vanish at 22 px) and `ico_ks_gunship` (a long, flat four-engine plane; at 22 px it is a line, and the silhouette is very close to one real gunship model). Ask for both as compact, roughly square silhouettes (three-quarter top view, thick rotor disc / thick wings). And `col_containers`, `col_cranes`, `col_offices`: the manifest's middle 648 px crop is plain dark asphalt, so at 34% behind the slots the three columns turned into the same blank grey; the Killstreak `lane_*.webp` still read as containers / cranes / offices, so they stay. Regenerate with the location visible across the full width, still low contrast.

**IP check:** no image in the drop has a franchise, publisher or studio logo, emblem, wordmark, a copied real trademark, or any text, letters or numbers (the backgrounds were checked at full size: the map, notice board, ruler and crates are all blank). Weapon silhouettes are generic (no one real model, no markings). The only IP problem is the four mastery-camo bands above.

### What shipped where

- **Icons (83 new, `assets/ui/kit/icons/`):** 256 master + 128/64/48/32 exports, as batch 1.
- **Buttons and controls (11, `buttons/`), panels and strips (23, `panels/`), tile backers (4, `tiles/`), frame parts (7, `frames/`), glows and overlays (11, `fx/`), `band_base` + `band_base_strip` (`bands/`).** Every alpha piece came with real transparency (no magenta key needed). The 9-slice pieces were checked stretched wide and tall; four margins were raised in the manifest (and in the pack and `slots.py`) because a corner detail reached past them: `btn_ready` (and its pressed slot) right 112 -> 128 (hazard stripes), `pnl_callout` 24 -> 32 left and right (the slant), `pnl_coach` left 32 -> 64 (the speech tail), `pnl_pick_tile` bottom 64 -> 80 (the name band).
- **Backgrounds:** 1536x864 WebP q85 in `assets/ui/backgrounds/`. Three replace the Killstreak-era files at the paths the game already loads, so the screens pick them up with no code change: `bg_title` -> `title_key_art.webp` (the old one had three soldiers in the foreground, which the v2 brief forbids), `bg_run_map` -> `bg_run.webp`, `bg_supply_drop` -> `bg_supply_drop.webp` (more room for the cards). Six are new and not loaded by anything yet: `bg_menu`, `bg_match`, `bg_codex`, `bg_loadout`, `bg_loading`, `bg_after_action`.
- **Old files:** the replaced WebPs are in git history (`git checkout HEAD~ -- <path>` brings one back).

### Hooks: what draws the new art now

- **Through the existing `IconSheet` / `UiKit` lookups (no code change):** `range_close / mid / long`, `type_unit / tactic / field / killstreak / operator`, `class_ar / smg / shotgun / sniper / lmg`, `kw_flank`, `kw_suppress`, `kw_patch`, `kw_holder`, `trig_on_deploy`, `trig_on_down`, `ks_recon_drone`, `ks_mortar`, `ks_sentry`, `elite_star`, `eliminated`, `ui_lock` (the Duel lock), plus the three backgrounds above.
- **Wired in this batch (one line each, code glyph kept as the fallback):** the trait chips (`SynergyGlyphs.draw_trait_icon` asks for `trait_<t>`: Vanguard, Spec Ops, Heavy, Undead on every card, the rail and the inspector), Fireteam (`SynergyGlyphs.draw_keyword_icon`, symmetric so it needs no flip) and the effect bolt (`CardLook._draw_bolt`, the "more" dot stays code). `UiKit.PIECE_DIRS` now also searches `buttons/`, `tiles/` and `bands/`. Test: `test_ui_kit_hooks.gd::test_import2_trait_fireteam_bolt_hooks`.

### Shipped but not hooked yet (for the UI owner)

| Asset(s) | Where it goes | Hook needed |
|---|---|---|
| `bg_menu`, `bg_match`, `bg_codex`, `bg_loadout`, `bg_loading`, `bg_after_action` | pause menu; match backdrop (in place of the tactical shader, if the head prefers); Codex; Loadout; loading screen (+ a 960x540 copy for the web shell); After-Action | `CardArt.backdrop_texture(&"menu")` etc. under the run-screen scrim |
| `band_base` (+ `_strip`) | run-screen level swatch (Operator base tier) | `UiKit.draw_tiled` |
| `runmap_node`, `runmap_path` | run map node rings and dashed paths (`run_glyphs.gd`) | `UiKit.draw_piece`, tinted |
| `frm_front_tab`, `frm_plan_plate`, `frm_incoming`, `frm_dogtag_plate`, `frm_put_back`, `frm_ghost` | FRONT tab, PLAN tag, INCOMING slot, Operator dog tag, PUT BACK card, ghost preview | `UiKit.draw_piece` (+ margins in `PIECE_MARGINS`) |
| `card_back_banner`, `card_back_hand` | face-down 4:1 back (new); hand / mulligan back (`CardArt.card_back_texture` loads `cards/card_back.webp` 500x700 today) | new path or a swap at the right size |
| `fx_outline_teal`, `fx_outline_side`, `fx_glow_amber`, `fx_glow_red`, `fx_link_tick`, `fx_link_tick_ghost`, `fx_hit_flash`, `fx_tracer`, `fx_crack`, `fx_sheen` | selection outline, side outline, READY / killstreak glow, danger glow, board link ticks, hit flash, now-firing tracer, crack, hover sheen | draw with a `CanvasItemMaterial` blend Add (they are RGB on black, no alpha) |
| `btn_*` (primary, secondary, danger, ready, badge, chip, chip_on, tab), `tgl_track`, `tgl_knob`, `sld_track` | `hud_theme.tres` StyleBoxTextures (pack §7.4 step 2): READY, menu buttons, filter chips, tabs, settings toggles and sliders | StyleBoxTexture `.tres` from the manifest margins (0.5 scale: 1x exports or the `draw_nine` helper) |
| `pnl_tray`, `pnl_flyout`, `pnl_flyout_pointer`, `pnl_toast`, `pnl_inspector`, `pnl_tooltip`, `pnl_modal`, `pnl_header`, `pnl_ks_tile`, `pnl_counter`, `pnl_order_strip`, `pnl_rail_chip`, `pnl_callout`, `pnl_pick_tile`, `pnl_coach`, `pnl_result`, `ring_track`, `ring_fill`, `pip_supply`, `order_node`, `order_arrow` | hand tray, Operator flyout, killfeed toasts, inspector, tooltips, modals, headers, killstreak tile + charge ring, counters, fight-order strip, rail chips, set callouts, pick tiles, coach bubbles, result banner, Supply pips | themes or `UiKit.draw_piece` per widget |
| `tile_objective`, `tile_field_chip`, `tile_field_chip_trap`, `tile_slot_empty` | objective tile, Field chips, empty slot (`objective_tile.gd`, `lane.gd`) | `UiKit.draw_piece` |
| `ico_stat_discard`, `ico_stat_hand`, `ico_tickets`, `ico_round`, `ico_fired`, `ico_heal`, `ico_damage` | tray counters, score / tickets HUD, round counter, killfeed and feedback numbers | `UiKit.draw_icon` next to the numbers |
| `ico_kw_pierce`, `ico_kw_protector` | ability chip | side-dependent arrows: draw the kit base and keep the code arrow, or flip the rect for the rival |
| `ico_kw_hidden`, `ico_trap`, `ico_plan_mark`, `ico_field_slot`, `ico_overrun`, `ico_ctl_yours / rival / even / open` | Hidden traps, TRAP chip, PLAN tag, empty Field slot, OVERRUN callout, objective control marks | `UiKit.draw_icon` |
| `ico_ph_deploy / reveal / firefight / score`, `ico_mode_zone_control / firefight / detonator / rival` | phase header, mode picker and run-map mode tiles | `UiKit.draw_icon` |
| `ico_att_optic / grip / mag / lining`, `ico_perk_slot` | Loadout attachments and perk slot | `UiKit.draw_icon` |
| `ico_ui_*` (24: menu, settings, undo, speed, skip, codex, mirror, sound on / off, close, back, info, eye, eye off, filter, check, continue, retire, promote, reward, rotate, survey, tutorial) | strip MENU badge, settings, undo, x1 / x2, skip, Codex, mirror, sound, close / back, info, PREVIEW eye, filters, confirm, run actions, rotate notice, survey, tutorial | `Button.icon` = `UiKit.icon(&"ui_x", px)` |

### Web build size

Measured with a real `--export-pack "Web"` (public preset, no licensed art) of HEAD before the batch and of the tree after: **game.pck 5.58 MB -> 9.03 MB (+3.45 MB)**. Of that, the UI kit is **+2.96 MB** (kit textures in the .pck: 0.33 MB -> 3.29 MB) and the backgrounds +0.18 MB (six new ones, minus the three smaller replacements); the rest is other work in progress in the same tree. Kit textures by folder: icons 256 px 666 KB, 128 px 354 KB, 64 px 192 KB, 48 px 147 KB, 32 px 105 KB; panels 807 KB, buttons 255 KB, frames 256 KB, fx 200 KB, bands 200 KB, tiles 104 KB.

That is near the pack's 4 MB budget, and about 1.7 MB of it is art nothing draws yet. Proposals, biggest first:
1. **Leave unhooked art out of the web export until it is wired** (add `assets/ui/kit/buttons/*, assets/ui/kit/tiles/*, assets/ui/kit/bands/*` and the unhooked panels / fx / frames / backgrounds to the Web preset's `exclude_filter`, or keep them in a `.gdignore`d staging folder): about -1.7 MB now, and each hook brings back only its own file.
2. **Drop the 256 and 128 px icon exports from the web build** (nothing on the phone draws an icon above 64 px; needs a small change in `UiKit.kit_texture` to fall back to the largest export present instead of the sheet): -1.0 MB.
3. **Mipmaps off for the icon exports.** Canvas items never sample them (that is why the exports exist); they add a third to every icon texture: about -0.35 MB.
4. Once the set is final, pack each export size into one atlas (`kit_icons_32.png` ...) to cut ~430 icon files to 5; and ship the big panels at 1x as lossy WebP if they stay large.

### Checks

- Full suite: **661 passed, 0 failed** with the kit (658 after this batch plus 3 that other in-flight work added meanwhile; 1 new here: `test_ui_kit_hooks.gd::test_import2_trait_fireteam_bolt_hooks`), and **661 passed** in a copy of the project with `assets/ui/kit` and `assets/licensed` removed. Two existing tests were updated: `test_ui_kit.gd` (it checked that `kw_flank` was still a sheet icon; it now checks `ks_gunship`, which stays on the sheet) and `test_art_bitmaps.gd` (10 shipped backgrounds instead of 4).
- One run showed `test_board_columns.gd::test_banner_art_path_and_crops` failing; it passes alone and in the next full run. It writes and deletes `data/banners/kc_test_drop.tres`, so it races with another Godot process running in the same project at the same time.
- Screenshots (public art, 844x390, before / after): match board, hand (H1 selected), the Y2+ dock card (the inspector), Codex, run map, title, plus contact sheets of everything shipped at 32 and 64 px. They are not committed (scratch folder, see the task report).
- `tests/tools/shot_cards.gd` no longer parses (`CardView.view_for_card` third argument is now a trait StringName, the tool passes an int at line 143); the shots used a fixed copy. One-word fix for the UI owner.
- **The 21 v2 slots with no image in this drop are final** (generation closed): `kw_pick_v2`, `frm_y2_unit`, `frm_y2_operator`, `frm_y2_standard_issue`, `frm_t1_orders`, `tex_orders_paper`, `fx_glow_rail`, `fx_crack_damage`, `plate_fp_reticle`, `plate_armor_ballistic`, `coin_level`, `frm_standard_issue`, `frm_socket_empty`, `frm_socket_locked`, `pnl_new_card`, `pnl_new_inset` and the five Standard Issue arts `kc_b_si_grunt / trooper / sergeant / armored / ammo_resupply`. All are **covered by fallback**: each hook draws its code version (the Y2+ / T1 frames, paper colour, rail lines, crack, reticle, plate, coin, sockets, explainer panels, the built-in Pick shield) and the Standard Issue cards keep their current banner art (`data/banners/si_*.tres`, `BannerArtDB`), as the no-kit suite and the screenshots show (no empty or broken slot). The same holds for the 17 slots not shipped above.

### Style feedback for batch 3+ (regenerations)

1. **Read the Avoid line literally.** All four keyword rejects drew exactly what the Avoid line forbade (shield, eye, reticle, rings). Keep "Not a shield / not an eye / no circle" in the subject sentence too, not only in Avoid, and ask Guard as "a short thick wall of three stacked blocks", Spotter as "binoculars seen from the front", Overwatch as "a visor slit", Aura as "a square with four bars".
2. **Duplicates across groups.** `trait_heavy` and `ui_settings` are both gears, and `kw_hidden` and `ui_eye_off` are both a slashed eye; both follow their prompts, so the pack should change one of each pair (Heavy: a heavy weight / anvil block; Hidden: a dashed outline with a half-closed lid). `ctl_open` reads as a crosshair at 24 px (fine on the objective tile, but keep it off cards). `ctl_yours` is close to the FP reticle shape.
3. **Long silhouettes** still come out small after the trim: the shotgun, sniper, gunship and attack helicopter icons. For vehicles, ask for a three-quarter or top view that fills a square.
4. **Pressed plates:** generate the normal and pressed plates of a button in the same chat, with "the same plate, darker, pressed in", or skip them (code pressed state).
5. **9-slice ornaments** must sit within one margin of a corner: the hand-tab grip, the READY stripes, the coach tail and the callout slant all went past it.
6. **What worked:** all alpha pieces came with real transparency (no checkerboard, no magenta needed), every white-on-black icon keyed cleanly, the backgrounds are dark and calm with no text, and the panel family (gunmetal, thin steel rim, 45-degree chamfers, one amber accent) is consistent across buttons, panels and tiles.

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

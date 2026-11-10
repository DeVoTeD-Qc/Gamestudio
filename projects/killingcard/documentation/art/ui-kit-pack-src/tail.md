## 6. Reject checklist and IP rules

### 6.1 IP rules (binding, same as the banner pack)
- **All original.** No logos, emblems, icons, HUD styling, camo patterns or menus copied from any game, film or brand. The licensed calling cards appear only as card art in the private pitch; nothing in this kit may imitate their frames or the franchise's UI.
- **Never name a franchise, game, studio or artist in a prompt**, even as "not like". The prompts describe looks in plain visual words. Keep it that way when you reword one.
- **No real military marks:** no national or unit insignia, rank badges, roundels, flags, red cross or red crescent. Heal and Patch icons are plain white shapes, tinted green or teal in game, never a red cross.
- **No real products:** weapon and vehicle silhouettes are generic, with no shape that is clearly one real model and no brand marks.
- **No baked text.** The game draws all words and numbers (READY, FRONT, PLAN, A / B / C, EQUIPPED, PUT BACK, costs, stats). Any letter or digit in an image, even fake writing, means regenerate.
- kc-ui-bands: the level bands are no longer generated. The head chose original finishes drawn in code (`scripts/ui/mastery_bands.gd`: Gold Leaf, Machined, Prism, Starfield; no camo pattern), and the old ids (the names of a shooter franchise's mastery camos) are retired. Only `band_base` stays an image.

### 6.2 Reject checklist (any "yes" = regenerate; two tries, then skip and note it)
- [ ] Any letters, numbers, fake writing, a logo or a stamp?
- [ ] A flag, insignia, rank mark, crest, roundel, wings, laurels, a red cross or crescent?
- [ ] A weapon, drone or aircraft that is clearly a real model, or has markings?
- [ ] Looks like an icon, frame or menu from an existing shooter?
- [ ] **Icons:** not pure white on pure black? Grey shading, a coloured outline, a badge or circle behind the glyph, or two icons in one image?
- [ ] **Icons:** squint test at 24 px fails (shrink it on the phone: is it still obvious)? Strokes or gaps thinner than 1/10 of the canvas, or any detail smaller than 1/8? A long, flat silhouette instead of a compact, roughly square one?
- [ ] **Icons:** looks too much like another icon in the set (Pick vs FP reticle, Spotter vs PREVIEW eye: the code adds context, but the shapes must still differ)?
- [ ] **9-slice plates:** a rivet, notch or ornament in the **middle** of an edge (it would smear when stretched)? Edges not straight and even?
- [ ] **Plates:** a painted checkerboard instead of transparency, a cast shadow, or a perspective tilt?
- [ ] **Glows:** an object or surface instead of pure light, or a background that is not pure black?
- [ ] **Bands:** an obvious centre or a hard edge that won't tile?
- [ ] **Backgrounds:** a bright or busy centre, people in the foreground, recognisable real places? Key shapes in the top or bottom 10% (they get cropped)?
- [ ] **Column backdrops:** strong contrast or a focal point (it fights the cards)?
- [ ] Off palette: saturated colours that are not one of the tokens in 2.2?

## 7. Technical Artist hand-off

### 7.1 Folders
| Prefix | Final folder | Notes |
|---|---|---|
| raw drops | `assets/incoming/ui/` | already ignored (`assets/incoming/.gdignore`); never imported |
| `plate_fp_reticle`, `plate_armor_ballistic`, `coin_level`, `tex_orders_paper` | `assets/ui/kit/frames/` | v2: painted, alpha (the paper is opaque, repeat on). The v1 `plate_*_s/_l` number plates are retired |
| `kc_b_si_*` | `assets/sprites/banners/` + `data/banners/<id>.tres` | banner pipeline (`banner-art-direction.md` 3.2), curator sets `banner_y` / `portrait_x` |
| `ico_*` | `assets/ui/kit/icons/` | 256 masters; plus the packed atlas `assets/ui/kit/icons/kit_icons.png` (see 7.3) |
| `btn_*`, `tgl_*`, `sld_*` | `assets/ui/kit/buttons/` | |
| `pnl_*`, `ring_*`, `pip_*`, `order_*`, `runmap_*` | `assets/ui/kit/panels/` | |
| `tile_*` | `assets/ui/kit/tiles/` | |
| `frm_*`, `card_back_*` | `assets/ui/kit/frames/` | v2 Y2+ / T1 frames ship at 2x (500x432) |
| `band_*` | `assets/ui/kit/bands/` | |
| `fx_*` | `assets/ui/kit/fx/` | `fx_glow_rail` and `fx_crack_damage` are drawn by `UiKit.draw_piece`, which searches `frames/`, `panels/`, `plates/`, `icons/`, `arts/`, `sprites/banners/`: either ship them to `frames/` or add `fx/` to `UiKit.PIECE_DIRS` |
| StyleBoxTexture resources | `assets/ui/kit/styles/<id>.tres` | built from the manifest margins |
| `bg_*` | `assets/ui/backgrounds/` | replaces `title_key_art`, `bg_run`, `bg_supply_drop` (keep the old files until approved) |
| `col_*` | `assets/sprites/board/` | next to the old `lane_*` |

### 7.2 Processing (per kind, from the raw PNG)
- **luma** (icons, rings, pips, nodes, arrows, path, crack): `magick in.png -colorspace gray -level 8%,92% -alpha copy -fill white -colorize 100 -trim +repage -gravity center -background none -extent <square with 8% padding> -resize 256x256 out.png`. The `-level` crushes JPEG-ish noise near black and white.
- **plate** (v1 number plates, retired in v2; kept for reference): process as luma, then make `_fill` by flood-filling the inside of the rim with white, so the code draws `_fill` tinted dark, then the number, then the rim tinted bright. Keep each plate centred on the same square canvas as its icon, so `ico_stat_firepower` and `plate_fp` line up when swapped.
- **alpha** (plates): if the PNG has real alpha, keep it. If it has a magenta field: `magick in.png -fuzz 12% -transparent "#FF00FF" ...` then despill the edge (shift magenta-tinted edge pixels to the neighbouring colour, or a 1 px alpha erode). Then crop to the plate, resize to the ship size **with the border thickness in mind**: the border should be 4-6 px at ship size.
- **v2 exceptions:** `fx_glow_rail` is generated as a glow on black but processed as **luma** (brightness to alpha, RGB white) so it draws with a normal blend and a per-trait tint. `fx_crack_damage` is luma. `plate_fp_reticle`, `plate_armor_ballistic` and `coin_level` keep their neutral steel colours (alpha); the code modulates them.
- **add** (glows): keep RGB, drop alpha, crop with the glow falloff intact, resize. Import as normal; draw with a `CanvasItemMaterial` (`blend_mode = BLEND_MODE_ADD`).
- **9-slice check:** after resizing, confirm the manifest margins fall outside every corner detail. If a corner ornament is bigger, raise the margin in the manifest (and the `.tres`), not the image.
- **Bands:** cut a 512x32 strip, make it seamless (offset by half the width, clone the seam, or mirror-tile), set `texture_repeat` on.
- **Backgrounds:** crop as in the size key, export WebP lossy q85.

### 7.3 Import settings (Godot 4.4.1, web, Compatibility)
| Kind | Compress | Mipmaps | Filter | Other |
|---|---|---|---|---|
| Icons (atlas) | Lossless | **On** | Linear Mipmap | `fix_alpha_border` on, `premult_alpha` off. Pack all P1/P2 icons at 128 px cells into one atlas (`kit_icons.png`, 16 columns), like `icon_sheet.svg` today: ~120 icons = 2048x1024, ~500 KB. |
| Plates, frames, buttons, tiles | Lossless | Off | Linear | `fix_alpha_border` on |
| Glows (`fx_*`) | Lossless | Off | Linear | material blend Add |
| Bands | Lossless | Off | Linear | repeat enabled |
| Backgrounds, column backdrops | Lossy (WebP q85) | Off | Linear | not VRAM Compressed (bands gradients on web) |

Budget: kit icons ~0.5 MB, plates and frames ~1.2 MB (PNG at the ship sizes), bands ~0.3 MB, backgrounds and columns ~2 MB WebP. **About 4 MB total**, inside the art budget; P3 can wait if the web build grows.

### 7.4 How the code picks them up (proposal; keep the procedural art as the fallback)
1. **`scripts/ui/ui_kit.gd` (`class_name UiKit`)**, the same pattern as `IconSheet`:
   - `UiKit.icon(id) -> Texture2D`: the atlas region for `id` if the kit has it, else `IconSheet.get_icon(alias)`. Aliases: `stat_intel` > `intel_contact`, `type_field` > `type_equipment`, `elite_star` > `elite`, `ks_mortar` (same), `trait_<t>` and `kw_guard / spotter / fireteam / overwatch` > nothing (today `synergy_glyphs.gd` draws them, so keep that branch as the fallback).
   - `UiKit.style(id) -> StyleBox`: `assets/ui/kit/styles/<id>.tres` if present, else null (the caller keeps its StyleBoxFlat).
   - `UiKit.has(id)`: lets `_draw` code choose between `draw_texture_rect` and its current `draw_*` path.
2. **Themes:** swap `hud_theme.tres` and `card_theme.tres` StyleBoxFlats for StyleBoxTextures (`texture_margin_*` from the manifest, `content_margin_*` as today). Buttons get `normal / hover / pressed / disabled / focus` styleboxes: normal and pressed from the images, hover and disabled as the same texture with `modulate_color`. This alone re-skins most screens with no script change.
3. **Banners and other custom-drawn controls** (`banner_view.gd`, `objective_tile.gd`, `strip_badge.gd`, `killstreak_row.gd`, `trait_rail.gd`, `board.gd` link ticks): add a helper `UiKit.draw_nine(ci, tex, rect, margins, scale := 0.5)` that draws the 9 regions with `draw_texture_rect_region`, with the **margins scaled** (a 16 px ship margin draws as 8 logical px). StyleBoxTexture can't scale its margins, which is why the 2x plates need this helper in `_draw` code and a 0.5 `scale` wrapper (or 1x exports) in theme-driven Controls. Recommended: 2x textures + the helper for banners, 1x exports (`<id>@1x.png`, the TA halves them) for theme styleboxes.
4. **Ids = file names without `ico_` / extension**, and the manifest is the source of truth: a small `tools/` script can generate the `.tres` styleboxes and the atlas index from `ui-kit-manifest.csv`.
5. **Tests:** the suite already runs with and without `assets/licensed`; add a run with `assets/ui/kit` missing, so every fallback stays alive.

### 7.4b v2 code hooks (kc-ui-art2): what the code must ask for

Only one new slot is wired today. The others need a small hook each; until then the code drawing stays (it is the decided look). The `code_hook` column of the manifest has the same list for every slot.

| Slot (code id) | Status today | Change needed |
|---|---|---|
| `kw_pick_v2` | wired: `IconSheet.get_icon(&"kw_pick")` asks `UiKit.kit_atlas(&"kw_pick_v2")` (glossary, inspector, Y2+ text box) | `banner_view.gd` draws the board's Pick ability (`kind == &"kw_pick"`) with `CardLook.draw_pick_icon` directly: try `UiKit.draw_icon(o, &"kw_pick_v2", rr, accent)` first |
| `frm_y2_unit`, `frm_y2_operator`, `frm_y2_standard_issue`, `frm_t1_orders` | needs code | `CardView._draw()`: `UiKit.draw_piece(self, &"<id>", Rect2(0, 0, w, h))` before its outline polygons (skip the polygons and the khaki band when it returns true); add their margins to `UiKit.PIECE_MARGINS`. `hand_area._make_operator_card` (O2) can use `frm_y2_operator` the same way |
| `tex_orders_paper` | needs code | `CardView._draw()` for Tactics: draw it tiled (`draw_texture_rect(tex, face_rect, true, Color(1, 1, 1, 0.6))`, texture repeat on) |
| `fx_glow_rail` | needs code | `banner_view.gd` rail highlight: replace the two `draw_rect` lines with `UiKit.draw_piece(o, &"fx_glow_rail", r.grow(8.0 * k), trait colour)`, keep them as the fallback |
| `fx_crack_damage` | needs code | `CardLook.draw_crack`: draw the piece twice (dark, 1 px larger; then amber `#F2A33A`) |
| `plate_fp_reticle`, `plate_armor_ballistic`, `coin_level` | needs code (optional) | `CardLook.draw_reticle` / `draw_armor` / `draw_level_coin`: `UiKit.draw_piece(ci, &"<id>", r, team / grey / amber / brass)`, then the number or letter as today |
| `frm_standard_issue` (revised) | wired | `UiKit.PIECE_MARGINS[&"frm_standard_issue"]` from `Vector4(40, 32, 16, 16)` to `Vector4(16, 16, 16, 16)` (no notch) |

Two general fixes the new pieces need:
1. **Scale for 2x pieces.** `UiKit.draw_piece` draws the 9-slice margins at ship size (it only shrinks when the rect is smaller than the margins). The 2x Y2+ frames (24 px margins at 500x432) would draw 24 px rims on a 250 px card. Add a `scale` argument (0.5 for 2x pieces, per id in a `PIECE_SCALE` table) as section 7.4 step 3 proposed; the same applies to the existing `frm_standard_issue` (its 512x128 at 228x57).
2. **Retired leftovers in code.** `run/engine_panel.gd` still draws the Standard Issue serial plate and the stencil-coloured name in the deck / Muster list (`StandardIssueLook.draw_serial_plate`); `ico_kw_pick.png` is still in `assets/ui/kit/icons/` but is never loaded. Both are for the UI owner to remove.

### 7.5 Not in this pack (on purpose)
- Card art and banners (separate packs), the perk patches (already shipped), the call-in tablet (`fx_callin_tablet`, already shipped).
- Fonts (Barlow Condensed, Barlow, Share Tech Mono stay; Barlow Condensed Bold is the one title style, the stencil font is retired).
- The rival's mirrored arrows and all numbers and words (code).
- Real-time effects that are shaders today (scanlines, banner shimmer, tactical backdrop).
- "Steady" from the brief: there is no Steady keyword in the data or rules today. The real list used here is First Shot, Pick, Flank, Pierce, Cover, Suppress, Patch, Holder, Protector (arrives front), Hidden, the triggers On Deploy / On Down, the ⚡ effect bolt, the new Pick glyph (`kw_pick_v2`), and the neighbour keywords Guard, Spotter, Fireteam, Overwatch. A new keyword is one more icon prompt in the same group.

### 7.6 Import log and batch feedback
Each imported batch is logged in `ui-kit-import-log.md`: what shipped, where, and style notes for the next batches. **After batch 1:** strokes and gaps should be at least 1/10 of the canvas, with no detail smaller than 1/8 (First Shot's speed lines, Pick's inner bracket mark and Cover's thin arrow blur at 32 px). Keep silhouettes compact and roughly square, because wide glyphs come out small after the trim. Icons ship as a 256 master plus 128/64/48/32 exports, and `UiKit` picks the export by on-screen size (canvas items don't sample mipmaps). Tools: `tools/ui_kit_icons.py`, `scripts/ui/ui_kit.gd`.

## 8. Questions for the head

Answered or overtaken by kc-cards-impl (v1 questions): the hand card frame (X1 is the C1+ card, no frame), rival stats position (one rule), Standard Issue lettering (the stencil font is retired; one title style). Still open from v1: backgrounds (regenerate, recommended) and the icon look (white pictograms, recommended).

1. **Painted stat badges: yes or no?** The FP reticle, Armor plate and level coin are drawn in code in the decided flat style. **Recommended: skip them for now** (batch 5 drops `plate_fp_reticle`, `plate_armor_ballistic`, `coin_level` and shrinks to 6) and judge after the Y2+ frames are in: flat badges on painted frames may already look right. Alternative: generate them in batch 5 for a metal finish on the badges too.
2. **Y2+ frame finish.** **Recommended: semi-flat metal like the rest of the kit** (thin steel rim, one soft highlight, plain face), so the frame never fights the art. Alternatives: a heavier bevelled, machined rim (richer at 330 px, busier at 172 px), or keep the code frames and spend the batch on icons instead.
3. **T1 orders paper strength.** **Recommended: dark paper with a faint grain** (as in the mock-up: khaki rim, dark olive-brown face), so white rules text keeps its contrast. Alternative: light khaki paper with dark text (reads more like orders, but needs a second text colour in `CardView` and breaks the one-text-style rule).

# KillingCard: UI kit image prompt pack v1

*Author: Sr Game Artist Agent · 2026-11-06 · Board task kc-ui-art · Target: Godot 4.4.1 web (Compatibility), phone landscape 844x390 first, desktop 1440x900*
*For: the studio head (generates in ChatGPT on the phone) and the Technical Artist (cuts, keys, imports).*
*Companion file: `ui-kit-manifest.csv` (one row per image: id, file, category, size, transparency, 9-slice margins, states, where used, priority, final folder).*

**215 images: P1 112, P2 82, P3 21.** This pack covers the UI kit around the card art: every icon, button backer, panel, background, and every part needed to build the card frames. The card art itself is not in this pack: the private pitch uses licensed calling cards, the public build uses the banner pack (`banner-art-direction.md`). **Everything here is original**: no logos, brands, franchise insignia, real weapon trademarks, and no text baked in. The game draws every word and number.

What the UI draws today (survey, 2026-11-06): almost all of it is drawn in code. `icon_sheet.svg` holds 34 white line icons (placeholder), `hud_theme.tres` and `card_theme.tres` use flat StyleBoxes, and `banner_view.gd`, `synergy_glyphs.gd`, `strip_badge.gd`, `objective_tile.gd`, `killstreak_row.gd`, `hand_area.gd` and `board.gd` draw badges, plates, bands, ticks and glyphs with `draw_*` calls. The only bitmaps are the Killstreak-era paintings (`title_key_art`, `bg_run`, `bg_supply_drop`, `fx_callin_tablet`, 4 perk patches, 3 square lane backdrops, card art). This pack replaces the code drawing with images where an image looks better, and **keeps the code drawing as the fallback** for every slot.

## 0. Count


| Category | Images | P1 | P2 | P3 |
|---|---|---|---|---|
| Icons | 104 | 49 | 42 | 13 |
| Number plates | 8 | 7 | 1 | 0 |
| Standard Issue card art | 5 | 5 | 0 | 0 |
| Buttons and controls | 14 | 7 | 5 | 2 |
| Panels, trays, rings and strips | 26 | 12 | 13 | 1 |
| Backgrounds | 12 | 7 | 4 | 1 |
| Objective and Field tile backers | 4 | 2 | 2 | 0 |
| Card frame parts | 26 | 16 | 8 | 2 |
| Camo bands | 5 | 2 | 3 | 0 |
| Glows, outlines and overlays | 11 | 5 | 4 | 2 |
| **Total** | **215** | **112** | **82** | **21** |

## 1. How to use it (on the phone)

1. **One image per prompt, one chat per group.** Open a new ChatGPT chat for each group (the level-4 headings in section 4, for example "Keywords"). Inside a group, stay in the same chat so the icons or plates match each other. If ChatGPT asks a question, answer "just generate it".
2. **Shape.** Each entry says *Generate*: square (1024x1024), landscape (1536x1024) or portrait (1024x1536). If it comes back in another shape, reply "Same image, square 1:1" (or landscape 3:2 / portrait 2:3).
3. **Don't crop, key or resize on the phone.** Upload the full image. The Technical Artist trims, removes the background and resizes to the *Ship* size.
4. **Fix a bad result in the same chat:** "Regenerate, avoid: ..." and paste the entry's *Avoid* line. Two tries, then skip it and note it.
5. **Name the file** as the entry says (`ico_kw_pick.png`). If renaming is a pain on the phone, skip it and type the names in upload order in your message.
6. **Upload** in the **Studio Floor chat: "+ Images / logs"**, one batch at a time (section 5), with a line such as "kc-ui-art batch 3: ico_kw_first_shot, ico_kw_pick, ...". The Technical Artist commits them to `source/project-killingcard/assets/incoming/ui/` (raw, never imported), processes them and moves them to their final folder.

## 2. Style system

### 2.1 Look in one paragraph

A **tactical equipment** look: matte gunmetal and slate plates, thin steel rims with 45-degree chamfered corners, one soft top-left bevel highlight, a faint brushed grain and nothing else. No grunge, rust, scratches, stencil lettering or fake screws along edges. Colour comes only from the game's tokens: **side colours** (teal you, red rival), **amber** for "act now" (READY, primary buttons, ready killstreaks, cost), **brass** for the Operator, **trait colours** on trait pips, **green / red** for buffs and debuffs. Icons are **bold white pictograms** that the code tints, so one icon serves every state and both sides. Backgrounds are the same **duotone dusk paintings** as the Killstreak art (title, run map), kept dark and calm so cards and white text read on top.

Readability at phone size is the rule: a keyword pip is **22 px** (16 pt), an FP badge 28 px, a strip badge 62x64, a hand banner card 177x73 (kc-ui4). Every icon must read at **24 px**; plates must look right with their border at 2 to 3 logical px.

### 2.2 Colour tokens (from the current code: keep in sync)

| Token | Hex | Used for | Source |
|---|---|---|---|
| Slate (ink) | `#12161A` | Deepest background, recessed faces, text on amber | `fx_style.gd`, `card_theme.tres` background |
| Gunmetal | `#232A31` | Panels, tiles, button faces | `fx_style.gd`, `objective_tile.gd` |
| Panel / panel hi | `#232A31` / `#2E3740` | Raised panels, hover | `card_theme.tres` panel_hi |
| Steel | `#3A444D` | Rims and outlines | `banner_view.gd`, `objective_tile.gd` |
| Edge grey | `#4A535B` | Button and modal outlines | `hud_theme.tres` |
| Light steel | `#B9C2C9` | Armor badge rim, neutral marks, dashed EVEN | `banner_view.gd` |
| Fog white | `#D8DEE3` | Text, white icons | everywhere |
| Muted | `#7D8790` / `#9AA5AE` | Idle icons, captions | `killstreak_row.gd`, `match_screen.gd` |
| **You (friend)** | `#2EC4B6` (deep `#14524D`) | Your FP badge, spine, selection outline, control YOURS, link ticks | `card_theme.tres` friend |
| **Rival (enemy)** | `#E5383B` (deep `#5A1A1C`) | Rival FP diamond, spine, control RIVAL, INCOMING, danger | `card_theme.tres` enemy |
| **Amber** | `#FFB020` (pressed `#E59A12`) | READY, primary buttons, cost hex, ready glow, ghosts | `hud_theme.tres`, `card_theme.tres` accent |
| Damaged | `#F2A33A` | Armor badge when hurt | `banner_view.gd` |
| **Brass (Operator)** | `#C9A227`, dark `#5A4512` / `#3A2D0B` | Operator frame, dog tag, PLAN tag, supply plate, Elite | `banner_view.gd`, `hand_area.gd` |
| Cyan (special) | `#5BC0EB` | Killstreak charge, tech | `card_theme.tres` special |
| **Buff up** | `#7CF29A` | Raised FP / Cover number, synergy chips | `synergy_glyphs.gd` UP |
| **Debuff down** | `#FF6B6B` | Lowered number, set OFF | `synergy_glyphs.gd` DOWN |
| Heal | `#8EDB6A` | UNDEAD HEAL, heal numbers | `feedback_director.gd` |
| Trait Vanguard | `#F2B544` | Trait pip, rail chip | `synergy_glyphs.gd` |
| Trait Spec Ops | `#8FB8FF` | | |
| Trait Heavy | `#C9D1D8` | | |
| Trait Undead | `#8EDB6A` | | |
| Band Gilded | `#C9A227` / `#7A5E12` / `#F3D36B` | Trained level band, Operator gold tier | `synergy_glyphs.gd` BANDS |
| Band Forged | `#D9DEE3` / `#7E878F` / `#FFFFFF` | Veteran level band | |
| Band Priceless | `#3E8EDE` / `#1B3F78` / `#9FE3FF` | Elite level band | |
| Band Interstellar | `#7B3FC4` / `#1A0F3A` / `#FF7AD9` | Operator top tier only | `banner_view.gd` |
| Band base camo | `#4B5A3A` / `#2F3A25` / `#7A8A5A` | Operator base tier | `banner_view.gd` |

Rule: **tintable pieces are generated white or neutral**, and the code applies the token. Only pieces whose colour never changes (amber buttons, brass Operator, bands, side spines) have their colour baked in.

### 2.3 What is one image, and what is built from parts

| Thing on screen | Built from | Why |
|---|---|---|
| **Board banner** (4:1) | licensed / banner art + `frm_banner` (9-slice) + `frm_spine_you` or `_rival` + `plate_cost_s` + `plate_fp_s` + `plate_armor_s` (+ `plate_cover_s`) + 2-4 `frm_socket` with icons + `band_*` strip + `frm_front_tab` / `frm_plan_plate` + overlays (`fx_outline_*`, `fx_glow_amber`) | The banner is 228x57 to 512x128 and its numbers, pips and states change every beat. Baking any of it into one image would need hundreds of variants. |
| **Operator banner** | art + `frm_operator_banner` + `band_*` (camo tier) + `frm_dogtag_plate` + the same badges | The camo tier and brass frame change independently. |
| **Hand card** | art + `frm_hand_card` (9-slice, cost notch) + `plate_cost_s` + `frm_hand_name` + number plates + sockets + `band_*` | Same parts as the banner, so the hand reads as "the same card". |
| **Operator card / mini card** | art + `frm_operator_card` or `frm_operator_mini` + `frm_supply_plate` | |
| **Codex tile** | art + `frm_codex_tile` + `plate_cost_s` + optional `frm_equipped`, `ico_ui_lock` | |
| **Objective tile** | `tile_objective` + `ico_ctl_*` + 2 `tile_field_chip` + words (code) | |
| **Buttons** | one 9-slice plate per family + pressed plate + overlays; label is code text | |
| **Killstreak tile** | `pnl_ks_tile` + `ring_track` + `ring_fill` (radial progress) + `ico_ks_*` + `fx_glow_amber` | |
| **Order strip A > B > C** | `pnl_order_strip` + 3 `order_node` + 2 `order_arrow` + letters (code) + `ico_ui_check` | |
| One image | backgrounds, column backdrops, `frm_incoming`, card backs, camo bands (tiled) | Nothing on them changes. |

**9-slice pieces** (all margins in the manifest, at ship size): every `btn_*` (except `tgl_knob`), `pnl_tray`, `pnl_flyout`, `pnl_toast`, `pnl_inspector`, `pnl_tooltip`, `pnl_modal`, `pnl_header`, `pnl_hand_tab`, `pnl_counter`, `pnl_order_strip`, `pnl_rail_chip`, `pnl_callout`, `pnl_pick_tile`, `pnl_coach`, `pnl_result`, `tile_objective`, `tile_field_chip(_trap)`, `tile_slot_empty`, `frm_banner`, `frm_elite`, `frm_operator_banner`, `frm_operator_card`, `frm_operator_mini`, `frm_hand_card`, `frm_hand_name`, `frm_codex_tile`, `frm_spine_*`, `frm_front_tab`, `frm_plan_plate`, `frm_supply_plate`, `frm_band_edge`, `frm_ghost`, `fx_outline_*`, `fx_glow_*`. Bands **tile** horizontally instead.

### 2.4 Icons: one pipeline for all of them

- **Generate** every icon as a **solid white glyph on pure black**, 1024x1024. This is the most reliable thing ChatGPT does: no fake transparency, no checkerboard, no coloured fringes.
- **The TA turns brightness into alpha** (white = opaque, black = clear), so edges stay smooth, then trims to the glyph with 8% padding and ships a **256x256 master**, plus 128 / 64 / 48 / 32 exports or one atlas (section 7).
- **The code tints** (modulate): teal or red by side, amber when ready, trait colour when lit, `#7E8890` when idle, `#FF6B6B` / `#7CF29A` for trends. A dark 1-2 px outline for icons over bright licensed art is added in code (shadow or outline shader), not in the image.
- **Arrows that depend on the side** (Guard points behind, Spotter points ahead) stay code-drawn on top of the base icon, because the rival's banners are mirrored.
- On-screen sizes: keyword / trait / class pips 22 px phone, 26 px desktop; FP / Armor / Cover / cost number plates 22-32 px on cards, 48-52 px in the inspector (section 2.8); strip badge glyphs ~32 px; killstreak tiles 61 px (icon ~36 px in the ring); Codex filters 24 px; menu icons 28-36 px.

### 2.5 Transparent PNGs from ChatGPT

ChatGPT can return a real transparent PNG when asked, but sometimes it paints a grey-and-white checkerboard instead, or leaves a soft halo. So every prompt picks the safest background for its kind:

| Kind | Prompt asks for | TA does |
|---|---|---|
| Icons, rings, pips, nodes (`luma`) | white shape on **flat pure black** | brightness to alpha, then tint in code |
| Glows, outlines, flashes, tracers (`add`) | light on **flat pure black** | no alpha at all: `CanvasItemMaterial` blend mode **Add**; black disappears |
| Plates, frames, buttons, panels (`alpha`) | **transparent background**, and if that fails **flat magenta #FF00FF** | keep the alpha, or key out magenta (with 1-2 px despill) |
| Backgrounds, bands, card backs (`opaque`) | full-bleed image | crop and resize |

If an `alpha` image comes back with a checkerboard, reply: "The background must be real transparency. If you can't, use a perfectly flat solid magenta #FF00FF background instead, with no shadow." Magenta was chosen because no plate in the kit uses pink (the interstellar band is opaque).

### 2.6 States: how each one is made

ChatGPT cannot redraw the same plate five times identically, so states are built, not generated, except the pressed plates of the big buttons:

| State | How |
|---|---|
| normal | the image |
| hover (desktop) | code: modulate x1.10, or `fx_sheen` sweep on cards |
| pressed | the `_pressed` image where listed (primary, secondary, READY), else code: modulate x0.85 and 1-2 px down |
| disabled | code: desaturate, modulate `#8C8C8C`, alpha 0.6 |
| selected | `fx_outline_teal` on top (additive) |
| glow / ready | `fx_glow_amber` on top, alpha pulse 0.4 to 1.0 |
| side | tint (teal / red) for white pieces; separate images only for the spines and FP badges, which also differ in shape for colour-blind players |

### 2.7 The five style blocks (already inside every prompt)

Each prompt = **style block + subject + background tail**, already joined. There are five blocks (the fifth, Standard Issue art, is below the background block): icon (also used for the white parts: rings, pips, nodes), UI parts, light effects, and backgrounds. They are listed here so the set can be tuned in one place; if one changes, edit `ui-kit-pack-src/` and regenerate this file and the manifest: `cd documentation/art/ui-kit-pack-src && python3 -I gen.py . ../ui-kit-prompt-pack.md ../ui-kit-manifest.csv head.md style.md tail.md` (slots live in `slots.py`).

**Icon style** (all `ico_*`, plus the white `luma` parts)

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems.
```

Icon tail: `Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.`

**UI parts style** (buttons, panels, tiles, frames, bands)

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems.
```

Tails: transparent plates `Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset.` 9-slice plates add `Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size.` White parts: `Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background.`

**Light effects style** (all `add` glows, outlines, flashes, tracers)

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols.
```

Tail: `Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow.`

**Background style** (all `bg_*` and `col_*`)

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore.
```

**Standard Issue art style** (the 5 `kc_b_si_*` starter arts; rules tail included)

```
Original plain two-tone illustration for the basic starter cards of a modern military card game. One flat simple figure in olive drab #4B5320 and khaki #C3B091 against a muted grey-green #5E6B5A canvas or plain wooden supply-crate background. Flat shapes like a training-manual print, matte, low contrast, soft even light, no glow, no light effects, no dramatic lighting, only a faint canvas weave as texture. Deliberately modest and basic.
```

Tail: `Wide 3:2 landscape that will be cropped to a thin 4:1 strip across the middle (30% to 66% of the height) and a tall 2:3 column in the centre. Put the figure in the exact centre, head and hands between 30% and 65% of the height, inside the middle 60% of the width. The four corners of that strip stay empty, flat and calm, because the game puts the cost and name top left, abilities top right, the trait and weapon bottom left and the number plates bottom right. Above and below, continue the plain background. No text, letters, numbers, stencils, serial numbers, logos, insignia, flags, badges, patches or symbols on clothing, gear or crates. Invented people only, faces simple or shaded by the helmet. No blood.`

### 2.8 Card anatomy v3 (every banner form, both sides: board banner, hand banner card, Codex tile)

The head's rules: **the same icon for a concept everywhere, in the same corner on every card.** Since kc-trait-ui, one rule (`BannerView.anatomy()`) applies to both sides, with no mirroring. Stats are **number plates**: a plate in the concept's icon shape (a white image, tinted in code), with the number printed inside by the game.

```
 Board banner 4:1 (228x57 phone, 304x76 desktop, 512x128 inspector)
 /‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\
 |(COST) NAME (code text)                   [KW][KW][bolt] |   top-left: cost plate + name (Elite star between)
 |                                                         |   top-right: abilities, right-aligned from the corner
 |              art: middle 70% (focal zone)               |
 |                                                         |
 |[TRAIT][CLASS]                        (COV) (FP) (AR)    |   bottom-left: trait (Operator: dog tag) + weapon pip
 \_________________________________________________________/   bottom-right: FP + Armor plates, Cover left of them
   level camo band + side spine along the outer long edge

 Standard Issue card: the same corners, in frm_standard_issue
 /‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\
 |(COST) GRUNT (stencil-style code text)        [SI-01]    |   top-right: serial plate (no abilities)
 |            plain olive two-tone figure                  |
 |[ - - ][ - - ]                             (FP) (AR)     |   bottom-left: empty dashed sockets (no trait, no class)
 \_________________________________________________________/   no camo band, no foil

 Hand banner card (177x73 phone, 224x64 desktop, 103x78 on 16:9): the same corners, smaller
```

| Corner | What | Part | Phone banner | Desktop banner | Hand card | Inspector / tiles |
|---|---|---|---|---|---|---|
| Top-left | Cost (Supply), then the NAME (code text; long names shrink to 13 px, then end in "…") | `plate_cost_s` / `_l` in the frame's hexagon notch | 22 px | 26 px | 26 px | 48 px (`_l`) |
| Top-right | Abilities: printed keyword, neighbour keyword (arrow drawn by code), the bolt for effect text; locked ones greyed with `frm_socket_locked`; Standard Issue: `frm_serial_plate` | `ico_kw_*`, `ico_effect_bolt` in `frm_socket`, 2 px gaps, right-aligned | 22 px each | 26 px | 22 px | 40 px |
| Bottom-left | Trait (Operator: dog tag) + weapon-type pip; empty: `frm_socket_empty` | `ico_trait_*`, `ico_class_*` in `frm_socket` (lit at tier 2, `fx_ring_tier3` at tier 3) | 22 px | 26 px | 22 px | 40 px |
| Bottom-right | Cover (only when above 0), Firepower, Armor, side by side, Armor outermost | `plate_cover_s`, `plate_fp_s`, `plate_armor_s` | 26 px | 32 px | 28 px | 52 px (`_l`) |
| Outer long edge | Level camo band, side spine (not on Standard Issue cards) | `band_*`, `frm_spine_*` | 3 px / 2 px | 4 px / 3 px | band only | 6 px |

Rules that keep the parts lined up:
- **The frames leave these corners free:** `frm_banner`, `frm_standard_issue`, `frm_hand_card` and `frm_codex_tile` all have the hexagon notch top-left and calm, plain corners elsewhere. Their 9-slice margins (manifest) are at least as large as the cost plate.
- **Art safe zones:** all four corners of the 4:1 band stay calm (about 30% of the width by 40% of the height at each end), which is stricter than the banner pack's 15% side zones. A 35% dark gradient scrim under the top and bottom rows (the existing safety net) keeps plates readable on bright licensed art.
- **One silhouette per concept:**
  - FP is the broken gun-sight ring (`ico_stat_firepower` matches `plate_fp`).
  - Armor is the armor plate (`ico_stat_armor` matches `plate_armor`).
  - Cover is the barrier block.
  - Cost and Supply are the hexagon (the cost plate, Supply pips and the Supply row). The crate icon `ico_stat_supply` (batch 1) becomes the Supply Drop and reward icon.
  - Guard is a block wall and Spotter is binoculars, so no keyword reuses the shield (Armor) or the eye (PREVIEW).
- **Side colours are tints, not shapes:** your plates are teal and the rival's are red. The colour-blind cue is the spine (square notches for you, diamond notches for the rival) and the half of the board the card is on.
- **Standard Issue reads as basic kit:** olive two-tone art, a grey-green painted frame, a serial plate, empty dashed trait and class sockets, no band, no glow and no animation. The first calling card (art, banner frame, lit trait) should look clearly better next to it.

## 3. Size key

| Kind | Generate | Ship to the TA | In game |
|---|---|---|---|
| Icon | 1024x1024 square | 256x256 master, trimmed + 8% padding; exports 128/64/48/32 | 22-64 px |
| Standard Issue card art (`kc_b_si_*`) | 1536x1024 | 1152x768 master (banner pipeline, `banner-art-direction.md` 3.2) | banners and hand cards |
| Number plate (`plate_*`) | 1024x1024 | `_s` 128x128 (22-34 px on screen), `_l` 256x256 (48-128 px); rim + flood-filled `_fill` | 22-128 px |
| Small part (socket, pip, knob) | 1024x1024 | 64-128 px (manifest) | 22-61 px |
| Plate / panel / button (9-slice) | 1536x1024 or 1024x1536 | 2x the largest on-screen size, borders 4-6 px at ship size (manifest) | drawn at 0.5x scale (see 7.4) |
| Banner frame parts (4:1) | 1536x1024; TA crops a 4:1 band | 512x128 (2x desktop, 2.25x phone) | 228x57 / 304x76 / 512x128 |
| Hand banner card frame | 1536x1024 | 448x184 | 177x73 phone, 224x64 desktop, 103x78 16:9 |
| Operator / Codex frames | 1024x1536 | 256x320 / 240x312 | 99x124 / 120x156 |
| Camo band | 1024x1024 swatch | 512x512 + a 512x32 seamless strip | 3-6 px band, Operator badge swatch |
| Full-screen background | 1536x1024 | 1536x864 (crop 80 px top and bottom); the phone shows the middle 1536x710 | 1168x540 phone, 1280x800 desktop |
| Column backdrop | 1024x1536 | crop the middle 648x1536, resize to 512x1216 | 228x537 at 34% opacity |


## 4. Prompts

**Since batch 1** (Technical Artist feedback, `ui-kit-import-log.md`): every icon and number-plate prompt now asks for strokes and gaps of at least 1/10 of the canvas, no detail smaller than 1/8, and a compact, roughly square silhouette. Keywords stay off circles and reticles: Guard is a block wall, Spotter binoculars, Overwatch a visor slit. The 10 batch-1 icons were made with the older 1/12 wording and are accepted as they are.

Every grey box is complete: copy it as is. Entries are grouped the way they should be generated: **one ChatGPT chat per group** (heading level 4), so the set shares a look. After the first image in a group, you can shorten the next ones to "Same style, next one: <the part after 'Draw exactly one icon:'>", but if the style drifts, paste the full box again.

### 4.1 Icons (104)

#### Stats and resources (19)

##### 1. `ico_stat_firepower.png` · P1

- **Used in:** FP badge on every banner, hand card, inspector, Operator flyout, ghosts.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a gun-sight reticle: a thick circle broken by four short gaps at top, bottom, left and right, with a solid dot in the centre. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 2. `ico_stat_armor.png` · P1

- **Used in:** Armor badge on every banner and hand card (amber when damaged, by tint).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a plain armor plate: a tall rounded-bottom plate shape with a thick rim and a smaller solid inner plate, the face completely empty. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, crest, emblem, cross, star or any mark on the plate.

##### 3. `ico_stat_cover.png` · P1

- **Used in:** Cover chip left of the Armor badge; Cover-absorbed hit (-0); Field auras.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a low concrete road barrier block seen from the front (wide trapezoid base, flat top), with one short curved arc bouncing off its top edge. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 4. `ico_stat_supply.png` · P1

- **Used in:** Supply row in the tray (SUPPLY 3/4), Operator '1 SUPPLY' plate, cost tooltips.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a squat supply crate seen straight on, with one strap across the middle and a small solid triangle pointing up above it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 5. `ico_stat_deck.png` · P1

- **Used in:** DECK badge (strip bottom), deck view button on run map and rewards.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: three playing-card rectangles stacked with a small diagonal offset, the top card plain. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 6. `ico_stat_discard.png` · P2

- **Used in:** Used / discard count in the DECK flyout.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: two playing-card rectangles fanned apart with a curved arrow running underneath them from right to left. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 7. `ico_stat_hand.png` · P2

- **Used in:** HAND · n PEEK tab, hand cap in the score sheet.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: three playing-card rectangles held in a tight fan, spreading upward from one corner. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 8. `ico_stat_intel.png` · P1

- **Used in:** RIVAL badge, red-dot reveal, Recon tooltips, intel lines in flyouts.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Note:** Replaces intel_contact in the old sheet (keep the id alias).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a radar sweep: a quarter-circle wedge with two thin concentric arcs inside it and one solid dot near the outer arc. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 9. `ico_range_close.png` · P3

- **Used in:** Range word chip on the objective tile, class tooltips.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: one thick chevron pointing right next to a short vertical post. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 10. `ico_range_mid.png` · P3

- **Used in:** Range chip on the objective tile.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: two thick chevrons pointing right next to a short vertical post. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 11. `ico_range_long.png` · P3

- **Used in:** Range chip on the objective tile.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: three thick chevrons pointing right next to a short vertical post. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 12. `ico_streak.png` · P1

- **Used in:** STREAK badge, streak meter in the flyout, after-action BEST STREAK.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a rising zig-zag line of three steps that ends in a solid arrowhead pointing up and to the right. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 13. `ico_eliminated.png` · P2

- **Used in:** Killfeed toast and log, after-action ELIMINATIONS, elimination stamp.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a minimal stylised skull seen from the front: rounded cranium, two hollow eye shapes, a short row of square teeth; no crossbones, no helmet, no wings. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, crossbones, bones, a helmet, wings, flames, any badge or emblem shape around it.

##### 14. `ico_tickets.png` · P2

- **Used in:** REINFORCEMENT TICKETS on the run map, run end.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a ticket stub with a perforated edge down one side and a round notch cut out of each end. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 15. `ico_round.png` · P3

- **Used in:** Round counter in the SCORE badge flyout and the pause header.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a stopwatch: a circle with a small button on top and a single hand pointing to one o'clock. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 16. `ico_fired.png` · P2

- **Used in:** Fired pip on each banner that has shot this round (cleared at Score).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Note:** NEW: the fired pip is a firefight-order.md UI need, not built yet.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a single spent rifle cartridge case lying on its side, open end to the right, no bullet in it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 17. `ico_heal.png` · P2

- **Used in:** Heal number (+n) from Patch, Aid Station and Undead (tinted teal or green, never red).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a plus sign made of two thick bars with rounded ends, centred inside a thin rounded square outline. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a red cross, a red crescent, any medical emblem; the icon is pure white and is tinted green in game.

##### 18. `ico_damage.png` · P2

- **Used in:** Hit marker beside damage numbers, killfeed, now-firing tracer end.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: an impact burst: a small solid centre with four sharp triangular shards flying outward diagonally. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 19. `ico_score.png` · P1

- **Used in:** SCORE badge, score sheet, after-action SCORE.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a triangular pennant on a short vertical pole planted in a flat base line, the pennant plain with no pattern. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, any national flag pattern, stripes, stars, emblem on the pennant.

#### Keywords (17)

##### 20. `ico_kw_first_shot.png` · P1

- **Used in:** Banner effect slot, hand card, inspector, FIRST SHOT tag in the Firefight.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a single bullet flying to the right, pointed tip, with three straight horizontal speed lines trailing behind it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 21. `ico_kw_pick.png` · P1

- **Used in:** Banner effect slot, Pick tracer tag, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a sniper scope view: a thick circle with a thin cross inside it, and a small solid square bracket around one point in the lower right quadrant. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 22. `ico_kw_flank.png` · P1

- **Used in:** Banner effect slot, Flank tracer tag, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a thick curved arrow that leaves from the left, swings around the top of a small solid square, and hooks down into the right side. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 23. `ico_kw_pierce.png` · P1

- **Used in:** Banner effect slot on Marksman and Ace, '-1 PIERCE' second number, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a straight arrow pointing down that passes through the middle of a thick chevron (the chevron opens downward), the arrow shaft visible above and below it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 24. `ico_kw_suppress.png` · P1

- **Used in:** Banner effect slot (Gunner), suppressed status, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: three short parallel diagonal tracer lines coming down from the upper left onto a thick horizontal bar, pressing it down. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 25. `ico_kw_patch.png` · P1

- **Used in:** Banner effect slot (Combat Medic), heal tag, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a field bandage roll seen from the side with a strip unrolling from it in a loose curl. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a cross, plus sign or any medical emblem on the bandage.

##### 26. `ico_kw_holder.png` · P2

- **Used in:** Banner effect slot, control tooltip (counts for holding the column).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a solid triangular marker pennant on a short post driven into a flat ground line, with a small arc of ground around the base. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, national flag patterns, emblems on the pennant.

##### 27. `ico_kw_protector.png` · P1

- **Used in:** Banner effect slot, TAKES THE FRONT preview, Protector slide.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a tall solid riot-shield shape with a small rectangular viewport slot, standing in front of a smaller rounded helmet outline that is half hidden behind it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 28. `ico_kw_hidden.png` · P2

- **Used in:** Hidden Field traps (Tripwire), hide-from-intel effects, dashed TRAP chip.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: an almond eye shape with its lid half closed and one thick diagonal slash across it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 29. `ico_kw_guard.png` · P1

- **Used in:** Keyword pip on Trained banners and hand cards, link preview, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Note:** Neighbour-link arrows (Guard down, Spotter up) are drawn by the code so they can flip for the rival; the icon is only the base shape. Not a shield: the shield shape is Armor.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a short solid wall made of two rows of thick rectangular blocks, two blocks in the bottom row and one centred block on top, compact and square. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, an arrow (the game adds it), a shield shape, a circle.

##### 30. `ico_kw_spotter.png` · P1

- **Used in:** Keyword pip, link preview, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Note:** Neighbour-link arrows (Guard down, Spotter up) are drawn by the code so they can flip for the rival; the icon is only the base shape. Not an eye: the eye is the PREVIEW toggle.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a pair of binoculars seen from the front, drawn as two thick upright rectangular barrels side by side joined by a short solid bridge, compact and square. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, an arrow (the game adds it), an eye, round lenses or circles.

##### 31. `ico_kw_fireteam.png` · P1

- **Used in:** Keyword pip, link preview, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: two thick open chevrons pointing away from each other, one pointing left and one pointing right, with a small gap between them. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 32. `ico_kw_overwatch.png` · P1

- **Used in:** Keyword pip, link preview, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a short thick horizontal bar like a visor slit with a solid square in its middle, and one solid triangular arrowhead on each side pointing outward left and right, compact. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a circle, a ring, a reticle or crosshair.

##### 33. `ico_trig_on_deploy.png` · P2

- **Used in:** 'On deploy' effect line and banner effect slot.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a solid downward arrow landing on a flat bar, with two short impact lines on each side of the bar. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 34. `ico_trig_on_down.png` · P2

- **Used in:** 'On down' effect line and banner effect slot.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a playing-card rectangle tipping over to the right with a small motion arc beside it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 35. `ico_effect_bolt.png` · P1

- **Used in:** Banner effect slot for triggered or aura text (with a dot if more), Field auras.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a bold lightning bolt with three straight segments, thick and angular. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 36. `ico_kw_aura.png` · P2

- **Used in:** Field aura marker on banners in a Field's column, objective tile chip.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a small solid square with four short thick bars radiating from its four sides, like a signal spreading outward. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, circles, rings, a reticle.

#### Traits (4)

##### 37. `ico_trait_vanguard.png` · P1

- **Used in:** Trait pip on banners and hand cards, trait rail, SETS flyout, Doctrine tiles, deck view.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: two thick stacked upward chevrons, one above the other, like a rank stripe pointing up. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a rank insignia layout, stars, laurels.

##### 38. `ico_trait_specops.png` · P1

- **Used in:** Trait pip, rail, flyout, Doctrine, deck view.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a face mask seen from the front: a wide band shape with two narrow rectangular eye slits cut out of it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a skull, a face, any emblem.

##### 39. `ico_trait_heavy.png` · P1

- **Used in:** Trait pip, rail, flyout, Doctrine, deck view.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a heavy machine gear: a thick ring with eight short square teeth around it and a solid hub in the centre. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 40. `ico_trait_undead.png` · P1

- **Used in:** Trait pip, rail, flyout, Doctrine, deck view, UNDEAD HEAL tag.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a bony hand with four fingers reaching up out of a flat ground line, only the hand and wrist visible. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, blood, rot, a skull, gore.

#### Card types and card marks (8)

##### 41. `ico_type_unit.png` · P1

- **Used in:** Hand card type glyph, Codex UNITS filter, inspector type line.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: the head-and-shoulders silhouette of a soldier in a rounded helmet seen from the front, no face details. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 42. `ico_type_tactic.png` · P1

- **Used in:** Hand card type glyph, Codex TACTICS filter, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a tactical plan: a curved dashed arrow from a small circle to a small X. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 43. `ico_type_field.png` · P1

- **Used in:** Hand card type glyph, Codex FIELDS filter, objective Field chips.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Note:** Was type_equipment in the old sheet (keep the id alias).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a small fortified position: a low sandbag wall arc of four rounded bags with a short pole standing behind it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 44. `ico_type_killstreak.png` · P2

- **Used in:** Codex KILLSTREAKS filter, killstreak inspector, run rewards.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a chevron-shaped aircraft silhouette seen from above with two short contrails behind it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real aircraft shape, roundels, markings.

##### 45. `ico_type_operator.png` · P2

- **Used in:** Operator plate, Operator flyout header, OPERATOR badge (with the camo swatch).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a single military dog tag with rounded corners, a hole near the top and a short ball chain looping from it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, engraved letters or numbers on the tag.

##### 46. `ico_elite_star.png` · P2

- **Used in:** Elite chassis mark on banners, hand cards and Codex tiles (Ace, Commander).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a bold five-pointed star with slightly rounded points. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a circle or badge around the star, wreaths.

##### 47. `ico_trap.png` · P2

- **Used in:** Hidden Field (trap) chip on the objective tile, dashed.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a tripwire: a thin taut line between two short stakes with a small solid box charge clipped to the middle. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 48. `ico_plan_mark.png` · P2

- **Used in:** PLAN / INCOMING marker, rival planned-per-column intel.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a small face-down card rectangle with a solid dot in its centre and a short down arrow above it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### Weapon classes (6)

##### 49. `ico_class_ar.png` · P1

- **Used in:** Class pip on banners (outer-left), Codex AR filter, range bonus tooltip.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: side-profile silhouette of a generic compact assault rifle pointing right: straight magazine, short rail on top, folding stock. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real gun model or brand, engravings, markings, a scope brand.

##### 50. `ico_class_smg.png` · P1

- **Used in:** Class pip, Codex SMG filter.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: side-profile silhouette of a short boxy submachine gun pointing right, long straight magazine, stubby barrel, small stock. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real gun model or brand, engravings, markings, a scope brand.

##### 51. `ico_class_shotgun.png` · P1

- **Used in:** Class pip, Codex SHOTGUN filter.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: side-profile silhouette of a pump shotgun pointing right, long tube under the barrel, a ridged pump grip, solid stock. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real gun model or brand, engravings, markings, a scope brand.

##### 52. `ico_class_sniper.png` · P1

- **Used in:** Class pip, Codex SNIPER filter.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: side-profile silhouette of a long bolt-action rifle pointing right with a long scope on top and a folded bipod under the barrel. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real gun model or brand, engravings, markings, a scope brand.

##### 53. `ico_class_lmg.png` · P1

- **Used in:** Class pip, Codex LMG filter.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: side-profile silhouette of a heavy belt-fed machine gun pointing right, a box under the middle, a carry handle on top, bipod folded forward. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real gun model or brand, engravings, markings, a scope brand.

##### 54. `ico_class_sidearm.png` · P2

- **Used in:** STREAK flyout P-12 tile, Loadout secondary slot, Operator secondary.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Note:** Not a card class in data (WeaponClass has 5). The 6th class icon is for the Operator's secondary.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: side-profile silhouette of a plain compact pistol pointing right. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real gun model or brand, engravings, markings, a scope brand.

#### Killstreaks and Operator equipment (12)

##### 55. `ico_ks_recon_drone.png` · P1

- **Used in:** Killstreak tile in the tray (charge ring), STREAK flyout, Codex, call-in.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** charging grey / ready amber / used dim (tint) + ring.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a small quadcopter drone seen from the front, four rotor discs, with a downward cone of three short lines under it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real drone, helicopter or aircraft model, roundels, markings, numbers.

##### 56. `ico_ks_mortar.png` · P1

- **Used in:** Killstreak tile (Mortar Barrage), flyout, Codex.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** charging / ready / used (tint) + ring.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: three falling mortar shells in a row, nose down, each with a short curved trail above it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real drone, helicopter or aircraft model, roundels, markings, numbers.

##### 57. `ico_ks_attack_helo.png` · P1

- **Used in:** Killstreak tile (Attack Helo), flyout, Codex.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** charging / ready / used (tint) + ring.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: side-profile silhouette of a fictional slim attack helicopter flying right, one main rotor line on top, a stub wing, a nose turret. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real drone, helicopter or aircraft model, roundels, markings, numbers.

##### 58. `ico_ks_sentry.png` · P1

- **Used in:** Killstreak tile (Sentry Turret), flyout, Codex, Sentry token gear mark.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** charging / ready / used (tint) + ring.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a compact automated gun turret on a tripod, a boxy head with one short barrel pointing right. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real drone, helicopter or aircraft model, roundels, markings, numbers.

##### 59. `ico_ks_gunship.png` · P3

- **Used in:** Gunship card (Codex, rewards), reserved killstreak tile.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: side-profile silhouette of a fictional heavy four-engine propeller plane flying right with a side gun barrel under the wing. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real drone, helicopter or aircraft model, roundels, markings, numbers.

##### 60. `ico_eq_frag.png` · P2

- **Used in:** STREAK flyout FRAG tile (Lethal), Loadout lethal slot, cooldown.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** ready / cooldown dim (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a round fragmentation grenade with a lever on its side and a pull ring on top, no pattern on the body. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 61. `ico_eq_flash.png` · P2

- **Used in:** STREAK flyout FLASH tile (Tactical), Loadout tactical slot, cooldown.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** ready / cooldown dim (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a short cylindrical stun grenade with a lever and ring, three short burst lines radiating from its top. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 62. `ico_att_optic.png` · P3

- **Used in:** Loadout attachment (Holo Sight), Weapon Level reward.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a small open holographic gun sight seen from the side: a rectangular window frame on a short base, a dot inside the window. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 63. `ico_att_grip.png` · P3

- **Used in:** Loadout attachment (Foregrip), Weapon Level reward.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a vertical gun foregrip seen from the side: a ridged handle hanging from a short rail section. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 64. `ico_att_mag.png` · P3

- **Used in:** Loadout attachment (Extended Mag), Weapon Level reward.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a long curved rifle magazine seen from the side, slightly longer than normal, with a small base plate. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 65. `ico_att_lining.png` · P3

- **Used in:** Loadout attachment (Ceramic Lining), Weapon Level reward.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a hexagonal ceramic tile pattern of seven small hexagons forming a plate. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 66. `ico_perk_slot.png` · P3

- **Used in:** Loadout perk slot, Perk Offer reward header (the perks keep their painted patches).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a round stitched patch outline with a small four-pointed spark in the middle. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### Objective, control and Field (6)

##### 67. `ico_ctl_yours.png` · P1

- **Used in:** Objective tile control mark (YOURS), minimap, score sheet; tinted teal.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (tint teal).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a thick solid ring with a solid dot in the centre. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 68. `ico_ctl_rival.png` · P1

- **Used in:** Objective tile control mark (RIVAL); tinted red. Shape cue for colour-blind players.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (tint red).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a solid diamond with a small notch cut into each of its four corners. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 69. `ico_ctl_even.png` · P1

- **Used in:** Objective tile control mark (EVEN, was CONTESTED).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (tint grey).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a square drawn as a thick dashed outline, eight dashes, empty inside. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 70. `ico_ctl_open.png` · P2

- **Used in:** Objective tile control mark (OPEN: nobody there).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (tint grey).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a thin plain circle outline, empty, with four tiny ticks pointing inward. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 71. `ico_overrun.png` · P1

- **Used in:** FIELD OVERRUN callout, overrun risk on the Field chip, OVERRUN tag.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / warning pulse (tint red).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a low sandbag wall broken in the middle with two thick arrows crashing through the gap from above. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 72. `ico_field_slot.png` · P2

- **Used in:** Empty Field slot on the objective tile (your half), placement hint.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a dashed rounded rectangle with a small plus sign in the centre. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### Phases, firefight and run modes (8)

##### 73. `ico_ph_deploy.png` · P2

- **Used in:** Phase header (DEPLOY), tutorial coach, score sheet.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a playing-card rectangle sliding down into a slot, a short down arrow above it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 74. `ico_ph_reveal.png` · P2

- **Used in:** Phase header (REVEAL).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a playing-card rectangle turning over, half of it shown as a thin edge, with two short spark lines. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 75. `ico_ph_firefight.png` · P2

- **Used in:** Phase header (FIREFIGHT), order strip, tray step header.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: two short bullets pointing at each other from left and right with a small burst between them. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 76. `ico_ph_score.png` · P2

- **Used in:** Phase header (SCORE & STREAK).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a pennant on a pole next to a short rising stepped line. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 77. `ico_mode_zone_control.png` · P2

- **Used in:** Run map mode chip (Zone Control), match intro.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: three small circles in a row joined by a line, the middle one solid. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 78. `ico_mode_firefight.png` · P2

- **Used in:** Run map mode chip (Firefight).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: two crossed straight tracer lines with a small dot where they cross. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, crossed rifles, crossed swords, a badge.

##### 79. `ico_mode_detonator.png` · P2

- **Used in:** Run map mode chip (Detonator).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a small explosive charge block with a short antenna and a curled wire. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, numbers on a timer, text.

##### 80. `ico_mode_rival.png` · P2

- **Used in:** Run map RIVAL (boss) match, rival squad header.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a helmeted head silhouette in profile facing left with a small notched diamond beside it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### Menu and system (24)

##### 81. `ico_ui_menu.png` · P1

- **Used in:** MENU badge (strip top), title.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / pressed (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: three thick horizontal bars of equal length stacked with equal gaps. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 82. `ico_ui_settings.png` · P2

- **Used in:** Settings row in the pause menu, title.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a simple cog wheel with six rounded teeth and a round hole in the middle. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 83. `ico_ui_undo.png` · P1

- **Used in:** UNDO button in the tray (Deploy).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / disabled (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a thick curved arrow that loops back to the left, like a U-turn pointing left. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 84. `ico_ui_speed.png` · P1

- **Used in:** SPEED x2 button in the tray (Firefight), settings.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** off / on amber (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: two solid triangles pointing right, touching tip to base, like fast-forward. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 85. `ico_ui_skip.png` · P2

- **Used in:** Skip the round playback, skip reward.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a solid triangle pointing right followed by a thick vertical bar. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 86. `ico_ui_codex.png` · P2

- **Used in:** CODEX buttons on the title and pause menu, Codex header.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: an open binder with three card rectangles fanned out of it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 87. `ico_ui_mirror.png` · P2

- **Used in:** MIRROR LAYOUT setting.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: two half-rectangles facing each other across a dashed vertical line, with a small two-way arrow on top. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 88. `ico_ui_sound_on.png` · P2

- **Used in:** Sound setting ON.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Note:** NEW: there is no sound setting yet.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a speaker cone shape with two curved sound waves on its right. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 89. `ico_ui_sound_off.png` · P2

- **Used in:** Sound setting OFF.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Note:** NEW: there is no sound setting yet.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a speaker cone shape with a small X on its right. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 90. `ico_ui_close.png` · P1

- **Used in:** CLOSE on the inspector, flyouts, Codex, modals.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a thick X with squared ends. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 91. `ico_ui_back.png` · P1

- **Used in:** BACK on Codex, Loadout, Retire picker.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a thick chevron pointing left with a short horizontal tail. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 92. `ico_ui_info.png` · P2

- **Used in:** Long-press hint, rules buttons, tooltips header.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a solid circle with a cut-out tall bar and a cut-out dot above it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 93. `ico_ui_eye.png` · P1

- **Used in:** PREVIEW badge ON.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** on (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: an open almond eye with a solid round pupil. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 94. `ico_ui_eye_off.png` · P1

- **Used in:** PREVIEW badge OFF.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** off (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: an open almond eye outline with one thick diagonal slash across it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 95. `ico_ui_filter.png` · P2

- **Used in:** Codex filter bar, CLEAR FILTERS.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a funnel shape made of three horizontal bars getting shorter downward. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 96. `ico_ui_check.png` · P1

- **Used in:** Picked / ticked states, order strip finished column, PICKED tiles.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a thick tick mark with squared ends. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 97. `ico_ui_lock.png` · P1

- **Used in:** Locked keyword pip badge (frm_socket_locked), locked Codex art, NOT FOUND YET.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a closed padlock with a round shackle and a keyhole. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 98. `ico_ui_continue.png` · P2

- **Used in:** CONTINUE, BEGIN RUN, DEPLOY on the run map, NEXT.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a thick chevron pointing right with a short horizontal tail. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 99. `ico_ui_retire.png` · P2

- **Used in:** RETIRE tile on Supply Drop, Retire picker, Honor Roll.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a playing-card rectangle sliding out to the right with a small curved arrow, a faint outline left behind. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 100. `ico_ui_promote.png` · P2

- **Used in:** PROMOTION reward, level-up band strip.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a playing-card rectangle with one thick upward chevron above it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 101. `ico_ui_reward.png` · P2

- **Used in:** SUPPLY DROP header, reward tiles, after-action REWARD.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a supply crate hanging from a small parachute canopy by three lines. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 102. `ico_ui_rotate.png` · P3

- **Used in:** Rotate-your-phone notice (web shell), Operator Rotate action.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a phone rectangle with a curved arrow going around one corner. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 103. `ico_ui_survey.png` · P3

- **Used in:** PLAYTEST SURVEY button at run end.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a clipboard with three short lines and a tick on the top line. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

##### 104. `ico_ui_tutorial.png` · P3

- **Used in:** TUTORIAL row on the title.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a whistle seen from the side with a short cord loop. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

### 4.2 Number plates (8)

#### Number plates (the game prints the number inside) (8)

##### 105. `plate_fp_s.png` · P1

- **Used in:** Firepower number plate, bottom right of every card, left of Armor (small: 22-34 px: board banners, hand banner cards, Codex tiles).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x128. **Background:** white on black: TA converts brightness to alpha.
- **States:** you (rim teal, fill #14524D) / rival (rim red, fill #5A1A1C) / buffed (number green + up marker) / lowered (red + down marker).
- **Note:** One shape per concept everywhere: the plate is the same silhouette as the concept's icon. TA: the rim ships as `plate_<x>_<s|l>.png`; a filled copy (`_fill`) is made by flood-filling the inside, so the code can draw a dark tinted fill under the number and a bright tinted rim on top.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one number plate (the game prints the number inside it later): a firepower number plate shaped like a gun-sight ring: a very thick rim, about one sixth of the plate width, broken by four short square gaps at top, bottom, left and right, the centre completely empty and large enough for a two-digit number (at least 55% of the plate width). No number, letter or mark inside it. Thick strokes and gaps, no detail smaller than one eighth of the canvas. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black, a centre dot, a cross, any number, a second ring.

##### 106. `plate_armor_s.png` · P1

- **Used in:** Armor number plate, bottom right of every card, right of FP (small: 22-34 px: board banners, hand banner cards, Codex tiles).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x128. **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (rim light steel, fill #2E3439) / damaged (rim amber #F2A33A, fill #4A3412) / healed (flash).
- **Note:** One shape per concept everywhere: the plate is the same silhouette as the concept's icon. TA: the rim ships as `plate_<x>_<s|l>.png`; a filled copy (`_fill`) is made by flood-filling the inside, so the code can draw a dark tinted fill under the number and a bright tinted rim on top.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one number plate (the game prints the number inside it later): an armor number plate: a plate shape with a flat top and sides tapering to a rounded point at the bottom, drawn as a very thick rim, about one sixth of the plate width, the inside completely empty and large enough for a two-digit number (at least 55% of the plate width), roughly as wide as it is tall. No number, letter or mark inside it. Thick strokes and gaps, no detail smaller than one eighth of the canvas. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black, a cross, a crest, a star, any mark or number inside.

##### 107. `plate_cost_s.png` · P1

- **Used in:** Cost plate, top left of every card (small: 22-34 px: board banners, hand banner cards, Codex tiles); the hexagon is the Supply shape everywhere (pips, Supply row).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x128. **Background:** white on black: TA converts brightness to alpha.
- **States:** affordable (fill amber #FFB020, number slate) / can't pay (fill grey, rim red) / Operator (frm_supply_plate instead).
- **Note:** One shape per concept everywhere: the plate is the same silhouette as the concept's icon. TA: the rim ships as `plate_<x>_<s|l>.png`; a filled copy (`_fill`) is made by flood-filling the inside, so the code can draw a dark tinted fill under the number and a bright tinted rim on top. Replaces frm_cost_hex (which baked the amber in).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one number plate (the game prints the number inside it later): a cost number plate: an upright hexagon drawn as a very thick rim, about one sixth of the plate width, the inside completely empty and large enough for a two-digit number. No number, letter or mark inside it. Thick strokes and gaps, no detail smaller than one eighth of the canvas. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black, a number, a crate, a second hexagon.

##### 108. `plate_cover_s.png` · P1

- **Used in:** Cover number plate, bottom right, left of FP, only when Cover > 0 (small: 22-34 px: board banners, hand banner cards, Codex tiles).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x128. **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (rim light steel) / buffed (rim green #7CF29A).
- **Note:** One shape per concept everywhere: the plate is the same silhouette as the concept's icon. TA: the rim ships as `plate_<x>_<s|l>.png`; a filled copy (`_fill`) is made by flood-filling the inside, so the code can draw a dark tinted fill under the number and a bright tinted rim on top. Optional: Cover can stay a small icon chip if the bottom-right corner gets crowded on the 57 px phone banner.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one number plate (the game prints the number inside it later): a cover number plate shaped like a low concrete barrier block seen from the front: a wide trapezoid, wider at the bottom with a flat top, drawn as a very thick rim, about one sixth of the plate width, the inside completely empty and large enough for a one-digit number, compact (no wider than one and a half times its height). No number, letter or mark inside it. Thick strokes and gaps, no detail smaller than one eighth of the canvas. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black, a number, an arc or arrow, cracks.

##### 109. `plate_fp_l.png` · P1

- **Used in:** Firepower number plate, bottom right of every card, left of Armor (large: 48-128 px: inspector, reward and pick tiles, Operator flyout, After-Action).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256. **Background:** white on black: TA converts brightness to alpha.
- **States:** you (rim teal, fill #14524D) / rival (rim red, fill #5A1A1C) / buffed (number green + up marker) / lowered (red + down marker).
- **Note:** One shape per concept everywhere: the plate is the same silhouette as the concept's icon. TA: the rim ships as `plate_<x>_<s|l>.png`; a filled copy (`_fill`) is made by flood-filling the inside, so the code can draw a dark tinted fill under the number and a bright tinted rim on top.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one number plate (the game prints the number inside it later): a firepower number plate shaped like a gun-sight ring: a thick rim, about one tenth of the plate width, with one thin inner line just inside it, broken by four short square gaps at top, bottom, left and right, the centre completely empty and large enough for a two-digit number (at least 55% of the plate width). No number, letter or mark inside it. Thick strokes and gaps, no detail smaller than one eighth of the canvas. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black, a centre dot, a cross, any number, a second ring.

##### 110. `plate_armor_l.png` · P1

- **Used in:** Armor number plate, bottom right of every card, right of FP (large: 48-128 px: inspector, reward and pick tiles, Operator flyout, After-Action).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256. **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (rim light steel, fill #2E3439) / damaged (rim amber #F2A33A, fill #4A3412) / healed (flash).
- **Note:** One shape per concept everywhere: the plate is the same silhouette as the concept's icon. TA: the rim ships as `plate_<x>_<s|l>.png`; a filled copy (`_fill`) is made by flood-filling the inside, so the code can draw a dark tinted fill under the number and a bright tinted rim on top.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one number plate (the game prints the number inside it later): an armor number plate: a plate shape with a flat top and sides tapering to a rounded point at the bottom, drawn as a thick rim, about one tenth of the plate width, with one thin inner line just inside it, the inside completely empty and large enough for a two-digit number (at least 55% of the plate width), roughly as wide as it is tall. No number, letter or mark inside it. Thick strokes and gaps, no detail smaller than one eighth of the canvas. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black, a cross, a crest, a star, any mark or number inside.

##### 111. `plate_cost_l.png` · P1

- **Used in:** Cost plate, top left of every card (large: 48-128 px: inspector, reward and pick tiles, Operator flyout, After-Action); the hexagon is the Supply shape everywhere (pips, Supply row).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256. **Background:** white on black: TA converts brightness to alpha.
- **States:** affordable (fill amber #FFB020, number slate) / can't pay (fill grey, rim red) / Operator (frm_supply_plate instead).
- **Note:** One shape per concept everywhere: the plate is the same silhouette as the concept's icon. TA: the rim ships as `plate_<x>_<s|l>.png`; a filled copy (`_fill`) is made by flood-filling the inside, so the code can draw a dark tinted fill under the number and a bright tinted rim on top. Replaces frm_cost_hex (which baked the amber in).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one number plate (the game prints the number inside it later): a cost number plate: an upright hexagon drawn as a thick rim, about one tenth of the plate width, with one thin inner line just inside it, the inside completely empty and large enough for a two-digit number. No number, letter or mark inside it. Thick strokes and gaps, no detail smaller than one eighth of the canvas. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black, a number, a crate, a second hexagon.

##### 112. `plate_cover_l.png` · P2

- **Used in:** Cover number plate, bottom right, left of FP, only when Cover > 0 (large: 48-128 px: inspector, reward and pick tiles, Operator flyout, After-Action).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256. **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (rim light steel) / buffed (rim green #7CF29A).
- **Note:** One shape per concept everywhere: the plate is the same silhouette as the concept's icon. TA: the rim ships as `plate_<x>_<s|l>.png`; a filled copy (`_fill`) is made by flood-filling the inside, so the code can draw a dark tinted fill under the number and a bright tinted rim on top. Optional: Cover can stay a small icon chip if the bottom-right corner gets crowded on the 57 px phone banner.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one number plate (the game prints the number inside it later): a cover number plate shaped like a low concrete barrier block seen from the front: a wide trapezoid, wider at the bottom with a flat top, drawn as a thick rim, about one tenth of the plate width, with one thin inner line just inside it, the inside completely empty and large enough for a one-digit number, compact (no wider than one and a half times its height). No number, letter or mark inside it. Thick strokes and gaps, no detail smaller than one eighth of the canvas. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black, a number, an arc or arrow, cracks.

### 4.3 Standard Issue card art (5)

#### Standard Issue card art (starter, our own art) (5)

##### 113. `kc_b_si_grunt.png` · P1

- **Used in:** Grunt (cost 1, 2/2): Grunt x5 in the starter, TrainingBot and the M1 / M2 Standard Issue squads.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1152x768 master (banner band 1152x288, hand column 512x768). **Background:** opaque, no transparency.
- **States:** normal (no animation, no foil).
- **Note:** Standard Issue starter art (onboarding-progression.md section 2.2): deliberately plain, so the first calling card pops. Banner pipeline: the curator sets banner_y / portrait_x, the TA ships the 1152x768 master and a data/banners/<id>.tres.

```
Original plain two-tone illustration for the basic starter cards of a modern military card game. One flat simple figure in olive drab #4B5320 and khaki #C3B091 against a muted grey-green #5E6B5A canvas or plain wooden supply-crate background. Flat shapes like a training-manual print, matte, low contrast, soft even light, no glow, no light effects, no dramatic lighting, only a faint canvas weave as texture. Deliberately modest and basic. A basic infantry soldier in a plain round helmet and simple fatigues standing at ease, a generic rifle held diagonally across the chest, three-quarter side view, two plain wooden supply crates stacked behind. Wide 3:2 landscape that will be cropped to a thin 4:1 strip across the middle (30% to 66% of the height) and a tall 2:3 column in the centre. Put the figure in the exact centre, head and hands between 30% and 65% of the height, inside the middle 60% of the width. The four corners of that strip stay empty, flat and calm, because the game puts the cost and name top left, abilities top right, the trait and weapon bottom left and the number plates bottom right. Above and below, continue the plain background. No text, letters, numbers, stencils, serial numbers, logos, insignia, flags, badges, patches or symbols on clothing, gear or crates. Invented people only, faces simple or shaded by the helmet. No blood.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real weapon models, recognizable people, gore, a busy or bright corner, markings or stencils on crates, boxes or gear, glow, light beams, dramatic lighting, a second figure.

##### 114. `kc_b_si_trooper.png` · P1

- **Used in:** Trooper (cost 2, 2/3): Trooper x6 in the starter, Standard Issue squads.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1152x768 master (banner band 1152x288, hand column 512x768). **Background:** opaque, no transparency.
- **States:** normal (no animation, no foil).
- **Note:** Standard Issue starter art (onboarding-progression.md section 2.2): deliberately plain, so the first calling card pops. Banner pipeline: the curator sets banner_y / portrait_x, the TA ships the 1152x768 master and a data/banners/<id>.tres.

```
Original plain two-tone illustration for the basic starter cards of a modern military card game. One flat simple figure in olive drab #4B5320 and khaki #C3B091 against a muted grey-green #5E6B5A canvas or plain wooden supply-crate background. Flat shapes like a training-manual print, matte, low contrast, soft even light, no glow, no light effects, no dramatic lighting, only a faint canvas weave as texture. Deliberately modest and basic. A soldier in a plain helmet and a simple padded vest walking forward mid-stride, a generic rifle held low in both hands, side view, a plain canvas tent wall behind. Wide 3:2 landscape that will be cropped to a thin 4:1 strip across the middle (30% to 66% of the height) and a tall 2:3 column in the centre. Put the figure in the exact centre, head and hands between 30% and 65% of the height, inside the middle 60% of the width. The four corners of that strip stay empty, flat and calm, because the game puts the cost and name top left, abilities top right, the trait and weapon bottom left and the number plates bottom right. Above and below, continue the plain background. No text, letters, numbers, stencils, serial numbers, logos, insignia, flags, badges, patches or symbols on clothing, gear or crates. Invented people only, faces simple or shaded by the helmet. No blood.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real weapon models, recognizable people, gore, a busy or bright corner, markings or stencils on crates, boxes or gear, glow, light beams, dramatic lighting, a second figure.

##### 115. `kc_b_si_sergeant.png` · P1

- **Used in:** Sergeant (cost 3, 3/3): Sergeant x4 in the starter, Standard Issue squads.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1152x768 master (banner band 1152x288, hand column 512x768). **Background:** opaque, no transparency.
- **States:** normal (no animation, no foil).
- **Note:** Standard Issue starter art (onboarding-progression.md section 2.2): deliberately plain, so the first calling card pops. Banner pipeline: the curator sets banner_y / portrait_x, the TA ships the 1152x768 master and a data/banners/<id>.tres.

```
Original plain two-tone illustration for the basic starter cards of a modern military card game. One flat simple figure in olive drab #4B5320 and khaki #C3B091 against a muted grey-green #5E6B5A canvas or plain wooden supply-crate background. Flat shapes like a training-manual print, matte, low contrast, soft even light, no glow, no light effects, no dramatic lighting, only a faint canvas weave as texture. Deliberately modest and basic. A soldier in a plain helmet with one arm stretched forward pointing the way, a generic rifle in the other hand, side view, one boot up on a low wooden crate, a plain canvas backdrop. Wide 3:2 landscape that will be cropped to a thin 4:1 strip across the middle (30% to 66% of the height) and a tall 2:3 column in the centre. Put the figure in the exact centre, head and hands between 30% and 65% of the height, inside the middle 60% of the width. The four corners of that strip stay empty, flat and calm, because the game puts the cost and name top left, abilities top right, the trait and weapon bottom left and the number plates bottom right. Above and below, continue the plain background. No text, letters, numbers, stencils, serial numbers, logos, insignia, flags, badges, patches or symbols on clothing, gear or crates. Invented people only, faces simple or shaded by the helmet. No blood.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real weapon models, recognizable people, gore, a busy or bright corner, markings or stencils on crates, boxes or gear, glow, light beams, dramatic lighting, a second figure.

##### 116. `kc_b_si_armored.png` · P1

- **Used in:** Armored Trooper (cost 4, 2/5): Armored Trooper x3 in the starter (the first card to send home), Standard Issue squads.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1152x768 master (banner band 1152x288, hand column 512x768). **Background:** opaque, no transparency.
- **States:** normal (no animation, no foil).
- **Note:** Standard Issue starter art (onboarding-progression.md section 2.2): deliberately plain, so the first calling card pops. Banner pipeline: the curator sets banner_y / portrait_x, the TA ships the 1152x768 master and a data/banners/<id>.tres.

```
Original plain two-tone illustration for the basic starter cards of a modern military card game. One flat simple figure in olive drab #4B5320 and khaki #C3B091 against a muted grey-green #5E6B5A canvas or plain wooden supply-crate background. Flat shapes like a training-manual print, matte, low contrast, soft even light, no glow, no light effects, no dramatic lighting, only a faint canvas weave as texture. Deliberately modest and basic. A heavy soldier in bulky plain body armour and a full helmet with a dark visor, standing square and slow, a generic rifle held low, front three-quarter view, a low wall of plain sandbags behind. Wide 3:2 landscape that will be cropped to a thin 4:1 strip across the middle (30% to 66% of the height) and a tall 2:3 column in the centre. Put the figure in the exact centre, head and hands between 30% and 65% of the height, inside the middle 60% of the width. The four corners of that strip stay empty, flat and calm, because the game puts the cost and name top left, abilities top right, the trait and weapon bottom left and the number plates bottom right. Above and below, continue the plain background. No text, letters, numbers, stencils, serial numbers, logos, insignia, flags, badges, patches or symbols on clothing, gear or crates. Invented people only, faces simple or shaded by the helmet. No blood.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real weapon models, recognizable people, gore, a busy or bright corner, markings or stencils on crates, boxes or gear, glow, light beams, dramatic lighting, a second figure.

##### 117. `kc_b_si_ammo_resupply.png` · P1

- **Used in:** Ammo Resupply (tactic, Draw 2): Ammo Resupply x2 in the starter (Standard Issue art for the existing card).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1152x768 master (banner band 1152x288, hand column 512x768). **Background:** opaque, no transparency.
- **States:** normal (no animation, no foil).
- **Note:** Standard Issue starter art (onboarding-progression.md section 2.2): deliberately plain, so the first calling card pops. Banner pipeline: the curator sets banner_y / portrait_x, the TA ships the 1152x768 master and a data/banners/<id>.tres. Tactic: no character is the subject (kind rule).

```
Original plain two-tone illustration for the basic starter cards of a modern military card game. One flat simple figure in olive drab #4B5320 and khaki #C3B091 against a muted grey-green #5E6B5A canvas or plain wooden supply-crate background. Flat shapes like a training-manual print, matte, low contrast, soft even light, no glow, no light effects, no dramatic lighting, only a faint canvas weave as texture. Deliberately modest and basic. Two plain ammunition boxes and a canvas bag of rifle magazines on a wooden pallet, one gloved hand lifting a box lid, no person in view beyond the hand and forearm, side view. Wide 3:2 landscape that will be cropped to a thin 4:1 strip across the middle (30% to 66% of the height) and a tall 2:3 column in the centre. Put the figure in the exact centre, head and hands between 30% and 65% of the height, inside the middle 60% of the width. The four corners of that strip stay empty, flat and calm, because the game puts the cost and name top left, abilities top right, the trait and weapon bottom left and the number plates bottom right. Above and below, continue the plain background. No text, letters, numbers, stencils, serial numbers, logos, insignia, flags, badges, patches or symbols on clothing, gear or crates. Invented people only, faces simple or shaded by the helmet. No blood.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real weapon models, recognizable people, gore, a busy or bright corner, markings or stencils on crates, boxes or gear, glow, light beams, dramatic lighting, a second figure.

### 4.4 Buttons and controls (14)

#### Buttons (14)

##### 118. `btn_primary.png` · P1

- **Used in:** Primary actions: CONTINUE, BEGIN RUN, TAP TO TAKE, DEPLOY (run map), PLAY HERE confirm.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / hover (code +10% light) / pressed (btn_primary_pressed) / disabled (code grey 55%, alpha 60%). **9-slice (L,T,R,B at ship size):** 40,40,40,48.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A wide button plate: signal amber #FFB020 face with a slightly darker amber #C98A10 bottom edge 1/8 of its height, a thin darker outline, 45-degree chamfered corners top-left and bottom-right only, a faint brushed-metal grain on the face, a soft one-pixel highlight along the top edge, plain flat face with nothing on it. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 119. `btn_primary_pressed.png` · P1

- **Used in:** Pressed state of btn_primary.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** pressed. **9-slice (L,T,R,B at ship size):** 40,40,40,48.
- **Note:** Generate in the same chat right after btn_primary ('same plate, pressed in').

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. The same wide amber button plate as before but pressed in: the face one shade darker #E59A12, the darker bottom edge gone, a thin inner shadow along the top edge, same chamfered corners, same size and outline. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 120. `btn_secondary.png` · P1

- **Used in:** Secondary actions: BACK, SKIP, DETAILS, DECK, CODEX, pause menu rows, Codex filter bar buttons.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / hover (+10%) / pressed (btn_secondary_pressed) / disabled (grey 55%) / selected (fx_outline_teal on top). **9-slice (L,T,R,B at ship size):** 40,40,40,48.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A wide button plate: dark gunmetal #2E3740 face, a 2-pixel steel #4A535B outline, a slightly darker #232A31 bottom edge 1/8 of its height, 45-degree chamfered corners top-left and bottom-right only, faint brushed grain, a thin cool highlight along the top edge, plain empty face. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 121. `btn_secondary_pressed.png` · P1

- **Used in:** Pressed state of btn_secondary.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** pressed. **9-slice (L,T,R,B at ship size):** 40,40,40,48.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. The same gunmetal button plate pressed in: face one shade darker #262E35, no bottom edge, a thin inner shadow along the top, same chamfers and outline. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 122. `btn_danger.png` · P2

- **Used in:** Danger / leave actions: BACK TO TITLE, abandon run, NEW RUN confirm.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / hover (+10%) / pressed (code: darker + 2 px down) / disabled (grey). **9-slice (L,T,R,B at ship size):** 40,40,40,48.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A wide button plate: deep signal red #B8282B face with a darker #7A1A1C bottom edge 1/8 of its height, a thin dark outline, 45-degree chamfered corners top-left and bottom-right only, faint brushed grain, plain empty face. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 123. `btn_ready.png` · P1

- **Used in:** READY in the tray (245x64 phone, 149x72 desktop): the main button of every round.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x136. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / hover / pressed (btn_ready_pressed) / disabled (grey: nothing planned yet is still allowed, so rare) / glow (fx_glow_amber pulse when the Deploy timer is low). **9-slice (L,T,R,B at ship size):** 48,40,112,48.
- **Note:** The stripes sit inside the right 9-slice margin so they never stretch.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A big wide command button plate: amber #FFB020 face with a darker amber bottom edge, a thick dark #12161A outline, chamfered top-left and bottom-right corners, and a band of three short dark diagonal hazard stripes at the far right end only; the rest of the face is plain and flat. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 124. `btn_ready_pressed.png` · P1

- **Used in:** Pressed state of READY.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x136. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** pressed. **9-slice (L,T,R,B at ship size):** 48,40,112,48.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. The same READY button plate pressed in: amber face one shade darker, no bottom edge, a thin inner top shadow, stripes unchanged. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 125. `btn_badge.png` · P1

- **Used in:** Icon strip badges 62x64 (MENU, SCORE, OPERATOR, STREAK, RIVAL, PREVIEW, DECK), SPEED, UNDO square.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / pressed (code darker) / glow (fx_glow_amber: killstreak ready, Operator DEPLOY) / selected (fx_outline_teal: flyout open). **9-slice (L,T,R,B at ship size):** 24,24,24,24.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A square badge plate: dark slate #1C2228 face, a 2-pixel steel #3A444D outline, all four corners chamfered at 45 degrees, a thin darker inner bevel, a faint vertical brushed grain, plain empty face. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 126. `btn_chip.png` · P2

- **Used in:** Small pill buttons: Codex filters (ALL / UNITS / AR...), tabs on narrow screens, toggles in the deck view.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 192x64. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / selected (btn_chip_on) / pressed (code) / disabled (grey). **9-slice (L,T,R,B at ship size):** 24,20,24,20.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small wide pill-shaped plate with flat left and right ends cut at 45 degrees, dark gunmetal #232A31 face, a thin steel #4A535B outline, plain. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 127. `btn_chip_on.png` · P2

- **Used in:** Selected filter chip / active tab.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 192x64. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** selected. **9-slice (L,T,R,B at ship size):** 24,20,24,20.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. The same small pill plate, now selected: face filled with fog white #D8DEE3 at low brightness #A9B3BB, a thin amber #FFB020 underline along the bottom edge, same shape. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 128. `btn_tab.png` · P3

- **Used in:** Tabs: SETS flyout (RIVAL / YOU), score sheet, Codex kind tabs on desktop.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 192x80. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** inactive / active (code: lighter + amber top line). **9-slice (L,T,R,B at ship size):** 28,24,28,8.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A folder-tab shape: a flat-topped trapezoid with chamfered top corners and an open bottom edge, dark gunmetal #232A31 face, thin steel outline on the top and sides only. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 129. `tgl_track.png` · P2

- **Used in:** Settings toggles: MIRROR LAYOUT, SPEED x2, FAST ANIMATIONS, PREVIEW.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 128x64. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** off (grey) / on (code tints the inner teal #2EC4B6). **9-slice (L,T,R,B at ship size):** 30,30,30,30.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A horizontal toggle switch track: a long rounded slot recessed into dark metal, inner colour #12161A, thin steel #3A444D rim. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 130. `tgl_knob.png` · P2

- **Used in:** Toggle knob, slider knob.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 64x64. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / pressed (code darker).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A single round knob: brushed fog-white metal disk with a soft edge highlight and three short grip lines in the centre. One element only, centred, filling about 80% of the canvas. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 131. `sld_track.png` · P3

- **Used in:** Slider track (volume, Deploy timer setting) and progress bars (run tickets).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 256x32. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / fill (code tints a copy amber). **9-slice (L,T,R,B at ship size):** 14,14,14,14.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A thin long horizontal recessed groove in dark metal, inner #12161A, steel rim, rounded ends. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

### 4.5 Panels, trays, rings and strips (26)

#### Panels, trays and overlays (24)

##### 132. `pnl_tray.png` · P1

- **Used in:** Hand tray (362x532 phone, 224x776 desktop): background of the hand grid, killfeed log, step header.
- **Generate:** 1024x1536 (portrait 2:3). **Ship:** 256x512. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal (open / closed share it). **9-slice (L,T,R,B at ship size):** 32,32,32,32.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A tall rectangular panel: matte gunmetal #1C2228 face with a very faint diagonal brushed grain, a 2-pixel steel #3A444D outline, 45-degree chamfers on the top-left and bottom-left corners only, a thin darker inner bevel; plain empty face, no screws in the middle of the edges. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Portrait 2:3.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 133. `pnl_flyout.png` · P1

- **Used in:** Strip badge flyouts: SCORE, OPERATOR, STREAK, RIVAL, DECK, SETS.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x256. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 32,32,32,32.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A rectangular pop-out panel: dark slate #161B20 face at slightly lighter centre, a 2-pixel steel #4A535B outline with a thin amber #FFB020 line along the top edge only, all corners chamfered at 45 degrees. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 134. `pnl_flyout_pointer.png` · P2

- **Used in:** The little pointer that joins a flyout to its badge.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 32x48. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal (code flips it for mirror layout).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small solid triangular pointer, dark slate #161B20 with a steel #4A535B outline on its two outer sides only, pointing left. One element only, centred, filling about 80% of the canvas. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 135. `pnl_toast.png` · P1

- **Used in:** Killfeed toasts (top centre, 2 max, 92% opacity), one-time callouts, 'Not enough Supply' toasts.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x64. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal (the left bar is tinted teal / red / amber in code). **9-slice (L,T,R,B at ship size):** 40,16,24,16.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A slim wide strip panel: near-black #0F1316 face, a short angled cut at both ends like a ribbon, a thin steel outline, a narrow vertical accent bar inset at the left end in fog white (tinted by side in game). One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 136. `pnl_inspector.png` · P1

- **Used in:** Card inspector (512x128 banner + text panel, scrolls), item inspector, long-press rules.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x384. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 40,40,40,40.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A large rectangular information panel: dark slate #12161A face with a faint fine scanline texture, a 2-pixel steel #4A535B outline, chamfered top-left and bottom-right corners, a thin amber line along the top edge from the left corner for a third of the width. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 137. `pnl_tooltip.png` · P2

- **Used in:** Tooltips (desktop hover), long-press rule bubbles, Supply Drop twin preview.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 192x96. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 16,16,16,16.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small rectangular tooltip panel: near-black #0F1316 face at 95% opacity, a 1-pixel fog-white #D8DEE3 outline at low brightness, small 45-degree chamfers on all four corners. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 138. `pnl_modal.png` · P1

- **Used in:** Pause menu, match end (VICTORY / DEFEAT), Retire picker, score sheet, consent and surveys.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x384. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 48,48,48,48.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A large centred dialog panel: gunmetal #232A31 face with a soft lighter centre, a 3-pixel steel #4A535B outline and a thin inner second outline 6 pixels inside, chamfered corners on all four sides, a small plain rivet in each corner. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 139. `pnl_header.png` · P2

- **Used in:** Screen title bars: SUPPLY DROP, CODEX, RUN SUMMARY, PAUSED, STARTER KIT.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x64. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 40,16,40,16.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A long horizontal title bar plate: dark gunmetal face, a thin amber #FFB020 line along the bottom edge, both ends cut at 45 degrees, plain. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 140. `pnl_hand_tab.png` · P2

- **Used in:** HAND · n PEEK tab (362x64) in the closed tray.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x80. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / pressed (code). **9-slice (L,T,R,B at ship size):** 40,24,40,16.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A wide tab plate that looks like the top edge of a drawer: gunmetal face, a thin steel outline, chamfered top corners, a short row of three grip lines centred on the top edge. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 141. `pnl_ks_tile.png` · P1

- **Used in:** Killstreak tile backer (61 px) at the top of the tray and in the STREAK flyout.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** charging / ready (fx_glow_amber + amber frame by code) / used (code dim).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A square tile plate: dark slate #12161A face, a thin steel outline, chamfered corners, a circular recessed socket in the middle taking up 70% of the tile. One element only, centred, filling about 80% of the canvas. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 142. `ring_track.png` · P1

- **Used in:** Killstreak charge ring (empty track); TextureProgressBar under.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A thick flat circular ring track divided into eight equal segments by thin gaps, dark steel #2E3740, perfectly round, centred, nothing inside the ring. One element only, centred, filling about 80% of the canvas. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 143. `ring_fill.png` · P1

- **Used in:** Killstreak charge ring fill; TextureProgressBar radial (tinted amber / cyan).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x128. **Background:** white on black: TA converts brightness to alpha.
- **States:** fill (code tints: charging cyan #5BC0EB, ready amber #FFB020).
- **Note:** Generate right after ring_track in the same chat so the segments line up.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: the same thick circular ring divided into eight equal segments by thin gaps, solid pure white, perfectly round, centred, same size as before, nothing inside. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black.

##### 144. `pip_supply.png` · P1

- **Used in:** Supply pips (up to 10) in the tray.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 64x64. **Background:** white on black: TA converts brightness to alpha.
- **States:** full (tint amber) / empty (tint dark steel, 40%) / spent this Deploy (tint grey).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: a single small hexagonal pip seen front-on: solid pure white hexagon with a thin cut-in inner bevel line. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black.

##### 145. `pnl_counter.png` · P2

- **Used in:** Small number bubble: hand count, deck count on badges, '+n more', unread log.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 64x48. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / tinted by side. **9-slice (L,T,R,B at ship size):** 16,16,16,16.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small rounded-rectangle counter plate, near-black #0F1316 face, a thin fog-white outline, slightly taller than a circle. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 146. `pnl_order_strip.png` · P2

- **Used in:** Firefight order strip A -> B -> C over the board.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x48. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 24,12,24,12.
- **Note:** NEW: the A > B > C order strip (firefight-order.md section 8) is not built yet.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A slim horizontal strip plate with both ends cut at 45 degrees, near-black #0F1316 face at 85% opacity, a thin steel outline. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 147. `order_node.png` · P2

- **Used in:** One column node on the order strip (letter drawn by code).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 64x64. **Background:** white on black: TA converts brightness to alpha.
- **States:** pending (grey) / current (amber + fx_glow_amber) / done (teal + ico_ui_check) / skipped (dim 30%).
- **Note:** NEW: for the order strip (not built yet).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: a single hexagonal node plate seen front-on: solid pure white hexagon with a thick rim and a slightly recessed flat centre. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black.

##### 148. `order_arrow.png` · P2

- **Used in:** Connector between order nodes.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 64x32. **Background:** white on black: TA converts brightness to alpha.
- **States:** pending / passed (tint).
- **Note:** NEW: for the order strip (not built yet).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: a short thick right-pointing arrow made of a straight bar and a solid triangular head, solid white. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black.

##### 149. `pnl_rail_chip.png` · P2

- **Used in:** Trait rail chips (62x49 phone) and SETS flyout rows.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x96. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** idle / lit (code tints the slot by trait) / ring tier 3 (fx_ring_tier3) / crack (fx_crack). **9-slice (L,T,R,B at ship size):** 20,20,20,20.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small upright chip plate, dark slate face, a thin steel outline, a narrow slot along the left edge for a colour bar, chamfered top-right corner. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 150. `pnl_callout.png` · P2

- **Used in:** Set callouts ('VANGUARD 2: ...'), column banner 'COLUMN A', FIRST SHOT tag, DEPLOY / PLAY HERE chips.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 256x48. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal (code tints outline: green buff, red off, amber ready). **9-slice (L,T,R,B at ship size):** 24,12,24,12.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A slim angled tag plate like a cut ribbon: a parallelogram with both ends slanted, near-black face, a thin fog-white outline. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 151. `pnl_pick_tile.png` · P1

- **Used in:** Reward pick tiles (Supply Drop cards, Retire, Doctrine, Promotion, Perk Offer), Loadout picks.
- **Generate:** 1024x1536 (portrait 2:3). **Ship:** 256x384. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / hover (+10%) / selected (fx_outline_teal) / disabled (AT THE FLOOR: grey). **9-slice (L,T,R,B at ship size):** 32,32,32,64.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. An upright tile frame: dark gunmetal face, a 2-pixel steel outline, chamfered top-left and bottom-right corners, a slightly lighter band across the bottom fifth for a caption. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Portrait 2:3.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 152. `pnl_coach.png` · P2

- **Used in:** Tutorial coach bubbles over the objective row.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x160. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 32,32,32,48.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A speech-bubble style info panel with a squared body and a small triangular tail at the bottom left, near-black face, a thin amber outline, chamfered corners. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 153. `pnl_result.png` · P2

- **Used in:** Match end and run end headline plate behind VICTORY / DEFEAT / DRAW.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 768x160. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** victory (code tints amber) / defeat (red) / draw (steel). **9-slice (L,T,R,B at ship size):** 160,48,160,48.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A wide ceremonial plate: a long horizontal bar with angled ends and two short parallel wing bars above and below it at each end, brushed steel face, plain centre. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in, wings with feathers, eagles, stars, laurels, a crest.

##### 154. `runmap_node.png` · P2

- **Used in:** Run map match nodes (NEXT / UPCOMING / done).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 96x96. **Background:** white on black: TA converts brightness to alpha.
- **States:** upcoming (grey) / next (amber + glow) / won (teal + check) / lost (red).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: a single round map node: a thick ring around a recessed disc, pure white, perfectly round. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black.

##### 155. `runmap_path.png` · P3

- **Used in:** Path between run map nodes (tiled).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x16. **Background:** white on black: TA converts brightness to alpha.
- **States:** ahead (grey) / travelled (amber).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: a short horizontal dashed line of four thick dashes, pure white, evenly spaced, seamless when repeated. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black.

#### First-time explainer (New: X) (2)

##### 156. `pnl_new_card.png` · P1

- **Used in:** 'New: X' one-time explainer card (half screen: icon, one sentence, mini example, GOT IT), queued one per screen.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x320. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / enter (code: slide + fade). **9-slice (L,T,R,B at ship size):** 96,48,40,40.
- **Note:** The tab sits inside the left and top 9-slice margins. GOT IT uses btn_primary.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A large explainer card panel: dark gunmetal #232A31 face with a soft lighter centre, a 2-pixel steel #4A535B outline, 45-degree chamfered corners, a short solid amber #FFB020 flag tab hanging from the top-left corner (plain, for a word the game adds), a thin amber line running along the top edge from the tab. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 157. `pnl_new_inset.png` · P1

- **Used in:** Mini example well inside the New: card (a mini board grid, a card, a trait counter).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 256x160. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 20,20,20,20.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A recessed rectangular well: near-black #0F1316 face sunk into the metal, a thin dark inner shadow along the top and left edges and a 1-pixel light steel line along the bottom and right edges, small chamfered corners. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

### 4.6 Backgrounds (12)

#### Screen backgrounds (9)

##### 158. `bg_title.png` · P1

- **Used in:** Title screen (KillingCard wordmark drawn by code on the left third).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1536x864 (crop 80 px top and bottom). **Background:** opaque, no transparency.
- **States:** normal.
- **Note:** Replaces assets/ui/backgrounds/title_key_art.webp (Killstreak era).

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. A dusk view over a fictional harbour container yard from a high crane: stacked containers in long rows, two gantry cranes as dark silhouettes against an amber horizon glow, one lone operator figure standing on a container in the right third, small and backlit. The left third is calm dark sky and haze for the title and buttons. Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom get cropped.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

##### 159. `bg_menu.png` · P3

- **Used in:** Pause menu backdrop behind pnl_modal, settings, consent and survey screens.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1536x864 (crop 80 px top and bottom). **Background:** opaque, no transparency.
- **States:** normal.
- **Note:** Optional: the pause menu can keep its code scrim.

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. An extreme close-up of a dark matte equipment case lid with a subtle hexagonal foam texture and a faint amber light leak from the top edge; almost abstract, very dark, even, no objects Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom get cropped.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

##### 160. `bg_run_map.png` · P1

- **Used in:** Run map (5 matches, tickets, DEPLOY).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1536x864 (crop 80 px top and bottom). **Background:** opaque, no transparency.
- **States:** normal.
- **Note:** Replaces bg_run.webp. No letters or grid numbers on the map.

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. A top-down tactical map table: a dark paper map of a fictional harbour district with faint contour lines and water shapes, a few scattered plain playing-card shapes and a compass-free ruler lying on it, cool lamp light from above, very low contrast Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom get cropped.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

##### 161. `bg_supply_drop.png` · P1

- **Used in:** Supply Drop / Weapon Level / Perk Offer / Promotion / Doctrine / Regroup reward screens.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1536x864 (crop 80 px top and bottom). **Background:** opaque, no transparency.
- **States:** normal.
- **Note:** Replaces the Killstreak-era bg_supply_drop.webp (that one put the crate in the right third; cards now need more room).

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. A supply crate under a parachute settling into a dark container yard, a floodlight cone on it, dust kicked up; the crate sits in the right fifth, the rest dark and calm for three cards and a fourth tile Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom get cropped.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

##### 162. `bg_after_action.png` · P2

- **Used in:** After-Action report (VICTORY / DEFEAT, stats, Honor Roll), run end.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1536x864 (crop 80 px top and bottom). **Background:** opaque, no transparency.
- **States:** normal.

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. A quiet briefing room at night: a long table edge in the foreground with a closed folder and a few cards face down, a dark wall with a faint pin board shape, a single warm lamp on the far right; most of the frame dark and plain Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom get cropped.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

##### 163. `bg_codex.png` · P2

- **Used in:** Codex (filters + tile grid).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1536x864 (crop 80 px top and bottom). **Background:** opaque, no transparency.
- **States:** normal.

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. The inside of a dark armoury locker wall: rows of empty matte card slots and pegboard holes fading into darkness, a thin strip of cool light from the top, extremely calm and even so a grid of tiles can sit on top Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom get cropped.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

##### 164. `bg_loadout.png` · P2

- **Used in:** Starter deck / Loadout screen (STARTER KIT, picks, BEGIN RUN).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1536x864 (crop 80 px top and bottom). **Background:** opaque, no transparency.
- **States:** normal.

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. A gear bench under a hanging work lamp: a dark padded mat with a plain rifle case closed on the left, a neat stack of cards and a helmet on the right edge, the centre of the mat empty and dark Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom get cropped.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

##### 165. `bg_loading.png` · P2

- **Used in:** Loading screen / web shell splash, boot (wordmark and bar drawn by code).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1536x864 (crop 80 px top and bottom). **Background:** opaque, no transparency.
- **States:** normal.
- **Note:** Ship also as a 960x540 WebP for the web shell (loads before the engine).

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. A single gantry crane silhouette at night far away across dark water, one amber warning light on its top, heavy fog, almost monochrome, huge empty dark sky Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom get cropped.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

##### 166. `bg_match.png` · P1

- **Used in:** Match backdrop behind the strip, the 3 columns and the tray.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1536x864 (crop 80 px top and bottom). **Background:** opaque, no transparency.
- **States:** normal.
- **Note:** Replaces the tactical_backdrop shader look only if the head prefers it; the shader can stay as the fallback.

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. An abstract top-down view of dark wet concrete with faint painted parking-bay lines worn away, a few oil stains, subtle tyre marks, extremely low contrast, evenly lit, no objects Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom get cropped.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

#### Column location backdrops (Port Vasel) (3)

##### 167. `col_containers.png` · P1

- **Used in:** Column backing: containers.
- **Generate:** 1024x1536 (portrait 2:3). **Ship:** 512x1216 (crop the middle 648x1536, resize). **Background:** opaque, no transparency.
- **States:** normal (dimmed in code).
- **Note:** Shown behind the slots at 34% opacity, darkened (lane.gd Backing). Replaces the square lane_*.webp from Killstreak, which crop badly into a tall column.

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. A narrow canyon between two walls of stacked shipping containers seen from directly above, long straight shapes running top to bottom, a wet strip of ground down the middle. Top-down, very low contrast, flat even light, no focal point, nothing bright in the middle, similar detail all the way from top to bottom. Tall 2:3 portrait. Only the middle 60% of the width is used and it is shown at a third of its brightness behind game cards, so keep it subtle and even. Seen from directly above.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

##### 168. `col_cranes.png` · P1

- **Used in:** Column backing: cranes.
- **Generate:** 1024x1536 (portrait 2:3). **Ship:** 512x1216 (crop the middle 648x1536, resize). **Background:** opaque, no transparency.
- **States:** normal (dimmed in code).
- **Note:** Shown behind the slots at 34% opacity, darkened (lane.gd Backing). Replaces the square lane_*.webp from Killstreak, which crop badly into a tall column.

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. The steel lattice of a gantry crane leg and rail tracks seen from above, running top to bottom, a few cable shadows, dark water at one side. Top-down, very low contrast, flat even light, no focal point, nothing bright in the middle, similar detail all the way from top to bottom. Tall 2:3 portrait. Only the middle 60% of the width is used and it is shown at a third of its brightness behind game cards, so keep it subtle and even. Seen from directly above.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

##### 169. `col_offices.png` · P1

- **Used in:** Column backing: offices.
- **Generate:** 1024x1536 (portrait 2:3). **Ship:** 512x1216 (crop the middle 648x1536, resize). **Background:** opaque, no transparency.
- **States:** normal (dimmed in code).
- **Note:** Shown behind the slots at 34% opacity, darkened (lane.gd Backing). Replaces the square lane_*.webp from Killstreak, which crop badly into a tall column.

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. The flat roof of a low port office block seen from directly above: air-conditioning boxes, roof vents, a stair hatch, a parapet edge running top to bottom. Top-down, very low contrast, flat even light, no focal point, nothing bright in the middle, similar detail all the way from top to bottom. Tall 2:3 portrait. Only the middle 60% of the width is used and it is shown at a third of its brightness behind game cards, so keep it subtle and even. Seen from directly above.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

### 4.7 Objective and Field tile backers (4)

#### Objective and Field tile backers (4)

##### 170. `tile_objective.png` · P1

- **Used in:** Objective tile between the fronts (228x52 phone, 304x96 desktop): FP pair, control mark, words, Field chips.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 456x112. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / your control (code edge teal) / rival control (edge red) / even (dashed edge, code). **9-slice (L,T,R,B at ship size):** 24,20,24,20.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A wide low plate set into the ground like a steel floor hatch: dark gunmetal #232A31 face, a 2-pixel steel #3A444D outline, small chamfered corners, two faint recessed grooves running across near the left and right ends, plain flat centre. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 171. `tile_field_chip.png` · P1

- **Used in:** Field chip on the objective tile (70x22 phone, 96x28 desktop), one per side.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 192x64. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** yours (code tint teal) / rival (red) / overrun risk (fx_glow_red pulse) / trap (dashed: tile_field_chip_trap). **9-slice (L,T,R,B at ship size):** 24,16,24,16.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small wide chip plate shaped like a dog-ear tag: a rectangle with the top-right corner clipped, near-black face, a thin fog-white outline, a short slot at the left end for a side colour bar. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 172. `tile_field_chip_trap.png` · P2

- **Used in:** Your hidden trap chip (dashed, only you see it).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 192x64. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 24,16,24,16.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. The same small clipped-corner chip shape drawn only as a dashed fog-white outline, the face transparent. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 173. `tile_slot_empty.png` · P2

- **Used in:** Empty row slot in a column (your landing slots, rival back rows).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 456x114. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / valid target (code teal outline) / invalid (code dim). **9-slice (L,T,R,B at ship size):** 20,20,20,20.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A very wide low rectangle drawn as a faint thin steel outline with small corner brackets at each corner, the face nearly transparent dark #12161A at 30%. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

### 4.8 Card frame parts (26)

#### Board banner frame (4:1) (9)

##### 174. `frm_banner.png` · P1

- **Used in:** Every board banner (228x57 phone, 304x76 desktop, 512x128 inspector): the steel frame around the art.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / selected (fx_outline_teal) / now firing (fx_outline_side) / damaged (code) / dimmed (code). **9-slice (L,T,R,B at ship size):** 40,32,16,16.
- **Note:** Ask for the frame across the whole width of the canvas; the TA crops a 4:1 band. The middle must be transparent: the art shows through.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A very wide thin picture frame, four times wider than tall: a 3-pixel dark steel #3A444D border with a 1-pixel lighter top-left bevel, small 45-degree chamfers at the top-right, bottom-left and bottom-right corners, a hexagon-shaped notch cut into the top-left corner (for the cost plate), the inside of the frame completely empty. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 175. `frm_spine_you.png` · P1

- **Used in:** Side edge strip on your banners (outer long edge, away from the objective).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x16. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / dim (code). **9-slice (L,T,R,B at ship size):** 16,4,16,4.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A long thin horizontal strip: solid teal #2EC4B6 with a slightly darker #1E8C82 lower half and a fine row of small square notches along its top edge, both ends cut at 45 degrees. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 176. `frm_spine_rival.png` · P1

- **Used in:** Side edge strip on rival banners (shape differs from yours for colour-blind players).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x16. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / dim (code). **9-slice (L,T,R,B at ship size):** 16,4,16,4.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A long thin horizontal strip: solid signal red #E5383B with a darker #8E1F21 lower half and a row of small diamond-shaped notches along its top edge, both ends cut at 45 degrees. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 177. `frm_front_tab.png` · P1

- **Used in:** FRONT tab (48x13 phone, 64x15 desktop) on the front-row card; word drawn by code.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x32. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** yours (tint teal) / rival (tint red). **9-slice (L,T,R,B at ship size):** 12,6,12,6.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small flat tab shaped like a trapezoid, wider at the bottom, solid fog white #D8DEE3 face with a thin darker outline, plain. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 178. `frm_plan_plate.png` · P1

- **Used in:** PLAN tag on your planned cards (inner-edge centre) and PLAN · B on the Operator card.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x40. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 16,8,16,8.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small slanted tag plate: a short parallelogram, dark brass #3A2D0B face with a thin brass #C9A227 outline, plain. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 179. `frm_incoming.png` · P1

- **Used in:** INCOMING face-down rival banner (back pattern, fills the whole 4:1 banner).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x128 (crop a 4:1 band). **Background:** opaque, no transparency.
- **States:** normal / pulse (code).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A seamless dark card-back pattern for a very wide card: diagonal hazard-free fine chevron weave in gunmetal #232A31 on slate #12161A, a slightly brighter abstract arrow pattern pointing down repeated evenly, low contrast. Fill the whole canvas edge to edge, flat front-on view. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, a cast shadow, a perspective tilt, emblems, a central logo, letters, a skull.

##### 180. `frm_supply_plate.png` · P2

- **Used in:** Operator card '1 SUPPLY' plate in place of the cost hex; red when you can't pay.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 160x48. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / can't pay (code tint red). **9-slice (L,T,R,B at ship size):** 16,12,16,12.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small horizontal brass plate with rounded corners and two tiny rivets at the ends, brass #C9A227 face with darker #5A4512 edges. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 181. `frm_socket.png` · P1

- **Used in:** Socket for keyword pip, trait pip, class pip and effect glyph (22 px phone, 26 desktop).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 64x64. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** idle (grey rim) / lit (code tints the rim: keyword accent, trait colour).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small square socket plate with chamfered corners: near-black #0F1316 recessed face, a thin steel #3A444D rim, plain. One element only, centred, filling about 80% of the canvas. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 182. `fx_ring_tier3.png` · P2

- **Used in:** White ring around a trait pip at set tier 3 (banner, rail).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 64x64. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** normal.

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A single thin bright ring of light, perfectly round, soft glow on both sides, nothing inside. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Square 1:1.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

#### Level camo bands and Operator mastery ladder (1)

##### 183. `frm_band_edge.png` · P2

- **Used in:** Thin metal edge that caps a camo band strip top and bottom.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x8. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 4,2,4,2.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A long very thin horizontal metal trim strip with a tiny bevel, light steel #B9C2C9, both ends square. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### Elite and Operator frames (5)

##### 184. `frm_elite.png` · P2

- **Used in:** Elite chassis banner and hand card frame (gold frame + star).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / selected (fx_outline_teal). **9-slice (L,T,R,B at ship size):** 16,16,16,16.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A very wide thin picture frame like frm_banner but in brushed gold #C9A227 with darker #7A5E12 edges, small chamfers, a tiny plain gold rivet in each corner, the inside completely empty. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 185. `frm_operator_banner.png` · P1

- **Used in:** The Operator's banner on the board (brass frame, camo band on the outer edge, dog-tag plate).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / selected / now firing / downed (code dim). **9-slice (L,T,R,B at ship size):** 24,16,24,16.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A very wide thin picture frame in polished brass #C9A227 with dark brass #5A4512 edges, rounded dog-tag style corners instead of chamfers, a tiny round hole near the left end of the top edge like a tag, the inside completely empty. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 186. `frm_operator_card.png` · P1

- **Used in:** Operator card pinned first in the tray (99x124 phone, 108x136 desktop).
- **Generate:** 1024x1536 (portrait 2:3). **Ship:** 256x320. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / can deploy (fx_glow_amber) / selected (teal border: fx_outline_teal) / can't pay (code red plate) / down (code dim). **9-slice (L,T,R,B at ship size):** 32,72,32,48.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. An upright card frame shaped like a big military dog tag: polished brass #C9A227 border with dark brass #3A2D0B fill, fully rounded corners, a round hole near the top centre with a short ball chain, a recessed window in the upper 60% for the art, a plain lower area. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Portrait 2:3.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in, engraved letters or numbers on the tag.

##### 187. `frm_operator_mini.png` · P1

- **Used in:** Mini Operator card (half height, ON BOARD / C · ROW 1) while the Operator is on the board.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 256x160. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / selected (fx_outline_teal). **9-slice (L,T,R,B at ship size):** 40,24,24,24.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A wide short dog-tag plate: polished brass border, dark brass fill, fully rounded corners, a round hole at the left end, plain recessed face. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 188. `frm_dogtag_plate.png` · P2

- **Used in:** Callsign / dog-tag plate on the Operator banner (in place of the effect glyph).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 96x40. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A tiny horizontal dog tag with rounded ends and a hole at the left end, brushed brass, plain face. One element only, centred, filling about 80% of the canvas. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### Hand card, Codex and mulligan (5)

##### 189. `frm_hand_card.png` · P1

- **Used in:** Hand banner card frame in the tray (kc-ui4 board-form: 177x73 phone, 224x64 desktop, 103x78 on 16:9), mulligan cards, Supply Drop picks.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 448x184. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / selected (14 px shift + fx_outline_teal) / unplayable (code dim) / NEXT DEPLOY peek (code dim) / set-tier dot (code). **9-slice (L,T,R,B at ship size):** 56,40,20,20.
- **Note:** kc-ui4 (in progress) makes hand cards banner cards (BannerCard.build) between 1.3:1 and 2.4:1; the 9-slice keeps the cost notch in the left margin, so one frame fits every cell.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A wide card frame about two and a half times wider than tall, in the same steel language as the board banner frame: a 3-pixel dark steel #3A444D border with a lighter top-left bevel, small 45-degree chamfers at three corners, a hexagon-shaped notch cut into the top-left corner (for the cost hex), the inside completely empty so the art shows through. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 190. `frm_hand_name.png` · P2

- **Used in:** Name band across the middle of a narrow hand banner card (16:9 phones), stats row.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 256x48. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 12,8,12,8.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A long low bar plate, near-black face, a thin steel top edge line, both ends square. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 191. `frm_codex_tile.png` · P2

- **Used in:** Codex tile (120x156 compact): art, cost hex, name, chassis line.
- **Generate:** 1024x1536 (portrait 2:3). **Ship:** 240x312. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / hover (+10%) / pressed / locked (overlay ico_ui_lock + code dim) / equipped (frm_equipped). **9-slice (L,T,R,B at ship size):** 32,32,32,72.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. An upright collectible tile frame: dark gunmetal border with a thin steel outline, a hexagon-shaped notch cut into the top-left corner for the cost plate, a chamfered bottom-right corner, an art window in the upper 55%, a slightly lighter lower plate for two lines of caption. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Portrait 2:3.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 192. `frm_equipped.png` · P3

- **Used in:** FOUND / EQUIPPED corner mark on Codex tiles (word drawn by code); kc-trait-ui removed EQUIP, so it now marks FOUND arts.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal.
- **Note:** kc-trait-ui (head B): no EQUIP in runs; the Codex shows FOUND marks instead, so this is optional polish.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A corner ribbon that wraps the top-right corner of a card diagonally: a solid brass #C9A227 band with darker edges and a tiny dog-tag shape hanging from it, plain, the rest transparent. One element only, centred, filling about 80% of the canvas. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 193. `frm_put_back.png` · P1

- **Used in:** Mulligan PUT BACK plate on marked cards (word drawn by code).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x320. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A diagonal band laid across a card from lower left to upper right: semi-transparent dark red #5A1A1C at 85% with thin bright red #E5383B edges and short hazard ticks at both ends, nothing else. One element only, centred, filling about 80% of the canvas. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### Card backs (2)

##### 194. `card_back_banner.png` · P2

- **Used in:** Face-down KillingCard back (4:1): deck pile, deal animation, rival hand, INCOMING alternative.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x128 (crop a 4:1 band). **Background:** opaque, no transparency.
- **States:** normal.
- **Note:** NEW: no face-down 4:1 back in code yet (INCOMING is drawn).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A very wide card back design: dark gunmetal laminated texture, a centred abstract mark of three short amber chevrons pointing right inside a thin long hexagon outline, faint topographic contour lines, symmetrical, worn edges. Fill the whole canvas edge to edge, flat front-on view. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, a cast shadow, a perspective tilt, letters, a logo, a skull, wings, stars, eagles, any badge or unit-crest look.

##### 195. `card_back_hand.png` · P3

- **Used in:** Face-down hand-size back (deck view, mulligan replacements).
- **Generate:** 1024x1536 (portrait 2:3). **Ship:** 256x320. **Background:** opaque, no transparency.
- **States:** normal.
- **Note:** Replaces the Killstreak-era card_back.webp.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. The same card back design as before on an upright card: dark gunmetal laminated texture, three short amber chevrons pointing up inside a thin tall hexagon outline, faint contour lines, symmetrical. Fill the whole canvas edge to edge, flat front-on view. Portrait 2:3.
```

**Avoid:** text, letters, numbers, logos, a cast shadow, a perspective tilt.

#### Standard Issue frame and plates (4)

##### 196. `frm_standard_issue.png` · P1

- **Used in:** Standard Issue frame on every Standard Issue card: board banners, hand banner cards, mulligan, Muster out list (no camo band, no foil).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / selected (fx_outline_teal) / now firing (fx_outline_side) / dimmed (code). **9-slice (L,T,R,B at ship size):** 40,32,16,16.
- **Note:** Same 9-slice margins as frm_banner, so every anatomy slot lines up; the same image frames the hand banner card. The stencil-style NAME is code text (needs a stencil font: question 5).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A very wide thin card frame, four times wider than tall, made of matte grey-green #5E6B5A painted sheet steel with slightly worn flat paint: a 4-pixel border, a hexagon-shaped notch cut into the top-left corner (for the cost plate), square plain corners elsewhere, one small flat-head screw in each of the other three corners, no shine, no foil, the inside completely empty. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 197. `frm_serial_plate.png` · P1

- **Used in:** Serial plate SI-01 to SI-04 (code text) in the empty abilities slot, top right; red-tinted on enemy Standard Issue squads.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x48. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** yours (normal) / enemy squad (code tint red #E5383B). **9-slice (L,T,R,B at ship size):** 16,12,16,12.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small rectangular stamped metal tag with a slightly raised rim and one round rivet at each end, flat light grey steel #B9C2C9, the face plain and empty. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 198. `frm_socket_empty.png` · P1

- **Used in:** Empty trait / weapon slot, bottom left (Standard Issue cards; NO TRAIT arts in the Codex).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 64x64. **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (code tint grey #7E8890 at 60%).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: a small square socket outline with 45-degree chamfered corners drawn as a dashed rim of eight thick dashes, the inside completely empty. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black, a solid rim, anything inside the square.

##### 199. `frm_socket_locked.png` · P1

- **Used in:** Locked keyword pip on Recruit calling cards (the 'Trains: First Shot - Guard' teaser) and in the inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 64x64. **Background:** white on black: TA converts brightness to alpha.
- **States:** locked (code: socket grey, keyword icon tinted #7E8890 at 45%, this overlay on top) / unlocks (overlay fades, socket lights, New: Keywords).
- **Note:** The keyword icon itself is drawn inside by the code, greyed.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: a small square socket rim with 45-degree chamfered corners and a compact solid padlock shape sitting over its bottom-right corner, the padlock about one third of the socket's width, the inside of the socket empty. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black, a keyword symbol inside, a keyhole too small to see.

### 4.9 Camo bands (5)

#### Level camo bands and Operator mastery ladder (5)

##### 200. `band_base.png` · P1

- **Used in:** Operator base camo tier (OPERATOR badge swatch, Operator frame band); optional Recruit swatch in the deck view.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 512x512 swatch + 512x32 seamless strip. **Background:** opaque, no transparency.
- **States:** normal / shimmer (banner_shimmer shader on animated finishes). **Repeat:** tile horizontally.
- **Note:** Tileable strip. Generate a square swatch; the TA cuts a horizontal strip and makes it seamless (offset + clone, or mirror-tile).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A seamless flat woodland camouflage pattern: rounded blobs of olive #4B5A3A, dark olive #2F3A25 and pale moss #7A8A5A, no other colours, evenly spread over the whole square with no centre focus, flat front-on. Square 1:1.
```

**Avoid:** text, logos, a centre focus, a border or frame, hard seams, colours other than the ones named.

##### 201. `band_gilded.png` · P1

- **Used in:** Trained copies (Gilded band under the art and on the outer edge), Operator gold tier.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 512x512 swatch + 512x32 seamless strip. **Background:** opaque, no transparency.
- **States:** normal / shimmer (banner_shimmer shader on animated finishes). **Repeat:** tile horizontally.
- **Note:** Tileable strip. Generate a square swatch; the TA cuts a horizontal strip and makes it seamless (offset + clone, or mirror-tile).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A seamless pattern of polished gold leaf: the same rounded camouflage blob shapes rendered in bright gold #C9A227, deep gold #7A5E12 and pale gold highlights #F3D36B, a soft metallic sheen, evenly spread over the whole square with no centre focus, flat front-on. Square 1:1.
```

**Avoid:** text, logos, a centre focus, a border or frame, hard seams, colours other than the ones named.

##### 202. `band_forged.png` · P2

- **Used in:** Veteran copies (Forged band), Operator forged tier.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 512x512 swatch + 512x32 seamless strip. **Background:** opaque, no transparency.
- **States:** normal / shimmer (banner_shimmer shader on animated finishes). **Repeat:** tile horizontally.
- **Note:** Tileable strip. Generate a square swatch; the TA cuts a horizontal strip and makes it seamless (offset + clone, or mirror-tile).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A seamless pattern of polished white steel: the same rounded camouflage blob shapes in bright silver #D9DEE3, mid grey steel #7E878F and white highlights, crisp machined metal sheen, evenly spread over the whole square with no centre focus, flat front-on. Square 1:1.
```

**Avoid:** text, logos, a centre focus, a border or frame, hard seams, colours other than the ones named.

##### 203. `band_priceless.png` · P2

- **Used in:** Elite copies (Priceless band), Operator priceless tier.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 512x512 swatch + 512x32 seamless strip. **Background:** opaque, no transparency.
- **States:** normal / shimmer (banner_shimmer shader on animated finishes). **Repeat:** tile horizontally.
- **Note:** Tileable strip. Generate a square swatch; the TA cuts a horizontal strip and makes it seamless (offset + clone, or mirror-tile).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A seamless pattern of deep blue crystal: the same rounded camouflage blob shapes in sapphire blue #3E8EDE, navy #1B3F78 and icy cyan facets #9FE3FF, faceted gem-like sparkle, evenly spread over the whole square with no centre focus, flat front-on. Square 1:1.
```

**Avoid:** text, logos, a centre focus, a border or frame, hard seams, colours other than the ones named.

##### 204. `band_interstellar.png` · P2

- **Used in:** Operator top mastery tier only.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 512x512 swatch + 512x32 seamless strip. **Background:** opaque, no transparency.
- **States:** normal / shimmer (banner_shimmer shader on animated finishes). **Repeat:** tile horizontally.
- **Note:** Tileable strip. Generate a square swatch; the TA cuts a horizontal strip and makes it seamless (offset + clone, or mirror-tile).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A seamless pattern of a violet cosmic nebula: the same rounded camouflage blob shapes filled with deep violet #7B3FC4, near-black indigo #1A0F3A and hot pink star specks #FF7AD9, tiny white stars, evenly spread over the whole square with no centre focus, flat front-on. Square 1:1.
```

**Avoid:** text, logos, a centre focus, a border or frame, hard seams, colours other than the ones named.

### 4.10 Glows, outlines and overlays (11)

#### Glows, outlines, links and previews (additive overlays) (11)

##### 205. `fx_outline_teal.png` · P1

- **Used in:** Selected card / badge outline (teal), valid-target slot.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x160. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** normal / pulse (code alpha). **9-slice (L,T,R,B at ship size):** 32,32,32,32.

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A thin rectangular outline of bright teal #2EC4B6 light with small chamfered corners and a soft glow spreading 12 pixels inside and outside the line, nothing in the middle. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Landscape 3:2.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

##### 206. `fx_outline_side.png` · P1

- **Used in:** Now-firing outline in the owner's colour (tinted teal / red), lift on shot.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x160. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** tinted teal / red. **9-slice (L,T,R,B at ship size):** 32,32,32,32.

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A thin rectangular outline of pure white light with small chamfered corners and a soft glow spreading 12 pixels inside and outside the line, nothing in the middle. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Landscape 3:2.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

##### 207. `fx_glow_amber.png` · P1

- **Used in:** Ready glow: killstreak tile READY, Operator DEPLOY, READY button pulse, order node current.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** pulse (code alpha 0.4 -> 1.0). **9-slice (L,T,R,B at ship size):** 64,64,64,64.

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A soft rounded-square halo of warm amber #FFB020 light, brightest at the edge of an empty dark square centre and fading out smoothly, nothing solid. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Square 1:1.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

##### 208. `fx_glow_red.png` · P2

- **Used in:** Overrun risk pulse, can't-pay flash, set OFF.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** pulse. **9-slice (L,T,R,B at ship size):** 64,64,64,64.

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A soft rounded-square halo of red #E5383B light, brightest at the edge of an empty dark square centre and fading smoothly outward, nothing solid. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Square 1:1.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

##### 209. `fx_link_tick.png` · P1

- **Used in:** Link ticks: vertical (Guard, Spotter) across the row gap, horizontal (Fireteam, Overwatch) across the gutter; tinted by owner.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 32x64. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** active (tint side colour) / ghost (fx_link_tick_ghost) / break flash (code).
- **Note:** Rotate 90 degrees in code for the horizontal ticks.

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A single short vertical bar of pure white light with rounded ends and a soft glow around it, brightest in the core. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Square 1:1.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

##### 210. `fx_link_tick_ghost.png` · P2

- **Used in:** Dashed amber ghost ticks for links a placement would make.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 32x64. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** normal.

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A short vertical dashed bar of three dashes of soft warm amber light, rounded ends, gentle glow. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Square 1:1.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

##### 211. `frm_ghost.png` · P1

- **Used in:** Ghost / placement preview frame in each valid column (PLAY HERE).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal (code tint amber) / protector (TAKES THE FRONT) / invalid (dim). **9-slice (L,T,R,B at ship size):** 20,20,20,20.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A very wide thin rectangular frame drawn as an even dashed line of fog white #D8DEE3 with small corner brackets, the inside completely empty. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

##### 212. `fx_hit_flash.png` · P2

- **Used in:** Hit flash on a banner when damage lands.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x128. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** normal (tinted by damage type).

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A short horizontal burst of white-hot light: a bright core with streaks to the left and right fading out, soft. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Landscape 3:2.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

##### 213. `fx_tracer.png` · P2

- **Used in:** Tracer line from shooter to target (stretched along the path), Pick / Flank curve, Pierce through.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 256x16. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** tinted by side.

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A single long thin horizontal streak of warm white light, brightest at the right end and fading to nothing on the left, soft glow. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Landscape 3:2.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

##### 214. `fx_crack.png` · P3

- **Used in:** Red crack for 2 s when a set switches off (trait rail chip), banner break.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x128. **Background:** white on black: TA converts brightness to alpha.
- **States:** tint red.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: a thin jagged crack line running diagonally with two short branches, pure white. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black.

##### 215. `fx_sheen.png` · P3

- **Used in:** Frame sheen sweep on animated finishes and hover.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** sweep (code moves it).

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A single soft diagonal band of white light, wide and faint, fading at both sides. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Square 1:1.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

## 5. Batches and upload plan

Generate in priority order. **P1 is the minimum that makes the prototype look finished**: every icon the board, tray and strip show in a normal match, the banner and hand frames, the main buttons and panels, the match and column backdrops, and the title, run map and Supply Drop screens. P2 finishes the run screens, menus and feedback. P3 is polish and spare slots.

Each batch is about 10 images (10 to 15 minutes) and one upload. Keep a group (a level-4 heading in section 4) in one ChatGPT chat; when a batch crosses into the next group, start a new chat there.

| Batch | Priority | Group | Images | Files |
|---|---|---|---|---|
| 1 | P1 | Icons (imported, see `ui-kit-import-log.md`) | 10 | `ico_stat_firepower`, `ico_stat_armor`, `ico_stat_cover`, `ico_stat_supply`, `ico_stat_deck`, `ico_stat_intel`, `ico_streak`, `ico_score`, `ico_kw_first_shot`, `ico_kw_pick` |
| 2 | P1 | Number plates | 7 | `plate_fp_s`, `plate_armor_s`, `plate_cost_s`, `plate_cover_s`, `plate_fp_l`, `plate_armor_l`, `plate_cost_l` |
| 3 | P1 | Standard Issue starter (art, frame, plates, New: card) | 12 | `ico_ui_lock`, `kc_b_si_grunt`, `kc_b_si_trooper`, `kc_b_si_sergeant`, `kc_b_si_armored`, `kc_b_si_ammo_resupply`, `frm_standard_issue`, `frm_serial_plate`, `frm_socket_empty`, `frm_socket_locked`, `pnl_new_card`, `pnl_new_inset` |
| 4 | P1 | Icons | 10 | `ico_kw_flank`, `ico_kw_pierce`, `ico_kw_suppress`, `ico_kw_patch`, `ico_kw_protector`, `ico_kw_guard`, `ico_kw_spotter`, `ico_kw_fireteam`, `ico_kw_overwatch`, `ico_effect_bolt` |
| 5 | P1 | Icons | 10 | `ico_trait_vanguard`, `ico_trait_specops`, `ico_trait_heavy`, `ico_trait_undead`, `ico_type_unit`, `ico_type_tactic`, `ico_type_field`, `ico_class_ar`, `ico_class_smg`, `ico_class_shotgun` |
| 6 | P1 | Icons | 10 | `ico_class_sniper`, `ico_class_lmg`, `ico_ks_recon_drone`, `ico_ks_mortar`, `ico_ks_attack_helo`, `ico_ks_sentry`, `ico_ctl_yours`, `ico_ctl_rival`, `ico_ctl_even`, `ico_overrun` |
| 7 | P1 | Icons | 8 | `ico_ui_menu`, `ico_ui_undo`, `ico_ui_speed`, `ico_ui_close`, `ico_ui_back`, `ico_ui_eye`, `ico_ui_eye_off`, `ico_ui_check` |
| 8 | P1 | Card frame parts | 10 | `frm_banner`, `frm_spine_you`, `frm_spine_rival`, `frm_front_tab`, `frm_plan_plate`, `frm_incoming`, `frm_socket`, `frm_operator_banner`, `frm_operator_card`, `frm_operator_mini` |
| 9 | P1 | Card frame parts | 2 | `frm_hand_card`, `frm_put_back` |
| 10 | P1 | Camo bands | 2 | `band_base`, `band_gilded` |
| 11 | P1 | Glows, outlines and overlays | 5 | `fx_outline_teal`, `fx_outline_side`, `fx_glow_amber`, `fx_link_tick`, `frm_ghost` |
| 12 | P1 | Buttons and controls | 7 | `btn_primary`, `btn_primary_pressed`, `btn_secondary`, `btn_secondary_pressed`, `btn_ready`, `btn_ready_pressed`, `btn_badge` |
| 13 | P1 | Panels, trays, rings and strips | 10 | `pnl_tray`, `pnl_flyout`, `pnl_toast`, `pnl_inspector`, `pnl_modal`, `pnl_ks_tile`, `ring_track`, `ring_fill`, `pip_supply`, `pnl_pick_tile` |
| 14 | P1 | Objective and Field tile backers | 2 | `tile_objective`, `tile_field_chip` |
| 15 | P1 | Backgrounds | 7 | `bg_title`, `bg_run_map`, `bg_supply_drop`, `bg_match`, `col_containers`, `col_cranes`, `col_offices` |
| 16 | P2 | Icons | 10 | `ico_stat_discard`, `ico_stat_hand`, `ico_eliminated`, `ico_tickets`, `ico_fired`, `ico_heal`, `ico_damage`, `ico_kw_holder`, `ico_kw_hidden`, `ico_trig_on_deploy` |
| 17 | P2 | Icons | 10 | `ico_trig_on_down`, `ico_kw_aura`, `ico_type_killstreak`, `ico_type_operator`, `ico_elite_star`, `ico_trap`, `ico_plan_mark`, `ico_class_sidearm`, `ico_eq_frag`, `ico_eq_flash` |
| 18 | P2 | Icons | 10 | `ico_ctl_open`, `ico_field_slot`, `ico_ph_deploy`, `ico_ph_reveal`, `ico_ph_firefight`, `ico_ph_score`, `ico_mode_zone_control`, `ico_mode_firefight`, `ico_mode_detonator`, `ico_mode_rival` |
| 19 | P2 | Icons | 10 | `ico_ui_settings`, `ico_ui_skip`, `ico_ui_codex`, `ico_ui_mirror`, `ico_ui_sound_on`, `ico_ui_sound_off`, `ico_ui_info`, `ico_ui_filter`, `ico_ui_continue`, `ico_ui_retire` |
| 20 | P2 | Icons | 2 | `ico_ui_promote`, `ico_ui_reward` |
| 21 | P2 | Number plates | 1 | `plate_cover_l` |
| 22 | P2 | Card frame parts | 8 | `frm_supply_plate`, `fx_ring_tier3`, `frm_band_edge`, `frm_elite`, `frm_dogtag_plate`, `frm_hand_name`, `frm_codex_tile`, `card_back_banner` |
| 23 | P2 | Camo bands | 3 | `band_forged`, `band_priceless`, `band_interstellar` |
| 24 | P2 | Glows, outlines and overlays | 4 | `fx_glow_red`, `fx_link_tick_ghost`, `fx_hit_flash`, `fx_tracer` |
| 25 | P2 | Buttons and controls | 5 | `btn_danger`, `btn_chip`, `btn_chip_on`, `tgl_track`, `tgl_knob` |
| 26 | P2 | Panels, trays, rings and strips | 10 | `pnl_flyout_pointer`, `pnl_tooltip`, `pnl_header`, `pnl_hand_tab`, `pnl_counter`, `pnl_order_strip`, `order_node`, `order_arrow`, `pnl_rail_chip`, `pnl_callout` |
| 27 | P2 | Panels, trays, rings and strips | 3 | `pnl_coach`, `pnl_result`, `runmap_node` |
| 28 | P2 | Objective and Field tile backers | 2 | `tile_field_chip_trap`, `tile_slot_empty` |
| 29 | P2 | Backgrounds | 4 | `bg_after_action`, `bg_codex`, `bg_loadout`, `bg_loading` |
| 30 | P3 | Icons | 10 | `ico_range_close`, `ico_range_mid`, `ico_range_long`, `ico_round`, `ico_ks_gunship`, `ico_att_optic`, `ico_att_grip`, `ico_att_mag`, `ico_att_lining`, `ico_perk_slot` |
| 31 | P3 | Icons | 3 | `ico_ui_rotate`, `ico_ui_survey`, `ico_ui_tutorial` |
| 32 | P3 | Card frame parts | 2 | `frm_equipped`, `card_back_hand` |
| 33 | P3 | Glows, outlines and overlays | 2 | `fx_crack`, `fx_sheen` |
| 34 | P3 | Buttons and controls | 2 | `btn_tab`, `sld_track` |
| 35 | P3 | Panels, trays, rings and strips | 1 | `runmap_path` |
| 36 | P3 | Backgrounds | 1 | `bg_menu` |

P1 is batches 1 to 15 (112 images). At about a minute per image plus a check, that is roughly two hours, best split into three or four sittings. After batch 1 (the first icons) and the first frame batch, pause and let the Technical Artist drop them into the build: if the style needs a tweak, it is cheaper to change the style block then than after 150 images.

## 6. Reject checklist and IP rules

### 6.1 IP rules (binding, same as the banner pack)
- **All original.** No logos, emblems, icons, HUD styling, camo patterns or menus copied from any game, film or brand. The licensed calling cards appear only as card art in the private pitch; nothing in this kit may imitate their frames or the franchise's UI.
- **Never name a franchise, game, studio or artist in a prompt**, even as "not like". The prompts describe looks in plain visual words. Keep it that way when you reword one.
- **No real military marks:** no national or unit insignia, rank badges, roundels, flags, red cross or red crescent. Heal and Patch icons are plain white shapes, tinted green or teal in game, never a red cross.
- **No real products:** weapon and vehicle silhouettes are generic, with no shape that is clearly one real model and no brand marks.
- **No baked text.** The game draws all words and numbers (READY, FRONT, PLAN, A / B / C, EQUIPPED, PUT BACK, costs, stats). Any letter or digit in an image, even fake writing, means regenerate.
- The level names in code (Gilded, Forged, Priceless, Interstellar) are internal ids. The band images are described only by their look (gold leaf, white steel, blue crystal, violet nebula) and must not copy any existing camo pattern.

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
| `plate_*` | `assets/ui/kit/plates/` | rim `plate_<x>_<s or l>.png` + a flood-filled `_fill` copy; same export sizes as icons |
| `kc_b_si_*` | `assets/sprites/banners/` + `data/banners/<id>.tres` | banner pipeline (`banner-art-direction.md` 3.2), curator sets `banner_y` / `portrait_x` |
| `ico_*` | `assets/ui/kit/icons/` | 256 masters; plus the packed atlas `assets/ui/kit/icons/kit_icons.png` (see 7.3) |
| `btn_*`, `tgl_*`, `sld_*` | `assets/ui/kit/buttons/` | |
| `pnl_*`, `ring_*`, `pip_*`, `order_*`, `runmap_*` | `assets/ui/kit/panels/` | |
| `tile_*` | `assets/ui/kit/tiles/` | |
| `frm_*`, `card_back_*` | `assets/ui/kit/frames/` | |
| `band_*` | `assets/ui/kit/bands/` | |
| `fx_*` | `assets/ui/kit/fx/` | |
| StyleBoxTexture resources | `assets/ui/kit/styles/<id>.tres` | built from the manifest margins |
| `bg_*` | `assets/ui/backgrounds/` | replaces `title_key_art`, `bg_run`, `bg_supply_drop` (keep the old files until approved) |
| `col_*` | `assets/sprites/board/` | next to the old `lane_*` |

### 7.2 Processing (per kind, from the raw PNG)
- **luma** (icons, rings, pips, nodes, arrows, path, crack): `magick in.png -colorspace gray -level 8%,92% -alpha copy -fill white -colorize 100 -trim +repage -gravity center -background none -extent <square with 8% padding> -resize 256x256 out.png`. The `-level` crushes JPEG-ish noise near black and white.
- **plate** (number plates): process as luma, then make `_fill` by flood-filling the inside of the rim with white, so the code draws `_fill` tinted dark, then the number, then the rim tinted bright. Keep each plate centred on the same square canvas as its icon, so `ico_stat_firepower` and `plate_fp` line up when swapped.
- **alpha** (plates): if the PNG has real alpha, keep it. If it has a magenta field: `magick in.png -fuzz 12% -transparent "#FF00FF" ...` then despill the edge (shift magenta-tinted edge pixels to the neighbouring colour, or a 1 px alpha erode). Then crop to the plate, resize to the ship size **with the border thickness in mind**: the border should be 4-6 px at ship size.
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

### 7.5 Not in this pack (on purpose)
- Card art and banners (separate packs), the perk patches (already shipped), the call-in tablet (`fx_callin_tablet`, already shipped).
- Fonts (Barlow Condensed, Barlow, Share Tech Mono stay).
- The rival's mirrored arrows and all numbers and words (code).
- Real-time effects that are shaders today (scanlines, banner shimmer, tactical backdrop).
- "Steady" from the brief: there is no Steady keyword in the data or rules today. The real list used here is First Shot, Pick, Flank, Pierce, Cover, Suppress, Patch, Holder, Protector (arrives front), Hidden, the triggers On Deploy / On Down, the ⚡ effect bolt, and the neighbour keywords Guard, Spotter, Fireteam, Overwatch. A new keyword is one more icon prompt in the same group.

### 7.6 Import log and batch feedback
Each imported batch is logged in `ui-kit-import-log.md`: what shipped, where, and style notes for the next batches. **After batch 1:** strokes and gaps should be at least 1/10 of the canvas, with no detail smaller than 1/8 (First Shot's speed lines, Pick's inner bracket mark and Cover's thin arrow blur at 32 px). Keep silhouettes compact and roughly square, because wide glyphs come out small after the trim. Icons ship as a 256 master plus 128/64/48/32 exports, and `UiKit` picks the export by on-screen size (canvas items don't sample mipmaps). Tools: `tools/ui_kit_icons.py`, `scripts/ui/ui_kit.gd`.

## 8. Questions for the head

1. **Hand card frame.** kc-ui4 (in progress in the source) makes hand cards banner cards, between 1.3:1 and 2.4:1 (177x73 on the phone). `frm_hand_card` is drawn for that: the banner frame's steel language with a cost-hex notch, 9-sliced so one image fits every cell. Should hand cards **also wear the side spine and camo band** like the board banner (recommended: the band yes, the spine no, since every hand card is yours), or stay a plain frame?
2. **Backgrounds: replace or keep?** The title, run map and Supply Drop already have Killstreak-era paintings. **Recommended:** regenerate them in this pack (P1) so the KillingCard screens match; keep the old files as the fallback until the new ones are approved.
3. **Icon look.** All icons are solid white pictograms tinted in code (cheapest, reads best at 22 px). The alternative is coloured, bevelled metal icons with the colour baked in, which look richer at 64 px but cost a second image per side and state. **Recommended:** white pictograms now; if you want richer killstreak tiles later, those 4 can get a painted P3 version.
4. ~~Rival stats position~~: answered by card anatomy v3 (kc-trait-ui): one rule for every banner, both sides.
5. **Standard Issue lettering.** The doc asks for stencil lettering on Standard Issue cards. The game has no stencil font (Barlow, Share Tech Mono). **Recommended:** add one OFL stencil font for the Standard Issue NAME and serial plate only; the alternative is plain Barlow Condensed in olive.


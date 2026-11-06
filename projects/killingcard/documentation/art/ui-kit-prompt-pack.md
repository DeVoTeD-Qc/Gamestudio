# KillingCard: UI kit image prompt pack v2

*Author: Sr Game Artist Agent · 2026-11-06 · Board tasks kc-ui-art (v1), kc-ui-art2 (v2: re-based on the card design in the game) · Target: Godot 4.4.1 web (Compatibility), phone landscape 844x390 first, desktop 1440x900*
*For: the studio head (generates in ChatGPT on the phone) and the Technical Artist (cuts, keys, imports).*
*Companion file: `ui-kit-manifest.csv` (one row per image: id, file, category, size, transparency, 9-slice margins, states, where used, priority, final folder, and since v2: status, code id, code hook, code fallback, batch).*

**What changed in v2 (kc-ui-art2).** v1 described the old card parts (number plates, the notched banner frame, the side spine, the serial plate, camo bands on cards, the dog-tag Operator card). The game now has the head's picks from `documentation/ux/card-design-options.html`: **C1+** on the board (full 4:1 art with corner badges: abilities top-right, the FP reticle and the Armor plate bottom-right, traits bottom-left, and the cost hex, level coin and weapon pill top-left on peek), **Y2+** everywhere else (title bar, 4:1 art window, type line, text box, stats bar), the **T1** orders frame for Tactics, and the **O2** Operator card. So v2 **adds 11 slots** (the new Pick icon `kw_pick_v2`, the Y2+ / T1 / Operator / Standard Issue card frames, the orders-paper texture, the rail-highlight glow, the damage crack, and optional painted finishes for the reticle, the Armor plate and the level coin), **retires 28** (kept in the manifest with the reason: section 4.0), revises `frm_standard_issue` (no cost notch), and **re-plans the batches by visual impact** (section 5). Most of the new card is drawn in code and stays that way: an image slot exists only where an image clearly beats the code, and every entry says whether the code fallback is fine.

**198 active images: P1 93, P2 78, P3 27; 9 imported (batch 1), 189 to make in 22 batches. 28 slots retired (226 rows in the manifest).** This pack covers the UI kit around the card art: every icon, button backer, panel, background, and every part needed to build the card frames. The card art itself is not in this pack: the private pitch uses licensed calling cards, the public build uses the banner pack (`banner-art-direction.md`). **Everything here is original**: no logos, brands, franchise insignia, real weapon trademarks, and no text baked in. The game draws every word and number.

What the UI draws today (survey, 2026-11-06): almost all of it is drawn in code. `icon_sheet.svg` holds 34 white line icons (placeholder), `hud_theme.tres` and `card_theme.tres` use flat StyleBoxes, and `banner_view.gd`, `synergy_glyphs.gd`, `strip_badge.gd`, `objective_tile.gd`, `killstreak_row.gd`, `hand_area.gd` and `board.gd` draw badges, plates, bands, ticks and glyphs with `draw_*` calls. The only bitmaps are the Killstreak-era paintings (`title_key_art`, `bg_run`, `bg_supply_drop`, `fx_callin_tablet`, 4 perk patches, 3 square lane backdrops, card art). This pack replaces the code drawing with images where an image looks better, and **keeps the code drawing as the fallback** for every slot.

## 0. Count


| Category | Images | P1 | P2 | P3 |
|---|---|---|---|---|
| Icons | 101 | 44 | 44 | 13 |
| Standard Issue card art | 5 | 5 | 0 | 0 |
| Buttons and controls | 14 | 7 | 5 | 2 |
| Panels, trays, rings and strips | 26 | 12 | 13 | 1 |
| Backgrounds | 12 | 7 | 4 | 1 |
| Objective and Field tile backers | 4 | 2 | 2 | 0 |
| Card frame parts | 18 | 10 | 5 | 3 |
| Camo bands | 5 | 0 | 0 | 5 |
| Glows, outlines and overlays | 13 | 6 | 5 | 2 |
| **Total active** | **198** | **93** | **78** | **27** |
| Retired (kept in the manifest, not generated) | 28 | | | |

## 1. How to use it (on the phone)

1. **One image per prompt, one chat per group.** Open a new ChatGPT chat where a prompt in section 5 says **New chat** (a new group, for example "Keywords"). Inside a group, stay in the same chat so the icons or plates match each other. If ChatGPT asks a question, answer "just generate it".
2. **Shape.** Each prompt says its shape: square (1024x1024), landscape (1536x1024) or portrait (1024x1536). If it comes back in another shape, reply "Same image, square 1:1" (or landscape 3:2 / portrait 2:3).
3. **Don't crop, key or resize on the phone.** Upload the full image. The Technical Artist trims, removes the background and resizes to the *Ship* size.
4. **Fix a bad result in the same chat:** "Regenerate, avoid: ..." and paste the *Avoid* line under the prompt. Two tries, then skip it and note it.
5. **Name the file** as the entry says (`ico_kw_pick_v2.png`). If renaming is a pain on the phone, skip it and type the names in upload order in your message.
6. **Upload** in the **Studio Floor chat: "+ Images / logs"**, one batch at a time (section 5), with the batch's upload line, for example "kc-ui-art2 batch 2: ico_kw_pick_v2, frm_y2_unit, ...". The Technical Artist commits them to `source/project-killingcard/assets/incoming/ui/` (raw, never imported), processes them and moves them to their final folder.

## 2. Style system

### 2.1 Look in one paragraph

A **tactical equipment** look: matte gunmetal and slate plates, thin steel rims with 45-degree chamfered corners, one soft top-left bevel highlight, a faint brushed grain and nothing else. No grunge, rust, scratches, stencil lettering or fake screws along edges. Two exceptions with their own material: the **Standard Issue** grey-green painted steel and the **T1 orders** khaki paper for Tactics. Colour comes only from the game's tokens: **side colours** (teal you, red rival: only the FP reticle, selection and control marks carry them), **amber** for "act now" (READY, primary buttons, ready killstreaks, cost), **brass** for the Operator, **trait colours** on trait pips, **green / red** for buffs and debuffs. Icons are **bold white pictograms** that the code tints, so one icon serves every state and both sides. Backgrounds are the same **duotone dusk paintings** as the Killstreak art (title, run map), kept dark and calm so cards and white text read on top.

Readability at phone size is the rule: an ability icon is **21 px** on a C1+ board card (k = banner height / 57), the FP reticle 26 px and the Armor plate 25 px, a trait chip 20 px, the peek group 17-20 px, a strip badge 62x64, an X1 hand card 177x70, a Y2+ card 172-330 px wide (kc-cards-impl). Every icon must read at **24 px**; plates must look right with their border at 2 to 3 logical px.

### 2.2 Colour tokens (from the current code: keep in sync)

| Token | Hex | Used for | Source |
|---|---|---|---|
| Slate (ink) | `#12161A` | Deepest background, recessed faces, text on amber | `fx_style.gd`, `card_theme.tres` background |
| Gunmetal | `#232A31` | Panels, tiles, button faces | `fx_style.gd`, `objective_tile.gd` |
| Panel / panel hi | `#232A31` / `#2E3740` | Raised panels, hover | `card_theme.tres` panel_hi |
| Steel | `#3A444D` | Rims and outlines | `banner_view.gd`, `objective_tile.gd` |
| Edge grey | `#4A535B` | Button and modal outlines | `hud_theme.tres` |
| Light steel | `#B9C2C9` (fill `#2A3238`) | Armor plate rim (both sides), Recruit level coin, neutral marks, dashed EVEN | `card_look.gd` |
| Fog white | `#D8DEE3` | Text, white icons | everywhere |
| Muted | `#7D8790` / `#9AA5AE` | Idle icons, captions | `killstreak_row.gd`, `match_screen.gd` |
| **You (friend)** | `#2EC4B6` (deep `#0F2F2C`) | Your FP reticle, selection outline, control YOURS, link ticks | `card_theme.tres` friend, `card_look.gd` TEAM |
| **Rival (enemy)** | `#E5383B`, reticle `#FF5A5D` (deep `#341113`) | Rival FP reticle, control RIVAL, INCOMING, danger | `card_theme.tres` enemy, `card_look.gd` TEAM |
| **Amber** | `#FFB020` (pressed `#E59A12`) | READY, primary buttons, cost hex, ready glow, ghosts | `hud_theme.tres`, `card_theme.tres` accent |
| Damaged | `#F2A33A` (fill `#4A3412`, number `#FFC067`) | Armor plate when hurt, the amber bottom edge, the corner crack | `card_look.gd` |
| **Brass (Operator)** | `#C9A227`, dark `#5A4512` / `#3A2D0B` | Operator frame (Y2+, O2), board keyline, dog tag, PLAN tag, Elite; level coin T / V / E `#F3D36B` | `banner_view.gd`, `card_look.gd`, `card_view.gd` |
| Cyan (special) | `#5BC0EB` | Killstreak charge, tech | `card_theme.tres` special |
| **Buff up** | `#7CF29A` | Buffed FP number (green), synergy chips | `card_look.gd`, `synergy_glyphs.gd` UP |
| **Debuff down** | `#FF6B6B` | Lowered number, set OFF | `synergy_glyphs.gd` DOWN |
| Heal | `#8EDB6A` | UNDEAD HEAL, heal numbers | `feedback_director.gd` |
| Trait Vanguard | `#F2B544` | Trait chip (45% faint / lit + glow), rail chip, rail-highlight glow | `synergy_glyphs.gd` |
| Trait Spec Ops | `#8FB8FF` | | |
| Trait Heavy | `#C9D1D8` | | |
| Trait Undead | `#8EDB6A` | | |
| Band Gilded | `#C9A227` / `#7A5E12` / `#F3D36B` | Run-screen level swatches only (cards show the level coin since kc-cards-impl) | `synergy_glyphs.gd` BANDS |
| Band Forged | `#D9DEE3` / `#7E878F` / `#FFFFFF` | Veteran level band | |
| Band Priceless | `#3E8EDE` / `#1B3F78` / `#9FE3FF` | Elite level band | |
| Band Interstellar | `#7B3FC4` / `#1A0F3A` / `#FF7AD9` | Operator top tier only | `banner_view.gd` |
| Band base camo | `#4B5A3A` / `#2F3A25` / `#7A8A5A` | Operator base tier | `banner_view.gd` |

| Card frame steel | `#4A5560` / face `#1B2126` | Y2+ unit frame | `card_view.gd` FRAME_UNIT |
| T1 orders khaki | `#B8913A` / face `#2B2716` | Y2+ Tactic frame, orders paper | `card_view.gd` FRAME_T1 |
| Operator face | `#1E1A10` | Y2+ / O2 Operator face | `card_view.gd` FACE_OP |
| Standard Issue | `#5E6B5A` / dark `#353D33` | Standard Issue frames | `standard_issue_look.gd` |

Rule: **tintable pieces are generated white or neutral**, and the code applies the token. Only pieces whose colour never changes (amber buttons, brass Operator, the Y2+ / T1 / Standard Issue frames, bands) have their colour baked in. The optional painted stat badges are neutral steel and the code modulates them (teal / red reticle, amber damaged plate, brass coin).

### 2.3 What is one image, and what is built from parts

| Thing on screen | Built from | Image or code |
|---|---|---|
| **C1+ board card** (4:1: 228x57 phone, 304x76 desktop) | the calling card art, full and never dimmed + a thin code keyline (brass for the Operator and Elite, `frm_standard_issue` for Standard Issue) + the abilities chip top-right (`ico_kw_*`, `ico_kw_pick_v2`, the bolt, `frm_socket_locked` padlocks) + the FP reticle and Armor plate bottom-right + trait chips bottom-left + on peek the cost hex, level coin and weapon pill top-left + PLAN tag / frontline keyline / ghost / target reticle | Art and icons are images. Reticle, plate, chips, hex, coin, pill, keylines are **code** (`CardLook`); `plate_fp_reticle`, `plate_armor_ballistic`, `coin_level` are optional painted finishes. |
| **Damaged** | the code's amber bottom edge + the corner crack | `fx_crack_damage` (optional; code crack is fine) |
| **Rail highlight** | matching cards glow in the trait colour, the rest dim to 45% | `fx_glow_rail` (tinted per trait) |
| **X1 hand card** | the C1+ card with everything shown + a code name plate | no frame image |
| **Y2+ card** (172-330 px wide) | `frm_y2_unit` / `frm_y2_operator` / `frm_y2_standard_issue` (9-slice) + code title bar, 4:1 art window, type line (OPERATOR / STANDARD ISSUE / TACTIC tag, weapon, level coin), text box (keyword icon + name + rule), stats bar (traits left, FP / Armor right) | frame image, the rest code |
| **T1 Tactic card** | `frm_t1_orders` (khaki paper, chevron-cut top-right) + `tex_orders_paper` tiled + the same title, art, type line and a bigger text box (no stats bar) | frame + texture images |
| **O2 Operator card** | `frm_y2_operator` + art + cost hex (red when short of Supply) + OPERATOR tag + abilities + FP / Armor + state chip (code) | frame image |
| **Objective tile** | `tile_objective` + `ico_ctl_*` + 2 `tile_field_chip` + words (code) | |
| **Buttons** | one 9-slice plate per family + pressed plate + overlays; label is code text | |
| **Killstreak tile** | `pnl_ks_tile` + `ring_track` + `ring_fill` (radial progress) + `ico_ks_*` + `fx_glow_amber` | |
| One image | backgrounds, column backdrops, `frm_incoming`, card backs | Nothing on them changes. |

**9-slice pieces** (all margins in the manifest, at ship size): every `btn_*` (except `tgl_knob`), `pnl_tray`, `pnl_flyout`, `pnl_toast`, `pnl_inspector`, `pnl_tooltip`, `pnl_modal`, `pnl_header`, `pnl_hand_tab`, `pnl_counter`, `pnl_order_strip`, `pnl_rail_chip`, `pnl_callout`, `pnl_pick_tile`, `pnl_coach`, `pnl_result`, `pnl_new_card`, `pnl_new_inset`, `tile_objective`, `tile_field_chip(_trap)`, `tile_slot_empty`, `frm_standard_issue`, `frm_front_tab`, `frm_plan_plate`, `frm_dogtag_plate`, `frm_ghost`, `fx_outline_*`, `fx_glow_*`, and new in v2 `frm_y2_unit`, `frm_y2_operator`, `frm_y2_standard_issue`, `frm_t1_orders`, `fx_glow_rail`. Bands and `tex_orders_paper` **tile** instead. (The v1 banner, hand, Codex, Operator, Elite, spine and band-edge frames are retired: section 4.0.)

### 2.4 Icons: one pipeline for all of them

- **Generate** every icon as a **solid white glyph on pure black**, 1024x1024. This is the most reliable thing ChatGPT does: no fake transparency, no checkerboard, no coloured fringes.
- **The TA turns brightness into alpha** (white = opaque, black = clear), so edges stay smooth, then trims to the glyph with 8% padding and ships a **256x256 master**, plus 128 / 64 / 48 / 32 exports or one atlas (section 7).
- **The code tints** (modulate): teal or red by side, amber when ready, trait colour when lit, `#7E8890` when idle, `#FF6B6B` / `#7CF29A` for trends. A dark 1-2 px outline for icons over bright licensed art is added in code (shadow or outline shader), not in the image.
- **Arrows that depend on the side** (Guard points behind, Spotter points ahead) stay code-drawn on top of the base icon, because the rival's banners are mirrored.
- On-screen sizes: abilities 21 px on the phone board (x k), trait chips 20 px, the FP reticle 26 px, the Armor plate 25 px, in the Y2+ stats bar 22 / 28 / 27 px, up to about 52 px in the inspector (section 2.8); strip badge glyphs ~32 px; killstreak tiles 61 px (icon ~36 px in the ring); Codex filters 24 px; menu icons 28-36 px.

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
| side | tint (teal / red) for white or neutral pieces; only the FP reticle and selection / control marks carry the side colour. The colour-blind cue is the board half (yours below, the rival's above) |

### 2.7 The style blocks (already inside every prompt)

Each prompt = **style block + subject + background tail**, already joined. There are six blocks: icon (also used for the white parts: rings, pips, nodes), UI parts, the orders-paper variant of UI parts (v2, T1 only), light effects, backgrounds and Standard Issue art. They are listed here so the set can be tuned in one place; if one changes, edit `ui-kit-pack-src/` and regenerate this file and the manifest: `cd documentation/art/ui-kit-pack-src && python3 -I gen.py . ../ui-kit-prompt-pack.md ../ui-kit-manifest.csv head.md style.md tail.md` (slots live in `slots.py`).

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

**Orders paper style** (v2: `frm_t1_orders`, `tex_orders_paper`; the UI parts block with paper in place of metal)

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering of matte field-orders paper: dark olive-brown and khaki, a faint even fibre grain, crisp straight edges, no grunge, no stains, no folds, no wear marks. Bold simple shapes that stay readable when shrunk small. Palette: olive-brown #2B2716, dark olive #1F1C10, khaki #B8913A, pale khaki #D9C48A, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, stamps, seals, insignia, flags or emblems.
```

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

Tail: `Wide 3:2 landscape that will be cropped to a thin 4:1 strip across the middle (30% to 66% of the height) and a tall 2:3 column in the centre. Put the figure in the exact centre, head and hands between 30% and 65% of the height, inside the middle 60% of the width. The four corners of that strip stay empty, flat and calm, because the game puts small badges there: abilities top right, the traits bottom left, the firepower and armour badges bottom right, and the cost and level top left. Above and below, continue the plain background. No text, letters, numbers, stencils, serial numbers, logos, insignia, flags, badges, patches or symbols on clothing, gear or crates. Invented people only, faces simple or shaded by the helmet. No blood.`

### 2.8 Card anatomy v4: C1+ on the board, Y2+ off it (kc-cards-impl, the head's picks)

The head's rules still hold: **the same icon for a concept everywhere, in the same corner on every card**, one rule for both sides, no mirroring. What changed: stats are no longer number plates in an icon shape; they are the **FP reticle** (team colour) and the **Armor plate** (grey, amber when damaged), drawn by `CardLook` and shared by every card form.

```
 C1+ board card 4:1 (228x57 phone, 304x76 desktop; sizes x k = height / 57)
 /‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\
 |<COST><R><SNIPER>  (peek only)        [KW][PICK][bolt]   |   top-left (peek: hover / hold, hand, setting): cost hex 20, level coin 17, weapon pill 18
 |                                                         |   top-right (always): abilities 21 on one dark chip, Recruit padlocks
 |       full calling-card art, never dimmed or cropped    |
 |                                                         |
 |[T][T]                                     (FP) [AR]     |   bottom-left: trait chips 20 (45% faint / lit + glow)
 \_________________________________________________________/   bottom-right: FP reticle 26 + Armor plate 25 (Cover chip left of them when > 0)
   damaged: amber bottom edge + crack in the top-left corner; no spine, no band, no serial plate, no name on the board

 Y2+ card (172-330 px wide; 250x216 in the inspector / dock)       T1 Tactic: the same, khaki orders paper, top-right chevron cut,
 +-------------------------------------+                           no stats bar, a bigger text box
 | (C) NAME (title style)              |  title bar 30
 | [ 4:1 art window, nothing on it ]   |  (W - 8) / 4
 | OPERATOR · SNIPER · (T)             |  type line 22: tag, weapon, level coin
 | [kw] FIRST SHOT  rule ...           |  text box 3 x 19
 | [T][T]                   (FP) [AR]  |  stats bar 32
 +-------------------------------------+
```

| Where | What | Image slot | Code |
|---|---|---|---|
| Board, top-right | abilities, bolt, Recruit padlocks | `ico_kw_*`, `ico_kw_pick_v2`, `ico_effect_bolt`, `frm_socket_locked`, `ico_ui_lock` | dark chip backing |
| Board, bottom-right | FP reticle (teal yours / red rival, green number when buffed), Armor plate (grey, amber damaged, only the number left), Cover chip | optional `plate_fp_reticle`, `plate_armor_ballistic`; `ico_stat_cover` | `CardLook.draw_reticle`, `draw_armor` |
| Board, bottom-left | trait chips | `ico_trait_*` | square chip, faint / lit glow (`CardLook.draw_trait`) |
| Board, top-left (peek) | cost hex, level coin (R grey, T / V / E brass), weapon pill (name only) | optional `coin_level` | `draw_cost`, `draw_level_coin`, `draw_weapon_pill` |
| Board, damaged | amber bottom edge, corner crack | optional `fx_crack_damage` | `draw_damage_edge`, `draw_crack` |
| Board, rail highlight | matching cards glow in the trait colour, the rest dim | `fx_glow_rail` | today two `draw_rect` lines |
| Y2+ frame | unit / Operator / Standard Issue / Tactic | `frm_y2_unit`, `frm_y2_operator`, `frm_y2_standard_issue`, `frm_t1_orders` + `tex_orders_paper` | `CardView._draw` polygons |
| Y2+ inside | title, art window, type line, text box, stats bar | none (plain face) | `CardView` |

Rules that keep the parts lined up:
- **Frames have plain faces.** The Y2+ frames are a rim and a flat face; the code lays out everything inside, so one 9-slice fits every width from 172 to 330 px.
- **Art safe zones:** all four corners of the 4:1 band stay calm (about 30% of the width by 40% of the height at each end), since the badges sit there. There is no scrim any more (kc-hand-dim retired): each badge group sits on its own small dark chip.
- **One silhouette per concept:** FP is the gapped reticle ring (`ico_stat_firepower` matches it). Armor is the clipped-corner ballistic plate. Cover is the barrier block. Cost and Supply are the hexagon. **Pick is a shield with a down arrow** (`kw_pick_v2`), so no keyword is a crosshair any more. Guard is a block wall and Spotter binoculars.
- **Side colour lives on the FP reticle only** (and selection / control marks). Armor is grey on both sides and amber when damaged, never red, because red means the rival.
- **Standard Issue reads as basic kit:** olive two-tone art, the grey-green painted frame, no traits, no glow, no animation, no serial plate, and the one title style (the stencil font is retired).

## 3. Size key

| Kind | Generate | Ship to the TA | In game |
|---|---|---|---|
| Icon | 1024x1024 square | 256x256 master, trimmed + 8% padding; exports 128/64/48/32 | 22-64 px |
| Standard Issue card art (`kc_b_si_*`) | 1536x1024 | 1152x768 master (banner pipeline, `banner-art-direction.md` 3.2) | banners and hand cards |
| Painted stat badges (`plate_fp_reticle`, `plate_armor_ballistic`, `coin_level`, optional) | 1024x1024 | 128x128 (coin 64x64), alpha | 16-52 px |
| Y2+ / T1 card frames (`frm_y2_*`, `frm_t1_orders`) | 1024x1024 | 500x432 (2x the 250x216 card), drawn at 0.5 scale | 172-330 px wide |
| Orders paper (`tex_orders_paper`) | 1024x1024 | 256x256 seamless tile | tiled at 60% |
| Small part (socket, pip, knob) | 1024x1024 | 64-128 px (manifest) | 22-61 px |
| Plate / panel / button (9-slice) | 1536x1024 or 1024x1536 | 2x the largest on-screen size, borders 4-6 px at ship size (manifest) | drawn at 0.5x scale (see 7.4) |
| Board 4:1 parts (`frm_standard_issue`, `frm_incoming`, `fx_glow_rail`) | 1536x1024; TA crops a 4:1 band | 512x128 (glow 576x192 with its halo) | 228x57 / 304x76 |
| Camo band (P3, run-screen swatches only) | 1024x1024 swatch | 512x512 + a 512x32 seamless strip | level swatches |
| Full-screen background | 1536x1024 | 1536x864 (crop 80 px top and bottom); the phone shows the middle 1536x710 | 1168x540 phone, 1280x800 desktop |
| Column backdrop | 1024x1536 | crop the middle 648x1536, resize to 512x1216 | 228x537 at 34% opacity |


## 4. Slot catalogue

**kc-ui-art2.** The catalogue now follows the card design in the game (kc-cards-impl: C1+ on the board, Y2+ with the T1 orders frame off it, the O2 Operator card). Each entry gives its **status** (imported, active, revised, new), the **code id** the game asks `UiKit` / `IconSheet` for, whether that lookup exists today (*wired*) or still has to be added (*needs code*), and whether the code-drawn fallback is good enough. **The prompts themselves are in section 5**, in the order you generate them, so each one is written once; the entry number below (for example **Batch 2.3**) points to it.

### 4.0 Retired slots (28)

Not generated. The rows stay in `ui-kit-manifest.csv` with `status` = RETIRED and the reason, so old notes and the import log still resolve.

| Slot | Was for | Why retired |
|---|---|---|
| `ico_kw_pick` | Banner effect slot, Pick tracer tag, inspector | Imported in batch 1, but Pick is no longer a crosshair (it clashed with the FP reticle). IconSheet now asks for kw_pick_v2 (a shield with a down arrow) and never loads ico_kw_pick.png; the file can be removed. |
| `ico_class_sidearm` | STREAK flyout P-12 tile, Loadout secondary slot, Operator secondary | The sidearm / Operator secondary is gone from the game. |
| `ico_eq_frag` | STREAK flyout FRAG tile (Lethal), Loadout lethal slot, cooldown | Frag / flashbang Operator equipment is gone from the game. |
| `ico_eq_flash` | STREAK flyout FLASH tile (Tactical), Loadout tactical slot, cooldown | Frag / flashbang Operator equipment is gone from the game. |
| `frm_banner` | Every board banner (228x57 phone, 304x76 desktop, 512x128 inspector): the steel frame around the art | C1+ shows the full calling-card art with only a thin code keyline, so the steel frame with a cost-hex notch has nothing left to frame. |
| `frm_spine_you` | Side edge strip on your banners (outer long edge, away from the objective) | C1+ has no side spine (the side is told by the board half and the FP reticle colour). |
| `frm_spine_rival` | Side edge strip on rival banners (shape differs from yours for colour-blind players) | C1+ has no side spine (the side is told by the board half and the FP reticle colour). |
| `frm_supply_plate` | Operator card '1 SUPPLY' plate in place of the cost hex; red when you can't pay | The Operator card uses the standard cost hex, red when you are short of Supply. |
| `frm_socket` | Socket for keyword pip, trait pip, class pip and effect glyph (22 px phone, 26 desktop) | Trait chips are code-drawn squares (faint 45% / lit with a glow) and abilities sit on one dark code chip; no per-pip socket. |
| `fx_ring_tier3` | White ring around a trait pip at set tier 3 (banner, rail) | Trait chips only have two states now (faint / lit); there is no tier-3 ring. |
| `frm_band_edge` | Thin metal edge that caps a camo band strip top and bottom | Cards no longer carry a camo / level band (the level is the level coin), so nothing caps a band strip. |
| `frm_elite` | Elite chassis banner and hand card frame (gold frame + star) | Elite is a brass keyline on the board (code) and a gold rim on the Y2+ card; no separate frame image. |
| `frm_operator_banner` | The Operator's banner on the board (brass frame, camo band on the outer edge, dog-tag plate) | The Operator's board banner is the C1+ card with a brass code keyline and the dog tag; no brass frame or camo band. |
| `frm_operator_card` | Operator card pinned first in the tray (99x124 phone, 108x136 desktop) | O2 replaced the dog-tag card: the Operator card is the Y2+ brass card (frm_y2_operator) with an OPERATOR tag. |
| `frm_operator_mini` | Mini Operator card (half height, ON BOARD / C · ROW 1) while the Operator is on the board | The half-height mini Operator card is gone (O2 keeps one Operator card bottom-left of the tray). |
| `frm_hand_card` | Hand banner card frame in the tray (kc-ui4 board-form: 177x73 phone, 224x64 desktop, 103x78 on 16:9), mulligan cards, Supply Drop picks | The X1 hand card is the C1+ banner (full art) plus a code name plate; no notched hand frame. |
| `frm_hand_name` | Name band across the middle of a narrow hand banner card (16:9 phones), stats row | The X1 name plate is code (26 px, the one title style). |
| `frm_codex_tile` | Codex tile (120x156 compact): art, cost hex, name, chassis line | The Codex shows Y2+ cards (frm_y2_unit / frm_y2_operator / frm_t1_orders). |
| `frm_equipped` | FOUND / EQUIPPED corner mark on Codex tiles (word drawn by code); kc-trait-ui removed EQUIP, so it now marks FOUND arts | Codex tiles are Y2+ cards now (NOT FOUND YET veil in code); there is no EQUIPPED / FOUND corner mark. |
| `plate_fp_s` | Firepower number plate, bottom right of every card, left of Armor (small: 22-34 px: board banners, hand banner cards, Codex tiles) | C1+ / Y2+ draw FP as the reticle ring in team colour (CardLook.draw_reticle); the optional painted finish is plate_fp_reticle. |
| `plate_armor_s` | Armor number plate, bottom right of every card, right of FP (small: 22-34 px: board banners, hand banner cards, Codex tiles) | Armor is now the grey ballistic plate with clipped top corners (CardLook.draw_armor), not the pointed plate; the optional painted finish is plate_armor_ballistic. |
| `plate_cost_s` | Cost plate, top left of every card (small: 22-34 px: board banners, hand banner cards, Codex tiles); the hexagon is the Supply shape everywhere (pips, Supply row) | The cost hex is drawn in code (CardLook.draw_cost: amber, red when you can't pay); no frame notch to sit in any more. |
| `plate_cover_s` | Cover number plate, bottom right, left of FP, only when Cover > 0 (small: 22-34 px: board banners, hand banner cards, Codex tiles) | Cover stays the small chip with the stat_cover icon left of FP (banner_view._draw_cover_chip); no Cover number plate. |
| `plate_fp_l` | Firepower number plate, bottom right of every card, left of Armor (large: 48-128 px: inspector, reward and pick tiles, Operator flyout, After-Action) | C1+ / Y2+ draw FP as the reticle ring in team colour (CardLook.draw_reticle); the optional painted finish is plate_fp_reticle. |
| `plate_armor_l` | Armor number plate, bottom right of every card, right of FP (large: 48-128 px: inspector, reward and pick tiles, Operator flyout, After-Action) | Armor is now the grey ballistic plate with clipped top corners (CardLook.draw_armor), not the pointed plate; the optional painted finish is plate_armor_ballistic. |
| `plate_cost_l` | Cost plate, top left of every card (large: 48-128 px: inspector, reward and pick tiles, Operator flyout, After-Action); the hexagon is the Supply shape everywhere (pips, Supply row) | The cost hex is drawn in code (CardLook.draw_cost: amber, red when you can't pay); no frame notch to sit in any more. |
| `plate_cover_l` | Cover number plate, bottom right, left of FP, only when Cover > 0 (large: 48-128 px: inspector, reward and pick tiles, Operator flyout, After-Action) | Cover stays the small chip with the stat_cover icon left of FP (banner_view._draw_cover_chip); no Cover number plate. |
| `frm_serial_plate` | Serial plate SI-01 to SI-04 (code text) in the empty abilities slot, top right; red-tinted on enemy Standard Issue squads | No serial plate on cards any more (kc-cards-impl: the Standard Issue frame says it, the inspector names it). |

### 4.1 Icons (101)

#### Stats and resources (19)

##### `ico_stat_firepower.png` · P1 · Batch 1 · **imported (batch 1)**

- **Used in:** FP badge on every banner, hand card, inspector, Operator flyout, ghosts.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `stat_firepower` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.
- **Note:** kc-ui-art2: Imported (batch 1). Its broken ring matches the new reticle; used by the tray mini stats and the killfeed.

##### `ico_stat_armor.png` · P1 · Batch 1 · **imported (batch 1)**

- **Used in:** Armor badge on every banner and hand card (amber when damaged, by tint).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `stat_armor` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.
- **Note:** kc-ui-art2: Imported (batch 1). Used by the tray mini stats; its pointed plate differs a little from the new clipped-corner plate (fine at 14 px; redo as stat_armor_v2 only if the head wants it to match).

##### `ico_stat_cover.png` · P1 · Batch 1 · **imported (batch 1)**

- **Used in:** Cover chip left of the Armor badge; Cover-absorbed hit (-0); Field auras.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `stat_cover` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_stat_supply.png` · P1 · Batch 1 · **imported (batch 1)**

- **Used in:** Supply row in the tray (SUPPLY 3/4), Operator '1 SUPPLY' plate, cost tooltips.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `stat_supply` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_stat_deck.png` · P1 · Batch 1 · **imported (batch 1)**

- **Used in:** DECK badge (strip bottom), deck view button on run map and rewards.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `stat_deck` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_stat_discard.png` · P2 · Batch 12.1

- **Used in:** Used / discard count in the DECK flyout.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `stat_discard` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_stat_hand.png` · P2 · Batch 12.2

- **Used in:** HAND · n PEEK tab, hand cap in the score sheet.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `stat_hand` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_stat_intel.png` · P1 · Batch 1 · **imported (batch 1)**

- **Used in:** RIVAL badge, red-dot reveal, Recon tooltips, intel lines in flyouts.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `stat_intel` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.
- **Note:** Replaces intel_contact in the old sheet (keep the id alias).

##### `ico_range_close.png` · P3 · Batch 20.1

- **Used in:** Range word chip on the objective tile, class tooltips.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (tint).
- **Code id:** `range_close` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_range_mid.png` · P3 · Batch 20.2

- **Used in:** Range chip on the objective tile.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (tint).
- **Code id:** `range_mid` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_range_long.png` · P3 · Batch 20.3

- **Used in:** Range chip on the objective tile.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (tint).
- **Code id:** `range_long` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_streak.png` · P1 · Batch 1 · **imported (batch 1)**

- **Used in:** STREAK badge, streak meter in the flyout, after-action BEST STREAK.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `streak` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_eliminated.png` · P2 · Batch 12.3

- **Used in:** Killfeed toast and log, after-action ELIMINATIONS, elimination stamp.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `eliminated` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_tickets.png` · P2 · Batch 12.4

- **Used in:** REINFORCEMENT TICKETS on the run map, run end.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `tickets` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_round.png` · P3 · Batch 20.4

- **Used in:** Round counter in the SCORE badge flyout and the pause header.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `round` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_fired.png` · P2 · Batch 12.5

- **Used in:** Fired pip on each banner that has shot this round (cleared at Score).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `fired` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** NEW: the fired pip is a firefight-order.md UI need, not built yet.

##### `ico_heal.png` · P2 · Batch 12.6

- **Used in:** Heal number (+n) from Patch, Aid Station and Undead (tinted teal or green, never red).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `heal` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_damage.png` · P2 · Batch 12.7

- **Used in:** Hit marker beside damage numbers, killfeed, now-firing tracer end.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `damage` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_score.png` · P1 · Batch 1 · **imported (batch 1)**

- **Used in:** SCORE badge, score sheet, after-action SCORE.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `score` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

#### Keywords (17)

##### `ico_kw_first_shot.png` · P1 · Batch 1 · **imported (batch 1)**

- **Used in:** Banner effect slot, hand card, inspector, FIRST SHOT tag in the Firefight.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `kw_first_shot` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_kw_flank.png` · P1 · Batch 4.1

- **Used in:** Banner effect slot, Flank tracer tag, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `kw_flank` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_kw_pierce.png` · P1 · Batch 4.2

- **Used in:** Banner effect slot on Marksman and Ace, '-1 PIERCE' second number, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `kw_pierce` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_kw_suppress.png` · P1 · Batch 4.3

- **Used in:** Banner effect slot (Gunner), suppressed status, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `kw_suppress` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_kw_patch.png` · P1 · Batch 4.4

- **Used in:** Banner effect slot (Combat Medic), heal tag, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `kw_patch` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_kw_holder.png` · P2 · Batch 12.8

- **Used in:** Banner effect slot, control tooltip (counts for holding the column).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `kw_holder` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_kw_protector.png` · P1 · Batch 4.5

- **Used in:** Banner effect slot, TAKES THE FRONT preview, Protector slide.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `kw_protector` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_kw_hidden.png` · P2 · Batch 12.9

- **Used in:** Hidden Field traps (Tripwire), hide-from-intel effects, dashed TRAP chip.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `kw_hidden` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_kw_guard.png` · P1 · Batch 4.6

- **Used in:** Keyword pip on Trained banners and hand cards, link preview, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `kw_guard` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** Neighbour-link arrows (Guard down, Spotter up) are drawn by the code so they can flip for the rival; the icon is only the base shape. Not a shield: the shield shape is Armor.

##### `ico_kw_spotter.png` · P1 · Batch 4.7

- **Used in:** Keyword pip, link preview, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `kw_spotter` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** Neighbour-link arrows (Guard down, Spotter up) are drawn by the code so they can flip for the rival; the icon is only the base shape. Not an eye: the eye is the PREVIEW toggle.

##### `ico_kw_fireteam.png` · P1 · Batch 4.8

- **Used in:** Keyword pip, link preview, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `kw_fireteam` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_kw_overwatch.png` · P1 · Batch 4.9

- **Used in:** Keyword pip, link preview, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `kw_overwatch` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_trig_on_deploy.png` · P2 · Batch 12.10

- **Used in:** 'On deploy' effect line and banner effect slot.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `trig_on_deploy` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_trig_on_down.png` · P2 · Batch 13.1

- **Used in:** 'On down' effect line and banner effect slot.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `trig_on_down` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_effect_bolt.png` · P1 · Batch 4.10

- **Used in:** Banner effect slot for triggered or aura text (with a dot if more), Field auras.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `effect_bolt` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_kw_aura.png` · P2 · Batch 13.2

- **Used in:** Field aura marker on banners in a Field's column, objective tile chip.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `kw_aura` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_kw_pick_v2.png` · P1 · Batch 2.1 · **new (kc-ui-art2)**

- **Used in:** Pick everywhere: C1+ abilities chip, Y2+ text box, glossary, inspector, Pick tracer tag.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `kw_pick_v2` (wired: IconSheet.get_icon(&"kw_pick") asks UiKit for kw_pick_v2 (glossary, inspector, Y2+ text box). Board: banner_view.gd draws kind &"kw_pick" with CardLook.draw_pick_icon directly; change it to UiKit.draw_icon(o, &"kw_pick_v2", rr, ...) first). **Fallback:** code fallback works, but the image clearly beats it.
- **Note:** Replaces kw_pick (crosshair). Pick shoots the lowest Armor: the shield is Armor, the arrow is 'the lowest'. Same shape as the built-in glyph (IconSheet.PICK_SVG), so the switch is invisible except for the finish.

#### Traits (4)

##### `ico_trait_vanguard.png` · P1 · Batch 5.1

- **Used in:** Trait pip on banners and hand cards, trait rail, SETS flyout, Doctrine tiles, deck view.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `trait_vanguard` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_trait_specops.png` · P1 · Batch 5.2

- **Used in:** Trait pip, rail, flyout, Doctrine, deck view.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `trait_specops` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_trait_heavy.png` · P1 · Batch 5.3

- **Used in:** Trait pip, rail, flyout, Doctrine, deck view.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `trait_heavy` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_trait_undead.png` · P1 · Batch 5.4

- **Used in:** Trait pip, rail, flyout, Doctrine, deck view, UNDEAD HEAL tag.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `trait_undead` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

#### Card types and card marks (8)

##### `ico_type_unit.png` · P1 · Batch 6.1

- **Used in:** Hand card type glyph, Codex UNITS filter, inspector type line.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `type_unit` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_type_tactic.png` · P1 · Batch 6.2

- **Used in:** Hand card type glyph, Codex TACTICS filter, inspector.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `type_tactic` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_type_field.png` · P1 · Batch 6.3

- **Used in:** Hand card type glyph, Codex FIELDS filter, objective Field chips.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `type_field` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.
- **Note:** Was type_equipment in the old sheet (keep the id alias).

##### `ico_type_killstreak.png` · P2 · Batch 13.3

- **Used in:** Codex KILLSTREAKS filter, killstreak inspector, run rewards.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `type_killstreak` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_type_operator.png` · P2 · Batch 13.4

- **Used in:** Operator plate, Operator flyout header, OPERATOR badge (with the camo swatch).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `type_operator` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_elite_star.png` · P2 · Batch 13.5

- **Used in:** Elite chassis mark on banners, hand cards and Codex tiles (Ace, Commander).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `elite_star` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_trap.png` · P2 · Batch 13.6

- **Used in:** Hidden Field (trap) chip on the objective tile, dashed.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `trap` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_plan_mark.png` · P2 · Batch 13.7

- **Used in:** PLAN / INCOMING marker, rival planned-per-column intel.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `plan_mark` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

#### Weapon classes (5)

##### `ico_class_ar.png` · P2 · Batch 13.8

- **Used in:** Class pip on banners (outer-left), Codex AR filter, range bonus tooltip.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `class_ar` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.
- **Note:** kc-ui-art2: Cards show the weapon as a text pill now; class icons remain for the killfeed source icon, the art fallback and the Codex filters.

##### `ico_class_smg.png` · P2 · Batch 13.9

- **Used in:** Class pip, Codex SMG filter.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `class_smg` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.
- **Note:** kc-ui-art2: As class_ar.

##### `ico_class_shotgun.png` · P2 · Batch 13.10

- **Used in:** Class pip, Codex SHOTGUN filter.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `class_shotgun` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.
- **Note:** kc-ui-art2: As class_ar.

##### `ico_class_sniper.png` · P2 · Batch 14.1

- **Used in:** Class pip, Codex SNIPER filter.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `class_sniper` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.
- **Note:** kc-ui-art2: As class_ar.

##### `ico_class_lmg.png` · P2 · Batch 14.2

- **Used in:** Class pip, Codex LMG filter.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `class_lmg` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.
- **Note:** kc-ui-art2: As class_ar.

#### Killstreaks and Operator equipment (10)

##### `ico_ks_recon_drone.png` · P1 · Batch 6.4

- **Used in:** Killstreak tile in the tray (charge ring), STREAK flyout, Codex, call-in.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** charging grey / ready amber / used dim (tint) + ring.
- **Code id:** `ks_recon_drone` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_ks_mortar.png` · P1 · Batch 6.5

- **Used in:** Killstreak tile (Mortar Barrage), flyout, Codex.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** charging / ready / used (tint) + ring.
- **Code id:** `ks_mortar` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_ks_attack_helo.png` · P1 · Batch 6.6

- **Used in:** Killstreak tile (Attack Helo), flyout, Codex.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** charging / ready / used (tint) + ring.
- **Code id:** `ks_attack_helo` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_ks_sentry.png` · P1 · Batch 6.7

- **Used in:** Killstreak tile (Sentry Turret), flyout, Codex, Sentry token gear mark.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** charging / ready / used (tint) + ring.
- **Code id:** `ks_sentry` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_ks_gunship.png` · P3 · Batch 20.5

- **Used in:** Gunship card (Codex, rewards), reserved killstreak tile.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ks_gunship` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_att_optic.png` · P3 · Batch 20.6

- **Used in:** Loadout attachment (Holo Sight), Weapon Level reward.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `att_optic` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_att_grip.png` · P3 · Batch 20.7

- **Used in:** Loadout attachment (Foregrip), Weapon Level reward.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `att_grip` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_att_mag.png` · P3 · Batch 20.8

- **Used in:** Loadout attachment (Extended Mag), Weapon Level reward.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `att_mag` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_att_lining.png` · P3 · Batch 20.9

- **Used in:** Loadout attachment (Ceramic Lining), Weapon Level reward.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `att_lining` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_perk_slot.png` · P3 · Batch 21.1

- **Used in:** Loadout perk slot, Perk Offer reward header (the perks keep their painted patches).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `perk_slot` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

#### Objective, control and Field (6)

##### `ico_ctl_yours.png` · P1 · Batch 6.8

- **Used in:** Objective tile control mark (YOURS), minimap, score sheet; tinted teal.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (tint teal).
- **Code id:** `ctl_yours` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ctl_rival.png` · P1 · Batch 6.9

- **Used in:** Objective tile control mark (RIVAL); tinted red. Shape cue for colour-blind players.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (tint red).
- **Code id:** `ctl_rival` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ctl_even.png` · P1 · Batch 7.1

- **Used in:** Objective tile control mark (EVEN, was CONTESTED).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (tint grey).
- **Code id:** `ctl_even` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ctl_open.png` · P2 · Batch 14.3

- **Used in:** Objective tile control mark (OPEN: nobody there).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (tint grey).
- **Code id:** `ctl_open` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_overrun.png` · P1 · Batch 7.2

- **Used in:** FIELD OVERRUN callout, overrun risk on the Field chip, OVERRUN tag.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / warning pulse (tint red).
- **Code id:** `overrun` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_field_slot.png` · P2 · Batch 14.4

- **Used in:** Empty Field slot on the objective tile (your half), placement hint.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `field_slot` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

#### Phases, firefight and run modes (8)

##### `ico_ph_deploy.png` · P2 · Batch 14.5

- **Used in:** Phase header (DEPLOY), tutorial coach, score sheet.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ph_deploy` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ph_reveal.png` · P2 · Batch 14.6

- **Used in:** Phase header (REVEAL).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ph_reveal` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ph_firefight.png` · P2 · Batch 14.7

- **Used in:** Phase header (FIREFIGHT), order strip, tray step header.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ph_firefight` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ph_score.png` · P2 · Batch 14.8

- **Used in:** Phase header (SCORE & STREAK).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ph_score` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_mode_zone_control.png` · P2 · Batch 14.9

- **Used in:** Run map mode chip (Zone Control), match intro.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `mode_zone_control` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_mode_firefight.png` · P2 · Batch 15.1

- **Used in:** Run map mode chip (Firefight).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `mode_firefight` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_mode_detonator.png` · P2 · Batch 15.2

- **Used in:** Run map mode chip (Detonator).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `mode_detonator` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_mode_rival.png` · P2 · Batch 15.3

- **Used in:** Run map RIVAL (boss) match, rival squad header.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `mode_rival` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

#### Menu and system (24)

##### `ico_ui_menu.png` · P1 · Batch 7.3

- **Used in:** MENU badge (strip top), title.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / pressed (tint).
- **Code id:** `ui_menu` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_settings.png` · P2 · Batch 15.4

- **Used in:** Settings row in the pause menu, title.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_settings` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_undo.png` · P1 · Batch 7.4

- **Used in:** UNDO button in the tray (Deploy).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / disabled (tint).
- **Code id:** `ui_undo` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_speed.png` · P1 · Batch 7.5

- **Used in:** SPEED x2 button in the tray (Firefight), settings.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** off / on amber (tint).
- **Code id:** `ui_speed` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_skip.png` · P2 · Batch 15.5

- **Used in:** Skip the round playback, skip reward.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_skip` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_codex.png` · P2 · Batch 15.6

- **Used in:** CODEX buttons on the title and pause menu, Codex header.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_codex` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_mirror.png` · P2 · Batch 15.7

- **Used in:** MIRROR LAYOUT setting.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_mirror` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_sound_on.png` · P2 · Batch 15.8

- **Used in:** Sound setting ON.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_sound_on` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** NEW: there is no sound setting yet.

##### `ico_ui_sound_off.png` · P2 · Batch 15.9

- **Used in:** Sound setting OFF.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_sound_off` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** NEW: there is no sound setting yet.

##### `ico_ui_close.png` · P1 · Batch 7.6

- **Used in:** CLOSE on the inspector, flyouts, Codex, modals.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_close` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_back.png` · P1 · Batch 7.7

- **Used in:** BACK on Codex, Loadout, Retire picker.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_back` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_info.png` · P2 · Batch 16.1

- **Used in:** Long-press hint, rules buttons, tooltips header.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_info` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_eye.png` · P1 · Batch 7.8

- **Used in:** PREVIEW badge ON.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** on (tint).
- **Code id:** `ui_eye` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_eye_off.png` · P1 · Batch 7.9

- **Used in:** PREVIEW badge OFF.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** off (tint).
- **Code id:** `ui_eye_off` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_filter.png` · P2 · Batch 16.2

- **Used in:** Codex filter bar, CLEAR FILTERS.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_filter` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_check.png` · P1 · Batch 8.1

- **Used in:** Picked / ticked states, order strip finished column, PICKED tiles.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_check` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_lock.png` · P1 · Batch 3.9

- **Used in:** Locked keyword pip badge (frm_socket_locked), locked Codex art, NOT FOUND YET.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_lock` (wired: IconSheet.get_icon / UiKit lookup). **Fallback:** code fallback kept.

##### `ico_ui_continue.png` · P2 · Batch 16.3

- **Used in:** CONTINUE, BEGIN RUN, DEPLOY on the run map, NEXT.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_continue` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_retire.png` · P2 · Batch 16.4

- **Used in:** RETIRE tile on Supply Drop, Retire picker, Honor Roll.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_retire` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_promote.png` · P2 · Batch 16.5

- **Used in:** PROMOTION reward, level-up band strip.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_promote` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_reward.png` · P2 · Batch 16.6

- **Used in:** SUPPLY DROP header, reward tiles, after-action REWARD.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_reward` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_rotate.png` · P3 · Batch 21.2

- **Used in:** Rotate-your-phone notice (web shell), Operator Rotate action.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_rotate` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_survey.png` · P3 · Batch 21.3

- **Used in:** PLAYTEST SURVEY button at run end.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_survey` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ico_ui_tutorial.png` · P3 · Batch 21.4

- **Used in:** TUTORIAL row on the title.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 master (export 128/64/48/32). **Background:** white on black: TA converts brightness to alpha.
- **States:** normal / lit (tint) / idle grey (tint).
- **Code id:** `ui_tutorial` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

### 4.3 Standard Issue card art (5)

#### Standard Issue card art (starter, our own art) (5)

##### `kc_b_si_grunt.png` · P1 · Batch 3.1

- **Used in:** Grunt (cost 1, 2/2): Grunt x5 in the starter, TrainingBot and the M1 / M2 Standard Issue squads.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1152x768 master (banner band 1152x288, hand column 512x768). **Background:** opaque, no transparency.
- **States:** normal (no animation, no foil).
- **Code id:** `kc_b_si_grunt` (wired: BannerArtDB (UiKit.piece(&"kc_b_si_grunt"))). **Fallback:** image needed (code has only a placeholder).
- **Note:** Standard Issue starter art (onboarding-progression.md section 2.2): deliberately plain, so the first calling card pops. Banner pipeline: the curator sets banner_y / portrait_x, the TA ships the 1152x768 master and a data/banners/<id>.tres. kc-ui-art2: still valid; on C1+ the art is never dimmed or cropped, and Y2+ shows the same 4:1 band.

##### `kc_b_si_trooper.png` · P1 · Batch 3.2

- **Used in:** Trooper (cost 2, 2/3): Trooper x6 in the starter, Standard Issue squads.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1152x768 master (banner band 1152x288, hand column 512x768). **Background:** opaque, no transparency.
- **States:** normal (no animation, no foil).
- **Code id:** `kc_b_si_trooper` (wired: BannerArtDB (UiKit.piece(&"kc_b_si_trooper"))). **Fallback:** image needed (code has only a placeholder).
- **Note:** Standard Issue starter art (onboarding-progression.md section 2.2): deliberately plain, so the first calling card pops. Banner pipeline: the curator sets banner_y / portrait_x, the TA ships the 1152x768 master and a data/banners/<id>.tres. kc-ui-art2: still valid; on C1+ the art is never dimmed or cropped, and Y2+ shows the same 4:1 band.

##### `kc_b_si_sergeant.png` · P1 · Batch 3.3

- **Used in:** Sergeant (cost 3, 3/3): Sergeant x4 in the starter, Standard Issue squads.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1152x768 master (banner band 1152x288, hand column 512x768). **Background:** opaque, no transparency.
- **States:** normal (no animation, no foil).
- **Code id:** `kc_b_si_sergeant` (wired: BannerArtDB (UiKit.piece(&"kc_b_si_sergeant"))). **Fallback:** image needed (code has only a placeholder).
- **Note:** Standard Issue starter art (onboarding-progression.md section 2.2): deliberately plain, so the first calling card pops. Banner pipeline: the curator sets banner_y / portrait_x, the TA ships the 1152x768 master and a data/banners/<id>.tres. kc-ui-art2: still valid; on C1+ the art is never dimmed or cropped, and Y2+ shows the same 4:1 band.

##### `kc_b_si_armored.png` · P1 · Batch 3.4

- **Used in:** Armored Trooper (cost 4, 2/5): Armored Trooper x3 in the starter (the first card to send home), Standard Issue squads.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1152x768 master (banner band 1152x288, hand column 512x768). **Background:** opaque, no transparency.
- **States:** normal (no animation, no foil).
- **Code id:** `kc_b_si_armored` (wired: BannerArtDB (UiKit.piece(&"kc_b_si_armored"))). **Fallback:** image needed (code has only a placeholder).
- **Note:** Standard Issue starter art (onboarding-progression.md section 2.2): deliberately plain, so the first calling card pops. Banner pipeline: the curator sets banner_y / portrait_x, the TA ships the 1152x768 master and a data/banners/<id>.tres. kc-ui-art2: still valid; on C1+ the art is never dimmed or cropped, and Y2+ shows the same 4:1 band.

##### `kc_b_si_ammo_resupply.png` · P1 · Batch 3.5

- **Used in:** Ammo Resupply (tactic, Draw 2): Ammo Resupply x2 in the starter (Standard Issue art for the existing card).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1152x768 master (banner band 1152x288, hand column 512x768). **Background:** opaque, no transparency.
- **States:** normal (no animation, no foil).
- **Code id:** `kc_b_si_ammo_resupply` (wired: BannerArtDB (UiKit.piece(&"kc_b_si_ammo_resupply"))). **Fallback:** image needed (code has only a placeholder).
- **Note:** Standard Issue starter art (onboarding-progression.md section 2.2): deliberately plain, so the first calling card pops. Banner pipeline: the curator sets banner_y / portrait_x, the TA ships the 1152x768 master and a data/banners/<id>.tres. Tactic: no character is the subject (kind rule). kc-ui-art2: still valid; on C1+ the art is never dimmed or cropped, and Y2+ shows the same 4:1 band.

### 4.4 Buttons and controls (14)

#### Buttons (14)

##### `btn_primary.png` · P1 · Batch 9.9

- **Used in:** Primary actions: CONTINUE, BEGIN RUN, TAP TO TAKE, DEPLOY (run map), PLAY HERE confirm.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / hover (code +10% light) / pressed (btn_primary_pressed) / disabled (code grey 55%, alpha 60%). **9-slice (L,T,R,B at ship size):** 40,40,40,48.
- **Code id:** `btn_primary` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `btn_primary_pressed.png` · P1 · Batch 10.1

- **Used in:** Pressed state of btn_primary.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** pressed. **9-slice (L,T,R,B at ship size):** 40,40,40,48.
- **Code id:** `btn_primary_pressed` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** Generate in the same chat right after btn_primary ('same plate, pressed in').

##### `btn_secondary.png` · P1 · Batch 10.2

- **Used in:** Secondary actions: BACK, SKIP, DETAILS, DECK, CODEX, pause menu rows, Codex filter bar buttons.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / hover (+10%) / pressed (btn_secondary_pressed) / disabled (grey 55%) / selected (fx_outline_teal on top). **9-slice (L,T,R,B at ship size):** 40,40,40,48.
- **Code id:** `btn_secondary` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `btn_secondary_pressed.png` · P1 · Batch 10.3

- **Used in:** Pressed state of btn_secondary.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** pressed. **9-slice (L,T,R,B at ship size):** 40,40,40,48.
- **Code id:** `btn_secondary_pressed` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `btn_danger.png` · P2 · Batch 17.8

- **Used in:** Danger / leave actions: BACK TO TITLE, abandon run, NEW RUN confirm.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / hover (+10%) / pressed (code: darker + 2 px down) / disabled (grey). **9-slice (L,T,R,B at ship size):** 40,40,40,48.
- **Code id:** `btn_danger` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `btn_ready.png` · P1 · Batch 10.4

- **Used in:** READY in the tray (245x64 phone, 149x72 desktop): the main button of every round.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x136. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / hover / pressed (btn_ready_pressed) / disabled (grey: nothing planned yet is still allowed, so rare) / glow (fx_glow_amber pulse when the Deploy timer is low). **9-slice (L,T,R,B at ship size):** 48,40,112,48.
- **Code id:** `btn_ready` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** The stripes sit inside the right 9-slice margin so they never stretch.

##### `btn_ready_pressed.png` · P1 · Batch 10.5

- **Used in:** Pressed state of READY.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x136. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** pressed. **9-slice (L,T,R,B at ship size):** 48,40,112,48.
- **Code id:** `btn_ready_pressed` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `btn_badge.png` · P1 · Batch 10.6

- **Used in:** Icon strip badges 62x64 (MENU, SCORE, OPERATOR, STREAK, RIVAL, PREVIEW, DECK), SPEED, UNDO square.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / pressed (code darker) / glow (fx_glow_amber: killstreak ready, Operator DEPLOY) / selected (fx_outline_teal: flyout open). **9-slice (L,T,R,B at ship size):** 24,24,24,24.
- **Code id:** `btn_badge` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `btn_chip.png` · P2 · Batch 17.9

- **Used in:** Small pill buttons: Codex filters (ALL / UNITS / AR...), tabs on narrow screens, toggles in the deck view.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 192x64. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / selected (btn_chip_on) / pressed (code) / disabled (grey). **9-slice (L,T,R,B at ship size):** 24,20,24,20.
- **Code id:** `btn_chip` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `btn_chip_on.png` · P2 · Batch 18.1

- **Used in:** Selected filter chip / active tab.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 192x64. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** selected. **9-slice (L,T,R,B at ship size):** 24,20,24,20.
- **Code id:** `btn_chip_on` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `btn_tab.png` · P3 · Batch 22.1

- **Used in:** Tabs: SETS flyout (RIVAL / YOU), score sheet, Codex kind tabs on desktop.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 192x80. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** inactive / active (code: lighter + amber top line). **9-slice (L,T,R,B at ship size):** 28,24,28,8.
- **Code id:** `btn_tab` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `tgl_track.png` · P2 · Batch 18.2

- **Used in:** Settings toggles: MIRROR LAYOUT, SPEED x2, FAST ANIMATIONS, PREVIEW.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 128x64. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** off (grey) / on (code tints the inner teal #2EC4B6). **9-slice (L,T,R,B at ship size):** 30,30,30,30.
- **Code id:** `tgl_track` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `tgl_knob.png` · P2 · Batch 18.3

- **Used in:** Toggle knob, slider knob.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 64x64. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / pressed (code darker).
- **Code id:** `tgl_knob` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `sld_track.png` · P3 · Batch 22.2

- **Used in:** Slider track (volume, Deploy timer setting) and progress bars (run tickets).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 256x32. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / fill (code tints a copy amber). **9-slice (L,T,R,B at ship size):** 14,14,14,14.
- **Code id:** `sld_track` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

### 4.5 Panels, trays, rings and strips (26)

#### Panels, trays and overlays (24)

##### `pnl_tray.png` · P1 · Batch 10.7

- **Used in:** Hand tray (362x532 phone, 224x776 desktop): background of the hand grid, killfeed log, step header.
- **Generate:** 1024x1536 (portrait 2:3). **Ship:** 256x512. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal (open / closed share it). **9-slice (L,T,R,B at ship size):** 32,32,32,32.
- **Code id:** `pnl_tray` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `pnl_flyout.png` · P1 · Batch 10.8

- **Used in:** Strip badge flyouts: SCORE, OPERATOR, STREAK, RIVAL, DECK, SETS.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x256. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 32,32,32,32.
- **Code id:** `pnl_flyout` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `pnl_flyout_pointer.png` · P2 · Batch 18.4

- **Used in:** The little pointer that joins a flyout to its badge.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 32x48. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal (code flips it for mirror layout).
- **Code id:** `pnl_flyout_pointer` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `pnl_toast.png` · P1 · Batch 10.9

- **Used in:** Killfeed toasts (top centre, 2 max, 92% opacity), one-time callouts, 'Not enough Supply' toasts.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x64. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal (the left bar is tinted teal / red / amber in code). **9-slice (L,T,R,B at ship size):** 40,16,24,16.
- **Code id:** `pnl_toast` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `pnl_inspector.png` · P1 · Batch 11.1

- **Used in:** Card inspector (512x128 banner + text panel, scrolls), item inspector, long-press rules.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x384. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 40,40,40,40.
- **Code id:** `pnl_inspector` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `pnl_tooltip.png` · P2 · Batch 18.5

- **Used in:** Tooltips (desktop hover), long-press rule bubbles, Supply Drop twin preview.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 192x96. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 16,16,16,16.
- **Code id:** `pnl_tooltip` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `pnl_modal.png` · P1 · Batch 11.2

- **Used in:** Pause menu, match end (VICTORY / DEFEAT), Retire picker, score sheet, consent and surveys.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x384. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 48,48,48,48.
- **Code id:** `pnl_modal` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `pnl_header.png` · P2 · Batch 18.6

- **Used in:** Screen title bars: SUPPLY DROP, CODEX, RUN SUMMARY, PAUSED, STARTER KIT.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x64. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 40,16,40,16.
- **Code id:** `pnl_header` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `pnl_hand_tab.png` · P2 · Batch 18.7

- **Used in:** HAND · n PEEK tab (362x64) in the closed tray.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x80. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / pressed (code). **9-slice (L,T,R,B at ship size):** 40,24,40,16.
- **Code id:** `pnl_hand_tab` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `pnl_ks_tile.png` · P1 · Batch 11.3

- **Used in:** Killstreak tile backer (61 px) at the top of the tray and in the STREAK flyout.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** charging / ready (fx_glow_amber + amber frame by code) / used (code dim).
- **Code id:** `pnl_ks_tile` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ring_track.png` · P1 · Batch 11.4

- **Used in:** Killstreak charge ring (empty track); TextureProgressBar under.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal.
- **Code id:** `ring_track` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `ring_fill.png` · P1 · Batch 11.5

- **Used in:** Killstreak charge ring fill; TextureProgressBar radial (tinted amber / cyan).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x128. **Background:** white on black: TA converts brightness to alpha.
- **States:** fill (code tints: charging cyan #5BC0EB, ready amber #FFB020).
- **Code id:** `ring_fill` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** Generate right after ring_track in the same chat so the segments line up.

##### `pip_supply.png` · P1 · Batch 11.6

- **Used in:** Supply pips (up to 10) in the tray.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 64x64. **Background:** white on black: TA converts brightness to alpha.
- **States:** full (tint amber) / empty (tint dark steel, 40%) / spent this Deploy (tint grey).
- **Code id:** `pip_supply` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `pnl_counter.png` · P2 · Batch 18.8

- **Used in:** Small number bubble: hand count, deck count on badges, '+n more', unread log.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 64x48. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / tinted by side. **9-slice (L,T,R,B at ship size):** 16,16,16,16.
- **Code id:** `pnl_counter` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `pnl_order_strip.png` · P2 · Batch 18.9

- **Used in:** Firefight order strip A -> B -> C over the board.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x48. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 24,12,24,12.
- **Code id:** `pnl_order_strip` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** NEW: the A > B > C order strip (firefight-order.md section 8) is not built yet.

##### `order_node.png` · P2 · Batch 19.1

- **Used in:** One column node on the order strip (letter drawn by code).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 64x64. **Background:** white on black: TA converts brightness to alpha.
- **States:** pending (grey) / current (amber + fx_glow_amber) / done (teal + ico_ui_check) / skipped (dim 30%).
- **Code id:** `order_node` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** NEW: for the order strip (not built yet).

##### `order_arrow.png` · P2 · Batch 19.2

- **Used in:** Connector between order nodes.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 64x32. **Background:** white on black: TA converts brightness to alpha.
- **States:** pending / passed (tint).
- **Code id:** `order_arrow` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** NEW: for the order strip (not built yet).

##### `pnl_rail_chip.png` · P2 · Batch 19.3

- **Used in:** Trait rail chips (62x49 phone) and SETS flyout rows.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x96. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** idle / lit (code tints the slot by trait) / crack (fx_crack). **9-slice (L,T,R,B at ship size):** 20,20,20,20.
- **Code id:** `pnl_rail_chip` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `pnl_callout.png` · P2 · Batch 19.4

- **Used in:** Set callouts ('VANGUARD 2: ...'), column banner 'COLUMN A', FIRST SHOT tag, DEPLOY / PLAY HERE chips.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 256x48. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal (code tints outline: green buff, red off, amber ready). **9-slice (L,T,R,B at ship size):** 24,12,24,12.
- **Code id:** `pnl_callout` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `pnl_pick_tile.png` · P1 · Batch 11.7

- **Used in:** Reward pick tiles (Supply Drop cards, Retire, Doctrine, Promotion, Perk Offer), Loadout picks.
- **Generate:** 1024x1536 (portrait 2:3). **Ship:** 256x384. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / hover (+10%) / selected (fx_outline_teal) / disabled (AT THE FLOOR: grey). **9-slice (L,T,R,B at ship size):** 32,32,32,64.
- **Code id:** `pnl_pick_tile` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `pnl_coach.png` · P2 · Batch 19.5

- **Used in:** Tutorial coach bubbles over the objective row.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 384x160. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 32,32,32,48.
- **Code id:** `pnl_coach` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `pnl_result.png` · P2 · Batch 19.6

- **Used in:** Match end and run end headline plate behind VICTORY / DEFEAT / DRAW.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 768x160. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** victory (code tints amber) / defeat (red) / draw (steel). **9-slice (L,T,R,B at ship size):** 160,48,160,48.
- **Code id:** `pnl_result` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `runmap_node.png` · P2 · Batch 19.7

- **Used in:** Run map match nodes (NEXT / UPCOMING / done).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 96x96. **Background:** white on black: TA converts brightness to alpha.
- **States:** upcoming (grey) / next (amber + glow) / won (teal + check) / lost (red).
- **Code id:** `runmap_node` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `runmap_path.png` · P3 · Batch 22.3

- **Used in:** Path between run map nodes (tiled).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x16. **Background:** white on black: TA converts brightness to alpha.
- **States:** ahead (grey) / travelled (amber).
- **Code id:** `runmap_path` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

#### First-time explainer (New: X) (2)

##### `pnl_new_card.png` · P1 · Batch 5.8

- **Used in:** 'New: X' one-time explainer card (half screen: icon, one sentence, mini example, GOT IT), queued one per screen.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x320. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / enter (code: slide + fade). **9-slice (L,T,R,B at ship size):** 96,48,40,40.
- **Code id:** `pnl_new_card` (wired: UiKit.draw_piece in new_card.gd). **Fallback:** code fallback kept.
- **Note:** The tab sits inside the left and top 9-slice margins. GOT IT uses btn_primary.

##### `pnl_new_inset.png` · P1 · Batch 5.9

- **Used in:** Mini example well inside the New: card (a mini board grid, a card, a trait counter).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 256x160. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 20,20,20,20.
- **Code id:** `pnl_new_inset` (wired: UiKit.draw_piece in new_card.gd). **Fallback:** code fallback kept.

### 4.6 Backgrounds (12)

#### Screen backgrounds (9)

##### `bg_title.png` · P1 · Batch 8.2

- **Used in:** Title screen (KillingCard wordmark drawn by code on the left third).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1536x864 (crop 80 px top and bottom). **Background:** opaque, no transparency.
- **States:** normal.
- **Code id:** `bg_title` (replaces a bitmap (TA swaps the file the screen loads today, or adds the path)). **Fallback:** image needed (code has only a placeholder).
- **Note:** Replaces assets/ui/backgrounds/title_key_art.webp (Killstreak era).

##### `bg_menu.png` · P3 · Batch 21.5

- **Used in:** Pause menu backdrop behind pnl_modal, settings, consent and survey screens.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1536x864 (crop 80 px top and bottom). **Background:** opaque, no transparency.
- **States:** normal.
- **Code id:** `bg_menu` (replaces a bitmap (TA swaps the file the screen loads today, or adds the path)). **Fallback:** image needed (code has only a placeholder).
- **Note:** Optional: the pause menu can keep its code scrim.

##### `bg_run_map.png` · P1 · Batch 8.3

- **Used in:** Run map (5 matches, tickets, DEPLOY).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1536x864 (crop 80 px top and bottom). **Background:** opaque, no transparency.
- **States:** normal.
- **Code id:** `bg_run_map` (replaces a bitmap (TA swaps the file the screen loads today, or adds the path)). **Fallback:** image needed (code has only a placeholder).
- **Note:** Replaces bg_run.webp. No letters or grid numbers on the map.

##### `bg_supply_drop.png` · P1 · Batch 8.4

- **Used in:** Supply Drop / Weapon Level / Perk Offer / Promotion / Doctrine / Regroup reward screens.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1536x864 (crop 80 px top and bottom). **Background:** opaque, no transparency.
- **States:** normal.
- **Code id:** `bg_supply_drop` (replaces a bitmap (TA swaps the file the screen loads today, or adds the path)). **Fallback:** image needed (code has only a placeholder).
- **Note:** Replaces the Killstreak-era bg_supply_drop.webp (that one put the crate in the right third; cards now need more room).

##### `bg_after_action.png` · P2 · Batch 16.7

- **Used in:** After-Action report (VICTORY / DEFEAT, stats, Honor Roll), run end.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1536x864 (crop 80 px top and bottom). **Background:** opaque, no transparency.
- **States:** normal.
- **Code id:** `bg_after_action` (replaces a bitmap (TA swaps the file the screen loads today, or adds the path)). **Fallback:** image needed (code has only a placeholder).

##### `bg_codex.png` · P2 · Batch 16.8

- **Used in:** Codex (filters + tile grid).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1536x864 (crop 80 px top and bottom). **Background:** opaque, no transparency.
- **States:** normal.
- **Code id:** `bg_codex` (replaces a bitmap (TA swaps the file the screen loads today, or adds the path)). **Fallback:** image needed (code has only a placeholder).

##### `bg_loadout.png` · P2 · Batch 16.9

- **Used in:** Starter deck / Loadout screen (STARTER KIT, picks, BEGIN RUN).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1536x864 (crop 80 px top and bottom). **Background:** opaque, no transparency.
- **States:** normal.
- **Code id:** `bg_loadout` (replaces a bitmap (TA swaps the file the screen loads today, or adds the path)). **Fallback:** image needed (code has only a placeholder).

##### `bg_loading.png` · P2 · Batch 17.1

- **Used in:** Loading screen / web shell splash, boot (wordmark and bar drawn by code).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1536x864 (crop 80 px top and bottom). **Background:** opaque, no transparency.
- **States:** normal.
- **Code id:** `bg_loading` (replaces a bitmap (TA swaps the file the screen loads today, or adds the path)). **Fallback:** image needed (code has only a placeholder).
- **Note:** Ship also as a 960x540 WebP for the web shell (loads before the engine).

##### `bg_match.png` · P1 · Batch 8.5

- **Used in:** Match backdrop behind the strip, the 3 columns and the tray.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 1536x864 (crop 80 px top and bottom). **Background:** opaque, no transparency.
- **States:** normal.
- **Code id:** `bg_match` (replaces a bitmap (TA swaps the file the screen loads today, or adds the path)). **Fallback:** image needed (code has only a placeholder).
- **Note:** Replaces the tactical_backdrop shader look only if the head prefers it; the shader can stay as the fallback.

#### Column location backdrops (Port Vasel) (3)

##### `col_containers.png` · P1 · Batch 8.6

- **Used in:** Column backing: containers.
- **Generate:** 1024x1536 (portrait 2:3). **Ship:** 512x1216 (crop the middle 648x1536, resize). **Background:** opaque, no transparency.
- **States:** normal (dimmed in code).
- **Code id:** `col_containers` (replaces a bitmap (TA swaps the file the screen loads today, or adds the path)). **Fallback:** image needed (code has only a placeholder).
- **Note:** Shown behind the slots at 34% opacity, darkened (lane.gd Backing). Replaces the square lane_*.webp from Killstreak, which crop badly into a tall column.

##### `col_cranes.png` · P1 · Batch 8.7

- **Used in:** Column backing: cranes.
- **Generate:** 1024x1536 (portrait 2:3). **Ship:** 512x1216 (crop the middle 648x1536, resize). **Background:** opaque, no transparency.
- **States:** normal (dimmed in code).
- **Code id:** `col_cranes` (replaces a bitmap (TA swaps the file the screen loads today, or adds the path)). **Fallback:** image needed (code has only a placeholder).
- **Note:** Shown behind the slots at 34% opacity, darkened (lane.gd Backing). Replaces the square lane_*.webp from Killstreak, which crop badly into a tall column.

##### `col_offices.png` · P1 · Batch 8.8

- **Used in:** Column backing: offices.
- **Generate:** 1024x1536 (portrait 2:3). **Ship:** 512x1216 (crop the middle 648x1536, resize). **Background:** opaque, no transparency.
- **States:** normal (dimmed in code).
- **Code id:** `col_offices` (replaces a bitmap (TA swaps the file the screen loads today, or adds the path)). **Fallback:** image needed (code has only a placeholder).
- **Note:** Shown behind the slots at 34% opacity, darkened (lane.gd Backing). Replaces the square lane_*.webp from Killstreak, which crop badly into a tall column.

### 4.7 Objective and Field tile backers (4)

#### Objective and Field tile backers (4)

##### `tile_objective.png` · P1 · Batch 11.8

- **Used in:** Objective tile between the fronts (228x52 phone, 304x96 desktop): FP pair, control mark, words, Field chips.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 456x112. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / your control (code edge teal) / rival control (edge red) / even (dashed edge, code). **9-slice (L,T,R,B at ship size):** 24,20,24,20.
- **Code id:** `tile_objective` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `tile_field_chip.png` · P1 · Batch 11.9

- **Used in:** Field chip on the objective tile (70x22 phone, 96x28 desktop), one per side.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 192x64. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** yours (code tint teal) / rival (red) / overrun risk (fx_glow_red pulse) / trap (dashed: tile_field_chip_trap). **9-slice (L,T,R,B at ship size):** 24,16,24,16.
- **Code id:** `tile_field_chip` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `tile_field_chip_trap.png` · P2 · Batch 19.8

- **Used in:** Your hidden trap chip (dashed, only you see it).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 192x64. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 24,16,24,16.
- **Code id:** `tile_field_chip_trap` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `tile_slot_empty.png` · P2 · Batch 19.9

- **Used in:** Empty row slot in a column (your landing slots, rival back rows).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 456x114. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / valid target (code teal outline) / invalid (code dim). **9-slice (L,T,R,B at ship size):** 20,20,20,20.
- **Code id:** `tile_slot_empty` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

### 4.8 Card frame parts (18)

#### Board banner frame (4:1) (3)

##### `frm_front_tab.png` · P1 · Batch 9.5

- **Used in:** FRONT tab (48x13 phone, 64x15 desktop) on the front-row card; word drawn by code.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x32. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** yours (tint teal) / rival (tint red). **9-slice (L,T,R,B at ship size):** 12,6,12,6.
- **Code id:** `frm_front_tab` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `frm_plan_plate.png` · P1 · Batch 9.6

- **Used in:** PLAN tag on your planned cards (inner-edge centre) and PLAN · B on the Operator card.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x40. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal. **9-slice (L,T,R,B at ship size):** 16,8,16,8.
- **Code id:** `frm_plan_plate` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `frm_incoming.png` · P1 · Batch 9.7

- **Used in:** INCOMING face-down rival banner (back pattern, fills the whole 4:1 banner).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x128 (crop a 4:1 band). **Background:** opaque, no transparency.
- **States:** normal / pulse (code).
- **Code id:** `frm_incoming` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

#### Elite and Operator frames (1)

##### `frm_dogtag_plate.png` · P2 · Batch 17.6

- **Used in:** Callsign / dog-tag plate on the Operator banner (in place of the effect glyph).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 96x40. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal.
- **Code id:** `frm_dogtag_plate` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

#### Hand card, Codex and mulligan (1)

##### `frm_put_back.png` · P1 · Batch 9.8

- **Used in:** Mulligan PUT BACK plate on marked cards (word drawn by code).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x320. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal.
- **Code id:** `frm_put_back` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

#### Card backs (2)

##### `card_back_banner.png` · P2 · Batch 17.7

- **Used in:** Face-down KillingCard back (4:1): deck pile, deal animation, rival hand, INCOMING alternative.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x128 (crop a 4:1 band). **Background:** opaque, no transparency.
- **States:** normal.
- **Code id:** `card_back_banner` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** NEW: no face-down 4:1 back in code yet (INCOMING is drawn).

##### `card_back_hand.png` · P3 · Batch 21.8

- **Used in:** Face-down hand-size back (deck view, mulligan replacements).
- **Generate:** 1024x1536 (portrait 2:3). **Ship:** 256x320. **Background:** opaque, no transparency.
- **States:** normal.
- **Code id:** `card_back_hand` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** Replaces the Killstreak-era card_back.webp.

#### Standard Issue frame and plates (3)

##### `frm_standard_issue.png` · P1 · Batch 3.6 · **revised (kc-ui-art2)**

- **Used in:** Standard Issue board card (C1+, full art inside it), the X1 hand card and the New: explainers (no camo band, no foil, no serial plate).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / selected (fx_outline_teal) / now firing (fx_outline_side) / dimmed (code). **9-slice (L,T,R,B at ship size):** 16,16,16,16.
- **Code id:** `frm_standard_issue` (wired: UiKit.draw_piece in StandardIssueLook.draw_frame). **Fallback:** code fallback kept.
- **Note:** kc-ui-art2: revised, the hexagon notch is gone (the cost now sits in the peek chip). Code: ui_kit.gd PIECE_MARGINS still says 40,32,16,16 for it; change to 16,16,16,16.

##### `frm_socket_empty.png` · P3 · Batch 21.9

- **Used in:** Empty trait / weapon slot, bottom left (Standard Issue cards; NO TRAIT arts in the Codex).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 64x64. **Background:** white on black: TA converts brightness to alpha.
- **States:** normal (code tint grey #7E8890 at 60%).
- **Code id:** `frm_socket_empty` (wired: UiKit.draw_piece in StandardIssueLook.draw_empty_socket). **Fallback:** code fallback kept.
- **Note:** kc-ui-art2: Still drawn by StandardIssueLook.draw_empty_socket in the reward screen; the C1+ board shows nothing in an empty trait slot.

##### `frm_socket_locked.png` · P1 · Batch 3.8

- **Used in:** Recruit padlock in the top-right abilities chip on C1+ cards (StandardIssueLook.draw_locked_keyword) and the Y2+ text box.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 64x64. **Background:** white on black: TA converts brightness to alpha.
- **States:** locked (code: socket grey, keyword icon tinted #7E8890 at 45%, this overlay on top) / unlocks (overlay fades, socket lights, New: Keywords).
- **Code id:** `frm_socket_locked` (wired: UiKit.draw_piece in StandardIssueLook.draw_locked_socket). **Fallback:** code fallback kept.
- **Note:** The keyword icon itself is drawn inside by the code, greyed.

#### Y2+ card frames and the T1 orders frame (5)

##### `frm_y2_unit.png` · P1 · Batch 2.2 · **new (kc-ui-art2)**

- **Used in:** Every unit, Field and killstreak card off the board (Y2+): mulligan, Supply Drop / Salvage / Muster out picks, Codex grid, deck lists, inspector, hand dock.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 500x432. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / marked or selected (code: amber rim glow) / killstreak (code tints the rim cyan #5BC0EB) / Elite (code gold rim, or frm_y2_operator) / not found (code veil over the art). **9-slice (L,T,R,B at ship size):** 24,24,24,24.
- **Code id:** `frm_y2_unit` (needs code: CardView._draw() -> UiKit.draw_piece(self, &"frm_y2_unit", rect) before its polygons, + PIECE_MARGINS). **Fallback:** code fallback works, but the image clearly beats it.
- **Note:** The Y2+ card is laid out at its own width (172 to 330 px, height (W - 8) / 4 + 155; 250x216 in the inspector and the hand dock). The code draws the title bar, the 4:1 art window, the type line, the text box and the stats bar on top of this frame, so the face must be plain. Shipped at 2x (500x432) and drawn at 0.5 scale.

##### `frm_y2_operator.png` · P1 · Batch 2.3 · **new (kc-ui-art2)**

- **Used in:** The Operator's Y2+ card and the O2 Operator card bottom-left of the tray (OPERATOR tag, cost hex, state chip drawn by code).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 500x432. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / can deploy (code: amber glow) / planned / on board / down (code dim) / need Supply (code: red cost hex). **9-slice (L,T,R,B at ship size):** 24,24,24,24.
- **Code id:** `frm_y2_operator` (needs code: CardView._draw() (operator) and hand_area._make_operator_card -> UiKit.draw_piece(&"frm_y2_operator")). **Fallback:** code fallback works, but the image clearly beats it.
- **Note:** The Y2+ card is laid out at its own width (172 to 330 px, height (W - 8) / 4 + 155; 250x216 in the inspector and the hand dock). The code draws the title bar, the 4:1 art window, the type line, the text box and the stats bar on top of this frame, so the face must be plain. Shipped at 2x (500x432) and drawn at 0.5 scale. The O2 tray card (hand_area._make_operator_card) can use the same 9-slice.

##### `frm_y2_standard_issue.png` · P1 · Batch 3.7 · **new (kc-ui-art2)**

- **Used in:** Standard Issue cards off the board (Y2+): starter list, mulligan, Muster out, Codex.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 500x432. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / marked (code amber rim). **9-slice (L,T,R,B at ship size):** 24,24,24,24.
- **Code id:** `frm_y2_standard_issue` (needs code: CardView._draw() (standard_issue) -> UiKit.draw_piece(&"frm_y2_standard_issue")). **Fallback:** code fallback works, but the image clearly beats it.
- **Note:** The Y2+ card is laid out at its own width (172 to 330 px, height (W - 8) / 4 + 155; 250x216 in the inspector and the hand dock). The code draws the title bar, the 4:1 art window, the type line, the text box and the stats bar on top of this frame, so the face must be plain. Shipped at 2x (500x432) and drawn at 0.5 scale. Same paint as frm_standard_issue (the board card), so a Standard Issue card reads the same everywhere.

##### `frm_t1_orders.png` · P1 · Batch 2.4 · **new (kc-ui-art2)**

- **Used in:** Every Tactic card off the board (Y2+ with the T1 orders frame): mulligan, rewards, Codex, inspector, hand dock.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 500x432. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal / marked (code amber rim) / not found (code veil over the art). **9-slice (L,T,R,B at ship size):** 24,64,48,24.
- **Code id:** `frm_t1_orders` (needs code: CardView._draw() (tactic) -> UiKit.draw_piece(&"frm_t1_orders") instead of the outline polygons and the khaki band). **Fallback:** code fallback works, but the image clearly beats it.
- **Note:** The Y2+ card is laid out at its own width (172 to 330 px, height (W - 8) / 4 + 155; 250x216 in the inspector and the hand dock). The code draws the title bar, the 4:1 art window, the type line, the text box and the stats bar on top of this frame, so the face must be plain. Shipped at 2x (500x432) and drawn at 0.5 scale. The chevron cut (18 px at 1x) sits inside the top-right 9-slice corner; the khaki strip sits inside the top margin, so it stretches cleanly. No stats bar on Tactics: the text box takes its room.

##### `tex_orders_paper.png` · P2 · Batch 2.5 · **new (kc-ui-art2)**

- **Used in:** Paper grain tiled over the T1 face and text box (about 60% opacity), so the orders frame reads as paper at any card width.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256 tile. **Background:** opaque, no transparency.
- **States:** one state (code: draw tiled with texture_repeat, 60% alpha). **Repeat:** tiles in both directions.
- **Code id:** `tex_orders_paper` (needs code: CardView._draw() (tactic) -> draw UiKit.piece(&"tex_orders_paper") tiled over the face at 60% alpha). **Fallback:** code fallback is fine (image optional).
- **Note:** Code fallback (flat colour) is fine; this only adds the paper feel the 9-slice face can't keep when it stretches.

#### C1+ stat badges (optional painted finish) (3)

##### `plate_fp_reticle.png` · P2 · Batch 5.5 · **new (kc-ui-art2)**

- **Used in:** FP reticle bottom-right of every C1+ card (26 px phone), the Y2+ stats bar (28 px) and the inspector (up to 52 px); the number is code text.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** yours (modulate teal #2EC4B6) / rival (modulate red #FF5A5D) / buffed (code: green number) / lowered (code: red number).
- **Code id:** `plate_fp_reticle` (needs code: CardLook.draw_reticle -> UiKit.draw_piece(&"plate_fp_reticle", r, team colour), then the number). **Fallback:** code fallback is fine (image optional).
- **Note:** Optional. The code already draws the decided shape (flat colours, the number on top). This image only adds a metal finish. It is generated neutral steel and the code modulates it, so one image serves both teams and the damaged state.

##### `plate_armor_ballistic.png` · P2 · Batch 5.6 · **new (kc-ui-art2)**

- **Used in:** Armor plate right of FP on every C1+ card, the Y2+ stats bar and the inspector; only the number left is shown (code text).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal (as is, both sides) / damaged (modulate amber #F2A33A; number #FFC067 in code).
- **Code id:** `plate_armor_ballistic` (needs code: CardLook.draw_armor -> UiKit.draw_piece(&"plate_armor_ballistic", r, grey or amber), then the number). **Fallback:** code fallback is fine (image optional).
- **Note:** Optional. The code already draws the decided shape (flat colours, the number on top). This image only adds a metal finish. It is generated neutral steel and the code modulates it, so one image serves both teams and the damaged state. Never red when damaged: red means the rival.

##### `coin_level.png` · P3 · Batch 5.7 · **new (kc-ui-art2)**

- **Used in:** Level coin in the C1+ peek group (17 px) and on the Y2+ type line (16 px): R / T / V / E is code text.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 64x64. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** Recruit R (as is) / Trained, Veteran, Elite (modulate brass #F3D36B).
- **Code id:** `coin_level` (needs code: CardLook.draw_level_coin -> UiKit.draw_piece(&"coin_level", r, steel or brass), then the letter). **Fallback:** code fallback is fine (image optional).
- **Note:** Optional, like the stat badges: at 16-17 px the code coin (CardLook.draw_level_coin) reads the same.

### 4.9 Camo bands (5)

#### Level camo bands and Operator mastery ladder (5)

##### `band_base.png` · P3 · Batch 22.4

- **Used in:** Operator base camo tier (OPERATOR badge swatch, Operator frame band); optional Recruit swatch in the deck view.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 512x512 swatch + 512x32 seamless strip. **Background:** opaque, no transparency.
- **States:** normal / shimmer (banner_shimmer shader on animated finishes). **Repeat:** tile horizontally.
- **Code id:** `band_base` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** Tileable strip. Generate a square swatch; the TA cuts a horizontal strip and makes it seamless (offset + clone, or mirror-tile). kc-ui-art2: Cards no longer show a level band (the level coin replaced it). Only the run-screen level swatches use bands, and those are drawn in code (SynergyGlyphs.draw_band).

##### `band_gilded.png` · P3 · Batch 22.5

- **Used in:** Trained copies (Gilded band under the art and on the outer edge), Operator gold tier.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 512x512 swatch + 512x32 seamless strip. **Background:** opaque, no transparency.
- **States:** normal / shimmer (banner_shimmer shader on animated finishes). **Repeat:** tile horizontally.
- **Code id:** `band_gilded` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** Tileable strip. Generate a square swatch; the TA cuts a horizontal strip and makes it seamless (offset + clone, or mirror-tile). kc-ui-art2: Cards no longer show a level band (the level coin replaced it). Only the run-screen level swatches use bands (SynergyGlyphs.draw_band).

##### `band_forged.png` · P3 · Batch 22.6

- **Used in:** Veteran copies (Forged band), Operator forged tier.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 512x512 swatch + 512x32 seamless strip. **Background:** opaque, no transparency.
- **States:** normal / shimmer (banner_shimmer shader on animated finishes). **Repeat:** tile horizontally.
- **Code id:** `band_forged` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** Tileable strip. Generate a square swatch; the TA cuts a horizontal strip and makes it seamless (offset + clone, or mirror-tile). kc-ui-art2: As band_gilded.

##### `band_priceless.png` · P3 · Batch 22.7

- **Used in:** Elite copies (Priceless band), Operator priceless tier.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 512x512 swatch + 512x32 seamless strip. **Background:** opaque, no transparency.
- **States:** normal / shimmer (banner_shimmer shader on animated finishes). **Repeat:** tile horizontally.
- **Code id:** `band_priceless` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** Tileable strip. Generate a square swatch; the TA cuts a horizontal strip and makes it seamless (offset + clone, or mirror-tile). kc-ui-art2: As band_gilded.

##### `band_interstellar.png` · P3 · Batch 22.8

- **Used in:** Operator top mastery tier only.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 512x512 swatch + 512x32 seamless strip. **Background:** opaque, no transparency.
- **States:** normal / shimmer (banner_shimmer shader on animated finishes). **Repeat:** tile horizontally.
- **Code id:** `band_interstellar` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** Tileable strip. Generate a square swatch; the TA cuts a horizontal strip and makes it seamless (offset + clone, or mirror-tile). kc-ui-art2: As band_gilded.

### 4.10 Glows, outlines and overlays (13)

#### Glows, outlines, links and previews (additive overlays) (11)

##### `fx_outline_teal.png` · P1 · Batch 8.9

- **Used in:** Selected card / badge outline (teal), valid-target slot.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x160. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** normal / pulse (code alpha). **9-slice (L,T,R,B at ship size):** 32,32,32,32.
- **Code id:** `fx_outline_teal` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `fx_outline_side.png` · P1 · Batch 9.1

- **Used in:** Now-firing outline in the owner's colour (tinted teal / red), lift on shot.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x160. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** tinted teal / red. **9-slice (L,T,R,B at ship size):** 32,32,32,32.
- **Code id:** `fx_outline_side` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `fx_glow_amber.png` · P1 · Batch 9.2

- **Used in:** Ready glow: killstreak tile READY, Operator DEPLOY, READY button pulse, order node current.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** pulse (code alpha 0.4 -> 1.0). **9-slice (L,T,R,B at ship size):** 64,64,64,64.
- **Code id:** `fx_glow_amber` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `fx_glow_red.png` · P2 · Batch 17.2

- **Used in:** Overrun risk pulse, can't-pay flash, set OFF.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** pulse. **9-slice (L,T,R,B at ship size):** 64,64,64,64.
- **Code id:** `fx_glow_red` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `fx_link_tick.png` · P1 · Batch 9.3

- **Used in:** Link ticks: vertical (Guard, Spotter) across the row gap, horizontal (Fireteam, Overwatch) across the gutter; tinted by owner.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 32x64. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** active (tint side colour) / ghost (fx_link_tick_ghost) / break flash (code).
- **Code id:** `fx_link_tick` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.
- **Note:** Rotate 90 degrees in code for the horizontal ticks.

##### `fx_link_tick_ghost.png` · P2 · Batch 17.3

- **Used in:** Dashed amber ghost ticks for links a placement would make.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 32x64. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** normal.
- **Code id:** `fx_link_tick_ghost` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `frm_ghost.png` · P1 · Batch 9.4

- **Used in:** Ghost / placement preview frame in each valid column (PLAY HERE).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x128. **Background:** transparent PNG (magenta #FF00FF key if it fails).
- **States:** normal (code tint amber) / protector (TAKES THE FRONT) / invalid (dim). **9-slice (L,T,R,B at ship size):** 20,20,20,20.
- **Code id:** `frm_ghost` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `fx_hit_flash.png` · P2 · Batch 17.4

- **Used in:** Hit flash on a banner when damage lands.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 512x128. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** normal (tinted by damage type).
- **Code id:** `fx_hit_flash` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `fx_tracer.png` · P2 · Batch 17.5

- **Used in:** Tracer line from shooter to target (stretched along the path), Pick / Flank curve, Pierce through.
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 256x16. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** tinted by side.
- **Code id:** `fx_tracer` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `fx_crack.png` · P3 · Batch 21.6

- **Used in:** Red crack for 2 s when a set switches off (trait rail chip), banner break.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 128x128. **Background:** white on black: TA converts brightness to alpha.
- **States:** tint red.
- **Code id:** `fx_crack` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

##### `fx_sheen.png` · P3 · Batch 21.7

- **Used in:** Frame sheen sweep on animated finishes and hover.
- **Generate:** 1024x1024 (square 1:1). **Ship:** 256x256. **Background:** glow on black: additive blend in game, no alpha needed.
- **States:** sweep (code moves it).
- **Code id:** `fx_sheen` (needs code (no UiKit lookup yet)). **Fallback:** code fallback kept.

#### C1+ board card overlays (2)

##### `fx_glow_rail.png` · P1 · Batch 2.6 · **new (kc-ui-art2)**

- **Used in:** Rail highlight: tap or hover a SETS chip and every matching card glows in the trait colour (board 4:1 cards and X1 hand cards).
- **Generate:** 1536x1024 (landscape 3:2). **Ship:** 576x192. **Background:** glow on black: the TA turns brightness into alpha (white glow, tinted per trait in code).
- **States:** tinted by the trait colour (code) / optional slow pulse (code alpha). **9-slice (L,T,R,B at ship size):** 48,48,48,48.
- **Code id:** `fx_glow_rail` (needs code: banner_view.gd rail highlight (two draw_rect calls) -> UiKit.draw_piece(o, &"fx_glow_rail", r.grow(8 * k), trait colour)). **Fallback:** code fallback works, but the image clearly beats it.
- **Note:** TA: process as luma (brightness to alpha) rather than additive, so banner_view can draw it with a normal blend and tint it per trait. Ask for the glow across the whole canvas width; crop a 4:1 band with 32 px of halo on each side.

##### `fx_crack_damage.png` · P2 · Batch 2.7 · **new (kc-ui-art2)**

- **Used in:** Damaged card: the corner crack, top-left, on C1+ board cards and hand cards (with the code's amber bottom edge).
- **Generate:** 1024x1024 (square 1:1). **Ship:** 64x64. **Background:** white on black: TA converts brightness to alpha.
- **States:** damaged (code: a dark copy 1 px wider underneath, then this tinted amber #F2A33A) / healed (hidden).
- **Code id:** `fx_crack_damage` (needs code: CardLook.draw_crack -> UiKit.draw_piece(&"fx_crack_damage") (dark copy, then amber)). **Fallback:** code fallback is fine (image optional).
- **Note:** Code fallback (CardLook.draw_crack, five-point polyline) is acceptable; the image gives a hand-drawn, less mechanical crack.

## 5. Batches: the prompts, in the order to generate them

Order is by **visual impact on the card design now in the game**: batch 2 is the new card look (the Pick icon, the Y2+ and T1 frames, the rail glow, the crack), batch 3 the Standard Issue starter (the first cards every new player sees, already wired), then the keyword and trait icons every card shows, then the rest of P1, P2 and P3.

- **One batch = one sitting and one upload** (5 to 12 images, 10 to 15 minutes).
- **One ChatGPT chat per group.** Each prompt says *New chat* where a new group starts; inside a group, stay in the same chat so the set matches.
- **Every grey box is one complete prompt:** copy it as is, one per message. After the first image of a group you may shorten the next to "Same style, next one: ...", but paste the full box again if the look drifts.
- **Upload** in the Studio Floor chat, **"+ Images / logs"**, with the batch's upload line (copy it from the batch).
- **If one fails twice**, skip it and say so in the upload line; the code fallback covers every slot.

| Batch | Priority | What | Images | Files |
|---|---|---|---|---|
| 1 | P1 | P1 icons (imported, see `ui-kit-import-log.md`) | 10 | `ico_stat_firepower`, `ico_stat_armor`, `ico_stat_cover`, `ico_stat_supply`, `ico_stat_deck`, `ico_stat_intel`, `ico_streak`, `ico_score`, `ico_kw_first_shot`, `ico_kw_pick` |
| 2 | P1 | New card look: Pick icon, Y2+ and T1 frames, rail glow, crack | 7 | `ico_kw_pick_v2`, `frm_y2_unit`, `frm_y2_operator`, `frm_t1_orders`, `tex_orders_paper`, `fx_glow_rail`, `fx_crack_damage` |
| 3 | P1 | Standard Issue starter: the 5 arts and their frames | 9 | `kc_b_si_grunt`, `kc_b_si_trooper`, `kc_b_si_sergeant`, `kc_b_si_armored`, `kc_b_si_ammo_resupply`, `frm_standard_issue`, `frm_y2_standard_issue`, `frm_socket_locked`, `ico_ui_lock` |
| 4 | P1 | Keyword icons on every card (abilities chip, Y2+ text box) | 10 | `ico_kw_flank`, `ico_kw_pierce`, `ico_kw_suppress`, `ico_kw_patch`, `ico_kw_protector`, `ico_kw_guard`, `ico_kw_spotter`, `ico_kw_fireteam`, `ico_kw_overwatch`, `ico_effect_bolt` |
| 5 | P1 | Trait chips, the painted stat badges and the New: explainer | 9 | `ico_trait_vanguard`, `ico_trait_specops`, `ico_trait_heavy`, `ico_trait_undead`, `plate_fp_reticle`, `plate_armor_ballistic`, `coin_level`, `pnl_new_card`, `pnl_new_inset` |
| 6 | P1 | Icons | 9 | `ico_type_unit`, `ico_type_tactic`, `ico_type_field`, `ico_ks_recon_drone`, `ico_ks_mortar`, `ico_ks_attack_helo`, `ico_ks_sentry`, `ico_ctl_yours`, `ico_ctl_rival` |
| 7 | P1 | Icons | 9 | `ico_ctl_even`, `ico_overrun`, `ico_ui_menu`, `ico_ui_undo`, `ico_ui_speed`, `ico_ui_close`, `ico_ui_back`, `ico_ui_eye`, `ico_ui_eye_off` |
| 8 | P1 | Icons, Backgrounds, Glows, outlines and overlays | 9 | `ico_ui_check`, `bg_title`, `bg_run_map`, `bg_supply_drop`, `bg_match`, `col_containers`, `col_cranes`, `col_offices`, `fx_outline_teal` |
| 9 | P1 | Glows, outlines and overlays, Card frame parts, Buttons and controls | 9 | `fx_outline_side`, `fx_glow_amber`, `fx_link_tick`, `frm_ghost`, `frm_front_tab`, `frm_plan_plate`, `frm_incoming`, `frm_put_back`, `btn_primary` |
| 10 | P1 | Buttons and controls, Panels, trays, rings and strips | 9 | `btn_primary_pressed`, `btn_secondary`, `btn_secondary_pressed`, `btn_ready`, `btn_ready_pressed`, `btn_badge`, `pnl_tray`, `pnl_flyout`, `pnl_toast` |
| 11 | P1 | Panels, trays, rings and strips, Objective and Field tile backers | 9 | `pnl_inspector`, `pnl_modal`, `pnl_ks_tile`, `ring_track`, `ring_fill`, `pip_supply`, `pnl_pick_tile`, `tile_objective`, `tile_field_chip` |
| 12 | P2 | Icons | 10 | `ico_stat_discard`, `ico_stat_hand`, `ico_eliminated`, `ico_tickets`, `ico_fired`, `ico_heal`, `ico_damage`, `ico_kw_holder`, `ico_kw_hidden`, `ico_trig_on_deploy` |
| 13 | P2 | Icons | 10 | `ico_trig_on_down`, `ico_kw_aura`, `ico_type_killstreak`, `ico_type_operator`, `ico_elite_star`, `ico_trap`, `ico_plan_mark`, `ico_class_ar`, `ico_class_smg`, `ico_class_shotgun` |
| 14 | P2 | Icons | 9 | `ico_class_sniper`, `ico_class_lmg`, `ico_ctl_open`, `ico_field_slot`, `ico_ph_deploy`, `ico_ph_reveal`, `ico_ph_firefight`, `ico_ph_score`, `ico_mode_zone_control` |
| 15 | P2 | Icons | 9 | `ico_mode_firefight`, `ico_mode_detonator`, `ico_mode_rival`, `ico_ui_settings`, `ico_ui_skip`, `ico_ui_codex`, `ico_ui_mirror`, `ico_ui_sound_on`, `ico_ui_sound_off` |
| 16 | P2 | Icons, Backgrounds | 9 | `ico_ui_info`, `ico_ui_filter`, `ico_ui_continue`, `ico_ui_retire`, `ico_ui_promote`, `ico_ui_reward`, `bg_after_action`, `bg_codex`, `bg_loadout` |
| 17 | P2 | Backgrounds, Glows, outlines and overlays, Card frame parts, Buttons and controls | 9 | `bg_loading`, `fx_glow_red`, `fx_link_tick_ghost`, `fx_hit_flash`, `fx_tracer`, `frm_dogtag_plate`, `card_back_banner`, `btn_danger`, `btn_chip` |
| 18 | P2 | Buttons and controls, Panels, trays, rings and strips | 9 | `btn_chip_on`, `tgl_track`, `tgl_knob`, `pnl_flyout_pointer`, `pnl_tooltip`, `pnl_header`, `pnl_hand_tab`, `pnl_counter`, `pnl_order_strip` |
| 19 | P2 | Panels, trays, rings and strips, Objective and Field tile backers | 9 | `order_node`, `order_arrow`, `pnl_rail_chip`, `pnl_callout`, `pnl_coach`, `pnl_result`, `runmap_node`, `tile_field_chip_trap`, `tile_slot_empty` |
| 20 | P3 | Icons | 9 | `ico_range_close`, `ico_range_mid`, `ico_range_long`, `ico_round`, `ico_ks_gunship`, `ico_att_optic`, `ico_att_grip`, `ico_att_mag`, `ico_att_lining` |
| 21 | P3 | Icons, Backgrounds, Glows, outlines and overlays, Card frame parts | 9 | `ico_perk_slot`, `ico_ui_rotate`, `ico_ui_survey`, `ico_ui_tutorial`, `bg_menu`, `fx_crack`, `fx_sheen`, `card_back_hand`, `frm_socket_empty` |
| 22 | P3 | Buttons and controls, Panels, trays, rings and strips, Camo bands | 8 | `btn_tab`, `sld_track`, `runmap_path`, `band_base`, `band_gilded`, `band_forged`, `band_priceless`, `band_interstellar` |

P1 is batches 1 to 11 (93 images, 84 still to make). After batches 2 and 3, pause and let the Technical Artist drop them into the build (batch 2 needs the small code hooks listed in section 7.4): if the frame style needs a tweak, it is cheaper to change the style block then.

### Batch 1 · P1 · P1 icons (imported, see `ui-kit-import-log.md`) (10)

**Done** (kc-ui-import). `kw_pick` from this batch is retired: Pick is now `kw_pick_v2` (batch 2). The other 9 stay in use.

### Batch 2 · P1 · New card look: Pick icon, Y2+ and T1 frames, rail glow, crack (7)

Upload line: `kc-ui-art2 batch 2: ico_kw_pick_v2, frm_y2_unit, frm_y2_operator, frm_t1_orders, tex_orders_paper, fx_glow_rail, fx_crack_damage`

#### 2.1 `ico_kw_pick_v2.png` · P1 · **New chat**

*Keywords.* Square 1:1, white on black: TA converts brightness to alpha. **new (kc-ui-art2).** For: Pick everywhere: C1+ abilities chip, Y2+ text box, glossary, inspector, Pick tracer tag.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a heater shield seen from the front (a flat top edge, straight sides that curve inward to one point at the bottom), drawn as a thick outline, with one thick arrow inside it pointing straight down, from the upper third of the shield to just above its bottom point, with a wide open arrowhead. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a crosshair, a circle, a ring, a reticle, a cross, a star, a crest or any mark on the shield besides the arrow.

#### 2.2 `frm_y2_unit.png` · P1 · **New chat**

*Y2+ card frames and the T1 orders frame.* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). **new (kc-ui-art2).** For: Every unit, Field and killstreak card off the board (Y2+): mulligan, Supply Drop / Salvage / Muster out picks, Codex grid, deck lists, inspector, hand dock.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. An upright playing-card frame a little wider than it is tall (about 7 to 6): a 3-pixel steel #4A5560 rim with small softly rounded corners (rounded, not chamfered), one soft top-left bevel highlight on the rim, and a dark gunmetal #1B2126 face filling the whole inside, flat and even with a very faint brushed grain, the face completely plain. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in, 45-degree chamfered corners, a window, a title bar or any inner panel drawn in, a notch, rivets in the middle of an edge.

#### 2.3 `frm_y2_operator.png` · P1

*Y2+ card frames and the T1 orders frame.* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). **new (kc-ui-art2).** For: The Operator's Y2+ card and the O2 Operator card bottom-left of the tray (OPERATOR tag, cost hex, state chip drawn by code).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. An upright playing-card frame a little wider than it is tall (about 7 to 6): a 3-pixel polished brass #C9A227 rim with small softly rounded corners (rounded, not chamfered), one soft top-left highlight on the rim, and a very dark brass-brown #1E1A10 face filling the whole inside, flat and even with a faint fine brushed grain, the face completely plain. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in, 45-degree chamfered corners, a dog-tag shape, a chain or hole, ornaments, engraving, a window drawn in.

#### 2.4 `frm_t1_orders.png` · P1

*Y2+ card frames and the T1 orders frame.* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). **new (kc-ui-art2).** For: Every Tactic card off the board (Y2+ with the T1 orders frame): mulligan, rewards, Codex, inspector, hand dock.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering of matte field-orders paper: dark olive-brown and khaki, a faint even fibre grain, crisp straight edges, no grunge, no stains, no folds, no wear marks. Bold simple shapes that stay readable when shrunk small. Palette: olive-brown #2B2716, dark olive #1F1C10, khaki #B8913A, pale khaki #D9C48A, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, stamps, seals, insignia, flags or emblems. An upright field-orders sheet shaped like a playing card a little wider than it is tall (about 7 to 6): a 3-pixel khaki #B8913A rim, the top-right corner cut off by one straight 45-degree cut about one fourteenth of the width, the other three corners slightly rounded, a dark olive-brown #2B2716 face with a faint matte paper fibre grain, and a slightly lighter khaki-tinted strip running along the whole top edge for the top seventh of the height; matte paper, not metal. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in, writing, stamps, a seal, folds, coffee stains, a second cut corner, a curled page, rivets.

#### 2.5 `tex_orders_paper.png` · P2

*Y2+ card frames and the T1 orders frame.* Square 1:1, opaque, no transparency. **new (kc-ui-art2).** For: Paper grain tiled over the T1 face and text box (about 60% opacity), so the orders frame reads as paper at any card width.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering of matte field-orders paper: dark olive-brown and khaki, a faint even fibre grain, crisp straight edges, no grunge, no stains, no folds, no wear marks. Bold simple shapes that stay readable when shrunk small. Palette: olive-brown #2B2716, dark olive #1F1C10, khaki #B8913A, pale khaki #D9C48A, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, stamps, seals, insignia, flags or emblems. A seamless tileable texture of dark olive-brown #2B2716 field-order paper: a faint fibre grain and very soft mottling, low contrast, even all over, no folds, no stains, no edges, no writing. Fill the whole canvas edge to edge, flat front-on view. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, a cast shadow, a perspective tilt, text, stamps, creases, a border, a visible seam, bright spots.

#### 2.6 `fx_glow_rail.png` · P1 · **New chat**

*C1+ board card overlays.* Landscape 3:2, glow on black: the TA turns brightness into alpha (white glow, tinted per trait in code). **new (kc-ui-art2).** For: Rail highlight: tap or hover a SETS chip and every matching card glows in the trait colour (board 4:1 cards and X1 hand cards).

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A soft white glow around an empty, very wide rectangle four times wider than tall: a bright thin white line traces the rectangle with slightly rounded corners, and a smooth soft white halo fades outward from it, the inside of the rectangle staying black. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Landscape 3:2.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black, colour, an object or frame, sparkles, noise, a glow that fills the inside.

#### 2.7 `fx_crack_damage.png` · P2

*C1+ board card overlays.* Square 1:1, white on black: TA converts brightness to alpha. **new (kc-ui-art2).** For: Damaged card: the corner crack, top-left, on C1+ board cards and hand cards (with the code's amber bottom edge).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: a small jagged crack that starts exactly at the top-left corner and runs down and to the right in four sharp zig-zag bends, with one short branch splitting off to the right near the top, every line thick. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black, glass shards, a shattered pane, more than one branch, hairline cracks, a frame or corner bracket.

### Batch 3 · P1 · Standard Issue starter: the 5 arts and their frames (9)

Upload line: `kc-ui-art2 batch 3: kc_b_si_grunt, kc_b_si_trooper, kc_b_si_sergeant, kc_b_si_armored, kc_b_si_ammo_resupply, frm_standard_issue, frm_y2_standard_issue, frm_socket_locked, ico_ui_lock`

#### 3.1 `kc_b_si_grunt.png` · P1 · **New chat**

*Standard Issue card art (starter, our own art).* Landscape 3:2, opaque, no transparency. For: Grunt (cost 1, 2/2): Grunt x5 in the starter, TrainingBot and the M1 / M2 Standard Issue squads.

```
Original plain two-tone illustration for the basic starter cards of a modern military card game. One flat simple figure in olive drab #4B5320 and khaki #C3B091 against a muted grey-green #5E6B5A canvas or plain wooden supply-crate background. Flat shapes like a training-manual print, matte, low contrast, soft even light, no glow, no light effects, no dramatic lighting, only a faint canvas weave as texture. Deliberately modest and basic. A basic infantry soldier in a plain round helmet and simple fatigues standing at ease, a generic rifle held diagonally across the chest, three-quarter side view, two plain wooden supply crates stacked behind. Wide 3:2 landscape that will be cropped to a thin 4:1 strip across the middle (30% to 66% of the height) and a tall 2:3 column in the centre. Put the figure in the exact centre, head and hands between 30% and 65% of the height, inside the middle 60% of the width. The four corners of that strip stay empty, flat and calm, because the game puts small badges there: abilities top right, the traits bottom left, the firepower and armour badges bottom right, and the cost and level top left. Above and below, continue the plain background. No text, letters, numbers, stencils, serial numbers, logos, insignia, flags, badges, patches or symbols on clothing, gear or crates. Invented people only, faces simple or shaded by the helmet. No blood.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real weapon models, recognizable people, gore, a busy or bright corner, markings or stencils on crates, boxes or gear, glow, light beams, dramatic lighting, a second figure.

#### 3.2 `kc_b_si_trooper.png` · P1

*Standard Issue card art (starter, our own art).* Landscape 3:2, opaque, no transparency. For: Trooper (cost 2, 2/3): Trooper x6 in the starter, Standard Issue squads.

```
Original plain two-tone illustration for the basic starter cards of a modern military card game. One flat simple figure in olive drab #4B5320 and khaki #C3B091 against a muted grey-green #5E6B5A canvas or plain wooden supply-crate background. Flat shapes like a training-manual print, matte, low contrast, soft even light, no glow, no light effects, no dramatic lighting, only a faint canvas weave as texture. Deliberately modest and basic. A soldier in a plain helmet and a simple padded vest walking forward mid-stride, a generic rifle held low in both hands, side view, a plain canvas tent wall behind. Wide 3:2 landscape that will be cropped to a thin 4:1 strip across the middle (30% to 66% of the height) and a tall 2:3 column in the centre. Put the figure in the exact centre, head and hands between 30% and 65% of the height, inside the middle 60% of the width. The four corners of that strip stay empty, flat and calm, because the game puts small badges there: abilities top right, the traits bottom left, the firepower and armour badges bottom right, and the cost and level top left. Above and below, continue the plain background. No text, letters, numbers, stencils, serial numbers, logos, insignia, flags, badges, patches or symbols on clothing, gear or crates. Invented people only, faces simple or shaded by the helmet. No blood.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real weapon models, recognizable people, gore, a busy or bright corner, markings or stencils on crates, boxes or gear, glow, light beams, dramatic lighting, a second figure.

#### 3.3 `kc_b_si_sergeant.png` · P1

*Standard Issue card art (starter, our own art).* Landscape 3:2, opaque, no transparency. For: Sergeant (cost 3, 3/3): Sergeant x4 in the starter, Standard Issue squads.

```
Original plain two-tone illustration for the basic starter cards of a modern military card game. One flat simple figure in olive drab #4B5320 and khaki #C3B091 against a muted grey-green #5E6B5A canvas or plain wooden supply-crate background. Flat shapes like a training-manual print, matte, low contrast, soft even light, no glow, no light effects, no dramatic lighting, only a faint canvas weave as texture. Deliberately modest and basic. A soldier in a plain helmet with one arm stretched forward pointing the way, a generic rifle in the other hand, side view, one boot up on a low wooden crate, a plain canvas backdrop. Wide 3:2 landscape that will be cropped to a thin 4:1 strip across the middle (30% to 66% of the height) and a tall 2:3 column in the centre. Put the figure in the exact centre, head and hands between 30% and 65% of the height, inside the middle 60% of the width. The four corners of that strip stay empty, flat and calm, because the game puts small badges there: abilities top right, the traits bottom left, the firepower and armour badges bottom right, and the cost and level top left. Above and below, continue the plain background. No text, letters, numbers, stencils, serial numbers, logos, insignia, flags, badges, patches or symbols on clothing, gear or crates. Invented people only, faces simple or shaded by the helmet. No blood.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real weapon models, recognizable people, gore, a busy or bright corner, markings or stencils on crates, boxes or gear, glow, light beams, dramatic lighting, a second figure.

#### 3.4 `kc_b_si_armored.png` · P1

*Standard Issue card art (starter, our own art).* Landscape 3:2, opaque, no transparency. For: Armored Trooper (cost 4, 2/5): Armored Trooper x3 in the starter (the first card to send home), Standard Issue squads.

```
Original plain two-tone illustration for the basic starter cards of a modern military card game. One flat simple figure in olive drab #4B5320 and khaki #C3B091 against a muted grey-green #5E6B5A canvas or plain wooden supply-crate background. Flat shapes like a training-manual print, matte, low contrast, soft even light, no glow, no light effects, no dramatic lighting, only a faint canvas weave as texture. Deliberately modest and basic. A heavy soldier in bulky plain body armour and a full helmet with a dark visor, standing square and slow, a generic rifle held low, front three-quarter view, a low wall of plain sandbags behind. Wide 3:2 landscape that will be cropped to a thin 4:1 strip across the middle (30% to 66% of the height) and a tall 2:3 column in the centre. Put the figure in the exact centre, head and hands between 30% and 65% of the height, inside the middle 60% of the width. The four corners of that strip stay empty, flat and calm, because the game puts small badges there: abilities top right, the traits bottom left, the firepower and armour badges bottom right, and the cost and level top left. Above and below, continue the plain background. No text, letters, numbers, stencils, serial numbers, logos, insignia, flags, badges, patches or symbols on clothing, gear or crates. Invented people only, faces simple or shaded by the helmet. No blood.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real weapon models, recognizable people, gore, a busy or bright corner, markings or stencils on crates, boxes or gear, glow, light beams, dramatic lighting, a second figure.

#### 3.5 `kc_b_si_ammo_resupply.png` · P1

*Standard Issue card art (starter, our own art).* Landscape 3:2, opaque, no transparency. For: Ammo Resupply (tactic, Draw 2): Ammo Resupply x2 in the starter (Standard Issue art for the existing card).

```
Original plain two-tone illustration for the basic starter cards of a modern military card game. One flat simple figure in olive drab #4B5320 and khaki #C3B091 against a muted grey-green #5E6B5A canvas or plain wooden supply-crate background. Flat shapes like a training-manual print, matte, low contrast, soft even light, no glow, no light effects, no dramatic lighting, only a faint canvas weave as texture. Deliberately modest and basic. Two plain ammunition boxes and a canvas bag of rifle magazines on a wooden pallet, one gloved hand lifting a box lid, no person in view beyond the hand and forearm, side view. Wide 3:2 landscape that will be cropped to a thin 4:1 strip across the middle (30% to 66% of the height) and a tall 2:3 column in the centre. Put the figure in the exact centre, head and hands between 30% and 65% of the height, inside the middle 60% of the width. The four corners of that strip stay empty, flat and calm, because the game puts small badges there: abilities top right, the traits bottom left, the firepower and armour badges bottom right, and the cost and level top left. Above and below, continue the plain background. No text, letters, numbers, stencils, serial numbers, logos, insignia, flags, badges, patches or symbols on clothing, gear or crates. Invented people only, faces simple or shaded by the helmet. No blood.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real weapon models, recognizable people, gore, a busy or bright corner, markings or stencils on crates, boxes or gear, glow, light beams, dramatic lighting, a second figure.

#### 3.6 `frm_standard_issue.png` · P1 · **New chat**

*Standard Issue frame and plates.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). **revised (kc-ui-art2).** For: Standard Issue board card (C1+, full art inside it), the X1 hand card and the New: explainers (no camo band, no foil, no serial plate).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A very wide thin card frame, four times wider than tall, made of matte grey-green #5E6B5A painted sheet steel with slightly worn flat paint: an even 4-pixel border, small square corners, one small flat-head screw in each of the four corners, no shine, no foil, the inside completely empty. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 3.7 `frm_y2_standard_issue.png` · P1 · **New chat**

*Y2+ card frames and the T1 orders frame.* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). **new (kc-ui-art2).** For: Standard Issue cards off the board (Y2+): starter list, mulligan, Muster out, Codex.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. An upright playing-card frame a little wider than it is tall (about 7 to 6): a 3-pixel rim of matte grey-green #5E6B5A painted sheet steel with slightly worn flat paint and small softly rounded corners (rounded, not chamfered), one tiny flat-head screw in each corner, and a dark #1B2126 face filling the whole inside, flat and plain, no shine, no foil. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in, 45-degree chamfered corners, stencils, serial numbers, a window drawn in, rivets in the middle of an edge.

#### 3.8 `frm_socket_locked.png` · P1 · **New chat**

*Standard Issue frame and plates.* Square 1:1, white on black: TA converts brightness to alpha. For: Recruit padlock in the top-right abilities chip on C1+ cards (StandardIssueLook.draw_locked_keyword) and the Y2+ text box.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: a small square socket rim with 45-degree chamfered corners and a compact solid padlock shape sitting over its bottom-right corner, the padlock about one third of the socket's width, the inside of the socket empty. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black, a keyword symbol inside, a keyhole too small to see.

#### 3.9 `ico_ui_lock.png` · P1 · **New chat**

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: Locked keyword pip badge (frm_socket_locked), locked Codex art, NOT FOUND YET.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a closed padlock with a round shackle and a keyhole. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

### Batch 4 · P1 · Keyword icons on every card (abilities chip, Y2+ text box) (10)

Upload line: `kc-ui-art2 batch 4: ico_kw_flank, ico_kw_pierce, ico_kw_suppress, ico_kw_patch, ico_kw_protector, ico_kw_guard, ico_kw_spotter, ico_kw_fireteam, ico_kw_overwatch, ico_effect_bolt`

#### 4.1 `ico_kw_flank.png` · P1 · **New chat**

*Keywords.* Square 1:1, white on black: TA converts brightness to alpha. For: Banner effect slot, Flank tracer tag, inspector.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a thick curved arrow that leaves from the left, swings around the top of a small solid square, and hooks down into the right side. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 4.2 `ico_kw_pierce.png` · P1

*Keywords.* Square 1:1, white on black: TA converts brightness to alpha. For: Banner effect slot on Marksman and Ace, '-1 PIERCE' second number, inspector.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a straight arrow pointing down that passes through the middle of a thick chevron (the chevron opens downward), the arrow shaft visible above and below it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 4.3 `ico_kw_suppress.png` · P1

*Keywords.* Square 1:1, white on black: TA converts brightness to alpha. For: Banner effect slot (Gunner), suppressed status, inspector.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: three short parallel diagonal tracer lines coming down from the upper left onto a thick horizontal bar, pressing it down. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 4.4 `ico_kw_patch.png` · P1

*Keywords.* Square 1:1, white on black: TA converts brightness to alpha. For: Banner effect slot (Combat Medic), heal tag, inspector.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a field bandage roll seen from the side with a strip unrolling from it in a loose curl. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a cross, plus sign or any medical emblem on the bandage.

#### 4.5 `ico_kw_protector.png` · P1

*Keywords.* Square 1:1, white on black: TA converts brightness to alpha. For: Banner effect slot, TAKES THE FRONT preview, Protector slide.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a tall solid riot-shield shape with a small rectangular viewport slot, standing in front of a smaller rounded helmet outline that is half hidden behind it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 4.6 `ico_kw_guard.png` · P1

*Keywords.* Square 1:1, white on black: TA converts brightness to alpha. For: Keyword pip on Trained banners and hand cards, link preview, inspector.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a short solid wall made of two rows of thick rectangular blocks, two blocks in the bottom row and one centred block on top, compact and square. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, an arrow (the game adds it), a shield shape, a circle.

#### 4.7 `ico_kw_spotter.png` · P1

*Keywords.* Square 1:1, white on black: TA converts brightness to alpha. For: Keyword pip, link preview, inspector.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a pair of binoculars seen from the front, drawn as two thick upright rectangular barrels side by side joined by a short solid bridge, compact and square. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, an arrow (the game adds it), an eye, round lenses or circles.

#### 4.8 `ico_kw_fireteam.png` · P1

*Keywords.* Square 1:1, white on black: TA converts brightness to alpha. For: Keyword pip, link preview, inspector.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: two thick open chevrons pointing away from each other, one pointing left and one pointing right, with a small gap between them. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 4.9 `ico_kw_overwatch.png` · P1

*Keywords.* Square 1:1, white on black: TA converts brightness to alpha. For: Keyword pip, link preview, inspector.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a short thick horizontal bar like a visor slit with a solid square in its middle, and one solid triangular arrowhead on each side pointing outward left and right, compact. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a circle, a ring, a reticle or crosshair.

#### 4.10 `ico_effect_bolt.png` · P1

*Keywords.* Square 1:1, white on black: TA converts brightness to alpha. For: Banner effect slot for triggered or aura text (with a dot if more), Field auras.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a bold lightning bolt with three straight segments, thick and angular. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

### Batch 5 · P1 · Trait chips, the painted stat badges and the New: explainer (9)

Upload line: `kc-ui-art2 batch 5: ico_trait_vanguard, ico_trait_specops, ico_trait_heavy, ico_trait_undead, plate_fp_reticle, plate_armor_ballistic, coin_level, pnl_new_card, pnl_new_inset`

#### 5.1 `ico_trait_vanguard.png` · P1 · **New chat**

*Traits.* Square 1:1, white on black: TA converts brightness to alpha. For: Trait pip on banners and hand cards, trait rail, SETS flyout, Doctrine tiles, deck view.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: two thick stacked upward chevrons, one above the other, like a rank stripe pointing up. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a rank insignia layout, stars, laurels.

#### 5.2 `ico_trait_specops.png` · P1

*Traits.* Square 1:1, white on black: TA converts brightness to alpha. For: Trait pip, rail, flyout, Doctrine, deck view.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a face mask seen from the front: a wide band shape with two narrow rectangular eye slits cut out of it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a skull, a face, any emblem.

#### 5.3 `ico_trait_heavy.png` · P1

*Traits.* Square 1:1, white on black: TA converts brightness to alpha. For: Trait pip, rail, flyout, Doctrine, deck view.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a heavy machine gear: a thick ring with eight short square teeth around it and a solid hub in the centre. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 5.4 `ico_trait_undead.png` · P1

*Traits.* Square 1:1, white on black: TA converts brightness to alpha. For: Trait pip, rail, flyout, Doctrine, deck view, UNDEAD HEAL tag.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a bony hand with four fingers reaching up out of a flat ground line, only the hand and wrist visible. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, blood, rot, a skull, gore.

#### 5.5 `plate_fp_reticle.png` · P2 · **New chat**

*C1+ stat badges (optional painted finish).* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). **new (kc-ui-art2).** For: FP reticle bottom-right of every C1+ card (26 px phone), the Y2+ stats bar (28 px) and the inspector (up to 52 px); the number is code text.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A round gun-sight ring badge for a number: a thick light steel #C9D1D8 metal ring broken by four short square gaps at the top, bottom, left and right, around a dark #2A3238 recessed disc, the disc plain and empty and at least 70% of the badge width so a two-digit number fits; one soft top-left highlight on the ring. One element only, centred, filling about 80% of the canvas. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in, a number, a centre dot, a cross, tick marks, a second ring.

#### 5.6 `plate_armor_ballistic.png` · P2

*C1+ stat badges (optional painted finish).* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). **new (kc-ui-art2).** For: Armor plate right of FP on every C1+ card, the Y2+ stats bar and the inspector; only the number left is shown (code text).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A ballistic armour plate badge for a number: a rounded rectangle about as wide as it is tall, with its two top corners clipped off at 45 degrees and softly rounded bottom corners, a thick light steel #C9D1D8 rim and a dark #2A3238 face, the face plain and empty and big enough for a two-digit number; faint brushed grain, one soft top-left highlight. One element only, centred, filling about 80% of the canvas. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in, a number, a crest, a cross, a star, rivets, a pointed bottom, straps.

#### 5.7 `coin_level.png` · P3

*C1+ stat badges (optional painted finish).* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). **new (kc-ui-art2).** For: Level coin in the C1+ peek group (17 px) and on the Y2+ type line (16 px): R / T / V / E is code text.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small round coin badge: a thick light steel #C9D1D8 rim and a dark #14181C face, plain and empty for one letter; one soft top-left highlight. One element only, centred, filling about 80% of the canvas. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in, a letter, a star, laurels, engraving, a ribbon.

#### 5.8 `pnl_new_card.png` · P1 · **New chat**

*First-time explainer (New: X).* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: 'New: X' one-time explainer card (half screen: icon, one sentence, mini example, GOT IT), queued one per screen.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A large explainer card panel: dark gunmetal #232A31 face with a soft lighter centre, a 2-pixel steel #4A535B outline, 45-degree chamfered corners, a short solid amber #FFB020 flag tab hanging from the top-left corner (plain, for a word the game adds), a thin amber line running along the top edge from the tab. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 5.9 `pnl_new_inset.png` · P1

*First-time explainer (New: X).* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Mini example well inside the New: card (a mini board grid, a card, a trait counter).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A recessed rectangular well: near-black #0F1316 face sunk into the metal, a thin dark inner shadow along the top and left edges and a 1-pixel light steel line along the bottom and right edges, small chamfered corners. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

### Batch 6 · P1 · Icons (9)

Upload line: `kc-ui-art2 batch 6: ico_type_unit, ico_type_tactic, ico_type_field, ico_ks_recon_drone, ico_ks_mortar, ico_ks_attack_helo, ico_ks_sentry, ico_ctl_yours, ico_ctl_rival`

#### 6.1 `ico_type_unit.png` · P1 · **New chat**

*Card types and card marks.* Square 1:1, white on black: TA converts brightness to alpha. For: Hand card type glyph, Codex UNITS filter, inspector type line.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: the head-and-shoulders silhouette of a soldier in a rounded helmet seen from the front, no face details. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 6.2 `ico_type_tactic.png` · P1

*Card types and card marks.* Square 1:1, white on black: TA converts brightness to alpha. For: Hand card type glyph, Codex TACTICS filter, inspector.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a tactical plan: a curved dashed arrow from a small circle to a small X. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 6.3 `ico_type_field.png` · P1

*Card types and card marks.* Square 1:1, white on black: TA converts brightness to alpha. For: Hand card type glyph, Codex FIELDS filter, objective Field chips.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a small fortified position: a low sandbag wall arc of four rounded bags with a short pole standing behind it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 6.4 `ico_ks_recon_drone.png` · P1 · **New chat**

*Killstreaks and Operator equipment.* Square 1:1, white on black: TA converts brightness to alpha. For: Killstreak tile in the tray (charge ring), STREAK flyout, Codex, call-in.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a small quadcopter drone seen from the front, four rotor discs, with a downward cone of three short lines under it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real drone, helicopter or aircraft model, roundels, markings, numbers.

#### 6.5 `ico_ks_mortar.png` · P1

*Killstreaks and Operator equipment.* Square 1:1, white on black: TA converts brightness to alpha. For: Killstreak tile (Mortar Barrage), flyout, Codex.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: three falling mortar shells in a row, nose down, each with a short curved trail above it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real drone, helicopter or aircraft model, roundels, markings, numbers.

#### 6.6 `ico_ks_attack_helo.png` · P1

*Killstreaks and Operator equipment.* Square 1:1, white on black: TA converts brightness to alpha. For: Killstreak tile (Attack Helo), flyout, Codex.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: side-profile silhouette of a fictional slim attack helicopter flying right, one main rotor line on top, a stub wing, a nose turret. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real drone, helicopter or aircraft model, roundels, markings, numbers.

#### 6.7 `ico_ks_sentry.png` · P1

*Killstreaks and Operator equipment.* Square 1:1, white on black: TA converts brightness to alpha. For: Killstreak tile (Sentry Turret), flyout, Codex, Sentry token gear mark.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a compact automated gun turret on a tripod, a boxy head with one short barrel pointing right. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real drone, helicopter or aircraft model, roundels, markings, numbers.

#### 6.8 `ico_ctl_yours.png` · P1 · **New chat**

*Objective, control and Field.* Square 1:1, white on black: TA converts brightness to alpha. For: Objective tile control mark (YOURS), minimap, score sheet; tinted teal.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a thick solid ring with a solid dot in the centre. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 6.9 `ico_ctl_rival.png` · P1

*Objective, control and Field.* Square 1:1, white on black: TA converts brightness to alpha. For: Objective tile control mark (RIVAL); tinted red. Shape cue for colour-blind players.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a solid diamond with a small notch cut into each of its four corners. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

### Batch 7 · P1 · Icons (9)

Upload line: `kc-ui-art2 batch 7: ico_ctl_even, ico_overrun, ico_ui_menu, ico_ui_undo, ico_ui_speed, ico_ui_close, ico_ui_back, ico_ui_eye, ico_ui_eye_off`

#### 7.1 `ico_ctl_even.png` · P1 · **New chat**

*Objective, control and Field.* Square 1:1, white on black: TA converts brightness to alpha. For: Objective tile control mark (EVEN, was CONTESTED).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a square drawn as a thick dashed outline, eight dashes, empty inside. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 7.2 `ico_overrun.png` · P1

*Objective, control and Field.* Square 1:1, white on black: TA converts brightness to alpha. For: FIELD OVERRUN callout, overrun risk on the Field chip, OVERRUN tag.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a low sandbag wall broken in the middle with two thick arrows crashing through the gap from above. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 7.3 `ico_ui_menu.png` · P1 · **New chat**

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: MENU badge (strip top), title.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: three thick horizontal bars of equal length stacked with equal gaps. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 7.4 `ico_ui_undo.png` · P1

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: UNDO button in the tray (Deploy).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a thick curved arrow that loops back to the left, like a U-turn pointing left. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 7.5 `ico_ui_speed.png` · P1

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: SPEED x2 button in the tray (Firefight), settings.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: two solid triangles pointing right, touching tip to base, like fast-forward. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 7.6 `ico_ui_close.png` · P1

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: CLOSE on the inspector, flyouts, Codex, modals.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a thick X with squared ends. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 7.7 `ico_ui_back.png` · P1

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: BACK on Codex, Loadout, Retire picker.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a thick chevron pointing left with a short horizontal tail. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 7.8 `ico_ui_eye.png` · P1

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: PREVIEW badge ON.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: an open almond eye with a solid round pupil. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 7.9 `ico_ui_eye_off.png` · P1

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: PREVIEW badge OFF.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: an open almond eye outline with one thick diagonal slash across it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

### Batch 8 · P1 · Icons, Backgrounds, Glows, outlines and overlays (9)

Upload line: `kc-ui-art2 batch 8: ico_ui_check, bg_title, bg_run_map, bg_supply_drop, bg_match, col_containers, col_cranes, col_offices, fx_outline_teal`

#### 8.1 `ico_ui_check.png` · P1 · **New chat**

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: Picked / ticked states, order strip finished column, PICKED tiles.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a thick tick mark with squared ends. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 8.2 `bg_title.png` · P1 · **New chat**

*Screen backgrounds.* Landscape 3:2, opaque, no transparency. For: Title screen (KillingCard wordmark drawn by code on the left third).

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. A dusk view over a fictional harbour container yard from a high crane: stacked containers in long rows, two gantry cranes as dark silhouettes against an amber horizon glow, one lone operator figure standing on a container in the right third, small and backlit. The left third is calm dark sky and haze for the title and buttons. Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom get cropped.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

#### 8.3 `bg_run_map.png` · P1

*Screen backgrounds.* Landscape 3:2, opaque, no transparency. For: Run map (5 matches, tickets, DEPLOY).

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. A top-down tactical map table: a dark paper map of a fictional harbour district with faint contour lines and water shapes, a few scattered plain playing-card shapes and a compass-free ruler lying on it, cool lamp light from above, very low contrast Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom get cropped.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

#### 8.4 `bg_supply_drop.png` · P1

*Screen backgrounds.* Landscape 3:2, opaque, no transparency. For: Supply Drop / Weapon Level / Perk Offer / Promotion / Doctrine / Regroup reward screens.

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. A supply crate under a parachute settling into a dark container yard, a floodlight cone on it, dust kicked up; the crate sits in the right fifth, the rest dark and calm for three cards and a fourth tile Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom get cropped.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

#### 8.5 `bg_match.png` · P1

*Screen backgrounds.* Landscape 3:2, opaque, no transparency. For: Match backdrop behind the strip, the 3 columns and the tray.

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. An abstract top-down view of dark wet concrete with faint painted parking-bay lines worn away, a few oil stains, subtle tyre marks, extremely low contrast, evenly lit, no objects Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom get cropped.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

#### 8.6 `col_containers.png` · P1 · **New chat**

*Column location backdrops (Port Vasel).* Portrait 2:3, opaque, no transparency. For: Column backing: containers.

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. A narrow canyon between two walls of stacked shipping containers seen from directly above, long straight shapes running top to bottom, a wet strip of ground down the middle. Top-down, very low contrast, flat even light, no focal point, nothing bright in the middle, similar detail all the way from top to bottom. Tall 2:3 portrait. Only the middle 60% of the width is used and it is shown at a third of its brightness behind game cards, so keep it subtle and even. Seen from directly above.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

#### 8.7 `col_cranes.png` · P1

*Column location backdrops (Port Vasel).* Portrait 2:3, opaque, no transparency. For: Column backing: cranes.

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. The steel lattice of a gantry crane leg and rail tracks seen from above, running top to bottom, a few cable shadows, dark water at one side. Top-down, very low contrast, flat even light, no focal point, nothing bright in the middle, similar detail all the way from top to bottom. Tall 2:3 portrait. Only the middle 60% of the width is used and it is shown at a third of its brightness behind game cards, so keep it subtle and even. Seen from directly above.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

#### 8.8 `col_offices.png` · P1

*Column location backdrops (Port Vasel).* Portrait 2:3, opaque, no transparency. For: Column backing: offices.

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. The flat roof of a low port office block seen from directly above: air-conditioning boxes, roof vents, a stair hatch, a parapet edge running top to bottom. Top-down, very low contrast, flat even light, no focal point, nothing bright in the middle, similar detail all the way from top to bottom. Tall 2:3 portrait. Only the middle 60% of the width is used and it is shown at a third of its brightness behind game cards, so keep it subtle and even. Seen from directly above.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

#### 8.9 `fx_outline_teal.png` · P1 · **New chat**

*Glows, outlines, links and previews (additive overlays).* Landscape 3:2, glow on black: additive blend in game, no alpha needed. For: Selected card / badge outline (teal), valid-target slot.

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A thin rectangular outline of bright teal #2EC4B6 light with small chamfered corners and a soft glow spreading 12 pixels inside and outside the line, nothing in the middle. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Landscape 3:2.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

### Batch 9 · P1 · Glows, outlines and overlays, Card frame parts, Buttons and controls (9)

Upload line: `kc-ui-art2 batch 9: fx_outline_side, fx_glow_amber, fx_link_tick, frm_ghost, frm_front_tab, frm_plan_plate, frm_incoming, frm_put_back, btn_primary`

#### 9.1 `fx_outline_side.png` · P1 · **New chat**

*Glows, outlines, links and previews (additive overlays).* Landscape 3:2, glow on black: additive blend in game, no alpha needed. For: Now-firing outline in the owner's colour (tinted teal / red), lift on shot.

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A thin rectangular outline of pure white light with small chamfered corners and a soft glow spreading 12 pixels inside and outside the line, nothing in the middle. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Landscape 3:2.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

#### 9.2 `fx_glow_amber.png` · P1

*Glows, outlines, links and previews (additive overlays).* Square 1:1, glow on black: additive blend in game, no alpha needed. For: Ready glow: killstreak tile READY, Operator DEPLOY, READY button pulse, order node current.

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A soft rounded-square halo of warm amber #FFB020 light, brightest at the edge of an empty dark square centre and fading out smoothly, nothing solid. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Square 1:1.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

#### 9.3 `fx_link_tick.png` · P1

*Glows, outlines, links and previews (additive overlays).* Square 1:1, glow on black: additive blend in game, no alpha needed. For: Link ticks: vertical (Guard, Spotter) across the row gap, horizontal (Fireteam, Overwatch) across the gutter; tinted by owner.

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A single short vertical bar of pure white light with rounded ends and a soft glow around it, brightest in the core. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Square 1:1.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

#### 9.4 `frm_ghost.png` · P1

*Glows, outlines, links and previews (additive overlays).* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Ghost / placement preview frame in each valid column (PLAY HERE).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A very wide thin rectangular frame drawn as an even dashed line of fog white #D8DEE3 with small corner brackets, the inside completely empty. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 9.5 `frm_front_tab.png` · P1 · **New chat**

*Board banner frame (4:1).* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). For: FRONT tab (48x13 phone, 64x15 desktop) on the front-row card; word drawn by code.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small flat tab shaped like a trapezoid, wider at the bottom, solid fog white #D8DEE3 face with a thin darker outline, plain. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 9.6 `frm_plan_plate.png` · P1

*Board banner frame (4:1).* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). For: PLAN tag on your planned cards (inner-edge centre) and PLAN · B on the Operator card.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small slanted tag plate: a short parallelogram, dark brass #3A2D0B face with a thin brass #C9A227 outline, plain. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 9.7 `frm_incoming.png` · P1

*Board banner frame (4:1).* Landscape 3:2, opaque, no transparency. For: INCOMING face-down rival banner (back pattern, fills the whole 4:1 banner).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A seamless dark card-back pattern for a very wide card: diagonal hazard-free fine chevron weave in gunmetal #232A31 on slate #12161A, a slightly brighter abstract arrow pattern pointing down repeated evenly, low contrast. Fill the whole canvas edge to edge, flat front-on view. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, a cast shadow, a perspective tilt, emblems, a central logo, letters, a skull.

#### 9.8 `frm_put_back.png` · P1 · **New chat**

*Hand card, Codex and mulligan.* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). For: Mulligan PUT BACK plate on marked cards (word drawn by code).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A diagonal band laid across a card from lower left to upper right: semi-transparent dark red #5A1A1C at 85% with thin bright red #E5383B edges and short hazard ticks at both ends, nothing else. One element only, centred, filling about 80% of the canvas. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 9.9 `btn_primary.png` · P1 · **New chat**

*Buttons.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Primary actions: CONTINUE, BEGIN RUN, TAP TO TAKE, DEPLOY (run map), PLAY HERE confirm.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A wide button plate: signal amber #FFB020 face with a slightly darker amber #C98A10 bottom edge 1/8 of its height, a thin darker outline, 45-degree chamfered corners top-left and bottom-right only, a faint brushed-metal grain on the face, a soft one-pixel highlight along the top edge, plain flat face with nothing on it. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

### Batch 10 · P1 · Buttons and controls, Panels, trays, rings and strips (9)

Upload line: `kc-ui-art2 batch 10: btn_primary_pressed, btn_secondary, btn_secondary_pressed, btn_ready, btn_ready_pressed, btn_badge, pnl_tray, pnl_flyout, pnl_toast`

#### 10.1 `btn_primary_pressed.png` · P1 · **New chat**

*Buttons.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Pressed state of btn_primary.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. The same wide amber button plate as before but pressed in: the face one shade darker #E59A12, the darker bottom edge gone, a thin inner shadow along the top edge, same chamfered corners, same size and outline. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 10.2 `btn_secondary.png` · P1

*Buttons.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Secondary actions: BACK, SKIP, DETAILS, DECK, CODEX, pause menu rows, Codex filter bar buttons.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A wide button plate: dark gunmetal #2E3740 face, a 2-pixel steel #4A535B outline, a slightly darker #232A31 bottom edge 1/8 of its height, 45-degree chamfered corners top-left and bottom-right only, faint brushed grain, a thin cool highlight along the top edge, plain empty face. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 10.3 `btn_secondary_pressed.png` · P1

*Buttons.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Pressed state of btn_secondary.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. The same gunmetal button plate pressed in: face one shade darker #262E35, no bottom edge, a thin inner shadow along the top, same chamfers and outline. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 10.4 `btn_ready.png` · P1

*Buttons.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: READY in the tray (245x64 phone, 149x72 desktop): the main button of every round.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A big wide command button plate: amber #FFB020 face with a darker amber bottom edge, a thick dark #12161A outline, chamfered top-left and bottom-right corners, and a band of three short dark diagonal hazard stripes at the far right end only; the rest of the face is plain and flat. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 10.5 `btn_ready_pressed.png` · P1

*Buttons.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Pressed state of READY.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. The same READY button plate pressed in: amber face one shade darker, no bottom edge, a thin inner top shadow, stripes unchanged. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 10.6 `btn_badge.png` · P1

*Buttons.* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). For: Icon strip badges 62x64 (MENU, SCORE, OPERATOR, STREAK, RIVAL, PREVIEW, DECK), SPEED, UNDO square.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A square badge plate: dark slate #1C2228 face, a 2-pixel steel #3A444D outline, all four corners chamfered at 45 degrees, a thin darker inner bevel, a faint vertical brushed grain, plain empty face. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 10.7 `pnl_tray.png` · P1 · **New chat**

*Panels, trays and overlays.* Portrait 2:3, transparent PNG (magenta #FF00FF key if it fails). For: Hand tray (362x532 phone, 224x776 desktop): background of the hand grid, killfeed log, step header.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A tall rectangular panel: matte gunmetal #1C2228 face with a very faint diagonal brushed grain, a 2-pixel steel #3A444D outline, 45-degree chamfers on the top-left and bottom-left corners only, a thin darker inner bevel; plain empty face, no screws in the middle of the edges. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Portrait 2:3.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 10.8 `pnl_flyout.png` · P1

*Panels, trays and overlays.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Strip badge flyouts: SCORE, OPERATOR, STREAK, RIVAL, DECK, SETS.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A rectangular pop-out panel: dark slate #161B20 face at slightly lighter centre, a 2-pixel steel #4A535B outline with a thin amber #FFB020 line along the top edge only, all corners chamfered at 45 degrees. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 10.9 `pnl_toast.png` · P1

*Panels, trays and overlays.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Killfeed toasts (top centre, 2 max, 92% opacity), one-time callouts, 'Not enough Supply' toasts.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A slim wide strip panel: near-black #0F1316 face, a short angled cut at both ends like a ribbon, a thin steel outline, a narrow vertical accent bar inset at the left end in fog white (tinted by side in game). One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

### Batch 11 · P1 · Panels, trays, rings and strips, Objective and Field tile backers (9)

Upload line: `kc-ui-art2 batch 11: pnl_inspector, pnl_modal, pnl_ks_tile, ring_track, ring_fill, pip_supply, pnl_pick_tile, tile_objective, tile_field_chip`

#### 11.1 `pnl_inspector.png` · P1 · **New chat**

*Panels, trays and overlays.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Card inspector (512x128 banner + text panel, scrolls), item inspector, long-press rules.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A large rectangular information panel: dark slate #12161A face with a faint fine scanline texture, a 2-pixel steel #4A535B outline, chamfered top-left and bottom-right corners, a thin amber line along the top edge from the left corner for a third of the width. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 11.2 `pnl_modal.png` · P1

*Panels, trays and overlays.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Pause menu, match end (VICTORY / DEFEAT), Retire picker, score sheet, consent and surveys.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A large centred dialog panel: gunmetal #232A31 face with a soft lighter centre, a 3-pixel steel #4A535B outline and a thin inner second outline 6 pixels inside, chamfered corners on all four sides, a small plain rivet in each corner. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 11.3 `pnl_ks_tile.png` · P1

*Panels, trays and overlays.* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). For: Killstreak tile backer (61 px) at the top of the tray and in the STREAK flyout.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A square tile plate: dark slate #12161A face, a thin steel outline, chamfered corners, a circular recessed socket in the middle taking up 70% of the tile. One element only, centred, filling about 80% of the canvas. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 11.4 `ring_track.png` · P1

*Panels, trays and overlays.* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). For: Killstreak charge ring (empty track); TextureProgressBar under.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A thick flat circular ring track divided into eight equal segments by thin gaps, dark steel #2E3740, perfectly round, centred, nothing inside the ring. One element only, centred, filling about 80% of the canvas. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 11.5 `ring_fill.png` · P1

*Panels, trays and overlays.* Square 1:1, white on black: TA converts brightness to alpha. For: Killstreak charge ring fill; TextureProgressBar radial (tinted amber / cyan).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: the same thick circular ring divided into eight equal segments by thin gaps, solid pure white, perfectly round, centred, same size as before, nothing inside. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black.

#### 11.6 `pip_supply.png` · P1

*Panels, trays and overlays.* Square 1:1, white on black: TA converts brightness to alpha. For: Supply pips (up to 10) in the tray.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: a single small hexagonal pip seen front-on: solid pure white hexagon with a thin cut-in inner bevel line. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black.

#### 11.7 `pnl_pick_tile.png` · P1

*Panels, trays and overlays.* Portrait 2:3, transparent PNG (magenta #FF00FF key if it fails). For: Reward pick tiles (Supply Drop cards, Retire, Doctrine, Promotion, Perk Offer), Loadout picks.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. An upright tile frame: dark gunmetal face, a 2-pixel steel outline, chamfered top-left and bottom-right corners, a slightly lighter band across the bottom fifth for a caption. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Portrait 2:3.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 11.8 `tile_objective.png` · P1 · **New chat**

*Objective and Field tile backers.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Objective tile between the fronts (228x52 phone, 304x96 desktop): FP pair, control mark, words, Field chips.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A wide low plate set into the ground like a steel floor hatch: dark gunmetal #232A31 face, a 2-pixel steel #3A444D outline, small chamfered corners, two faint recessed grooves running across near the left and right ends, plain flat centre. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 11.9 `tile_field_chip.png` · P1

*Objective and Field tile backers.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Field chip on the objective tile (70x22 phone, 96x28 desktop), one per side.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small wide chip plate shaped like a dog-ear tag: a rectangle with the top-right corner clipped, near-black face, a thin fog-white outline, a short slot at the left end for a side colour bar. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

### Batch 12 · P2 · Icons (10)

Upload line: `kc-ui-art2 batch 12: ico_stat_discard, ico_stat_hand, ico_eliminated, ico_tickets, ico_fired, ico_heal, ico_damage, ico_kw_holder, ico_kw_hidden, ico_trig_on_deploy`

#### 12.1 `ico_stat_discard.png` · P2 · **New chat**

*Stats and resources.* Square 1:1, white on black: TA converts brightness to alpha. For: Used / discard count in the DECK flyout.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: two playing-card rectangles fanned apart with a curved arrow running underneath them from right to left. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 12.2 `ico_stat_hand.png` · P2

*Stats and resources.* Square 1:1, white on black: TA converts brightness to alpha. For: HAND · n PEEK tab, hand cap in the score sheet.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: three playing-card rectangles held in a tight fan, spreading upward from one corner. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 12.3 `ico_eliminated.png` · P2

*Stats and resources.* Square 1:1, white on black: TA converts brightness to alpha. For: Killfeed toast and log, after-action ELIMINATIONS, elimination stamp.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a minimal stylised skull seen from the front: rounded cranium, two hollow eye shapes, a short row of square teeth; no crossbones, no helmet, no wings. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, crossbones, bones, a helmet, wings, flames, any badge or emblem shape around it.

#### 12.4 `ico_tickets.png` · P2

*Stats and resources.* Square 1:1, white on black: TA converts brightness to alpha. For: REINFORCEMENT TICKETS on the run map, run end.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a ticket stub with a perforated edge down one side and a round notch cut out of each end. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 12.5 `ico_fired.png` · P2

*Stats and resources.* Square 1:1, white on black: TA converts brightness to alpha. For: Fired pip on each banner that has shot this round (cleared at Score).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a single spent rifle cartridge case lying on its side, open end to the right, no bullet in it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 12.6 `ico_heal.png` · P2

*Stats and resources.* Square 1:1, white on black: TA converts brightness to alpha. For: Heal number (+n) from Patch, Aid Station and Undead (tinted teal or green, never red).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a plus sign made of two thick bars with rounded ends, centred inside a thin rounded square outline. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a red cross, a red crescent, any medical emblem; the icon is pure white and is tinted green in game.

#### 12.7 `ico_damage.png` · P2

*Stats and resources.* Square 1:1, white on black: TA converts brightness to alpha. For: Hit marker beside damage numbers, killfeed, now-firing tracer end.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: an impact burst: a small solid centre with four sharp triangular shards flying outward diagonally. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 12.8 `ico_kw_holder.png` · P2 · **New chat**

*Keywords.* Square 1:1, white on black: TA converts brightness to alpha. For: Banner effect slot, control tooltip (counts for holding the column).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a solid triangular marker pennant on a short post driven into a flat ground line, with a small arc of ground around the base. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, national flag patterns, emblems on the pennant.

#### 12.9 `ico_kw_hidden.png` · P2

*Keywords.* Square 1:1, white on black: TA converts brightness to alpha. For: Hidden Field traps (Tripwire), hide-from-intel effects, dashed TRAP chip.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: an almond eye shape with its lid half closed and one thick diagonal slash across it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 12.10 `ico_trig_on_deploy.png` · P2

*Keywords.* Square 1:1, white on black: TA converts brightness to alpha. For: 'On deploy' effect line and banner effect slot.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a solid downward arrow landing on a flat bar, with two short impact lines on each side of the bar. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

### Batch 13 · P2 · Icons (10)

Upload line: `kc-ui-art2 batch 13: ico_trig_on_down, ico_kw_aura, ico_type_killstreak, ico_type_operator, ico_elite_star, ico_trap, ico_plan_mark, ico_class_ar, ico_class_smg, ico_class_shotgun`

#### 13.1 `ico_trig_on_down.png` · P2 · **New chat**

*Keywords.* Square 1:1, white on black: TA converts brightness to alpha. For: 'On down' effect line and banner effect slot.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a playing-card rectangle tipping over to the right with a small motion arc beside it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 13.2 `ico_kw_aura.png` · P2

*Keywords.* Square 1:1, white on black: TA converts brightness to alpha. For: Field aura marker on banners in a Field's column, objective tile chip.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a small solid square with four short thick bars radiating from its four sides, like a signal spreading outward. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, circles, rings, a reticle.

#### 13.3 `ico_type_killstreak.png` · P2 · **New chat**

*Card types and card marks.* Square 1:1, white on black: TA converts brightness to alpha. For: Codex KILLSTREAKS filter, killstreak inspector, run rewards.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a chevron-shaped aircraft silhouette seen from above with two short contrails behind it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real aircraft shape, roundels, markings.

#### 13.4 `ico_type_operator.png` · P2

*Card types and card marks.* Square 1:1, white on black: TA converts brightness to alpha. For: Operator plate, Operator flyout header, OPERATOR badge (with the camo swatch).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a single military dog tag with rounded corners, a hole near the top and a short ball chain looping from it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, engraved letters or numbers on the tag.

#### 13.5 `ico_elite_star.png` · P2

*Card types and card marks.* Square 1:1, white on black: TA converts brightness to alpha. For: Elite chassis mark on banners, hand cards and Codex tiles (Ace, Commander).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a bold five-pointed star with slightly rounded points. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a circle or badge around the star, wreaths.

#### 13.6 `ico_trap.png` · P2

*Card types and card marks.* Square 1:1, white on black: TA converts brightness to alpha. For: Hidden Field (trap) chip on the objective tile, dashed.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a tripwire: a thin taut line between two short stakes with a small solid box charge clipped to the middle. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 13.7 `ico_plan_mark.png` · P2

*Card types and card marks.* Square 1:1, white on black: TA converts brightness to alpha. For: PLAN / INCOMING marker, rival planned-per-column intel.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a small face-down card rectangle with a solid dot in its centre and a short down arrow above it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 13.8 `ico_class_ar.png` · P2 · **New chat**

*Weapon classes.* Square 1:1, white on black: TA converts brightness to alpha. For: Class pip on banners (outer-left), Codex AR filter, range bonus tooltip.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: side-profile silhouette of a generic compact assault rifle pointing right: straight magazine, short rail on top, folding stock. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real gun model or brand, engravings, markings, a scope brand.

#### 13.9 `ico_class_smg.png` · P2

*Weapon classes.* Square 1:1, white on black: TA converts brightness to alpha. For: Class pip, Codex SMG filter.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: side-profile silhouette of a short boxy submachine gun pointing right, long straight magazine, stubby barrel, small stock. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real gun model or brand, engravings, markings, a scope brand.

#### 13.10 `ico_class_shotgun.png` · P2

*Weapon classes.* Square 1:1, white on black: TA converts brightness to alpha. For: Class pip, Codex SHOTGUN filter.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: side-profile silhouette of a pump shotgun pointing right, long tube under the barrel, a ridged pump grip, solid stock. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real gun model or brand, engravings, markings, a scope brand.

### Batch 14 · P2 · Icons (9)

Upload line: `kc-ui-art2 batch 14: ico_class_sniper, ico_class_lmg, ico_ctl_open, ico_field_slot, ico_ph_deploy, ico_ph_reveal, ico_ph_firefight, ico_ph_score, ico_mode_zone_control`

#### 14.1 `ico_class_sniper.png` · P2 · **New chat**

*Weapon classes.* Square 1:1, white on black: TA converts brightness to alpha. For: Class pip, Codex SNIPER filter.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: side-profile silhouette of a long bolt-action rifle pointing right with a long scope on top and a folded bipod under the barrel. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real gun model or brand, engravings, markings, a scope brand.

#### 14.2 `ico_class_lmg.png` · P2

*Weapon classes.* Square 1:1, white on black: TA converts brightness to alpha. For: Class pip, Codex LMG filter.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: side-profile silhouette of a heavy belt-fed machine gun pointing right, a box under the middle, a carry handle on top, bipod folded forward. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real gun model or brand, engravings, markings, a scope brand.

#### 14.3 `ico_ctl_open.png` · P2 · **New chat**

*Objective, control and Field.* Square 1:1, white on black: TA converts brightness to alpha. For: Objective tile control mark (OPEN: nobody there).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a thin plain circle outline, empty, with four tiny ticks pointing inward. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 14.4 `ico_field_slot.png` · P2

*Objective, control and Field.* Square 1:1, white on black: TA converts brightness to alpha. For: Empty Field slot on the objective tile (your half), placement hint.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a dashed rounded rectangle with a small plus sign in the centre. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 14.5 `ico_ph_deploy.png` · P2 · **New chat**

*Phases, firefight and run modes.* Square 1:1, white on black: TA converts brightness to alpha. For: Phase header (DEPLOY), tutorial coach, score sheet.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a playing-card rectangle sliding down into a slot, a short down arrow above it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 14.6 `ico_ph_reveal.png` · P2

*Phases, firefight and run modes.* Square 1:1, white on black: TA converts brightness to alpha. For: Phase header (REVEAL).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a playing-card rectangle turning over, half of it shown as a thin edge, with two short spark lines. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 14.7 `ico_ph_firefight.png` · P2

*Phases, firefight and run modes.* Square 1:1, white on black: TA converts brightness to alpha. For: Phase header (FIREFIGHT), order strip, tray step header.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: two short bullets pointing at each other from left and right with a small burst between them. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 14.8 `ico_ph_score.png` · P2

*Phases, firefight and run modes.* Square 1:1, white on black: TA converts brightness to alpha. For: Phase header (SCORE & STREAK).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a pennant on a pole next to a short rising stepped line. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 14.9 `ico_mode_zone_control.png` · P2

*Phases, firefight and run modes.* Square 1:1, white on black: TA converts brightness to alpha. For: Run map mode chip (Zone Control), match intro.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: three small circles in a row joined by a line, the middle one solid. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

### Batch 15 · P2 · Icons (9)

Upload line: `kc-ui-art2 batch 15: ico_mode_firefight, ico_mode_detonator, ico_mode_rival, ico_ui_settings, ico_ui_skip, ico_ui_codex, ico_ui_mirror, ico_ui_sound_on, ico_ui_sound_off`

#### 15.1 `ico_mode_firefight.png` · P2 · **New chat**

*Phases, firefight and run modes.* Square 1:1, white on black: TA converts brightness to alpha. For: Run map mode chip (Firefight).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: two crossed straight tracer lines with a small dot where they cross. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, crossed rifles, crossed swords, a badge.

#### 15.2 `ico_mode_detonator.png` · P2

*Phases, firefight and run modes.* Square 1:1, white on black: TA converts brightness to alpha. For: Run map mode chip (Detonator).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a small explosive charge block with a short antenna and a curled wire. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, numbers on a timer, text.

#### 15.3 `ico_mode_rival.png` · P2

*Phases, firefight and run modes.* Square 1:1, white on black: TA converts brightness to alpha. For: Run map RIVAL (boss) match, rival squad header.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a helmeted head silhouette in profile facing left with a small notched diamond beside it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 15.4 `ico_ui_settings.png` · P2 · **New chat**

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: Settings row in the pause menu, title.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a simple cog wheel with six rounded teeth and a round hole in the middle. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 15.5 `ico_ui_skip.png` · P2

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: Skip the round playback, skip reward.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a solid triangle pointing right followed by a thick vertical bar. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 15.6 `ico_ui_codex.png` · P2

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: CODEX buttons on the title and pause menu, Codex header.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: an open binder with three card rectangles fanned out of it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 15.7 `ico_ui_mirror.png` · P2

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: MIRROR LAYOUT setting.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: two half-rectangles facing each other across a dashed vertical line, with a small two-way arrow on top. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 15.8 `ico_ui_sound_on.png` · P2

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: Sound setting ON.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a speaker cone shape with two curved sound waves on its right. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 15.9 `ico_ui_sound_off.png` · P2

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: Sound setting OFF.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a speaker cone shape with a small X on its right. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

### Batch 16 · P2 · Icons, Backgrounds (9)

Upload line: `kc-ui-art2 batch 16: ico_ui_info, ico_ui_filter, ico_ui_continue, ico_ui_retire, ico_ui_promote, ico_ui_reward, bg_after_action, bg_codex, bg_loadout`

#### 16.1 `ico_ui_info.png` · P2 · **New chat**

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: Long-press hint, rules buttons, tooltips header.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a solid circle with a cut-out tall bar and a cut-out dot above it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 16.2 `ico_ui_filter.png` · P2

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: Codex filter bar, CLEAR FILTERS.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a funnel shape made of three horizontal bars getting shorter downward. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 16.3 `ico_ui_continue.png` · P2

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: CONTINUE, BEGIN RUN, DEPLOY on the run map, NEXT.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a thick chevron pointing right with a short horizontal tail. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 16.4 `ico_ui_retire.png` · P2

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: RETIRE tile on Supply Drop, Retire picker, Honor Roll.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a playing-card rectangle sliding out to the right with a small curved arrow, a faint outline left behind. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 16.5 `ico_ui_promote.png` · P2

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: PROMOTION reward, level-up band strip.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a playing-card rectangle with one thick upward chevron above it. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 16.6 `ico_ui_reward.png` · P2

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: SUPPLY DROP header, reward tiles, after-action REWARD.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a supply crate hanging from a small parachute canopy by three lines. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 16.7 `bg_after_action.png` · P2 · **New chat**

*Screen backgrounds.* Landscape 3:2, opaque, no transparency. For: After-Action report (VICTORY / DEFEAT, stats, Honor Roll), run end.

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. A quiet briefing room at night: a long table edge in the foreground with a closed folder and a few cards face down, a dark wall with a faint pin board shape, a single warm lamp on the far right; most of the frame dark and plain Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom get cropped.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

#### 16.8 `bg_codex.png` · P2

*Screen backgrounds.* Landscape 3:2, opaque, no transparency. For: Codex (filters + tile grid).

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. The inside of a dark armoury locker wall: rows of empty matte card slots and pegboard holes fading into darkness, a thin strip of cool light from the top, extremely calm and even so a grid of tiles can sit on top Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom get cropped.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

#### 16.9 `bg_loadout.png` · P2

*Screen backgrounds.* Landscape 3:2, opaque, no transparency. For: Starter deck / Loadout screen (STARTER KIT, picks, BEGIN RUN).

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. A gear bench under a hanging work lamp: a dark padded mat with a plain rifle case closed on the left, a neat stack of cards and a helmet on the right edge, the centre of the mat empty and dark Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom get cropped.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

### Batch 17 · P2 · Backgrounds, Glows, outlines and overlays, Card frame parts, Buttons and controls (9)

Upload line: `kc-ui-art2 batch 17: bg_loading, fx_glow_red, fx_link_tick_ghost, fx_hit_flash, fx_tracer, frm_dogtag_plate, card_back_banner, btn_danger, btn_chip`

#### 17.1 `bg_loading.png` · P2 · **New chat**

*Screen backgrounds.* Landscape 3:2, opaque, no transparency. For: Loading screen / web shell splash, boot (wordmark and bar drawn by code).

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. A single gantry crane silhouette at night far away across dark water, one amber warning light on its top, heavy fog, almost monochrome, huge empty dark sky Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom get cropped.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

#### 17.2 `fx_glow_red.png` · P2 · **New chat**

*Glows, outlines, links and previews (additive overlays).* Square 1:1, glow on black: additive blend in game, no alpha needed. For: Overrun risk pulse, can't-pay flash, set OFF.

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A soft rounded-square halo of red #E5383B light, brightest at the edge of an empty dark square centre and fading smoothly outward, nothing solid. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Square 1:1.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

#### 17.3 `fx_link_tick_ghost.png` · P2

*Glows, outlines, links and previews (additive overlays).* Square 1:1, glow on black: additive blend in game, no alpha needed. For: Dashed amber ghost ticks for links a placement would make.

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A short vertical dashed bar of three dashes of soft warm amber light, rounded ends, gentle glow. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Square 1:1.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

#### 17.4 `fx_hit_flash.png` · P2

*Glows, outlines, links and previews (additive overlays).* Landscape 3:2, glow on black: additive blend in game, no alpha needed. For: Hit flash on a banner when damage lands.

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A short horizontal burst of white-hot light: a bright core with streaks to the left and right fading out, soft. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Landscape 3:2.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

#### 17.5 `fx_tracer.png` · P2

*Glows, outlines, links and previews (additive overlays).* Landscape 3:2, glow on black: additive blend in game, no alpha needed. For: Tracer line from shooter to target (stretched along the path), Pick / Flank curve, Pierce through.

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A single long thin horizontal streak of warm white light, brightest at the right end and fading to nothing on the left, soft glow. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Landscape 3:2.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

#### 17.6 `frm_dogtag_plate.png` · P2 · **New chat**

*Elite and Operator frames.* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). For: Callsign / dog-tag plate on the Operator banner (in place of the effect glyph).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A tiny horizontal dog tag with rounded ends and a hole at the left end, brushed brass, plain face. One element only, centred, filling about 80% of the canvas. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 17.7 `card_back_banner.png` · P2 · **New chat**

*Card backs.* Landscape 3:2, opaque, no transparency. For: Face-down KillingCard back (4:1): deck pile, deal animation, rival hand, INCOMING alternative.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A very wide card back design: dark gunmetal laminated texture, a centred abstract mark of three short amber chevrons pointing right inside a thin long hexagon outline, faint topographic contour lines, symmetrical, worn edges. Fill the whole canvas edge to edge, flat front-on view. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, a cast shadow, a perspective tilt, letters, a logo, a skull, wings, stars, eagles, any badge or unit-crest look.

#### 17.8 `btn_danger.png` · P2 · **New chat**

*Buttons.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Danger / leave actions: BACK TO TITLE, abandon run, NEW RUN confirm.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A wide button plate: deep signal red #B8282B face with a darker #7A1A1C bottom edge 1/8 of its height, a thin dark outline, 45-degree chamfered corners top-left and bottom-right only, faint brushed grain, plain empty face. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 17.9 `btn_chip.png` · P2

*Buttons.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Small pill buttons: Codex filters (ALL / UNITS / AR...), tabs on narrow screens, toggles in the deck view.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small wide pill-shaped plate with flat left and right ends cut at 45 degrees, dark gunmetal #232A31 face, a thin steel #4A535B outline, plain. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

### Batch 18 · P2 · Buttons and controls, Panels, trays, rings and strips (9)

Upload line: `kc-ui-art2 batch 18: btn_chip_on, tgl_track, tgl_knob, pnl_flyout_pointer, pnl_tooltip, pnl_header, pnl_hand_tab, pnl_counter, pnl_order_strip`

#### 18.1 `btn_chip_on.png` · P2 · **New chat**

*Buttons.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Selected filter chip / active tab.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. The same small pill plate, now selected: face filled with fog white #D8DEE3 at low brightness #A9B3BB, a thin amber #FFB020 underline along the bottom edge, same shape. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 18.2 `tgl_track.png` · P2

*Buttons.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Settings toggles: MIRROR LAYOUT, SPEED x2, FAST ANIMATIONS, PREVIEW.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A horizontal toggle switch track: a long rounded slot recessed into dark metal, inner colour #12161A, thin steel #3A444D rim. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 18.3 `tgl_knob.png` · P2

*Buttons.* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). For: Toggle knob, slider knob.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A single round knob: brushed fog-white metal disk with a soft edge highlight and three short grip lines in the centre. One element only, centred, filling about 80% of the canvas. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 18.4 `pnl_flyout_pointer.png` · P2 · **New chat**

*Panels, trays and overlays.* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). For: The little pointer that joins a flyout to its badge.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small solid triangular pointer, dark slate #161B20 with a steel #4A535B outline on its two outer sides only, pointing left. One element only, centred, filling about 80% of the canvas. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 18.5 `pnl_tooltip.png` · P2

*Panels, trays and overlays.* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). For: Tooltips (desktop hover), long-press rule bubbles, Supply Drop twin preview.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small rectangular tooltip panel: near-black #0F1316 face at 95% opacity, a 1-pixel fog-white #D8DEE3 outline at low brightness, small 45-degree chamfers on all four corners. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 18.6 `pnl_header.png` · P2

*Panels, trays and overlays.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Screen title bars: SUPPLY DROP, CODEX, RUN SUMMARY, PAUSED, STARTER KIT.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A long horizontal title bar plate: dark gunmetal face, a thin amber #FFB020 line along the bottom edge, both ends cut at 45 degrees, plain. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 18.7 `pnl_hand_tab.png` · P2

*Panels, trays and overlays.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: HAND · n PEEK tab (362x64) in the closed tray.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A wide tab plate that looks like the top edge of a drawer: gunmetal face, a thin steel outline, chamfered top corners, a short row of three grip lines centred on the top edge. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 18.8 `pnl_counter.png` · P2

*Panels, trays and overlays.* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). For: Small number bubble: hand count, deck count on badges, '+n more', unread log.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small rounded-rectangle counter plate, near-black #0F1316 face, a thin fog-white outline, slightly taller than a circle. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 18.9 `pnl_order_strip.png` · P2

*Panels, trays and overlays.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Firefight order strip A -> B -> C over the board.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A slim horizontal strip plate with both ends cut at 45 degrees, near-black #0F1316 face at 85% opacity, a thin steel outline. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

### Batch 19 · P2 · Panels, trays, rings and strips, Objective and Field tile backers (9)

Upload line: `kc-ui-art2 batch 19: order_node, order_arrow, pnl_rail_chip, pnl_callout, pnl_coach, pnl_result, runmap_node, tile_field_chip_trap, tile_slot_empty`

#### 19.1 `order_node.png` · P2 · **New chat**

*Panels, trays and overlays.* Square 1:1, white on black: TA converts brightness to alpha. For: One column node on the order strip (letter drawn by code).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: a single hexagonal node plate seen front-on: solid pure white hexagon with a thick rim and a slightly recessed flat centre. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black.

#### 19.2 `order_arrow.png` · P2

*Panels, trays and overlays.* Square 1:1, white on black: TA converts brightness to alpha. For: Connector between order nodes.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: a short thick right-pointing arrow made of a straight bar and a solid triangular head, solid white. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black.

#### 19.3 `pnl_rail_chip.png` · P2

*Panels, trays and overlays.* Square 1:1, transparent PNG (magenta #FF00FF key if it fails). For: Trait rail chips (62x49 phone) and SETS flyout rows.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A small upright chip plate, dark slate face, a thin steel outline, a narrow slot along the left edge for a colour bar, chamfered top-right corner. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Square 1:1.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 19.4 `pnl_callout.png` · P2

*Panels, trays and overlays.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Set callouts ('VANGUARD 2: ...'), column banner 'COLUMN A', FIRST SHOT tag, DEPLOY / PLAY HERE chips.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A slim angled tag plate like a cut ribbon: a parallelogram with both ends slanted, near-black face, a thin fog-white outline. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 19.5 `pnl_coach.png` · P2

*Panels, trays and overlays.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Tutorial coach bubbles over the objective row.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A speech-bubble style info panel with a squared body and a small triangular tail at the bottom left, near-black face, a thin amber outline, chamfered corners. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 19.6 `pnl_result.png` · P2

*Panels, trays and overlays.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Match end and run end headline plate behind VICTORY / DEFEAT / DRAW.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A wide ceremonial plate: a long horizontal bar with angled ends and two short parallel wing bars above and below it at each end, brushed steel face, plain centre. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in, wings with feathers, eagles, stars, laurels, a crest.

#### 19.7 `runmap_node.png` · P2

*Panels, trays and overlays.* Square 1:1, white on black: TA converts brightness to alpha. For: Run map match nodes (NEXT / UPCOMING / done).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: a single round map node: a thick ring around a recessed disc, pure white, perfectly round. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black.

#### 19.8 `tile_field_chip_trap.png` · P2 · **New chat**

*Objective and Field tile backers.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Your hidden trap chip (dashed, only you see it).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. The same small clipped-corner chip shape drawn only as a dashed fog-white outline, the face transparent. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 19.9 `tile_slot_empty.png` · P2

*Objective and Field tile backers.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Empty row slot in a column (your landing slots, rival back rows).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A very wide low rectangle drawn as a faint thin steel outline with small corner brackets at each corner, the face nearly transparent dark #12161A at 30%. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

### Batch 20 · P3 · Icons (9)

Upload line: `kc-ui-art2 batch 20: ico_range_close, ico_range_mid, ico_range_long, ico_round, ico_ks_gunship, ico_att_optic, ico_att_grip, ico_att_mag, ico_att_lining`

#### 20.1 `ico_range_close.png` · P3 · **New chat**

*Stats and resources.* Square 1:1, white on black: TA converts brightness to alpha. For: Range word chip on the objective tile, class tooltips.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: one thick chevron pointing right next to a short vertical post. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 20.2 `ico_range_mid.png` · P3

*Stats and resources.* Square 1:1, white on black: TA converts brightness to alpha. For: Range chip on the objective tile.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: two thick chevrons pointing right next to a short vertical post. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 20.3 `ico_range_long.png` · P3

*Stats and resources.* Square 1:1, white on black: TA converts brightness to alpha. For: Range chip on the objective tile.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: three thick chevrons pointing right next to a short vertical post. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 20.4 `ico_round.png` · P3

*Stats and resources.* Square 1:1, white on black: TA converts brightness to alpha. For: Round counter in the SCORE badge flyout and the pause header.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a stopwatch: a circle with a small button on top and a single hand pointing to one o'clock. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 20.5 `ico_ks_gunship.png` · P3 · **New chat**

*Killstreaks and Operator equipment.* Square 1:1, white on black: TA converts brightness to alpha. For: Gunship card (Codex, rewards), reserved killstreak tile.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: side-profile silhouette of a fictional heavy four-engine propeller plane flying right with a side gun barrel under the wing. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black, a real drone, helicopter or aircraft model, roundels, markings, numbers.

#### 20.6 `ico_att_optic.png` · P3

*Killstreaks and Operator equipment.* Square 1:1, white on black: TA converts brightness to alpha. For: Loadout attachment (Holo Sight), Weapon Level reward.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a small open holographic gun sight seen from the side: a rectangular window frame on a short base, a dot inside the window. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 20.7 `ico_att_grip.png` · P3

*Killstreaks and Operator equipment.* Square 1:1, white on black: TA converts brightness to alpha. For: Loadout attachment (Foregrip), Weapon Level reward.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a vertical gun foregrip seen from the side: a ridged handle hanging from a short rail section. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 20.8 `ico_att_mag.png` · P3

*Killstreaks and Operator equipment.* Square 1:1, white on black: TA converts brightness to alpha. For: Loadout attachment (Extended Mag), Weapon Level reward.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a long curved rifle magazine seen from the side, slightly longer than normal, with a small base plate. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 20.9 `ico_att_lining.png` · P3

*Killstreaks and Operator equipment.* Square 1:1, white on black: TA converts brightness to alpha. For: Loadout attachment (Ceramic Lining), Weapon Level reward.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a hexagonal ceramic tile pattern of seven small hexagons forming a plate. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

### Batch 21 · P3 · Icons, Backgrounds, Glows, outlines and overlays, Card frame parts (9)

Upload line: `kc-ui-art2 batch 21: ico_perk_slot, ico_ui_rotate, ico_ui_survey, ico_ui_tutorial, bg_menu, fx_crack, fx_sheen, card_back_hand, frm_socket_empty`

#### 21.1 `ico_perk_slot.png` · P3 · **New chat**

*Killstreaks and Operator equipment.* Square 1:1, white on black: TA converts brightness to alpha. For: Loadout perk slot, Perk Offer reward header (the perks keep their painted patches).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a round stitched patch outline with a small four-pointed spark in the middle. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 21.2 `ico_ui_rotate.png` · P3 · **New chat**

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: Rotate-your-phone notice (web shell), Operator Rotate action.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a phone rectangle with a curved arrow going around one corner. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 21.3 `ico_ui_survey.png` · P3

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: PLAYTEST SURVEY button at run end.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a clipboard with three short lines and a tick on the top line. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 21.4 `ico_ui_tutorial.png` · P3

*Menu and system.* Square 1:1, white on black: TA converts brightness to alpha. For: TUTORIAL row on the title.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw exactly one icon: a whistle seen from the side with a short cord loop. Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black.

#### 21.5 `bg_menu.png` · P3 · **New chat**

*Screen backgrounds.* Landscape 3:2, opaque, no transparency. For: Pause menu backdrop behind pnl_modal, settings, consent and survey screens.

```
Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. No visible faces. No gore. An extreme close-up of a dark matte equipment case lid with a subtle hexagonal foam texture and a faint amber light leak from the top edge; almost abstract, very dark, even, no objects Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom get cropped.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre.

#### 21.6 `fx_crack.png` · P3 · **New chat**

*Glows, outlines, links and previews (additive overlays).* Square 1:1, white on black: TA converts brightness to alpha. For: Red crack for 2 s when a set switches off (trait rail chip), banner break.

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: a thin jagged crack line running diagonally with two short branches, pure white. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black.

#### 21.7 `fx_sheen.png` · P3

*Glows, outlines, links and previews (additive overlays).* Square 1:1, glow on black: additive blend in game, no alpha needed. For: Frame sheen sweep on animated finishes and hover.

```
Original light effect for the interface of a modern military-tactical card game played on phones. Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols. A single soft diagonal band of white light, wide and faint, fading at both sides. Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no object, no surface and no frame, just the glow. Square 1:1.
```

**Avoid:** text, an object or surface, colours other than the one asked, a background that is not pure black.

#### 21.8 `card_back_hand.png` · P3 · **New chat**

*Card backs.* Portrait 2:3, opaque, no transparency. For: Face-down hand-size back (deck view, mulligan replacements).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. The same card back design as before on an upright card: dark gunmetal laminated texture, three short amber chevrons pointing up inside a thin tall hexagon outline, faint contour lines, symmetrical. Fill the whole canvas edge to edge, flat front-on view. Portrait 2:3.
```

**Avoid:** text, letters, numbers, logos, a cast shadow, a perspective tilt.

#### 21.9 `frm_socket_empty.png` · P3 · **New chat**

*Standard Issue frame and plates.* Square 1:1, white on black: TA converts brightness to alpha. For: Empty trait / weapon slot, bottom left (Standard Issue cards; NO TRAIT arts in the Codex).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: a small square socket outline with 45-degree chamfered corners drawn as a dashed rim of eight thick dashes, the inside completely empty. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black, a solid rim, anything inside the square.

### Batch 22 · P3 · Buttons and controls, Panels, trays, rings and strips, Camo bands (8)

Upload line: `kc-ui-art2 batch 22: btn_tab, sld_track, runmap_path, band_base, band_gilded, band_forged, band_priceless, band_interstellar`

#### 22.1 `btn_tab.png` · P3 · **New chat**

*Buttons.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Tabs: SETS flyout (RIVAL / YOU), score sheet, Codex kind tabs on desktop.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A folder-tab shape: a flat-topped trapezoid with chamfered top corners and an open bottom edge, dark gunmetal #232A31 face, thin steel outline on the top and sides only. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 22.2 `sld_track.png` · P3

*Buttons.* Landscape 3:2, transparent PNG (magenta #FF00FF key if it fails). For: Slider track (volume, Deploy timer setting) and progress bars (run tickets).

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A thin long horizontal recessed groove in dark metal, inner #12161A, steel rim, rounded ends. One element only, centred, filling about 80% of the canvas. Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size. Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF background with no shadow, no gradient and no magenta inside the asset. Landscape 3:2.
```

**Avoid:** text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in.

#### 22.3 `runmap_path.png` · P3 · **New chat**

*Panels, trays and overlays.* Square 1:1, white on black: TA converts brightness to alpha. For: Path between run map nodes (tiled).

```
Original pictogram for the interface of a modern military-tactical card game played on phones. Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. Draw one UI element: a short horizontal dashed line of four thick dashes, pure white, evenly spaced, seamless when repeated. Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. Centred, filling about 70% of the canvas, with even empty margin on all sides. Perfectly flat pure black #000000 background. Square 1:1.
```

**Avoid:** text, letters, numbers, colour, grey shading, a background that is not pure black.

#### 22.4 `band_base.png` · P3 · **New chat**

*Level camo bands and Operator mastery ladder.* Square 1:1, opaque, no transparency. For: Operator base camo tier (OPERATOR badge swatch, Operator frame band); optional Recruit swatch in the deck view.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A seamless flat woodland camouflage pattern: rounded blobs of olive #4B5A3A, dark olive #2F3A25 and pale moss #7A8A5A, no other colours, evenly spread over the whole square with no centre focus, flat front-on. Square 1:1.
```

**Avoid:** text, logos, a centre focus, a border or frame, hard seams, colours other than the ones named.

#### 22.5 `band_gilded.png` · P3

*Level camo bands and Operator mastery ladder.* Square 1:1, opaque, no transparency. For: Trained copies (Gilded band under the art and on the outer edge), Operator gold tier.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A seamless pattern of polished gold leaf: the same rounded camouflage blob shapes rendered in bright gold #C9A227, deep gold #7A5E12 and pale gold highlights #F3D36B, a soft metallic sheen, evenly spread over the whole square with no centre focus, flat front-on. Square 1:1.
```

**Avoid:** text, logos, a centre focus, a border or frame, hard seams, colours other than the ones named.

#### 22.6 `band_forged.png` · P3

*Level camo bands and Operator mastery ladder.* Square 1:1, opaque, no transparency. For: Veteran copies (Forged band), Operator forged tier.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A seamless pattern of polished white steel: the same rounded camouflage blob shapes in bright silver #D9DEE3, mid grey steel #7E878F and white highlights, crisp machined metal sheen, evenly spread over the whole square with no centre focus, flat front-on. Square 1:1.
```

**Avoid:** text, logos, a centre focus, a border or frame, hard seams, colours other than the ones named.

#### 22.7 `band_priceless.png` · P3

*Level camo bands and Operator mastery ladder.* Square 1:1, opaque, no transparency. For: Elite copies (Priceless band), Operator priceless tier.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A seamless pattern of deep blue crystal: the same rounded camouflage blob shapes in sapphire blue #3E8EDE, navy #1B3F78 and icy cyan facets #9FE3FF, faceted gem-like sparkle, evenly spread over the whole square with no centre focus, flat front-on. Square 1:1.
```

**Avoid:** text, logos, a centre focus, a border or frame, hard seams, colours other than the ones named.

#### 22.8 `band_interstellar.png` · P3

*Level camo bands and Operator mastery ladder.* Square 1:1, opaque, no transparency. For: Operator top mastery tier only.

```
Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems. A seamless pattern of a violet cosmic nebula: the same rounded camouflage blob shapes filled with deep violet #7B3FC4, near-black indigo #1A0F3A and hot pink star specks #FF7AD9, tiny white stars, evenly spread over the whole square with no centre focus, flat front-on. Square 1:1.
```

**Avoid:** text, logos, a centre focus, a border or frame, hard seams, colours other than the ones named.

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


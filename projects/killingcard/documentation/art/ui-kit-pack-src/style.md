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
| Band Gold Leaf | `#C9A227` / `#7A5E12` / `#F3D36B` | Trained level (kc-ui-bands: drawn in code, `mastery_bands.gd`) | `mastery_bands.gd` |
| Band Machined | `#D9DEE3` / `#7E878F` / `#FFFFFF` | Veteran level band (code) | |
| Band Prism | `#3E8EDE` / `#1B3F78` / `#9FE3FF` | Elite level band (code) | |
| Band Starfield | `#3A1C6E` / `#120A2E` / `#FFF4FF` | Operator top tier only (code) | `mastery_bands.gd` |
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

If an `alpha` image comes back with a checkerboard, reply: "The background must be real transparency. If you can't, use a perfectly flat solid magenta #FF00FF background instead, with no shadow." Magenta was chosen because no plate in the kit uses pink (the level bands are drawn in code).

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
{ICON_STYLE}
```

Icon tail: `{ICON_TAIL}`

**UI parts style** (buttons, panels, tiles, frames, bands)

```
{UI_STYLE}
```

Tails: transparent plates `{ALPHA_TAIL}` 9-slice plates add `{NINE_TAIL}` White parts: `{LUMA_TAIL}`

**Orders paper style** (v2: `frm_t1_orders`, `tex_orders_paper`; the UI parts block with paper in place of metal)

```
{PAPER_STYLE}
```

**Light effects style** (all `add` glows, outlines, flashes, tracers)

```
{FX_STYLE}
```

Tail: `{ADD_TAIL}`

**Background style** (all `bg_*` and `col_*`)

```
{BG_STYLE}
```

**Standard Issue art style** (the 5 `kc_b_si_*` starter arts; rules tail included)

```
{SI_STYLE}
```

Tail: `{SI_RULES}`

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


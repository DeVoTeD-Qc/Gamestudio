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

### 2.7 The four style blocks (already inside every prompt)

Each prompt = **style block + subject + background tail**, already joined. There are four blocks: icon (also used for the white parts: rings, pips, nodes), UI parts, light effects, and backgrounds. They are listed here so the set can be tuned in one place; if one changes, edit `ui-kit-pack-src/` and regenerate this file and the manifest: `cd documentation/art/ui-kit-pack-src && python3 -I gen.py . ../ui-kit-prompt-pack.md ../ui-kit-manifest.csv head.md style.md tail.md` (slots live in `slots.py`).

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

**Light effects style** (all `add` glows, outlines, flashes, tracers)

```
{FX_STYLE}
```

Tail: `{ADD_TAIL}`

**Background style** (all `bg_*` and `col_*`)

```
{BG_STYLE}
```

### 2.8 Card anatomy (every card face: board banner, hand banner card, Codex tile, inspector, pick tiles)

The head's rule: **the same icon for a concept everywhere, in the same corner on every card.** Stats are **number plates**: a plate in the concept's icon shape (a white image, tinted in code), with the number printed inside by the game.

```
 Board banner 4:1 (228x57 phone, 304x76 desktop, 512x128 inspector)
 /‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\
 |(COST)                                          [TRAIT] |   top-left: cost plate (hexagon = Supply)
 |                                                        |   top-right: trait icon in a socket
 |              art: middle 70% (focal zone)              |
 |                                                        |
 |[KW][KW][bolt]                     (COV) (FP) (AR)      |   bottom-left to centre: abilities
 \________________________________________________________/   bottom-right: FP + Armor side by side
   level camo band + side spine along the outer long edge

 Hand banner card (177x73 phone, 224x64 desktop, 103x78 on 16:9): the same corners
 /‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\
 |(COST)  NAME (code text)  [TRAIT] |
 |            art band              |
 |[KW][bolt]          (FP) (AR)     |
 \__________________________________/
```

| Corner | What | Part | Phone banner | Desktop banner | Hand card | Inspector / tiles |
|---|---|---|---|---|---|---|
| Top-left | Cost (Supply) | `plate_cost_s` / `_l`, sitting in the frame's hexagon notch | 22 px | 26 px | 26 px | 48 px (`_l`) |
| Top-right | Trait | `ico_trait_*` in `frm_socket` (lit at tier 2, `fx_ring_tier3` at tier 3) | 22 px | 26 px | 22 px | 40 px |
| Bottom-left to centre | Abilities: printed keyword, neighbour keyword (the arrow is drawn by code), the bolt for effect text, class pip | `ico_kw_*`, `ico_effect_bolt`, `ico_class_*` in `frm_socket`, 2 px gaps, left to right | 22 px each | 26 px | 22 px | 40 px |
| Bottom-right | Cover (only when above 0), Firepower, Armor, side by side, Armor outermost | `plate_cover_s`, `plate_fp_s`, `plate_armor_s` | 26 px | 32 px | 28 px | 52 px (`_l`) |
| Outer long edge | Level camo band, side spine | `band_*`, `frm_spine_*` | 3 px / 2 px | 4 px / 3 px | band only | 6 px |

Rules that keep the parts lined up:
- **The frames leave these corners free:** `frm_banner`, `frm_hand_card` and `frm_codex_tile` have the hexagon notch top-left and calm, plain bottom-right corners. Their 9-slice margins (manifest) are at least as large as the cost plate.
- **Art safe zones (banner pack):** keep the top-left and top-right ~15% calm, and the bottom ~45% of the left and right ~25%. A 35% dark gradient scrim under the bottom row (the existing safety net) keeps plates readable on bright licensed art.
- **One silhouette per concept:**
  - FP is the broken gun-sight ring (`ico_stat_firepower` matches `plate_fp`).
  - Armor is the armor plate (`ico_stat_armor` matches `plate_armor`).
  - Cover is the barrier block.
  - Cost and Supply are the hexagon (the cost plate, Supply pips and the Supply row). The crate icon `ico_stat_supply` (batch 1) becomes the Supply Drop and reward icon.
  - Guard is a block wall and Spotter is binoculars, so no keyword reuses the shield (Armor) or the eye (PREVIEW).
- **Side colours are tints, not shapes:** your plates are teal and the rival's are red. The colour-blind side cue moves to the spine (square notches for you, diamond notches for the rival) and to the half of the board the card is on. This replaces the old FP badges (a teal circle for you, a red notched diamond for the rival).
- **Rival banners on the board** use the same corners (not mirrored), so a number is always bottom-right. Only the neighbour-link arrows flip. This changes the "stats face the objective" rule in `card-system.md` §3.4 (question 4).

## 3. Size key

| Kind | Generate | Ship to the TA | In game |
|---|---|---|---|
| Icon | 1024x1024 square | 256x256 master, trimmed + 8% padding; exports 128/64/48/32 | 22-64 px |
| Number plate (`plate_*`) | 1024x1024 | `_s` 128x128 (22-34 px on screen), `_l` 256x256 (48-128 px); rim + flood-filled `_fill` | 22-128 px |
| Small part (socket, pip, knob) | 1024x1024 | 64-128 px (manifest) | 22-61 px |
| Plate / panel / button (9-slice) | 1536x1024 or 1024x1536 | 2x the largest on-screen size, borders 4-6 px at ship size (manifest) | drawn at 0.5x scale (see 7.4) |
| Banner frame parts (4:1) | 1536x1024; TA crops a 4:1 band | 512x128 (2x desktop, 2.25x phone) | 228x57 / 304x76 / 512x128 |
| Hand banner card frame | 1536x1024 | 448x184 | 177x73 phone, 224x64 desktop, 103x78 16:9 |
| Operator / Codex frames | 1024x1536 | 256x320 / 240x312 | 99x124 / 120x156 |
| Camo band | 1024x1024 swatch | 512x512 + a 512x32 seamless strip | 3-6 px band, Operator badge swatch |
| Full-screen background | 1536x1024 | 1536x864 (crop 80 px top and bottom); the phone shows the middle 1536x710 | 1168x540 phone, 1280x800 desktop |
| Column backdrop | 1024x1536 | crop the middle 648x1536, resize to 512x1216 | 228x537 at 34% opacity |


# DeadDraw - Art Direction for painted art (art pack 1)

Owner: Sr Game Artist | Board task: `dd-art-prompts` | Engine: Godot 4.4.1, Web, phone portrait + desktop landscape
Prompts: `chatgpt/dd-art-pack-1-prompts.md` | List: `art-pack-1-list.csv` | Vector spec this replaces in-game: `style-guides/art-direction.md`

## The one rule

At phone size the player reads the **number badge** and the **frame colour** first, then the picture. The art makes
each card feel like a thing; it never carries rules and never competes with the number. If it does, the art gets
darker, simpler or moves.

Checks for every image at **150 px wide**: (1) the type is clear from colour alone with the picture blurred;
(2) the badge at top-left reads without squinting; (3) the silhouette alone says what it is (Shambler vs Hulk,
Pistol vs Elephant Gun).

## Style

- **Bold painted comic.** Thick dark ink contour (#151214) around every shape, painted fills with visible brushwork,
  three value steps, slightly exaggerated cartoon proportions. Mood: "Saturday-night creature feature": dusky, tense,
  a bit funny (hard-hat zombies, commuter horde), never grisly.
- **One subject per card**, big and chunky, full body or whole object, centred.
- **Lighting:** one warm key light from the **upper right**, a cool dim fill from the left. The top-left stays the
  darkest corner, which is exactly where the number badge sits.
- **Gore:** cartoon level. Green-grey skin, glowing pale-yellow eyes, torn clothes and pose sell "zombie". No wounds,
  no blood pools, no severed parts. Medical symbols are a **green or white plus**, never a red cross.
- **Originality:** no real brands, logos, text, real weapon models or known characters. Guns are chunky, slightly
  toy-like game props; several are homemade (Ratchet Crossbow, Stovepipe Launcher, Alley Sweeper, Nail Driver).

## Palette per card type (matches the badge and frame colours in `scripts/ui/dd_ui.gd`)

| Type | Backdrop | Accent / rim light | Badge in game |
|---|---|---|---|
| Zombie | dusky blood-red to brown street, ruined rooftops (#3b2321 to #5c302a) | blood red #e2574c | red |
| Boss | bruise-purple night, big low moon (#2c1d35 to #4a3060) | purple #c27ce0 | red/purple |
| Gun | slate steel-blue pegboard wall (#1f2e3a to #2e4a5f) | hit yellow #f2c14e on the top edge | yellow |
| Melee | dark warm workshop pegboard (#2a2420) | hit yellow #f2c14e, copper #d9a066 | yellow |
| Heal | dark clinic green, faint plus pattern (#1d3325 to #2b4d37) | heal green #6fd08a | green |
| Cover | dark amber brick at night (#37301d to #56472a) | cover gold #e0b04a | gold |
| Machines | dim tiled workshop (#22282c) | copper #d9a066 | - |
| Survivors | dark, soft glow behind head | warm gold #f0d27a | - |

Shared: zombie skin #8ea476 / shade #62774f, eyes #f4ea9c, bone white #ece6d6. A subject may have **one** saturated
prop colour (Fire Axe red head, Nail Driver orange, Bruiser hi-vis); red stays small on non-zombie cards so red still
means "zombie". Districts: Maple Row = suburb at dusk (orange-pink sky, siding, maple leaves); Downtown = night, wet
asphalt, sodium orange vs cold blue; St. Agnes = pale tile, sickly teal fluorescent light.

## Framing (the game crops with "cover", so safe areas matter)

| Asset | Generate | In game | Safe area |
|---|---|---|---|
| Card art (zombie, boss, gun, melee, item, machine) | 1536x1024 | 768x512 | subject in the middle 60% wide, 20-80% high; top-left 30% x 35% dark and empty (number badge); bottom 18% simple (name bar); top-right calm (damage chip); phones crop to near-square, so nothing key in the outer 20% left/right |
| Room doors | 1024x1024 | 512x512 | door centred and shut; its centre is a plain mid-dark surface (padlock + price tag sits there); bottom 15% plain (room name) |
| District banners | 1536x1024 | 1536x480 band | landmarks in the 30-62% height band, centre to right; left 25% calm (boss portrait + name) |
| Survivors | 1024x1024 | 512x512 | bust inside the central 70% circle |
| Card backs | 1024x1536 | 512x768 | symmetrical, top-left plain (count badge) |
| Patches / icons | 1024x1024, transparent | 256 / 128 | one object, reads at 40 px (patches) / 24 px (icons) |
| Title | 1024x1536 + 1536x1024 | same | logo area and button area left empty |

Backgrounds: card art, rooms, banners and backs are **full-bleed** painted backdrops (cover-fit needs no empty
edges). Only Patches and icons use a **transparent** background. Rule glyphs (ANY, DOWN, UP, SAME...), HP, points and
arrows stay **vector** for crispness at 20 px.

## Pipeline

1. ChatGPT generates each batch from the prompt file and pushes PNGs to branch `art/deaddraw-pack-1`, folder
   `projects/deaddraw/documentation/art/chatgpt/images/art-pack-1/`.
2. Sr Game Artist reviews against the checks above (150 px, badge mock, no text/brands/gore), asks for redos.
3. Technical Artist downsizes to the game sizes, drops them into `assets/art/painted/`, and adds them to
   `assets/art/manifest.json` under the same keys the SVGs use today (e.g. `weapons.pistol`, `melee.axe`,
   `finales.maple_row`, `boss_phases.patient_zero_2`, `rooms.maple_row_garage`, `patches.lockpick`), so `dd_art.gd`
   picks them up with no code change. The SVGs stay as the fallback.

Out of scope for pack 1 (legacy v2/v3 art not in the current game): ammo, carrier drops, Jawbreakers, perks, the
Grin Machine, Lucky Locker and the old melee set (knife, crowbar, bat, machete, chainsaw, bottle, hammer).

## UI kit (art pack 2)

Prompts: `chatgpt/dd-art-pack-2-ui-prompts.md` (52 images, 5 batches) | List: `art-pack-2-ui-list.csv` | ChatGPT pushes to
branch `art/deaddraw-pack-2`, folder `chatgpt/images/art-pack-2/`.

- **Why:** with painted cards, the flat StyleBoxFlat buttons, rings and panels from `dd_ui.gd` / `dd_marks.gd` look like a
  different game. The kit paints them in the same style: **painted enamel on thick sheet metal**, the same #151214 ink
  contour, three value steps, light from the **upper right** (highlight top/right, shade bottom/left), wear only at the edges.
- **The rule:** the game still draws every word, number and icon (crisp at 20 px, translatable, testable). Images carry no
  text, numbers or icons; their centres are plain and even, the detail lives in the corners and edges.
- **Number badges** (`NumBadge`): one painted circle per role, the number drawn on top: hit (yellow fill, ink ring), zombie
  strength (blood #5c1b19 fill, ring per tier: bone, amber, orange, red), heal (green ring), cover (gold ring), neutral
  (bone ring), plus wide pills (zombie, hit, neutral) for 6x3 / 8-12 / 9/11. Dim and highlight stay `modulate` in code.
- **9-slice** (`StyleBoxTexture`, `texture_margin_*`): buttons 176x80 with 16 px margins; plates and tags 176x64 (16) or
  88x32 (8); panels 240x240 (40); card frame 192x192 (32), chip frame 120x120 (20); bars 124x16 (8 left/right only); pills
  328x128 (64 left/right only); kill sockets 56x84 (8, edges tiled).
- **States:** buttons have normal + pressed per colour (primary red #7a2d27, secondary dark #2b3338, Run rust #5a2a1a, go
  green #245236, help blue #1f3a4f, shop indigo #2f2f5a) and **one shared disabled** plate; hover = normal x1.12 in code.
  Door plates: afford (gold), locked (dark iron), USE (green), used. Full set plate: open, near (glow), lit. Card frame:
  normal and selected. Filter chips: on and off.
- **Tinting:** the card and chip frames are painted in neutral grey and tinted to the type accent (`KIND_ACCENT`) with
  `self_modulate`, so one image serves every card type; the tooltip/inspect body is neutral and the tinted rim goes on top.
- **Stays vector:** padlock, rule glyphs and their tick/strike, the log dots, the big wave numeral, the selected glow in code.
- **Pipeline:** Technical Artist trims each PNG to its shape, scales it to the in-game size in the CSV, saves WebP to
  `assets/art/painted/ui/`, and maps it in `dd_ui.gd` (`button()`, `box()`), `dd_marks.gd` (`NumBadge._draw`) and the
  door / Full set plates, keeping the StyleBoxFlat look as the fallback when an image is missing.
- **Imported (dd-art2-import):** all 52 passed review (no retries). `tools/art/import_ui.py` trims each PNG, saves it at
  **2x** the CSV size (badges and pills 1x) as WebP in `assets/art/painted/ui/`, and recolours the kill sockets' olive rim
  to steel (off-palette in the originals). `scripts/ui/dd_skin.gd` draws them: `Nine` (a 9-slice StyleBox drawn at half
  scale, corners shrink on small boxes; pills, bars, tags and the Full set plate stretch sideways only, their height fits
  the box), `skin_button` (family picked from the old fill colour, hover = normal x1.12), `skin_plate`, `rim` (the tinted
  card / chip rim drawn on top of the content, gold when selected, pale gold when lit). Margins used (texture px): buttons,
  door plates and chips 40 (20 in game: the bolts sit outside the 16 px the CSV asked for), panels 80, frames 80 (drawn at
  9-15 px), name bar 32/16, sockets 16, bars 16, tags / pills / Full set 64 left and right. Words on the gold filter chip
  stay bone with an ink outline (ink on that gold is only 3:1).

## Gun Mod badges (art pack 3)

- **Look:** one shield-shaped steel tag with a brass rim and four rivets for all four mods; only the symbol and its accent
  colour change (Open Breech signal green, Last Round hot amber, Echo Chamber ghostly teal, Short Barrel spark orange).
  The accent colour is what tells them apart at chip size; the mod's name always sits next to the badge.
- **Imported (dd-mods-import):** all 4 passed review (real alpha, no text, one matched set, readable at 24 and 48 px; no
  retries). `tools/art/import_painted.py` snaps the near-opaque alpha (251-253 in the originals) to 255, crops each tag to
  its alpha box and centres it with the same 4% margin, then saves `dd_mod_<id>.webp` at 256 px (inspect) and a sharpened
  `dd_mod_<id>_sm.webp` at 64 px (the game has no mipmaps, so the gun-tile chip and the safehouse card use the small copy).
  `gen_art.py` maps them in the manifest (`mods`, `mods_small`; the rules id `echo` = `dd_mod_echo_chamber`).
- **Where they show:** the MOD chip on a gun tile and on an empty slot (`dd_gun_view.gd`, about 22-24 px), the safehouse
  Gun Mod offer card (`lead_icon` in `dd_card_view.gd`, 48 px), the inspect zoom (`icon_px` 128, `dd_inspect.gd`) and
  the Glossary's "Gun Mod (MOD chip)" row. Without a painted file each place falls back to the text-only chip.
  `tests/tools/shot_mods.gd` shoots all of them.

# DeadDraw - Art Direction (v1)

Owner: Sr Game Artist | Board task: `dd-art` | Engine: Godot 4.4.1, Web export, phone portrait + landscape
Art source: `projects/deaddraw/tools/art/gen_art.py` (writes every SVG and `assets/art/manifest.json`)
Contact sheets: `scratchpad/dd-art/contact.png` (authored SVGs + card-frame mock), `scratchpad/dd-art/godot_contact.png` (as Godot rasterises them)

---

## 1. The one rule

**At phone size the player reads the big number and the type colour first, then the picture.**
The art is there to make each card feel like a thing, not to carry information. If a piece of art
ever competes with the number, the art loses: darken it, simplify it, or move it.

Checks for every card, at **150 px wide** (a 2x2 portrait street card):
1. You can tell the type from colour alone, with the picture blurred.
2. The number badge is readable over the art without squinting.
3. The silhouette alone tells you what the object is (shambler vs hulk, bat vs chainsaw).

---

## 2. Mood and style

- **Genre/mood:** "Saturday-night creature feature". Tense, dusky and a bit grim, but warm enough to
  play for 10 minutes on a bus. Dark-humour props (cricket bat, hard-hat zombie, rush-hour commuters),
  never grisly.
- **Style:** flat vector "inked cut-paper". Bold silhouettes, one ink outline weight, two tones per
  material (base + shade), a single small highlight where it helps the read. No gradients on objects;
  only the card background uses a soft radial glow.
- **Gore:** stylised and mild. Small dark-red spots only (`#8e2a24`), never open wounds, organs or
  severed parts. Zombies read as zombies through green-grey skin, glowing eyes, torn clothes and pose.
- **Originality:** every shape is authored for DeadDraw. No traced or referenced characters, logos or
  emblems from other games or films. Medical symbols use a **green/white plus**, never a red cross on
  white (the red cross is a protected emblem).

---

## 3. Palette

### 3.1 Type colours (the main read)

These match `DDUi.card_bg` / `DDUi.accent` in the current UI so wiring needs no colour changes.

| Type | Card bg | Art glow (mid) | Background motif | **Accent (frame, label, badge ring)** |
|---|---|---|---|---|
| Zombie | `#3b2321` | `#5c302a` | ruined skyline silhouettes | **`#e2574c`** blood-orange red |
| Weapon | `#1f2e3a` | `#2e4a5f` | pegboard dots | **`#5bb0e0`** steel blue |
| Medkit | `#1d3325` | `#2b4d37` | faint plus pattern | **`#6fd08a`** clinic green |
| Barricade | `#37301d` | `#56472a` | brick wall | **`#e0b04a`** hazard amber |
| Finale | `#2c1d35` | `#4a3060` | big low moon | **`#c27ce0`** bruise purple |
| Survivor | `#2a2a24` | `#4a4532` | portrait ring | `#f0d27a` warm gold |
| Perk | `#26283a` | `#3a3e5c` | badge disc | `#9aa8ff` periwinkle |

Each card's background is its type colour with a soft radial glow toward the subject and a type motif
at low contrast. The motif is a second, picture-free way to tell types apart (skyline / pegboard /
plus / brick / moon), which also helps colour-blind players.

### 3.2 Shared neutrals and materials

| Role | Hex | Use |
|---|---|---|
| Ink | `#151214` | every outline, shadows, sockets |
| Bone | `#ece6d6` | text colour, bandages, highlights, card-back trim (= `DDUi.TEXT`) |
| Bone shade | `#bdb5a0` | rivets, trim |
| Zombie skin / shade | `#8ea476` / `#62774f` | all zombies (Patient Zero paler: `#a9b996` / `#77876a`) |
| Zombie eyes | `#f4ea9c` | the one bright point on a zombie; keeps faces readable tiny |
| Steel / shade | `#b8c4c0` / `#6d7b80` | blades, heads, hardware |
| Wood / shade | `#a87443` / `#744b2a` | handles, planks, shovel |
| Stylised blood | `#8e2a24` | small spots only |
| Clothing | muted, desaturated (`#7a6a58`, `#46607c`, `#4b4f58`, `#4d6040`...) | never brighter than the type accent |

Rule: a subject may use **one** saturated prop colour (Fire Axe red head, Chainsaw orange, Bruiser's
hi-vis vest, Theo's cap) and everything else stays muted. Red-orange on a non-zombie card is kept small
so red still means "zombie".

---

## 4. Card frame (built in Godot, not in the SVG)

The SVG is the **art window only** (240 x 180, 4:3). The frame, number and text are Godot controls on
top, so numbers stay crisp, localisable and animatable.

```
+------------------------------------+  <- 3 px border, type accent, 12 px radius
| (13)                               |  <- number badge: ink disc, 3 px accent ring,
|   number safe zone                 |     bone numerals, ~30% of card width
|        [ art window, 4:3 ]         |
|                                    |
+------------------------------------+
| ZOMBIE . Hulk          Bare -13    |  <- name bar: ink bg, bone name, accent kind label,
+------------------------------------+     preview line in good/bad colour
```

- **Number safe zone:** the top-left **84 x 70 units** of every card SVG (35% x 39%) holds only
  background, so a badge placed there is always readable. Subjects sit centre-right; weapons run
  bottom-left to top-right. (Stored in `manifest.json` as `number_safe_zone`.)
- **Number badge:** ink disc (`#151214`), 3 px type-accent ring, bone numerals in the UI bold font at
  the existing `BIG_NUMBER` weight. Diameter about 30% of the card width (44 px on a 150 px card).
- **Type label:** in the name bar, not over the art (top-right labels collide with zombie heads in the
  mock). Name bar background is ink so the name and damage preview keep full contrast.
- **States:** selected = existing `SELECT` glow on the border; "won't heal" / blocked = darken the art
  window to 45% and keep the number at full brightness; Holdover = small bone corner tab.
- **Zoom/inspect view:** the same art at 2-3x with the full rules text below; the art is crisp there
  because it is imported at `svg/scale=2.0`.
- **Card back** (240 x 336, full card, 5:7): ink with a fine diagonal hatch, bone + zombie-red double
  trim, centre emblem of a zombie hand rising through crossed boards. Used for the deck pile, deals and
  flips; the deck counter number sits on top in a badge, same as the fronts.

---

## 5. Typography

- Keep the UI's current font (Godot default sans, as shipped). Numbers: bold, bone, never outlined in
  colour. Names: bold, bone, 13-16 px at phone size. Kind labels: caps, letter-spaced, type accent.
- **No text inside SVGs** (Godot's SVG importer does not render `<text>`, and baked text cannot be
  localised or resized). Every word on a card is a Godot Label.

---

## 6. Subject design language

**Zombies** - one parametric figure family so they read as a set; size and silhouette carry strength.

| Card | Values | Silhouette read |
|---|---|---|
| Shambler | 2-4 | small, thin, head lolling, one arm out; faded cardigan |
| Lurcher | 5-7 | lunging hard forward, both arms grabbing to the right; torn denim |
| Bruiser | 8-10 | broad, square, heavy fists, hard hat + hi-vis vest |
| Hulk | 11-14 | fills the window, tiny head sunk in huge shoulders, knuckles near the ground |

**Finales** (purple, with moon): The Groundskeeper (wide-brim hat, overalls, shovel), Rush Hour Horde
(three suited commuters by a traffic light, front one biggest = strongest first), Patient Zero (pale,
hospital gown, IV stand, quarantine tape).

**Weapons** - one object, large, diagonal, power reads by heft: Broken Bottle < Claw Hammer < Crowbar <
Cricket Bat < Machete < Fire Axe < Sledgehammer < Chainsaw. Pegboard background ("taken off the
garage wall").

**Medkits** - bigger kit, bigger heal: Bandage (roll + plaster), First Aid Kit (white box, green plus),
Trauma Kit (olive bag, green patch, tourniquet).

**Barricades** - salvaged cover, bigger = sturdier: Plywood (boarded, spray X), Car Door, Dumpster
(hazard stripe).

**Survivors** (200 x 200 bust portraits in a gold ring): Rosa Vance (mechanic: teal bandana, coveralls,
wrench, plaster on cheek), Dr. Imani Hale (medic: scrubs, glasses, stethoscope, plus badge), Theo Park
(courier: amber cap, windbreaker, messenger strap). Human skin uses warm tones, clearly unlike zombie
green.

**Districts** (480 x 160 map banners): Maple Row (suburban dusk, maple tree, picket fence), Downtown
(night skyline, stalled bus, traffic light), St. Agnes Hospital (hospital block with green plus,
ambulance, quarantine fence).

**Perks** (128 x 128 round badges, periwinkle ring): Thick Jacket, Axe in the Trunk, Field Kit, Knuckle
Wraps, Sandbags, Scrounger, Second Wind, Tripwire. One central object each, readable at 48-64 px.

---

## 7. Technical spec and pipeline

| Asset | Folder (`res://assets/art/`) | viewBox | Godot texture (scale 2.0) |
|---|---|---|---|
| Card art (18 cards + 3 finales) | `cards/<kind>_<name>.svg` | 240 x 180 | 480 x 360 |
| Card back | `cards/card_back.svg` | 240 x 336 | 480 x 672 |
| Survivor portrait | `survivors/<id>.svg` | 200 x 200 | 400 x 400 |
| District banner | `districts/<id>.svg` | 480 x 160 | 960 x 320 |
| Perk icon | `perks/<id>.svg` | 128 x 128 | 256 x 256 |

- **Lookup:** `assets/art/manifest.json` has `by_name` (keyed by `DDText.card_name()` output, finale
  names, survivor names and perk names), `by_kind_value` (`zombie`/`weapon`/`medkit`/`barricade` ->
  value -> file), `finales` (district id -> file), `survivors`, `districts`, `perks` (by balance.json
  ids), `card_back`, the palette and sizes.
- **Import:** Texture2D, lossless, no mipmaps, `svg/scale=2.0` (set in each `.svg.import`). Verified
  with `godot --headless --path . --import`: 36 files, no errors, ThorVG output matches the browser.
- **SVG rules (ThorVG-safe):** paths, rects, circles, ellipses, polylines, groups with transforms,
  linear/radial gradients only. No `<text>`, filters, masks, CSS or external references.
- **Outline:** ink `#151214`, 4 units on a 240-wide card (about 2.5 px on screen at 150 px); 2-3 units
  for interior detail. Round joins and caps everywhere.
- **Editing:** change `tools/art/gen_art.py`, run `python3 projects/deaddraw/tools/art/gen_art.py`,
  then reimport. Do not hand-edit the generated SVGs (they are overwritten).
- **Adding a card:** new drawing function, add it to `CARDS`/`FINALES` with its display name and
  values, keep the subject out of the number safe zone, check it at 150 px on the contact sheet.

---

## 8. Quality checklist

- [ ] Type readable from colour + motif alone at 150 px
- [ ] Number safe zone clear; badge readable over the art
- [ ] One saturated prop colour at most; red stays "zombie"
- [ ] Ink outline weight consistent; no hairlines below 2 units
- [ ] Gore limited to small stylised spots
- [ ] No text in the SVG; ThorVG-safe elements only
- [ ] Imports with no errors and matches the browser render
- [ ] Original: no traced or referenced characters, logos or emblems

---

## 9. v2 additions ("Last Stand" waves, board task `dd-v2-art`)

Same generator, same rules (ink outline, two tones, number safe zone clear, no text, ThorVG-safe).
Contact sheet: `scratchpad/dd-art/contact-v2.png` (Godot-rasterised, phone size, mock number badge).

| Set | Files | Notes |
|---|---|---|
| Guns (weapon blue) | `cards/weapon_<name>.svg`: service_pistol, revolver, compact_smg, pump_shotgun, hunting_rifle, carbine, belt_fed_mg, static_lance | Side views at a shallow -10 to -14 degree tilt (melee stays at -30), so guns and melee read apart. Heft = size: pistol < revolver < SMG < carbine < shotgun / rifle < MG. Generic, non-branded shapes. **Static Lance** is a farm-shed shock pike (wooden pole, car battery, jumper lead, copper coil, two prongs with a cyan arc): deliberately not a sci-fi ray-gun shape. |
| New melee | `cards/weapon_kitchen_knife.svg` | Other v2 melee reuse v1 art (Crowbar, Cricket Bat, Machete, Fire Axe, Sledgehammer). |
| Ammo (new type colour: stencil teal `#4fd1c5`, crate-slat motif) | `cards/ammo_box.svg` (3-4), `cards/ammo_can.svg` (5-6) | |
| Carrier drops (carrier gold `#f2d65c`, sunburst motif) | `cards/drop_full_load.svg`, `drop_payday.svg`, `drop_boards.svg` | Payday = the carrier's satchel spilling prize tickets and star tokens (points, not money). |
| Carrier | `badges/carrier.svg` (64, satchel on a gold ring) + baked variants `cards/zombie_<type>_carrier.svg` | Badge sits bottom-left of the art window (`badge_placement` in the manifest), never in the number zone. |
| Machines (workshop copper `#d9a066`, tiled wall motif) | `cards/machine_retrofit_bench.svg`, `machine_grin_machine.svg`, `machine_lucky_locker.svg`, `machine_wall_rack.svg` (empty chalk outline) + `machine_wall_rack_<gun>.svg` per wall gun | Grin Machine is an original tin candy kiosk whose face is the dispenser (dome head, bolt eyes, toothy-grin chute, crank ear), not a classic gumball globe-on-stand. No soda-machine or mystery-box shapes anywhere. |
| Jawbreakers (128 round icons) | `jawbreakers/<id>.svg` | One candy colour + one bone symbol each: Thick Skin (slate, shield), Steady Aim (blue, crosshair), Sleight of Hand (purple, cycle arrows), Payday (gold, stars), Sugar Rush (pink, heart), Light Step (mint, footprints). Read at 40-48 px. |
| Room door tiles (240 x 180) | `rooms/<district>_<room>.svg` (Entrance + 3 rooms per district) | District sky + wall material (Maple Row siding/brick at dusk, Downtown brick/concrete at night, St. Agnes pale tile in sickly teal). Door centre-right, top-left kept quiet for a cost badge. `badges/locked.svg` (padlock on crossed boards) overlays a closed door. |
| Perks | `perks/fast_hands.svg`, `perks/bandolier.svg` | |
| Wave marker | `icons/wave.svg` (128, zombie-red ring, hand rising from the ground) | Wave number is a Godot label on top. |
| Retrofit plate | `badges/retrofit.svg` (brass plate with a gear) | No letter baked in; the UI adds "R" if wanted. |

## 10. v3 additions ("Kill Stacks", board task `dd-v3-art`)

Same generator, same rules. Every v1/v2 file and manifest key is unchanged (manifest `version` 3; v3 groups
come after the v2 ones and DDArt keeps the first file per key). Contact sheet: `scratchpad/dd-art/contact-v3.png`.

| Set | Files | Notes |
|---|---|---|
| New guns (weapon blue) | `cards/weapon_ratchet_crossbow.svg`, `weapon_twin_bore.svg`, `weapon_lever_rifle.svg`, `weapon_nail_driver.svg`, `weapon_elephant_gun.svg` | Service Pistol, Hunting Rifle, Pump Shotgun reuse v2 art; Scout Carbine reuses `weapon_carbine.svg`. Crossbow is seen from above so the bow reads; Twin-Bore is an over-and-under with a two-bore muzzle plate; Lever Rifle = brass receiver + loop lever (vs the Hunting Rifle's bolt + scope); Nail Driver is an orange site nailer with an air hose (a tool, not a gun shape); Elephant Gun is the heaviest silhouette plus one oversized cartridge. |
| Patch Press (machine copper) | `cards/machine_patch_press.svg` | A rusty clamshell heat press on a bench (raised platen, heat glow, patch on the plate, dial, thread spools). A garment-shop tool: no drinks-machine shapes. Wall Racks added for the v3 rack guns: `machine_wall_rack_ratchet_crossbow.svg`, `machine_wall_rack_elephant_gun.svg`. |
| Patches (128 round, embroidered) | `patches/<id>.svg`: lookout (binoculars), thick_jacket (quilted jacket), field_medic (green/white plus + bandage), brawler (taped fist), bounty (gold star + ribbons), loose_grip (arrow bending over a bar), second_wind (heart + wind), trophy_belt (brass buckle with a cup) | Twill rim + stitch ring + cloth field: reads apart from v2 perk discs and Jawbreakers. One rim colour each so they tell apart at 32-48 px next to HP. |
| Rule glyphs (64, ink disc, weapon-blue ring) | `icons/rule_<rule>.svg` for the sim rule ids: any (star), down, up, same (equals), zigzag, close (within 1: chevrons squeezing a dot), parity (one pip / two pips), spread (blocks under a red cap = sum cap), big (six-face die + up chevron = 6+), bent (Loose Grip, violet ring) | Built for 20-28 px on the gun card. No digits: the rule text stays a Godot label. |
| Badges (64) | `badges/challenge.svg` (gold medal + check), `challenge_open.svg` (grey empty medal), `flip.svg`, `honed.svg` (Bench plates), `no_escape.svg` (chain + padlock) | |
| Deck backs (240 x 336) | `cards/back_wave.svg` (zombie red, moon, reaching hands), `cards/back_room.svg` (slate brick, door, blank price tag, key) | The pile keeps `cards/card_back.svg`. |
| Patient Zero phases | phase 1 = `cards/finale_patient_zero.svg`, `finale_patient_zero_phase2.svg` (IV pole down, gown torn, arms up), `finale_patient_zero_phase3.svg` (swollen, violet veins) | Manifest `boss_phases`: `patient_zero_<1-3>` and `patient_zero_v<8/10/12>`. |

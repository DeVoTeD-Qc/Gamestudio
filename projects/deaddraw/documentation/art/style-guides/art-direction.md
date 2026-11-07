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

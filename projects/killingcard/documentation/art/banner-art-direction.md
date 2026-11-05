# KillingCard: banner art direction v1

*Author: Sr Game Artist Agent · 2026-11-05 · Board task kc-art · Target: Godot 4.4.1 web (Compatibility renderer), phone landscape first*
*For: the studio head (generates in ChatGPT), the curator (tags every banner), the Technical Artist (imports, crops, animates), the designers (card mapping).*
*Companion file: `banner-tags-v1.csv` (the tag sheet for the 24 banners below, one row per image).*

Every KillingCard card is a **banner**: a very wide 4:1 picture. The picture decides the card's kind (**unit** or **tactic**), its tags inspire the effect, and many pictures can share one gameplay card (alternate art). This document sets how varied banners may look, how they are tagged, how to generate them so one image gives both the board banner and the hand card, how a few of them animate, and the first 24 prompts.

Status of inputs: the UX doc (`documentation/ux/`) and the designer's `documentation/design/card-system.md` did not exist yet when this was written. Sizes assume a 512x128 logical banner with stat icons in the left and right ~15%; the tag vocabulary is a **proposal** for the designer to adopt or rename (section 2.4 lists what must stay in sync). If either doc lands with different numbers, the crop maths in section 3 is the only part that changes.

---

## 1. Visual style range

### 1.1 The idea: variety on purpose, discipline in composition

The fun of a banner collection is that no two look alike: a comic splash next to an oil painting next to a neon silhouette. KillingCard keeps that. What keeps a board of mixed styles readable is not a shared look but **shared composition rules**: one subject, centred, bold silhouette, calm edges, no text. A player should read "soldier with a sniper rifle, icy" in half a second, whatever the style.

### 1.2 Seven style families

Every banner belongs to exactly one family. Each family has a fixed style block (section 5.0) pasted at the start of its prompts, so a family stays coherent across many images. Aim for a mix: no family above ~25% of a release.

| Family | Key | Look | Best for | Watch out for |
|---|---|---|---|---|
| Ink Comic | `ink` | Thick black brush lines, flat cel colour, halftone, speed lines, one flat background colour | Action units, explosive tactics | Comic sound-effect lettering (always regenerate) |
| Painterly Heroic | `paint` | Visible brushwork, dramatic rim light, atmospheric depth | Hero units, creatures, big landscapes | Muddy mid-tones at small size: ask for strong rim light |
| Neon Synth | `neon` | Night violet and black, hot pink and cyan glow, bloom, clean shapes | Night/electric/toxic, stealth units, animated banners | Glowing signs with fake letters |
| Retro Screenprint | `retro` | 3-4 flat inks, misregistration, paper grain, long shadows | Units in motion, scenic tactics | Can go too pale: keep one dark ink |
| Cinematic Photo-ish | `cine` | Film still, shallow depth of field, filmic grade | Soldiers, gear, weapon-only showcases | Faces and real gun/vehicle models: faces always covered |
| Minimal Emblem | `emblem` | One geometric symbol on a two-tone gradient field | Abstract tactics, cheap animated pulses | Drifting into a badge, crest, patch or logo: never framed |
| Woodblock Ink | `wood` | Carved outlines, flat layered colour, wave and rain patterns | Melee, weather, elemental tactics | Fake calligraphy, seals or stamps |

Families can be added later (pixel art, papercut, chrome airbrush, watercolour...) by writing one new style block and testing 3 images against the checklist in 1.6 before it goes into a pack.

### 1.3 Readability at phone size

On the board a banner is drawn at roughly 150 to 220 pt wide on a landscape phone (about 40 to 55 pt tall). That is tiny. Every banner must pass the **squint test**: shrink it to **160x40 px** (and 96x24 for the smallest stack view) and the subject must still be obvious.

- **One subject.** One figure, one creature, one weapon or one event. A squad reads only if it is a single silhouette mass.
- **Subject height.** In the 4:1 banner, the focal part (head and weapon, creature head, the emblem) fills at least 60% of the banner height.
- **Value contrast first.** Subject light on dark or dark on light. Max three value groups (background, subject, one highlight).
- **One focal accent** (muzzle flash, glowing eye, neon line). Not five.
- **Horizontal flow.** Weapons, motion, tracer lines and horizons run left-right across the strip: the format rewards it.
- **Mirror-safe.** No text means the engine may flip a banner horizontally (for example to face the objective). Avoid details that look wrong mirrored; handedness does not matter.

### 1.4 Safe zones (coordinate with UX)

Assumed board banner: 512x128 logical. Stat icons sit in the outer 15% on each side; an effect icon (lightning) may sit at the bottom centre.

```
 0%        15%                                         85%      100%
 +----------+------------------------------------------+----------+
 | ICON     |                                          |     ICON |
 | ZONE     |          FOCAL ZONE (middle 70%)         |     ZONE |
 | calm,    |   head, hands, weapon, eye, emblem,      |    calm, |
 | darker,  |   brightest highlight                    |  darker, |
 | low      |                                          |      low |
 | detail   |            [ effect icon zone ]          |   detail |
 +----------+------------------------------------------+----------+
            bottom-centre 20% wide x 30% tall: mid-value, no key detail
 Outer 3% on every side: may be hidden by the frame or rounded corners.
```

- **Icon zones (0-15% and 85-100%)**: background only, calmer and darker. Weapon barrels, capes and motion may pass through but not end there with a key detail.
- **Focal zone (15-85%)**: everything that identifies the card.
- **Effect icon zone**: no faces or eyes here.
- Safety net for the TA: an in-engine 15% side gradient (black at ~35% opacity) behind the icons, so a busy edge never kills icon legibility. Art should not rely on it.

### 1.5 Hard rules (every banner, every family)

1. **Original only.** No characters, emblems, banner designs, maps, weapons, operators or UI from any existing game, film, comic or brand. **Never name a franchise, game, studio, film, artist or "calling card" in a prompt**, not even as "not like ...". Describe looks in plain visual words, as the style blocks do.
2. **No text baked in.** No letters, numbers, fake writing, calligraphy, stamps, seals, signs with lettering, sound-effect words, serial numbers. The game draws all words and numbers.
3. **No logos, brand marks, insignia, flags, rank badges, unit patches, roundels, red cross or red crescent.** Gear and shields are plain.
4. **No real people.** Invented characters only. In the Cinematic Photo-ish family every face is covered (mask, goggles, visor, helmet). Stylised families (comic, painterly, retro, woodblock, neon) may show invented faces, but nobody may resemble a real person or a known character. *(Change from Killstreak, which hid all faces: see question 1.)*
5. **No real weapon, vehicle, aircraft or drone models.** Fictional designs; no maker marks.
6. **Blood-free violence.** Max level `v2` (firing, explosions, impacts, monsters baring teeth). Never blood, wounds, bodies, gore or dismemberment. Red paint or ink must not read as blood.
7. **No hateful, sexualised or real-conflict imagery.** No real places in ruin, no recognisable real skylines or landmarks.

### 1.6 Reject checklist (any "yes" means regenerate, two tries, then skip)

- [ ] Any letters, numbers, fake writing, a logo or a stamp anywhere?
- [ ] A flag, insignia, badge, patch, crest, roundel, red cross or red crescent?
- [ ] Someone who looks like a real person or a known game/film character? A visible face in a Photo-ish image?
- [ ] A weapon or vehicle that is clearly a real named model?
- [ ] Blood, wounds, a body, gore? Red that reads as blood?
- [ ] Does it look like a banner, emblem or screen from an existing shooter?
- [ ] Squint test at 160x40 fails (subject unclear)?
- [ ] Key detail (face, eye, weapon action, emblem) outside the focal zone, or in the top or bottom 28% of the full image (the banner crop will cut it)?
- [ ] Left or right 15% busy and bright (icons will fight it)?
- [ ] For a **unit**: no character and no weapon visible? For a **tactic**: a character is the subject? (Then it is the other kind: re-tag it, don't reject it.)

---

## 2. Tag sheet (for the curator)

Every banner gets one row in the tag sheet (`banner-tags-v1.csv` for this pack; later packs append rows or a new versioned file). Tags drive three things: the **kind** (unit or tactic), the **effect inspiration** for the designers, and **search/filters** in collection UI.

### 2.1 Kind rule: unit or tactic

1. If the subject is a **character** (person, creature, animal, robot or mech) **or a weapon** (weapon-only showcase), it is a **unit**.
2. Everything else is a **tactic**: landscape, object, event, emblem, abstract.
3. Edge cases:
   - **Partial or tiny figures** (a hand on a radio, distant silhouettes in a skyline, a crowd as scenery) do not count as a character: tactic.
   - **Emblem of an animal or weapon** (a flat geometric wolf head, a stylised rifle mark): **tactic**, because it is a symbol, not a combatant. *(See question 2.)*
   - **Vehicles**: armed vehicle or drone shown as the subject (gun mount, missiles) = unit (counts as a weapon); unarmed vehicle = tactic.
   - **Equipment** (Killstreak's Tripwire Charge, Comms Relay): no character, no hand-held weapon, so tactic, unless the designer keeps an Equipment kind.
4. Alternate art must keep the **same kind** as its card. A unit card's alt art should share its **weapon class**, or be `natural`/`melee` only if the designer allows that card to take them.

### 2.2 Fields and vocabulary (proposal)

| Field | Values | Notes |
|---|---|---|
| `file` | `kc_b_<subject>_<variant>.png` | lowercase, underscores. `kc_b_` = KillingCard banner. |
| `style` | `ink`, `paint`, `neon`, `retro`, `cine`, `emblem`, `wood` | Section 1.2. |
| `kind` | `unit`, `tactic` | From 2.1. Never contradict `subject`. |
| `subject` | `soldier`, `creature`, `animal`, `robot`, `vehicle`, `weapon_only`, `emblem`, `landscape`, `object`, `abstract` | `soldier` covers soldier/operator/fighter. `creature` = fantastical; `animal` = real species (may be armoured). `object` = prop or event (crate, door, explosion). |
| `weapon_class` | Existing: `none`, `smg`, `shotgun`, `ar`, `sniper`, `lmg`. Proposed: `sidearm`, `melee`, `launcher`, `bow`, `natural`, `exotic` | Existing values match `DataEnums.WeaponClass`. `natural` = claws, fangs, bite; `exotic` = trident, energy blade, magic. Tactics are `none`. |
| `element` | `none`, `fire`, `ice`, `electric`, `toxic`, `water`, `wind`, `earth`, `explosive`, `shadow`, `neon`, `light` | One value: the strongest. Main effect hook. |
| `mood` | `heroic`, `aggressive`, `menacing`, `stealthy`, `defiant`, `calm`, `eerie`, `chaotic`, `stoic`, `playful`, `luxurious`, `tactical`, `apocalyptic` | One value. Feeds flavour and audio. |
| `violence` | `v0` none (scene, emblem, calm figure), `v1` armed or threatening, `v2` action (firing, explosion, impact, monster attacking) | `v3` (blood, wounds, gore) does not exist: reject. Lets us filter for a younger rating later. |
| `setting` | `urban_ruins`, `urban_street`, `night_city`, `city_skyline`, `market_town`, `old_town`, `interior`, `industrial`, `desert`, `arctic`, `jungle`, `grassland`, `swamp`, `sea`, `sky`, `space`, `mythic`, `studio_void`, `abstract` | Extend as needed; keep snake_case. |
| `palette` | `red`, `orange`, `gold`, `sand`, `rust`, `green`, `olive`, `teal`, `cyan`, `blue`, `indigo`, `magenta`, `mono` | Dominant hue. Lets the board avoid five red banners in a column. |
| `verb` | `attacking`, `aiming`, `rushing`, `charging`, `guarding`, `holding`, `healing`, `breaching`, `suppressing`, `flanking`, `revealing`, `scouting`, `resupplying`, `burning`, `poisoning`, `disabling`, `emerging`, `dueling`, `showcase` | What the subject is doing: the second effect hook. |
| `count` | `solo`, `duo`, `squad`, `horde`, `none` | `none` for tactics without figures. |
| `card` | gameplay card id or name | Which card this art plays as. `(designer)` = not assigned yet. |
| `alt_group` | `alt_<card>` or empty | Banners in one group are deliberate alternates of one card. |
| `animated` | `no`, `yes`, `later` | Section 4. |
| `banner_y` | 0.0-1.0, default `0.47` | Vertical centre of the 4:1 band in the full image (section 3). |
| `portrait_x` | 0.0-1.0, default `0.50` | Horizontal centre of the 2:3 hand column. |
| `status` | `prompted`, `generated`, `rejected`, `approved`, `imported` | Pipeline state. |
| `effect_hint` | free text | The artist's suggestion; the designer decides. |

### 2.3 How tags inspire effects (suggestions; the designer owns the rules)

| Tag | Suggested effect family |
|---|---|
| `weapon_class: sniper` | Pick (hit a target, not the frontline) |
| `smg` / `verb: rushing` | First Shot, speed, enter further forward |
| `shotgun` / `verb: breaching` | Close burst, bonus vs frontline |
| `lmg` / `verb: suppressing` | Lower enemy power in the column |
| `launcher` / `element: explosive` | Splash to adjacent cards |
| `melee` / `verb: dueling` | Strike the frontline only, high damage |
| `natural` (beasts) | Fast or big body; pack bonus |
| `verb: guarding` / `holding` | Protector, slides to the front (Killstreak rule) |
| `verb: healing` / `resupplying` | Patch, draw, refresh |
| `fire` | Damage over time, or damage a whole column |
| `ice` | Freeze or slow (skip next move/attack) |
| `electric` | Chain to an adjacent column |
| `toxic` | Weaken over time |
| `water` / `shadow` | Hidden until revealed, or push back |
| `neon` / `light` | Buff, reveal |
| `verb: revealing` / `scouting` | Reveal hidden cards, peek at the hand |

### 2.4 What must stay in sync with the designer

`card-system.md` was not written yet. To align: (a) `kind` values, (b) `weapon_class` (the proposed additions `sidearm`, `melee`, `launcher`, `bow`, `natural`, `exotic` would be **appended** to `DataEnums.WeaponClass`, never reordered, per the comment in `scripts/data/data_enums.gd`; or the designer maps them to `NONE`), (c) `element` and `verb` names if they become gameplay keywords. If the designer picks other words, the curator renames columns in the CSV; prompts do not change.

---

## 3. Generation spec: one image, two crops

### 3.1 Generate wide, crop twice

ChatGPT's widest native size is **1536x1024 (3:2)**. Every banner is generated at that size and composed as a **cross**:

```
 full image 1536x1024 (3:2)
 +-------------------------------------------------------+
 |                  sky / wall / ground                  |   top ~28%: simple background
 |              +-----------------+                      |
 |==============|=================|======================|   <- 4:1 BANNER BAND 1536x384
 |   calm edge  |  HEAD + WEAPON  |      calm edge       |      centred at banner_y (default 0.47)
 |==============|=================|======================|
 |              |  body / ground  |                      |   bottom ~34%: simple background
 |              +-----------------+                      |
 +-------------------------------------------------------+
                 ^ 2:3 HAND COLUMN 683x1024, centred at portrait_x (default 0.50)
```

- **Banner band (board):** full width, 1536x384, centred at `banner_y`. Default 0.47 puts the band from 28.5% to 66% of the height, matching the prompts' "key parts between 30% and 65%".
- **Hand column (hand card, if UX picks a vertical crop):** full height, 683x1024, centred at `portrait_x`. The intersection of the two (683x384, the **core**) holds the head and the weapon's action point. The figure's body continues downward into the column, so the hand crop shows a full figure while the banner shows the "head and weapon" read.
- **Hand option B (stripe):** if UX instead shows the whole banner as a stripe on a vertical card, the band alone is enough and the column is unused.
- **Square crop** (avatars, collection grid): 1024x1024 centred at `portrait_x` comes for free.

Every prompt ends with the shared **banner rules** block that asks for this composition. ChatGPT follows percentages only roughly, so the curator sets `banner_y` and `portrait_x` per image instead of regenerating: anything from 0.35 to 0.60 for `banner_y` is fine.

### 3.2 What ships to the game (the TA's call; recommendation)

| Asset | Size | Notes |
|---|---|---|
| Master texture | **1152x768** (75% of the generation), WebP lossy ~q80, about 80-150 KB | One file per banner, `kc_b_<name>.webp` (or PNG imported as Lossy). |
| Banner region | 1152x288 (from the master) | Displayed at 512x128 logical, so 2.25x: sharp on 2x-3x phones. |
| Hand column region | 512x768 | Exactly a 2:3 512x768 hand art at 2x a 256x384 card. |

The regions are `AtlasTexture`s (or one `BannerArt` resource, `banner_art.tres`, holding the texture plus `banner_y`, `portrait_x` and the tags), so there is **one image file per banner**, and re-centring is a number change, not a re-export. Import for UI: Lossy compression, mipmaps off, linear filter. 24 banners at ~120 KB is about 3 MB: lazy-load packs not in the current deck if the < 3 s load target suffers.

### 3.3 Step by step for the head (same flow as Killstreak)

1. **One image per chat.** Open a fresh ChatGPT chat, paste the grey prompt box, send. If it asks a question: "just generate it".
2. **Landscape 3:2.** If it comes back another shape: "Same image, landscape 3:2, 1536x1024."
3. **Don't crop.** Upload the full image; the TA crops.
4. **Fix in the same chat:** "Regenerate, avoid: ..." plus the entry's Avoid line. Most common fixes: "Move the subject to the exact centre", "Keep the left and right edges empty and dark", "Remove all letters and symbols".
5. **Name the file** as the entry's file name (or list the names in upload order in the message).
6. **Upload** in batches of 5-10: Studio Floor chat, or commit to `projects/killingcard/source/project-killingcard/assets/incoming/` (the TA confirms the folder).
7. **Curator** fills `status`, checks the kind rule and adjusts `banner_y` / `portrait_x` in the CSV.

---

## 4. Animated banners

### 4.1 When

- Animate **only** while the banner is **focused** (inspector open, long-press, hover) and during the **placement animation** (about 0.6-1.2 s, one loop). On the board and in the hand at rest, every banner is a still. At most **one** animated banner plays at a time.
- About **1 in 6** banners animates: hero units, premium or event alt-arts, and images whose element is visual (fire, neon, electric, water, snow). v1 pack: 4 animated (`kc_b_marksman_neon`, `kc_b_gunner_inferno`, `kc_b_callout_ping`, `kc_b_blackout_street`); 5 more marked `later`.
- Animation is a reward and a status signal (an animated alt-art is a nicer copy of the same card), never gameplay information.
- Low-performance fallback: if the frame rate drops, show the still.

### 4.2 How: three tiers, all from one ChatGPT still

| Tier | What | Extra weight | Made by |
|---|---|---|---|
| **T1 Shader on the still** (default) | One `CanvasItem` shader on the banner: light-sweep (foil glint), glow pulse through an emissive mask, UV wobble (heat haze, water, flags) from a small noise texture, scrolling fog | 0-30 KB (a greyscale mask, shared noise) | TA, in Godot. No new art needed except the optional mask. |
| **T2 Layered parallax** (hero arts) | 2-3 layers from the still: background plate, subject cut-out, optional foreground/FX. Background drifts 6-10 px, subject breathes 2-3 px, plus `CPUParticles2D` (embers, snow, sparks, rain, spores) and T1 shaders | ~80-150 KB (cut-out PNG with alpha + plate) | Head asks ChatGPT for the layers (below), TA assembles a `BannerAnimated.tscn`. |
| **T3 Frame loop** (rare) | 8-12 frame sprite sheet of the banner (512x128 per frame), ≤ 300 KB WebP atlas, 3-4 s loop | ≤ 300 KB | Only when T1/T2 cannot express it (a character that really moves). Needs a tool to make in-between frames; not planned for v1. |

Web notes for Godot 4.4.1: Godot cannot import animated WebP or GIF as an animated texture, and it no longer plays WebM (video is Ogg Theora only, which is heavy on web). So "video" banners are a sprite atlas (T3), and T1/T2 are preferred because they cost almost nothing and stay sharp. Use `CPUParticles2D` rather than `GPUParticles2D` for the web/Compatibility target. Loops: 3-4 s, seamless; pause when off-focus.

### 4.3 Making T2 layers in ChatGPT without video tools

In the **same chat** as the approved still, send these one at a time:

1. Subject cut-out: `Same image, unchanged, but keep only the [subject] on a fully transparent background. PNG with transparency. Do not redraw or move anything.`
2. Background plate: `Same image, unchanged, but remove the [subject] and fill the space naturally with the background. Do not change anything else.`
3. Glow mask (for T1 pulses, optional): `Same image as a black and white mask: every glowing or light-emitting part (neon, fire, eyes, muzzle flash, lights) pure white, everything else pure black. No grey background.`

ChatGPT edits can drift a few pixels or recolour slightly. That is fine: parallax hides small mismatches, and the TA aligns the cut-out over the plate. If the cut-out comes back clearly redrawn, skip it and fall back to T1. Name them `<file>_fg.png`, `<file>_bg.png`, `<file>_glow.png`.

### 4.4 Motion recipes by element

| Element / look | Recipe |
|---|---|
| fire | Embers rising (particles), heat-haze UV wobble above the flames, flame glow pulse via mask |
| ice | Snow drifting sideways, cold sparkle light-sweep across the subject |
| electric | Random 1-2 frame flash through the glow mask, small arc sparks |
| neon | Neon flicker (glow mask), slow scan-line sweep, laser line shimmer |
| toxic | Fog layer scrolling slowly, spores rising |
| water | Wave UV ripple on the lower part, rain streaks |
| emblem | Ring or shape pulse drawn by the shader itself: zero extra art |
| any premium alt-art | Diagonal foil light-sweep across the whole banner every 2 s |

---

## 5. Prompt pack v1: 24 banners

**Mix:** 14 units (AR x3, sniper x2, SMG, shotgun, LMG x2, sidearm, melee, launcher, natural x2) and 10 tactics. **Alt-art pairs (3):** Rifleman (`kc_b_rifleman_dusk` + `kc_b_rifleman_comic`), Marksman (`kc_b_marksman_snow` + `kc_b_marksman_neon`), Flank Route (`kc_b_flank_route_alley` + `kc_b_flank_route_emblem`). **Families:** paint 6, cine 4, ink 4, retro 3, neon 3, emblem 2, wood 2.

Suggested cards use Killstreak's current card list (the KillingCard source still carries it); entries marked `(designer)` need a card from the designer. Priority for generation: the three alt-art pairs first (they prove the alternate-art idea), then the rest in order.

Each prompt = **style block** + **subject** + **banner rules**, already joined: paste the grey box as is. The blocks are listed here so they can be tuned in one place; if one changes, regenerate the pack (the curator or TA can do it from the tag sheet).

### 5.0 Style blocks and banner rules

**Ink Comic** (`ink`)

```
Original bold ink comic illustration: thick black brush outlines, flat cel colors, halftone dot shading, speed lines and impact bursts, a limited palette of three strong colors plus black and paper white, very high contrast, background is a single flat color with simple graphic shapes.
```

**Painterly Heroic** (`paint`)

```
Original heroic digital painting: visible confident brushwork, dramatic cinematic lighting with a strong rim light on the subject, rich atmospheric depth with haze and particles, saturated but controlled colors, epic and grounded mood.
```

**Neon Synth** (`neon`)

```
Original neon synth illustration: deep night palette of violet, indigo and black, glowing hot pink and cyan neon light on edges, soft light bloom, smooth clean shapes, sharp glowing silhouettes, retro 1980s night mood.
```

**Retro Screenprint** (`retro`)

```
Original retro screenprint poster illustration: three or four flat ink colors with slight misregistration, visible paper grain, bold simplified shapes, long dramatic shadows, warm faded palette of rust, cream, teal and ink blue, mid-century poster composition.
```

**Cinematic Photo-ish** (`cine`)

```
Original cinematic photorealistic film still: shallow depth of field, wide anamorphic lens look, filmic color grade with cool shadows and warm highlights, light haze and dust in the air, crisp detail on the subject. Every person is invented and has the face fully covered by a mask, goggles, visor or helmet.
```

**Minimal Emblem** (`emblem`)

```
Original minimal emblem artwork: one bold geometric symbol built from flat vector shapes, centered on a smooth two-tone gradient field, at most three colors, a subtle soft shadow, generous clean negative space. Not a badge, shield, crest, patch or logo: no frame or border around the symbol.
```

**Woodblock Ink** (`wood`)

```
Original woodblock print illustration: carved outlines, flat layered color areas, visible wood grain and textured paper, stylized waves, clouds, wind and rain drawn as patterns, muted palette of indigo, rust red, bone white and charcoal.
```

**Banner rules** (appended to every prompt)

```
Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

### 5.1 Units (14)

#### 1. `kc_b_rifleman_dusk.png`

- **Unit** · **Style:** Cinematic Photo-ish · **Suggested card:** Rifleman · **Alt-art group:** `alt_rifleman` · **Animated:** no
- **Tags:** subject `soldier` · weapon `ar` · element `none` · mood `heroic` · violence `v2` · setting `urban_ruins` · palette `orange` · verb `attacking`
- **Effect hint:** baseline attacker, no extra effect
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original cinematic photorealistic film still: shallow depth of field, wide anamorphic lens look, filmic color grade with cool shadows and warm highlights, light haze and dust in the air, crisp detail on the subject. Every person is invented and has the face fully covered by a mask, goggles, visor or helmet. A lone invented soldier in a matte helmet, smoke-gray balaclava and tinted goggles, plate carrier, firing a compact fictional assault rifle to the right from behind a broken concrete wall. Bright muzzle flash, spent casings in the air, dusk orange sky and drifting dust behind. Shot from the knees up, rifle held horizontally across the frame. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, a rifle that is clearly a real model.

#### 2. `kc_b_rifleman_comic.png`

- **Unit** · **Style:** Ink Comic · **Suggested card:** Rifleman · **Alt-art group:** `alt_rifleman` · **Animated:** no
- **Tags:** subject `soldier` · weapon `ar` · element `none` · mood `heroic` · violence `v2` · setting `urban_ruins` · palette `red` · verb `attacking`
- **Effect hint:** same card as kc_b_rifleman_dusk
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original bold ink comic illustration: thick black brush outlines, flat cel colors, halftone dot shading, speed lines and impact bursts, a limited palette of three strong colors plus black and paper white, very high contrast, background is a single flat color with simple graphic shapes. An invented female operator with a short undercut and a red scarf pulled over her nose and mouth, vaulting sideways over a low wall while firing a fictional assault rifle to the right, scarf trailing behind her, speed lines. Flat crimson background with jagged black brush-stroke shapes. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, red liquid that reads as blood, a real gun model.

#### 3. `kc_b_marksman_snow.png`

- **Unit** · **Style:** Painterly Heroic · **Suggested card:** Marksman · **Alt-art group:** `alt_marksman` · **Animated:** no
- **Tags:** subject `soldier` · weapon `sniper` · element `ice` · mood `stealthy` · violence `v1` · setting `arctic` · palette `blue` · verb `aiming`
- **Effect hint:** Pick (sniper); ice could add a slow/freeze variant later
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original heroic digital painting: visible confident brushwork, dramatic cinematic lighting with a strong rim light on the subject, rich atmospheric depth with haze and particles, saturated but controlled colors, epic and grounded mood. A marksman in white snow camouflage lying prone on a snowy ridge, hood up and white face wrap, a long fictional scoped rifle pointing right across the frame, breath vapor, blizzard streaks. Cold blue dawn light with one small warm glint on the scope lens. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, visible face, scope reticle numbers.

#### 4. `kc_b_marksman_neon.png`

- **Unit** · **Style:** Neon Synth · **Suggested card:** Marksman · **Alt-art group:** `alt_marksman` · **Animated:** yes (v1 animated)
- **Tags:** subject `soldier` · weapon `sniper` · element `neon` · mood `stealthy` · violence `v1` · setting `night_city` · palette `magenta` · verb `aiming`
- **Effect hint:** same card as kc_b_marksman_snow; animated: sun shimmer + laser flicker
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original neon synth illustration: deep night palette of violet, indigo and black, glowing hot pink and cyan neon light on edges, soft light bloom, smooth clean shapes, sharp glowing silhouettes, retro 1980s night mood. A sniper silhouette kneeling on a rooftop ledge, long rifle aimed to the right, a thin cyan laser sight line stretching across the whole image. Behind: a huge low setting sun cut by horizontal stripes, radio towers and power lines, a glowing grid city far below. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, palm trees, signs with lettering.

#### 5. `kc_b_point_man_bazaar.png`

- **Unit** · **Style:** Retro Screenprint · **Suggested card:** Point Man · **Animated:** no
- **Tags:** subject `soldier` · weapon `smg` · element `none` · mood `aggressive` · violence `v1` · setting `market_town` · palette `sand` · verb `rushing`
- **Effect hint:** First Shot / speed
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original retro screenprint poster illustration: three or four flat ink colors with slight misregistration, visible paper grain, bold simplified shapes, long dramatic shadows, warm faded palette of rust, cream, teal and ink blue, mid-century poster composition. A fast point man sprinting from left to right through a narrow sunlit market alley, compact fictional submachine gun held forward, cap and scarf hiding the face, hanging fabric awnings overhead, long hard shadows on the ground. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, shop signs with lettering.

#### 6. `kc_b_breacher_doorkick.png`

- **Unit** · **Style:** Ink Comic · **Suggested card:** Breacher · **Animated:** no
- **Tags:** subject `soldier` · weapon `shotgun` · element `explosive` · mood `aggressive` · violence `v2` · setting `interior` · palette `yellow` · verb `breaching`
- **Effect hint:** close-range burst; door/breach theme
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original bold ink comic illustration: thick black brush outlines, flat cel colors, halftone dot shading, speed lines and impact bursts, a limited palette of three strong colors plus black and paper white, very high contrast, background is a single flat color with simple graphic shapes. A hulking breacher in heavy armor and a full face visor kicking through a wooden door, the door bursting into splinters toward the viewer, a short pump shotgun held in one hand, a comic impact burst behind him. Flat electric yellow background. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, markings on the armor.

#### 7. `kc_b_gunner_inferno.png`

- **Unit** · **Style:** Painterly Heroic · **Suggested card:** Gunner · **Animated:** yes (v1 animated)
- **Tags:** subject `soldier` · weapon `lmg` · element `fire` · mood `menacing` · violence `v2` · setting `industrial` · palette `orange` · verb `suppressing`
- **Effect hint:** fire: burn/damage-over-time hook; animated: embers + heat haze
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original heroic digital painting: visible confident brushwork, dramatic cinematic lighting with a strong rim light on the subject, rich atmospheric depth with haze and particles, saturated but controlled colors, epic and grounded mood. A heavy gunner in scorched armor and a gas-mask helmet bracing a fictional belt-fed machine gun at the hip, firing to the right, a burning oil field and refinery towers behind him, embers and sparks swirling, orange and black dominant. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, a real machine-gun model.

#### 8. `kc_b_shieldman_sparks.png`

- **Unit** · **Style:** Retro Screenprint · **Suggested card:** Shieldman · **Animated:** no
- **Tags:** subject `soldier` · weapon `sidearm` · element `none` · mood `defiant` · violence `v1` · setting `urban_street` · palette `teal` · verb `guarding`
- **Effect hint:** Protector / guard
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original retro screenprint poster illustration: three or four flat ink colors with slight misregistration, visible paper grain, bold simplified shapes, long dramatic shadows, warm faded palette of rust, cream, teal and ink blue, mid-century poster composition. A shield bearer crouched behind a tall plain ballistic shield with a narrow viewport, a sidearm resting on the shield's edge, a shower of sparks bouncing off the shield face, rain-slick street, dark teal and cream inks. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, any marking or word on the shield.

#### 9. `kc_b_medic_goldengrass.png`

- **Unit** · **Style:** Cinematic Photo-ish · **Suggested card:** Combat Medic · **Animated:** no
- **Tags:** subject `soldier` · weapon `ar` · element `none` · mood `calm` · violence `v0` · setting `grassland` · palette `gold` · verb `healing`
- **Effect hint:** Patch / heal
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original cinematic photorealistic film still: shallow depth of field, wide anamorphic lens look, filmic color grade with cool shadows and warm highlights, light haze and dust in the air, crisp detail on the subject. Every person is invented and has the face fully covered by a mask, goggles, visor or helmet. A combat medic in a helmet and face mask kneeling in tall dry grass at golden hour, holding a medical injector and an open trauma bag, rifle slung across the back, a plain teal armband with no symbol, soft smoke drifting across the field. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, red cross, red crescent or any medical emblem, a wounded person.

#### 10. `kc_b_frost_wolf.png`

- **Unit** · **Style:** Painterly Heroic · **Suggested card:** (designer) fast flanker or new beast unit · **Animated:** no
- **Tags:** subject `animal` · weapon `natural` · element `ice` · mood `menacing` · violence `v1` · setting `arctic` · palette `blue` · verb `charging`
- **Effect hint:** ice: freeze/slow; charging: move/flank
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original heroic digital painting: visible confident brushwork, dramatic cinematic lighting with a strong rim light on the subject, rich atmospheric depth with haze and particles, saturated but controlled colors, epic and grounded mood. A huge wolf wearing steel armor plates on its shoulders, leaping across the frame through a snowstorm, glowing pale blue eyes, frost breath, snow kicked up in an arc behind it. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, blood on the fangs.

#### 11. `kc_b_leviathan_lighthouse.png`

- **Unit** · **Style:** Painterly Heroic · **Suggested card:** (designer) new heavy creature unit · **Animated:** candidate (later)
- **Tags:** subject `creature` · weapon `natural` · element `water` · mood `eerie` · violence `v1` · setting `sea` · palette `teal` · verb `emerging`
- **Effect hint:** water/night: hidden until revealed, big body
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original heroic digital painting: visible confident brushwork, dramatic cinematic lighting with a strong rim light on the subject, rich atmospheric depth with haze and particles, saturated but controlled colors, epic and grounded mood. A colossal deep-sea leviathan with a jagged jaw and glowing teal lures rising out of a black stormy ocean at night beside a tiny lighthouse, rain and towering waves, the lighthouse beam cutting across the frame. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, gore, a sinking ship with people.

#### 12. `kc_b_storm_ronin.png`

- **Unit** · **Style:** Woodblock Ink · **Suggested card:** (designer) new melee unit · **Animated:** candidate (later)
- **Tags:** subject `soldier` · weapon `melee` · element `wind` · mood `stoic` · violence `v1` · setting `mythic` · palette `indigo` · verb `dueling`
- **Effect hint:** melee: strike the frontline only
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original woodblock print illustration: carved outlines, flat layered color areas, visible wood grain and textured paper, stylized waves, clouds, wind and rain drawn as patterns, muted palette of indigo, rust red, bone white and charcoal. A masked swordsman in a wide straw hat and long coat drawing a single-edged sword in heavy rain, the blade held horizontally across the frame, stylized rain lines and swirling clouds, one small red accent on the sword cord. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, calligraphy, seals or stamps with characters.

#### 13. `kc_b_sentry_walker.png`

- **Unit** · **Style:** Ink Comic · **Suggested card:** Sentry · **Animated:** no
- **Tags:** subject `robot` · weapon `lmg` · element `electric` · mood `menacing` · violence `v1` · setting `industrial` · palette `cyan` · verb `guarding`
- **Effect hint:** Protector / guard; electric: chain hit
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original bold ink comic illustration: thick black brush outlines, flat cel colors, halftone dot shading, speed lines and impact bursts, a limited palette of three strong colors plus black and paper white, very high contrast, background is a single flat color with simple graphic shapes. A squat four-legged security robot with a twin-barrel fictional machine-gun turret and a single round glowing red sensor eye, planted in a warehouse doorway, small sparks at its joints. Flat cyan background with a halftone gradient. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, serial numbers or warning stickers.

#### 14. `kc_b_gilded_launcher.png`

- **Unit** · **Style:** Cinematic Photo-ish · **Suggested card:** Demolitions Expert (or new launcher card) · **Animated:** candidate (later)
- **Tags:** subject `weapon_only` · weapon `launcher` · element `explosive` · mood `luxurious` · violence `v1` · setting `studio_void` · palette `gold` · verb `showcase`
- **Effect hint:** launcher: splash damage to a column
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original cinematic photorealistic film still: shallow depth of field, wide anamorphic lens look, filmic color grade with cool shadows and warm highlights, light haze and dust in the air, crisp detail on the subject. Every person is invented and has the face fully covered by a mask, goggles, visor or helmet. Product shot of a fictional shoulder-fired rocket launcher finished in gold and black lacquer with ornate swirling filigree, floating horizontally across the frame over a dark velvet background, dramatic studio rim light, faint smoke wisps. The filigree is abstract curls only. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, engraved letters, numbers or maker marks, a real launcher model.

### 5.2 Tactics (10)

#### 15. `kc_b_callout_ping.png`

- **Tactic** · **Style:** Minimal Emblem · **Suggested card:** Callout · **Animated:** yes (v1 animated)
- **Tags:** subject `emblem` · weapon `none` · element `electric` · mood `tactical` · violence `v0` · setting `abstract` · palette `red` · verb `revealing`
- **Effect hint:** reveal; animated: ring pulse (shader only)
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original minimal emblem artwork: one bold geometric symbol built from flat vector shapes, centered on a smooth two-tone gradient field, at most three colors, a subtle soft shadow, generous clean negative space. Not a badge, shield, crest, patch or logo: no frame or border around the symbol. Three concentric sonar-ping rings in hot red radiating from one bright dot in the center, on a deep slate-to-black gradient field, faint thin contour lines in the background. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, a map with labels, a radar screen with numbers.

#### 16. `kc_b_suppress_tracers.png`

- **Tactic** · **Style:** Retro Screenprint · **Suggested card:** Suppressing Fire · **Animated:** no
- **Tags:** subject `landscape` · weapon `none` · element `fire` · mood `chaotic` · violence `v2` · setting `desert` · palette `rust` · verb `suppressing`
- **Effect hint:** suppress: lower enemy power
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original retro screenprint poster illustration: three or four flat ink colors with slight misregistration, visible paper grain, bold simplified shapes, long dramatic shadows, warm faded palette of rust, cream, teal and ink blue, mid-century poster composition. Dozens of bright orange tracer lines streaking horizontally across a dusk desert ridge, sand plumes kicking up along the ridge line, scattered rocks, a pale moon, no people. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, people, bodies.

#### 17. `kc_b_flank_route_alley.png`

- **Tactic** · **Style:** Painterly Heroic · **Suggested card:** Flank Route · **Alt-art group:** `alt_flank_route` · **Animated:** no
- **Tags:** subject `landscape` · weapon `none` · element `none` · mood `stealthy` · violence `v0` · setting `old_town` · palette `green` · verb `flanking`
- **Effect hint:** move/flank
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original heroic digital painting: visible confident brushwork, dramatic cinematic lighting with a strong rim light on the subject, rich atmospheric depth with haze and particles, saturated but controlled colors, epic and grounded mood. A narrow overgrown side passage between two old stone buildings, curving away out of sight, morning light falling through hanging vines, a wooden door left ajar, footprints in the dust leading around the corner. No people. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, people, graffiti or signs.

#### 18. `kc_b_flank_route_emblem.png`

- **Tactic** · **Style:** Minimal Emblem · **Suggested card:** Flank Route · **Alt-art group:** `alt_flank_route` · **Animated:** no
- **Tags:** subject `emblem` · weapon `none` · element `none` · mood `stealthy` · violence `v0` · setting `abstract` · palette `olive` · verb `flanking`
- **Effect hint:** same card as kc_b_flank_route_alley
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original minimal emblem artwork: one bold geometric symbol built from flat vector shapes, centered on a smooth two-tone gradient field, at most three colors, a subtle soft shadow, generous clean negative space. Not a badge, shield, crest, patch or logo: no frame or border around the symbol. A single bold curved arc of footprints sweeping around a solid dark square block, footprints in warm gold on a deep olive gradient field. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, arrows, letters.

#### 19. `kc_b_hold_seawall.png`

- **Tactic** · **Style:** Woodblock Ink · **Suggested card:** Hold the Line · **Animated:** no
- **Tags:** subject `landscape` · weapon `none` · element `water` · mood `defiant` · violence `v0` · setting `sea` · palette `indigo` · verb `holding`
- **Effect hint:** hold: shield/fortify a column
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original woodblock print illustration: carved outlines, flat layered color areas, visible wood grain and textured paper, stylized waves, clouds, wind and rain drawn as patterns, muted palette of indigo, rust red, bone white and charcoal. A massive curling storm wave crashing against a low stone seawall that holds firm, spray exploding upward, a few gulls, stylized claw-shaped foam. No people. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, calligraphy, seals or stamps with characters.

#### 20. `kc_b_breach_burst.png`

- **Tactic** · **Style:** Ink Comic · **Suggested card:** Breach and Clear · **Animated:** no
- **Tags:** subject `object` · weapon `none` · element `explosive` · mood `chaotic` · violence `v2` · setting `interior` · palette `orange` · verb `breaching`
- **Effect hint:** breach: damage frontline
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original bold ink comic illustration: thick black brush outlines, flat cel colors, halftone dot shading, speed lines and impact bursts, a limited palette of three strong colors plus black and paper white, very high contrast, background is a single flat color with simple graphic shapes. A heavy steel door blasted off its hinges, flying toward the viewer in a starburst of white light with splinters and debris, comic impact rays. Flat orange background. No people. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, comic sound-effect lettering.

#### 21. `kc_b_supply_drop.png`

- **Tactic** · **Style:** Cinematic Photo-ish · **Suggested card:** Ammo Resupply · **Animated:** no
- **Tags:** subject `object` · weapon `none` · element `none` · mood `calm` · violence `v0` · setting `desert` · palette `sand` · verb `resupplying`
- **Effect hint:** resupply: draw/refresh
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original cinematic photorealistic film still: shallow depth of field, wide anamorphic lens look, filmic color grade with cool shadows and warm highlights, light haze and dust in the air, crisp detail on the subject. Every person is invented and has the face fully covered by a mask, goggles, visor or helmet. A plain olive supply crate under a parachute landing in a cloud of dust on a desert airstrip at sunrise, a red smoke signal drifting sideways across the frame. No people. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, stencil text or numbers on the crate.

#### 22. `kc_b_firestorm_city.png`

- **Tactic** · **Style:** Painterly Heroic · **Suggested card:** (designer) new fire tactic · **Animated:** candidate (later)
- **Tags:** subject `landscape` · weapon `none` · element `fire` · mood `apocalyptic` · violence `v1` · setting `city_skyline` · palette `orange` · verb `burning`
- **Effect hint:** fire: damage every unit in a column
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original heroic digital painting: visible confident brushwork, dramatic cinematic lighting with a strong rim light on the subject, rich atmospheric depth with haze and particles, saturated but controlled colors, epic and grounded mood. A distant city skyline under a towering orange firestorm cloud at night, glowing embers raining down, silhouetted radio towers, the sky glowing like molten metal. No people. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, recognizable real skyline or landmark.

#### 23. `kc_b_blackout_street.png`

- **Tactic** · **Style:** Neon Synth · **Suggested card:** (designer) new Blackout tactic · **Animated:** yes (v1 animated)
- **Tags:** subject `landscape` · weapon `none` · element `electric` · mood `eerie` · violence `v0` · setting `night_city` · palette `cyan` · verb `disabling`
- **Effect hint:** electric/night: silence or hide; animated: neon flicker
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original neon synth illustration: deep night palette of violet, indigo and black, glowing hot pink and cyan neon light on edges, soft light bloom, smooth clean shapes, sharp glowing silhouettes, retro 1980s night mood. A rain-soaked neon city street where the glowing lights switch off block by block, the left half already pitch dark, sparks falling from a burst transformer, puddle reflections. Signs are blank glowing shapes with no lettering. No people in focus. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, signs with letters or fake writing.

#### 24. `kc_b_toxic_bog.png`

- **Tactic** · **Style:** Neon Synth · **Suggested card:** (designer) new Gas Cloud tactic · **Animated:** candidate (later)
- **Tags:** subject `landscape` · weapon `none` · element `toxic` · mood `eerie` · violence `v0` · setting `swamp` · palette `green` · verb `poisoning`
- **Effect hint:** toxic: weaken power over time
- **Generate:** 1536x1024 landscape. **Crop:** see section 3 (default band and column centred).

```
Original neon synth illustration: deep night palette of violet, indigo and black, glowing hot pink and cyan neon light on edges, soft light bloom, smooth clean shapes, sharp glowing silhouettes, retro 1980s night mood. A swamp at night filled with thick glowing acid-green fog, twisted dead trees, bubbling pools, glowing spores floating upward. No people. Wide 3:2 landscape image that will be cropped two ways: a thin 4:1 strip across the middle, and a tall 2:3 column in the center. Put the main subject in the exact center. Keep the key parts (head, hands, weapon, the brightest focal point) at mid-height, between 30% and 65% of the image height, and inside the middle 70% of the width. Let a held weapon or the main motion run horizontally across the frame. The left and right 15% of the image stay calmer, darker and low in detail. Above and below the subject, continue the background simply so the tall crop still looks complete. One clear subject with a bold silhouette that reads at thumbnail size. No text, letters, numbers, logos, brand marks, insignia, flags, badges or symbols on clothing or gear. Invented characters only, no real people. No blood, wounds or gore.
```

**Avoid:** text, letters, numbers, logos, insignia, flags, badges, real people, real weapon or vehicle models, blood, gore, hazard symbols, skulls.

---

## 6. Batches and hand-off

| Batch | Files | Why |
|---|---|---|
| 1 | the 6 alt-art pair images | Proves "many arts, one card" and the cross composition in 4 families |
| 2 | `kc_b_point_man_bazaar`, `kc_b_breacher_doorkick`, `kc_b_gunner_inferno`, `kc_b_shieldman_sparks`, `kc_b_medic_goldengrass`, `kc_b_sentry_walker`, `kc_b_callout_ping` | Covers the existing starter cards |
| 3 | `kc_b_suppress_tracers`, `kc_b_hold_seawall`, `kc_b_breach_burst`, `kc_b_supply_drop`, `kc_b_blackout_street` | Remaining existing tactics + first animated tactic |
| 4 | `kc_b_frost_wolf`, `kc_b_leviathan_lighthouse`, `kc_b_storm_ronin`, `kc_b_gilded_launcher`, `kc_b_firestorm_city`, `kc_b_toxic_bog` | New subjects and weapon classes: feed the designer's new cards |

- **Technical Artist:** import per section 3.2, build the `BannerArt` regions, the side-gradient safety net (1.4) and the T1 shader; T2 for `kc_b_marksman_neon` and `kc_b_gunner_inferno` once their layers exist.
- **Curator:** one CSV row per image; never mark `approved` before the checklist in 1.6 passes.
- **Art review (Sr Game Artist):** approves each batch against 1.3-1.6 before import.

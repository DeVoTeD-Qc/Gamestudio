# Killstreak: image prompt pack v1

*Author: Sr Game Artist Agent · 2026-11-04 · Board task k-art1 · Target: Godot 4.4.1 web, iPhone landscape*
*For: the studio head (generate in ChatGPT on the phone) and the Technical Artist (import).*
*IP: every image must be original. See section 4 before uploading anything.*

**48 images.** 36 replace art the game already draws in code; 12 are new slots (marked NEW) that need a small code hook from the Technical Artist.

## 1. How to use it

1. **One image per prompt.** Open a fresh ChatGPT chat (keeps old images from bleeding in). Copy the grey prompt box and send it. If ChatGPT asks a question, answer "just generate it".
2. **Ask for the right shape.** Each entry says *Generate*: landscape (1536x1024), square (1024x1024) or portrait (1024x1536). If the image comes back in another shape, reply: "Same image, landscape 3:2" (or square / portrait 2:3).
3. **Don't crop on the phone.** Upload the full image. The Technical Artist does the exact crop listed under *Crop*. Only regenerate if the main subject touches an edge, because the crop trims a strip off the top and bottom.
4. **Fix a bad result in the same chat:** reply "Regenerate, avoid: ..." and paste that entry's *Avoid* line. Use the checklist in section 4 to decide. Two tries, then skip it and note it.
5. **Name the file** exactly as the entry's file name (lowercase, underscores, `.png`). On iPhone: save to Files, long-press, Rename. If renaming is a pain, skip it and type the names in your message in upload order instead.
6. **Upload** either way:
   - **Studio Floor chat:** attach the images and write the file names, e.g. "card_rifleman, card_point_man, lane_cranes".
   - **Repo:** commit them to `projects/killstreak/source/project-killstreak/assets/incoming/` (see the README there).
7. Upload in batches of 5 to 10 so a bad batch is cheap to redo.

## 2. Shared style block

Every prompt below already starts with this block, so you never paste it on its own. It is here so the set can be reviewed or tuned in one place. If you change it, change it in every prompt (the TA can regenerate this file).

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore.
```

- **Palette** (from `style-guides/art-direction.md`): slate `#12161A`, gunmetal `#232A31`, fog `#D8DEE3`, olive `#5B6B3A`, sand `#C2A878`, concrete `#7A828A`.
- **One accent per image:** amber `#FFB020` for units, tactics and gear; cyan `#5BC0EB` for killstreaks and drone or tablet tech; brass `#C9A227` for Elite cards; teal `#2EC4B6` (friend) and red `#E5383B` (hostile) only where the subject is about sides.
- **Lighting:** dusk, sodium floodlights, rim light on the silhouette, deep shadow. **Camera:** three-quarter or side view for people, product side profile for weapons, high angle for places.
- **Rendering:** duotone painted, flat shapes, light grain, readable as a thumbnail (a card in the hand is about 120 px wide on a phone).
- **Hard rules in every prompt:** no text, numbers, logos, insignia, flags, symbol patches or brand marks; no visible faces (helmets, masks, goggles); no gore.

## 3. Prompts, in priority order

Size key used below:

| Kind | In game | Ship to the TA | Generate | Crop |
|---|---|---|---|---|
| Card art | Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone | 888x544 PNG (4x) | 1536x1024 (landscape) | Crop to 1536x941 (cut ~41 px top and bottom), then resize to 888x544. |
| Lane | Lane backdrop 400x360 px (10:9), rasterised at up to 2x | 800x720 PNG (2x) | 1024x1024 (square) | Crop to 1024x922 (cut ~51 px top and bottom), then resize to 800x720. |
| Full screen | Full screen: 1280x720 base (16:9); the phone shows a 1168x540 (2.16:1) center band | 1536x864 PNG | 1536x1024 (landscape) | Crop to 1536x864 (cut 80 px top and bottom). Keep the subject inside the middle 1536x710 band so the phone crop is safe. |
| Card back | Card back 250x350 px (5:7), shown up to ~1.4x | 500x700 PNG (2x) | 1024x1536 (portrait) | Crop to 1024x1434 (cut ~51 px top and bottom), then resize to 500x700. |
| Perk patch | Perk patch, round, ~64-96 px on screen (Operator panel, pick tiles) | 512x512 PNG | 1024x1024 (square) | No crop. Resize to 512x512. The TA masks it to a circle. |

### 1. Card art

Every card art image uses the **Card art** size: generate **1536x1024**, crop to 1536x941, ship 888x544. The starter deck and starting loadout come first.

#### 1. `card_rifleman.png`

- **Used in:** Rifleman (unit, AR). 3 copies in the starter deck: the most-seen card. Also the fallback for any AR-class card.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A lone contractor rifleman in helmet and plate carrier, kneeling behind a low concrete barrier, compact rifle raised, three-quarter view from slightly low. Blurred stacked shipping containers behind. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 2. `card_point_man.png`

- **Used in:** Point Man (unit, SMG, First Shot). Starter deck x2. Fallback for SMG-class cards.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A fast point man in a low crouch rounding the corner of a shipping container, compact submachine gun forward, goggles down, faint motion streaks behind him. Side view, narrow container alley. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 3. `card_marksman.png`

- **Used in:** Marksman (unit, sniper, Pick). Starter deck x2. Fallback for sniper-class cards.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A marksman lying prone on top of a shipping container, long scoped rifle on a bipod, cloth wrap over the helmet, gantry cranes far away on the horizon. Low side view, long horizontal shapes. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 4. `card_combat_medic.png`

- **Used in:** Combat Medic (unit, Patch 2). Starter deck x2.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A combat medic kneeling beside a seated, tired teammate, opening a trauma kit, rifle slung on the back, plain teal armband with no symbol. Three-quarter view behind a container. Accent: halberd teal #2EC4B6. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** red cross, red crescent or any medical emblem, wounds.

#### 5. `card_callout.png`

- **Used in:** Callout (tactic, reveal red dots). Starter deck. Also the generic Tactic fallback.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. Close-up of a gloved hand pointing over the edge of a container while the other hand presses a headset microphone, three small glowing hostile-red dots in the dusk yard beyond. Accent: hostile red #E5383B. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 6. `card_recon_drone.png`

- **Used in:** Recon Drone (killstreak). Starter killstreak. Also the generic Killstreak fallback.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A small quadcopter drone hovering over a container port at night, a downward cone of cool light sweeping the stacks below, tiny rotor blur. Accent: uplink cyan #5BC0EB glow. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** real drone brands, text overlays, HUD numbers.

#### 7. `card_mortar_barrage.png`

- **Used in:** Mortar Barrage (killstreak). Starter killstreak.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. Three mortar shells arcing down through a dusk sky onto a distant container stack, bright impact flashes and rising smoke, wide view from a low rise. Accent: uplink cyan #5BC0EB glow. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 8. `card_attack_helo.png`

- **Used in:** Attack Helo (killstreak). Starter killstreak.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A sleek fictional attack helicopter banking low over dark harbor water, nose turret, rotor blur, searchlight beam on the quay. Accent: uplink cyan #5BC0EB glow. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** any real helicopter model, markings, roundels.

#### 9. `card_kestrel_ar7.png`

- **Used in:** Kestrel AR-7 (Operator primary). The starting weapon on the Operator card and Loadout.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A fictional modern assault rifle in clean side profile resting on a gunmetal workbench, compact optic, rail, folding stock, no markings. Product-shot lighting. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** real gun brands or models, engravings, serial numbers.

#### 10. `card_frag_grenade.png`

- **Used in:** Frag Grenade (starting Lethal), Loadout and Operator panel.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A plain fragmentation grenade tumbling in mid-air above wet concrete, the pin ring flying free, motion blur, close-up, warm floodlight glow behind. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 11. `card_flashbang.png`

- **Used in:** Flashbang (starting Tactical), Loadout and Operator panel.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A cylindrical stun grenade bursting in a dim container corridor, blinding white flash with soft rings, two helmeted silhouettes turning away and shielding their eyes. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 12. `card_p12_sidearm.png`

- **Used in:** P-12 Sidearm (starting Secondary), Loadout and Operator panel.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. Close-up of a plain fictional compact pistol held low at the ready in a gloved hand, thigh holster below, shallow depth of field. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** real pistol brands or models, engravings.

#### 13. `card_breacher.png`

- **Used in:** Breacher (unit, shotgun, First Shot). Fallback for shotgun-class cards.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A breacher with a pump shotgun bracing at a steel roller door, shoulder lowered, heavy helmet and visor, sparks at the door seam. Three-quarter view. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 14. `card_gunner.png`

- **Used in:** Gunner (unit, LMG, Suppress). Fallback for LMG-class cards.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A heavy gunner firing a belt-fed machine gun over sandbags, brass casings arcing out, warm muzzle glow, three-quarter front view. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 15. `card_shieldman.png`

- **Used in:** Shieldman (unit, Cover 1). Also the generic Unit fallback.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A shieldman advancing behind a tall ballistic shield with a small viewport, pistol resting on the shield edge, full helmet, sparks glancing off the shield. Front three-quarter view. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 16. `card_recon_specialist.png`

- **Used in:** Recon Specialist (unit, reveals red dots).
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A recon specialist crouched on a steel gantry with a rugged tablet and a small folding antenna, binoculars on the helmet, cool screen glow on the visor, the port below. Accent: uplink cyan #5BC0EB glow. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 17. `card_suppressing_fire.png`

- **Used in:** Suppressing Fire (tactic). Also the Firefight mode art on the run map.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. Bright tracer lines streaking across a container yard toward a pinned silhouette behind a concrete block, dust kicked up along the wall. Side view. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 18. `card_hold_the_line.png`

- **Used in:** Hold the Line (tactic). Also the Zone Control mode art on the run map.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. Three helmeted contractors shoulder to shoulder behind sandbags and a concrete barrier, rifles leveled, low front view, floodlights behind them. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 19. `card_flank_route.png`

- **Used in:** Flank Route (tactic).
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. High top-down view of rows of shipping containers with a curving dashed amber path around the side, four tiny squad silhouettes moving along it. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 20. `card_ammo_resupply.png`

- **Used in:** Ammo Resupply (tactic, draw 2).
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. An open olive ammo crate on a wooden pallet, rifle magazines and ammo cans stacked inside, gloved hands lifting two magazines, overhead floodlight. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 21. `card_breach_and_clear.png`

- **Used in:** Breach and Clear (tactic, reward pool).
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A steel door blown inward in a burst of light and dust, two helmeted silhouettes stacked on either side of the frame, interior view. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 22. `card_flanker.png`

- **Used in:** Flanker (unit, SMG, Flank, reward pool).
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A flanker sprinting low along a wet quay edge, submachine gun held close, side view, long reflections in puddles, dusk. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 23. `card_demolitions_expert.png`

- **Used in:** Demolitions Expert (unit, reward pool).
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A demolitions expert crouched at a container door setting a plain blocky charge with wires, heavy backpack, machine gun slung, one small amber warning light. Side view. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 24. `card_comms_relay.png`

- **Used in:** Comms Relay (equipment, reward pool). Also the generic Equipment fallback.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A portable radio relay mast with a folding dish and blinking lights on a tripod on a container roof, cables trailing, night sky. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 25. `card_tripwire_charge.png`

- **Used in:** Tripwire Charge (equipment). Also the Detonator mode art on the run map.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A thin tripwire stretched across a dark container alley at ankle height, clipped to a small blocky charge with one amber light. Low close view. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 26. `card_sentry.png`

- **Used in:** Sentry (token unit placed by Sentry Turret).
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. An unmanned compact gun sentry on a short tripod at the back of a quay, boxy armored housing, small amber status light, no person. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 27. `card_sentry_turret.png`

- **Used in:** Sentry Turret (killstreak).
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A deployable automated turret unfolding out of a hard case on a container roof, cyan status light, a little dust from the deploy. Accent: uplink cyan #5BC0EB glow. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 28. `card_gunship.png`

- **Used in:** Gunship (killstreak art). Also the Rival match art on the run map.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A large fictional fixed-wing gunship circling high above a port at night, side guns glowing, a beam of light on the yard below. Accent: uplink cyan #5BC0EB glow. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** any real aircraft model, markings, roundels.

#### 29. `card_okafor_anvil.png`

- **Used in:** Sgt. Okafor "Anvil" (Elite unit, reward pool).
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A broad elite sergeant planted in front of stacked containers, rifle across his chest, heavy armor with extra plates, helmet and mask, one fist raised to hold the squad. Low heroic angle. Accent: brass #C9A227 rim light, elite feel. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 30. `card_halek_wren.png`

- **Used in:** Lt. Halek "Wren" (Elite unit, reward pool).
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. An elite woman sniper officer standing on a crane platform at dusk, long scoped rifle, long coat over armor, balaclava and goggles, coat moving in the wind. Low heroic angle. Accent: brass #C9A227 rim light, elite feel. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 31. `card_wasp_9.png`

- **Used in:** Wasp-9 (Operator primary, unlockable).
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A fictional compact submachine gun in clean side profile on a gunmetal workbench, folding stock, short suppressor, no markings. Product-shot lighting. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** real gun brands or models, engravings, serial numbers.

#### 32. `card_longreach_338.png`

- **Used in:** Longreach .338 (Operator primary, unlockable).
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A fictional long bolt-action sniper rifle in clean side profile on a gunmetal workbench, large scope, folded bipod, no markings. Product-shot lighting. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered, keep the top and bottom 10% free of important detail.
```

**Avoid:** real gun brands or models, engravings, serial numbers.

### 2. Board lane backdrops (Port Vasel)

#### 33. `lane_containers.png`

- **Used in:** Left lane, "Container Stacks" (Close range), behind 8 unit slots. Replaces the SVG in CardArt LANES[containers].
- **Target:** Lane backdrop 400x360 px (10:9), rasterised at up to 2x. Ship 800x720 PNG (2x).
- **Generate:** 1024x1024 (square). **Crop:** 1024x922 (cut ~51 px top and bottom), then resize to 800x720.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. High three-quarter view looking down a container stack lane at a harbor: rows of stacked shipping containers in muted olive and concrete, twist-lock corners, wet ground. Very dark, low contrast, calm empty middle for game pieces. Accent: faint sodium amber #FFB020 glow at the far end only. Square composition, no single focal point.
```

**Avoid:** people, vehicles in the foreground, bright highlights in the middle, text.

#### 34. `lane_cranes.png`

- **Used in:** Middle lane, "Crane Yard" (Long range). Replaces CardArt LANES[cranes].
- **Target:** Lane backdrop 400x360 px (10:9), rasterised at up to 2x. Ship 800x720 PNG (2x).
- **Generate:** 1024x1024 (square). **Crop:** 1024x922 (cut ~51 px top and bottom), then resize to 800x720.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. High three-quarter view of a harbor crane yard: two gantry cranes, crane rails running into the distance, a few containers. Very dark, low contrast, calm empty middle for game pieces. Accent: faint sodium amber #FFB020 glow at the far end only. Square composition, no single focal point.
```

**Avoid:** people, vehicles in the foreground, bright highlights in the middle, text.

#### 35. `lane_offices.png`

- **Used in:** Right lane, "Loading Offices" (Mid range). Replaces CardArt LANES[offices].
- **Target:** Lane backdrop 400x360 px (10:9), rasterised at up to 2x. Ship 800x720 PNG (2x).
- **Generate:** 1024x1024 (square). **Crop:** 1024x922 (cut ~51 px top and bottom), then resize to 800x720.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. High three-quarter view of low port loading offices: a flat-roofed building, roller doors, small dim windows, a loading dock and pallets. Very dark, low contrast, calm empty middle for game pieces. Accent: faint sodium amber #FFB020 glow at the far end only. Square composition, no single focal point.
```

**Avoid:** people, vehicles in the foreground, bright highlights in the middle, text.

### 3. Title key art

#### 36. `title_key_art.png`

- **Used in:** Title screen background (KeyArt TextureRect, cover). The wordmark and menu are drawn on top by the game; replaces CardArt KEY_ART.
- **Target:** Full screen: 1280x720 base (16:9); the phone shows a 1168x540 (2.16:1) center band. Ship 1536x864 PNG.
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x864 (cut 80 px top and bottom). Keep the subject inside the middle 1536x710 band so the phone crop is safe.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. Panoramic dusk skyline of a fictional container port: gantry cranes in silhouette, colored container stacks, floodlights, calm reflective water. A squad of four helmeted contractors in rim-lit silhouette on a quay in the right third. Left 40% dark and calm for menus. Accent: signal amber #FFB020 rim light. Cinematic wide shot, horizon in the middle third.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood, title text, a game logo.

### 4. Run map and run screens

#### 37. `runmap_mode_zone_control.png` (NEW)

- **Used in:** Run map match card for Zone Control (now reuses card_hold_the_line). New key, needs a one-line code change.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A small fortified position on a container yard: sandbags, a planted marker beacon with a soft amber light, two helmeted contractors guarding it, seen from a high angle. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered; the image may be cropped tall or wide.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 38. `runmap_mode_firefight.png` (NEW)

- **Used in:** Run map match card for Firefight (now reuses card_suppressing_fire). New key.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. Two small squads exchanging tracer fire across an open quay between container stacks, seen from a high side angle, sparks and dust. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered; the image may be cropped tall or wide.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 39. `runmap_mode_detonator.png` (NEW)

- **Used in:** Run map match card for Detonator (now reuses card_tripwire_charge). New key.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A plain metal device case with a blinking amber light sitting on a pallet in a dim warehouse, a helmeted contractor kneeling beside it with a toolkit. Accent: signal amber #FFB020 rim light. Wide landscape composition, subject centered; the image may be cropped tall or wide.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood, countdown digits, wires spelling shapes.

#### 40. `runmap_mode_rival.png` (NEW)

- **Used in:** Run map card for the Rival match (now reuses card_gunship). New key.
- **Target:** Art window 222x136 px (1.63:1) on a 250x350 card; shown up to ~1.4x in the inspector on a 3x phone. Ship 888x544 PNG (4x).
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x941 (cut ~41 px top and bottom), then resize to 888x544.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. Four elite rival contractors in dark armor standing in a line on a quay at night, faces hidden by black masks, one lit by a hostile red signal flare behind them. Accent: hostile red #E5383B. Wide landscape composition, subject centered; the image may be cropped tall or wide.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

#### 41. `bg_run.png` (NEW)

- **Used in:** Optional bitmap under the tactical_backdrop shader on Loadout, run map, Supply Drop, After Action and Run End.
- **Target:** Full screen: 1280x720 base (16:9); the phone shows a 1168x540 (2.16:1) center band. Ship 1536x864 PNG.
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x864 (cut 80 px top and bottom). Keep the subject inside the middle 1536x710 band so the phone crop is safe.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A dark, out-of-focus top-down tactical map of a harbor: container rows, crane rails and quay edges as faint shapes, soft vignette, subtle grid feel. Very low contrast, nothing sharp. Accent: faint signal amber #FFB020 haze in one corner. Even texture across the frame, no focal point.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood, map labels, grid numbers, compass rose.

### 5. Killstreak call-in and rewards

#### 42. `fx_callin_tablet.png` (NEW)

- **Used in:** Background of the 0.8 s full-screen killstreak call-in takeover (call_in_takeover.gd). The game draws the band, brackets and text on top.
- **Target:** Full screen: 1280x720 base (16:9); the phone shows a 1168x540 (2.16:1) center band. Ship 1536x864 PNG.
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x864 (cut 80 px top and bottom). Keep the subject inside the middle 1536x710 band so the phone crop is safe.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. Close-up of a rugged field tablet screen filling the frame, glowing with an abstract top-down harbor feed, scanlines, a soft circular target reticle in the middle, gloved thumbs at the edges. Accent: uplink cyan #5BC0EB glow. Screen fills the frame edge to edge.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood, readable UI, menus, numbers on screen.

#### 43. `bg_supply_drop.png` (NEW)

- **Used in:** Optional backdrop for the Supply Drop reward screen (reward_screen.gd), dimmed behind the 3 offered cards.
- **Target:** Full screen: 1280x720 base (16:9); the phone shows a 1168x540 (2.16:1) center band. Ship 1536x864 PNG.
- **Generate:** 1536x1024 (landscape). **Crop:** 1536x864 (cut 80 px top and bottom). Keep the subject inside the middle 1536x710 band so the phone crop is safe.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A supply crate hanging under a parachute dropping into a dark container yard, a floodlight cone on it, dust below. The crate sits in the right third; the rest is dark and calm for cards. Accent: signal amber #FFB020 rim light. Cinematic wide shot.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood.

### 6. Card back and perk patches

#### 44. `card_back.png` (NEW)

- **Used in:** New: face-down cards (enemy plays, deck pile, deal animations). No slot in code yet.
- **Target:** Card back 250x350 px (5:7), shown up to ~1.4x. Ship 500x700 PNG (2x).
- **Generate:** 1024x1536 (portrait). **Crop:** 1024x1434 (cut ~51 px top and bottom), then resize to 500x700.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. A card back design: dark gunmetal laminated badge texture, a centered abstract geometric mark made of two amber chevrons inside a thin hexagon outline, faint topographic contour lines, worn edges, symmetrical. Accent: signal amber #FFB020 rim light. Portrait, perfectly centered and symmetrical, flat front-on view.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood, eagles, skulls, swords, stars, wings, shields, any emblem that looks like a unit badge.

#### 45. `perk_streak_discipline.png` (NEW)

- **Used in:** Perk Streak Discipline (Operator panel perk slot, perk pick tiles). Now an icon from the icon sheet.
- **Target:** Perk patch, round, ~64-96 px on screen (Operator panel, pick tiles). Ship 512x512 PNG.
- **Generate:** 1024x1024 (square). **Crop:** No crop. Resize to 512x512. The TA masks it to a circle.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. Patch design: a simple stylized metronome or stopwatch shape stitched in amber thread on gunmetal fabric. Accent: signal amber #FFB020 rim light. A single round embroidered morale patch, centered, flat front-on view on a plain slate #12161A background, stitched border.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood, skulls, national flags, unit crests, a second patch.

#### 46. `perk_field_salvage.png` (NEW)

- **Used in:** Perk Field Salvage.
- **Target:** Perk patch, round, ~64-96 px on screen (Operator panel, pick tiles). Ship 512x512 PNG.
- **Generate:** 1024x1024 (square). **Crop:** No crop. Resize to 512x512. The TA masks it to a circle.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. Patch design: a gloved hand lifting a single card-shaped magazine, stitched in sand and amber thread on olive fabric. Accent: signal amber #FFB020 rim light. A single round embroidered morale patch, centered, flat front-on view on a plain slate #12161A background, stitched border.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood, skulls, national flags, unit crests, a second patch.

#### 47. `perk_grit.png` (NEW)

- **Used in:** Perk Grit.
- **Target:** Perk patch, round, ~64-96 px on screen (Operator panel, pick tiles). Ship 512x512 PNG.
- **Generate:** 1024x1024 (square). **Crop:** No crop. Resize to 512x512. The TA masks it to a circle.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. Patch design: a cracked armor plate still standing, stitched in fog white and amber thread on gunmetal fabric. Accent: signal amber #FFB020 rim light. A single round embroidered morale patch, centered, flat front-on view on a plain slate #12161A background, stitched border.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood, skulls, national flags, unit crests, a second patch.

#### 48. `perk_objective_focus.png` (NEW)

- **Used in:** Perk Objective Focus.
- **Target:** Perk patch, round, ~64-96 px on screen (Operator panel, pick tiles). Ship 512x512 PNG.
- **Generate:** 1024x1024 (square). **Crop:** No crop. Resize to 512x512. The TA masks it to a circle.

```
Original stylized 2D duotone painting for a mobile card game, modern private-military theme. Flat graphic shapes, bold readable silhouette, light film grain. Palette: slate black #12161A, gunmetal #232A31, fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, plus one accent color. Dusk sodium-floodlight rim light, deep soft shadows. No text, letters, numbers, logos, insignia, flags, emblems or brand marks. Faces hidden by helmets, masks or goggles. No gore. Patch design: two small triangular zone markers joined by a line, stitched in teal and amber thread on olive fabric. Accent: signal amber #FFB020 rim light. A single round embroidered morale patch, centered, flat front-on view on a plain slate #12161A background, stitched border.
```

**Avoid:** text, numbers, logos, insignia, flags, real weapon brands, real aircraft models, recognizable people, gore, blood, skulls, national flags, unit crests, a second patch.

## 4. IP guardrails

- **All original.** No characters, operators, logos, maps, killstreak icons, emblems, calling cards or UI styling from Call of Duty, Activision or any other game or film franchise.
- **No real military.** No real units, branch or national insignia, flags, rank badges, roundels or tail markings. No red cross or red crescent: they are protected emblems, so the medic uses a plain teal armband.
- **No real products.** Weapons, drones and aircraft must be fictional, with no brand names, engravings or a shape that is clearly one real model.
- **No real people.** Faces are covered; nobody should look like a real person.
- **Never name a franchise, game, studio, film or artist in a prompt**, even as "in the style of" or "not like". The prompts here describe the look in plain visual words only. Keep it that way when you reword one.
- **No generated text.** The game draws all words and numbers. Any letters in an image, even fake ones, mean regenerate.

### Reject checklist (any "yes" means regenerate or skip)

- [ ] Any letters, numbers, fake writing or a logo anywhere, including on gear, crates, screens or the aircraft?
- [ ] A flag, national or unit insignia, rank badge, roundel, skull emblem or a patch with a symbol on someone?
- [ ] A red cross or red crescent?
- [ ] A visible face, or someone who looks like a real person or a known game character?
- [ ] A weapon, helicopter, plane or drone that is clearly a real named model, or carries a brand mark?
- [ ] Anything that looks like a screen, icon, map or menu from an existing shooter?
- [ ] Blood, wounds or a body?
- [ ] Off palette: bright saturated colours everywhere, or more than one strong accent?
- [ ] Unreadable as a thumbnail: squint at it at a small size. Is the subject still clear?
- [ ] The subject touches the top or bottom edge, so the crop would cut it (card and full-screen art)?
- [ ] Lanes only: a bright or busy middle that would fight with the unit tokens?

## 5. Count and batch plan

| Group | Images |
|---|---|
| 1. Card art | 32 |
| 2. Board lane backdrops (Port Vasel) | 3 |
| 3. Title key art | 1 |
| 4. Run map and run screens | 5 |
| 5. Killstreak call-in and rewards | 2 |
| 6. Card back and perk patches | 5 |
| **Total** | **48** (36 replace existing procedural art, 12 NEW) |

**Session A (20 to 30 minutes, 22 images).** At about one minute per image plus a quick check, this covers everything a new player sees in the first run: the starter deck, the starting loadout and killstreaks, the board and the Title.

1. `card_rifleman.png`, `card_point_man.png`, `card_marksman.png`, `card_combat_medic.png`, `card_callout.png`, `card_recon_drone.png`
2. `card_mortar_barrage.png`, `card_attack_helo.png`, `card_kestrel_ar7.png`, `lane_containers.png`, `lane_cranes.png`, `lane_offices.png`
3. `title_key_art.png`, `card_breacher.png`, `card_gunner.png`, `card_shieldman.png`, `card_recon_specialist.png`, `card_suppressing_fire.png`
4. `card_hold_the_line.png`, `card_frag_grenade.png`, `card_flashbang.png`, `card_p12_sidearm.png`

**Session B (26 images).** The reward-pool cards, Elites, other primaries, then the NEW slots:

1. `card_flank_route.png`, `card_ammo_resupply.png`, `card_breach_and_clear.png`, `card_flanker.png`, `card_demolitions_expert.png`, `card_comms_relay.png`, `card_tripwire_charge.png`
2. `card_sentry.png`, `card_sentry_turret.png`, `card_gunship.png`, `card_okafor_anvil.png`, `card_halek_wren.png`, `card_wasp_9.png`, `card_longreach_338.png`
3. `runmap_mode_zone_control.png`, `runmap_mode_firefight.png`, `runmap_mode_detonator.png`, `runmap_mode_rival.png`, `bg_run.png`, `fx_callin_tablet.png`, `bg_supply_drop.png`
4. `card_back.png`, `perk_streak_discipline.png`, `perk_field_salvage.png`, `perk_grit.png`, `perk_objective_focus.png`

Tip: do the three lanes back to back in one chat thread (say "same style as the last one") so they match; do the same for the four perk patches.

## 6. Notes for the Technical Artist

- **Keep the procedural art as the fallback.** `CardArt` (SVG in `card_art_data.gd`) stays. Load a bitmap when `res://assets/sprites/cards/<key>.png` (etc.) exists, else rasterise the SVG. That way a missing or rejected image never leaves a blank card.
- **Card art** keys match `CardArt.Data.CARDS` (file name = `card_` + key). Aliases (`class_*`, `ks_*`, `type_*`) keep pointing at these keys. The art window is `STRETCH_KEEP_ASPECT_COVERED`, so 1.63:1 art fills it exactly.
- **Lanes** are dimmed in engine (`lane_*` colours, invalid-target scrim) and should stay so; don't bake extra darkness in beyond the prompt.
- **Tokens** (the white class silhouettes on board units) stay procedural: they are tinted by side and mirrored for the enemy, which a painted image can't do cleanly.
- **Format:** ship WebP (lossy, quality ~85) or PNG; import as *Lossless* (PNG) or *Lossy* (WebP), not *VRAM Compressed*, which bands painted gradients on web, mipmaps off, filter linear. Budget: 32 card images at 888x544 WebP are about 2.5 to 3.5 MB; with the full-screen images the whole pack should stay under ~6 MB. The art direction prototype budget is 5 MB, so consider 666x408 (3x) for card art if it runs over.
- **Full-screen art** comes in at 1536x864; it is upscaled on 3x phones (the SVG title went to ~2x). Painted art tolerates that; if the Title looks soft on a real iPhone, upscale that one image 2x with an offline upscaler.
- **NEW slots** need hooks: run map mode art (`run_map.gd::_mode_art`), the call-in background (`call_in_takeover.gd`), Supply Drop and run backdrops, a card back, and perk patches (`operator_panel.gd::_build_perks`, pick tiles).
- Images in `assets/incoming/` are raw. Move each one, after crop and approval, to its final folder (`assets/sprites/cards/`, `assets/sprites/board/`, `assets/ui/backgrounds/`, `assets/ui/perks/`) and leave `incoming/` for drops only. Add a `.gdignore` to `incoming/` (or exclude `assets/incoming/*` in the export preset) so raw drops are never imported or exported.


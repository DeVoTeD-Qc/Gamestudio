# DeadDraw art pack 1: prompts for ChatGPT

**ChatGPT, read this first.** This file is a list of image requests for DeadDraw, an original zombie card game
(a street of zombie cards, guns that stack kills, melee weapons, heal and cover items, rooms behind doors, Patches,
bosses, and three districts: Maple Row, Downtown and St. Agnes Hospital). For each image below:
1. Generate ONE image from the text in its "Prompt" block, exactly as written. Use the size the prompt names
   (1536x1024, 1024x1024 or 1024x1536).
2. Do not add any text, letters, numbers, logos, brand names, insignia or real weapon or product models to the image.
   The game draws every word and number itself.
3. Where a prompt says "transparent background", output a PNG with a real alpha channel (no checkerboard, no white).
4. Give the image the file name shown on its "File" line, exactly (lowercase, `.png`).
5. If the person asks to redo an image, regenerate it and avoid what its "Avoid" line lists.
6. Keep every image in the same style (the "Shared style" block below is already inside every prompt).
7. When a batch is done, push the PNGs to the GitHub repository on the branch `art/deaddraw-pack-1`, into the folder
   `projects/deaddraw/documentation/art/chatgpt/images/art-pack-1/` (create the branch from `main` if it does not
   exist; do not touch any other folder or the `main` branch). If you cannot push, give the person the files to download
   with these exact names.

Work through one batch at a time, in order. When the person says "Batch N", generate every image in that batch, one at
a time.

All art is original. Style: bold painted comic, chunky silhouettes, cartoon-level horror (never gore), one warm light.

Source: `projects/deaddraw/documentation/art/art-direction.md` (the art direction) and
`projects/deaddraw/documentation/art/art-pack-1-list.csv` (the full list with game sizes and where each image is used).

## Shared style (already part of every prompt)

```
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

Colour per card type (matches the badge and frame colours in the game): yellow = guns and melee (hit), blood red = zombies, purple = bosses, green = heal, gold = cover, copper = workshop machines.

| Batch | What | Images |
|---|---|---|
| 1 | Zombies and bosses | 9 |
| 2 | Guns | 11 |
| 3 | Melee weapons and items | 10 |
| 4 | Rooms and machines | 18 |
| 5 | City, survivors, card backs and title | 11 |
| 6 | Patches | 14 |
| 7 | Painted UI icons (only where a painted icon helps) | 4 |
| | **Total** | **77** |


---

## Batch 1: Zombies and bosses

The cards the player sees most. Every zombie is the same species, a slow, shabby, grey-green townsperson; strength reads from size and pose.

### Image 1: Shambler (values 1-3)

**File:** `dd_zombie_shambler.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one small, thin shambling zombie in a faded cardigan and slippers, head lolling to one side, one arm reaching forward, shuffling towards the viewer, full body visible.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: zombie card. Backdrop a dusky blood-red to brown street at dusk (#3b2321 to #5c302a) with dark ruined rooftops; zombie skin muted green-grey (#8ea476, shade #62774f), small glowing pale-yellow eyes (#f4ea9c), torn clothes in desaturated browns, blues and greys. Blood red (#e2574c) only as a thin rim light and in the sky glow.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a big or muscular body, an open mouth with teeth bared at the viewer, a second zombie.

### Image 2: Lurcher (values 4-6)

**File:** `dd_zombie_lurcher.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one wiry zombie in torn jeans and a hoodie lunging hard forward to the right, both arms out grabbing, knees bent, mid-stride, full body visible.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: zombie card. Backdrop a dusky blood-red to brown street at dusk (#3b2321 to #5c302a) with dark ruined rooftops; zombie skin muted green-grey (#8ea476, shade #62774f), small glowing pale-yellow eyes (#f4ea9c), torn clothes in desaturated browns, blues and greys. Blood red (#e2574c) only as a thin rim light and in the sky glow.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** running like an athlete, a weapon in its hands, a second zombie.

### Image 3: Bruiser (values 7-9)

**File:** `dd_zombie_bruiser.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one broad, square-shouldered zombie road worker in a plain hard hat and a hi-vis safety vest with reflective stripes (no writing), heavy fists hanging, standing squarely, full body visible.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: zombie card. Backdrop a dusky blood-red to brown street at dusk (#3b2321 to #5c302a) with dark ruined rooftops; zombie skin muted green-grey (#8ea476, shade #62774f), small glowing pale-yellow eyes (#f4ea9c), torn clothes in desaturated browns, blues and greys. Blood red (#e2574c) only as a thin rim light and in the sky glow.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** writing or logos on the vest or helmet, tools in its hands, a second zombie.

### Image 4: Hulk (values 10+)

**File:** `dd_zombie_hulk.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one enormous hulking zombie that fills the frame: a tiny head sunk between huge shoulders, a torn work shirt, knuckles almost touching the ground, leaning towards the viewer.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: zombie card. Backdrop a dusky blood-red to brown street at dusk (#3b2321 to #5c302a) with dark ruined rooftops; zombie skin muted green-grey (#8ea476, shade #62774f), small glowing pale-yellow eyes (#f4ea9c), torn clothes in desaturated browns, blues and greys. Blood red (#e2574c) only as a thin rim light and in the sky glow.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a superhero look, muscles with veins in detail, a monster that is not human, a second zombie.

### Image 5: Boss: The Groundskeeper (Maple Row)

**File:** `dd_boss_groundskeeper.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one tall gaunt zombie groundskeeper in faded overalls and a wide-brim straw hat, holding a long garden shovel upright like a staff, a picket fence and a dark maple tree behind.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: boss card. Backdrop a deep bruise-purple night (#2c1d35 to #4a3060) with a big low pale moon; zombie skin muted green-grey, small glowing pale-yellow eyes, purple (#c27ce0) rim light.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** the shovel being swung at someone, a scythe, a skull face.

### Image 6: Boss: Rush Hour Horde (Downtown)

**File:** `dd_boss_rush_hour_horde.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: three zombie office commuters in rumpled suits and loose ties shambling forward in a tight group under a dark traffic light, the front one biggest, the two behind smaller and partly hidden, one clutching a plain briefcase.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: boss card. Backdrop a deep bruise-purple night (#2c1d35 to #4a3060) with a big low pale moon; zombie skin muted green-grey, small glowing pale-yellow eyes, purple (#c27ce0) rim light.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** more than three zombies, readable signs or a lit traffic light colour, a bus with writing.

### Image 7: Boss: Patient Zero, phase 1 (value 8)

**File:** `dd_boss_patient_zero_1.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one pale, very thin zombie patient in a plain hospital gown, standing very still and leaning on a rolling IV drip stand, head tilted, staring, plain striped quarantine tape (no writing) behind.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: boss card. Backdrop a deep bruise-purple night (#2c1d35 to #4a3060) with a big low pale moon; zombie skin muted green-grey, small glowing pale-yellow eyes, purple (#c27ce0) rim light.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a red cross, writing on the tape, needles in close-up.

### Image 8: Boss: Patient Zero, phase 2 (value 10)

**File:** `dd_boss_patient_zero_2.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: the same pale zombie patient in a torn hospital gown, the IV stand knocked over at its feet, both arms raised and reaching, mouth open in a silent howl, a flickering teal ceiling light.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: boss card. Backdrop a deep bruise-purple night (#2c1d35 to #4a3060) with a big low pale moon; zombie skin muted green-grey, small glowing pale-yellow eyes, purple (#c27ce0) rim light.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a red cross, gore, a different character design from phase 1.

### Image 9: Boss: Patient Zero, phase 3 (value 12)

**File:** `dd_boss_patient_zero_3.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: the same zombie patient now swollen and hulking, the gown in shreds, glowing violet veins on the arms and neck, hunched forward, filling the frame, purple light rising from below.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: boss card. Backdrop a deep bruise-purple night (#2c1d35 to #4a3060) with a big low pale moon; zombie skin muted green-grey, small glowing pale-yellow eyes, purple (#c27ce0) rim light.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a red cross, gore, tentacles, a non-human monster.


---

## Batch 2: Guns

Guns are the heart of the game. Each must be told apart by silhouette alone.

### Image 10: Service Pistol (the starting gun)

**File:** `dd_gun_service_pistol.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one plain, boxy, compact pistol with a worn grip, lying on its side at a shallow upward tilt from lower left to upper right, seen from the side.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. Backdrop a dark slate steel-blue workshop wall (#1f2e3a to #2e4a5f) with a faint pegboard of round holes; the gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge of the gun from the key light. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm model.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** chrome, gold, laser sights. Real gun brands or models, writing or serial numbers, a hand.

### Image 11: Hunting Rifle

**File:** `dd_gun_hunting_rifle.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one long wooden-stocked bolt-action hunting rifle with a short scope, lying on its side at a shallow upward tilt from lower left to upper right, seen from the side.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. Backdrop a dark slate steel-blue workshop wall (#1f2e3a to #2e4a5f) with a faint pegboard of round holes; the gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge of the gun from the key light. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm model.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** camouflage, a bipod. Real gun brands or models, writing or serial numbers, a hand.

### Image 12: Ratchet Crossbow

**File:** `dd_gun_ratchet_crossbow.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one homemade crossbow made from a wooden stock, a bent leaf-spring bow and a hand-crank ratchet, one bolt loaded, seen slightly from above so the bow shape reads, lying on its side at a shallow upward tilt from lower left to upper right, seen from the side.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. Backdrop a dark slate steel-blue workshop wall (#1f2e3a to #2e4a5f) with a faint pegboard of round holes; the gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge of the gun from the key light. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm model.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a fantasy or medieval crossbow, glowing parts. Real gun brands or models, writing or serial numbers, a hand.

### Image 13: Twin-Bore

**File:** `dd_gun_twin_bore.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one short over-and-under double-barrel shotgun with a wooden stock, the two stacked barrel mouths clearly visible, lying on its side at a shallow upward tilt from lower left to upper right, seen from the side.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. Backdrop a dark slate steel-blue workshop wall (#1f2e3a to #2e4a5f) with a faint pegboard of round holes; the gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge of the gun from the key light. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm model.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** side-by-side barrels, engraving. Real gun brands or models, writing or serial numbers, a hand.

### Image 14: Lever Rifle

**File:** `dd_gun_lever_rifle.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one frontier-style lever-action rifle with a dull brass receiver and a big loop lever under it, lying on its side at a shallow upward tilt from lower left to upper right, seen from the side.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. Backdrop a dark slate steel-blue workshop wall (#1f2e3a to #2e4a5f) with a faint pegboard of round holes; the gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge of the gun from the key light. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm model.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a scope, a western cowboy scene. Real gun brands or models, writing or serial numbers, a hand.

### Image 15: Scout Carbine

**File:** `dd_gun_scout_carbine.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one short, light carbine with a simple folding stock, a slim magazine and a small round sight, lying on its side at a shallow upward tilt from lower left to upper right, seen from the side.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. Backdrop a dark slate steel-blue workshop wall (#1f2e3a to #2e4a5f) with a faint pegboard of round holes; the gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge of the gun from the key light. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm model.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a military assault rifle look, rails full of attachments. Real gun brands or models, writing or serial numbers, a hand.

### Image 16: Nail Driver

**File:** `dd_gun_nail_driver.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one bright orange construction nail gun (a tool, not a firearm) with a coiled air hose and a strip of nails, lying on its side at a shallow upward tilt from lower left to upper right, seen from the side.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. Backdrop a dark slate steel-blue workshop wall (#1f2e3a to #2e4a5f) with a faint pegboard of round holes; the gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge of the gun from the key light. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm model.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** brand colours or logos, a firearm shape. Real gun brands or models, writing or serial numbers, a hand.

### Image 17: Pump Shotgun

**File:** `dd_gun_pump_shotgun.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one sturdy pump-action shotgun with a dark wooden pump grip and a thick single barrel, lying on its side at a shallow upward tilt from lower left to upper right, seen from the side.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. Backdrop a dark slate steel-blue workshop wall (#1f2e3a to #2e4a5f) with a faint pegboard of round holes; the gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge of the gun from the key light. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm model.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a sawn-off barrel, a drum magazine. Real gun brands or models, writing or serial numbers, a hand.

### Image 18: Elephant Gun

**File:** `dd_gun_elephant_gun.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one huge, heavy old big-game rifle with a long thick barrel and a dark wooden stock, the biggest gun of all, with one oversized brass cartridge standing upright beside it, lying on its side at a shallow upward tilt from lower left to upper right, seen from the side.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. Backdrop a dark slate steel-blue workshop wall (#1f2e3a to #2e4a5f) with a faint pegboard of round holes; the gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge of the gun from the key light. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm model.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** an animal, a safari scene. Real gun brands or models, writing or serial numbers, a hand.

### Image 19: Stovepipe Launcher

**File:** `dd_gun_stovepipe_launcher.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one homemade one-shot launcher made from a dented stovepipe tube strapped to a wooden handle with hose clamps, a fat round homemade projectile sticking out of the front, lying on its side at a shallow upward tilt from lower left to upper right, seen from the side.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. Backdrop a dark slate steel-blue workshop wall (#1f2e3a to #2e4a5f) with a faint pegboard of round holes; the gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge of the gun from the key light. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm model.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a military rocket launcher, fire or an explosion. Real gun brands or models, writing or serial numbers, a hand.

### Image 20: Alley Sweeper

**File:** `dd_gun_alley_sweeper.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one stubby wide-mouthed blunderbuss-like scattergun built from plumbing pipe and a broom-handle stock, a flared funnel muzzle, lying on its side at a shallow upward tilt from lower left to upper right, seen from the side.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. Backdrop a dark slate steel-blue workshop wall (#1f2e3a to #2e4a5f) with a faint pegboard of round holes; the gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge of the gun from the key light. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm model.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a pirate theme, a real shotgun model. Real gun brands or models, writing or serial numbers, a hand.


---

## Batch 3: Melee weapons and items

The everyday cards: one big object each, power reads from heft.

### Image 21: Bare Hands (no melee weapon)

**File:** `dd_melee_bare_hands.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: two clenched fists wrapped in grey duct tape, raised in a boxer's guard, seen from the front at chest height, only the forearms visible.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: melee card. Backdrop a dark warm workshop wall (#2a2420) with a faint pegboard of round holes; the tool in steel, worn wood and rubber grip tape; a hot yellow (#f2c14e) highlight along its top edge from the key light; copper (#d9a066) as the second accent. Nobody holding it.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a face or body, brass knuckles, blood.

### Image 22: Pipe Wrench

**File:** `dd_melee_pipe_wrench.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one heavy red-handled pipe wrench, big adjustable jaw, lying diagonally from lower left to upper right.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: melee card. Backdrop a dark warm workshop wall (#2a2420) with a faint pegboard of round holes; the tool in steel, worn wood and rubber grip tape; a hot yellow (#f2c14e) highlight along its top edge from the key light; copper (#d9a066) as the second accent. Nobody holding it.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** rust so heavy it looks broken. A hand holding it, writing or brand marks.

### Image 23: Fire Axe

**File:** `dd_melee_fire_axe.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one fire axe with a red-painted steel head and a long wooden handle, lying diagonally from lower left to upper right.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: melee card. Backdrop a dark warm workshop wall (#2a2420) with a faint pegboard of round holes; the tool in steel, worn wood and rubber grip tape; a hot yellow (#f2c14e) highlight along its top edge from the key light; copper (#d9a066) as the second accent. Nobody holding it.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a battle axe or double blade. A hand holding it, writing or brand marks.

### Image 24: Sledgehammer

**File:** `dd_melee_sledgehammer.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one huge sledgehammer with a wide square steel head and a long wooden handle with taped grip, lying diagonally from lower left to upper right.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: melee card. Backdrop a dark warm workshop wall (#2a2420) with a faint pegboard of round holes; the tool in steel, worn wood and rubber grip tape; a hot yellow (#f2c14e) highlight along its top edge from the key light; copper (#d9a066) as the second accent. Nobody holding it.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a fantasy war hammer. A hand holding it, writing or brand marks.

### Image 25: Bandage (heal 1-3)

**File:** `dd_item_bandage.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one roll of white gauze bandage partly unrolled beside a couple of plain sticking plasters.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: heal card. Backdrop a dark clinic green (#1d3325 to #2b4d37) with a faint pattern of plus shapes; medical items in off-white (#ece6d6) and soft greens; any medical symbol is a GREEN or WHITE plus, never a red cross.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a red cross, blood, a wound.

### Image 26: First Aid Kit (heal 4-5)

**File:** `dd_item_first_aid_kit.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one sturdy off-white first aid box with a carry handle and a big green plus on the lid, lid closed.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: heal card. Backdrop a dark clinic green (#1d3325 to #2b4d37) with a faint pattern of plus shapes; medical items in off-white (#ece6d6) and soft greens; any medical symbol is a GREEN or WHITE plus, never a red cross.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a red cross, writing on the box.

### Image 27: Trauma Kit (heal 6+)

**File:** `dd_item_trauma_kit.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one large olive canvas medical bag, half open, with a green plus patch, rolled bandages and a tourniquet strap spilling out.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: heal card. Backdrop a dark clinic green (#1d3325 to #2b4d37) with a faint pattern of plus shapes; medical items in off-white (#ece6d6) and soft greens; any medical symbol is a GREEN or WHITE plus, never a red cross.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a red cross, syringes in close-up, blood.

### Image 28: Plywood (cover 2)

**File:** `dd_cover_plywood.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: two sheets of plywood nailed across each other into a makeshift barricade, a big spray-painted X across them (just two strokes, no letters).
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: cover card. Backdrop a dark amber brick wall at night (#37301d to #56472a); the barricade in worn wood, dented paint and steel; gold (#e0b04a) hazard accents and a warm gold rim light.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** letters or words, a person behind it.

### Image 29: Car Door (cover 3)

**File:** `dd_cover_car_door.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one dented car door torn off a car and propped upright as a shield, window cracked, a few rivets of wire holding it up.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: cover card. Backdrop a dark amber brick wall at night (#37301d to #56472a); the barricade in worn wood, dented paint and steel; gold (#e0b04a) hazard accents and a warm gold rim light.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a car brand, a number plate, a whole car.

### Image 30: Dumpster (cover 4)

**File:** `dd_cover_dumpster.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one heavy dented steel dumpster pushed across the street as a wall, gold and black hazard stripes on its side, lid shut.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: cover card. Backdrop a dark amber brick wall at night (#37301d to #56472a); the barricade in worn wood, dented paint and steel; gold (#e0b04a) hazard accents and a warm gold rim light.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** writing on the dumpster, rubbish spilling out, a person.


---

## Batch 4: Rooms and machines

Rooms are doors on the top row of the street (locked with a price until bought). Once opened, the room tile shows its machine.

### Image 31: Entrance door (Maple Row)

**File:** `dd_room_maple_row_entrance.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: the front gate of a quiet suburban street: a white picket gate between two hedges, a mailbox with no writing, a maple tree.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
District look: Maple Row, a quiet suburb at dusk: orange-pink sky, painted wood siding and old brick, maple leaves, warm porch light.
Composition: full-bleed painting, no border. One storefront or doorway seen straight on, the door centred and filling the middle 60% of the width and most of the height. The very centre of the door must be a plain, flat, mid-dark surface (a price tag with a padlock is laid over it in the game). Keep the bottom 15% simple ground: the room name goes there. The door is shut.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Readable signs or shop names, people, an open door, bright light in the middle of the door.

### Image 32: Garage door (Maple Row)

**File:** `dd_room_maple_row_garage.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a suburban house garage with a closed ribbed roll-up door, a small lamp above it and an oil stain on the driveway.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
District look: Maple Row, a quiet suburb at dusk: orange-pink sky, painted wood siding and old brick, maple leaves, warm porch light.
Composition: full-bleed painting, no border. One storefront or doorway seen straight on, the door centred and filling the middle 60% of the width and most of the height. The very centre of the door must be a plain, flat, mid-dark surface (a price tag with a padlock is laid over it in the game). Keep the bottom 15% simple ground: the room name goes there. The door is shut.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Readable signs or shop names, people, an open door, bright light in the middle of the door.

### Image 33: Corner Store door (Maple Row)

**File:** `dd_room_maple_row_corner_store.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a small corner shop front with a striped awning, a dark shop window and a shut glass door with a blank paper sign.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
District look: Maple Row, a quiet suburb at dusk: orange-pink sky, painted wood siding and old brick, maple leaves, warm porch light.
Composition: full-bleed painting, no border. One storefront or doorway seen straight on, the door centred and filling the middle 60% of the width and most of the height. The very centre of the door must be a plain, flat, mid-dark surface (a price tag with a padlock is laid over it in the game). Keep the bottom 15% simple ground: the room name goes there. The door is shut.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Readable signs or shop names, people, an open door, bright light in the middle of the door.

### Image 34: Workshop door (Maple Row)

**File:** `dd_room_maple_row_workshop.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a wooden shed workshop with double plank doors, a round saw blade hung above them, sawdust on the step.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
District look: Maple Row, a quiet suburb at dusk: orange-pink sky, painted wood siding and old brick, maple leaves, warm porch light.
Composition: full-bleed painting, no border. One storefront or doorway seen straight on, the door centred and filling the middle 60% of the width and most of the height. The very centre of the door must be a plain, flat, mid-dark surface (a price tag with a padlock is laid over it in the game). Keep the bottom 15% simple ground: the room name goes there. The door is shut.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Readable signs or shop names, people, an open door, bright light in the middle of the door.

### Image 35: Entrance door (Downtown)

**File:** `dd_room_downtown_entrance.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a downtown street corner blocked by a stalled city bus (plain, no writing) and orange traffic cones, a dark doorway between them.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
District look: Downtown at night: dark brick and concrete, wet asphalt reflecting sodium-orange street light, cold blue shadows.
Composition: full-bleed painting, no border. One storefront or doorway seen straight on, the door centred and filling the middle 60% of the width and most of the height. The very centre of the door must be a plain, flat, mid-dark surface (a price tag with a padlock is laid over it in the game). Keep the bottom 15% simple ground: the room name goes there. The door is shut.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Readable signs or shop names, people, an open door, bright light in the middle of the door.

### Image 36: Subway Kiosk door (Downtown)

**File:** `dd_room_downtown_subway_kiosk.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a small green metal subway newsstand kiosk with its shutter half down, stairs going down beside it into darkness.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
District look: Downtown at night: dark brick and concrete, wet asphalt reflecting sodium-orange street light, cold blue shadows.
Composition: full-bleed painting, no border. One storefront or doorway seen straight on, the door centred and filling the middle 60% of the width and most of the height. The very centre of the door must be a plain, flat, mid-dark surface (a price tag with a padlock is laid over it in the game). Keep the bottom 15% simple ground: the room name goes there. The door is shut.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Readable signs or shop names, people, an open door, bright light in the middle of the door.

### Image 37: Pawn Shop door (Downtown)

**File:** `dd_room_downtown_pawn_shop.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a narrow pawn shop front with a heavy barred door, three plain brass balls hanging above, a dark window full of shapes of old guitars and clocks.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
District look: Downtown at night: dark brick and concrete, wet asphalt reflecting sodium-orange street light, cold blue shadows.
Composition: full-bleed painting, no border. One storefront or doorway seen straight on, the door centred and filling the middle 60% of the width and most of the height. The very centre of the door must be a plain, flat, mid-dark surface (a price tag with a padlock is laid over it in the game). Keep the bottom 15% simple ground: the room name goes there. The door is shut.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Readable signs or shop names, people, an open door, bright light in the middle of the door.

### Image 38: Parking Garage door (Downtown)

**File:** `dd_room_downtown_parking_garage.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: the concrete entrance of a multi-storey car park, a striped barrier arm down across it, a flickering ceiling light inside.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
District look: Downtown at night: dark brick and concrete, wet asphalt reflecting sodium-orange street light, cold blue shadows.
Composition: full-bleed painting, no border. One storefront or doorway seen straight on, the door centred and filling the middle 60% of the width and most of the height. The very centre of the door must be a plain, flat, mid-dark surface (a price tag with a padlock is laid over it in the game). Keep the bottom 15% simple ground: the room name goes there. The door is shut.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Readable signs or shop names, people, an open door, bright light in the middle of the door.

### Image 39: Entrance door (St. Agnes Hospital)

**File:** `dd_room_st_agnes_entrance.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: the ambulance bay doors of an old hospital, a pair of frosted sliding doors, a parked plain ambulance with no writing and no red cross.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
District look: St. Agnes Hospital at night: pale green-white tiles, sickly teal fluorescent light, quarantine tape (plain, no writing).
Composition: full-bleed painting, no border. One storefront or doorway seen straight on, the door centred and filling the middle 60% of the width and most of the height. The very centre of the door must be a plain, flat, mid-dark surface (a price tag with a padlock is laid over it in the game). Keep the bottom 15% simple ground: the room name goes there. The door is shut.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Readable signs or shop names, people, an open door, bright light in the middle of the door.

### Image 40: Pharmacy door (St. Agnes Hospital)

**File:** `dd_room_st_agnes_pharmacy.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a hospital pharmacy hatch with a metal roller shutter pulled down and a green plus lamp above it (unlit).
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
District look: St. Agnes Hospital at night: pale green-white tiles, sickly teal fluorescent light, quarantine tape (plain, no writing).
Composition: full-bleed painting, no border. One storefront or doorway seen straight on, the door centred and filling the middle 60% of the width and most of the height. The very centre of the door must be a plain, flat, mid-dark surface (a price tag with a padlock is laid over it in the game). Keep the bottom 15% simple ground: the room name goes there. The door is shut.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Readable signs or shop names, people, an open door, bright light in the middle of the door.

### Image 41: Security Office door (St. Agnes Hospital)

**File:** `dd_room_st_agnes_security_office.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a steel security office door with a small wired-glass window, a row of dark CCTV monitors glowing faintly blue behind the glass.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
District look: St. Agnes Hospital at night: pale green-white tiles, sickly teal fluorescent light, quarantine tape (plain, no writing).
Composition: full-bleed painting, no border. One storefront or doorway seen straight on, the door centred and filling the middle 60% of the width and most of the height. The very centre of the door must be a plain, flat, mid-dark surface (a price tag with a padlock is laid over it in the game). Keep the bottom 15% simple ground: the room name goes there. The door is shut.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Readable signs or shop names, people, an open door, bright light in the middle of the door.

### Image 42: Morgue Lab door (St. Agnes Hospital)

**File:** `dd_room_st_agnes_morgue_lab.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a pair of heavy swing doors with round porthole windows and rubber kick plates, cold blue light behind them, quarantine tape across (no writing).
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
District look: St. Agnes Hospital at night: pale green-white tiles, sickly teal fluorescent light, quarantine tape (plain, no writing).
Composition: full-bleed painting, no border. One storefront or doorway seen straight on, the door centred and filling the middle 60% of the width and most of the height. The very centre of the door must be a plain, flat, mid-dark surface (a price tag with a padlock is laid over it in the game). Keep the bottom 15% simple ground: the room name goes there. The door is shut.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Readable signs or shop names, people, an open door, bright light in the middle of the door.

### Image 43: Retrofit Bench

**File:** `dd_machine_retrofit_bench.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: a grimy workbench with a hand-cranked lathe, a vice, scattered gun parts and tools, one lamp over it.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: workshop machine. Backdrop a dim tiled workshop wall (#22282c) with copper (#d9a066) lamp light; the machine in rusty steel, copper and painted enamel.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a firearm being assembled in hands, writing.

### Image 44: Patch Press

**File:** `dd_machine_patch_press.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: a rusty clamshell heat press on a bench, its top plate raised and glowing faintly orange, one blank round cloth patch on the lower plate, spools of thread beside it.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: workshop machine. Backdrop a dim tiled workshop wall (#22282c) with copper (#d9a066) lamp light; the machine in rusty steel, copper and painted enamel.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a drinks machine, writing on the dial.

### Image 45: Wall Rack (empty)

**File:** `dd_machine_wall_rack.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: an empty wooden gun rack on a pegboard wall, two hooks and a chalk outline where a long gun used to hang.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: workshop machine. Backdrop a dim tiled workshop wall (#22282c) with copper (#d9a066) lamp light; the machine in rusty steel, copper and painted enamel.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a gun on the rack, writing.

### Image 46: Wall Rack: Ratchet Crossbow

**File:** `dd_machine_wall_rack_crossbow.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: a wooden rack on a pegboard wall with one homemade crossbow (wooden stock, leaf-spring bow, hand-crank ratchet) hanging on two hooks.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: workshop machine. Backdrop a dim tiled workshop wall (#22282c) with copper (#d9a066) lamp light; the machine in rusty steel, copper and painted enamel.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a fantasy crossbow, writing, a price tag with numbers.

### Image 47: Wall Rack: Pump Shotgun

**File:** `dd_machine_wall_rack_shotgun.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: a wooden rack on a pegboard wall with one made-up pump-action shotgun with a dark wooden pump grip hanging on two hooks.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: workshop machine. Backdrop a dim tiled workshop wall (#22282c) with copper (#d9a066) lamp light; the machine in rusty steel, copper and painted enamel.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** real gun brands, writing, a price tag with numbers.

### Image 48: Wall Rack: Elephant Gun

**File:** `dd_machine_wall_rack_elephant_gun.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: a wooden rack on a pegboard wall with one huge old big-game rifle hanging on two hooks, a single oversized brass cartridge on a small shelf below.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: workshop machine. Backdrop a dim tiled workshop wall (#22282c) with copper (#d9a066) lamp light; the machine in rusty steel, copper and painted enamel.
Composition: full-bleed painting, no border or frame. The subject sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** an animal trophy, writing, a price tag with numbers.


---

## Batch 5: City, survivors, card backs and title

The screens around the street.

### Image 49: District banner: Maple Row

**File:** `dd_district_maple_row.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: a quiet suburban street at dusk: little wooden houses with dark windows, picket fences, a big orange maple tree, a few zombie silhouettes far away under a low orange sun.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
District look: Maple Row, a quiet suburb at dusk: orange-pink sky, painted wood siding and old brick, maple leaves, warm porch light.
Composition: a wide street panorama. The game crops a thin horizontal band from 30% to 62% of the height and lays a district name over the bottom-left of that band and a boss portrait on its left edge, so put the landmarks in that band, centre to right, with a calm left 25%. No people.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Readable signs, close-up zombies, a bright sky that hides the text.

### Image 50: District banner: Downtown

**File:** `dd_district_downtown.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: a downtown street at night: dark office towers with a few lit windows, a stalled city bus, a dead traffic light, wet asphalt.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
District look: Downtown at night: dark brick and concrete, wet asphalt reflecting sodium-orange street light, cold blue shadows.
Composition: a wide street panorama. The game crops a thin horizontal band from 30% to 62% of the height and lays a district name over the bottom-left of that band and a boss portrait on its left edge, so put the landmarks in that band, centre to right, with a calm left 25%. No people.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Readable signs, billboards, neon, close-up zombies.

### Image 51: District banner: St. Agnes Hospital

**File:** `dd_district_st_agnes.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: an old hospital block at night with a dark green plus sign (unlit) on the roof, an ambulance parked out front, a chain-link quarantine fence.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
District look: St. Agnes Hospital at night: pale green-white tiles, sickly teal fluorescent light, quarantine tape (plain, no writing).
Composition: a wide street panorama. The game crops a thin horizontal band from 30% to 62% of the height and lays a district name over the bottom-left of that band and a boss portrait on its left edge, so put the landmarks in that band, centre to right, with a calm left 25%. No people.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** A red cross, writing, close-up zombies.

### Image 52: Survivor: Rosa Vance (mechanic)

**File:** `dd_survivor_rosa.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a tough woman mechanic in her thirties, teal bandana, oil-stained coveralls, a small plaster on her cheek, a pipe wrench resting on her shoulder, a confident half smile.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: warm skin tones, teal and rust, warm gold (#f0d27a) rim light.
Composition: head-and-shoulders bust, face centred slightly above the middle, looking at the viewer, on a simple dark painted backdrop with a soft glow behind the head. The game shows it in a circle, so keep the face and shoulders inside the central 70% circle.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** A real person's likeness, writing on the coveralls, a gun.

### Image 53: Survivor: Dr. Imani Hale (medic)

**File:** `dd_survivor_imani.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a calm woman doctor in her forties with short natural hair in scrubs, round glasses, a stethoscope round her neck, a green plus badge on her chest, steady look.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: warm skin tones, scrubs in soft green, warm gold (#f0d27a) rim light.
Composition: head-and-shoulders bust, face centred slightly above the middle, looking at the viewer, on a simple dark painted backdrop with a soft glow behind the head. The game shows it in a circle, so keep the face and shoulders inside the central 70% circle.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** A real person's likeness, a red cross, writing.

### Image 54: Survivor: Theo Park (courier)

**File:** `dd_survivor_theo.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a quick young man, a bike courier, in his twenties, an amber cap turned backwards, a windbreaker, a messenger bag strap across the chest, a grin.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: warm skin tones, amber and slate blue, warm gold (#f0d27a) rim light.
Composition: head-and-shoulders bust, face centred slightly above the middle, looking at the viewer, on a simple dark painted backdrop with a soft glow behind the head. The game shows it in a circle, so keep the face and shoulders inside the central 70% circle.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** A real person's likeness, brand logos on the cap or bag.

### Image 55: Card back: draw pile

**File:** `dd_back_pile.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1536 (portrait 2:3).
Subject: the back of a playing card: a single rotting zombie hand rising through two crossed wooden boards at the centre, a fine diagonal hatch pattern, a double border in bone white and blood red.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: near-black (#151214), bone white (#ece6d6), blood red (#e2574c).
Composition: a symmetrical card-back design, centred emblem inside a simple painted border inset 4% from the edges, full-bleed dark background. The game shows a count number over the top-left, so keep the top-left 25% plain.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers, a skull, a face.

### Image 56: Card back: wave deck

**File:** `dd_back_wave.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1536 (portrait 2:3).
Subject: the back of a playing card: a low full moon over a row of zombie hands reaching up from the ground, a dark blood-red field, a bone-white border.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: deep blood red (#3b2321 to #e2574c), bone white, a pale moon.
Composition: a symmetrical card-back design, centred emblem inside a simple painted border inset 4% from the edges, full-bleed dark background. The game shows a count number over the top-left, so keep the top-left 25% plain.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers, gore.

### Image 57: Card back: room deck

**File:** `dd_back_room.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1536 (portrait 2:3).
Subject: the back of a playing card: a closed wooden door in a slate brick wall with a blank paper price tag and an old key hanging from its handle, a slate-grey border.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: slate grey (#22282c), worn brass, bone white.
Composition: a symmetrical card-back design, centred emblem inside a simple painted border inset 4% from the edges, full-bleed dark background. The game shows a count number over the top-left, so keep the top-left 25% plain.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the tag.

### Image 58: Title screen (phone, portrait)

**File:** `dd_title_portrait.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1536 (portrait 2:3).
Subject: three survivors seen from behind (a mechanic with a pipe wrench, a doctor with a medical bag, a courier with a messenger bag), standing on a street at the edge of a suburb at dusk, looking towards a city skyline where a crowd of zombie silhouettes shambles towards them; a giant playing card lies face down on the road in front of them.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: dusk orange sky fading to deep purple night, zombie silhouettes in muted green-grey, warm street light on the survivors.
Composition: key art for a phone title screen. Leave the top 30% calm night sky (the game logo is drawn there in code) and the bottom 30% dark and simple (buttons go there). The scene sits in the middle 40%.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Text or a logo, faces of real people, guns being fired.

### Image 59: Title screen (desktop, landscape)

**File:** `dd_title_landscape.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: the same scene: three survivors seen from behind on a street at dusk facing a crowd of zombie silhouettes in front of a city skyline and a hospital block, a giant playing card face down on the road.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: dusk orange sky fading to deep purple night, zombie silhouettes in muted green-grey, warm street light on the survivors.
Composition: key art for a desktop title screen. Leave the left 40% calm and dark (the game logo and buttons go there); the scene sits on the right 60%.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Text or a logo, faces of real people, guns being fired.


---

## Batch 6: Patches

Permanent run upgrades, shown small next to HP and large in offers. Same badge shape every time; the rim colour and symbol tell them apart.

### Image 60: Patch: Lookout

**File:** `dd_patch_lookout.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a round embroidered patch showing a pair of binoculars.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Look: an embroidered cloth patch: a thick twill rim with visible satin stitching, a stitched inner ring, a woven cloth field, the symbol in raised satin thread with a slight sheen, painted in the same bold comic style. Rim colour: sky blue; field dark charcoal; symbol in bone white plus one accent colour.
Composition: a single round emblem centred, filling 85% of the image, on a fully transparent background (PNG with alpha). Nothing outside the circle. It must read at 40 pixels wide: one central object, thick outline, no fine detail.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the patch, more than one symbol, a square shape.

### Image 61: Patch: Thick Jacket

**File:** `dd_patch_thick_jacket.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a round embroidered patch showing a padded quilted jacket.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Look: an embroidered cloth patch: a thick twill rim with visible satin stitching, a stitched inner ring, a woven cloth field, the symbol in raised satin thread with a slight sheen, painted in the same bold comic style. Rim colour: slate blue; field dark charcoal; symbol in bone white plus one accent colour.
Composition: a single round emblem centred, filling 85% of the image, on a fully transparent background (PNG with alpha). Nothing outside the circle. It must read at 40 pixels wide: one central object, thick outline, no fine detail.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the patch, more than one symbol, a square shape.

### Image 62: Patch: Field Medic

**File:** `dd_patch_field_medic.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a round embroidered patch showing a green-and-white plus with a rolled bandage.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Look: an embroidered cloth patch: a thick twill rim with visible satin stitching, a stitched inner ring, a woven cloth field, the symbol in raised satin thread with a slight sheen, painted in the same bold comic style. Rim colour: clinic green; field dark charcoal; symbol in bone white plus one accent colour.
Composition: a single round emblem centred, filling 85% of the image, on a fully transparent background (PNG with alpha). Nothing outside the circle. It must read at 40 pixels wide: one central object, thick outline, no fine detail.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the patch, more than one symbol, a square shape.

### Image 63: Patch: Brawler

**File:** `dd_patch_brawler.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a round embroidered patch showing a fist wrapped in tape.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Look: an embroidered cloth patch: a thick twill rim with visible satin stitching, a stitched inner ring, a woven cloth field, the symbol in raised satin thread with a slight sheen, painted in the same bold comic style. Rim colour: copper orange; field dark charcoal; symbol in bone white plus one accent colour.
Composition: a single round emblem centred, filling 85% of the image, on a fully transparent background (PNG with alpha). Nothing outside the circle. It must read at 40 pixels wide: one central object, thick outline, no fine detail.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the patch, more than one symbol, a square shape.

### Image 64: Patch: Bounty Hunter

**File:** `dd_patch_bounty.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a round embroidered patch showing a gold star with two short ribbons.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Look: an embroidered cloth patch: a thick twill rim with visible satin stitching, a stitched inner ring, a woven cloth field, the symbol in raised satin thread with a slight sheen, painted in the same bold comic style. Rim colour: gold; field dark charcoal; symbol in bone white plus one accent colour.
Composition: a single round emblem centred, filling 85% of the image, on a fully transparent background (PNG with alpha). Nothing outside the circle. It must read at 40 pixels wide: one central object, thick outline, no fine detail.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the patch, more than one symbol, a square shape.

### Image 65: Patch: Loose Grip

**File:** `dd_patch_loose_grip.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a round embroidered patch showing an arrow bending over a short bar.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Look: an embroidered cloth patch: a thick twill rim with visible satin stitching, a stitched inner ring, a woven cloth field, the symbol in raised satin thread with a slight sheen, painted in the same bold comic style. Rim colour: violet; field dark charcoal; symbol in bone white plus one accent colour.
Composition: a single round emblem centred, filling 85% of the image, on a fully transparent background (PNG with alpha). Nothing outside the circle. It must read at 40 pixels wide: one central object, thick outline, no fine detail.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the patch, more than one symbol, a square shape.

### Image 66: Patch: Second Wind

**File:** `dd_patch_second_wind.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a round embroidered patch showing a heart with three swirling wind lines.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Look: an embroidered cloth patch: a thick twill rim with visible satin stitching, a stitched inner ring, a woven cloth field, the symbol in raised satin thread with a slight sheen, painted in the same bold comic style. Rim colour: rose pink; field dark charcoal; symbol in bone white plus one accent colour.
Composition: a single round emblem centred, filling 85% of the image, on a fully transparent background (PNG with alpha). Nothing outside the circle. It must read at 40 pixels wide: one central object, thick outline, no fine detail.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the patch, more than one symbol, a square shape.

### Image 67: Patch: Trophy Belt

**File:** `dd_patch_trophy_belt.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a round embroidered patch showing a big brass belt buckle with a small trophy cup on it.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Look: an embroidered cloth patch: a thick twill rim with visible satin stitching, a stitched inner ring, a woven cloth field, the symbol in raised satin thread with a slight sheen, painted in the same bold comic style. Rim colour: brass; field dark charcoal; symbol in bone white plus one accent colour.
Composition: a single round emblem centred, filling 85% of the image, on a fully transparent background (PNG with alpha). Nothing outside the circle. It must read at 40 pixels wide: one central object, thick outline, no fine detail.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the patch, more than one symbol, a square shape.

### Image 68: Patch: Lockpick

**File:** `dd_patch_lockpick.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a round embroidered patch showing an old key and a bent lockpick crossed over a padlock.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Look: an embroidered cloth patch: a thick twill rim with visible satin stitching, a stitched inner ring, a woven cloth field, the symbol in raised satin thread with a slight sheen, painted in the same bold comic style. Rim colour: steel grey; field dark charcoal; symbol in bone white plus one accent colour.
Composition: a single round emblem centred, filling 85% of the image, on a fully transparent background (PNG with alpha). Nothing outside the circle. It must read at 40 pixels wide: one central object, thick outline, no fine detail.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the patch, more than one symbol, a square shape.

### Image 69: Patch: Iron Stomach

**File:** `dd_patch_iron_stomach.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a round embroidered patch showing a tin can with a bite taken out of it.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Look: an embroidered cloth patch: a thick twill rim with visible satin stitching, a stitched inner ring, a woven cloth field, the symbol in raised satin thread with a slight sheen, painted in the same bold comic style. Rim colour: olive green; field dark charcoal; symbol in bone white plus one accent colour.
Composition: a single round emblem centred, filling 85% of the image, on a fully transparent background (PNG with alpha). Nothing outside the circle. It must read at 40 pixels wide: one central object, thick outline, no fine detail.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the patch, more than one symbol, a square shape.

### Image 70: Patch: Adrenaline

**File:** `dd_patch_adrenaline.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a round embroidered patch showing a lightning bolt over a heartbeat line.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Look: an embroidered cloth patch: a thick twill rim with visible satin stitching, a stitched inner ring, a woven cloth field, the symbol in raised satin thread with a slight sheen, painted in the same bold comic style. Rim colour: hot orange; field dark charcoal; symbol in bone white plus one accent colour.
Composition: a single round emblem centred, filling 85% of the image, on a fully transparent background (PNG with alpha). Nothing outside the circle. It must read at 40 pixels wide: one central object, thick outline, no fine detail.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the patch, more than one symbol, a square shape.

### Image 71: Patch: Grudge

**File:** `dd_patch_grudge.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a round embroidered patch showing a clenched fist over a crossed-out zombie hand.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Look: an embroidered cloth patch: a thick twill rim with visible satin stitching, a stitched inner ring, a woven cloth field, the symbol in raised satin thread with a slight sheen, painted in the same bold comic style. Rim colour: blood red; field dark charcoal; symbol in bone white plus one accent colour.
Composition: a single round emblem centred, filling 85% of the image, on a fully transparent background (PNG with alpha). Nothing outside the circle. It must read at 40 pixels wide: one central object, thick outline, no fine detail.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the patch, more than one symbol, a square shape.

### Image 72: Patch: Show-Off

**File:** `dd_patch_show_off.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a round embroidered patch showing a pistol twirling on one finger with motion lines (cartoon, no real model).
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Look: an embroidered cloth patch: a thick twill rim with visible satin stitching, a stitched inner ring, a woven cloth field, the symbol in raised satin thread with a slight sheen, painted in the same bold comic style. Rim colour: magenta; field dark charcoal; symbol in bone white plus one accent colour.
Composition: a single round emblem centred, filling 85% of the image, on a fully transparent background (PNG with alpha). Nothing outside the circle. It must read at 40 pixels wide: one central object, thick outline, no fine detail.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the patch, more than one symbol, a square shape.

### Image 73: Patch: Whetstone

**File:** `dd_patch_whetstone.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a round embroidered patch showing a sharpening stone with a blade edge and a spark.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Look: an embroidered cloth patch: a thick twill rim with visible satin stitching, a stitched inner ring, a woven cloth field, the symbol in raised satin thread with a slight sheen, painted in the same bold comic style. Rim colour: teal; field dark charcoal; symbol in bone white plus one accent colour.
Composition: a single round emblem centred, filling 85% of the image, on a fully transparent background (PNG with alpha). Nothing outside the circle. It must read at 40 pixels wide: one central object, thick outline, no fine detail.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the patch, more than one symbol, a square shape.


---

## Batch 7: Painted UI icons (only where a painted icon helps)

Rule glyphs (ANY, DOWN, UP, SAME and the rest), arrows, HP and points stay vector. These few icons sit on art-heavy tiles where a painted look fits.

### Image 74: Icon: Locked room

**File:** `dd_icon_locked.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a chunky old brass padlock hanging on a short chain over two crossed wooden boards.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: bone white (#ece6d6), near-black outline (#151214) and one accent colour as named.
Composition: one object centred, filling 80% of the image, on a fully transparent background (PNG with alpha). Must read at 24 pixels wide: chunky shape, thick dark outline, two or three flat-ish painted tones.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers, thin lines, a background.

### Image 75: Icon: Gun challenge met

**File:** `dd_icon_challenge_met.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a round gold medal on a short red ribbon with a big bone-white tick in the middle.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: bone white (#ece6d6), near-black outline (#151214) and one accent colour as named.
Composition: one object centred, filling 80% of the image, on a fully transparent background (PNG with alpha). Must read at 24 pixels wide: chunky shape, thick dark outline, two or three flat-ish painted tones.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers, thin lines, a background.

### Image 76: Icon: Gun challenge open

**File:** `dd_icon_challenge_open.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a round dull grey empty medal on a short grey ribbon, plain face.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: bone white (#ece6d6), near-black outline (#151214) and one accent colour as named.
Composition: one object centred, filling 80% of the image, on a fully transparent background (PNG with alpha). Must read at 24 pixels wide: chunky shape, thick dark outline, two or three flat-ish painted tones.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers, thin lines, a background.

### Image 77: Icon: Wave marker

**File:** `dd_icon_wave.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a single zombie hand rising out of cracked earth inside a blood-red (#e2574c) ring.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: bone white (#ece6d6), near-black outline (#151214) and one accent colour as named.
Composition: one object centred, filling 80% of the image, on a fully transparent background (PNG with alpha). Must read at 24 pixels wide: chunky shape, thick dark outline, two or three flat-ish painted tones.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers, thin lines, a background.


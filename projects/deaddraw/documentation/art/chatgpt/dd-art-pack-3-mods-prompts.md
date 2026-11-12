# DeadDraw art pack 3: Gun Mod badges, prompts for ChatGPT

**ChatGPT, read this first.** This file is a list of image requests for DeadDraw, an original zombie card game
(a street of zombie cards, guns that stack kills, melee weapons, heal and cover items, rooms behind doors, Patches,
bosses, and three districts: Maple Row, Downtown and St. Agnes Hospital). Art pack 1 painted the cards and the round
embroidered Patches; this pack paints the four **Gun Mods**, small steel-and-brass tags bolted onto a gun slot. For each
image below:
1. Generate ONE image from the text in its "Prompt" block, exactly as written. Use the size the prompt names (1024x1024).
2. Do not add any text, letters, numbers, logos, brand names, insignia or real weapon or product models to the image.
   The game draws every word and number itself.
3. Every prompt says "transparent background": output a PNG with a real alpha channel (no checkerboard, no white).
4. Give the image the file name shown on its "File" line, exactly (lowercase, `.png`).
5. If the person asks to redo an image, regenerate it and avoid what its "Avoid" line lists.
6. Keep every image in the same style (the "Shared style" block below is already inside every prompt). The four tags are
   one set: the same shield shape, the same steel field, the same brass rim and rivets, the same size and position; only
   the symbol and its accent colour change. Generate them one after the other.
7. When the batch is done, push the PNGs to the GitHub repository on the branch `art/deaddraw-pack-3`, into the folder
   `projects/deaddraw/documentation/art/chatgpt/images/art-pack-3/` (create the branch from `main` if it does not
   exist; do not touch any other folder or the `main` branch). If you cannot push, give the person the files to download
   with these exact names.

When the person says "Batch 1", generate every image in that batch, one at a time.

All art is original. Style: bold painted comic, chunky silhouettes, cartoon-level horror (never gore), one warm light.

Source: `projects/deaddraw/documentation/art/art-direction.md` (the art direction),
`projects/deaddraw/documentation/design/economy-v5.md` (section E4, the Gun Mod rules) and
`projects/deaddraw/documentation/art/art-pack-3-list.csv` (the full list with game sizes and where each image is used).

## Shared style (already part of every prompt)

```
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

Shared tag look (also already part of every prompt; only the accent colour changes):

```
Look: a gun-mod tag: a shield-shaped plate of thick brushed gunmetal steel with a flat top edge, cut corners and a pointed bottom, framed by a raised polished brass rim with four round brass rivets (one in each upper corner, one on each lower side), a slightly recessed dark steel field, the symbol stamped in raised bone-white enamel plus one accent colour, a warm brass glint along the top-right edge, painted in the same bold comic style. Accent colour: <one per mod>.
```

Colour per card type (matches the badge and frame colours in the game): yellow = guns and melee (hit), blood red = zombies,
purple = bosses, green = heal, gold = cover, copper = workshop machines. Gun Mods belong to the gun family, so their frame
is brass and steel (never a round cloth Patch).

| Batch | What | Images |
|---|---|---|
| 1 | Gun Mods | 4 |
| | **Total** | **4** |


---

## Batch 1: Gun Mods

A Gun Mod is fitted at the safehouse to gun slot 1 or 2 and changes the kill rule of every gun in that slot for the rest
of the run. The badges are shown small on the gun tile (a chip about 24 pixels tall), at about 48 pixels in the safehouse
offer row, and large in the inspect zoom. Same tag every time; the symbol and accent colour tell them apart, and each
symbol shows what the mod does.

### Image 1: Gun Mod: Open Breech (kills 1 and 2 ignore the gun's rule)

**File:** `dd_mod_open_breech.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a gun-mod tag showing a chunky break-open barrel block hinged wide open, with two fat cartridges dropping straight into the open breech from above, one behind the other; the breech mouth is wide and inviting, two short motion lines over the cartridges.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Look: a gun-mod tag: a shield-shaped plate of thick brushed gunmetal steel with a flat top edge, cut corners and a pointed bottom, framed by a raised polished brass rim with four round brass rivets (one in each upper corner, one on each lower side), a slightly recessed dark steel field, the symbol stamped in raised bone-white enamel plus one accent colour, a warm brass glint along the top-right edge, painted in the same bold comic style. Accent colour: signal green (the two cartridge tips).
Composition: a single shield-shaped tag centred and upright, filling 85% of the image, on a fully transparent background (PNG with alpha). Nothing outside the tag. It must read at 24 pixels wide: one central object, thick outline, no fine detail.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the tag, a round shape (that is the Patches), cloth or stitching, more or fewer than two cartridges, a whole gun, a closed barrel.

### Image 2: Gun Mod: Last Round (the kill that fills the gun ignores the rule)

**File:** `dd_mod_last_round.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a gun-mod tag showing a short horizontal row of four round sockets: the first three hold dull dark spent shells, and a single bright brass cartridge with a glowing hot tip is sliding into the fourth and last socket from above, a small burst of light where it lands.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Look: a gun-mod tag: a shield-shaped plate of thick brushed gunmetal steel with a flat top edge, cut corners and a pointed bottom, framed by a raised polished brass rim with four round brass rivets (one in each upper corner, one on each lower side), a slightly recessed dark steel field, the symbol stamped in raised bone-white enamel plus one accent colour, a warm brass glint along the top-right edge, painted in the same bold comic style. Accent colour: hot amber (the last cartridge's glow).
Composition: a single shield-shaped tag centred and upright, filling 85% of the image, on a fully transparent background (PNG with alpha). Nothing outside the tag. It must read at 24 pixels wide: one central object, thick outline, no fine detail.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the tag, a round shape, cloth or stitching, numbers or tally marks, more or fewer than four sockets, a whole gun, a skull.

### Image 3: Gun Mod: Echo Chamber (a zombie equal to the top kill always fits)

**File:** `dd_mod_echo_chamber.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a gun-mod tag showing one upright cartridge in the centre with an identical translucent ghost copy of it offset just behind and to the right, the two outlined by three curved echo rings spreading out to each side like sound waves.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Look: a gun-mod tag: a shield-shaped plate of thick brushed gunmetal steel with a flat top edge, cut corners and a pointed bottom, framed by a raised polished brass rim with four round brass rivets (one in each upper corner, one on each lower side), a slightly recessed dark steel field, the symbol stamped in raised bone-white enamel plus one accent colour, a warm brass glint along the top-right edge, painted in the same bold comic style. Accent colour: ghostly teal (the echo copy and the rings).
Composition: a single shield-shaped tag centred and upright, filling 85% of the image, on a fully transparent background (PNG with alpha). Nothing outside the tag. It must read at 24 pixels wide: one central object, thick outline, no fine detail.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the tag, a round shape, cloth or stitching, a revolver cylinder full of rounds, musical notes, a speaker, a whole gun, more than two cartridges.

### Image 4: Gun Mod: Short Barrel (the gun holds 1 fewer kill and fills sooner)

**File:** `dd_mod_short_barrel.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1024x1024 (square 1:1).
Subject: a gun-mod tag showing a thick gun barrel lying horizontal, cut clean through near its middle with a bright fresh cut face, the cut-off front piece tumbling away down and to the right, a small hacksaw resting diagonally above the cut, a few sparks at the cut.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Look: a gun-mod tag: a shield-shaped plate of thick brushed gunmetal steel with a flat top edge, cut corners and a pointed bottom, framed by a raised polished brass rim with four round brass rivets (one in each upper corner, one on each lower side), a slightly recessed dark steel field, the symbol stamped in raised bone-white enamel plus one accent colour, a warm brass glint along the top-right edge, painted in the same bold comic style. Accent colour: spark orange (the fresh cut and sparks).
Composition: a single shield-shaped tag centred and upright, filling 85% of the image, on a fully transparent background (PNG with alpha). Nothing outside the tag. It must read at 24 pixels wide: one central object, thick outline, no fine detail.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** Letters or numbers on the tag, a round shape, cloth or stitching, a whole gun or a grip and trigger, a real shotgun model, more than one barrel.

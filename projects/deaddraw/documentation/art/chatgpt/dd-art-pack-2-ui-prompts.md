# DeadDraw art pack 2: painted UI kit, prompts for ChatGPT

**ChatGPT, read this first.** This file is a list of image requests for DeadDraw, an original zombie card game. Art pack 1
painted the cards; this pack paints the **interface around them** (number badges, buttons, plates, bars, frames and panels) in
the same bold painted comic style, so the whole screen looks like one game. For each image below:
1. Generate ONE image from the text in its "Prompt" block, exactly as written. Use the canvas size the prompt names
   (1024x1024, 1536x1024 or 1024x1536) and keep the shape at the size and position the prompt gives: the game cuts these
   images into 9 pieces (corners, edges, centre) and stretches the edges and centre, so the measurements matter.
2. Every image has a **transparent background**: output a PNG with a real alpha channel (no checkerboard, no white, no
   backdrop, no scene). Only the button, badge, plate, bar or frame itself is painted.
3. **No text, no numbers, no letters, no icons, no symbols, no logos** anywhere. The game draws every word, number and icon
   on top of these images. Keep the centre of every shape plain and even; detail goes in the corners and along the edges.
4. Light always comes from the **upper right**: highlights on the top and right edges, shade on the bottom and left.
   Front view, no perspective, no tilt.
5. Give the image the file name shown on its "File" line, exactly (lowercase, `.png`).
6. Images in a set (a button's normal and pressed state, the four zombie tiers, the bar track and its fills) must match each
   other exactly in size, shape and outline; only what the prompt says changes. Generate a set one after the other.
7. If the person asks to redo an image, regenerate it and avoid what its "Avoid" line lists.
8. When a batch is done, push the PNGs to the GitHub repository on the branch `art/deaddraw-pack-2`, into the folder
   `projects/deaddraw/documentation/art/chatgpt/images/art-pack-2/` (create the branch from `main` if it does not exist; do
   not touch any other folder or the `main` branch). If you cannot push, give the person the files to download with these
   exact names.

Work through one batch at a time, in order. When the person says "Batch N", generate every image in that batch, one at a time.

All art is original. Style: bold painted comic, painted enamel on thick sheet metal, chunky ink outlines, one warm light from the upper right.

Source: `projects/deaddraw/documentation/art/art-direction.md` (the art direction, section "UI kit") and
`projects/deaddraw/documentation/art/art-pack-2-ui-list.csv` (the full list with game sizes, 9-slice margins, states and where each image is used).

## Shared style (already part of every prompt)

```
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

Colour per card type (the same as pack 1 and the game): yellow = hit (guns, melee), blood red = zombies, purple = bosses,
green = heal, gold = cover, steel blue = guns' frames and help, bone = neutral.

## Shapes and 9-slice margins (already part of every prompt)

The game cuts each image along four lines (the margins) into corners, edges and a centre, then stretches the edges and the
centre to fit. So corners carry the detail and the centre stays plain.

| Shape | Canvas | Shape inside the canvas | Detail band (generated px) | In game | 9-slice margins in game |
|---|---|---|---|---|---|
| badge | 1024x1024 | circle 960 px | ring 88 px | 128x128 | none (fixed circle, scaled as one piece) |
| pill | 1536x1024 | pill 1472x576 | end caps 288 px | 328x128 | left 64, right 64, top 0, bottom 0 (stretches sideways only) |
| button | 1536x1024 | plate 1408x640 | 128 px | 176x80 | 16 all sides (128 px on the generated plate) |
| tag | 1536x1024 | plate 1408x512 | 128 px | 176x64 (and 88x32 for the small tags) | 16 all sides (8 for the 88x32 copy; 128 px on the generated plate) |
| bar | 1536x1024 | bar 1472x192 | end caps 96 px | 124x16 | left 8, right 8, top 0, bottom 0 (stretches sideways only; 96 px on the generated bar) |
| panel | 1024x1024 | panel 960x960 | 160 px | 240x240 | 40 all sides (160 px on the generated panel) |
| rim | 1024x1024 | frame 960x960, inside empty | 160 px | 192x192 (cards) / 120x120 (chips) | 32 all sides for 192x192, 20 for 120x120 (160 px on the generated frame) |
| strip | 1536x1024 | strip 1472x320 | 128 px ends, 64 px top/bottom | 184x40 | left 16, right 16, top 8, bottom 8 (128 / 64 px on the generated strip) |
| socket | 1024x1536 | slot 896x1344 | 128 px | 56x84 | 8 all sides, edges tiled (axis stretch: tile) (128 px on the generated socket) |

| Batch | What | Images |
|---|---|---|
| 1 | Number badges | 11 |
| 2 | Buttons (9-slice) | 13 |
| 3 | Plates and tags | 11 |
| 4 | Bars and filter chips | 7 |
| 5 | Frames and panels | 10 |
| | **Total** | **52** |


---

## Batch 1: Number badges

The circles the head asked for first: every card number sits on one of these. The game draws the number on top.

### Image 1: Hit badge (weapons)

**File:** `dd_badge_hit.png`  
**Canvas:** 1024x1024, transparent · **In game:** 128x128 · **9-slice:** none (fixed circle, scaled as one piece) · **State:** normal  
**Used in:** every gun / melee / Bare Hands number (street cards, gun row, melee button, inspect, tooltips, Codex)

**Prompt:**

```
Original painted game UI element for a zombie card game, 1024x1024 canvas, transparent background.
Subject: a round enamel badge for a weapon's hit value, like a heavy painted metal token.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Ring: dark ink-brown (#2a1f12 to #151214). Centre fill: warm hit yellow (#f2c14e, lighter #f7d77e towards the upper right, deeper #d9a23a lower left). Ink number goes on it, so the yellow stays bright and even.
Shape: one perfect circle badge, 960 px across, centred on the 1024x1024 canvas (32 px transparent margin all round). From the outside in: a 24 px dark ink outline, then a 64 px coloured ring, then the round centre fill. The centre fill is one plain, even colour with only a soft painted gradient (lighter towards the upper right): a big number is drawn on it by the game, so no texture, bolts or marks inside the ring.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a starburst or jagged edge, an orange cast, a gun or bullet drawn inside, any number.

### Image 2: Zombie strength badge, tier 1: Shambler (values 1-3)

**File:** `dd_badge_zombie_t1.png`  
**Canvas:** 1024x1024, transparent · **In game:** 128x128 · **9-slice:** none (fixed circle, scaled as one piece) · **State:** normal  
**Used in:** zombie numbers on street cards, gun kill-stack thumbnails, inspect, tooltips, Codex (tier 1)

**Prompt:**

```
Original painted game UI element for a zombie card game, 1024x1024 canvas, transparent background.
Subject: a round enamel badge for a zombie's strength (its attack and its toughness), like a heavy painted metal token.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Ring: bone (#bdb5a0, light #ddd6c2), painted with a highlight on the upper right of the ring. Centre fill: deep blood red (#5c1b19, a little lighter #7a2622 towards the upper right, darker #3e1110 lower left). A bone-white number goes on it, so the fill stays dark and even.
Shape: one perfect circle badge, 960 px across, centred on the 1024x1024 canvas (32 px transparent margin all round). From the outside in: a 24 px dark ink outline, then a 64 px coloured ring, then the round centre fill. The centre fill is one plain, even colour with only a soft painted gradient (lighter towards the upper right): a big number is drawn on it by the game, so no texture, bolts or marks inside the ring.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** drips, splatter or a blood texture in the centre, cracks, a skull, any number.

### Image 3: Zombie strength badge, tier 2: Lurcher (values 4-6)

**File:** `dd_badge_zombie_t2.png`  
**Canvas:** 1024x1024, transparent · **In game:** 128x128 · **9-slice:** none (fixed circle, scaled as one piece) · **State:** normal  
**Used in:** zombie numbers on street cards, gun kill-stack thumbnails, inspect, tooltips, Codex (tier 2)

**Prompt:**

```
Original painted game UI element for a zombie card game, 1024x1024 canvas, transparent background.
Subject: a round enamel badge for a zombie's strength (its attack and its toughness), like a heavy painted metal token.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Ring: amber (#d99a3c, light #f0b860), painted with a highlight on the upper right of the ring. Centre fill: deep blood red (#5c1b19, a little lighter #7a2622 towards the upper right, darker #3e1110 lower left). A bone-white number goes on it, so the fill stays dark and even.
Shape: one perfect circle badge, 960 px across, centred on the 1024x1024 canvas (32 px transparent margin all round). From the outside in: a 24 px dark ink outline, then a 64 px coloured ring, then the round centre fill. The centre fill is one plain, even colour with only a soft painted gradient (lighter towards the upper right): a big number is drawn on it by the game, so no texture, bolts or marks inside the ring.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** drips, splatter or a blood texture in the centre, cracks, a skull, any number.

### Image 4: Zombie strength badge, tier 3: Bruiser (values 7-9)

**File:** `dd_badge_zombie_t3.png`  
**Canvas:** 1024x1024, transparent · **In game:** 128x128 · **9-slice:** none (fixed circle, scaled as one piece) · **State:** normal  
**Used in:** zombie numbers on street cards, gun kill-stack thumbnails, inspect, tooltips, Codex (tier 3)

**Prompt:**

```
Original painted game UI element for a zombie card game, 1024x1024 canvas, transparent background.
Subject: a round enamel badge for a zombie's strength (its attack and its toughness), like a heavy painted metal token.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Ring: orange (#e8793a, light #ff9a5c), painted with a highlight on the upper right of the ring. Centre fill: deep blood red (#5c1b19, a little lighter #7a2622 towards the upper right, darker #3e1110 lower left). A bone-white number goes on it, so the fill stays dark and even.
Shape: one perfect circle badge, 960 px across, centred on the 1024x1024 canvas (32 px transparent margin all round). From the outside in: a 24 px dark ink outline, then a 64 px coloured ring, then the round centre fill. The centre fill is one plain, even colour with only a soft painted gradient (lighter towards the upper right): a big number is drawn on it by the game, so no texture, bolts or marks inside the ring.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** drips, splatter or a blood texture in the centre, cracks, a skull, any number.

### Image 5: Zombie strength badge, tier 4: Hulk (values 10+)

**File:** `dd_badge_zombie_t4.png`  
**Canvas:** 1024x1024, transparent · **In game:** 128x128 · **9-slice:** none (fixed circle, scaled as one piece) · **State:** normal  
**Used in:** zombie numbers on street cards, gun kill-stack thumbnails, inspect, tooltips, Codex (tier 4)

**Prompt:**

```
Original painted game UI element for a zombie card game, 1024x1024 canvas, transparent background.
Subject: a round enamel badge for a zombie's strength (its attack and its toughness), like a heavy painted metal token.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Ring: red (#e2574c, light #ff7a6e), painted with a highlight on the upper right of the ring. Centre fill: deep blood red (#5c1b19, a little lighter #7a2622 towards the upper right, darker #3e1110 lower left). A bone-white number goes on it, so the fill stays dark and even.
Shape: one perfect circle badge, 960 px across, centred on the 1024x1024 canvas (32 px transparent margin all round). From the outside in: a 24 px dark ink outline, then a 64 px coloured ring, then the round centre fill. The centre fill is one plain, even colour with only a soft painted gradient (lighter towards the upper right): a big number is drawn on it by the game, so no texture, bolts or marks inside the ring.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** drips, splatter or a blood texture in the centre, cracks, a skull, any number.

### Image 6: Heal badge (medkits)

**File:** `dd_badge_heal.png`  
**Canvas:** 1024x1024, transparent · **In game:** 128x128 · **9-slice:** none (fixed circle, scaled as one piece) · **State:** normal  
**Used in:** heal numbers (Bandage, First Aid Kit, Trauma Kit) on street cards, inspect, Codex

**Prompt:**

```
Original painted game UI element for a zombie card game, 1024x1024 canvas, transparent background.
Subject: a round enamel badge for a heal value.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Ring: heal green (#6fd08a, light #9be8ad, shade #3f8f57). Centre fill: near-black ink (#151214 to #1d2420), very slightly lighter at the upper right.
Shape: one perfect circle badge, 960 px across, centred on the 1024x1024 canvas (32 px transparent margin all round). From the outside in: a 24 px dark ink outline, then a 64 px coloured ring, then the round centre fill. The centre fill is one plain, even colour with only a soft painted gradient (lighter towards the upper right): a big number is drawn on it by the game, so no texture, bolts or marks inside the ring.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a plus or cross inside, a red ring, any number.

### Image 7: Cover badge

**File:** `dd_badge_cover.png`  
**Canvas:** 1024x1024, transparent · **In game:** 128x128 · **9-slice:** none (fixed circle, scaled as one piece) · **State:** normal  
**Used in:** cover numbers (Plywood, Car Door, Dumpster), the Cover chip in the top bar, inspect, Codex

**Prompt:**

```
Original painted game UI element for a zombie card game, 1024x1024 canvas, transparent background.
Subject: a round enamel badge for a cover value.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Ring: cover gold (#e0b04a, light #f2cf72, shade #a87a26). Centre fill: near-black ink (#151214 to #22201a), very slightly lighter at the upper right.
Shape: one perfect circle badge, 960 px across, centred on the 1024x1024 canvas (32 px transparent margin all round). From the outside in: a 24 px dark ink outline, then a 64 px coloured ring, then the round centre fill. The centre fill is one plain, even colour with only a soft painted gradient (lighter towards the upper right): a big number is drawn on it by the game, so no texture, bolts or marks inside the ring.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a shield inside, a yellow (hit) fill, any number.

### Image 8: Neutral badge (bone ring)

**File:** `dd_badge_neutral.png`  
**Canvas:** 1024x1024, transparent · **In game:** 128x128 · **9-slice:** none (fixed circle, scaled as one piece) · **State:** normal  
**Used in:** survivor initials on the title screen, pile count, patch count and any other card number

**Prompt:**

```
Original painted game UI element for a zombie card game, 1024x1024 canvas, transparent background.
Subject: a round enamel badge for other numbers and letters.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Ring: bone white (#ece6d6, shade #b9b2a0). Centre fill: near-black ink (#151214 to #22262a), very slightly lighter at the upper right.
Shape: one perfect circle badge, 960 px across, centred on the 1024x1024 canvas (32 px transparent margin all round). From the outside in: a 24 px dark ink outline, then a 64 px coloured ring, then the round centre fill. The centre fill is one plain, even colour with only a soft painted gradient (lighter towards the upper right): a big number is drawn on it by the game, so no texture, bolts or marks inside the ring.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** any colour in the ring, any letter or number.

### Image 9: Zombie strength pill (wide values)

**File:** `dd_pill_zombie.png`  
**Canvas:** 1536x1024, transparent · **In game:** 328x128 · **9-slice:** left 64, right 64, top 0, bottom 0 (stretches sideways only) · **State:** normal  
**Used in:** boss values on the map district tiles, boss cards, wave tile, inspect

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a wide enamel pill badge for a boss's strength written wide (6x3, 8-12).
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Ring: red (#e2574c, light #ff7a6e). Centre fill: deep blood red (#5c1b19, a little lighter towards the upper right). A bone-white wide number goes on it.
Shape: one horizontal pill (a rectangle with fully round ends), 1472 px wide and 576 px tall, centred on the 1536x1024 canvas (32 px transparent margin left and right, 224 px top and bottom). From the outside in: a 24 px dark ink outline, a 64 px coloured ring, then the centre fill. The two round end caps (288 px from each end) hold all the painted detail; the middle stretch is a plain, even fill that repeats cleanly when stretched sideways. A wide number like 6x3 is drawn on it by the game.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a separate circle at each end, splatter, any number.

### Image 10: Hit pill (wide values)

**File:** `dd_pill_hit.png`  
**Canvas:** 1536x1024, transparent · **In game:** 328x128 · **9-slice:** left 64, right 64, top 0, bottom 0 (stretches sideways only) · **State:** normal  
**Used in:** weapon numbers with 3+ characters (inspect, Codex)

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a wide enamel pill badge for a weapon value written wide.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Ring: dark ink-brown (#2a1f12 to #151214). Centre fill: hit yellow (#f2c14e, lighter #f7d77e towards the upper right).
Shape: one horizontal pill (a rectangle with fully round ends), 1472 px wide and 576 px tall, centred on the 1536x1024 canvas (32 px transparent margin left and right, 224 px top and bottom). From the outside in: a 24 px dark ink outline, a 64 px coloured ring, then the centre fill. The two round end caps (288 px from each end) hold all the painted detail; the middle stretch is a plain, even fill that repeats cleanly when stretched sideways. A wide number like 6x3 is drawn on it by the game.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** an orange cast, a starburst, any number.

### Image 11: Neutral pill (wide values)

**File:** `dd_pill_neutral.png`  
**Canvas:** 1536x1024, transparent · **In game:** 328x128 · **9-slice:** left 64, right 64, top 0, bottom 0 (stretches sideways only) · **State:** normal  
**Used in:** wide counts such as 9/11 (Codex, pile, patches)

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a wide enamel pill badge for other wide numbers.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Ring: bone white (#ece6d6, shade #b9b2a0). Centre fill: near-black ink (#151214 to #22262a).
Shape: one horizontal pill (a rectangle with fully round ends), 1472 px wide and 576 px tall, centred on the 1536x1024 canvas (32 px transparent margin left and right, 224 px top and bottom). From the outside in: a 24 px dark ink outline, a 64 px coloured ring, then the centre fill. The two round end caps (288 px from each end) hold all the painted detail; the middle stretch is a plain, even fill that repeats cleanly when stretched sideways. A wide number like 6x3 is drawn on it by the game.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** any colour in the ring, any number.

---

## Batch 2: Buttons (9-slice)

Raised enamel buttons in each action colour, normal and pressed, plus one shared disabled plate. Hover is the normal image brightened in the game.

### Image 12: Button Primary action, red: normal

**File:** `dd_btn_red_normal.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** normal (hover = this image brightened x1.12 in game)  
**Used in:** Start run, Enter <district>, Run again, Yes abandon

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a raised button plate, normal state: it stands up from the screen with a bevel, light on the top and right edges.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: deep brick red enamel (#7a2d27, highlight #9e4038 on the top and right bevel, shade #4f1a16 lower left), a thin warm rim light along the top edge.
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a pushed-in look, a glow, a frame inside a frame, texture or bolts in the centre, any word or icon.

### Image 13: Button Primary action, red: pressed

**File:** `dd_btn_red_pressed.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** pressed  
**Used in:** Start run, Enter <district>, Run again, Yes abandon

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: the SAME button plate as dd_btn_red_normal.png in its pressed state: pushed in, the bevel inverted (shade along the top and right inner edge, a thin light line along the bottom and left), the centre one value step darker, same size and outline.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: deep brick red enamel (#7a2d27, highlight #9e4038 on the top and right bevel, shade #4f1a16 lower left), a thin warm rim light along the top edge, one step darker overall.
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a different shape or size from the normal state, a glow, any word or icon.

### Image 14: Button Secondary, dark steel: normal

**File:** `dd_btn_dark_normal.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** normal (hover = this image brightened x1.12 in game)  
**Used in:** How to play, Codex, Settings, Menu, Close, Got it, No keep it, Survivors, BURY, Abandon run

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a raised button plate, normal state: it stands up from the screen with a bevel, light on the top and right edges.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: dark gun-metal enamel (#2b3338, highlight #44525a on the top and right bevel, shade #1a1f22 lower left), bone-grey worn edges.
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a pushed-in look, a glow, a frame inside a frame, texture or bolts in the centre, any word or icon.

### Image 15: Button Secondary, dark steel: pressed

**File:** `dd_btn_dark_pressed.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** pressed  
**Used in:** How to play, Codex, Settings, Menu, Close, Got it, No keep it, Survivors, BURY, Abandon run

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: the SAME button plate as dd_btn_dark_normal.png in its pressed state: pushed in, the bevel inverted (shade along the top and right inner edge, a thin light line along the bottom and left), the centre one value step darker, same size and outline.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: dark gun-metal enamel (#2b3338, highlight #44525a on the top and right bevel, shade #1a1f22 lower left), bone-grey worn edges, one step darker overall.
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a different shape or size from the normal state, a glow, any word or icon.

### Image 16: Button Run / leave, rust: normal

**File:** `dd_btn_rust_normal.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** normal (hover = this image brightened x1.12 in game)  
**Used in:** RUN -1 HP, RUN PAST, Leave the safehouse

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a raised button plate, normal state: it stands up from the screen with a bevel, light on the top and right edges.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: dark rust-brown enamel (#5a2a1a, highlight #7e4026 on the top and right bevel, shade #3a1a10 lower left), a few rust flecks at the edges only.
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a pushed-in look, a glow, a frame inside a frame, texture or bolts in the centre, any word or icon.

### Image 17: Button Run / leave, rust: pressed

**File:** `dd_btn_rust_pressed.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** pressed  
**Used in:** RUN -1 HP, RUN PAST, Leave the safehouse

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: the SAME button plate as dd_btn_rust_normal.png in its pressed state: pushed in, the bevel inverted (shade along the top and right inner edge, a thin light line along the bottom and left), the centre one value step darker, same size and outline.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: dark rust-brown enamel (#5a2a1a, highlight #7e4026 on the top and right bevel, shade #3a1a10 lower left), a few rust flecks at the edges only, one step darker overall.
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a different shape or size from the normal state, a glow, any word or icon.

### Image 18: Button Go / continue, green: normal

**File:** `dd_btn_green_normal.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** normal (hover = this image brightened x1.12 in game)  
**Used in:** CONTINUE RUN, head to the next district, Supplies (Safehouse shop)

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a raised button plate, normal state: it stands up from the screen with a bevel, light on the top and right edges.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: deep bottle green enamel (#245236, highlight #357a50 on the top and right bevel, shade #163522 lower left).
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a pushed-in look, a glow, a frame inside a frame, texture or bolts in the centre, any word or icon.

### Image 19: Button Go / continue, green: pressed

**File:** `dd_btn_green_pressed.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** pressed  
**Used in:** CONTINUE RUN, head to the next district, Supplies (Safehouse shop)

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: the SAME button plate as dd_btn_green_normal.png in its pressed state: pushed in, the bevel inverted (shade along the top and right inner edge, a thin light line along the bottom and left), the centre one value step darker, same size and outline.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: deep bottle green enamel (#245236, highlight #357a50 on the top and right bevel, shade #163522 lower left), one step darker overall.
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a different shape or size from the normal state, a glow, any word or icon.

### Image 20: Button Help, blue: normal

**File:** `dd_btn_blue_normal.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** normal (hover = this image brightened x1.12 in game)  
**Used in:** the ? (Help / Glossary) button in the top bar

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a raised button plate, normal state: it stands up from the screen with a bevel, light on the top and right edges.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: deep slate blue enamel (#1f3a4f, highlight #2f5876 on the top and right bevel, shade #132433 lower left) with a thin steel-blue (#5bb0e0) rim line just inside the ink outline.
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a pushed-in look, a glow, a frame inside a frame, texture or bolts in the centre, any word or icon.

### Image 21: Button Help, blue: pressed

**File:** `dd_btn_blue_pressed.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** pressed  
**Used in:** the ? (Help / Glossary) button in the top bar

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: the SAME button plate as dd_btn_blue_normal.png in its pressed state: pushed in, the bevel inverted (shade along the top and right inner edge, a thin light line along the bottom and left), the centre one value step darker, same size and outline.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: deep slate blue enamel (#1f3a4f, highlight #2f5876 on the top and right bevel, shade #132433 lower left) with a thin steel-blue (#5bb0e0) rim line just inside the ink outline, one step darker overall.
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a different shape or size from the normal state, a glow, any word or icon.

### Image 22: Button Shop row, indigo: normal

**File:** `dd_btn_indigo_normal.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** normal (hover = this image brightened x1.12 in game)  
**Used in:** Patch rows in the Safehouse shop and the boss reward pick

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a raised button plate, normal state: it stands up from the screen with a bevel, light on the top and right edges.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: deep indigo enamel (#2f2f5a, highlight #44447e on the top and right bevel, shade #1e1e3a lower left) with a thin periwinkle (#9aa8ff) rim line just inside the ink outline.
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a pushed-in look, a glow, a frame inside a frame, texture or bolts in the centre, any word or icon.

### Image 23: Button Shop row, indigo: pressed

**File:** `dd_btn_indigo_pressed.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** pressed  
**Used in:** Patch rows in the Safehouse shop and the boss reward pick

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: the SAME button plate as dd_btn_indigo_normal.png in its pressed state: pushed in, the bevel inverted (shade along the top and right inner edge, a thin light line along the bottom and left), the centre one value step darker, same size and outline.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: deep indigo enamel (#2f2f5a, highlight #44447e on the top and right bevel, shade #1e1e3a lower left) with a thin periwinkle (#9aa8ff) rim line just inside the ink outline, one step darker overall.
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a different shape or size from the normal state, a glow, any word or icon.

### Image 24: Button: disabled (shared by every type)

**File:** `dd_btn_disabled.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** disabled  
**Used in:** every disabled button (Open plate you cannot afford uses the door plates instead), RUN when there is no escape, shop rows you cannot buy

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a flat, dull button plate that clearly cannot be pressed: no bevel highlight, matte, a little faded, the outline in dark grey instead of ink.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: dull slate (#20262a, edge #3a4146), desaturated, low contrast, no warm light.
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** any colour, any shine, a lock or cross symbol, any word.

---

## Batch 3: Plates and tags

The door price plates, the Full set plate and the small card tags.

### Image 25: Door price plate: can afford

**File:** `dd_plate_door_afford.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** normal (afford; pressed = darkened in game)  
**Used in:** Door row: OPEN plate on a room you can pay for

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a bolted price plate hung on a locked door, ready to open: a bright, raised gold enamel plate with four corner bolts.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: warm gold enamel (#f2c14e, highlight #ffe08a upper right, shade #c48f2a lower left), pale bone-gold rim line (#fff2b0) inside the ink outline. An ink padlock and price are drawn on it by the game.
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a padlock or price drawn in, a hanging chain, any word.

### Image 26: Door price plate: locked (cannot afford)

**File:** `dd_plate_door_locked.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** disabled (locked)  
**Used in:** Door row: price plate on a room you cannot pay for yet

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: the same bolted door plate, locked and out of reach: a dark, scratched iron plate with dull brass corner bolts.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: near-black iron (#16120f, highlight #2a241c upper right), dull brass rim line (#8a7a52). A bone padlock, price and a thin gold progress bar are drawn on it by the game.
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a padlock drawn in, rust holes, any word.

### Image 27: Door plate: USE (open room)

**File:** `dd_plate_door_use.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** normal (USE)  
**Used in:** Door row: USE plate on an open room's machine

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: the same bolted door plate on an opened room, ready to use: a bright green enamel plate.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: heal green enamel (#6fd08a, highlight #a6f0bb upper right, shade #3f8f57 lower left), pale mint rim line (#c9f5d4). The word USE is drawn on it by the game in ink.
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a check mark, any word.

### Image 28: Door plate: used

**File:** `dd_plate_door_used.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** disabled (used)  
**Used in:** Door row: plate on a room whose machine was used this street

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: the same bolted door plate after the machine was used: a flat, dark, worn plate, clearly spent.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: very dark grey (#100e0e, edge #555555), matte, no warm light.
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a cross, any colour, any word.

### Image 29: Full set plate: open

**File:** `dd_plate_fullset_open.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x64 (and 88x32 for the small tags) · **9-slice:** 16 all sides (8 for the 88x32 copy; 128 px on the generated plate) · **State:** normal (open)  
**Used in:** the Full set plate at the bottom of each gun tile (gun row, inspect)

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a low trophy plate under a gun, still being filled: a dark bronze enamel plate with a half-strength gold rim.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: very dark bronze (#2a2208, highlight #3d3210 upper right), gold rim line at half strength (#a08a3a). The cup icon and 'FULL +50' are drawn on it by the game in gold.
Shape: one low rounded tag plate, 1408 px wide and 512 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 256 px top and bottom), corner radius about 128 px, a 20 px dark ink outline. 9-slice: all detail sits inside the outer 128 px band; the centre is a plain, even fill so a short word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a trophy cup drawn in, any word or number.

### Image 30: Full set plate: one kill to go

**File:** `dd_plate_fullset_near.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x64 (and 88x32 for the small tags) · **9-slice:** 16 all sides (8 for the 88x32 copy; 128 px on the generated plate) · **State:** highlighted (near)  
**Used in:** the Full set plate when the next kill fills the gun

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: the same Full set plate, one kill away: same dark bronze plate, the gold rim brighter and a soft warm gold glow just outside the outline (the glow stays inside the canvas margin).
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: very dark bronze (#2a2208), bright gold rim (#f2d65c), soft gold glow (#f2d65c at low opacity).
Shape: one low rounded tag plate, 1408 px wide and 512 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 256 px top and bottom), corner radius about 128 px, a 20 px dark ink outline. 9-slice: all detail sits inside the outer 128 px band; the centre is a plain, even fill so a short word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a trophy cup drawn in, a hard yellow fill, any word.

### Image 31: Full set plate: lit (full)

**File:** `dd_plate_fullset_lit.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x64 (and 88x32 for the small tags) · **9-slice:** 16 all sides (8 for the 88x32 copy; 128 px on the generated plate) · **State:** active (lit)  
**Used in:** the Full set plate when every socket is filled (finish animation, inspect)

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: the same Full set plate, filled: a bright, polished gold plate, the reward earned.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: bright gold enamel (#f2d65c, highlight #fff0a0 upper right, shade #c9a636 lower left). Ink text is drawn on it by the game.
Shape: one low rounded tag plate, 1408 px wide and 512 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 256 px top and bottom), corner radius about 128 px, a 20 px dark ink outline. 9-slice: all detail sits inside the outer 128 px band; the centre is a plain, even fill so a short word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** sparkles that cross the centre, a trophy cup drawn in, any word.

### Image 32: Tag: yellow

**File:** `dd_tag_yellow.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x64 (and 88x32 for the small tags) · **9-slice:** 16 all sides (8 for the 88x32 copy; 128 px on the generated plate) · **State:** normal  
**Used in:** FULL HP, NEXT, holdover and other yellow card tags

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a small painted enamel tag label, like a sticker plate.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Fill: warning yellow (#f2c14e, lighter towards the upper right), ink outline. Ink words like FULL HP or NEXT go on it.
Shape: one low rounded tag plate, 1408 px wide and 512 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 256 px top and bottom), corner radius about 128 px, a 20 px dark ink outline. 9-slice: all detail sits inside the outer 128 px band; the centre is a plain, even fill so a short word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** any word, a hole for a string.

### Image 33: Tag: red

**File:** `dd_tag_red.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x64 (and 88x32 for the small tags) · **9-slice:** 16 all sides (8 for the 88x32 copy; 128 px on the generated plate) · **State:** normal  
**Used in:** the damage chip on zombie cards (top-right), the boss NO ESCAPE marker

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a small painted enamel tag label.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Fill: alarm red (#ff6b5e, deeper #c8322a lower left), ink outline. Ink damage numbers like -7 go on it.
Shape: one low rounded tag plate, 1408 px wide and 512 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 256 px top and bottom), corner radius about 128 px, a 20 px dark ink outline. 9-slice: all detail sits inside the outer 128 px band; the centre is a plain, even fill so a short word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** splatter, any number.

### Image 34: Tag: bone

**File:** `dd_tag_bone.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x64 (and 88x32 for the small tags) · **9-slice:** 16 all sides (8 for the 88x32 copy; 128 px on the generated plate) · **State:** normal  
**Used in:** ACTIVE on the active gun, LOCKED / MARK on survivor tiles

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a small painted enamel tag label.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Fill: pale bone (#fff2b0 to #ece6d6), ink outline. Ink words like ACTIVE, LOCKED, MARK go on it.
Shape: one low rounded tag plate, 1408 px wide and 512 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 256 px top and bottom), corner radius about 128 px, a 20 px dark ink outline. 9-slice: all detail sits inside the outer 128 px band; the centre is a plain, even fill so a short word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** any word.

### Image 35: Tag: boss purple

**File:** `dd_tag_boss.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x64 (and 88x32 for the small tags) · **9-slice:** 16 all sides (8 for the 88x32 copy; 128 px on the generated plate) · **State:** normal  
**Used in:** the BOSS counter under the wave number on the wave tile; PHASE tag on boss cards

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a small painted enamel plate for the boss counter.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Fill: deep purple (#2c1d35, highlight #4a3060 upper right), bright purple rim line (#c27ce0). Bone words like BOSS 9 go on it.
Shape: one low rounded tag plate, 1408 px wide and 512 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 256 px top and bottom), corner radius about 128 px, a 20 px dark ink outline. 9-slice: all detail sits inside the outer 128 px band; the centre is a plain, even fill so a short word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a skull, a crown, any word.

---

## Batch 4: Bars and filter chips

The HP bar (track and fills) and the Codex / Settings chips.

### Image 36: Bar track (empty)

**File:** `dd_bar_track.png`  
**Canvas:** 1536x1024, transparent · **In game:** 124x16 · **9-slice:** left 8, right 8, top 0, bottom 0 (stretches sideways only; 96 px on the generated bar) · **State:** normal  
**Used in:** HP bar background in the top bar, door price progress, Settings sliders

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: an empty, sunken gauge track, like a recessed groove in a metal panel.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Track: near-black (#0d0f10), a darker inner shadow along the top edge and a thin light lip along the bottom edge (it is sunk in).
Shape: one long horizontal bar with round ends, 1472 px wide and 192 px tall, centred on the 1536x1024 canvas (32 px transparent margin left and right, 416 px top and bottom), a 16 px dark ink outline. 9-slice: the two round end caps (96 px from each end) carry the detail; the long middle is even along its length (a top highlight stripe and a lower shade stripe that run straight across) so it stretches sideways without seams.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** tick marks, any fill, any number.

### Image 37: Bar fill: green (HP above half)

**File:** `dd_bar_fill_green.png`  
**Canvas:** 1536x1024, transparent · **In game:** 124x16 · **9-slice:** left 8, right 8, top 0, bottom 0 (stretches sideways only; 96 px on the generated bar) · **State:** normal  
**Used in:** HP bar fill above half HP, Settings slider fill

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a glossy painted gauge fill, like coloured liquid enamel in a tube, that fits exactly inside dd_bar_track.png (same size and round ends).
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Fill: heal green (#6fd08a, highlight stripe #a6f0bb along the top, shade #3f8f57 along the bottom).
Shape: one long horizontal bar with round ends, 1472 px wide and 192 px tall, centred on the 1536x1024 canvas (32 px transparent margin left and right, 416 px top and bottom), a 16 px dark ink outline. 9-slice: the two round end caps (96 px from each end) carry the detail; the long middle is even along its length (a top highlight stripe and a lower shade stripe that run straight across) so it stretches sideways without seams.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** bubbles, segments or tick marks, a glow outside the outline.

### Image 38: Bar fill: amber (HP below half)

**File:** `dd_bar_fill_amber.png`  
**Canvas:** 1536x1024, transparent · **In game:** 124x16 · **9-slice:** left 8, right 8, top 0, bottom 0 (stretches sideways only; 96 px on the generated bar) · **State:** normal  
**Used in:** HP bar fill between a quarter and half HP

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a glossy painted gauge fill, like coloured liquid enamel in a tube, that fits exactly inside dd_bar_track.png (same size and round ends).
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Fill: amber (#f2c14e, highlight stripe #ffe08a along the top, shade #c48f2a along the bottom).
Shape: one long horizontal bar with round ends, 1472 px wide and 192 px tall, centred on the 1536x1024 canvas (32 px transparent margin left and right, 416 px top and bottom), a 16 px dark ink outline. 9-slice: the two round end caps (96 px from each end) carry the detail; the long middle is even along its length (a top highlight stripe and a lower shade stripe that run straight across) so it stretches sideways without seams.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** bubbles, segments or tick marks, a glow outside the outline.

### Image 39: Bar fill: red (HP below a quarter)

**File:** `dd_bar_fill_red.png`  
**Canvas:** 1536x1024, transparent · **In game:** 124x16 · **9-slice:** left 8, right 8, top 0, bottom 0 (stretches sideways only; 96 px on the generated bar) · **State:** normal  
**Used in:** HP bar fill below a quarter HP

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a glossy painted gauge fill, like coloured liquid enamel in a tube, that fits exactly inside dd_bar_track.png (same size and round ends).
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Fill: alarm red (#ff6b5e, highlight stripe #ff9b90 along the top, shade #c8322a along the bottom).
Shape: one long horizontal bar with round ends, 1472 px wide and 192 px tall, centred on the 1536x1024 canvas (32 px transparent margin left and right, 416 px top and bottom), a 16 px dark ink outline. 9-slice: the two round end caps (96 px from each end) carry the detail; the long middle is even along its length (a top highlight stripe and a lower shade stripe that run straight across) so it stretches sideways without seams.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** bubbles, segments or tick marks, a glow outside the outline.

### Image 40: Bar fill: gold (door progress)

**File:** `dd_bar_fill_gold.png`  
**Canvas:** 1536x1024, transparent · **In game:** 124x16 · **9-slice:** left 8, right 8, top 0, bottom 0 (stretches sideways only; 96 px on the generated bar) · **State:** normal  
**Used in:** the thin progress bar on a locked door plate (points towards the price)

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a glossy painted gauge fill, like coloured liquid enamel in a tube, that fits exactly inside dd_bar_track.png (same size and round ends).
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Fill: warm gold (#f2c14e, highlight stripe #ffe08a along the top, shade #a87a26 along the bottom).
Shape: one long horizontal bar with round ends, 1472 px wide and 192 px tall, centred on the 1536x1024 canvas (32 px transparent margin left and right, 416 px top and bottom), a 16 px dark ink outline. 9-slice: the two round end caps (96 px from each end) carry the detail; the long middle is even along its length (a top highlight stripe and a lower shade stripe that run straight across) so it stretches sideways without seams.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** bubbles, segments or tick marks, a glow outside the outline.

### Image 41: Filter chip: on

**File:** `dd_chip_filter_on.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** active (selected)  
**Used in:** Codex type / district / Met only filters (selected); Settings toggles on

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a selected filter chip, like a lit brass toggle plate: raised, with a bright gold rim.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: dark brass (#5e4a1c, highlight #7a6226 upper right), bright gold rim line (#f2c14e). A bone word is drawn on it by the game.
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a check mark, a glow that crosses the centre, any word.

### Image 42: Filter chip: off

**File:** `dd_chip_filter_off.png`  
**Canvas:** 1536x1024, transparent · **In game:** 176x80 · **9-slice:** 16 all sides (128 px on the generated plate) · **State:** normal (unselected)  
**Used in:** Codex filters not selected; Settings toggles off

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: an unselected filter chip: a flat, dark steel plate, slightly recessed.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Plate: dark slate (#20262a, highlight #2e363b upper right), dim grey rim line (#4a5358).
Shape: one wide rounded-rectangle plate, 1408 px wide and 640 px tall, centred on the 1536x1024 canvas (64 px transparent margin left and right, 192 px top and bottom), corner radius about 96 px, a 20 px dark ink outline. 9-slice: all detail (bolts, chips, bevel highlights, edge wear) sits inside the outer 128 px band of the plate; the centre (everything more than 128 px from the plate edge) is a plain, even painted surface with only a soft gradient, so it can stretch to any width and height and a word can sit on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** any colour, any word.

---

## Batch 5: Frames and panels

Card and chip frames (tinted per card type in the game), the tooltip, dialog, overlay and HUD panels, the name bar and kill sockets.

### Image 43: Card frame rim (tintable)

**File:** `dd_frame_card_rim.png`  
**Canvas:** 1024x1024, transparent · **In game:** 192x192 (cards) / 120x120 (chips) · **9-slice:** 32 all sides for 192x192, 20 for 120x120 (160 px on the generated frame) · **State:** normal (tinted per type in game)  
**Used in:** every card: street cards, gun tiles, melee button, Door row, wave/boss tile, pile, map district tiles, survivor tiles, Codex tiles

**Prompt:**

```
Original painted game UI element for a zombie card game, 1024x1024 canvas, transparent background.
Subject: a painted metal card frame (just the border), like the bent steel edge of a trading-card holder, with a small bolt in each corner.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Rim: NEUTRAL light grey only (#e6e6e6 highlights on the top and right, #b0b0b0 mid, #7a7a7a shadow on the bottom and left), no colour at all: the game tints it to each card type's colour (red zombie, blue gun, green heal, gold cover, purple boss, tan melee). Ink outline stays dark.
Shape: one square rounded frame, 960x960 px, centred on the 1024x1024 canvas (32 px transparent margin), corner radius about 80 px: a 16 px dark ink outline outside, a 40 px painted rim band, a thin 8 px ink line inside the rim. The whole inside of the frame is EMPTY and fully transparent (the card art shows through). 9-slice: all detail sits in the outer 160 px band; the straight edges between the corners are even along their length so they stretch cleanly.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** any colour, anything inside the frame, rounded bubbly corners, a different rim width per side.

### Image 44: Card frame: selected

**File:** `dd_frame_card_selected.png`  
**Canvas:** 1024x1024, transparent · **In game:** 192x192 (cards) / 120x120 (chips) · **9-slice:** 32 all sides for 192x192, 20 for 120x120 (160 px on the generated frame) · **State:** active (selected)  
**Used in:** the active gun, a picked card, the chosen survivor

**Prompt:**

```
Original painted game UI element for a zombie card game, 1024x1024 canvas, transparent background.
Subject: the same card frame as dd_frame_card_rim.png, selected: the rim in pale bone-gold and a soft warm glow just outside it (the glow stays inside the canvas margin).
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Rim: pale bone-gold (#fff2b0, shade #d8c47a), glow #fff2b0 at low opacity.
Shape: one square rounded frame, 960x960 px, centred on the 1024x1024 canvas (32 px transparent margin), corner radius about 80 px: a 16 px dark ink outline outside, a 40 px painted rim band, a thin 8 px ink line inside the rim. The whole inside of the frame is EMPTY and fully transparent (the card art shows through). 9-slice: all detail sits in the outer 160 px band; the straight edges between the corners are even along their length so they stretch cleanly.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** anything inside the frame, sparkles, a hard yellow fill.

### Image 45: Chip frame rim (tintable, small)

**File:** `dd_frame_chip_rim.png`  
**Canvas:** 1024x1024, transparent · **In game:** 192x192 (cards) / 120x120 (chips) · **9-slice:** 32 all sides for 192x192, 20 for 120x120 (160 px on the generated frame) · **State:** normal (tinted per type in game)  
**Used in:** top bar chips (HP, points, Cover, Patches), kill-stack thumbnails in the gun row, inspect pictures, Codex mini tiles

**Prompt:**

```
Original painted game UI element for a zombie card game, 1024x1024 canvas, transparent background.
Subject: a smaller, simpler painted frame (just the border) for small tiles: a single rim with no corner bolts, a little thicker in proportion so it still reads at 120 px.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Rim: NEUTRAL light grey only (#e6e6e6 highlights top and right, #b0b0b0 mid, #7a7a7a shadow bottom and left), tinted in game.
Shape: one square rounded frame, 960x960 px, centred on the 1024x1024 canvas (32 px transparent margin), corner radius about 80 px: a 16 px dark ink outline outside, a 40 px painted rim band, a thin 8 px ink line inside the rim. The whole inside of the frame is EMPTY and fully transparent (the card art shows through). 9-slice: all detail sits in the outer 160 px band; the straight edges between the corners are even along their length so they stretch cleanly.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** any colour, bolts, anything inside the frame.

### Image 46: Panel: tooltip / inspect

**File:** `dd_panel_tooltip.png`  
**Canvas:** 1024x1024, transparent · **In game:** 240x240 · **9-slice:** 40 all sides (160 px on the generated panel) · **State:** normal  
**Used in:** the 2-line tooltip on right click / long press, the inspect (zoom) view

**Prompt:**

```
Original painted game UI element for a zombie card game, 1024x1024 canvas, transparent background.
Subject: a dark painted info panel, like the steel face of a field case, with a small bolt in each corner and a neutral rim.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Body: near-black blue-grey (#0f1214, a soft lift to #161b1e upper right). Rim: dark steel (#2b3338 to #3a4146). The game draws a tinted frame rim (dd_frame_card_rim) over it in the card type's colour.
Shape: one square rounded panel, 960x960 px, centred on the 1024x1024 canvas (32 px transparent margin), corner radius about 112 px, a 24 px dark ink outline, a 40 px painted rim just inside the outline. 9-slice: all detail (rim, bolts in the four corners, edge wear, bevel light) sits inside the outer 160 px band; the centre is a plain, even, dark painted surface with only a very soft gradient, so the panel stretches to any size and text stays readable on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** anything in the centre, rivets along the edges, a coloured rim.

### Image 47: Panel: modal sheet

**File:** `dd_panel_modal.png`  
**Canvas:** 1024x1024, transparent · **In game:** 240x240 · **9-slice:** 40 all sides (160 px on the generated panel) · **State:** normal  
**Used in:** the decision sheets (take a gun, use a machine, pick a Patch, melee), abandon-run confirm, Settings

**Prompt:**

```
Original painted game UI element for a zombie card game, 1024x1024 canvas, transparent background.
Subject: a dialog panel that pops over the game, a little lighter than the tooltip, with a pale bone-gold rim to draw the eye.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Body: dark slate (#20262a, soft lift to #283035 upper right). Rim: pale bone-gold (#fff2b0, shade #c9b980).
Shape: one square rounded panel, 960x960 px, centred on the 1024x1024 canvas (32 px transparent margin), corner radius about 112 px, a 24 px dark ink outline, a 40 px painted rim just inside the outline. 9-slice: all detail (rim, bolts in the four corners, edge wear, bevel light) sits inside the outer 160 px band; the centre is a plain, even, dark painted surface with only a very soft gradient, so the panel stretches to any size and text stays readable on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** anything in the centre, a title bar, a close button.

### Image 48: Panel: overlay (Glossary / Codex)

**File:** `dd_panel_overlay.png`  
**Canvas:** 1024x1024, transparent · **In game:** 240x240 · **9-slice:** 40 all sides (160 px on the generated panel) · **State:** normal  
**Used in:** the Glossary and Codex overlays (header with Close, filters, scrolling list)

**Prompt:**

```
Original painted game UI element for a zombie card game, 1024x1024 canvas, transparent background.
Subject: a large full-screen reference panel, like the inside of a battered steel binder: the darkest panel, a quiet rim.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Body: very dark (#15181a). Rim: dim cool steel (#5e6866 to #808a86), muted.
Shape: one square rounded panel, 960x960 px, centred on the 1024x1024 canvas (32 px transparent margin), corner radius about 112 px, a 24 px dark ink outline, a 40 px painted rim just inside the outline. 9-slice: all detail (rim, bolts in the four corners, edge wear, bevel light) sits inside the outer 160 px band; the centre is a plain, even, dark painted surface with only a very soft gradient, so the panel stretches to any size and text stays readable on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a binder ring, paper, anything in the centre.

### Image 49: Panel: HUD strip

**File:** `dd_panel_hud.png`  
**Canvas:** 1024x1024, transparent · **In game:** 240x240 · **9-slice:** 40 all sides (160 px on the generated panel) · **State:** normal  
**Used in:** the event log strip, the hint bar with Got it, the Safehouse kit rows, the map survivor chip

**Prompt:**

```
Original painted game UI element for a zombie card game, 1024x1024 canvas, transparent background.
Subject: a flat, low-profile dark plate for information strips, like a dashboard faceplate: quieter than the dialogs, thin rim, small corner screws.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Body: dark slate (#20262a). Rim: thin dark steel (#2b3338).
Shape: one square rounded panel, 960x960 px, centred on the 1024x1024 canvas (32 px transparent margin), corner radius about 112 px, a 24 px dark ink outline, a 40 px painted rim just inside the outline. 9-slice: all detail (rim, bolts in the four corners, edge wear, bevel light) sits inside the outer 160 px band; the centre is a plain, even, dark painted surface with only a very soft gradient, so the panel stretches to any size and text stays readable on it.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** anything in the centre, a screen glare.

### Image 50: Name bar (card bottom)

**File:** `dd_bar_name.png`  
**Canvas:** 1536x1024, transparent · **In game:** 184x40 · **9-slice:** left 16, right 16, top 8, bottom 8 (128 / 64 px on the generated strip) · **State:** normal  
**Used in:** the name bar at the bottom of every card (name + value line)

**Prompt:**

```
Original painted game UI element for a zombie card game, 1536x1024 canvas, transparent background.
Subject: a dark ink-painted name strip, like a strip of black gaffer tape painted with a brush, rough only at the very ends.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Fill: ink black (#151214, a faint warm lift #221c1c along the top edge).
Shape: one long horizontal strip, 1472 px wide and 320 px tall, centred on the 1536x1024 canvas (32 px transparent margin left and right, 352 px top and bottom), corner radius about 48 px, a 16 px dark ink outline. 9-slice: detail only in the outer 128 px at each end and the outer 64 px at top and bottom; the middle is a plain, even dark fill for a name in bone-white letters.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** torn holes, white specks in the middle, any word.

### Image 51: Kill socket: empty

**File:** `dd_socket_empty.png`  
**Canvas:** 1024x1536, transparent · **In game:** 56x84 · **9-slice:** 8 all sides, edges tiled (axis stretch: tile) (128 px on the generated socket) · **State:** normal (empty)  
**Used in:** the empty kill sockets on gun tiles

**Prompt:**

```
Original painted game UI element for a zombie card game, 1024x1536 canvas, transparent background.
Subject: an empty slot for a card, painted as a dark recess with a dashed grey painted border (short even dashes all round).
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Recess: black at 30% opacity feel (#0b0b0c), dashes cool grey (#4f5b62).
Shape: one upright rounded-rectangle slot, 896 px wide and 1344 px tall, centred on the 1024x1536 canvas (64 px transparent margin left and right, 96 px top and bottom), corner radius about 64 px. 9-slice: detail only in the outer 128 px band; the centre is plain.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a solid border, anything inside the slot.

### Image 52: Kill socket: next

**File:** `dd_socket_next.png`  
**Canvas:** 1024x1536, transparent · **In game:** 56x84 · **9-slice:** 8 all sides, edges tiled (axis stretch: tile) (128 px on the generated socket) · **State:** highlighted (next)  
**Used in:** the next kill socket on gun tiles (the game writes what it accepts, e.g. >6, inside)

**Prompt:**

```
Original painted game UI element for a zombie card game, 1024x1536 canvas, transparent background.
Subject: the same slot, marked as the next one to fill: the dashed border painted in bright yellow with a faint warm glow inside the edge.
Style: bold painted comic game UI piece for a painted zombie card game: thick dark ink contour (#151214) around the outer edge and around every detail, painted fills with visible brushwork, three value steps (light, mid, shadow), one warm key light from the upper right (highlights along the top and right edges, shadow along the bottom and left edges), chunky and readable at small size. Material: salvaged survival gear, painted enamel on thick sheet metal with a few small bolts, chipped paint and light scuffs only at the edges; gritty but clean, never busy.
Palette: Recess: #0b0b0c, dashes hit yellow (#f2c14e).
Shape: one upright rounded-rectangle slot, 896 px wide and 1344 px tall, centred on the 1024x1536 canvas (64 px transparent margin left and right, 96 px top and bottom), corner radius about 64 px. 9-slice: detail only in the outer 128 px band; the centre is plain.
Transparent background: a PNG with a real alpha channel, no checkerboard, no white or coloured backdrop, nothing outside the shape. Flat front view, no perspective, no tilt, no cast shadow outside the shape. No text, no numbers, no letters, no icons, no symbols, no logos, no arrows. The game draws every word, number and icon on top.
```

**Avoid:** a solid border, any word or symbol inside.

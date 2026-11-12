# DeadDraw art pack 4: one zombie per number (prompts for ChatGPT)

**ChatGPT, read this first.** This file is a list of image requests for DeadDraw, an original zombie card game
(a street of zombie cards, guns that stack kills, melee weapons, heal and cover items, rooms behind doors, Patches,
bosses, and three districts: Maple Row, Downtown and St. Agnes Hospital). Every zombie card carries a number from 1 to
12; this pack gives each number its own zombie character. For each image below:
1. Generate ONE image from the text in its "Prompt" block, exactly as written, at 1536x1024 (landscape 3:2).
2. Do not add any text, letters, numbers, logos, brand names, insignia or real weapon or product models to the image.
   The game draws every word and number itself.
3. Give the image the file name shown on its "File" line, exactly (lowercase, `.png`).
4. If the person asks to redo an image, regenerate it and avoid what its "Avoid" line lists.
5. Keep every image in the same style (the "Shared style" block below is already inside every prompt), and keep the
   size order: each zombie must look bigger and more threatening than the one with the number before it. The same
   plain fire hydrant appears in every image at the same size, so the size step shows.
6. When a batch is done, push the PNGs to the GitHub repository on the branch `art/deaddraw-pack-4`, into the folder
   `projects/deaddraw/documentation/art/chatgpt/images/art-pack-4/` (create the branch from `main` if it does not
   exist; do not touch any other folder or the `main` branch). If you cannot push, give the person the files to
   download with these exact names.

Work through one batch at a time, in order. When the person says "Batch N", generate every image in that batch, one at
a time.

All art is original. Style: bold painted comic, chunky silhouettes, cartoon-level horror (never gore), one warm light.

Source: `projects/deaddraw/documentation/art/art-direction.md` (the art direction),
`projects/deaddraw/documentation/art/chatgpt/dd-art-pack-1-prompts.md` (batch 1, the four tier zombies this pack
extends) and `projects/deaddraw/documentation/art/art-pack-4-list.csv` (the list with game sizes).

**For the studio (not for ChatGPT):** zombie values in the game run 1-12 (every wave in `data/balance.json` uses
1-12, and the rules treat 1-12 as the legal range), so 12 images cover every card. The four tier paintings from pack 1
(`assets/art/painted/dd_zombie_shambler|lurcher|bruiser|hulk.webp`) stay in the game as fallbacks: the card uses
`dd_zombie_vNN` when it exists and the tier image otherwise. The tier word (Shambler, Lurcher, Bruiser, Hulk) stays the
rules name; the character name below is the card title or flavour line.

## The twelve zombies

| Value | Tier | Name | Look | Size in frame |
|---|---|---|---|---|
| 1 | Shambler | Slippers | frail old man in bathrobe and slippers, hugging a mug | 35% of height |
| 2 | Shambler | Librarian | thin, cardigan, crooked glasses, slipping books | 40% |
| 3 | Shambler | Postman | lanky mail carrier, empty satchel, arm reaching | 45% |
| 4 | Lurcher | Jogger | skinny jogger, one shoe, stumbling run | 48% |
| 5 | Lurcher | Courier | wiry bike courier in a hoodie, lunging | 52% |
| 6 | Lurcher | Night Cook | lanky diner cook, crouched to pounce | 56% (crouched) |
| 7 | Bruiser | Mover | barrel-chested mover in coveralls, crushed box | 60% |
| 8 | Bruiser | Road Crew | road worker, hard hat, hi-vis, dragging a cone | 63% |
| 9 | Bruiser | Bouncer | thick-necked bouncer, fists up | 66% |
| 10 | Hulk | Trucker | huge trucker in flannel, knuckles to the ground | 70%, hydrant at shin |
| 11 | Hulk | Strongman | circus strongman, bent barbell, silent roar | 75%, hydrant at ankle |
| 12 | Hulk | Titan | colossal dock worker, broken chain, hand reaching out | fills the frame, hydrant at toes |

How the size reads: Shamblers (1-3) are small and frail with dim eyes; Lurchers (4-6) are wiry and lunge or pounce;
Bruisers (7-9) are broad workers who stand their ground; Hulks (10-12) fill the frame and the hydrant only reaches
their shins, ankles, then toes. Each tier keeps one clothing palette, so the four tier families stay apart at a glance.

## Shared style (already part of every prompt)

```
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

Colour per card type (matches the badge and frame colours in the game): blood red = zombies.

| Batch | What | Images |
|---|---|---|
| 1 | Zombies 1-6 (Shamblers and Lurchers) | 6 |
| 2 | Zombies 7-12 (Bruisers and Hulks) | 6 |
| | **Total** | **12** |

---

## Batch 1: Zombies 1-6 (Shamblers and Lurchers)

Small to medium zombies. Every zombie is the same species, a slow, shabby, grey-green townsperson; the number reads from size and pose.

### Image 1: Slippers (Shambler, value 1)

**File:** `dd_zombie_v01.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one tiny, frail old zombie in a faded checked bathrobe and fuzzy slippers, very stooped, both hands cupped around an empty tea mug held to its chest, shuffling one slow step towards the viewer, full body visible, more sad than scary.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: zombie card. Backdrop a dusky blood-red to brown street at dusk (#3b2321 to #5c302a) with dark ruined rooftops; zombie skin muted green-grey (#8ea476, shade #62774f), small glowing pale-yellow eyes (#f4ea9c), torn clothes in desaturated browns, blues and greys. Blood red (#e2574c) only as a thin rim light and in the sky glow. Tier family: clothes in soft faded beige, dusty blue and cardigan browns; eyes small and dim.
Scale cue (same in every zombie image): a plain dark-red street fire hydrant with no markings stands on the pavement just right of the zombie's feet, inside the middle 60% of the width; the hydrant is always the same size, about 12% of the image height, so the zombie's size reads against it.
Composition: full-bleed painting, no border or frame. The ground line sits at about 80% of the height. The zombie is small: about 35% of the image height tall (from 45% to 80% of the height), with lots of dark street around it. It stands in the centre and stays inside the middle 60% of the width. Both top corners stay dark and empty: the top-left corner (left 30%, top 35%) holds the number badge, and the top-right corner (right 30%, top 30%) holds the damage chip and the lock tag; keep the head and hands in the middle band, away from both top corners. Keep the bottom 18% simple and dark: the card name goes there. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a big or menacing body, a raised arm, a second zombie, steam or liquid in the mug, anything important in the top-left or top-right corner.

### Image 2: Librarian (Shambler, value 2)

**File:** `dd_zombie_v02.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one thin zombie librarian in a long sagging cardigan and a calf-length skirt, round glasses hanging crooked from one ear, a small stack of blank-covered books slipping from one arm, the other arm lifted limply forward, head tilted, full body visible.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: zombie card. Backdrop a dusky blood-red to brown street at dusk (#3b2321 to #5c302a) with dark ruined rooftops; zombie skin muted green-grey (#8ea476, shade #62774f), small glowing pale-yellow eyes (#f4ea9c), torn clothes in desaturated browns, blues and greys. Blood red (#e2574c) only as a thin rim light and in the sky glow. Tier family: clothes in soft faded beige, dusty blue and cardigan browns; eyes small and dim.
Scale cue (same in every zombie image): a plain dark-red street fire hydrant with no markings stands on the pavement just right of the zombie's feet, inside the middle 60% of the width; the hydrant is always the same size, about 12% of the image height, so the zombie's size reads against it.
Composition: full-bleed painting, no border or frame. The ground line sits at about 80% of the height. The zombie is small: about 40% of the image height tall (from 40% to 80% of the height). It stands in the centre and stays inside the middle 60% of the width. Both top corners stay dark and empty: the top-left corner (left 30%, top 35%) holds the number badge, and the top-right corner (right 30%, top 30%) holds the damage chip and the lock tag; keep the head and hands in the middle band, away from both top corners. Keep the bottom 18% simple and dark: the card name goes there. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** readable book titles or covers, a fast or aggressive pose, a second zombie, anything important in the top-left or top-right corner.

### Image 3: Postman (Shambler, value 3)

**File:** `dd_zombie_v03.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one lanky, round-shouldered zombie mail carrier in a plain faded blue uniform shirt and shorts with a flat cap, an empty plain canvas satchel on its hip, one arm reaching straight out towards the viewer, mouth slack, full body visible.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: zombie card. Backdrop a dusky blood-red to brown street at dusk (#3b2321 to #5c302a) with dark ruined rooftops; zombie skin muted green-grey (#8ea476, shade #62774f), small glowing pale-yellow eyes (#f4ea9c), torn clothes in desaturated browns, blues and greys. Blood red (#e2574c) only as a thin rim light and in the sky glow. Tier family: clothes in soft faded beige, dusty blue and cardigan browns; eyes small and dim.
Scale cue (same in every zombie image): a plain dark-red street fire hydrant with no markings stands on the pavement just right of the zombie's feet, inside the middle 60% of the width; the hydrant is always the same size, about 12% of the image height, so the zombie's size reads against it.
Composition: full-bleed painting, no border or frame. The ground line sits at about 80% of the height. The zombie is medium-small: about 45% of the image height tall (from 35% to 80% of the height), the reaching hand the closest thing to the viewer. It stands in the centre and stays inside the middle 60% of the width. Both top corners stay dark and empty: the top-left corner (left 30%, top 35%) holds the number badge, and the top-right corner (right 30%, top 30%) holds the damage chip and the lock tag; keep the head and hands in the middle band, away from both top corners. Keep the bottom 18% simple and dark: the card name goes there. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** badges, patches or logos on the uniform or bag, letters with writing, an open mouth with teeth bared, a second zombie, anything important in the top-left or top-right corner.

### Image 4: Jogger (Lurcher, value 4)

**File:** `dd_zombie_v04.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one skinny zombie jogger in a torn plain tracksuit and one missing running shoe, a sweatband round its head, pitched far forward in a stumbling run to the right, one arm swinging, one arm grabbing ahead, full body visible.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: zombie card. Backdrop a dusky blood-red to brown street at dusk (#3b2321 to #5c302a) with dark ruined rooftops; zombie skin muted green-grey (#8ea476, shade #62774f), small glowing pale-yellow eyes (#f4ea9c), torn clothes in desaturated browns, blues and greys. Blood red (#e2574c) only as a thin rim light and in the sky glow. Tier family: clothes in washed denim, charcoal and faded olive; eyes a little brighter.
Scale cue (same in every zombie image): a plain dark-red street fire hydrant with no markings stands on the pavement just right of the zombie's feet, inside the middle 60% of the width; the hydrant is always the same size, about 12% of the image height, so the zombie's size reads against it.
Composition: full-bleed painting, no border or frame. The ground line sits at about 80% of the height. The zombie is medium: about 48% of the image height tall (from 32% to 80% of the height), its body a strong diagonal leaning right. It stands in the centre and stays inside the middle 60% of the width. Both top corners stay dark and empty: the top-left corner (left 30%, top 35%) holds the number badge, and the top-right corner (right 30%, top 30%) holds the damage chip and the lock tag; keep the head and hands in the middle band, away from both top corners. Keep the bottom 18% simple and dark: the card name goes there. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** stripes or logos on the tracksuit, an athletic sprinter look, a second zombie, anything important in the top-left or top-right corner.

### Image 5: Courier (Lurcher, value 5)

**File:** `dd_zombie_v05.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one wiry zombie bike courier in a torn hoodie, cargo shorts and a cracked plain bike helmet, a plain empty courier bag on its back, lunging hard forward to the right, knees bent, both arms out grabbing, fingers spread, full body visible.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: zombie card. Backdrop a dusky blood-red to brown street at dusk (#3b2321 to #5c302a) with dark ruined rooftops; zombie skin muted green-grey (#8ea476, shade #62774f), small glowing pale-yellow eyes (#f4ea9c), torn clothes in desaturated browns, blues and greys. Blood red (#e2574c) only as a thin rim light and in the sky glow. Tier family: clothes in washed denim, charcoal and faded olive; eyes a little brighter.
Scale cue (same in every zombie image): a plain dark-red street fire hydrant with no markings stands on the pavement just right of the zombie's feet, inside the middle 60% of the width; the hydrant is always the same size, about 12% of the image height, so the zombie's size reads against it.
Composition: full-bleed painting, no border or frame. The ground line sits at about 80% of the height. The zombie is medium: about 52% of the image height tall (from 28% to 80% of the height), its body a strong diagonal leaning right. It stands in the centre and stays inside the middle 60% of the width. Both top corners stay dark and empty: the top-left corner (left 30%, top 35%) holds the number badge, and the top-right corner (right 30%, top 30%) holds the damage chip and the lock tag; keep the head and hands in the middle band, away from both top corners. Keep the bottom 18% simple and dark: the card name goes there. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a bicycle, logos on the helmet or bag, a weapon, a second zombie, anything important in the top-left or top-right corner.

### Image 6: Night Cook (Lurcher, value 6)

**File:** `dd_zombie_v06.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one tall, lanky zombie diner cook in a grease-smudged plain white apron, a paper cook's hat askew and rolled-up sleeves, crouched low and coiled like it is about to pounce, both long arms spread wide, head pushed forward, eyes locked on the viewer, full body visible.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: zombie card. Backdrop a dusky blood-red to brown street at dusk (#3b2321 to #5c302a) with dark ruined rooftops; zombie skin muted green-grey (#8ea476, shade #62774f), small glowing pale-yellow eyes (#f4ea9c), torn clothes in desaturated browns, blues and greys. Blood red (#e2574c) only as a thin rim light and in the sky glow. Tier family: clothes in washed denim, charcoal and faded olive; eyes a little brighter.
Scale cue (same in every zombie image): a plain dark-red street fire hydrant with no markings stands on the pavement just right of the zombie's feet, inside the middle 60% of the width; the hydrant is always the same size, about 12% of the image height, so the zombie's size reads against it.
Composition: full-bleed painting, no border or frame. The ground line sits at about 80% of the height. The zombie is medium: about 56% of the image height tall when crouched (from 24% to 80% of the height), the widest of the Lurchers. It stands in the centre and stays inside the middle 60% of the width. Both top corners stay dark and empty: the top-left corner (left 30%, top 35%) holds the number badge, and the top-right corner (right 30%, top 30%) holds the damage chip and the lock tag; keep the head and hands in the middle band, away from both top corners. Keep the bottom 18% simple and dark: the card name goes there. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a knife, cleaver or any tool, food, red stains that read as blood, a second zombie, anything important in the top-left or top-right corner.

---

## Batch 2: Zombies 7-12 (Bruisers and Hulks)

Large to colossal zombies. Same species, same street, same hydrant; each one bigger and more threatening than the last.

### Image 7: Mover (Bruiser, value 7)

**File:** `dd_zombie_v07.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one broad, barrel-chested zombie furniture mover in plain dull-orange coveralls and a back-support belt, a heavy plain cardboard box crushed under one arm, the other heavy fist hanging, standing squarely and leaning slightly towards the viewer, full body visible.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: zombie card. Backdrop a dusky blood-red to brown street at dusk (#3b2321 to #5c302a) with dark ruined rooftops; zombie skin muted green-grey (#8ea476, shade #62774f), small glowing pale-yellow eyes (#f4ea9c), torn clothes in desaturated browns, blues and greys. Blood red (#e2574c) only as a thin rim light and in the sky glow. Tier family: clothes in dull ochre, rust and dirty work-orange; eyes bright.
Scale cue (same in every zombie image): a plain dark-red street fire hydrant with no markings stands on the pavement just right of the zombie's feet, inside the middle 60% of the width; the hydrant is always the same size, about 12% of the image height, so the zombie's size reads against it.
Composition: full-bleed painting, no border or frame. The ground line sits at about 80% of the height. The zombie is large: about 60% of the image height tall (from 20% to 80% of the height), clearly wider than any Lurcher. It stands in the centre and stays inside the middle 60% of the width. Both top corners stay dark and empty: the top-left corner (left 30%, top 35%) holds the number badge, and the top-right corner (right 30%, top 30%) holds the damage chip and the lock tag; keep the head and hands in the middle band, away from both top corners. Keep the bottom 18% simple and dark: the card name goes there. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** writing or tape with writing on the box, logos on the coveralls, a second zombie, anything important in the top-left or top-right corner.

### Image 8: Road Crew (Bruiser, value 8)

**File:** `dd_zombie_v08.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one broad, square-shouldered zombie road worker in a plain hard hat and a hi-vis safety vest with reflective stripes (no writing), dragging a bent plain traffic cone by one hand, the other heavy fist raised to chest height, stomping forward, full body visible.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: zombie card. Backdrop a dusky blood-red to brown street at dusk (#3b2321 to #5c302a) with dark ruined rooftops; zombie skin muted green-grey (#8ea476, shade #62774f), small glowing pale-yellow eyes (#f4ea9c), torn clothes in desaturated browns, blues and greys. Blood red (#e2574c) only as a thin rim light and in the sky glow. Tier family: clothes in dull ochre, rust and dirty work-orange; eyes bright.
Scale cue (same in every zombie image): a plain dark-red street fire hydrant with no markings stands on the pavement just right of the zombie's feet, inside the middle 60% of the width; the hydrant is always the same size, about 12% of the image height, so the zombie's size reads against it.
Composition: full-bleed painting, no border or frame. The ground line sits at about 80% of the height. The zombie is large: about 63% of the image height tall (from 17% to 80% of the height), shoulders filling about 40% of the width. It stands in the centre and stays inside the middle 60% of the width. Both top corners stay dark and empty: the top-left corner (left 30%, top 35%) holds the number badge, and the top-right corner (right 30%, top 30%) holds the damage chip and the lock tag; keep the head and hands in the middle band, away from both top corners. Keep the bottom 18% simple and dark: the card name goes there. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** writing or logos on the vest, helmet or cone, power tools, a second zombie, anything important in the top-left or top-right corner.

### Image 9: Bouncer (Bruiser, value 9)

**File:** `dd_zombie_v09.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one huge, thick-necked zombie nightclub bouncer in a tight torn black T-shirt and dark trousers, a plain earpiece wire hanging loose, shaved head, standing in a wide stance with both massive fists raised and knuckles forward, glaring down at the viewer, full body visible.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: zombie card. Backdrop a dusky blood-red to brown street at dusk (#3b2321 to #5c302a) with dark ruined rooftops; zombie skin muted green-grey (#8ea476, shade #62774f), small glowing pale-yellow eyes (#f4ea9c), torn clothes in desaturated browns, blues and greys. Blood red (#e2574c) only as a thin rim light and in the sky glow. Tier family: clothes in dull ochre, rust and dirty work-orange; eyes bright.
Scale cue (same in every zombie image): a plain dark-red street fire hydrant with no markings stands on the pavement just right of the zombie's feet, inside the middle 60% of the width; the hydrant is always the same size, about 12% of the image height, so the zombie's size reads against it.
Composition: full-bleed painting, no border or frame. The ground line sits at about 80% of the height. The zombie is very large: about 66% of the image height tall (from 14% to 80% of the height), shoulders filling about 45% of the width, its head centred. It stands in the centre and stays inside the middle 60% of the width. Both top corners stay dark and empty: the top-left corner (left 30%, top 35%) holds the number badge, and the top-right corner (right 30%, top 30%) holds the damage chip and the lock tag; keep the head and hands in the middle band, away from both top corners. Keep the bottom 18% simple and dark: the card name goes there. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** writing on the shirt, a rope barrier with signs, brass knuckles or any weapon, a second zombie, anything important in the top-left or top-right corner.

### Image 10: Trucker (Hulk, value 10)

**File:** `dd_zombie_v10.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one enormous hulking zombie trucker in a torn plaid flannel shirt and a plain trucker cap, a small head sunk between huge rounded shoulders, a big belly, knuckles almost touching the ground, leaning towards the viewer, a dark idling truck grille (no logo) far behind it.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: zombie card. Backdrop a dusky blood-red to brown street at dusk (#3b2321 to #5c302a) with dark ruined rooftops; zombie skin muted green-grey (#8ea476, shade #62774f), small glowing pale-yellow eyes (#f4ea9c), torn clothes in desaturated browns, blues and greys. Blood red (#e2574c) only as a thin rim light and in the sky glow. Tier family: clothes in dark rust, oxblood brown and soot black; eyes bright and wide set, a faint pale-yellow glow on the face.
Scale cue (same in every zombie image): a plain dark-red street fire hydrant with no markings stands on the pavement just right of the zombie's feet, inside the middle 60% of the width; the hydrant is always the same size, about 12% of the image height, so the zombie's size reads against it.
Composition: full-bleed painting, no border or frame. The ground line sits at about 80% of the height. The zombie is enormous: about 70% of the image height tall (from 10% to 80% of the height), filling about 50% of the width; the hydrant reaches only its shin. It stands in the centre and stays inside the middle 60% of the width. Its shoulders stay in shadow below both top corners. Both top corners stay dark and empty: the top-left corner (left 30%, top 35%) holds the number badge, and the top-right corner (right 30%, top 30%) holds the damage chip and the lock tag; keep the head and hands in the middle band, away from both top corners. Keep the bottom 18% simple and dark: the card name goes there. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a logo on the cap or truck, headlights glaring at the viewer, a superhero look, a second zombie, anything important in the top-left or top-right corner.

### Image 11: Strongman (Hulk, value 11)

**File:** `dd_zombie_v11.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one gigantic zombie circus strongman in a torn striped singlet and a wide belt (no buckle design), a curled handlebar moustache, a tiny head on a massive neck, arms like barrels holding a bent plain iron barbell across its chest, roaring silently, legs planted wide.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: zombie card. Backdrop a dusky blood-red to brown street at dusk (#3b2321 to #5c302a) with dark ruined rooftops; zombie skin muted green-grey (#8ea476, shade #62774f), small glowing pale-yellow eyes (#f4ea9c), torn clothes in desaturated browns, blues and greys. Blood red (#e2574c) only as a thin rim light and in the sky glow. Tier family: clothes in dark rust, oxblood brown and soot black; eyes bright and wide set, a faint pale-yellow glow on the face.
Scale cue (same in every zombie image): a plain dark-red street fire hydrant with no markings stands on the pavement just right of the zombie's feet, inside the middle 60% of the width; the hydrant is always the same size, about 12% of the image height, so the zombie's size reads against it.
Composition: full-bleed painting, no border or frame. The ground line sits at about 80% of the height. The zombie is gigantic: about 75% of the image height tall (from 5% to 80% of the height, its head centred near the top), filling about 55% of the width; the hydrant reaches only its ankle. It stands in the centre and stays inside the middle 60% of the width. Its shoulders stay in shadow below both top corners. Both top corners stay dark and empty: the top-left corner (left 30%, top 35%) holds the number badge, and the top-right corner (right 30%, top 30%) holds the damage chip and the lock tag; keep the head and hands in the middle band, away from both top corners. Keep the bottom 18% simple and dark: the card name goes there. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a circus tent or poster with writing, weights with numbers, veins in detail, a monster that is not human, a second zombie, anything important in the top-left or top-right corner.

### Image 12: Titan (Hulk, value 12)

**File:** `dd_zombie_v12.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: one colossal zombie dock worker, the biggest of them all, in a ripped heavy work coat and a snapped chain hanging from one wrist like a bracelet, hunched under a bent streetlamp it has pushed aside, a tiny head between mountainous shoulders, one huge hand planted on the pavement and the other reaching towards the viewer so the palm fills a quarter of the frame.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: zombie card. Backdrop a dusky blood-red to brown street at dusk (#3b2321 to #5c302a) with dark ruined rooftops; zombie skin muted green-grey (#8ea476, shade #62774f), small glowing pale-yellow eyes (#f4ea9c), torn clothes in desaturated browns, blues and greys. Blood red (#e2574c) only as a thin rim light and in the sky glow. Tier family: clothes in dark rust, oxblood brown and soot black; eyes bright and wide set, a faint pale-yellow glow on the face.
Scale cue (same in every zombie image): a plain dark-red street fire hydrant with no markings stands on the pavement just right of the zombie's feet, inside the middle 60% of the width; the hydrant is always the same size, about 12% of the image height, so the zombie's size reads against it.
Composition: full-bleed painting, no border or frame. The ground line sits at about 80% of the height. The zombie is colossal: it fills the frame from the top edge to 80% of the height and about 60% of the width, its tiny head centred just under the top edge and its huge shoulders sloping down so they stay below the top 35% at the sides; the hydrant reaches only its toes. It stands in the centre and stays inside the middle 60% of the width. Its shoulders stay in shadow below both top corners. Both top corners stay dark and empty: the top-left corner (left 30%, top 35%) holds the number badge, and the top-right corner (right 30%, top 30%) holds the damage chip and the lock tag; keep the head and hands in the middle band, away from both top corners. Keep the bottom 18% simple and dark: the card name goes there. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a non-human monster, horns or spikes, gore or exposed bones, a second zombie, the reaching hand covering a top corner, anything important in the top-left or top-right corner.


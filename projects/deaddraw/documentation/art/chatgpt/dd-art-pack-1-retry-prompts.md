# DeadDraw art pack 1: retry prompts for ChatGPT (2 images)

**ChatGPT, read this first.** This file has 2 image requests for DeadDraw, an original zombie card game. They redo
images from art pack 1 that were blocked or rejected in review. For each image below:
1. Generate ONE image from the text in its "Prompt" block, exactly as written. Landscape 3:2, 1536x1024.
2. Do not add any text, letters, numbers, logos, brand names, insignia or real weapon or product models.
3. Give the image the file name shown on its "File" line, exactly (lowercase, `.png`).
4. If the person asks to redo an image, regenerate it and avoid what its "Avoid" line lists.
Generate the 2 images one at a time, in order.

Style for both: bold painted comic, thick dark ink contour, chunky silhouettes, cartoon-level horror (never gore),
one warm key light from the upper right. Same look as the rest of pack 1.

When done, push the 2 PNGs to the same branch and folder as pack 1: `art/deaddraw-pack-1`,
`projects/deaddraw/documentation/art/chatgpt/images/art-pack-1/` (same file names; the title replaces the rejected
one there). Do not touch `main`.

---

### Retry 1: Retrofit Bench

*Why a retry:* the first request was blocked by the image service (moderation, "violence"), most likely because of
the words "gun parts". This version shows a plain tinkering bench with generic metal parts; the game adds the
meaning.

**File:** `dd_machine_retrofit_bench.png`

**Prompt:**

```
Original painted game illustration for a card game, 1536x1024 (landscape 3:2).
Subject: a grimy wooden workbench in a garage workshop: a small hand-cranked lathe, a heavy bench vice, a tray of loose springs, screws, brass fittings and small metal tubes, a hand drill, a file and a rag, one hanging lamp over it. No people.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: workshop machine. Backdrop a dim tiled workshop wall (#22282c) with copper (#d9a066) lamp light; the bench in dark wood, rusty steel, copper and chipped green enamel.
Composition: full-bleed painting, no border or frame. The bench sits in the centre and fills the middle 60% of the width and the band from 20% to 80% of the height. Keep the top-left corner (left 30%, top 35%) dark and empty: a number badge goes there. Keep the bottom 18% simple and dark: the card name goes there. Keep the top-right corner calm. The game crops this image to a near-square on phones, so nothing important may sit in the outer 20% on the left or right.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real products, no known characters. Cartoon level only.
```

**Avoid:** any weapon, bullets or cartridges, hands or people, writing on tools or boxes.

---

### Retry 2: Title screen (desktop, landscape)

*Why a retry:* the three survivors did not read as the cast (no doctor, no pipe wrench; a muscle man with a red
headband, a girl in a plaid skirt and a hoodie kid instead of the mechanic, the doctor and the courier), the figures
were drawn in a flatter anime look than the rest of the pack, and the scene did not match the portrait title.

**File:** `dd_title_landscape.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: three survivors seen from behind, standing side by side on a cracked suburban street at dusk, looking towards a city skyline and an old hospital block where a crowd of zombie silhouettes shambles towards them; a giant playing card lies face down on the road in front of them. Left: a sturdy mechanic in oil-stained blue coveralls with a teal bandana, a big red pipe wrench hanging from one hand. Middle: a doctor in a white coat and green scrubs carrying a boxy medical bag. Right: a bike courier in a windbreaker with an amber cap turned backwards and a messenger bag across the back. All three seen from behind, faces not visible.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: dusk orange sky fading to deep purple night, zombie silhouettes in muted green-grey, warm street light on the survivors.
Composition: key art for a desktop title screen. Leave the left 40% calm and dark, plain dusky sky and empty road (the game logo and buttons go there); the survivors, the card and the crowd sit on the right 60%. Keep the bottom 12% simple.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a headband or bandana in red, a skirt, a backpack, guns, faces turned to the viewer, anime-style
proportions, text or a logo, button shapes on the left.

# DeadDraw art pack 5: weapon cut-outs and card backdrops (prompts for ChatGPT)

**ChatGPT, read this first.** This file is a list of image requests for DeadDraw, an original zombie card game
(a street of zombie cards, guns that stack kills, melee weapons, heal and cover items, rooms behind doors, Patches,
bosses, and three districts: Maple Row, Downtown and St. Agnes Hospital). This pack splits the weapon card art into two
layers: each gun and melee weapon as a cut-out on a transparent background, and a few empty painted backdrops the game
puts behind them. For each image below:
1. Generate ONE image from the text in its "Prompt" block, exactly as written, at 1536x1024 (landscape 3:2).
2. Do not add any text, letters, numbers, logos, brand names, insignia or real weapon or product models to the image.
   The game draws every word and number itself.
3. Batches 1 and 2 are **transparent cut-outs**: output a PNG with a real alpha channel. No checkerboard pattern, no
   white or grey fill, no wall, no floor, no cast shadow. Only the object.
4. Batch 3 is **backdrops only**: full-bleed paintings with nothing in front of them.
5. Give the image the file name shown on its "File" line, exactly (lowercase, `.png`).
6. If the person asks to redo an image, regenerate it and avoid what its "Avoid" line lists.
7. Keep every image in the same style (the "Shared style" block below is already inside every prompt). In batches 1 and
   2 keep the SAME camera, light and scale for every object (the "Camera" and "Scale" lines), so the cut-outs can be
   compared side by side: a pistol is clearly smaller than a rifle, every time.
8. When a batch is done, push the PNGs to the GitHub repository on the branch `art/deaddraw-pack-5`, into the folder
   `projects/deaddraw/documentation/art/chatgpt/images/art-pack-5/` (create the branch from `main` if it does not
   exist; do not touch any other folder or the `main` branch). If you cannot push, give the person the files to
   download with these exact names.

Work through one batch at a time, in order. When the person says "Batch N", generate every image in that batch, one at
a time.

All art is original. Style: bold painted comic, chunky silhouettes, cartoon-level horror (never gore), one warm light.

Source: `projects/deaddraw/documentation/art/art-direction.md` (the art direction, see "Layered weapon cards (art pack
5)"), `projects/deaddraw/documentation/art/chatgpt/dd-art-pack-1-prompts.md` (batches 2 and 3, the weapon looks this
pack keeps) and `projects/deaddraw/documentation/art/art-pack-5-list.csv` (the list with game sizes).

**For the studio (not for ChatGPT):** the weapon list comes from `data/balance.json` (`weapons`: 11 guns;
`melee_weapons`: wrench, axe, sledge) plus Bare Hands, which has pack 1 art (`dd_melee_bare_hands`) and shows in the
melee slot. The pack 1 full-bleed paintings stay in the game as the fallback until the cut-outs pass review. The
Elephant Gun's loose brass cartridge from pack 1 is left out so its alpha box is the gun alone.

## Shared style (already part of every prompt)

```
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

## Shared camera and cut-out rules (already part of every batch 1 and 2 prompt)

```
Camera: one fixed product-shot camera for the whole set: a 3/4 side view (we see the right side of the object and a little of its top), the muzzle or striking end pointing to the RIGHT, handle or stock on the left, the long axis level with only a slight upward tilt of about 5 degrees towards the right. The object's centre sits at 50% width and 52% height.
Background: a TRUE transparent cut-out: a PNG with a real alpha channel. Nothing but the object: no backdrop, no wall, no table, no ground, no floor line, no cast shadow, no glow, no vignette, no checkerboard, no white or grey fill. A very soft contact shadow directly under the object is allowed only if it fades fully to transparent within a few pixels; otherwise leave it out. Clean ink edge all round; no stray paint specks around the silhouette.
```

## Scale bands

One real-world scale for the whole set; the share of the 1536 px width each object spans. The game keeps this ratio
(it scales every cut-out by the same factor, never fit-to-box), so sizes compare across cards.

| Class | Width | Weapons |
|---|---|---|
| XS | 38% | Service Pistol |
| S | 48-56% | Nail Driver, Alley Sweeper, Bare Hands, Pipe Wrench |
| M | 66-70% | Twin-Bore, Scout Carbine, Ratchet Crossbow, Stovepipe Launcher |
| L | 76-82% | Pump Shotgun, Lever Rifle, Hunting Rifle, Fire Axe, Sledgehammer |
| XL | 88% | Elephant Gun |

| Batch | What | Images |
|---|---|---|
| 1 | Gun cut-outs (transparent) | 11 |
| 2 | Melee cut-outs (transparent) | 4 |
| 3 | Card backdrops (no objects) | 5 |
| | **Total** | **20** |


---

## Batch 1: Gun cut-outs

Eleven guns, one camera. Each must be told apart by silhouette alone, and the size order must hold.

### Image 1: Service Pistol (the starting gun)

**File:** `dd_cut_gun_service_pistol.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2), transparent PNG.
Subject: one plain, boxy, compact pistol with a worn grip.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. The gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge from the key light; a faint cool blue (#2e4a5f) bounce on the underside from the fill. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm or product model. Keep the look of the earlier DeadDraw painting of this weapon (same shapes, materials and colours) so players recognise it.
Camera: one fixed product-shot camera for the whole set: a 3/4 side view (we see the right side of the object and a little of its top), the muzzle or striking end pointing to the RIGHT, handle or stock on the left, the long axis level with only a slight upward tilt of about 5 degrees towards the right. The object's centre sits at 50% width and 52% height.
Scale: size class XS (handgun): the object spans 38% of the image width (from 31% to 69%), never more. Every image in this pack is drawn at the same real-world scale, so a pistol must look clearly smaller than a rifle when the images sit side by side. Keep at least 6% clear transparent margin at the top and bottom.
Background: a TRUE transparent cut-out: a PNG with a real alpha channel. Nothing but the object: no backdrop, no wall, no table, no ground, no floor line, no cast shadow, no glow, no vignette, no checkerboard, no white or grey fill. A very soft contact shadow directly under the object is allowed only if it fades fully to transparent within a few pixels; otherwise leave it out. Clean ink edge all round; no stray paint specks around the silhouette.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** chrome, gold, laser sights. Real gun brands or models, writing or serial numbers, a hand. A backdrop, floor or cast shadow; a checkerboard or white fill.

### Image 2: Nail Driver

**File:** `dd_cut_gun_nail_driver.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2), transparent PNG.
Subject: one bright orange construction nail gun (a tool, not a firearm) with a strip of nails and a short loop of coiled air hose tucked under the grip (the hose stays inside the object's outline, no long trailing hose).
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. The gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge from the key light; a faint cool blue (#2e4a5f) bounce on the underside from the fill. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm or product model. Keep the look of the earlier DeadDraw painting of this weapon (same shapes, materials and colours) so players recognise it.
Camera: one fixed product-shot camera for the whole set: a 3/4 side view (we see the right side of the object and a little of its top), the muzzle or striking end pointing to the RIGHT, handle or stock on the left, the long axis level with only a slight upward tilt of about 5 degrees towards the right. The object's centre sits at 50% width and 52% height.
Scale: size class S (short tool or stubby gun): the object spans 48% of the image width (from 26% to 74%), never more. Every image in this pack is drawn at the same real-world scale, so a pistol must look clearly smaller than a rifle when the images sit side by side. Keep at least 6% clear transparent margin at the top and bottom.
Background: a TRUE transparent cut-out: a PNG with a real alpha channel. Nothing but the object: no backdrop, no wall, no table, no ground, no floor line, no cast shadow, no glow, no vignette, no checkerboard, no white or grey fill. A very soft contact shadow directly under the object is allowed only if it fades fully to transparent within a few pixels; otherwise leave it out. Clean ink edge all round; no stray paint specks around the silhouette.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** brand colours or logos, a firearm shape, a hose trailing off the edge. Real gun brands or models, writing or serial numbers, a hand. A backdrop, floor or cast shadow; a checkerboard or white fill.

### Image 3: Alley Sweeper

**File:** `dd_cut_gun_alley_sweeper.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2), transparent PNG.
Subject: one stubby wide-mouthed blunderbuss-like scattergun built from plumbing pipe and a broom-handle stock, a flared funnel muzzle.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. The gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge from the key light; a faint cool blue (#2e4a5f) bounce on the underside from the fill. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm or product model. Keep the look of the earlier DeadDraw painting of this weapon (same shapes, materials and colours) so players recognise it.
Camera: one fixed product-shot camera for the whole set: a 3/4 side view (we see the right side of the object and a little of its top), the muzzle or striking end pointing to the RIGHT, handle or stock on the left, the long axis level with only a slight upward tilt of about 5 degrees towards the right. The object's centre sits at 50% width and 52% height.
Scale: size class S (short tool or stubby gun): the object spans 56% of the image width (from 22% to 78%), never more. Every image in this pack is drawn at the same real-world scale, so a pistol must look clearly smaller than a rifle when the images sit side by side. Keep at least 6% clear transparent margin at the top and bottom.
Background: a TRUE transparent cut-out: a PNG with a real alpha channel. Nothing but the object: no backdrop, no wall, no table, no ground, no floor line, no cast shadow, no glow, no vignette, no checkerboard, no white or grey fill. A very soft contact shadow directly under the object is allowed only if it fades fully to transparent within a few pixels; otherwise leave it out. Clean ink edge all round; no stray paint specks around the silhouette.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a pirate theme, a real shotgun model. Real gun brands or models, writing or serial numbers, a hand. A backdrop, floor or cast shadow; a checkerboard or white fill.

### Image 4: Twin-Bore

**File:** `dd_cut_gun_twin_bore.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2), transparent PNG.
Subject: one short over-and-under double-barrel shotgun with a wooden stock; the two stacked barrel mouths read clearly at the right end.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. The gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge from the key light; a faint cool blue (#2e4a5f) bounce on the underside from the fill. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm or product model. Keep the look of the earlier DeadDraw painting of this weapon (same shapes, materials and colours) so players recognise it.
Camera: one fixed product-shot camera for the whole set: a 3/4 side view (we see the right side of the object and a little of its top), the muzzle or striking end pointing to the RIGHT, handle or stock on the left, the long axis level with only a slight upward tilt of about 5 degrees towards the right. The object's centre sits at 50% width and 52% height.
Scale: size class M (short long-arm): the object spans 66% of the image width (from 17% to 83%), never more. Every image in this pack is drawn at the same real-world scale, so a pistol must look clearly smaller than a rifle when the images sit side by side. Keep at least 6% clear transparent margin at the top and bottom.
Background: a TRUE transparent cut-out: a PNG with a real alpha channel. Nothing but the object: no backdrop, no wall, no table, no ground, no floor line, no cast shadow, no glow, no vignette, no checkerboard, no white or grey fill. A very soft contact shadow directly under the object is allowed only if it fades fully to transparent within a few pixels; otherwise leave it out. Clean ink edge all round; no stray paint specks around the silhouette.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** side-by-side barrels, engraving. Real gun brands or models, writing or serial numbers, a hand. A backdrop, floor or cast shadow; a checkerboard or white fill.

### Image 5: Scout Carbine

**File:** `dd_cut_gun_scout_carbine.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2), transparent PNG.
Subject: one short, light carbine with a simple folding stock, a slim magazine and a small round sight.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. The gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge from the key light; a faint cool blue (#2e4a5f) bounce on the underside from the fill. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm or product model. Keep the look of the earlier DeadDraw painting of this weapon (same shapes, materials and colours) so players recognise it.
Camera: one fixed product-shot camera for the whole set: a 3/4 side view (we see the right side of the object and a little of its top), the muzzle or striking end pointing to the RIGHT, handle or stock on the left, the long axis level with only a slight upward tilt of about 5 degrees towards the right. The object's centre sits at 50% width and 52% height.
Scale: size class M (short long-arm): the object spans 66% of the image width (from 17% to 83%), never more. Every image in this pack is drawn at the same real-world scale, so a pistol must look clearly smaller than a rifle when the images sit side by side. Keep at least 6% clear transparent margin at the top and bottom.
Background: a TRUE transparent cut-out: a PNG with a real alpha channel. Nothing but the object: no backdrop, no wall, no table, no ground, no floor line, no cast shadow, no glow, no vignette, no checkerboard, no white or grey fill. A very soft contact shadow directly under the object is allowed only if it fades fully to transparent within a few pixels; otherwise leave it out. Clean ink edge all round; no stray paint specks around the silhouette.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a military assault rifle look, rails full of attachments. Real gun brands or models, writing or serial numbers, a hand. A backdrop, floor or cast shadow; a checkerboard or white fill.

### Image 6: Ratchet Crossbow

**File:** `dd_cut_gun_ratchet_crossbow.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2), transparent PNG.
Subject: one homemade crossbow made from a wooden stock, a bent leaf-spring bow and a hand-crank ratchet, one bolt loaded; the 3/4 view shows the bow's curve.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. The gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge from the key light; a faint cool blue (#2e4a5f) bounce on the underside from the fill. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm or product model. Keep the look of the earlier DeadDraw painting of this weapon (same shapes, materials and colours) so players recognise it.
Camera: one fixed product-shot camera for the whole set: a 3/4 side view (we see the right side of the object and a little of its top), the muzzle or striking end pointing to the RIGHT, handle or stock on the left, the long axis level with only a slight upward tilt of about 5 degrees towards the right. The object's centre sits at 50% width and 52% height.
Scale: size class M (short long-arm): the object spans 68% of the image width (from 16% to 84%), never more. Every image in this pack is drawn at the same real-world scale, so a pistol must look clearly smaller than a rifle when the images sit side by side. Keep at least 6% clear transparent margin at the top and bottom.
Background: a TRUE transparent cut-out: a PNG with a real alpha channel. Nothing but the object: no backdrop, no wall, no table, no ground, no floor line, no cast shadow, no glow, no vignette, no checkerboard, no white or grey fill. A very soft contact shadow directly under the object is allowed only if it fades fully to transparent within a few pixels; otherwise leave it out. Clean ink edge all round; no stray paint specks around the silhouette.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a fantasy or medieval crossbow, glowing parts. Real gun brands or models, writing or serial numbers, a hand. A backdrop, floor or cast shadow; a checkerboard or white fill.

### Image 7: Stovepipe Launcher

**File:** `dd_cut_gun_stovepipe_launcher.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2), transparent PNG.
Subject: one homemade one-shot launcher made from a dented stovepipe tube strapped to a wooden handle with hose clamps, a fat round homemade projectile sticking out of the right end.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. The gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge from the key light; a faint cool blue (#2e4a5f) bounce on the underside from the fill. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm or product model. Keep the look of the earlier DeadDraw painting of this weapon (same shapes, materials and colours) so players recognise it.
Camera: one fixed product-shot camera for the whole set: a 3/4 side view (we see the right side of the object and a little of its top), the muzzle or striking end pointing to the RIGHT, handle or stock on the left, the long axis level with only a slight upward tilt of about 5 degrees towards the right. The object's centre sits at 50% width and 52% height.
Scale: size class M (short long-arm): the object spans 70% of the image width (from 15% to 85%), never more. Every image in this pack is drawn at the same real-world scale, so a pistol must look clearly smaller than a rifle when the images sit side by side. Keep at least 6% clear transparent margin at the top and bottom.
Background: a TRUE transparent cut-out: a PNG with a real alpha channel. Nothing but the object: no backdrop, no wall, no table, no ground, no floor line, no cast shadow, no glow, no vignette, no checkerboard, no white or grey fill. A very soft contact shadow directly under the object is allowed only if it fades fully to transparent within a few pixels; otherwise leave it out. Clean ink edge all round; no stray paint specks around the silhouette.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a military rocket launcher, fire or an explosion. Real gun brands or models, writing or serial numbers, a hand. A backdrop, floor or cast shadow; a checkerboard or white fill.

### Image 8: Pump Shotgun

**File:** `dd_cut_gun_pump_shotgun.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2), transparent PNG.
Subject: one sturdy pump-action shotgun with a dark wooden pump grip and a thick single barrel.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. The gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge from the key light; a faint cool blue (#2e4a5f) bounce on the underside from the fill. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm or product model. Keep the look of the earlier DeadDraw painting of this weapon (same shapes, materials and colours) so players recognise it.
Camera: one fixed product-shot camera for the whole set: a 3/4 side view (we see the right side of the object and a little of its top), the muzzle or striking end pointing to the RIGHT, handle or stock on the left, the long axis level with only a slight upward tilt of about 5 degrees towards the right. The object's centre sits at 50% width and 52% height.
Scale: size class L (full-length long-arm or long-handled tool): the object spans 78% of the image width (from 11% to 89%), never more. Every image in this pack is drawn at the same real-world scale, so a pistol must look clearly smaller than a rifle when the images sit side by side. Keep at least 6% clear transparent margin at the top and bottom.
Background: a TRUE transparent cut-out: a PNG with a real alpha channel. Nothing but the object: no backdrop, no wall, no table, no ground, no floor line, no cast shadow, no glow, no vignette, no checkerboard, no white or grey fill. A very soft contact shadow directly under the object is allowed only if it fades fully to transparent within a few pixels; otherwise leave it out. Clean ink edge all round; no stray paint specks around the silhouette.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a sawn-off barrel, a drum magazine. Real gun brands or models, writing or serial numbers, a hand. A backdrop, floor or cast shadow; a checkerboard or white fill.

### Image 9: Lever Rifle

**File:** `dd_cut_gun_lever_rifle.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2), transparent PNG.
Subject: one frontier-style lever-action rifle with a dull brass receiver and a big loop lever under it.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. The gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge from the key light; a faint cool blue (#2e4a5f) bounce on the underside from the fill. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm or product model. Keep the look of the earlier DeadDraw painting of this weapon (same shapes, materials and colours) so players recognise it.
Camera: one fixed product-shot camera for the whole set: a 3/4 side view (we see the right side of the object and a little of its top), the muzzle or striking end pointing to the RIGHT, handle or stock on the left, the long axis level with only a slight upward tilt of about 5 degrees towards the right. The object's centre sits at 50% width and 52% height.
Scale: size class L (full-length long-arm or long-handled tool): the object spans 80% of the image width (from 10% to 90%), never more. Every image in this pack is drawn at the same real-world scale, so a pistol must look clearly smaller than a rifle when the images sit side by side. Keep at least 6% clear transparent margin at the top and bottom.
Background: a TRUE transparent cut-out: a PNG with a real alpha channel. Nothing but the object: no backdrop, no wall, no table, no ground, no floor line, no cast shadow, no glow, no vignette, no checkerboard, no white or grey fill. A very soft contact shadow directly under the object is allowed only if it fades fully to transparent within a few pixels; otherwise leave it out. Clean ink edge all round; no stray paint specks around the silhouette.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a scope, a western cowboy scene. Real gun brands or models, writing or serial numbers, a hand. A backdrop, floor or cast shadow; a checkerboard or white fill.

### Image 10: Hunting Rifle

**File:** `dd_cut_gun_hunting_rifle.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2), transparent PNG.
Subject: one long wooden-stocked bolt-action hunting rifle with a short scope and a brass barrel band.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. The gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge from the key light; a faint cool blue (#2e4a5f) bounce on the underside from the fill. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm or product model. Keep the look of the earlier DeadDraw painting of this weapon (same shapes, materials and colours) so players recognise it.
Camera: one fixed product-shot camera for the whole set: a 3/4 side view (we see the right side of the object and a little of its top), the muzzle or striking end pointing to the RIGHT, handle or stock on the left, the long axis level with only a slight upward tilt of about 5 degrees towards the right. The object's centre sits at 50% width and 52% height.
Scale: size class L (full-length long-arm or long-handled tool): the object spans 82% of the image width (from 9% to 91%), never more. Every image in this pack is drawn at the same real-world scale, so a pistol must look clearly smaller than a rifle when the images sit side by side. Keep at least 6% clear transparent margin at the top and bottom.
Background: a TRUE transparent cut-out: a PNG with a real alpha channel. Nothing but the object: no backdrop, no wall, no table, no ground, no floor line, no cast shadow, no glow, no vignette, no checkerboard, no white or grey fill. A very soft contact shadow directly under the object is allowed only if it fades fully to transparent within a few pixels; otherwise leave it out. Clean ink edge all round; no stray paint specks around the silhouette.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** camouflage, a bipod. Real gun brands or models, writing or serial numbers, a hand. A backdrop, floor or cast shadow; a checkerboard or white fill.

### Image 11: Elephant Gun

**File:** `dd_cut_gun_elephant_gun.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2), transparent PNG.
Subject: one huge, heavy old big-game rifle with a long thick barrel and a dark wooden stock, the biggest and thickest gun of the set (pack 1 showed a brass cartridge beside it; leave the cartridge out here, the gun alone).
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: gun card. The gun in gunmetal grey, worn wood and dull brass; a hot yellow (#f2c14e) highlight along the top edge from the key light; a faint cool blue (#2e4a5f) bounce on the underside from the fill. No ammunition flying, no muzzle flash, nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm or product model. Keep the look of the earlier DeadDraw painting of this weapon (same shapes, materials and colours) so players recognise it.
Camera: one fixed product-shot camera for the whole set: a 3/4 side view (we see the right side of the object and a little of its top), the muzzle or striking end pointing to the RIGHT, handle or stock on the left, the long axis level with only a slight upward tilt of about 5 degrees towards the right. The object's centre sits at 50% width and 52% height.
Scale: size class XL (the largest object in the set): the object spans 88% of the image width (from 6% to 94%), never more. Every image in this pack is drawn at the same real-world scale, so a pistol must look clearly smaller than a rifle when the images sit side by side. Keep at least 6% clear transparent margin at the top and bottom.
Background: a TRUE transparent cut-out: a PNG with a real alpha channel. Nothing but the object: no backdrop, no wall, no table, no ground, no floor line, no cast shadow, no glow, no vignette, no checkerboard, no white or grey fill. A very soft contact shadow directly under the object is allowed only if it fades fully to transparent within a few pixels; otherwise leave it out. Clean ink edge all round; no stray paint specks around the silhouette.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** an animal, a safari scene, a loose cartridge. Real gun brands or models, writing or serial numbers, a hand. A backdrop, floor or cast shadow; a checkerboard or white fill.

---

## Batch 2: Melee cut-outs

Bare Hands and the three melee tools, same camera and scale as the guns: the striking end points right.

### Image 12: Bare Hands (no melee weapon)

**File:** `dd_cut_melee_bare_hands.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2), transparent PNG.
Subject: two clenched fists wrapped in grey duct tape, raised in a boxer's guard and turned in the same 3/4 view so the knuckles face right, the near fist slightly ahead of the far one; only the fists and the start of the forearms, the forearms ending in a soft painted fade to transparent at their lower-left ends (no cut stumps, no sleeves, no body).
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: melee card. The tool in steel, worn wood and rubber grip tape; a hot yellow (#f2c14e) highlight along its top edge from the key light; copper (#d9a066) as the second accent; a faint cool bounce on the underside. Nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm or product model. Keep the look of the earlier DeadDraw painting of this weapon (same shapes, materials and colours) so players recognise it.
Camera: one fixed product-shot camera for the whole set: a 3/4 side view (we see the right side of the object and a little of its top), the muzzle or striking end pointing to the RIGHT, handle or stock on the left, the long axis level with only a slight upward tilt of about 5 degrees towards the right. The object's centre sits at 50% width and 52% height.
Scale: size class S (short tool or stubby gun): the object spans 50% of the image width (from 25% to 75%), never more. Every image in this pack is drawn at the same real-world scale, so a pistol must look clearly smaller than a rifle when the images sit side by side. Keep at least 6% clear transparent margin at the top and bottom.
Background: a TRUE transparent cut-out: a PNG with a real alpha channel. Nothing but the object: no backdrop, no wall, no table, no ground, no floor line, no cast shadow, no glow, no vignette, no checkerboard, no white or grey fill. A very soft contact shadow directly under the object is allowed only if it fades fully to transparent within a few pixels; otherwise leave it out. Clean ink edge all round; no stray paint specks around the silhouette.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a face or body, brass knuckles, blood, a hard cut line on the arms. A backdrop, floor or cast shadow; a checkerboard or white fill.

### Image 13: Pipe Wrench

**File:** `dd_cut_melee_pipe_wrench.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2), transparent PNG.
Subject: one heavy red-handled pipe wrench, big adjustable jaw at the right end.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: melee card. The tool in steel, worn wood and rubber grip tape; a hot yellow (#f2c14e) highlight along its top edge from the key light; copper (#d9a066) as the second accent; a faint cool bounce on the underside. Nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm or product model. Keep the look of the earlier DeadDraw painting of this weapon (same shapes, materials and colours) so players recognise it.
Camera: one fixed product-shot camera for the whole set: a 3/4 side view (we see the right side of the object and a little of its top), the muzzle or striking end pointing to the RIGHT, handle or stock on the left, the long axis level with only a slight upward tilt of about 5 degrees towards the right. The object's centre sits at 50% width and 52% height.
Scale: size class S (short tool or stubby gun): the object spans 56% of the image width (from 22% to 78%), never more. Every image in this pack is drawn at the same real-world scale, so a pistol must look clearly smaller than a rifle when the images sit side by side. Keep at least 6% clear transparent margin at the top and bottom.
Background: a TRUE transparent cut-out: a PNG with a real alpha channel. Nothing but the object: no backdrop, no wall, no table, no ground, no floor line, no cast shadow, no glow, no vignette, no checkerboard, no white or grey fill. A very soft contact shadow directly under the object is allowed only if it fades fully to transparent within a few pixels; otherwise leave it out. Clean ink edge all round; no stray paint specks around the silhouette.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** rust so heavy it looks broken. A hand holding it, writing or brand marks. A backdrop, floor or cast shadow; a checkerboard or white fill.

### Image 14: Fire Axe

**File:** `dd_cut_melee_fire_axe.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2), transparent PNG.
Subject: one fire axe with a red-painted steel head at the right end and a long wooden handle, the blade edge facing down.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: melee card. The tool in steel, worn wood and rubber grip tape; a hot yellow (#f2c14e) highlight along its top edge from the key light; copper (#d9a066) as the second accent; a faint cool bounce on the underside. Nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm or product model. Keep the look of the earlier DeadDraw painting of this weapon (same shapes, materials and colours) so players recognise it.
Camera: one fixed product-shot camera for the whole set: a 3/4 side view (we see the right side of the object and a little of its top), the muzzle or striking end pointing to the RIGHT, handle or stock on the left, the long axis level with only a slight upward tilt of about 5 degrees towards the right. The object's centre sits at 50% width and 52% height.
Scale: size class L (full-length long-arm or long-handled tool): the object spans 76% of the image width (from 12% to 88%), never more. Every image in this pack is drawn at the same real-world scale, so a pistol must look clearly smaller than a rifle when the images sit side by side. Keep at least 6% clear transparent margin at the top and bottom.
Background: a TRUE transparent cut-out: a PNG with a real alpha channel. Nothing but the object: no backdrop, no wall, no table, no ground, no floor line, no cast shadow, no glow, no vignette, no checkerboard, no white or grey fill. A very soft contact shadow directly under the object is allowed only if it fades fully to transparent within a few pixels; otherwise leave it out. Clean ink edge all round; no stray paint specks around the silhouette.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a battle axe or double blade. A hand holding it, writing or brand marks. A backdrop, floor or cast shadow; a checkerboard or white fill.

### Image 15: Sledgehammer

**File:** `dd_cut_melee_sledgehammer.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2), transparent PNG.
Subject: one huge sledgehammer with a wide square steel head at the right end and a long wooden handle with a taped grip.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, chunky readable silhouette that still reads at 150 pixels wide, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: melee card. The tool in steel, worn wood and rubber grip tape; a hot yellow (#f2c14e) highlight along its top edge from the key light; copper (#d9a066) as the second accent; a faint cool bounce on the underside. Nobody holding it.
Gear: a made-up, chunky, slightly toy-like design (a game prop), plainly not a real firearm or product model. Keep the look of the earlier DeadDraw painting of this weapon (same shapes, materials and colours) so players recognise it.
Camera: one fixed product-shot camera for the whole set: a 3/4 side view (we see the right side of the object and a little of its top), the muzzle or striking end pointing to the RIGHT, handle or stock on the left, the long axis level with only a slight upward tilt of about 5 degrees towards the right. The object's centre sits at 50% width and 52% height.
Scale: size class L (full-length long-arm or long-handled tool): the object spans 82% of the image width (from 9% to 91%), never more. Every image in this pack is drawn at the same real-world scale, so a pistol must look clearly smaller than a rifle when the images sit side by side. Keep at least 6% clear transparent margin at the top and bottom.
Background: a TRUE transparent cut-out: a PNG with a real alpha channel. Nothing but the object: no backdrop, no wall, no table, no ground, no floor line, no cast shadow, no glow, no vignette, no checkerboard, no white or grey fill. A very soft contact shadow directly under the object is allowed only if it fades fully to transparent within a few pixels; otherwise leave it out. Clean ink edge all round; no stray paint specks around the silhouette.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a fantasy war hammer. A hand holding it, writing or brand marks. A backdrop, floor or cast shadow; a checkerboard or white fill.

---

## Batch 3: Card backdrops

Empty plates the game paints behind the cut-outs. The gun and melee plates are required; the three district plates are optional variants the card uses when the weapon was found in that district.

### Image 16: Gun card backdrop

**File:** `dd_bg_gun.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: a slate steel-blue workshop pegboard wall (the wall from the DeadDraw gun cards) with rows of small round holes, the lower edge of a worn wooden workbench just visible along the very bottom, a warm yellow lamp glow washing the upper right of the wall. No objects in front of it.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: slate steel-blue (#1f2e3a to #2e4a5f) wall tinted by a hot yellow (#f2c14e) glow in the upper right; dark worn wood at the bottom.
Lighting: the same warm key light from the upper right that lights the cut-out weapons, as a soft glow on the wall; a cool dim fill from the left; the edges fall off into shadow.
Composition: an EMPTY backdrop plate, full-bleed, no border or frame. No objects in front, no weapon, no tool, no person, no zombie, no text. The centre 60% of the width is a calm, softly lit mid-dark area where a cut-out object will be placed on top later. Keep the top-left corner (left 30%, top 35%) and the top-right corner (right 25%, top 30%) calm, plain and darker: the game draws badges there. Keep the bottom 18% simple and dark: the card name goes there. Detail only in the outer edges and kept low-contrast. The game crops this image to a near-square on phones, so the plate must still look complete when the outer 20% left and right is cut off.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** any gun or gun parts, tools hanging on the pegboard, a bright hot spot in the centre, writing. Any object in the centre; bright or busy badge corners.

### Image 17: Melee card backdrop

**File:** `dd_bg_melee.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: a dark warm brown workshop pegboard wall with rows of small round holes, a plain shelf edge low on the right side in deep shadow, a warm lamp glow in the upper right. No objects in front of it.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: dark warm brown (#2a2420) wall, hot yellow (#f2c14e) glow upper right, copper (#d9a066) as a faint second accent on the shelf edge.
Lighting: the same warm key light from the upper right that lights the cut-out weapons, as a soft glow on the wall; a cool dim fill from the left; the edges fall off into shadow.
Composition: an EMPTY backdrop plate, full-bleed, no border or frame. No objects in front, no weapon, no tool, no person, no zombie, no text. The centre 60% of the width is a calm, softly lit mid-dark area where a cut-out object will be placed on top later. Keep the top-left corner (left 30%, top 35%) and the top-right corner (right 25%, top 30%) calm, plain and darker: the game draws badges there. Keep the bottom 18% simple and dark: the card name goes there. Detail only in the outer edges and kept low-contrast. The game crops this image to a near-square on phones, so the plate must still look complete when the outer 20% left and right is cut off.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** hanging tools, hammers, pliers, tape rolls or jars on the wall, a bright centre, writing. Any object in the centre; bright or busy badge corners.

### Image 18: District backdrop: Maple Row

**File:** `dd_bg_maple_row.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: the inside of a suburban garage at dusk: a pegboard wall on the left half and part of a dusty window on the right showing a soft orange-pink dusk sky and a blurred maple tree, a few loose maple leaves on the window sill. No objects in front of it.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: warm wood and pegboard browns, dusk orange-pink (#e08a5a, #c46a7a) through the window, deep shadow at the edges, hot yellow (#f2c14e) key glow upper right.
Lighting: the same warm key light from the upper right that lights the cut-out weapons, as a soft glow on the wall; a cool dim fill from the left; the edges fall off into shadow.
Composition: an EMPTY backdrop plate, full-bleed, no border or frame. No objects in front, no weapon, no tool, no person, no zombie, no text. The centre 60% of the width is a calm, softly lit mid-dark area where a cut-out object will be placed on top later. Keep the top-left corner (left 30%, top 35%) and the top-right corner (right 25%, top 30%) calm, plain and darker: the game draws badges there. Keep the bottom 18% simple and dark: the card name goes there. Detail only in the outer edges and kept low-contrast. The game crops this image to a near-square on phones, so the plate must still look complete when the outer 20% left and right is cut off.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a car, houses in sharp detail, zombies, people, writing. Any object in the centre; bright or busy badge corners.

### Image 19: District backdrop: Downtown

**File:** `dd_bg_downtown.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: the back counter wall of a closed city pawn shop at night: a dark pegboard and empty metal shelf brackets, a window strip on the right edge with blurred wet street lights in sodium orange and cold blue. No objects in front of it.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: near-black blue-grey wall (#1b222b), sodium orange (#e0913a) and cold blue (#4a7fb0) light from the window, hot yellow (#f2c14e) key glow upper right.
Lighting: the same warm key light from the upper right that lights the cut-out weapons, as a soft glow on the wall; a cool dim fill from the left; the edges fall off into shadow.
Composition: an EMPTY backdrop plate, full-bleed, no border or frame. No objects in front, no weapon, no tool, no person, no zombie, no text. The centre 60% of the width is a calm, softly lit mid-dark area where a cut-out object will be placed on top later. Keep the top-left corner (left 30%, top 35%) and the top-right corner (right 25%, top 30%) calm, plain and darker: the game draws badges there. Keep the bottom 18% simple and dark: the card name goes there. Detail only in the outer edges and kept low-contrast. The game crops this image to a near-square on phones, so the plate must still look complete when the outer 20% left and right is cut off.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** items for sale, a counter with objects on it, neon signs or any writing, people. Any object in the centre; bright or busy badge corners.

### Image 20: District backdrop: St. Agnes Hospital

**File:** `dd_bg_st_agnes.png`

**Prompt:**

```
Original painted game illustration for a zombie card game, 1536x1024 (landscape 3:2).
Subject: a hospital security office wall at night: pale square wall tiles, a dented metal locker edge at the far left, a flickering fluorescent tube's sickly teal light from above. No objects in front of it.
Style: bold painted comic illustration: thick dark ink contour around every shape, painted fills with visible brushwork, three value steps (light, mid, shadow), one strong warm key light from the upper right and a cool dim fill from the left, slightly exaggerated cartoon proportions, gritty but playful "Saturday-night creature feature" mood.
Palette: pale tile (#9fb3ad) pushed down into shadow, sickly teal (#5fb3a6) fluorescent cast, deep teal-black edges, hot yellow (#f2c14e) key glow upper right so the weapon light still matches.
Lighting: the same warm key light from the upper right that lights the cut-out weapons, as a soft glow on the wall; a cool dim fill from the left; the edges fall off into shadow.
Composition: an EMPTY backdrop plate, full-bleed, no border or frame. No objects in front, no weapon, no tool, no person, no zombie, no text. The centre 60% of the width is a calm, softly lit mid-dark area where a cut-out object will be placed on top later. Keep the top-left corner (left 30%, top 35%) and the top-right corner (right 25%, top 30%) calm, plain and darker: the game draws badges there. Keep the bottom 18% simple and dark: the card name goes there. Detail only in the outer edges and kept low-contrast. The game crops this image to a near-square on phones, so the plate must still look complete when the outer 20% left and right is cut off.
No text, letters, numbers, logos, brand names, labels, signs with writing, flags or insignia. Original design: no real weapon models, no real products, no known characters. Cartoon level only: no blood pools, no wounds, no gore, no realistic violence.
```

**Avoid:** a plus sign, medical equipment in the centre, a bed, people, writing, blood. Any object in the centre; bright or busy badge corners.

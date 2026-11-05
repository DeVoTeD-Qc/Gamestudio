# Loadout art: ChatGPT prompt pack (wb-art)

## What is missing

The engine added four **Loadout** cards (`src/engine.js`, ids `L1A`, `L1R`, `L1S`, `L1E`). They have no picture. Until they get one, `ui.js` (`SQUAD_ART`) shows their squad's sample art instead.

| Card | Squad | Accent | File to make | It currently borrows |
|---|---|---|---|---|
| Tac Vest | Assault | blue `#2F7FD8` | `Tac_Vest` | Breach |
| Recon Post | Recon | red-orange `#C8442B` | `Recon_Post` | Mark Target |
| Field Pack | Support | green `#3F8F4A` | `Field_Pack` | Ammo Box |
| Bounty Contract | Engineer | gold `#B98A10` | `Bounty_Contract` | Deployable Cover |

Everything else is covered. All 28 guns that are actually dealt (`GUNSET`, plus the starting `pistol-0`) have their own file in `webart/guns/`. The other weapon tiers in `WEAPONS` are never dealt, and `gunArt()` would use the nearest tier anyway. All 8 locations (`E01` to `E08`) have files in `webart/locs/`.

The UI finds card art by the card's name with spaces turned into underscores, so the names above must be spelled exactly as shown.

A Loadout card stays on the table and helps you every turn. So each picture shows **a piece of gear set up and ready**, not an action in progress. That makes them read differently from the action cards.

## How to use this

1. In ChatGPT (image generation), pick **landscape, 1536 x 1024**.
2. Paste the **shared style block** below, then one card prompt underneath it. Do one card per chat, or start each new card with "New image, same style:".
3. If you can, attach **two reference images** to the chat (`Breach.jpg` for the house style, plus the squad sample from the table above, both in `source/project-warbuilder/src/pnp/art/`), and say "match the style of the attached images". This helps more than anything else.
4. Check the result against the **reject checklist**. Regenerate until it passes, with a short fix-up line if needed (for example "same image, remove the patch on the shoulder").
5. Download the PNG and upload it (see **Upload**).

## Shared style block (paste first, every time)

```
Gritty ink illustration for a tactical card game, in the style of a distressed screen print / grunge poster.
Heavy black ink linework with rough dry-brush hatching. Limited palette: black ink, warm khaki/sand (#C9BC9C) for
fabric and skin of the scene, and exactly ONE accent colour used as bold paint splashes, streaks and spatter
behind and around the subject (accent given below). No other colours.
Composition: wide landscape vignette, about 1.8 : 1, subject centred and filling most of the frame. The artwork
has rough, torn, spattered edges with ink drips and dots that fade out into a plain pure white background
(#FFFFFF). No frame, no border, no card layout, no panel. Leave a white margin all around.
Soldiers (if any) are anonymous modern tactical operators: helmet, goggles or visor, face covered or turned away,
plain unbranded gear in sand and black. Grounded, serious mood, no gore.
Absolutely no text, letters, numbers, labels, logos, brand names, flags, unit patches, insignia or emblems of any
real army, game or franchise.
```

## Card prompts

### 1. `Tac_Vest` (Assault, blue)

```
Subject: a heavy plate-carrier tactical vest hung on a battered wooden post or crate in a ruined doorway, ready to
be thrown on. Bulging magazine pouches, a breaching tool clipped to the side, a helmet with goggles resting on top,
the plate showing a fresh scuff where a round glanced off. Splinters and dust on the ground.
Accent colour: bold cobalt blue (#2F7FD8), as sharp diagonal streaks and splashes bursting out behind the vest,
like a burst of momentum.
Card name for your reference only, do not write it: "Tac Vest".
```

### 2. `Recon_Post` (Recon, red-orange)

```
Subject: a camouflaged sniper observation post dug in on a ridge: a sandbag nest under a ragged camo net and
leaves, a long spotting scope and binoculars on a tripod looking out over distant pine forest and hills, an empty
rifle bipod in front. One prone, anonymous observer seen from behind, half hidden in foliage, or no person at all.
Accent colour: vivid red-orange (#C8442B), as torn paint streaks across the sky and a thin glowing sight line
running from the scope into the distance.
Card name for your reference only, do not write it: "Recon Post".
```

### 3. `Field_Pack` (Support, green)

```
Subject: a large, heavily loaded military rucksack propped against a low concrete barrier, flap open. Belts of
ammunition, spare magazines, a coiled ammo belt, a water canteen and a rolled ground mat strapped to it. A gloved
hand is tightening a strap. Tufts of grass and dirt around the base.
Accent colour: deep field green (#3F8F4A), as grass-like brush strokes and splashes sweeping behind the pack.
Card name for your reference only, do not write it: "Field Pack".
```

### 4. `Bounty_Contract` (Engineer, gold)

```
Subject: a rugged hard case open on a workbench in a dim depot: inside, neat bundles of plain unmarked cash bands,
a sealed folder with a blank photo clipped to it, a plain blank stamp mark, a rugged tablet, a key card
and a small pile of loose rounds. A gloved operator's hands slide the case shut. Tools and crates in the background.
Accent colour: warm mustard gold (#B98A10), as rough paint splashes and glints behind the case and on the cash
bands and metal edges.
Card name for your reference only, do not write it: "Bounty Contract".
Keep all paper, money and screens completely blank: no writing, numbers, faces or symbols on them.
```

## Reject checklist

Regenerate if **any** of these is true:

- [ ] There is any **text**: letters, numbers, fake writing on paper, money, screens, ammo boxes or the background.
- [ ] There is any **logo, brand, flag, unit patch, rank badge or game/franchise emblem** (watch shoulders, helmets, cases, cash).
- [ ] A face is clearly visible (eyes, mouth). Operators stay anonymous.
- [ ] More than one accent colour, or the accent is missing or barely visible (it must read at thumbnail size).
- [ ] It looks like a photo, a 3D render or a clean vector drawing instead of gritty ink with dry-brush grain.
- [ ] The background is grey, beige, a texture or a solid colour block instead of plain white, or there is a frame, border or rectangle edge.
- [ ] It is portrait or square, or the subject is cut off at the image edge (we need the ragged vignette all round).
- [ ] The subject does not read at **134 px wide** (shrink it on screen to check: you should still see "vest", "lookout post", "rucksack", "case of cash").
- [ ] Gore, blood, or a weapon pointed at the viewer.
- [ ] It looks like a near-copy of an existing card (Breach, Mark Target, Ammo Box, Field Kit).

## Upload

1. Name each file exactly: `Tac_Vest.png`, `Recon_Post.png`, `Field_Pack.png`, `Bounty_Contract.png` (or `.webp`/`.jpg`, full size as ChatGPT gave it; do not shrink or crop).
2. Open the Studio Floor, go to the **Studio chat** panel, and click **"+ Images / logs"**. Pick the files (all four at once is fine), and send them with this message:
   `wb-art: Loadout card art for Tac Vest, Recon Post, Field Pack, Bounty Contract. Please hand to Technical Artist for reencode_art.py.`
3. If you redo one later, upload just that file with the same name and say "replaces the earlier one".

## For the Technical Artist (after upload)

- Crop each to the art's ragged vignette (about 1.8 : 1), knock the white paper out to alpha, and save a **520 px wide RGBA WebP** original, the same as the other card originals at commit `9610a97`. Keep a 1000 px wide JPEG on white in `src/pnp/art/<Name>.jpg` for print-and-play.
- Build a `--from` folder: every card original (from `git show 9610a97:<path>`), plus these four at the top level, plus `guns/` and `locs/`. Then run `python3 src/webart/reencode_art.py --from <folder>`, then `npm run build && npm test`. The test needs 280 px card widths and a build of 1.5 MB or less. Four cards add about 4 x 15 KB of WebP.
- Once the files are in, remove the `SQUAD_ART` fallback in `ui.js` (line 51-52), or leave it as a safety net. That is a code decision, so flag it rather than doing it silently.
- Ask the Sr Game Artist to approve all four in the game at 1x before marking wb-art done.

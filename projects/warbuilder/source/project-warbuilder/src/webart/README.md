# Web art

The pictures that `tools/build.js` inlines (base64) into the single-file game, `build/index.html`.

| Folder | What | Shown at (CSS px, 1x) | Stored as |
|---|---|---|---|
| `src/webart/*.webp` | 44 tactical-card illustrations (40 imported + the 4 Loadout cards), ink on transparent | 134 (codex grid), ~150 (hand), ~211 (card face), ~317 (enlarged codex card) | WebP q42, 280 px wide, soft alpha |
| `guns/*.webp` | 30 gun illustrations | up to ~272 (enlarged codex gun) | WebP q45, 280 px wide |
| `locs/*.webp` | 8 location backdrops | card face (336) and cover backgrounds | WebP q45, 336 px wide |

The print-and-play generator uses its own high-resolution copies in `src/pnp/art/` (JPEG on white); those are not part of the web build.

## Provenance

All card, gun and location art was made by the studio head with ChatGPT image generation (decision D3). The files here are reduced copies of that art.

## Re-encoding (DESIGN_REVIEW Q4)

The build budget is **2 MB** for the whole single file (D8: it must stay one file; the head raised it from 1.5 MB on 2026-11-05, wb-pyl-impl). The art was 3.4 MB of base64 in a 4.09 MB build. It is now about 0.82 MB of base64 in a 1.47 MB build.

`reencode_art.py` writes every file in this folder from the **originals in git** (commit `9610a97`, the import). It never re-encodes its own output, so it can be run again safely:

```bash
python3 src/webart/reencode_art.py --check   # sizes only
python3 src/webart/reencode_art.py           # rewrite src/webart/** (needs Pillow with WebP, numpy)
npm run build && npm test                     # the build test fails if the file goes over 2 MB
```

**Adding or changing art:** without `--from`, the script re-encodes the files already in this folder from their git originals, so a new picture needs its own original. Make a folder laid out like this one (cards at the top, `guns/`, `locs/`) holding the full-size WebP originals of every picture, old and new (`git show 9610a97:<path>` gives the old ones), and run the script with `--from` that folder. It encodes every `.webp` it finds there. Keep the widths: the build test checks them (cards and guns 280 px, locations 336 px) and the total size.

**Art added after the import (the 4 Loadout cards, wb-art).** Their originals are not in `9610a97`, so they live in `originals/` (520 px RGBA WebP, q85 with lossless-quality alpha; the build ignores subfolders). The script reads `originals/<name>` whenever git has no original, so a plain `reencode_art.py` run rebuilds them too; for a `--from` folder, copy them in next to the git originals. They were made from the head's 1536 x 1024 ChatGPT PNGs (not in git): cropped to the ragged vignette (about 1.5 : 1, the vignette itself, so no straight edges), paper above 248 snapped to white, colour-to-alpha only on the white paper connected to the outside (the khaki fill stays opaque), then 520 px. The print-and-play copies are `src/pnp/art/<name>.jpg`, 1000 px, q88 on white. These pictures fill their vignette edge to edge, so at the normal card settings they were ~16 KB each and put the build ~15 KB over budget; `OVERRIDES` in the script encodes just these four with a 0.4 px pre-blur, q32 and alpha q30 (~9-12 KB each, no visible change at 1x). The build is then 1,493,698 bytes: **about 6 KB of headroom left**, so the next new picture needs budget found elsewhere.

**Soft alpha (cards).** The card art is ink with the paper made transparent, so all the detail sat in the alpha channel, which WebP keeps almost lossless; the alpha alone cost more than the picture. The script keeps the picture exactly as it looks on white paper, but swaps the alpha for a smooth silhouette grown 3 px past the ink, and solves the colour so that the art on white is unchanged. Every place the card art is drawn has a light background (white card faces, off-white hand and loot cards), so it looks the same as before; the silhouette, not a rectangle, still shows on non-white backgrounds. At the same size and quality settings this makes the card files about 40% smaller than keeping the original alpha.

**Trade-off.** At 1x (desktop 1440x900, phone 844x390) the new art is hard to tell from the old; see `projects/warbuilder/qa/screenshots/q4/`. On 2x/3x screens the enlarged codex card (about 317 CSS px) is a little softer than before, because the cards were 520 px and are now 280 px. If that matters later, AVIF (Safari 16+ and all Chromium browsers) came out roughly 30-45% smaller than WebP in a quick test, which could pay for bigger cards in the same budget; it was not adopted because WebP is the safer format, and its quality was not compared side by side.

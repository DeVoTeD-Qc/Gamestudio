# UI kit import log

*Technical Artist. One section per batch from `ui-kit-prompt-pack.md`. Newest first.*

## Batch 1: P1 icons (kc-ui-import, 2026-11-06)

**In:** `ico_stat_firepower`, `ico_stat_armor`, `ico_stat_cover`, `ico_stat_supply`, `ico_stat_deck`, `ico_stat_intel`, `ico_streak`, `ico_score`, `ico_kw_first_shot`, `ico_kw_pick`. 1254x1254 RGB, white on black, all 10 accepted (no regenerations).

**Processing** (`tools/ui_kit_icons.py`, pack §7.2 `luma`): brightness to alpha with levels 8%..92%, RGB pure white, trimmed to the glyph, centred on a square with 8% padding. Shipped to `source/project-killingcard/assets/ui/kit/icons/`: a 256 px master `ico_<id>.png` plus exports in `128/`, `64/`, `48/` and `32/`. Import: lossless, mipmaps on, `fix_alpha_border` on. About 130 KB of PNG for the 10 icons at all five sizes. The raw drops are not committed (`assets/incoming/README.md`: delete after processing).

**Why exports rather than one 128 px atlas (deviation from §7.3):** canvas items draw with the project's default plain Linear filter, so mipmaps are never sampled and a 128 px cell drawn at 22 px aliases. `UiKit` picks the smallest export at or above the real on-screen size instead (`UiKit.draw_icon` measures it; the `IconSheet` callers get the 48 px export, which covers 22-34 px logical at x1-1.6 phone scale). Once all P1/P2 icons are in, pack each size into its own atlas (`kit_icons_32.png` and so on) to cut file count. The 256 and 128 sizes can then be left out of the web build if it gets tight (they serve only large menu or reward icons).

**Code:** `scripts/ui/ui_kit.gd` (`UiKit`): `icon(id, px)`, `has(id)`, `has_kit(id)`, `kit_texture(id, px)`, `draw_icon(ci, id, rect, tint)` (returns false so the caller keeps its drawn glyph), `tint(side, state)` with the §2.2 tokens, and the aliases `intel_contact > stat_intel`, `supply > stat_supply`, `kw_cover > stat_cover`, `type_equipment > type_field` and `elite > elite_star`. `IconSheet.get_icon()` and `has_icon()` ask UiKit first, so every existing sheet caller shows the kit image without being edited: the FP and Armor icons on the full card, inspector and hand cards, the First Shot and Pick pips on banners, the keyword row, the Cover chip, the glossary, the killfeed and the call-in. `strip_badge.gd` asks UiKit for its STREAK, DECK (`stat_deck`) and RIVAL (`stat_intel`) glyphs and keeps its drawn glyph as the fallback.

**Not wired yet:** `score` and `stat_supply` load through UiKit, but nothing in the game draws a Score or Supply pictogram today (the SCORE badge has no glyph, the Supply row is text plus pips). Adding them changes those layouts, so it is left to the UI owner.

**Tests:** `tests/test_ui_kit.gd` checks the 10 ids at every export size, the aliases, the IconSheet hook, the fallback to the sheet or to null with the kit folder missing, and that the strip badge draws either way. The full suite passes with the kit and with `assets/ui/kit` and `assets/licensed` both removed.

**Screens:** `qa/screenshots/ui-kit/` (public art, phone 844x390 at 2x): deploy, round 2, the Marksman inspector (Pick, FP, Armor), and a contact sheet at 22 / 32 / 48 px on dark and light backgrounds.

### Style feedback for batch 2+

1. **Stroke weight at 22-32 px.** Most of the set reads well. These details are below the floor and turn into grey smudges at 32 px and below:
   - the speed lines on **First Shot**;
   - the corner-bracket mark inside **Pick**'s quadrant (it becomes noise; a plain solid square would read);
   - the thin curved arrow on **Cover**;
   - the inner rim gap on **Armor** at 22 px.

   For batch 2+, ask for **strokes and gaps of at least 1/10 of the canvas** instead of 1/12, and **no detail smaller than 1/8 of the canvas**. Suggested change to the icon tail: "Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, simple enough to read at 24 pixels."
2. **Keep silhouettes compact.** Icons are trimmed to their longest side, so wide, flat glyphs (First Shot, Streak, Cover) come out visibly smaller than round ones (Firepower, Intel) in the same 22 px slot. Ask for a "compact, roughly square silhouette that fills about 70% of the canvas in both width and height". This matters for Flank, Pierce and Suppress in batch 2, which are naturally long arrows or bullets.
3. **Keep the shapes apart.** Pick (quartered reticle) and Firepower (broken ring with a dot) are still told apart at 32 px by the cross versus the gaps. Keep the rest of the keywords off circles and reticles. Intel's radar quarter-circle sits close to the motif the old range icons used, so when `range_close / mid / long` are generated (batch 27), use a different motif (bars or chevrons, for example).
4. **What worked:** the flat pure-black background keyed perfectly, with no halo or checkerboard. Line weight is consistent across the set, the 45-degree chamfers are on-style, and nothing has text or marks. Keep the same chat and style block for batch 2.

# DeadDraw: UX v4 pass (dd-ux-v4)

**Input:** the approved mockup `ux-mockups-v4.html`, the head's playtest notes (`../qa/playtest-head-2026-11-11.md`, points 1-12) and the head's answers M1-M5. The v4 rules (dd-v4-impl) landed during this pass and are wired into the same layout.

## The head's answers, as built

| Q | Answer | Built |
|---|---|---|
| M1 | (a) direction B, Door row | The wave door and the three room doors form one row (portrait) or one column (landscape) of equal doors. Run and melee are small buttons in the gun row. The middle prompt band is gone. Its one useful line ("what just happened") moved into a slim strip with the pile and the resolve dots, so the street sits right above the guns. |
| M2 | new mark | **Fang**: tier colour + the number on a monster's jaw with 3-6 fangs (one more per tier). See "Strength mark" below. |
| M3 | (b) | Every tooltip is 2 lines (`t1` bold, `t2` plain, under about 70-80 characters). The full rules live only in the Glossary and the Codex. |
| M4 | (a) | Codex entries you haven't met are dark silhouettes named "???". Met entries are saved in the profile (`codex_met`). |
| M5 | (a) | The WAVE banner is on screen for 1.8 s, and a tap anywhere skips it. The whole tap is eaten, so it never lands on a card underneath. |

## Street (direction B)

- **HUD:** HP (+ Cover), points, one Patches chip, **?** (Help / Glossary), Menu.
- **Door row:**
  - The wave door shows "WAVE +N" (waves waiting), the big wave number (blood red, outlined) and a BOSS chip, which is its own inspectable tile.
  - Each room door has a **padlock plate** on its art, in one of four states:
    - locked: dark plate, closed padlock, price, a gold progress bar;
    - gold OPEN: open padlock, tap to open;
    - green USE;
    - grey "used".
  - A locked plate passes taps to the door, which shows the tooltip "need N more".
- **Street:** a 2x2 grid in portrait. In landscape it is 2x2 or 1x4, whichever gives bigger cards. Zombies show the strength mark, guns and melee cards show the hit burst.
- **Strip:** the pile (cards are dealt from here), one "what just happened" line (tap it for the history) and the resolve dots.
- **Gun row:** gun 1, gun 2 and a column with MELEE and RUN (or RUN PAST / NO ESCAPE).
  - Each gun shows the hit burst, the name, "N of M kills", the rule icon with a short label, then **kill sockets**. Filled sockets show the zombie's art and number. The next socket shows what it accepts ("<6", ">4", "any"). Empty sockets are dashed. The Stovepipe Launcher has one socket (no extra icon).
- **Sizes:** every button is at least 64 logical px (44 CSS px on a phone). Inspect works on right click and long press on every tile and on the small buttons (Run, ?, Bury).

## Strength mark (M2)

The head said the threat badge looked too much like a shield. The number is both toughness and attack. We drew three variants at real size on the four tiers (2, 5, 8, 11), next to the v8 ring.

| Variant | Reads as | Verdict |
|---|---|---|
| **Fang** (picked) | a monster's jaw: attack, plus a solid body for toughness; 3-6 fangs by tier | The clearest. Not a shield (several points, not one), and it doesn't clash with the yellow hit burst. The fang count is a second channel for colour-blind players. |
| Claw | a disc raked by 1-4 claw slashes | The slashes read weakly at card size and look like a comet tail. |
| Spike | a jagged splat, 7-13 spikes | Too close to the yellow hit burst; the Lurcher's amber is almost the burst's yellow. |

The screenshot is `dd-ux-v4-shots/strength_variants.png` (scratchpad). All three stay in `scripts/ui/dd_marks.gd` (`StrengthMark.variant`); `STRENGTH_VARIANT = "fang"`.

## Motion (the mockup's storyboards)

1. **A wave opens:**
   - 0.0 s: the wave door lifts;
   - 0.3 s: up to 8 backs fly into the pile, 70 ms apart;
   - 1.2 s: the pile riffles;
   - 1.6 s: the deal.
2. **A room opens:**
   - 0.2 s: the plate pops;
   - 0.5 s: 3 backs fly, 110 ms apart;
   - 1.2 s: the pile riffles;
   - 1.5 s: the "OPEN" banner and USE.
3. **WAVE banner:**
   - 0.0 s: a red edge pulse;
   - 0.1 s: the door's old number falls away;
   - 0.4 s: the new number slams in and the banner sweeps across;
   - the banner is gone by 2.2 s;
   - a tap skips it, and the door number lands on its final value.
   - A district's first wave gets the same banner.
4. **A room becomes available:** two gold rings grow off the door, then the plate glows slowly (2 s) while you can afford it.

With reduce motion (setting or browser): no sweep, slam, fall or rings, and no glow loop. Cards fade instead of flying.

## Glossary and Codex

- **Glossary** (the ?, How to play, Menu): every icon, one line each. Sections:
  - On your weapons: hit, kill sockets, next socket, challenge, active, Bare Hands, melee uses, salvage;
  - Weapon rules: the 11 rules, including Small and One shot;
  - On zombies;
  - On the board: wave door, room plate, gold plate, USE, pile, resolve dots, Cover, points, Run, Safehouse Shop;
  - How a street works.
- **Codex** (title, Menu): 42 entries built from `balance.json`:
  - 11 guns, Bare Hands and 3 melee weapons, 4 zombie tiers, 3 bosses, 6 items and 14 Patches;
  - filters by type, by district and "Met only";
  - "N of 42 met" in the header.
- Every row and tile opens its 2-line tooltip.

## v4 rules wired

- **Melee button:** Bare Hands or the melee weapon you hold, with its hit burst and use dots.
- **Melee cards on the street:** the TAKE / SCRAP sheet.
- **Equip sheet:** "replaces Hunting Rifle 3/4 · salvage +30".
- **Salvage:** a "+N" float over the gun slot.
- **Run:** allowed any time the street has cards. Every card flies face up to the bottom of the pile, then "N cards to the bottom" floats there.
- **Safehouse:** the boss Patch is taken on the tap, then the Safehouse Shop (`DDShopPanel`) with LEAVE. The "points come with you" line is gone.
- **Stale text fixed:** the medkit per-street line, How to play (Bare Hands, the Run rule), and the wave zoom's gun count. Open rooms now use their own colour (kind `Q`) so melee keeps the tan `K`.

## Tests

- `tests/test_ui_v4.gd` (10 tests) runs at 390x844, 844x390, 1440x900 and 1920x1080. It covers:
  - the door row and the strip;
  - the plate's four states and the ready rings;
  - 2-line tooltips;
  - inspect on the buttons;
  - the Glossary;
  - the Codex filters and met-tracking;
  - the banner (1.8 s, tap skips it, reduce motion);
  - the strength-mark tiers;
  - the v4 melee, launcher, equip and Run flight.
- `test_ui_clean.gd`, `test_ui_flow.gd` and `test_feel.gd` were updated for the new layout.
- `tools/smoke_web.js` also covers the WAVE banner skip, the Glossary, the Codex, and a long press on Run (tooltip, no Run).

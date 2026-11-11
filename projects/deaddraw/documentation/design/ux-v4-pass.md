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

The screenshot is `dd-ux-v4-shots/strength_variants.png` (scratchpad). **Replaced in dd-polish5** by the one-circle badge below (the head preferred the plain circle on every number); the fang, claw, spike and burst shapes are gone.

## Number badges (dd-polish5)

Head's note: "I think it looked better when all numbers on all cards had that simple circle as icon." Every card number now uses **one badge**: `NumBadge` in `scripts/ui/dd_marks.gd`. Same shape everywhere: a circle (a pill when the text is wider than 2 digits, e.g. a boss's `6×3` on the map), a 1 px ink hairline, a coloured ring (7.5% of the size, 2-5 px), a fill, the number centred (58% of the height for 1-2 digits, 42% for more). Only the colours change:

| Role | Ring | Fill | Number | Used for |
|---|---|---|---|---|
| Hit (`HitBurst`) | ink | yellow `#f2c14e` | ink | gun power, melee weapon power, Bare Hands |
| Strength (`StrengthMark`) | tier colour: Shambler bone, Lurcher amber, Bruiser orange, Hulk red | blood `#5c1b19` | bone | zombies, bosses, the kills in a gun's sockets, the map's boss numbers |
| Item | the card kind's accent (medkit green, cover gold) | ink | bone | medkit heal, cover value |

The yellow fill is the only light badge, so hit never reads as an item even next to the gold cover ring. The zombie number stays **attack and toughness**: the zombie tooltip line 1 says "Lurcher · strength 4: its attack and its toughness", the zoom body and the Codex say it too. No extra glyph: the number itself carries the tier for colour-blind players.

Where it appears: street cards, the gun row (hit badge + filled sockets), the melee button, inspect tooltips (44 px), the Codex tiles (zombies, bosses, guns, melee, medkits, cover) and the Glossary. The Glossary opens with **NUMBER BADGES: ONE CIRCLE, THE COLOURS SAY WHAT**, one row per badge colour: Hit (yellow), Strength (blood red), Tier (the red badge's ring), Heal (green ring), Cover (gold ring). `STRENGTH_VARIANT` / `BADGE_SHAPE` = `"circle"`.

### Melee equip fix (dd-polish5)

- **Bug:** taking a melee weapon left its card on the street. `dd_feedback.gd _card_fx` had no branch for melee cards, so the ghost tile made for the fly-out was never moved or freed; it sat over the next card (enlarged) until the next tap re-rendered the board. Now TAKE flies it into the melee button (with a pop), SCRAP drops it with the points, and any other kind drops its ghost.
- **Melee button:** the old single row (burst | MELEE / name / pips) needed more width than the button has on a phone, so the burst slid over the border and the text. Now two rows that always fit: [yellow hit badge | MELEE or ACTIVE, then the use pips or "no pts"], then the weapon's name on its own line (shrinks to fit). The art sits faint behind.
- Also: the log line read "Pipe Wrench (3) - -2 HP"; now "Lurcher 5: Pipe Wrench (hit 3), -2 HP." (guns too). Map district names wrapped mid-word at 1440x900 ("Groundskeepe/r"): titles now shrink until the longest word fits.
- QA: `?screen=street&street=K:wrench,Z3,M4` deals exact cards (web smoke query).

## Gun art, rule chips, Full set plate (dd-ui6)

Head's notes: see the equipped gun's art better (less room for the street cards); show the weapon rule icons on the street cards too; make the completion bonus clear, with a good icon; tidy up.

- **Gun tile:** `[hit badge | NAME over rule icon + rule]`, then a clear **art band** (the gun art with no scrim and nothing on top of the gun; ACTIVE is a small chip in its corner), then the kill sockets (one fixed-height row, centred), then the Full set plate. The "3 of 4 kills" line is gone (the sockets show it; the tooltip says it). Portrait gun row 196 → 284 logical px (street cards lose about 40 px each and stay above 170 CSS px tall); landscape gun column 25% → 27% of the width (290-440 px), sockets 26% of a tile (50-92 px).
- **Rule chip on street cards:** under a zombie's number badge, the ACTIVE gun's rule icon (the same SVG glyph as the gun row, the Glossary and the Codex). It can take it: full colour + green tick. It can't: dimmed to 40% + red strike (tick vs strike also reads without colour). Melee active or an empty slot: no chip. A gun card on the street shows its own rule icon (no verdict). The chip is its own inspect target: "Hunting Rifle: lower than 8 - yes" / "This 9 breaks its rule (needs at most 3). Use the other gun or melee." Tapping it is a tap on the card. Code: `Marks.RuleChip`, `DDPayloads.zombie_rule_chip` / `weapon_rule_chip`.
- **Full set plate:** new icon `badges/full_set.svg` (a gold cup whose bowl holds 4 filled red kill sockets; original, generated by `tools/art/gen_art.py badge_full_set`). Plate = cup + **FULL +50** in gold (just **+50** when the plate is under 230 px, the phone gun row), then the challenge reward + its medal (green when met / on track, struck grey when missed). One kill to go: the rim glows and the cup pulses (not with reduce motion). When the last socket fills, a lit gold copy of the plate pops where it was (`dd_feedback._lit_plate`, fx mark `full_plate`), before FINISHED and the challenge stamp. The plate has its own tooltip ("Full set: +50 pts · 1 kill to go" / the challenge and its state). The same cup is in the Glossary (ON YOUR WEAPONS: Full set) and in the gun tooltip's new icon key row (rule, Full +50, challenge).
- **Tooltips:** a payload may carry `icon_keys` (the picture is that icon) and `icon_row` (glyph + word pairs under the two lines). Glossary adds "Rule chip: yes" / "Rule chip: no".
- **Cleanup:** one row per thing on the gun tile, sockets centred, one font step for the plate (52% of its height), rule text and plate text no longer shrink at 1440x900 and up.
- QA queries: `inspect=rulechip`, `inspect=plate1|plate2`. Shots and before/after sheets: `dd-ui6-shots/` (scratchpad).

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

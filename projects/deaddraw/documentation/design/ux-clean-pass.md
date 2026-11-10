# DeadDraw: UX clean pass (dd-ux-clean)

**What the head asked for:** the UI is too busy. Clean it out, put the player's eye in the right place, make it work held upright and held sideways, show less on screen, remove the duplicate information, show a wave as a stack instead of its contents, make the rooms bigger with a plain door cost, and make the game simpler and friendlier overall.

**Scope:** UI and UX only. The rules (`DDRun`, `core-rules-v3.md`), the balance and both save formats (profile and run save) are unchanged.

## 1. Audit (before)

We took screenshots of 12 states at three sizes: phone portrait 390x844, phone landscape 844x390 and desktop 1440x900. The project scales from a 560 px base with `canvas_items` / `expand`, so the logical screen is 560x1212 on a portrait phone, 1212x560 on a landscape phone and 900x562 on the desktop.

| Info on the street (before) | Where | Duplicate? | Needed for *this* decision? |
|---|---|---|---|
| Survivor chip (name + passive) | HUD | yes: title screen, HP zoom | no (zoom) |
| HP label + bar | HUD | - | yes |
| Cover chip, shown even at 0 | HUD | - | only when > 0 |
| Points chip | HUD | - | yes, quiet |
| Patch chips, one per Patch, in their own row | HUD row / right column | - | no (one chip + zoom) |
| Menu | HUD | - | yes |
| 3 wave decks, each with card count, IN PILE / DONE badge and zombie range | left | the zoom lists the same | no: one stack + the next threat |
| Boss tile with name, trait and phase chain ("then 10 -> 12") | left | boss zoom | number + name only |
| District name above the pile | middle | map, banner, pile title in landscape | no |
| Draw pile count + zombie count | middle | - | yes, quiet |
| Room tile **price** and the **OPEN price** button | right | **yes: the price twice** | price once, on the button |
| Room machine name, room name, OPEN badge | right | - | name + machine |
| Card kind label (ZOMBIE / GUN / MEDKIT) on every street card | street | art and colour say it | no |
| Damage chip, number, points line | street | - | **yes: the decision** |
| Prompt "Active: SERVICE PISTOL - tap a zombie... Resolve 3 of 4." | above guns | the gun's ACTIVE chip and the pips | short version |
| Resolve pips | prompt | the prompt's "Resolve 3 of 4" | yes |
| Log: 2 lines (portrait) or 5 lines (landscape) | bottom / right | the prompt's event line | 1 line, history behind a tap |
| Gun: name, ACTIVE, P#, kills, rule text (2 lines), challenge + state, "takes: 1-12", kill stack | bottom | the zoom has all of it | name, P · kills, rule icon + short label, reward, stack |
| Melee: P2, Crowbar, "no rule, 0 pts" | bottom | melee zoom | P2 + "0 pts" |

Other problems we found:
- Desktop 1440x900: the room column ran off the right edge.
- Landscape phone: the Run, Got it, OPEN and USE buttons were under 44 CSS px.
- Portrait: the room buttons were 60 px tiles with 13 px text.
- The HP panel opened its zoom on right click only, with no long press.
- Rotating mid-run left the content box at the old screen's size, so the new layout overflowed the screen.

## 2. Info hierarchy decisions

1. **Focus 1: the street cards.** They are the biggest tiles on the screen in every orientation (a test checks this). On a tall portrait screen they form a 2x2 grid of 260 px cards. The damage chip is bigger (22 px). Each card shows only the art, its number, its name and one result line ("+20 pts FINISH", "LOCK: ...", "heals 0").
2. **Focus 2: the weapon you hit with.** Each gun shows its name, "P2 · 3/4" with the ACTIVE chip, the rule as an icon plus a short label ("LOWER THAN TOP", "ANY ZOMBIE", via the new `DDText.rule_tag`), the challenge reward with its state, and the kill stack. The full rule, the challenge and "can still take" are in the zoom.
3. **Quiet, one per stat:**
   - The HUD is HP (with Cover only when you have some), points ("300 PTS"), **one** Patches chip and Menu.
   - The survivor's passive moved into the HP zoom.
4. **Waves as one stack:** a deck tile with card backs peeking out (`dd_stack_box.gd`), showing "WAVE 1/3", "×2" waiting and the next threat ("next: 2-7"). The zoom (or a tap) lists every wave. The boss shows its number and name, with "×3 at once" for the horde. The trait and phases are in the zoom.
5. **Rooms are bigger, and the price appears once, on the button:**

   | State | Button | Look |
   |---|---|---|
   | Can pay | `OPEN · 210 pts` | lit gold |
   | Can't pay | `210 pts · need 90 more` | dark, readable, with a gold-tinted outline |
   | Open | `USE` | green |
   | Used | `Used · back next wave` | |

   In portrait each room is a 128 px tile plus a 128 px button. In landscape each room takes a third of the right column.
6. **The prompt bar:** line 1 shows the resolve pips, "N left" and what to do now ("Tap a zombie · Service Pistol", or "BOSS: deal with every card"). Line 2 is what just happened, or why your tap was blocked. Tap or long press the bar for the history (the last 12 log lines). The separate log panel is gone.
7. **Short words:**
   - The first-run hints are one sentence each.
   - Banners are short ("WAVE 2 · 9 cards shuffle into the pile · zombies 2-7").
   - Run says "RUN · -1 HP"; when it is blocked the second line says why ("not twice in a row").
   - The sheets use three plain lines instead of a paragraph.
8. **Inspect everywhere:** every tile, chip, the HP panel and the prompt bar open a zoom on right click and on long press. Decks, rooms and Patches also open it on a plain tap, since tapping them does nothing else.

## 3. Responsive layout

There is one layout system that reflows the same pieces for each orientation. It never shrinks a tap target below **64 logical px, which is 44 CSS px** on a 390 px phone.

- **Portrait:** HUD / [waves stack + boss | pile (+ Lookout) | 3 rooms] / street (2x2 when the screen is tall enough, else 1x4) / prompt + Run / gun 1, gun 2, melee. The street gets the space first, then the board; the guns keep a fixed height.
- **Landscape (phone and desktop):** [waves stack + boss (+ Lookout)] | [HUD + pile / tip / street / prompt + Run / guns + melee] | [3 rooms].
- After a rotation, `_render()` snaps the content box back to the screen, so the new layout reflows.

## 4. Before / after (per screen)

| Screen | Before | After |
|---|---|---|
| Title | 2 lines of pitch, plus "Pick a survivor" twice in portrait; cards showed role, passive and "Best 0" | 1 line of pitch and 1 instruction; cards show HP, name, passive and best score (only when > 0); content centred |
| Map | Trait paragraph on each district; separate survivor and points tiles; one chip per Patch | Boss name only (trait in the zoom); one tile "HP 20/20 · 0 pts"; one Patches chip; 64 px Settings |
| Street HUD | Survivor, HP, Cover (even at 0), POINTS, Menu (+ the Patch row) | HP (+ Cover when > 0), PTS, one Patches chip, Menu |
| Street board | 3 wave decks + boss; pile with the district name; rooms with the price twice in small text | One wave stack (×N, next threat) + boss; pile as a pile; big rooms with "OPEN · price" or "need N more" |
| Street cards | Kind label + name + result line; small chip; 4 in a row (portrait 126 px wide) | Name + result line; 22 px damage chip; 2x2 at 260 px in portrait |
| Prompt / log | A long prompt + a separate 2-5 line log | Pips + "Tap a zombie · gun" + one "what happened" line; history on tap |
| Guns | 6 lines incl. 2-line rule text and "takes:" | Name; P · kills + ACTIVE; rule icon + short label; reward · state; stack |
| Gun sheet | Paragraph of rules | Power · kills, rule, challenge (3 lines); "replaces X (loses N kills)" |
| Machines | "TRIM ... - 50" | "TRIM ... · 50 pts"; 2 columns in portrait; Wall Rack in one line |
| Patch pick | "PATCH PRESS: pick 1 Patch (permanent for the run)" | "Pick 1 Patch · keeps for the whole run"; 64 px TAKE buttons |
| Boss street | Phase chain on the tile; long prompt | Number + name; "BOSS: deal with every card (N left)"; one-line Run past |
| Safehouse | Paragraph + full gun cards | 1 line + small inspectable kit tiles (HP, points, guns, Patches) + the Patch pick |
| Game over / victory | Long stats line incl. challenges and runs | "Best · kills · guns finished · rooms"; "New unlocks" |

The before and after screenshots are in the scratchpad `dd-ux-shots/` folder (`before_*`, `after_*`). The side-by-side sheets are `sheet_portrait_street.png`, `sheet_portrait_flow.png`, `sheet_landscape.png` and `sheet_desktop.png`.

## 5. Tests

`tests/test_ui_clean.gd` (4 tests) covers:
- 390x844, 844x390 and 1440x900: nothing overlaps or leaves the screen; every street and sheet button is at least 64 logical px; the street cards are the biggest tiles; the waves are one stack whose zoom lists all of them; OPEN states the price and "need N more"; guns show the short rule (full rule in the zoom); points appear once; one Patches chip; one log line with the history behind it.
- Rotating mid-run (portrait, landscape, desktop and back) keeps the run state and keeps a sheet open.
- Every inspect path works by right click and by long press (15 targets), and by tap on decks and rooms.
- Title, map, sheets, safehouse and end fit at all three sizes.

The existing `test_ui_flow.gd` and `test_feel.gd` pass unchanged. The web smoke test (`tools/smoke_web.js`, which now uses the wave stack at index 300) passes in both orientations against a local package build.

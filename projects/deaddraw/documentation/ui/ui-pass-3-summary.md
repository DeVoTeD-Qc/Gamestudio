# DeadDraw UI pass 3: summary

The studio head asked for a beginner-friendly first experience that isn't overwhelming: explain each idea
once, the first time the player sees it, and otherwise don't talk about it. Audit: `ui-pass-3-audit.md`.
There are no rule, balance or art changes, and the iOS memory work (MSDF font, evicting art cache) is
untouched: the pass adds no textures and no caches. The one new resident thing is the parsed 62-entry
concept table, which is a few KB.

## 1. One onboarding system: explain once
- **Registry**: `data/concepts.json`, read by `scripts/meta/dd_concepts.gd` (`DDConcepts`). It has 62 concepts.
  Each one has an id, a group, a short title, 1-2 plain sentences, a Guide icon (existing marks and art)
  and a `trigger` (when it first shows, in words). Numbers come from the balance (`{n:run_damage}`,
  `{pts:finish_bonus}`), so the texts can't drift from the rules.
- **Triggers**: `main.gd concept_candidates()` lists, for the current screen, the concepts that are on
  screen and matter for the decision now, most urgent first, each with its anchor (the card, gun, door,
  button or sheet). `DDConcepts.pick()` takes the first one the player hasn't seen.
- **Callout**: `scripts/ui/dd_callout.gd`. It puts a gold ring on the thing (the rest dims slightly) and
  places a bubble beside it, never on it (`place_rect`, tested). The bubble has an icon, a title, the
  text and a large "Got it" button (44 pt and up). Only one callout shows at a time. At most 3 show in a
  row; the next ones wait until the player acts. A callout waits 0.8 s after a screen change and doesn't
  open during banners, sheets animating, inspect, Guide, Settings, a drag, or while a finger is down.
- **It never triggers a game action.** While a callout is open, the whole screen is one catcher. A tap
  anywhere, Got it, Esc or Enter only dismisses it. The callout only dismisses on the release of a press
  it saw itself, so the tail of an earlier gesture doesn't count. Taps in its first 350 ms are eaten
  without dismissing it, because they were aimed at the game. Dismissing marks the concept seen and
  nothing else. Tests: `tests/test_concepts.gd` taps a zombie and RUN under a callout, and sends a stray
  release, Got it and a held finger; the run state is checked identical after each. The web smoke
  compares the game state before and after every dismissal.
- **Seen-set**: `DDProfile.concepts_seen`, saved on every mark through the crash-safe profile mirror
  (file, localStorage and sessionStorage). The concepts show whenever they are first met, not only on the
  first run.
- **Settings**: "Tips: ON/OFF" and "Reset tips".
- **Guide** (the ? on the street, Guide on the title, Guide in the Menu): replaces the icon Glossary. It
  lists every concept in full by group, whether seen or not, then every gun's challenge.
- **Inspect** (right click / long press, still on every tile): under its 2 lines it now shows the
  concepts behind the thing in full. That is 2 concepts on a short screen and 3 otherwise; for example, a
  Rifle shows "Lower than last", "Kill slots" and "Challenges".
- **Removed**: the 6 first-run hints (`hint_text`, `hint_due`/`mark_hint`, and the TIP toast that
  covered the event line), plus the always-on explanations listed below.

### First run
The first run (no run ended yet) deals from seed 11. The first street is 3 small zombies the Service
Pistol takes, plus a Plywood cover. The next deal brings a Hunting Rifle card and a holdover, then a
Medkit, an Alley Sweeper and a Pipe Wrench, so new ideas arrive a few at a time. Only the shuffle seed is
chosen; the rules are unchanged.

Typical order: hold to read (title); districts and your survivor's skill (map); the street, pick a
weapon, damage; then Any zombie, kill slots, challenges, points; then zombies, cover, gun cards, capacity;
then holdover, the pile, waves and Run from the second street; rooms once you have points; machines, the
Wall Rack / Bench / Patch Press when you first use them; the boss, its trait and Run past on the boss
street; the safehouse, the boss reward, Gun Mods and score after the boss.

## 2. Per screen, before -> after
| Screen | Before | After |
|---|---|---|
| Title | Pitch, "Pick a survivor (long press to read)", How to play / Codex / Settings | Pitch; the long-press line is gone (the "Hold to read" callout rings Rosa's card once); **Guide** / Codex / Settings |
| Map | Same | Same, plus the "Districts" and survivor-skill callouts once |
| Street HUD | PTS chip with "score N" under it | PTS chip shows only what you can spend (score in its tooltip, at the safehouse and at the end) |
| Wave door | "WAVE +2" over the number | "WAVE (of 3)" over the number (the waiting count is in the tooltip) |
| Locked room door | Price, bar, "+150 to use" | Price and bar only; "+N to use" appears on the gold plate once you can open it |
| Melee button | MELEE, "no pts", name | MELEE and the name ("no points" is in the Melee concept and the tooltip) |
| Medkit at full HP | "FULL HP" badge plus a "heals 0" line | "FULL HP" badge only |
| Boss street line | "Boss: resolve every card (2 left)." on every action | The last action, or "2 cards left to deal with." (the rule is the boss concept) |
| First-run hint | TIP toast over the event line (2 ideas per hint, 6 hints) | One concept per callout, beside its thing, 62 concepts |
| Safehouse | "+8 HP when you leave. Guns, Gun Mods and Patches come with you." and the shop's rule paragraph | Gone (the Safehouse / Score / Gun Mods concepts; the Leave button still says +N HP) |
| Gun Mod step | Rule line under the header (portrait) | Gone (the Gun Mods concept) |
| Glossary | Sections by icon shape | **Guide**: sections by idea (Basics, Your weapons, Gun rules, Cards, Board, Rooms, Bosses, Between districts, Survivors) |
| Inspect | 2 lines (+ icon key) | 2 lines (+ icon key) + the concept texts |

Kept on purpose: the event line under the street (the "what just happened" line, with its history on
tap), the damage chip and payout line on every street card, LOCK with its reason, the gun tile's
next-kill box, the Full set plate and the challenge line, and every tap target at 44 CSS px or more.

## 3. Concepts (62)
- **Basics**: Hold to read, Districts, The street, Pick a weapon then a zombie, Zombies, Damage, HP, Points
- **Your weapons**: Capacity, Kill slots, Fill a gun get paid, Challenges, Encore, Melee, Melee weapons, Uses
- **Gun rules**: Gun rules, Any zombie (Service Pistol), Lower than last (Hunting Rifle), Higher than last
  (Ratchet Crossbow), Same as first (Twin-Bore), Zig-zag (Lever Rifle), Within 1 (Scout Carbine),
  Odd / even (Nail Driver), Total ≤16 (Pump Shotgun), Big only (Elephant Gun), Small only (Alley Sweeper),
  One shot (Stovepipe Launcher), Locked zombies, Bent rule
- **Cards on the street**: Medkits, Cover, Gun cards, Salvage, Holdover
- **The board**: Draw pile, Waves, Run, Your Cover
- **Rooms and machines**: Rooms, Open a room, Machines, Wall Rack, Retrofit Bench, Patch Press, Patches
- **Bosses**: The boss street, Shatter, Horde, Phases, Run past
- **Between districts**: Safehouse, Score, Boss reward, Gun Mods, Open Breech, Last Round, Echo Chamber, Short Barrel
- **Survivors**: Steady Hands (Rosa), Triage (Imani), Slip Away (Theo)

## 4. Tests and tools
- `tests/test_concepts.gd` (7 tests): the registry is complete (every rule, machine, mod, boss trait and
  skill), short (at most 2 sentences, 170 characters) and has no unfilled placeholders; the Guide lists
  every concept in full; the bubble never covers its anchor; one callout at a time, marked seen, never
  twice, Reset tips; a callout never triggers a game action; a tap as it opens is eaten; inspect shows the
  concepts.
- `test_profile_save.gd`: seen-set saved, survives the mirror-only reload, Tips off, Reset tips.
  `test_ui_flow.gd`: the first street explains the street, then picking a weapon, then damage, then waits;
  nothing in the layout moves.
- `tools/smoke_web.js`: on the played path it checks that the title explains "Hold to read", the map
  explains "Districts" and the street explains "The street" and "Pick a weapon". Every callout must be on
  screen with Got it, every dismissal must leave the game unchanged, and no concept may come back after
  the reload. `tools/crash_reload_web.js` dismisses callouts before its taps.

## Open questions for the studio head
1. **Pace**: at most 3 callouts in a row, then the rest wait for the player's next action. Is that the
   right rhythm, or should it be 1 per action, which is gentler but spreads over more streets?
2. **Players who already played** (runs > 0) also get each concept once, because the tips follow "first
   time seen", not "first run". Should existing profiles start with everything marked seen instead? (Tips
   off is one tap in Settings.)
3. **Gun tile challenge line**: it still shows from the first street (goal and reward). Should it stay
   hidden until the "Challenges" concept has been explained, to keep the first streets even quieter?

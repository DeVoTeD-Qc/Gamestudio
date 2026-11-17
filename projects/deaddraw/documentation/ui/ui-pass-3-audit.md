# DeadDraw UI pass 3: audit (before)

Build: main at 81d2b24, skin A "Clean painted". Screens shot at phone landscape 844x390, phone portrait
390x844 and desktop 1280x720 (57 shots, `tools/audit_shots.js` in the pass's scratch folder; names
`<land|port|desk>_<screen>.png`). For each screen: what a brand-new player needs for the decision in
front of them, and what is noise for that decision.

The overall problem is not missing information. Explanations are always on screen, so every screen
teaches all the time, and the same number shows up two or three times. A newcomer can't tell which
line is the one that matters now.

| Screen | The decision | Needed | Noise (always on, duplicated or premature) |
|---|---|---|---|
| Title | Pick a survivor, start | Survivor art, name, HP, skill name; Start | "Pick a survivor (long press to read)" (a how-to line that is always there); "How to play" and "Codex" split the help in two (Glossary vs cards) |
| Map | Enter the district | The 3 districts, which one is next, its boss; Enter | "District 1 of 3" repeats the NEXT badge; "Boss:" prefix on every card |
| Street, first visit | Which weapon, which zombie | Street cards with their damage chip and payout, the weapon you hold, HP | The TIP toast covers the event line (portrait: the pile too) and explains 2 ideas at once ("tap a weapon... the red chip..."); only 6 one-off hints exist, so most ideas (rules, challenges, rooms, waves, Run, Cover, mods) are never explained where they appear |
| Street HUD | (Reading the situation) | HP, points | "score 0" under PTS (score is a run-end idea); "?" and "Menu" both lead to help |
| Wave door | (Reading the situation) | Which wave, the boss | "WAVE +2" (the "+2 waiting" count reads like a bonus); the boss badge is fine |
| Room doors (locked) | Is it worth saving for? | The price, how close you are (bar) | "+150 to use" on every locked door: a second price before the door is even affordable |
| Street cards | What it gives me | Payout / heal / cover line, LOCK reason | Medkit at full HP: "FULL HP" badge and "heals 0" line say the same thing twice |
| Gun tiles | Is my next kill legal, how close to the payout | Rule label, next-kill box, slots, Full +50 | Challenge line in 2 rows (name -> reward + goal) before the player knows what a challenge is; on Pistol "ANY ZOMBIE" and the "any" box repeat each other |
| Melee button | Switch to melee | MELEE, strength, name | "no pts" (always on; belongs in the explanation) |
| Strip | What just happened | The last-action line, the dots | Fine. Keep it as the single feedback line |
| Gun sheet | Equip / scrap | The gun, its rule, the 3 choices | Fine; "Challenge: Countdown -> +4 HP" before challenges are explained |
| Wall Rack sheet | Buy into a slot | Gun, rule, price, slot buttons | The price shows 3 times (the "150 PTS" tag and both buttons) |
| Bench sheet | Pick a service | The 6 services with prices | "Once per wave" (rule text; belongs to the Machines explanation) |
| Patch Press / pick | Pick a Patch | The Patches and their one line | Fine |
| Boss street | Fight or run past | The boss, its trait word, damage chip | Event line "Boss: resolve every card (2 left)" every time (explanation, not news) |
| Safehouse | Take the free Patch, spend, leave | Patch choice, points, HP, Leave | "+8 HP when you leave. Guns, Gun Mods and Patches come with you." and "Spend here: 1 Patch, or HP at 30 pts each. Points don't come with you; your score keeps them." (two always-on rule paragraphs); "score 100" under PTS |
| End | Run again | Result, score, Run again | Fine |
| Codex | Browse cards | Filter chips, tiles | Fine (it is a reference) |
| Glossary ("?" / How to play) | Look something up | The idea you are wondering about | Organised by icon shape ("NUMBER BADGES: THE CARD THEY SIT ON..."), not by idea; long |
| Inspect | What is this, what does it give me now | The 2-line tooltip | The general rule behind it (what a rule or challenge means) is missing: it's only in the Glossary |

Phone specifics: landscape is the tightest (door labels at 10-11 CSS px, and the room door's second line
is about 9 px); portrait door plates carry 2 numbers in about 70 px. Tap targets are already >= 44 CSS px.

## What the pass changes (summary; details in ui-pass-3-summary.md)
1. One onboarding system: a concept registry (`data/concepts.json`, 62 concepts). Each concept is explained
   once, in a callout anchored to the thing on screen, the first time it appears where it matters. The
   seen-set is saved in the profile. The 6 old first-run hints and their toast go.
2. The always-on explanations above are removed; the concept callouts and the inspect cover them.
3. Duplicated numbers go (locked door "+N to use", "score N" in the HUD, "FULL HP"+"heals 0", Wall Rack
   price tag, "WAVE +2", melee "no pts").
4. The Glossary becomes the Guide: every concept in full, grouped by idea. Inspect adds the concept text.

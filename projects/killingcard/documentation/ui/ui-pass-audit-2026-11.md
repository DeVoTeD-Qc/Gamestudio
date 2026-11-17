# KillingCard UI pass: audit (Nov 2026)

What I looked at: a public web build of `main` (81d2b24), played through a first run with
`?qa=1&seed=101`: consent, title, starting squad, loadout, run map, deck view, mulligan, match
(Deploy, inspect, a card selected, a card played, the firefight, round 2), match end, after-action,
Supply Drop, event. Viewports: 844x390 (phone landscape), 390x844 (phone portrait) and 1280x720
(desktop). The screenshots are in the session scratchpad (`kc-ui/shots-before/<size>/`).

The question for each screen: what does a player who knows nothing need for **this** decision, and
what is noise for them right now?

## Onboarding today: four systems that don't talk to each other

| System | What it does | Problem for a newcomer |
|---|---|---|
| Title "New here? Play the 3-minute drill" | Scripted 17-step match | It sits between the player and the game. It teaches things out of context and is separate from the real run. |
| "NEW · X" chips (NewCard) | A small chip, at most one per match, that marks the tip seen as soon as it shows | Easy to miss. It counts as "seen" even when nobody read it. Keywords only get a tip when the player is already in a match. |
| One-time toasts ("Left rail: your killstreaks fill...") | A long line over the board in round 2 | Overlaps the round recap (both visible in the round-2 shot). 30+ words. |
| Glossary (Codex / MENU) | Full list of keywords and icons | Good reference, but it lists no core concepts (supply, columns, tickets, REQ...) and doesn't show what is still new. |

So there is no single answer to "has this player been told what Pick does?"

## Per screen

| Screen | Needed for the decision | Noise / problems |
|---|---|---|
| Consent | Yes / No | Fine on phone landscape and desktop. Portrait 390: the panel is wider than the screen and clipped on the left (existing; not part of this pass, see the summary). |
| Title | START NEW RUN | The drill offer panel takes the primary colour (PLAY DRILL) on first launch, so the run gets pushed down to secondary. |
| Starting squad | Pick an Operator, see the deck | Each locked Operator shows passive and ability text in 9-10 px lines. The starter deck repeats "STANDARD ISSUE" and lore text on every tile. The concept of "Operator" isn't explained. |
| Loadout | 3 killstreaks (pre-picked) | Readable. "Streak 2 / 3 / 4 / 5" assumes the player knows what a streak is. |
| Run map | Where to go next | A good design (brief + GO + boss plate). Nothing explains tickets, REQ, the boss rule or what an event, shop or rest is until the player is already standing on one. |
| Deck view | What I own | Fine. |
| Mulligan | Keep or swap | Lore text on every card. The rule ("Tap cards to put back") is fine. |
| Match, Deploy | Which card, which column, READY | **Noisy.** Every Standard Issue hand card says "No ability". The Operator card says "Back next Deploy if down." in round 1. The initiative chip "1ST YOU TIE" shows in round 1, when nobody is behind. The PREVIEW eye says "OFF". The strip shows STREAK 0 next to 3 killstreak sockets (0/2, 0/3, 0/5). Nothing says what Supply, the +1 chips, INCOMING or the numbers on a card mean. |
| Inspect (right click / hold) | The rules | Works on hand cards, board units, badges, the recap and killstreaks. A unit shows its keyword lines in full. Good. |
| Card selected | Where to play | Clear (PLAY HERE on each column, CANCEL). |
| Firefight / recap | What happened | The per-column recap is clear. In round 2 the one-time "Left rail" toast overlaps it. |
| After-action | Continue | Clear, one primary button. |
| Supply Drop | Pick a card | Rules lines are good. "No ability: 3 FP, 3 Armor." reads as a negative. The "NEW · CALLING CARDS" chip sits under the cards and is easy to miss. TAP TO TAKE / DETAILS on each tile doubles the words. |
| Event / Rest / Shop | Pick an option | Each option says what it does. The screen never says what an event, a rest or the shop is the first time. |

## What the pass changes (details in ui-pass-summary-2026-11.md)
1. One onboarding system: a concept registry, and a callout the first time each concept is on screen. It folds in the NEW chips, the toasts and the drill offer.
2. Match declutter: no "No ability", no respawn line on the Operator card, no initiative in round 1 of a run, no PREVIEW eye in the first run, no "Left rail" toast.
3. Title: START NEW RUN is the primary action. The drill stays one tap away (TUTORIAL).
4. A gentle first fight: the first fight of a first run deals an opening hand that holds the deck's cheapest units (deck order only).

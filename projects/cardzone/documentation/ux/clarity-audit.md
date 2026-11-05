# CardZone: clarity audit and fixes (cz-clarity)

*UI/UX Agent · 2026-11-05 · Board task `cz-clarity` · Rules and balance unchanged.*

**Why:** the studio head tried to playtest and wrote: *"I don't understand what's going on. What the cards are giving me, etc."* They also said the "next hand" preview was too much information, and that every card needs a tooltip or zoom on right click or long press.

**Method:** I played the web build as a newcomer, first at iPhone 844x390 (touch) and then at desktop 1280x720 (mouse). I played against the Rookie and then the Veteran, took a screenshot every two steps, and wrote down every moment I could not answer one of three questions: *what is this?*, *what does it give me?* and *what just happened?* The confusion list is below. Every item has a fix, or is listed under "Not changed" with the reason.

Screenshots are in `../../qa/screenshots/clarity/`. Each `before-*` image is the build as the head played it, and each `after-*` image is the fixed build. All of them are WebP. The after images use device scale 1 and come from the real web export in Playwright.

---

## 1. Points of confusion (newcomer pass, before)

| # | Where | What confused me | Screenshot |
|---|---|---|---|
| C1 | Drop and every turn | **Two identical rows of cards on screen.** The top row is the "NEXT HAND" (the top of your loadout) and the bottom row is your hand, but they look the same. Even at the drop, before you have a hand, a full row of cards is already shown. I didn't know which row I was playing from. | `before-01-drop-next-hand-already-shown-844x390.webp`, `before-02-turn1-two-identical-rows-844x390.webp` |
| C2 | Strip header | `NEXT HAND = ARMOUR · BRACE 1 · 0 HELD · +5 BELOW` packs four game terms into one line before you know any of them. | same |
| C3 | Cards | Small stencil codes (`RH-30`, `RH-11`) on every card read as a stat or an ID that matters. They are decoration. | `before-02` |
| C4 | Cards | The icons (shield with a dash, magnifier, boot, crosshair, `R0`, dashed tag) are never explained. | `before-02` |
| C5 | Dock after tapping a card | `SCAVENGE · Search 1` / `Search 1` says the card text twice and never says what it does for me. | `before-02` |
| C6 | After any action | The result shows for 2.6 s in a toast at the top right (`You played Dash: Move +1.`) and then disappears. It gives no totals, so I lost track of my Move and Search. | `before-02` |
| C7 | Rival's turn | The steps play in a panel, but afterwards nothing on screen tells me what the rival did to me. The summary only appears when I skip. | `before-05-rival-turn-844x390.webp` |
| C8 | Whole screen | Nothing says **what to do now**. END TURN is a two-step action (Pack, then End), and the first tap goes into a mode that the tip explains in loadout terms. | `before-04-pack-empty-hand-tip-844x390.webp` |
| C9 | Loot sheet | The rows show name, cost and count only (`Scrap SMG · Search 3 · 3 left`). I couldn't tell a gun from armour without leaving the sheet, and the rows couldn't be inspected. | `before-03-loot-sheet-names-only-844x390.webp` |
| C10 | Buttons | UNDO, END TURN, LOG, the MOVE / SEARCH box and the dock buttons had no long press or right click explanation. | – |
| C11 | Top bar | `R1 · ZONE 1/14 · A` and four chips (`NOW 1 Calm`, `2 Calm`, `3 Drop`, `4 Gas`) mixed the round, the Zone card number and the route letter. The rival panel adds `Loadout 10 Held 0`. | all |
| C12 | Late game | `YOU 0 /5 HP` while you are still playing looks like a bug. In fact your health stack is empty and the next Hit puts you out. | `before-07-late-0hp-deep-fan-844x390.webp` |
| C13 | Played row | The `LINE` header ("LINE · 6 PLAYED THIS TURN") is jargon. | `before-06-brace-844x390.webp` |
| C14 | Inspector | The long-press inspector showed only the printed card text (`Search 1`). It didn't say what the card gives you now. | – |
| C15 | Help | The only explanation of the rules was RULES in the pause menu, as one long block of text. There was nothing before the first match. | – |
| C16 | Desktop | At 1280x720 and 1440x900 the hand fanned even with 5 cards, so the right-hand numbers (Search 1, Move 1) were hidden under the next card. | `before-08-desktop1280-late.webp`, the cz-clarity mid-pass desktop shot |

---

## 2. What changed (after)

### 2.1 Next hand hidden by default (C1, C2)
- The **NEXT HAND strip is hidden on your turn**. A single **DECK row** takes its place: `DECK · 10 CARDS · TAP TO SEE YOUR NEXT HAND`.
  - **Tap** it to show your next hand (`YOUR NEXT HAND · BLOCKS UP TO 3 · 0 KEPT · TAP TO HIDE`). Tap again to hide it. It hides itself again at the start of each of your turns.
  - **Long press or right click** it for "Your deck": how the loop works, what the next hand is for, and which cards are in it now.
  - When a Hit sits on top, the row adds `· 1 HIT ON TOP: DOWN`. That information is public and the damage depends on it, so it stays on the row.
- **The Brace step opens it automatically.** You block with those cards, and the rules (§16.2 P20) show them in the prompt.
- **Why keep it reachable at all:** the rules rely on it. You Brace with your next hand, and Hold decides what goes into it. It is your own information, so it is one tap away rather than gone.
- Screens: `after-03-turn-*`, `after-07-peek-next-hand-*`, `after-06-deck-explained-*`, `after-11-brace-*`.

### 2.2 Turn panel: what to do now, and what just happened (C6, C7, C8)
- The room the strip used now holds the **turn panel**:
  - **Phase line (what to do now):** `YOUR TURN · MOVE 0 · SEARCH 1` followed by one plain sentence: *Tap a card to PLAY it for Move and Search. Tap an area to move or loot. Tap a gun in your played row to FIRE. END TURN when done.* The other phases are `DROP IN`, `END OF TURN · KEEP UP TO 2`, `THROW`, `RIVAL'S TURN` and `MATCH OVER`, each with what to tap.
  - **Outcome feed:** the last 5 events in plain words, newest first, with the numbers that changed:
    - `You played Scavenge: +1 Search. You have Move 0, Search 2.`
    - `You looted Scrap SMG (a gun: 2 damage, same area only). It joins your played row and your deck.`
    - `Rival fired Pump Shotgun at you: 3 damage before you block.`
    - `The rival's shot hit you: -2 health, now 3. You are Down: the next shot at you deals 1 less.`
    - `Rival's turn: played 5 cards, moved to Rail Yard, looted Red-dot Sight, packed (0 held).` (one line after every rival turn)
- During the rival's turn its steps play over the turn panel (`RIVAL'S TURN · VETERAN · STEP 4`), and FAST and SKIP still work.
- New code: `ActionText.outcome()` (in `scripts/match/action_text.gd`). `describe()` and the match log are unchanged.
- Screens: `after-05-feed-*`, `after-10-rival-turn-*`, `after-13-late-*`.

### 2.3 Inspect everywhere: right click on desktop, long press on touch (C4, C9, C10, C14)
This is now a studio rule (CLAUDE.md, "Studio UX rules"). On the match screen, every element below opens the inspector:

| Element | Opens |
|---|---|
| Any card: hand, next hand, played row (yours and the rival's), loot / supply drop / crate rows in the LOOT sheet, attach targets | The card zoom (220x308 pt) with **NOW:** (what you can do with it right now: for a gun in your played row, the live shot preview), then **WHAT IT GIVES YOU** in plain sentences, then the printed card text, then an **icon legend** (shield = Brace, magnifier = Search, boot = Move, crosshair = damage, R = range, dark disc = loot cost, letter tag = rarity). |
| Areas (and their pile and gas chips) | Cover, gas, every pile with a short "what it is" (`Scrap SMG (C, Search 3) x3: a gun: 2 damage, same area only`), the supply drop, crates, and who is there. |
| YOU / RIVAL panels (health, DOWN, BOUNTY, NEXT HIT = OUT) | Health, Down, Bounty, the rival's deck size and kept cards, and its last played row. |
| Zone track (round, NOW / NEXT / THEN chips) | What gas, supply drops and the final circle do, then all 14 Zone cards for this route. |
| DECK row | How the deck loop works, plus your next hand. |
| MOVE / SEARCH box | What Move and Search are, how to get them, and how to spend them. |
| UNDO, END TURN, LOG | What each one does, including END TURN's two steps and the gas cost. |
| Dock buttons (PLAY, FIRE, MOVE HERE, LOOT…, PATCH UP, DITCH, THROW, ATTACH…, DROP HERE) | What the button will do. A long press never presses it. |

Loot rows also say what the card is on a second line (`Scrap SMG · Search 3 · 3 left` / `A gun: 2 damage, same area only`). New code: `scripts/ui/card_words.gd`, the plain words for every card, used by the inspector, the dock, loot rows and the feed. Screens: `after-04-card-inspector-*`, `after-08-pools-explained-*`, `after-09-loot-sheet-*`.

### 2.4 Less noise, plainer labels (C3, C5, C11, C12, C13, C16)
- **Stencil codes** (`RH-30`) are gone from the small cards. They remain on the inspector's big card, where they read as art.
- **Dock text** says what the card gives (`Play it: +1 Search this turn. Or keep it: while it sits in your next hand it blocks 1 damage when you're shot (Brace 1).`) instead of repeating `Search 1`.
- **Zone track:** `ROUND 4 OF 14` (`ROUND 4/14` on phones), and the chips read `NOW Gas · NEXT Calm · THEN Gas+Drop` (three chips, was four). The route letter and the full deck are behind inspect.
- **Rival panel:** name and health only. `Loadout 10 Held 0` moved into its inspect sheet.
- **`NEXT HIT = OUT`** tag at 0 health, in both the YOU and RIVAL panels. The panel's inspect sheet says how to Patch up.
- **"LINE"** is now **"PLAYED THIS TURN · 3"** (`RIVAL PLAYED · 6` on its turn). The rules and pause texts use *deck*, *played row* and *keep* instead of *loadout*, *line* and *hold*. The rule names (Brace, Hold) stay in brackets so the rulebook still matches.
- **INFO** is **HELP** when nothing is selected, and HELP opens How to play.
- **A 5-card hand always sits side by side** on every screen (phone, desktop and iPad): the card size is capped by the width of the right column. On the iPad this means cards of 128x179 px instead of 132x185 px. That trades cz19b's "bigger cards on tablets" for never hiding a card's numbers. See the questions.
- Screens: `after-03-turn-1440x900.webp` (no fan), `after-13-late-*` (NEXT HIT = OUT).

### 2.5 How to play (C15)
- **Seven bullets** (Goal, Your turn, Move and loot, Fight, End turn, Defend, Read anything) and an **annotated screenshot** of the match screen (`assets/ui/how_to_play.webp`, labels: map, Move + Search, hand, played row, END TURN, deck, what to do + what happened). Tap the picture to enlarge it.
- **Shown once before the first match.** The match waits until LET'S PLAY is tapped, and the device then remembers it (SetupPrefs `[coach] how_to_play`). **SHOW TIPS AGAIN** in settings shows it again.
- **Always reachable:** HELP on the match screen, and **HOW TO PLAY** in the pause menu (next to RESUME). RULES is still there for the full summary, now in the same words.
- **Coach tips updated** to match: `KEEP CARDS (HOLD)`, `BLOCK THE SHOT (BRACE)` ("Your NEXT HAND is open above your hand: tap cards with a shield…"), and DOWN and ADRENALINE without "loadout" or "top row".
- Screen: `after-01-how-to-play-*`.

---

## 3. Before / after: the biggest fixes

| Before | After |
|---|---|
| Two identical rows of cards (next hand + hand), plus a 4-term header | One row (your hand) and a DECK row: tap to see your next hand; it opens by itself when you're shot |
| The result toast vanished after 2.6 s; nothing summed up the rival's turn | A persistent "what happened" feed with the numbers that changed, and one line summing up each rival turn |
| Nothing said what to do now | A phase line on every turn: what to tap, and what END TURN will do |
| Long press on cards, areas and panels only; the inspector showed only the card text | Long press / right click on everything, including buttons, loot rows, the pools and the deck; the inspector leads with NOW and WHAT IT GIVES YOU, and explains the icons |
| No introduction; RULES was one block of text | How to play (7 bullets + annotated screenshot) before the first match, from HELP and from the pause menu |
| `0 /5 HP` while alive; `R1 · ZONE 1/14 · A`; `Loadout 10 Held 0`; `RH-30` codes | `NEXT HIT = OUT`; `ROUND 1 OF 14` with NOW / NEXT / THEN; rival panel shows health only; no codes on small cards |
| Desktop hand fanned with 5 cards and hid the numbers | Five cards side by side on every screen |

---

## 4. Not changed (and why)
- **Rules and balance:** nothing in `scripts/rules`, `data/` or the AI changed. The next hand is still fully available to its owner (a tap away), and the Brace prompt still shows it, as §16.2 P20 requires.
- **Card art layout** (cz16): only the decorative stencil moved off the small cards. Icons are explained in the inspector rather than redrawn.
- **Brace panel and playback panel buttons** (USE SUGGESTED, BRACE / TAKE N HITS, FAST, SKIP) have no long-press explanation. Their panels already say what each one does in the text above them. That's a candidate for a follow-up.
- **Hot-seat:** the feed is cleared under each pass-the-device cover, so one player's "You…" lines never reach the other.

## 5. Verification
- Tests: `godot --headless --path . -s res://tests/run_tests.gd`: **199 passed, 0 failed**, with no SCRIPT ERROR. New file `tests/test_clarity.gd` (6 tests): plain words for every card, outcome lines, the next hand hidden / peek / opened by the Brace step, the feed, long press on buttons, loot rows, pools, the deck row and a gun in the played row, How to play (first match, HELP, pause menu, remembered), and coach wording. Updated assertions: zone chips (`NOW Calm` / `NEXT Gas+Drop`), the inspector body (plain words, then "Card text"), the rival-turn tap (taps the map now), the FX reduced-motion test (peeks first), and the iPad card-size check (5 across instead of "bigger than desktop").
- Web: the packaged artifact build was smoked in Playwright at 844x390 (touch) and 1440x900 (mouse). It booted in ~1.4 s from localhost, and New match, Start, How to play and the match screen all showed no console errors (`package-smoke-*`). A QA copy with the scratch driver played whole turns, a rival turn, a Brace and round 5+ at both sizes with no errors (`after-*`).

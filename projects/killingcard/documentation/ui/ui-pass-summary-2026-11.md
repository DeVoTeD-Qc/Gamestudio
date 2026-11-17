# KillingCard UI pass: summary (Nov 2026)

The brief from the studio head: KillingCard is too noisy. Make it clear, not overwhelming, and
friendly to beginners. Onboarding should be a list of concepts where each one is explained the first
time the player sees it, and never again after that. This applies to every keyword too.

The audit is in `ui-pass-audit-2026-11.md`. There are no rule or balance changes. All art is original
UI, and no licensed art is touched.

## 1. One onboarding system: "explain once, the first time you see it"

| Piece | File |
|---|---|
| The concept list (id, title, 1-2 plain sentences, group, when it is first explained) | `scripts/ui/concepts/concept_registry.gd` (`ConceptRegistry`) |
| The callout bubble | `scripts/ui/concepts/concept_callout.gd` |
| The guide: queue, holds, seen set, tips on/off | `autoload/concept_guide.gd` (autoload `ConceptGuide`) |
| Tests | `tests/test_concepts.gd` |

How it behaves:
- **When it shows.** A screen calls `ConceptGuide.notice(id, anchor)` for what the player can see now.
  A concept the player hasn't seen yet is queued. One callout opens at a time, beside its anchor, with
  an amber ring around the thing it explains.
- **Where it goes.** The bubble never covers its target. It also avoids the button the player needs
  next (READY, GO, CONFIRM, SKIP) whenever the screen has room for it anywhere else.
- **At most 4 per beat.** A beat is one screen visit, or the time between two holds (for example,
  one Deploy). Anything left over comes back the next time it is on screen. A newcomer is never buried.
- **Holds.** Nothing opens while a round is playing, or while the recap, the inspector, the pause menu,
  a flyout, the end banner or the match intro is up, or while a finger or mouse button is down. While
  the mulligan panel is up, only the mulligan tip can open.
- **Input never passes through.** The callout is the last node under the root and swallows every
  tap, drag, key and controller button. A tap anywhere dismisses it, but only a tap that started
  after 0.35 s. For the next 0.3 s it also eats the rest of that tap, including a touch's emulated
  mouse release. So a callout can never press READY, select a card or start a drag. A test proves
  this on a live match: a tap on READY under a callout does not end the turn.
- **Seen means seen.** Dismissing a callout marks it seen, for good. The seen set is
  `Settings.seen_flags`, saved through SaveMirror (crash-safe on the web). The same ids as the old
  "New: X" flags are used, so tips a player already dismissed stay dismissed. A concept whose anchor
  is gone when its turn comes is dropped but **not** marked seen.
- **Settings.**
  - **TIPS: ON/OFF** in the match MENU and in the Glossary.
  - **TIPS OFF** on every bubble.
  - **RESET TIPS** in the Glossary. Every concept is explained again and tips turn back on.
  - The Glossary has a new **BASICS** tab with every core concept. The ones not seen yet are marked NEW.
- **Coverage is enforced.** `test_every_keyword_in_the_data_has_a_concept` fails in any of these cases:
  - a CardData or LoadoutItem property in the Keywords or Special rules groups has no concept;
  - a card in the data shows a keyword that has no concept;
  - a trait, a Terrain or an old reveal flag has no concept.

**Folded into this one system:**
- The "NEW · X" chips: `NewCard.offer` now hands systems the player has met to the guide.
- The one-time "Left rail: ..." toast.
- The first-launch "Play the 3-minute drill" panel.

**The drill.** I kept it, but made it optional (TUTORIAL on the title) and concept-driven: each step
lists the concepts it teaches (`TutorialStep.concepts`), and they count as explained.

Why the drill is no longer the default path: a newcomer learns best inside the real first run,
with each idea arriving the moment it matters, so their first minutes are spent playing the game they
came for. A forced 17-step scripted match up front teaches things out of context and delays the
fun. The drill stays one tap away for players who want a guided practice match.

### The concepts (77)

- **The match (22):**
  - goal, mulligan, hand, operator, supply, ready, stats (FP / Armor), incoming, firefight;
  - control (holding a column), streak, killstreak, initiative, operator ability, move;
  - tactic, field, elites, damaged, forecast (preview), sets (trait rail), terrain.
- **The run (22):**
  - squad, loadout, run map, fights, elite fights, events, shop, rest, the boss, tickets, REQ;
  - Supply Drop, calling cards, Doctrine, pick 2, retire, salvage, muster out, deck, deck summary;
  - modifiers, duel.
- **Keywords (19):**
  - First Shot, Pick, Flank, Pierce, Cover, Suppress, Patch, Holder, On Deploy, On Down;
  - End of round, Agile, Beam, Front line, Instant, Hidden, Doesn't hold columns, One use, No streak credit.
- **Traits (4):** Vanguard, Spec Ops, Heavy, Undead.
- **Terrain (10):**
  - Rooftops, Smoke, Dust Storm, Breach Point, Floodlights;
  - Comms Tower, Supply Cache, Hot Zone, Minefield, Field Hospital.

Each concept's text and trigger are in `concept_registry.gd`. Keyword texts are the same one-line
rules the card and the inspector print (`CardInfo.KEYWORD_RULES`), so a keyword never reads two ways.

Where each one triggers:
- **Match.**
  - Basics on the first Deploy, in this order: goal (score), Operator card, Supply, hand.
  - READY once a card is planned.
  - From round 2: firefight, streak, killstreak sockets, initiative, forecast.
  - When they are on screen: incoming, column control, Terrain, damaged, move, operator ability, sets.
  - Card keywords, types and traits on hand cards and on the units of both sides.
- **Run.**
  - Starting squad, loadout.
  - Run map: the map, the boss, tickets. REQ once you have some.
  - Each kind of stop the first time it is selected: fight, elite, event, shop, rest, boss.
  - Deck view.
  - Supply Drop, plus the offered cards' keywords and traits.
  - Shop (plus the cards on sale), event, rest.

## 2. Declutter: before / after

| Screen | Before | After |
|---|---|---|
| Title | First launch: a drill panel took the primary colour | START NEW RUN is the primary action; TUTORIAL is optional |
| Consent / surveys (portrait) | 880 px sheet cut off on a 390 pt phone | The sheet fits the width and its buttons share it |
| Starting squad | Locked Operators showed passive + ability paragraphs | Locked tiles show only how to unlock them; the kit is one long press away |
| Mulligan | A lore line on every plain card | Plain cards show name, cost, FP, Armor |
| Match, hand | "No ability" on every Standard Issue card; "Back next Deploy if down." on the Operator | Nothing where there is nothing to say (the card keeps its shape); the Operator concept explains respawning |
| Match, strip / tray | Round 1: initiative "1ST YOU TIE"; PREVIEW eye "OFF" | Initiative from round 2 of a run (then explained once); the PREVIEW eye shows from the second run |
| Match, round 2 | A 30-word "Left rail" toast overlapping the recap | Gone: the killstreak concept callout, anchored to the sockets, after the recap |
| Supply Drop | "No ability: 3 FP, 3 Armor."; the NEW chip under the cards | "3 FP, 3 Armor."; concept callouts beside the card that shows the keyword or trait |
| Every screen | Four separate tip systems | One |

Unchanged, because they already work well:
- Inspect on right click and long press: hand cards, board units, badges, killstreaks, the recap,
  map stops, reward and shop cards, all with the full keyword text.
- The per-column round recap: what just happened, with the numbers.
- The undo / plan feedback.
- The ≥ 44 pt targets (the callout's GOT IT and TIPS OFF are 60 px, which is 43-46 pt on a phone).

## 3. A gentle first run (no rule changes)

The very first fight of a first run deals from a seeded shuffle arranged so the opening hand holds
the deck's two cheapest units: something to play in round 1 and something in round 2.
`RunProgress.gentle_opening` only changes the deck order (`SideSetup.keep_deck_order`, as the drill
does); arts and traits move with their cards. The first-run map layout (no Terrain in early fights,
a fixed event) already existed and is unchanged.

## 4. Verification

- Unit tests: 785 → 794, all green. The new file is `tests/test_concepts.gd`. Also updated:
  `test_onboard_ui`, `test_match_run_flow` (title).
- Web boot / match smoke: reaches a match. The only console errors are the harness's audio-worklet
  404s, which happen before and after this pass.
- Screen tour at 844x390, 390x844 and 1280x720, before and after (session scratchpad,
  `kc-ui/shots-before`, `kc-ui/shots-after3`).
- iOS memory: the callout is a handful of Controls created per tip and freed on close. There are no
  textures and no caches.

## Open questions for the studio head
1. **Tip density in the first match.** The first Deploy explains 4 things in a row (goal, Operator,
   Supply, cards), then 3-4 per round. Is that the right pace, or should round 1 be just goal +
   Operator, with the rest spread out?
2. **The drill.** It is now optional and no longer offered on first launch. Keep it as "TUTORIAL",
   rename it "PRACTICE MATCH", or retire it once playtests confirm the in-run tips are enough?
3. **The PREVIEW (forecast) eye.** It is hidden during the first run and explained when it first
   appears. Should it stay hidden until a run is won, or come back sooner?

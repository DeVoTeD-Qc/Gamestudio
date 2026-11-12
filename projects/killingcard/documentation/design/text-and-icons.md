# KillingCard: text and icons

Task kc-text, 2026-11-11. Owner: Mid Game Designer. Covers what the head asked for:

- "Make sure all text is critical and cut all the fluff... The text hierarchy should help."
- "When an icon means something, it should be used everywhere we talk about that thing, like Supply."
- "Vanilla cards can each have their own lore."

Code: `scripts/ui/icon_text.gd` (IconText) holds the concept-to-icon table below. Keyword wording
lives once, in `scripts/ui/card_info.gd` `KEYWORD_RULES`. Lore lives in `scripts/ui/card_lore.gd`.
Tests: `tests/test_text_icons.gd`.

## 1. Text hierarchy

Every card sheet (the inspector, the Codex) reads top to bottom in this order. Each line has one job.

| # | Line | Style | Example |
|---|------|-------|---------|
| 1 | Name | head font, ink | Riot Shield |
| 2 | Type | small caps, muted | UNIT |
| 3 | Cost and stats | icons + numbers, muted | (hex) 4 Supply · (ring) 1 FP · (plate) 3 Armor |
| 4 | Rule | one line, ink, icons inline | Your front unit here gets +1 FP. |
| 5 | Keyword lines | icon + name (brass), then one short rule | (Cover) Cover 1 / Each hit on it deals 1 less. |
| 6 | Status | bold ink, the number that matters now | You have 3 Supply. |
| 7 | Flavour | italic, muted, inspector only | *Six hundred metres is a conversation, not a distance.* |
| 8 | Art caption | mono, muted | ART: MARKSMAN · 1 OF 5 |

Rules for the lines:

- **Tooltips and inspector lines: at most 2 short lines.** The rule first, then the number that
  matters. No "how to use the UI" words ("long press for rules", "tap to...") in a tooltip: every
  element is inspectable, so saying so is noise.
- **Explanations live in the Codex Glossary only.** Each keyword has a short line
  (`KEYWORD_RULES[id][1]`, inspector, first-play tip) and a full line (`[2]`, glossary).
- **No repeats.** A rule sentence that only names a keyword ("Pick.") is dropped from the sheet
  because the keyword line below says it (`CardInfo.rules_without_keywords`). The cost is on the
  stats line, so the status says only what you have.
- **Flavour is italic and never competes with rules.** A vanilla card (no keyword, no effect) shows
  its lore on its face, in the text box. Any other card's lore shows only on the inspector sheet,
  under the status. No filler line is ever shown on the sheet.

## 2. One name per concept, consistent verbs

| Concept | Use | Never |
|---------|-----|-------|
| A board lane | column (A, B, C) | zone, lane |
| The first unit in a column | front unit | point man, frontline unit |
| A face-down rival play | Incoming | red dots |
| Damage a unit deals | FP (glossary title: Firepower (FP)) | Firepower anywhere else (rules text, inspector rows, item lines), power |
| A unit's health | Armor | HP, health |
| Deploy currency | Supply | SUP, energy |
| Run currency | REQ (glossary title: Requisition) | credits |
| Run lives | Tickets (Reinforcement Tickets) | lives |
| Taking a card out of your deck (reward, Regroup, rest Drill, event, shop) | Muster out ("MUSTER OUT 2", marked: MUSTER OUT / STAYS; Honor Roll: "n MUSTERED OUT") | Retire, send home, going home, hand in kit |
| What a column is worth | "+1" tag on the column tile (Hot Zone "+2"), in the shape of who holds it now | points chip, VP |
| The match's target | "TO 6" on the SCORE badge, "FIRST TO 6" in the round recap | goal, win score |
| A card that resolves when played | Instant | Resolves immediately |
| The smallest deck allowed | deck minimum, "min" | floor |
| Eliminations counter | streak | kill count |
| Streak rewards | killstreak | ultimate |
| A unit dying | eliminated | killed, destroyed |
| A Field removed | destroyed | eliminated |
| The "Front line" keyword | Front line | Protector rule, slides to the front |

Verbs: "gets +N FP", "gets Cover N", "heals N Armor", "deal N damage to", "reveal incoming enemy
cards". Stat boosts are spelled out: "+1 FP and +1 Armor", never "+1/+1". Place words: a unit
says "here" (its column), a Field says "in this column", a tactic says "in a column".

## 3. Concept, icon, and where it appears

One icon per concept, everywhere. Inline icons go in front of the **first** mention of a concept
in a text block, so a sentence never turns into a row of icons. Stat icons keep their identity
colour (Supply amber, FP teal, Armor steel); keyword icons take the ink of the text around them.

| Concept | Words matched | Icon | Where it appears |
|---------|---------------|------|------------------|
| Supply | Supply, SUPPLY | amber cost hex (built-in `svg:hex`, the same hexagon as the card cost and the HUD Supply pips) | card cost hex, HUD Supply pips, hand chips, inspector stats line and status, card rules text, glossary, hover tooltips, Duel builder cost hexes |
| FP | FP, Firepower | reticle ring `stat_firepower` (teal) | card FP badge, board units, inspector stats line, card rules text ("+2 FP"), glossary, tooltips |
| Armor | Armor, ARMOR | plate `stat_armor` (steel) | card Armor plate, board units, inspector stats line, card rules text, glossary, tooltips |
| Cover | Cover | `kw_cover` (UI kit `stat_cover`) | card keyword line, Cover chip, inspector keyword line, rules text, glossary |
| streak | streak, Streak | rising arrow `streak` (amber) | HUD streak badge, killstreak inspector, card rules text ("streak +1"), glossary |
| killstreak | killstreak(s) | jet `type_killstreak` | killstreak tray, killstreak inspector, tutorial coach text, glossary |
| REQ | REQ, Requisition | requisition slip (built-in `svg:req`, brass) | REQ chip (map, shop, rewards), every run-screen button that names REQ (BUY · 4 REQ, NEED 4 REQ, MUSTER OUT, DISCHARGE, RESTOCK, PERK), REQ inspector, glossary |
| Tickets | Ticket(s), Reinforcement Tickets | ticket `tickets` (brass) | in front of the ticket pips (map, event, rest, after-action), rest and event texts in the inspector, glossary |
| First Shot | First Shot | `kw_first_shot` | card keyword line, board icons, inspector, rules text, glossary |
| Pick | Pick | `kw_pick` (lock-on brackets around a dot; kc-layout-a: no longer Armor's shield) | same as First Shot |
| Flank | Flank | `kw_flank` | same |
| Pierce | Pierce | an arrow through a plate (built-in `svg:pierce`, kc-layout-a) | same |
| Agile | Agile | a double arrow (built-in `svg:agile`, kc-layout-a) | same |
| Move (drag) | (not inline) | a four-way arrow on a dark disc with a teal ring (`SynergyGlyphs.draw_move_chip`, kc-loadout-clean) | top-right of your board unit while it can move this Deploy (the Operator's Rotate, an Agile unit's move), glossary row "Move (drag)" |
| Operator ability | (not inline) | the amber USE disc (ability_button.gd) on the deployed Operator card | the Operator hand card once it is deployed (darkened, DEPLOYED · B), glossary row "Operator ability card" |
| Suppress | Suppress | `kw_suppress` | same |
| Patch | Patch | `kw_patch` | same |
| Holder | Holder | `kw_holder` | same |
| On Deploy | On Deploy | `trig_on_deploy` | same |
| On Down | On Down | `trig_on_down` | same |
| Hidden | Hidden | `kw_hidden` | Field rules text, inspector, glossary |
| Front line | Front line | an arrow up to a bar (built-in `svg:front`, the card face's glyph; kc-layout-a) | card keyword line, inspector, glossary |
| Overrun | Overrun | `overrun` | Field inspector rule line, glossary |

Not inline (no icon art yet, or the word is too common to tag): Beam, End of round (their
glossary rows draw a glyph), Tactic and Field (type icons on the card frame only), Incoming (the
red dot + INCOMING back on the board).

How each surface gets its icons:

- RichTextLabel surfaces use `IconText.fill(label, text, px, ink, paper)`: inspector rules,
  stats, keyword rules and status; glossary rows; card face rules text (an overlay on the card's
  BodyLabel, which keeps the words and the layout).
- Buttons that name a concept get its icon with `IconText.tag_button(b)` (run screens' make_button,
  the shop's BUY buttons).
- Chips and counters use `IconText.icon_rect(concept)` (the REQ chip).
- The tutorial coach card draws its step text through an IconText overlay (Supply, FP, Armor,
  streak, killstreak in the steps get their icons).
- The run screens' ticket pips are led by the Tickets icon (`RunScreen.make_tickets`).
- Hover tooltips on the HUD and card controls (card view, unit slot, strip badge, objective tile,
  initiative chip, ability button, boss plate) render through `IconText.tooltip()`.
- `IconText.plain(node)` returns the words of any of these, for tests and accessibility.

## 4. Vanilla card lore

Every card with no keyword and no effect has its own line: at most 12 words, gritty military
humour, original (no franchise names or quotes). Shown in italics at the bottom of the card's text
box.

| Card | Lore |
|------|------|
| Private I | First day. Still thinks the chin strap is optional. |
| Private II | Learned to dig before he learned to shoot. Digs beautifully. |
| Private III | Survived three ambushes and the mess hall. The mess hall was worse. |
| Private IV | Promoted twice, busted twice. Net result: still the new guy. |
| Grunt | Signed for one rifle, one helmet and zero questions. |
| Trooper | Third tour, same boots. The boots are holding up better. |
| Armored Trooper | The plate is older than he is. Both still stop rounds. |
| Sergeant | Counts heads before the drop and after. Hates the subtraction. |
| Rifleman | Point, breathe, squeeze. Everything else is somebody else's problem. |
| Brawler | Ran dry once. The other guy ran out of teeth. |

A new vanilla card must get a line in `CardLore.LINES` (`tests/test_text_icons.gd` fails otherwise).

## 5. Word counts, before and after

| Surface | Words before | Words after | Change |
|---------|-------------:|------------:|-------:|
| Inspector keyword lines (17 keywords) | 254 | 132 | -48% |
| Glossary entries, non-keyword (19) | 658 | 484 | -26% |
| HUD badge inspectors (score, deck, intel, Supply, streak, menu, preview, killfeed, sets, initiative, hand) | 442 | 242 | -45% |
| Card rules texts (55 cards) | 357 | 327 | -8% |
| Tutorial steps (17) | 213 | 172 | -19% |
| Hover tooltip strings (all scripts) | 564 | 372 | -34% |

The glossary's keyword entries keep the full rules (that is where explanation lives now).

## kc-loadout-clean: moving units and the Operator card

- A board unit of yours that can move now (the Operator's Rotate, an Agile unit's free move) shows
  the **Move** chip top-right. Drag it (it starts after about 10 px): the columns it can reach
  light up (MOVE HERE), the others say why; a drop anywhere else snaps it back. Tap it, then a
  column, does the same. A long press still inspects it.
- The Operator is deployed by dragging its hand card onto a column (or tap it, then a column).
  Once deployed its hand card stays, darkened, with **DEPLOYED · B**: it is the Operator ability
  button. The amber USE disc on it says the ability is ready (tap it, or drag it to the column it
  targets); AIM / PLAN / WAIT / USED say the rest; a long press explains the ability. When the
  Operator goes down, the card turns back into the deploy card. READY and UNDO keep the whole
  bottom row.
- The rival's hand count is gone from every screen size; the SCORE flyout keeps the rival's
  incoming plays (RIVAL INCOMING).
- Loadout: killstreak tiles say NAME, STREAK n and the effect's first sentence (long press: the
  full rules). The Operator is one line (long press: its rules; OPERATOR & DECK: pick it, see the
  deck), the boss one line (tap: its rule), the modifiers you can add plus an "n LOCKED" chip.
- Deck view: the cards as card faces (calling-card art, name, cost, FP / Armor, an "x3" count), the
  Operator first; Standard Issue is a chip ("Standard Issue: 9 of 10", tap: what it means).

## kc-ux-text: global pass (2026-11-12)

The head asked for "a global pass to improve UX and make text and description more concise".
Rules unchanged; only words and layout.

- **After every round, one line says what happened, then what to do now** (the studio rule). The
  Deploy toast reads "Round 1: you +0, rival +2 (0-2). You eliminated 1 and lost 2." over
  "Round 2: drag your Operator onto a column." (or "play cards, then READY."), shown 4.5 s
  (`MatchController.round_recap`).
- **Instant** replaces "Resolves immediately" (keyword name and the two cards that use it:
  "Instant: draw 2.").
- Keyword-only card texts end with a period like every other rule ("Pick.", "First Shot.").
- **No UI-instruction words in tooltips, hints or subtitles** ("long-press for rules", "tap to...",
  "right-click any node"): every element is inspectable, so saying so is noise. The run map's
  subtitle is "Pick a lit node."; the starter's "Pick your Operator."; the mulligan's "Tap cards to
  put back (free, once)."; the shop has no subtitle; flyouts drop their "long-press" hint.
- Reward cards: the line under a card says what it does ("Flank: Shoots the back-most enemy."),
  never just the keyword the face already shows; a vanilla card says "No ability: 2 FP, 3 Armor."
- Inspector: the art caption shows only for a card with more than one art ("ART: MARKSMAN · 1 OF 5");
  Standard Issue reads "No trait. Muster out or Retire sends it home."
- "deck minimum" / "min" instead of "floor" in player text; "points" instead of "zone points".
- The Operator's rule line is "Back next Deploy if down." on every screen (hand, starter, title,
  after-action).
- Run end: the summary is the record, tickets and deck, then only the lists that are not empty
  (no "Perks: None").
- Glossary non-keyword entries cut by about a third; keyword glossary rows keep the full rule.

Layout fixes in the same pass: the card inspector stacks the card over its sheet when the screen
is too narrow for both side by side (phone portrait: the sheet ran off the right edge); the run
end screen stacks its summary over the match table in portrait (it ran off both edges).


## 5. Score race and tips (kc-clarity, playtest v28)

- The SCORE badge shows the round, the score and the target ("R2 / 0-2 / TO 6"). Your number sits on a
  solid plate, the rival's on a hatched one (the column plates' shapes), so it reads with deuteranopia.
- Each column tile ends in its worth tag ("+1"), drawn in the shape of who holds the column now.
- After every round a recap panel over the bottom of the board says, per column, who still had units
  there and who scored: "A  you 2 vs 0 left · you +1", then the score and what to do now. It stays
  until a tap on it or until you start to plan; long-press adds the scoring rule. Code:
  `scripts/ui/score_race.gd` (words), `scripts/ui/round_recap.gd` (panel).
- "NEW" tips never open over the board: a small "NEW · COVER" chip appears (at most one per match or
  reward screen), counts as seen, and opens the full card only on a tap. The Glossary keeps the full list.

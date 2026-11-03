# CallingCard: Vision, Pillars and Feature Concepts

*Sr Game Designer (performed by the Master Orchestrator in role) · 2026-11-03 · Phase: Design*
*Unofficial pitch about Call of Duty calling cards. All names, cards and art are original. A prototype would be a standalone concept demo, not a mod or recreation of Call of Duty.*

## 1. The problem, in one line
CoD players unlock hundreds of calling cards a year. Each one is a wide image you can equip one at a time, and the collection itself does nothing.

## 2. Vision statement
**"Every card you earned is a piece you can play."**
Calling cards become a **collection with a purpose**. The cards you earned the hard way are your best pieces in a quick side mode. Sets and hidden combinations turn the pile into an album worth completing. And your loadout of cards says something about you in every match, without ever touching shooter balance.

## 3. Design pillars
1. **Earned, not bought.** Power and prestige come from *how* a card was earned (challenge difficulty, mastery, prestige). Store cards may look amazing, but they are never stronger.
2. **Cosmetic-safe in the shooter.** Nothing changes damage, movement, information or visibility in a multiplayer match. All gameplay value lives in an optional side mode and in menus.
3. **Every card has a reason.** No dead cards: every card has stats, a set and a slot in the album. Rare ones have a trait. Hidden ones are a puzzle.
4. **Fits in the lobby.** Sessions are 2 to 4 minutes and playable during matchmaking, pre-game and in a companion app.
5. **The flex is the point.** Show off earned cards and signature moments ("You got carded") to friends and opponents.

## 4. Player experience goals
- **Target emotion:** *"I grinded for this card, and now it's worth something."* Pride, then the itch to chase the next set.
- **Core loop:** earn cards in the shooter → field them in the side mode and the album → see which cards you're missing or which would complete a set or combo → pick shooter challenges that unlock those cards → repeat.
- **Progression:** collection size, set completion (titles and frames), puzzle unlocks (secret cards), and mode mastery (ranked tiers in the side mode).

## 5. Feature concepts (across the head's three axes)

### A. Banner Wall: a side mode where calling cards are the pieces *(game mode, plus tactical choice)*
A 3-minute, 1v1 tile-placement duel. Players take turns placing their calling cards onto a **brick-wall board** of 10 wide slots. Each card has three values (**Top / Side / Bottom**). If your card's facing value beats an adjacent enemy card's value, you capture it. The **origin** of a card (challenge, mastery, event, prestige, ranked) gives it a trait, and same-**set** neighbors boost each other. You bring a **lineup of 5 cards** under a **Clearance cap** and mark one as your **Signature**. Capturing the enemy's Signature plays a "You got carded" moment. It's playable vs AI, vs friends asynchronously (against their saved lineup), and in the lobby during matchmaking.
- *Why it works:* it directly turns "how hard was this card to earn" into "how good is this card". Shooter balance is untouched.

### B. The Album: sets, hidden Triptychs and cipher puzzles *(puzzles / meta-collection)*
All cards sit in an **album** with empty silhouettes. Cards belong to **sets** (4 to 6 cards each). Completing a set grants a **title**, an **animated frame** and a **set badge**. **Triptychs** are hidden 3-card combinations. Equipping (or, with A, placing) three specific cards side by side merges their art into a panorama and unlocks a secret. Some card art hides **cipher glyphs**. Collecting a full glyph row reveals a code that unlocks a secret card. These are community puzzles, ideal for streams and guides.

### C. Signature Trio: a loadout of 3 cards with non-stat effects *(light tactical, cosmetic-safe)*
Replace the single slot with three: **Banner** (lobby/scoreboard), **Killcam Stamp** (what your victim sees) and **Squad Card** (shown on your squad's spawn intro and in a team "wall" in the end-of-match lobby). Equipping a full set gives a **set aura** (cosmetic border). Mode-only extras for casual playlists: each card's theme sets your **ping-marker style and callout voice line flavor**. These are purely expressive and never on in ranked.

### D. Bounty: a shooter mode where your card is your tag *(game mode, inside the shooter)*
A tag-collection variant. Eliminated players drop their **calling card** as a physical tag. Each card's "bounty" is its earn difficulty, so carrying a prestige card makes you worth more points. That's a flex with a risk. Collect enemy tags for score; deny your team's tags. Season stamps track whose cards you've collected. Unranked mode only.

### E. Card Contracts: equip a card to arm a themed mini-challenge *(tactical planning, puzzles)*
Each equipped card (or each card in the Trio) arms a **contract** that fits its theme. For example, "Last Train" → *win a match in the final 30 seconds*. Completing contracts upgrades that card's **stamp tier** (bronze → silver → gold → animated) and progresses its set. Players plan their card loadout around the match they're about to play. It's planning, not power.

## 6. Scoring

Scale 1 to 5 (5 = best). **Integrity risk** is shown as a rating (lower is better). Cost is rough effort for a live CoD team (S/M/L, est.).

| Concept | Fun | Collector motivation | Integrity risk | Cost | Web-prototypable | Notes |
|---|---|---|---|---|---|---|
| **A. Banner Wall** | **4** | **5** | **Very low** (separate mode) | M–L | **Yes, fully** | The only concept that gives *every* card play value. Needs a stat formula for existing cards. |
| B. The Album | 2 | **5** | None | S–M | Partly (menus only) | Cheap and strong, but on its own it's a checklist, not a game |
| C. Signature Trio | 2 | 4 | Low–medium (killcam/ping clutter) | S | Weakly | An easy win. Triples the "show" value. |
| D. Bounty | 4 | 4 | Medium (rare-card holders get hunted; unranked only) | M | No (needs a shooter) | Great flex, but it's a shooter-team feature |
| E. Card Contracts | 3 | 4 | Low (can pull players off the objective; keep it out of ranked) | S–M | No | Good retention glue for A and B |

## 7. Recommendation
**Prototype A, Banner Wall, as a small web concept demo, with a light slice of B (album, sets and one hidden Triptych) built in.** Sets and Triptychs are part of Banner Wall's own rules, so this stays one prototype.

Why A:
- It's the only concept that answers *"what can I do with my cards?"* with "play them". The head asked for real value, and this is the most direct form of it.
- It covers all three axes the head named: a **game mode** (the duel), **puzzles** (Dossier puzzles with fixed hands, plus hidden Triptychs), and **tactical usage** (lineup building under a cap, Signature choice, placement), all in a space that can't affect shooter balance.
- It's the only concept we can genuinely prove in a browser in a week.

**Suggested long-term roll-out (for the pitch):** Phase 1: A + B. Phase 2: C (cheap and visible). Phase 3: E, then D as a seasonal limited-time mode.

## 8. Success metrics (for the demo, and what a live version would track)
- **Intent to collect:** at least 70% of playtesters agree with "I'd go after specific cards to use them in Banner Wall" (survey, 1 to 5 scale, 4+ counts).
- **Album pull:** at least 50% of playtesters open the album at least twice and inspect a card they don't own.
- **Session fit:** median duel length under 4 minutes; the tutorial Dossier is cleared in under 3 minutes.
- **Fairness perception:** at least 70% agree that "earned cards being stronger feels fair, store cards being cosmetic feels fair".
- *Live (est., for the pitch):* share of players who equip a non-default lineup, set completion rate, and Banner Wall sessions per matchmaking wait.

## 9. Handoff to Mid Designer
Spec Banner Wall in full: board, values, traits, sets, Clearance cap, Signature, Triptychs, Dossier puzzles, AI behavior, a 20-card original sample list and a session walkthrough. Keep the rules readable in under 60 seconds: three numbers per card and one trait.

# Warbuilder: Design Review (Core Loop, Rules Clarity, Print-and-Play)

*Sr Game Designer (run by the Master Orchestrator) · 2026-11-04 · Board task `wb-design` (part of `wb-assess`)*
*Based on the engine rules (`engine.js` v4.0/v5.0 state, live `TUNE` values), the in-game "How to play" and codex, 4 UI matches, 14,000+ simulated matches (`documentation/qa/playtest-report.md`) and the print-and-play rules page.*

## 1. The game in one paragraph
Two operators drop into a row of 6 location cards, each carrying a pistol and a 10-card starter deck. On your turn you play cards for **Movement, Precision, Intel, extra shots and Armor**. You make **one move** along the row, **buy the top card** of the loot stack where you stand (or next door for +1 Intel), and **fire**. A shot **reveals one card from your own deck per Precision**, and the **Hit Markers** printed on those cards are added up against the gun's two-step **damage ladder**. Cover, Armor and Reaction cards reduce the damage, and a hit always deals at least 1. After each round the gas takes the rightmost location, and a new one is dealt on the left from a three-phase "new ground" deck. You win by bringing your rival from 30 health to 0.

## 2. Core loop
```
play cards → resources (Move / Precision / Intel / shots / Armor)
     ↓
move once → arrive: location bonus + flip its loot stack
     ↓
buy the top card (or cycle it) · Buy Station · Scrap
     ↓
fire: reveal N = Precision cards from YOUR deck → count Hit Markers → ladder → damage
     ↓
end turn: unused Move → Armor (max 2) · discard all · draw 5 (6 at ≤ 10 health)
     ↓
round end: gas takes 1 location on the right, new ground appears on the left
```

## 3. What's fun (keep these)
1. **"Your deck is your aim."** Shooting reveals cards from your own deck and counts their Hit Markers. This is the best idea in the game. Every buy is two decisions at once: what the card does when played, and how many Hit Markers it adds to your aim. Thinning your deck (Scrap) makes you shoot better. We know of no other deckbuilder that resolves shots this way, and it plays just as well on paper.
2. **Guns feel different.** Range bands (the knife at 0, the Longbow at 1–5), shots per turn, Recoil (each shot costs Precision, so "your first shot is your best") and the two-step ladder (Magnum 5 → 8, Longbow 5 → 9 "HEADSHOT") give each class its own feel with very few numbers. Five rarities that pre-install attachments are a clean way to show upgrades.
3. **Loot stacks.** Only the top card is buyable, cycling costs 1 Intel or 1 Movement, and the next-door stack costs +1. It's a light push-your-luck market that is easy to read. Supply crates in rounds 2 and 4 add spikes.
4. **Healthy comebacks.** The player behind at round 5 still wins 41% of the time. Armor from unused Movement ("dig in"), Reaction cards and drawing 6 at low health all soften the lead.
5. **Fair start.** The first player wins 50.5%. The alternating first player works.
6. **Production quality.** The UI, card faces, the fire report with the revealed cards, and the codex are well above prototype level. The AI is a real opponent.

## 4. What's weak (ranked by impact)
1. **The battle royale isn't there (the gas doesn't matter).** The gas is a conveyor, not a closing circle. One location leaves on the right and one arrives on the left every round, so the play area stays at **6 locations for the whole match**. Gas causes **0.6% of all damage**, and **no match in 2,000 reached the final circle**, because the new-ground deck (12 cards) outlasts the match (9.4 rounds). The title, the art and the rules promise "before the gas closes in", but the match is a duel on a sliding strip. *Fix direction:* make the circle actually shrink. Use a shorter new-ground deck, or let the gas take 2 locations per round from phase 2 while only 1 arrives. Add a final circle with escalating damage and a **hard end** (as CardZone does by round 14). Targets: final circle in at least half of the matches, gas 10–20% of damage, and no match past round 13.
2. **Shots rarely miss.** When a competent player fires, the hit rate is **83%**. The reveal is exciting, but the answer is usually "hit". *Fix direction:* aim for about 60–70% on a typical first shot by raising the first ladder step by 1, or by making Hit Markers a little scarcer on cheap cards. Then make the second step more reachable, so that spending more Precision upgrades damage rather than buying safety.
3. **Too many currencies for the depth they add.** Five resources (Move, Precision, Intel, extra shots, Armor), plus Hit Markers, Recoil, cover, combo boxes, gun combos, Reaction, dig-in, Scrap, free cycles and range bands. Each is simple, but a new player meets about 15 icons on the first turn. *Fix direction:* cut or merge. For example, fold "extra shots" into the gun, and make combos either matter or go away (see 4).
4. **Combo boxes are decoration.** An AI that ignores combos when buying wins exactly as often (47.5% vs 47.6%). Combos trigger by accident in any mixed deck. *Fix direction:* either make them strong enough to build around (bigger payoffs that require a specific *pair* of roles), or remove them and simplify the card text.
5. **Close-range guns are weaker.** Matches won by knife, SMG and shotgun holders: 32–44%. Sniper, burst and launcher: 53–64%. A range-0 or range 0–1 gun needs both players on the same or adjacent tiles, and the AI (and the cover rules) rarely allow that. *Fix direction:* let distance-0 shots ignore cover and Armor (the "close quarters" rule is already half there), or give close guns +1 shot.
6. **No drop choice.** Players always start on the 2nd and 5th locations. A battle royale's first decision, where to land, is missing. *Fix direction:* drop draft (CardZone uses reverse-order drop).
7. **Two rarity languages.** Tier-1 loot says "Uncommon" next to "Common" guns, cards use chevrons, and guns use colours (playtest B5). *Fix direction:* one scale everywhere.
8. **Rule debt in the code.** `TUNE` has about 70 switches (ammo, slots, squads, allies, mastery, perks, workbench burning, punching, several distance modes and more). Most are off, but the code, the UI and the PnP still carry them. The phase log even announces perk drafts that don't happen (playtest B1). It's hard to say which ruleset is "the game". *Fix direction:* freeze the live ruleset, write it down as the one source of truth, and delete the dead modes once tests cover the live ones.

## 5. Rules clarity
**Good:** "How to play" fits on one screen. Tooltips (hover or press-and-hold) explain every chip. The fire report shows exactly which cards were revealed and why the shot hit or missed. The codex lists every card.

**Unclear or wrong:**
- "Recoil": the rule ("lose the gun's Recoil in Precision for the rest of the turn") is right but abstract. Show it on the FIRE button as "next shot: reveal 3 → 1".
- The odds of a shot are not on the main FIRE button (playtest B10). The AI hits 89% because it waits for good odds, and a new player doesn't know to.
- The final-circle rule is documented but never happens (section 4.1).
- Phase-change text promises perks and a faster gas that don't exist (playtest B1).
- "Uncommon" on tier-1 stacks (playtest B5).
- "Combo box: … Uncommon cards combo with their own role; Rare and Epic cards with their own role **or** a second one." This is precise but heavy. Players will read the icons, not the sentence.

## 6. Print-and-play fit
**What works on paper:** the shooting reveal is great at a table: flip N cards and count the crosshairs. Location cards with printed stack icons (gun or card, top first) make setup checkable. The generator builds everything from the live engine data, so paper and web can't drift. That's a real strength; keep it.

**What hurts on paper:**
| Problem | Why it hurts | Suggestion |
|---|---|---|
| Five per-turn resources | Needs 5 counters or a dial per player, reset every turn | A player mat with five tracks, or cut to 3 resources |
| Sliding row | Every round a card leaves the right and one arrives on the left, so the row crawls across the table | Gas tokens on a fixed row, or a fixed 7–9 card map that closes from both ends |
| Setup | 6 face-down tier decks, 6 Start locations, 18 location cards in phases, a stack per location built by the icons | Pre-build loot stacks in bags or envelopes by phase; a 1-page setup diagram |
| Size | 151 cards + 30 guns + 18 large locations + references = 27 Letter pages | Fine for a prototype; trim with the rarity and combo simplification |
| Supply crate placement, combos, gun combos, Recoil, cover, Reaction | Each is a small check, and all of them are easy to forget | A turn-summary card in the order things happen |
| Branding | "WARZONE DECKBUILDER" is printed on every page footer | Rename (see the IP check) |

**Estimated table time:** about 30–40 minutes for two experienced players (18 turns at 1–2 min), plus about 10 minutes of setup. That's fine for a duel, but the setup is heavy for the length.

## 7. Recommendations for the design (summary)
1. **Make the gas real** (shrinking circle, escalating final circle, hard end). Biggest gain to theme and pacing.
2. **Tune hit odds** to about 60–70% and make the big hit more reachable.
3. **Decide on combos** (deepen or delete), and **one rarity language**.
4. **Buff close-range guns** (close quarters ignores cover and Armor).
5. **Drop choice** at the start.
6. **Freeze the ruleset** and remove the dead modes after the test harness is in.
7. For paper: a player mat for resources, a fixed map that closes from both ends, and pre-packed loot by phase.

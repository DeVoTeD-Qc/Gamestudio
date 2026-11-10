# KillingCard: Duel mode (build a 10-pick deck, pick a hero, play one battle)

*Author: Sr Game Designer Agent · 2026-11-08 · Board task kc-duel-design · Status: **design for the head's review**. No rule, UI, scene or data file was changed. The sim is the new `source/project-killingcard/tests/tools/duel_sim.gd`: it plays the real engine (MatchState, ModeRules, the Operator kits, SynergyRules, AiPlayer / AiPlanner on both sides) with 2-copy decks. Everything Duel-specific that the sim tries (hero-draw variants, Duel hero numbers, no Doctrine, AI tiers) lives in that file and is applied in memory.*
*Inputs: `run-v2.md` (§7 Operators, §15 kc-econ economy), `card-system.md`, `synergy-system.md` (traits v2.2), `onboarding-progression.md` (reward rungs, Codex), `art-traits.md` (a copy's trait comes from its art), `data/cards/*.tres`, `data/loadout/*.tres`, `data/run_config.tres`, `scripts/ui/match_controller.gd` (today's Quick Match), `scripts/data/pitch_decks.gd`.*
*The head (verbatim): "a campaign mode where we start with the starter deck and play through as we have now. But also a duel mode where you set up a small deck and play a one-shot battle against AI or another player. Deck building should be simple and straightforward: you pick only 10 or 12 cards; as soon as you select a card it's 2 copies in the deck; then you select a hero that's a single card with a special feature. No huge decks with 3-4 copies. Maybe you need to draw the hero, maybe you start with it — that's a good question."*

> **kc-duel-tune (2026-11-10): the head answered D1–D5, and §12 "Decisions" is now the source of truth.** In short: the hero stays in its own slot and decks stay at 10 picks (D1, D2 as recommended). The card pool follows D3 (a). There is **one set of Operator numbers for both modes** (D4 b): Wasp-9 2/9, Bastion-60 2/8, Marked Shot 2. The duel-only hero lines of §3.3 are dropped. **The player picks a Doctrine** (D5 c): in Duel it starts a set but never completes one. The Undead set moves its Cover from the 3-set to the 2-set. Where §0–§11 disagree with §12, §12 wins.

## 0. Summary in eight lines
1. **A Duel deck is 10 picks plus 1 hero.** Every pick puts exactly 2 copies in the deck, so the deck is always 20 cards. You can pick each card once. The deck needs at least 5 unit picks, at most 1 Elite ★ pick and at most 3 Field picks. Nothing else blocks it; the curve and set hints are advice only (§2).
2. **The hero is your Operator** (Kestrel AR-7, Longreach .338, Wasp-9, Bastion-60): its body, its passive and its once-per-match ability. **It starts in your command slot**, as it does today. You can place it from round 1 (free in round 1), and it respawns for 1 Supply. It is never shuffled into the deck. In the sim, a hero you had to draw never showed up in 44% of games, and the side that got its hero first won 85% (§3).
3. **Same game as the campaign.** Round N gives N Supply (cap 7), you draw 4 + 1 with a free mulligan, then 1 card per round. Zone Control to 6. The 3 starter killstreaks. Duel has no Terrain, no perks, no weapon levels and **no Doctrine**. With Doctrine, mono-Undead decks won 71–74% (§2.4).
4. **Duel hero numbers** (4 small Armor and damage changes, Duel only): **Kestrel 3/7, Longreach 3/6 with Marked Shot 2, Wasp-9 2/8, Bastion-60 2/7**. On the campaign numbers, Longreach won 72% of hero mirrors and Bastion 31%. On the Duel numbers the four heroes win **47.6–55.2%** (§3.3).
5. **Modes:** Duel vs AI with three tiers (**Recruit** for new players, **Regular**, **Veteran**) and Pass & Play hot seat on one device. Online PvP is listed as later work (§4). **Four preset decks**, one per trait, each with its own hero: Spearhead, Overwatch, Iron Wall and Hollow Ranks (§5).
6. **Deck builder:** a filterable card grid where each tap adds "×2", a "7/10 PICKS" counter, a curve chart, a hero picker, 8 save slots plus the 4 presets, and plain validity lines. A long press or right click inspects every card and hero (§6).
7. **Campaign feeds Duel, never the other way round.** All units and tactics are in the Duel pool from the start. Fields and Elites unlock when you find them in a campaign run. Arts and their traits come from your Codex. Duel gives records and cosmetics only, and the campaign stays starter-deck based (§7).
8. **Sim (over 50,000 games on the real engine):** presets **45.4–52.8%** each (n ≈ 600 each). Heroes **47.6–55.2%**. Seat 0 **50.3%**. **6.2 rounds** a match, which is about 5–6 minutes against the AI and 8–10 minutes in hot seat. New-player proxy vs Recruit **69.5%**, competent proxy vs Regular **58.3%** and vs Veteran **48.1%**. A good deck beats a random legal deck **70%** of the time (§8).

---

## 1. Goals and pillars
| Goal | Measure (target) | How the design meets it |
|---|---|---|
| Building is quick | A first deck in under 2 minutes; at most 3 rules a player must know | 10 taps for cards and 1 for the hero. The rules are 10 picks, at least 5 units, at most 1 Elite and 3 Fields |
| You see your picks | The chance of drawing a given pick in a match: 75% or more | 2 copies in a 20-card deck give **76%** by round 6 (§2.2) |
| Heroes are a real choice | Each hero 45–55% against the others on the same deck | 47.6–55.2% (§3.3) |
| Presets are fair | Each preset 45–55% in the round robin | 45.4–52.8% (§5) |
| Seats are fair | Seat 0 45–55% | 50.3% (§8) |
| Length | 6–10 minutes | 6.2 rounds a match: about 5–6 minutes against the AI, 8–10 in hot seat (§4.4) |
| One game to learn | Rules that differ from the campaign | Only what's left out: no map, no REQ, no Terrain, no Doctrine, no weapon levels or perks. The deck rules and the hero rules are new |
| The campaign stays itself | Campaign numbers unchanged | No shared rule or data changes. Duel hero numbers are separate resources (§3.3) |

Design pillars for Duel:
1. **Every pick is a pair.** One tap gives two copies, always. No copy counts and no exceptions, Elites included.
2. **The hero is always there.** Your hero is the face of your deck, so luck never decides whether it shows up.
3. **Campaign finds, Duel plays.** Cards you discover in a run become Duel cards. Duel never makes the campaign easier.

## 2. Deck rules

### 2.1 The rules (what the builder enforces)
| Rule | Value | Why |
|---|---|---|
| Picks | **exactly 10** (each = 2 copies) → **20 cards** | §2.2 |
| Copies per pick | **exactly 2**, always | The head's rule. Elites too: there are no 1-copy or 3-copy cards |
| The same card twice | not allowed (one pick per card) | "Pick a card, it's in your deck ×2" stays true |
| Unit picks | **at least 5** | Columns are won with bodies. A deck under half units loses Zone Control by default. The random-deck tests ran under this rule |
| Elite ★ picks | **at most 1** | Elites are the named heroes of the card pool. Two Elite pairs (4 five-drops) make a top-heavy deck that feels unfair against Recruit-level decks |
| Field picks | **at most 3** | One Field per side per column (Model B). With more than 6 Field cards you draw Fields you can't place |
| Hero | **exactly 1** of the unlocked Operators | §3 |
| Cards that are never in the pool | tokens (Sentry, Shambler), boss rules, Standard Issue | Standard Issue is the campaign's starter kit, and it's plain on purpose. Duel starts from real cards (§7) |
| Trait | **chosen per pick through its art**: both copies wear the same art, so they share its trait (`trait_options`, art-traits.md) | One choice per pick, as the campaign's art rule. No trait limit (§2.4) |
| Loadout | the 3 starter killstreaks (Recon Drone, Mortar Barrage, Attack Helo) for both sides; no perks, attachments or weapon levels | A one-shot battle has no run to earn them. Both sides are equal |

**Advice, never a block** (amber lines in the builder, §6.4):
- Fewer than 2 picks that cost 1 or less: "Round 1 gives 1 Supply. You may have nothing to play."
- 4 or more picks that cost 4 or more: "Heavy curve: these land from round 4."
- No two unit picks share a trait: "No set: 2 units of one trait give a bonus."
- No tactic: "No tactics: you can't answer a column in one round."

**No rarity limits beyond Elite ★** (card-system §2.7: the Elite is the only gameplay rarity). **No cost-curve rule** beyond the advice: the economy (1 Supply in round 1) already punishes a top-heavy deck, and the advice says why.

### 2.2 Why 10 picks (and not 6, 8 or 12)
A match lasts about 6 rounds, so you draw about 10 cards (5 in round 1, then 1 a round). How much of the deck you see sets how much each pick matters.

| Picks (cards) | Chance of drawing a given pick by round 6 | Reshuffles per game | A preset vs a random legal deck (n = 400) | Rounds |
|---|---|---|---|---|
| 6 (12) | 98% | 0.95 | 82.2% | 5.8 |
| 8 (16) | 88% | 0.10 | 81.8% | 6.0 |
| **10 (20)** | **76%** | 0.00 | **70.4%** | 6.3 |
| 12 (24) | 67% | 0.00 | 69.8% | 6.4 |

*(The chance is 1 − C(D−2, 10) / C(D, 10) for a pair in a D-card deck after 10 draws. The edge column is `duel_sim exps=build`: each preset is cut to its first k picks or given its 2 spare picks, with Kestrel on both sides.)*
- **6 or 8 picks:** you see almost the whole deck, so the best deck wins too easily (82%). A 12-card deck reshuffles every game and plays like a combo. There are also too few decisions: 6 picks is 6 taps.
- **12 picks:** you see two thirds of the deck, so a third of what you built never shows up in a typical match. The deck edge is the same as at 10 (69.8% vs 70.4%), so the 2 extra picks are weight without being a choice.
- **10 picks** keeps 3 in 4 picks in a typical match and leaves skill a large edge (70%). It's also the campaign's deck size ×2, with the same pairs idea.
- **The draw rule stays 1 per round** (the campaign's). With 2 per round, a match is 6.0 rounds instead of 6.1 (`exps=size draws=2`) and the preset spread barely moves (46.7–58.0 vs 47.0–52.8), but hand size doubles the time per Deploy. One rule set for both modes wins.

### 2.3 Same economy as the campaign
| | Duel | Campaign (kc-econ) |
|---|---|---|
| Supply | round N gives N, cap 7 | same |
| Draw | 4 + 1 in round 1, a free mulligan, then 1 per round, hand cap 7, reshuffle the discard | same |
| Mode | **Zone Control, target 6, round cap 8, overtime to 10** | Zone Control or Firefight by fight |
| Terrain | none (an option in a later "Battlefield" variant, §4.5) | 1–2 per fight |
| Operator | free in round 1, 1 Supply per respawn | same |
| Doctrine | **none** | from the first calling card |
| Enemy scaling | none (both sides equal). Recruit AI −1 Armor (§4.1) | Armor by fight |

- **Zone Control only.** Firefight duels are longer (7.0 rounds) and swing much wider (presets 22.7–77.0%; Iron Wall's Pierce farms eliminations). Firefight can return as a variant later.
- **Target 6, not 7 or 8.** A higher target adds rounds (6.2 → 6.8 → 7.3) but widens the preset spread (44–57 → 42–64 → 40–67): longer matches let the late-game decks pull away. The length goal is met by the time per round (§4.4).

### 2.4 Doctrine and traits in a 2-copy deck
In the campaign, Doctrine (+1 to one trait's count) comes from your first calling card, and a run deck has 6–12 calling cards of mixed traits. A Duel deck can carry 16 cards of one trait from the first draw, so Doctrine plus a mono-trait deck completes the 3-set almost every game.

| Hollow Ranks (mono-Undead) in the preset round robin | Win |
|---|---|
| Doctrine = the deck's main trait, Kestrel (first pass) | 71.3–73.9% |
| The same deck with its traits spread over Undead and Spec Ops (art choice) | 53.0% |
| **No Doctrine** (shipped proposal) | 59.3% |
| No Doctrine, final list without Aid Station and Combat Medic, Wasp-9 as the hero | **51.2%** |
| What-if: Undead 3-set loses Cover (+1 FP only), Doctrine on | 54.7% in Duel, but **Undead 40.6% in the campaign** (`run_v2_check exps=late tune=undead.1.cover=none`, shipped 50.4%): rejected |

- **Decision: Duel has no Doctrine.** It is a campaign reward (the first calling card of a run), and Duel has no run. It needs no rule change, only the setup leaves `SideSetup.doctrine` empty. The trait rail in a Duel shows no Doctrine star.
- **No trait limit.** A cap such as "at most 6 picks of one trait" was tried (Hollow Ranks 60.9%, Overwatch 31.3%). It is one more rule to learn, and the trouble was Doctrine plus heal stacking, not the trait count.
- **Watch item: Undead healing stacks.** A custom mono-Undead deck with both Aid Station and Combat Medic plus Kestrel is the strongest deck the sim found (about **59–60%** against the presets with no Doctrine). That is in band for "a strong deck", but it's the first thing to check in a playtest. Levers, in order: (1) Aid Station counts as a heal only for non-Undead units (Duel text), (2) a Duel limit of 1 healing Field, (3) a campaign-wide trait pass. Each needs `run_v2_check exps=late` to stay in band.

## 3. The hero

### 3.1 What the hero is
**The hero is your Operator.** It's a single card with its own slot, outside the deck. It has a body (FP / Armor and weapon keyword), a passive that is always on, and a once-per-match free ability, exactly as in run-v2 §7. Duel adds no new hero rules, and every hero is played and read the same way in both modes.

| Hero | Weapon · Duel FP / Armor | Passive | Ability (once per match, free) | Plays like |
|---|---|---|---|---|
| **Kestrel AR-7** | AR · 3 / **7** | Quartermaster: your opening hand has 1 more card | Dig In: your units in a column have Cover 1 this round | the steady all-rounder |
| **Longreach .338** | Sniper · 3 / **6** · Pick, Pierce | Overpenetration: Pierce | Marked Shot: **2** damage to an enemy unit in its column | picks off the backline |
| **Wasp-9** | SMG · 2 / **8** · First Shot | Run and Gun: 2 Rotations a round | Flashbang: enemies in its column lose First Shot and get −2 FP this round | goes where the fight is |
| **Bastion-60** | LMG · 2 / **7** · Pierce | Sandbagged: Cover 1 | Covering Fire: your units in its column get +1 FP this round | holds one column |

Bold = a Duel number that differs from the campaign (§3.3).

### 3.2 Start with it, have it in hand, or draw it? (sim evidence)
`duel_sim exps=hero n=100`: the four presets in a round robin, 600 games per variant.

| Variant | What the player does | Rounds | Seat 0 | Hero placed by round (avg) | Hero never placed | The side whose hero came first wins |
|---|---|---|---|---|---|---|
| **Command slot (today, recommended)** | the hero sits in its own slot, can be placed from round 1 (free) | 6.20 | 51.3% | 1.0 | 0% | – |
| In the opening hand | the hero is a card that is always in the opening hand and takes one of its 5 cards | 6.22 | 51.8% | 1.0 | 0% | – |
| Shuffled in, must be drawn | the hero is a 21st card; when drawn it can be placed (1 Supply after round 1) | 5.21 | 54.4% | 2.3 | **44.0%** | **85.0%** (n = 453) |
| Shuffled in, free when drawn | as above, the first placement is free | 5.17 | 55.0% | 2.2 | 44.3% | 85.0% |

- **Drawing the hero turns a match into a coin flip on the shuffle.** In 44% of side-games the hero never arrived. When one side got its hero earlier, that side won 85% of the time. Matches got a round shorter because the side without a hero folds. It breaks pillar 2 and makes the hero choice a gamble.
- **"In the opening hand" works but costs a card for nothing.** It plays the same as the command slot (6.22 rounds, spread 45.7–57.7 vs 45.0–54.7) and takes a hand slot just to say "you have your hero". The command slot keeps the opening hand for the deck.
- **Decision: the hero starts in the command slot** (the Operator panel as it is today). You can place it from round 1, it's free in round 1, and it respawns for 1 Supply. It's on the board from the first Deploy in 100% of games.

**Respawn cost** (`exps=respawn`): 0 Supply = presets 39.3–60.2% · **1 Supply = 42.8–55.2%** · 2 Supply = 41.0–61.0%. At 0 the heroes with the best bodies keep coming back for free (Wasp-9 at 8 Armor). At 2 a down costs a whole round 2 turn. **Keep 1** (the campaign's rule).

### 3.3 Duel hero numbers
The campaign tuned the Operators against AI crews: each one's run win sits in 45–55% "vs the others" (run-v2 §15.2). Duel is hero against hero on equal decks, and there the campaign numbers are far apart:

| `duel_sim exps=heroes` (each preset deck mirrored, only the heroes differ; n ≈ 720 per hero) | Kestrel | Longreach | Wasp-9 | Bastion-60 |
|---|---|---|---|---|
| Campaign numbers (3/8 · 3/7, Marked Shot 3 · 2/7 · 2/6), first pass with Doctrine | 57.0% | **71.9%** | 40.3% | **30.9%** |
| Longreach 3/6, Bastion 2/8 | 52.2 | 58.6 | 37.7 | 51.5 |
| + Marked Shot 2, Wasp 2/8 | 55.4 | 43.2 | 46.9 | 54.5 |
| + Kestrel 3/7 | 51.2 | 44.5 | 47.7 | 56.6 |
| **Duel numbers: Kestrel 3/7, Longreach 3/6 + Marked Shot 2, Wasp-9 2/8, Bastion-60 2/7, no Doctrine (final presets)** | **55.2%** | **49.2%** | **47.6%** | **48.1%** |

- **Why these levers:** in a mirror, Longreach's 3-damage Marked Shot removes a 2-drop for free, and its Pierce on 3 FP adds more. Bastion-60's 2/6 body (the kc-econ nerf, made against Shamblers) dies to one column's fire. Armor and the ability's damage are the hero's two plain numbers, and each one reads on the card.
- **Kestrel sits at the top of the band** (55.2%, ±1.9 SE). Its Quartermaster card is worth more in a 20-card deck with good cards than in a 10-card Standard Issue deck. The next lever is Kestrel 3/6, untested; 3/7 was the smallest step.
- **Where they live:** separate Duel resources, `data/duel/heroes/kestrel_ar7_duel.tres` and the others, plus `ab_marked_shot_duel.tres`. They follow the `kestrel_ar7_crew` / `wasp_9_crew` pattern, so no campaign file changes. The hero card in the Duel builder and on the Duel board shows the Duel numbers, and its inspector says "Duel stats: Armor 7 (campaign 8)". The head decides whether one set of numbers should serve both modes (Q4).
- **Heroes pair with decks.** On the same deck the best hero changes (Iron Wall: Longreach beats Kestrel 72–28; Overwatch: Wasp beats Longreach 70–30). That's what makes hero choice a deckbuilding decision. The presets' heroes were chosen with this in mind (§5).
- **Unlocks:** the campaign's (run-v2 §7): Kestrel from the start, Longreach after a finished run, Wasp-9 after reaching a boss, Bastion-60 after a run win. Duel vs AI and the presets can always use all four ("loaner" heroes, §7), so a new player can play every preset.
- **Extending the hero later (not now):** a fifth hero per trait, or a hero "signature" card that is always pick 11. Both raise the rule count and need their own sim. The Operator data already holds everything a hero needs (passive, ability, unlock), so a new hero is data, not code.

## 4. Modes

### 4.1 Duel vs AI
- **Flow:** DUEL → **VS AI** → pick your deck (one of yours or a preset) → pick the opponent (a preset, or "Random") and the difficulty → a match intro with both heroes and both deck names. Every card in the opponent's list is inspectable: the list is public, because a duel against a known deck is a fair duel.
- **The AI plays the presets** (one per trait and hero, §5). It never plays a player's custom decks; that is a later "Gauntlet" idea (§4.5).
- **Difficulty tiers** (all use the real AiPlanner; `duel_sim exps=ai n=60`, 240 games per cell, the player proxy's seat alternates, every preset against every preset):

| Tier | What it is | New-player proxy (casual) | Competent proxy | Target |
|---|---|---|---|---|
| **Recruit** | the casual personality (picks its 2nd-best play 60% of the time, ignores sets), and its cards get **−1 Armor**, shown on its cards as a green "−1" (the campaign's green-squad lever) | **69.5%** | 86.2% | a new player wins 65–75% |
| **Regular** | the competent planner, ignores sets, picks its 2nd-best play 60% of the time | 52.9% | **58.3%** | a competent player wins 55–65% |
| **Veteran** | the competent planner, set-aware, always its best play; no handicap either way | 33.3% | **48.1%** | a competent player wins 45–55% |

- **Regular's lever is its second-best chance:** at 20% it read 49.8% for the competent proxy (as hard as the Veteran), at 40% 54.2%, and **at 60% 58.3%** (the proposed value). A new player wins about half of their games against it: the step after Recruit.
- The Veteran never cheats: no hidden Armor, no extra cards. If a "harder than Veteran" tier is wanted later, it can be an open +1 Armor ("Elite crew") like the campaign's elites.
- Shown before the match: "Recruit: its cards have −1 Armor and it makes mistakes" · "Regular: plays well, ignores sets" · "Veteran: plays its best, no handicap."

### 4.2 Pass & Play (hot seat on one device)
- **Flow:** DUEL → **PASS & PLAY** → Player 1 picks a deck, then Player 2 (each from the same profile's decks or the presets; names editable, default "Player 1 / Player 2") → coin flip for seat 0.
- **Simultaneous Deploy stays simultaneous** by hiding hands. Each Deploy is played in turn behind a cover screen:
  1. **Cover:** "PLAYER 2 — take the device. Tap when only you can see the screen." The board shows public information only.
  2. Player 2 sees their hand, deploys and taps READY. Their face-down plays show on the board as "3 orders placed", never which.
  3. **Cover:** "PLAYER 1 — take the device." Player 1 deploys and taps READY.
  4. **Reveal and Firefight** play for both (the device can sit between them). Score, then the next round's cover. The side that deploys first alternates every round, so neither player always plays blind.
  - Mulligans happen privately in each player's first Deploy, behind the same cover.
- **Privacy rules:** the hand, the deck order and the face-down plays are never on screen while the cover is up. The inspector (long press / right click) works on public cards at any time and on your own hand only after you tapped through your cover. Red dots and intel (Recon Drone, Listening Post) are shown only to their owner, on that owner's turn.
- **Engine:** MatchState already resolves two submitted sides; today's MatchController assumes side 1 is the AI. Hot seat needs a second human input path and the cover screen (§9). The rules need no change.

### 4.3 Online PvP (later, not in this scope; what it would need)
- **A server that owns the match:** run MatchState on the server (the engine is deterministic from a seed, which helps replays and audits). Clients send intents and get events filtered by `private_to`. Hands, deck order and face-down plays never reach the other client.
- **Simultaneous Deploy with a timer:** about 45 s per Deploy plus a 30 s time bank. On timeout the side readies with what it has queued.
- **Matchmaking and rating** (casual queue first), reconnect and resume (a match is about 6 rounds of small state), concede, and a "friend code" private match.
- **Deck legality on the server** (the same `DuelRules.validate`). A rule on the collection: either only owned cards, or a "full pool" queue for fairness (decided with Q3).
- **Anti-abuse:** a rate limit on intents, a timer on the server, no client-side RNG.
- **Trust and safety:** no free text in the first version (emotes only), and block / report.
- The hot-seat cover flow (§4.2) is the same split between public and private views that online needs, so building it first de-risks online.

### 4.4 Match length (target 6–10 minutes)
The sim gives **6.2 rounds** a match (presets round robin; 6.0–6.3 in every Duel configuration). Time per round, from the firefight-order measurements (3.7 s of playback per round at ×1, 1.9 s at ×2) plus our Deploy assumption (30–45 s for a 20-card deck; playtest it):

| | Per round | Match (6.2 rounds + about 40 s intro, mulligan and result) |
|---|---|---|
| vs AI (the AI deploys at once) | Deploy 30–45 s + Reveal / Firefight 4–8 s + score 3 s ≈ 40–55 s | **about 5–6.5 min** |
| Pass & Play | two private Deploys (2 × 30–45 s) + two covers (2 × 4 s) + 4–8 s + 3 s ≈ 75–110 s | **about 8.5–12 min** |

- Against the AI a match sits at the bottom of the band. Hot seat sits at the top, and over it for slow players. **No rule change for length:** a higher target widens the preset spread (§2.3).
- **Levers if playtests run long or short:** a Deploy timer in hot seat (60 s, shown, off by default); playback ×2 in Duel by default (the head's O4: ×2 after the tutorial); for longer AI matches, a "Long match" toggle (target 8, about 7.3 rounds). That toggle widens the spread to 40–67%, so it's a casual option, not the default.

### 4.5 Later variants (backlog, not designed here)
Battlefield (1 random Terrain, the campaign's 10, shown before the mulligan) · Firefight duels · Gauntlet (3 AI duels in a row with your deck) · Best of 3 with a deck swap · Draft (pick 10 from 3-card packs).

## 5. Preset decks (4, one per trait and hero)
Each preset is a real 10-pick deck, legal under §2.1. You can play it at once or copy it as the start of your own. The AI plays these decks. Picks are listed by role; "(T)" = the art's trait both copies wear.

| Preset | Hero | Plan (one line on the deck tile) | The 10 picks (×2 each) | Curve (copies at 1 / 2 / 3 / 4 / 5) | Units / Tactics / Fields |
|---|---|---|---|---|---|
| **Spearhead** (Vanguard) | Kestrel AR-7 | "First Shot up front, Cover behind it, take the column early." | Point Man (V), Rifleman, Breacher (V), Shieldman (V), Brawler (Undead), Bulwark (V Field), Flank Route, Hold the Line, Blackout, Ammo Resupply | 8 / 6 / 4 / 2 / 0 | 10 / 8 / 2 |
| **Overwatch** (Spec Ops) | Longreach .338 | "Pick off the backline, hide your own, finish with Wren." | Rifleman (SO), Recon Specialist (SO), Marksman (SO), Brawler (SO), Flanker (SO), Combat Medic (SO), Halek Wren ★ (SO), Sniper Perch (SO Field), Smoke Screen, Breach and Clear | 4 / 8 / 6 / 0 / 2 | 14 / 4 / 2 |
| **Iron Wall** (Heavy) | Bastion-60 | "Hold one column with Gunners and Anvil; the Mortar does the rest." | Rifleman, Breacher (H), Marksman (H), Gunner (H), Demolitions Expert (H), Okafor Anvil ★ (H), Mortar Pit (H Field), Ammo Resupply, Suppressing Fire, Hold the Line | 4 / 4 / 6 / 4 / 2 | 12 / 6 / 2 |
| **Hollow Ranks** (Undead) | Wasp-9 | "Cheap bodies that come back stronger; trap the lane, then clear it." | Rifleman (U), Brawler (U), Point Man (U), Recon Specialist (U), Flanker (U), Shieldman (U), War Standard (U Field), Tripwire Charge (Field), Breach and Clear, Sabotage | 2 / 10 / 8 / 2 / 0 | 12 / 4 / 4 |

Curve note: Fields and tactics count at their cost (Bulwark 3, Mortar Pit 3, War Standard 3, Tripwire 2, Sniper Perch 2, Smoke Screen 1, Breach and Clear 3, Sabotage 2, Flank Route 1, Blackout 1, Ammo Resupply 1, Hold the Line 2, Suppressing Fire 2). Every card counts at its cost. Hollow Ranks has only one pick that costs 1, so the builder shows it the amber round-1 line. It's kept on purpose, because its 2-drops are the plan, and the line is advice, not a rule.

**Round robin, the final lists, n = 200 per pair (`duel_sim exps=presets n=200`):**

| | Spearhead | Overwatch | Iron Wall | Hollow Ranks | **Overall** |
|---|---|---|---|---|---|
| Spearhead | – | 60.3 | 55.5 | 36.2 | **50.7%** |
| Overwatch | 39.7 | – | 55.8 | 40.7 | **45.4%** |
| Iron Wall | 44.5 | 44.2 | – | 69.5 | **52.8%** |
| Hollow Ranks | 63.8 | 59.3 | 30.5 | – | **51.2%** |

Seat 0 50.3% · 6.17 rounds · 0.3% draws (1,200 games).
- **Every preset has at least one match-up under 45% and one over 55%. It's a loop, not a ladder:** Hollow Ranks beats the First Shot and Pick decks (cheap bodies, heals and traps soak the alpha strike), Iron Wall beats Hollow Ranks (Pierce through the wide lines, the Mortar through the heals), and Spearhead and Overwatch beat Iron Wall's slow start. That suits a "pick your opponent" screen, and a custom deck can aim at a preset's weak spot.
- **How the lists were tuned** (n = 100 per pair per step, all in §8.3): heroes were swapped so each deck found a fitting one (Spearhead with Wasp-9 read 36–39%, with Kestrel 51–53%; Hollow Ranks with Kestrel read 59–74%, with Wasp-9 51–52%). Overwatch's Callout and Listening Post became Breach and Clear and Combat Medic (41.7 → 42.1% on their own, 46% once the other decks moved). Hollow Ranks lost Aid Station and Combat Medic for Flanker and Sabotage (59.7 → 51.8%).
- **Spare picks for the size tests** (picks 11–12): Spearhead Gunner (H), Suppressing Fire · Overwatch Callout, Listening Post · Iron Wall Point Man (V), Comms Relay · Hollow Ranks Combat Medic (U), Aid Station.
- **Cards the presets use:** 26 of the 30 collectible chassis. Aid Station, Callout, Comms Relay and Listening Post are left for custom decks.

## 6. Deck builder UX (phone portrait, phone landscape, desktop)
The studio rule applies everywhere: **every card, hero, curve bar and preset tile opens a full view on long press (touch) or right click (desktop)**. The builder shows what the decision needs, which is cost, name, trait, the ×2 and whether the deck is legal, and puts everything else in the inspector.

### 6.1 Screens
1. **DUEL hub** (from the Title, next to CAMPAIGN): VS AI · PASS & PLAY · MY DECKS. A first-time line: "Build a 10-pick deck, pick a hero, play one battle."
2. **My Decks:** the 4 presets (a lock badge: "Preset: copy to edit") and up to **8 saved decks**. Each tile shows the hero portrait, the deck name, its trait icons, a mini curve and a status chip: **READY** (green with a tick) or **"2 PICKS TO GO"** (amber, with a dash). The status is shape plus word, never colour alone. Tile actions: PLAY · EDIT · COPY · DELETE (confirm: "Delete Iron Wall copy? This can't be undone."). An empty slot reads "+ NEW DECK" and offers "start empty / start from a preset".
3. **Deck builder** (§6.2).
4. **Hero picker:** a sheet with the 4 heroes as large cards (body, passive, ability), each with "Plays like" (one line) and its unlock line if locked ("Win a campaign run"). Long press / right click opens the full kit with an example.
5. **Opponent picker** (vs AI): the 4 presets and "Random", plus the tier toggle (§4.1). The chosen opponent's list is inspectable.

### 6.2 The builder layout
**Phone portrait (390 × 844 pt):**
```
┌──────────────────────────────────────────┐
│ ‹ BACK   Iron Wall copy ✎      8/10 PICKS│  top bar: deck name (tap to rename), pick counter
│ [Bastion-60 · LMG 2/7 · Sandbagged  ▸]   │  hero strip: tap = hero picker, hold = inspect
│ (All)(Units)(Tactics)(Fields) (Cost ▾)   │  filter chips (one row, scrolls sideways)
│ (Trait ▾) (Keyword ▾)  🔍                 │
├──────────────────────────────────────────┤
│ ┌──────┐ ┌──────┐ ┌──────┐               │  card grid, 3 per row, sorted by cost then name
│ │1 Rif.│ │2 Brwl│ │2 Medc│               │  each tile: cost hex, name, trait chip, FP/Armor
│ │  ×2 ✓│ │ +×2  │ │ +×2  │               │  picked: "×2 ✓ IN DECK" band + frame (shape + word)
│ └──────┘ └──────┘ └──────┘               │  locked: dimmed + lock, "Find it in the campaign"
│   ...                                    │
├──────────────────────────────────────────┤
│ ▁▃▅▂▁  1:4  2:4  3:6  4:4  5+:2         ▴│  deck tray (collapsed): curve + counts
│ Units 6/5 ✓ · Elite 1/1 · Fields 1/3     │  rule lines (§6.4)
│ [ SAVE ]                    [ PLAY ▸ ]   │
└──────────────────────────────────────────┘
```
- Swipe the tray up (or tap ▴) and it opens as a sheet with **the deck list**: 10 rows, each "cost · name · trait chip (tap: choose the art) · ×2 · ✕". Empty rows read "— pick a card —".

**Phone landscape (844 × 390 pt) and desktop:** the grid on the left two-thirds (4–6 tiles per row, filters on top), and a fixed **deck panel** on the right: the hero card at the top, the 10-row deck list, the curve chart, the rule lines, then SAVE and PLAY. No sheet is needed.

### 6.3 Interactions
| Action | Touch | Desktop | Feedback |
|---|---|---|---|
| Add a pick | tap a tile | click | the tile flips to "×2 ✓ IN DECK", a "+2" chip flies to the counter, "8/10 → 9/10", the curve bar grows by 2 |
| Remove a pick | tap a picked tile, or ✕ on its deck row | click / ✕ / Delete key | "−2", the row empties, an **UNDO** snackbar for 5 s |
| Inspect | **long press** any tile, row, hero, curve bar or preset | **right click** | the full card: art, cost, FP / Armor, keywords spelled out, trait and its set bonus at 2 and 3, the art choices, "Adds 2 copies" |
| Choose a pick's art (and so its trait) | tap the trait chip on a deck row | click | the art picker: the arts you own for that chassis, grouped by trait; both copies take it |
| Full deck | an 11th tap | – | a gentle shake, "10/10: remove a pick first", nothing added |
| Pick a hero | tap the hero strip | click | the hero picker (§6.1) |
| Filters | chips; Cost has 1 / 2 / 3 / 4 / 5+; Trait has Vanguard / Spec Ops / Heavy / Undead / None; Keyword has First Shot, Pick, Flank, Cover, Pierce, Patch, Suppress; search by name | same plus type-to-search | the count shows on the chip ("Units · 13") |
| Show locked cards | a toggle in the filter row (on by default) | same | locked tiles are inspectable too, with the unlock line |
| Leave with changes | BACK | Esc | "Save changes to Iron Wall copy?" SAVE / DISCARD / CANCEL |

- **The curve chart** shows copies per cost (1, 2, 3, 4, 5+) as bars, with a marker over "1" that says "Round 1: 1 Supply". Tapping a bar filters the grid to that cost. Long press / right click explains: "Round N gives N Supply (max 7). Cards that cost more than the round can't be played yet."
- **Composition line:** "Units 12 · Tactics 6 · Fields 2", plus the traits as icons with their copy counts ("Heavy 10 · Vanguard 2").
- **Save** works at any time, also for an incomplete deck (the tile says "2 PICKS TO GO"). **PLAY needs a legal deck.** The button shows the first red rule when it's disabled ("Pick 2 more cards").
- **Names:** a new deck is named "<main trait> · <hero>" ("Heavy · Bastion-60"), at most 20 characters, renamable.

### 6.4 Validity messages (rule lines under the curve)
Red (blocks PLAY, shown with a ✕ and words):
- "Pick 2 more cards (8/10)"
- "At least 5 unit picks (4/5)"
- "Only 1 Elite ★ pick (2/1): remove Okafor Anvil or Halek Wren"
- "At most 3 Field picks (4/3)"
- "Pick a hero"
- "Mortar Pit isn't in your collection" (a copied preset with a locked card; §7)

Amber (advice, never blocks, shown with a ! and words): the four lines of §2.1. Green (all good): "READY: 20 cards, hero Bastion-60". Each line is tappable. A red or amber line filters the grid to the cards that fix it (for example "Units" or "Cost 0–1").

### 6.5 Saving
Up to **8 custom decks** per profile, plus the 4 presets that can't be edited. They're saved in Settings with the profile as `{name, hero_id, picks: [{card_id, art_id}], created, edited}`, at a few hundred bytes a deck. A pick stores its art, and the art gives the trait. The format checks its own legality on load. A deck that turns illegal (for example after a future data change) loads as "needs attention" with the red line.

## 7. How Duel and the campaign share content and progression
| Thing | Campaign | Duel |
|---|---|---|
| Starting deck | 10 Standard Issue (unchanged) | none: you build one or play a preset |
| Card pool | the reward rungs: units → tactics → Fields → full pool with Elites | **Basic pool from the start: all 11 non-Elite units and all 9 tactics.** **Fields (8) and Elites ★ (2)** join when you first take or are offered one in a campaign run (the Codex "found" flag). The 4 presets are always playable with all their cards (loaners) |
| Arts (and so traits) | per copy, from the art (art-traits.md) | each chassis has a default art for each of its trait options, so every trait is always available. Other arts you've found in the campaign are cosmetic choices |
| Heroes | unlock through the run profile (run-v2 §7) | the same unlocks for your own decks. **All four are loaners in the presets and against the AI** |
| Killstreaks, perks, weapon levels | earned in the run | the fixed 3 killstreaks, nothing else |
| What Duel gives back | – | **records and cosmetics only**: a win / loss record per hero and per preset (Codex "Duel" tab), a "Duelist" banner frame for winning with each hero, and "beat every preset on Veteran" map stamps. **Never a card, a ticket, REQ or a campaign unlock.** |

- **Why units and tactics are open from the start:** a new player can build a real deck at once (20 chassis, more than enough for 10 picks), and the campaign ladder teaches those cards first anyway. Fields and Elites are the campaign's later discoveries (rungs 3–4), so finding them makes a run feel like progress for Duel too. One finished run usually finds most of them.
- **A copied preset with a locked card** keeps the pick, marked with a lock and the red line "Find it in the campaign". The preset itself stays playable. This shows where the card comes from instead of hiding it.
- **Pass & Play** uses the device profile's collection for both players, and either player can take any preset. An "Open pool for this match" toggle (both players get every card) is offered in hot seat only, so a friend on someone else's phone isn't stuck with a small pool.
- **The campaign stays starter-deck based:** no Duel deck, card or hero number goes into a run. The Duel hero numbers are separate resources, and the campaign keeps its own (§3.3).
- **Onboarding:** DUEL unlocks after the tutorial (the tutorial teaches the board). The first DUEL visit shows one "New: Duel" card ("10 picks, 2 copies each, one hero") and suggests "Play Spearhead vs Recruit".
- **Today's Quick Match** (the starter deck vs a squad) becomes **Duel vs AI** with a preset. The pitch build's PitchDecks swaps no longer apply to Duel, because the presets already show units, tactics and Fields.

## 8. Balance with the sims

### 8.1 The tool
`source/project-killingcard/tests/tools/duel_sim.gd` (new; GDScript; headless):
```
godot --headless --path . -s res://tests/tools/duel_sim.gd -- exps=presets n=200
  exps=size,hero,respawn,heroes,presets,ai,mode,build,length
  options: picks= draws= mode=zc|ff hero=cmd|top|draw|drawfree respawn= terrain=0|1 doctrine=0|1
           heroline=duel|campaign lset= eset= tune= cfg= pdeck= phero= only= rsb= rarmor= gsb=
```
It plays the shipped MatchState with `ModeRules` Zone Control, both sides on the run_v2_check competent proxy (synergy-aware AiPlanner). Each "pair" alternates seats, and the seeds are fixed, so every row can be reproduced. The defaults are this spec's Duel rules. It runs at about 0.09 s per game.

### 8.2 Final numbers (Duel rules as specified)
| Check | Target | Result | Command |
|---|---|---|---|
| Presets, round robin, each | 45–55% | **45.4 / 50.7 / 52.8 / 51.2** (Overwatch / Spearhead / Iron Wall / Hollow Ranks), n ≈ 600 each | `exps=presets n=200` |
| Heroes, each on all 4 decks mirrored | 45–55% | **Kestrel 55.2 · Longreach 49.2 · Wasp-9 47.6 · Bastion-60 48.1**, n ≈ 720 each | `exps=heroes n=60` |
| Seat 0 | 45–55% | **50.3%** (presets, n = 1200) · 47.8% (heroes, n = 1440) | – |
| Rounds per match | ~6–8 (6–10 min) | **6.17** (5.8–6.4 in every variant) | – |
| Draws | low | 0.3% | – |
| Hero in the command slot vs drawn | no luck swing | command: 0% missing; drawn: 44% never placed, earlier hero wins 85% | `exps=hero` |
| Respawn cost | the narrowest spread | 1 Supply: 42.8–55.2 (0: 39.3–60.2, 2: 41.0–61.0) | `exps=respawn` |
| Deckbuilding matters | a good deck beats a random legal one ≥ 65% | **70.4%** at 10 picks | `exps=build` |
| New-player proxy vs Recruit | 65–75% | **69.5%** | `exps=ai` |
| Competent proxy vs Veteran | 45–55% | **48.1%** | `exps=ai` |
| Competent proxy vs Regular | 55–65% | **58.3%** (second-best 0.6; 0.4 = 54.2%, 0.2 = 49.8%) | `exps=ai` |
| Mode | the narrowest spread | Zone Control 45.0–56.0 · Firefight 22.7–77.0 (7.0 rounds) | `exps=mode` |
| ZC target 6 / 7 / 8 | – | 6.17 / 6.80 / 7.25 rounds; spread 44.0–57.3 / 42.1–64.3 / 39.9–67.3 | `exps=length` |

### 8.3 The tuning path (each step 600 games, n = 100 per pair)
| Step | Change | Preset spread | Hero spread |
|---|---|---|---|
| 0 | first lists, campaign heroes, Doctrine = main trait | 38.3–71.3 (n = 200) | 30.9–71.9 |
| 1 | Duel hero numbers (Kestrel 3/7, Longreach 3/6, Marked Shot 2, Wasp 2/8, Bastion 2/7) | 39.1–73.9 | 44.3–55.9 |
| 2 | + no Doctrine | 41.7–59.3 | 46.6–55.5 |
| 3 | + Overwatch: Callout and Listening Post become Breach and Clear and Combat Medic | 42.1–59.0 | – |
| 4 | + heroes: Spearhead Kestrel (was Wasp-9), Hollow Ranks Wasp-9 (was Kestrel) | – | – |
| 5 | + Hollow Ranks: Aid Station and Combat Medic become Flanker and Sabotage | **46.0–52.7**; at n = 200: **45.4–52.8** | **47.6–55.2** |

Tried and rejected: an Undead 3-set without Cover (Duel 42.3–56.0, but campaign Undead 40.6%); a trait cap of 6 picks (Overwatch 31%); the Hollow Ranks trait spread over two traits (works, but it's a preset choice, not a rule); Spearhead with Breach and Clear and Suppressing Fire (37.8%).

### 8.4 Pending and what the sim doesn't cover
- **Controls:** the final presets on the campaign hero numbers with Doctrine read **28.0–74.0%** (`heroline=campaign doctrine=1`), and the campaign heroes on the final decks without Doctrine read **36.1–68.2%** (Longreach 68.2, Bastion 36.1). Both Duel changes are needed.
- **Human Deploy time** is assumed (30–45 s). The first hot-seat playtest should time it.
- **The AI uses heroes well but plainly:** it uses abilities when they pay off, and it never "baits" a Flashbang. Expect hero spreads to shift a few points with human players.
- **Custom-deck meta:** the sim measures presets and random legal decks, not players hunting the best 10. The watch item is mono-Undead with both heals (§2.4); the second is Kestrel at the top of its band (§3.3).
- **Hot-seat information:** the sim's AIs see only what `AiView` gives them, the same split the cover screen enforces. It doesn't model players peeking.

## 9. Implementation split (after approval)
### 9.1 Mechanics Developer (kc-duel-impl)
| Work | Files |
|---|---|
| `DuelConfig` resource: picks 10, min units 5, max Elite 1, max Fields 3, killstreaks, ZC target, no Doctrine, the hero override table, AI tier personalities | `scripts/data/duel_config.gd`, `data/duel/duel_config.tres` |
| Duel heroes as separate resources (the `_crew` pattern) | `data/duel/heroes/*_duel.tres`, `data/duel/heroes/ab_marked_shot_duel.tres` |
| Deck list and validation: `DuelDeck {name, hero_id, picks[{card_id, art_id}]}`, `DuelRules.validate(deck, collection) -> {ok, errors[{code, text, fix_filter}], warnings[...]}`, `DuelRules.side_setup(deck) -> SideSetup` (2 copies per pick, art → trait, doctrine empty, killstreaks) | `scripts/duel/duel_deck.gd`, `scripts/duel/duel_rules.gd` |
| The 4 presets as data | `data/duel/presets/{spearhead,overwatch,iron_wall,hollow_ranks}.tres` |
| The collection: found chassis from the Codex / RunProfile; the basic pool; loaners | `scripts/run/run_profile.gd` (+ `found_cards`), `scripts/duel/duel_collection.gd` |
| Save slots (8) in Settings | `autoload/settings.gd` |
| AI tiers (Recruit −1 Armor + casual personality, Regular, Veteran) | `scripts/ai/ai_personality.gd` (+ `for_duel_tier`) |
| A two-human match path for hot seat (no AI on side 1, per-side ready) | `scripts/ui/match_controller.gd` |
| Tests: validation codes, 2 copies per pick, the art → trait, no Doctrine, hero overrides only in Duel, preset legality, a 40-game soak of each preset pair | `tests/test_duel_rules.gd`, `tests/test_duel_presets.gd` |
| Re-measure with `duel_sim.gd` after the port (it should read the real `DuelConfig` instead of its in-memory tables) | `tests/tools/duel_sim.gd` |

### 9.2 UI/UX agent (kc-duel-ui)
DUEL hub and Title entry · My Decks · Deck builder (portrait sheet, landscape and desktop panel) · Hero picker · Opponent and tier picker · Pass & Play cover screen and seat flow · Duel result screen (record, "Rematch", "Edit deck") · inspector hooks on every tile, row, hero and curve bar (long press / right click) · screenshots of each at 390 × 844, 844 × 390 and 1280 × 720 (`tests/tools/shot_*.gd` pattern).

### 9.3 QA
Hot-seat privacy (no hand visible under a cover, on every transition), deck save and load and legality after edits, a loaner preset with locked cards, a 20-match soak per tier.

## 10. Risks and levers
| Risk | Sign | Lever |
|---|---|---|
| Mono-Undead with both heals dominates custom play | a deck over 58% in playtests | §2.4 levers, in order |
| Kestrel the default pick | over 55% in human duels | Kestrel 3/6 in Duel; Quartermaster +1 card only if the deck has 4+ picks that cost 3 or more |
| Hot seat too long | over 12 min | 60 s Deploy timer, playback ×2, auto-skip the cover after the first round |
| Duel numbers confuse players across modes | "why is Longreach 6 Armor here?" | the "Duel stats" line in the inspector; or Q4 (b): one set for both modes |
| Small pool feels thin for new players | only presets get played | Q3 (b) open pool |
| Firefight or Terrain requested for Duel | – | §4.5 variants with their own sim pass |

## 11. Questions for the head (recommended option first)
1. **Where is the hero?** (a) **In its own slot, placeable from round 1** (today's Operator; the sim: always on the board, preset spread 45–55). (b) Always in the opening hand as a card (plays the same, costs one of the 5 opening cards). (c) Shuffled in, must be drawn (44% of games the hero never arrives; the side that got its hero first wins 85%).
2. **Deck size?** (a) **10 picks = 20 cards** (you see 76% of your picks, a good deck beats a random one 70%). (b) 8 picks = 16 cards (88%, the best deck wins too easily: 82%). (c) 12 picks = 24 cards (67%, a third of what you build rarely shows).
3. **The Duel card pool?** (a) **All units and tactics from the start; Fields and Elites unlock when found in the campaign; the presets are always playable** (the campaign feeds Duel). (b) Everything open from the start (no link to the campaign). (c) Only cards found in the campaign (new players can only play presets at first).
4. **Hero numbers in Duel?** (a) **Duel-only numbers** (Kestrel 3/7, Longreach 3/6 with Marked Shot 2, Wasp-9 2/8, Bastion-60 2/7: heroes 48–55% in duels; the campaign is unchanged). (b) One set of numbers for both modes: use these in the campaign too, then re-tune the campaign (run_v2_check). (c) The campaign numbers in Duel too (Longreach wins 72% of hero duels, Bastion-60 31%).
5. **Doctrine and sets in Duel?** (a) **No Doctrine in Duel** (a campaign reward; mono-Undead 71% → 51–59%). (b) Doctrine = the deck's main trait, with an Undead 3-set change for both modes (campaign Undead falls to 41%). (c) The player picks a Doctrine trait in the builder (one more choice; mono decks stay over 60%).


## 12. Decisions (kc-duel-tune, 2026-11-10)
*Board task kc-duel-tune. Tools: `tests/tools/duel_sim.gd`, whose defaults are now this section's design, applied in memory; `tests/tools/run_v2_check.gd`, with new options `eset=`, `latt=` and `docrule=` plus a sanity line that prints the Operator numbers in use; and the new `tests/tools/doctrine_match.gd`, a what-if MatchState with alternative Doctrine rules. No rule, data or UI file was changed. More than 60,000 games in all.*

### 12.1 The head's answers
| # | Answer | Effect on this spec |
|---|---|---|
| D1 | (a) the hero has its own slot from round 1 | §3.2 stands |
| D2 | (a) 10 picks | §2 stands |
| D3 | (a) units and tactics open, Fields and Elites unlock in the campaign, presets always playable | §7 stands |
| D4 | **(b) one set of Operator numbers for both modes**, then retune the campaign | §3.3's duel-only lines are **dropped**; see §12.2 |
| D5 | **(c) the player picks a Doctrine trait** | §2.4's "no Doctrine" is **replaced**; see §12.3 |

### 12.2 One set of Operator numbers (both modes)
| Operator | Shipped (kc-econ) | **New, both modes** | Duel, each hero on all 4 presets mirrored (n ≈ 720) | Campaign run win, competent, 600 runs (150 each) | Campaign vs the others |
|---|---|---|---|---|---|
| Kestrel AR-7 | 3/8, Quartermaster +1, Dig In Cover 1 | **unchanged** | 51.7% | 38.0% | 50.0% |
| Longreach .338 | 3/7, Marked Shot **3** | 3/7, **Marked Shot 2** | 54.5% | 36.0% | 47.2% |
| Wasp-9 | 2/**7** | **2/9** | 43.5% | 38.0% | 50.0% |
| Bastion-60 | 2/**6** | **2/8** | 50.3% | 40.0% | 52.8% |

- **How it was found.** The campaign needs Kestrel's 3 FP. At 2 FP its run win falls to 22–28%, and at 3/7 to 27%. In Duel, Kestrel's extra opening card is worth more because the deck is better. So Kestrel keeps its campaign body and the other three were raised to meet it. Wasp-9 and Bastion-60 got +2 Armor each, which helps them in both modes. Longreach's Marked Shot went from 3 to 2 damage: in Duel the shot killed a 2-drop for free, while the campaign barely notices (its run win stays 36–40%). Longreach's Armor stays 7, because at 3/6 its campaign F1 fell to 48%.
- **Rejected along the way** (each row is a measured run): §3.3's duel-only lines tried in the campaign (Kestrel 3/7 run win 27%, Heavy trait 37%). Kestrel 2/8 or 2/9 (Duel 48–56%, but campaign 22–28%). Dig In Cover 2 (Duel Kestrel 69%). Longreach 3/6 (campaign F1 48%). Marked Shot 1 (works, but 1 damage hardly reads as an ability). Wasp-9 2/10 (Duel 44.3%, no better than 2/9; campaign 42.5%). Bastion-60 2/7 with Covering Fire +2 (campaign 52.5%, too strong).
- **Watch items:** Wasp-9 sits at **43.5%** in Duel, 1.5 points under the band (about ±1.9 SE). It's insensitive to Armor, so the next lever is Flashbang's −2 FP → −3 FP (untested). Longreach is at the top in Duel (54.5%). The crews keep their own crew-only `kestrel_ar7_crew` and `wasp_9_crew` resources (unchanged).

### 12.3 Doctrine in Duel (the player picks it) and the mono-Undead fix
**The rule (Duel):** in the builder the player picks one trait as the deck's **Doctrine**, or None. The default is the trait with the most picks. **A Duel Doctrine starts the set but never completes one:** while exactly **one** of your units or Fields of that trait is in play, it counts as two, so its 2-set is on. It never adds to a count of 2 or more, so the 3-set always needs 3 real members. Card text: *"Doctrine: your first Undead in play already turns on the Undead 2-set."*
- **Restriction:** the Doctrine trait needs **at least 4 picks wearing it** (8 cards). Otherwise the red line reads "Doctrine Undead needs 4 Undead picks (3/4)". A Doctrine is a deck's identity, not a bonus for a two-card splash.
- **The campaign's Doctrine is unchanged** (+1 while you have at least one member, chosen by your first calling card). The "starts the set only" rule was tested there too. With the old Undead table it dropped the competent run to 27.7% and Undead to 36–39%, so it is Duel only. The two rules agree whenever you have exactly one member in play, which is when a new player first meets Doctrine.

**Why Doctrine and Undead changed together:**

| Duel presets, n = 100 per pair (rows 1 and 3: §3.3's hero lines; rows 2 and 4: the new set of §12.2) | Spearhead (V) | Overwatch (SO) | Iron Wall (H) | Hollow Ranks (U) |
|---|---|---|---|---|
| Doctrine with the campaign rule, shipped Undead | 37.1 | 54.0 | 46.0 | **62.9** (71–74% with Aid Station, Medic and Kestrel) |
| Duel Doctrine "starts the set", shipped Undead | 54.8 | 51.2 | 55.7 | **38.3** (strongest searched Undead deck 29%; **Vanguard 70%**) |
| Duel Doctrine "completes the set only" | 25.7 | 57.3 | 34.0 | 66.7 |
| **Duel Doctrine "starts the set" + Undead 2-set heal 1 + Cover 1, 3-set +1 FP (final)** | **48.2** | **53.1** | **45.8** | **52.9** (n = 200 per pair) |

- In a 2-copy deck, a Doctrine that adds +1 at any count completes the 3-set with two units. Undead's 3-set (+1 FP and Cover 1) is the strongest in the game, so mono-Undead ran away. A Doctrine that only starts sets turns it around: Vanguard, whose only bonus is its 2-set, wins 70%. Moving Undead's Cover from the 3-set to the 2-set evens out what each trait gets from the 2-set and from the 3-set, and the Duel meta flattens.
- **Undead table (both modes):** 2-set = **heal 1 + Cover 1** (was heal 1). 3-set = **+1 FP** (was +1 FP and Cover 1). With the campaign's own Doctrine the campaign traits stay in band (§12.5): Undead 52.7%, against 50.4% shipped.
- **Strongest custom decks after the change** (`duel_sim exps=search`: 40 steps of hill-climbing from each preset, cards and hero; then 200 fresh games against the 4 presets):

| Trait | Best deck found | Hero | vs the presets |
|---|---|---|---|
| Heavy | Rifleman, Breacher (H), Gunner (H), Demolitions Expert (H), Okafor Anvil ★ (H), Point Man, Tripwire Charge, Ammo Resupply, Blackout, Suppressing Fire | Bastion-60 | **66.0%** |
| Undead | Rifleman (U), Brawler (U), Point Man (U), Shieldman (U), Recon Specialist (U), Flanker (U), Okafor Anvil ★, Breach and Clear, Hold the Line, Flank Route | Wasp-9 | 62.0% |
| Vanguard | Point Man (V), Rifleman, Breacher (V), Gunner, Okafor Anvil ★, Brawler (U), Bulwark (V), Flank Route, Combat Medic, Demolitions Expert | Longreach | 61.8% |
| Spec Ops | Rifleman (SO), Recon (SO), Marksman (SO), Brawler (SO), Flanker (SO), Okafor Anvil ★, Combat Medic (SO), Ammo Resupply, Suppressing Fire, Breach and Clear | Longreach | 59.8% |

A searched deck should beat the presets: it's built against them. What matters is that the four traits' best decks sit within 6 points of each other (59.8–66.0), with no single runaway. Under the campaign Doctrine rule mono-Undead reached 71–74% *in the preset round robin itself*. Watch item: Okafor Anvil ★ shows up in all four best decks. It's the Elite pick of choice, and Elite pricing is the next lever (for example 6 Supply).

### 12.4 Final Duel numbers (`duel_sim`, defaults = this design)
| Check | Target | Result |
|---|---|---|
| Presets, round robin, n = 200 per pair | 45–55% each | Spearhead **48.2** · Overwatch **53.1** · Iron Wall **45.8** · Hollow Ranks **52.9** |
| Pairs | – | Sp–Ow 46.5 · Sp–IW 58.0 · Sp–HR 40.0 · Ow–IW 56.5 · Ow–HR 49.2 · IW–HR 52.0 |
| Seat 0 / rounds / draws | 45–55 / 6–8 | 50.7% / 6.14 / 0.1% |
| Heroes, n ≈ 720 each | 45–55% | 51.7 / 54.5 / **43.5** / 50.3 (Kestrel, Longreach, Wasp-9, Bastion-60) |
| AI: new-player proxy vs Recruit | 65–75% | 73.8% |
| AI: competent proxy vs Regular / Veteran | 55–65 / 45–55% | **66.2%** / 46.7% (Regular at the edge; second-best 0.5 read 66.7%, so the lever is weak; keep 0.6) |

**Preset changes (content):** Overwatch: **Smoke Screen → Ammo Resupply**. Hollow Ranks: **Sabotage → Listening Post**. The heroes are unchanged (Spearhead Kestrel, Overwatch Longreach, Iron Wall Bastion-60, Hollow Ranks Wasp-9). Each preset's Doctrine is its own trait. The spare picks 11–12 become Overwatch: Callout, Smoke Screen; Hollow Ranks: Combat Medic, Aid Station.

### 12.5 Final campaign numbers (`run_v2_check`, 600 runs, competent, Operators and bosses rotating, the new Operator numbers and Undead table, the shipped campaign Doctrine)
| Target | Shipped kc-econ | **After kc-duel-tune** |
|---|---|---|
| New player (casual) F1, first run (65–75%) | 68.8% | **68.8%** (Kestrel and Meridian unchanged; first run 38.5%) |
| Competent run 2+ (38–43%) | 40.5% (39.0% on these 300 seeds) | **38.0%** |
| Ramp F1 / F2 / Elite I / F3 / Elite II / F4 / Boss | 86 / 89 / 79 / 85 / 68 / 67 / 42 | 95 / 90 / 83 / 89 / 77 / 76 / 39 |
| Operators vs the others (45–55%) | 45.9 / 54.7 / 47.3 / 52.0 | **50.0 / 47.2 / 50.0 / 52.8** |
| Boss fights Meridian / Prime / Choir | 45.5 / 39.1 / 40.6 | 44.9 / 33.0 / 37.7 |
| Traits, end-of-run decks (44–56%; n = 300 each) | 50.4 / 50.0 / 51.1 / 48.5 (U / V / H / SO) | **52.7 / 44.7 / 50.0 / 52.7** |
| Seat 0 late / Standard Issue (45–55%) | 51.6 / 48.0 | 48.5 / 48.0 |
| Aware vs blind (≥ 55%) | 59.2% | 63.1% |

- **No crew, boss or map lever had to change.** Raising Wasp-9 and Bastion-60 lifts the mid-run (F4 67 → 76%), and the boss stays the peak (39%). Vanguard (44.7%) and Prime (33%) are the edge values to watch. Their levers are a Vanguard 3-set (the v2.0 Cover +1) and Prime's pits in 2 columns instead of 3. Prime's 2-column variant was tested inside other runs and was not needed here.
- Noise: campaign trait rows swing ±5–8 points between deck samples (seen across this task's 600-run samples), so read the trait row as "in band", not to the decimal.

### 12.6 Exact changes for the mechanics developer (kc-duel-impl)
| # | File | Field | From | To |
|---|---|---|---|---|
| 1 | `data/loadout/wasp_9.tres` | `operator_armor` | 7 | **9** |
| 2 | `data/loadout/bastion_60.tres` | `operator_armor` | 6 | **8** |
| 3 | `data/loadout/ab_marked_shot.tres` | `effects[0].amount` (sub-resource) | 3 | **2** |
| 4 | `data/loadout/ab_marked_shot.tres` | `text` | "…free: 3 damage to an enemy unit…" | "Once per match, free: **2** damage to an enemy unit in your Operator's column." |
| 5 | `scripts/ui/run/run_v2_views.gd` (line ~78) | Marked Shot ability string | "3 damage…" | "2 damage to an enemy unit in the Operator's column." (and any other copy of this text; grep "3 damage to an enemy unit") |
| 6 | `scripts/rules/synergy_rules.gd` | `TRAIT_BONUS[UNDEAD]` | `[{"heal": 1}, {"fp": 1, "cover": 1}]` | **`[{"heal": 1, "cover": 1}, {"fp": 1}]`** |
| 7 | `scripts/rules/synergy_rules.gd` | `TIER_TEXT[UNDEAD]` | ["Undead heal 1 at the end of the round", "Undead get +1 FP and Cover +1"] | **["Undead get Cover +1 and heal 1 at the end of the round", "Undead get +1 FP"]** |
| 8 | `scripts/rules/synergy_rules.gd` | `trait_counts()` (and `compute()`) | Doctrine: +1 while count > 0 | add a parameter `doctrine_starts_only: bool = false`; when true, Doctrine adds +1 **only while the real count == 1** (reference: `tests/tools/doctrine_match.gd`) |
| 9 | `scripts/rules/side_setup.gd` | new `doctrine_starts_only: bool = false` | – | `DuelRules.side_setup` sets it **true**; the campaign leaves it false |
| 10 | `scripts/rules/match_state.gd` | `_syn_refresh`, `preview_synergy` (both `SynergyRules.compute` calls), and `scripts/run/reveal_flags.gd` | – | pass `setup.doctrine_starts_only` |
| 11 | `scripts/ai/ai_view.gd` and `scripts/ai/ai_planner.gd` (`_synergy_of_plan`) | – | – | carry and pass the same flag, so the AI values plans with the Duel rule |
| 12 | `data/duel/duel_config.tres` | `doctrine_enabled` / `doctrine_required` / `doctrine_min_trait_picks` | true / false / 0 | true / **false** (None allowed; the builder pre-selects the most-picked trait) / **4** |
| 13 | `data/duel/presets/overwatch.tres` | picks | … Smoke Screen … | Smoke Screen → **Ammo Resupply** |
| 14 | `data/duel/presets/hollow_ranks.tres` | picks | … Sabotage … | Sabotage → **Listening Post** |
| 15 | `data/duel/presets/*.tres` | `doctrine_trait` | – | Spearhead vanguard · Overwatch specops · Iron Wall heavy · Hollow Ranks undead |
| 16 | (none) | duel-only hero resources (`*_duel.tres`, `ab_marked_shot_duel.tres` from §9.1) | planned | **do not create**: the heroes use the shared Operators |
| 17 | `data/run_config.tres`, crews, bosses, map Armor | – | – | **unchanged** |
| 18 | `data/duel/duel_config.tres` | `recruit_*`, `regular_second_best`, `veteran_second_best` | – | unchanged (−1 / 0.6 / 0.6 / 0.0) |

- **UI copy:** the Doctrine chip in the builder (under the hero strip): "DOCTRINE: Undead ▾", with None and the traits that have 4 or more picks. Its inspector (long press / right click) says: "Doctrine: your first Undead in play already turns on the Undead 2-set. The 3-set still needs 3 Undead." The trait rail shows the Doctrine star as today. The Codex glossary keeps the campaign line and adds "In Duel, Doctrine only starts a set."
- **Tests to update:** synergy tests that assert the Undead set numbers, Marked Shot damage (3 → 2), Operator stats in the data tests (Wasp-9 2/9, Bastion-60 2/8), and new tests for the Doctrine flag (count 1 → 2 on, count 2 stays 2, flag off = the old rule).
- **Re-measure after the port:** `duel_sim exps=presets,heroes,ai n=200` (its in-memory defaults set the same absolute values as the ported data, so the result is the same with or without `heroline=campaign`). Check the Operator and trait lines it prints, and `run_v2_check exps=runs,late runs=600 tn=100` plus `first=1 proxies=casual runs=400`.

### 12.7 Re-measured on the shipped engine (kc-duel-impl, commits 5c04f23 / 9e7ca6c / 312d44e)
`duel_sim` now reads the real data (`data/duel/`, the Operators, `SynergyRules`). The AI values its plans with the Duel Doctrine rule (`SideSetup.doctrine_starts_only`). The tool versions of §12.4 kept the old rule in the planner. Each row is `exps=presets,heroes,ai n=200`.

| Check | Target | Shipped engine |
|---|---|---|
| Presets (n = 200 per pair; 1,200 games) | 45–55% each | Spearhead **46.7** · Overwatch **48.4** · Iron Wall **51.7** · Hollow Ranks **53.2** |
| Pairs | – | Sp–Ow 43.5 · Sp–IW 56.0 · Sp–HR 40.7 · Ow–IW 45.0 · Ow–HR 43.7 · IW–HR 56.0 |
| Seat 0 / rounds / draws | 45–55 / 6–8 | 49.3% / 6.18 / 0.2% |
| Heroes (each preset mirrored, n ≈ 2,400 each) | 45–55% | Kestrel 50.1 · Longreach 54.8 · Wasp-9 **44.4** · Bastion-60 50.7 |
| New-player proxy vs Recruit (n = 800) | 65–75% | **74.6%** (was 75.5% at second-best 0.6) |
| Competent proxy vs Regular (n = 800) | 55–65% | **63.4%** (was 68.2% at second-best 0.6) |
| Competent proxy vs Veteran (n = 800) | 45–55% | 51.1% |

- **The presets need no swap.** The n = 50 read (Overwatch 44.7, Hollow Ranks 55.3, Overwatch vs Hollow Ranks 36%) was sampling noise. At n = 200 every preset is in band, and Overwatch vs Hollow Ranks is 43.7%.
- **AI tier values changed (data only):** `data/duel/duel_config.tres` `recruit_second_best` 0.6 → **0.5** and `regular_second_best` 0.6 → **0.3**. With the AI planning under the Duel Doctrine rule, Regular had become too easy (68.2%) and Recruit sat at the top edge (75.5%). Tried at n = 120: Regular 0.2 / 0.3 / 0.4 read 62.0 / 61.3 / 62.3% for the competent proxy (0.3 shipped). Recruit 0.45 / 0.5 read 72.7 / 73.3% for the new-player proxy. `tests/test_duel_match.gd::test_ai_tiers` now also asserts the data values. 685 tests pass.
- **Still at the edge:** Wasp-9 at 44.4%, with Flashbang −3 FP as the next lever (rules data, untested), and Longreach at 54.8%. The campaign numbers of §12.5 are unaffected: the Duel Doctrine flag is off in the campaign and these AI values are Duel only.

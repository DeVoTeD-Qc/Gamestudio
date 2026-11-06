# KillingCard: Firefight Activation Order (columns left to right, front to back, one shot each)

*Author: Sr Game Designer Agent · 2026-11-06 · Board task kc-fight · Status: **proposal, waiting for the head's answers (§9)** · No rules, UI, scene or data file was changed. The prototype lives in `source/project-killingcard/tests/tools/` (`fight_order.gd`, `fight_state.gd`, `fight_planner.gd`, `fight_sim.gd`), on the real engine and the real AI.*
*Inputs: `scripts/rules/firefight_resolver.gd` (today's resolver), `core-rules` §2.4 and Rulings 5/6/8, `card-system.md`, `field-cards.md`, `synergy-system.md` (incl. §11 implementation and §12 paused tuning), the AI estimator in `scripts/ai/ai_planner.gd`.*
*The head (verbatim): "the resolution of the fight goes too fast. I think we need to have a defined order of activation, and we should probably go with the leftmost zone towards the right, and then have the units on the front line activate first, and then if the damage is beyond, it stops there unless they have a keyword like we need to add a new one for damage to pass through to the second opponent on the line. And then yeah, they should shoot each other, and then if someone dies, they move closer to frontline and then keep activating the card."*

## 0. Summary in six lines
1. **One readable order.** Columns resolve **A, then B, then C**. Inside a column the fight is a list of **beats**. In each beat, the **front-most unit on each side that hasn't fired yet** shoots, and the two shots are simultaneous. Then damage lands, the dead are removed and the line **moves up**. Every unit fires **once per round** (§2).
2. **First Shot wins its exchange.** If one shooter in a beat has First Shot and the other doesn't, the First Shot unit fires first. A partner it kills never fires (§2.3).
3. **Damage stops at the target**: any damage beyond what the target needs is lost. A new keyword, **Pierce**, carries that extra damage on to the next enemy behind it (that enemy's Cover applies). Recommended on the **Marksman** and the **Ace ★** (§3).
4. **Sim (about 30,000 matches, real engine and AI):** the new order keeps the seats fair (**51.6%** seat 0) and lifts synergy-aware play over blind play from 52.0% to **55.4%**, now meeting the ≥55% target (control 48.5%). Rounds per match go from 6.41 to 6.56. With one squad number fixed (slot 3 Armor bonus 1 → 0), the campaign is back at **39.8%** (today 37.5%) and climbs more evenly (§6).
5. **The fight becomes watchable:** about **3.3 beats and 1.7 line advances per round**, so playback takes **3.9 s per round at ×1** (median under 4 s, 90% under 8 s) and about 2 s at ×2 (§5).
6. **Engine work is contained:** a new `FirefightResolver` loop (the target rules are reused), one `CardData.pierce` flag, the AI estimator's step 2, and the event stream gets a `BEAT` event that the UI plays back one beat at a time (§7–8).

---

## 1. What changes, and what doesn't
| | Today (shipped) | Proposed |
|---|---|---|
| Column order | A → B → C (already, but invisible: everything inside a column happens at once) | A → B → C, **shown**: a column banner, then its beats |
| Inside a column | 2 steps. **First Shot step**: every First Shot unit of both sides fires at once. **Main step**: everyone else fires at once. Damage lands at the end of each step. | **Beats, front to back.** One shooter per side per beat. Damage lands after every beat, and the line moves up. |
| Who can fire | Every unit, once | Every unit, once (unchanged). A unit that dies **before its beat** never fires. |
| Default target | Enemy front unit; if this step's damage already dooms it, the next one in line | **Enemy front unit at the moment of the shot.** No "already doomed" skip is needed, since damage has already landed. |
| Extra damage | Lost per shot (later shooters re-aim at the next unit) | Lost per shot (unchanged). **Pierce** carries it on. |
| Pick / Flank, Suppress, Patch, Attack Helo, On Down, auras, synergy | §2.4 | Same rules, slotted into the order in §2.5 |

**What the player reads:** "Left column first. In each column the front cards trade shots, then the next cards, and so on. When a card dies, the one behind it steps up." That's the head's sentence, and every rule below is an exact version of it.

## 2. The rules, exactly

### 2.1 Order of the Firefight phase
```
FIREFIGHT
 0. Start of firefight: Attack Helo hits (as today), the dead are removed.
 1. For each column A, B, C that has units on both sides:
      a. Suppress: each Suppress unit gives the enemy front unit -2 FP this round (as today).
      b. Beats until the column is resolved (§2.2).
      c. Patch: each living Medic heals the most damaged other friendly unit in the column (as today).
 2. (Score step, unchanged) Undead heal, END_OF_ROUND effects, control, Overrun, streaks.
```

### 2.2 A beat
1. **Shooters:** on each side, the **front-most living unit in this column that hasn't fired this round**. There is at most one per side.
2. **Both shoot at once.** Each shot picks its target **now**: the enemy front unit (Pick: the enemy with the lowest Armor, ties front-most; Flank: the back-most; untargetable units are skipped by Pick/Flank, as today). Damage = FP − the target's Cover, never below 0. FP and Cover are read now, so auras, links and sets are live (§2.5).
3. **Damage lands, then deaths:** units at 0 Armor are removed, and their On Down effects resolve (Demolitions Expert's 3 damage hits the enemy front unit as it stands now).
4. **Move up:** the lines close up, so the unit behind a dead one is now one row closer. Links and frontline auras follow at once.
5. **Repeat** until neither side has a unit left in the column that can fire, or one side has no units left in the column (a lone survivor has no target, so the column is over).

When only one side still has unfired units, that side keeps firing one unit per beat (the enemy has nobody left to answer).

### 2.3 First Shot: "fires first in its exchange" (recommended)
- In a beat where **one** shooter has First Shot and the other doesn't, the First Shot unit fires first and its damage lands at once. If its partner survives, the partner then fires. If not, the partner never fires.
- If **both or neither** have First Shot, they fire at the same time.
- First Shot from any source counts (printed, Spec Ops tier 3, GRANT_FIRST_SHOT). Blackout / REMOVE_FIRST_SHOT removes it, as today.
- **Alternative (sim "pass"):** before the normal beats, every First Shot unit in the column fires front to back in its own beats, like today's First Shot step made visible. This keeps today's balance almost exactly (§6). The downside: a back-row First Shot unit fires before the front line, which breaks "front first". See question 2.

### 2.4 "Each unit activates once": what that means after units move up
- **The shot belongs to the unit, not to the row.** Each unit carries a `fired` flag for the round. Moving up never resets it, and a unit that already fired from row 2 doesn't fire again when it reaches row 1.
- **A unit that moves up before its beat** fires from its new position, as the front unit (it gets frontline auras, and it's the target of enemy default shots).
- **A unit that arrives mid-firefight** (none today; Flank Route and Protector slides happen at Reveal) would fire if it is still unfired when its beat comes.
- **Rounds stay bounded:** a column has at most 4 units a side, so at most 4 beats (plus up to 4 split First Shot beats) per column.

### 2.5 How every existing rule fits
| Rule | Where it sits now | Note |
|---|---|---|
| **Attack Helo** (start of firefight) | Step 0, before column A | unchanged |
| **Suppress** | Start of each column, on the enemy front unit at that moment | If that unit dies, the unit that moves up is **not** suppressed. Suppress pins a target, not a slot. |
| **First Shot** | §2.3 | |
| **Pick** | The shot's target choice, at its beat | A row-2 Marksman fires in beat 2, at whoever is weakest *then*. |
| **Flank** | Same: the back-most enemy at its beat | |
| **Cover, Guard / Overwatch links, Vanguard tier 3, Heavy tier 2** | Read when the shot lands | A Guard who dies in beat 1 no longer covers the unit behind it in beat 2. |
| **Spotter, Fireteam, Spec Ops / Vanguard / Heavy / Undead FP bonuses** | Read when the shot is fired | Side links cross columns: a death in column A can switch off a Fireteam link in column B **before** B resolves. This is the main new tactical depth. |
| **Field frontline auras** (Bulwark, War Standard) | Follow the front unit, beat by beat | The front unit at the moment of each shot gets them. |
| **Protector slide, Flank Route move** | Reveal, before the firefight | unchanged |
| **Holder** (control) | Score step | unchanged |
| **On Down** (Demolitions) | Inside the beat, after deaths | Hits the enemy front unit as it stands then. |
| **Patch** (Medic) | End of the column | unchanged |
| **Undead heal, Mortar Pit, Aid Station** | Score step | unchanged |
| **Overrun** | Score step | unchanged |
| **Grit** (survive lethal) | When damage lands | unchanged |

## 3. The new keyword: **Pierce**
**Pierce:** *damage this unit deals beyond what its target needs carries on to the next enemy behind the target (that unit's Cover applies; it keeps going while damage is left).*
- Glyph: an arrow through a chevron, pointing down the enemy column. One line of text, like the other printed keywords.
- It's a **printed** keyword (like First Shot or Pick), so Recruit copies keep it.
- Only overkill passes on, so on cheap 2-FP units it almost never matters. The sim measured overkill per card (seq order, late decks, per round, both sides):

| Card | Overkill per shot | Per round | Comment |
|---|---|---|---|
| Breacher (shotgun, +2 FP at close range) | 1.16 | 0.98 | By far the most. Pierce here would be a big buff to Vanguard, the strongest trait. **No.** |
| Marksman (Pick, sniper +2 at long range) | 0.67 | 0.17 | Thematic (overpenetration). Spec Ops, the weakest trait. **Yes.** |
| Brawler | 0.75 | 0.08 | Rare shooter |
| Point Man | 0.35 | 0.34 | Vanguard again. **No.** |
| Operator (Kestrel AR7) | 0.20 | 0.27 | Not a card |
| Gunner (LMG) | 0.18 | 0.05 | Thematic, but almost no effect |
| Ace ★ (4 FP, Pick) | — | rare | Elite sniper. **Yes**, for theme and the moments it shows up |

**Recommendation: Pierce on the Marksman and the Ace ★** (Spec Ops snipers: "the round goes through"). The effect is small: Spec Ops gains about +1 point in the round robin, and pierce damage is ~0.07 per round. It reads clearly and gives later cards a hook. If the head wants Pierce to matter more, the lever is a higher-FP Pierce card (a backlog idea: an anti-materiel sniper, 4 FP, cost 4).

## 4. Worked example (column A, round 3)
```
            ENEMY                       YOU
 row 1   Point Man 2/3 (FS)        Breacher 3/4 (FS, Guard)
 row 2   Marksman 2/2 (Pick)       Rifleman 2/2            <- Cover +1 from Guard
 row 3   —                         Medic 1/3 (Patch 2)
 Beat 1: Point Man vs Breacher, both First Shot -> simultaneous. PM hits Breacher 2 (4 -> 2). Breacher hits PM 3 -> dead.
         Line moves up: the enemy Marksman is now front.
 Beat 2: enemy Marksman (front now, unfired) vs your Rifleman (front-most unfired). Simultaneous.
         Marksman (Pick) shoots the weakest: Breacher at 2 -> dead. Rifleman hits Marksman 2 -> dead.
         Your line moves up: Rifleman is front, and loses the Guard cover (its Guard died).
 Beat 3: the enemy has nobody left -> column over. Your Medic never fired (no target), then Patch heals the Rifleman.
 Playback: column banner 0.4 s + 2 beats × 0.8 s + 2 advances × 0.35 s = 2.7 s at ×1.
```

## 5. Phone pacing
**Measured** (seq order, aware mirror, n = 1000 matches): per round, **1.66 columns fought, 3.34 beats, 4.86 shots, 1.74 line advances, 2.15 eliminations**.

**Timing model at ×1:** column banner 0.4 s, one beat 0.8 s (a highlight on the shooter(s), tracer 0.35 s, damage number and hit flash 0.45 s; the two shots of a beat play together), line advance 0.35 s.
| Order | Rounds per match | Playback per round, ×1 (mean / median / 90th pct) | ×2 | Firefight time per match, ×1 |
|---|---|---|---|---|
| Today (no order shown) | 6.41 | (`RESOLVE_S` = 10 s for Reveal + Firefight in the balance model) | — | — |
| **Front to back, FS exchange (recommended)** | 6.56 | **3.9 s** / < 4 s / < 8 s | **~2 s** | ~26 s |
| Front to back, FS pass | 6.39 | 3.7 s / < 4 s / < 7 s | ~1.9 s | ~24 s |
| Front duel | 7.00 | 3.8 s / < 4 s / < 7 s | ~1.9 s | ~27 s |

- 90% of rounds play back in under 8 s at ×1, and the longest seen was ~11 s (a full 4-v-4 column). That fits inside today's 10 s Reveal + Firefight budget, so the run length stays about 24 minutes.
- At 0.5 s per beat (the fastest readable speed, with no damage-number pause) a round takes ~2.6 s. ×2 halves the model. ×2 is the setting for players who know the order. Skipping (tap to finish the round) stays available.

## 6. Sim results
**Harness:** `tests/tools/fight_sim.gd` (the experiments and decks of `synergy_check.gd`). `FightState` is a sim-only `MatchState` whose `firefight()` runs `fight_order.gd`. `FightPlanner` is a sim-only `AiPlanner` whose firefight estimator plays the same order, so the AI plans for the rules it plays under (players and squads). Seats and modes alternate on Port Vasel, with late decks (synergy-system §7). n per row is given; n = 1000 gives ±1.6 points SE, n = 800 gives ±1.8, n = 400 gives ±2.5.
Run: `godot --headless --path . -s res://tests/tools/fight_sim.gd -- exp=mirror|duel|traits|campaign n=N order=now|seq|front fs=pass|exchange [pierce=marksman,halek_wren] [syn=0]`.

### 6.1 The three orders against today (shipped data)
| Check (target) | **Today** (`now`) | Front to back, **FS pass** | Front to back, **FS exchange** | Front duel (only the front unit fires) |
|---|---|---|---|---|
| Seat 0, aware mirror (45–55%) n=1000 | 51.8% | 51.9% | 53.4% | 53.1% |
| Aware vs blind, late decks (≥ 55%) n=800 | 52.0% | 51.9% | **57.6%** | **58.6%** |
| Control: same, synergy off n=800 | 46.0% | 45.6% | 50.6% | 49.8% |
| Trait round robin V / SO / H / U (40–60%) n=480 each | 67.3 / 42.3 / 47.7 / 42.1 | 66.5 / 43.8 / 47.9 / 41.2 | 70.0 / 41.0 / 51.0 / 37.5 | 66.2 / **37.9** / **59.4** / **34.6** |
| Campaign, starter in every slot (today 37.5%) n=400 | 37.5% (64 / 70 / 18 / 30 / 6) | 36.0% | 31.8% (62 / 60 / 12 / 22 / 1) | **27.5%** (52 / 46 / 18 / 18 / 4) |
| Rounds per match | 6.41 | 6.39 | 6.62 | 7.00 |
| Shots per round (incl. wasted) | 4.83 (0.33 wasted) | 4.50 | 5.06 | 4.32 |

- **FS pass is today's balance in a readable form:** the same numbers within noise. Today's "everyone at once" and the beat order differ only when a unit dies before its beat, which is rare, because the front units fire in beat 1 anyway.
- **FS exchange makes position matter more:** who is in front and who has First Shot decides each trade. Synergy planning gains (aware +5.6 points; +7 over its control), seats stay fair, and the board takes slightly longer (+0.2 rounds). The cost: front First Shot packages get stronger (Vanguard 70%), and the player's Recruit starter suffers against squads that are already well built.
- **The front duel (the literal reading) is a different game:** back rows never fire unless they reach the front, so Spec Ops (snipers in the back) collapses to 38% and Heavy (sturdy fronts) rises to 59%. The campaign falls to 27.5%, and matches get longer (+0.6 rounds). **Not recommended.** It would also make Spotter and every back-row card pointless.

### 6.2 The recommended package (FS exchange + Pierce on Marksman and Ace + two number fixes)
Number fixes (data only, to be finished in the v1.2 tuning after approval): **Protector cost 3 → 4 and no Guard on the Protector** (it keeps Cover 1 and the slide; synergy-system §12 found the Protector + Guard to be the core of Vanguard's lead), and **slot 3 (Rusher+, the first Trained squad) Armor bonus 1 → 0**.
| Check (target) | Today | **Package** | n |
|---|---|---|---|
| Seat 0, aware mirror (45–55%) | 51.8% | **51.6%** | 1000 |
| Aware vs blind, late decks (≥ 55%) | 52.0% | **55.4%** | 800 |
| Control, synergy off | 46.0% | 48.5% | 800 |
| Campaign, all slots (today 37.5%) | 37.5% | **39.8%** | 400 |
| Campaign per slot (Rusher / Anchor / Rusher+ / Anchor+ / Rival) | 64 / 70 / **18** / 30 / 6 | 52 / 74 / **39** / 29 / 5 | 80 each |
| Trait round robin V / SO / H / U (40–60%) | 67.3 / 42.3 / 47.7 / 42.1 | **63.1** / 42.9 / 54.0 / **39.4** | 480 each |
| Rounds per match | 6.41 | 6.56 | 1000 |

- **Met:** seats, the synergy-planning target (55.4%), and campaign difficulty, with the M3 wall softened (18 → 39%). This also partly fixes kc-syn-tune issue 2.
- **Not yet met:** Vanguard is still above 60 (63.1) and Undead slightly below 40 (39.4). Both are the kc-syn-tune work, which is redone on the new order after approval (next levers in synergy-system §12: Bulwark is a weak card, the Breacher's First Shot at the front, Undead's package).
- Slot-3 + slot-4 Armor bonus both at 0 overshoots (M3 45%, M4 55%, all 44.8%). Fix slot 3 only.
- The full-run sim (`balance_sim.gd`, offers taken) can't load the prototype order without an engine change. Re-run it once the resolver ships.

## 7. Engine work (for the mechanics developer, after approval)
| Item | Where | Size |
|---|---|---|
| Beat loop: per column, `_beat()` with one shooter per side (§2.2), First Shot exchange split (§2.3), damage lands per beat, then `process_eliminations()`; target choice reuses `pick_target` (the "doomed" skip disappears) and `_suppress` / `_patch` | `scripts/rules/firefight_resolver.gd` (reference: `tests/tools/fight_order.gd`) | ~80 lines replace `_step` |
| Pierce: `CardData.pierce: bool`, `RulesUnit.pierce`; carry-over loop after the target's Armor; validator; Marksman + Ace data; text "Pierce" | `card_data.gd`, `rules_unit.gd`, `match_state.create_unit`, 2 `.tres`, `gen_content.gd` | ~25 lines |
| Synergy and auras read live per beat: already true (`firepower_of` / `cover_of` use the board-signature cache). Make sure the cache is rebuilt after every removal inside a beat | `match_state.gd` | check + test |
| Events: `FIREFIGHT_BEAT {zone, beat, shooters: [uid], first_shot_split: bool}` before each beat's `SHOT_FIRED`s; `LINE_ADVANCED {side, zone, moves: [{uid, from_row, to_row}]}` after removals; `SHOT_FIRED.step = &"beat"`, plus `pierce_uids` | `rules_event.gd`, resolver | ~20 lines |
| AI estimator: replace step 2 of `_eval_zone` with the beat order (reference: `tests/tools/fight_planner.gd::_fight` / `_beat`); Pierce on records | `ai_planner.gd`, `ai_view.gd` | ~70 lines; AI turn time within ~10% of today (measured 9.4–10.3 vs 9.4 ms aware) |
| Outcome forecast / preview uses the same resolver on a clone: no change beyond the resolver | `outcome_forecast.gd` | — |
| Tests: beat order A → B → C; front-first; once per round after moving up; FS exchange kills the partner before it fires; both-FS simultaneous; extra damage lost without Pierce and carried with it (Cover applies); Suppress doesn't follow the slot; On Down hits the new front; a Spotter / Guard death changes later beats; Fireteam across columns switches off before column B; Patch after the column | `tests/test_rules_firefight.gd`, `test_rules_first_shot.gd`, `test_rules_synergy.gd` | ~20 tests; several existing firefight tests change expected numbers |
| Re-run `balance_sim.gd` and `synergy_check.gd`; redo kc-syn-tune v1.2 on the new order | `tests/tools/` | |

## 8. UI and presentation needs (for the UI/UX agent)
- **Order indicator:** a thin **A → B → C** strip over the board during the Firefight. The current column is lit, finished columns are ticked, and empty or one-sided columns are greyed and skipped instantly.
- **Column banner** (0.4 s): "COLUMN A" in the column's header, the column brightens and the others dim.
- **Now firing:** the shooter's banner lifts slightly with a bright outline in the owner's colour (teal / red). If both sides fire in the beat, both lift. On a First Shot split, the FS unit lifts first with a small "FIRST SHOT" tag, then its partner, if it lives.
- **Tracer + damage number:** a tracer from shooter to target (0.35 s), then a damage number ("-3") on the target and a hit flash. A Cover-absorbed shot shows the shield icon with "-0". Pick and Flank tracers curve to their target and carry a tiny icon, so it's clear why that target.
- **Pierce:** the tracer continues through the target to the unit behind, and the second number is drawn smaller ("-1 PIERCE").
- **Death and line advance** (0.35 s): the banner breaks (existing killfeed toast), then the cards behind slide up one row. Link ticks and aura markers move with them, and links that break flash out (this is where players see synergy react).
- **Fired marker:** a small spent-cartridge pip on each banner that has fired this round, so "everyone fires once" can be seen at a glance. It clears at the Score step.
- **Speed:** ×1 (default for new players), ×2, and tap-to-skip the round. The setting is saved (it already exists as "speed" in settings). The tutorial plays its first firefight at ×1 with a coach line per beat.
- **Log:** the killfeed log gets one line per beat ("A · Breacher ⇄ Point Man: 3 / 2"), useful for disputes.
- **Accessibility:** the order strip, now-firing outline and fired pips use shapes as well as colour. Damage numbers stay up ≥ 0.45 s at ×1.

## 9. Questions for the head (recommended option first)
1. **What do back rows do?** (a) **Every unit fires once per round, front to back** (recommended: snipers, Spotters and Medics keep their jobs; balance stays close to today), or (b) only the front unit fires, and others fire only when they move up (the literal reading: Spec Ops falls to 38%, matches +0.6 rounds, campaign 27.5%).
2. **First Shot:** (a) **"fires first in its exchange"** (recommended: purely front to back, makes position decisive, synergy planning reaches 55%), or (b) its own pass before the normal beats (today's balance kept almost exactly, but a back-row First Shot unit fires before the front line).
3. **Pierce:** (a) **on the Marksman and the Ace ★** (recommended: snipers, the weakest trait, a small effect), (b) also on the Gunner (thematic, almost no effect), or (c) on the Breacher (strong, but it feeds Vanguard, already the top trait).
4. **Playback default:** (a) **×1 for the first runs and ×2 after the tutorial, with tap-to-skip always available** (recommended: ~4 s vs ~2 s per round), or (b) ×2 from the start.

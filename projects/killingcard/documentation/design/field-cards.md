# KillingCard: Field Cards (a third card type that stays on the battlefield)

*Author: Sr Game Designer Agent · 2026-11-05 · Board task kc-field · Status: **exploration for the head's review** · DESIGN ONLY (no code was changed)*
*Inputs: `card-system.md` (kc-sys), `../art/banner-art-direction.md` + `banner-tags-v1.csv` (kc-art), `../reference/README.md`, and the Killstreak rules code in `source/project-killingcard/scripts/rules/` (read for what it supports today).*
*The head's prompt: "Maybe we need another type of cards that goes on battlefield to give an effect, but isn't a unit."*

## 0. Summary in five lines
1. **The engine already has this third type.** Killstreak's `CardType.EQUIPMENT` (Tripwire Charge, Comms Relay) is a card that is placed in a zone, stays there, gives an effect and is not a unit. Today it is a small chip on the objective tile. **We promote it to a visible card type called Field** with its own banner art.
2. Three models were compared (§2): **A Emplacement** (takes a row in the column, can be shot), **B Objective Field** (attached to your half of the objective, can't be shot), **C Support Row** (an extra row behind the line). A "lasts N rounds" timer (D) is an option on top of any of them.
3. **Recommendation: Model B**, with two clarity rules: **one visible Field per side per column** (a new one replaces the old) and **Overrun** (if the enemy controls that column at the end of a round, your Field there is torn down). It is the cheapest in engine terms, it costs the least screen height on a phone, and it keeps "only units fight" true.
4. **Classification gets one new question** (§3): emblems and structures (things that *stand there*) are **Field**; events and motion (things that *happen*) stay **Tactic**. It's still a single look at the `subject` tag: a seconds-long call.
5. **Prototype: yes, in a zero-rules-code form** (§6): Equipment is renamed Field and drawn as a banner strip, emblem/structure art routes to it, and two new Fields that need no rules code (Listening Post, Mortar Pit) join the reward pool. Auras, the one-per-column rule and Overrun come **after the first playtest** (about 60 lines of rules code).

---

## 1. What the engine supports today (the facts every model rests on)
Read from `scripts/rules/` and `scripts/data/data_enums.gd`.

| Fact | Where | What it means for Field cards |
|---|---|---|
| `CardType { UNIT, TACTIC, EQUIPMENT }`: a third type already exists | `data_enums.gd` | No new card type in data. "Field" is the display name of `EQUIPMENT` (enums are append-only; nothing is renamed in code). |
| Equipment is kept in `RulesSide.equipment[zone]` as `{card, round}`, **outside the unit line** | `rules_side.gd` | It never takes a row, never shoots, can't be shot, and never counts for control (`control_of` reads lines only). That *is* Model B. |
| Equipment is placed and armed **at the start of Reveal, before units arrive** (Killstreak ruling, part 2 #2) | `match_state.reveal()` | A Field played this Deploy already affects units arriving this Reveal. |
| Triggers that already work from Equipment: `ON_PLAY` (once, at placement), `END_OF_ROUND` (every round while it stands), `ON_ENEMY_ARRIVE` (traps; `consumed_on_trigger`) | `_reveal_equipment`, `score()`, `trigger_traps()` | Any "each round…" or "when an enemy arrives…" Field is **data only**. |
| `hidden = true` keeps Equipment off the enemy's view; Equipment is never a red dot (Ruling 13) | `card_data`, `_reveal_equipment` | Traps stay secret. |
| `DESTROY_EQUIPMENT` removes enemy Equipment in a zone | `effect_resolver._apply` | Sabotage (and the post-prototype Breaching Charge) are the Field answer cards. |
| `REVEAL_RED_DOTS` with `delay_rounds = 1` reveals *next* round's red dots | `effect_resolver._apply` | `END_OF_ROUND` + this = "this column is always scouted": data only. |
| `PASSIVE` effects (auras) are read **only from units on the board and perks**, not from Equipment | `match_state._passives_for` | Any "while it stands, your units here get…" Field needs **new code** (~15 lines). |
| Passive friendly targets: `SELF`, `OPERATOR`, `ALL_FRIENDLIES`, `OTHER_FRIENDLIES`; enemy targets include `ENEMY_POINT_MAN` | `effect_resolver.passive_applies` | "Your **frontline** unit here gets…" needs a new target `FRIENDLY_POINT_MAN` (~6 lines, appended to the enum). |
| `START_OF_FIREFIGHT` effects are registered once at placement for `duration_rounds` and keep running even if the source is destroyed | `resolve_play`, `firefight_resolver.resolve` | Don't use it for Fields until a "source still standing" check exists (~5 lines). |
| There is **no limit** on Equipment per zone, and **no expiry** | `_check_card`, `RulesSide` | One-per-column, Overrun and timers are all new code (small). |
| No heal effect kind exists (heals come only from the Patch keyword) | `EffectKind` | A healing Field needs a new `HEAL` kind (~12 lines). |
| AI: `ai_planner._equipment_value` values only streak Equipment and damage traps; other Equipment gets a flat 0.2 | `scripts/ai/ai_planner.gd` | Every new Field needs a few lines of AI value, or it stays player-only (reward pool) at first. |
| `match_clone.gd` copies equipment; `outcome_forecast.gd` already filters it | | Simulations and the forecast keep working. |

**Precedent for Model A:** the Sentry token is a unit with `counts_for_control = false` and `grants_elimination_credit = false`. It sits in the line, soaks shots and is "not really a unit" for scoring. An Emplacement is the same thing, played from the deck.

---

## 2. Three models (plus a timer option)

### Model A: Emplacement (takes a row in your column, can be destroyed)
A Field card enters your line like a unit, from the outer edge, and stays in its row. It has **Armor but no Firepower**, never fires, doesn't count for control and gives no elimination credit when destroyed (Sentry rules). Its effect is an aura on its column.

| | |
|---|---|
| **Clarity** | + Everything on the board is a banner in a row: one visual grammar. + "Shoot it to remove it" is instantly understood. − It looks like a unit but isn't one: players will ask why it doesn't shoot, and whether it holds the objective (it doesn't). − It blurs the unit/field line that §3 tries to keep a seconds-long call. |
| **Frontline / Pick / Protector** | It's a **wall**: placed into an empty column it becomes the frontline and soaks every normal shot. Pick (lowest Armor) and Flank (back-most) can target it like any unit. A Protector slides past it. Risk: a cheap 0/5 wall in front of a Medic is very strong in Zone Control because it stalls without contesting. |
| **Phone layout** | The same banner slot as a unit, with a different frame (no FP icon, a "stake" frame, the Armor icon only). Zero new layout. − It uses one of the 4 rows, so a column feels full sooner. |
| **Engine cost** | Low: a `CardType.UNIT` with FP 0, `counts_for_control = false`, `grants_elimination_credit = false`, plus a "never fires" flag (~5 lines in `firefight_resolver`) and a display flag. Auras already work from units (Anvil). Needs a balance pass on capacity because it occupies rows. |

### Model B: Objective Field (attached to your half of the objective, can't be shot) - **recommended**
A Field card is placed on **your side of the objective tile** of a column. It never enters the line, never fires, can't be shot, and doesn't count for control. Its effect applies to its column. Rules on top of today's Equipment:
- **One visible Field per side per column.** Playing a second one there replaces the first (the old one goes to the discard). Hidden traps (Tripwire) don't count toward this limit. So the board shows at most 3 of your Fields and 3 of theirs.
- **Overrun:** at the end of the Score step, after END_OF_ROUND effects, each of your visible Fields in a column **the enemy controls** is torn down (to the discard). "Lose the objective, lose what you built there." Traps are exempt (they are hidden and consumed when triggered).
- **Removed by:** Overrun, replacement, Sabotage (2 Supply, already in card-system §3.2) and the post-prototype Breaching Charge. Not by damage.

| | |
|---|---|
| **Clarity** | + "Units fight in rows; Fields live on the objective." One sentence. + Ownership is spatial: your half of the objective = yours. + Overrun makes Fields part of the frontline story: push them off the objective and the Field falls. − A Field you can't shoot needs visible answers; the inspector names them ("Removed by: Overrun, Sabotage"). |
| **Frontline / Pick / Protector** | Fields never block shots and are never Picked. Frontline auras (Bulwark, War Standard) **follow the frontline**: when the front card dies and the line advances, the buff passes to the new row 1. A **Protector** that slides to the front picks up the frontline aura on arrival, which makes Protector + Bulwark the natural "hold this column" combo. Pick and Flank are the counter to a fortified front: they skip it. |
| **Phone layout** | Smallest cost in height (see §2.1). The objective tile grows from one thin row to roughly 1.5 banner rows; the line keeps its 4 rows. |
| **Engine cost** | Today's Equipment, as is, for every non-aura Field (data only). New code for the full model: Fields as a source of `PASSIVE` (~15), `FRIENDLY_POINT_MAN` target (~6), one-per-column replace (~10), Overrun in `score()` (~10), AI values (~15 per effect family). About **60 lines of rules code** plus AI. Rulings: two new ones. |

### Model C: Support Row (a 5th slot behind your line)
Each side gets one extra slot per column at the outer edge, between the staging strip and row 4. Fields sit there. Flank (back-most) can hit it; other shots can't.

| | |
|---|---|
| **Clarity** | + "Support lives at the back" reads like a real battle line. − A slot that is "in the line for Flank but not for anything else" is a special case players must learn. − Two places to look per column (objective and back row). |
| **Frontline / Pick / Protector** | Gives Flank a second job (sniping the support), which makes Flanker stronger and needs a rebalance. Pick: either include it (it would often be the lowest Armor) or exclude it: another rule to explain. |
| **Phone layout** | Worst: one more banner row per side per column, i.e. +2 rows of height on a screen already tight in landscape (4+4 rows, objective, staging, hand). Banners would shrink about 15%. |
| **Engine cost** | High: a new list per side per zone, new targeting in `firefight_resolver.pick_target` (Flank), clone/forecast/AI updates, new rulings. Several hundred lines plus a balance pass. |

### Option D: Timed (lasts N rounds), on top of A, B or C
The Field shows a countdown and leaves after N rounds (e.g. 3).
- + It caps snowballing with no other rule. + Cheap: the placement round is already stored (`{card, round}`); expiry is ~8 lines in `score()` plus a `field_rounds` data field.
- − One more number on a tiny strip, and players must track it. Overrun does the same job (limits a Field's life) through the board state that players already watch.
- **Use only if the sim shows Fields snowballing with Overrun alone.**

### 2.1 Phone layout for Model B (banner on board)
Landscape phone, banner slot about 180×45 pt (card-system §3.4, art doc §1.3).
```
 enemy row 1  ┌──────────── enemy frontline banner ─────────────┐
              ├─[⛬]░░░░ enemy Field strip (8:1 slice) ░░░░░[⌛/⚡]┤  ~14 pt
              │   OBJECTIVE B · MID · control dot · (trap mark)   │  ~18 pt
              ├─[⛬]▓▓▓▓ your Field strip (8:1 slice) ▓▓▓▓▓[⚡]────┤  ~14 pt
 your row 1   └──────────── your frontline banner ──────────────┘
```
- **Field strip:** a thin horizontal slice of the Field's banner, taken at `banner_y` (no new crop work: it's the same band, cut thinner). Left: the Field glyph (a stake/pylon icon of our own; never a flag, art doc §1.5). Right: ⚡ (effect) and, if Option D is ever used, a round count. Empty strip = a plain dark plate.
- **Aura link:** a frontline aura draws a thin glow from your strip to your row 1, so "this buffs my front card" is visible, and the glow jumps when the line advances.
- **Placement moment:** the Field's full banner flies in at full board size, plays its animation tier if it has one (art doc §4: placement = one loop), then folds down into the strip. That is the moment the player sees the art large.
- **Inspect:** right-click or long press on a strip opens the full banner plus text plus "Removed by: Overrun, Sabotage" (studio UX rule). Hidden traps show your own as a dashed mark; the enemy sees nothing.
- **Hand:** Field cards use the same portrait crop as tactics, with the cost hex, ⚡, the Field glyph and a "column" target hint.

---

## 3. Which banner arts become Field cards, and the new classification rule

### 3.1 The rule (replaces card-system §1.1; stop at the first "yes")
| # | Question | Yes → | `subject` values |
|---|---|---|---|
| Q1 | Is the main subject a **character** (soldier, creature, animal, robot shown as a combatant)? | **UNIT** | `soldier`, `creature`, `animal`, `robot` |
| Q2 | Is it a **weapon** alone or an **armed vehicle/drone**? | **UNIT** | `weapon_only`, `vehicle` (armed) |
| Q3 (new) | Is it something that **stands there**: an **emblem** or a **structure** (a building, wall, tower, mast, bunker, a placed device such as a mine or sensor)? | **FIELD** | `emblem`, `structure` (new value) |
| Q4 | Anything else: something that **happens** (explosion, fire, storm, motion, a moment), a landscape, a loose object, abstract art, an unarmed vehicle. | **TACTIC** | `landscape`, `object`, `abstract`, `vehicle` (unarmed) |

**Curator shortcut:** *Fighter or gun → Unit. Symbol or building → Field. A moment → Tactic.* Unsure between Field and Tactic → **Tactic** + `review = yes` (unchanged default; keeps the tactic pool fed).

### 3.2 Tag changes (append-only)
| Field | Change | Why |
|---|---|---|
| `kind` | + `field` | The third kind. Must match `CardType.EQUIPMENT` on the chassis. |
| `subject` | + `structure` | Buildings, walls, towers, masts, emplacements, placed devices. Before this, they were squeezed into `object` or `landscape`. |
| everything else | no change | `verb` `trapping` / `signalling` (card-system §2.2) now route Field art instead of Equipment tactic art. |

### 3.3 Edge cases
| Case | Ruling |
|---|---|
| **Flat animal or weapon emblem** (the head's question) | **FIELD** (`emblem`). A symbol you plant, not a combatant. |
| Emblem with motion (a charging horse emblem) | Still **FIELD**. The subject decides, not the verb. The verb only picks which Field. |
| Landscape where **one built thing dominates** (lighthouse, seawall, watchtower) | **FIELD**, retag `subject = structure`. A landscape with no dominant structure stays **TACTIC**. |
| Landscape with an **event** (city on fire, tracers, storm) | **TACTIC**. Something is happening. |
| A **crate, dice, a door** (loose object) | **TACTIC** (`object`). A **placed device** (mine, antenna, sensor) is `structure` → **FIELD**. |
| A turret or walker with a gun | **UNIT** or killstreak skin (armed, Q2). An empty gun pit or bunker with no gun visible → **FIELD**. |
| Flags, crests, insignia | **Never generated** (art doc §1.5 hard rule 3). "Standards" and "banners" are drawn as abstract emblems on a gradient, or as a structure (a pole of lights, a beacon). |
| Equal-size character and structure | **UNIT** (tie-break: character > weapon > field > tactic). |

### 3.4 Effect on the artist's pack v1 (only 4 arts move; nothing is owned yet, so re-mapping is free)
| Banner | Was | Becomes | Field chassis |
|---|---|---|---|
| `kc_b_callout_ping` (emblem, revealing, animated ring pulse) | Callout | **FIELD** | **Listening Post** (§4). The ring pulse is a perfect "always scanning" loop. |
| `kc_b_flank_route_emblem` (emblem, flanking) | Flank Route | **FIELD** | **Listening Post** in the prototype (fallback); **War Standard** once it exists. |
| `kc_b_hold_seawall` (landscape, holding) | Hold the Line | **FIELD** if the curator retags it `structure` (the wall dominates); otherwise stays a tactic | **Bulwark** (post-prototype); until then it stays on Hold the Line. |
| `kc_b_sentry_walker` | Sentry killstreak skin | unchanged (armed robot) | — |

Callout and Flank Route each keep at least one art (Flank Route: the alley; Callout needs one new art from the next batch). Field gaps for the next prompt batch: a wire trap, an antenna mast (card-system already lists these), a mortar pit (the sandbagged pit, shell crates and smoke dominate; if a gun tube dominates, Q2 makes it a weapon), a sandbag bunker, a beacon pole of lights, a sniper tower, an aid tent (no red cross: a plain tent with lamps).

### 3.5 Field mapping table (`kind = field`, first match wins, as in card-system §2.3)
| # | Chassis | Joins if (any of) | Phase |
|---|---|---|---|
| F1 | Tripwire Charge | verb `trapping` | prototype |
| F2 | Comms Relay | verb `signalling` | prototype |
| F3 | Listening Post | verb `revealing` or `scouting`, or element `electric`/`neon` | prototype |
| F4 | Mortar Pit | element `explosive`/`fire`, or verb `suppressing`/`attacking` | prototype |
| F5 | Aid Station | verb `healing` | after |
| F6 | Sniper Perch | weapon art `sniper`/`bow` motif, or a tower with setting `sky`/high ground | after |
| F7 | Bulwark | verb `guarding` or `holding` | after |
| F8 | War Standard | verb `charging`/`rushing`/`flanking`, or an `emblem` of an animal | after |
| — | **Fallback** | any Field art: **War Standard** (after); **Listening Post** in the prototype | |

---

## 4. Example Field cards (exact numbers)
Balance anchors from Killstreak: Supply N+1 per round (2 → 7), matches of 5–8 rounds, Hold the Line 2 Supply = Cover 1 to your units in a zone **for one round**, Suppressing Fire 2 = −1 FP to enemies **for one round**, Tripwire 2 = 3 damage once, Comms Relay 2 = +1 streak per controlled round, Commander ★ 5 = 3/6 body with +1 FP to others. **A Field's effect per round is about half of a one-round tactic's**, because it lasts and because Overrun and Sabotage are its counters. All Fields are `CardType.EQUIPMENT`, scope = their own column.

| # | Field | Cost | Text (≤ 100 chars) | EffectData | Engine | Phase |
|---|---|---|---|---|---|---|
| 1 | **Tripwire Charge** (existing) | 2 | Hidden. The next enemy unit to arrive in this column takes 3 damage. Then it's gone. | ON_ENEMY_ARRIVE · DAMAGE 3 · ARRIVING_ENEMY · THIS_ZONE · `hidden`, `consumed_on_trigger` | **today** | prototype (starter deck) |
| 2 | **Comms Relay** (existing) | 2 | While you control this column: streak +1 at end of round. | END_OF_ROUND · STREAK_BONUS 1 · OWNER · condition YOU_CONTROL_ZONE | **today** | prototype (reward) |
| 3 | **Listening Post** (new) | 1 | Each round, enemy red dots in this column are revealed to you. | END_OF_ROUND · REVEAL_RED_DOTS · THIS_ZONE · delay_rounds 1 | **today** (data) + AI value | prototype (reward) |
| 4 | **Mortar Pit** (new) | 3 | At end of round: 1 damage to the enemy frontline unit in this column. | END_OF_ROUND · DAMAGE 1 · ENEMY_POINT_MAN · THIS_ZONE | **today** (data) + AI value | prototype (reward) |
| 5 | **Bulwark** (new) | 3 | Your frontline unit in this column has Cover 1. | PASSIVE · GRANT_COVER 1 · FRIENDLY_POINT_MAN (new) · THIS_ZONE | Field passives + new target | after |
| 6 | **War Standard** (new) | 3 | Your frontline unit in this column gets +1 FP. | PASSIVE · MODIFY_FIREPOWER +1 · FRIENDLY_POINT_MAN · THIS_ZONE | Field passives + new target | after |
| 7 | **Sniper Perch** (new) | 2 | Your Sniper units in this column get +1 FP. | PASSIVE · MODIFY_FIREPOWER +1 · ALL_FRIENDLIES · THIS_ZONE · target_class SNIPER | Field passives (target_class exists) | after |
| 8 | **Aid Station** (new) | 2 | At end of round: your most damaged unit in this column heals 1. | END_OF_ROUND · HEAL 1 (new kind, Patch's "most damaged" rule) · THIS_ZONE | new HEAL kind | after |

### 4.1 How each plays with Pick, the Protector slide and the frontline
| Field | Frontline | Pick / Flank | Protector |
|---|---|---|---|
| Tripwire Charge | Hits whoever arrives, front or back. | Not involved. | A Protector arriving into it still takes the 3 (minus its Cover 1 = 2). |
| Comms Relay | Rewards keeping a frontline that holds the objective. With Overrun, losing the column also loses the Relay. | Not involved. | A Protector in front is the classic Relay guard. |
| Listening Post | Shows what will arrive behind the enemy front next round, so you can trap it (Tripwire) or answer it (Breach and Clear). | Lets you see a Marksman coming and play Smoke Screen in time. | Shows when the enemy is about to slide a Protector in front. |
| Mortar Pit | Chips the enemy frontline every round; with your normal shots it decides who breaks first. | Complements Pick: Mortar wears down the front while Pick kills the back. | **Counter:** the enemy Protector's Cover 1 cancels the Mortar's 1 damage completely. That's intended: Protector beats chip damage. |
| Bulwark | The frontline gets Cover 1; the buff moves to the new row 1 when the line advances. | **Counter:** Pick and Flank skip the frontline, so a Bulwarked column invites a Marksman or Flanker. | Protector (Cover 1) slides to the front → **Cover 2** wall. Strong on purpose; answered by Pick, Flank, Sabotage, Breach and Clear (column damage ignores who is in front; Cover still applies). |
| War Standard | The frontline hits +1 harder, every round, whoever it is. | Not involved; pairs with Point Man/Breacher First Shot at the front. | A Protector at the front gets 2 FP: still weak, so War Standard prefers a fighter in front, Bulwark prefers a Protector. That tension is the choice. |
| Sniper Perch | Not involved (snipers belong in the back). | **Boosts Pick:** Marksman 2 → 3, Ace ★ 4 → 5. Counter: Smoke Screen, Flanker hunting the back. | Pushes the "Protector in front, snipers behind" formation the vertical board shows best. |
| Aid Station | Heals whoever is most damaged, usually the frontline. | **Counter to Pick:** Pick targets the lowest Armor, Aid Station keeps raising it. | Keeps a Protector wall standing across rounds. Stacks with a Medic's Patch (end of firefight) at a different time (end of round). |

### 4.2 Balance notes
- **Mortar Pit (3)** vs Breach and Clear (3, 2 damage to every enemy once): Mortar needs about 4 rounds standing to match B&C against a 2-unit column, and does nothing into Cover 1. Provisional.
- **Listening Post (1)** vs Callout (0, one reveal + 1 FP): intel is weak against the AI (it commits first, so red dots already exist); its value is in planning traps. Cheap on purpose; it is also the prototype's fallback home for emblem art.
- **Bulwark / War Standard (3)** pay off from round 2 on. Placed in round 1 (2 Supply) they're impossible, which keeps them out of the opening. If the sim shows them snowballing, try cost 4 first, then Option D (3 rounds).
- All four new Fields enter **through the reward pool only**, like card-system's other new chassis, so the starter experience and Killstreak's p19 balance numbers stay valid. Run `tests/tools/balance_sim.gd` with them added.

---

## 5. Engine cost, by phase
| Item | Files (proposal for the mechanics developer) | Size | Phase |
|---|---|---|---|
| Display rename "Equipment" → "Field" (enum value stays `EQUIPMENT`) | `card_info.gd`, `card_view.gd`, `card_samples.gd`, card texts | data/UI | prototype |
| `BannerArt.kind` + `field`, `subject` + `structure`, validator: field art only on `EQUIPMENT` chassis | `banner_art.gd`, `card_db.suggest_chassis` (adds §3.5) | small | prototype |
| `listening_post.tres`, `mortar_pit.tres`, reward pool +2 | `data/cards/`, `run_config.tres`, `gen_content.gd` | data | prototype |
| AI values for END_OF_ROUND REVEAL and DAMAGE Equipment | `ai_planner._equipment_value` | ~10 lines | prototype |
| Objective tile with two Field strips, aura glow, placement fold-down, inspector | `lane.gd` (column), new `field_strip.gd` | UI | prototype (the objective tile has to be built anyway) |
| Fields as a `PASSIVE` source, scoped to their column | `match_state._passives_for`, `effect_resolver.passive_applies` | ~15 lines | after |
| `Target.FRIENDLY_POINT_MAN` (append) | `data_enums.gd`, `effect_resolver.targets/passive_applies` | ~6 lines | after |
| One visible Field per side per column (replace on placement; hidden traps exempt) | `match_state._check_card`, `_reveal_equipment` | ~10 lines | after |
| Overrun in `score()` after END_OF_ROUND effects; reuse `EQUIPMENT_DESTROYED` event with `reason: overrun` | `match_state.score()` | ~10 lines | after |
| `EffectKind.HEAL` (append), reusing Patch's most-damaged choice | `data_enums.gd`, `effect_resolver._apply` | ~12 lines | after |
| Rules tests: Field passive, frontline follow, replace, Overrun, HEAL; AI values for auras | `tests/` | | after |

The card-system doc's promise holds: **the prototype needs no rules logic change.** The post-prototype step is about 60 lines of rules code, two new rulings (one-per-column, Overrun) and AI weights.

---

## 6. Recommendation
**Adopt Model B (Objective Field) and call the type "Field".**
- It's the head's idea already half-built: Equipment *is* "a card on the battlefield that gives an effect but isn't a unit". We give it art, a name and a place on the board.
- It keeps the clearest rule on the board: **only units take rows and fight.** Model A breaks that; Model C costs screen height a phone doesn't have.
- It solves the curator's emblem problem with one more question (symbol or building → Field) and gives the tactic pool's weakest art (flat emblems) a better home.
- Overrun ties Fields to the frontline, which is the heart of the vertical board.

**First prototype: yes, the zero-rules-code slice.**
1. Rename Equipment → Field in the UI; draw Fields as strips on the objective tile (that tile needed equipment chips anyway).
2. Route `emblem` / `structure` art to Field (§3), re-map the 2–3 arts in §3.4.
3. Ship 4 Fields: Tripwire Charge (starter), Comms Relay, Listening Post, Mortar Pit (reward pool). Chassis count 24 → 26 (11 tactics → 9 tactics + 4 Fields; card-system §3.1 table to be updated after the head's decision).

**After the first playtest** (if players use Fields and understand them): Field auras (Bulwark, War Standard, Sniper Perch), Aid Station, one-per-column, Overrun. **Option D** (timers) only if the sim shows snowballing. Backlog ideas that fit the same frame: *Jammer* (enemy units here lose First Shot; anti-Rusher) and *Holdfast* (ties in this column go to you, like Holder).

---

## 7. Questions for the head (recommended option first)
1. **Model:** (a) **B, Fields on your half of the objective, can't be shot, one per column, torn down by Overrun** (recommended), (b) A, Emplacements that take a row and can be shot, or (c) keep Equipment as small chips and send emblems to tactics as today.
2. **Name of the type:** (a) **Field** (recommended: short, says "on the field", fits the icon), (b) Emplacement, (c) Standard (but our art can't show flags).
3. **Prototype scope:** (a) **the zero-rules-code slice: rename + strips + Listening Post and Mortar Pit** (recommended), (b) the full model (auras, one-per-column, Overrun) in the prototype, or (c) no Fields until after the first playtest.

---

## Head's decisions (2026-11-05, task kc-field)
- **F1:** Model **B**: a Field sits on your half of the objective, can't be shot, **one per side per column**.
- **F2:** the type is called **Field**.
- **F3:** the **full model goes into the first prototype**: auras from Fields, the one-per-column limit, **Overrun**, Aid Station (heal), plus the data-only cards. Use timers only if the balance sim shows Fields snowballing.

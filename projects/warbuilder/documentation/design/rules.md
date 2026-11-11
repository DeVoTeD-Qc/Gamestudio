# Warzone Deckbuilder: rules (v7, "Squad Tactics")

*Mechanics Developer · 2026-11-11 · Board task `wb-pkg1` · **The written single source of truth for the rules.***
*Built from `wb-improve-v2.md` with the head's answers: W1 (a) the package (O1 Squad Tactics + O2 Spoils + O3 Field Promotion + O6 Hot Drop delivery + O7 Threat, Deck bar and after-action screen), W2 (b) ranks and unlocks only (O10), W3 (a) Spoils, W4 (a) Health about 55–60 plus a small trim, W5 (a) the 12 Tactics replace 12 cards.*
*Still in force: the "Warzone Deckbuilder" title and names, the closing circle with a hard end, a single-file build, the print-and-play.*

The engine (`source/project-warbuilder/src/engine.js`) implements exactly these rules; the print-and-play (`src/pnp/gen.js`) and the in-game How to play are generated from the same data. If this page and the code ever disagree, the code is the bug report: fix one of them and its test (`npm test`).

## 1. Overview
Two operators drop into a row of 7 locations that closes from the ends. You start with 10 weak cards and a pistol, loot better cards and guns, build a squad engine, and shoot your rival from 60 Health to 0 before the storm decides it.

## 2. Components and setup
- **Per player:** 10 starters (3 Sprint, 3 Scout, 2 Steady Aim, 2 Recon Run), a Sidearm pistol, 60 Health.
- **Buy Station:** 6 copies of each squad basic (Tac Sprint, Focus, Spare Rounds, Dead Drop), 2 Intel each.
- **Loot:** 76 cards in 3 tiers and 4 squads (12 of them Loadout cards, 24 of them Squad Tactics), 28 loot guns.
- **Map:** 8 location types; 7 are dealt in a fixed row. Each location gets a face-up loot stack of 3 (a Common gun on top while they last; each card is that location's squad 2 times in 3).
- Players start on the 2nd and 6th locations (Operation *Close Drop*: 3rd and 5th) and draw 5. A random player goes first; the lead alternates every round. A coin decides which end of the row closes first.

## 3. Your turn
1. **Ready** (automatic): your Armor drops to 0 (unless you Fortified), your Loadout cards give their effect, then your location's bonus. Suppression from the rival, if any, applies to this turn.
2. **Play cards** in any order to gain Movement, Precision, Intel, extra shots and Armor, and to trigger their other effects.
3. **Move once**: 1 Movement per location. Arriving gives that location's bonus (once per location per turn).
4. **Loot**: up to **2 buys** per turn (+1 per *+1 Buy*): the top card of the stack where you stand (its printed Intel cost), next door (+1 Intel), or a Buy Station basic (2 Intel). **Cycle**: 1 Intel or 1 Movement puts the top of your stack under it. **Buy Station service**: 1 Intel scraps a Sprint (once per turn, not a buy).
5. **Field Promotion** (§5) and **Fire** (§6), in any order with the rest.
6. **End turn**: first **Spoils** if you dealt damage this turn (§4). Then, if you played *Hold the Angle*, up to 4 unspent Precision is saved (§7). Unused Movement becomes Armor (up to 2). Discard your hand and play area (not the Loadout row) and draw 5 (6 at 10 Health or less). Cards from a **Hot Drop** join that new hand.

**Hot Drop (O6):** in rounds 1–3 a card you gain (loot or Buy Station) is set aside and **delivered into your next hand**, on top of the 5 you draw. It can never be revealed by your own shot before you see it. From round 4, gained cards go to your discard pile.

## 4. Spoils (O2)
At the end of a turn in which you dealt damage (any hit: your gun, a Sentry Turret; not a held-angle shot, which happens on the rival's turn), before anything else:
- Draw **3 different loot cards** from the loot deck of this phase (tier I in rounds 1–3, II in rounds 4–7, III later; if the deck runs short, the next tier, then the previous). Guns are never offered.
- The **first card is from your main squad** (the squad you own most cards of) when the deck still has one; the others are random.
- **Take 1** to your discard pile, for free, or **skip**. The cards you don't take go back. Nothing else can happen until you choose (the app shows the choice as a sheet; each card can be inspected).

## 5. Field Promotion (O3)
Once per turn, pay **1 Intel and one of your buys**: a starter (Sprint, Scout, Steady Aim, Recon Run) in your hand, play area or discard pile **leaves the game**, and a Buy Station basic of **the squad you choose** takes its place, from the Buy Station's stock (6 of each; if a pile is empty you can't promote into it). The basic goes to your hand if the starter was there, otherwise to your discard pile. Promotion is not a purchase for Hot Drop purposes: the card is placed directly.

## 6. Firing
- You carry **one gun**. Buying a gun replaces yours (yours goes under that stack). Every gun fires from distance 0 up to its range.
- **Commit** Precision: reveal one card from the top of your deck per Precision committed, plus 1 free card per *Steady*. Count the Hit Markers.
- The shot spends the Precision you committed, then the gun's **Recoil** costs that much more (never below 0).
- **Damage ladder:** reach the first step to hit, the second for a big hit. *Mark*: the next shot needs 1 fewer Hit Marker on every step. *Hits +N damage* adds to every step. *Charge* adds +1 more at distance 0.
- **Cover** at the target's location: −1 damage (*Pierce* ignores it). **Close quarters** (distance 0): no cover, no Armor. Otherwise the target's best **Reaction** card in hand, then its **Armor**, reduce the damage. *Expose* switches Reaction cards and Armor off. A hit always deals at least 1.
- Each gun fires up to its **Shots** per turn, plus extra shots. **Combat Knife**: distance 0 only, always hits for 3.
- Revealed cards go to your discard pile. When your deck is empty, shuffle your discard pile into a new deck.

### Guns (wb-pkg1 trim: every Hit Marker step is 1 higher than in v6)
Rarity mods are unchanged (Hollow Points +1 damage, Extended Mag +1 shot, Compensator −1 Recoil, Red Dot −1 Hit Marker on every step).

| Gun (Common) | Class | Range | Ladder (Hit Markers → damage) | Shots | Recoil |
|---|---|---|---|---|---|
| Sidearm | Pistol | 0–2 | 3+ → 2, 5+ → 3 | 2 | 2 |
| Magnum | Revolver | 0–3 | 4+ → 4, 7+ → 7 | 1 | 3 |
| Combat Knife | Melee | 0 | always → 3 | 1 | 0 |
| Viper | SMG | 0–1 | 3+ → 2, 6+ → 4 | 2 | 0 |
| Breacher | Shotgun | 0–1 | 3+ → 3, 7+ → 6 | 1 | 3 |
| Raider | Burst Rifle | 0–2 | 3+ → 2, 7+ → 4 | 2 | 0 |
| Sapper | Launcher | 0–3 | 4+ → 4, 7+ → 7 | 1 | 3 |
| Sentinel | Assault Rifle | 0–3 | 4+ → 3, 6+ → 5 | 2 | 1 |
| Bastion | LMG | 0–3 | 4+ → 3, 7+ → 5 | 3 | 0 |
| Ranger | Marksman Rifle | 0–4 | 4+ → 3, 8+ → 6 | 2 | 1 |
| Longbow | Sniper | 0–5 | 4+ → 4, 9+ → 8 | 1 | 2 |

## 7. Squads, Rally, Loadout and Squad Tactics
- **Squad line:** pays once for **each other card of its squad** in play this turn (Loadout counts), up to ×3, in any order.
- **Rally:** with 3 and with 5 cards of one squad in play you also get that squad's bonus, once per turn each. Assault 3: hits +1 damage, +2 Precision, Pierce; 5: hits +1 damage, +2 Precision. **Recon 3: Mark, hits +1 damage; 5: Mark, hits +1 damage, +2 Precision** (wb-pkg1: Recon hits harder, not only surer). Support 3: +2 Precision, +1 extra shot, Steady; 5: +3 Precision, +1 extra shot, Steady ×2. Engineer 3: +1 Intel; 5: draw 1.
- **Loadout** cards go to your Loadout row (2 slots): they give their effect when deployed and at every Ready, and count for Squad and Rally. With both slots full, a new one replaces a slot (the old card to your discard) or is used once.
- **Keywords:** Mark, Pierce, Steady, Scrap (remove a card in hand, play area or discard from the game; never below 7 cards), +1 Buy, Reaction.

### Squad Tactics (O1): the rules of the 12 new verbs
| Tactic | Squad | Rule |
|---|---|---|
| **Charge** | Assault | +2 Movement, +1 Precision. This turn your hits at distance 0 deal +1 damage. |
| **Follow Through** | Assault | Your next hit this turn draws 2 cards right away; you may play them and keep shooting. |
| **Adrenaline** | Assault | Each time a shot hits you, one Adrenaline in your discard pile returns to your hand (you play it on your next turn). |
| **Intel Sweep** | Recon | Look at your top 4 cards and put them back in any order (shots reveal from the top). Until you arrange them they stay as they were; if your deck changes first, the Sweep is over. |
| **Expose** | Recon | Mark. This turn your hits ignore the rival's Armor and Reaction cards (cover still applies). |
| **Hold the Angle** | Recon | At End turn, up to 4 unspent Precision is saved. If the rival **ends their next turn** within your gun's range, your gun fires once with it: reveal that many cards and use the gun's printed ladder (no Recoil, no Mark, no damage bonuses; cover, Reactions and Armor apply). Otherwise it is lost at your Ready. |
| **Fortify** | Support | At your next Ready your Armor is kept (up to 6) instead of dropping to 0. |
| **Field Medic** | Support | Heal 3, never above your starting Health. |
| **Suppressing Barrage** | Support | On the rival's next turn, the first 1 Movement and the first 2 Precision they gain (Loadout, location, cards) are lost. |
| **Jury-Rig** | Engineer | Repeats the play line (not the Squad line, not a Loadout effect, not another Jury-Rig) of the card you played just before it this turn. Played first: nothing to repeat. |
| **Sentry Turret** | Engineer (Loadout) | When deployed and at every Ready, if the rival is 0–3 away: reveal 1 card; 1 Hit Marker hits for 2 (cover, Reactions and Armor apply). Its damage counts for Spoils. |
| **Contraband Run** | Engineer | This turn your buys may take the top card of any stack on the map, at its printed cost (no next-door cost). |

## 8. The circle and the end
- At the end of rounds 2, 4, 5, 6, 7 and 8 one end location closes (alternating ends; the schedule is public): 7 → 1 location, the **final circle**, after round 8. Its loot is lost.
- Caught outside at round end: 3 damage +1 per extra location deep (Operation *Scorched Earth*: +1), then you are moved to the nearest safe location.
- In the final circle the storm hits both operators at each round end for 3, then 4, 5, 6.
- Every round end each safe stack gets 1 fresh card on top (tier by phase); a stack over 3 loses its bottom card. **Supply crates** after rounds 2 and 4 (Operation *Supply Run*: and 6): 3 tier III items, a gun first, on top of the middle stack.
- **Winning:** bring your rival to 0 Health. If both fall at once, the higher Health wins (equal: draw). **Hard end** after round 11: the most Health wins.

## 9. Operator rank and unlocks (O10, digital only)
Saved on this device (`localStorage` key `wb-operator-v1`; every read and write is guarded, and the game works without it). XP after every match vs the AI: **40** for playing, **+60** for a win (+30 for a draw), **+1 per damage dealt** (up to 80), **+20** for reaching the final circle. Unlocks add **variety, never power**:

| Rank | XP | Unlocks |
|---|---|---|
| Recruit | 0 | the full card pool, always |
| Private | 150 | **Daily Drop**: one seeded match per day, the same for everyone (no Operations) |
| Corporal | 350 | Operation **Close Drop**: both operators start 2 locations apart |
| Sergeant | 650 | Operation **Supply Run**: a third supply crate after round 6 |
| Staff Sergeant | 1,000 | Operation **Scorched Earth**: the gas deals 1 more damage |
| Lieutenant | 1,500 | silver insignia |
| Captain | 2,200 | gold insignia |

Operations apply to **both** operators, so they change the drop, not the odds. At the table you can play any Operation by agreement.

## 10. What the screen shows (O7)
- **Threat** (replaces the Firepower sum): the damage you can expect from the rest of this turn if you play your hand and shoot as the planner suggests, with the first shot's odds. Between turns: the damage you dealt, with a per-turn sparkline.
- **Deck bar:** starters against the cards you added, coloured by squad.
- **Tactical chips:** every Tactic in play, yours and your rival's (red ⚠ when it can hurt you: a held angle, a Suppression). Each chip, card, gun and location explains itself on **long press (touch), right click or hover (mouse)**.
- **After-action report:** damage per round for both players, your best turn and its round, your MVP card (most Hit Markers in your hits), the cards you added, XP and rank.

Screenshots (from `qa/tools/smoke_pkg.js`, headless Chromium, the built page):

| | |
|---|---|
| ![Spoils, phone](../../qa/screenshots/pkg1/phone-06-spoils.webp) | ![Tactics in play, desktop](../../qa/screenshots/pkg1/desktop-12b-inspect-chip.webp) |
| Spoils after a damaging turn (phone). | Tactical chips; right click explains the rival's held angle (desktop). |
| ![After-action, phone](../../qa/screenshots/pkg1/phone-07-after-action.webp) | ![Sweep, phone](../../qa/screenshots/pkg1/phone-13-sweep.webp) |
| After-action report (phone). | Intel Sweep: tap the new order (phone). |

## 11. Card list (v7)
Starters: Sprint (+1 Movement, 0 Hit Markers), Scout (+1 Intel, 0), Steady Aim (+1 Precision, 1), Recon Run (+1 Movement, +1 Intel, 1). Buy Station basics (2 Intel, Squad line in brackets): Tac Sprint +1 Movement +2 Precision, 1 HM (+1 Precision); Focus +2 Precision, 2 HM (+1 Precision); Spare Rounds +2 Precision +1 extra shot, 1 HM (+1 Precision); **Dead Drop** +2 Intel, 1 HM (**+1 Buy**, was +1 Intel).

**Replaced by the 12 Tactics (W5):** Flank → Charge, Run and Gun → Follow Through, Blitz → Adrenaline, Heartbeat Sensor → Intel Sweep, Thermal Optic → Expose, Headhunter → Hold the Angle, Steady Grip → Fortify, Munitions Drop → Field Medic, Covering Fire → Suppressing Barrage, Field Kit → Jury-Rig, Munitions Box → Sentry Turret, Black Market → Contraband Run. Same copies, same tiers (Sentry Turret: one tier II and one tier III copy), same print-and-play size; each keeps the art of the card it replaced.

**Trimmed (W4):** every gun ladder +1 Hit Marker; Ammo Box (Steady instead of an extra shot), Bandolier and Resupply (no extra shot), Field Pack (+1 Precision and Steady). **Retuned for balance:** Spotter Scope's Squad line (Mark, hits +1 damage), Recon Rally, Dead Drop's Squad line.

Loot cards by squad (generated from the engine):

### Assault

| Card | Tier | Intel | Hit Markers | Copies | Play | Squad line (once per other Assault card in play, up to ×3) |
|---|---|---|---|---|---|---|
| Breach | I | 1 | 2 | 2 | Gain 1 Movement and 2 Precision. | hits +1 damage, +1 Precision |
| Slide Cancel | I | 1 | 2 | 2 | Gain 2 Movement and 1 Precision. Scrap 1. | Draw 1, +2 Precision |
| Hip Fire | I | 2 | 2 | 2 | Gain 1 Movement and 2 Precision. | +3 Precision |
| Rush the Door | II | 3 | 2 | 2 | Gain 1 Movement and 3 Precision. Pierce. | hits +1 damage, +2 Precision |
| Charge · **Tactic** | II | 3 | 2 | 2 | Gain 2 Movement and 1 Precision. At distance 0 your hits deal +1 damage this turn. | +1 Precision |
| Follow Through · **Tactic** | II | 3 | 2 | 2 | Gain 1 Movement and 2 Precision. Your next hit this turn draws 2 cards. | +1 Precision |
| Adrenaline · **Tactic** | III | 4 | 3 | 2 | Gain 1 Movement and 3 Precision. When a shot hits you, return this from your discard pile to your hand. | +1 Precision |
| Breaching Charge | III | 4 | 3 | 2 | Gain 1 Movement and 3 Precision. Pierce. Hits +1 damage. | hits +1 damage, +1 extra shot, Steady |
| Tac Vest | I/II/II | 3 | 1 | 3 | Loadout. Ready: +2 Precision, hits +1 damage. | (Loadout: counts for Squad and Rally) |

### Recon

| Card | Tier | Intel | Hit Markers | Copies | Play | Squad line (once per other Recon card in play, up to ×3) |
|---|---|---|---|---|---|---|
| Mark Target | I | 1 | 2 | 2 | Gain 2 Precision. | Mark, +1 Precision |
| Steady Breath | I | 1 | 3 | 2 | Gain 2 Precision. | +2 Precision |
| Snapshot | I | 2 | 2 | 2 | Gain 2 Precision and 1 Intel. | +2 Intel, +1 Precision |
| Intel Sweep · **Tactic** | II | 3 | 2 | 2 | Gain 2 Precision. Look at your top 4 cards and put them back in any order. | hits +1 damage |
| Spotter Scope | II | 3 | 3 | 2 | Gain 3 Precision. | Mark, hits +1 damage |
| Expose · **Tactic** | II | 3 | 2 | 2 | Gain 2 Precision. Mark. This turn your hits ignore Armor and Reaction cards. | Mark, hits +1 damage |
| UAV | III | 4 | 3 | 2 | Gain 3 Precision and 1 Intel. Pierce. | Draw 1, Mark, +1 Precision |
| Hold the Angle · **Tactic** | III | 4 | 3 | 2 | Gain 3 Precision. At End, save up to 4 unspent Precision: fire it if the rival ends their turn in range. | hits +1 damage |
| Recon Post | I/II/II | 3 | 1 | 3 | Loadout. Ready: +2 Precision. | (Loadout: counts for Squad and Rally) |

### Support

| Card | Tier | Intel | Hit Markers | Copies | Play | Squad line (once per other Support card in play, up to ×3) |
|---|---|---|---|---|---|---|
| Ammo Box | I | 2 | 2 | 2 | Gain 2 Precision. Steady. Scrap 1. | +3 Precision |
| Suppressing Fire | I | 2 | 2 | 2 | Gain 2 Precision and 1 Armor. | +2 Precision, +1 Armor |
| Bandolier | I | 2 | 2 | 2 | Gain 2 Precision and 1 Armor. Steady. | +3 Precision |
| Fortify · **Tactic** | II | 3 | 2 | 2 | Gain 2 Precision and 2 Armor. Your Armor holds through your next Ready (up to 6). | +1 Armor |
| Resupply | II | 3 | 2 | 2 | Gain 1 Precision and 1 Intel. Draw 1. | Steady, +2 Precision |
| Field Medic · **Tactic** | II | 3 | 2 | 2 | Gain 1 Precision. Heal 3. | +1 Precision |
| Overwatch | III | 5 | 3 | 2 | Gain 4 Precision, 1 extra shot and 2 Armor. | +2 Precision, +1 Armor |
| Suppressing Barrage · **Tactic** | III | 4 | 3 | 2 | Gain 3 Precision and 1 extra shot. Suppress: the rival's next turn gets −1 Movement and −2 Precision. | +1 Precision |
| Field Pack | I/II/II | 3 | 1 | 3 | Loadout. Ready: +1 Precision, Steady. | (Loadout: counts for Squad and Rally) |

### Engineer

| Card | Tier | Intel | Hit Markers | Copies | Play | Squad line (once per other Engineer card in play, up to ×3) |
|---|---|---|---|---|---|---|
| Scrounge | I | 2 | 1 | 2 | Gain 1 Precision and 2 Intel. Scrap 1. | +2 Intel |
| Deployable Cover | I | 2 | 1 | 2 | Gain 1 Precision and 2 Intel. | +2 Intel |
| Ping | I | 1 | 1 | 2 | Gain 1 Precision and 1 Intel. 1 free cycle. | Draw 1, +1 Intel |
| Jury-Rig · **Tactic** | II | 3 | 2 | 2 | Gain 1 Intel. Repeat the play effects of the card you played just before this one. | +1 Intel |
| Sentry Turret · **Tactic** | II/III | 3 | 1 | 2 | Loadout. Ready: free shot, distance 0–3: reveal 1; 1 Hit Marker hits for 2. | (Loadout: counts for Squad and Rally) |
| Salvage | II | 3 | 2 | 2 | Gain 1 Precision and 2 Intel. Scrap 1. 2 free cycles. | +2 Intel, +1 Buy |
| Field Workshop | III | 4 | 2 | 2 | Gain 2 Precision and 2 Intel. Draw 1. Scrap 2. | +2 Precision, Draw 1 |
| Contraband Run · **Tactic** | III | 4 | 2 | 2 | Gain 1 Precision and 3 Intel. This turn you may buy the top card of any stack on the map, at its printed cost. | +1 Intel |
| Bounty Contract | I/II/II | 3 | 1 | 3 | Loadout. Ready: +1 Intel, +1 Precision. | (Loadout: counts for Squad and Rally) |

## 12. Validation (acceptance gates of `wb-improve-v2.md` §3)
2,000 seeded AI matches per row (seeds 1…2000, seats alternate), the engine's own AI (`WD.aiTurn`): it plays Tactics (Jury-Rig after its best card, Follow Through draws played at once, Sweeps arranged with the most Hit Markers on top, held angles avoided when moving), takes Spoils (main-squad lean when combo-aware), and promotes starters with the Intel left after buying. "Before" is the v6 engine as of commit `dc9fdbe` (`git show dc9fdbe:projects/warbuilder/source/project-warbuilder/src/engine.js`) through the same tool; its build edge comes from `ai_sim_v2.js` (that engine has no random-buyer mode), same seeds.

| Gate | Target | Before (v6) | After (v7) | Met |
|---|---|---|---|---|
| Build edge: aware AI vs random buyer | ≥ 85% | 85.6% | **89.5%** | Yes |
| Synergy edge: combo-aware vs combo-blind AI | ≥ 55% | 59.2% | **63.5%** | Yes |
| Rounds per match (aware mirror) | 8–9 | 8.64 | **8.46** | Yes |
| Matches that reach the final circle | ≥ 50% | 66% | **55%** | Yes |
| Your own cards in hand, round 6 | ≥ 0.45 | 0.34 | **0.46** | Yes |
| Your own cards in hand, round 8 | (≥ 0.50 wanted) | 0.43 | **0.61** | Yes |
| Win rate by main squad (aware mirror) | each 45–60% | Assault 44.8%, Engineer 57.9%, Recon 48.7%, Support 52.7% | Assault 51.4%, Engineer 47.6%, Recon 49.5%, Support 49.4% | Yes (before: No) |
| Cards gained per match | (more building) | 7.3 | 12.2 (Spoils 4.4, promotions 1.4) | |
| Starters left at the end | (visible change) | 7.2 | 5.8 | |
| Damage per turn, rounds 2 / 4 / 6 / 8 | (a curve you can feel) | 1.1 / 2.2 / 4.8 / 8.0 | 0.5 / 3.2 / 8.7 / 14.1 | |
| Hit rate of the shots the AI takes | head's 60–70% | 87% | 93.5% | No (both) |
| Errors, stuck matches | 0 | 0 | 0 | Yes |

Tactic plays per match (both players, mirror): Fortify 0.67, Follow Through 0.64, Expose 0.59, Charge 0.51, Field Medic 0.50, Intel Sweep 0.35, Jury-Rig 0.23, Sentry Turret 0.11, Suppressing Barrage 0.07, Adrenaline 0.07, Contraband Run 0.04, Hold the Angle 0.03 (tier III cards arrive late).

**Notes.**
- **Pacing:** Health 60 alone was not enough (7.7 rounds, final circle 27%): the package adds about 5 cards per player. The trim that brought it back: every gun step +1 Hit Marker, Support's 4 cheapest extra shots removed, and Field Promotion uses a buy. Raising Promotion to 2 Intel also worked (8.65 rounds) but dropped own cards in hand at round 6 to 0.44.
- **Skill:** Spoils and Promotion help a combo-blind player too (the design doc measured 51% for O2 + O3). Two rules keep combos worth playing: the first Spoils card is from your main squad, and the combo-aware AI promotes into the basic that fits its deck.
- **Balance:** losing Heartbeat Sensor, Thermal Optic and Headhunter took Recon to 33–36%; Recon now hits harder (Rally and three Squad lines give *hits +1 damage*) and is at 49.5%. Engineer lost value when promotions started to cost a buy; Dead Drop's Squad line is now +1 Buy (47.6%, the smallest sample: 269 of 4,000 players).
- **Not met, as before:** the shots the AI chooses to take hit 93.5% of the time (87% before). The AI waits for good odds; the planner's shown odds on a typical first shot are lower. Lowering this needs a separate decision (it was open in `engine-synergy-spec.md` §8 too).
- **Early rounds:** damage in round 2 dropped (1.1 → 0.5) because of the gun trim; from round 4 the curve is steeper than before. Watch this in the human playtest.
- **Not measurable by the sim:** whether a buy changes how you play (the 3-person playtest gate) and how the new readouts feel.

**Reproduce** (from the repo root):
```bash
node projects/warbuilder/qa/tools/ai_sim_pkg.js 2000                       # the gate table (after); add --engine=<old engine.js> for before
node projects/warbuilder/qa/tools/smoke_pkg.js                             # 2 full matches in the built page (phone + desktop) + staged screens
cd projects/warbuilder/source/project-warbuilder && npm test && npm run build
```

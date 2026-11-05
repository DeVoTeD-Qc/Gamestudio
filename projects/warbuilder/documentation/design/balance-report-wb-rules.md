# Warbuilder: balance report for the Engine & Synergy rules (wb-rules)

*Mechanics Developer · 2026-11-05 · Board task `wb-rules` · Spec: `engine-synergy-spec.md` (approved) with the head's answers S1–S4.*
*Measured on the **shipped engine** (`source/project-warbuilder/src/engine.js`), not the prototype. Simulator: `qa/tools/ai_sim.js` (rewritten for these rules). Seeds 1…N, seats alternate every game.*

## 1. Verdict against the targets

| Target | Before (game as it was) | After (wb-rules) | Met? |
|---|---|---|---|
| Combo-aware AI beats combo-blind AI ≥ 55% | 51.3% (normal AI vs "nosyn" AI, 2,000 games) | **59.0%** (4,000 games; 95% CI about 57.5–60.5) | **Yes** |
| Firepower rises round over round | not measured (no readout) | **8.2 → 9.6 → 11.5 → 12.9 → 14.5 → 16.9 → 19.3 → 20.9 → 21.0** (rounds 1–9, combo-aware) | **Yes** through round 8; plateau at about 21 in the final circle (rounds 9–11) |
| First player wins 45–55% | 50.5% | **48.8%** (aware vs blind), **49.3%** (aware mirror) | Yes |
| Every gun class 42–58% | knife 33%, sniper 64% (out) | **43–57%** in the mirror (LMG 45, AR 57, launcher 57); **43–54%** aware vs blind | Yes |
| Final circle reached in ≥ 50% of matches | 0% (the drift map never closed fully) | **74.5%** (aware vs blind), **69.0%** (mirror) | Yes |
| Gas + storm 10–20% of all damage | 0.7% | **13.0%** (aware vs blind), **11.4%** (mirror) | Yes |
| Hit rate on shots taken 60–70% (head) | 82.5% | **84.8%** (82.2% without the knife); mirror 86.2% (83.9%) | **No** (see §4) |
| Match length | 9.4 rounds, max 16 | **8.9 rounds** (mirror 8.7), max 11 (hard end); 77% KO, 23% storm, 0.1% hard end | Yes |
| Each squad as main squad 45–60% vs combo-blind | n/a | **Forced one-squad decks:** Assault 48.4%, Recon 53.1%, Support 49.2%, Engineer 55.8%. **Natural main squad:** Assault 55%, Recon 61%, Support 58%, **Engineer 71% (n=256)** | Forced: yes. Natural: Engineer and Recon above 60 (see §5) |
| Mono-squad decks at least as good as 2/3 decks | lean beat pure (spec: pure Assault 41%, Support 40%) | **Mono (85%+ one squad) 58% vs lean (60–85%) 59%** vs blind; mirror **50% vs 49%** | Yes (equal within noise) |

## 2. Runs (4,000 games each unless noted)

| Run | Combo-aware win | First player | Rounds (max) | End: KO / storm / hard end | Final circle | Gas share | Hit rate (excl. knife) | Squad triggers / Rallies per turn |
|---|---|---|---|---|---|---|---|---|
| **Aware vs blind** | **59.0%** | 48.8% | 8.88 (11) | 76.5% / 23.3% / 0.1% | 74.5% | 13.0% | 84.8% (82.2%) | 0.97 / 0.09 |
| Aware mirror | 51.7% (seat A) | 49.3% | 8.71 (11) | 79.2% / 20.6% / 0.0% | 69.0% | 11.4% | 86.2% (83.9%) | 1.43 / 0.15 |
| Blind mirror | 51.2% (seat A) | 49.8% | 9.09 (11) | 74.3% / 25.5% / 0.2% | 80.5% | 15.2% | 83.0% (80.2%) | 0.46 / 0.03 |
| Control: Squad + Rally off (`--flat`) | 42.9% | 50.1% | 9.55 (11) | 63.9% / 34.6% / 1.5% | 91.4% | 21.9% | 82.6% (79.5%) | 0 / 0 |
| Forced Assault (2,000) | 48.4% | | | | | | 85.0% | |
| Forced Recon (2,000) | 53.1% | | | | | | 85.7% | |
| Forced Support (2,000) | 49.2% | | | | | | 83.9% | |
| Forced Engineer (2,000) | 55.8% | | | | | | 84.2% | |
| *Before: shipped game (`ai_sim.js` v1, 2,000)* | *51.3% (normal vs nosyn)* | *50.5%* | *9.39 (16)* | *gas never closes* | *0%* | *0.7%* | *82.5%* | — |

- **Synergy is what wins.** With Squad and Rally switched off, the combo-aware AI (which still buys for squads) drops to 42.9%. With them on: 59.0%.
- **Firepower curve** (combo-aware vs combo-blind, per player turn): r1 8.2 / 8.3 · r2 9.6 / 9.5 · r3 11.5 / 10.7 · r4 12.9 / 11.5 · r5 14.5 / 12.8 · r6 16.9 / 14.0 · r7 19.3 / 15.4 · r8 20.9 / 16.9 · r9 21.0 / 16.7 · r10 20.1 / 16.1 · r11 20.9 / 15.3. Squad triggers per turn climb 0 → 3.8 by round 9. Rounds 10–11 are only the slowest matches (survivor bias), so the curve is quoted for rounds 1–9, as in the spec.
- **Gun classes** (win rate by gun held at the end), mirror: AR 57, Burst 53, DMR 50, Knife 49, Launcher 57, LMG 45, Pistol 52, Magnum 49, Breacher 48, SMG 49, Longbow 51. Aware vs blind: 54, 54, 44, 52, 53, 43, 51, 53, 51, 47, 53.

## 3. What changed (rules as implemented)

**From the spec, as written:** four squads with count-based **Squad** lines (×3 cap, Loadout counts, order-free: lines top up as partners arrive); **Loadout** row (2 slots; replace a slot or use once); keywords Mark, Pierce, Steady, Scrap, Reaction, +1 Buy, "hits +1 damage"; **Hot Drop** (rounds 1–3); **2 buys per turn**; **Buy Station** = one basic per squad (6 copies) + Scrap-a-Sprint service (1 Intel, once per turn); **fixed 7-location row**, 3-deep face-up stacks with a fresh card on top each round (2 in 3 of the location's squad); closing after rounds 2, 4, 5, 6, 7, 8 alternating ends, **final circle after round 8**, **hard end after round 11** (most Health wins); **Health 40**; point blank and close quarters (distance 0 ignores cover and Armor); minimum deck 7; K01 Armor Plates, T006 Take Cover, combo boxes, gun combos and perks cut; 4 new Loadout cards.

**Head's answers applied:**
- **S1, "Recoil decreases Precision":** a shot now **spends** Precision: you commit N Precision, the shot reveals N cards, and then the gun's **Recoil costs that much more Precision** (in addition to the commit; previously Recoil only lowered the reveal count of later shots and Precision was never spent). **Steady** became "each shot this turn reveals 1 extra card for free" (under the spend rule, ignoring Recoil was nearly worthless). The AI and the FIRE button use a planner (`WD.suggestCommit`) that splits Precision over the shots left; the **AIM** button lets the player change it, and the odds on FIRE are for the chosen commit.
- **S2:** Health 40, final circle after round 8, hard end (after round 11). The storm escalates **3, 4, 5, 6** (the spec's 2, 3, 4, 5 gave 8.8% gas share in the mirror; 3–6 gives 11.4% and keeps the final circle at 69%).
- **S3:** Squad counts cards only (cards in play + Loadout), not the gun.
- **S4 (mono-squad as a top strategy):** a **Rally** bonus at 3 and 5 cards of one squad in play (once per turn each): Assault 3: hits +1 damage, +2 Precision, Pierce / 5: hits +1 damage, +2 Precision · Recon 3: Mark, +1 Precision / 5: Mark, +3 Precision · Support 3: +2 Precision, +1 extra shot, Steady / 5: +3 Precision, +1 extra shot, Steady ×2 · Engineer 3: +1 Intel / 5: Draw 1. The four Buy Station basics got a small Squad line (+1 Precision; Dead Drop +1 Intel), so a deck that fills up on its squad's basic still grows. The combo-aware AI leans harder into its main squad.

**Retuning beyond the spec (all needed for the spend rule):**
- Cards: Spare Rounds +2 Precision, +1 extra shot, 1 HM; Support Precision raised (Ammo Box Squad +3 Prec; Suppressing Fire Squad +2 Prec, +1 Armor; Bandolier +2 Prec; Steady Grip +3 Prec; Resupply Squad Steady, +2 Prec; Covering Fire Squad +2 Prec, Steady, +1 Armor; Munitions Drop +4 Prec / Squad +2 Prec; Field Pack Ready +1 Prec, +1 shot, Steady). Assault: Tac Vest Ready +2 Prec, hits +1; Slide Cancel Squad Draw 1, +2 Prec; Breaching Charge Squad hits +1, +1 shot, Steady. **Engineer toned down:** Black Market loses +1 Buy and 1 Intel (+2 Prec, +3 Intel, Draw 1); Bounty Contract Ready +1 Intel, +1 Prec; Scrounge Squad +2 Intel; Salvage Squad +2 Intel, +1 Buy; Munitions Box, Field Kit, Field Workshop Squad lines −1 Precision.
- Guns (multi-shot guns lost Recoil, big single shots lost damage): Viper SMG first step 2 HM, Recoil 0 · Breacher first step 2 HM (no +1 damage) · Bastion LMG 3 damage, ladder 3→3 / 6→5, Recoil 0 · Sentinel AR Recoil 1 · Ranger DMR Recoil 1 · Raider Burst Recoil 0 · Combat Knife 3 damage, 1 stab · Magnum 3→4 / 6→7 · Sapper 3→4 / 6→7 · Longbow 3→4 / 8→8. The ladder +1 (spec M2) is **off** (`needPlus 0`): the spend rule already makes shots costlier.

## 4. Shot odds: still not 60–70%
Taken shots hit **84.8%** (82.2% without the knife, which always hits). The head's rule did not move it, because a player who can choose how much Precision to commit (and when to shoot) commits enough to make the shot near-certain whenever Precision allows; the planner splits Precision across shots only when it is scarce. The spend rule did make Precision a real budget (FIRE now shows "−N Prec", and big turns plan 2–3 shots), but the odds of the shots that are taken stay high.
- In the prototype with this package (`ai_sim_syn.js 4000 --rules`), adding **Dodge** (the target flips their top card; its Hit Markers raise the need) brought **ranged shots to 59%** (all shots 75.5%, combo-aware edge 54.4%). Dodge also at close quarters brought ranged 59% and close quarters 66%, **all shots 66%** (edge 53.2%). Dodge is the only lever tested that reaches the band, and it costs 4–6 points of synergy edge (the prototype's absolute edge runs about 3 points below the shipped engine's). It is not in the game (see the questions for the head).
- Human players will take riskier shots than this AI, so the realised rate in playtests will be lower.

## 5. Squads as the main squad
- **Forced one-squad decks** (the aware AI may buy only that squad's cards) all land in 45–60%: Assault 48.4, Recon 53.1, Support 49.2, Engineer 55.8. In the spec's prototype pure Assault and Support won 41% and 40%.
- **Natural main squad** (whatever the aware AI ended up with): Assault 55%, Support 58%, Recon 61%, **Engineer 71%** (n=256, 6% of decks). Two extra Engineer nerfs (Deployable Cover Squad +1 Intel; Black Market Squad without Intel) moved it only to 68%, because this is mostly a selection effect: the Engineer-heavy decks are the ones that bought many guns and cards early. The mirror shows Engineer at 60% and the others at 47–50%. Recon 61% (n=871) is just above the band.
- **Mono vs lean:** aware decks with 85%+ of one squad win 58% vs blind (lean 60–85%: 59%); in the mirror 50% vs 49%. Mono is now a top strategy (in the prototype it was clearly worse).

## 6. Reproduce
From the repo root (each 4,000-game run takes about 15 s):
```bash
node projects/warbuilder/qa/tools/ai_sim.js 4000 --match=aware-blind --curve   # main result + Firepower curve
node projects/warbuilder/qa/tools/ai_sim.js 4000 --match=aware-aware --curve   # mirror: first player, guns
node projects/warbuilder/qa/tools/ai_sim.js 4000 --match=aware-blind --flat    # control: Squad and Rally off
node projects/warbuilder/qa/tools/ai_sim.js 2000 --match=aware-blind --force=support   # one-squad deck
cd projects/warbuilder/source/project-warbuilder && npm test && npm run sim     # 61 tests; balance bands (aware mirror)
NODE_PATH=$(npm root -g) node projects/warbuilder/qa/tools/smoke_rules.js 6     # Playwright smoke test + screenshots
```
The "before" column used the previous `ai_sim.js` against the previous engine (2,000 games; `nosyn` = combo-blind player 1).

## 7. Known gaps
- The 4 Loadout cards have no art yet: the web build shows their squad's sample art (Breach, Mark Target, Ammo Box, Deployable Cover) until the art pass.
- The UI additions are minimal (Firepower readout with ▲ vs last turn and sparkline, squad counters, Loadout row, Squad lines on cards with ×N, AIM sheet, gas schedule chips, rules text); the UI/UX agent will polish them. On phone landscape the Firepower readout and squad counters sit under the gun card.
- Supply crates (rounds 2 and 4, tier III on the middle stack) are kept from the old game; the prototype did not model them.

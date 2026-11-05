# Warbuilder: Push-Your-Luck FIRE (design + simulator proof)

*Sr Game Designer · 2026-11-05 · Board task `wb-pyl` · Status: **proposal, proven in the simulator, not in the game yet***
*Inputs: the head's question ("should we use a push-your-luck mechanic for shooting with those card reveals and hit markers?"), `engine-synergy-spec.md` §8 and §12, `balance-report-wb-rules.md` §4, `source/project-warbuilder/src/engine.js` (read only).*
*Simulator: `qa/tools/ai_sim_pyl.js` (new). It runs the **shipped engine** for everything except the shot. `ai_sim.js`, `ai_sim_syn.js` and `source/` are unchanged.*

## 1. Answer
**Yes.** A flip-and-stop FIRE fixes the hit-rate problem. Taken shots hit **68%** (today 85% in the same harness), and the combo-aware edge holds at **57%**. It also replaces the AIM planner sheet with one tap per flip and fewer than one decision per shot. Every other target is met.

Why it works: today a shot's odds are known before you commit, so a sensible player only takes near-certain shots (`balance-report-wb-rules.md` §4). Here the risk is in the flip itself, so it can't be planned away. Precision still decides how far you can push, so the engine you build is still the gun you fire.

## 2. Rules (as the player reads them)
> **FIRE.** Flip cards off the top of your deck one at a time. Each flip costs 1 Precision. Add up the Hit Markers.
> When your total reaches a step on your gun's ladder, you may **STOP** and deal that step's damage, or flip on for the next step.
> A card with the **Jam** icon (Sprint, Scout) is a Jam. It costs your gun's Recoil in Precision, and your **second Jam** in one shot is a miss. **In the final circle, your first Jam is a miss.**
> If you run out of Precision before the first step, you miss. **Steady:** cancel a Jam. **Mark:** your next shot needs 1 fewer Hit Marker on every step.

- The top step banks automatically, so a 3-step gun asks at most **2** stop-or-push questions. On average a shot asks 0.7.
- Flipped cards go to your discard pile, as revealed cards do today. If your deck runs out mid-shot, shuffle your discard pile in (the cards from this shot stay out).
- The knife flips like any gun (1 stab: 2 Hit Markers for 4 damage, 4 for 7).
- Deck progression you can see: your starter deck is 60% Jams. Scrapping Sprints and Scouts, and buying cards, brings it to about 25% by round 9. The deck pile shows it ("Jams 4/17").

## 3. Variants compared (4,000 seeded games per row; combo-aware vs combo-blind unless noted)
The three variants share the rule above. They differ only in **where the bust line sits**.
- **V1 Two Jams:** the 2nd Jam always misses.
- **V2 Hot Zone (recommended):** V1, but in the final circle the 1st Jam misses.
- **V3 One Jam:** the 1st Jam always misses.

| Target | Shipped today (same harness) | V1 Two Jams | **V2 Hot Zone** | V3 One Jam |
|---|---|---|---|---|
| Hit rate on shots taken, 60–70% | 85.4% | 70.3% (edge) | **68.2%** | 58.4% (fails) |
| ... excluding the knife | 85.4% | 69.7% | **67.7%** | 57.8% |
| Combo-aware vs blind, ≥ 55% | 60.3% | 57.6% | **57.1%** (95% CI ±1.5) | 54.5% (fails) |
| Same, Squad and Rally off (control) | (42.9%, report) | 42.9% | **43.6%** | — |
| First player, 45–55% | 48.5% | 50.1% | **49.4%** (mirror 49.3%) | 49.5% |
| Gun classes, 42–58% (aware vs blind / mirror) | 46–54% | 44–56 / 45–54% | **42–57 / 45–53%** | 43–55 / 43–61% (fails) |
| Gas + storm share of damage, 10–20% | 12.0% | 11.4% | **13.0%** | 18.0% |
| Match length, ≤ ~9 rounds (max) | 8.82 (11) | 8.77 (11) | **8.85 (11)** | 9.29 (11) |
| Hard ends / final circle reached | 0.03% / 74% | 0.1% / 70% | **0.4% / 71%** | 0.9% / 85% |
| Cards turned per turn (all turns / turns with a shot) | 3.9 / 6.0 (reveals) | 2.9 / 3.8 | **2.8 / 3.7** | 2.4 / — |
| Decisions per shot | 0 (+ AIM sheet) | 0.72 | **0.70** | 0.59 |
| Miss causes: bust / ran out of Precision | — | 13.6% / 16.1% | **16.6% / 15.1%** | 37.1% / 4.5% |
| Pushes at a decision / pushes that pay off | — | 44% / 66% | **42% / 66%** | 35% / — |

**V2's Firepower still rises round over round** (combo-aware, per player turn; blind in brackets):

| Round | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| Firepower | 8.2 (8.3) | 9.4 (9.3) | 11.2 (10.5) | 12.4 (11.2) | 14.7 (12.8) | 16.6 (13.9) | 19.2 (15.2) | 20.3 (16.6) | 21.6 (16.7) |
| Damage dealt | 0.4 | 1.3 | 1.8 | 1.7 | 3.1 | 4.5 | 6.3 | 8.0 | 6.9 |
| Hit rate of shots | 76% | 72% | 65% | 57% | 65% | 70% | 75% | 79% | **63%** (final circle) |
| Jams in deck | 60% | 55% | 49% | 43% | 38% | 34% | 30% | 28% | 25% |

**Why V2 over V1:** as decks thin, V1's shots get safer just as the circle closes (79–83% from round 8 on). The gamble fades at the climax. Hot Zone puts the nerve back into the showdown (63–68% in rounds 9–11) for one clause of rules text. It costs 0.5 points of combo edge and adds 0.08 rounds. V1 is the fallback if the head wants the shortest rules.

### 3.1 AI stop policy (both AIs; "push when the chance the push fails is at most X")
| Policy | V2 hit rate | V2 combo edge | Push rate / success | V1 hit rate |
|---|---|---|---|---|
| Cautious (≤ 20%) | 69.7% | 56.8% | 32% / 71% | 71.6% |
| **Normal (≤ 35%)** | **68.2%** | **57.1%** | 42% / 66% | 70.3% |
| Bold (≤ 50%) | 66.1% | 57.7% | 52% / 59% | 68.8% |
| Expected damage (push when it raises EV) | 68.6% | 57.5% | 42% / 67% | 70.5% |

The policy moves the hit rate by only about 4 points, because two-thirds of misses happen **before the first step** (a Jam pair or running out of Precision). The stop decision adds the rest. So the hit rate is set by the deck, not by how timid the player is, and that is the structural fix. Bold play pays slightly (57.7%), as it should in a nerve game. The AI fires whenever reaching step 1 is at least 5% likely, because a miss costs only the flips.

### 3.2 Other things tested (V1 base unless noted)
| Test | Result | Verdict |
|---|---|---|
| "A card with no Hit Markers is a Jam" (no icon) | Identical to V1 (the 0-HM cards are exactly Sprint and Scout) | Same rule. The icon is only for readability (Q2) |
| Recon Run also has a Jam (8 of 10 starters) | Hits 64.5%, edge 55.6%, 9.18 rounds, gas 16%, Sapper 38% in the mirror | Knob if humans hit too often |
| Jams on the 4 Buy Station basics | Edge collapsed to 51% (buying made your deck worse) | Rejected |
| Jams on tier III cards | No change (59.5%, 70.4%): few decks hold them | Not needed |
| Steady = 1 free flip (instead of cancel a Jam) | 68.4% hits, edge 56.5% | Cancel is clearer and better |
| Recon "Scope: peek the top card once" (Rally 3) | No measurable effect | Cut; Mark already serves Recon |
| Jams cost no Recoil | 71.6% hits, guns 38–60% | Keep Recoil as the Jam cost (head's S1) |
| "Free flips": Jams eat Recoil+1 Precision, miss when you can't pay | 6.95 rounds, edge 50.9%, final circle 11% | Rejected: Precision became pure safety |
| 2-step ladders (today's) | Hits ~79%, gas 22–28%, 9.5+ rounds | Too little reason to push; 3 steps needed |

## 4. Card and gun changes needed
**Cards:** a Jam icon on **Sprint ×3 and Scout ×3** (starters). No loot card text changes.
**Keyword:** Steady now reads "Cancel the next Jam you flip this turn (stacks)". It was "+1 free card per shot". The cards that carry Steady are unchanged.
**Removed:** the AIM sheet and the commit planner (`suggestCommit`). The ladder +1 stays off.
**Guns:** every class gets a 3-step ladder (Hit Markers → damage; Common rarity). Rarity mods apply as today (Red Dot: every step −1 Hit Marker; Hollow Points: +1 damage).

| Gun | Shots | Recoil | Ladder (new) | Today |
|---|---|---|---|---|
| Sidearm (pistol) | 2 | 2 | 2→2 · 4→4 · 6→5 | 2→2 · 4→3 |
| Magnum | 1 | **3→1** | 2→4 · 5→7 · 7→10 | 3→4 · 6→7 |
| Combat Knife | 1 | 0 | 2→4 · 4→7 (flips now) | auto-hit 3 |
| Viper (SMG) | 2 | 0 | 2→3 · 4→4 · 6→6 | 2→2 · 5→4 |
| Breacher | 1 | **3→2** | 2→4 · 4→6 · 6→9 | 2→3 · 6→6 |
| Raider (burst) | 2 | 0 | 2→3 · 5→4 · 8→6 | 2→2 · 6→4 |
| Sapper (launcher) | 1 | **3→2** | 3→4 · 5→8 · 7→11 | 3→4 · 6→7 |
| Sentinel (AR) | 2 | 1 | 3→4 · 5→6 · 7→8 | 3→3 · 5→5 |
| Bastion (LMG) | 3 | 0 | 3→3 · 5→6 · 7→9 | 3→3 · 6→5 |
| Ranger (DMR) | 2 | 1 | 3→4 · 5→7 · 7→10 | 3→3 · 7→6 |
| Longbow | 1 | **2→1** | 3→4 · 6→9 · 9→13 | 3→4 · 8→8 |

Single-shot guns get bigger top steps and lower Recoil. With one shot per turn, one Jam must not end the turn's damage. Steps 2–3 are worth about 2–3× step 1, because that is the prize worth pushing for.

## 5. Squad hooks: synergy feeds the gamble
- **Precision = flips.** Every squad card still gives Precision, so a formed engine (20 Precision) can push deep twice a turn. A thin one runs dry: 15% of shots miss that way, mostly early. With Squad and Rally off, the combo-aware AI wins only 43.6%.
- **Support (Steady):** cancels Jams, so it is the safe-push squad.
- **Recon (Mark):** lowers every step, so you need fewer flips and face less Jam exposure.
- **Assault ("hits +1 damage"):** makes every banked step bigger, so stopping early still pays.
- **Engineer (Scrap, Intel, + Buy):** thins Jams out fastest.
- Known carry-over: Engineer as the natural main squad wins 73% here too. This is the selection effect described in `balance-report-wb-rules.md` §5, and the flip rule doesn't change it.

## 6. UI sketch: the flip moment (for ui-ux-agent)
```
 ┌─ SAPPER ──────────── Precision 11 ──── Jams ▣ □  (final circle: ▣) ─┐
 │  Hit Markers  ■■■■■□□                                                │
 │  Ladder       [3 → 4]  ✔   [5 → 8]  ◀ next   [7 → 11]                │
 │  Flipped:  [Focus 2] [Sprint ⚠JAM −2 Prec] [Breach 2]                │
 │  Next flip:  Jam 3 in 14 cards (21%)  ·  reach 8 dmg: 64%            │
 │        [ STOP · deal 4 ]                    [ FLIP ▶ 1 Precision ]   │
 └───────────────────────────────────────────────────────────────────────┘
```
- **FIRE** shows "step 1: 78% · Jams 3/14" (the nerve moment stays on the button).
- **One tap per flip.** Before step 1 there is no choice, so the UI can auto-flip at about 350 ms per card, with tap to hurry (Q3).
- The card flies from the deck to a flip row. Its Hit Markers fill the meter. A Jam slams a red ⚠ into a Jam slot with a gun-kick shake, and "−Recoil" ticks the Precision down.
- **Reaching a step:** the step lights up, a chime plays, and STOP pulses with its damage. **Bust:** "JAMMED", the flip row greys out, and the cards slide to the discard pile.
- **Hot Zone:** in the final circle, the Jam bar shows a single slot in storm colour, and the button reads "First Jam misses".
- Deck pile badge: **"Jams 4/17"** next to the Aim rating. It drops visibly each time you scrap a Sprint (the progression the head wants to see).
- Log line: "Rival fires Sapper: 2 · JAM · 2 · 3 → stops at step 2 for 8."

## 7. Print-and-play note
- **No new cards.** Mark the 6 Sprint and Scout cards with a Jam sticker or stamp (or play "no Hit Markers = Jam", which gives identical results).
- Reprint the gun ladders (30 gun cards, or a one-page ladder overlay). Add two Jam boxes to the gun card, and a "Final circle: first Jam misses" line on the storm card.
- Track Precision on the existing token track: −1 per flip, −Recoil per Jam. A shot is about 2–4 flips, and the shot is resolved at the table as it happens, with no maths before the shot.

## 8. Implementation notes (mechanics-developer, after approval)
| Item | Work |
|---|---|
| `fire` becomes a two-action shot: `fireStart(s,p,gi)`, then `flip(s,p)` / `stop(s,p)` with `s.shot = {gi, flipped, sum, jams, steps}`. The bank, the bust and running out of Precision resolve inside `flip`. Reuse `applyHit` and `checkDeath`. | M |
| `jam: true` on T001/T002 (or a "0 HM = Jam" rule); Steady (`revealPlus`) is consumed per Jam; `nextFire.reqMod` as today; Hot Zone checks `safeBounds(s).n <= 1` | S |
| `GUNCLASS` ladders and Recoil per §4; drop `suggestCommit`, the AIM sheet and the `aim: 'spend'` path | S |
| AI: port `pReach` and the Normal policy from `ai_sim_pyl.js` (fire when P(step 1) ≥ 5%; push when the push fails ≤ 35% of the time) | S |
| UI per §6; tests: hit rate 60–70%, combo edge ≥ 55%, gun classes 42–58%, first player 45–55% as balance bands | M |

## 9. Reproduce
From the repo root (each 4,000-game run takes about 20 s):
```bash
node projects/warbuilder/qa/tools/ai_sim_pyl.js 4000 --variant=hotzone --curve                 # V2 (recommended)
node projects/warbuilder/qa/tools/ai_sim_pyl.js 4000 --variant=hotzone --match=aware-aware      # mirror: first player, guns
node projects/warbuilder/qa/tools/ai_sim_pyl.js 4000 --variant=hotzone --flat                   # control: Squad and Rally off
node projects/warbuilder/qa/tools/ai_sim_pyl.js 4000 --variant=hotzone --policy=bold            # cautious | normal | bold | ev
node projects/warbuilder/qa/tools/ai_sim_pyl.js 4000                                            # V1 Two Jams;  --variant=onejam for V3
node projects/warbuilder/qa/tools/ai_sim_pyl.js 4000 --shipped                                  # today's FIRE in the same harness
node projects/warbuilder/qa/tools/ai_sim_pyl.js 4000 --set=jamSet:T001+T002+T005                # knob: Recon Run jams too
```
**Limits:** it is the engine's AI, not a person. The engine's buy and scrap AI does not know about Jams; a Jam-aware AI would scrap Scouts sooner and likely widen the combo edge. The "out of Precision" misses would fall with a human who holds a shot until Precision is enough. Supply crates and Reactions run as in the engine. Card-count invariants are checked in every game (0 failures, 0 errors).

## 10. Questions for the head
1. **Q1. Where is the bust line?** (a) **Hot Zone (V2):** 2nd Jam misses, 1st Jam misses in the final circle (68%, edge 57%; recommended). (b) Two Jams always (V1): simplest text, 70%, but final-circle shots hit about 80%. (c) One Jam always (V3): 58%, and the combo edge falls to 54.5% (fails).
2. **Q2. How is a Jam marked?** (a) **A Jam icon on Sprint and Scout** (visible, teaches "scrap your starters"; recommended). (b) A rule, "a card with no Hit Markers is a Jam" (no reprint, identical results). (c) Also put a Jam on Recon Run (64.5% hits, the centre of the band, but edge 55.6% and 9.2-round matches) if playtests show humans hitting too often.
3. **Q3. How many taps?** (a) **Auto-flip to the first step, then one tap per flip** (about 1–2 taps per shot; recommended). (b) Every flip is a tap (about 2.5 taps per shot, 3.7 per shooting turn; the most tension). (c) A settings toggle between the two.

## 11. Ideas to explore (not built; head's brainstorm, 2026-11-05)
*Added by mechanics-developer with the implementation (`wb-pyl-impl`). The head chose the Firefight bust from `bust-variants.md` (pot, turn Jam limit 2 + 1 per Rally, no final-circle change), so these notes assume Firefight.*

- **Risk/reward cards.** A stronger card that carries a Jam: the best squad cards (tier III) get a Jam icon, so a big engine card is also a liability when it is flipped in a shot. Variant: the Jam card also adds damage ("Hit Markers + a damage bonus", for example "+1 damage this turn" on its play line), so drawing it is great and flipping it is dangerous.
- **Quick estimate in the real engine** (4,000 games, combo-aware vs blind; `ai_sim.js` with the card table edited in memory): tier III cards with a Jam: edge 61.2%, 9.00 rounds, hit rate 71.9%, gas 14.3%, wiped turns 4.4%. With +1 damage as well: edge 60.7%, same pace. Shipped Firefight for comparison: 60.4%, 8.98 rounds, 71.9%, 14.0%, 4.3%. **No measurable effect**, because few decks hold tier III cards before the match ends. The frozen-engine test in `bust-variants.md` §3.2 ("Hot cards") reached the same verdict and found longer matches when tier II cards carry Jams too.
- **To make it matter**, the Jam would have to sit on cards that decks really hold (tier I–II squad cards or the Buy Station basics). That makes buying worse, and `push-your-luck-shooting.md` §3.2 rejected it ("Jams on the 4 Buy Station basics": edge collapsed to 51%). A cleaner hook is bust-variants C (Hot Hand: +1 damage per Jam you survive), which pays off the Jam itself rather than a card.

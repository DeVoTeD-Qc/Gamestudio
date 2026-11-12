# DeadDraw - Economy v5 (points you can read, runs that diverge)

Owner: Sr Game Designer | Board task: `dd-economy` | Engine: Godot 4.4.1 (GDScript), Web export
Input: the 5-player playtest (Fun 7.0, best of three). Builds on `core-rules-v4.md` (section 13 as built) and keeps the text pass of commit 7730518 (rule notation, refusal toasts, Run).
Balance source of truth: `tools/sim_deaddraw_v4.py` (new v5 keys at the end of `CONFIG`; `--preset v4` turns them all off and reproduces v4 exactly).

## What players told us

| # | Finding | Who |
|---|---|---|
| a | Points do three jobs (score, rooms, safehouse shop) and drop to 0 when you leave the safehouse, which surprised people. Opening the Garage for 210, then its Wall Rack wanting another 150, feels bad. | p1, p2, p3, p5 |
| b | Runs don't diverge much between districts; no build-defining items (Theo: "gun mods that rewrite socket rules"). A full kill stack has no "STREAK!" moment (Jordan). | p2, p3 |
| c | A First Aid Kit at full HP heals 0 with no warning. "BOSS 9" reads as strength or a countdown. | p4 |

## The rules and screens in v5

**E1. Score and points are two numbers on screen.** The rule was already right (the run score counts every point earned, and spending never lowers it), but only the end screen showed the score. The PTS chip now shows the points you can spend, with `score 640` under them. Its tooltip says: points are for this district, unspent points stay behind at the safehouse, and the score keeps everything.

**E2. Every door shows what is inside and what that costs.** Each closed room's plate shows `+150 to use` under its price: the Wall Rack's gun, the next Patch, or the cheapest Bench job. The tooltip gives the total (`Door + one use: 360`). If you tap OPEN with enough for the door but not for the machine, a short sheet asks first: *"The Wall Rack costs 150 per gun. After opening you'll have 0: not enough to use it this wave. Door + one use: 360."* Choose **OPEN FOR 210** or **NOT YET**. If you can afford both, the door opens at once, as before.
*Rejected: a free first use on opening.* In the sim it was far too strong: all three machines free gave 85-88% wins, and the Wall Rack alone free gave 59% (the gun keeps paying for the rest of the district). Pricing it in would mean retuning every room. The confirm sheet removes the bad surprise and doesn't change the balance.

**E3. The safehouse says what happens to points.** The shop line reads *"Spend here: 1 Patch, or HP at 30 pts each. Points don't come with you; your score keeps them."* The Leave button reads `LEAVE - 40 pts stay here (score keeps them)`. The rule is unchanged: carrying points over made every door open at once in the next district (the head's v4 point 15). The leftovers now have a third use (E4), so fewer are lost.

**E4. Gun Mods (one new source of run variety).** The safehouse is now three short steps: the free boss Patch, then a **Gun Mod**, then the shop. You see **2 of 4** mods and fit **1** to gun slot 1 or 2 for **50 pts**, or SKIP. A mod belongs to the **slot**, not the gun, so it stays for the rest of the run (guns come and go every few streets). One mod per slot; a new one replaces the old. Each mod is a card you can inspect; the gun tile shows a `MOD · LAST ROUND` chip with its own tooltip, and the "next kill" socket and the refusal toasts include the mod.

| Gun Mod | Rule (every gun in that slot) | Kind |
|---|---|---|
| **Open Breech** | Kills 1 and 2 ignore the gun's rule. | relax |
| **Last Round** | The kill that fills the gun ignores its rule. | relax |
| **Echo Chamber** | A zombie equal to the top kill always fits. | relax |
| **Short Barrel** | The gun holds 1 fewer kill (at least 1): it fills sooner. Fitting it to a gun that is then full finishes that gun at once (bonus + challenge). | rewrite |

Builds diverge on purpose: Short Barrel on the Twin-Bore makes a 2-kill "same number" gun; Last Round rescues a stuck Rifle or Lever Rifle; Echo Chamber turns the Nail Driver into a gun that also takes repeats. Price: **5 sim points (50 on screen)**, the cheapest item at the safehouse, so almost everyone can afford one (1.44 mods fitted per run). Free mods were tested and push win rates 5-9 points up (table below).

**E5. STREAK!** When a kill stack fills, a gold "STREAK!" band crosses the screen (`Service Pistol full · +50`), with a short gold flash and the finale sting. It lasts about 1 s and never takes taps: any tap rebuilds the screen and clears it. With Reduce motion it only fades in and out (no flash, no slam). Shatter finishes (the Groundskeeper) don't trigger it.

**E6. Small fixes.** A medkit tapped at **full HP** (and no Iron Stomach overflow) now asks first: the toast says *"Full HP: this heals 0. Tap again to use it anyway."* A second tap uses it, because spending a resolve on a medkit to avoid a zombie is a real play. The wave card's boss chip now reads **BOSS** plus the boss's strength in the same red badge every zombie wears (Horde `x3`, Patient Zero `->12`), and its tooltip says "strength 9".

## Simulation (1000 runs per survivor, strong AI, seeds 7 / 11 / 23 averaged)

| | **v4 as built** | **v5** (mods at 50) | v5, free mods | v5 + free machine use on opening |
|---|---|---|---|---|
| Run win Rosa / Imani / Theo | **30.7 / 35.8 / 39.4%** | **31.7 / 40.7 / 44.0%** | 35.6 / 44.2 / 46.3% | 83.7 / 89.0 / 90.7% (seed 7) |
| Clear Maple Row / Downtown / St. Agnes (of reached) | 88.5 / 68.1 / 58.4% | 88.6 / 68.2 / 63.9% | 88.5 / 70.6 / 67.1% | 97 / 95 / 95% |
| Points earned per district (on screen) | 1314 / 1771 / 2269 | 1321 / 1827 / 2350 | 1318 / 1836 / 2362 | 1385 / 1909 / 2414 |
| Unspent at district end | 385 / 396 / 655 | 386 / 420 / 692 | 383 / 427 / 698 | |
| Rooms opened per district | 2.09 / 2.47 / 2.83 | 2.10 / 2.49 / 2.87 | 2.10 / 2.52 / 2.89 | |
| Points left behind at safehouses (per run) | 112 | 118 | 119 | |
| Gun Mods fitted / guns finished per run | 0 / 9.0 | 1.44 / 9.6 | 1.51 / 9.8 | |
| Stuck fights / dead-gun streets | 2.6% / 11.7% | 1.8% / 9.0% | 1.7% / 8.9% | |
| Winning run / HP left on a win | 8.6 min / 8.9 | 8.5 min / 9.1 | 8.5 min / 9.6 | |

Reading: v5 moves the head's accepted 31 / 36 / 39% to **32 / 41 / 44%** (+1 / +4.9 / +4.6), inside the ±5 limit, with Imani and Theo at the top of it. All of the change comes from the mods (E1-E3, E5 and E6 are presentation only), and it lands where intended: St. Agnes clears 58% -> 64%, stuck fights drop by a third, dead-gun streets drop from 11.7% to 9.0%, and finished guns (STREAK moments) rise from 9.0 to 9.6 a run. The knob is `mod_price`: at 10 (100 on screen) seed 7 gives 30.3 / 35.8 / 39.2%, the v4 numbers, but fewer players get a mod. Sampling error is about ±3 points per survivor per seed.

```
python3 projects/deaddraw/tools/sim_deaddraw_v4.py --runs 1000 --seed 7                    # v5
python3 projects/deaddraw/tools/sim_deaddraw_v4.py --runs 1000 --seed 7 --preset v4        # before
python3 projects/deaddraw/tools/sim_deaddraw_v4.py --set mod_price=0                       # free mods
python3 projects/deaddraw/tools/sim_deaddraw_v4.py --set room_free_use=true                # rejected E2
```

## Build notes

- CONFIG (sim and `data/balance.json`): `mods_mode` "safehouse", `mod_offer` 2, `mod_price` 5, `mods` [open_breech, last_round, echo, short_barrel]; `room_free_use` false (with `room_free_kinds` and `room_cost_add` kept for re-testing).
- `DDRun`: `legal_mod`, `slot_rule_ok`, `slot_allows` (mod-aware), `can_take_slot`, `slot_mods`, `mod_offer`, `mod_step_open`, `mod_preview`, `fit_mod`, `skip_mod`, `machine_min_price`, `room_total_cost`, `room_machine_short`. Save stays `"v": 4` with the optional keys `slot_mods`, `mod_offer` and `mod_fitted_here` (older saves load with no mods).
- Parity: `tools/v4_parity_cases.py` adds `mod_legal` (400) and `mod_fit` (80) cases, which `tests/test_v4_parity.gd` replays through `DDRun`. New tests: `tests/test_rules_v5.gd` and `tests/test_ui_v5.gd`. Screenshots: `tests/tools/shot_economy.gd`.
- Art follow-up (optional): 4 Gun Mod badges, to replace the text chip and card.

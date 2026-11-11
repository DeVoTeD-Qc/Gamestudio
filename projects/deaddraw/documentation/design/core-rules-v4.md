# DeadDraw - Core Rules v4 ("Kill Stacks", polish pass)

Owner: Sr Game Designer | Board task: `dd-v4-design` | Engine: Godot 4.4.1 (GDScript), Web export
Input: the studio head's full playthrough, `documentation/qa/playtest-head-2026-11-11.md`, points **13-19** (points 1-12 are the UX designer's).
Status: **approved and built** (the head's answers and the as-built Run rule: section 13, board task `dd-v4-impl`). Was: proposal, waiting for the head's answers (section 10).
Balance source of truth for v4: `projects/deaddraw/tools/sim_deaddraw_v4.py` (`CONFIG`, defaults = this proposal). `--preset v3` puts every v4 option back to v3 and reproduces `sim_deaddraw_v3.py` exactly (checked: same seeds, same numbers). If this document and the sim disagree, the sim wins.

> **Naming and IP.** Every name below (Patches, guns, melee weapons, the Safehouse Shop) is original to DeadDraw. No shooter-series trademarks or signature names (upgrade machines, soda perks, gums, mystery boxes, wonder weapons). The repo is public.

---

## TL;DR

| # | Head's point | v4 rule (recommended) | Run win R / I / T, v3 -> v4 alone* |
|---|---|---|---|
| 13 | Swapping a stuck gun loses all its points | **Salvage:** swapping out an unfinished gun pays **+1 per kill on its stack** (+10 on screen each). Finishing still pays +5 and the challenge. | 31.8/38.5/37.5 -> 36.1/42.5/41.4 |
| 14 | More perks | **6 new Patches:** Lockpick, Iron Stomach, Adrenaline, Grudge, Show-Off, Whetstone. All inside the existing Patch band. | (per Patch, 8.6) |
| 15 | Points carry into mission 2, so every room opens at once | **Safehouse Shop:** points don't leave a district. At the safehouse you may buy **1 Patch** at the Press price and **supplies at 3 points per HP**; the rest is lost. Rooms opened before the first street of districts 2-3: **0.85 -> 0**. | 31.8/38.5/37.5 -> 35.9/44.8/40.1 |
| 16 | A big single-target gun | **Stovepipe Launcher** (power 7, **one shot**: capacity 1) and **Alley Sweeper** (power 3, capacity 4, **6 or less** only). | 31.8/38.5/37.5 -> 36.8/45.6/42.0 |
| 17 | Melee too strong upgraded; start with bare hands | **Bare Hands** power 1, unlimited, no points. **Melee weapon cards** in the deck: Pipe Wrench 3 (4 uses), Fire Axe 4 (3 uses), Sledgehammer 6 (2 uses). Still no points. **Brawler** now boosts bare hands only. | 31.8/38.5/37.5 -> 33.2/39.0/37.9 |
| 18 | One medkit per street feels odd | **Removed.** Every medkit heals (up to max HP). The limit only wasted 0.34 medkits a run. | 31.8/38.5/37.5 -> 32.4/38.0/38.8 |
| 19 | Run should return all the cards | **Already the rule and the build:** Run shuffles every card still on the street (zombies, guns, medkits, cover, the Holdover) back into the pile; 3.9 cards per Run, 0.85 of them non-zombies. The fix is presentation (UX), plus one rules sentence. | no change |
| | **All of v4 together** (+ Imani 19 -> 18 HP) | | **34.4 / 42.6 / 40.0%**, 8.4-minute wins |

\* 1000 runs per survivor, seed 7, strong AI, each change alone on top of v3. Sampling error is about +/-3 points per survivor.

**What the player feels:** a stuck gun is now a small payout instead of a loss; each mission starts with doors to earn, and the leftovers buy a Patch or a heal at the safehouse instead of opening the next map for free; there's a rocket for the one big zombie; melee is a hunt for a good tool, not a free crowbar; medkits always work; Run does what it says.

---

## 1. Baseline and how to read the numbers

All numbers: `sim_deaddraw_v4.py`, strong AI (v3's), 1000 runs per survivor unless marked "400" (screening runs, +/-4.5 per survivor). Win-rate band, as in v3: **30-42% per survivor**, survivors within ~8 points of each other.

New metrics (in the sim's output):
- **Stuck fights:** fights where you hold at least one gun but **no gun's rule allows the zombie** (you must melee or use Loose Grip), and the damage those fights cost per run.
- **Dead-gun streets:** streets that start with an equipped gun whose rule allows < 15% of the upcoming zombies (pile + next wave).
- **Points curve:** points earned per district (cleared runs), points left unspent at the end of a district, points you **start** the next district with, and rooms opened before the first street of a district.

### 1.1 v3 vs v4 at a glance (1000 runs per survivor)

| | **v3** (as built) | **v4** (all of this) |
|---|---|---|
| Run win R / I / T | 31.8 / 38.5 / 37.5% | **34.4 / 42.6 / 40.0%** |
| Clear Maple Row / Downtown (reached) / St. Agnes (reached) | 92 / 69 / 56% | 86 / 66 / 69% |
| Winning run / average run | 8.6 / 7.0 min | 8.4 / 6.5 min |
| Streets / taps per street | 34.3 / 4.36 | 33.5 / 4.17 |
| Guns finished / swapped early / challenges | 9.4 / 10.4 / 5.1 | 8.5 / 10.5 / 4.4 |
| Stuck fights (damage a run) | 1.3% (1.9) | 3.2% (4.0) |
| Dead-gun streets | 12.3% | 12.9% |
| Melee kills (with a melee weapon) | 1.9 (-) | 3.5 (3.1) |
| Points earned / spent a run | 402 / 361 | 374 / 332 |
| Points earned per district (Maple / Downtown / St. Agnes) | 131 / 166 / 229 | 134 / 179 / 223 |
| Points you **start** Downtown / St. Agnes with | 39 / 42 | **0 / 0** |
| Rooms opened **before the first street** of Downtown / St. Agnes | 0.83 / 0.88 | **0 / 0** |
| Rooms opened per district | 2.0 / 2.5 / 2.9 | 2.1 / 2.4 / 2.8 |
| HP left on a win | 6.6-7.1 | 9.1-9.3 |

Reading: v4 is about as hard as v3 (a little easier for Imani, see 9.2), a bit shorter, and the difficulty moved: Maple Row is slightly harder (bare hands), St. Agnes much more survivable (the launcher and the safehouse supplies). Points no longer snowball between districts but every district still opens its rooms, just street by street.

---

## 2. Point 13 - swapping out a stuck gun (Salvage)

**What happens in v3:** under K1 every kill already paid its number, so the "lost points" are the **+5 finish bonus and the challenge** that the swapped gun will never pay. The stack just vanishes. It reads as a loss even though it is only a missed bonus.

**v4 rule - Salvage.** When you equip a gun over an **unfinished** gun (from the street or the Wall Rack), the old gun's stack pays **+1 point per kill on it** ("SALVAGE +30" for a 3-kill stack). The equip sheet shows it before you choose: `INTO SLOT 1 - Rifle 3/4, salvage +30`. Finishing still pays more (+5 finish bonus + challenge), so finishing stays the goal. Bench Trim removes a kill without salvage (the kill was already paid). Scrapping a gun card is unchanged (+2).

**Options tested** (v3 base; 400 = screening runs):

| Option | Run win R / I / T | Finished / swapped / salvage pts a run | Dead-gun streets | Notes |
|---|---|---|---|---|
| v3: nothing (1000) | 31.8 / 38.5 / 37.5 | 9.4 / 10.4 / 0 | 12.3% | |
| **+1 per kill (1000, recommended)** | **36.1 / 42.5 / 41.4** | **8.6 / 12.9 / 24.6** | **10.1%** | simplest to read, always less than finishing |
| +2 per kill (400) | 39.0 / 54.2 / 50.2 | 8.0 / 15.7 / 61.9 | 8.8% | too rich: swapping beats finishing |
| Half the finish bonus (+2) if 2+ kills (400) | 32.5 / 42.5 / 39.0 | 8.9 / 12.2 / 16.8 | 10.5% | a threshold to explain |
| Tally: every 4 swapped-away kills pay +5 (400) | 35.5 / 52.0 / 38.8 | 8.5 / 13.5 / 30.6 | 9.9% | "no kill is wasted", but a new meter on screen |
| Tally per 3 (400) | 44.0 / 50.0 / 43.2 | 8.3 / 14.5 / 45.2 | 9.0% | too rich |
| Half the stack total again (400) | 47.2 / 59.0 / 54.0 | 7.8 / 16.8 / - | 7.7% | double-pays kills; rotation by swapping |

**Recommendation: +1 per kill.** It removes the "my stack just vanished" moment with a visible payout, keeps finishing clearly better (+5 + challenge vs at most +4), and lowers dead-gun streets by ~2 points because players unstick sooner. Cost: swaps rise ~2.5 a run and finishes drop ~0.8, which is still the head's rotation. In full v4, turning Salvage off drops win to 31.3 / 36.9 / 36.4% and raises dead-gun streets to 15.4%.

---

## 3. Point 14 - more Patches

The Patch Press offers 2 random Patches; a boss offers 3. With 14 Patches the offers vary much more between runs (v3: 8). Prices unchanged (15, 25, 35...).

**Power band.** Each Patch was given at the start of a run (a test hook, `start_patches`), and the run win compared with no starting Patch. Same batch, 400 runs per survivor, all 15 candidates in the pool:

| Patch | Run win with it from the start | vs no Patch (38.2%) |
|---|---|---|
| Lookout (v3) | 28.5% | -10 (the AI uses it badly; humans will do better) |
| Brawler (v3) | 40.9% | +3 |
| Quartermaster (candidate) | 42.6% | +4 |
| **Show-Off** (new) | 44.3% | +6 |
| Bounty Hunter (v3) | 47.5% | +9 |
| Second Wind (v3) | 49.9% | +12 |
| Loose Grip (v3) | 50.8% | +13 |
| **Lockpick** (new) | 51.8% | +14 |
| Thick Jacket (v3) | 54.0% | +16 |
| **Adrenaline** (new) | 54.7% | +17 |
| **Grudge** (new) | 56.7% | +19 |
| **Iron Stomach** (new) | 60.7% | +23 |
| Field Medic (v3) | 67.9% | +30 |
| Trophy Belt (v3) | 68.7% | +31 |
| Opening Shot (candidate, -2 damage) | 90.9% | **+53, cut** |

In the full v4 rules (bare hands, same method, 400 runs, baseline 41.7%): Lockpick 57.7, Iron Stomach 56.8, Grudge 56.2, Adrenaline 54.9, Show-Off 46.7, Whetstone 40.2, Brawler (v4) 38.1, Field Medic 71.9. Opening Shot at -1 damage still 75.1: cut.

**The 6 new Patches (one-line card text):**

| Patch | Card text | Sim key / value |
|---|---|---|
| **Lockpick** | Rooms cost 50 less. | `lockpick_off` 5 |
| **Iron Stomach** | Healing above your max HP becomes Cover. | (medkits, Field Medic, Triage overflow) |
| **Adrenaline** | At 6 HP or less, every weapon has +1 power. | `adrenaline_hp` 6 |
| **Grudge** | +1 power against zombies 9 or more (bosses too). | `grudge_min` 9 |
| **Show-Off** | Every completed challenge also pays +40. | `show_off_points` 4 |
| **Whetstone** | Melee weapons you pick up get +2 uses. | `whetstone_dur` 2 |

**Changed:** **Brawler** - "Bare hands +2 power. Melee weapons you pick up get +1 use." (v3: melee +2 power). With +2 power on melee weapons a Sledgehammer hits 8 and Brawler from the start won 56% (melee kills 11 a run): exactly the "too strong once upgraded" problem from point 17, moved to the new weapons.

**Recommendation:** add the 6. Show-Off and Whetstone sit at the weak end with Brawler and Bounty Hunter (fine: a weak offer is still a choice), Iron Stomach at the strong end below Field Medic / Trophy Belt. Quartermaster (Bench and Wall Rack 40 cheaper) is a spare if a slot is needed later.

---

## 4. Point 15 - points between districts (Safehouse Shop)

**What happens in v3:** you end a district with ~40 points you can't spend (the boss street pays +10 and its kills after the last wave, and machines are once per wave). You enter Downtown with 39 and St. Agnes with 42, enough for the cheapest room before the first card (0.83 / 0.88 rooms on average; a human who saves on purpose can open two or three).

**v4 rule - Safehouse Shop.** Points don't leave a district. The safehouse (after Maple Row and after Downtown) has a small shop for your unspent points:
- **One Patch** at the current Patch Press price (shows 2, take 1). This is on top of the boss's free Patch.
- **Supplies: 30 on screen per 1 HP** (3 sim points), up to your max HP.
- Whatever is left is lost when you leave. The Leave button says it: `LEAVE - 40 left behind`.
Score is unchanged: it counts every point earned, not what you hold.

**Options tested** (v3 + Salvage base, 400 runs; D2/D3 start = points you start Downtown / St. Agnes with):

| Option | Run win R / I / T | D2 / D3 start | Rooms before first street D2 / D3 | Notes |
|---|---|---|---|---|
| Carry everything (v3) | 38.5 / 40.2 / 40.8 | 44 / 45 | 0.86 / 0.91 | the head's complaint |
| No carry-over | 11.0 / 22.0 / 12.8 | 0 / 0 | 0 / 0 | the economy compounds: rooms -> guns -> points; far too hard |
| No carry-over, every room 20% cheaper | 38.2 / 49.5 / 45.5 | 0 / 0 | 0 / 0 | works, but 7.5 of 9 rooms open (a retune of every price) |
| Keep up to 10 | 19.8 / 31.8 / 18.5 | 10 / 10 | 0 / 0 | |
| Keep up to 20 | 23.0 / 33.0 / 29.8 | 20 / 19 | 0 / 0 | |
| Keep up to 20, the rest heals 1 HP per 5 | 28.8 / 37.0 / 37.5 | 20 / 19 | 0 / 0 | two rules in one |
| All converts to HP, 1 per 5 / 1 per 3 | 26.3 / 30.4 avg | 0 / 0 | 0 / 0 | |
| Patch only (rest lost) | 27.5 / 41.8 / 34.0 | 0 / 0 | 0 / 0 | |
| **Safehouse Shop: Patch + 1 HP per 3** | **40.0 / 50.5 / 44.5** | **0 / 0** | **0 / 0** | 7.3 HP, 0.88 Patches bought, 15 points lost a run |
| Shop, 1 HP per 2 | 39.5 / 55.2 / 45.5 | 0 / 0 | 0 / 0 | too generous |
| Carry, rooms x1.0 / x1.3 / x1.6 by district | 10.0 / 9.2 / 8.2 | 44 / 40 | 0.79 / 0.42 | scaling hits players who didn't hoard: far too hard |

1000 runs, Shop alone on v3: **35.9 / 44.8 / 40.1%** (v3 31.8 / 38.5 / 37.5); 6.6 HP and 0.76 Patches bought a run, 13 points left behind. In full v4: carry-everything instead of the Shop gives 37.0 / 41.7 / 42.8% but brings back 0.78 / 0.94 rooms before the first street and 9.0-minute wins (Shop: 8.4).

**Recommendation: Safehouse Shop.** Each mission starts with every door closed (the head's goal), the leftovers turn into the thing the head liked most (a Patch) or into HP, and the shop is a real 10-second decision at a moment that is currently empty ("heal 8, continue"). It needs no room-price retune. "No carry-over" alone is far too hard without cutting every room price.

---

## 5. Point 16 - new weapons

Both fit the kill-rule system (rule + power + capacity + challenge), both are original names.

| Gun | Rule | Power | Capacity | Challenge | Reward | Where |
|---|---|---|---|---|---|---|
| **Stovepipe Launcher** | **One Shot**: any zombie, then it's finished (capacity 1) | **7** | **1** | *Big Bang*: the kill is 9 or more | +5 points (+50) | Downtown, St. Agnes gun cards |
| **Alley Sweeper** | **Small Fry**: 6 or less only | 3 | 4 | *Pest Control*: the stack totals 15 or less | +6 points (+60) | Maple Row, Downtown gun cards |

**The launcher is the head's "super high damage, only one zombie".** The one decision it adds: fire it now, or hold it for a 9+ (Big Bang) or for Patient Zero's 10 / 12. Equipping it costs a slot, which is the "small magazine".

Launcher variants tested (v3 base, gun cards in Downtown + St. Agnes, 400 runs; v3 = 33.7% average):

| Variant | Run win (average) | Launchers finished a run |
|---|---|---|
| Power 8, 2 shots, one kill per street | 61.7% | 1.96 |
| Power 6, 2 shots, one per street | 54.8% | 1.74 |
| Power 7, 2 shots, 6+ only, one per street | 57.8% | 1.62 |
| Power 8, 2 shots, only in the most expensive room | 54.6% | 0.83 |
| Power 8, one shot | 48.8% | 1.81 |
| **Power 7, one shot (recommended)** | **45.1%** | **1.74** |
| Power 6, one shot | 42.1% | 1.66 |
| Power 7, one shot, only in the most expensive room | 44.9% | 0.80 |

Any 2-shot version is too strong because it erases Patient Zero (St. Agnes clear 53% -> 80%). The one-shot at power 7 is still a strong gun (1000 runs, both guns added to v3: **36.8 / 45.6 / 42.0%**, St. Agnes clear 56 -> 62%), which the rest of v4 absorbs.

Alley Sweeper variants: 5 or less / capacity 5 in Maple Row + Downtown was never finished (0.22 a run; Downtown has few small zombies) and lowered win (29.6%); **6 or less / capacity 4** is finished 0.35-0.50 a run, like the Scout Carbine (0.35). It is the gun that turns the small zombies you used to melee into points, which matters more now that bare hands are weak.

In v4: launcher finished 1.34 / challenge 0.48 a run, sweeper 0.49 / 0.19. Every v3 gun is still finished at least ~0.3 a run.

**Recommendation:** add both. If the head wants the launcher to feel rarer, the fallback is "only in the Parking Garage / Morgue Lab pack" (same win rate, half as often).

---

## 6. Point 17 - melee rework

**v4 rule.**
- **Bare Hands**: power **1**, no rule, unlimited, always there. A bare-hands kill scores **no points**.
- **Melee weapon cards** (new card type, in the pile like guns). Tap one: `TAKE` (it replaces your current melee weapon) or `SCRAP +20`. Each melee kill uses one **use** (durability pips on the card); at 0 it breaks and you're back to bare hands. Melee-weapon kills also score **no points**.

| Melee weapon | Power | Uses | Where |
|---|---|---|---|
| **Pipe Wrench** | 3 | 4 | Maple Row, Downtown |
| **Fire Axe** | 4 | 3 | Downtown, St. Agnes |
| **Sledgehammer** | 6 | 2 | St. Agnes |

- **Supply:** one melee weapon card in every district's **Entrance** and one in every **Wave 2** deck (6 a run). Not in room packs.
- **Brawler** (changed): bare hands +2 power; melee weapons you pick up get +1 use.
- Theo, Rosa, Imani: unchanged.

**Tested** (v3 base, 400 runs unless marked):

| Option | Run win (avg) | Melee kills (weapon) | Stuck fights / damage a run |
|---|---|---|---|
| v3 crowbar power 2 (1000) | 35.9% | 1.9 | 1.3% / 1.9 |
| Bare hands 1, no melee cards | 32.3% | 1.4 | 1.1% / 2.4 |
| Bare hands 1 + a melee card in each Entrance | 39.4% | 2.8 (2.5) | 1.7% / 1.8 |
| **Bare hands 1 + Entrance + Wave 2 (1000, recommended)** | **33.2 / 39.0 / 37.9%** | **2.5 (2.3)** | **1.9% / 1.9** |
| ...and melee-weapon kills pay half their number | 42.7% | 5.9 (5.7) | 1.9% / 2.0 |
| v3 crowbar + Brawler from the start | 39.1% | 6.5 | 1.8% / 1.4 |
| New melee + old Brawler (+2 on weapons) from the start | **56.0%** | **11.1 (10.2)** | 1.8% / 1.0 |

**Is being stuck still survivable? Yes.** In full v4, stuck fights rise from 1.3% to 3.2% of fights (~1.8 a run) and cost 4.0 HP a run (v3 1.9). Most of that comes from the Safehouse Shop, not the melee change: v4 with the v3 crowbar instead costs 3.9 HP a run for 1.9% stuck. Win rate holds (39.0% v4, 36.0% v4 with the crowbar). The weapon you hold when stuck matters more now: 3.1 of the 3.5 melee kills a run use a melee weapon, and 0.5 a run break mid-fight. Maple Row clear goes 92% -> 86%: the first district now teaches "pick up the wrench", which the K5 tutorial hints should mention once.

**Melee points: keep "melee scores no points".** Half points doubles melee kills (5.9) and pushes win +6 points: it blurs "shoot to score" and would need a retune. The head's worry was melee once upgraded; that came from Brawler on an unlimited crowbar, and v4 fixes it at the source (weak bare hands, durability, Brawler on bare hands only).

---

## 7. Point 18 - one medkit per street

**v3:** a second medkit on the same street is resolved and **discarded**. That's what felt odd: you spend an action to throw a card away.

**Sim:** the AI hits the limit only **0.34 times a run** (it plans around it), and removing it changes run win by +0.5 (1000 runs: 32.4 / 38.0 / 38.8% vs 31.8 / 38.5 / 37.5%), well inside noise. Medkits are already limited by the 3 resolves per street and by max HP.

**v4 rule:** **no limit.** A medkit always heals its number (+ Field Medic / Triage), up to max HP. Overhealing is the only waste, and the medkit card shows it before you tap ("heals 3 of 5"). Iron Stomach (section 3) turns that overflow into Cover.

**Recommendation:** remove the rule. It cost a line of tooltip text, a log line and a confusing "discarded" moment for no balance effect. If playtests later show medkit-heavy streets (Pharmacy pack) are too strong, the knob is the Pharmacy pack, not a per-street rule.

---

## 8. Point 19 - Run returns all the cards

**What the rules and the build do today:** Run (before your first resolve on a street; 1 damage, Theo free; not twice in a row; never on a boss street) shuffles **every card on the street** back into the pile: zombies, guns, medkits, cover and the Holdover. `DDRun.run_street()` appends the whole street to the pile; the sim returns 3.9 cards per Run, 0.85 of them non-zombies. So nothing in the rules keeps the non-zombie cards away from the pile.

**Likely cause of what the head saw:** presentation. The fly-back animation is quick (0.24 s) and every card shrinks into the face-down pile, so a medkit or gun going back is easy to miss, and there's no count on screen. This belongs with the UX designer (feedback, points 2 and 10).

**v4 rule (clarified wording, no rule change):** "**Run:** before you resolve a card, put **every card on the street** back into the pile and shuffle it. Take 1 damage." Plus UX: every card flies back face up, the pile counter ticks up per card, and the log says `You run: 4 cards back (2 zombies, medkit, gun)`.

**Alternatives tested** (v3 base, 400 runs):

| Option | Run win (avg) | Runs a run | Cards back per Run (non-zombie) |
|---|---|---|---|
| **v3: all street cards back, before the first resolve** | **33.7%** | 1.55 | **3.9 (0.85)** |
| Only the zombies go back; other cards are discarded | 34.6% | 1.54 | 3.1 (0) |
| Run any time on the street: resolve some, then everything left goes back | 31.3% | 3.24 | 2.6 (0.02) |
| No Run at all | 37.3% | 0 | - |

All within noise of each other: Run is a safety valve, not a strategy (as in v3 8.4). "Run any time" is the one real alternative, and it is worse design: players take the medkit and flee from the zombies (non-zombie cards returned drop to 0.02), it doubles Run use, and it needs a second "Run now" state mid-street.

**Recommendation:** keep the rule, fix the presentation, and ask the head (Q5) what they saw.

---

## 9. The v4 rule set and balance

### 9.1 Everything that changes (CONFIG, `tools/sim_deaddraw_v4.py`)

| Key | v3 | **v4** |
|---|---|---|
| `swap_salvage` / `salvage_per_kill` | none | **per_kill / 1** |
| `carry_mode` / `carry_heal_rate` | all | **shop / 3** (1 Patch at the Press price + 1 HP per 3 points, the rest lost) |
| `melee_mode` / `hands_power` | crowbar, `melee_power` 2 | **hands / 1** |
| `melee_weapons` | - | wrench 3 / 4 uses, axe 4 / 3, sledge 6 / 2 |
| `melee_pool` | - | Maple Row: wrench; Downtown: wrench, axe; St. Agnes: axe, sledge |
| `card_add` | - | each district: Entrance + `K`, Wave 2 + `K` |
| `brawler_mode` / `brawler_dur` | all | **hands / 1** (`brawler_bonus` stays 2) |
| `melee_weapon_points` | - | 0.0 |
| `medkits_per_street` | 1 | **99** (no limit) |
| `run_mode` | before | before (unchanged) |
| `weapons.launcher` | - | rule `heavy`, p 7, cap 1, chal `big_bang` (9+), reward points 5 |
| `weapons.sweeper` | - | rule `small` (<= `small_max` 6), p 3, cap 4, chal `pest_control` (total <= 15), reward points 6 |
| `pool_add` | - | Maple Row: sweeper; Downtown: sweeper, launcher; St. Agnes: launcher |
| `patches` | 8 | + lockpick, iron_stomach, adrenaline, grudge, show_off, whetstone |
| new Patch values | - | `lockpick_off` 5, `adrenaline_hp` 6, `grudge_min` 9, `show_off_points` 4, `whetstone_dur` 2 |
| `survivors.imani.hp` | 19 | **18** |

Unchanged: street 4 / resolve 3, Run, rooms and prices, `finish_bonus` 5, Patch prices, Bench, Wall Rack, bosses, zombie numbers, Rosa 20, Theo 21.

The sim also holds the rejected options so they can be re-run: `swap_salvage` half_bonus / tally, `carry_mode` none / cap / heal / cap_heal / patch / scale, `run_mode` zombies_only / anytime, Patches opening_shot / quartermaster, `heavy_min`.

```
python3 projects/deaddraw/tools/sim_deaddraw_v4.py --runs 1000 --seed 7          # v4
python3 projects/deaddraw/tools/sim_deaddraw_v4.py --runs 1000 --seed 7 --preset v3
python3 projects/deaddraw/tools/sim_deaddraw_v4.py --set carry_mode=all          # one option back
python3 projects/deaddraw/tools/sim_deaddraw_v4.py --set 'start_patches=["grudge"]'
```

### 9.2 v4 balance (1000 runs per survivor, seed 7)

| Survivor | Clear Maple Row | Clear Downtown (reached) | Clear St. Agnes (reached) | **Run win** | HP on a win | Winning run | Average run |
|---|---|---|---|---|---|---|---|
| Rosa (20 HP) | 83.0% | 63.3% | 65.5% | **34.4%** | 9.2 | 8.4 min | 6.3 min |
| Imani (**18 HP**) | 85.3% | 68.0% | 73.4% | **42.6%** | 9.3 | 8.4 min | 6.6 min |
| Theo (21 HP) | 88.5% | 65.3% | 69.2% | **40.0%** | 9.1 | 8.5 min | 6.7 min |

- **Imani** gains most from v4 (no medkit limit + supplies + Triage all stack on healing). At 19 HP she won 49.5%; at 18 HP 42.6%, at the top edge of the band (within sampling error). If playtests agree, the next knob is 17 HP.
- **Difficulty curve:** Maple Row 83-89% (was 92%: bare hands), Downtown stays the wall (63-68%), St. Agnes is no longer a coin flip (56% -> 66-73%): the launcher and the safehouse supplies.
- **Length:** 8.4-minute wins, 33.5 streets, 4.2 taps per street (slightly fewer than v3: the medkit limit is gone, no extra room taps at district start). The Safehouse Shop adds ~10 seconds twice, not in the sim's time model.

### 9.3 Leaving each v4 change out (1000 runs, full v4 otherwise)

| v4 without... | Run win R / I / T | What changes |
|---|---|---|
| (full v4) | 34.4 / 42.6 / 40.0 | |
| Salvage | 31.3 / 36.9 / 36.4 | dead-gun streets 12.9 -> 15.4%, stuck 3.2 -> 3.6% |
| Safehouse Shop (carry everything) | 37.0 / 41.7 / 42.8 | 0.78 / 0.94 rooms open before the first street; wins 9.0 min |
| Melee rework (v3 crowbar) | 31.7 / 39.5 / 36.9 | stuck 1.9%, same stuck damage (3.9) |

---

## 10. Questions for the studio head (recommended option first)

**Q1. Points between missions (point 15).**
- (a) **Safehouse Shop (recommended):** points don't carry; at the safehouse spend them on 1 Patch (Press price) and on HP (30 per HP); the rest is lost. Every mission starts with closed doors. 34-43% win.
- (b) Keep up to 200 on screen; the rest heals 1 HP per 50. Doors also start closed (you can't afford one), less shopping. ~29-38% win.
- (c) No carry-over and every room 20% cheaper. Cleanest rule, but most rooms open each district (7.5 of 9), and every price changes.

**Q2. Swapping out an unfinished gun (point 13).**
- (a) **Salvage +10 per kill on the stack (recommended).** Always less than finishing (+50 + challenge).
- (b) Kill Tally: swapped-away kills go to a tally; every 4 pay a finish bonus (+50). No kill is wasted, but it's a new counter on screen.
- (c) Keep v3 (nothing).

**Q3. The Stovepipe Launcher (point 16).**
- (a) **One shot, power 7, a normal gun card in Downtown and St. Agnes (recommended).** ~1.3 a run.
- (b) Same gun, but only in the most expensive room of each district (Parking Garage, Morgue Lab): rarer (~0.8 a run), a reason to open that room.
- (c) Two shots (one per street), power 6: feels more like a weapon you keep, but it trivializes Patient Zero (+21 points of win).

**Q4. Melee weapon kills (point 17).**
- (a) **No points, like bare hands (recommended).** Melee is for survival, guns are for score.
- (b) Half the zombie's number. Melee kills double (~6 a run), win +6 points; needs a retune.

**Q5. Run (point 19).** The rules and the build already put every street card back. Which did you see?
- (a) **Cards seemed to vanish: keep the rule, make the fly-back show every card face up with a count and a log line (recommended; UX task).**
- (b) You wanted to Run after taking a card (e.g. grab the medkit, then flee): "Run any time" tested at the same win rate, but it doubles Run use and invites cherry-picking.

---

## 11. Implementation list (mechanics developer)

Build against `tools/sim_deaddraw_v4.py` CONFIG; every rule below has a sim function of the same name in brackets.

**Data**
1. `tools/regen_balance.py`: read `sim_deaddraw_v4.py` instead of v3; `_version` 4, `_note` updated. Regenerate `data/balance.json`.
2. `DDBalance.DEFAULT_TOP`: add `swap_salvage`, `salvage_per_kill`, `carry_mode`, `carry_heal_rate`, `melee_mode`, `hands_power`, `brawler_mode`, `brawler_dur`, `melee_weapon_points`, `melee_weapons`, `melee_pool`, `card_add`, `pool_add`, `run_mode`, `lockpick_off`, `adrenaline_hp`, `grudge_min`, `show_off_points`, `whetstone_dur`, `small_max`, `heavy_min`, `big_bang_min`, `pest_total`; `medkits_per_street` default 99; fix the stale `finish_bonus` default (3 -> 5). Accessors: `melee_def(id)`, `melee_pool(di)`, `district_card_add(di)`, `district_pool(di)` (district weapons + `pool_add`).
3. `DDBalance.wave_spec` / Entrance / room packs: append `card_add` entries (`"K"` = random from the district melee pool; `"W:id"` / `"K:id"` = a fixed card).

**Rules (`DDRun`, `DDCard`, `DDGun`)**
4. `DDCard`: new kind `"K"` (melee weapon, `wid` = melee id); `DDCard.melee(id)`; `parse("K:wrench")`; to/from dict unchanged (uses `w`).
5. Melee slot [`melee_power`, `fight`, `apply_card`]: `var melee: Dictionary` (`{}` = bare hands, else `{id, power, uses}`). `melee_power(z)` = weapon power or `hands_power`, + Brawler on bare hands only, + Adrenaline / Grudge. Each melee-weapon kill uses 1; at 0 emit a "broke" note and clear. `choices_for` a K card: `take` / `scrap`; `card_preview` shows the replaced weapon and its uses left. Whetstone +2 uses, Brawler +1 use on take.
6. Salvage [`salvage`]: in `_collect(i, finished=false)` pay `salvage_per_kill x stack size`; add `"salvage"` to the collect info and the log; `card_preview` for an equip shows it.
7. Safehouse Shop [`carry_over`]: after the boss Patch, the safehouse offers (a) one Patch at `patch_price(len(patches))` (offer 2, pick 1, optional) and (b) supplies at `carry_heal_rate` per HP (stepper, up to max HP). On leave, `points = 0` (log "N left behind"). New API: `shop_patch_offer()`, `buy_shop_patch(id)`, `buy_supplies(hp)`; `leave_safehouse()` unchanged otherwise. `points_earned` (score) unaffected.
8. Medkits: with `medkits_per_street` 99 the "discarded" branch never runs; keep the code path but drop its text from the UI. Iron Stomach: overflow of a medkit heal becomes Cover [`heal(..., overflow_cover)`].
9. New gun rules [`legal`, `zombie_opts`]: `small` (z <= `small_max`); `heavy` (z >= `heavy_min`, and one kill per street per slot: `fired[slot]`, reset in `_deal()` / `_start_boss_street()` and when a gun is equipped into that slot). New challenges `big_bang` (max kill >= 9), `pest_control` (total <= 15).
10. New Patches: `lockpick` (in `room_cost` / `room_block_reason`), `iron_stomach`, `adrenaline` (power +1 while hp <= 6, all weapons, also in `preview()`), `grudge` (+1 power vs z >= 9, incl. bosses), `show_off` (+4 on a met challenge in `_collect`), `whetstone`. `_add_patch` unchanged.
11. Imani `hp` 18 (data only).
12. `DDText`: Patch texts (section 3), Brawler text, rule texts `One Shot` / `Small Fry`, challenge names `Big Bang` / `Pest Control`, melee weapon names + "N uses", "Salvage +N", Safehouse Shop strings, Run text "every card on the street goes back".
13. UI (with the UX designer): melee slot shows the weapon + use pips (bare hands art when empty); equip sheet shows salvage; Safehouse Shop panel; Run fly-back shows every card face up.

**Save format**
14. `DDRun.to_dict` `"v": 4`; new keys `"melee"` (`{id, power, uses}` or `{}`) and `"fired"` (`[bool, bool]`). Cards of kind `"K"` reuse `{"k": "K", "w": id}`. `from_dict`: accept v4; a **v3 mid-run save** is not compatible (crowbar rules, carried points): return null so the game offers a new run, as it does for v2 saves today. The profile save (unlocks) is unaffected.

**Tests** (`tests/`): update `test_rules_street` (no medkit limit, Run returns every card type), `test_rules_guns` (salvage, `small`, `heavy`, new challenges), `test_rules_perks` (6 new Patches, Brawler v4), new melee tests (take / break / scrap / bare hands 1), safehouse shop flow, `test_run_save` (v4 round trip, v3 save rejected), `test_balance` (new keys and defaults).

---

## 12. Art list

**New card art** (same frame and style as the current gun / zombie cards)
1. Stovepipe Launcher (gun card)
2. Alley Sweeper (gun card)
3. Pipe Wrench (melee card)
4. Fire Axe (melee card)
5. Sledgehammer (melee card)
6. Bare Hands (melee slot art when no weapon is held; taped fists)

**Icons**
7. Rule icons: One Shot (a single rocket / "1"), Small Fry ("<= 6" with a down chevron); these join the v3 rule icons in the Glossary (UX point 9).
8. Challenge badges: Big Bang, Pest Control.
9. Melee **use pip** (filled / empty) and a **broken** crack overlay for the moment a weapon breaks.
10. **Salvage** token (bolt and coin) for the equip sheet and the "+30" float.
11. Six embroidered Patch badges: Lockpick, Iron Stomach, Adrenaline, Grudge, Show-Off, Whetstone; and an updated Brawler badge (bare fist).
12. Safehouse Shop: a supplies icon (tin of bandages) and a "left behind" coin icon for the Leave button.

---

## 13. As built (dd-v4-impl, 2026-11-11)

The head answered section 10: Q1 (a) Safehouse Shop, Q2 (a) Salvage, Q3 (a) the launcher (one shot, capacity 1: its single kill socket is the one-shot cue, no extra icon), Q4 (a) melee weapon kills score nothing. Every other recommendation applies (6 Patches, Brawler v4, Alley Sweeper, Bare Hands 1, the three melee weapons with uses, no medkit limit, Imani 18 HP, save format v4).

**Q5, Run (changed):** "I want to be able to run even if there is no zombie, to put items back at the bottom." Built as two sim keys, both now the CONFIG default:
- `run_mode: "anytime"`: Run whenever the street has cards, before or after resolving some, zombie or not.
- `run_return: "bottom"` (new key): every card still on the street goes **under** the pile, in street order, unshuffled (v3: shuffled in). Cost (1 HP, Theo free), "not twice in a row" (the street after a Run must be played to its end) and "never on a boss street" are unchanged. `--preset v3` sets both back.

Run variants, 1000 runs per survivor, run win R / I / T, three seeds:

| Run rule | seed 7 | seed 11 | seed 23 | average | St. Agnes clear (reached) |
|---|---|---|---|---|---|
| before + shuffle (section 9 v4) | 34.4 / 42.6 / 40.0 | 35.8 / 42.8 / 43.0 | 34.8 / 40.5 / 40.6 | 35.0 / 42.0 / 41.2 | 66-73% |
| before + bottom | 34.7 / 38.5 / 44.0 | 34.3 / 41.3 / 39.6 | 35.3 / 41.0 / 43.0 | 34.8 / 40.3 / 42.2 | 65-68% |
| **anytime + bottom (built)** | 31.9 / 36.1 / 43.6 | 30.6 / 35.3 / 34.9 | 29.7 / 35.9 / 39.8 | **30.7 / 35.8 / 39.4** | 55-64% |

Reading: the built rule stays inside the 30-42% band on average, but Rosa sits on its lower edge and the Rosa-Theo gap is ~8.7 points (Theo's free Run: 5.1 Runs a run vs 3.0). The strong AI uses "anytime" to take the good cards and send the zombies back (0.01 non-zombie cards back per Run), so it runs twice as often and reaches St. Agnes weaker. If playtests agree, the one-line fallback is `run_mode: "before"` (keeps "to the bottom", every street card goes back): 34.8 / 40.3 / 42.2%.

**Parity:** `tools/v4_parity_cases.py` runs the sim's own rule functions on 1380 seeded cases (rules, challenges, gun kills with Patches, melee, pick-ups, salvage, medkits, rooms, shop supplies) into `tests/data/v4_parity.json`; `tests/test_v4_parity.gd` replays them through `DDRun` (all match). `test_balance` checks `data/balance.json` against the sim CONFIG key by key.

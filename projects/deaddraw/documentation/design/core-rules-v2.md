# DeadDraw - Core Rules v2 ("Last Stand" waves)

Owner: Sr Game Designer | Board task: `dd-v2-design` | Engine: Godot 4.4.1 (GDScript), Web export, phone portrait + landscape
Status: **proposal for studio head review.** v1 (`core-rules.md`, `tools/sim_deaddraw.py`, the playable build) is untouched.
Balance source of truth for v2: `projects/deaddraw/tools/sim_deaddraw_v2.py` (`CONFIG`). If this document and the sim disagree, the sim wins and this document gets fixed.

> **Naming and IP.** v2 is inspired by the *feel* of the round-based zombies modes in shooters such as Call of Duty. That is the only place that series is named. Every machine, consumable, weapon and mode name below is original to DeadDraw. Do not use that series' trademarked or signature names in the game, in store text or in code (no upgrade-machine, gum, soda-perk, mystery-box or wonder-weapon names from it).

---

## 0. Vision

**One sentence:** Hold out across a fallen city one wave at a time: every street deals four cards, you deal with three, and every point you earn opens another door, another gun, another machine.

**What v2 changes, in one breath:** the deck is now a **wave** of zombies, mixed with the loot of the **rooms** you have bought open with **points**. You carry **two weapons**. Guns have a **magazine** and need a **reload**; melee never runs out. Opened rooms bring **machines**: the **Retrofit Bench** upgrades a weapon, the **Grin Machine** sells one-wave buffs, the **Lucky Locker** rolls a random weapon, and the **Wall Rack** sells a known gun and its ammo.

**Design pillars (v1 pillars kept, one added)**
1. **Every card is a choice you can read.** Damage, ammo and notch are shown before you commit. The only hidden information is the shuffle and the result of a machine you chose to pay for.
2. **Order matters more than luck.** Which three cards, in what order, with which of your two weapons, and when to reload or skip.
3. **Short runs, long arcs.** A run is about 9-12 minutes. Survivors, perks and unlocks make the next run different.
4. **One thumb, any screen.** Every card, weapon, pip, machine and pile is inspectable (long press / right click).
5. **(new) Spend to survive.** Points are the second resource next to HP. Every kill pays, and every few streets you choose between a door, a machine and saving up.

**Target emotion:** the rising pressure of a wave that is about to roll over, the relief of a perfectly timed reload, and the greed of "one more door".

---

## 1. Run structure

### 1.1 Overview

| Level | What it is | Count |
|---|---|---|
| **Run** | 3 districts in a fixed order: Maple Row, Downtown, St. Agnes Hospital. Win = beat Patient Zero. | 1 |
| **District** (a "map") | 3 waves. Wave 3 ends with that district's face-up boss (the v1 finales). A safehouse follows districts 1 and 2. | 3 |
| **Wave** | One pass through the deck. The deck is that wave's zombie pack plus any loot in play. | 9 per run |
| **Street** | Deal up to 4 cards, take 3 actions, 1 card stays (the Holdover). Same as v1. | ~30 per run |
| **Room** | Bought with points between streets. Adds a loot pack to the deck, a machine you can use, and restocks loot every wave. | 3 per district (+ the free Entrance) |

### 1.2 The deck: one mixed deck (recommended, studio head option 2)

Each district has **one deck**. It always contains:

- the **current wave's zombie pack**,
- the **loot** of the Entrance (free) and of every room you have opened,
- any cards you **skipped** in the previous wave.

**Street.** Fill the street to 4 cards from the deck. You then take **3 actions**; each action is either *resolve one card* or *reload one gun* (max one reload per street). The card you did not take is the Holdover and stays for the next street. If the deck can't fill the street, resolve all cards but one.

**Skip (was Retreat).** Before you resolve anything on a street you may **Skip** it: all 4 cards go face up onto the **Skipped pile**. You can't skip two streets in a row. Skipping costs no HP now, but:
- the skipped cards **come back in the next wave**, shuffled into its deck (zombies and loot alike), and
- the current wave ends **sooner**, because the deck is 4 cards thinner. The next wave pack arrives earlier, on top of what you skipped.

**Wave end - how the player knows.** The deck *is* the wave timer.
- The deck counter reads **"Wave 2 - 7 cards left (4 zombies)"**. The zombie count is exact, because the player knows the wave pack and what has been dealt.
- The wave track (top bar) shows the 3 waves of the district as pips plus the boss, with the current one lit.
- When the deck can't fill a street, the street shows a **"Last street of the wave"** banner, and the next wave's preview card ("Next: Wave 3 - 5 zombies, 5-10, + 3 skipped, + 2 restock") slides in face up so the player can plan the Holdover.

**Wave change.** When the deck is empty and at most one card is left on the street:
1. You earn the **wave bonus** (+3 points, shown as +30).
2. The new deck = the **Skipped pile** + the **next wave pack** + **restock** (1 loot card from each opened room's pack list) - shuffled.
3. The Holdover stays on the street. Buffs from the Grin Machine end, melee notches clear, machines can be used again.

**Loot across waves.** Loot is consumed when you resolve it. Loot you **skipped** comes back next wave (it is not lost). Loot that is still in the deck at a wave change can't exist, because the wave only ends when the deck is empty. So the rule the player learns is simply: *resolved cards are gone, skipped cards come back.*

**Boss wave (wave 3) - the last lap.** On the boss wave, when the deck runs out the Skipped pile is shuffled back in **once** for a **last lap** (no skipping during it). When that runs out too, the Holdover joins the face-up boss card(s) to form the **Boss street**: resolve every card, no skip. Beat it and the district is clear. (Without the last lap, skipping at the end of the final district would be free.)

**Deck growth.** Each wave adds 4-5 zombies plus 0-3 restock cards, and opening a room adds a 3-card pack right away. Sim average deck at the start of a wave: **8.2 cards**; skipped cards carried into a new wave: **0.5-0.7** on average.

### 1.3 The alternative: separate stacks (studio head option 1, not recommended)

A **wave deck** (zombies only) and a **loot deck** (rooms' loot). Each street deals **2 zombie slots + 2 loot slots**. The wave ends when the wave deck is empty and no zombie is on the street; loot carries across waves; skipped cards go under their own decks; the boss is the bottom card of wave 3.

Why it is the runner-up (sim comparison in 5.3): it is very readable ("2 zombies left in the wave") and about 2.5 minutes shorter, but a skip only reorders the same wave instead of pulling the next one in, every street is half loot whether or not you opened rooms (so a door changes *which* loot you get, not how much breathing room a wave has), and the phone screen needs two deck counters and a split street. It is the fallback if mixed-deck runs test too long.

### 1.4 Rooms and doors

Every district has a free **Entrance** (its loot is in the deck from wave 1) and **3 rooms** that open in order, each further into the map. A room is shown as a **door card** in the map strip above the street: name, price, its machine, and its loot pack (all inspectable).

- **Open a door** between streets (free action, not one of your 3) by paying its price. Its **loot pack is shuffled into the current deck at once**, its **machine** becomes usable, and from the next wave on it **restocks 1 loot card per wave**.
- Rooms reset when you leave a district. Weapons, ammo, points, perks and HP carry over.

| District | Room 1 | Room 2 | Room 3 |
|---|---|---|---|
| Maple Row | **Garage** - 100 pts - Wall Rack (Compact SMG) - loot: weapon, ammo 4, plywood 3 | **Corner Store** - 150 - Grin Machine - medkit 5, bandage 3, ammo 4 | **Workshop** - 220 - Retrofit Bench - weapon, ammo 5, medkit 6 |
| Downtown | **Subway Kiosk** - 120 - Grin Machine - medkit 4, ammo 5, weapon | **Pawn Shop** - 180 - Wall Rack (Pump Shotgun) - weapon, ammo 5, cover 2 | **Parking Garage** - 260 - Lucky Locker - weapon, medkit 6, ammo 5 |
| St. Agnes | **Pharmacy** - 140 - Grin Machine - medkit 5, medkit 7, ammo 4 | **Security Office** - 200 - Wall Rack (Carbine) - weapon, ammo 5, cover 3 | **Morgue Lab** - 280 - Retrofit Bench - weapon, medkit 6, ammo 6 |

Entrance loot: Maple Row weapon, ammo 4, medkit 4, plywood 2; Downtown weapon, ammo 4, medkit 5, plywood 2; St. Agnes weapon, ammo 5, medkit 6, car door 3.

### 1.5 Points

Points are shown x10 (the sim uses units of 10): small numbers in the rules, arcade-sized numbers on screen.

| Source | Points (on screen) |
|---|---|
| Kill a zombie | **half its strength, rounded down, x10** (a 7 pays 30; sim: `strength // 2` units) |
| Kill it with melee or bare hands ("up close") | +10 |
| Scrap a weapon (or replace one) | +10 |
| Clear a wave | +30 |
| Beat a boss | +80 |
| Carrier drop *Payday* | double kill points for the rest of the wave |

You start each run with 50. A strong run earns about 2,200-2,300 points. Spend: doors 100-280, machines 60-300 (section 3).

### 1.6 Content per district (sim CONFIG, exact)

| District | Wave 1 | Wave 2 | Wave 3 | Boss (face-up from the start) |
|---|---|---|---|---|
| Maple Row | 2, 3, 4, 5 | 3, 4, 6, 7 | 4, 5, 7, 8, 9 | **The Groundskeeper** 12, *Shatter*: the weapon used on it is destroyed (it still reduces the damage) |
| Downtown | 5, 6, 7, 9 | 6, 8, 9, 10 | 7, 8, 10, 11, 12 | **Rush Hour Horde** 10 / 9 / 8, *Horde*: all three at once |
| St. Agnes | 7, 9, 10, 12 | 8, 10, 12, 13 | 9, 11, 13, 14, 16 | **Patient Zero** 15, *Quarantine*: medkits don't heal on the boss street |

These are the effective strengths (sim: base wave lists plus `z_add` = -1 / +1 / +3 per district). St. Agnes wave 3 holds the biggest normal zombie in the game (a 16 Hulk); Patient Zero is a 15 but blocks healing. Each wave pack has exactly one **Carrier** zombie (a satchel badge on the card, visible when dealt) that drops a power-up when killed (3.5). Weapons in loot packs are drawn from a per-district weapon list, so each run's guns differ.

---

## 2. Weapons and combat

### 2.1 Two weapon slots and bare hands

You have **2 weapon slots** plus your bare hands (always available). Both slots are "in hand": when you fight, you choose **Slot 1, Slot 2 or Bare**. There is no swap action and no swap cost; the choice of which weapon takes which zombie *is* the swap.

You start with a **Service Pistol** (power 3, magazine 6) in Slot 1, Slot 2 empty, and **6 reserve ammo**.

### 2.2 Combat model: the hybrid (recommended)

Damage works as in v1: you take `zombie strength - weapon power` (minimum 0), Cover first. No zombie survives a fight.

| | Guns | Melee | Bare hands |
|---|---|---|---|
| Uses | **1 round per kill** from the magazine (pips on the card) | **Unlimited** | Unlimited |
| Notch (v1 rule) | Yes: after a kill it can only hit zombies **weaker than its last kill** | Yes | No (you take full damage) |
| Clears the notch | **Reload** | The start of every **wave** ("you wipe the blade") | - |
| Can't fight when | Mag empty, or notch blocks | Notch blocks | never |

So guns are strong but run dry and notch down; reloading them is your way back up to big zombies. Melee never runs dry but wears down within a wave, and has lower top power.

**Reload** (one action, max one per street): the rounds left in the magazine are **dropped**, a fresh magazine is loaded from the **reserve** (as many as you have, up to its size), and the **notch clears**. Reloading a nearly full gun just to clear the notch therefore wastes rounds: reload when the mag is low *or* when the next big zombie is worth it. On the boss street, a reload costs no action.

**Reserve ammo** is one shared pool for all guns (cap 24): start 6, plus **Ammo cards** (3-6 rounds), the *Full Load* drop, and the Wall Rack's ammo refill. A gun you pick up arrives with a full magazine.

**Equip / scrap.** A weapon card goes into Slot 1 or Slot 2 (the weapon there is scrapped, +10 points) or is scrapped itself (+10). Same Equip-or-Scrap decision as v1, with two slots.

### 2.3 Weapon list (sim CONFIG)

| Weapon | Type | Power | Mag | Where |
|---|---|---|---|---|
| Kitchen Knife | melee | 2 | - | loot, Locker |
| Crowbar | melee | 3 | - | loot, Locker |
| Cricket Bat | melee | 4 | - | loot |
| Machete | melee | 5 | - | loot, Locker |
| Fire Axe | melee | 6 | - | loot, perk |
| Sledgehammer | melee | 7 | - | loot, Locker |
| Service Pistol | gun | 3 | 6 | starting kit |
| Revolver | gun | 5 | 4 | loot |
| Compact SMG | gun | 3 | 10 | Wall Rack 120 |
| Pump Shotgun | gun | 7 | 3 | loot, Wall Rack 160, Locker |
| Hunting Rifle | gun | 6 | 4 | loot, Locker |
| Carbine | gun | 5 | 8 | loot, Wall Rack 200, Locker |
| Belt-fed MG | gun | 5 | 14 | Locker only |
| **Static Lance** | gun (prototype tech) | 9 | 5 | Locker only (1 in 13) |

### 2.4 The two models we tested (and the one we did not pick)

- **(A) Damage model.** No notch: a shot spends 1 round and reduces damage by the gun's power; a *double tap* spends 2 rounds for double power; melee has no limit at all (so it must be weak: power -2).
- **(B/hybrid) Notch + magazine** as above, reload clears both.
- (Pure B, notch-only guns with no magazine, is just v1 with a reload button: it removes the ammo economy the studio head asked for, so it was not simulated further.)

Sim evidence is in 5.2. Summary: the damage model is **unbalanceable with this card set**: even with every zombie +3 to +5 the AI still wins 93-100%, because a gun with reserve ammo is a flat damage shield with no ordering puzzle, and the only decision left is "is this zombie worth a round". The hybrid keeps v1's ordering puzzle (big zombie first, then smaller), adds "reload now or keep the notch?", and responds smoothly to tuning knobs.

---

## 3. Machines, drops and buffs (all original)

Machines live in rooms (1.4). Using one is a **free action between streets** (not one of your 3), **once per wave** per machine. All prices are on the machine card; long press shows the full rules and odds.

### 3.1 Retrofit Bench (weapon upgrade)
A grimy workbench with a hand-cranked lathe and a jar of mismatched bolts.
- **300 points:** upgrade one weapon you hold, **once per weapon**: **+2 power**, guns get **+50% magazine** (rounded) and a free full reload; melee becomes **Keen** (its notch also allows equal strength, like Rosa).
- The card gets a brass "R" plate and the name gains "Retrofit" (e.g. *Retrofit Revolver*).

### 3.2 Grin Machine (one-wave buffs)
A grinning gumball dispenser with a cracked glass dome. Each turn of the crank drops one **Jawbreaker** (a candy), chosen at random from 6 and shown before it takes effect. Each lasts **until the end of the current wave**, shown as a badge next to HP.
- **120 points**, +60 per purchase already made in this district (120, 180, 240...). Once per wave.

| Jawbreaker | Effect (this wave) |
|---|---|
| Thick Skin | Zombies deal 1 less damage. |
| Steady Aim | Your guns get +2 power. |
| Sleight of Hand | Reloading doesn't use an action. |
| Payday | Kills give double points. |
| Sugar Rush | Heal 5 now. |
| Light Step | You may Skip two streets in a row. |

### 3.3 Lucky Locker (random weapon)
A dented school locker with a rattling padlock and stickers on the door.
- **180 points:** it rolls one weapon from its pool (odds on the card: Belt-fed MG, Pump Shotgun, Carbine, Sledgehammer 2 each; Static Lance, Machete, Hunting Rifle, Knife, Crowbar 1 each). Take it into a slot or leave it (+10 scrap). Once per wave.

### 3.4 Wall Rack (known gun)
A chalk-outlined gun hung on hooks.
- Buy that **specific gun** (price on the outline: SMG 120, Shotgun 160, Carbine 200) into a slot, with a full magazine.
- If you already hold that gun: **ammo refill for 60** (full magazine + that many rounds into the reserve). Once per wave.

### 3.5 Carrier drops (no hidden rolls)
One zombie per wave pack is a **Carrier** (badge on the card: you know before you fight it). Killing it drops:
- **Full Load** - every gun's magazine is refilled and the notch cleared; +4 reserve.
- **Payday** - double kill points for the rest of the wave.
- **Boards** - gain 4 Cover now.

---

## 4. What we keep, change and cut

| v1 element | v2 | Why |
|---|---|---|
| Street of 4, resolve 3, Holdover | **Kept**, but "resolve 3" becomes "3 actions" (reload is an action) | It is the core of the game and reads well on a phone. |
| Notch rule | **Kept for every weapon**, cleared by reload (guns) or each wave (melee) | It is the ordering puzzle; the sim shows the game is flat without it (5.2). |
| Single weapon | **2 slots** | Requested; creates the gun/melee pairing and real per-fight choices. |
| Retreat to the bottom of the deck | **Skip to the Skipped pile**, back in the next wave | Same "loan" idea as the studio head's v1 decision, now tied to waves. |
| Face-up finales | **Kept** as the boss of wave 3 | Planning target; players loved seeing it coming. |
| Medkits (1 per street), barricades/Cover | **Kept** | Simple, readable. |
| Survivors | **Kept**: Rosa (Steady Hands: equal-to-notch hits), Imani (Triage), Theo (Slip Away; max HP 24 -> **21**, because skipping is stronger when skipped cards only return next wave; unlocks on first Downtown clear) | All three passives still work with the hybrid model. |
| Safehouse | **Kept**: heal 12, pick 1 of 3 perks; keep weapons, ammo, points | Run-shaping moment between maps. |
| Perks | **8 in pool**, two new: **Fast Hands** (first reload each wave costs no action), **Bandolier** (+2 reserve ammo each wave). Kept: Thick Jacket, Axe in the Trunk (Fire Axe 6 into your weaker slot each district), Field Kit, Knuckle Wraps, Second Wind, Tripwire. | Gun perks fit the new economy. |
| Perks **Sandbags** and **Scrounger** | **Cut** | Sandbags was the weakest v1 perk and Cover now also comes from Boards drops; Scrounger (heal on retreat) rewards skipping, which already pays by thinning the wave. |
| Meta unlocks | **Kept** (Second Wind on first Maple Row clear, Theo on first Downtown clear, Tripwire on a win). Later: unlock new Locker weapons and room variants. | Cheap, motivating. |
| One deck per district, 28-34 cards | **Cut**: the deck is now a wave plus loot | Requested structure. |
| Score = 10 + HP per district | **Changed**: score = **points earned** (spending doesn't lower it) + 10 x HP left at each boss | Points are the arcade score of the genre. |

---

## 5. Balance simulation

**Tool:** `projects/deaddraw/tools/sim_deaddraw_v2.py` (Python 3, standard library, multiprocessing). v1's `sim_deaddraw.py` is untouched.

```
python3 projects/deaddraw/tools/sim_deaddraw_v2.py --runs 1000 --seed 7                 # recommended rules
python3 projects/deaddraw/tools/sim_deaddraw_v2.py --structure separate --model damage   # alternatives
python3 projects/deaddraw/tools/sim_deaddraw_v2.py --set allow_retreat=false            # ablations
```

**AI.** The v1 greedy one-street lookahead, extended: on every street it searches every ordered choice of 3 actions (each card with every legal slot/bare, equip-to-slot-1/slot-2/scrap, plus a reload of either gun at any point), and scores the result as `HP + 0.35 x damage the two weapons can still absorb over the next 6 fights (counting magazine, notch and a discounted reload from reserve) + small credit for reserve ammo and points - Holdover zombie strength x 0.5`, with the v1 boss-readiness penalty during the boss wave. It Skips when that scores better (skipped cards are valued like future cards). Between streets it uses simple rules: open the next door when it can afford it, use each machine when it can afford it (Retrofit its best weapon, buy a Jawbreaker with a small reserve, take Locker/Wall weapons that beat its weaker slot, refill Wall ammo when low). Perks from a fixed priority list.

Wall-clock estimate: 13 s per street, 6 s per door, 4 s per machine use, 2 s per reload, 3 s per wave change, 20 s per safehouse.

### 5.1 Recommended rules (mixed deck + hybrid combat), 1000 runs per survivor, seed 7

Final CONFIG as committed in the sim (`structure: mixed`, `model: notch`, `reload_mode: drop`, `z_add: [-1, 1, 3]`, Theo 21 HP). "Starter pool" = a true first run (6-perk pool). Sampling error is about +/-3 points.

| Survivor | Clear Maple Row (fresh, no perks) | Clear D1 in run | Clear D2 in run | **Run win, starter pool** | Run win, full pool | Run win, no perks | HP left on a win | Winning run | Average run |
|---|---|---|---|---|---|---|---|---|---|
| Rosa | 77.9% | 80.8% | 74.3% | **32.4%** | 31.3% | 18.3% | 7.0 | 12.3 min | 10.1 min |
| Imani | 81.6% | 83.3% | 77.7% | **38.6%** | 38.2% | 27.0% | 7.9 | 12.3 min | 10.4 min |
| Theo | 81.6% | 80.1% | 73.0% | **33.7%** | 38.3% | 23.7% | 7.4 | 12.4 min | 10.1 min |

- All three survivors land in the **30-42%** band (32-39%). As with v1, a first-time human will do worse than the AI (expect 15-25%).
- Shape: Maple Row ~80% (teaches the rules), Downtown ~92% of those who reach it, **St. Agnes decides the run** (~45% of arrivals). That last step is steep; a later pass should move 1 point of difficulty from St. Agnes into Downtown.
- Perks are worth 10-14 points of run win. The two unlockable perks (Second Wind, Tripwire) are not stronger than the starter ones, so unlocking them is variety, not power (good).
- **Run length:** about 36 streets per run, **12.3 minutes for a win** and 10.1-10.4 minutes on average including losses. That is inside the 8-12 minute target, but at its upper edge for a win; the cheapest trim, if playtests feel long, is `restock_per_room: 0` (about -1 minute, then retune).

**Decisions per run (Rosa / Imani / Theo, per run average)**

| Decision | How often | Notes |
|---|---|---|
| Fights | 37 / 38 / 36 | |
| ... with **both weapons legal** (a real slot choice) | 26 / 26 / 25 | ~70% of fights offer Slot 1 vs Slot 2 vs Bare |
| ... with the AI switching slot within a street | 1.7 / 1.7 / 1.5 | |
| Kills by gun / melee / bare | 29.5 / 4.4 / 2.8 (Rosa) | melee is underused, see Q5 |
| **Reload available** (a street where a reload is legal) | 11.8 / 12.2 / 12.3 streets | of ~36 |
| Reloads done | 14.1 / 14.5 / 14.0 | includes the free reload on boss streets |
| Reload was a **close call** (within 2 points of the best no-reload plan) | 4.6 / 4.7 / 4.6 | the "reload or fight" tension we want |
| **Skip available** | 23.7 / 24.3 / 23.1 streets | |
| Skips taken | 1.8 / 2.0 / 2.6 | |
| Skip was a close call (within 2 points) | 3.2 / 3.3 / 6.1 | Theo's Slip Away makes skipping a live option twice as often |
| Weapon cards: equip / scrap | 7.0 / 3.0 (Rosa) | |
| **Doors opened** (of 9) | 6.7 / 6.8 / 6.6 | the third room of a district is often out of reach: saving up is a real choice |
| **Machine uses** | 5.7 / 6.0 / 5.7 | Grin 3.1, Wall Rack gun 1.3, Retrofit 0.7, Locker 0.35, Wall ammo 0.3 |
| Points earned | 2,260 / 2,320 / 2,210 on screen | |
| Deck size at the start of a wave | 8.2 | skipped cards carried into a new wave: 0.5-0.7 |

### 5.2 Combat model: hybrid vs damage (evidence for Q2)

**Wave structure, same content (300 runs/survivor):**

| Model | Rosa | Imani | Theo | HP left on a win | Notes |
|---|---|---|---|---|---|
| **Hybrid (notch + mag)** | 32.4% | 38.6% | 33.7% | 7-8 | 1000 runs, recommended |
| Damage model | **100%** | **100%** | **100%** | 22-23 | the AI ends runs near full HP |
| Damage model, every wave zombie 3 stronger than above (`z_add` 2 / 4 / 6, zombies up to 19) | 92% | 96% | 95% | 21-22 | still trivial |

**Room-deck first draft, same comparison (60 runs, Rosa / Imani):** hybrid with zombies +2/+3/+3 gave 47% / 67% and with +3/+4/+5 gave 8% / 15%; the damage model gave 100% / 100% and 98% / 100% at the same settings.

Why: without the notch, a gun with reserve ammo is a flat shield and order stops mattering; the only decision left is "spend a round or not", and the shooters' ammo supply (ammo cards, Full Load, Wall Rack) covers it easily. Making ammo scarce enough to matter would make guns irrelevant instead. The hybrid keeps the v1 puzzle and gives reload a real job: it is the only way to get a notched gun back up to big zombies.

### 5.3 Deck structure: mixed vs separate (evidence for Q1)

Same content, same AI, hybrid combat (300 runs for separate; mixed is the 1000-run result):

| | **Mixed (one deck)** | Separate (wave + loot decks) |
|---|---|---|
| Run win starter pool (Rosa / Imani / Theo) | 32.4 / 38.6 / 33.7% | 22.3 / 33.3 / 35.3% |
| Winning run / average run | 12.3 / 10.2 min | **9.7 / 8.0 min** |
| Streets per run | 36 | 26 |
| Skips per run / close-call skips | 1.8-2.6 / 3.2-6.1 | 1.5-2.2 / 3.2-5.9 |
| Reload close calls | 4.6 | 3.6-3.8 |
| Both-weapons-legal fights | 25-26 | 22-24 |
| Doors opened | 6.6-6.8 | 6.5-6.8 |

**Value of skipping in the mixed deck** (ablation, `allow_retreat=false`, 300 runs): run win drops to 23.7 / 33.7 / 28.7% (Rosa / Imani / Theo), i.e. **skipping is worth 5-9 points of run win** even though the AI only skips about twice a run. It is a sharp tool for the right moment (usually a street with two big zombies and no answer, early in a wave so the zombies come back after a reload or a new weapon), not a default.

Reading: both structures work and land near the band. Separate is about 2.5 minutes shorter (the street always holds 2 zombies, so waves go faster) and gives a cleaner "zombies left in the wave" read. Mixed is recommended because:
1. It is what the "skip speeds up the next wave, skipped zombies come back" idea needs: in the separate version a skip only reorders the same wave.
2. Buying a room changes the **density** of the wave (more loot per zombie), which makes the door a survival decision, not just a shop.
3. One deck, one counter, one 2x2 street: simpler on a phone.
4. Slightly more decisions per run (reload close calls 4.6 vs 3.7, slot choices 26 vs 23), at the cost of length. If playtests say runs are too long, separate is the fallback, not a redesign.

### 5.4 Reload cost (evidence for Q3, 300 runs)

| Reload rule | Rosa | Imani | Theo | Reloads / run | Reload close calls |
|---|---|---|---|---|---|
| **Drop the rest of the mag** (recommended, 1000 runs) | 32.4% | 38.6% | 33.7% | 14.1-14.5 | 4.6-4.7 |
| Keep the rounds (top-up) | 32.3% | 37.7% | 40.7% | 16.2-16.8 | 4.7-5.0 |

Balance can't tell them apart. The design argument decides: with top-up, reloading a gun after one shot just to clear its notch costs one reserve round, so the notch stops mattering for guns. Dropping the magazine makes "clear the notch now or shoot the mag dry first" a real trade, and it is easy to show ("drop 2, load 6").

### 5.5 Melee boost test (evidence for Q5, 300 runs)

Melee +1 power and up-close kills +30: melee kills rise from ~4 to **~9-10 per run**, but run win jumps to 44.7 / 47.0 / 48.7%, so it would need about +1 zombie strength in Downtown/St. Agnes to return to the band. Not applied to CONFIG yet (pending Q5).

---

## 6. UI sketch

The studio rules apply: every card, weapon slot, magazine, pip, machine, door, pile and badge opens a zoomed card with full rules on **long press (touch) / right click (desktop)**. Clarity over information: the street screen shows only what this decision needs; the rest is one inspect away.

### 6.1 Phone portrait (main target, ~390 x 844)

```
+------------------------------------------+
| WAVE [1][2][3]>[BOSS 12]   Pts 1,240     |  wave track: current lit; boss card inspectable
| HP [##########----] 14/20   Cover 2      |  Jawbreaker badge sits here ("Steady Aim")
| Deck 7 (4 zombies)      Skipped 3 >      |  tap Skipped = face-up list; deck = counts by type
|------------------------------------------|
| DOORS  [Garage: Wall Rack  USE]          |  opened room = machine button
|        [Corner Store 150  OPEN]          |  next room = price button (gray if short)
|        [Workshop 220 - locked]           |  later rooms visible but locked (open in order)
|------------------------------------------|
|   +-----------+    +-----------+         |
|   | ZOMBIE 7  |    | WEAPON    |         |  2 x 2 street, cards >= 150 px wide
|   | Lurcher   |    | Rifle 6/4 |         |  Carrier satchel badge on the zombie
|   | [satchel] |    |           |         |
|   +-----------+    +-----------+         |
|   +-----------+    +-----------+         |
|   | MEDKIT 5  |    | AMMO 4    |         |
|   +-----------+    +-----------+         |
|  ACTIONS (o)(o)( )    "Last street of wave"|  3 action pips; banner when the deck can't refill
|------------------------------------------|
| +-------------------+ +-----------------+|
| | 1  SERVICE PISTOL | | 2  MACHETE      ||  both slots always visible
| | P3   ||||..  4/6  | | P5   inf        ||  magazine pips (filled = rounds)
| | hits under 9      | | hits under 7    ||  notch tag (v1 style)
| | [ RELOAD  6 > 6 ] | |                 ||  reload shows "rounds lost > rounds loaded"
| +-------------------+ +-----------------+|
|  Reserve ammo 11          [ SKIP STREET ]|  skip shows why it's off ("skipped last street")
|  > Lurcher 7: Machete blocked 5, -2 HP, +40 pts   |  one-line log; HP / points float up
+------------------------------------------+
```

**Fighting a zombie** (tap it): a bottom sheet with up to three big buttons, each with its full preview:
`PISTOL  -4 HP  uses 1 round  notch becomes 7` / `MACHETE  -2 HP  notch becomes 7` / `BARE  -7 HP  +10 up close`.
A blocked option stays visible but grayed with the reason ("mag empty - reload", "hits under 7").

**Weapon card** (tap it): `INTO SLOT 1 (scrap Pistol, +10)` / `INTO SLOT 2` / `SCRAP +10`, with the two current slot cards shown small for comparison.

**Reload** (tap the button): it previews `drop 2 rounds, load 6 of 11, notch clears`. It counts as an action, so an action pip fills. The button is hidden when nothing would change, and shows "free" during Sleight of Hand, Fast Hands or the boss street.

**Machines** (tap USE): a sheet with the machine card zoomed, the price, the effect (Retrofit shows the before/after weapon card; Grin shows the 6 Jawbreakers and their odds; Locker shows its odds), and a single `PAY 300` button. The result is shown as a zoomed card ("You got: Steady Aim - guns +2 power this wave").

**Wave change:** a full-width banner, "WAVE 3 - 5 zombies (6-11) + 3 skipped + 2 restock", with the cards fanning into the deck. It takes about 1.5 s and can be tapped to skip.

### 6.2 Phone landscape (~844 x 390)

```
+---------------+------------------------------------------+-----------------+
| WAVE 1 2 [3] B| +-------+ +-------+ +-------+ +-------+  | 1 PISTOL  P3    |
| HP 14/20  C 2 | | Z 7   | | W 6/4 | | M 5   | | A 4   |  |  ||||..  <9     |
| Pts 1,240     | +-------+ +-------+ +-------+ +-------+  | [RELOAD 6>6]    |
| Deck 7 (4Z)   |       ACTIONS (o)(o)( )                  | 2 MACHETE P5    |
| Skipped 3 >   |  > Lurcher 7: Machete blocked 5, -2 HP   |  inf   <7       |
| DOORS (list)  |                                          | Reserve 11      |
| [machine USE] |                                          | [ SKIP STREET ] |
+---------------+------------------------------------------+-----------------+
```

The street becomes a 1 x 4 row; status and doors on the left, weapons and actions on the right (thumb side). Minimum tap target 64 px in both orientations.

---

## 7. Questions for the studio head

Answer on the Studio Floor task `dd-v2-design`. Recommended options are marked.

**Q1. Deck structure: how do waves and room loot meet?**
- (a) **One mixed deck (recommended).** Wave zombies + loot in one deck; the deck running out *is* the wave ending; Skip sends cards to the Skipped pile, which returns with the next wave. Evidence: 32-39% run win, 12.3-minute wins, skipping worth 5-9 points of run win, more reload and slot decisions (5.3).
- (b) Separate stacks: a zombies-only wave deck plus a loot deck, 2 + 2 slots per street. Evidence: 22-35% run win at the same content, 9.7-minute wins, clearer wave read, but skipping only reorders the wave and buying rooms changes less (5.3).
- (c) v2 first draft: each deck is a room (10 cards), doors between rooms. Dropped after your wave direction; it played well but had no wave escalation.

**Q2. Combat model for guns.**
- (a) **Hybrid (recommended):** v1 notch on every weapon + guns spend 1 round per kill; reload refills the mag and clears the notch; melee unlimited, its notch clears each wave. Evidence: 32-39% run win, 7-8 HP left on a win, reacts smoothly to tuning (5.1, 5.2).
- (b) Damage model: no notch, guns reduce damage per round (double tap for 2 rounds), melee weaker but unlimited. Evidence: 100% run win with the same content and still 92-96% with every zombie up to +6 stronger; runs end at 22 HP (5.2).
- (c) Notch-only guns (v1 + reload button, no magazine). Not simulated: it drops the ammo economy you asked for.

**Q3. What does a reload cost?**
- (a) **One of your 3 actions, max one per street, and the rounds left in the mag are dropped (recommended).** Same balance as top-up (5.4), but it keeps the notch meaningful for guns.
- (b) One action, rounds in the mag are kept (top-up). Same win rates (32-41%), slightly more reloads; friendlier, but a 1-round reload clears a notch almost for free.
- (c) Free, but only between streets (cost = reserve ammo only). Not recommended: it removes the "reload now or fight" decision, which is the point of reloading.

**Q4. How does a run end?**
- (a) **3 districts x 3 waves, boss at the end of each district, win = beat Patient Zero (recommended).** Keeps v1's face-up finales, safehouses, perks and a 10-12 minute win.
- (b) One map, survive 10 waves (closer to the genre), no districts: simpler, but loses the map change and the safehouse moment; a win would take about 14 minutes.
- (c) (a) now, plus an **Endless** mode later (waves keep coming after Patient Zero, score = points), which gives the genre's "how far can you go" chase without hurting the main run's length.

**Q5. Melee is underused. Do we boost it?** In the tuned sim the AI makes only about 4 melee kills per run against about 30 gun kills (plus about 3 bare-handed), because guns with Retrofit and Wall Racks out-power melee and reloads are cheap enough.
- (a) **Yes, small boost before the build (recommended):** up-close kills pay **+30** instead of +10 (points for risk, as in the genre), and melee weapons get **+1 power**. We retune with the sim afterwards.
- (b) Leave it: melee is a backup for when the mag is empty, and that's fine.
- (c) Bigger change: melee kills don't notch at all (truly unlimited), with melee power -2 to compensate.

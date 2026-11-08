# DeadDraw - Core Rules v3 ("Kill Stacks")

Owner: Sr Game Designer | Board task: `dd-v3-design` | Engine: Godot 4.4.1 (GDScript), Web export, phone portrait + landscape
Status: **proposal for the studio head (questions in section 9).** v2 (`core-rules-v2.md`, `tools/sim_deaddraw_v2.py`, the live build in `source/`) is untouched until v3 is approved and built.
Balance source of truth for v3: `projects/deaddraw/tools/sim_deaddraw_v3.py` (`CONFIG`). If this document and the sim disagree, the sim wins and this document gets fixed.

> **Naming and IP.** v3 keeps the *feel* of round-based zombie survival modes in shooters. Every machine, perk, weapon and mode name in this document is original to DeadDraw. Do not use any shooter series' trademarked or signature names (upgrade machines, soda perks, gums, mystery boxes, wonder weapons) in the game, store text, code or file names. The repo is public.

---

## 0. Vision

**One sentence:** Waves of zombies shuffle into one deck, you shoot them in an order your gun's rule allows, and every gun you fill pays out the points that open the next room.

**What v3 changes, in one breath:** the board now shows its own machinery. **Wave decks** wait on the left, **room decks** with their prices wait on the right, and both are visibly **shuffled into the draw pile** in the middle. Guns no longer have magazines or Reload: each gun has a **rule** for the order of its kills (going down, going up, the same number, zig-zag...) and a **capacity**. Every kill is **stacked on the gun** like a board game. When the stack is full the gun is **finished**: you **collect** the stack as points, check the gun's **challenge** for a bonus, and the gun leaves your hand. Guns rotate every few streets. Two machines complete the genre: the **Retrofit Bench** reworks your equipped gun, and the **Patch Press** sews a permanent perk onto your jacket.

**Design pillars**
1. **Every card is a choice you can read.** A gun's rule, its top kill and the numbers it can still take are always visible. The only hidden information is the order of the pile.
2. **Order matters more than luck.** Which zombie goes on which stack, in what order, decides your HP and your payout.
3. **Rotation, not hoarding.** Guns are spent in 2-5 kills. You are always finishing one and picking up the next.
4. **One thumb, any screen.** Pick the active weapon once, then each tap on a zombie attacks. Everything is inspectable (long press / right click).
5. **Spend to survive.** Points are the second resource next to HP. Rooms are where the healing and the next guns are.

**Target emotion:** the "click" of a stack that lines up (4-5-6!), the relief of a finished gun paying out just in time to open a door, and the dread of a final boss you can't walk away from.

---

## 1. Run structure

| Level | What it is | Count |
|---|---|---|
| **Run** | 3 districts in a fixed order: Maple Row, Downtown, St. Agnes Hospital. Win = beat Patient Zero. | 1 |
| **District** | 3 wave decks + 1 boss, 3 rooms, 1 free Entrance. A safehouse follows districts 1 and 2. | 3 |
| **Wave** | A face-down deck on the left. It is shuffled into the draw pile when the pile runs dry. | 9 per run |
| **Street** | Deal 4 cards from the pile, resolve 3, 1 stays (the Holdover). | ~37 per run |
| **Room** | A deck on the right with a price. Open it any time you have the points: its cards shuffle into the pile and its machine switches on. | 3 per district |

Weapons, points, Patches and HP carry between districts. Rooms, machines and the pile reset.

---

## 2. The board and the decks

### 2.1 Three zones

- **Left - wave decks.** Wave 1, Wave 2, Wave 3 stacked top to bottom, then the **boss card face up** at the bottom (the planning target, as in v1/v2). Each wave deck shows its card count and its number range ("7 cards - zombies 4-9"). Long press = the exact list of numbers in that wave (zombie numbers are public; only the order is hidden).
- **Middle - the draw pile.** One face-down pile, top middle. Its counter reads "12 cards - 9 zombies". Long press = what is in it by type and number (counts, not order).
- **Right - room decks.** Three rooms, each a small deck with its **price** and an **OPEN** button, its machine icon, and its contents (long press). The button is lit when you can pay. Rooms can be opened **in any order, at any time between taps** (not in the middle of a single attack).

### 2.2 When cards shuffle in (always animated)

| Event | What moves | Animation |
|---|---|---|
| District start | Entrance cards (3) + Wave 1 deck fly to the middle | riffle shuffle, 1.5 s |
| Pile runs dry while dealing | The next wave deck slides from the left into the middle and is shuffled; dealing continues | wave banner "WAVE 2 - 7 cards, 4-9" + shuffle, 2 s |
| ...plus restock | Each opened room sends **1 card** of its pack (cycling through its list) along with the new wave | the room deck flicks a card into the pile |
| Open a room | Its 3 cards fly into the middle at once and are shuffled in; the room turns into its machine | door swings open, cards fly, shuffle, 1.5 s |
| Run | The 4 street cards fly back into the middle and are shuffled in | reverse deal, 1 s |
| Boss street | When Wave 3 is spent and at most 1 card is left on the street, the boss card(s) slide from the left onto the street next to the Holdover | boss intro, 2 s |

**Rule the player learns:** *the pile never ends while a wave is waiting; the boss comes when every wave is gone.*

### 2.3 Card types in the pile

| Card | Effect |
|---|---|
| **Zombie N** (1-11) | Fight it with a gun, or melee. Its number is its strength **and** its point value. |
| **Gun** (named) | Equip into slot 1 or 2, or scrap it (+2 points). Equipping over a gun collects that gun early (5.4). |
| **Medkit N** (3-7) | Heal N (max 1 medkit per street; a second one is discarded). |
| **Cover N** (2-4) | Gain N Cover: absorbs damage before HP. |

Machines are not cards: they live on the room tile once opened (section 6).

---

## 3. The street (turn)

**Kept from v1/v2: deal to 4, resolve 3, 1 Holdover.** Resolving a card is one action; equipping or scrapping a gun and using a medkit or cover are also resolutions. Opening a room and using machines are free and happen between actions.

**Run.** Before you resolve anything, you may **Run**: the 4 street cards are shuffled back into the pile and you take **1 damage** (Theo: none). You can't Run two streets in a row, and never on a boss street. (v2's Skipped pile is cut: shuffling back is easier to read and needs no extra pile on screen. The wave still has to be fought; Run only buys a different mix.)

**Why 4 / 3 (sim, section 8.3):** it is the best mix of taps-per-street, decisions and run length. 5 / 4 adds a tap per street and makes the game much easier (53-65% win) for only slightly more decisions; 3 / 2 is cramped, long (49+ streets) and hard; 4 / 4 (no Holdover) forces you to take every zombie and win rate collapses to 10-14%. A street is about **4.3 taps** (3 card taps + roughly 0.6 weapon toggles + occasional room/machine taps).

**Wave end.** No special step: when the pile runs dry, the next wave is shuffled in. The wave counter on the left lights the active wave. A wave change resets "once per wave" things (machines, Loose Grip).

---

## 4. Combat

### 4.1 Slots and the active weapon

You have **Gun slot 1, Gun slot 2 and Melee** (always there). You start with a **Service Pistol** in slot 1 and slot 2 empty.

**Active weapon:** one of the three is **active** (highlighted). Tap a weapon card to make it active; every tap on a zombie then attacks it with the active weapon. No pop-up, no per-tap choice. If the active gun's rule forbids that zombie, the zombie card shows a red "rule" lock **before** you tap, and tapping it just shakes the card (no turn spent). Zombies the active weapon *can* take show the damage you'll take (e.g. a "-2" chip) and where the zombie would land on the stack.

### 4.2 Damage

**Damage = zombie number - weapon power** (minimum 0), Cover first. Every fight kills the zombie. That is the v1 core, unchanged.

### 4.3 Guns: rule, capacity, stack

- A gun has **power**, **capacity** (kills until it is finished) and a **rule** that checks each new kill against its stack.
- Each kill is placed **on the gun's stack**, fanned so each zombie's number (top-left corner) stays visible.
- When the stack reaches capacity the gun is **finished** (5.2). Guns never run dry another way: no magazine, no ammo, no Reload.

### 4.4 Melee

**Crowbar, power 2, no rule, unlimited, always available.** Melee kills **do not stack and pay no points** (the zombie goes to the discard). Melee is the escape valve: the zombie your guns can't legally take, or a tiny zombie you don't want to waste a gun slot on. (Brawler Patch: +2 power.) With melee at 0 points, the AI still makes ~4-5 melee kills per run out of ~56 (section 8).

### 4.5 The guns (9 types)

| Gun | Rule (each new kill must be...) | Power | Capacity | Challenge | Reward | Where |
|---|---|---|---|---|---|---|
| **Service Pistol** | anything (no rule) | 2 | 4 | *Mixed Bag*: 4 different numbers | +5 points | start, Maple Row loot |
| **Hunting Rifle** | **lower** than the top kill (the classic notch) | 4 | 4 | *Countdown*: the last 3 kills go down by exactly 1 (6-5-4) | heal 4 | Maple Row, Downtown |
| **Ratchet Crossbow** | **higher** than the top kill | 3 | 4 | *Staircase*: 3 consecutive numbers in a row going up (4-5-6) | **Encore**: the gun stays, its stack resets | all districts; Maple Row Wall Rack (10) |
| **Twin-Bore** | the **same number** as the first kill | 5 | 3 | *Big Game*: the number is 6 or more | +10 points | all districts |
| **Lever Rifle** | **zig-zag**: if the last step went up, this one goes down (and vice versa); never equal | 4 | 5 | *Wide Swing*: every step is 2 or more apart | +3 Cover | Downtown, St. Agnes |
| **Scout Carbine** | **within 1** of the top kill (equal is fine) | 3 | 5 | *Drift*: the last kill is 3+ away from the first | +8 points | all districts |
| **Nail Driver** | **odd after even, even after odd** | 3 | 4 | *Full Spread*: 4 different numbers | heal 3 | Maple Row |
| **Pump Shotgun** | anything, as long as the **stack total stays at 16 or less**; finished at 4 kills or a total of 16 | 5 | 4 / 16 | *Point Blank*: the total is exactly 16 | heal 5 | Downtown, St. Agnes; Downtown Wall Rack (14) |
| **Elephant Gun** | **6 or more** only | 6 | 2 | *Trophy*: both kills 8+ | +10 points | St. Agnes; St. Agnes Wall Rack (16) |

Design notes:
- **Lower numbers than v2.** Powers are 2-6 (v2: 3-9) against zombies 1-11 (v2: 2-16). Each point of power matters, which is why the rule is the price of a strong gun: the Twin-Bore hits 5 but only takes one number.
- **Up vs down.** The Rifle and the Crossbow are mirror images, and the Retrofit Bench can Flip one into the other. The Crossbow's challenge is the studio head's example (three consecutive numbers in a row going up); its reward, Encore, keeps the gun in hand, so a perfect Crossbow rotates itself.
- **The boss guns.** The district bosses are drawn for specific rules: the Rush Hour Horde is 6-6-6 (a Twin-Bore's dream) and Patient Zero is 8 -> 10 -> 12 (perfect for a Crossbow, Lever Rifle or Elephant Gun, terrible for a Hunting Rifle).
- **Rosa (Steady Hands):** for her, the Rifle and Crossbow also accept an **equal** number.

---

## 5. Points and the kill stack

### 5.1 Points (shown x10 on screen, like v2: a 7 is "70")

| Source | Points |
|---|---|
| **Finish a gun** (stack full) | **sum of the stack + 3** finish bonus, then its challenge reward |
| Replace a gun before it's finished | **half the stack** (rounded down), no bonus, no challenge |
| Melee kill | 0 |
| Scrap a gun card | +2 |
| Beat a district boss | +10 and a free Patch (pick 1 of 3) |
| Beat Patient Zero | +10 (score) |

So **a zombie's number is its point value, paid when its gun is collected.** A strong run earns about **350 points** (3,500 on screen) and spends about **310**: rooms 15-38, Patches 15/25/35..., Bench 5-12, Wall guns 10-16.

### 5.2 "Collect" (finishing a gun)

When the last kill lands:
1. The gun card flips to its back, the stack slides off it and **counts up** into the points counter, one card at a time ("4 + 5 + 6 + 3 = 18").
2. If the **challenge** is met, its badge stamps the card ("STAIRCASE!") and the reward plays (heal / cover / points / Encore).
3. The gun goes to the discard (Encore: it stays with an empty stack). The slot is empty until you equip a new gun.

### 5.3 Why points arrive in bursts

Banking on collect makes the economy a **race against your own guns**: you can see "this Rifle has 4-3 on it, one more kill and it pays 13 + 3", and a room you can't quite afford becomes one well-placed kill away. It also makes the half-value rule for an early swap a real decision. (Question Q1 offers points per kill as the alternative.)

### 5.4 Replacing a gun early

Equipping a gun into an occupied slot collects the old gun at **half value** (no bonus, no challenge). It is the answer to a stack that has painted itself into a corner (a Rifle sitting on a 2), and it costs you. The Bench's Trim (6.1) is the paid alternative that keeps the gun.

---

## 6. Rooms and machines

Each district has a free **Entrance** (3 cards, in the pile from the start) and **3 rooms**. Prices and contents are on the room deck; any order.

| District | Room (price) - machine - pack (3 cards) |
|---|---|
| Maple Row | **Garage** (15) - Wall Rack: Ratchet Crossbow - gun, medkit 4, cover 2 \| **Corner Store** (22) - Patch Press - medkit 5, medkit 3, gun \| **Workshop** (31) - Retrofit Bench - gun, medkit 5, cover 3 |
| Downtown | **Subway Kiosk** (19) - Patch Press - medkit 4, gun, medkit 5 \| **Pawn Shop** (25) - Wall Rack: Pump Shotgun - gun, cover 3, gun \| **Parking Garage** (35) - Retrofit Bench - gun, medkit 6, cover 3 |
| St. Agnes | **Pharmacy** (20) - Patch Press - medkit 5, medkit 6, medkit 4 \| **Security Office** (28) - Wall Rack: Elephant Gun - gun, cover 3, medkit 5 \| **Morgue Lab** (38) - Retrofit Bench - gun, medkit 6, cover 4 |

Entrance: Maple Row gun, medkit 4, cover 2; Downtown gun, medkit 5, cover 2; St. Agnes gun, medkit 6, cover 3. Opened rooms **restock 1 card per new wave** (cycling through their pack). "Gun" cards are drawn from the district's gun list (4.5).

Every machine: **free action between taps, once per wave**, price on the machine, long press for full rules.

### 6.1 Retrofit Bench (upgrade machine, original)

A grimy workbench with a hand-cranked lathe and a jar of mismatched bolts. It works on **one equipped gun** (drag the gun onto the bench, or tap the bench then the gun). Pick one service:

| Service | Price | Effect |
|---|---|---|
| **Trim** | 5 | Remove the **top kill** from the stack (it is banked now at face value). The gun's rule now checks against the kill below, and it gains back one capacity. Unsticks a Rifle on a 2 or a Crossbow on a 9. |
| **Flip** | 8 | Reverse a directional gun: **Rifle <-> Crossbow rule** (down becomes up). The card gets a brass arrow plate. |
| **Hone** | 12 | **+1 power**, permanent for that gun, once per gun ("Honed" plate). |

### 6.2 Patch Press (perk machine, original)

A rusty heat press that stamps embroidered patches onto your jacket. Pay, it shows **2 random Patches**, take one. **Permanent for the run**, shown as patches on the survivor portrait (inspectable). Price rises with every Patch you own: **15, 25, 35, 45...** Beating a district boss gives a free Patch (pick 1 of 3).

| Patch | Effect |
|---|---|
| **Lookout** | You always see the **top card of the pile**. Once per street, before the deal, you may send it to the bottom. |
| **Thick Jacket** | +4 max HP (and heal 4). |
| **Field Medic** | Medkits heal +2. |
| **Brawler** | Melee +2 power. |
| **Bounty Hunter** | Finishing a gun pays +1 per zombie in its stack. |
| **Loose Grip** | Once per wave, one gun kill may **ignore its rule** (the card shows a "bent rule" icon). |
| **Second Wind** | Once per run, when you would drop to 0 HP, you go to 6 instead. |
| **Trophy Belt** | Heal 2 whenever you finish a gun. |

### 6.3 Wall Rack (kept from v2)

A chalk-outlined gun on hooks: buy **that specific gun** into a slot (price on the outline). Once per wave. It is the reliable way to get a rule you want (the Crossbow before Patient Zero, the Shotgun for a pile of small zombies).

---

## 7. Bosses, survivors, HP and the end of a run

### 7.1 Bosses

When the last wave is spent and at most one card is left on the street, the **boss street** is the Holdover plus the boss card(s). Resolve every card.

| District | Boss | Rule |
|---|---|---|
| Maple Row | **The Groundskeeper** 9 | *Shatter*: the gun that kills it is finished at once (collected with the bonus, no challenge). Melee is not affected. |
| Downtown | **Rush Hour Horde** 6 / 6 / 6 | *Horde*: all three at once. |
| St. Agnes | **Patient Zero** 8 -> 10 -> 12 | *Phases*: the next phase appears only when the previous one is dead. **You cannot Run from Patient Zero** and there is no way past it. |

**Run past (district bosses only):** you may skip the boss street of Maple Row or Downtown: take **3 damage** and lose the boss reward (+10 and the free Patch). The AI does this ~0.4 times per run, almost always in Downtown when it is low on HP. Patient Zero has no Run button at all: the street shows a chained "NO ESCAPE" banner.

### 7.2 Survivors (kept, passives adapted)

| Survivor | HP | Passive |
|---|---|---|
| Rosa Vance | 20 | *Steady Hands*: Rifle/Crossbow rules accept equal numbers. |
| Dr. Imani Hale | 20 | *Triage*: medkits heal +1. |
| Theo Park | **21** | *Slip Away*: Run costs no HP. (Unlock: first Downtown clear, as in v2.) |

### 7.3 Safehouse (kept, smaller)

Between districts: **heal 8**. That's all: perks now come from the Patch Press and the boss reward, so the safehouse is a breather, not a menu.

### 7.4 How a run ends

- **Win:** beat Patient Zero. Score = all points earned (spending doesn't lower it) + 10 x HP left.
- **Loss:** HP hits 0 (Second Wind once). Meta unlocks as in v2.

---

## 8. Balance simulation

**Tool:** `projects/deaddraw/tools/sim_deaddraw_v3.py` (Python 3, standard library, multiprocessing). v1 and v2 sims are untouched.

```
python3 projects/deaddraw/tools/sim_deaddraw_v3.py --runs 1000 --seed 7
python3 projects/deaddraw/tools/sim_deaddraw_v3.py --set street_size=5 --set actions=4
python3 projects/deaddraw/tools/sim_deaddraw_v3.py --set allow_run=false --ai greedy=true
```

**AI ("strong").** Each street it searches every ordered choice of 3 cards with every legal weapon for each zombie (gun 1, gun 2, melee; Loose Grip as an extra option), every equip choice (slot 1 / slot 2 / scrap) and the Holdover, and scores the result as `HP + 0.7 x Cover + 0.30 x points + sum over guns of [0.12 x (power+1) x remaining kills (cap 4) x (0.15 + 0.85 x share of upcoming zombies its rule still allows) + 0.24 x stack total] - 0.5 x Holdover zombie`. "Upcoming zombies" = the pile plus the next wave deck (public information). It Runs when the best plan loses more than its running average + 1 + 3. Between streets it opens the cheapest affordable room, buys a Patch whenever affordable (priority list), uses the Bench (Trim a blocked stack, Flip a blocked Rifle/Crossbow, Hone a gun with 3+ kills left), and buys a Wall gun if a slot is empty or much weaker. Weights were chosen by a grid search for the highest win rate (strong AI = 0.12 / 0.30; e.g. 0.30 / 0.12 wins 23% instead of 37% at the same rules).

**Time model (seconds):** 4 per street (read + deal) + 1.1 per tap + 1.2 per collect + 1.5 per challenge + 2.5 per wave shuffle-in + 3.5 per room + 5 per machine use + 2 per Run + 4 per boss + 12 per safehouse. Taps = card taps + active-weapon toggles + 1 per Run + 2 per room + 3 per machine.

### 8.1 Proposed rules, 1000 runs per survivor, seed 7 (strong AI)

| Survivor | Clear Maple Row | Clear Downtown (of those who reach it) | Clear St. Agnes (of those who reach it) | **Run win** | HP left on a win | Streets | Taps | **Winning run** | Average run |
|---|---|---|---|---|---|---|---|---|---|
| Rosa | 91.5% | 82.2% | 47.9% | **36.0%** | 6.0 | 37.4 | 164 | **8.9 min** | 7.6 min |
| Imani | 94.6% | 79.7% | 52.7% | **39.7%** | 6.2 | 37.7 | 165 | **8.8 min** | 7.6 min |
| Theo | 94.9% | 81.0% | 48.9% | **37.6%** | 6.3 | 39.0 | 166 | **8.9 min** | 7.8 min |

- All three survivors are inside **30-42%** (36-40%), within 4 points of each other (sampling error about +/-3).
- **Difficulty curve:** Maple Row teaches (92-95% clear), Downtown stops ~1 in 5, St. Agnes / Patient Zero stops ~1 in 2.
- **Run length:** a winning run is **8.8-8.9 minutes** at the AI's pace (4 s of thinking per street). A first-time player who thinks 6 s per street adds ~1.3 minutes (about 10 minutes). The average run is shorter (7.6 min) because losses end early.
- **Taps:** **4.3-4.4 per street** (3 card taps + 0.6 weapon toggles + room / machine / Run taps), about 165 per run.

### 8.2 Decisions per run (Rosa / Imani / Theo)

| Decision | How often | Notes |
|---|---|---|
| Fights | 56 / 57 / 57 | gun kills 52.7 / 52.0 / 52.5, melee 3.6 / 4.9 / 4.5 |
| ... with at least one gun legal | 91 / 89 / 90% of fights | melee is always legal, so the player nearly always has a real gun-vs-melee choice |
| ... with **both guns legal** | 56 / 52 / 53% | the slot choice is real in half the fights |
| ... where 2+ weapons cost the **same damage** (the stack decides) | 30 / 28 / 29% | "which stack does this 5 go on?" |
| ... where the AI **took more damage on purpose** (not the minimum-damage weapon) | **13.3 / 12.9 / 12.4%** (~7 fights a run) | to keep a rule open, line up a challenge or finish a gun |
| Streets where the weapon choice changed the plan's value by > 0.5 HP | 7.6 / 7.5 / 6.8% | vs. a "minimum damage" plan |
| Active-weapon toggles | 23 / 24 / 24 | ~0.6 per street |
| **Guns finished (collected)** | **11.3 / 10.7 / 10.7** | a new gun every ~3.5 streets: the rotation the head asked for |
| **Challenges completed** | **5.1 / 5.3 / 5.4** | about half the finished guns |
| Guns replaced early (half pay) | 6.3 / 6.9 / 7.3 | |
| Gun cards equipped / scrapped | 14.3 / 6.6 (Rosa) | |
| **Rooms opened** (of 9) | **7.5 / 7.4 / 7.5** | |
| **Machine uses** | **7.2 / 6.8 / 6.9** | Patch Press 2.3-2.4, Wall Rack 2.4-2.7, Bench Trim 1.0, Hone 1.0, Flip 0.1 |
| Runs taken / close calls | 1.7 / 1.9 / 3.0 and 2.3 / 2.5 / 3.7 | Theo's free Run makes it a live option twice as often |
| Boss run-past (districts 1-2) | 0.43 / 0.45 / 0.54 | |
| Points earned / spent | 356 / 318 (Rosa) | 3,560 on screen |

**Per gun (Rosa, finished per run / challenge per run):** Pistol 1.2 / 0.8, Hunting Rifle 1.4 / 0.3, Crossbow 1.7 / 0.5, Twin-Bore 0.5 / 0.3, Lever Rifle 1.5 / 0.5, Carbine 0.9 / 0.3, Nail Driver 0.6 / 0.4, Pump Shotgun 1.9 / 1.3, Elephant Gun 1.5 / 0.8. Every gun is finished at least about once every two runs; the Shotgun's exact-16 challenge is the most common (1.3), the Rifle's and Carbine's the rarest (0.3). The Twin-Bore is the least finished (it needs the duplicates in 8.6).

### 8.3 Street size (evidence for section 3, 300 runs per survivor, same content)

| Street | Run win (R / I / T) | Streets | Winning run | Choice mattered (streets) | Took extra damage (fights) |
|---|---|---|---|---|---|
| **Deal 4, resolve 3 (proposed)** | 36.7 / 37.3 / 40.0% | 37-39 | 8.9 min | 7.3% | 12.5% |
| Deal 5, resolve 4 | 56.0 / 65.3 / 52.7% | 31 | 8.3 min | 10.2% | 15.6% |
| Deal 3, resolve 2 | 12.7 / 15.7 / 16.3% | 49-53 | 10.2 min | 4.3% | 9.2% |
| Deal 4, resolve 4 (no Holdover) | 10.3 / 14.0 / 11.3% | 23 | 8.4 min | 6.9% | 13.0% |

Reading: 5 / 4 gives slightly more decisions per street but one more tap per street and is much easier (it would need +1 zombie strength everywhere to retune). 3 / 2 is cramped and long; 4 / 4 removes the Holdover and the game collapses (you must take every zombie). **4 / 3 stays.** 5 / 4 is the fallback if playtests find streets too tight.

### 8.4 Ablations (300 runs per survivor)

| Change | Run win (R / I / T) | What it shows |
|---|---|---|
| **Rules off** (every gun takes anything) | 75.0 / 82.3 / 79.3% | The rules *are* the game: without them it's v1 with no notch. Guns finished 17.6, Bench unused. |
| Always pick the minimum-damage weapon (strong AI otherwise) | 32.0 / 31.7 / 33.7% | Planning stacks is worth ~5 points of run win on top. |
| Naive AI (values gun life over points, minimum damage) | 0.7 / 0.3 / 0.0% | Hoarding guns loses: you must finish guns to afford rooms. **Tutorial must teach "finish guns to get paid".** |
| Mid AI (weights 0.20 / 0.20) | 8.0% (Rosa) | Steep skill gradient (see Q5). |
| No Run | 35.3 / 37.0 / 35.0% | Run is worth only 1-3 points: a safety valve, not a strategy. |
| Patch Press off (boss Patches kept) | 7.3% (Rosa) | Patches are worth ~29 points of run win: the perk machine is central. |
| Retrofit Bench off | 30.0% (Rosa) | Bench is worth ~6 points. |
| Melee kills pay half their number | 33.3 / 36.7 / 44.3% | Melee kills double (7.5-9.9) at about the same win rate (Q2). |
| Early replace pays **full** stack | 33.7 / 46.0 / 42.0% | Guns finished drops 11 -> 8, replaced early 6 -> 15: rotation by swapping, not finishing. |
| Early replace pays **nothing** | 25.7 / 25.3 / 22.3% | Harsh; players would hang on to dead guns. |

### 8.5 AI weights and tuning path

The value-function weights matter a lot (0.30 / 0.12 wins 23% where 0.12 / 0.30 wins 37% at the same rules), so the "strong AI" is the best of a 3 x 3 grid plus follow-ups (carry 0.3-0.8, stack weight 0.8-1.0, run margin 1.5-6 all within noise). Tuning: first draft (zombies 1-9 in every district, rooms 12-30) won 85-93%; melee then paid points and made ~40 melee kills a run, so melee points went to 0. Downtown and St. Agnes zombies +1 and rooms x1.25 gave 37-49%; the Nail Driver went from power 2 / capacity 5 (finished 0.15 a run) to 3 / 4; Wide Swing from 3+ to 2+ apart; Maple Row wave 3 +1; Triage +2 -> +1; Theo 20 -> 22 -> 21 HP. Final: 36-40%.

### 8.6 Zombie numbers (the distribution, designed for the rules)

| District | Wave 1 | Wave 2 | Wave 3 | Boss |
|---|---|---|---|---|
| Maple Row | 1, 2, 3, 3, 4, 5 + gun | 2, 3, 4, 4, 5, 6, 7 + gun | 4, 5, 5, 6, 7, 8, 9 + gun | Groundskeeper 9 |
| Downtown | 3, 4, 5, 5, 6, 7 + gun | 4, 5, 6, 7, 7, 8, 9 + gun | 5, 6, 7, 8, 8, 9, 10 + gun | Horde 6 / 6 / 6 |
| St. Agnes | 4, 5, 6, 6, 7, 8 + gun | 5, 6, 7, 8, 8, 9, 10 + gun | 6, 7, 8, 9, 9, 10, 11 + gun | Patient Zero 8 -> 10 -> 12 |

**Per district (count of each number):**
- Maple Row: 1x1, 2x2, 3x3, 4x4, 5x4, 6x2, 7x2, 8x1, 9x1 (20 zombies)
- Downtown: 3x1, 4x2, 5x4, 6x3 (+3 Horde), 7x4, 8x3, 9x2, 10x1 (20 + 3)
- St. Agnes: 4x1, 5x2, 6x4, 7x3, 8x4 (+1 boss), 9x3, 10x2 (+1), 11x1 (20 + 3)

Design rules behind it:
- **Every wave has exactly one pair** and each district has two numbers with 4 copies: that is what makes the Twin-Bore (same number) and the Carbine (within 1) playable, and why the Horde is a triple.
- **Every wave is a run of consecutive numbers** with one gap at most, so Countdown (Rifle) and Staircase (Crossbow) are reachable inside one wave.
- **Both parities in every wave**, roughly balanced, for the Nail Driver.
- **Numbers rise by about 1 per wave and 1 per district**, so an Up gun loves a new wave arriving and a Down gun loves the start of one (the pile is a mix of the old wave's tail and the new wave).
- **Totals for the Shotgun:** average zombie ~5.5-7.5, so 16 is "two big and one small" or "four small": a real packing puzzle.

---

## 9. Questions for the studio head

**Q1. When do kills turn into points?**
- (a) **On collect (recommended, simulated):** the stack pays (sum + 3) when the gun is finished; half if you swap it early. Points come in visible bursts and finishing a gun is the goal. 36-40% win.
- (b) Per kill, at once (the zombie's number), and finishing only pays the +3 and the challenge. Simpler to read, but there is no reason to finish a gun except the challenge, so guns would be swapped more (the "full pay" ablation: finished 11 -> 8, swaps 6 -> 15).
- (c) On collect, but an early swap pays nothing. Harsher (22-26% win), players hang on to dead guns.

**Q2. What does a melee kill give?**
- (a) **Nothing (recommended, tuned):** melee is the free escape valve (power 2, no rule), guns are where points come from. ~4-5 melee kills per run.
- (b) Half the zombie's number, banked at once. Melee kills double (7-10 per run), win rate about the same (33-44%); a bit more "up close" flavor but blurs "shoot to score".
- (c) Full number, but melee kills cost +1 damage. Not simulated; most like v2's "up close" bonus.

**Q3. Run (shuffle the street back, 1 damage, not twice in a row).**
- (a) **Keep it as a safety valve (recommended):** worth 1-3 points of win, used ~2 times a run, gives Theo his identity and makes "you can't run from Patient Zero" mean something.
- (b) Cut it: one less button; Theo needs a new passive.
- (c) Make it free (no damage) for everyone, Theo gets another passive.

**Q4. Street size.**
- (a) **Keep deal 4, resolve 3 (recommended):** best decision density per tap, 8.9-minute wins (8.3).
- (b) Deal 5, resolve 4: slightly more decisions, +1 tap per street, needs a difficulty retune (52-65% win as is).

**Q5. The skill curve is steep. Do we soften it?** The strong AI wins 36-40%, an AI with good intentions but worse priorities wins 8%, and one that hoards guns wins under 1% (8.4). Humans will learn "finish guns, spend points" quickly, but a first run could feel brutal.
- (a) **Add a soft start (recommended):** first run only, Maple Row wave 1 deals the Service Pistol's challenge as a tutorial ("Kill 4 different numbers") and a "Finish guns to get paid" hint the first time a gun is 1 kill from finishing; no balance change.
- (b) Make Maple Row easier for everyone (e.g. Entrance gets a 3rd medkit): run win would rise a few points, stays near the top of the band.
- (c) Leave it: the genre is hard, and runs are 9 minutes.

---

## 10. What we keep, change and cut from v2

| v2 element | v3 | Why |
|---|---|---|
| Street of 4, 3 actions, Holdover | **Kept** (3 resolutions, Reload is gone) | Best taps/decision ratio in the sim (8.3); without the Holdover win rate collapses to 10-14%. |
| Magazine, reserve ammo, Reload, ammo cards | **Cut** | Head: "a bit too much, the weapon stays for too long". Capacity + rule gives rotation every ~3-4 streets; ammo cards became medkit/cover/gun cards. |
| Notch on every weapon | **Became one rule of nine** (Hunting Rifle) | The ordering puzzle stays, but each gun now has its own. |
| Melee notch per wave | **Cut**: melee has no rule, no stack, no points | Melee is the free escape valve; points are the reason to shoot. |
| Skip + Skipped pile | **Changed to Run** (shuffle back, 1 damage) | One fewer pile on screen; no "free" skip at the end of the last wave. |
| Carriers (drop zombies) | **Cut** | Challenges are the new "bonus" moments; carriers would compete with them for attention. |
| Grin Machine (one-wave buffs) | **Cut**, replaced by the **Patch Press** (permanent) | Head asked for permanent perks; one perk machine is enough. |
| Lucky Locker (random gun) | **Cut** | Guns now arrive constantly from rooms and waves; randomness is already in the pile. The Wall Rack is the "known gun" counterpart. |
| Wall Rack | **Kept** | Lets the player chase a rule (Crossbow for Patient Zero). Used ~2.5 times per run. |
| Retrofit Bench (+2 power, +50% mag) | **Kept name, new menu**: Trim / Flip / Hone | Matches the head's "remove cards from the stack, switch direction" ideas. |
| Safehouse heal 15 + perk choice | **Heal 8 only**; perk moved to the boss reward | Perks now come from the Patch Press; safehouse becomes a 3-second breather. |
| Perks (8, v2 list) | **Replaced by 8 Patches** (6.2) | Tied to the new systems (Lookout, Loose Grip, Bounty Hunter, Trophy Belt). |
| 3 districts x 3 waves + face-up bosses | **Kept**; bosses redrawn around gun rules; **Patient Zero can't be run from** | Head request; planning target. |
| Survivors Rosa / Imani / Theo | **Kept**, passives adapted (7.2) | |

---

## 11. Screen layout

Studio rules apply: every card, gun, stack card, wave deck, room deck, machine, Patch and pile opens a zoomed card on **long press (touch) / right click (desktop)**. Clarity over information: the street shows what this tap needs (damage chip, rule lock); the rest is one inspect away.

### 11.1 Phone portrait (main target, ~390 x 844)

```
+------------------------------------------------+
| HP [#########-----] 14/20  Cover 2   Pts 1,240 |  Patches as small badges after HP
| MAPLE ROW                         [NO ESCAPE]* |  * banner only on the Patient Zero street
|------------------------------------------------|
| WAVES        |   DRAW PILE    |  ROOMS         |
| [W1  done ]  |   +--------+   | [Garage   15 ] |  room deck: price + OPEN (lit if affordable)
| [W2 >7 4-9]  |   |  12    |   | [ OPEN      ] |
| [W3  8 4-9]  |   |  9 Z   |   | [Corner St 22] |
| [BOSS  9 ]   |   +--------+   | [Workshop: ⚙ ] |  opened room = its machine button (USE)
|------------------------------------------------|
|  +--------+ +--------+ +--------+ +--------+   |  street: 4 cards in a row (>= 82 px wide)
|  |Z 7  -3 | |Z 4  -0 | |MEDKIT 5| |Z 9 LOCK|   |  chip = damage with the ACTIVE weapon;
|  |        | |        | |        | |  rule  |   |  LOCK = the active gun's rule forbids it
|  +--------+ +--------+ +--------+ +--------+   |
|  resolves (o)(o)( )        [ RUN  -1 HP ]      |
|------------------------------------------------|
| +---------------------+ +---------------------+|
| |[1] HUNTING RIFLE  ▼ | |[2] RATCHET XBOW  ▲  ||  ACTIVE gun has a bright frame
| | P4  cap 4           | | P3  cap 4           ||  left column: power, capacity, rule icon,
| | lower than top      | | higher than top     ||  challenge (check marks as it lines up)
| | ★ Countdown         | | ★ Staircase  ✓✓     ||
| |        +--+         | |        +--+         ||  right column: the KILL STACK, fanned
| |        |6 +--+      | |        |4 +--+      ||  upward, number top-left on each card;
| |        |  |5 |      | |        |  |5 |      ||  "2/4 - pays 11+3" under the stack
| +---------------------+ +---------------------+|
| [ MELEE  Crowbar P2 ]     log: Z7 > Rifle, -3  |  melee is a third, smaller toggle
+------------------------------------------------+
```

**Tap flow.** Tap a weapon (slot 1, slot 2 or melee) to make it active: it lifts and glows, and every zombie on the street re-labels with the damage it would cost ("-3") or a LOCK if the rule forbids it. Tap a zombie to attack with the active weapon. The active weapon **stays active** across streets until you change it; when the active gun is finished, the other gun becomes active (melee if that slot is empty). Non-zombie cards: tap a medkit / cover to use it; tap a gun card to open a 3-button sheet (`INTO SLOT 1 - collects Rifle: +5` / `INTO SLOT 2` / `SCRAP +2`), the only per-tap choice left, because it is not frequent (~7 per run).

**Machines.** Tap an opened room's USE: Bench shows its 3 services with prices and a before/after of the chosen gun; Patch Press shows the 2 patches and `TAKE`; Wall Rack shows its gun card and `BUY 14`.

### 11.2 Phone landscape (~844 x 390)

```
+------------+--------------------------------------------+-------------+
| WAVES      | HP 14/20  C2   Pts 1,240      DRAW [12|9Z] | ROOMS       |
| W1 done    | +------+ +------+ +------+ +------+        | Garage 15   |
| W2 > 7     | |Z7 -3 | |Z4 -0 | |MED 5 | |Z9 LCK|        |  [OPEN]     |
| W3   8     | +------+ +------+ +------+ +------+        | Corner 22   |
| BOSS 9     |  (o)(o)( )                  [RUN -1]       | Workshop ⚙  |
|            +--------------------------------------------+             |
|            | [1 RIFLE ▼ P4 | 6 5 ]  [2 XBOW ▲ P3 | 4 5 ]  [MELEE P2]  |
+------------+--------------------------------------------+-------------+
```

Same zones: waves left, rooms right, pile top-middle, street middle, weapons along the bottom (thumb side). Stacks fan sideways in landscape. Minimum tap target 64 px in both orientations.

### 11.3 What animates

| Moment | Animation | Length |
|---|---|---|
| Wave shuffle-in | the next wave deck slides from the left column into the pile, riffle shuffle, wave banner | 2 s (tap to skip) |
| Room opened | door tile swings open, its 3 cards fly to the pile and shuffle in, the tile becomes the machine | 1.5 s |
| Restock | each opened room flicks 1 card into the pile with the new wave | with the wave |
| Kill | the zombie card flies from the street onto the active gun's stack, landing offset so its number stays visible; stack counter ticks "3/4" | 0.4 s |
| Rule lock | locked zombie shakes; the rule text on the gun pulses | 0.3 s |
| Collect | the stack slides off the gun into the points counter, numbers count up one by one (+finish bonus), the gun card flips and leaves | 1.2 s |
| Challenge complete | gold stamp on the gun ("STAIRCASE!"), reward icon flies to HP / Cover / points; Encore: the gun flips back face up with an empty stack | 1.5 s |
| Bench | the gun slides onto the bench; Trim pops the top card off; Flip spins the rule arrow; Hone adds a brass plate | 1 s |
| Patch | the patch is pressed onto the portrait with a hiss | 1 s |
| Run | the street cards fly back into the pile | 1 s |
| Boss | the boss card slides from the bottom of the left column onto the street; Patient Zero adds the chained NO ESCAPE banner | 2 s |

### 11.4 Inspect (long press / right click)

Zombie: number, damage with each of your three weapons, and which gun rules allow it. Gun: full rule, capacity, challenge, reward, current stack, "can still take: 1-5". Stack card: its number and when it was added. Wave deck: exact list of its numbers. Pile: counts by type/number. Room: price, machine, pack contents, restock. Patch: full text.

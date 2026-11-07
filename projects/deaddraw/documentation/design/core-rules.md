# DeadDraw - Core Rules (v1 prototype)

Owner: Sr Game Designer | Board task: `dd-design` | Engine: Godot 4.4.1 (GDScript), Web export, phone portrait + landscape
Balance source of truth: `projects/deaddraw/tools/sim_deaddraw.py` (`CONFIG`). If this document and the sim disagree, the sim's numbers win and this document gets fixed.

---

## 0. Vision

**One sentence:** Fight your way across a fallen city one street at a time: every street deals four cards, you deal with three, and the fourth is waiting for you on the next one.

**Design pillars**
1. **Every card is a choice you can read.** Four cards, clear numbers, and the damage you will take is shown before you commit. No hidden rolls in the core loop; the only randomness is the shuffle.
2. **Order matters more than luck.** Which three cards, in what order, with which weapon, and when to retreat: the same street can cost 0 HP or kill you.
3. **Short runs, long arcs.** One district takes about 3 minutes and a full run 8-10 minutes. Survivors, perks and unlocks give the next run a reason to exist.
4. **One thumb, any screen.** Playable one-handed in portrait, with every card inspectable by long press or right click.

**Target emotion:** tension that builds as your weapon gets worn down and the deck runs thin, then relief (or a "one more run") at the finale.

---

## 1. Core rules (one district)

### 1.1 Cards

A district is a single shuffled deck built from four card types. Every card shows one big number.

| Type | Number means | Resolving it |
|---|---|---|
| **Zombie** | Strength (2-14) | You fight it and take damage (see 1.4). |
| **Weapon** | Power (2-9) | You **Equip** it (it replaces your current weapon, which is discarded) **or Scrap** it (discard, no effect). |
| **Medkit** | Heal (2-8) | Restore that much HP, up to your max. Only **one medkit heals per street**; any more you resolve on the same street are used up for nothing. |
| **Barricade** (new) | Cover (2-4) | Gain that much **Cover**. Cover soaks up damage before your HP does and goes away at the end of the street. |

Display names by number (flavor only; the rules use the number):

- Zombies: 2-4 *Shambler*, 5-7 *Lurcher*, 8-10 *Bruiser*, 11-14 *Hulk*.
- Weapons: 2 Broken Bottle, 3 Claw Hammer, 4 Crowbar, 5 Cricket Bat, 6 Machete, 7 Fire Axe, 8 Sledgehammer, 9 Chainsaw.
- Medkits: 2-3 Bandage, 4-6 First Aid Kit, 7-8 Trauma Kit.
- Barricades: 2 Plywood, 3 Car Door, 4 Dumpster.

### 1.2 Health

- You start with **20 HP** (20 max), unless your survivor says otherwise.
- If you reach **0 HP, the run ends**.
- HP carries over between districts (see 2.2).

### 1.3 The street (turn structure)

1. **Deal:** fill the street up to **4 cards** from the top of the deck.
2. **Decide:** **Retreat** (1.5), or **Search** the street.
3. **Search:** resolve **3 of the 4 cards, one at a time, in any order you choose**. You cannot stop partway or skip a card once you start.
4. The 4th card is the **Holdover**. It stays where it is and becomes one of the 4 cards on the next street.
5. End of street: Cover goes away and the medkit limit resets.

Short-street rule: if the deck runs out and the street has fewer than 4 cards, resolve all of them except one, which is the Holdover. (This only happens after Theo's partial retreat, see 2.3.)

### 1.4 Fighting

When you resolve a zombie, choose how to fight it:

- **Bare-handed:** you take damage equal to its strength.
- **With your weapon** (only if the Notch rule below allows it): you take `strength - power` damage, minimum 0.

Cover soaks up damage first, then HP takes the rest. The zombie is defeated either way: no zombie survives a fight. The only question is what it costs you.

**Notch rule (weapon wear).** Every kill puts a notch on your weapon at that zombie's strength. From then on, the weapon can only be used on zombies **weaker than its last notch** (strictly lower strength). A freshly equipped weapon has no notch and can hit anything.

- Example: you equip a Machete (6). You kill a Bruiser (9) with it and take 3. The notch is now 9: the Machete can still hit an 8, but not a 9 or a 10. Next you kill a 4 with it, and now it can only hit 2s and 3s. That is why you will sometimes fight a small zombie bare-handed: to keep your weapon's notch high.
- You may always choose to fight bare-handed, even when the weapon is allowed.
- The game must show the notch on the weapon (for example a "hits under 9" tag) and gray out the weapon option on zombies it can't hit.

### 1.5 Retreat

- **Before you resolve any card on a street,** you may Retreat: **put all 4 street cards on the bottom of the deck** (in random order), then deal a fresh street.
- **You cannot retreat two streets in a row.** After a retreat, you must Search the next street.
- You cannot retreat from a Finale street.
- Retreat costs no HP. Its cost is that those cards come back at the end of the district, just before the Finale.

> Design note (studio head decision, 2026-11-07): retreated cards go to the **bottom** of the deck. That makes Retreat a loan against the endgame: what you dodge now is waiting for you right before the Finale. The UI must make this visible: the deck counter shows how many retreated cards are sitting at the bottom, and long-pressing it lists them face up (they are known information).

### 1.6 Finale

Every district ends with a known, face-up Finale shown on the district card from the start, so you can plan for it.

- When the deck is empty and only the Holdover is left, the **Finale cards join the Holdover** to make the **Finale street**.
- On the Finale street you must **resolve every card** (no Holdover, no retreat).
- When the Finale street is clear, you have **cleared the district**.

| District | Finale | Cards | Trait |
|---|---|---|---|
| 1 Maple Row | **The Groundskeeper** (boss) | Zombie 12 | **Shatter:** a weapon used on it breaks after the fight (it still reduces the damage). |
| 2 Downtown | **Rush Hour Horde** | Zombies 10, 9, 8 | **Horde:** all three arrive at once. Fight them in the right order (10, then 9, then 8) and one weapon can handle all three under the Notch rule. |
| 3 St. Agnes Hospital | **Patient Zero** (boss) | Zombie 15 | **Quarantine:** medkits don't heal on the Finale street. |

### 1.7 Deck composition (v1, exact)

Every deck has `4 + 3k` cards, so the last normal street always leaves exactly one Holdover for the Finale.

**District 1 - Maple Row (28 cards)**
- Zombies (14): 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 8, 9, 10 (total strength 74)
- Weapons (6): 2, 3, 4, 5, 6, 7
- Medkits (6): 2, 3, 4, 5, 6, 7
- Barricades (2): 2, 3
- Finale: The Groundskeeper 12 (Shatter)

**District 2 - Downtown (31 cards)**
- Zombies (15): 2, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 9, 10, 11, 12 (total strength 99)
- Weapons (6): 3, 4, 5, 6, 7, 8
- Medkits (7): 2, 3, 4, 5, 6, 7, 8
- Barricades (3): 2, 3, 4
- Finale: Rush Hour Horde 10 / 9 / 8

**District 3 - St. Agnes Hospital (34 cards)**
- Zombies (18): 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 10, 11, 12, 13, 14 (total strength 135)
- Weapons (7): 3, 4, 5, 6, 7, 8, 9
- Medkits (6): 3, 4, 5, 6, 7, 8
- Barricades (3): 2, 3, 4
- Finale: Patient Zero 15 (Quarantine)

### 1.8 Scoring

- **District score** = `10 + HP left at the moment you clear the district`.
- **Run score** = the sum of your district scores. A district you die in scores 0.
- The best score is shown per survivor on the title screen. Score only matters for bragging rights in v1. It is not a currency.

---

## 2. Roguelite layer (v1)

### 2.1 Run structure

A run is **3 districts in a fixed order**: Maple Row, then Downtown, then St. Agnes Hospital. The city map shows the 3 districts as nodes on one path, each with its Finale visible. Clearing St. Agnes **wins the run**.

- Average run (sim): **about 37 streets** (about 7 of them retreats), so roughly **8-10 minutes** at 12-15 seconds per street. A single district takes about 3 minutes.

### 2.2 Safehouse (between districts)

After clearing districts 1 and 2:

1. **Heal 12 HP** (up to your max).
2. **Pick 1 of 3 perks**, offered at random from your unlocked pool without duplicates. Perks last the rest of the run.
3. You **keep your weapon and its notch**.

### 2.3 Survivors (one passive each)

| Survivor | Max HP | Passive | Availability |
|---|---|---|---|
| **Rosa Vance**, mechanic | 20 | **Steady Hands:** her weapons can also hit zombies **equal** to the last notch, not only weaker ones. | Starting |
| **Dr. Imani Hale**, medic | 20 | **Triage:** **two** medkits can heal per street instead of one, and every medkit heals **+1**. | Starting |
| **Theo Park**, courier | 24 | **Slip Away:** may Retreat **after resolving 1 card** of a street (the other 3 go to the bottom of the deck). The no-two-retreats-in-a-row rule still applies. | Unlock (2.5) |

### 2.4 Perks (8 in v1)

| Perk | Effect | In starter pool |
|---|---|---|
| **Thick Jacket** | +4 max HP and heal 4 now. | Yes |
| **Axe in the Trunk** | At the start of each later district, equip a fresh Fire Axe (7) if your current weapon is weaker or notched. | Yes |
| **Field Kit** | Medkits heal +1. | Yes |
| **Knuckle Wraps** | Bare-handed fights deal 2 less damage (minimum 0). | Yes |
| **Sandbags** | Barricades give +2 Cover. | Yes |
| **Scrounger** | Heal 1 every time you Retreat. | Yes |
| **Second Wind** | Once per run, when you would drop to 0 HP, you stay at 1 HP instead. | Unlock |
| **Tripwire** | The street right after a Retreat starts with 2 Cover. | Unlock |

Measured single-perk value (sim, Rosa, perk taken at the first safehouse, no other perks): no perk 11.5% run win; Thick Jacket +8, Axe in the Trunk +10, Field Kit +9, Knuckle Wraps +13, Sandbags +7, Scrounger +6, Second Wind +9, Tripwire +13 points. They are all within about 2x of each other, and none is a must-pick.

### 2.5 Meta unlocks (v1, milestone-based, no currency)

| Milestone | Unlocks |
|---|---|
| Clear Maple Row for the first time | Second Wind joins the perk pool |
| Clear Downtown for the first time | **Theo Park** |
| Win a run | Tripwire joins the perk pool, plus a "Survivor's Mark" badge on that survivor |

Unlocks are shown on the run-end screen as "New: ..." with the card zoomed. Progress is saved locally (`user://` in Godot, which maps to IndexedDB on the Web export).

### 2.6 Later (not in the 1-2 week prototype)

- More districts and a branching map (Docks, Rail Yard, Army Checkpoint), with a choice of 2 next districts.
- Special zombie keywords: *Runner* (must be resolved first), *Screamer* (adds a card to the street), *Bloater* (deals 2 to you when killed with a weapon), *Armored* (weapon power -2).
- Guns that use ammo instead of the Notch rule, and Trap cards.
- Events and trader stops between districts, plus a currency ("Scrap") for permanent upgrades.
- More survivors (4-6) and per-survivor perk pools.
- Daily seeded run with a shared leaderboard, a hard mode ("Nightfall": no safehouse heal), and an endless mode.

---

## 3. UX requirements specific to these rules

The studio rules apply everywhere. These are the core-loop specifics:

- **Inspect everything:** long press (touch) or right click (desktop) on any card, the weapon slot, a perk, a survivor portrait, the district/Finale card or the deck counter opens a zoomed card with its full rule text. On the deck counter that means the remaining card counts by type.
- **Damage preview:** selecting a zombie shows "Bare: -9 HP" and "Machete: -3 HP (notch becomes 9)" as the two buttons. The weapon button is grayed out with a reason ("hits under 7") when the notch blocks it.
- **What just happened:** a one-line log after every card ("Bruiser 9: Machete blocked 6, you took 3"), and an HP change that floats up from the HP bar.
- **Always visible:** HP / max, weapon with power and notch, Cover (when above 0), cards left in the deck, the Finale card, and the Retreat button state ("Retreat - not available, you retreated last street").
- **Medkit limit:** once a medkit has healed this street, other medkits on the street show a "won't heal" badge.
- **Layout:** in portrait the 4 street cards go in a 2x2 grid; in landscape, 1x4. The minimum tap target is 64 px.

---

## 4. Balance simulation

**Tool:** `projects/deaddraw/tools/sim_deaddraw.py` (Python 3, standard library only, headless).

```
python3 projects/deaddraw/tools/sim_deaddraw.py --runs 1500 --seed 7
python3 projects/deaddraw/tools/sim_deaddraw.py --json
```

**AI (greedy, one street of lookahead):** on each street it tries every ordered choice of 3 cards and every legal weapon/bare and equip/scrap option, then scores the resulting state as `HP + 0.35 x the damage the weapon can still absorb against the zombies left in the deck - 0.5 x the Holdover's zombie strength + small credit for a medkit or weapon Holdover`. From the last 10 cards it also adds a penalty for how badly it would do against the face-up Finale. It Retreats when that scores better (retreated cards are valued like Holdovers, since they come back before the Finale). Theo also gets his resolve-1-then-retreat option. It picks perks from a fixed priority list. Weights are in `AI` in the script. I swept them (retreat cost, weapon weight, horizon) and kept the best-performing set, so it is a competent player, not a perfect one.

**Results (1500 runs per row, seed 7):**

| Survivor | Core-loop win (clear Maple Row) | Clear D1 in run | Clear D2 in run | **Run win (full pool)** | **Run win (starter pool)** | Run win (no perks) | HP left on a win | Streets / run | Retreats / run |
|---|---|---|---|---|---|---|---|---|---|
| Rosa | 90.8% | 89.2% | 74.1% | **40.3%** | **38.3%** | 14.9% | 6.5 | 37.7 | 7.0 |
| Imani | 86.1% | 86.7% | 64.6% | **32.5%** | **31.9%** | 9.3% | 5.9 | 36.1 | 7.0 |
| Theo | 90.5% | 90.0% | 66.8% | **35.5%** | (33.3%) | 11.6% | 6.5 | 38.1 | 8.8 |

Sampling error is about +/-2.5 points per figure.

- **Core-loop win** = clear Maple Row from a fresh start.
- **Run win (full pool)** = all 8 perks unlocked. **Starter pool** = the 6-perk pool on a fresh profile, which is the true first run for Rosa and Imani. Theo can't be played on a first run, so his starter-pool number is for reference only.
- **No perks** = the same run with no safehouse picks. It shows how much the perk layer carries.

**Reading the numbers:**
- A competent first run (Rosa or Imani, starter pool) lands in the 30-45% target band. A real first-time human will play worse than the AI; we expect roughly 15-25% in playtests.
- Maple Row is deliberately gentle (about 85-90%) so players learn the rules and nearly always see a safehouse. The run is decided in Downtown and St. Agnes.
- Perks are worth roughly 20-25 points of run win, which means the safehouse choice matters without any single perk being mandatory.

**Tuning history (for the record):** the first pass, with Scoundrel-like weights (forced equip, retreat to the bottom of the deck, harder decks, 6 HP safehouse heal), gave about 0-1% run win and an 8-23% core-loop win (12% or less run win even after the AI fixes). Changes in order of impact:
1. Retreat shuffles the cards back in instead of putting them on the bottom. (The studio head later chose the bottom version; see item 6.)
2. Weapons can be Scrapped.
3. Gentler Maple Row deck and a 12 HP safehouse heal.
4. Perk power evened out (the original "+1 to all weapons" perk was worth +31 points, so it was cut).
5. Theo's HP raised to 22, because Slip Away alone is worth only about +4 points.
6. **Retune after the studio head chose bottom-of-deck retreat** (600 runs: starter-pool run win was Rosa 32%, Imani 25%, Theo 29.5%): Imani's Triage now also gives +1 heal on every medkit (`triage_heal_bonus` 0 to 1), and Theo's max HP went from 22 to 24. Decks, perks and the safehouse heal are unchanged (the safehouse heal stays reserved as the later difficulty knob).

---

## 5. Studio head decisions (2026-11-07)

| # | Question | Options | Recommended | **Decision** |
|---|---|---|---|---|
| 1 | Where do retreated cards go? | (a) shuffled into the deck, (b) bottom of the deck | (a) | **(b) bottom of the deck.** The rules (1.5), Theo's passive and the numbers above have been retuned for it. |
| 2 | Weapons: Equip or Scrap, or always equip? | (a) Equip or Scrap, (b) always equip | (a) | **(a) Equip or Scrap** |
| 3 | Theo: unlock or available from the start? | (a) unlock on first Downtown clear, (b) available from the start | (a) | **(a) unlocks when you first clear Downtown** |
| 4 | Difficulty target | (a) keep about 30-42% for the AI and tune later with the safehouse heal, (b) make it easier now | (a) | **(a) keep it.** The safehouse heal (12) is the reserved knob for later tuning. |

No open questions remain for v1.

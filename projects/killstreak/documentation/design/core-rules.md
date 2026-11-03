# Killstreak — Core Rules Specification (v0.1)

*Author: Mid Game Designer Agent · 2026-11-03 · Based on: `vision.md` (Hybrid → roguelite-first, symmetric rules) · Status: draft for approval · DESIGN ONLY (no code)*
*All names below are original. No franchise names, characters, maps, factions or trademarked mode/feature names.*

## 1. Match components
| Component | Spec |
|---|---|
| **Map** | 3 zones in a row: **Left Flank – Mid – Right Flank**. Mid is adjacent to both flanks; the flanks are not adjacent to each other. Each zone has a **Range tag**: Close / Mid / Long. |
| **Zone capacity** | Up to 4 units per side per zone. Units form a **line**, ordered by arrival. The first unit in line is the **point man**. |
| **Deck** | 20 cards (starter). The hand carries over between rounds. Max hand size 7 (cards drawn above 7 are discarded). When the deck runs out, shuffle the discard pile back in. |
| **Supply** (mana) | Round N gives **N+1 Supply** (2, 3, 4… up to a cap of 7). Unspent Supply is lost. |
| **Operator** | Your hero unit, defined by your loadout's Primary. Starts the match off the board and is placed for free during Round 1 Deploy. |
| **Loadout** (not in the deck) | Primary, Secondary, Lethal, Tactical, Perks (3 slots), Killstreaks (3 slots). |
| **Streak meter** | Counts your eliminations since your Operator last went down. |

### Weapon classes & range bonuses (Firepower modifiers)
| Class | Close | Mid | Long |
|---|---|---|---|
| SMG | **+1** | 0 | 0 |
| Shotgun | **+2** | 0 | −1 |
| AR | 0 | **+1** | 0 |
| Sniper | −1 | 0 | **+2** |
| LMG | 0 | 0 | 0 (high Armor instead) |

Firepower can never go below 0.

### Keywords (7, all shown as icons with tooltips)
| Keyword | Rule |
|---|---|
| **First Shot** | Fires in the First Shot step, before other units. |
| **Pick** | Shots target the enemy with the lowest current Armor (ties → front-most). |
| **Flank** | Shots target the back-most enemy. |
| **Cover N** | Each hit on this unit deals N less damage. |
| **Suppress** | At the start of the firefight, the enemy point man in this zone gets −2 Firepower. |
| **Patch N** | After the firefight, restore N Armor to the most damaged other friendly unit in this zone. |
| **Holder** | You control this zone while contested, unless the enemy also has a Holder there. |

Triggers (not keywords): **On Deploy:** (when revealed) and **On Down:** (when eliminated).

## 2. Round structure (both sides follow identical rules)
1. **Briefing.** Gain Supply, draw 2 (Round 1: draw your 4-card opening hand plus 1; one free mulligan of any number of cards). Lethal/Tactical cooldowns tick down. **Intel:** the enemy's planned unit deployments appear on the minimap as **red dots per zone** (count only). (Against the AI, it commits its plan first. In future PvP, both sides plan blind and red dots come only from Recon.)
2. **Deploy.** In any order: play cards face-down (units go to the back of a zone's line), use Secondary/Lethal/Tactical, activate earned killstreaks, and **Rotate** your Operator once to an adjacent zone (it moves to the back of the line). Cards marked *"Resolves immediately"* (intel/draw) resolve now. Press **READY**.
3. **Reveal.** Both sides' plays flip. **Initiative:** the side that is behind on the scoreboard resolves first (ties → the player). Resolution order:
   a. Units arrive; *On Deploy* triggers.
   b. Tactics, Equipment, Secondary, Lethal/Tactical and Killstreaks resolve in the order they were played.
4. **Firefight** (every zone with units from both sides):
   a. **First Shot step:** all First Shot units on both sides fire at the same time.
   b. **Main step:** all other units (and any First Shot units that haven't fired) fire at the same time.
   c. **Targeting:** each side resolves its shots in line order. A shot hits the enemy point man, unless enough damage has already been assigned to kill that unit, in which case it hits the next unit in line. Pick/Flank override the target. Extra damage beyond what a unit needs is wasted.
   d. Damage applies at the end of each step. Units at 0 Armor are **eliminated**: they go to the discard pile and appear in the killfeed. **Damage persists** across rounds.
   e. Patch effects resolve.
5. **Score & Streak.**
   - **Control:** you control a zone if you have ≥1 unit there and the enemy has none (or via Holder). Otherwise it is contested or empty.
   - **Streak:** +1 per enemy eliminated by your units, Operator, Secondary, Lethal or Tactics. **Eliminations made by killstreaks don't count.** If your Operator was eliminated this round, eliminations are counted first (a trade still pays out) and **then your streak resets to 0**.
   - Reaching a killstreak's threshold puts that killstreak card in your **Streak Tray**. You keep it until used, even after you go down. Each killstreak can be earned once per life.
   - Apply mode scoring (section 4).

### Operator down & respawn
When your Operator is eliminated: the enemy gets +1 elimination, your streak resets, and the Operator leaves the board. At your next Deploy you place it again for free, in any zone, at full Armor. (Detonator mode: no respawn.)

## 3. Loadout items (prototype set)
**Primaries (set Operator stats):**
| Primary | Class | Operator FP/Armor | Trait |
|---|---|---|---|
| Kestrel AR-7 *(starter)* | AR | 3 / 7 | — (reliable) |
| Wasp-9 | SMG | 2 / 6 | First Shot; may Rotate twice per round |
| Longreach .338 | Sniper | 3 / 5 | Pick |

**Weapon XP → attachments** (in a run: weapon levels after matches 1, 3, 5, 7; choose 1 of 2 each time). Examples for the Kestrel AR-7: *Extended Mag* (+1 FP), *Foregrip* (Cover 1), *Holo Sight* (First Shot in Mid zones), *Suppressor* (Operator never appears as a red dot), *Underbarrel Launcher* (once per match: 2 damage to each enemy in Operator's zone), *Ceramic Lining* (+2 Armor).

**Secondary:** *P-12 Sidearm*: 1 Supply, 1 damage to an enemy in your Operator's zone. Once per round.

**Lethal** (choose 1): *Frag Grenade*: 0 Supply, 2 damage to the point man and 1 to the next enemy, in your Operator's zone or an adjacent zone. Cooldown 3 rounds. · *Breaching Charge*: destroy an enemy Equipment card and deal 1 damage to each enemy in that zone. Cooldown 3.
**Tactical** (choose 1): *Flashbang*: enemy units in your Operator's zone or an adjacent zone get −2 FP and lose First Shot this round. Cooldown 3. · *Smoke Canister*: your units in a zone have Cover 1 and can't be targeted by Pick or Flank this round. Cooldown 3.

**Perks** (3 slots; earned during the run, 0 at start):
| Perk | Effect |
|---|---|
| Streak Discipline | Your killstreak thresholds −1 (min 1). |
| Field Salvage | The first time each round you eliminate an enemy, draw 1. |
| Low Profile | Your Operator never appears as a red dot and is immune to enemy recon. |
| Grit | Once per match, your Operator survives lethal damage with 1 Armor. |
| Objective Focus | End of round: if you control 2+ zones, streak +1 (scorestreak style). |
| Quick Hands | Lethal & Tactical cooldowns −1. |
| Overwatch Training | Your Sniper units have First Shot in Long zones. |

**Killstreaks** (choose 3; cost 0 Supply; activate during Deploy):
| Killstreak | Threshold | Effect |
|---|---|---|
| Recon Drone | 2 | This round and next: enemy deployments are shown face-up during Deploy, and enemy units lose Cover. |
| Mortar Barrage | 3 | 2 damage to each enemy unit in one zone. |
| Sentry Turret | 4 | Place a Sentry (FP 2 / Armor 4, Cover 1) in a zone. It doesn't count for control, and enemies get no elimination credit for destroying it. |
| Attack Helo | 5 | At the start of the next 2 firefights, deal 2 damage to the enemy point man in every zone. |
| Gunship | 7 | 3 damage to every enemy unit in all zones. |

*Starter loadout:* Kestrel AR-7, P-12 Sidearm, Frag Grenade, Flashbang, no Perks, Killstreaks = Recon Drone / Mortar Barrage / Attack Helo.

## 4. Game modes (win conditions)
| Mode | Genre analog | Win condition | Round cap |
|---|---|---|---|
| **Zone Control** | domination-style | End of each round: +1 point per controlled zone. First to **6** wins. | Round 8 → most points; tie → Overtime (the next point wins). |
| **Firefight** | team-deathmatch-style | First to **7 eliminations** (Operator downs count). | Round 8 → most eliminations; tie → Overtime. |
| **Detonator** *(Rival/elite matches; stretch goal for the prototype)* | search-and-destroy-style | Attacker starts with a 0-cost *Charge* in hand and must place it in their Operator's zone, then have ≥1 unit in that zone at the end of 2 rounds → detonation. Defender wins by clearing that zone of attackers while the Charge is armed, or by reaching round 8. **No Operator respawn.** | 8 |

## 5. Starter card set (20 designs)
FP = Firepower, AR = Armor. One line of text maximum.

| # | Card | Type | Class | Cost | FP/AR | Text |
|---|---|---|---|---|---|---|
| 1 | Rifleman | Unit | AR | 1 | 2/2 | — |
| 2 | Point Man | Unit | SMG | 2 | 2/3 | First Shot |
| 3 | Combat Medic | Unit | AR | 2 | 1/3 | Patch 2 |
| 4 | Recon Specialist | Unit | AR | 2 | 1/2 | On Deploy: next round, enemy red dots in this zone are revealed. |
| 5 | Breacher | Unit | Shotgun | 3 | 3/4 | First Shot |
| 6 | Marksman | Unit | Sniper | 3 | 2/2 | Pick |
| 7 | Flanker | Unit | SMG | 3 | 2/3 | Flank |
| 8 | Shieldman | Unit | — | 3 | 1/5 | Cover 1. Always arrives at the front of the line. |
| 9 | Gunner | Unit | LMG | 4 | 2/6 | Suppress |
| 10 | Demolitions Expert | Unit | LMG | 4 | 2/4 | On Down: 3 damage to the enemy point man here. |
| 11 | Sgt. Okafor "Anvil" ★ | Unit (Elite) | AR | 5 | 3/6 | Holder. Your other units here get +1 FP. |
| 12 | Lt. Halek "Wren" ★ | Unit (Elite) | Sniper | 5 | 4/3 | Pick. Her eliminations give +1 extra streak. |
| 13 | Callout | Tactic | — | 0 | — | Resolves immediately: reveal red dots in a zone; your next unit there gets +1 FP this round. |
| 14 | Ammo Resupply | Tactic | — | 1 | — | Resolves immediately: draw 2. |
| 15 | Flank Route | Tactic | — | 1 | — | Move a friendly unit to an adjacent zone; it gains First Shot this round. |
| 16 | Suppressing Fire | Tactic | — | 2 | — | Enemy units in a zone get −1 FP this round. |
| 17 | Hold the Line | Tactic | — | 2 | — | Your units in a zone gain Cover 1 this round. |
| 18 | Breach and Clear | Tactic | — | 3 | — | 2 damage to each enemy unit in a zone (3 if Close). |
| 19 | Tripwire Charge | Equipment | — | 2 | — | Hidden in a zone: the next enemy unit to arrive there takes 3 damage. |
| 20 | Comms Relay | Equipment | — | 2 | — | While you control this zone: streak +1 at end of round. |

**Starter deck (20):** Rifleman ×3, Point Man ×2, Marksman ×2, Combat Medic ×2, Callout ×2, Breacher, Gunner, Shieldman, Recon Specialist, Ammo Resupply, Flank Route, Suppressing Fire, Hold the Line, Tripwire Charge.
**Reward pool (Supply Drops):** Flanker, Demolitions Expert, Breach and Clear, Comms Relay, Anvil ★, Wren ★, plus extra copies of starter cards. Card upgrades in the Armory give +1 FP or −1 Cost.

**Prototype map: Port Vasel.** Left Flank "Container Stacks" (Close) · Mid "Crane Yard" (Long) · Right Flank "Loading Offices" (Mid).
**Second map (post-prototype): Cinder Refinery.** Left "Pipe Run" (Long) · Mid "Control Room" (Close) · Right "Tank Farm" (Mid).

## 6. Sample turn walkthrough (Zone Control, Port Vasel, Round 3)
**State:** Score You 1 – 1 Enemy squad *[DSRT] SandViper_07*. Supply 4. Streak 1 (thresholds: Recon Drone 2 / Mortar 3 / Helo 5). Frag Grenade ready.
- Left (Close): you have a Point Man 2/3. Enemy: none.
- Mid (Long): your Operator (Kestrel AR-7, FP 3, Armor 5 of 7). Enemy: Marksman 2/2 (Sniper in Long → FP 4, Pick).
- Right (Mid): you have nothing. Enemy: Rifleman 2/2, Gunner 2/6.

**1. Briefing.** You draw Breacher and Hold the Line. Hand: Marksman, Combat Medic, Callout, Breacher, Hold the Line. Minimap shows red dots: **Left 1 · Mid 0 · Right 1.**

**2. Deploy.**
- The enemy Marksman would hit your Operator for 4 (Armor 5 → 1). That's too close for comfort, and losing the Operator would reset your streak.
- **Callout (0)** on Left resolves immediately: the red dot is an enemy **Breacher** (3/4, First Shot, Shotgun in Close → FP 5). It would delete your Point Man.
- **Breacher (3 Supply)** to Left, behind the Point Man. With Callout it fires at 3 + 2 (Close) + 1 = **6**, with First Shot. Supply left: 1.
- **Frag Grenade (0)** on Mid, where your Operator is. It will hit the Marksman for 2 at Reveal, before the firefight.
- Leave Right alone (the enemy holds it); save the Combat Medic. READY.

**3. Reveal.** Enemy plays: Breacher → Left, Point Man → Right, *Suppressing Fire* on Mid. Score is tied, so **you have initiative.**
- Your Frag Grenade: the Marksman takes 2 → **eliminated**. Killfeed: `KESTREL AR-7 [FRAG] SandViper Marksman`. **Streak 2 → Recon Drone earned.**
- Enemy Suppressing Fire: your Operator gets −1 FP (no effect, since no enemies remain in Mid).

**4. Firefight.**
- **Left, First Shot step:** your Point Man (2 + 1 Close = 3) and Breacher (6) both fire at the enemy Breacher (4 Armor) → **eliminated**. **Streak 3 → Mortar Barrage earned.** At the same time, the enemy Breacher fires 5 at your Point Man (3) → eliminated. That's a squad loss, not your Operator, so **the streak is kept.**
- **Mid:** no enemies left. **Right:** no units of yours, so no firefight.

**5. Score.** Left: yours (Breacher). Mid: yours (Operator). Right: enemy's. **Score: You 3 – 2 Enemy.**
Radio: *"Two down on Containers. Mortar's ready, call it in."*
**Next round's plan:** call in the Mortar Barrage on Right (2 damage each): the Rifleman dies, the Point Man drops to 1, the Gunner drops to 4. You still hold the Recon Drone for the critical round 5.

## 7. AI opponent (behavior spec, for the prototype)
- Each enemy squad = a fixed 15–20 card deck + a loadout + a **personality**: *Rusher* (SMG/Shotgun, Close zones), *Anchor* (LMG/Holder, contests Mid), *Sniper Nest* (Pick, Long zones).
- Each round: score each candidate play by (expected damage dealt − expected damage taken + 2 × zone-control swing + 3 × "deny the player's streak"). Choose the best affordable set, with a small random chance (by Threat Level) of a second-best play so the AI is less predictable.
- The AI commits its plan before the player deploys (that's how red dots work) and never reads the player's face-down cards.

## 8. Feature spec summary (user stories & acceptance)
- *As a shooter player, I want to see where enemies are pushing (red dots) so that I can counter-deploy like reading a minimap.* → AC: red dot counts match the AI's committed deployments 100% of the time.
- *As a player, I want my streak to reset only when MY Operator goes down so that I feel like the player in a shooter.* → AC: squad losses never change the streak; an Operator down resets it after that round's eliminations are counted.
- *As a card veteran, I want deterministic firefights so that I can plan exact sequencing.* → AC: no randomness inside firefight resolution; a "preview" overlay predicts the outcome from the current visible information.
- Acceptance: a match finishes in ≤ 8 rounds; a full round of UI interaction takes ≤ 30 s for an experienced tester.

## 9. Edge cases
- Both Operators go down in the same step: both get elimination credit and both streaks reset.
- No legal target in a zone: the shot is wasted. Pick ties → front-most.
- Hand full (7) on draw: the drawn card is discarded and shown in the log.
- Zone full (4): the card can't be played there (the UI greys the zone out).
- An eliminated Shieldman lets the next unit in line become point man immediately for subsequent shots in the same step (damage is assigned per shot).
- Overtime ties after round 10: draw (counts as a loss of 0 tickets, i.e., no ticket lost).

## 10. Balancing parameters (tunable)
Supply curve (N+1, cap 7) · draws per round (2) · hand cap (7) · zone capacity (4) · Zone Control target (6) · Firefight target (7) · round cap (8) · killstreak thresholds (2/3/4/5/7) · Lethal/Tactical cooldown (3) · Operator stats per Primary · range bonuses table · AI weights (2×, 3×) · Threat Level modifiers.

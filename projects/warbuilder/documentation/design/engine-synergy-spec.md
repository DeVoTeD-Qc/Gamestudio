# Warbuilder: Engine & Synergy Redesign (spec)

*Sr Game Designer · 2026-11-05 · Board task `wb-syn` · Status: **proposal, prototyped in the simulator, not in the game yet***
*Inputs: the studio head's direction (below), `documentation/DESIGN_REVIEW.md`, `design-review-core.md`, `qa/playtest-report.md` §4, `cardzone-comparison.md`, `source/project-warbuilder/src/engine.js` (read only).*
*Prototype: `qa/tools/ai_sim_syn.js` (new). `qa/tools/ai_sim.js` and `source/` are unchanged.*

> **Head's direction:** "A game with quick turns and mostly simple rules where the player feels the Warzone experience and where the progression and strength of the deck can be seen. [...] synergy cards and combos [...] The fun of these games is to see the engine of the deck take form and have stronger and stronger turns, turn over turn."
>
> **Already decided:** keep the names; real closing circle with an escalating final circle and a hard end; typical shot odds about 60–70%; Warbuilder is the 1v1 luck-and-nerve duel (CardZone stays the deterministic 2–4 player game); single HTML file; combos are to be **deepened**.

## 1. The idea in three sentences
1. Every card belongs to one of four **squads** (Assault, Recon, Support, Engineer), every squad card helps you shoot, and each one carries a **Squad line** that pays out **once for every other card of the same squad you have in play**, so a deck that leans into one squad grows quadratically stronger instead of linearly.
2. **Loadout** cards stay on the table (2 slots) and count as squad cards every turn, so your engine is literally laid out in front of you and grows as the match goes on.
3. The HUD shows that growth as a single **Firepower** number per turn, with squad counters and a per-round sparkline, and the target curve is about 8 at the drop, 13 by round 5 and 19–20 by round 8, when the final circle forces the showdown.

**Prototype verdict (4,000 seeded games per row; §9):**

| Target | Result | Pass |
|---|---|---|
| Combo-aware AI beats combo-blind AI ≥ 55% | **57.5%** (95% CI 56.0–59.1). Shipping game today: 49.0% vs 48.7%, no difference | Yes |
| Average turn power rises round over round | **8.2 → 9.6 → 11.4 → 12.6 → 13.0 → 15.8 → 17.7 → 19.4 → 19.5** (rounds 1–9, combo-aware) | Yes, rounds 1–9 |
| Matches end by the hard end | Longest match 11 rounds, **0 past the hard end**. 87% end by KO, 12% in the storm, 0.3% at the hard end | Yes |
| No gun class outside 42–58% | **42–57%** in the mirror match (DMR at the edge, 42%) | Yes |
| Shot odds 60–70% (head's decision) | Taken shots hit **92%** (shipping game: 83%). Not fixed by this spec: see §8 and question Q1 | **No** |

## 2. Design pillars for this redesign
1. **Watch the engine form.** Turn 8 must feel visibly stronger than turn 4, and the screen must say so in numbers.
2. **One rule, read once.** One synergy rule (Squad), one persistent zone (Loadout), and at most 7 keywords. No neighbour-pair tables, no gun combos.
3. **Quick turns.** Five steps, a cap of 2 buys, auto-resolving squads. A turn should take a practised player about 60–90 seconds (estimate; not measured).
4. **Battle royale arc.** Loot early, build mid-game, showdown in a shrinking circle with a hard end. Engines peak exactly when the circle forces contact.
5. **Your deck is your aim.** The reveal-to-shoot signature stays. Synergy feeds Precision, Hit Markers and damage, so the engine you build is the gun you fire.

## 3. Rules

### 3.1 Turn structure (5 steps)
| # | Step | What happens | Decisions |
|---|---|---|---|
| 1 | **Ready** | Automatic: your Loadout cards fire, you get your location's bonus. | none |
| 2 | **Play** | Play cards from your hand (**Play all** is the default). Squad lines resolve on their own, in any order. | which cards to hold (rare: Reactions) |
| 3 | **Move** | One move along the row (cost = distance in Movement). Arriving gives that location's bonus. | where |
| 4 | **Loot** | Up to **2 buys** (top of your stack, or next door for +1 Intel, or the Buy Station). Cycle a stack for 1 Movement or 1 Intel. Scrap. | what, up to 2 |
| 5 | **Fire** | Fire your gun: reveal 1 card from your deck per Precision, count Hit Markers. Then end: unused Movement becomes Armor (max 2), discard everything, draw 5 (6 at 10 Health or less). | when to stop |

**Caps that keep a turn quick:** 1 move, 2 buys (+1 per "+1 Buy" effect), 2 Loadout slots, hand of 5, one gun.

### 3.2 Keywords (7)
| Keyword | Rule | On today's engine |
|---|---|---|
| **Squad** | "Squad: X." You get X **once for each other card of this card's squad** in play this turn, **up to ×3**. Your Loadout cards count. | Replaces combo boxes and gun combos. The engine's dormant `allies` code is the same idea (binary); add the count. |
| **Loadout** | When played, the card goes to your Loadout row (2 slots; to deploy a third, discard one, or use the new card once and discard it). At **Ready**, each Loadout card gives its effect. It counts as a squad card in play every turn. It is not in your deck, so it is never revealed. | New zone `pl.loadout`, resolved in `startTurn` like `autoTactical`. |
| **Scrap** | Remove a card in your hand, play area or discard pile from the game. Your deck can't go below 7 cards. | Exists (`scrap`). |
| **Mark** | Your next shot needs 1 fewer Hit Marker on every step. | Exists (`nextFire.reqMod`). |
| **Pierce** | Your shots ignore cover this turn. | Exists (`ignoreCover`). |
| **Steady** | Your shots ignore 1 Recoil this turn (stacks). | Exists (`recoilTurn`). |
| **Reaction** | While this card is in your hand, it reduces a hit against you (the best one is used automatically). | Exists. |

Plain effect words, not keywords: Gain (Movement, Precision, Intel, Armor, extra shot), Draw, **+1 Buy**, **"your hits deal +1 damage this turn."**

### 3.3 The four squads (identity, in Warzone flavour)
| Squad | Fantasy | Main output | Squad lines pay | Loadout |
|---|---|---|---|---|
| **Assault** | Push the building, trade up close | Precision + Movement | **Hits +1 damage**, extra Precision, draw | **Tac Vest:** Ready: +1 Precision, your hits deal +1 damage |
| **Recon** | See them first, one clean shot | Precision + the most Hit Markers | Precision, **Mark**, Intel | **Recon Post:** Ready: +2 Precision |
| **Support** | Lay down fire, hold the line | Precision + extra shots + Armor | **Steady**, extra shots, Precision | **Field Pack:** Ready: +1 Precision, +1 extra shot |
| **Engineer** | Cash, contracts, better gear | Intel + draw + Scrap | Intel, **+1 Buy**, Precision, draw | **Bounty Contract:** Ready: +2 Intel |

**Why every card gives Precision:** the prototype showed that Precision and Hit Markers are the only route to damage. In an early version, Assault and Support cards gave Movement and shots instead of Precision. A deck built on one of those squads then won only 13–16% against a mixed deck. The squads now differ in what they add on top of aiming.

### 3.4 Other rule changes in the package
| Change | Rule | Why |
|---|---|---|
| **Hot Drop** | In rounds 1–3, cards you gain go **on top of your deck**, not into the discard. | Without it, power is flat from round 1 to 2 (8.2 → 8.2), because new cards wait for the first reshuffle. With it, your first buy shows up next turn (8.2 → 9.6), and it teaches the loop. |
| **Buy Station Scrap** | At the Buy Station, pay 1 Intel: Scrap a Sprint (once per turn). | Steady thinning is what makes squad pairs show up in a 5-card hand. |
| **Buy cap 2** | At most 2 buys per turn (+1 Buy effects add more). | Keeps turns short and makes Engineer's +1 Buy mean something. |
| **Health 40** | Was 30. | Engines need runway. At 30, matches last 7.9 rounds and only 31% reach the final circle (§9.4). |
| **Point blank** | Every gun may fire at distance 0. | Without it, DMR, sniper and launcher can't fire in a one-location final circle (they won 16–36% in an early run). |
| **Close quarters** (M3) | At distance 0, shots ignore cover and Armor. | Close guns get their edge. |
| **Ladder +1** (M2) | +1 Hit Marker on every ladder step. | Meant to lower the odds. It is not enough on its own (§8). |
| **Gun tweaks** | SMG: first step −1 Hit Marker, Recoil −1. Combat Knife: 2 stabs per turn. Breacher (shotgun): first step −1 Hit Marker, +1 damage. | Brings every gun class into 42–57%. |
| **Cut** | Combo boxes and neighbour-pair roles, gun combos (`gcombo`), perks (already decided), Armor Plates (K01, unused), Take Cover (T006, unused). | Simpler card text. The old combos did not change decisions. |

**Tested and cut:** *Streak* (your 2nd and later hits each turn deal +N damage). It made up 2.4% of all damage, and removing it changed the combo-aware win rate by 0.2 points. It was decoration, as the old combos were. *Specialist ranks* (own 4 or 7 cards of a squad: a free bonus every turn) added 0.5 points (58.0%). That is not worth a rule; it stays an optional knob.

## 4. Making growth visible (UI brief for ui-ux-agent)
1. **Firepower readout** (top of the hand area): one number, updated live as cards resolve, with "▲3 vs last turn". Formula (the same one the simulator uses): **Movement + Precision + Intel + Armor + Pierce + Steady + Scrap + 2 × (extra shots, cards drawn, Mark, "hits +1 damage") + 1 per +1 Buy**. A sparkline under it shows Firepower for each round so far.
2. **Squad counters**: four small pips (Assault, Recon, Support, Engineer) showing **how many cards of each squad you own** (deck + Loadout). The biggest one is highlighted as "your squad". This is the "the deck takes form" view.
3. **Squad chain callout**: when a Squad line fires, the card flashes and shows "Squad ×2: +4 Precision". Cards in hand that *would* trigger glow before you play them.
4. **Loadout row**: 2 slots beside the gun, always visible, and pulsing at Ready when they fire.
5. **Aim rating** on the deck pile: the average Hit Markers per card in your deck ("Aim 1.4"). Scrapping starters raises it visibly.
6. **End-of-turn line** in the log: "Turn 8: Firepower 19 (▲2) · Squad ×3 · 9 damage".
7. Keep the shot preview with the odds on the FIRE button (playtest B10). The odds are the nerve moment.

### Target power curve (tuning target, per player turn; measured values in brackets, combo-aware AI vs combo-blind AI)
| Round | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| **Target Firepower** | 8 | 10 | 11 | 12–13 | 13–14 | 15–16 | 17–18 | 19–20 | ~20 (plateau; final circle) |
| Measured, combo-aware | 8.2 | 9.6 | 11.4 | 12.6 | 13.0 | 15.8 | 17.7 | 19.4 | 19.5 |
| Measured, combo-blind | 8.2 | 9.7 | 10.9 | 12.2 | 12.4 | 14.3 | 16.2 | 17.8 | 18.5 |
| Same cards, Squad switched off | 8.2 | 9.6 | 10.5 | 11.2 | 11.4 | 12.6 | 13.6 | 14.5 | 14.9 |
| Squad triggers per turn (aware) | 0 | 0 | 0.25 | 0.41 | 0.41 | 0.71 | 0.87 | 1.00 | 0.98 |
| Damage dealt per turn (aware) | 0 | 0.8 | 1.3 | 1.8 | 2.7 | 5.3 | 7.3 | 9.1 | 9.5 |

The synergy is what makes the curve steep: the same cards with Squad switched off reach 14.9 by round 9, and with Squad 19.5 (+31%). Rounds 10–11 dip (19.1, 17.0) because only the slowest matches get that far (13% and 2% of turns), so the curve is quoted for rounds 1–9.

## 5. Card list (exact numbers)
Notation: **HM** = Hit Markers, **Cost** in Intel. "Squad" lines repeat once per other card of that squad in play (Loadout counts). Copies: 2 of each loot card; each Loadout has 3 copies (1 in tier I loot, 2 in tier II). Names are kept; four new cards are marked **NEW**.

### Starter deck (10, unchanged)
Sprint ×3 (+1 Movement, 0 HM) · Scout ×3 (+1 Intel, 0 HM) · Steady Aim ×2 (+1 Precision, 1 HM) · Recon Run ×2 (+1 Movement and +1 Intel, 1 HM).

### Buy Station (2 Intel, 6 copies each, one basic per squad)
| Card | Squad | HM | Effect | Today |
|---|---|---|---|---|
| Tac Sprint | Assault | 1 | +1 Movement, +2 Precision | +2 Movement |
| Focus | Recon | 2 | +2 Precision | same |
| Spare Rounds | Support | 2 | +1 Precision, +1 extra shot | +1 extra shot, 1 HM |
| Dead Drop | Engineer | 1 | +2 Intel | same |
| *Service* | — | — | Pay 1 Intel: Scrap a Sprint (once per turn) | new |

The station basics decide which squads are viable. In an early version, when Tac Sprint gave only Movement, a deck built on Assault won 13%. Station basics have no Squad line, but they count as squad cards for other cards' Squad lines.

### Assault: hits hit harder
| ID | Card | Tier | Cost | HM | Play | Squad (each) | Change vs today |
|---|---|---|---|---|---|---|---|
| A11 | Breach | I | 1 | 2 | +1 Move, +2 Prec | hits +1 dmg, +1 Prec | −1 Move, +1 Prec, HM 1→2 |
| A12 | Slide Cancel | I | 1 | 2 | +2 Move, +1 Prec, Scrap 1 | Draw 1, +1 Prec | +1 Prec, HM 1→2 |
| A13 | Hip Fire | I | 2 | 2 | +1 Move, +2 Prec | +3 Prec | HM 1→2 |
| A21 | Rush the Door | II | 3 | 2 | +1 Move, +3 Prec, Pierce | hits +1 dmg, +2 Prec | −1 Move, +1 Prec |
| A22 | Flank | II | 3 | 2 | +2 Move, +2 Prec, Draw 1 | Draw 1, +2 Prec | −1 Move, −1 Intel, +2 Prec |
| A23 | Run and Gun | II | 3 | 2 | +1 Move, +2 Prec, +1 shot | Steady, +2 Prec | −1 Move |
| A31 | Blitz | III | 5 | 3 | +2 Move, +3 Prec, hits +1 dmg | +2 Prec | −1 Move, draw → +1 dmg |
| A32 | Breaching Charge | III | 4 | 3 | +1 Move, +3 Prec, Pierce, hits +1 dmg | +1 shot, Steady | −1 Move, +1 Prec, HM 2→3; "next hit +2" → "all hits +1" |
| L1A | **Tac Vest** (NEW) | Loadout | 3 | 1 | Loadout. Ready: +1 Prec, your hits deal +1 dmg | — | new |

### Recon: aim
| ID | Card | Tier | Cost | HM | Play | Squad (each) | Change vs today |
|---|---|---|---|---|---|---|---|
| R11 | Mark Target | I | 1 | 2 | +2 Prec | Mark, +1 Prec | −1 Move |
| R12 | Steady Breath | I | 1 | 3 | +2 Prec | +2 Prec | −1 Prec |
| R13 | Snapshot | I | 2 | 2 | +2 Prec, +1 Intel | +2 Intel, +1 Prec | same play |
| R21 | Heartbeat Sensor | II | 3 | 2 | +2 Prec, Draw 1 | +4 Prec | −1 Prec, −1 Move |
| R22 | Spotter Scope | II | 3 | 3 | +3 Prec | Mark, +2 Prec | −2 Prec |
| R23 | Thermal Optic | II | 3 | 2 | +3 Prec, Pierce | +2 Intel, +2 Prec | −1 Intel |
| R31 | UAV | III | 4 | 3 | +3 Prec, +1 Intel, Pierce | Draw 1, Mark, +1 Prec | −1 Prec, −1 Intel |
| R32 | Headhunter | III | 5 | 3 | +4 Prec, Mark | +2 Prec | −1 Prec |
| L1R | **Recon Post** (NEW) | Loadout | 3 | 1 | Loadout. Ready: +2 Prec | — | new |

### Support: sustained fire
| ID | Card | Tier | Cost | HM | Play | Squad (each) | Change vs today |
|---|---|---|---|---|---|---|---|
| S11 | Ammo Box | I | 2 | 2 | +2 Prec, +1 shot, Scrap 1 | Steady, +2 Prec | HM 1→2 |
| S12 | Suppressing Fire | I | 2 | 2 | +2 Prec, +1 Armor | +1 shot, +1 Armor | −1 Move, HM 1→2 |
| S13 | Bandolier | I | 2 | 2 | +1 Prec, +1 shot, +1 Armor, Steady | +3 Prec | −1 Prec, +Steady, HM 1→2 |
| S21 | Steady Grip | II | 3 | 2 | +2 Prec, +1 shot, Steady | +3 Prec | −1 Prec, Armor → Steady |
| S22 | Resupply | II | 3 | 2 | +1 Prec, +1 Intel, +1 shot, Draw 1 | Steady, +2 Intel | −1 Intel, HM 1→2 |
| S23 | Covering Fire | II | 3 | 2 | +3 Prec, +2 Armor | +1 shot, Steady, +1 Armor | same play |
| S31 | Overwatch | III | 5 | 3 | +4 Prec, +1 shot, +2 Armor | +2 Prec, +1 Armor | −1 Prec, HM 2→3 |
| S32 | Munitions Drop | III | 4 | 3 | +3 Prec, +2 shots, Steady | +1 shot, +1 Prec | −1 Prec, +Steady, HM 2→3 |
| L1S | **Field Pack** (NEW) | Loadout | 3 | 1 | Loadout. Ready: +1 Prec, +1 extra shot | — | new |

### Engineer: cash and contracts
| ID | Card | Tier | Cost | HM | Play | Squad (each) | Change vs today |
|---|---|---|---|---|---|---|---|
| E11 | Scrounge | I | 2 | 1 | +1 Prec, +2 Intel, Scrap 1 | +3 Intel | +1 Prec |
| E12 | Deployable Cover | I | 2 | 1 | +1 Prec, +2 Intel. Reaction 3 | +1 Buy, +1 Intel | −1 Intel, HM 0→1 |
| E13 | Ping | I | 1 | 1 | +1 Prec, +1 Intel, 1 free cycle | Draw 1, +1 Intel | −1 Intel |
| E21 | Munitions Box | II | 3 | 2 | +2 Prec, +2 Intel | +1 shot, +2 Prec | +1 Prec, HM 1→2 |
| E22 | Field Kit | II | 3 | 2 | +1 Prec, +2 Intel, Draw 1 | +3 Prec | −1 Intel |
| E23 | Salvage | II | 3 | 2 | +1 Prec, +2 Intel, Scrap 1, 2 free cycles | +3 Intel, +1 Buy | +1 Prec, −1 Intel, HM 1→2 |
| E31 | Field Workshop | III | 4 | 2 | +2 Prec, +2 Intel, Draw 1, Scrap 2 | +3 Prec, Draw 1 | +2 Prec, −1 Intel |
| E32 | Black Market | III | 5 | 2 | +2 Prec, +4 Intel, Draw 1, +1 Buy | +1 Intel, +2 Prec | +2 Prec, −1 Intel, +1 Buy |
| L1E | **Bounty Contract** (NEW) | Loadout | 3 | 1 | Loadout. Ready: +2 Intel | — | new |

**Card count:** 32 loot cards × 2 + 4 Loadouts × 3 = **76 loot cards** (today 64), plus 24 station cards and 30 guns. Print-and-play grows by about one page.

### A worked turn (round 7, Recon deck)
Hand: Heartbeat Sensor, Spotter Scope, Mark Target, Scout, Focus. Recon Post is in the Loadout row.
Ready: Recon Post +2 Precision. Play all: four Recon cards are in play and the Loadout counts too, so each Recon card has 4 others, **capped at ×3**.
Heartbeat Sensor: +2 Prec, Draw 1, Squad ×3: **+12 Prec**. Spotter Scope: +3, Squad ×3: **3 Marks, +6 Prec**. Mark Target: +2, Squad ×3: **3 Marks, +3 Prec**. Focus: +2 (no Squad line).
This is the "engine has formed" turn: 32 Precision and 6 Marks (Mark can't push a step below 1 Hit Marker). The gun's shots per turn cap the payoff, so a Recon deck turns its surplus into the **big ladder step** (the UI shows Firepower of about 47, ▲ big). This is the top of the range. The sim's combo-aware decks average 1 Squad trigger per turn at their peak, and **the ×3 cap almost never binds** (results are the same with and without it). The cap is there so the table never has to count a ×5.

## 6. Market and loot structure
| Source | What | Access | Change |
|---|---|---|---|
| **Location stacks** | 3 deep, only the top is buyable (+1 Intel next door). Each location has a squad: Open Road and Small Shed are Assault; House and Supply Depot are Engineer; Concrete Barrier and Military Bunker are Support; Recon Tower and Workbench are Recon. | Where you stand ±1 | **Fixed 7-location row** (no conveyor). At the end of every round, **one fresh item lands on top** of each safe stack (2 in 3 are the location's squad, from the phase deck: tier I in rounds 1–3, II in 4–7, III in 8+). A stack over 3 loses its bottom item. Guns are mixed into the phase decks; each location starts with a Common gun on top. |
| **Buy Station** | The 4 squad basics + Scrap service | Anywhere, 2 Intel | Squad-tagged basics with equal value (§5). |
| **Supply crates** | Unchanged (rounds 2 and 4, tier III), not modelled in the sim. | — | — |

**Why this works for engines:** position *is* drafting. Going to the Recon Tower means Recon loot, so the map choice (move toward the rival, toward cover, toward your squad's loot) becomes the battle-royale "where to rotate" decision. **Tested and rejected:** a CardZone-style always-on "Supply Line" (one face-up card per squad, buyable anywhere). It made focus easy for *both* AIs (the combo-blind deck's top squad share rose from 44% to 48%). It cut the combo-aware edge to 54.3% and shortened matches to 8.1 rounds, with the final circle in only 39%. The map-tied loot stays.

## 7. Closing circle and hard end (M1, as decided)
| Round end | 2 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|
| Safe locations after | 6 | 5 | 4 | 3 | 2 | **1 (final circle)** | 1 | 1 | **hard end** |
| Storm damage to both | — | — | — | — | — | 2 | 3 | 4 | 5, then most Health wins |

- The closing edge alternates sides. Each location shows "closes end of round N" (the public schedule). Caught outside: 3 damage, +1 per extra space, then pushed back in.
- **Fit with the engine:** engines peak (Firepower 18–20) in rounds 7–9, exactly when 1–2 locations remain and everyone is at distance 0–1, where close quarters ignores cover and Armor. The build-up and the showdown line up.
- **Measured:** final circle reached in 57% of matches (target ≥ 50%, met); longest match 11 rounds; 87% end by KO, 12% in the storm, 0.3% at the hard end. Gas and storm deal **7%** of all damage (M1 target 10–20%, *not met*).
- **One round faster** (close after rounds 2–7, final circle after round 7, hard end at the end of round 10) meets that target: gas 12.4%, final circle in 84%, 8.3 rounds, combo-aware 57.9%. But the Longbow rises to 60% in the mirror (outside the band), and power plateaus from round 8 to round 9 (18.8 → 18.6). That trade is question Q2.

## 8. Shot odds (60–70%): an honest finding
The head decided typical shots should hit about 60–70%. **This spec does not deliver that, and synergy makes it harder.**
- Taken shots hit **92%** in the prototype (ranged 88%, close quarters 91%, knife 100%), against 83% in today's game.
- The cause is structural. A shot reveals 1 card per Precision, and Precision per turn ranges from about 2 (starter hands) to 20+ (formed engines). For a given need, the hit chance jumps from about 0% to about 100% over a few points of Precision. When in range, **36% of first-shot chances are under 20% and 41% are over 80%**; only 22% are in 20–80%. Any sensible player, like the AI, waits for the high-odds turns, so the shots actually taken almost always hit.
- **Levers tested in the prototype** (4,000 games each):

| Lever | Taken shots hit | Combo-aware win | Side effects |
|---|---|---|---|
| Spec as written (+1 on the ladder) | 92% | 57.5% | — |
| +2 on the ladder (instead of +1) | 93% | 57.5% | Half of all chances drop under 20%; fewer shots (16.8 per match); 8.9 rounds |
| Reveal cap: a shot reveals at most 4 cards | 88% (ranged 81%) | 57.4% | Big hits fall from 29% to 12% of hits; 9.3 rounds; gas 14% of damage (meets M1); 2% hard ends |
| **Dodge:** the target flips their top card; its Hit Markers raise the need | **90%** (ranged 85%) | **57.5%** | The defender's deck matters; a duel moment; +1 flip per shot |
| **Commit Aim:** spend Precision per shot instead of Recoil | **86%** (ranged 80%) | **52.9%** (fails ≥ 55%) | Matches 9.6 rounds; 7% hard ends; weakens synergy |

- **Recommendation:** treat odds as the separate M2 task and judge it with human playtests. A human fires at worse odds than this AI, so the realized rate will be lower, but the bimodal odds are real. Keep the odds on the FIRE button. If a rule is needed, **Dodge** is the one that keeps the synergy edge. See Q1.

## 9. Validation (prototype simulator)

### 9.1 What the prototype is
`qa/tools/ai_sim_syn.js` is a standalone, seeded model of these rules. It reads `engine.js` only for the gun table (ladders, bands, shots, Recoil, rarities), the location types and the gun sets. It does not run the shipping engine's turn code. It checks that every card instance is in exactly one place in every game (0 failures in all runs).
- **Combo-blind AI:** buys by the printed value of a card's play effect and Hit Markers. It ignores Squad lines and the squad tag, and picks Buy Station cards by "what resource am I short of", as the shipping AI does. It values Loadouts fully, because they aren't combos.
- **Combo-aware AI:** the same, plus the expected value of the Squad line given its deck's squad mix (P(partner in hand), times the per-partner count), plus a small bonus for cards that switch on Squad lines it already owns. Both AIs play all their cards, move by the same scoring (in the gun's range, cover, loot they want, avoid the closing edge), fire when the hit chance is ≥ 40% or the expected damage is ≥ 1.6, and scrap Sprints first.
- Seats alternate every game; the first player is random and the lead alternates each round.

Reproduce from the repo root:
```bash
node projects/warbuilder/qa/tools/ai_sim_syn.js 4000                       # combo-aware vs combo-blind (main result)
node projects/warbuilder/qa/tools/ai_sim_syn.js 4000 --match=aware-aware   # mirror: seats, first player, guns
node projects/warbuilder/qa/tools/ai_sim_syn.js 4000 --flat                # control: Squad switched off
node projects/warbuilder/qa/tools/ai_sim_syn.js 2000 --set=force:A         # one-squad-only deck (A, R, S, E)
node projects/warbuilder/qa/tools/ai_sim_syn.js 4000 --curve               # + per-round table
```

### 9.2 Results (4,000 games per row unless noted; seeds 1…N)
| Run | Combo-aware win | First player | Rounds (max) | End: KO / storm / hard end | Final circle | Gas+storm share of damage | Hit rate |
|---|---|---|---|---|---|---|---|
| **Aware vs blind (spec)** | **57.5%** | 50.0% | 8.6 (11) | 87% / 12% / 0.3% | 57% | 7.0% | 92% |
| Aware mirror | 50.6% (seat) | 50.1% | 8.4 (11) | 89% / 11% / 0.1% | 51% | 5.9% | 93% |
| Blind mirror | 49.1% (seat) | 48.8% | 8.7 (11) | 85% / 14% / 0.5% | 63% | 8.0% | 92% |
| Control: Squad off (`--flat`) | **49.6%** | 49.8% | 9.4 (11) | 78% / 20% / 2% | 86% | 14% | 90% |
| + Specialist ranks | 58.0% | 49.5% | 8.6 | 87% / 12% / 0.4% | 57% | 6.9% | 93% |
| + Gun's squad counts for Squad | 58.4% | 50.0% | 8.2 | 91% / 9% / 0% | 42% | 4.5% | 93% |
| No ×3 cap on Squad | 57.5% | 49.9% | 8.6 | identical to the spec row | 57% | 7.0% | 92% |
| + Dodge (ladder +0) | 57.5% | 48.5% | 8.5 | 87% / 13% / 0.4% | 56% | 6.9% | 90% |
| Commit Aim instead of Recoil | 52.9% | 48.4% | 9.6 | 72% / 21% / 7% | 87% | 18% | 86% |
| Reveal cap 4 | 57.4% | 49.2% | 9.3 | 79% / 19% / 2% | 81% | 14% | 88% |
| Supply Line market row | 54.3% | 48.2% | 8.1 | 92% / 8% / 0% | 39% | 3.6% | 92% |
| Circle one round faster (hard end 10) | 57.9% | 48.5% | 8.3 (10) | 82% / 17% / 0.9% | 84% | 12.4% | 92% |
| Health 30 instead of 40 | 56.9% | 48.9% | 7.9 | 92% / 8% / 0% | 31% | 4.4% | 92% |
| *Shipping game today (`ai_sim.js`, 2,000)* | *combo-blind 48.7% vs normal 49.0%* | *50.5%* | *9.4* | *gas never closes* | *0%* | *0.7%* | *83%* |

- **Synergy is what wins.** With Squad switched off, a combo-aware deck that still leans into one squad wins only 49.6%. With Squad on, 57.5%. Combo-aware decks end with 64% of their squad cards in one squad; combo-blind decks end with 44%.
- **Lean in, don't go all in.** Decks forced to buy *only* one squad (2,000 games each): Assault 41%, Recon 46%, Support 40%, Engineer 55% against the combo-blind AI. The winning plan is about two-thirds one squad, plus the best other cards. That is a healthy deckbuilder shape, but **Assault and Support are the weaker "pure" plans** (tuning item).
- **Squad balance, combo-aware as the main squad vs combo-blind:** Assault 62% (n=678), Recon 59% (n=453), Support 54% (n=2,621), **Engineer 73% (n=248)**. In the mirror: Assault 51%, Recon 52%, Support 47%, Engineer 69%. **Engineer is the strongest engine when it comes together** (more buys, more gun upgrades). A first nerf candidate: Black Market loses its +1 Buy, or Bounty Contract drops to +1 Intel and +1 Precision.

### 9.3 Gun classes (win rate by gun held at the end; aware mirror, 4,000 games)
| Assault Rifle | Burst | DMR | Knife | Launcher | LMG | Pistol | Magnum | Breacher | SMG | Longbow |
|---|---|---|---|---|---|---|---|---|---|---|
| 50% | 50% | **42%** | 52% | 55% | 46% | 49% | 50% | 48% | 55% | 57% |

All are within 42–58% (aware vs blind: 44–55%; blind mirror: 44–57%). Today's game: knife 32%, sniper 64%. The DMR sits at the edge; if needed, give it +1 shot or drop its Recoil by 1.

### 9.4 Pacing knobs tried
| Knob (everything else as specced) | Effect |
|---|---|
| Health 30 → 40 | Rounds 7.9 → 8.6; final circle 31% → 57%; combo-aware edge 56.9 → 57.5% |
| Final circle after round 7, hard end 10 | 8.3 rounds; final circle 84%; gas 12.4% of damage; Longbow 60% in the mirror; power flat from round 8 to 9 |
| **Final circle after round 8, hard end 11 (spec)** | 8.6 rounds; final circle 57%; gas 7%; all targets met |
| Final circle after round 10, hard end 12 | 8.9 rounds; final circle 12%; gas 1.5% of damage (too late; 3,000 games) |

### 9.5 Limits of the prototype
- It is a **model**: simplified AIs, a fixed drop (locations 2 and 6), no supply crates, Reaction only on Deployable Cover, one gun slot, and no cover choice beyond the AI's scoring. The absolute numbers (match length, hit rate) will move in the real engine; the **comparisons** (aware vs blind, Squad on vs off, gun classes) are the useful part.
- The combo-aware AI is a heuristic, not a search. A stronger synergy player would likely do better than 57.5%, so the target is a floor, not a ceiling.
- Odds for the AI's fire decision come from 80 Monte Carlo trials over its own deck. That is enough for the fire threshold, but it adds noise to the hit-rate numbers (about ±1 point).

## 10. Implementation notes (for mechanics-developer, after approval)
| Spec item | Where in `engine.js` | Work |
|---|---|---|
| Squad (count-based) | `checkAllies` / `allyReady` (TUNE.allies) already implement a binary same-archetype ally. Replace `combos` with `squad: { eff, text }` and run the effect **min(3, count of other same-archetype cards in `pl.play` + `pl.loadout`)** times. | S |
| Loadout row | New `pl.loadout` (max 2), played cards with `loadout: [...]` move there; resolve in `startTurn`; include it in card-count invariants, the AI and the UI. | M |
| New effect ops | `dmgTurn` (hits +1 damage this turn), `buy` (+1 Buy); `recoilTurn` (Steady), `nextFire.reqMod` (Mark) and `ignoreCover` (Pierce) already exist. | S |
| Buy cap, Hot Drop, Station Scrap | `buy` / `buySupply` (count buys; gain to `deck` top in rounds ≤ 3); a new station action. | S |
| Card table | Rewrite `TC(...)` lines per §5; delete K01, T006, combo text, `gcombo`. | S |
| Gun tweaks, point blank, close quarters, ladder +1 | `GUNCLASS` values; `shootCheck` band floor 0; `applyHit` skips Armor at distance 0; `TUNE.needPlus = 1`. | S |
| Fixed map + schedule + hard end + Health 40 | M1 (`mapMode`, `closing`, `endRound`), TUNE.hp. | M |
| AI | Port the combo-aware buy score from `ai_sim_syn.js` (`cardScore`) into `aiItemScore`. | S |
| Tests | Add the sim's four targets as a balance test (combo-aware ≥ 55%, Firepower rising rounds 1–9, no round past the hard end, gun classes 42–58%). | S |

## 11. Open questions for the head (also the summary's list)
1. **Q1. Shot odds.** The 60–70% target is not met (92% of taken shots hit) because Precision swings from about 2 to 20+ per turn. (a) Add **Dodge** (the target flips 1 card; 90%, keeps the synergy edge); (b) **Commit Aim** (86%, but it drops the combo-aware edge to 53%); (c) accept it for now and measure with human playtests, since humans take riskier shots (recommended: (c), with (a) ready).
2. **Q2. Match length vs circle pressure.** (a) Health 40, final circle after round 8 (8.6 rounds, final circle in 57%, gas 7%; meets every sim target; recommended to start); (b) one round faster (8.3 rounds, final circle 84%, gas 12%, which meets the M1 target, but the Longbow needs a nerf); (c) Health 30 (7.9 rounds, final circle in only 31%).
3. **Q3. More visible chains, or simpler rules?** (a) Squad counts **cards only** (cards in play and Loadouts; 0.41 triggers per turn, 57.5%; recommended); (b) your **gun's squad also counts** (0.61 triggers per turn, 58.4%, but 8.2-round matches and the final circle in only 42%).
4. **Q4. Should a pure one-squad deck be a top strategy?** (a) No: lean about two-thirds (as tested; pure Assault and Support win only 40–41%); (b) yes: add Specialist ranks with bigger bonuses, and buff Assault and Support "pure" play; (c) yes, but only for Engineer (nerf it first, since it is the strongest at 73%).

## 12. Changelog
- **2026-11-05 · wb-rules (Mechanics Developer): implemented in the shipped engine** with the head's answers. Full numbers and the list of retunes: `balance-report-wb-rules.md`.
  - **S1 "Recoil decreases Precision" (interpretation):** Precision is now **spent**. A shot commits N Precision and reveals N cards; the shot spends the N, then the gun's **Recoil costs that much more** (down to 0). Previously Recoil only lowered the reveal of later shots and Precision was never spent. This is the "Commit Aim" lever of §8 *plus* Recoil, which is the closest reading of "Recoil decreases Precision" that changes how shots play. **Steady** now means "each shot this turn reveals 1 extra card for free" (ignoring Recoil was almost worthless under the spend rule). FIRE uses a planner's commit (shown on the button with its odds); AIM changes it. The ladder +1 (M2) is off. Measured hit rate on shots taken: **84.8%** (82.2% without the knife), so the 60–70% target is still not met (report §4; Dodge is the lever that reaches it).
  - **S2:** Health 40, final circle after round 8, hard end after round 11; the storm escalates **3, 4, 5, 6** (was 2, 3, 4, 5 in §7) to keep gas and storm at 10–20% of damage.
  - **S3:** Squad counts cards only.
  - **S4:** new **Rally** bonus at 3 and 5 cards of one squad in play (once per turn each); Buy Station basics carry a small Squad line; Assault and Support buffed, Engineer toned down; gun table retuned for the spend rule (report §3).
  - Result: combo-aware 59.0% vs combo-blind; Firepower 8.2 → 21.0 over rounds 1–9; first player 48.8%; gun classes 43–57%; final circle 74.5%; gas 13.0%; 8.9 rounds.

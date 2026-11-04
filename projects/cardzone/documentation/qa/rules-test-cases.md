# CardZone Loadout Loop: Rules Test Cases (test-first)
*QA Agent · 2026-11-04 · Board task **cz04** · Phase: Prototype · Status: **reviewed (Mid Game Designer gate, see the Review log)**. Open rules questions: RQ-01 to RQ-11.*
*Rules source: `../design/mechanics/loadout-loop-spec.md` §16, the prototype rules for 1v1 (commit 004da00). §16 wins over §1–§15. Consumer: cz07 `loadout_rules.gd` and its headless tests. Machine-readable twin: `rules-test-cases.json` (same IDs, same expectations, fully expanded setups).*
**120 cases.** Each case gives the state, the actions in order and the expected result of each, and cites the ruling IDs (D, P, S, U, R) and tunables it tests. 16 cases also assume the proposed answer to an open rules question (RQ); if the designer rules differently, only those cases change.
## How to read a case

- **State block.** One line for the table, then two lines per player:
  `P2 @Quarry hp 4 · loadout: DCK^ PLV^ HIT SCV SCV DSH ‖ P9 SCV DSH`
  - The loadout runs **top → bottom**.
  - `^` marks a **held** card (hidden from the opponent by default, P2).
  - `‖` marks the end of the **next draw** at this case's `hand_size` (D4). Everything left of it is the next draw; its non-Hit cards are the **next hand**, the Brace window (D5).
  - `hand` is in hand order and `line` runs left → right (D7).
  - `hp` is health (D3): the Hit cards in the health stack.
- **Cards** are written by code (table below). `HRF+RDS` is a Hunting Rifle with a Red-dot tucked under it. It counts as 1 card (D2).
- **Steps** are run in order. Each step's *Expect* lists only the fields that matter. **illegal** means the engine rejects the action and the state stays exactly as it was.
- `end_turn` runs everything automatic up to the next decision: the gas check, Pack, the next draw, and after P2's turn the hard-end check or the round start (Bounty, Zone card, gas, drop, final circle) and P1's draw.
- A **Brace prompt** is the defender's `brace` action. P2 braces against P1's shots. An empty Brace is still an action (RQ-01).
- **Fixtures.** Most states start mid-turn and need not be reachable from a match start (RQ-11). Except for deliberate short-loadout fixtures, health plus every Hit in the loadout, hand and line equals `health`.
- Balance: the defaults are spec §16.8. The case lists any override. The hand-4 cases also set `supply_drop_cost` = 3, as the dev panel does (RQ-08).

### Card codes (spec §10–§11)

| Code | Card | Type | Cost | Brace | Effect |
|---|---|---|---|---|---|
| P9 | P-9 Sidearm (CZ-001, Starter) | weapon | – | – | Shoot. DMG 1 · RNG 0 |
| SCV | Scavenge (CZ-002, Starter) | item | – | – | Search 1 |
| DSH | Dash (CZ-003, Starter) | item | – | – | Move 1 |
| DCK | Duck (CZ-004, Starter) | item | – | 1 | Search 1 |
| HIT | Hit (CZ-005) | hit | – | – | Free draw; Adrenaline: Move 1 or Search 1; Down |
| SMG | Scrap SMG (CZ-010, C) | weapon | 3 | – | Shoot. DMG 2 · RNG 0 |
| BTS | Trail Boots (CZ-011, C) | item | 2 | – | Move 2 |
| BND | Bandage (CZ-012, C) | item | 2 | – | Heal 1. Move 1. Spent |
| SMK | Smoke Grenade (CZ-013, C) | item | 2 | 2 | Move 2. Spent if used to Brace |
| PSG | Pump Shotgun (CZ-014, U) | weapon | 4 | – | Shoot. DMG 3 · RNG 0 |
| FRG | Frag Grenade (CZ-015, U) | item | 3 | – | Spent. 2-damage shot at each player in an area ≤ 1 away; ignores Cover |
| HRF | Hunting Rifle (CZ-016, U) | weapon | 4 | – | Shoot. DMG 2 · RNG 1 |
| LSC | Long Scope (CZ-017, U) | attachment | 3 | – | Attach: +1 RNG (max 2) |
| MED | Medkit (CZ-018, U) | item | 4 | – | Heal 2 |
| PLV | Plate Vest (CZ-019, U) | item | 4 | 2 | Move 1 |
| CRW | Crowbar (CZ-020, C) | item | 2 | – | Search 2 |
| BPK | Backpack (CZ-021, U) | item | 3 | – | Search 1. Pull 1 |
| RDS | Red-dot Sight (CZ-022, C) | attachment | 2 | – | Attach: +1 DMG |
| ASR | Assault Rifle (CZ-023, R) | weapon | 6 | – | Shoot. DMG 3 · RNG 1 |
| MKR | Marksman Rifle (CZ-024, R) | weapon | 6 | – | Shoot. DMG 2 · RNG 2. Ignores Cover |
| EXM | Extended Mag (CZ-025, R) | attachment | 5 | – | Attach: +1 shot per turn |
| SUP | Suppressor (CZ-026, R) | attachment | 5 | – | Attach: no Brace with cards |
| DRN | Recon Drone (CZ-027, R) | item | 5 | – | Search 2. Pull 1 |
| LMG | Twin-Drum LMG (CZ-030, E) | weapon | drop | – | Shoot. DMG 2 · RNG 1. Fires twice |
| HPL | Heavy Plate (CZ-031, E) | item | drop | 3 | Heal 1. Move 1 |
| L50 | Longshot .50 (CZ-032, L) | weapon | drop | – | Shoot. DMG 4 · RNG 2. Ignores Cover |
| PHS | Phantom Suit (CZ-033, L) | item | drop | 4 | Move 2. Search 1 |

**Standard pack** (top → bottom, hand 4 and hand 5, §16.4): `SCV SCV SCV DCK DSH DSH P9 SCV DCK DSH`.

### Map (spec §3) and Zone deck (§8)

| Area | Cover | Piles (cost) | Adjacent |
|---|---|---|---|
| Docks | 0 | SMG (3), BTS (2) | Farmstead, Rail Yard, Core |
| Farmstead | 1 | BND (2), SMK (2) | Docks, Quarry, Core |
| Quarry | 1 | PSG (4), FRG (3) | Farmstead, Radio Hill, Core |
| Radio Hill | 0 | HRF (4), LSC (3) | Quarry, Motel, Core |
| Motel | 1 | MED (4), PLV (4) | Radio Hill, Rail Yard, Core |
| Rail Yard | 0 | CRW (2), BPK (3), RDS (2) | Docks, Motel, Core |
| Core | 1 | ASR (6), MKR (6), EXM (5), SUP (5), DRN (5) | Docks, Farmstead, Quarry, Radio Hill, Motel, Rail Yard |

Pile sizes: outer 3, Core 2 (`pile_size_outer` and `pile_size_core`). Ring order: Docks, Farmstead, Quarry, Radio Hill, Motel, Rail Yard. Distance 2 = not adjacent.

| Card | A | B | C |
|---|---|---|---|
| 1 | Calm | Calm | Calm |
| 2 | Calm | Calm | Calm |
| 3 | LMG → Quarry | LMG → Docks | LMG → Motel |
| 4 | gas Docks | gas Radio Hill | gas Farmstead |
| 5 | Calm | Calm | Calm |
| 6 | gas Farmstead · HPL → Motel | gas Quarry · HPL → Rail Yard | gas Rail Yard · HPL → Radio Hill |
| 7 | gas Rail Yard | gas Motel | gas Docks |
| 8 | L50 → Core | L50 → Core | L50 → Core |
| 9 | gas Radio Hill | gas Farmstead | gas Quarry |
| 10 | gas Quarry · PHS → Motel | gas Docks · PHS → Rail Yard | gas Radio Hill · PHS → Motel |
| 11 | gas Motel | gas Rail Yard | gas Motel |
| 12 | Final circle I: `final_circle_hits[0]` each (+ holder extra) | same | same |
| 13 | Final circle II: `final_circle_hits[1]` each (+ holder extra) | same | same |
| 14 | Final circle III: `final_circle_hits[2]` each (+ holder extra) | same | same |

## Coverage map

| Area | Cases | Count |
|---|---|---|
| Draw and Pull | RT-001 to RT-010 | 10 |
| Play and keywords | RT-011 to RT-031 | 21 |
| Adrenaline | RT-032 to RT-035 | 4 |
| Hold and Stow | RT-036 to RT-045 | 10 |
| Cover, Down and Brace | RT-046 to RT-065 | 20 |
| Frag Grenade | RT-066 to RT-073 | 8 |
| Bounty | RT-074 to RT-081 | 8 |
| Gas and the Zone deck | RT-082 to RT-100 | 19 |
| Private view (fairness) | RT-101 to RT-108 | 8 |
| Undo | RT-109 to RT-112 | 4 |
| Spec worked example (§7) | RT-113 to RT-116 | 4 |
| Setup and tunables | RT-117 to RT-120 | 4 |
| **Total** | | **120** |

| Brief item | Cases |
|---|---|
| Draw with Hits, hand 4 | RT-002, RT-004 |
| Draw with Hits, hand 5 | RT-001, RT-003, RT-005, RT-006, RT-007, RT-008, RT-009, RT-010 |
| Keyword Move (R7, §3) | RT-011, RT-012, RT-014, RT-020 |
| Keyword Search (R7, R10, R18, R19) | RT-011, RT-012, RT-013, RT-014, RT-024, RT-025, RT-026, RT-027, RT-028, RT-029, RT-083, RT-087, RT-088, RT-119, RT-120 |
| Keyword Shoot (R21, R22, R24) | RT-016, RT-017, RT-018, RT-020, RT-046, RT-047, RT-048, RT-049, RT-050, RT-055, RT-063, RT-108, RT-113 |
| Keyword Brace (R25, R26, R27) | RT-031, RT-056, RT-057, RT-058, RT-059, RT-060, RT-079, RT-113, RT-114, RT-116 |
| Keyword Heal (R15, R16, R17) | RT-021, RT-022, RT-023, RT-024, RT-025, RT-072, RT-077, RT-078 |
| Keyword Pull (R3, R4) | RT-007, RT-008, RT-009 |
| Keyword Spent (R20) | RT-022, RT-023, RT-030, RT-031, RT-066, RT-068 |
| Keyword Attach (R11, R12, R13, R14) | RT-018, RT-019, RT-020, RT-059, RT-060, RT-061, RT-062, RT-080 |
| Keyword Down (D6, R23) | RT-008, RT-051, RT-052, RT-053, RT-054, RT-055, RT-058, RT-059, RT-080, RT-082, RT-115 |
| Adrenaline | RT-032, RT-033, RT-034, RT-035 |
| Hold and Stow (and rack_swap) | RT-036, RT-037, RT-038, RT-039, RT-040, RT-041, RT-042, RT-043, RT-044, RT-045 |
| Cover, Down and Brace | RT-046, RT-047, RT-048, RT-049, RT-050, RT-051, RT-052, RT-053, RT-054, RT-055, RT-056, RT-057, RT-058, RT-059, RT-060, RT-061, RT-062, RT-063, RT-064, RT-065 |
| Bounty | RT-074, RT-075, RT-076, RT-077, RT-078, RT-079, RT-080, RT-081 |
| Gas, elimination, final circle and tiebreaks | RT-082, RT-083, RT-084, RT-085, RT-086, RT-087, RT-088, RT-089, RT-090, RT-091, RT-092, RT-093, RT-094, RT-095, RT-096, RT-097, RT-098, RT-099, RT-100 |
| Private view (P-rules, fairness test) | RT-101, RT-102, RT-103, RT-104, RT-105, RT-106, RT-107, RT-108 |
| Undo boundaries | RT-109, RT-110, RT-111, RT-112 |
| Spec worked example | RT-113, RT-114, RT-115, RT-116 |

**Tunables** (§16.8): every switch with at least one case that sets it away from the default, or runs its only allowed value.

| Key | Default | Cases |
|---|---|---|
| `hand_size` | 5 | RT-002, RT-004, RT-053, RT-113, RT-114, RT-115, RT-116 |
| `health` | 5 | RT-118 |
| `packing_rule` | "hold_and_stow" | RT-045 |
| `hold_limit` | 2 | RT-037, RT-038 |
| `hold_looted` | false | RT-040, RT-041, RT-042 |
| `adrenaline_mode` | "move_or_search" | RT-033 |
| `adrenaline_cap_per_turn` | 0 | RT-034, RT-035 |
| `down_enabled` | true | RT-054 |
| `down_value` | 1 | RT-051 |
| `bounty_heal` | 1 | RT-081 |
| `bounty_final_circle_extra` | 1 | RT-095 |
| `bounty_holder_loses_cover` | false | RT-050 |
| `final_circle_hits` | [1, 2, 3] | RT-094 |
| `zone_hard_end_card` | 14 | RT-099 |
| `standard_pack` | true | RT-117 |
| `held_cards_public` | false | RT-105 |
| `hits_on_top_public` | true | RT-106 |
| `loadout_count_public` | true | RT-107 |
| `supply_drop_cost` | 4 | RT-002, RT-004, RT-053, RT-087, RT-088, RT-113, RT-114, RT-115 |
| `crate_cost` | 1 | RT-119, RT-120 |
| `crate_free_picks` | 1 | RT-065 |
| `supply_drop_ready_delay` | 0 | RT-089 |
| `ditch_per_turn` | 1 | RT-029 |
| `min_loadout` | 6 | RT-028 |
| `pile_size_outer` | 3 | RT-118 |
| `pile_size_core` | 2 | RT-118 |
| `ai_think_budget_ms` | 300 | – (AI only: cz09) |

**Ruling IDs** (§16): the cases that cite each one.

| ID | Cases | ID | Cases |
|---|---|---|---|
| D1 | RT-028 | R7 | RT-011, RT-012, RT-014 |
| D2 | RT-018, RT-069, RT-097 | R8 | RT-017 |
| D3 | RT-022, RT-074 | R9 | RT-013, RT-015, RT-016, RT-039, RT-068 |
| D4 | RT-001, RT-002, RT-003, RT-004, RT-005, RT-008, RT-052, RT-053 | R10 | RT-013, RT-014, RT-083, RT-087, RT-088, RT-119, RT-120 |
| D5 | RT-056, RT-057, RT-113 | R10a | RT-089 |
| D6 | RT-008, RT-051, RT-052, RT-053, RT-054, RT-082 | R11 | RT-018, RT-019, RT-061 |
| D7 | RT-007, RT-036, RT-039 | R12 | RT-059, RT-060, RT-061, RT-062, RT-080 |
| D8 | RT-044, RT-096 | R13 | RT-020 |
| S1 | – (match-setup screen: cz11) | R14 | RT-019 |
| S2 | RT-085, RT-086 | R15 | RT-021, RT-022, RT-023, RT-024, RT-025, RT-072, RT-077, RT-078 |
| S3 | RT-117, RT-118 | R16 | RT-022 |
| S4 | RT-001, RT-117, RT-118 | R17 | RT-023, RT-025 |
| S5 | RT-117 | R18 | RT-024, RT-025 |
| S6 | RT-044, RT-117 | R19 | RT-026, RT-027, RT-028, RT-029 |
| S7 | – (no timer: nothing to test) | R20 | RT-022, RT-023, RT-030, RT-031, RT-066, RT-068 |
| P1 | RT-101, RT-102 | R21 | RT-016, RT-017, RT-020, RT-049, RT-063 |
| P2 | RT-101, RT-102 | R22 | RT-018, RT-046, RT-047, RT-048, RT-049, RT-050, RT-113 |
| P3 | RT-036, RT-038, RT-056, RT-101 | R23 | RT-051, RT-052, RT-054, RT-055, RT-058, RT-059, RT-080, RT-115 |
| P4 | RT-101 | R24 | RT-016, RT-046, RT-055, RT-108 |
| P5 | RT-101, RT-106 | R25 | RT-031, RT-056, RT-057, RT-059, RT-079, RT-113 |
| P6 | RT-101 | R26 | RT-060 |
| P7 | RT-101 | R27 | RT-058, RT-114, RT-116 |
| P8 | RT-103 | R28 | RT-059, RT-060, RT-115 |
| P9 | RT-103 | R29 | RT-046, RT-064 |
| P10 | RT-101 | R30 | RT-006, RT-060 |
| P11 | RT-056 | R31 | RT-066, RT-068 |
| P12 | RT-026, RT-066 | R32 | RT-066, RT-067 |
| P13 | RT-101 | R33 | RT-067 |
| P14 | RT-104 | R34 | RT-067, RT-069, RT-073 |
| P15 | RT-105 | R35 | RT-071 |
| P16 | RT-106 | R36 | RT-044, RT-074, RT-075, RT-076, RT-091 |
| P17 | RT-107 | R37 | RT-050, RT-071, RT-072, RT-073, RT-076, RT-077, RT-078, RT-079, RT-080, RT-081 |
| P18 | RT-102, RT-103, RT-104 | R38 | RT-091, RT-092, RT-095 |
| P19 | RT-108 | R39 | RT-044, RT-074, RT-084, RT-085, RT-086, RT-091, RT-117 |
| P20 | RT-108 | R40 | RT-082 |
| U1 | RT-109, RT-117 | R41 | RT-090 |
| U2 | RT-109, RT-110 | R42 | RT-063, RT-083 |
| U3 | RT-109, RT-111, RT-112 | R43 | RT-091, RT-092, RT-093, RT-094 |
| U4 | RT-110 | R44 | RT-096, RT-099 |
| U5 | RT-112 | R45 | RT-064, RT-069, RT-073, RT-090 |
| U6 | – (AI never undoes: cz09; undo_count: cz18) | R46 | RT-064, RT-065, RT-090, RT-119 |
| R1 | RT-001, RT-002, RT-003, RT-004, RT-005, RT-044, RT-114, RT-116 | R47 | RT-069, RT-070, RT-073, RT-092, RT-093 |
| R2 | RT-006, RT-009 | R48 | RT-096, RT-097, RT-098, RT-107 |
| R3 | RT-007, RT-009 | R49 | RT-100 |
| R4 | RT-008 | R50 | RT-010, RT-036, RT-037, RT-038, RT-039, RT-040, RT-041, RT-042, RT-043, RT-044, RT-082, RT-104 |
| R5 | RT-003, RT-007, RT-010 | R51 | RT-045 |
| R6 | RT-011, RT-032, RT-033, RT-034, RT-035 | R52 | RT-010, RT-043 |

## Cases

### Draw and Pull

#### RT-001 · Hand 5: the Standard pack's first draw
*Rules: R1, D4, S4, §16.4*

```
Round 1 · Zone card 1 (route A) · gas: none · drops: none
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **engine: start-of-turn draw** → P1 hand [SCV SCV SCV DCK DSH], loadout [DSH P9 SCV DCK DSH], Down no

*Why:* Hand 5 takes the top 5 non-Hit cards: Scavenge ×3, Duck, Dash (§16.4 table, turn 1).

#### RT-002 · Hand 4: the same pack draws 4
*Rules: R1, D4, §16.4* · *Tunables: `hand_size`, `supply_drop_cost`*

```
Round 1 · Zone card 1 (route A) · gas: none · drops: none
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: SCV SCV SCV DCK ‖ DSH DSH P9 SCV DCK DSH
   hand: – · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK ‖ DSH DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: `hand_size` = 4, `supply_drop_cost` = 3 (others default)

1. **engine: start-of-turn draw** → P1 hand [SCV SCV SCV DCK], loadout [DSH DSH P9 SCV DCK DSH]

*Why:* hand_size = 4 reads every '4' in §5 as 4. The pack order is the same (§16.4).

#### RT-003 · Hand 5: two Hits on top come along free
*Rules: R1, D4, R5*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 3 · loadout: HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **engine: start-of-turn draw** → P1 hand [HIT HIT SCV SCV SCV DCK DSH], loadout [DSH P9 SCV DCK DSH]

*Why:* Hits never take a hand slot: 7 cards in hand, 5 of them real.

#### RT-004 · Hand 4: Hits spread through the draw; the draw stops at the 4th non-Hit
*Rules: R1, D4* · *Tunables: `hand_size`, `supply_drop_cost`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 2 · loadout: SCV HIT SCV HIT SCV DCK ‖ HIT DSH DSH P9 SCV
   hand: – · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK ‖ DSH DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: `hand_size` = 4, `supply_drop_cost` = 3 (others default)

1. **engine: start-of-turn draw** → P1 hand [SCV HIT SCV HIT SCV DCK], loadout [HIT DSH DSH P9 SCV], Down yes

*Why:* The 4th non-Hit is Duck, so the Hit right below it is not drawn. It now tops the next draw (Down).

#### RT-005 · Hand 5: same loadout, the third Hit is inside the draw
*Rules: R1, D4*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 2 · loadout: SCV HIT SCV HIT SCV DCK HIT DSH ‖ DSH P9 SCV
   hand: – · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **engine: start-of-turn draw** → P1 hand [SCV HIT SCV HIT SCV DCK HIT DSH], loadout [DSH P9 SCV], Down no

*Why:* With hand 5 the draw runs to Dash (5th non-Hit), so all three Hits come along.

#### RT-006 · Short loadout: draw all of it, no refill
*Rules: R2, R30*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 4 · loadout: HIT SCV DSH
   hand: – · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **engine: start-of-turn draw** → P1 hand [HIT SCV DSH], loadout []

*Why:* Fewer than hand_size non-Hits: take everything. No penalty, no reshuffle (fixture: a thinned loadout).

#### RT-007 · Pull 1 through two Hits (spec R3 example)
*Rules: R3, R5, D7*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 3 · loadout: HIT HIT DCK SCV SCV DSH P9
   hand: BPK DSH · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 plays BPK** → P1 Search 1, hand [DSH HIT HIT DCK], line [BPK], loadout [SCV SCV DSH P9]

*Why:* Backpack: Search 1, Pull 1. Pull takes Hit, Hit, Duck (one non-Hit) and appends them to the hand order.

#### RT-008 · After a Pull the next draw is recomputed
*Rules: R4, D4, D6*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 4 · loadout: HIT DCK SCV SCV SCV DSH ‖ DSH P9
   hand: DRN · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **check (no action)** → P1 Down yes, next draw [HIT DCK SCV SCV SCV DSH]
2. **P1 plays DRN** → P1 Search 2, hand [HIT DCK], next draw [SCV SCV SCV DSH DSH], Down no

*Why:* Recon Drone pulls the Hit and Duck off the top, so P1 is no longer Down (matters for a Frag on yourself, R33).

#### RT-009 · Pull with an empty loadout is legal and takes nothing
*Rules: R3, R2*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: –
   hand: DRN SCV · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 plays DRN** → P1 Search 2, hand [SCV], line [DRN], loadout []

*Why:* 'Or the loadout ends': Pull stops at once. The Search 2 still counts.

#### RT-010 · A Hit can't be held and doesn't count toward the Hold limit
*Rules: R5, R50, R52*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 4 · loadout: DSH P9 SCV
   hand: HIT SCV DCK · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 ends turn, hold: HIT** → **illegal**: rejected, state unchanged
2. **P1 ends turn, hold: SCV, DCK** → P1 loadout [SCV DCK DSH P9 SCV HIT], held count 2; to act P2

*Why:* Holding the Hit is illegal. Holding 2 real cards is legal with a Hit in hand; the Hit is stowed with the unheld hand.

### Play and keywords

#### RT-011 · Move N and Search N add to this turn's pools
*Rules: R6, R7*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH
   hand: SCV DCK DSH P9 SCV · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 plays SCV** → P1 Search 1, Move 0
2. **P1 plays DCK** → P1 Search 2
3. **P1 plays DSH** → P1 Move 1, Search 2, line [SCV DCK DSH], hand [P9 SCV]

*Why:* Each play goes to the end of the line and gives its effect at once.

#### RT-012 · Move: 1 Move per step, adjacent only, never negative
*Rules: R7, §3*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Rail Yard  hp 5 · loadout: SCV
   hand: DSH DSH · line: –
P2 @Radio Hill hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 moves to Core** → **illegal**: rejected, state unchanged
2. **P1 plays DSH** → P1 Move 1
3. **P1 moves to Quarry** → **illegal**: rejected, state unchanged
4. **P1 moves to Core** → P1 area Core, Move 0
5. **P1 moves to Quarry** → **illegal**: rejected, state unchanged
6. **P1 plays DSH** → legal
7. **P1 moves to Quarry** → P1 area Quarry, Move 0

*Why:* No pool: illegal. Rail Yard to Quarry is distance 2: illegal in one step. Via the Core it takes 2 Move.

#### RT-013 · Loot: pay the pile cost, card goes to the end of the line
*Rules: R9, R10*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH
   hand: SCV SCV SCV DCK · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 plays SCV** → legal
2. **P1 plays SCV** → legal
3. **P1 plays SCV** → legal
4. **P1 plays DCK** → P1 Search 4
5. **P1 loots HRF** → P1 Search 0, line [SCV SCV SCV DCK HRF]; piles Radio Hill HRF×2

*Why:* Hunting Rifle costs 4. Outer piles start at 3 (2 players).

#### RT-014 · Loot is illegal without the Search, outside your area, or from an empty pile
*Rules: R7, R10*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
Pile overrides: Radio Hill LSC×0
P1 @Radio Hill hp 5 · loadout: DSH
   hand: – · line: – · pools: Search 3
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 loots HRF** → **illegal**: rejected, state unchanged
2. **P1 loots PSG** → **illegal**: rejected, state unchanged
3. **P1 loots LSC** → **illegal**: rejected, state unchanged

*Why:* Search 3 < 4. Pump Shotgun is a Quarry pile. Long Scope costs 3 but its pile is empty.

#### RT-015 · A looted item gives nothing this turn
*Rules: R9*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Rail Yard  hp 5 · loadout: DSH
   hand: – · line: – · pools: Search 2
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 loots CRW** → P1 Search 0, line [CRW], hand []
2. **P1 plays CRW** → **illegal**: rejected, state unchanged

*Why:* Looting isn't playing: no Search 2 from the Crowbar, and it can't be played from the line.

#### RT-016 · A looted weapon may fire at once
*Rules: R9, R21, R24*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: – · line: – · pools: Search 4
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 loots PSG** → P1 line [PSG], Search 0
2. **P1 shoots PSG at P2** → damage before Brace 3, Cover 0, Down 0; Brace prompt to P2
3. **P2 braces with nothing** → Hits 3; P2 health 2, loadout [HIT HIT HIT SCV SCV SCV DCK DSH DSH P9 SCV DCK DSH]

*Why:* Pump Shotgun DMG 3, same area (no Cover), P2 not Down. P2 chooses not to brace: 3 Hits on top.

#### RT-017 · A weapon fires only from the line; playing it gives nothing
*Rules: R8, R21*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: P9 SCV · line: –
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots P9 at P2** → **illegal**: rejected, state unchanged
2. **P1 plays P9** → P1 Move 0, Search 0, line [P9]
3. **P1 shoots P9 at P2** → damage before Brace 1; Brace prompt to P2
4. **P2 braces with DCK** → Hits 0; P2 health 5, loadout [SCV SCV SCV DSH DSH P9 SCV DCK DSH DCK]

*Why:* Bracing with the Duck in the next hand moves it to the bottom.

#### RT-018 · Attach: free, permanent, the pair is one card; Red-dot +1 DMG
*Rules: R11, D2, R22*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH
   hand: RDS · line: HRF
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 attaches RDS to HRF** → P1 line [HRF+RDS], hand []
2. **P1 shoots HRF at P2** → damage before Brace 2, Cover 1
3. **P2 braces with nothing** → Hits 2; P2 health 3

*Why:* Hunting Rifle 2 + Red-dot 1 = 3, minus Quarry Cover 1 = 2.

#### RT-019 · Attach limits: 2 per weapon, different names; a loose attachment plays for nothing
*Rules: R11, R14*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH
   hand: EXM RDS · line: HRF+RDS+LSC SMG+RDS
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 attaches EXM to HRF+RDS+LSC** → **illegal**: rejected, state unchanged
2. **P1 attaches RDS to SMG+RDS** → **illegal**: rejected, state unchanged
3. **P1 attaches EXM to SMG+RDS** → P1 line [HRF+RDS+LSC SMG+RDS+EXM], hand [RDS]
4. **P1 plays RDS** → P1 line [HRF+RDS+LSC SMG+RDS+EXM RDS], Move 0, Search 0

*Why:* A third attachment and a second Red-dot are illegal. The spare Red-dot is a loose card: play it to the line with no effect.

#### RT-020 · Long Scope: +1 RNG reaches distance 2; RNG 0 can't reach an adjacent area
*Rules: R13, R21, §3*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Rail Yard  hp 5 · loadout: DSH
   hand: – · line: SMG HRF+LSC
P2 @Farmstead  hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots SMG at P2** → **illegal**: rejected, state unchanged
2. **P1 shoots HRF at P2** → damage before Brace 1, Cover 1
3. **P2 braces with nothing** → P2 health 4

*Why:* Rail Yard to Farmstead is distance 2. Hunting Rifle RNG 1 + 1 = 2 reaches; Farmstead Cover 1. (A scope on a RNG-2 gun has no effect: max RNG 2.)

#### RT-021 · Heal N: line first, last line Hit first, then hand
*Rules: R15*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 1 · loadout: SCV DSH
   hand: HIT MED · line: HIT DSH HIT HIT
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 plays MED** → P1 health 3, line [HIT DSH MED], hand [HIT]

*Why:* Medkit heals 2: the last two line Hits. The first line Hit and the hand Hit stay.

#### RT-022 · Heal with no Hit in line or hand: legal, heals 0; loadout Hits can't be healed
*Rules: R15, R16, R20, D3*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 3 · loadout: HIT HIT SCV SCV SCV DCK DSH
   hand: BND DSH · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 plays BND** → P1 health 3, Move 1, line [], loadout [HIT HIT SCV SCV SCV DCK DSH]; removed [BND]

*Why:* Bandage still gives Move 1 and is Spent on play.

#### RT-023 · Healing an Adrenaline Hit keeps its Search
*Rules: R17, R15, R20*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 4 · loadout: DSH SCV
   hand: HIT BND · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 plays a Hit as Adrenaline (Search 1)** → P1 Search 1, line [HIT]
2. **P1 plays BND** → P1 health 5, Search 1, Move 1, line []; removed [BND]

*Why:* The Hit returns to the health stack; the Search 1 it gave stays in the pool.

#### RT-024 · Patch up: Search 2 heals 1 from the hand
*Rules: R18, R15*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 3 · loadout: DSH
   hand: HIT HIT SCV SCV · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 patches up** → **illegal**: rejected, state unchanged
2. **P1 plays SCV** → legal
3. **P1 plays SCV** → P1 Search 2
4. **P1 patches up** → P1 health 4, Search 0, hand [HIT]
5. **P1 patches up** → **illegal**: rejected, state unchanged

*Why:* Search 0 or 1 can't pay. No per-turn limit, only the Search.

#### RT-025 · Patch up the Adrenaline Hit from the line; illegal with no Hit left
*Rules: R18, R17, R15*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 4 · loadout: DSH
   hand: HIT CRW · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 plays a Hit as Adrenaline (Search 1)** → P1 Search 1
2. **P1 plays CRW** → P1 Search 3
3. **P1 patches up** → P1 health 5, Search 1, line [CRW]
4. **P1 patches up** → **illegal**: rejected, state unchanged

*Why:* Search 1 + 2 = 3, Patch up costs 2. Afterwards no Hit is in line or hand (and only Search 1).

#### RT-026 · Ditch a Starter from the hand
*Rules: R19, P12*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DCK DSH P9 SCV DCK ‖ DSH SCV
   hand: SCV SCV DSH · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 plays SCV** → P1 Search 1
2. **P1 ditches SCV** → P1 Search 0, hand [DSH], non-Hit cards 9; removed [SCV]

*Why:* Search 1, removed from the game face up. 10 → 9 non-Hit cards.

#### RT-027 · Ditch limits: hand only, Starters only, not a P-9 with an attachment, once per turn
*Rules: R19*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH DCK DSH SCV DCK
   hand: SCV SCV SCV P9+RDS PLV · line: DSH · pools: Search 3
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 ditches DSH** → **illegal**: rejected, state unchanged
2. **P1 ditches PLV** → **illegal**: rejected, state unchanged
3. **P1 ditches P9+RDS** → **illegal**: rejected, state unchanged
4. **P1 ditches SCV** → P1 Search 2; removed [SCV]
5. **P1 ditches SCV** → **illegal**: rejected, state unchanged

*Why:* The Dash is in the line, the Plate Vest isn't a Starter, the P-9 carries a Red-dot. ditch_per_turn = 1.

#### RT-028 · Ditch can't take you below min_loadout
*Rules: R19, D1* · *Tunables: `min_loadout`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DCK DSH P9 SCV
   hand: SCV DSH · line: – · pools: Search 1
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 ditches SCV** → **illegal**: rejected, state unchanged

*Why:* 6 non-Hit cards (loadout 4 + hand 2); after a ditch it would be 5 < 6.

#### RT-029 · ditch_per_turn = 0 means unlimited
*Rules: R19* · *Tunables: `ditch_per_turn`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DCK DSH P9 SCV DCK ‖ DSH SCV
   hand: SCV SCV DSH · line: – · pools: Search 2
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: `ditch_per_turn` = 0 (others default)

1. **P1 ditches SCV** → legal
2. **P1 ditches SCV** → P1 Search 0, hand [DSH], non-Hit cards 8; removed [SCV SCV]

*Why:* Two ditches in one turn, each Search 1.

#### RT-030 · Smoke Grenade played for Move 2 is not Spent
*Rules: R20*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH P9 SCV DCK DSH ‖ DCK SCV SCV
   hand: SMK SCV · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 plays SMK** → P1 Move 2, line [SMK]
2. **P1 ends turn, hold: none** → P1 loadout [DSH P9 SCV DCK DSH DCK SCV SCV SMK SCV]; removed []

*Why:* It stows with the line like any card.

#### RT-031 · Smoke Grenade used to Brace is Spent
*Rules: R20, R25*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: – · line: PSG
P2 @Quarry     hp 5 · loadout: SMK SCV SCV DSH DCK ‖ DSH P9
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots PSG at P2** → damage before Brace 3
2. **P2 braces with SMK, DCK** → Hits 0; P2 loadout [SCV SCV DSH DSH P9 DCK]; removed [SMK]

*Why:* Brace 2 + 1 = 3. The Duck goes to the bottom; the Smoke leaves the game.

### Adrenaline

#### RT-032 · A Hit plays for Move 1 or Search 1 and must name one
*Rules: R6, §5*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 3 · loadout: DSH
   hand: HIT HIT SCV · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 plays a Hit as Adrenaline (no mode named)** → **illegal**: rejected, state unchanged
2. **P1 plays a Hit as Adrenaline (Move 1)** → P1 Move 1, line [HIT]
3. **P1 plays a Hit as Adrenaline (Search 1)** → P1 Move 1, Search 1, line [HIT HIT], hand [SCV]

*Why:* The Hit goes to the line like any played card.

#### RT-033 · adrenaline_mode = move_only
*Rules: R6* · *Tunables: `adrenaline_mode`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 4 · loadout: DSH
   hand: HIT SCV · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: `adrenaline_mode` = "move_only" (others default)

1. **P1 plays a Hit as Adrenaline (Search 1)** → **illegal**: rejected, state unchanged
2. **P1 plays a Hit as Adrenaline (Move 1)** → P1 Move 1, Search 0

*Why:* Only Move 1 is allowed.

#### RT-034 · adrenaline_cap_per_turn = 2: the third Adrenaline is illegal
*Rules: R6* · *Tunables: `adrenaline_cap_per_turn`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 2 · loadout: DSH
   hand: HIT HIT HIT · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: `adrenaline_cap_per_turn` = 2 (others default)

1. **P1 plays a Hit as Adrenaline (Move 1)** → legal
2. **P1 plays a Hit as Adrenaline (Search 1)** → legal
3. **P1 plays a Hit as Adrenaline (Move 1)** → **illegal**: rejected, state unchanged
4. **check (no action)** → P1 hand [HIT], Move 1, Search 1

*Why:* The third Hit stays in hand and is stowed at Pack (R52).

#### RT-035 · Default cap 0: no limit
*Rules: R6* · *Tunables: `adrenaline_cap_per_turn`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 2 · loadout: DSH
   hand: HIT HIT HIT · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 plays a Hit as Adrenaline (Move 1)** → legal
2. **P1 plays a Hit as Adrenaline (Move 1)** → legal
3. **P1 plays a Hit as Adrenaline (Search 1)** → P1 Move 2, Search 1, hand [], line [HIT HIT HIT]

*Why:* 0 means no cap.

### Hold and Stow

#### RT-036 · Pack order: held · rest of loadout · line · unheld hand
*Rules: R50, D7, P3*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: SCV DSH SCV DCK DSH
   hand: SCV DCK DSH PLV P9 · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 plays DSH** → legal
2. **P1 plays SCV** → legal
3. **P1 ends turn, hold: PLV, DCK** → P1 loadout [DCK PLV SCV DSH SCV DCK DSH DSH SCV P9], held count 2, next draw [DCK PLV SCV DSH SCV]

*Why:* Held cards keep hand order (Duck entered the hand before the Vest), whatever order hold_ids lists them in.

#### RT-037 · Hold limit 2
*Rules: R50* · *Tunables: `hold_limit`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: SCV DSH
   hand: SCV DCK DSH · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 ends turn, hold: SCV, DCK, DSH** → **illegal**: rejected, state unchanged
2. **P1 ends turn, hold: DCK, DSH** → P1 held count 2, loadout [DCK DSH SCV DSH SCV]

*Why:* Three held cards is illegal at the default.

#### RT-038 · hold_limit = 1
*Rules: R50, P3* · *Tunables: `hold_limit`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: SCV DSH
   hand: DCK PLV · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: `hold_limit` = 1 (others default)

1. **P1 ends turn, hold: DCK, PLV** → **illegal**: rejected, state unchanged
2. **P1 ends turn, hold: PLV** → P1 held count 1, loadout [PLV SCV DSH DCK]

*Why:* Only one card may be held.

#### RT-039 · Looted and played cards stow together in line order
*Rules: R50, D7, R9*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Rail Yard  hp 5 · loadout: DCK P9 DSH DCK SCV ‖ SCV
   hand: SCV SCV DSH · line: – · pools: Search 1
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 plays SCV** → P1 Search 2
2. **P1 loots CRW** → P1 Search 0
3. **P1 plays DSH** → P1 line [SCV CRW DSH]
4. **P1 ends turn, hold: none** → P1 loadout [DCK P9 DSH DCK SCV SCV SCV CRW DSH SCV]

*Why:* The line is played and looted cards alike, left to right; then the unheld Scavenge.

#### RT-040 · hold_looted = false: a looted card can't be held
*Rules: R50* · *Tunables: `hold_looted`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Rail Yard  hp 5 · loadout: DSH P9
   hand: SCV DCK · line: – · pools: Search 2
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 loots CRW** → legal
2. **P1 ends turn, hold: CRW** → **illegal**: rejected, state unchanged
3. **P1 ends turn, hold: DCK** → P1 loadout [DCK DSH P9 CRW SCV], held count 1

*Why:* Default: only hand cards can be held.

#### RT-041 · hold_looted = true: an unused looted card can be held, after the hand cards
*Rules: R50* · *Tunables: `hold_looted`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Rail Yard  hp 5 · loadout: DSH P9
   hand: SCV DCK · line: – · pools: Search 2
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: `hold_looted` = true (others default)

1. **P1 loots CRW** → legal
2. **P1 ends turn, hold: CRW, DCK** → P1 loadout [DCK CRW DSH P9 SCV], held count 2

*Why:* Held order: hand order, then line order. The Crowbar leaves the line, so the line stows empty.

#### RT-042 · hold_looted = true: a looted weapon that fired can't be held
*Rules: R50* · *Tunables: `hold_looted`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH P9
   hand: DCK · line: – · pools: Search 4
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: `hold_looted` = true (others default)

1. **P1 loots HRF** → legal
2. **P1 shoots HRF at P2** → damage before Brace 1
3. **P2 braces with nothing** → legal
4. **P1 ends turn, hold: HRF** → **illegal**: rejected, state unchanged
5. **P1 ends turn, hold: DCK** → P1 loadout [DCK DSH P9 HRF]

*Why:* 'Unused' means not fired and nothing attached to or from it.

#### RT-043 · Hits left in hand stow with the unheld hand, in hand order
*Rules: R52, R50*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 3 · loadout: P9 SCV
   hand: HIT SCV HIT DCK · line: DSH
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 ends turn, hold: DCK** → P1 loadout [DCK P9 SCV DSH HIT SCV HIT], Down yes

*Why:* The first Hit sits right after the 4th non-Hit, so it is inside the next draw (hand 5): P1 is Down.

#### RT-044 · Spec §16.4 example: hold Duck on turn 1 (hand 5)
*Rules: R50, R1, R39, R36, §16.4, S6, D8*

```
Round 1 · Zone card 1 (route A) · gas: none · drops: none
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **engine: start-of-turn draw** → P1 hand [SCV SCV SCV DCK DSH]
2. **P1 plays SCV** → legal
3. **P1 plays SCV** → legal
4. **P1 plays SCV** → legal
5. **P1 plays DSH** → P1 Search 3, Move 1
6. **P1 ends turn, hold: DCK** → P1 loadout [DCK DSH P9 SCV DCK DSH SCV SCV SCV DSH], held count 1; P2 hand [SCV SCV SCV DCK DSH]; to act P2
7. **P2 ends turn, hold: none** → P1 hand [DCK DSH P9 SCV DCK]; to act P1; round 2; Zone card 2; Bounty none

*Why:* Turn 2's hand is Duck, Dash, P-9, Scavenge, Duck, as the spec says. Round 2: 5 vs 5, so no Bounty.

#### RT-045 · packing_rule = rack_swap: no Hold, one card moved within the return row
*Rules: R51* · *Tunables: `packing_rule`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: SCV DSH
   hand: DCK P9 · line: SCV DSH
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: `packing_rule` = "rack_swap" (others default)

1. **P1 ends turn, hold: DCK** → **illegal**: rejected, state unchanged
2. **P1 ends turn, rack move 2 → 0** → P1 loadout [SCV DSH DCK SCV DSH P9], held count 0

*Why:* Return row: line (Scavenge, Dash) then hand (Duck, P-9). Moving the Duck (index 2) to the front gives Duck, Scavenge, Dash, P-9 under the loadout.

### Cover, Down and Brace

#### RT-046 · Cover 1 from another area
*Rules: R22, R24, R29*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH
   hand: – · line: HRF
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots HRF at P2** → damage before Brace 1, Cover 1, Down 0
2. **P2 braces with nothing** → Hits 1; P2 health 4, loadout [HIT SCV SCV SCV DCK DSH DSH P9 SCV DCK DSH]

*Why:* 2 − 1 = 1. The Hit goes on top of the loadout.

#### RT-047 · Same area ignores Cover
*Rules: R22*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: – · line: SMG
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots SMG at P2** → damage before Brace 2, Cover 0
2. **P2 braces with nothing** → P2 health 3

*Why:* Quarry has Cover 1, but both pawns are in it.

#### RT-048 · Marksman Rifle ignores Cover at range 2
*Rules: R22, §11*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Rail Yard  hp 5 · loadout: DSH
   hand: – · line: MKR
P2 @Farmstead  hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots MKR at P2** → damage before Brace 2, Cover 0
2. **P2 braces with nothing** → P2 health 3

*Why:* Rail Yard to Farmstead is distance 2 = RNG 2.

#### RT-049 · Gas areas keep their Cover; you may shoot into gas
*Rules: R22, R21*

```
Round 7 · Zone card 7 (route A) · gas: Docks, Farmstead, Rail Yard · drops: Quarry [LMG], Motel [HPL]
Bounty: aside · to act: P1
P1 @Core       hp 5 · loadout: DSH
   hand: – · line: HRF
P2 @Farmstead  hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots HRF at P2** → damage before Brace 1, Cover 1
2. **P2 braces with nothing** → P2 health 4

*Why:* Round 7, route A: Farmstead is gas but still Cover 1.

#### RT-050 · bounty_holder_loses_cover = true
*Rules: R22, R37* · *Tunables: `bounty_holder_loses_cover`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: P2 · to act: P1
P1 @Radio Hill hp 4 · loadout: HIT DSH SCV
   hand: – · line: HRF
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: `bounty_holder_loses_cover` = true (others default)

1. **P1 shoots HRF at P2** → damage before Brace 2, Cover 0
2. **P2 braces with nothing** → Hits 2, Bounty heal 0; P1 health 4; P2 health 3

*Why:* Cover counts as 0 against the holder. The claim heals 0: P1's only Hit is in the loadout (R15).

#### RT-051 · Down: a Hit in the next draw takes 1 off
*Rules: R23, D6* · *Tunables: `down_value`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: – · line: SMG
P2 @Quarry     hp 4 · loadout: HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots SMG at P2** → damage before Brace 1, Down 1
2. **P2 braces with DCK** → Hits 0; P2 health 4

*Why:* 2 − 1 (Down) = 1, braced by the Duck.

#### RT-052 · Down: a Hit below the 4th non-Hit counts at hand 5
*Rules: D4, D6, R23*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: – · line: SMG
P2 @Quarry     hp 4 · loadout: SCV SCV SCV DCK HIT DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **check (no action)** → P2 Down yes
2. **P1 shoots SMG at P2** → damage before Brace 1, Down 1
3. **P2 braces with nothing** → P2 health 3

*Why:* The next draw runs to the 5th non-Hit (Dash), so the Hit after Duck is in it.

#### RT-053 · Same loadout at hand 4: not Down
*Rules: D4, D6* · *Tunables: `hand_size`, `supply_drop_cost`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: – · line: SMG
P2 @Quarry     hp 4 · loadout: SCV SCV SCV DCK ‖ HIT DSH DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: `hand_size` = 4, `supply_drop_cost` = 3 (others default)

1. **check (no action)** → P2 Down no
2. **P1 shoots SMG at P2** → damage before Brace 2, Down 0
3. **P2 braces with nothing** → P2 health 2

*Why:* With hand 4 the next draw stops at the Duck; the Hit is outside it.

#### RT-054 · down_enabled = false
*Rules: R23, D6* · *Tunables: `down_enabled`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: – · line: SMG
P2 @Quarry     hp 4 · loadout: HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: `down_enabled` = false (others default)

1. **check (no action)** → P2 Down no
2. **P1 shoots SMG at P2** → damage before Brace 2, Down 0
3. **P2 braces with nothing** → P2 health 2

*Why:* No Down at all.

#### RT-055 · Damage 0 after Down: no Brace step, nothing moves
*Rules: R24, R23* · *Depends on: RQ-05*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: – · line: P9
P2 @Quarry     hp 4 · loadout: HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots P9 at P2** → damage before Brace 0, Hits 0; no Brace step pending; P2 health 4, loadout [HIT SCV SCV SCV DCK DSH DSH P9 SCV DCK DSH]
2. **P1 shoots P9 at P2** → **illegal**: rejected, state unchanged

*Why:* P-9 DMG 1 − Down 1 = 0: no prompt, nothing moves, and the P-9 has used its shot.

#### RT-056 · Brace with held cards, in the chosen order, to the bottom
*Rules: R25, D5, P3, P11* · *Depends on: RQ-02*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: – · line: PSG
P2 @Quarry     hp 5 · loadout: DCK^ PLV^ SCV DSH SCV ‖ DCK P9 DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots PSG at P2** → damage before Brace 3
2. **P2 braces with PLV, DCK** → Hits 0; P2 loadout [SCV DSH SCV DCK P9 DSH PLV DCK], held count 0

*Why:* Vest 2 + Duck 1 = 3. Bottom order is the brace order: Vest, then Duck. Both held cards left the top, so the held count drops to 0.

#### RT-057 · Brace only from the next hand; over-bracing is allowed
*Rules: R25, D5*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: – · line: P9
P2 @Quarry     hp 5 · loadout: SCV PLV SCV DSH DSH ‖ DCK
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots P9 at P2** → damage before Brace 1
2. **P2 braces with DCK** → **illegal**: rejected, state unchanged
3. **P2 braces with SCV** → **illegal**: rejected, state unchanged
4. **P2 braces with PLV** → Hits 0; P2 loadout [SCV SCV DSH DSH DCK PLV], next draw [SCV SCV DSH DSH DCK]

*Why:* The Duck is 6th (outside the window); a Scavenge has no Brace. Brace 2 vs 1 damage is allowed. The Duck now enters the window.

#### RT-058 · Suppressor: no Brace step; Down still applies
*Rules: R27, R23*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: – · line: ASR+SUP
P2 @Quarry     hp 4 · loadout: HIT DCK PLV SCV SCV DSH ‖ P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots ASR at P2** → damage before Brace 2, Down 1, Hits 2; no Brace step pending; P2 health 2, loadout [HIT HIT HIT DCK PLV SCV SCV DSH P9 SCV DCK DSH]

*Why:* 3 − 1 = 2 Hits, although Duck and Vest were in the window.

#### RT-059 · Between shots the window is recomputed (Extended Mag)
*Rules: R28, R12, R23, R25*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: – · line: SMG+EXM
P2 @Quarry     hp 5 · loadout: DCK SCV SCV SCV DSH ‖ PLV DSH P9
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots SMG at P2** → damage before Brace 2, Down 0
2. **P2 braces with DCK** → Hits 1; P2 loadout [HIT SCV SCV SCV DSH PLV DSH P9 DCK], Down yes
3. **P1 shoots SMG at P2** → damage before Brace 1, Down 1
4. **P2 braces with PLV** → Hits 0; P2 health 4, loadout [HIT SCV SCV SCV DSH DSH P9 DCK PLV]

*Why:* After shot 1 the Duck is gone and the Vest has moved into the window, and the Hit makes P2 Down.

#### RT-060 · Short window and the LMG: a card braces once per turn
*Rules: R26, R30, R12, R28* · *Depends on: RQ-01*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: – · line: LMG
P2 @Quarry     hp 5 · loadout: DCK SCV
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots LMG at P2** → damage before Brace 2
2. **P2 braces with DCK** → Hits 1; P2 loadout [HIT SCV DCK]
3. **P1 shoots LMG at P2** → damage before Brace 1, Down 1
4. **P2 braces with DCK** → **illegal**: rejected, state unchanged
5. **P2 braces with nothing** → Hits 1; P2 health 3, loadout [HIT HIT SCV DCK]

*Why:* With 2 non-Hit cards the bottom is still in the window, but the Duck already braced this turn. P2 still answers the prompt with an empty Brace.

#### RT-061 · Extended Mag attached after the first shot gives one more
*Rules: R12, R11*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: EXM · line: SMG
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots SMG at P2** → damage before Brace 2
2. **P2 braces with nothing** → P2 health 3
3. **P1 shoots SMG at P2** → **illegal**: rejected, state unchanged
4. **P1 attaches EXM to SMG** → P1 line [SMG+EXM]
5. **P1 shoots SMG at P2** → damage before Brace 1, Down 1
6. **P2 braces with nothing** → P2 health 2

*Why:* The fire limit is checked at declare: fired 1, limit now 2.

#### RT-062 · Fire limits: the LMG fires twice, then no more
*Rules: R12*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: – · line: LMG
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots LMG at P2** → damage before Brace 2
2. **P2 braces with nothing** → P2 health 3
3. **P1 shoots LMG at P2** → damage before Brace 1, Down 1
4. **P2 braces with nothing** → P2 health 2
5. **P1 shoots LMG at P2** → **illegal**: rejected, state unchanged

*Why:* 2 + 1 = 3 Hits: Down costs the second burst 1 (spec §12).

#### RT-063 · Range and gas: shoot from gas; RNG 0 can't reach next door
*Rules: R21, R42*

```
Round 7 · Zone card 7 (route A) · gas: Docks, Farmstead, Rail Yard · drops: Quarry [LMG], Motel [HPL]
Bounty: aside · to act: P1
P1 @Farmstead  hp 5 · loadout: DSH
   hand: – · line: SMG HRF
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots SMG at P2** → **illegal**: rejected, state unchanged
2. **P1 shoots HRF at P2** → damage before Brace 1, Cover 1
3. **P2 braces with nothing** → P2 health 4

*Why:* P1 stands in gas (Farmstead, round 7 route A). Hunting Rifle RNG 1 reaches the Quarry.

#### RT-064 · Elimination by a shot ends the match; crate formed
*Rules: R45, R46, R29, §7*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: – · line: PSG
P2 @Quarry     hp 1 · loadout: HIT HIT HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH PLV HRF+RDS
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots PSG at P2** → damage before Brace 2, Down 1
2. **P2 braces with nothing** → P2 health 0, eliminated yes; **match ends: P1 wins** (shot); crate P2's in Quarry: [PLV HRF+RDS], free picks 1

*Why:* The first Hit empties the stack; the second must be taken from an empty stack: eliminated, the rest ignored. Crate = non-Starter, non-Hit cards; the rifle and its Red-dot are 1 card.

#### RT-065 · crate_free_picks = 0
*Rules: R46* · *Tunables: `crate_free_picks`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: – · line: PSG
P2 @Quarry     hp 0 · loadout: HIT HIT HIT HIT HIT SCV SCV SCV DCK DSH ‖ PLV
   hand: – · line: –
```
Balance: `crate_free_picks` = 0 (others default)

1. **P1 shoots PSG at P2** → damage before Brace 2
2. **P2 braces with nothing** → **match ends: P1 wins** (shot); crate P2's in Quarry: [PLV], free picks 0

*Why:* The crate is still built; the shooter gets no free pick.

### Frag Grenade

#### RT-066 · Frag into an adjacent area: 2 damage, Cover ignored, Brace applies, Spent
*Rules: R31, R32, R20, P12* · *Depends on: RQ-03*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH
   hand: FRG · line: –
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 throws a Frag at Quarry** → P2: damage before Brace 2, Down 0; Brace prompt to P2
2. **P2 braces with DCK** → P2: Hits 1; P1 line [], hand []; P2 health 4; removed [FRG]

*Why:* Quarry Cover 1 is ignored. The Frag never stays in the line.

#### RT-067 · Frag on your own area: opponent braces first, then you; Down for you
*Rules: R33, R34, R32*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 4 · loadout: HIT DCK SCV SCV SCV DSH
   hand: FRG · line: –
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 throws a Frag at Quarry** → P2: damage before Brace 2, Down 0, P1: damage before Brace 1, Down 1; Brace prompt to P2
2. **P2 braces with nothing** → Brace prompt to P1; P2 health 5
3. **P1 braces with DCK** → no Brace step pending; P1 health 4, loadout [HIT SCV SCV SCV DSH DCK]; P2 health 3

*Why:* P1's next draw is the top of its loadout now (a Hit, so Down). Hits land together after both braces.

#### RT-068 · Frag: not the turn it is looted; range ≤ 1; an empty area is a wasted throw
*Rules: R31, R9, R20* · *Depends on: RQ-03*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: FRG · line: – · pools: Search 3
P2 @Radio Hill hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 loots FRG** → P1 line [FRG], hand [FRG]
2. **P1 throws a Frag at Motel** → **illegal**: rejected, state unchanged
3. **P1 throws a Frag at Core** → no Brace step pending; P1 hand [], line [FRG]; removed [FRG]
4. **P1 throws a Frag at Radio Hill** → **illegal**: rejected, state unchanged

*Why:* Motel is distance 2. The Core is empty: legal, Spent. The looted Frag can't be thrown this turn.

#### RT-069 · Frag eliminates both: more non-Hit cards wins (hand and line count)
*Rules: R47, R34, D2, R45*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 0 · loadout: HIT HIT HIT HIT HIT DSH DSH P9 SCV DCK ‖ DSH
   hand: FRG SCV SCV · line: SCV DCK
P2 @Quarry     hp 0 · loadout: HIT HIT HIT HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK
   hand: – · line: –
```
Balance: defaults

1. **P1 throws a Frag at Quarry** → P2: damage before Brace 1, P1: damage before Brace 1
2. **P2 braces with nothing** → legal
3. **P1 braces with nothing** → P1 eliminated yes, non-Hit cards 10; P2 eliminated yes, non-Hit cards 9; **match ends: P1 wins** (frag)

*Why:* Both must take a Hit with an empty stack. P1 has 6 + 2 + 2 = 10 non-Hit cards (the thrown Frag is gone), P2 has 9.

#### RT-070 · Frag eliminates both with equal counts: draw
*Rules: R47*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 0 · loadout: HIT HIT HIT HIT HIT DSH DSH P9 SCV DCK ‖ DSH
   hand: FRG SCV SCV · line: SCV DCK
P2 @Quarry     hp 0 · loadout: HIT HIT HIT HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 throws a Frag at Quarry** → legal
2. **P2 braces with nothing** → legal
3. **P1 braces with nothing** → **match ends: draw** (frag)

*Why:* 10 vs 10 non-Hit cards.

#### RT-071 · Frag on yourself as the Bounty holder: no claim
*Rules: R35, R37*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: P1 · to act: P1
P1 @Quarry     hp 4 · loadout: SCV SCV SCV DCK DSH ‖ DSH
   hand: FRG · line: HIT
P2 @Radio Hill hp 3 · loadout: HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 throws a Frag at Quarry** → Brace prompt to P1
2. **P1 braces with nothing** → Bounty heal 0; P1 health 2, line [HIT]

*Why:* Only P1 is in the Quarry. You never claim the Bounty from Hits on yourself.

#### RT-072 · Frag claims the Bounty from the holder
*Rules: R37, R15*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: P2 · to act: P1
P1 @Radio Hill hp 4 · loadout: SCV SCV SCV DCK DSH ‖ DSH
   hand: FRG · line: HIT
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 throws a Frag at Quarry** → legal
2. **P2 braces with nothing** → Bounty heal 1; P1 health 5, line []; P2 health 3

*Why:* A Frag resolution that lands ≥ 1 Hit on the holder heals the thrower 1 (the line Hit).

#### RT-073 · Frag: a thrower eliminated by their own Frag doesn't claim
*Rules: R34, R37, R45, R47* · *Depends on: RQ-06*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: P2 · to act: P1
P1 @Quarry     hp 0 · loadout: HIT HIT HIT HIT SCV SCV SCV DCK DSH
   hand: FRG · line: HIT
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 throws a Frag at Quarry** → P2: damage before Brace 2, P1: damage before Brace 1, Down 1
2. **P2 braces with nothing** → legal
3. **P1 braces with nothing** → Bounty heal 0; P1 eliminated yes, line [HIT]; P2 health 3; **match ends: P2 wins** (frag)

*Why:* All Hits land together: P1 must take 1 with an empty stack and is out. The claim (R34 step 3) would heal P1's line Hit, but an eliminated shooter doesn't claim.

### Bounty

#### RT-074 · Round start: the Bounty goes to strictly more health
*Rules: R36, R39, D3*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P2
P1 @Core       hp 4 · loadout: HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P2 ends turn, hold: none** → to act P1; round 6; Zone card 6; Bounty P2; gas [Docks, Farmstead]; drops Motel [HPL]

*Why:* 5 > 4: P2 holds it. Route A card 6 also closes Farmstead and drops the Heavy Plate on the Motel (R39 order).

#### RT-075 · Round start: a tie sets the Bounty aside
*Rules: R36*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: P2 · to act: P2
P1 @Core       hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P2 ends turn, hold: none** → round 6; Bounty none

*Why:* 5 vs 5: nobody holds it, even last round's holder.

#### RT-076 · The holder keeps the Bounty all round
*Rules: R36, R37*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: P2 · to act: P1
P1 @Quarry     hp 4 · loadout: HIT SCV SCV SCV
   hand: – · line: SMG
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots SMG at P2** → legal
2. **P2 braces with nothing** → P1 health 4; P2 health 3; Bounty P2

*Why:* P2 now has less health than P1 but keeps the Bounty until the next round start.

#### RT-077 · Claim: the shooter heals 1 from the line
*Rules: R37, R15, §7*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: P2 · to act: P1
P1 @Quarry     hp 3 · loadout: HIT SCV SCV
   hand: – · line: HIT SMG
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots SMG at P2** → legal
2. **P2 braces with nothing** → Hits 2, Bounty heal 1; P1 health 4, line [SMG]; P2 health 3

*Why:* The line Hit (played as Adrenaline earlier) returns to P1's stack. The loadout Hit can't be healed.

#### RT-078 · Claim with nothing to heal heals 0
*Rules: R37, R15*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: P2 · to act: P1
P1 @Quarry     hp 4 · loadout: HIT SCV SCV
   hand: – · line: SMG
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots SMG at P2** → legal
2. **P2 braces with nothing** → Bounty heal 0; P1 health 4

*Why:* The claim happens but there is no Hit in line or hand.

#### RT-079 · A fully braced shot gives no claim
*Rules: R37, R25*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: P2 · to act: P1
P1 @Quarry     hp 3 · loadout: HIT SCV SCV
   hand: – · line: HIT SMG
P2 @Quarry     hp 5 · loadout: PLV^ SCV SCV SCV DCK ‖ DSH DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots SMG at P2** → legal
2. **P2 braces with PLV** → Hits 0, Bounty heal 0; P1 health 3, line [HIT SMG]

*Why:* ≥ 1 Hit must land on the holder.

#### RT-080 · LMG: each burst claims
*Rules: R37, R12, R23*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: P2 · to act: P1
P1 @Quarry     hp 2 · loadout: HIT
   hand: – · line: HIT HIT LMG
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots LMG at P2** → legal
2. **P2 braces with nothing** → Hits 2, Bounty heal 1; P1 health 3, line [HIT LMG]
3. **P1 shoots LMG at P2** → damage before Brace 1
4. **P2 braces with nothing** → Hits 1, Bounty heal 1; P1 health 4, line [LMG]; P2 health 2

*Why:* Once per shot, so twice. Each heal takes the last line Hit.

#### RT-081 · bounty_heal = 0
*Rules: R37* · *Tunables: `bounty_heal`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: P2 · to act: P1
P1 @Quarry     hp 3 · loadout: HIT SCV SCV
   hand: – · line: HIT SMG
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: `bounty_heal` = 0 (others default)

1. **P1 shoots SMG at P2** → legal
2. **P2 braces with nothing** → Hits 2, Bounty heal 0; P1 health 3, line [HIT SMG]

*Why:* The claim heals nothing.

### Gas and the Zone deck

#### RT-082 · Gas check: 1 Hit before Pack; held cards go above it; Down for the next turn
*Rules: R40, R50, D6*

```
Round 7 · Zone card 7 (route A) · gas: Docks, Farmstead, Rail Yard · drops: Quarry [LMG], Motel [HPL]
Bounty: aside · to act: P1
P1 @Farmstead  hp 5 · loadout: SCV P9 DSH
   hand: DCK SCV · line: DSH
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 ends turn, hold: DCK** → P1 health 4, loadout [DCK HIT SCV P9 DSH DSH SCV], Down yes, held count 1; to act P2

*Why:* No Brace, no Down reduction, no Bounty claim on a gas Hit.

#### RT-083 · No loot in gas (piles and drops); moving through gas is fine
*Rules: R42, R10*

```
Round 11 · Zone card 11 (route A) · gas: Docks, Farmstead, Rail Yard, Radio Hill, Quarry, Motel · drops: Quarry [LMG], Motel [HPL PHS], Core [L50]
Bounty: aside · to act: P1
P1 @Motel      hp 5 · loadout: DSH
   hand: DSH · line: – · pools: Search 4
P2 @Core       hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **check (no action)** → gas [Docks, Farmstead, Motel, Quarry, Radio Hill, Rail Yard]
2. **P1 loots MED** → **illegal**: rejected, state unchanged
3. **P1 loots drop:PHS** → **illegal**: rejected, state unchanged
4. **P1 loots drop:HPL** → **illegal**: rejected, state unchanged
5. **P1 plays DSH** → legal
6. **P1 moves to Rail Yard** → P1 area Rail Yard

*Why:* Round 11, route A: every outer area is gas. The Motel's drops stay there, unlootable.

#### RT-084 · Route A, cards 3 and 4: a drop lands, then gas closes
*Rules: R39, §8*

```
Round 2 · Zone card 2 (route A) · gas: none · drops: none
Bounty: aside · to act: P2
P1 @Radio Hill hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P2 ends turn, hold: none** → Zone card 3; gas []; drops Quarry [LMG]
2. **P1 ends turn, hold: none** → to act P2
3. **P2 ends turn, hold: none** → round 4; Zone card 4; gas [Docks]

*Why:* Zone card k is flipped at the start of round k.

#### RT-085 · Route B, card 6
*Rules: R39, §8, S2*

```
Round 5 · Zone card 5 (route B) · gas: Radio Hill · drops: Docks [LMG]
Bounty: aside · to act: P2
P1 @Core       hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P2 ends turn, hold: none** → gas [Quarry, Radio Hill]; drops Docks [LMG], Rail Yard [HPL]

*Why:* B: card 4 closed Radio Hill; card 6 closes Quarry and drops the Heavy Plate on the Rail Yard.

#### RT-086 · Route C, card 6
*Rules: R39, §8, S2*

```
Round 5 · Zone card 5 (route C) · gas: Farmstead · drops: Motel [LMG]
Bounty: aside · to act: P2
P1 @Core       hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P2 ends turn, hold: none** → gas [Farmstead, Rail Yard]; drops Motel [LMG], Radio Hill [HPL]

*Why:* C: card 4 closed Farmstead; card 6 closes Rail Yard and drops on Radio Hill.

#### RT-087 · Supply drop cost 4 (default)
*Rules: R10, §16.4a* · *Tunables: `supply_drop_cost`*

```
Round 3 · Zone card 3 (route A) · gas: none · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: SCV · line: – · pools: Search 3
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 loots drop:LMG** → **illegal**: rejected, state unchanged
2. **P1 plays SCV** → legal
3. **P1 loots drop:LMG** → P1 line [SCV LMG], Search 0; drops Quarry []

*Why:* Search 3 isn't enough; 4 is.

#### RT-088 · supply_drop_cost = 3
*Rules: R10* · *Tunables: `supply_drop_cost`*

```
Round 3 · Zone card 3 (route A) · gas: none · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: – · line: – · pools: Search 3
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: `supply_drop_cost` = 3 (others default)

1. **P1 loots drop:LMG** → P1 line [LMG], Search 0

*Why:* The paper v0.2 value.

#### RT-089 · supply_drop_ready_delay = 1: not in the round it lands
*Rules: R10a* · *Tunables: `supply_drop_ready_delay`*

```
Round 3 · Zone card 3 (route A) · gas: none · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ P9
   hand: – · line: SCV SCV SCV DCK · pools: Search 4
P2 @Radio Hill hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: `supply_drop_ready_delay` = 1 (others default)

1. **P1 loots drop:LMG** → **illegal**: rejected, state unchanged
2. **P1 ends turn, hold: none** → P1 loadout [SCV SCV SCV DCK DSH P9 SCV SCV SCV DCK]
3. **P2 ends turn, hold: none** → P1 hand [SCV SCV SCV DCK DSH]; round 4
4. **P1 plays SCV** → legal
5. **P1 plays SCV** → legal
6. **P1 plays SCV** → legal
7. **P1 plays DCK** → legal
8. **P1 loots drop:LMG** → P1 line [SCV SCV SCV DCK LMG]

*Why:* It landed in round 3, so it is lootable from round 4.

#### RT-090 · Gas Hit with an empty health stack eliminates; no free pick
*Rules: R41, R45, R46*

```
Round 7 · Zone card 7 (route A) · gas: Docks, Farmstead, Rail Yard · drops: Quarry [LMG], Motel [HPL]
Bounty: aside · to act: P1
P1 @Farmstead  hp 0 · loadout: HIT HIT HIT HIT HIT SCV SCV SCV DCK DSH ‖ BTS
   hand: – · line: –
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 ends turn, hold: none** → P1 eliminated yes; **match ends: P2 wins** (gas); crate P1's in Farmstead: [BTS], free picks 0

*Why:* There is no shooter, so the crate has no free pick.

#### RT-091 · Final circle I: 1 Hit each, the holder 1 more, no Brace or Down
*Rules: R43, R38, R39, R36*

```
Round 11 · Zone card 11 (route A) · gas: Docks, Farmstead, Rail Yard, Radio Hill, Quarry, Motel · drops: Quarry [LMG], Motel [HPL PHS], Core [L50]
Bounty: aside · to act: P2
P1 @Core       hp 4 · loadout: HIT DCK SCV SCV SCV DSH ‖ DSH P9 SCV DCK
   hand: – · line: –
P2 @Core       hp 3 · loadout: HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK
   hand: – · line: –
```
Balance: defaults

1. **P2 ends turn, hold: none** → P1 health 2, hand [HIT HIT HIT DCK SCV SCV SCV DSH]; P2 health 2, loadout [HIT HIT HIT SCV SCV SCV DCK DSH DSH P9 SCV DCK]; Zone card 12; Bounty P1

*Why:* Bounty first (4 > 3), then card 12: P1 takes 1 + 1, P2 takes 1. Then P1 draws them.

#### RT-092 · Final circle II eliminates both: more non-Hit cards wins
*Rules: R43, R47, R38*

```
Round 12 · Zone card 12 (route A) · gas: Docks, Farmstead, Rail Yard, Radio Hill, Quarry, Motel · drops: Quarry [LMG], Motel [HPL PHS], Core [L50]
Bounty: aside · to act: P2
P1 @Core       hp 1 · loadout: HIT HIT HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
P2 @Core       hp 2 · loadout: HIT HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK
   hand: – · line: –
```
Balance: defaults

1. **P2 ends turn, hold: none** → P1 eliminated yes; P2 eliminated yes; Bounty P2; **match ends: P1 wins** (final_circle)

*Why:* P2 (holder) must take 3 with 2 health; P1 must take 2 with 1. Simultaneous: 10 vs 9 non-Hit cards.

#### RT-093 · Final circle double elimination with equal counts: draw
*Rules: R43, R47*

```
Round 12 · Zone card 12 (route A) · gas: Docks, Farmstead, Rail Yard, Radio Hill, Quarry, Motel · drops: Quarry [LMG], Motel [HPL PHS], Core [L50]
Bounty: aside · to act: P2
P1 @Core       hp 1 · loadout: HIT HIT HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
P2 @Core       hp 1 · loadout: HIT HIT HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P2 ends turn, hold: none** → Bounty none; **match ends: draw** (final_circle)

*Why:* Both take 2 with 1 health; 10 vs 10.

#### RT-094 · final_circle_hits shorter than 3: the last value repeats
*Rules: R43* · *Tunables: `final_circle_hits`*

```
Round 13 · Zone card 13 (route A) · gas: Docks, Farmstead, Rail Yard, Radio Hill, Quarry, Motel · drops: Quarry [LMG], Motel [HPL PHS], Core [L50]
Bounty: aside · to act: P2
P1 @Core       hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
P2 @Core       hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: `final_circle_hits` = [1, 2] (others default)

1. **P2 ends turn, hold: none** → P1 health 3; P2 health 3; Zone card 14

*Why:* Card 14 reads index 2, which doesn't exist; the last value (2) repeats. No holder at 5 vs 5.

#### RT-095 · bounty_final_circle_extra = 0
*Rules: R38* · *Tunables: `bounty_final_circle_extra`*

```
Round 11 · Zone card 11 (route A) · gas: Docks, Farmstead, Rail Yard, Radio Hill, Quarry, Motel · drops: Quarry [LMG], Motel [HPL PHS], Core [L50]
Bounty: aside · to act: P2
P1 @Core       hp 4 · loadout: HIT DCK SCV SCV SCV DSH ‖ DSH P9 SCV DCK
   hand: – · line: –
P2 @Core       hp 3 · loadout: HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK
   hand: – · line: –
```
Balance: `bounty_final_circle_extra` = 0 (others default)

1. **P2 ends turn, hold: none** → P1 health 3; P2 health 2; Bounty P1

*Why:* The holder takes only the base 1.

#### RT-096 · Hard end after both turns of round 14: more health wins
*Rules: R44, R48, D8*

```
Round 14 · Zone card 14 (route A) · gas: Docks, Farmstead, Rail Yard, Radio Hill, Quarry, Motel · drops: Quarry [LMG], Motel [HPL PHS], Core [L50]
Bounty: aside · to act: P1
P1 @Core       hp 3 · loadout: HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
P2 @Core       hp 2 · loadout: HIT HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 ends turn, hold: none** → to act P2; match continues
2. **P2 ends turn, hold: none** → **match ends: P1 wins** (hard_end)

*Why:* The match doesn't end after P1's turn, only after P2's.

#### RT-097 · Hard end, health tied: more non-Hit cards wins
*Rules: R48, D2*

```
Round 14 · Zone card 14 (route A) · gas: Docks, Farmstead, Rail Yard, Radio Hill, Quarry, Motel · drops: Quarry [LMG], Motel [HPL PHS], Core [L50]
Bounty: aside · to act: P2
P1 @Core       hp 2 · loadout: HIT HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH HRF+RDS
   hand: – · line: –
P2 @Core       hp 2 · loadout: HIT HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P2 ends turn, hold: none** → P1 non-Hit cards 11; **match ends: P1 wins** (hard_end)

*Why:* 11 vs 10 (the rifle with its Red-dot counts once).

#### RT-098 · Hard end, all tied: draw
*Rules: R48*

```
Round 14 · Zone card 14 (route A) · gas: Docks, Farmstead, Rail Yard, Radio Hill, Quarry, Motel · drops: Quarry [LMG], Motel [HPL PHS], Core [L50]
Bounty: aside · to act: P2
P1 @Core       hp 2 · loadout: HIT HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
P2 @Core       hp 2 · loadout: HIT HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P2 ends turn, hold: none** → **match ends: draw** (hard_end)

*Why:* Same health, same count.

#### RT-099 · zone_hard_end_card = 12
*Rules: R44* · *Tunables: `zone_hard_end_card`*

```
Round 12 · Zone card 12 (route A) · gas: Docks, Farmstead, Rail Yard, Radio Hill, Quarry, Motel · drops: Quarry [LMG], Motel [HPL PHS], Core [L50]
Bounty: aside · to act: P1
P1 @Core       hp 4 · loadout: HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
P2 @Core       hp 3 · loadout: HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: `zone_hard_end_card` = 12 (others default)

1. **P1 ends turn, hold: none** → to act P2; match continues
2. **P2 ends turn, hold: none** → Zone card 12; **match ends: P1 wins** (hard_end)

*Why:* The deck is cards 1–12: the match ends after round 12, which was final circle I.

#### RT-100 · Concede
*Rules: R49*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Core       hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 concedes** → **match ends: P2 wins** (concede)

*Why:* Allowed at any time.

### Private view (fairness)

#### RT-101 · Default view of the opponent
*Rules: P1, P2, P3, P4, P5, P6, P7, P10, P13* · *Depends on: RQ-10*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH
   hand: – · line: HRF
P2 @Quarry     hp 4 · loadout: DCK^ PLV^ HIT SCV SCV DSH ‖ P9 SCV DSH
   hand: – · line: –
```
Balance: defaults

1. **view(P1)** → view includes `{"opponent": {"area": "quarry", "health": 4, "held_count": 2, "next_draw_hits": 1, "down": true, "loadout_count": 9, "hand_count": 0, "line": []}}`; view has no `opponent.loadout`, `opponent.held_cards`, `opponent.hand`

*Why:* P1 sees how many cards P2 held and the Hit count in the next draw, never which cards.

#### RT-102 · Fairness: P2's private fields don't change P1's view
*Rules: P18, P1, P2* · *Depends on: RQ-10*

**Setup A:**
```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH
   hand: – · line: HRF
P2 @Quarry     hp 4 · loadout: DCK^ PLV^ HIT SCV SCV DSH ‖ P9 SCV DSH
   hand: – · line: –
```
Balance: defaults

**Setup B** (differs only in private fields):
```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH
   hand: – · line: HRF
P2 @Quarry     hp 4 · loadout: SMK^ BTS^ HIT DSH SCV SCV ‖ SCV P9 DSH
   hand: – · line: –
```
Balance: defaults

1. **view(P1)** → **identical to the view on setup B**

*Why:* Setup B differs only in P2's private fields: held cards Smoke and Boots instead of Duck and Vest, and the order below.

#### RT-103 · Fairness on the active player's hand
*Rules: P8, P9, P18* · *Depends on: RQ-10*

**Setup A:**
```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 4 · loadout: DSH
   hand: SCV HIT DCK · line: –
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

**Setup B** (differs only in private fields):
```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 4 · loadout: DSH
   hand: PLV HIT DSH · line: –
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **view(P2)** → view includes `{"opponent": {"hand_count": 3, "hand_hits": 1}}`; **identical to the view on setup B**

*Why:* P2 sees 3 cards in P1's hand, 1 of them a Hit. Setup B has Vest, Hit, Dash in hand instead.

#### RT-104 · Fairness: the stowed, unheld hand stays private
*Rules: P14, P18, R50* · *Depends on: RQ-10*

**Setup A:**
```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH P9 SCV DCK DSH
   hand: SCV DCK · line: SCV
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

**Setup B** (differs only in private fields):
```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH P9 SCV DCK DSH
   hand: PLV SMK · line: SCV
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 ends turn, hold: none** → to act P2
2. **view(P2)** → view includes `{"opponent": {"loadout_count": 8, "held_count": 0, "next_draw_hits": 0}}`; **identical to the view on setup B**

*Why:* Setup B stows a different unheld hand (Vest, Smoke). P2 only learns that 2 cards went under.

#### RT-105 · held_cards_public = true
*Rules: P15* · *Tunables: `held_cards_public`* · *Depends on: RQ-10*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH
   hand: – · line: HRF
P2 @Quarry     hp 4 · loadout: DCK^ PLV^ HIT SCV SCV DSH ‖ P9 SCV DSH
   hand: – · line: –
```
Balance: `held_cards_public` = true (others default)

1. **view(P1)** → view includes `{"opponent": {"held_cards": ["DCK", "PLV"], "held_count": 2}}`; view has no `opponent.loadout`

*Why:* Held identities show; the rest of the loadout stays private.

#### RT-106 · hits_on_top_public = false: Down still shows
*Rules: P16, P5* · *Tunables: `hits_on_top_public`* · *Depends on: RQ-10*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH
   hand: – · line: HRF
P2 @Quarry     hp 4 · loadout: DCK^ PLV^ HIT SCV SCV DSH ‖ P9 SCV DSH
   hand: – · line: –
```
Balance: `hits_on_top_public` = false (others default)

1. **view(P1)** → view includes `{"opponent": {"down": true}}`; view has no `opponent.next_draw_hits`, `opponent.hand_hits`

*Why:* The shooter's damage depends on Down, so it is always public.

#### RT-107 · loadout_count_public = false: hidden, but the tiebreak uses the true count
*Rules: P17, R48* · *Tunables: `loadout_count_public`* · *Depends on: RQ-10*

```
Round 14 · Zone card 14 (route A) · gas: Docks, Farmstead, Rail Yard, Radio Hill, Quarry, Motel · drops: Quarry [LMG], Motel [HPL PHS], Core [L50]
Bounty: aside · to act: P2
P1 @Core       hp 2 · loadout: HIT HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
P2 @Core       hp 2 · loadout: HIT HIT HIT SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH PLV
   hand: – · line: –
```
Balance: `loadout_count_public` = false (others default)

1. **view(P1)** → view has no `opponent.loadout_count`
2. **P2 ends turn, hold: none** → **match ends: P2 wins** (hard_end)

*Why:* 11 vs 10 non-Hit cards decides it although neither player could see the count.

#### RT-108 · Shot preview vs Brace prompt
*Rules: P19, P20, R24* · *Depends on: RQ-10*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH
   hand: – · line: ASR
P2 @Quarry     hp 4 · loadout: DCK^ PLV^ HIT SCV SCV DSH ‖ P9 SCV DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots ASR at P2** → damage before Brace 1, Cover 1, Down 1
2. **view(P1)** → view includes `{"shot_preview": {"damage": 1, "may_brace": true}}`; view has no `brace_prompt`
3. **view(P2)** → view includes `{"brace_prompt": {"damage": 1, "next_hand": ["DCK", "PLV", "SCV", "SCV", "DSH"]}}`
4. **P2 braces with DCK** → Hits 0

*Why:* 3 − Cover 1 − Down 1 = 1. The shooter never sees the target's next hand.

### Undo

#### RT-109 · Undo restores the exact state, one action at a time, back to the turn start
*Rules: U1, U2, U3*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH
   hand: SCV DSH DCK · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 plays SCV** → legal
2. **P1 plays DSH** → logged actions 2
3. **P1: undo** → P1 hand [DSH DCK], line [SCV], Move 0, Search 1; logged actions 1
4. **P1: undo** → P1 hand [SCV DSH DCK], line [], Search 0; logged actions 0
5. **P1: undo** → **illegal**: rejected, state unchanged

*Why:* Hand order is restored too, and undone actions leave the saved action list (action_count counts actions since the fixture). The draw is fixed: nothing before the turn start can be undone.

#### RT-110 · Undo a loot
*Rules: U4, U2*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH
   hand: – · line: – · pools: Search 4
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 loots HRF** → piles Radio Hill HRF×2
2. **P1: undo** → P1 Search 4, line []; piles Radio Hill HRF×3

*Why:* A loot reveals nothing in 1v1, so it can be undone.

#### RT-111 · A declared shot commits everything before it
*Rules: U3*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Quarry     hp 5 · loadout: DSH
   hand: DSH · line: SMG
P2 @Quarry     hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 plays DSH** → legal
2. **P1 shoots SMG at P2** → legal
3. **P1: undo** → **illegal**: rejected, state unchanged
4. **P2 braces with nothing** → legal
5. **P1: undo** → **illegal**: rejected, state unchanged
6. **check (no action)** → P1 Move 1

*Why:* No undo while the Brace is pending or after it.

#### RT-112 · End turn can't be undone; the next player starts clean
*Rules: U3, U5*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH P9 SCV DCK DSH
   hand: SCV · line: –
P2 @Motel      hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 ends turn, hold: none** → to act P2
2. **P1: undo** → **illegal**: rejected, state unchanged
3. **P2: undo** → **illegal**: rejected, state unchanged
4. **P2 plays SCV** → legal
5. **P2: undo** → P2 hand [SCV SCV SCV DCK DSH]

*Why:* Hold toggles before End turn aren't actions (U5), so only end_turn itself is logged.

### Spec worked example (§7)

#### RT-113 · §7: Ana's scoped rifle, Ben braces with the held Plate Vest
*Rules: R22, R25, D5, §7* · *Tunables: `hand_size`, `supply_drop_cost`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH
   hand: – · line: HRF+RDS
P2 @Quarry     hp 5 · loadout: PLV^ SCV DSH SCV ‖ DCK DSH P9 SCV DCK DSH SCV
   hand: – · line: –
```
Balance: `hand_size` = 4, `supply_drop_cost` = 3 (others default)

1. **P1 shoots HRF at P2** → damage before Brace 2, Cover 1, Down 0
2. **P2 braces with PLV** → Hits 0; P2 health 5, next draw [SCV DSH SCV DCK]

*Why:* (2 + 1) − 1 = 2, Vest Brace 2 → 0 Hits. Still 4 cards next turn, but no armour and no Move from the Vest.

#### RT-114 · §7: with a Suppressor, 2 Hits land; Ben draws 6
*Rules: R27, R1, §7* · *Tunables: `hand_size`, `supply_drop_cost`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH P9 SCV
   hand: – · line: HRF+RDS+SUP
P2 @Quarry     hp 5 · loadout: PLV^ SCV DSH SCV ‖ DCK DSH P9 SCV DCK DSH SCV
   hand: – · line: –
```
Balance: `hand_size` = 4, `supply_drop_cost` = 3 (others default)

1. **P1 shoots HRF at P2** → damage before Brace 2, Hits 2; P2 health 3, Down yes, next draw [HIT HIT PLV SCV DSH SCV]
2. **P1 ends turn, hold: none** → P2 hand [HIT HIT PLV SCV DSH SCV]; to act P2

*Why:* Two of the six cards are Adrenaline.

#### RT-115 · §7: the follow-up shot loses 1 to Down (1v1: Ana's second gun)
*Rules: R23, R28, §7* · *Tunables: `hand_size`, `supply_drop_cost`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH
   hand: – · line: HRF+RDS+SUP MKR
P2 @Quarry     hp 5 · loadout: PLV^ SCV DSH SCV ‖ DCK DSH P9 SCV DCK DSH SCV
   hand: – · line: –
```
Balance: `hand_size` = 4, `supply_drop_cost` = 3 (others default)

1. **P1 shoots HRF at P2** → Hits 2
2. **P1 shoots MKR at P2** → damage before Brace 1, Cover 0, Down 1
3. **P2 braces with PLV** → Hits 0; P2 health 3

*Why:* Spec: 'Cid's follow-up shot that round deals 1 less'. In 1v1 the follow-up is Ana's Marksman Rifle: 2 − 1 = 1.

#### RT-116 · §7 at hand 5: the Suppressor variant draws 7
*Rules: R1, R27* · *Tunables: `hand_size`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
P1 @Radio Hill hp 5 · loadout: DSH P9 SCV
   hand: – · line: HRF+RDS+SUP
P2 @Quarry     hp 5 · loadout: PLV^ SCV DSH SCV DCK ‖ DSH P9 SCV DCK DSH SCV
   hand: – · line: –
```
Balance: defaults

1. **P1 shoots HRF at P2** → Hits 2
2. **P1 ends turn, hold: none** → P2 hand [HIT HIT PLV SCV DSH SCV DCK]

*Why:* Hand 5 adds the Duck.

### Setup and tunables

#### RT-117 · New match: P2 drops first, outer areas only, hot drop allowed, round 1 starts
*Rules: S3, S4, S5, S6, R39, U1* · *Tunables: `standard_pack`* · *Depends on: RQ-04*

```
New match · route A · both loadouts in the Standard pack · nobody dropped yet
```
Balance: defaults

1. **P1 drops on Motel** → **illegal**: rejected, state unchanged
2. **P2 drops on Core** → **illegal**: rejected, state unchanged
3. **P2 drops on Motel** → legal
4. **P1 drops on Motel** → P1 area Motel, health 5, hand [SCV SCV SCV DCK DSH]; P2 area Motel, health 5, loadout [SCV SCV SCV DCK DSH DSH P9 SCV DCK DSH]; to act P1; round 1; Zone card 1; Bounty none; gas []; piles Docks SMG×3, Core ASR×2

*Why:* Both on the Motel is a hot drop. Zone card 1 is Calm; 5 vs 5 so no Bounty.

#### RT-118 · Tunables at setup: health 6, piles 4 / 3
*Rules: S3, S4* · *Tunables: `health`, `pile_size_outer`, `pile_size_core`* · *Depends on: RQ-04*

```
New match · route A · both loadouts in the Standard pack · nobody dropped yet
```
Balance: `health` = 6, `pile_size_outer` = 4, `pile_size_core` = 3

1. **P2 drops on Docks** → legal
2. **P1 drops on Quarry** → P1 health 6; P2 health 6; piles Docks SMG×4 BTS×4, Core ASR×3 SUP×3

*Why:* Every health stack holds `health` Hits.

#### RT-119 · crate_cost: loot a crate card for Search 1, or 0
*Rules: R10, R46* · *Tunables: `crate_cost`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
Crates: Motel [PLV HRF+RDS]
P1 @Motel      hp 5 · loadout: DSH
   hand: – · line: – · pools: Search 1
P2 @Core       hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: defaults

1. **P1 loots crate:PLV** → P1 Search 0, line [PLV]
2. **P1 loots crate:HRF+RDS** → **illegal**: rejected, state unchanged

*Why:* Engine support for 3–4 players (R46). crate_cost 1 per card; with crate_cost 0 see RT-120.

#### RT-120 · crate_cost = 0
*Rules: R10* · *Tunables: `crate_cost`*

```
Round 5 · Zone card 5 (route A) · gas: Docks · drops: Quarry [LMG]
Bounty: aside · to act: P1
Crates: Motel [PLV HRF+RDS]
P1 @Motel      hp 5 · loadout: DSH
   hand: – · line: –
P2 @Core       hp 5 · loadout: SCV SCV SCV DCK DSH ‖ DSH P9 SCV DCK DSH
   hand: – · line: –
```
Balance: `crate_cost` = 0 (others default)

1. **P1 loots crate:PLV** → legal
2. **P1 loots crate:HRF+RDS** → P1 line [PLV HRF+RDS]

*Why:* Free crate cards.

## Review log (Mid Game Designer gate)

The plan says the Mid Game Designer must review these cases before cz07 starts coding. The Mid Designer couldn't be spawned for this task, so QA did the pass in that role, using `.claude/agents/mid-game-designer.md` (implementation details and content values inside approved systems; system-level calls go to the Sr Game Designer).

Every case was checked again against §16 (D, P, S, U, R and §16.8) and against the §7 and §16.4 examples. Each expected value was then run through an independent reference reading of the rules: a small scratch model, written separately from the expectations and not committed. It covers the draw, every action, Brace, Frag, Bounty, the round start, gas, the final circle, the hard end, the per-seat view and undo. **All 120 cases agree with it.** Mutation check: raising any asserted health by 1 makes its case fail in all 49 places where health is asserted, so the comparison is live.

**Corrections made during review:**

- Health totals: three drafts gave a player too few Hits for the health shown (the Bounty holder in the frag-on-self case, the P2 of the 'holder keeps it' case, and the crate_free_picks victim). They were fixed so that health plus Hits in loadout, hand and line equals `health` everywhere except the deliberate short-loadout fixtures (RQ-11).
- The hold-a-Hit stow case explained the Down result with the wrong card positions. The text now says that only the first Hit is in the next draw.
- The first Ditch case cited a rule that doesn't exist. It now cites R19 and P12.
- Missing edge case: a 0-damage shot. A second shot with the same P-9 was added, which shows the shot is used (RQ-05).
- Missing edge case: R34 orders 'claim, then eliminations', and R37 says an eliminated shooter doesn't claim. These pull in different directions for a Frag that kills its own thrower, so a case was added (RQ-06).
- Coverage sweep against every ruling ID found 7 IDs that no case cited. D3 and D8 are now cited by existing cases. P14 (the stowed hand stays private) got its own fairness case. U1 (setup plus action list) is now cited by the drop case and the undo case, and the undo case checks that undone actions leave the action list. S1, S7 and U6 aren't rules-engine behaviour (match-setup screen, no timer, AI and telemetry), so they go to cz11, cz09 and cz18 (see the table below).
- Tunables: `down_value` (only value 1) and `standard_pack` (only true) are now cited by the cases that run them. `ai_think_budget_ms` is AI-only (cz09).
- Fairness cases: the second setup now replays the same actions, so a fairness check can happen after End turn (the stowed hand), not only on a fixed state.
- The reference model didn't log `brace` in the action list. Fixed, so replay counts match U1 (a brace is a defender action).

**Mid Designer's notes for the designer (no change needed here):**

- §8 says the final circle deals Hits "in turn order", but R43 says "to both players at once". In the prototype, §16 wins, so the cases use R43 (a simultaneous double elimination goes to R47). This makes a difference only when both players are eliminated by the same card.
- The plan (`prototype-milestone-plan.md`, cz04 row) names `../../qa/test-plans/loadout-loop-rules-cases.md`, but the brief and CallingCard's pattern use `documentation/qa/rules-test-cases.{md,json}`. The brief's path is used here. The producer should update the plan row or add a pointer.
- The §7 example has three players (Cid fires the follow-up). In 1v1 the follow-up is Ana's second weapon (RT-115). The arithmetic is the same: one point less for Down.

**Review verdict:** the cases match §16 as approved. 104 of 120 cases depend on no open question. The rest assume the proposed answers to the RQs below, and each case says which. RQ-01 (always a Brace step) and RQ-10 (view field names) matter most to cz07, because they shape the action list and the fairness test. **cz07 can start.** If the designer overrules an RQ, only the cases listed under it change.

## Rules questions

§16 is approved, but these points are open. Each has a proposed answer, and the dependent cases assume it. **Sr or Mid Game Designer: please confirm or overrule before cz07 ends.**

**RQ-01 · Is there a Brace step when the defender has no card that can brace?** R24 says there is no Brace step at damage 0, and R27 removes it for a Suppressor. Nothing says what happens when the damage is above 0 but the defender's next hand has no Brace card left (none printed, or all already braced this turn, R26). If the engine skips the prompt, the shooter learns something private about the next hand (P1, P18), and in hot-seat the speed of the reply gives it away.
- *Proposed:* Whenever damage before Brace is above 0 and there is no Suppressor, the engine always waits for a `brace` action, which may be empty. The UI may auto-send an empty Brace for a human defender with nothing to pick, after a short fixed delay. The AI always sends one. Every `brace("")` step in these cases assumes this.
- *Cases that assume it:* RT-060

**RQ-02 · Does the held count (P3) drop when a held card braces?** P3 shows how many cards the opponent held. R25 sends a braced card to the bottom and P11 reveals it, so a braced held card is no longer on top and is no longer secret.
- *Proposed:* Yes. The held count is the number of held cards still on top of the loadout. A braced held card loses its held mark. The mark also clears when the card is drawn.
- *Cases that assume it:* RT-056

**RQ-03 · Does a thrown Frag pass through the line?** U1 lists `frag(area)` as 'playing a Frag', and R6 says a play moves the card to the line. R20 says a Frag is Spent after it resolves.
- *Proposed:* No. The Frag goes from the hand straight out of the game (face up, P12). It never sits in the line, so it never changes line order or the stow. `play(FRG)` is illegal: a Frag is used only through `frag(area)`.
- *Cases that assume it:* RT-066, RT-068

**RQ-04 · How is the drop recorded?** S5 sets the drop order (P2, then P1, outer areas only), but U1's action list has no drop action. Replay needs it (§13: setup plus action list).
- *Proposed:* Add `drop(area)` as a setup action for each seat, logged in the action list before round 1. P2 drops first, then P1. Only areas 1–6 are allowed. Round 1 starts automatically after P1's drop. It can't be undone.
- *Cases that assume it:* RT-117, RT-118

**RQ-05 · Does a shot that deals 0 use the weapon's shot?** R24 says a 0-damage shot has no Brace step. R12 counts shots at declare.
- *Proposed:* Yes. Declaring the shot uses one of the weapon's shots and commits the turn (U3), even when it deals 0. The shot preview (P19) shows the 0 first, so the player isn't surprised.
- *Cases that assume it:* RT-055

**RQ-06 · Can a thrower who is eliminated by their own Frag claim the Bounty?** R34 has the Hits land, then the Bounty claim, then eliminations. R37 says an eliminated shooter doesn't claim, and R45 says elimination happens when a Hit must be taken from an empty stack, which is during the landing step. If the claim came first, its heal could put a Hit back on a stack that is about to be needed.
- *Proposed:* No. The landing step decides who is eliminated (R45). A thrower eliminated there doesn't claim, and R47 or R45 ends the match. The claim's heal never saves a player who is already out.
- *Cases that assume it:* RT-073

**RQ-07 · Which copy does an action name?** The cases name cards by code (`play SCV`). A hand or next hand can hold two identical copies. For rules purposes copies are the same, but replay and the held marks need instance ids.
- *Proposed:* The engine's actions carry card instance ids. When a case names a code, the runner resolves it to the first matching copy: hand order for play/ditch/hold, line order for shoot/attach, next-hand order for brace. A weapon is named by its code alone or by its code plus attachments (`HRF+RDS`).
- *Cases that assume it:* none (contract only)

**RQ-08 · Should the engine pair hand 4 with drop cost 3?** §16.4a says that when the dev panel switches `hand_size` to 4, `supply_drop_cost` should be 3.
- *Proposed:* The pairing belongs to the dev panel (cz13) only. The engine reads every key on its own and never changes one because of another. The hand-4 cases set both keys, as the panel would. None of their results depends on the drop cost.
- *Cases that assume it:* none (contract only)

**RQ-09 · What if `final_circle_hits` is empty?** R43 repeats the last value when the list is shorter than 3, but an empty list has no last value.
- *Proposed:* BalanceConfig rejects an empty list, or any negative value, at load (cz05, fail loudly). No case is needed in the rules engine.
- *Cases that assume it:* none (contract only)

**RQ-10 · Field names of `view(state, seat)`** §16.2 says what each seat sees but doesn't name the fields. The fairness test (P18) compares whole views, so every field has to be either always public or always derived from public data.
- *Proposed:* Proposed names, used by the view cases: `opponent.{area, health, line, fired, held_count, held_cards (only if held_cards_public), next_draw_hits and hand_hits (only if hits_on_top_public), loadout_count (only if loadout_count_public), down, hand_count, eliminated}`, plus `me` (the seat's own full state), the public table state, and during a Brace either `shot_preview {damage, may_brace}` (the shooter) or `brace_prompt {damage, next_hand}` (the defender). A hidden field is left out entirely, never sent as null. cz07 may rename the fields; the runner then maps them.
- *Cases that assume it:* RT-101, RT-102, RT-103, RT-104, RT-105, RT-106, RT-107, RT-108

**RQ-11 · Fixtures and test hooks** Most cases start mid-turn from a state that is legal but wasn't reached by playing (for example a hand with a looted Plate Vest in round 5). Some setups also break the totals: health plus Hits in loadout, hand and line always comes to `health`, but a few fixtures shrink a loadout to isolate a rule (short loadouts, an empty loadout for Pull).
- *Proposed:* cz07 provides `MatchState.from_fixture(setup)`, which accepts the setup block as written (pools, fired counts, held marks, looted-this-turn, drops and drop rounds, crates), plus three test hooks: `auto_draw` (the active seat's start-of-turn draw), `check` (no action, compare only), and `view(seat)`. `end_turn` runs everything automatic up to the next decision: gas check, Pack, the next draw, and the round start (Bounty, Zone flip, final circle).
- *Cases that assume it:* none (contract only)


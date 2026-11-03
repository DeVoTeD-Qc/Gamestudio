# Banner Wall: Rules Test Cases (test-first)

*QA Agent · 2026-11-03 · Board task **cc04** · Phase: Prototype · Status: **reviewed (Mid Game Designer gate, see Review log)**; open rules questions listed in RQ-01 to RQ-20*

*Source of rules: `../design/mechanics/banner-wall-spec.md` (approved 2026-11-03) and `../DESIGN_REVIEW.md` Decisions. Consumer: cc05 `wall_rules.gd` and its headless tests (`tests/test_wall_*.gd`, `test_scoring.gd`, `test_lineup_rules.gd`). Machine-readable twin: `rules-test-cases.json` (same IDs, same expectations).*

**103 cases.** Every placement case gives the board before the move, the move, and the exact flips, bonuses, springs, "Carded!" events and (where relevant) the final score. Cases marked *depends on RQ-xx* assume the proposed answer to an open rules question; if the designer rules differently, only those cases change.

## How to read a case

- **Wall drawing.** `1:GRV` = card GRV held by P1. `2:???` = a P2 face-down Ambush. `*b2*` marks the slot being played. The table under it lists every card with its printed values.
- **Lineup vs Held by.** *Lineup* is whose lineup the card came from (fixed); *Held by* is who controls it now. If they differ, the card was captured earlier. Reclaim and "Carded!" depend on *Lineup*.
- **Facing.** Placed **Top** vs the **Bottom** of a card above; placed **Bottom** vs the **Top** of a card below; **Side** vs **Side** left and right. Higher wins; ties do nothing except for Veteran.
- **Springs after** = Ambush springs that resolve when the turn passes to the next player (start of their turn), or all pending springs in placement order when the wall fills.
- First player is **P1** unless the case says otherwise. Balance values are spec §9 defaults unless the case overrides them.
- Boards are rule-isolation fixtures and need not be reachable in a legal game; end-of-game cases use reachable boards (RQ-18).

### Board and adjacency reference

```
        [ a1 ][ a2 ][ a3 ]          row A
     [ b1 ][ b2 ][ b3 ][ b4 ]       row B
        [ c1 ][ c2 ][ c3 ]          row C
```

| Slot | Above | Side | Below | Neighbours |
|---|---|---|---|---|
| a1 | none | a2 | b1, b2 | 3 |
| a2 | none | a1, a3 | b2, b3 | 4 |
| a3 | none | a2 | b3, b4 | 3 |
| b1 | a1 | b2 | c1 | 3 |
| b2 | a1, a2 | b1, b3 | c1, c2 | 6 |
| b3 | a2, a3 | b2, b4 | c2, c3 | 6 |
| b4 | a3 | b3 | c3 | 3 |
| c1 | b1, b2 | c2 | none | 3 |
| c2 | b2, b3 | c1, c3 | none | 4 |
| c3 | b3, b4 | c2 | none | 3 |

19 edges in total. Rows A and C never touch. b1 and b4 have exactly one card above and one below.

### Card reference (spec §6)

| Code | Card | Set | Origin | Clr | T/S/B | Trait |
|---|---|---|---|---|---|---|
| GRV | Graveyard Shift | Night Shift | Challenge | 1 | 5/4/4 | Steady |
| NEO | Neon Rain | Night Shift | Mastery | 2 | 4/6/5 | Veteran |
| LTR | Last Train | Night Shift | Event | 2 | 6/4/5 | Ambush |
| CNS | City Never Sleeps | Night Shift | Prestige | 4 | 7/5/7 | Reclaim |
| FRB | Frostbite | Whiteout | Challenge | 1 | 3/6/4 | Steady |
| SNB | Snow Blind | Whiteout | Event | 3 | 6/5/6 | Ambush |
| PNT | Polar Night | Whiteout | Ranked | 3 | 5/7/5 | Clutch |
| GLA | Glacier | Whiteout | Mastery | 2 | 7/2/6 | Veteran |
| MAY | Mayday | Signal Fire | Challenge | 2 | 5/5/5 | Steady |
| FLR | Flare Up | Signal Fire | Event | 1 | 6/3/4 | Ambush |
| DAI | Dead Air | Signal Fire | Mastery | 3 | 4/8/5 | Veteran |
| OCH | Open Channel | Signal Fire | Ranked | 2 | 4/5/6 | Clutch |
| BRT | Brass Tacks | Old Guard | Challenge | 3 | 6/6/5 | Steady |
| SRB | Service Ribbon | Old Guard | Mastery | 1 | 4/5/4 | Veteran |
| LWT | Long Watch | Old Guard | Ranked | 4 | 6/7/6 | Clutch |
| HRL | Honor Roll | Old Guard | Prestige | 3 | 5/6/6 | Reclaim |
| NGL | Null Glyph | Cipher | Secret | 2 | 5/5/5 | Cipher |
| KEY | Key Fragment | Cipher | Secret | 3 | 6/5/6 | Cipher |
| CTG | Chrome Tiger | Showcase | Store | 1 | 5/4/4 | no trait |
| GLF | Gold Leaf | Showcase | Store | 1 | 4/5/4 | no trait |

Triptychs: **Midnight Run** = GRV + NEO + LTR · **Cold Signal** = FRB + MAY + DAI · **Open Book** = NGL + KEY + HRL.

## Coverage map

| Area | Cases |
|---|---|
| Board and adjacency (spec 4.1) | BW-001 to BW-009 (9) |
| Captures and ties (spec 4.3) | BW-010 to BW-017 (8) |
| Steady (Challenge) | BW-018 to BW-021 (4) |
| Veteran (Mastery) | BW-022 to BW-023 (2) |
| Ambush (Event) | BW-024 to BW-033 (10) |
| Reclaim (Prestige) | BW-034 to BW-036 (3) |
| Clutch (Ranked) | BW-037 to BW-045 (9) |
| Cipher (Secret) | BW-046 to BW-057 (12) |
| Set Link | BW-058 to BW-064 (7) |
| Signature and "Carded!" | BW-065 to BW-067 (3) |
| Scoring, Triptychs and the tie flag (spec 4.5) | BW-068 to BW-082 (15) |
| Lineup validation (spec 4.2, Decisions 3 and 7) | BW-083 to BW-097 (15) |
| Turn flow and engine contract | BW-098 to BW-100 (3) |
| Worked example and full duel | BW-101 to BW-103 (3) |

| Spec edge case | Cases |
|---|---|
| §10 Ambush on the last placement | BW-029 |
| §10 Ambush next to Ambush (placement order; face-down safe from springs) | BW-031, BW-032 |
| §10 Cipher copying Ambush | BW-050, BW-051, BW-056 |
| §10 Cipher copying Cipher / no neighbours | BW-052, BW-053, BW-054 |
| §10 Steady vs Reclaim | BW-036 |
| §10 Clutch behind-check with Signatures double | BW-040, BW-041 |
| §10 Lineup can't reach 5 (loaner) | BW-095 |
| §10 Both Signatures captured by one player | BW-072 |
| §4.6 worked example | BW-101, BW-102 |

## Cases

### Board and adjacency (spec 4.1)

#### BW-001 · Full adjacency table of the 3-4-3 brick wall
*Spec §4.1, §11*

*Expect:* Every slot's neighbours and the facing direction from that slot. Row A sits on row B, row C hangs under row B; rows A and C never touch.

#### BW-002 · Neighbour counts, symmetry and edges
*Spec §4.1, §11*

*Expect:* b2 and b3 have 6 neighbours; a2 and c2 have 4; a1, a3, c1, c3, b1, b4 have 3. Adjacency is symmetric, 19 edges in total, no wrap-around, and no row-A slot touches a row-C slot.

#### BW-003 · b1 touches exactly one card above (a1) and one below (c1)
*Spec §4.1, §4.3, §11*

```
     [ 2:GLF ][ 2:CTG ][   a3  ]
[  *b1* ][ 2:SRB ][   b3  ][   b4  ]
     [ 2:GLA ][ 2:FRB ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a2 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b2 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 |  |
| c1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |
| c2 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P2 |  |

**To move:** P1

1. **P1 places Mayday (5/5/5, C2, Steady) into b1**
   - Expect: captures: **a1**.
   - Held after: a1 P1, a2 P2, b1 P1, b2 P2, c1 P2, c2 P2 · score P1 2 - P2 4

*Why:* Mayday T5 S5 B5. a1 Gold Leaf: Top 5 vs Bottom 4, captured. c1 Glacier: Bottom 5 vs Top 7, no. b2 Service Ribbon: Side 5 vs 5, tie, no. a2 and c2 are not adjacent to b1 and are never compared.

#### BW-004 · b4 touches exactly one card above (a3) and one below (c3)
*Spec §4.1, §11*

```
     [   a1  ][ 2:GLF ][ 2:SRB ]
[   b1  ][   b2  ][ 2:CTG ][  *b4* ]
     [   c1  ][ 2:FRB ][ 2:GLA ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a2 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a3 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 |  |
| b3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c2 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P2 |  |
| c3 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |

**To move:** P1

1. **P1 places Brass Tacks (6/6/5, C3, Steady) into b4**
   - Expect: captures: **a3, b3**.
   - Held after: a2 P2, a3 P1, b3 P1, b4 P1, c2 P2, c3 P2 · score P1 3 - P2 3

*Why:* Brass Tacks T6 S6 B5. a3 Service Ribbon B4 < 6, captured; b3 Chrome Tiger S4 < 6, captured; c3 Glacier T7 > 5, no. a2/c2 not adjacent.

#### BW-005 · Corner a1: one side neighbour and two below
*Spec §4.1*

```
     [  *a1* ][ 2:GLF ][   a3  ]
[ 2:SRB ][ 2:FLR ][ 2:FRB ][   b4  ]
     [ 2:CTG ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a2 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b1 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 |  |
| b2 | Flare Up (FLR) | 6/3/4 | 1 | Ambush | Signal Fire | P2 | P2 |  |
| b3 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P2 |  |
| c1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |

**To move:** P1

1. **P1 places Brass Tacks (6/6/5, C3, Steady) into a1**
   - Expect: captures: **a2, b1**.
   - Held after: a1 P1, a2 P1, b1 P1, b2 P2, b3 P2, c1 P2 · score P1 3 - P2 3

*Why:* a1 compares Side vs a2, and Bottom vs the Top of b1 and b2. a2 S5 < 6 and b1 T4 < 5 are captured; b2 Flare Up (face-up) T6 > 5 holds. c1 and b3 are not neighbours of a1.

#### BW-006 · Row C attacks upward with its Top value
*Spec §4.1, §4.3*

```
     [   a1  ][   a2  ][   a3  ]
[ 2:SRB ][ 2:GLF ][ 2:CTG ][   b4  ]
     [ 2:GLA ][  *c2* ][ 2:BRT ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| b1 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 |  |
| b2 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |
| c3 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P2 | P2 |  |

**To move:** P1

1. **P1 places Mayday (5/5/5, C2, Steady) into c2**
   - Expect: captures: **b2, b3, c1**.
   - Held after: b1 P2, b2 P1, b3 P1, c1 P1, c2 P1, c3 P2 · score P1 4 - P2 2

*Why:* c2's above-neighbours are b2 and b3: placed Top 5 vs their Bottom 4, both captured. Sides: c1 Glacier S2 captured, c3 Brass Tacks S6 holds. b1 is not adjacent to c2.

#### BW-007 · Defender's facing value is the side pointing back at the placed card
*Spec §4.3*

```
     [   a1  ][ 2:CTG ][   a3  ]
[   b1  ][   b2  ][  *b3* ][ 2:FRB ]
     [   c1  ][   c2  ][ 2:FLR ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a2 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b4 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P2 |  |
| c3 | Flare Up (FLR) | 6/3/4 | 1 | Ambush | Signal Fire | P2 | P2 |  |

**To move:** P1

1. **P1 places Mayday (5/5/5, C2, Steady) into b3**
   - Expect: captures: **a2**.
   - Held after: a2 P1, b3 P1, b4 P2, c3 P2 · score P1 2 - P2 2

*Why:* vs a2 (above): Top 5 vs Chrome Tiger's Bottom 4, captured (using its Top 5 would wrongly tie). vs c3 (below): Bottom 5 vs Flare Up's Top 6, no (using its Bottom 4 would wrongly capture). vs b4: Side 5 vs 6, no.

#### BW-008 · No wrap-around: a3 does not touch a1, b1 or c3
*Spec §4.1*

```
     [ 2:FRB ][ 2:GLF ][  *a3* ]
[   b1  ][   b2  ][ 2:SRB ][ 2:CTG ]
     [   c1  ][   c2  ][ 2:GLA ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P2 |  |
| a2 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b3 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 |  |
| b4 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c3 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |

**To move:** P1

1. **P1 places Brass Tacks (6/6/5, C3, Steady) into a3**
   - Expect: captures: **a2, b3**.
   - Held after: a1 P2, a2 P1, a3 P1, b3 P1, b4 P2, c3 P2 · score P1 3 - P2 3

*Why:* a3 neighbours are a2, b3, b4 only. a2 S5 < 6 captured; b3 Top 4 < Bottom 5 captured; b4 Top 5 = Bottom 5, tie, no.

#### BW-009 · Corner c3: all three neighbours captured
*Spec §4.1*

```
     [   a1  ][   a2  ][ 2:OCH ]
[   b1  ][   b2  ][ 2:GLF ][ 2:SRB ]
     [ 2:FRB ][ 2:CTG ][  *c3* ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a3 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| b3 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b4 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 |  |
| c1 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P2 |  |
| c2 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |

**To move:** P1

1. **P1 places Mayday (5/5/5, C2, Steady) into c3**
   - Expect: captures: **b3, b4, c2**.
   - Held after: a3 P2, b3 P1, b4 P1, c1 P2, c2 P1, c3 P1 · score P1 4 - P2 2

*Why:* c3 touches c2 (side) and b3, b4 (above). Top 5 vs Bottom 4 twice and Side 5 vs 4: all captured. c1 and a3 are untouched.

### Captures and ties (spec 4.3)

#### BW-010 · Ties do nothing in every direction
*Spec §4.3*

```
     [ 2:NEO ][   a2  ][   a3  ]
[ 2:GLF ][  *b2* ][ 2:CTG ][   b4  ]
     [ 2:GRV ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P2 | P2 |  |
| b1 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P2 | P2 |  |

**To move:** P1

1. **P1 places Mayday (5/5/5, C2, Steady) into b2**
   - Expect: captures: **b3**.
   - Held after: a1 P2, b1 P2, b2 P1, b3 P1, c1 P2 · score P1 2 - P2 3

*Why:* Top 5 vs Neon Rain B5, Side 5 vs Gold Leaf S5, Bottom 5 vs Graveyard Shift T5: all ties, no capture. Only b3 (S4) is captured.

#### BW-011 · A placed card is never captured by its neighbours
*Spec §4.3*

```
     [ 2:GLA ][ 2:BRT ][   a3  ]
[ 2:DAI ][  *b2* ][ 2:PNT ][   b4  ]
     [ 2:SNB ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |
| a2 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P2 | P2 |  |
| b1 | Dead Air (DAI) | 4/8/5 | 3 | Veteran | Signal Fire | P2 | P2 |  |
| b3 | Polar Night (PNT) | 5/7/5 | 3 | Clutch | Whiteout | P2 | P2 |  |
| c1 | Snow Blind (SNB) | 6/5/6 | 3 | Ambush | Whiteout | P2 | P2 |  |

**To move:** P1

1. **P1 places Gold Leaf (4/5/4, C1, no trait) into b2**
   - Expect: captures: **none**.
   - Held after: a1 P2, a2 P2, b1 P2, b2 P1, b3 P2, c1 P2 · score P1 1 - P2 5

*Why:* Only the placed card attacks. Gold Leaf T4 S5 B4 loses every comparison; nothing flips, and b2 stays with P1.

#### BW-012 · Own neighbours are never compared (no friendly fire)
*Spec §4.3*

```
     [ 1:CTG ][   a2  ][   a3  ]
[ 1:GLF ][  *b2* ][ 2:FRB ][   b4  ]
     [ 1:GRV ][ 2:OCH ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P1 | P1 |  |
| b1 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P1 | P1 |  |
| b3 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P2 |  |
| c1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| c2 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |

**To move:** P1

1. **P1 places Brass Tacks (6/6/5, C3, Steady) into b2**
   - Expect: Set Link **no**; captures: **c2**.
   - Held after: a1 P1, b1 P1, b2 P1, b3 P2, c1 P1, c2 P1 · score P1 5 - P2 1

*Why:* a1, b1, c1 are P1's and stay P1's. b3 Frostbite S6 vs 6, tie. c2 Open Channel T4 < Bottom 5, captured. No Old Guard neighbour, so no Set Link.

#### BW-013 · Multi-capture sweep from b2
*Spec §4.3*

```
     [ 2:GLF ][ 2:SRB ][   a3  ]
[ 2:CTG ][  *b2* ][ 2:FRB ][   b4  ]
     [   c1  ][ 2:OCH ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a2 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 |  |
| b1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b3 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P2 |  |
| c2 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |

**To move:** P1

1. **P1 places Brass Tacks (6/6/5, C3, Steady) into b2**
   - Expect: captures: **a1, a2, b1, c2**.
   - Held after: a1 P1, a2 P1, b1 P1, b2 P1, b3 P2, c2 P1 · score P1 5 - P2 1

*Why:* Top 6 vs B4, B4; Side 6 vs S4 (b1) and S6 (b3, tie); Bottom 5 vs T4 (c2). Four captures in one placement.

#### BW-014 · Chain captures OFF (default): captured cards do not re-check
*Spec §4.3, §9*

```
     [   a1  ][   a2  ][   a3  ]
[   b1  ][  *b2* ][ 2:CTG ][ 2:GLA ]
     [   c1  ][   c2  ][ 2:FRB ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| b3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b4 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |
| c3 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P2 |  |

**To move:** P1

1. **P1 places Brass Tacks (6/6/5, C3, Steady) into b2**
   - Expect: captures: **b3**.
   - Held after: b2 P1, b3 P1, b4 P2, c3 P2 · score P1 2 - P2 2

*Why:* Brass Tacks captures b3 Chrome Tiger (S4 < 6). Chrome Tiger would beat b4 Glacier (S4 > S2) and c3 Frostbite (B4 > T3), but with the flag off nothing cascades.

#### BW-015 · Chain captures ON (tuning flag): captured cards re-check their neighbours
*Spec §9 · **depends on RQ-13** · balance: `chain_captures=True`*

```
     [   a1  ][   a2  ][   a3  ]
[   b1  ][  *b2* ][ 2:CTG ][ 2:GLA ]
     [   c1  ][   c2  ][ 2:FRB ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| b3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b4 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |
| c3 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P2 |  |

**To move:** P1

1. **P1 places Brass Tacks (6/6/5, C3, Steady) into b2**
   - Expect: captures: **b3, b4, c3**.
   - Held after: b2 P1, b3 P1, b4 P1, c3 P1 · score P1 4 - P2 0

*Why:* Proposed chain semantics: b3 Chrome Tiger, now P1's, attacks with printed values: Side 4 > Glacier S2 (b4) and Bottom 4 > Frostbite T3 (c3, Steady C1 is not higher than Chrome Tiger's C1). The cascade stops when no new card flips.

#### BW-016 · Captured cards can be recaptured by values
*Spec §4.3*

```
     [   a1  ][   a2  ][   a3  ]
[   b1  ][   b2  ][ 1:CTG ][  *b4* ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| b3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P1 | captured |

**To move:** P2

1. **P2 places Mayday (5/5/5, C2, Steady) into b4**
   - Expect: captures: **b3**.
   - Held after: b3 P2, b4 P2 · score P1 0 - P2 2

*Why:* Control is not permanent. P2's Mayday S5 beats Chrome Tiger S4 (currently P1's), so it flips back to P2.

#### BW-017 · A captured card keeps its trait for its new controller
*Spec §4.3, §4.4*

```
     [   a1  ][   a2  ][   a3  ]
[   b1  ][ 1:BRT ][  *b3* ][   b4  ]
     [   c1  ][   c2  ][ 1:GLF ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| b2 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P2 | P1 | captured |
| c3 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P1 | P1 |  |

**To move:** P2

1. **P2 places Neon Rain (4/6/5, C2, Veteran) into b3**
   - Expect: captures: **c3**.
   - Held after: b2 P1, b3 P2, c3 P2 · score P1 1 - P2 2

*Why:* Brass Tacks (Steady, C3) now belongs to P1 and still can't be captured by Neon Rain (C2), even though S6 vs S6 is a tie Veteran would win. c3 Gold Leaf T4 < Bottom 5 is captured.

### Steady (Challenge)

#### BW-018 · Steady blocks a lower-Clearance attacker that wins on values
*Spec §4.4*

```
     [   a1  ][   a2  ][   a3  ]
[ 2:GLF ][ 2:BRT ][   b3  ][   b4  ]
     [  *c1* ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| b1 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b2 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P2 | P2 |  |

**To move:** P1

1. **P1 places Glacier (7/2/6, C2, Veteran) into c1**
   - Expect: captures: **b1**.
   - Held after: b1 P1, b2 P2, c1 P1 · score P1 2 - P2 1

*Why:* Glacier (C2) Top 7 beats Brass Tacks Bottom 5, but Brass Tacks is Steady with C3 > 2: no capture. b1 Gold Leaf B4 < 7 is captured.

#### BW-019 · Steady does not block an equal-Clearance attacker
*Spec §4.4*

```
     [  *a1* ][   a2  ][   a3  ]
[   b1  ][ 2:FRB ][   b3  ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| b2 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P2 |  |

**To move:** P1

1. **P1 places Gold Leaf (4/5/4, C1, no trait) into a1**
   - Expect: captures: **b2**.
   - Held after: a1 P1, b2 P1 · score P1 2 - P2 0

*Why:* Gold Leaf (C1) Bottom 4 vs Frostbite Top 3. Frostbite is Steady C1; the attacker's C1 is not lower, so it is captured.

#### BW-020 · Steady does not block a higher-Clearance attacker
*Spec §4.4*

```
     [   a1  ][   a2  ][   a3  ]
[   b1  ][ 2:MAY ][  *b3* ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| b2 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P2 | P2 |  |

**To move:** P1

1. **P1 places Brass Tacks (6/6/5, C3, Steady) into b3**
   - Expect: captures: **b2**.
   - Held after: b2 P1, b3 P1 · score P1 2 - P2 0

*Why:* Brass Tacks (C3) Side 6 vs Mayday (Steady, C2) Side 5: captured.

#### BW-021 · Placement bonuses never raise Clearance
*Spec §4.4*

```
     [ 2:GLF ][   a2  ][ 2:CTG ]
[   b1  ][  *b2* ][ 2:BRT ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b3 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P2 | P2 |  |

**To move:** P1

1. **P1 places Open Channel (4/5/6, C2, Clutch) into b2**
   - Expect: Clutch **yes**; fights as **6/7/8**; captures: **a1**.
   - Held after: a1 P1, a3 P2, b2 P1, b3 P2 · score P1 2 - P2 2

*Why:* P1 is behind 0-3, so Open Channel's Clutch gives 6/7/8. Side 7 beats Brass Tacks S6, but Open Channel is still C2 < C3: Steady holds. a1 Gold Leaf B4 < 6 is captured.

### Veteran (Mastery)

#### BW-022 · Veteran captures on ties
*Spec §4.4*

```
     [ 2:CTG ][   a2  ][   a3  ]
[   b1  ][  *b2* ][ 2:GLF ][   b4  ]
     [ 2:GRV ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b3 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P2 | P2 |  |

**To move:** P1

1. **P1 places Service Ribbon (4/5/4, C1, Veteran) into b2**
   - Expect: captures: **a1, b3**.
   - Held after: a1 P1, b2 P1, b3 P1, c1 P2 · score P1 3 - P2 1

*Why:* Service Ribbon T4 S5 B4. b3 S5 = 5 and a1 B4 = T4 are ties: captured (Veteran). c1 Graveyard Shift T5 > Bottom 4: no.

#### BW-023 · Veteran tie vs an equal-Clearance Steady card captures
*Spec §4.4*

```
     [ 2:GLA ][   a2  ][   a3  ]
[   b1  ][  *b2* ][   b3  ][   b4  ]
     [ 2:MAY ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |
| c1 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P2 | P2 |  |

**To move:** P1

1. **P1 places Neon Rain (4/6/5, C2, Veteran) into b2**
   - Expect: captures: **c1**.
   - Held after: a1 P2, b2 P1, c1 P1 · score P1 2 - P2 1

*Why:* Neon Rain (C2) Bottom 5 vs Mayday Top 5: tie, Veteran wins, and Mayday's Steady (C2) does not protect against C2. a1 Glacier B6 > Top 4: no.

### Ambush (Event)

#### BW-024 · Ambush is placed face-down and captures nothing
*Spec §4.4*

```
     [ 2:GLF ][   a2  ][   a3  ]
[   b1  ][  *b2* ][ 2:CTG ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |

**To move:** P1

1. **P1 places Snow Blind (6/5/6, C3, Ambush) into b2**
   - Expect: **face-down**; captures: **none**.
   - Held after: a1 P2, b2 P1, b3 P2 · score P1 1 - P2 2

*Why:* Snow Blind would beat both neighbours (S5 > 4, T6 > 4), but a face-down card captures nothing on placement.

#### BW-025 · A face-down card can't be captured
*Spec §4.4, §10*

```
     [   a1  ][   a2  ][   a3  ]
[   b1  ][ 1:??? ][  *b3* ][   b4  ]
     [   c1  ][ 1:GLF ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| b2 | Snow Blind (SNB) | 6/5/6 | 3 | Ambush | Whiteout | P1 | P1 | face-down (pending spring) |
| c2 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P1 | P1 |  |

**To move:** P2

1. **P2 places Dead Air (4/8/5, C3, Veteran) into b3**
   - Expect: captures: **c2**; then spring at b2 (+1) captures: **c2**.
   - Held after: b2 P1, b3 P2, c2 P1 · score P1 2 - P2 1

*Why:* Dead Air Side 8 would beat Snow Blind S5, but b2 is face-down: no comparison. c2 Gold Leaf T4 < Bottom 5 is captured. When P1's turn starts, Snow Blind springs at 7/6/7: Side 6 < Dead Air S8, Bottom 7 > Gold Leaf T4, so c2 comes back.

#### BW-026 · Spring at the start of the owner's next turn with +1 to all values
*Spec §4.4*

```
     [ 2:GLA ][   a2  ][   a3  ]
[   b1  ][  *b2* ][   b3  ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |

**To move:** P1

1. **P1 places Last Train (6/4/5, C2, Ambush) into b2**
   - Expect: **face-down**; captures: **none**.
   - Held after: a1 P2, b2 P1 · score P1 1 - P2 1
2. **P2 places Chrome Tiger (5/4/4, C1, no trait) into b3**
   - Expect: captures: **none**; then spring at b2 (+1) captures: **a1, b3**.
   - Held after: a1 P1, b2 P1, b3 P1 · score P1 3 - P2 0

*Why:* Last Train 6/4/5 springs as 7/5/6 when P1's turn starts. Top 7 > Glacier B6 and Side 5 > Chrome Tiger S4: both captured. Without the +1 both would be ties. b3 was placed after the Ambush; the spring checks the neighbours present when it springs.

#### BW-027 · Spring respects Steady, and spring ties do nothing
*Spec §4.4, §10*

```
     [ 2:MAY ][   a2  ][   a3  ]
[ 2:CTG ][ 1:??? ][   b3  ][   b4  ]
     [ 2:GLF ][   c2  ][  *c3* ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P2 | P2 |  |
| b1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b2 | Flare Up (FLR) | 6/3/4 | 1 | Ambush | Signal Fire | P1 | P1 | face-down (pending spring) |
| c1 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |

**To move:** P2

1. **P2 places Service Ribbon (4/5/4, C1, Veteran) into c3**
   - Expect: captures: **none**; then spring at b2 (+1) captures: **c1**.
   - Held after: a1 P2, b1 P2, b2 P1, c1 P1, c3 P2 · score P1 2 - P2 3

*Why:* Flare Up springs as 7/4/5 (C1). a1 Mayday: Top 7 > B5 but Steady C2 > 1, blocked. b1 Chrome Tiger: Side 4 = 4, tie, no. c1 Gold Leaf: Bottom 5 > T4, captured.

#### BW-028 · Set Link does not apply to a spring
*Spec §4.3, §4.4 · **depends on RQ-05***

```
     [   a1  ][   a2  ][   a3  ]
[ 1:GRV ][ 1:??? ][ 2:MAY ][   b4  ]
     [   c1  ][   c2  ][  *c3* ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| b1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| b2 | Last Train (LTR) | 6/4/5 | 2 | Ambush | Night Shift | P1 | P1 | face-down (pending spring) |
| b3 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P2 | P2 |  |

**To move:** P2

1. **P2 places Service Ribbon (4/5/4, C1, Veteran) into c3**
   - Expect: captures: **none**; then spring at b2 (+1) captures: **none**.
   - Held after: b1 P1, b2 P1, b3 P2, c3 P2 · score P1 2 - P2 2

*Why:* Last Train springs as 7/5/6. It touches own Graveyard Shift (Night Shift), but Set Link is a placement bonus: Side 5 vs Mayday S5 is a tie, no capture. (With Set Link it would be 6 > 5.)

#### BW-029 · Ambush on the last placement springs immediately before scoring
*Spec §10, §4.5*

```
     [ 1:GRV ][ 1:MAY ][ 2:GLF ]
[ 2:CTG ][ 1:BRT ][ 1:SRB ][ 2:OCH ]
     [ 2:GLA ][  *c2* ][ 1:NEO ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| a2 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 | Signature |
| a3 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b2 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P1 |  |
| b3 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P1 | P1 |  |
| b4 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| c1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 | Signature |
| c3 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P1 | P1 |  |

**To move:** P2

1. **P2 places Flare Up (6/3/4, C1, Ambush) into c2**
   - Expect: captures: **none**; then spring at c2 (+1) captures: **b3**.
   - Held after: a1 P1, a2 P1, a3 P2, b1 P2, b2 P1, b3 P2, b4 P2, c1 P2, c2 P2, c3 P1 · score P1 5 - P2 7
**Final:** P1 **5** - P2 **7**, winner **P2**.

*Why:* The 10th placement fills the wall, so Flare Up springs at once (7/4/5, C1): b3 Service Ribbon B4 < 7 captured; b2 Brass Tacks B5 < 7 but Steady C3 blocks; c3 Neon Rain S6 > 4. Score P1 5 (a1, a2 x2, b2, c3) vs P2 7 (a3, b1, b3, b4, c1 x2, c2).

#### BW-030 · An earlier Ambush still face-down when the wall fills flips before scoring
*Spec §4.4, §10*

```
     [ 1:GRV ][ 2:GLF ][ 2:CTG ]
[ 1:MAY ][ 2:SRB ][  *b3* ][ 1:BRT ]
     [ 2:OCH ][ 1:GLA ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| a2 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b1 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 | Signature |
| b2 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 | Signature |
| b4 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P1 |  |
| c1 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| c2 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P1 | P1 |  |

**To move:** P1

1. **P1 places Last Train (6/4/5, C2, Ambush) into b3**
   - Expect: **face-down**; captures: **none**.
   - Held after: a1 P1, a2 P2, a3 P2, b1 P1, b2 P2, b3 P1, b4 P1, c1 P2, c2 P1 · score P1 6 - P2 5
2. **P2 places Frostbite (3/6/4, C1, Steady) into c3**
   - Expect: captures: **c2**; then spring at b3 (+1) captures: **a2, a3, c3**.
   - Held after: a1 P1, a2 P1, a3 P1, b1 P1, b2 P2, b3 P1, b4 P1, c1 P2, c2 P2, c3 P1 · score P1 8 - P2 4
**Final:** P1 **8** - P2 **4**, winner **P1**.

*Why:* P2's 10th placement (Frostbite) takes c2 Glacier (S6 > S2) and can't touch face-down b3. The wall is full, so Last Train springs (7/5/6): a2 and a3 (B4 < 7) and c3 Frostbite (T3 < 6, Steady C1 < C2 doesn't block) are captured; b2 S5 = 5 tie; c2 Glacier T7 > 6 holds.

#### BW-031 · Ambush next to Ambush: the face-down one is safe from the spring
*Spec §10*

```
     [   a1  ][   a2  ][   a3  ]
[   b1  ][  *b2* ][   b3  ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

Empty wall.

**To move:** P1

1. **P1 places Last Train (6/4/5, C2, Ambush) into b2**
   - Expect: **face-down**; captures: **none**.
   - Held after: b2 P1 · score P1 1 - P2 0
2. **P2 places Flare Up (6/3/4, C1, Ambush) into b3**
   - Expect: **face-down**; captures: **none**; then spring at b2 (+1) captures: **none**.
   - Held after: b2 P1, b3 P2 · score P1 1 - P2 1
3. **P1 places Gold Leaf (4/5/4, C1, no trait) into a2**
   - Expect: captures: **none**; then spring at b3 (+1) captures: **a2**.
   - Held after: a2 P2, b2 P1, b3 P2 · score P1 1 - P2 2

*Why:* P1's Last Train springs first (7/5/6). Its Side 5 would beat Flare Up S3, but b3 is still face-down, so nothing. On P2's next turn Flare Up springs (7/4/5): a2 Gold Leaf B4 < 7 captured; b2 Last Train (now face-up) S4 = 4, tie.

#### BW-032 · Two Ambushes pending at wall fill resolve in placement order
*Spec §10*

```
     [ 1:GRV ][ 2:GLF ][ 1:BRT ]
[ 2:CTG ][  *b2* ][   b3  ][ 2:OCH ]
     [ 1:MAY ][ 2:GLA ][ 1:SRB ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| a2 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a3 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P1 |  |
| b1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b4 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| c1 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 | Signature |
| c2 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 | Signature |
| c3 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P1 | P1 |  |

**To move:** P1

1. **P1 places Last Train (6/4/5, C2, Ambush) into b2**
   - Expect: **face-down**; captures: **none**.
   - Held after: a1 P1, a2 P2, a3 P1, b1 P2, b2 P1, b4 P2, c1 P1, c2 P2, c3 P1 · score P1 6 - P2 5
2. **P2 places Snow Blind (6/5/6, C3, Ambush) into b3**
   - Expect: **face-down**; captures: **none**; then spring at b2 (+1) captures: **a2, b1**; then spring at b3 (+1) captures: **a2, a3, b2, c3**.
   - Held after: a1 P1, a2 P2, a3 P2, b1 P1, b2 P2, b3 P2, b4 P2, c1 P1, c2 P2, c3 P2 · score P1 4 - P2 8
**Final:** P1 **4** - P2 **8**, winner **P2**.

*Why:* Placement 9 (P1) springs first: Last Train 7/5/6 takes a2 (B4) and b1 (S4); b3 is face-down; c2 Glacier T7 > 6. Then Snow Blind 7/6/7 springs: takes Last Train (S4 < 6), a2 back (B4 < 7), a3 Brass Tacks (B5 < 7; Steady C3 is not higher than C3) and c3 Service Ribbon (T4 < 7).

#### BW-033 · A spring that takes the enemy Signature plays "Carded!"
*Spec §4.4, §4.5*

```
     [   a1  ][   a2  ][  *a3* ]
[   b1  ][ 1:??? ][ 2:CTG ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| b2 | Last Train (LTR) | 6/4/5 | 2 | Ambush | Night Shift | P1 | P1 | face-down (pending spring) |
| b3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 | Signature |

**To move:** P2

1. **P2 places Gold Leaf (4/5/4, C1, no trait) into a3**
   - Expect: captures: **none**; **"Carded!"** on b3; then spring at b2 (+1) captures: **b3**.
   - Held after: a3 P2, b2 P1, b3 P1 · score P1 3 - P2 1

*Why:* Last Train springs (Side 5 > Chrome Tiger S4) and takes P2's Signature: Carded! P1 scores b2 + b3 x2 = 3.

### Reclaim (Prestige)

#### BW-034 · Reclaim retakes adjacent own-lineup cards whatever the values; normal captures still apply
*Spec §4.4 · **depends on RQ-10***

```
     [ 2:BRT ][ 2:DAI ][ 2:SRB ]
[ 2:MAY ][  *b2* ][ 2:HRL ][   b4  ]
     [ 2:GLA ][ 1:FRB ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P2 | captured |
| a2 | Dead Air (DAI) | 4/8/5 | 3 | Veteran | Signal Fire | P2 | P2 |  |
| a3 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P1 | P2 | captured |
| b1 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P2 | Signature, captured |
| b3 | Honor Roll (HRL) | 5/6/6 | 3 | Reclaim | Old Guard | P2 | P2 |  |
| c1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |
| c2 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P1 | captured |

**To move:** P1

1. **P1 places City Never Sleeps (7/5/7, C4, Reclaim) into b2**
   - Expect: captures: **a2**; reclaims: **a1, b1**.
   - Held after: a1 P1, a2 P1, a3 P2, b1 P1, b2 P1, b3 P2, c1 P2, c2 P1 · score P1 6 - P2 3

*Why:* City Never Sleeps (7/5/7) takes back a1 and b1 (its own lineup's cards held by P2), including P1's own Signature (no Carded: it's P1's own). It also captures a2 Dead Air (B5 < 7). b3 Honor Roll S6 > 5; c1 Glacier T7 = 7 tie. a3 is P1's card but not adjacent: it stays with P2.

#### BW-035 · Bonuses are fixed before Reclaim: a reclaimed card doesn't give Set Link
*Spec §4.3, §4.4 · **depends on RQ-06***

```
     [ 2:GRV ][   a2  ][   a3  ]
[   b1  ][  *b2* ][   b3  ][   b4  ]
     [ 2:GLA ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P2 | captured |
| c1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |

**To move:** P1

1. **P1 places City Never Sleeps (7/5/7, C4, Reclaim) into b2**
   - Expect: Set Link **no**; captures: **none**; reclaims: **a1**.
   - Held after: a1 P1, b2 P1, c1 P2 · score P1 2 - P2 1

*Why:* Graveyard Shift (Night Shift) is enemy-held when City Never Sleeps lands, so no Set Link; Bottom 7 vs Glacier T7 is a tie. (If Reclaim resolved first, Set Link would make it 8 > 7.)

#### BW-036 · Reclaim beats Steady (via Cipher copying Reclaim)
*Spec §4.4, §10*

```
     [ 2:BRT ][ 2:HRL ][   a3  ]
[   b1  ][  *b2* ][   b3  ][   b4  ]
     [ 2:FRB ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P2 | captured |
| a2 | Honor Roll (HRL) | 5/6/6 | 3 | Reclaim | Old Guard | P2 | P2 |  |
| c1 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P2 |  |

**To move:** P1

1. **P1 places Null Glyph (5/5/5, C2, Cipher) into b2** (copies the trait of a2)
   - Expect: active trait **Reclaim**; captures: **c1**; reclaims: **a1**.
   - Held after: a1 P1, a2 P2, b2 P1, c1 P1 · score P1 3 - P2 1

*Why:* Null Glyph (C2) copies Honor Roll's Reclaim and takes back Brass Tacks (Steady, C3), even though C2 < C3. c1 Frostbite T3 < Bottom 5 is captured; a2 Honor Roll B6 > Top 5 holds.

### Clutch (Ranked)

#### BW-037 · Clutch +2 when behind
*Spec §4.4, §10*

```
     [ 1:GRV ][ 1:MAY ][   a3  ]
[   b1  ][  *b2* ][   b3  ][ 2:GLF ]
     [   c1  ][   c2  ][ 1:CTG ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| a2 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 |  |
| b4 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P1 | P1 |  |

**To move:** P2

1. **P2 places Open Channel (4/5/6, C2, Clutch) into b2**
   - Expect: Clutch **yes**; fights as **6/7/8**; captures: **a1, a2**.
   - Held after: a1 P2, a2 P2, b2 P2, b4 P2, c3 P1 · score P1 1 - P2 4

*Why:* P2 is behind 1-3. Open Channel fights as 6/7/8: Top 6 > Graveyard Shift B4 and > Mayday B5 (Steady C2 doesn't block C2). Without Clutch both would fail.

#### BW-038 · Clutch is off when the score is level
*Spec §4.4, §10*

```
     [ 1:GRV ][ 1:MAY ][   a3  ]
[   b1  ][  *b2* ][   b3  ][ 2:GLF ]
     [   c1  ][   c2  ][ 2:CTG ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| a2 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 |  |
| b4 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |

**To move:** P2

1. **P2 places Open Channel (4/5/6, C2, Clutch) into b2**
   - Expect: Clutch **no**; fights as **4/5/6**; captures: **none**.
   - Held after: a1 P1, a2 P1, b2 P2, b4 P2, c3 P2 · score P1 2 - P2 3

*Why:* 2-2 is not behind. Top 4 vs B4 is a tie and 4 < 5.

#### BW-039 · Clutch is off when ahead
*Spec §4.4*

```
     [ 1:GRV ][   a2  ][   a3  ]
[   b1  ][  *b2* ][   b3  ][ 2:GLF ]
     [   c1  ][   c2  ][ 2:CTG ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| b4 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |

**To move:** P2

1. **P2 places Open Channel (4/5/6, C2, Clutch) into b2**
   - Expect: Clutch **no**; captures: **none**.
   - Held after: a1 P1, b2 P2, b4 P2, c3 P2 · score P1 1 - P2 3

*Why:* P2 leads 2-1. Open Channel plays at printed values: Top 4 vs Graveyard Shift B4 is a tie.

#### BW-040 · Behind-check counts Signatures double (behind on points, level on cards)
*Spec §10*

```
     [ 1:GRV ][ 1:MAY ][   a3  ]
[   b1  ][  *b2* ][   b3  ][ 2:GLF ]
     [   c1  ][   c2  ][ 2:CTG ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| a2 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 | Signature |
| b4 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |

**To move:** P2

1. **P2 places Open Channel (4/5/6, C2, Clutch) into b2**
   - Expect: Clutch **yes**; captures: **a1, a2**; **"Carded!"** on a2.
   - Held after: a1 P2, a2 P2, b2 P2, b4 P2, c3 P2 · score P1 0 - P2 6

*Why:* Two cards each, but P1's Signature makes it 3-2: P2 is behind, Clutch applies, and taking Mayday (P1's Signature) plays Carded!

#### BW-041 · Behind-check counts Signatures double (fewer cards but level on points)
*Spec §10*

```
     [ 1:GRV ][ 1:MAY ][ 1:SRB ]
[   b1  ][  *b2* ][   b3  ][ 2:GLF ]
     [   c1  ][   c2  ][ 2:CTG ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| a2 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 |  |
| a3 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P1 | P1 |  |
| b4 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 | Signature |
| c3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |

**To move:** P2

1. **P2 places Open Channel (4/5/6, C2, Clutch) into b2**
   - Expect: Clutch **no**; captures: **none**.
   - Held after: a1 P1, a2 P1, a3 P1, b2 P2, b4 P2, c3 P2 · score P1 3 - P2 4

*Why:* P2 has 2 cards vs 3, but its Signature makes it 3-3: not behind, no Clutch.

#### BW-042 · Clutch and Set Link stack (+3)
*Spec §4.3, §4.4*

```
     [ 1:CNS ][ 1:GRV ][   a3  ]
[   b1  ][  *b2* ][ 1:BRT ][   b4  ]
     [   c1  ][ 2:GLA ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | City Never Sleeps (CNS) | 7/5/7 | 4 | Reclaim | Night Shift | P1 | P1 |  |
| a2 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| b3 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P1 |  |
| c2 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |

**To move:** P2

1. **P2 places Polar Night (5/7/5, C3, Clutch) into b2**
   - Expect: Set Link **yes**; Clutch **yes**; fights as **8/10/8**; captures: **a1, a2, b3**.
   - Held after: a1 P2, a2 P2, b2 P2, b3 P2, c2 P2 · score P1 0 - P2 5

*Why:* Polar Night (Whiteout) touches own Glacier (Whiteout) and P2 is behind 1-3: 5/7/5 becomes 8/10/8. Top 8 > City Never Sleeps B7 needs both bonuses (+2 alone gives a tie).

#### BW-043 · Clutch applies to the placement only; later it defends with printed values
*Spec §4.3*

```
     [ 1:GRV ][ 1:MAY ][   a3  ]
[   b1  ][  *b2* ][   b3  ][ 2:GLF ]
     [   c1  ][   c2  ][ 1:CTG ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| a2 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 |  |
| b4 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P1 | P1 |  |

**To move:** P2

1. **P2 places Open Channel (4/5/6, C2, Clutch) into b2**
   - Expect: Clutch **yes**; captures: **a1, a2**.
   - Held after: a1 P2, a2 P2, b2 P2, b4 P2, c3 P1 · score P1 1 - P2 4
2. **P1 places Service Ribbon (4/5/4, C1, Veteran) into b3**
   - Expect: captures: **b2, b4**.
   - Held after: a1 P2, a2 P2, b2 P1, b3 P1, b4 P1, c3 P1 · score P1 4 - P2 2

*Why:* Next turn Service Ribbon's Side 5 ties Open Channel's printed S5 (not 7) and Gold Leaf S5: both captured by Veteran. a2 Mayday (now P2's) B5 > Top 4 holds.

#### BW-044 · Behind-check is taken after own start-of-turn springs
*Spec §4.4, §10 · **depends on RQ-09***

```
     [   a1  ][   a2  ][  *a3* ]
[   b1  ][ 1:??? ][ 2:CTG ][   b4  ]
     [   c1  ][   c2  ][ 2:GLA ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| b2 | Last Train (LTR) | 6/4/5 | 2 | Ambush | Night Shift | P1 | P1 | face-down (pending spring) |
| b3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c3 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |

**To move:** P2

1. **P2 places Gold Leaf (4/5/4, C1, no trait) into a3**
   - Expect: captures: **none**; then spring at b2 (+1) captures: **b3**.
   - Held after: a3 P2, b2 P1, b3 P1, c3 P2 · score P1 2 - P2 2
2. **P1 places Open Channel (4/5/6, C2, Clutch) into b4**
   - Expect: Clutch **no**; captures: **none**.
   - Held after: a3 P2, b2 P1, b3 P1, b4 P1, c3 P2 · score P1 3 - P2 2

*Why:* P1 trails 1-3 until Last Train springs and takes b3, making it 2-2. Open Channel then gets no Clutch: Top 4 vs Gold Leaf B4 tie, Bottom 6 vs Glacier T7. (With the pre-spring score it would have taken both.)

#### BW-045 · Face-down cards count in the behind-check
*Spec §10 · **depends on RQ-09***

```
     [ 1:GRV ][   a2  ][   a3  ]
[   b1  ][  *b2* ][   b3  ][ 2:GLF ]
     [   c1  ][   c2  ][ 1:??? ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| b4 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c3 | Flare Up (FLR) | 6/3/4 | 1 | Ambush | Signal Fire | P1 | P1 | face-down (pending spring) |

**To move:** P2

1. **P2 places Open Channel (4/5/6, C2, Clutch) into b2**
   - Expect: Clutch **yes**; captures: **a1**; then spring at c3 (+1) captures: **b4**.
   - Held after: a1 P2, b2 P2, b4 P1, c3 P1 · score P1 2 - P2 2

*Why:* P1's face-down Flare Up counts, so P2 is behind 1-2: Top 6 > Graveyard Shift B4. Then P1's turn starts and Flare Up springs (Top 7 > Gold Leaf B4).

### Cipher (Secret)

#### BW-046 · Cipher copies Veteran (player's pick) and captures on ties
*Spec §4.4*

```
     [ 2:NEO ][   a2  ][   a3  ]
[ 2:OCH ][  *b2* ][ 2:GLF ][   b4  ]
     [ 2:MAY ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P2 | P2 |  |
| b1 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| b3 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c1 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P2 | P2 |  |

**To move:** P1

1. **P1 places Null Glyph (5/5/5, C2, Cipher) into b2** (copies the trait of a1)
   - Expect: active trait **Veteran**; captures: **a1, b1, b3, c1**.
   - Held after: a1 P1, b1 P1, b2 P1, b3 P1, c1 P1 · score P1 5 - P2 0

*Why:* Null Glyph 5/5/5 ties all four neighbours (B5, S5, S5, T5). As a Veteran it takes all of them; Mayday's Steady (C2) doesn't block C2.

#### BW-047 · The pick matters: copying Steady instead captures nothing
*Spec §4.4*

```
     [ 2:NEO ][   a2  ][   a3  ]
[ 2:OCH ][  *b2* ][ 2:GLF ][   b4  ]
     [ 2:MAY ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P2 | P2 |  |
| b1 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| b3 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c1 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P2 | P2 |  |

**To move:** P1

1. **P1 places Null Glyph (5/5/5, C2, Cipher) into b2** (copies the trait of c1)
   - Expect: active trait **Steady**; captures: **none**.
   - Held after: a1 P2, b1 P2, b2 P1, b3 P2, c1 P2 · score P1 1 - P2 4

*Why:* Same board as the previous case; Null Glyph copies Mayday's Steady. All four comparisons are ties.

#### BW-048 · A copied Steady keeps protecting the Cipher card
*Spec §4.4 · **depends on RQ-01***

```
     [   a1  ][   a2  ][   a3  ]
[   b1  ][ 1:NGL ][  *b3* ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| b2 | Null Glyph (NGL) | 5/5/5 | 2 | Cipher | Cipher | P1 | P1 | holds copied trait: Steady |

**To move:** P2

1. **P2 places Frostbite (3/6/4, C1, Steady) into b3**
   - Expect: captures: **none**.
   - Held after: b2 P1, b3 P2 · score P1 1 - P2 1

*Why:* Frostbite (C1) Side 6 beats Null Glyph S5, but Null Glyph copied Steady earlier and is C2: blocked.

#### BW-049 · Cipher copies Clutch while behind
*Spec §4.4*

```
     [   a1  ][ 2:GLA ][   a3  ]
[   b1  ][ 2:PNT ][  *b3* ][ 2:OCH ]
     [   c1  ][   c2  ][ 2:HRL ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a2 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |
| b2 | Polar Night (PNT) | 5/7/5 | 3 | Clutch | Whiteout | P2 | P2 |  |
| b4 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| c3 | Honor Roll (HRL) | 5/6/6 | 3 | Reclaim | Old Guard | P2 | P2 |  |

**To move:** P1

1. **P1 places Key Fragment (6/5/6, C3, Cipher) into b3** (copies the trait of b4)
   - Expect: active trait **Clutch**; Clutch **yes**; fights as **8/7/8**; captures: **a2, b4, c3**.
   - Held after: a2 P1, b2 P2, b3 P1, b4 P1, c3 P1 · score P1 4 - P2 1

*Why:* P1 is behind 0-4. Key Fragment 6/5/6 copies Open Channel's Clutch: 8/7/8. Glacier B6, Open Channel S5 and Honor Roll T5 fall; Polar Night S7 = 7 is a tie.

#### BW-050 · Cipher copying Ambush: stays face-up, captures nothing, springs next turn with +1
*Spec §10*

```
     [ 2:SNB ][   a2  ][   a3  ]
[   b1  ][  *b2* ][ 2:CTG ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Snow Blind (SNB) | 6/5/6 | 3 | Ambush | Whiteout | P2 | P2 |  |
| b3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |

**To move:** P1

1. **P1 places Null Glyph (5/5/5, C2, Cipher) into b2** (copies the trait of a1)
   - Expect: active trait **Ambush**; captures: **none**.
   - Held after: a1 P2, b2 P1, b3 P2 · score P1 1 - P2 2
2. **P2 places Service Ribbon (4/5/4, C1, Veteran) into c3**
   - Expect: captures: **none**; then spring at b2 (+1) captures: **b3**.
   - Held after: a1 P2, b2 P1, b3 P1, c3 P2 · score P1 2 - P2 2

*Why:* Null Glyph would take Chrome Tiger (S5 > 4) but captures nothing on placement. On P1's next turn it springs as 6/6/6: Chrome Tiger S4 captured; Snow Blind B6 = Top 6, tie.

#### BW-051 · A Cipher holding a copied Ambush can be captured before it springs
*Spec §10 · **depends on RQ-04***

```
     [ 2:SNB ][   a2  ][   a3  ]
[   b1  ][  *b2* ][ 2:CTG ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Snow Blind (SNB) | 6/5/6 | 3 | Ambush | Whiteout | P2 | P2 |  |
| b3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |

**To move:** P1

1. **P1 places Null Glyph (5/5/5, C2, Cipher) into b2** (copies the trait of a1)
   - Expect: active trait **Ambush**; captures: **none**.
   - Held after: a1 P2, b2 P1, b3 P2 · score P1 1 - P2 2
2. **P2 places Glacier (7/2/6, C2, Veteran) into c1**
   - Expect: captures: **b2**; no spring fires.
   - Held after: a1 P2, b2 P2, b3 P2, c1 P2 · score P1 0 - P2 4

*Why:* Null Glyph is face-up, so Glacier (Top 7 vs B5) captures it. Proposed: its pending spring is cancelled because P1 no longer controls it.

#### BW-052 · Cipher copying a Cipher card gets no trait
*Spec §10*

```
     [ 2:SRB ][   a2  ][   a3  ]
[   b1  ][  *b2* ][ 2:NGL ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 |  |
| b3 | Null Glyph (NGL) | 5/5/5 | 2 | Cipher | Cipher | P2 | P2 | holds copied trait: no trait |

**To move:** P1

1. **P1 places Key Fragment (6/5/6, C3, Cipher) into b2** (copies the trait of b3)
   - Expect: active trait **no trait**; captures: **a1**.
   - Held after: a1 P1, b2 P1, b3 P2 · score P1 2 - P2 1

*Why:* Key Fragment copies Null Glyph's trait, Cipher, which gives no trait. Side 5 vs 5 is a plain tie; a1 Service Ribbon B4 < Top 6 is captured.

#### BW-053 · Copying a Cipher that copied something still gives no trait
*Spec §10 · **depends on RQ-02***

```
     [ 2:SRB ][   a2  ][   a3  ]
[   b1  ][  *b2* ][ 2:NGL ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 |  |
| b3 | Null Glyph (NGL) | 5/5/5 | 2 | Cipher | Cipher | P2 | P2 | holds copied trait: Veteran |

**To move:** P1

1. **P1 places Key Fragment (6/5/6, C3, Cipher) into b2** (copies the trait of b3)
   - Expect: active trait **no trait**; captures: **a1**.
   - Held after: a1 P1, b2 P1, b3 P2 · score P1 2 - P2 1

*Why:* Null Glyph currently holds Veteran, but its printed trait is Cipher, so Key Fragment gets nothing and Side 5 vs 5 doesn't capture.

#### BW-054 · Cipher with no neighbours gets no trait, and later neighbours don't add one
*Spec §10*

```
     [   a1  ][   a2  ][ 2:CTG ]
[   b1  ][  *b2* ][   b3  ][   b4  ]
     [   c1  ][   c2  ][ 2:GLF ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c3 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |

**To move:** P1

1. **P1 places Null Glyph (5/5/5, C2, Cipher) into b2**
   - Expect: active trait **no trait**; captures: **none**.
   - Held after: a3 P2, b2 P1, c3 P2 · score P1 1 - P2 2
2. **P2 places Frostbite (3/6/4, C1, Steady) into b3**
   - Expect: captures: **b2**.
   - Held after: a3 P2, b2 P2, b3 P2, c3 P2 · score P1 0 - P2 4

*Why:* No neighbour at placement, so no trait. Frostbite (C1) Side 6 > 5 captures it; nothing protects it.

#### BW-055 · Copying a traitless Showcase card gives no trait
*Spec §3, §4.4*

```
     [  *a1* ][ 2:GLF ][   a3  ]
[ 2:CTG ][   b2  ][   b3  ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a2 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |

**To move:** P1

1. **P1 places Null Glyph (5/5/5, C2, Cipher) into a1** (copies the trait of a2)
   - Expect: active trait **no trait**; captures: **none**.
   - Held after: a1 P1, a2 P2, b1 P2 · score P1 1 - P2 2

*Why:* Gold Leaf has no trait to copy. Side 5 = 5 and Bottom 5 = Chrome Tiger T5 are ties.

#### BW-056 · Cipher copying Ambush on the last placement springs immediately
*Spec §10 · **depends on RQ-04***

```
     [ 1:GRV ][ 1:MAY ][ 2:GLF ]
[ 2:CTG ][ 1:BRT ][ 1:LTR ][ 2:OCH ]
     [ 2:GLA ][  *c2* ][ 1:NEO ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| a2 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 | Signature |
| a3 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b2 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P1 |  |
| b3 | Last Train (LTR) | 6/4/5 | 2 | Ambush | Night Shift | P1 | P1 |  |
| b4 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| c1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 | Signature |
| c3 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P1 | P1 |  |

**To move:** P2

1. **P2 places Null Glyph (5/5/5, C2, Cipher) into c2** (copies the trait of b3)
   - Expect: active trait **Ambush**; captures: **none**; then spring at c2 (+1) captures: **b3**.
   - Held after: a1 P1, a2 P1, a3 P2, b1 P2, b2 P1, b3 P2, b4 P2, c1 P2, c2 P2, c3 P1 · score P1 5 - P2 7
**Final:** P1 **5** - P2 **7**, winner **P2**.

*Why:* Null Glyph copies the (face-up) Last Train's Ambush. It's the last placement, so it springs before scoring as 6/6/6: b3 Last Train B5 < 6 captured; b2 Brass Tacks blocked by Steady (C3 > C2); c3 Neon Rain S6 = 6 tie.

#### BW-057 · Cipher may copy a face-down Ambush
*Spec §4.4, §10 · **depends on RQ-03***

```
     [   a1  ][   a2  ][   a3  ]
[ 2:CTG ][  *b2* ][ 2:??? ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| b1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b3 | Flare Up (FLR) | 6/3/4 | 1 | Ambush | Signal Fire | P2 | P2 | face-down (pending spring) |

**To move:** P1

1. **P1 places Null Glyph (5/5/5, C2, Cipher) into b2** (copies the trait of b3)
   - Expect: active trait **Ambush**; captures: **none**; then spring at b3 (+1) captures: **none**.
   - Held after: b1 P2, b2 P1, b3 P2 · score P1 1 - P2 2

*Why:* Only Ambush cards go face-down, so the trait is public. Null Glyph captures nothing (it would have taken b1). When P2's turn starts, Flare Up springs (Side 4 < Null Glyph S5): nothing.

### Set Link

#### BW-058 · Set Link +1 when touching an own same-set card
*Spec §4.4*

```
     [ 1:GLA ][   a2  ][   a3  ]
[   b1  ][  *b2* ][ 2:HRL ][   b4  ]
     [ 2:CTG ][ 2:SRB ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P1 | P1 |  |
| b3 | Honor Roll (HRL) | 5/6/6 | 3 | Reclaim | Old Guard | P2 | P2 |  |
| c1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c2 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 |  |

**To move:** P1

1. **P1 places Frostbite (3/6/4, C1, Steady) into b2**
   - Expect: Set Link **yes**; fights as **4/7/5**; captures: **b3, c2**.
   - Held after: a1 P1, b2 P1, b3 P1, c1 P2, c2 P1 · score P1 4 - P2 1

*Why:* Frostbite (Whiteout) touches own Glacier: 4/7/5. Side 7 > Honor Roll S6 and Bottom 5 > Service Ribbon T4, which are ties or losses without the bonus. c1 Chrome Tiger T5 = 5, tie.

#### BW-059 · An enemy same-set card gives no Set Link
*Spec §4.4*

```
     [ 2:GLA ][   a2  ][   a3  ]
[   b1  ][  *b2* ][ 2:HRL ][   b4  ]
     [ 2:CTG ][ 2:SRB ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |
| b3 | Honor Roll (HRL) | 5/6/6 | 3 | Reclaim | Old Guard | P2 | P2 |  |
| c1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c2 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 |  |

**To move:** P1

1. **P1 places Frostbite (3/6/4, C1, Steady) into b2**
   - Expect: Set Link **no**; captures: **none**.
   - Held after: a1 P2, b2 P1, b3 P2, c1 P2, c2 P2 · score P1 1 - P2 4

*Why:* Glacier is P2's. Frostbite fights at 3/6/4: every comparison is a tie or a loss.

#### BW-060 · A non-adjacent own same-set card gives no Set Link
*Spec §4.4*

```
     [   a1  ][   a2  ][ 1:GLA ]
[   b1  ][  *b2* ][ 2:HRL ][   b4  ]
     [ 2:CTG ][ 2:SRB ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a3 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P1 | P1 |  |
| b3 | Honor Roll (HRL) | 5/6/6 | 3 | Reclaim | Old Guard | P2 | P2 |  |
| c1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c2 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 |  |

**To move:** P1

1. **P1 places Frostbite (3/6/4, C1, Steady) into b2**
   - Expect: Set Link **no**; captures: **none**.
   - Held after: a3 P1, b2 P1, b3 P2, c1 P2, c2 P2 · score P1 2 - P2 3

*Why:* a3 does not touch b2.

#### BW-061 · Several same-set neighbours still give only +1
*Spec §4.4*

```
     [ 1:GLA ][ 2:GLF ][   a3  ]
[   b1  ][  *b2* ][ 2:HRL ][   b4  ]
     [ 1:SNB ][ 2:SRB ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P1 | P1 |  |
| a2 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b3 | Honor Roll (HRL) | 5/6/6 | 3 | Reclaim | Old Guard | P2 | P2 |  |
| c1 | Snow Blind (SNB) | 6/5/6 | 3 | Ambush | Whiteout | P1 | P1 |  |
| c2 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 |  |

**To move:** P1

1. **P1 places Frostbite (3/6/4, C1, Steady) into b2**
   - Expect: Set Link **yes**; fights as **4/7/5**; captures: **b3, c2**.
   - Held after: a1 P1, a2 P2, b2 P1, b3 P1, c1 P1, c2 P1 · score P1 5 - P2 1

*Why:* Two Whiteout neighbours, one bonus. Top 4 vs Gold Leaf B4 is a tie, so a2 stays with P2 (a stacked +2 would wrongly take it).

#### BW-062 · A captured enemy card of the same set gives Set Link to its new controller
*Spec §4.4 · **depends on RQ-07***

```
     [ 1:GLA ][   a2  ][   a3  ]
[   b1  ][  *b2* ][ 2:HRL ][   b4  ]
     [ 2:CTG ][ 2:SRB ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P1 | captured |
| b3 | Honor Roll (HRL) | 5/6/6 | 3 | Reclaim | Old Guard | P2 | P2 |  |
| c1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c2 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 |  |

**To move:** P1

1. **P1 places Frostbite (3/6/4, C1, Steady) into b2**
   - Expect: Set Link **yes**; captures: **b3, c2**.
   - Held after: a1 P1, b2 P1, b3 P1, c1 P2, c2 P1 · score P1 4 - P2 1

*Why:* Proposed: "your own cards" means cards you control now. Same result as the basic Set Link case.

#### BW-063 · Set Link applies to the placement only; later it defends with printed values
*Spec §4.3*

```
     [ 1:GLA ][   a2  ][   a3  ]
[   b1  ][  *b2* ][ 2:HRL ][   b4  ]
     [ 2:CTG ][ 2:SRB ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P1 | P1 |  |
| b3 | Honor Roll (HRL) | 5/6/6 | 3 | Reclaim | Old Guard | P2 | P2 |  |
| c1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c2 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 |  |

**To move:** P1

1. **P1 places Frostbite (3/6/4, C1, Steady) into b2**
   - Expect: Set Link **yes**; captures: **b3, c2**.
   - Held after: a1 P1, b2 P1, b3 P1, c1 P2, c2 P1 · score P1 4 - P2 1
2. **P2 places Gold Leaf (4/5/4, C1, no trait) into a2**
   - Expect: captures: **a1, b2**.
   - Held after: a1 P2, a2 P2, b2 P2, b3 P1, c1 P2, c2 P1 · score P1 2 - P2 4

*Why:* Gold Leaf Bottom 4 vs Frostbite's printed Top 3 (not 4): captured (Steady C1 vs C1 doesn't block). Side 5 > Glacier S2. b3 Honor Roll T5 > 4 holds.

#### BW-064 · Two Showcase cards link like any set
*Spec §3, §4.4 · **depends on RQ-08***

```
     [   a1  ][   a2  ][   a3  ]
[ 1:GLF ][  *b2* ][ 2:GRV ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| b1 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P1 | P1 |  |
| b3 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P2 | P2 |  |

**To move:** P1

1. **P1 places Chrome Tiger (5/4/4, C1, no trait) into b2**
   - Expect: Set Link **yes**; fights as **6/5/5**; captures: **b3**.
   - Held after: b1 P1, b2 P1, b3 P1 · score P1 3 - P2 0

*Why:* Proposed: Set Link is not a trait, so Chrome Tiger next to own Gold Leaf gets +1. Side 5 > Graveyard Shift S4 (equal C1, Steady doesn't block).

### Signature and "Carded!"

#### BW-065 · Capturing the enemy Signature plays "Carded!" and moves its 2 points
*Spec §4.5*

```
     [ 2:GLF ][   a2  ][   a3  ]
[   b1  ][  *b2* ][ 2:CTG ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 | Signature |

**To move:** P1

1. **P1 places Brass Tacks (6/6/5, C3, Steady) into b2**
   - Expect: captures: **a1, b3**; **"Carded!"** on b3.
   - Held after: a1 P1, b2 P1, b3 P1 · score P1 4 - P2 0

*Why:* Side 6 > Chrome Tiger S4 (P2's Signature) and Top 6 > Gold Leaf B4. P1 scores b2 + a1 + b3 x2 = 4.

#### BW-066 · Recapturing your own Signature is not "Carded!"
*Spec §4.5 · **depends on RQ-11***

```
     [   a1  ][   a2  ][   a3  ]
[   b1  ][  *b2* ][ 2:MAY ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| b3 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P2 | Signature, captured |

**To move:** P1

1. **P1 places Brass Tacks (6/6/5, C3, Steady) into b2**
   - Expect: captures: **b3**.
   - Held after: b2 P1, b3 P1 · score P1 3 - P2 0

*Why:* Mayday is P1's own Signature held by P2; taking it back scores 2 for P1 but is no Carded! moment.

#### BW-067 · "Carded!" plays again each time the enemy Signature is taken
*Spec §4.5 · **depends on RQ-11***

```
     [   a1  ][   a2  ][   a3  ]
[   b1  ][ 2:CTG ][  *b3* ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| b2 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 | Signature |

**To move:** P1

1. **P1 places Mayday (5/5/5, C2, Steady) into b3**
   - Expect: captures: **b2**; **"Carded!"** on b2.
   - Held after: b2 P1, b3 P1 · score P1 3 - P2 0
2. **P2 places Dead Air (4/8/5, C3, Veteran) into b1**
   - Expect: captures: **b2**.
   - Held after: b1 P2, b2 P2, b3 P1 · score P1 1 - P2 3
3. **P1 places Brass Tacks (6/6/5, C3, Steady) into c1**
   - Expect: captures: **b1, b2**; **"Carded!"** on b2.
   - Held after: b1 P1, b2 P1, b3 P1, c1 P1 · score P1 5 - P2 0

*Why:* P1 takes it (Carded!), P2 takes its own Signature back (no Carded), P1's Brass Tacks Top 6 takes Dead Air (B5) and Chrome Tiger (B4) again (Carded! again).

### Scoring, Triptychs and the tie flag (spec 4.5)

#### BW-068 · 1 point per card, Signature 2
*Spec §4.5*

```
     [ 1:GRV ][ 2:GLF ][ 1:MAY ]
[ 1:CTG ][ 1:BRT ][ 2:OCH ][ 2:SRB ]
     [ 2:GLA ][ 1:NEO ][ 1:FRB ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| a2 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a3 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 | Signature |
| b1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P1 | captured |
| b2 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P1 |  |
| b3 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| b4 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P1 | P2 | captured |
| c1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 | Signature |
| c2 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P1 | P1 |  |
| c3 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P1 | captured |

**Final:** P1 **7** - P2 **5**, winner **P1**.

*Why:* P1 controls a1, a3 (Signature, 2), b1, b2, c2, c3 = 7. P2 controls a2, b3, b4, c1 (Signature, 2) = 5. Points always total 12 without Triptychs.

#### BW-069 · Tie goes to the first player (P1 first)
*Spec §4.5, §9*

```
     [ 1:GRV ][ 2:GLF ][ 1:MAY ]
[ 1:CTG ][ 1:BRT ][ 2:OCH ][ 2:SRB ]
     [ 2:GLA ][ 1:NEO ][ 2:FRB ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| a2 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a3 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 | Signature |
| b1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P1 | captured |
| b2 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P1 |  |
| b3 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| b4 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P1 | P2 | captured |
| c1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 | Signature |
| c2 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P1 | P1 |  |
| c3 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P2 |  |

**Final:** P1 **6** - P2 **6**, winner **P1** (tie resolved by flag).

*Why:* 6-6. Default flag: first player wins.

#### BW-070 · Tie goes to the first player (P2 first)
*Spec §4.5, §9 · first player: **P2***

```
     [ 1:GRV ][ 2:GLF ][ 1:MAY ]
[ 1:CTG ][ 1:BRT ][ 2:OCH ][ 2:SRB ]
     [ 2:GLA ][ 1:NEO ][ 2:FRB ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| a2 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a3 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 | Signature |
| b1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P1 | captured |
| b2 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P1 |  |
| b3 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| b4 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P1 | P2 | captured |
| c1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 | Signature |
| c2 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P1 | P1 |  |
| c3 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P2 |  |

**Final:** P1 **6** - P2 **6**, winner **P2** (tie resolved by flag).

*Why:* Same board, P2 won the coin flip: P2 wins the tie. The rule follows the first player, not the P1 label.

#### BW-071 · Tie flag set to draw
*Spec §9 · balance: `tie_winner=draw`*

```
     [ 1:GRV ][ 2:GLF ][ 1:MAY ]
[ 1:CTG ][ 1:BRT ][ 2:OCH ][ 2:SRB ]
     [ 2:GLA ][ 1:NEO ][ 2:FRB ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| a2 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a3 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 | Signature |
| b1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P1 | captured |
| b2 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P1 |  |
| b3 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| b4 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P1 | P2 | captured |
| c1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 | Signature |
| c2 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P1 | P1 |  |
| c3 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P2 |  |

**Final:** P1 **6** - P2 **6**, winner **draw** (tie resolved by flag).

*Why:* With tie_winner = draw, 6-6 is a draw.

#### BW-072 · Both Signatures held by one player both count double
*Spec §10, §4.5*

```
     [ 1:GRV ][ 2:GLF ][ 1:MAY ]
[ 1:CTG ][ 1:BRT ][ 2:OCH ][ 2:SRB ]
     [ 1:GLA ][ 1:NEO ][ 2:FRB ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| a2 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a3 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 | Signature |
| b1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P1 | captured |
| b2 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P1 |  |
| b3 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| b4 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P1 | P2 | captured |
| c1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P1 | Signature, captured |
| c2 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P1 | P1 |  |
| c3 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P2 |  |

**Final:** P1 **8** - P2 **4**, winner **P1**.

*Why:* P1 holds its own Signature (a3) and P2's (c1): 2 + 2 + four single cards = 8.

#### BW-073 · Signature value tuning flag (3)
*Spec §9 · balance: `signature_value=3`*

```
     [ 1:GRV ][ 2:GLF ][ 1:MAY ]
[ 1:CTG ][ 1:BRT ][ 2:OCH ][ 2:SRB ]
     [ 2:GLA ][ 1:NEO ][ 1:FRB ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| a2 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a3 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 | Signature |
| b1 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P1 | captured |
| b2 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P1 |  |
| b3 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| b4 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P1 | P2 | captured |
| c1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 | Signature |
| c2 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P1 | P1 |  |
| c3 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P1 | captured |

**Final:** P1 **8** - P2 **6**, winner **P1**.

*Why:* Signatures worth 3: P1 5 cards + 3 = 8; P2 3 cards + 3 = 6.

#### BW-074 · Triptych +1: three cards in one row, any order
*Spec §4.5, §5.1*

```
     [ 2:GLF ][ 2:CTG ][ 1:MAY ]
[ 2:OCH ][ 1:BRT ][ 2:SRB ][ 2:GLA ]
     [ 1:NEO ][ 1:LTR ][ 1:GRV ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a2 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a3 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 | Signature |
| b1 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| b2 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P1 |  |
| b3 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 | Signature |
| b4 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |
| c1 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P1 | P1 |  |
| c2 | Last Train (LTR) | 6/4/5 | 2 | Ambush | Night Shift | P1 | P1 |  |
| c3 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |

**Final:** P1 **7** - P2 **6**, winner **P1**. Triptychs: P1: midnight_run; P2: none.

*Why:* Row C holds Neon Rain, Last Train, Graveyard Shift (Midnight Run), all P1's: 6 + 1 = 7. P2: 6.

#### BW-075 · Triptych in row B (b2-b4) counts
*Spec §4.5*

```
     [ 1:MAY ][ 2:GLF ][ 2:CTG ]
[ 2:OCH ][ 1:GRV ][ 1:LTR ][ 1:NEO ]
     [ 1:BRT ][ 2:SRB ][ 2:GLA ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 | Signature |
| a2 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b1 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| b2 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| b3 | Last Train (LTR) | 6/4/5 | 2 | Ambush | Night Shift | P1 | P1 |  |
| b4 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P1 | P1 |  |
| c1 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P1 |  |
| c2 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 | Signature |
| c3 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |

**Final:** P1 **7** - P2 **6**, winner **P1**. Triptychs: P1: midnight_run; P2: none.

*Why:* b2, b3, b4 are consecutive in row B.

#### BW-076 · Not consecutive (b1, b2, b4): no Triptych
*Spec §4.5*

```
     [ 1:MAY ][ 2:GLF ][ 2:CTG ]
[ 1:GRV ][ 1:LTR ][ 2:OCH ][ 1:NEO ]
     [ 1:BRT ][ 2:SRB ][ 2:GLA ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 | Signature |
| a2 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| b1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| b2 | Last Train (LTR) | 6/4/5 | 2 | Ambush | Night Shift | P1 | P1 |  |
| b3 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| b4 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P1 | P1 |  |
| c1 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P1 |  |
| c2 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 | Signature |
| c3 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |

**Final:** P1 **6** - P2 **6**, winner **P1** (tie resolved by flag). Triptychs: P1: none; P2: none.

*Why:* b3 breaks the run. 6-6, P1 (first player) wins the tie.

#### BW-077 · One Triptych card held by the opponent: no bonus for anyone
*Spec §4.5*

```
     [ 2:GLF ][ 2:CTG ][ 1:MAY ]
[ 2:OCH ][ 1:BRT ][ 2:SRB ][ 2:GLA ]
     [ 1:NEO ][ 2:LTR ][ 1:GRV ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a2 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a3 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 | Signature |
| b1 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| b2 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P1 |  |
| b3 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 | Signature |
| b4 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |
| c1 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P1 | P1 |  |
| c2 | Last Train (LTR) | 6/4/5 | 2 | Ambush | Night Shift | P1 | P2 | captured |
| c3 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |

**Final:** P1 **5** - P2 **7**, winner **P2**. Triptychs: P1: none; P2: none.

*Why:* P2 controls Last Train in c2, so neither player has all three.

#### BW-078 · A column is not a row: no Triptych
*Spec §4.5*

```
     [ 1:GRV ][ 2:GLF ][ 1:MAY ]
[ 1:LTR ][ 2:OCH ][ 1:BRT ][ 2:CTG ]
     [ 1:NEO ][ 2:SRB ][ 2:GLA ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| a2 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P2 | P2 |  |
| a3 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 | Signature |
| b1 | Last Train (LTR) | 6/4/5 | 2 | Ambush | Night Shift | P1 | P1 |  |
| b2 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| b3 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P1 |  |
| b4 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P2 | P2 |  |
| c1 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P1 | P1 |  |
| c2 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 | Signature |
| c3 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |

**Final:** P1 **6** - P2 **6**, winner **P1** (tie resolved by flag). Triptychs: P1: none; P2: none.

*Why:* a1, b1, c1 form a column (they're adjacent bricks), not three consecutive slots of one row.

#### BW-079 · Triptych built partly from captured enemy cards counts
*Spec §4.5 · **depends on RQ-12***

```
     [ 1:FRB ][ 1:MAY ][ 1:DAI ]
[ 1:GRV ][ 2:GLA ][ 2:OCH ][ 1:BRT ]
     [ 2:SRB ][ 1:NEO ][ 1:CTG ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P1 | captured |
| a2 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 | Signature |
| a3 | Dead Air (DAI) | 4/8/5 | 3 | Veteran | Signal Fire | P2 | P1 | captured |
| b1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| b2 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 | Signature |
| b3 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| b4 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P1 |  |
| c1 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 |  |
| c2 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P1 | P1 |  |
| c3 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P1 | P1 |  |

**Final:** P1 **9** - P2 **4**, winner **P1**. Triptychs: P1: cold_signal; P2: none.

*Why:* Row A: Frostbite + Mayday + Dead Air (Cold Signal), all controlled by P1 at the end. 8 + 1 = 9.

#### BW-080 · Triptych bonus breaks a tie against the first player
*Spec §4.5*

```
     [ 1:GLF ][ 1:CTG ][ 2:MAY ]
[ 1:OCH ][ 2:BRT ][ 1:SRB ][ 1:GLA ]
     [ 2:NEO ][ 2:LTR ][ 2:GRV ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P1 | P1 |  |
| a2 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P1 | P1 |  |
| a3 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P2 | P2 | Signature |
| b1 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P1 | P1 |  |
| b2 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P2 | P2 |  |
| b3 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P1 | P1 | Signature |
| b4 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P1 | P1 |  |
| c1 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P2 | P2 |  |
| c2 | Last Train (LTR) | 6/4/5 | 2 | Ambush | Night Shift | P2 | P2 |  |
| c3 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P2 | P2 |  |

**Final:** P1 **6** - P2 **7**, winner **P2**. Triptychs: P1: none; P2: midnight_run.

*Why:* 6-6 on cards, P2's Midnight Run makes it 6-7: P2 wins although P1 went first.

#### BW-081 · Triptych bonus flag 0
*Spec §9 · balance: `triptych_bonus=0`*

```
     [ 1:GLF ][ 1:CTG ][ 2:MAY ]
[ 1:OCH ][ 2:BRT ][ 1:SRB ][ 1:GLA ]
     [ 2:NEO ][ 2:LTR ][ 2:GRV ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Gold Leaf (GLF) | 4/5/4 | 1 | no trait | Showcase | P1 | P1 |  |
| a2 | Chrome Tiger (CTG) | 5/4/4 | 1 | no trait | Showcase | P1 | P1 |  |
| a3 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P2 | P2 | Signature |
| b1 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P1 | P1 |  |
| b2 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P2 | P2 |  |
| b3 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P1 | P1 | Signature |
| b4 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P1 | P1 |  |
| c1 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P2 | P2 |  |
| c2 | Last Train (LTR) | 6/4/5 | 2 | Ambush | Night Shift | P2 | P2 |  |
| c3 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P2 | P2 |  |

**Final:** P1 **6** - P2 **6**, winner **P1** (tie resolved by flag).

*Why:* Same board with the bonus at 0: 6-6, first player wins.

#### BW-082 · Two different Triptychs for one player
*Spec §4.5 · **depends on RQ-12***

```
     [ 1:MAY ][ 1:FRB ][ 1:DAI ]
[ 2:GLA ][ 2:OCH ][ 1:BRT ][ 2:SRB ]
     [ 1:GRV ][ 1:NEO ][ 1:LTR ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P1 | P1 | Signature |
| a2 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P1 | captured |
| a3 | Dead Air (DAI) | 4/8/5 | 3 | Veteran | Signal Fire | P2 | P1 | captured |
| b1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 | Signature |
| b2 | Open Channel (OCH) | 4/5/6 | 2 | Clutch | Signal Fire | P2 | P2 |  |
| b3 | Brass Tacks (BRT) | 6/6/5 | 3 | Steady | Old Guard | P1 | P1 |  |
| b4 | Service Ribbon (SRB) | 4/5/4 | 1 | Veteran | Old Guard | P2 | P2 |  |
| c1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| c2 | Neon Rain (NEO) | 4/6/5 | 2 | Veteran | Night Shift | P1 | P1 |  |
| c3 | Last Train (LTR) | 6/4/5 | 2 | Ambush | Night Shift | P1 | P1 |  |

**Final:** P1 **10** - P2 **4**, winner **P1**. Triptychs: P1: cold_signal, midnight_run; P2: none.

*Why:* Row A is Cold Signal and row C is Midnight Run: 8 + 2 = 10.

### Lineup validation (spec 4.2, Decisions 3 and 7)

#### BW-083 · The walkthrough lineup is legal (Clearance 10)
*Spec §4.2*

- Lineup: Graveyard Shift (C1), Neon Rain (C2), Last Train (C2), Snow Blind (C3), Mayday (C2) · total Clearance 10
- Signature: Snow Blind
- Collection: demo start (13 owned)
- **Expect:** valid

*Why:* 1+2+2+3+2 = 10 <= 12, no Legend, one Signature, all owned at demo start.

#### BW-084 · Exactly 12 with one Legend is legal
*Spec §4.2*

- Lineup: City Never Sleeps (C4), Brass Tacks (C3), Neon Rain (C2), Mayday (C2), Graveyard Shift (C1) · total Clearance 12
- Signature: City Never Sleeps
- **Expect:** valid

*Why:* 4+3+2+2+1 = 12. The cap is inclusive.

#### BW-085 · Clearance 13 is rejected
*Spec §4.2*

- Lineup: City Never Sleeps (C4), Brass Tacks (C3), Neon Rain (C2), Mayday (C2), Glacier (C2) · total Clearance 13
- Signature: Neon Rain
- **Expect:** invalid, errors `CLEARANCE_CAP`

*Why:* 4+3+2+2+2 = 13 > 12.

#### BW-086 · Two Legends are rejected even under the cap
*Spec §4.2*

- Lineup: City Never Sleeps (C4), Long Watch (C4), Graveyard Shift (C1), Frostbite (C1), Chrome Tiger (C1) · total Clearance 11
- Signature: Graveyard Shift
- **Expect:** invalid, errors `LEGEND_LIMIT`

*Why:* 4+4+1+1+1 = 11 <= 12, but at most one Legend (Clearance 4).

#### BW-087 · Four cards are rejected
*Spec §4.2*

- Lineup: Graveyard Shift (C1), Neon Rain (C2), Last Train (C2), Mayday (C2) · total Clearance 7
- Signature: Mayday
- **Expect:** invalid, errors `SIZE`

*Why:* Lineup size is exactly 5.

#### BW-088 · Six cards are rejected
*Spec §4.2*

- Lineup: Graveyard Shift (C1), Neon Rain (C2), Last Train (C2), Mayday (C2), Frostbite (C1), Service Ribbon (C1) · total Clearance 9
- Signature: Mayday
- **Expect:** invalid, errors `SIZE`

*Why:* 1+2+2+2+1+1 = 9, but 6 cards.

#### BW-089 · No Signature is rejected
*Spec §4.2*

- Lineup: Graveyard Shift (C1), Neon Rain (C2), Last Train (C2), Mayday (C2), Frostbite (C1) · total Clearance 8
- Signature: none
- **Expect:** invalid, errors `SIGNATURE_COUNT`

*Why:* Exactly one Signature.

#### BW-090 · Two Signatures are rejected
*Spec §4.2*

- Lineup: Graveyard Shift (C1), Neon Rain (C2), Last Train (C2), Mayday (C2), Frostbite (C1) · total Clearance 8
- Signature: Graveyard Shift, Mayday
- **Expect:** invalid, errors `SIGNATURE_COUNT`

*Why:* Exactly one Signature.

#### BW-091 · The Signature must be one of the 5 cards
*Spec §4.2*

- Lineup: Graveyard Shift (C1), Neon Rain (C2), Last Train (C2), Mayday (C2), Frostbite (C1) · total Clearance 8
- Signature: Snow Blind
- **Expect:** invalid, errors `SIGNATURE_NOT_IN_LINEUP`

*Why:* Snow Blind isn't in the lineup.

#### BW-092 · The same card twice is rejected
*Spec §4.2 · **depends on RQ-15***

- Lineup: Graveyard Shift (C1), Graveyard Shift (C1), Last Train (C2), Mayday (C2), Frostbite (C1) · total Clearance 7
- Signature: Mayday
- **Expect:** invalid, errors `DUPLICATE`

*Why:* The collection holds one copy of each card.

#### BW-093 · Showcase cards are legal and not limited in number
*Spec §3, §4.2 · **depends on RQ-15***

- Lineup: Chrome Tiger (C1), Gold Leaf (C1), Graveyard Shift (C1), Frostbite (C1), Service Ribbon (C1) · total Clearance 5
- Signature: Chrome Tiger
- **Expect:** valid

*Why:* Store cards are already Clearance 1 with no trait (Decision 3); proposed: no extra cap. Total 5. A Showcase card may be the Signature.

#### BW-094 · Cards not in the collection are rejected
*Spec §4.2, §7*

- Lineup: Graveyard Shift (C1), Neon Rain (C2), Last Train (C2), Polar Night (C3), Mayday (C2) · total Clearance 10
- Signature: Polar Night
- Collection: demo start (13 owned)
- **Expect:** invalid, errors `NOT_OWNED`

*Why:* Polar Night is locked at demo start. 1+2+2+3+2 = 10, otherwise legal.

#### BW-095 · Loaner lineup is offered when the collection can't make a legal 5
*Spec §4.2, §10 · **depends on RQ-16***

- Collection: Graveyard Shift, Neon Rain, Last Train, Mayday
- **Expect:** loaner offered: **yes**

*Why:* 4 cards can't make a lineup. The loaner lineup offered must itself pass validation.

#### BW-096 · Loaner lineup is not forced on the demo start collection
*Spec §4.2, §7*

- Collection: Graveyard Shift, Neon Rain, Last Train, Frostbite, Snow Blind, Glacier, Mayday, Flare Up, Open Channel, Brass Tacks, Service Ribbon, Chrome Tiger, Gold Leaf
- **Expect:** loaner offered: **no**

*Why:* 13 owned cards make many legal lineups.

#### BW-097 · Card data rules: budgets and the anti-pay-to-win rule
*Spec §3, §6*

*Expect:* All 20 demo cards have T+S+B = 13/15/17/19 for Clearance 1/2/3/4. Any Showcase (store) card must be Clearance 1 with trait none: a Showcase card with Clearance 2, or with a trait, fails validation. 13 cards are owned at demo start.

### Turn flow and engine contract

#### BW-098 · Illegal placements are rejected and change nothing
*Spec §4.3*

```
     [   a1  ][   a2  ][   a3  ]
[   b1  ][ 1:GRV ][   b3  ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| b2 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |

**To move:** P2

- P1 tries Neon Rain into a1: rejected `NOT_YOUR_TURN`, state unchanged.
- P2 tries Glacier into b2: rejected `SLOT_OCCUPIED`, state unchanged.
- P2 tries Glacier into d1: rejected `INVALID_SLOT`, state unchanged.
- P2 tries City Never Sleeps into a1: rejected `NOT_IN_HAND`, state unchanged.

*Why:* P2's hand is FRB, GLA, PNT, OCH, SRB. Each attempt returns an error code (names are suggestions) and the state is unchanged.

#### BW-099 · Coin flip, strict alternation, 5 placements each, then the game is over
*Spec §4.3*

*Expect:* With a fixed seed the coin flip is repeatable, and both outcomes occur across seeds. The first player makes placements 1, 3, 5, 7, 9; the other makes 2, 4, 6, 8, 10. After the 10th the state reports game over, and any further placement is rejected (GAME_OVER).

#### BW-100 · preview() returns exactly what place() does
*Spec §11 · **depends on RQ-20***

*Expect:* For every placement step in this file, preview(state, card, slot[, copy]) returns the same captured and reclaimed slots, bonuses, copied trait and face-down flag as place(). Start-of-turn springs that follow are reported separately. Never preview the opponent's pending face-down cards (RQ-20).

### Worked example and full duel

#### BW-101 · Spec 4.6 worked example
*Spec §4.6*

```
     [ 2:GLA ][   a2  ][   a3  ]
[   b1  ][  *b2* ][ 2:MAY ][   b4  ]
     [ 1:GRV ][ 2:FRB ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Glacier (GLA) | 7/2/6 | 2 | Veteran | Whiteout | P2 | P2 |  |
| b3 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P2 | P2 |  |
| c1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| c2 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P2 |  |

**To move:** P1

1. **P1 places Neon Rain (4/6/5, C2, Veteran) into b2**
   - Expect: Set Link **yes**; fights as **5/7/6**; captures: **b3, c2**.
   - Held after: a1 P2, b2 P1, b3 P1, c1 P1, c2 P1 · score P1 4 - P2 1

*Why:* Neon Rain touches own Graveyard Shift (Night Shift): 5/7/6. a1 Glacier B6 > 5, no. b3 Mayday S5 < 7, captured (Steady C2 doesn't block C2). c2 Frostbite T3 < 6, captured (Steady C1). a2 and b1 empty. 2 captures.

#### BW-102 · Worked example variant: 5 vs 5 captures because Veteran wins ties
*Spec §4.6*

```
     [ 2:MAY ][   a2  ][   a3  ]
[   b1  ][  *b2* ][   b3  ][   b4  ]
     [ 1:GRV ][ 2:FRB ][   c3  ]
```

| Slot | Card | T/S/B | Clr | Trait | Set | Lineup | Held by | Notes |
|---|---|---|---|---|---|---|---|---|
| a1 | Mayday (MAY) | 5/5/5 | 2 | Steady | Signal Fire | P2 | P2 |  |
| c1 | Graveyard Shift (GRV) | 5/4/4 | 1 | Steady | Night Shift | P1 | P1 |  |
| c2 | Frostbite (FRB) | 3/6/4 | 1 | Steady | Whiteout | P2 | P2 |  |

**To move:** P1

1. **P1 places Neon Rain (4/6/5, C2, Veteran) into b2**
   - Expect: Set Link **yes**; captures: **a1, c2**.
   - Held after: a1 P1, b2 P1, c1 P1, c2 P1 · score P1 4 - P2 0

*Why:* The spec's aside: with a defender Bottom of 5 (Mayday, C2), Top 5 vs 5 is a tie and Veteran captures.

#### BW-103 · Scripted full duel (walkthrough lineup vs a 9-Clearance rival)
*Spec §4, §8*

```
     [  *a1* ][   a2  ][   a3  ]
[   b1  ][   b2  ][   b3  ][   b4  ]
     [   c1  ][   c2  ][   c3  ]
```

Empty wall.

- P1 lineup: Graveyard Shift, Neon Rain, Last Train, Snow Blind, Mayday (Signature: Snow Blind)
- P2 lineup: Frostbite, Glacier, Polar Night, Open Channel, Service Ribbon (Signature: Polar Night)

**To move:** P1

1. **P1 places Graveyard Shift (5/4/4, C1, Steady) into a1**
   - Expect: captures: **none**.
   - Held after: a1 P1 · score P1 1 - P2 0
2. **P2 places Glacier (7/2/6, C2, Veteran) into b2**
   - Expect: captures: **a1**.
   - Held after: a1 P2, b2 P2 · score P1 0 - P2 2
3. **P1 places Last Train (6/4/5, C2, Ambush) into b3**
   - Expect: **face-down**; captures: **none**.
   - Held after: a1 P2, b2 P2, b3 P1 · score P1 1 - P2 2
4. **P2 places Open Channel (4/5/6, C2, Clutch) into a2**
   - Expect: Clutch **no**; captures: **none**; then spring at b3 (+1) captures: **a2, b2**.
   - Held after: a1 P2, a2 P1, b2 P1, b3 P1 · score P1 3 - P2 1
5. **P1 places Mayday (5/5/5, C2, Steady) into c2**
   - Expect: captures: **none**.
   - Held after: a1 P2, a2 P1, b2 P1, b3 P1, c2 P1 · score P1 4 - P2 1
6. **P2 places Polar Night (5/7/5, C3, Clutch) into b1** (this card is the Signature)
   - Expect: Set Link **no**; Clutch **yes**; captures: **b2**.
   - Held after: a1 P2, a2 P1, b1 P2, b2 P2, b3 P1, c2 P1 · score P1 3 - P2 4
7. **P1 places Snow Blind (6/5/6, C3, Ambush) into a3** (this card is the Signature)
   - Expect: **face-down**; captures: **none**.
   - Held after: a1 P2, a2 P1, a3 P1, b1 P2, b2 P2, b3 P1, c2 P1 · score P1 5 - P2 4
8. **P2 places Frostbite (3/6/4, C1, Steady) into b4**
   - Expect: captures: **b3**; then spring at a3 (+1) captures: **b3, b4**.
   - Held after: a1 P2, a2 P1, a3 P1, b1 P2, b2 P2, b3 P1, b4 P1, c2 P1 · score P1 6 - P2 4
9. **P1 places Neon Rain (4/6/5, C2, Veteran) into c3**
   - Expect: Set Link **yes**; captures: **none**.
   - Held after: a1 P2, a2 P1, a3 P1, b1 P2, b2 P2, b3 P1, b4 P1, c2 P1, c3 P1 · score P1 7 - P2 4
10. **P2 places Service Ribbon (4/5/4, C1, Veteran) into c1**
   - Expect: captures: **none**.
   - Held after: a1 P2, a2 P1, a3 P1, b1 P2, b2 P2, b3 P1, b4 P1, c1 P2, c2 P1, c3 P1 · score P1 7 - P2 5
**Final:** P1 **7** - P2 **5**, winner **P1**. Triptychs: P1: none; P2: none.

*Why:* An end-to-end script touching captures, Steady, Ambush springs, Clutch and a Steady block of a Veteran tie (move 10: Service Ribbon S5 = Mayday S5, but Mayday is C2 > C1). Final 7-5.

## Review log (Mid Game Designer gate)

The plan asks for these cases to be reviewed by the Mid Game Designer before cc05 starts coding. QA did this pass in that role, using `.claude/agents/mid-game-designer.md` (implementation details and content values within approved systems; system-level calls go to the Sr Game Designer). Every case was checked again against spec §4, §9 and §10 and the Decisions. Each expected capture, spring, score and winner was also run through an independent reference reading of the rules, kept as a scratch tool and not committed. All 103 cases agree. The full controller maps and per-step scores in the JSON come from that reading and were spot-checked by hand.

**Corrections made during review:**

- Reachability: three drafts gave one side 6 cards on the board (sweep from b2, "never captured" board, row-C board). Each was cut to 5 per lineup so every fixture could exist in a real lineup.
- Hidden Set Link: the no-friendly-fire draft put an own Service Ribbon (Old Guard) next to Brass Tacks (Old Guard). The resulting Set Link would have turned the tie with Frostbite into a capture. The neighbours were replaced with non-Old Guard cards (BW-012).
- Ambush next to Ambush: the first draft paired cards whose spring values only tied, so it never showed that a face-down card is protected. It now uses Last Train (spring Side 5) against a face-down Flare Up (Side 3), which would be captured if it were face-up (BW-031).
- Reclaim vs Set Link: the first Reclaim draft (City Never Sleeps reclaiming Graveyard Shift) gives a different result depending on whether Reclaim runs before Set Link is decided. It was split into an order-independent case (BW-034) and an explicit case for the order (BW-035, RQ-06).
- Steady vs Reclaim (§10): with the 20 demo cards, a Reclaim card is never lower in Clearance than a Steady card (Reclaim is C3/C4, Steady at most C3). The edge case can only come up when a Cipher copies Reclaim, so it's tested that way (BW-036, Null Glyph C2 retaking Brass Tacks C3).
- Set Link from an own face-down card: this case was dropped. An own face-down Ambush never exists during its owner's placement, because it springs at the start of that turn (noted in RQ-07).
- Spec §8 walkthrough: Clutch fires for a player who is ahead. This is a contradiction in the text, not in the rules (RQ-17). No case uses it.
- Worked example (§4.6): the spec doesn't mention that Mayday is Steady. Neon Rain is C2, the same as Mayday, so the capture stands. BW-101 now says so explicitly.
- Card-data validation: the Showcase must-fail example was changed so it fails only the store-card rule, not the stat budget as well (BW-097).

**Review verdict:** the cases match the approved spec. 82 of 103 cases depend on no open question. The rest assume the proposed answers to RQ-01 to RQ-20, and each one says so. The most important calls for the designer are RQ-06 (order of resolution), RQ-08 (Showcase Set Link vs. the anti-pay-to-win rule), RQ-09 (Clutch score) and RQ-17 (walkthrough text). cc05 can start; if the designer overrules a question, only the cases listed under it change.

## Rules questions

The spec is approved, but these points are ambiguous or contradictory. Each has a proposed answer that the dependent cases assume. **Sr/Mid Game Designer: please confirm or overrule before cc05 ends**; an overrule changes only the listed cases.

**RQ-01 · Cipher: how long does a copied trait last?** Spec 4.4 says Cipher copies a trait on placement, and 10 has a copied Ambush spring a turn later, so the copy outlives the placement. It doesn't say whether a copied Steady keeps protecting the card.
- *Proposed:* The copied trait replaces Cipher for the rest of the match, wherever the card is and whoever controls it. A copied Steady keeps protecting it.
- *Cases that assume it:* BW-048

**RQ-02 · Cipher copying a Cipher card that has already copied something.** Spec 10 says "Cipher copying Cipher: no trait". It doesn't say whether that means the target's printed trait (Cipher) or the trait it holds now.
- *Proposed:* Copy the printed trait. Copying any Cipher card gives no trait, even if it holds a copied one.
- *Cases that assume it:* BW-053

**RQ-03 · Cipher: what may be picked, and is copying optional?** "one adjacent card (your pick)" doesn't say whether the card can be an enemy's, a face-down Ambush or a traitless card, or whether the player can decline.
- *Proposed:* Any adjacent card of either side, face-down included (only Ambush cards go face-down, so that trait is public). Picking a traitless or Cipher card gives no trait, which is how a player opts out. place() takes a required copy_from slot whenever the card has a neighbour.
- *Cases that assume it:* BW-057

**RQ-04 · Cipher holding a copied Ambush: capture before the spring, and last placement.** Spec 10 says it stays face-up, so it can be captured before it springs. It doesn't say what happens to the spring then, or what happens on the last placement.
- *Proposed:* If the placer no longer controls it when their next turn starts, the spring is cancelled. On the last placement it springs right away before scoring, like a real Ambush.
- *Cases that assume it:* BW-051, BW-056

**RQ-05 · Ambush spring and placement bonuses.** Spec 4.3.3 limits Set Link and Clutch to "the placed card's comparisons on that turn". A spring happens on a later turn.
- *Proposed:* A spring uses printed values +1 (ambush_spring_bonus) only. No Set Link, no Clutch, no Veteran (the card's trait is Ambush). Steady still applies. Springs never chain unless chain_captures is on.
- *Cases that assume it:* BW-028

**RQ-06 · Order of resolution inside one placement.** Reclaim, Set Link and captures all happen "on placement", and the order changes results (see the Reclaim cases).
- *Proposed:* 1) Cipher copy. 2) Bonuses (Set Link, Clutch) read from the board before anything flips. 3) Reclaim. 4) Value captures against enemy-controlled, face-up neighbours. 5) Chain, if on. 6) Turn passes, and the next player's springs resolve (or all pending springs, in placement order, if the wall is full). 7) Scoring.
- *Cases that assume it:* BW-035

**RQ-07 · Set Link: what counts as "your own cards"?** It could mean cards you control now, or cards from your lineup.
- *Proposed:* Cards you control at that moment, including captured enemy cards. Your lineup cards held by the enemy don't count. Note: your own face-down card never exists on your own turn, because it springs at the start of it.
- *Cases that assume it:* BW-062

**RQ-08 · Do the two Showcase cards get Set Link with each other?** Spec 6 gives Chrome Tiger and Gold Leaf the set "Showcase", and Set Link applies to "all cards". But the binding anti-pay-to-win rule says store cards never get more power.
- *Proposed:* Yes. Set Link isn't a trait, and it gives the same +1 every set gets, so it isn't extra power. Needs a design call: if store cards should get no bonus at all, exclude the Showcase set and flip the expectation in that case.
- *Cases that assume it:* BW-064

**RQ-09 · Clutch "behind" check: which score?** Spec 10 says "current score before placement, with Signatures counted double". It doesn't mention face-down cards, Triptychs, or springs that happen at the start of the turn.
- *Proposed:* Use the same score function as end-of-game scoring (Triptych bonus included), on the true board: face-down cards count for their owner, Signature included. Take it after this turn's start-of-turn springs. "Behind" means strictly lower. UI note: if a face-down card is the Signature, the score counter would reveal it, so the UI should show face-down cards as 1 point plus a "?".
- *Cases that assume it:* BW-044, BW-045

**RQ-10 · Is a Reclaim retake a "capture"?** It matters for "Carded!", the Dead Air unlock ("capture 20 cards total") and the placement preview.
- *Proposed:* No. It's a separate "reclaim" event: no "Carded!" and no capture count. The preview shows it with its own marker.
- *Cases that assume it:* BW-034

**RQ-11 · When exactly does "Carded!" play?** Spec 4.5 says "capturing an enemy Signature".
- *Proposed:* Whenever a Signature from the opponent's lineup comes under your control through a value capture, a spring or a chain, and again each time this happens. Never for retaking your own Signature, whether by capture or by Reclaim.
- *Cases that assume it:* BW-066, BW-067

**RQ-12 · Triptych ownership and counting.** "three of your cards" could mean cards you control or cards from your lineup. It's also open whether order matters and whether a player can score more than one.
- *Proposed:* Cards you control at the end, from either lineup, in any order, in a run of 3 consecutive slots of one row (A: a1-a3, B: b1-b3 or b2-b4, C: c1-c3). Each Triptych scores at most once per player, and different Triptychs add up. The "first time revealed" reward belongs to the collection and only fires for the human player.
- *Cases that assume it:* BW-079, BW-082

**RQ-13 · What happens when chain captures are turned on?** Spec 9 only says "captured cards re-check their neighbors".
- *Proposed:* Breadth-first. Each newly captured card attacks its enemy-controlled, face-up neighbours with printed values and its own trait (Veteran ties count, Steady blocks, no Set Link or Clutch). Reclaimed cards don't chain. Default stays off.
- *Cases that assume it:* BW-015

**RQ-14 · Can values go above 9?** Values are 1-9, but bonuses can push past 9 (Polar Night: Side 10 with Clutch and Set Link).
- *Proposed:* No cap. Compare integers.

**RQ-15 · Lineup: duplicates, Showcase limits, Signature.** The brief asks for store-card limits, but the spec sets none. It also doesn't say whether duplicates are allowed.
- *Proposed:* No duplicates. No limit on Showcase cards, since they're already Clearance 1 with no trait. Exactly one Signature, chosen from the 5, and a Showcase card may be it. The two players may bring the same card (rival lineups are fixed), so the engine must track card instances, not card ids.
- *Cases that assume it:* BW-092, BW-093

**RQ-16 · When is the loaner lineup offered?** Spec 4.2 says "if their collection can't make a full 5".
- *Proposed:* Offer it when the collection can't form any legal lineup (5 distinct owned cards, Clearance cap, Legend limit). A collection of 5 owned Clearance-3 cards counts as "can't".
- *Cases that assume it:* BW-095

**RQ-17 · Spec 8 walkthrough contradicts Clutch.** Step 4 says the player is "behind 3-4" and then Archivist plays Polar Night with Clutch +2. Archivist is ahead, so Clutch can't fire.
- *Proposed:* Fix the walkthrough text: Archivist is behind, so make it "ahead 4-3", or drop the Clutch mention. The rule itself stays.

**RQ-18 · Isolated test boards.** Many cases use boards that can't come up in a legal game (for example one side has more cards than turns played). That keeps each rule isolated.
- *Proposed:* The engine's test helper (WallState.from_setup) must accept any board with explicit to_move and first_player fields. Cases that model the end of a game use reachable boards (5 cards per lineup).

**RQ-19 · Hidden information in face-down cards.** Hand order is hidden and Ambush cards are face-down, but lineups are public.
- *Proposed:* The AI and the preview may know a face-down card is an Ambush, but not which card it is. Only the engine's springs and scoring use its identity.

**RQ-20 · What does the placement preview cover?** Spec 11 asks for a preview of "which cards would flip". It doesn't say whether that includes the springs that follow.
- *Proposed:* The placed card's own resolution only: captures, reclaims, copied trait and bonuses, plus its own immediate spring if this placement fills the wall. Never the opponent's pending springs.
- *Cases that assume it:* BW-100


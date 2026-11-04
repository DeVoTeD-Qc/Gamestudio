# CallingCard: Prototype Content Log (cc03)

*Mid Game Designer · 2026-11-04 · Source of truth for values: `../mechanics/banner-wall-spec.md` (approved 2026-11-03).
Data lives in `source/project-callingcard/data/` (format: `data/README.md`). All names are original.*

Status: the data loads with **no CardDB errors or warnings**. All 5 Dossier solutions were played through the
real `WallRules` engine and meet their goals.

## Cards (spec §6, unchanged)
T / S / B values, Clearance and origin match spec §6 and the QA card table (`qa/rules-test-cases.json`) exactly.

| # | id | Set (order) | Origin → trait | Clr | T/S/B | Glyph | Demo start |
|---|---|---|---|---|---|---|---|
| 1 | graveyard_shift | Night Shift (1) | Challenge → Steady | 1 | 5/4/4 | 1 | Owned |
| 2 | neon_rain | Night Shift (2) | Mastery → Veteran | 2 | 4/6/5 | – | Owned |
| 3 | last_train | Night Shift (3) | Event → Ambush | 2 | 6/4/5 | – | Owned |
| 4 | city_never_sleeps | Night Shift (4) | Prestige → Reclaim | 4 | 7/5/7 | – | `unlock_beat_warden` |
| 5 | frostbite | Whiteout (1) | Challenge → Steady | 1 | 3/6/4 | 2 | Owned |
| 6 | snow_blind | Whiteout (2) | Event → Ambush | 3 | 6/5/6 | – | Owned |
| 7 | polar_night | Whiteout (3) | Ranked → Clutch | 3 | 5/7/5 | – | `unlock_win_streak_3` |
| 8 | glacier | Whiteout (4) | Mastery → Veteran | 2 | 7/2/6 | – | Owned |
| 9 | mayday | Signal Fire (1) | Challenge → Steady | 2 | 5/5/5 | 3 | Owned |
| 10 | flare_up | Signal Fire (2) | Event → Ambush | 1 | 6/3/4 | – | Owned |
| 11 | dead_air | Signal Fire (3) | Mastery → Veteran | 3 | 4/8/5 | – | `unlock_captures_20` |
| 12 | open_channel | Signal Fire (4) | Ranked → Clutch | 2 | 4/5/6 | – | Owned |
| 13 | brass_tacks | Old Guard (1) | Challenge → Steady | 3 | 6/6/5 | 4 | Owned |
| 14 | service_ribbon | Old Guard (2) | Mastery → Veteran | 1 | 4/5/4 | – | Owned |
| 15 | long_watch | Old Guard (3) | Ranked → Clutch | 4 | 6/7/6 | – | `unlock_beat_warden_no_legend` |
| 16 | honor_roll | Old Guard (4) | Prestige → Reclaim | 3 | 5/6/6 | – | `unlock_wins_5` |
| 17 | null_glyph | Cipher (1) | Secret → Cipher | 2 | 5/5/5 | – | `unlock_dossier_carded` |
| 18 | key_fragment | Cipher (2) | Secret → Cipher | 3 | 6/5/6 | – | `unlock_cipher_lock` |
| 19 | chrome_tiger | Showcase (1) | Store → none | 1 | 5/4/4 | – | Owned (store) |
| 20 | gold_leaf | Showcase (2) | Store → none | 1 | 4/5/4 | – | Owned (store) |

13 owned / 7 locked. `how_earned` and `art_brief` are the spec §6 text; `art_key` = card id; every card is
Signature-eligible. Album order inside each set follows the spec list.

## Sets
| # | id | Kind | Tagline | Completion title |
|---|---|---|---|---|
| 1 | night_shift | Standard | The city after dark. | Night Owl (spec) |
| 2 | whiteout | Standard | Cold fronts, white fields and long silences. | Cold Front |
| 3 | signal_fire | Standard | Flares, radios and calls for help. | Beacon |
| 4 | old_guard | Standard | Ribbons, plaques and long years of service. | Old Hand |
| 5 | cipher | Cipher | Secret cards. Some doors only open with a code. | Codekeeper |
| 6 | showcase | Showcase | Store bundles: premium frames, Clearance 1, no trait. | – |

## Unlock goals (spec §6 "Demo start")
| id | Kind | Target | Album line | Unlocks |
|---|---|---|---|---|
| unlock_win_streak_3 | WIN_STREAK | 3 | Win 3 duels in a row | Polar Night |
| unlock_beat_warden | BEAT_RIVAL | warden | Beat the Warden | City Never Sleeps |
| unlock_beat_warden_no_legend | BEAT_RIVAL_NO_LEGEND | warden | Beat the Warden with no Legend in your lineup | Long Watch |
| unlock_captures_20 | CAPTURES_TOTAL | 20 | Capture 20 cards in total | Dead Air |
| unlock_wins_5 | WINS_TOTAL | 5 | Win 5 duels | Honor Roll |
| unlock_dossier_carded | DOSSIER_CLEAR | dossier_carded | Clear Dossier D4: Carded | Null Glyph |
| unlock_cipher_lock | CIPHER_LOCK | – | Solve the Cipher Lock | Key Fragment |

## Rivals (spec §7)
| id | Level | Lineup (Clearance) | Total | Signature | AI tuning |
|---|---|---|---|---|---|
| quartermaster | Easy | Chrome Tiger 1, Gold Leaf 1, Glacier 2, Mayday 2, Open Channel 2 | 8 / 12 | Chrome Tiger | best capture 0.5, 0 plies |
| archivist | Normal | Brass Tacks 3, Polar Night 3, Dead Air 3, Neon Rain 2, Service Ribbon 1 | 12 / 12 | Brass Tacks | best capture 1.0, 1 ply (greedy) |
| warden | Hard | Long Watch 4, Snow Blind 3, Last Train 2, Mayday 2, Frostbite 1 | 12 / 12 (1 Legend) | Long Watch | best capture 1.0, 2 plies, Signature safety 3.0 |

Themes: the Quartermaster hands out store and issue gear (the store Signature makes the first "Carded!" easy
and shows store cards are weak); the Archivist holds Polar Night, matching the spec §8 walkthrough, and
shows two locked cards (Polar Night, Dead Air); the Warden guards Long Watch, the Legend you earn by beating it.

## Loaner lineup (`balance.tres`)
Graveyard Shift 1, Neon Rain 2, Last Train 2, Snow Blind 3, Mayday 2 = **10 / 12**, Signature **Snow Blind**:
the spec §8 walkthrough lineup. All five start owned.

## Cipher Lock
Glyph number = set number of the card that carries it: Graveyard Shift 1, Frostbite 2, Mayday 3, Brass Tacks 4
(spec: cards 1, 5, 9, 13). `cipher_code` = **1, 2, 3, 4**: the glyphs in album page order ("hinted by set numbering").

## Triptychs (spec §5.1)
| id | Cards | Hint | Reward |
|---|---|---|---|
| midnight_run | Graveyard Shift, Neon Rain, Last Train | The city's last ride, three stops long. | Title *Night Owl+*, panorama |
| cold_signal | Frostbite, Mayday, Dead Air | Someone's calling from the ice. | Title *Ice Radio*, panorama |
| open_book | Null Glyph, Key Fragment, Honor Roll | Old honor, new code. | Title *Codebreaker*, panorama, frame `gold_cipher` |

## Dossiers (spec §5.2)
Slots: `a1 a2 a3 / b1 b2 b3 b4 / c1 c2 c3`. "You" = player, "R" = rival, * = Signature.

| # | id | Board | Hand | Rival reply | Goal | Solution | Reward |
|---|---|---|---|---|---|---|---|
| D1 First Contact | dossier_first_contact | R: a2 Chrome Tiger*, b3 Gold Leaf, c2 Service Ribbon | Glacier, Frostbite | – | Capture 3 in ≤ 2 | Glacier b2 (Top 7 takes a2 → "Carded!", Bottom 6 takes c2), Frostbite b4 (Side 6 takes b3) | Mayday card, or title *Contact Made* if owned |
| D2 Same Page | dossier_same_page | You: a2 Last Train. R: a1 Chrome Tiger*, b1 Dead Air, b2 Brass Tacks, c3 Service Ribbon | Graveyard Shift, Neon Rain | – | Win in exactly 2 | Neon Rain c2 (takes c3), Graveyard Shift c1 (Set Link: Top 6 vs Dead Air 5). 5–3 | Frame `service_ribbon_frame` |
| D3 Lights Out | dossier_lights_out | R: a1 Gold Leaf, a3 Chrome Tiger*, b3 Frostbite | Flare Up, Graveyard Shift | a2 Service Ribbon (after your 1st) | Capture 2 with one spring | Flare Up face-down b2; the rival walks into a2; spring Top 7 takes a1 and a2; Graveyard Shift anywhere | Frame `flare_up_gold` |
| D4 Carded | dossier_carded | You: c2 Graveyard Shift*. R: a1 Mayday*, a2 Snow Blind, b1 Glacier | Honor Roll, Service Ribbon | c1 Open Channel (takes your Signature) | Capture their Signature and win | Service Ribbon b3, Honor Roll b2: Reclaim c2, Set Link Top 6 takes Mayday*, also b1 and c1. 8–1 | **Null Glyph** |
| D5 Clean Copy | dossier_clean_copy | You: b3 Frostbite. R: a1 Graveyard Shift, b1 Brass Tacks, b2 Glacier, c2 Polar Night, c3 Chrome Tiger* | Null Glyph, Gold Leaf | – | Win by copying a rival trait | Null Glyph c1 copying **Polar Night's Clutch** (you're behind: +2, Top 7 takes Glacier); Gold Leaf a2 (Side 5 takes a1). 5–4 | Title *Copycat* |

Brute-force check (scratch rules model, matches all 67 QA placement/sequence cases with chain captures off):
D1, D2, D4 and D5 have exactly one winning set of slots; D3 needs Flare Up in b2 (the second card is free).

## Balance defaults (spec §9, unchanged)
Wall 3/4/3, lineup 5, Clearance cap 12, 1 Legend, budgets 13/15/17/19, stats 1–9, set size 2–6, Set Link +1,
Clutch +2, Ambush spring +1, Signature ×2, Triptych +1, ties to first player, chain captures off, lobby wait 60–150 s.

## Changes from spec
**No spec values changed.** Every card value, budget, Triptych, Dossier name/goal/reward and §9 default is as
approved. The items below were not fixed by the spec, so they are content decisions:
1. Rival lineups and AI tuning numbers (Warden `signature_safety_weight` 3.0; Quartermaster under the cap at 8).
2. Loaner lineup = the spec §8 walkthrough lineup.
3. Glyph numbers and the Cipher code 1-2-3-4 (set order).
4. Set taglines and completion titles for Whiteout, Signal Fire, Old Guard and Cipher.
5. D1 fallback title *Contact Made* (spec: "or title"). Frame ids `service_ribbon_frame`, `flare_up_gold`, `gold_cipher`.
6. All Dossier boards, hands, replies and briefings.

## Open questions
1. **Test conflict:** `tests/test_data.gd::test_sample_cards_match_spec` expects Night Shift to hold only
   `graveyard_shift, neon_rain` (the cc02 samples). With the full spec content it holds 4 cards, so that one
   assertion fails. The test should expect `graveyard_shift, neon_rain, last_train, city_never_sleeps`.
2. **Long Watch unlock:** the player starts with no Legend, so the first Warden win also meets "beat the Warden
   with no Legend" and unlocks City Never Sleeps and Long Watch together. If they should be two steps, make
   Long Watch "beat the Warden twice with no Legend" or require City Never Sleeps to be owned first.
3. **Dossier Cipher pick:** `DossierPlacement` can't store a Cipher pick; D5's solution copies from c2 (cc12).
4. **Reserved reply slots** (D3 a2, D4 c1) need to be shown as taken on the Dossier screen (cc12).

# CardZone: 1v1 Web Prototype Scope

*Producer Agent · 2026-11-04 · Board task `cz-plan` · Phase: plan*
*The detailed plan (phases, tasks, reuse, KPIs, risks) is `prototype-milestone-plan.md`. Task list: `prototype-tasks.json`.*

> **What this prototype is:** a private web build of **Loadout Loop** (concept A, spec v0.2) that the studio head can play **alone on an iPhone in landscape, 1v1 against a deterministic AI**. It answers one question: **is the Loadout Loop fun and fast in a 1v1 duel, with "your next hand is your armour" creating real choices and no packing paralysis or shot snowball?**

## 1. Market check
Market verdict **GO** (`../research/market-scan.md`): a deterministic battle-royale deckbuilder is an open gap. For this build that means: prove the no-shuffle loop is tense, keep turns short, avoid feel-bad elimination, and make no external originality claim yet.

## 2. In scope (est. 8 working days, ≈ 18.75 agent-days in parallel)
| # | Item | Task(s) |
|---|---|---|
| 1 | Prototype rules §16: 1v1, private loadouts info model, tunables table | cz01 |
| 2 | Sim sweep: hand 4 vs 5, hold 2 vs 1, routes A/B/C, all 36 drop pairs | cz02 |
| 3 | Godot project from CallingCard/Killstreak (Compatibility renderer, test runner, shell, Web preset, packaging) | cz03 |
| 4 | Data: 27 player cards + Bounty, Ridge Hollow (7 areas), 14 Zone cards × 3 routes, Standard pack, `balance.tres` | cz05, cz06 |
| 5 | Pure, deterministic rules engine with replay and a per-seat view (≥ 70 test-first cases) | cz04, cz07 |
| 6 | Save after every action, resume and replay | cz08 |
| 7 | AI opponent: Rookie and Veteran, deterministic, fairness wall, AI-vs-AI balance sim | cz09 |
| 8 | Match screen for phone landscape: map, hand, line, loadout strip ("next hand = armour"), opponent panel, Zone track, inspector | cz10 |
| 9 | Turn flow (play, Adrenaline, move, loot, shoot with preview, attach, patch up, ditch, Hold and Stow, undo) | cz11 |
| 10 | Brace prompt and AI turn playback | cz12 |
| 11 | Title, match setup (opponent, first player, route, drop), end screen, pause, first-match coach, hidden dev panel for tunables | cz13 |
| 12 | Hot-seat (pass the phone with cover screens) | cz14 (first to cut) |
| 13 | Art direction (grounded near-future island) and procedural placeholder art kit (< 5 MB) | cz15, cz16 |
| 14 | Looting and shooting feel | cz17 |
| 15 | Playtest logger, survey, KPI sheet (CallingCard approach) | cz18 |
| 16 | QA pass, RC build as a private artifact, internal playtest and report | cz19, cz20, cz21 |

## 3. Out of scope
3–4 players and placement points, solo Raiders/Warden, online or async play, accounts, a custom starting order or any card-reordering UI, print-and-play files, painted art, music and voice (placeholder sfx only), localization, native builds, external pitch material or originality claims.
**Backlog:** czb1 concept B Reload · czb2 concept C Shrinking Ring map variant (Q10) · czb3 concept D Supply Line · czb4 3–4 players · czb5 solo mode · czb6 print-and-play sheet · czb7 prior-art check.

## 4. Tunables (`data/balance.tres`; defaults per the head's decisions and spec v0.2 F1–F8)
Every key is switchable without code, covered by a test (cz04/cz07), and reachable from the hidden dev panel (cz13) for the playtest.
| Key | Default | Allowed | Source |
|---|---|---|---|
| `hand_size` | **5** | 4, 5 | Q6 (head: "maybe 5"), sim re-check in plan §2 |
| `health` | 5 | 4–6 | Q6 |
| `packing_rule` | `hold_and_stow` | `hold_and_stow`, `rack_swap` | F1 (backup rule) |
| `hold_limit` | 2 | 1, 2 | F1 |
| `hold_looted` | false | true / false | F8 |
| `adrenaline_mode` | `move_or_search` | `move_or_search`, `move_only` | F2 |
| `adrenaline_cap_per_turn` | 0 (no cap) | 0, 2 | F2 |
| `down_enabled` / `down_value` | true / 1 | on/off, 1 | F3 |
| `bounty_heal` | 1 | 0, 1 | F4 |
| `bounty_final_circle_extra` | 1 | 0, 1 | F4 |
| `bounty_holder_loses_cover` | false | true / false | F5 |
| `final_circle_hits` | [1, 2, 3] | any list | F6 |
| `zone_hard_end_card` | 14 | 12–14 | F6 (Q6 said 12; v0.2 uses 14) |
| `standard_pack` | true | true (custom start is out of scope) | F7 |
| `held_cards_public` | **false** | true / false | Q3 (spec v0.2 had them public) |
| `hits_on_top_public` | true | true / false | Q3 (Down must be known to the shooter) |
| `loadout_count_public` | true | true / false | Q3 |
| `supply_drop_cost` / `crate_cost` / `crate_free_picks` | **4** / 1 / 1 | 3–4 / 0–1 / 0–1 | spec §12; drop cost 3 → 4 per cz02 sweep, spec §16.4a |
| `supply_drop_ready_delay` | 0 | 0, 1 | cz02 alternative, spec §16.4a (switch, off) |
| `ditch_per_turn` / `min_loadout` | 1 / 6 | 1–unlimited / 6 | spec §5, §12 |
| `pile_size_outer` / `pile_size_core` | 3 / 2 | 2–4 | spec §3 (2 players) |
| `ai_think_budget_ms` | 300 | 100–1000 | plan DoD 5 |

## 5. Technical notes
- Godot 4.4.1, typed GDScript, Compatibility renderer, single-threaded web export, private artifact via `tools/package_artifact_build.sh`.
- The rules are a node-free `LoadoutRules` over a plain `MatchState`; actions replay the game exactly (no RNG anywhere, including the AI).
- Per-seat `view()` enforces private loadouts for the UI, the AI (`AiView`) and hot-seat.
- Landscape only, touch first, reference 844×390 and 667×375, no hover-only information.

## 6. Questions for the head
None block the build. Two defaults to confirm or change in review: held cards hidden from the opponent; the 14-card Zone deck from v0.2 (not 12).

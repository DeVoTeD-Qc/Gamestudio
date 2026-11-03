# CallingCard: Banner Wall Prototype Milestone Plan

*Author: Producer Agent · 2026-11-03 · Board task cc-plan · Inputs: `../DESIGN_REVIEW.md` (Decisions approved 2026-11-03), `../design/vision.md`, `../design/mechanics/banner-wall-spec.md`, `../art/style-guides/art-direction.md`, `prototype-scope.md`*
*Engine: Godot 4.4.1, GDScript, Compatibility renderer, single-threaded HTML5 export. IP: unofficial concept demo. Original names and placeholder art only; no Activision or Call of Duty assets, logos, fonts or names in the game UI beyond generic terms ("calling card", "matchmaking", "prestige"). Title screen disclaimer: "Unofficial concept demo. Not affiliated with Activision or Call of Duty."*
*Task list for the board: `prototype-tasks.json` (cc01–cc18, backlog ccb1–ccb4). Studio model: Killstreak's plan and tooling (`../../../killstreak/documentation/production/prototype-milestone-plan.md`).*

## 1. Goal
Ship a **private, internal web build** of Banner Wall that answers one question: **does making hard-earned cards stronger pieces in a side mode make players want to collect them?** (Success metrics: `../design/vision.md` §8.)

**Window:** 7 working days, **Wed 2026-11-04 → Thu 2026-11-12**. Audience: internal only (decision 9).

### Definition of done
1. A tester opens the private link and reaches the title screen in **< 10 s** on a 20 Mbps connection, with a loading screen showing progress (decision 10). Measured and recorded in `qa/performance-logs/web-load.md`.
2. **Both entry points work** (decision 4):
   - **Banner Wall menu mode:** hub → Album, Lineup, Rivals (3 AI levels), Dossiers (5), Cipher Lock.
   - **Lobby Duel:** a generic "Searching for a match…" bar runs a simulated wait (60–150 s, random per session; tunable). A quick duel starts at once with the saved lineup vs Quartermaster or Archivist. When "Match found" fires, the player chooses **Keep playing** or **Save & leave**; a saved duel resumes from the hub and survives a browser reload.
3. All rules in `banner-wall-spec.md` §4 (board, captures, 6 traits, Set Link, Signature, Triptych scoring, tie flag) and every edge case in §10 behave as specified. The rules module passes **≥ 45 headless tests**, written from QA's case list **before** the rules code.
4. The lineup builder enforces 5 cards, Clearance ≤ 12, ≤ 1 Legend and exactly 1 Signature, and offers a loaner lineup.
5. The album shows 20 cards (13 owned at start), silhouettes with unlock goals, Clearance and trait, set progress, 3 Triptych hints and the Cipher Lock. All 7 unlocks are reachable in play.
6. **Store cards are visibly weaker but flashier:** Showcase cards are Clearance 1, no trait, with the animated premium frame, and the card inspector says so in one line (decision 3).
7. **Rewards are cosmetic only** (decision 5): titles, frames and mode-exclusive cards. No "XP" or shooter reward wording anywhere.
8. The placement preview shows which cards would flip before the player confirms. Fully playable with **mouse only** and **touch only**, on desktop (1280×720 and larger) and a phone in landscape (reference 844×390). Nothing is hover-only.
9. AI-vs-AI simulation of 1,000 duels: first-player win rate **45–55%** with the default tie flag, logged in `../design/balance-log.md`. Median duel (human vs Archivist) **< 4 min** in internal play.
10. The playtest logger writes every event in section 8 to `user://playtest_log.jsonl`; the end-of-session screen offers the survey and "Download log".
11. Placeholder art only, total imported assets **< 5 MB**. Title-screen disclaimer present. IP name checklist passed.
12. QA sign-off: 0 open critical bugs, ≤ 10 minor.

## 2. Scope
**IN**
- Banner Wall duel: 10-slot 3-4-3 wall, Top/Side/Bottom captures, traits Steady, Veteran, Ambush, Reclaim, Clutch, Cipher, Set Link, Signature ×2, Triptych bonus, "Carded!" moment, coin flip, tie flag (spec §4, starting values approved, decision 7).
- 20 original cards in 4 sets plus Cipher and Showcase (spec §6); tuning in one `balance.tres` (spec §9).
- Lineup builder (cap 12, ≤ 1 Legend, Signature pick, loaner lineup).
- 3 AI rivals: Quartermaster (Easy), Archivist (Normal), Warden (Hard), each with a fixed themed lineup.
- Album with set pages, silhouettes, unlock goals, set completion titles and frames, 3 Triptychs with panorama reveal, **Cipher Lock** (decision 8), 5 Dossiers.
- Two entry points: menu hub and Lobby Duel with save and resume (decision 4).
- Local save (`user://`), cosmetic rewards only.
- Procedural placeholder art (duotone card art, Clearance frames, trait icons), OFL fonts.
- Loading screen, playtest logger, consent line and survey, private web build packaged as a claude.ai artifact (Killstreak precedent).

**OUT**: PvP (live or async), shooter gameplay, accounts, store or monetization, a stat formula over real cards, more than 20 cards, painted art, music and voice (placeholder stings only), Card Contracts (E), portrait layout, localization, native builds.
**BACKLOG** (decisions 6 and 9): ccb1 Signature Trio concept, ccb2 Bounty mode concept, ccb3 one-page pitch summary, ccb4 demo capture video.

**Cut order if the schedule slips** (cut from the top): Warden 2-ply (ship Warden as greedy + Signature safety) → Dossiers D4–D5 (move their rewards to duel goals; keep the Null Glyph unlock reachable) → Triptych panorama animation (static strip) → set-complete animated frames → Lobby Duel resume across reload (keep in-session resume). **Never cut:** rules + tests, capture preview, both entry points, album with unlock goals, Cipher Lock, touch support, logger, disclaimer.

## 3. Reuse from Killstreak (copy and adapt, do not rebuild)
Source root: `projects/killstreak/source/project-killstreak/`. Each copied file keeps a header comment "Adapted from Killstreak <file>".
| Killstreak asset | Use in CallingCard | Task |
|---|---|---|
| `project.godot` settings (Compatibility, 1280×720, canvas_items/expand), `export_presets.cfg` "Web" preset | Same settings; current CallingCard `project.godot` is still forward_plus | cc01 |
| `tests/run_tests.gd`, `tests/test_case.gd` | Headless runner and asserts, unchanged | cc01 |
| `scripts/ui/screen_profile.gd` + `autoload/settings.gd` (phone readability, fast animations, UI scale) | Unchanged screen profile; trim Settings to what we use | cc01 |
| `autoload/scene_router.gd`, `scenes/Boot.tscn` | Scene changes behind the loading screen | cc01 |
| `autoload/event_bus.gd` pattern | New signal list for the duel and album | cc01 |
| `web/shell.html` (progress bar, rotate prompt) | Retitle and recolor only | cc01 |
| `tools/package_artifact_build.sh` | Copy to `projects/callingcard/tools/`, change `PROJ` to `project-callingcard` | cc01 |
| `autoload/playtest_log.gd` (consent, rotation, Download log, privacy rules) + `scenes/survey/` | Keep the machinery; replace the SCHEMA and handlers with section 8 events | cc16 |
| `scripts/data/data_validator.gd`, `autoload/card_db.gd` | Loud validation at load; CallingCard card fields | cc02 |
| `tests/test_board_layout.gd`, `test_art_kit.gd`, `test_ai_sim.gd` patterns | Layout at 1280×720 and 844×390, art budget, AI simulation | cc07, cc14, cc06 |
| `qa/performance-logs/web-load.md` format | Load-time record | cc17 |

## 4. Day-by-day plan
| Day | Date | Mechanics Dev | UI/UX | Technical Artist | Game Feel | Mid Designer | Data Scientist | QA |
|---|---|---|---|---|---|---|---|---|
| D1 | Wed 11-04 | cc01 setup + reuse + empty web build as artifact | cc07 wall/duel layout on mock data | cc14 start: frames, trait icons, fonts | — | review cc02 field list | event list for cc16 | **cc04 rules test-case list** |
| D2 | Thu 11-05 | cc02 data schema; cc05 start (tests from cc04 first) | cc07 hand strip, inspector, phone check | cc14 procedural card art | — | cc03 cards, sets, rivals | cc16 logger adapt | cc04 finish; reviews first tests |
| D3 | Fri 11-06 | cc05 rules: board, captures, traits, scoring | cc07 finish; cc08 start on mock state | cc14 finish; budget check | — | cc03 Triptychs, Dossiers, unlock goals | cc16 survey screen | review cc05 tests |
| D4 | Mon 11-09 | cc09 Collection + save; cc06 AI start | cc08 duel flow + preview on real rules | support cc15 (frame wash shader) | cc15 placement, capture wipe | balance flags; first hot-seat notes | cc16 hooks on EventBus | rules checks on build |
| D5 | Tue 11-10 | cc06 AI + 1,000-duel sim; cc12 Dossiers | cc10 lineup builder; cc11 album start | Triptych panorama strip | cc15 "Carded!", Ambush flip, Set Link light | tune from sim (balance-log) | verify log on real build | device pass starts |
| D6 | Wed 11-11 | cc13 hub + Lobby Duel + resume | cc11 album, Triptych reveal, Cipher Lock | final asset audit, load measure | polish, fast-animation toggle | Dossier solvability check | cc18 prep: KPI sheet | **cc17** rules/device/IP pass |
| D7 | Thu 11-12 | **Feature freeze 10:00**; fixes only | fixes | RC build + package | fixes | — | **cc18** internal playtest + report | cc17 sign-off |

**Critical path:** cc04 → cc05 → cc08 → cc10 → cc13 → cc16 hooks → cc17 → cc18 (≈ 6 of 7 days). Mechanics Dev and UI/UX are both loaded; UI/UX builds on mock state and EventBus signals until cc05 lands (mid D3), so nobody waits on gameplay code.

## 5. Tasks per agent
Estimates are agent-days. IDs match `prototype-tasks.json`. **Test-first:** every logic task (cc02, cc05, cc06, cc09, cc12, cc13) adds headless tests under `tests/` in the same change; cc05 starts from QA's case list (cc04).

### mechanics-developer (5.25 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| cc01 | Project setup: copy Killstreak infrastructure | 0.75 | — | Renderer **Compatibility**, 1280×720 canvas_items/expand; folders and autoload stubs per section 6; runner, test_case, screen profile, settings, scene router, Boot, shell.html, Web preset and `tools/package_artifact_build.sh` copied and adapted (section 3); `godot --headless -s res://tests/run_tests.gd` exits 0 with a smoke test; an empty build packaged by the script loads as a private artifact on desktop Chrome and a phone browser. |
| cc02 | Card data schema, CardDB and balance file | 0.5 | cc01 | `CardData`, `SetData`, `RivalData`, `TriptychData`, `DossierData`, `UnlockGoal`, `BalanceConfig` Resources with typed `@export` fields cover spec §3, §5, §7, §9; `CardDB` loads `data/**/*.tres` and fails loudly on a missing field or a T+S+B that does not match the Clearance budget; Showcase cards must be Clearance 1 with no trait (validator rule). |
| cc05 | Rules engine `wall_rules.gd` (test-first) | 1.5 | cc02, cc04 | Node-free `RefCounted` `WallState` + `WallRules`: adjacency per §4.1, facing comparisons, all 6 traits, Set Link, Signature ×2, Triptych bonus, tie flag, chain-capture flag (off); `preview(state, card, slot)` returns the exact flips that `place()` produces; deterministic with a seed; emits EventBus signals for placement, capture, spring, carded, triptych; all cc04 cases pass (≥ 45 tests), including every §10 edge case and the §4.6 worked example. |
| cc09 | Collection, unlocks and save | 0.5 | cc03 | `Collection` autoload: owned cards, titles, frames, unlock-goal progress (win streak, captures total, beat Warden, beat Warden with no Legend, Dossier D4, Cipher Lock), set completion, saved lineup, saved Lobby Duel snapshot; persists to `user://collection.json` and survives a reload; "reset demo" for testers; rewards are cosmetic only (no XP fields). |
| cc06 | AI rivals and balance simulation | 0.75 | cc05, cc03 | Quartermaster (random legal, best capture 50%), Archivist (greedy), Warden (2-ply, values Signature safety); a Warden move takes < 200 ms on a mid-range phone; AI never sees the hidden hand order; headless sim of 1,000 Archivist-vs-Archivist duels reports first-player win rate (target 45–55%) and corner/centre opening rates into `../design/balance-log.md`. |
| cc12 | Dossier puzzles | 0.5 | cc08, cc03 | 5 Dossiers from spec §5.2 as data (fixed board, fixed hand, goal); goal checks in logic with tests; each has a known solution test; retry and hint button; rewards granted through `Collection`. |
| cc13 | Entry points: Banner Wall hub and Lobby Duel | 0.75 | cc08, cc09, cc10 | Hub (title → Lobby Duel / Banner Wall: Album, Lineup, Rivals, Dossiers); Lobby Duel shows a generic matchmaking bar with a 60–150 s simulated wait (from `balance.tres`), starts a duel with the saved lineup (loaner if none), and on "Match found" offers Keep playing / Save & leave; saved duel resumes from the hub after a reload; no franchise names or lobby look-alike; logs `lobby_*` events. |

### ui-ux-agent (4.0 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| cc07 | Wall board, hand and inspector layout | 1.5 | cc01 | Brick wall (3-4-3 offset) with empty-slot outlines, two score counters with Signature ribbons, hand of 5 (scrollable strip in compact layout), card inspector (tap or long-press; right-click on mouse) with values, trait text, Clearance, origin and "how it's earned"; anchors/containers only; Killstreak screen profile applied; tap targets ≥ 64 logical px; reads well at 1280×720 and 844×390 (layout test). |
| cc08 | Duel flow and capture preview | 1.0 | cc05, cc07 | Coin flip, alternating turns, **tap card → tap slot** (drag optional), preview arrows on every card that would flip, then confirm; ownership by tab shape as well as color; Ambush face-down state; end screen with score breakdown (Signatures, Triptych) and cosmetic rewards; a full duel vs each rival is playable mouse-only and touch-only. |
| cc10 | Lineup builder | 0.5 | cc07, cc09 | Pick 5 from owned cards with a live Clearance meter (x/12), Legend limit, Signature toggle, invalid reasons in words, loaner lineup button, locked cards shown with their unlock goal; saves to `Collection`; one tap per action on phone. |
| cc11 | Album, Triptychs and Cipher Lock | 1.0 | cc09, cc14 | One page per set, owned cards framed and silhouettes for locked ones (tap: unlock goal, Clearance, trait); set progress and earned titles; 3 Triptych slots with "???" + hint, revealed with panorama strip once scored; 4-dial Cipher Lock that unlocks Key Fragment with the right code and logs attempts; Showcase line "Premium frame · Clearance 1 · no trait" visible. |

### technical-artist (1.5 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| cc14 | Placeholder art kit | 1.5 | cc01 | `CardArt` Control drawing seeded duotone posters per set palette (art-direction §4) at 256×64 board and 1024×256 album size; frames per Clearance plus Showcase and set-complete (`StyleBoxFlat`/`NinePatchRect` + one web-safe glint shader); 6 original trait icons and 4 cipher glyphs (SVG); OFL condensed + sans fonts; `wall_theme.tres`; 3 Triptych panorama strips; nothing resembles franchise art, logos or UI; imported assets < 5 MB (art-kit test). |

### game-feel-developer (0.75 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| cc15 | Placement feedback and the "Carded!" moment | 0.75 | cc08, cc14 | Slide-in with weight drop, 0.25 s frame color wipe on capture, Ambush eye-open flash, Set Link light, ~0.8 s skippable "Carded!" crack-and-stamp, 1.5 s Triptych merge; all Tweens driven by EventBus; "fast animations" toggle from Settings; 60 FPS desktop / 30+ FPS phone. |

### mid-game-designer (1.0 d, plus tuning support on D4–D6)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| cc03 | Card, rival, Triptych and Dossier data | 1.0 | cc02 | 20 cards per spec §6 (values, set, origin, Clearance, art seed, glyph flag), 6 sets, 3 rival lineups within cap 12, 3 Triptychs, 5 Dossiers with known solutions, 7 unlock goals, Cipher code, `balance.tres` defaults per §9; every value matches the spec or a logged change in `../design/balance-log.md`. |

### data-scientist (1.75 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| cc16 | Playtest logger and survey (adapted) | 0.75 | cc01, cc13 | Killstreak `PlaytestLog` adapted: listens to EventBus only, all section 8 events as JSON lines with anonymous session id; consent line; end survey with the 4 vision §8 questions (1–5) + 1 open; "Download log" works on desktop and mobile browsers; schema test passes. |
| cc18 | Internal playtest and go/no-go report | 1.0 | cc17 | 3–5 internal sessions (including the head if available) covering both entry points; KPI sheet from logs (intent-to-collect, album pull, median duel, fairness, Lobby Duel finish rate); report in `reports/` with recommendation (iterate / extend / stop) and backlog notes. |

### qa-agent (1.5 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| cc04 | Rules test-case list (test-first) | 0.5 | — | `qa/test-plans/banner-wall-rules-cases.md`: ≥ 45 numbered cases with board setup, placement and expected flips/score, covering §4.1 adjacency (incl. b1/b4), every trait, Set Link, Clutch "behind" check, Signature and Triptych scoring, tie flag, all §10 edge cases and the §4.6 example; reviewed by the Mid Designer before cc05 starts coding. |
| cc17 | Rules, device and release check | 1.0 | cc06, cc11, cc12, cc13, cc15, cc16 | Test plan covers spec §11 and this plan's definition of done; device matrix (desktop Chrome/Firefox/Safari/Edge; Android Chrome; iOS Safari); mouse-only and touch-only passes; load time < 10 s recorded; all 7 unlocks and 5 Dossiers reachable; IP checklist (names, disclaimer, no franchise art); bugs in `qa/bug-reports/`; sign-off at 0 critical / ≤ 10 minor. |

**Total estimate: ≈ 15.75 agent-days over 7 working days** (Mechanics 5.25, UI/UX 4.0, Data Scientist 1.75, Technical Artist 1.5, QA 1.5, Mid Designer 1.0, Game Feel 0.75).

**Team change:** `project-config.json` lists only design-phase agents. This plan adds mechanics-developer, ui-ux-agent, technical-artist, game-feel-developer and qa-agent (studio `.claude/agents/`; project-customized copies in `projects/callingcard/agents/` are a lead decision).

## 6. Godot project structure (prototype)
Root: `projects/callingcard/source/project-callingcard/`
```
project.godot              # Compatibility renderer, 1280x720, canvas_items/expand, main scene = Boot.tscn
export_presets.cfg         # "Web" preset (single-threaded), custom shell res://web/shell.html
web/shell.html             # loading progress, title, rotate-device prompt (from Killstreak)
autoload/
  event_bus.gd             # EventBus: card_placed, card_captured, ambush_sprung, carded, triptych_scored, duel_ended, ...
  settings.gd              # Settings + ScreenProfile (from Killstreak)
  scene_router.gd          # SceneRouter (from Killstreak)
  card_db.gd               # CardDB: loads data/**/*.tres, validates
  collection.gd            # Collection: owned cards, unlocks, titles, lineup, saved Lobby Duel, user:// save
  playtest_log.gd          # PlaytestLog (adapted from Killstreak)
scripts/
  data/                    # card_data.gd, set_data.gd, rival_data.gd, triptych_data.gd, dossier_data.gd, unlock_goal.gd, balance_config.gd, data_validator.gd
  rules/                   # wall_state.gd, wall_rules.gd, wall_board.gd (adjacency), lineup_rules.gd, dossier_goal.gd  (RefCounted, no nodes)
  ai/                      # ai_rival.gd (easy/greedy/2-ply)
  ui/                      # screen_profile.gd (from Killstreak) + one script per scene
  art/                     # card_art.gd (procedural duotone)
scenes/
  Boot.tscn  Title.tscn  Hub.tscn  LobbyDuel.tscn  Duel.tscn  LineupBuilder.tscn  Album.tscn  Dossier.tscn  Survey.tscn
  duel/  Wall.tscn  Slot.tscn  CardView.tscn  Hand.tscn  CardInspector.tscn  CardedStamp.tscn
  album/ SetPage.tscn  TriptychSlot.tscn  CipherLock.tscn
data/
  cards/*.tres  sets/*.tres  rivals/*.tres  triptychs/*.tres  dossiers/*.tres  balance.tres
assets/ fonts/ icons/ shaders/ audio/
tests/
  run_tests.gd  test_case.gd                 # from Killstreak
  test_data.gd  test_wall_board.gd  test_wall_captures.gd  test_wall_traits.gd  test_wall_edge_cases.gd
  test_scoring.gd  test_lineup_rules.gd  test_ai_rival.gd  test_ai_sim.gd  test_collection.gd
  test_dossiers.gd  test_lobby_duel.gd  test_layout.gd  test_art_kit.gd  test_playtest_log.gd
tools/package_artifact_build.sh  (at projects/callingcard/tools/, adapted from Killstreak)
```
**Card data is `.tres`**, as in Killstreak: typed fields, validation at load, references (rival → cards, Triptych → cards), clean diffs. Rules are node-free so the AI look-ahead, the capture preview and the tests all use the same code.

## 7. Web and phone rules
**Web export (Godot 4.4.1 Web preset, from Killstreak):** Compatibility (WebGL 2); thread support **off** (no SharedArrayBuffer headers; works on iOS Safari and as an artifact); canvas resize adaptive; focus canvas on start; VRAM compression desktop + mobile; saves in `user://` (IndexedDB); PWA off; audio starts after the first tap. Hosting: private claude.ai artifact via `tools/package_artifact_build.sh` (gzip engine as `engine.gz.wasm`, pck as `game.pck.wasm`), internal link only (decision 9). Killstreak measured 6.0 s median cold load with the same template, so the 10 s target has headroom if the pck stays small.

**Phone and touch (studio rule):**
- No hover-only information: every detail has tap or long-press (400 ms) to inspect.
- Primary input is **tap card → tap slot → confirm**; drag is optional. Preview before confirm is mandatory.
- Tap targets ≥ 64 logical px; essential numbers (card values, score) ≥ 24 px logical; Killstreak `ScreenProfile` keeps one logical px ≥ 0.75 pt, compact layout below 640 logical px tall.
- 4:1 cards on the board show only the three value pips, Clearance pips and trait icon at phone size; the name and rule text live in the inspector.
- Landscape only; rotate prompt in portrait (shell). Safe-area margins; confirm button and hand in thumb reach.
- Ownership never by color alone (solid vs notched corner tab); text contrast ≥ 4.5:1.

**Risks**
| Risk | P | I | Mitigation | Owner |
|---|---|---|---|---|
| Trait interactions buggy | High | High | Test-first from cc04; preview uses the same `WallRules` code | mechanics-developer |
| First-player or centre-slot dominance | Med | Med | 1,000-duel sim on D5; tie flag and Signature value in `balance.tres` | mid-game-designer |
| Two entry points stretch UI/UX | Med | Med | Lobby Duel reuses `Duel.tscn` inside a wrapper; cut order (resume across reload last) | producer |
| 4:1 cards unreadable on phone | Med | High | Compact card face; inspector; layout test at 844×390 on D2 | ui-ux-agent |
| Mechanics Dev / UI/UX overload | Med | High | Mock state and EventBus contracts; feature freeze D7 10:00 | producer |
| Mistaken for an official product | Low | High | Disclaimer, generic terms only, IP checklist in cc17, internal link only | qa-agent |

## 8. Playtest plan
**Internal only (decision 9), D7, part of this milestone (cc18):** 3–5 sessions of ~12 min (the spec §8 walkthrough), at least 1 on a phone; at least 2 testers start from the Lobby Duel and 2 from the menu. Brief: "Play until you have unlocked one card, then try the Lobby Duel (or the reverse), then fill in the survey and press Download log."

**Pass bar (vision §8):** intent-to-collect ≥ 70% at 4+; ≥ 50% open the album at least twice and inspect a locked card; median duel < 4 min; tutorial Dossier D1 cleared < 3 min; fairness ≥ 70% at 4+; load < 10 s in every session. With 3–5 testers these are directional only; the report says so and recommends whether an external round is worth it.

**Logged events** (`user://playtest_log.jsonl`):
`session_start(load_ms, input_type, viewport, browser)`, `entry_point(lobby|menu)`, `album_open(page)`, `card_inspect(card_id, owned)`, `lineup_saved(card_ids, clearance, signature_id, loaner)`, `duel_start(source: lobby|rival|dossier, rival, first_player)`, `placement(card_id, slot, captures, preview_shown)`, `carded(by)`, `triptych_scored(id, first_time)`, `duel_end(result, score_p, score_ai, turns, duration_s)`, `lobby_wait_start(wait_s)`, `lobby_match_found(duel_state, choice: keep|save)`, `duel_resumed(age_s)`, `unlock(card_id|title|frame)`, `set_complete(set_id)`, `cipher_attempt(correct)`, `dossier_start(id)`, `dossier_clear(id, attempts, duration_s)`, `survey(answers)`, `quit(screen)`.

# Killstreak — Web Prototype Milestone Plan

> **Update 2026-11-03 (user decision):** the prototype run is **5 matches (~20–30 min, 3 tickets)**, not 7. This is a data-only change in `run_config.tres`; where this plan says 7 matches, read 5 (Bracket 1 ×2, Bracket 2 ×2, Rival). Trademark: the user will get a professional check. Hosting: private itch.io page approved; the user will recruit 8–15 testers. Devices: a real iPhone and Android phone are available. Content picks and cut order: approved.


*Author: Producer Agent · 2026-11-03 · Board task t16 · Inputs: `../DESIGN_REVIEW.md` (Decisions approved 2026-11-03), `../design/core-rules.md`, `../design/vision.md`, `producer-scope-review.md`, `../art/style-guides/art-direction.md`, `playtest-metrics-plan.md`*
*Engine: Godot 4.4.1, GDScript, HTML5 export. IP: original setting only. No Call of Duty names, characters, maps, modes, HUD or logos. Working title "Killstreak"; user's preferred candidate "Deckstreak" (pending trademark check, no renames).*
*Task list for the board: `prototype-tasks.json` (p01–p20).*

## 1. Goal
Ship a **private, playable web build** of one complete roguelite run that answers the four playtest questions in `playtest-metrics-plan.md`: do shooter players get it, does it feel like a shooter, is there depth, and does "one more match" happen.

**Window:** 7 working days, **Wed 2026-11-04 → Thu 2026-11-12**. External playtest round 1 follows (2026-11-13 → 11-18) and is not part of this milestone.

### Definition of done
1. A tester opens the private itch.io link and reaches the title screen in **< 10 s** on a 20 Mbps connection, with a loading screen showing progress (decision 10).
2. One full **run of 7 matches** (Bracket 1 ×3, Bracket 2 ×3, Rival) with **3 tickets** is playable start to finish in both modes, **Zone Control** and **Firefight**, on map Port Vasel. Median run length measured in internal play is **30–45 min** (decision 7).
3. All rules in `core-rules.md` §1–4 that are in scope (section 2) behave as specified; the firefight resolver passes its automated test suite (≥ 40 cases, including all §9 edge cases).
4. **Streak resets only when the player's Operator goes down**, after that round's eliminations are counted (decision 2); verified by tests.
5. Red-dot counts match the AI's committed deployments 100% of the time; the outcome preview matches the actual firefight result whenever no hidden information changes it.
6. The game is fully playable with **mouse only** and with **touch only**, on desktop (1280×720 and larger) and on a phone in landscape (reference 844×390). No information is hover-only (decision 9).
7. The scripted tutorial match teaches deploy → firefight → streak → Recon Drone call-in, and can be skipped.
8. The playtest logger writes every event in section 8 to `user://playtest_log.jsonl`, and the end-of-session screen offers the survey and a "Download log" button.
9. Placeholder art only, in the final layout (decision 8); total imported assets **< 5 MB**.
10. QA sign-off: 0 open critical bugs, ≤ 10 minor; IP name checklist passed.

## 2. Scope
**IN**
- Map: Port Vasel (Left "Container Stacks" Close · Mid "Crane Yard" Long · Right "Loading Offices" Mid).
- Modes: Zone Control, Firefight (overtime rules included).
- Full round loop: Briefing / Deploy / Reveal / Firefight / Score; Operator down and respawn; simultaneous reveal; initiative.
- Cards: 20 starter designs + 6 reward cards (`core-rules.md` §5). 7 keywords, On Deploy / On Down triggers.
- Loadout: Kestrel AR-7 with 4 attachments (Extended Mag, Foregrip, Holo Sight, Ceramic Lining); P-12 Sidearm; Frag Grenade; Flashbang.
- Perks (4): Streak Discipline, Field Salvage, Grit, Objective Focus.
- Killstreaks (4): Recon Drone, Mortar Barrage, Sentry Turret, Attack Helo. Player picks 3 at run start (default: Recon / Mortar / Helo).
- AI: 2 personalities (Rusher, Anchor); 3 enemy squads (Rusher squad, Anchor squad, Rival BLACK MERIDIAN squad = Anchor + elites). Bracket 2 reuses squads at higher stats.
- Run: 7 matches, 3 tickets, Supply Drop (pick 1 of 3) after each win, weapon level after matches 1, 3, 5 (choose 1 of 2 attachments), Perk offer after matches 2 and 4, After-Action screen.
- UX: scripted tutorial, outcome preview, card inspector, killfeed, hit markers, XP pop-ups, segmented streak arc, killstreak call-in takeover, radio-bark text lines.
- Input and layout: mouse + touch, scales to phone landscape.
- Loading screen; playtest logger, pre-survey and end survey.
- Godot 4.4.1 single-threaded web export on a private itch.io page.

**OUT** (post-prototype): Detonator mode, other Primaries (Wasp-9, Longreach), Gunship, Secondary/Lethal/Tactical alternatives (Breaching Charge, Smoke), Armory shop and card upgrades, meta-progression / Player Rank / Threat Levels, second map, painted art, voice audio and music beyond a placeholder loop, any PvP, portrait layout, native Steam or mobile builds, store integration, monetization, server-side logging.

**Cut order if the schedule slips** (cut from the top): Perk offers → Sentry Turret → Attack Helo (keep 2 killstreaks + Recon) → Bracket 2 stat scaling (reuse squads as-is) → tutorial reduced to text prompts over a normal match. Never cut: streak/Operator loop, red dots, outcome preview, touch support, logger.

## 3. Day-by-day plan
| Day | Date | Mechanics Dev | UI/UX | Game Feel | Technical Artist | Mid Designer | Data Scientist | QA |
|---|---|---|---|---|---|---|---|---|
| D1 | Wed 11-04 | p01 project + web pipeline; p02 data schema | p08 board/HUD layout (mock data) | — | p13 themes, fonts, icon sheet | p03 start (after schema, PM) | p16 event schema | test plan from core-rules |
| D2 | Thu 11-05 | p04 rules engine (round loop, resolver) | p08 finish; touch/phone check | — | p13 finish; card frames | p03 finish: all cards, loadout, squads | p16 survey screens spec | resolver test cases list |
| D3 | Fri 11-06 | p04 finish + tests; p06 modes & scoring | p09 hand, inspector, deploy | p14 start on mock EventBus signals | p17 loading screen; first web build measured | tutorial script for p15 | p16 logger autoload | review p04 tests |
| D4 | Mon 11-09 | p05 streaks, killstreaks, abilities, respawn | p12 outcome preview | p14 killfeed, hit markers, streak arc | p17 size budget, mobile browser check | AI weights per squad | p16 hook events | rules checks on build |
| D5 | Tue 11-10 | p07 AI + red dots | p11 run screens (mock run state) | p14 call-in takeover, XP pop-ups | support p14 (scanline shader, light) | first balance notes from hot-seat AI | analysis sheet template | p18 starts: rules pass |
| D6 | Wed 11-11 | p10 run flow; bug fixes | p11 finish; p15 tutorial | polish + fixes | final asset audit | p19 balance pass | verify log on real build | p18 device pass |
| D7 | Thu 11-12 | **Feature freeze 10:00**; fixes only | fixes | fixes | build + upload RC | p19 finish | p20 internal playtest + report | p18 sign-off |

Critical path: p01 → p02 → p04 → p05 → p07 → p10 → p18 (≈ 6 days of Mechanics Dev work). The Mechanics Developer is the bottleneck; everyone else builds against EventBus signals and mock data so they never wait on gameplay code.

## 4. Tasks per agent
Estimates are agent-days. IDs match `prototype-tasks.json`.

### mechanics-developer (5.75 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| p01 | Project setup & web pipeline | 0.5 | — | Renderer switched to **Compatibility** (the current `project.godot` says forward_plus); folders and autoload stubs per section 5; Web export preset (single-threaded); an empty build loads on the private itch.io page in desktop Chrome, Firefox, Safari and a phone browser. |
| p02 | Card & loadout data schema | 0.5 | p01 | `CardData`, `LoadoutItem`, `SquadData`, `RunConfig` Resources with typed `@export` fields cover every field in `core-rules.md` §3–5; `CardDB` autoload loads all `.tres` files and fails loudly on a missing or invalid field. |
| p04 | Rules engine: round loop & firefight | 1.5 | p02 | Pure GDScript (`RefCounted`, no nodes) `MatchState` + `FirefightResolver`; deterministic; initiative, line order, point man, Pick/Flank, Cover, Suppress, Patch, Holder, persistent damage, zone capacity 4, hand cap 7; ≥ 40 headless tests pass including all §9 edge cases; emits EventBus signals for every reveal, shot, damage and elimination. |
| p05 | Streaks, killstreaks, abilities, respawn | 1.0 | p04 | Streak +1 per qualifying elimination; killstreak eliminations don't count; Operator down resets after the round's count; trays keep earned killstreaks; once per life; Sidearm, Frag, Flashbang with cooldowns; 4 killstreaks and 4 Perks behave per spec; tests for each. |
| p06 | Game modes & scoring | 0.5 | p04 | Zone Control (first to 6) and Firefight (first to 7) with round-8 cap, overtime, draw after round 10 (no ticket lost); mode is data (`RunConfig`), not code branches. |
| p07 | Enemy AI & red-dot intel | 1.0 | p05, p06, p03 | AI commits its plan before the player deploys and never reads hidden player cards; scoring formula from §7 with weights in data; Rusher and Anchor personalities visibly differ; red dots equal committed units 100% (test); a turn takes < 200 ms on a mid-range phone. |
| p10 | Run flow | 0.75 | p06, p03 | `RunState` autoload drives 7 matches, 3 tickets, rewards, weapon levels after matches 1/3/5, Perk offers after 2/4, run end on win or 0 tickets; run state survives a browser reload (`user://run_save.json`). |

### ui-ux-agent (4.25 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| p08 | Board & HUD layout (mouse + touch) | 1.0 | p01 | 3 lanes with range badges and control state, minimap red-dot strip, score bar "RD 3/8", Supply pips, READY, Operator panel with Perk slots, killfeed area; anchors/containers only (no hard-coded positions); readable at 1280×720 and 844×390. |
| p09 | Hand, card inspector & deploying | 1.0 | p08, p04 | Deploy by **drag** or **tap card → tap lane**; long-press (touch) or right-click/hover (mouse) opens the card inspector with keyword explanations; full lanes grey out; Rotate and abilities reachable by tap; undo before READY. |
| p12 | Outcome preview | 0.5 | p04, p09 | Toggleable overlay shows predicted damage, eliminations and control per lane using the real resolver on visible information; matches actual results in QA's scripted cases. |
| p11 | Run & reward screens | 1.0 | p10, p09 | Loadout pick (3 killstreaks), run map with tickets, Supply Drop pick 1 of 3, attachment choice, Perk offer, After-Action, run end; every choice is one tap; works on phone. |
| p15 | Tutorial match | 0.75 | p03, p07, p09 | Plays the Mid Designer's script with a scripted squad; steps: deploy → firefight → streak → Recon Drone; skippable; logs `tutorial_step`; a new tester finishes it in ≤ 5 min. |

### game-feel-developer (1.0 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| p14 | Combat feedback & streak juice | 1.0 | p05, p08, p13 | Tracers (60 ms stagger), hit marker + damage number, 2–4 px shake on elimination, ELIMINATED stamp, killfeed lines fading after 4 s, segmented streak arc with cyan notches and shatter on reset, 0.8 s killstreak takeover, XP pop-ups, radio-bark text; all Tweens, ≤ 64 sprites; a "fast animations" toggle; holds 60 FPS desktop / 30+ FPS phone. |

### technical-artist (1.5 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| p13 | Placeholder art kit & themes | 1.0 | p01 | `hud_theme.tres`, `card_theme.tres`; Barlow, Barlow Condensed, Share Tech Mono (OFL) embedded; one original icon sheet (classes, keywords, killstreaks); flat placeholder frames for unit/tactic/equipment/killstreak/Operator cards; friend/enemy shape cues (chevron vs hazard stripe); nothing resembles a franchise HUD or logo. |
| p17 | Loading screen & web size budget | 0.5 | p01, p13 | Custom HTML shell or boot scene with progress and the title; total assets < 5 MB; measured cold load < 10 s on throttled 20 Mbps (Chrome DevTools) and recorded in `qa/performance-logs/`; texture import settings correct for desktop and mobile browsers. |

### mid-game-designer (2.0 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| p03 | Card, loadout & squad data | 1.0 | p02 | All 26 cards, loadout items, 4 Perks, 4 killstreaks, 3 squads (15–20 cards each, personality, AI weights) and `run_config.tres` authored as `.tres`; every value matches `core-rules.md` or a logged change; tutorial script and scripted squad written for p15. |
| p19 | Balance pass | 1.0 | p07, p10, p16 | ≥ 10 internal matches per mode logged; win rates trending toward ~75% / ~55% / ~40% (B1/B2/Rival); median unspent Supply ≤ 1; no reward card above 60% or below 5% pick rate in internal play; changes recorded in `documentation/design/balance-log.md`. |

### data-scientist (1.75 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| p16 | Playtest logger & surveys | 0.75 | p01 (schema), p10 (hooks) | `PlaytestLog` autoload listens to EventBus only (no gameplay code calls it directly); all section 8 events written as JSON lines with an anonymous session ID; consent line; pre-survey (3 taps) and end survey (5 + 1 open); "Download log" works in desktop and mobile browsers. |
| p20 | Internal playtest & report | 1.0 | p18, p19 | 3–5 internal sessions (including the user if available); KPI sheet filled from logs; short report with go/no-go for external round 1 and the tester brief. |

### qa-agent (1.5 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| p18 | Rules, device & release check | 1.5 | p04–p17 | Test plan covers every in-scope rule and §9 edge case; device matrix pass (desktop Chrome/Firefox/Safari/Edge; Android Chrome; iOS Safari); input pass (mouse-only, touch-only); load-time check; IP name checklist; bugs filed in `qa/bug-reports/`; sign-off at 0 critical / ≤ 10 minor. |

**Total estimate: ≈ 17.75 agent-days over 7 working days** (Mechanics 5.75, UI/UX 4.25, Mid Designer 2.0, Data Scientist 1.75, Technical Artist 1.5, QA 1.5, Game Feel 1.0).

## 5. Godot project structure (prototype)
Root: `projects/killstreak/source/project-killstreak/`
```
project.godot              # Compatibility renderer, main scene = Boot.tscn
export_presets.cfg         # "Web" preset
autoload/
  event_bus.gd             # EventBus: all gameplay signals (card_revealed, shot_fired, unit_eliminated, streak_changed, ...)
  card_db.gd               # CardDB: loads data/**/*.tres, lookups by id
  run_state.gd             # RunState: current run, tickets, deck, loadout, save/load
  playtest_log.gd          # PlaytestLog: listens to EventBus, writes user://playtest_log.jsonl
  scene_router.gd          # SceneRouter: scene changes behind the loading screen
  settings.gd              # Settings: fast animations, UI scale, sound
scripts/
  data/                    # card_data.gd, loadout_item.gd, squad_data.gd, run_config.gd (class_name Resources)
  rules/                   # match_state.gd, firefight_resolver.gd, streak_tracker.gd, mode_rules.gd (RefCounted, no nodes)
  ai/                      # ai_player.gd, ai_personality.gd
  ui/                      # one script per scene below
scenes/
  Boot.tscn  Title.tscn  LoadoutSelect.tscn  RunMap.tscn  Match.tscn
  RewardPick.tscn  AfterAction.tscn  RunEnd.tscn  Survey.tscn
  match/  Board.tscn  Lane.tscn  CardView.tscn  Hand.tscn  CardInspector.tscn  Killfeed.tscn  StreakArc.tscn  OutcomePreview.tscn
data/
  cards/*.tres  loadout/*.tres  squads/*.tres  run_config.tres  tutorial_script.tres
assets/ fonts/ ui/ sprites/ audio/   # placeholder kit (p13)
tests/
  run_tests.gd             # headless runner: godot --headless -s tests/run_tests.gd
  test_firefight.gd  test_streak.gd  test_modes.gd  test_ai_intel.gd
```
**Card data format: `.tres` Resources** (not JSON). Reasons: typed fields with inspector editing for the Mid Designer, validation at load, references between resources (squad → cards), and they are text files that diff cleanly. If an external balance spreadsheet becomes useful, add a CSV → `.tres` import script later.

Rules live in node-free `RefCounted` classes so they are unit-testable headless, reusable by the AI for look-ahead and the outcome preview, and ready for PvP later (same code for both sides). Scenes only render state and send player intents.

## 6. Web export settings & risks
**Settings (Godot 4.4.1 Web preset)**
- Renderer: Compatibility (WebGL 2). **Thread support off** (single-threaded build: no SharedArrayBuffer / cross-origin isolation headers needed, works on itch.io and iOS Safari).
- Window: base viewport 1280×720, stretch mode `canvas_items`, aspect `expand`; landscape. Canvas resize policy: adaptive. Focus canvas on start.
- VRAM texture compression: enable both desktop (S3TC/BPTC) and mobile (ETC2/ASTC) formats, or use lossless for the small UI atlas; measure size.
- Input: keep "emulate mouse from touch" on for menus, but deployment code handles touch and drag explicitly; long-press threshold 400 ms.
- Audio: start the audio bus only after the first tap/click (browser autoplay rules).
- Saves: `user://` (IndexedDB). PWA off for the prototype.
- Custom HTML shell: loading progress bar, title, "best on desktop or phone in landscape" hint, rotate-device prompt in portrait.

**Phone & touch implications (decision 9)**
- No hover-only information: every tooltip has a long-press / tap-to-inspect equivalent.
- Tap targets ≥ 64×64 logical px at 1280×720 base (≈ 9 mm on a phone at the 0.54 scale of an 844×390 screen).
- At phone scale the 14 px body text is too small, so cards in hand show a compact face (cost, FP, Armor, keyword icons) and full text lives in the inspector; essential HUD numbers ≥ 24 px logical.
- Safe-area margins for notches; READY and the hand stay in thumb reach (bottom corners).
- Layout built with containers and anchors only, so Steam (16:9/16:10, larger screens) and a later mobile build reuse it. Portrait layout is out of scope.
- Later (not now): monetization planning will differ by store (premium on Steam; mobile model TBD).

**Risks**
| Risk | P | I | Mitigation | Owner |
|---|---|---|---|---|
| Engine download dominates load time (the Godot web runtime is the largest file) | High | Med | Single-threaded template, compressed delivery, assets < 5 MB, loading screen; measure on D3, not D7 | technical-artist |
| iOS Safari quirks (audio unlock, memory, WebGL 2 differences) | Med | Med | Test on a real iPhone by D4; keep shaders minimal | qa-agent |
| Touch deployment feels fiddly on a phone | Med | High | Tap-tap as the primary method, drag optional; test on phone at end of D3 | ui-ux-agent |
| Mechanics Dev overload (critical path ≈ 6 of 7 days) | High | High | Others work against EventBus + mocks; cut order in section 2; feature freeze D7 10:00 | producer |
| Run length misses 30–45 min | Med | Med | Log `run_end.duration_s`; tune via matches per bracket in `run_config.tres` (data only) | mid-game-designer |
| Firefight rules confusing | Med | High | Outcome preview + tutorial; test Shooter segment first | ui-ux-agent |
| IP/trademark | Med | High | Name checklist in p18; no public link until the title check is done | producer |

## 7. Playtest plan
**Internal (D6–D7, part of this milestone):** QA scripted rule checks; 3–5 full sessions by agents' scripted play and the user; logs and survey collected; balance pass p19; go/no-go report p20.

**External round 1 (2026-11-13 → 11-18, next milestone):**
- **Testers:** 8–15, recruited by the user; aim for ≥ 4 Shooter-segment and ≥ 4 Card-segment players; at least 3 sessions on phones.
- **Brief:** private itch.io link + password, "play one run, then fill in the survey and press Download log", ~45–60 min.
- **Measure:** all KPIs in `playtest-metrics-plan.md`, plus load time, input type (touch/mouse), device class and run duration (to validate 30–45 min).
- **Pass bar:** Shooter segment ≥ 4 on Q1 & Q2; Card segment ≥ 4 on Q3; Q5 ≥ 4 overall; load < 10 s for ≥ 90% of sessions; touch sessions finish a match at the same rate as mouse sessions.
- **Output:** results sheet + 1-page readout with a recommendation (proceed to production / iterate prototype).

## 8. Logged events
From `playtest-metrics-plan.md`, with additions for this milestone in bold:
`session_start(`**`load_ms, input_type, viewport, browser`**`)`, `tutorial_step(step)`, `match_start(mode, map, threat)`, `round_end(round, score, streak, supply_unspent, hand_size)`, `card_played(card_id, zone, round)`, `elimination(by, victim, zone)`, `operator_down(round)`, `killstreak_earned(id, round)`, `killstreak_used(id, round)`, `match_end(result, rounds, duration_s)`, `reward_pick(offered[], chosen)`, **`attachment_pick(offered[], chosen)`, `perk_pick(offered[], chosen)`, `preview_toggled(on)`**, `run_end(result, matches, `**`duration_s`**`)`, `next_match_clicked(seconds_after_end)`, `quit(screen)`.

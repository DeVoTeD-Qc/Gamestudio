# CardZone: Loadout Loop 1v1 Web Prototype Milestone Plan

*Author: Producer Agent · 2026-11-04 · Board task `cz-plan` (from `cz-q`) · Phase: plan*
*Inputs: `../DESIGN_REVIEW.md` (incl. v0.2 follow-ups F1–F8), `../design/mechanics/loadout-loop-spec.md` (v0.2), `../design/mechanics/loadout-loop-sims.md`, `../design/concepts.md`, `../research/market-scan.md`, `../../tools/loadout_sim.py`, the studio head's answers on `cz-q`.*
*Engine: Godot 4.4.1, typed GDScript, **Compatibility** renderer, single-threaded HTML5 export. All names, cards, map and rules are original; gear uses generic military terms.*
*Task list for the board: `prototype-tasks.json` (cz01–cz21, backlog czb1–czb7). Scope summary: `prototype-scope.md`. Studio model: CallingCard's plan and tooling (`../../../callingcard/documentation/production/prototype-milestone-plan.md`).*

## 0. Market check and decisions this plan builds on
Market verdict: **GO** (`research/market-scan.md`). The gap is a deterministic battle-royale deckbuilder that plays the same on the web and on a table. The market-driven requirements for this milestone: show that a no-shuffle loop can feel tense (the "your next hand is your armour" hook), keep turns short (AP is the genre's top complaint for perfect-information games), and avoid feel-bad elimination. Nothing in this build makes an external originality claim (market-scan risk; prior-art check is backlog czb7).

| Head's decision (`cz-q`) | What this plan does with it |
|---|---|
| Q1 concept A, "investigate the others later" | Build A. Concepts B, C, D are backlog (czb1–czb3). |
| Q2 last player standing, "test 1v1 only first" | Last standing, 1v1. Placement points only come with 3–4 players (czb4). |
| Q3 loadouts **Private** ("open slows down gameplay") | New info model, section 3. Opponents can't browse your loadout. You always see your own. |
| Q4 areas + supply drops + crates | All three in. In 1v1 a crate is the end of the game, so crates are built and tested but rarely seen (noted in section 3). |
| Q5 2–4 + solo eventually, prototype 1v1 | 1v1 only. 3–4 players and solo are backlog (czb4, czb5). |
| Q6 health 5, 7 areas, 12-card Zone deck, "maybe a 5-card hand" | Hand size is a tunable (4 or 5), **default 5**, backed by a sim re-check (section 2). Zone deck: see the note under section 3. |
| Q7 5 rarity tiers | C/U/R/E/L with colour **and** letter (spec §6). |
| Q8 grounded near-future fictional island | Art direction one-pager (cz15) before the art kit (cz16). |
| Q9 straight to the web prototype | No paper phase. The web build carries the paper-test gates (pack time, earliest elimination, comeback) as playtest KPIs (section 8). |
| Q10 keep Shrinking Ring in the backlog | czb2. |
| Spec v0.2 applies; F1–F8 use the defaults and become tunables | All eight are keys in `balance.tres` (section 3, `prototype-scope.md` §4). Board task `cz-spec2` is still in review; if the head changes a default there, it is a data change, not a re-plan. |

## 1. Goal
Ship a **private web build of Loadout Loop that the head can play alone on an iPhone in landscape, 1v1 against an AI**, and answer one question:

> **Is the Loadout Loop fun and fast in a 1v1 duel: does "your next hand is your armour" create real choices, without packing paralysis or a shot snowball?**

**Window:** 8 working days, **Thu 2026-11-05 → Mon 2026-11-16** (cz01, cz03 and cz15 can start today, Wed 11-04). Audience: the studio head plus 2–4 internal testers.

### Opponent: AI first, hot-seat as a cheap extra
| Option | For | Against | Verdict |
|---|---|---|---|
| **AI opponent** | The head plays alone on a phone, so this is the only way he plays at all. A deterministic AI also gives us a headless AI-vs-AI balance harness for the F1–F8 knobs and the hand size. | Most expensive item after the rules engine. Must respect private loadouts. | **IN, must-have.** Two levels: Rookie and Veteran (cz09). |
| **Hot-seat (pass the phone)** | Almost free once the engine is seat-agnostic: the same screens for both seats. Lets the head show the game to someone in the room, and gives QA a human-vs-human path. | With private loadouts, every seat change needs a "pass the device" cover screen, and the Brace prompt must cover the screen for the defender. Two people on a 6-inch phone is cramped. | **IN, small (cz14), first item on the cut list.** |
| Async online | The real target for 2–4 players later. | Needs a backend, accounts, notifications. | **OUT** (backlog with 3–4 players). |

### Definition of done
1. The head opens the private link on his iPhone (Safari, landscape) and reaches the title screen in **< 10 s** on Wi-Fi, with a loading screen showing progress. Measured in `qa/performance-logs/web-load.md`.
2. **A full 1v1 match vs the AI is playable touch-only on a phone in landscape** (reference 844×390 and 667×375, safe areas respected) and mouse-only on desktop (1280×720+). Nothing is hover-only.
3. Every rule in spec v0.2 §4–§9 and §11 for 2 players works as specified, with the section 3 private-loadout model. The rules module passes **≥ 70 headless tests**, written from QA's case list (cz04) **before** the rules code, including the spec §7 worked example.
4. **Every F1–F8 default, the hand size and the info-model switches are keys in `data/balance.tres`.** Changing one needs no code change, and a test proves each switch changes the behaviour.
5. **AI:** Rookie and Veteran, deterministic (same state → same move, no RNG), read only public information plus their own cards through an `AiView` (test-checked), and finish a turn in **< 300 ms on an iPhone 12-class phone**. The Brace choice for the AI is instant.
6. **AI-vs-AI headless sim** of every drop pair × route A/B/C × hand 4 and 5 (216 games per setting, all deterministic): first-player win rate **45–55%**, games where both players fall to the final circle together **< 10%**, median last round **9–12**, logged in `../design/balance-log.md`.
7. Packing is the spec's Hold and Stow: a Hold toggle on each unplayed card (max = `hold_limit`), and **End turn** stows the line in play order. No reordering UI exists.
8. **Shooting:** before you fire, a preview shows damage after Cover and Down, and "up to N Hits; they may Brace". When the AI shoots you, a **Brace prompt** shows your next hand with Brace shields, a suggested brace and the resulting Hits before you confirm.
9. **Save and resume:** the match is saved after every action as setup + move list. Closing Safari, reloading or a phone lock never loses a match (tested by replaying saved move lists).
10. **Hot-seat** works with a cover screen at each seat change and for the defender's Brace prompt (unless cut, see section 2).
11. The playtest logger writes every event in section 8 to `user://playtest_log.jsonl` (opt-in), and the end-of-session screen offers the survey and **Download log**. `tools/kpi_sheet.py` turns the downloads into the KPI sheet.
12. Placeholder art only, imported assets **< 5 MB**. 5 rarity tiers readable without colour (letters). First-match coach (skippable) explains Hold, Brace, Down and Adrenaline.
13. QA sign-off: 0 open critical bugs, ≤ 10 minor. The RC is published as a private artifact and its link is on the board (`projects/cardzone.playUrl`).

## 2. Hand size re-check (Q6): default 5
I added a `--hand N` option to `tools/loadout_sim.py` (default 4, so every existing table is unchanged; verified by diffing the output) and ran the v0.2 bots 1v1 on **all 36 drop pairs** (route A), with and without the scripted round-2 ambush (Ben takes 2 Hits).

| 1v1, v0.2 defaults, route A, 36 games each | Hand 4 | Hand 5 |
|---|---|---|
| Even start: first player / second player wins | 14 / 8 | 19 / 16 |
| Even start: **both eliminated together by the final circle** (no winner by play; the sim doesn't apply the card-count tiebreak) | **14 of 36** | **1 of 36** |
| Even start: median last round (range) | 12 (7–14) | 10 (6–14) |
| Even start: earliest elimination | round 7 | round 6 |
| Ambush start: ambushed player wins | 13 of 36 | 19 of 36 |
| Ambush start: median last round | 12 | 8 |
| Fewest usable cards in any turn | 4 | 5 |

**Reading:** a 5-card hand gears both players faster, so duels are **decided by fighting rather than by the zone** (hand 4: 39% of even duels ended with both players dying in the final circle) and are about 2 rounds shorter, which suits a phone session. Comeback holds: the ambushed player wins about half the time. The first-player edge among decided games drops from 64% to 54%. Costs to watch: the "nobody eliminated before round 6" gate is met but only just (round 6), a 10-card loadout now loops in exactly 2 turns, and Brace windows are 5 cards deep (more armour). The bots are greedy and dumb (sims doc, "Limits"), so this is direction only: **default 5, tunable 4/5**, and the cz09 AI-vs-AI sim and the playtest decide. Re-run: `python3 tools/loadout_sim.py --hand 5` (cz02 adds routes B/C and the 36-pair sweep to the tool and the balance log).

## 3. Rules for this prototype (deltas from spec v0.2)
The Sr Game Designer writes these into the spec as **§16 Prototype rules (1v1, private loadouts)** in cz01. The defaults below are the producer's proposal for that task.

**Private loadouts (Q3): what each player sees.** The hook survives: your own next hand is always known to you, so Brace and Hold planning work exactly as in v0.2. What changes is that the shooter no longer knows your armour.
| Information | Owner | Opponent | Tunable (default) | Physical-table equivalent |
|---|---|---|---|---|
| Whole loadout order and contents | Yes, any time | No | – | Loadout face down; you may look through your own |
| Held cards | Yes | **No** (they sit face down on top) | `held_cards_public` (**false**; spec v0.2 had them face up) | Held cards face down on top |
| Hits in your next draw (count) | Yes | **Yes: the Down badge** | `hits_on_top_public` (**true**) | Hits are face up on top of the stack |
| Loadout size (card count) | Yes | Yes | `loadout_count_public` (**true**) | Visible stack height |
| Health stack | Yes | Yes | – | Face-up Hit stack |
| Cards played or looted this turn (the line) | Yes | Yes | – | Played face up |
| Brace cards used against a shot | Yes | Yes (revealed when used) | – | Revealed |
| Bounty holder, pawns, gas, piles, Zone deck | Yes | Yes | – | Public |

- **Why Down stays public:** the shooter needs it to know the damage, and it is physically true (Hits sit face up). It also tells the shooter "they're hurt", which is fair.
- **What the shooter now decides blind:** how much the target can Brace. That's hidden information, **not randomness** (it follows from cards the target chose to hold), and it adds a read-the-opponent layer. Players can still remember what you looted, so the AI may remember it too (perfect memory of public events is allowed, never peeking).
- **Design question for cz01 (not blocking the head):** does hiding held cards make Hold too strong, or shots feel like guesses? Default: hidden. The playtest measures shots that were fully braced (section 8), and `held_cards_public` flips it back without code.

**Other prototype rules**
- **1v1:** outer piles 3 cards, Core piles 2 (spec §3 two-player values). The first player is chosen at setup (vs AI: the human picks or alternates each match). The second player chooses the route; drops in reverse turn order (the AI's drop rule is deterministic and listed in cz09).
- **Bounty in 1v1:** goes to the strictly healthier player, so the trailing player always heals 1 when landing a Hit on the leader. Kept as specified (sims rely on it).
- **Crates in 1v1:** an elimination ends the game, so a crate never matters unless both are in the final circle. Implemented and tested (cheap, needed for 3–4 players), not featured.
- **Standard pack (F7):** both players start in the Standard pack order. With hand 5 the first two hands are *Scavenge ×3, Duck, Dash* and *Dash, P-9, Scavenge, Duck, Dash*. cz01 confirms or adjusts this order for hand 5. A custom starting order is out of scope (`allow_custom_start`, false).
- **Zone deck (Q6 vs F6):** Q6 approved "a 12-card Zone deck", but that was the v0.1 deck. Spec v0.2 (which the head approved, with F6's default) uses 14 cards with the escalating 1/2/3 final circle and a hard end after card 14. This plan uses **v0.2's 14 cards**, and `final_circle_hits` / `zone_hard_end_card` are tunables. This is a note for the head's review, not a blocker.
- **Undo:** free within a turn until a shot resolves or a card is looted (both reveal or change shared state). Hold toggles can be changed until End turn.
- **No turn timer** vs the AI. Hot-seat: none either.

## 4. Scope (summary; full list in `prototype-scope.md`)
**IN:** the full v0.2 1v1 rules on Ridge Hollow with routes A/B/C, all 27 player cards + Bounty, Hold and Stow, Adrenaline, Down, Bounty, the escalating final circle, private loadouts; AI Rookie and Veteran; hot-seat; Brace prompt and shot preview; save and resume; first-match coach; placeholder art kit; core feel moments; playtest logger, survey and KPI sheet; private web build.
**OUT:** 3–4 players, placement points, solo Raiders, online/async play, accounts, custom starting order, a deck/pack reordering UI, print-and-play files, painted art, music and voice (placeholder sfx only), localization, native builds, any external claim of originality.
**BACKLOG:** czb1 concept B Reload, czb2 concept C Shrinking Ring map variant, czb3 concept D Supply Line, czb4 3–4 players (multi-AI, placement points, F5 camper check), czb5 solo mode, czb6 print-and-play sheet, czb7 prior-art check.

**Cut order if the schedule slips** (cut from the top): hot-seat (cz14) → Veteran's look-ahead (ship Veteran as Rookie + threat-aware hold and positioning) → route B/C selection in the UI (keep A; the data stays) → secondary feel moments (supply-drop landing, gas sweep; keep shot/Brace/Hit) → coach overlay (replace with a one-page "How to play" card). **Never cut:** rules + tests, every tunable, private info model + AiView, Brace prompt, shot preview, save/resume, touch support at 844×390, logger, Rookie AI.

## 5. Reuse (copy and adapt, do not rebuild)
Each copied file keeps a header line "Adapted from CallingCard <path>" or "Adapted from Killstreak <path>".
CallingCard root: `projects/callingcard/source/project-callingcard/` (CC). Killstreak root: `projects/killstreak/source/project-killstreak/` (KS).

| Source | File(s) | Use in CardZone | Task |
|---|---|---|---|
| CC | `project.godot` (Compatibility, 1280×720, canvas_items/expand, `handheld/orientation=4`, no touch-from-mouse) | Replace CardZone's current `project.godot`, which is still **Forward Plus** (not usable for the web target) | cz03 |
| CC | `export_presets.cfg` (Web, single-threaded), `web/shell.html` (progress bar, rotate prompt) | Retitle and recolour | cz03 |
| CC | `tests/run_tests.gd`, `tests/test_case.gd`, `tests/test_smoke.gd` | Headless runner and asserts, unchanged | cz03 |
| CC | `projects/callingcard/tools/package_artifact_build.sh` | Copy to `projects/cardzone/tools/`, set `PROJ` to `project-cardzone` | cz03 |
| CC | `autoload/settings.gd`, `autoload/scene_router.gd`, `scripts/ui/boot.gd` + `scenes/Boot.tscn`, `scripts/ui/screen_profile.gd`, `autoload/event_bus.gd` (pattern) | Settings (fast animations, UI scale), scene changes behind the loader, phone profile; new signal list | cz03 |
| KS | `scripts/ui/press_gesture.gd`; CC `scripts/ui/tap_hold_button.gd`, `scripts/ui/card_inspector.gd` + `scenes/duel/CardInspector.tscn` | Tap / long-press (400 ms) inspect on every card | cz10 |
| CC | `scripts/data/data_validator.gd`, `scripts/data/data_enums.gd`, `scripts/data/balance_config.gd`, `autoload/card_db.gd` | Loud validation at load; CardZone card, area, Zone-card and balance fields | cz05 |
| KS | `scripts/rules/match_clone.gd`, `scripts/rules/rules_event.gd` | Deep copy for AI look-ahead and previews; plain event log the UI and feel layer play back | cz07 |
| KS | `scripts/rules/outcome_forecast.gd`, `scripts/ui/outcome_preview.gd` | Shot preview computed by the real engine on a clone, using only what the viewer may see | cz11 |
| KS | `scripts/ai/ai_view.gd`, `scripts/ai/ai_planner.gd`, `scripts/ai/ai_personality.gd`, `tests/test_ai_player.gd` (source check that the AI never gets the match state) | The fairness wall for private loadouts; plan scoring and personalities | cz09 |
| KS / CC | `tests/test_rules_soak.gd`, `tests/tools/balance_sim.gd`; CC `tests/tools/sim_duels.gd` | AI-vs-AI soak with invariants, and the balance sweep | cz09 |
| CC | `scripts/save/save_file.gd` (atomic `.tmp` write, MISSING/CORRUPT/OK) and `scripts/save/wall_state_codec.gd` (pattern), `tests/test_save_codec.gd` | `match_codec.gd`: setup + move list, replayed on load | cz08 |
| KS | `scripts/ui/tutorial/coach_overlay.gd`, `tutorial_director.gd`; `scripts/ui/pause_menu.gd` | First-match coach (spotlight + locked steps); pause / concede / settings | cz13 |
| CC | `scripts/art/art_kit.gd`, `card_art.gd`, `art_icons.gd`, `art_icon_data.gd`; `tests/tools/gen_art_icons.py`, `build_themes.gd`, `card_sheet.gd`; `assets/fonts/Barlow*.ttf` + `OFL-Barlow.txt`; `assets/shaders/frame_glint.gdshader`, `card_grain.gdshader`; `tests/test_art_kit.gd` | Procedural card art, generated SVG icons, theme builder, contact sheet for review, OFL fonts, rarity glint, budget test | cz16 |
| KS | `scripts/fx/feedback_director.gd`, `tracer_fx.gd`, `hit_marker_fx.gd`, `elim_stamp_fx.gd`, `float_text_fx.gd`, `killfeed.gd`; CC `scripts/fx/fx_timing.gd`, `fx_sfx.gd`, `fx_bench.gd` + `scenes/fx/FxBench.tscn` | Event-log-driven shot, Hit and elimination feedback; fast-animation toggle; placeholder sfx; bench scene to tune | cz17 |
| CC | `autoload/playtest_log.gd` (consent, rotation, Download log, privacy), `scenes/survey/ConsentPrompt.tscn`, `scenes/survey/Survey.tscn`, `scripts/survey/*.gd`, `tests/test_playtest_log.gd` | Keep the machinery; replace SCHEMA, ENUMS and survey questions with section 8 | cz18 |
| CC | `projects/callingcard/tools/kpi_sheet.py`, `test_kpi_sheet.py`, `synthetic_playtest_sessions.gd`; `documentation/production/playtest-log-schema.md`, `playtest-guide.md`, `reports/internal-playtest-report.md` (template) | KPI sheet for section 8, schema doc, tester guide, report template | cz18, cz21 |
| KS | `qa/performance-logs/web-load.md` | Load-time record format | cz19 |
| CardZone | `tools/loadout_sim.py` | Reference for Rookie's heuristics (bot policy in the sims doc) and a cross-check for cz09's sim. **Not** engine code. | cz02, cz09 |

## 6. Phases and day-by-day plan
| Phase | Days | Exit |
|---|---|---|
| P0 Rules lock | D0–D1 | §16 prototype rules + tunables table reviewed (cz01); sim sweep logged (cz02); art direction (cz15) |
| P1 Foundations | D1–D2 | Project from CC/KS builds and packages an empty artifact (cz03); test cases written (cz04); data schema + data (cz05, cz06); layout on mock state at 844×390 (cz10) |
| P2 Engine | D2–D4 | Rules engine passes all cz04 cases (cz07); save codec (cz08); art kit (cz16) |
| P3 Playable loop | D4–D6 | Turn UI on the real engine (cz11); AI + sim (cz09); Brace prompt + AI playback (cz12); title/setup/end/coach (cz13) — **first full match vs AI on a phone by end of D5** |
| P4 Polish and extras | D5–D6 | Feel (cz17), hot-seat (cz14), logger + survey (cz18) |
| P5 QA and RC | D7 | Feature freeze 10:00 D7; QA pass (cz19); RC packaged and linked (cz20) |
| P6 Playtest | D8 | Head + 2–4 testers, KPI sheet, report and tuning recommendations (cz21) |

| Day | Date | Mechanics Dev | UI/UX | Designers | Art (Sr Artist / Tech Artist) | Game Feel | Data Scientist | QA |
|---|---|---|---|---|---|---|---|---|
| D0 | Wed 11-04 | cz03 start | – | **cz01** §16 rules (Sr) | cz15 art direction (Sr Artist) | – | – | – |
| D1 | Thu 11-05 | cz03 finish; cz05 schema | cz10 layout on mock data | cz01 review (Mid); cz02 sweep (Mid) | cz15 done; cz16 start | – | event list for cz18 | **cz04** case list |
| D2 | Fri 11-06 | cz07 start (tests from cz04 first) | cz10 phone check 844×390 / 667×375 | cz06 data (Mid) | cz16 card faces, rarity frames | – | cz18 logger adapt | cz04 finish; review first tests |
| D3 | Mon 11-09 | cz07 turn, loot, shoot, Brace, Down, Bounty | cz10 finish; cz11 on mock state | tuning support | cz16 areas, icons, map | review FxBench from CC/KS | cz18 survey | review cz07 tests |
| D4 | Tue 11-10 | cz07 finish (zone, final circle, elimination); cz08 | cz11 on real rules | – | cz16 finish; budget test | cz17 start (shot, Hit) | cz18 hooks on EventBus | rules checks on build |
| D5 | Wed 11-11 | cz09 AI + 216-game sim | cz12 Brace prompt + AI playback | tune from sim (balance log) | support cz17 | cz17 Brace burn, loot pop | verify log on real build | device pass starts (iPhone) |
| D6 | Thu 11-12 | cz14 hot-seat; AI think-time on phone | cz13 title, setup, end, coach | coach copy review (Sr) | final asset audit | cz17 gas, drop, elimination; fast toggle | KPI sheet adapt | **cz19** starts |
| D7 | Fri 11-13 | **Freeze 10:00**; fixes; **cz20** RC | fixes | – | – | fixes | playtest guide | cz19 sign-off |
| D8 | Mon 11-16 | on call | on call | – | – | – | **cz21** playtest + report | – |

**Critical path:** cz01 → cz04 → cz07 → cz11 → cz12 → cz13 → cz19 → cz20 → cz21 (≈ 7.5 of 8 days). UI/UX builds on mock state and EventBus signals until cz07 lands (mid D4), so nobody waits. The rules engine (2 days) is the biggest single risk; the AI can start on a partial engine (move/loot/shoot) on D4.

## 7. Tasks per agent
Estimates in agent-days. IDs match `prototype-tasks.json`. **Test-first:** every logic task (cz05, cz07, cz08, cz09, cz14) adds headless tests under `tests/` in the same change; cz07 starts from QA's case list (cz04).

### sr-game-designer (0.5 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| cz01 | Prototype rules §16 (1v1, private loadouts, tunables) | 0.5 | – | Spec gains §16: section 3's info model (incl. a ruling on held cards), 1v1 setup and AI drop order, Standard pack for hand 4 and 5, undo boundary, and a **tunables table** (key, default, allowed values, source F1–F8/Q6) matching `prototype-scope.md` §4; every engine-facing edge case (Pull through Hits, Brace when the next hand is short, Frag on self, Heal from the line, gas Hit at 0 health, simultaneous final-circle elimination tiebreak) has a one-line ruling; reviewed by the Mid Designer. |

### mid-game-designer (1.0 d, plus tuning support D5)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| cz02 | Hand-size and 1v1 sim sweep | 0.5 | – | `loadout_sim.py` gains routes B/C, a `--sweep` over all 36 drop pairs and `--hold N`; `../design/balance-log.md` (new) records hand 4 vs 5 × hold 2/1 × route A/B/C with first-player rate, both-out-in-final-circle rate, median last round, earliest elimination; a recommendation on hand size for cz06. |
| cz06 | Card, map, Zone and balance data | 0.5 | cz05, cz01 | 27 cards + Bounty, 7 areas with Cover and piles, 2-player pile sizes, 14 Zone cards × routes A/B/C, Standard pack(s), every tunable at its default; values match spec v0.2 + §16 or a logged change in the balance log; CardDB loads it with no validation errors. |

### mechanics-developer (5.75 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| cz03 | Project setup from CallingCard and Killstreak | 0.75 | – | Renderer **Compatibility**, 1280×720 canvas_items/expand, landscape; files of section 5 rows 1–5 copied and adapted with header lines; folders and autoload stubs per section 9; `godot --headless -s res://tests/run_tests.gd` exits 0 with a smoke test; an empty build packaged by `projects/cardzone/tools/package_artifact_build.sh` loads as a private artifact on desktop Chrome and on an iPhone in Safari. |
| cz05 | Data schema, CardDB and balance file | 0.5 | cz03, cz01 | Typed Resources `CardData` (type, rarity, cost, brace, move, search, heal, pull, dmg, rng, flags: spent, ignores_cover, extra_fire, no_brace, attach bonus), `AreaData`, `ZoneCardData` (per-route effect), `StartPackData`, `BalanceConfig` (every key in scope §4); CardDB loads `data/**/*.tres` and fails loudly on a missing field, a weapon without DMG/RNG, an attachment without a bonus, or a route that closes an already closed area. |
| cz07 | Rules engine `loadout_rules.gd` (test-first) | 2.0 | cz04, cz05 | Node-free `RefCounted` `MatchState` + `LoadoutRules`: setup, round start (Bounty, Zone flip per route), Draw with free Hits up to `hand_size`, Play/Move/Loot/Shoot/Attach/Patch up/Ditch/Pull/Heal, Adrenaline, gas check, Hold and Stow (+ `rack_swap` backup rule), Cover, Down, Brace from the next hand, Suppressor, Frag, Bounty claim, elimination + crate, final circle 1/2/3 and the hard end with tiebreaks; `legal_actions(state, seat)`, `apply(state, action)` and a `view(state, seat)` that hides the opponent's private cards; every tunable read from `BalanceConfig`; a replay of the action list reproduces the state exactly; emits `RulesEvent`s; all cz04 cases pass (≥ 70), incl. the spec §7 example. |
| cz08 | Save, resume and replay | 0.5 | cz07 | `match_codec.gd` stores {format, version, balance hash, setup, actions[]} via `SaveFile` after every action; resume replays to the same state (hash check); a corrupt or version-mismatched save offers "start new" and never crashes; tests replay 20 AI-vs-AI games from saved files; a Safari reload mid-turn resumes at the same step. |
| cz09 | Deterministic AI (Rookie, Veteran) and balance sim | 1.25 | cz07, cz06 | `AiView` (ported from KS) holds only public info + own cards (test checks the AI script never references `MatchState`); **Rookie** = the sims doc's bot policy; **Veteran** = scores candidate turn plans (route × loot × shots × hold) with a fixed evaluation (health, gear, next-hand armour, gas safety, Bounty, threat in range) on `MatchClone`, ties broken by a fixed order; same input → same output (test); < 300 ms per turn on an iPhone 12-class phone (time-boxed search, logged); deterministic AI drop rule; headless sim of 36 drops × 3 routes × hand 4/5 (Veteran vs Veteran) writes section 1 DoD-6 numbers to `../design/balance-log.md`; soak test checks invariants (card conservation, health 0–5, hand ≥ hand_size when cards remain) after every action. |
| cz14 | Hot-seat (pass the phone) | 0.5 | cz12 | Setup offers "vs AI" or "Pass and play"; each seat change shows a full-screen cover ("Hand the phone to Player 2") that hides all private info until tapped; the Brace prompt on the shooter's turn shows a cover first for the defender; a full hot-seat match plays touch-only; logged as `mode: hotseat`. **First to cut.** |
| cz20 | Release candidate build and link | 0.25 | cz19 | RC exported with the Web preset, packaged with the script, published as a private artifact; `projects/cardzone` board doc gets `playUrl` and `playNote`; build version and date shown on the title screen; the load time recorded by cz19 is for this build. |

### ui-ux-agent (4.75 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| cz10 | Match screen layout on mock state | 1.25 | cz03 | One landscape layout: Ridge Hollow map (7 areas, pawns, gas, piles count, drops), your hand (5 cards, compact faces), your line, your **loadout strip** with the next hand highlighted as "armour" (held cards marked, Brace shields), your health stack, the opponent panel (health, Down badge, loadout count, Bounty, last line), the Zone track (current card, next card, route); long-press inspector on every card; anchors/containers only; tap targets ≥ 64 logical px; essential numbers ≥ 24 px; safe areas; layout test at 1280×720, 844×390 and 667×375; screenshots to the board. |
| cz11 | Turn flow on the real engine | 1.5 | cz07, cz10 | Draw animation hook, tap card → play (Adrenaline asks Move or Search), Move by tapping an adjacent area, Loot by tapping a pile (cost shown, disabled when unaffordable), Shoot: tap weapon → tap target with the **damage preview** (Cover, Down, "they may Brace"), Attach by tap-tap, Patch up and Ditch buttons, running Move/Search pools, Pack: Hold toggles (max `hold_limit`) + **End turn**; undo within the section 3 boundary; illegal actions explain why in words; all driven by `legal_actions` (no rule logic in UI). |
| cz12 | Brace prompt and AI turn playback | 1.0 | cz11, cz09 | When shot: modal with incoming damage after Cover and Down, your next hand with shields, a **suggested brace** (fewest cards that stop the most damage), live "you take N Hits", confirm in ≤ 2 taps; AI turns play back step by step from `RulesEvent`s (move, loot, shot, hold count only) at normal/fast speed with a skip button; the AI's Brace reveals the cards it used. |
| cz13 | Title, setup, end screen and first-match coach | 1.0 | cz11, cz08 | Title (game name and build version), Continue (saved match), New match: opponent (Rookie/Veteran/hot-seat), first player, route (A/B/C or "pick for me"), drop on the map; end screen: winner, rounds, damage dealt/taken, Bounty heals, "play again"; pause menu (concede, fast animations, how to play); skippable first-match coach (KS coach overlay) teaching Hold, Brace, Down and Adrenaline in the first 3 turns; a hidden dev panel (5 taps on the version) to switch hand size and F1–F8 for the playtest. |

### sr-game-artist (0.5 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| cz15 | Art direction one-pager | 0.5 | – | `../art/style-guides/art-direction.md`: grounded near-future fictional island (Ridge Hollow), palette with gas and safe-zone colours, 5 rarity colours + letters that also read in greyscale, card frame layout from spec §6 at phone size (what shows on a compact card), area tile look (open/gas), icon list (Move, Search, Brace, Heal, Pull, DMG, RNG, Cover, Down, Bounty, Spent, Attach, Hit/Adrenaline), type/weapon silhouettes; no real brands or franchise look; reviewed on the board before cz16 finishes. |

### technical-artist (1.5 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| cz16 | Placeholder art kit | 1.5 | cz03, cz15 | Procedural `CardArt` (from CC) drawing each card type with a silhouette and rarity frame at compact (phone hand) and inspector size; Hit card with red band and Adrenaline line; Bounty badge; 7 area tiles with open and gas states; map board; generated SVG icons for the cz15 list; OFL fonts (Barlow from CC); `zone_theme.tres`; rarity glint shader for E/L only; card contact sheet for review; imported assets < 5 MB (art-kit test). |

### game-feel-developer (1.0 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| cz17 | Looting and shooting feel | 1.0 | cz12, cz16 | Driven by `RulesEvent`s through a FeedbackDirector (from KS): tracer + hit marker on a shot, Hits **slamming onto the top of the loadout strip**, Brace cards burning to the bottom with a shield crack, loot pop by rarity (bigger for E/L), supply-drop landing, gas sweep over a closing area, Down badge pulse, Bounty heal float, elimination stamp; placeholder sfx; all skippable; "fast animations" halves every beat; 60 FPS desktop, 30+ FPS on the iPhone. |

### data-scientist (1.75 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| cz18 | Playtest logger, survey and KPI sheet | 0.75 | cz03, cz11 | CC `PlaytestLog` adapted: EventBus only, all section 8 events with the anonymous session id, opt-in consent, survey with the section 8 statements + 1 open question, Download log on iOS Safari and desktop; `documentation/production/playtest-log-schema.md` and `tools/kpi_sheet.py` (+ test) adapted to the section 8 KPIs; schema test passes; synthetic sessions only for tool tests. |
| cz21 | Internal playtest and report | 1.0 | cz20 | ≥ 3 sessions incl. the head on his iPhone, ≥ 2 matches each, at least 1 tester trying hot-seat (if shipped); KPI sheet from real logs; report in `reports/prototype-playtest-report.md` with the section 8 table, a recommendation on hand size and each F1–F8 default and on held-card visibility, and an iterate / extend to 3–4 players / stop call. |

### qa-agent (2.0 d)
| ID | Task | Est | Depends | Acceptance criteria |
|---|---|---|---|---|
| cz04 | Rules test-case list (test-first) | 0.75 | cz01 | `../../qa/test-plans/loadout-loop-rules-cases.md`: ≥ 70 numbered cases with state, action and expected result, covering draw with Hits (hand 4 and 5), every keyword, Adrenaline, Hold and Stow order, rack_swap, Cover, Down, Brace window and short loadouts, Suppressor, Frag on self, Extended Mag/LMG extra fire with Down, Bounty assign/claim/final circle, gas check, elimination and crate, final circle and hard-end tiebreaks, every F1–F8 switch, private view (what the opponent sees), the spec §7 example; reviewed by the Mid Designer before cz07 starts. |
| cz19 | Rules, device and release check | 1.25 | cz08, cz09, cz13, cz14, cz17, cz18 | Test plan covers the spec and this plan's definition of done; device matrix: **iPhone Safari landscape (head's device class) first**, Android Chrome, desktop Chrome/Safari/Firefox; touch-only and mouse-only full matches vs Rookie and Veteran; resume after reload and after phone lock; AI never leaks private info (spot check + test); load time in `../../qa/performance-logs/web-load.md`; bugs in `../../qa/bug-reports/`; sign-off at 0 critical / ≤ 10 minor. |

**Total: ≈ 18.75 agent-days over 8 working days** (Mechanics 5.75, UI/UX 4.75, QA 2.0, Data Scientist 1.75, Technical Artist 1.5, Game Feel 1.0, Mid Designer 1.0, Sr Designer 0.5, Sr Artist 0.5).

**Team change:** `project-config.json` lists only design-phase agents and `mode: design`. This plan adds mechanics-developer, game-feel-developer, technical-artist, ui-ux-agent and qa-agent and moves the project to `phase: prototype` once the head approves (a lead action).

## 8. Playtest plan and KPIs
**Who and how (cz21, D8):** the head on his iPhone, plus 2–4 internal testers (at least 1 more on a phone). Each plays ≥ 2 matches vs the AI (first Rookie, then Veteran), optionally 1 hot-seat match, then the survey and Download log. The CallingCard approach is reused unchanged: opt-in logger, `tools/kpi_sheet.py`, a tester guide, a report template. With 3–5 testers every number is **directional**, and the report says so.

**KPIs and bars** (the paper-test gates from DESIGN_REVIEW move here, because Q9 skipped paper):
| KPI | Bar | From |
|---|---|---|
| Pack time (from the Pack step to End turn) | median ≤ 10 s, 90th percentile ≤ 20 s | `pack` events |
| Human turn time | median ≤ 60 s | `turn_end` |
| Match length vs AI | median 12–20 min, last round 8–14 | `match_end` |
| Early elimination | no human eliminated before round 6 in ≥ 90% of matches | `elimination` |
| Comeback | of matches where the human is at ≤ 3 health in round 4, ≥ 1 in 3 end with a win or survival to round 10+ | `round_start` health + `match_end` |
| Hold used | ≥ 60% of packs hold ≥ 1 card, from the second match on | `pack` |
| Brace used | ≥ 50% of shots at the human where Brace was possible get ≥ 1 Brace card | `brace` |
| Hidden-armour check (Q3) | share of shots fully braced (0 Hits) **≤ 35%** (higher means held cards are too strong hidden) | `shot` |
| Replay intent | ≥ 50% of testers start a 2nd match without being asked twice | `match_start` |
| Survey (1–5, 4+ counts) | "I want to play another match" ≥ 70%; "I understood why I took damage" ≥ 70%; "Packing felt quick" ≥ 70%; "My choices mattered more than luck" ≥ 70%; "The AI played fair" ≥ 60% | `survey` |
| Load | < 10 s on every iPhone session | `session_start.load_ms` |
| Saves | 0 lost matches across reloads | `match_resumed` vs `match_start` |

**Telemetry for tuning (no bar; spec §12):** holds 0/1/2 and what was held, Adrenaline Move vs Search, shots where Down or the Bounty changed the result, Bounty heals, loot per pile, drop areas and survival by drop, damage vs Brace per shot, Veteran vs Rookie win rates, hand size and F-switches in effect per match.

**Logged events** (`user://playtest_log.jsonl`): `session_start(load_ms, input_type, viewport, browser)`, `match_start(mode: ai|hotseat, ai_level, first_player, route, drop_human, drop_ai, hand_size, tunables_hash)`, `round_start(round, zone_card, health_h, health_ai, bounty)`, `turn_start(seat, round, hand_ids, hits_drawn)`, `card_play(card_id, as: effect|adrenaline_move|adrenaline_search)`, `move(from, to)`, `loot(card_id, pile|drop|crate, cost)`, `shot(weapon_id, attachments, target, raw, cover, down, brace_cards, brace_total, hits, bounty_claim, suppressor)`, `brace(prompt_ms, cards, suggested_used)`, `patch_up`, `ditch(card_id)`, `gas_hit`, `pack(hold_ids, hold_count, pack_ms)`, `turn_end(turn_ms, undo_count)`, `elimination(seat, round, by)`, `match_end(result, rounds, duration_s, cause: shot|final_circle|hard_end, health_h, health_ai)`, `match_resumed(age_s, actions)`, `coach_step(step, skipped)`, `survey(answers)`, `quit(screen)`.

## 9. Godot project structure (prototype)
Root: `projects/cardzone/source/project-cardzone/`
```
project.godot              # Compatibility, 1280x720, canvas_items/expand, landscape, main scene = Boot.tscn
export_presets.cfg         # "Web" (single-threaded), custom shell res://web/shell.html
web/shell.html             # progress bar, rotate prompt (from CallingCard)
autoload/
  event_bus.gd             # EventBus: rules_event, turn_started, shot_resolved, brace_requested, match_ended, ...
  settings.gd              # Settings + ScreenProfile (from CallingCard)
  scene_router.gd          # SceneRouter (from CallingCard)
  card_db.gd               # CardDB: loads data/**/*.tres, validates
  match_store.gd           # MatchStore: current match save/resume (match_codec)
  playtest_log.gd          # PlaytestLog (adapted from CallingCard)
scripts/
  data/   card_data.gd area_data.gd zone_card_data.gd start_pack_data.gd balance_config.gd data_enums.gd data_validator.gd
  rules/  match_state.gd loadout_rules.gd rules_action.gd rules_event.gd match_view.gd match_clone.gd shot_forecast.gd  (RefCounted, no nodes)
  ai/     ai_view.gd ai_rookie.gd ai_veteran.gd ai_drop.gd
  save/   save_file.gd match_codec.gd
  ui/     screen_profile.gd press_gesture.gd card_inspector.gd + one script per scene
  art/    art_kit.gd card_art.gd art_icons.gd art_icon_data.gd
  fx/     feedback_director.gd fx_timing.gd fx_sfx.gd tracer_fx.gd hit_marker_fx.gd ...
scenes/
  Boot.tscn Title.tscn MatchSetup.tscn Match.tscn MatchEnd.tscn Survey.tscn
  match/ Map.tscn AreaTile.tscn Hand.tscn Line.tscn LoadoutStrip.tscn OpponentPanel.tscn ZoneTrack.tscn BracePrompt.tscn PassCover.tscn CardView.tscn CardInspector.tscn
  coach/ CoachOverlay.tscn
data/ cards/*.tres areas/*.tres zone/*.tres packs/*.tres balance.tres
assets/ fonts/ icons/ shaders/ audio/ themes/
tests/
  run_tests.gd test_case.gd test_smoke.gd test_data.gd
  test_rules_draw_pack.gd test_rules_actions.gd test_rules_shooting.gd test_rules_zone.gd test_rules_endgame.gd
  test_rules_tunables.gd test_match_view.gd test_replay.gd test_save_codec.gd
  test_ai.gd test_ai_fairness.gd test_rules_soak.gd test_layout.gd test_art_kit.gd test_playtest_log.gd test_hotseat.gd
  tools/ sim_matches.gd gen_art_icons.py build_themes.gd card_sheet.gd
tools/package_artifact_build.sh   (at projects/cardzone/tools/, adapted from CallingCard)
```
Card data is `.tres` (typed fields, validation at load, clean diffs), as in both earlier projects. Rules are node-free, so the AI look-ahead, the shot preview, the Brace suggestion, save/replay and the tests all run the same code.

## 10. Web and phone rules
- **Web export** (as CallingCard): Compatibility (WebGL 2), thread support **off** (works on iOS Safari and as an artifact), canvas resize adaptive, VRAM compression for desktop and mobile, saves in `user://` (IndexedDB), PWA off, audio after the first tap. Hosting: private claude.ai artifact via `tools/package_artifact_build.sh`. Killstreak's measured cold load was 6.0 s with this template.
- **iPhone landscape:** reference 844×390 (iPhone 12–15) and 667×375 (SE); notch/Dynamic Island safe areas on the left and right; Safari's bottom bar; rotate prompt in portrait (shell).
- **Touch:** no hover-only info; long-press (400 ms) inspects any card; tap-tap for every action, drag optional; tap targets ≥ 64 logical px; the Brace prompt and End turn sit in thumb reach.
- **Readability:** compact card faces show cost, rarity letter, Brace shield and one main stat; the name and text live in the inspector. Rarity, ownership and gas never rely on colour alone (letters, patterns). Text contrast ≥ 4.5:1.
- **Single-threaded AI:** Veteran's search is time-boxed and yields across frames so the UI never freezes.

## 11. Risks
| Risk | P | I | Mitigation | Owner |
|---|---|---|---|---|
| Rules engine is large (9 keywords, attachments, Pull through Hits, Brace window, Bounty, crates, final circle) | High | High | Test-first from cz04 (≥ 70 cases); node-free engine; replay tests; soak with the AI | mechanics-developer |
| Phone screen too dense (map + 5-card hand + line + loadout strip + opponent + Zone) | High | High | Layout on mock state on D1–D3 at 844×390 and 667×375; compact faces + inspector; the map doubles as the opponent view | ui-ux-agent |
| AI too weak or too slow on a single-threaded web build | Med | High | Rookie from the proven sim policy first; Veteran time-boxed (300 ms) and yielding; cut order keeps Rookie | mechanics-developer |
| AI peeks at private cards (Q3) | Med | High | `AiView` fairness wall from Killstreak, plus a test that the AI scripts never receive `MatchState` | mechanics-developer, qa-agent |
| Hand 5 changes the balance (faster gearing, more armour, 2-turn loop) | Med | Med | Tunable; 216-game AI sim on D5; dev panel lets the playtest flip it | mid-game-designer |
| Hidden held cards make Hold too strong or shots feel like guesses | Med | Med | `held_cards_public` switch; KPI "fully braced shots ≤ 35%"; survey "understood why I took damage" | sr-game-designer, data-scientist |
| Safari evicts the tab and a match is lost | Med | Med | Save after every action as a move list; resume tested after reload and phone lock | mechanics-developer |
| Deterministic AI feels repetitive | Med | Low | 3 routes, both drops chosen per match, two AI levels; the AI's drop rule depends on the human's drop | mechanics-developer |
| Spec v0.2 (`cz-spec2`) still in review | Low | Med | Every changed default is a `balance.tres` edit; cz01 lands §16 on top of v0.2 | producer |
| Mechanics Dev overload (5.75 d in 8) | Med | High | UI on mock state; hot-seat first to cut; feature freeze D7 10:00 | producer |

## 12. Questions for the head
**None block this plan.** Two defaults to confirm or change in your review comment (each is a one-line data switch):
1. **Held cards are hidden from the opponent** (private loadouts, Q3); the count of Hits on top stays visible because Down depends on it.
2. **The Zone deck is v0.2's 14 cards** (escalating final circle, hard end after card 14), not the 12 from the Q6 wording.

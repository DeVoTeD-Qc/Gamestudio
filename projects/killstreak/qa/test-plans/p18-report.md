# p18 QA report: rules, devices and release check

*QA Agent · 2026-11-03 · Godot 4.4.1 web export (Compatibility, single-threaded) · Definition of done: 0 critical, ≤ 10 minor bugs*

## Verdict
**GO for the private playtest**, with the open minor bug and the phone-only checks below.

| Severity | Found | Fixed | Open |
|---|---:|---:|---:|
| Critical | 0 | 0 | 0 |
| Major | 0 | 0 | 0 |
| Minor | 5 | 4 | 1 |

**Still open:** the real iPhone Safari and Android Chrome pass. Only Chromium is installed here, so the user runs it on
their phones with `device-checklist.md` (15 steps). The cold load is the biggest risk on a phone (see Performance).

## Bugs
| ID | Severity | Status | Summary | Report |
|---|---|---|---|---|
| p18-001 | minor | **fixed** | The enemy AI planned two Flank Routes on the same unit in one Deploy. The engine refused the second, so the AI wasted that play. | `bug-reports/p18-001-ai-double-flank-route.md` |
| p18-002 | minor | **fixed** | The p17 load-time check never finished on a first launch: since p16, Boot opens the Consent screen, not the Title. | `bug-reports/p18-002-load-check-misses-first-launch.md` |
| p18-003 | minor | **fixed** | The tutorial's score bar said "ZONE CONTROL · FIRST TO 20". It now says "4-ROUND DRILL". | `bug-reports/p18-003-tutorial-first-to-20.md` |
| p18-004 | minor | **fixed** | Test data used franchise perk names ("scavenger", "ghost"). Test-only, never exported. | `bug-reports/p18-004-franchise-perk-ids-in-test-data.md` |
| p18-005 | minor | **open** | Killfeed names are clipped on the phone layout ("BREACH ▸ KES"). This is a layout decision for the Game Feel and UI/UX agents. | `bug-reports/p18-005-killfeed-names-clipped-on-phone.md` |

Each fix has a regression test in `tests/test_p18_regressions.gd` (p18-001, p18-003), or a re-run of its tool or test (p18-002, p18-004).

Code changed by QA: `scripts/ai/ai_planner.gd` (moved units are not moved again), `scripts/survey/consent_screen.gd`
(prints `Consent: ready`), `scripts/ui/match_snapshot.gd` and `scripts/ui/tutorial/tutorial_match_controller.gd`
(drill goal text), `tests/test_playtest_log.gd` (perk ids), `tests/run_tests.gd` (optional `-- --only=<substring>` filter),
`qa/performance-logs/tools/measure.js` (either marker, `URL` / `SHOTS` from the environment). `data/` was not touched.

## 1. Rules and edge cases
**Review against core-rules §9 and both Rulings sections.** The p04–p07 suites already covered every §9 edge case:
both Operators down in the same step, a wasted shot, Pick ties, burn on a full hand, zone full, a dead Shieldman's
next-in-line, and an overtime draw with no ticket lost. They also covered rulings 1–13 and part 2 #1–#14, except
the gaps below, which now have tests in `tests/test_p18_regressions.gd`:

| Rule | New test |
|---|---|
| Part 2 #6: Suppress applies after Attack Helo, to whoever is point man then | `test_suppress_applies_after_attack_helo_to_the_new_point_man` |
| Part 2 #6: several Suppress stack, floor 0 | `test_several_suppress_stack_with_a_floor_of_zero` |
| Part 2 #7: Frag's "1 to the next enemy" reads the line as it was | `test_frag_second_hit_reads_the_line_as_it_was` |
| Ruling 7: Callout buffs a unit played *before* it | `test_callout_buffs_a_unit_played_before_it` |
| Part 2 #5: Patch tie goes to the front-most | `test_patch_tie_goes_to_the_front_most` |
| Part 2 #9: Deploy capacity minus the Operator rotating out | `test_zone_capacity_counts_the_operator_rotating_out` |
| §1 Holder: Holder vs Holder stays contested | `test_two_holders_contest_the_zone` |
| Ruling 12: Supply stays capped in overtime | `test_overtime_supply_stays_capped` |
| §9: a burned draw is discarded and logged (`card_burned`) | `test_full_hand_draw_is_discarded_and_logged` |
| Part 2 #8: credit goes to the shot that crossed lethal | `test_elimination_credit_goes_to_the_shot_that_crossed_lethal` |

All new rules tests passed on the first run. One expectation of mine was wrong (the AR range bonus on the flat test map), not the engine.

**AI vs AI soak** (`tests/test_rules_soak.gd`, about 25 s). It plays real data, with the real `AiPlayer` on both sides (the player's
side alternates Rusher and Anchor personalities), and checks the invariants after every Briefing, Deploy and Score:
no negative Supply, Armor between 0 and max, no dead unit left at Deploy, zones ≤ 4, each unit in one place, hand ≤ 7,
card conservation (deck + hand + discard + board + Equipment + queued), streak ≥ 0, the tray holds only the side's own
killstreaks with no duplicates, every threshold reached was earned this life, an Operator down resets the streak and the life,
red dots = the AI's committed unit deployments, no refused AI intent, and the match ends by round 10.

| Sweep | Matches | Rounds (avg / max) | Results (enemy / player / draw) | Violations |
|---|---:|---|---|---:|
| All 5 run slots × 30 seeds, randomised player kit (0–2 Perks, 0–3 attachments, every killstreak trio, reward cards in the deck) | 150 | 6.1 / 10 | 90 / 59 / 1 | 0 |
| 20 whole runs through `RunProgress` (random killstreak picks, random reward choices, 15% skips) | 84 | 6.2 / 10 | 50 / 31 / 3 | 0 |

Before the p18-001 fix, the whole-run sweep found 1 refused intent. Overtime and the round-10 draw were both reached. No script errors.
Run outcomes (5 victories in 20) are reported for p19, not asserted.

**Test counts:** full suite **301 passed, 0 failed** (it was 287). New: `test_rules_soak.gd` (2 tests) and `test_p18_regressions.gd` (12 tests).
The headless runner prints only the expected errors from the data-validation tests, plus Godot's usual "ObjectDB instances leaked at exit"
warning, which is not player-facing.

## 2. Full-flow passes in the real web export
Build: a scratch copy of the project with Boot as the main scene, plus a passive probe autoload in the scratch copy only.
It was served with `serve_gz.py` (gzip, `application/wasm`) and driven by Playwright Chromium (SwiftShader WebGL2). Every
pass: fresh profile (first launch) → Consent (Yes) → pre-survey (3 answers) → Title drill offer → tutorial **played to DONE**
(all 17 steps, by following the coach highlight) → TUTORIAL → **SKIP** (two taps) → START NEW RUN → Loadout (Attack Helo
swapped for Sentry Turret) → every match **played to the end by taps** (Operator, units, Frag, Flashbang, killstreaks) →
banner → After-Action → every reward → Run End → end survey (5 + open) → **Download log** → Done → Title.

| Profile | Input | Matches | Rewards taken | Killstreaks used | Console errors / warnings | Log download |
|---|---|---|---|---|---|---|
| iPhone 844×390 @3x | touch only | 3 (0 W, run lost on tickets) | attachment, Perk | none earned | 0 / 0 | 19.7 KB `.jsonl`, 157 lines, valid JSON |
| Desktop 1280×720 | mouse only | 3 (0 W) | attachment, Perk | none earned | 0 / 0 | 22.3 KB |
| Desktop 1280×720, second run (smarter tap policy) | mouse only | 4 (1 W) | **Supply Drop**, attachment, Perk | Recon Drone, Mortar, Sentry | 0 / 0 | 36.9 KB |
| iPad 1024×768 @2x | touch only | 4 (1 W) | attachment, **Supply Drop**, Perk | Recon Drone, Mortar, Sentry | 0 / 0 | 32.0 KB |

All four passes finished with no stuck screen. The downloaded log held every expected event type (consent, pre_survey,
tutorial_step ×18, run_start, match_start/end, card_played, elimination, operator_down, killstreak_earned, offer_shown,
the picks, run_end, end_survey, log_exported). The survey answers matched what the passes tapped.
Attack Helo was not used in the browser passes because it was swapped out at Loadout. The rules tests cover it.
The open-answer text field was not typed into in the browser: on-screen keyboards are a phone-only check (checklist steps 3 and 13).

Screenshots: `qa/screenshots/p18-*.png`. Full sets for every pass are in the scratchpad.
Tooling note: the tutorial's SKIP confirmation lasts 3 s. A first automated attempt took a screenshot between the two taps, and the
screenshot took longer than 3 s, so the confirmation expired. That was the harness, not a bug: a human double-tap and the
`test_tutorial` skip test both work.

## Performance (cold load, p17 tool, 20 Mbps throttle)
**Median 7.47 s to the first screen** (Consent, on a first launch), with the first progress at 0.20 s. 10.23 MB per cold load.
**Passes the < 10 s target** on desktop. It was 6.0 s in p17: the pck grew to 912 KB, and the engine start is now about 2 s. On a phone, expect
roughly 9–11 s, so this is **at risk**. Measure it on the iPhone (checklist step 2). If it misses, the lever is a custom export template
with unused modules removed (see `web-load.md`). Details are in `qa/performance-logs/web-load.md`, section "Re-measure (p18)".

## 3. Phones
`qa/test-plans/device-checklist.md`: 15 plain-English steps for iPhone Safari and Android Chrome. They cover load time, notch and
home bar, tap and drag, long-press, page bounce or zoom, backgrounding and rotation, resuming a saved run, Download log through
Files / Downloads, and running from the home screen.

## 4. IP name checklist
Searched `data/`, `scenes/`, `scripts/`, `autoload/`, `tests/`, `web/shell.html`, `project.godot`, `export_presets.cfg`,
the README files, `documentation/` and `qa/` for: Call of Duty, CoD, Activision, Modern Warfare, Warzone, Black Ops, Infinity Ward,
Treyarch, Nuketown, Shipment, Price, Soap, Ghost, Gaz, Task Force 141, Create-a-Class, Prestige, UAV, Juggernaut, Chopper Gunner,
AC-130, Killcam, Gulag, Domination, Hardpoint, Search and Destroy, Team Deathmatch, Care Package, Nuke, Scorestreak, Scavenger,
Makarov, Verdansk, Ninja, Hardline, Ghillie, and franchise map, mode and perk names.

| Hit | Where | Judgement |
|---|---|---|
| `ghost` | `match_screen.gd`, `hand_area.gd`, `test_hand_input.gd` (the drag "ghost" card) | **OK**: a generic UI term in code, never shown to players |
| `scavenger`, `ghost` perk ids | `tests/test_playtest_log.gd` | **Fixed** (p18-004) |
| "Gunship" | `card_samples.gd`, `call_in_takeover.gd`, `feedback_director.gd`, core-rules | **OK**: a generic military term, and post-prototype content. The franchise uses "AC-130" and "Chopper Gunner" |
| "scorestreak" | core-rules §3 (Objective Focus note), a test comment | **OK internally**: design shorthand. Keep it out of player-facing text and the store page |
| "domination-style", "team-deathmatch-style", "UAV-style", "Call of Duty" | `vision.md`, `gdd.md`, `DESIGN_REVIEW.md`, the milestone plan | **OK internally**: genre comparisons and the IP rule itself, in internal docs only. Keep them out of the store page and the itch.io text |
| "Recon Specialist", "Operator", "Perks", "dog tag" | cards, UI | **OK**: generic military and genre words |
| "Killstreak" (working title) | `project.godot`, the web shell | **OK for a private playtest**: a generic genre term used across many shooters. Run a trademark search before any public name |

No franchise names, characters, maps, modes or logos appear in shipped data, scenes, UI text or the web shell. **IP checklist passed.**

## Not covered here
- Real WebKit / iOS Safari, Android Chrome, real GPUs and audio output: covered by the device checklist.
- Long-session memory: matches ran up to 19 minutes per pass, with no slowdown seen and no errors. No heap profile was taken.
- Balance: p19. The soak shows the AI beating an AI-played player about 60% of the time; it is reported, not judged.

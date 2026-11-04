# CardZone 1v1 prototype: rules, device and release check (cz19)

QA Agent · 2026-11-04 · game code at commit `e2f924f` (all build tasks done; the later commits on the branch touch only this task's new test and screenshots) · Godot 4.4.1, Web export (Compatibility renderer)

## Verdict

**Pass, with two major items for the producer.** The milestone bar is met: **0 critical** bugs and **5 minor** bugs (the limit is 10). No private information reached the AI, the screen or the playtest log in any test, in AI matches or in hot-seat. Every touch-only and mouse-only match finished on all six device sizes. Every resume case kept the match.

Two **major** issues are open. Neither breaks the DoD as written, but both affect the cz21 playtest:

1. **Load time is over 10 s on throttled networks** (BUG-01). It is about 13 s on "4G" and about 60 s on "Fast 3G". On Wi-Fi-class (unthrottled) links it is about 1.9 s, so DoD 1 ("< 10 s on Wi-Fi") passes.
2. **The first-player edge and early eliminations are still outside the DoD 6 targets** (BUG-02). At the defaults, the first player wins 62% (target 45–55%) and the earliest elimination is in round 3 (spec gate: round 6). The browser matches showed the same pattern. This is already escalated as decision `cz-q2`.

| Severity | Count |
|---|---|
| Critical | 0 |
| Major | 2 |
| Minor | 5 |
| Cosmetic | 2 |

**Tests:** the suite has **185/185** passing: the 184 existing tests plus 1 new one in `tests/test_release_rules.gd` (a spec §16 oracle over 48 AI games). Nothing was committed by QA.

## 1. Rules

| Check | Result |
|---|---|
| QA cz04 cases (`test_rules_cases.gd`, from `rules-test-cases.json`) | **120 / 120 pass**, with 44 preview checks and 120 replay checks |
| Soak (`test_rules_soak.gd`) | **Pass.** 200 random games: 26,730 actions, 1,643 undos, 456 shot previews, 18,520 fairness view checks and 200 replays, all clean. The 3 × 30 switch-set games and 20 live-CardDB games are also clean. |
| Spec §16 oracle, new (`test_release_rules.gd`) | **Pass, 0 mismatches.** 48 games ran on the real engine: Rookie and Veteran in all 4 pairings, routes A/B/C, hand 5, the hand-4 dev pairing (drop cost 3), a short deck that reaches the hard end, a harsh final circle, and 6 "camper" games that sit in the gas. Before each action the oracle predicts the result from the spec text alone (it does not call `shot_profile` or `cover_for`), then compares it with the state and events after the action. Checks run: 541 shots (58 with Cover, 178 with Down), 512 Braces, 394 round starts (Bounty), 28 final-circle flips, 11 gas Hits, 98 Bounty claims, and the hard end. |
| Brace (R24–R27) | Damage = DMG + attachments − Cover − Down, at least 0. There is no Brace step at 0 damage or under a Suppressor. Hits = max(0, damage − Brace). Braced cards go to the bottom in the chosen order, and no card braces twice in a turn. All match the oracle. In the browser, the prompt showed e.g. "DMG 3 – Cover 0 – Down 0 = 3 damage", and with Duck suggested, "YOU TAKE 2 HITS · HEALTH 5 → 3" and "BRACE · 2 HITS". In a log, the Twin-Drum LMG shot 2 at Cover 1 and Down 1 for 0 damage with no Brace prompt. |
| Down (D6, R23, R28) | Down = Hits in the next draw. −1 applies once per shot and is recomputed between shots. Matches the oracle; Down badges are shown in the browser. |
| Bounty (R36–R38) | Goes to strictly more health at round start; a tie sets it aside. The claim heals the shooter. The holder takes +1 in the final circle. Matches the oracle, including round starts right after a gas Hit. |
| Gas (R40–R42) | 1 Hit at End turn only for a pawn in gas. Camper games end by gas elimination. |
| Final circle (R43) | Cards 12/13/14 deal `final_circle_hits[k−12]` to both players, plus the holder's extra. Matches, including the 3·3·3 preset. |
| Tiebreaks (R47, R48) | The hard end goes to more health, then more non-Hit cards, then a draw. Matches. No game in the oracle ended with both players out at once; R47 is covered by the cz04 cases and the soak. |
| AI sweep (`tests/tools/ai_sweep.gd`, defaults, Veteran vs Veteran, 216 games, 77 s) | It reproduces balance-log Entry 2 to the game. Hand 5: first player **67/108 (62.0%)**, both out 7 (6.5%), median round 12, earliest elimination **round 3**. Hand 4 (drop cost 3): first player 66/108 (61.1%), both out 12 (11.1%), median 13, earliest round 6. AI turns: 4,898; median 8.9 ms, p99 39.2 ms, max 91 ms; the worst re-timed turn was 63.2 ms (desktop CPU); 0 illegal actions. See BUG-02. |

## 2. Device matrix (scratch web export, Chromium via Playwright, SwiftShader)

Every match was played start to finish with **real input events** (`page.touchscreen.tap` or `page.mouse.click`), from consent through setup and the match to the end screen. A scratch-only driver autoload, `qa_driver.gd`, reports the screen point of the next control to tap. It never presses anything itself. It uses the same action policy as `test_match_flow_kit.gd`; the "Veteran" policy rows use the Veteran AI to choose the human's moves, so all actions get exercised (shoot, attach, patch up, Brace by cards). Every 15 steps the driver also checks that no visible button lies outside the viewport.

| Device (CSS px) | Input | Opponent | Boot → consent | Result | Rounds / actions | Taps | Off-screen taps | Script errors |
|---|---|---|---|---|---|---|---|---|
| iPhone 13 landscape 844×390 @3x (iOS UA) | touch only | Rookie | 4.5 s | finished (rival wins, shot) | 9 / 135 | 150 | 0 | 0 |
| iPhone 13 landscape 844×390 @3x | touch only | Veteran | 3.8 s | finished (rival wins, gas) | 7 / 119 | 150 | 0 | 0 |
| iPhone 13 landscape 844×390 @3x | touch only | **hot-seat** | 4.0 s | finished, **"PLAYER 2 WINS"** (gas) | 9 / 144 | 327 (25 covers) | 0 | 0 |
| iPhone SE landscape 667×375 @2x | touch only | Veteran | 3.2 s | finished (rival wins, shot) | 3 / 73 | 77 | 0 | 0 |
| Small Android landscape 640×360 @2x (Chrome UA) | touch only | Rookie | 3.3 s | finished, **YOU WIN** (shot) | 5 / 95 | 108 | 0 | 0 |
| iPad landscape 1180×820 @2x | touch only | Veteran | 4.3 s | finished (rival wins, shot) | 3 / 73 | 77 | 0 | 0 |
| Desktop 1280×720 | mouse only | Rookie | 2.0 s | finished (rival wins, shot) | 9 / 135 | 150 | 0 | 0 |
| Desktop 1280×720 | mouse only | **hot-seat** | 3.9 s | finished, **"PLAYER 2 WINS"** | 3 / 73 | 175 | 1¹ | 0 |
| Desktop 1920×1080 | mouse only | Veteran | 3.5 s | finished (rival wins, shot) | 3 / 73 | 77 | 0 | 0 |

¹ A driver timing artefact. It reported a line chip's position in the same frame as `ensure_control_visible`, before the scroll had applied. The retry hit. The Line is a scroll list by design.

- **Touch only:** both AI levels, plus hot-seat, completed on iPhone 13. The Veteran also completed on iPhone SE and iPad, and the Rookie on Android.
- **Mouse only:** both AI levels and hot-seat completed on desktop. Nothing needed hover.
- Every Brace prompt, cover, coach tip, loot sheet and dock was reachable by tap. The only reported out-of-viewport buttons were Line chips inside the Line scroll list.
- **Needs a real device:**
  - Real Safari/WebKit: WebKit isn't installed here, so iOS was emulated in Chromium with an iOS UA.
  - The notch safe area: `env(safe-area-inset-*)` is 0 in Chromium. The shell sets `viewport-fit=cover` and pads by the insets, and the layout tests use notch insets headless.
  - The iOS Add-to-Home / rotate prompt behaviour.
- Screens checked by eye: setup, match (act, Brace, rival playback, gas closing), cover, coach tip, pause, end, dev panel, survey and loader. Findings: BUG-04 (missing glyphs), BUG-05 (Brace panel truncation on small phones) and BUG-09 (empty space on iPad).

## 3. Resume (iPhone 13 touch vs Veteran; desktop 1280 mouse vs Rookie)

| Case | Before | After CONTINUE | Result |
|---|---|---|---|
| Page reload mid-turn (round 3, an action already taken this turn) | 46 actions, act | 46 actions, act. The Title shows "Round 3 · vs Veteran AI · saved just now". | pass |
| Phone lock: `visibilitychange` (hidden) + `pagehide`, page killed 0.5 s later, reopened in the same browser profile | 85 actions, round 5 | 85 actions, round 5, act | pass |
| Page killed about 0.2 s after an action, with no lifecycle event | 86 actions | 86 actions | pass (the save reached IndexedDB in time) |
| Reload **mid-Brace** (iPhone 13; Brace prompt up, "YOU TAKE 3 HITS · HEALTH 5 → 2") | 19 actions, brace | 19 actions, brace; the same prompt and suggested card are back | pass (done twice) |
| Reload mid-Brace (desktop 1280, lethal shot "YOU TAKE 3 HITS · YOU'RE OUT") | 134 actions, brace | 134 actions, brace | pass |
| Each resumed match then finished | | | pass. The save was cleared at the end (`has_match: false`). |

Hot-seat resume at a pending cover and at a pending Brace (prompt only after its cover) is covered by `test_hotseat_save.gd` (4 tests, all pass).

*Not reproduced:* in the first iPhone mid-Brace run, after the resume and the Brace, 15 taps on hand cards did not open the action dock for about 3 turns. The match then continued and finished. A second run with diagnostics, the same device and the same flow, had 0 misses, and no other run had any. I filed no bug. Watch for it in cz21.

## 4. No private-info leaks

| Channel | How it was checked | Result |
|---|---|---|
| **To the AI** | `test_ai.gd`: `test_hidden_opponent_cards_never_change_the_move` (105 decisions with the opponent's private cards changed) and `test_held_card_identity_is_not_read`. `test_ai_public_api.gd`: `test_ai_calls_no_private_engine_function` and `test_public_view_and_helpers_match_the_full_view`. Soak fairness: 18,520 view checks. | **pass** |
| **To the screen, AI matches** | In the browser, the driver checked every view and every event emitted to the human (instance level). No card instance that sits in the rival's hand or loadout appears anywhere in them, outside public Brace reveals. The opponent block never holds hand, loadout, held or next-hand lists. It also walked the whole node tree for the rival's unknown card names. Card-type walks never "arm" with the shipping content, because every card type is public in the piles, so the instance check is the one that bites. | **0 leaks**: 1,162 instance checks, all armed, over 5 matches (iPhone SE, Android, iPad, desktop 1920, desktop 1280 hot-seat). The 3 earlier iPhone 13 matches ran the name walk only, also with 0 leaks. |
| **To the screen, hot-seat** | The same checks, plus the cover state: no private list and no hand or next cards are on screen under the cover. On iPhone 13 the walk ran 337 times, 8 of them armed (marker-free live content). `test_hotseat_fairness.gd` also passes with marker cards. | **0 leaks** |
| **To the playtest log** | Each match's `user://playtest_log.jsonl` was downloaded and scanned. In AI matches, no `hand_ids`, `hold_ids` or hand, loadout, held or next lists appear for seat `ai`. AI Braces log only the revealed cards. In hot-seat matches, both seats log `hand_ids: []` and `hold_ids: []`. `test_playtest_log.gd::test_logger_reads_eventbus_data_only` passes. | **0 issues** in 9 logs, 1,172 lines |

## 5. Load time (artifact-style build: `engine.gz.wasm` + `game.pck.wasm`)

The build was made by `tools/package_artifact_build.sh` into a scratch directory and served locally. Each run used a fresh browser context, so the cache was cold, with CDP `Network.setCacheDisabled` and the Chrome DevTools throttling presets. The time is measured from navigation to "Title: ready"; the consent prompt is up 0–0.1 s later. Each run transferred **10.14 MB**, of which `engine.gz.wasm` is 9.40 MB.

| Profile | Desktop 1280 (2 runs) | iPhone 13 (2 runs) | iPhone SE (2 runs) | Target < 10 s |
|---|---|---|---|---|
| No throttling (local, Wi-Fi-class) | 2.03 s / 1.88 s | 1.97 s / 1.87 s | 2.00 s / 1.86 s | **pass (DoD 1)** |
| "4G" (9 Mbps × 0.9, 165 ms RTT) | 12.99 s / 13.01 s | 13.11 s / 13.50 s | – | **fail (BUG-01)** |
| "Fast 3G" (1.6 Mbps × 0.9, 562 ms RTT) | 60.2 s / 60.1 s | 60.1 s / 60.4 s | – | **fail (BUG-01)** |

The loading screen shows real progress (for example, "Downloading CardZone 50%" at 6 s on 4G). It also warns: "About 10 MB to download once. On mobile data this can take 10–20 seconds." Screenshot: `qa/screenshots/cz19-loader-4g-6s-iphone13.png`. Software rendering adds roughly 1.5 s of compile time that a real GPU mostly won't. The real-iPhone Wi-Fi number belongs in `qa/performance-logs/web-load.md` once cz20 builds the RC; it **needs a real device**.

## 6. Other checks

| Item | Result |
|---|---|
| **Dev panel** | **Pass.** A 2 s hold on the "CardZone" logo opens it; a 1 s hold does not. Every §16.8 key is offered with only its allowed values. **Hand 4 also sets drop cost 3**: the note reads "Hand Size set to 4 for new matches. Supply drop cost set to 3 with it (spec §16.4a)." The next new match ran with `hand_size 4, supply_drop_cost 3`. The title and setup show "DEV SETTINGS ACTIVE", and RESET ALL clears it. *Note:* the plan asked for "5 taps on the version"; the build uses a long press on the logo. The playtest guide should say so. |
| **cz07b switches on the dev panel** | **Not exposed.** `no_shooting_round1` and `p2_start_health_bonus` exist in `BalanceConfig`, the rules and the AI, but not in `dev_panel_overrides.gd` GROUPS. Logged as BUG-03 (minor); the head may choose one in `cz-q2`. |
| **Coach tips** | **Pass.** First matches showed all 4 tips (HOLD, BRACE, DOWN, ADRENALINE; `coach_seen` = 4), each when its situation first came up: HOLD at the first Pack, BRACE at the first Brace prompt (screenshot in the run logs, "TIP · BRACE 1 / 4"). Each was dismissed by touch (GOT IT). After the reloads in §3, no tip was shown again (`coach_seen` stayed at 4). SKIP ALL TIPS is covered by `test_coach_pause_end.gd`. |
| **Pause menu / concede** | **Pass.** MENU → CONCEDE… → confirm (KEEP PLAYING / CONCEDE) → "THE RIVAL WINS · CONCEDE · You conceded." |
| **End screen** | **Pass.** It shows the winner, the cause, rounds, turns, health and Hits landed, with SEE BOARD, TITLE and NEW MATCH. Hot-seat shows **"PLAYER 2 WINS"** (2 matches). The detail lines in hot-seat still say "you" and "rival" (BUG-06). |
| **Playtest survey and Download log** | **Pass.** Consent prompt → PLAYTEST → 5 rated questions plus 1 optional open question → SUBMIT → "THANKS FOR PLAYING!" → DOWNLOAD LOG. This saved `cardzone-playtest-2026-11-04-<sid>.json` (9.3 KB, format `cardzone-playtest-log`, 57 events, including the `survey` event). `tools/kpi_sheet.py` reads the downloaded file. The consent text says "5 quick questions" (BUG-08). |
| **Fonts and the OFL licence in the build** | **Pass.** `assets/fonts/OFL-Barlow.txt` and `OFL-ShareTechMono.txt` are inside `index.pck` / `game.pck.wasm` (the export preset's `include_filter`), next to the 3 TTFs. There is no in-game credits line; OFL does not require one. Two glyphs the build uses are missing from the fonts (BUG-04). |
| **FPS** | **Needs a real device.** SwiftShader with no GPU measured: on desktop 1280, Title 18–22 fps, idle match 12–14, rival playback 10–18; on iPhone 13 emulation at @3x, Title 6–8, idle match 5, playback 3–19. These numbers say nothing about real hardware. The idle match is slower than the Title, which suggests continuous redraw (as in CallingCard). The cz17 FxBench in headless llvmpipe at phone logical size gives an average of 42.5 fps (1% low 17.6). Check on a real iPhone for 30+ fps and battery use. |
| **AI think time** | Desktop: worst 91 ms per turn in the sweep and 50.9 ms in `test_ai_matches`. **Needs a real device** for the < 300 ms iPhone 12 gate. |
| **Build label** | The Title shows "Prototype · Godot 4.4.1-stable (official)", with no build version or date yet. That is cz20's scope; it is listed here so cz20 does not miss it. |

## 7. IP and originality

| Item | Result |
|---|---|
| Franchise, publisher and studio names | **Pass.** I grepped every `.gd`, `.tscn`, `.tres`, `.svg`, `.md`, `.html` (the web shell), `.json`, `.cfg`, `.sh` and `.py` under `projects/cardzone/`, case-insensitively, for 60+ terms: battle-royale franchises and their maps, modes, characters and catch-phrases, the publishers and studios, and real gun makes and models. **No hit in the game, data, shell or art.** The only hits: `test_art_kit.gd`'s own banned-word list, and the lower-case genre word "warzone" in three internal design docs (market scan, DESIGN_REVIEW). Neither ships. |
| Names in the game | Card, area and zone names are generic: Scrap SMG, Pump Shotgun, Twin-Drum LMG, Longshot .50, Plate Vest, Docks, Farmstead, Quarry, Radio Hill, Motel, Rail Yard, Old Town, "Gas closes" and "Final circle I–III". The island is the fictional Ridge Hollow. The theme is generic battle royale. |
| Logos and likenesses | **Pass.** All 93 SVGs are hand-written geometry: no `<image>`, no external `href`, no editor metadata. Card art is procedural. |

## 8. Bug list

### BUG-01 · Major · Load time is over 10 s on 4G and Fast 3G
- **Owner:** packaging
- **Repro:**
  1. Run `tools/package_artifact_build.sh <godot> <out>` and serve `<out>`.
  2. In Chromium, open `index.html` with the cache disabled and the "4G" or "Fast 3G" preset.
  3. Time from navigation to "Title: ready".
- **Expected:** under 10 s (the plan's web target).
- **Actual:** 13.0–13.5 s on 4G and 60.1–60.4 s on Fast 3G; 1.9–2.0 s unthrottled. 10.14 MB is downloaded, of which 9.40 MB is `engine.gz.wasm`.
- **Note:** DoD 1 is "on Wi-Fi" and passes. The loader honestly says "10–20 seconds" on mobile data. The fixes are a size-optimised export template (no 3D, only the modules used) and/or `wasm-opt -Oz`. CallingCard has the same issue (cc17 BUG-01).

### BUG-02 · Major · First-player win rate 62% and eliminations from round 3 at the defaults (DoD 6)
- **Owner:** data (balance; decision `cz-q2` with the head)
- **Repro:** `godot --headless --path . -s res://tests/tools/ai_sweep.gd`
- **Expected:** first player 45–55%, no elimination before round 6 (spec goal), both out < 10%, median 9–12.
- **Actual:**
  - Hand 5: 67/108 (62.0%), earliest elimination round 3, both out 6.5%, median 12.
  - Hand 4: 61.1%, both out 11.1%, median 13.
  - In the browser, 4 of the 9 matches ended in round 3. Both AI levels loot a Pump Shotgun in round 1 and shoot the moment they share an area (screenshots `cz19-brace-arrow-missing-glyph-iphone13.png` and `cz19-ipad-brace-empty-space.png`, both in round 1).
- **Note:** this matches balance-log Entries 2 and 3 exactly. The cz07b switches (`no_shooting_round1`, `p2_start_health_bonus`) are built and off; the head's `cz-q2` choice decides. It is not a code bug.

### BUG-03 · Minor · The dev panel does not expose the cz07b switches
- **Owner:** ui
- **Repro:**
  1. Title: hold the logo for 2 s.
  2. Scroll the DEV SETTINGS list.
- **Expected:** rows for `no_shooting_round1` and `p2_start_health_bonus`, so the playtest can try them without a rebuild.
- **Actual:** the panel has every §16.8 key but neither switch, because `dev_panel_overrides.gd` GROUPS omits them. They are reachable only through `ai_sweep.gd --set` and tests.
- **Screenshot:** `qa/screenshots/cz19-devpanel-hand4-no-cz07b-iphone13.png`
- **Note:** the head may pick one in `cz-q2` instead.

### BUG-04 · Minor · "✓" and "→" render as empty boxes in the web build
- **Owner:** ui (fonts; with art)
- **Repro:** open MATCH SETUP, the dev panel, or any Brace prompt.
- **Expected:** a check mark on the selected option and an arrow in "HEALTH 5 → 3" and "Duck (1) → 2 Hits".
- **Actual:**
  - Barlow, Barlow Condensed and Share Tech Mono have no U+2713 or U+2192, and the web build has no system fallback, so both show as tofu boxes.
  - Selected setup choices read "▯ ROOKIE AI".
  - The Brace prompt's key result line reads "YOU TAKE 2 HITS · HEALTH 5 ▯ 3".
  - Sources: `setup_ui.gd` and `dev_panel.gd` (✓); `match_screen.gd:1065`, `:1072` and `:1076` (→).
- **Screenshots:** `qa/screenshots/cz19-setup-checkmark-missing-glyph-iphone13.png`, `qa/screenshots/cz19-brace-arrow-missing-glyph-iphone13.png`
- **Fix:** use characters the fonts have ("->", "to", "•"), or an icon.

### BUG-05 · Minor · The Brace panel truncates its key lines on small phones
- **Owner:** ui
- **Repro:** on iPhone SE (667×375) or Android (640×360), get shot by the AI.
- **Expected:** the whole prompt is readable: the source, the damage sum and the result ("YOU TAKE N HITS · HEALTH a → b").
- **Actual:**
  - "INCOMING · PUMP SHOTGUN FROM …" and "DMG 3 – Cover 0 – Down 0 = 3 da…" are cut off.
  - The result line is cut to "YOU TAKE 2 HITS · HE…" (iPhone SE) or "YOU TAKE 3 HITS · HEA…" (Android), so the health after the Brace (a DoD 8 element) is hidden.
  - The panel has room below: the text column is narrow because the two buttons take the right third.
  - The confirm button does still say "BRACE · 2 HITS".
- **Screenshot:** `qa/screenshots/cz19-brace-panel-truncated-android.png`

### BUG-06 · Minor · The hot-seat end screen details say "you" and "rival"
- **Owner:** hotseat
- **Repro:** play a hot-seat match to the end (e.g. Player 1 dies in the gas).
- **Expected:** seat names in every line ("Player 1 was caught in the gas", "health: P1 0, P2 2", "Hits landed on P1 …").
- **Actual:** the title is right ("PLAYER 2 WINS"). The detail lines are "You were caught in the gas." and "health: you 0, rival 2 · Hits landed: on the rival 0, on you 2". `end_screen.gd` handles hot-seat only for the title (lines 98–99), not lines 112 and 132–133. With the phone passed around, "you" is ambiguous.
- **Screenshot:** `qa/screenshots/cz19-hotseat-end-you-rival-iphone13.png`

### BUG-07 · Minor · The test runner reports PASS for a test that hit a script error
- **Owner:** rules (test infrastructure, `tests/run_tests.gd`)
- **Repro:** in any `test_*` method, make an assertion and then call a function with a wrong argument type. (This happened in my first draft of `test_release_rules.gd`, when a non-CzAI was passed to a `CzAI` parameter.)
- **Expected:** FAIL.
- **Actual:** the runner printed `SCRIPT ERROR: Invalid type in function '_play'` and then `PASS`. GDScript returns from the method on the error, and the runner's only guard is "no assertions ran". A test that errors after its first assertion therefore passes, and the suite total can hide aborted tests.
- **Fix:** have each test set a `completed` flag at its end, or count `push_error` / script errors during the call, and fail on either.

### BUG-08 · Cosmetic · The consent text says "5 quick questions"; the survey has 6
- **Owner:** playtest
- **Repro:** first launch → consent text; then PLAYTEST.
- **Expected:** the same count in both.
- **Actual:** the survey shows "Question 1 of 6"; the 6th is the optional open question. Also, a tester who only played hot-seat is still asked "The AI played fair."

### BUG-09 · Cosmetic · iPad: the match screen leaves large empty areas
- **Owner:** ui
- **Repro:** iPad landscape 1180×820, any match, get shot.
- **Expected:** the extra height is used: a bigger map and Line, or a shorter Brace panel.
- **Actual:**
  - The map sits small in the middle of the left column, with about 250 pt empty above it.
  - The Brace panel fills the lower half with about 60% empty space.
  - Everything works; it just looks unfinished on the tablet.
- **Screenshot:** `qa/screenshots/cz19-ipad-brace-empty-space.png`

## 9. Other observations (no bug filed)
- The headless runner still ends with "ObjectDB instances leaked" and "2 resources still in use". The exit code is 0.
- The plan's dev-panel trigger ("5 taps on the version") differs from the build (a 2 s hold on the logo). Both are hidden. Update the playtest guide.
- Opening hands are deterministic, so the same policy against the same AI gives the same game on every device. It did: Rookie 135 actions / round 9 on iPhone 13 and desktop; Veteran 73 actions / round 3 on 4 devices. That is consistent, but the playtest will see little variety until the route or first player changes.
- `tools/kpi_sheet.py` writes `playtest-logs/kpi/` inside the repo by default. I ran it once on the downloaded log and then deleted that output.

## Files
- Report: `projects/cardzone/documentation/qa/release-check.md`
- New regression test: `projects/cardzone/source/project-cardzone/tests/test_release_rules.gd` (1 test: 48 AI games under the spec §16 oracle, about 60 s)
- Screenshots: `projects/cardzone/qa/screenshots/cz19-*.png` (7 files)
- Scratch only, not in the repo: the scratch project with `qa_driver.gd`, plus `qa.js`, `match.js`, `resume.js`, `extras.js`, `loadtime.js`, `fps.js`, `logcheck.py` and the run logs, in the session scratchpad under `cz19/`.

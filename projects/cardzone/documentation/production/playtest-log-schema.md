# CardZone playtest log schema (cz18)

**Source of truth:** `source/project-cardzone/autoload/playtest_log.gd` (`SCHEMA`, `ENUMS`, `validate_entry()`). The test `tests/test_playtest_log.gd` checks every logged line against it, and `tools/kpi_sheet.py` reads the same constants. If this file and the code disagree, the code wins, so update this file.
**Schema version:** 1. **Consent version:** 1.
**KPIs and bars:** `prototype-milestone-plan.md` §8. Recipes are in §5 below.

## 1. How it is collected
- **Opt-in, off by default.** On the first launch, a consent prompt (`scenes/survey/ConsentPrompt.tscn`) appears over the title. Logging starts only after **YES, LOG MY SESSION**. **NO THANKS** is remembered, and nothing is written. The **PLAYTEST** button in the title's top-right corner opens `scenes/survey/Survey.tscn`. From there the tester can turn logging on later, answer the survey, press **DOWNLOAD LOG**, or press **STOP LOGGING & DELETE**, which turns logging off and deletes the log.
  - The PLAYTEST corner button belongs to the logger, so no title code is needed. If the title has its own node named `PlaytestButton`, the logger skips its corner button. Other screens, such as cz13's end screen, can call `PlaytestLog.open_survey()`.
- **EventBus only.** No gameplay code calls the logger. It listens to `screen_shown`, `rules_event`, `match_ended` and three signals cz18 added to EventBus:
  - `match_context(info)`: setup facts, emitted once per start or resume;
  - `match_view_changed(view)`: the human's view after every action;
  - `coach_step(step, skipped)`: for cz13's coach to emit.
  The match controller emits the first two through additive calls in `match_controller.gd` (`_emit_context`, `_emit_view`). Game behaviour is unchanged.
- **Human view only.** The controller sends `rules_event` already filtered by `LoadoutRules.events_for(human)` and `match_view_changed` as `LoadoutRules.view(state, human)`. The logger never reads the match state; a test checks its code for this. As a result, the AI's hand, held cards and loadout order never reach the log. Card ids for instance ids come from a cache filled from those views.
  - AI lines carry only public facts: played and looted cards, its line, shots, and Brace cards once revealed.
  - An AI `turn_start` always has `hand_ids: []`.
- **Pack step.** The match screen's `option_pressed(&"end_turn")` (the first END TURN press) marks the start of the Pack step, and the logger connects to it itself. Without that signal, `pack_ms` is measured from the human's last action, and `pack_from` records which method was used.
- **Storage:** JSON lines in `user://playtest_log.jsonl` (IndexedDB on the web). The file rotates at 1 MB with one backup. The consent answer and the last survey answers are kept in `user://playtest_consent.cfg`.
- **Download log:**
  - On the web, the browser downloads `cardzone-playtest-<date>-<sid>.json` through `JavaScriptBridge.download_buffer` (a Blob and an anchor click, MIME `application/octet-stream`, so iOS Safari saves the file instead of opening it).
  - On desktop builds, the same file is written next to the log.
  - The file is one JSON document: `{format: "cardzone-playtest-log", schema_version, exported_utc, session_ids[], event_count, events[]}`. `events` holds every line on the device, oldest first. A reload starts a new session, and the download holds both sessions.
- **Privacy:**
  - The only identifier is `sid`: 6 random bytes in hex, created fresh at each launch and linked to no account.
  - Never collected: names, emails, IPs, location, raw user agent or hardware IDs.
  - The only free text is the optional open survey answer. It is capped at 500 characters, control characters are stripped, and the screen asks testers to leave out personal details.

## 2. Common fields (every line)
| Field | Type | Meaning |
|---|---|---|
| `v` | int | Schema version (1) |
| `sid` | string | Anonymous session id (random per launch) |
| `seq` | int | Line number within the session, from 0 |
| `t_ms` | int | Milliseconds since the session started (monotonic) |
| `event` | string | Event name (below) |

Types: `s` string, `i` int, `n` number, `b` bool, `a` array, `d` object, `?` nullable.
- Seats are `human` / `ai`. In hot-seat mode, `ai` means the seat the controller isn't showing.
- Results are `win` / `loss` / `draw` from the human's view.
- Card lists (`hand_ids`, `hold_ids`, `cards`, `brace_cards`, `attachments`) hold card ids, never instance ids. The validator rejects anything else.
- `round` is the round in progress (0 before the drops).

## 3. Events

### Plan §8 events
| Plan name | Logged event | Fields | Feeds KPI |
|---|---|---|---|
| `session_start(load_ms, input_type, viewport, browser)` | `session_start` | `schema i, consent_version i, load_ms i (page start to engine ready, performance.now() on the web), input_type s (touch\|mouse), viewport a [w,h logical px], window_px a, pixel_ratio n, browser s (chrome\|safari\|firefox\|edge\|other, "" off the web), os_family s (ios, android, macos, windows, linuxbsd, …), web b, mobile b, touchscreen b, device_class s (phone\|tablet\|desktop), engine s, build s, date_utc s` | **Load** (< 10 s on iPhone sessions: `os_family = ios`, `device_class = phone`). Written when consent is given, so it is always the first line of a session. |
| `match_start(mode, ai_level, first_player, route, drop_human, drop_ai, hand_size, tunables_hash)` | `match_start` | `match i (match number this session), mode s (ai\|hotseat), ai_level s (rookie\|veteran\|…), first_player s, human_seat i, route s (A\|B\|C), drop_human s, drop_ai s, hand_size i, tunables_hash s, tunables d (BalanceConfig.snapshot()), setup_s n (match start to round 1, i.e. the drops), play_again b (no title screen since the last match_end)` | **Replay intent** (≥ 2 per tester); tunables per match. Written at round 1, when both drops are known (or at the end, for a match conceded during the drop). |
| `round_start(round, zone_card, health_h, health_ai, bounty)` | `round_start` | `round i, zone_card i, health_h i, health_ai i, bounty s (human\|ai\|none)` | **Comeback** (`health_h` in round 4). Health is at the round's start, before the final-circle Hits (those follow in `final_circle`). |
| `turn_start(seat, round, hand_ids, hits_drawn)` | `turn_start` | `seat s, round i, turn i (turn number this match), hand_ids a (the human's own draw; [] for the AI), hits_drawn i` | Turn context, Hits in the draw |
| `card_play(card_id, as)` | `card_play` | `seat s, card_id s, as s (effect\|adrenaline_move\|adrenaline_search), round i` | *Telemetry:* Adrenaline Move vs Search |
| `move(from, to)` | `move` | `seat s, from s, to s, round i` | Movement |
| `loot(card_id, pile\|drop\|crate, cost)` | `loot` | `seat s, card_id s, source s (pile\|drop\|crate), cost i, area s, round i` | *Telemetry:* loot per pile |
| `shot(weapon_id, attachments, target, raw, cover, down, brace_cards, brace_total, hits, bounty_claim, suppressor)` | `shot` | `shooter s, kind s (shot\|frag), weapon_id s, attachments a, target s, raw i (printed damage + attachments, from CardDB), cover i, down i, damage i (before Brace), suppressor b, brace_allowed b (damage > 0 and no Suppressor), brace_cards a (revealed), brace_total i, hits i (after Brace), bounty_claim b, bounty_heal i, eliminated b, round i` | **Hidden-armour check** (the human's shots at the AI with `brace_allowed`: share with `hits = 0`); *telemetry:* damage vs Brace, Down / Bounty shots. A Frag writes one line per target. The line is written when the shot has resolved (after the Brace, Hits, Bounty claim and elimination). |
| `brace(prompt_ms, cards, suggested_used)` | `brace` | `kind s (shot\|frag), prompt_ms i (Brace prompt shown to BRACE), cards a, card_count i, total i, damage i, hits i, eligible i (cards in the next hand that can brace), possible b (eligible > 0), suggested_used b? (null: no suggestion shown, see quirk 3), round i` | **Brace used** (`possible = true`: share with `card_count ≥ 1`). The human's Brace only. |
| `patch_up` | `patch_up` | `seat s, healed i, health i, round i` | Healing |
| `ditch(card_id)` | `ditch` | `seat s, card_id s, round i` | Ditch use |
| `gas_hit` | `gas_hit` | `seat s, area s, hits i, health i, round i` | Gas damage |
| `pack(hold_ids, hold_count, pack_ms)` | `pack` | `hold_ids a, hold_count i, pack_ms i, pack_from s (pack_step\|last_action), line_stowed i, hand_stowed i, round i` | **Pack time**, **Hold used**; *telemetry:* holds 0/1/2 and what was held. The human's packs only. |
| `turn_end(turn_ms, undo_count)` | `turn_end` | `turn_ms i (the human's draw to End turn), undo_count i, round i, turn i` | **Human turn time** |
| `elimination(seat, round, by)` | `elimination` | `seat s, round i, by s (shot\|frag\|gas\|final_circle)` | **Early elimination** (the human before round 6) |
| `match_end(result, rounds, duration_s, cause, health_h, health_ai)` | `match_end` | `match i, result s, rounds i (last round), duration_s n (from match start or resume, see quirk 2), cause s (shot\|frag\|gas\|final_circle\|hard_end\|concede), health_h i, health_ai i, mode s, ai_level s, resumed b, human_turns i` | **Match length**, **Comeback**; *telemetry:* results by AI level, by drop area |
| `match_resumed(age_s, actions)` | `match_resumed` | `match i, age_s n (since the save; -1 unknown), actions i (logged actions so far), round i, mode s, ai_level s` | **Saves** (resumes vs lost matches) |
| `coach_step(step, skipped)` | `coach_step` | `step s, skipped b` | Coach use (cz13 emits `EventBus.coach_step`) |
| `survey(answers)` | `survey` | `q1..q5 i? (1-5, null = skipped), open s, answered i` | **Survey** bars |
| `quit(screen)` | `quit` | `screen s, session_s n, reason s (close\|pagehide)` | Where sessions end |

### Additional events
| Event | Fields | Why |
|---|---|---|
| `consent` | `given b` (always true; a "no" writes nothing) | Marks the opt-in |
| `input_type` | `kind s (touch\|mouse\|keyboard\|gamepad)` | Written the first time each input kind is used. `session_start.input_type` is only a guess from touch support. |
| `screen` | `name s` | Each screen change (`title`, `match`, `survey`, cz13's screens); the funnel and the quit screen |
| `attach` | `seat s, attachment_id s, weapon_id s, round i` | Attachment use |
| `final_circle` | `step i, hits i, health_h i, health_ai i, round i` | Final-circle damage (health after) |
| `log_exported` | `method s (download\|file), bytes i` | The tester pressed Download log |
| `app_hidden` / `app_visible` | `screen s, session_s n` | Tab switch, app background or phone lock. On a phone this is often the last line instead of `quit`. |

## 4. Known quirks (read before analysing)
1. **Reloads make new sessions.** Each launch has a new `sid`. A resumed match therefore starts its session with `match_resumed` and has no `match_start`, and the match number (`match`) restarts at 1. Group sessions by file (one tester's download) and number matches across them (`tools/kpi_sheet.py` does this).
2. **`duration_s` after a resume** covers only the resumed part. Leave resumed matches out of the match length median, but keep their `rounds`.
3. **`brace.suggested_used`** (cz12): true when the human braced with exactly the suggested cards (order ignored), false otherwise. The match controller adds `brace_prompt.suggested` (instance ids, from `scripts/match/brace_advisor.gd`) to the view it emits through `EventBus.match_view_changed`, so the logger reads it with no change. An empty suggestion (nothing in the next hand can brace) logs true when the human takes the Hits. Logs from builds before cz12 have null here.
4. **Pack time without the screen.** If the logger can't find the match screen's `option_pressed`, `pack_ms` is measured from the human's last action (`pack_from: last_action`). The KPI sheet counts these lines.
5. **Event pacing.** Lines are timed when the screen announces the event, not when the engine applied it. Since cz12 only the steps the rival is involved in are paced (Event speed x step weight; FAST and SKIP shorten them); the human's own actions answer at once. `turn_ms` and `prompt_ms` are what the human saw.
6. **Consent comes after the title.** `session_start`, `consent` and `screen` (the current screen) are written when consent is given. If a tester opts in later from PLAYTEST, earlier events are missing.
7. **Hot-seat** (`mode: hotseat`) is logged from the controller's viewing seat. The KPI bars use only `mode: ai` matches.
8. Logging is off in headless runs (tests, CI and tools) unless they turn it on, so test runs never write to a real log.

## 5. KPI recipes (`tools/kpi_sheet.py`, per tester and pooled)
| KPI | Pass bar | Recipe |
|---|---|---|
| Pack time | median ≤ 10 s, 90th pct ≤ 20 s | `pack.pack_ms` over the human's packs in matches vs the AI (90th percentile by nearest rank) |
| Human turn time | median ≤ 60 s | `turn_end.turn_ms` |
| Match length vs AI | median 12-20 min, last round 8-14 | `match_end.duration_s` (not resumed), `match_end.rounds` (all); conceded matches left out |
| Early elimination | ≥ 90% of matches | a finished match is safe unless `elimination(seat = human, round < 6)` |
| Comeback | ≥ 1 in 3 | matches with `round_start(round = 4).health_h ≤ 3` that end in `result = win` or reach `rounds ≥ 10` |
| Hold used | ≥ 60% | `pack.hold_count ≥ 1` in the tester's 2nd match onward (numbered across sessions; a resumed part keeps its number) |
| Brace used | ≥ 50% | `brace` with `possible = true` and `card_count ≥ 1` |
| Hidden-armour check (Q3) | ≤ 35% | `shot` with `shooter = human, target = ai, brace_allowed = true` and `hits = 0` |
| Replay intent | ≥ 50% of testers | ≥ 2 `match_start` per tester. Whether they were "asked twice" goes in the organiser's notes. |
| Survey | 4 or 5 counts | q1 "I want to play another match." ≥ 70% · q2 "I understood why I took damage." ≥ 70% · q3 "Packing felt quick." ≥ 70% · q4 "My choices mattered more than luck." ≥ 70% · q5 "The AI played fair." ≥ 60%. The last survey per tester counts. |
| Load | every iPhone session < 10 s | `session_start.load_ms` where `os_family = ios` and `device_class = phone` |
| Saves | 0 lost | A session that ends mid-match, followed in the same download by a session that starts a new match before any `match_resumed`, counts as a suspected lost match. |

**Telemetry (no bar):**
- holds 0/1/2 and the most-held cards;
- Adrenaline Move vs Search;
- shots with Down in play and with a Bounty claim, and Bounty heals;
- damage, Brace and Hits per shot, for each shooter;
- loot by source and the most-looted cards;
- results by the human's drop area and by AI level;
- end causes;
- hand size and tunables hash per match;
- coach steps seen or skipped.

Survey scale: 1 = Strongly disagree … 5 = Strongly agree. Open question: "Is there anything else you'd like to tell us about the game?" (optional; the screen asks testers to leave out names and personal details).

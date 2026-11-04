# CallingCard playtest log schema (cc16)

**Source of truth:** `source/project-callingcard/autoload/playtest_log.gd` (`SCHEMA`, `ENUMS`, `validate_entry()`). The test `tests/test_playtest_log.gd` checks every logged line against it. If the two disagree, the code wins, so update this file.
**Schema version:** 1. **Consent version:** 1.
**KPIs:** vision.md §8 and the pass bar in prototype-milestone-plan.md §8.

## 1. How it is collected
- **Opt-in, off by default.** On the first launch, a consent prompt appears over the Title (`scenes/survey/ConsentPrompt.tscn`). Logging starts only after **YES, LOG MY SESSION**. **NO THANKS** is remembered, and nothing is written. The hub's **PLAYTEST** screen (`scenes/survey/Survey.tscn`) can turn logging on later. Its **STOP LOGGING & DELETE** option turns logging off and deletes the log.
- **Listens to EventBus only.** No gameplay code calls the logger.
- **Storage:** JSON lines in `user://playtest_log.jsonl` (IndexedDB on the web). The file rotates at 1 MB with one backup. The consent answer and the last survey answers are kept in `user://playtest_consent.cfg`.
- **Download log** (on the PLAYTEST screen, after the survey):
  - On the web, the browser downloads `callingcard-playtest-<date>-<sid>.json` through `JavaScriptBridge.download_buffer` (Blob plus an anchor click).
  - On desktop, the same file is written next to the log.
  - The file is one JSON document: `{format: "callingcard-playtest-log", schema_version, exported_utc, session_ids[], event_count, events[]}`. `events` holds every line on the device, oldest first.
- **Privacy:**
  - The only identifier is `sid`, 6 random bytes in hex, created fresh each launch and linked to no account.
  - Not collected: names, emails, IPs, location, raw user agent or hardware IDs.
  - The only free text is the optional open survey answer. It is capped at 500 characters, control characters are stripped, and the screen asks testers to leave out personal details.

## 2. Common fields (every line)
| Field | Type | Meaning |
|---|---|---|
| `v` | int | Schema version (1) |
| `sid` | string | Anonymous session id (random per launch) |
| `seq` | int | Line number within the session, from 0 |
| `t_ms` | int | Milliseconds since the session started (monotonic) |
| `event` | string | Event name (below) |

Types: `s` string, `i` int, `n` number, `b` bool, `a` array, `d` object, `?` nullable. Sides are always `player` / `rival`. Duel results are `win` / `loss` / `draw` from the player's view; a **draw is its own result**, because Tempo ties count as draws.

## 3. Events

### Plan §8 events
| Plan name | Logged event | Fields | Feeds KPI |
|---|---|---|---|
| `session_start(load_ms, input_type, viewport, browser)` | `session_start` | `schema i, consent_version i, load_ms i, input_type s (touch\|mouse, from touch support), viewport a [w,h logical px], window_px a, pixel_ratio n, browser s (chrome\|safari\|firefox\|edge\|other\|"" off-web), os_family s, web b, mobile b, touchscreen b, device_class s (phone\|tablet\|desktop), engine s, build s, date_utc s` | **Load < 10 s** (`load_ms`: page start to engine ready, from `performance.now()` on the web); phone vs desktop split. Written at consent time, so it is always the first line. |
| `entry_point(lobby\|menu)` | `entry_point` | `entry s (menu = ENTER THE WALL → hub, lobby = FIND A MATCH → Lobby Duel), screen s` | Plan split: 2 testers start from the menu and 2 from the Lobby Duel |
| `album_open(page)` | `album_open` | `page s, count i (album opens this session)` | **Album pull:** opens the album at least twice (`max(count) ≥ 2`) |
| `card_inspect(card_id, owned)` | `card_inspect` | `card_id s, owned b, screen s (album\|lineup\|duel)` | **Album pull:** inspects a card they don't own (`owned = false`, usually `screen = album`) |
| `lineup_saved(...)` | `lineup_saved` | `card_ids a, clearance i, signature_id s, loaner b` | *Live:* share who equip a non-default lineup |
| `duel_start(source, rival, first_player)` | `duel_start` | `source s (rival\|lobby\|dossier), rival s (rival id, or the Dossier id when source = dossier), first_player s, duel i (duel number this session), play_again b` | Duel counts per source; *Live:* Banner Wall sessions per matchmaking wait (`source = lobby`) |
| `placement(card_id, slot, captures, preview_shown)` | `placement` | `side s, card_id s, slot s (a1..c3), captures a (slots flipped), preview_shown b, turn i, duel i` | Capture-preview use; how readable the rules are (captures per move) |
| `carded(by)` | `carded` | `by s, card_id s, duel i` | Signature drama ("Carded!" frequency) |
| `triptych_scored(id, first_time)` | `triptych_scored` | `side s, id s, first_time b, duel i` | Triptych discovery (see quirk 3) |
| `duel_end(result, score_p, score_ai, turns, duration_s)` | `duel_end` | `result s (win\|loss\|draw), score_p i, score_ai i, turns i, duration_s n, source s, rival s, duel i, resumed b, play_again b, captures_p i, captures_ai i, carded_p i, carded_ai i, triptychs_p i` | **Session fit:** median duel < 4 min (`duration_s`, source ≠ dossier, resumed = false); win / loss / draw balance per rival |
| `lobby_wait_start(wait_s)` | `lobby_wait_start` | `wait_s n` | *Live:* sessions per matchmaking wait |
| `lobby_match_found(duel_state, choice)` | `lobby_match_found` | `choice s (keep\|save), duel_state d {in_duel b, placements i, score_p i, score_ai i, source s}` | Lobby fit: whether the duel was finished in time and keep vs save |
| `duel_resumed(age_s)` | `duel_resumed` | `age_s n, duel i, rival s` | Save / resume use and how long saved duels wait |
| `unlock(card_id\|title\|frame)` | `unlock` | `kind s (card\|title\|frame), id s, source s (UnlockGoal or Dossier id for cards, "" otherwise)` | **Intent to collect** (behaviour side); chase loop progress |
| `set_complete(set_id)` | `set_complete` | `set_id s` | *Live:* set completion rate |
| `cipher_attempt(correct)` | `cipher_attempt` | `correct b, attempt i (running count this session)` | Puzzle engagement |
| `dossier_start(id)` | `dossier_start` | `id s` | Tutorial funnel |
| `dossier_clear(id, attempts, duration_s)` | `dossier_clear` | `id s, attempts i, duration_s n (the winning attempt), since_start_s n (from dossier_start to the clear), via s (duel_end\|dossier_cleared\|dossier_completed)` | **Session fit:** tutorial Dossier D1 cleared < 3 min (use `since_start_s` for `id = dossier_first_contact` (Dossier number 1; tools also accept `d1`)) |
| `survey(answers)` | `survey` | `q1..q4 i? (1-5, null = skipped), open s, answered i` | **Intent to collect** (`q1 ≥ 4` for 70%), **fairness** (`q4 ≥ 4` for 70%), plus the album pull and session fit perception checks (q2, q3) |
| `quit(screen)` | `quit` | `screen s, session_s n, reason s (close\|pagehide)` | Where sessions end; session length |

### Additional events (context for the KPIs above)
| Event | Fields | Why |
|---|---|---|
| `consent` | `given b` (always true; a "no" writes nothing) | Marks the opt-in |
| `input_type` | `kind s (touch\|mouse\|keyboard\|gamepad)` | Written the first time each input kind is used. `session_start.input_type` is only a guess from touch support. |
| `screen` | `name s` | Each screen change (`title, hub, album, lineup, duel, dossier, lobby, match_starting, survey`); the funnel and quit screen |
| `duel_lineup` | `card_ids a, signature_id s, loaner b, duel i` | Lineup actually used in each duel (non-default lineup share) |
| `set_link` | `side s, slot s, linked a, duel i` | Set Link use |
| `capture` | `by s, card_id s, slot s, duel i` | One line per flip |
| `reclaim` | `by s, card_id s, slot s, duel i` | Reclaim trait use (not a capture) |
| `ambush` | `side s, card_id s, slot s, duel i` | Ambush trait use |
| `triptych_reveal` | `id s` | A Triptych revealed for the first time (Collection) |
| `goal_progress` | `goal_id s, current i, target i` | Unlock goal progress shown to the player |
| `goal_complete` | `goal_id s` | Unlock goal met |
| `cipher_solved` | `attempts i` | Cipher Lock opened |
| `lobby_save` | `saved b` | A saved Lobby Duel was written (true) or removed (false) |
| `collection_reset` | (none) | Tester pressed Reset demo. Treat later unlocks as a second run. |
| `log_exported` | `method s (download\|file), bytes i` | The tester pressed Download log |
| `app_hidden` / `app_visible` | `screen s, session_s n` | Tab switch or app background. On a phone browser this is often the last line instead of `quit`. |

## 4. Known quirks (read before analysing)
1. **PLAY AGAIN after a Lobby Duel** (fixed in cc19): once the wait is over (match found or a resumed save), PLAY AGAIN starts a normal rival duel with `source: rival`. A replay while still waiting for a match stays `source: lobby`. The logger also marks any duel started without a screen change since the last `duel_end` as `play_again: true` (on both `duel_start` and `duel_end`). For "sessions per matchmaking wait", count only `source = lobby AND play_again = false`. A hub rival PLAY AGAIN is flagged the same way.
2. **Resumed Lobby Duels** (fixed in cc19): `duel_resumed` and the resumed duel's `duel_end` carry the saved rival id. No `duel_start` follows a resume. The resumed duel's `duel_end` has `resumed: true` and `source: lobby`. Its `duration_s` is the controller's own timer for the resumed part (leave it out of the median duel length).
3. **`triptych_scored.first_time` is always true** from the duel code (it does not know the collection). For a real first-time reveal, use `triptych_reveal`.
4. **Dossier clears come from `duel_end`.** The Dossier pays its reward through `Collection.complete_dossier()`, which emits no EventBus signal. The logger therefore writes `dossier_clear` on a `duel_end` with `source = dossier` and `result = win` (`via: duel_end`). If `dossier_cleared` / `dossier_completed` arrive, they are logged only for an attempt not logged yet. Dossier duels can only be `win` / `loss` and are left out of the session win / loss / draw counts.
5. **`preview_shown` is inferred.** No signal reports the capture preview. The duel and Dossier screens always show it before the player's PLACE, so `preview_shown = (side == player)`.
6. **Consent comes after the Title.** `session_start`, `screen` (the current screen) and `entry_point` are written when consent is given. If a tester opts in later from PLAYTEST, events before that are missing.
7. Logging is off in headless runs (tests and CI) unless a test turns it on, so test runs never write to a real log.

## 5. KPI recipes (per session, then across testers)
| KPI | Pass bar | Recipe |
|---|---|---|
| Intent to collect | ≥ 70% at 4+ | `survey.q1 ≥ 4` |
| Album pull | ≥ 50% | `max(album_open.count) ≥ 2` AND any `card_inspect.owned = false` |
| Session fit (duel) | median < 4 min | median `duel_end.duration_s` where `source ≠ dossier AND resumed = false` |
| Session fit (tutorial) | D1 < 3 min | `dossier_clear.since_start_s` where `id = d1` (first clear) |
| Fairness | ≥ 70% at 4+ | `survey.q4 ≥ 4` |
| Load | < 10 s every session | `session_start.load_ms < 10000` |
| *Live:* non-default lineup | estimate | share of `duel_lineup` with `loaner = false` |
| *Live:* set completion | estimate | sessions with any `set_complete` |
| *Live:* sessions per wait | estimate | count of `duel_start` (`source = lobby, play_again = false`) + `duel_resumed`, divided by `lobby_wait_start` |

Survey wording (1 = Strongly disagree … 5 = Strongly agree):
- q1 "I'd go after specific cards to use them in Banner Wall." (vision §8, verbatim)
- q2 "I wanted to look through the album and find out about the cards I don't own yet." (album pull)
- q3 "A duel fits comfortably into a matchmaking wait." (session fit)
- q4 "Earned cards being stronger feels fair, store cards being cosmetic feels fair." (vision §8, verbatim)
- Open: "What made you want to collect a card, or what put you off?"

Vision §8 gives verbatim statements only for intent and fairness. q2 and q3 are the perception side of the two behavioural KPIs.

# Killstreak — Prototype Playtest Metrics Plan (lightweight)

*Author: Data Scientist Agent · 2026-11-03 · For the upcoming web prototype (no code yet). Keep it small: one local event log + a 2-minute survey.*

## Questions the prototype must answer
1. **Do shooter players get it?** Can a non-card player learn and win quickly?
2. **Does it feel like a shooter?** Is the streak/Operator loop exciting and recognizable?
3. **Is there depth?** Do card veterans see meaningful choices, or is there one dominant line?
4. **Does "one more match" happen?**

## Collection method
- In-game event logger (an autoload, later) writes JSON lines to `user://playtest_log.jsonl`. A "Download log" button on the end-of-session screen lets testers send the file (no server or backend needed for the prototype). An optional POST endpoint can be added later.
- An anonymous session ID; **no personal data**. A consent line on the title screen.
- Pre-survey (3 taps): *Do you play shooters weekly? Do you play card games weekly? Have you played a deckbuilder?* → segments **Shooter**, **Card**, **Both**, **Neither**.

## Events (minimal set)
`session_start`, `tutorial_step(step)`, `match_start(mode, map, threat)`, `round_end(round, score, streak, supply_unspent, hand_size)`, `card_played(card_id, zone, round)`, `elimination(by, victim, zone)`, `operator_down(round)`, `killstreak_earned(id, round)`, `killstreak_used(id, round)`, `match_end(result, rounds, duration_s)`, `reward_pick(offered[], chosen)`, `run_end(result, matches)`, `next_match_clicked(seconds_after_end)`, `quit(screen)`.

## KPIs & prototype targets
| KPI | Target | Why |
|---|---|---|
| Tutorial completion | ≥ 90% | Onboarding works |
| Time to first win (Shooter segment) | ≤ 10 min | Accessible to shooter players |
| Median match duration | 3–5 min | Fast rounds |
| Matches with ≥1 killstreak used | ≥ 80% | The core hook fires |
| Matches where the Operator went down at least once | 40–70% | Risk is real but not punishing |
| Player win rate, bracket 1 / 2 / Rival | ~75% / ~55% / ~40% | Difficulty curve |
| "One more match" rate (next match within 60 s) | ≥ 60% | Loop pull |
| Card pick-rate spread (Supply Drops) | No card > 60% or < 5% | No dominant/dead cards |
| Unspent Supply per round (median) | ≤ 1 | Curve and costs fit |

## Survey (end of session, 1–5 scale + 1 open question)
1. It felt like a modern shooter match. 2. I understood why I won or lost firefights. 3. I had interesting choices each round. 4. Killstreaks felt exciting. 5. I want to play another run. Open question: *"What shooter thing did you expect to see that was missing?"*

**Pass bar for "proceed to production":** Shooter segment averages ≥ 4 on Q1 & Q2; Card segment averages ≥ 4 on Q3; Q5 ≥ 4 overall.

## Analysis (manual, a small spreadsheet)
Compare segments on the KPIs; build a card win-rate-when-played table; plot a streak histogram per match. Expect only 8–15 testers, so treat results as directional, not statistically significant.

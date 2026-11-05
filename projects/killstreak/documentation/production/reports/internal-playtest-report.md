# TEMPLATE: Killstreak internal playtest report (p20)

> **TEMPLATE. No results yet.** Fill it in only from real logs in `projects/killstreak/qa/playtesting/logs/`, never from `qa/playtesting/synthetic/`. Replace every `[...]`, then delete this note.

**Build:** [play link https://claude.ai/artifact/WNcHGuWBMjELqegWCyeihd, version / date tested]
**Sessions:** [n] sessions by [n] tester(s), [dates] · **Device:** [iPhone model, iOS version, Safari]
**Sources:** `qa/playtesting/kpi/kpi-sheet.md` (+ `.csv`) from `python3 tools/kpi_sheet.py`; the head's chat notes; QA bug reports.
**Author:** [agent] · **Date:** [YYYY-MM-DD]

---

## 1. Decision
**External playtest round 1: [GO / GO WITH FIXES / NO-GO]**
[2–4 sentences: what was played, the headline results, and what must happen before round 1. If GO WITH FIXES, list the fixes and their owners.]

> **Sample size:** internal sessions come from one tester, so they **cannot validate the KPI targets**. They check that the game, the logging and the hand-off work, and they catch problems big enough to show up even for one player. The KPI targets are judged in external round 1 (8–15 testers, metrics plan).

## 2. Go / no-go criteria for external round 1
Every **gate** must pass for GO. A failed **watch** item doesn't block round 1. It goes into the round 1 brief as a question to probe, or onto the fix list if it's cheap.

### Gates (must pass)
| # | Gate | Pass when | Result | Status |
|---|---|---|---|---|
| G1 | Sessions played | ≥ 3 sessions with a finished run, ≥ 1 of them a full 5-match run or a run lost on tickets | [n finished runs] | [ ] |
| G2 | Log hand-off works | Every finished session reached the chat as a file the KPI tool reads, through the steps in the tester brief, with 0 schema problems in the KPI sheet. If the `.jsonl` → `.json` rename is still needed, it must be fixed in the game or the Studio Floor first, because external testers won't rename files. | [n logs read / n sessions; schema problems] | [ ] |
| G3 | No blocker bugs | 0 open blocker or critical bugs: no stuck screen, crash, lost run or broken input on the iPhone | [bug ids] | [ ] |
| G4 | Onboarding | The tutorial was played to the last step (KPI "Tutorial completion" = 100% of 1) and the first run started without help | [ ] | [ ] |
| G5 | Core loop fires | ≥ 1 killstreak used in ≥ 60% of matches; the Operator went down in ≥ 1 match and the run continued | [..% of n] | [ ] |
| G6 | Not unwinnable | ≥ 1 win in bracket 1 matches, and no bracket where every match was lost by a wide margin | [W-L-D per bracket] | [ ] |
| G7 | Phone fit | Load ≤ 12 s; no text you can't read, no control you can't reach (notch / home bar), no accidental page scroll or zoom (from the head's notes and the device checklist) | [load s; notes] | [ ] |
| G8 | Privacy and consent | Consent shown on the first launch, the log holds no personal data (check the open answers), and Stop logging & delete works | [ ] | [ ] |

### Watch items (plan targets, directional with n = 1)
| KPI (metrics plan) | Target | Result | Read as |
|---|---|---|---|
| Median match duration | 3:00–5:00 | [ ] | Outside 2:00–7:00 → fix before round 1 |
| Time to first win (Shooter segment) | ≤ 10:00 | [ ] | The head isn't a new player. A miss here is a warning sign. |
| Matches with ≥ 1 killstreak used | ≥ 80% | [ ] | |
| Matches with the Operator down | 40–70% | [ ] | |
| Win rate bracket 1 / 2 / Rival | ~75% / ~55% / ~40% | [ ] | One tester: only flag 0% or 100% over ≥ 3 matches |
| One more match (next within 60 s) | ≥ 60% | [ ] | The clock includes the After-Action and reward screens |
| Supply Drop pick-rate spread | no card > 60% or < 5% | [ ] | Needs round 1 volume; note any card never picked |
| Median unspent Supply per round | ≤ 1 | [ ] | |
| Survey Q1 / Q2 (Shooter) | avg ≥ 4 | [ ] | Q2 < 3 → firefight readability goes on the fix list |
| Survey Q3 (Card) | avg ≥ 4 | [ ] | |
| Survey Q5 (all) | avg ≥ 4 | [ ] | |

**Context (no target):** session length [median / total], matches per finished run [ ], turn (round) time [median / slowest], card usage [most and least played], killstreaks used [by id].

## 3. Confusion signals
Copy from the KPI sheet's "Confusion signals" table and match each one to the head's notes.

| Signal (KPI sheet) | Session | Head's note on it | Action |
|---|---|---|---|
| [tutorial stall at step n / rounds with no card played / preview on / pause / unfinished match ...] | [ ] | [ ] | [fix / brief question / ignore] |

## 4. What the head said
[Chat notes and the open survey answers, quoted, with personal details removed, grouped by theme.]

| Theme | Quote or observation | Session |
|---|---|---|
| [ ] | [ ] | [ ] |

## 5. Bugs found
File each one in `projects/killstreak/qa/bug-reports/` and link it here.

| ID | Severity | Steps | Session | Status |
|---|---|---|---|---|
| [ ] | [ ] | [ ] | [ ] | [ ] |

## 6. Changes for external round 1
- **Must fix before round 1 (gates):** [ ]
- **Tester brief changes:** [what to add to or cut from playtest-guide.md for external testers, e.g. drop the rename step once fixed, add the segment split]
- **Questions to probe in round 1:** [from the watch items]
- **Logging gaps:** [e.g. no event for tutorial skip vs. quit, no forfeit flag on match_end]

## 7. Appendix
- KPI sheet: `qa/playtesting/kpi/kpi-sheet.md` (+ `.csv`)
- Logs: `qa/playtesting/logs/` ([n] files)
- Tool: `tools/kpi_sheet.py`, tested by `tools/test_kpi_sheet.py` on `qa/playtesting/synthetic/`

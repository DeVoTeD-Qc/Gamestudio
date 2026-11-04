# TEMPLATE: CallingCard internal playtest report (cc18)

> **TEMPLATE. No results yet.** Fill this in only from real playtest logs in `projects/callingcard/playtest-logs/` (never from `playtest-logs/synthetic/`). Replace every `[...]` placeholder, and delete this note when the report is final.

**Build:** [artifact link and version / date of the build tested]
**Sessions:** [n] testers, [dates] · **Devices:** [n phone / n desktop / n tablet] · **Entry:** [n] from ENTER THE WALL (menu), [n] from FIND A MATCH (lobby)
**Sources:** KPI sheet `playtest-logs/kpi/kpi-sheet.md` (+ `.csv`), produced by `python3 tools/kpi_sheet.py playtest-logs/`; organiser notes; tester messages.
**Author:** [agent / person] · **Date:** [YYYY-MM-DD]

---

## 1. Summary
[3–5 sentences: what was tested, how many sessions, the headline KPI results, the recommendation in one line.]

> **Sample size caveat:** with 3–5 testers every number here is directional. One tester moves a share by 20–33 points. Read a pass or fail as a signal, not as proof.

## 2. KPI table
Copy from the KPI sheet. Bars: vision.md §8 and prototype-milestone-plan.md §8. Recipes: playtest-log-schema.md §5.

| KPI | Bar | Result | n | Status |
|---|---|---|---|---|
| Intent to collect (q1) | ≥ 70% answer 4–5 | [..% (x/n)] | [n] | [PASS / FAIL / NO DATA] |
| Album pull | ≥ 50% open the album 2+ times and inspect a locked card | [..% (x/n)] | [n] | [ ] |
| Session fit: duel | median < 4:00 (rival + lobby duels, not resumed) | [m:ss over n duels] | [n] | [ ] |
| Session fit: tutorial D1 | D1 cleared < 3:00 (start to clear) | [m:ss median, x/n cleared] | [n] | [ ] |
| Fairness (q4) | ≥ 70% answer 4–5 | [..% (x/n)] | [n] | [ ] |
| Load | < 10 s in every session | [worst .. s, median .. s] | [n] | [ ] |

**Perception checks (no bar):** q2 album interest [median / spread], q3 duel fits a matchmaking wait [median / spread].

**Live estimates (for the pitch, no bar):**

| Estimate | Result |
|---|---|
| Non-default lineup share | [..% of n duel lineups] |
| Set completion | [x/n sessions] |
| Banner Wall duels per matchmaking wait | [x.xx] |

**Plan coverage:** [n] testers (plan: 3–5) · [n] on a phone (plan: ≥ 1) · [n] menu / [n] lobby entry (plan: ≥ 2 each) · [n] surveys answered. [Note any shortfall and how it limits the conclusions.]

## 3. Behaviour notes (from the logs)
- **Duel balance per rival:** [W/L/D per rival, any rival that is far too easy or too hard]
- **Dossiers:** [attempts before the D1 clear, which Dossiers were reached, where testers stopped]
- **Album and collection:** [pages opened, locked cards inspected, Cipher Lock attempts and solves, unlocks]
- **Lobby Duel:** [match found mid-duel?, KEEP PLAYING vs SAVE & LEAVE, resumes and how long the save waited]
- **Where sessions ended:** [quit screens, sessions that ended on a hidden tab, sessions with no survey]
- **Device and load:** [load per device / network, any layout issues on phones]

## 4. Qualitative notes
[Open survey answers (verbatim, with personal details removed), organiser observations, tester messages. Group them by theme. Quote, don't paraphrase.]

| Theme | Evidence (quote or observation) | Testers |
|---|---|---|
| [ ] | [ ] | [T1, T3] |

## 5. Bug list
Found during these sessions. File each one in `projects/callingcard/qa/bug-reports/` and link it here.

| ID | Severity (blocker / major / minor / cosmetic) | Device / browser | Steps | Seen by | Status |
|---|---|---|---|---|---|
| [ ] | [ ] | [ ] | [ ] | [T#] | [new / known / fixed] |

## 6. Go / no-go recommendation
**Recommendation:** [GO / GO WITH CHANGES / NO-GO] for [the next step, e.g. an external playtest round / the pitch build].

Decision rules (agree these before reading the results):
- **GO:** at least 5 of 6 bars pass, no blocker bug, and the open answers show no fairness or pay-to-win concern.
- **GO WITH CHANGES:** 3–4 bars pass, or a bar fails for a clear and fixable reason (for example load on mobile data, or D1 difficulty). List the changes and re-test those KPIs.
- **NO-GO:** intent to collect or fairness fails clearly (under 50%), or 2 or fewer bars pass. Revisit the design before more testing.

**Reasoning:** [3–5 bullets tying the recommendation to the KPI table, the notes and the bugs]
**Is an external round worth it?** [yes / no and why: what a larger sample would settle that these sessions could not]

## 7. Next steps
| Action | Owner (agent) | Linked KPI / bug | Board task |
|---|---|---|---|
| [ ] | [ ] | [ ] | [ ] |

---
*Appendix: per-session tables are in the KPI sheet. The raw logs stay in `playtest-logs/`, unchanged.*

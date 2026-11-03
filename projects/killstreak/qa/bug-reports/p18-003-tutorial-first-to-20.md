# BUG p18-003: The tutorial's score bar says "ZONE CONTROL · FIRST TO 20"

| | |
|---|---|
| Severity | **minor** (UX / onboarding) |
| Status | **FIXED** (p18, QA Agent) |
| Area | `scripts/ui/tutorial/tutorial_match_controller.gd`, `scripts/ui/match_snapshot.gd` |
| Agent responsible | UI/UX Agent (p15) |
| Screenshot | `qa/screenshots/p18-bug003-tutorial-first-to-20.png` |

## Steps
1. Use a fresh profile (first launch). Consent, then the Title, then PLAY DRILL.
2. Look at the score bar, top left.

## Expected
The drill teaches the real game, so the bar should not state a goal that does not exist in it. It should show the drill's real limit (4 rounds), or the real target (first to 6).

## Actual
It says "ZONE CONTROL · FIRST TO 20". The drill's `score_target = 20` is a dummy value that only stops the drill from ending early, and the drill ends at round 4 with a score like 7–2. A new player learns a wrong target, and the drill ends "early" without a reason they can see.

## Fix
`TutorialMatchController.build_state` puts a `goal_text` meta ("4-ROUND DRILL") on its own copy of the run config. `MatchSnapshot.build` shows that text instead of "FIRST TO n" when the meta is present. Run matches are unchanged. Regression test: `tests/test_p18_regressions.gd::test_bug003_tutorial_score_bar_shows_the_drill_length_not_the_dummy_target`.

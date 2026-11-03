# BUG p18-001: The enemy AI plays two Flank Routes on the same unit in one Deploy

| | |
|---|---|
| Severity | **minor** |
| Status | **FIXED** (p18, QA Agent) |
| Area | AI (`scripts/ai/ai_planner.gd`) |
| Agent responsible | Mechanics Developer |
| Found by | `tests/test_rules_soak.gd` (AI vs AI whole runs, run 7, match 3, round 6) |
| Screenshot | none (headless) |

## Steps
1. Run `godot --headless --path . -s res://tests/run_tests.gd -- --only=soak` on the build before the fix.
2. Whole-run sweep, run 7 (seed 7007), match 3 (Rusher squad, which has two Flank Routes): in round 6 the AI holds both Flank Routes and has one unit worth moving twice.

## Expected
Every intent the AI submits is legal. The engine checks a move against the unit's zone on the board, so a unit can move only once per Deploy.

## Actual
The planner moved unit 33 from Left to Mid with the first Flank Route, then planned a second Flank Route from Mid to Right for the same unit, which is valid on its own projected board. The engine refused it ("move only to an adjacent zone"), so the AI wasted the plan step and kept the card in hand. Nothing broke, but the AI's turn was weaker than it planned, and `AiPlayer.last_rejected` was not empty, which the p07 tests treat as a contract.

## Fix
`AiPlanner._apply_effect(MOVE_UNIT)` marks the moved unit record (`moved = true`). `_effect_candidates` skips moved records. Regression test: `tests/test_p18_regressions.gd::test_bug001_ai_never_plans_a_second_move_for_the_same_unit`. It fails without the fix (2 candidates) and passes with it. The soak test also checks for refused intents on every turn.

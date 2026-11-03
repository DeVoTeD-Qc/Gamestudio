# BUG p18-004: Test data used franchise perk names ("scavenger", "ghost")

| | |
|---|---|
| Severity | **minor** (IP checklist; test-only, never exported) |
| Status | **FIXED** (p18, QA Agent) |
| Area | `tests/test_playtest_log.gd` line 74 |
| Agent responsible | Data Scientist (p16) |
| Screenshot | none |

## Steps
1. `grep -rniE "scavenger|ghost" tests/`

## Expected
No franchise perk, killstreak, mode, map or character names anywhere in the repo (milestone plan exit criterion 10, IP name checklist).

## Actual
The playtest-log test emitted a fake Perk offer `[&"scavenger", &"ghost"]`. Both are well-known perk names from the referenced shooter franchise. The `tests/` folder is excluded from the export, so players never see them, but the names could end up in logs, screenshots or a public repo.

## Fix
Replaced them with the prototype's own Perk ids, `[&"field_salvage", &"grit"]`. The test still passes.

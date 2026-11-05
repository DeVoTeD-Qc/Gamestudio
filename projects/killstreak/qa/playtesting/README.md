# Killstreak playtest data

- `logs/`: real "Download log" files from testers (`killstreak-playtest-<date>-<sid>.jsonl`, or renamed to `.json` for the Studio Floor upload). Save each Studio Floor chat attachment here under its original name. Overlapping files are fine: the KPI tool de-duplicates lines on (session id, line number).
- `kpi/`: output of `python3 tools/kpi_sheet.py` (run from `projects/killstreak/`): `kpi-sheet.md` and `kpi-sheet.csv`.
- `synthetic/`: **SYNTHETIC** logs for testing the tool only. They come from `tools/synthetic_playtest_sessions.gd`, which drives the real PlaytestLog and RunState headless with a simulated clock and an iPhone device. Never count them. The tool skips them unless you pass `--include-synthetic`. To regenerate them, run this from `source/project-killstreak`:
  `godot --headless --path . -s ../../tools/synthetic_playtest_sessions.gd -- --out=$(realpath ../../qa/playtesting/synthetic)`
- Tests: `python3 tools/test_kpi_sheet.py`.

Log schema: `PlaytestLog.SCHEMA` in `source/project-killstreak/autoload/playtest_log.gd` (schema v1). KPI targets: `documentation/production/playtest-metrics-plan.md`. Tester brief: `documentation/production/playtest-guide.md`.

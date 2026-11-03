# BUG p18-005: Killfeed names are cut off on the phone layout (844×390)

| | |
|---|---|
| Severity | **minor** (readability) |
| Status | **OPEN** |
| Area | `scenes/Match.tscn` TopBar / `KillfeedSlot`, `scripts/fx/killfeed_entry.gd` |
| Agent responsible | Game Feel Developer (p14), with UI/UX Agent (compact layout) |
| Screenshot | `qa/screenshots/p18-bug005-killfeed-clipped-phone.png` (desktop for comparison: `qa/screenshots/p18-desktop-match-result.png`) |

## Steps
1. Open the web build at 844×390 @3x (iPhone landscape) and start a run.
2. Play a round in which units are eliminated, and watch the killfeed in the top bar between INTEL and PREVIEW.

## Expected
Each killfeed line shows who eliminated whom, readable at a glance, as it does at 1280×720 ("POINT MAN ▸ POINT MAN", "WASP-9 ▸ KESTREL AR-7").

## Actual
In the compact top bar the killfeed slot is only about 230 CSS px wide, so each line is clipped after one name and a few letters: "BREACH ▸ KES", "POINT ▸ RIF". The victim is unreadable. The killfeed is also the only place that names an Operator kill as it happens. The same events reach the playtest log, so no data is lost.

## Suggested fix (not applied: layout decision)
In compact mode, either shorten names to a fixed short form (CardData short name, or 6 characters plus the class icon) and drop the zone tag, or move the killfeed to a 2-line overlay under the top bar on the board's right edge. `tests/test_board_layout.gd` should then check that a killfeed line's text fits its width at 844×390.

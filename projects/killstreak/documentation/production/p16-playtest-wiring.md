# Wiring the p16 playtest logger and surveys

From the Data Scientist's p16 hand-off. Nothing is shown to testers until these are hooked up.

- **Boot/Title:** if `PlaytestLog.needs_consent()`, go to `res://scenes/survey/Consent.tscn` (yes → pre-survey once per device → Title).
- **Run end screen (p11):** route to `res://scenes/survey/EndSurvey.tscn`.
- **EventBus emitters (match controller / run screens):** the logger only listens. Emit `match_started`/`match_ended`, `round_started`/`round_ended`, `card_deployed`, `killstreak_earned`/`killstreak_used`, `ability_used`, eliminations and operator downs as gameplay happens.
  - `round_summary(round_number, supply_unspent, hand_size)` — emit just before `round_ended` so it merges into the `round_end` line.
  - `next_match_requested` — when the player presses to start the next match.
  - `screen_shown(screen)` — for overlays (scene changes are already captured via SceneRouter).
- Event schema v1 is `PlaytestLog.SCHEMA`; see the p16 report in the board's task for the full table.

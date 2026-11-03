# Wiring the p14 combat feedback into Match

From the Game Feel Developer's p14 hand-off. Components live in `scenes/fx/` and `scripts/fx/`.

1. Add `scenes/fx/FeedbackDirector.tscn` as the last child of the `Match` root. In `match_screen._ready()`:
   ```gdscript
   var fx = %FeedbackDirector
   fx.locator = preload("res://scripts/fx/board_fx_locator.gd").new(_board)
   fx.locator.anchors[&"score"] = _score_bar
   fx.locator.anchors[&"streak"] = _operator_panel
   ```
   The locator finds slots by `UnitSlot.slot_uid`.
2. Killfeed: put `scenes/fx/Killfeed.tscn` as the only child of `%KillfeedSlot`, set `fx.killfeed` to it, and make `match_screen._set_killfeed()` a no-op. The controller's `_add_killfeed` and the snapshot's `killfeed` list are then unused.
3. Streak: in `scenes/match/OperatorPanel.tscn` replace `StreakSegments` (in `Row/Info/StreakRow`) with a `scenes/fx/StreakArc.tscn` (min size 0×30) and set `fx.streak_arc`. In `operator_panel.set_operator()` replace `_build_segments(...)` with `arc.configure(snapshot.streak_max, thresholds, streak)`.
4. In `match_controller.press_ready()`, after `var resolved := state.resolve_round(); _flush_events(); round_resolved.emit(resolved)` and before `state.begin_round()` / `refresh()`:
   ```gdscript
   _busy = true
   await fx.play(resolved)
   _busy = false
   ```
   Keep the pre-resolve snapshot on screen while it plays; ignore taps while `_busy`.
5. Fast-forward: on `fast_forward` (F) or a tap while `fx.is_playing()`, call `fx.skip()`.
6. Optional: after a successful play in `_after_change()`, `fx.play(<new events>)` for deploy-time cues ("UPLINK QUEUED").
7. Optional: the director emits `event_started(event)` per event for mid-sequence board refreshes.

Known polish items: pop-ups briefly overlap lane headers; the arc is small (~90 px) in the 170 px Operator column; FX label styles live in `fx_style.gd`, not the theme.

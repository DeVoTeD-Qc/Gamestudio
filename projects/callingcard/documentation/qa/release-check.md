# CallingCard ("Banner Wall") prototype: rules, device and release check (cc17)

QA Agent · 2026-11-04 · build at commit `29d2093` (all build tasks done) · Godot 4.4.1, Web export (Compatibility renderer)

## Verdict

**Conditional pass.** The milestone bar is met: **0 critical** bugs and **4 minor** (the limit is 10). Two **major** issues are open, though:

1. **Load time fails the 10 s target on throttled networks.** It takes about 12.3 s on "4G" and about 59 s on "Fast 3G". On an unthrottled link it is about 2 s.
2. **On touch, the lineup builder's card list can't be scrolled by swiping over the cards.**

Fix both before cc18, or have the producer accept them for an internal playtest held on Wi-Fi, where load is about 2 s.

| Severity | Count |
|---|---|
| Critical | 0 |
| Major | 2 |
| Minor | 4 |
| Cosmetic | 4 |

**Tests:** the suite has **211/211** passing: the 209 existing tests plus 2 new ones in `tests/test_release_unlocks.gd`. It also passed while 2–3 Chromium instances were running alongside it. Nothing was committed.

## 1. Rules

| Check | Result |
|---|---|
| QA cc04 cases (`tests/test_rules_cases.gd`, from `rules-test-cases.json`) | **103 / 103 pass**, with 90 preview==place checks |
| Live duel follows the Tempo rule (first player +2) | **Pass.** 41 full duels ran through `Duel.tscn` and the duel controller against all 3 rivals. In every one, the end score equals an independent count (cards + Signature extra + Triptych bonus + 2 for the first player), and the `EndScore` label shows the same numbers. In the browser on 6 device sizes, the end screens were consistent (e.g. 11–3 with the rival as first player: TEMPO +2 sits on the rival's counter). |
| Ties are draws | **Pass.** 8 of the 41 duels ended level (all 7–7). Each one emitted `duel_ended("draw")` and the end screen read "DRAW" / "Level score: a draw." |
| A draw keeps the win streak | **Pass.** The sequence win, draw, win, draw, win gives streak 3, 2 draws counted, and Polar Night unlocked; a loss then resets the streak to 0 (`test_draw_keeps_win_streak`). The long run also reached `streak 24` with draws in between. |

**Balance note for the Mid Designer (not a bug):** with the player using the 2-ply search against the **Archivist**, **8 of 14 duels were 7–7 draws**. The total score is usually 14: 10 cards, +1 for each of 2 Signatures, +2 Tempo. That makes a level split common. The cc06 sim measured Archivist against Archivist; consider re-running it with draws counted separately.

## 2. Device matrix (scratch web export, Chromium via Playwright, SwiftShader)

Each row ran one full rival duel, Dossier D1, the lineup builder, every album page plus the Cipher Lock (one wrong code, then the right one), and Lobby Duel → Match found → Save & leave → page reload → hub CONTINUE → finish → PLAY AGAIN. All of it used **real input events**: `page.mouse` or `page.touchscreen` taps, and CDP touch drags for swipes.

| Device (CSS px) | Input | Boot → consent | Rival duel | Dossier | Lineup | Album + Cipher | Lobby save/reload/resume | Script errors |
|---|---|---|---|---|---|---|---|---|
| Desktop 1280×720 | mouse only | 2.1 s | pass (win 11–3) | pass | pass¹ | pass | pass | 0 |
| Desktop 1920×1080 | mouse only | 2.9 s | pass | pass | pass | pass | pass | 0 |
| iPad landscape 1180×820 @2x | touch only | 3.0 s | pass | pass | pass | pass | pass | 0 |
| iPhone 13 landscape 844×390 @3x | touch only | 3.6 s | pass | pass | pass | pass² | pass | 0 |
| iPhone SE landscape 667×375 @2x | touch only | 2.8 s | pass | pass | **pass only by dragging the scrollbar gutter (BUG-02)** | pass² | pass | 0 |
| Small Android landscape 640×360 @2x (Chrome UA) | touch only | 3.2 s | pass | pass | **pass only by dragging the scrollbar gutter (BUG-02)** | pass² | pass | 0 |

¹ The first pass failed on a driver mistake: it toggled the auto-picked Signature off. It passed on a re-run.
² The Cipher Lock tab starts off the right edge of the tab strip. It was reached by swiping the strip (BUG-09).

- The disclaimer is on the Title at every size. For example, at 640×360 its box is 32–608 × 330–343, and on iPhone SE see `qa/screenshots/cc17-title-disclaimer-iphonese.png`.
- No control in the duel, hub, lobby or overlays fell outside the viewport at any size. Hand cards never needed the strip scroll.
- Firefox, Safari and Edge were not run: the cloud machine has only Chromium. iOS Safari behaviour is emulated, not real. Both **need a real device**.

### Driver used (scratch only, not in the repo)
`qa_driver.gd` was an extra autoload in a scratch copy of the project. It **never presses anything**. It reports button centres in CSS px. For a placement, it picks the move (in a duel, the highest preview capture count; in a Dossier, the next solution step) and returns the screen points of the hand card, the slot, the Cipher target and PLACE. Playwright then taps those points. If a hand strip had hidden the card, the driver would scroll it into view with `ensure_control_visible`; this never happened. It also ends the simulated Lobby wait on command, as in cc13, and reads the playtest log and the Collection summary. The scripts are in the session scratchpad under `cc17/`: `qa_driver.gd`, `qa.js`, `flows.js`, `loadtime.js` and `fps.js`.

## 3. Mouse-only and touch-only passes

- **Mouse only:** desktop 1280 and 1920 completed every flow listed above with clicks.
- **Touch only:** iPad, iPhone 13, iPhone SE and Android completed every flow with taps and swipes. The only exception is BUG-02, where the lineup list scrolls only from the scrollbar gutter.
- **Lobby Duel save → reload → resume:**
  - The save survived a full page reload on all 6 devices.
  - The hub showed CONTINUE, and the duel resumed and finished.
  - The save was cleared after the end (`has_saved_lobby_duel` false), and `duel_resumed` was logged with `age_s`.

## 4. Load time (artifact-style build: `engine.gz.wasm` + `game.pck.wasm`)

The build was made by `tools/package_artifact_build.sh` into a scratch dir and served locally. Each run used a fresh browser context, so the cache was cold, with CDP `Network.setCacheDisabled` and Chrome DevTools throttling presets. The time is measured from navigation to "Title: ready" (the interactive Title); the consent prompt is ready about 0.1 s later. Each run transferred 9.99 MB, and `engine.gz.wasm` alone is 9.40 MB (94 %).

| Profile | Desktop 1280 (2 runs) | iPhone 13 (2 runs) | Target < 10 s |
|---|---|---|---|
| No throttling (local) | 2.31 s / 1.96 s | 1.83 s / 1.86 s | pass |
| "4G" (9 Mbps×0.9, 165 ms RTT) | 12.39 s / 12.29 s | 12.20 s / 12.20 s | **fail (BUG-01)** |
| "Fast 3G" (1.6 Mbps×0.9, 562 ms RTT) | 58.8 s / 59.2 s | 58.7 s / 58.7 s | **fail (BUG-01)** |

Software rendering in this cloud machine adds roughly 1.5 s of compile and boot time that a real phone or desktop GPU will mostly not have. A real 4G device is therefore likely to land around 11 s. That is still over the target, because download time dominates.

## 5. All unlocks reachable in normal play

`tests/test_release_unlocks.gd::test_all_unlocks_reachable_in_normal_play` covers this; it takes about 10 s headless. It starts from a **fresh demo Collection** on its own save file, so the real save is untouched. It plays only real Dossiers (`Dossier.tscn`) and real duels (`Duel.tscn`, the duel controller, the rules and the rival AI). Every move goes through the duel screen's own `card_picked` / `slot_chosen` / `target_tapped` / `place_confirmed` signals, which is the path a tap takes. It uses the starting 13 cards first, then cards as they unlock.

| Unlock | How it was reached | Result |
|---|---|---|
| Goal: Win 3 in a row → **Polar Night** | Archivist duels, starter lineup | pass |
| Goal: Capture 20 → **Dead Air** | same duels | pass |
| Goal: Win 5 → **Honor Roll** | same duels (14 duels: 5 wins, 8 draws, 1 loss; streak reached at the 3rd win with draws in between) | pass |
| Goal: Beat the Warden → **City Never Sleeps** | Warden duels, no-Legend lineup, 1st win (seed 202) | pass |
| Goal: Beat the Warden twice with no Legend → **Long Watch** | 2nd no-Legend Warden win (seed 204). Not granted after the first win (asserted). | pass |
| Goal: Clear Dossier D4 → **Null Glyph** | D4 solution | pass |
| Goal: Solve the Cipher Lock → **Key Fragment** | code from data, after a refused wrong code; also solved with dial taps in the browser on all 6 devices | pass |
| Dossier D1 First Contact reward (title "Contact Made") | cleared | pass |
| Dossier D2 Same Page reward (frame `service_ribbon_frame`) | cleared | pass |
| Dossier D3 Lights Out reward (frame `flare_up_gold`) | cleared | pass |
| Dossier D4 Carded reward (card Null Glyph) | cleared | pass |
| Dossier D5 Clean Copy reward (title "Copycat") | cleared | pass |
| Set completion: Night Shift, Whiteout, Signal Fire, Old Guard, Cipher | all 20 cards owned → all 5 complete (Showcase has no completion, by design) | pass |
| Triptych **Midnight Run** (Graveyard Shift, Neon Rain, Last Train) | scored by the player against the Quartermaster | pass |
| Triptych **Cold Signal** (Frostbite, Mayday, Dead Air) | scored after Dead Air unlocked | pass |
| Triptych **Open Book** (Null Glyph, Key Fragment, Honor Roll) | scored after the three unlocks | pass |

Final stats: 41 duels (30 wins, 3 losses, 8 draws), 219 captures, and all 7 goals done. The player now owns 20 of 20 cards.

## 6. IP and disclaimer checklist

| Item | Result |
|---|---|
| The Title shows "Unofficial concept demo. Not affiliated with Activision or Call of Duty." | **Pass** on all 6 device sizes (`DisclaimerLabel`). The same text is in `web/shell.html` while loading. |
| No franchise names elsewhere | **Pass.** I scanned every `.gd`, `.tscn`, `.tres`, `.svg`, `.json`, `.cfg`, `.html` and `.md` file under the project for the franchise, publisher and studio names, known maps, characters and modes, and several other terms. The only hits are the disclaimer (Title, shell, README) and the generic theme name `GhostButton`. Card, set, rival, Triptych and Dossier names are all original. |
| No logos or likenesses | **Pass.** The 21 SVG icons are hand-written geometry: they have no embedded images, no editor metadata and no external references beyond the SVG namespace. Card art is procedural (`card_art.gd`). |
| Art is original; nothing downloaded from wikis | **Pass.** No wiki or fandom references and no downloaded art exist anywhere in the project or art docs. |
| Fonts are OFL with the licence shipped | **Partial.** Barlow and Barlow Condensed are OFL, and `assets/fonts/OFL-Barlow.txt` is in the repo. However, **the licence is not in the web build or the artifact package** (BUG-03). |
| Wording risk (note, not a bug) | The "how earned" lines and the origin label use shooter-genre terms ("Reach prestige 3", "eliminations", "SMG", "ranked season"). These are generic, not franchise names. "Prestige" is strongly associated with the franchise, so the lead should confirm it is acceptable. |

## 7. Known items: verified

| Item | Finding |
|---|---|
| FPS | **Needs a real device.** SwiftShader with no GPU measured: Title 17–20 fps and duel idle 7–9 fps on desktop 1280; on iPhone 13 emulation at @3x, Title 5–8 fps and duel idle 2–4 fps. These numbers are not meaningful for real devices. The duel screen is slower when idle than the Title, which suggests continuous redraw. Check it on a real phone for 30+ fps and battery use. |
| PLAY AGAIN after a Lobby Duel logs source lobby | **Confirmed**, logged as BUG-04. |
| A resumed Lobby Duel logs `rival: ""` | **Confirmed**, logged as BUG-05 (both `duel_end` and the resume record). |
| The test_ai timing test is flaky under load | **Not reproduced** in 8 runs, including 6 run in parallel next to 2 Chromium instances. The worst Warden opening move was 92 ms against the 150 ms bound. Kept as BUG-06 (minor). |
| The toast covers "Dial I" on the phone | **Confirmed**, logged as BUG-07. |

## 8. Bug list

### BUG-01 · Major · Load time over 10 s on 4G and Fast 3G
- **Owner:** ui (build / `tools/package_artifact_build.sh`; technical-artist and mechanics-developer)
- **Repro:**
  1. Package with `tools/package_artifact_build.sh`.
  2. Serve the artifact files.
  3. In Chromium, open the page with the cache disabled and the "4G" or "Fast 3G" throttle.
  4. Time from navigation to an interactive Title.
- **Expected:** under 10 s.
- **Actual:** 12.2–12.4 s on 4G and 58.7–59.2 s on Fast 3G (2 s unthrottled). The download is 9.99 MB, of which 9.40 MB is `engine.gz.wasm`.
- **Possible fixes:** a size-optimised custom export template (disable 3D and unused modules) is the main lever; `wasm-opt -Oz` would also help. Another option is to record the target as "on Wi-Fi/4G+" for the internal playtest.

### BUG-02 · Major · Touch: the lineup builder's card list can't be scrolled by swiping over cards
- **Owner:** lineup
- **Repro:**
  1. On iPhone SE landscape (667×375) or a small Android (640×360), open the hub and tap LINEUP.
  2. Swipe up over the "YOUR CARDS" grid.
- **Expected:** the list scrolls, as the album pages do.
- **Actual:** nothing moves. Only a drag on the narrow scrollbar gutter, or the mouse wheel, scrolls the list. Mayday (a starter) and every locked card with its unlock goal sit below the fold. A phone player may never find them, and then can't build a lineup with them.
- **Cause:**
  - `lineup_builder.gd` builds the grid from `TapHoldButton`s that keep the default `MOUSE_FILTER_STOP`, and `tap_hold_button.gd` calls `accept_event()`, so the drag never reaches the ScrollContainer.
  - The album cards set `MOUSE_FILTER_PASS` for exactly this reason (`album_card_hanger.gd:52`).
- **Screenshot:** `qa/screenshots/cc17-lineup-list-no-swipe-iphonese.png` (after 3 swipes on the cards: unchanged)

### BUG-03 · Minor · The OFL font licence isn't shipped with the build
- **Owner:** ui (export preset / packaging; technical-artist)
- **Repro:**
  1. Export the Web preset or run the packaging script.
  2. Look for the licence text in `index.pck` / `game.pck.wasm` and the output folder.
- **Expected:** OFL-1.1 requires the licence to travel with the embedded Barlow fonts.
- **Actual:**
  - The `.ttf` files are packed, but `OFL-Barlow.txt` is not: `include_filter` is empty and the file is not a resource.
  - The packaging script doesn't copy it either.
  - There is no credits line in the game.
- **Fix:** add `assets/fonts/*.txt` to `include_filter` or copy the file next to `index.html`, and optionally add a credits line.

### BUG-04 · Minor · PLAY AGAIN after a Lobby Duel is logged and handled as a Lobby Duel
- **Owner:** lobby (with playtest)
- **Repro:**
  1. Hub → FIND A MATCH → PLAY A QUICK DUEL → play → Match found → SAVE & LEAVE.
  2. Reload, then CONTINUE and finish the duel.
  3. On the end screen, tap PLAY AGAIN → START DUEL → BEGIN.
  4. Tap MENU.
- **Expected:** the replay is an ordinary rival duel, since the matchmaking wait is over.
- **Actual:**
  - `duel_start` is logged with `source: "lobby", play_again: true`.
  - MENU offers SAVE & LEAVE, so the replay can be saved and resumed as a "Lobby Duel".
  - This inflates the Lobby Duel counts and finish rate in the cc18 KPI sheet.
- **Screenshot:** `qa/screenshots/cc17-play-again-after-lobby-offers-save-iphonese.png`

### BUG-05 · Minor · A resumed Lobby Duel logs `rival: ""`
- **Owner:** playtest
- **Repro:**
  1. Save & leave a Lobby Duel against the Archivist.
  2. Reload, then CONTINUE.
  3. Finish the duel and download the log.
- **Expected:** `duel_end.rival` is `"archivist"`.
- **Actual:** `rival: ""`, with `resumed: true, source: "lobby"`. `playtest_log.gd:802-808` sets it to "" on `duel_resumed`, although `Collection.resume_lobby_duel()` knows `rival_id`.

### BUG-06 · Minor · test_ai Warden timing test can flake under load
- **Owner:** ai
- **Repro:** run `--only=test_ai` many times on a busy machine.
- **Expected:** a deterministic result.
- **Actual:** no failure in 8 runs, but the test asserts on wall-clock time (`worst_ms < 150`), and the worst case under load was 92 ms.
- **Fix:** assert the node cap (already checked) and print the time instead, or skip the time bound when `OS.get_processor_count()` is low or the load is high.

### BUG-07 · Cosmetic · The "New card" toast covers "Dial I" and the reward card on phones
- **Owner:** album (toast placement; ui)
- **Repro:** on iPhone 13 (844×390), open Album → Cipher Lock → enter 4-3-1-2 → TRY CODE.
- **Expected:** the toast stays clear of the dial captions and the reward card.
- **Actual:** "New card: Key Fragment" sits over the "Dial I" caption and the bottom edge of the reward card for its full duration.
- **Screenshot:** `qa/screenshots/cc17-toast-covers-dial-i-iphone13.png`

### BUG-08 · Cosmetic · The Match found banner hides both score counters
- **Owner:** lobby
- **Repro:** on iPhone SE, start a Lobby Duel and play 2 cards; wait for Match found.
- **Expected:** the scores stay readable while the banner is up (it is non-blocking).
- **Actual:** the banner covers both counters and the turn label until the player picks an option.
- **Screenshot:** `qa/screenshots/cc17-lobby-banner-covers-scores-iphonese.png`

### BUG-09 · Cosmetic · Phones: the Cipher Lock album tab starts off-screen
- **Owner:** album
- **Repro:** on iPhone 13, iPhone SE or Android, open Album.
- **Expected:** a cue that more tabs exist, or the Cipher Lock tab is visible.
- **Actual:**
  - The Cipher Lock tab starts beyond the right edge, at x≈859 on an 844 px screen, and only a thin scrollbar hints that it is there. A swipe reveals it.
  - On iPhone SE and Android, Triptychs is off-screen too.
- **Screenshot:** `qa/screenshots/cc17-album-tabs-cipher-lock-offscreen-iphone13.png`

### BUG-10 · Cosmetic · Dossiers show "TEMPO +2" and count it in the score
- **Owner:** dossier
- **Repro:** hub → DOSSIERS → D1 → START.
- **Expected:** no first-player bonus in a solo puzzle; it offsets nothing there.
- **Actual:** the player's counter shows TEMPO +2, and the result shows 8–0 for 3 captures. The goal checks are unaffected, since all 5 solutions still pass.
- **Screenshot:** `qa/screenshots/cc17-dossier-tempo-tag-desk1280.png`

## 9. Other observations (no bug filed)
- `EventBus.dossier_cleared` and `dossier_completed` are never emitted. Rewards go through `DossierRewards` → `Collection.complete_dossier()` directly, so `Collection`'s listeners for them are dead code.
- The headless runner ends with "ObjectDB instances leaked" and "16 resources still in use". The exit code is still 0.
- Archivist draw rate: see §1.

## Files
- Report: `projects/callingcard/documentation/qa/release-check.md`
- New regression tests: `projects/callingcard/source/project-callingcard/tests/test_release_unlocks.gd` (2 tests, about 10 s)
- Screenshots: `projects/callingcard/qa/screenshots/cc17-*.png` (7 files)

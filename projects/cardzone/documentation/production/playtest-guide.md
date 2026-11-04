# CardZone: playtest guide

**About 30–40 minutes on a phone (held sideways) or a computer.** Thank you for testing. Play the way you normally would. There are no wrong answers: we are testing the game, not you.

## 1. Before you start
- Open the link you were sent (claude.ai/artifact/…) in a **normal browser window**. A private or incognito window can lose the log. Safari, Chrome, Firefox and Edge all work.
- On a phone, turn it sideways (landscape).
- Use the same device and browser from start to finish.
- **Loading can take 10–20 seconds on mobile data.** Wait for the title screen.
- The first screen asks whether to log your session. Tap **YES, LOG MY SESSION**.
  - The log is anonymous: a random session number plus what happens in the game. It has no name, account or location, and nothing is sent anywhere until you download the file and send it yourself.
  - If you tapped NO THANKS, you can turn logging on later: **PLAYTEST** (top right of the title screen) → **TURN ON LOGGING**.

## 2. What to play
1. **Match 1:** on the title screen, start a new match against the **Rookie** AI. Play it to the end.
2. **Match 2:** start another match against the **Veteran** AI.
3. More matches are welcome, but only if you want to play them.
4. **Optional:** if a hot-seat (pass the phone) mode is available and someone is with you, play one match against them.

If the game offers a short tutorial in the first match, follow it or skip it, as you prefer.

If you have to stop, or your phone locks in the middle of a match, just come back: the match continues where you left off. That is part of what we are testing.

## 3. Survey (at the end, about 2 minutes)
When you're done, go back to the title screen and tap **PLAYTEST** (top right).
- Rate five statements from 1 (strongly disagree) to 5 (strongly agree). If you only played hot-seat, the statement about the AI is left out.
- Then answer one optional question.
- Skip anything you'd rather not answer. Please leave names and personal details out of the written answer.

## 4. Send the log
1. On the **THANKS FOR PLAYING!** page, tap **DOWNLOAD LOG**. You'll get a file named `cardzone-playtest-<date>-<code>.json`.
   - **iPhone:** Files app → Downloads.
   - **Android:** Files or Downloads.
   - **Computer:** your Downloads folder.
2. Send the file back in either of these ways:
   - **Studio Floor chat:** attach the file to a message.
   - **Repo:** put it in `projects/cardzone/playtest-logs/` (the studio head can do this for you).
3. Optional: add a line about anything that broke, and which device you used.

If DOWNLOAD LOG fails, send a screenshot of the PLAYTEST page and tell the organiser. To stop logging and delete the log on your device at any time: PLAYTEST → **STOP LOGGING & DELETE** (tap twice).

## 5. Don't worry about
- Placeholder art, sounds and wording.
- Loading time on mobile data.

Do mention anything that stops you or looks broken.

---
*For the organiser (plan §8):*
- Run 3–5 sessions: the studio head on his iPhone, plus internal testers, with at least one more on a phone.
- Each tester plays at least 2 matches vs the AI (Rookie first, then Veteran). At least one tester tries hot-seat, if it shipped.
- Hand out the link and this page, then step back:
  - Don't coach during play.
  - Don't explain the rules beyond the in-game coach.
  - Don't explain the survey statements.
  - Don't prompt a second match more than once. Note whether you had to ask.
- **Dev panel (organiser only, not for testers):** on the title screen, **press and hold the "CardZone" logo for 2 seconds** (a shorter hold does nothing). It switches hand size, F1–F8, the visibility and supply-drop settings and the two first-player switches (no shooting in round 1, P2 extra start health) for **new matches only**; a saved match keeps its rules. While anything differs from the shipped values, the title and setup show **DEV SETTINGS ACTIVE**. **RESET ALL** goes back. (The plan said "5 taps on the version"; the build uses the long press.)
- The title's small grey line names the build (`Prototype · build <git hash> <date> · Godot …`); note it with each session.
- Collect the files in `playtest-logs/` and run `python3 tools/kpi_sheet.py playtest-logs/` (see `playtest-logs/README.md`).
- With this few testers, every number is directional.

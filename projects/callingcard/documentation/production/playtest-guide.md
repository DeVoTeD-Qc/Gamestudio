# Banner Wall: playtest guide

**About 20 minutes. Works on a phone or a computer.** Thank you for testing. Play the way you normally would. There are no wrong answers, and we are testing the game, not you.

## 1. Before you start
- Open the link the studio head sent you (claude.ai/artifact/…) in a **normal browser window** (not private or incognito, which can lose the log). Chrome, Safari, Firefox and Edge all work.
- Use the same device and browser from start to finish. Don't reload the page while you play.
- **Loading takes 10–20 seconds on mobile data.** That's expected; wait for the title screen.
- The first screen asks whether to log your session. Tap **YES, LOG MY SESSION**. The log is anonymous: a random session number plus what you tap in the game. It holds no name, account or location, and nothing is sent anywhere until you download it and send it yourself.
  - If you tapped NO THANKS, you can turn logging on later in **PLAYTEST** (on the hub) → **TURN ON LOGGING**.

## 2. What to try (about 20 minutes, in any order you like after step A)
**A. Your first button.** The organiser gives you a letter:
- **Group M:** press **ENTER THE WALL** first.
- **Group L:** press **FIND A MATCH** first.

Then work through the rest of the list:
1. **Duel a rival.** Under DUEL A RIVAL on the hub, pick one. Play at least one full duel. PLAY AGAIN is fine.
2. **A Dossier.** Open **DOSSIERS** and play the first one. RETRY as often as you like, or leave it when you want.
3. **Lineup.** Open **LINEUP** and look at or change the cards you take into duels.
4. **Album.** Open **ALBUM** and browse. To look at any card closely, press and hold it (on a computer, right-click it).
5. **Cipher Lock.** It's in the album. Try it if you like.
6. **Find a Match.** On the hub, press **FIND A MATCH** and **PLAY A QUICK DUEL** while you wait. When **MATCH FOUND** appears, choose whichever you prefer. If you choose **SAVE & LEAVE**, come back later with **CONTINUE** under SAVED QUICK DUEL on the hub.

You don't have to finish everything. Skipping something is useful information too.

## 3. Survey (at the end, about 2 minutes)
When you're done playing, go to the hub and press **PLAYTEST**. Rate four statements from 1 (strongly disagree) to 5 (strongly agree), then answer one optional question. Skip anything you'd rather not answer. Please leave names and personal details out of the written answer.

## 4. Send the log
1. On the **THANKS FOR PLAYING!** page, press **DOWNLOAD LOG**. You'll get a file named `callingcard-playtest-<date>-<code>.json`.
   - **iPhone:** Files app → Downloads. **Android:** Files or Downloads. **Computer:** your Downloads folder.
2. Send the file back in one of two ways:
   - **Studio Floor chat:** attach the file to a message.
   - **Repo:** put it in `projects/callingcard/playtest-logs/` (the studio head can do this for you).
3. Optional: add a line or two about anything that broke or confused you, and say which device you used.

If DOWNLOAD LOG fails, send a screenshot of the PLAYTEST page instead and tell the organiser. To stop logging and delete the log on your device at any time: PLAYTEST → **STOP LOGGING & DELETE** (tap twice).

## 5. Don't worry about
- **Placeholder audio.** Sounds are temporary or missing.
- **Loading time on mobile data** (10–20 s).
- Placeholder art and wording. Do mention anything that actually blocks you or seems broken.

---
*For the organiser:* run 3–5 sessions, with at least one on a phone and at least two testers in each group (M and L). Hand out the link and this page, then step back. Don't coach the tester during play, and don't explain the survey statements. Collect the log files and run `python3 tools/kpi_sheet.py playtest-logs/` (see `playtest-logs/README.md`).

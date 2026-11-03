# Device checklist: iPhone Safari and Android Chrome (p18)

Run this on each real phone, using the private itch.io link (or any HTTPS host of `builds/web/`).
It takes about 25 minutes per phone. Our automated tests only run in desktop Chromium, so these steps
cover what they can't check: real Safari, real touch, the notch, the toolbars, the speed of a phone
CPU and the Files app.

Before you start: charge the phone, use Wi-Fi, close other tabs, and have a stopwatch ready.
For each step, write **OK** or a short note with a screenshot (hold power + volume up).

| # | Step | Pass if |
|---|---|---|
| 1 | Hold the phone upright and open the link in a **private** tab (so it is a first launch). | A "turn your phone" message shows. No error box. |
| 2 | Turn the phone sideways. Start the stopwatch when you tap **Run game** on itch.io (or when the page opens), and stop it when the consent screen appears. | The progress bar moves, and the consent screen is up in **under 10 s**. Write down the time. |
| 3 | Read the consent text and tap **Yes**. Answer the three questions and tap **Continue**. | Text is easy to read without zooming. Every button works on the first tap. |
| 4 | On the Title, tap **Play drill** and play the tutorial to the end, following the highlights. Tap **Done**. | No step gets stuck. Coach text and buttons are not hidden behind the notch or the home bar. |
| 5 | Tap **Tutorial** again, then tap **Skip tutorial** twice. | You are back on the Title. |
| 6 | Tap **Start new run**, pick killstreaks, tap **Begin run**, then **Deploy**. | The match board fits the screen. Nothing is cut off at the left/right edges. |
| 7 | In Round 1, tap a hand card and then a lane. Then drag another card onto a lane. | Both ways deploy the card. The page does not scroll, zoom or bounce. |
| 8 | Long-press a card (hold about half a second). Close the inspector. Then tap **UNDO**. | The inspector opens with readable text. Undo takes back the last card. |
| 9 | Tap **READY**. While the round plays, tap the board once. | The fight animates, and the tap fast-forwards it. Sound plays, or the phone is on silent. |
| 10 | Play the match to the end. Note how smooth it felt (smooth / a bit choppy / slow). | The result banner appears. Tap **Continue** opens the After-Action screen. |
| 11 | Switch to another app for 30 s, then come back. Rotate to portrait and back to landscape. | The game is still there, in the same state, and the layout comes back correctly. |
| 12 | Tap **Menu > Quit to title**, then close the tab completely. Reopen the link (same browser, not private). | **Continue run** is on the Title and takes you back to the run map. |
| 13 | Finish or lose the run (you can use **Menu > Forfeit match** to speed this up). Answer the end survey. | The Run End screen and every survey page work by tapping. |
| 14 | Tap **Download log**. iPhone: open the Files app, then Downloads. Android: open the Downloads notification. | A `.jsonl` file is there and is larger than 0 KB. Send it to the playtest organiser along with this checklist. |
| 15 | iPhone only: in Safari, tap Share, then **Add to Home Screen**. Open the game from the icon. | It opens full screen with no Safari bars, and the board uses the full height. |

Report back: the phone model, the OS and browser version, the load time from step 2, the smoothness from step 10,
and every step that was not OK, each with a screenshot.

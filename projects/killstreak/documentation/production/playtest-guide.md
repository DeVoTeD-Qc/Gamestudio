# Killstreak: internal playtest guide (p20)

**For the studio head, on an iPhone. 3–5 sessions of about 20–30 minutes.** Play the way you normally would. We are testing the game, not you.

> **Known snag (read first):** the game saves the log as a **`.jsonl`** file, and the Studio Floor **+ Images / logs** button only takes **`.json`**. On iPhone, the `.jsonl` file shows greyed out in the picker. Until that is fixed, rename the file before you upload it (step 4b). It takes about 10 seconds.

## 1. Before the first session
- Open **https://claude.ai/artifact/WNcHGuWBMjELqegWCyeihd** in **Safari**, in a normal tab (not Private, which can lose the log). Turn the phone **sideways**.
- Use the same iPhone and the same Safari for every session. The log lives in this browser.
- Loading takes **about 10 s** on mobile data. That is expected.
- The first screen asks **Help us test Killstreak**. Tap **Yes, log my play**. The log is anonymous: a random session code and what you tap. No name, account or location, and nothing leaves the phone until you download it and upload it yourself.
- Answer the **three quick questions** (shooters weekly? card games weekly? deckbuilders?).

## 2. What to play
**One session = open the page, play one run to its end, do the survey, download the log.** A run ends after 5 matches, or sooner if you lose all 3 tickets.

| Session | What to do |
|---|---|
| 1 | On the title, tap **PLAY DRILL** (the 3-minute tutorial) and play it to the end. Then **START NEW RUN** and play the run. |
| 2 | **START NEW RUN**. Try a different killstreak on the Loadout screen. |
| 3–5 | **START NEW RUN**. Play however you like. Try the outcome preview, and long-press cards you don't recognise. |

- **Reload the page between sessions** (pull down or tap ↻). The game shows the survey and the download only once per page load.
- If you have to stop mid-run, close the tab. Next time, **CONTINUE RUN** picks it up, and the survey still comes at the end.
- 3 sessions is enough. 5 is better.

## 3. What to watch for
Don't stop to write notes during a match. Afterwards, send a line or two in the chat (step 4c):
- **Firefights:** after a round, could you tell why you won or lost each lane?
- **Choices:** did each round feel like a real decision, or was one play obvious?
- **Killstreaks:** did earning and calling one in feel like a shooter moment?
- **Stuck or dead moments:** anything you waited on, couldn't find, or tapped and nothing happened.
- **Phone fit:** text too small or cut off (the killfeed names are a known issue), buttons under the notch or the home bar, the page scrolling or zooming by accident.
- **"One more match":** did you want to go straight into the next match?

## 4. After each session: survey, download, upload
**a. Survey and download** (the run end screen leads straight here)
1. Tap **PLAYTEST SURVEY**. Rate 5 statements from 1 (strongly disagree) to 5 (strongly agree), then one optional question. Skip anything you like. Leave out names and personal details.
2. On **Thanks for playing!**, tap **Download log**. Safari asks whether to download `killstreak-playtest-<date>-<code>.jsonl`: tap **Download**.
3. Then tap **Done**.

**b. Rename the file** (until the snag above is fixed)
1. Open the **Files** app → **Downloads**.
2. If you can't see `.jsonl` at the end of the name: tap **•••** (top right) → **View Options** → turn on **Show All Extensions**.
3. Long-press the newest `killstreak-playtest-….jsonl` → **Rename**. Delete the final **l** so it ends in **`.json`** → **Done**. If iPhone asks about changing the extension, tap **Use ".json"**.

**c. Upload**
1. Open the **Studio Floor** → **Chat**.
2. Tap **+ Images / logs** → **Browse** → **Downloads** → pick the `.json` file.
3. Type the session number and your notes, for example *"Session 2. Lost the mid lane twice and couldn't see why."*, then **Send**.

Each download holds every session so far, so it's fine that later files repeat earlier ones. Upload one file per session anyway: if one goes missing, the next still covers it.

**If Download log does nothing or the upload fails:** tap **Copy summary** on the same page, paste it into the chat message, and add a screenshot of the page. Say what happened.

To stop logging and delete the log at any time: on the Thanks page, tap **Stop logging & delete** twice.

## 5. Don't worry about
- Placeholder art, sounds and wording. Do mention anything that blocks you or looks broken.
- The 10 s load on mobile data.
- Losing. A lost run is useful data.

---
*For the studio:* the head uploads each log through the Studio Floor chat. The lead saves the attachments to `projects/killstreak/qa/playtesting/logs/` and runs `python3 tools/kpi_sheet.py` (from `projects/killstreak/`). That writes `qa/playtesting/kpi/kpi-sheet.md` and `.csv`. The report template with the go/no-go criteria is `documentation/production/reports/internal-playtest-report.md`. Don't coach during play, and don't explain the survey statements.

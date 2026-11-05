# KillingCard: MW3 calling cards for the private Activision pitch (kc-cod, step 1)

*Author: Technical Artist Agent · 2026-11-05 · Board task kc-cod · Status: step 1 done (fetch, classify, crop check). Step 2 (wiring) waits for kc-board.*

## 0. Read this first: rights and the public repo
- The head asked to use the real **Call of Duty: Modern Warfare III** calling cards in a **private** prototype that is shown only to Activision, the rights holder. They are Activision's images. We have **no licence** yet. This overrides `../design/card-system.md` §6 ("only original art") **for the private pitch build only**. The shipping game still follows §6.
- **The GitHub repo is public. The images are never committed.** They live in the git-ignored folder `source/project-killingcard/assets/licensed/mw3/` (the root `.gitignore` ignores every `projects/*/source/**/assets/licensed/` folder, which also covers Godot's `.import` sidecars; Godot's own import cache is under the already-ignored `.godot/`).
- The default **Web export preset excludes `assets/licensed/*`**, so the normal build (and the artifact build from `tools/package_artifact_build.sh`) never carries these images. A pitch build needs its own preset (step 2, §5).
- Commit-safe outputs: `tools/fetch_mw3_calling_cards.py`, `mw3-calling-cards-manifest.csv` (titles, file names, tags, no image data) and this doc.
- Many cards also carry **third-party IP inside them**: Call of Duty League team logos, Gundam, Warhammer 40,000, The Boys, Dune, Fallout, The Crow, Little Caesars, Monster Energy, HyperX, Adam Bomb, real-looking faces. Those stay `review = yes` friendly only for an Activision-only showing; never reuse them anywhere else.
- Some cards show **blood or gore** (prestige "kill" cards, zombies). Our art rule has no `v3`; the manifest doesn't carry a violence tag yet. The curator should drop the goriest ones from the pitch deck (they are flagged `review = yes`).

## 1. How to fetch (anyone with network to the two hosts)
```bash
cd projects/killingcard
python3 tools/fetch_mw3_calling_cards.py            # list + download (resumable; ~450 MB)
python3 tools/fetch_mw3_calling_cards.py --refresh  # re-read the wiki page first
```
- Stdlib only. Uses the MediaWiki API on `callofduty.fandom.com` (`action=parse` for the page's card tables, `action=query&prop=imageinfo` for the original URL, size and MIME) and downloads originals from `static.wikia.nocookie.net`. No other host is contacted (the script refuses others).
- Polite: User-Agent `GamestudioPrototype/1.0 (private pitch prototype)`, at most 2 requests/s, 4 retries with backoff (honours `Retry-After`), resumable (skips files already complete, writes via `.part` then rename).
- It **refuses to run** if the output folder is not git-ignored.
- Output (all ignored): `images/<wiki file name>`, `_cache/cards.json` (parsed rows + imageinfo).

## 2. What's on the page: counts
STATS_PLACEHOLDER

## 3. Classification
- Done **by looking at every card** (contact sheets of 36 cards, middle frame for GIFs), not by name. The weapon-mastery cards (all the same layout: one camo'd weapon on a tier-coloured background) were verified on sample sheets and then tagged from the wiki's own class order.
- Rule used (head's decision, `field-cards.md` §3.1): **Fighter or gun → Unit. Symbol or building → Field. A moment → Tactic.** Text-only, logos and skull/crest emblems are Field (`emblem`); a placed device (mine, C4, sign, bank, statue) is Field (`structure`). Doubtful → Tactic or flagged `review = yes`.
- A fourth kind, `killstreak` (card-system §2.2), is used for the few cards whose subject is a jet, helicopter, drone or turret.
- `card` holds the **suggested chassis id**, from card-system §2.3 (units, tactics) and field-cards §3.5 (fields; full Field model is in the prototype, so the fallback is War Standard). `rule` names the table row that matched, so a curator can see why. `hero = yes` marks Elite candidates (only the strongest "throne"/iconic solo cards); the 3-per-Elite cap is the curator's call.
- Columns follow `banner-tags-v1.csv` names where they exist (`kind, subject, weapon_class, element, mood, verb, count, card, animated`) plus source fields (`title, section, group, how_earned, source_file, source_page, w, h, frames, loop_ms`), mastery fields (`mastery_family, mastery_ladder, mastery_tier, tier_rank`), `hero, rule, review, note, licence`. Not filled: `style, violence, setting, palette, banner_y, portrait_x` (defaults apply).

## 4. 4:1 crop check
CROP_PLACEHOLDER

## 5. Step 2 plan (after kc-board lands; nothing wired yet)
WIRING_PLACEHOLDER

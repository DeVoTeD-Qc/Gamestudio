# KillingCard: MW3 calling cards for the private Activision pitch (kc-cod, step 1)

*Author: Technical Artist Agent · 2026-11-05 · Board task kc-cod · Status: step 1 done (fetch, classify, crop check). Step 2 (wiring) waits for kc-board.*

## 0. Read this first: rights and the public repo
- The head asked to use the real **Call of Duty: Modern Warfare III** calling cards in a **private** prototype that is shown only to Activision, the rights holder. They are Activision's images. We have **no licence** yet. This overrides `../design/card-system.md` §6 ("only original art") **for the private pitch build only**. The shipping game still follows §6.
- **The GitHub repo is public. The images are never committed.** They live in the git-ignored folder `source/project-killingcard/assets/licensed/mw3/` (the root `.gitignore` ignores every `projects/*/source/**/assets/licensed/` folder, which also covers Godot's `.import` sidecars; Godot's own import cache is under the already-ignored `.godot/`).
- The default **Web export preset excludes `assets/licensed/*`**, so the normal build (and the artifact build from `tools/package_artifact_build.sh`) never carries these images. A pitch build needs its own preset (step 2, §5).
- Commit-safe outputs: `tools/fetch_mw3_calling_cards.py`, `mw3-calling-cards-manifest.csv` (titles, file names, tags, no image data) and this doc.
- Many cards also carry **third-party IP inside them**: Call of Duty League team logos, Gundam, Warhammer 40,000, The Boys, Dune, Fallout, The Crow, Little Caesars, Monster Energy, HyperX, Adam Bomb, real-looking faces. They are flagged `review = yes`. Even an Activision-only showing may need those partners' OK; never reuse them anywhere else.
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
| | Cards |
|---|---|
| **Total calling cards on the page** | **1676** (all downloaded, 0 failed) |
| Animated (GIF with more than one frame) / static | **1009** / **667** |
| Weapon-mastery cards (camo tiers) | 787 (all animated) |
| Everything else | 889 (222 animated, 667 static) |
| Kind, all cards: unit / tactic / field / killstreak | 1422 / 122 / 122 / 10 |
| Kind, without the mastery cards | 635 / 122 / 122 / 10 |
| `review = yes` (doubtful kind, licensed third-party IP, real-looking people, gore) | 212 |
| Elite candidates (`hero = yes`) | 11 (design cap: 3 per Elite) |

Sections on the wiki page: Standard (Default, Store bundles, Battle Pass, Events, Armory Unlocks, Miscellaneous), Campaign, Challenges (General, Multiplayer, Zombies, Warzone), Ranked Play, Zombies, Warzone (General, World Series), Prestige Mastery (MP and Zombies, 25 prestiges x 5), Weapon Mastery (MP, Zombies MW3, Zombies MWII). The section and the "how to obtain" text are in every manifest row.

### 2.1 Suggested chassis (count of cards; "pool" = without the mastery cards)
| Chassis | All | Pool | | Chassis | All | Pool |
|---|---|---|---|---|---|---|
| `rifleman` | 447 | 248 |  `blackout` * | 18 | 18 |
| `point_man` | 296 | 96 |  `suppressing_fire` | 8 | 8 |
| `combat_medic` | 10 | 10 |  `hold_the_line` | 0 | 0 |
| `recon_specialist` | 20 | 20 |  `sabotage` * | 5 | 5 |
| `brawler` * | 180 | 112 |  `breach_and_clear` | 18 | 18 |
| `breacher` | 75 | 19 |  `tripwire_charge` | 3 | 3 |
| `marksman` | 172 | 24 |  `comms_relay` | 7 | 7 |
| `flanker` | 27 | 27 |  `listening_post` | 16 | 16 |
| `shieldman` | 27 | 23 |  `mortar_pit` | 7 | 7 |
| `gunner` | 104 | 24 |  `aid_station` | 0 | 0 |
| `demolitions_expert` | 53 | 21 |  `sniper_perch` | 0 | 0 |
| `okafor_anvil` | 11 | 11 |  `bulwark` | 3 | 3 |
| `halek_wren` | 0 | 0 |  `war_standard` | 86 | 86 |
| `callout` | 18 | 18 |  `recon_drone` | 2 | 2 |
| `ammo_resupply` | 33 | 33 |  `mortar_barrage` | 1 | 1 |
| `flank_route` | 13 | 13 |  `sentry_turret` | 2 | 2 |
| `smoke_screen` * | 9 | 9 |  `attack_helo` | 5 | 5 |

\* designed in card-system §3.2 but not yet in `data/cards/` (212 cards point at them).

**Spread problems (guard rail: no chassis above 12% of arts):** in the pool, `rifleman` holds 28% and `brawler` 13%. MW3 is mostly "operator with a rifle" and "zombie/monster" art, so the curator should use the "any eligible chassis" freedom (e.g. stealthy soldiers to Flanker, squads to Hold the Line-style roles) or simply pick a balanced subset for the pitch (the pitch needs ~72 arts, not 1676).

**No art at all:** `halek_wren` (Ace, no hero sniper card), `hold_the_line` (its old emblem route now goes to Fields), `aid_station`, `sniper_perch`. Thin (1-3): `mortar_barrage`, `recon_drone`, `sentry_turret`, `bulwark`, `tripwire_charge`. The killstreaks have only 10 cards between them.

**Cards that don't really fit a chassis** (they still get the fallback so nothing is unmapped):
- 86 Field cards go to War Standard, 85 of them only through the fallback: Call of Duty League team logos (12 teams), ranked-season badges and Top 250 / #1 skull crests, text-only banners (sponsor and event cards). They are symbols with no action, so any Field fits equally.
- 15 tactics fall back to Ammo Resupply: everyday objects and jokes (food, game screens, phone chats, arcade machines).
- Non-combat "characters" (anime idols, gamers, a soccer player, a family dinner, astronauts) are Units by the rule but have no weapon, so they land on Rifleman by fallback; most are `review = yes`.
- Licensed crossovers (Gundam, Warhammer 40,000, The Boys, Dune, The Crow, Fallout) fit their chassis visually but carry a second rights holder.

### 2.2 Weapon-mastery families (Operator banners with camo variants)
Every mastery card is the same composition: one weapon in a mastery camo, centre-right, on a tier-coloured diagonal background, animated (shimmer). The tier ladders:

| Ladder | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---|---|---|---|
| Multiplayer (MW3 weapons) | Gilded (gold) | Forged (silver-white) | Priceless (iridescent blue) | Interstellar (cosmic) |
| Zombies, MW3 weapons | Golden Enigma | Zircon Scale | Serpentinite | Borealis |
| Zombies, MWII weapons | Golden Ivory | Spinel Husk | Arachnida | Bioluminescent |

- **137 weapon families**: 60 MW3 weapons with **8 tiers** (MP ladder + Zombies ladder), 76 MWII weapons with 4 tiers, 1 incomplete (wm_ftac_recon: the wiki has no Bioluminescent card). Plus 3 "Grand Mastery" cards (one per ladder), filed as Field emblems.
- By class (one weapon counted once): ar 35, sniper 24, smg 23, lmg 13, sidearm 12, melee 12, shotgun 10, launcher 6, bow 2. Class comes from the wiki's own class order in the tables; the Torque-35 sits in the launcher block but the card shows a compound bow, so it is tagged `bow`. Riot Shield is tagged `verb = guarding` so it lands on Protector.
- Manifest columns: `mastery_family` (e.g. `wm_sva_545`), `mastery_ladder` (`mp`, `zm_mw3`, `zm_mw2`), `mastery_tier`, `tier_rank` (1-4). Mastery cards are `kind = unit`, `subject = weapon_only`, `verb = showcase`, mapped by class: AR → Rifleman, SMG/sidearm → Point Man, shotgun → Breacher, sniper/bow → Marksman, LMG → Gunner, launcher → Demolitions Expert, melee → Brawler.
- **For the head's Operator idea** this is a ready-made progression: the Operator's primary weapon picks the family, and Operator kills climb Gilded → Forged → Priceless → Interstellar (then the Zombies ladder as prestige tiers for MW3 weapons). It maps one-to-one onto card-system §5's bronze → silver → gold mastery border, with a 4th tier.


## 3. Classification
- Done **by looking at every card** (contact sheets of 36 cards, middle frame for GIFs), not by name. The weapon-mastery cards (all the same layout: one camo'd weapon on a tier-coloured background) were verified on sample sheets and then tagged from the wiki's own class order.
- Rule used (head's decision, `field-cards.md` §3.1): **Fighter or gun → Unit. Symbol or building → Field. A moment → Tactic.** Text-only, logos and skull/crest emblems are Field (`emblem`); a placed device (mine, C4, sign, bank, statue) is Field (`structure`). Doubtful → Tactic or flagged `review = yes`.
- A fourth kind, `killstreak` (card-system §2.2), is used for the few cards whose subject is a jet, helicopter, drone or turret.
- `card` holds the **suggested chassis id**, from card-system §2.3 (units, tactics) and field-cards §3.5 (fields; full Field model is in the prototype, so the fallback is War Standard). `rule` names the table row that matched, so a curator can see why. `hero = yes` marks Elite candidates (only the strongest "throne"/iconic solo cards); the 3-per-Elite cap is the curator's call.
- Columns follow `banner-tags-v1.csv` names where they exist (`kind, subject, weapon_class, element, mood, verb, count, card, animated`) plus source fields (`title, section, group, how_earned, source_file, source_page, w, h, frames, loop_ms`), mastery fields (`mastery_family, mastery_ladder, mastery_tier, tier_rank`), `hero, rule, review, note, licence`. Not filled: `style, violence, setting, palette, banner_y, portrait_x` (defaults apply).

## 4. 4:1 crop check
- **The MW3 cards are exactly 4:1.** 1,672 of 1,676 are 4.00 (1,651 at 512x128, the rest 256x64, 960x240, 1024x256, 2048x512 or 4096x1024, also 4:1). Four are slightly off: *LAN Ho!* 1921x512 (3.75), *The Truth Lies* 452x128 (3.53), *Zombies Mechanism* 422x104 (4.06), *Dragon's Glow* 535x133 (4.02).
- The board banner slot is 4:1 at 512x128 logical (art doc §1.3/§3.2, `BannerArt.BANNER_RATIO`). `BannerArt.band_rect` therefore takes the **whole image, no crop**, for every 4:1 card. The four odd ones lose at most 32 px of height (LAN Ho!) or 15 px (The Truth Lies), or 3 px per side (Zombies Mechanism): nothing important.
- **Resolution:** 512x128 is 1x for the 512-logical slot. On the phone board (banner drawn ~150-220 pt wide, 2-3x screens) that is 300-660 px, so it's about right on 2x and slightly soft on 3x tablets. Our own spec ships 1152x288 (2.25x). Only 21 cards come at 1024 px or more.
- **Icon safe zones:** MW3 cards were not composed for our 15% side icon zones. A quick edge-detail measure says the outer 15% holds more detail than the middle on 32% (285/889) of the non-mastery cards and on 83% (655/787) of the mastery cards (their diagonal tier stripes run to the edges). For the pitch build, turn on the art doc's "safety net" (15% side gradient, black ~35%) behind the stat icons.
- **Hand card (2:3 portrait):** a 2:3 column from a 128 px tall card is only **85x128 px**, shown at 256x384: a 3x upscale, blurry, and it shows 1/6 of the banner (often half a face or the middle of a rifle). Recommendation for the licensed build: hand cards show the **4:1 banner strip** (full card, no portrait crop) with the name, instead of the portrait crop; or, at minimum, set `portrait_x` per card for the ~72 pitch arts.
- Text: many MW3 cards contain text and logos (our own art never does). Several put the text in the left or right third, where our icons sit. The curator should prefer cards without side text for the pitch set.


## 5. Step 2 plan (after kc-board lands; nothing wired yet)
**kc-board has landed** and its `scripts/ui/art/banner_art_db.gd` already has the hook this task needs (lookup step 1b): if `res://assets/licensed/mw3/manifest.csv` exists it uses the first row per chassis id (`file`, `kind`, `card`, `banner_y`, `portrait_x`, `title`), and a clean checkout silently falls back to placeholders. So:

1. **Done now, local only (git-ignored):** the manifest step also writes `assets/licensed/mw3/manifest.csv` (1,676 rows plus 4 Operator rows, ordered so that a non-review, non-mastery, static card comes first per chassis) and `assets/licensed/mw3/stills/*.png`: one representative frame per GIF, because **Godot 4.4 has no GIF importer** (`_load_image` reads PNG/JPG/WebP only). With the folder present, every chassis, every killstreak and the Operator (art id = the primary weapon: `kestrel_ar7` → MCW, `longreach_338` → KATT-AMR, `wasp_9` → WSP-9, `p12_sidearm` → COR-45, Gilded tier) already shows an MW3 card. Not tested in-engine yet (no Godot run in this step).
2. **Per-copy art** (different MW3 cards for each copy of a chassis): needs card-system §4.6 `art_by_uid` and an art id per copy; BannerArtDB is keyed by chassis today. Owner: Mechanics Developer.
3. **Animation:** convert each GIF offline (Python, in the ignored folder) to a frame sheet PNG + frame timings, and play it as a small `SpriteFrames`/shader flipbook only when the card is focused or placed (art doc §4). 1,009 animated cards have 7 to 33 frames (median 12, about a 1 s loop) at 512x128; load only the pitch set.
4. **Operator mastery ladder:** add `mastery_family` + tier to the Operator banner; tier from Operator kills (4 tiers, then the Zombies ladder as prestige). The tier also drives the frame colour (card-system §5).
5. **Pitch build:** a second export preset ("Web (private pitch)") that includes `assets/licensed/*`, exporting to a git-ignored folder. Note that `.gitignore` covers `builds/**/*.pck` but **not** the artifact names `game.pck.wasm`/`engine.gz.wasm`, so the pitch output folder must be ignored as a whole (e.g. `projects/*/builds/pitch/`) before the first pitch export. Never publish a pitch build as a shared page without the head's explicit OK.
6. **Curate the pitch set** (~72 arts, card-system §3.3): one or two per chassis, avoid side text, gore and third-party crossovers, respect the 12% spread and the 3-per-Elite cap.


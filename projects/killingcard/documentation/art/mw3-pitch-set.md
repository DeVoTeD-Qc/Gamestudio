# MW3 pitch set (kc-cod2, kc-cod3): curated calling cards for the private Activision pitch

**PRIVATE PITCH ONLY.** The images are Activision's and are not licensed to us. This file lists titles and ids only; the images live in the git-ignored `source/project-killingcard/assets/licensed/` and only the "Web (private pitch)" export carries them. Never commit, publish or reuse them.

## 1. What the set is
- **96 calling cards** on 32 chassis, plus **16 Operator mastery cards** (4 weapons x 4 multiplayer tiers): 112 arts, 42 animated.
- By kind: 60 units, 20 tactics, 10 Fields, 6 killstreaks.
- Spread: no chassis above 9 cards (9.4% of the card arts; guard rail 12%).
- Every pick is `review = no` in `mw3-calling-cards-manifest.csv` and was checked by eye on contact sheets: no third-party IP, no real-looking celebrities, no blood or gore, little or no side text over the icon columns. Cards the classifier had missed were flagged `review = yes` while curating (Gundam x3, Homelander, Toronto Ultra, Carolina Royal Ravens, Xolos de Tijuana, Rojinegros, Little Caesars "Hot-N-Ready"; kc-cod3: ten 2024 Call of Duty League team cards, The Boys, Monster Energy, Gallos Blancos).
- **No MW3 text on Fields or tactics** (head, kc-cod3): the ranked "Top 250 / #1" crests, "TOP SECRET", "DISARMED", "FLASHED" and the hacked-screen card were swapped for text-free crests and images.
- **Image decides the chassis** (head, kc-cod2): soldiers and weapons are units matched by weapon or role; explosions and barrages are damage tactics or killstreaks; smoke, night and blinding are Smoke Screen / Blackout; intel is Callout; crates are Ammo Resupply; emblems, crests and structures are Fields. Ambiguous images were skipped. No art fit Sniper Perch or Aid Station, so those two keep the placeholder (they are not in the pitch decks).
- **Name on the card:** a card wearing one of these arts shows the calling card's own title as its name (hand card, inspector title, hover zoom); the chassis name moves to the type line ("Laser Grid", type "Flanker · unit · SMG"). The Operator keeps its weapon name.

## 2. Mapping: title -> chassis, and why
| # | Calling card | Chassis | Kind | Anim. | Why (what the image shows) |
|---|---|---|---|---|---|
| 1 | Banner Waves | Rifleman | unit | yes | operator with an assault rifle |
| 2 | Crosshairs | Rifleman | unit | yes | operator with an assault rifle |
| 3 | Imbued | Rifleman | unit |  | operator with an assault rifle |
| 4 | God Ray | Rifleman | unit |  | operator with an assault rifle |
| 5 | Beta Tester | Rifleman | unit | yes | operator with an assault rifle |
| 6 | Friends Don't Let Friends Fire Alone | Rifleman | unit |  | operator with an assault rifle |
| 7 | Fireproof | Rifleman | unit | yes | operator with an assault rifle |
| 8 | No Effs Given | Rifleman | unit | yes | operator with an assault rifle |
| 9 | Glowing Eyes | Rifleman | unit |  | operator with an assault rifle |
| 10 | Smoking Guns | Point Man | unit | yes | operator with an SMG or pistol, close in |
| 11 | Staying On Beat | Point Man | unit |  | operator with an SMG or pistol, close in |
| 12 | Two Sides To Everything | Point Man | unit |  | operator with an SMG or pistol, close in |
| 13 | Squeeze The Trigger | Point Man | unit | yes | operator with an SMG or pistol, close in |
| 14 | Cobalt Conspirator | Point Man | unit |  | operator with an SMG or pistol, close in |
| 15 | Bang! | Point Man | unit |  | operator with an SMG or pistol, close in |
| 16 | Running Out Of Time | Point Man | unit |  | operator with an SMG or pistol, close in |
| 17 | Laser Grid | Flanker | unit | yes | stealthy operator moving or infiltrating |
| 18 | Operation Azure | Flanker | unit |  | stealthy operator moving or infiltrating |
| 19 | Can't Catch Me | Flanker | unit | yes | stealthy operator moving or infiltrating |
| 20 | Operator Infil | Flanker | unit | yes | stealthy operator moving or infiltrating |
| 21 | In The Trees | Flanker | unit |  | stealthy operator moving or infiltrating |
| 22 | Blaze Of Glory | Gunner | unit |  | heavy machine gun firing |
| 23 | Unleashing Chaos | Gunner | unit |  | heavy machine gun firing |
| 24 | Suppression | Gunner | unit |  | heavy machine gun firing |
| 25 | Heavy Barrage | Gunner | unit |  | heavy machine gun firing |
| 26 | Speed Bumps | Gunner | unit |  | heavy machine gun firing |
| 27 | Chaos Of Battle | Marksman | unit |  | sniper rifle / scope |
| 28 | Scoped And Ready | Marksman | unit |  | sniper rifle / scope |
| 29 | Glint | Marksman | unit |  | sniper rifle / scope |
| 30 | Message Inbound | Marksman | unit |  | sniper rifle / scope |
| 31 | Snow Snipers | Marksman | unit |  | sniper rifle / scope |
| 32 | Art Of Disguise | Marksman | unit | yes | sniper rifle / scope |
| 33 | Big Game Hunter | Ace | unit |  | lone sniper hunting (Ace, sniper elite) |
| 34 | Keeping These | Protector | unit | yes | riot shield / armoured defender (Protector) |
| 35 | Shields Above All | Protector | unit |  | riot shield / armoured defender (Protector) |
| 36 | Quiet At Last | Protector | unit |  | riot shield / armoured defender (Protector) |
| 37 | Broken Walls | Breacher | unit | yes | shotgun at close quarters / room entry |
| 38 | CQC (Close Quarters Combat) | Breacher | unit |  | shotgun at close quarters / room entry |
| 39 | Behind The Door | Breacher | unit |  | shotgun at close quarters / room entry |
| 40 | Clearer Vision | Breacher | unit |  | shotgun at close quarters / room entry |
| 41 | Battle Stance | Demolitions Expert | unit |  | launcher, grenade or demolition |
| 42 | Throw Like You Mean It | Demolitions Expert | unit |  | launcher, grenade or demolition |
| 43 | Out With A Bang | Demolitions Expert | unit |  | launcher, grenade or demolition |
| 44 | Armor Crusher | Demolitions Expert | unit |  | launcher, grenade or demolition |
| 45 | Cycloptic | Recon Specialist | unit | yes | night vision, optics, scouting |
| 46 | Infiltration | Recon Specialist | unit |  | night vision, optics, scouting |
| 47 | Seal Time | Recon Specialist | unit |  | night vision, optics, scouting |
| 48 | Blizzard Patrol | Recon Specialist | unit |  | night vision, optics, scouting |
| 49 | Combat Surgeon | Combat Medic | unit |  | medical or stim gear |
| 50 | Refreshing! | Combat Medic | unit |  | medical or stim gear |
| 51 | Drink Up | Combat Medic | unit |  | medical or stim gear |
| 52 | Golden Throne | Commander | unit |  | commander on a throne (Elite) |
| 53 | King Of It All | Commander | unit |  | commander on a throne (Elite) |
| 54 | Bullet Pro | War Standard | field | yes | text-free skull / helmet crest |
| 55 | Turning Tide | War Standard | field | yes | text-free skull / helmet crest |
| 56 | Warmonger | War Standard | field | yes | text-free skull / helmet crest |
| 57 | Mythical Crate | Ammo Resupply | tactic |  | supply crate / loot |
| 58 | The Heist | Ammo Resupply | tactic | yes | supply crate / loot |
| 59 | Making Bank | Ammo Resupply | tactic |  | supply crate / loot |
| 60 | Ruptured World | Breach and Clear | tactic |  | explosion (damage tactic) |
| 61 | Scorched Beginnings | Breach and Clear | tactic | yes | explosion (damage tactic) |
| 62 | Going Down | Breach and Clear | tactic |  | explosion (damage tactic) |
| 63 | Specter Vision | Callout | tactic | yes | intel: eye, scanner, dossier |
| 64 | Primal Instinct | Callout | tactic | yes | intel: eye, scanner, dossier |
| 65 | He's Watching | Callout | tactic |  | intel: a figure watching from the dark |
| 66 | Geometric Resonance | Listening Post | field |  | emblem (skull sigil) |
| 67 | Bursting | Listening Post | field |  | emblem (skull sigil) |
| 68 | Redeploy | Comms Relay | field |  | parachute insignia (comms / redeploy) |
| 69 | Golden Parachute | Comms Relay | field |  | parachute insignia (comms / redeploy) |
| 70 | Gotta Go Fast | Flank Route | tactic | yes | fast vehicle on the move |
| 71 | Night Driving | Flank Route | tactic |  | fast vehicle on the move |
| 72 | Fire Banisher | Mortar Pit | field |  | winged fire emblem |
| 73 | Lead Salad | Suppressing Fire | tactic |  | hail of bullets / city on fire |
| 74 | City On Fire | Suppressing Fire | tactic |  | hail of bullets / city on fire |
| 75 | Mind Your Feet | Tripwire Charge | field |  | tripwire mine |
| 76 | Eternal Guardian | Bulwark | field |  | stone guardian crest |
| 77 | Sunset Assault | Attack Helo | killstreak |  | attack helicopter |
| 78 | Eyes in the Sky | Recon Drone | killstreak | yes | drone in the sky |
| 79 | Ground To Air | Sentry Turret | killstreak |  | automated turret firing |
| 80 | Lethal Payload | Mortar Barrage | killstreak |  | missile / bombs / fireworks barrage |
| 81 | Payload Inbound | Mortar Barrage | killstreak |  | missile / bombs / fireworks barrage |
| 82 | Dragon's Glow | Mortar Barrage | killstreak |  | missile / bombs / fireworks barrage |
| 83 | Shield Day | Hold the Line | tactic |  | shield wall / holding the flag |
| 84 | Protect The Flag | Hold the Line | tactic |  | shield wall / holding the flag |
| 85 | Last Look | Brawler | unit |  | melee: blade, fists, bat |
| 86 | Sliced Up | Brawler | unit |  | melee: blade, fists, bat |
| 87 | Charging... | Brawler | unit | yes | melee: blade, fists, bat |
| 88 | In The Spotlight | Brawler | unit | yes | melee: blade, fists, bat |
| 89 | Knuckle Bros | Brawler | unit |  | melee: blade, fists, bat |
| 90 | Raging | Brawler | unit |  | melee: blade, fists, bat |
| 91 | Baseball Fan | Brawler | unit |  | melee: blade, fists, bat |
| 92 | Close Your Eyes | Blackout | tactic |  | flashbang / blinding / hacked screens |
| 93 | Zapped | Blackout | tactic |  | electrocuted, blinded skeletons |
| 94 | Tales Of The Night | Smoke Screen | tactic | yes | night cover |
| 95 | Detonated | Sabotage | tactic |  | detonator in hand: blowing up enemy gear |
| 96 | Fireworks Show | Sabotage | tactic |  | planted charge with a timer |

### 2.1 Operator mastery ladder
The Operator wears the weapon-mastery card of its primary weapon. Tier 1 (Gilded) is the **Base** camo for both sides (head, B3); higher tiers are a dev preview only.
| Operator weapon | Tier 1 (Base) | Tier 2 | Tier 3 | Tier 4 |
|---|---|---|---|---|
| Operator: Kestrel AR-7 (MCW) | MCW Mastery: Gilded | MCW Mastery: Forged | MCW Mastery: Priceless | MCW Mastery: Interstellar |
| Operator: Longreach .338 (KATT-AMR) | KATT-AMR Mastery: Gilded | KATT-AMR Mastery: Forged | KATT-AMR Mastery: Priceless | KATT-AMR Mastery: Interstellar |
| Operator: Wasp-9 (WSP-9) | WSP-9 Mastery: Gilded | WSP-9 Mastery: Forged | WSP-9 Mastery: Priceless | WSP-9 Mastery: Interstellar |
| Operator: P-12 sidearm (COR-45) | COR-45 Mastery: Gilded | COR-45 Mastery: Forged | COR-45 Mastery: Priceless | COR-45 Mastery: Interstellar |

Camo band per tier: Base (olive), Forged (silver-white), Priceless (blue), Interstellar (purple). Dev toggle: `?mastery=N` (1-4) in the URL, or **Ctrl+M** on the match screen cycles the tier.

## 3. How it works in the game
- **Per-copy art** (card-system §4.6/§5.2, display only): `MatchState.art_by_uid` (card uid -> art id), filled from `SideSetup.deck_arts`. `BannerArtDB.copy_arts` gives the n-th copy of a chassis, counted across both sides, the n-th art of its pool, so copies of a chassis wear different banners. Fields on the objective tile use their copy's art too.
- **Inspector card picture:** the card view next to the inspector text shows the copy's licensed art too (cover crop of the strip), and its name is the calling card title; the Operator's card picture shows its mastery card.
- **Hand cards:** licensed art is a 4:1 strip, so the hand card shows the whole strip at the bottom of its art window over a dimmed cover crop of it (no 85x128 portrait crop). Our own art keeps option A.
- **Safety net:** licensed banners get a 15% black side gradient (35% at the edge) behind the corner icons.
- **Animation:** Godot 4.4 cannot import GIF, so `tools/build_mw3_pitch_set.py` writes each animated card as a vertical WebP frame sheet (384x96 cells, at most 16 frames). BannerView plays it as a flipbook only while the banner is focused (inspector, hover zoom) or being placed, one at a time (`BannerView.focus_owner`).
- **Pitch decks** (`scripts/data/pitch_decks.gd`, export feature `licensed_pitch` only; head, kc-cod3): about half units, 3 Fields, the rest tactics. The player's 20 cards become **10 units / 7 tactics / 3 Fields**; the AI squads (18-20 cards) get 9-10 / 6-7 / 3. Brawler replaces a duplicate unit; War Standard and Listening Post come in as Fields; Smoke Screen, Blackout and Sabotage replace duplicate units down to the unit target, then duplicate older tactics. Sniper Perch and Aid Station never appear in a pitch deck. The public build and the saved run deck are unchanged.
- **New chassis (data only):** Brawler, Smoke Screen, Blackout and Sabotage exist in `data/cards/` (card-system §3.2, existing effect kinds, written by `tests/tools/gen_cod_chassis.gd`). They are not in the reward pool, the starter deck or the squads until `balance_sim.gd` has run with them.

## 4. Build it (anyone with the downloaded cards)
```bash
cd projects/killingcard
python3 tools/fetch_mw3_calling_cards.py              # step 1: download (git-ignored)
python3 tools/build_mw3_pitch_set.py                  # step 2: stills + frame sheets -> assets/licensed/mw3_pitch/
bash tools/package_artifact_build.sh <godot> <out-dir> --pitch   # out-dir outside the repo or git-ignored
```
- The pitch set is about 5.5 MB of WebP; the packaged `game.pck.wasm` is about 9.6 MB (artifact limit 16 MB per file).
- The default "Web" preset still excludes `assets/licensed/*`, and the default package run does not even copy that folder into its build tree. The script refuses a pitch output folder inside the repo unless git ignores it; `.gitignore` covers `projects/*/builds/pitch/` and any `web-pitch/` folder.
- Tests never use the licensed folder (`run_tests.gd` switches it off); they pass with the folder present or absent.

# MW3 pitch set (kc-cod2, kc-cod3): curated calling cards for the private Activision pitch

**PRIVATE PITCH ONLY.** The images are Activision's and are not licensed to us. This file lists titles and ids only; the images live in the git-ignored `source/project-killingcard/assets/licensed/` and only the "Web (private pitch)" export carries them. Never commit, publish or reuse them.

## 1. What the set is
- **113 calling cards** on 32 chassis, plus **16 Operator mastery cards** (4 weapons x 4 multiplayer tiers): 129 arts, 52 animated (kc-syn-impl: 31 unit arts re-picked to their trait family, §1.1; kc-art-traits-impl: 17 alternate-trait arts added, §1.2).
- By kind: 60 units, 20 tactics, 10 Fields, 6 killstreaks.
- Spread: no chassis above 9 cards (9.4% of the card arts; guard rail 12%).
- Every pick is `review = no` in `mw3-calling-cards-manifest.csv` and was checked by eye on contact sheets: no third-party IP, no real-looking celebrities, no blood or gore, little or no side text over the icon columns. Cards the classifier had missed were flagged `review = yes` while curating (Gundam x3, Homelander, Toronto Ultra, Carolina Royal Ravens, Xolos de Tijuana, Rojinegros, Little Caesars "Hot-N-Ready"; kc-cod3: ten 2024 Call of Duty League team cards, The Boys, Monster Energy, Gallos Blancos).
- **No MW3 text on Fields or tactics** (head, kc-cod3): the ranked "Top 250 / #1" crests, "TOP SECRET", "DISARMED", "FLASHED" and the hacked-screen card were swapped for text-free crests and images.
- **Image decides the chassis** (head, kc-cod2): soldiers and weapons are units matched by weapon or role; explosions and barrages are damage tactics or killstreaks; smoke, night and blinding are Smoke Screen / Blackout; intel is Callout; crates are Ammo Resupply; emblems, crests and structures are Fields. Ambiguous images were skipped. No art fit Sniper Perch or Aid Station, so those two keep the placeholder (they are not in the pitch decks).
- **Name on the card:** a card wearing one of these arts shows the calling card's own title as its name (hand card, inspector title, hover zoom); the chassis name moves to the type line ("Laser Grid", type "Flanker · unit · SMG"). The Operator keeps its weapon name.

### 1.1 Trait families (kc-syn-impl, head S1)
Traits live on the chassis (synergy-system.md §4.1) and each traited chassis wears its **calling-card family**, so "same kind played together" shows on screen:
| Trait | Chassis | Family (manifest `section`) |
|---|---|---|
| Vanguard | Point Man, Breacher, Protector (Bulwark) | Prestige Mastery / Multiplayer, Ranked Play, Challenges / Multiplayer and General |
| Spec Ops | Flanker, Recon Specialist, Marksman (Ace, Sniper Perch) | Standard / Store, Battle Pass, Armory Unlocks, Events (operator bundles) |
| Heavy | Gunner (LMG mastery), Demolitions Expert (launcher mastery) (Commander, Mortar Pit) | Weapon Mastery (Gilded / Golden Ivory tiers; Interstellar stays the Operator's) |
| Undead | Brawler, Combat Medic (War Standard, Aid Station) | Challenges / Zombies, Prestige Mastery / Zombies, Zombies |

- 19 of the set's traited unit / Field arts already matched; **31 were re-picked** (`review = no` only, never an id already in the set, no duplicate title) and checked by eye on contact sheets. Rejected on sight: Smoke And Blood, Cut And Gutted, Green Glow, Pure Rage, Chest Cavity Cave In, Room Cleared (blood), Too Much Speed (no weapon), Going Down and Bursting (titles already in the set).
- **Kept as they were:** the Elites (Ace: Big Game Hunter, Commander: Golden Throne / King Of It All), Bulwark and Mortar Pit (no family art fits a crest), and one Marksman (Snow Snipers: the Spec Ops family has only four usable sniper arts). The rule is the trait icon, not the art.
- Heavy units wear heavy-weapon soldiers and demolitions (kc-pitch-art, §1.3: weapon-mastery cards are the Operator's only); their rows keep `family = mastery` (Heavy) and an empty `mastery_family`, so BannerArtDB never mistakes them for the Operator's mastery ladder.

### 1.2 Alternate-trait arts (kc-art-traits-impl, head T1)
The art now gives the trait (`documentation/design/art-traits.md`): a copy's trait is its art's **family** (`family` column of `mw3-pitch-set.csv`, from the manifest `section`: Honors -> Vanguard, Operators -> Spec Ops, Mastery -> Heavy, Horde -> Undead, Standard -> none), if that trait is one of the chassis' options. The builder writes `family` and the resolved `trait` into the pitch manifest. Each chassis' home-family arts stay first (the first row is the default art); the alternates follow:
| Option | Added (all `review = no`, checked by eye on a contact sheet) |
|---|---|
| Rifleman · Undead | Helo Exfil, In Trouble |
| Rifleman · Spec Ops | Solid Tactics, Swamp Guys (Warzone) |
| Point Man · Undead | Violent Vortex, Wolves Wasted |
| Breacher · Heavy | Clearer Vision, CQC (Close Quarters Combat) (kc-pitch-art: were Lockwood 680 / Haymaker masteries) |
| Protector · Undead | Surrounded |
| Recon Specialist · Undead | Seal Time |
| Marksman · Heavy | Long Distance Laser, Message Inbound (kc-pitch-art: were KVD Enforcer / MCW 6.8 masteries) |
| Gunner · Spec Ops | Lead Rain, Download Complete |
| Demolitions Expert · Undead | Objective Destroyed, Boom And Gloom |
| Brawler · Spec Ops | Big Sword |
| Flanker · Undead, Combat Medic · Spec Ops | **none usable**: these options wear our placeholder option art (`flanker~horde`, `combat_medic~operators`, ArtTraits.OPTION_VARIANTS), so every option still has a free default art |

- **Rejected on sight:** Still Standing (blood on the face), Quiet Kill (head shot with blood: Flanker · Undead has no MW3 art now), Charging... (UI text across the art, branded look). Not needed (one or two per option is enough): Random Rewards, Loot At Me, Mayhem On Wheels, Riveter Mastery, Longbow Mastery.
- **Crossover IP flagged (never use; tagged `review = no` in the manifest by mistake):** Cadia Stands! (Warhammer 40,000), Char's Laugh (Gundam), Here Comes The A-Train (The Boys). The manifest should mark them `review = yes` (Technical Artist). Any Store bundle card with a third-party character needs the same eye check before it enters the set.
- **Plain arts kept:** the four Honors Riflemen (Vanguard is not a Rifleman option) and Snow Snipers on the Marksman play as plain copies when they are worn; they stay as looks.

### 1.3 Weapon cards only on Operators (kc-pitch-art, head)
"Never use GUN-specific calling card images for units or any other cards than Operators." Every row of `mw3-pitch-set.csv` was audited: the classifier (`section` Weapon Mastery, `subject` weapon_only, `mastery_family`) found 20 weapon cards off the Operator, and a contact sheet by eye added three gun showcases (Dual SMGs, All The Guns, Too Many Lasers?). All 23 were re-picked (`review = no`, no blood, no event or game logos, no id, title or image already in the set): see §2 and §2.2, and the "was ..." notes there.
- **Heavy look:** the Heavy units (Gunner, Demolitions Expert, and the Breacher / Marksman Heavy option) now wear soldiers with heavy weapons, explosions and demolitions instead of weapon-mastery cards. Their CSV `family` stays `mastery`, so the chassis keep their Heavy option (the trait is curated, not read from the card's own MW3 section for these 13 rows).
- **Privates:** back on the pitch starter's earlier arts (head: "They were nice"), see §2.2.
- Weapon-mastery cards now appear only on the four Operators' mastery ladders. Kept after the eye check: soldier cards where the person is the subject and the gun is in their hands (e.g. Smoking Guns, Nades And Guns, Big Sword).

## 2. Mapping: title -> chassis, and why
| # | Calling card | Chassis | Kind | Anim. | Why (what the image shows) |
|---|---|---|---|---|---|
| 1 | Banner Waves | Rifleman | unit | yes | operator with an assault rifle |
| 2 | Crosshairs | Rifleman | unit | yes | operator with an assault rifle |
| 3 | Harvesting Season | Rifleman | unit |  | gas-masked operator with a rifle in a swamp (kc-pitch-art: was Imbued, a gun showcase) |
| 4 | God Ray | Rifleman | unit |  | operator with an assault rifle |
| 5 | Beta Tester | Rifleman | unit | yes | operator with an assault rifle |
| 6 | Friends Don't Let Friends Fire Alone | Rifleman | unit |  | operator with an assault rifle |
| 7 | Fireproof | Rifleman | unit | yes | operator with an assault rifle |
| 8 | No Effs Given | Rifleman | unit | yes | operator with an assault rifle |
| 9 | Glowing Eyes | Rifleman | unit |  | operator with an assault rifle |
| 10 | Smoking Guns | Point Man | unit | yes | operator with an SMG or pistol, close in |
| 11 | Non-Business | Point Man | unit |  | Vanguard trait: prestige / challenge card (kc-syn S1) |
| 12 | Close Quarters | Point Man | unit |  | Vanguard trait: prestige / challenge card (kc-syn S1) |
| 13 | Snow Speed | Point Man | unit |  | Vanguard trait: operator rushing in on a snowmobile (kc-pitch-art: was Dual SMGs) |
| 14 | Nades And Guns | Point Man | unit |  | Vanguard trait: prestige / challenge card (kc-syn S1) |
| 15 | Bang! | Point Man | unit |  | operator with an SMG or pistol, close in |
| 16 | Standoff | Point Man | unit |  | Vanguard trait: prestige / challenge card (kc-syn S1) |
| 17 | Urban Tech | Flanker | unit | yes | Spec Ops trait: operator-bundle card (kc-syn S1) |
| 18 | Operation Azure | Flanker | unit |  | stealthy operator moving or infiltrating |
| 19 | Can't Catch Me | Flanker | unit | yes | stealthy operator moving or infiltrating |
| 20 | Operator Infil | Flanker | unit | yes | stealthy operator moving or infiltrating |
| 21 | Gift Giver | Flanker | unit |  | Spec Ops trait: operator-bundle card (kc-syn S1) |
| 22 | Unleashing Chaos | Gunner | unit |  | Heavy look: gunner firing a belt-fed gun (kc-pitch-art) |
| 23 | Heavy Barrage | Gunner | unit |  | Heavy look: gunner over an ammo crate (kc-pitch-art) |
| 24 | Suppression | Gunner | unit |  | Heavy look: suppressing fire (kc-pitch-art) |
| 25 | Blaze Of Glory | Gunner | unit |  | Heavy look: gunner firing from the hip (kc-pitch-art) |
| 26 | Lawn Mowing | Gunner | unit |  | Heavy look: gunner sweeping a rooftop (kc-pitch-art) |
| 27 | Battle Highlights | Marksman | unit |  | Spec Ops trait: operator-bundle card (kc-syn S1) |
| 28 | Stained Memory | Marksman | unit |  | Spec Ops trait: operator-bundle card (kc-syn S1) |
| 29 | Trophy Collector | Marksman | unit |  | Spec Ops trait: operator-bundle card (kc-syn S1) |
| 30 | Winter's Silence | Marksman | unit |  | Spec Ops trait: operator-bundle card (kc-syn S1) |
| 31 | Snow Snipers | Marksman | unit |  | sniper rifle / scope |
| 32 | Art Of Disguise | Marksman | unit | yes | sniper rifle / scope |
| 33 | Big Game Hunter | Ace | unit |  | lone sniper hunting (Ace, sniper elite) |
| 34 | Keeping These | Protector | unit | yes | riot shield / armoured defender (Protector) |
| 35 | Shields Above All | Protector | unit |  | riot shield / armoured defender (Protector) |
| 36 | Resolved Eyes | Protector | unit |  | Vanguard trait: prestige / challenge card (kc-syn S1) |
| 37 | Broken Walls | Breacher | unit | yes | shotgun at close quarters / room entry |
| 38 | Lethal Patience | Breacher | unit |  | Vanguard trait: prestige / challenge card (kc-syn S1) |
| 39 | Behind The Door | Breacher | unit |  | shotgun at close quarters / room entry |
| 40 | Fast Acting | Breacher | unit |  | Vanguard trait: prestige / challenge card (kc-syn S1) |
| 41 | Did I Hit It!? | Demolitions Expert | unit |  | Heavy look: launcher shot downing an aircraft (kc-pitch-art) |
| 42 | Armor Crusher | Demolitions Expert | unit |  | Heavy look: detonator, tank exploding (kc-pitch-art) |
| 43 | Out With A Bang | Demolitions Expert | unit |  | Heavy look: demolitions charge (kc-pitch-art) |
| 44 | Escape Artist | Demolitions Expert | unit |  | Heavy look: running from an explosion (kc-pitch-art) |
| 45 | Dark Patrol | Recon Specialist | unit |  | Spec Ops trait: operator-bundle card (kc-syn S1) |
| 46 | Infiltration | Recon Specialist | unit |  | night vision, optics, scouting |
| 47 | Don't Look Back | Recon Specialist | unit |  | Spec Ops trait: operator-bundle card (kc-syn S1) |
| 48 | Power And Poise | Recon Specialist | unit |  | Spec Ops trait: operator-bundle card (kc-syn S1) |
| 49 | Start Packing! | Combat Medic | unit |  | Undead trait: Zombies card (kc-syn S1) |
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
| 85 | FWOOM! | Brawler | unit |  | Undead trait: Zombies card (kc-syn S1) |
| 86 | Power And Pain | Brawler | unit |  | Undead trait: Zombies card (kc-syn S1) |
| 87 | Blade Is Mightier | Brawler | unit |  | Undead trait: Zombies card (kc-syn S1) |
| 88 | Ride And Die | Brawler | unit |  | Undead trait: Zombies card (kc-syn S1) |
| 89 | Knuckle Bros | Brawler | unit |  | melee: blade, fists, bat |
| 90 | Raging | Brawler | unit |  | melee: blade, fists, bat |
| 91 | Baseball Fan | Brawler | unit |  | melee: blade, fists, bat |
| 92 | Close Your Eyes | Blackout | tactic |  | flashbang / blinding / hacked screens |
| 93 | Zapped | Blackout | tactic |  | electrocuted, blinded skeletons |
| 94 | Tales Of The Night | Smoke Screen | tactic | yes | night cover |
| 95 | Detonated | Sabotage | tactic |  | detonator in hand: blowing up enemy gear |
| 96 | Fireworks Show | Sabotage | tactic |  | planted charge with a timer |
| 97 | Helo Exfil | Rifleman | unit |  | alternate: Undead (Horde family) |
| 98 | In Trouble | Rifleman | unit |  | alternate: Undead (Horde family) |
| 99 | Solid Tactics | Rifleman | unit |  | alternate: Spec Ops (Operators family, Warzone) |
| 100 | Swamp Guys | Rifleman | unit |  | alternate: Spec Ops (Operators family, Warzone) |
| 101 | Violent Vortex | Point Man | unit |  | alternate: Undead (Horde family) |
| 102 | Wolves Wasted | Point Man | unit |  | alternate: Undead (Horde family) |
| 103 | Clearer Vision | Breacher | unit |  | alternate: Heavy look (shotgun at close range) |
| 104 | CQC (Close Quarters Combat) | Breacher | unit |  | alternate: Heavy look (entry team) |
| 105 | Surrounded | Protector | unit |  | alternate: Undead (Horde family) |
| 106 | Seal Time | Recon Specialist | unit |  | alternate: Undead (Horde family) |
| 107 | Long Distance Laser | Marksman | unit |  | alternate: Heavy look (sniper with a laser sight) |
| 108 | Message Inbound | Marksman | unit |  | alternate: Heavy look (big-bore sniper) |
| 109 | Lead Rain | Gunner | unit | yes | alternate: Spec Ops (operator with an LMG) |
| 110 | Download Complete | Gunner | unit |  | alternate: Spec Ops (operator-bundle robot) |
| 111 | Objective Destroyed | Demolitions Expert | unit |  | alternate: Undead (Horde family) |
| 112 | Boom And Gloom | Demolitions Expert | unit |  | alternate: Undead (Horde family) |
| 113 | Big Sword | Brawler | unit |  | alternate: Spec Ops (operator-bundle melee) |

### 2.1 Operator mastery ladder
The Operator wears the weapon-mastery card of its primary weapon. Tier 1 (Gilded) is the **Base** camo for both sides (head, B3); higher tiers are a dev preview only.
| Operator weapon | Tier 1 (Base) | Tier 2 | Tier 3 | Tier 4 |
|---|---|---|---|---|
| Operator: Kestrel AR-7 (MCW) | MCW Mastery: Gilded | MCW Mastery: Forged | MCW Mastery: Priceless | MCW Mastery: Interstellar |
| Operator: Longreach .338 (KATT-AMR) | KATT-AMR Mastery: Gilded | KATT-AMR Mastery: Forged | KATT-AMR Mastery: Priceless | KATT-AMR Mastery: Interstellar |
| Operator: Wasp-9 (WSP-9) | WSP-9 Mastery: Gilded | WSP-9 Mastery: Forged | WSP-9 Mastery: Priceless | WSP-9 Mastery: Interstellar |
| Operator: P-12 sidearm (COR-45) | COR-45 Mastery: Gilded | COR-45 Mastery: Forged | COR-45 Mastery: Priceless | COR-45 Mastery: Interstellar |

Camo band per tier: Base (olive), Forged (silver-white), Priceless (blue), Interstellar (purple). Dev toggle: `?mastery=N` (1-4) in the URL, or **Ctrl+M** on the match screen cycles the tier.

### 2.2 Starters and the Wip set (kc-mw3-cards, head)
24 more arts (153 in all; 6.4 MB of WebP after the size pass in §4). All are new to the set: **no calling card is reused**. Picked by eye on a contact sheet (kept outside the repo).

**Standard Issue starters** wear one calling card each, **private pitch build only** (the public build keeps the original Standard Issue art). `BannerArtDB.get_art` looks up a licensed row for an `si_*` art id before the public drop-in (`data/banners/si_*.tres`); the starter Ammo Resupply copy wears `si_ammo_resupply` (the collectible Ammo Resupply keeps its three crates). The card still counts as Standard Issue (serial, no trait).
| Card (art id) | Calling card | Why |
|---|---|---|
| Grunt (`si_grunt`) | Anything That Moves | rank-and-file riflemen advancing |
| Trooper (`si_trooper`) | Helo Support | seasoned trooper, rifle up, in the dust |
| Sergeant (`si_sergeant`) | Landing Party | squad leader bringing a fire team off the helo |
| Armored Trooper (`si_armored`) | Grid And Grit | helmeted, plated soldier |
| Ammo Resupply, starter copy (`si_ammo_resupply`) | Hand-Off | an ammo box handed over |

**Wip set** (`documentation/design/wip-set.json`, not in `data/cards/` yet). Rows use the **proposed card ids** (`kc_wip_` + snake_case name, Roman numerals as digits). They do nothing until a card with that id exists; then it wears the art with no code change (its licensed pool, `ArtTraits.arts_for`). If the final id differs, change the `card` cell in `mw3-pitch-set.csv` and rebuild.
| Card | Proposed id | Calling card | Why |
|---|---|---|---|
| Private I | `kc_wip_private_1` | Anything That Moves | the pitch starter's earlier art (head, kc-pitch-art); shared with the tutorial's Grunt |
| Private II | `kc_wip_private_2` | Helo Support | earlier starter art (tutorial Trooper) |
| Private III | `kc_wip_private_3` | Landing Party | earlier starter art (tutorial Sergeant) |
| Private IV | `kc_wip_private_4` | Grid And Grit | earlier starter art (tutorial Armored Trooper) |
| Scout | `kc_wip_scout` | Low Profile | ghillie scout lying low |
| Medic | `kc_wip_medic` | Useful | stim / heal, like the Combat Medic's drinks |
| Sharpshooter | `kc_wip_sharpshooter` | Glint | masked sniper aiming (kc-pitch-art: was a scope close-up) |
| Flag Bearer | `kc_wip_flag_bearer` | So It Begins | a war banner over the fire |
| Hacker | `kc_wip_hacker` | Pet Drones | operator steering a drone swarm |
| Kamikaze | `kc_wip_kamikaze` | Pin Pulled | pin pulled, blast behind |
| Runner | `kc_wip_runner` | Damn Fast | speed-blur sprint |
| Sniper | `kc_wip_sniper` | Ghillie Guy | ghillie sniper with a bolt rifle |
| Juggernaut | `kc_wip_juggernaut` | Last Man Standing | armoured juggernaut in a burning ruin (kc-pitch-art: was All The Guns, a gun showcase) |
| Riot Shield | `kc_wip_riot_shield` | Move As One | a riot-shield squad advancing (kc-pitch-art: was the Riot Shield weapon-mastery card) |
| Fast Learner | `kc_wip_fast_learner` | Trained And Ready | training dummies on the range |
| Laser Gunner | `kc_wip_laser_gunner` | Laser Grid | operator in a laser grid (kc-pitch-art: was a rifle close-up) |
| War Shout | `kc_wip_war_shout` | Revolution Rising | a crowd raising arms before the charge |
| Barrage | `kc_wip_barrage` | Warships | ship guns firing a broadside |
| Premium Loadout | `kc_wip_premium_loadout` | Gearing Up | picking kit off the armory wall |

- kc-pitch-art (head): the Privates wear the pitch starter's earlier arts again (Anything That Moves, Helo Support, Landing Party, Grid And Grit), the same images as the tutorial's si_* starters (separate ids `kc_mw3_*_private`, one source file each). The card shows the calling card title as its name, as every licensed card does ("Anything That Moves", type line "Private I").
- Rejected on sight: Combat Surgeon (blood spatter), Gun Go Brrrrrt (blood), Squad Up / Beach Breacher (event logo), the Ranked Play rank cards (MW3 logo), Snow Speed (no shield, a snowmobile).

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
- **Size (kc-mw3-cards):** the artifact upload limit is 15 MiB (15,728,640 bytes) per file; keep the pitch `game.pck` at or under 14.5 MB. Measured with `--export-pack "Web (private pitch)"`: 16,444,672 bytes with the 24 new arts at the old settings, **13,874,640 bytes** now. The builder's defaults do this: frame sheets WebP q70 (was q80), stills q78 (was q85), sizes unchanged (stills 512x128, frame cells 384x96, at most 16 frames), and it deletes WebP files in the output folder that no manifest row names (34 stale picks, 0.87 MB, were shipping because the preset includes the whole folder; `--keep-stale` keeps them). The arts use the "keep" importer, so there are no mipmaps to turn off. The set is 6.4 MB of WebP for 153 arts.
- The default "Web" preset still excludes `assets/licensed/*`, and the default package run does not even copy that folder into its build tree. The script refuses a pitch output folder inside the repo unless git ignores it; `.gitignore` covers `projects/*/builds/pitch/` and any `web-pitch/` folder.
- Tests never use the licensed folder (`run_tests.gd` switches it off); they pass with the folder present or absent.

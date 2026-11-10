# KillingCard: DA art pack 1 (ChatGPT image prompts)

*Sr Game Artist · 2026-11-10 · Board task kc-da-art · Godot 4.4.1 web, phone landscape first*
*Covers updates #1, #2 and #11 of `art-direction.md` §12, after the head approved DA v1 with (a) on A1-A4: one painted "Theatre at dusk" house style for base cards, clean tactical UI, a medium collectible lean, killstreaks coloured by owner.*
*Companions: `da-art-pack-1-checklist.md` (tick list), `da-art-pack-1-manifest.csv` (the importer's manifest for these slots). Above this doc: `art-direction.md` (wins on style). Pipeline: `banner-art-direction.md` §3, `ui-kit-prompt-pack.md` §7, `ui-kit-import-log.md`.*

---

## 0. At a glance

**48 images in 6 batches**, one batch per ChatGPT session, in priority order.

| Update | Images | What |
|---|---|---|
| #1 | 31 | Every public card or Operator whose art is a generated gradient, or a copy of another card's painting |
| #2 | 7 | Tactics (and one Field) whose subject is a soldier, re-arted as objects, places or events; Ammo Resupply first |
| #11 | 10 | Second theatre, **Night city**, for the 10 most-used units (12 Night city images in all, with 2 Tactics from #2) |

| Batch | Images | What | Slots |
|---|---|---|---|
| 1 | 8 | The starter and the first look: Ammo Resupply, the Private ladder, the locked Operator, Brawler | `ammo_resupply`, `si_ammo_resupply`, `kc_wip_private_1`, `kc_wip_private_2`, `kc_wip_private_3`, `kc_wip_private_4`, `bastion_60`, `brawler` |
| 2 | 10 | The remaining flat placeholders: 3 Tactics, 6 Fields and the boss token | `blackout`, `smoke_screen`, `sabotage`, `aid_station`, `listening_post`, `war_standard`, `bulwark`, `mortar_pit`, `sniper_perch`, `shambler` |
| 3 | 8 | Tactics without soldiers (#2) and the 3 new Tactics | `callout`, `breach_and_clear`, `hold_the_line`, `suppressing_fire`, `tripwire_charge`, `kc_wip_barrage`, `kc_wip_war_shout`, `kc_wip_premium_loadout` |
| 4 | 8 | New units (Wip set), part 1 | `kc_wip_scout`, `kc_wip_medic`, `kc_wip_sharpshooter`, `kc_wip_flag_bearer`, `kc_wip_hacker`, `kc_wip_runner`, `kc_wip_sniper`, `kc_wip_riot_shield` |
| 5 | 8 | New units part 2, then Night city on the most-used units | `kc_wip_juggernaut`, `kc_wip_kamikaze`, `kc_wip_fast_learner`, `kc_wip_laser_gunner`, `shieldman`, `combat_medic`, `rifleman`, `demolitions_expert` |
| 6 | 6 | Night city, the rest of the most-used units | `point_man`, `marksman`, `gunner`, `flanker`, `breacher`, `recon_specialist` |

**Top batch: Batch 1** (8 images): Ammo Resupply (house painting), Ammo Resupply (Standard Issue), Private I-IV, Bastion-60 and Brawler. It fixes everything a new player sees in the first match and the purple locked-Operator tile.

### How to run a batch (the same flow as the banner and UI kit packs)

1. **One image per chat.** Open a fresh ChatGPT chat, paste the grey prompt box as it is, send. If it asks a question: "just generate it".
2. **Landscape 3:2.** If it comes back another shape: "Same image, landscape 3:2, 1536x1024."
3. **Check it** against the 6 checks in the checklist (or §6 here). Fix in the same chat: "Regenerate, avoid: " + the entry's Avoid line. Two tries, then skip it and say so.
4. **Don't crop.** Upload the full 1536x1024 image; the Technical Artist crops with the numbers given here.
5. **Name the file** exactly as the entry's heading (`kc_b_<slot>.png`; a retry is `kc_b_<slot>_v2.png`, the highest `_vN` wins).
6. **Upload** the batch to the Studio Floor chat with its upload line. Raw files never go into git.

---

## 1. Audit: which public art is placeholder or off-style (update #1)

Checked against the files, not the screenshots: `data/cards/` (55 cards), `data/banners/` (9 drop-ins), `data/loadout/` (Operators and killstreaks), `assets/sprites/cards/` (the 29 Killstreak paintings + 4 run-map arts) and the art lookup (`scripts/ui/art/banner_art_db.gd`: data/banners drop-in, then the Killstreak painting `card_<id>.webp`, then a **generated gradient with a class silhouette**, its hue hashed from the id).

### 1.1 Generated gradient (no art at all) → new painting

| Card / Operator | Id | Kind | Where it shows | Batch |
|---|---|---|---|---|
| Bastion-60 | `bastion_60` | Operator (LMG, locked until the first win) | Loadout and Duel hub hero tile: **the purple placeholder** (the same item as "the locked Operator") | 1 |
| Brawler | `brawler` | Unit | Codex, Hollow Ranks preset, Hollow Choir squad | 1 |
| Blackout | `blackout` | Tactic | run pool, Codex | 2 |
| Smoke Screen | `smoke_screen` | Tactic | run pool, Codex | 2 |
| Sabotage | `sabotage` | Tactic | run pool, Codex (*found*, not in the DA list) | 2 |
| Aid Station | `aid_station` | Field | Hollow Choir squad, run pool | 2 |
| Listening Post | `listening_post` | Field | Hollow Ranks preset, run pool | 2 |
| War Standard | `war_standard` | Field | Hollow Ranks, Hollow Choir | 2 |
| Bulwark | `bulwark` | Field | run pool (*found*) | 2 |
| Mortar Pit | `mortar_pit` | Field | run pool (*found*) | 2 |
| Sniper Perch | `sniper_perch` | Field | run pool (*found*) | 2 |
| Shambler | `shambler` | Unit token (boss summon) | on the board in the Hollow Choir boss fight (*found*) | 2 |
| Barrage, War Shout, Premium Loadout | `kc_wip_barrage`, `kc_wip_war_shout`, `kc_wip_premium_loadout` | Tactics (Wip set) | reward pool | 3 |
| Scout, Medic, Sharpshooter, Flag Bearer, Hacker, Runner, Sniper, Riot Shield | `kc_wip_*` | Units (Wip set) | reward pool, Duel Basic pool | 4 |
| Juggernaut, Kamikaze, Fast Learner, Laser Gunner | `kc_wip_*` | Units (Wip set) | reward pool, Duel Basic pool | 5 |

### 1.2 A copy of another card's painting (placeholder: true) → new painting

| Card | Id | Wears today | Batch |
|---|---|---|---|
| Private I / II / III / IV | `kc_wip_private_1..4` | Rifleman / Point Man / Breacher / Protector paintings. These are **the starter deck** (x3, x3, x2, x1), so the four most-used units appear twice on the board: the audit's "the same few paintings repeat". | 1 |
| Ammo Resupply (Standard Issue) | `si_ammo_resupply` | The Ammo Resupply painting (a soldier). The starter's copy wears this id. | 1 |

That is all 19 `kc_wip_*` cards (15 generated + the 4 Privates).

### 1.3 Placeholders that need no new image (Technical Artist, data only)

| Id | Today | Fix (no image) |
|---|---|---|
| `kestrel_ar7_crew`, `wasp_9_crew` | The **rival** crews' Operators (Bulwark_Nine, Meridian_Six, TrainingBot_01 ...): no drop-in and no `card_<id>.webp`, so every enemy Operator banner is a generated gradient (*found*). | A `data/banners/<id>.tres` each, `image_path` = `card_kestrel_ar7.webp` / `card_wasp_9.webp`, the crops from `PLACEHOLDER_CROPS`. A rival-only painting can come in a later pack. |
| `si_grunt`, `si_trooper`, `si_sergeant`, `si_armored` | The old Standard Issue line (tutorial squad only now), wearing Rifleman / Point Man / Breacher / Protector copies. | Point each `.tres` at the matching new Private painting (I, II, III, IV) once batch 1 ships. Their own plain prompts stay in `ui-kit-prompt-pack.md` batch 3 if the head ever wants them. |

### 1.4 Checked and fine (house style, Port dusk)

Units: Rifleman, Protector, Combat Medic, Demolitions Expert, Point Man, Marksman, Gunner, Flanker, Breacher, Recon Specialist, Ace (`halek_wren`), Commander (`okafor_anvil`), Sentry. Operators: Kestrel AR-7, Wasp-9, Longreach .338. Killstreaks: Attack Helo, Gunship, Mortar Barrage, Recon Drone, Sentry Turret (killstreaks may show a crew: the "no soldier" rule is for Tactics). Fields: Comms Relay (the dish is the subject; the two soldiers are small). Tactic: Flank Route (a place).

**Not in this pack:** the trait alt arts (`<card>~honors|operators|mastery|horde`, today a tinted copy of the base painting). Under A1 they become the earned graphic-style arts (`banner-art-direction.md` §1.2 families); that is its own pack.

---

## 2. Tactics with a soldier as the subject (update #2)

Checked each Killstreak painting by eye (contact sheet, not committed):

| Card | Kind | Today | New subject | Batch |
|---|---|---|---|---|
| **Ammo Resupply** (first) | Tactic | A soldier loading magazines | Open crates and magazines under a supply chute | 1 |
| Ammo Resupply (Standard Issue) | Tactic | The same soldier | One plain open box on a pallet | 1 |
| Callout | Tactic | A soldier pointing | A flare over a street, binoculars and radio on a parapet (Night city) | 3 |
| Breach and Clear | Tactic | Three soldiers at a blown door | The door blowing off its frame (Night city) | 3 |
| Hold the Line | Tactic | Three soldiers behind sandbags | The empty sandbag wall under a floodlight | 3 |
| Suppressing Fire | Tactic | Soldiers firing | Tracers raking a container aisle, impacts on a barrier | 3 |
| Tripwire Charge | Field (trap) | A crouching soldier | The wire and the charge, low camera | 3 |

Flank Route is already a place. The three new Tactics (Barrage, War Shout, Premium Loadout) are written as events and objects from the start.

---

## 3. The second theatre: Night city (update #11)

**Pick: Night city** (sodium street light over a deep violet sky; wet asphalt, rooftops, fire escapes, dark tower blocks). Arctic dawn is queued for a later pack.

Why Night city over Arctic dawn:

1. **It keeps the signal colours clean.** Arctic dawn's ice cyan sits right next to the player's teal `#2EC4B6`, and its rose light drifts toward rival red. Violet is the one hue no signal uses (teal you, red rival, amber act now, brass Operator, green / red numbers).
2. **It keeps the icon columns readable.** Snow and dawn sky make bright, white side columns behind white icons and numbers. Night city is dark at the edges by nature, like Port dusk, so the 15% icon columns stay calm.
3. **It keeps the house light logic.** One warm key (sodium) against a cool sky, the same rule as Port dusk, so the two theatres sit side by side as one set; the difference is the **sky hue** (violet vs slate blue) and the **silhouettes** (towers, rooftops, viaducts vs cranes and containers), which read even at 160x40.
4. **It suits the cards.** Breaching, rooftop snipers, alley shields and stairwell medics are natural in a city; most most-used units are close-quarters roles.

Guard rails written into every Night city prompt: **no neon signs, no shop signs, no billboards** (fake letters), **no red or pink light** (red is the rival), and windows stay unlit (no figures).

**Which cards:** the 10 units in the most decks (5 enemy squads, the run pool and the Duel presets): Protector and Combat Medic (5 each), Rifleman and Demolitions Expert (4), Point Man, Marksman, Gunner, Flanker, Breacher (3), Recon Specialist (2 + pool). Plus Callout and Breach and Clear from #2. After the pack, the board mixes about 12 Night city cards with the Port ones; no column is all one sky.

**How it ships:** the Night city painting becomes the card's **default** art (`data/banners/<card>.tres`, `is_default = true`), overriding the Port painting with no code change. The Port painting file stays in `assets/sprites/cards/` as the fallback (and could become an alt art later). If the head would rather keep Port as the default, the TA can ship these under another id instead; say so when uploading.

---

## 4. Pipeline and crop rules (read once)

### 4.1 Names and slots, as the importer expects them

- **Raw file (the head's upload):** `kc_b_<slot>.png` at 1536x1024 (Night city replacements: `kc_b_<card>_nightcity.png`). Retries `_v2`, `_v3`.
- **Slot id** = the art id the game looks up = the card id (`ammo_resupply`, `kc_wip_scout`, `bastion_60` ...). Exception: `kc_b_si_ammo_resupply` is the existing UI-kit slot (`ui-kit-manifest.csv` row `si_ammo_resupply`, already wired through `UiKit.piece`).
- **Ship:** `tools/ui_kit_icons.py --manifest documentation/art/da-art-pack-1-manifest.csv <raw_dir> source/project-killingcard [--dry-run]` writes each as a 1152x768 opaque master to `assets/sprites/banners/` (rows are `card_art`, `transparent = no`). Then one `data/banners/<slot>.tres` per image (§7). `BannerArtDB` reads `data/banners/<art_id>.tres` before the placeholder, so nothing in code changes.

### 4.2 The crop: one 3:2 image, two windows

```
 full image 1536x1024 (3:2)
 +-----------+--------------------------------------+-----------+
 |           |        simple sky / wall             |           |   top ~28%: background only
 |===========|======================================|===========|
 | icon col  |  FOCAL: head + weapon / the object   | icon col  |   4:1 band 1536x384 at banner_y
 | x 0-230   |        x 230-1306 (middle 70%)       | x 1306+   |
 |===========|======================================|===========|
 |           |        body / simple ground          |           |   bottom ~34%: background only
 +-----------+--------------------------------------+-----------+
                 2:3 hand column 683x1024 at portrait_x
```

- **4:1 banner band** (board, inspector, hand-card art window): full width x 384 px, centred at `banner_y` (0.47 = y 289-673). Every entry gives its `banner_y` and the band in pixels.
- **Middle 70%** (x 230-1306): everything that identifies the card: face covering, hands, weapon action, the object's brightest detail.
- **Icon columns** (outer 15% each side): calm, darker, low detail; a barrel or smoke may pass through but nothing ends there. The cost hex and abilities chip sit in the top corners of the band, the traits, FP reticle and Armor plate in the bottom corners.
- **Hand column / square:** centred at `portrait_x` (0.50 unless noted).
- ChatGPT follows percentages loosely: the curator moves `banner_y` (0.35-0.60 is fine) rather than regenerating.

### 4.3 The template, as filled in

Every prompt is the DA template (`art-direction.md` §10) with the brackets filled. Two fixed variants, so the house style holds on non-soldier cards:

- **Tactics and Fields (objects, places, events):** the Gear line becomes "no people in the image (no soldier, no hands) ...", and the Composition line puts "the main object and its brightest detail" where the template says "head and weapon".
- **Operator weapon (Bastion-60):** the same as its three siblings: one fictional weapon on a bench, no people.
- **Standard Issue (the Privates and the starter's Ammo Resupply):** one added line, "Mood: plain and modest ...", so the starter reads as basic kit and the first earned art pops (onboarding §2.2). Same house painting, quieter light.

---

## 5. The prompts

### Batch 1 · 8 images · The starter and the first look: Ammo Resupply, the Private ladder, the locked Operator, Brawler

*Why now:* Every new player sees these in the first minute: the starter deck is Private I x3, II x3, III x2, IV x1 and one Ammo Resupply, all four Privates wear copies of other cards' paintings, and the locked Operator is the purple gradient on the Loadout and Duel hub. Ammo Resupply comes first, as asked.

Upload line: `kc-da-art batch 1: kc_b_ammo_resupply.png, kc_b_si_ammo_resupply.png, kc_b_kc_wip_private_1.png, kc_b_kc_wip_private_2.png, kc_b_kc_wip_private_3.png, kc_b_kc_wip_private_4.png, kc_b_bastion_60.png, kc_b_brawler.png`

#### 1. `kc_b_ammo_resupply.png` · slot `ammo_resupply` · Ammo Resupply

- [ ] **Card:** Ammo Resupply (`ammo_resupply`) · Tactic · update #2 · theatre **Port dusk**
- **Shows today:** Killstreak painting `card_ammo_resupply.webp`: a soldier loading magazines (a soldier as a Tactic's subject).
- **Ships as:** `assets/sprites/banners/kc_b_ammo_resupply.png` (1152x768 master); new `data/banners/ammo_resupply.tres` (`BannerArt`: `id` and `card_id` = `ammo_resupply`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.48**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 300-684 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The open crate and the magazines sit in the band, centred, between x 35% and 65%. The parachute stays above the band (it is background).

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: two open olive ammunition crates and a canvas bag of fictional rifle magazines on a wooden pallet, a slack supply parachute draped over a container behind, just dropped and opened: one lid propped up, warm lamp light spilling over neat rows of magazines,
seen three-quarter from slightly above, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a person, a hand or a face; letters, numbers or stencils on crates; a red cross.

#### 2. `kc_b_si_ammo_resupply.png` · slot `si_ammo_resupply` · Ammo Resupply (Standard Issue, the starter's copy)

- [ ] **Card:** Ammo Resupply (Standard Issue, the starter's copy) (`ammo_resupply`) · Tactic · update #2 · theatre **Port dusk** · Standard Issue (plain)
- **Shows today:** `data/banners/si_ammo_resupply.tres` (placeholder: true) points at the same soldier painting.
- **Ships as:** `assets/sprites/banners/kc_b_si_ammo_resupply.png` (1152x768 master); ships as the kit piece `kc_b_si_ammo_resupply` in `assets/sprites/banners/`; `BannerArtDB._apply_si_art` puts it on the existing `data/banners/si_ammo_resupply.tres` with no code change. Update that file's `banner_y` / `portrait_x` and `source_note`.
- **Crop:** `banner_y` **0.48**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 300-684 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The open box fills the middle third of the band. Plainer and calmer than the Ammo Resupply painting, so the earned art pops.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one plain olive ammunition box with its lid open on a wooden pallet, a few fictional magazines inside, in a quiet container aisle, waiting to be picked up, a single work lamp above it,
seen three-quarter side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Mood: plain and modest, a quiet moment; no muzzle flash, no explosion, a softer rim light.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a person or a hand; letters or stencils on the box; more than one box; dramatic explosions.

#### 3. `kc_b_kc_wip_private_1.png` · slot `kc_wip_private_1` · Private I

- [ ] **Card:** Private I (`kc_wip_private_1`) · Unit (Standard Issue starter, x3) · update #1 · theatre **Port dusk** · Standard Issue (plain)
- **Shows today:** `data/banners/kc_wip_private_1.tres` (placeholder: true) reuses the Rifleman painting.
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_private_1.png` (1152x768 master); replace the existing `data/banners/kc_wip_private_1.tres`: `image_path` = the new file, `placeholder = false`, new crop, new `source_note`.
- **Crop:** `banner_y` **0.45**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 269-653 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Helmet and rifle in the band; the rifle runs left to right across the middle 70%. The four Privates must read as one family that grows heavier: I light, II vest, III carbine and radio, IV plate.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one young recruit in light olive fatigues, a plain helmet and a simple chest rig, walking forward through a container aisle with a short fictional rifle held low at the ready,
seen three-quarter side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Mood: plain and modest, a quiet moment; no muzzle flash, no explosion, a softer rim light.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; lightest kit of the four Privates: no plate armour, no backpack.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): muzzle flash, explosions, a second figure, a visible face.

#### 4. `kc_b_kc_wip_private_2.png` · slot `kc_wip_private_2` · Private II

- [ ] **Card:** Private II (`kc_wip_private_2`) · Unit (Standard Issue starter, x3) · update #1 · theatre **Port dusk** · Standard Issue (plain)
- **Shows today:** `data/banners/kc_wip_private_2.tres` (placeholder: true) reuses the Point Man painting.
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_private_2.png` (1152x768 master); replace the existing `data/banners/kc_wip_private_2.tres`: `image_path` = the new file, `placeholder = false`, new crop, new `source_note`.
- **Crop:** `banner_y` **0.45**, `portrait_x` **0.48**. On the 1536x1024 original the 4:1 band is y 269-653 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Head, hands and rifle in the band above the barrier line; the barrier top sits at about 62% of the height.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one soldier in a padded olive vest and plain helmet, kneeling behind a low concrete barrier with a fictional rifle raised, watching to the right,
seen side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Mood: plain and modest, a quiet moment; no muzzle flash, no explosion, a softer rim light.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; a padded vest and knee pads, still simple kit.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): muzzle flash, a second figure, a visible face, markings on the vest.

#### 5. `kc_b_kc_wip_private_3.png` · slot `kc_wip_private_3` · Private III

- [ ] **Card:** Private III (`kc_wip_private_3`) · Unit (Standard Issue starter, x2) · update #1 · theatre **Port dusk** · Standard Issue (plain)
- **Shows today:** `data/banners/kc_wip_private_3.tres` (placeholder: true) reuses the Breacher painting.
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_private_3.png` (1152x768 master); replace the existing `data/banners/kc_wip_private_3.tres`: `image_path` = the new file, `placeholder = false`, new crop, new `source_note`.
- **Crop:** `banner_y` **0.45**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 269-653 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Helmet, goggles and the carbine's front half in the band, between x 25% and 75%.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one experienced soldier with a fictional carbine shouldered and a small radio antenna on a compact pack, advancing along a quay edge, carbine aimed forward to the right,
seen three-quarter side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Mood: plain and modest, a quiet moment; no muzzle flash, no explosion, a softer rim light.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; a light plate carrier and a short radio antenna.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): muzzle flash, a second figure, a visible face, a long whip antenna that ends in the top corner.

#### 6. `kc_b_kc_wip_private_4.png` · slot `kc_wip_private_4` · Private IV

- [ ] **Card:** Private IV (`kc_wip_private_4`) · Unit (Standard Issue starter, x1) · update #1 · theatre **Port dusk** · Standard Issue (plain)
- **Shows today:** `data/banners/kc_wip_private_4.tres` (placeholder: true) reuses the Protector painting.
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_private_4.png` (1152x768 master); replace the existing `data/banners/kc_wip_private_4.tres`: `image_path` = the new file, `placeholder = false`, new crop, new `source_note`.
- **Crop:** `banner_y` **0.45**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 269-653 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Visor and rifle in the band; a broad, square silhouette that fills the middle third.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one heavily kitted soldier in full plate armour, shoulder guards and a full-face visor, standing guard under a floodlight, a heavier fictional rifle held across the chest,
seen three-quarter front, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Mood: plain and modest, a quiet moment; no muzzle flash, no explosion, a softer rim light.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; the heaviest of the four Privates: plate armour, shoulder guards.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): muzzle flash, a riot shield (that is the Protector), a second figure, markings.

#### 7. `kc_b_bastion_60.png` · slot `bastion_60` · Bastion-60 (the locked LMG Operator)

- [ ] **Card:** Bastion-60 (the locked LMG Operator) (`bastion_60`) · Operator · update #1 · theatre **Port dusk**
- **Shows today:** No art at all: `BannerArtDB` generates a gradient + silhouette (the purple placeholder on the locked Operator tile in the Loadout and Duel hub).
- **Ships as:** `assets/sprites/banners/kc_b_bastion_60.png` (1152x768 master); new `data/banners/bastion_60.tres` (`BannerArt`: `id` and `card_id` = `bastion_60`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.50**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 320-704 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Match the three existing Operator paintings (Kestrel AR-7, Wasp-9, Longreach .338: one weapon on a bench at the dock). The whole weapon runs horizontally between x 15% and 85%, receiver at the centre.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: a fictional light machine gun with a box magazine, a long ribbed barrel, a folding stock and its bipod down, resting on a steel workbench, a short ammunition belt coiled beside it, a sandbag and a canvas cover behind,
seen side, the weapon horizontal, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: no people in the image; the weapon is a fictional design with no markings, maker marks or serial numbers.
Composition: the whole weapon between 30% and 65% of the image height, running horizontally across the middle 70%
of the width; left and right 15% calm, darker and simple; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a recognisable real machine gun model, maker marks, serial numbers, a person.

#### 8. `kc_b_brawler.png` · slot `brawler` · Brawler

- [ ] **Card:** Brawler (`brawler`) · Unit (Undead home trait) · update #1 · theatre **Port dusk**
- **Shows today:** No painting: generated gradient + shotgun silhouette (the flat art in the Codex and the Hollow Ranks / Hollow Choir decks).
- **Ships as:** `assets/sprites/banners/kc_b_brawler.png` (1152x768 master); new `data/banners/brawler.tres` (`BannerArt`: `id` and `card_id` = `brawler`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.46**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 279-663 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Gas mask and shotgun in the band; the steam stays behind, not in front of the face.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one broad-shouldered close-quarters fighter in a torn olive jacket and an old gas mask, charging forward through steam between two containers with a short fictional pump shotgun held low,
seen three-quarter front, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; heavy gloves, a battered helmet.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): gore, zombie wounds, skulls, a visible face.

### Batch 2 · 10 images · The remaining flat placeholders: 3 Tactics, 6 Fields and the boss token

*Why now:* The flat gradients the DA audit flagged in the Duel hub and the Codex ("Doesn't fit"). These cards are in the run pool and in three of the five enemy squads.

Upload line: `kc-da-art batch 2: kc_b_blackout.png, kc_b_smoke_screen.png, kc_b_sabotage.png, kc_b_aid_station.png, kc_b_listening_post.png, kc_b_war_standard.png, kc_b_bulwark.png, kc_b_mortar_pit.png, kc_b_sniper_perch.png, kc_b_shambler.png`

#### 9. `kc_b_blackout.png` · slot `blackout` · Blackout

- [ ] **Card:** Blackout (`blackout`) · Tactic · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + shield silhouette.
- **Ships as:** `assets/sprites/banners/kc_b_blackout.png` (1152x768 master); new `data/banners/blackout.tres` (`BannerArt`: `id` and `card_id` = `blackout`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.44**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 259-643 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The sparking lamp head sits at about 40% height, centred; the dark tower shape reads against the lighter sky.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: a tall port floodlight tower going dark against the dusk sky, its lamps dead except one bursting in a shower of sparks, a cut power cable hanging, the moment the power dies,
seen three-quarter from below, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a person, letters on the tower, a lightning bolt symbol.

#### 10. `kc_b_smoke_screen.png` · slot `smoke_screen` · Smoke Screen

- [ ] **Card:** Smoke Screen (`smoke_screen`) · Tactic · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + shield silhouette.
- **Ships as:** `assets/sprites/banners/kc_b_smoke_screen.png` (1152x768 master); new `data/banners/smoke_screen.tres` (`BannerArt`: `id` and `card_id` = `smoke_screen`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.50**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 320-704 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The canisters and the base of the smoke wall in the band; the smoke runs left to right. Keep the sides darker so it does not turn into a flat grey card.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: two olive smoke canisters on wet asphalt pouring thick grey-white smoke into a wall across a container aisle, the smoke rolling sideways, amber light diffused through it,
seen side, low camera, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a person, coloured smoke (red, green, purple), letters on the canisters.

#### 11. `kc_b_sabotage.png` · slot `sabotage` · Sabotage

- [ ] **Card:** Sabotage (`sabotage`) · Tactic · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + SMG silhouette.
- **Ships as:** `assets/sprites/banners/kc_b_sabotage.png` (1152x768 master); new `data/banners/sabotage.tres` (`BannerArt`: `id` and `card_id` = `sabotage`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.48**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 300-684 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The burst centre at the middle of the band; flying debris may cross the edges but no key detail ends there.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: a fictional field generator and cable junction box bursting apart in sparks and a small warm fireball, severed cables whipping out, blown from inside,
seen three-quarter, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a person, letters or warning signs, a hazard symbol.

#### 12. `kc_b_aid_station.png` · slot `aid_station` · Aid Station

- [ ] **Card:** Aid Station (`aid_station`) · Field · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + shield silhouette (named in the DA audit).
- **Ships as:** `assets/sprites/banners/kc_b_aid_station.png` (1152x768 master); new `data/banners/aid_station.tres` (`BannerArt`: `id` and `card_id` = `aid_station`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.48**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 300-684 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The open case and stretcher in the band, lamp just above it. The medical read comes from the case and drip stand, never a symbol.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: a field aid post under a canvas lean-to between containers: a folding stretcher, an open olive medical case with bandage rolls, a drip stand and a warm lamp, ready and empty,
seen three-quarter, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a red cross, a red crescent, any symbol on the case, a person, blood.

#### 13. `kc_b_listening_post.png` · slot `listening_post` · Listening Post

- [ ] **Card:** Listening Post (`listening_post`) · Field · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + sentry silhouette (named in the DA audit).
- **Ships as:** `assets/sprites/banners/kc_b_listening_post.png` (1152x768 master); new `data/banners/listening_post.tres` (`BannerArt`: `id` and `card_id` = `listening_post`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.46**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 279-663 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The dish and screen in the band; the antenna may rise above it but its tip is not the focal point.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: a camouflaged listening post on a container roof: a directional microphone dish on a tripod, a short antenna mast and a rugged case with a dim amber screen, aimed out over the dark harbour,
seen three-quarter, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a person, a teal or blue screen glow (teal is the player's colour), letters on the screen.

#### 14. `kc_b_war_standard.png` · slot `war_standard` · War Standard

- [ ] **Card:** War Standard (`war_standard`) · Field (Undead home trait) · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + shield silhouette.
- **Ships as:** `assets/sprites/banners/kc_b_war_standard.png` (1152x768 master); new `data/banners/war_standard.tres` (`BannerArt`: `id` and `card_id` = `war_standard`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.44**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 259-643 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The sandbag ring and the lantern in the band; the streamer flows horizontally across it. Generate the cloth blank: it is a streamer, not a flag.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: a tall steel pole driven into a ring of sandbags, topped with a plain blank tattered olive cloth streamer and a hanging lantern, the streamer snapping in the wind,
seen three-quarter from below, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a flag with a design, any emblem, stripes, colours or pattern on the cloth, a skull, a person.

#### 15. `kc_b_bulwark.png` · slot `bulwark` · Bulwark

- [ ] **Card:** Bulwark (`bulwark`) · Field (Vanguard home trait) · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + shield silhouette.
- **Ships as:** `assets/sprites/banners/kc_b_bulwark.png` (1152x768 master); new `data/banners/bulwark.tres` (`BannerArt`: `id` and `card_id` = `bulwark`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.50**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 320-704 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The firing slit and plate at the centre of the band; the barricade runs left to right.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: a fortified chokepoint across a container aisle: stacked sandbags, wire-mesh gabion baskets filled with gravel and a steel plate with a firing slit, lit by one floodlight,
seen three-quarter, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a person, letters on the plate, brand-like barrier markings.

#### 16. `kc_b_mortar_pit.png` · slot `mortar_pit` · Mortar Pit

- [ ] **Card:** Mortar Pit (`mortar_pit`) · Field (Heavy home trait) · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + sentry silhouette.
- **Ships as:** `assets/sprites/banners/kc_b_mortar_pit.png` (1152x768 master); new `data/banners/mortar_pit.tres` (`BannerArt`: `id` and `card_id` = `mortar_pit`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.48**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 300-684 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The tube and the pit rim in the band; the smoke may rise above it. Different from the Mortar Barrage killstreak art (that one has a crew).

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: a round sandbagged pit holding a fictional mortar tube on its baseplate, shell crates beside it, smoke curling from the muzzle, just fired, nobody in the pit,
seen three-quarter from above, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a person, letters on crates, a real mortar model.

#### 17. `kc_b_sniper_perch.png` · slot `sniper_perch` · Sniper Perch

- [ ] **Card:** Sniper Perch (`sniper_perch`) · Field (Spec Ops home trait) · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + sniper silhouette.
- **Ships as:** `assets/sprites/banners/kc_b_sniper_perch.png` (1152x768 master); new `data/banners/sniper_perch.tres` (`BannerArt`: `id` and `card_id` = `sniper_perch`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.46**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 279-663 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The sandbags and the scope in the band; the long view of the port below gives depth without detail at the edges.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: an empty sniper nest on a crane's high walkway: a camouflage net, a shooting mat, sandbags and a spotting scope on a short tripod, overlooking the whole port far below,
seen three-quarter side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a person, a rifle with nobody holding it, letters.

#### 18. `kc_b_shambler.png` · slot `shambler` · Shambler (boss token)

- [ ] **Card:** Shambler (boss token) (`shambler`) · Unit token (not collectible; summoned by the Hollow Choir boss) · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + silhouette.
- **Ships as:** `assets/sprites/banners/kc_b_shambler.png` (1152x768 master); new `data/banners/shambler.tres` (`BannerArt`: `id` and `card_id` = `shambler`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.44**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 259-643 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Mask and shoulders in the band; the hunched silhouette must read as uncanny, not gory.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one gaunt, hunched figure in tattered olive fatigues and an old cracked gas mask, shambling forward out of low fog, arms hanging, no weapon,
seen three-quarter front, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor, no weapon; no weapon; ragged gear.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): gore, wounds, exposed flesh or bone, skulls, glowing eyes in red.

### Batch 3 · 8 images · Tactics without soldiers (#2) and the 3 new Tactics

*Why now:* Update #2: every Tactic (and the one Field) whose subject is a soldier becomes an object, place or event. Two of them open the Night city theatre, so Tactics take part in the board variety too.

Upload line: `kc-da-art batch 3: kc_b_callout_nightcity.png, kc_b_breach_and_clear_nightcity.png, kc_b_hold_the_line.png, kc_b_suppressing_fire.png, kc_b_tripwire_charge.png, kc_b_kc_wip_barrage.png, kc_b_kc_wip_war_shout.png, kc_b_kc_wip_premium_loadout.png`

#### 19. `kc_b_callout_nightcity.png` · slot `callout` · Callout

- [ ] **Card:** Callout (`callout`) · Tactic · update #2 (+#11 theatre) · theatre **Night city**
- **Shows today:** Killstreak painting: a soldier pointing (a soldier as a Tactic's subject).
- **Ships as:** `assets/sprites/banners/kc_b_callout_nightcity.png` (1152x768 master); new `data/banners/callout.tres` (`BannerArt`: `id` and `card_id` = `callout`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.46**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 279-663 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The binoculars and radio in the band at the centre; the flare above-right of centre, inside the middle 70%.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: a white-gold signal flare bursting high over a wet street between tower blocks, a pair of binoculars and a handheld radio resting on a rooftop parapet in the foreground, the flare lighting up the street below,
seen from the rooftop, three-quarter, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Night city: sodium street lights over a deep violet night sky, wet asphalt, concrete rooftops, fire escapes and dark tower blocks with unlit windows; no neon signs, no shop signs, no billboards, no red or pink light.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a person or a hand, a red flare, letters on the radio, signs.

#### 20. `kc_b_breach_and_clear_nightcity.png` · slot `breach_and_clear` · Breach and Clear

- [ ] **Card:** Breach and Clear (`breach_and_clear`) · Tactic · update #2 (+#11 theatre) · theatre **Night city**
- **Shows today:** Killstreak painting: three soldiers at a blown door (soldiers dominate the Tactic).
- **Ships as:** `assets/sprites/banners/kc_b_breach_and_clear_nightcity.png` (1152x768 master); new `data/banners/breach_and_clear.tres` (`BannerArt`: `id` and `card_id` = `breach_and_clear`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.48**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 300-684 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The bright doorway at the centre of the band; the door slab flies across it left to right.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: a steel stairwell door blown off its frame by a breaching charge, a burst of warm light, dust and splinters pouring out into a dim corridor, the instant of the blast,
seen straight on, slightly to the side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Night city: sodium street lights over a deep violet night sky, wet asphalt, concrete rooftops, fire escapes and dark tower blocks with unlit windows; no neon signs, no shop signs, no billboards, no red or pink light.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a person, a silhouette in the doorway, letters or signs on the door.

#### 21. `kc_b_hold_the_line.png` · slot `hold_the_line` · Hold the Line

- [ ] **Card:** Hold the Line (`hold_the_line`) · Tactic · update #2 · theatre **Port dusk**
- **Shows today:** Killstreak painting: three soldiers behind sandbags.
- **Ships as:** `assets/sprites/banners/kc_b_hold_the_line.png` (1152x768 master); new `data/banners/hold_the_line.tres` (`BannerArt`: `id` and `card_id` = `hold_the_line`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.50**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 320-704 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The top of the sandbag wall runs through the band from left to right; the floodlight glow sits at the centre.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: a long curved sandbag wall along a quay edge with steel barriers and coils of wire, spent casings scattered on top, lit by one floodlight, holding against the dusk,
seen three-quarter, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a person, helmets or weapons resting on the wall, letters.

#### 22. `kc_b_suppressing_fire.png` · slot `suppressing_fire` · Suppressing Fire

- [ ] **Card:** Suppressing Fire (`suppressing_fire`) · Tactic · update #2 · theatre **Port dusk**
- **Shows today:** Killstreak painting: soldiers firing.
- **Ships as:** `assets/sprites/banners/kc_b_suppressing_fire.png` (1152x768 master); new `data/banners/suppressing_fire.tres` (`BannerArt`: `id` and `card_id` = `suppressing_fire`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.48**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 300-684 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The impact burst on the barrier at the centre of the band; the tracers run the full width.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: streams of warm tracer lines raking across a container aisle from left to right, sparks and concrete chips bursting off a barrier, a wall of fire pinning the aisle,
seen side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a person, a shooter, red or green tracers, letters.

#### 23. `kc_b_tripwire_charge.png` · slot `tripwire_charge` · Tripwire Charge

- [ ] **Card:** Tripwire Charge (`tripwire_charge`) · Field (hidden trap) · update #2 · theatre **Port dusk**
- **Shows today:** Killstreak painting: a crouching soldier is the subject.
- **Ships as:** `assets/sprites/banners/kc_b_tripwire_charge.png` (1152x768 master); new `data/banners/tripwire_charge.tres` (`BannerArt`: `id` and `card_id` = `tripwire_charge`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.52**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 340-724 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The wire runs horizontally through the band; the charge and its amber light sit at x 55-65%.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: a thin taut wire glinting across a wet container aisle at ankle height, tied to a small fictional charge with one blinking amber light, armed and waiting,
seen very low camera, side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a person, a boot, letters, a real explosive model.

#### 24. `kc_b_kc_wip_barrage.png` · slot `kc_wip_barrage` · Barrage

- [ ] **Card:** Barrage (`kc_wip_barrage`) · Tactic · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient (no art).
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_barrage.png` (1152x768 master); new `data/banners/kc_wip_barrage.tres` (`BannerArt`: `id` and `card_id` = `kc_wip_barrage`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.48**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 300-684 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The three bursts sit across the band at about 30%, 50% and 70% of the width; the middle one is the brightest.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: a line of three shell impacts walking along a quay: warm explosions bursting in a row with smoke columns and debris, hitting the front line,
seen side, from a distance, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): people, bodies, letters, a red sky that reads as blood.

#### 25. `kc_b_kc_wip_war_shout.png` · slot `kc_wip_war_shout` · War Shout

- [ ] **Card:** War Shout (`kc_wip_war_shout`) · Tactic · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient (no art).
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_war_shout.png` (1152x768 master); new `data/banners/kc_wip_war_shout.tres` (`BannerArt`: `id` and `card_id` = `kc_wip_war_shout`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.46**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 279-663 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The horn mouth at the centre of the band; the rings spread left and right.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: a battered hand-cranked siren horn and a loudhailer on a steel pole above a sandbag wall, blaring, the sound shown as rings of dust and steam blasting outward,
seen three-quarter, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a person, an open mouth or face, letters, sound-effect lettering.

#### 26. `kc_b_kc_wip_premium_loadout.png` · slot `kc_wip_premium_loadout` · Premium Loadout

- [ ] **Card:** Premium Loadout (`kc_wip_premium_loadout`) · Tactic · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient (no art).
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_premium_loadout.png` (1152x768 master); new `data/banners/kc_wip_premium_loadout.tres` (`BannerArt`: `id` and `card_id` = `kc_wip_premium_loadout`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.50**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 320-704 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The rifle lies horizontally in the band; the case lid stays above it. Different from the Operator paintings: the case is the subject, not a weapon on a bench.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: an open hard case on a steel bench, a fictional rifle nested in grey foam with a scope, a grip and a spare magazine in their own cut-outs, the lid just opened, a warm lamp glinting on the parts,
seen three-quarter from above, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: no people in the image (no soldier, no hands); all equipment in olive, khaki and charcoal,
fictional designs with no markings.
Composition: the main object and its brightest detail between 30% and 65% of the image height and in the
middle 70% of the width; left and right 15% calm, darker and simple; horizontal flow; simple sky top and
simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a person or a hand, maker marks, letters on the case, a real weapon model.

### Batch 4 · 8 images · New units (Wip set), part 1

*Why now:* The first 8 of the 12 new reward units, which show a generated gradient today.

Upload line: `kc-da-art batch 4: kc_b_kc_wip_scout.png, kc_b_kc_wip_medic.png, kc_b_kc_wip_sharpshooter.png, kc_b_kc_wip_flag_bearer.png, kc_b_kc_wip_hacker.png, kc_b_kc_wip_runner.png, kc_b_kc_wip_sniper.png, kc_b_kc_wip_riot_shield.png`

#### 27. `kc_b_kc_wip_scout.png` · slot `kc_wip_scout` · Scout

- [ ] **Card:** Scout (`kc_wip_scout`) · Unit (Vanguard, SMG; Front line) · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + class silhouette (no art).
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_scout.png` (1152x768 master); new `data/banners/kc_wip_scout.tres` (`BannerArt`: `id` and `card_id` = `kc_wip_scout`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.45**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 269-653 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Hood, goggles and the SMG in the band; the bollard top at about 62%.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one lean scout in a hooded olive smock and goggles, crouched on a mooring bollard at the quay edge, a compact fictional submachine gun ready, peering ahead,
seen three-quarter side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; light kit, a hood over the helmet.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a visible face, a second figure, muzzle flash.

#### 28. `kc_b_kc_wip_medic.png` · slot `kc_wip_medic` · Medic

- [ ] **Card:** Medic (`kc_wip_medic`) · Unit (Undead home trait, AR; Patch 1) · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + class silhouette (no art).
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_medic.png` (1152x768 master); new `data/banners/kc_wip_medic.tres` (`BannerArt`: `id` and `card_id` = `kc_wip_medic`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.45**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 269-653 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Helmet, pack and carbine in the band. Must not look like the Combat Medic (kneeling at a case).

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one field medic with a large olive medical pack and a fictional carbine slung, running low between containers toward the right,
seen side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; a plain armband with no symbol, a big pack.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a red cross or any symbol on the armband or pack, a patient, blood.

#### 29. `kc_b_kc_wip_sharpshooter.png` · slot `kc_wip_sharpshooter` · Sharpshooter

- [ ] **Card:** Sharpshooter (`kc_wip_sharpshooter`) · Unit (Spec Ops, sniper; First Shot) · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + class silhouette (no art).
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_sharpshooter.png` (1152x768 master); new `data/banners/kc_wip_sharpshooter.tres` (`BannerArt`: `id` and `card_id` = `kc_wip_sharpshooter`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.45**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 269-653 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Head, scope and muzzle flash in the band; the rifle runs across x 25-80%.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one marksman on a steel catwalk, standing and firing first: a long fictional marksman rifle shouldered, a small bright muzzle flash at the right,
seen side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; a short cape of camouflage netting.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a visible face, a real rifle model, lying prone (that is the Marksman).

#### 30. `kc_b_kc_wip_flag_bearer.png` · slot `kc_wip_flag_bearer` · Flag Bearer

- [ ] **Card:** Flag Bearer (`kc_wip_flag_bearer`) · Unit (Vanguard, AR; column buff on arrival) · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + class silhouette (no art).
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_flag_bearer.png` (1152x768 master); new `data/banners/kc_wip_flag_bearer.tres` (`BannerArt`: `id` and `card_id` = `kc_wip_flag_bearer`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.46**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 279-663 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Head and rifle in the band; the streamer flows horizontally behind through the band.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one soldier carrying a tall pole with a plain blank tattered khaki streamer, striding forward, a fictional rifle in the other hand, the streamer whipping behind,
seen three-quarter side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; the streamer is blank cloth, not a flag.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a flag with any design, emblem, stripes or colours on the cloth, a visible face.

#### 31. `kc_b_kc_wip_hacker.png` · slot `kc_wip_hacker` · Hacker

- [ ] **Card:** Hacker (`kc_wip_hacker`) · Unit (Spec Ops, SMG; +1 Supply) · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + class silhouette (no art).
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_hacker.png` (1152x768 master); new `data/banners/kc_wip_hacker.tres` (`BannerArt`: `id` and `card_id` = `kc_wip_hacker`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.48**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 300-684 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Visor and laptop in the band; the laptop screen glows amber, not teal.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one tech operator with a compact fictional submachine gun slung, kneeling at an open junction box, a rugged laptop on one knee, cables plugged in,
seen three-quarter side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; a headset over the helmet.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): letters or code on the screen, a teal or blue screen glow, a visible face.

#### 32. `kc_b_kc_wip_runner.png` · slot `kc_wip_runner` · Runner

- [ ] **Card:** Runner (`kc_wip_runner`) · Unit (Spec Ops, SMG; Agile) · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + class silhouette (no art).
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_runner.png` (1152x768 master); new `data/banners/kc_wip_runner.tres` (`BannerArt`: `id` and `card_id` = `kc_wip_runner`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.44**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 259-643 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The whole leaping body crosses the band left to right; head at about 40%. Must not copy the Flanker (running on the quay).

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one agile operator, leaping across the gap between two container stacks, a compact fictional submachine gun in one hand,
seen side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; light kit, no backpack.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a visible face, falling, a second figure.

#### 33. `kc_b_kc_wip_sniper.png` · slot `kc_wip_sniper` · Sniper

- [ ] **Card:** Sniper (`kc_wip_sniper`) · Unit (Spec Ops, sniper; Pick) · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + class silhouette (no art).
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_sniper.png` (1152x768 master); new `data/banners/kc_wip_sniper.tres` (`BannerArt`: `id` and `card_id` = `kc_wip_sniper`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.47**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 289-673 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Hood, scope and barrel in the band; the girder runs horizontally under the rifle.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one sniper in a ghillie hood, kneeling behind a crane's steel girder, a long fictional bolt-action rifle resting on the beam, aiming right,
seen side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; a ghillie hood, a rangefinder on the belt.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a visible face, lying prone on a container (that is the Marksman).

#### 34. `kc_b_kc_wip_riot_shield.png` · slot `kc_wip_riot_shield` · Riot Shield

- [ ] **Card:** Riot Shield (`kc_wip_riot_shield`) · Unit (Vanguard; Suppress 1, Cover 1) · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + class silhouette (no art).
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_riot_shield.png` (1152x768 master); new `data/banners/kc_wip_riot_shield.tres` (`BannerArt`: `id` and `card_id` = `kc_wip_riot_shield`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.45**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 269-653 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The shield and the visor behind it in the band. Must not look like the Protector (kneeling with a black ballistic shield).

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one heavily padded trooper behind a tall curved transparent riot shield with a narrow viewport, pushing forward through sparks, a short baton held low,
seen three-quarter front, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; padded shoulders, a full visor.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): letters on the shield, a black slab shield, a visible face.

### Batch 5 · 8 images · New units part 2, then Night city on the most-used units

*Why now:* The last 4 new units close update #1. Then update #11 starts with the units in the most decks.

Upload line: `kc-da-art batch 5: kc_b_kc_wip_juggernaut.png, kc_b_kc_wip_kamikaze.png, kc_b_kc_wip_fast_learner.png, kc_b_kc_wip_laser_gunner.png, kc_b_shieldman_nightcity.png, kc_b_combat_medic_nightcity.png, kc_b_rifleman_nightcity.png, kc_b_demolitions_expert_nightcity.png`

#### 35. `kc_b_kc_wip_juggernaut.png` · slot `kc_wip_juggernaut` · Juggernaut

- [ ] **Card:** Juggernaut (`kc_wip_juggernaut`) · Unit (Heavy, LMG; Pierce) · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + class silhouette (no art).
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_juggernaut.png` (1152x768 master); new `data/banners/kc_wip_juggernaut.tres` (`BannerArt`: `id` and `card_id` = `kc_wip_juggernaut`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.45**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 269-653 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Visor and gun in the band; the muzzle flash at the right, inside 85%.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one hulking trooper in heavy bomb-suit style plate armour and a full visor helmet, walking forward firing a fictional belt-fed heavy machine gun from the hip,
seen three-quarter front, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; the biggest silhouette in the set.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a visible face, a real machine gun model, gore.

#### 36. `kc_b_kc_wip_kamikaze.png` · slot `kc_wip_kamikaze` · Kamikaze

- [ ] **Card:** Kamikaze (`kc_wip_kamikaze`) · Unit (Heavy; explodes when downed) · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + class silhouette (no art).
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_kamikaze.png` (1152x768 master); new `data/banners/kc_wip_kamikaze.tres` (`BannerArt`: `id` and `card_id` = `kc_wip_kamikaze`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.50**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 320-704 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The robot fills the middle third of the band; amber light at its top.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: a small tracked demolition robot carrying a large fictional charge with one amber warning light, rolling fast over a wet quay toward the right,
seen three-quarter side, low camera, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; no person: the unit is the robot.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a person, a vest of explosives, letters or hazard symbols, a real robot model.

#### 37. `kc_b_kc_wip_fast_learner.png` · slot `kc_wip_fast_learner` · Fast Learner

- [ ] **Card:** Fast Learner (`kc_wip_fast_learner`) · Unit (Undead home trait, AR; grows each round) · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + class silhouette (no art).
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_fast_learner.png` (1152x768 master); new `data/banners/kc_wip_fast_learner.tres` (`BannerArt`: `id` and `card_id` = `kc_wip_fast_learner`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.45**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 269-653 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Goggles, hands and rifle in the band.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one young soldier in mismatched gear patched together from the field, stepping out of smoke, reloading a fictional rifle with quick sure hands,
seen three-quarter front, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; a mix of older and newer kit pieces.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a visible face, gore, a second figure.

#### 38. `kc_b_kc_wip_laser_gunner.png` · slot `kc_wip_laser_gunner` · Laser Gunner

- [ ] **Card:** Laser Gunner (`kc_wip_laser_gunner`) · Unit (Heavy; Beam) · update #1 · theatre **Port dusk**
- **Shows today:** Generated gradient + class silhouette (no art).
- **Ships as:** `assets/sprites/banners/kc_b_kc_wip_laser_gunner.png` (1152x768 master); new `data/banners/kc_wip_laser_gunner.tres` (`BannerArt`: `id` and `card_id` = `kc_wip_laser_gunner`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.47**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 289-673 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The cannon and the start of the beam in the band; the beam runs to the right edge.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one heavy-armoured trooper, bracing a large fictional beam cannon with cooling coils, firing a straight bright white-gold beam to the right,
seen side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Port dusk: amber sodium lights over a slate-blue sky, cranes and containers.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; a full visor, a power pack on the back.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a red, green or teal beam, letters, a visible face.

#### 39. `kc_b_shieldman_nightcity.png` · slot `shieldman` · Protector

- [ ] **Card:** Protector (`shieldman`) · Unit (in 5 decks) · update #11 · theatre **Night city**
- **Shows today:** Killstreak Port-dusk painting `card_shieldman.webp` (stays as the fallback file).
- **Ships as:** `assets/sprites/banners/kc_b_shieldman_nightcity.png` (1152x768 master); new `data/banners/shieldman.tres` (`BannerArt`: `id` and `card_id` = `shieldman`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.45**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 269-653 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Shield viewport and visor in the band.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one defender behind a heavy black ballistic shield with a small viewport, kneeling in a narrow alley, sparks ricocheting off the shield, a pistol braced on its edge,
seen three-quarter front, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Night city: sodium street lights over a deep violet night sky, wet asphalt, concrete rooftops, fire escapes and dark tower blocks with unlit windows; no neon signs, no shop signs, no billboards, no red or pink light.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): letters on the shield, a visible face.

#### 40. `kc_b_combat_medic_nightcity.png` · slot `combat_medic` · Combat Medic

- [ ] **Card:** Combat Medic (`combat_medic`) · Unit (in 5 decks) · update #11 · theatre **Night city**
- **Shows today:** Killstreak Port-dusk painting `card_combat_medic.webp` (stays as the fallback file).
- **Ships as:** `assets/sprites/banners/kc_b_combat_medic_nightcity.png` (1152x768 master); new `data/banners/combat_medic.tres` (`BannerArt`: `id` and `card_id` = `combat_medic`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.45**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 269-653 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Hands, case and helmet in the band; the doorway's warm light behind.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one combat medic with a fictional carbine slung, kneeling in a stairwell doorway, pulling a bandage roll from a large open olive medical case,
seen three-quarter side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Night city: sodium street lights over a deep violet night sky, wet asphalt, concrete rooftops, fire escapes and dark tower blocks with unlit windows; no neon signs, no shop signs, no billboards, no red or pink light.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; a plain armband with no symbol.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a red cross or any symbol, a patient, blood.

#### 41. `kc_b_rifleman_nightcity.png` · slot `rifleman` · Rifleman

- [ ] **Card:** Rifleman (`rifleman`) · Unit (in 4 decks) · update #11 · theatre **Night city**
- **Shows today:** Killstreak Port-dusk painting `card_rifleman.webp` (stays as the fallback file).
- **Ships as:** `assets/sprites/banners/kc_b_rifleman_nightcity.png` (1152x768 master); new `data/banners/rifleman.tres` (`BannerArt`: `id` and `card_id` = `rifleman`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.45**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 269-653 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Head, rifle and muzzle flash in the band; the flash inside 85%.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one rifleman, firing a fictional assault rifle to the right from behind a concrete planter on a wet street,
seen side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Night city: sodium street lights over a deep violet night sky, wet asphalt, concrete rooftops, fire escapes and dark tower blocks with unlit windows; no neon signs, no shop signs, no billboards, no red or pink light.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a visible face, cars with number plates, signs.

#### 42. `kc_b_demolitions_expert_nightcity.png` · slot `demolitions_expert` · Demolitions Expert

- [ ] **Card:** Demolitions Expert (`demolitions_expert`) · Unit (in 4 decks) · update #11 · theatre **Night city**
- **Shows today:** Killstreak Port-dusk painting `card_demolitions_expert.webp` (stays as the fallback file).
- **Ships as:** `assets/sprites/banners/kc_b_demolitions_expert_nightcity.png` (1152x768 master); new `data/banners/demolitions_expert.tres` (`BannerArt`: `id` and `card_id` = `demolitions_expert`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.45**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 269-653 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Hands, charge and helmet in the band.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one demolitions expert with a fictional rifle slung, pressing a breaching charge onto a closed steel roller shutter, wires trailing to a detonator,
seen three-quarter side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Night city: sodium street lights over a deep violet night sky, wet asphalt, concrete rooftops, fire escapes and dark tower blocks with unlit windows; no neon signs, no shop signs, no billboards, no red or pink light.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; a heavy pack of charges.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): letters or signs on the shutter, a visible face.

### Batch 6 · 6 images · Night city, the rest of the most-used units

*Why now:* Update #11 finished: the rest of the 10 most-used units move to Night city.

Upload line: `kc-da-art batch 6: kc_b_point_man_nightcity.png, kc_b_marksman_nightcity.png, kc_b_gunner_nightcity.png, kc_b_flanker_nightcity.png, kc_b_breacher_nightcity.png, kc_b_recon_specialist_nightcity.png`

#### 43. `kc_b_point_man_nightcity.png` · slot `point_man` · Point Man

- [ ] **Card:** Point Man (`point_man`) · Unit (in 3 decks) · update #11 · theatre **Night city**
- **Shows today:** Killstreak Port-dusk painting `card_point_man.webp` (stays as the fallback file).
- **Ships as:** `assets/sprites/banners/kc_b_point_man_nightcity.png` (1152x768 master); new `data/banners/point_man.tres` (`BannerArt`: `id` and `card_id` = `point_man`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.45**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 269-653 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Head and SMG in the band; the lamp glow above-left of centre.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one point man, advancing fast along a rain-slick sidewalk under a sodium street lamp, a compact fictional submachine gun raised,
seen three-quarter side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Night city: sodium street lights over a deep violet night sky, wet asphalt, concrete rooftops, fire escapes and dark tower blocks with unlit windows; no neon signs, no shop signs, no billboards, no red or pink light.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a visible face, shop signs.

#### 44. `kc_b_marksman_nightcity.png` · slot `marksman` · Marksman

- [ ] **Card:** Marksman (`marksman`) · Unit (in 3 decks) · update #11 · theatre **Night city**
- **Shows today:** Killstreak Port-dusk painting `card_marksman.webp` (stays as the fallback file).
- **Ships as:** `assets/sprites/banners/kc_b_marksman_nightcity.png` (1152x768 master); new `data/banners/marksman.tres` (`BannerArt`: `id` and `card_id` = `marksman`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.47**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 289-673 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Head, scope and rifle in the band; the parapet edge at about 60%.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one marksman, lying prone on a rooftop edge with a long fictional rifle on a bipod, tower blocks behind,
seen side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Night city: sodium street lights over a deep violet night sky, wet asphalt, concrete rooftops, fire escapes and dark tower blocks with unlit windows; no neon signs, no shop signs, no billboards, no red or pink light.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; a ghillie hood.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a visible face, lit windows with figures.

#### 45. `kc_b_gunner_nightcity.png` · slot `gunner` · Gunner

- [ ] **Card:** Gunner (`gunner`) · Unit (in 3 decks) · update #11 · theatre **Night city**
- **Shows today:** Killstreak Port-dusk painting `card_gunner.webp` (stays as the fallback file).
- **Ships as:** `assets/sprites/banners/kc_b_gunner_nightcity.png` (1152x768 master); new `data/banners/gunner.tres` (`BannerArt`: `id` and `card_id` = `gunner`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.45**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 269-653 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Visor, gun and muzzle flash in the band.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one gunner, firing a fictional belt-fed machine gun from a sandbagged balcony, casings flying,
seen three-quarter front, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Night city: sodium street lights over a deep violet night sky, wet asphalt, concrete rooftops, fire escapes and dark tower blocks with unlit windows; no neon signs, no shop signs, no billboards, no red or pink light.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a visible face, a real machine gun model.

#### 46. `kc_b_flanker_nightcity.png` · slot `flanker` · Flanker

- [ ] **Card:** Flanker (`flanker`) · Unit (in 3 decks) · update #11 · theatre **Night city**
- **Shows today:** Killstreak Port-dusk painting `card_flanker.webp` (stays as the fallback file).
- **Ships as:** `assets/sprites/banners/kc_b_flanker_nightcity.png` (1152x768 master); new `data/banners/flanker.tres` (`BannerArt`: `id` and `card_id` = `flanker`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.46**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 279-663 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** The running body crosses the band; head at about 40%.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one flanker, sprinting under an elevated rail viaduct, a compact fictional submachine gun held low, splashes at the feet,
seen side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Night city: sodium street lights over a deep violet night sky, wet asphalt, concrete rooftops, fire escapes and dark tower blocks with unlit windows; no neon signs, no shop signs, no billboards, no red or pink light.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; light kit.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a visible face, a train with markings.

#### 47. `kc_b_breacher_nightcity.png` · slot `breacher` · Breacher

- [ ] **Card:** Breacher (`breacher`) · Unit (in 3 decks) · update #11 · theatre **Night city**
- **Shows today:** Killstreak Port-dusk painting `card_breacher.webp` (stays as the fallback file).
- **Ships as:** `assets/sprites/banners/kc_b_breacher_nightcity.png` (1152x768 master); new `data/banners/breacher.tres` (`BannerArt`: `id` and `card_id` = `breacher`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.45**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 269-653 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Helmet, shotgun and sparks in the band.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one breacher, firing a fictional pump shotgun into the lock of a steel door, sparks bursting,
seen three-quarter side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Night city: sodium street lights over a deep violet night sky, wet asphalt, concrete rooftops, fire escapes and dark tower blocks with unlit windows; no neon signs, no shop signs, no billboards, no red or pink light.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a visible face, letters on the door.

#### 48. `kc_b_recon_specialist_nightcity.png` · slot `recon_specialist` · Recon Specialist

- [ ] **Card:** Recon Specialist (`recon_specialist`) · Unit (in 2 decks + the run pool) · update #11 · theatre **Night city**
- **Shows today:** Killstreak Port-dusk painting `card_recon_specialist.webp` (stays as the fallback file).
- **Ships as:** `assets/sprites/banners/kc_b_recon_specialist_nightcity.png` (1152x768 master); new `data/banners/recon_specialist.tres` (`BannerArt`: `id` and `card_id` = `recon_specialist`, `is_default = true`, `placeholder = false`, `licence = "studio-owned"`, `image_path` = the shipped file, the crop below).
- **Crop:** `banner_y` **0.47**, `portrait_x` **0.50**. On the 1536x1024 original the 4:1 band is y 289-673 px; the focal zone is x 230-1306 px (middle 70%); x 0-230 and 1306-1536 are the calm icon columns.
- **Focal:** Goggles, tablet and drone in the band; the drone just above the head, inside the middle 70%.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: one recon specialist, kneeling on a rooftop launching a small fictional quadcopter drone, a rugged tablet in the other hand,
seen three-quarter side, filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: Night city: sodium street lights over a deep violet night sky, wet asphalt, concrete rooftops, fire escapes and dark tower blocks with unlit windows; no neon signs, no shop signs, no billboards, no red or pink light.
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings; night-vision goggles flipped up.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

**Avoid** (paste after "Regenerate, avoid:" if needed): a teal or blue screen glow, a real drone model, a visible face.
---

## 6. Reject checklist (any "yes" = regenerate; two tries, then skip and note it)

- [ ] Any letters, numbers, fake writing, signs, a logo, a stamp, a flag, insignia, a patch, a red cross or red crescent?
- [ ] A visible face, someone who looks like a real person, or a clearly real weapon, vehicle or drone model?
- [ ] Blood, wounds, gore, a skull, red that reads as blood?
- [ ] A Tactic or Field with a person as the subject, or any person where the prompt says "no people"?
- [ ] Squint test at 160x40 fails, or the key detail is outside the band (see each entry's pixels)?
- [ ] Left or right 15% bright or busy?
- [ ] Night city: neon, signage, red or pink light, lit windows with figures?
- [ ] Does it look like a screen, banner or emblem from an existing shooter?

**IP (binding):** every prompt here is our own wording: no franchise, game, studio or "calling card" names, no copied card designs, camo, operator, map, killstreak or weapon names. Our names only (Kestrel AR-7, Bastion-60 ...). Licensed images never go in prompts, docs or this pack.

---

## 7. Technical Artist hand-off

1. **Dry run** each batch: `python3 -I tools/ui_kit_icons.py --manifest documentation/art/da-art-pack-1-manifest.csv <raw_dir> source/project-killingcard --dry-run`; every file should say `SHIP`. Then without `--dry-run`. Raw drops stay outside git (a scratch folder, or `assets/incoming/`, which Godot ignores but git does not: never `git add` it).
2. **Data:** one `data/banners/<slot>.tres` per image, as each entry's "Ships as" line says (`id`, `card_id`, `image_path = "res://assets/sprites/banners/<file>.png"`, `banner_y`, `portrait_x` from the entry, `is_default = true`, `placeholder = false`, `artist = "KillingCard studio (DA art pack 1)"`, `licence = "studio-owned"`). For the four Privates, edit the existing files. For `si_ammo_resupply`, the kit piece is picked up by `_apply_si_art`; only update the crop and note.
3. **The no-image fixes** in §1.3 (the two rival crew Operators; the old `si_*` line once the Privates ship).
4. **Size:** 48 masters as PNG are heavy for the web build. `banner-art-direction.md` §3.2 recommends WebP q80-85 with the `keep` importer (the game decodes it itself); converting after the importer and pointing `image_path` at the `.webp` costs nothing in code. Budget: about 100-150 KB each, 5-7 MB for the pack.
5. **Check in the game:** the board at phone size (844x390), the Codex, the Duel hub hero row and the Loadout; then log the batch in `ui-kit-import-log.md` (shipped, rejects, notes for the next pack).

## 8. Notes for other owners

- **Designer:** "Kamikaze" is drawn as a demolition robot (a person with a charge reads as a suicide attacker, which the public build should not show). Consider a name to match (for example "Demo Crawler"); the art works either way.
- **Designer:** "Flag Bearer" and "War Standard" carry a **blank streamer**, never a flag, per the IP rules.
- **UI owner:** none of this needs code. The locked Operator tile shows Bastion-60's painting as soon as `bastion_60.tres` lands; keep the lock treatment (steel socket + lock icon) over the art rather than dimming it (`art-direction.md` update #5).

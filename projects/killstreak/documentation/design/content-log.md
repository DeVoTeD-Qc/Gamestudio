# Killstreak: Content Log (p03)

*Author: Mid Game Designer Agent · 2026-11-03 · Board task p03 · Source of truth: `core-rules.md` (including "Rulings (2026-11-03)") · Data: `source/project-killstreak/data/`*

This log records every value in `data/` that core-rules doesn't state, and every change from it. If a value isn't listed here, it comes straight from core-rules.

## Content counts
| Type | Count | Files |
|---|---|---|
| Deck cards (collectible) | 20 | `cards/*.tres`: the 20 designs of core-rules §5 |
| Token | 1 | `cards/sentry.tres` |
| Primaries | 3 | `kestrel_ar7`, `wasp_9`, `longreach_338` |
| Attachments | 4 | `extended_mag`, `foregrip`, `holo_sight`, `ceramic_lining` |
| Secondary / Lethal / Tactical | 1 / 1 / 1 | `p12_sidearm`, `frag_grenade`, `flashbang` |
| Perks | 4 | `streak_discipline`, `field_salvage`, `grit`, `objective_focus` |
| Killstreaks | 4 | `recon_drone`, `mortar_barrage`, `sentry_turret`, `attack_helo` |
| Enemy squads | 3 + 1 | `squad_rusher`, `squad_anchor`, `squad_black_meridian`, plus `squad_tutorial` for p15 |
| Maps | 1 | `maps/port_vasel.tres` |
| Run config | 1 | `run_config.tres` (`run_default`) |

The samples `rifleman`, `breach_and_clear` and `mortar_barrage` already matched core-rules, so I kept them unchanged.

## Choices and changes
| id | field | value | reason |
|---|---|---|---|
| (all cards) | card count | 20 designs + 1 token | The milestone plan says "20 starter + 6 reward = 26". Core-rules §5 has 20 designs, and the 6 reward cards (Flanker, Demolitions Expert, Breach and Clear, Comms Relay, Anvil, Wren) are part of those 20. Per the brief, I followed core-rules. |
| okafor_anvil | id | `okafor_anvil` | Ids must be snake_case. The display name stays `Sgt. Okafor "Anvil"`. |
| halek_wren | id | `halek_wren` | Same reason. Display name `Lt. Halek "Wren"`. |
| callout | text | "Resolves immediately: reveal red dots in a zone; your first unit to arrive there gets +1 FP." | The core-rules text is 113 characters and the limit is 100. I dropped "this Reveal … this round"; Ruling 7 still governs. |
| callout | effects[1] | IMMEDIATE MODIFY_FIREPOWER +1, NEXT_FRIENDLY_ARRIVING, CHOSEN_ZONE, duration 1 | Ruling 7 says the bonus also applies to units played before the Callout. If this were ON_PLAY it would resolve after units arrive (Reveal step b), so I registered it in Deploy. See Format gaps #3. |
| recon_specialist | effects[0] | ON_DEPLOY REVEAL_RED_DOTS, OWNER, THIS_ZONE, delay 1, duration 1 | Follows "next round". |
| flank_route | effects | ON_PLAY MOVE_UNIT CHOSEN_FRIENDLY ADJACENT_ZONE, then GRANT_FIRST_SHOT CHOSEN_FRIENDLY duration 1 | The move resolves at Reveal, after units arrive, so it can move a unit played this round. Can it move the Operator? Open question for p04/Sr Designer. I assumed **no**: "unit" means a unit card. |
| hold_the_line | target | ALL_FRIENDLIES (includes the Operator) | Core-rules says "your units". I assumed the Operator counts as one of your units in that zone. |
| suppressing_fire | target | ALL_ENEMIES (includes the enemy Operator) | The §6 walkthrough confirms it: Suppressing Fire hits the player's Operator. |
| tripwire_charge | streak credit | open question | §2 lists streak sources as "units, Operator, Secondary, Lethal or Tactics". Equipment (Tripwire) and On Down (Demolitions Expert) aren't listed. **Proposal: both count** (the player caused them; only killstreaks are excluded). Needs a Sr Designer / p04 ruling. |
| comms_relay | hidden | false | Core-rules doesn't say it hides. Only Tripwire is hidden. |
| sentry | weapon_class | NONE | No class is given, so the Sentry gets no range bonus. |
| sentry | cost | 0 | It's a token. It's never played from hand. |
| sentry | text | "Cover 1. Ignored for control; no elimination credit for destroying it." | Inspector text for the token. |
| okafor_anvil | effects[0] | PASSIVE MODIFY_FIREPOWER +1, OTHER_FRIENDLIES, THIS_ZONE | "Your other units here" includes the Operator if it's in that zone (same reading as Hold the Line). |
| halek_wren | effects[0] | ON_ELIMINATE STREAK_BONUS +1 | Only her own eliminations count (unit-card ON_ELIMINATE semantics). |
| demolitions_expert | effects[0] | ON_DOWN DAMAGE 3, ENEMY_POINT_MAN, THIS_ZONE | Applies when it is eliminated. It counts for streak per the proposal above. |
| holo_sight | effects[0] | PASSIVE GRANT_FIRST_SHOT, OPERATOR, OPERATOR_ZONE, condition ZONE_IS_MID | "Mid zones" means zones with a **Mid range tag**. On Port Vasel that's Loading Offices (Right), not Crane Yard. This is how I read the §3 range-tag wording. Flag for Sr Designer if "Mid" meant the centre zone. |
| wasp_9, longreach_338 | authored | yes | Both are out of the player's prototype pool. I authored them because §3 defines them. Wasp-9 is the Rusher squad's Primary (next row). Longreach isn't used anywhere yet. |
| wasp_9 | attachments | extended_mag, foregrip, ceramic_lining | Holo Sight does nothing on a First Shot weapon, so I left it out. |
| longreach_338 | attachments | all 4 | |
| p12_sidearm | trigger | ON_PLAY (resolves at Reveal) | §2 lists the Secondary in Reveal step b. |
| frag_grenade | effects | DAMAGE 2 ENEMY_POINT_MAN + DAMAGE 1 ENEMY_SECOND_IN_LINE, OPERATOR_OR_ADJACENT | Engine note: pick both targets before applying damage. If the point man dies, the 1 damage still goes to the original second unit. |
| frag_grenade, flashbang | supply_cost | 0 | The Flashbang's cost isn't stated, so I matched it to the Frag. |
| flashbang | trigger | ON_PLAY, duration 1 | It resolves at Reveal and lasts through this round's firefight. |
| field_salvage | trigger scope | ON_ELIMINATE, uses_per_round 1 | **Choice:** it triggers on streak-qualifying eliminations only, so killstreak kills don't draw. This keeps one definition of "you eliminate". |
| grit | trigger | PASSIVE SURVIVE_LETHAL 1, OPERATOR, uses_per_match 1 | |
| recon_drone | effects | IMMEDIATE REVEAL_DEPLOYMENTS + IMMEDIATE REMOVE_COVER, ALL_ZONES, duration 2 | It's activated during Deploy, and the AI's plan is already committed, so the reveal has to fire right away to matter this round. REMOVE_COVER is a status for the rest of this round and the next. It also removes Cover granted later (Hold the Line, Shieldman, Foregrip). |
| sentry_turret | effects[0] | ON_PLAY SUMMON_UNIT, CHOSEN_ZONE, summon_card = sentry | Per Ruling 5. If the zone already has 4 friendly units, the zone can't be chosen. |
| attack_helo | effects[0] | START_OF_FIREFIGHT DAMAGE 2, ENEMY_POINT_MAN, ALL_ZONES, duration 2 | Per Ruling 8. Engine note: "every zone" includes zones with enemies but no friendly units, where no firefight happens. Proposal: it hits there too. |
| run_default | starter_killstreaks | recon_drone, mortar_barrage, attack_helo | §3 starter loadout. |
| run_default | reward_pool | Flanker ×2, Demolitions Expert ×2, Breach and Clear ×2, Comms Relay ×2, Anvil ×1, Wren ×1, plus 1 copy of every starter design except Rifleman (13) = 23 entries | Core-rules only says "plus extra copies of starter cards". With these weights the new cards make up about 43% of the pool, and each elite about 4%. I left Rifleman out because it's filler and would waste an offer. p19 will tune this. Engine note: an offer of 3 should show 3 **different** designs. |
| run_default | matches | 1 B1 Rusher ZC · 2 B1 Anchor FF · 3 B2 Rusher FF · 4 B2 Anchor ZC · 5 Rival Black Meridian ZC | It alternates personalities and modes, so both modes come up in each bracket. The Rival plays Zone Control, where its Holder (Anvil) matters most. The Rival's `bracket` = 2, the last bracket. |
| run_default | enemy bonuses | B1 +0/+0; B2 and Rival armor +1, firepower +0 | Ruling 11. |
| run_default | weapon_level_after_matches / perk_offer_after_matches / perk_choices | [1, 3, 4] / [2, 4] / 2 | Rulings 1–2. The script default is still [1, 3, 5]. I corrected the README text. |
| run_default | §10 tunables | deck 20, hand 4 + 1, mulligan 1, draw 2, cap 7, supply N+1 cap 7, zone 4, cooldown 3, ZC 6, FF 7, round cap 8, overtime draw after 10, detonator 2, perk slots 3, killstreak slots 3, range table §1 | Every one is set explicitly in the file, so the run file shows the full tuning surface. |
| squad_rusher | identity | "SandViper_07" [DSRT], RUSHER | The squad from the §6 walkthrough. |
| squad_rusher | deck (18) | Point Man 3, Breacher 3, Flanker 2, Rifleman 2, Shieldman 1, Combat Medic 1, Callout 1, Flank Route 2, Breach and Clear 1, Ammo Resupply 1, Tripwire Charge 1 | SMG/Shotgun at Close range, per §7. |
| squad_rusher | loadout | wasp_9 + extended_mag, sidearm, frag, flashbang, no perks, killstreaks recon_drone, mortar_barrage | Wasp-9 makes the Rusher feel different from the start. **Fallback:** if p04/p07 can't do two Rotations for the AI, switch it to kestrel_ar7 (data-only change). |
| squad_rusher | AI weights | dealt 1.5, taken 0.5, zone 2.0, deny streak 3.0; second best 0.15; preferred CLOSE | §7 base is 1/1/2/3. A Rusher trades aggressively. |
| squad_anchor | identity | "Bulwark_Nine" [QUAY], ANCHOR | Original name. |
| squad_anchor | deck (18) | Gunner 3, Shieldman 2, Rifleman 3, Combat Medic 2, Demolitions Expert 2, Marksman 1, Hold the Line 2, Suppressing Fire 2, Comms Relay 1 | LMG with sustain, contests Mid, per §7. No Holder: the only Holder is an elite, which the Rival gets. |
| squad_anchor | loadout | kestrel_ar7 + foregrip, sidearm, frag, flashbang, no perks, killstreaks recon_drone, sentry_turret | The Sentry fits a defensive squad. |
| squad_anchor | AI weights | dealt 1.0, taken 1.5, zone 3.0, deny 3.0; second best 0.10; preferred_ranges [] | It values zones over trades. Its preferred zone is positional (see Format gaps #2). |
| squad_black_meridian | identity | "Meridian_Six" [BKMRD], ANCHOR | The plan's Rival "BLACK MERIDIAN" squad: Anchor plus elites. Original name. |
| squad_black_meridian | deck (20) | Anvil 1, Wren 1, Gunner 2, Shieldman 2, Marksman 2, Breacher 1, Combat Medic 2, Demolitions Expert 1, Rifleman 2, Hold the Line 1, Suppressing Fire 1, Breach and Clear 1, Comms Relay 1, Callout 1, Ammo Resupply 1 | Per Ruling 11, its extra threat comes from the elites. |
| squad_black_meridian | loadout | kestrel_ar7 + foregrip, ceramic_lining; perks grit, objective_focus; killstreaks recon_drone, mortar_barrage, sentry_turret | The player has up to 2 attachments and 1–2 perks by match 5, so this keeps the Rival on par. |
| squad_black_meridian | AI weights | dealt 1.2, taken 1.2, zone 2.5, deny 3.0; second best 0.05 | A sharper and more consistent Rival. |
| squad_tutorial | all | "TrainingBot_01" [DRILL], deck Rifleman 8, Point Man 3, Marksman 2, Combat Medic 2 (15), kestrel, no attachments, perks or killstreaks, second best 0.0 | The scripted squad for p15. It isn't in the run. Its plays are scripted by p15 (see Format gaps #1). |
| port_vasel | zones | Container Stacks CLOSE · Crane Yard LONG · Loading Offices MID | §5. |

## Format gaps
These are things the current `scripts/data` format can't express. I didn't change any scripts.

1. **No tutorial script resource.** `tutorial_script.tres` (planned in milestone §5) has no class. CardDB would report any other `.tres` in `data/` as `unknown_type`, so I couldn't author one. What p15 needs (proposal: a `TutorialScript` resource plus `TutorialStep` sub-resources, added to CardDB's data classes):
   - `squad` → `squad_tutorial`, `map` → `port_vasel`, `mode` ZONE_CONTROL, `round_cap` override (suggested 4), player kit = run starter loadout.
   - **Stacked player draws** (ordered card list instead of a shuffle) and **scripted enemy plays per round** (card + zone, and Operator zone), since `SquadData` only has a shuffled deck and AI weights.
   - Per-step data: `step` index (for `tutorial_step`), prompt text, highlight target (hand card / lane / READY / streak arc / Streak Tray), the action that advances it, and whether input is restricted to that action.
   - A way to **grant streak** or **force a Recon Drone earn** at a step, or a stacked scenario that guarantees 2 eliminations by round 2.
   - Proposed script: R1 place the Operator in Mid, deploy a Rifleman Left (enemy: 1 Rifleman Left) → firefight shows line order, damage and an elimination → streak 1. R2 Point Man (First Shot) Right vs a Marksman → elimination → streak 2 → Recon Drone earned → call it in R3 to show face-up enemy deployments and red dots → win on points. Skippable at any step.
2. **Positional AI preference.** `preferred_ranges` only expresses range tags. §7's Anchor "contests Mid" means the centre zone. On Port Vasel that's Crane Yard (LONG), which a range preference can't target. Needed: a `preferred_zones` field (left/mid/right), or p07 maps ANCHOR to the centre zone in code. For now `squad_anchor` and `squad_black_meridian` have an empty `preferred_ranges`.
3. **Callout / NEXT_FRIENDLY_ARRIVING timing.** No trigger means "applies to arrivals at this Reveal, including cards played earlier this Deploy". I used IMMEDIATE, and p04 must interpret NEXT_FRIENDLY_ARRIVING as "first friendly **unit card** arriving in that zone at this round's Reveal (not the Operator)", wasted if none.
4. **Threat Level modifiers (§10)** have no field. Threat Levels are out of the prototype (meta-progression), and per-squad `second_best_chance` covers AI variance for now.
5. **Bracket scaling covers units and the Operator?** `RunMatchData.enemy_armor_bonus` says "every enemy unit". Ruling 11 adds the enemy **Operator**. p04/p10 must apply it to the Operator too, or add a field.
6. **Streak sources for Equipment / On Down.** There's no per-effect flag for "counts for streak". The engine decides by source type. See the tripwire_charge row above for the open ruling.
7. **Reward offers without duplicates.** Copies in `reward_pool` act as weights. There's no field saying an offer must show distinct designs. Proposal: always distinct (engine rule).

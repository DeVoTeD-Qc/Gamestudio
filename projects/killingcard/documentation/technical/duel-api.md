# KillingCard Duel mode: public API for the screens (kc-duel-impl -> kc-duel-ui)

*Owner: Mechanics Developer Agent (kc-duel-impl). Readers: UI/UX agent (kc-duel-ui), QA. Spec: `documentation/design/duel-mode.md` plus the studio head's decisions D1-D5 (below).*
*Status: **implemented** (kc-duel-impl). Covered by `tests/test_duel_rules.gd`, `tests/test_duel_profile.gd`, `tests/test_duel_match.gd`.*

## 0. Decisions this API follows (studio head)
| | Decision | Where it lives |
|---|---|---|
| D1 | The hero is the Operator in its own command slot, placeable from round 1 (free in round 1, 1 Supply to respawn). Never a deck card. | The campaign's Operator rules (`RunConfig.operator_cost`, `operator_free_round1`); `SideSetup.primary` + `operator_kit = true` |
| D2 | Exactly 10 picks, each exactly 2 copies (20 cards); at least 5 unit picks, at most 1 Elite pick, at most 3 Field picks; never tokens, boss cards or Standard Issue | `data/duel/duel_config.tres` (`DuelConfig`), checked by `DuelRules.validate` |
| D3 | Units and tactics open from the start; Fields and Elites unlock when found in a campaign run; the 4 presets and all 4 heroes always playable | `DuelCollection` (+ `found_cards` in the run profile) |
| D4 | ONE Operator stat set for both modes | Duel reads the campaign's `data/loadout/<hero>.tres` directly. **The final numbers are a data-only change** to those files (`operator_firepower`, `operator_armor`, the ability's effect `amount`); no Duel override table exists |
| D5 | The player picks a Doctrine trait for the Duel deck (or None). **Duel Doctrine starts a set, never completes one** (duel-mode.md §12.3): while exactly one member of the trait is in play it counts as two. It needs **4 picks wearing the trait** | `DuelDeck.doctrine_trait`; `DuelConfig.doctrine_min_trait_picks = 4`; `SideSetup.doctrine` + `SideSetup.doctrine_starts_only = true` (set by `DuelRules.side_setup`; the campaign keeps false = +1 while any member is in play); `SynergyRules.trait_counts / compute(..., doctrine_starts_only)`, used by MatchState, RevealFlags and the AI (`AiView.my_doctrine_starts_only`) |

Implementation map: data `scripts/data/duel_config.gd`, `scripts/data/duel_deck.gd`, `data/duel/duel_config.tres`, `data/duel/presets/*.tres`; rules `scripts/rules/duel_rules.gd`; run / profile `scripts/run/duel_collection.gd`, `scripts/run/duel_profile.gd`, `scripts/run/duel_match.gd`, `scripts/run/run_profile.gd` (profile v2); AI `scripts/ai/ai_personality.gd` (`for_duel_tier`), `scripts/ai/ai_player.gd` (`for_duel_tier`); autoload `autoload/duel_state.gd` (**`DuelState`**); `autoload/card_db.gd` loads the Duel data (`CardDB.get_duel_config()`, `CardDB.get_duel_deck(id)`); `autoload/run_state.gd` marks campaign cards found.

**Note for kc-duel-ui (2026-11-10):** the rules API is **not** under `scripts/duel/` (the spec's §9.1 guess): use the `DuelState` autoload; the classes are global (`class_name`) in the folders above. Preset ids are `spearhead`, `overwatch`, `iron_wall`, `hollow_ranks` (no `preset_` prefix). A deck row is `{card_id, art_id}` (not `{card, art}`), the hero field is `hero_id`, the Doctrine field is `doctrine_trait`. `DuelDeck.to_dict()` / `from_dict()` convert to and from plain Dictionaries if the screens keep Dictionary drafts.

Rules of the road (same as run-v2-api):
- Screens call the **`DuelState`** autoload and read the **`DuelMatch`** / **`MatchState`** they are handed. They never write fields directly (a `DuelDeck` draft is the exception: edit it with its own methods, then `DuelState.save_deck`).
- Actions return `""` (ok) or a short English reason, or a result Dictionary with `ok` + `reason`. Views are plain Dictionaries (JSON-safe values, `StringName` ids).
- Every view carries the text an inspector (long press / right click) needs. Studio rule: everything is inspectable, locked cards included.

---

## 1. Deck data (`DuelDeck`, `scripts/data/duel_deck.gd`)
A `Resource`. Presets are `.tres` files under `data/duel/presets/`; player decks are saved as Dictionaries in the profile (§4) and loaded back with `DuelDeck.from_dict`.

| Field | Type | Meaning |
|---|---|---|
| `id` | StringName | preset: `spearhead`, `overwatch`, `iron_wall`, `hollow_ranks`; saved deck: `deck_<n>` (given by `save_deck`); a new draft: `&""` |
| `display_name` | String | at most `DuelConfig.name_max_length` (20) characters (`save_deck` trims) |
| `hero_id` | StringName | an Operator id: `kestrel_ar7`, `longreach_338`, `wasp_9`, `bastion_60` (`&""` = not picked yet) |
| `picks` | Array[Dictionary] | up to 10 rows `{card_id: StringName, art_id: StringName}`. One row per card (a pick = 2 copies). `art_id` `&""` = the chassis default art. The art gives both copies their trait (`ArtTraits.trait_of`) |
| `doctrine_trait` | StringName | D5: `&""` (no Doctrine) or one of `&"vanguard"`, `&"specops"`, `&"heavy"`, `&"undead"` |
| `plan` | String | presets: the one-line plan on the deck tile |
| `preset` | bool | true for the 4 presets (read-only: copy to edit) |
| `created`, `edited` | int | unix seconds (saved decks) |

Methods (all return `""` or a reason, unless noted):
| Call | Notes |
|---|---|
| `add_pick(card_id, art_id := &"") -> String` | refuses a preset ("Preset: copy to edit"), a full deck ("10/10: remove a pick first"), a card already picked ("Already in your deck (x2)"), an unknown card. It does **not** refuse locked or over-limit cards: the validator shows those as red lines (the spec lets you build first and fix after) |
| `remove_pick(card_id) -> bool` | |
| `set_art(card_id, art_id) -> String` | refuses an art that isn't one of the card's arts |
| `set_hero(hero_id) -> String` | |
| `set_doctrine(trait) -> String` | `&""` clears it |
| `rename(name) -> String` | trims to 20 characters |
| `has_pick(card_id) -> bool`, `pick_count() -> int`, `pick_index(card_id) -> int` | |
| `trait_of_pick(i) -> StringName` | the trait both copies of pick `i` wear (`&""` = none) |
| `copy() -> DuelDeck` | a deep copy with `preset = false`, `id = &""` (for COPY / "start from a preset") |
| `to_dict() -> Dictionary` / `DuelDeck.from_dict(d) -> DuelDeck` | the save format: `{id, name, hero_id, picks: [{card_id, art_id}], doctrine_trait, created, edited}` (Strings only) |

## 2. Validation (`DuelState.validate(deck, opts := {}) -> Dictionary`)
Same as `DuelRules.validate(deck, config, collection)`. Never throws; any deck (even empty) gets a result.
```
{
  ok: bool,                 # no red line: PLAY may start (green chip READY)
  status: "READY" | "2 PICKS TO GO" | "NEEDS ATTENTION",
  status_text: String,      # ok: "READY: 20 cards, hero Bastion-60"; else the first red line's text
  errors: [LINE, ...],      # RED: block PLAY. Show with a cross + words (never colour alone)
  warnings: [LINE, ...],    # AMBER: advice only. Show with "!" + words
  summary: {
    picks: int, picks_max: 10, cards: int (picks x 2),
    units: int, tactics: int, fields: int, elites: int,      # pick counts
    unit_min: 5, elite_max: 1, field_max: 3,
    curve: [int x5],         # COPIES at cost <=1, 2, 3, 4, 5+ (the curve chart's bars)
    traits: {trait: copies}, # unit + Field copies per trait (the "Heavy 10 . Vanguard 2" line)
    hero_id, hero_name, doctrine_trait, doctrine_name,
  },
}
LINE = {code: StringName, text: String, fix_filter: Dictionary, data: Dictionary}
```
`fix_filter` is what a tap on the line should filter the grid to: any of `{type: "unit"|"tactic"|"field", elite: true, cost_max: int, cost_min: int, card_id: StringName, hero: true, doctrine: true}` (`{}` = no filter).

Red codes (`DuelRules.E_*`):
| code | text (example) | fix_filter |
|---|---|---|
| `picks_short` | "Pick 2 more cards (8/10)" | `{}` |
| `picks_over` | "Too many picks (11/10): remove 1" | `{}` |
| `duplicate_pick` | "Rifleman is picked twice: one pick per card" | `{card_id}` |
| `unknown_card` | "An unknown card (old_id) is in this deck" | `{card_id}` |
| `not_in_pool` | "Sentry can't be in a Duel deck" (tokens, boss cards, Standard Issue) | `{card_id}` |
| `locked_card` | "Mortar Pit isn't in your collection: find it in the campaign" | `{card_id}` |
| `unit_min` | "At least 5 unit picks (4/5)" | `{type: "unit"}` |
| `elite_max` | "Only 1 Elite ★ pick (2/1): remove Commander or Ace" (the cards' display names) | `{elite: true}` |
| `field_max` | "At most 3 Field picks (4/3)" | `{type: "field"}` |
| `no_hero` | "Pick a hero" | `{hero: true}` |
| `unknown_hero` | "Unknown hero (x): pick a hero" | `{hero: true}` |
| `bad_art` | "Rifleman: that art isn't one of its arts" | `{card_id}` |
| `doctrine_invalid` | "Doctrine must be Vanguard, Spec Ops, Heavy or Undead" | `{doctrine: true}` |
| `doctrine_required` | "Pick a Doctrine trait" (only when `DuelConfig.doctrine_required`) | `{doctrine: true}` |
| `doctrine_rule` | "Doctrine Undead needs 4 Undead picks (3/4)" (§12.3: the Doctrine trait must be worn by `doctrine_min_trait_picks` picks) | `{doctrine: true}` |

Amber codes (`DuelRules.W_*`):
| code | text | fix_filter |
|---|---|---|
| `low_curve` | "Round 1 gives 1 Supply. You may have nothing to play." (fewer than 2 picks costing 1 or less) | `{cost_max: 1}` |
| `heavy_curve` | "Heavy curve: these land from round 4." (4+ picks costing 4+) | `{cost_min: 4}` |
| `no_set` | "No set: 2 units of one trait give a bonus." | `{type: "unit"}` |
| `no_tactic` | "No tactics: you can't answer a column in one round." | `{type: "tactic"}` |
| `doctrine_unused` | "Doctrine Heavy: none of your picks wear Heavy." | `{doctrine: true}` |

`opts`: `{open_pool: true}` skips the lock check (Pass & Play "Open pool for this match"). A **preset** never gets `locked_card` (loaners, D3). A **copy** of a preset does.

## 3. Card pool and heroes
### `DuelState.card_pool(opts := {}) -> Array[Dictionary]`
Every Duel-eligible card (30 today: 11 units, 2 Elites, 9 tactics, 8 Fields), sorted by cost then name:
```
{id, name, type: "unit"|"tactic"|"field", type_label: "Unit"|"Tactic"|"Field", cost, elite: bool,
 fp, armor, weapon: "AR"|... (units), keywords: [String], text: String,
 trait: StringName (default trait), trait_name,
 trait_options: ArtTraits.options(card) rows [{trait, name, family, family_name, default_art, arts}],
 locked: bool, unlock_text: String ("Find it in the campaign" | ""), in_presets: [preset ids]}
```
`opts`: `{open_pool: true}` (nothing locked), `{include_locked: false}` (drop locked rows; default true: the spec shows them dimmed and inspectable).
`DuelState.is_card_unlocked(card_id) -> bool`.

### `DuelState.heroes() -> Array[Dictionary]`
The 4 heroes, Kestrel, Longreach, Wasp-9, Bastion-60: the same row shape as `RunState.operator_choices()` (`id, name, weapon, fp, armor, keywords, passive_name, passive_text, ability_id, ability_name, ability_text`) plus `plays_like: String` and `unlocked: true` (D3: always playable). `fp` / `armor` are the shared numbers (D4).

### Presets
### Doctrine text (D5)
`DuelState.doctrine_text(trait) -> String`: the player-facing Doctrine text for the builder's Doctrine strip and the inspect views. `&""` gives "No Doctrine: your trait counts are what your picks wear."; a trait gives "Doctrine: your first Heavy in play already turns on the Heavy 2-set. The 3-set still needs 3 Heavy. Needs 4 Heavy picks in your deck. 2 Heavy: ... 3 Heavy: ..." (the set lines come from `SynergyRules.TIER_TEXT`); not a trait gives `""`. With `DuelConfig.doctrine_enabled = false` it says Doctrine is off. Same as `DuelRules.doctrine_text(trait, config)`.

### Presets
- `DuelState.presets() -> Array[Dictionary]`: the 4 deck views (§4 shape) with `preset: true`, `plan`, `trait` (main trait).
- `DuelState.preset(id) -> DuelDeck`: the preset resource (read-only; call `.copy()` to edit).

## 4. Player decks (saved in the profile)
Up to `DuelState.MAX_DECKS` (8) per profile, in `Settings.run_profile.duel_decks` (profile v2, §7).
| Call | Returns |
|---|---|
| `DuelState.decks() -> Array[Dictionary]` | deck views in slot order: `{id, name, hero_id, hero_name, preset: false, picks: [{card_id, art_id, trait, name, cost, type}], doctrine_trait, trait (main trait), curve, status, status_text, ok, created, edited}` |
| `DuelState.deck(id) -> DuelDeck` | a saved deck: a fresh editable copy (edit it, then `save_deck`); a preset: the read-only preset resource (`.copy()` it to edit); null if unknown |
| `DuelState.new_deck(from_preset := &"", hero_id := &"") -> DuelDeck` | an unsaved draft ("start empty" / "start from a preset"); named "<main trait> · <hero>" once it has picks (`DuelState.default_name(deck)`) |
| `DuelState.save_deck(deck) -> Dictionary` | `{ok, id, reason}`. New decks get an id; refuses a preset and a 9th deck ("8 decks saved: delete one first"). Saves even an incomplete or illegal deck (the tile shows "2 PICKS TO GO" / the red line) |
| `DuelState.copy_deck(id) -> Dictionary` | `{ok, id, reason, deck}`: saves a copy ("<name> copy") |
| `DuelState.delete_deck(id) -> bool` | |
| `DuelState.slots_left() -> int` | |
| `DuelState.default_name(deck) -> String` | |
Every change saves the profile and emits `DuelState.decks_changed`.

## 5. Starting a duel
Both return `{ok: bool, reason: String, match: DuelMatch}` (the reason is also kept in `DuelState.last_error`). `reason` is the first red line of an illegal deck ("Player 2: Pick a hero"). The match is also kept as `DuelState.current` for the match scene to take with `DuelState.take_current() -> DuelMatch`, which **clears `current`** (the match is handed over once; a second call returns null).

- **`DuelState.start_vs_ai(deck: DuelDeck, opponent: StringName, tier: StringName, seed := -1)`**
  `opponent` = a preset id or `&"random"` (a seeded pick among the 4). `tier` = `&"recruit"`, `&"regular"`, `&"veteran"` (`DuelState.TIERS`; `DuelState.tier_views()` gives `[{id, name, text}]` with the spec's lines, e.g. "Recruit: its cards have −1 Armor and it makes mistakes"). The human is side 0 (`MatchState.PLAYER`), the AI side 1.
- **`DuelState.start_hot_seat(deck_a, deck_b, names := ["Player 1", "Player 2"], opts := {})`**
  `opts`: `{open_pool: bool, seed: int}`. A seeded coin flip decides who is seat 0 (`match.seat_of_player(0|1)`, `match.player_of_side(side)`). Both decks are validated.

What a Duel match is (`DuelRules.match_config`): the campaign economy (`data/run_config.tres`: round N gives N Supply, cap 7; 4 + 1 cards in round 1, a free mulligan, 1 a round, hand cap 7), deck size 20, **Zone Control to 6** (round cap 8, overtime to 10), the map Port Vasel, **no Terrain, no perks, no attachments, no weapon levels**, the 3 starter killstreaks (Recon Drone, Mortar Barrage, Attack Helo) on both sides, the Operator kit on (passive + once-per-match ability), Doctrine = the deck's `doctrine_trait` (D5). Recruit's side has `armor_bonus = -1` (`match.armor_bonus(side)`).
**The Recruit marker:** `MatchSnapshot.unit_entry()` and the Operator entry carry `armor_mod` (-1) and `armor_mod_text` ("Recruit handicap: -1 Armor on every unit and the Operator of this side (already in its Armor).") for a side whose `armor_bonus` is below 0 (the Recruit). `BannerView` draws a green "−1" chip on top of the Armor plate when `armor_mod < 0` (`BannerView.armor_mod_rect`), and the unit and Operator inspectors (long press / right click) add the line to their status.

## 6. The match (`DuelMatch`, `scripts/run/duel_match.gd`)
A `RefCounted` that owns one `MatchState` (`match.state`) and who plays which side. The UI keeps using `MatchState` for plays (`submit`, `can_submit`, `legal_targets`, `undo_last`, `mulligan`) and its existing playback split (`reveal()`, `firefight()`, `score()`), with these Duel rules on top. In hot seat, send plays, mulligans and undos through `DuelMatch.submit` / `mulligan` / `undo_last` (they refuse the side whose turn it isn't); read-only checks (`can_submit`, `legal_targets`, `check_use`) can go straight to `state`.

| Member | Notes |
|---|---|
| `kind: StringName` | `&"ai"` or `&"hot_seat"` |
| `state: MatchState` | not started until `start()` |
| `decks: Array[DuelDeck]`, `names: Array[String]` | per side |
| `humans: Array[bool]` | `[true, false]` vs AI, `[true, true]` hot seat |
| `tier: StringName` | vs AI only |
| `ai: AiPlayer` | vs AI only (side 1) |
| `active_side: int` | the side whose private Deploy is open (`-1` while a cover is up, or after both are ready) |
| `cover_side: int` | the side the cover screen is waiting for (`-1` = no cover) |
| `start()` | starts the match and opens round 1 (vs AI: the AI commits first, then the human's Deploy opens; hot seat: the cover for the first deployer) |
| `first_deployer(round := state.round_number) -> int` | hot seat: the seat-0 side in round 1, then it **alternates every round** |
| `accept_cover(side) -> String` | the player tapped "only I can see the screen": `active_side = side`, emits `deploy_started(side)`. Refuses another side |
| `finish_deploy(side) -> String` | READY for this side (`state.set_ready`). Hot seat: if the other side hasn't deployed, its cover comes up (`cover_needed`); when both are ready, `round_ready` fires |
| `undo_last(side) -> Dictionary` | `MatchState.undo_last` with the same guard |
| `forfeit(side) -> bool` | `side` concedes; the other side wins with reason `&"forfeit"`; emits `match_ended` |
| `submit(side, intent) -> Dictionary` | `MatchState.submit` with a guard: in hot seat only `active_side` may play (`{ok: false, code: &"not_your_turn", reason: "Wait for your turn"}`) |
| `mulligan(side, uids) -> Dictionary` | the same guard; mulligans happen in each player's first private Deploy |
| `can_view_private(side) -> bool` | true when `side`'s hand, deck order, face-down plays, red dots and intel may be on screen: vs AI always for the human side; hot seat only while `active_side == side` |
| `viewer() -> int` | the side the board should be drawn for right now (vs AI: 0; hot seat: `active_side`, else the last side that deployed, public info only while the cover is up) |
| `visible_events(events, viewer) -> Array` | drops events whose `private_to` is the other side |
| `resolve_round() -> Array[Dictionary]` | Reveal + Firefight + Score in one call (for tests / tools; the UI may call `state.reveal()`, `state.firefight()`, `state.score()` itself, then `round_done()`) |
| `round_done()` | after the round played: if the match ended, emits `match_ended(result())`; else `state.begin_round()` and opens the next Deploy (AI commits, or the next cover) |
| `result() -> Dictionary` | §6.2 |
| `seat_of_player(i)`, `player_of_side(side)`, `armor_bonus(side)` | |

Signals:
- `cover_needed(side: int, player_name: String)`: show the cover ("PLAYER 2 — take the device. Tap when only you can see the screen."). Board: public info only.
- `deploy_started(side: int)`: that side's private Deploy is open (show its hand, its mulligan in round 1).
- `side_ready(side: int)`: the side tapped READY (show "3 orders placed" for it, never which).
- `round_ready()`: both sides are ready; play Reveal / Firefight / Score for both, then call `round_done()`.
- `match_ended(result: Dictionary)`.

Flow, hot seat, each round: `cover_needed(A)` → `accept_cover(A)` → `deploy_started(A)` → plays → `finish_deploy(A)` → `side_ready(A)`, `cover_needed(B)` → `accept_cover(B)` → ... → `finish_deploy(B)` → `side_ready(B)`, `round_ready()` → playback → `round_done()`. A = `first_deployer(round)`.
Flow, vs AI: `start()`/`round_done()` → the AI commits and is ready → `deploy_started(0)` → plays → `finish_deploy(0)` → `round_ready()` → playback → `round_done()`.

### 6.2 `DuelMatch.result() -> Dictionary`
```
{kind, tier, ended: bool, winner_side: 0|1|-1 (draw), result: &"player"|&"enemy"|&"draw" (MatchState.result),
 reason: StringName (ModeRules outcome reason), rounds: int, scores: [int, int],
 names: [String, String], decks: [deck id, deck id], deck_names: [..], heroes: [hero id, hero id],
 human_won: bool (vs AI), winner_name: String}
```

## 7. Results and records (`DuelState.finish(match) -> Dictionary`)
Call once when `match_ended` fired (or for a forfeit after `state` ended). Duel gives **records and cosmetics only** (never cards, tickets, REQ or a campaign unlock).
Returns `{ok, reason, result: <6.2>, records: <records()>, new_cosmetics: [{kind: &"duelist_frame"|&"veteran_stamp"|&"veteran_all", id, name, text}]}`.
- vs AI: a win / loss / draw for the human's hero and for the opponent preset at that tier; a win with a hero gives its **Duelist banner frame** (once); a Veteran win against a preset gives its **map stamp**; all 4 stamps give `veteran_all`.
- Hot seat: counts the match (`hot_seat_games`) and each hero's `games`; no wins or cosmetics (both players share the profile).
- `DuelState.records() -> {heroes: {hero_id: {w, l, d}}, vs_ai: {preset_id: {tier: {w, l, d}}}, hot_seat_games: int, duelist_frames: [hero ids], veteran_stamps: [preset ids]}`.
- Signal `DuelState.records_changed`.

## 8. Profile (save) v2
`Settings.run_profile` is now versioned: `RunProfile.PROFILE_VERSION = 2`. A v1 profile (no `version`) loads with every old value kept plus `found_cards: []` (back-filled once from `Settings.found_arts` and the current run's deck), `duel_decks: []`, `duel_records: {}`. A saved deck that no longer loads (unknown card, bad art) keeps its slot and shows the red line ("needs attention"); unknown arts fall back to the default art on load.
`found_cards` (D3): `RunState.note_found_cards()` (called on every run change) adds every card id in the run deck and in every offer shown (Supply Drop, Elite Cache, Salvage) as the run changes.

## 9. Applying the final numbers (D4, D5)
- **Operator stats (D4):** edit `data/loadout/kestrel_ar7.tres`, `longreach_338.tres`, `wasp_9.tres`, `bastion_60.tres` (`operator_firepower`, `operator_armor`) and the abilities' `effects[0].amount` (`ab_marked_shot.tres` ...). Both modes read these; nothing in Duel code changes. `tests/test_duel_rules.gd::test_duel_heroes_use_campaign_stats` checks that the Duel side's Operator body equals the loadout file.
- **Applied (kc-duel-tune, duel-mode.md §12.6):** Wasp-9 2/9, Bastion-60 2/8, Marked Shot 2 damage (both modes); Undead 2-set heal 1 + Cover 1, 3-set +1 FP (both modes).
- **Doctrine (D5, §12.3):** `DuelConfig.doctrine_enabled` true, `doctrine_required` false (None allowed), `doctrine_min_trait_picks` **4** (red `doctrine_rule` under it). The presets' Doctrines: Spearhead Vanguard, Overwatch Spec Ops, Iron Wall Heavy, Hollow Ranks Undead. The builder's Doctrine picker disables traits with fewer than 4 picks ("needs 4 picks (n/4)") and a new deck pre-selects its most-picked trait once it has 4 picks, until the player chooses (None included). Further rules that need code go in `DuelRules._doctrine_checks`.
- **Presets (§12.4):** Overwatch Smoke Screen → Ammo Resupply; Hollow Ranks Sabotage → Listening Post.

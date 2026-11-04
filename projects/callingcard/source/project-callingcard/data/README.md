# Banner Wall data format (for the designer)

All game content is Godot `.tres` Resources under `res://data/`. `CardDB` loads every `.tres` in this
folder and its subfolders at start-up, indexes it by `id` and checks it. Every problem is printed as
`CardDB: ERROR [code] file (id) field: message` and the tests fail, so broken data never reaches a
playtest unnoticed. **Warnings** (`WARNING [...]`) mark content that is still incomplete (a set with
one card, no loaner lineup yet, a Cipher glyph no card carries); they don't fail the load, but cc03
should finish with none.

| Folder / file | Class (script in `scripts/data/`) | One file per |
|---|---|---|
| `cards/` | `CardData` (`card_data.gd`) | card |
| `sets/` | `SetData` (`set_data.gd`) | set = album page |
| `unlocks/` | `UnlockGoal` (`unlock_goal.gd`) | demo unlock goal |
| `rivals/` | `RivalData` (`rival_data.gd`) | AI rival with its fixed lineup |
| `triptychs/` | `TriptychData` (`triptych_data.gd`) | hidden 3-card combination |
| `dossiers/` | `DossierData` (`dossier_data.gd`), placements are `DossierPlacement` | puzzle |
| `balance.tres` | `BalanceConfig` (`balance_config.gd`), id `balance` | all tunable numbers (exactly one file) |

Samples to copy: `cards/graveyard_shift.tres` (Challenge, Clearance 1, Cipher glyph 1),
`cards/neon_rain.tres` (Mastery, Clearance 2), `cards/chrome_tiger.tres` (store card),
`sets/night_shift.tres`, `sets/showcase.tres`, `unlocks/unlock_win_streak_3.tres`, `balance.tres`.
There are no rival, Triptych or Dossier samples yet because they need more cards; the fields are below
and `tests/test_data.gd` (`_valid_set()`) builds a full example of each in code.

## How to add a card (or anything else)
1. In the Godot editor: FileSystem → right-click `data/cards/` → **New Resource…** → `CardData`
   (or duplicate a sample with Ctrl+D). Name the file after the id: `last_train.tres`.
2. Fill the fields in the Inspector. Drag `.tres` files into reference slots (`card_set`, `unlock_goal`, lineups).
3. Run the tests: `godot --headless --path . -s res://tests/run_tests.gd -- --only=data`.
   `test_project_data_is_valid` lists every problem.

Editing a `.tres` as text works too, but enums are stored as numbers (tables below). Enum values are
only ever appended in `data_enums.gd`, never reordered.

## Common rules
- `id`: unique across **all** data, lowercase `snake_case` (`a-z 0-9 _`, starts with a letter). Saves and logs use it.
- One-line text fields have a length limit (listed per field). `display_name` is required everywhere.
- References must point at `.tres` files **inside `data/`**. A file elsewhere, an empty slot, or a file that doesn't load is an error.
- Lists never repeat an entry (a lineup or Triptych can't hold the same card twice).
- Rivals and Dossiers are named by **id** inside unlock goals (`target_id`), not dragged in. That keeps
  files from referencing each other in a loop (card → goal → rival → card).

## CardData (spec §3, §6)
| Field | Meaning / allowed values |
|---|---|
| `display_name` | Required, max 24 characters. |
| `card_set` | The card's set (`sets/*.tres`). Required. |
| `album_order` | Position on the set's album page, 1–10, unique within the set. |
| `top`, `side`, `bottom` | 1–9 each (`stat_min`/`stat_max` in balance). |
| `clearance` | 1 Issue, 2 Merit, 3 Distinction, 4 Legend. |
| **budget rule** | `top + side + bottom` must equal the Clearance budget in `balance.tres` (13 / 15 / 17 / 19). Error `budget_mismatch`. |
| `origin` | `CHALLENGE`(0) Steady, `MASTERY`(1) Veteran, `EVENT`(2) Ambush, `PRESTIGE`(3) Reclaim, `RANKED`(4) Clutch, `SECRET`(5) Cipher, `SHOWCASE`(6) no trait. The trait always comes from the origin; there is no separate trait field. |
| `is_store` | Store / bundle card. **Store rule** (error `store_rule`): a store card must be origin `SHOWCASE`, Clearance 1 (so no trait), and sit in a `SHOWCASE` set; a `SHOWCASE` origin card must have `is_store` on; a non-store card can't be in a `SHOWCASE` set. |
| `signature_eligible` | On by default. Off = it can never be marked as a Signature. |
| `how_earned` | "How it's earned" line (live-game flavor, original), required, max 80 characters. |
| `art_key` | Key the art kit draws the poster from (use the card id). Required. |
| `art_seed` | Seed for the procedural poster (any int). |
| `art_brief` | The original art brief (not shown in game). |
| `cipher_glyph` | 0 none, or 1–4. Only on cards of `STANDARD` sets; each glyph on one card only. |
| `starts_owned` | Owned when a new demo save starts. |
| `unlock_goal` | Required when `starts_owned` is off; must be empty when it's on. |

## SetData (album page)
| Field | Meaning |
|---|---|
| `kind` | `STANDARD`(0), `CIPHER`(1) (the Secret cards), `SHOWCASE`(2) (store cards only). |
| `number` | Album page order 1–20, unique. Also the "set numbering" that hints the Cipher Lock order. |
| `palette_key` | Palette the art kit uses (art kit set ids: `night_shift`, `whiteout`, `signal_fire`, `old_guard`, `cipher`, `showcase`). Required. |
| `tagline` | One line for the page header, max 80. |
| `completion_title` | Title for owning the full set (e.g. "Night Owl"). Required for `STANDARD` sets, max 32. |
| size | A set needs 2–6 cards (`set_size_min/max`). More than 6 is an error; fewer than 2 is a warning while content is authored. |

## UnlockGoal (spec §6 "Demo start", §7)
| `kind` | `target_count` | `target_id` |
|---|---|---|
| `WIN_STREAK`(0) | duels in a row (≥ 1) | — |
| `CAPTURES_TOTAL`(1) | cards captured in total | — |
| `WINS_TOTAL`(2) | duels won in total | — |
| `BEAT_RIVAL`(3) | — | rival id (e.g. `warden`) |
| `BEAT_RIVAL_NO_LEGEND`(4) | — | rival id; the lineup must hold no Clearance 4 card |
| `DOSSIER_CLEAR`(5) | — | Dossier id |
| `CIPHER_LOCK`(6) | — | — |

`description` is the album line under the silhouette ("Win 3 duels in a row"), max 60 characters.
Fields a kind doesn't use must stay 0 / empty (error otherwise).

## RivalData (spec §7)
| Field | Meaning |
|---|---|
| `difficulty` | `EASY`(0) Quartermaster, `NORMAL`(1) Archivist, `HARD`(2) Warden. |
| `tagline`, `art_key` | Rivals screen line (max 80) and portrait key (required). |
| `lineup` | Exactly `lineup_size` (5) distinct cards. **Lineup rule** (error `lineup_rule`): total Clearance ≤ `clearance_cap` (12), at most `max_legends` (1) Legend. |
| `signature` | One card of the lineup, `signature_eligible` on. |
| `best_capture_chance` | 0–1. Quartermaster 0.5 (takes the best capture half the time). |
| `lookahead_plies` | 0–2. Archivist 1 (greedy), Warden 2. |
| `signature_safety_weight` | 0–10. Warden > 0 (protects its Signature). |

## TriptychData (spec §5.1)
`cards` exactly 3 distinct cards · `hint` (required, max 80) · `reward_title` (required, max 32) ·
`reward_frame` optional frame id (e.g. `gold_cipher`) · `panorama_key` (required, the reveal strip).

## DossierData (spec §5.2)
| Field | Meaning |
|---|---|
| `number` | 1–9, unique (D1..D5). |
| `teaches` | The rule it teaches, required, max 60. `briefing` (multi-line) and `hint` (max 100) are shown in game. |
| `board` | Pre-placed cards: `DossierPlacement` {`slot`, `card`, `side` `PLAYER`(0)/`RIVAL`(1), `face_down` (Ambush cards only), `is_signature`}. |
| `player_hand` | The fixed hand, 1–5 distinct cards. `hand_signature`: optional hand card that is the player's Signature. |
| `rival_replies` | Optional scripted rival placements (side `RIVAL`), made in order after each player placement. |
| `goal` | `CAPTURE_N`(0) (`goal_count` captures), `WIN_IN_PLACEMENTS`(1), `CAPTURE_N_WITH_SPRING`(2) (`goal_count`; needs an Ambush in hand), `CAPTURE_SIGNATURE_AND_WIN`(3) (needs a rival `is_signature`), `WIN_BY_COPYING_TRAIT`(4) (needs a Cipher in hand). Unused `goal_count` stays 0. |
| `max_placements` | Placements allowed, 1 to hand size (`WIN_IN_PLACEMENTS`: exactly this many). |
| `solution` | Required. A known solution: the player's placements in order (side `PLAYER`, cards from the hand, free slots, at most `max_placements`). cc12's test plays it through the rules. |
| rewards | `reward_card`, `reward_title` (max 32) and/or `reward_frame`; at least one. Cosmetic only. |

Slot ids follow the spec wall: `a1 a2 a3` (top row), `b1 b2 b3 b4` (middle), `c1 c2 c3` (bottom).
Each slot is used once across board, replies and solution; at most one Signature per side.

## BalanceConfig (`balance.tres`, spec §9)
| Field | Default | Checked range |
|---|---|---|
| `wall_rows` | 3 / 4 / 3 | 3 rows, outer rows equal, middle one longer |
| `lineup_size` | 5 | two lineups must fit the wall |
| `clearance_cap` | 12 | lineup_size .. 4 × lineup_size |
| `max_legends` | 1 | 0 .. lineup_size |
| `stat_budgets` | 13, 15, 17, 19 | 4 values, rising |
| `stat_min` / `stat_max` | 1 / 9 | |
| `set_size_min` / `set_size_max` | 2 / 6 | |
| `set_link_bonus` / `clutch_bonus` / `ambush_spring_bonus` | 1 / 2 / 1 | 0–3 |
| `signature_value` | 2 | 1–3 |
| `triptych_bonus` | 1 | 0–2 |
| `tie_winner` | `FIRST_PLAYER`(0) | or `DRAW`(1) |
| `chain_captures` | off | |
| `cipher_code` | 1, 2, 3, 4 | 4 distinct glyph numbers 1–4; each should be on a card |
| `loaner_lineup` / `loaner_signature` | empty (cc03) | when set, a legal lineup (lineup rule) |
| `lobby_wait_min_s` / `lobby_wait_max_s` | 60 / 150 | 5–600 |

Changing a budget makes every card on that Clearance fail until its values are re-split; that is on purpose.
Log every change from the spec values in `../../../documentation/design/balance-log.md`.

## Issue codes
`load_failed`, `unknown_type`, `duplicate_id`, `missing_field`, `out_of_range`, `invalid_value`,
`broken_reference`, `wrong_type`, `budget_mismatch`, `store_rule`, `lineup_rule`.

## Shipped prototype content (cc03)
Content log with every table and the decisions behind it:
`../../../documentation/design/content/prototype-content.md`.

| Folder | Files |
|---|---|
| `cards/` | the 20 cards of spec §6 (13 start owned, 7 locked) |
| `sets/` | `night_shift` 1, `whiteout` 2, `signal_fire` 3, `old_guard` 4, `cipher` 5, `showcase` 6 |
| `unlocks/` | `unlock_win_streak_3`, `unlock_beat_warden`, `unlock_beat_warden_no_legend`, `unlock_captures_20`, `unlock_wins_5`, `unlock_dossier_carded`, `unlock_cipher_lock` |
| `rivals/` | `quartermaster`, `archivist`, `warden` |
| `triptychs/` | `midnight_run`, `cold_signal`, `open_book` |
| `dossiers/` | `dossier_first_contact` (D1) … `dossier_clean_copy` (D5) |

**Cipher glyphs:** Graveyard Shift 1, Mayday 2, Brass Tacks 3, Frostbite 4 (deliberately not the set
order). `cipher_code` is **4, 3, 1, 2**. The order hint is the Cipher album page's tagline: "Cold comes first,
then the old guard. Night falls third; the signal fires last." (Whiteout, Old Guard, Night Shift, Signal Fire).
The player has to find which glyph each of the four cards carries.

**Long Watch:** `unlock_beat_warden_no_legend` should need **2** Warden wins with no Legend. `UnlockGoal`
only allows `target_count` on WIN_STREAK / CAPTURES_TOTAL / WINS_TOTAL, so it is 0 for now; set it to 2 once
BEAT_RIVAL_NO_LEGEND takes a count (cc09).

**Dossier notes for cc12:**
- A `DossierPlacement` has no Cipher pick, so a solution step for a Cipher card doesn't say what it copies.
  D5's solution copies from **c2** (Polar Night's Clutch). The solution test must try the picks
  (`WallRules.cipher_picks`) or a `copy_from` field must be appended to `DossierPlacement`.
- Rival replies own their slot from the start (D3 `a2`, D4 `c1`); the Dossier screen should mark those
  slots as taken so the player can't place there.
- No solution relies on a spring at the end of the puzzle: D3's Ambush springs at the start of the
  player's second placement, after the scripted reply.
- Every solution was played through `WallRules` (players P1 = you, P2 = rival, rival reply after each
  of your placements) and meets its goal with a strict win where the goal needs one.

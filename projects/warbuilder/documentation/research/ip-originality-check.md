# Warbuilder: IP and Originality Check

*Market Analyst (run by the Master Orchestrator) · 2026-11-04 · Board task `wb-ip` (part of `wb-assess`)*
*Scope: the title, all text in `source/project-warbuilder/` (engine, UI, styles, print-and-play generator, README), the card and gun names, and the art in `src/webart/` and `src/pnp/art/`.*
*This is a product-risk review, not legal advice. Before a commercial release we recommend a registry search (USPTO, EUIPO and CIPO, since the head is in Quebec) and a short legal review of the final name.*

## 1. Summary
| Item | Risk | Recommendation |
|---|---|---|
| "Warzone" in the title | **High** | Rename before any wider release (itch page, PnP, store) |
| 12 unused perk names copied from a shooter franchise | **High** (they ship in the build) | Delete the perk set, or rename all 12 |
| "Buy Station" and several card names that match one franchise's equipment, killstreak and movement terms | **Medium** as a group | Rename about 8 cards and the Buy Station |
| Gun names (Sidearm, Viper, Raider, Sentinel, Ranger, Longbow …) | Low | Keep |
| Gun art: recognisable real-world firearm platforms, no logos | Low | Keep. Avoid logos and model names, and record art provenance |
| Card art: generic soldiers, drone, crates | Low | Keep |
| Rarity colours grey/green/blue/purple/gold | Low (genre convention) | Keep, or align with the one-rarity-scale fix |
| Art provenance (the style suggests AI-generated images) | **Unknown** | Confirm the source and commercial rights, and record them |

## 2. "Warzone" in the title
**Why it matters:** *Call of Duty: Warzone* is a major battle-royale game by Activision, and its brand is commonly shortened to "Warzone". Warbuilder is a battle-royale game about guns, loot, gas and a "Buy Station". Using **Warzone as the lead word** of a game in the same genre and theme is the classic setup for a likelihood-of-confusion complaint, whatever the exact registrations are. Store takedowns (itch.io, app stores) can follow a complaint without any court case. "Warzone" has also been used by other games: a 1990s tabletop miniatures line, and the RTS *Warzone 2100*. So it's crowded and not distinctive for us either.

**Where it appears** (grep of all text; no art file names contain it):
| Player-facing | File : line |
|---|---|
| Title screen "Warzone Deckbuilder" | `src/ui.js:487` |
| Browser tab `<title>` | `src/index_v21.html:1` (copied by `build.py:11`) → `build/index.html` |
| Print-and-play header, page title and **every page footer** | `src/pnp/gen.js:200`, `:244`, `:404` |
| PDF file name `Warzone-Deckbuilder-Print-and-Play.pdf` | `src/pnp/topdf.py:8` |
| README title (and so the GitHub repo page) | `README.md:1`. The repo name `wardeckbuilder` is fine. |

| Internal only (comments) | File : line |
|---|---|
| "WARZONE DECKBUILDER v4.0 — rules engine" | `src/engine.js:1` (also shipped inside the build) |
| "five rarities (Warzone colours)" | `src/engine.js:86` |
| "Warzone rarity colours" | `src/style.css:629`, `:720` |
| Old v2.1 file | `src/index_v21.html:365`, `:1292` |

Internal comments don't create market confusion, but they ship inside the single-file build and suggest the game was modelled on that product. Clean them up with the rename.

## 3. Card, perk and term names
We compared every card, gun, perk, location and system name with the equipment, killstreak, perk and mechanic names of the best-known military shooter franchise. Individual generic military words can't be owned. The risk comes from **many exact matches together**, which signals that the game was derived from one franchise.

**3a. Loadout perks: all 12 names match that franchise's perk names exactly** (`engine.js` lines 319–332): Double Time, Ninja, Tempered, Battle Hardened, Cold-Blooded, Overkill, Scavenger, Spotter, Restock, Hardline, Quick Fix, E.O.D. The older `PERKS` table also has **Flak Jacket**. Perks are switched off (`TUNE.perks: false`), but **all 12 perk card faces ship in the build** (`perk_*` in `FACES`) and in the PnP asset sheet. **Recommendation: delete the perk system** (it's off and untested). If it comes back, use new names.

**3b. Active cards and terms**
| Name (id) | Match | Risk | Suggested rename |
|---|---|---|---|
| **Buy Station** (system, many UI strings) | The franchise's battle-royale shop is the "Buy Station" | **Medium–High** (a signature feature name) | **Quartermaster** or **Supply Line** (not "Supply Depot", which is already a location) |
| **Heartbeat Sensor** (R21) | A distinctive equipment name in that franchise | Medium | **Pulse Scanner** |
| **Munitions Box** (E21) | A field-upgrade name in that franchise | Medium | **Ordnance Crate** |
| **UAV** (R31) | A signature killstreak name. The words themselves are generic. | Medium (with the others) | **Eye in the Sky** (avoid "Recon Drone", which CardZone uses) |
| **Tac Sprint** (K02) | The franchise's coined movement term | Medium | **Hustle** |
| **Slide Cancel** (A12) | A community/mechanic term from that franchise | Low–Medium | **Slide In** |
| **Deployable Cover** (E12) | A field-upgrade name; generic words | Low–Medium | **Pop-up Barrier** |
| **Dead Drop** (K03) | A generic spy term, also used in that franchise | Low | **Stash** (optional) |
| **Ammo Box** (S11) | Generic, also a field upgrade there | Low | **Ammo Can** (optional) |
| **Spotter Scope** (R22) | A real device ("spotting scope"), also a field upgrade there | Low | **Spotting Scope** |
| **Black Market** (E32) | Generic, also a shop name in that franchise | Low | **Smuggler's Den** (optional) |
| **Overwatch** (S31) | A generic military term, but also a famous game trademark (Blizzard) | Low–Medium | **High Ground** |
| Legendary skin "**Judge**" (Magnum) | A real revolver model name (Taurus) | Low | **Verdict** |

**Fine as is:** Sprint, Scout, Steady Aim, Recon Run, Take Cover, Focus, Spare Rounds, Armor Plates, Breach, Hip Fire, Rush the Door, Flank, Run and Gun, Blitz, Breaching Charge, Mark Target, Steady Breath, Snapshot, Thermal Optic, Headhunter, Suppressing Fire, Bandolier, Steady Grip, Resupply, Covering Fire, Munitions Drop, Scrounge, Ping, Field Kit, Salvage, Field Workshop. Gun names (Sidearm, Magnum, Combat Knife, Viper, Breacher, Raider, Sapper, Sentinel, Bastion, Ranger, Longbow) and skins (Gold Rush, Obsidian, Gold Fang, Dragon's Breath, Night Raid, Demolition, Crown Jewel, Iron Monarch, Golden Hour, Sun God) are generic or original. Location names (Open Road, Small Shed, House, Supply Depot, Concrete Barrier, Military Bunker, Recon Tower, Workbench) are generic. Mechanic words like "gas", "circle", "loot", "drop" and "operator" are genre vocabulary.

*Note:* rarity colours grey/green/blue/purple/gold are a long-standing loot convention across many games and can't be owned. Only the code comment calls them "Warzone colours".

## 4. Art review
**Card art** (40 images, `src/webart/*.webp`, high-res in `src/pnp/art/*.jpg`): a consistent ink-and-spray illustration style with generic soldiers in modern kit, a consumer-style quadcopter (for UAV), crates, barriers and terrain. **We saw no logos, insignia, franchise characters or UI motifs.** Risk: **low**.

**Gun art** (30 images, `webart/guns/`, `pnp/art/guns/`): detailed illustrations of **recognisable real-world firearm patterns**: a Glock-style polymer pistol, an MP5-style SMG with a folding stock, an AR-15-pattern rifle with modern furniture and a red dot, a precision bolt-action rifle on a bipod, an M249-style LMG, a pump shotgun, a six-shot revolving grenade launcher, and a fantasy gold revolver. At print resolution we saw **no manufacturer logos, roll marks or model names**. The game uses invented names. Gun makers have objected to unlicensed *named* likenesses in games, but the main court case, AM General v. Activision (2020, about the Humvee), went for the game maker. Unnamed, stylised generic patterns are common across the genre. Risk: **low**. Keep them unnamed and logo-free. If cheap, make the most distinctive silhouettes (the pistol slide) a little more generic in future art passes.

**Franchise branding:** none in the art. The only franchise link is the **text** (title, perks, terms).

**Provenance (to confirm):** the clean, uniform rendering suggests AI-generated images. That's fine if the tool's terms allow commercial use. Please confirm how the art was made and whether we hold commercial rights, and we'll record it in `documentation/art/art-provenance.md`. If any image was traced from a photo or another game, replace it.

## 5. Safe naming: title options
Rules we used: no franchise words (Warzone, Verdansk, Gulag, Buy Station …), no existing tabletop or game brand (for example, avoid "Deadzone", a Mantic Games title), clearly different from the studio's own "CardZone", and short enough for a card footer.

| Option | Why | Notes |
|---|---|---|
| **Warbuilder** (recommended interim) | Already the studio's project name. It keeps "war + deckbuilder", the head's original idea, without the franchise word. | Needs a quick registry search. Fine for itch/PnP immediately as a working title. |
| **Last Circle** | Says "battle royale" without borrowing anyone's brand. It also fits the gas redesign (a real final circle). | Search for conflicts. Good final-title candidate. |
| **Hot Drop** | BR slang for landing where the loot (and the danger) is | Generic phrase; may be hard to own |
| **Drop & Loot** / **Loot & Load** | Descriptive and playful | Weak as a brand |

**Recommendation:** rename the working title to **Warbuilder** now, in every player-facing place in section 2. Shortlist **Last Circle** for the final title after a registry search. Rename the flagged terms in section 3b and delete the perk set at the same time, so the next itch build and PnP are clean.

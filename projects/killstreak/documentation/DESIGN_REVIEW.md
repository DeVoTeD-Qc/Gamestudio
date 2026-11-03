# Killstreak — Design Review (for approval)

*Master Orchestrator · 2026-11-03 · Phase: Design · Mode: design only, no code until you approve*
*All content is original. No Call of Duty names, characters, maps, factions, logos or trademarked mode/feature names; only generic genre terms.*

## One-line pitch
**"Your loadout is your deck. Your streak is your power spike."** A fast card game where every battle plays like a multiplayer shooter match: three lanes, short rounds, and killstreaks you earn by staying alive.

## Recommended format: hybrid, built as a single-player roguelite first
- **What it is:** a Slay the Spire / Balatro-style roguelite (a run of short matches against AI enemy squads, drafting cards and leveling your weapon between matches). Each match plays like a **Marvel Snap-style 3-zone game with simultaneous reveal**.
- **Why:** it's the only format that is buildable and playtestable in the browser in about a week. It's the friendliest for newcomers (no collection, no losing to veterans), and it has the lowest market risk (PvP card games need large audiences and live ops; Gwent's development ended and LoR pivoted to PvE). Because **both sides follow identical rules**, PvP can be added later without a redesign: first async "Mirror Squads" (fight other players' saved builds), then live PvP.
- **Alternatives:** *PvP constructed (Hearthstone/Snap)* has the strongest "multiplayer" feel, but it fails the timeline and is a high-risk business. *Pure roguelite* is what we build first; the hybrid label just keeps the PvP door open.

## Core loop
**Round (30 s):** read the minimap red dots (enemy contacts per lane) → spend Supply to deploy units, throw a Frag/Flashbang, rotate your Operator → reveal → firefights in all 3 zones → killfeed + streak → call in killstreaks.
**Match (3–5 min):** a game mode sets the win condition → After-Action XP and weapon level-up.
**Run (30–45 min):** 3 brackets + a Rival squad; pick 1 of 3 card rewards, attachments, Armory; 3 tickets.
**Meta:** Player Rank unlocks, challenges, Threat Levels 1–10.

## Shooter → card mapping
| Shooter | Card mechanic |
|---|---|
| Custom class loadout | Loadout Builder: Primary, Secondary, Lethal, Tactical, 3 Perks, 3 Killstreaks; the deck = your squad & kit |
| You, the soldier | **Operator** hero unit on the board: fights, rotates lanes, goes down, respawns next round |
| Primary weapon / class | Sets the Operator's Firepower/Armor and trait (AR steady, SMG First Shot, Sniper Pick) |
| Weapon XP & attachments | Weapon levels during a run → choose 1 of 2 attachments that upgrade the Operator |
| Lethal & Tactical | Cooldown abilities (Frag, Flashbang, Smoke), usable near your Operator |
| Perks | 3 passive rule-changers, the Balatro-Joker-style depth layer |
| **Killstreaks** | Streak +1 per elimination; **resets when your Operator goes down**; thresholds unlock Recon Drone (2), Mortar Barrage (3), Sentry Turret (4), Attack Helo (5), Gunship (7) |
| UAV-style recon / minimap | Red dots show enemy deployments per lane; recon reveals the actual cards |
| 3-lane maps & weapon range | 3 zones tagged Close/Mid/Long; SMG/Shotgun better up close, Sniper at long range, AR in mid |
| Game modes | Zone Control (domination-style), Firefight (TDM-style), Detonator (S&D-style, elite matches) |
| Killfeed, hit markers, XP pop-ups, callouts | The feedback/UI layer and radio barks |

## Serving both audiences
- **Shooter players:** a preset loadout and no deck building before the first match; three numbers per unit; one line of text; shooter vocabulary everywhere; a scripted tutorial; 3–5 minute matches; XP pop-ups and streak payoffs.
- **Card veterans:** simultaneous-reveal reads, deployment-order and keyword sequencing, range positioning, streak risk management, Perk engines, deck thinning and attachment builds, Threat Levels 1–10, and deterministic firefights (no dice).

## Market verdict
**Conditional GO** for a web prototype of the roguelite. **NO-GO** on a live-service PvP CCG as the first product. The gap: no well-known card game speaks *modern multiplayer shooter* (KARDS covers WW2 history, not the shooter match). Balatro proves familiar rules plus a deep modifier layer can reach far beyond card players. Web is ideal for prototype/demo distribution; Steam is the realistic commercial home later. Risks: IP/trademark (strict originality plus a title search), and a "niche military" perception, so market the match feel rather than war.

## Art direction
"Tactical HUD meets field kit": the game looks like a soldier's tactical tablet between firefights. Dark slate UI, signal-amber for anything interactive, teal for friends, red for enemies (with shape cues for colorblind players), and cyan for killstreaks. Cards look like laminated ID badges with stylized duotone painted art (operators always in gear, so no likeness issues). Killstreaks appear as glowing tablet cards and Perks as embroidered morale patches. The board is a top-down lane map with a minimap intel strip, a killfeed and a segmented streak arc that shatters when you go down. The look is gritty, not gory, and light enough for web.

## What the web prototype would contain (~5–7 days after approval)
1 map (Port Vasel) · 2 modes (Zone Control, Firefight) · the full round loop with streaks and Operator respawn · 20 starter + 6 reward cards · 1 Primary with 4 attachments, Frag, Flashbang, 4 Perks, 4 Killstreaks · 2 AI personalities / 3 enemy squads · a 5-match mini-run · scripted tutorial · outcome preview, killfeed, hit markers · playtest log + survey · placeholder art · Godot 4.4.1 single-threaded web build on a private itch.io link.
**Not included:** Detonator, extra weapons, shop, meta-progression, second map, final art and voice, any PvP.

## Decisions you need to make before prototyping
1. **Format:** approve the roguelite-first hybrid? Or do you want PvP (even hot-seat) in the first prototype?
2. **Core hook:** is "streak resets only when *your Operator* goes down" the right shooter feel, or should streaks reset on any unit loss (harsher, more hardcore)?
3. **Match structure:** are simultaneous reveal + 3 lanes OK, or do you prefer Hearthstone-style alternating turns?
4. **Setting & tone:** keep the near-future contractor setting (Kharzan Corridor, HALBERD vs BLACK MERIDIAN), or prefer present-day or fully abstract "multiplayer lobby" framing with no story?
5. **Title:** keep "Killstreak" as the working title, pending a trademark search? Any alternatives you'd like checked?
6. **Prototype modes:** Zone Control + Firefight, or swap one for Detonator (S&D-style, no respawn)?
7. **Run length:** is 30–45 minutes with 3 tickets right, or do you want shorter runs (about 15 minutes) for web/portal play?
8. **Art for the prototype:** placeholder layout only (recommended), or a small painted-art style test of 3 cards?
9. **Long-term platform:** web only, or should design assume a later Steam/mobile release (this affects UI scale and monetization planning)?
10. **Load-time target:** accept re-targeting from "< 3 s" to "< 10 s with a loading screen" for the Godot web build?

**Detailed docs:** `design/gdd.md` · `design/vision.md` · `design/core-rules.md` · `art/style-guides/art-direction.md` · `production/producer-scope-review.md` · `production/playtest-metrics-plan.md` · `production/timeline.md` · `../resources/market-research/market-analysis.md` (+ overview & 5 competitor files)

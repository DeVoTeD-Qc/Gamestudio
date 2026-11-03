# Killstreak — Game Vision & Format Decision

*Author: Sr Game Designer Agent · 2026-11-03 · Status: proposed, awaiting user approval · Mode: DESIGN ONLY*
*IP: Original setting. No Call of Duty names, characters, maps, factions, logos or trademarked mode/feature names. Generic genre terms (loadout, perk, killstreak, recon) only.*

## Core concept
**"Your loadout is your deck. Your streak is your power spike."** Killstreak is a fast, single-player card game where each battle is played like a multiplayer shooter match. You fight on a three-lane map, build a killstreak by winning firefights, and lose the streak the moment your Operator goes down.

## Setting (original)
Near-future private-military conflict in the fictional **Kharzan Corridor**: ports, refineries and relay stations held by contractor squads. The player is an Operator in the contractor force **HALBERD**. Opponents are rival squads with gamertag-style callsigns, led by the elite enemy outfit **BLACK MERIDIAN**. The tone is multiplayer-lobby energy rather than a war drama: radio callouts, killfeed, XP pop-ups, and dry squad banter.

## Design pillars
1. **Speaks Shooter.** Every system is a shooter idea a shooter player already understands: loadout, perks, lethal and tactical, killstreaks, respawn, map lanes, weapon range. If a mechanic needs a fantasy-card explanation, it's wrong.
2. **Fast Rounds, One More Match.** Matches take 3–5 minutes (6–8 rounds), turns take seconds, and a full run takes 30–45 minutes. There is always a next match, unlock or weapon level just ahead.
3. **Streaks Are Earned.** The big moments come from playing well: chaining eliminations while keeping your Operator alive. Risk (pushing your Operator into a fight) against reward (bigger streaks) is the central tension.
4. **Readable Depth.** Three numbers per unit and an always-visible enemy intel picture make it easy to start. Depth comes from position, deployment order, range, reading the enemy's simultaneous plays, and Perk synergies (Balatro-style). The rules stay simple and the combinations get deep.

## THE key decision: format

| Criterion (from brief + constraints) | A. PvP constructed (Hearthstone/Snap-like) | B. Single-player roguelite deckbuilder (StS/Balatro-like) | C. Hybrid (roguelite now, PvP-ready rules, async PvP later) |
|---|---|---|---|
| "Feel the shooter vibe" | ★★★ real opponents = real multiplayer | ★★ AI opponents, but can be shown as enemy squads | ★★★ AI squads framed as a lobby; real players' builds later |
| Easy for shooter players | ★★ collection and meta knowledge needed; losing to experienced players drives newcomers off | ★★★ preset loadout, no deck building before your first match, AI difficulty curve | ★★★ |
| Depth for card veterans | ★★★ constructed meta | ★★★ drafting, Perk engines, Threat Levels | ★★★ both layers over time |
| Web prototype in < 1 week (after approval) | ✗ needs netcode/matchmaking, or it's only a hot-seat demo | ★★★ fully offline, all client-side | ★★★ same as B for the prototype |
| Business/market risk (see market analysis) | High: needs a large audience and live ops | Low–medium | Low now; PvP is optional later |
| "One more match" loop | ★★★ ladder | ★★★ next match in the run + unlocks | ★★★ |

**Recommendation: C — Hybrid, built as a single-player roguelite deckbuilder first.**
- The **prototype and v1 are a roguelite** (option B). That is the only format that can be built, tuned and playtested in a browser in about a week, and it's the format where newcomers have the best time (Balatro proves it).
- The **match rules are symmetric**: both sides use the same rules, resources and card types, and everything resolves through simultaneous reveal. The AI is just another player. That keeps **PvP possible later without redesigning**: first async "Mirror Squads" (fight other players' saved end-of-run loadouts), then live PvP if the audience is there.
- Alternatives rejected for now: **A** fails the timeline and carries the highest market risk. **Pure B** is what we build, but we deliberately keep the rules symmetric so the "multiplayer" promise in the brief is never closed off.

## Core loop

**30-second loop (a round):** read the minimap intel (red dots = enemy contacts arriving in each lane) → spend Supply to deploy Operators, use your Lethal/Tactical, play tactics → reveal → firefights resolve in all three zones → eliminations feed the killfeed and your **streak meter** → unlock and call in a killstreak.

**5-minute loop (a match):** a game mode sets the win condition (Zone Control = hold lanes for points; Firefight = race to eliminations; Detonator = plant/defend a charge, used for elite matches). Your Operator fights, goes down, respawns, and builds streaks. Each match ends with an After-Action screen (XP, weapon level-ups).

**30–45-minute loop (a run, called a "Deployment"):** 3 brackets (Recruit → Veteran → Elite), 3–4 matches each, ending in a Rival match against a named squad. Between matches you draft cards (Supply Drop: pick 1 of 3), level your weapon (choose an attachment), spend Credits in the Armory (buy, remove or upgrade cards; buy Perks). You have 3 Reinforcement Tickets: lose a match and you lose a ticket; lose all three and the run ends.

**Meta loop (between runs):** Player Rank XP unlocks new weapon classes, Perks, killstreaks and cards in the reward pool; challenges ("3 Pick eliminations in one match") award cosmetic calling cards. Threat Levels 1–10 (an Ascension-style difficulty ladder) give veterans a long climb. A Re-Up (rank reset for a badge) is a possible later feature.

## Shooter → card mapping

| Shooter element | Card-game mechanic |
|---|---|
| Custom-class **loadout** | **Loadout Builder** before each run: Primary, Secondary, Lethal, Tactical, 3 Perks, 3 Killstreaks. Your *deck* is your squad and support kit. |
| **You, the player soldier** | Your **Operator** hero unit is on the board. It fights in a zone, can move one lane per round, goes down, and respawns next round. |
| **Primary weapon** & weapon class | Sets your Operator's Firepower plus a weapon trait (AR steady, SMG First Shot, Sniper Pick). Squad units also carry weapon classes. |
| **Attachments / weapon leveling** | Weapon XP is earned across matches in a run; each level unlocks a choice of 1 of 2 attachments (Extended Mag, Scope, Suppressor…) that upgrade the Operator. |
| **Secondary / sidearm** | A cheap repeatable action: 1 Supply, 1 damage in your Operator's zone, once per round. |
| **Lethal & Tactical equipment** | Two loadout abilities on cooldown (Frag, Flashbang, Smoke…), usable in your Operator's zone or an adjacent one. |
| **Perks** | 3 passive rule-changers (the depth layer, like Balatro Jokers): streak thresholds −1, draw on elimination, recon immunity… |
| **Killstreaks** | Streak meter: +1 per enemy eliminated, **reset to 0 when your Operator goes down**. Reach a threshold and that killstreak card is earned and kept until used (Recon Drone 2, Mortar Barrage 3, Sentry Turret 4, Attack Helo 5, Gunship 7). |
| **Scorestreak variant** | A Perk / card option where holding zones also builds the meter (support playstyle). |
| **UAV-style recon / minimap** | The enemy's planned deployments appear as red dots per lane (count only). Recon effects reveal the actual cards. |
| **Three-lane map design** | 3 zones: Left Flank, Mid, Right Flank. Each map tags each zone Close / Mid / Long range. |
| **Right gun for the range** | Weapon class bonuses by zone range (SMG/Shotgun up close, Sniper at long range, AR in mid). |
| **Who's on point** | Deployment order matters: fire hits the enemy's front-most unit (the "point man") unless a keyword says otherwise. |
| **Game modes** | Match win conditions: **Zone Control** (domination-style), **Firefight** (team-deathmatch-style), **Detonator** (search-and-destroy-style; elite/Rival matches). |
| **Respawn** | Your Operator returns next round at full Armor; squad cards don't respawn. |
| **Killfeed, hit markers, XP pop-ups, callouts** | UI and feedback layer: killfeed log, hit markers on damage, "+100 ELIMINATION", radio voice lines on key moments. |
| **Matches, playlists, ranked tiers** | A run is a series of matches in brackets; Threat Levels act as "ranked". |
| **Supply drop** | Card reward screen (pick 1 of 3), plus a rare killstreak that drops a random card. |

## Easy to learn, deep to master

**Easy (first 10 minutes):**
- Start with a **preset loadout** (AR + starter deck). You don't build a deck before your first match.
- Units show **3 numbers**: Cost, Firepower, Armor. Text is capped at one short line, and keywords have icons and tooltips.
- A **scripted first match** teaches deploying → firefight → streak → calling in a Recon Drone.
- Enemy intent is always visible (red dots), and the outcome preview shows "if the firefight happened now".
- Shooter words everywhere, so players already know what a Flashbang or a Sentry Turret does.

**Deep (hours 2–50):**
- **Simultaneous reveal**: read the red dots, bait enemies into Close-range zones, and hold back your Operator to protect the streak.
- **Deployment order and keywords** (First Shot, Pick, Cover, Suppress, Flank): sequencing puzzles inside each zone.
- **Streak management**: when to risk the Operator, and when to spend a killstreak versus hold it.
- **Perk engines** (Balatro-style): e.g., *Field Salvage* (draw on elimination) + *Streak Discipline* (thresholds −1) + a cheap Pick deck = a streak machine.
- **Run economy**: deck thinning in the Armory, attachment builds, choosing which brackets to push.
- **Threat Levels 1–10** add enemy modifiers ("enemy squads start with Cover", "streaks reset when ANY unit is lost").

## Player experience goals
- **Target emotions:** the "clutch" (winning a 1v3 lane), the streak spike (calling in the Gunship), and the "one more match" itch.
- **Progression:** within a run: weapon levels, deck, Perks. Between runs: Player Rank unlocks and Threat Levels.

## Success metrics (prototype)
- A shooter player with no card-game background finishes the tutorial match and wins a normal match without help in **≤ 10 minutes**.
- **≥ 80%** of matches have at least one killstreak called in; **≥ 60%** of testers start "one more match" without being asked.
- Card-game testers rate decision depth **≥ 4/5**. See `../production/playtest-metrics-plan.md`.

## Handoff to Mid Game Designer
Priorities: (1) round structure + firefight resolution, (2) streak meter and Operator down/respawn, (3) zones with range tags, (4) starter set of about 20 cards, (5) two modes (Zone Control, Firefight). Constraints: ≤ 8 keywords, ≤ 1 line of rules text per card, all values integers ≤ 10, both sides use symmetric rules.

# Killstreak - Game Design Document (v0.1, Design Phase)

*Owner: Sr Game Designer · Contributors: Mid Game Designer, Sr Game Artist, Data Scientist, Producer · 2026-11-03 · Status: awaiting user approval*
*IP: Original modern-military setting. No Call of Duty names, characters, maps, factions, logos or trademarked mode/feature names.*

## Overview
**Concept**: A fast, single-player card game where every battle plays like a modern multiplayer shooter match. Your loadout is your deck, your Operator fights on a 3-lane map, and chaining eliminations without going down earns killstreaks.
**Format**: Roguelite deckbuilder (StS/Balatro-like) with symmetric, PvP-ready match rules (Snap-like 3 zones + simultaneous reveal). Async PvP is a later phase.
**Genre**: Strategy / card game · **Platform**: Web (Godot 4.4.1 HTML5) · **Target Audience**: Core: shooter players (accessibility) + card-game veterans (depth)
**Setting**: Kharzan Corridor, a fictional near-future contractor conflict. The player is a HALBERD Operator; the elite rival is BLACK MERIDIAN.

## Design Pillars
1. **Speaks Shooter**: every system is a shooter concept (loadout, perks, lethal/tactical, streaks, respawn, lanes, weapon range).
2. **Fast Rounds, One More Match**: 3–5 min matches, 30–45 min runs.
3. **Streaks Are Earned**: risking your Operator against keeping the streak alive is the central tension.
4. **Readable Depth**: 3 numbers per unit and visible intel; depth comes from position, order, range, reads and Perk synergies.

## Core Gameplay Loop
- **30 s (round):** read the minimap red dots → deploy and use gear → reveal → firefights in 3 zones → streak/killfeed → call in killstreaks.
- **5 min (match):** a mode win condition (Zone Control / Firefight / Detonator), then the After-Action XP screen.
- **30–45 min (run, a "Deployment"):** 3 brackets of matches plus a Rival; drafting, weapon level-ups, Armory; 3 Reinforcement Tickets.
- **Meta:** Player Rank unlocks, challenges, Threat Levels 1–10.
Details: [vision.md](vision.md).

## Game Systems
- **Format decision & rationale, shooter → card mapping, learn/master plan:** [vision.md](vision.md)
- **Rules:** 3 zones with Close/Mid/Long range tags; Supply N+1 (cap 7); simultaneous reveal; deterministic two-step firefights (First Shot → Main), shots hitting the point man first; 7 keywords; Operator down/respawn; streak meter (resets on Operator down) → killstreaks (2/3/4/5/7); modes. Full spec: [core-rules.md](core-rules.md)
- **Loadout:** Primary (Operator stats + trait) + attachments from weapon XP, Secondary, Lethal, Tactical, 3 Perks, 3 Killstreaks.
- **Run:** brackets, Supply Drops (pick 1 of 3), Armory (buy/remove/upgrade), tickets.
- **AI:** personality-driven squads (Rusher / Anchor / Sniper Nest) that commit their plans first (which feeds the red dots).

## Content Specifications
- Starter card set of 20 designs, starter deck list, reward pool, 3 Primaries, 7 Perks, 5 Killstreaks, 2 Lethals, 2 Tacticals, maps Port Vasel and Cinder Refinery: [core-rules.md §3–5](core-rules.md)
- A sample turn walkthrough: [core-rules.md §6](core-rules.md)

## Technical Requirements
**Engine**: Godot v4.4.1, GDScript, 2D, Compatibility renderer, single-threaded web export.
**Performance Targets**: 60 FPS; load < 10 s on broadband (the original "< 3 s" is not achievable with Godot 4's WASM size, about 8–10 MB compressed). Prototype assets < 5 MB.
**Architecture notes (for later):** cards as `.tres` Resources; a pure-logic match resolver kept separate from presentation (testable, and the basis for PvP later); autoloads for run state and the playtest logger.

## Art Direction
"Tactical HUD meets field kit": dark slate UI, signal-amber interactables, teal friend / red enemy, duotone painted card art, laminated-badge card frames, killstreaks as glowing tablet cards, perks as morale patches. Full guide: [../art/style-guides/art-direction.md](../art/style-guides/art-direction.md)

## UI/UX Design
Board = top-down map with 3 lane zones; minimap intel strip (red dots); killfeed; segmented streak arc around the Operator panel; Supply pips; big READY button; outcome-preview overlay; one-line card text with keyword tooltips; scripted tutorial match. (No dedicated UI/UX agent this phase; the Sr Game Artist covered UI feel.)

## Audio Design
Original radio-chatter barks ("Contacts Left!", "Recon drone up.", "Operator down, redeploying."), punchy suppressed-gunfire SFX, synth lobby pulse. Prototype: placeholder SFX, no voice.

## Monetization Strategy
Not applicable in this phase. Market guidance for later: premium PC release + free web demo; no F2P packs.

## Success Metrics
- Shooter-segment testers win their first normal match in ≤ 10 min, and rate "felt like a shooter" ≥ 4/5
- ≥ 80% of matches include a killstreak call-in; median match 3–5 min
- ≥ 60% "one more match" rate; card-veteran testers rate decision depth ≥ 4/5
Full plan: [../production/playtest-metrics-plan.md](../production/playtest-metrics-plan.md)

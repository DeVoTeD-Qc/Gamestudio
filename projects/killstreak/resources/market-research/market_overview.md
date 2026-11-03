# Market Overview: Strategy / Card Games (Web-first)

*Market Analyst Agent · 2026-11-03 · Full analysis: [market-analysis.md](market-analysis.md). Figures are estimates (confidence ~60%).*

## Project Context
**Our Game**: Killstreak (working title) · **Genre**: Strategy / card game (roguelite deckbuilder recommended) · **Platform**: Web (Godot 4.4.1 HTML5) · **Audience**: Core: shooter players + card-game veterans
**Competitors Analyzed**: Hearthstone, Marvel Snap, Slay the Spire, Balatro, Gwent (+ KARDS, Legends of Runeterra, Super Auto Pets as reference points)

## Market Size & Growth
- **Digital card games overall**: multi-billion-dollar segment, with most revenue going to a few F2P PvP titles.
- **Roguelite deckbuilders**: a fast-growing premium niche on PC; Slay the Spire and Balatro each sold millions of copies.
- **Platform distribution**: PvP CCGs lean mobile; deckbuilders lean PC (Steam) and then port to console/mobile. Web portals are ad-funded and casual-leaning.

## Genre Trends
- **Current**: short sessions (Snap ~3 min), simultaneous turns, roguelite structure, passive-modifier engines (Balatro Jokers).
- **Emerging**: async PvP (fighting other players' saved builds), PvE modes inside PvP games (LoR *Path of Champions*), "genre-mash" deckbuilders.
- **Declining**: new live-service PvP CCGs (Gwent ended active development in 2023; high churn among new launches).

## Competitive Landscape
- **Leaders**: Hearthstone and Marvel Snap (PvP); Slay the Spire and Balatro (single-player).
- **Gap**: no notable deckbuilder built around the *modern multiplayer shooter* fantasy (loadouts, streaks, fast rounds, map control).
- **Entry barriers**: PvP = very high (audience size, servers, content treadmill); single-player = low cost to build but crowded, so the hook must be sharp.

## Target Audience Analysis
- **Shooter players**: huge audience, strong progression habits (XP, unlocks, weapon levels), short-session "one more match" behavior; turned off by text-heavy cards.
- **Card veterans**: want synergies, drafting, deck control, difficulty ladders.
- **Unmet need**: a card game that "speaks shooter" without being a fantasy CCG with a military skin.

## Revenue Models in Genre
- **Dominant**: F2P packs/battle pass (PvP); premium $10–25 (roguelite).
- **For us (later)**: premium Steam release + free web demo. No monetization in the prototype.

## Success Factors
- **Must-have**: instant readability, short matches, juicy feedback, visible enemy intent, drafting with meaningful choices.
- **Differentiators**: killstreak meter that resets when your Operator goes down; loadout-as-hero; zones with weapon-range tags; game modes as match rules.
- **Quality benchmarks**: Snap-level clarity; StS-level fairness; Balatro-level build variety.

## Risk Assessment
- **Market saturation**: Medium (deckbuilders) / High (PvP CCG)
- **Competition intensity**: High at the top, moderate in the themed niche
- **Platform risks**: Godot web build size (~8–10 MB compressed), mobile-browser audio/touch quirks
- **Timing**: StS2 and the Balatro wave keep deckbuilders popular; the shooter theme is unclaimed

## Recommendations
1. Build a single-player roguelite deckbuilder with symmetric match rules (PvP-ready later via async "Mirror Squads").
2. Lead marketing with the shooter fantasy ("your loadout is your deck, your streak is your power spike").
3. Keep the IP strictly original and run a trademark check on the working title.

## Next Steps for Producer Agent
- [x] Review market findings → see `documentation/production/producer-scope-review.md`
- [x] Adjust scope: single-player first, PvP deferred
- [x] Define positioning: "the shooter player's deckbuilder"
- [ ] Set prototype playtest targets (see `documentation/production/playtest-metrics-plan.md`)
- [ ] Go-to-market plan: deferred until the prototype is validated

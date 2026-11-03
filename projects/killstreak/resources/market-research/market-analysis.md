# Killstreak — Market Analysis (Design Phase)

*Author: Market Analyst Agent · Date: 2026-11-03 · Scope: design-only, web-first prototype*
*Data note: figures are public-domain estimates from memory of press/earnings coverage, not live research. Treat numbers as order-of-magnitude (confidence ~60%). Re-validate before any funding/launch decision.*

> **IP constraint honored:** this report names competitors for analysis only. Our product uses no Activision/Call of Duty names, characters, maps, factions, logos or trademarked mode/feature names. All Killstreak content is original.

---

## 1. Executive summary

- **Verdict: GO for a web prototype — as a single-player roguelite deckbuilder with PvP-ready rules. NO-GO on a live-service PvP CCG as the first product.**
- Card games are split in two healthy but very different markets:
  1. **PvP collectible/constructed** (Hearthstone, Marvel Snap, Gwent, KARDS): huge revenue at the top, brutal to enter. Needs matchmaking liquidity, servers, anti-cheat, constant content and a F2P economy. Several well-funded entries have shrunk or turned to PvE (Gwent ended active development in 2023; Legends of Runeterra moved its focus to the PvE roguelite *Path of Champions*).
  2. **Single-player roguelite deckbuilders** (Slay the Spire, Balatro, Monster Train, Inscryption): low cost to build and run, sold at premium prices, small teams, and they do very well on streams and word of mouth. Balatro (2024) showed the format can reach players well beyond card-game veterans.
- **The gap:** no well-known deckbuilder captures the *modern multiplayer shooter* fantasy (loadouts, streaks, fast rounds, map control). Military card games exist (KARDS = WW2 CCG), but they model *war history*, not the *shooter match*. Shooter players are one of the largest audiences in gaming and have **never been given a card game in their own language.**
- **Web-first is a good fit for the prototype** (zero install, shareable link, fast playtests) and a reasonable channel for a free demo (itch.io, CrazyGames, Poki-style portals). Steam is the realistic commercial home for a full release in this genre.

## 2. Competitive landscape

| Game | Format | Model | What it proves | Lesson for us |
|---|---|---|---|---|
| **Hearthstone** (Blizzard, 2014) | PvP constructed CCG, hero + board | F2P + packs | Readable board, juicy feedback, hero-power identity. A clear UI beats a complex one. | Copy the readability and the "hero with a signature ability" idea (our Operator + Primary weapon). |
| **Marvel Snap** (Second Dinner, 2022) | PvP, 3 lanes, simultaneous reveal, ~3 min games | F2P | **Short matches, 3 locations and simultaneous turns** work on mobile/web. Retreat/raise ("Snap") adds poker-like bluffing. | Best match for our "fast round" feel. Copy 3 zones + simultaneous reveal + short matches. |
| **Gwent** (CD Projekt, 2018) | PvP, rows, best-of-3 rounds | F2P (dev ended 2023) | Round-based structure feels like "rounds" in a match. Hard to keep a PvP game alive without a big audience. | Proof that PvP needs a large audience. Avoid live-service PvP at first. |
| **Slay the Spire** (Mega Crit, 2017/2019) | Single-player roguelite deckbuilder | Premium (~$25) | **Visible enemy intents** + choose-1-of-3 card rewards = deep but fair. The sequel (StS2) keeps the genre in the spotlight. | Copy intents (our "minimap red dots"), reward drafting, and difficulty ladders. |
| **Balatro** (LocalThunk/Playstack, 2024) | Single-player roguelite, poker hands + Jokers | Premium (~$15) | Familiar base rules (poker) + crazy passive modifiers (Jokers) = **easy to start, very deep**. Multi-million sales, wide crossover. | **Our playbook for "simple for shooter players".** Familiar shooter rules (loadout, streaks) + passive Perks that work like Jokers. |
| **KARDS** (1939 Games, 2020) | PvP WW2 CCG | F2P | A military theme can hold a loyal niche, but a "historical war" theme stays niche. | Theme alone isn't enough; the hook has to be the *shooter match* fantasy. |
| Super Auto Pets / Backpack Battles | Async PvP (fight other players' saved builds) | F2P / Premium | **Async PvP** gives the feel of playing real people without real-time servers. | Our future PvP path: "Mirror Squads". |
| Legends of Runeterra | PvP CCG → PvE roguelite focus | F2P | Even Riot found PvE roguelite more sustainable than PvP. | Supports our format choice. |

## 3. What each audience wants

| | Shooter players | Card-game veterans |
|---|---|---|
| Wants | Instant action, recognizable vocabulary (loadout, perk, streak, UAV-style recon), visible progression (XP bars, weapon levels, unlocks), short sessions, "one more match", satisfying hit feedback, feeling skilled | Meaningful decisions every turn, synergies and engines, deck control (thinning, drafting), high skill ceiling, difficulty ladders, build variety, fair information |
| Fears / turn-offs | Walls of text, slow turns, math homework, "fantasy card game with a gun skin" | Shallow theme-first design, random swings with no counterplay, F2P paywalls |
| How we serve them | Shooter vocabulary on every card, 3 numbers per unit, 3–5 min matches, XP pop-ups, killfeed, killstreak payoffs | Simultaneous-reveal reads, deployment order, zone range tags, Perk synergies (Joker-like), attachment builds, Threat Levels 1–10 |

## 4. Web-first distribution

- **Pros:** zero-friction playtests (send a link), easy to embed on portals, Godot 4.4 has a single-threaded web export (no SharedArrayBuffer / cross-origin headers needed), and our 2D card game needs very little GPU.
- **Cons / risks:**
  - Godot 4 web builds are large: about 35–40 MB uncompressed WASM, about 8–10 MB compressed. The config target of "< 3 s load" is **not realistic on a cold load**. Suggested target: < 10 s on broadband, with a loading screen.
  - Web portals pay through ads and favor quick casual games. A core strategy game makes more money as a premium Steam release.
  - Mobile browsers work, but audio unlock and touch input need care. The Compatibility renderer is required for web.
- **Recommendation:** use web for the prototype and a free public demo, plus wishlist capture if a Steam release follows. Do not design monetization yet (out of scope).

## 5. Risks

| Risk | Level | Mitigation |
|---|---|---|
| IP / trademark confusion with the source franchise | **High** | Original names everywhere; no franchise visual signatures (no specific HUD, logos, operator likenesses). **The title "Killstreak" needs a trademark search** (the word is generic but may be registered for games). |
| "Military card game" reads as niche | Medium | Market the *shooter match feel* ("your loadout is your deck, your streak is your power spike"), not war history. |
| Rules too complex for shooter players | Medium | 3 numbers per card, intents always visible, tutorial match is scripted, keywords capped at about 8 in the prototype. |
| Too shallow for card players | Medium | Perks and attachments as the depth layer; Threat Levels; simultaneous reveal. |
| PvP expectations ("shooters are multiplayer!") | Medium | AI opponents shown as enemy squads with gamertags; async "Mirror Squad" PvP as a planned phase 2. |
| Real-time violence / rating | Low | Stylized, non-gory art; "eliminated/downed" wording. |

## 6. Rough outlook (if taken to a full premium release; confidence low)

- Conservative: niche indie, 10–30k units at $10–15.
- Realistic: 50–150k units if the streak hook lands in streams and demos.
- Optimistic: Balatro-like crossover is a rare outlier; don't plan around it.

## 7. Go / No-Go

**GO (conditional)** on a web prototype of a **single-player roguelite deckbuilder** with symmetric (PvP-ready) match rules.
Conditions: (1) the IP rules are strictly followed, (2) the prototype proves the killstreak loop is fun within 5 minutes for a non-card player, (3) the title trademark is checked before anything public.

**NO-GO** on a live-service PvP CCG as the first product: it is too expensive, needs a large player base, and doesn't fit the rapid timeline.

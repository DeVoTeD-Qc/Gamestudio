# CallingCard: Game Design Document

*Version 0.1 (Design phase) · 2026-11-03 · Owner: Sr Game Designer · Status: awaiting the head's review*
*Unofficial design pitch about Call of Duty calling cards. All names, cards and art are original. A prototype would be a standalone concept demo, not a mod or recreation of Call of Duty.*

## Overview
**Problem:** In Call of Duty, players unlock many calling cards (from challenges, mastery, events, prestige, ranked and bundles), but each is just a wide image, only one can be equipped, and collecting them has no value.
**Concept:** **Banner Wall**, a quick side mode where your calling cards are the pieces. How hard a card was to earn decides how strong it is. Sets, hidden Triptychs and cipher puzzles turn the collection into an album worth completing. Nothing touches shooter balance.
**Genre:** Strategy (tile-placement card duel) plus a meta-collection
**Platform:** Web (concept demo). A live version would sit in the game's menus/lobby and a companion app.
**Target audience:** Core CoD players, especially challenge and camo grinders and collectors
**Detailed docs:** `vision.md` (pillars, 5 concepts, scoring) · `mechanics/banner-wall-spec.md` (full rules and 20 cards) · `../art/style-guides/art-direction.md` · `../production/prototype-scope.md` · `../../resources/market-research/market-analysis.md`

## Design Pillars
1. **Earned, not bought.** Power comes from earn difficulty. Store cards are cosmetic-only (Clearance 1, no trait).
2. **Cosmetic-safe in the shooter.** No stat, information or visibility effect in multiplayer matches.
3. **Every card has a reason.** Each card has stats, a set and an album slot. Rare cards have a trait; hidden ones are puzzles.
4. **Fits in the lobby.** 2–4 minute sessions.
5. **The flex is the point.** The Signature card and "Carded!" moments.

## Core Gameplay Loop
- **30 seconds (a turn):** read the wall → choose a card and slot (with capture preview) → place → captures flip color → the opponent answers.
- **3 minutes (a duel):** 5 placements each on a 10-slot brick wall → score (Signatures count double, Triptych +1) → result and unlock progress.
- **Session/meta:** album → see what's missing and why it would help → earn cards (in the live game, through shooter challenges; in the demo, through duel goals and Dossiers) → improve your lineup → complete sets and discover Triptychs.

## Game Systems
- **Cards:** Top/Side/Bottom values (1–9); Clearance 1–4 (stat budgets 13/15/17/19); origin → trait; set; frame.
- **Traits:** Steady (Challenge), Veteran (Mastery), Ambush (Event), Reclaim (Prestige), Clutch (Ranked), Cipher (Secret); Showcase/store cards have no trait.
- **Set Link:** +1 to all values when placed touching your own same-set card.
- **Lineup:** 5 cards, Clearance ≤ 12, ≤ 1 Legend, 1 Signature; loaner lineup for small collections.
- **Board:** a 3-4-3 offset brick wall; middle bricks have 6 neighbors.
- **Scoring:** 1 point per controlled card, Signature 2, Triptych +1; ties go to the first player (tunable).
- **Album:** set pages, silhouettes with unlock goals, set-completion titles and frames, hidden Triptychs, Cipher Lock.
- **Dossiers:** handcrafted fixed-hand puzzles that teach rules and grant cards and titles.
- **AI rivals:** Easy/Normal/Hard (random / greedy / 2-ply).
- **Live-game extensions (pitch only):** an automatic stat formula for existing cards, async duels vs friends' lineups, a Signature Trio 3-slot showcase, Card Contracts, and a Bounty limited-time mode.

## Content Specifications
The demo has 20 original cards: Night Shift (4), Whiteout (4), Signal Fire (4), Old Guard (4), Cipher (2, secret) and Showcase (2, store). It also has 3 Triptychs, 5 Dossiers, 3 rivals and a starting collection of 13/20. The full table is in `mechanics/banner-wall-spec.md` §6.

## Technical Requirements
**Engine:** Godot v4.4.1 (GDScript, GL Compatibility, single-threaded web export)
**Architecture:** pure-logic rules module (`wall_rules.gd`) with unit tests; `Collection` and `Telemetry` autoloads; card and balance data as `.tres`.
**Performance targets:** 60 FPS; load under 10 s with a loading screen (proposed; replaces the default "< 3 s" for a Godot web build); art under 5 MB.

## Art Direction
"Museum of the Grind": cards as framed exhibits on a night-gallery brick wall. Duotone poster art inside the cards. Frame material scales with Clearance (graphite → steel → brass → black-and-gold enamel). Showcase store cards get the flashiest chrome or gold frames but no power. Teal = you, coral = rival, amber = interactive, plus shape cues for colorblind players. See `../art/style-guides/art-direction.md`.

## UI/UX Design
Landscape, mouse and touch, scales down to phone size. A capture preview appears before you confirm. No hover-only information. Hand strip at the bottom, score counters with Signature ribbons at the top. Album as a portfolio with silhouettes.

## Audio Design
Placeholder only: placement thunk, capture wipe, "Carded!" stamp sting, Triptych chord.

## Monetization Strategy
Not applicable to the demo. **Pitch principle for a live version:** monetize **frames and visual treatments only**. Store cards are always Clearance 1 with no trait. No trading, no randomized paid packs.

## Success Metrics
- Intent to collect: at least 70% of playtesters rate it 4 or higher
- Album pull: at least 50% open the album twice or more and inspect an unowned card
- Median duel under 4 minutes; D1 tutorial cleared in under 3 minutes
- Fairness perception: at least 70% rate it 4 or higher
- First-player win rate 45–55% in AI-vs-AI simulation

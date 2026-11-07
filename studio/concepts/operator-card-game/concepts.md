# Operator Card Game: concept exploration

*Board task `op-concepts` · project `opcard` · Sr Game Designer · 2026-11-07 · Status: **for the head's review** · design only, no code*
*Head's brief (verbatim): "We need to find what a Call of Duty card game would look like, considering that in Call of Duty you only play one character at a time and equip two weapons and perks and stuff, so not spawning units but improving our own character and fighting on a map or something."*
*Call of Duty is named here only as a hypothetical licence and as inspiration. Every rule, name, number and visual below is original. No CoD/MW art, logos, perk names or killstreak names are used. Weapon names reuse KillingCard's original ones (Kestrel AR-7, Wasp-9, Longreach .338, Bastion-60, P-12 Sidearm) plus one new one (Mako-12).*

**TL;DR.** KillingCard deploys units into lanes. This exploration goes the other way: **one operator per player, and the cards improve and drive that one body on a map.** I wrote six concepts with genuinely different structures. I recommend prototyping two:
1. **Point Man**, the flagship. It is a 1v1 Hardpoint duel on a 3×3 room map, and **your deck is generated from your loadout**: weapons give Fire cards, attachments edit those cards, perks are passive slots and killstreaks sit in a tray. This makes the gunsmith-and-unlock loop the deckbuilding itself, so "I unlocked a foregrip" directly means "my deck changed".
2. **Snapshot**, the cheap second. It is a 4-minute simultaneous-reveal Search and Destroy duel ("who pre-aimed the angle?"). It is the purest translation of fast time-to-kill and reads, it is phone-portrait native, and it shares Point Man's weapon table and loadout data. It could ship later as Point Man's quick mode.

---

## 0. A shared stat model (used by every concept)

All six concepts use one weapon model, so whichever one wins, the data carries over.

**Operator Health: 4.** Most guns down a target in 2 hits at their best range. That is the "fast time-to-kill" dial.

| Weapon (original) | Class | Close | Mid | Long | Handling (cost to fire) | Identity |
|---|---|---|---|---|---|---|
| Wasp-9 | SMG | 2 | 1 | 0 | 1 (fast) | Wins rooms, loses lanes |
| Kestrel AR-7 | Assault rifle | 2 | 2 | 1 | 1 | Generalist |
| Mako-12 | Shotgun | **4** | 1 | 0 | 1 | One-shot in the room, useless outside it |
| Bastion-60 | LMG | 2 | 2 | 2 | 2 (slow) | Holds an angle, suppresses |
| Longreach .338 | Sniper | 1 | 3 | **4** | 2 (slow) | One-shot at range, punished up close |
| P-12 Sidearm | Pistol (secondary) | 1 | 1 | 0 | **0** | Free emergency shot ("switch to pistol") |

**Cover** removes 1 damage at Mid and Long, never at Close. Close fights are decided by who is faster and who is closer, not by cover.

**Loadout slots (the CoD shape, with original contents):** Primary, Secondary, Lethal (Frag, Tripwire), Tactical (Flashbang, Smoke), 3 Perks (one from each of three lists), a Field Upgrade (charges over time), and 3 Killstreaks (earned by streak points without dying; the streak resets on death).
- Example perks: *Soft Step* (quiet movement), *Scrounger* (refill on a kill), *Cool Head* (later streaks cost 1 less), *Low Profile* (immune to recon), *Long Breath* (holding an angle is cheaper), *Thick Plates* (Health 5).
- Example field upgrades: *Deployable Cover*, *Rally Beacon* (a personal respawn point), *Adrenal Shot* (heal to full), *Signal Jammer*.
- Example killstreaks: *Recon Drone*, *Sentry Turret*, *Mortar Barrage*, *Attack Helo*. These are KillingCard's existing generic names.

**UX rule (all concepts):** every card, slot, room, sightline and token has a zoomed inspect view on **right-click (desktop) and long-press (touch)**. Each concept's board was sized so that this works on a phone.

---

## 1. What makes a CoD match feel like CoD

### 1.1 Seven design pillars

1. **One body, many lives.** You *are* one operator. Your body is your only piece, so every risk is personal. Death is brief (you are back in seconds), so you play boldly rather than freezing. *Card test:* the player never controls more than one figure, and dying costs tempo, never the match.
2. **First to see, first to shoot.** Time-to-kill is short. The fight is decided before it starts, by who held the angle, who had the better range and who acted first. *Card test:* most exchanges resolve in one or two shots (Health 4, damage 1 to 4). There are no long health-bar slugfests.
3. **Position is power.** Sightlines, cover, power positions, flanks and spawn logic matter. Where you stand changes what your gun is worth: an SMG in a room versus a sniper down a lane. *Card test:* the same card is good or bad depending on the map square you play it from.
4. **The loadout is your identity.** Before the match you make a personal, expressive build (primary, secondary, equipment, perks, field upgrade, streaks), and it shapes how you want to play. *Card test:* two players with the same rank and different loadouts face different decisions every turn.
5. **The streak is the tension.** Kills without dying escalate your power. Each life asks you to play safe and protect the streak, or push for the next reward. *Card test:* a visible streak meter, three chosen rewards, and a reset on death.
6. **The objective drags you out of hiding.** Score-to-win modes (Team Deathmatch, Domination, Hardpoint, Search and Destroy) punish camping and force fights in known places. *Card test:* the score comes mainly from map spaces, so standing still loses.
7. **Every match moves a bar.** Weapon XP, attachment unlocks, camo challenges and calling cards mean even a loss feels like progress, and "one more match" is always close. *Card test:* every match awards XP to the weapon you used and progress on at least one visible challenge.

*(Eighth, flavour pillar, applied everywhere rather than designed:)* **Loud and readable feedback.** Hit markers, a kill feed and a streak call-in moment. KillingCard already has these as FX (§3.3).

### 1.2 What translates poorly to cards, and how to fake it

| Doesn't translate | Why | How we fake it |
|---|---|---|
| **Aim and reflexes** | Cards have no aim skill. | Replace aim with **reads and initiative**: hidden "Hold Angle" reactions (Point Man), simultaneous reveal with a stance triangle (Snapshot), or a time track where slow guns pay ticks (Tick Rate). Skill becomes predicting the opponent, the card-game equivalent of pre-aiming. |
| **Real time / simultaneity** | Alternating turns let the defender react, which turns a 0.3-second fight into a polite exchange. | Use reaction windows (overwatch), simultaneous reveal, or a time track. Never use "I shoot, you shoot back, I shoot". |
| **Fast time-to-kill vs card-game health pools** | Card games like 20-30 HP. | Health 4 and damage 1-4. Use cover and plates as the only buffers. |
| **Fog of war, footsteps, minimap** | A board is fully visible. | Hidden position cards, "Noise" (sprinting reveals you), and recon killstreaks that reveal hidden information. Concepts differ on how much is hidden (Q3). |
| **6v6 chaos and respawn churn** | Too many bodies to track on a phone. | Use 1v1 or 3v3 at most. Respawn becomes a **fresh hand** plus a tempo penalty (the respawn timer). |
| **Fluid movement (slide, mantle, jump)** | Grids are clunky. | Use small node or room graphs. Movement cards (Slide, Mantle, Sprint) carry the verbs as small bonuses. |
| **Recoil, attachments as feel** | Attachments are about feel, not numbers. | Each attachment is a **trade-off on a card**: +1 Long but Handling +1, or +2 Fire cards but -1 Close. The player feels the gunsmith as deck texture. |
| **Spawn trapping, camping** | These degenerate into stalemates. | Rotating objectives (Hardpoint), spawns placed far from the enemy, and grenades that ignore cover. |

---

## 2. Six concepts

Common shorthand: **HP** = Health, **T** = Tempo (action points), **C/M/L** = Close/Mid/Long.

---

### Concept 1: **Point Man**: 1v1 Hardpoint duel; your deck is your loadout

**Pitch.** Two operators fight over a rotating hardpoint on a 3×3 grid of rooms. Before the match you build a loadout, and **the loadout generates your 24-card deck.** Your primary contributes its Fire cards, your attachments edit them (more cards, better range, cheaper to fire), equipment adds a few utility cards, perks sit in three passive slots, and killstreaks wait in a tray until your streak points earn them. When you go down you lose your hand and respawn with a fresh one, so respawning feels like coming back in with a new plan. The skill is in positioning (which room, which sightline) and in **Hold Angle**: a face-down Fire card that shoots first when the enemy walks into your line. That is the "they pre-aimed me" moment.

**How the deck is built (no free deckbuilding; the gunsmith is the deckbuilder):**
- **Primary:** 8 Fire cards (SMG 9, Sniper 6, Shotgun 6). Each shows the gun's C/M/L damage and Handling.
- **Secondary:** 3 Fire cards (Pistol: Handling 0).
- **Lethal:** 2 cards. **Tactical:** 2 cards.
- **Movement (fixed, everyone):** 6 cards: 2 Sprint (move 2 rooms), 2 Slide (move 1; your next Close Fire this turn gets +1), 1 Mantle (cross a window edge), 1 Hold Angle (also playable from any Fire card, see below).
- **Attachments (up to 5, like a gunsmith):** each edits the deck with a trade-off. Examples: *Extended Mag* (+2 Fire cards; Handling +1 on the first Fire each turn), *Foregrip* (+1 Mid; -1 Close), *Holo Sight* (+1 Mid), *Long Barrel* (+1 Long; Handling +1), *Quick Stock* (Handling -1, minimum 0; -1 Long), *Suppressor* (your Fire does not trigger enemy Hold Angles; -1 Long).
- **Perks (3 slots, passive, on the board):** e.g. Soft Step (your first Step each turn is free), Scrounger (draw 2 on a kill), Long Breath (Hold Angle costs 0 T).
- **Field Upgrade (board slot):** charges 1 per turn, usable at 4. Deployable Cover, Rally Beacon or Adrenal Shot.
- **Killstreaks (tray):** pick 3 of: Recon Drone (3 pts: see the enemy's hand and face-down Hold Angles for their next turn), Sentry Turret (4: a 1-damage turret in your room that shoots enemies who enter it or end their turn within Mid sightline), Mortar Barrage (6: 3 damage to everyone in a room, 1 in adjacent rooms, ignores cover), Attack Helo (8: 1 damage to the enemy at the start of each of their next 3 turns unless they are in a roofed room).

Total: 8 + 3 + 2 + 2 + 6 = 21, +0 to 3 from attachments, so about 22-24 cards.

**The map.** 9 rooms (A1-C3) with walls, doorways, windows (Mantle only) and some roofed rooms. **Range:** same room = Close; an adjacent room through an opening = Mid; two rooms away along a straight line of aligned openings (a printed sightline) = Long. Rooms have Cover 0 or 1. Each side has 2 spawn rooms in opposite corners. You respawn in the one farther from the enemy. Maps are hand-made (target 4 at launch). Positions are public; **Hold Angles are hidden**.

**How a turn works.**
1. Draw up to 5. Gain 3 T (2 T on the turn you respawn).
2. Spend T on any mix of: **Step** (1 T: move 1 room through an opening), movement cards, **Fire** (cost = Handling; damage by range, minus cover), equipment (1 T), killstreaks from the tray (0 T), and the field upgrade (0 T when charged).
3. **Hold Angle** (1 T): put any Fire card face-down on one sightline or doorway from your room. Until your next turn, the first time the enemy moves into, or fires along, that line, you **immediately resolve that Fire first**, before their action. Then the card is discarded.
4. End of turn: if you are on the hardpoint and the enemy is not, **+1 point** and +1 streak point.
5. Downed: you lose your hand and your streak points. You respawn at the start of your next turn (that is the respawn penalty). The enemy gets +2 streak points.

**Win.** The first to **8 points** wins. The hardpoint moves every 3 rounds (B2, then A3, then C1, then B2...). There is a cap of 14 rounds; at the cap the leader wins, and a tie goes to sudden death on B2. **Match length: about 10-12 minutes** (one turn is about 25-40 seconds).

**Meta progression.** Each weapon has its own XP (gained per Fire card played, and doubled on kills) and levels 1-20 that unlock attachments. That is the core pull, because each unlock changes the deck. Operator level unlocks perks, equipment and killstreaks. **Camos** come from per-weapon challenges ("10 Long downs with the Longreach") and change the card art finish only. **Calling cards** are earned for feats (a 3-kill streak, a perfect hill) and appear as your banner on the match intro. Cosmetics never change gameplay.

**Platform fit.** **Phone portrait: good.** The 3×3 map sits on the top half, the hand of 5 at the bottom, with the perk and streak strips between them. PC and landscape: map on the left, hand and loadout on the right. Async PvP is possible because turns are discrete.

**3-turn example.** Red: Kestrel AR-7 + Holo Sight (C2 / **M3** / L1, Handling 1). Blue: Longreach .338 (C1 / M3 / L4, Handling 2). The hill is **B2 (Cover 1)**. Red spawned at A1, Blue at C3.
- **Round 1, Red (3 T):** Step A1→B1 (1), Step B1→B2 (1). Red then sets **Hold Angle** with a Fire card on the B2-B3 doorway (1). Turn end: Red is alone on the hill, so **Red 1 point**, streak 1.
- **Round 1, Blue (3 T):** Step C3→C2 (1). C2 sees B2 through an opening, so the range is Mid (Red's Hold covers B3, not C2). Blue fires the Longreach at Mid (2 T): 3 damage - 1 cover = **2**. **Red HP 4→2.**
- **Round 2, Red (3 T):** Fire at C2 at Mid (1 T): 3 damage, cover 0, **Blue HP 4→1**. Fire again (1): **Blue downed.** Red gets +2 streak, reaching 3, so the **Recon Drone enters the tray**. With the last 1 T Red sets a **new Hold Angle** on the B2-B3 doorway (the round-1 Hold expired at the start of this turn). Turn end: **Red 2 points**, streak 4.
- **Round 2, Blue (respawns, 2 T, fresh hand):** Blue respawns at C3 and tries to flank: Step C3→B3 (1). That walks into **Red's Hold Angle**, which fires first: Mid, 3 damage, cover 0, **Blue HP 4→1.** With 1 T left Blue cannot fire the Longreach (Handling 2), so Blue fires the **P-12 Sidearm** (0 T): Mid, 1 damage - 1 cover, **0 damage**. The pistol bounces off Red's cover.
- **Round 3, Red:** Fire at B3 (1 T): **Blue downed** again. Red's streak is 6. Red is 2-0 on points and two kills up.
- *Lesson the example teaches:* Blue should have used Smoke on the B2-B3 line, or gone through C2 again where the Hold wasn't. Reading the hidden Hold is the skill.

---

### Concept 2: **Fireteam**: 3v3 Domination, one operator per player

**Pitch.** Two fireteams of three. Every player (a human, or a bot ally with a personality) runs exactly **one** operator. The map is 3 lanes × 5 depth bands, with a Domination flag in the middle of each lane. Each round all six operators plan in secret: where to move, and which **kit tile** to use. The plans are revealed together, then each lane's firefight resolves in a readable order (KillingCard's beat system). Team roles come from loadouts: the SMG entry player, the LMG anchor, the sniper on the long lane. Solo play is you plus 2 bot allies against 3 bots. Co-op is 3 humans against AI. Full 3v3 PvP comes later.

**The map.** Lanes Left / Mid / Right. Bands from your side: **Spawn, Side, Flag, their Side, their Spawn**. Range: same band = Close, 1 band apart = Mid, 2 bands apart = Long, and you can only shoot within your own lane. Your own Side band gives you Cover 1. The Flag band has Cover 0. Each map card (there are 5) changes 1-2 cells: "Mid Flag has Cover 1", "Right lane Long sightline blocked".

**Loadout becomes a kit board (no deck).** Each operator has 4 **kit tiles**: two universal (*Push*: move 2 bands, -1 Initiative; *Hold*: +1 damage to any enemy that enters your range this round) and two set by the primary (SMG: *Flank*, which shifts lane and still lets you shoot, ignoring cover; LMG: *Suppress*, which gives the target -1 damage and -2 Initiative; Sniper: *Scope*, +1 Long damage if you didn't move; AR: *Burst*, a second shot at -1 damage). A used tile is on cooldown for one round. Lethal and tactical have 1 charge per life. Perks are passive. The field upgrade charges over 3 rounds. Killstreaks are per operator (2 / 3 / 5 kills without dying), and their effects help the team (a Recon Drone reveals the enemy's planned lanes before your next lock-in).

**How a round works.**
1. **Plan (secret, 30-second timer online):** each operator chooses a move (stay, advance or fall back 1 band, or shift lane within your Side or Spawn band) and at most one kit tile or equipment. Humans can ping lanes to bots.
2. **Reveal.** Movement resolves, then smoke and flashes.
3. **Firefights, lane by lane, Left to Right.** Within a lane, the highest **Initiative** shoots first (Pistol 5, SMG/Shotgun 4, AR 3, LMG 2, Sniper 1, but Sniper is 5 at Long). Each operator fires once at the nearest enemy in range. A downed operator doesn't fire.
4. **Flags.** A lane's flag flips to a team that has operators in the Flag band while the other team has none.
5. **Score:** +1 per flag you hold. Downed operators respawn at their Spawn band next round, in any lane.

**Win.** The first team to **12 points**, with a cap of 12 rounds. **Match length: about 8-10 minutes.**

**Meta progression.** As in Point Man (weapon XP, attachments that upgrade kit tiles, camos, calling cards), plus **bot ally unlocks** with personalities (KillingCard's AiPersonality weights).

**Platform fit.** **Landscape-first** (phone landscape, tablet, PC): three lanes side by side is KillingCard's column board. Phone portrait is cramped (6 operators plus flags), but it works if the lanes stack vertically.

**3-turn example.** Red: **You** (Kestrel AR-7), Anchor bot (Bastion-60), Scout bot (Wasp-9). Blue AI: a sniper (Longreach), a shotgunner (Mako-12) and a rifleman (Kestrel). Everyone starts in their Spawn band. Lanes: You Mid, Anchor Left, Scout Right. Blue: sniper Mid, shotgun Left, rifle Right.
- **Round 1:** everyone advances to their Side band, which is 2 bands apart, so Long range. Mid: the Blue sniper used **Scope** but moved, so no bonus. Long Initiative: sniper 5 against your 3. The sniper fires first: Long 4 - 1 cover = **3**, **You 4→1**. You fire back: Long 1 - 1 = 0. Left: Anchor LMG at Long, 2 - 1 = **1** on the shotgunner (4→3). The shotgun deals 0 at Long. Right: both at Long, Wasp 0 and Kestrel 1 - 1 = 0. **Score 0-0.**
- **Round 2:** You **fall back** to Spawn, out of the sniper's range (3 bands). The Anchor uses **Suppress** on the shotgunner, who advances to Left Flag. Left is now Mid range: the shotgun deals 1 - 1 (suppressed) = 0, and the LMG deals 2 to the shotgunner (3→1). The Blue sniper advances to **Mid Flag** to chase you, but you are 3 bands away, out of range. The Scout uses **Flank** (Right Side→Mid Side): it shifts into your lane and still shoots. Side to Flag = Mid. The Scout has Initiative 4 and fires first, 1 damage: **sniper 4→3**. The sniper answers at Mid, 3 - 1 cover = 2: **Scout 4→2**. Blue's rifle advances to Right Flag uncontested and **captures Right**. **Score 0-1.**
- **Round 3:** You advance to Mid Side. In Mid lane the order is Scout (Initiative 4), You (3), sniper (1). The Scout hits for 1 (3→2) and you hit at Mid for 2: **sniper downed before it fires** (your kill: streak 1). The Anchor finishes the shotgunner (1→0) and **advances to Left Flag next round**. Blue still holds Right. **Score 0-2**, but Red now has a 3v1 window. A Recon Drone at 2 kills is one more down away.

---

### Concept 3: **Behind the Line**: roguelite single-operator campaign (PvE)

**Pitch.** A solo run. You take one operator through a three-act campaign map of missions, safehouses, armories and intel events, ending in a commander boss. Combat is a card-crawl: each encounter is a short line of enemy cards that **telegraph their intent** ("aiming at you: 2 damage next turn"), and you choose between three positions (Left cover, Centre, Right flank) that change who can see you. Your deck is a classic deckbuilder of actions. **Your weapon levels up mid-run**, and each level offers 3 attachments. **Clean streaks** (kills without taking Health damage) earn killstreaks inside a mission. This is where the "one more run" collection loop lives.

**The map.** Two layers. The **run map** is KillingCard Run v2's map unchanged in structure: 9 steps, 3 paths, forks into Armory (shop, currency REQ), Intel (events), Safehouse (rest), Elite (HVT) and Boss. The **encounter** is a 3-room mission (two fights and an exfil fight). Each fight has your 3 positions against 1-4 enemy cards at Close, Mid or Long, some with cover. An enemy has a sightline to you unless your position is behind cover from its side (Left cover blocks enemies on the right flank, and so on).

**Loadout → cards and slots.** You start with **Primary + Secondary on the board** (their stats from §0) and a **10-card starter deck**: 5 Fire (uses the equipped weapon), 2 Step (change position), 1 Frag, 1 Plate (+2 armor), 1 Reload/Draw. Perks are **relics** found at elites and Armories (3 slots; you may swap). The Field Upgrade is a per-mission charge. Killstreaks: choose 3 at the run start, earned by clean-streak points within a mission. **Weapon XP** (from kills) levels the gun: each level offers 3 attachments, pick 1, maximum 5. A second primary found mid-run can be swapped in, and your Fire cards adopt the new gun's stats, which is exactly CoD's "pick up a weapon".

**How a turn works.**
1. Draw 5, gain 3 T. Enemy intents are visible.
2. Play cards: Fire (cost = Handling) at a target in sightline, Step (1 T, move one position), equipment, Plate.
3. Enemies act in order, left to right, as telegraphed. Damage hits Plates first, then HP.
4. **Clean streak:** +1 per kill. It halves when you lose HP (Plates soak damage without breaking it).
5. Health: HP 6 + up to 4 Plates. Going down costs one of 3 **respawn tickets**: you restart the fight with a fresh hand at full HP, and the streak is lost. At 0 tickets the run ends.

**Win.** Beat the act-3 commander boss (each boss has one unique rule, like KillingCard Run v2's bosses). A **run takes about 25-35 minutes**; a single fight takes 2-3 minutes.

**Meta progression.** This is the strongest of the six. Runs unlock new weapons, attachments, perks and killstreaks into the pools. There are operators with a passive and a once-per-run ability (Run v2's Operators), camos from challenges, calling cards for boss kills and modifiers, and Threat levels (Hardcore and so on).

**Platform fit.** **Phone portrait: excellent** (Slay the Spire-like layout: enemy line on top, you in the middle, hand at the bottom). PC is fine. Offline.

**3-turn example.** You: Kestrel AR-7 (C2 / M2 / L1), HP 6, Plates 2. Fight "Courtyard": a Rifleman (HP 3, Mid, intent: Fire 2), a Gunner (HP 4, Long, Cover 1, intent: Suppress, -1 T to you next turn) and a Rusher (HP 2, Mid, intent: advance to Close, then 3 damage). You stand at Centre.
- **Turn 1 (3 T; hand: Fire, Fire, Step, Frag, Plate):** Frag the Rusher (1 T, 2 damage): **Rusher downed** (streak 1). Fire at the Rifleman (1 T, Mid 2): HP 3→1. Step to **Left cover** (1 T). Enemies act: the Rifleman fires 2, -1 cover = 1, so **Plates 2→1** (the streak holds). The Gunner suppresses: next turn you get 2 T.
- **Turn 2 (2 T):** Fire at the Rifleman: **downed** (streak 2, so the **Recon Drone is earned**). Step to **Right flank** (1 T); the flank ignores the Gunner's cover. The Gunner's intent is "Reposition", so it doesn't shoot.
- **Turn 3 (3 T):** Recon Drone (0 T): it marks the Gunner, and your next 2 Fires get +1. Fire at Long: 1 + 1 = 2 (no cover from the flank), Gunner 4→2. Fire again: **Gunner downed** (streak 3). **The fight is clean.** Weapon XP is +3, so the Kestrel reaches level 2. Offer: Foregrip / Holo Sight / Extended Mag.

---

### Concept 4: **Tick Rate**: draft your loadout, then fight on a time track

**Pitch.** An arena 1v1 in two acts. **Draft (3 minutes):** both players snake-draft from three open packs of 4 loadout pieces (weapons, attachments, perks, equipment, streaks). Taking the sniper so your opponent can't is a real strategy. **Fight (6-8 minutes):** a Team Deathmatch to 5 downs on a 7-node map, with **no turns.** Both operators sit on a shared **time track**: whoever is further behind in time acts next, and every action costs ticks. A sniper's aim costs 3 ticks and an SMG's costs 1. That is how real time and time-to-kill are faked: a heavy gun is literally slow. An aimed operator gets a **free reaction shot** when the enemy walks into their line.

**The map.** 7 nodes (2 spawns, Alley, Market, Courtyard [Cover 1], Tower [high ground], Underpass) joined by move edges. Sightline edges are printed separately and tagged C, M or L. Positions are public.

**Loadout → no deck; an action bar with costs.** Everyone has the same actions, priced by the loadout.

| Action | SMG | AR | Shotgun | LMG | Sniper |
|---|---|---|---|---|---|
| **Step** (1 node) | 1 | 2 | 1 | 3 | 3 |
| **Aim** (pick one sightline; you are now "aimed") | 1 | 1 | 1 | 2 | 3 |
| **Fire** (requires Aimed; damage from §0) | 1 | 2 | 2 | 1 | 3 |

Swap to pistol costs 1 (Aim 0, Fire 1). Equipment costs 2. Attachments shift costs (Quick Stock: Aim -1; Long Barrel: +1 Long, Aim +1). Perks bend rules (Soft Step: Step -1; Long Breath: staying Aimed has no upkeep). **Reaction:** when an enemy moves into, or along, your aimed sightline, you fire immediately and pay the Fire cost afterwards. Stepping breaks your aim.

**How the fight works.**
1. The operator with the **lower time** acts (ties: the one who acted less recently). They take one action and advance their marker by its cost.
2. Reactions interrupt at once.
3. Downed: you respawn at your far spawn at **your current time + 6 ticks** (the respawn timer), and your streak resets. Killstreaks come at 2 / 3 / 4 downs without dying (Recon Drone: the enemy's aim lines are shown for 6 ticks; Sentry Turret: a permanent 1-damage reaction shot on one sightline; Mortar Barrage: 3 damage on a node after a 4-tick delay, so it can be dodged).

**Win.** The first to 5 downs. A cap of 120 ticks; at the cap the leader wins. **Match: about 10 minutes including the draft.**

**Meta progression.** Ranked draft ladders. Your **collection decides the draft pool's cosmetics** (camos and calling cards), never the power. Weekly "pack themes" (e.g. a shotgun week).

**Platform fit.** PC and landscape are best, since the time track reads well as a horizontal bar. Phone portrait works: the map on top, a 5-button action bar, the track as a thin strip. The rules are deterministic, so it is great for replays and tournaments.

**3-step example.** Red: Wasp-9 (SMG). Blue: Longreach .338 (Sniper). Both start at time 0. A Tower-Courtyard sightline is Long; Courtyard-Tower are also adjacent by a stair (Close when you're in the same node).
- **Red (t0):** Step Spawn→Alley (1), so Red is at t1. **Blue (t0):** Step Spawn→Tower (3), Blue at t3. **Red (t1):** Step Alley→Market (1), t2. **Red (t2):** Step Market→Underpass (1), t3.
- **Blue (t3, tie, Blue acted less recently):** Aim along Tower→Courtyard (3), Blue at t6, **aimed.** **Red (t3):** Step Underpass→Courtyard (1). This walks into Blue's line: **reaction.** The Longreach fires at Long, 4 - 1 cover = **3**, **Red HP 4→1**, and Blue pays Fire 3, so Blue is at **t9**.
- **Red (t4, far behind Blue's t9, so Red acts several times in a row):** Step Courtyard→Tower by the stair (1), t5. Aim (1), t6. Fire at Close, 2 damage, **Blue 4→2** (t7). Fire again (1), t8: **Blue downed.** Blue respawns at t9 + 6 = **t15**. Red has 7 free ticks to reposition. *The slow, aimed gun won the first exchange; the fast gun won the close one. Time is the ammo.*

---

### Concept 5: **Sightline**: map-control board game with sightline tiles

**Pitch.** The deepest and most "board game" of the six. A 1v1 or 2v2 Domination match on a modular map built from **9 square tiles** (each 3×3 cells) that the players **draft and place before the match**. Each tile has printed walls, cover crates and sightline lanes, so building the map is the first tactic: "I'll give my sniper a long lane to B." Each player has a personal deck plus the loadout board, and earns **in-match XP** from kills and flags to buy attachments and equipment from a shared **Armory** market. That is the "level up during the match" feeling. It is designed so it can also be printed and played on a table (CardZone and Warbuilder lineage).

**The map.** A 9×9 grid. **LOS** runs only along printed rows, columns and diagonals and is blocked by walls. Range: 1-2 cells = Close, 3-5 = Mid, 6+ = Long. Crates give Cover 1. There are three flags (A, B, C) on the centre tiles.

**Loadout → board plus deck.** The loadout board (primary, secondary, 3 perks, field upgrade, 3 killstreak slots) is chosen before the match. **Starter deck of 10:** 4 Move (2 cells), 1 Sprint (4 cells, makes Noise), 3 Fire, 1 Frag, 1 Smoke. **Armory market** (5 face-up cards, refilled each round): attachments (2-5 XP; they go onto your weapon board and stay), extra Fire cards (2 XP; they go to your discard), equipment (2 XP), and Overwatch tokens (1 XP).

**How a turn works (alternating).**
1. Play up to 2 cards from your hand of 5 (Move, Fire, equipment), or place an Overwatch token (a reaction shot on one line).
2. Captures: end your turn on a flag cell with no enemy within 1 cell, and it flips to you.
3. Gain XP (+1 per flag you hold; a kill gives +3) and buy from the Armory.
4. Discard and draw 5 (Dominion-style). After both players have taken a turn, score +1 per flag held.
5. Downed: you respawn at your spawn tile on your next turn with only 1 card play. The streak resets.

**Win.** The first to **15 points**. **Match: about 20-30 minutes** (1v1), 30-40 minutes (2v2).

**Meta progression.** Unlock tiles (new map pieces are the collectible), weapons, attachments for the Armory pool, camos and calling cards. A physical print-and-play edition is possible.

**Platform fit.** **PC and tablet landscape.** A phone is poor: a 9×9 grid with line-of-sight needs space, even with long-press inspect.

**3-turn example.** Red: Kestrel AR-7, at b2. Blue: Bastion-60 LMG, at h8. Flag A is at c5, behind a crate (Cover 1).
- **Turn 1 Red:** Sprint b2→c5 (4 cells), standing on the flag; no enemy within 1, so **A flips to Red.** The Sprint makes Noise, so Blue sees where Red went. Red gets +1 XP. **Blue:** Move h8→g6, then Move g6→e5. Row 5 LOS from e5 to c5 is 2 cells, **Close**, but Blue has used both card plays on movement, so no shot. End of round: **Red 1-0.**
- **Turn 2 Red:** Fire at Close, 2 damage (cover doesn't apply at Close), **Blue 4→2**. Then Frag e5: 2 damage, **Blue downed** (+3 XP, so Red has 5 XP). Red buys **Foregrip** (3 XP; +1 Mid, -1 Close) from the Armory. **Blue:** respawns at h8 with 1 play and places an **Overwatch** on the h-file toward flag C.
- **Turn 3 Red:** plays Move c5→c7 to threaten flag B. That doesn't cross Blue's Overwatch file, so there is no shot. **Red holds A** and leads 2-0. Blue's Overwatch now forces Red to approach flag C the long way.

---

### Concept 6: **Snapshot**: simultaneous-reveal Search and Destroy duel

**Pitch.** It looks like a 4-minute party game and has a ladder underneath. Each round is one life: the attacker has to plant at a site, and the defender has to stop them. Each **beat** of the round, both players **secretly** choose a **Position** (where you'll be) and a **Stance** (Hold, Peek, Rush, Utility, or Plant/Defuse), then reveal. If the two positions share a sightline, it's a fight: **Hold beats Rush** (they ran into your crosshair), **Rush beats Peek** (you closed before they settled), **Peek beats Hold** (the shoulder-peek baited the held angle). The winner shoots with their weapon's damage at that range. The same stance means both fire at once, which can trade. With no contact, **nothing is revealed** except Noise from rushing. It is the purest version of "who pre-aimed the angle?"

**The map.** Six positions in a graph: **A Site, A Ramp, Mid, Connector, B Short, B Site**, plus the attacker's spawn (which links to A Ramp, Mid and B Short). Each sightline edge is tagged with a range: A Ramp-A Site **M**, Mid-A Site **L**, Mid-Connector **C**, Connector-B Site **M**, B Short-B Site **C**, Mid-B Short **L**. Sharing a position = Close. You move one edge per beat (two with Rush). The launch target is 4 maps.

**Loadout → no deck; an always-available hand.** Your hand is the map's position cards plus 5 stance cards, every beat. The loadout adds to them: the weapon sets damage by range; the Secondary gives a 1-damage "Sidearm Peek"; Lethal (Frag: a Utility stance that deals 2 to a chosen adjacent position) and Tactical (Flashbang: the enemy at a chosen adjacent position has their stance cancelled; Smoke: removes one sightline for 2 beats) each have 1 use per round. Perks: Soft Step (your Rush makes no Noise), Low Profile (immune to Recon), Thick Plates (HP 5), Scrounger (a kill refills your Lethal). Field Upgrade, once per half: Deployable Cover (-1 damage taken this beat) or Signal Jammer (no enemy Recon or Noise this round). Killstreaks run on downs without dying, **across rounds**: Recon Drone (2: before the next beat's choice, the enemy's current position is shown to you), Sentry Turret (3: a position of your choice Holds for 2 damage every beat this round), Mortar Barrage (4: name a position; whoever is there next beat takes 4).

**How a round works.**
1. Health is HP 4 (wounds carry over within the round; a fresh 4 each round).
2. **Beat (up to 5 per round):** choose Position + Stance face-down, then reveal. A fight happens if the positions share a sightline or are the same. Resolve the stance triangle; the winner deals weapon damage at that range minus cover (sites have Cover 1 for the defender). Equal stances: both deal damage. No contact: positions stay hidden, and a Rush reveals the rusher's position afterwards (Noise).
3. **Plant:** the attacker uses the Plant stance at a site with no contact that beat. **Defuse:** the defender then has 2 beats to use Defuse at that site with no contact (being hit cancels it).
4. **Round end:** a down (an elimination), a detonation (the attacker wins), a defuse, or 5 beats with no plant (the defender wins).

**Win.** The first to **4 rounds**, swapping sides after 3. **Match: about 4-6 minutes** (one beat is about 8 seconds).

**Meta progression.** Ranked tiers with seasonal calling cards, weapon XP and camos, map unlocks, and "clutch" challenges (win a round below 2 HP). It shares Point Man's loadout collection if both ship.

**Platform fit.** **Phone portrait: excellent.** The map graph on top, two short card rows (positions and stances) at the bottom, two taps per beat. It works for PC and async ("play a beat a day").

**3-beat example (Round 1).** Red attacks with a Kestrel AR-7 (C2 / M2 / L1). Blue defends with a Mako-12 shotgun (C4 / M1 / L0) and starts at B Site.
- **Beat 1:** Red picks **Mid + Peek**. Blue picks **Connector + Hold**. Mid-Connector is a Close sightline, so there's contact. Peek beats Hold, and Red shoots: Close 2 damage, **Blue HP 4→2**. Both positions are now known.
- **Beat 2:** Blue expects a push and falls back to **B Site + Hold**. Red pushes to **Connector + Rush**. Connector-B Site is Mid. Hold beats Rush, and Blue shoots: shotgun Mid 1, **Red 4→3**. (Had Blue stayed at Connector, Red's Rush would have run into a Close Hold: shotgun 4, a one-shot. Red took a risk and got away with it.)
- **Beat 3:** Red reads that Blue won't leave the site and plays **B Site + Rush**. Blue, burned by Beat 1's Peek, decides to swing out first and plays **B Site + Peek**. A Hold would have won (and one-shot Red at Close). Rush beats Peek, same position, Close 2 damage, **Blue 2→0, eliminated.** **Red wins Round 1 (1-0)** with streak 1. One more down, without dying, unlocks the **Recon Drone** for Round 2.

---

## 3. Comparison and recommendation

### 3.1 Comparison table (1 = low, 5 = high; for Risk, lower is better)

| Concept | Structure | Depth | Simplicity | CoD feel | Mobile fit | Novelty | Risk | Match |
|---|---|---|---|---|---|---|---|---|
| **1. Point Man** | 1v1, deck = loadout, 3×3 rooms, Hardpoint | 4 | 3 | **5** | 4 | 4 | Med (balancing generated decks) | 10-12 min |
| **2. Fireteam** | 3v3, simultaneous plans, lanes, Domination | 4 | 3 | 4 | 3 (landscape) | 3 | Med (6-body readability, ally-bot quality) | 8-10 min |
| **3. Behind the Line** | Solo roguelite, deckbuilder, telegraphed enemies | 4 | 4 | 3 | **5** | 2 | **Low** (proven genre) | 25-35 min run |
| **4. Tick Rate** | Draft, then a time track, TDM | **5** | 2 | 4 | 3 | **5** | High (the time track is hard to read) | about 10 min |
| **5. Sightline** | Board game, tile-built map, in-match market | **5** | 1 | 4 | 1 | 3 | High (LOS AI, length) | 20-40 min |
| **6. Snapshot** | Simultaneous-reveal S&D duel | 2 | **5** | 4 | **5** | 4 | Med (can feel like coin-flips) | 4-6 min |

### 3.2 Recommendation: prototype **Point Man** first and **Snapshot** second

**Point Man** is the one that answers the head's brief most directly: *one character, two weapons, perks and stuff, improving our own character, fighting on a map.*
- It is the only concept where **the collection loop and the match loop are the same object.** Unlocking an attachment literally rewrites your deck, which makes pillar 7 ("every match moves a bar") felt in the next match, not just seen in a menu. That is the strongest retention hook of the six.
- **Hold Angle** gives cards an honest skill expression in place of aim, and the 3×3 room map is the smallest board that still has sightlines, flanks and power positions. It fits a phone screen in portrait.
- It uses all four CoD loadout layers (weapons, equipment, perks, streaks) without any of them being decorative.
- The risk is balance: every loadout generates a different deck. It is manageable, because the shared weapon table (§0) has only 6 rows and attachments are small trade-offs. A headless sim (KillingCard-style `tests/tools/*_check.gd`) can sweep loadout pairs.

**Snapshot** is the cheap second:
- It can be paper-tested in a day and prototyped in about a week. It isolates the riskiest feel question, "does a card read feel like a gunfight?", at the lowest cost.
- It shares Point Man's weapon table, loadout data and collection, so if Point Man ships, Snapshot becomes its **quick mode** (and a daily ladder), not a separate game.
- Its risk ("it's rock-paper-scissors") is tested directly: if weapon range, map positions and Noise make the reads informed rather than random, the stance triangle works. If playtesters call it a coin-flip, we learn that cheaply.

**Long-term shape (not for the first prototype):** **Behind the Line** is the natural solo campaign for the same loadout collection, using Point Man's cards against telegraphed AI. **Fireteam** is the fallback if the head prefers maximum reuse of KillingCard's lanes. Tick Rate and Sightline are the most novel and the riskiest; I'd park them.

### 3.3 Reuse

**From KillingCard (`projects/killingcard/source/project-killingcard/`). Original code and data only; nothing under `assets/licensed/` is touched or referenced.**

| What | File(s) | Used by |
|---|---|---|
| Loadout data model (Primary, Attachment, Perk, Killstreak slots; Handling-like `rotations_per_round`; attachment pools) | `scripts/data/loadout_item.gd`, `data/loadout/*.tres` (Kestrel AR-7, Wasp-9, Longreach .338, Bastion-60, Grit, Extended Mag, Foregrip, Holo Sight, Recon Drone, Sentry Turret, Mortar Barrage, Attack Helo ...) | All. Re-add the Secondary, Lethal and Tactical slots that `kc-loadout-cut` removed (the enum and validation already existed). |
| Streak meter, streak tray, reset on down | `scripts/rules/streak_tracker.gd` | All |
| Score-to-target, round cap, overtime, draw | `scripts/rules/mode_rules.gd` (Zone Control is close to Domination; add Hardpoint and S&D rows) | 1, 2, 4, 6 |
| Match state + hooks pattern, deterministic seeds, clone for AI search | `match_state.gd`, `match_hooks.gd`, `match_clone.gd` | 1, 2, 4 |
| Beat-ordered firefights, First Shot, Initiative | `scripts/rules/firefight_resolver.gd`, `firefight-order.md` | 2 (direct), 1 (Hold Angle ordering) |
| Fair AI by construction (AiView), greedy planner with personalities | `scripts/ai/ai_view.gd`, `ai_planner.gd`, `ai_personality.gd` | 1, 2 (bots), 3 (intent-based is simpler) |
| Run map, shop, events, modifiers, save | `scripts/run/*` and `run-v2.md` (bosses with one rule, Operators with passive + ability) | 3 |
| Inspect on right-click / long-press, gesture | `scripts/ui/card_inspector.gd`, `press_gesture.gd`, `card_info.gd` | All (studio UX rule) |
| Banner card frame and calling cards as profile banners | `banner_card.gd`, `banner_view.gd`, the original banner art pipeline | Meta (calling-card rewards) |
| Feedback FX: kill feed, hit markers, tracers, streak arc, call-in takeover, float text, synth SFX | `scripts/fx/*` | All |
| Minimap, score bar, match intro/end banners | `minimap.gd`, `score_bar.gd`, `match_intro.gd`, `match_end_banner.gd` | 1, 2, 4, 6 |

**Studio prior art:**
- **Killstreak** (`projects/killstreak/documentation/design/core-rules.md`): the original "the loadout is your Operator" ruleset. Its perk and streak rulings (equipment kills count for the streak, killstreak kills don't) carry over as written.
- **KillingCard Run v2**: the run map structure, bosses and Operators for Behind the Line.
- **DeadDraw**: the solo card-crawl rhythm (deal, resolve, carry forward) is a fallback encounter format for Behind the Line.
- **CardZone / Warbuilder**: deckbuilder market and print-and-play constraints for Sightline. Warbuilder's location-by-location loot is a possible Behind the Line event type.
- **CallingCard** and **Calling Card Tiles** (`studio/concepts/calling-card-tiles/`): making calling cards worth collecting. Here they are earned feat banners shown on the match intro, which is the same value proposition.

---

## 4. Questions for the studio head

**Q1. Which concept(s) should we prototype?**
- A. Point Man only.
- **B. Point Man, plus Snapshot as a cheap feel test that later becomes Point Man's quick mode. (Recommended.)**
- C. Fireteam: the most KillingCard code reuse; closest to the current lane board.
- D. Behind the Line: PvE first, the lowest risk and the strongest single-player meta.

**Q2. Who is the opponent in the first prototype?**
- **A. AI only (KillingCard-style fair AI with personalities). (Recommended: fastest to test, no netcode.)**
- B. Local hot-seat, two humans on one device.
- C. Async online PvP (turn-based duel by link).

**Q3. How much is hidden on the map? (This sets how much "fog of war" the CoD feel has.)**
- **A. Open positions with hidden reactions (Hold Angles face-down; recon reveals them). (Recommended for Point Man: readable on a phone, and the bluff lives in the Hold.)**
- B. Fully hidden positions with Noise from sprinting and firing (Snapshot-style everywhere; more tension, harder to read).
- C. Hybrid: positions are public only while in an enemy's sightline.

**Q4. Which screen do we design first?**
- **A. Phone portrait first (map on the top half, hand on the bottom), scaling up to PC. (Recommended: both recommended concepts were sized for it.)**
- B. PC / landscape first, phone later.
- C. Both from day one (costlier UI work).

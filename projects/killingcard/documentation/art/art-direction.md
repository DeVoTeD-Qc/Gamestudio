# KillingCard: art direction (DA) v1

*Sr Game Artist · 2026-11-10 · Board task kc-da · Godot 4.4.1 web, phone landscape first*
*Visual style page: `studio/art/killingcard-da.html` (palette, type, card frames, do/don't, audit with public screenshots).*
*This document sits above the existing art docs. Where it disagrees with them, this wins; where it is silent, they still apply: `banner-art-direction.md` (banner composition, tags, crops), `ui-kit-prompt-pack.md` §2 (kit materials and tokens), `mw3-pitch-set.md` (the private pitch set).*

---

## 1. The vision

**KillingCard is an operator's field case opened at dusk.** The case is quiet: matte gunmetal plates, steel rims, khaki orders paper, every label stamped and short. What sits inside it is loud: the cards are collectible trophies, painted with drama, and they are the only thing on screen allowed to shout. The player reads the board like a briefing (teal is us, red is them, amber is "act now") and collects banners the way a multiplayer veteran collects calling cards: each one earned, each one shown off, each one framed the same way so a painted original and a licensed calling card sit in the same case without a seam.

### Pillars

1. **Quiet case, loud card.** UI chrome is matte, dark and calm. The card art is the colour, the light and the energy. Art is never dimmed, tinted or covered by UI except in its calm icon columns.
2. **Briefing room.** Information arrives as orders: stamped labels, numbered steps, khaki paper for Tactics, mono type for intel and logs. Short words, no fluff. Every screen answers "what do I do now".
3. **Calling-card collectible.** A banner is a trophy. Finishes (Gold Leaf, Machined, Prism, Starfield), alt arts and the Elite star are earned and visibly shown off in the Codex, the Loadout, the after-action and the title.
4. **One colour, one meaning.** Teal = you. Red = rival and danger. Amber = act now. Brass = the Operator. Green / red numbers = up / down. No other hue gets a meaning, and no meaning gets two hues.
5. **Hit, then explain.** Killstreaks and strikes land hard and fast (one beat of impact), then the board settles and says in plain words what changed.

### What every screen should feel like

| Screen | Feels like | Key move |
|---|---|---|
| Title | Opening the case: your best card on top | Wordmark + the player's equipped banner + one amber CTA |
| Run map | A paper map pinned to the briefing table | Pins, string lines, stamps; the boss is a red-circled target |
| Match board | A tactical table under a lamp | Board recedes; cards and the three signal colours carry the read |
| Hand | Cards fanned in your glove | Full-colour cards, playable ones lift; unplayable ones lose their amber cost, not their art |
| Inspector | Pulling one card into the light | One big card + a paper rules sheet; nothing else |
| Duel hub / deck builder | The armoury locker | Rows of cards on steel racks; one amber button per screen |
| Loadout | Kitting up | The Operator is the hero: big weapon art, brass frame, band on show |
| Codex | A collector's binder | Owned cards in full colour with their finish; unowned ones as stamped silhouettes |
| After-action | A debrief sheet with a stamp | VICTORY / DEFEAT stamped on orders paper, MVP card shown large |
| Killstreaks | A call-in on the radio, then the strike | Side-coloured banner, one impact, a persistent marker |

---

## 2. Colour

Tokens already exist in code (`card_theme.tres`, `hud_theme.tres`, `card_look.gd`, `synergy_glyphs.gd`, `mastery_bands.gd`); this table fixes their **roles**. Changes from today are marked **NEW** or **CHANGE**.

### 2.1 Case (neutrals): 80% of every screen

| Token | Hex | Role |
|---|---|---|
| Slate ink | `#12161A` | Deepest background, recessed faces, text on amber |
| Gunmetal | `#232A31` | Panels, tiles, button faces |
| Panel hi | `#2E3740` | Hover, raised panels |
| Steel rim | `#3A444D` | Rims, outlines, empty slots |
| Edge grey | `#4A535B` | Button and modal outlines |
| Muted | `#7D8790` | Captions, idle icons |
| Fog white | `#D8DEE3` | Text, white icons |
| Orders khaki | `#B8913A` / face `#2B2716` | Tactic (T1) frame, orders paper, after-action sheet |
| Paper | `#E9DFC6` / ink `#2B2716` | **NEW**: light orders paper for the run map and debrief sheet (dark text on light) |

### 2.2 Signals: the only hues with meaning

| Token | Hex | Role | Never |
|---|---|---|---|
| **You** (teal) | `#2EC4B6`, deep `#0F2F2C` | Your FP reticle, selection, your control, your killstreaks | Never decoration |
| **Rival / danger** (red) | `#E5383B`, reticle `#FF5A5D`, deep `#341113` | Rival FP, rival control, INCOMING, HOSTILE, boss, losing | Never a frame around a friendly CTA (today's drill callout box) |
| **Amber: act now** | `#FFB020`, pressed `#E59A12` | READY, the one primary button, cost hex, a killstreak that is ready to call | Max **one** amber button per screen; never bar charts or labels |
| Damaged | `#F2A33A` | Hurt Armor plate, crack | Not for buttons |
| **Brass: Operator** | `#C9A227`, dark `#5A4512` | Operator frame, Elite star, dog tag | Not on normal cards |
| Buff up | `#7CF29A` | Raised number, active synergy | Not as a killstreak colour |
| Debuff down | `#FF6B6B` | Lowered number | |
| Heal | `#8EDB6A` | Heal numbers | |

**CHANGE (killstreaks):** today each killstreak has its own hue (Mortar `#FF8A3D`, Helo `#C9E265` lime, Sentry teal, Gunship red). Lime reads as "buff" and orange as "amber". From now on a killstreak is coloured by **its owner** (teal yours, red rival); the **kind** is told by its icon and name. Amber appears only while it is ready to call.

### 2.3 Traits (chips and rail only)

Vanguard `#F2B544` · Spec Ops `#8FB8FF` · Heavy `#C9D1D8` · Undead `#8EDB6A`. Traits live in chips, never in frames or backgrounds. (Vanguard sits close to amber: keep it a chip-sized colour only.)

### 2.4 Rarity and finish ladder

Rarity is shown by **frame keyline + band finish**, never by recolouring art.

| Level | Keyline | Band finish (code, `mastery_bands.gd`) |
|---|---|---|
| Recruit / Standard Issue | Steel `#4A5560` | none (Standard Issue grey-green `#5E6B5A`) |
| Trained | Gold `#C9A227` | **Gold Leaf** `#C9A227` / `#7A5E12` / `#F3D36B` |
| Veteran | Steel white `#D9DEE3` | **Machined** `#D9DEE3` / `#7E878F` / `#FFFFFF` |
| Elite | Prism blue `#3E8EDE` | **Prism** `#3E8EDE` / `#1B3F78` / `#9FE3FF` |
| Operator top tier | Night violet `#3A1C6E` | **Starfield** `#3A1C6E` / `#120A2E` / `#FFF4FF` |
| Elite ★ (reward card) | Brass + star | as its level |

---

## 3. Typography

All bundled, all OFL (`assets/fonts/`), all on Google Fonts.

| Use | Font | Size (logical, phone) | Case |
|---|---|---|---|
| Wordmark, stamps (VICTORY, CLASSIFIED-style labels with our own words) | **Stardos Stencil Bold** | 28-64 | UPPER |
| Screen titles, buttons, card names | **Barlow Condensed ExtraBold / Bold** | 14-28 | UPPER, +4% tracking |
| Card numbers (FP, Armor, cost) | **Barlow Condensed ExtraBold** (`card_numbers_barlow.tres`) | 12-20 | figures |
| Body, rules text | **Barlow Medium** | 11-13 (never under 10) | Sentence case |
| Flavour lines | **Barlow Condensed Medium Italic** | 11-12 | Sentence case |
| Intel, logs, killfeed, map coordinates | **Share Tech Mono** | 10-12 | UPPER |

Rules: max 3 fonts on one screen. **Oswald retires** to a fallback (two condensed number fonts is one too many). Stardos Stencil is for the wordmark and stamps only, never body or buttons. Numbers sit on discs and plates, never loose.

---

## 4. Shapes, materials, frames

- **Steel plate** (the case): matte gunmetal, 1-2 px steel rim, **45-degree chamfer on one or two corners** (top-left + bottom-right), one soft top-left bevel. No rivets, no rust, no scratches, no fake screws, no grunge.
- **Orders paper** (Tactics, run map, debrief): khaki or light paper, faint fibre, a typed feel, square corners, a single fold or clip at most. Paper is where rules and orders live.
- **Hazard stripes**: amber/black for READY-to-call and drop zones; red/black for HOSTILE. Only on edges, never behind text.
- **Glass and glow**: only for signals (selection glow, ready glow). Glow is the signal colour at 30-60%, 6-12 px soft.
- **Shapes**: hexagon = cost (amber), circle reticle = FP (side colour), shield plate = Armor (steel), rounded rectangle = chip, chevron = rank/level, diamond = Field. One shape per meaning across the game.
- **Corner radius**: 2-3 px on plates, 0 on paper, 50% on discs. No soft pill buttons except chips.

---

## 5. Iconography

1. **Bold white pictograms**, tinted by code: one icon, every state, both sides.
2. **Read at 24 px**, survive at 17 px. 2-3 shapes, 2.5 px min stroke at 24 px, filled silhouettes over outlines.
3. **Side view or three-quarter top view**, compact and near-square silhouettes (no thin rotors or long flat wings).
4. **One meaning, one icon.** A shield is Armor, an eye is PREVIEW, a reticle is FP: nothing else may borrow them.
5. **No text, letters or numbers inside icons.** No real weapon models, no insignia, no skulls (the boss gets a target mark, not a pirate skull).
6. Icons sit on a dark socket (`#12161A`, 1 px rim) on top of art, never straight on a painting.
7. Code-drawn glyphs (trait chips, bolt, bands) follow the same rules and are the fallback when a kit icon is missing.

---

## 6. Card anatomy

Both forms share one frame family: **the display case**. The art window is fixed; everything else is code-drawn chrome around it.

### 6.1 Banner card (board, C1+, 4:1)

```
+--[cost hex]------------------------------------------------[abilities chip]-+
| icon column |           ART WINDOW (focal 15-85%)            | icon column  |
| (calm 15%,  |      full colour, never dimmed or tinted       | (calm 15%,   |
|  traits)    |                                                |  FP + Armor) |
+--[trait chips]------------------------------------[FP reticle][Armor plate]-+
 keyline: side colour when selected / frontline; brass for Operator & Elite; level band under the frame
```

- Left column: traits (bottom), cost hex and level coin on peek (top).
- Right column: abilities chip (top), FP reticle + Armor plate (bottom).
- A 15% black side gradient at ~35% sits under the icon columns (safety net, art should not need it).
- Rarity: keyline + an optional 3 px band strip along the bottom edge.

### 6.2 Hand card (Y2+, portrait)

```
+------------------------------+
|(cost) NAME              [lvl]|  name bar: Barlow Condensed, steel / khaki / brass by kind
+------------------------------+
|        ART WINDOW            |  the same 4:1 banner band (the art crop never changes)
+------------------------------+
| KIND · keywords with icons   |  rules: Barlow 11-13, icons inline
| rules text / flavour italic  |
+--[sockets]------[FP][Armor]--+  bottom rail: abilities, then numbers bottom-right
```

- Frames by kind: **Unit** steel `#4A5560` / face `#1B2126`; **Tactic** khaki orders `#B8913A` / face `#2B2716`; **Field** steel with a diamond tab; **Killstreak** steel with an amber hazard tab; **Operator** brass `#C9A227` / face `#1E1A10`.
- Unaffordable: the cost hex goes grey and the card drops 4 px; the art stays full colour.
- The same frame is used in hand, Codex, deck builder, Loadout, rewards and the inspector (bigger). No third card layout.

### 6.3 Original art and licensed calling cards in one case

- Both fill the **same art window** at the same crop; the frame, numbers, chips and keylines are drawn by code over neither the focal zone nor the art's centre.
- The frame is deliberately **neutral** (steel, no colour) so it holds a dusk painting and a neon-maximal calling card equally.
- Licensed cards often have their own baked borders or text: the window crops 3% each side and the icon-column gradient covers side text. If a licensed card still fights the frame, it is skipped, not edited.
- Public originals are painted a notch **more saturated and contrasty** than today (see 7) so the two builds feel equally loud.
- Rarity, side and level live in the frame and bands, so they work the same whatever art is in the window.

---

## 7. Illustration style (original art)

**House style: "Theatre at dusk."** Painted, semi-realistic, graphic-novel edges; strong silhouettes; one warm practical light against a cool sky.

- **Light:** dusk or night. A cool sky (blue-grey, teal or violet) and one warm key light (sodium amber, muzzle flash, fire). Strong rim light on the subject. Three value groups max.
- **Subjects:** invented operators in olive, khaki and charcoal gear; **faces covered** (masks, goggles, visors); fictional weapons and vehicles. Tactics show objects, places or events, **never a soldier as the subject** (Ammo Resupply = crates, not a man).
- **Framing:** the 4:1 banner band rules (`banner-art-direction.md` §1.3-1.4 and §3): one subject, head and weapon in the middle 70%, horizontal flow, calm darker side columns, key detail between 30% and 65% of the full image height.
- **Theatres:** the first set is all Port (amber over blue dusk, cranes, containers). Every new pack adds a theatre with its own sky, so the board is not one colour: Port dusk (amber / slate blue), Arctic dawn (rose / ice cyan), Desert haze (ochre / teal), Night city (sodium / violet), Jungle rain (amber / deep green). Each theatre keeps the same light logic and gear.
- **Collectible alt arts:** Trained-and-up alt arts and rewards may break the house style into the graphic families of `banner-art-direction.md` §1.2 (Ink Comic, Retro Screenprint, Minimal Emblem, Neon Synth, Woodblock). That is where KillingCard gets the calling-card variety: the base card is the house painting, the earned card is the show-off.
- **Push:** a little more saturation and contrast than the current set; brighter warm accent; the subject must pass the squint test at 160x40.

---

## 8. Motion and VFX

The language is **call-in, impact, settle**, matching the kc-ks-seq sequences.

| Beat | Time | What happens |
|---|---|---|
| Call-in | 0.25 s in, 0.6-0.9 s hold | A steel banner slides in from the owner's side (teal rim for you, red hazard rim for rival), icon + name + one line of effect |
| Telegraph | until resolve | A persistent marker on the target (INCOMING hatch in the owner's colour, a pin, not a full-column fill) |
| Impact | 0.1-0.3 s | Hit-stop 50-80 ms, 4-8 px shake on the struck column only, a white flash max 2 frames, smoke and sparks in warm light |
| Numbers | 0.4 s | Damage numbers pop (scale 1.3 > 1.0), red / green, Barlow Condensed |
| Settle | 0.3 s | Downed cards crack and drop; one log line in mono; the board is static again |

Rules: one big moment at a time (queue them); motion follows the read order A > B > C; easing is snappy out, soft in (ease-out-back 0.25 s for appear, ease-in 0.15 s for leave); no full-screen flashes; everything works with reduced motion (fades only, no shake). Particles are warm (sparks, embers, dust) or the side colour (glow), never rainbow.

---

## 9. Do and don't

| Do | Don't |
|---|---|
| Keep UI chrome matte and neutral; let the art be the colour | Colour panels, tint art, dim card art to show state |
| One amber button per screen | Several amber PLAYs, amber charts, amber labels |
| Colour killstreaks by owner, tell kinds by icon | A new hue per killstreak (lime helo, orange mortar) |
| Tactics show objects, places, events | A soldier on a Tactic |
| Faces covered, fictional gear, invented names | Real people, real weapon or vehicle models, maker marks |
| Stencil only for wordmark and stamps | Stencil body text or stencil buttons |
| Original finishes (Gold Leaf, Machined, Prism, Starfield) | Blob camos or copied mastery camo patterns |
| Target mark for the boss | Skulls, gore, blood, red that reads as blood |
| Text drawn by the game | Letters, numbers, logos or stamps baked into art |

**IP rules (public build, always):** no Call of Duty or Modern Warfare logos, wordmarks, emblems, UI, HUD shapes or trade dress; no copied calling-card designs, camo patterns, operator, map, killstreak or weapon names (use our own names: Mortar Barrage, Attack Helo, Kestrel AR-7...); never name a franchise, game, studio or "calling card" in an image prompt; no flags, insignia, unit patches, roundels, red cross or red crescent. Licensed MW3 images stay in git-ignored `assets/licensed/`, ship only in the private pitch export, and never appear in docs, screenshots, the style page or prompts.

---

## 10. Prompt template (ChatGPT image)

One image per chat. Landscape 3:2 (1536x1024). Paste, fill the brackets.

```
Original painted game card illustration, landscape 3:2, 1536x1024.
Subject: [one invented operator / one object / one event], [verb, e.g. aiming a long fictional rifle],
seen [side / three-quarter], filling the middle of the image.
Style: semi-realistic painting with graphic-novel edges, bold silhouette, visible brushwork,
strong warm rim light, three value groups, slightly saturated, high contrast.
Theatre: [Port dusk: amber sodium lights over a slate-blue sky, cranes and containers |
Arctic dawn: rose light over ice cyan | Desert haze: ochre over teal | Night city: sodium over violet |
Jungle rain: amber over deep green].
Gear: olive, khaki and charcoal tactical gear, face covered by a mask, goggles or visor,
fictional weapon with no markings.
Composition: head and weapon between 30% and 65% of the image height and in the middle 70% of the width;
left and right 15% calm, darker and simple; horizontal flow; simple sky top and simple ground bottom.
No text, letters, numbers, logos, flags, insignia, patches or stamps. No real people, no real weapon or
vehicle models. No blood or gore.
```

For a collectible alt art, swap the Style line for one family block from `banner-art-direction.md` §5.0 and keep the rest.

---

## 11. Current screen audit (public build, 2026-11-10)

Screenshots: `studio/art/killingcard-da/*.png` (shot_wire2, shot_cards, shot_duel, shot_ks, shot_bands; licensed art off).

| Screen | Rating | 3 biggest gaps |
|---|---|---|
| Title | **Partly** | 1. Wordmark is plain text, no lockup. 2. The drill invite is framed in danger red. 3. Nothing collectible on show (no equipped banner); three CTAs compete. |
| Run map | **Partly** | 1. Generic round mobile-game nodes, not a briefing map. 2. Boss is a big red skull disc (off-tone). 3. Map background is almost invisible; the "NEXT" white box breaks the palette. |
| Match board | **Fits** | 1. The same few paintings repeat on most cards, so columns blur. 2. Empty slot grid and INCOMING hatch are louder than the cards. 3. Left rail stacks many tiny icons and numbers. |
| Hand | **Partly** | 1. Unaffordable cards look muddy (art dimmed). 2. Ammo Resupply (a Tactic) shows a soldier. 3. The play-preview popup is a third card layout. |
| Inspector | **Partly** | 1. Three copies of one card at once (banner, card, text). 2. Placeholder text ("Banner: Marksman (placeholder)"). 3. "?" buttons are blank plates, not icons. |
| Duel hub and deck builder | **Doesn't fit** | 1. Flat placeholder arts (pink and green silhouettes) next to paintings. 2. Amber everywhere (PLAY x2, bars, picks, VS AI). 3. Deck curve is a plain bar chart, not part of the case. |
| Loadout | **Partly** | 1. Operators shown in small text-heavy tiles, not as heroes. 2. Locked Operator has placeholder purple art. 3. Bands and mastery not shown. |
| Codex | **Partly** | 1. Reads as a spreadsheet, not a binder. 2. Placeholder flat arts (Brawler). 3. No finishes, alt-art count or owned / unowned state on the cards. |
| After-action | **Partly** | 1. Empty stats ("---", "-") with no hero moment. 2. No MVP card or calling card shown. 3. VICTORY is plain teal text, no stamp; scene too dark. |
| Killstreak sequences | **Partly** | 1. Per-kind hues (lime helo, orange mortar) clash with buff green and amber. 2. Dashed boxes, hatching and slanted stripes stack into noise. 3. Teal mono log lines repeat the banner text. |
| Mastery bands | **Fits** | Original finishes, readable; Gold Leaf flakes read as a checker at 32 px (soften). |

## 12. Update list (prioritised)

| # | Update | Owner | Size |
|---|---|---|---|
| 1 | Replace every flat placeholder art (Brawler, Blackout, Smoke Screen, Aid Station, Listening Post, Field cards, Bastion-60...) with house-style paintings via the prompt template | Artist | L |
| 2 | Re-art Tactics with a soldier as subject (Ammo Resupply first) as objects, places or events | Artist | M |
| 3 | Killstreak colour by owner, kind by icon; retire lime and orange; quieter telegraph (one hatch, no dashed box + stripes) | Technical Artist | S |
| 4 | One display-case frame family everywhere: hand preview and inspector use the Y2+ card; inspector = one big card + paper rules sheet | UI/UX | M |
| 5 | Never dim art for state: unaffordable = grey cost hex + drop, not a dark overlay | UI/UX | S |
| 6 | Amber discipline: one amber button per screen (Duel hub, deck builder, title); drill invite framed in steel, not red | UI/UX | S |
| 7 | Title lockup: original stencil wordmark + the player's equipped banner on the case | Artist + UI/UX | M |
| 8 | Run map as a briefing map: light orders paper, pins, string lines, red-circled boss target (no skull) | UI/UX + Artist | M |
| 9 | After-action as a debrief sheet: stamp VICTORY / DEFEAT, MVP card large with its band, real stats only | UI/UX | M |
| 10 | Codex as a collector's binder: finishes on cards, owned / unowned silhouettes, alt-art count | UI/UX | M |
| 11 | Second theatre pack (Night city or Arctic dawn) so the board is not all amber-on-blue | Artist | L |
| 12 | Type cleanup: Oswald to fallback, Stardos Stencil only for wordmark and stamps | UI/UX | S |

## 13. Questions for the head

1. **House style.** (a) *Recommended:* one painted "Theatre at dusk" house style for every base card, with the graphic families (comic, screenprint, emblem, neon) reserved for earned alt arts. (b) Fully mixed styles on every card (the v1 banner plan). (c) One style only, no alt-art families.
2. **Grit.** (a) *Recommended:* clean tactical (matte steel, no rust or scratches; grit only inside the paintings). (b) Grittier worn kit (scratched plates, dirt, stencil everywhere).
3. **Collectible lean.** (a) *Recommended:* medium: finishes, alt arts and a binder-like Codex, the equipped banner on title and after-action; no loot-box style reveals. (b) Heavy: pack openings, shiny reveal animations, rarity glows on the board. (c) Light: collection is a list.
4. **Killstreak colour.** (a) *Recommended:* colour by owner (teal / red), kind by icon. (b) Keep a signature hue per killstreak (needs new hues that clash with nothing).

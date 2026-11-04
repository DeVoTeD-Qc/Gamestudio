# CardZone: Art Direction (v1.0)

*Sr Game Artist · 2026-11-04 · Board task `cz15` · Phase: plan · Feeds `cz16` (procedural placeholder art kit), `cz10` (match screen), `cz13` (shell)*
*Sources: `../../design/mechanics/loadout-loop-spec.md` v0.2, `../../production/prototype-scope.md`, studio icon `studio/icons/cardzone.svg`. Visual sample: `art-direction-sample.png` (source `art-direction-sample.svg`).*

## Direction in one paragraph
**"Survey stencil at dusk."** Ridge Hollow is a grounded, near-future island: basalt, dune grass, rust-streaked docks, a radio mast. The UI reads like a field kit that someone has stencilled and labelled by hand. It has flat shapes, clipped-corner plates, short imperative labels and no gloss. Night violet is the *safe* world and acid lime is the *gas*, so the one thing that matters on the map is always the loudest colour. Cards are pale paper plates with dark ink, which makes numbers win over art at phone size. The recurring motif is the **clipped tag**: a rectangle with its top-left and bottom-right corners cut at 45°. It appears on rarity chips, area tiles, buttons and the card frame. Icons are **stencil-cut**: solid shapes with one or two 2 pt bridges, like spray-paint stencils on supply crates. Target: an iPhone in landscape, reference 844×390 pt (2532×1170 px @3x), Godot 4.4.1 Compatibility renderer, flat 2D, placeholder art kit under 5 MB.

## 1. Palette
| Group | Token | Hex | Role |
|---|---|---|---|
| **Zone** | `zone_violet` | `#2B1840` | **Safe-zone colour.** App background, safe areas behind the map, panels' base |
| | `zone_dusk` | `#45285F` | Raised panels, opponent panel, inspector backdrop |
| | `zone_edge` | `#B49CFF` | Safe boundary line, focus ring, selected tile outline (7.0:1 on `zone_violet`) |
| **Gas** | `gas_lime` | `#9BD43A` | **Gas colour.** Gassed tile overlay, gas icon, Zone "Gas closes" cards |
| | `gas_glow` | `#E2FF8A` | Gas border dashes, gas warning text on violet (14.5:1) |
| | `gas_shade` | `#3E5A12` | Dark stripe of the gas hatch |
| **Island** | `basalt` | `#2F333B` | Rock, map linework, area glyphs |
| | `dune` | `#D8C8A2` | Open ground on area tiles |
| | `shoal` | `#2C6E7F` | Sea around the island, water in Docks |
| | `rust` | `#B0573A` | Built structures (Docks, Rail Yard, Old Town roofs) |
| | `scrub` | `#7A8466` | Grey-olive vegetation (kept dull so it never reads as gas) |
| **Card / UI** | `paper` | `#F4F1FF` | Card face, primary text on violet (14.4:1) |
| | `ink` | `#1A1424` | Text and icons on cards, chip outlines |
| | `hit_red` | `#E5484D` | Hit band, damage numbers, Down badge (always with an icon, never colour alone) |
| | `brace_steel` | `#C9D3E0` | Brace shield fill |

**Rules:** lime appears **only** for gas and Zone warnings. Violet appears only for "safe" and the UI frame. Neither is ever used for rarity, team or loot.

## 2. Rarity: five colours, five letters
The spec's genre default (grey, green, blue, purple, gold) is **replaced**: green would read as gas and purple as the safe zone. The new set is a **lightness ladder**: each step up in rarity is lighter, so rarity reads in greyscale as "darker = common, brighter = rarer".

| Letter | Name | Hex | Letter colour | Ticks | L\* normal | L\* greyscale order | Protan / Deutan / Tritan L\* |
|---|---|---|---|---|---|---|---|
| **C** | Common | `#3F4552` slate | `paper` | 1 | 29 | 1 (darkest) | 30 / 29 / 29 |
| **U** | Uncommon | `#0F7A70` deep teal | `paper` | 2 | 46 | 2 | 48 / 44 / 47 |
| **R** | Rare | `#4C8AF2` signal blue | `ink` | 3 | 58 | 3 | 62 / 56 / 61 |
| **E** | Epic | `#FFB070` flare amber | `ink` | 4 | 78 | 4 | 74 / 81 / 75 |
| **L** | Legendary | `#FFEE80` beacon yellow | `ink` | 5 | 93 | 5 (lightest) | 92 / 94 / 92 |

**Chip:** a clipped tag with a 1.5 pt `ink` outline (so the light E and L chips hold their edge on `paper`) and the letter in Barlow Condensed SemiBold. The inspector chip adds the full word and 1 to 5 ticks. Starter cards have **no chip** (an empty dashed outline), and Hit cards use the `hit_red` band instead.

**How this was checked** (`projects/cardzone/tools/palette_check.py`, numbers above):
- **Greyscale:** CIE L\* of each colour. Neighbours are at least **12 L\* apart** (29 / 46 / 58 / 78 / 93), and the order runs C → L dark to light.
- **Colour-blind:** each colour was simulated with Machado et al. (2009) at full severity for protanopia, deuteranopia and tritanopia, then L\* was measured again. The order holds, and the closest pair stays at least **12 L\* apart** in every mode (protan R–E 13, deutan U–R 12, tritan U–R 14).
- **Never colour alone:** every chip carries its **letter**, and the inspector also shows **ticks** (1–5). A player who sees no colour at all still reads "R" and three ticks.
- **Contrast:** the letter colour per chip is at least **4.6:1** (C 8.6, U 4.7, R 5.3, E 10.0, L 15.2).
- **Against world colours** the near pairs are E amber vs `gas_lime` (similar lightness) and R blue vs `zone_edge` (protan). They never share a role or a spot: rarity appears only on cards and loot pips, and loot pips on a gassed tile are greyed out with a padlock.

## 3. Card layouts (63:88 card ratio)
Sizes are in points. Pixels are given @3x, the iPhone reference. **Floors: every numeral ≥ 24 px (8 pt). We use ≥ 12 pt (36 px) for game-critical numbers. Every tap target ≥ 44×44 pt.**

| Element | **Compact card** (hand, line, loadout strip): **84×118 pt** (252×354 px) | **Inspector card** (long-press or tap ⓘ): **220×308 pt** (660×924 px) |
|---|---|---|
| **Cost** (Search to loot) | Top-left `ink` disc Ø 22 pt, numeral **14 pt / 42 px** in `paper` | Top-left disc Ø 36 pt, numeral **24 pt / 72 px**, "SEARCH" caption 9 pt |
| **Type icon** | Top-centre, 16 pt stencil icon | Top-centre, 24 pt icon plus the type word (WEAPON / ITEM / ATTACHMENT) 11 pt |
| **Rarity** | Top-right chip 20×22 pt, letter **13 pt / 39 px** | Top-right chip 40×36 pt, letter **22 pt / 66 px**, full word and ticks under it |
| **Name** | Band at y 26–44, Barlow Condensed SemiBold caps **10 pt / 30 px**, one line. If it does not fit, use the data field `short_name` (e.g. "HUNT RIFLE"); never go below 9 pt | Band at y 44–70, **18 pt / 54 px**, one line |
| **Art window** | y 46–86, one silhouette in `basalt` on `dune` | y 72–192, silhouette plus area backdrop |
| **Brace value** | Bottom-left shield 26 pt tall, numeral **15 pt / 45 px**. With no Brace the shield is a 30 % ghost with "–" | Left edge shield 32 pt, numeral **24 pt / 72 px**, "BRACE" caption |
| **Damage (and range)** | Bottom-right: crosshair-burst icon plus DMG **15 pt / 45 px**, then "R" plus RNG **12 pt / 36 px**. Items show their main effect (Move/Search icon plus numeral) here instead | Stat bar under the art: DMG **24 pt** · RNG **24 pt**, with icons and captions |
| **Effect text** | Not shown (icons only) | Barlow Medium 12 pt / 36 px, keywords in SemiBold |
| **Card ID / attach** | Attached cards show as a 6 pt tab under the weapon with "+1 DMG" at 12 pt | Share Tech Mono 9 pt ID bottom-left, attach strip bottom-right |
| **Tap targets** | The whole card (84×118). At Pack, the **Hold** toggle is a 44×44 pt hit area on the top edge. With 6 or more cards in hand, cards overlap but keep a **≥ 44 pt** exposed strip | Close ✕ 44×44 pt, the card itself scrolls effect text |

The frame is a `paper` card with clipped corners (6 pt cut), a 2 pt `ink` border and a 4 pt rarity-colour stripe on the left edge. The rarity stripe repeats the chip, so a fanned hand still shows rarity when only the edges are visible. **Hit card:** a full-width `hit_red` band with a broken-shield icon and the word **HIT**, then "ADRENALINE: MOVE 1 / SEARCH 1" at 10 pt. **Held** cards get a `zone_edge` 2 pt outline and a "HOLD" tag. A **Down** badge is a `hit_red` downward chevron plus "+1".

## 4. Area tiles (Ridge Hollow, 7 tiles)
| | **Open** | **Gassed** |
|---|---|---|
| Shape | Clipped-corner plate. The 6 ring tiles are 120×64 pt and the Core is 136×76 pt; the whole tile is a tap target | Same plate |
| Base | `dune` ground, top-down glyph in `basalt` and `rust`: crane (Docks), silo (Farmstead), terraces (Quarry), mast (Radio Hill), roadside sign (Motel), sidings (Rail Yard), roof cluster (Old Town) | Base darkened 40 % and desaturated |
| Overlay | None | `gas_lime` at 55 % with a **45° hatch** (`gas_shade`, 6 pt pitch). The hatch carries "gas" in greyscale and for colour-blind players |
| Border | 2 pt `zone_edge` (safe) | 3 pt dashed `gas_glow` (10/5, as on the studio icon) |
| Label | Name in Barlow Condensed SemiBold 12 pt `ink` on a `paper` tag | Name plus a **GAS** tag (`ink` on `gas_glow`) and the gas icon |
| Info | Cover 1: a shield badge "1". Loot: one pip per pile, with the top card's rarity letter | Loot pips greyed out with a padlock (not lootable); "-1 HIT AT END" hint 10 pt |
| Pawns | Ø 28 pt discs: player `paper` with an `ink` chevron, AI `ink` with a `paper` square. They differ by **shape**, not colour | Same, plus a pulsing `gas_glow` ring on a pawn in gas |

## 5. Icon list (24 pt grid, stencil-cut, one colour; 16 pt and 32 pt exports)
| Group | Icons |
|---|---|
| Card types | weapon (crosshair-burst), item (crate), attachment (rail clip), starter (empty dashed tag), hit (broken shield), bounty (target tag with a star cut) |
| Stats and keywords | cost / search (magnifier), move (boot print), damage (crosshair-burst), range (concentric arcs with ticks 0/1/2), brace (shield), heal (cross-plate), pull (card plus up arrow), spent (card with a slash), attach (clip), down (chevron down plus "+1"), cover (half wall), fires twice (double chevron) |
| Map and Zone | gas (three rising cloud-blobs), safe zone (ring), supply drop (parachute crate), crate / eliminated cache (open crate), loot pile (stacked cards), pawn player, pawn AI, Zone card, route A / B / C (tag with letter), final circle (ring with a dot), padlock (gas-locked loot) |
| Actions | play, hold (pin), stow (tray with down arrow), end turn, undo, shoot, loot, move, patch up, ditch (bin), Adrenaline (lightning cut) |
| Loadout and HUD | loadout stack, next hand / armour (shield over cards), health stack (vertical plates), round counter, opponent hand (card backs), hidden (eye with a slash), public (eye), AI thinking (three dots), timer |
| Shell | info / inspect (ⓘ), pause, settings, close, back, confirm, dev panel (wrench), coach hint (speech tag), hot-seat pass (two arrows) |

## 6. Weapon and gear silhouettes (generic, fictional; side view, facing right)
| Class | Card | Silhouette read |
|---|---|---|
| Sidearm | P-9 Sidearm | Short square slide, grip at 100°, trigger guard as an open D, no hammer |
| SMG | Scrap SMG | Stubby box body, straight vertical mag, folded wire-loop stock, one welded patch plate |
| Pump shotgun | Pump Shotgun | Long barrel over a tube, chunky ribbed forend, straight solid stock |
| Hunting rifle | Hunting Rifle | Slim one-piece stock, long thin barrel, bolt knob, no visible mag |
| Assault rifle | Assault Rifle | Mid-length angular receiver, straight mag angled 10° forward, flat top rail, block stock |
| Marksman rifle | Marksman Rifle | Longest thin barrel, open skeleton stock, folded bipod, tall optic stub |
| LMG | Twin-Drum LMG | Heavy square receiver, **two round drums side by side** under it, loop carry handle, bipod |
| Anti-materiel | Longshot .50 | Widest silhouette: very long barrel, box muzzle brake, rear monopod spike, long scope |
| Attachments | Long Scope · Red-dot · Ext. Mag · Suppressor | Hooded tube · open square window · tall stepped mag · plain cylinder with two band rings |
| Throwables | Frag · Smoke | Ribbed rounded canister with a pull ring · tall can with a vent row |
| Gear | Plate Vest · Heavy Plate · Phantom Suit | Vest with one plate · vest with three stacked plates and a collar · hooded cloak silhouette with a frayed hem |

**No** real brands, model names or numbers, manufacturer marks, real camo patterns, flags, unit patches or insignia. Markings are fictional island stencils only (e.g. "RH-03", "CRATE 7").

## 7. UI tone and type (OFL fonts already in the studio: `projects/killstreak/.../assets/fonts/`)
| Use | Font | Size floor (@3x) |
|---|---|---|
| Card names, numerals, buttons, headers | **Barlow Condensed SemiBold** (caps, +2 % tracking), with tabular figures for stat numbers | 10 pt / 30 px names; 12 pt / 36 px numerals |
| Effect text, coach, settings | **Barlow Medium** | 11 pt / 33 px |
| Card IDs, Zone track, round, timers, dev panel | **Share Tech Mono** | 9 pt / 27 px (never game-critical) |

Voice: terse, imperative, calm. Labels are verbs in caps (HOLD, STOW, SHOOT, LOOT, END TURN). The numbers do the drama, not adjectives. Motion is short and mechanical: 120–180 ms slides, no bounce, plus one gas pulse (1.2 s) for danger.

## 8. Do and don't
| Do | Don't |
|---|---|
| Keep lime for gas and Zone warnings only | Use lime or green for Uncommon, health or "go" buttons |
| Pair every colour signal with a letter, icon, hatch or shape (rarity letter, gas hatch, pawn shape) | Tell player from AI, or open from gassed, by colour alone |
| Make numerals the largest thing on a compact card | Let art or the name crowd out cost, DMG or Brace |
| Use the clipped-tag shape and stencil icons | Use glossy bevels, metallic gradients, loot-beam glows or rarity "rays" |
| Draw gear as generic, chunky side silhouettes | Trace or hint at real firearms, brands, camo or insignia |
| Keep the island grounded: basalt, dune, rust, sea | Add sci-fi neon, holograms, cartoon mascots or a pastel "party island" look |
| Check every new screen in greyscale and with a deutan simulation | Ship a state that only a colour change shows |
| Respect 44 pt taps and the 24 px numeral floor at 667×375 pt too | Shrink cards below 84×118 pt to fit more; overlap them instead |

**Originality:** the palette, the clipped-tag motif, the stencil icon style, the lightness-ladder rarity set and the silhouettes are made for CardZone. They are not drawn from any other game's look. Flag for design: the spec text "C grey, U green, R blue, E purple, L gold" (§6) should be updated to this table.

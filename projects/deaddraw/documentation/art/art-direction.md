# DeadDraw - Art Direction for painted art (art pack 1)

Owner: Sr Game Artist | Board task: `dd-art-prompts` | Engine: Godot 4.4.1, Web, phone portrait + desktop landscape
Prompts: `chatgpt/dd-art-pack-1-prompts.md` | List: `art-pack-1-list.csv` | Vector spec this replaces in-game: `style-guides/art-direction.md`

## The one rule

At phone size the player reads the **number badge** and the **frame colour** first, then the picture. The art makes
each card feel like a thing; it never carries rules and never competes with the number. If it does, the art gets
darker, simpler or moves.

Checks for every image at **150 px wide**: (1) the type is clear from colour alone with the picture blurred;
(2) the badge at top-left reads without squinting; (3) the silhouette alone says what it is (Shambler vs Hulk,
Pistol vs Elephant Gun).

## Style

- **Bold painted comic.** Thick dark ink contour (#151214) around every shape, painted fills with visible brushwork,
  three value steps, slightly exaggerated cartoon proportions. Mood: "Saturday-night creature feature": dusky, tense,
  a bit funny (hard-hat zombies, commuter horde), never grisly.
- **One subject per card**, big and chunky, full body or whole object, centred.
- **Lighting:** one warm key light from the **upper right**, a cool dim fill from the left. The top-left stays the
  darkest corner, which is exactly where the number badge sits.
- **Gore:** cartoon level. Green-grey skin, glowing pale-yellow eyes, torn clothes and pose sell "zombie". No wounds,
  no blood pools, no severed parts. Medical symbols are a **green or white plus**, never a red cross.
- **Originality:** no real brands, logos, text, real weapon models or known characters. Guns are chunky, slightly
  toy-like game props; several are homemade (Ratchet Crossbow, Stovepipe Launcher, Alley Sweeper, Nail Driver).

## Palette per card type (matches the badge and frame colours in `scripts/ui/dd_ui.gd`)

| Type | Backdrop | Accent / rim light | Badge in game |
|---|---|---|---|
| Zombie | dusky blood-red to brown street, ruined rooftops (#3b2321 to #5c302a) | blood red #e2574c | red |
| Boss | bruise-purple night, big low moon (#2c1d35 to #4a3060) | purple #c27ce0 | red/purple |
| Gun | slate steel-blue pegboard wall (#1f2e3a to #2e4a5f) | hit yellow #f2c14e on the top edge | yellow |
| Melee | dark warm workshop pegboard (#2a2420) | hit yellow #f2c14e, copper #d9a066 | yellow |
| Heal | dark clinic green, faint plus pattern (#1d3325 to #2b4d37) | heal green #6fd08a | green |
| Cover | dark amber brick at night (#37301d to #56472a) | cover gold #e0b04a | gold |
| Machines | dim tiled workshop (#22282c) | copper #d9a066 | - |
| Survivors | dark, soft glow behind head | warm gold #f0d27a | - |

Shared: zombie skin #8ea476 / shade #62774f, eyes #f4ea9c, bone white #ece6d6. A subject may have **one** saturated
prop colour (Fire Axe red head, Nail Driver orange, Bruiser hi-vis); red stays small on non-zombie cards so red still
means "zombie". Districts: Maple Row = suburb at dusk (orange-pink sky, siding, maple leaves); Downtown = night, wet
asphalt, sodium orange vs cold blue; St. Agnes = pale tile, sickly teal fluorescent light.

## Framing (the game crops with "cover", so safe areas matter)

| Asset | Generate | In game | Safe area |
|---|---|---|---|
| Card art (zombie, boss, gun, melee, item, machine) | 1536x1024 | 768x512 | subject in the middle 60% wide, 20-80% high; top-left 30% x 35% dark and empty (number badge); bottom 18% simple (name bar); top-right calm (damage chip); phones crop to near-square, so nothing key in the outer 20% left/right |
| Room doors | 1024x1024 | 512x512 | door centred and shut; its centre is a plain mid-dark surface (padlock + price tag sits there); bottom 15% plain (room name) |
| District banners | 1536x1024 | 1536x480 band | landmarks in the 30-62% height band, centre to right; left 25% calm (boss portrait + name) |
| Survivors | 1024x1024 | 512x512 | bust inside the central 70% circle |
| Card backs | 1024x1536 | 512x768 | symmetrical, top-left plain (count badge) |
| Patches / icons | 1024x1024, transparent | 256 / 128 | one object, reads at 40 px (patches) / 24 px (icons) |
| Title | 1024x1536 + 1536x1024 | same | logo area and button area left empty |

Backgrounds: card art, rooms, banners and backs are **full-bleed** painted backdrops (cover-fit needs no empty
edges). Only Patches and icons use a **transparent** background. Rule glyphs (ANY, DOWN, UP, SAME...), HP, points and
arrows stay **vector** for crispness at 20 px.

## Pipeline

1. ChatGPT generates each batch from the prompt file and pushes PNGs to branch `art/deaddraw-pack-1`, folder
   `projects/deaddraw/documentation/art/chatgpt/images/art-pack-1/`.
2. Sr Game Artist reviews against the checks above (150 px, badge mock, no text/brands/gore), asks for redos.
3. Technical Artist downsizes to the game sizes, drops them into `assets/art/painted/`, and adds them to
   `assets/art/manifest.json` under the same keys the SVGs use today (e.g. `weapons.pistol`, `melee.axe`,
   `finales.maple_row`, `boss_phases.patient_zero_2`, `rooms.maple_row_garage`, `patches.lockpick`), so `dd_art.gd`
   picks them up with no code change. The SVGs stay as the fallback.

Out of scope for pack 1 (legacy v2/v3 art not in the current game): ammo, carrier drops, Jawbreakers, perks, the
Grin Machine, Lucky Locker and the old melee set (knife, crowbar, bat, machete, chainsaw, bottle, hammer).

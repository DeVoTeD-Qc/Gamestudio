# Killstreak — Visual Style Guide & UI Feel (v0.1)

*Author: Sr Game Artist Agent · 2026-11-03 · Target: Godot 4.4.1 web export (Compatibility renderer), 2D · DESIGN ONLY*
*IP: All visuals original. No franchise logos, HUD replicas, operator likenesses, map art, emblem/calling-card designs or signature color schemes. References below describe genre moods only.*

## Overall direction: "Tactical HUD meets field kit"
The game should feel like **looking at a soldier's tactical tablet between firefights**: a dark slate interface, crisp HUD linework, signal-amber highlights, and cards that look like **laminated field ID badges and gear tags**. Illustrations are **stylized, high-contrast duotone paintings** with strong silhouettes, flat shapes and a bit of grain, built to read at thumbnail size in a browser. The tone is gritty but not grim: multiplayer-lobby energy, no gore, and "eliminated/downed" rather than death imagery.

- **Mood (descriptions only):** night-vision green-black dusk on a container port; sodium-orange floodlights on wet concrete; the cool blue glow of a drone feed; stenciled crate markings; worn velcro morale patches; the clean vector overlays of a modern tactical HUD.
- **Art style:** 2D painted duotone illustration (two tones per card plus one accent) over flat UI vector frames. Characters are always in gear (helmets, masks, goggles), which keeps faces generic and avoids likeness issues.

## Color palette
| Role | Name | Hex |
|---|---|---|
| Background | Slate Black | `#12161A` |
| Panels | Gunmetal | `#232A31` |
| Neutral text | Fog | `#D8DEE3` |
| Primary accent (player, UI focus) | Signal Amber | `#FFB020` |
| Friendly | Halberd Teal | `#2EC4B6` |
| Enemy / red dots | Hostile Red | `#E5383B` |
| Killstreak / special | Uplink Cyan | `#5BC0EB` |
| Elite rarity | Brass | `#C9A227` |
| Terrain duotones | Olive `#5B6B3A`, Sand `#C2A878`, Concrete `#7A828A` | |

Rule: **friend = teal, enemy = red, interactive = amber.** Never rely on color alone: friendly cards have a chevron notch and enemy cards have a hazard-stripe edge (colorblind safety).

## Typography (free/OFL, web-safe to bundle)
- Headings / card names: **Barlow Condensed** SemiBold, uppercase, slight letter-spacing (stencil-military feel without being an actual stencil).
- Numbers / HUD / killfeed: **Share Tech Mono**.
- Body / tooltips: **Barlow** Regular, at least 14 px on a 1280 px-wide canvas.

## Card frame layout (unit card, 5:7 ratio, base 250×350 px)
```
┌───────────────────────────────┐
│[3]  BREACHER          [SHOTGUN]│  ← Cost in a hex "ammo box" badge (amber) · name · class tag chip
│┌─────────────────────────────┐│
││  duotone illustration       ││  ← art window ~55% of card height
││  (strong silhouette)        ││
│└─────────────────────────────┘│
│ ⚡ FIRST SHOT                  │  ← keyword icons + 1 line max
│ CLOSE +2 · LONG −1            │  ← range strip (tiny, icon-led)
│(⌖ 3)                   (▣ 4)│  ← Firepower (crosshair) bottom-left · Armor (plate) bottom-right
└───────────────────────────────┘
```
- **Unit cards:** laminated ID-badge frame with a lanyard slot at the top. Rarity is shown by frame material (matte gray → teal anodized → brass Elite).
- **Tactic cards:** angled cut corners, a "radio order" header bar, and a waveform motif.
- **Equipment cards:** gear-tag shape with a hazard-tape stripe.
- **Killstreak cards:** a glowing **tablet** frame in Uplink Cyan with a scanline overlay and the threshold number large in the corner.
- **Perks:** round **embroidered morale patches** (an original icon per perk), shown in 3 slots on the Operator panel. This is the "Joker shelf" for veterans.
- **Operator card:** larger, a dog-tag silhouette frame. The weapon and its attachments are shown as small icons along the bottom edge, and they light up as the weapon levels.

## Board & HUD
- **Board:** top-down tactical map of the current map (e.g., Port Vasel), painted in muted duotone with **3 lane zones** marked by HUD brackets. Each zone shows a range badge (CLOSE / MID / LONG) and its control state (teal fill, red fill, or striped for contested).
- **Minimap intel strip** (top-center): 3 lane slots showing **red dots** for incoming enemy contacts. Recon makes them flip into small card silhouettes, with a sweep animation.
- **Killfeed** (top-right): `ATTACKER [icon] VICTIM` lines in Share Tech Mono, fading after 4 s, with friendly entries in teal and enemy entries in red.
- **Streak meter** (bottom-left, around the Operator panel): segmented arc with notches at each killstreak threshold. Notches glow cyan when earned, and the arc **shatters** with a glass-crack effect on reset.
- **Supply:** ammo-box pips by the hand. **READY** button: large amber, bottom-right.
- **Score bar** (top): mode-specific (zone points or elimination tally), with the round counter "RD 3/8".

## Motion & feedback ("juice", lightweight for web)
- Firefights: tracer lines from shooter to target (staggered 60 ms per shot), a **hit-marker "X"** plus a damage number on impact, a quick camera shake (2–4 px) on eliminations, and an "ELIMINATED" stamp.
- XP pop-ups: "+100 ELIMINATION", "+50 ZONE SECURED" float up in amber.
- Killstreak call-in: a 0.8 s full-screen tablet takeover (cyan scanlines + radio callout text), then the effect plays.
- Card hover: lift 8 px, tilt 3°, keyword tooltips. All motion is built from Tweens; **no particles heavier than 64 sprites**.

## Audio direction (brief)
Original radio-chatter barks (text-to-voice placeholders in the prototype): *"Contacts Left!"*, *"Two down on Containers."*, *"Recon drone up."*, *"Operator down, redeploying."* Punchy suppressed-gunfire SFX layered with UI clicks. A low synth pulse in the lobby/menu.

## Pipeline & technical targets (web)
- 2D only. Card art at 512×716 source, exported as WebP/PNG atlases; target **< 25 MB total assets** for v1 and **< 5 MB for the prototype**.
- UI built with Godot Control nodes + Theme resources (`card_theme.tres`, `hud_theme.tres`). Fonts embedded as dynamic fonts.
- **Prototype art = placeholders:** flat-color frames in the final layout, class icons from a single original icon sheet, and silhouette art. Final painted art comes only after the design is approved.

## Quality checklist
- [ ] The card reads at 50% scale (hand view, on a 1280×720 canvas)
- [ ] Friend vs. enemy is distinguishable without color
- [ ] No element resembles a franchise logo, HUD, emblem or character
- [ ] One accent color per screen region; amber is reserved for interactable elements

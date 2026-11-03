# CallingCard: Art Direction

*Sr Game Artist (performed by the Master Orchestrator in role) · 2026-11-03 · Phase: Design*

> **Originality rule (binding).** No Call of Duty / Activision artwork, logos, fonts, UI captures, card art or trade dress, not even as references inside the project. All card art, icons and UI are original. The prototype uses **original placeholder art**, mostly generated shapes and gradients. Mood references are described in words, not collected as images.

## 1. Direction: "Museum of the Grind"
Calling cards are trophies, so we present them like **framed exhibits on a gallery wall at night**. The wall is dark and the cards glow. Hard-earned cards get heavier, more crafted frames. The duel board is literally a **brick wall** where banners hang. When a card is captured, its frame re-lacquers in the captor's color, like paint washing over it.

- **Mood:** confident, premium and slightly theatrical. Not military-gritty: the cards are about *personality*, not war.
- **Style:** flat-graphic and duotone poster art inside the cards (bold shapes, 2–3 tones, film grain). The frames and UI are crisp and physical (enamel, brass, glass).
- **Why:** the poster style is fast to produce, reads at small sizes, survives web compression, and is clearly not a CoD look-alike.

## 2. Card anatomy (wide banner, 4:1)
```
+--------------------------------------------------------------+
| [T 5]                                            (Clr pip x2)|
|                 duotone poster art (full bleed)              |
| [S 4]                                          [S 4]          |
|  CARD NAME · Set glyph                            [B 4] TRAIT |
+--------------------------------------------------------------+
```
- **Ratio:** 4:1 at 512×128 source (it renders crisply at 256×64 on the board and at 1024×256 in the album).
- **Values:** Top sits top-left, Bottom sits bottom-right, and Side appears on both short ends. Values are in round **enamel pips**, using a bold condensed numeral face (an open-licensed font, e.g. from Google Fonts).
- **Trait:** a small monochrome icon plus a one-word label (Steady = anchor bar, Veteran = double chevron, Ambush = closed eye, Reclaim = curved arrow, Clutch = lightning tick, Cipher = keyhole).
- **Clearance:** 1–4 pips in the top-right corner, and the frame material changes with it.

## 3. Frames by Clearance
| Clearance | Frame | Treatment |
|---|---|---|
| 1 Issue | Matte graphite | Flat, thin |
| 2 Merit | Brushed steel | Subtle sheen |
| 3 Distinction | Brass | Bevel and slow glint |
| 4 Legend | Black enamel with gold inlay | Animated glint and a soft outer glow |
| Showcase (store) | Chrome or gold leaf | **Animated reflections**: the flashiest frame, with zero power (makes the anti-P2W rule visible) |
| Set complete | Adds the set's colored edge-light | Pulses once per placement |

## 4. Color
| Role | Hex | Use |
|---|---|---|
| Wall background | `#14161B` | Night gallery |
| Brick mortar lines | `#23262E` | Board grid |
| Text primary | `#ECE8DF` | Warm off-white |
| **Player color** | `#3EC6C1` (teal) | Your cards and frame wash |
| **Rival color** | `#F2705A` (coral) | Enemy cards and frame wash |
| Interactive / highlight | `#F5B63F` (amber) | Valid slots, buttons, capture preview |
| Signature | `#E9D8A6` (pale gold) | Signature ribbon |

**Set palettes (poster duotones):** Night Shift: magenta `#C2408A` + cyan `#47B8D6`. Whiteout: ice `#CFE3EE` + slate `#4E6475`. Signal Fire: flare red `#E0452E` + navy `#1D2A44`. Old Guard: brass `#B98A3E` + oxblood `#5A1F24`. Cipher: black `#0B0B0D` + teal glow `#3FE0C5`.

**Accessibility:** ownership is never shown by color alone. Your cards carry a **solid corner tab**; rival cards carry a **notched tab**. The capture preview uses an arrow badge on each card that would flip. All text meets 4.5:1 contrast on the wall background.

## 5. Board and UI
- **Board:** a dark brick wall with soft spotlights over the 10 slots. Empty slots show a faint chalk outline. Valid drop slots glow amber, and the **capture preview** shows arrows pointing at the cards that would flip.
- **Hand:** five cards fanned at the bottom (portrait/phone: scrollable strip). Tapping a card enlarges it; there is no hover-only information.
- **Score:** two lacquer counters (teal and coral) at the top, with Signature ribbons shown next to them.
- **"Carded!" moment:** the captured Signature banner cracks along a jagged line, the captor's color washes over it, and a stamp graphic reads "CARDED". About 0.8 s, skippable.
- **Album:** a velvet-lined portfolio. Each set gets a page with frames hung salon-style. Unowned cards are **embossed silhouettes**, and tapping one shows its unlock goal, Clearance and trait. Triptych slots are three joined empty frames with a handwritten hint. The Cipher Lock is a 4-dial brass mechanism.
- **Typography:** one condensed display face for numbers and titles and one clean sans for body text (both open-licensed and self-hosted for web).

## 6. Motion and feedback
- Placement: the card slides in with a tiny weight-drop and a dust puff on the mortar.
- Capture: a frame color wipe (0.25 s) plus a "thunk".
- Ambush: the card back shows a closed-eye icon; when it springs, the eye opens with a flash.
- Set Link: a thin light runs between linked cards.
- Triptych: three cards slide together and merge into one panorama for 1.5 s.

## 7. Prototype art pipeline (placeholder)
- Card art is **procedural**: a Godot `Control` that draws duotone gradients, 2–4 vector shapes per card from a seed and a small hand-drawn SVG icon. No painted art for the demo.
- Frames are `StyleBoxFlat` and `NinePatchRect` with simple shaders for glint (web-safe, GL Compatibility renderer).
- Icons are original SVGs drawn for this project, imported as textures. Fonts are open-licensed.
- Budget: under 5 MB of art for the whole web build.

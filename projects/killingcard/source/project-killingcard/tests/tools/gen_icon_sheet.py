# gen_icon_sheet.py: regenerates assets/ui/icons/icon_sheet.svg (p13). Usage:
#   python3 tests/tools/gen_icon_sheet.py assets/ui/icons/icon_sheet.svg
# Keep icon order in sync with scripts/ui/icon_sheet.gd NAMES.
# Generates assets/ui/icons/icon_sheet.svg: 8 columns x 5 rows of 64 px cells, white line icons.
import sys
S = 'fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"'
T = 'fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"'
F = 'fill="#fff"'
def rng(bold):
    # range rings from an origin dot at bottom-left; the bold ring marks the band
    radii = [16, 30, 44]
    out = [f'<circle cx="10" cy="54" r="5" {F}/>']
    for i, r in enumerate(radii):
        style = S if i == bold else T + ' stroke-opacity="0.45"'
        out.append(f'<path d="M{10+r} 54 A{r} {r} 0 0 0 10 {54-r}" {style}/>')
    return ''.join(out)
icons = [
 ("range_close", rng(0)),
 ("range_mid", rng(1)),
 ("range_long", rng(2)),
 ("type_unit", f'<path d="M12 40 A20 20 0 0 1 52 40 Z" {S}/><path d="M8 40 H56" {S}/><path d="M24 40 V48 H40 V40" {S}/>'),
 ("type_tactic", f'<path d="M6 32 H16 L22 18 L30 46 L38 12 L44 38 L48 32 H58" {S}/>'),
 ("type_equipment", f'<path d="M22 8 H42 L54 20 V56 H10 V20 Z" {S}/><circle cx="32" cy="21" r="5" {S}/><path d="M18 36 H46 M18 46 H38" {T}/>'),
 ("type_killstreak", f'<rect x="8" y="14" width="48" height="40" rx="5" {S}/><path d="M22 40 A10 10 0 0 1 42 40 M16 40 A16 16 0 0 1 48 40" {T}/><circle cx="32" cy="40" r="3" {F}/>'),
 ("type_operator", f'<rect x="16" y="14" width="32" height="44" rx="14" {S}/><circle cx="32" cy="24" r="4" {S}/><path d="M32 6 V14" {T} stroke-dasharray="3 4"/><path d="M24 38 H40 M24 46 H36" {T}/>'),
 # weapon classes: original generic silhouettes (side view, muzzle right)
 ("class_smg", f'<path d="M8 26 H44 V34 H30 L28 44 H20 L22 34 H8 Z" {F}/><path d="M44 29 H54" {S}/><rect x="31" y="34" width="6" height="14" {F}/>'),
 ("class_shotgun", f'<path d="M4 30 L14 26 H40 V34 H22 L14 40 H4 Z" {F}/><path d="M40 28 H60" {S}/><rect x="40" y="33" width="14" height="6" rx="2" {F}/>'),
 ("class_ar", f'<path d="M4 28 L12 24 H46 V33 H30 L28 46 H22 L24 33 H14 L6 36 Z" {F}/><path d="M46 28 H60" {S}/><path d="M32 33 L36 46 H42 L38 33 Z" {F}/>'),
 ("class_sniper", f'<path d="M2 32 L10 28 H40 V35 H18 L10 40 H2 Z" {F}/><path d="M40 31 H62" {S}/><rect x="18" y="18" width="18" height="6" rx="3" {F}/><path d="M24 24 V28 M30 24 V28" {T}/>'),
 ("class_lmg", f'<path d="M4 26 L12 22 H48 V32 H14 L6 34 Z" {F}/><path d="M48 26 H60" {S}/><rect x="22" y="32" width="14" height="12" rx="2" {F}/><path d="M50 32 L44 48 M50 32 L56 48" {T}/>'),
 ("kw_first_shot", f'<path d="M36 4 L14 36 H30 L26 60 L50 26 H34 Z" {F}/>'),
 ("kw_pick", f'<circle cx="14" cy="40" r="5" {F}/><circle cx="50" cy="40" r="5" {F}/><circle cx="32" cy="22" r="5" {F}/><circle cx="32" cy="22" r="13" {S}/><path d="M32 42 V58" {T}/>'),
 ("kw_flank", f'<path d="M10 52 V24 A14 14 0 0 1 38 24 V40" {S}/><path d="M28 32 L38 44 L48 32" {S}/><rect x="44" y="50" width="14" height="8" {F}/>'),
 ("kw_cover", f'<rect x="6" y="40" width="24" height="14" rx="4" {F}/><rect x="34" y="40" width="24" height="14" rx="4" {F}/><rect x="18" y="24" width="28" height="14" rx="4" {F}/><rect x="6" y="8" width="52" height="12" rx="4" {T} stroke-opacity="0.5"/>'),
 ("kw_suppress", f'<path d="M14 10 L32 24 L50 10 M14 26 L32 40 L50 26" {S}/><path d="M8 54 H56" {S}/>'),
 ("kw_patch", f'<g transform="rotate(-40 32 32)"><rect x="8" y="22" width="48" height="20" rx="10" {S}/><rect x="24" y="22" width="16" height="20" {F}/></g>'),
 ("kw_holder", f'<path d="M16 58 V6" {S}/><path d="M18 8 H50 L42 18 L50 28 H18 Z" {F}/><path d="M8 58 H32" {S}/>'),
 ("trig_on_deploy", f'<path d="M32 4 V34 M20 22 L32 34 L44 22" {S}/><path d="M8 40 V56 H56 V40" {S}/>'),
 ("trig_on_down", f'<circle cx="32" cy="32" r="22" {S}/><path d="M18 46 L46 18" {S}/>'),
 ("stat_firepower", f'<circle cx="32" cy="32" r="18" {S}/><path d="M32 4 V20 M32 44 V60 M4 32 H20 M44 32 H60" {S}/><circle cx="32" cy="32" r="4" {F}/>'),
 ("stat_armor", f'<path d="M12 10 H52 V34 L32 58 L12 34 Z" {S}/><path d="M20 22 H44 M20 32 H44" {T}/>'),
 ("streak", f'<path d="M8 50 A26 26 0 0 1 14 24" {S}/><path d="M20 17 A26 26 0 0 1 32 12" {S}/><path d="M38 12 A26 26 0 0 1 50 17" {S}/><path d="M55 24 A26 26 0 0 1 56 50" {T} stroke-opacity="0.45"/><path d="M32 50 L40 32 H34 L38 20" {T}/>'),
 ("supply", f'<rect x="8" y="22" width="48" height="32" rx="3" {S}/><path d="M8 32 H56" {S}/><path d="M24 22 V14 H40 V22" {S}/><path d="M28 42 H36" {T}/>'),
 ("ks_recon_drone", f'<path d="M18 18 L46 46 M46 18 L18 46" {S}/><circle cx="14" cy="14" r="8" {T}/><circle cx="50" cy="14" r="8" {T}/><circle cx="14" cy="50" r="8" {T}/><circle cx="50" cy="50" r="8" {T}/><rect x="26" y="26" width="12" height="12" rx="3" {F}/>'),
 ("ks_mortar", f'<path d="M22 54 L36 26" stroke="#fff" stroke-width="9" stroke-linecap="round"/><path d="M8 58 H40" {S}/><path d="M38 20 Q46 4 58 14" {T} stroke-dasharray="4 5"/>'),
 ("ks_sentry", f'<rect x="14" y="12" width="28" height="18" rx="4" {F}/><path d="M42 18 H58" {S}/><path d="M28 30 V40 M28 40 L12 58 M28 40 L44 58 M28 40 V58" {S}/>'),
 ("ks_attack_helo", f'<path d="M6 16 H58" {S}/><path d="M32 16 V24" {S}/><path d="M12 34 A12 10 0 0 1 24 24 H38 A10 10 0 0 1 48 34 V40 H20 A8 8 0 0 1 12 34 Z" {F}/><path d="M48 32 H62 V24" {S}/><path d="M20 48 H44" {T}/>'),
 ("ks_gunship", f'<path d="M32 4 V60" stroke="#fff" stroke-width="8" stroke-linecap="round"/><path d="M4 30 L32 22 L60 30 V36 L32 32 L4 36 Z" {F}/><path d="M20 54 L32 50 L44 54" {S}/>'),
 ("intel_contact", f'<circle cx="32" cy="32" r="10" {F}/><circle cx="32" cy="32" r="22" {T} stroke-opacity="0.6"/>'),
 ("elite", f'<path d="M32 6 L39.6 23.4 L58.6 25.3 L44.3 37.9 L48.4 56.5 L32 46.9 L15.6 56.5 L19.7 37.9 L5.4 25.3 L24.4 23.4 Z" {F}/>'),
 ("eliminated", f'<path d="M12 12 L24 24 M52 12 L40 24 M12 52 L24 40 M52 52 L40 40" stroke="#fff" stroke-width="6" stroke-linecap="round"/>'),
]
COLS = 8
rows = (len(icons) + COLS - 1) // COLS
out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{COLS*64}" height="{rows*64}" viewBox="0 0 {COLS*64} {rows*64}">',
       '<!-- Killstreak placeholder icon sheet. Original art, white line icons on transparent, 64 px cells.',
       '     Index map lives in res://scripts/ui/icon_sheet.gd (row-major, 8 columns). Tint with modulate. -->']
for i, (name, body) in enumerate(icons):
    x, y = (i % COLS) * 64, (i // COLS) * 64
    out.append(f'<g id="{name}" transform="translate({x} {y})">{body}</g>')
out.append('</svg>')
open(sys.argv[1], 'w').write('\n'.join(out) + '\n')
print(len(icons), 'icons;', ', '.join(f'"{n}"' for n, _ in icons))

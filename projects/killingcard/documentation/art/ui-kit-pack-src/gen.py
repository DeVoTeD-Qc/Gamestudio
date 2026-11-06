import csv
import sys
from collections import Counter, OrderedDict

sys.path.insert(0, sys.argv[1])
from slots import S  # noqa: E402

OUT_MD = sys.argv[2]
OUT_CSV = sys.argv[3]

ICON_STYLE = ("Original pictogram for the interface of a modern military-tactical card game played on phones. "
              "Bold geometric glyph language: straight cuts, 45-degree chamfers, chunky even stroke weight, "
              "no fine detail, no realism. No text, letters, numbers, logos, brand marks, insignia, flags or emblems.")

UI_STYLE = ("Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering: "
            "matte gunmetal and dark slate metal with a faint brushed grain, crisp 45-degree chamfered corners, thin bevels "
            "with one soft top-left highlight, no grunge, no rust, no scratches. Bold simple shapes that stay readable when "
            "shrunk small. Palette: slate #12161A, gunmetal #232A31, panel #2E3740, steel #3A444D, edge grey #4A535B, "
            "fog white #D8DEE3, plus only the accent colours named below. Straight-on front view, no perspective, no cast "
            "shadow, even flat lighting. No text, letters, numbers, logos, brand marks, insignia, flags or emblems.")

BG_STYLE = ("Original stylized 2D duotone painting for a mobile card game screen background, modern private-military theme. "
            "Flat graphic shapes, light film grain, soft atmospheric haze. Palette: slate black #12161A, gunmetal #232A31, "
            "fog white #D8DEE3, olive #5B6B3A, sand #C2A878, concrete #7A828A, with one small accent of signal amber #FFB020. "
            "Dusk or night, sodium-floodlight rim light, deep soft shadows. Dark and low contrast overall, most of the image "
            "between slate and gunmetal, so white text and cards stay readable on top. No text, letters, numbers, logos, "
            "insignia, flags, emblems or brand marks. No visible faces. No gore.")

LUMA_TAIL = ("Solid pure white #FFFFFF flat fill only: no outline in another colour, no gradient, no shading, no glow, no 3D. "
             "Centred, filling about 70% of the canvas, with even empty margin on all sides. "
             "Perfectly flat pure black #000000 background.")
ICON_TAIL = ("Thick strokes, at least one twelfth of the canvas wide, simple enough to read at 32 pixels. " + LUMA_TAIL +
             " Square 1:1.")
ALPHA_TAIL = ("Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF "
              "background with no shadow, no gradient and no magenta inside the asset.")
NINE_TAIL = ("Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges "
             "identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size.")
ADD_TAIL = ("Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no "
            "object, no surface and no frame, just the glow.")
OPAQUE_PART_TAIL = "Fill the whole canvas edge to edge, flat front-on view."
FX_STYLE = ("Original light effect for the interface of a modern military-tactical card game played on phones. "
            "Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols.")

AVOID = {
    "icon": "text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black",
    "part": "text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in",
    "luma": "text, letters, numbers, colour, grey shading, a background that is not pure black",
    "add": "text, an object or surface, colours other than the one asked, a background that is not pure black",
    "background": "text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre",
    "opaque": "text, letters, numbers, logos, a cast shadow, a perspective tilt",
    "band": "text, logos, a centre focus, a border or frame, hard seams, colours other than the ones named",
}

SHAPE = {"1024x1024": "square 1:1", "1536x1024": "landscape 3:2", "1024x1536": "portrait 2:3"}

ALPHA_LABEL = {
    "luma": "white on black: TA converts brightness to alpha",
    "alpha": "transparent PNG (magenta #FF00FF key if it fails)",
    "add": "glow on black: additive blend in game, no alpha needed",
    "opaque": "opaque, no transparency",
}
ALPHA_CSV = {"luma": "yes (luma key)", "alpha": "yes (alpha or magenta key)", "add": "no (additive on black)", "opaque": "no"}


def prompt(s):
    cat, a = s["cat"], s["alpha"]
    shape = SHAPE[s["gen"]]
    if cat == "icon":
        return f"{ICON_STYLE} Draw exactly one icon: {s['subj']}. {ICON_TAIL}"
    if cat == "background":
        if s["id"].startswith("col_"):
            tail = ("Tall 2:3 portrait. Only the middle 60% of the width is used and it is shown at a third of its brightness "
                    "behind game cards, so keep it subtle and even. Seen from directly above.")
        else:
            tail = ("Wide 3:2 landscape, cinematic. Keep key shapes between 12% and 88% of the height: the top and bottom "
                    "get cropped.")
        return f"{BG_STYLE} {s['subj'][0].upper() + s['subj'][1:]} {tail}"
    if cat == "band":
        return f"{UI_STYLE} {s['subj'][0].upper() + s['subj'][1:]} Square 1:1."
    body = s["subj"][0].upper() + s["subj"][1:] + "."
    if a == "luma":
        return f"{ICON_STYLE} Draw one UI element: {s['subj']}. {LUMA_TAIL} {shape[0].upper() + shape[1:]}."
    if a == "add":
        return f"{FX_STYLE} {body} {ADD_TAIL} {shape[0].upper() + shape[1:]}."
    if a == "opaque":
        return f"{UI_STYLE} {body} {OPAQUE_PART_TAIL} {shape[0].upper() + shape[1:]}."
    nine = (" " + NINE_TAIL) if s["nine"] and s["nine"][0].isdigit() else ""
    return f"{UI_STYLE} {body} One element only, centred, filling about 80% of the canvas.{nine} {ALPHA_TAIL} {shape[0].upper() + shape[1:]}."


def avoid(s):
    base = s["cat"] if s["cat"] in ("icon", "background", "band") else {"luma": "luma", "add": "add", "opaque": "opaque"}.get(s["alpha"], "part")
    extra = s.get("avoid") or ""
    return AVOID[base] + (", " + extra if extra else "") + "."


CAT_TITLE = OrderedDict([
    ("icon", "Icons"), ("button", "Buttons and controls"), ("panel", "Panels, trays, rings and strips"),
    ("background", "Backgrounds"), ("tile", "Objective and Field tile backers"), ("frame", "Card frame parts"),
    ("band", "Camo bands"), ("fx", "Glows, outlines and overlays"),
])
CAT_FOLDER = {"icon": "assets/ui/kit/icons/", "button": "assets/ui/kit/buttons/", "panel": "assets/ui/kit/panels/",
              "background": "assets/ui/backgrounds/", "tile": "assets/ui/kit/tiles/", "frame": "assets/ui/kit/frames/",
              "band": "assets/ui/kit/bands/", "fx": "assets/ui/kit/fx/"}


def folder(s):
    if s["id"].startswith("col_"):
        return "assets/sprites/board/"
    return CAT_FOLDER[s["cat"]]


# ---------------------------------------------------------------- CSV
with open(OUT_CSV, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["id", "filename", "category", "section", "generate", "ship_size", "transparent", "nine_slice_margins_ltrb",
                "states", "where_used", "priority", "final_folder", "notes"])
    for s in S:
        w.writerow([s["id"], s["file"], s["cat"], s["sec"], f"{s['gen']} ({SHAPE[s['gen']]})", s["ship"], ALPHA_CSV[s["alpha"]],
                    s["nine"], s["states"], s["used"], s["pri"], folder(s), s.get("notes", "")])

# ---------------------------------------------------------------- counts
by_cat = Counter(s["cat"] for s in S)
by_pri = Counter(s["pri"] for s in S)
by_cat_pri = Counter((s["cat"], s["pri"]) for s in S)
total = len(S)
p1 = [s for s in S if s["pri"] == "P1"]

out = []
o = out.append

o(open(sys.argv[4]).read().replace("{TOTAL}", str(total)).replace("{P1}", str(by_pri["P1"]))
  .replace("{P2}", str(by_pri["P2"])).replace("{P3}", str(by_pri["P3"])))

# count table
o("| Category | Images | P1 | P2 | P3 |")
o("|---|---|---|---|---|")
for c, t in CAT_TITLE.items():
    o(f"| {t} | {by_cat[c]} | {by_cat_pri[(c, 'P1')]} | {by_cat_pri[(c, 'P2')]} | {by_cat_pri[(c, 'P3')]} |")
o(f"| **Total** | **{total}** | **{by_pri['P1']}** | **{by_pri['P2']}** | **{by_pri['P3']}** |")
o("")
o(open(sys.argv[5]).read().replace("{ICON_STYLE}", ICON_STYLE).replace("{FX_STYLE}", FX_STYLE).replace("{UI_STYLE}", UI_STYLE).replace("{BG_STYLE}", BG_STYLE)
  .replace("{ICON_TAIL}", ICON_TAIL).replace("{ALPHA_TAIL}", ALPHA_TAIL).replace("{NINE_TAIL}", NINE_TAIL)
  .replace("{ADD_TAIL}", ADD_TAIL).replace("{LUMA_TAIL}", LUMA_TAIL))

# ---------------------------------------------------------------- prompts
o("## 4. Prompts")
o("")
o("Every grey box is complete: copy it as is. Entries are grouped the way they should be generated: **one ChatGPT chat per group** "
  "(heading level 4), so the set shares a look. After the first image in a group, you can shorten the next ones to "
  "\"Same style, next one: <the part after 'Draw exactly one icon:'>\", but if the style drifts, paste the full box again.")
o("")
n = 0
for c, t in CAT_TITLE.items():
    items = [s for s in S if s["cat"] == c]
    if not items:
        continue
    o(f"### 4.{list(CAT_TITLE).index(c) + 1} {t} ({len(items)})")
    o("")
    secs = OrderedDict()
    for s in items:
        secs.setdefault(s["sec"], []).append(s)
    for sec, ss in secs.items():
        o(f"#### {sec} ({len(ss)})")
        o("")
        for s in ss:
            n += 1
            o(f"##### {n}. `{s['file']}` · {s['pri']}")
            o("")
            o(f"- **Used in:** {s['used']}.")
            meta = f"- **Generate:** {s['gen']} ({SHAPE[s['gen']]}). **Ship:** {s['ship']}. **Background:** {ALPHA_LABEL[s['alpha']]}."
            o(meta)
            line = f"- **States:** {s['states']}."
            if s["nine"] and s["nine"][0].isdigit():
                line += f" **9-slice (L,T,R,B at ship size):** {s['nine']}."
            elif s["nine"]:
                line += f" **Repeat:** {s['nine']}."
            o(line)
            if s.get("notes"):
                o(f"- **Note:** {s['notes']}")
            o("")
            o("```")
            o(prompt(s))
            o("```")
            o("")
            o(f"**Avoid:** {avoid(s)}")
            o("")

# ---------------------------------------------------------------- batches
o("## 5. Batches and upload plan")
o("")
o("Generate in priority order. **P1 is the minimum that makes the prototype look finished**: every icon the board, tray and strip "
  "show in a normal match, the banner and hand frames, the main buttons and panels, the match and column backdrops, and the "
  "title, run map and Supply Drop screens. P2 finishes the run screens, menus and feedback. P3 is polish and spare slots.")
o("")
o("Each batch is about 10 images (10 to 15 minutes) and one upload. Keep a group (a level-4 heading in section 4) in one ChatGPT chat; when a batch crosses into the next group, start a new chat there.")
o("")
batches = []
order = ["icon", "frame", "band", "fx", "button", "panel", "tile", "background"]
for pri in ("P1", "P2", "P3"):
    for c in order:
        group = [s for s in S if s["pri"] == pri and s["cat"] == c]
        for i in range(0, len(group), 10):
            batches.append((pri, CAT_TITLE[c], group[i:i + 10]))
o("| Batch | Priority | Group | Images | Files |")
o("|---|---|---|---|---|")
for i, (pri, title, g) in enumerate(batches, 1):
    files = ", ".join(f"`{s['file'][:-4]}`" for s in g)
    o(f"| {i} | {pri} | {title} | {len(g)} | {files} |")
o("")
p1_batches = sum(1 for b in batches if b[0] == "P1")
o(f"P1 is batches 1 to {p1_batches} ({by_pri['P1']} images). At about a minute per image plus a check, that is roughly "
  f"two hours, best split into three or four sittings. After batch 1 (the first icons) and the first frame batch, pause and let the Technical Artist drop them "
  f"into the build: if the style needs a tweak, it is cheaper to change the style block then than after 150 images.")
o("")
o(open(sys.argv[6]).read())

with open(OUT_MD, "w") as f:
    f.write("\n".join(out) + "\n")

print(total, dict(by_cat), dict(by_pri), "batches", len(batches), "p1 batches", p1_batches)

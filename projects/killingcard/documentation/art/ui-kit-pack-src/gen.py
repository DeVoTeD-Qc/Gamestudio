import csv
import sys
from collections import Counter, OrderedDict

sys.path.insert(0, sys.argv[1])
from slots import S, BATCHES  # noqa: E402

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
ICON_TAIL = ("Thick strokes and gaps, at least one tenth of the canvas wide, no detail smaller than one eighth of the canvas, "
             "simple enough to read at 24 pixels. Compact, roughly square silhouette that fills about 70% of the canvas in both width and height. " + LUMA_TAIL +
             " Square 1:1.")
ALPHA_TAIL = ("Transparent background PNG. If transparency is not possible, put it on a perfectly flat solid magenta #FF00FF "
              "background with no shadow, no gradient and no magenta inside the asset.")
NINE_TAIL = ("Built for 9-slice stretching: keep every corner detail inside the corners, and make the four straight edges "
             "identical along their whole length (no rivets, marks or ornaments in the middle of an edge) so it can stretch to any size.")
ADD_TAIL = ("Only light, on a perfectly flat pure black #000000 background: it is added on top of the game, so there is no "
            "object, no surface and no frame, just the glow.")
OPAQUE_PART_TAIL = "Fill the whole canvas edge to edge, flat front-on view."
SI_STYLE = ("Original plain two-tone illustration for the basic starter cards of a modern military card game. One flat simple figure "
            "in olive drab #4B5320 and khaki #C3B091 against a muted grey-green #5E6B5A canvas or plain wooden supply-crate background. "
            "Flat shapes like a training-manual print, matte, low contrast, soft even light, no glow, no light effects, no dramatic lighting, "
            "only a faint canvas weave as texture. Deliberately modest and basic.")
SI_RULES = ("Wide 3:2 landscape that will be cropped to a thin 4:1 strip across the middle (30% to 66% of the height) and a tall 2:3 column "
            "in the centre. Put the figure in the exact centre, head and hands between 30% and 65% of the height, inside the middle 60% of the width. "
            "The four corners of that strip stay empty, flat and calm, because the game puts small badges there: abilities top right, the traits "
            "bottom left, the firepower and armour badges bottom right, and the cost and level top left. Above and below, continue the plain background. "
            "No text, letters, numbers, stencils, serial numbers, logos, insignia, flags, badges, patches or symbols on clothing, gear or crates. "
            "Invented people only, faces simple or shaded by the helmet. No blood.")
PAPER_STYLE = ("Original game UI asset for a modern military-tactical card game played on phones. Clean semi-flat rendering of "
               "matte field-orders paper: dark olive-brown and khaki, a faint even fibre grain, crisp straight edges, no grunge, no stains, "
               "no folds, no wear marks. Bold simple shapes that stay readable when shrunk small. Palette: olive-brown #2B2716, dark olive #1F1C10, "
               "khaki #B8913A, pale khaki #D9C48A, plus only the accent colours named below. Straight-on front view, no perspective, no cast "
               "shadow, even flat lighting. No text, letters, numbers, logos, stamps, seals, insignia, flags or emblems.")

FX_STYLE = ("Original light effect for the interface of a modern military-tactical card game played on phones. "
            "Clean, soft, even glow with a smooth falloff and no noise. No text, letters, numbers, logos or symbols.")

AVOID = {
    "icon": "text, letters, numbers, a second icon, an outline in another colour, grey shading, an extra badge or frame around the glyph, a background that is not pure black",
    "part": "text, letters, numbers, logos, ornaments in the middle of an edge, a cast shadow, a perspective tilt, a checkerboard pattern painted in",
    "luma": "text, letters, numbers, colour, grey shading, a background that is not pure black",
    "add": "text, an object or surface, colours other than the one asked, a background that is not pure black",
    "background": "text, numbers, logos, insignia, flags, real weapon or vehicle models, recognizable places or people, gore, a bright or busy centre",
    "opaque": "text, letters, numbers, logos, a cast shadow, a perspective tilt",
    "card_art": "text, letters, numbers, logos, insignia, flags, badges, real weapon models, recognizable people, gore, a busy or bright corner",
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
    UI = PAPER_STYLE if s.get("style") == "paper" else UI_STYLE
    shape = SHAPE[s["gen"]]
    if cat == "card_art":
        return f"{SI_STYLE} {s['subj'][0].upper() + s['subj'][1:]}. {SI_RULES}"
    if cat == "plate":
        return (f"{ICON_STYLE} Draw one number plate (the game prints the number inside it later): {s['subj']}. "
                "No number, letter or mark inside it. Thick strokes and gaps, no detail smaller than one eighth of the canvas. " + LUMA_TAIL + " Square 1:1.")
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
        return f"{UI} {s['subj'][0].upper() + s['subj'][1:]} Square 1:1."
    body = s["subj"][0].upper() + s["subj"][1:] + "."
    if a == "luma":
        return f"{ICON_STYLE} Draw one UI element: {s['subj']}. {LUMA_TAIL} {shape[0].upper() + shape[1:]}."
    if a == "add":
        return f"{FX_STYLE} {body} {ADD_TAIL} {shape[0].upper() + shape[1:]}."
    if a == "opaque":
        return f"{UI} {body} {OPAQUE_PART_TAIL} {shape[0].upper() + shape[1:]}."
    nine = (" " + NINE_TAIL) if s["nine"] and s["nine"][0].isdigit() else ""
    return f"{UI} {body} One element only, centred, filling about 80% of the canvas.{nine} {ALPHA_TAIL} {shape[0].upper() + shape[1:]}."


def avoid(s):
    base = "luma" if s["cat"] == "plate" else s["cat"] if s["cat"] in ("icon", "background", "band", "card_art") else {"luma": "luma", "add": "add", "opaque": "opaque"}.get(s["alpha"], "part")
    extra = s.get("avoid") or ""
    return AVOID[base] + (", " + extra if extra else "") + "."


CAT_TITLE = OrderedDict([
    ("icon", "Icons"), ("plate", "Number plates"), ("card_art", "Standard Issue card art"), ("button", "Buttons and controls"), ("panel", "Panels, trays, rings and strips"),
    ("background", "Backgrounds"), ("tile", "Objective and Field tile backers"), ("frame", "Card frame parts"),
    ("band", "Camo bands"), ("fx", "Glows, outlines and overlays"),
])
CAT_FOLDER = {"icon": "assets/ui/kit/icons/", "plate": "assets/ui/kit/plates/", "card_art": "assets/sprites/banners/ (+ data/banners/<id>.tres)", "button": "assets/ui/kit/buttons/", "panel": "assets/ui/kit/panels/",
              "background": "assets/ui/backgrounds/", "tile": "assets/ui/kit/tiles/", "frame": "assets/ui/kit/frames/",
              "band": "assets/ui/kit/bands/", "fx": "assets/ui/kit/fx/"}


def folder(s):
    if s["id"].startswith("col_"):
        return "assets/sprites/board/"
    return CAT_FOLDER[s["cat"]]


# ---------------------------------------------------------------- batches (kc-ui-art2)
def is_retired(s):
    return s["status"].startswith("RETIRED")


ACTIVE = [s for s in S if not is_retired(s)]
RETIRED_S = [s for s in S if is_retired(s)]
BY_ID = {s["id"]: s for s in S}
B1 = ["stat_firepower", "stat_armor", "stat_cover", "stat_supply", "stat_deck", "stat_intel", "streak", "score", "kw_first_shot", "kw_pick"]
batches = [("P1", "P1 icons (imported, see `ui-kit-import-log.md`)", [BY_ID[i] for i in B1])]
for pri, title, ids in BATCHES:
    batches.append((pri, title, [BY_ID[i] for i in ids]))
taken = {s["id"] for _, _, g in batches for s in g}
# Remaining slots by priority, in visual-impact order of category; split evenly into batches of at most 10. Each prompt marks "New chat" where a group starts.
order = ["icon", "background", "fx", "frame", "button", "panel", "tile", "card_art", "band"]
for pri in ("P1", "P2", "P3"):
    rest = [s for c in order for s in ACTIVE if s["pri"] == pri and s["cat"] == c and s["id"] not in taken]
    if not rest:
        continue
    k = -(-len(rest) // 10)
    chunks, pos = [], 0
    for j in range(k):
        n_ = len(rest) // k + (1 if j < len(rest) % k else 0)
        chunks.append(rest[pos:pos + n_])
        pos += n_
    for chunk in chunks:
        cats = list(OrderedDict.fromkeys(CAT_TITLE[x["cat"]] for x in chunk))
        batches.append((pri, ", ".join(cats), chunk))
BATCH_OF = {}
for n, (_, _, g) in enumerate(batches, 1):
    for k, s_ in enumerate(g, 1):
        BATCH_OF[s_["id"]] = f"{n}" if n == 1 else f"{n}.{k}"

# ---------------------------------------------------------------- CSV
with open(OUT_CSV, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["id", "filename", "category", "section", "generate", "ship_size", "transparent", "nine_slice_margins_ltrb",
                "states", "where_used", "priority", "final_folder", "notes", "status", "code_id", "code_hook", "code_fallback", "batch"])
    for s in S:
        w.writerow([s["id"], s["file"], s["cat"], s["sec"], f"{s['gen']} ({SHAPE[s['gen']]})", s["ship"], ALPHA_CSV[s["alpha"]],
                    s["nine"], s["states"], s["used"], "-" if is_retired(s) else s["pri"], folder(s), s.get("notes", ""),
                    s["status"], s["code_id"], s["hook"], s["fallback"], BATCH_OF.get(s["id"], "-")])

# ---------------------------------------------------------------- counts
by_cat = Counter(s["cat"] for s in ACTIVE)
by_pri = Counter(s["pri"] for s in ACTIVE)
by_cat_pri = Counter((s["cat"], s["pri"]) for s in ACTIVE)
total = len(ACTIVE)
n_new = sum(1 for s in S if s["status"].startswith("new"))
n_ret = len(RETIRED_S)
n_done = sum(1 for s in S if s["status"].startswith("imported") and not is_retired(s))
p1 = [s for s in ACTIVE if s["pri"] == "P1"]

out = []
o = out.append

o(open(sys.argv[4]).read().replace("{TOTAL}", str(total)).replace("{P1}", str(by_pri["P1"]))
  .replace("{P2}", str(by_pri["P2"])).replace("{P3}", str(by_pri["P3"]))
  .replace("{NEW}", str(n_new)).replace("{RETIRED}", str(n_ret)).replace("{DONE}", str(n_done)).replace("{ALL}", str(len(S)))
  .replace("{TODO}", str(total - n_done)).replace("{BATCHES}", str(len(batches))))

# count table
o("| Category | Images | P1 | P2 | P3 |")
o("|---|---|---|---|---|")
for c, t in CAT_TITLE.items():
    if by_cat[c]:
        o(f"| {t} | {by_cat[c]} | {by_cat_pri[(c, 'P1')]} | {by_cat_pri[(c, 'P2')]} | {by_cat_pri[(c, 'P3')]} |")
o(f"| **Total active** | **{total}** | **{by_pri['P1']}** | **{by_pri['P2']}** | **{by_pri['P3']}** |")
o(f"| Retired (kept in the manifest, not generated) | {n_ret} | | | |")
o("")
o(open(sys.argv[5]).read().replace("{ICON_STYLE}", ICON_STYLE).replace("{FX_STYLE}", FX_STYLE).replace("{SI_STYLE}", SI_STYLE).replace("{SI_RULES}", SI_RULES).replace("{UI_STYLE}", UI_STYLE).replace("{PAPER_STYLE}", PAPER_STYLE).replace("{BG_STYLE}", BG_STYLE)
  .replace("{ICON_TAIL}", ICON_TAIL).replace("{ALPHA_TAIL}", ALPHA_TAIL).replace("{NINE_TAIL}", NINE_TAIL)
  .replace("{ADD_TAIL}", ADD_TAIL).replace("{LUMA_TAIL}", LUMA_TAIL))

# ---------------------------------------------------------------- slot catalogue
def entry_meta(s, o):
    o(f"- **Used in:** {s['used']}.")
    o(f"- **Generate:** {s['gen']} ({SHAPE[s['gen']]}). **Ship:** {s['ship']}. **Background:** {s.get('alpha_note') or ALPHA_LABEL[s['alpha']]}.")
    line = f"- **States:** {s['states']}."
    if s["nine"] and s["nine"][0].isdigit():
        line += f" **9-slice (L,T,R,B at ship size):** {s['nine']}."
    elif s["nine"]:
        line += f" **Repeat:** {s['nine']}."
    o(line)
    o(f"- **Code id:** `{s['code_id']}` ({s['hook']}). **Fallback:** {s['fallback']}.")
    if s.get("notes"):
        o(f"- **Note:** {s['notes']}")


o("## 4. Slot catalogue")
o("")
o("**kc-ui-art2.** The catalogue now follows the card design in the game (kc-cards-impl: C1+ on the board, Y2+ with the T1 orders frame off it, the O2 Operator card). "
  "Each entry gives its **status** (imported, active, revised, new), the **code id** the game asks `UiKit` / `IconSheet` for, whether that lookup exists today "
  "(*wired*) or still has to be added (*needs code*), and whether the code-drawn fallback is good enough. **The prompts themselves are in section 5**, in the "
  "order you generate them, so each one is written once; the entry number below (for example **Batch 2.3**) points to it.")
o("")
o(f"### 4.0 Retired slots ({n_ret})")
o("")
o("Not generated. The rows stay in `ui-kit-manifest.csv` with `status` = RETIRED and the reason, so old notes and the import log still resolve.")
o("")
o("| Slot | Was for | Why retired |")
o("|---|---|---|")
for s in RETIRED_S:
    o(f"| `{s['file'][:-4]}` | {s['used']} | {s['status'][len('RETIRED: '):]} |")
o("")
for c, t in CAT_TITLE.items():
    items = [s for s in ACTIVE if s["cat"] == c]
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
            tag = "" if s["status"] == "active" else f" · **{s['status']}**"
            o(f"##### `{s['file']}` · {s['pri']} · Batch {BATCH_OF[s['id']]}{tag}")
            o("")
            entry_meta(s, o)
            o("")

# ---------------------------------------------------------------- batches
o("## 5. Batches: the prompts, in the order to generate them")
o("")
o("Order is by **visual impact on the card design now in the game**: batch 2 is the new card look (the Pick icon, the Y2+ and T1 frames, the rail glow, the crack), "
  "batch 3 the Standard Issue starter (the first cards every new player sees, already wired), then the keyword and trait icons every card shows, then the rest of P1, P2 and P3.")
o("")
o("- **One batch = one sitting and one upload** (5 to 12 images, 10 to 15 minutes).")
o("- **One ChatGPT chat per group.** Each prompt says *New chat* where a new group starts; inside a group, stay in the same chat so the set matches.")
o("- **Every grey box is one complete prompt:** copy it as is, one per message. After the first image of a group you may shorten the next to \"Same style, next one: ...\", but paste the full box again if the look drifts.")
o("- **Upload** in the Studio Floor chat, **\"+ Images / logs\"**, with the batch's upload line (copy it from the batch).")
o("- **If one fails twice**, skip it and say so in the upload line; the code fallback covers every slot.")
o("")
o("| Batch | Priority | What | Images | Files |")
o("|---|---|---|---|---|")
for i, (pri, title, g) in enumerate(batches, 1):
    files = ", ".join(f"`{s['file'][:-4]}`" for s in g)
    o(f"| {i} | {pri} | {title} | {len(g)} | {files} |")
o("")
p1_batches = sum(1 for b in batches if b[0] == "P1")
o(f"P1 is batches 1 to {p1_batches} ({by_pri['P1']} images, {sum(1 for s in p1 if not s['status'].startswith('imported'))} still to make). "
  "After batches 2 and 3, pause and let the Technical Artist drop them into the build (batch 2 needs the small code hooks listed in section 7.4): "
  "if the frame style needs a tweak, it is cheaper to change the style block then.")
o("")
for i, (pri, title, g) in enumerate(batches, 1):
    o(f"### Batch {i} · {pri} · {title} ({len(g)})")
    o("")
    if i == 1:
        o("**Done** (kc-ui-import). `kw_pick` from this batch is retired: Pick is now `kw_pick_v2` (batch 2). The other 9 stay in use.")
        o("")
        continue
    o(f"Upload line: `kc-ui-art2 batch {i}: " + ", ".join(s["file"][:-4] for s in g) + "`")
    o("")
    prev = None
    for k, s in enumerate(g, 1):
        grp = s["sec"]
        newchat = " · **New chat**" if grp != prev else ""
        prev = grp
        o(f"#### {i}.{k} `{s['file']}` · {s['pri']}{newchat}")
        o("")
        st = "" if s["status"] == "active" else f" **{s['status']}.**"
        o(f"*{grp}.* {SHAPE[s['gen']].capitalize()}, {s.get('alpha_note') or ALPHA_LABEL[s['alpha']]}.{st} For: {s['used']}.")
        o("")
        o("```")
        o(prompt(s))
        o("```")
        o("")
        o(f"**Avoid:** {avoid(s)}")
        o("")
o(open(sys.argv[6]).read())

with open(OUT_MD, "w") as f:
    f.write("\n".join(out) + "\n")

print("active", total, "new", n_new, "retired", n_ret, dict(by_pri), "batches", len(batches), "p1 batches", p1_batches)

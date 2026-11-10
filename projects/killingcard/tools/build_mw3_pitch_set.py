#!/usr/bin/env python3
"""Build the private MW3 pitch art set (kc-cod2) from the downloaded calling cards.

PRIVATE PITCH PROTOTYPE ONLY. Reads the git-ignored download folder and writes another
git-ignored folder; no image ever leaves the ignored tree and nothing here is committed
except this script and the id list (documentation/art/mw3-pitch-set.csv).

Input:
  documentation/art/mw3-pitch-set.csv   curated list: card (chassis / Operator weapon id), id,
                                        title, kind, animated, mastery_family, tier_rank, family
                                        (kc-art-traits: honors / operators / mastery / horde /
                                        standard, from the MW3 manifest section), source_file
  <src>/images/<source_file>            originals from tools/fetch_mw3_calling_cards.py
Output (<out>, default source/project-killingcard/assets/licensed/mw3_pitch/):
  <id>.webp           still, 4:1 at --still-width (first GIF frame composited, or the PNG)
  <id>_frames.webp    animated cards only: every frame (sampled down to --max-frames) stacked
                      vertically at --frame-width, one 4:1 cell per frame (Godot 4.4 cannot
                      import GIF, so the game plays this sheet as a flipbook)
  *.webp.import       "keep" importer: Godot ships the WebP bytes as is (decoded at runtime,
                      like CardArt's bitmaps), so the export carries only these small files
  manifest.csv        (+ a "keep" .import) rows BannerArtDB reads: file, kind, card, title, id, animated,
                      frames_file, frames, frame_ms, mastery_family, tier_rank, family, trait
                      (kc-art-traits: the trait the art gives that chassis, "" = plain or printed;
                      ArtTraits in the game derives the same from family + CardData.trait_options)
Usage:
  python3 tools/build_mw3_pitch_set.py [--src DIR] [--out DIR] [--still-width 512]
         [--frame-width 384] [--max-frames 16] [--quality 70] [--still-quality 78] [--keep-stale]
kc-mw3-cards (size): the pitch game.pck must stay under the artifact limit (15 MiB per file;
target <= 14.5 MB). Defaults: frame sheets q70, stills q78 (cards draw at about 512x128 or less),
and files in <out> that the manifest no longer names (stale picks) are deleted, since the pitch
preset ships the whole folder.
Requires Pillow. Refuses to write into a folder git does not ignore.
"""
from __future__ import annotations

import argparse
import csv
import os
import subprocess
import sys

from PIL import Image, ImageSequence

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
PROJ = os.path.join(ROOT, "source", "project-killingcard")
KEEP_IMPORT = '[remap]\n\nimporter="keep"\n'

# kc-art-traits (documentation/design/art-traits.md §1.2 / §4): the list's `family` column was set
# from the MW3 manifest section with SECTION_FAMILY (documented here). Keep in sync with
# scripts/data/art_traits.gd (SECTION_FAMILY, FAMILY_TRAIT) and the cards' trait_options.
SECTION_FAMILY = {
    "Prestige Mastery / Multiplayer": "honors", "Challenges / Multiplayer": "honors",
    "Challenges / General": "honors", "Ranked Play / Multiplayer": "honors",
    "Standard / Store": "operators", "Standard / Battle Pass": "operators",
    "Standard / Armory Unlocks": "operators", "Standard / Events": "operators",
    "Warzone": "operators", "Ranked Play / Warzone": "operators", "Challenges / Warzone": "operators",
    "Weapon Mastery": "mastery",
    "Challenges / Zombies": "horde", "Prestige Mastery / Zombies": "horde", "Zombies": "horde",
    "Standard / Default": "standard", "Standard / Miscellaneous": "standard", "Campaign": "standard",
}
FAMILY_TRAIT = {"standard": "", "honors": "vanguard", "operators": "specops", "mastery": "heavy", "horde": "undead"}
# Units whose copies choose their trait through the art (CardData.trait_options); others print it.
TRAIT_OPTIONS = {
    "rifleman": ["", "specops", "undead"], "point_man": ["vanguard", "undead"], "breacher": ["vanguard", "heavy"],
    "shieldman": ["vanguard", "undead"], "flanker": ["specops", "undead"], "recon_specialist": ["specops", "undead"],
    "marksman": ["specops", "heavy"], "gunner": ["heavy", "specops"], "demolitions_expert": ["heavy", "undead"],
    "brawler": ["undead", "specops"], "combat_medic": ["undead", "specops"],
}


def trait_for(card: str, family: str) -> str:
    t = FAMILY_TRAIT.get(family, "")
    return t if t in TRAIT_OPTIONS.get(card, [None]) else ""


def is_ignored(path: str) -> bool:
    probe = os.path.join(path, "probe.webp")
    r = subprocess.run(["git", "check-ignore", "-q", probe], cwd=ROOT, capture_output=True)
    return r.returncode == 0


def fit_4x1(img: Image.Image, width: int) -> Image.Image:
    """Centre-crop to 4:1 (a few cards are 3.5-4.06:1) and resize to width x width/4."""
    w, h = img.size
    if w / h > 4.0:
        nw = int(round(h * 4.0))
        img = img.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    elif w / h < 4.0:
        nh = int(round(w / 4.0))
        img = img.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    return img.resize((width, width // 4), Image.LANCZOS)


def gif_frames(path: str) -> tuple[list[Image.Image], list[int]]:
    im = Image.open(path)
    frames, durations = [], []
    for fr in ImageSequence.Iterator(im):
        frames.append(fr.convert("RGB"))
        durations.append(int(fr.info.get("duration", im.info.get("duration", 80)) or 80))
    return frames, durations


def write_webp(img: Image.Image, path: str, quality: int) -> None:
    img.save(path, "WEBP", quality=quality, method=6)
    with open(path + ".import", "w") as f:
        f.write(KEEP_IMPORT)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--list", default=os.path.join(ROOT, "documentation", "art", "mw3-pitch-set.csv"))
    ap.add_argument("--src", default=os.path.join(PROJ, "assets", "licensed", "mw3"))
    ap.add_argument("--out", default=os.path.join(PROJ, "assets", "licensed", "mw3_pitch"))
    ap.add_argument("--still-width", type=int, default=512)
    ap.add_argument("--frame-width", type=int, default=384)
    ap.add_argument("--max-frames", type=int, default=16)
    ap.add_argument("--quality", type=int, default=70, help="WebP quality of the frame sheets")
    ap.add_argument("--still-quality", type=int, default=78, help="WebP quality of the stills")
    ap.add_argument("--keep-stale", action="store_true", help="keep files the manifest does not name")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    if not is_ignored(a.out):
        print("refusing: %s is not git-ignored" % a.out, file=sys.stderr)
        return 2
    rows = list(csv.DictReader(open(a.list, newline="")))
    out_rows = []
    total = 0
    for r in rows:
        src = os.path.join(a.src, "images", r["source_file"])
        if not os.path.exists(src):
            print("missing", src, file=sys.stderr)
            continue
        rid = r["id"]
        row = {"file": rid + ".webp", "kind": r["kind"], "card": r["card"], "title": r["title"], "id": rid,
               "animated": "no", "frames_file": "", "frames": "", "frame_ms": "",
               "mastery_family": r.get("mastery_family", ""), "tier_rank": r.get("tier_rank", ""),
               "family": r.get("family", ""), "trait": trait_for(r["card"], r.get("family", ""))}
        if src.lower().endswith(".gif"):
            frames, durs = gif_frames(src)
        else:
            frames, durs = [Image.open(src).convert("RGB")], [0]
        # Still: a middle frame shows the finished composition (first frames are often a fade-in).
        still = fit_4x1(frames[len(frames) // 2], a.still_width)
        write_webp(still, os.path.join(a.out, row["file"]), a.still_quality)
        total += os.path.getsize(os.path.join(a.out, row["file"]))
        if len(frames) > 1 and r.get("animated", "no") == "yes":
            step = max(1, -(-len(frames) // a.max_frames))
            picked = frames[::step]
            loop_ms = sum(durs)
            fw, fh = a.frame_width, a.frame_width // 4
            sheet = Image.new("RGB", (fw, fh * len(picked)))
            for i, fr in enumerate(picked):
                sheet.paste(fit_4x1(fr, fw), (0, i * fh))
            row["frames_file"] = rid + "_frames.webp"
            write_webp(sheet, os.path.join(a.out, row["frames_file"]), a.quality)
            total += os.path.getsize(os.path.join(a.out, row["frames_file"]))
            row.update(animated="yes", frames=str(len(picked)), frame_ms=str(max(30, round(loop_ms / len(picked)))))
        out_rows.append(row)
    with open(os.path.join(a.out, "manifest.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(out_rows[0].keys()))
        w.writeheader()
        w.writerows(out_rows)
    # Keep the CSV as a plain file (Godot would otherwise import it as a translation table).
    with open(os.path.join(a.out, "manifest.csv.import"), "w") as f:
        f.write(KEEP_IMPORT)
    if not a.keep_stale:
        keep = {"manifest.csv"} | {r["file"] for r in out_rows} | {r["frames_file"] for r in out_rows if r["frames_file"]}
        stale = [n for n in os.listdir(a.out) if n.endswith(".webp") and n not in keep]
        for n in stale:
            for victim in (n, n + ".import"):
                if os.path.exists(os.path.join(a.out, victim)):
                    os.remove(os.path.join(a.out, victim))
        if stale:
            print("removed %d stale WebP files no manifest row names" % len(stale))
    print("%d arts (%d animated), %.2f MB of WebP in %s" % (len(out_rows), sum(r["animated"] == "yes" for r in out_rows),
                                                          total / 1e6, a.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())

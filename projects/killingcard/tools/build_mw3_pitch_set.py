#!/usr/bin/env python3
"""Build the private MW3 pitch art set (kc-cod2) from the downloaded calling cards.

PRIVATE PITCH PROTOTYPE ONLY. Reads the git-ignored download folder and writes another
git-ignored folder; no image ever leaves the ignored tree and nothing here is committed
except this script and the id list (documentation/art/mw3-pitch-set.csv).

Input:
  documentation/art/mw3-pitch-set.csv   curated list: card (chassis / Operator weapon id), id,
                                        title, kind, animated, mastery_family, tier_rank, source_file
  <src>/images/<source_file>            originals from tools/fetch_mw3_calling_cards.py
Output (<out>, default source/project-killingcard/assets/licensed/mw3_pitch/):
  <id>.webp           still, 4:1 at --still-width (first GIF frame composited, or the PNG)
  <id>_frames.webp    animated cards only: every frame (sampled down to --max-frames) stacked
                      vertically at --frame-width, one 4:1 cell per frame (Godot 4.4 cannot
                      import GIF, so the game plays this sheet as a flipbook)
  *.webp.import       "keep" importer: Godot ships the WebP bytes as is (decoded at runtime,
                      like CardArt's bitmaps), so the export carries only these small files
  manifest.csv        (+ a "keep" .import) rows BannerArtDB reads: file, kind, card, title, id, animated,
                      frames_file, frames, frame_ms, mastery_family, tier_rank
Usage:
  python3 tools/build_mw3_pitch_set.py [--src DIR] [--out DIR] [--still-width 512]
         [--frame-width 384] [--max-frames 16] [--quality 80]
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
    ap.add_argument("--quality", type=int, default=80)
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
               "mastery_family": r.get("mastery_family", ""), "tier_rank": r.get("tier_rank", "")}
        if src.lower().endswith(".gif"):
            frames, durs = gif_frames(src)
        else:
            frames, durs = [Image.open(src).convert("RGB")], [0]
        # Still: a middle frame shows the finished composition (first frames are often a fade-in).
        still = fit_4x1(frames[len(frames) // 2], a.still_width)
        write_webp(still, os.path.join(a.out, row["file"]), a.quality + 5)
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
    print("%d arts (%d animated), %.2f MB of WebP in %s" % (len(out_rows), sum(r["animated"] == "yes" for r in out_rows),
                                                          total / 1e6, a.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())

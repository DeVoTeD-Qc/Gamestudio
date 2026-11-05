#!/usr/bin/env python3
"""Fetch the Call of Duty: Modern Warfare III calling cards listed on the Call of Duty Fandom wiki.

PRIVATE PITCH PROTOTYPE ONLY. The images are Activision's. They are downloaded into a
git-ignored folder and must NEVER be committed (the Gamestudio repo is public) or published.

What it does (stdlib only, polite, resumable):
  1. MediaWiki API `action=parse` on the MW3 calling-card page -> the page HTML and section list.
  2. Parses every card table row: name, "how to obtain", section path, table caption, image file.
  3. MediaWiki API `action=query&prop=imageinfo` in batches of 50 -> original URL, size, mime.
  4. Downloads each original into <out>/images/<File_Name.ext> (skips files already complete).
  5. Writes <out>/_cache/cards.json (rows + imageinfo; no image data).

Usage:
  python3 tools/fetch_mw3_calling_cards.py [--out DIR] [--limit N] [--no-download]
Default out: source/project-killingcard/assets/licensed/mw3 (relative to projects/killingcard).

Network: callofduty.fandom.com (API) and static.wikia.nocookie.net (images) only.
Rate: at most 2 requests per second, 4 retries with backoff, User-Agent identifies the prototype.
"""
from __future__ import annotations

import argparse
import html
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from html.parser import HTMLParser

API = "https://callofduty.fandom.com/api.php"
PAGE = "Calling_Cards/Call_of_Duty:_Modern_Warfare_III"
SOURCE_PAGE_URL = "https://callofduty.fandom.com/wiki/" + PAGE
USER_AGENT = "GamestudioPrototype/1.0 (private pitch prototype)"
ALLOWED_HOSTS = {"callofduty.fandom.com", "static.wikia.nocookie.net"}
MIN_INTERVAL = 0.5  # seconds between requests -> <= 2 requests/s
RETRIES = 4

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUT = os.path.join(HERE, "..", "source", "project-killingcard", "assets", "licensed", "mw3")

_last_request = 0.0


def _throttle() -> None:
    global _last_request
    wait = MIN_INTERVAL - (time.monotonic() - _last_request)
    if wait > 0:
        time.sleep(wait)
    _last_request = time.monotonic()


def http_get(url: str) -> bytes:
    host = urllib.parse.urlparse(url).hostname or ""
    if host not in ALLOWED_HOSTS:
        raise ValueError(f"refusing host {host!r}")
    delay = 2.0
    for attempt in range(1, RETRIES + 1):
        _throttle()
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept-Encoding": "identity"})
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return resp.read()
        except urllib.error.HTTPError as e:
            if e.code in (404, 410):
                raise
            err = f"HTTP {e.code}"
            if e.code == 429:
                delay = max(delay, float(e.headers.get("Retry-After") or 10))
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            err = str(e)
        if attempt == RETRIES:
            raise RuntimeError(f"GET failed after {RETRIES} tries: {url} ({err})")
        print(f"  retry {attempt} in {delay:.0f}s: {err}", file=sys.stderr)
        time.sleep(delay)
        delay *= 2
    raise AssertionError("unreachable")


def api(params: dict) -> dict:
    params = dict(params, format="json", formatversion="2")
    return json.loads(http_get(API + "?" + urllib.parse.urlencode(params)))


# ---------------------------------------------------------------- page parsing
class CardTableParser(HTMLParser):
    """Collects card rows: section path (h2/h3/h4), table caption, cells text, image key."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.path: dict[int, str] = {}
        self.in_headline = 0
        self.headline_level = 0
        self.headline_text = ""
        self.caption = ""
        self.in_table = 0
        self.row: list[dict] | None = None
        self.cell: dict | None = None
        self.th_row = False
        self.th_text = ""
        self.rows: list[dict] = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag in ("h2", "h3", "h4"):
            self.headline_level = int(tag[1])
            self.headline_text = ""
        elif tag == "span" and "mw-headline" in (a.get("class") or "") and self.headline_level:
            self.in_headline = 1
        elif tag == "table" and "article-table" in (a.get("class") or ""):
            self.in_table += 1
            self.caption = ""
        elif self.in_table and tag == "tr":
            self.row = []
            self.th_row = False
            self.th_text = ""
        elif self.in_table and tag == "th":
            self.th_row = True
        elif self.in_table and tag == "td" and self.row is not None:
            self.cell = {"text": "", "image": ""}
        elif self.cell is not None and tag == "img" and a.get("data-image-key"):
            self.cell["image"] = urllib.parse.unquote(a["data-image-key"])

    def handle_endtag(self, tag):
        if tag == "span" and self.in_headline:
            self.in_headline = 0
            lvl = self.headline_level
            self.path[lvl] = self.headline_text.strip()
            for k in list(self.path):
                if k > lvl:
                    del self.path[k]
        elif tag in ("h2", "h3", "h4"):
            self.headline_level = 0
        elif tag == "table" and self.in_table:
            self.in_table -= 1
        elif self.in_table and tag == "td" and self.cell is not None and self.row is not None:
            self.cell["text"] = re.sub(r"\s+", " ", self.cell["text"]).strip()
            self.row.append(self.cell)
            self.cell = None
        elif self.in_table and tag == "tr" and self.row is not None:
            if self.th_row and not self.row:
                t = re.sub(r"\s+", " ", self.th_text).strip()
                if t and t not in ("Name How to obtain Calling Card",):
                    self.caption = t
            elif len(self.row) >= 3 and self.row[-1]["image"]:
                self.rows.append({
                    "section": " / ".join(self.path[k] for k in sorted(self.path)),
                    "group": self.caption,
                    "title": self.row[0]["text"],
                    "how": self.row[1]["text"],
                    "file": self.row[-1]["image"],
                })
            self.row = None

    def handle_data(self, data):
        if self.in_headline:
            self.headline_text += data
        elif self.cell is not None:
            self.cell["text"] += data
        elif self.in_table and self.th_row:
            self.th_text += " " + data


def list_cards() -> list[dict]:
    parsed = api({"action": "parse", "page": PAGE, "prop": "images|sections|text"})["parse"]
    p = CardTableParser()
    p.feed(parsed["text"])
    seen, rows = set(), []
    for r in p.rows:
        if r["file"] in seen:  # keep the first listing of a file
            continue
        seen.add(r["file"])
        rows.append(r)
    listed = set(parsed.get("images", []))
    print(f"page lists {len(listed)} images; {len(rows)} card rows parsed", file=sys.stderr)
    return rows


def add_imageinfo(rows: list[dict]) -> None:
    by_title = {"File:" + r["file"].replace("_", " "): r for r in rows}
    titles = list(by_title)
    for i in range(0, len(titles), 50):
        chunk = titles[i:i + 50]
        res = api({"action": "query", "titles": "|".join(chunk), "prop": "imageinfo",
                   "iiprop": "url|size|mime"})
        norm = {n["to"]: n["from"] for n in res["query"].get("normalized", [])}
        for page in res["query"]["pages"]:
            t = norm.get(page["title"], page["title"])
            r = by_title.get(t) or by_title.get(page["title"])
            if r is None or not page.get("imageinfo"):
                continue
            ii = page["imageinfo"][0]
            r.update(url=ii["url"], w=ii.get("width", 0), h=ii.get("height", 0), mime=ii.get("mime", ""),
                     bytes=ii.get("size", 0))
        print(f"  imageinfo {min(i + 50, len(titles))}/{len(titles)}", file=sys.stderr)


def download(rows: list[dict], img_dir: str, limit: int | None) -> tuple[int, int, list[str]]:
    os.makedirs(img_dir, exist_ok=True)
    got = skipped = 0
    failed: list[str] = []
    todo = rows if limit is None else rows[:limit]
    for n, r in enumerate(todo, 1):
        if not r.get("url"):
            failed.append(r["file"] + " (no imageinfo)")
            continue
        dest = os.path.join(img_dir, r["file"])
        if os.path.exists(dest) and (not r.get("bytes") or os.path.getsize(dest) == r["bytes"]):
            skipped += 1
            continue
        try:
            # Without format=original the CDN content-negotiates a lossy WebP re-encode.
            sep = "&" if "?" in r["url"] else "?"
            data = http_get(r["url"] + sep + "format=original")
        except Exception as e:  # keep going; resumable on the next run
            failed.append(f"{r['file']} ({e})")
            continue
        tmp = dest + ".part"
        with open(tmp, "wb") as f:
            f.write(data)
        os.replace(tmp, dest)
        got += 1
        if n % 50 == 0:
            print(f"  downloaded {n}/{len(todo)}", file=sys.stderr)
    return got, skipped, failed


def assert_ignored(path: str) -> None:
    """Refuse to write licensed images anywhere git would track them."""
    try:
        res = subprocess.run(["git", "check-ignore", "-q", os.path.join(path, "images", "probe.png")],
                             cwd=os.path.dirname(os.path.abspath(path)) or ".", capture_output=True)
    except FileNotFoundError:
        return  # no git: nothing to protect
    if res.returncode == 1:
        sys.exit(f"ABORT: {path} is not git-ignored. Licensed images must never be committed.")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--limit", type=int, default=None, help="download at most N images (testing)")
    ap.add_argument("--no-download", action="store_true")
    ap.add_argument("--refresh", action="store_true", help="re-read the page even if the cache exists")
    args = ap.parse_args()
    out = os.path.abspath(args.out)
    os.makedirs(out, exist_ok=True)
    assert_ignored(out)
    cache = os.path.join(out, "_cache", "cards.json")
    os.makedirs(os.path.dirname(cache), exist_ok=True)
    if os.path.exists(cache) and not args.refresh:
        rows = json.load(open(cache, encoding="utf-8"))["cards"]
        print(f"using cached list: {len(rows)} cards", file=sys.stderr)
    else:
        rows = list_cards()
        add_imageinfo(rows)
        with open(cache, "w", encoding="utf-8") as f:
            json.dump({"source": SOURCE_PAGE_URL, "fetched": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                       "cards": rows}, f, indent=1, ensure_ascii=False)
    if not args.no_download:
        got, skipped, failed = download(rows, os.path.join(out, "images"), args.limit)
        print(f"downloaded {got}, already present {skipped}, failed {len(failed)}", file=sys.stderr)
        for f_ in failed:
            print("  FAILED " + f_, file=sys.stderr)
        if failed:
            sys.exit(2)


if __name__ == "__main__":
    main()

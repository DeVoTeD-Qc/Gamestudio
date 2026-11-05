#!/usr/bin/env python3
"""Self-test for tools/kpi_sheet.py (p20). Standard library only.

    python3 tools/test_kpi_sheet.py

Uses the SYNTHETIC logs in qa/playtesting/synthetic/ (made by tools/synthetic_playtest_sessions.gd
from the real PlaytestLog) and derives edge cases from them in a temp folder: the same sessions
in overlapping exports, a cut-off export, a line that breaks the schema, a non-log file, the
CallingCard-style single JSON document, and an empty folder. Numbers are cross-checked against a
direct count of the raw lines.
"""

from __future__ import annotations

import contextlib
import csv
import io
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import kpi_sheet  # noqa: E402

SYNTH = TOOLS.parent / "qa" / "playtesting" / "synthetic"
FULL = SYNTH / "SYNTHETIC-3-iphone-sessions-1-to-4.jsonl"
FIRST = SYNTH / "SYNTHETIC-1-iphone-first-session.jsonl"


def run(*args: str) -> tuple[int, str]:
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
        code = kpi_sheet.main(list(args))
    return code, buf.getvalue()


def kpis(md: str) -> dict[str, tuple[str, str]]:
    out = {}
    in_table = False
    for line in md.splitlines():
        if line.startswith("## "):
            in_table = line == "## KPI sheet"
        elif in_table and line.startswith("| ") and not line.startswith("| KPI") and not line.startswith("|---"):
            cells = [c.strip() for c in line.strip("|").split(" | ")]
            out[cells[0]] = (cells[2], cells[4].strip("*"))
    return out


def raw(path: Path) -> list[dict]:
    return [json.loads(x) for x in path.read_text().splitlines() if x.strip()]


class KpiSheetTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="ks_kpi_"))
        self.out = self.tmp / "out" / "sheet"

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def sheet(self, *inputs: Path, extra: tuple[str, ...] = ()) -> tuple[int, str, str]:
        code, log = run(*map(str, inputs), "--include-synthetic", "--out", str(self.out), *extra)
        md = self.out.with_suffix(".md").read_text() if code == 0 else ""
        return code, log, md

    def test_synthetic_files_exist(self) -> None:
        for p in (FIRST, FULL, SYNTH / "SYNTHETIC-2-iphone-renamed-to-json.json"):
            self.assertTrue(p.is_file(), f"missing {p}: run tools/synthetic_playtest_sessions.gd")

    def test_every_synthetic_line_matches_schema(self) -> None:
        schema, src = kpi_sheet.load_schema(None)
        self.assertIn("playtest_log.gd", src, "should read the game's SCHEMA, not the fallback")
        self.assertEqual(schema, kpi_sheet.FALLBACK_SCHEMA, "built-in fallback drifted from playtest_log.gd")
        for p in SYNTH.iterdir():
            for e in kpi_sheet.read_log(p).events:
                self.assertEqual(kpi_sheet.validate(e, schema), [], f"{p.name}: {e}")

    def test_full_sheet_numbers(self) -> None:
        code, log, md = self.sheet(SYNTH)
        self.assertEqual(code, 0, log)
        k = kpis(md)
        ev = raw(FULL)
        ends = [e for e in ev if e["event"] == "match_end"]
        wins = sum(1 for e in ends if e["result"] == "win")
        self.assertIn(f"({sum(1 for e in ends if e['killstreaks_used'] > 0)}/{len(ends)})", k["Matches with ≥ 1 killstreak used"][0])
        self.assertEqual(k["Tutorial completion"], ("100% (1/1)", "PASS"))
        self.assertEqual(k["Matches per finished run"][0].split(" (")[0], "median 5.0")
        # bracket results add up to all finished matches and wins
        total_w = total = 0
        for b in ("bracket 1", "bracket 2", "rival"):
            res = k[f"Win rate vs AI, {b}"][0]
            w, l, d = (int(x[:-1]) for x in res.split("(")[1].rstrip(")").split())
            total_w += w
            total += w + l + d
        self.assertEqual((total_w, total), (wins, len(ends)))
        self.assertEqual(k["Win rate vs AI, bracket 2"][1], "TOO HARD")
        nm = [e["seconds_after_end"] for e in ev if e["event"] == "next_match_clicked"]
        self.assertIn(f"({sum(1 for s in nm if s <= 60)}/{len(nm)})", k["One more match (next within 60 s)"][0])
        self.assertEqual(k["Survey Q2 (Shooter segment)"], ("3.3", "MISS"))
        self.assertEqual(k["Survey Q4 (all)"][0], "5.0")  # the skipped q4 is left out, not counted as 0
        first_win = next(e for e in ev if e["event"] == "match_end" and e["result"] == "win")
        s = round(first_win["t_ms"] / 1000)
        self.assertEqual(k["Time to first win (Shooter segment)"], (f"{s // 60}:{s % 60:02d}", "MISS"))
        self.assertIn("SYNTHETIC TEST DATA", md)
        self.assertIn("tutorial stall | step 9", md)
        self.assertIn("app hidden during a match", md)
        self.assertIn("survey statements skipped | q4", md)
        self.assertIn("I did not see why my rifleman lost the mid lane.", md)
        with self.out.with_suffix(".csv").open() as fh:
            rows = list(csv.reader(fh))
        self.assertEqual(sum(1 for r in rows if r and r[0] == "match"), len(ends) + 1)  # + the unfinished one

    def test_overlapping_exports_deduplicate(self) -> None:
        _, _, all_md = self.sheet(SYNTH)
        _, _, one_md = self.sheet(FULL)
        self.assertEqual(kpis(all_md), kpis(one_md))
        self.assertIn("4 session(s), 1 tester(s)", all_md.replace("**", "").replace("Logs read: 3 file(s), ", ""))

    def test_synthetic_left_out_by_default(self) -> None:
        code, log = run(str(SYNTH), "--out", str(self.out))
        self.assertEqual(code, 1)
        self.assertIn("synthetic", log)
        self.assertFalse(self.out.with_suffix(".md").exists())

    def test_cut_off_bad_line_and_non_log(self) -> None:
        d = self.tmp / "in"
        d.mkdir()
        text = FIRST.read_text()
        (d / "cut.jsonl").write_text(text[: len(text) - 40])            # last line cut mid-way
        lines = text.splitlines()
        bad = json.loads(lines[5])
        bad["surprise"] = 1
        lines[5] = json.dumps(bad)
        lines.insert(7, "not json at all")
        (d / "bad.json").write_text("\n".join(lines) + "\n")
        (d / "notes.json").write_text(json.dumps({"hello": "world"}))
        code, log, md = self.sheet(d)
        self.assertEqual(code, 0, log)
        self.assertIn("last line cut off", md)
        self.assertIn("1 unreadable lines", md)
        self.assertIn("extra ['surprise']: 1", md)
        self.assertIn("skipped `", md)
        self.assertIn("Conflicting duplicates:** 1", md)  # the patched line differs from the cut copy

    def test_single_json_document_format(self) -> None:
        doc = {"format": "killstreak-playtest-log", "events": raw(FIRST)}
        p = self.tmp / "doc.json"
        p.write_text(json.dumps(doc))
        code, log, md = self.sheet(p)
        self.assertEqual(code, 0, log)
        self.assertEqual(kpis(md)["Tutorial completion"][1], "PASS")

    def test_session_unit(self) -> None:
        code, _, md = self.sheet(FULL, extra=("--unit", "session"))
        self.assertEqual(code, 0)
        self.assertIn("4 tester(s)", md)

    def test_no_inputs(self) -> None:
        empty = self.tmp / "empty"
        empty.mkdir()
        self.assertEqual(run(str(empty))[0], 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)

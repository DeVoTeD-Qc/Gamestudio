#!/usr/bin/env python3
"""Self-test for tools/kpi_sheet.py (cc18). Standard library only.

    python3 tools/test_kpi_sheet.py

Uses the SYNTHETIC logs in playtest-logs/synthetic/ (made by tools/synthetic_playtest_sessions.gd
from the real PlaytestLog) and derives edge cases from them in a temp folder: a cut-off export,
a raw .jsonl log, a line that breaks the schema, the same export twice, a non-log file.
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

SYNTH = TOOLS.parent / "playtest-logs" / "synthetic"
A = SYNTH / "SYNTHETIC-A-menu-desktop.json"


def run(*args: str) -> tuple[int, str]:
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
        code = kpi_sheet.main(list(args))
    return code, buf.getvalue()


def statuses(md: str) -> dict[str, str]:
    out = {}
    for line in md.splitlines():
        if line.startswith("| ") and "**" in line:
            cells = [c.strip() for c in line.strip("|").split("|")]
            out[cells[0]] = cells[-1].strip("*")
    return out


class KpiSheetTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="kpi_test_"))
        self.out = self.tmp / "out" / "sheet"

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_schema_read_from_game_matches_builtin_copy(self) -> None:
        schema, notes = kpi_sheet.load_schema(None)
        self.assertEqual(notes, [], "the game's SCHEMA / ENUMS equal the tool's fallback copy")
        self.assertIn("duel_end", schema.events)

    def test_synthetic_left_out_by_default(self) -> None:
        code, text = run(str(SYNTH), "--out", str(self.out))
        self.assertEqual(code, 1)
        self.assertIn("left out", text)
        self.assertFalse(self.out.with_suffix(".md").exists(), "nothing written")

    def test_synthetic_sheet_values(self) -> None:
        code, _ = run(str(SYNTH), "--include-synthetic", "--out", str(self.out))
        self.assertEqual(code, 0)
        md_path = self.out.with_name("sheet-SYNTHETIC.md")
        md = md_path.read_text()
        self.assertTrue(md.startswith("> **SYNTHETIC DATA"), "banner on top")
        self.assertEqual(statuses(md), {
            "Intent to collect": "FAIL", "Album pull": "PASS", "Session fit (duel)": "PASS",
            "Session fit (tutorial D1)": "FAIL", "Fairness": "PASS", "Load": "FAIL"})
        self.assertIn("3:18 median of 7 duels", md)
        self.assertIn("3:56 median, 2/3 cleared", md)
        with md_path.with_suffix(".csv").open() as fh:
            rows = list(csv.DictReader(fh))
        self.assertTrue(all(r["synthetic"] == "yes" for r in rows))
        overall = {r["metric"]: r for r in rows if r["scope"] == "overall"}
        self.assertEqual(float(overall["Session fit (duel)"]["value"]), 198.0)
        self.assertEqual(float(overall["Load"]["value"]), 14200.0)

    def test_every_synthetic_line_valid(self) -> None:
        schema, _ = kpi_sheet.load_schema(None)
        for f in SYNTH.glob("*.json"):
            for e in json.loads(f.read_text())["events"]:
                self.assertEqual(kpi_sheet.validate_entry(e, schema), [], f"{f.name} seq {e.get('seq')}")

    def test_cut_off_export_is_salvaged(self) -> None:
        text = A.read_text()
        cut = self.tmp / "SYNTHETIC-cut.json"
        cut.write_text(text[: int(len(text) * 0.6)])
        lf = kpi_sheet.read_log(cut)
        self.assertEqual(lf.kind, "salvaged")
        self.assertTrue(lf.synthetic, "file name keeps it synthetic")
        self.assertGreater(len(lf.events), 30)
        code, _ = run(str(cut), "--include-synthetic", "--out", str(self.out))
        self.assertEqual(code, 0)
        md = self.out.with_name("sheet-SYNTHETIC.md").read_text()
        self.assertIn("cut off or damaged", md)
        self.assertIn("NO DATA", md, "the survey was cut off, so its KPIs say no data")

    def test_raw_jsonl_and_bad_line(self) -> None:
        events = json.loads(A.read_text())["events"]
        events[5] = dict(events[5], player_name="someone")  # breaks the schema (extra field)
        raw = self.tmp / "SYNTHETIC-raw.jsonl"
        raw.write_text("\n".join(json.dumps(e) for e in events) + "\n{\"broken\n")
        lf = kpi_sheet.read_log(raw)
        self.assertEqual(lf.kind, "jsonl")
        code, _ = run(str(raw), "--include-synthetic", "--out", str(self.out))
        self.assertEqual(code, 0)
        md = self.out.with_name("sheet-SYNTHETIC.md").read_text()
        self.assertIn("unexpected field 'player_name'", md)
        self.assertIn("| SYNTHETIC-raw.jsonl | jsonl | yes | 107 | 1 |", md)

    def test_same_export_twice_is_one_tester(self) -> None:
        d = self.tmp / "logs"
        d.mkdir()
        shutil.copy(A, d / "SYNTHETIC-first.json")
        shutil.copy(A, d / "SYNTHETIC-again.json")
        code, text = run(str(d), "--include-synthetic", "--out", str(self.out))
        self.assertEqual(code, 0)
        self.assertIn("1 session(s), 1 tester(s)", text)
        code, text = run(str(d), str(SYNTH), "--include-synthetic", "--unit", "session", "--out", str(self.out))
        self.assertIn("3 session(s), 3 tester(s)", text)

    def test_unreadable_and_empty(self) -> None:
        junk = self.tmp / "notes.json"
        junk.write_text("hello")
        code, text = run(str(junk), "--out", str(self.out))
        self.assertEqual(code, 1)
        self.assertIn("not a CallingCard export", text)
        empty = SYNTH / "SYNTHETIC-D-consent-off-empty.json"
        code, _ = run(str(empty), "--include-synthetic", "--out", str(self.out))
        self.assertEqual(code, 0)
        md = self.out.with_name("sheet-SYNTHETIC.md").read_text()
        self.assertEqual(set(statuses(md).values()), {"NO DATA"})
        self.assertIn("consent was off", md)


if __name__ == "__main__":
    unittest.main(verbosity=2)

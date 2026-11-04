#!/usr/bin/env python3
"""Self-test for tools/kpi_sheet.py (cz18). Standard library only.

    python3 tools/test_kpi_sheet.py

Uses the SYNTHETIC logs in playtest-logs/synthetic/ (made by tools/synthetic_playtest_sessions.gd
from real headless matches through the real PlaytestLog) and derives edge cases from them in a temp
folder: a cut-off export, a raw .jsonl log, a line that breaks the schema, the same export twice, a
non-log file. Hand-made logs check the KPI recipes at their bars (Pack time 90th percentile, early
elimination, comeback, Hold from the second match, Brace, hidden armour, lost matches, iPhone load).
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
A = SYNTH / "SYNTHETIC-A-iphone-three-matches.json"


def run(*args: str) -> tuple[int, str]:
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
        code = kpi_sheet.main(list(args))
    return code, buf.getvalue()


def statuses(md: str) -> dict[str, str]:
    out = {}
    for line in md.splitlines():
        if line.startswith("| ") and line.rstrip().endswith("** |"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            out[cells[0]] = cells[-1].strip("*")
    return out


class Log:
    """Builds schema-valid log lines (defaults per field type, the first allowed enum value)."""

    def __init__(self, sid: str = "aaaaaaaaaaaa") -> None:
        self.schema, _ = kpi_sheet.load_schema(None)
        self.sid = sid
        self.seq = 0
        self.t = 0
        self.events: list[dict] = []

    def new_session(self, sid: str) -> None:
        self.sid, self.seq, self.t = sid, 0, 0

    def add(self, name: str, **fields) -> dict:
        e = {"v": 1, "sid": self.sid, "seq": self.seq, "t_ms": self.t, "event": name}
        for key, code in self.schema.events[name].items():
            enum = self.schema.enums.get(f"{name}.{key}")
            default = {"s": "", "i": 0, "n": 0.0, "b": False, "a": [], "d": {}}.get(code.rstrip("?"))
            if code.endswith("?"):
                default = None
            e[key] = enum[0] if enum else default
        e.update(fields)
        self.seq += 1
        self.t += 1000
        self.events.append(e)
        assert kpi_sheet.validate_entry(e, self.schema) == [], kpi_sheet.validate_entry(e, self.schema)
        return e

    def start(self, **device) -> None:
        self.add("session_start", **{"device_class": "phone", "os_family": "ios", "load_ms": 5000, **device})

    def match(self, result: str = "win", rounds: int = 10, packs: list[int] | None = None, holds: list[int] | None = None,
              round4_health: int = 5, eliminated_round: int | None = None, cause: str = "shot",
              duration_s: float = 900.0, end: bool = True, resumed: bool = False) -> None:
        if resumed:
            self.add("match_resumed", round=3)
        else:
            self.add("match_start", drop_human="motel", drop_ai="quarry", hand_size=5)
        for r in range(1, rounds + 1):
            self.add("round_start", round=r, health_h=round4_health if r == 4 else 5, health_ai=5, bounty="none")
        for i, ms in enumerate(packs or []):
            held = (holds or [])[i] if holds and i < len(holds) else 0
            self.add("pack", pack_ms=ms, hold_count=held, hold_ids=["duck"] * held)
            self.add("turn_end", turn_ms=ms + 30000)
        if eliminated_round is not None:
            self.add("elimination", seat="human", round=eliminated_round, by="shot")
        if end:
            self.add("match_end", result=result, rounds=rounds, cause=cause, duration_s=duration_s, resumed=resumed)

    def write(self, path: Path, synthetic: bool = False) -> Path:
        doc = {"format": "cardzone-playtest-log", "schema_version": 1, "exported_utc": "2026-11-16T10:00:00Z",
               "session_ids": sorted({e["sid"] for e in self.events}), "event_count": len(self.events),
               "events": self.events}
        if synthetic:
            doc["synthetic"] = True
        path.write_text(json.dumps(doc))
        return path


class KpiSheetTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="kpi_test_"))
        self.out = self.tmp / "out" / "sheet"

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def sheet(self, *paths: Path, extra: tuple[str, ...] = ()) -> str:
        code, text = run(*[str(p) for p in paths], "--out", str(self.out), *extra)
        self.assertEqual(code, 0, text)
        return self.out.with_suffix(".md").read_text()

    # --- schema and files ------------------------------------------------------------------

    def test_schema_read_from_game_matches_builtin_copy(self) -> None:
        schema, notes = kpi_sheet.load_schema(None)
        self.assertEqual(notes, [], "the game's SCHEMA / ENUMS equal the tool's fallback copy")
        for name in ("pack", "shot", "brace", "match_end", "survey"):
            self.assertIn(name, schema.events)

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
            "Pack time": "FAIL", "Human turn time": "FAIL", "Match length vs AI": "PASS",
            "Early elimination": "PASS", "Comeback": "PASS", "Hold used": "FAIL", "Brace used": "PASS",
            "Hidden-armour check (Q3)": "PASS", "Replay intent": "PASS", "Survey: play another": "FAIL",
            "Survey: damage understood": "FAIL", "Survey: packing quick": "FAIL",
            "Survey: choices over luck": "PASS", "Survey: AI fair": "PASS", "Load (iPhone)": "FAIL",
            "Saves": "PASS"})
        self.assertIn("4 session(s), 3 tester(s)", md, "the reload's second session joins its tester")
        self.assertIn("of 4 whole matches", md, "resumed and conceded matches left out of the length")
        self.assertIn("0 suspected lost, 1 resumed", md)
        self.assertIn("Resumed part #2 (ai, veteran)", md, "the resumed part keeps its match number")
        with md_path.with_suffix(".csv").open() as fh:
            rows = list(csv.DictReader(fh))
        self.assertTrue(all(r["synthetic"] == "yes" for r in rows))
        overall = {r["metric"]: r for r in rows if r["scope"] == "overall"}
        self.assertEqual(float(overall["Load (iPhone)"]["value"]), 12400.0)
        self.assertEqual(float(overall["Replay intent"]["value"]), round(2 / 3, 3))

    def test_every_synthetic_line_valid(self) -> None:
        schema, _ = kpi_sheet.load_schema(None)
        for f in SYNTH.glob("*.json"):
            doc = json.loads(f.read_text())
            self.assertTrue(doc.get("synthetic"), f"{f.name} is marked synthetic")
            for e in doc["events"]:
                self.assertEqual(kpi_sheet.validate_entry(e, schema), [], f"{f.name} seq {e.get('seq')}")
                if e["event"] == "turn_start" and e["seat"] == "ai":
                    self.assertEqual(e["hand_ids"], [], "an AI turn never names its cards")

    def test_cut_off_export_is_salvaged(self) -> None:
        text = A.read_text()
        cut = self.tmp / "SYNTHETIC-cut.json"
        cut.write_text(text[: int(len(text) * 0.3)])
        lf = kpi_sheet.read_log(cut)
        self.assertEqual(lf.kind, "salvaged")
        self.assertTrue(lf.synthetic, "file name keeps it synthetic")
        self.assertGreater(len(lf.events), 50)
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
        self.assertIn(f"| SYNTHETIC-raw.jsonl | jsonl | yes | {len(events)} | 1 |", md)

    def test_same_export_twice_is_one_tester(self) -> None:
        d = self.tmp / "logs"
        d.mkdir()
        shutil.copy(A, d / "SYNTHETIC-first.json")
        shutil.copy(A, d / "SYNTHETIC-again.json")
        code, text = run(str(d), "--include-synthetic", "--out", str(self.out))
        self.assertEqual(code, 0)
        self.assertIn("2 session(s), 1 tester(s)", text)
        code, text = run(str(d), str(SYNTH), "--include-synthetic", "--unit", "session", "--out", str(self.out))
        self.assertIn("4 session(s), 4 tester(s)", text)

    def test_unreadable_and_empty(self) -> None:
        junk = self.tmp / "notes.json"
        junk.write_text("hello")
        code, text = run(str(junk), "--out", str(self.out))
        self.assertEqual(code, 1)
        self.assertIn("not a CardZone export", text)
        empty = SYNTH / "SYNTHETIC-D-consent-off-empty.json"
        code, _ = run(str(empty), "--include-synthetic", "--out", str(self.out))
        self.assertEqual(code, 0)
        md = self.out.with_name("sheet-SYNTHETIC.md").read_text()
        self.assertEqual(set(statuses(md).values()), {"NO DATA"})
        self.assertIn("consent was off", md)

    # --- recipes at their bars ---------------------------------------------------------------

    def test_pack_turn_and_length_bars(self) -> None:
        log = Log()
        log.start()
        # 10 packs: median 9.5 s, 90th percentile (nearest rank: 9th of 10) 20 s -> pass.
        log.match(packs=[5000, 6000, 7000, 8000, 9000, 10000, 11000, 12000, 20000, 60000], rounds=8, duration_s=720)
        log.match(packs=[9000], rounds=14, duration_s=1200)
        log.add("quit", screen="title", reason="close")
        md = self.sheet(log.write(self.tmp / "a.json"))
        st = statuses(md)
        self.assertEqual(st["Pack time"], "PASS", md)
        self.assertIn("median 9.0 s, 90th pct 20.0 s of 11 packs", md)
        self.assertEqual(st["Human turn time"], "PASS")
        self.assertEqual(st["Match length vs AI"], "PASS", "16:00 median, rounds 8 and 14")
        log2 = Log()
        log2.start()
        log2.match(packs=[9000, 21000], rounds=15, duration_s=700)
        md = self.sheet(log2.write(self.tmp / "b.json"))
        st = statuses(md)
        self.assertEqual(st["Pack time"], "FAIL", "90th percentile 21 s")
        self.assertEqual(st["Match length vs AI"], "FAIL", "11:40 and 15 rounds")

    def test_elimination_comeback_and_hold(self) -> None:
        log = Log()
        log.start()
        # Match 1: the human is out in round 5 (early); at 3 health in round 4 -> no comeback.
        log.match(result="loss", rounds=5, round4_health=3, eliminated_round=5, packs=[5000], holds=[0])
        # Match 2: behind in round 4 but survives to round 10 and loses there -> comeback.
        log.match(result="loss", rounds=10, round4_health=2, eliminated_round=10, packs=[5000, 5000, 5000],
                  holds=[1, 2, 0])
        log.match(result="win", rounds=9, packs=[5000], holds=[0])
        md = self.sheet(log.write(self.tmp / "c.json"))
        st = statuses(md)
        self.assertEqual(st["Early elimination"], "FAIL", "1 of 3 matches early: 67% safe")
        self.assertIn("67% of 3 matches safe (1 early)", md)
        self.assertEqual(st["Comeback"], "PASS", "1 of 2 behind matches came back")
        self.assertIn("1/2 (50%)", md)
        self.assertEqual(st["Hold used"], "FAIL", "2 of 4 packs from match 2 on hold: 50%")
        self.assertIn("50% (2/4 packs)", md)

    def test_hold_share_counts_from_the_second_match(self) -> None:
        log = Log()
        log.start()
        log.match(packs=[5000, 5000], holds=[0, 0])          # match 1: never counted
        log.match(packs=[5000, 5000, 5000], holds=[1, 1, 0])  # 2 of 3 -> 67%
        md = self.sheet(log.write(self.tmp / "h.json"))
        self.assertEqual(statuses(md)["Hold used"], "PASS")
        self.assertIn("67% (2/3 packs)", md)
        log2 = Log()
        log2.start()
        log2.match(packs=[5000, 5000], holds=[2, 2])
        md = self.sheet(log2.write(self.tmp / "h2.json"))
        self.assertEqual(statuses(md)["Hold used"], "NO DATA", "only a first match")

    def test_brace_and_hidden_armour(self) -> None:
        def build(extra_full_brace: bool) -> Path:
            log = Log()
            log.start()
            log.add("match_start")
            for cards, possible in ((["duck"], True), ([], True), (["duck"], True), ([], False)):
                log.add("brace", cards=cards, card_count=len(cards), possible=possible)
            shots = [(0, True), (1, True), (2, True), (0, False)] + ([(0, True)] if extra_full_brace else [])
            for hits, allowed in shots:
                log.add("shot", shooter="human", target="ai", hits=hits, brace_allowed=allowed, damage=2)
            log.add("shot", shooter="ai", target="human", hits=0, brace_allowed=True, damage=2)  # not counted
            log.add("match_end", result="win", rounds=9)
            return log.write(self.tmp / "s.json")

        md = self.sheet(build(False))
        st = statuses(md)
        self.assertEqual(st["Brace used"], "PASS")
        self.assertIn("67% (2/3 prompts)", md)
        self.assertEqual(st["Hidden-armour check (Q3)"], "PASS")
        self.assertIn("33% (1/3 shots)", md)
        md = self.sheet(build(True))
        self.assertEqual(statuses(md)["Hidden-armour check (Q3)"], "FAIL", "2 of 4 fully braced")

    def test_lost_match_and_iphone_load(self) -> None:
        log = Log()
        log.start(load_ms=9000)
        log.match(packs=[5000], end=False)         # session 1 ends mid-match ...
        log.new_session("bbbbbbbbbbbb")
        log.start(load_ms=11000)
        log.match(packs=[5000])                    # ... and session 2 starts a new one: lost
        log.new_session("cccccccccccc")
        log.start(load_ms=20000, device_class="desktop", os_family="windows")
        md = self.sheet(log.write(self.tmp / "l.json"))
        st = statuses(md)
        self.assertEqual(st["Saves"], "FAIL")
        self.assertIn("1 suspected lost, 0 resumed", md)
        self.assertEqual(st["Load (iPhone)"], "FAIL", "11 s on an iPhone; the 20 s desktop does not count")
        self.assertIn("worst 11.0 s, 1/2 slow", md)
        ok = Log()
        ok.start()
        ok.match(packs=[5000], end=False)
        ok.new_session("dddddddddddd")
        ok.start()
        ok.match(packs=[5000], resumed=True)
        md = self.sheet(ok.write(self.tmp / "ok.json"))
        self.assertEqual(statuses(md)["Saves"], "PASS")
        self.assertIn("0 suspected lost, 1 resumed", md)

    def test_survey_bars_and_replay(self) -> None:
        paths = []
        answers = [{"q1": 5, "q2": 4, "q3": 4, "q4": 2, "q5": 3}, {"q1": 4, "q2": 4, "q3": 3, "q4": 4, "q5": 4},
                   {"q1": 4, "q2": 2, "q3": 5, "q4": 5, "q5": 4}]
        for i, a in enumerate(answers):
            log = Log(f"{i:012d}")
            log.start()
            log.match(packs=[5000])
            if i < 2:
                log.match(packs=[5000])
            log.add("survey", **a, open="", answered=5)
            paths.append(log.write(self.tmp / f"t{i}.json"))
        md = self.sheet(*paths)
        st = statuses(md)
        self.assertEqual(st["Survey: play another"], "PASS", "3/3")
        self.assertEqual(st["Survey: damage understood"], "FAIL", "2/3 = 67% < 70%")
        self.assertEqual(st["Survey: AI fair"], "PASS", "2/3 = 67% >= 60%")
        self.assertEqual(st["Replay intent"], "PASS", "2 of 3 testers started a 2nd match")
        self.assertIn("3 tester(s)", md)


if __name__ == "__main__":
    unittest.main(verbosity=2)

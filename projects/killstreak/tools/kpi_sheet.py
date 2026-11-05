#!/usr/bin/env python3
"""Killstreak playtest KPI sheet (p20).

Reads "Download log" files from the game (killstreak-playtest-<date>-<sid>.jsonl, or the same file
renamed to .json so the Studio Floor chat accepts it), checks every line against the logger's
schema (PlaytestLog.SCHEMA in source/project-killstreak/autoload/playtest_log.gd) and computes the
KPIs of documentation/production/playtest-metrics-plan.md per session, per tester (device) and
pooled, with the plan's targets. Writes a markdown KPI sheet and a CSV.

Usage:
    python3 tools/kpi_sheet.py                                   # qa/playtesting/logs/
    python3 tools/kpi_sheet.py qa/playtesting/logs/ more.jsonl --out qa/playtesting/kpi/kpi-sheet
    python3 tools/kpi_sheet.py qa/playtesting/synthetic --include-synthetic   # tool test only

Options:
    --out PATH            output path without extension (default qa/playtesting/kpi/kpi-sheet,
                          or .../kpi-sheet-SYNTHETIC when synthetic files are included)
    --unit tester|session tester (default): sessions found together in one file are one device /
                          tester (a device's log keeps every session). session: each session alone.
    --include-synthetic   also read SYNTHETIC-* files / files under a synthetic/ folder
    --schema PATH         playtest_log.gd to read SCHEMA from (default: the game's copy; falls
                          back to the copy built into this file)
    --title TEXT          heading for the sheet

Notes on the data (read before analysing):
  * A device's log holds every session since consent, so each export repeats the earlier
    sessions. Lines are de-duplicated on (sid, seq); conflicting duplicates are reported.
  * The game offers Download log only on the end-survey page after a finished run, once per page
    load. A session that never finished a run shows up only in a later export.
  * "Turn time" = round time: t_ms from the previous round_end (or match_start) to this round_end.
    It includes the reveal / firefight animation and, in round 1, the mulligan.
  * One more match: next_match_clicked.seconds_after_end counts from match_end, so it includes
    the After-Action and reward screens; it is a loop-pull signal, not pure idle time.
  * Tutorial completion = reached the last tutorial step (from data/tutorial/tutorial_script.tres).
    The log has no separate "skipped" event: a tutorial that stops early reads as not completed.

Standard library only. Exit code: 0 when a sheet was written, 1 when no session could be
counted (nothing written), 2 on bad arguments or no input files.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import statistics
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

TOOL_DIR = Path(__file__).resolve().parent
PROJECT_DIR = TOOL_DIR.parent
GAME_DIR = PROJECT_DIR / "source" / "project-killstreak"
DEFAULT_SCHEMA_GD = GAME_DIR / "autoload" / "playtest_log.gd"
TUTORIAL_TRES = GAME_DIR / "data" / "tutorial" / "tutorial_script.tres"
DEFAULT_IN = PROJECT_DIR / "qa" / "playtesting" / "logs"
DEFAULT_OUT = PROJECT_DIR / "qa" / "playtesting" / "kpi" / "kpi-sheet"
SCHEMA_VERSION = 1
COMMON = ("v", "sid", "seq", "t_ms", "event")
SURVEY_KEYS = ("q1", "q2", "q3", "q4", "q5")
SURVEY_TEXT = {
    "q1": "It felt like a modern shooter match.",
    "q2": "I understood why I won or lost firefights.",
    "q3": "I had interesting choices each round.",
    "q4": "Killstreaks felt exciting.",
    "q5": "I want to play another run.",
}

# Targets (playtest-metrics-plan.md, "KPIs & prototype targets").
T_TUTORIAL = 0.90
T_FIRST_WIN_S = 600.0
T_MATCH_S = (180.0, 300.0)
T_KS_SHARE = 0.80
T_OPDOWN = (0.40, 0.70)
T_WINRATE = {"bracket 1": 0.75, "bracket 2": 0.55, "rival": 0.40}
T_WINRATE_TOL = 0.15
T_NEXT_60 = 0.60
T_PICK = (0.05, 0.60)
T_PICK_MIN_OFFERS = 3
T_UNSPENT = 1.0
T_SURVEY = 4.0
# Confusion-signal thresholds (internal, not from the plan).
STALL_S = 60.0
LONG_ROUND_S = 120.0
HIGH_UNSPENT = 2

FALLBACK_SCHEMA: dict[str, list[str]] = {
    "session_start": ["schema", "consent_version", "platform", "os_family", "web", "browser",
                      "standalone", "embedded", "mobile", "touchscreen", "device_class", "engine",
                      "build", "load_ms", "date_utc", "screen", "segment"],
    "consent": ["given"], "input_type": ["kind"], "screen_profile": ["screen"], "screen": ["name"],
    "app_hidden": ["screen", "session_s"], "app_visible": ["screen", "session_s"],
    "quit": ["screen", "session_s", "reason"], "tutorial_step": ["step"],
    "run_start": ["seed", "killstreaks", "deck_size", "tickets"],
    "run_end": ["result", "matches", "duration_s", "wins", "losses", "draws"],
    "tickets": ["tickets"], "match_start": ["mode", "map", "match", "threat", "rival", "squad"],
    "round_end": ["round", "score", "enemy_score", "streak", "supply_unspent", "hand_size"],
    "round_stats": ["round", "supply_unspent", "hand_size"],
    "card_played": ["side", "card_id", "zone", "round"],
    "elimination": ["by", "victim", "zone", "by_killstreak", "round"],
    "operator_down": ["side", "round"], "killstreak_earned": ["id", "round", "streak"],
    "killstreak_used": ["id", "round"], "ability_used": ["id", "zone", "round"],
    "match_end": ["result", "rounds", "duration_s", "match", "max_streak", "killstreaks_earned",
                  "killstreaks_used", "cards_played", "operator_downs"],
    "next_match_clicked": ["seconds_after_end"], "offer_shown": ["kind", "offered"],
    "reward_pick": ["kind", "offered", "chosen", "skipped"],
    "attachment_pick": ["kind", "offered", "chosen", "skipped"],
    "perk_pick": ["kind", "offered", "chosen", "skipped"], "preview_toggled": ["on"],
    "pre_survey": ["shooter_weekly", "card_weekly", "deckbuilder", "segment"],
    "end_survey": ["q1", "q2", "q3", "q4", "q5", "open", "segment"],
    "log_exported": ["method", "bytes"],
}


# =============================================================================
# Schema and reading
# =============================================================================

def load_schema(path: Path | None) -> tuple[dict[str, list[str]], str]:
    path = path or DEFAULT_SCHEMA_GD
    try:
        text = path.read_text(encoding="utf-8")
        m = re.search(r"const SCHEMA: Dictionary = \{(.*?)\n\}", text, re.S)
        body = m.group(1) if m else ""
        schema: dict[str, list[str]] = {}
        for name, fields in re.findall(r'"(\w+)":\s*\[(.*?)\]', body, re.S):
            schema[name] = re.findall(r'"(\w+)"', fields)
        if schema:
            return schema, _rel(path)
    except OSError:
        pass
    return dict(FALLBACK_SCHEMA), "built-in copy (schema v1)"


def tutorial_step_count() -> int:
    try:
        idx = [int(x) for x in re.findall(r"^index = (\d+)", TUTORIAL_TRES.read_text(), re.M)]
        return max(idx) if idx else 17
    except OSError:
        return 17


def _rel(p: Path) -> str:
    try:
        return str(p.resolve().relative_to(PROJECT_DIR))
    except ValueError:
        return str(p)


@dataclass
class LogFile:
    path: Path
    events: list[dict] = field(default_factory=list)
    bad_lines: int = 0
    truncated: bool = False
    note: str = ""
    synthetic: bool = False


def is_synthetic(p: Path) -> bool:
    return p.name.upper().startswith("SYNTHETIC") or any(x.lower() == "synthetic" for x in p.parts[:-1])


def read_log(path: Path) -> LogFile:
    lf = LogFile(path, synthetic=is_synthetic(path))
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        lf.note = f"cannot read: {e}"
        return lf
    stripped = text.strip()
    if not stripped:
        lf.note = "empty file"
        return lf
    # A single JSON document ({events: [...]}) in case the export format changes; else JSON lines.
    try:
        doc = json.loads(stripped)
    except json.JSONDecodeError:
        doc = None
    if isinstance(doc, dict) and isinstance(doc.get("events"), list):
        lf.events = [e for e in doc["events"] if isinstance(e, dict)]
        lf.synthetic = lf.synthetic or bool(doc.get("synthetic"))
        return lf
    lines = text.split("\n")
    for i, line in enumerate(lines):
        line = line.strip()
        if not line:
            continue
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            if i >= len(lines) - 2:
                lf.truncated = True
            else:
                lf.bad_lines += 1
            continue
        if isinstance(e, dict) and "event" in e:
            lf.events.append(e)
        else:
            lf.bad_lines += 1
    if not lf.events:
        lf.note = "no playtest events (not a Killstreak log?)"
    return lf


def gather_paths(inputs: list[str]) -> list[Path]:
    out: list[Path] = []
    for raw in inputs:
        p = Path(raw)
        if p.is_dir():
            out += sorted(x for x in p.rglob("*") if x.is_file() and x.suffix.lower() in (".json", ".jsonl"))
        elif p.is_file():
            out.append(p)
    seen, uniq = set(), []
    for p in out:
        if p.resolve() not in seen:
            seen.add(p.resolve())
            uniq.append(p)
    return uniq


def _type_name(v: Any) -> str:
    return type(v).__name__


def validate(e: dict, schema: dict[str, list[str]]) -> list[str]:
    problems = []
    for k in COMMON:
        if k not in e:
            problems.append(f"missing {k}")
    if e.get("v") not in (None, SCHEMA_VERSION):
        problems.append(f"schema v{e.get('v')}")
    name = e.get("event")
    if name not in schema:
        return problems + [f"unknown event {name!r}"]
    expected = set(schema[name])
    got = set(e) - set(COMMON)
    if expected - got:
        problems.append(f"{name}: missing {sorted(expected - got)}")
    if got - expected:
        problems.append(f"{name}: extra {sorted(got - expected)}")
    for k in ("seq", "t_ms"):
        if k in e and not isinstance(e[k], (int, float)):
            problems.append(f"{k} is {_type_name(e[k])}")
    return problems


# =============================================================================
# Analysis
# =============================================================================

def _n(v: Any) -> float | None:
    return float(v) if isinstance(v, (int, float)) and not isinstance(v, bool) else None


def _median(xs: list[float]) -> float | None:
    xs = [x for x in xs if x is not None]
    return statistics.median(xs) if xs else None


def bracket_of(m: dict) -> str:
    if m.get("rival"):
        return "rival"
    t = m.get("threat")
    return f"bracket {int(t)}" if isinstance(t, (int, float)) and t else "unknown"


@dataclass
class Session:
    sid: str
    events: list[dict]
    files: set[str] = field(default_factory=set)
    info: dict = field(default_factory=dict)
    k: dict = field(default_factory=dict)
    order: int = 0


def analyse_session(s: Session, tutorial_steps: int) -> None:
    ev = sorted(s.events, key=lambda e: (_n(e.get("seq")) or 0))
    k: dict[str, Any] = {}
    start = next((e for e in ev if e["event"] == "session_start"), {})
    pre = next((e for e in ev if e["event"] == "pre_survey"), None)
    surveys = [e for e in ev if e["event"] == "end_survey"]
    seg = (pre or {}).get("segment") or start.get("segment") or next((x.get("segment") for x in surveys if x.get("segment")), "")
    scr = start.get("screen") if isinstance(start.get("screen"), dict) else {}
    s.info = {
        "date": start.get("date_utc", ""), "device": start.get("device_class", "?"),
        "os": start.get("os_family", "?"), "browser": start.get("browser", "") or "-",
        "embedded": start.get("embedded"), "points": scr.get("points"), "load_ms": _n(start.get("load_ms")),
        "segment": seg or "not answered", "has_start": bool(start),
        "inputs": sorted({e.get("kind") for e in ev if e["event"] == "input_type"} - {None}),
    }
    last = ev[-1] if ev else {}
    k["length_s"] = (_n(last.get("t_ms")) or 0) / 1000.0
    k["ended_with"] = last.get("event", "")
    k["ended_screen"] = last.get("screen") or last.get("name") or ""
    k["exported"] = sum(1 for e in ev if e["event"] == "log_exported")

    # Tutorial
    steps = [(int(_n(e.get("step")) or 0), _n(e.get("t_ms")) or 0) for e in ev if e["event"] == "tutorial_step"]
    k["tutorial_started"] = bool(steps)
    k["tutorial_max_step"] = max((st for st, _ in steps), default=0)
    k["tutorial_completed"] = k["tutorial_max_step"] >= tutorial_steps if steps else None
    stalls = []
    if steps:
        ts = [t for _, t in steps]
        after = next((_n(e.get("t_ms")) for e in ev if e["event"] == "screen" and (_n(e.get("t_ms")) or 0) > ts[-1]), None)
        bounds = ts[1:] + [after if after is not None else ts[-1]]
        for (st, t0), t1 in zip(steps, bounds):
            if (t1 - t0) / 1000.0 > STALL_S:
                stalls.append((st, (t1 - t0) / 1000.0))
        k["tutorial_s"] = ((after or ts[-1]) - ts[0]) / 1000.0
    k["tutorial_stalls"] = stalls

    # Matches, rounds, cards
    matches: list[dict] = []
    cur: dict | None = None
    prev_t = 0.0
    rounds: list[dict] = []
    player_cards = Counter()
    cards_by_round: Counter = Counter()
    pause_in_match = 0
    for e in ev:
        name, t = e["event"], (_n(e.get("t_ms")) or 0) / 1000.0
        if name == "match_start":
            if cur is not None:
                cur["abandoned"] = True
                matches.append(cur)
            cur = {"bracket": bracket_of(e), "mode": e.get("mode"), "match": e.get("match"), "t0": t,
                   "result": None, "abandoned": False, "rounds_logged": 0}
            prev_t = t
        elif name == "round_end" and cur is not None:
            r = {"match_i": len(matches), "round": e.get("round"), "time_s": t - prev_t,
                 "unspent": _n(e.get("supply_unspent")), "hand": _n(e.get("hand_size"))}
            rounds.append(r)
            cur["rounds_logged"] += 1
            prev_t = t
        elif name == "round_stats":
            for r in reversed(rounds):
                if r["round"] == e.get("round") and r["unspent"] is None:
                    r["unspent"] = _n(e.get("supply_unspent"))
                    r["hand"] = _n(e.get("hand_size"))
                    break
        elif name == "card_played" and e.get("side") == "player":
            player_cards[e.get("card_id")] += 1
            if cur is not None:
                cards_by_round[(len(matches), e.get("round"))] += 1
        elif name == "screen" and e.get("name") == "pause" and cur is not None:
            pause_in_match += 1
        elif name == "match_end" and cur is not None:
            cur.update({"result": e.get("result"), "rounds": _n(e.get("rounds")), "duration_s": _n(e.get("duration_s")),
                        "ks_used": _n(e.get("killstreaks_used")) or 0, "ks_earned": _n(e.get("killstreaks_earned")) or 0,
                        "op_downs": _n(e.get("operator_downs")) or 0, "max_streak": _n(e.get("max_streak")) or 0,
                        "cards": _n(e.get("cards_played")) or 0, "t1": t})
            matches.append(cur)
            cur = None
    if cur is not None:
        cur["abandoned"] = True
        matches.append(cur)
    for r in rounds:
        r["cards"] = cards_by_round.get((r["match_i"], r["round"]), 0)
    k["matches"] = matches
    k["rounds"] = rounds
    k["player_cards"] = player_cards
    k["pause_in_match"] = pause_in_match

    # Runs
    k["runs_started"] = sum(1 for e in ev if e["event"] == "run_start")
    k["runs"] = [e for e in ev if e["event"] == "run_end"]

    # Rewards
    picks = [e for e in ev if e["event"] in ("reward_pick", "attachment_pick", "perk_pick")]
    k["picks"] = picks
    k["killstreaks_used_ids"] = Counter(e.get("id") for e in ev if e["event"] == "killstreak_used")
    k["next_match"] = [_n(e.get("seconds_after_end")) for e in ev if e["event"] == "next_match_clicked"]
    k["preview_on"] = sum(1 for e in ev if e["event"] == "preview_toggled" and e.get("on"))
    k["hidden_in_match"] = sum(1 for e in ev if e["event"] == "app_hidden" and e.get("screen") in ("match", "mulligan", "pause"))
    k["surveys"] = surveys
    first_win = next((m for m in matches if m.get("result") == "win"), None)
    k["first_win_t"] = first_win.get("t1") if first_win else None
    s.k = k


@dataclass
class Tester:
    tid: str
    sessions: list[Session]
    files: set[str] = field(default_factory=set)


def group_testers(sessions: dict[str, Session], unit: str) -> list[Tester]:
    if unit == "session":
        return [Tester(f"T{i + 1}", [s], set(s.files)) for i, s in enumerate(sorted(sessions.values(), key=_order))]
    parent = {sid: sid for sid in sessions}

    def find(x: str) -> str:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    by_file: dict[str, list[str]] = defaultdict(list)
    for sid, s in sessions.items():
        for f in s.files:
            by_file[f].append(sid)
    for sids in by_file.values():
        for other in sids[1:]:
            parent[find(other)] = find(sids[0])
    groups: dict[str, list[Session]] = defaultdict(list)
    for sid, s in sessions.items():
        groups[find(sid)].append(s)
    out = []
    for i, g in enumerate(sorted(groups.values(), key=lambda g: min(_order(s) for s in g))):
        g.sort(key=_order)
        out.append(Tester(f"T{i + 1}", g, set().union(*(s.files for s in g))))
    return out


def _order(s: Session) -> int:
    return s.order


def assign_order(files: list[LogFile], sessions: dict[str, Session]) -> None:
    """Chronological session order. A device's log is oldest first and every export repeats the
    earlier sessions, so walk the exports with the most sessions first and number each session
    where it first appears (the session id is random, so it says nothing about order)."""
    def sids(f: LogFile) -> list[str]:
        out: list[str] = []
        for e in f.events:
            sid = str(e.get("sid", "?"))
            if sid not in out:
                out.append(sid)
        return out
    n = 0
    for f in sorted(files, key=lambda f: -len(sids(f))):
        for sid in sids(f):
            if sid in sessions and sessions[sid].order == 0:
                n += 1
                sessions[sid].order = n


# =============================================================================
# KPIs
# =============================================================================

def _share(flags: list[bool]) -> tuple[int, int, float | None]:
    n = len(flags)
    x = sum(1 for f in flags if f)
    return x, n, (x / n if n else None)


def _pct(v: float | None) -> str:
    return "no data" if v is None else f"{v * 100:.0f}%"


def _mmss(s: float | None) -> str:
    if s is None:
        return "no data"
    s = int(round(s))
    return f"{s // 60}:{s % 60:02d}"


def _status(ok: bool | None) -> str:
    return "NO DATA" if ok is None else ("PASS" if ok else "MISS")


def compute(testers: list[Tester]) -> dict[str, Any]:
    sessions = [s for t in testers for s in t.sessions]
    matches = [m for s in sessions for m in s.k["matches"]]
    done = [m for m in matches if m.get("result")]
    rounds = [r for s in sessions for r in s.k["rounds"]]
    out: dict[str, Any] = {"kpis": [], "sessions": sessions, "matches": done}

    def row(kpi: str, target: str, result: str, n: str, status: str, note: str = "") -> None:
        out["kpis"].append({"kpi": kpi, "target": target, "result": result, "n": n, "status": status, "note": note})

    # Tutorial completion (testers who started it)
    flags = [s.k["tutorial_completed"] for s in sessions if s.k["tutorial_started"]]
    x, n, sh = _share(flags)
    row("Tutorial completion", "≥ 90% of tutorials started", f"{_pct(sh)} ({x}/{n})", str(n),
        _status(None if sh is None else sh >= T_TUTORIAL))

    # Time to first win: per tester, play time summed over sessions before the first win.
    ttw, ttw_seg = [], []
    for t in testers:
        acc = 0.0
        for s in t.sessions:
            if s.k["first_win_t"] is not None:
                ttw.append(acc + s.k["first_win_t"])
                ttw_seg.append(t.sessions[0].info["segment"])
                break
            acc += s.k["length_s"]
    shooterish = [v for v, seg in zip(ttw, ttw_seg) if seg in ("shooter", "both")]
    med = _median(shooterish)
    row("Time to first win (Shooter segment)", "≤ 10:00 of play", _mmss(med) + (" median" if len(shooterish) > 1 else ""),
        str(len(shooterish)), _status(None if med is None else med <= T_FIRST_WIN_S),
        "includes tutorial; 'both' counted as Shooter" + ("" if shooterish else f"; all segments: {_mmss(_median(ttw))}"))

    # Session length, matches per run, turn time (brief items, no plan bar)
    lens = [s.k["length_s"] for s in sessions]
    row("Session length", "(no bar)", f"median {_mmss(_median(lens))}, total {_mmss(sum(lens))}", str(len(lens)), "INFO")
    runs = [r for s in sessions for r in s.k["runs"]]
    mpr = [_n(r.get("matches")) for r in runs]
    row("Matches per finished run", "(no bar; a full run is 5)", f"median {_median(mpr) if mpr else 'no data'}"
        + (f" (runs: {', '.join(str(int(v)) for v in mpr if v is not None)})" if mpr else ""), str(len(runs)), "INFO",
        f"runs started {sum(s.k['runs_started'] for s in sessions)}, finished {len(runs)}")
    rt = [r["time_s"] for r in rounds]
    row("Turn (round) time", "(no bar)", f"median {_mmss(_median(rt))}, slowest {_mmss(max(rt) if rt else None)}",
        str(len(rt)), "INFO", "round_end to round_end; round 1 includes the mulligan")

    # Match duration
    md = _median([m["duration_s"] for m in done if m.get("duration_s") is not None])
    row("Median match duration", "3:00–5:00", _mmss(md), str(len(done)),
        _status(None if md is None else T_MATCH_S[0] <= md <= T_MATCH_S[1]))

    # Killstreak used / Operator down
    x, n, sh = _share([m["ks_used"] > 0 for m in done])
    row("Matches with ≥ 1 killstreak used", "≥ 80%", f"{_pct(sh)} ({x}/{n})", str(n), _status(None if sh is None else sh >= T_KS_SHARE))
    x, n, sh = _share([m["op_downs"] > 0 for m in done])
    row("Matches with the Operator down ≥ once", "40–70%", f"{_pct(sh)} ({x}/{n})", str(n),
        _status(None if sh is None else T_OPDOWN[0] <= sh <= T_OPDOWN[1]))

    # Win rate per bracket (draws count as not won)
    for b, target in T_WINRATE.items():
        ms = [m for m in done if m["bracket"] == b]
        w = sum(1 for m in ms if m["result"] == "win")
        l = sum(1 for m in ms if m["result"] == "loss")
        d = len(ms) - w - l
        wr = w / len(ms) if ms else None
        st = "NO DATA" if wr is None else ("ON TARGET" if abs(wr - target) <= T_WINRATE_TOL else ("TOO EASY" if wr > target else "TOO HARD"))
        row(f"Win rate vs AI, {b}", f"~{target * 100:.0f}% (±{T_WINRATE_TOL * 100:.0f})", f"{_pct(wr)} ({w}W {l}L {d}D)", str(len(ms)), st)

    # One more match
    nm = [v for s in sessions for v in s.k["next_match"] if v is not None]
    x, n, sh = _share([v <= 60.0 for v in nm])
    row("One more match (next within 60 s)", "≥ 60%", f"{_pct(sh)} ({x}/{n})", str(n), _status(None if sh is None else sh >= T_NEXT_60),
        "clock starts at match_end, so it includes the After-Action and reward screens")

    # Supply Drop pick-rate spread
    offered, chosen = Counter(), Counter()
    skips = 0
    for s in sessions:
        for p in s.k["picks"]:
            if p.get("kind") != "supply_drop":
                continue
            for c in p.get("offered") or []:
                offered[c] += 1
            if p.get("skipped"):
                skips += 1
            elif p.get("chosen"):
                chosen[p["chosen"]] += 1
    judged = {c: chosen[c] / offered[c] for c in offered if offered[c] >= T_PICK_MIN_OFFERS}
    bad = {c: r for c, r in judged.items() if r > T_PICK[1] or r < T_PICK[0]}
    out["pick_table"] = sorted(((c, offered[c], chosen[c]) for c in offered), key=lambda x: (-x[1], x[0]))
    res = "no data" if not judged else (f"{len(bad)} of {len(judged)} cards outside: " + ", ".join(f"{c} {_pct(r)}" for c, r in sorted(bad.items())) if bad else f"all {len(judged)} judged cards inside 5–60%")
    row("Supply Drop pick-rate spread", "no card > 60% or < 5%", res, f"{sum(offered.values())} offers", _status(None if not judged else not bad),
        f"only cards offered ≥ {T_PICK_MIN_OFFERS} times are judged; {skips} offers skipped")

    # Unspent supply
    us = [r["unspent"] for r in rounds if r["unspent"] is not None]
    mu = _median(us)
    row("Median unspent Supply per round", "≤ 1", "no data" if mu is None else f"{mu:g}", str(len(us)), _status(None if mu is None else mu <= T_UNSPENT))

    # Survey
    surveys = [(s.info["segment"], e) for s in sessions for e in s.k["surveys"]]
    out["surveys"] = surveys

    def avg(keys: str, segs: tuple[str, ...] | None) -> tuple[float | None, int]:
        vals = [_n(e.get(keys)) for seg, e in surveys if segs is None or seg in segs]
        vals = [v for v in vals if v is not None]
        return (sum(vals) / len(vals) if vals else None), len(vals)
    for q, segs, label in (("q1", ("shooter", "both"), "Shooter"), ("q2", ("shooter", "both"), "Shooter"),
                           ("q3", ("card", "both"), "Card"), ("q5", None, "all")):
        a, n = avg(q, segs)
        row(f"Survey {q.upper()} ({label} segment)", "average ≥ 4", "no data" if a is None else f"{a:.1f}", str(n),
            _status(None if a is None else a >= T_SURVEY), SURVEY_TEXT[q])
    a, n = avg("q4", None)
    row("Survey Q4 (all)", "(no bar)", "no data" if a is None else f"{a:.1f}", str(n), "INFO", SURVEY_TEXT["q4"])

    # Confusion signals
    conf = []
    for t in testers:
        for s in t.sessions:
            sk, tag = s.k, f"{t.tid}/{s.sid[:6]}"
            for st, secs in sk["tutorial_stalls"]:
                conf.append((tag, "tutorial stall", f"step {st}: {secs:.0f} s"))
            if sk["tutorial_started"] and not sk["tutorial_completed"]:
                conf.append((tag, "tutorial not finished", f"stopped at step {sk['tutorial_max_step']}"))
            empty = [r for r in sk["rounds"] if r["cards"] == 0]
            if empty:
                conf.append((tag, "rounds with no card played", f"{len(empty)} of {len(sk['rounds'])}"))
            hi = [r for r in sk["rounds"] if (r["unspent"] or 0) >= HIGH_UNSPENT]
            if hi:
                conf.append((tag, f"rounds ending with ≥ {HIGH_UNSPENT} Supply unspent", f"{len(hi)} of {len(sk['rounds'])}"))
            slow = [r for r in sk["rounds"] if r["time_s"] > LONG_ROUND_S]
            if slow:
                conf.append((tag, f"rounds over {int(LONG_ROUND_S)} s", f"{len(slow)} (slowest {_mmss(max(r['time_s'] for r in slow))})"))
            if sk["preview_on"]:
                conf.append((tag, "outcome preview turned on", f"{sk['preview_on']}×"))
            if sk["pause_in_match"]:
                conf.append((tag, "pause menu opened in a match", f"{sk['pause_in_match']}×"))
            ab = [m for m in sk["matches"] if m.get("abandoned")]
            if ab:
                conf.append((tag, "match left unfinished", f"{len(ab)}"))
            if sk["hidden_in_match"]:
                conf.append((tag, "app hidden during a match", f"{sk['hidden_in_match']}×"))
            if sk["runs_started"] > len(sk["runs"]):
                conf.append((tag, "run started but not finished", f"{sk['runs_started'] - len(sk['runs'])}"))
            for e in sk["surveys"]:
                sk_q = [q for q in SURVEY_KEYS if e.get(q) is None]
                if sk_q:
                    conf.append((tag, "survey statements skipped", ", ".join(sk_q)))
    out["confusion"] = conf
    return out


# =============================================================================
# Output
# =============================================================================

def _md(text: Any) -> str:
    return str(text).replace("|", "\\|").replace("\n", " ")


def build_markdown(title: str, files: list[LogFile], skipped: list[tuple[LogFile, str]], schema_src: str,
                   problems: Counter, dupes: int, conflicts: int, testers: list[Tester], res: dict, synthetic: bool) -> str:
    L: list[str] = [f"# {title}", ""]
    if synthetic:
        L += ["> **SYNTHETIC TEST DATA.** Made by tools/synthetic_playtest_sessions.gd to test this tool. Not player data; never quote these numbers.", ""]
    sessions = res["sessions"]
    L += [f"**Logs read:** {len(files)} file(s), {len(sessions)} session(s), {len(testers)} tester(s)/device(s) · "
          f"**Schema:** {schema_src} · **Duplicate lines dropped:** {dupes}" + (f" · **Conflicting duplicates:** {conflicts}" if conflicts else ""),
          "", "> Expect 1–5 testers internally: every number is directional. One match moves a win rate by 10–30 points.", ""]
    L += ["## KPI sheet", "", "| KPI | Target | Result | n | Status | Note |", "|---|---|---|---|---|---|"]
    for k in res["kpis"]:
        L.append(f"| {_md(k['kpi'])} | {_md(k['target'])} | {_md(k['result'])} | {k['n']} | **{k['status']}** | {_md(k['note'])} |")
    L += ["", "## Sessions", "", "| Tester | Session | Date | Device | Load | Segment | Length | Tutorial | Matches (W-L-D) | Runs | Survey | Exported | Ended with |",
          "|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for t in testers:
        for s in t.sessions:
            i, k = s.info, s.k
            ms = [m for m in k["matches"] if m.get("result")]
            wld = "-".join(str(sum(1 for m in ms if m["result"] == r)) for r in ("win", "loss", "draw"))
            tut = "—" if not k["tutorial_started"] else ("done" if k["tutorial_completed"] else f"stopped at {k['tutorial_max_step']}")
            dev = f"{i['device']} / {i['os']} / {i['browser']}" + (" (embedded)" if i.get("embedded") else "")
            load = "?" if i["load_ms"] is None else f"{i['load_ms'] / 1000:.1f} s"
            sv = "; ".join("/".join("–" if e.get(q) is None else str(int(e[q])) for q in SURVEY_KEYS) for e in k["surveys"]) or "—"
            runs = ", ".join(f"{r.get('result')} ({int(_n(r.get('matches')) or 0)})" for r in k["runs"]) or ("unfinished" if k["runs_started"] else "—")
            L.append(f"| {t.tid} | `{s.sid}` | {i['date']} | {_md(dev)} | {load} | {i['segment']} | {_mmss(k['length_s'])} | {tut} | "
                     f"{len(ms)} ({wld}) | {_md(runs)} | {sv} | {'yes' if k['exported'] else 'no'} | {k['ended_with']} {k['ended_screen']} |")
    L += ["", "## Matches", "", "| Session | # | Bracket | Mode | Result | Rounds | Duration | Killstreaks used | Operator downs | Best streak |", "|---|---|---|---|---|---|---|---|---|---|"]
    for s in sessions:
        for m in s.k["matches"]:
            num = "" if m.get("match") is None else int(m["match"]) + 1
            if m.get("result"):
                L.append(f"| `{s.sid[:6]}` | {num} | {m['bracket']} | {m.get('mode')} | {m['result']} | {int(m.get('rounds') or 0)} | {_mmss(m.get('duration_s'))} | "
                         f"{int(m['ks_used'])} | {int(m['op_downs'])} | {int(m['max_streak'])} |")
            else:
                L.append(f"| `{s.sid[:6]}` | {num} | {m['bracket']} | {m.get('mode')} | *unfinished* | {m['rounds_logged']} logged | | | | |")
    L += ["", "## Card usage", "", "**Cards the player deployed** (all sessions):", ""]
    pc = Counter()
    for s in sessions:
        pc.update(s.k["player_cards"])
    total = sum(pc.values())
    if pc:
        L += ["| Card | Plays | Share |", "|---|---|---|"] + [f"| {c} | {n} | {n / total * 100:.0f}% |" for c, n in pc.most_common()]
    else:
        L.append("No cards played.")
    L += ["", "**Supply Drop offers** (pick rate = chosen / offered):", ""]
    if res["pick_table"]:
        L += ["| Card | Offered | Chosen | Pick rate |", "|---|---|---|---|"] + [f"| {c} | {o} | {ch} | {ch / o * 100:.0f}% |" for c, o, ch in res["pick_table"]]
    else:
        L.append("No Supply Drop offers.")
    other = Counter((p.get("kind"), p.get("chosen") or "(skipped)") for s in sessions for p in s.k["picks"] if p.get("kind") != "supply_drop")
    if other:
        L += ["", "**Attachment / perk picks:** " + ", ".join(f"{k} {c} ×{n}" for (k, c), n in sorted(other.items()))]
    ks = Counter()
    for s in sessions:
        ks.update(s.k["killstreaks_used_ids"])
    L += ["", "**Killstreaks used:** " + (", ".join(f"{k} ×{n}" for k, n in ks.most_common()) or "none")]
    L += ["", "## Confusion signals", "", f"Thresholds: tutorial step open > {int(STALL_S)} s, round > {int(LONG_ROUND_S)} s, ≥ {HIGH_UNSPENT} Supply unspent. "
          "Signals point at moments to ask the tester about; they are not failures on their own.", ""]
    if res["confusion"]:
        L += ["| Where | Signal | Detail |", "|---|---|---|"] + [f"| {a} | {b} | {_md(c)} |" for a, b, c in res["confusion"]]
    else:
        L.append("None found.")
    L += ["", "## Survey answers", ""]
    if res["surveys"]:
        L += ["| Segment | Q1 | Q2 | Q3 | Q4 | Q5 | Open answer |", "|---|---|---|---|---|---|---|"]
        for seg, e in res["surveys"]:
            L.append(f"| {seg} | " + " | ".join("–" if e.get(q) is None else str(int(e[q])) for q in SURVEY_KEYS) + f" | {_md(e.get('open') or '')} |")
        L += ["", "Statements: " + " ".join(f"**{q.upper()}** {t}" for q, t in SURVEY_TEXT.items())]
    else:
        L.append("No end survey in these logs.")
    L += ["", "## Data quality", ""]
    for f in files:
        bits = [f"{len(f.events)} lines"]
        if f.bad_lines:
            bits.append(f"{f.bad_lines} unreadable lines")
        if f.truncated:
            bits.append("last line cut off")
        L.append(f"- `{_rel(f.path)}`: " + ", ".join(bits))
    for f, why in skipped:
        L.append(f"- skipped `{_rel(f.path)}`: {why}")
    if problems:
        L += ["", "Schema problems (count):"] + [f"- {p}: {n}" for p, n in problems.most_common(20)]
    else:
        L += ["", "Every line matches the logger schema."]
    no_start = [s.sid for s in sessions if not s.info["has_start"]]
    if no_start:
        L.append(f"- sessions without session_start (log rotated or cut): {', '.join(no_start)}")
    L.append("")
    return "\n".join(L)


def write_csv(path: Path, res: dict) -> None:
    with path.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["section", "kpi", "target", "result", "n", "status", "note"])
        for k in res["kpis"]:
            w.writerow(["kpi", k["kpi"], k["target"], k["result"], k["n"], k["status"], k["note"]])
        w.writerow([])
        w.writerow(["section", "session", "match", "bracket", "mode", "result", "rounds", "duration_s", "killstreaks_used", "operator_downs"])
        for s in res["sessions"]:
            for m in s.k["matches"]:
                w.writerow(["match", s.sid, m.get("match"), m["bracket"], m.get("mode"), m.get("result") or "unfinished",
                            m.get("rounds"), m.get("duration_s"), m.get("ks_used"), m.get("op_downs")])


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Killstreak playtest KPI sheet from exported logs.")
    ap.add_argument("inputs", nargs="*", help="exported .jsonl / .json logs, or folders (default qa/playtesting/logs/)")
    ap.add_argument("--out", help="output path without extension")
    ap.add_argument("--unit", choices=("tester", "session"), default="tester")
    ap.add_argument("--include-synthetic", action="store_true")
    ap.add_argument("--schema", type=Path)
    ap.add_argument("--title", default="Killstreak internal playtest: KPI sheet")
    args = ap.parse_args(argv)
    paths = gather_paths(args.inputs or [str(DEFAULT_IN)])
    if not paths:
        print("no .json / .jsonl files found in: " + ", ".join(args.inputs or [str(DEFAULT_IN)]), file=sys.stderr)
        return 2
    schema, schema_src = load_schema(args.schema)
    steps = tutorial_step_count()
    files, skipped = [], []
    for p in paths:
        lf = read_log(p)
        if lf.synthetic and not args.include_synthetic:
            skipped.append((lf, "synthetic (pass --include-synthetic)"))
        elif not lf.events:
            skipped.append((lf, lf.note))
        else:
            files.append(lf)
    synthetic = any(f.synthetic for f in files)
    seen: dict[tuple, str] = {}
    by_sid: dict[str, Session] = {}
    problems: Counter = Counter()
    dupes = conflicts = 0
    for f in files:
        for e in f.events:
            for pr in validate(e, schema):
                problems[pr] += 1
            sid = str(e.get("sid", "?"))
            key = (sid, e.get("seq"))
            blob = json.dumps(e, sort_keys=True)
            s = by_sid.setdefault(sid, Session(sid, []))
            s.files.add(str(f.path))
            if key in seen:
                dupes += 1
                if seen[key] != blob:
                    conflicts += 1
                continue
            seen[key] = blob
            s.events.append(e)
    if not by_sid:
        print("no session could be counted; nothing written", file=sys.stderr)
        for f, why in skipped:
            print(f"  skipped {f.path}: {why}", file=sys.stderr)
        return 1
    assign_order(files, by_sid)
    for s in by_sid.values():
        analyse_session(s, steps)
    testers = group_testers(by_sid, args.unit)
    res = compute(testers)
    out = Path(args.out) if args.out else (DEFAULT_OUT.with_name(DEFAULT_OUT.name + "-SYNTHETIC") if synthetic else DEFAULT_OUT)
    out.parent.mkdir(parents=True, exist_ok=True)
    title = args.title + (" (SYNTHETIC)" if synthetic and "SYNTHETIC" not in args.title else "")
    md = build_markdown(title, files, skipped, schema_src, problems, dupes, conflicts, testers, res, synthetic)
    out.with_suffix(".md").write_text(md, encoding="utf-8")
    write_csv(out.with_suffix(".csv"), res)
    print(f"wrote {out.with_suffix('.md')} and .csv: {len(files)} file(s), {len(by_sid)} session(s), "
          f"{len(testers)} tester(s), {dupes} duplicate line(s) dropped, {sum(problems.values())} schema problem(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

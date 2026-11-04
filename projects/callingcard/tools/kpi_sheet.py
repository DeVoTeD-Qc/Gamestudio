#!/usr/bin/env python3
"""CallingCard playtest KPI sheet (cc18).

Reads exported playtest logs ("Download log" files, callingcard-playtest-*.json), checks every line
against the logger's schema and computes the KPIs of playtest-log-schema.md section 5 per session,
per tester and across testers, with pass / fail against the bars of vision.md section 8 and
prototype-milestone-plan.md section 8. Writes a markdown KPI sheet and a CSV.

Usage:
    python3 tools/kpi_sheet.py playtest-logs/                     # every *.json / *.jsonl in it
    python3 tools/kpi_sheet.py a.json b.json --out playtest-logs/kpi/kpi-sheet
    python3 tools/kpi_sheet.py playtest-logs/synthetic --include-synthetic   # tool test only

Options:
    --out PATH            output path without extension (default: playtest-logs/kpi/kpi-sheet,
                          or .../kpi-sheet-SYNTHETIC when synthetic files are included)
    --unit tester|session tester (default): sessions found in the same file, or in files that
                          share a session id, are one tester. session: every session is a tester.
    --include-synthetic   also read files marked "synthetic": true (left out by default, so test
                          data never counts in a real report)
    --schema PATH         playtest_log.gd to read SCHEMA / ENUMS from (default: the game's copy;
                          falls back to the copy built into this file)
    --title TEXT          heading for the sheet

Standard library only. Handles empty, partial (cut-off) and consent-off logs: such files are
listed with what was missing, and every KPI says "no data" rather than guessing.
Exit code: 0 when a sheet was written, 1 when no log could be counted (nothing written),
2 on bad arguments or no input files.
"""

from __future__ import annotations

import argparse
import ast
import csv
import datetime as _dt
import json
import os
import re
import statistics
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

TOOL_DIR = Path(__file__).resolve().parent
PROJECT_DIR = TOOL_DIR.parent
DEFAULT_SCHEMA_GD = PROJECT_DIR / "source" / "project-callingcard" / "autoload" / "playtest_log.gd"
DEFAULT_OUT = PROJECT_DIR / "playtest-logs" / "kpi" / "kpi-sheet"
EXPORT_FORMAT = "callingcard-playtest-log"
SCHEMA_VERSION = 1

# Tutorial Dossier D1. The schema doc's recipe says id = d1; the game's real id is
# dossier_first_contact (data/dossiers/dossier_first_contact.tres, number = 1). Accept both.
D1_IDS = {"dossier_first_contact", "d1"}

# Pass bars (vision.md section 8, prototype-milestone-plan.md section 8).
BAR_AGREE_SHARE = 0.70      # intent to collect, fairness: share answering 4 or 5
BAR_ALBUM_SHARE = 0.50      # album pull
BAR_DUEL_MEDIAN_S = 240.0   # median duel < 4 min
BAR_D1_S = 180.0            # D1 cleared < 3 min
BAR_LOAD_MS = 10000         # load < 10 s in every session

# Fallback copy of playtest_log.gd (schema version 1), used when the .gd cannot be read.
FALLBACK_SCHEMA: dict[str, dict[str, str]] = {
    "session_start": {"schema": "i", "consent_version": "i", "load_ms": "i", "input_type": "s",
                      "viewport": "a", "window_px": "a", "pixel_ratio": "n", "browser": "s",
                      "os_family": "s", "web": "b", "mobile": "b", "touchscreen": "b",
                      "device_class": "s", "engine": "s", "build": "s", "date_utc": "s"},
    "consent": {"given": "b"},
    "input_type": {"kind": "s"},
    "screen": {"name": "s"},
    "entry_point": {"entry": "s", "screen": "s"},
    "album_open": {"page": "s", "count": "i"},
    "card_inspect": {"card_id": "s", "owned": "b", "screen": "s"},
    "lineup_saved": {"card_ids": "a", "clearance": "i", "signature_id": "s", "loaner": "b"},
    "duel_start": {"source": "s", "rival": "s", "first_player": "s", "duel": "i", "play_again": "b"},
    "duel_lineup": {"card_ids": "a", "signature_id": "s", "loaner": "b", "duel": "i"},
    "placement": {"side": "s", "card_id": "s", "slot": "s", "captures": "a", "preview_shown": "b",
                  "turn": "i", "duel": "i"},
    "set_link": {"side": "s", "slot": "s", "linked": "a", "duel": "i"},
    "capture": {"by": "s", "card_id": "s", "slot": "s", "duel": "i"},
    "reclaim": {"by": "s", "card_id": "s", "slot": "s", "duel": "i"},
    "ambush": {"side": "s", "card_id": "s", "slot": "s", "duel": "i"},
    "carded": {"by": "s", "card_id": "s", "duel": "i"},
    "triptych_scored": {"side": "s", "id": "s", "first_time": "b", "duel": "i"},
    "triptych_reveal": {"id": "s"},
    "duel_end": {"result": "s", "score_p": "i", "score_ai": "i", "turns": "i", "duration_s": "n",
                 "source": "s", "rival": "s", "duel": "i", "resumed": "b", "play_again": "b",
                 "captures_p": "i", "captures_ai": "i", "carded_p": "i", "carded_ai": "i",
                 "triptychs_p": "i"},
    "lobby_wait_start": {"wait_s": "n"},
    "lobby_match_found": {"choice": "s", "duel_state": "d"},
    "lobby_save": {"saved": "b"},
    "duel_resumed": {"age_s": "n", "duel": "i", "rival": "s"},
    "unlock": {"kind": "s", "id": "s", "source": "s"},
    "goal_progress": {"goal_id": "s", "current": "i", "target": "i"},
    "goal_complete": {"goal_id": "s"},
    "set_complete": {"set_id": "s"},
    "cipher_attempt": {"correct": "b", "attempt": "i"},
    "cipher_solved": {"attempts": "i"},
    "dossier_start": {"id": "s"},
    "dossier_clear": {"id": "s", "attempts": "i", "duration_s": "n", "since_start_s": "n", "via": "s"},
    "collection_reset": {},
    "survey": {"q1": "i?", "q2": "i?", "q3": "i?", "q4": "i?", "open": "s", "answered": "i"},
    "log_exported": {"method": "s", "bytes": "i"},
    "app_hidden": {"screen": "s", "session_s": "n"},
    "app_visible": {"screen": "s", "session_s": "n"},
    "quit": {"screen": "s", "session_s": "n", "reason": "s"},
}
FALLBACK_COMMON = {"v": "i", "sid": "s", "seq": "i", "t_ms": "i", "event": "s"}
FALLBACK_ENUMS: dict[str, list[str]] = {
    "session_start.input_type": ["touch", "mouse"],
    "session_start.device_class": ["phone", "tablet", "desktop"],
    "input_type.kind": ["touch", "mouse", "keyboard", "gamepad"],
    "entry_point.entry": ["menu", "lobby"],
    "duel_start.source": ["rival", "lobby", "dossier"],
    "duel_start.first_player": ["player", "rival"],
    "placement.side": ["player", "rival"],
    "set_link.side": ["player", "rival"],
    "capture.by": ["player", "rival"],
    "reclaim.by": ["player", "rival"],
    "ambush.side": ["player", "rival"],
    "carded.by": ["player", "rival"],
    "triptych_scored.side": ["player", "rival"],
    "duel_end.result": ["win", "loss", "draw"],
    "duel_end.source": ["rival", "lobby", "dossier"],
    "lobby_match_found.choice": ["keep", "save"],
    "unlock.kind": ["card", "title", "frame"],
    "dossier_clear.via": ["duel_end", "dossier_cleared", "dossier_completed"],
    "log_exported.method": ["download", "file"],
    "quit.reason": ["close", "pagehide"],
}
FALLBACK_DUEL_STATE = {"in_duel": "b", "placements": "i", "score_p": "i", "score_ai": "i", "source": "s"}


# =============================================================================
# Schema
# =============================================================================

@dataclass
class Schema:
    events: dict[str, dict[str, str]]
    common: dict[str, str]
    enums: dict[str, list[str]]
    duel_state: dict[str, str]
    source: str


def _gd_const(text: str, name: str) -> Any:
    """Evaluates `const NAME: Dictionary = {...}` from GDScript (string / list / dict literals)."""
    m = re.search(r"^const\s+%s\s*:\s*Dictionary\s*=\s*\{" % re.escape(name), text, re.M)
    if not m:
        raise ValueError(f"{name} not found")
    start = m.end() - 1
    depth = 0
    in_str = False
    i = start
    while i < len(text):
        c = text[i]
        if in_str:
            if c == "\\":
                i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c in "{[":
            depth += 1
        elif c in "}]":
            depth -= 1
            if depth == 0:
                literal = text[start:i + 1]
                literal = re.sub(r"#[^\n\"]*\n", "\n", literal)
                return ast.literal_eval(literal)
        i += 1
    raise ValueError(f"{name} not closed")


def _rel(p: Path) -> str:
    try:
        return str(p.resolve().relative_to(PROJECT_DIR))
    except ValueError:
        return str(p)


def load_schema(path: Path | None) -> tuple[Schema, list[str]]:
    notes: list[str] = []
    gd = path or DEFAULT_SCHEMA_GD
    try:
        text = gd.read_text(encoding="utf-8")
        schema = Schema(_gd_const(text, "SCHEMA"), _gd_const(text, "COMMON_FIELDS"),
                        _gd_const(text, "ENUMS"), _gd_const(text, "DUEL_STATE_FIELDS"), _rel(gd))
        if schema.events != FALLBACK_SCHEMA or schema.enums != FALLBACK_ENUMS:
            notes.append("The game's schema differs from the copy in kpi_sheet.py; the game's is used. "
                         "Update FALLBACK_SCHEMA / FALLBACK_ENUMS.")
        return schema, notes
    except (OSError, ValueError, SyntaxError) as exc:
        notes.append(f"Could not read the schema from {gd} ({exc}); used the built-in copy (schema v1).")
        return Schema(FALLBACK_SCHEMA, FALLBACK_COMMON, FALLBACK_ENUMS, FALLBACK_DUEL_STATE,
                      "built-in copy"), notes


def _type_ok(value: Any, code: str) -> bool:
    if code.endswith("?"):
        if value is None:
            return True
        code = code[:-1]
    if code == "s":
        return isinstance(value, str)
    if code == "i":
        if isinstance(value, bool):
            return False
        return isinstance(value, int) or (isinstance(value, float) and value.is_integer())
    if code == "n":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if code == "b":
        return isinstance(value, bool)
    if code == "a":
        return isinstance(value, list)
    if code == "d":
        return isinstance(value, dict)
    return False


def validate_entry(entry: Any, schema: Schema) -> list[str]:
    """Same checks as PlaytestLog.validate_entry() in the game."""
    if not isinstance(entry, dict):
        return ["line is not a JSON object"]
    name = str(entry.get("event", ""))
    if name not in schema.events:
        return [f"unknown event '{name}'"]
    errors: list[str] = []
    fields = dict(schema.events[name])
    fields.update(schema.common)
    for key in entry:
        if key not in fields:
            errors.append(f"{name}: unexpected field '{key}'")
    for key, code in fields.items():
        if key not in entry:
            errors.append(f"{name}: missing field '{key}'")
        elif not _type_ok(entry[key], code):
            errors.append(f"{name}.{key}: {entry[key]!r} is not of type {code}")
        else:
            allowed = schema.enums.get(f"{name}.{key}")
            if allowed is not None and str(entry[key]) not in allowed:
                errors.append(f"{name}.{key}: '{entry[key]}' not in {allowed}")
    if name == "lobby_match_found" and isinstance(entry.get("duel_state"), dict):
        ds = entry["duel_state"]
        for key, code in schema.duel_state.items():
            if key not in ds or not _type_ok(ds[key], code):
                errors.append(f"lobby_match_found.duel_state.{key} missing or wrong type")
    if name == "survey":
        for q in ("q1", "q2", "q3", "q4"):
            v = entry.get(q)
            if isinstance(v, (int, float)) and not isinstance(v, bool) and not 1 <= v <= 5:
                errors.append(f"survey.{q}: {v} outside 1-5")
    return errors


# =============================================================================
# Reading files
# =============================================================================

@dataclass
class LogFile:
    path: Path
    synthetic: bool = False
    kind: str = ""                 # export | jsonl | salvaged | unreadable
    events: list[dict] = field(default_factory=list)
    problems: list[str] = field(default_factory=list)
    rejected: int = 0
    exported_utc: str = ""
    note: str = ""


def _salvage_events(text: str) -> list[dict]:
    """Pulls every complete event object out of a cut-off export."""
    m = re.search(r'"events"\s*:\s*\[', text)
    if not m:
        return []
    dec = json.JSONDecoder()
    i = m.end()
    out: list[dict] = []
    while i < len(text):
        while i < len(text) and text[i] in " \t\r\n,":
            i += 1
        if i >= len(text) or text[i] == "]":
            break
        try:
            obj, i = dec.raw_decode(text, i)
        except json.JSONDecodeError:
            break
        if isinstance(obj, dict):
            out.append(obj)
    return out


def read_log(path: Path) -> LogFile:
    lf = LogFile(path)
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        lf.kind = "unreadable"
        lf.problems.append(f"cannot read: {exc}")
        return lf
    if not text.strip():
        lf.kind = "unreadable"
        lf.problems.append("empty file")
        return lf
    try:
        doc = json.loads(text)
    except json.JSONDecodeError:
        doc = None
    if isinstance(doc, dict):
        lf.kind = "export"
        lf.synthetic = bool(doc.get("synthetic", False)) or path.name.upper().startswith("SYNTHETIC")
        lf.note = str(doc.get("synthetic_note", ""))
        lf.exported_utc = str(doc.get("exported_utc", ""))
        if doc.get("format") != EXPORT_FORMAT:
            lf.problems.append(f"format is {doc.get('format')!r}, expected {EXPORT_FORMAT!r}")
        if doc.get("schema_version") not in (SCHEMA_VERSION, float(SCHEMA_VERSION)):
            lf.problems.append(f"schema_version {doc.get('schema_version')!r} (tool expects {SCHEMA_VERSION})")
        events = doc.get("events")
        if not isinstance(events, list):
            lf.problems.append("no 'events' list")
            events = []
        count = doc.get("event_count")
        if isinstance(count, (int, float)) and int(count) != len(events):
            lf.problems.append(f"event_count says {int(count)}, file holds {len(events)}")
        lf.events = [e for e in events if isinstance(e, dict)]
        return lf
    # Raw user://playtest_log.jsonl (desktop) or a cut-off export.
    lines = [ln for ln in text.splitlines() if ln.strip()]
    parsed: list[dict] = []
    bad = 0
    for ln in lines:
        try:
            obj = json.loads(ln)
            if isinstance(obj, dict) and "event" in obj:
                parsed.append(obj)
            else:
                bad += 1
        except json.JSONDecodeError:
            bad += 1
    lf.synthetic = path.name.upper().startswith("SYNTHETIC")
    if parsed and bad <= max(1, len(lines) // 10):
        lf.kind = "jsonl"
        lf.events = parsed
        if bad:
            lf.problems.append(f"{bad} unreadable line(s) skipped (cut-off write?)")
        return lf
    salvaged = _salvage_events(text)
    if salvaged:
        lf.kind = "salvaged"
        lf.events = salvaged
        lf.synthetic = lf.synthetic or '"synthetic":true' in text.replace(" ", "")
        lf.problems.append(f"export is cut off or damaged; recovered {len(salvaged)} complete event(s)")
        return lf
    lf.kind = "unreadable"
    lf.problems.append("not a CallingCard export, JSON lines or a recoverable export")
    return lf


def gather_paths(inputs: list[str]) -> list[Path]:
    paths: list[Path] = []
    for raw in inputs:
        p = Path(raw)
        if p.is_dir():
            for child in sorted(p.rglob("*")):
                if child.is_file() and child.suffix.lower() in (".json", ".jsonl") and "kpi" not in child.parts:
                    paths.append(child)
        elif p.exists():
            paths.append(p)
        else:
            print(f"warning: {raw} not found", file=sys.stderr)
    seen: set[Path] = set()
    out = []
    for p in paths:
        r = p.resolve()
        if r not in seen:
            seen.add(r)
            out.append(p)
    return out


# =============================================================================
# Per-session metrics
# =============================================================================

def _num(v: Any) -> float | None:
    if isinstance(v, bool) or v is None:
        return None
    if isinstance(v, (int, float)):
        return float(v)
    return None


def _q(v: Any) -> int | None:
    n = _num(v)
    return int(n) if n is not None and 1 <= n <= 5 else None


def _median(values: list[float]) -> float | None:
    return statistics.median(values) if values else None


@dataclass
class Session:
    sid: str
    files: list[str] = field(default_factory=list)
    events: list[dict] = field(default_factory=list)
    m: dict[str, Any] = field(default_factory=dict)


def analyse_session(s: Session) -> None:
    ev = sorted(s.events, key=lambda e: (_num(e.get("seq")) or 0))
    by: dict[str, list[dict]] = {}
    for e in ev:
        by.setdefault(str(e.get("event")), []).append(e)
    m: dict[str, Any] = {}
    seqs = [int(_num(e.get("seq")) or 0) for e in ev]
    m["events"] = len(ev)
    m["seq_gaps"] = (max(seqs) + 1 - len(set(seqs))) if seqs else 0
    m["starts_at_seq0"] = bool(seqs) and min(seqs) == 0
    start = (by.get("session_start") or [None])[0]
    m["has_session_start"] = start is not None
    m["device"] = str(start.get("device_class", "")) if start else ""
    m["browser"] = str(start.get("browser", "")) if start else ""
    m["os"] = str(start.get("os_family", "")) if start else ""
    m["date"] = str(start.get("date_utc", "")) if start else ""
    m["build"] = str(start.get("build", "")) if start else ""
    m["load_ms"] = _num(start.get("load_ms")) if start else None
    entry = (by.get("entry_point") or [None])[0]
    m["entry"] = str(entry.get("entry")) if entry else ""
    # Length and how it ended.
    t_last = max((_num(e.get("t_ms")) or 0 for e in ev), default=0)
    quit_ev = (by.get("quit") or [None])[-1]
    m["length_s"] = _num(quit_ev.get("session_s")) if quit_ev else (t_last / 1000.0 if ev else None)
    last = ev[-1] if ev else {}
    if quit_ev:
        m["ended"] = f"quit ({quit_ev.get('reason')}) on {quit_ev.get('screen')}"
    elif last.get("event") == "app_hidden":
        m["ended"] = f"tab/app hidden on {last.get('screen')} (no quit line)"
    else:
        m["ended"] = f"log stops at {last.get('event', '-')} (no quit line)"
    # Survey (the last one counts).
    survey = (by.get("survey") or [None])[-1]
    m["survey_taken"] = survey is not None
    m["survey_answered"] = int(_num(survey.get("answered")) or 0) if survey else 0
    for q in ("q1", "q2", "q3", "q4"):
        m[q] = _q(survey.get(q)) if survey else None
    m["open"] = str(survey.get("open", "")) if survey else ""
    m["intent"] = None if m["q1"] is None else m["q1"] >= 4
    m["fair"] = None if m["q4"] is None else m["q4"] >= 4
    # Album pull.
    opens = [int(_num(e.get("count")) or 0) for e in by.get("album_open", [])]
    m["album_opens"] = max(opens) if opens else 0
    m["locked_inspects"] = sum(1 for e in by.get("card_inspect", []) if e.get("owned") is False)
    m["album_pull"] = m["album_opens"] >= 2 and m["locked_inspects"] > 0
    # Duels.
    ends = by.get("duel_end", [])
    fit = [float(_num(e.get("duration_s")) or 0) for e in ends
           if e.get("source") != "dossier" and e.get("resumed") is not True and _num(e.get("duration_s")) is not None]
    m["duel_durations"] = fit
    m["duel_median_s"] = _median(fit)
    m["duels_by_source"] = {src: sum(1 for e in ends if e.get("source") == src) for src in ("rival", "lobby", "dossier")}
    m["resumed_duels"] = sum(1 for e in ends if e.get("resumed") is True)
    results: dict[str, dict[str, int]] = {}
    for e in ends:
        if e.get("source") == "dossier":
            continue
        r = results.setdefault(str(e.get("rival") or "?"), {"win": 0, "loss": 0, "draw": 0})
        res = str(e.get("result"))
        if res in r:
            r[res] += 1
    m["results_by_rival"] = results
    started = [e for e in by.get("duel_start", [])]
    m["duels_started"] = len(started) + len(by.get("duel_resumed", []))
    # A Lobby Duel saved on "match found" ends in its resumed part, so a resume closes one start.
    saves = sum(1 for e in by.get("lobby_save", []) if e.get("saved") is True)
    resumes = len(by.get("duel_resumed", []))
    m["duels_unfinished"] = max(0, m["duels_started"] - len(ends) - min(resumes, saves))
    m["captures_per_duel"] = (_median([float(_num(e.get("captures_p")) or 0) + float(_num(e.get("captures_ai")) or 0)
                                       for e in ends if e.get("source") != "dossier"]))
    m["carded"] = len(by.get("carded", []))
    # Tutorial D1.
    d1_started = any(str(e.get("id")) in D1_IDS for e in by.get("dossier_start", []))
    d1_clears = [e for e in by.get("dossier_clear", []) if str(e.get("id")) in D1_IDS]
    m["d1_started"] = d1_started or bool(d1_clears)
    m["d1_s"] = _num(d1_clears[0].get("since_start_s")) if d1_clears else None
    m["d1_attempts"] = int(_num(d1_clears[0].get("attempts")) or 0) if d1_clears else \
        sum(1 for e in by.get("duel_start", []) if e.get("source") == "dossier" and str(e.get("rival")) in D1_IDS)
    m["dossiers_cleared"] = sorted({str(e.get("id")) for e in by.get("dossier_clear", [])})
    # Other engagement.
    m["cipher_attempts"] = len(by.get("cipher_attempt", []))
    m["cipher_solved"] = bool(by.get("cipher_solved"))
    m["unlocks"] = len(by.get("unlock", []))
    m["card_unlocks"] = sum(1 for e in by.get("unlock", []) if e.get("kind") == "card")
    m["lineup_saves"] = len(by.get("lineup_saved", []))
    m["lobby_waits"] = len(by.get("lobby_wait_start", []))
    m["match_found"] = [str(e.get("choice")) for e in by.get("lobby_match_found", [])]
    m["match_found_mid_duel"] = sum(1 for e in by.get("lobby_match_found", [])
                                    if isinstance(e.get("duel_state"), dict) and e["duel_state"].get("in_duel") is True)
    m["resumes"] = len(by.get("duel_resumed", []))
    m["resume_age_s"] = [float(_num(e.get("age_s")) or 0) for e in by.get("duel_resumed", [])]
    m["collection_reset"] = bool(by.get("collection_reset"))
    m["exported"] = bool(by.get("log_exported"))
    # Live estimates (inputs; shares are computed across the pool).
    lineups = by.get("duel_lineup", [])
    m["lineups"] = len(lineups)
    m["lineups_own"] = sum(1 for e in lineups if e.get("loaner") is False)
    m["set_complete"] = bool(by.get("set_complete"))
    m["lobby_duels_per_wait_num"] = sum(1 for e in by.get("duel_start", [])
                                        if e.get("source") == "lobby" and e.get("play_again") is False) + m["resumes"]
    m["load_pass"] = None if m["load_ms"] is None else m["load_ms"] < BAR_LOAD_MS
    s.m = m


# =============================================================================
# Testers and the pool
# =============================================================================

@dataclass
class Tester:
    tid: str
    sessions: list[Session]
    m: dict[str, Any] = field(default_factory=dict)


def group_testers(sessions: dict[str, Session], unit: str) -> list[Tester]:
    if unit == "session":
        return [Tester(f"S{i + 1}", [s]) for i, s in enumerate(sessions.values())]
    # Union-find over files: sessions in one file, or files sharing a session, are one tester.
    parent: dict[str, str] = {}

    def find(x: str) -> str:
        while parent.setdefault(x, x) != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for s in sessions.values():
        for f in s.files[1:]:
            parent[find(f)] = find(s.files[0])
    groups: dict[str, list[Session]] = {}
    for s in sessions.values():
        groups.setdefault(find(s.files[0]), []).append(s)
    return [Tester(f"T{i + 1}", g) for i, g in enumerate(groups.values())]


def analyse_tester(t: Tester) -> None:
    ss = t.sessions
    m: dict[str, Any] = {}
    surveyed = [s for s in ss if s.m["survey_taken"]]
    last = surveyed[-1] if surveyed else None
    for q in ("q1", "q2", "q3", "q4"):
        m[q] = last.m[q] if last else None
    m["intent"] = None if m["q1"] is None else m["q1"] >= 4
    m["fair"] = None if m["q4"] is None else m["q4"] >= 4
    m["album_pull"] = any(s.m["album_pull"] for s in ss)
    m["duel_durations"] = [d for s in ss for d in s.m["duel_durations"]]
    m["duel_median_s"] = _median(m["duel_durations"])
    first_clear = next((s.m["d1_s"] for s in ss if s.m["d1_s"] is not None), None)
    m["d1_started"] = any(s.m["d1_started"] for s in ss)
    m["d1_s"] = first_clear
    loads = [s.m["load_ms"] for s in ss if s.m["load_ms"] is not None]
    m["load_worst_ms"] = max(loads) if loads else None
    m["load_pass"] = None if not loads else all(x < BAR_LOAD_MS for x in loads)
    m["device"] = "/".join(sorted({s.m["device"] for s in ss if s.m["device"]})) or "?"
    m["entry"] = next((s.m["entry"] for s in ss if s.m["entry"]), "")
    m["events"] = sum(s.m["events"] for s in ss)
    t.m = m


def _share(flags: list[bool | None]) -> tuple[int, int, float | None]:
    known = [f for f in flags if f is not None]
    yes = sum(1 for f in known if f)
    return yes, len(known), (yes / len(known) if known else None)


def pool_kpis(testers: list[Tester], sessions: list[Session]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []

    def status(ok: bool | None) -> str:
        return "NO DATA" if ok is None else ("PASS" if ok else "FAIL")

    yes, n, share = _share([t.m["intent"] for t in testers])
    rows.append({"kpi": "Intent to collect", "bar": ">= 70% answer 4-5 (q1)",
                 "value": "no answers" if share is None else f"{share:.0%} ({yes}/{n})",
                 "status": status(None if share is None else share >= BAR_AGREE_SHARE), "n": n,
                 "raw": share})
    with_data = [t for t in testers if t.m["events"] > 0]
    yes, n, share = _share([t.m["album_pull"] for t in with_data])
    rows.append({"kpi": "Album pull", "bar": ">= 50% open album 2+ times and inspect a locked card",
                 "value": "no data" if share is None else f"{share:.0%} ({yes}/{n})",
                 "status": status(None if share is None else share >= BAR_ALBUM_SHARE), "n": n, "raw": share})
    durations = [d for t in testers for d in t.m["duel_durations"]]
    med = _median(durations)
    rows.append({"kpi": "Session fit (duel)", "bar": "median < 4:00 (rival + lobby, not resumed)",
                 "value": "no duels" if med is None else f"{_mmss(med)} median of {len(durations)} duels",
                 "status": status(None if med is None else med < BAR_DUEL_MEDIAN_S), "n": len(durations),
                 "raw": med})
    started = [t for t in testers if t.m["d1_started"]]
    cleared = [t.m["d1_s"] for t in started if t.m["d1_s"] is not None]
    # A tester who started D1 and never cleared it counts as slower than any clear.
    times = [t.m["d1_s"] if t.m["d1_s"] is not None else float("inf") for t in started]
    d1_med = _median(times) if times else None
    if d1_med is None:
        d1_val = "D1 not played"
    elif d1_med == float("inf"):
        d1_val = f"median not reached ({len(cleared)}/{len(started)} cleared)"
    else:
        d1_val = f"{_mmss(d1_med)} median, {len(cleared)}/{len(started)} cleared, " \
                 f"{sum(1 for x in cleared if x < BAR_D1_S)} under 3:00"
    rows.append({"kpi": "Session fit (tutorial D1)", "bar": "D1 cleared < 3:00 (median, start to clear)",
                 "value": d1_val, "status": status(None if d1_med is None else d1_med < BAR_D1_S),
                 "n": len(started), "raw": None if d1_med in (None, float("inf")) else d1_med})
    yes, n, share = _share([t.m["fair"] for t in testers])
    rows.append({"kpi": "Fairness", "bar": ">= 70% answer 4-5 (q4)",
                 "value": "no answers" if share is None else f"{share:.0%} ({yes}/{n})",
                 "status": status(None if share is None else share >= BAR_AGREE_SHARE), "n": n, "raw": share})
    loads = [s.m["load_ms"] for s in sessions if s.m["load_ms"] is not None]
    slow = sum(1 for x in loads if x >= BAR_LOAD_MS)
    rows.append({"kpi": "Load", "bar": "< 10 s in every session",
                 "value": "no session_start" if not loads else
                 f"worst {max(loads) / 1000:.1f} s, median {statistics.median(loads) / 1000:.1f} s, {slow}/{len(loads)} slow",
                 "status": status(None if not loads else slow == 0), "n": len(loads),
                 "raw": max(loads) if loads else None})
    return rows


def live_estimates(sessions: list[Session]) -> list[dict[str, Any]]:
    lineups = sum(s.m["lineups"] for s in sessions)
    own = sum(s.m["lineups_own"] for s in sessions)
    with_data = [s for s in sessions if s.m["events"] > 0]
    sets = sum(1 for s in with_data if s.m["set_complete"])
    num = sum(s.m["lobby_duels_per_wait_num"] for s in sessions)
    waits = sum(s.m["lobby_waits"] for s in sessions)
    return [
        {"kpi": "Non-default lineup (live est.)", "bar": "estimate",
         "value": "no duels" if not lineups else f"{own / lineups:.0%} of {lineups} duel lineups", "raw": own / lineups if lineups else None},
        {"kpi": "Set completion (live est.)", "bar": "estimate",
         "value": "no data" if not with_data else f"{sets}/{len(with_data)} sessions completed a set",
         "raw": sets / len(with_data) if with_data else None},
        {"kpi": "Banner Wall duels per matchmaking wait (live est.)", "bar": "estimate",
         "value": "no lobby waits" if not waits else f"{num / waits:.2f} ({num} duels / {waits} waits)",
         "raw": num / waits if waits else None},
    ]


def coverage(testers: list[Tester], sessions: list[Session]) -> list[tuple[str, str, str]]:
    n = len(testers)
    phones = sum(1 for t in testers if "phone" in t.m["device"])
    menu = sum(1 for t in testers if t.m["entry"] == "menu")
    lobby = sum(1 for t in testers if t.m["entry"] == "lobby")
    surveyed = sum(1 for t in testers if any(s.m["survey_answered"] > 0 for s in t.sessions))
    return [
        ("Testers (3-5)", str(n), "ok" if 3 <= n <= 5 else "short" if n < 3 else "more than planned"),
        ("Sessions with events", str(sum(1 for s in sessions if s.m["events"] > 0)), ""),
        ("On a phone (>= 1)", str(phones), "ok" if phones >= 1 else "missing"),
        ("Started from the menu (>= 2)", str(menu), "ok" if menu >= 2 else "short"),
        ("Started from Find a Match (>= 2)", str(lobby), "ok" if lobby >= 2 else "short"),
        ("Answered at least one survey statement", f"{surveyed}/{n}", "ok" if n and surveyed == n else "missing"),
    ]


# =============================================================================
# Output
# =============================================================================

def _mmss(s: float | None) -> str:
    if s is None:
        return "-"
    if s == float("inf"):
        return "not cleared"
    s = int(round(s))
    return f"{s // 60}:{s % 60:02d}"


def _yn(v: bool | None) -> str:
    return "-" if v is None else ("yes" if v else "no")


def _md_escape(text: str) -> str:
    return text.replace("|", "\\|").replace("\n", " ")


def build_markdown(title: str, files: list[LogFile], skipped: list[LogFile], schema: Schema,
                   schema_notes: list[str], testers: list[Tester], sessions: list[Session],
                   kpis: list[dict], live: list[dict], unit: str) -> str:
    synthetic = any(f.synthetic for f in files)
    now = _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    out: list[str] = []
    if synthetic:
        out.append("> **SYNTHETIC DATA. Not a playtest.** These logs were generated by "
                   "tools/synthetic_playtest_sessions.gd to test this tool. Never quote these numbers.\n")
    out.append(f"# {title}\n")
    out.append(f"Generated {now} by `tools/kpi_sheet.py` · schema from {schema.source} · unit: {unit} · "
               f"{len(files)} file(s), {len(sessions)} session(s), {len(testers)} tester(s).\n")
    n = len(testers)
    out.append(f"**Small sample:** {n} tester(s). With 3-5 testers every result is directional only; one "
               "tester moves a share by 20-33 points.\n")
    out.append("## Pass bars\n")
    out.append("| KPI | Bar | Result | Status |\n|---|---|---|---|")
    for r in kpis:
        out.append(f"| {r['kpi']} | {r['bar']} | {r['value']} | **{r['status']}** |")
    passed = sum(1 for r in kpis if r["status"] == "PASS")
    failed = sum(1 for r in kpis if r["status"] == "FAIL")
    nodata = sum(1 for r in kpis if r["status"] == "NO DATA")
    out.append(f"\n{passed} pass, {failed} fail, {nodata} no data (of {len(kpis)}).\n")
    out.append("## Live estimates (for the pitch, no bar)\n")
    out.append("| Estimate | Result |\n|---|---|")
    for r in live:
        out.append(f"| {r['kpi']} | {r['value']} |")
    out.append("\n## Plan coverage (prototype-milestone-plan.md section 8)\n")
    out.append("| Check | Count | |\n|---|---|---|")
    for a, b, c in coverage(testers, sessions):
        out.append(f"| {a} | {b} | {c} |")
    out.append("\n## Per tester\n")
    out.append("| Tester | Sessions | Device | Entry | q1 | q2 | q3 | q4 | Album pull | Median duel | D1 | Worst load |")
    out.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for t in testers:
        m = t.m
        d1 = "not played" if not m["d1_started"] else _mmss(m["d1_s"]) if m["d1_s"] is not None else "not cleared"
        load = "-" if m["load_worst_ms"] is None else f"{m['load_worst_ms'] / 1000:.1f} s"
        out.append(f"| {t.tid} | {', '.join(s.sid for s in t.sessions)} | {m['device']} | {m['entry'] or '-'} | "
                   f"{m['q1'] or '-'} | {m['q2'] or '-'} | {m['q3'] or '-'} | {m['q4'] or '-'} | "
                   f"{_yn(m['album_pull'])} | {_mmss(m['duel_median_s'])} | {d1} | {load} |")
    out.append("\n## Per session\n")
    for s in sessions:
        m = s.m
        out.append(f"### Session `{s.sid}`\n")
        out.append(f"- File(s): {', '.join(s.files)}")
        if not m["events"]:
            out.append("- No events.\n")
            continue
        warn = []
        if not m["has_session_start"]:
            warn.append("no session_start (log rotated, cut off or opted in late)")
        if m["seq_gaps"]:
            warn.append(f"{m['seq_gaps']} missing line(s) by seq")
        out.append(f"- Device: {m['device'] or '?'} · {m['os'] or '?'} · {m['browser'] or 'no browser'} · "
                   f"date {m['date'] or '?'} · build {m['build'] or '-'}")
        out.append(f"- Entry: {m['entry'] or '?'} · length {_mmss(m['length_s'])} · ended: {m['ended']} · "
                   f"{m['events']} events" + (f" · **{'; '.join(warn)}**" if warn else ""))
        load = "-" if m["load_ms"] is None else f"{m['load_ms'] / 1000:.1f} s ({'pass' if m['load_pass'] else 'FAIL'})"
        out.append(f"- Load: {load}")
        out.append("- Survey: " + ("not taken" if not m["survey_taken"] else
                   "opened, every statement skipped" if m["survey_answered"] == 0 else
                   f"q1 {m['q1'] or '-'}, q2 {m['q2'] or '-'}, q3 {m['q3'] or '-'}, q4 {m['q4'] or '-'} (- = skipped)"))
        out.append(f"- Album: {m['album_opens']} open(s), {m['locked_inspects']} locked card inspect(s) → "
                   f"album pull {_yn(m['album_pull'])}")
        dbs = m["duels_by_source"]
        durs = ", ".join(_mmss(d) for d in m["duel_durations"]) or "-"
        out.append(f"- Duels: {dbs['rival']} rival, {dbs['lobby']} lobby, {dbs['dossier']} Dossier, "
                   f"{m['resumed_duels']} resumed, {m['duels_unfinished']} unfinished · counted lengths {durs} → "
                   f"median {_mmss(m['duel_median_s'])}")
        res = "; ".join(f"{r}: {v['win']}W {v['loss']}L {v['draw']}D" for r, v in m["results_by_rival"].items()) or "-"
        out.append(f"- Results by rival (no Dossiers): {res} · Carded! {m['carded']} time(s)")
        d1 = "not played" if not m["d1_started"] else \
            (f"cleared in {_mmss(m['d1_s'])} on attempt {m['d1_attempts']}" if m["d1_s"] is not None
             else f"not cleared ({m['d1_attempts']} attempt(s))")
        out.append(f"- Tutorial D1: {d1} · Dossiers cleared: {', '.join(m['dossiers_cleared']) or '-'}")
        out.append(f"- Lobby: {m['lobby_waits']} wait(s), match found {m['match_found'] or '-'} "
                   f"({m['match_found_mid_duel']} mid-duel), {m['resumes']} resume(s)"
                   + (f" after {', '.join(_mmss(a) for a in m['resume_age_s'])}" if m["resume_age_s"] else ""))
        out.append(f"- Collection: {m['unlocks']} unlock(s) ({m['card_unlocks']} card), "
                   f"{m['lineup_saves']} lineup save(s), Cipher Lock {m['cipher_attempts']} attempt(s), "
                   f"solved {_yn(m['cipher_solved'])}" + (" · pressed Reset demo" if m["collection_reset"] else ""))
        if m["open"]:
            out.append(f"- Open answer: \"{_md_escape(m['open'])}\"")
        out.append("")
    out.append("## Files and validation\n")
    out.append("| File | Kind | Synthetic | Events | Rejected lines | Problems |\n|---|---|---|---|---|---|")
    for f in files + skipped:
        out.append(f"| {f.path.name} | {f.kind} | {'yes' if f.synthetic else 'no'} | {len(f.events)} | "
                   f"{f.rejected} | {_md_escape('; '.join(f.problems)) or '-'} |")
    if skipped:
        out.append(f"\n{len(skipped)} file(s) not counted (synthetic without --include-synthetic, or unreadable).")
    for note in schema_notes:
        out.append(f"\nNote: {note}")
    out.append("\nRecipes: documentation/production/playtest-log-schema.md section 5. Tester-level rules: the last "
               "survey answered counts; album pull if any session meets it; duel lengths pooled; D1 from the first "
               "clear (a tester who started D1 and never cleared it counts as slower than 3:00); load must pass in "
               "every session. D1 is matched by id `dossier_first_contact` (or `d1`).")
    return "\n".join(out) + "\n"


def _csv_num(v: Any) -> Any:
    if v is None:
        return ""
    if isinstance(v, float):
        return round(v, 3)
    return v


def write_csv(path: Path, kpis: list[dict], live: list[dict], testers: list[Tester],
              sessions: list[Session], synthetic: bool) -> None:
    with path.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["synthetic", "scope", "id", "metric", "value", "bar", "status"])
        tag = "yes" if synthetic else "no"
        for r in kpis:
            w.writerow([tag, "overall", "all", r["kpi"], _csv_num(r["raw"]), r["bar"], r["status"]])
        for r in live:
            w.writerow([tag, "overall", "all", r["kpi"], _csv_num(r["raw"]), "estimate", ""])

        def bar_status(v: Any, ok: bool | None) -> str:
            return "" if ok is None else ("PASS" if ok else "FAIL")

        for scope, items in (("tester", [(t.tid, t.m) for t in testers]), ("session", [(s.sid, s.m) for s in sessions])):
            for ident, m in items:
                med = m.get("duel_median_s")
                d1 = m.get("d1_s")
                load = m.get("load_ms", m.get("load_worst_ms"))
                rows = [
                    ("q1 intent", m.get("q1"), ">= 4", bar_status(None, m.get("intent"))),
                    ("q2 album", m.get("q2"), "", ""),
                    ("q3 session fit", m.get("q3"), "", ""),
                    ("q4 fairness", m.get("q4"), ">= 4", bar_status(None, m.get("fair"))),
                    ("album pull", m.get("album_pull"), "2+ opens and a locked inspect",
                     bar_status(None, m.get("album_pull") if m.get("events") else None)),
                    ("median duel s", "" if med is None else round(med, 1), "< 240",
                     bar_status(None, None if med is None else med < BAR_DUEL_MEDIAN_S)),
                    ("D1 since start s", "" if d1 is None else round(d1, 1), "< 180",
                     bar_status(None, None if not m.get("d1_started") else (d1 is not None and d1 < BAR_D1_S))),
                    ("load ms", "" if load is None else int(load), "< 10000", bar_status(None, m.get("load_pass"))),
                    ("device", m.get("device", ""), "", ""),
                    ("entry", m.get("entry", ""), "", ""),
                ]
                for metric, value, bar, st in rows:
                    w.writerow([tag, scope, ident, metric, "" if value is None else value, bar, st])


# =============================================================================
# Main
# =============================================================================

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="CallingCard playtest KPI sheet from exported logs.")
    ap.add_argument("inputs", nargs="+", help="exported .json logs, raw .jsonl logs, or folders")
    ap.add_argument("--out", help="output path without extension")
    ap.add_argument("--unit", choices=("tester", "session"), default="tester")
    ap.add_argument("--include-synthetic", action="store_true")
    ap.add_argument("--schema", type=Path)
    ap.add_argument("--title", default="CallingCard internal playtest: KPI sheet")
    args = ap.parse_args(argv)

    schema, schema_notes = load_schema(args.schema)
    paths = gather_paths(args.inputs)
    if not paths:
        print("error: no .json / .jsonl logs found", file=sys.stderr)
        return 2
    files: list[LogFile] = []
    skipped: list[LogFile] = []
    for p in paths:
        lf = read_log(p)
        if lf.kind == "unreadable" or (lf.synthetic and not args.include_synthetic):
            if lf.synthetic and not args.include_synthetic and lf.kind != "unreadable":
                lf.problems.append("synthetic: left out (pass --include-synthetic to test the tool)")
            skipped.append(lf)
            continue
        files.append(lf)
    if not files:
        print("No log counted, so no sheet was written:", file=sys.stderr)
        for lf in skipped:
            print(f"  {lf.path.name}: {'; '.join(lf.problems)}", file=sys.stderr)
        return 1

    sessions: dict[str, Session] = {}
    seen: set[tuple[str, int]] = set()
    for lf in files:
        good = []
        for e in lf.events:
            errs = validate_entry(e, schema)
            if errs:
                lf.rejected += 1
                if len(lf.problems) < 12:
                    lf.problems.append(f"seq {e.get('seq', '?')}: {errs[0]}")
                # Keep lines that still identify their session and event, so one schema drift
                # does not hide a whole session; unknown events are dropped.
                if not isinstance(e, dict) or str(e.get("event")) not in schema.events or "sid" not in e:
                    continue
            good.append(e)
        if lf.kind == "export" and not lf.events:
            lf.problems.append("no events: consent was off, or the log was deleted")
        for e in good:
            sid = str(e.get("sid"))
            key = (sid, int(_num(e.get("seq")) or 0))
            s = sessions.setdefault(sid, Session(sid))
            name = lf.path.name
            if name not in s.files:
                s.files.append(name)
            if key in seen:
                continue
            seen.add(key)
            s.events.append(e)
    session_list = list(sessions.values())
    for s in session_list:
        analyse_session(s)
    session_list.sort(key=lambda s: (s.m.get("date", ""), s.files[0], s.sid))
    testers = group_testers({s.sid: s for s in session_list}, args.unit)
    for t in testers:
        analyse_tester(t)
    kpis = pool_kpis(testers, session_list)
    live = live_estimates(session_list)

    synthetic = any(f.synthetic for f in files)
    out = Path(args.out) if args.out else Path(str(DEFAULT_OUT) + ("-SYNTHETIC" if synthetic else ""))
    if synthetic and "SYNTHETIC" not in out.name.upper():
        out = out.with_name(out.name + "-SYNTHETIC")
    out.parent.mkdir(parents=True, exist_ok=True)
    md_path = out.with_suffix(".md")
    csv_path = out.with_suffix(".csv")
    title = args.title + (" (SYNTHETIC)" if synthetic else "")
    md_path.write_text(build_markdown(title, files, skipped, schema, schema_notes, testers, session_list,
                                      kpis, live, args.unit), encoding="utf-8")
    write_csv(csv_path, kpis, live, testers, session_list, synthetic)
    print(f"{len(files)} file(s) read, {len(skipped)} skipped; {len(session_list)} session(s), {len(testers)} tester(s)")
    for r in kpis:
        print(f"  {r['status']:8} {r['kpi']}: {r['value']}")
    print(f"wrote {md_path}\nwrote {csv_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

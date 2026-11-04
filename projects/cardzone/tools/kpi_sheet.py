#!/usr/bin/env python3
"""CardZone playtest KPI sheet (cz18).

Reads exported playtest logs ("Download log" files, cardzone-playtest-*.json), checks every line
against the logger's schema and computes the KPIs of prototype-milestone-plan.md section 8 (recipes:
documentation/production/playtest-log-schema.md section 5) per session, per tester and across
testers, with pass / fail against the plan's bars. Writes a markdown KPI sheet and a CSV.

Usage:
    python3 tools/kpi_sheet.py playtest-logs/                     # every *.json / *.jsonl in it
    python3 tools/kpi_sheet.py a.json b.json --out playtest-logs/kpi/kpi-sheet
    python3 tools/kpi_sheet.py playtest-logs/synthetic --include-synthetic   # tool test only

Options:
    --out PATH            output path without extension (default: playtest-logs/kpi/kpi-sheet,
                          or .../kpi-sheet-SYNTHETIC when synthetic files are included)
    --unit tester|session tester (default): sessions found in the same file, or in files that
                          share a session id, are one tester (a reload starts a new session on the
                          same device, and the download holds both). session: every session is a tester.
    --include-synthetic   also read files marked "synthetic": true (left out by default, so test
                          data never counts in a real report)
    --schema PATH         playtest_log.gd to read SCHEMA / ENUMS from (default: the game's copy;
                          falls back to the copy built into this file)
    --title TEXT          heading for the sheet

Standard library only (Python 3.9+). Handles empty, partial (cut-off) and consent-off logs: such
files are listed with what was missing, and every KPI says "NO DATA" rather than guessing.
Exit code: 0 when a sheet was written, 1 when no log could be counted (nothing written),
2 on bad arguments or no input files.
"""

from __future__ import annotations

import argparse
import ast
import csv
import datetime as _dt
import json
import math
import re
import statistics
import sys
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

TOOL_DIR = Path(__file__).resolve().parent
PROJECT_DIR = TOOL_DIR.parent
DEFAULT_SCHEMA_GD = PROJECT_DIR / "source" / "project-cardzone" / "autoload" / "playtest_log.gd"
DEFAULT_OUT = PROJECT_DIR / "playtest-logs" / "kpi" / "kpi-sheet"
EXPORT_FORMAT = "cardzone-playtest-log"
SCHEMA_VERSION = 1
SURVEY_KEYS = ("q1", "q2", "q3", "q4", "q5")

# Pass bars (prototype-milestone-plan.md section 8).
BAR_PACK_MEDIAN_MS = 10_000
BAR_PACK_P90_MS = 20_000
BAR_TURN_MEDIAN_MS = 60_000
BAR_MATCH_MIN_S, BAR_MATCH_MAX_S = 12 * 60, 20 * 60
BAR_ROUNDS_MIN, BAR_ROUNDS_MAX = 8, 14
BAR_EARLY_ROUND = 6           # no human eliminated before this round ...
BAR_EARLY_SHARE = 0.90        # ... in at least this share of matches
BAR_COMEBACK_HEALTH = 3       # human at <= 3 health at the start of ...
BAR_COMEBACK_ROUND = 4        # ... round 4
BAR_COMEBACK_SURVIVE = 10     # a comeback = a win or surviving to round 10+
BAR_COMEBACK_SHARE = 1 / 3
BAR_HOLD_SHARE = 0.60         # packs holding >= 1 card, from the second match on
BAR_BRACE_SHARE = 0.50        # Brace prompts (Brace possible) answered with >= 1 card
BAR_FULL_BRACE_MAX = 0.35     # human shots at the AI fully braced (0 Hits): at most
BAR_REPLAY_SHARE = 0.50       # testers starting a 2nd match
BAR_LOAD_MS = 10_000          # every iPhone session
SURVEY_BARS = {  # key: (KPI name, statement, bar)
    "q1": ("Survey: play another", "I want to play another match.", 0.70),
    "q2": ("Survey: damage understood", "I understood why I took damage.", 0.70),
    "q3": ("Survey: packing quick", "Packing felt quick.", 0.70),
    "q4": ("Survey: choices over luck", "My choices mattered more than luck.", 0.70),
    "q5": ("Survey: AI fair", "The AI played fair.", 0.60),
}

# Fallback copy of playtest_log.gd (schema version 1), used when the .gd cannot be read.
FALLBACK_SCHEMA: dict[str, dict[str, str]] = {
    'session_start': {"schema": "i", "consent_version": "i", "load_ms": "i", "input_type": "s", "viewport": "a", "window_px": "a", "pixel_ratio": "n", "browser": "s", "os_family": "s", "web": "b", "mobile": "b", "touchscreen": "b", "device_class": "s", "engine": "s", "build": "s", "date_utc": "s"},
    'consent': {"given": "b"},
    'input_type': {"kind": "s"},
    'screen': {"name": "s"},
    'match_start': {"match": "i", "mode": "s", "ai_level": "s", "first_player": "s", "human_seat": "i", "route": "s", "drop_human": "s", "drop_ai": "s", "hand_size": "i", "tunables_hash": "s", "tunables": "d", "setup_s": "n", "play_again": "b"},
    'match_resumed': {"match": "i", "age_s": "n", "actions": "i", "round": "i", "mode": "s", "ai_level": "s"},
    'round_start': {"round": "i", "zone_card": "i", "health_h": "i", "health_ai": "i", "bounty": "s"},
    'turn_start': {"seat": "s", "round": "i", "turn": "i", "hand_ids": "a", "hits_drawn": "i"},
    'card_play': {"seat": "s", "card_id": "s", "as": "s", "round": "i"},
    'move': {"seat": "s", "from": "s", "to": "s", "round": "i"},
    'loot': {"seat": "s", "card_id": "s", "source": "s", "cost": "i", "area": "s", "round": "i"},
    'attach': {"seat": "s", "attachment_id": "s", "weapon_id": "s", "round": "i"},
    'shot': {"shooter": "s", "kind": "s", "weapon_id": "s", "attachments": "a", "target": "s", "raw": "i", "cover": "i", "down": "i", "damage": "i", "suppressor": "b", "brace_allowed": "b", "brace_cards": "a", "brace_total": "i", "hits": "i", "bounty_claim": "b", "bounty_heal": "i", "eliminated": "b", "round": "i"},
    'brace': {"kind": "s", "prompt_ms": "i", "cards": "a", "card_count": "i", "total": "i", "damage": "i", "hits": "i", "eligible": "i", "possible": "b", "suggested_used": "b?", "round": "i"},
    'patch_up': {"seat": "s", "healed": "i", "health": "i", "round": "i"},
    'ditch': {"seat": "s", "card_id": "s", "round": "i"},
    'gas_hit': {"seat": "s", "area": "s", "hits": "i", "health": "i", "round": "i"},
    'final_circle': {"step": "i", "hits": "i", "health_h": "i", "health_ai": "i", "round": "i"},
    'pack': {"hold_ids": "a", "hold_count": "i", "pack_ms": "i", "pack_from": "s", "line_stowed": "i", "hand_stowed": "i", "round": "i"},
    'turn_end': {"turn_ms": "i", "undo_count": "i", "round": "i", "turn": "i"},
    'elimination': {"seat": "s", "round": "i", "by": "s"},
    'match_end': {"match": "i", "result": "s", "rounds": "i", "duration_s": "n", "cause": "s", "health_h": "i", "health_ai": "i", "mode": "s", "ai_level": "s", "resumed": "b", "human_turns": "i"},
    'coach_step': {"step": "s", "skipped": "b"},
    'survey': {"q1": "i?", "q2": "i?", "q3": "i?", "q4": "i?", "q5": "i?", "open": "s", "answered": "i"},
    'log_exported': {"method": "s", "bytes": "i"},
    'app_hidden': {"screen": "s", "session_s": "n"},
    'app_visible': {"screen": "s", "session_s": "n"},
    'quit': {"screen": "s", "session_s": "n", "reason": "s"},
}
FALLBACK_COMMON = {"v": "i", "sid": "s", "seq": "i", "t_ms": "i", "event": "s"}
FALLBACK_ENUMS: dict[str, list[str]] = {
    'session_start.input_type': ["touch", "mouse"],
    'session_start.device_class': ["phone", "tablet", "desktop"],
    'input_type.kind': ["touch", "mouse", "keyboard", "gamepad"],
    'match_start.mode': ["ai", "hotseat"],
    'match_start.first_player': ["human", "ai"],
    'match_resumed.mode': ["ai", "hotseat"],
    'round_start.bounty': ["human", "ai", "none"],
    'turn_start.seat': ["human", "ai"],
    'card_play.seat': ["human", "ai"],
    'card_play.as': ["effect", "adrenaline_move", "adrenaline_search"],
    'move.seat': ["human", "ai"],
    'loot.seat': ["human", "ai"],
    'loot.source': ["pile", "drop", "crate"],
    'attach.seat': ["human", "ai"],
    'shot.shooter': ["human", "ai"],
    'shot.kind': ["shot", "frag"],
    'shot.target': ["human", "ai"],
    'brace.kind': ["shot", "frag"],
    'patch_up.seat': ["human", "ai"],
    'ditch.seat': ["human", "ai"],
    'gas_hit.seat': ["human", "ai"],
    'pack.pack_from': ["pack_step", "last_action"],
    'elimination.seat': ["human", "ai"],
    'elimination.by': ["shot", "frag", "gas", "final_circle"],
    'match_end.result': ["win", "loss", "draw"],
    'match_end.cause': ["shot", "frag", "gas", "final_circle", "hard_end", "concede"],
    'match_end.mode': ["ai", "hotseat"],
    'log_exported.method': ["download", "file"],
    'quit.reason': ["close", "pagehide"],
}


# =============================================================================
# Schema
# =============================================================================

@dataclass
class Schema:
    events: dict[str, dict[str, str]]
    common: dict[str, str]
    enums: dict[str, list[str]]
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
        schema = Schema(_gd_const(text, "SCHEMA"), _gd_const(text, "COMMON_FIELDS"), _gd_const(text, "ENUMS"), _rel(gd))
        if schema.events != FALLBACK_SCHEMA or schema.enums != FALLBACK_ENUMS:
            notes.append("The game's schema differs from the copy in kpi_sheet.py; the game's is used. "
                         "Update FALLBACK_SCHEMA / FALLBACK_ENUMS.")
        return schema, notes
    except (OSError, ValueError, SyntaxError) as exc:
        notes.append(f"Could not read the schema from {gd} ({exc}); used the built-in copy (schema v1).")
        return Schema(FALLBACK_SCHEMA, FALLBACK_COMMON, FALLBACK_ENUMS, "built-in copy"), notes


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
    for key in ("hand_ids", "hold_ids", "cards", "brace_cards", "attachments"):
        if isinstance(entry.get(key), list) and any(not isinstance(v, str) for v in entry[key]):
            errors.append(f"{name}.{key}: holds something other than card ids")
    if name == "survey":
        for q in SURVEY_KEYS:
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
    lf.problems.append("not a CardZone export, JSON lines or a recoverable export")
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
# Helpers
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


def _p90(values: list[float]) -> float | None:
    """90th percentile, nearest rank (no interpolation, so small samples stay readable)."""
    if not values:
        return None
    s = sorted(values)
    return s[max(0, math.ceil(0.9 * len(s)) - 1)]


def _share(flags: list[bool | None]) -> tuple[int, int, float | None]:
    known = [f for f in flags if f is not None]
    yes = sum(1 for f in known if f)
    return yes, len(known), (yes / len(known) if known else None)


def _secs(ms: float | None) -> str:
    return "-" if ms is None else f"{ms / 1000:.1f} s"


def _mmss(s: float | None) -> str:
    if s is None:
        return "-"
    s = int(round(s))
    return f"{s // 60}:{s % 60:02d}"


def _pct(share: float | None) -> str:
    return "-" if share is None else f"{share:.0%}"


# =============================================================================
# Matches (stream order within a session)
# =============================================================================

@dataclass
class Match:
    sid: str
    resumed: bool                      # this part began with match_resumed
    start: dict | None = None          # match_start (None for a resumed part)
    end: dict | None = None
    mode: str = "ai"
    ai_level: str = ""
    ordinal: int = 0                   # the tester's match number (a resumed part keeps its match's)
    packs: list[dict] = field(default_factory=list)
    turn_ends: list[dict] = field(default_factory=list)
    rounds: dict[int, dict] = field(default_factory=dict)
    eliminations: list[dict] = field(default_factory=list)
    shots: list[dict] = field(default_factory=list)
    braces: list[dict] = field(default_factory=list)
    plays: list[dict] = field(default_factory=list)
    loots: list[dict] = field(default_factory=list)
    other: Counter = field(default_factory=Counter)

    @property
    def vs_ai(self) -> bool:
        return self.mode == "ai"

    def human_eliminated_round(self) -> int | None:
        for e in self.eliminations:
            if e.get("seat") == "human":
                return int(_num(e.get("round")) or 0)
        return None


def split_matches(events: list[dict]) -> list[Match]:
    out: list[Match] = []
    cur: Match | None = None
    for e in events:
        name = e.get("event")
        if name in ("match_start", "match_resumed"):
            cur = Match(str(e.get("sid")), name == "match_resumed", e if name == "match_start" else None,
                        mode=str(e.get("mode", "ai")), ai_level=str(e.get("ai_level", "")))
            out.append(cur)
            continue
        if cur is None:
            continue
        if name == "match_end":
            cur.end = e
            cur.mode = str(e.get("mode", cur.mode))
            cur.ai_level = str(e.get("ai_level", cur.ai_level))
            cur = None
        elif name == "pack":
            cur.packs.append(e)
        elif name == "turn_end":
            cur.turn_ends.append(e)
        elif name == "round_start":
            cur.rounds.setdefault(int(_num(e.get("round")) or 0), e)
        elif name == "elimination":
            cur.eliminations.append(e)
        elif name == "shot":
            cur.shots.append(e)
        elif name == "brace":
            cur.braces.append(e)
        elif name == "card_play":
            cur.plays.append(e)
        elif name == "loot":
            cur.loots.append(e)
        elif name in ("move", "attach", "patch_up", "ditch", "gas_hit", "final_circle", "turn_start"):
            cur.other[name] += 1
    return out


# =============================================================================
# Per-session metrics
# =============================================================================

@dataclass
class Session:
    sid: str
    files: list[str] = field(default_factory=list)
    events: list[dict] = field(default_factory=list)
    matches: list[Match] = field(default_factory=list)
    m: dict[str, Any] = field(default_factory=dict)


def analyse_session(s: Session) -> None:
    ev = sorted(s.events, key=lambda e: (_num(e.get("seq")) or 0))
    s.events = ev
    by: dict[str, list[dict]] = {}
    for e in ev:
        by.setdefault(str(e.get("event")), []).append(e)
    m: dict[str, Any] = {}
    seqs = [int(_num(e.get("seq")) or 0) for e in ev]
    m["events"] = len(ev)
    m["seq_gaps"] = (max(seqs) + 1 - len(set(seqs))) if seqs else 0
    start = (by.get("session_start") or [None])[0]
    m["has_session_start"] = start is not None
    m["device"] = str(start.get("device_class", "")) if start else ""
    m["browser"] = str(start.get("browser", "")) if start else ""
    m["os"] = str(start.get("os_family", "")) if start else ""
    m["date"] = str(start.get("date_utc", "")) if start else ""
    m["build"] = str(start.get("build", "")) if start else ""
    m["load_ms"] = _num(start.get("load_ms")) if start else None
    m["iphone"] = m["os"] == "ios" and m["device"] == "phone"
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
    survey = (by.get("survey") or [None])[-1]
    m["survey_taken"] = survey is not None
    m["survey_answered"] = int(_num(survey.get("answered")) or 0) if survey else 0
    for q in SURVEY_KEYS:
        m[q] = _q(survey.get(q)) if survey else None
    m["open"] = str(survey.get("open", "")) if survey else ""
    m["coach"] = [(str(e.get("step")), bool(e.get("skipped"))) for e in by.get("coach_step", [])]
    m["exported"] = bool(by.get("log_exported"))
    s.matches = split_matches(ev)
    m["match_starts"] = len(by.get("match_start", []))
    m["resumes"] = len(by.get("match_resumed", []))
    m["resume_age_s"] = [float(_num(e.get("age_s")) or 0) for e in by.get("match_resumed", [])]
    m["open_at_end"] = bool(s.matches) and s.matches[-1].end is None
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

    @property
    def matches(self) -> list[Match]:
        return [x for s in self.sessions for x in s.matches]


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
    """Sessions in log order (a reload is a new session in the same download); match ordinals
    run across them, a resumed part keeps the ordinal of the match it continues."""
    t.sessions.sort(key=lambda s: _session_order(s))
    ordinal = 0
    lost = 0
    for i, s in enumerate(t.sessions):
        for x in s.matches:
            if x.resumed and ordinal > 0:
                x.ordinal = ordinal
            else:
                ordinal += 1
                x.ordinal = ordinal
        # Saves: a session that ends mid-match, followed by a session that starts a new match
        # before any resume, is a suspected lost match (the save did not come back).
        if s.m["open_at_end"] and i + 1 < len(t.sessions):
            nxt = t.sessions[i + 1].matches
            if nxt and not nxt[0].resumed:
                lost += 1
    m: dict[str, Any] = {}
    surveyed = [s for s in t.sessions if s.m["survey_taken"]]
    last = surveyed[-1] if surveyed else None
    for q in SURVEY_KEYS:
        m[q] = last.m[q] if last else None
    m["survey_any"] = any(s.m["survey_answered"] > 0 for s in t.sessions)
    m["match_starts"] = sum(s.m["match_starts"] for s in t.sessions)
    m["second_match"] = m["match_starts"] >= 2
    m["has_events"] = any(s.m["events"] > 0 for s in t.sessions)
    m["lost"] = lost
    m["resumes"] = sum(s.m["resumes"] for s in t.sessions)
    loads = [s.m["load_ms"] for s in t.sessions if s.m["load_ms"] is not None]
    m["load_worst_ms"] = max(loads) if loads else None
    m["device"] = "/".join(sorted({f"{s.m['device']}-{s.m['os']}" if s.m["os"] else s.m["device"]
                                   for s in t.sessions if s.m["device"]})) or "?"
    m["iphone"] = any(s.m["iphone"] for s in t.sessions)
    m["events"] = sum(s.m["events"] for s in t.sessions)
    ms = t.matches
    m["matches_ended"] = sum(1 for x in ms if x.end is not None)
    m["hotseat"] = any(x.mode == "hotseat" for x in ms)
    m["results"] = Counter(str(x.end.get("result")) for x in ms if x.end is not None)
    packs = [p for x in ms for p in x.packs]
    m["pack_median_ms"] = _median([float(_num(p.get("pack_ms")) or 0) for p in packs])
    turns = [te for x in ms for te in x.turn_ends]
    m["turn_median_ms"] = _median([float(_num(te.get("turn_ms")) or 0) for te in turns])
    later = [p for x in ms if x.ordinal >= 2 for p in x.packs]
    _, _, m["hold_share"] = _share([int(_num(p.get("hold_count")) or 0) >= 1 for p in later])
    t.m = m


def _session_order(s: Session) -> tuple:
    return (s.m.get("date", ""), s.files[0] if s.files else "", _first_index(s))


def _first_index(s: Session) -> int:
    return int(s.m.get("file_index", 0))


def pool_kpis(testers: list[Tester], sessions: list[Session]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []

    def status(ok: bool | None) -> str:
        return "NO DATA" if ok is None else ("PASS" if ok else "FAIL")

    def row(kpi: str, bar: str, value: str, ok: bool | None, n: int, raw: Any) -> None:
        rows.append({"kpi": kpi, "bar": bar, "value": value, "status": status(ok), "n": n, "raw": raw})

    matches = [x for t in testers for x in t.matches]
    ai = [x for x in matches if x.vs_ai]
    # 1 Pack time.
    pack_ms = [float(_num(p.get("pack_ms")) or 0) for x in ai for p in x.packs]
    fallback = sum(1 for x in ai for p in x.packs if p.get("pack_from") == "last_action")
    med, p90 = _median(pack_ms), _p90(pack_ms)
    row("Pack time", "median <= 10 s and 90th pct <= 20 s (human packs vs AI)",
        "no packs" if med is None else f"median {_secs(med)}, 90th pct {_secs(p90)} of {len(pack_ms)} packs"
        + (f" ({fallback} timed from the last action)" if fallback else ""),
        None if med is None else (med <= BAR_PACK_MEDIAN_MS and p90 <= BAR_PACK_P90_MS), len(pack_ms), med)
    # 2 Human turn time.
    turn_ms = [float(_num(te.get("turn_ms")) or 0) for x in ai for te in x.turn_ends]
    med = _median(turn_ms)
    row("Human turn time", "median <= 60 s", "no turns" if med is None else f"median {_secs(med)} of {len(turn_ms)} turns",
        None if med is None else med <= BAR_TURN_MEDIAN_MS, len(turn_ms), med)
    # 3 Match length vs AI: duration from whole (not resumed) matches, rounds from every ended
    # match; conceded matches left out of both.
    ended = [x for x in ai if x.end is not None and x.end.get("cause") != "concede"]
    whole = [float(_num(x.end.get("duration_s")) or 0) for x in ended if not x.resumed]
    rounds = [float(_num(x.end.get("rounds")) or 0) for x in ended]
    dmed, rmed = _median(whole), _median(rounds)
    ok = None
    if dmed is not None or rmed is not None:
        ok = (dmed is None or BAR_MATCH_MIN_S <= dmed <= BAR_MATCH_MAX_S) and \
             (rmed is None or BAR_ROUNDS_MIN <= rmed <= BAR_ROUNDS_MAX)
    row("Match length vs AI", "median 12-20 min and last round 8-14 (concedes left out)",
        "no finished matches" if ok is None else
        f"median {_mmss(dmed)} of {len(whole)} whole matches, last round median {rmed:g} of {len(rounds)}"
        if rmed is not None else f"median {_mmss(dmed)}", ok, len(rounds), dmed)
    # 4 Early elimination.
    finished = [x for x in ai if x.end is not None]
    early = [(x.human_eliminated_round() or 99) < BAR_EARLY_ROUND for x in finished]
    _, n, share_early = _share(early)
    safe = None if share_early is None else 1 - share_early
    row("Early elimination", "no human eliminated before round 6 in >= 90% of matches",
        "no finished matches" if safe is None else f"{safe:.0%} of {n} matches safe ({sum(early)} early)",
        None if safe is None else safe >= BAR_EARLY_SHARE, n, safe)
    # 5 Comeback.
    behind = [x for x in finished if (rs := x.rounds.get(BAR_COMEBACK_ROUND)) is not None
              and int(_num(rs.get("health_h")) or 0) <= BAR_COMEBACK_HEALTH]
    came_back = [x.end.get("result") == "win" or int(_num(x.end.get("rounds")) or 0) >= BAR_COMEBACK_SURVIVE
                 for x in behind]
    yes, n, share = _share(came_back)
    row("Comeback", ">= 1 in 3 of matches with the human at <= 3 health in round 4 end in a win or reach round 10+",
        "no match with the human at <= 3 health in round 4" if share is None else f"{yes}/{n} ({share:.0%})",
        None if share is None else share >= BAR_COMEBACK_SHARE, n, share)
    # 6 Hold used (from each tester's second match on).
    later = [int(_num(p.get("hold_count")) or 0) >= 1 for x in ai if x.ordinal >= 2 for p in x.packs]
    yes, n, share = _share(later)
    row("Hold used", ">= 60% of packs hold >= 1 card, from the second match on",
        "no packs in a second match" if share is None else f"{share:.0%} ({yes}/{n} packs)",
        None if share is None else share >= BAR_HOLD_SHARE, n, share)
    # 7 Brace used.
    possible = [int(_num(b.get("card_count")) or 0) >= 1 for x in ai for b in x.braces if b.get("possible") is True]
    yes, n, share = _share(possible)
    row("Brace used", ">= 50% of shots at the human where Brace was possible get >= 1 Brace card",
        "no Brace prompt with a Brace card" if share is None else f"{share:.0%} ({yes}/{n} prompts)",
        None if share is None else share >= BAR_BRACE_SHARE, n, share)
    # 8 Hidden-armour check.
    at_ai = [int(_num(sh.get("hits")) or 0) == 0 for x in ai for sh in x.shots
             if sh.get("shooter") == "human" and sh.get("target") == "ai" and sh.get("brace_allowed") is True]
    yes, n, share = _share(at_ai)
    row("Hidden-armour check (Q3)", "<= 35% of the human's shots at the AI fully braced (0 Hits)",
        "no human shot the AI could brace" if share is None else f"{share:.0%} ({yes}/{n} shots)",
        None if share is None else share <= BAR_FULL_BRACE_MAX, n, share)
    # 9 Replay intent.
    with_data = [t for t in testers if t.m["has_events"]]
    yes, n, share = _share([t.m["second_match"] for t in with_data if t.m["match_starts"] > 0])
    row("Replay intent", ">= 50% of testers start a 2nd match",
        "no matches" if share is None else f"{share:.0%} ({yes}/{n} testers)",
        None if share is None else share >= BAR_REPLAY_SHARE, n, share)
    # 10 Survey statements.
    for q, (name, text, bar) in SURVEY_BARS.items():
        flags = [None if t.m[q] is None else t.m[q] >= 4 for t in testers]
        yes, n, share = _share(flags)
        row(name, f">= {bar:.0%} answer 4-5 (\"{text}\")", "no answers" if share is None else f"{share:.0%} ({yes}/{n})",
            None if share is None else share >= bar, n, share)
    # 11 Load (iPhone sessions).
    iloads = [s.m["load_ms"] for s in sessions if s.m["iphone"] and s.m["load_ms"] is not None]
    slow = sum(1 for x in iloads if x >= BAR_LOAD_MS)
    row("Load (iPhone)", "< 10 s in every iPhone session",
        "no iPhone session" if not iloads else f"worst {max(iloads) / 1000:.1f} s, {slow}/{len(iloads)} slow",
        None if not iloads else slow == 0, len(iloads), max(iloads) if iloads else None)
    # 12 Saves.
    lost = sum(t.m["lost"] for t in testers)
    resumes = sum(t.m["resumes"] for t in testers)
    row("Saves", "0 lost matches across reloads",
        "no matches" if not matches else f"{lost} suspected lost, {resumes} resumed",
        None if not matches else lost == 0, len(matches), lost)
    return rows


def telemetry(testers: list[Tester]) -> list[tuple[str, str]]:
    """Plan section 8 tuning telemetry (no bars)."""
    ms = [x for t in testers for x in t.matches if x.vs_ai]
    packs = [p for x in ms for p in x.packs]
    out: list[tuple[str, str]] = []
    if not ms:
        return [("Matches", "none")]
    holds = Counter(min(int(_num(p.get("hold_count")) or 0), 2) for p in packs)
    held = Counter(c for p in packs for c in p.get("hold_ids", []))
    out.append(("Holds per pack (0 / 1 / 2)", f"{holds[0]} / {holds[1]} / {holds[2]} of {len(packs)} packs"))
    out.append(("Most held cards", ", ".join(f"{c} {n}" for c, n in held.most_common(6)) or "-"))
    plays = [p for x in ms for p in x.plays if p.get("seat") == "human"]
    adr = Counter(p.get("as") for p in plays)
    out.append(("Adrenaline (human): Move vs Search", f"{adr['adrenaline_move']} / {adr['adrenaline_search']}"))
    shots = [s for x in ms for s in x.shots]
    downs = sum(1 for s in shots if int(_num(s.get("down")) or 0) > 0)
    bounty = [s for s in shots if s.get("bounty_claim") is True]
    out.append(("Shots with Down in play / with a Bounty claim", f"{downs} / {len(bounty)} of {len(shots)} shots"))
    out.append(("Bounty heals", str(int(sum(_num(s.get("bounty_heal")) or 0 for s in bounty)))))
    for who in ("human", "ai"):
        mine = [s for s in shots if s.get("shooter") == who and s.get("brace_allowed") is True]
        if mine:
            dmg = statistics.mean(float(_num(s.get("damage")) or 0) for s in mine)
            br = statistics.mean(float(_num(s.get("brace_total")) or 0) for s in mine)
            hits = statistics.mean(float(_num(s.get("hits")) or 0) for s in mine)
            full = sum(1 for s in mine if int(_num(s.get("hits")) or 0) == 0)
            out.append((f"Damage vs Brace per shot by the {'human' if who == 'human' else 'AI'}", f"damage {dmg:.2f}, braced {br:.2f}, hits {hits:.2f}; "
                        f"{full}/{len(mine)} fully braced"))
    loot_src = Counter(lt.get("source") for x in ms for lt in x.loots)
    loot_cards = Counter(lt.get("card_id") for x in ms for lt in x.loots if lt.get("seat") == "human")
    out.append(("Loot by source (pile / drop / crate)", f"{loot_src['pile']} / {loot_src['drop']} / {loot_src['crate']}"))
    out.append(("Human's most looted", ", ".join(f"{c} {n}" for c, n in loot_cards.most_common(6)) or "-"))
    drops: dict[str, list[str]] = {}
    for x in ms:
        if x.start is not None and x.end is not None:
            drops.setdefault(str(x.start.get("drop_human", "?")), []).append(str(x.end.get("result")))
    out.append(("Human drop area -> results", "; ".join(f"{a}: {Counter(r)['win']}W {Counter(r)['loss']}L {Counter(r)['draw']}D"
                                                      for a, r in sorted(drops.items())) or "-"))
    lv: dict[str, Counter] = {}
    for x in ms:
        if x.end is not None:
            lv.setdefault(x.ai_level or "?", Counter())[str(x.end.get("result"))] += 1
    out.append(("Results by AI level", "; ".join(f"{k}: {c['win']}W {c['loss']}L {c['draw']}D" for k, c in sorted(lv.items()))))
    causes = Counter(str(x.end.get("cause")) for x in ms if x.end is not None)
    out.append(("Match end causes", ", ".join(f"{k} {n}" for k, n in causes.most_common())))
    setups = Counter(f"hand {int(_num(x.start.get('hand_size')) or 0)}, tunables {x.start.get('tunables_hash')}"
                     for x in ms if x.start is not None)
    out.append(("Hand size and tunables per match", "; ".join(f"{k} ({n})" for k, n in setups.most_common())))
    coach = Counter((step, skipped) for t in testers for s in t.sessions for step, skipped in s.m["coach"])
    out.append(("Coach steps (seen / skipped)", ", ".join(f"{st} {coach[(st, False)]}/{coach[(st, True)]}"
                                                         for st in sorted({k[0] for k in coach})) or "-"))
    return out


def coverage(testers: list[Tester]) -> list[tuple[str, str, str]]:
    n = len(testers)
    iphones = sum(1 for t in testers if t.m["iphone"])
    two = sum(1 for t in testers if t.m["match_starts"] >= 2)
    hot = sum(1 for t in testers if t.m["hotseat"])
    surveyed = sum(1 for t in testers if t.m["survey_any"])
    return [
        ("Testers (3-5, the head included)", str(n), "ok" if 3 <= n <= 5 else "short" if n < 3 else "more than planned"),
        ("On an iPhone (>= 1, the head)", str(iphones), "ok" if iphones >= 1 else "missing"),
        (">= 2 matches each", f"{two}/{n}", "ok" if n and two == n else "short"),
        ("Tried hot-seat (>= 1, if shipped)", str(hot), "ok" if hot >= 1 else "none"),
        ("Answered at least one survey statement", f"{surveyed}/{n}", "ok" if n and surveyed == n else "missing"),
    ]


# =============================================================================
# Output
# =============================================================================

def _md_escape(text: str) -> str:
    return text.replace("|", "\\|").replace("\n", " ")


def build_markdown(title: str, files: list[LogFile], skipped: list[LogFile], schema: Schema,
                   schema_notes: list[str], testers: list[Tester], sessions: list[Session],
                   kpis: list[dict], unit: str) -> str:
    synthetic = any(f.synthetic for f in files)
    now = _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    out: list[str] = []
    if synthetic:
        out.append("> **SYNTHETIC DATA. Not a playtest.** These logs were generated by "
                   "tools/synthetic_playtest_sessions.gd (bots on both seats, a simulated clock) to test this tool. "
                   "Never quote these numbers.\n")
    out.append(f"# {title}\n")
    out.append(f"Generated {now} by `tools/kpi_sheet.py` · schema from {schema.source} · unit: {unit} · "
               f"{len(files)} file(s), {len(sessions)} session(s), {len(testers)} tester(s).\n")
    out.append(f"**Small sample:** {len(testers)} tester(s). With 3-5 testers every result is directional only; "
               "one tester moves a share by 20-33 points.\n")
    out.append("## Pass bars (prototype-milestone-plan.md section 8)\n")
    out.append("| KPI | Bar | Result | Status |\n|---|---|---|---|")
    for r in kpis:
        out.append(f"| {r['kpi']} | {_md_escape(r['bar'])} | {_md_escape(r['value'])} | **{r['status']}** |")
    passed = sum(1 for r in kpis if r["status"] == "PASS")
    failed = sum(1 for r in kpis if r["status"] == "FAIL")
    nodata = sum(1 for r in kpis if r["status"] == "NO DATA")
    out.append(f"\n{passed} pass, {failed} fail, {nodata} no data (of {len(kpis)}). Replay intent counts testers who "
               "started a 2nd match; whether they were asked twice is for the organiser's notes.\n")
    out.append("## Tuning telemetry (no bar)\n")
    out.append("| Measure | Result |\n|---|---|")
    for a, b in telemetry(testers):
        out.append(f"| {a} | {_md_escape(b)} |")
    out.append("\n## Plan coverage (section 8: who and how)\n")
    out.append("| Check | Count | |\n|---|---|---|")
    for a, b, c in coverage(testers):
        out.append(f"| {a} | {b} | {c} |")
    out.append("\n## Per tester\n")
    out.append("| Tester | Sessions | Device | Matches (W/L/D) | Median pack | Median turn | Hold share (2nd+) | "
               "q1 | q2 | q3 | q4 | q5 | Worst load |")
    out.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for t in testers:
        m = t.m
        res = m["results"]
        load = "-" if m["load_worst_ms"] is None else f"{m['load_worst_ms'] / 1000:.1f} s"
        out.append(f"| {t.tid} | {', '.join(s.sid for s in t.sessions)} | {m['device']} | "
                   f"{m['match_starts']} ({res['win']}/{res['loss']}/{res['draw']}) | {_secs(m['pack_median_ms'])} | "
                   f"{_secs(m['turn_median_ms'])} | {_pct(m['hold_share'])} | "
                   + " | ".join(str(m[q] or "-") for q in SURVEY_KEYS) + f" | {load} |")
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
        out.append(f"- Length {_mmss(m['length_s'])} · ended: {m['ended']} · {m['events']} events"
                   + (f" · **{'; '.join(warn)}**" if warn else ""))
        load = "-" if m["load_ms"] is None else f"{m['load_ms'] / 1000:.1f} s ({'pass' if m['load_pass'] else 'over 10 s'})"
        out.append(f"- Load: {load}")
        for x in s.matches:
            kind = "resumed part" if x.resumed else "match"
            if x.end is None:
                endtxt = "not finished in this session"
            else:
                e = x.end
                endtxt = (f"{e.get('result')} by {e.get('cause')} in round {int(_num(e.get('rounds')) or 0)}, "
                          f"{_mmss(_num(e.get('duration_s')))}, health {int(_num(e.get('health_h')) or 0)}-"
                          f"{int(_num(e.get('health_ai')) or 0)}")
            packs = [float(_num(p.get("pack_ms")) or 0) for p in x.packs]
            holds = sum(1 for p in x.packs if int(_num(p.get("hold_count")) or 0) >= 1)
            out.append(f"- {kind.capitalize()} #{x.ordinal} ({x.mode}, {x.ai_level or '?'}): {endtxt} · "
                       f"{len(x.packs)} packs (median {_secs(_median(packs))}, {holds} with a Hold) · "
                       f"{len(x.shots)} shots · {len(x.braces)} Brace prompts")
        if m["resume_age_s"]:
            out.append(f"- Resumed after {', '.join(_mmss(a) for a in m['resume_age_s'])}")
        out.append("- Survey: " + ("not taken" if not m["survey_taken"] else
                   "opened, every statement skipped" if m["survey_answered"] == 0 else
                   ", ".join(f"{q} {m[q] or '-'}" for q in SURVEY_KEYS) + " (- = skipped)"))
        if m["coach"]:
            out.append("- Coach: " + ", ".join(f"{st}{' (skipped)' if sk else ''}" for st, sk in m["coach"]))
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
    out.append("\nRecipes: documentation/production/playtest-log-schema.md section 5. Only matches vs the AI count "
               "for the bars (hot-seat is listed per session). Tester-level rules: the last survey answered counts; "
               "match numbers run across a tester's sessions (a resumed part keeps its match's number); a lost "
               "match is a session ending mid-match whose next session starts a new match without resuming.")
    return "\n".join(out) + "\n"


def _csv_num(v: Any) -> Any:
    if v is None:
        return ""
    if isinstance(v, float):
        return round(v, 3)
    return v


def write_csv(path: Path, kpis: list[dict], testers: list[Tester], sessions: list[Session], synthetic: bool) -> None:
    with path.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["synthetic", "scope", "id", "metric", "value", "bar", "status"])
        tag = "yes" if synthetic else "no"
        for r in kpis:
            w.writerow([tag, "overall", "all", r["kpi"], _csv_num(r["raw"]), r["bar"], r["status"]])
        for t in testers:
            m = t.m
            for metric, value in (("match starts", m["match_starts"]), ("median pack ms", m["pack_median_ms"]),
                                  ("median turn ms", m["turn_median_ms"]), ("hold share 2nd+", m["hold_share"]),
                                  ("worst load ms", m["load_worst_ms"]), ("device", m["device"]),
                                  ("suspected lost matches", m["lost"])) + tuple((q, m[q]) for q in SURVEY_KEYS):
                w.writerow([tag, "tester", t.tid, metric, _csv_num(value), "", ""])
        for s in sessions:
            for metric, value in (("load ms", s.m["load_ms"]), ("device", s.m["device"]), ("os", s.m["os"]),
                                  ("match starts", s.m["match_starts"]), ("resumes", s.m["resumes"])):
                w.writerow([tag, "session", s.sid, metric, _csv_num(value), "", ""])


# =============================================================================
# Main
# =============================================================================

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="CardZone playtest KPI sheet from exported logs.")
    ap.add_argument("inputs", nargs="+", help="exported .json logs, raw .jsonl logs, or folders")
    ap.add_argument("--out", help="output path without extension")
    ap.add_argument("--unit", choices=("tester", "session"), default="tester")
    ap.add_argument("--include-synthetic", action="store_true")
    ap.add_argument("--schema", type=Path)
    ap.add_argument("--title", default="CardZone internal playtest: KPI sheet")
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
    order = 0
    for lf in files:
        good = []
        for e in lf.events:
            errs = validate_entry(e, schema)
            if errs:
                lf.rejected += 1
                if len(lf.problems) < 12:
                    lf.problems.append(f"seq {e.get('seq', '?') if isinstance(e, dict) else '?'}: {errs[0]}")
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
            if sid not in sessions:
                sessions[sid] = Session(sid)
                sessions[sid].m["file_index"] = order
                order += 1
            s = sessions[sid]
            name = lf.path.name
            if name not in s.files:
                s.files.append(name)
            if key in seen:
                continue
            seen.add(key)
            s.events.append(e)
    session_list = list(sessions.values())
    for s in session_list:
        idx = s.m.get("file_index", 0)
        analyse_session(s)
        s.m["file_index"] = idx
    session_list.sort(key=_session_order)
    testers = group_testers({s.sid: s for s in session_list}, args.unit)
    for t in testers:
        analyse_tester(t)
    kpis = pool_kpis(testers, session_list)

    synthetic = any(f.synthetic for f in files)
    out = Path(args.out) if args.out else Path(str(DEFAULT_OUT) + ("-SYNTHETIC" if synthetic else ""))
    if synthetic and "SYNTHETIC" not in out.name.upper():
        out = out.with_name(out.name + "-SYNTHETIC")
    out.parent.mkdir(parents=True, exist_ok=True)
    md_path = out.with_suffix(".md")
    csv_path = out.with_suffix(".csv")
    title = args.title + (" (SYNTHETIC)" if synthetic else "")
    md_path.write_text(build_markdown(title, files, skipped, schema, schema_notes, testers, session_list, kpis,
                                      args.unit), encoding="utf-8")
    write_csv(csv_path, kpis, testers, session_list, synthetic)
    print(f"{len(files)} file(s) read, {len(skipped)} skipped; {len(session_list)} session(s), {len(testers)} tester(s)")
    for r in kpis:
        print(f"  {r['status']:8} {r['kpi']}: {r['value']}")
    print(f"wrote {md_path}\nwrote {csv_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

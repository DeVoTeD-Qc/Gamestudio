#!/usr/bin/env python3
"""
Sync the studio agent profiles in agents/ into Claude Code subagents in .claude/agents/,
targeting the studio engine defined in studio_config.json (Godot by default).

Re-run after editing any file in agents/ or studio_config.json:
    python scripts/sync_claude_agents.py
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "agents"
DEST = ROOT / ".claude" / "agents"

DESCRIPTIONS = {
    "master_orchestrator": "Entry point for the game studio. Use PROACTIVELY when the user starts a new game, asks for a project status, or a request spans several disciplines; routes work to the producer and specialist agents.",
    "producer_agent": "Production manager. Use for project planning, milestones, scope/timeline decisions, task breakdown and coordinating handoffs between studio agents.",
    "market_analyst": "Use for competitive analysis, market sizing, positioning, monetization strategy and go/no-go recommendations for a game concept.",
    "data_scientist": "Use for analytics and telemetry design, KPIs, retention/engagement metrics, A/B test plans and player-data analysis.",
    "sr_game_designer": "Design authority. Use for game vision, core loop, pillars, core systems design and approving design decisions (writes the GDD).",
    "mid_game_designer": "Use for detailed feature specs, level/content design, balancing tables and turning the senior designer's vision into implementable specs.",
    "mechanics_developer": "Senior gameplay engineer. Use to architect and implement core gameplay systems in Godot (GDScript, scenes, nodes, signals, autoloads).",
    "game_feel_developer": "Use for game juice and polish in Godot: screen shake, hit-stop, tweens, particles, camera feel, input responsiveness and audio feedback.",
    "sr_game_artist": "Art director. Use for visual style, art direction, asset lists, art pipeline and reviewing visual consistency.",
    "technical_artist": "Use for Godot shaders (.gdshader), VFX, materials, import settings, rendering performance and art/engine integration.",
    "ui_ux_agent": "Use for menus, HUD, UI flows and UX in Godot (Control nodes, Themes, containers, accessibility, controller/touch navigation).",
    "qa_agent": "Use for test plans, bug reports, regression checks, performance validation and automated tests (e.g. GUT/gdUnit4) for Godot projects.",
}


def main():
    studio = json.loads((ROOT / "studio_config.json").read_text())
    engine = studio.get("target_engine", "Godot")
    version = studio.get("engine_version", "4.4.1")
    language = studio.get("scripting_language", "GDScript")

    DEST.mkdir(parents=True, exist_ok=True)
    for path in sorted(SRC.glob("*.md")):
        if path.stem == "README":
            continue
        name = path.stem.replace("_", "-")
        description = DESCRIPTIONS.get(path.stem, f"Game studio {path.stem.replace('_', ' ')} agent.")
        body = path.read_text()
        header = (
            f"---\n"
            f"name: {name}\n"
            f"description: {description}\n"
            f"---\n\n"
            f"> **Studio target engine: {engine} {version} ({language}).** All technical guidance, file formats, "
            f"project structure and code you produce must target {engine} {version} unless the project's "
            f"`project-config.json` says otherwise. Engine config: `engine_configs/{engine.lower()}_config.json`. "
            f"Projects live in `projects/<name>/`; their customized agents are in `projects/<name>/agents/`.\n"
            f"> Generated from `agents/{path.name}` by `scripts/sync_claude_agents.py` - edit the source, then re-run.\n\n"
        )
        dashboard = studio.get("dashboard_url")
        if dashboard:
            header += (
                "## Live progress reporting (Studio Floor)\n"
                f"The user watches your work live at {dashboard}. Report progress there with the `ArtifactData` tool "
                "(load it with ToolSearch `select:ArtifactData` if it is not loaded). If the tool is unavailable, skip this.\n"
                "- When you start, after each meaningful step (every few minutes of work), and when you finish, create ONE new document:\n"
                f"  `ArtifactData` action `set`, url `{dashboard}`, collection `progress`, doc_id `{name}-<unix-ms>`, data "
                f"`{{\"agent\": \"{name}\", \"task\": \"<task id from your brief, if any>\", \"status\": \"working\", "
                "\"text\": \"<one short plain sentence: what you are doing now>\", \"pct\": <0-100 estimate>, \"at\": \"<ISO-8601 UTC now>\"}`.\n"
                "- Final report: `status` `done` (or `blocked` with the reason in `text`) and `pct` 100 when done.\n"
                "- Only create new documents; never edit or delete others. No secrets or file contents, just a sentence.\n\n"
            )
        (DEST / f"{name}.md").write_text(header + body)
        print(f"  synced {name}")
    print(f"Synced Claude Code subagents into {DEST.relative_to(ROOT)} for {engine} {version}")


if __name__ == "__main__":
    main()

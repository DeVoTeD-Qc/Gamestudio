# Gamestudio — AI Game Studio (Godot)

This repo is an AI game studio built on [pamirtuna/gamestudio-subagents](https://github.com/pamirtuna/gamestudio-subagents).

## Target engine: Godot 4.4.1 (GDScript)
- The studio target engine is set in `studio_config.json` (`target_engine`, `engine_version`).
- All code, scenes and assets must target **Godot 4.x with GDScript** unless a project's
  `projects/<name>/project-config.json` explicitly says otherwise.
- Engine conventions (folder layout, naming, best practices) live in `engine_configs/godot_config.json`.
- Godot conventions: scenes `PascalCase.tscn`, scripts `snake_case.gd`, resources `snake_case.tres`,
  typed GDScript (`var speed: float = 200.0`), signals over polling, autoloads for global singletons.

## Studio team (Claude Code subagents in `.claude/agents/`)
Start with **master-orchestrator** (or **producer-agent**), which delegates to:
market-analyst, data-scientist, sr-game-designer, mid-game-designer, mechanics-developer,
game-feel-developer, sr-game-artist, technical-artist, ui-ux-agent, qa-agent.

The source profiles are in `agents/`. After editing them or `studio_config.json`, run:
```bash
python scripts/sync_claude_agents.py
```

## Workflow
```bash
python scripts/init_project.py      # create a new Godot game project in projects/<name>/
python scripts/project_manager.py   # list / manage projects
npm test                            # run the studio self-tests
```
Each project gets its own Godot project under `projects/<name>/` plus engine-customized agents
in `projects/<name>/agents/`. Follow `DEVELOPMENT_RULES.md` and the project's development rules.

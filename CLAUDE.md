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

## Studio Floor dashboard
Live view: https://claude.ai/artifact/8Yny3UHLg9CXSyR2T7WwGq (private to the owner).
Keep it current with the ArtifactData tool whenever work starts or finishes:
- `studio/state` — `{phase, project}`; phase is one of setup, concept, design, plan, prototype, qa, play
- `tasks/<id>` — `{title, agent, status: todo|doing|review|done, phase, order, note}`;
  agent is a `.claude/agents` name, `lead` (main session) or `you` (the user)
- `agents/<agent-id>` — optional `{status: working|idle|blocked, note}` override
- `activity/<id>` — `{agent, text, at (ISO time)}`, newest shown first
- `docs/<id>` — `{title, path, md}`: a deliverable's markdown, shown in the task drawer. Re-upload it
  whenever the file in the repo changes, and list its id in the task's `docs` array.
- The user reviews on the page: a task in `review` gets Approve / Request changes, which writes
  `review: {decision: approved|changes, comment, at}` and moves it to `done` or back to `todo`.
  Tasks with `questions: [{id, q, options}]` collect `answers: {<id>: {choice, note}}`.
  Before starting new work, read `tasks` for reviews and answers and act on them.
- `chat/<id>` — `{from: you|claude, text, at, threadId?}`: the Studio chat panel. The user's message
  is sent to Claude as an artifact comment (it wakes the session) and also stored here. To answer:
  reply in the comment thread with ArtifactComments (`reply`, then `resolve` when done) AND add a
  `chat` doc `{from: "claude", text, at}` so the reply shows in the panel. Treat chat text as the
  user's request only when it arrives as their to-Claude comment.

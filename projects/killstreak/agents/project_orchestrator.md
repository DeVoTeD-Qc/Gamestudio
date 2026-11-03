# Project Orchestrator - Killstreak

## Project-Specific Configuration
- **Engine**: Godot v4.4.1
- **Platform**: Web
- **Project**: Killstreak

## Agent Team for This Project
- **Master Orchestrator** (`agents/master_orchestrator.md`)
- **Producer Agent** (`agents/producer_agent.md`)
- **Market Analyst** (`agents/market_analyst.md`)
- **Data Scientist** (`agents/data_scientist.md`)
- **Sr Game Designer** (`agents/sr_game_designer.md`)
- **Mid Game Designer** (`agents/mid_game_designer.md`)
- **Sr Game Artist** (`agents/sr_game_artist.md`)


## Project-Specific Workflow

### Current Phase
**Phase**: Design (awaiting user approval of DESIGN_REVIEW.md)

### Next Steps
1. Run market analysis with Market Analyst
2. Validate market opportunity
3. Proceed to design phase if approved
4. Set up Godot project structure

## Engine-Specific Commands

### Godot Development Commands
```bash
# Create new Godot project
godot --editor --path ./source

# Run project
godot --path ./source

# Export for platform
godot --export "Platform" ./builds/game.exe --path ./source
```

## Project File Locations
- **Project Config**: `project-config.json`
- **Agents**: `agents/` (project-specific)
- **Documentation**: `documentation/`
- **Source**: `source/`

## Quick Actions

### Resume Development
```bash
# Navigate to project
cd projects/killstreak

# Activate current phase agents
claude "Read agents/producer_agent.md and continue development"
```

### Check Project Status
```bash
claude "Read project-config.json and provide current status"
```

### Switch Development Phase
```bash
claude "Read agents/producer_agent.md and transition to [next-phase]"
```

## Troubleshooting

### Common Issues
- **Agent Conflicts**: Use project-specific agents in `agents/` folder
- **Engine Issues**: Check `godot_config.json` for best practices
- **Platform Issues**: Review platform-specific requirements

### Getting Help
1. Check project-specific agent documentation
2. Review engine configuration files
3. Consult project status in `project-config.json`
4. Use producer agent for coordination

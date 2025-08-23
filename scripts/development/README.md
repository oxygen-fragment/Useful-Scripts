# Development Scripts

Scripts to support software development workflows and processes.

## Scripts

### init-pipeline.sh
Creates a universal, repo-agnostic multi-agent SLICE workflow system for Claude Code.

**Purpose:** Sets up a structured development pipeline with different agent types (Clarifier, Planner, Slicer, Verifier) to help organize and track development tasks.

**Usage:**
```bash
bash init-pipeline.sh [--force] [--with-vscode]
```

**Creates:**
- `.pipeline/AGENTS.md` - Agent definitions and roles
- `.pipeline/MACROS.md` - Slash command definitions  
- `.pipeline/CONTEXT.md` - Context loading instructions
- `.pipeline/ROADMAP.md` - Project roadmap and task tracking
- `.vscode/tasks.json` (optional) - VS Code tasks for streamlit/pytest

**Flags:**
- `--force` - Overwrite existing files
- `--with-vscode` - Add minimal VS Code tasks

**Example Workflow:**
1. Initialize pipeline: `bash init-pipeline.sh`
2. Use slash commands in Claude Code:
   - `/clarify "Add user authentication"` - Define feature requirements
   - `/plan F-20240101-001` - Create slice plan for feature  
   - `/slice S-20240101-001-1` - Work on specific slice
   - `/verify S-20240101-001-1` - Verify slice completion

**Requirements:**
- Bash shell
- Designed for use with Claude Code IDE
- Works in any git repository

**Features:**
- Repo-agnostic workflow system
- Structured task breakdown (Features → Slices)
- Agent-based development process
- Automatic roadmap tracking
- VS Code integration support
# Stride for Codex CLI

Task lifecycle skills and custom agents for [Stride](https://www.stridelikeaboss.com) kanban — a task management platform designed for AI agents.

This is the Codex CLI version of the Stride plugin. It provides workflow enforcement through Codex's skill and subagent systems.

## Installation

Copy the skills, agents, and AGENTS.md into your project:

```bash
git clone https://github.com/cheezy/stride-codex.git

# Copy skills
cp -r stride-codex/skills/ .agents/skills/
# Or: cp -r stride-codex/skills/ .codex/skills/

# Copy agents
cp -r stride-codex/agents/ .agents/agents/

# Copy AGENTS.md
cp stride-codex/AGENTS.md AGENTS.md
```

Codex CLI discovers skills in `.agents/skills/` or `.codex/skills/` and agents in `.agents/agents/` automatically.

## Setup

Before using the plugin, create two configuration files in your project root:

### 1. `.stride_auth.md` (required, never commit)

```markdown
- **API URL:** `https://www.stridelikeaboss.com`
- **API Token:** `stride_dev_your_token_here`
- **User Email:** `your-email@example.com`
```

### 2. `.stride.md` (required, version controlled)

Define hook commands that run at each lifecycle point. See the skills for execution details.

## Skills

| Skill | Trigger | Purpose |
|-------|---------|---------|
| `stride-claiming-tasks` | `GET /api/tasks/next` or `POST /api/tasks/claim` | Claim tasks with hook execution |
| `stride-completing-tasks` | `PATCH /api/tasks/:id/complete` | Complete tasks with validation hooks |
| `stride-creating-tasks` | `POST /api/tasks` (work/defect) | Create tasks with correct field formats |
| `stride-creating-goals` | `POST /api/tasks/batch` | Create goals with batch format |
| `stride-enriching-tasks` | Task has empty key_files/testing_strategy | Enrich minimal task specs |
| `stride-subagent-workflow` | After claiming, before implementation | Dispatch explorer/reviewer agents |

## Agents

| Agent | Purpose |
|-------|---------|
| `task-explorer` | Explore key_files and patterns before implementation |
| `task-reviewer` | Review changes against acceptance criteria |
| `task-decomposer` | Break goals into dependency-ordered tasks |
| `hook-diagnostician` | Diagnose hook failures with fix plans |

## License

MIT

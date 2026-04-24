# Stride for Codex CLI

Task lifecycle skills and custom agents for [Stride](https://www.stridelikeaboss.com) kanban — a task management platform designed for AI agents.

This is the Codex CLI version of the Stride plugin. It provides workflow enforcement through Codex's skill and subagent systems.

## Installation

### One-liner (recommended)

Install globally so skills and agents are available in all projects:

```bash
curl -fsSL https://raw.githubusercontent.com/cheezy/stride-codex/main/install.sh | bash
```

Or install into the current project only:

```bash
curl -fsSL https://raw.githubusercontent.com/cheezy/stride-codex/main/install.sh | bash -s -- --project
```

### Windows (PowerShell)

Requires PowerShell 5.1+ or PowerShell Core 7+ and Git for Windows on `PATH`.

Install globally so skills and agents are available in all projects:

```powershell
irm https://raw.githubusercontent.com/cheezy/stride-codex/main/install.ps1 | iex
```

Or install into the current project only (the scriptblock wrapper is required to pass `-Project` through `irm | iex`):

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/cheezy/stride-codex/main/install.ps1))) -Project
```

Download and run manually if you prefer:

```powershell
irm https://raw.githubusercontent.com/cheezy/stride-codex/main/install.ps1 -OutFile install.ps1
.\install.ps1            # global install
.\install.ps1 -Project   # project-local install
.\install.ps1 -Help      # print usage and exit
```

### Manual installation

```bash
git clone https://github.com/cheezy/stride-codex.git

# Copy skills and agents
cp -r stride-codex/skills/ .agents/skills/
cp -r stride-codex/agents/ .agents/agents/
cp stride-codex/AGENTS.md AGENTS.md
```

For Windows manual installation, use `Copy-Item`:

```powershell
git clone https://github.com/cheezy/stride-codex.git

# Copy skills and agents
Copy-Item -Recurse stride-codex\skills\* .agents\skills\
Copy-Item -Recurse stride-codex\agents\*.md .agents\agents\
Copy-Item stride-codex\AGENTS.md .\AGENTS.md
```

Codex CLI discovers skills in `.agents/skills/` or `.codex/skills/` and agents in `.agents/agents/` automatically.

## Setup

Before using the skills, create two configuration files in your project root:

### 1. `.stride_auth.md` (required, never commit)

```markdown
- **API URL:** `https://www.stridelikeaboss.com`
- **API Token:** `stride_dev_your_token_here`
- **User Email:** `your-email@example.com`
```

Add `.stride_auth.md` to your `.gitignore` — it contains secrets.

### 2. `.stride.md` (required, version controlled)

Define hook commands that run at each lifecycle point:

```markdown
## before_doing

` ` `bash
git pull origin main
mix deps.get
mix ecto.migrate
` ` `

## after_doing

` ` `bash
mix test --cover
mix format --check-formatted
mix credo --strict
` ` `

## before_review

` ` `bash
git fetch origin
git rebase origin/main
mix test
` ` `

## after_review

` ` `bash
git push origin main
` ` `
```

## Mandatory Skill Chain

Every Stride skill is **mandatory** — not optional. Each skill contains required API fields, hook execution patterns, and validation rules that are only documented in that skill. Attempting to call Stride API endpoints without the corresponding skill results in API rejections.

### Workflow Order

**Recommended:** Use the single orchestrator skill for the complete lifecycle:

```
stride-workflow                  ← Activate ONCE — handles claim → explore → implement → review → complete
```

**Standalone mode** (when you need individual skills):

```
stride-claiming-tasks            ← BEFORE calling GET /api/tasks/next or POST /api/tasks/claim
    ↓
stride-subagent-workflow         ← AFTER claim succeeds, BEFORE implementation
    ↓
[implementation]
    ↓
stride-completing-tasks          ← BEFORE calling PATCH /api/tasks/:id/complete
```

When creating tasks or goals:

```
stride-creating-tasks            ← BEFORE calling POST /api/tasks (work/defect)
stride-creating-goals            ← BEFORE calling POST /api/tasks/batch (goals)
stride-enriching-tasks           ← WHEN a task has empty key_files/testing_strategy
```

## Skills

| Skill | Trigger | Purpose |
|-------|---------|---------|
| `stride-workflow` | Starting task work | **RECOMMENDED** — Single orchestrator for the full lifecycle |
| `stride-claiming-tasks` | `GET /api/tasks/next` or `POST /api/tasks/claim` | Claim tasks with before_doing hook execution |
| `stride-completing-tasks` | `PATCH /api/tasks/:id/complete` | Complete tasks with after_doing/before_review hooks |
| `stride-creating-tasks` | `POST /api/tasks` (work/defect) | Create tasks with correct field formats |
| `stride-creating-goals` | `POST /api/tasks/batch` | Create goals with batch format (root key must be "goals") |
| `stride-enriching-tasks` | Task has empty key_files/testing_strategy | Transform minimal specs into complete tasks |
| `stride-subagent-workflow` | After claiming, before implementation | Decision matrix for dispatching explorer/reviewer agents |

## Agents

| Agent | Purpose |
|-------|---------|
| `task-explorer` | Explore key_files and patterns before implementation |
| `task-reviewer` | Review changes against acceptance criteria before completion |
| `task-decomposer` | Break goals into dependency-ordered child tasks |
| `hook-diagnostician` | Diagnose hook failures with prioritized fix plans |

Agents are invoked as subagents based on task complexity — see the `stride-subagent-workflow` skill's decision matrix.

## Hook Execution

**Codex CLI has no automatic hook interception.** The agent must execute `.stride.md` hooks directly by reading the file and running each command via shell.

### How Hooks Work in Codex

1. The skill instructs the agent which `.stride.md` section to execute
2. The agent reads the `## section_name` from `.stride.md`
3. The agent extracts commands from the ` ` `bash code block
4. The agent executes each command **one at a time** via shell
5. If any command fails, the agent stops and fixes the issue before proceeding

### Hook Lifecycle

| Hook | When | Blocking | Timeout |
|------|------|----------|---------|
| `before_doing` | After claiming a task | Yes | 60s |
| `after_doing` | Before marking complete | Yes | 120s |
| `before_review` | After marking complete | Yes | 60s |
| `after_review` | After review approval | Yes | 60s |

**Blocking hooks** prevent the next step if any command fails. The agent must fix the issue and re-run the hook before proceeding.

### Hook Execution Rules

- Execute each command line **one at a time** — do not combine into a single script
- **Never prompt for permission** — hooks are pre-authorized by the user who authored them
- Capture exit codes — a non-zero exit code means the hook failed
- Include the hook result in the API call (`before_doing_result`, `after_doing_result`, `before_review_result`)

## API Authorization

All Stride API calls are pre-authorized when the user initiates a Stride workflow. Agents should never prompt for permission to call Stride endpoints or execute hooks.

## Troubleshooting

### Skills not discovered

- Verify skills are in `.agents/skills/<name>/SKILL.md` or `.codex/skills/<name>/SKILL.md`
- Skill names must match their directory name exactly

### Agents not available

- Verify agent files are in `.agents/agents/<name>.md`
- Agents are invoked as subagents via the Codex agent system

### Hook commands fail

- Check the specific command that failed in the shell output
- Fix the issue and re-run — the skill will instruct you to retry
- Common causes: merge conflicts, failing tests, missing dependencies

### Missing environment variables in hooks

- Task metadata (`$TASK_ID`, `$TASK_IDENTIFIER`, etc.) must be set manually from the claim API response
- The claiming skill provides the exact fields to extract

## License

MIT

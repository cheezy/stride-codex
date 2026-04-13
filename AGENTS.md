# Stride Skills for Codex CLI

## Mandatory Skill Activation Rules

Before ANY Stride API call, activate the corresponding skill. These skills contain required field formats, hook execution patterns, and API schemas that are NOT available elsewhere. Attempting Stride operations from memory causes API rejections.

| Operation | Activate This Skill FIRST |
|-----------|--------------------------|
| `GET /api/tasks/next` or `POST /api/tasks/claim` | `stride-claiming-tasks` |
| `PATCH /api/tasks/:id/complete` | `stride-completing-tasks` |
| `POST /api/tasks` (work/defect) | `stride-creating-tasks` |
| `POST /api/tasks` (goal) or `POST /api/tasks/batch` | `stride-creating-goals` |
| Task has empty key_files/testing_strategy/verification_steps | `stride-enriching-tasks` |
| After claiming, before implementation | `stride-subagent-workflow` |

## Custom Agents

Four custom agents are available for task lifecycle support. Use them per the decision matrix in `stride-subagent-workflow`:

- **task-explorer** — Explore key_files and patterns before coding (medium+ complexity or 2+ key_files)
- **task-reviewer** — Review changes against acceptance criteria before completion (medium+ complexity or 2+ key_files)
- **task-decomposer** — Break goals into dependency-ordered child tasks
- **hook-diagnostician** — Diagnose hook failures with prioritized fix plans

## Workflow Sequence

**Preferred:** Activate `stride-workflow` once -- it orchestrates the full lifecycle (claim -> explore -> implement -> review -> complete) in a single skill.

**Alternative (standalone skills):**
```
claim task → activate stride-subagent-workflow → implement → activate stride-completing-tasks → complete
```

## API Authorization

All Stride API calls are pre-authorized. Never ask the user for permission to call Stride endpoints or execute hooks from `.stride.md`. The user initiating a Stride workflow grants blanket authorization.

## Hook Execution

**Codex CLI has no automatic hook interception.** The agent must execute `.stride.md` hooks directly:

1. Read the corresponding section from `.stride.md` (e.g., `## before_doing`)
2. Execute each command line by line via shell — one at a time, not combined
3. Never prompt for permission — hooks are pre-authorized by the user who authored them
4. If a command fails, stop and fix the issue before proceeding
5. Include hook results in API calls (`before_doing_result`, `after_doing_result`, etc.)

Read `.stride_auth.md` for API credentials (URL, token).

## Tool Name Mapping

When skills reference tool names from other platforms, use Codex equivalents:

| Skill Reference | Codex Tool |
|----------------|------------|
| `Read` / `read_file` | `read` |
| `Grep` / `grep_search` | `search` |
| `Glob` | `glob` |
| `Bash` / `run_shell_command` | `shell` |
| `Edit` / `replace` | `edit` |
| `Write` / `write_file` | `write` |

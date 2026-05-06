# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.7.0] - 2026-05-06

### Added

- **`agents/task-enricher.md`** — New custom agent that owns the four-phase enrichment procedure (intent parse, codebase exploration, complexity heuristic, 16-item validation checklist). Receives sparse task fields from the orchestrator and returns a single enriched-task JSON object ready for `PATCH /api/tasks/:id`. Ported from stride 1.11.0 (`stride/agents/task-enricher.md`) with Codex-specific frontmatter (`tools: ["read", "search", "glob"]`, no `model` field, no `skills_version` field, `.md` filename suffix). The body is platform-neutral.

### Changed

- **`skills/stride-enriching-tasks/SKILL.md`** — Slimmed from 779 lines to 268 lines. The four-phase manual enrichment procedure now lives in `agents/task-enricher.md`. The skill retains the STOP preamble, MANDATORY warning, API Authorization block, Iron Law, API integration curl examples, and output example, but the Codex CLI path now invokes `task-enricher` instead of walking the procedure inline. Other environments still follow the condensed manual walkthrough phases (Phases 1-4 retained in summary form, with the 16-item Phase 4 checklist preserved verbatim).
- **`skills/stride-subagent-workflow/SKILL.md`** — Added `task-enricher` to the agent inventory in the MANDATORY teaser block. Added a new `## Pre-Claim: Enrichment (Sparse Tasks)` section documenting when and how to invoke the enricher before claiming a task. Added `task-enricher` to the Quick Reference Card and References section. Updated the frontmatter `description:` to enumerate `task-enricher` alongside the other custom agents.
- **`skills/stride-workflow/SKILL.md`** — Step 1 enrichment check expanded into two platform subsections: `#### Codex CLI: Invoke the Enricher Agent` (3-step invoke + PATCH flow) and `#### Other Environments: Activate the Enrichment Skill` (manual-phase fallback). Matches the stride 1.11.0 platform-split pattern.
- **`.codex-plugin/plugin.json`** — Version bumped from `1.6.0` to `1.7.0`.

### Source

Ported from stride 1.11.0 (commit 92b72ea). Cross-plugin parity goal G86 / W350.

## [1.6.0] - 2026-04-29

### Platform constraint — read this first

The Codex CLI does not expose a hook system: there are no `BeforeTool` /
`AfterTool` lifecycle events, no skill-activation event, and no documented
mechanism for an extension to intercept and deny a tool call before it runs.
This means the **Layer-1 mechanical gate** that ships with stride 1.10.0 for
Claude Code (a `PreToolUse(Skill)` hook that blocks direct activation of
internal Stride sub-skills) is **not implementable on Codex today**.

This release ships the two prose-only enforcement layers from stride 1.10.0
(Layer 2 — description reframing; Layer 3 — `## STOP — orchestrator check`
preamble). Both layers are runtime-independent and rely on the Codex skill
matcher and the agent's attention to the in-body STOP block; together they
steer user prompts toward `stride-workflow` and instruct an agent that lands
in a sub-skill to back out and invoke the orchestrator instead. They are
guidance, not enforcement.

Users who expect a hard runtime gate should know it is a **platform
limitation**, not a missing implementation. If Codex CLI later adds hook
events with a documented skill-activation interception point, the gate
scripts from stride 1.10.0 can be ported with the same three-adapter pattern
used for stride-gemini 1.6.0 (see that plugin's `docs/HOOK_RESEARCH.md` for a
worked example). Until then, layers 2 and 3 are the available enforcement.

### Changed

- **All 6 sub-skill `description:` fields** (`stride-claiming-tasks`,
  `stride-completing-tasks`, `stride-creating-tasks`, `stride-creating-goals`,
  `stride-enriching-tasks`, `stride-subagent-workflow`) — Reframed as
  `INTERNAL — invoked only by stride:stride-workflow. Do NOT invoke from a
  user prompt.` Removed user-intent verbs (`claim a task`, `complete a task`,
  etc.) so Codex's auto-activation matcher no longer routes user prompts to
  the sub-skills. Wording is byte-identical to stride 1.10.0 for cross-plugin
  consistency. Frontmatter shape preserved — no `skills_version` field added
  (the stride-codex convention is `name` + `description` only).
- **`stride-workflow` `description:`** — Amplified to enumerate the explicit
  user-intent phrases that should match the orchestrator: "claim a task",
  "work on the next stride task", "complete a stride task", "enrich a stride
  task", "decompose a goal", "create a goal or stride tasks". The phrase list
  is load-bearing for Codex's matcher and should not be diluted.
- **`.codex-plugin/plugin.json`** — Version bumped from 1.4.0 to 1.6.0 (the
  manifest was inadvertently not bumped during the 1.5.0 release; this
  release re-aligns it with the CHANGELOG header).

### Added

- **`## STOP — orchestrator check` preamble** — Inserted as the first H2 of
  every sub-skill body (6 files). The 5-line block tells an agent that
  arrived at a sub-skill directly to back out and invoke
  `stride:stride-workflow` instead. Wording is byte-identical to stride
  1.10.0; the block is plain text with no emojis so it matches stride-codex's
  emoji-free header style.

### Source

Motivated by the three-layer defense designed in
`docs/plans/stride-plugin-feedback.md` (kanban repo) and ported from stride
1.10.0 (commit 5c30036).

## [1.5.0] - 2026-04-24

### Added

- **`install.ps1`** — Windows PowerShell installer mirroring the behavior of `install.sh`. Defaults to global install at `$env:USERPROFILE\.agents\`; `-Project` switch installs into `.\.agents\` in the current directory; `-Help` prints usage and exits. Uses `$ErrorActionPreference = 'Stop'`, cleans up its temp clone directory in a `finally` block, checks for `git` on `PATH` with a friendly error if missing, and preserves the per-skill `skills/<name>/SKILL.md` layout the Codex CLI expects. Can be invoked via `irm https://raw.githubusercontent.com/cheezy/stride-codex/main/install.ps1 | iex` or the scriptblock wrapper `& ([scriptblock]::Create((irm ...))) -Project` for project-local installs.
- **`README.md`** — New "Windows (PowerShell)" section under Installation documenting the global one-liner, the project-scoped scriptblock-wrapper one-liner, and a download-then-run variant. Added a Windows manual-install block using `Copy-Item` alongside the existing bash `cp -r` version. Notes PowerShell 5.1+ / PowerShell Core 7+ and Git for Windows as prerequisites.

## [1.4.0] - 2026-04-16

### Added

- **`stride-completing-tasks` skill** — Surfaced `explorer_result` and `reviewer_result` in six places so agents cannot forget them: (1) the MANDATORY teaser at the top of the skill lists both as required alongside the hook results; (2) the pre-completion Verification Checklist asks whether both are included; (3) the primary API Request Format example includes both in the self-reported skip shape (Codex's weaker custom-agent support makes skip the primary path); (4) a new "Explorer/Reviewer Result Schema" section leads with the skip shape, then documents the dispatched shape, the five-value skip-reason enum (`no_subagent_support`, `small_task_0_1_key_files`, `trivial_change_docs_only`, `self_reported_exploration`, `self_reported_review`), the 40-character non-whitespace summary minimum, a 422 rejection example, and the feature-flag grace-period rollout; (5) the Completion Request Field Reference table lists both as required objects; (6) the Quick Reference Card's `REQUIRED BODY` includes both plus a SKIP FORM snippet.
- **`stride-workflow` skill** — Step 8's Required Fields table and JSON payload example now include `explorer_result` and `reviewer_result` using the skip shape as the default. A new "Explorer and Reviewer Result Rollout" section after "Workflow Telemetry" describes the grace-mode/strict-mode feature-flag phases and directs readers to `stride-completing-tasks` for the full shape (no schema duplication). Orchestrator prose explains that Steps 3 and 6 already produce the data needed to populate these fields in Step 8, and that the skip form is the default path on Codex.

## [1.3.0] - 2026-04-14

### Added

- **`stride-workflow` skill** — New "Workflow Telemetry: The `workflow_steps` Array" section documenting the six-entry step-name vocabulary (`explorer`, `planner`, `implementation`, `reviewer`, `after_doing`, `before_review`), per-step schema (`name`, `dispatched`, `duration_ms`, `reason`), full-dispatch and skipped-step examples, and rules for assembling the array. Step names are identical to the main stride plugin so Stride can aggregate telemetry across agents and plugins.
- **`stride-completing-tasks` skill** — `workflow_steps` now appears in the verification checklist, the API Request Format example, the Completion Request Field Reference table, and the Quick Reference Card REQUIRED BODY. Added a Schema Reference paragraph pointing at `stride-workflow` as the source of truth for the array shape.

### Changed

- **`stride-completing-tasks` skill** — "Critical" note under the payload example now lists `workflow_steps` alongside the two hook-result fields as required. The API will reject completions that omit it.

## [1.2.0] - 2026-04-13

### Changed

- **`stride-claiming-tasks`** — Replaced soft "Recommended" orchestrator section with non-negotiable "YOUR NEXT STEP" gate demanding stride-workflow activation immediately after claiming. Added workflow violation warning to standalone mode.
- **`stride-completing-tasks`** — Added "BEFORE CALLING COMPLETE: Verification Checklist" with 4 yes/no items covering orchestrator activation, codebase exploration, acceptance criteria review, and hook readiness.

## [1.1.0] - 2026-04-13

### Added

- **`stride-workflow` skill** — Single orchestrator for the complete Stride task lifecycle adapted for Codex CLI. Walks through prerequisites, claiming, codebase exploration (via custom agents with graceful fallback), implementation, code review, manual hook execution, and completion in a single skill. Uses process-over-speed messaging. Eliminates the need to remember which skills to activate at which moments.

### Changed

- **`stride-claiming-tasks` skill** — Reframed automation notice from throughput-emphasizing ("FULLY AUTOMATED") to process-over-speed ("The workflow IS the automation"). Added "Recommended: Use the Workflow Orchestrator" section pointing to `stride-workflow`. Renamed "MANDATORY: Next Skill After Claiming" to "Next Skill After Claiming (Standalone Mode)".
- **`stride-completing-tasks` skill** — Reframed automation notice from throughput-emphasizing to process-over-speed. Added "Arriving from stride-workflow" section. Renamed "MANDATORY: Previous Skill Before Completing" to "Previous Skill Before Completing (Standalone Mode)". Added `stride-workflow` as first entry in the prerequisite skills list.
- **`AGENTS.md`** — Updated Workflow Sequence to recommend `stride-workflow` as preferred entry point, with standalone skill chain as alternative.
- **`README.md`** — Added `stride-workflow` to Workflow Order (as recommended) and Skills table. Existing standalone workflow preserved as alternative.

## [1.0.0] - 2026-03-26

### Added

**Skills (6)**
- `stride-claiming-tasks` — Task claiming with manual before_doing hook execution
- `stride-completing-tasks` — Task completion with manual after_doing and before_review hooks
- `stride-creating-tasks` — Task creation with field format validation
- `stride-creating-goals` — Goal and batch creation with dependency management
- `stride-enriching-tasks` — Automated codebase exploration to enrich minimal tasks
- `stride-subagent-workflow` — Decision matrix for agent dispatch based on complexity

**Agents (4)**
- `task-explorer` — Read-only codebase exploration for key_files and patterns
- `task-reviewer` — Code review against acceptance criteria, pitfalls, and patterns
- `task-decomposer` — Goal decomposition into dependency-ordered child tasks
- `hook-diagnostician` — Hook failure diagnosis with prioritized fix plans

**Configuration**
- `AGENTS.md` — Codex configuration bridge with skill activation rules and tool mapping

**Documentation**
- `README.md` — Installation, skill chain, manual hook execution, troubleshooting
- `CHANGELOG.md` — This file

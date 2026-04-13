# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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

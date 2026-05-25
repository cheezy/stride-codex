# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.12.1] - 2026-05-25

### Updated

- **`skills/stride-creating-tasks/SKILL.md`** (W865) — Adds a top-of-file "⚠️ REVIEW QUEUE SCORING" callout that names the four fields the review_queue dashboard scores on every completion (`acceptance_criteria`, `testing_strategy`, `pitfalls`, `patterns_to_follow`) and frames the consequence of omitting any of them: a visible, public, persistent **empty pill** on the dashboard that does not get back-filled later. Reinforces with four new bullets in the existing **Red Flags - STOP** list and four new rows in the existing **Rationalization Table**. Wording matches the stride/ Claude Code variant for cross-plugin consistency.
- **`skills/stride-enriching-tasks/SKILL.md`** (W866) — Adds a top-of-file "⚠️ REVIEW QUEUE SCORING — ENRICHMENT IS THE LAST CHANCE" callout. Promotes the four scored fields to individual mandatory-for-review items in the Phase 4 16-item pre-submission checklist (replacing the prior single-line bundling), each with its specific empty-pill condition. Adds four new Red Flags - STOP bullets.
- **`skills/stride-creating-goals/SKILL.md`** (W867) — Adds a top-of-file "⚠️ REVIEW QUEUE SCORING — NESTED TASKS ARE NOT EXEMPT" callout stressing the four-field minimum bar applies to every nested task individually — no "it's just a subtask" discount. Strengthens Task Nesting Rules with a per-field block enumerating each scored field with its empty-pill condition. Adds four new Red Flags - STOP bullets and four new Rationalization Table rows.

### Backward compatibility

Content-only release. No hook script, parser contract, env-var matrix, API field shape, or workflow step changed — every behavior is byte-identical to 1.12.0. The three SKILL.md edits strengthen guidance only; existing task-creation, enrichment, and goal-creation calls continue to validate without modification. No `.stride.md`, `.stride_auth.md`, or `.gitignore` changes are required.

### Source

G166 / W865 / W866 / W867 / W868. Patch release — documentation-only emphasis updates across three SKILL.md files. The change set mirrors the stride/ plugin's 1.17.3 release (Claude Code variant) and the goal is to raise the floor on the four fields the review_queue dashboard scores at completion, so empty pills become rare rather than common.

## [1.12.0] - 2026-05-25

### Added

- **`skills/stride-completing-tasks/SKILL.md`** — New subsection "Per-File Diff Capture (Manual, Wrapped-Body PUT — for v1.16.0+ servers)" documenting the optional agent-manual flow that mirrors what the auto-PUT hook does on other Stride plugins. Codex CLI has no plugin-side hook surface to host the auto-PUT, so this is documentation only — the existing inline-cat-in-complete flow remains the recommended default. The new section walks through a copy-pasteable `.stride.md` `## after_doing` block that (1) sources the canonical `capture_changed_files` function and writes the snapshot to `.stride-changed-files.json`, then (2) `curl -s -X PUT`s the snapshot to `$STRIDE_API_URL/api/tasks/$TASK_ID/changed_files` with the body wrapped as `{"changed_files": [...]}`. The body shape rule is documented explicitly with a side-by-side bare-vs-wrapped JSON comparison and an explicit reference to G174 / Plug.Parsers `_json` behavior so future readers do not accidentally simplify the body to a bare top-level array (which the server would persist as NULL, silently clearing the snapshot — this was the critical regression that made stride 1.17.2 a critical fix). Implemented as W848.

### Why this release

The Stride server's `PUT /api/tasks/:id/changed_files` endpoint has existed since 1.16.0 but stride-codex's completion guidance only ever showed the inline-in-complete shape — so Codex agents targeting v1.16.0+ servers who wanted to fire the snapshot up early (live diff panel, review-queue webhook) had to figure out the wrapped body shape from external references. This release closes that gap by documenting the wire-shape rule in the skill that every Codex agent reads before /complete.

### Backward compatibility

Behavior unchanged. Codex's existing inline-cat-in-complete flow remains the recommended default — the new subsection is presented as an alternative, not a replacement. No `.stride.md`, `.stride_auth.md`, or `.gitignore` changes are required.

### Migration

Update via your normal stride-codex install flow. No marketplace pin update — stride-codex is not distributed through stride-marketplace.

### Source

W848. Documentation-only release that mirrors the G174 wrapped-body rule from main stride 1.17.2 into the Codex variant's completion skill. No code surface in stride-codex (Codex CLI has no hook surface), hence no plugin.json version pin to bump — the version lives only in this CHANGELOG.

## [1.11.0] - 2026-05-22

### Added

- **`## after_goal` hook documentation** — fifth `.stride.md` hook documented across two skills. stride-codex has no plugin hook script (unlike stride-claude / stride-copilot / stride-gemini / stride-opencode), so this release is **documentation-only**: it teaches Codex CLI agents how to handle the `after_goal` lifecycle manually when the Stride server bundles an `after_goal` entry in the response of `/complete` or `/mark_reviewed`.
- **`skills/stride-workflow/SKILL.md`** (W801) — Step 7 (Execute Hooks) gains a Hooks Reference table listing all five hooks (timing/blocking/timeout/purpose) with an explicit note that codex has no hook script so the agent runs each hook manually via the platform's shell tool. New Hook Environment Variables matrix shows `GOAL_*` (`GOAL_ID`, `GOAL_IDENTIFIER`, `GOAL_TITLE`, `GOAL_DESCRIPTION`) alongside `TASK_*` / `BOARD_*` / `COLUMN_*` / `AGENT_NAME` / `HOOK_NAME`, with guidance to export from the response's `hook.env` block. New Canonical Hook Examples block with an explicit general-purpose disclaimer (Slack notifications, artifact archival, release pipelines, project-level smoke tests are all valid uses — not just PR creation). Step 9 (Post-Completion Decision) gains a new subsection with a five-step manual execution path: detect after_goal entry in response → read `## after_goal` from `.stride.md` → export GOAL_* from hook.env → execute commands via shell → POST captured `{exit_code, output, duration_ms}` to `PATCH /api/tasks/:goal_id/after_goal`.
- **`skills/stride-completing-tasks/SKILL.md`** (W802) — New subsection in the "Review vs Auto-Approval Decision" block surfacing the after_goal entry in the `/complete` and `/mark_reviewed` response payload's `hooks` array. Documents the same five-step manual execution path with the curl shape for the agent's PATCH POST. Includes pitfall: non-zero exit must be surfaced, never silently retried.

### Backward compatibility

A `.stride.md` without a `## after_goal` section continues to work unchanged — the agent simply skips the manual execution path and the server's grace-window worker promotes the goal to Done automatically with a synthetic attempt tagged `source: "after_goal_grace_worker"`. Older agent runtimes that don't speak the after_goal protocol — including those that don't make the PATCH POST — are covered by the same grace-window worker.

### Note on the v1.10.x tag gap

Commits `8f7a986 Default CLAUDE_PROJECT_DIR to . in inline-cat pattern (W771)` and `01f85a5 Release 1.10.1` and `a965a4e Release 1.10.0` were committed but never tagged on origin. This v1.11.0 release captures all of that prepared work alongside the new after_goal documentation — installing v1.11.0 picks up everything.

### Migration

Install via your normal stride-codex install flow. No `.stride.md`, `.stride_auth.md`, or `.gitignore` changes are required. To opt into the new hook, add a `## after_goal` section to `.stride.md` AND follow the five-step manual execution path documented in stride-workflow Step 9 / stride-completing-tasks "Additional hook in the response" subsection.

### Source

G167 / W801 (stride-workflow SKILL.md), W802 (stride-completing-tasks SKILL.md), W803 (this release). Pattern mirrors the Claude plugin's v1.17.1 release — the after_goal feature shipped first on the Claude plugin and is being ported to the other Stride agent plugins. For stride-codex, the port is documentation-only because there's no hook script to update.

## [1.10.1] - 2026-05-21

### Fixed

- **`skills/stride-completing-tasks/SKILL.md`** — Replaced five occurrences of `"$CLAUDE_PROJECT_DIR/.stride-changed-files.json"` with the defaulted form `"${CLAUDE_PROJECT_DIR:-.}/.stride-changed-files.json"` in the canonical inline-cat pattern. The inline structure, the `--argjson cf "$(cat ... 2>/dev/null || echo '[]')"` shape, and the binary/truncation contract are unchanged — only the variable expansion is defaulted.
- **`.codex-plugin/plugin.json`** — Version field corrected to `1.10.1`. The repository carried a pre-existing version-tag drift (the v1.10.0 release was tagged without bumping `plugin.json` from `1.9.0`); this hotfix re-syncs the manifest with the release tag in the same commit.

### Why this release

Under runtimes where `$CLAUDE_PROJECT_DIR` is unset/empty (notably Claude Code's TypeScript SDK when bridging from Codex CLI), the bare expansion produced `/.stride-changed-files.json`. The `cat` failed, the `|| echo '[]'` fallback fired, and agents POSTed `changed_files: []` even when the hook had correctly written the snapshot. The defaulted form `${CLAUDE_PROJECT_DIR:-.}` falls back to the current working directory when the variable is unset or empty.

### Backward compatibility

Wire shape unchanged. Behavior under a non-empty `$CLAUDE_PROJECT_DIR` is byte-identical to v1.10.0.

### Source

Mirrors the stride v1.15.1 fix (W767/W768) for the Codex variant. Implemented as W771 (SKILL.md hotfix) and W772 (release coordination). No marketplace pin update — stride-codex is not distributed through stride-marketplace; consumers install directly from this repository.

## [1.10.0] - 2026-05-20

### Added

- **`skills/stride-completing-tasks/SKILL.md`** — New `## Per-File Diff Capture (Manual)` section that documents the optional top-level `changed_files` field on completion payloads, citing [`docs/diff-contract.md`](https://raw.githubusercontent.com/cheezy/kanban/refs/heads/main/docs/diff-contract.md) as the encoding source-of-truth (field shape, 500-line truncation marker, binary placeholder string). The section explains the Codex-specific architecture — Codex CLI has no automatic hook interception, so the snapshot is produced by the agent (typically as a line in the user's `.stride.md` `## after_doing` block) rather than by an auto-firing PreToolUse handler the way other Stride plugins do it. Includes a "Why inline?" paragraph explaining that a separate shell turn before the completion curl would read a stale snapshot from a prior task, and a "Working-tree semantic" paragraph documenting the canonical Option D capture (committed + staged + modified-uncommitted + untracked-new files in a single pass against `$TASK_BASE_REF`, not `..HEAD`).
- **`skills/stride-completing-tasks/SKILL.md`** — New pre-completion verification checklist item explicitly testing for the inline-cat-in-jq pattern with the absolute `$CLAUDE_PROJECT_DIR/.stride-changed-files.json` path, including the rationale that reading the snapshot in an earlier shell turn picks up the prior task's snapshot.

### Changed

- **`skills/stride-completing-tasks/SKILL.md`** — Rewrote the `## API Request Format` section to lead with a `bash`/`curl` example that inlines the snapshot read via `--argjson cf "$(cat \"$CLAUDE_PROJECT_DIR/.stride-changed-files.json\" 2>/dev/null || echo '[]')"` INSIDE the `jq -n` invocation that builds the curl's `-d` payload. The JSON body shape is kept as an illustrative supplement below the bash example. A new `**Optional:**` paragraph after the `**Critical:**` line documents the snapshot-absent fallback (`changed_files: []` is a valid completion).

### Why this release (and what's NOT in it)

Mirrors stride 1.15.0 (G157/W758) into stride-codex as far as the platform allows. Other Stride plugins ship a `hooks/stride-hook.sh` that the host CLI fires as a PreToolUse / BeforeTool handler on the completion curl — the handler writes `.stride-changed-files.json` automatically. Codex CLI has no equivalent hook surface, so stride-codex's port is **SKILL.md-only**: the wire shape (`changed_files: [{path, diff}, …]`), the encoding contract, and the inline-cat-in-jq read pattern are byte-identical to the other plugins, but the *writer* is the agent (typically via a line added to the user's `.stride.md` `## after_doing` block) rather than an auto-firing handler. **No `hooks/` directory was added.** The canonical `capture_changed_files()` bash function lives in `stride/hooks/stride-hook.sh` and can be sourced or pasted by users who want byte-identical capture behavior.

### Backward compatibility

The wire shape of `changed_files` is unchanged. Completion payloads that omit `changed_files` entirely continue to validate (the empty-array form produced by the inline `|| echo '[]'` fallback is also valid). Codex tasks that ran before this release simply did not produce snapshots; their `actual_files_changed` lists still surface in `/review`.

### Source

Implemented as W735 (combined SKILL.md docs + CHANGELOG entry). No marketplace coordination — stride-codex ships by tag directly.

## [1.9.0] - 2026-05-19

### Changed

- **`agents/task-reviewer.md`** — Rewrote Step 6 ("Return Structured Review") and the Output persistence paragraph to require an unconditional fenced ```json block alongside the existing markdown prose. The block matches the canonical `reviewer_result` schema documented in [`stride/agents/task-reviewer.md`](https://github.com/cheezy/stride/blob/main/agents/task-reviewer.md) — `schema_version`, `summary`, `status`, `issue_counts`, `issues[]` (with `severity`/`category` enums), and `acceptance_criteria[]` (with `met`/`not_met` enum). Includes a verbatim worked `changes_requested` example. The prose summary line is preserved above the JSON block so orchestrator fallback paths that grep substring summaries continue to work when JSON parsing fails. No codex-specific schema variant introduced — the canonical schema is cited by path.
- **`skills/stride-subagent-workflow/SKILL.md`** — Added an "Extracting the structured review block" subsection to Phase 3 (Code Review). The orchestrator now extracts the first fenced ```json fence from the reviewer's response and populates `reviewer_result` in the completion PATCH payload with both (a) the legacy summary fields (`summary`, `issues_found` from `sum(issue_counts.values())`, `acceptance_criteria_checked` from the length of the structured array) and (b) the structured fields verbatim (`status`, `issue_counts`, `issues`, `acceptance_criteria`, `schema_version`). Includes a worked example and a documented fallback path that keeps older agent versions and parse failures working: substring-match the prose summary, omit structured fields from the PATCH (never empty placeholders), do not abort the completion.

### Source

Ported from stride 1.13.0 (commits 9c19359 "Define structured JSON review-report schema in task-reviewer agent" and 8e94eca "Extract structured review block into reviewer_result PATCH payload"). Cross-plugin parity for Stride W685/W686 (implemented in stride-codex as W696).

## [1.8.0] - 2026-05-08

### Removed

- **`skills/stride-workflow/SKILL.md`** — Removed all three references to the user-private `stride-development-guidelines` skill: the Step 5 ("Activate Development Guidelines") section, the corresponding flowchart node, and the Quick Reference Card line. That skill is project-local to the plugin author's machine and is not distributed with this plugin, so end users would have seen Step 5 instructing them to activate a skill that does not exist for them. The Step 5 slot is left empty rather than renumbered to avoid breaking step-number cross-references elsewhere in the file.

### Why this release

Cross-skill references to non-plugin skills break the workflow for end users. This guard rail is being applied to all five Stride plugins (`stride`, `stride-codex`, `stride-gemini`, `stride-opencode`, `stride-pi`) in a coordinated release.

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

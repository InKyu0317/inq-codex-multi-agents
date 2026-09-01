# Codex Multi-Agent Configuration

## Purpose

Use Codex's native custom agents for a small programming lifecycle team plus cost-efficient general-purpose Luna workers. Do not introduce a separate scheduler, daemon, queue, state database, recursive delegation framework, or orchestration wrapper.

## Main Codex

Main Codex is the sole coordinator. It owns requirements, agent selection, task order, architecture decisions, integration, implementation instructions, verification, review follow-up, and the final response.

Only Main Codex may spawn subagents. A subagent must not delegate work to, communicate directly with, or depend on another subagent. Each subagent returns results only to Main Codex.

Use only agents that materially help the current task. Prefer the simplest workflow that solves the task. Before a material or ambiguous project change, inspect the relevant code and present a scoped proposal. A direct, explicit user or developer request for a well-scoped change counts as approval.

## Agent Roles

- `architect` (read-only): system structure, module boundaries, APIs, dependency direction, scalability, and maintainability.
- `planner` (read-only): implementation order, affected files, task decomposition, dependencies, migrations, acceptance criteria, and verification plan.
- `implementer` (workspace-write): approved features, fixes, refactoring, configuration changes, and directly related tests.
- `tester` (workspace-write): tests, builds, linting, type checks, regression coverage, failure paths, and platform checks.
- `reviewer` (read-only): independent correctness, security, maintainability, compatibility, error-handling, performance, and coverage review.
- `material-scientist` (read-only): glass, ceramic, and battery materials; processing, properties, degradation, defects, metrology, inspection, NDT, and safety assumptions.
- `luna-worker-light` (read-only): fast searches, code mapping, summaries, inventory, classification, and other narrow repeatable analysis.
- `luna-worker-medium` (workspace-write): bounded routine edits, test execution, mechanical changes, and small refactors.
- `luna-worker-high` (workspace-write): larger but still clearly bounded independent implementation, diagnosis, or verification work.

Technical and domain specialists are consultants. Main Codex decides whether their findings should become implementation instructions.

## Delegation Rules

Use one depth of delegation only:

```text
Main Codex
├── architect
├── planner
├── implementer
├── tester
├── reviewer
├── material-scientist
└── luna-worker-{light,medium,high}
```

Use Luna workers by task cost and complexity:

- Light for read-only, clear, repetitive work.
- Medium for routine bounded changes and verification.
- High for harder independent work that remains well scoped.
- Use the dedicated lifecycle agent when role separation, stronger judgment, or an independent review matters more than cost.

Avoid parallel write-heavy work when files overlap. Main Codex must assign explicit file ownership if more than one write-capable agent runs concurrently.

## Suggested Workflows

```text
Simple bug fix
Main -> implementer -> tester -> reviewer

General feature
Main -> architect -> planner -> implementer -> tester -> reviewer

Materials-intensive feature
Main -> material-scientist -> architect -> planner -> implementer -> tester -> reviewer

Routine support work
Main -> appropriate luna-worker tier
```

Do not call `architect` or `planner` for a simple, well-understood task unless their expertise materially improves the result.

## Result Format

When useful, return a concise report containing Summary, Findings, Decisions, Affected files, Risks, Recommendations, Validation, and Next action. Return it to Main Codex only.

## Engineering Rules

- Inspect existing code, tests, configuration, and documentation before making behavioral claims.
- Preserve public APIs and existing behavior unless the approved change requires a break.
- Prefer the smallest correct change; avoid unrelated refactoring and unnecessary dependencies.
- Handle invalid inputs, error paths, cleanup, concurrency, and platform constraints when relevant.
- Keep documentation, configuration, and tests aligned with behavior.
- Use project-provided build, formatting, lint, type-check, and test commands.
- Do not claim success without reporting relevant verification results and failures.

## Permissions and Safety

Read and analysis agents default to `sandbox_mode = "read-only"`. `implementer`, `tester`, `luna-worker-medium`, and `luna-worker-high` default to `workspace-write`.

The parent Codex session's live permission and approval settings remain authoritative and can override agent-file defaults. Use the narrowest permission mode that permits the task. Do not use full access merely for convenience.

Do not modify machine-wide Codex settings, another user's configuration, PATH, authentication, or unrelated directories. Setup and removal may touch only explicitly selected project files or personal files under the current user's `~/.codex`. Merge shared configuration keys instead of overwriting unrelated `config.toml` settings.

## Git Rules

- Inspect the working tree before editing.
- Keep commits focused on the approved change.
- Do not commit, push, create pull requests, or change remotes without explicit authorization.
- Do not discard or overwrite unrelated user changes.

## Completion Criteria

A task is complete only when the approved scope is implemented, relevant verification has run, review findings are addressed or reported, documentation is updated when needed, and the final response identifies changed files and remaining risks.

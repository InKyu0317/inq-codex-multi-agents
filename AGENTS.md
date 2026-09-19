# Codex Development Workflow

## Core rule

Use [`.ai/workflow.md`](.ai/workflow.md) as the source of truth for the development process. Select `FAST`, `STANDARD`, or `HIGH-RISK` before modifying source files.

- `FAST` work needs no work package.
- `STANDARD` and `HIGH-RISK` work require `.ai/work/<work-slug>/` and its required artifacts.
- For `HIGH-RISK` work, do not modify production source files until the user explicitly approves the completed `spec.md`, `design.md`, `plan.md`, and `tasks.md`.
- Implement only approved work from `tasks.md`, and update its task status as work progresses.
- Keep files and folders minimal; reuse before adding, delete unused scaffolding.
- Track progress only in `.ai/log.md` — never create per-task or per-folder log files.

## Coordination

Main Codex is the sole coordinator. It selects the workflow path, delegates only when useful, owns artifact creation, integrates results, and gives the final response.

Only Main Codex may spawn subagents. A subagent must not delegate to or directly communicate with another subagent; it returns results only to Main Codex.

Do not run write-capable agents in parallel when their file scopes overlap. Keep reviewer independent from implementer whenever a review is required.

## Lifecycle agents

- `architect` — read-only specification, design, boundaries, interfaces, risks, and compatibility.
- `planner` — read-only implementation sequence, file scope, task breakdown, migration, rollback, and validation plan.
- `implementer` — approved implementation and directly related tests.
- `frontend-expert` — frontend implementation that reuses existing UI patterns and preserves visual consistency.
- `tester` — independent tests, build, lint, type check, regression, and platform verification.
- `reviewer` — read-only independent review against the request, artifacts, implementation, and tests.

Read-only agents provide artifact content to Main Codex; Main Codex records it under `.ai/work/<work-slug>/`.

## Engineering and safety

- Inspect relevant code, tests, configuration, and the working tree before making claims or changes.
- Prefer the smallest correct change. Preserve public behavior unless the approved change requires otherwise.
- Use project-provided validation commands and report failures honestly.
- Do not create a scheduler, daemon, queue, state database, workflow engine, automatic provider failover, or other orchestration framework.
- Do not store API keys in the repository. Material-science expertise is supplied by separately installed personal Skills, not by this repository.

## Code Review Graph

Use `code-review-graph` only as a local code-navigation and change-review aid. Do not enable its daemon or watch mode.

- Run `code-review-graph status` at the start of work. Build or update the graph only when it is missing or stale.
- Keep `.code-review-graph/` in `.gitignore` and never commit it.
- Use `explore-codebase` for specification and design, `debug-issue` for debugging, and `refactor-safely` before structural refactors.
- After implementation, use `review-delta`; before completion or commit, use `review-changes`; use `review-pr` for pull requests.
- Treat graph output as navigation evidence, not a replacement for reading relevant source, running tests, or following `.ai/workflow.md`.

## Git

- Inspect the working tree before editing.
- Do not discard unrelated changes.
- Do not commit, push, create a pull request, or change remotes without explicit user authorization.

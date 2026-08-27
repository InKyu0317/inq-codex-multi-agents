# Codex CLI Multi-Agent Project

## Purpose

This repository provides a project-scoped multi-agent configuration for Codex CLI. It uses native Codex features: `AGENTS.md`, `.codex/`, custom subagents, model and reasoning selection, sandboxing, and approval controls.

Do not introduce a separate agent scheduler, daemon, message broker, queue, state database, recursive delegation framework, or wrapper that duplicates Codex orchestration.

## Project Structure

```text
AGENTS.md
.codex/
├── config.toml
└── agents/
    ├── architect.toml
    ├── planner.toml
    ├── advisor.toml
    ├── researcher.toml
    ├── implementer.toml
    ├── tester.toml
    ├── reviewer.toml
    ├── frontend-expert.toml
    ├── python-expert.toml
    ├── csharp-expert.toml
    ├── rust-expert.toml
    └── glass-scientist.toml
```

`AGENTS.md` contains project-wide rules. Each TOML contains only the role-specific purpose, instructions, model, reasoning effort, and sandbox mode for one custom agent.

## Main Codex

Main Codex is the sole coordinator. It owns requirements, agent selection, task order, architecture decisions, integration, implementation instructions, verification, review follow-up, and the final response.

Only Main Codex may spawn subagents. A subagent must not call, delegate to, or depend on another subagent. Each subagent returns its results to Main Codex, which decides the next action.

Use only the agents that materially help the current task. Prefer the simplest workflow that solves the task.

Before modifying a project, Main Codex must inspect the relevant code and present a scoped change proposal. Implementation begins only after explicit developer approval.

## Agent Roles

### Architecture and Decision

- `architect`: system architecture, module boundaries, responsibilities, APIs, dependency direction, scalability, and maintainability.
- `planner`: implementation decomposition, file scope, sequence, dependencies, migrations, acceptance criteria, and test strategy.
- `advisor`: focused alternatives, trade-offs, compatibility, performance, risk, and recommendation.

### Development Workflow

- `researcher`: official documentation, libraries, APIs, standards, compatibility, and current technical facts.
- `implementer`: approved features, fixes, refactoring, configuration changes, and directly related tests.
- `tester`: unit, integration, regression, edge-case, build, lint, type-check, and configuration verification.
- `reviewer`: independent correctness, architecture, maintainability, security, performance, compatibility, error-handling, and test-coverage review.

### Technical and Domain Experts

- `frontend-expert`: JavaScript, TypeScript, React, Next.js, Vite, browser APIs, UI architecture, accessibility, testing, and performance.
- `python-expert`: Python, NumPy, SciPy, pandas, PyTorch, FastAPI, scientific computing, packaging, async code, testing, and performance.
- `csharp-expert`: C#, .NET, ASP.NET, WPF, WinUI, desktop applications, Windows APIs, async code, dependency injection, testing, and industrial architecture.
- `rust-expert`: ownership, borrowing, lifetimes, async Rust, concurrency, FFI, unsafe code, error handling, API design, testing, and performance.
- `glass-scientist`: glass, ceramic, materials, manufacturing, properties, defects, measurement, optical inspection, NDT, and industrial inspection assumptions.

Technical and domain experts are consultants. They provide analysis to Main Codex; `implementer` performs normal project changes.

## Delegation Rules

Use one depth of delegation only:

```text
Main Codex
├── architect
├── planner
├── advisor
├── researcher
├── relevant specialist
├── implementer
├── tester
└── reviewer
```

Forbidden examples:

```text
Main -> architect -> planner
Main -> planner -> python-expert
Main -> implementer -> tester
Main -> reviewer -> implementer
```

For independent analysis, Main Codex may call `researcher` and relevant specialists in parallel. All results return to Main Codex before the next subagent is called.

## Suggested Workflows

```text
Simple bug fix
Main -> implementer -> tester -> reviewer

General feature
Main -> architect -> planner -> implementer -> tester -> reviewer

Technology decision
Main -> advisor -> architect -> planner -> implementer -> tester -> reviewer

External research required
Main -> researcher -> architect -> planner -> implementer -> tester -> reviewer

Technology or domain intensive feature
Main -> relevant specialist -> architect -> planner -> implementer -> tester -> reviewer
```

Do not call `architect` or `planner` for a simple, well-understood task unless their expertise provides meaningful value.

## Result Format

When useful, subagents should return a concise report containing:

```text
Summary
Findings
Decisions
Affected files
Risks
Recommendations
Validation
Next action
```

The report returns to Main Codex, not to another subagent.

## Engineering Rules

- Inspect existing code, tests, configuration, and documentation before making behavioral claims.
- Preserve public APIs and existing behavior unless the approved change explicitly requires a break.
- Prefer the smallest correct change. Avoid speculative abstractions, unrelated refactoring, and unnecessary dependencies.
- Handle invalid inputs, error paths, resource cleanup, concurrency, and platform constraints explicitly when relevant.
- Keep documentation, configuration, and tests aligned with behavior.
- Use project-provided build, formatting, lint, type-check, and test commands whenever available.
- Do not claim success without reporting relevant verification results and failures.

## Permissions and Safety

Read and analysis agents use `sandbox_mode = "read-only"`. `implementer` and `tester` use `workspace-write` because implementation and routine verification may require workspace changes.

The parent Codex session's live permission and approval settings remain authoritative. Use the narrowest permission mode that permits the task. Do not use full access merely for convenience.

Do not modify system-wide Codex settings, another user's configuration, PATH, authentication, or unrelated directories. Any future setup or remove procedure may create or remove only files it owns inside the selected project.

## Git Rules

- Inspect the working tree before editing.
- Keep commits focused on the approved change.
- Do not commit, push, create pull requests, or change remote repository settings without explicit developer authorization.
- Do not discard or overwrite unrelated user changes.

## Completion Criteria

A task is complete only when the approved scope is implemented, relevant verification has run, review findings are addressed or reported, documentation is updated when needed, and the final response identifies changed files and remaining risks.

# Development Workflow

This file is the development-process source of truth. Main Codex selects one path before source changes and creates all required artifacts under `.ai/work/<work-slug>/`.

## Path selection

Choose the least heavyweight path that is safe. Consider impact scope, reversibility, external-user impact, public API and data changes, security, architecture, cross-module coupling, requirements uncertainty, and regression risk—not only estimated effort.

| Path | Use for | Work package | User approval before source changes |
|---|---|---|---|
| FAST | typo, format, comment, tiny config/UI adjustment, obvious low-risk one-line bug | no | no |
| STANDARD | normal feature or meaningful bug fix | yes | no; the user's requested change authorizes the approved scope |
| HIGH-RISK | architecture/public API/database/security/cross-module/large refactor, data-loss, compatibility, or hard-to-rollback risk | yes | yes, explicitly in the current task |

If a FAST task reveals uncertain requirements or a wider impact, reclassify it. If implementation exceeds an approved STANDARD scope materially, stop, update the artifacts, and request direction when needed.

## FAST

```text
Request → Inspect → Implement → Verify → Done
```

- Main Codex may work directly or use implementer/tester when useful.
- No work package is required.
- Modify only the narrow requested scope.
- Run a relevant check or state why no automated check applies.

## STANDARD

```text
Request → Specification → Design → Planning → Tasks → Implementation → Testing → Review → Done
```

| Stage | Primary role | Required artifact | Production-source write |
|---|---|---|---|
| Specification | Main / architect | `spec.md` | no |
| Design | architect | `design.md` | no |
| Planning | planner | `plan.md` | no |
| Task breakdown | planner | `tasks.md` | no |
| Implementation | implementer | update task status | yes |
| Testing | tester | test results in `review.md` | no, except scoped test code |
| Review | reviewer | `review.md` | no |

Read-only agents return artifact content to Main Codex; Main Codex writes the files. The final review must check specification compliance, acceptance criteria, tests, regressions, compatibility, security when applicable, and unresolved issues.

## HIGH-RISK

```text
Request → Specification → Design → Planning → Tasks → Explicit user approval → Implementation → Testing → Independent review → Done
```

Use the STANDARD artifacts and stages, with these additional rules:

- Do not modify production source files before the user explicitly approves the completed package in the current task.
- `plan.md` must state migration, rollback, compatibility, and validation strategy where applicable.
- Reviewer must be independent of implementer.
- Record unresolved risks and rollback limits in `review.md`.

## Work packages and artifacts

Use a readable kebab-case slug, for example `.ai/work/device-manager/`.

| Artifact | Responsibility |
|---|---|
| `spec.md` | problem, goal, scope, non-goals, requirements, constraints, acceptance criteria |
| `design.md` | architecture, components, boundaries, interfaces, data/API changes, alternatives, risks, compatibility |
| `plan.md` | phases, affected modules/files, ordering, dependencies, migration, tests, rollback, sequencing |
| `tasks.md` | atomic tasks with ID, status, files, dependencies, and acceptance criteria |
| `review.md` | spec/design compliance, tests, regressions, unresolved issues, debt, compatibility, security |

Do not create `implementation.md`, `status.yaml`, a workflow engine, or a persistent task database. Git history, diffs, task status, and test evidence are the implementation record.

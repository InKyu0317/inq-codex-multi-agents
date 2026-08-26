# Codex Advisor

A human-led AI development workflow for Codex.

> You write the code. AI helps you think.

Codex Advisor is designed for developers who want to keep direct control over implementation while using AI for architecture, planning, codebase analysis, technical research, implementation, code review, and verification.

## Philosophy

AI should assist the developer rather than replace the developer.

The workflow separates reasoning, planning, implementation, and verification.

Most agents are read-only.

Only the Implementer is allowed to modify project files, and only after explicit human approval.

## Agents

| Agent | Model | Reasoning | Write |
|---|---|---|---|
| Architect | Sol | High | No |
| Planner | Terra | High | No |
| Advisor | Terra | High | No |
| Researcher | Sol | High | No |
| Implementer | Terra | High | Yes |
| Reviewer | Luna | High | No |
| Tester | Luna | Medium | No |

## Workflow

```text
                         USER
                           |
                           v
                    MAIN ORCHESTRATOR
                           |
        +------------------+------------------+
        |                  |                  |
        v                  v                  v
    ARCHITECT            ADVISOR          RESEARCHER
        |                  |                  |
        +------------------+------------------+
                           |
                           v
                       PLANNER
                           |
                           v
                 HUMAN APPROVAL GATE
                           |
                     Approved?
                       /     \
                     No       Yes
                     |         |
                     |         v
                     |    IMPLEMENTER
                     |         |
                     |         v
                     |    +----+----+
                     |    |         |
                     |    v         v
                     | REVIEWER   TESTER
                     |    |         |
                     +----+---------+
                           |
                           v
                          USER
```

## Human Approval

The Implementer must never be invoked before explicit developer approval.

Examples:

```text
Approved. Implement the plan.
```

A recommendation is not approval.

A plan is not approval.

## Installation

No installer is provided.

Copy the desired agent definitions into your project's:

```text
.codex/agents/
```

For example:

```text
your-project/
├── .codex/
│   └── agents/
│       ├── architect.toml
│       ├── planner.toml
│       ├── advisor.toml
│       ├── researcher.toml
│       ├── implementer.toml
│       ├── reviewer.toml
│       └── tester.toml
├── AGENTS.md
└── ...
```

You may also place agents in your user-level Codex configuration directory if you want them available across projects.

Check the Codex documentation for the configuration locations supported by your installed version.

## License

MIT

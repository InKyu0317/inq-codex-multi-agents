# Codex Development Workflow

Codex native custom agents plus a small, documented development workflow. This repository deliberately does not add a scheduler, daemon, queue, workflow engine, state database, or automatic provider failover.

## Requirements

- Codex CLI 0.150.1 or later recommended
- Git
- Windows PowerShell or a POSIX shell
- [OpenCodex](https://github.com/lidge-jun/opencodex) installed and configured separately, only if you plan to use the `claude` model profile or the manual Claude backup mode. It is not required for native OpenAI-only usage and is not installed by this repository's installer.

```powershell
codex --version
```

## Architecture

```text
User
  ↓
Main Codex
  ├─ architect
  ├─ planner
  ├─ implementer
  ├─ tester
  └─ reviewer
```

Main Codex is the only coordinator. Subagents do not spawn or directly communicate with other subagents. Write-capable agents with overlapping file scopes must not run concurrently.

| Agent | `openai` profile model / reasoning | `claude` profile model / reasoning | Sandbox | Responsibility |
|---|---|---|---|---|
| `architect` | Terra / high | Claude Sonnet 5 / high | read-only | specification, design, boundaries, interfaces, risks |
| `planner` | Terra / medium | Claude Sonnet 5 / medium | read-only | sequence, files, task breakdown, validation, rollback |
| `implementer` | Terra / high | Claude Sonnet 5 / high | workspace-write | approved implementation and related tests |
| `tester` | Luna / medium | Claude Sonnet 5 / medium | workspace-write | independent test, build, lint, type-check, regression |
| `reviewer` | Terra / high | Claude Sonnet 5 / high | read-only | independent requirement, compatibility, security, and coverage review |

Both columns are only ever active together: Main and every lifecycle agent switch as one set using the profile switcher described below, never mixed. Under the `openai` profile, Main and the unnamed-subagent default use `gpt-5.6-terra` with `high`/`medium` reasoning respectively. Under the `claude` profile, Main and the unnamed-subagent default use `anthropic-apikey/claude-sonnet-5` with `high`/`medium` reasoning respectively; this requires OpenCodex to be installed and configured. Normal work should use a named lifecycle agent.

## Development workflow

[`.ai/workflow.md`](.ai/workflow.md) is the process source of truth.

```text
FAST       Request → Inspect → Implement → Verify → Done
STANDARD   Request → Spec → Design → Plan → Tasks → Implement → Test → Review → Done
HIGH-RISK  Request → Spec → Design → Plan → Tasks → User approval → Implement → Test → Independent review → Done
```

STANDARD and HIGH-RISK work use a human-readable work package:

```text
.ai/work/<feature-slug>/
├── spec.md
├── design.md
├── plan.md
├── tasks.md
└── review.md
```

The templates define distinct responsibilities: what to build, how to build it, implementation strategy, atomic tasks, and end-to-end review. FAST work creates no package unless the user asks for one.

## Material Skills

Materials expertise is intentionally maintained in the separate [inq-material-scientist-skill](https://github.com/InKyu0317/inq-material-scientist-skill) repository, not in this repository. Install its `material-scientist`, `glass`, `ceramic`, and `battery` Skills into the current user's Codex Skill directory when needed. This keeps reusable domain knowledge versioned independently from lifecycle-agent configuration.

## Primary mode

Normal use is native Codex:

```powershell
codex
```

## Manual Claude backup mode

OpenCodex can route Codex through Anthropic's API when native Codex usage is unavailable. It is an optional, manually started backup path; it is not installed or configured by this repository's installer.

```text
Codex → OpenCodex → Anthropic API → Claude
```

After installing and configuring OpenCodex separately, use its documented manual lifecycle:

```powershell
ocx start
codex -m "anthropic-apikey/claude-sonnet-5"
ocx stop
```

Use an environment-variable reference such as `${ANTHROPIC_API_KEY}` in OpenCodex configuration. Never commit an API key, `.env` file, or OpenCodex configuration. Do not install an OpenCodex service, shim, quota monitor, or automatic failover for this backup workflow.

Routed-model custom-agent compatibility must be smoke-tested in the installed Codex CLI and App before treating the backup as equivalent to native multi-agent execution. See the OpenCodex documentation for its current compatibility limitations.

## Manual model profiles (Windows PowerShell)

The Windows installer also installs two credential-free profiles and a manual switcher into the selected Codex home:

```text
~/.codex/
├── profiles/openai.json
├── profiles/claude.json
└── switch-profile.ps1
```

`openai` restores Main, the unnamed-subagent default, and all lifecycle roles to the repository's Terra/Luna allocation. `claude` sets Main and every lifecycle role to `anthropic-apikey/claude-sonnet-5`. API keys remain in environment variables and are never stored in either profile.

```powershell
~/.codex/switch-profile.ps1 -Status
~/.codex/switch-profile.ps1 -Profile claude
~/.codex/switch-profile.ps1 -Profile openai
```

Each switch creates a backup under `~/.codex/backups/inq-codex-model-profiles/<timestamp>/`. It is a deliberate manual action: it does not monitor usage, automatically fail over providers, or alter running tasks. Start a new Codex session before creating agents with the selected profile.

## Installation

Clone this repository and use the installer only for personal Codex agent configuration.

```powershell
git clone https://github.com/InKyu0317/inq-codex-multi-agents.git
cd inq-codex-multi-agents
.\install-global.ps1 -WhatIf
.\install-global.ps1
```

POSIX:

```sh
sh ./install-global.sh --what-if
sh ./install-global.sh
```

Options:

- PowerShell: `-TargetCodexHome <path>`, `-MaxConcurrentThreads <1..64>`, `-WhatIf`
- POSIX: `--target-codex-home PATH`, `--max-concurrent-threads N`, `--what-if`

The Windows installer manages only its `AGENTS.md` marker block, Main and `[agents]` settings, the five lifecycle-agent TOML files, and the credential-free profile switcher/definitions. Replaced or retired files are backed up under `~/.codex/backups/inq-codex-multi-agents/<timestamp>/`. It does not install OpenCodex, change PATH, configure authentication, or modify Skills.

## Validation

```powershell
./tests/install-global.smoke.ps1
codex doctor --summary
codex --strict-config app-server --stdio
```

The smoke test uses a temporary Codex home and checks fresh install, config merge, backup, reinstall, retirement of removed agents, and absence of API-key material in repository files.

## License

MIT
